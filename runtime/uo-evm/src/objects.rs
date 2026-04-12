use crate::controller::CallRecorder;
use crate::oram::{map_record_bytes, MapEntry, OramState};
use anyhow::{anyhow, bail, Result};
use rand::rngs::OsRng;
use rand::{RngCore, SeedableRng};
use rand_chacha::ChaCha20Rng;
use std::collections::{BTreeMap, BTreeSet};
use uo_core::ir::{BackendKind, ContainerKind, StateObject};
use uo_core::manifest::PATH_ORAM_SCHEME;
use uo_core::trace::{classify_write, PhysicalWriteEvent};
use uo_core::Value;
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

#[derive(Clone, Debug)]
struct RawMapEntry {
    value: Value,
    physical: Vec<u8>,
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

#[derive(Clone, Debug)]
pub(crate) struct OramMapObject {
    spec: StateObject,
    oram: OramState,
    accessed: bool,
    dirty: bool,
    rng: ChaCha20Rng,
}

#[derive(Clone, Debug)]
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
                let payload = logical.canonical_bytes();
                let cipher = StoreCipher::from_rng(&mut rng);
                let aad = cell_slot_aad(&spec.name);
                Ok(Self::UoCell(CellObject {
                    spec: spec.clone(),
                    physical: cipher.filler(aad.as_bytes(), payload.len().max(1), &mut rng),
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
                let values = vec![Value::zero_for_type(&spec.value_type); capacity];
                let logical_len = Value::zero_for_type(&spec.value_type)
                    .canonical_bytes()
                    .len()
                    .max(1);
                let cipher = StoreCipher::from_rng(&mut rng);
                let physical_slots = (0..capacity)
                    .map(|index| {
                        let aad = array_slot_aad(&spec.name, index);
                        cipher.filler(aad.as_bytes(), logical_len, &mut rng)
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
                let logical_len = map_record_bytes(&entries[0]).len().max(1);
                let cipher = StoreCipher::from_rng(&mut rng);
                let physical_slots = (0..capacity)
                    .map(|index| {
                        let aad = small_map_slot_aad(&spec.name, index);
                        cipher.filler(aad.as_bytes(), logical_len, &mut rng)
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
                rng,
            })),
        }
    }

    pub fn instantiate(spec: &StateObject) -> Result<Self> {
        let mut seed = [0u8; 32];
        OsRng.fill_bytes(&mut seed);
        let mut master_rng = ChaCha20Rng::from_seed(seed);
        Self::instantiate_from_rng(spec, &mut master_rng)
    }

    pub fn instantiate_with_seed(spec: &StateObject, seed: u64) -> Result<Self> {
        let mut master_rng = ChaCha20Rng::seed_from_u64(seed);
        Self::instantiate_from_rng(spec, &mut master_rng)
    }

    pub fn clone_for_tx(&self) -> Self {
        let mut cloned = self.clone();
        cloned.clear_transient();
        if let Self::UoOramMap(object) = &mut cloned {
            object
                .oram
                .refresh_from_storage(&object.spec)
                .expect("valid ORAM control metadata");
        }
        cloned
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

    pub fn get_cell(&mut self, trace: &mut CallRecorder) -> Result<Value> {
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

    pub fn set_cell(
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

    pub fn get_array(&mut self, index: usize, trace: &mut CallRecorder) -> Result<Value> {
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

    pub fn set_array(
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

    pub fn get_map(&mut self, key: &Value, trace: &mut CallRecorder) -> Result<Value> {
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
                let (value, transcript) = object.oram.get(&object.spec, key, &mut object.rng)?;
                if let Some(leaf) = transcript.path_leaf {
                    trace.record_path_oram_leaf_access(
                        object.spec.id,
                        &object.spec.name,
                        object.oram.parameters.bucket_count,
                        leaf,
                    );
                }
                for event in transcript.logical_accesses {
                    trace.logical_read(&event.kind, &event.object, event.detail);
                }
                for event in transcript.physical_reads {
                    trace.physical_read(&event.object, event.location, event.len);
                }
                for write in transcript.physical_writes {
                    trace.physical_write(PhysicalWriteEvent {
                        object: object.spec.name.clone(),
                        location: write.location,
                        class: classify_write(&write.old, &write.new),
                        old: write.old,
                        new: write.new,
                    });
                }
                Ok(value)
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    pub fn put_map(
        &mut self,
        key: Value,
        value: Value,
        predicate: Option<bool>,
        trace: &mut CallRecorder,
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
                let transcript =
                    object
                        .oram
                        .put(&object.spec, key, value, apply, &mut object.rng)?;
                if let Some(leaf) = transcript.path_leaf {
                    trace.record_path_oram_leaf_access(
                        object.spec.id,
                        &object.spec.name,
                        object.oram.parameters.bucket_count,
                        leaf,
                    );
                }
                for event in transcript.logical_accesses {
                    trace.logical_read(&event.kind, &event.object, event.detail);
                }
                for event in transcript.physical_reads {
                    trace.physical_read(&event.object, event.location, event.len);
                }
                for write in transcript.physical_writes {
                    trace.physical_write(PhysicalWriteEvent {
                        object: object.spec.name.clone(),
                        location: write.location,
                        class: classify_write(&write.old, &write.new),
                        old: write.old,
                        new: write.new,
                    });
                }
                trace.logical_write("uooram_put", &object.spec.name, "oblivious");
                if apply {
                    object.dirty = true;
                }
                Ok(())
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    pub fn commit(self, old: &Self, aborted: bool, trace: &mut CallRecorder) -> Result<Self> {
        match (self, old) {
            (Self::RawCell(new), Self::RawCell(old)) => {
                let mut next = old.clone();
                if !aborted && new.written {
                    let old_physical = old.physical.clone();
                    let new_physical = raw_encode(&new.value);
                    trace.physical_write(PhysicalWriteEvent {
                        object: new.spec.name.clone(),
                        location: new.spec.name.clone(),
                        class: classify_write(&old_physical, &new_physical),
                        old: old_physical.clone(),
                        new: new_physical.clone(),
                    });
                    next.value = new.value.clone();
                    next.physical = new_physical;
                }
                next.accessed = false;
                next.written = false;
                Ok(Self::RawCell(next))
            }
            (Self::UoCell(new), Self::UoCell(old)) => {
                let mut next = new.clone();
                let committed_value = if aborted {
                    old.value.clone()
                } else {
                    new.value.clone()
                };
                if new.accessed {
                    let old_physical = old.physical.clone();
                    let aad = cell_slot_aad(&next.spec.name);
                    let new_physical = next
                        .cipher
                        .seal(aad.as_bytes(), &committed_value.canonical_bytes(), &mut next.rng);
                    trace.physical_write(PhysicalWriteEvent {
                        object: next.spec.name.clone(),
                        location: next.spec.name.clone(),
                        class: classify_write(&old_physical, &new_physical),
                        old: old_physical,
                        new: new_physical.clone(),
                    });
                    next.physical = new_physical;
                    next.value = committed_value;
                } else {
                    next.value = old.value.clone();
                    next.physical = old.physical.clone();
                }
                next.accessed = false;
                next.written = false;
                Ok(Self::UoCell(next))
            }
            (Self::RawArray(new), Self::RawArray(old)) => {
                let mut next = old.clone();
                if !aborted {
                    for index in &new.written_indices {
                        let old_physical = old.physical_slots[*index].clone();
                        let new_physical = raw_encode(&new.values[*index]);
                        trace.physical_write(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}[{index}]", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
                        next.values[*index] = new.values[*index].clone();
                        next.physical_slots[*index] = new_physical;
                    }
                }
                next.accessed = false;
                next.written_indices.clear();
                Ok(Self::RawArray(next))
            }
            (Self::UoArray(new), Self::UoArray(old)) => {
                let mut next = new.clone();
                let source_values = if aborted { &old.values } else { &new.values };
                if new.accessed {
                    for (index, value) in source_values.iter().enumerate() {
                        let old_physical = old.physical_slots[index].clone();
                        let aad = array_slot_aad(&new.spec.name, index);
                        let new_physical = next
                            .cipher
                            .seal(aad.as_bytes(), &value.canonical_bytes(), &mut next.rng);
                        trace.physical_write(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}[{index}]", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
                        next.physical_slots[index] = new_physical;
                        next.values[index] = value.clone();
                    }
                } else {
                    next.values = old.values.clone();
                    next.physical_slots = old.physical_slots.clone();
                }
                next.accessed = false;
                next.written_indices.clear();
                Ok(Self::UoArray(next))
            }
            (Self::RawMap(new), Self::RawMap(old)) => {
                let mut next = old.clone();
                if !aborted {
                    for (key_name, (_key, value)) in &new.staged {
                        let old_entry = old.entries.get(key_name);
                        let old_physical = old_entry
                            .map(|entry| entry.physical.clone())
                            .unwrap_or_else(|| vec![0u8; 32]);
                        let new_physical = raw_encode(value);
                        trace.physical_write(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}::{key_name}", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
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
                let mut next = new.clone();
                let source_entries = if aborted { &old.entries } else { &new.entries };
                if new.accessed {
                    for (index, entry) in source_entries.iter().enumerate() {
                        let old_physical = old.physical_slots[index].clone();
                        let aad = small_map_slot_aad(&new.spec.name, index);
                        let new_physical = next
                            .cipher
                            .seal(aad.as_bytes(), &map_record_bytes(entry), &mut next.rng);
                        trace.physical_write(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}#{index}", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
                        next.entries[index] = entry.clone();
                        next.physical_slots[index] = new_physical;
                    }
                } else {
                    next.entries = old.entries.clone();
                    next.physical_slots = old.physical_slots.clone();
                }
                next.accessed = false;
                next.dirty = false;
                Ok(Self::UoSmallMap(next))
            }
            (Self::UoOramMap(new), Self::UoOramMap(old)) => {
                let mut next = new.clone();
                if new.accessed {
                    if new.spec.oram_scheme == PATH_ORAM_SCHEME {
                        next.oram = if aborted {
                            old.oram.clone()
                        } else {
                            new.oram.clone()
                        };
                    } else {
                        let commit = new
                            .oram
                            .commit(&new.spec, &old.oram, aborted, &mut next.rng)?;
                        for write in commit.writes {
                            trace.physical_write(PhysicalWriteEvent {
                                object: new.spec.name.clone(),
                                location: write.location,
                                class: classify_write(&write.old, &write.new),
                                old: write.old,
                                new: write.new,
                            });
                        }
                        next.oram = commit.next;
                    }
                } else {
                    next.oram = old.oram.clone();
                }
                next.accessed = false;
                next.dirty = false;
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
            }
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
