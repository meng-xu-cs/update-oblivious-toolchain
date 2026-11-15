use crate::controller::CallRecorder;
use crate::freshness::PathOramLeafSeed;
use crate::oram::{
    select_pending_put_value, MapEntry, OramState, OramTranscript, PathOramLeafCoinSource,
    PendingOramPut,
};
use crate::secret::ObjectSecret;
use anyhow::{anyhow, bail, Result};
use serde_json::json;
use std::collections::BTreeMap;
use uo_allocator::AllocatorSession;
use uo_core::ir::{BackendKind, ContainerKind, StateObject};
use uo_core::manifest::is_path_oram_scheme;
use uo_core::trace::{ExactObjectKind, ExactObjectSlots};
use uo_core::Value;
#[cfg_attr(not(any(test, feature = "diagnostics")), allow(unused_imports))]
use uo_core::{
    FixedBoxBuilder, RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness,
};
use uo_store::{sealed_record_len, SharedStorage, StorageHandle, StoreCipher};

#[path = "generated_object_helpers.rs"]
mod generated_object_helpers;

use generated_object_helpers::{
    clone_runtime_value_for_read, cold_commit_boxed_values, cold_commit_small_map_entries,
    cold_commit_value_to_zero, cold_zero_boxed_values, cold_zero_small_map_entries,
    cold_zero_small_map_entry, cold_zero_value, decode_array_values_from_storage,
    decode_cell_value_from_storage, decode_small_map_entries_from_storage,
    keep_loaded_array_values, keep_loaded_cell_value, keep_loaded_small_map_entries,
    raw_encode_value, reconcile_array_commit_values, reconcile_cell_commit_value,
    reconcile_raw_map_committed_entry, reconcile_small_map_commit_entries,
    seal_canonical_value_commit_slot, seal_map_record, seal_map_record_commit_slot, seal_value,
    select_array_value_at_index, select_small_map_value_for_key, update_array_value_at_index,
    update_masked_value, update_small_map_entries_for_put, wipe_boxed_values_and_slots,
    wipe_loaded_array_values, wipe_loaded_cell_value, wipe_small_map_entries_and_slots,
    wipe_value_and_physical_slot,
};

#[derive(Debug)]
pub(crate) struct CellObject {
    spec: StateObject,
    value: Value,
    physical: Box<[u8]>,
    cipher: StoreCipher,
    accessed: bool,
    written: bool,
    // The value the call loaded, kept from the call's first write of the
    // cell until its commit: what the commit keeps if the call aborted.
    // `None` while `value` is still the loaded one.
    loaded_value: Option<Value>,
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
            loaded_value: None,
        }
    }

    fn wipe_secrets(&mut self) {
        wipe_value_and_physical_slot(&mut self.value, &mut self.physical);
        wipe_loaded_cell_value(&mut self.loaded_value);
        self.accessed = false;
        self.written = false;
    }

    /// The cell's sealed record, read from its store.
    fn read_record(&self) -> Result<Box<[u8]>> {
        self.cipher.read_stored_record(
            &self.spec.name,
            sealed_record_len(self.spec.value_type.canonical_len()),
        )
    }

    fn decode_value(&self, physical: &[u8], allocator: &mut AllocatorSession) -> Result<Value> {
        decode_cell_value_from_storage(
            &self.spec.name,
            &self.spec.value_type,
            physical,
            &self.cipher,
            allocator,
        )
    }

    fn decode_value_from_storage(&self, allocator: &mut AllocatorSession) -> Result<Value> {
        let physical = self.read_record()?;
        self.decode_value(&physical, allocator)
    }

    /// Load the cell for a call: read its sealed record from the store, once
    /// for the call, and open it. The call's accesses work on the opened
    /// value, and the call keeps the record to seal the next one over it.
    fn clone_for_tx(
        &self,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let physical = self.read_record()?;
        trace.physical_scan(&self.spec.name, ExactObjectKind::Cell, 1, physical.len());
        Ok(Self {
            spec: self.spec.clone(),
            value: self.decode_value(&physical, allocator)?,
            physical,
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            written: false,
            loaded_value: None,
        })
    }

    fn cold_commit(&mut self) -> Result<()> {
        cold_commit_value_to_zero(&mut self.value, &self.spec.value_type);
        wipe_loaded_cell_value(&mut self.loaded_value);
        // The store keeps the cell's record: a committed cell holds none.
        self.physical = Box::default();
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
    // The values the call loaded, kept from the call's first write of the
    // array until its commit: what the commit keeps if the call aborted.
    // `None` while `values` are still the loaded ones.
    loaded_values: Option<Box<[Value]>>,
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
            loaded_values: None,
        }
    }

    fn wipe_secrets(&mut self) {
        wipe_boxed_values_and_slots(&mut self.values, &mut self.physical_slots);
        wipe_loaded_array_values(&mut self.loaded_values);
        self.accessed = false;
        clear_written_slots(&mut self.written_slots);
    }

    /// The array's sealed slots, read from its store in slot order.
    fn read_records(&self) -> Result<Box<[Box<[u8]>]>> {
        read_exact_slots(
            &self.cipher,
            &self.spec.name,
            ExactObjectKind::Array,
            self.values.len(),
            sealed_record_len(self.spec.value_type.canonical_len()),
        )
    }

    fn decode_values(
        &self,
        physical_slots: &[Box<[u8]>],
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[Value]>> {
        decode_array_values_from_storage(
            &self.spec.name,
            &self.spec.value_type,
            physical_slots,
            &self.cipher,
            allocator,
        )
    }

    fn decode_values_from_storage(&self, allocator: &mut AllocatorSession) -> Result<Box<[Value]>> {
        let physical_slots = self.read_records()?;
        self.decode_values(&physical_slots, allocator)
    }

    /// Load the array for a call: read every sealed slot from the store,
    /// once for the call, and open it. The call's accesses work on the
    /// opened values, and the call keeps the records to seal the next ones
    /// over them.
    fn clone_for_tx(
        &self,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let physical_slots = self.read_records()?;
        record_load_scan(
            trace,
            &self.spec.name,
            ExactObjectKind::Array,
            &physical_slots,
        );
        Ok(Self {
            spec: self.spec.clone(),
            values: self.decode_values(&physical_slots, allocator)?,
            written_slots: boxed_false_flags(physical_slots.len()),
            physical_slots,
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            loaded_values: None,
        })
    }

    fn cold_commit(&mut self) -> Result<()> {
        cold_commit_boxed_values(&mut self.values, &self.spec.value_type);
        wipe_loaded_array_values(&mut self.loaded_values);
        // The store keeps the array's records: a committed array holds none.
        self.physical_slots = Box::default();
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
    // The store that keeps the map's public values, once the map is
    // deployed with one.
    storage: Option<StorageHandle>,
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
            storage: self.storage.clone(),
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
    // The entries the call loaded, kept from the call's first write of the
    // map until its commit: what the commit keeps if the call aborted.
    // `None` while `entries` are still the loaded ones. An entry wipes
    // itself when it is dropped.
    loaded_entries: Option<Box<[MapEntry]>>,
}

impl SmallMapObject {
    fn wipe_secrets(&mut self) {
        wipe_small_map_entries_and_slots(&mut self.entries, &mut self.physical_slots);
        self.loaded_entries = None;
        self.accessed = false;
        self.dirty = false;
    }

    /// The map's sealed slots, read from its store in slot order.
    fn read_records(&self) -> Result<Box<[Box<[u8]>]>> {
        let key_type = self
            .spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("small-map object {} missing key type", self.spec.name))?;
        read_exact_slots(
            &self.cipher,
            &self.spec.name,
            ExactObjectKind::Map,
            self.entries.len(),
            sealed_record_len(1 + key_type.canonical_len() + self.spec.value_type.canonical_len()),
        )
    }

    fn decode_entries(
        &self,
        physical_slots: &[Box<[u8]>],
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[MapEntry]>> {
        decode_small_map_entries_from_storage(&self.spec, physical_slots, &self.cipher, allocator)
    }

    fn decode_entries_from_storage(
        &self,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[MapEntry]>> {
        let physical_slots = self.read_records()?;
        self.decode_entries(&physical_slots, allocator)
    }

    /// Load the map for a call: read every sealed slot from the store, once
    /// for the call, and open it. The call's accesses scan the opened
    /// entries, and the call keeps the records to seal the next ones over
    /// them.
    fn clone_for_tx(
        &self,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let physical_slots = self.read_records()?;
        record_load_scan(
            trace,
            &self.spec.name,
            ExactObjectKind::Map,
            &physical_slots,
        );
        Ok(Self {
            spec: self.spec.clone(),
            entries: self.decode_entries(&physical_slots, allocator)?,
            physical_slots,
            cipher: self.cipher.clone_for_runtime_state(),
            accessed: false,
            dirty: false,
            loaded_entries: None,
        })
    }

    fn cold_commit(&mut self) -> Result<()> {
        let key_type = self
            .spec
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("small-map object {} missing key type", self.spec.name))?;
        cold_commit_small_map_entries(&mut self.entries, key_type, &self.spec.value_type);
        // The store keeps the map's records: a committed map holds none.
        self.physical_slots = Box::default();
        self.loaded_entries = None;
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
    leaf_coin_seed: PathOramLeafSeed,
    leaf_coin_source: PathOramLeafCoinSource,
    // Path ORAM schemes: the call's writes, which reach the ORAM at commit,
    // and the map's contents with those writes applied, which later reads in
    // the call return.
    pending_view: Option<Box<[MapEntry]>>,
    pending_puts: Vec<PendingOramPut>,
    // The private scheme: whether each of the call's writes, in order, reuses
    // the presence the preceding get of its key found (public, from the
    // program), the next write's index, and the last get's key and presence.
    presence_plan: Box<[bool]>,
    next_put: usize,
    last_get: Option<(Value, bool)>,
}

impl OramMapObject {
    fn clear_pending(&mut self) {
        self.pending_view = None;
        self.pending_puts.clear();
        self.presence_plan = Box::default();
        self.next_put = 0;
        self.last_get = None;
    }

    fn wipe_secrets(&mut self) {
        self.accessed = false;
        self.dirty = false;
        self.clear_pending();
    }

    fn cold_commit(&mut self) -> Result<()> {
        self.oram.cold_commit();
        self.accessed = false;
        self.dirty = false;
        self.clear_pending();
        self.leaf_coin_source = PathOramLeafCoinSource::from_domain_seed(&self.leaf_coin_seed);
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

    /// A fresh object, with its first records sealed for a deployment to
    /// hand to its store. Its storage key and its initial placement come
    /// from a generator seeded with 256 bits of the object's secret, and its
    /// Path ORAM leaf coins from a seed derived from the same secret.
    pub(in crate::runtime) fn instantiate(
        spec: &StateObject,
        secret: &ObjectSecret,
    ) -> Result<Self> {
        Self::instantiate_with(spec, secret, true)
    }

    /// The object a restart finds in a store: the same key and leaf coins as
    /// a fresh object of the same secret, and no record. Nothing is sealed:
    /// the store keeps the object's records.
    pub(in crate::runtime) fn instantiate_for_restart(
        spec: &StateObject,
        secret: &ObjectSecret,
    ) -> Result<Self> {
        Self::instantiate_with(spec, secret, false)
    }

    fn instantiate_with(spec: &StateObject, secret: &ObjectSecret, seal: bool) -> Result<Self> {
        #[cfg(not(feature = "insecure-eval-raw"))]
        if spec.confidential && matches!(spec.backend, BackendKind::Raw) {
            bail!("confidential object {} uses raw backend", spec.name);
        }
        let mut rng = secret.rng()?;
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
                    loaded_value: None,
                }))
            }
            (ContainerKind::Cell, _) => {
                let logical = cold_zero_value(&spec.value_type);
                let cipher = StoreCipher::from_rng(&mut rng);
                let physical = if seal {
                    seal_value(&cell_slot_aad(&spec.name), &logical, &cipher)?
                } else {
                    Box::default()
                };
                Ok(Self::UoCell(CellObject {
                    spec: spec.clone(),
                    physical,
                    value: logical,
                    cipher,
                    accessed: false,
                    written: false,
                    loaded_value: None,
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
                    loaded_values: None,
                }))
            }
            (ContainerKind::Array, _) => {
                let capacity = spec
                    .capacity
                    .ok_or_else(|| anyhow!("array {} is missing capacity", spec.name))?;
                let zero_value = cold_zero_value(&spec.value_type);
                let cipher = StoreCipher::from_rng(&mut rng);
                let values = cold_zero_boxed_values(capacity, &spec.value_type);
                let sealed = if seal { capacity } else { 0 };
                let mut physical_slots = FixedBoxBuilder::new(sealed);
                for index in 0..sealed {
                    let aad = array_slot_aad(&spec.name, index);
                    physical_slots.push(seal_value(&aad, &zero_value, &cipher)?)?;
                }
                Ok(Self::UoArray(ArrayObject {
                    spec: spec.clone(),
                    values,
                    physical_slots: physical_slots.finish()?,
                    cipher,
                    accessed: false,
                    written_slots: boxed_false_flags(capacity),
                    loaded_values: None,
                }))
            }
            (ContainerKind::Map, BackendKind::Raw) => Ok(Self::RawMap(RawMapObject {
                spec: spec.clone(),
                entries: BTreeMap::new(),
                staged: BTreeMap::new(),
                storage: None,
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
                let sealed = if seal { capacity } else { 0 };
                let mut physical_slots = FixedBoxBuilder::new(sealed);
                for index in 0..sealed {
                    let aad = small_map_slot_aad(&spec.name, index);
                    physical_slots.push(seal_map_record(&aad, &zero_entry, &cipher)?)?;
                }
                Ok(Self::UoSmallMap(SmallMapObject {
                    spec: spec.clone(),
                    entries,
                    physical_slots: physical_slots.finish()?,
                    cipher,
                    accessed: false,
                    dirty: false,
                    loaded_entries: None,
                }))
            }
            (ContainerKind::Map, BackendKind::Oram) => {
                let leaf_coin_seed = secret.path_oram_leaf_seed()?;
                Ok(Self::UoOramMap(OramMapObject {
                    spec: spec.clone(),
                    oram: OramState::instantiate(spec, &mut rng, seal)?,
                    accessed: false,
                    dirty: false,
                    leaf_coin_source: PathOramLeafCoinSource::from_domain_seed(&leaf_coin_seed),
                    leaf_coin_seed,
                    pending_view: None,
                    pending_puts: Vec::new(),
                    presence_plan: Box::default(),
                    next_put: 0,
                    last_get: None,
                }))
            }
        }
    }

    /// An object whose secret a test can reproduce from a seed, deployed
    /// into a store of its own, which keeps the object's records.
    #[cfg(test)]
    pub fn instantiate_with_seed(spec: &StateObject, seed: u64) -> Result<Self> {
        let mut object = Self::instantiate(spec, &ObjectSecret::from_diagnostic_seed(seed))?;
        object.deploy_into_storage(&SharedStorage::memory())?;
        Ok(object)
    }

    /// The object's cipher, sharing its key's count of seals, if the object
    /// has a key.
    pub(in crate::runtime) fn seal_cipher(&self) -> Option<StoreCipher> {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                Some(object.cipher.clone_for_runtime_state())
            }
            Self::RawArray(object) | Self::UoArray(object) => {
                Some(object.cipher.clone_for_runtime_state())
            }
            Self::UoSmallMap(object) => Some(object.cipher.clone_for_runtime_state()),
            Self::UoOramMap(object) => Some(object.oram.seal_cipher()),
            Self::RawMap(_) => None,
        }
    }

    /// Put a newly instantiated object behind its contract's store. A
    /// sealed object's cipher keeps its part of the store, so every record
    /// the object opens or seals from now on crosses to the store, and the
    /// store takes the object's records as their first, under the names a
    /// call's trace gives them; the object keeps none of them. A public
    /// object keeps its part of the store for the values a call commits.
    pub(in crate::runtime) fn deploy_into_storage(
        &mut self,
        storage: &SharedStorage,
    ) -> Result<()> {
        let handle = storage.handle(self.name());
        match self {
            Self::UoCell(object) => {
                object.cipher.attach_storage(handle);
                let physical = std::mem::take(&mut object.physical);
                object
                    .cipher
                    .store_first_record(&object.spec.name, &physical)
            }
            Self::UoArray(object) => {
                object.cipher.attach_storage(handle);
                let slots = ExactObjectSlots::none_of(&object.spec.name, ExactObjectKind::Array);
                let physical_slots = std::mem::take(&mut object.physical_slots);
                for (index, slot) in physical_slots.iter().enumerate() {
                    object
                        .cipher
                        .store_first_record(&slots.location(index), slot)?;
                }
                Ok(())
            }
            Self::UoSmallMap(object) => {
                object.cipher.attach_storage(handle);
                let slots = ExactObjectSlots::none_of(&object.spec.name, ExactObjectKind::Map);
                let physical_slots = std::mem::take(&mut object.physical_slots);
                for (index, slot) in physical_slots.iter().enumerate() {
                    object
                        .cipher
                        .store_first_record(&slots.location(index), slot)?;
                }
                Ok(())
            }
            Self::UoOramMap(object) => object.oram.deploy_into_storage(&object.spec, handle),
            Self::RawCell(object) => {
                object.cipher.attach_storage(handle);
                Ok(())
            }
            Self::RawArray(object) => {
                object.cipher.attach_storage(handle);
                Ok(())
            }
            Self::RawMap(object) => {
                object.storage = Some(handle);
                Ok(())
            }
        }
    }

    /// Give an object instantiated for a restart the state a store keeps
    /// for it: how a runtime that restarts finds the object a deployment of
    /// the same contract and secret left. A sealed object holds no record:
    /// its cipher takes its part of the store, which keeps its records, and
    /// resumes at the seal count the store has reserved, so it repeats no
    /// nonce of a record the store was handed. A public object takes the
    /// values the store keeps.
    pub(in crate::runtime) fn restore_from_storage(
        &mut self,
        storage: &SharedStorage,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        let handle = storage.handle(self.name());
        match self {
            Self::UoCell(object) => {
                object.cipher.resume_seal_count(handle.reserved_seals());
                object.cipher.attach_storage(handle);
            }
            Self::UoArray(object) => {
                object.cipher.resume_seal_count(handle.reserved_seals());
                object.cipher.attach_storage(handle);
            }
            Self::UoSmallMap(object) => {
                object.cipher.resume_seal_count(handle.reserved_seals());
                object.cipher.attach_storage(handle);
            }
            Self::UoOramMap(object) => {
                object
                    .oram
                    .restore_from_storage(&object.spec, handle, allocator)?;
            }
            Self::RawCell(object) => {
                for (location, value) in handle.public_records() {
                    if location != object.spec.name {
                        bail!("the store keeps a value at {location} that is no slot of a cell");
                    }
                    let value: Value = serde_json::from_slice(&value)?;
                    object.physical = raw_encode_value(&value)?;
                    object.value = value;
                }
                object.cipher.attach_storage(handle);
            }
            Self::RawArray(object) => {
                for (location, value) in handle.public_records() {
                    let index = location
                        .strip_prefix(object.spec.name.as_str())
                        .and_then(|rest| rest.strip_prefix('['))
                        .and_then(|rest| rest.strip_suffix(']'))
                        .and_then(|index| index.parse::<usize>().ok())
                        .filter(|index| *index < object.values.len())
                        .ok_or_else(|| {
                            anyhow!(
                                "the store keeps a value at {location} that is no slot of an array"
                            )
                        })?;
                    let value: Value = serde_json::from_slice(&value)?;
                    if let (Some(slot), Some(physical)) = (
                        object.values.get_mut(index),
                        object.physical_slots.get_mut(index),
                    ) {
                        *physical = raw_encode_value(&value)?;
                        *slot = value;
                    }
                }
                object.cipher.attach_storage(handle);
            }
            Self::RawMap(object) => {
                let prefix = format!("{}::", object.spec.name);
                for (location, value) in handle.public_records() {
                    let key_name = location.strip_prefix(prefix.as_str()).ok_or_else(|| {
                        anyhow!("the store keeps a value at {location} that is no entry of a map")
                    })?;
                    let value: Value = serde_json::from_slice(&value)?;
                    let physical = raw_encode_value(&value)?;
                    reconcile_raw_map_committed_entry(
                        &mut object.entries,
                        key_name,
                        &value,
                        physical,
                    );
                }
                object.storage = Some(handle);
            }
        }
        Ok(())
    }

    /// Load the object for a call. An exact object (a cell, an array or a
    /// full-scan map on a sealed backend) is read here, every slot of it,
    /// and this is the only time the call reads it: the scan is traced
    /// once, whatever the number of the call's accesses, and the accesses
    /// work on the opened copy. A raw object is copied and traces each
    /// access; a Path ORAM map reads its paths as it is accessed.
    pub(in crate::runtime) fn clone_for_tx(
        &self,
        trace: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        match self {
            Self::RawCell(object) => Ok(Self::RawCell(object.clone_committed_public())),
            Self::RawArray(object) => Ok(Self::RawArray(object.clone_committed_public())),
            Self::RawMap(object) => Ok(Self::RawMap(object.clone_committed_public())),
            Self::UoCell(object) => Ok(Self::UoCell(object.clone_for_tx(trace, allocator)?)),
            Self::UoArray(object) => Ok(Self::UoArray(object.clone_for_tx(trace, allocator)?)),
            Self::UoSmallMap(object) => {
                Ok(Self::UoSmallMap(object.clone_for_tx(trace, allocator)?))
            }
            Self::UoOramMap(object) => Ok(Self::UoOramMap(OramMapObject {
                spec: object.spec.clone(),
                oram: object.oram.clone_for_tx(&object.spec, allocator)?,
                accessed: false,
                dirty: false,
                leaf_coin_seed: object.leaf_coin_seed.duplicate(),
                leaf_coin_source: PathOramLeafCoinSource::from_domain_seed(&object.leaf_coin_seed),
                pending_view: None,
                pending_puts: Vec::with_capacity(object.oram.parameters().accesses_per_call),
                presence_plan: Box::default(),
                next_put: 0,
                last_get: None,
            })),
        }
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
        // A committed object holds no sealed record: the store keeps them.
        self.holds_no_sealed_record()
            && match self {
                Self::UoCell(object) => !object.accessed && !object.written,
                Self::UoArray(object) => {
                    !object.accessed && no_written_slots(&object.written_slots)
                }
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

    /// Hand each sealed record the store keeps for the object to `visit`,
    /// in slot order. These are the bytes a host that keeps the storage
    /// sees; the object holds none of them. A raw object seals nothing.
    pub(in crate::runtime) fn for_each_sealed_record(
        &self,
        visit: &mut dyn FnMut(&[u8]),
    ) -> Result<()> {
        let mut visit_slots = |cipher: &StoreCipher, name: &str, kind, slots: usize| {
            let locations = ExactObjectSlots::none_of(name, kind);
            (0..slots).try_for_each(|index| {
                visit_stored_record(cipher, &locations.location(index), &mut *visit)
            })
        };
        match self {
            Self::UoCell(object) => {
                visit_slots(&object.cipher, &object.spec.name, ExactObjectKind::Cell, 1)
            }
            Self::UoArray(object) => visit_slots(
                &object.cipher,
                &object.spec.name,
                ExactObjectKind::Array,
                object.values.len(),
            ),
            Self::UoSmallMap(object) => visit_slots(
                &object.cipher,
                &object.spec.name,
                ExactObjectKind::Map,
                object.entries.len(),
            ),
            Self::UoOramMap(object) => object.oram.for_each_sealed_record(&object.spec, visit),
            Self::RawCell(_) | Self::RawArray(_) | Self::RawMap(_) => Ok(()),
        }
    }

    /// The object's cipher and the sealed records its store keeps, so that
    /// a test can compare the keys of two objects and read the records'
    /// nonces. A raw object seals nothing.
    #[cfg(test)]
    pub(crate) fn sealed_storage_for_test(&self) -> Option<(&StoreCipher, Vec<Box<[u8]>>)> {
        let cipher = match self {
            Self::UoCell(object) => &object.cipher,
            Self::UoArray(object) => &object.cipher,
            Self::UoSmallMap(object) => &object.cipher,
            Self::UoOramMap(object) => object.oram.cipher_for_test(),
            Self::RawCell(_) | Self::RawArray(_) | Self::RawMap(_) => return None,
        };
        let mut records = Vec::new();
        self.for_each_sealed_record(&mut |record| records.push(Box::from(record)))
            .ok()?;
        Some((cipher, records))
    }

    /// Whether the object holds no sealed record: the store keeps them all.
    /// A loaded object holds the records it read until the call commits.
    pub(crate) fn holds_no_sealed_record(&self) -> bool {
        match self {
            Self::UoCell(object) => object.physical.is_empty(),
            Self::UoArray(object) => object.physical_slots.is_empty(),
            Self::UoSmallMap(object) => object.physical_slots.is_empty(),
            Self::UoOramMap(object) => object.oram.holds_no_sealed_record(),
            Self::RawCell(_) | Self::RawArray(_) | Self::RawMap(_) => true,
        }
    }

    #[cfg(test)]
    pub(crate) fn path_oram_access_counter_for_test(&self) -> Option<u64> {
        match self {
            Self::UoOramMap(object) => Some(object.oram.access_counter_for_test()),
            _ => None,
        }
    }

    #[cfg(any(test, feature = "diagnostics"))]
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

    #[cfg(any(test, feature = "diagnostics"))]
    pub(in crate::runtime) fn exposes_path_oram_witnesses(&self) -> bool {
        matches!(
            self,
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme)
        )
    }

    #[cfg_attr(feature = "insecure-eval-raw", allow(dead_code))]
    pub(in crate::runtime) fn is_update_oblivious_backend(&self) -> bool {
        matches!(
            self,
            Self::UoCell(_) | Self::UoArray(_) | Self::UoSmallMap(_) | Self::UoOramMap(_)
        )
    }

    /// Whether the object's declared spec marks it `confidential: true`. A
    /// confidential kernel may target only confidential objects, independent of
    /// the backend (a UO-but-public object is not a valid confidential target).
    pub(in crate::runtime) fn is_confidential(&self) -> bool {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => object.spec.confidential,
            Self::RawArray(object) | Self::UoArray(object) => object.spec.confidential,
            Self::RawMap(object) => object.spec.confidential,
            Self::UoSmallMap(object) => object.spec.confidential,
            Self::UoOramMap(object) => object.spec.confidential,
        }
    }

    #[cfg(any(test, feature = "diagnostics"))]
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
        if self.is_confidential() {
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
                let state = object.oram.public_state_snapshot_value(&object.spec)?;
                json!({"kind": "oram_map", "name": &object.spec.name, "state": state})
            }
        }))
    }

    pub(in crate::runtime) fn get_cell(&mut self, trace: &mut CallRecorder) -> Result<Value> {
        match self {
            Self::RawCell(object) => {
                object.accessed = true;
                trace.logical_read("cell_get", &object.spec.name, "");
                trace.physical_read(
                    &object.spec.name,
                    object.spec.name.clone(),
                    object.physical.len(),
                );
                Ok(clone_runtime_value_for_read(&object.value))
            }
            Self::UoCell(object) => {
                // The call read the cell when it loaded it.
                object.accessed = true;
                trace.logical_read("cell_get", &object.spec.name, "");
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
                keep_loaded_cell_value(&mut object.loaded_value, &object.value);
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
                // The call read the array when it loaded it; the access
                // selects among the opened values.
                object.accessed = true;
                trace.logical_read("array_get", &object.spec.name, "oblivious");
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
                keep_loaded_array_values(&mut object.loaded_values, &object.values)?;
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
                // The call read the map when it loaded it; the access scans
                // the opened entries.
                object.accessed = true;
                record_small_map_scan(object, trace);
                let value =
                    select_small_map_value_for_key(&object.entries, key, &object.spec.value_type)?;
                Ok((value, false))
            }
            Self::UoOramMap(object) if object.oram.is_tree() => {
                object.accessed = true;
                // A get on the private scheme's tree: one ORAM access per
                // node access.
                let (value, found, transcripts, update_failed) = object.oram.tree_get(
                    &object.spec,
                    key,
                    allocator,
                    &mut object.leaf_coin_source,
                )?;
                record_tree_transcripts(trace, &object.spec, &object.oram, transcripts)?;
                // A later write of the same key may reuse the presence.
                object.last_get = Some((key.clone(), found));
                let value = select_pending_put_value(&object.pending_puts, key, value)?;
                Ok((value, update_failed))
            }
            Self::UoOramMap(object) => {
                object.accessed = true;
                trace.record_oram_access(object.spec.id, object.oram.parameters());
                let (value, transcript, update_failed) =
                    object
                        .oram
                        .get(&object.spec, key, allocator, &mut object.leaf_coin_source)?;
                record_oram_transcript(
                    trace,
                    &object.spec,
                    object.oram.path_bucket_count(),
                    transcript,
                )?;
                // Writes earlier in the call reach the ORAM at commit; until
                // then a read of a key the call wrote takes the last write's
                // value.
                let value = select_pending_put_value(&object.pending_puts, key, value)?;
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
                record_small_map_scan(object, trace);
                trace.logical_write("uomap_put", &object.spec.name, "oblivious");
                keep_loaded_small_map_entries(&mut object.loaded_entries, &object.entries)?;
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
            Self::UoOramMap(object) if object.oram.is_tree() => {
                object.accessed = true;
                // A write to the private scheme's tree reaches it at commit,
                // as one put. Here a get finds whether the key is present,
                // and the map's pending size decides whether the write
                // overflows the map. The tree is not written before the call
                // commits, so a write that the program shows to follow a get
                // of the same key reuses that get's presence instead
                // (`uo_core::presence_reuse`); which writes do is public.
                let reuses = object
                    .presence_plan
                    .get(object.next_put)
                    .copied()
                    .unwrap_or(false);
                object.next_put += 1;
                let (found, update_failed) = if reuses {
                    let Some(last_get) = object.last_get.take() else {
                        bail!(
                            "write to {} reuses a presence that no get found",
                            object.spec.name
                        );
                    };
                    // The program makes the keys equal; a mismatch fails the
                    // write.
                    object.oram.reuse_tree_presence(&last_get, &key)
                } else {
                    let (_value, found, transcripts, update_failed) = object.oram.tree_get(
                        &object.spec,
                        &key,
                        allocator,
                        &mut object.leaf_coin_source,
                    )?;
                    record_tree_transcripts(trace, &object.spec, &object.oram, transcripts)?;
                    (found, update_failed)
                };
                object.last_get = None;
                let capacity_overflowed = object.oram.decide_pending_tree_put(
                    &object.spec,
                    &object.pending_puts,
                    found,
                    &key,
                    &value,
                    apply,
                )?;
                // A write that overflows the map aborts the call and takes no
                // effect, so later reads in the call do not see it.
                object.pending_puts.push(PendingOramPut::new(
                    apply & !capacity_overflowed,
                    key,
                    value,
                ));
                trace.logical_write("uooram_put", &object.spec.name, "oblivious");
                object.dirty = true;
                Ok(capacity_overflowed | update_failed)
            }
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme) => {
                object.accessed = true;
                // The write reaches the ORAM at commit, as one access that is
                // masked off if the call aborts. Here it updates the pending
                // view, which decides whether it overflows the map.
                if object.pending_view.is_none() {
                    object.pending_view = Some(object.oram.clone_logical_entries()?);
                }
                let view = object
                    .pending_view
                    .as_deref_mut()
                    .ok_or_else(|| anyhow!("pending view missing for {}", object.spec.name))?;
                let capacity_overflowed = update_small_map_entries_for_put(
                    view,
                    key.clone(),
                    value.clone(),
                    apply,
                    &object.spec.value_type,
                    &object.spec.name,
                )?;
                // A write that overflows the map aborts the call and takes no
                // effect, so later reads in the call do not see it.
                object.pending_puts.push(PendingOramPut::new(
                    apply & !capacity_overflowed,
                    key,
                    value,
                ));
                trace.logical_write("uooram_put", &object.spec.name, "oblivious");
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
                )?;
                record_oram_transcript(
                    trace,
                    &object.spec,
                    object.oram.path_bucket_count(),
                    transcript,
                )?;
                trace.logical_write("uooram_put", &object.spec.name, "oblivious");
                object.dirty = true;
                Ok(update_failed)
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    /// Store `entries` in this map, loaded as for a call, with no trace: the
    /// full scan takes each as a write of the call would, and a Path ORAM
    /// map makes one committed put for each. A write that overflows the map
    /// fails the load. The capacity sweep fills its maps this way, since an
    /// instrumented call per key is too slow; only a test or diagnostics
    /// build has it.
    #[cfg(any(test, feature = "diagnostics"))]
    pub(in crate::runtime) fn bulk_put_for_diagnostics(
        &mut self,
        entries: Vec<(Value, Value)>,
        allocator: &mut AllocatorSession,
    ) -> Result<()> {
        match self {
            Self::UoSmallMap(object) => {
                object.accessed = true;
                let value_type = object.spec.value_type.clone();
                let object_name = object.spec.name.clone();
                for (key, value) in entries {
                    let capacity_overflowed = update_small_map_entries_for_put(
                        &mut object.entries,
                        key,
                        value,
                        true,
                        &value_type,
                        &object_name,
                    )?;
                    if capacity_overflowed {
                        bail!("bulk load overflows {object_name}");
                    }
                }
                object.dirty = true;
                Ok(())
            }
            Self::UoOramMap(object) if object.oram.is_tree() => {
                object.accessed = true;
                for (key, value) in entries {
                    let put = PendingOramPut::new(true, key, value);
                    object.oram.commit_tree_put(
                        &object.spec,
                        &put,
                        false,
                        allocator,
                        &mut object.leaf_coin_source,
                    )?;
                }
                object.dirty = true;
                Ok(())
            }
            Self::UoOramMap(object) if is_path_oram_scheme(&object.spec.oram_scheme) => {
                object.accessed = true;
                for (key, value) in entries {
                    let put = PendingOramPut::new(true, key, value);
                    object.oram.commit_put(
                        &object.spec,
                        &put,
                        false,
                        allocator,
                        &mut object.leaf_coin_source,
                    )?;
                }
                object.dirty = true;
                Ok(())
            }
            _ => bail!("{} is not a map that a bulk load fills", self.name()),
        }
    }

    /// Commit the object a call ran on over the committed one, `old`.
    /// `may_write` says whether the call's program has a write statement for
    /// the object. An exact object is resealed, slot by slot, exactly when
    /// it does, whether or not a write ran or its predicate held, and also
    /// when the call aborted, with the contents the call loaded. An exact
    /// object the program only reads is left as it was loaded, with no
    /// write. The decision is the program's, not the object's access flags.
    /// Commit reads no storage: an aborted call's contents are the copy the
    /// object kept at its first write, so a call that aborts opens no record
    /// that a call that commits does not. A Path ORAM map has written its
    /// paths as it was accessed.
    pub(in crate::runtime) fn commit(
        self,
        old: &Self,
        aborted: bool,
        may_write: bool,
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
                    keep_public_value(next.cipher.storage(), &next.spec.name, &next.value)?;
                }
                next.accessed = false;
                next.written = false;
                Ok(Self::RawCell(next))
            }
            (Self::UoCell(new), Self::UoCell(_)) => {
                let mut next = new;
                let loaded_value = next.loaded_value.take();
                let spec_name = next.spec.name.clone();
                let cipher = &next.cipher;
                let physical = &mut next.physical;
                trace.begin_exact_rewrite(&spec_name, ExactObjectKind::Cell);
                reconcile_cell_commit_value(
                    &mut next.value,
                    loaded_value,
                    aborted,
                    may_write,
                    |committed_value| {
                        seal_canonical_value_commit_slot(
                            &spec_name,
                            spec_name.clone(),
                            cell_slot_aad(&spec_name),
                            committed_value,
                            physical,
                            cipher,
                            trace,
                            allocator,
                        )
                    },
                )?;
                trace.end_exact_rewrite();
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
                        keep_public_value(
                            next.cipher.storage(),
                            &format!("{}[{index}]", new.spec.name),
                            new_value,
                        )?;
                    }
                }
                next.accessed = false;
                clear_written_slots(&mut next.written_slots);
                Ok(Self::RawArray(next))
            }
            (Self::UoArray(new), Self::UoArray(_)) => {
                let mut next = new;
                let loaded_values = next.loaded_values.take();
                let spec_name = next.spec.name.clone();
                let cipher = &next.cipher;
                let physical_slots = &mut next.physical_slots;
                trace.begin_exact_rewrite(&spec_name, ExactObjectKind::Array);
                reconcile_array_commit_values(
                    &mut next.values,
                    loaded_values,
                    aborted,
                    may_write,
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
                            trace,
                            allocator,
                        )
                    },
                )?;
                trace.end_exact_rewrite();
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
                        keep_public_value(
                            next.storage.as_ref(),
                            &format!("{}::{key_name}", next.spec.name),
                            value,
                        )?;
                    }
                }
                next.staged.clear();
                Ok(Self::RawMap(next))
            }
            (Self::UoSmallMap(new), Self::UoSmallMap(_)) => {
                let mut next = new;
                let loaded_entries = next.loaded_entries.take();
                let spec_name = next.spec.name.clone();
                let cipher = &next.cipher;
                let physical_slots = &mut next.physical_slots;
                trace.begin_exact_rewrite(&spec_name, ExactObjectKind::Map);
                reconcile_small_map_commit_entries(
                    &mut next.entries,
                    loaded_entries,
                    aborted,
                    may_write,
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
                            trace,
                            allocator,
                        )
                    },
                )?;
                trace.end_exact_rewrite();
                next.accessed = false;
                next.dirty = false;
                Ok(Self::UoSmallMap(next))
            }
            (Self::UoOramMap(new), Self::UoOramMap(old)) => {
                let mut next = new;
                if next.accessed {
                    if next.oram.is_tree() {
                        // The call's writes reach the tree now, in order, one
                        // put each, masked off if the call aborted.
                        let pending_puts = std::mem::take(&mut next.pending_puts);
                        for put in pending_puts.iter() {
                            let transcripts = next.oram.commit_tree_put(
                                &next.spec,
                                put,
                                aborted,
                                allocator,
                                &mut next.leaf_coin_source,
                            )?;
                            record_tree_transcripts(trace, &next.spec, &next.oram, transcripts)?;
                        }
                        next.leaf_coin_source.ensure_exhausted(&next.spec.name)?;
                    } else if is_path_oram_scheme(&next.spec.oram_scheme) {
                        // The call's writes reach the ORAM now, in order, one
                        // access each. An aborted call's writes are masked off
                        // but still make their accesses, so the call leaves the
                        // trace of a committed one and nothing is rolled back:
                        // its reads only remapped keys.
                        next.pending_view = None;
                        let pending_puts = std::mem::take(&mut next.pending_puts);
                        for put in pending_puts.iter() {
                            trace.record_oram_access(next.spec.id, next.oram.parameters());
                            let transcript = next.oram.commit_put(
                                &next.spec,
                                put,
                                aborted,
                                allocator,
                                &mut next.leaf_coin_source,
                            )?;
                            record_oram_transcript(
                                trace,
                                &next.spec,
                                next.oram.path_bucket_count(),
                                transcript,
                            )?;
                        }
                        next.leaf_coin_source.ensure_exhausted(&next.spec.name)?;
                    } else {
                        let shadow_oram =
                            std::mem::replace(&mut next.oram, OramState::placeholder());
                        let commit =
                            shadow_oram.commit(&next.spec, &old.oram, aborted, allocator)?;
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
                    PathOramLeafCoinSource::from_domain_seed(&next.leaf_coin_seed);
                Ok(Self::UoOramMap(next))
            }
            _ => bail!("mismatched object kinds during commit"),
        }
    }

    fn clear_transient(&mut self) {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                wipe_loaded_cell_value(&mut object.loaded_value);
                object.accessed = false;
                object.written = false;
            }
            Self::RawArray(object) | Self::UoArray(object) => {
                wipe_loaded_array_values(&mut object.loaded_values);
                object.accessed = false;
                clear_written_slots(&mut object.written_slots);
            }
            Self::RawMap(object) => {
                object.wipe_staged();
            }
            Self::UoSmallMap(object) => {
                object.loaded_entries = None;
                object.accessed = false;
                object.dirty = false;
            }
            Self::UoOramMap(object) => {
                object.accessed = false;
                object.dirty = false;
                object.clear_pending();
                object.leaf_coin_source =
                    PathOramLeafCoinSource::from_domain_seed(&object.leaf_coin_seed);
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

    /// Whether the object is a map on the private Path ORAM scheme.
    pub(in crate::runtime) fn is_private_scheme_map(&self) -> bool {
        matches!(self, Self::UoOramMap(object) if object.oram.is_tree())
    }

    /// Install a private-scheme map's presence-reuse plan for the call:
    /// whether each of its writes, in order, reuses the presence the
    /// preceding get of its key found.
    pub(in crate::runtime) fn install_presence_reuse_plan(
        &mut self,
        plan: Box<[bool]>,
    ) -> Result<()> {
        match self {
            Self::UoOramMap(object) if object.oram.is_tree() => {
                object.presence_plan = plan;
                object.next_put = 0;
                object.last_get = None;
                Ok(())
            }
            _ if plan.iter().all(|reuses| !reuses) => Ok(()),
            _ => bail!("{} is not a private-scheme map", self.name()),
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
                object.leaf_coin_source.ensure_reserved_for_writes(
                    &object.spec.name,
                    object.pending_puts.len(),
                    object.oram.coins_per_pending_write(),
                )
            }
            _ => Ok(()),
        }
    }
}

/// Record a tree operation's node accesses in the call trace, one ORAM
/// access each.
fn record_tree_transcripts(
    trace: &mut CallRecorder,
    spec: &StateObject,
    oram: &OramState,
    transcripts: Box<[OramTranscript]>,
) -> Result<()> {
    for transcript in transcripts.into_vec() {
        trace.record_oram_access(spec.id, oram.parameters());
        record_oram_transcript(trace, spec, oram.path_bucket_count(), transcript)?;
    }
    Ok(())
}

/// Record one ORAM access in the call trace: its logical and physical
/// events and, on a Path ORAM map, its leaf and position-map transition.
fn record_oram_transcript(
    trace: &mut CallRecorder,
    spec: &StateObject,
    path_bucket_count: usize,
    transcript: OramTranscript,
) -> Result<()> {
    let (
        logical_accesses,
        physical_reads,
        physical_writes,
        zero_writes,
        path_leaf,
        path_transition,
    ) = transcript.into_runtime_trace_parts();
    if let Some(leaf) = path_leaf {
        trace.record_path_oram_leaf_access(spec.id, &spec.name, path_bucket_count, leaf);
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
        trace.physical_write(write.with_object(&spec.name));
        Ok(())
    })?;
    trace.add_zero_writes(zero_writes);
    Ok(())
}

/// Leave the value a call committed to a public object with the object's
/// store, so that a runtime that restarts finds it. A public object is not
/// sealed, and the store does not log its values.
fn keep_public_value(storage: Option<&StorageHandle>, location: &str, value: &Value) -> Result<()> {
    if let Some(storage) = storage {
        storage.put_public(location, &serde_json::to_vec(value)?)?;
    }
    Ok(())
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

/// The logical events of one access to a full-scan map: the access scans
/// every opened entry, one event for each, which the trace holds as one
/// item. It reads no sealed record; the call read the map's slots when it
/// loaded the map.
fn record_small_map_scan(object: &SmallMapObject, trace: &mut CallRecorder) {
    trace.logical_scan("uomap_scan", &object.spec.name, object.entries.len());
}

/// Trace the read of every sealed slot of an exact object, in slot order: the
/// call's one read of the object, made when the call loads it. The slots of
/// an object have one length, so the trace holds the scan as one item.
/// The sealed records of the `slots` slots of an exact object, read from the
/// object's store in slot order. A call reads every slot of an exact object
/// it loads, once, and here: the store keeps the records, and they cross the
/// storage boundary as they are read. The call keeps them to seal the slots'
/// next records over them; a committed object holds none.
fn read_exact_slots(
    cipher: &StoreCipher,
    object_name: &str,
    kind: ExactObjectKind,
    slots: usize,
    record_len: usize,
) -> Result<Box<[Box<[u8]>]>> {
    let locations = ExactObjectSlots::none_of(object_name, kind);
    let mut records = FixedBoxBuilder::new(slots);
    for index in 0..slots {
        records.push(cipher.read_stored_record(&locations.location(index), record_len)?)?;
    }
    records.finish()
}

/// Hand `visit` the record the store of `cipher` keeps at `location`, with
/// no copy and no read logged: what a digest of the store's ciphertext reads.
pub(crate) fn visit_stored_record(
    cipher: &StoreCipher,
    location: &str,
    visit: &mut dyn FnMut(&[u8]),
) -> Result<()> {
    cipher
        .storage()
        .ok_or_else(|| anyhow!("no store keeps the record at {location}"))?
        .with_record(location, |record| visit(record))
        .ok_or_else(|| anyhow!("the store holds no record at {location}"))
}

fn record_load_scan(
    trace: &mut CallRecorder,
    object_name: &str,
    kind: ExactObjectKind,
    physical_slots: &[Box<[u8]>],
) {
    let len = physical_slots.first().map_or(0, |slot| slot.len());
    if physical_slots.iter().all(|slot| slot.len() == len) {
        trace.physical_scan(object_name, kind, physical_slots.len(), len);
        return;
    }
    // Slots of more than one length are read one event each.
    let slots = ExactObjectSlots {
        object: object_name.into(),
        kind,
        slots: physical_slots.len(),
        len,
    };
    for (index, slot) in physical_slots.iter().enumerate() {
        trace.physical_read(object_name, slots.location(index), slot.len());
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
            max_commit_ops: 0,
            max_load_ops: 0,
        })
        .unwrap()
    }

    /// A recorder for a load whose trace the test does not read.
    fn load_recorder() -> crate::controller::CallRecorder {
        crate::controller::CallRecorder::begin("load_test", &[])
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

    /// A restart seals nothing. The object it builds has the key of a fresh
    /// object of the same secret and no record, and its key's seal count
    /// stands at zero until the store it is restored from resumes it; a
    /// fresh object seals its first records for its deployment.
    #[test]
    fn an_object_built_for_a_restart_seals_nothing() {
        let surrogate = StateObject {
            oram_scheme: uo_core::manifest::SURROGATE_ORAM_SCHEME.into(),
            ..path_oram_spec()
        };
        let tree = StateObject {
            oram_scheme: uo_core::manifest::PATH_ORAM_PRIVATE_POSMAP_SCHEME.into(),
            ..path_oram_spec()
        };
        for spec in [
            cell_spec(),
            array_spec(),
            small_map_spec(),
            path_oram_spec(),
            surrogate,
            tree,
        ] {
            let secret = crate::secret::ObjectSecret::from_diagnostic_seed(0x5E57);
            let fresh = RuntimeObject::instantiate(&spec, &secret).unwrap();
            let restarted = RuntimeObject::instantiate_for_restart(&spec, &secret).unwrap();
            let (fresh_cipher, restarted_cipher) = (
                fresh.seal_cipher().unwrap(),
                restarted.seal_cipher().unwrap(),
            );
            assert!(fresh_cipher.seal_count() > 0, "{}", spec.name);
            assert!(!fresh.holds_no_sealed_record(), "{}", spec.name);
            assert_eq!(restarted_cipher.seal_count(), 0, "{}", spec.name);
            assert!(restarted.holds_no_sealed_record(), "{}", spec.name);
            assert!(fresh_cipher == restarted_cipher, "{}", spec.name);
            assert!(restarted.committed_cache_is_cold(), "{}", spec.name);
        }
    }

    #[test]
    fn uo_cell_clone_for_tx_rebuilds_from_sealed_storage() {
        let spec = cell_spec();
        let mut object = RuntimeObject::instantiate_with_seed(&spec, 0xC311).unwrap();
        let zero = Value::zero_for_type(&spec.value_type);
        // The committed cell holds no record: the store keeps it.
        assert!(object.holds_no_sealed_record());
        let original_physical = object.sealed_storage_for_test().unwrap().1[0].clone();

        match &mut object {
            RuntimeObject::UoCell(cell) => {
                cell.value = nested_nonzero_value();
                cell.accessed = true;
                cell.written = true;
            }
            _ => unreachable!(),
        }

        let mut allocator = tx_allocator();
        let cloned = object
            .clone_for_tx(&mut load_recorder(), &mut allocator)
            .unwrap();
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
        // The committed array holds no record: the store keeps them.
        assert!(object.holds_no_sealed_record());
        let original_slots = object
            .sealed_storage_for_test()
            .unwrap()
            .1
            .into_boxed_slice();

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
        let cloned = object
            .clone_for_tx(&mut load_recorder(), &mut allocator)
            .unwrap();
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
        // The committed map holds no record: the store keeps them.
        assert!(object.holds_no_sealed_record());
        let original_slots = object
            .sealed_storage_for_test()
            .unwrap()
            .1
            .into_boxed_slice();

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
        let cloned = object
            .clone_for_tx(&mut load_recorder(), &mut allocator)
            .unwrap();
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
    fn uo_cell_commit_keeps_the_loaded_value_on_abort() {
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
        let mut new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
        shadow_allocator.finish().unwrap();
        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        new.set_cell(
            Value::Struct(
                vec![
                    ("flag".into(), Value::Bool(true)),
                    (
                        "items".into(),
                        Value::Array(vec![Value::uint(21), Value::uint(34)].into_boxed_slice()),
                    ),
                ]
                .into_boxed_slice(),
            ),
            None,
            &mut recorder,
        )
        .unwrap();
        // The first write keeps the value the call loaded.
        match &new {
            RuntimeObject::UoCell(cell) => assert_eq!(cell.loaded_value, Some(zero.clone())),
            _ => unreachable!(),
        }
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, true, true, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        // The aborted call reseals the loaded value and keeps no copy.
        assert_eq!(recorder.physical_write_count(), 1);
        match committed {
            RuntimeObject::UoCell(cell) => {
                assert_eq!(cell.value, zero);
                assert_eq!(cell.loaded_value, None);
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
        let new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
        shadow_allocator.finish().unwrap();
        let physical_ptr = match &new {
            RuntimeObject::UoCell(cell) => cell.physical.as_ptr(),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, false, &mut recorder, &mut commit_allocator)
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
    fn exact_objects_are_resealed_exactly_when_the_call_may_write_them() {
        // The decision is the program's: whether it has a write statement for
        // the object. Whether the call touched the object, and whether it
        // aborted, do not change it.
        fn sealed(object: &RuntimeObject) -> Vec<Vec<u8>> {
            let (_, records) = object.sealed_storage_for_test().unwrap();
            records.iter().map(|record| record.to_vec()).collect()
        }
        fn mark_accessed(object: &mut RuntimeObject) {
            match object {
                RuntimeObject::UoCell(cell) => cell.accessed = true,
                RuntimeObject::UoArray(array) => array.accessed = true,
                RuntimeObject::UoSmallMap(map) => map.accessed = true,
                _ => unreachable!(),
            }
        }
        for (spec, seed) in [
            (cell_spec(), 0xE001u64),
            (array_spec(), 0xE002),
            (small_map_spec(), 0xE003),
        ] {
            let old = RuntimeObject::instantiate_with_seed(&spec, seed).unwrap();
            let stored = sealed(&old);
            let slots = stored.len();
            for (accessed, aborted, may_write) in [
                (true, false, false),
                (false, false, false),
                (true, true, false),
                (true, false, true),
                (false, false, true),
                (true, true, true),
            ] {
                let mut shadow_allocator = tx_allocator();
                let mut new = old
                    .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
                    .unwrap();
                shadow_allocator.finish().unwrap();
                if accessed {
                    mark_accessed(&mut new);
                }
                let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
                let mut commit_allocator = tx_allocator();
                let committed = new
                    .commit(
                        &old,
                        aborted,
                        may_write,
                        &mut recorder,
                        &mut commit_allocator,
                    )
                    .unwrap();
                commit_allocator.finish().unwrap();
                let case = format!(
                    "{} accessed={accessed} aborted={aborted} may_write={may_write}",
                    spec.name
                );
                if may_write {
                    // Every slot is sealed again, under a later nonce.
                    assert_eq!(recorder.physical_write_count(), slots, "{case}");
                    let resealed = sealed(&committed);
                    assert_eq!(resealed.len(), slots, "{case}");
                    assert!(
                        resealed.iter().zip(&stored).all(|(new, old)| new != old),
                        "{case}"
                    );
                } else {
                    // No write, and storage is as it was.
                    assert_eq!(recorder.physical_write_count(), 0, "{case}");
                    assert_eq!(sealed(&committed), stored, "{case}");
                }
                assert!(!committed.holds_no_sealed_record(), "{case}");
                let committed = committed.into_cold_committed().unwrap();
                assert!(committed.committed_cache_is_cold(), "{case}");
            }
        }
    }

    #[test]
    fn a_sealed_write_that_repeats_a_nonce_is_still_an_update() {
        // A sealed write is an Update in every unit the observer classifies,
        // and the runtime checks that on the bytes. The record's markers
        // make it certain: a record carries the marker that the record it
        // replaces does not. Here the seal count of an object is set back,
        // as a rollback of the enclave's state would set it, so that the
        // next write repeats the nonce of the last one and, for the same
        // value, its ciphertext. The record still differs from the one it
        // replaces, in the marker of each unit, and the write passes.
        fn written(
            object: &RuntimeObject,
            recorder: &mut crate::controller::CallRecorder,
        ) -> anyhow::Result<RuntimeObject> {
            let mut allocator = tx_allocator();
            let mut tx = object.clone_for_tx(&mut load_recorder(), &mut allocator)?;
            match &tx {
                RuntimeObject::UoCell(_) => tx.set_cell(nested_nonzero_value(), None, recorder)?,
                RuntimeObject::UoSmallMap(_) => {
                    let key = Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0xE1; 20])),
                            ("nonce".into(), Value::uint(3)),
                        ]
                        .into_boxed_slice(),
                    );
                    tx.put_map(key, nested_nonzero_value(), None, recorder, &mut allocator)?;
                }
                _ => unreachable!(),
            }
            let committed = tx.commit(object, false, true, recorder, &mut allocator)?;
            allocator.finish()?;
            Ok(committed)
        }
        fn cipher_of(object: &RuntimeObject) -> uo_store::StoreCipher {
            match object {
                RuntimeObject::UoCell(cell) => cell.cipher.clone_for_runtime_state(),
                RuntimeObject::UoSmallMap(map) => map.cipher.clone_for_runtime_state(),
                _ => unreachable!(),
            }
        }
        fn set_cipher(object: &mut RuntimeObject, cipher: uo_store::StoreCipher) {
            match object {
                RuntimeObject::UoCell(cell) => cell.cipher = cipher,
                RuntimeObject::UoSmallMap(map) => map.cipher = cipher,
                _ => unreachable!(),
            }
        }
        fn records(object: &RuntimeObject) -> Vec<Vec<u8>> {
            let (_, records) = object.sealed_storage_for_test().unwrap();
            records.iter().map(|record| record.to_vec()).collect()
        }
        for (spec, seed) in [(cell_spec(), 0xF201u64), (small_map_spec(), 0xF202)] {
            let deployed = RuntimeObject::instantiate_with_seed(&spec, seed).unwrap();
            let mut recorder = crate::controller::CallRecorder::begin("first_write", &[]);
            let first = written(&deployed, &mut recorder).unwrap();
            let first_records = records(&first);
            let slots = first_records.len();
            assert_eq!(recorder.physical_write_count(), slots, "{}", spec.name);

            // A twin of the deployment has the object's key and a seal count
            // that stands where the object's stood before its first write.
            let twin = RuntimeObject::instantiate_with_seed(&spec, seed).unwrap();
            let mut rolled_back = first;
            let mut cipher = cipher_of(&twin);
            cipher.attach_storage(cipher_of(&rolled_back).storage().unwrap().clone());
            set_cipher(&mut rolled_back, cipher);
            let mut recorder = crate::controller::CallRecorder::begin("repeated_nonce", &[]);
            let second = written(&rolled_back, &mut recorder).unwrap();
            assert_eq!(recorder.physical_write_count(), slots, "{}", spec.name);
            for (old, new) in first_records.iter().zip(records(&second)) {
                assert!(uo_core::is_update_write(old, &new), "{}", spec.name);
                for (old_unit, new_unit) in old.chunks_exact(32).zip(new.chunks_exact(32)) {
                    // The same nonce and value: the units differ in their
                    // marker and in nothing else.
                    assert_ne!(old_unit[0], new_unit[0], "{}", spec.name);
                    assert_eq!(old_unit[1..], new_unit[1..], "{}", spec.name);
                }
            }
        }
    }

    #[test]
    fn uo_cell_commit_reuses_ciphertext_buffer_when_written() {
        let spec = cell_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xC013).unwrap();

        let mut shadow_allocator = tx_allocator();
        let mut new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
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
            .commit(&old, false, true, &mut recorder, &mut commit_allocator)
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
    fn uo_array_commit_leaves_an_unwritten_array_as_loaded() {
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
        let new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
        shadow_allocator.finish().unwrap();
        let (values_ptr, physical_slots_ptr) = match &new {
            RuntimeObject::UoArray(array) => (array.values.as_ptr(), array.physical_slots.as_ptr()),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, false, &mut recorder, &mut commit_allocator)
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
        let mut new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
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
            .commit(&old, false, true, &mut recorder, &mut commit_allocator)
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
    fn uo_small_map_commit_keeps_the_loaded_entries_on_abort() {
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
        let mut new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
        shadow_allocator.finish().unwrap();
        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut put_allocator = tx_allocator();
        let overflowed = new
            .put_map(
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
                            Value::Array(vec![Value::uint(15), Value::uint(16)].into_boxed_slice()),
                        ),
                    ]
                    .into_boxed_slice(),
                ),
                None,
                &mut recorder,
                &mut put_allocator,
            )
            .unwrap();
        put_allocator.finish().unwrap();
        assert!(!overflowed);
        let (entries_ptr, physical_slots_ptr) = match &new {
            RuntimeObject::UoSmallMap(map) => {
                // The write took effect on the opened entries, and the first
                // write kept the entries the call loaded.
                assert!(map.entries[0].is_occupied());
                assert!(map.loaded_entries.is_some());
                (map.entries.as_ptr(), map.physical_slots.as_ptr())
            }
            _ => unreachable!(),
        };

        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, true, true, &mut recorder, &mut commit_allocator)
            .unwrap();
        commit_allocator.finish().unwrap();

        // The aborted call reseals every slot with the loaded entries.
        assert_eq!(recorder.physical_write_count(), 2);
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
                assert!(map.loaded_entries.is_none());
                assert!(!map.accessed);
                assert!(!map.dirty);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn an_exact_object_is_read_once_when_the_call_loads_it() {
        // The load reads every sealed slot and traces it. The call's
        // accesses work on the opened copy: each keeps its logical event and
        // reads nothing more.
        // A cell: one record.
        let spec = cell_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xF001).unwrap();
        let mut recorder = crate::controller::CallRecorder::begin("load_test", &[]);
        let mut allocator = tx_allocator();
        let mut cell = old.clone_for_tx(&mut recorder, &mut allocator).unwrap();
        assert_eq!(recorder.metrics().physical_reads, 1);
        cell.get_cell(&mut recorder).unwrap();
        cell.set_cell(nested_nonzero_value(), None, &mut recorder)
            .unwrap();
        cell.get_cell(&mut recorder).unwrap();
        assert_eq!(recorder.metrics().physical_reads, 1);
        assert_eq!(recorder.metrics().logical_reads, 2);
        assert_eq!(recorder.metrics().logical_writes, 1);
        assert_eq!(recorder.physical_read_locations(), ["nested_cell"]);

        // An array: one record per slot, in slot order.
        let spec = array_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xF002).unwrap();
        let mut recorder = crate::controller::CallRecorder::begin("load_test", &[]);
        let mut array = old.clone_for_tx(&mut recorder, &mut allocator).unwrap();
        assert_eq!(recorder.metrics().physical_reads, 3);
        array.get_array(1, &mut recorder).unwrap();
        array
            .set_array(
                2,
                Value::zero_for_type(&spec.value_type),
                None,
                &mut recorder,
            )
            .unwrap();
        array.get_array(0, &mut recorder).unwrap();
        assert_eq!(recorder.metrics().physical_reads, 3);
        assert_eq!(recorder.metrics().logical_reads, 2);
        assert_eq!(recorder.metrics().logical_writes, 1);
        assert_eq!(
            recorder.physical_read_locations(),
            ["nested_array[0]", "nested_array[1]", "nested_array[2]"]
        );

        // A full-scan map: one record per slot, in slot order. Each access
        // scans the two opened entries.
        let spec = small_map_spec();
        let key = Value::zero_for_type(spec.key_type.as_ref().unwrap());
        let old = RuntimeObject::instantiate_with_seed(&spec, 0xF003).unwrap();
        let mut recorder = crate::controller::CallRecorder::begin("load_test", &[]);
        let mut map = old.clone_for_tx(&mut recorder, &mut allocator).unwrap();
        assert_eq!(recorder.metrics().physical_reads, 2);
        map.get_map(&key, &mut recorder, &mut allocator).unwrap();
        map.put_map(
            key.clone(),
            nested_nonzero_value(),
            None,
            &mut recorder,
            &mut allocator,
        )
        .unwrap();
        map.get_map(&key, &mut recorder, &mut allocator).unwrap();
        assert_eq!(recorder.metrics().physical_reads, 2);
        assert_eq!(recorder.metrics().logical_reads, 3 * 2);
        assert_eq!(recorder.metrics().logical_writes, 1);
        assert_eq!(
            recorder.physical_read_locations(),
            ["nested_map#0", "nested_map#1"]
        );
        allocator.finish().unwrap();
    }

    #[test]
    fn commit_opens_no_sealed_record() {
        // Commit reads no storage. A call that only reads an exact object
        // commits it with no resource event at all, and a call that aborts
        // after a write logs what a call that commits logs: the seals.
        fn write(object: &mut RuntimeObject, spec: &StateObject, allocator: &mut AllocatorSession) {
            let mut recorder = crate::controller::CallRecorder::begin("write_test", &[]);
            match object {
                RuntimeObject::UoCell(_) => object
                    .set_cell(nested_nonzero_value(), None, &mut recorder)
                    .unwrap(),
                RuntimeObject::UoArray(_) => object
                    .set_array(
                        1,
                        Value::Struct(
                            vec![
                                ("owner".into(), Value::Address([0xD1; 20])),
                                ("count".into(), Value::uint(41)),
                            ]
                            .into_boxed_slice(),
                        ),
                        None,
                        &mut recorder,
                    )
                    .unwrap(),
                RuntimeObject::UoSmallMap(_) => {
                    let key = Value::Struct(
                        vec![
                            ("owner".into(), Value::Address([0xD2; 20])),
                            ("nonce".into(), Value::uint(7)),
                        ]
                        .into_boxed_slice(),
                    );
                    let overflowed = object
                        .put_map(key, nested_nonzero_value(), None, &mut recorder, allocator)
                        .unwrap();
                    assert!(!overflowed);
                }
                _ => unreachable!(),
            }
            let _ = spec;
        }
        for (spec, seed) in [
            (cell_spec(), 0xF101u64),
            (array_spec(), 0xF102),
            (small_map_spec(), 0xF103),
        ] {
            let old = RuntimeObject::instantiate_with_seed(&spec, seed).unwrap();
            let slots = old.sealed_storage_for_test().unwrap().1.len();
            let mut commit_events = Vec::new();
            for (aborted, may_write) in [(false, false), (true, false), (false, true), (true, true)]
            {
                let mut shadow_allocator = tx_allocator();
                let mut new = old
                    .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
                    .unwrap();
                if may_write {
                    write(&mut new, &spec, &mut shadow_allocator);
                }
                shadow_allocator.finish().unwrap();
                let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
                let mut commit_allocator = tx_allocator();
                let committed = new
                    .commit(
                        &old,
                        aborted,
                        may_write,
                        &mut recorder,
                        &mut commit_allocator,
                    )
                    .unwrap();
                let events = commit_allocator
                    .finish()
                    .unwrap()
                    .resource_events()
                    .event_count();
                let case = format!("{} aborted={aborted} may_write={may_write}", spec.name);
                assert_eq!(recorder.metrics().physical_reads, 0, "{case}");
                if may_write {
                    // One reservation of scratch, wiped, for each seal.
                    assert_eq!(events, 2 * slots, "{case}");
                } else {
                    assert_eq!(events, 0, "{case}");
                }
                // An aborted call commits the contents it loaded.
                if aborted || !may_write {
                    let mut reload_allocator = tx_allocator();
                    let reloaded_old = old
                        .clone_for_tx(&mut load_recorder(), &mut reload_allocator)
                        .unwrap();
                    let reloaded_new = committed
                        .clone_for_tx(&mut load_recorder(), &mut reload_allocator)
                        .unwrap();
                    reload_allocator.finish().unwrap();
                    match (&reloaded_old, &reloaded_new) {
                        (RuntimeObject::UoCell(old), RuntimeObject::UoCell(new)) => {
                            assert_eq!(old.value, new.value, "{case}")
                        }
                        (RuntimeObject::UoArray(old), RuntimeObject::UoArray(new)) => {
                            assert_eq!(old.values, new.values, "{case}")
                        }
                        (RuntimeObject::UoSmallMap(old), RuntimeObject::UoSmallMap(new)) => {
                            assert_eq!(old.entries, new.entries, "{case}")
                        }
                        _ => unreachable!(),
                    }
                }
                commit_events.push(events);
            }
            // Abort and commit do the same work on a written object.
            assert_eq!(commit_events[2], commit_events[3], "{}", spec.name);
        }
    }

    #[test]
    fn uo_small_map_commit_reuses_written_slot_buffers() {
        let spec = small_map_spec();
        let old = RuntimeObject::instantiate_with_seed(&spec, 0x5C02).unwrap();

        let mut shadow_allocator = tx_allocator();
        let mut new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
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
            .commit(&old, false, true, &mut recorder, &mut commit_allocator)
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
        let new = old
            .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
            .unwrap();
        shadow_allocator.finish().unwrap();
        let (entries_ptr, position_map_ptr, stash_ptr) = match &new {
            RuntimeObject::UoOramMap(map) => map.oram.logical_state_ptrs_for_test(),
            _ => unreachable!(),
        };

        let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
        let mut commit_allocator = tx_allocator();
        let committed = new
            .commit(&old, false, false, &mut recorder, &mut commit_allocator)
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
    fn uo_path_oram_commit_masks_pending_writes_on_abort() {
        // A Path ORAM write reaches the ORAM only at commit. An aborted call
        // masks it off there but still makes its access, so the contents stay
        // as before the call while the path is rewritten as on a commit.
        let spec = path_oram_spec();
        let key = Value::Address([0x77; 20]);
        let written_entry = || MapEntry::new(true, Value::Address([0x77; 20]), Value::uint(23));
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
        let expected_entries = match &old {
            RuntimeObject::UoOramMap(map) => map.oram.stored_entries_for_test(&spec),
            _ => unreachable!(),
        };

        for aborted in [true, false] {
            let mut shadow_allocator = tx_allocator();
            let mut new = old
                .clone_for_tx(&mut load_recorder(), &mut shadow_allocator)
                .unwrap();
            shadow_allocator.finish().unwrap();
            let mut recorder = crate::controller::CallRecorder::begin("commit_test", &[]);
            let mut allocator = tx_allocator();
            let overflowed = new
                .put_map(
                    key.clone(),
                    Value::uint(23),
                    Some(true),
                    &mut recorder,
                    &mut allocator,
                )
                .unwrap();
            assert!(!overflowed);
            // The write is pending: it makes no access, and a read later in
            // the call sees it through the call's pending writes.
            assert_eq!(recorder.physical_write_count(), 0);
            let (read, _) = new.get_map(&key, &mut recorder, &mut allocator).unwrap();
            assert_eq!(read, Value::uint(23));
            allocator.finish().unwrap();
            let writes_before_commit = recorder.physical_write_count();

            let mut commit_allocator = tx_allocator();
            let committed = new
                .commit(&old, aborted, true, &mut recorder, &mut commit_allocator)
                .unwrap();
            commit_allocator.finish().unwrap();
            assert!(recorder.physical_write_count() > writes_before_commit);
            match committed {
                RuntimeObject::UoOramMap(map) => {
                    let entries = map.oram.stored_entries_for_test(&spec);
                    let written = entries.iter().any(|entry| *entry == written_entry());
                    assert_eq!(written, !aborted);
                    if aborted {
                        assert_eq!(entries, expected_entries);
                    }
                    assert!(map.pending_view.is_none());
                    assert!(map.pending_puts.is_empty());
                    assert!(!map.accessed);
                    assert!(!map.dirty);
                }
                _ => unreachable!(),
            }
        }
    }
}
