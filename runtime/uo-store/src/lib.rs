#![allow(clippy::borrowed_box, clippy::needless_lifetimes)]

pub mod codec;
pub mod storage;
mod store;

pub use codec::{sealed_record_seal_count, StoreCipher};
pub use storage::{
    sealed_write_class, FileStorage, MemoryStorage, SharedStorage, StorageAdapter, StorageHandle,
    StorageIo, StorageStats, SyncPolicy, SEAL_RESERVATION_STEP,
};
pub use store::StoreExecutionMetrics;
