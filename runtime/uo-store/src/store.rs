use crate::codec::StoreCipher;
use anyhow::Result;
use rand_chacha::ChaCha20Rng;
use serde::{Deserialize, Serialize};
use uo_core::trace::{LogicalEvent, PhysicalWriteEvent};

#[path = "generated_store_helpers.rs"]
mod generated_store_helpers;
use generated_store_helpers::{StoreLogicalEventTrace, StorePhysicalWriteTrace, StoreSlotTable};

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq)]
pub struct StoreExecutionMetrics {
    pub logical_reads: usize,
    pub logical_writes: usize,
    pub physical_reads: usize,
    pub physical_writes: usize,
    pub zero_writes: usize,
    pub discard_writes: usize,
}

#[allow(dead_code)]
pub trait ObjectStore {
    fn read_cell(&mut self, object: &str) -> Result<Box<[u8]>>;
    fn write_cell(&mut self, object: &str, value: &mut [u8]) -> Result<()>;
    fn physical_writes(&self) -> &[PhysicalWriteEvent];
    fn logical_events(&self) -> &[LogicalEvent];
    fn metrics(&self) -> &StoreExecutionMetrics;
}

#[derive(Debug)]
pub struct RawObjectStore {
    slots: StoreSlotTable,
    physical_writes: StorePhysicalWriteTrace,
    logical_events: StoreLogicalEventTrace,
    metrics: StoreExecutionMetrics,
}

#[derive(Debug)]
pub struct UoObjectStore {
    slots: StoreSlotTable,
    physical_writes: StorePhysicalWriteTrace,
    logical_events: StoreLogicalEventTrace,
    metrics: StoreExecutionMetrics,
    rng: ChaCha20Rng,
    cipher: StoreCipher,
}

#[cfg(test)]
mod tests {
    use super::{ObjectStore, RawObjectStore, UoObjectStore};
    use uo_core::trace::WriteClass;

    #[test]
    fn raw_store_exposes_set_and_same() {
        let mut store = RawObjectStore::with_zeroed_slots(["slot".to_string()]).unwrap();
        let mut first = [0u8; 32];
        let mut second = [1u8; 32];
        store.write_cell("slot", &mut first).unwrap();
        store.write_cell("slot", &mut second).unwrap();
        assert_eq!(first, [0u8; 32]);
        assert_eq!(second, [0u8; 32]);
        let classes: Vec<_> = store
            .physical_writes()
            .iter()
            .map(|event| event.class)
            .collect();
        assert_eq!(classes, vec![WriteClass::Same, WriteClass::Set]);
    }

    #[test]
    fn uo_store_emits_update_only_after_init() {
        let mut store = UoObjectStore::preinitialized([("slot".to_string(), 32)]).unwrap();
        let mut first = [0u8; 32];
        let mut second = [0u8; 32];
        let mut third = [1u8; 32];
        store.write_cell("slot", &mut first).unwrap();
        store.write_cell("slot", &mut second).unwrap();
        store.write_cell("slot", &mut third).unwrap();
        assert_eq!(first, [0u8; 32]);
        assert_eq!(second, [0u8; 32]);
        assert_eq!(third, [0u8; 32]);
        store.ensure_update_only().unwrap();
        assert!(store
            .physical_writes()
            .iter()
            .all(|event| event.class == WriteClass::Update));
    }

    #[test]
    fn uo_store_write_that_repeats_a_nonce_is_still_an_update() {
        use crate::codec::StoreCipher;
        use rand::SeedableRng;
        use rand_chacha::ChaCha20Rng;

        // Two ciphers made from the same key material have one key, and
        // each counts its seals from zero. With the count set back before
        // every write, each write of the same value seals the same
        // ciphertext under the same nonce. The slot's record still changes
        // in every unit, since a record carries the marker that the record
        // it replaces does not: the store's check of the write's bytes
        // passes, and the observer sees an Update.
        let cipher = || StoreCipher::from_rng(&mut ChaCha20Rng::seed_from_u64(0xC1F3));
        let mut store = UoObjectStore::preinitialized([("slot".to_string(), 32)]).unwrap();
        let mut records = Vec::new();
        for _ in 0..4 {
            store.cipher = cipher();
            store.write_cell("slot", &mut [5u8; 32]).unwrap();
            records.push(store.read_cell("slot").unwrap());
        }
        assert_eq!(store.physical_writes().len(), 4);
        store.ensure_update_only().unwrap();
        for pair in records.windows(2) {
            let (old, new) = (&pair[0], &pair[1]);
            assert_eq!(old.len(), 64);
            assert!(uo_core::is_update_write(old, new));
            for (old_unit, new_unit) in old.chunks_exact(32).zip(new.chunks_exact(32)) {
                assert_ne!(old_unit[0], new_unit[0]);
                assert_eq!(old_unit[1..], new_unit[1..]);
            }
        }
        // The record after two writes is the record before them.
        assert_eq!(records[0], records[2]);
        assert_eq!(records[1], records[3]);
    }
}
