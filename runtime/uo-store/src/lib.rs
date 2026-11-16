#![allow(clippy::borrowed_box, clippy::needless_lifetimes)]

pub mod codec;
pub mod storage;
mod store;

pub use codec::{sealed_record_len, sealed_record_seal_count, StoreCipher};
pub use storage::{
    sealed_write_class, storage_failure, AppendFailure, CheckpointStep, FileStorage, JournalEntry,
    MemoryStorage, SharedStorage, StorageAdapter, StorageError, StorageFailure, StorageFault,
    StorageHandle, StorageIo, StorageStats, SyncPolicy, SEAL_RESERVATION_STEP,
};
pub use store::StoreExecutionMetrics;
