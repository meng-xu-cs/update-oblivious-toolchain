use crate::codec::StoreCipher;
use anyhow::{anyhow, Result};
use rand::SeedableRng;
use rand_chacha::ChaCha20Rng;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uo_core::trace::{classify_write, LogicalEvent, PhysicalWriteEvent, WriteClass};

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq)]
pub struct StoreExecutionMetrics {
    pub logical_reads: usize,
    pub logical_writes: usize,
    pub physical_reads: usize,
    pub physical_writes: usize,
    pub zero_writes: usize,
    pub discard_writes: usize,
}

pub trait ObjectStore {
    fn read_cell(&mut self, object: &str) -> Result<Vec<u8>>;
    fn write_cell(&mut self, object: &str, value: &[u8]) -> Result<()>;
    fn physical_writes(&self) -> &[PhysicalWriteEvent];
    fn logical_events(&self) -> &[LogicalEvent];
    fn metrics(&self) -> &StoreExecutionMetrics;
}

#[derive(Clone, Debug)]
pub struct RawObjectStore {
    slots: BTreeMap<String, Vec<u8>>,
    physical_writes: Vec<PhysicalWriteEvent>,
    logical_events: Vec<LogicalEvent>,
    metrics: StoreExecutionMetrics,
}

impl RawObjectStore {
    pub fn new() -> Self {
        Self {
            slots: BTreeMap::new(),
            physical_writes: Vec::new(),
            logical_events: Vec::new(),
            metrics: StoreExecutionMetrics::default(),
        }
    }

    pub fn with_zeroed_slots(objects: impl IntoIterator<Item = String>) -> Self {
        let mut store = Self::new();
        for object in objects {
            store.slots.insert(object, vec![0u8; 32]);
        }
        store
    }
}

impl ObjectStore for RawObjectStore {
    fn read_cell(&mut self, object: &str) -> Result<Vec<u8>> {
        self.metrics.logical_reads += 1;
        self.metrics.physical_reads += 1;
        self.logical_events.push(LogicalEvent {
            kind: "raw_cell_get".into(),
            object: object.into(),
            detail: String::new(),
        });
        Ok(self
            .slots
            .entry(object.into())
            .or_insert_with(|| vec![0u8; 32])
            .clone())
    }

    fn write_cell(&mut self, object: &str, value: &[u8]) -> Result<()> {
        self.metrics.logical_writes += 1;
        self.metrics.physical_writes += 1;
        if value.iter().all(|byte| *byte == 0) {
            self.metrics.zero_writes += 1;
        }
        let old = self
            .slots
            .entry(object.into())
            .or_insert_with(|| vec![0u8; value.len()])
            .clone();
        let new = value.to_vec();
        self.slots.insert(object.into(), new.clone());
        self.logical_events.push(LogicalEvent {
            kind: "raw_cell_set".into(),
            object: object.into(),
            detail: format!("{} bytes", value.len()),
        });
        self.physical_writes.push(PhysicalWriteEvent {
            object: object.into(),
            location: object.into(),
            class: classify_write(&old, &new),
            old,
            new,
        });
        Ok(())
    }

    fn physical_writes(&self) -> &[PhysicalWriteEvent] {
        &self.physical_writes
    }

    fn logical_events(&self) -> &[LogicalEvent] {
        &self.logical_events
    }

    fn metrics(&self) -> &StoreExecutionMetrics {
        &self.metrics
    }
}

#[derive(Clone, Debug)]
pub struct UoObjectStore {
    slots: BTreeMap<String, Vec<u8>>,
    physical_writes: Vec<PhysicalWriteEvent>,
    logical_events: Vec<LogicalEvent>,
    metrics: StoreExecutionMetrics,
    rng: ChaCha20Rng,
    cipher: StoreCipher,
}

impl UoObjectStore {
    pub fn preinitialized(objects: impl IntoIterator<Item = (String, usize)>) -> Self {
        let mut rng = ChaCha20Rng::seed_from_u64(0x5EED);
        let cipher = StoreCipher::random();
        let mut slots = BTreeMap::new();
        for (object, logical_len) in objects {
            let aad = format!("uo_store:{object}");
            slots.insert(object, cipher.filler(aad.as_bytes(), logical_len, &mut rng));
        }
        Self {
            slots,
            physical_writes: Vec::new(),
            logical_events: Vec::new(),
            metrics: StoreExecutionMetrics::default(),
            rng,
            cipher,
        }
    }

    pub fn ensure_update_only(&self) -> Result<()> {
        if self
            .physical_writes
            .iter()
            .any(|event| event.class != WriteClass::Update)
        {
            return Err(anyhow!("confidential path emitted a non-UPDATE write"));
        }
        Ok(())
    }
}

impl ObjectStore for UoObjectStore {
    fn read_cell(&mut self, object: &str) -> Result<Vec<u8>> {
        self.metrics.logical_reads += 1;
        self.metrics.physical_reads += 1;
        self.logical_events.push(LogicalEvent {
            kind: "uo_cell_get".into(),
            object: object.into(),
            detail: String::new(),
        });
        self.slots
            .get(object)
            .cloned()
            .ok_or_else(|| anyhow!("unknown UO object: {object}"))
    }

    fn write_cell(&mut self, object: &str, value: &[u8]) -> Result<()> {
        self.metrics.logical_writes += 1;
        self.metrics.physical_writes += 1;
        let old = self
            .slots
            .get(object)
            .cloned()
            .ok_or_else(|| anyhow!("unknown UO object: {object}"))?;
        let aad = format!("uo_store:{object}");
        let new = self.cipher.seal(aad.as_bytes(), value, &mut self.rng);
        self.logical_events.push(LogicalEvent {
            kind: "uo_cell_set".into(),
            object: object.into(),
            detail: format!("{} bytes", value.len()),
        });
        self.slots.insert(object.into(), new.clone());
        self.physical_writes.push(PhysicalWriteEvent {
            object: object.into(),
            location: object.into(),
            class: classify_write(&old, &new),
            old,
            new,
        });
        Ok(())
    }

    fn physical_writes(&self) -> &[PhysicalWriteEvent] {
        &self.physical_writes
    }

    fn logical_events(&self) -> &[LogicalEvent] {
        &self.logical_events
    }

    fn metrics(&self) -> &StoreExecutionMetrics {
        &self.metrics
    }
}

#[cfg(test)]
mod tests {
    use super::{ObjectStore, RawObjectStore, UoObjectStore};
    use uo_core::trace::WriteClass;

    #[test]
    fn raw_store_exposes_set_and_same() {
        let mut store = RawObjectStore::with_zeroed_slots(["slot".to_string()]);
        store.write_cell("slot", &[0u8; 32]).unwrap();
        store.write_cell("slot", &[1u8; 32]).unwrap();
        let classes: Vec<_> = store
            .physical_writes()
            .iter()
            .map(|event| event.class)
            .collect();
        assert_eq!(classes, vec![WriteClass::Same, WriteClass::Set]);
    }

    #[test]
    fn uo_store_emits_update_only_after_init() {
        let mut store = UoObjectStore::preinitialized([("slot".to_string(), 32)]);
        store.write_cell("slot", &[0u8; 32]).unwrap();
        store.write_cell("slot", &[0u8; 32]).unwrap();
        store.write_cell("slot", &[1u8; 32]).unwrap();
        store.ensure_update_only().unwrap();
        assert!(store
            .physical_writes()
            .iter()
            .all(|event| event.class == WriteClass::Update));
    }
}
