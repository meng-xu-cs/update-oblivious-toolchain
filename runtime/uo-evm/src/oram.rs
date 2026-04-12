use anyhow::{anyhow, bail, Result};
use rand::RngCore;
use rand_chacha::ChaCha20Rng;
use uo_core::ir::StateObject;
use uo_core::manifest::{PATH_ORAM_SCHEME, SURROGATE_ORAM_SCHEME};
use uo_core::trace::{LogicalEvent, PhysicalReadEvent};
use uo_core::{ScalarType, Type, Value};
use uo_core::{RuntimePathOramTransitionKind, RuntimePathOramTransitionWitness};
use uo_store::StoreCipher;

pub(crate) const ORAM_DIRECTORY_PAGE_ENTRIES: usize = 8;
const ORAM_BUCKET_HEADER_BYTES: usize = 24;
const SURROGATE_BLOCKS_PER_BUCKET: usize = 2;
const PATH_BLOCKS_PER_BUCKET: usize = 4;
const ORAM_SLOT_INDEX_BYTES: usize = 8;
const ORAM_LEAF_LABEL_BYTES: usize = 8;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct MapEntry {
    pub occupied: bool,
    pub key: Value,
    pub value: Value,
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
        let key_type = spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
        let key_len = fixed_scalar_width(key_type)?;
        let value_len = fixed_scalar_width(&spec.value_type)?;
        match spec.oram_scheme.as_str() {
            SURROGATE_ORAM_SCHEME => {
                let block_size = 1 + key_len + value_len;
                let bucket_size = ORAM_BUCKET_HEADER_BYTES + SURROGATE_BLOCKS_PER_BUCKET * block_size;
                let tree_height = log2_ceil(capacity.max(2));
                let metadata_pages = oram_directory_page_count(capacity);
                Ok(Self {
                    scheme: SURROGATE_ORAM_SCHEME.into(),
                    capacity,
                    block_size,
                    bucket_size,
                    bucket_count: capacity.max(1).next_power_of_two().max(8) / 2,
                    blocks_per_bucket: SURROGATE_BLOCKS_PER_BUCKET,
                    tree_height,
                    stash_bound: 0,
                    recursion_depth: 0,
                    metadata_pages,
                    metadata_pages_per_access: metadata_pages + 1,
                    accesses_per_call: 1,
                    buckets_per_access: (tree_height + 2).max(3),
                    directory_page_entries: ORAM_DIRECTORY_PAGE_ENTRIES,
                    directory_page_bytes: ORAM_DIRECTORY_PAGE_ENTRIES * block_size,
                })
            }
            PATH_ORAM_SCHEME => {
                let leaf_count = capacity.max(2).next_power_of_two();
                let tree_height = log2_ceil(leaf_count);
                let block_size = 1 + ORAM_SLOT_INDEX_BYTES + ORAM_LEAF_LABEL_BYTES + key_len + value_len;
                let bucket_size = ORAM_BUCKET_HEADER_BYTES + PATH_BLOCKS_PER_BUCKET * block_size;
                let stash_bound = capacity.max(1);
                let metadata_pages =
                    oram_directory_page_count(capacity) + oram_directory_page_count(stash_bound);
                Ok(Self {
                    scheme: PATH_ORAM_SCHEME.into(),
                    capacity,
                    block_size,
                    bucket_size,
                    bucket_count: 2 * leaf_count - 1,
                    blocks_per_bucket: PATH_BLOCKS_PER_BUCKET,
                    tree_height,
                    stash_bound,
                    recursion_depth: 0,
                    metadata_pages,
                    metadata_pages_per_access: metadata_pages + 1,
                    accesses_per_call: 1,
                    buckets_per_access: tree_height + 1,
                    directory_page_entries: ORAM_DIRECTORY_PAGE_ENTRIES,
                    directory_page_bytes: ORAM_DIRECTORY_PAGE_ENTRIES * block_size,
                })
            }
            other => bail!("unsupported ORAM scheme {} for {}", other, spec.name),
        }
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
            self.metadata_pages.saturating_sub(self.position_map_pages())
        } else {
            0
        }
    }
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
    pub path_leaf: Option<usize>,
    pub path_transition: Option<RuntimePathOramTransitionWitness>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramWrite {
    pub location: String,
    pub old: Vec<u8>,
    pub new: Vec<u8>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramCommit {
    pub next: OramState,
    pub writes: Vec<OramWrite>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramState {
    pub parameters: OramParameters,
    pub entries: Vec<MapEntry>,
    pub position_map: Vec<Option<usize>>,
    pub stash: Vec<OramBlock>,
    pub storage: OramStorage,
    pub access_counter: u64,
    pub cipher: StoreCipher,
}

impl OramState {
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
                    let payload = encode_oram_directory_page(&entries[start..end], &empty_entry);
                    let aad = oram_meta_aad(spec, page);
                    cipher.seal(aad.as_bytes(), &payload, rng)
                })
                .collect();
            let buckets = (0..parameters.bucket_count)
                .map(|index| {
                    let aad = oram_bucket_aad(spec, index);
                    cipher.filler(aad.as_bytes(), parameters.bucket_size, rng)
                })
                .collect();
            Ok(Self {
                parameters,
                entries,
                position_map: Vec::new(),
                stash: Vec::new(),
                storage: OramStorage {
                    directory_pages,
                    buckets,
                    access_counter_slot: cipher
                        .seal(oram_counter_aad(spec).as_bytes(), &0u64.to_be_bytes(), rng),
                },
                access_counter: 0,
                cipher,
            })
        } else {
            let position_map = vec![None; parameters.capacity];
            let stash = Vec::new();
            let directory_pages =
                encode_path_metadata_pages(spec, &parameters, &cipher, &position_map, &stash, rng)?;
            let buckets = (0..parameters.bucket_count)
                .map(|index| {
                    let aad = oram_bucket_aad(spec, index);
                    let empty_bucket = OramBucket::empty(spec, index)?;
                    Ok(cipher.seal(aad.as_bytes(), &empty_bucket.serialize(spec)?, rng))
                })
                .collect::<Result<Vec<_>>>()?;
            Ok(Self {
                parameters,
                entries,
                position_map,
                stash,
                storage: OramStorage {
                    directory_pages,
                    buckets,
                    access_counter_slot: cipher
                        .seal(oram_counter_aad(spec).as_bytes(), &0u64.to_be_bytes(), rng),
                },
                access_counter: 0,
                cipher,
            })
        }
    }

    pub(crate) fn refresh_from_storage(&mut self, spec: &StateObject) -> Result<()> {
        let counter_bytes = self
            .cipher
            .open(oram_counter_aad(spec).as_bytes(), 8, &self.storage.access_counter_slot)
            .ok_or_else(|| anyhow!("failed to decode ORAM counter for {}", spec.name))?;
        let mut counter = [0u8; 8];
        counter.copy_from_slice(&counter_bytes);
        self.access_counter = u64::from_be_bytes(counter);
        if self.parameters.is_surrogate() {
            let mut entries = Vec::new();
            for (page_index, page) in self.storage.directory_pages.iter().enumerate() {
                let aad = oram_meta_aad(spec, page_index);
                let payload = self
                    .cipher
                    .open(aad.as_bytes(), self.parameters.directory_page_bytes, page)
                    .ok_or_else(|| anyhow!("failed to decode ORAM metadata page for {}", spec.name))?;
                entries.extend(decode_oram_directory_page(&payload, spec)?);
            }
            entries.truncate(self.parameters.capacity);
            self.entries = entries;
        } else {
            let (position_map, stash) =
                decode_path_metadata_pages(spec, &self.parameters, &self.cipher, &self.storage.directory_pages)?;
            self.position_map = position_map;
            self.stash = stash;
            self.entries = self.reconstruct_path_entries(spec)?;
        }
        Ok(())
    }

    pub(crate) fn get(
        &mut self,
        spec: &StateObject,
        key: &Value,
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
            self.path_get(spec, key, rng)
        }
    }

    pub(crate) fn put(
        &mut self,
        spec: &StateObject,
        key: Value,
        value: Value,
        apply: bool,
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
            self.path_put(spec, key, value, apply, rng)
        }
    }

    pub(crate) fn commit(
        &self,
        spec: &StateObject,
        old: &Self,
        aborted: bool,
        rng: &mut ChaCha20Rng,
    ) -> Result<OramCommit> {
        if self.parameters.is_surrogate() {
            let source_entries = if aborted { &old.entries } else { &self.entries };
            let empty_entry = empty_map_entry(spec)?;
            let mut next = self.clone();
            let mut writes = Vec::new();
            for page in 0..old.storage.directory_pages.len() {
                let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
                let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(source_entries.len());
                let old_physical = old.storage.directory_pages[page].clone();
                let payload = encode_oram_directory_page(&source_entries[start..end], &empty_entry);
                let aad = oram_meta_aad(spec, page);
                let new_physical = self.cipher.seal(aad.as_bytes(), &payload, rng);
                writes.push(OramWrite {
                    location: format!("{}@meta{page}", spec.name),
                    old: old_physical,
                    new: new_physical.clone(),
                });
                next.storage.directory_pages[page] = new_physical;
            }
            let next_counter = old.access_counter + 1;
            let old_counter_physical = old.storage.access_counter_slot.clone();
            let new_counter_physical = self
                .cipher
                .seal(oram_counter_aad(spec).as_bytes(), &next_counter.to_be_bytes(), rng);
            writes.push(OramWrite {
                location: format!("{}@counter", spec.name),
                old: old_counter_physical,
                new: new_counter_physical.clone(),
            });
            next.storage.access_counter_slot = new_counter_physical;
            for index in self.surrogate_bucket_window() {
                let old_physical = old.storage.buckets[index].clone();
                let payload =
                    OramBucket::from_entries(spec, source_entries, old.access_counter, index)?
                        .serialize(spec)?;
                let aad = oram_bucket_aad(spec, index);
                let new_physical = self.cipher.seal(aad.as_bytes(), &payload, rng);
                writes.push(OramWrite {
                    location: format!("{}@bucket{index}", spec.name),
                    old: old_physical,
                    new: new_physical.clone(),
                });
                next.storage.buckets[index] = new_physical;
            }
            next.entries = source_entries.clone();
            next.access_counter = next_counter;
            Ok(OramCommit { next, writes })
        } else {
            let next = if aborted { old.clone() } else { self.clone() };
            let _ = rng;
            Ok(OramCommit {
                next,
                writes: Vec::new(),
            })
        }
    }

    fn surrogate_access_transcript(&self, spec: &StateObject) -> OramTranscript {
        let mut logical_accesses = Vec::new();
        let mut physical_reads = Vec::new();
        let metadata_pages = (0..self.storage.directory_pages.len()).collect::<Vec<_>>();
        let bucket_indices = self.surrogate_bucket_window();

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

        for page in &metadata_pages {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_meta_scan".into(),
                object: spec.name.clone(),
                detail: format!("page:{page}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@meta{page}", spec.name),
                len: self.storage.directory_pages[*page].len(),
            });
        }

        for index in &bucket_indices {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_bucket_scan".into(),
                object: spec.name.clone(),
                detail: format!("bucket:{index}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@bucket{index}", spec.name),
                len: self.storage.buckets[*index].len(),
            });
        }

        OramTranscript {
            logical_accesses,
            physical_reads,
            physical_writes: Vec::new(),
            path_leaf: None,
            path_transition: None,
        }
    }

    fn surrogate_bucket_window(&self) -> Vec<usize> {
        (0..self.parameters.buckets_per_access)
            .map(|offset| ((self.access_counter as usize) + offset) % self.storage.buckets.len())
            .collect()
    }

    fn access_leaf_for_key(&self, key: &Value, rng: &mut ChaCha20Rng) -> usize {
        if let Some(slot) = self.find_slot(key) {
            self.position_map
                .get(slot)
                .and_then(|leaf| *leaf)
                .unwrap_or_else(|| sample_leaf(rng, self.parameters.leaf_count()))
        } else {
            sample_leaf(rng, self.parameters.leaf_count())
        }
    }

    fn find_slot(&self, key: &Value) -> Option<usize> {
        self.entries
            .iter()
            .position(|entry| entry.occupied && entry.key == *key)
    }

    fn path_access_transcript(&self, spec: &StateObject, leaf: usize) -> OramTranscript {
        let mut logical_accesses = Vec::new();
        let mut physical_reads = Vec::new();
        let metadata_pages = (0..self.storage.directory_pages.len()).collect::<Vec<_>>();
        let bucket_indices = path_bucket_indices(self.parameters.leaf_count(), leaf);

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

        for page in &metadata_pages {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_metadata_load".into(),
                object: spec.name.clone(),
                detail: format!("page:{page}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@meta{page}", spec.name),
                len: self.storage.directory_pages[*page].len(),
            });
        }

        for index in &bucket_indices {
            logical_accesses.push(LogicalEvent {
                kind: "uooram_path_read".into(),
                object: spec.name.clone(),
                detail: format!("bucket:{index}"),
            });
            physical_reads.push(PhysicalReadEvent {
                object: spec.name.clone(),
                location: format!("{}@bucket{index}", spec.name),
                len: self.storage.buckets[*index].len(),
            });
        }

        OramTranscript {
            logical_accesses,
            physical_reads,
            physical_writes: Vec::new(),
            path_leaf: Some(leaf),
            path_transition: None,
        }
    }

    fn reconstruct_path_entries(&self, spec: &StateObject) -> Result<Vec<MapEntry>> {
        let mut entries = vec![empty_map_entry(spec)?; self.parameters.capacity];
        for block in &self.stash {
            if block.occupied {
                entries[block.slot_index] = MapEntry {
                    occupied: true,
                    key: block.key.clone(),
                    value: block.value.clone(),
                };
            }
        }
        for index in 0..self.parameters.bucket_count {
            let bucket = self.decode_bucket(spec, index)?;
            for block in bucket.blocks {
                if block.occupied {
                    entries[block.slot_index] = MapEntry {
                        occupied: true,
                        key: block.key,
                        value: block.value,
                    };
                }
            }
        }
        Ok(entries)
    }

    fn decode_bucket(&self, spec: &StateObject, index: usize) -> Result<OramBucket> {
        let aad = oram_bucket_aad(spec, index);
        let payload = self
            .cipher
            .open(aad.as_bytes(), self.parameters.bucket_size, &self.storage.buckets[index])
            .ok_or_else(|| anyhow!("failed to decode ORAM bucket {} for {}", index, spec.name))?;
        OramBucket::deserialize(spec, &payload)
    }

    fn path_get(
        &mut self,
        spec: &StateObject,
        key: &Value,
        rng: &mut ChaCha20Rng,
    ) -> Result<(Value, OramTranscript)> {
        let access_leaf = self.access_leaf_for_key(key, rng);
        let leaf_count = self.parameters.leaf_count();
        let slot = slot_for_key(&self.entries, key);
        let prior_leaf = slot.and_then(|slot_index| self.position_map.get(slot_index).copied().flatten());
        let next_leaf = slot.map(|_| sample_leaf(rng, leaf_count));
        let return_value = self
            .entries
            .iter()
            .find(|entry| entry.occupied && entry.key == *key)
            .map(|entry| entry.value.clone())
            .unwrap_or_else(|| Value::zero_for_type(&spec.value_type));
        let writes = self.rewrite_path_for_access(
            spec,
            access_leaf,
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
        rng: &mut ChaCha20Rng,
    ) -> Result<OramTranscript> {
        let access_leaf = self.access_leaf_for_key(&key, rng);
        let leaf_count = self.parameters.leaf_count();
        let slot = slot_for_key(&self.entries, &key);
        let prior_leaf = slot.and_then(|slot_index| self.position_map.get(slot_index).copied().flatten());
        let insert_slot = if slot.is_none() && apply && !value.is_zero_like() {
            allocate_slot(&self.entries)
        } else {
            None
        };
        let next_leaf = match (slot, apply, value.is_zero_like(), insert_slot) {
            (Some(_), true, false, _) => Some(sample_leaf(rng, leaf_count)),
            (None, true, false, Some(_)) => Some(sample_leaf(rng, leaf_count)),
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
        let writes = self.rewrite_path_for_access(
            spec,
            access_leaf,
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
        transcript.path_transition = Some(transition);
        Ok(transcript)
    }

    fn rewrite_path_for_access<F>(
        &mut self,
        spec: &StateObject,
        access_leaf: usize,
        rng: &mut ChaCha20Rng,
        update: F,
    ) -> Result<Vec<OramWrite>>
    where
        F: FnOnce(
            &mut Vec<MapEntry>,
            &mut Vec<Option<usize>>,
            &mut Vec<OramBlock>,
            &mut ChaCha20Rng,
        ) -> Result<()>,
    {
        let mut writes = Vec::new();
        let path = path_bucket_indices(self.parameters.leaf_count(), access_leaf);
        let mut working_entries = self.entries.clone();
        let mut working_position_map = self.position_map.clone();
        let mut working_stash = self.stash.clone();

        for bucket_index in &path {
            let bucket = self.decode_bucket(spec, *bucket_index)?;
            working_stash.extend(bucket.blocks.into_iter().filter(|block| block.occupied));
        }

        update(&mut working_entries, &mut working_position_map, &mut working_stash, rng)?;

        if working_stash.len() > self.parameters.stash_bound + self.parameters.buckets_per_access {
            bail!(
                "stash bound exceeded for {} under path ORAM candidate",
                spec.name
            );
        }

        for bucket_index in path.iter().rev() {
            let bucket = build_path_bucket(&self.parameters, *bucket_index, &mut working_stash)?;
            let payload = bucket.serialize(spec)?;
            let aad = oram_bucket_aad(spec, *bucket_index);
            let old_physical = self.storage.buckets[*bucket_index].clone();
            let new_physical = self.cipher.seal(aad.as_bytes(), &payload, rng);
            self.storage.buckets[*bucket_index] = new_physical.clone();
            writes.push(OramWrite {
                location: format!("{}@bucket{}", spec.name, bucket_index),
                old: old_physical,
                new: new_physical,
            });
        }

        if working_stash.len() > self.parameters.stash_bound {
            bail!("stash bound exceeded for {}", spec.name);
        }

        let new_directory_pages = encode_path_metadata_pages(
            spec,
            &self.parameters,
            &self.cipher,
            &working_position_map,
            &working_stash,
            rng,
        )?;
        for (page, new_physical) in new_directory_pages.into_iter().enumerate() {
            let old_physical = self.storage.directory_pages[page].clone();
            self.storage.directory_pages[page] = new_physical.clone();
            writes.push(OramWrite {
                location: format!("{}@meta{page}", spec.name),
                old: old_physical,
                new: new_physical,
            });
        }

        let next_counter = self.access_counter + 1;
        let old_counter_physical = self.storage.access_counter_slot.clone();
        let new_counter_physical = self
            .cipher
            .seal(oram_counter_aad(spec).as_bytes(), &next_counter.to_be_bytes(), rng);
        self.storage.access_counter_slot = new_counter_physical.clone();
        writes.push(OramWrite {
            location: format!("{}@counter", spec.name),
            old: old_counter_physical,
            new: new_counter_physical,
        });

        self.entries = working_entries;
        self.position_map = working_position_map;
        self.stash = working_stash;
        self.access_counter = next_counter;
        Ok(writes)
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
        pages.push(cipher.seal(aad.as_bytes(), &payload, rng));
    }
    for page in 0..parameters.stash_pages() {
        let start = page * ORAM_DIRECTORY_PAGE_ENTRIES;
        let end = (start + ORAM_DIRECTORY_PAGE_ENTRIES).min(stash.len());
        let mut payload = Vec::with_capacity(parameters.directory_page_bytes);
        if start < stash.len() {
            for block in &stash[start..end] {
                payload.extend_from_slice(&block.serialize(spec)?);
            }
        }
        while payload.len() < parameters.directory_page_bytes {
            payload.extend_from_slice(&OramBlock::empty(spec)?.serialize(spec)?);
        }
        let aad = oram_meta_aad(spec, parameters.position_map_pages() + page);
        pages.push(cipher.seal(aad.as_bytes(), &payload, rng));
    }
    Ok(pages)
}

fn decode_path_metadata_pages(
    spec: &StateObject,
    parameters: &OramParameters,
    cipher: &StoreCipher,
    pages: &[Vec<u8>],
) -> Result<(Vec<Option<usize>>, Vec<OramBlock>)> {
    let mut position_map = Vec::with_capacity(parameters.capacity);
    for page in 0..parameters.position_map_pages() {
        let aad = oram_meta_aad(spec, page);
        let payload = cipher
            .open(aad.as_bytes(), parameters.directory_page_bytes, &pages[page])
            .ok_or_else(|| anyhow!("failed to decode ORAM position map page {}", page))?;
        for slot in payload.chunks_exact(8).take(ORAM_DIRECTORY_PAGE_ENTRIES) {
            if position_map.len() == parameters.capacity {
                break;
            }
            let mut encoded = [0u8; 8];
            encoded.copy_from_slice(slot);
            let value = u64::from_be_bytes(encoded);
            if value == u64::MAX {
                position_map.push(None);
            } else {
                position_map.push(Some(
                    usize::try_from(value)
                        .map_err(|_| anyhow!("leaf label overflow for {}", spec.name))?,
                ));
            }
        }
    }
    let mut stash = Vec::new();
    for page in 0..parameters.stash_pages() {
        let page_index = parameters.position_map_pages() + page;
        let aad = oram_meta_aad(spec, page_index);
        let payload = cipher
            .open(aad.as_bytes(), parameters.directory_page_bytes, &pages[page_index])
            .ok_or_else(|| anyhow!("failed to decode ORAM stash page {}", page_index))?;
        for block_bytes in payload.chunks_exact(parameters.block_size) {
            let block = OramBlock::deserialize(spec, block_bytes)?;
            if block.occupied {
                stash.push(block);
            }
        }
    }
    Ok((position_map, stash))
}

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
    stash.remove(index);
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
            block.occupied
                && path_bucket_indices(parameters.leaf_count(), block.leaf).contains(&bucket_index)
        }) else {
            break;
        };
        blocks.push(stash.remove(candidate_index));
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

    fn serialize(&self, spec: &StateObject) -> Result<Vec<u8>> {
        let key_type = spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
        let mut out = Vec::with_capacity(OramParameters::for_spec(spec)?.block_size);
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
        out.extend_from_slice(&encode_scalar_value(key_type, &self.key)?);
        out.extend_from_slice(&encode_scalar_value(&spec.value_type, &self.value)?);
        Ok(out)
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
        for slot in 0..parameters.blocks_per_bucket {
            if let Some(block) = self.blocks.get(slot) {
                out.extend_from_slice(&block.serialize(spec)?);
            } else {
                out.extend_from_slice(&OramBlock::empty(spec)?.serialize(spec)?);
            }
        }
        if out.len() != parameters.bucket_size {
            bail!(
                "unexpected ORAM bucket length for {}: {} != {}",
                spec.name,
                out.len(),
                parameters.bucket_size
            );
        }
        Ok(out)
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
    let mut out = vec![if entry.occupied { 0x7d } else { 0x53 }];
    out.extend_from_slice(&entry.key.canonical_bytes());
    out.extend_from_slice(&entry.value.canonical_bytes());
    out
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
    let mut out = Vec::new();
    for index in 0..ORAM_DIRECTORY_PAGE_ENTRIES {
        let entry = entries.get(index).unwrap_or(empty_entry);
        out.extend_from_slice(&map_record_bytes(entry));
    }
    out
}

fn decode_oram_directory_page(payload: &[u8], spec: &StateObject) -> Result<Vec<MapEntry>> {
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
    let key_len = fixed_scalar_width(key_type)?;
    let value_len = fixed_scalar_width(&spec.value_type)?;
    let mut entries = Vec::with_capacity(ORAM_DIRECTORY_PAGE_ENTRIES);
    for record in payload.chunks_exact(record_len) {
        let occupied = match record[0] {
            0x7d => true,
            0x53 => false,
            other => bail!("invalid ORAM directory tag {other:#x} for {}", spec.name),
        };
        let key = decode_scalar_value(key_type, &record[1..1 + key_len])?;
        let value = decode_scalar_value(
            &spec.value_type,
            &record[1 + key_len..1 + key_len + value_len],
        )?;
        entries.push(MapEntry {
            occupied,
            key,
            value,
        });
    }
    Ok(entries)
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

fn encode_scalar_value(ty: &Type, value: &Value) -> Result<Vec<u8>> {
    let bytes = value.canonical_bytes();
    let expected_len = fixed_scalar_width(ty)?;
    if bytes.len() != expected_len {
        bail!(
            "unexpected scalar width for ORAM value: {} != {}",
            bytes.len(),
            expected_len
        );
    }
    Ok(bytes)
}

fn decode_scalar_value(ty: &Type, bytes: &[u8]) -> Result<Value> {
    match ty {
        Type::Scalar(ScalarType::Bool) => {
            if bytes.len() != 1 {
                bail!("expected 1 byte for bool, got {}", bytes.len());
            }
            Ok(Value::Bool(bytes[0] != 0))
        }
        Type::Scalar(ScalarType::Uint(_)) => {
            if bytes.len() != 32 {
                bail!("expected 32 bytes for uint, got {}", bytes.len());
            }
            let mut out = [0u8; 16];
            out.copy_from_slice(&bytes[16..]);
            Ok(Value::Uint(u128::from_be_bytes(out)))
        }
        Type::Scalar(ScalarType::Bytes32) => {
            let array: [u8; 32] = bytes
                .try_into()
                .map_err(|_| anyhow!("expected 32 bytes for bytes32, got {}", bytes.len()))?;
            Ok(Value::Bytes32(array))
        }
        Type::Scalar(ScalarType::Address) => {
            let array: [u8; 20] = bytes
                .try_into()
                .map_err(|_| anyhow!("expected 20 bytes for address, got {}", bytes.len()))?;
            Ok(Value::Address(array))
        }
        _ => bail!("ORAM control metadata only supports scalar map key/value types"),
    }
}

fn log2_ceil(value: usize) -> usize {
    value.max(1).next_power_of_two().ilog2() as usize
}

#[cfg(test)]
mod tests {
    use super::{MapEntry, OramBucket, OramParameters, SURROGATE_ORAM_SCHEME};
    use uo_core::ir::{BackendKind, ContainerKind, StateObject};
    use uo_core::{ScalarType, Type, Value};

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
}
