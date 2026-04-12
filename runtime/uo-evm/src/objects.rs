use crate::oram::{map_record_bytes, MapEntry, OramState, OramTranscript};
use anyhow::{anyhow, bail, Result};
use rand::SeedableRng;
use rand_chacha::ChaCha20Rng;
use std::collections::{BTreeMap, BTreeSet};
use uo_core::ir::{BackendKind, ContainerKind, StateObject};
use uo_core::trace::{classify_write, LogicalEvent, PhysicalReadEvent, PhysicalWriteEvent};
use uo_core::Value;
use uo_store::{StoreCipher, StoreExecutionMetrics};

#[derive(Clone, Debug)]
pub(crate) struct ObjectCommit {
    pub next: RuntimeObject,
    pub logical_accesses: Vec<LogicalEvent>,
    pub logical_writes: Vec<LogicalEvent>,
    pub physical_reads: Vec<PhysicalReadEvent>,
    pub physical_writes: Vec<PhysicalWriteEvent>,
    pub metrics: StoreExecutionMetrics,
}

#[derive(Clone, Debug, Default)]
struct Tape {
    logical_accesses: Vec<LogicalEvent>,
    logical_writes: Vec<LogicalEvent>,
    physical_reads: Vec<PhysicalReadEvent>,
    metrics: StoreExecutionMetrics,
}

impl Tape {
    fn read(&mut self, kind: &str, object: &str, detail: impl Into<String>) {
        self.metrics.logical_reads += 1;
        self.logical_accesses.push(LogicalEvent {
            kind: kind.into(),
            object: object.into(),
            detail: detail.into(),
        });
    }

    fn write(&mut self, kind: &str, object: &str, detail: impl Into<String>) {
        self.metrics.logical_writes += 1;
        self.logical_writes.push(LogicalEvent {
            kind: kind.into(),
            object: object.into(),
            detail: detail.into(),
        });
    }

    fn physical_read(&mut self, object: &str, location: impl Into<String>, len: usize) {
        self.metrics.physical_reads += 1;
        self.physical_reads.push(PhysicalReadEvent {
            object: object.into(),
            location: location.into(),
            len,
        });
    }

    fn record_oram(&mut self, transcript: OramTranscript) {
        let _ = transcript.schedule;
        self.metrics.logical_reads += transcript.logical_accesses.len();
        self.metrics.physical_reads += transcript.physical_reads.len();
        self.logical_accesses.extend(transcript.logical_accesses);
        self.physical_reads.extend(transcript.physical_reads);
    }
}

#[derive(Clone, Debug)]
pub(crate) struct CellObject {
    spec: StateObject,
    value: Value,
    physical: Vec<u8>,
    cipher: StoreCipher,
    accessed: bool,
    written: bool,
    tape: Tape,
    rng: ChaCha20Rng,
}

impl CellObject {
    fn reset_tape(&mut self) {
        self.accessed = false;
        self.written = false;
        self.tape = Tape::default();
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
    tape: Tape,
    rng: ChaCha20Rng,
}

impl ArrayObject {
    fn reset_tape(&mut self) {
        self.accessed = false;
        self.written_indices.clear();
        self.tape = Tape::default();
    }
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
    tape: Tape,
}

impl RawMapObject {
    fn reset_tape(&mut self) {
        self.staged.clear();
        self.tape = Tape::default();
    }
}

#[derive(Clone, Debug)]
pub(crate) struct SmallMapObject {
    spec: StateObject,
    entries: Vec<MapEntry>,
    physical_slots: Vec<Vec<u8>>,
    cipher: StoreCipher,
    accessed: bool,
    dirty: bool,
    tape: Tape,
    rng: ChaCha20Rng,
}

impl SmallMapObject {
    fn reset_tape(&mut self) {
        self.accessed = false;
        self.dirty = false;
        self.tape = Tape::default();
    }
}

#[derive(Clone, Debug)]
pub(crate) struct OramMapObject {
    spec: StateObject,
    oram: OramState,
    accessed: bool,
    dirty: bool,
    tape: Tape,
    rng: ChaCha20Rng,
}

impl OramMapObject {
    fn reset_tape(&mut self) {
        self.accessed = false;
        self.dirty = false;
        self.tape = Tape::default();
    }
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
    pub fn instantiate(spec: &StateObject) -> Result<Self> {
        let seed = 0xC0DE_u64 ^ (spec.id as u64) ^ ((spec.name.len() as u64) << 16);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        match (&spec.kind, &spec.backend) {
            (ContainerKind::Cell, BackendKind::Raw) => {
                let logical = Value::zero_for_type(&spec.value_type);
                Ok(Self::RawCell(CellObject {
                    spec: spec.clone(),
                    physical: raw_encode(&logical),
                    value: logical,
                    cipher: StoreCipher::random(),
                    accessed: false,
                    written: false,
                    tape: Tape::default(),
                    rng,
                }))
            }
            (ContainerKind::Cell, _) => {
                let logical = Value::zero_for_type(&spec.value_type);
                let payload = logical.canonical_bytes();
                let cipher = StoreCipher::random();
                let aad = cell_slot_aad(&spec.name);
                Ok(Self::UoCell(CellObject {
                    spec: spec.clone(),
                    physical: cipher.filler(aad.as_bytes(), payload.len().max(1), &mut rng),
                    value: logical,
                    cipher,
                    accessed: false,
                    written: false,
                    tape: Tape::default(),
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
                    cipher: StoreCipher::random(),
                    accessed: false,
                    written_indices: BTreeSet::new(),
                    tape: Tape::default(),
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
                let cipher = StoreCipher::random();
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
                    tape: Tape::default(),
                    rng,
                }))
            }
            (ContainerKind::Map, BackendKind::Raw) => Ok(Self::RawMap(RawMapObject {
                spec: spec.clone(),
                entries: BTreeMap::new(),
                staged: BTreeMap::new(),
                tape: Tape::default(),
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
                let cipher = StoreCipher::random();
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
                    tape: Tape::default(),
                    rng,
                }))
            }
            (ContainerKind::Map, BackendKind::Oram) => Ok(Self::UoOramMap(OramMapObject {
                spec: spec.clone(),
                oram: OramState::instantiate(spec, &mut rng)?,
                accessed: false,
                dirty: false,
                tape: Tape::default(),
                rng,
            })),
        }
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

    pub fn get_cell(&mut self) -> Result<Value> {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                object.accessed = true;
                object.tape.read("cell_get", &object.spec.name, "");
                object.tape.physical_read(
                    &object.spec.name,
                    object.spec.name.clone(),
                    object.physical.len(),
                );
                Ok(object.value.clone())
            }
            _ => bail!("{} is not a cell", self.name()),
        }
    }

    pub fn set_cell(&mut self, value: Value, predicate: Option<bool>) -> Result<()> {
        let apply = predicate.unwrap_or(true);
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                object.accessed = true;
                object.tape.write("cell_set", &object.spec.name, "slot");
                object.tape.physical_read(
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

    pub fn get_array(&mut self, index: usize) -> Result<Value> {
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
                object
                    .tape
                    .read("array_get", &object.spec.name, format!("[{index}]"));
                object.tape.physical_read(
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
                object
                    .tape
                    .read("array_get", &object.spec.name, format!("[{index}]"));
                record_array_scan(object);
                Ok(value)
            }
            _ => bail!("{} is not an array", self.name()),
        }
    }

    pub fn set_array(&mut self, index: usize, value: Value, predicate: Option<bool>) -> Result<()> {
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
                object
                    .tape
                    .write("array_set", &object.spec.name, format!("[{index}]"));
                object.tape.physical_read(
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
                object
                    .tape
                    .write("array_set", &object.spec.name, format!("[{index}]"));
                record_array_scan(object);
                if apply {
                    object.values[index] = value;
                    object.written_indices.insert(index);
                }
                Ok(())
            }
            _ => bail!("{} is not an array", self.name()),
        }
    }

    pub fn get_map(&mut self, key: &Value) -> Result<Value> {
        match self {
            Self::RawMap(object) => {
                let key_name = key.canonical_key();
                object
                    .tape
                    .read("raw_map_get", &object.spec.name, key_name.clone());
                object.tape.physical_read(
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
                    object
                        .tape
                        .read("uomap_scan", &object.spec.name, format!("slot:{index}"));
                    object.tape.physical_read(
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
                let (value, transcript) = object.oram.get(&object.spec, key)?;
                object.tape.record_oram(transcript);
                Ok(value)
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    pub fn put_map(&mut self, key: Value, value: Value, predicate: Option<bool>) -> Result<()> {
        let apply = predicate.unwrap_or(true);
        match self {
            Self::RawMap(object) => {
                let key_name = key.canonical_key();
                object
                    .tape
                    .write("raw_map_put", &object.spec.name, key_name.clone());
                if apply {
                    object.staged.insert(key_name, (key, value));
                }
                Ok(())
            }
            Self::UoSmallMap(object) => {
                object.accessed = true;
                for index in 0..object.entries.len() {
                    object
                        .tape
                        .read("uomap_scan", &object.spec.name, format!("slot:{index}"));
                    object.tape.physical_read(
                        &object.spec.name,
                        format!("{}#{index}", object.spec.name),
                        object.physical_slots[index].len(),
                    );
                }
                object
                    .tape
                    .write("uomap_put", &object.spec.name, "oblivious");
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
                let transcript = object.oram.put(&object.spec, key, value, apply)?;
                object.tape.record_oram(transcript);
                object
                    .tape
                    .write("uooram_put", &object.spec.name, "oblivious");
                if apply {
                    object.dirty = true;
                }
                Ok(())
            }
            _ => bail!("{} is not a map", self.name()),
        }
    }

    pub fn commit(self, old: &Self, aborted: bool) -> Result<ObjectCommit> {
        match (self, old) {
            (Self::RawCell(mut new), Self::RawCell(old)) => {
                let mut physical_writes = Vec::new();
                let mut next = old.clone();
                if !aborted && new.written {
                    let old_physical = old.physical.clone();
                    let new_physical = raw_encode(&new.value);
                    physical_writes.push(PhysicalWriteEvent {
                        object: new.spec.name.clone(),
                        location: new.spec.name.clone(),
                        class: classify_write(&old_physical, &new_physical),
                        old: old_physical.clone(),
                        new: new_physical.clone(),
                    });
                    next.value = new.value.clone();
                    next.physical = new_physical;
                    next.tape.metrics.physical_writes += 1;
                    if next.physical.iter().all(|byte| *byte == 0) {
                        next.tape.metrics.zero_writes += 1;
                    }
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::RawCell(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            (Self::UoCell(mut new), Self::UoCell(old)) => {
                let mut physical_writes = Vec::new();
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
                    physical_writes.push(PhysicalWriteEvent {
                        object: next.spec.name.clone(),
                        location: next.spec.name.clone(),
                        class: classify_write(&old_physical, &new_physical),
                        old: old_physical,
                        new: new_physical.clone(),
                    });
                    next.physical = new_physical;
                    next.value = committed_value;
                    next.tape.metrics.physical_writes += 1;
                } else {
                    next.value = old.value.clone();
                    next.physical = old.physical.clone();
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::UoCell(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            (Self::RawArray(mut new), Self::RawArray(old)) => {
                let mut physical_writes = Vec::new();
                let mut next = old.clone();
                if !aborted {
                    for index in &new.written_indices {
                        let old_physical = old.physical_slots[*index].clone();
                        let new_physical = raw_encode(&new.values[*index]);
                        physical_writes.push(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}[{index}]", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
                        next.values[*index] = new.values[*index].clone();
                        next.physical_slots[*index] = new_physical;
                        next.tape.metrics.physical_writes += 1;
                    }
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::RawArray(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            (Self::UoArray(mut new), Self::UoArray(old)) => {
                let mut physical_writes = Vec::new();
                let mut next = new.clone();
                let source_values = if aborted { &old.values } else { &new.values };
                if new.accessed {
                    for (index, value) in source_values.iter().enumerate() {
                        let old_physical = old.physical_slots[index].clone();
                        let aad = array_slot_aad(&new.spec.name, index);
                        let new_physical = next
                            .cipher
                            .seal(aad.as_bytes(), &value.canonical_bytes(), &mut next.rng);
                        physical_writes.push(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}[{index}]", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
                        next.physical_slots[index] = new_physical;
                        next.values[index] = value.clone();
                        next.tape.metrics.physical_writes += 1;
                    }
                } else {
                    next.values = old.values.clone();
                    next.physical_slots = old.physical_slots.clone();
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::UoArray(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            (Self::RawMap(mut new), Self::RawMap(old)) => {
                let mut physical_writes = Vec::new();
                let mut next = old.clone();
                if !aborted {
                    for (key_name, (_key, value)) in &new.staged {
                        let old_entry = old.entries.get(key_name);
                        let old_physical = old_entry
                            .map(|entry| entry.physical.clone())
                            .unwrap_or_else(|| vec![0u8; 32]);
                        let new_physical = raw_encode(value);
                        physical_writes.push(PhysicalWriteEvent {
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
                        next.tape.metrics.physical_writes += 1;
                    }
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::RawMap(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            (Self::UoSmallMap(mut new), Self::UoSmallMap(old)) => {
                let mut physical_writes = Vec::new();
                let mut next = new.clone();
                let source_entries = if aborted { &old.entries } else { &new.entries };
                if new.accessed {
                    for (index, entry) in source_entries.iter().enumerate() {
                        let old_physical = old.physical_slots[index].clone();
                        let aad = small_map_slot_aad(&new.spec.name, index);
                        let new_physical = next
                            .cipher
                            .seal(aad.as_bytes(), &map_record_bytes(entry), &mut next.rng);
                        physical_writes.push(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: format!("{}#{index}", new.spec.name),
                            class: classify_write(&old_physical, &new_physical),
                            old: old_physical,
                            new: new_physical.clone(),
                        });
                        next.entries[index] = entry.clone();
                        next.physical_slots[index] = new_physical;
                        next.tape.metrics.physical_writes += 1;
                    }
                } else {
                    next.entries = old.entries.clone();
                    next.physical_slots = old.physical_slots.clone();
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::UoSmallMap(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            (Self::UoOramMap(mut new), Self::UoOramMap(old)) => {
                let mut physical_writes = Vec::new();
                let mut next = new.clone();
                if new.accessed {
                    let commit = new
                        .oram
                        .commit(&new.spec, &old.oram, aborted, &mut next.rng)?;
                    for write in commit.writes {
                        physical_writes.push(PhysicalWriteEvent {
                            object: new.spec.name.clone(),
                            location: write.location,
                            class: classify_write(&write.old, &write.new),
                            old: write.old,
                            new: write.new,
                        });
                        next.tape.metrics.physical_writes += 1;
                    }
                    next.oram = commit.next;
                } else {
                    next.oram = old.oram.clone();
                }
                next.reset_tape();
                Ok(ObjectCommit {
                    next: Self::UoOramMap(next),
                    logical_accesses: std::mem::take(&mut new.tape.logical_accesses),
                    logical_writes: std::mem::take(&mut new.tape.logical_writes),
                    physical_reads: std::mem::take(&mut new.tape.physical_reads),
                    physical_writes,
                    metrics: new.tape.metrics,
                })
            }
            _ => bail!("mismatched object kinds during commit"),
        }
    }

    fn clear_transient(&mut self) {
        match self {
            Self::RawCell(object) | Self::UoCell(object) => {
                object.accessed = false;
                object.written = false;
                object.tape = Tape::default();
            }
            Self::RawArray(object) | Self::UoArray(object) => {
                object.accessed = false;
                object.written_indices.clear();
                object.tape = Tape::default();
            }
            Self::RawMap(object) => {
                object.staged.clear();
                object.tape = Tape::default();
            }
            Self::UoSmallMap(object) => {
                object.accessed = false;
                object.dirty = false;
                object.tape = Tape::default();
            }
            Self::UoOramMap(object) => {
                object.accessed = false;
                object.dirty = false;
                object.tape = Tape::default();
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

fn record_array_scan(object: &mut ArrayObject) {
    for index in 0..object.physical_slots.len() {
        object.tape.physical_read(
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
