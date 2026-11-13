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
    fn uo_store_fails_a_write_that_repeats_a_nonce() {
        use crate::codec::StoreCipher;
        use rand::SeedableRng;
        use rand_chacha::ChaCha20Rng;

        // Two ciphers made from the same key material have one key, and
        // each counts its seals from zero.
        let cipher = || StoreCipher::from_rng(&mut ChaCha20Rng::seed_from_u64(0xC1F3));
        let mut store = UoObjectStore::preinitialized([("slot".to_string(), 32)]).unwrap();
        store.cipher = cipher();
        store.write_cell("slot", &mut [5u8; 32]).unwrap();
        store.write_cell("slot", &mut [5u8; 32]).unwrap();
        assert_eq!(store.physical_writes().len(), 2);

        // With the count set back the next seal repeats the first write's
        // nonce. The same value under that nonce is the record the slot
        // held after the first write, not the one it holds now: an Update.
        store.cipher = cipher();
        store.write_cell("slot", &mut [5u8; 32]).unwrap();
        assert_eq!(store.physical_writes().len(), 3);
        // Set back once more, the seal repeats the nonce of the record the
        // slot holds, and the same value gives the same record: the
        // observer would see a Same, and the store fails the write.
        store.cipher = cipher();
        let error = store.write_cell("slot", &mut [5u8; 32]).unwrap_err();
        assert!(
            format!("{error:#}").contains("is not an Update of the record it replaces"),
            "{error:#}"
        );
        assert_eq!(store.physical_writes().len(), 3);
        store.ensure_update_only().unwrap();
    }
}
