use anyhow::{anyhow, bail, Result};
use rand_chacha::ChaCha20Rng;
use uo_core::ir::StateObject;
use uo_core::trace::{LogicalEvent, PhysicalReadEvent};
use uo_core::{ScalarType, Type, Value};
use uo_store::StoreCipher;

pub(crate) const ORAM_DIRECTORY_PAGE_ENTRIES: usize = 8;
const ORAM_BLOCKS_PER_BUCKET: usize = 2;
const ORAM_BUCKET_HEADER_BYTES: usize = 24;
const ORAM_SCHEME: &str = "surrogate_public_schedule_v1";

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
        let block_size = 1 + key_len + value_len;
        let bucket_size = ORAM_BUCKET_HEADER_BYTES + ORAM_BLOCKS_PER_BUCKET * block_size;
        let tree_height = log2_ceil(capacity.max(2));
        let metadata_pages = oram_directory_page_count(capacity);
        Ok(Self {
            scheme: ORAM_SCHEME.into(),
            capacity,
            block_size,
            bucket_size,
            bucket_count: capacity.max(1).next_power_of_two().max(8) / 2,
            blocks_per_bucket: ORAM_BLOCKS_PER_BUCKET,
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
}

#[derive(Clone, Debug)]
pub(crate) struct OramStorage {
    pub directory_pages: Vec<Vec<u8>>,
    pub buckets: Vec<Vec<u8>>,
    pub access_counter_slot: Vec<u8>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramAccessSchedule {
    pub metadata_pages: Vec<usize>,
    pub bucket_indices: Vec<usize>,
}

#[derive(Clone, Debug)]
pub(crate) struct OramTranscript {
    pub schedule: OramAccessSchedule,
    pub logical_accesses: Vec<LogicalEvent>,
    pub physical_reads: Vec<PhysicalReadEvent>,
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
    pub storage: OramStorage,
    pub access_counter: u64,
    pub cipher: StoreCipher,
}

impl OramState {
    pub(crate) fn instantiate(spec: &StateObject, rng: &mut ChaCha20Rng) -> Result<Self> {
        let parameters = OramParameters::for_spec(spec)?;
        let empty_entry = empty_map_entry(spec)?;
        let entries = vec![empty_entry.clone(); parameters.capacity];
        let cipher = StoreCipher::random();
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
            storage: OramStorage {
                directory_pages,
                buckets,
                access_counter_slot: cipher.seal(oram_counter_aad(spec).as_bytes(), &0u64.to_be_bytes(), rng),
            },
            access_counter: 0,
            cipher,
        })
    }

    pub(crate) fn refresh_from_storage(&mut self, spec: &StateObject) -> Result<()> {
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
        let counter_bytes = self
            .cipher
            .open(oram_counter_aad(spec).as_bytes(), 8, &self.storage.access_counter_slot)
            .ok_or_else(|| anyhow!("failed to decode ORAM counter for {}", spec.name))?;
        let mut counter = [0u8; 8];
        counter.copy_from_slice(&counter_bytes);
        self.entries = entries;
        self.access_counter = u64::from_be_bytes(counter);
        Ok(())
    }

    pub(crate) fn get(&self, spec: &StateObject, key: &Value) -> Result<(Value, OramTranscript)> {
        let transcript = self.access_transcript(spec);
        let value = self
            .entries
            .iter()
            .find(|entry| entry.occupied && entry.key == *key)
            .map(|entry| entry.value.clone())
            .unwrap_or_else(|| Value::zero_for_type(&spec.value_type));
        Ok((value, transcript))
    }

    pub(crate) fn put(
        &mut self,
        spec: &StateObject,
        key: Value,
        value: Value,
        apply: bool,
    ) -> Result<OramTranscript> {
        let transcript = self.access_transcript(spec);
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
    }

    pub(crate) fn commit(
        &self,
        spec: &StateObject,
        old: &Self,
        aborted: bool,
        rng: &mut ChaCha20Rng,
    ) -> Result<OramCommit> {
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
        for index in self.bucket_window() {
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
    }

    fn access_transcript(&self, spec: &StateObject) -> OramTranscript {
        let mut logical_accesses = Vec::new();
        let mut physical_reads = Vec::new();
        let schedule = OramAccessSchedule {
            metadata_pages: (0..self.storage.directory_pages.len()).collect(),
            bucket_indices: self.bucket_window(),
        };

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

        for page in &schedule.metadata_pages {
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

        for index in &schedule.bucket_indices {
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
            schedule,
            logical_accesses,
            physical_reads,
        }
    }

    fn bucket_window(&self) -> Vec<usize> {
        (0..self.parameters.buckets_per_access)
            .map(|offset| ((self.access_counter as usize) + offset) % self.storage.buckets.len())
            .collect()
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

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct OramBlock {
    pub occupied: bool,
    pub key: Value,
    pub value: Value,
}

impl OramBlock {
    fn empty(spec: &StateObject) -> Result<Self> {
        Ok(Self {
            occupied: false,
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
        let expected_len = 1 + key_len + value_len;
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
        Ok(Self {
            occupied,
            key: decode_scalar_value(key_type, &bytes[1..1 + key_len])?,
            value: decode_scalar_value(
                &spec.value_type,
                &bytes[1 + key_len..1 + key_len + value_len],
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
    use super::{MapEntry, OramBucket, OramParameters};
    use uo_core::ir::{BackendKind, ContainerKind, StateObject};
    use uo_core::{ScalarType, Type, Value};

    fn oram_spec() -> StateObject {
        StateObject {
            id: 7,
            name: "balances".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
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
                    key: Value::Address([0x11; 20]),
                    value: Value::Uint(5),
                },
                super::OramBlock {
                    occupied: true,
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
