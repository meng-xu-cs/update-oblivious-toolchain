use crate::controller::CallRecorder;
use crate::freshness::derive_path_oram_leaf_seed;
use crate::oram::{MapEntry, OramState, PathOramLeafCoinSource};
use anyhow::{anyhow, bail, Result};
use rand::{RngCore, SeedableRng};
use rand_chacha::ChaCha20Rng;
use serde_json::json;
use std::collections::BTreeMap;
use uo_allocator::AllocatorSession;
use uo_core::ir::{BackendKind, ContainerKind, StateObject};
use uo_core::manifest::is_path_oram_scheme;
use uo_core::Value;
use uo_core::{
    FixedBoxBuilder, RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness,
};
use uo_store::StoreCipher;

#[path = "generated_object_helpers.rs"]
mod generated_object_helpers;

use generated_object_helpers::{
    clone_runtime_value_for_read, cold_commit_boxed_values, cold_commit_small_map_entries,
    cold_commit_value_to_zero, cold_zero_boxed_values, cold_zero_small_map_entries,
    cold_zero_small_map_entry, cold_zero_value, decode_array_values_from_storage,
    decode_cell_value_from_storage, decode_small_map_entries_from_storage, raw_encode_value,
    reconcile_array_commit_values, reconcile_cell_commit_value, reconcile_raw_map_committed_entry,
    reconcile_small_map_commit_entries, seal_canonical_value_commit_slot, seal_map_record,
    seal_map_record_commit_slot, seal_value, select_array_value_at_index,
    select_small_map_value_for_key, update_array_value_at_index, update_masked_value,
    update_small_map_entries_for_put, wipe_boxed_values_and_slots,
    wipe_small_map_entries_and_slots, wipe_value_and_physical_slot,
};

#[derive(Debug)]
pub(crate) struct CellObject {
    spec: StateObject,
    value: Value,
    physical: Box<[u8]>,
    cipher: StoreCipher,
    accessed: bool,
    written: bool,
    rng: ChaCha20Rng,
}

impl CellObject {
    fn clone_committed_public(&self) -> Self {
        Self {
            spec: self.spec.clone(),
            value: self.value.clone(),
            physical: self.physical.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written: false,
            rng: self.rng.clone(),
        }
    }

    fn clone_committed_cold(&self) -> Self {
        Self {
            spec: self.spec.clone(),
            value: cold_zero_value(&self.spec.value_type),
            physical: self.physical.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written: false,
            rng: self.rng.clone(),
        }
    }

    fn wipe_secrets(&mut self) {
        wipe_value_and_physical_slot(&mut self.value, &mut self.physical);
        self.accessed = false;
        self.written = false;
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn decode_value_from_storage(&self, allocator: &mut AllocatorSession) -> Result<Value> {
        decode_cell_value_from_storage(
            &self.spec.name,
            &self.spec.value_type,
            &self.physical,
            &self.cipher,
            allocator,
        )
    }

    fn clone_for_tx(&self, allocator: &mut AllocatorSession) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            value: self.decode_value_from_storage(allocator)?,
            physical: self.physical.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written: false,
            rng: self.rng.clone(),
        })
    }

    fn cold_commit(&mut self) -> Result<()> {
        cold_commit_value_to_zero(&mut self.value, &self.spec.value_type);
        self.accessed = false;
        self.written = false;
        Ok(())
    }
}

impl Drop for CellObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Debug)]
pub(crate) struct ArrayObject {
    spec: StateObject,
    values: Box<[Value]>,
    physical_slots: Box<[Box<[u8]>]>,
    cipher: StoreCipher,
    accessed: bool,
    written_slots: Box<[bool]>,
    rng: ChaCha20Rng,
}

impl ArrayObject {
    fn clone_committed_public(&self) -> Self {
        Self {
            spec: self.spec.clone(),
            values: self.values.clone(),
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written_slots: boxed_false_flags(self.physical_slots.len()),
            rng: self.rng.clone(),
        }
    }

    fn clone_committed_cold(&self) -> Self {
        Self {
            spec: self.spec.clone(),
            values: cold_zero_boxed_values(self.values.len(), &self.spec.value_type),
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written_slots: boxed_false_flags(self.physical_slots.len()),
            rng: self.rng.clone(),
        }
    }

    fn wipe_secrets(&mut self) {
        wipe_boxed_values_and_slots(&mut self.values, &mut self.physical_slots);
        self.accessed = false;
        clear_written_slots(&mut self.written_slots);
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn decode_values_from_storage(&self, allocator: &mut AllocatorSession) -> Result<Box<[Value]>> {
        decode_array_values_from_storage(
            &self.spec.name,
            &self.spec.value_type,
            &self.physical_slots,
            &self.cipher,
            allocator,
        )
    }

    fn clone_for_tx(&self, allocator: &mut AllocatorSession) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            values: self.decode_values_from_storage(allocator)?,
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written_slots: boxed_false_flags(self.physical_slots.len()),
            rng: self.rng.clone(),
        })
    }

    fn cold_commit(&mut self) -> Result<()> {
        cold_commit_boxed_values(&mut self.values, &self.spec.value_type);
        self.accessed = false;
        clear_written_slots(&mut self.written_slots);
        Ok(())
    }
}

impl Drop for ArrayObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Debug)]
pub(crate) struct RawMapEntry {
    value: Value,
    physical: Box<[u8]>,
}

impl RawMapEntry {
    pub(crate) fn committed(value: Value, physical: Box<[u8]>) -> Self {
        Self { value, physical }
    }

    fn clone_committed_public(&self) -> Self {
        Self {
            value: self.value.clone(),
            physical: self.physical.clone(),
        }
    }

    fn wipe_secrets(&mut self) {
        wipe_value_and_physical_slot(&mut self.value, &mut self.physical);
    }
}

impl Drop for RawMapEntry {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Debug)]
pub(crate) struct RawMapObject {
    spec: StateObject,
    entries: BTreeMap<String, RawMapEntry>,
    staged: BTreeMap<String, (Value, Value)>,
}

impl RawMapObject {
    fn clone_committed_public(&self) -> Self {
        Self {
            spec: self.spec.clone(),
            entries: self
                .entries
                .iter()
                .map(|(key, entry)| (key.clone(), entry.clone_committed_public()))
                .collect(),
            staged: BTreeMap::new(),
        }
    }

    fn wipe_staged(&mut self) {
        for (_key_name, (key, value)) in self.staged.iter_mut() {
            key.wipe_secrets();
            value.wipe_secrets();
        }
        self.staged.clear();
    }

    fn wipe_secrets(&mut self) {
        for entry in self.entries.values_mut() {
            entry.wipe_secrets();
        }
        self.entries.clear();
        self.wipe_staged();
    }
}

impl Drop for RawMapObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Debug)]
pub(crate) struct SmallMapObject {
    spec: StateObject,
    entries: Box<[MapEntry]>,
    physical_slots: Box<[Box<[u8]>]>,
    cipher: StoreCipher,
    accessed: bool,
    dirty: bool,
    rng: ChaCha20Rng,
}

impl SmallMapObject {
    fn clone_committed_cold(&self) -> Result<Self> {
        let key_type = self
            .spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("small-map object {} missing key type", self.spec.name))?;
        Ok(Self {
            spec: self.spec.clone(),
            entries: cold_zero_small_map_entries(
                self.entries.len(),
                key_type,
                &self.spec.value_type,
            ),
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            dirty: false,
            rng: self.rng.clone(),
        })
    }

    fn wipe_secrets(&mut self) {
        wipe_small_map_entries_and_slots(&mut self.entries, &mut self.physical_slots);
        self.accessed = false;
        self.dirty = false;
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn decode_entries_from_storage(
        &self,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[MapEntry]>> {
        decode_small_map_entries_from_storage(
            &self.spec,
            &self.physical_slots,
            &self.cipher,
            allocator,
        )
    }

    fn clone_for_tx(&self, allocator: &mut AllocatorSession) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            entries: self.decode_entries_from_storage(allocator)?,
            physical_slots: self.physical_slots.clone(),
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            dirty: false,
            rng: self.rng.clone(),
        })
    }

    fn cold_commit(&mut self) -> Result<()> {
        let key_type = self
            .spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("small-map object {} missing key type", self.spec.name))?;
        cold_commit_small_map_entries(&mut self.entries, key_type, &self.spec.value_type);
        self.accessed = false;
        self.dirty = false;
        Ok(())
    }
}

impl Drop for SmallMapObject {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[derive(Debug)]
pub(crate) struct OramMapObject {
    spec: StateObject,
    oram: OramState,
    accessed: bool,
    dirty: bool,
    leaf_coin_seed: u64,
    leaf_coin_source: PathOramLeafCoinSource,
    rng: ChaCha20Rng,
}

impl OramMapObject {
    fn clone_committed_cold(&self) -> Result<Self> {
        Ok(Self {
            spec: self.spec.clone(),
            oram: self.oram.clone_committed_cold(&self.spec)?,
            accessed: false,
            dirty: false,
            leaf_coin_seed: self.leaf_coin_seed,
            leaf_coin_source: PathOramLeafCoinSource::from_domain_seed(self.leaf_coin_seed),
            rng: self.rng.clone(),
        })
    }

    fn wipe_secrets(&mut self) {
        self.accessed = false;
        self.dirty = false;
        self.rng = ChaCha20Rng::from_seed([0u8; 32]);
    }

    fn cold_commit(&mut self) -> Result<()> {
        self.oram.cold_commit();
        self.accessed = false;
        self.dirty = false;
        self.leaf_coin_source = PathOramLeafCoinSource::from_domain_seed(self.leaf_coin_seed);
        Ok(())
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
    pub(in crate::runtime) fn value_canonical_len(&self) -> usize {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => object.spec.value_type.canonical_len(),
            Self::RawArray(object) | Self::UoArray(object) => {
                object.spec.value_type.canonical_len()
            }
            Self::RawMap(object) => object.spec.value_type.canonical_len(),
            Self::UoSmallMap(object) => object.spec.value_type.canonical_len(),
            Self::UoOramMap(object) => object.spec.value_type.canonical_len(),
        }
    }

    pub(in crate::runtime) fn key_canonical_len(&self) -> Result<usize> {
        let key_type = match self {
            Self::RawMap(object) => object
                .spec
                .key_type
                .as_ref()
                .ok_or_else(|| anyhow!("map {} missing key type", object.spec.name))?,
            Self::UoSmallMap(object) => object
                .spec
                .key_type
                .as_ref()
                .ok_or_else(|| anyhow!("map {} missing key type", object.spec.name))?,
            Self::UoOramMap(object) => object
                .spec
                .key_type
                .as_ref()
                .ok_or_else(|| anyhow!("map {} missing key type", object.spec.name))?,
            _ => bail!("key_canonical_len is only defined for map objects"),
        };
        Ok(key_type.canonical_len())
    }

    fn instantiate_from_rng(spec: &StateObject, master_rng: &mut ChaCha20Rng) -> Result<Self> {
        if spec.confidential && matches!(spec.backend, BackendKind::Raw) {
            bail!("confidential object {} uses raw backend", spec.name);
        }
        let object_seed = master_rng.next_u64();
        let mut rng = ChaCha20Rng::seed_from_u64(object_seed);
        match (&spec.kind, &spec.backend) {
            (ContainerKind::Cell, BackendKind::Raw) => {
                let logical = cold_zero_value(&spec.value_type);
                Ok(Self::RawCell(CellObject {
                    spec: spec.clone(),
                    physical: raw_encode_value(&logical)?,
                    value: logical,
                    cipher: StoreCipher::from_rng(&mut rng),
                    accessed: false,
                    written: false,
                    rng,
                }))
            }
            (ContainerKind::Cell, _) => {
                let logical = cold_zero_value(&spec.value_type);
                let cipher = StoreCipher::from_rng(&mut rng);
                let aad = cell_slot_aad(&spec.name);
                Ok(Self::UoCell(CellObject {
                    spec: spec.clone(),
                    physical: seal_value(&aad, &logical, &cipher, &mut rng)?,
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
                let mut values = FixedBoxBuilder::new(capacity);
                let mut physical_slots = FixedBoxBuilder::new(capacity);
                for _ in 0..capacity {
                    let logical = cold_zero_value(&spec.value_type);
                    physical_slots.push(raw_encode_value(&logical)?)?;
                    values.push(logical)?;
                }
                Ok(Self::RawArray(ArrayObject {
                    spec: spec.clone(),
                    values: values.finish()?,
                    physical_slots: physical_slots.finish()?,
                    cipher: StoreCipher::from_rng(&mut rng),
                    accessed: false,
                    written_slots: boxed_false_flags(capacity),
                    rng,
                }))
            }
            (ContainerKind::Array, _) => {
                let capacity = spec
                    .capacity
                    .ok_or_else(|| anyhow!("array {} is missing capacity", spec.name))?;
                let zero_value = cold_zero_value(&spec.value_type);
                let cipher = StoreCipher::from_rng(&mut rng);
                let values = cold_zero_boxed_values(capacity, &spec.value_type);
                let mut physical_slots = FixedBoxBuilder::new(capacity);
                for index in 0..capacity {
                    let aad = array_slot_aad(&spec.name, index);
                    physical_slots.push(seal_value(&aad, &zero_value, &cipher, &mut rng)?)?;
                }
                Ok(Self::UoArray(ArrayObject {
                    spec: spec.clone(),
                    values,
                    physical_slots: physical_slots.finish()?,
                    cipher,
                    accessed: false,
                    written_slots: boxed_false_flags(capacity),
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
                let key_type = spec
                    .key_type
                    .as_ref()
                    .ok_or_else(|| anyhow!("map {} missing key type", spec.name))?;
                let entries = cold_zero_small_map_entries(capacity, key_type, &spec.value_type);
                let zero_entry = cold_zero_small_map_entry(key_type, &spec.value_type);
                let cipher = StoreCipher::from_rng(&mut rng);
                let mut physical_slots = FixedBoxBuilder::new(capacity);
                for index in 0..capacity {
                    let aad = small_map_slot_aad(&spec.name, index);
                    physical_slots.push(seal_map_record(&aad, &zero_entry, &cipher, &mut rng)?)?;
                }
                Ok(Self::UoSmallMap(SmallMapObject {
                    spec: spec.clone(),
                    entries,
                    physical_slots: physical_slots.finish()?,
                    cipher,
                    accessed: false,
                    dirty: false,
                    rng,
                }))
            }
            (ContainerKind::Map, BackendKind::Oram) => {
                let leaf_coin_seed = derive_path_oram_leaf_seed(object_seed, spec.id, &spec.name);
                Ok(Self::UoOramMap(OramMapObject {
                    spec: spec.clone(),
                    oram: OramState::instantiate(spec, &mut rng)?,
                    accessed: false,
                    dirty: false,
                    leaf_coin_seed,
                    leaf_coin_source: PathOramLeafCoinSource::from_domain_seed(leaf_coin_seed),
                    rng,
                }))
            }
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
            Self::RawCell(object) => Ok(Self::RawCell(object.clone_committed_public())),
            Self::RawArray(object) => Ok(Self::RawArray(object.clone_committed_public())),
            Self::RawMap(object) => Ok(Self::RawMap(object.clone_committed_public())),
            Self::UoCell(object) => Ok(Self::UoCell(object.clone_for_tx(allocator)?)),
            Self::UoArray(object) => Ok(Self::UoArray(object.clone_for_tx(allocator)?)),
            Self::UoSmallMap(object) => Ok(Self::UoSmallMap(object.clone_for_tx(allocator)?)),
            Self::UoOramMap(object) => Ok(Self::UoOramMap(OramMapObject {
                spec: object.spec.clone(),
                oram: object.oram.clone_for_tx(&object.spec, allocator)?,
                accessed: false,
                dirty: false,
                leaf_coin_seed: object.leaf_coin_seed,
                leaf_coin_source: PathOramLeafCoinSource::from_domain_seed(object.leaf_coin_seed),
                rng: object.rng.clone(),
            })),
        }
    }

    pub(in crate::runtime) fn clone_committed_cold(&self) -> Result<Self> {
        Ok(match self {
            Self::RawCell(object) => Self::RawCell(object.clone_committed_public()),
            Self::UoCell(object) => Self::UoCell(object.clone_committed_cold()),
            Self::RawArray(object) => Self::RawArray(object.clone_committed_public()),
            Self::UoArray(object) => Self::UoArray(object.clone_committed_cold()),
            Self::RawMap(object) => Self::RawMap(object.clone_committed_public()),
            Self::UoSmallMap(object) => Self::UoSmallMap(object.clone_committed_cold()?),
            Self::UoOramMap(object) => Self::UoOramMap(object.clone_committed_cold()?),
        })
    }

    pub(in crate::runtime) fn into_cold_committed(mut self) -> Result<Self> {
        match &mut self {
            Self::UoCell(object) => object.cold_commit()?,
            Self::UoArray(object) => object.cold_commit()?,
            Self::UoSmallMap(object) => object.cold_commit()?,
            Self::UoOramMap(object) => object.cold_commit()?,
            _ => self.clear_transient(),
        }
        Ok(self)
    }

    pub(in crate::runtime) fn committed_cache_is_cold(&self) -> bool {
        // This boundary check is public-only. Secret zeroization is enforced by
        // cold_commit/drop paths instead of rescanning cached confidential data.
        match self {
            Self::UoCell(object) => !object.accessed && !object.written,
            Self::UoArray(object) => !object.accessed && no_written_slots(&object.written_slots),
            Self::UoSmallMap(object) => !object.accessed && !object.dirty,
            Self::UoOramMap(object) => !object.accessed && !object.dirty,
            _ => true,
        }
    }

    #[cfg(test)]
    pub(crate) fn force_committed_cache_hot_for_test(&mut self) -> Result<()> {
        match self {
            Self::UoCell(object) => {
                object.accessed = true;
                Ok(())
            }
            Self::UoArray(object) => {
                object.accessed = true;
                Ok(())
            }
            Self::UoSmallMap(object) => {
                object.accessed = true;
                Ok(())
            }
            Self::UoOramMap(object) => {
                object.accessed = true;
                Ok(())
            }
            _ => bail!("{} is not a confidential UO object", self.name()),
        }
    }

    #[cfg(test)]
    pub(crate) fn path_oram_access_counter_for_test(&self) -> Option<u64> {
        match self {
            Self::UoOramMap(object) => Some(object.oram.access_counter_for_test()),
            _ => None,
        }
    }

    pub(in crate::runtime) fn path_oram_position_map_witness(
        &self,
    ) -> Result<Option<RuntimePathOramPositionMapWitness>> {
        match self {
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme) => {
                Ok(Some(object.oram.path_position_map_witness(&object.spec)?))
            }
            _ => Ok(None),
        }
    }

    pub(in crate::runtime) fn exposes_path_oram_witnesses(&self) -> bool {
        matches!(
            self,
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme)
        )
    }

    pub(in crate::runtime) fn is_update_oblivious_backend(&self) -> bool {
        matches!(
            self,
            Self::UoCell(_) | Self::UoArray(_) | Self::UoSmallMap(_) | Self::UoOramMap(_)
        )
    }

    pub(in crate::runtime) fn path_oram_access_counter_witness(
        &self,
    ) -> Option<RuntimeOramAccessCounterWitness> {
        match self {
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme) => {
                Some(object.oram.access_counter_witness(&object.spec))
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

    pub(in crate::runtime) fn public_state_snapshot_value(
        &self,
        allocator: &mut AllocatorSession,
    ) -> Result<Option<serde_json::Value>> {
        let is_confidential = match self {
            Self::RawCell(object) | Self::UoCell(object) => object.spec.confidential,
            Self::RawArray(object) | Self::UoArray(object) => object.spec.confidential,
            Self::RawMap(object) => object.spec.confidential,
            Self::UoSmallMap(object) => object.spec.confidential,
            Self::UoOramMap(object) => object.spec.confidential,
        };
        if is_confidential {
            return Ok(None);
        }
        Ok(Some(match self {
            Self::RawCell(object) => {
                json!({"kind": "cell", "name": &object.spec.name, "value": &object.value})
            }
            Self::UoCell(object) => {
                let value = object.decode_value_from_storage(allocator)?;
                json!({"kind": "cell", "name": &object.spec.name, "value": value})
            }
            Self::RawArray(object) => {
                json!({"kind": "array", "name": &object.spec.name, "values": &object.values})
            }
            Self::UoArray(object) => {
                let values = object.decode_values_from_storage(allocator)?;
                json!({"kind": "array", "name": &object.spec.name, "values": values})
            }
            Self::RawMap(object) => {
                let entries = object
                    .entries
                    .iter()
                    .map(|(key, entry)| json!({"key": key, "value": &entry.value}))
                    .collect::<Vec<_>>();
                json!({"kind": "map", "name": &object.spec.name, "entries": entries})
            }
            Self::UoSmallMap(object) => {
                let entries = object
                    .decode_entries_from_storage(allocator)?
                    .iter()
                    .map(|entry| {
                        json!({
                            "occupied": entry.is_occupied(),
                            "key": entry.key(),
                            "value": entry.value(),
                        })
                    })
                    .collect::<Vec<_>>();
                json!({"kind": "map", "name": &object.spec.name, "entries": entries})
            }
            Self::UoOramMap(object) => {
                let state = object.oram.public_state_snapshot_value();
                json!({"kind": "oram_map", "name": &object.spec.name, "state": state})
            }
        }))
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
                Ok(clone_runtime_value_for_read(&object.value))
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
            Self::RawCell(object) => {
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
            Self::UoCell(object) => {
                object.accessed = true;
                trace.logical_write("cell_set", &object.spec.name, "slot");
                trace.physical_read(
                    &object.spec.name,
                    object.spec.name.clone(),
                    object.physical.len(),
                );
                update_masked_value(&mut object.value, value, apply)?;
                object.written = true;
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
                let physical = object.physical_slots.get(index).ok_or_else(|| {
                    anyhow!(
                        "raw array physical slot {} missing for {} despite value slot guard",
                        index,
                        object.spec.name
                    )
                })?;
                trace.physical_read(
                    &object.spec.name,
                    format!("{}[{index}]", object.spec.name),
                    physical.len(),
                );
                Ok(value)
            }
            Self::UoArray(object) => {
                object.accessed = true;
                trace.logical_read("array_get", &object.spec.name, "oblivious");
                record_array_scan(object, trace);
                select_array_value_at_index(&object.values, index, &object.spec.value_type)
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
                let physical = object.physical_slots.get(index).ok_or_else(|| {
                    anyhow!(
                        "raw array physical slot {} missing for {} despite value slot guard",
                        index,
                        object.spec.name
                    )
                })?;
                trace.physical_read(
                    &object.spec.name,
                    format!("{}[{index}]", object.spec.name),
                    physical.len(),
                );
                if apply {
                    let value_slot = object.values.get_mut(index).ok_or_else(|| {
                        anyhow!(
                            "raw array value slot {} missing for {} despite value slot guard",
                            index,
                            object.spec.name
                        )
                    })?;
                    let written_slot = object.written_slots.get_mut(index).ok_or_else(|| {
                        anyhow!(
                            "raw array written flag {} missing for {} despite value slot guard",
                            index,
                            object.spec.name
                        )
                    })?;
                    *value_slot = value;
                    *written_slot = true;
                }
                Ok(())
            }
            Self::UoArray(object) => {
                object.accessed = true;
                trace.logical_write("array_set", &object.spec.name, "oblivious");
                record_array_scan(object, trace);
                update_array_value_at_index(&mut object.values, index, value, apply)?;
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
    ) -> Result<(Value, bool)> {
        match self {
            Self::RawMap(object) => {
                let key_name = key.canonical_key()?;
                trace.logical_read("raw_map_get", &object.spec.name, key_name.clone());
                trace.physical_read(
                    &object.spec.name,
                    format!("{}::{key_name}", object.spec.name),
                    32,
                );
                if let Some((_, staged_value)) = object.staged.get(&key_name) {
                    return Ok((staged_value.clone(), false));
                }
                let value = object
                    .entries
                    .get(&key_name)
                    .map(|entry| entry.value.clone())
                    .unwrap_or_else(|| cold_zero_value(&object.spec.value_type));
                Ok((value, false))
            }
            Self::UoSmallMap(object) => {
                object.accessed = true;
                record_small_map_scan(object, trace)?;
                let value =
                    select_small_map_value_for_key(&object.entries, key, &object.spec.value_type)?;
                Ok((value, false))
            }
            Self::UoOramMap(object) => {
                object.accessed = true;
                trace.record_oram_access(object.spec.id, object.oram.parameters());
                let (value, transcript, update_failed) = object.oram.get(
                    &object.spec,
                    key,
                    allocator,
                    &mut object.leaf_coin_source,
                    &mut object.rng,
                )?;
                let (
                    logical_accesses,
                    physical_reads,
                    physical_writes,
                    zero_writes,
                    path_leaf,
                    path_transition,
                ) = transcript.into_runtime_trace_parts();
                if let Some(leaf) = path_leaf {
                    trace.record_path_oram_leaf_access(
                        object.spec.id,
                        &object.spec.name,
                        object.oram.path_bucket_count(),
                        leaf,
                    );
                }
                if let Some(transition) = path_transition {
                    trace.record_path_oram_leaf_state_transition(transition);
                }
                for event in logical_accesses {
                    trace.logical_read(&event.kind, &event.object, event.detail);
                }
                for event in physical_reads {
                    trace.physical_read(&event.object, event.location, event.len);
                }
                physical_writes.for_each_write(|write| {
                    trace.physical_write(write.with_object(&object.spec.name));
                    Ok(())
                })?;
                trace.add_zero_writes(zero_writes);
                Ok((value, update_failed))
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
    ) -> Result<bool> {
        let apply = predicate.unwrap_or(true);
        match self {
            Self::RawMap(object) => {
                let key_name = key.canonical_key()?;
                trace.logical_write("raw_map_put", &object.spec.name, key_name.clone());
                if apply {
                    object.staged.insert(key_name, (key, value));
                }
                Ok(false)
            }
            Self::UoSmallMap(object) => {
                object.accessed = true;
                record_small_map_scan(object, trace)?;
                trace.logical_write("uomap_put", &object.spec.name, "oblivious");
                let value_type = object.spec.value_type.clone();
                let object_name = object.spec.name.clone();
                let capacity_overflowed = update_small_map_entries_for_put(
                    &mut object.entries,
                    key,
                    value,
                    apply,
                    &value_type,
                    &object_name,
                )?;
                object.dirty = true;
                Ok(capacity_overflowed)
            }
            Self::UoOramMap(object) => {
                object.accessed = true;
                trace.record_oram_access(object.spec.id, object.oram.parameters());
                let (transcript, update_failed) = object.oram.put(
                    &object.spec,
                    key,
                    value,
                    apply,
                    allocator,
                    &mut object.leaf_coin_source,
                    &mut object.rng,
                )?;
                let (
                    logical_accesses,
                    physical_reads,
                    physical_writes,
                    zero_writes,
                    path_leaf,
                    path_transition,
                ) = transcript.into_runtime_trace_parts();
                if let Some(leaf) = path_leaf {
                    trace.record_path_oram_leaf_access(
                        object.spec.id,
                        &object.spec.name,
                        object.oram.path_bucket_count(),
                        leaf,
                    );
                }
                if let Some(transition) = path_transition {
                    trace.record_path_oram_leaf_state_transition(transition);
                }
                for event in logical_accesses {
                    trace.logical_read(&event.kind, &event.object, event.detail);
                }
                for event in physical_reads {
                    trace.physical_read(&event.object, event.location, event.len);
                }
                physical_writes.for_each_write(|write| {
                    trace.physical_write(write.with_object(&object.spec.name));
                    Ok(())
                })?;
                trace.add_zero_writes(zero_writes);
                trace.logical_write("uooram_put", &object.spec.name, "oblivious");
                object.dirty = true;
                Ok(update_failed)
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
                let mut next = old.clone_committed_public();
                if !aborted && new.written {
                    let new_physical = raw_encode_value(&new.value)?;
                    trace.raw_physical_write_from_buffers(
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
                let restored_value = if aborted || !next.accessed {
                    Some(old.decode_value_from_storage(allocator)?)
                } else {
                    None
                };
                let spec_name = next.spec.name.clone();
                let cipher = &next.cipher;
                let rng = &mut next.rng;
                let physical = &mut next.physical;
                reconcile_cell_commit_value(
                    &mut next.value,
                    restored_value,
                    aborted,
                    next.accessed,
                    |committed_value| {
                        seal_canonical_value_commit_slot(
                            &spec_name,
                            spec_name.clone(),
                            cell_slot_aad(&spec_name),
                            committed_value,
                            physical,
                            cipher,
                            rng,
                            trace,
                            allocator,
                        )
                    },
                )?;
                next.accessed = false;
                next.written = false;
                Ok(Self::UoCell(next))
            }
            (Self::RawArray(new), Self::RawArray(old)) => {
                let mut next = old.clone_committed_public();
                if !aborted {
                    for (index, written) in new.written_slots.iter().enumerate() {
                        if !*written {
                            continue;
                        }
                        let new_value = new.values.get(index).ok_or_else(|| {
                            anyhow!(
                                "raw array new value slot {} missing for {} despite written flag",
                                index,
                                new.spec.name
                            )
                        })?;
                        let old_physical = old.physical_slots.get(index).ok_or_else(|| {
                            anyhow!(
                        "raw array old physical slot {} missing for {} despite written flag",
                        index,
                        new.spec.name
                    )
                        })?;
                        let new_physical = raw_encode_value(new_value)?;
                        trace.raw_physical_write_from_buffers(
                            &new.spec.name,
                            format!("{}[{index}]", new.spec.name),
                            old_physical,
                            &new_physical,
                        );
                        let next_value = next.values.get_mut(index).ok_or_else(|| {
                            anyhow!(
                                "raw array next value slot {} missing for {} despite written flag",
                                index,
                                new.spec.name
                            )
                        })?;
                        let next_physical =
                            next.physical_slots.get_mut(index).ok_or_else(|| {
                                anyhow!(
                        "raw array next physical slot {} missing for {} despite written flag",
                        index,
                        new.spec.name
                    )
                            })?;
                        *next_value = new_value.clone();
                        *next_physical = new_physical;
                    }
                }
                next.accessed = false;
                clear_written_slots(&mut next.written_slots);
                Ok(Self::RawArray(next))
            }
            (Self::UoArray(new), Self::UoArray(old)) => {
                let mut next = new;
                let restored_values = if aborted || !next.accessed {
                    Some(old.decode_values_from_storage(allocator)?)
                } else {
                    None
                };
                let spec_name = next.spec.name.clone();
                let cipher = &next.cipher;
                let rng = &mut next.rng;
                let physical_slots = &mut next.physical_slots;
                reconcile_array_commit_values(
                    &mut next.values,
                    restored_values.as_deref(),
                    aborted,
                    next.accessed,
                    |index, value| {
                        let physical = physical_slots.get_mut(index).ok_or_else(|| {
                            anyhow!(
                                "UO array commit physical slot {} missing for {} despite generated public commit schedule",
                                index,
                                spec_name
                            )
                        })?;
                        let slot_label = format!("{}[{index}]", spec_name);
                        seal_canonical_value_commit_slot(
                            &spec_name,
                            slot_label,
                            array_slot_aad(&spec_name, index),
                            value,
                            physical,
                            cipher,
                            rng,
                            trace,
                            allocator,
                        )
                    },
                )?;
                next.accessed = false;
                clear_written_slots(&mut next.written_slots);
                Ok(Self::UoArray(next))
            }
            (Self::RawMap(new), Self::RawMap(old)) => {
                let mut next = old.clone_committed_public();
                if !aborted {
                    for (key_name, (_key, value)) in &new.staged {
                        let zero_physical = [0u8; 32];
                        let old_physical = old
                            .entries
                            .get(key_name)
                            .map(|entry| entry.physical.as_ref())
                            .unwrap_or(zero_physical.as_slice());
                        let new_physical = raw_encode_value(value)?;
                        trace.raw_physical_write_from_buffers(
                            &new.spec.name,
                            format!("{}::{key_name}", new.spec.name),
                            old_physical,
                            &new_physical,
                        );
                        reconcile_raw_map_committed_entry(
                            &mut next.entries,
                            key_name,
                            value,
                            new_physical,
                        );
                    }
                }
                next.staged.clear();
                Ok(Self::RawMap(next))
            }
            (Self::UoSmallMap(new), Self::UoSmallMap(old)) => {
                let mut next = new;
                let restored_entries = if aborted || !next.accessed {
                    Some(old.decode_entries_from_storage(allocator)?)
                } else {
                    None
                };
                let spec_name = next.spec.name.clone();
                let cipher = &next.cipher;
                let rng = &mut next.rng;
                let physical_slots = &mut next.physical_slots;
                reconcile_small_map_commit_entries(
                    &mut next.entries,
                    restored_entries.as_deref(),
                    aborted,
                    next.accessed,
                    |index, entry| {
                        let physical = physical_slots.get_mut(index).ok_or_else(|| {
                            anyhow!(
                                "UO small-map commit physical slot {} missing for {} despite generated public commit schedule",
                                index,
                                spec_name
                            )
                        })?;
                        let slot_label = format!("{}#{index}", spec_name);
                        seal_map_record_commit_slot(
                            &spec_name,
                            slot_label,
                            small_map_slot_aad(&spec_name, index),
                            entry,
                            physical,
                            cipher,
                            rng,
                            trace,
                            allocator,
                        )
                    },
                )?;
                next.accessed = false;
                next.dirty = false;
                Ok(Self::UoSmallMap(next))
            }
            (Self::UoOramMap(new), Self::UoOramMap(old)) => {
                let mut next = new;
                if next.accessed {
                    if is_path_oram_scheme(&next.spec.oram_scheme) {
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
                        let (next_oram, writes, zero_writes) = commit.into_object_commit_parts();
                        writes.for_each_write(|write| {
                            trace.physical_write(write.with_object(&next.spec.name));
                            Ok(())
                        })?;
                        trace.add_zero_writes(zero_writes);
                        next.oram = next_oram;
                    }
                }
                next.accessed = false;
                next.dirty = false;
                next.leaf_coin_source =
                    PathOramLeafCoinSource::from_domain_seed(next.leaf_coin_seed);
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
                clear_written_slots(&mut object.written_slots);
            }
            Self::RawMap(object) => {
                object.wipe_staged();
            }
            Self::UoSmallMap(object) => {
                object.accessed = false;
                object.dirty = false;
            }
            Self::UoOramMap(object) => {
                object.accessed = false;
                object.dirty = false;
                object.leaf_coin_source =
                    PathOramLeafCoinSource::from_domain_seed(object.leaf_coin_seed);
            }
        }
    }

    pub(in crate::runtime) fn enable_injected_path_oram_leaf_coins(&mut self) {
        if let Self::UoOramMap(object) = self {
            if is_path_oram_scheme(&object.spec.oram_scheme) {
                object.leaf_coin_source = PathOramLeafCoinSource::require_injected();
            }
        }
    }

    pub(in crate::runtime) fn install_path_oram_leaf_coins(
        &mut self,
        coins: Box<[usize]>,
    ) -> Result<()> {
        match self {
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme) => {
                object.leaf_coin_source.install(coins);
                Ok(())
            }
            _ if coins.is_empty() => Ok(()),
            _ => bail!("{} is not a path-ORAM map", self.name()),
        }
    }

    pub(in crate::runtime) fn ensure_path_oram_leaf_coins_consumed(&self) -> Result<()> {
        match self {
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme) => {
                object.leaf_coin_source.ensure_exhausted(&object.spec.name)
            }
            _ => Ok(()),
        }
    }
}

fn boxed_false_flags(len: usize) -> Box<[bool]> {
    FixedBoxBuilder::from_fn(len, |_| false)
}

fn clear_written_slots(slots: &mut [bool]) {
    slots.fill(false);
}

fn no_written_slots(slots: &[bool]) -> bool {
    !slots.iter().any(|written| *written)
}

fn record_array_scan(object: &ArrayObject, trace: &mut CallRecorder) {
    for (index, physical) in object.physical_slots.iter().enumerate() {
        trace.physical_read(
            &object.spec.name,
            format!("{}[{index}]", object.spec.name),
            physical.len(),
        );
    }
}

fn record_small_map_scan(object: &SmallMapObject, trace: &mut CallRecorder) -> Result<()> {
    for (index, _) in object.entries.iter().enumerate() {
        let physical = object.physical_slots.get(index).ok_or_else(|| {
            anyhow!(
                "UO small-map physical slot {} missing for {} despite entry scan schedule",
                index,
                object.spec.name
            )
        })?;
        trace.logical_read("uomap_scan", &object.spec.name, format!("slot:{index}"));
        trace.physical_read(
            &object.spec.name,
            format!("{}#{index}", object.spec.name),
            physical.len(),
        );
    }
    Ok(())
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
    use super::{no_written_slots, MapEntry, RuntimeObject};
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
        .unwrap()
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
        Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(vec![Value::uint(7), Value::uint(9)].into_boxed_slice()),
                ),
            ]
            .into_boxed_slice(),
        )
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
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x11; 20])),
                            ("count".into(), Value::uint(3)),
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x22; 20])),
                            ("count".into(), Value::uint(5)),
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x33; 20])),
                            ("count".into(), Value::uint(7)),
                        ]
                        .into_boxed_slice(),
                    ),
                ]
                .into_boxed_slice();
                array.accessed = true;
                array.written_slots.fill(true);
            }
            _ => unreachable!(),
        }

        let mut allocator = tx_allocator();
        let cloned = object.clone_for_tx(&mut allocator).unwrap();
        allocator.finish().unwrap();

        match cloned {
            RuntimeObject::UoArray(array) => {
                assert_eq!(array.values, vec![zero; 3].into_boxed_slice());
                assert_eq!(array.physical_slots, original_slots);
                assert!(!array.accessed);
                assert!(no_written_slots(&array.written_slots));
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
                map.entries[0] = MapEntry::new(
                    true,
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x44; 20])),
                            ("nonce".into(), Value::uint(1)),
                        ]
                        .into_boxed_slice(),
                    ),
                    nested_nonzero_value(),
                );
                map.entries[1] = MapEntry::new(
                    true,
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x55; 20])),
                            ("nonce".into(), Value::uint(2)),
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("flag".into(), Value::Bool(true)),
                            (
                                "items".into(),
                                Value::Array(
                                    vec![Value::uint(11), Value::uint(13)].into_boxed_slice(),
                                ),
                            ),
                        ]
                        .into_boxed_slice(),
                    ),
                );
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
                        MapEntry::new(false, zero_key.clone(), zero_value.clone()),
                        MapEntry::new(false, zero_key, zero_value),
                    ]
                    .into_boxed_slice()
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
                cell.value = Value::Struct(
                    vec![
                        ("flag".into(), Value::Bool(true)),
                        (
                            "items".into(),
                            Value::Array(vec![Value::uint(21), Value::uint(34)].into_boxed_slice()),
                        ),
                    ]
                    .into_boxed_slice(),
                );
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
    fn uo_cell_set_cell_with_false_predicate_preserves_prior_value() {
        let spec = cell_spec();
        let prior = nested_nonzero_value();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0xC014).unwrap();
        match &mut object {
            RuntimeObject::UoCell(cell) => {
                cell.value = prior.clone();
            }
            _ => unreachable!(),
        }

        let replacement = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(false)),
                (
                    "items".into(),
                    Value::Array(vec![Value::uint(21), Value::uint(34)].into_boxed_slice()),
                ),
            ]
            .into_boxed_slice(),
        );
        let mut recorder = crate::controller::CallRecorder::begin("set_cell_test", &[]);
        object
            .set_cell(replacement, Some(false), &mut recorder)
            .unwrap();

        match object {
            RuntimeObject::UoCell(cell) => {
                assert_eq!(cell.value, prior);
                assert!(cell.accessed);
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
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x91; 20])),
                            ("count".into(), Value::uint(8)),
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x92; 20])),
                            ("count".into(), Value::uint(9)),
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x93; 20])),
                            ("count".into(), Value::uint(10)),
                        ]
                        .into_boxed_slice(),
                    ),
                ]
                .into_boxed_slice();
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
                assert_eq!(array.values, vec![zero; 3].into_boxed_slice());
                assert_eq!(array.values.as_ptr(), values_ptr);
                assert_eq!(array.physical_slots.as_ptr(), physical_slots_ptr);
                assert!(!array.accessed);
                assert!(no_written_slots(&array.written_slots));
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_array_set_array_with_false_predicate_preserves_prior_value() {
        let spec = array_spec();
        let prior = Value::Struct(
            vec![
                ("owner".into(), Value::Address([0xB1; 20])),
                ("count".into(), Value::uint(19)),
            ]
            .into_boxed_slice(),
        );
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0xA663).unwrap();
        match &mut object {
            RuntimeObject::UoArray(array) => {
                array.values[1] = prior.clone();
            }
            _ => unreachable!(),
        }

        let replacement = Value::Struct(
            vec![
                ("owner".into(), Value::Address([0xB2; 20])),
                ("count".into(), Value::uint(27)),
            ]
            .into_boxed_slice(),
        );
        let mut recorder = crate::controller::CallRecorder::begin("set_array_test", &[]);
        object
            .set_array(1, replacement, Some(false), &mut recorder)
            .unwrap();

        match object {
            RuntimeObject::UoArray(array) => {
                assert_eq!(array.values[1], prior);
                assert!(array.accessed);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_array_out_of_bounds_index_is_masked_no_match() {
        let spec = array_spec();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0xA664).unwrap();
        let prior = Value::Struct(
            vec![
                ("owner".into(), Value::Address([0xC1; 20])),
                ("count".into(), Value::uint(31)),
            ]
            .into_boxed_slice(),
        );
        match &mut object {
            RuntimeObject::UoArray(array) => {
                array.values[1] = prior.clone();
            }
            _ => unreachable!(),
        }

        let replacement = Value::Struct(
            vec![
                ("owner".into(), Value::Address([0xC2; 20])),
                ("count".into(), Value::uint(37)),
            ]
            .into_boxed_slice(),
        );
        let mut recorder = crate::controller::CallRecorder::begin("array_oob_test", &[]);
        let read = object.get_array(99, &mut recorder).unwrap();
        object
            .set_array(99, replacement, Some(true), &mut recorder)
            .unwrap();

        assert_eq!(read, Value::zero_for_type(&spec.value_type));
        match object {
            RuntimeObject::UoArray(array) => {
                assert_eq!(array.values[1], prior);
                assert!(array.accessed);
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
        let committed_value = Value::Struct(
            vec![
                ("owner".into(), Value::Address([0xA1; 20])),
                ("count".into(), Value::uint(17)),
            ]
            .into_boxed_slice(),
        );
        match &mut new {
            RuntimeObject::UoArray(array) => {
                array.values[1] = committed_value.clone();
                array.accessed = true;
                array.written_slots[1] = true;
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
                assert!(no_written_slots(&array.written_slots));
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn uo_small_map_put_map_with_false_predicate_preserves_prior_entry() {
        let spec = small_map_spec();
        let key = Value::Struct(
            vec![
                ("owner".into(), Value::Address([0x71; 20])),
                ("nonce".into(), Value::uint(4)),
            ]
            .into_boxed_slice(),
        );
        let original_key = key.clone();
        let prior = nested_nonzero_value();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0x5C00).unwrap();
        match &mut object {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = MapEntry::new(true, key.clone(), prior.clone());
            }
            _ => unreachable!(),
        }

        let replacement = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(false)),
                (
                    "items".into(),
                    Value::Array(vec![Value::uint(21), Value::uint(34)].into_boxed_slice()),
                ),
            ]
            .into_boxed_slice(),
        );
        let mut recorder = crate::controller::CallRecorder::begin("put_map_test", &[]);
        let mut allocator = tx_allocator();
        object
            .put_map(key, replacement, Some(false), &mut recorder, &mut allocator)
            .unwrap();
        allocator.finish().unwrap();

        match object {
            RuntimeObject::UoSmallMap(map) => {
                assert_eq!(map.entries[0], MapEntry::new(true, original_key, prior));
                assert!(map.accessed);
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
                map.entries[0] = MapEntry::new(
                    true,
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x77; 20])),
                            ("nonce".into(), Value::uint(4)),
                        ]
                        .into_boxed_slice(),
                    ),
                    nested_nonzero_value(),
                );
            }
            _ => unreachable!(),
        }

        let mut shadow_allocator = tx_allocator();
        let mut new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        match &mut new {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = MapEntry::new(
                    true,
                    Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0x88; 20])),
                            ("nonce".into(), Value::uint(5)),
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("flag".into(), Value::Bool(true)),
                            (
                                "items".into(),
                                Value::Array(
                                    vec![Value::uint(15), Value::uint(16)].into_boxed_slice(),
                                ),
                            ),
                        ]
                        .into_boxed_slice(),
                    ),
                );
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
                        MapEntry::new(false, zero_key.clone(), zero_value.clone()),
                        MapEntry::new(false, zero_key, zero_value),
                    ]
                    .into_boxed_slice()
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
        let committed_entry = MapEntry::new(
            true,
            Value::Struct(
                vec![
                    ("owner".into(), Value::Address([0x99; 20])),
                    ("nonce".into(), Value::uint(6)),
                ]
                .into_boxed_slice(),
            ),
            nested_nonzero_value(),
        );
        match &mut new {
            RuntimeObject::UoSmallMap(map) => {
                map.entries[0] = MapEntry::new(
                    committed_entry.is_occupied(),
                    committed_entry.key().clone(),
                    committed_entry.value().clone(),
                );
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
            RuntimeObject::UoOramMap(map) => map.oram.logical_state_snapshot_for_test(),
            _ => unreachable!(),
        };

        match &mut old {
            RuntimeObject::UoOramMap(map) => {
                map.oram.install_slot_for_test(
                    0,
                    MapEntry::new(true, Value::Address([0x66; 20]), Value::uint(19)),
                    Some(0),
                );
            }
            _ => unreachable!(),
        }

        let mut shadow_allocator = tx_allocator();
        let new = old.clone_for_tx(&mut shadow_allocator).unwrap();
        shadow_allocator.finish().unwrap();
        let (entries_ptr, position_map_ptr, stash_ptr) = match &new {
            RuntimeObject::UoOramMap(map) => map.oram.logical_state_ptrs_for_test(),
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
                let (entries, position_map, stash) = map.oram.logical_state_snapshot_for_test();
                assert_eq!(entries, expected_entries);
                assert_eq!(position_map, expected_position_map);
                assert_eq!(stash, expected_stash);
                let (current_entries_ptr, current_position_map_ptr, current_stash_ptr) =
                    map.oram.logical_state_ptrs_for_test();
                assert_eq!(current_entries_ptr, entries_ptr);
                assert_eq!(current_position_map_ptr, position_map_ptr);
                assert_eq!(current_stash_ptr, stash_ptr);
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
            RuntimeObject::UoOramMap(map) => {
                let (entries, position_map, stash) = map.oram.logical_state_snapshot_for_test();
                let (directory_pages, buckets, counter_slot) = map.oram.storage_snapshot_for_test();
                (
                    entries,
                    position_map,
                    stash,
                    directory_pages,
                    buckets,
                    counter_slot,
                )
            }
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
            RuntimeObject::UoOramMap(map) => {
                let (entries_ptr, position_map_ptr, stash_ptr) =
                    map.oram.logical_state_ptrs_for_test();
                let (directory_pages_ptr, buckets_ptr, counter_ptr) =
                    map.oram.storage_ptrs_for_test();
                (
                    entries_ptr,
                    position_map_ptr,
                    stash_ptr,
                    directory_pages_ptr,
                    buckets_ptr,
                    counter_ptr,
                )
            }
            _ => unreachable!(),
        };

        match &mut new {
            RuntimeObject::UoOramMap(map) => {
                map.oram.install_slot_for_test(
                    0,
                    MapEntry::new(true, Value::Address([0x77; 20]), Value::uint(23)),
                    Some(0),
                );
                map.oram.corrupt_storage_for_test();
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
                let (entries, position_map, stash) = map.oram.logical_state_snapshot_for_test();
                assert_eq!(entries, expected_entries);
                assert_eq!(position_map, expected_position_map);
                assert_eq!(stash, expected_stash);
                let (directory_pages, buckets, counter_slot) = map.oram.storage_snapshot_for_test();
                assert_eq!(directory_pages, expected_directory_pages);
                assert_eq!(buckets, expected_buckets);
                assert_eq!(counter_slot, expected_counter_slot);
                let (current_entries_ptr, current_position_map_ptr, current_stash_ptr) =
                    map.oram.logical_state_ptrs_for_test();
                assert_eq!(current_entries_ptr, entries_ptr);
                assert_eq!(current_position_map_ptr, position_map_ptr);
                assert_eq!(current_stash_ptr, stash_ptr);
                let (current_directory_pages_ptr, current_buckets_ptr, current_counter_ptr) =
                    map.oram.storage_ptrs_for_test();
                assert_eq!(current_directory_pages_ptr, directory_pages_ptr);
                assert_eq!(current_buckets_ptr, buckets_ptr);
                assert_eq!(current_counter_ptr, counter_ptr);
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }
}
