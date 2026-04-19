use crate::controller::CallRecorder;
use crate::oram::{
    decode_map_record, map_record_bytes, MapEntry, OramState, PathOramLeafCoinSource,
};
use anyhow::{anyhow, bail, Result};
use rand::{RngCore, SeedableRng};
use rand_chacha::ChaCha20Rng;
use std::collections::{BTreeMap, BTreeSet};
use uo_allocator::{AllocatorSession, ScratchRegion};
use uo_core::ir::{BackendKind, ContainerKind, StateObject};
use uo_core::manifest::PATH_ORAM_SCHEME;
use uo_core::{RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness};
use uo_core::{Type, Value};
use uo_store::StoreCipher;

#[derive(Clone, Debug)]
pub(crate) struct CellObject {
    spec: StateObject,
    value: Value,
    physical: Vec<u8>,
    cipher: StoreCipher,
    accessed: bool,
    written: bool,
    rng: ChaCha20Rng,
}

impl CellObject {
    fn wipe_secrets(&mut self) {
        self.value.wipe_secrets();
        self.physical.fill(0);
        self.accessed = false;
        self.written = false;
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn decode_value_from_storage(&self, allocator: &mut AllocatorSession) -> Result<Value> {
        let aad = cell_slot_aad(&self.spec.name);
        decode_sealed_value(
            &self.cipher,
            &aad,
            &self.physical,
            &self.spec.value_type,
            &self.spec.name,
            allocator,
        )
    }

    fn clone_for_tx(&self, allocator: &mut AllocatorSession) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            value: self.decode_value_from_storage(allocator)?,
            physical: self.physical.clone(),
            cipher: self.cipher.clone(),
            accessed: false,
            written: false,
            rng: self.rng.clone(),
        })
    }

    fn cold_commit(&mut self) {
        self.value = Value::zero_for_type(&self.spec.value_type);
        self.accessed = false;
        self.written = false;
    }
}

impl Drop for CellObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug)]
pub(crate) struct ArrayObject {
    spec: StateObject,
    values: Vec<Value>,
    physical_slots: Vec<Vec<u8>>,
    cipher: StoreCipher,
    accessed: bool,
    written_indices: BTreeSet<usize>,
    rng: ChaCha20Rng,
}

impl ArrayObject {
    fn wipe_secrets(&mut self) {
        for value in &mut self.values {
            value.wipe_secrets();
        }
        for slot in &mut self.physical_slots {
            slot.fill(0);
        }
        self.accessed = false;
        self.written_indices.clear();
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn decode_values_from_storage(&self, allocator: &mut AllocatorSession) -> Result<Vec<Value>> {
        let mut values = Vec::with_capacity(self.physical_slots.len());
        self.decode_values_from_storage_into(allocator, &mut values)?;
        Ok(values)
    }

    fn decode_values_from_storage_into(
        &self,
        allocator: &mut AllocatorSession,
        values: &mut Vec<Value>,
    ) -> Result<()> {
        if values.capacity() < self.physical_slots.len() {
            bail!(
                "array decode buffer capacity {} fell below public slot count {} for {}",
                values.capacity(),
                self.physical_slots.len(),
                self.spec.name
            );
        }
        values.clear();
        for (index, physical) in self.physical_slots.iter().enumerate() {
            let aad = array_slot_aad(&self.spec.name, index);
            values.push(decode_sealed_value(
                &self.cipher,
                &aad,
                physical,
                &self.spec.value_type,
                &self.spec.name,
                allocator,
            )?);
        }
        Ok(())
    }

    fn clone_for_tx(&self, allocator: &mut AllocatorSession) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            values: self.decode_values_from_storage(allocator)?,
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone(),
            accessed: false,
            written_indices: BTreeSet::new(),
            rng: self.rng.clone(),
        })
    }

    fn cold_commit(&mut self) {
        self.values.clear();
        self.values.resize(
            self.physical_slots.len(),
            Value::zero_for_type(&self.spec.value_type),
        );
        self.accessed = false;
        self.written_indices.clear();
    }
}

impl Drop for ArrayObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug)]
struct RawMapEntry {
    value: Value,
    physical: Vec<u8>,
}

impl RawMapEntry {
    fn wipe_secrets(&mut self) {
        self.value.wipe_secrets();
        self.physical.fill(0);
    }
}

impl Drop for RawMapEntry {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug)]
pub(crate) struct RawMapObject {
    spec: StateObject,
    entries: BTreeMap<String, RawMapEntry>,
    staged: BTreeMap<String, (Value, Value)>,
}

#[derive(Clone, Debug)]
pub(crate) struct SmallMapObject {
    spec: StateObject,
    entries: Vec<MapEntry>,
    physical_slots: Vec<Vec<u8>>,
    cipher: StoreCipher,
    accessed: bool,
    dirty: bool,
    rng: ChaCha20Rng,
}

impl SmallMapObject {
    fn wipe_secrets(&mut self) {
        for entry in &mut self.entries {
            entry.wipe_secrets();
        }
        for slot in &mut self.physical_slots {
            slot.fill(0);
        }
        self.accessed = false;
        self.dirty = false;
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn decode_entries_from_storage(
        &self,
        allocator: &mut AllocatorSession,
    ) -> Result<Vec<MapEntry>> {
        let mut entries = Vec::with_capacity(self.physical_slots.len());
        self.decode_entries_from_storage_into(allocator, &mut entries)?;
        Ok(entries)
    }

    fn decode_entries_from_storage_into(
        &self,
        allocator: &mut AllocatorSession,
        entries: &mut Vec<MapEntry>,
    ) -> Result<()> {
        let record_len = map_record_len(&self.spec)?;
        if entries.capacity() < self.physical_slots.len() {
            bail!(
                "small-map decode buffer capacity {} fell below public slot count {} for {}",
                entries.capacity(),
                self.physical_slots.len(),
                self.spec.name
            );
        }
        entries.clear();
        for (index, physical) in self.physical_slots.iter().enumerate() {
            let aad = small_map_slot_aad(&self.spec.name, index);
            let _io_guard = allocator.reserve_guard(ScratchRegion::IoScratch, record_len)?;
            let entry = self
                .cipher
                .with_opened_payload(aad.as_bytes(), record_len, physical, |payload| {
                    decode_map_record(&self.spec, payload)
                })
                .ok_or_else(|| {
                    anyhow!(
                        "failed to decode sealed small-map slot {} for {}",
                        index,
                        self.spec.name
                    )
                })??;
            entries.push(entry);
        }
        Ok(())
    }

    fn clone_for_tx(&self, allocator: &mut AllocatorSession) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            entries: self.decode_entries_from_storage(allocator)?,
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone(),
            accessed: false,
            dirty: false,
            rng: self.rng.clone(),
        })
    }

    fn cold_commit(&mut self) {
        let zero_key = Value::zero_for_type(
            self.spec
                .key_type
                .as_ref()
                .expect("small-map objects must have key types"),
        );
        let zero_value = Value::zero_for_type(&self.spec.value_type);
        self.entries.clear();
        self.entries.resize(
            self.physical_slots.len(),
            MapEntry {
                occupied: false,
                key: zero_key.clone(),
                value: zero_value.clone(),
            },
        );
        self.accessed = false;
        self.dirty = false;
    }
}

impl Drop for SmallMapObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Clone, Debug)]
pub(crate) struct OramMapObject {
    spec: StateObject,
    oram: OramState,
    accessed: bool,
    dirty: bool,
    leaf_coin_source: PathOramLeafCoinSource,
    rng: ChaCha20Rng,
}

impl OramMapObject {
    fn wipe_secrets(&mut self) {
        self.accessed = false;
        self.dirty = false;
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn cold_commit(&mut self) {
        self.oram.cold_commit();
        self.accessed = false;
        self.dirty = false;
        self.leaf_coin_source = PathOramLeafCoinSource::random();
    }
}

impl Drop for OramMapObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Debug)]
pub(crate) enum RuntimeObject {
    RawCell(CellObject),
    UoCell(CellObject),
    RawArray(ArrayObject),
    UoArray(ArrayObject),
    RawMap(RawMapObject),
    UoSmallMap(SmallMapObject),
    UoOramMap(OramMapObject),
}

impl RuntimeObject {
    fn instantiate_from_rng(spec: &StateObject, master_rng: &mut ChaCha20Rng) -> Result<Self> {
        let mut rng = ChaCha20Rng::seed_from_u64(master_rng.next_u64());
        match (&spec.kind, &spec.backend) {
            (ContainerKind::Cell, BackendKind::Raw) => {
                let logical = Value::zero_for_type(&spec.value_type);
                Ok(Self::RawCell(CellObject {
                    spec: spec.clone(),
                    physical: raw_encode(&logical),
                    value: logical,
                    cipher: StoreCipher::from_rng(&mut rng),
                    accessed: false,
                    written: false,
                    rng,
                }))
            }
            (ContainerKind::Cell, _) => {
                let logical = Value::zero_for_type(&spec.value_type);
                let cipher = StoreCipher::from_rng(&mut rng);
                let aad = cell_slot_aad(&spec.name);
                Ok(Self::UoCell(CellObject {
                    spec: spec.clone(),
                    physical: seal_value(&cipher, aad.as_bytes(), &logical, &mut rng),
                    value: logical,
                    cipher,
                    accessed: false,
                    written: false,
                    rng,
                }))
            }
            (ContainerKind::Array, BackendKind::Raw) => {
                let capacity = spec
                    .capacity
                    .ok_or_else(|| anyhow!("array {} is missing capacity", spec.name))?;
                let values = vec![Value::zero_for_type(&spec.value_type); capacity];
                let physical_slots = values.iter().map(raw_encode).collect();
                Ok(Self::RawArray(ArrayObject {
                    spec: spec.clone(),
                    values,
                    physical_slots,
                    cipher: StoreCipher::from_rng(&mut rng),
                    accessed: false,
                    written_indices: BTreeSet::new(),
                    rng,
                }))
            }
            (ContainerKind::Array, _) => {
                let capacity = spec
                    .capacity
                    .ok_or_else(|| anyhow!("array {} is missing capacity", spec.name))?;
                let zero_value = Value::zero_for_type(&spec.value_type);
                let zero_payload = zero_value.canonical_bytes();
                let values = vec![zero_value; capacity];
                let cipher = StoreCipher::from_rng(&mut rng);
                let physical_slots = (0..capacity)
                    .map(|index| {
                        let aad = array_slot_aad(&spec.name, index);
                        let mut payload = zero_payload.clone();
                        cipher.seal_and_wipe(aad.as_bytes(), &mut payload, &mut rng)
                    })
                    .collect();
                Ok(Self::UoArray(ArrayObject {
                    spec: spec.clone(),
                    values,
                    physical_slots,
                    cipher,
                    accessed: false,
                    written_indices: BTreeSet::new(),
                    rng,
                }))
            }
            (ContainerKind::Map, BackendKind::Raw) => Ok(Self::RawMap(RawMapObject {
                spec: spec.clone(),
                entries: BTreeMap::new(),
                staged: BTreeMap::new(),
            })),
            (ContainerKind::Map, BackendKind::FullScan) => {
                let capacity = spec
                    .capacity
                    .ok_or_else(|| anyhow!("map {} is missing capacity", spec.name))?;
                let zero_key = Value::zero_for_type(
                    spec.key_type
                        .as_ref()
                        .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?,
                );
                let zero_value = Value::zero_for_type(&spec.value_type);
                let entries = (0..capacity)
                    .map(|_| MapEntry {
                        occupied: false,
                        key: zero_key.clone(),
                        value: zero_value.clone(),
                    })
                    .collect::<Vec<_>>();
                let zero_record = map_record_bytes(&MapEntry {
                    occupied: false,
                    key: zero_key,
                    value: zero_value,
                });
                let cipher = StoreCipher::from_rng(&mut rng);
                let physical_slots = (0..capacity)
                    .map(|index| {
                        let aad = small_map_slot_aad(&spec.name, index);
                        let mut payload = zero_record.clone();
                        cipher.seal_and_wipe(aad.as_bytes(), &mut payload, &mut rng)
                    })
                    .collect();
                Ok(Self::UoSmallMap(SmallMapObject {
                    spec: spec.clone(),
                    entries,
                    physical_slots,
                    cipher,
                    accessed: false,
                    dirty: false,
                    rng,
                }))
            }
            (ContainerKind::Map, BackendKind::Oram) => Ok(Self::UoOramMap(OramMapObject {
                spec: spec.clone(),
                oram: OramState::instantiate(spec, &mut rng)?,
                accessed: false,
                dirty: false,
                leaf_coin_source: PathOramLeafCoinSource::random(),
                rng,
            })),
        }
    }

    pub fn instantiate_with_seed(spec: &StateObject, seed: u64) -> Result<Self> {
        let mut master_rng = ChaCha20Rng::seed_from_u64(seed);
        Self::instantiate_from_rng(spec, &mut master_rng)
    }

    pub(in crate::runtime) fn clone_for_tx(
        &self,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        match self {
            Self::RawCell(object) => Ok(Self::RawCell(object.clone())),
            Self::RawArray(object) => Ok(Self::RawArray(object.clone())),
            Self::RawMap(object) => Ok(Self::RawMap(RawMapObject {
                spec: object.spec.clone(),
                entries: object.entries.clone(),
                staged: BTreeMap::new(),
            })),
            Self::UoCell(object) => Ok(Self::UoCell(object.clone_for_tx(allocator)?)),
            Self::UoArray(object) => Ok(Self::UoArray(object.clone_for_tx(allocator)?)),
            Self::UoSmallMap(object) => Ok(Self::UoSmallMap(object.clone_for_tx(allocator)?)),
            Self::UoOramMap(object) => Ok(Self::UoOramMap(OramMapObject {
                spec: object.spec.clone(),
                oram: object.oram.clone_for_tx(&object.spec, allocator)?,
                accessed: false,
                dirty: false,
                leaf_coin_source: PathOramLeafCoinSource::random(),
                rng: object.rng.clone(),
            })),
        }
    }

    pub(in crate::runtime) fn clone_committed_cold(&self) -> Self {
        debug_assert!(self.committed_cache_is_cold());
        match self {
            Self::RawCell(object) => Self::RawCell(object.clone()),
            Self::UoCell(object) => Self::UoCell(object.clone()),
            Self::RawArray(object) => Self::RawArray(object.clone()),
            Self::UoArray(object) => Self::UoArray(object.clone()),
            Self::RawMap(object) => Self::RawMap(RawMapObject {
                spec: object.spec.clone(),
                entries: object.entries.clone(),
                staged: BTreeMap::new(),
            }),
            Self::UoSmallMap(object) => Self::UoSmallMap(object.clone()),
            Self::UoOramMap(object) => Self::UoOramMap(object.clone()),
        }
    }

    pub(in crate::runtime) fn into_cold_committed(mut self) -> Self {
        match &mut self {
            Self::UoCell(object) => object.cold_commit(),
            Self::UoArray(object) => object.cold_commit(),
            Self::UoSmallMap(object) => object.cold_commit(),
            Self::UoOramMap(object) => object.cold_commit(),
            _ => self.clear_transient(),
        }
        self
    }

    pub(in crate::runtime) fn committed_cache_is_cold(&self) -> bool {
        match self {
            Self::UoCell(object) => {
                object.value == Value::zero_for_type(&object.spec.value_type)
                    && !object.accessed
                    && !object.written
            }
            Self::UoArray(object) => {
                object.values
                    == vec![
                        Value::zero_for_type(&object.spec.value_type);
                        object.physical_slots.len()
                    ]
                    && !object.accessed
                    && object.written_indices.is_empty()
            }
            Self::UoSmallMap(object) => {
                object.entries.iter().all(|entry| !entry.occupied)
                    && !object.accessed
                    && !object.dirty
            }
            Self::UoOramMap(object) => {
                object.oram.entries.is_empty()
                    && object.oram.position_map.is_empty()
                    && object.oram.stash.is_empty()
                    && !object.accessed
                    && !object.dirty
            }
            _ => true,
        }
    }

    #[cfg(test)]
    pub(crate) fn path_oram_access_counter_for_test(&self) -> Option<u64> {
        match self {
            Self::UoOramMap(object) => Some(object.oram.access_counter),
            _ => None,
        }
    }

    pub(in crate::runtime) fn path_oram_position_map_witness(
        &self,
    ) -> Result<Option<RuntimePathOramPositionMapWitness>> {
        match self {
            Self::UoOramMap(object) if object.spec.oram_scheme == PATH_ORAM_SCHEME => {
                let leaves = if object.oram.position_map.len() == object.oram.parameters.capacity {
                    object.oram.position_map.clone()
                } else {
                    object.oram.path_position_map_from_storage(&object.spec)?
                };
                Ok(Some(RuntimePathOramPositionMapWitness {
                    object_id: object.spec.id,
                    object_name: object.spec.name.clone(),
                    leaves,
                }))
            }
            _ => Ok(None),
        }
    }

    pub(in crate::runtime) fn path_oram_access_counter_witness(
        &self,
    ) -> Option<RuntimeOramAccessCounterWitness> {
        match self {
            Self::UoOramMap(object) if object.spec.oram_scheme == PATH_ORAM_SCHEME => {
                Some(RuntimeOramAccessCounterWitness {
                    object_id: object.spec.id,
                    object_name: object.spec.name.clone(),
                    access_counter: object.oram.access_counter,
                })
            }
            _ => None,
        }
    }

    pub fn name(&self) -> &str {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => &object.spec.name,
            Self::RawArray(object) | Self::UoArray(object) => &object.spec.name,
            Self::RawMap(object) => &object.spec.name,
            Self::UoSmallMap(object) => &object.spec.name,
            Self::UoOramMap(object) => &object.spec.name,
        }
    }

    pub(in crate::runtime) fn get_cell(&mut self, trace: &mut CallRecorder) -> Result<Value> {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                object.accessed = true;
                trace.logical_read("cell_get", &object.spec.name, "");
                trace.physical_read(
                    &object.spec.name,
                    object.spec.name.clone(),
                    object.physical.len(),
                );
                Ok(object.value.clone())
            }
            _ => bail!("{} is not a cell", self.name()),
        }
    }

    pub(in crate::runtime) fn set_cell(
        &mut self,
        value: Value,
        predicate: Option<bool>,
        trace: &mut CallRecorder,
    ) -> Result<()> {
        let apply = predicate.unwrap_or(true);
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                object.accessed = true;
                trace.logical_write("cell_set", &object.spec.name, "slot");
                trace.physical_read(
                    &object.spec.name,
                    object.spec.name.clone(),
                    object.physical.len(),
                );
                if apply {
                    object.value = value;
                    object.written = true;
                }
                Ok(())
            }
            _ => bail!("{} is not a cell", self.name()),
        }
    }

    pub(in crate::runtime) fn get_array(
        &mut self,
        index: usize,
        trace: &mut CallRecorder,
    ) -> Result<Value> {
        match self {
            Self::RawArray(object) => {
                object.accessed = true;
                let value = object.values.get(index).cloned().ok_or_else(|| {
                    anyhow!(
                        "array index {} out of bounds for {}",
                        index,
                        object.spec.name
                    )
                })?;
                trace.logical_read("array_get", &object.spec.name, format!("[{index}]"));
                trace.physical_read(
                    &object.spec.name,
                    format!("{}[{index}]", object.spec.name),
                    object.physical_slots[index].len(),
                );
                Ok(value)
            }
            Self::UoArray(object) => {
                object.accessed = true;
                let value = object.values.get(index).cloned().ok_or_else(|| {
                    anyhow!(
                        "array index {} out of bounds for {}",
                        index,
                        object.spec.name
                    )
                })?;
                trace.logical_read("array_get", &object.spec.name, format!("[{index}]"));
                record_array_scan(object, trace);
                Ok(value)
            }
            _ => bail!("{} is not an array", self.name()),
        }
    }

    pub(in crate::runtime) fn set_array(
        &mut self,
        index: usize,
        value: Value,
        predicate: Option<bool>,
        trace: &mut CallRecorder,
    ) -> Result<()> {
        let apply = predicate.unwrap_or(true);
        match self {
            Self::RawArray(object) => {
                object.accessed = true;
                object.values.get(index).ok_or_else(|| {
                    anyhow!(
                        "array index {} out of bounds for {}",
                        index,
                        object.spec.name
                    )
                })?;
                trace.logical_write("array_set", &object.spec.name, format!("[{index}]"));
                trace.physical_read(
                    &object.spec.name,
                    format!("{}[{index}]", object.spec.name),
                    object.physical_slots[index].len(),
                );
                if apply {
                    object.values[index] = value;
                    object.written_indices.insert(index);
                }
                Ok(())
            }
            Self::UoArray(object) => {
                object.accessed = true;
                object.values.get(index).ok_or_else(|| {
                    anyhow!(
                        "array index {} out of bounds for {}",
                        index,
                        object.spec.name
                    )
                })?;
                trace.logical_write("array_set", &object.spec.name, format!("[{index}]"));
                record_array_scan(object, trace);
                if apply {
                    object.values[index] = value;
                    object.written_indices.insert(index);
                }
                Ok(())
            }
            _ => bail!("{} is not an array", self.name()),
        }
    }

    pub(in crate::runtime) fn get_map(
        &mut self,
        key: &Value,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Value> {
        match self {
            Self::RawMap(object) => {
                let key_name = key.canonical_key();
                trace.logical_read("raw_map_get", &object.spec.name, key_name.clone());
                trace.physical_read(
                    &object.spec.name,
                    format!("{}::{key_name}", object.spec.name),
                    32,
                );
                if let Some((_, staged_value)) = object.staged.get(&key_name) {
                    return Ok(staged_value.clone());
                }
                Ok(object
                    .entries
                    .get(&key_name)
                    .map(|entry| entry.value.clone())
                    .unwrap_or_else(|| Value::zero_for_type(&object.spec.value_type)))
            }
            Self::UoSmallMap(object) => {
                object.accessed = true;
                for index in 0..object.entries.len() {
                    trace.logical_read("uomap_scan", &object.spec.name, format!("slot:{index}"));
                    trace.physical_read(
                        &object.spec.name,
                        format!("{}#{index}", object.spec.name),
                        object.physical_slots[index].len(),
                    );
                }
                Ok(object
                    .entries
                    .iter()
                    .find(|entry| entry.occupied && entry.key == *key)
                    .map(|entry| entry.value.clone())
                    .unwrap_or_else(|| Value::zero_for_type(&object.spec.value_type)))
            }
            Self::UoOramMap(object) => {
                object.accessed = true;
                trace.record_oram_access(object.spec.id, &object.oram.parameters);
                let (value, transcript) = object.oram.get(
                    &object.spec,
                    key,
                    allocator,
                    &mut object.leaf_coin_source,
                    &mut object.rng,
                )?;
                if let Some(leaf) = transcript.path_leaf {
                    trace.record_path_oram_leaf_access(
                        object.spec.id,
                        &object.spec.name,
                        object.oram.parameters.bucket_count,
                        leaf,
                    );
                }
                if let Some(transition) = transcript.path_transition {
                    trace.record_path_oram_leaf_state_transition(transition);
                }
                for event in transcript.logical_accesses {
                    trace.logical_read(&event.kind, &event.object, event.detail);
                }
                for event in transcript.physical_reads {
                    trace.physical_read(&event.object, event.location, event.len);
                }
                for write in transcript.physical_writes {
                    trace.physical_write(write.with_object(&object.spec.name));
                }
                trace.add_zero_writes(transcript.zero_writes);
                Ok(value)
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    pub(in crate::runtime) fn put_map(
        &mut self,
        key: Value,
        value: Value,
        predicate: Option<bool>,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        let apply = predicate.unwrap_or(true);
        match self {
            Self::RawMap(object) => {
                let key_name = key.canonical_key();
                trace.logical_write("raw_map_put", &object.spec.name, key_name.clone());
                if apply {
                    object.staged.insert(key_name, (key, value));
                }
                Ok(())
            }
            Self::UoSmallMap(object) => {
                object.accessed = true;
                for index in 0..object.entries.len() {
                    trace.logical_read("uomap_scan", &object.spec.name, format!("slot:{index}"));
                    trace.physical_read(
                        &object.spec.name,
                        format!("{}#{index}", object.spec.name),
                        object.physical_slots[index].len(),
                    );
                }
                trace.logical_write("uomap_put", &object.spec.name, "oblivious");
                if apply {
                    let value_is_zero = value.is_zero_like();
                    if let Some(entry) = object
                        .entries
                        .iter_mut()
                        .find(|entry| entry.occupied && entry.key == key)
                    {
                        if value_is_zero {
                            entry.occupied = false;
                            entry.value = Value::zero_for_type(&object.spec.value_type);
                        } else {
                            entry.value = value;
                        }
                    } else if !value_is_zero {
                        let entry = object
                            .entries
                            .iter_mut()
                            .find(|entry| !entry.occupied)
                            .ok_or_else(|| {
                                anyhow!("map {} exceeded public capacity", object.spec.name)
                            })?;
                        entry.occupied = true;
                        entry.key = key;
                        entry.value = value;
                    }
                    object.dirty = true;
                }
                Ok(())
            }
            Self::UoOramMap(object) => {
                object.accessed = true;
                trace.record_oram_access(object.spec.id, &object.oram.parameters);
                let transcript = object.oram.put(
                    &object.spec,
                    key,
                    value,
                    apply,
                    allocator,
                    &mut object.leaf_coin_source,
                    &mut object.rng,
                )?;
                if let Some(leaf) = transcript.path_leaf {
                    trace.record_path_oram_leaf_access(
                        object.spec.id,
                        &object.spec.name,
                        object.oram.parameters.bucket_count,
                        leaf,
                    );
                }
                if let Some(transition) = transcript.path_transition {
                    trace.record_path_oram_leaf_state_transition(transition);
                }
                for event in transcript.logical_accesses {
                    trace.logical_read(&event.kind, &event.object, event.detail);
                }
                for event in transcript.physical_reads {
                    trace.physical_read(&event.object, event.location, event.len);
                }
                for write in transcript.physical_writes {
                    trace.physical_write(write.with_object(&object.spec.name));
                }
                trace.add_zero_writes(transcript.zero_writes);
                trace.logical_write("uooram_put", &object.spec.name, "oblivious");
                if apply {
                    object.dirty = true;
                }
                Ok(())
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    pub(in crate::runtime) fn commit(
        self,
        old: &Self,
        aborted: bool,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        match (self, old) {
            (Self::RawCell(new), Self::RawCell(old)) => {
                let mut next = old.clone();
                if !aborted && new.written {
                    let new_physical = raw_encode(&new.value);
                    trace.physical_write_from_buffers(
                        &new.spec.name,
                        new.spec.name.clone(),
                        &old.physical,
                        &new_physical,
                    );
                    next.value = new.value.clone();
                    next.physical = new_physical;
                }
                next.accessed = false;
                next.written = false;
                Ok(Self::RawCell(next))
            }
            (Self::UoCell(new), Self::UoCell(old)) => {
                let mut next = new;
                let committed_value = if aborted {
                    old.decode_value_from_storage(allocator)?
                } else {
                    next.value.clone()
                };
                if next.accessed {
                    let aad = cell_slot_aad(&next.spec.name);
                    let _io_guard = allocator
                        .reserve_guard(ScratchRegion::IoScratch, committed_value.canonical_len())?;
                    let mut payload = committed_value.canonical_bytes();
                    if !next.cipher.seal_and_wipe_into(
                        aad.as_bytes(),
                        &mut payload,
                        &mut next.rng,
                        &mut next.physical,
                    ) {
                        bail!(
                            "sealed cell buffer for {} fell below required public ciphertext size",
                            next.spec.name
                        );
                    }
                    trace.physical_write_from_buffers(
                        &next.spec.name,
                        next.spec.name.clone(),
                        &old.physical,
                        &next.physical,
                    );
                    next.value = committed_value;
                } else {
                    next.value = old.decode_value_from_storage(allocator)?;
                }
                next.accessed = false;
                next.written = false;
                Ok(Self::UoCell(next))
            }
            (Self::RawArray(new), Self::RawArray(old)) => {
                let mut next = old.clone();
                if !aborted {
                    for index in &new.written_indices {
                        let new_physical = raw_encode(&new.values[*index]);
                        trace.physical_write_from_buffers(
                            &new.spec.name,
                            format!("{}[{index}]", new.spec.name),
                            &old.physical_slots[*index],
                            &new_physical,
                        );
                        next.values[*index] = new.values[*index].clone();
                        next.physical_slots[*index] = new_physical;
                    }
                }
                next.accessed = false;
                next.written_indices.clear();
                Ok(Self::RawArray(next))
            }
            (Self::UoArray(new), Self::UoArray(old)) => {
                let mut next = new;
                if aborted || !next.accessed {
                    old.decode_values_from_storage_into(allocator, &mut next.values)?;
                }
                if next.accessed {
                    for index in 0..next.values.len() {
                        let value = next.values[index].clone();
                        let aad = array_slot_aad(&next.spec.name, index);
                        let _io_guard = allocator
                            .reserve_guard(ScratchRegion::IoScratch, value.canonical_len())?;
                        let mut payload = value.canonical_bytes();
                        if !next.cipher.seal_and_wipe_into(
                            aad.as_bytes(),
                            &mut payload,
                            &mut next.rng,
                            &mut next.physical_slots[index],
                        ) {
                            bail!(
                                "sealed array slot buffer for {}[{}] fell below required public ciphertext size",
                                next.spec.name,
                                index
                            );
                        }
                        trace.physical_write_from_buffers(
                            &next.spec.name,
                            format!("{}[{index}]", next.spec.name),
                            &old.physical_slots[index],
                            &next.physical_slots[index],
                        );
                        next.values[index] = value.clone();
                    }
                }
                next.accessed = false;
                next.written_indices.clear();
                Ok(Self::UoArray(next))
            }
            (Self::RawMap(new), Self::RawMap(old)) => {
                let mut next = old.clone();
                if !aborted {
                    for (key_name, (_key, value)) in &new.staged {
                        let zero_physical = [0u8; 32];
                        let old_physical = old
                            .entries
                            .get(key_name)
                            .map(|entry| entry.physical.as_slice())
                            .unwrap_or(zero_physical.as_slice());
                        let new_physical = raw_encode(value);
                        trace.physical_write_from_buffers(
                            &new.spec.name,
                            format!("{}::{key_name}", new.spec.name),
                            old_physical,
                            &new_physical,
                        );
                        if value.is_zero_like() {
                            next.entries.remove(key_name);
                        } else {
                            next.entries.insert(
                                key_name.clone(),
                                RawMapEntry {
                                    value: value.clone(),
                                    physical: new_physical,
                                },
                            );
                        }
                    }
                }
                next.staged.clear();
                Ok(Self::RawMap(next))
            }
            (Self::UoSmallMap(new), Self::UoSmallMap(old)) => {
                let mut next = new;
                if aborted || !next.accessed {
                    old.decode_entries_from_storage_into(allocator, &mut next.entries)?;
                }
                if next.accessed {
                    for index in 0..next.entries.len() {
                        let entry = next.entries[index].clone();
                        let aad = small_map_slot_aad(&next.spec.name, index);
                        let _io_guard = allocator.reserve_guard(
                            ScratchRegion::IoScratch,
                            1 + entry.key.canonical_len() + entry.value.canonical_len(),
                        )?;
                        let mut payload = map_record_bytes(&entry);
                        if !next.cipher.seal_and_wipe_into(
                            aad.as_bytes(),
                            &mut payload,
                            &mut next.rng,
                            &mut next.physical_slots[index],
                        ) {
                            bail!(
                                "sealed small-map slot buffer for {}#{} fell below required public ciphertext size",
                                next.spec.name,
                                index
                            );
                        }
                        trace.physical_write_from_buffers(
                            &next.spec.name,
                            format!("{}#{index}", next.spec.name),
                            &old.physical_slots[index],
                            &next.physical_slots[index],
                        );
                        next.entries[index] = entry;
                    }
                }
                next.accessed = false;
                next.dirty = false;
                Ok(Self::UoSmallMap(next))
            }
            (Self::UoOramMap(new), Self::UoOramMap(old)) => {
                let mut next = new;
                if next.accessed {
                    if next.spec.oram_scheme == PATH_ORAM_SCHEME {
                        if aborted {
                            next.oram
                                .restore_from_old(&old.spec, &old.oram, allocator)?;
                        }
                    } else {
                        let shadow_oram =
                            std::mem::replace(&mut next.oram, OramState::placeholder());
                        let commit = shadow_oram.commit(
                            &next.spec,
                            &old.oram,
                            aborted,
                            allocator,
                            &mut next.rng,
                        )?;
                        for write in commit.writes {
                            trace.physical_write(write.with_object(&next.spec.name));
                        }
                        trace.add_zero_writes(commit.zero_writes);
                        next.oram = commit.next;
                    }
                }
                next.accessed = false;
                next.dirty = false;
                next.leaf_coin_source = PathOramLeafCoinSource::random();
                Ok(Self::UoOramMap(next))
            }
            _ => bail!("mismatched object kinds during commit"),
        }
    }

    fn clear_transient(&mut self) {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                object.accessed = false;
                object.written = false;
            }
            Self::RawArray(object) | Self::UoArray(object) => {
                object.accessed = false;
                object.written_indices.clear();
            }
            Self::RawMap(object) => {
                object.staged.clear();
            }
            Self::UoSmallMap(object) => {
                object.accessed = false;
                object.dirty = false;
            }
            Self::UoOramMap(object) => {
                object.accessed = false;
                object.dirty = false;
                object.leaf_coin_source = PathOramLeafCoinSource::random();
            }
        }
    }

    pub(in crate::runtime) fn enable_injected_path_oram_leaf_coins(&mut self) {
        if let Self::UoOramMap(object) = self {
            if object.spec.oram_scheme == PATH_ORAM_SCHEME {
                object.leaf_coin_source = PathOramLeafCoinSource::require_injected();
            }
        }
    }

    pub(in crate::runtime) fn install_path_oram_leaf_coins(
        &mut self,
        coins: Vec<usize>,
    ) -> Result<()> {
        match self {
            Self::UoOramMap(object) if object.spec.oram_scheme == PATH_ORAM_SCHEME => {
                object.leaf_coin_source.install(coins);
                Ok(())
            }
            _ if coins.is_empty() => Ok(()),
            _ => bail!("{} is not a path-ORAM map", self.name()),
        }
    }

    pub(in crate::runtime) fn ensure_path_oram_leaf_coins_consumed(&self) -> Result<()> {
        match self {
            Self::UoOramMap(object) if object.spec.oram_scheme == PATH_ORAM_SCHEME => {
                object.leaf_coin_source.ensure_exhausted(&object.spec.name)
            }
            _ => Ok(()),
        }
    }
}

fn raw_encode(value: &Value) -> Vec<u8> {
    if value.is_zero_like() {
        vec![0u8; 32]
    } else {
        let bytes = value.canonical_bytes();
        if bytes.iter().all(|byte| *byte == 0) {
            vec![1u8; 32]
        } else {
            bytes
        }
    }
}

fn seal_value(cipher: &StoreCipher, aad: &[u8], value: &Value, rng: &mut ChaCha20Rng) -> Vec<u8> {
    let mut payload = value.canonical_bytes();
    cipher.seal_and_wipe(aad, &mut payload, rng)
}

fn decode_sealed_value(
    cipher: &StoreCipher,
    aad: &str,
    physical: &[u8],
    ty: &Type,
    object_name: &str,
    allocator: &mut AllocatorSession,
) -> Result<Value> {
    let payload_len = ty.canonical_len();
    let _io_guard = allocator.reserve_guard(ScratchRegion::IoScratch, payload_len)?;
    cipher
        .with_opened_payload(aad.as_bytes(), payload_len, physical, |payload| {
            Value::decode_canonical(ty, payload)
        })
        .ok_or_else(|| anyhow!("failed to decode sealed value for {}", object_name))?
}

fn map_record_len(spec: &StateObject) -> Result<usize> {
    let key_type = spec
        .key_type
        .as_ref()
        .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
    Ok(1 + key_type.canonical_len() + spec.value_type.canonical_len())
}

fn record_array_scan(object: &ArrayObject, trace: &mut CallRecorder) {
    for index in 0..object.physical_slots.len() {
        trace.physical_read(
            &object.spec.name,
            format!("{}[{index}]", object.spec.name),
            object.physical_slots[index].len(),
        );
    }
}

fn cell_slot_aad(object: &str) -> String {
    format!("cell:{object}")
}

fn array_slot_aad(object: &str, index: usize) -> String {
    format!("array:{object}:{index}")
}

fn small_map_slot_aad(object: &str, index: usize) -> String {
    format!("small_map:{object}:{index}")
}

#[cfg(test)]
mod tests {
    use super::{MapEntry, RuntimeObject};
    use uo_allocator::{AllocatorPlan, AllocatorSession};
    use uo_core::ir::{BackendKind, ContainerKind, StateObject};
    use uo_core::manifest::PATH_ORAM_SCHEME;
    use uo_core::{ScalarType, StructField, Type, Value};

    fn tx_allocator() -> AllocatorSession {
        AllocatorSession::new(AllocatorPlan {
            arena_bytes: 0,
            max_stack_words: 0,
            scratch_bytes: 1024,
            max_kernel_ops: 0,
        })
    }

    fn nested_value_type() -> Type {
        Type::Struct(vec![
            StructField {
                name: "flag".into(),
                ty: Type::Scalar(ScalarType::Bool),
            },
            StructField {
                name: "items".into(),
                ty: Type::Array(Box::new(Type::Scalar(ScalarType::Uint(256))), 2),
            },
        ])
    }

    fn nested_nonzero_value() -> Value {
        Value::Struct(vec![
            ("flag".into(), Value::Bool(true)),
            (
                "items".into(),
                Value::Array(vec![Value::Uint(7), Value::Uint(9)]),
            ),
        ])
    }

    fn cell_spec() -> StateObject {
        StateObject {
            id: 1,
            name: "nested_cell".into(),
            kind: ContainerKind::Cell,
            backend: BackendKind::FullScan,
            oram_scheme: String::new(),
            value_type: nested_value_type(),
            key_type: None,
            capacity: None,
            confidential: true,
        }
    }

    fn array_spec() -> StateObject {
        StateObject {
            id: 2,
            name: "nested_array".into(),
            kind: ContainerKind::Array,
            backend: BackendKind::FullScan,
            oram_scheme: String::new(),
            value_type: Type::Struct(vec![
                StructField {
                    name: "owner".into(),
                    ty: Type::Scalar(ScalarType::Address),
                },
                StructField {
                    name: "count".into(),
                    ty: Type::Scalar(ScalarType::Uint(256)),
                },
            ]),
            key_type: None,
            capacity: Some(3),
            confidential: true,
        }
    }

    fn small_map_spec() -> StateObject {
        StateObject {
            id: 3,
            name: "nested_map".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::FullScan,
            oram_scheme: String::new(),
            value_type: nested_value_type(),
            key_type: Some(Type::Struct(vec![
                StructField {
                    name: "owner".into(),
                    ty: Type::Scalar(ScalarType::Address),
                },
                StructField {
                    name: "nonce".into(),
                    ty: Type::Scalar(ScalarType::Uint(256)),
                },
            ])),
            capacity: Some(2),
            confidential: true,
        }
    }

    fn path_oram_spec() -> StateObject {
        StateObject {
            id: 4,
            name: "path_oram_map".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
            oram_scheme: PATH_ORAM_SCHEME.into(),
            value_type: Type::Scalar(ScalarType::Uint(256)),
            key_type: Some(Type::Scalar(ScalarType::Address)),
            capacity: Some(9),
            confidential: true,
        }
    }

    #[test]
    fn uo_cell_clone_for_tx_rebuilds_from_sealed_storage() {
        let spec = cell_spec();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0xC311).unwrap();
        let zero = Value::zero_for_type(&spec.value_type);
        let original_physical = match &object {
            RuntimeObject::UoCell(cell) => cell.physical.clone(),
            _ => unreachable!(),
        };

        match &mut object {
            RuntimeObject::UoCell(cell) => {
                cell.value = nested_nonzero_value();
                cell.accessed = true;
                cell.written = true;
            }
            _ => unreachable!(),
        }

        let mut allocator = tx_allocator();
        let cloned = object.clone_for_tx(&mut allocator).unwrap();
        allocator.finish().unwrap();

        match cloned {
            RuntimeObject::UoCell(cell) => {
                assert_eq!(cell.value, zero);
                assert_eq!(cell.physical, original_physical);
                assert!(!cell.accessed);
                assert!(!cell.written);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_array_clone_for_tx_rebuilds_from_sealed_storage() {
        let spec = array_spec();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0xA22A).unwrap();
        let zero = Value::zero_for_type(&spec.value_type);
        let original_slots = match &object {
            RuntimeObject::UoArray(array) => array.physical_slots.clone(),
            _ => unreachable!(),
        };

        match &mut object {
            RuntimeObject::UoArray(array) => {
                array.values = vec![
                    Value::Struct(vec![
                        ("owner".into(), Value::Address([0x11; 20])),
                        ("count".into(), Value::Uint(3)),
                    ]),
                    Value::Struct(vec![
                        ("owner".into(), Value::Address([0x22; 20])),
                        ("count".into(), Value::Uint(5)),
                    ]),
                    Value::Struct(vec![
                        ("owner".into(), Value::Address([0x33; 20])),
                        ("count".into(), Value::Uint(7)),
                    ]),
                ];
                array.accessed = true;
                array.written_indices.extend([0, 1, 2]);
            }
            _ => unreachable!(),
        }

        let mut allocator = tx_allocator();
        let cloned = object.clone_for_tx(&mut allocator).unwrap();
        allocator.finish().unwrap();

        match cloned {
            RuntimeObject::UoArray(array) => {
                assert_eq!(array.values, vec![zero; 3]);
                assert_eq!(array.physical_slots, original_slots);
                assert!(!array.accessed);
                assert!(array.written_indices.is_empty());
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_small_map_clone_for_tx_rebuilds_from_sealed_storage() {
        let spec = small_map_spec();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0x5AA1).unwrap();
        let zero_key = Value::zero_for_type(spec.key_type.as_ref().unwrap());
        let zero_value = Value::zero_for_type(&spec.value_type);
        let original_slots = match &object {
            RuntimeObject::UoSmallMap(map) => map.physical_slots.clone(),
            _ => unreachable!(),
        };

        match &mut object {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = MapEntry {
                    occupied: true,
                    key: Value::Struct(vec![
                        ("owner".into(), Value::Address([0x44; 20])),
                        ("nonce".into(), Value::Uint(1)),
                    ]),
                    value: nested_nonzero_value(),
                };
                map.entries[1] = MapEntry {
                    occupied: true,
                    key: Value::Struct(vec![
                        ("owner".into(), Value::Address([0x55; 20])),
                        ("nonce".into(), Value::Uint(2)),
                    ]),
                    value: Value::Struct(vec![
                        ("flag".into(), Value::Bool(true)),
                        (
                            "items".into(),
                            Value::Array(vec![Value::Uint(11), Value::Uint(13)]),
                        ),
                    ]),
                };
                map.accessed = true;
                map.dirty = true;
            }
            _ => unreachable!(),
        }

        let mut allocator = tx_allocator();
        let cloned = object.clone_for_tx(&mut allocator).unwrap();
        allocator.finish().unwrap();

        match cloned {
            RuntimeObject::UoSmallMap(map) => {
                assert_eq!(
                    map.entries,
                    vec![
                        MapEntry {
                            occupied: false,
                            key: zero_key.clone(),
                            value: zero_value.clone(),
                        },
                        MapEntry {
                            occupied: false,
                            key: zero_key,
                            value: zero_value,
                        },
                    ]
                );
                assert_eq!(map.physical_slots, original_slots);
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_cell_commit_reads_old_state_from_storage_on_abort() {
        let spec = cell_spec();
        let zero = Value::zero_for_type(&spec.value_type);
        let mut old = RuntimeObject::instantiate_with_seed(&spec, 0xCE11).unwrap();
        match &mut old {
            RuntimeObject::UoCell(cell) => {
                cell.value = nested_nonzero_value();
            }
            _ => unreachable!(),
        }

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        match &mut new {
            RuntimeObject::UoCell(cell) => {
                cell.value = Value::Struct(vec![
                    ("flag".into(), Value::Bool(true)),
                    (
                        "items".into(),
                        Value::Array(vec![Value::Uint(21), Value::Uint(34)]),
                    ),
                ]);
                cell.accessed = true;
                cell.written = true;
            }
            _ => unreachable!(),
        }
        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, true, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoCell(cell) => {
                assert_eq!(cell.value, zero);
                assert!(!cell.accessed);
                assert!(!cell.written);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_cell_commit_reuses_ciphertext_buffer_when_unaccessed() {
        let spec = cell_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xC012).unwrap();

        let mut shadow_allocator = tx_allocator();
        let new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let physical_ptr = match &new {
            RuntimeObject::UoCell(cell) => cell.physical.as_ptr(),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoCell(cell) => {
                assert_eq!(cell.physical.as_ptr(), physical_ptr);
                assert!(!cell.accessed);
                assert!(!cell.written);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_cell_commit_reuses_ciphertext_buffer_when_written() {
        let spec = cell_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xC013).unwrap();

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let physical_ptr = match &new {
            RuntimeObject::UoCell(cell) => cell.physical.as_ptr(),
            _ => unreachable!(),
        };
        let committed_value = nested_nonzero_value();
        match &mut new {
            RuntimeObject::UoCell(cell) => {
                cell.value = committed_value.clone();
                cell.accessed = true;
                cell.written = true;
            }
            _ => unreachable!(),
        }

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoCell(cell) => {
                assert_eq!(cell.physical.as_ptr(), physical_ptr);
                assert_eq!(cell.value, committed_value);
                assert!(!cell.accessed);
                assert!(!cell.written);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_array_commit_reads_old_state_from_storage_when_unaccessed() {
        let spec = array_spec();
        let zero = Value::zero_for_type(&spec.value_type);
        let mut old = RuntimeObject::instantiate_with_seed(&spec, 0xA661).unwrap();
        match &mut old {
            RuntimeObject::UoArray(array) => {
                array.values = vec![
                    Value::Struct(vec![
                        ("owner".into(), Value::Address([0x91; 20])),
                        ("count".into(), Value::Uint(8)),
                    ]),
                    Value::Struct(vec![
                        ("owner".into(), Value::Address([0x92; 20])),
                        ("count".into(), Value::Uint(9)),
                    ]),
                    Value::Struct(vec![
                        ("owner".into(), Value::Address([0x93; 20])),
                        ("count".into(), Value::Uint(10)),
                    ]),
                ];
            }
            _ => unreachable!(),
        }

        let mut shadow_allocator = tx_allocator();
        let new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let (values_ptr, physical_slots_ptr) = match &new {
            RuntimeObject::UoArray(array) => (array.values.as_ptr(), array.physical_slots.as_ptr()),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoArray(array) => {
                assert_eq!(array.values, vec![zero; 3]);
                assert_eq!(array.values.as_ptr(), values_ptr);
                assert_eq!(array.physical_slots.as_ptr(), physical_slots_ptr);
                assert!(!array.accessed);
                assert!(array.written_indices.is_empty());
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_array_commit_reuses_written_slot_buffers() {
        let spec = array_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xA662).unwrap();

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let slot_ptr = match &new {
            RuntimeObject::UoArray(array) => array.physical_slots[1].as_ptr(),
            _ => unreachable!(),
        };
        let committed_value = Value::Struct(vec![
            ("owner".into(), Value::Address([0xA1; 20])),
            ("count".into(), Value::Uint(17)),
        ]);
        match &mut new {
            RuntimeObject::UoArray(array) => {
                array.values[1] = committed_value.clone();
                array.accessed = true;
                array.written_indices.insert(1);
            }
            _ => unreachable!(),
        }

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoArray(array) => {
                assert_eq!(array.physical_slots[1].as_ptr(), slot_ptr);
                assert_eq!(array.values[1], committed_value);
                assert!(!array.accessed);
                assert!(array.written_indices.is_empty());
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_small_map_commit_reads_old_state_from_storage_on_abort() {
        let spec = small_map_spec();
        let zero_key = Value::zero_for_type(spec.key_type.as_ref().unwrap());
        let zero_value = Value::zero_for_type(&spec.value_type);
        let mut old = RuntimeObject::instantiate_with_seed(&spec, 0x5C01).unwrap();
        match &mut old {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = MapEntry {
                    occupied: true,
                    key: Value::Struct(vec![
                        ("owner".into(), Value::Address([0x77; 20])),
                        ("nonce".into(), Value::Uint(4)),
                    ]),
                    value: nested_nonzero_value(),
                };
            }
            _ => unreachable!(),
        }

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        match &mut new {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = MapEntry {
                    occupied: true,
                    key: Value::Struct(vec![
                        ("owner".into(), Value::Address([0x88; 20])),
                        ("nonce".into(), Value::Uint(5)),
                    ]),
                    value: Value::Struct(vec![
                        ("flag".into(), Value::Bool(true)),
                        (
                            "items".into(),
                            Value::Array(vec![Value::Uint(15), Value::Uint(16)]),
                        ),
                    ]),
                };
                map.accessed = true;
                map.dirty = true;
            }
            _ => unreachable!(),
        }
        let (entries_ptr, physical_slots_ptr) = match &new {
            RuntimeObject::UoSmallMap(map) => (map.entries.as_ptr(), map.physical_slots.as_ptr()),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, true, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoSmallMap(map) => {
                assert_eq!(
                    map.entries,
                    vec![
                        MapEntry {
                            occupied: false,
                            key: zero_key.clone(),
                            value: zero_value.clone(),
                        },
                        MapEntry {
                            occupied: false,
                            key: zero_key,
                            value: zero_value,
                        },
                    ]
                );
                assert_eq!(map.entries.as_ptr(), entries_ptr);
                assert_eq!(map.physical_slots.as_ptr(), physical_slots_ptr);
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_small_map_commit_reuses_written_slot_buffers() {
        let spec = small_map_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0x5C02).unwrap();

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let slot_ptr = match &new {
            RuntimeObject::UoSmallMap(map) => map.physical_slots[0].as_ptr(),
            _ => unreachable!(),
        };
        let committed_entry = MapEntry {
            occupied: true,
            key: Value::Struct(vec![
                ("owner".into(), Value::Address([0x99; 20])),
                ("nonce".into(), Value::Uint(6)),
            ]),
            value: nested_nonzero_value(),
        };
        match &mut new {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = committed_entry.clone();
                map.accessed = true;
                map.dirty = true;
            }
            _ => unreachable!(),
        }

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoSmallMap(map) => {
                assert_eq!(map.physical_slots[0].as_ptr(), slot_ptr);
                assert_eq!(map.entries[0], committed_entry);
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_path_oram_commit_reads_old_state_from_storage_when_unaccessed() {
        let spec = path_oram_spec();
        let mut old = RuntimeObject::instantiate_with_seed(&spec, 0x0A12).unwrap();
        let mut old_allocator = tx_allocator();
        match &mut old {
            RuntimeObject::UoOramMap(map) => {
                map.oram
                    .refresh_from_storage(&spec, &mut old_allocator)
                    .unwrap();
            }
            _ => unreachable!(),
        }
        old_allocator.finish().unwrap();
        let (expected_entries, expected_position_map, expected_stash) = match &old {
            RuntimeObject::UoOramMap(map) => (
                map.oram.entries.clone(),
                map.oram.position_map.clone(),
                map.oram.stash.clone(),
            ),
            _ => unreachable!(),
        };

        match &mut old {
            RuntimeObject::UoOramMap(map) => {
                map.oram.entries[0] = MapEntry {
                    occupied: true,
                    key: Value::Address([0x66; 20]),
                    value: Value::Uint(19),
                };
                map.oram.position_map[0] = Some(0);
            }
            _ => unreachable!(),
        }

        let mut shadow_allocator = tx_allocator();
        let new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let (entries_ptr, position_map_ptr, stash_ptr) = match &new {
            RuntimeObject::UoOramMap(map) => (
                map.oram.entries.as_ptr(),
                map.oram.position_map.as_ptr(),
                map.oram.stash.as_ptr(),
            ),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoOramMap(map) => {
                assert_eq!(map.oram.entries, expected_entries);
                assert_eq!(map.oram.position_map, expected_position_map);
                assert_eq!(map.oram.stash, expected_stash);
                assert_eq!(map.oram.entries.as_ptr(), entries_ptr);
                assert_eq!(map.oram.position_map.as_ptr(), position_map_ptr);
                assert_eq!(map.oram.stash.as_ptr(), stash_ptr);
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_path_oram_commit_restores_old_state_in_place_on_abort() {
        let spec = path_oram_spec();
        let mut old = RuntimeObject::instantiate_with_seed(&spec, 0x0A13).unwrap();
        let mut old_allocator = tx_allocator();
        match &mut old {
            RuntimeObject::UoOramMap(map) => {
                map.oram
                    .refresh_from_storage(&spec, &mut old_allocator)
                    .unwrap();
            }
            _ => unreachable!(),
        }
        old_allocator.finish().unwrap();
        let (
            expected_entries,
            expected_position_map,
            expected_stash,
            expected_directory_pages,
            expected_buckets,
            expected_counter_slot,
        ) = match &old {
            RuntimeObject::UoOramMap(map) => (
                map.oram.entries.clone(),
                map.oram.position_map.clone(),
                map.oram.stash.clone(),
                map.oram.storage.directory_pages.clone(),
                map.oram.storage.buckets.clone(),
                map.oram.storage.access_counter_slot.clone(),
            ),
            _ => unreachable!(),
        };

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let (
            entries_ptr,
            position_map_ptr,
            stash_ptr,
            directory_pages_ptr,
            buckets_ptr,
            counter_ptr,
        ) = match &new {
            RuntimeObject::UoOramMap(map) => (
                map.oram.entries.as_ptr(),
                map.oram.position_map.as_ptr(),
                map.oram.stash.as_ptr(),
                map.oram.storage.directory_pages.as_ptr(),
                map.oram.storage.buckets.as_ptr(),
                map.oram.storage.access_counter_slot.as_ptr(),
            ),
            _ => unreachable!(),
        };

        match &mut new {
            RuntimeObject::UoOramMap(map) => {
                map.oram.entries[0] = MapEntry {
                    occupied: true,
                    key: Value::Address([0x77; 20]),
                    value: Value::Uint(23),
                };
                map.oram.position_map[0] = Some(0);
                if let Some(page) = map.oram.storage.directory_pages.first_mut() {
                    page[0] ^= 0x01;
                }
                if let Some(bucket) = map.oram.storage.buckets.first_mut() {
                    bucket[0] ^= 0x01;
                }
                map.oram.storage.access_counter_slot[0] ^= 0x01;
                map.accessed = true;
                map.dirty = true;
            }
            _ => unreachable!(),
        }

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, true, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        match committed {
            RuntimeObject::UoOramMap(map) => {
                assert_eq!(map.oram.entries, expected_entries);
                assert_eq!(map.oram.position_map, expected_position_map);
                assert_eq!(map.oram.stash, expected_stash);
                assert_eq!(map.oram.storage.directory_pages, expected_directory_pages);
                assert_eq!(map.oram.storage.buckets, expected_buckets);
                assert_eq!(map.oram.storage.access_counter_slot, expected_counter_slot);
                assert_eq!(map.oram.entries.as_ptr(), entries_ptr);
                assert_eq!(map.oram.position_map.as_ptr(), position_map_ptr);
                assert_eq!(map.oram.stash.as_ptr(), stash_ptr);
                assert_eq!(
                    map.oram.storage.directory_pages.as_ptr(),
                    directory_pages_ptr
                );
                assert_eq!(map.oram.storage.buckets.as_ptr(), buckets_ptr);
                assert_eq!(map.oram.storage.access_counter_slot.as_ptr(), counter_ptr);
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }
}
