use anyhow::{anyhow, bail, Result};
use rand_chacha::ChaCha20Rng;
use serde_json::json;
use uo_allocator::{AllocatorPlan, AllocatorSession};
use uo_core::ir::StateObject;
use uo_core::manifest::{
    is_path_oram_scheme, OramManifest, PATH_ORAM_PRIVATE_POSMAP_SCHEME, SURROGATE_ORAM_SCHEME,
};
use uo_core::trace::{LogicalEvent, PhysicalReadEvent, WriteClass};
use uo_core::Value;
use uo_core::{
    RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness,
    RuntimePathOramTransitionWitness,
};
use uo_store::StoreCipher;

#[path = "generated_object_helpers.rs"]
mod generated_object_helpers;
#[path = "generated_oram_codecs.rs"]
mod generated_oram_codecs;

use generated_object_helpers::{
    decode_oram_directory_page_into_slice, decode_scalar_value, encode_oram_directory_page_into,
    filler_boxed_oram_payload, fixed_scalar_width, reseal_oram_payload_and_record_write,
    seal_boxed_oram_payload, with_opened_oram_payload,
};
use generated_oram_codecs::path_entries_from_storage;
pub(crate) use generated_oram_codecs::select_pending_put_value;
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
use generated_oram_codecs::{
    bootstrap_tree_storage, decide_pending_tree_put, refresh_tree_state_from_storage, run_tree_get,
    run_tree_put, tree_entries_from_storage, tree_position_map_witness_leaves, tree_put_accesses,
    TreeState,
};
#[cfg(test)]
use generated_oram_codecs::{
    bucket_on_leaf_path, decode_bucket_payload, deserialize_oram_bucket, oram_bucket_aad,
    oram_bucket_bytes, oram_bucket_from_entries, oram_bucket_with_live_blocks,
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

#[derive(Debug)]
pub(crate) struct OramStorage {
    directory_pages: Box<[Box<[u8]>]>,
    buckets: Box<[Box<[u8]>]>,
    access_counter_slot: Box<[u8]>,
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
        seed: u64,
        next_index: u64,
    },
    Injected {
        coins: Box<[usize]>,
        next_index: usize,
    },
}

impl Default for PathOramLeafCoinSource {
    fn default() -> Self {
        Self::Random {
            seed: 0,
            next_index: 0,
        }
    }
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

    pub(crate) fn path_position_map_witness(
        &self,
        spec: &StateObject,
    ) -> Result<RuntimePathOramPositionMapWitness> {
        let leaves = if self.is_tree() {
            tree_position_map_witness_leaves(spec, &self.parameters, &self.cipher, &self.storage)?
        } else {
            path_position_map_witness_leaves(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
            )?
        };
        Ok(RuntimePathOramPositionMapWitness {
            object_id: spec.id,
            object_name: spec.name.clone(),
            leaves,
        })
    }

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
            stored_entries = tree_entries_from_storage(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage,
                &self.empty_entry,
            )?;
            &stored_entries
        } else if self.parameters.is_path_oram() {
            stored_entries = path_entries_from_storage(
                spec,
                &self.parameters,
                &self.cipher,
                &self.storage.directory_pages,
                &self.storage.buckets,
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

    #[cfg(test)]
    pub(crate) fn access_counter_for_test(&self) -> u64 {
        self.access_counter
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
        path_entries_from_storage(
            spec,
            &self.parameters,
            &self.cipher,
            &self.storage.directory_pages,
            &self.storage.buckets,
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
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let mut cloned = cold_clone_oram_state(spec, self)?;
        cloned.refresh_from_storage(spec, allocator)?;
        Ok(cloned)
    }

    pub(crate) fn clone_committed_cold(&self, spec: &StateObject) -> Result<Self> {
        cold_clone_oram_state(spec, self)
    }

    /// The map's slots as the call sees them. On a Path ORAM map they are its
    /// directory, each slot's occupancy and key with no value: the values
    /// live only in the blocks.
    pub(crate) fn clone_logical_entries(&self) -> Result<Box<[MapEntry]>> {
        clone_boxed_map_entries(&self.entries)
    }

    pub(crate) fn cold_commit(&mut self) {
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

    pub(crate) fn instantiate(spec: &StateObject, rng: &mut ChaCha20Rng) -> Result<Self> {
        let parameters = OramParameters::for_spec(spec)?;
        let cipher = StoreCipher::from_rng(rng);
        let empty_entry = empty_map_entry(spec)?;
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
                    directory_pages,
                    buckets,
                    access_counter_slot: bootstrap_oram_counter_slot(spec, &cipher, rng)?,
                },
                access_counter: 0,
                cipher,
            };
            state.cold_commit();
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
                rng,
            )?;
            let buckets = bootstrap_filler_buckets(spec, &parameters, &cipher, rng)?;
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
                    directory_pages,
                    buckets,
                    access_counter_slot: bootstrap_oram_counter_slot(spec, &cipher, rng)?,
                },
                access_counter: 0,
                cipher,
            };
            state.cold_commit();
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
            })?;
            let directory_pages = encode_path_metadata_pages(
                spec,
                &parameters,
                &cipher,
                position_map.as_ref(),
                entries.as_ref(),
                stash.as_slice(),
                &mut bootstrap_allocator,
                rng,
            )?;
            bootstrap_allocator.finish()?;
            let buckets = bootstrap_empty_path_buckets(spec, &parameters, &cipher, rng)?;
            let mut state = Self {
                parameters,
                empty_entry,
                entries,
                position_map,
                stash,
                tree: None,
                storage: OramStorage {
                    directory_pages,
                    buckets,
                    access_counter_slot: bootstrap_oram_counter_slot(spec, &cipher, rng)?,
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
        rng: &mut ChaCha20Rng,
    ) -> Result<(Value, OramTranscript, bool)> {
        if self.parameters.is_surrogate() {
            run_surrogate_get(self, spec, key)
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
    ) -> Result<(OramTranscript, bool)> {
        if self.parameters.is_surrogate() {
            run_surrogate_put(self, spec, key, value, apply)
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
                decode_surrogate_entries_from_storage_into(
                    spec,
                    &old.parameters,
                    &old.cipher,
                    &old.storage.directory_pages,
                    allocator,
                    &old.empty_entry,
                    &mut next.entries,
                )?;
            }
            let empty_entry = empty_map_entry(spec)?;
            if old.storage.directory_pages.len() != next.parameters.metadata_pages
                || next.storage.directory_pages.len() != next.parameters.metadata_pages
            {
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
                rng,
                &mut next.storage.directory_pages,
                &mut writes,
            )?;
            let next_counter = old.access_counter + 1;
            rewrite_oram_counter_in_place(
                spec,
                next_counter,
                &next.cipher,
                allocator,
                rng,
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
                rng,
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
            let _ = (spec, old, aborted, allocator, rng);
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
        rng: &mut ChaCha20Rng,
    ) -> Result<(Value, bool, Box<[OramTranscript]>, bool)> {
        run_tree_get(self, spec, key, allocator, leaf_coins, rng)
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
        rng: &mut ChaCha20Rng,
    ) -> Result<Box<[OramTranscript]>> {
        let (transcripts, overflowed, failed) = run_tree_put(
            self,
            spec,
            &put.key,
            &put.value,
            put.apply & !aborted,
            allocator,
            leaf_coins,
            rng,
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
        rng: &mut ChaCha20Rng,
    ) -> Result<OramTranscript> {
        run_path_commit_put(self, spec, put, aborted, allocator, leaf_coins, rng)
    }

    fn path_get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        allocator: &mut AllocatorSession,
        leaf_coins: &mut PathOramLeafCoinSource,
        rng: &mut ChaCha20Rng,
    ) -> Result<(Value, OramTranscript, bool)> {
        run_path_get(self, spec, key, allocator, leaf_coins, rng)
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
    ) -> Result<(OramTranscript, bool)> {
        run_path_put(self, spec, key, value, apply, allocator, leaf_coins, rng)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        bucket_on_leaf_path, decode_bucket_payload, deserialize_oram_bucket, empty_map_entry,
        encode_path_metadata_pages, generated_oram_codecs::decode_path_metadata_pages,
        oram_bucket_bytes, oram_bucket_from_entries, oram_bucket_with_live_blocks,
        repeat_boxed_map_entries, repeat_boxed_masked_usize_options, MapEntry, MaskedUsizeOption,
        OramBlock, OramParameters, OramState, PathOramLeafCoinSource, SURROGATE_ORAM_SCHEME,
    };
    use rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;
    use uo_allocator::{AllocatorPlan, AllocatorSession};
    use uo_core::ir::{BackendKind, ContainerKind, StateObject};
    use uo_core::manifest::PATH_ORAM_SCHEME;
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
            max_commit_ops: 0,
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
        let mut rebuilt = state.clone_committed_cold(spec).unwrap();
        let mut allocator = allocator_for_path_oram(&rebuilt.parameters);
        rebuilt.refresh_from_storage(spec, &mut allocator).unwrap();
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

    fn path_oram_state_with_stash(
        spec: &StateObject,
        stash: Vec<OramBlock>,
        seed: u64,
    ) -> OramState {
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut state = OramState::instantiate(spec, &mut rng).unwrap();
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
        state.storage.directory_pages = encode_path_metadata_pages(
            spec,
            &state.parameters,
            &state.cipher,
            &masked_position_map,
            &state.entries,
            &stash,
            &mut allocator,
            &mut rng,
        )
        .unwrap();
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
        seed: u64,
    ) {
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let masked_position_map = masked_position_map_from_options(position_map);
        let mut entries =
            repeat_boxed_map_entries(state.parameters.capacity, &empty_map_entry(spec).unwrap())
                .unwrap();
        for (slot, key) in directory {
            entries[*slot] = MapEntry::new(true, key.clone(), Value::uint(0));
        }
        state.storage.directory_pages = encode_path_metadata_pages(
            spec,
            &state.parameters,
            &state.cipher,
            &masked_position_map,
            &entries,
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
        let cloned = state.clone_for_tx(&spec, &mut allocator).unwrap();

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
                Value::uint(17),
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
    fn path_oram_get_reports_working_stash_overflow_in_band() {
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5010);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
        let (value, _transcript, overflowed) = state
            .get(
                &spec,
                &Value::Address([0xEE; 20]),
                &mut allocator,
                &mut leaf_coins,
                &mut rng,
            )
            .unwrap();
        allocator.finish().unwrap();

        assert_eq!(value, Value::uint(0));
        assert!(overflowed);
    }

    #[test]
    fn surrogate_commit_reads_old_entries_from_storage_on_abort() {
        let spec = oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5153);
        let mut old = OramState::instantiate(&spec, &mut rng).unwrap();
        let mut old_allocator = allocator_for_path_oram(&old.parameters);
        old.refresh_from_storage(&spec, &mut old_allocator).unwrap();
        old_allocator.finish().unwrap();
        let expected_entries = map_entries_snapshot(&old.entries);
        old.entries[0] = MapEntry {
            occupied: true,
            key: Value::Address([0x11; 20]),
            value: Value::uint(7),
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
            value: Value::uint(9),
        };

        let mut commit_allocator = allocator_for_path_oram(&new.parameters);
        let mut commit_rng = ChaCha20Rng::seed_from_u64(0x9191);
        let commit = new
            .commit(&spec, &old, true, &mut commit_allocator, &mut commit_rng)
            .unwrap();
        commit_allocator.finish().unwrap();

        assert_eq!(map_entries_snapshot(&commit.next.entries), expected_entries);
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

        let mut rebuilt = commit.next.clone_committed_cold(&spec).unwrap();
        let mut refresh_allocator = allocator_for_path_oram(&rebuilt.parameters);
        rebuilt
            .refresh_from_storage(&spec, &mut refresh_allocator)
            .unwrap();
        refresh_allocator.finish().unwrap();
        assert_eq!(map_entries_snapshot(&rebuilt.entries), expected_entries);
    }

    #[test]
    fn surrogate_get_returns_zero_for_missing_key_after_full_scan_lookup() {
        let spec = oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x5154);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
                &mut rng,
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
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
                &mut rng,
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
        let mut rng = ChaCha20Rng::seed_from_u64(0x5EED);
        let cipher = StoreCipher::random();
        let mut encode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
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
            &mut rng,
        )
        .unwrap();
        let mut decode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
        })
        .unwrap();
        let err =
            decode_path_metadata_pages(&spec, &parameters, &cipher, &pages, &mut decode_allocator)
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
        let mut rng = ChaCha20Rng::seed_from_u64(0xD1CE7A11);
        let cipher = StoreCipher::random();
        let mut encode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
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
            &mut rng,
        )
        .unwrap();
        assert_eq!(pages.len(), parameters.metadata_pages);
        let mut decode_allocator = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: parameters.directory_page_bytes,
            max_kernel_ops: 0,
            max_commit_ops: 0,
        })
        .unwrap();
        let (decoded_position_map, decoded_stash) =
            decode_path_metadata_pages(&spec, &parameters, &cipher, &pages, &mut decode_allocator)
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
        let mut first_rng = ChaCha20Rng::seed_from_u64(0xD3117E);
        let mut second_rng = ChaCha20Rng::seed_from_u64(0xD3117E);

        let (first_transcript, first_overflowed) = first
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
        let (second_transcript, second_overflowed) = second
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
        // A call starts from the metadata pages alone: corrupting every
        // bucket leaves the refresh untouched.
        let spec = path_oram_spec();
        let original_stash = vec![OramBlock {
            occupied: true,
            slot_index: 2,
            leaf: 1,
            key: Value::Address([0x33; 20]),
            value: Value::uint(4),
        }];
        let mut state = path_oram_state_with_stash(&spec, original_stash, 0xB0C7);
        for bucket in state.storage.buckets.iter_mut() {
            bucket.fill(0xFF);
        }
        let mut allocator = allocator_for_path_oram(&state.parameters);
        let cloned = state.clone_for_tx(&spec, &mut allocator).unwrap();
        assert_eq!(cloned.position_map[2].to_option(), Some(1));
        assert!(cloned.entries[2].matches_key(&Value::Address([0x33; 20])));
        assert_eq!(cloned.entries[2].value(), &Value::uint(0));
    }

    #[test]
    fn path_oram_get_reads_the_value_from_the_keys_block() {
        // The value comes from the key's block once its path is read; the
        // directory holds no value.
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0x7A1E);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
            0x7A1F,
        );
        let leaf_bucket = state.parameters.leaf_count() - 1 + leaf;
        let bucket = oram_bucket_with_live_blocks(&spec, 0, leaf_bucket, 1, &[block]).unwrap();
        let aad = super::oram_bucket_aad(&spec, leaf_bucket);
        let mut payload = oram_bucket_bytes(&bucket, &spec).unwrap();
        state.storage.buckets[leaf_bucket] = state
            .cipher
            .seal_and_wipe_boxed(aad.as_bytes(), &mut payload, &mut rng)
            .unwrap();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.refresh_from_storage(&spec, &mut allocator).unwrap();
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let (value, transcript, failed) = state
            .get(
                &spec,
                &Value::Address([0x77; 20]),
                &mut allocator,
                &mut leaf_coins,
                &mut rng,
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
        let mut rng = ChaCha20Rng::seed_from_u64(0xBAD5EED);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
            0xBAD5EED,
        );
        let bucket = oram_bucket_with_live_blocks(&spec, 0, 0, 1, &[duplicate]).unwrap();
        let aad = super::oram_bucket_aad(&spec, 0);
        let mut payload = oram_bucket_bytes(&bucket, &spec).unwrap();
        state.storage.buckets[0] = state
            .cipher
            .seal_and_wipe_boxed(aad.as_bytes(), &mut payload, &mut rng)
            .unwrap();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.refresh_from_storage(&spec, &mut allocator).unwrap();
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let (_value, _transcript, failed) = state
            .get(
                &spec,
                &Value::Address([0x44; 20]),
                &mut allocator,
                &mut leaf_coins,
                &mut rng,
            )
            .unwrap();
        assert!(failed);
    }

    #[test]
    fn path_oram_get_reports_position_map_leaf_mismatch_in_band() {
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0xBADC0DE);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
            0xBADC0DE,
        );

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.refresh_from_storage(&spec, &mut allocator).unwrap();
        let mut leaf_coins = PathOramLeafCoinSource::random();
        let (_value, _transcript, failed) = state
            .get(
                &spec,
                &Value::Address([0x55; 20]),
                &mut allocator,
                &mut leaf_coins,
                &mut rng,
            )
            .unwrap();
        assert!(failed);
    }

    #[test]
    fn path_oram_access_rejects_bucket_block_off_its_path() {
        let spec = path_oram_spec();
        let mut rng = ChaCha20Rng::seed_from_u64(0xFACE123);
        let mut state = OramState::instantiate(&spec, &mut rng).unwrap();
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
            0xFACE123,
        );
        let off_path_bucket = 1usize;
        assert!(!super::bucket_on_leaf_path(
            state.parameters.leaf_count(),
            off_path_bucket,
            leaf
        ));
        let bucket = oram_bucket_with_live_blocks(&spec, 0, off_path_bucket, 1, &[block]).unwrap();
        let aad = super::oram_bucket_aad(&spec, off_path_bucket);
        let mut payload = oram_bucket_bytes(&bucket, &spec).unwrap();
        state.storage.buckets[off_path_bucket] = state
            .cipher
            .seal_and_wipe_boxed(aad.as_bytes(), &mut payload, &mut rng)
            .unwrap();

        let mut allocator = allocator_for_path_oram(&state.parameters);
        state.refresh_from_storage(&spec, &mut allocator).unwrap();
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
                &mut rng,
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
            bucket_on_leaf_path, clone_tree_node, tree_avl_height, tree_bootstrap_nodes, tree_get,
            tree_get_accesses, tree_key_lt, tree_place_nodes, tree_put, tree_put_accesses,
            TreeAccessRecord, TreeHeader, TreeLink, TreeNode, TreePathStore, TreeShape, TreeStash,
        };
        use anyhow::Result;
        use rand::{Rng, SeedableRng};
        use rand_chacha::ChaCha20Rng;
        use std::collections::BTreeMap;
        use uo_core::{ScalarType, Type, Value};

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
            capacity.clamp(1, 114 + tree_put_accesses(tree_avl_height(capacity)))
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
            failure_allowed: bool,
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
                    let (value, found, failed) = tree_get(
                        &fixture.shape,
                        &mut fixture.store,
                        &mut fixture.stash,
                        &mut fixture.header,
                        &key,
                    )
                    .unwrap();
                    if failed {
                        assert!(failure_allowed, "a get failed");
                        return true;
                    }
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
                    let (overflow, failed) = tree_put(
                        &fixture.shape,
                        &mut fixture.store,
                        &mut fixture.stash,
                        &mut fixture.header,
                        &key,
                        &value,
                        apply,
                    )
                    .unwrap();
                    if failed {
                        assert!(failure_allowed, "a put failed");
                        return true;
                    }
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
            // may return to it and a few more, as the 114 + 3h + 1 bound
            // leaves room for those nodes above Path ORAM's 114.
            assert!(!run_with(40, 7, 40, 30, false));
        }

        #[test]
        fn tree_map_reports_a_stash_overflow() {
            // A stash of two blocks cannot take back the nodes a put reads.
            assert!(run_with(16, 3, 40, 2, true));
        }
    }
}
