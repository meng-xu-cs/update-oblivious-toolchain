#![allow(clippy::borrowed_box, clippy::needless_lifetimes)]

pub mod codec;
/// What a crash leaves of a file store's files, for tests.
#[cfg(any(test, feature = "fault-injection"))]
pub mod crash_model;
pub mod storage;
mod store;

pub use codec::{sealed_record_len, sealed_record_seal_count, StoreCipher};
pub use storage::{
    sealed_write_class, storage_failure, AppendFailure, CheckpointStep, FileStorage, MemoryStorage,
    SharedStorage, StorageAdapter, StorageError, StorageFailure, StorageFault, StorageHandle,
    StorageIo, StorageStats, SyncPolicy,
};
pub use store::StoreExecutionMetrics;
