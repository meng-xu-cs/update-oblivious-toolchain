use anyhow::{anyhow, bail, Result};
use rand::RngCore;
use rand_chacha::ChaCha20Rng;
use std::collections::VecDeque;
use uo_allocator::{AllocatorPlan, AllocatorSession, ScratchRegion};
use uo_core::ir::StateObject;
use uo_core::manifest::{OramManifest, PATH_ORAM_SCHEME, SURROGATE_ORAM_SCHEME};
use uo_core::trace::{
    classify_write, LogicalEvent, PhysicalReadEvent, PhysicalWriteEvent, WriteClass,
};
use uo_core::{RuntimePathOramTransitionKind, RuntimePathOramTransitionWitness};
use uo_core::{ScalarType, Type, Value};
use uo_store::StoreCipher;

pub(crate) const ORAM_DIRECTORY_PAGE_ENTRIES: usize = 8;
const ORAM_SLOT_INDEX_BYTES: usize = 8;
const ORAM_LEAF_LABEL_BYTES: usize = 8;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct MapEntry {
    pub occupied: bool,
    pub key: Value,
    pub value: Value,
}

impl MapEntry {
    pub(crate) fn wipe_secrets(&mut self) {
        self.occupied = false;
        self.key.wipe_secrets();
        self.value.wipe_secrets();
    }
}

impl Drop for MapEntry {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct OramParameters {
    pub scheme: String,
    pub capacity: usize,
    pub block_size: usize,
    pub bucket_size: usize,
    pub bucket_count: usize,
    pub blocks_per_bucket: usize,
    pub tree_height: usize,
    pub stash_bound: usize,
    pub recursion_depth: usize,
    pub metadata_pages: usize,
    pub metadata_pages_per_access: usize,
    pub accesses_per_call: usize,
    pub buckets_per_access: usize,
    pub directory_page_entries: usize,
    pub directory_page_bytes: usize,
}

impl OramParameters {
    pub(crate) fn for_spec(spec: &StateObject) -> Result<Self> {
        let capacity = spec
            .capacity
            .ok_or_else(|| anyhow!("map {} is missing capacity", spec.name))?;
        let manifest = OramManifest::for_object(spec)?;
        Ok(Self {
            scheme: manifest.scheme,
            capacity,
            block_size: manifest.block_size,
            bucket_size: manifest.bucket_size,
            bucket_count: manifest.bucket_count,
            blocks_per_bucket: manifest.blocks_per_bucket,
            tree_height: manifest.tree_height,
            stash_bound: manifest.stash_bound,
            recursion_depth: manifest.recursion_depth,
            metadata_pages: manifest.metadata_pages,
            metadata_pages_per_access: manifest.metadata_pages_per_access,
            accesses_per_call: manifest.accesses_per_call,
            buckets_per_access: manifest.buckets_per_access,
            directory_page_entries: ORAM_DIRECTORY_PAGE_ENTRIES,
            directory_page_bytes: ORAM_DIRECTORY_PAGE_ENTRIES * manifest.block_size,
        })
    }
}

impl OramParameters {
    fn is_surrogate(&self) -> bool {
        self.scheme == SURROGATE_ORAM_SCHEME
    }

    fn is_path_oram(&self) -> bool {
        self.scheme == PATH_ORAM_SCHEME
    }

    fn leaf_count(&self) -> usize {
        if self.is_path_oram() {
            (self.bucket_count + 1) / 2
        } else {
            self.bucket_count
        }
    }

    fn position_map_pages(&self) -> usize {
        if self.is_path_oram() {
            oram_directory_page_count(self.capacity)
        } else {
            self.metadata_pages
        }
    }

    fn stash_pages(&self) -> usize {
        if self.is_path_oram() {
            self.metadata_pages
                .saturating_sub(self.position_map_pages())
        } else {
            0
        }
    }
}

fn working_stash_capacity(parameters: &OramParameters) -> Result<usize> {
    let path_headroom = parameters
        .buckets_per_access
        .checked_mul(parameters.blocks_per_bucket)
        .ok_or_else(|| anyhow!("ORAM stash headroom overflowed public path bound"))?;
    parameters
        .stash_bound
        .checked_add(path_headroom)
        .ok_or_else(|| anyhow!("ORAM working stash capacity overflowed public bound"))
}

#[derive(Clone, Debug)]
pub(crate) struct OramStorage {
    pub directory_pages: Vec<Vec<u8>>,
    pub buckets: Vec<Vec<u8>>,
    pub access_counter_slot: Vec<u8>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramTranscript {
    pub logical_accesses: Vec<LogicalEvent>,
    pub physical_reads: Vec<PhysicalReadEvent>,
    pub physical_writes: Vec<OramWrite>,
    pub zero_writes: usize,
    pub path_leaf: Option<usize>,
    pub path_transition: Option<RuntimePathOramTransitionWitness>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramWrite {
    pub location: String,
    pub len: usize,
    pub class: WriteClass,
}

#[derive(Clone, Debug)]
pub(crate) struct OramCommit {
    pub next: OramState,
    pub writes: Vec<OramWrite>,
    pub zero_writes: usize,
}

impl OramWrite {
    pub(crate) fn from_buffers(location: impl Into<String>, old: &[u8], new: &[u8]) -> Self {
        Self {
            location: location.into(),
            len: new.len(),
            class: classify_write(old, new),
        }
    }

    pub(crate) fn with_object(self, object: &str) -> PhysicalWriteEvent {
        PhysicalWriteEvent::from_shape(object, self.location, self.len, self.class)
    }
}

fn record_oram_write(
    writes: &mut Vec<OramWrite>,
    zero_writes: &mut usize,
    location: impl Into<String>,
    old: &[u8],
    new: &[u8],
) {
    if new.iter().all(|byte| *byte == 0) {
        *zero_writes += 1;
    }
    writes.push(OramWrite::from_buffers(location, old, new));
}

#[derive(Debug)]
pub(crate) struct OramState {
    pub parameters: OramParameters,
    pub entries: Vec<MapEntry>,
    pub position_map: Vec<Option<usize>>,
    pub stash: Vec<OramBlock>,
    pub storage: OramStorage,
    pub access_counter: u64,
    pub cipher: StoreCipher,
}

impl Clone for OramState {
    fn clone(&self) -> Self {
        fn clone_vec_with_min_capacity<T: Clone>(
            values: &[T],
            current_capacity: usize,
            min_capacity: usize,
        ) -> Vec<T> {
            let mut cloned = Vec::with_capacity(current_capacity.max(min_capacity));
            cloned.extend(values.iter().cloned());
            cloned
        }

        let stash_capacity = working_stash_capacity(&self.parameters)
            .expect("public ORAM stash capacity bound overflowed during clone");
        Self {
            parameters: self.parameters.clone(),
            entries: clone_vec_with_min_capacity(
                &self.entries,
                self.entries.capacity(),
                self.parameters.capacity,
            ),
            position_map: clone_vec_with_min_capacity(
                &self.position_map,
                self.position_map.capacity(),
                self.parameters.capacity,
            ),
            stash: clone_vec_with_min_capacity(&self.stash, self.stash.capacity(), stash_capacity),
            storage: self.storage.clone(),
            access_counter: self.access_counter,
            cipher: self.cipher.clone(),
        }
    }
}

impl OramState {
    fn wipe_secrets(&mut self) {
        for entry in &mut self.entries {
            entry.wipe_secrets();
        }
        for leaf in &mut self.position_map {
            *leaf = None;
        }
        for block in &mut self.stash {
            block.wipe_secrets();
        }
        for page in &mut self.storage.directory_pages {
            page.fill(0);
        }
        for bucket in &mut self.storage.buckets {
            bucket.fill(0);
        }
        self.storage.access_counter_slot.fill(0);
        self.access_counter = 0;
    }
}

impl Drop for OramState {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug, Default)]
pub(crate) enum PathOramLeafCoinSource {
    #[default]
    Random,
    Injected(VecDeque<usize>),
}

impl Drop for PathOramLeafCoinSource {
    fn drop(&mut self) {
        if let Self::Injected(queue) = self {
            for leaf in queue.iter_mut() {
                *leaf = 0;
            }
        }
    }
}

impl PathOramLeafCoinSource {
    pub(crate) fn random() -> Self {
        Self::Random
    }

    pub(crate) fn require_injected() -> Self {
        Self::Injected(VecDeque::new())
    }

    pub(crate) fn install(&mut self, coins: Vec<usize>) {
        *self = Self::Injected(VecDeque::from(coins));
    }

    pub(crate) fn take_leaf(
        &mut self,
        object_name: &str,
        leaf_count: usize,
        rng: &mut ChaCha20Rng,
    ) -> Result<usize> {
        match self {
            Self::Random => Ok(sample_leaf(rng, leaf_count)),
            Self::Injected(queue) => {
                let leaf = queue.pop_front().ok_or_else(|| {
                    anyhow!(
                        "path ORAM object {} requires injected fresh-leaf coins, but the tape is exhausted",
                        object_name
                    )
                })?;
                if leaf >= leaf_count.max(1) {
                    bail!(
                        "path ORAM object {} received injected leaf {} outside leaf count {}",
                        object_name,
                        leaf,
                        leaf_count.max(1)
                    );
                }
                Ok(leaf)
            }
        }
    }

    pub(crate) fn ensure_exhausted(&self, object_name: &str) -> Result<()> {
        match self {
            Self::Random => Ok(()),
            Self::Injected(queue) if queue.is_empty() => Ok(()),
            Self::Injected(queue) => bail!(
                "path ORAM object {} left {} injected fresh-leaf coins unused",
                object_name,
                queue.len()
            ),
        }
    }
}

impl OramState {
    pub(crate) fn placeholder() -> Self {
        Self {
            parameters: OramParameters {
                scheme: String::new(),
                capacity: 0,
                block_size: 0,
                bucket_size: 0,
                bucket_count: 0,
                blocks_per_bucket: 0,
                tree_height: 0,
                stash_bound: 0,
                recursion_depth: 0,
                metadata_pages: 0,
                metadata_pages_per_access: 0,
                accesses_per_call: 0,
                buckets_per_access: 0,
                directory_page_entries: 0,
                directory_page_bytes: 0,
            },
            entries: Vec::new(),
            position_map: Vec::new(),
            stash: Vec::new(),
            storage: OramStorage {
                directory_pages: Vec::new(),
                buckets: Vec::new(),
                access_counter_slot: Vec::new(),
            },
            access_counter: 0,
            cipher: StoreCipher::random(),
        }
    }

    pub(crate) fn clone_for_tx(
        &self,
        spec: &StateObject,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let mut cloned = Self {
            parameters: self.parameters.clone(),
            entries: Vec::with_capacity(self.parameters.capacity),
            position_map: Vec::with_capacity(self.parameters.capacity),
            stash: Vec::with_capacity(working_stash_capacity(&self.parameters)?),
            storage: self.storage.clone(),
            access_counter: self.access_counter,
            cipher: self.cipher.clone(),
        };
        cloned.refresh_from_storage(spec, allocator)?;
        Ok(cloned)
    }

    pub(crate) fn restore_from_old(
        &mut self,
        spec: &StateObject,
        old: &Self,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        if self.parameters != old.parameters {
            bail!(
                "cannot restore ORAM state for {} across differing public parameters",
                spec.name
            );
        }
        if self.storage.directory_pages.capacity() < old.storage.directory_pages.len() {
            bail!(
                "directory page buffer capacity {} fell below public page count {} for {}",
                self.storage.directory_pages.capacity(),
                old.storage.directory_pages.len(),
                spec.name
            );
        }
        if self.storage.buckets.capacity() < old.storage.buckets.len() {
            bail!(
                "bucket buffer capacity {} fell below public bucket count {} for {}",
                self.storage.buckets.capacity(),
                old.storage.buckets.len(),
                spec.name
            );
        }
        if self.storage.access_counter_slot.capacity() < old.storage.access_counter_slot.len() {
            bail!(
                "counter buffer capacity {} fell below public counter size {} for {}",
                self.storage.access_counter_slot.capacity(),
                old.storage.access_counter_slot.len(),
                spec.name
            );
        }
        self.storage
            .directory_pages
            .clone_from(&old.storage.directory_pages);
        self.storage.buckets.clone_from(&old.storage.buckets);
        self.storage
            .access_counter_slot
            .clone_from(&old.storage.access_counter_slot);
        self.access_counter = old.access_counter;
        self.refresh_from_storage(spec, allocator)
    }

    pub(crate) fn cold_commit(&mut self) {
        for leaf in &mut self.position_map {
            *leaf = None;
        }
        self.entries.clear();
        self.position_map.clear();
        self.stash.clear();
    }

    pub(crate) fn path_position_map_from_storage(
        &self,
        spec: &StateObject,
    ) -> Result<Vec<Option<usize>>> {
        let scratch = self.parameters.directory_page_bytes.max(8);
        let mut allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: scratch.saturating_mul(4),
            max_stack_words: 0,
            scratch_bytes: scratch,
            max_kernel_ops: 0,
        });
        let position_map = decode_path_position_map_pages(
            spec,
            &self.parameters,
            &self.cipher,
            &self.storage.directory_pages,
            &mut allocator,
        )?;
        allocator
            .finish()
            .expect("position-map decode scratch should be wiped");
        Ok(position_map)
    }

    pub(crate) fn instantiate(spec: &StateObject, rng: &mut ChaCha20Rng) -> Result<Self> {
        let parameters = OramParameters::for_spec(spec)?;
        let cipher = StoreCipher::from_rng(rng);
        let empty_entry = empty_map_entry(spec)?;
        let entries = vec![empty_entry.clone(); parameters.capacity];
        if parameters.is_surrogate() {
            let directory_pages = (0..parameters.metadata_pages)
                .map(|page| {
                    let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
                    let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(entries.len());
                    let mut payload =
                        encode_oram_directory_page(&entries[start..end], &empty_entry);
                    let aad = oram_meta_aad(spec, page);
                    cipher.seal_and_wipe(aad.as_bytes(), &mut payload, rng)
                })
                .collect();
            let buckets = (0..parameters.bucket_count)
                .map(|index| {
                    let aad = oram_bucket_aad(spec, index);
                    cipher.filler(aad.as_bytes(), parameters.bucket_size, rng)
                })
                .collect();
            let mut state = Self {
                parameters,
                entries,
                position_map: Vec::new(),
                stash: Vec::new(),
                storage: OramStorage {
                    directory_pages,
                    buckets,
                    access_counter_slot: {
                        let mut payload = 0u64.to_be_bytes();
                        cipher.seal_and_wipe(oram_counter_aad(spec).as_bytes(), &mut payload, rng)
                    },
                },
                access_counter: 0,
                cipher,
            };
            state.cold_commit();
            Ok(state)
        } else {
            let position_map = vec![None; parameters.capacity];
            let stash = Vec::with_capacity(working_stash_capacity(&parameters)?);
            let bootstrap_scratch = parameters
                .directory_page_bytes
                .max(parameters.bucket_size)
                .max(8);
            let mut bootstrap_allocator = AllocatorSession::new(AllocatorPlan {
                arena_bytes: bootstrap_scratch.saturating_mul(4),
                max_stack_words: 0,
                scratch_bytes: bootstrap_scratch,
                max_kernel_ops: 0,
            });
            let directory_pages = encode_path_metadata_pages(
                spec,
                &parameters,
                &cipher,
                &position_map,
                &stash,
                &mut bootstrap_allocator,
                rng,
            )?;
            bootstrap_allocator
                .finish()
                .expect("bootstrap ORAM metadata scratch should be wiped");
            let buckets = (0..parameters.bucket_count)
                .map(|index| {
                    let aad = oram_bucket_aad(spec, index);
                    let empty_bucket = OramBucket::empty(spec, index)?;
                    let mut payload = empty_bucket.serialize(spec)?;
                    Ok(cipher.seal_and_wipe(aad.as_bytes(), &mut payload, rng))
                })
                .collect::<Result<Vec<_>>>()?;
            let mut state = Self {
                parameters,
                entries,
                position_map,
                stash,
                storage: OramStorage {
                    directory_pages,
                    buckets,
                    access_counter_slot: {
                        let mut payload = 0u64.to_be_bytes();
                        cipher.seal_and_wipe(oram_counter_aad(spec).as_bytes(), &mut payload, rng)
                    },
                },
                access_counter: 0,
                cipher,
            };
            state.cold_commit();
            Ok(state)
        }
    }

    pub(crate) fn refresh_from_storage(
        &mut self,
        spec: &StateObject,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        self.access_counter = {
            let _counter_guard = allocator.reserve_guard(ScratchRegion::IoScratch, 8)?;
            self.cipher
                .with_opened_payload(
                    oram_counter_aad(spec).as_bytes(),
                    8,
                    &self.storage.access_counter_slot,
                    |counter_bytes| {
                        let mut counter = [0u8; 8];
                        counter.copy_from_slice(counter_bytes);
                        u64::from_be_bytes(counter)
                    },
                )
                .ok_or_else(|| anyhow!("failed to decode ORAM counter for {}", spec.name))?
        };
        if self.parameters.is_surrogate() {
            Self::decode_surrogate_entries_from_storage_into(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
                allocator,
                &mut self.entries,
            )?;
        } else {
            decode_path_metadata_pages_into(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
                allocator,
                &mut self.position_map,
                &mut self.stash,
            )?;
            self.reconstruct_path_entries_into(spec, allocator)?;
        }
        Ok(())
    }

    fn decode_surrogate_entries_from_storage_into(
        spec: &StateObject,
        parameters: &OramParameters,
        cipher: &StoreCipher,
        directory_pages: &[Vec<u8>],
        allocator: &mut AllocatorSession,
        entries: &mut Vec<MapEntry>,
    ) -> Result<()> {
        if entries.capacity() < parameters.capacity {
            bail!(
                "surrogate ORAM entry buffer capacity {} fell below public slot count {} for {}",
                entries.capacity(),
                parameters.capacity,
                spec.name
            );
        }
        entries.clear();
        for (page_index, page) in directory_pages.iter().enumerate() {
            if entries.len() == parameters.capacity {
                break;
            }
            let aad = oram_meta_aad(spec, page_index);
            let _page_guard = allocator
                .reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
            let remaining = parameters.capacity - entries.len();
            cipher
                .with_opened_payload(
                    aad.as_bytes(),
                    parameters.directory_page_bytes,
                    page,
                    |payload| decode_oram_directory_page_into(payload, spec, remaining, entries),
                )
                .ok_or_else(|| {
                    anyhow!("failed to decode ORAM metadata page for {}", spec.name)
                })??;
        }
        Ok(())
    }

    pub(crate) fn get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
        rng: &mut ChaCha20Rng,
    ) -> Result<(Value, OramTranscript)> {
        if self.parameters.is_surrogate() {
            let value = self
                .entries
                .iter()
                .find(|entry| entry.occupied && entry.key == *key)
                .map(|entry| entry.value.clone())
                .unwrap_or_else(|| Value::zero_for_type(&spec.value_type));
            Ok((value, self.surrogate_access_transcript(spec)))
        } else {
            self.path_get(spec, key, allocator, leaf_coins, rng)
        }
    }

    pub(crate) fn put(
        &mut self,
        spec: &StateObject,
        key: Value,
        value: Value,
        apply: bool,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
        rng: &mut ChaCha20Rng,
    ) -> Result<OramTranscript> {
        if self.parameters.is_surrogate() {
            let transcript = self.surrogate_access_transcript(spec);
            if apply {
                let value_is_zero = value.is_zero_like();
                if let Some(entry) = self
                    .entries
                    .iter_mut()
                    .find(|entry| entry.occupied && entry.key == key)
                {
                    if value_is_zero {
                        *entry = empty_map_entry(spec)?;
                    } else {
                        entry.value = value;
                    }
                } else if !value_is_zero {
                    let entry = self
                        .entries
                        .iter_mut()
                        .find(|entry| !entry.occupied)
                        .ok_or_else(|| anyhow!("map {} exceeded public capacity", spec.name))?;
                    entry.occupied = true;
                    entry.key = key;
                    entry.value = value;
                }
            }
            Ok(transcript)
        } else {
            self.path_put(spec, key, value, apply, allocator, leaf_coins, rng)
        }
    }

    pub(crate) fn commit(
        self,
        spec: &StateObject,
        old: &Self,
        aborted: bool,
        allocator: &mut AllocatorSession,
        rng: &mut ChaCha20Rng,
    ) -> Result<OramCommit> {
        if self.parameters.is_surrogate() {
            let mut next = self;
            if aborted {
                Self::decode_surrogate_entries_from_storage_into(
                    spec,
                    &old.parameters,
                    &old.cipher,
                    &old.storage.directory_pages,
                    allocator,
                    &mut next.entries,
                )?;
            }
            let empty_entry = empty_map_entry(spec)?;
            let mut writes = Vec::with_capacity(
                old.storage.directory_pages.len() + next.parameters.buckets_per_access + 1,
            );
            let mut zero_writes = 0usize;
            for page in 0..old.storage.directory_pages.len() {
                let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
                let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(next.entries.len());
                let _page_guard = allocator.reserve_guard(
                    ScratchRegion::IoScratch,
                    next.parameters.directory_page_bytes,
                )?;
                let mut payload =
                    encode_oram_directory_page(&next.entries[start..end], &empty_entry);
                let aad = oram_meta_aad(spec, page);
                if !next.cipher.seal_and_wipe_into(
                    aad.as_bytes(),
                    &mut payload,
                    rng,
                    &mut next.storage.directory_pages[page],
                ) {
                    bail!(
                        "sealed surrogate metadata buffer for {}@meta{} fell below required public ciphertext size",
                        spec.name,
                        page
                    );
                }
                record_oram_write(
                    &mut writes,
                    &mut zero_writes,
                    format!("{}@meta{page}", spec.name),
                    &old.storage.directory_pages[page],
                    &next.storage.directory_pages[page],
                );
            }
            let next_counter = old.access_counter + 1;
            {
                let _counter_guard = allocator.reserve_guard(ScratchRegion::IoScratch, 8)?;
                let mut payload = next_counter.to_be_bytes();
                if !next.cipher.seal_and_wipe_into(
                    oram_counter_aad(spec).as_bytes(),
                    &mut payload,
                    rng,
                    &mut next.storage.access_counter_slot,
                ) {
                    bail!(
                        "sealed surrogate counter buffer for {} fell below required public ciphertext size",
                        spec.name
                    );
                }
            }
            record_oram_write(
                &mut writes,
                &mut zero_writes,
                format!("{}@counter", spec.name),
                &old.storage.access_counter_slot,
                &next.storage.access_counter_slot,
            );
            for_each_surrogate_bucket_window(
                next.parameters.buckets_per_access,
                next.access_counter as usize,
                next.storage.buckets.len(),
                |index| {
                    let _bucket_guard = allocator
                        .reserve_guard(ScratchRegion::IoScratch, next.parameters.bucket_size)?;
                    let mut payload =
                        OramBucket::from_entries(spec, &next.entries, old.access_counter, index)?
                            .serialize(spec)?;
                    let aad = oram_bucket_aad(spec, index);
                    if !next.cipher.seal_and_wipe_into(
                        aad.as_bytes(),
                        &mut payload,
                        rng,
                        &mut next.storage.buckets[index],
                    ) {
                        bail!(
                            "sealed surrogate bucket buffer for {}@bucket{} fell below required public ciphertext size",
                            spec.name,
                            index
                        );
                    }
                    record_oram_write(
                        &mut writes,
                        &mut zero_writes,
                        format!("{}@bucket{index}", spec.name),
                        &old.storage.buckets[index],
                        &next.storage.buckets[index],
                    );
                    Ok::<(), anyhow::Error>(())
                },
            )?;
            next.access_counter = next_counter;
            Ok(OramCommit {
                next,
                writes,
                zero_writes,
            })
        } else {
            let mut next = self;
            if aborted {
                next.restore_from_old(spec, old, allocator)?;
            }
            let _ = rng;
            Ok(OramCommit {
                next,
                writes: Vec::new(),
                zero_writes: 0,
            })
        }
    }

    fn surrogate_access_transcript(&self, spec: &StateObject) -> OramTranscript {
        let public_access_count =
            1 + self.storage.directory_pages.len() + self.parameters.buckets_per_access;
        let mut logical_accesses = Vec::with_capacity(public_access_count);
        let mut physical_reads = Vec::with_capacity(public_access_count);

        logical_accesses.push(LogicalEvent {
            kind: "uooram_counter".into(),
            object: spec.name.clone(),
            detail: "counter".into(),
        });
        physical_reads.push(PhysicalReadEvent {
            object: spec.name.clone(),
            location: format!("{}@counter", spec.name),
            len: self.storage.access_counter_slot.len(),
        });

        for page in 0..self.storage.directory_pages.len() {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_meta_scan".into(),
                object: spec.name.clone(),
                detail: format!("page:{page}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@meta{page}", spec.name),
                len: self.storage.directory_pages[page].len(),
            });
        }

        for_each_surrogate_bucket_window(
            self.parameters.buckets_per_access,
            self.access_counter as usize,
            self.storage.buckets.len(),
            |index| {
                logical_accesses.push(LogicalEvent {
                    kind: "uooram_bucket_scan".into(),
                    object: spec.name.clone(),
                    detail: format!("bucket:{index}"),
                });
                physical_reads.push(PhysicalReadEvent {
                    object: spec.name.clone(),
                    location: format!("{}@bucket{index}", spec.name),
                    len: self.storage.buckets[index].len(),
                });
                Ok::<(), ()>(())
            },
        )
        .expect("surrogate bucket-window walk is infallible");

        OramTranscript {
            logical_accesses,
            physical_reads,
            physical_writes: Vec::new(),
            zero_writes: 0,
            path_leaf: None,
            path_transition: None,
        }
    }

    fn access_leaf_for_key(
        &self,
        spec: &StateObject,
        key: &Value,
        leaf_coins: &mut PathOramLeafCoinSource,
        rng: &mut ChaCha20Rng,
    ) -> Result<usize> {
        if let Some(slot) = self.find_slot(key) {
            self.position_map
                .get(slot)
                .and_then(|leaf| *leaf)
                .map(Ok)
                .unwrap_or_else(|| {
                    leaf_coins.take_leaf(&spec.name, self.parameters.leaf_count(), rng)
                })
        } else {
            leaf_coins.take_leaf(&spec.name, self.parameters.leaf_count(), rng)
        }
    }

    fn find_slot(&self, key: &Value) -> Option<usize> {
        self.entries
            .iter()
            .position(|entry| entry.occupied && entry.key == *key)
    }

    fn path_access_transcript(&self, spec: &StateObject, leaf: usize) -> OramTranscript {
        let public_access_count =
            1 + self.storage.directory_pages.len() + self.parameters.buckets_per_access;
        let mut logical_accesses = Vec::with_capacity(public_access_count);
        let mut physical_reads = Vec::with_capacity(public_access_count);

        logical_accesses.push(LogicalEvent {
            kind: "uooram_counter".into(),
            object: spec.name.clone(),
            detail: "counter".into(),
        });
        physical_reads.push(PhysicalReadEvent {
            object: spec.name.clone(),
            location: format!("{}@counter", spec.name),
            len: self.storage.access_counter_slot.len(),
        });

        for page in 0..self.storage.directory_pages.len() {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_metadata_load".into(),
                object: spec.name.clone(),
                detail: format!("page:{page}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@meta{page}", spec.name),
                len: self.storage.directory_pages[page].len(),
            });
        }

        for_each_bucket_on_leaf_path_root_to_leaf(self.parameters.leaf_count(), leaf, |index| {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_path_read".into(),
                object: spec.name.clone(),
                detail: format!("bucket:{index}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@bucket{index}", spec.name),
                len: self.storage.buckets[index].len(),
            });
        });

        OramTranscript {
            logical_accesses,
            physical_reads,
            physical_writes: Vec::new(),
            zero_writes: 0,
            path_leaf: Some(leaf),
            path_transition: None,
        }
    }

    fn reconstruct_path_entries_into(
        &mut self,
        spec: &StateObject,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        let key_type = spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
        if self.entries.capacity() < self.parameters.capacity {
            bail!(
                "entry buffer capacity {} fell below required public bound {} for {}",
                self.entries.capacity(),
                self.parameters.capacity,
                spec.name
            );
        }
        self.entries.clear();
        self.entries
            .resize(self.parameters.capacity, empty_map_entry(spec)?);
        let mut live_slots = vec![None; self.parameters.capacity];
        for block in &self.stash {
            if block.occupied {
                validate_live_path_block(
                    spec,
                    &self.parameters,
                    &self.position_map,
                    &mut live_slots,
                    block,
                )?;
                self.entries[block.slot_index] = MapEntry {
                    occupied: true,
                    key: block.key.clone(),
                    value: block.value.clone(),
                };
            }
        }
        for index in 0..self.parameters.bucket_count {
            let aad = oram_bucket_aad(spec, index);
            let _bucket_guard =
                allocator.reserve_guard(ScratchRegion::IoScratch, self.parameters.bucket_size)?;
            self.cipher
                .with_opened_payload(
                    aad.as_bytes(),
                    self.parameters.bucket_size,
                    &self.storage.buckets[index],
                    |payload| {
                        decode_bucket_payload(spec, index, payload, |block| {
                            if !bucket_on_leaf_path(self.parameters.leaf_count(), index, block.leaf)
                            {
                                bail!(
                                    "decoded ORAM bucket {} for {} carries leaf {} off its path",
                                    index,
                                    spec.name,
                                    block.leaf
                                );
                            }
                            validate_live_path_block(
                                spec,
                                &self.parameters,
                                &self.position_map,
                                &mut live_slots,
                                &block,
                            )?;
                            let mut block = block;
                            self.entries[block.slot_index] = MapEntry {
                                occupied: true,
                                key: std::mem::replace(
                                    &mut block.key,
                                    Value::zero_for_type(key_type),
                                ),
                                value: std::mem::replace(
                                    &mut block.value,
                                    Value::zero_for_type(&spec.value_type),
                                ),
                            };
                            Ok(())
                        })
                    },
                )
                .ok_or_else(|| {
                    anyhow!("failed to decode ORAM bucket {} for {}", index, spec.name)
                })??;
        }
        for (slot_index, leaf) in self.position_map.iter().enumerate() {
            if leaf.is_some() && live_slots[slot_index].is_none() {
                bail!(
                    "decoded ORAM position map for {} references missing live block at slot {}",
                    spec.name,
                    slot_index
                );
            }
        }
        Ok(())
    }

    fn path_get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
        rng: &mut ChaCha20Rng,
    ) -> Result<(Value, OramTranscript)> {
        let access_leaf = self.access_leaf_for_key(spec, key, leaf_coins, rng)?;
        let leaf_count = self.parameters.leaf_count();
        let slot = slot_for_key(&self.entries, key);
        let prior_leaf =
            slot.and_then(|slot_index| self.position_map.get(slot_index).copied().flatten());
        let next_leaf = match slot {
            Some(_) => Some(leaf_coins.take_leaf(&spec.name, leaf_count, rng)?),
            None => None,
        };
        let return_value = self
            .entries
            .iter()
            .find(|entry| entry.occupied && entry.key == *key)
            .map(|entry| entry.value.clone())
            .unwrap_or_else(|| Value::zero_for_type(&spec.value_type));
        let (writes, zero_writes) = self.rewrite_path_for_access(
            spec,
            access_leaf,
            allocator,
            rng,
            |_entries, position_map, stash, _rng| {
                if let (Some(slot_index), Some(new_leaf)) = (slot, next_leaf) {
                    let block = find_stash_block_mut(stash, slot_index)?;
                    block.leaf = new_leaf;
                    position_map[slot_index] = Some(new_leaf);
                }
                Ok(())
            },
        )?;
        let mut transcript = self.path_access_transcript(spec, access_leaf);
        transcript.physical_writes = writes;
        transcript.zero_writes = zero_writes;
        transcript.path_transition = Some(RuntimePathOramTransitionWitness {
            object_id: spec.id,
            object_name: spec.name.clone(),
            bucket_count: self.parameters.bucket_count,
            kind: if slot.is_some() {
                RuntimePathOramTransitionKind::ReadHit
            } else {
                RuntimePathOramTransitionKind::ReadMiss
            },
            slot_index: slot,
            prior_leaf,
            next_leaf,
        });
        Ok((return_value, transcript))
    }

    fn path_put(
        &mut self,
        spec: &StateObject,
        key: Value,
        value: Value,
        apply: bool,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
        rng: &mut ChaCha20Rng,
    ) -> Result<OramTranscript> {
        let access_leaf = self.access_leaf_for_key(spec, &key, leaf_coins, rng)?;
        let leaf_count = self.parameters.leaf_count();
        let slot = slot_for_key(&self.entries, &key);
        let prior_leaf =
            slot.and_then(|slot_index| self.position_map.get(slot_index).copied().flatten());
        let insert_slot = if slot.is_none() && apply && !value.is_zero_like() {
            allocate_slot(&self.entries)
        } else {
            None
        };
        let next_leaf = match (slot, apply, value.is_zero_like(), insert_slot) {
            (Some(_), true, false, _) => Some(leaf_coins.take_leaf(&spec.name, leaf_count, rng)?),
            (None, true, false, Some(_)) => {
                Some(leaf_coins.take_leaf(&spec.name, leaf_count, rng)?)
            }
            _ => None,
        };
        let transition = if !apply {
            RuntimePathOramTransitionWitness {
                object_id: spec.id,
                object_name: spec.name.clone(),
                bucket_count: self.parameters.bucket_count,
                kind: RuntimePathOramTransitionKind::WriteNoop,
                slot_index: slot,
                prior_leaf,
                next_leaf: prior_leaf,
            }
        } else if let Some(slot_index) = slot {
            if value.is_zero_like() {
                RuntimePathOramTransitionWitness {
                    object_id: spec.id,
                    object_name: spec.name.clone(),
                    bucket_count: self.parameters.bucket_count,
                    kind: RuntimePathOramTransitionKind::WriteDelete,
                    slot_index: Some(slot_index),
                    prior_leaf,
                    next_leaf: None,
                }
            } else {
                RuntimePathOramTransitionWitness {
                    object_id: spec.id,
                    object_name: spec.name.clone(),
                    bucket_count: self.parameters.bucket_count,
                    kind: RuntimePathOramTransitionKind::WriteUpdate,
                    slot_index: Some(slot_index),
                    prior_leaf,
                    next_leaf,
                }
            }
        } else if let Some(slot_index) = insert_slot {
            RuntimePathOramTransitionWitness {
                object_id: spec.id,
                object_name: spec.name.clone(),
                bucket_count: self.parameters.bucket_count,
                kind: RuntimePathOramTransitionKind::WriteInsert,
                slot_index: Some(slot_index),
                prior_leaf: None,
                next_leaf,
            }
        } else {
            RuntimePathOramTransitionWitness {
                object_id: spec.id,
                object_name: spec.name.clone(),
                bucket_count: self.parameters.bucket_count,
                kind: RuntimePathOramTransitionKind::WriteNoop,
                slot_index: None,
                prior_leaf: None,
                next_leaf: None,
            }
        };
        let (writes, zero_writes) = self.rewrite_path_for_access(
            spec,
            access_leaf,
            allocator,
            rng,
            |entries, position_map, stash, _rng| {
                if !apply {
                    return Ok(());
                }
                match slot {
                    Some(slot_index) => {
                        if value.is_zero_like() {
                            remove_stash_block(stash, slot_index)?;
                            entries[slot_index] = empty_map_entry(spec)?;
                            position_map[slot_index] = None;
                        } else {
                            let block = find_stash_block_mut(stash, slot_index)?;
                            block.value = value.clone();
                            let new_leaf = next_leaf.expect("write update precomputes next leaf");
                            block.leaf = new_leaf;
                            entries[slot_index].value = value.clone();
                            position_map[slot_index] = Some(new_leaf);
                        }
                    }
                    None => {
                        if let Some(slot_index) = insert_slot {
                            let new_leaf = next_leaf.expect("write insert precomputes next leaf");
                            if slot_index >= entries.len() {
                                bail!("map {} exceeded public capacity", spec.name);
                            }
                            entries[slot_index] = MapEntry {
                                occupied: true,
                                key: key.clone(),
                                value: value.clone(),
                            };
                            position_map[slot_index] = Some(new_leaf);
                            stash.push(OramBlock {
                                occupied: true,
                                slot_index,
                                leaf: new_leaf,
                                key: key.clone(),
                                value: value.clone(),
                            });
                        }
                    }
                }
                Ok(())
            },
        )?;
        let mut transcript = self.path_access_transcript(spec, access_leaf);
        transcript.physical_writes = writes;
        transcript.zero_writes = zero_writes;
        transcript.path_transition = Some(transition);
        Ok(transcript)
    }

    fn rewrite_path_for_access<F>(
        &mut self,
        spec: &StateObject,
        access_leaf: usize,
        allocator: &mut AllocatorSession,
        rng: &mut ChaCha20Rng,
        update: F,
    ) -> Result<(Vec<OramWrite>, usize)>
    where
        F: FnOnce(
            &mut Vec<MapEntry>,
            &mut Vec<Option<usize>>,
            &mut Vec<OramBlock>,
            &mut ChaCha20Rng,
        ) -> Result<()>,
    {
        let mut writes = Vec::with_capacity(
            self.parameters.buckets_per_access + self.parameters.metadata_pages + 1,
        );
        let mut zero_writes = 0usize;
        let mut working_entries = std::mem::take(&mut self.entries);
        let mut working_position_map = std::mem::take(&mut self.position_map);
        let mut working_stash = std::mem::take(&mut self.stash);
        let required_stash_capacity = working_stash_capacity(&self.parameters)?;
        if working_stash.capacity() < required_stash_capacity {
            bail!(
                "working stash capacity {} fell below required public bound {} for {}",
                working_stash.capacity(),
                required_stash_capacity,
                spec.name
            );
        }

        let mut load_result = Ok(());
        for_each_bucket_on_leaf_path_root_to_leaf(
            self.parameters.leaf_count(),
            access_leaf,
            |bucket_index| {
                if load_result.is_err() {
                    return;
                }
                load_result = (|| -> Result<()> {
                    let aad = oram_bucket_aad(spec, bucket_index);
                    let _bucket_guard = allocator
                        .reserve_guard(ScratchRegion::IoScratch, self.parameters.bucket_size)?;
                    self.cipher
                        .with_opened_payload(
                            aad.as_bytes(),
                            self.parameters.bucket_size,
                            &self.storage.buckets[bucket_index],
                            |payload| {
                                decode_bucket_payload(spec, bucket_index, payload, |block| {
                                    working_stash.push(block);
                                    Ok(())
                                })
                            },
                        )
                        .ok_or_else(|| {
                            anyhow!(
                                "failed to decode ORAM bucket {} for {}",
                                bucket_index,
                                spec.name
                            )
                        })??;
                    Ok(())
                })();
            },
        );
        load_result?;

        update(
            &mut working_entries,
            &mut working_position_map,
            &mut working_stash,
            rng,
        )?;

        if working_stash.len() > self.parameters.stash_bound + self.parameters.buckets_per_access {
            bail!(
                "stash bound exceeded for {} under path ORAM candidate",
                spec.name
            );
        }

        let mut rebuild_result = Ok(());
        for_each_bucket_on_leaf_path_leaf_to_root(
            self.parameters.leaf_count(),
            access_leaf,
            |bucket_index| {
                if rebuild_result.is_err() {
                    return;
                }
                rebuild_result = (|| -> Result<()> {
                    let bucket =
                        build_path_bucket(&self.parameters, bucket_index, &mut working_stash)?;
                    let _bucket_guard = allocator
                        .reserve_guard(ScratchRegion::IoScratch, self.parameters.bucket_size)?;
                    let mut payload = bucket.serialize(spec)?;
                    let aad = oram_bucket_aad(spec, bucket_index);
                    let old_physical = self.storage.buckets[bucket_index].clone();
                    if !self.cipher.seal_and_wipe_into(
                        aad.as_bytes(),
                        &mut payload,
                        rng,
                        &mut self.storage.buckets[bucket_index],
                    ) {
                        bail!(
                            "sealed path-ORAM bucket buffer for {}@bucket{} fell below required public ciphertext size",
                            spec.name,
                            bucket_index
                        );
                    }
                    record_oram_write(
                        &mut writes,
                        &mut zero_writes,
                        format!("{}@bucket{}", spec.name, bucket_index),
                        &old_physical,
                        &self.storage.buckets[bucket_index],
                    );
                    Ok(())
                })();
            },
        );
        rebuild_result?;

        if working_stash.len() > self.parameters.stash_bound {
            bail!("stash bound exceeded for {}", spec.name);
        }

        rewrite_path_metadata_pages_in_place(
            spec,
            &self.parameters,
            &self.cipher,
            &working_position_map,
            &working_stash,
            allocator,
            rng,
            &mut self.storage.directory_pages,
            &mut writes,
            &mut zero_writes,
        )?;

        let next_counter = self.access_counter + 1;
        let old_counter_physical = self.storage.access_counter_slot.clone();
        {
            let _counter_guard = allocator.reserve_guard(ScratchRegion::IoScratch, 8)?;
            let mut payload = next_counter.to_be_bytes();
            if !self.cipher.seal_and_wipe_into(
                oram_counter_aad(spec).as_bytes(),
                &mut payload,
                rng,
                &mut self.storage.access_counter_slot,
            ) {
                bail!(
                    "sealed ORAM counter buffer for {} fell below required public ciphertext size",
                    spec.name
                );
            }
        }
        record_oram_write(
            &mut writes,
            &mut zero_writes,
            format!("{}@counter", spec.name),
            &old_counter_physical,
            &self.storage.access_counter_slot,
        );

        self.entries = working_entries;
        self.position_map = working_position_map;
        self.stash = working_stash;
        self.access_counter = next_counter;
        Ok((writes, zero_writes))
    }
}

fn oram_meta_aad(spec: &StateObject, page: usize) -> String {
    format!("oram:{}:meta:{page}", spec.name)
}

fn oram_bucket_aad(spec: &StateObject, index: usize) -> String {
    format!("oram:{}:bucket:{index}", spec.name)
}

fn oram_counter_aad(spec: &StateObject) -> String {
    format!("oram:{}:counter", spec.name)
}

fn encode_path_metadata_pages(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    position_map: &[Option<usize>],
    stash: &[OramBlock],
    allocator: &mut AllocatorSession,
    rng: &mut ChaCha20Rng,
) -> Result<Vec<Vec<u8>>> {
    let mut pages = Vec::with_capacity(parameters.metadata_pages);
    for page in 0..parameters.position_map_pages() {
        let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
        let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(position_map.len());
        let mut payload = Vec::with_capacity(parameters.directory_page_bytes);
        for entry in &position_map[start..end] {
            let encoded = match entry {
                Some(leaf) => u64::try_from(*leaf)
                    .map_err(|_| anyhow!("leaf label overflow for {}", spec.name))?,
                None => u64::MAX,
            };
            payload.extend_from_slice(&encoded.to_be_bytes());
        }
        while payload.len() < parameters.directory_page_bytes {
            payload.push(0);
        }
        let aad = oram_meta_aad(spec, page);
        let _page_guard =
            allocator.reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
        pages.push(cipher.seal_and_wipe(aad.as_bytes(), &mut payload, rng));
    }
    let empty_block = OramBlock::empty(spec)?;
    for page in 0..parameters.stash_pages() {
        let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
        let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(stash.len());
        let mut payload = Vec::with_capacity(parameters.directory_page_bytes);
        if start < stash.len() {
            for block in &stash[start..end] {
                block.serialize_into(spec, &mut payload)?;
            }
        }
        while payload.len() < parameters.directory_page_bytes {
            empty_block.serialize_into(spec, &mut payload)?;
        }
        let aad = oram_meta_aad(spec, parameters.position_map_pages() + page);
        let _page_guard =
            allocator.reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
        pages.push(cipher.seal_and_wipe(aad.as_bytes(), &mut payload, rng));
    }
    Ok(pages)
}

fn rewrite_path_metadata_pages_in_place(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    position_map: &[Option<usize>],
    stash: &[OramBlock],
    allocator: &mut AllocatorSession,
    rng: &mut ChaCha20Rng,
    directory_pages: &mut [Vec<u8>],
    writes: &mut Vec<OramWrite>,
    zero_writes: &mut usize,
) -> Result<()> {
    if directory_pages.len() != parameters.metadata_pages {
        bail!(
            "directory page count {} did not match public metadata page count {} for {}",
            directory_pages.len(),
            parameters.metadata_pages,
            spec.name
        );
    }
    let mut payload = Vec::with_capacity(parameters.directory_page_bytes);
    for page in 0..parameters.position_map_pages() {
        let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
        let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(position_map.len());
        payload.clear();
        for entry in &position_map[start..end] {
            let encoded = match entry {
                Some(leaf) => u64::try_from(*leaf)
                    .map_err(|_| anyhow!("leaf label overflow for {}", spec.name))?,
                None => u64::MAX,
            };
            payload.extend_from_slice(&encoded.to_be_bytes());
        }
        while payload.len() < parameters.directory_page_bytes {
            payload.push(0);
        }
        let aad = oram_meta_aad(spec, page);
        let _page_guard =
            allocator.reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
        let old_physical = directory_pages[page].clone();
        if !cipher.seal_and_wipe_into(
            aad.as_bytes(),
            &mut payload,
            rng,
            &mut directory_pages[page],
        ) {
            bail!(
                "sealed ORAM metadata buffer for {}@meta{} fell below required public ciphertext size",
                spec.name,
                page
            );
        }
        record_oram_write(
            writes,
            zero_writes,
            format!("{}@meta{page}", spec.name),
            &old_physical,
            &directory_pages[page],
        );
    }
    let empty_block = OramBlock::empty(spec)?;
    for page in 0..parameters.stash_pages() {
        let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
        let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(stash.len());
        payload.clear();
        if start < stash.len() {
            for block in &stash[start..end] {
                block.serialize_into(spec, &mut payload)?;
            }
        }
        while payload.len() < parameters.directory_page_bytes {
            empty_block.serialize_into(spec, &mut payload)?;
        }
        let page_index = parameters.position_map_pages() + page;
        let aad = oram_meta_aad(spec, page_index);
        let _page_guard =
            allocator.reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
        let old_physical = directory_pages[page_index].clone();
        if !cipher.seal_and_wipe_into(
            aad.as_bytes(),
            &mut payload,
            rng,
            &mut directory_pages[page_index],
        ) {
            bail!(
                "sealed ORAM metadata buffer for {}@meta{} fell below required public ciphertext size",
                spec.name,
                page_index
            );
        }
        record_oram_write(
            writes,
            zero_writes,
            format!("{}@meta{page_index}", spec.name),
            &old_physical,
            &directory_pages[page_index],
        );
    }
    Ok(())
}

#[cfg_attr(not(test), allow(dead_code))]
fn decode_path_metadata_pages(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    pages: &[Vec<u8>],
    allocator: &mut AllocatorSession,
) -> Result<(Vec<Option<usize>>, Vec<OramBlock>)> {
    let mut position_map = Vec::with_capacity(parameters.capacity);
    let mut stash = Vec::with_capacity(working_stash_capacity(parameters)?);
    decode_path_metadata_pages_into(
        spec,
        parameters,
        cipher,
        pages,
        allocator,
        &mut position_map,
        &mut stash,
    )?;
    Ok((position_map, stash))
}

fn decode_path_metadata_pages_into(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    pages: &[Vec<u8>],
    allocator: &mut AllocatorSession,
    position_map: &mut Vec<Option<usize>>,
    stash: &mut Vec<OramBlock>,
) -> Result<()> {
    decode_path_position_map_pages_into(spec, parameters, cipher, pages, allocator, position_map)?;
    let required_stash_capacity = working_stash_capacity(parameters)?;
    stash.clear();
    if stash.capacity() < required_stash_capacity {
        bail!(
            "stash buffer capacity {} fell below required public bound {} for {}",
            stash.capacity(),
            required_stash_capacity,
            spec.name
        );
    }
    for page in 0..parameters.stash_pages() {
        let page_index = parameters.position_map_pages() + page;
        let aad = oram_meta_aad(spec, page_index);
        let _page_guard =
            allocator.reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
        cipher
            .with_opened_payload(
                aad.as_bytes(),
                parameters.directory_page_bytes,
                &pages[page_index],
                |payload| -> Result<()> {
                    for block_bytes in payload.chunks_exact(parameters.block_size) {
                        let block = OramBlock::deserialize(spec, block_bytes)?;
                        if block.occupied {
                            if block.slot_index >= parameters.capacity {
                                bail!(
                                    "decoded ORAM stash for {} references out-of-range slot {}",
                                    spec.name,
                                    block.slot_index
                                );
                            }
                            if block.leaf >= parameters.leaf_count() {
                                bail!(
                                    "decoded ORAM stash for {} carries out-of-range leaf {}",
                                    spec.name,
                                    block.leaf
                                );
                            }
                            if stash.len() == parameters.stash_bound {
                                bail!(
                                    "decoded ORAM stash for {} exceeds manifest bound {}",
                                    spec.name,
                                    parameters.stash_bound
                                );
                            }
                            stash.push(block);
                        }
                    }
                    Ok(())
                },
            )
            .ok_or_else(|| anyhow!("failed to decode ORAM stash page {}", page_index))??;
    }
    Ok(())
}

fn decode_path_position_map_pages(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    pages: &[Vec<u8>],
    allocator: &mut AllocatorSession,
) -> Result<Vec<Option<usize>>> {
    let mut position_map = Vec::with_capacity(parameters.capacity);
    decode_path_position_map_pages_into(
        spec,
        parameters,
        cipher,
        pages,
        allocator,
        &mut position_map,
    )?;
    Ok(position_map)
}

fn decode_path_position_map_pages_into(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    pages: &[Vec<u8>],
    allocator: &mut AllocatorSession,
    position_map: &mut Vec<Option<usize>>,
) -> Result<()> {
    position_map.clear();
    if position_map.capacity() < parameters.capacity {
        bail!(
            "position-map buffer capacity {} fell below required public bound {} for {}",
            position_map.capacity(),
            parameters.capacity,
            spec.name
        );
    }
    for page in 0..parameters.position_map_pages() {
        let aad = oram_meta_aad(spec, page);
        let _page_guard =
            allocator.reserve_guard(ScratchRegion::IoScratch, parameters.directory_page_bytes)?;
        cipher
            .with_opened_payload(
                aad.as_bytes(),
                parameters.directory_page_bytes,
                &pages[page],
                |payload| -> Result<()> {
                    for slot in payload.chunks_exact(8).take(ORAM_DIRECTORY_PAGE_ENTRIES) {
                        if position_map.len() == parameters.capacity {
                            break;
                        }
                        let mut encoded = [0u8; 8];
                        encoded.copy_from_slice(slot);
                        let value = u64::from_be_bytes(encoded);
                        position_map.push(if value == u64::MAX {
                            None
                        } else {
                            let leaf = usize::try_from(value)
                                .map_err(|_| anyhow!("leaf label overflow for {}", spec.name))?;
                            if leaf >= parameters.leaf_count() {
                                bail!(
                                    "decoded ORAM position map for {} carries out-of-range leaf {}",
                                    spec.name,
                                    leaf
                                );
                            }
                            Some(leaf)
                        });
                    }
                    Ok(())
                },
            )
            .ok_or_else(|| anyhow!("failed to decode ORAM position map page {}", page))??;
    }
    Ok(())
}

#[cfg_attr(not(test), allow(dead_code))]
fn path_bucket_indices(leaf_count: usize, leaf: usize) -> Vec<usize> {
    let mut node = leaf_count - 1 + (leaf % leaf_count.max(1));
    let mut path = Vec::new();
    loop {
        path.push(node);
        if node == 0 {
            break;
        }
        node = (node - 1) / 2;
    }
    path.reverse();
    path
}

fn for_each_surrogate_bucket_window<E, F>(
    buckets_per_access: usize,
    access_counter: usize,
    bucket_count: usize,
    mut f: F,
) -> Result<(), E>
where
    F: FnMut(usize) -> Result<(), E>,
{
    for offset in 0..buckets_per_access {
        f((access_counter + offset) % bucket_count)?;
    }
    Ok(())
}

fn for_each_bucket_on_leaf_path_root_to_leaf<F>(leaf_count: usize, leaf: usize, mut f: F)
where
    F: FnMut(usize),
{
    fn visit<F>(node: usize, f: &mut F)
    where
        F: FnMut(usize),
    {
        if node != 0 {
            visit((node - 1) / 2, f);
        }
        f(node);
    }

    let node = leaf_count - 1 + (leaf % leaf_count.max(1));
    visit(node, &mut f);
}

fn for_each_bucket_on_leaf_path_leaf_to_root<F>(leaf_count: usize, leaf: usize, mut f: F)
where
    F: FnMut(usize),
{
    let mut node = leaf_count - 1 + (leaf % leaf_count.max(1));
    loop {
        f(node);
        if node == 0 {
            break;
        }
        node = (node - 1) / 2;
    }
}

fn bucket_on_leaf_path(leaf_count: usize, bucket_index: usize, leaf: usize) -> bool {
    let mut node = leaf_count - 1 + (leaf % leaf_count.max(1));
    loop {
        if node == bucket_index {
            return true;
        }
        if node == 0 {
            return false;
        }
        node = (node - 1) / 2;
    }
}

fn decode_bucket_payload<F>(
    spec: &StateObject,
    expected_bucket_index: usize,
    bytes: &[u8],
    mut on_block: F,
) -> Result<()>
where
    F: FnMut(OramBlock) -> Result<()>,
{
    let parameters = OramParameters::for_spec(spec)?;
    if bytes.len() != parameters.bucket_size {
        bail!(
            "unexpected ORAM bucket length for {}: {} != {}",
            spec.name,
            bytes.len(),
            parameters.bucket_size
        );
    }
    let mut bucket_index = [0u8; 8];
    bucket_index.copy_from_slice(&bytes[8..16]);
    let bucket_index = usize::try_from(u64::from_be_bytes(bucket_index))
        .map_err(|_| anyhow!("bucket index overflow for {}", spec.name))?;
    if bucket_index != expected_bucket_index {
        bail!(
            "decoded ORAM bucket header for {} claims index {} but storage location is {}",
            spec.name,
            bucket_index,
            expected_bucket_index
        );
    }
    let mut live_entry_count = [0u8; 8];
    live_entry_count.copy_from_slice(&bytes[16..24]);
    let live_entry_count = usize::try_from(u64::from_be_bytes(live_entry_count))
        .map_err(|_| anyhow!("live entry count overflow for {}", spec.name))?;
    if live_entry_count > parameters.blocks_per_bucket {
        bail!(
            "decoded ORAM bucket {} for {} exceeds block budget {}",
            bucket_index,
            spec.name,
            parameters.blocks_per_bucket
        );
    }
    let mut occupied = 0usize;
    for block in bytes[24..].chunks_exact(parameters.block_size) {
        let block = OramBlock::deserialize(spec, block)?;
        if block.occupied {
            occupied += 1;
            on_block(block)?;
        }
    }
    if occupied != live_entry_count {
        bail!(
            "decoded ORAM bucket {} for {} contains {} live blocks but header says {}",
            bucket_index,
            spec.name,
            occupied,
            live_entry_count
        );
    }
    Ok(())
}

fn validate_live_path_block(
    spec: &StateObject,
    parameters: &OramParameters,
    position_map: &[Option<usize>],
    live_slots: &mut [Option<usize>],
    block: &OramBlock,
) -> Result<()> {
    if block.slot_index >= position_map.len() {
        bail!(
            "decoded ORAM live block for {} references out-of-range slot {}",
            spec.name,
            block.slot_index
        );
    }
    if block.leaf >= parameters.leaf_count() {
        bail!(
            "decoded ORAM live block for {} carries out-of-range leaf {}",
            spec.name,
            block.leaf
        );
    }
    let expected_leaf = position_map[block.slot_index].ok_or_else(|| {
        anyhow!(
            "decoded ORAM live block for {} has slot {} but position map is empty there",
            spec.name,
            block.slot_index
        )
    })?;
    if expected_leaf != block.leaf {
        bail!(
            "decoded ORAM live block for {} disagrees with position map at slot {}: {} != {}",
            spec.name,
            block.slot_index,
            block.leaf,
            expected_leaf
        );
    }
    if live_slots[block.slot_index].replace(block.leaf).is_some() {
        bail!(
            "decoded ORAM state for {} contains duplicate live blocks for slot {}",
            spec.name,
            block.slot_index
        );
    }
    Ok(())
}

fn sample_leaf(rng: &mut ChaCha20Rng, leaf_count: usize) -> usize {
    (rng.next_u64() as usize) % leaf_count.max(1)
}

fn slot_for_key(entries: &[MapEntry], key: &Value) -> Option<usize> {
    entries
        .iter()
        .position(|entry| entry.occupied && entry.key == *key)
}

fn allocate_slot(entries: &[MapEntry]) -> Option<usize> {
    entries.iter().position(|entry| !entry.occupied)
}

fn find_stash_block_mut(stash: &mut [OramBlock], slot: usize) -> Result<&mut OramBlock> {
    stash
        .iter_mut()
        .find(|block| block.occupied && block.slot_index == slot)
        .ok_or_else(|| anyhow!("missing ORAM block for slot {}", slot))
}

fn remove_stash_block(stash: &mut Vec<OramBlock>, slot: usize) -> Result<()> {
    let index = stash
        .iter()
        .position(|block| block.occupied && block.slot_index == slot)
        .ok_or_else(|| anyhow!("missing ORAM block for slot {}", slot))?;
    // Stash order is not part of the witness boundary; avoid shift-heavy removal.
    stash.swap_remove(index);
    Ok(())
}

fn build_path_bucket(
    parameters: &OramParameters,
    bucket_index: usize,
    stash: &mut Vec<OramBlock>,
) -> Result<OramBucket> {
    let mut blocks = Vec::with_capacity(parameters.blocks_per_bucket);
    while blocks.len() < parameters.blocks_per_bucket {
        let Some(candidate_index) = stash.iter().position(|block| {
            block.occupied && bucket_on_leaf_path(parameters.leaf_count(), bucket_index, block.leaf)
        }) else {
            break;
        };
        // Bucket fill only needs some eligible block, not a stable stash ordering.
        blocks.push(stash.swap_remove(candidate_index));
    }
    Ok(OramBucket {
        access_counter: 0,
        bucket_index,
        live_entry_count: blocks.len(),
        blocks,
    })
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct OramBlock {
    pub occupied: bool,
    pub slot_index: usize,
    pub leaf: usize,
    pub key: Value,
    pub value: Value,
}

impl OramBlock {
    fn wipe_secrets(&mut self) {
        self.occupied = false;
        self.slot_index = 0;
        self.leaf = 0;
        self.key.wipe_secrets();
        self.value.wipe_secrets();
    }

    fn empty(spec: &StateObject) -> Result<Self> {
        Ok(Self {
            occupied: false,
            slot_index: 0,
            leaf: 0,
            key: Value::zero_for_type(
                spec.key_type
                    .as_ref()
                    .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?,
            ),
            value: Value::zero_for_type(&spec.value_type),
        })
    }

    fn from_entry(entry: &MapEntry) -> Self {
        Self {
            occupied: entry.occupied,
            slot_index: 0,
            leaf: 0,
            key: entry.key.clone(),
            value: entry.value.clone(),
        }
    }

    fn serialize_into(&self, spec: &StateObject, out: &mut Vec<u8>) -> Result<()> {
        let key_type = spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
        self.serialize_into_with_key_type(spec, key_type, out)
    }

    fn serialize_into_with_key_type(
        &self,
        spec: &StateObject,
        key_type: &Type,
        out: &mut Vec<u8>,
    ) -> Result<()> {
        out.push(u8::from(self.occupied));
        if spec.oram_scheme == PATH_ORAM_SCHEME {
            out.extend_from_slice(
                &u64::try_from(self.slot_index)
                    .map_err(|_| anyhow!("slot index overflow for {}", spec.name))?
                    .to_be_bytes(),
            );
            out.extend_from_slice(
                &u64::try_from(self.leaf)
                    .map_err(|_| anyhow!("leaf label overflow for {}", spec.name))?
                    .to_be_bytes(),
            );
        }
        append_encoded_scalar_value(out, key_type, &self.key)?;
        append_encoded_scalar_value(out, &spec.value_type, &self.value)
    }

    #[cfg_attr(not(test), allow(dead_code))]
    fn deserialize(spec: &StateObject, bytes: &[u8]) -> Result<Self> {
        let key_type = spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
        let key_len = fixed_scalar_width(key_type)?;
        let value_len = fixed_scalar_width(&spec.value_type)?;
        let path_bytes = if spec.oram_scheme == PATH_ORAM_SCHEME {
            ORAM_SLOT_INDEX_BYTES + ORAM_LEAF_LABEL_BYTES
        } else {
            0
        };
        let expected_len = 1 + path_bytes + key_len + value_len;
        if bytes.len() != expected_len {
            bail!(
                "unexpected ORAM block length for {}: {} != {}",
                spec.name,
                bytes.len(),
                expected_len
            );
        }
        let occupied = match bytes[0] {
            0 => false,
            1 => true,
            other => bail!("invalid ORAM block tag {other:#x} for {}", spec.name),
        };
        let (slot_index, leaf, key_start) = if spec.oram_scheme == PATH_ORAM_SCHEME {
            let mut slot_bytes = [0u8; 8];
            slot_bytes.copy_from_slice(&bytes[1..9]);
            let mut leaf_bytes = [0u8; 8];
            leaf_bytes.copy_from_slice(&bytes[9..17]);
            (
                usize::try_from(u64::from_be_bytes(slot_bytes))
                    .map_err(|_| anyhow!("slot index overflow for {}", spec.name))?,
                usize::try_from(u64::from_be_bytes(leaf_bytes))
                    .map_err(|_| anyhow!("leaf label overflow for {}", spec.name))?,
                17,
            )
        } else {
            (0, 0, 1)
        };
        Ok(Self {
            occupied,
            slot_index,
            leaf,
            key: decode_scalar_value(key_type, &bytes[key_start..key_start + key_len])?,
            value: decode_scalar_value(
                &spec.value_type,
                &bytes[key_start + key_len..key_start + key_len + value_len],
            )?,
        })
    }
}

impl Drop for OramBlock {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct OramBucket {
    pub access_counter: u64,
    pub bucket_index: usize,
    pub live_entry_count: usize,
    pub blocks: Vec<OramBlock>,
}

impl OramBucket {
    pub(crate) fn empty(_spec: &StateObject, bucket_index: usize) -> Result<Self> {
        Ok(Self {
            access_counter: 0,
            bucket_index,
            live_entry_count: 0,
            blocks: Vec::new(),
        })
    }

    pub(crate) fn from_entries(
        spec: &StateObject,
        entries: &[MapEntry],
        access_counter: u64,
        bucket_index: usize,
    ) -> Result<Self> {
        let parameters = OramParameters::for_spec(spec)?;
        Ok(Self {
            access_counter,
            bucket_index,
            live_entry_count: entries.iter().filter(|entry| entry.occupied).count(),
            blocks: entries
                .iter()
                .filter(|entry| entry.occupied)
                .take(parameters.blocks_per_bucket)
                .map(OramBlock::from_entry)
                .collect(),
        })
    }

    pub(crate) fn serialize(&self, spec: &StateObject) -> Result<Vec<u8>> {
        let parameters = OramParameters::for_spec(spec)?;
        let mut out = Vec::with_capacity(parameters.bucket_size);
        self.serialize_into(spec, &mut out)?;
        Ok(out)
    }

    pub(crate) fn serialize_into(&self, spec: &StateObject, out: &mut Vec<u8>) -> Result<()> {
        let parameters = OramParameters::for_spec(spec)?;
        let start_len = out.len();
        out.extend_from_slice(&self.access_counter.to_be_bytes());
        out.extend_from_slice(
            &u64::try_from(self.bucket_index)
                .map_err(|_| anyhow!("bucket index overflow for {}", spec.name))?
                .to_be_bytes(),
        );
        out.extend_from_slice(
            &u64::try_from(self.live_entry_count)
                .map_err(|_| anyhow!("live entry count overflow for {}", spec.name))?
                .to_be_bytes(),
        );
        let empty_block = OramBlock::empty(spec)?;
        for slot in 0..parameters.blocks_per_bucket {
            if let Some(block) = self.blocks.get(slot) {
                block.serialize_into(spec, out)?;
            } else {
                empty_block.serialize_into(spec, out)?;
            }
        }
        if out.len() - start_len != parameters.bucket_size {
            bail!(
                "unexpected ORAM bucket length for {}: {} != {}",
                spec.name,
                out.len() - start_len,
                parameters.bucket_size
            );
        }
        Ok(())
    }

    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn deserialize(spec: &StateObject, bytes: &[u8]) -> Result<Self> {
        let parameters = OramParameters::for_spec(spec)?;
        if bytes.len() != parameters.bucket_size {
            bail!(
                "unexpected ORAM bucket length for {}: {} != {}",
                spec.name,
                bytes.len(),
                parameters.bucket_size
            );
        }
        let mut access_counter = [0u8; 8];
        access_counter.copy_from_slice(&bytes[0..8]);
        let mut bucket_index = [0u8; 8];
        bucket_index.copy_from_slice(&bytes[8..16]);
        let mut live_entry_count = [0u8; 8];
        live_entry_count.copy_from_slice(&bytes[16..24]);
        let block_size = parameters.block_size;
        let mut blocks = Vec::with_capacity(parameters.blocks_per_bucket);
        for block in bytes[24..].chunks_exact(block_size) {
            blocks.push(OramBlock::deserialize(spec, block)?);
        }
        while matches!(blocks.last(), Some(block) if !block.occupied) {
            blocks.pop();
        }
        Ok(Self {
            access_counter: u64::from_be_bytes(access_counter),
            bucket_index: usize::try_from(u64::from_be_bytes(bucket_index))
                .map_err(|_| anyhow!("bucket index overflow for {}", spec.name))?,
            live_entry_count: usize::try_from(u64::from_be_bytes(live_entry_count))
                .map_err(|_| anyhow!("live entry count overflow for {}", spec.name))?,
            blocks,
        })
    }
}

pub(crate) fn map_record_bytes(entry: &MapEntry) -> Vec<u8> {
    let mut out = Vec::with_capacity(1 + entry.key.canonical_len() + entry.value.canonical_len());
    append_map_record_bytes(&mut out, entry);
    out
}

pub(crate) fn decode_map_record(spec: &StateObject, bytes: &[u8]) -> Result<MapEntry> {
    let key_type = spec
        .key_type
        .as_ref()
        .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
    let key_len = Value::zero_for_type(key_type).canonical_len();
    let value_len = Value::zero_for_type(&spec.value_type).canonical_len();
    let expected_len = 1 + key_len + value_len;
    if bytes.len() != expected_len {
        bail!(
            "unexpected map record length for {}: {} != {}",
            spec.name,
            bytes.len(),
            expected_len
        );
    }
    let occupied = match bytes[0] {
        0x7d => true,
        0x53 => false,
        other => bail!("invalid map record tag {other:#x} for {}", spec.name),
    };
    let key = Value::decode_canonical(key_type, &bytes[1..1 + key_len])?;
    let value = Value::decode_canonical(
        &spec.value_type,
        &bytes[1 + key_len..1 + key_len + value_len],
    )?;
    Ok(MapEntry {
        occupied,
        key,
        value,
    })
}

fn append_map_record_bytes(out: &mut Vec<u8>, entry: &MapEntry) {
    out.push(if entry.occupied { 0x7d } else { 0x53 });
    entry
        .key
        .visit_canonical_chunks(&mut |chunk| out.extend_from_slice(chunk));
    entry
        .value
        .visit_canonical_chunks(&mut |chunk| out.extend_from_slice(chunk));
}

pub(crate) fn empty_map_entry(spec: &StateObject) -> Result<MapEntry> {
    Ok(MapEntry {
        occupied: false,
        key: Value::zero_for_type(
            spec.key_type
                .as_ref()
                .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?,
        ),
        value: Value::zero_for_type(&spec.value_type),
    })
}

fn oram_directory_page_count(capacity: usize) -> usize {
    capacity.max(1).div_ceil(ORAM_DIRECTORY_PAGE_ENTRIES)
}

fn encode_oram_directory_page(entries: &[MapEntry], empty_entry: &MapEntry) -> Vec<u8> {
    let mut out = Vec::with_capacity(
        ORAM_DIRECTORY_PAGE_ENTRIES
            * (1 + empty_entry.key.canonical_len() + empty_entry.value.canonical_len()),
    );
    for index in 0..ORAM_DIRECTORY_PAGE_ENTRIES {
        let entry = entries.get(index).unwrap_or(empty_entry);
        append_map_record_bytes(&mut out, entry);
    }
    out
}

fn decode_oram_directory_page_into(
    payload: &[u8],
    spec: &StateObject,
    remaining: usize,
    out: &mut Vec<MapEntry>,
) -> Result<()> {
    let parameters = OramParameters::for_spec(spec)?;
    let record_len = parameters.block_size;
    let expected_len = ORAM_DIRECTORY_PAGE_ENTRIES * record_len;
    if payload.len() != expected_len {
        bail!(
            "unexpected ORAM directory payload length for {}: {} != {}",
            spec.name,
            payload.len(),
            expected_len
        );
    }
    let key_type = spec
        .key_type
        .as_ref()
        .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
    let _key_len = fixed_scalar_width(key_type)?;
    let _value_len = fixed_scalar_width(&spec.value_type)?;
    for record in payload.chunks_exact(record_len).take(remaining) {
        out.push(decode_map_record(spec, record)?);
    }
    Ok(())
}

fn fixed_scalar_width(ty: &Type) -> Result<usize> {
    match ty {
        Type::Scalar(ScalarType::Bool) => Ok(1),
        Type::Scalar(ScalarType::Uint(_)) => Ok(32),
        Type::Scalar(ScalarType::Bytes32) => Ok(32),
        Type::Scalar(ScalarType::Address) => Ok(20),
        _ => bail!("ORAM control metadata only supports scalar map key/value types"),
    }
}

fn append_encoded_scalar_value(out: &mut Vec<u8>, ty: &Type, value: &Value) -> Result<()> {
    let expected_len = fixed_scalar_width(ty)?;
    let actual_len = value.canonical_len();
    if actual_len != expected_len {
        bail!(
            "unexpected scalar width for ORAM value: {} != {}",
            actual_len,
            expected_len
        );
    }
    value.visit_canonical_chunks(&mut |chunk| out.extend_from_slice(chunk));
    Ok(())
}

fn decode_scalar_value(ty: &Type, bytes: &[u8]) -> Result<Value> {
    let expected_len = fixed_scalar_width(ty)?;
    if bytes.len() != expected_len {
        bail!(
            "expected {expected_len} bytes for {}, got {}",
            ty.short_name(),
            bytes.len()
        );
    }
    Value::decode_canonical(ty, bytes)
}

#[cfg(test)]
mod tests {
    use super::{
        bucket_on_leaf_path, decode_path_metadata_pages, empty_map_entry,
        encode_path_metadata_pages, MapEntry, OramBlock, OramBucket, OramParameters, OramState,
        PathOramLeafCoinSource, PATH_ORAM_SCHEME, SURROGATE_ORAM_SCHEME,
    };
    use rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;
    use uo_allocator::{AllocatorPlan, AllocatorSession};
    use uo_core::ir::{BackendKind, ContainerKind, StateObject};
    use uo_core::trace::WriteClass;
    use uo_core::{ScalarType, Type, Value};
    use uo_store::StoreCipher;

    fn oram_spec() -> StateObject {
        StateObject {
            id: 7,
            name: "balances".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
            oram_scheme: SURROGATE_ORAM_SCHEME.into(),
            value_type: Type::Scalar(ScalarType::Uint(256)),
            key_type: Some(Type::Scalar(ScalarType::Address)),
            capacity: Some(8),
            confidential: true,
        }
    }

    fn path_oram_spec() -> StateObject {
        StateObject {
            oram_scheme: PATH_ORAM_SCHEME.into(),
            capacity: Some(9),
            ..oram_spec()
        }
    }

    fn allocator_for_path_oram(parameters: &OramParameters) -> AllocatorSession {
        AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters
                .directory_page_bytes
                .max(parameters.bucket_size)
                .max(8),
            max_kernel_ops: 0,
        })
    }

    fn rebuild_path_oram_logical_state(
        spec: &StateObject,
        state: &OramState,
    ) -> (Vec<MapEntry>, Vec<Option<usize>>) {
        let mut rebuilt = state.clone();
        let mut allocator = allocator_for_path_oram(&rebuilt.parameters);
        rebuilt.refresh_from_storage(spec, &mut allocator).unwrap();
        (rebuilt.entries.clone(), rebuilt.position_map.clone())
    }

    fn oram_write_shapes(writes: &[super::OramWrite]) -> Vec<(String, usize, WriteClass)> {
        writes
            .iter()
            .map(|write| (write.location.clone(), write.len, write.class))
            .collect()
    }

    fn path_oram_state_with_stash(
        spec: &StateObject,
        stash: Vec<OramBlock>,
        seed: u64,
    ) -> OramState {
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut state = OramState::instantiate(spec, &mut rng).unwrap();
        let mut entries = vec![empty_map_entry(spec).unwrap(); state.parameters.capacity];
        let mut position_map = vec![None; state.parameters.capacity];
        for block in &stash {
            entries[block.slot_index] = MapEntry {
                occupied: block.occupied,
                key: block.key.clone(),
                value: block.value.clone(),
            };
            position_map[block.slot_index] = Some(block.leaf);
        }
        state.entries = entries;
        state.position_map = position_map.clone();
        let mut working_stash =
            Vec::with_capacity(super::working_stash_capacity(&state.parameters).unwrap());
        working_stash.extend(stash.clone());
        state.stash = working_stash;
        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.storage.directory_pages = encode_path_metadata_pages(
            spec,
            &state.parameters,
            &state.cipher,
            &position_map,
            &stash,
            &mut allocator,
            &mut rng,
        )
        .unwrap();
        state
    }

    fn reseal_path_oram_metadata(
        state: &mut OramState,
        spec: &StateObject,
        position_map: &[Option<usize>],
        stash: &[OramBlock],
        seed: u64,
    ) {
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.storage.directory_pages = encode_path_metadata_pages(
            spec,
            &state.parameters,
            &state.cipher,
            position_map,
            stash,
            &mut allocator,
            &mut rng,
        )
        .unwrap();
    }

    #[test]
    fn clone_for_tx_rebuilds_path_oram_from_storage_not_live_caches() {
        let spec = path_oram_spec();
        let original_stash = vec![
            OramBlock {
                occupied: true,
                slot_index: 1,
                leaf: 3,
                key: Value::Address([0x11; 20]),
                value: Value::Uint(5),
            },
            OramBlock {
                occupied: true,
                slot_index: 4,
                leaf: 6,
                key: Value::Address([0x22; 20]),
                value: Value::Uint(9),
            },
        ];
        let mut state = path_oram_state_with_stash(&spec, original_stash.clone(), 0xC10E);
        let expected_entries = state.entries.clone();
        let expected_position_map = state.position_map.clone();
        state.entries = vec![empty_map_entry(&spec).unwrap(); state.parameters.capacity];
        state.position_map = vec![None; state.parameters.capacity];
        state.stash.clear();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let cloned = state.clone_for_tx(&spec, &mut allocator).unwrap();

        assert_eq!(cloned.entries, expected_entries);
        assert_eq!(cloned.position_map, expected_position_map);
        assert_eq!(cloned.stash, original_stash);
    }

    #[test]
    fn path_oram_write_reuses_directory_bucket_and_counter_buffers() {
        let spec = path_oram_spec();
        let original_stash = vec![
            OramBlock {
                occupied: true,
                slot_index: 1,
                leaf: 3,
                key: Value::Address([0x11; 20]),
                value: Value::Uint(5),
            },
            OramBlock {
                occupied: true,
                slot_index: 4,
                leaf: 6,
                key: Value::Address([0x22; 20]),
                value: Value::Uint(9),
            },
        ];
        let mut state = path_oram_state_with_stash(&spec, original_stash, 0xC1A0);
        let directory_page_ptrs = state
            .storage
            .directory_pages
            .iter()
            .map(|page| page.as_ptr())
            .collect::<Vec<_>>();
        let bucket_ptrs = state
            .storage
            .buckets
            .iter()
            .map(|bucket| bucket.as_ptr())
            .collect::<Vec<_>>();
        let counter_ptr = state.storage.access_counter_slot.as_ptr();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let mut rng = ChaCha20Rng::seed_from_u64(0xC1A1);
        state
            .put(
                &spec,
                Value::Address([0x11; 20]),
                Value::Uint(17),
                true,
                &mut allocator,
                &mut leaf_coins,
                &mut rng,
            )
            .unwrap();
        allocator.finish().unwrap();

        assert_eq!(
            state
                .storage
                .directory_pages
                .iter()
                .map(|page| page.as_ptr())
                .collect::<Vec<_>>(),
            directory_page_ptrs
        );
        assert_eq!(
            state
                .storage
                .buckets
                .iter()
                .map(|bucket| bucket.as_ptr())
                .collect::<Vec<_>>(),
            bucket_ptrs
        );
        assert_eq!(state.storage.access_counter_slot.as_ptr(), counter_ptr);
    }

    #[test]
    fn surrogate_commit_reads_old_entries_from_storage_on_abort() {
        let spec = oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5153);
        let mut old = OramState::instantiate(&spec, &mut rng).unwrap();
        let mut old_allocator = allocator_for_path_oram(&old.parameters);
        old.refresh_from_storage(&spec, &mut old_allocator).unwrap();
        old_allocator.finish().unwrap();
        let expected_entries = old.entries.clone();
        old.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x11; 20]),
            value: Value::Uint(7),
        };

        let mut shadow_allocator = allocator_for_path_oram(&old.parameters);
        let mut new = old.clone_for_tx(&spec, &mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let entries_ptr = new.entries.as_ptr();
        let directory_page_ptrs = new
            .storage
            .directory_pages
            .iter()
            .map(|page| page.as_ptr())
            .collect::<Vec<_>>();
        let bucket_ptrs = new
            .storage
            .buckets
            .iter()
            .map(|bucket| bucket.as_ptr())
            .collect::<Vec<_>>();
        let counter_ptr = new.storage.access_counter_slot.as_ptr();
        new.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x22; 20]),
            value: Value::Uint(9),
        };

        let mut commit_allocator = allocator_for_path_oram(&new.parameters);
        let mut commit_rng = ChaCha20Rng::seed_from_u64(0x9191);
        let commit = new
            .commit(&spec, &old, true, &mut commit_allocator, &mut commit_rng)
            .unwrap();
        commit_allocator.finish().unwrap();

        assert_eq!(commit.next.entries, expected_entries);
        assert_eq!(commit.next.entries.as_ptr(), entries_ptr);
        assert_eq!(
            commit
                .next
                .storage
                .directory_pages
                .iter()
                .map(|page| page.as_ptr())
                .collect::<Vec<_>>(),
            directory_page_ptrs
        );
        assert_eq!(
            commit
                .next
                .storage
                .buckets
                .iter()
                .map(|bucket| bucket.as_ptr())
                .collect::<Vec<_>>(),
            bucket_ptrs
        );
        assert_eq!(
            commit.next.storage.access_counter_slot.as_ptr(),
            counter_ptr
        );
        assert_eq!(commit.next.access_counter, 1);

        let mut rebuilt = commit.next.clone();
        let mut refresh_allocator = allocator_for_path_oram(&rebuilt.parameters);
        rebuilt
            .refresh_from_storage(&spec, &mut refresh_allocator)
            .unwrap();
        refresh_allocator.finish().unwrap();
        assert_eq!(rebuilt.entries, expected_entries);
    }

    #[test]
    fn typed_bucket_roundtrips_fixed_shape() {
        let spec = oram_spec();
        let bucket = OramBucket {
            access_counter: 9,
            bucket_index: 3,
            live_entry_count: 2,
            blocks: vec![
                super::OramBlock {
                    occupied: true,
                    slot_index: 0,
                    leaf: 0,
                    key: Value::Address([0x11; 20]),
                    value: Value::Uint(5),
                },
                super::OramBlock {
                    occupied: true,
                    slot_index: 0,
                    leaf: 0,
                    key: Value::Address([0x22; 20]),
                    value: Value::Uint(7),
                },
            ],
        };
        let bytes = bucket.serialize(&spec).unwrap();
        assert_eq!(
            bytes.len(),
            OramParameters::for_spec(&spec).unwrap().bucket_size
        );
        assert_eq!(OramBucket::deserialize(&spec, &bytes).unwrap(), bucket);
    }

    #[test]
    fn decode_bucket_payload_rejects_header_index_mismatch() {
        let spec = path_oram_spec();
        let bucket = OramBucket {
            access_counter: 0,
            bucket_index: 0,
            live_entry_count: 1,
            blocks: vec![OramBlock {
                occupied: true,
                slot_index: 0,
                leaf: 0,
                key: Value::Address([0x11; 20]),
                value: Value::Uint(5),
            }],
        };
        let bytes = bucket.serialize(&spec).unwrap();
        let err = super::decode_bucket_payload(&spec, 1, &bytes, |_block| Ok(())).unwrap_err();
        assert!(err
            .to_string()
            .contains("claims index 0 but storage location is 1"));
    }

    #[test]
    fn decode_bucket_payload_rejects_live_count_underreport() {
        let spec = path_oram_spec();
        let bucket = OramBucket {
            access_counter: 0,
            bucket_index: 0,
            live_entry_count: 0,
            blocks: vec![OramBlock {
                occupied: true,
                slot_index: 0,
                leaf: 0,
                key: Value::Address([0x22; 20]),
                value: Value::Uint(7),
            }],
        };
        let bytes = bucket.serialize(&spec).unwrap();
        let err = super::decode_bucket_payload(&spec, 0, &bytes, |_block| Ok(())).unwrap_err();
        assert!(err
            .to_string()
            .contains("contains 1 live blocks but header says 0"));
    }

    #[test]
    fn bucket_from_entries_caps_to_public_block_budget() {
        let spec = oram_spec();
        let bucket = OramBucket::from_entries(
            &spec,
            &[
                MapEntry {
                    occupied: true,
                    key: Value::Address([0x11; 20]),
                    value: Value::Uint(1),
                },
                MapEntry {
                    occupied: true,
                    key: Value::Address([0x22; 20]),
                    value: Value::Uint(2),
                },
                MapEntry {
                    occupied: true,
                    key: Value::Address([0x33; 20]),
                    value: Value::Uint(3),
                },
            ],
            4,
            1,
        )
        .unwrap();
        assert_eq!(bucket.blocks.len(), 2);
        assert_eq!(bucket.live_entry_count, 3);
    }

    #[test]
    fn map_entry_wipe_secrets_clears_logical_contents() {
        let mut entry = MapEntry {
            occupied: true,
            key: Value::Address([0x11; 20]),
            value: Value::Uint(9),
        };
        entry.wipe_secrets();
        assert!(!entry.occupied);
        assert_eq!(entry.key, Value::Address([0u8; 20]));
        assert_eq!(entry.value, Value::Uint(0));
    }

    #[test]
    fn oram_block_wipe_secrets_clears_hidden_state() {
        let mut block = super::OramBlock {
            occupied: true,
            slot_index: 5,
            leaf: 7,
            key: Value::Address([0x22; 20]),
            value: Value::Uint(11),
        };
        block.wipe_secrets();
        assert!(!block.occupied);
        assert_eq!(block.slot_index, 0);
        assert_eq!(block.leaf, 0);
        assert_eq!(block.key, Value::Address([0u8; 20]));
        assert_eq!(block.value, Value::Uint(0));
    }

    #[test]
    fn path_oram_metadata_decode_rejects_stash_overflow() {
        let spec = path_oram_spec();
        let parameters = OramParameters::for_spec(&spec).unwrap();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5EED);
        let cipher = StoreCipher::random();
        let mut encode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
        });
        let position_map = vec![None; parameters.capacity];
        let stash = (0..=parameters.stash_bound)
            .map(|index| OramBlock {
                occupied: true,
                slot_index: index % parameters.capacity.max(1),
                leaf: index % parameters.leaf_count().max(1),
                key: Value::Address([index as u8; 20]),
                value: Value::Uint(index as u128),
            })
            .collect::<Vec<_>>();
        let pages = encode_path_metadata_pages(
            &spec,
            &parameters,
            &cipher,
            &position_map,
            &stash,
            &mut encode_allocator,
            &mut rng,
        )
        .unwrap();
        let mut decode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
        });
        let err =
            decode_path_metadata_pages(&spec, &parameters, &cipher, &pages, &mut decode_allocator)
                .unwrap_err();
        assert!(err
            .to_string()
            .contains("decoded ORAM stash for balances exceeds manifest bound"));
    }

    #[test]
    fn bucket_on_leaf_path_matches_materialized_path() {
        let spec = path_oram_spec();
        let parameters = OramParameters::for_spec(&spec).unwrap();
        for leaf in 0..parameters.leaf_count() {
            let path = super::path_bucket_indices(parameters.leaf_count(), leaf);
            for bucket_index in 0..parameters.bucket_count {
                assert_eq!(
                    bucket_on_leaf_path(parameters.leaf_count(), bucket_index, leaf),
                    path.contains(&bucket_index)
                );
            }
        }
    }

    #[test]
    fn path_oram_delete_trace_is_witness_invariant_under_stash_permutation() {
        let spec = path_oram_spec();
        let base_stash = vec![
            OramBlock {
                occupied: true,
                slot_index: 0,
                leaf: 0,
                key: Value::Address([0x10; 20]),
                value: Value::Uint(1),
            },
            OramBlock {
                occupied: true,
                slot_index: 1,
                leaf: 1,
                key: Value::Address([0x20; 20]),
                value: Value::Uint(2),
            },
            OramBlock {
                occupied: true,
                slot_index: 2,
                leaf: 2,
                key: Value::Address([0x30; 20]),
                value: Value::Uint(3),
            },
        ];
        let mut permuted_stash = base_stash.clone();
        permuted_stash.swap(0, 2);

        let mut first = path_oram_state_with_stash(&spec, base_stash, 0xA11CE);
        let mut second = path_oram_state_with_stash(&spec, permuted_stash, 0xA11CE);
        let delete_key = Value::Address([0x10; 20]);
        let delete_value = Value::Uint(0);

        let mut first_allocator = allocator_for_path_oram(&first.parameters);
        let mut second_allocator = allocator_for_path_oram(&second.parameters);
        let mut first_leaf_coins = PathOramLeafCoinSource::random();
        let mut second_leaf_coins = PathOramLeafCoinSource::random();
        let mut first_rng = ChaCha20Rng::seed_from_u64(0xD3117E);
        let mut second_rng = ChaCha20Rng::seed_from_u64(0xD3117E);

        let first_transcript = first
            .put(
                &spec,
                delete_key.clone(),
                delete_value.clone(),
                true,
                &mut first_allocator,
                &mut first_leaf_coins,
                &mut first_rng,
            )
            .unwrap();
        let second_transcript = second
            .put(
                &spec,
                delete_key,
                delete_value,
                true,
                &mut second_allocator,
                &mut second_leaf_coins,
                &mut second_rng,
            )
            .unwrap();

        assert_eq!(
            first_transcript.logical_accesses,
            second_transcript.logical_accesses
        );
        assert_eq!(
            first_transcript.physical_reads,
            second_transcript.physical_reads
        );
        assert_eq!(first_transcript.path_leaf, second_transcript.path_leaf);
        assert_eq!(
            first_transcript.path_transition,
            second_transcript.path_transition
        );
        assert_eq!(
            oram_write_shapes(&first_transcript.physical_writes),
            oram_write_shapes(&second_transcript.physical_writes)
        );
        assert_eq!(first.entries, second.entries);
        assert_eq!(first.position_map, second.position_map);
        assert_eq!(
            rebuild_path_oram_logical_state(&spec, &first),
            rebuild_path_oram_logical_state(&spec, &second)
        );
    }

    #[test]
    fn path_oram_refresh_rejects_duplicate_live_slot_across_stash_and_bucket() {
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0xBAD5EED);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
        let duplicate = OramBlock {
            occupied: true,
            slot_index: 0,
            leaf: 0,
            key: Value::Address([0x44; 20]),
            value: Value::Uint(9),
        };
        let position_map = vec![Some(0)]
            .into_iter()
            .chain(std::iter::repeat(None))
            .take(state.parameters.capacity)
            .collect::<Vec<_>>();
        reseal_path_oram_metadata(
            &mut state,
            &spec,
            &position_map,
            std::slice::from_ref(&duplicate),
            0xBAD5EED,
        );
        let bucket = OramBucket {
            access_counter: 0,
            bucket_index: 0,
            live_entry_count: 1,
            blocks: vec![duplicate],
        };
        let aad = super::oram_bucket_aad(&spec, 0);
        let mut payload = bucket.serialize(&spec).unwrap();
        state.storage.buckets[0] =
            state
                .cipher
                .seal_and_wipe(aad.as_bytes(), &mut payload, &mut rng);

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let err = state
            .refresh_from_storage(&spec, &mut allocator)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("contains duplicate live blocks for slot 0"));
    }

    #[test]
    fn path_oram_refresh_rejects_position_map_leaf_mismatch() {
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0xBADC0DE);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
        let block = OramBlock {
            occupied: true,
            slot_index: 0,
            leaf: 0,
            key: Value::Address([0x55; 20]),
            value: Value::Uint(7),
        };
        let position_map = vec![Some(1)]
            .into_iter()
            .chain(std::iter::repeat(None))
            .take(state.parameters.capacity)
            .collect::<Vec<_>>();
        reseal_path_oram_metadata(
            &mut state,
            &spec,
            &position_map,
            std::slice::from_ref(&block),
            0xBADC0DE,
        );

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let err = state
            .refresh_from_storage(&spec, &mut allocator)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("disagrees with position map at slot 0"));
    }

    #[test]
    fn path_oram_refresh_rejects_bucket_block_off_declared_path() {
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0xFACE123);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
        let leaf = state.parameters.leaf_count() - 1;
        let block = OramBlock {
            occupied: true,
            slot_index: 0,
            leaf,
            key: Value::Address([0x66; 20]),
            value: Value::Uint(13),
        };
        let position_map = vec![Some(leaf)]
            .into_iter()
            .chain(std::iter::repeat(None))
            .take(state.parameters.capacity)
            .collect::<Vec<_>>();
        reseal_path_oram_metadata(&mut state, &spec, &position_map, &[], 0xFACE123);
        let off_path_bucket = 1usize;
        assert!(!super::bucket_on_leaf_path(
            state.parameters.leaf_count(),
            off_path_bucket,
            leaf
        ));
        let bucket = OramBucket {
            access_counter: 0,
            bucket_index: off_path_bucket,
            live_entry_count: 1,
            blocks: vec![block],
        };
        let aad = super::oram_bucket_aad(&spec, off_path_bucket);
        let mut payload = bucket.serialize(&spec).unwrap();
        state.storage.buckets[off_path_bucket] =
            state
                .cipher
                .seal_and_wipe(aad.as_bytes(), &mut payload, &mut rng);

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let err = state
            .refresh_from_storage(&spec, &mut allocator)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains(&format!("carries leaf {leaf} off its path")));
    }
}
