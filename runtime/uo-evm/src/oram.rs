use crate::controller::CallRecorder;
use crate::freshness::PathOramLeafSeed;
use anyhow::{anyhow, bail, Result};
use rand_chacha::ChaCha20Rng;
use serde_json::json;
use std::collections::BTreeMap;
use uo_allocator::{AllocatorPlan, AllocatorSession};
use uo_core::ir::StateObject;
use uo_core::manifest::{
    is_path_oram_scheme, OramManifest, PATH_ORAM_PRIVATE_POSMAP_SCHEME, SURROGATE_ORAM_SCHEME,
};
use uo_core::trace::{LogicalEvent, PhysicalReadEvent, WriteClass};
use uo_core::{FixedBoxBuilder, Value};
// A production build decodes no position-map witness: the two functions
// that do are compiled into test and diagnostics builds alone.
#[cfg_attr(not(any(test, feature = "diagnostics")), allow(unused_imports))]
use uo_core::{
    RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness,
    RuntimePathOramTransitionWitness,
};
use uo_store::{sealed_record_len, StorageHandle, StoreCipher};

#[path = "generated_object_helpers.rs"]
mod generated_object_helpers;
#[path = "generated_oram_codecs.rs"]
mod generated_oram_codecs;

#[cfg(feature = "diagnostics")]
#[path = "avl_map_replay.rs"]
pub(crate) mod avl_map_replay;

#[cfg(feature = "diagnostics")]
#[path = "stash_occupancy.rs"]
pub(crate) mod stash_occupancy;

use generated_object_helpers::{
    decode_oram_directory_page_into_slice, decode_scalar_value, encode_oram_directory_page_into,
    filler_boxed_oram_payload, fixed_scalar_width, reseal_oram_payload_and_record_write,
    seal_boxed_oram_payload, with_opened_oram_payload,
};
use generated_oram_codecs::path_entries_from_storage;
pub(crate) use generated_oram_codecs::select_pending_put_value;
#[cfg_attr(not(any(test, feature = "diagnostics")), allow(unused_imports))]
use generated_oram_codecs::{
    bootstrap_empty_path_buckets, bootstrap_filler_buckets, bootstrap_oram_counter_slot,
    bootstrap_surrogate_directory_pages, clone_boxed_map_entries, cold_clone_oram_state,
    cold_commit_oram_state, decode_surrogate_entries_from_storage_into, empty_map_entry,
    empty_oram_write_batch, encode_path_metadata_pages, finish_oram_write_log,
    oram_directory_page_count, oram_write_log_capacity, oram_write_log_with_capacity,
    path_position_map_witness_leaves, push_oram_write_update, read_oram_counter_from_storage,
    refresh_path_state_from_storage, repeat_boxed_map_entries, repeat_boxed_masked_usize_options,
    rewrite_oram_counter_in_place, rewrite_surrogate_bucket_window_in_place,
    rewrite_surrogate_directory_pages_in_place, run_path_commit_put, run_path_get, run_path_put,
    run_surrogate_get, run_surrogate_put, working_stash_capacity, FixedStash, MaskedUsizeOption,
};
#[cfg_attr(not(any(test, feature = "diagnostics")), allow(unused_imports))]
use generated_oram_codecs::{
    bootstrap_tree_storage, decide_pending_tree_put, refresh_tree_state_from_storage,
    reused_fact_presence, run_tree_get, run_tree_put, tree_entries_from_storage,
    tree_position_map_witness_leaves, tree_put_accesses, tree_shape_for_spec, TreeState,
};
#[allow(unused_imports)]
pub(crate) use generated_oram_codecs::{OramBlock, OramBucket};

pub(crate) const ORAM_DIRECTORY_PAGE_ENTRIES: usize = 8;
const ORAM_SLOT_INDEX_BYTES: usize = 8;
const ORAM_LEAF_LABEL_BYTES: usize = 8;

#[derive(Debug, PartialEq, Eq)]
pub(crate) struct MapEntry {
    occupied: bool,
    key: Value,
    value: Value,
}

/// A write to a Path ORAM map held in the enclave until commit: its
/// predicate, key, and value.
#[derive(Debug)]
pub(crate) struct PendingOramPut {
    apply: bool,
    key: Value,
    value: Value,
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
    /// The public lengths of the map's sealed records: a bucket, a metadata
    /// page and the access counter.
    pub(crate) fn bucket_record_len(&self) -> usize {
        sealed_record_len(self.bucket_size)
    }

    pub(crate) fn page_record_len(&self) -> usize {
        sealed_record_len(self.directory_page_bytes)
    }

    pub(crate) fn counter_record_len(&self) -> usize {
        sealed_record_len(8)
    }

    fn is_surrogate(&self) -> bool {
        self.scheme == SURROGATE_ORAM_SCHEME
    }

    fn is_path_oram(&self) -> bool {
        is_path_oram_scheme(&self.scheme)
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

/// The sealed records of a map's storage that a state holds. The store
/// keeps every record, and a committed map holds none. A call's copy of the
/// map holds the records it read from the store until it seals their next
/// versions over them and hands those to the store: the counter and the
/// metadata pages from the call's load to its commit, and the buckets of a
/// path from the access that reads them to the next. A call that is dropped
/// leaves the store as it was, which keeps the records it replaced until
/// the call commits.
#[derive(Debug, Default)]
pub(crate) struct OramStorage {
    directory_pages: Box<[SealedPage]>,
    buckets: BucketTable,
    access_counter_slot: Box<[u8]>,
}

impl OramStorage {
    /// The storage of a map that holds no record, of `bucket_count` buckets.
    fn empty(bucket_count: usize) -> Self {
        Self {
            directory_pages: Box::default(),
            buckets: BucketTable::empty(bucket_count),
            access_counter_slot: Box::default(),
        }
    }

    /// Whether the storage holds no record.
    fn holds_none(&self) -> bool {
        self.directory_pages.is_empty()
            && self.buckets.holds_none()
            && self.access_counter_slot.is_empty()
    }

    /// Read the counter and every metadata page from the store, where they
    /// cross the storage boundary, and hold them. `trace` names each read,
    /// here and once: no access reads them again.
    fn read_counter_and_pages(
        &mut self,
        spec: &StateObject,
        parameters: &OramParameters,
        cipher: &StoreCipher,
        trace: &mut CallRecorder,
    ) -> Result<()> {
        let counter = format!("{}@counter", spec.name);
        self.access_counter_slot =
            cipher.read_stored_record(&counter, parameters.counter_record_len())?;
        trace.physical_read(&spec.name, counter, self.access_counter_slot.len());
        self.directory_pages =
            read_metadata_pages(spec, parameters, cipher, parameters.metadata_pages)?;
        for (page, sealed) in self.directory_pages.iter().enumerate() {
            let location = format!("{}@meta{page}", spec.name);
            trace.physical_read(&spec.name, location, sealed.len());
        }
        Ok(())
    }
}

/// The first `pages` metadata pages of a map, read from the store.
fn read_metadata_pages(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    pages: usize,
) -> Result<Box<[SealedPage]>> {
    let mut read = FixedBoxBuilder::new(pages);
    for page in 0..pages {
        read.push(SealedPage(cipher.read_stored_record(
            &format!("{}@meta{page}", spec.name),
            parameters.page_record_len(),
        )?))?;
    }
    read.finish()
}

/// One sealed record of a map's storage that a state holds: a bucket or a
/// metadata page it read from the store, or a deployment sealed.
#[derive(Debug)]
pub(crate) struct SealedPage(Box<[u8]>);

impl SealedPage {
    fn from_records(records: Box<[Box<[u8]>]>) -> Result<Box<[Self]>> {
        let mut pages = FixedBoxBuilder::new(records.len());
        for record in std::iter::IntoIterator::into_iter(records) {
            pages.push(Self::from(record))?;
        }
        pages.finish()
    }

    pub(crate) fn wipe(&mut self) {
        self.0.fill(0);
    }
}

impl From<Box<[u8]>> for SealedPage {
    fn from(record: Box<[u8]>) -> Self {
        Self(record)
    }
}

impl std::ops::Deref for SealedPage {
    type Target = [u8];

    fn deref(&self) -> &[u8] {
        &self.0
    }
}

impl std::ops::DerefMut for SealedPage {
    fn deref_mut(&mut self) -> &mut [u8] {
        &mut self.0
    }
}

/// The buckets of a map that a state holds, by index: those of the path an
/// access read from the store, until the next access, or every bucket a
/// deployment sealed, until the store takes them. `len` is the map's public
/// count of buckets; a committed map holds none of them.
#[derive(Debug, Default)]
pub(crate) struct BucketTable {
    len: usize,
    held: BTreeMap<usize, SealedPage>,
}

impl BucketTable {
    fn empty(len: usize) -> Self {
        Self {
            len,
            held: BTreeMap::new(),
        }
    }

    fn from_records(records: Box<[Box<[u8]>]>) -> Self {
        let len = records.len();
        let held = std::iter::IntoIterator::into_iter(records)
            .enumerate()
            .map(|(index, record)| (index, SealedPage::from(record)))
            .collect();
        Self { len, held }
    }

    /// The map's public count of buckets.
    pub(crate) fn len(&self) -> usize {
        self.len
    }

    pub(crate) fn get(&self, index: usize) -> Option<&SealedPage> {
        self.held.get(&index)
    }

    pub(crate) fn get_mut(&mut self, index: usize) -> Option<&mut SealedPage> {
        self.held.get_mut(&index)
    }

    /// Read bucket `index` from the store, where it crosses the storage
    /// boundary, and hold it in place of a copy held before.
    pub(crate) fn read(
        &mut self,
        cipher: &StoreCipher,
        spec: &StateObject,
        parameters: &OramParameters,
        index: usize,
    ) -> Result<()> {
        if index >= self.len {
            bail!(
                "bucket {} of {} is outside its {} buckets",
                index,
                spec.name,
                self.len
            );
        }
        let record = cipher.read_stored_record(
            &format!("{}@bucket{index}", spec.name),
            parameters.bucket_record_len(),
        )?;
        self.held.insert(index, SealedPage(record));
        Ok(())
    }

    /// Read every bucket from the store: what a decode of the whole map reads.
    fn read_all(
        spec: &StateObject,
        parameters: &OramParameters,
        cipher: &StoreCipher,
    ) -> Result<Self> {
        let mut table = Self::empty(parameters.bucket_count);
        for index in 0..parameters.bucket_count {
            table.read(cipher, spec, parameters, index)?;
        }
        Ok(table)
    }

    /// Drop every bucket held: the store keeps them.
    pub(crate) fn release(&mut self) {
        self.held.clear();
    }

    pub(crate) fn wipe(&mut self) {
        for page in self.held.values_mut() {
            page.wipe();
        }
    }

    fn holds_none(&self) -> bool {
        self.held.is_empty()
    }

    fn take_held(&mut self) -> BTreeMap<usize, SealedPage> {
        std::mem::take(&mut self.held)
    }
}

#[derive(Debug)]
pub(crate) struct OramWrite {
    location: String,
    len: usize,
    class: WriteClass,
}

#[derive(Debug)]
pub(crate) struct OramWriteBatch {
    writes: Box<[Option<OramWrite>]>,
    len: usize,
    zero_writes: usize,
}

#[derive(Debug)]
pub(crate) struct OramWriteLog {
    writes: Box<[Option<OramWrite>]>,
    len: usize,
    zero_writes: usize,
    overflowed: bool,
}

#[derive(Debug)]
pub(crate) struct OramTranscript {
    logical_accesses: Box<[LogicalEvent]>,
    physical_reads: Box<[PhysicalReadEvent]>,
    physical_writes: OramWriteBatch,
    path_leaf: Option<usize>,
    path_transition: Option<RuntimePathOramTransitionWitness>,
}

#[derive(Debug)]
pub(crate) struct OramCommit {
    next: OramState,
    writes: OramWriteBatch,
}

impl OramTranscript {
    pub(crate) fn into_runtime_trace_parts(
        self,
    ) -> (
        Box<[LogicalEvent]>,
        Box<[PhysicalReadEvent]>,
        OramWriteBatch,
        usize,
        Option<usize>,
        Option<RuntimePathOramTransitionWitness>,
    ) {
        let zero_writes = self.physical_writes.zero_writes();
        (
            self.logical_accesses,
            self.physical_reads,
            self.physical_writes,
            zero_writes,
            self.path_leaf,
            self.path_transition,
        )
    }
}

impl OramCommit {
    pub(crate) fn into_object_commit_parts(self) -> (OramState, OramWriteBatch, usize) {
        let zero_writes = self.writes.zero_writes();
        (self.next, self.writes, zero_writes)
    }
}

impl OramWriteBatch {
    fn empty() -> Self {
        empty_oram_write_batch()
    }

    pub(crate) fn for_each_write<F>(&self, mut visitor: F) -> Result<()>
    where
        F: FnMut(&OramWrite) -> Result<()>,
    {
        if self.len > self.writes.len() {
            bail!(
                "ORAM write batch public length {} exceeds capacity {}",
                self.len,
                self.writes.len()
            );
        }
        for index in 0..self.len {
            let slot = self.writes.get(index).ok_or_else(|| {
                anyhow!(
                    "ORAM write batch public prefix index {} missing despite length guard",
                    index
                )
            })?;
            let Some(write) = slot.as_ref() else {
                bail!("ORAM write batch missing populated public prefix entry {index}");
            };
            visitor(write)?;
        }
        Ok(())
    }

    pub(crate) fn zero_writes(&self) -> usize {
        self.zero_writes
    }
}

impl OramWriteLog {
    fn with_capacity(capacity: usize) -> Result<Self> {
        oram_write_log_with_capacity(capacity)
    }

    pub(crate) fn push_update(&mut self, location: impl Into<String>, len: usize) -> Result<()> {
        push_oram_write_update(self, location, len)
    }

    fn into_exact_batch(self) -> Result<OramWriteBatch> {
        finish_oram_write_log(self)
    }
}

#[derive(Debug)]
pub(crate) struct OramState {
    parameters: OramParameters,
    empty_entry: MapEntry,
    entries: Box<[MapEntry]>,
    position_map: Box<[MaskedUsizeOption]>,
    stash: FixedStash,
    // The private scheme's AVL map: its shape, header and stash.
    tree: Option<TreeState>,
    storage: OramStorage,
    access_counter: u64,
    cipher: StoreCipher,
}

#[derive(Debug)]
pub(crate) enum PathOramLeafCoinSource {
    Random {
        seed: PathOramLeafSeed,
        next_index: u64,
    },
    Injected {
        coins: Box<[usize]>,
        next_index: usize,
    },
}

impl OramState {
    pub(crate) fn parameters(&self) -> &OramParameters {
        &self.parameters
    }

    pub(crate) fn path_bucket_count(&self) -> usize {
        self.parameters.bucket_count
    }

    /// Whether the map is the private scheme's AVL map.
    pub(crate) fn is_tree(&self) -> bool {
        self.tree.is_some()
    }

    /// The node accesses of one put on the private scheme's tree, whose
    /// coins a call's pending writes reserve; 2 on the other schemes.
    pub(crate) fn coins_per_pending_write(&self) -> usize {
        if self.is_tree() {
            tree_put_accesses(generated_oram_codecs::tree_avl_height(
                self.parameters.capacity,
            ))
        } else {
            2
        }
    }

    /// The map's position map as a witness records it, decoded from the
    /// whole store. The runtime keeps a call's witness from call to call, so
    /// this runs for the first call and for an audit; a production build
    /// has no witness and does not have this function.
    #[cfg(any(test, feature = "diagnostics"))]
    pub(crate) fn path_position_map_witness(
        &self,
        spec: &StateObject,
    ) -> Result<RuntimePathOramPositionMapWitness> {
        // What the decoders open, outside any trace, read from the store:
        // the tree's every bucket and metadata page, the local scheme's every
        // position-map page.
        let leaves = if self.is_tree() {
            crate::instrumentation::count_witness_records(
                self.parameters.bucket_count + self.parameters.metadata_pages,
            );
            let storage = self.read_buckets_and_pages(spec)?;
            tree_position_map_witness_leaves(spec, &self.parameters, &self.cipher, &storage)?
        } else {
            crate::instrumentation::count_witness_records(self.parameters.position_map_pages());
            let pages = read_metadata_pages(
                spec,
                &self.parameters,
                &self.cipher,
                self.parameters.position_map_pages(),
            )?;
            path_position_map_witness_leaves(spec, &self.parameters, &self.cipher, &pages)?
        };
        Ok(RuntimePathOramPositionMapWitness {
            object_id: spec.id,
            object_name: spec.name.clone(),
            leaves,
        })
    }

    #[cfg(any(test, feature = "diagnostics"))]
    pub(crate) fn access_counter_witness(
        &self,
        spec: &StateObject,
    ) -> RuntimeOramAccessCounterWitness {
        RuntimeOramAccessCounterWitness {
            object_id: spec.id,
            object_name: spec.name.clone(),
            access_counter: self.access_counter,
        }
    }

    /// The map's contents for the public-state snapshot of a public map, read
    /// from storage: a Path ORAM map's values live only in its blocks, which
    /// a call reads only along the paths it accesses.
    pub(crate) fn public_state_snapshot_value(
        &self,
        spec: &StateObject,
    ) -> Result<serde_json::Value> {
        let stored_entries;
        let entries: &[MapEntry] = if self.is_tree() {
            let storage = self.read_buckets_and_pages(spec)?;
            stored_entries = tree_entries_from_storage(
                spec,
                &self.parameters,
                &self.cipher,
                &storage,
                &self.empty_entry,
            )?;
            &stored_entries
        } else if self.parameters.is_path_oram() {
            let storage = self.read_buckets_and_pages(spec)?;
            stored_entries = path_entries_from_storage(
                spec,
                &self.parameters,
                &self.cipher,
                &storage.directory_pages,
                &storage.buckets,
                &self.empty_entry,
            )?;
            &stored_entries
        } else {
            &self.entries
        };
        let entries = entries
            .iter()
            .map(|entry| {
                json!({
                    "occupied": entry.occupied,
                    "key": &entry.key,
                    "value": &entry.value,
                })
            })
            .collect::<Vec<_>>();
        Ok(json!({
            "kind": "oram_map",
            "access_counter": self.access_counter,
            "entries": entries,
        }))
    }

    /// Put the map behind a store. The map's cipher keeps the handle, so
    /// every record the map opens or seals from now on crosses to the store,
    /// and the store takes the map's records as their first, under the
    /// names the map's accesses read and write them by. The map keeps none
    /// of them.
    pub(crate) fn deploy_into_storage(
        &mut self,
        spec: &StateObject,
        storage: StorageHandle,
    ) -> Result<()> {
        self.cipher.attach_storage(storage);
        let mut records = std::mem::replace(
            &mut self.storage,
            OramStorage::empty(self.parameters.bucket_count),
        );
        for (page, record) in records.directory_pages.iter().enumerate() {
            self.cipher
                .store_first_record(&format!("{}@meta{page}", spec.name), record)?;
        }
        for (index, record) in records.buckets.take_held() {
            self.cipher
                .store_first_record(&format!("{}@bucket{index}", spec.name), &record)?;
        }
        self.cipher.store_first_record(
            &format!("{}@counter", spec.name),
            &records.access_counter_slot,
        )
    }

    /// Find the map in a store that a deployment of the same contract and
    /// secret left: how a runtime that restarts finds the map. The store
    /// keeps the map's records, and the map holds none of them. The cipher
    /// resumes at the seal count the store has reserved, so it repeats no
    /// nonce of a record the store was handed, and the map reads its access
    /// counter from the store.
    pub(crate) fn restore_from_storage(
        &mut self,
        spec: &StateObject,
        storage: StorageHandle,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        self.cipher.resume_seal_count(storage.reserved_seals());
        self.cipher.attach_storage(storage);
        let counter = self.cipher.read_stored_record(
            &format!("{}@counter", spec.name),
            self.parameters.counter_record_len(),
        )?;
        self.access_counter =
            read_oram_counter_from_storage(spec, &self.cipher, allocator, &counter)?;
        Ok(())
    }

    /// Hand each sealed record the store keeps for the map to `visit`: its
    /// metadata pages, its buckets and its counter, in that order.
    pub(crate) fn for_each_sealed_record(
        &self,
        spec: &StateObject,
        visit: &mut dyn FnMut(&[u8]),
    ) -> Result<()> {
        let pages =
            (0..self.parameters.metadata_pages).map(|page| format!("{}@meta{page}", spec.name));
        let buckets =
            (0..self.parameters.bucket_count).map(|index| format!("{}@bucket{index}", spec.name));
        for location in pages
            .chain(buckets)
            .chain(std::iter::once(format!("{}@counter", spec.name)))
        {
            crate::runtime::objects::visit_stored_record(&self.cipher, &location, &mut *visit)?;
        }
        Ok(())
    }

    /// Every bucket and metadata page of the map, read from the store: what
    /// a decode of the whole map opens.
    fn read_buckets_and_pages(&self, spec: &StateObject) -> Result<OramStorage> {
        Ok(OramStorage {
            directory_pages: read_metadata_pages(
                spec,
                &self.parameters,
                &self.cipher,
                self.parameters.metadata_pages,
            )?,
            buckets: BucketTable::read_all(spec, &self.parameters, &self.cipher)?,
            access_counter_slot: Box::default(),
        })
    }

    /// Whether the map holds no sealed record: the store keeps them all.
    pub(crate) fn holds_no_sealed_record(&self) -> bool {
        self.storage.holds_none()
    }

    #[cfg(test)]
    pub(crate) fn access_counter_for_test(&self) -> u64 {
        self.access_counter
    }

    #[cfg(test)]
    pub(crate) fn cipher_for_test(&self) -> &StoreCipher {
        &self.cipher
    }

    #[cfg(test)]
    pub(crate) fn logical_state_snapshot_for_test(
        &self,
    ) -> (Vec<MapEntry>, Vec<Option<usize>>, Vec<OramBlock>) {
        (
            self.entries
                .iter()
                .map(|entry| {
                    MapEntry::new(
                        entry.is_occupied(),
                        entry.key().clone(),
                        entry.value().clone(),
                    )
                })
                .collect(),
            self.position_map
                .iter()
                .map(|leaf| leaf.to_option())
                .collect(),
            self.stash.to_vec(),
        )
    }

    /// The map's contents as stored: every bucket and the stash.
    #[cfg(test)]
    pub(crate) fn stored_entries_for_test(&self, spec: &StateObject) -> Vec<MapEntry> {
        let storage = self.read_buckets_and_pages(spec).unwrap();
        path_entries_from_storage(
            spec,
            &self.parameters,
            &self.cipher,
            &storage.directory_pages,
            &storage.buckets,
            &self.empty_entry,
        )
        .unwrap()
        .iter()
        .map(|entry| {
            MapEntry::new(
                entry.is_occupied(),
                entry.key().clone(),
                entry.value().clone(),
            )
        })
        .collect()
    }

    #[cfg(test)]
    pub(crate) fn logical_state_ptrs_for_test(
        &self,
    ) -> (*const MapEntry, *const MaskedUsizeOption, *const OramBlock) {
        (
            self.entries.as_ptr(),
            self.position_map.as_ptr(),
            self.stash.as_ptr(),
        )
    }

    #[cfg(test)]
    pub(crate) fn install_slot_for_test(
        &mut self,
        slot_index: usize,
        entry: MapEntry,
        leaf: Option<usize>,
    ) {
        self.entries[slot_index] = entry;
        self.position_map[slot_index] = MaskedUsizeOption::from_option(leaf);
    }

    pub(crate) fn clone_for_tx(
        &self,
        spec: &StateObject,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let mut cloned = cold_clone_oram_state(spec, self)?;
        cloned.refresh_from_storage(spec, trace, allocator)?;
        Ok(cloned)
    }

    /// The map's slots as the call sees them. On a Path ORAM map they are its
    /// directory, each slot's occupancy and key with no value: the values
    /// live only in the blocks.
    pub(crate) fn clone_logical_entries(&self) -> Result<Box<[MapEntry]>> {
        clone_boxed_map_entries(&self.entries)
    }

    pub(crate) fn cold_commit(&mut self) {
        self.cold_plaintext();
        // The store keeps the map's records: a committed map holds none.
        self.storage = OramStorage::empty(self.parameters.bucket_count);
    }

    /// Zero what the map holds in the clear, and keep its records.
    fn cold_plaintext(&mut self) {
        cold_commit_oram_state(
            &mut self.position_map,
            &mut self.entries,
            &self.empty_entry,
            &mut self.stash,
        );
        if let Some(tree) = self.tree.as_mut() {
            tree.wipe_secrets();
        }
    }

    /// The map's cipher, sharing its key's count of seals.
    pub(crate) fn seal_cipher(&self) -> StoreCipher {
        self.cipher.clone_for_runtime_state()
    }

    /// A fresh map. With `seal`, it holds the first records a deployment
    /// hands its store; without, it is the map a restart finds, which holds
    /// no record and seals nothing, as the store keeps its records.
    pub(crate) fn instantiate(
        spec: &StateObject,
        rng: &mut ChaCha20Rng,
        seal: bool,
    ) -> Result<Self> {
        let parameters = OramParameters::for_spec(spec)?;
        let cipher = StoreCipher::from_rng(rng);
        let empty_entry = empty_map_entry(spec)?;
        if !seal {
            return Self::unsealed(spec, parameters, cipher, empty_entry);
        }
        if parameters.scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME {
            // The private scheme's map is an AVL tree in the ORAM: no flat
            // slots or position map in the enclave.
            let (directory_pages, buckets, tree) =
                bootstrap_tree_storage(spec, &parameters, &cipher, rng)?;
            let mut state = Self {
                parameters,
                entries: repeat_boxed_map_entries(0, &empty_entry)?,
                empty_entry,
                position_map: repeat_boxed_masked_usize_options(0, &MaskedUsizeOption::none())?,
                stash: FixedStash::placeholder(),
                tree: Some(tree),
                storage: OramStorage {
                    directory_pages: SealedPage::from_records(directory_pages)?,
                    buckets: BucketTable::from_records(buckets),
                    access_counter_slot: bootstrap_oram_counter_slot(spec, &cipher)?,
                },
                access_counter: 0,
                cipher,
            };
            state.cold_plaintext();
            return Ok(state);
        }
        let entries = repeat_boxed_map_entries(parameters.capacity, &empty_entry)?;
        let position_map_capacity = parameters.capacity;
        if parameters.is_surrogate() {
            let directory_pages = bootstrap_surrogate_directory_pages(
                spec,
                &parameters,
                &cipher,
                entries.as_ref(),
                &empty_entry,
            )?;
            let buckets = bootstrap_filler_buckets(spec, &parameters, &cipher)?;
            let mut state = Self {
                parameters,
                empty_entry,
                entries,
                position_map: repeat_boxed_masked_usize_options(
                    position_map_capacity,
                    &MaskedUsizeOption::none(),
                )?,
                stash: FixedStash::placeholder(),
                tree: None,
                storage: OramStorage {
                    directory_pages: SealedPage::from_records(directory_pages)?,
                    buckets: BucketTable::from_records(buckets),
                    access_counter_slot: bootstrap_oram_counter_slot(spec, &cipher)?,
                },
                access_counter: 0,
                cipher,
            };
            state.cold_plaintext();
            Ok(state)
        } else {
            let position_map =
                repeat_boxed_masked_usize_options(parameters.capacity, &MaskedUsizeOption::none())?;
            let stash = FixedStash::with_capacity(spec, working_stash_capacity(&parameters)?)?;
            let bootstrap_scratch = parameters
                .directory_page_bytes
                .max(parameters.bucket_size)
                .max(8);
            // One payload sealed per metadata page.
            let mut bootstrap_allocator = AllocatorSession::new(AllocatorPlan {
                arena_bytes: bootstrap_scratch.saturating_mul(4),
                max_stack_words: 0,
                scratch_bytes: bootstrap_scratch,
                max_kernel_ops: parameters.metadata_pages,
                max_commit_ops: 0,
                max_load_ops: 0,
            })?;
            let directory_pages = encode_path_metadata_pages(
                spec,
                &parameters,
                &cipher,
                position_map.as_ref(),
                entries.as_ref(),
                stash.as_slice(),
                &mut bootstrap_allocator,
            )?;
            bootstrap_allocator.finish()?;
            let buckets = bootstrap_empty_path_buckets(spec, &parameters, &cipher)?;
            let mut state = Self {
                parameters,
                empty_entry,
                entries,
                position_map,
                stash,
                tree: None,
                storage: OramStorage {
                    directory_pages: SealedPage::from_records(directory_pages)?,
                    buckets: BucketTable::from_records(buckets),
                    access_counter_slot: bootstrap_oram_counter_slot(spec, &cipher)?,
                },
                access_counter: 0,
                cipher,
            };
            state.cold_plaintext();
            Ok(state)
        }
    }

    /// The cold map a restart finds: its key, its public shape and its cold
    /// plaintext, and no record.
    fn unsealed(
        spec: &StateObject,
        parameters: OramParameters,
        cipher: StoreCipher,
        empty_entry: MapEntry,
    ) -> Result<Self> {
        let tree = if parameters.scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME {
            Some(TreeState::cold(
                &tree_shape_for_spec(spec, &parameters)?,
                parameters.buckets_per_access,
            )?)
        } else {
            None
        };
        let flat = tree.is_none();
        let slots = if flat { parameters.capacity } else { 0 };
        let stash = if flat && !parameters.is_surrogate() {
            FixedStash::with_capacity(spec, working_stash_capacity(&parameters)?)?
        } else {
            FixedStash::placeholder()
        };
        let mut state = Self {
            entries: repeat_boxed_map_entries(slots, &empty_entry)?,
            position_map: repeat_boxed_masked_usize_options(slots, &MaskedUsizeOption::none())?,
            empty_entry,
            stash,
            tree,
            storage: OramStorage::empty(parameters.bucket_count),
            parameters,
            access_counter: 0,
            cipher,
        };
        state.cold_commit();
        Ok(state)
    }

    /// Load the map for a call: read its counter and its metadata pages
    /// from the store, which the call holds until it commits, and open
    /// them. `trace` names those reads, the call's only reads of them.
    pub(crate) fn refresh_from_storage(
        &mut self,
        spec: &StateObject,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        self.storage
            .read_counter_and_pages(spec, &self.parameters, &self.cipher, trace)?;
        self.access_counter = read_oram_counter_from_storage(
            spec,
            &self.cipher,
            allocator,
            &self.storage.access_counter_slot,
        )?;
        if let Some(tree) = self.tree.as_mut() {
            refresh_tree_state_from_storage(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
                allocator,
                tree,
            )?;
        } else if self.parameters.is_surrogate() {
            decode_surrogate_entries_from_storage_into(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
                allocator,
                &self.empty_entry,
                &mut self.entries,
            )?;
        } else {
            refresh_path_state_from_storage(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
                allocator,
                &self.empty_entry,
                &mut self.position_map,
                &mut self.stash,
                &mut self.entries,
            )?;
        }
        Ok(())
    }

    pub(crate) fn get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
    ) -> Result<(Value, OramTranscript, bool)> {
        if self.parameters.is_surrogate() {
            run_surrogate_get(self, spec, key)
        } else {
            self.path_get(spec, key, allocator, leaf_coins)
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
    ) -> Result<(OramTranscript, bool)> {
        if self.parameters.is_surrogate() {
            run_surrogate_put(self, spec, key, value, apply)
        } else {
            self.path_put(spec, key, value, apply, allocator, leaf_coins)
        }
    }

    pub(crate) fn commit(
        self,
        spec: &StateObject,
        old: &Self,
        aborted: bool,
        allocator: &mut AllocatorSession,
    ) -> Result<OramCommit> {
        if self.parameters.is_surrogate() {
            let mut next = self;
            if aborted {
                // The pages the call read at its load: the committed ones,
                // which a surrogate map's call writes only below.
                decode_surrogate_entries_from_storage_into(
                    spec,
                    &old.parameters,
                    &old.cipher,
                    &next.storage.directory_pages,
                    allocator,
                    &old.empty_entry,
                    &mut next.entries,
                )?;
            }
            let empty_entry = empty_map_entry(spec)?;
            if next.storage.directory_pages.len() != next.parameters.metadata_pages {
                bail!(
                    "surrogate ORAM directory page count did not match public metadata count for {}",
                    spec.name
                );
            }
            let mut writes =
                OramWriteLog::with_capacity(oram_write_log_capacity(&next.parameters)?)?;
            rewrite_surrogate_directory_pages_in_place(
                spec,
                &next.parameters,
                &next.cipher,
                next.entries.as_ref(),
                &empty_entry,
                allocator,
                &mut next.storage.directory_pages,
                &mut writes,
            )?;
            let next_counter = old.access_counter + 1;
            rewrite_oram_counter_in_place(
                spec,
                next_counter,
                &next.cipher,
                allocator,
                &mut next.storage.access_counter_slot,
                &mut writes,
            )?;
            rewrite_surrogate_bucket_window_in_place(
                spec,
                &next.parameters,
                &next.cipher,
                next.entries.as_ref(),
                old.access_counter,
                allocator,
                &mut next.storage.buckets,
                &mut writes,
            )?;
            next.access_counter = next_counter;
            Ok(OramCommit {
                next,
                writes: writes.into_exact_batch()?,
            })
        } else {
            // A Path ORAM map's writes reach the ORAM through `commit_put`,
            // one access each, and an aborted call masks them off rather than
            // rolling back, so nothing is left to do here.
            let _ = (spec, old, aborted, allocator);
            Ok(OramCommit {
                next: self,
                writes: OramWriteBatch::empty(),
            })
        }
    }

    /// A get on the private scheme's tree: the value, whether the key is
    /// present, one transcript per node access, and whether one failed.
    pub(crate) fn tree_get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
    ) -> Result<(Value, bool, Box<[OramTranscript]>, bool)> {
        run_tree_get(self, spec, key, allocator, leaf_coins)
    }

    /// The presence a lookup takes from a fact an earlier lookup of the
    /// call found under `fact_key`, and whether the reuse failed.
    pub(crate) fn reuse_fact_presence(
        &self,
        fact_key: &Value,
        found: bool,
        key: &Value,
    ) -> (bool, bool) {
        reused_fact_presence(fact_key, found, key)
    }

    /// Decide a pending write to the private scheme's tree: whether it
    /// overflows the map, given whether the presence get found the key.
    pub(crate) fn decide_pending_tree_put(
        &mut self,
        spec: &StateObject,
        pending_puts: &[PendingOramPut],
        found: bool,
        key: &Value,
        value: &Value,
        apply: bool,
    ) -> Result<bool> {
        let tree = self
            .tree
            .as_mut()
            .ok_or_else(|| anyhow!("{} has no tree state", spec.name))?;
        Ok(decide_pending_tree_put(
            tree,
            pending_puts,
            found,
            key,
            value,
            apply,
        ))
    }

    /// A pending write to the private scheme's tree, made at commit and
    /// masked off if the call aborted: one transcript per node access.
    pub(crate) fn commit_tree_put(
        &mut self,
        spec: &StateObject,
        put: &PendingOramPut,
        aborted: bool,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
    ) -> Result<Box<[OramTranscript]>> {
        let (transcripts, overflowed, failed) = run_tree_put(
            self,
            spec,
            &put.key,
            &put.value,
            put.apply & !aborted,
            allocator,
            leaf_coins,
        )?;
        // The call decided every write's overflow with the map's pending
        // size, so a write that overflows or fails here means the decision
        // and the tree disagree; stop rather than commit.
        if overflowed | failed {
            bail!(
                "write to {} failed at commit; the pending size and the tree disagree",
                spec.name
            );
        }
        Ok(transcripts)
    }

    pub(crate) fn commit_put(
        &mut self,
        spec: &StateObject,
        put: &PendingOramPut,
        aborted: bool,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
    ) -> Result<OramTranscript> {
        run_path_commit_put(self, spec, put, aborted, allocator, leaf_coins)
    }

    fn path_get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
    ) -> Result<(Value, OramTranscript, bool)> {
        run_path_get(self, spec, key, allocator, leaf_coins)
    }

    fn path_put(
        &mut self,
        spec: &StateObject,
        key: Value,
        value: Value,
        apply: bool,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
    ) -> Result<(OramTranscript, bool)> {
        run_path_put(self, spec, key, value, apply, allocator, leaf_coins)
    }
}

#[cfg(test)]
mod tests {
    use super::generated_oram_codecs::{
        bucket_on_leaf_path, decode_bucket_payload, decode_path_metadata_pages,
        deserialize_oram_bucket, oram_bucket_aad, oram_bucket_bytes, oram_bucket_from_entries,
        oram_bucket_with_live_blocks,
    };
    use super::{
        empty_map_entry, encode_path_metadata_pages, repeat_boxed_map_entries,
        repeat_boxed_masked_usize_options, MapEntry, MaskedUsizeOption, OramBlock, OramBucket,
        OramParameters, OramState, PathOramLeafCoinSource, SealedPage, SURROGATE_ORAM_SCHEME,
    };
    use rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;
    use uo_allocator::{AllocatorPlan, AllocatorSession};
    use uo_core::ir::{BackendKind, ContainerKind, StateObject};
    use uo_core::manifest::PATH_ORAM_SCHEME;
    use uo_core::trace::WriteClass;
    use uo_core::{ScalarType, Type, Value};
    use uo_store::{SharedStorage, StoreCipher};

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
            max_commit_ops: 0,
            max_load_ops: 0,
        })
        .unwrap()
    }

    fn masked_position_map_from_options(position_map: &[Option<usize>]) -> Vec<MaskedUsizeOption> {
        position_map
            .iter()
            .copied()
            .map(MaskedUsizeOption::from_option)
            .collect()
    }

    fn options_from_masked_position_map(position_map: &[MaskedUsizeOption]) -> Vec<Option<usize>> {
        position_map.iter().map(|leaf| leaf.to_option()).collect()
    }

    fn map_entries_snapshot(entries: &[MapEntry]) -> Vec<MapEntry> {
        entries
            .iter()
            .map(|entry| {
                MapEntry::new(
                    entry.is_occupied(),
                    entry.key().clone(),
                    entry.value().clone(),
                )
            })
            .collect()
    }

    fn rebuild_path_oram_logical_state(
        spec: &StateObject,
        state: &OramState,
    ) -> (Vec<MapEntry>, Vec<Option<usize>>) {
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let rebuilt = state
            .clone_for_tx(spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        (
            map_entries_snapshot(&rebuilt.entries),
            options_from_masked_position_map(&rebuilt.position_map),
        )
    }

    fn oram_write_shapes(writes: &super::OramWriteBatch) -> Vec<(String, usize, WriteClass)> {
        let mut shapes = Vec::new();
        writes
            .for_each_write(|write| {
                shapes.push((write.location.clone(), write.len, write.class));
                Ok(())
            })
            .unwrap();
        shapes
    }

    /// A recorder for a load outside a call: nothing reads its trace.
    fn load_recorder() -> crate::controller::CallRecorder {
        crate::controller::CallRecorder::begin("load_test", &[])
    }

    /// A fresh map deployed into a store of its own, which keeps its
    /// records: a committed map, which holds none of them.
    fn deployed(spec: &StateObject, seed: u64) -> OramState {
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut state = OramState::instantiate(spec, &mut rng, true).unwrap();
        state
            .deploy_into_storage(spec, SharedStorage::memory().handle(&spec.name))
            .unwrap();
        state
    }

    /// A fresh map as a call loads it, its counter and metadata pages read
    /// from its store.
    fn loaded(spec: &StateObject, seed: u64) -> OramState {
        let mut state = deployed(spec, seed);
        let mut allocator = allocator_for_path_oram(&state.parameters);
        state
            .refresh_from_storage(spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        allocator.finish().unwrap();
        state
    }

    /// Hold the counter and the metadata pages of a deployed map, as a call
    /// that loads it does, and keep its plaintext as it is.
    fn hold_counter_and_pages(state: &mut OramState, spec: &StateObject) {
        let parameters = state.parameters.clone();
        let cipher = state.cipher.clone_for_runtime_state();
        state
            .storage
            .read_counter_and_pages(spec, &parameters, &cipher, &mut load_recorder())
            .unwrap();
    }

    /// Put `record` at `location` in the store of `state`, in place of the
    /// record it keeps there.
    fn put_stored_record(state: &OramState, location: &str, record: &[u8]) {
        let storage = state.cipher.storage().unwrap();
        storage.reserve_seals(state.cipher.seal_count()).unwrap();
        storage.write(location, record).unwrap();
    }

    fn path_oram_state_with_stash(
        spec: &StateObject,
        stash: Vec<OramBlock>,
        seed: u64,
    ) -> OramState {
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut state = OramState::instantiate(spec, &mut rng, true).unwrap();
        let mut entries =
            repeat_boxed_map_entries(state.parameters.capacity, &empty_map_entry(spec).unwrap())
                .unwrap()
                .into_vec();
        let mut position_map = vec![None; state.parameters.capacity];
        // The directory holds each slot's key; the value lives in the block.
        for block in &stash {
            entries[block.slot_index] = MapEntry {
                occupied: block.occupied,
                key: block.key.clone(),
                value: Value::uint(0),
            };
            position_map[block.slot_index] = Some(block.leaf);
        }
        let masked_position_map = masked_position_map_from_options(&position_map);
        state.entries = entries.into_boxed_slice();
        state.position_map = test_clone_masked_position_map(&masked_position_map);
        let mut working_stash = super::FixedStash::with_capacity(
            spec,
            super::working_stash_capacity(&state.parameters).unwrap(),
        )
        .unwrap();
        for block in &stash {
            working_stash.push(test_clone_oram_block(block)).unwrap();
        }
        state.stash = working_stash;
        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.storage.directory_pages = SealedPage::from_records(
            encode_path_metadata_pages(
                spec,
                &state.parameters,
                &state.cipher,
                &masked_position_map,
                &state.entries,
                &stash,
                &mut allocator,
            )
            .unwrap(),
        )
        .unwrap();
        // The store takes the pages, and the map holds them as a call does.
        state
            .deploy_into_storage(spec, SharedStorage::memory().handle(&spec.name))
            .unwrap();
        hold_counter_and_pages(&mut state, spec);
        state
    }

    fn test_clone_oram_block(block: &OramBlock) -> OramBlock {
        OramBlock {
            occupied: block.occupied,
            slot_index: block.slot_index,
            leaf: block.leaf,
            key: block.key.clone(),
            value: block.value.clone(),
        }
    }

    fn test_clone_oram_blocks(blocks: &[OramBlock]) -> Vec<OramBlock> {
        blocks.iter().map(test_clone_oram_block).collect()
    }

    fn test_clone_masked_position_map(
        position_map: &[MaskedUsizeOption],
    ) -> Box<[MaskedUsizeOption]> {
        position_map
            .iter()
            .map(|leaf| MaskedUsizeOption::from_option(leaf.to_option()))
            .collect::<Vec<_>>()
            .into_boxed_slice()
    }

    /// Reseal the metadata pages with this position map, these directory keys
    /// (slot, key), and this stash.
    fn reseal_path_oram_metadata(
        state: &mut OramState,
        spec: &StateObject,
        position_map: &[Option<usize>],
        directory: &[(usize, Value)],
        stash: &[OramBlock],
    ) {
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let masked_position_map = masked_position_map_from_options(position_map);
        let mut entries =
            repeat_boxed_map_entries(state.parameters.capacity, &empty_map_entry(spec).unwrap())
                .unwrap();
        for (slot, key) in directory {
            entries[*slot] = MapEntry::new(true, key.clone(), Value::uint(0));
        }
        let pages = encode_path_metadata_pages(
            spec,
            &state.parameters,
            &state.cipher,
            &masked_position_map,
            &entries,
            stash,
            &mut allocator,
        )
        .unwrap();
        for (page, record) in pages.iter().enumerate() {
            put_stored_record(state, &format!("{}@meta{page}", spec.name), record);
        }
    }

    /// Seal `bucket` as bucket `index` of `state`'s map and put it in the
    /// store.
    fn put_stored_bucket(state: &OramState, spec: &StateObject, index: usize, bucket: &OramBucket) {
        let aad = oram_bucket_aad(spec, index);
        let mut payload = oram_bucket_bytes(bucket, spec).unwrap();
        let record = state
            .cipher
            .seal_and_wipe_boxed(aad.as_bytes(), &mut payload)
            .unwrap();
        put_stored_record(state, &format!("{}@bucket{index}", spec.name), &record);
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
                value: Value::uint(5),
            },
            OramBlock {
                occupied: true,
                slot_index: 4,
                leaf: 6,
                key: Value::Address([0x22; 20]),
                value: Value::uint(9),
            },
        ];
        let mut state =
            path_oram_state_with_stash(&spec, test_clone_oram_blocks(&original_stash), 0xC10E);
        let expected_entries = map_entries_snapshot(&state.entries);
        let expected_position_map = test_clone_masked_position_map(&state.position_map);
        state.entries =
            repeat_boxed_map_entries(state.parameters.capacity, &empty_map_entry(&spec).unwrap())
                .unwrap();
        state.position_map = repeat_boxed_masked_usize_options(
            state.parameters.capacity,
            &MaskedUsizeOption::none(),
        )
        .unwrap();
        state.stash.clear();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let cloned = state
            .clone_for_tx(&spec, &mut load_recorder(), &mut allocator)
            .unwrap();

        assert_eq!(map_entries_snapshot(&cloned.entries), expected_entries);
        assert_eq!(cloned.position_map, expected_position_map);
        assert_eq!(cloned.stash.to_vec(), original_stash);
    }

    #[test]
    fn path_position_map_witness_reconstructs_cold_committed_state_from_storage() {
        let spec = path_oram_spec();
        let original_stash = vec![
            OramBlock {
                occupied: true,
                slot_index: 1,
                leaf: 3,
                key: Value::Address([0x11; 20]),
                value: Value::uint(5),
            },
            OramBlock {
                occupied: true,
                slot_index: 4,
                leaf: 6,
                key: Value::Address([0x22; 20]),
                value: Value::uint(9),
            },
        ];
        let mut state = path_oram_state_with_stash(&spec, original_stash, 0xC10F);
        let expected_position_map = state
            .position_map
            .iter()
            .map(|leaf| leaf.to_witness())
            .collect::<Vec<_>>();

        state.cold_commit();

        let witness = state.path_position_map_witness(&spec).unwrap();
        assert_eq!(witness.leaves, expected_position_map.into_boxed_slice());
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
                value: Value::uint(5),
            },
            OramBlock {
                occupied: true,
                slot_index: 4,
                leaf: 6,
                key: Value::Address([0x22; 20]),
                value: Value::uint(9),
            },
        ];
        let mut state = path_oram_state_with_stash(&spec, original_stash, 0xC1A0);
        let directory_page_ptrs = state
            .storage
            .directory_pages
            .iter()
            .map(|page| page.as_ptr())
            .collect::<Vec<_>>();
        assert_eq!(directory_page_ptrs.len(), state.parameters.metadata_pages);
        assert!(state.storage.buckets.holds_none());
        let counter_ptr = state.storage.access_counter_slot.as_ptr();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let mut leaf_coins = PathOramLeafCoinSource::random();
        state
            .put(
                &spec,
                Value::Address([0x11; 20]),
                Value::uint(17),
                true,
                &mut allocator,
                &mut leaf_coins,
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
        assert_eq!(state.storage.access_counter_slot.as_ptr(), counter_ptr);
        // The map holds the buckets of the path it read and resealed, which
        // are the records the store now keeps.
        let held: Vec<usize> = state.storage.buckets.held.keys().copied().collect();
        assert_eq!(held.len(), state.parameters.buckets_per_access);
        for index in held {
            let location = format!("{}@bucket{index}", spec.name);
            let stored = state.cipher.storage().unwrap().record(&location).unwrap();
            assert_eq!(&**state.storage.buckets.get(index).unwrap(), &*stored);
        }
    }

    /// A stash that holds more blocks than its bound is an overflow. The
    /// access stops with an error and commits nothing, so the caller drops
    /// the call and the committed map keeps every block: an overflow is not
    /// reported in band, where the call would abort and keep the access.
    #[test]
    fn path_oram_get_fails_on_a_stash_overflow() {
        let spec = path_oram_spec();
        let mut state = loaded(&spec, 0x5010);
        let stash_capacity = state.stash.capacity();
        let leaf_count = state.parameters.leaf_count();

        for index in 0..=stash_capacity {
            state
                .stash
                .push(OramBlock {
                    occupied: true,
                    slot_index: index % state.parameters.capacity,
                    leaf: index % leaf_count,
                    key: Value::Address([index as u8; 20]),
                    value: Value::uint(index as u128),
                })
                .unwrap();
        }
        assert!(state.stash.overflowed());

        let mut allocator = allocator_for_path_oram(&state.parameters);
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let error = state
            .get(
                &spec,
                &Value::Address([0xEE; 20]),
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap_err()
            .to_string();
        assert!(
            error.contains("a Path ORAM stash overflowed its bound"),
            "{error}"
        );
    }

    /// A committed map holds no sealed record: its store keeps them. A call
    /// reads from the store the counter and the metadata pages when it
    /// loads the map, and the buckets of a path when it accesses it, and
    /// holds those until it seals their next versions over them and hands
    /// them to the store. Making the map cold drops every record it holds.
    #[test]
    fn a_committed_map_holds_no_record_and_a_call_reads_the_ones_it_opens() {
        let spec = path_oram_spec();
        let committed = deployed(&spec, 0x5EA1);
        assert!(committed.holds_no_sealed_record());
        let storage = committed.cipher.storage().unwrap().clone();
        let stored = |location: &str| storage.record(location).unwrap();

        let mut allocator = allocator_for_path_oram(&committed.parameters);
        let mut recorder = load_recorder();
        let mut state = committed
            .clone_for_tx(&spec, &mut recorder, &mut allocator)
            .unwrap();
        assert!(committed.holds_no_sealed_record());
        // The load reads the counter and every metadata page, and the trace
        // names each of those reads there, once.
        let mut loaded = vec![format!("{}@counter", spec.name)];
        loaded.extend(
            (0..state.parameters.metadata_pages).map(|page| format!("{}@meta{page}", spec.name)),
        );
        assert_eq!(recorder.physical_read_locations(), loaded);
        // The load holds the counter and the metadata pages, as the store
        // keeps them, and no bucket.
        assert_eq!(
            &*state.storage.access_counter_slot,
            &*stored(&format!("{}@counter", spec.name))
        );
        assert_eq!(
            state.storage.directory_pages.len(),
            state.parameters.metadata_pages
        );
        for (page, record) in state.storage.directory_pages.iter().enumerate() {
            assert_eq!(&**record, &*stored(&format!("{}@meta{page}", spec.name)));
        }
        assert!(state.storage.buckets.holds_none());

        let mut leaf_coins = PathOramLeafCoinSource::random();
        state
            .put(
                &spec,
                Value::Address([0x5E; 20]),
                Value::uint(3),
                true,
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap();
        // The access holds the buckets of its path, each the record it
        // sealed and handed to the store, and every bucket it holds is on
        // the path it read.
        let leaf = state.parameters.leaf_count();
        let held: Vec<usize> = state.storage.buckets.held.keys().copied().collect();
        assert!(!held.is_empty() && held.len() < state.parameters.bucket_count);
        assert!(held
            .iter()
            .all(|index| *index < state.parameters.bucket_count));
        let _ = leaf;
        for index in &held {
            assert_eq!(
                &**state.storage.buckets.get(*index).unwrap(),
                &*stored(&format!("{}@bucket{index}", spec.name))
            );
        }
        state.cold_commit();
        assert!(state.holds_no_sealed_record());
    }

    #[test]
    fn surrogate_commit_reads_old_entries_from_storage_on_abort() {
        let spec = oram_spec();
        let mut old = deployed(&spec, 0x5153);
        let storage = old.cipher.storage().unwrap().clone();
        let records = |prefix: &str, count: usize| -> Vec<Box<[u8]>> {
            (0..count)
                .map(|index| {
                    storage
                        .record(&format!("{}@{prefix}{index}", spec.name))
                        .unwrap()
                })
                .collect()
        };
        let mut old_allocator = allocator_for_path_oram(&old.parameters);
        old.refresh_from_storage(&spec, &mut load_recorder(), &mut old_allocator)
            .unwrap();
        old_allocator.finish().unwrap();
        old.cold_commit();
        let expected_entries = {
            let mut allocator = allocator_for_path_oram(&old.parameters);
            map_entries_snapshot(
                &old.clone_for_tx(&spec, &mut load_recorder(), &mut allocator)
                    .unwrap()
                    .entries,
            )
        };
        // What the committed map holds of its contents in the clear is not
        // what a call reads: a call reads the store.
        old.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x11; 20]),
            value: Value::uint(7),
        };
        let (pages, buckets) = (old.parameters.metadata_pages, old.parameters.bucket_count);
        let old_pages = records("meta", pages);
        let old_buckets = records("bucket", buckets);
        let old_counter = storage.record(&format!("{}@counter", spec.name)).unwrap();

        let mut shadow_allocator = allocator_for_path_oram(&old.parameters);
        let mut new = old
            .clone_for_tx(&spec, &mut load_recorder(), &mut shadow_allocator)
            .unwrap();
        shadow_allocator.finish().unwrap();
        assert!(old.holds_no_sealed_record());
        let entries_ptr = new.entries.as_ptr();
        new.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x22; 20]),
            value: Value::uint(9),
        };

        let mut commit_allocator = allocator_for_path_oram(&new.parameters);
        let commit = new
            .commit(&spec, &old, true, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        assert_eq!(map_entries_snapshot(&commit.next.entries), expected_entries);
        assert_eq!(commit.next.entries.as_ptr(), entries_ptr);
        // The commit wrote every metadata page, a window of buckets and the
        // counter in the store, and no other bucket.
        assert!(records("meta", pages)
            .iter()
            .zip(&old_pages)
            .all(|(next, before)| next != before));
        let written_buckets = records("bucket", buckets)
            .iter()
            .zip(&old_buckets)
            .filter(|(next, before)| next != before)
            .count();
        assert_eq!(
            written_buckets,
            commit.next.parameters.buckets_per_access.min(buckets)
        );
        assert_ne!(
            storage.record(&format!("{}@counter", spec.name)).unwrap(),
            old_counter
        );
        assert_eq!(commit.next.access_counter, 1);
        assert!(old.holds_no_sealed_record());

        let mut next = commit.next;
        next.cold_commit();
        assert!(next.holds_no_sealed_record());
        let mut refresh_allocator = allocator_for_path_oram(&next.parameters);
        let rebuilt = next
            .clone_for_tx(&spec, &mut load_recorder(), &mut refresh_allocator)
            .unwrap();
        refresh_allocator.finish().unwrap();
        assert_eq!(map_entries_snapshot(&rebuilt.entries), expected_entries);
    }

    #[test]
    fn surrogate_get_returns_zero_for_missing_key_after_full_scan_lookup() {
        let spec = oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5154);
        let mut state = OramState::instantiate(&spec, &mut rng, true).unwrap();
        state.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x11; 20]),
            value: Value::uint(7),
        };
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let value = state
            .get(
                &spec,
                &Value::Address([0x22; 20]),
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap()
            .0;
        allocator.finish().unwrap();
        assert_eq!(value, Value::uint(0));
    }

    #[test]
    fn surrogate_put_with_false_apply_preserves_existing_entries() {
        let spec = oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5155);
        let mut state = OramState::instantiate(&spec, &mut rng, true).unwrap();
        state.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x11; 20]),
            value: Value::uint(7),
        };
        let snapshot = map_entries_snapshot(&state.entries);
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let mut leaf_coins = PathOramLeafCoinSource::random();
        state
            .put(
                &spec,
                Value::Address([0x11; 20]),
                Value::uint(99),
                false,
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap();
        allocator.finish().unwrap();
        assert_eq!(map_entries_snapshot(&state.entries), snapshot);
    }

    #[test]
    fn typed_bucket_roundtrips_fixed_shape() {
        let spec = oram_spec();
        let bucket = oram_bucket_with_live_blocks(
            &spec,
            9,
            3,
            2,
            &[
                super::OramBlock {
                    occupied: true,
                    slot_index: 0,
                    leaf: 0,
                    key: Value::Address([0x11; 20]),
                    value: Value::uint(5),
                },
                super::OramBlock {
                    occupied: true,
                    slot_index: 0,
                    leaf: 0,
                    key: Value::Address([0x22; 20]),
                    value: Value::uint(7),
                },
            ],
        )
        .unwrap();
        let bytes = oram_bucket_bytes(&bucket, &spec).unwrap();
        assert_eq!(
            bytes.len(),
            OramParameters::for_spec(&spec).unwrap().bucket_size
        );
        assert_eq!(deserialize_oram_bucket(&spec, &bytes).unwrap(), bucket);
    }

    #[test]
    fn decode_bucket_payload_rejects_header_index_mismatch() {
        let spec = path_oram_spec();
        let bucket = oram_bucket_with_live_blocks(
            &spec,
            0,
            0,
            1,
            &[OramBlock {
                occupied: true,
                slot_index: 0,
                leaf: 0,
                key: Value::Address([0x11; 20]),
                value: Value::uint(5),
            }],
        )
        .unwrap();
        let bytes = oram_bucket_bytes(&bucket, &spec).unwrap();
        let err = decode_bucket_payload(&spec, 1, &bytes, |_block| Ok(())).unwrap_err();
        assert!(err
            .to_string()
            .contains("claims index 0 but storage location is 1"));
    }

    #[test]
    fn decode_bucket_payload_rejects_live_count_underreport() {
        let spec = path_oram_spec();
        let bucket = oram_bucket_with_live_blocks(
            &spec,
            0,
            0,
            0,
            &[OramBlock {
                occupied: true,
                slot_index: 0,
                leaf: 0,
                key: Value::Address([0x22; 20]),
                value: Value::uint(7),
            }],
        )
        .unwrap();
        let bytes = oram_bucket_bytes(&bucket, &spec).unwrap();
        let err = decode_bucket_payload(&spec, 0, &bytes, |_block| Ok(())).unwrap_err();
        assert!(err
            .to_string()
            .contains("contains 1 live blocks but header says 0"));
    }

    #[test]
    fn bucket_from_entries_caps_to_public_block_budget() {
        let spec = oram_spec();
        let bucket = oram_bucket_from_entries(
            &spec,
            &[
                MapEntry {
                    occupied: true,
                    key: Value::Address([0x11; 20]),
                    value: Value::uint(1),
                },
                MapEntry {
                    occupied: true,
                    key: Value::Address([0x22; 20]),
                    value: Value::uint(2),
                },
                MapEntry {
                    occupied: true,
                    key: Value::Address([0x33; 20]),
                    value: Value::uint(3),
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
            value: Value::uint(9),
        };
        entry.wipe_secrets();
        assert!(!entry.occupied);
        assert_eq!(entry.key, Value::Address([0u8; 20]));
        assert_eq!(entry.value, Value::uint(0));
    }

    #[test]
    fn oram_block_wipe_secrets_clears_hidden_state() {
        let mut block = super::OramBlock {
            occupied: true,
            slot_index: 5,
            leaf: 7,
            key: Value::Address([0x22; 20]),
            value: Value::uint(11),
        };
        block.wipe_secrets();
        assert!(!block.occupied);
        assert_eq!(block.slot_index, 0);
        assert_eq!(block.leaf, 0);
        assert_eq!(block.key, Value::Address([0u8; 20]));
        assert_eq!(block.value, Value::uint(0));
    }

    #[test]
    fn path_oram_metadata_decode_rejects_stash_overflow() {
        let spec = path_oram_spec();
        let parameters = OramParameters::for_spec(&spec).unwrap();
        let cipher = StoreCipher::random();
        let mut encode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
            max_load_ops: 0,
        })
        .unwrap();
        let position_map = masked_position_map_from_options(&vec![None; parameters.capacity]);
        let stash = (0..=parameters.stash_bound)
            .map(|index| OramBlock {
                occupied: true,
                slot_index: index % parameters.capacity.max(1),
                leaf: index % parameters.leaf_count().max(1),
                key: Value::Address([index as u8; 20]),
                value: Value::uint(index as u128),
            })
            .collect::<Vec<_>>();
        let directory =
            repeat_boxed_map_entries(parameters.capacity, &empty_map_entry(&spec).unwrap())
                .unwrap();
        let pages = encode_path_metadata_pages(
            &spec,
            &parameters,
            &cipher,
            &position_map,
            &directory,
            &stash,
            &mut encode_allocator,
        )
        .unwrap();
        let mut decode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
            max_load_ops: 0,
        })
        .unwrap();
        let err = decode_path_metadata_pages(
            &spec,
            &parameters,
            &cipher,
            &SealedPage::from_records(pages.clone()).unwrap(),
            &mut decode_allocator,
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("decoded ORAM stash for balances exceeds manifest bound"));
    }

    #[test]
    fn path_oram_metadata_encode_handles_empty_stash_tail_pages() {
        let spec = path_oram_spec();
        let parameters = OramParameters::for_spec(&spec).unwrap();
        assert!(parameters.stash_pages() > 1);
        let cipher = StoreCipher::random();
        let mut encode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
            max_load_ops: 0,
        })
        .unwrap();
        let position_map_options = vec![None; parameters.capacity];
        let position_map = masked_position_map_from_options(&position_map_options);
        let stash = Vec::<OramBlock>::new();
        let directory =
            repeat_boxed_map_entries(parameters.capacity, &empty_map_entry(&spec).unwrap())
                .unwrap();
        let pages = encode_path_metadata_pages(
            &spec,
            &parameters,
            &cipher,
            &position_map,
            &directory,
            &stash,
            &mut encode_allocator,
        )
        .unwrap();
        assert_eq!(pages.len(), parameters.metadata_pages);
        let mut decode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
            max_load_ops: 0,
        })
        .unwrap();
        let (decoded_position_map, decoded_stash) = decode_path_metadata_pages(
            &spec,
            &parameters,
            &cipher,
            &SealedPage::from_records(pages.clone()).unwrap(),
            &mut decode_allocator,
        )
        .unwrap();
        assert_eq!(
            options_from_masked_position_map(decoded_position_map.as_ref()),
            position_map_options
        );
        assert!(decoded_stash.is_empty());
    }

    #[test]
    fn bucket_on_leaf_path_matches_materialized_path() {
        let spec = path_oram_spec();
        let parameters = OramParameters::for_spec(&spec).unwrap();
        for leaf in 0..parameters.leaf_count() {
            let path =
                super::generated_oram_codecs::path_bucket_indices(parameters.leaf_count(), leaf);
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
                value: Value::uint(1),
            },
            OramBlock {
                occupied: true,
                slot_index: 1,
                leaf: 1,
                key: Value::Address([0x20; 20]),
                value: Value::uint(2),
            },
            OramBlock {
                occupied: true,
                slot_index: 2,
                leaf: 2,
                key: Value::Address([0x30; 20]),
                value: Value::uint(3),
            },
        ];
        let mut permuted_stash = test_clone_oram_blocks(&base_stash);
        permuted_stash.swap(0, 2);

        let mut first = path_oram_state_with_stash(&spec, base_stash, 0xA11CE);
        let mut second = path_oram_state_with_stash(&spec, permuted_stash, 0xA11CE);
        let delete_key = Value::Address([0x10; 20]);
        let delete_value = Value::uint(0);

        let mut first_allocator = allocator_for_path_oram(&first.parameters);
        let mut second_allocator = allocator_for_path_oram(&second.parameters);
        let mut first_leaf_coins = PathOramLeafCoinSource::random();
        let mut second_leaf_coins = PathOramLeafCoinSource::random();

        let (first_transcript, first_overflowed) = first
            .put(
                &spec,
                delete_key.clone(),
                delete_value.clone(),
                true,
                &mut first_allocator,
                &mut first_leaf_coins,
            )
            .unwrap();
        let (second_transcript, second_overflowed) = second
            .put(
                &spec,
                delete_key,
                delete_value,
                true,
                &mut second_allocator,
                &mut second_leaf_coins,
            )
            .unwrap();

        assert!(!first_overflowed);
        assert!(!second_overflowed);
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
    fn path_oram_refresh_reads_no_bucket() {
        // A call starts from the counter and the metadata pages alone: its
        // load reads them from the store, and no bucket.
        let spec = path_oram_spec();
        let original_stash = vec![OramBlock {
            occupied: true,
            slot_index: 2,
            leaf: 1,
            key: Value::Address([0x33; 20]),
            value: Value::uint(4),
        }];
        let mut state = path_oram_state_with_stash(&spec, original_stash, 0xB0C7);
        state.cold_commit();
        let storage = state.cipher.storage().unwrap().clone();
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let reads_before = storage.stats().reads;
        let cloned = state
            .clone_for_tx(&spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        let reads = storage.stats().reads - reads_before;
        assert_eq!(reads as usize, 1 + state.parameters.metadata_pages);
        assert!(cloned.storage.buckets.holds_none());
        assert_eq!(cloned.position_map[2].to_option(), Some(1));
        assert!(cloned.entries[2].matches_key(&Value::Address([0x33; 20])));
        assert_eq!(cloned.entries[2].value(), &Value::uint(0));
    }

    #[test]
    fn path_oram_get_reads_the_value_from_the_keys_block() {
        // The value comes from the key's block once its path is read; the
        // directory holds no value.
        let spec = path_oram_spec();
        let mut state = deployed(&spec, 0x7A1E);
        let leaf = 2usize;
        let block = OramBlock {
            occupied: true,
            slot_index: 3,
            leaf,
            key: Value::Address([0x77; 20]),
            value: Value::uint(41),
        };
        let mut position_map = vec![None; state.parameters.capacity];
        position_map[3] = Some(leaf);
        reseal_path_oram_metadata(
            &mut state,
            &spec,
            &position_map,
            &[(3, Value::Address([0x77; 20]))],
            &[],
        );
        let leaf_bucket = state.parameters.leaf_count() - 1 + leaf;
        let bucket = oram_bucket_with_live_blocks(&spec, 0, leaf_bucket, 1, &[block]).unwrap();
        put_stored_bucket(&state, &spec, leaf_bucket, &bucket);

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state
            .refresh_from_storage(&spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let (value, transcript, failed) = state
            .get(
                &spec,
                &Value::Address([0x77; 20]),
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap();
        allocator.finish().unwrap();
        assert!(!failed);
        assert_eq!(value, Value::uint(41));
        assert_eq!(transcript.path_leaf, Some(leaf));
    }

    #[test]
    fn path_oram_get_reports_duplicate_live_block_in_band() {
        let spec = path_oram_spec();
        let mut state = deployed(&spec, 0xBAD5EED);
        let duplicate = OramBlock {
            occupied: true,
            slot_index: 0,
            leaf: 0,
            key: Value::Address([0x44; 20]),
            value: Value::uint(9),
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
            &[(0, Value::Address([0x44; 20]))],
            std::slice::from_ref(&duplicate),
        );
        let bucket = oram_bucket_with_live_blocks(&spec, 0, 0, 1, &[duplicate]).unwrap();
        put_stored_bucket(&state, &spec, 0, &bucket);

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state
            .refresh_from_storage(&spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let (_value, _transcript, failed) = state
            .get(
                &spec,
                &Value::Address([0x44; 20]),
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap();
        assert!(failed);
    }

    #[test]
    fn path_oram_get_reports_position_map_leaf_mismatch_in_band() {
        let spec = path_oram_spec();
        let mut state = deployed(&spec, 0xBADC0DE);
        let block = OramBlock {
            occupied: true,
            slot_index: 0,
            leaf: 0,
            key: Value::Address([0x55; 20]),
            value: Value::uint(7),
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
            &[(0, Value::Address([0x55; 20]))],
            std::slice::from_ref(&block),
        );

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state
            .refresh_from_storage(&spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let (_value, _transcript, failed) = state
            .get(
                &spec,
                &Value::Address([0x55; 20]),
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap();
        assert!(failed);
    }

    #[test]
    fn path_oram_access_rejects_bucket_block_off_its_path() {
        let spec = path_oram_spec();
        let mut state = deployed(&spec, 0xFACE123);
        let leaf = state.parameters.leaf_count() - 1;
        let block = OramBlock {
            occupied: true,
            slot_index: 0,
            leaf,
            key: Value::Address([0x66; 20]),
            value: Value::uint(13),
        };
        let position_map = vec![Some(leaf)]
            .into_iter()
            .chain(std::iter::repeat(None))
            .take(state.parameters.capacity)
            .collect::<Vec<_>>();
        reseal_path_oram_metadata(
            &mut state,
            &spec,
            &position_map,
            &[(0, Value::Address([0x66; 20]))],
            &[],
        );
        let off_path_bucket = 1usize;
        assert!(!bucket_on_leaf_path(
            state.parameters.leaf_count(),
            off_path_bucket,
            leaf
        ));
        let bucket = oram_bucket_with_live_blocks(&spec, 0, off_path_bucket, 1, &[block]).unwrap();
        put_stored_bucket(&state, &spec, off_path_bucket, &bucket);

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state
            .refresh_from_storage(&spec, &mut load_recorder(), &mut allocator)
            .unwrap();
        // A read of an absent key whose path, to leaf 0, runs through the
        // tampered bucket.
        let mut leaf_coins = PathOramLeafCoinSource::require_injected();
        leaf_coins.install(vec![0].into_boxed_slice());
        let err = state
            .get(
                &spec,
                &Value::Address([0x99; 20]),
                &mut allocator,
                &mut leaf_coins,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains(&format!("carries leaf {leaf} off its path")));
    }

    mod tree {
        //! The oblivious AVL map against a reference map, on an in-memory
        //! bucket store: contents, tree shape, pointers, free list, stash
        //! bound, and the fixed number of path reads and writes.
        use super::super::generated_oram_codecs::{
            bucket_on_leaf_path, clone_tree_node, compaction_network, expansion_network,
            for_each_bucket_on_leaf_path_leaf_to_root, odd_even_merge_sort_network,
            reused_fact_presence, tree_avl_height, tree_bootstrap_nodes, tree_get,
            tree_get_accesses, tree_key_lt, tree_place_nodes, tree_put, tree_put_accesses,
            TreeAccessRecord, TreeHeader, TreeLink, TreeNode, TreePathStore, TreeShape, TreeStash,
        };
        use anyhow::Result;
        use rand::{Rng, SeedableRng};
        use rand_chacha::ChaCha20Rng;
        use std::collections::BTreeMap;
        use uo_core::{ScalarType, Type, Uint256, Value};

        /// A lookup that reuses a fact takes the fact's presence under the
        /// key the fact was found under; under another key the reuse fails
        /// and takes no presence.
        #[test]
        fn a_reused_fact_serves_only_its_own_key() {
            let key = Value::Bytes32([4u8; 32]);
            let other = Value::Bytes32([5u8; 32]);
            assert_eq!(reused_fact_presence(&key, true, &key), (true, false));
            assert_eq!(reused_fact_presence(&key, false, &key), (false, false));
            assert_eq!(reused_fact_presence(&key, true, &other), (false, true));
            assert_eq!(reused_fact_presence(&key, false, &other), (false, true));
        }

        struct MemoryTreeStore {
            buckets: Vec<Box<[TreeNode]>>,
            empty: TreeNode,
            leaf_count: usize,
            coins: ChaCha20Rng,
            operation_ended: bool,
            accesses: usize,
            first_accesses: usize,
            ended_accesses: usize,
            ended_operations: usize,
            last_access_ended_after_operation: bool,
            reads: usize,
            writes: usize,
        }

        impl TreePathStore for MemoryTreeStore {
            fn coin(&mut self) -> Result<usize> {
                Ok(self.coins.gen_range(0..self.leaf_count))
            }

            fn begin_access(&mut self, first: bool) -> Result<()> {
                assert!(!self.operation_ended, "an access after the operation ended");
                if first {
                    self.accesses = 0;
                    self.first_accesses = 0;
                    self.ended_accesses = 0;
                    self.ended_operations = 0;
                    self.last_access_ended_after_operation = false;
                    self.reads = 0;
                    self.writes = 0;
                }
                self.accesses += 1;
                self.first_accesses += usize::from(first);
                Ok(())
            }

            fn load_bucket(&mut self, index: usize, stash: &mut TreeStash) -> Result<()> {
                self.reads += 1;
                for slot in self.buckets[index].iter_mut() {
                    stash.append(slot)?;
                    *slot = clone_tree_node(&self.empty);
                }
                Ok(())
            }

            fn store_bucket(&mut self, index: usize, blocks: &[TreeNode]) -> Result<()> {
                self.writes += 1;
                self.buckets[index] = blocks.iter().map(clone_tree_node).collect();
                Ok(())
            }

            fn end_operation(&mut self, _header: &TreeHeader, _stash: &TreeStash) -> Result<()> {
                self.ended_operations += 1;
                self.operation_ended = true;
                Ok(())
            }

            fn end_access(&mut self, record: &TreeAccessRecord) -> Result<()> {
                assert!(record.read_leaf < self.leaf_count);
                assert!(record.coin < self.leaf_count);
                if record.real {
                    assert_eq!(record.read_leaf, record.prior_leaf);
                } else {
                    assert_eq!(record.read_leaf, record.coin);
                }
                self.ended_accesses += 1;
                // The last access ends after the operation does.
                if self.operation_ended {
                    self.operation_ended = false;
                    self.last_access_ended_after_operation = true;
                }
                Ok(())
            }
        }

        struct Fixture {
            shape: TreeShape,
            store: MemoryTreeStore,
            stash: TreeStash,
            header: TreeHeader,
            levels: usize,
            rng: ChaCha20Rng,
        }

        impl Fixture {
            /// An operation of `accesses` node accesses: each reads and
            /// writes one path; the first reads the header and the stash and
            /// the operation writes them once.
            fn assert_operation_shape(&self, accesses: usize) {
                let store = &self.store;
                assert_eq!(store.accesses, accesses);
                assert_eq!(store.first_accesses, 1);
                assert_eq!(store.ended_accesses, accesses);
                assert_eq!(store.ended_operations, 1);
                assert!(store.last_access_ended_after_operation);
                assert_eq!(store.reads, accesses * self.levels);
                assert_eq!(store.writes, accesses * self.levels);
            }
        }

        fn key_type() -> Type {
            Type::Scalar(ScalarType::Address)
        }

        fn value_type() -> Type {
            Type::Scalar(ScalarType::Uint(256))
        }

        /// The Path ORAM stash bound plus the nodes an operation returns.
        fn default_stash_bound(capacity: usize) -> usize {
            capacity.clamp(
                1,
                uo_core::manifest::PATH_ORAM_STASH_BOUND_LIMIT
                    + tree_put_accesses(tree_avl_height(capacity)),
            )
        }

        fn fixture(capacity: usize, seed: u64, stash_bound: usize) -> Fixture {
            let leaf_count = capacity.max(2).next_power_of_two();
            let levels = leaf_count.trailing_zeros() as usize + 1;
            let avl_height = tree_avl_height(capacity);
            let shape = TreeShape {
                capacity,
                leaf_count,
                blocks_per_bucket: 5,
                avl_height,
                stash_bound,
                key_type: key_type(),
                value_type: value_type(),
                key_width: 20,
                value_width: 32,
            };
            let empty = TreeNode::empty(&key_type(), &value_type());
            let working = shape.stash_bound + shape.blocks_per_bucket * levels;
            let mut stash = TreeStash::with_capacity(shape.stash_bound, working, &empty).unwrap();
            let mut rng = ChaCha20Rng::seed_from_u64(seed);
            let mut coins = || Ok(rng.gen_range(0..leaf_count));
            let (header, nodes) = tree_bootstrap_nodes(&shape, &mut coins).unwrap();
            let mut buckets: Vec<Box<[TreeNode]>> = (0..2 * leaf_count - 1)
                .map(|_| (0..5).map(|_| clone_tree_node(&empty)).collect())
                .collect();
            tree_place_nodes(&shape, &nodes, &mut buckets, &mut stash).unwrap();
            Fixture {
                shape,
                store: MemoryTreeStore {
                    buckets,
                    empty,
                    leaf_count,
                    coins: ChaCha20Rng::seed_from_u64(seed ^ 0x5eed),
                    operation_ended: false,
                    accesses: 0,
                    first_accesses: 0,
                    ended_accesses: 0,
                    ended_operations: 0,
                    last_access_ended_after_operation: false,
                    reads: 0,
                    writes: 0,
                },
                stash,
                header,
                levels,
                rng,
            }
        }

        fn address(byte: u8) -> Value {
            Value::Address([byte; 20])
        }

        fn key_bytes(key: &Value) -> Vec<u8> {
            match key {
                Value::Address(bytes) => bytes.to_vec(),
                _ => unreachable!(),
            }
        }

        /// Decode every block and check the whole structure.
        fn check(fixture: &Fixture, expected: &BTreeMap<Vec<u8>, Value>) {
            let shape = &fixture.shape;
            let mut nodes: BTreeMap<usize, &TreeNode> = BTreeMap::new();
            for (index, bucket) in fixture.store.buckets.iter().enumerate() {
                for block in bucket.iter().filter(|block| block.occupied) {
                    assert!(
                        bucket_on_leaf_path(shape.leaf_count, index, block.leaf),
                        "block {} off its path",
                        block.id
                    );
                    assert!(
                        nodes.insert(block.id, block).is_none(),
                        "duplicate block {}",
                        block.id
                    );
                }
            }
            for block in fixture
                .stash
                .blocks
                .iter()
                .take(fixture.stash.persistent)
                .filter(|block| block.occupied)
            {
                assert!(
                    nodes.insert(block.id, block).is_none(),
                    "duplicate block {}",
                    block.id
                );
            }
            assert_eq!(nodes.len(), shape.capacity, "a node block was lost");
            assert!(
                fixture.stash.len() <= shape.stash_bound,
                "stash over its bound"
            );

            let mut contents = BTreeMap::new();
            fn walk(
                nodes: &BTreeMap<usize, &TreeNode>,
                link: &TreeLink,
                low: Option<&Value>,
                high: Option<&Value>,
                width: usize,
                contents: &mut BTreeMap<Vec<u8>, Value>,
            ) -> usize {
                if !link.present {
                    return 0;
                }
                let node = nodes[&link.id];
                assert_eq!(
                    node.leaf, link.leaf,
                    "pointer to node {} has a stale leaf",
                    node.id
                );
                assert!(node.in_tree, "tree pointer to free node {}", node.id);
                if let Some(low) = low {
                    assert!(tree_key_lt(low, &node.key, width).unwrap());
                }
                if let Some(high) = high {
                    assert!(tree_key_lt(&node.key, high, width).unwrap());
                }
                let left = walk(nodes, &node.left, low, Some(&node.key), width, contents);
                let right = walk(nodes, &node.right, Some(&node.key), high, width, contents);
                assert_eq!(left, node.left.height, "stale left height at {}", node.id);
                assert_eq!(
                    right, node.right.height,
                    "stale right height at {}",
                    node.id
                );
                assert!(left.abs_diff(right) <= 1, "node {} unbalanced", node.id);
                contents.insert(key_bytes(&node.key), node.value.clone());
                let height = 1 + left.max(right);
                assert_eq!(
                    height, link.height,
                    "stale height in pointer to {}",
                    node.id
                );
                height
            }
            let height = walk(
                &nodes,
                &fixture.header.root,
                None,
                None,
                shape.key_width,
                &mut contents,
            );
            assert!(height <= shape.avl_height);
            assert_eq!(
                &contents, expected,
                "contents differ from the reference map"
            );
            assert_eq!(fixture.header.size, expected.len());

            let mut free = 0usize;
            let mut link = fixture.header.free.duplicate();
            while link.present {
                let node = nodes[&link.id];
                assert_eq!(
                    node.leaf, link.leaf,
                    "free-list pointer to {} is stale",
                    node.id
                );
                assert!(!node.in_tree, "free list reaches tree node {}", node.id);
                free += 1;
                assert!(free <= shape.capacity, "free list cycles");
                link = node.left.duplicate();
            }
            assert_eq!(free + expected.len(), shape.capacity);
        }

        /// Run random operations against a reference map, checking the whole
        /// structure after each. Returns at the first operation that reports
        /// a failure, which only `failure_allowed` permits; reports whether
        /// one did.
        fn run_with(
            capacity: usize,
            seed: u64,
            operations: usize,
            stash_bound: usize,
            overflow_allowed: bool,
        ) -> bool {
            let mut fixture = fixture(capacity, seed, stash_bound);
            let mut expected = BTreeMap::new();
            let key_space = (2 * capacity + 3).min(250) as u8;
            let get_accesses = tree_get_accesses(fixture.shape.avl_height);
            let put_accesses = tree_put_accesses(fixture.shape.avl_height);
            for _ in 0..operations {
                let key = address(fixture.rng.gen_range(1..=key_space));
                let roll: f64 = fixture.rng.gen();
                if roll < 0.3 {
                    let got = tree_get(
                        &fixture.shape,
                        &mut fixture.store,
                        &mut fixture.stash,
                        &mut fixture.header,
                        &key,
                    );
                    let Some((value, found, failed)) = unless_overflow(got, overflow_allowed)
                    else {
                        return true;
                    };
                    assert!(!failed, "a get found the stored tree wrong");
                    let want = expected
                        .get(&key_bytes(&key))
                        .cloned()
                        .unwrap_or_else(|| Value::uint(0));
                    assert_eq!(value, want);
                    assert_eq!(found, expected.contains_key(&key_bytes(&key)));
                    fixture.assert_operation_shape(get_accesses);
                } else {
                    let value = if roll < 0.55 {
                        Value::uint(0)
                    } else {
                        Value::uint(fixture.rng.gen_range(1..1000u64))
                    };
                    let apply = fixture.rng.gen::<f64>() < 0.9;
                    let put = tree_put(
                        &fixture.shape,
                        &mut fixture.store,
                        &mut fixture.stash,
                        &mut fixture.header,
                        &key,
                        &value,
                        apply,
                    );
                    let Some((overflow, failed)) = unless_overflow(put, overflow_allowed) else {
                        return true;
                    };
                    assert!(!failed, "a put found the stored tree wrong");
                    fixture.assert_operation_shape(put_accesses);
                    let present = expected.contains_key(&key_bytes(&key));
                    let zero = value == Value::uint(0);
                    let full = expected.len() >= capacity;
                    assert_eq!(overflow, apply && !present && !zero && full);
                    if apply {
                        if zero {
                            expected.remove(&key_bytes(&key));
                        } else if present || !full {
                            expected.insert(key_bytes(&key), value);
                        }
                    }
                }
                check(&fixture, &expected);
            }
            false
        }

        /// The result of a tree operation, or `None` if its stash overflowed,
        /// which is an error of the operation and must be allowed.
        fn unless_overflow<T>(result: Result<T>, overflow_allowed: bool) -> Option<T> {
            match result {
                Ok(value) => Some(value),
                Err(error) => {
                    let error = error.to_string();
                    assert!(
                        overflow_allowed && error.contains("stash overflowed its bound"),
                        "{error}"
                    );
                    None
                }
            }
        }

        fn run(capacity: usize, seed: u64, operations: usize) {
            run_with(
                capacity,
                seed,
                operations,
                default_stash_bound(capacity),
                false,
            );
        }

        #[test]
        fn tree_avl_height_matches_fibonacci_bound() {
            for (capacity, height) in [
                (1, 1),
                (2, 2),
                (4, 3),
                (16, 5),
                (64, 8),
                (256, 11),
                (4096, 16),
                (16384, 19),
            ] {
                assert_eq!(tree_avl_height(capacity), height, "capacity {capacity}");
            }
        }

        #[test]
        fn tree_key_order_is_big_endian() {
            let low = Value::Address([0x10; 20]);
            let mut high_bytes = [0x10; 20];
            high_bytes[19] = 0x11;
            let high = Value::Address(high_bytes);
            assert!(tree_key_lt(&low, &high, 20).unwrap());
            assert!(!tree_key_lt(&high, &low, 20).unwrap());
            assert!(!tree_key_lt(&low, &low, 20).unwrap());
        }

        #[test]
        fn tree_map_matches_a_reference_map() {
            for capacity in [1, 2, 3, 5, 8] {
                for seed in 0..3 {
                    run(capacity, seed, 60);
                }
            }
        }

        #[test]
        fn tree_map_of_16_nodes_matches_a_reference_map() {
            for seed in 0..3 {
                run(16, seed, 60);
            }
        }

        #[test]
        fn tree_map_of_33_nodes_matches_a_reference_map() {
            run(33, 0, 40);
        }

        #[test]
        fn tree_map_with_a_stash_smaller_than_the_map_matches_a_reference_map() {
            // 40 nodes and a stash of 30 blocks: room for the 22 nodes a put
            // may return to it and a few more, as the 152 + 3h + 1 bound
            // leaves room for those nodes above Path ORAM's 152.
            assert!(!run_with(40, 7, 40, 30, false));
        }

        #[test]
        fn tree_map_fails_on_a_stash_overflow() {
            // A stash of two blocks cannot take back the nodes a put reads:
            // the operation stops with an error.
            assert!(run_with(16, 3, 40, 2, true));
        }

        /// A node with every field drawn at random; an unoccupied one is not
        /// the canonical empty node, so a test sees whether such a block's
        /// fields ever reach a bucket or a slot they should not.
        fn random_block(
            rng: &mut ChaCha20Rng,
            id: usize,
            leaf_count: usize,
            density: f64,
            empty: &TreeNode,
        ) -> TreeNode {
            let mut block = clone_tree_node(empty);
            block.occupied = rng.gen_bool(density);
            block.id = id;
            block.leaf = rng.gen_range(0..leaf_count);
            block.in_tree = rng.gen_bool(0.5);
            block.key = Value::Address(rng.gen());
            block.value = Value::Uint(Uint256::from_be_bytes(rng.gen()));
            for link in [&mut block.left, &mut block.right] {
                *link = TreeLink {
                    present: rng.gen_bool(0.5),
                    id: rng.gen_range(0..1_000),
                    leaf: rng.gen_range(0..leaf_count),
                    height: rng.gen_range(0..20),
                };
            }
            block
        }

        /// The eviction and compaction as they were written before the
        /// networks, with plain branches: each bucket of the path, deepest
        /// first, takes in stash order the first blocks still in the stash
        /// whose paths pass through it, up to its size; then each of the
        /// path's blocks left in the stash moves, in order, into the first
        /// empty persistent slot. Returns the buckets, the persistent slots
        /// and whether a block found no slot.
        fn evict_path_by_walking(
            blocks: &[TreeNode],
            persistent: usize,
            shape: &TreeShape,
            read_leaf: usize,
            empty: &TreeNode,
        ) -> (Vec<Vec<TreeNode>>, Vec<TreeNode>, bool) {
            let mut stash: Vec<TreeNode> = blocks.iter().map(clone_tree_node).collect();
            let mut buckets = Vec::new();
            for_each_bucket_on_leaf_path_leaf_to_root(shape.leaf_count, read_leaf, |index| {
                let mut bucket = Vec::new();
                for block in stash.iter_mut() {
                    if block.occupied
                        && bucket.len() < shape.blocks_per_bucket
                        && bucket_on_leaf_path(shape.leaf_count, index, block.leaf)
                    {
                        bucket.push(std::mem::replace(block, clone_tree_node(empty)));
                    }
                }
                while bucket.len() < shape.blocks_per_bucket {
                    bucket.push(clone_tree_node(empty));
                }
                buckets.push(bucket);
            });
            let (slots, appended) = stash.split_at_mut(persistent);
            let mut overflowed = false;
            for moving in appended.iter_mut() {
                if moving.occupied {
                    match slots.iter_mut().find(|slot| !slot.occupied) {
                        Some(slot) => *slot = std::mem::replace(moving, clone_tree_node(empty)),
                        None => overflowed = true,
                    }
                }
            }
            stash.truncate(persistent);
            (buckets, stash, overflowed)
        }

        /// The networks place every block as the bucket-by-bucket walk did:
        /// the same blocks in the same bucket slots, the same persistent
        /// slots, field for field, and the same overflow. Stashes of every
        /// density, with and without room, on paths of one to thirteen
        /// buckets.
        #[test]
        fn evict_path_places_blocks_as_the_bucket_by_bucket_walk() {
            let empty = TreeNode::empty(&key_type(), &value_type());
            let mut rng = ChaCha20Rng::seed_from_u64(0x47e7);
            let mut cases = 0usize;
            let mut overflows = 0usize;
            for leaf_count in [1usize, 2, 4, 8, 16, 64, 256, 4096] {
                let levels = leaf_count.trailing_zeros() as usize + 1;
                for per_bucket in [1usize, 2, 4, 5] {
                    for persistent in [0usize, 1, 3, 17, 60] {
                        for density in [0.0, 0.3, 0.7, 1.0] {
                            for _ in 0..4 {
                                let shape = TreeShape {
                                    capacity: leaf_count,
                                    leaf_count,
                                    blocks_per_bucket: per_bucket,
                                    avl_height: tree_avl_height(leaf_count),
                                    stash_bound: persistent,
                                    key_type: key_type(),
                                    value_type: value_type(),
                                    key_width: 20,
                                    value_width: 32,
                                };
                                let fill = persistent + levels * per_bucket;
                                let blocks: Vec<TreeNode> = (0..fill)
                                    .map(|id| {
                                        random_block(&mut rng, id, leaf_count, density, &empty)
                                    })
                                    .collect();
                                let mut stash =
                                    TreeStash::with_capacity(persistent, fill, &empty).unwrap();
                                for (slot, block) in blocks.iter().enumerate() {
                                    if slot < persistent {
                                        stash.blocks[slot] = clone_tree_node(block);
                                    } else {
                                        stash.append(block).unwrap();
                                    }
                                }
                                let read_leaf = rng.gen_range(0..leaf_count);
                                let (want_buckets, want_slots, want_overflow) =
                                    evict_path_by_walking(
                                        &blocks, persistent, &shape, read_leaf, &empty,
                                    );
                                let (buckets, overflowed) =
                                    stash.evict_path(&shape, read_leaf).unwrap();
                                assert_eq!(overflowed, want_overflow);
                                assert_eq!(buckets.len(), want_buckets.len());
                                for (bucket, want) in buckets.iter().zip(want_buckets.iter()) {
                                    assert_eq!(&bucket[..], &want[..]);
                                }
                                assert_eq!(&stash.blocks[..persistent], &want_slots[..]);
                                assert!(stash.blocks[persistent..]
                                    .iter()
                                    .all(|block| *block == empty));
                                assert_eq!(stash.fill, persistent);
                                cases += 1;
                                overflows += usize::from(overflowed);
                            }
                        }
                    }
                }
            }
            assert!(overflows > 0 && overflows < cases, "{overflows} of {cases}");
        }

        /// The sort network sorts every input of 0s and 1s up to twelve
        /// slots, so by the 0-1 principle every input; and random keys up to
        /// two hundred slots. Each compare-exchange is within the slots.
        #[test]
        fn odd_even_merge_sort_network_sorts_any_length() {
            for len in 0..=12usize {
                for bits in 0u32..(1u32 << len) {
                    let mut keys: Vec<u32> = (0..len).map(|slot| (bits >> slot) & 1).collect();
                    odd_even_merge_sort_network(len, |low, high| {
                        assert!(low < high && high < len);
                        if keys[low] > keys[high] {
                            keys.swap(low, high);
                        }
                        Ok(())
                    })
                    .unwrap();
                    assert!(
                        keys.windows(2).all(|pair| pair[0] <= pair[1]),
                        "{len} {bits:b}"
                    );
                }
            }
            let mut rng = ChaCha20Rng::seed_from_u64(0x0dd5);
            for len in 13..=200usize {
                for _ in 0..5 {
                    let mut keys: Vec<usize> = (0..len).map(|_| rng.gen_range(0..64)).collect();
                    let mut want = keys.clone();
                    want.sort_unstable();
                    odd_even_merge_sort_network(len, |low, high| {
                        assert!(low < high && high < len);
                        if keys[low] > keys[high] {
                            keys.swap(low, high);
                        }
                        Ok(())
                    })
                    .unwrap();
                    assert_eq!(keys, want);
                }
            }
        }

        /// Compaction moves the kept items to the front in their order, and
        /// expansion moves them back out to increasing targets; each leaves
        /// `keep` marking exactly where the kept items are.
        #[test]
        fn compaction_and_expansion_networks_keep_the_order() {
            let mut rng = ChaCha20Rng::seed_from_u64(0xc0de);
            for len in 0..=80usize {
                for _ in 0..20 {
                    let density = rng.gen_range(0.0..=1.0);
                    let keep: Vec<bool> = (0..len).map(|_| rng.gen_bool(density)).collect();
                    let kept: Vec<usize> = (0..len).filter(|&slot| keep[slot]).collect();
                    let mut items: Vec<usize> = (0..len).collect();
                    let mut flags = keep.clone();
                    compaction_network(&mut flags, |moves, from, to| {
                        assert!(to < from && from < len);
                        if moves {
                            items[to] = items[from];
                        }
                        Ok(())
                    })
                    .unwrap();
                    assert_eq!(&items[..kept.len()], &kept[..]);
                    assert!(flags[..kept.len()].iter().all(|flag| *flag));
                    assert!(flags[kept.len()..].iter().all(|flag| !*flag));

                    // Spread the front back out to random increasing targets.
                    let mut targets: Vec<usize> = (0..len).collect();
                    targets.retain(|_| rng.gen_bool(0.5));
                    targets.truncate(kept.len());
                    let count = targets.len();
                    let mut flags: Vec<bool> = (0..len).map(|slot| slot < count).collect();
                    let mut distance: Vec<usize> = (0..len)
                        .map(|slot| {
                            if slot < count {
                                targets[slot] - slot
                            } else {
                                0
                            }
                        })
                        .collect();
                    let mut items: Vec<usize> = (0..len).map(|slot| 1_000 + slot).collect();
                    expansion_network(&mut flags, &mut distance, |moves, from, to| {
                        assert!(from < to && to < len);
                        if moves {
                            items[to] = items[from];
                        }
                        Ok(())
                    })
                    .unwrap();
                    for (rank, target) in targets.iter().enumerate() {
                        assert_eq!(items[*target], 1_000 + rank);
                    }
                    let marked: Vec<usize> = (0..len).filter(|&slot| flags[slot]).collect();
                    assert_eq!(marked, targets);
                }
            }
        }
    }
}
