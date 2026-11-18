//! The storage boundary: what a host that keeps a contract's storage holds,
//! and what it sees of a call.
//!
//! A `StorageAdapter` keeps every sealed record of a deployed contract. The
//! runtime hands it each record it seals, and names each record it is about
//! to open. The adapter logs both from its own side: a read with the length
//! of the record it holds, a write with the class it computes from the bytes
//! it held and the bytes it is handed. That log does not come from the code
//! that records a call's trace, so the two can be compared.
//!
//! The adapter is transactional as a call is. The records a call writes are
//! pending until `commit`, which makes them durable together with the
//! runtime's public metadata, and `abandon` puts back what the call replaced.
//!
//! A sealed record carries the count of the seals made under its key before
//! it, which is its nonce. The adapter takes a record in a call only if that
//! count is below the count the last commit reserved for the record's
//! object: a reservation is made durable by the commit it is made for
//! (`reserve_seals`), and takes effect after it. A runtime reserves at each
//! commit what the next call can seal, and a restart resumes each key's count
//! at the reservation of the commit it restarts from, so no nonce that
//! reached the adapter is used again.
//!
//! A file store fails closed. An append to its journal that fails, whether
//! its write stopped part way or its sync failed after a whole write, may or
//! may not have left the entry in the files: its error says the outcome is
//! unknown (`StorageFailure::OutcomeUnknown`), and the store refuses every
//! operation until its directory is opened again, which finds the entry
//! whole or not at all. A checkpoint that fails leaves every commit in the
//! files and also makes the store refuse every operation. Any other error
//! comes before a file is touched (`StorageFailure::Definite`).
//!
//! What a store serves is on the device, under `SyncPolicy::Always`. After
//! a sync failed, the files a process reads can hold bytes that are not on
//! the device and that no later sync of that file puts there, so opening a
//! store publishes what it read before it serves it: the journal's whole
//! entries go into a new file, which is synced and renamed over the
//! journal, and the directory is synced. An open whose publication fails
//! fails, and serves nothing. Creating a store syncs the journal and the
//! snapshot, the directory that holds them, and each directory it made in
//! the one above it, before it returns.

use crate::codec::sealed_record_seal_count;
use anyhow::{anyhow, bail, Context, Result};
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fmt::{self, Write as _};
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Instant;
use uo_core::trace::{classify_write, WriteClass};
use uo_core::STORAGE_OBSERVER_UNIT_BYTES;

#[cfg(any(test, feature = "fault-injection"))]
use crate::crash_model::{self, FileOperation};

/// One read or write of a sealed record, as the adapter saw it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum StorageIo {
    Read {
        object: String,
        location: String,
        len: usize,
    },
    Write {
        object: String,
        location: String,
        len: usize,
        class: WriteClass,
    },
}

/// How a failed storage operation left the store's files.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum StorageFailure {
    /// Nothing reached the files: they hold what they held before the
    /// operation.
    Definite,
    /// An append to the journal failed after it began: the files hold its
    /// entry whole or not at all, and only opening them again shows which.
    /// The store refuses every operation until then.
    OutcomeUnknown,
}

/// The error of a storage operation, with how it left the files.
#[derive(Debug, thiserror::Error)]
#[error("{message}")]
pub struct StorageError {
    pub failure: StorageFailure,
    message: String,
}

impl StorageError {
    fn definite(message: impl Into<String>) -> anyhow::Error {
        anyhow::Error::new(Self {
            failure: StorageFailure::Definite,
            message: message.into(),
        })
    }

    fn outcome_unknown(message: impl Into<String>) -> anyhow::Error {
        anyhow::Error::new(Self {
            failure: StorageFailure::OutcomeUnknown,
            message: message.into(),
        })
    }
}

/// How the storage error in `error`'s chain left the store's files, if the
/// chain holds one: what a runtime tells the caller of a call whose commit
/// failed.
pub fn storage_failure(error: &anyhow::Error) -> Option<StorageFailure> {
    error
        .chain()
        .find_map(|cause| cause.downcast_ref::<StorageError>())
        .map(|error| error.failure)
}

/// Counts an adapter keeps of its work since it was made.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize)]
pub struct StorageStats {
    pub reads: u64,
    pub read_bytes: u64,
    pub writes: u64,
    pub written_bytes: u64,
    pub commits: u64,
    /// Reservations that raised a key's count, each made durable by the
    /// next commit.
    pub reservations: u64,
    /// Bytes appended to durable files, and the time that took with its
    /// syncs. An adapter that keeps no file has zeros.
    pub persisted_bytes: u64,
    pub persist_ns: u64,
    pub syncs: u64,
}

/// The class of a write of a sealed record over another, as the storage
/// observer classifies it: `Update` when every 32-byte unit is an `Update`,
/// and otherwise the class of the first unit that is not.
pub fn sealed_write_class(old: &[u8], new: &[u8]) -> WriteClass {
    if old.len() != new.len() || new.is_empty() {
        return classify_write(old, new);
    }
    old.chunks(STORAGE_OBSERVER_UNIT_BYTES)
        .zip(new.chunks(STORAGE_OBSERVER_UNIT_BYTES))
        .map(|(old_unit, new_unit)| classify_write(old_unit, new_unit))
        .find(|class| *class != WriteClass::Update)
        .unwrap_or(WriteClass::Update)
}

/// A store of sealed records behind the runtime.
pub trait StorageAdapter: Send + fmt::Debug {
    /// Take the first record of `location`, which belongs to `object`.
    fn create(&mut self, object: &str, location: &str, record: &[u8]) -> Result<()>;

    /// A copy of the record at `location`, which the runtime is about to
    /// open: the runtime holds no record of its own, so the record crosses
    /// to it here, and the read is logged with the adapter's record. Fails
    /// unless the record has the public length `len` the runtime expects.
    fn read(&mut self, location: &str, len: usize) -> Result<Box<[u8]>>;

    /// Take `record` in place of the record at `location`, and return the
    /// class of the write, computed from the record the adapter kept and the
    /// one it is handed. The write is logged with that class.
    fn write(&mut self, location: &str, record: &[u8]) -> Result<WriteClass>;

    /// Keep the public value at `location` of the public object `object`. A
    /// public object is not sealed; its value is kept so that a restart
    /// finds it, and it is not logged.
    fn put_public(&mut self, object: &str, location: &str, value: &[u8]) -> Result<()>;

    /// Reserve the seal counts below `below` for the key of `object`. The
    /// next commit makes the reservation durable with it, and it takes
    /// effect then: a record handed over in a call must be below the
    /// reservation of the last commit. Before a deployment's commit, outside
    /// a call, its records must be below the reservations that commit will
    /// make durable. A reservation is never undone.
    fn reserve_seals(&mut self, object: &str, below: u64) -> Result<()>;

    /// The count below which the last commit reserved the seals of
    /// `object`'s key.
    fn reserved_seals(&self, object: &str) -> u64;

    /// Start a call. Nothing may be pending, and the log starts again.
    fn begin(&mut self) -> Result<()>;

    /// Make everything taken since the last commit durable, with `meta`.
    fn commit(&mut self, meta: &[u8]) -> Result<()>;

    /// Put back what was replaced since the last commit.
    fn abandon(&mut self);

    /// The reads and writes since the last `begin`, in order.
    fn log(&self) -> Vec<StorageIo>;

    /// Whether reads and writes are logged from now on. They are, unless
    /// this turns it off: a load of many records that nothing compares
    /// with a trace does.
    fn set_logging(&mut self, logging: bool);

    /// The record at `location`, if the adapter keeps one.
    fn record(&self, location: &str) -> Option<&[u8]>;

    /// The public values of `object`, by location, in location order.
    fn public_records(&self, object: &str) -> Vec<(String, Vec<u8>)>;

    /// The SHA-256, in hex, of every sealed record the adapter keeps with
    /// its location, in location order: what a host that keeps the store
    /// holds of the contract's ciphertext.
    fn sealed_records_sha256(&self) -> String;

    /// The seal count each sealed record of `object` carries, ascending:
    /// the nonces under the object's key that the adapter holds.
    fn seal_counts(&self, object: &str) -> Vec<u64>;

    /// The metadata of the last commit.
    fn meta(&self) -> &[u8];

    fn stats(&self) -> StorageStats;

    /// Why the adapter refuses every operation, if it does: an append or a
    /// checkpoint failed, and what its files hold is known again only once
    /// they are opened again.
    fn poisoned(&self) -> Option<String> {
        None
    }

    /// Arm `fault` for the next operation it names. Only a test or a
    /// diagnostics build can; an adapter that keeps no files takes none.
    #[cfg(any(test, feature = "fault-injection"))]
    fn inject_fault(&mut self, fault: StorageFault) -> Result<()> {
        bail!("this store keeps no files and takes no injected fault ({fault:?})")
    }
}

#[derive(Debug)]
struct StoredRecord {
    object: u32,
    location: Box<str>,
    bytes: Box<[u8]>,
    /// Whether the record was created or first replaced since the last
    /// commit: `abandon` then has what to put back, and a later write of the
    /// record adds nothing to it.
    pending: bool,
}

#[derive(Debug)]
struct StoredObject {
    name: Box<str>,
    /// The reservation of the last commit.
    reserved_seals: u64,
    /// The reservation the next commit makes durable: never below the last
    /// commit's.
    staged_seals: u64,
}

#[derive(Debug)]
struct PublicRecord {
    object: u32,
    bytes: Box<[u8]>,
}

/// What `abandon` puts back, newest last.
#[derive(Debug)]
enum Pending {
    Replaced {
        record: u32,
        bytes: Box<[u8]>,
    },
    Created {
        record: u32,
    },
    Public {
        location: Box<str>,
        previous: Option<PublicRecord>,
    },
}

#[derive(Clone, Copy, Debug)]
struct LogEntry {
    record: u32,
    len: u32,
    class: Option<WriteClass>,
}

/// An adapter that keeps its records in memory. Nothing of it outlives the
/// process.
#[derive(Debug)]
pub struct MemoryStorage {
    objects: Vec<StoredObject>,
    object_ids: HashMap<Box<str>, u32>,
    records: Vec<StoredRecord>,
    locations: HashMap<Box<str>, u32>,
    public: HashMap<Box<str>, PublicRecord>,
    meta: Vec<u8>,
    in_call: bool,
    pending: Vec<Pending>,
    log: Vec<LogEntry>,
    logging: bool,
    stats: StorageStats,
}

impl Default for MemoryStorage {
    fn default() -> Self {
        Self {
            objects: Vec::new(),
            object_ids: HashMap::new(),
            records: Vec::new(),
            locations: HashMap::new(),
            public: HashMap::new(),
            meta: Vec::new(),
            in_call: false,
            pending: Vec::new(),
            log: Vec::new(),
            logging: true,
            stats: StorageStats::default(),
        }
    }
}

impl MemoryStorage {
    pub fn new() -> Self {
        Self::default()
    }

    fn object_id(&mut self, object: &str) -> Result<u32> {
        if let Some(id) = self.object_ids.get(object) {
            return Ok(*id);
        }
        let id = u32::try_from(self.objects.len())
            .map_err(|_| anyhow!("the store holds too many objects"))?;
        self.objects.push(StoredObject {
            name: object.into(),
            reserved_seals: 0,
            staged_seals: 0,
        });
        self.object_ids.insert(object.into(), id);
        Ok(id)
    }

    fn object_name(&self, id: u32) -> &str {
        self.objects
            .get(id as usize)
            .map(|object| &*object.name)
            .unwrap_or("")
    }

    /// A sealed record of `object` may be taken in a call only if its nonce
    /// is below the reservation of the last commit, which is durable; outside
    /// a call, before a deployment's commit, below the reservation that commit
    /// will make durable.
    fn ensure_nonce_reserved(&self, object: u32, location: &str, record: &[u8]) -> Result<()> {
        let count = sealed_record_seal_count(record).ok_or_else(|| {
            anyhow!("the bytes handed to the store for {location} are not a sealed record")
        })?;
        let reserved = self
            .objects
            .get(object as usize)
            .map(|object| {
                if self.in_call {
                    object.reserved_seals
                } else {
                    object.staged_seals
                }
            })
            .unwrap_or(0);
        if count >= reserved {
            bail!(
                "the store refuses the record of {location}: its seal count is not below the reservation of its key, in a call the durable reservation of the last commit"
            );
        }
        Ok(())
    }

    fn push_log(&mut self, record: u32, len: usize, class: Option<WriteClass>) {
        if !self.logging {
            return;
        }
        self.log.push(LogEntry {
            record,
            len: u32::try_from(len).unwrap_or(u32::MAX),
            class,
        });
    }

    /// The ids of the records and the locations of the public values that
    /// were taken since the last commit, each once, in the order they were
    /// first taken.
    fn pending_changes(&self) -> (Vec<u32>, Vec<&str>) {
        let mut records = Vec::new();
        let mut public: Vec<&str> = Vec::new();
        for entry in &self.pending {
            match entry {
                // A record is pending once: created, or first replaced.
                Pending::Replaced { record, .. } | Pending::Created { record } => {
                    records.push(*record);
                }
                Pending::Public { location, .. } => {
                    if !public.iter().any(|seen| *seen == &**location) {
                        public.push(location);
                    }
                }
            }
        }
        (records, public)
    }

    /// The reservations the next commit makes durable: of each object whose
    /// staged reservation is above its last commit's, in object order.
    fn staged_reservations(&self) -> Vec<(&str, u64)> {
        self.objects
            .iter()
            .filter(|object| object.staged_seals > object.reserved_seals)
            .map(|object| (&*object.name, object.staged_seals))
            .collect()
    }

    fn finish_commit(&mut self, meta: &[u8]) {
        for object in &mut self.objects {
            object.reserved_seals = object.staged_seals;
        }
        for entry in self.pending.drain(..) {
            if let Pending::Replaced { record, .. } | Pending::Created { record } = entry {
                if let Some(stored) = self.records.get_mut(record as usize) {
                    stored.pending = false;
                }
            }
        }
        self.in_call = false;
        self.meta.clear();
        self.meta.extend_from_slice(meta);
        self.stats.commits += 1;
    }

    /// Put a record in place without a check or a log entry: how a file's
    /// contents are loaded.
    fn load_record(&mut self, object: &str, location: &str, bytes: &[u8]) -> Result<()> {
        let object = self.object_id(object)?;
        if let Some(id) = self.locations.get(location) {
            let record = self
                .records
                .get_mut(*id as usize)
                .ok_or_else(|| anyhow!("the store's index names a record it does not hold"))?;
            record.bytes = bytes.into();
            return Ok(());
        }
        let id = u32::try_from(self.records.len())
            .map_err(|_| anyhow!("the store holds too many records"))?;
        self.records.push(StoredRecord {
            object,
            location: location.into(),
            bytes: bytes.into(),
            pending: false,
        });
        self.locations.insert(location.into(), id);
        Ok(())
    }

    fn load_public(&mut self, object: &str, location: &str, bytes: &[u8]) -> Result<()> {
        let object = self.object_id(object)?;
        self.public.insert(
            location.into(),
            PublicRecord {
                object,
                bytes: bytes.into(),
            },
        );
        Ok(())
    }

    /// A reservation a commit made durable, as the files hold it.
    fn load_reservation(&mut self, object: &str, below: u64) -> Result<()> {
        let id = self.object_id(object)?;
        if let Some(object) = self.objects.get_mut(id as usize) {
            object.reserved_seals = object.reserved_seals.max(below);
            object.staged_seals = object.staged_seals.max(below);
        }
        Ok(())
    }
}

impl StorageAdapter for MemoryStorage {
    fn create(&mut self, object: &str, location: &str, record: &[u8]) -> Result<()> {
        if self.locations.contains_key(location) || self.public.contains_key(location) {
            bail!("the store already holds a record at {location}");
        }
        let object = self.object_id(object)?;
        self.ensure_nonce_reserved(object, location, record)?;
        let id = u32::try_from(self.records.len())
            .map_err(|_| anyhow!("the store holds too many records"))?;
        self.records.push(StoredRecord {
            object,
            location: location.into(),
            bytes: record.into(),
            pending: true,
        });
        self.locations.insert(location.into(), id);
        self.pending.push(Pending::Created { record: id });
        Ok(())
    }

    fn read(&mut self, location: &str, len: usize) -> Result<Box<[u8]>> {
        let id = *self
            .locations
            .get(location)
            .ok_or_else(|| anyhow!("the store holds no record at {location}"))?;
        let record = self
            .records
            .get(id as usize)
            .ok_or_else(|| anyhow!("the store's index names a record it does not hold"))?;
        if record.bytes.len() != len {
            bail!(
                "the store's record at {} has {} bytes where the runtime reads {}",
                location,
                record.bytes.len(),
                len
            );
        }
        let bytes = record.bytes.clone();
        self.stats.reads += 1;
        self.stats.read_bytes += len as u64;
        self.push_log(id, len, None);
        Ok(bytes)
    }

    fn write(&mut self, location: &str, record: &[u8]) -> Result<WriteClass> {
        let id = *self
            .locations
            .get(location)
            .ok_or_else(|| anyhow!("the store holds no record at {location}"))?;
        let object = self
            .records
            .get(id as usize)
            .map(|stored| stored.object)
            .ok_or_else(|| anyhow!("the store's index names a record it does not hold"))?;
        self.ensure_nonce_reserved(object, location, record)?;
        let stored = self
            .records
            .get_mut(id as usize)
            .ok_or_else(|| anyhow!("the store's index names a record it does not hold"))?;
        if stored.bytes.len() != record.len() {
            bail!("the record handed to the store for {location} has another length than the record it replaces");
        }
        let class = sealed_write_class(&stored.bytes, record);
        let replaced = std::mem::replace(&mut stored.bytes, record.into());
        // What `abandon` puts back is the record of the last commit: only
        // the first write of a record since then keeps what it replaced.
        if !stored.pending {
            stored.pending = true;
            self.pending.push(Pending::Replaced {
                record: id,
                bytes: replaced,
            });
        }
        self.stats.writes += 1;
        self.stats.written_bytes += record.len() as u64;
        self.push_log(id, record.len(), Some(class));
        Ok(class)
    }

    fn put_public(&mut self, object: &str, location: &str, value: &[u8]) -> Result<()> {
        if self.locations.contains_key(location) {
            bail!("the store holds a sealed record at {location}");
        }
        let object = self.object_id(object)?;
        let previous = self.public.insert(
            location.into(),
            PublicRecord {
                object,
                bytes: value.into(),
            },
        );
        self.pending.push(Pending::Public {
            location: location.into(),
            previous,
        });
        Ok(())
    }

    fn reserve_seals(&mut self, object: &str, below: u64) -> Result<()> {
        let id = self.object_id(object)?;
        if let Some(object) = self.objects.get_mut(id as usize) {
            if below > object.staged_seals {
                object.staged_seals = below;
                self.stats.reservations += 1;
            }
        }
        Ok(())
    }

    fn reserved_seals(&self, object: &str) -> u64 {
        self.object_ids
            .get(object)
            .and_then(|id| self.objects.get(*id as usize))
            .map(|object| object.reserved_seals)
            .unwrap_or(0)
    }

    fn begin(&mut self) -> Result<()> {
        if self.in_call {
            bail!("the store has a call that was neither committed nor abandoned");
        }
        if !self.pending.is_empty() {
            bail!("the store holds records that were neither committed nor abandoned");
        }
        self.in_call = true;
        self.log.clear();
        Ok(())
    }

    fn commit(&mut self, meta: &[u8]) -> Result<()> {
        self.finish_commit(meta);
        Ok(())
    }

    fn abandon(&mut self) {
        while let Some(entry) = self.pending.pop() {
            match entry {
                Pending::Replaced { record, bytes } => {
                    if let Some(stored) = self.records.get_mut(record as usize) {
                        stored.bytes = bytes;
                        stored.pending = false;
                    }
                }
                Pending::Created { record } => {
                    // Records are created at the end, and undone newest
                    // first, so the record to remove is the last one.
                    if record as usize + 1 == self.records.len() {
                        if let Some(stored) = self.records.pop() {
                            self.locations.remove(&stored.location);
                        }
                    }
                }
                Pending::Public { location, previous } => match previous {
                    Some(previous) => {
                        self.public.insert(location, previous);
                    }
                    None => {
                        self.public.remove(&location);
                    }
                },
            }
        }
        self.in_call = false;
    }

    fn log(&self) -> Vec<StorageIo> {
        self.log
            .iter()
            .filter_map(|entry| {
                let record = self.records.get(entry.record as usize)?;
                let object = self.object_name(record.object).to_owned();
                let location = record.location.to_string();
                let len = entry.len as usize;
                Some(match entry.class {
                    None => StorageIo::Read {
                        object,
                        location,
                        len,
                    },
                    Some(class) => StorageIo::Write {
                        object,
                        location,
                        len,
                        class,
                    },
                })
            })
            .collect()
    }

    fn set_logging(&mut self, logging: bool) {
        self.logging = logging;
    }

    fn record(&self, location: &str) -> Option<&[u8]> {
        let id = self.locations.get(location)?;
        self.records.get(*id as usize).map(|record| &*record.bytes)
    }

    fn public_records(&self, object: &str) -> Vec<(String, Vec<u8>)> {
        let Some(id) = self.object_ids.get(object) else {
            return Vec::new();
        };
        let mut records: Vec<(String, Vec<u8>)> = self
            .public
            .iter()
            .filter(|(_, record)| record.object == *id)
            .map(|(location, record)| (location.to_string(), record.bytes.to_vec()))
            .collect();
        records.sort();
        records
    }

    fn sealed_records_sha256(&self) -> String {
        let mut records: Vec<&StoredRecord> = self.records.iter().collect();
        records.sort_by(|left, right| left.location.cmp(&right.location));
        let mut hasher = Sha256::new();
        for record in records {
            hasher.update((record.location.len() as u64).to_le_bytes());
            hasher.update(record.location.as_bytes());
            hasher.update((record.bytes.len() as u64).to_le_bytes());
            hasher.update(&record.bytes);
        }
        let mut hex = String::with_capacity(2 * FRAME_DIGEST_BYTES);
        for byte in hasher.finalize() {
            // Writing to a string cannot fail.
            let _ = write!(hex, "{byte:02x}");
        }
        hex
    }

    fn seal_counts(&self, object: &str) -> Vec<u64> {
        let Some(id) = self.object_ids.get(object) else {
            return Vec::new();
        };
        let mut counts: Vec<u64> = self
            .records
            .iter()
            .filter(|record| record.object == *id)
            .filter_map(|record| sealed_record_seal_count(&record.bytes))
            .collect();
        counts.sort_unstable();
        counts
    }

    fn meta(&self) -> &[u8] {
        &self.meta
    }

    fn stats(&self) -> StorageStats {
        self.stats
    }
}

/// When a file-backed adapter asks the operating system to flush what it
/// appended.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SyncPolicy {
    /// After every commit: a commit that returned is on the device.
    Always,
    /// Never: the files are written and the device is left to the operating
    /// system. A commit that returned survives the process, not a power
    /// failure.
    Never,
}

const SNAPSHOT_FILE: &str = "snapshot.bin";
const SNAPSHOT_TEMP_FILE: &str = "snapshot.tmp";
const JOURNAL_FILE: &str = "journal.bin";
/// The journal an open publishes, before it is renamed over the journal.
const JOURNAL_TEMP_FILE: &str = "journal.tmp";
const SNAPSHOT_MAGIC: u32 = 0x554F_534E;
const JOURNAL_MAGIC: u32 = 0x554F_4A4E;
const FRAME_HEADER_BYTES: usize = 12;
const FRAME_DIGEST_BYTES: usize = 32;
/// The kind of the journal's one entry: a commit, with the runtime's
/// metadata, the reservations it makes durable, and the records and public
/// values it makes durable. A journal entry of another kind is refused.
const ENTRY_COMMIT: u8 = 1;

/// How an append to the journal fails: its write stops part way, in the
/// entry's header, in its payload or in its digest, or its sync fails after
/// a whole write.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AppendFailure {
    WriteStopsInHeader,
    WriteStopsInPayload,
    WriteStopsInDigest,
    SyncFails,
}

impl AppendFailure {
    /// The bytes of an entry of `len` bytes that the write leaves before it
    /// stops, if it stops part way.
    fn written(self, len: usize) -> Option<usize> {
        match self {
            Self::WriteStopsInHeader => Some(FRAME_HEADER_BYTES / 2),
            Self::WriteStopsInPayload => {
                Some(FRAME_HEADER_BYTES + (len - FRAME_HEADER_BYTES - FRAME_DIGEST_BYTES) / 2)
            }
            Self::WriteStopsInDigest => Some(len - 1),
            Self::SyncFails => None,
        }
    }
}

/// A step of a checkpoint.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CheckpointStep {
    /// Writing the snapshot to a file beside the one in place.
    SnapshotWrite,
    /// Renaming that file over the one in place.
    SnapshotRename,
    /// Emptying the journal.
    JournalTruncation,
}

/// A failure a test or a diagnostics build makes a file store meet at the
/// next operation it names (`FileStorage::inject_fault`), as a device or a
/// file system could fail it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(tag = "operation", rename_all = "snake_case")]
pub enum StorageFault {
    /// The next append to the journal, a commit's, fails so.
    Append { failure: AppendFailure },
    /// The next checkpoint fails at this step.
    Checkpoint { step: CheckpointStep },
}

impl StorageFault {
    /// Every failure a file store can be made to meet: each way the append
    /// of a commit fails, and each step of a checkpoint.
    pub const ALL: [StorageFault; 7] = {
        use AppendFailure::*;
        [
            StorageFault::Append {
                failure: WriteStopsInHeader,
            },
            StorageFault::Append {
                failure: WriteStopsInPayload,
            },
            StorageFault::Append {
                failure: WriteStopsInDigest,
            },
            StorageFault::Append { failure: SyncFails },
            StorageFault::Checkpoint {
                step: CheckpointStep::SnapshotWrite,
            },
            StorageFault::Checkpoint {
                step: CheckpointStep::SnapshotRename,
            },
            StorageFault::Checkpoint {
                step: CheckpointStep::JournalTruncation,
            },
        ]
    };

    /// Whether an append that meets this failure leaves its entry whole in
    /// the files: only one whose sync failed after a whole write does. A
    /// checkpoint's failure leaves every commit in the files.
    pub fn leaves_the_entry_whole(self) -> bool {
        match self {
            Self::Append { failure, .. } => failure == AppendFailure::SyncFails,
            Self::Checkpoint { .. } => true,
        }
    }
}

/// An I/O error a test injected.
fn injected(what: &str) -> std::io::Error {
    std::io::Error::other(format!("injected fault: {what}"))
}

/// An adapter that keeps its records in two files of a directory: a
/// snapshot of every record, and a journal of the commits since. It serves
/// reads from the image of them it holds in memory.
///
/// A commit is one journal entry with a digest, appended and then synced as
/// the policy says, so it is in the files whole or not at all: an entry that
/// was cut short is dropped when the directory is opened.
#[derive(Debug)]
pub struct FileStorage {
    image: MemoryStorage,
    directory: PathBuf,
    journal: File,
    journal_path: PathBuf,
    journal_bytes: u64,
    /// The journal length above which a commit writes a snapshot and
    /// empties the journal.
    checkpoint_bytes: Option<u64>,
    sync: SyncPolicy,
    /// Why the store refuses every operation, once an append or a
    /// checkpoint failed.
    poisoned: Option<String>,
    /// The bytes after the journal's last whole entry that `open` cut.
    cut_on_open: u64,
    /// The failure a test armed for a later operation.
    #[cfg(any(test, feature = "fault-injection"))]
    fault: Option<StorageFault>,
}

fn put_u32(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn put_u64(out: &mut Vec<u8>, value: u64) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn put_bytes(out: &mut Vec<u8>, bytes: &[u8]) -> Result<()> {
    put_u32(
        out,
        u32::try_from(bytes.len()).map_err(|_| anyhow!("a stored value is too long"))?,
    );
    out.extend_from_slice(bytes);
    Ok(())
}

struct Decoder<'a> {
    bytes: &'a [u8],
}

impl<'a> Decoder<'a> {
    fn take(&mut self, len: usize) -> Result<&'a [u8]> {
        if self.bytes.len() < len {
            bail!("a stored entry ends before its contents do");
        }
        let (head, tail) = self.bytes.split_at(len);
        self.bytes = tail;
        Ok(head)
    }

    fn u8(&mut self) -> Result<u8> {
        Ok(self.take(1)?[0])
    }

    fn u32(&mut self) -> Result<u32> {
        let mut value = [0u8; 4];
        value.copy_from_slice(self.take(4)?);
        Ok(u32::from_le_bytes(value))
    }

    fn u64(&mut self) -> Result<u64> {
        let mut value = [0u8; 8];
        value.copy_from_slice(self.take(8)?);
        Ok(u64::from_le_bytes(value))
    }

    fn blob(&mut self) -> Result<&'a [u8]> {
        let len = self.u32()? as usize;
        self.take(len)
    }

    fn text(&mut self) -> Result<&'a str> {
        std::str::from_utf8(self.blob()?).context("a stored name is not UTF-8")
    }

    fn finish(&self) -> Result<()> {
        if !self.bytes.is_empty() {
            bail!("a stored entry has bytes after its contents");
        }
        Ok(())
    }
}

/// A frame: magic, payload length, payload, SHA-256 of the payload.
fn frame(magic: u32, payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(FRAME_HEADER_BYTES + payload.len() + FRAME_DIGEST_BYTES);
    put_u32(&mut out, magic);
    put_u64(&mut out, payload.len() as u64);
    out.extend_from_slice(payload);
    out.extend_from_slice(&Sha256::digest(payload));
    out
}

/// The payload of the frame at the start of `bytes` and the frame's length,
/// or `None` if `bytes` does not start with a whole frame of this magic.
fn read_frame(magic: u32, bytes: &[u8]) -> Option<(&[u8], usize)> {
    let header = bytes.get(..FRAME_HEADER_BYTES)?;
    let mut word = [0u8; 4];
    word.copy_from_slice(header.get(..4)?);
    if u32::from_le_bytes(word) != magic {
        return None;
    }
    let mut len = [0u8; 8];
    len.copy_from_slice(header.get(4..)?);
    let len = usize::try_from(u64::from_le_bytes(len)).ok()?;
    let end = FRAME_HEADER_BYTES.checked_add(len)?;
    let payload = bytes.get(FRAME_HEADER_BYTES..end)?;
    let digest = bytes.get(end..end.checked_add(FRAME_DIGEST_BYTES)?)?;
    (Sha256::digest(payload).as_slice() == digest).then_some((payload, end + FRAME_DIGEST_BYTES))
}

/// The journal of the store in `directory`, to append to and to read: a new
/// one, or the one that is there. The call is spelled with its type: the
/// runtime's sources name a method `open` only in the record codec, and a
/// check of them looks for the method call.
fn journal_file(directory: &Path, new: bool) -> std::io::Result<File> {
    let mut options = OpenOptions::new();
    options.append(true).read(true).create_new(new);
    OpenOptions::open(&options, directory.join(JOURNAL_FILE))
}

// The file operations of a file store. In a test or a diagnostics build each
// tells the model of a test that watches the files what it did, and fails
// where the test armed it to.

/// Create each directory of `directory` that does not exist, the outermost
/// first, and name them.
#[cfg_attr(not(any(test, feature = "fault-injection")), allow(unused_variables))]
fn create_directories(directory: &Path) -> std::io::Result<Vec<PathBuf>> {
    let mut missing = Vec::new();
    let mut at = Some(directory);
    while let Some(path) = at.filter(|path| !path.as_os_str().is_empty() && !path.exists()) {
        missing.push(path.to_path_buf());
        at = path.parent();
    }
    missing.reverse();
    fs::create_dir_all(directory)?;
    for path in &missing {
        #[cfg(any(test, feature = "fault-injection"))]
        crash_model::created_directory(path);
    }
    Ok(missing)
}

/// A new journal in `directory`, at `path`, to append to.
#[cfg_attr(not(any(test, feature = "fault-injection")), allow(unused_variables))]
fn create_journal(directory: &Path, path: &Path) -> std::io::Result<File> {
    let file = journal_file(directory, true)?;
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::created_file(path);
    Ok(file)
}

/// A file at `path` to write whole, empty: a new one, or the one there.
fn create_file(path: &Path) -> std::io::Result<File> {
    #[cfg(any(test, feature = "fault-injection"))]
    let armed = crash_model::fails(path, FileOperation::Write);
    #[cfg(not(any(test, feature = "fault-injection")))]
    let armed = false;
    if armed {
        return Err(injected("the file could not be created"));
    }
    let file = File::create(path)?;
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::created_file(path);
    Ok(file)
}

/// Sync `file`, which is at `path`.
#[cfg_attr(not(any(test, feature = "fault-injection")), allow(unused_variables))]
fn sync_file(file: &File, path: &Path) -> std::io::Result<()> {
    #[cfg(any(test, feature = "fault-injection"))]
    let armed = crash_model::fails(path, FileOperation::SyncFile);
    #[cfg(not(any(test, feature = "fault-injection")))]
    let armed = false;
    let synced = if armed {
        Err(injected("the sync failed"))
    } else {
        file.sync_data()
    };
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::synced_file(path, synced.is_ok());
    synced
}

/// The error of a sync of the file at `path` that a test made fail.
#[cfg_attr(not(any(test, feature = "fault-injection")), allow(unused_variables))]
fn sync_failed(path: &Path, what: &str) -> std::io::Error {
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::synced_file(path, false);
    injected(what)
}

/// Cut `file`, which is at `path`, to `len` bytes.
#[cfg_attr(not(any(test, feature = "fault-injection")), allow(unused_variables))]
fn truncate_file(file: &File, path: &Path, len: u64) -> std::io::Result<()> {
    file.set_len(len)?;
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::truncated(path, len);
    Ok(())
}

/// Rename the file at `from` to `to`, over the file there.
fn rename_file(from: &Path, to: &Path) -> std::io::Result<()> {
    #[cfg(any(test, feature = "fault-injection"))]
    let armed = crash_model::fails(to, FileOperation::Rename);
    #[cfg(not(any(test, feature = "fault-injection")))]
    let armed = false;
    if armed {
        return Err(injected("the rename failed"));
    }
    fs::rename(from, to)?;
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::renamed(from, to);
    Ok(())
}

/// Sync the directory `directory`: the names in it are on the device once
/// this returns.
fn sync_directory(directory: &Path) -> std::io::Result<()> {
    #[cfg(any(test, feature = "fault-injection"))]
    let armed = crash_model::fails(directory, FileOperation::SyncDirectory);
    #[cfg(not(any(test, feature = "fault-injection")))]
    let armed = false;
    let synced = if armed {
        Err(injected("the directory's sync failed"))
    } else {
        File::open(directory).and_then(|handle| handle.sync_all())
    };
    #[cfg(any(test, feature = "fault-injection"))]
    crash_model::synced_directory(directory, synced.is_ok());
    synced
}

/// Publish `entries`, the whole entries of the journal of the store in
/// `directory`: write them into a new file, sync it, rename it over the
/// journal, and sync the directory, as `sync` says. What the store serves
/// then rests on bytes a sync put on the device since they were read, not
/// on the journal a sync may have failed for. The journal, to append to.
fn publish_journal(directory: &Path, entries: &[u8], sync: SyncPolicy) -> Result<File> {
    let temp = directory.join(JOURNAL_TEMP_FILE);
    let mut file = create_file(&temp)?;
    file.write_all(entries)?;
    if sync == SyncPolicy::Always {
        sync_file(&file, &temp)?;
    }
    drop(file);
    rename_file(&temp, &directory.join(JOURNAL_FILE))?;
    if sync == SyncPolicy::Always {
        sync_directory(directory)?;
    }
    Ok(journal_file(directory, false)?)
}

impl FileStorage {
    /// A new store in `directory`, which must not hold one. Under
    /// `SyncPolicy::Always` it is on the device when this returns: the
    /// journal and the snapshot are synced, then the directory that holds
    /// them, then each directory this made, in the one above it, the
    /// innermost first. A directory that was there is the caller's to have
    /// put on the device. If any of this fails, no store is made.
    pub fn create(directory: impl AsRef<Path>, sync: SyncPolicy) -> Result<Self> {
        let directory = directory.as_ref().to_path_buf();
        let made = create_directories(&directory)
            .with_context(|| format!("creating {}", directory.display()))?;
        if directory.join(SNAPSHOT_FILE).exists() || directory.join(JOURNAL_FILE).exists() {
            bail!("{} already holds a store", directory.display());
        }
        let journal_path = directory.join(JOURNAL_FILE);
        let journal = create_journal(&directory, &journal_path)
            .with_context(|| format!("creating the journal in {}", directory.display()))?;
        if sync == SyncPolicy::Always {
            sync_file(&journal, &journal_path)
                .with_context(|| format!("syncing the journal in {}", directory.display()))?;
        }
        let image = MemoryStorage::new();
        // The snapshot's rename and the directory's sync after it put both
        // names on the device.
        write_snapshot(&directory, &image, sync, None)?;
        if sync == SyncPolicy::Always {
            for made in made.iter().rev() {
                if let Some(above) = made.parent() {
                    sync_directory(above)
                        .with_context(|| format!("syncing {}", above.display()))?;
                }
            }
        }
        Ok(Self {
            image,
            directory,
            journal,
            journal_path,
            journal_bytes: 0,
            checkpoint_bytes: None,
            sync,
            poisoned: None,
            cut_on_open: 0,
            #[cfg(any(test, feature = "fault-injection"))]
            fault: None,
        })
    }

    /// Write a snapshot and empty the journal after a commit that leaves
    /// the journal longer than `bytes`: the journal then stays near that
    /// length, whatever the number of commits.
    pub fn with_checkpoint_bytes(mut self, bytes: u64) -> Self {
        self.checkpoint_bytes = Some(bytes);
        self
    }

    /// The store in `directory`, as its last commit left it. The journal's
    /// last entry, if an append left it cut short or damaged, is cut off
    /// (`bytes_cut_on_open`). A journal in which a whole entry follows a
    /// damaged one is refused: that entry was appended after one that
    /// failed, and dropping it could drop a commit that was acknowledged.
    ///
    /// The store publishes what it read before it returns
    /// (`publish_journal`): under `SyncPolicy::Always`, whatever it serves,
    /// and so whatever a restart from it resolves, is on the device, though
    /// the journal held an entry whose sync failed. If the publication
    /// fails, the open fails, and the files hold every whole entry they
    /// held. One adapter at a time has a store's files open: the
    /// publication replaces the journal, and an adapter that had the old
    /// one would append to a file that is no longer the journal.
    pub fn open(directory: impl AsRef<Path>, sync: SyncPolicy) -> Result<Self> {
        let directory = directory.as_ref().to_path_buf();
        let snapshot = fs::read(directory.join(SNAPSHOT_FILE))
            .with_context(|| format!("reading the snapshot in {}", directory.display()))?;
        let (payload, _) = read_frame(SNAPSHOT_MAGIC, &snapshot)
            .ok_or_else(|| anyhow!("the snapshot in {} is damaged", directory.display()))?;
        let mut image = MemoryStorage::new();
        load_snapshot(&mut image, payload)?;
        let mut entries = Vec::new();
        journal_file(&directory, false)
            .and_then(|mut journal| journal.read_to_end(&mut entries))
            .with_context(|| format!("opening the journal in {}", directory.display()))?;
        let mut offset = 0usize;
        while let Some((payload, len)) = entries
            .get(offset..)
            .and_then(|rest| read_frame(JOURNAL_MAGIC, rest))
        {
            load_journal_entry(&mut image, payload)?;
            offset += len;
        }
        if offset != entries.len() {
            // What follows the last whole entry is the last append, which
            // did not finish. No whole entry may follow it.
            if let Some(later) = (offset + 1..entries.len())
                .find(|&at| read_frame(JOURNAL_MAGIC, &entries[at..]).is_some())
            {
                bail!(
                    "the journal in {} holds a whole entry at byte {later} after a damaged one at byte {offset}: it was appended after an append that failed, and the journal is refused",
                    directory.display()
                );
            }
        }
        let journal = publish_journal(&directory, &entries[..offset], sync).with_context(|| {
            format!(
                "publishing the store in {} before it is served: nothing is served, and the files hold every whole entry they held",
                directory.display()
            )
        })?;
        Ok(Self {
            image,
            journal_path: directory.join(JOURNAL_FILE),
            directory,
            journal,
            journal_bytes: offset as u64,
            checkpoint_bytes: None,
            sync,
            poisoned: None,
            cut_on_open: (entries.len() - offset) as u64,
            #[cfg(any(test, feature = "fault-injection"))]
            fault: None,
        })
    }

    /// Write a snapshot of every record and empty the journal. The snapshot
    /// replaces the one in place before the journal is emptied, so a
    /// checkpoint that fails at any step leaves every commit in the files,
    /// in the snapshot or in the journal. It then makes the store refuse
    /// every operation, as a failed append does.
    pub fn checkpoint(&mut self) -> Result<()> {
        self.refuse_if_poisoned()?;
        if !self.image.pending.is_empty() {
            return Err(StorageError::definite(
                "the store holds records that were neither committed nor abandoned",
            ));
        }
        let fail_at = self.take_checkpoint_fault();
        if let Err(error) = self.write_checkpoint(fail_at) {
            let reason = format!("a checkpoint failed ({error:#})");
            let message = format!(
                "{reason}: the files of {} hold every commit, in the snapshot or the journal, and the store refuses every operation until they are opened again",
                self.directory.display()
            );
            self.poisoned = Some(reason);
            return Err(StorageError::definite(message));
        }
        Ok(())
    }

    fn write_checkpoint(&mut self, fail_at: Option<CheckpointStep>) -> Result<()> {
        write_snapshot(&self.directory, &self.image, self.sync, fail_at)?;
        if fail_at == Some(CheckpointStep::JournalTruncation) {
            return Err(injected("the journal's truncation failed").into());
        }
        truncate_file(&self.journal, &self.journal_path, 0)?;
        self.journal.seek(SeekFrom::End(0))?;
        self.journal_bytes = 0;
        if self.sync == SyncPolicy::Always {
            sync_file(&self.journal, &self.journal_path)?;
            self.image.stats.syncs += 1;
        }
        Ok(())
    }

    /// The bytes after the journal's last whole entry that `open` cut off:
    /// an append that never finished.
    pub fn bytes_cut_on_open(&self) -> u64 {
        self.cut_on_open
    }

    /// Arm `fault` for the next operation it names. Only a test or a
    /// diagnostics build can.
    #[cfg(any(test, feature = "fault-injection"))]
    pub fn inject_fault(&mut self, fault: StorageFault) {
        self.fault = Some(fault);
    }

    /// The failure armed for the next append.
    #[cfg(any(test, feature = "fault-injection"))]
    fn take_append_fault(&mut self) -> Option<AppendFailure> {
        match self.fault {
            Some(StorageFault::Append { failure }) => {
                self.fault = None;
                Some(failure)
            }
            _ => None,
        }
    }

    #[cfg(not(any(test, feature = "fault-injection")))]
    fn take_append_fault(&mut self) -> Option<AppendFailure> {
        None
    }

    /// The step at which the next checkpoint is armed to fail.
    #[cfg(any(test, feature = "fault-injection"))]
    fn take_checkpoint_fault(&mut self) -> Option<CheckpointStep> {
        match self.fault {
            Some(StorageFault::Checkpoint { step }) => {
                self.fault = None;
                Some(step)
            }
            _ => None,
        }
    }

    #[cfg(not(any(test, feature = "fault-injection")))]
    fn take_checkpoint_fault(&mut self) -> Option<CheckpointStep> {
        None
    }

    /// Fail, naming why, once an append or a checkpoint failed. The error
    /// is definite: the refused operation touched no file.
    fn refuse_if_poisoned(&self) -> Result<()> {
        match &self.poisoned {
            Some(reason) => Err(StorageError::definite(format!(
                "the store in {} refuses every operation since {reason}; open its directory again",
                self.directory.display()
            ))),
            None => Ok(()),
        }
    }

    pub fn directory(&self) -> &Path {
        &self.directory
    }

    /// The bytes of the journal: what the commits since the last snapshot
    /// take on the device.
    pub fn journal_bytes(&self) -> Result<u64> {
        Ok(self.journal.metadata()?.len())
    }

    fn journal_passed_its_checkpoint(&self) -> bool {
        self.checkpoint_bytes
            .is_some_and(|limit| self.journal_bytes > limit)
    }

    /// Append an entry to the journal and sync it as the policy says. If
    /// either fails, the entry may be in the files whole or not at all: the
    /// error says the outcome is unknown, and the store refuses every later
    /// operation, so that nothing is appended after the failed entry.
    fn append(&mut self, payload: &[u8]) -> Result<()> {
        self.refuse_if_poisoned()?;
        let started = Instant::now();
        let entry = frame(JOURNAL_MAGIC, payload);
        let fault = self.take_append_fault();
        if let Err(error) = self.write_entry(&entry, fault) {
            let reason = format!("the append of a commit to its journal failed ({error})");
            let message = format!(
                "{reason}: the files of {} hold the commit whole or not at all, which opening them again shows, and the store refuses every operation until then",
                self.directory.display()
            );
            self.poisoned = Some(reason);
            return Err(StorageError::outcome_unknown(message));
        }
        self.journal_bytes += entry.len() as u64;
        self.image.stats.persisted_bytes += entry.len() as u64;
        self.image.stats.persist_ns +=
            u64::try_from(started.elapsed().as_nanos()).unwrap_or(u64::MAX);
        Ok(())
    }

    /// Write `entry` at the end of the journal and sync it as the policy
    /// says, or fail as `fault` says.
    fn write_entry(&mut self, entry: &[u8], fault: Option<AppendFailure>) -> std::io::Result<()> {
        if let Some(written) = fault.and_then(|fault| fault.written(entry.len())) {
            self.journal.write_all(&entry[..written])?;
            return Err(injected("the write stopped part way"));
        }
        self.journal.write_all(entry)?;
        if fault == Some(AppendFailure::SyncFails) {
            return Err(sync_failed(
                &self.journal_path,
                "the sync after a whole write failed",
            ));
        }
        if self.sync == SyncPolicy::Always {
            sync_file(&self.journal, &self.journal_path)?;
            self.image.stats.syncs += 1;
        }
        Ok(())
    }
}

fn put_record(out: &mut Vec<u8>, image: &MemoryStorage, record: &StoredRecord) -> Result<()> {
    put_bytes(out, image.object_name(record.object).as_bytes())?;
    put_bytes(out, record.location.as_bytes())?;
    put_bytes(out, &record.bytes)
}

fn put_public_record(
    out: &mut Vec<u8>,
    image: &MemoryStorage,
    location: &str,
    record: &PublicRecord,
) -> Result<()> {
    put_bytes(out, image.object_name(record.object).as_bytes())?;
    put_bytes(out, location.as_bytes())?;
    put_bytes(out, &record.bytes)
}

fn count(len: usize) -> Result<u32> {
    u32::try_from(len).map_err(|_| anyhow!("the store holds too many records"))
}

/// Write a snapshot of `image` beside the one in place and rename it over
/// that one, or fail at `fail_at`.
fn write_snapshot(
    directory: &Path,
    image: &MemoryStorage,
    sync: SyncPolicy,
    fail_at: Option<CheckpointStep>,
) -> Result<()> {
    let mut payload = Vec::new();
    put_bytes(&mut payload, &image.meta)?;
    put_u32(&mut payload, count(image.objects.len())?);
    for object in &image.objects {
        put_bytes(&mut payload, object.name.as_bytes())?;
        put_u64(&mut payload, object.reserved_seals);
    }
    put_u32(&mut payload, count(image.records.len())?);
    for record in &image.records {
        put_record(&mut payload, image, record)?;
    }
    let mut public: Vec<(&str, &PublicRecord)> = image
        .public
        .iter()
        .map(|(location, record)| (&**location, record))
        .collect();
    public.sort_by(|left, right| left.0.cmp(right.0));
    put_u32(&mut payload, count(public.len())?);
    for (location, record) in public {
        put_public_record(&mut payload, image, location, record)?;
    }
    let temp = directory.join(SNAPSHOT_TEMP_FILE);
    let mut file = create_file(&temp).with_context(|| format!("creating {}", temp.display()))?;
    let snapshot = frame(SNAPSHOT_MAGIC, &payload);
    if fail_at == Some(CheckpointStep::SnapshotWrite) {
        file.write_all(&snapshot[..snapshot.len() / 2])?;
        return Err(injected("the snapshot's write stopped part way").into());
    }
    file.write_all(&snapshot)?;
    if sync == SyncPolicy::Always {
        sync_file(&file, &temp)?;
    }
    drop(file);
    if fail_at == Some(CheckpointStep::SnapshotRename) {
        return Err(injected("the snapshot's rename failed").into());
    }
    rename_file(&temp, &directory.join(SNAPSHOT_FILE))?;
    if sync == SyncPolicy::Always {
        // The rename is on the device once the directory is.
        sync_directory(directory)?;
    }
    Ok(())
}

fn load_records(image: &mut MemoryStorage, decoder: &mut Decoder<'_>) -> Result<()> {
    for _ in 0..decoder.u32()? {
        let object = decoder.text()?;
        let location = decoder.text()?;
        let bytes = decoder.blob()?;
        image.load_record(object, location, bytes)?;
    }
    for _ in 0..decoder.u32()? {
        let object = decoder.text()?;
        let location = decoder.text()?;
        let bytes = decoder.blob()?;
        image.load_public(object, location, bytes)?;
    }
    Ok(())
}

fn load_snapshot(image: &mut MemoryStorage, payload: &[u8]) -> Result<()> {
    let mut decoder = Decoder { bytes: payload };
    image.meta = decoder.blob()?.to_vec();
    load_reservations(image, &mut decoder)?;
    load_records(image, &mut decoder)?;
    decoder.finish()
}

fn load_reservations(image: &mut MemoryStorage, decoder: &mut Decoder<'_>) -> Result<()> {
    for _ in 0..decoder.u32()? {
        let object = decoder.text()?;
        let below = decoder.u64()?;
        image.load_reservation(object, below)?;
    }
    Ok(())
}

fn load_journal_entry(image: &mut MemoryStorage, payload: &[u8]) -> Result<()> {
    let mut decoder = Decoder { bytes: payload };
    match decoder.u8()? {
        ENTRY_COMMIT => {
            let meta = decoder.blob()?.to_vec();
            load_reservations(image, &mut decoder)?;
            load_records(image, &mut decoder)?;
            image.meta = meta;
        }
        other => bail!("the journal holds an entry of unknown kind {other}"),
    }
    decoder.finish()
}

impl StorageAdapter for FileStorage {
    fn create(&mut self, object: &str, location: &str, record: &[u8]) -> Result<()> {
        self.refuse_if_poisoned()?;
        self.image.create(object, location, record)
    }

    fn read(&mut self, location: &str, len: usize) -> Result<Box<[u8]>> {
        self.refuse_if_poisoned()?;
        self.image.read(location, len)
    }

    fn write(&mut self, location: &str, record: &[u8]) -> Result<WriteClass> {
        self.refuse_if_poisoned()?;
        self.image.write(location, record)
    }

    fn put_public(&mut self, object: &str, location: &str, value: &[u8]) -> Result<()> {
        self.refuse_if_poisoned()?;
        self.image.put_public(object, location, value)
    }

    fn reserve_seals(&mut self, object: &str, below: u64) -> Result<()> {
        self.refuse_if_poisoned()?;
        // The reservation is written with the next commit, and takes effect
        // in a call once that commit is in the journal.
        self.image.reserve_seals(object, below)
    }

    fn reserved_seals(&self, object: &str) -> u64 {
        self.image.reserved_seals(object)
    }

    fn begin(&mut self) -> Result<()> {
        self.refuse_if_poisoned()?;
        self.image.begin()
    }

    fn commit(&mut self, meta: &[u8]) -> Result<()> {
        self.refuse_if_poisoned()?;
        let payload = self
            .commit_payload(meta)
            .map_err(|error| StorageError::definite(format!("{error:#}")))?;
        self.append(&payload)?;
        self.image.finish_commit(meta);
        if self.journal_passed_its_checkpoint() {
            // The commit is in the journal, so it stands. A checkpoint that
            // fails leaves every commit in the files and makes the store
            // refuse every later operation.
            let started = Instant::now();
            let _ = self.checkpoint();
            self.image.stats.persist_ns +=
                u64::try_from(started.elapsed().as_nanos()).unwrap_or(u64::MAX);
        }
        Ok(())
    }

    fn abandon(&mut self) {
        self.image.abandon();
    }

    fn log(&self) -> Vec<StorageIo> {
        self.image.log()
    }

    fn set_logging(&mut self, logging: bool) {
        self.image.set_logging(logging);
    }

    fn record(&self, location: &str) -> Option<&[u8]> {
        self.image.record(location)
    }

    fn public_records(&self, object: &str) -> Vec<(String, Vec<u8>)> {
        self.image.public_records(object)
    }

    fn sealed_records_sha256(&self) -> String {
        self.image.sealed_records_sha256()
    }

    fn seal_counts(&self, object: &str) -> Vec<u64> {
        self.image.seal_counts(object)
    }

    fn meta(&self) -> &[u8] {
        self.image.meta()
    }

    fn stats(&self) -> StorageStats {
        self.image.stats()
    }

    fn poisoned(&self) -> Option<String> {
        self.poisoned.clone()
    }

    #[cfg(any(test, feature = "fault-injection"))]
    fn inject_fault(&mut self, fault: StorageFault) -> Result<()> {
        FileStorage::inject_fault(self, fault);
        Ok(())
    }
}

impl FileStorage {
    /// The journal entry of a commit of the pending records, with `meta`
    /// and the reservations made since the last commit.
    fn commit_payload(&self, meta: &[u8]) -> Result<Vec<u8>> {
        let mut payload = vec![ENTRY_COMMIT];
        put_bytes(&mut payload, meta)?;
        let reservations = self.image.staged_reservations();
        put_u32(&mut payload, count(reservations.len())?);
        for (object, below) in reservations {
            put_bytes(&mut payload, object.as_bytes())?;
            put_u64(&mut payload, below);
        }
        let (records, public) = self.image.pending_changes();
        put_u32(&mut payload, count(records.len())?);
        for id in records {
            let record = self
                .image
                .records
                .get(id as usize)
                .ok_or_else(|| anyhow!("the store's index names a record it does not hold"))?;
            put_record(&mut payload, &self.image, record)?;
        }
        put_u32(&mut payload, count(public.len())?);
        for location in public {
            let record = self.image.public.get(location).ok_or_else(|| {
                anyhow!("the store's index names a public value it does not hold")
            })?;
            put_public_record(&mut payload, &self.image, location, record)?;
        }
        Ok(payload)
    }
}

/// The store of one deployed contract, shared by the objects whose records
/// it keeps.
#[derive(Clone)]
pub struct SharedStorage(Arc<Mutex<Box<dyn StorageAdapter>>>);

impl fmt::Debug for SharedStorage {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SharedStorage").finish_non_exhaustive()
    }
}

impl SharedStorage {
    pub fn new(adapter: impl StorageAdapter + 'static) -> Self {
        Self(Arc::new(Mutex::new(Box::new(adapter))))
    }

    /// A store that keeps its records in memory.
    pub fn memory() -> Self {
        Self::new(MemoryStorage::new())
    }

    /// Run `f` on the adapter.
    pub fn with<T>(&self, f: impl FnOnce(&mut dyn StorageAdapter) -> T) -> T {
        let mut adapter = self
            .0
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        f(adapter.as_mut())
    }

    /// Reserve, for each object, the seal counts below its count, for the
    /// next commit to make durable (`StorageAdapter::reserve_seals`).
    pub fn reserve_seals<'a>(
        &self,
        reservations: impl IntoIterator<Item = (&'a str, u64)>,
    ) -> Result<()> {
        self.with(|adapter| {
            for (object, below) in reservations {
                adapter.reserve_seals(object, below)?;
            }
            Ok(())
        })
    }

    /// Why the store refuses every operation, if it does.
    pub fn poisoned(&self) -> Option<String> {
        self.with(|adapter| adapter.poisoned())
    }

    /// Arm `fault` for the next operation it names. Only a test or a
    /// diagnostics build can.
    #[cfg(any(test, feature = "fault-injection"))]
    pub fn inject_fault(&self, fault: StorageFault) -> Result<()> {
        self.with(|adapter| adapter.inject_fault(fault))
    }

    pub fn handle(&self, object: &str) -> StorageHandle {
        StorageHandle {
            storage: self.clone(),
            object: object.into(),
        }
    }
}

/// The records of one object in its contract's store.
#[derive(Clone)]
pub struct StorageHandle {
    storage: SharedStorage,
    object: Arc<str>,
}

impl fmt::Debug for StorageHandle {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("StorageHandle")
            .field("object", &self.object)
            .finish_non_exhaustive()
    }
}

impl StorageHandle {
    pub fn object(&self) -> &str {
        &self.object
    }

    /// Hand the store the first record of `location`.
    pub fn create(&self, location: &str, record: &[u8]) -> Result<()> {
        self.storage
            .with(|adapter| adapter.create(&self.object, location, record))
    }

    /// See `StorageAdapter::read`.
    pub fn read(&self, location: &str, len: usize) -> Result<Box<[u8]>> {
        self.storage.with(|adapter| adapter.read(location, len))
    }

    /// See `StorageAdapter::write`.
    pub fn write(&self, location: &str, record: &[u8]) -> Result<WriteClass> {
        self.storage.with(|adapter| adapter.write(location, record))
    }

    pub fn put_public(&self, location: &str, value: &[u8]) -> Result<()> {
        self.storage
            .with(|adapter| adapter.put_public(&self.object, location, value))
    }

    /// Reserve the seal counts below `sealed`, the count of the seals made
    /// under the object's key so far, for the next commit to make durable. A
    /// deployment's records need it; a call's are below the reservation of
    /// the last commit, which the store checks.
    pub fn reserve_seals(&self, sealed: u64) -> Result<()> {
        self.storage
            .with(|adapter| adapter.reserve_seals(&self.object, sealed))
    }

    /// The reservation of the last commit for the object's key.
    pub fn reserved_seals(&self) -> u64 {
        self.storage
            .with(|adapter| adapter.reserved_seals(&self.object))
    }

    /// A copy of the record the store keeps at `location`.
    pub fn record(&self, location: &str) -> Option<Box<[u8]>> {
        self.storage
            .with(|adapter| adapter.record(location).map(Box::from))
    }

    /// Hand `visit` the record the store keeps at `location`, with no copy
    /// and no read logged: what a digest of the store's ciphertext reads.
    pub fn with_record<T>(&self, location: &str, visit: impl FnOnce(&[u8]) -> T) -> Option<T> {
        self.storage
            .with(|adapter| adapter.record(location).map(visit))
    }

    pub fn public_records(&self) -> Vec<(String, Vec<u8>)> {
        self.storage
            .with(|adapter| adapter.public_records(&self.object))
    }

    /// The counts of the store this object's records are in.
    pub fn stats(&self) -> StorageStats {
        self.storage.with(|adapter| adapter.stats())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::StoreCipher;
    use std::sync::atomic::{AtomicU32, Ordering};

    /// A record of `payload` that replaces none.
    fn sealed(cipher: &StoreCipher, payload: &[u8]) -> Box<[u8]> {
        let mut payload = payload.to_vec();
        cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload)
            .unwrap()
    }

    /// A record of `payload` sealed over `record`.
    fn resealed(cipher: &StoreCipher, record: &[u8], payload: &[u8]) -> Box<[u8]> {
        let mut out: Box<[u8]> = record.into();
        let mut payload = payload.to_vec();
        assert!(cipher.seal_and_wipe_into_slice(b"object:slot", &mut payload, &mut out));
        out
    }

    fn scratch_directory(name: &str) -> PathBuf {
        static NEXT: AtomicU32 = AtomicU32::new(0);
        let directory = std::env::temp_dir().join(format!(
            "uo-store-{name}-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::SeqCst)
        ));
        let _ = fs::remove_dir_all(&directory);
        directory
    }

    #[test]
    fn the_adapter_logs_reads_and_classifies_writes_from_its_own_records() {
        let cipher = StoreCipher::random();
        let mut store = MemoryStorage::new();
        store.reserve_seals("balances", 100).unwrap();
        let first = sealed(&cipher, &[1u8; 40]);
        store.create("balances", "balances#0", &first).unwrap();
        store.commit(b"deployed").unwrap();

        store.begin().unwrap();
        assert_eq!(*store.read("balances#0", first.len()).unwrap(), *first);
        let second = resealed(&cipher, &first, &[2u8; 40]);
        assert_eq!(
            store.write("balances#0", &second).unwrap(),
            WriteClass::Update
        );
        // The same record again changes no unit, and zeros clear every unit:
        // the adapter says so, whatever the caller meant to write.
        assert_eq!(
            store.write("balances#0", &second).unwrap(),
            WriteClass::Same
        );
        store.abandon();
        store.begin().unwrap();
        assert!(store.log().is_empty());
        assert_eq!(*store.read("balances#0", first.len()).unwrap(), *first);
        assert_eq!(
            store.write("balances#0", &second).unwrap(),
            WriteClass::Update
        );
        store.commit(b"called").unwrap();

        assert_eq!(
            store.log(),
            vec![
                StorageIo::Read {
                    object: "balances".into(),
                    location: "balances#0".into(),
                    len: first.len(),
                },
                StorageIo::Write {
                    object: "balances".into(),
                    location: "balances#0".into(),
                    len: second.len(),
                    class: WriteClass::Update,
                },
            ]
        );
        assert_eq!(store.record("balances#0"), Some(&*second));
        assert_eq!(store.meta(), b"called");
        // A record of another length is not a write of this location.
        store.begin().unwrap();
        let longer = sealed(&cipher, &[3u8; 80]);
        assert!(store.write("balances#0", &longer).is_err());
        assert!(store.write("balances#1", &second).is_err());
    }

    #[test]
    fn a_sealed_write_is_an_update_only_if_every_unit_is() {
        let old = [0xA5u8; 64];
        let mut new = [0x5Au8; 64];
        assert_eq!(sealed_write_class(&old, &new), WriteClass::Update);
        new[32..].copy_from_slice(&old[32..]);
        assert_eq!(sealed_write_class(&old, &new), WriteClass::Same);
        new[32..].fill(0);
        assert_eq!(sealed_write_class(&old, &new), WriteClass::Clear);
        let mut zero_before = old;
        zero_before[..32].fill(0);
        assert_eq!(
            sealed_write_class(&zero_before, &[0x5Au8; 64]),
            WriteClass::Set
        );
        assert_eq!(sealed_write_class(&old, &old), WriteClass::Same);
    }

    #[test]
    fn a_read_copies_the_stored_record_of_the_length_the_runtime_expects() {
        let cipher = StoreCipher::random();
        let mut store = MemoryStorage::new();
        store.reserve_seals("cell", 10).unwrap();
        let record = sealed(&cipher, &[9u8; 32]);
        store.create("cell", "cell", &record).unwrap();
        store.commit(b"").unwrap();
        store.begin().unwrap();
        assert!(store.read("cell", record.len() - 32).is_err());
        assert!(store.read("cell", record.len() + 32).is_err());
        assert!(store.read("missing", record.len()).is_err());
        assert!(store.log().is_empty());
        assert_eq!(*store.read("cell", record.len()).unwrap(), *record);
        assert_eq!(store.log().len(), 1);
        assert_eq!(store.stats().reads, 1);
        assert_eq!(store.stats().read_bytes, record.len() as u64);
    }

    #[test]
    fn abandon_puts_back_what_a_call_replaced_created_and_published() {
        let cipher = StoreCipher::random();
        let mut store = MemoryStorage::new();
        store.reserve_seals("map", 100).unwrap();
        let first = sealed(&cipher, &[1u8; 32]);
        store.create("map", "map#0", &first).unwrap();
        store.put_public("supply", "supply", b"1").unwrap();
        store.commit(b"one").unwrap();
        let committed_digest = store.sealed_records_sha256();

        store.begin().unwrap();
        let second = resealed(&cipher, &first, &[2u8; 32]);
        let third = resealed(&cipher, &second, &[3u8; 32]);
        store.write("map#0", &second).unwrap();
        store.write("map#0", &third).unwrap();
        assert_ne!(store.sealed_records_sha256(), committed_digest);
        store
            .create("map", "map#1", &sealed(&cipher, &[4u8; 32]))
            .unwrap();
        store.put_public("supply", "supply", b"2").unwrap();
        store.put_public("supply", "supply::k", b"3").unwrap();
        assert!(store.begin().is_err());
        store.abandon();

        // Two writes of one record leave one thing to put back: the record
        // of the last commit.
        assert_eq!(store.sealed_records_sha256(), committed_digest);
        assert_eq!(store.record("map#0"), Some(&*first));
        assert_eq!(store.record("map#1"), None);
        assert_eq!(
            store.public_records("supply"),
            vec![("supply".to_string(), b"1".to_vec())]
        );
        assert_eq!(store.meta(), b"one");
        // The store takes the next call, and logs none of it when told not
        // to.
        store.begin().unwrap();
        store.set_logging(false);
        store.read("map#0", first.len()).unwrap();
        store.write("map#0", &second).unwrap();
        store.write("map#0", &third).unwrap();
        store.commit(b"two").unwrap();
        assert!(store.log().is_empty());
        assert_eq!(store.record("map#0"), Some(&*third));
        store.set_logging(true);
        store.begin().unwrap();
        assert_eq!(*store.read("map#0", third.len()).unwrap(), *third);
        assert_eq!(store.log().len(), 1);
    }

    #[test]
    fn a_record_is_refused_until_its_nonce_is_reserved() {
        let cipher = StoreCipher::random();
        let mut store = MemoryStorage::new();
        let record = sealed(&cipher, &[1u8; 32]);
        assert_eq!(sealed_record_seal_count(&record), Some(0));
        // Nothing is reserved for the object, so its first record is refused.
        assert!(store.create("cell", "cell", &record).is_err());
        // A deployment's record is taken under the reservation its commit
        // makes durable.
        store.reserve_seals("cell", 1).unwrap();
        store.create("cell", "cell", &record).unwrap();
        assert_eq!(store.reserved_seals("cell"), 0);
        store.commit(b"deployed").unwrap();
        assert_eq!(store.reserved_seals("cell"), 1);
        // In a call, the next seal has count 1, which the last commit's
        // reservation does not cover; a reservation made in the call takes
        // effect after the call's commit.
        let next = resealed(&cipher, &record, &[2u8; 32]);
        assert_eq!(sealed_record_seal_count(&next), Some(1));
        store.begin().unwrap();
        store.reserve_seals("cell", 2).unwrap();
        let refused = store.write("cell", &next).unwrap_err().to_string();
        assert!(
            refused.contains("durable reservation of the last commit"),
            "{refused}"
        );
        assert_eq!(store.record("cell"), Some(&*record));
        store.commit(b"reserved").unwrap();
        assert_eq!(store.reserved_seals("cell"), 2);
        store.begin().unwrap();
        assert_eq!(store.write("cell", &next).unwrap(), WriteClass::Update);
        store.commit(b"called").unwrap();
        assert_eq!(store.seal_counts("cell"), vec![1]);
        // A reservation only grows, and bytes that are no record are refused.
        store.reserve_seals("cell", 1).unwrap();
        store.commit(b"lower").unwrap();
        assert_eq!(store.reserved_seals("cell"), 2);
        store.begin().unwrap();
        assert!(store.write("cell", &vec![0u8; next.len()]).is_err());
        store.abandon();
        assert_eq!(store.reserved_seals("other"), 0);
    }

    #[test]
    fn a_handle_reserves_the_seals_made_for_the_next_commit() {
        let storage = SharedStorage::memory();
        let handle = storage.handle("cell");
        handle.reserve_seals(0).unwrap();
        handle.reserve_seals(3).unwrap();
        // Staged until the next commit makes it durable.
        assert_eq!(handle.reserved_seals(), 0);
        let reservations = storage.with(|adapter| adapter.stats().reservations);
        handle.reserve_seals(3).unwrap();
        handle.reserve_seals(2).unwrap();
        assert_eq!(
            storage.with(|adapter| adapter.stats().reservations),
            reservations
        );
        storage.with(|adapter| adapter.commit(b"deployed")).unwrap();
        assert_eq!(handle.reserved_seals(), 3);
        // Several objects at once.
        storage
            .reserve_seals([("cell", 1u64 << 33), ("other", 5)])
            .unwrap();
        storage.with(|adapter| adapter.commit(b"reserved")).unwrap();
        assert_eq!(handle.reserved_seals(), 1 << 33);
        assert_eq!(storage.handle("other").reserved_seals(), 5);
    }

    #[test]
    fn a_file_store_reopens_as_its_last_commit_left_it() {
        let directory = scratch_directory("reopen");
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let third = resealed(&cipher, &second, &[3u8; 48]);
        {
            let mut store = FileStorage::create(&directory, SyncPolicy::Always).unwrap();
            assert!(FileStorage::create(&directory, SyncPolicy::Always).is_err());
            store.reserve_seals("map", 8).unwrap();
            store.create("map", "map#0", &first).unwrap();
            store.put_public("owner", "owner", b"\"a\"").unwrap();
            store.commit(b"deployed").unwrap();
            store.begin().unwrap();
            store.write("map#0", &second).unwrap();
            store.commit(b"first call").unwrap();
            // A call that is abandoned leaves nothing in the files.
            store.begin().unwrap();
            store.write("map#0", &third).unwrap();
            store.put_public("owner", "owner", b"\"b\"").unwrap();
            store.abandon();
            // One sync for each commit; a reservation is written with one.
            assert_eq!(store.stats().syncs, 2);
            assert!(store.stats().persisted_bytes > 0);
        }
        {
            let mut store = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
            assert_eq!(store.record("map#0"), Some(&*second));
            assert_eq!(store.meta(), b"first call");
            assert_eq!(store.reserved_seals("map"), 8);
            assert_eq!(
                store.public_records("owner"),
                vec![("owner".to_string(), b"\"a\"".to_vec())]
            );
            store.begin().unwrap();
            assert_eq!(*store.read("map#0", second.len()).unwrap(), *second);
            store.write("map#0", &third).unwrap();
            store.commit(b"second call").unwrap();
            store.checkpoint().unwrap();
            assert_eq!(store.journal_bytes().unwrap(), 0);
            // A reservation no commit made durable is not in the files.
            store.reserve_seals("map", 20).unwrap();
        }
        {
            // A journal that passes its checkpoint is emptied by the commit
            // that takes it there, and the store reopens as that commit
            // left it, with the reservation it made durable.
            let mut store = FileStorage::open(&directory, SyncPolicy::Never)
                .unwrap()
                .with_checkpoint_bytes(64);
            assert_eq!(store.reserved_seals("map"), 8);
            let fourth = resealed(&cipher, &third, &[4u8; 48]);
            store.begin().unwrap();
            store.write("map#0", &fourth).unwrap();
            store.reserve_seals("map", 20).unwrap();
            store.commit(b"third call").unwrap();
            assert_eq!(store.journal_bytes().unwrap(), 0);
            store.begin().unwrap();
            store.write("map#0", &third).unwrap();
            store.commit(b"second call").unwrap();
        }
        let store = FileStorage::open(&directory, SyncPolicy::Never).unwrap();
        assert_eq!(store.record("map#0"), Some(&*third));
        assert_eq!(store.meta(), b"second call");
        assert_eq!(store.reserved_seals("map"), 20);
        fs::remove_dir_all(&directory).unwrap();
    }

    #[test]
    fn a_commit_that_was_cut_short_is_dropped_whole() {
        let directory = scratch_directory("torn");
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let third = resealed(&cipher, &second, &[3u8; 48]);
        let whole = {
            let mut store = FileStorage::create(&directory, SyncPolicy::Never).unwrap();
            store.reserve_seals("map", 8).unwrap();
            store.create("map", "map#0", &first).unwrap();
            store.commit(b"deployed").unwrap();
            store.begin().unwrap();
            store.write("map#0", &second).unwrap();
            store.commit(b"first").unwrap();
            let whole = store.journal_bytes().unwrap();
            store.begin().unwrap();
            store.write("map#0", &third).unwrap();
            store.commit(b"second").unwrap();
            whole
        };
        let journal = directory.join(JOURNAL_FILE);
        let full = fs::metadata(&journal).unwrap().len();
        assert!(full > whole);
        // Cut the last entry at each of a few lengths: a header alone, half
        // a payload, all but one byte of the digest.
        for cut in [whole + 5, (whole + full) / 2, full - 1] {
            let bytes = fs::read(&journal).unwrap();
            fs::write(&journal, &bytes[..cut as usize]).unwrap();
            let store = FileStorage::open(&directory, SyncPolicy::Never).unwrap();
            assert_eq!(store.record("map#0"), Some(&*second), "cut at {cut}");
            assert_eq!(store.meta(), b"first");
            assert_eq!(store.journal_bytes().unwrap(), whole);
            assert_eq!(store.bytes_cut_on_open(), cut - whole);
            drop(store);
            fs::write(&journal, &bytes).unwrap();
        }
        // A flipped byte inside the last entry fails its digest.
        let mut bytes = fs::read(&journal).unwrap();
        let flipped = (whole + (full - whole) / 2) as usize;
        bytes[flipped] ^= 1;
        fs::write(&journal, &bytes).unwrap();
        let store = FileStorage::open(&directory, SyncPolicy::Never).unwrap();
        assert_eq!(store.record("map#0"), Some(&*second));
        fs::remove_dir_all(&directory).unwrap();
    }

    /// Every operation a poisoned store refuses, each with an error that
    /// says nothing reached the files and names why it refuses.
    fn assert_refuses_everything(store: &mut FileStorage, record: &[u8]) {
        let journal = store.journal_bytes().unwrap();
        let refusals: Vec<(&str, anyhow::Error)> = vec![
            ("begin", store.begin().unwrap_err()),
            ("commit", store.commit(b"refused").unwrap_err()),
            ("reserve", store.reserve_seals("map", 1 << 40).unwrap_err()),
            ("create", store.create("map", "map#9", record).unwrap_err()),
            ("write", store.write("map#0", record).unwrap_err()),
            (
                "public",
                store.put_public("owner", "owner", b"\"c\"").unwrap_err(),
            ),
            ("read", store.read("map#0", record.len()).unwrap_err()),
            ("checkpoint", store.checkpoint().unwrap_err()),
        ];
        for (operation, error) in refusals {
            assert_eq!(
                storage_failure(&error),
                Some(StorageFailure::Definite),
                "{operation}: {error}"
            );
            assert!(
                error.to_string().contains("refuses every operation since"),
                "{operation}: {error}"
            );
        }
        // Nothing was appended after the entry that failed.
        assert_eq!(store.journal_bytes().unwrap(), journal);
    }

    /// Each way the append of a commit fails, a call's commit or one that
    /// makes a reservation durable and holds no record: the error says the
    /// outcome is unknown, the store refuses every later operation and
    /// appends nothing more, and the reopened store holds every commit that
    /// returned, with the failed entry whole if its sync failed after a
    /// whole write and not at all, cut off, if its write stopped part way.
    #[test]
    fn a_failed_append_poisons_the_store_and_its_entry_is_whole_or_absent() {
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let other = sealed(&cipher, &[5u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let third = resealed(&cipher, &other, &[3u8; 48]);
        let appends = StorageFault::ALL
            .into_iter()
            .filter(|fault| matches!(fault, StorageFault::Append { .. }));
        let mut checked = 0;
        for (fault, reservation) in appends.flat_map(|fault| [(fault, false), (fault, true)]) {
            let StorageFault::Append { failure } = fault else {
                unreachable!()
            };
            let directory = scratch_directory("append-fault");
            let mut store = FileStorage::create(&directory, SyncPolicy::Always).unwrap();
            store.reserve_seals("map", 8).unwrap();
            store.create("map", "map#0", &first).unwrap();
            store.create("map", "map#1", &other).unwrap();
            store.commit(b"deployed").unwrap();
            // A commit that returned: it must survive whatever follows.
            store.begin().unwrap();
            store.write("map#0", &second).unwrap();
            store.commit(b"acknowledged").unwrap();
            let before = store.journal_bytes().unwrap();

            store.inject_fault(fault);
            store.begin().unwrap();
            if reservation {
                store.reserve_seals("map", 16).unwrap();
            } else {
                store.write("map#1", &third).unwrap();
            }
            let error = store.commit(b"unknown").unwrap_err();
            store.abandon();
            assert_eq!(
                storage_failure(&error),
                Some(StorageFailure::OutcomeUnknown),
                "{fault:?}: {error}"
            );
            assert!(store.poisoned().is_some(), "{fault:?}");
            assert_refuses_everything(&mut store, &third);
            let written = store.journal_bytes().unwrap() - before;
            drop(store);

            let store = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
            assert!(store.poisoned().is_none());
            // The commit that returned is there.
            assert_eq!(store.record("map#0"), Some(&*second), "{fault:?}");
            let whole = fault.leaves_the_entry_whole();
            assert_eq!(whole, failure == AppendFailure::SyncFails);
            let meta: &[u8] = if whole { b"unknown" } else { b"acknowledged" };
            assert_eq!(store.meta(), meta, "{fault:?}");
            if reservation {
                let reserved = if whole { 16 } else { 8 };
                assert_eq!(store.reserved_seals("map"), reserved, "{fault:?}");
                assert_eq!(store.record("map#1"), Some(&*other), "{fault:?}");
            } else {
                let record: &[u8] = if whole { &third } else { &other };
                assert_eq!(store.record("map#1"), Some(record), "{fault:?}");
                assert_eq!(store.reserved_seals("map"), 8, "{fault:?}");
            }
            // A write that stopped part way is cut off, whole; an entry
            // whose sync failed is kept.
            let cut = if whole { 0 } else { written };
            assert_eq!(store.bytes_cut_on_open(), cut, "{fault:?}");
            assert!(whole || written > 0, "{fault:?}");
            drop(store);
            // The reopened store takes commits again.
            let mut store = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
            store.begin().unwrap();
            store.commit(b"after").unwrap();
            drop(store);
            fs::remove_dir_all(&directory).unwrap();
            checked += 1;
        }
        assert_eq!(checked, 8);
    }

    /// A checkpoint that fails at any step leaves every commit in the files,
    /// the one whose commit ran it among them, which returns: its entry was
    /// in the journal before the checkpoint began. The store then refuses
    /// every operation until its directory is opened again.
    #[test]
    fn a_failed_checkpoint_keeps_every_commit_and_poisons_the_store() {
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let third = resealed(&cipher, &second, &[3u8; 48]);
        for step in [
            CheckpointStep::SnapshotWrite,
            CheckpointStep::SnapshotRename,
            CheckpointStep::JournalTruncation,
        ] {
            let directory = scratch_directory("checkpoint-fault");
            let mut store = FileStorage::create(&directory, SyncPolicy::Always)
                .unwrap()
                .with_checkpoint_bytes(1 << 20);
            store.reserve_seals("map", 8).unwrap();
            store.create("map", "map#0", &first).unwrap();
            store.commit(b"deployed").unwrap();
            store.begin().unwrap();
            store.write("map#0", &second).unwrap();
            store.commit(b"acknowledged").unwrap();
            // The next commit passes the checkpoint, which fails.
            store.checkpoint_bytes = Some(0);
            store.inject_fault(StorageFault::Checkpoint { step });
            store.begin().unwrap();
            store.write("map#0", &third).unwrap();
            store.commit(b"checkpointed").unwrap();
            let reason = store.poisoned().unwrap();
            assert!(reason.contains("checkpoint failed"), "{step:?}: {reason}");
            assert_refuses_everything(&mut store, &third);
            drop(store);
            let store = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
            assert_eq!(store.record("map#0"), Some(&*third), "{step:?}");
            assert_eq!(store.meta(), b"checkpointed", "{step:?}");
            assert_eq!(store.reserved_seals("map"), 8, "{step:?}");
            assert_eq!(store.bytes_cut_on_open(), 0, "{step:?}");
            drop(store);
            fs::remove_dir_all(&directory).unwrap();
        }
    }

    /// A reservation is written with the next commit, in its journal entry,
    /// and nothing is written before: a store opened again before that commit
    /// holds the reservations of the commit before. A commit of no record
    /// makes the reservations made since the last one durable, each object
    /// once, and leaves out a reservation below the last commit's.
    #[test]
    fn a_reservation_is_durable_with_the_next_commit() {
        let directory = scratch_directory("reservation");
        let mut store = FileStorage::create(&directory, SyncPolicy::Never).unwrap();
        store.reserve_seals("a", 8).unwrap();
        store.commit(b"deployed").unwrap();
        let before = store.journal_bytes().unwrap();
        store.reserve_seals("b", 1 << 33).unwrap();
        store.reserve_seals("b", 1 << 32).unwrap();
        store.reserve_seals("a", 4).unwrap();
        assert_eq!(store.journal_bytes().unwrap(), before);
        assert_eq!(store.reserved_seals("b"), 0);
        // A copy of the files, opened: one adapter at a time opens a store's
        // files, since an open publishes a journal of its own.
        let copy = scratch_directory("reservation-copy");
        fs::create_dir_all(&copy).unwrap();
        for file in [SNAPSHOT_FILE, JOURNAL_FILE] {
            fs::copy(directory.join(file), copy.join(file)).unwrap();
        }
        let reopened = FileStorage::open(&copy, SyncPolicy::Never).unwrap();
        assert_eq!(reopened.reserved_seals("b"), 0);
        drop(reopened);
        fs::remove_dir_all(&copy).unwrap();
        store.begin().unwrap();
        store.commit(b"reserved").unwrap();
        // One frame: the header; the kind, the metadata, one reservation, no
        // record and no public value; the digest.
        assert_eq!(
            (store.journal_bytes().unwrap() - before) as usize,
            FRAME_HEADER_BYTES + 1 + (4 + 8) + 4 + (4 + 1 + 8) + 4 + 4 + FRAME_DIGEST_BYTES
        );
        assert_eq!(store.reserved_seals("a"), 8);
        assert_eq!(store.reserved_seals("b"), 1 << 33);
        drop(store);
        let store = FileStorage::open(&directory, SyncPolicy::Never).unwrap();
        assert_eq!(store.reserved_seals("a"), 8);
        assert_eq!(store.reserved_seals("b"), 1 << 33);
        assert_eq!(store.meta(), b"reserved");
        drop(store);
        fs::remove_dir_all(&directory).unwrap();
    }

    /// A directory a crash model watches, empty, with what a crash leaves of
    /// it written to `crashed` and `crashed_again`.
    fn watched(name: &str) -> (PathBuf, crate::crash_model::CrashModel) {
        let root = scratch_directory(name);
        fs::create_dir_all(&root).unwrap();
        let model = crate::crash_model::CrashModel::watch(&root).unwrap();
        (root, model)
    }

    /// A store made in directories that did not exist, with a commit that
    /// returned, keeps the commit through a crash before any checkpoint:
    /// the journal is on the device, its name and the snapshot's in their
    /// directory, and each directory the store made in the one above it.
    #[test]
    fn a_created_store_keeps_its_commits_through_a_crash() {
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let (root, model) = watched("crash-create");
        let directory = root.join("deployments").join("store");
        let mut store = FileStorage::create(&directory, SyncPolicy::Always).unwrap();
        store.reserve_seals("map", 8).unwrap();
        store.create("map", "map#0", &first).unwrap();
        store.commit(b"deployed").unwrap();
        store.begin().unwrap();
        store.write("map#0", &second).unwrap();
        store.commit(b"first call").unwrap();
        drop(store);
        let crashed = scratch_directory("crash-create-after");
        model.crash_into(&crashed).unwrap();
        let store = FileStorage::open(
            crashed.join("deployments").join("store"),
            SyncPolicy::Always,
        )
        .unwrap();
        assert_eq!(store.meta(), b"first call");
        assert_eq!(store.record("map#0"), Some(&*second));
        assert_eq!(store.reserved_seals("map"), 8);
        drop(store);
        // A store that syncs nothing leaves nothing on the device.
        drop(model);
        let (unsynced_root, unsynced) = watched("crash-create-unsynced");
        let mut store =
            FileStorage::create(unsynced_root.join("store"), SyncPolicy::Never).unwrap();
        store.commit(b"deployed").unwrap();
        drop(store);
        let unsynced_crash = scratch_directory("crash-create-unsynced-after");
        unsynced.crash_into(&unsynced_crash).unwrap();
        assert!(!unsynced_crash.join("store").exists());
        for directory in [root, crashed, unsynced_root, unsynced_crash] {
            fs::remove_dir_all(directory).unwrap();
        }
    }

    /// The deployment's commit and a commit that returned, then a commit
    /// whose sync failed after a whole write, in a store a crash model
    /// watches: what a test that resolves that commit starts from.
    fn store_with_a_failed_sync(
        name: &str,
    ) -> (PathBuf, PathBuf, crate::crash_model::CrashModel, Box<[u8]>) {
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let third = resealed(&cipher, &second, &[3u8; 48]);
        let (root, model) = watched(name);
        let directory = root.join("store");
        let mut store = FileStorage::create(&directory, SyncPolicy::Always).unwrap();
        store.reserve_seals("map", 8).unwrap();
        store.create("map", "map#0", &first).unwrap();
        store.commit(b"deployed").unwrap();
        store.begin().unwrap();
        store.write("map#0", &second).unwrap();
        store.commit(b"acknowledged").unwrap();
        store.inject_fault(StorageFault::Append {
            failure: AppendFailure::SyncFails,
        });
        store.begin().unwrap();
        store.write("map#0", &third).unwrap();
        let error = store.commit(b"unknown").unwrap_err();
        assert_eq!(
            storage_failure(&error),
            Some(StorageFailure::OutcomeUnknown)
        );
        store.abandon();
        (root, directory, model, third)
    }

    /// The meta of the store a crash now would leave.
    fn meta_after_a_crash(model: &crate::crash_model::CrashModel, name: &str) -> Vec<u8> {
        let crashed = scratch_directory(name);
        model.crash_into(&crashed).unwrap();
        let meta = FileStorage::open(crashed.join("store"), SyncPolicy::Always)
            .unwrap()
            .meta()
            .to_vec();
        fs::remove_dir_all(crashed).unwrap();
        meta
    }

    /// A commit whose sync failed after a whole write is in the journal a
    /// process reads, and not on the device: a crash loses it, and a sync
    /// of the journal after the failure does not put it there. A store
    /// opened again serves it only once it published it, so a crash after
    /// the open keeps what the open served.
    #[test]
    fn a_reopened_store_publishes_what_it_read_before_it_serves_it() {
        let (root, directory, model, third) = store_with_a_failed_sync("publish");
        assert_eq!(
            meta_after_a_crash(&model, "publish-before"),
            b"acknowledged"
        );
        // A sync of the journal after the failed one: the entry stays off
        // the device.
        let journal = journal_file(&directory, false).unwrap();
        sync_file(&journal, &directory.join(JOURNAL_FILE)).unwrap();
        drop(journal);
        assert_eq!(
            meta_after_a_crash(&model, "publish-resync"),
            b"acknowledged"
        );
        // The process restarts with no crash: the open reads the entry and
        // publishes it before it serves it.
        let store = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
        assert_eq!(store.meta(), b"unknown");
        assert_eq!(store.record("map#0"), Some(&*third));
        assert_eq!(store.bytes_cut_on_open(), 0);
        drop(store);
        assert_eq!(meta_after_a_crash(&model, "publish-after"), b"unknown");
        assert!(!directory.join(JOURNAL_TEMP_FILE).exists());
        drop(model);
        fs::remove_dir_all(root).unwrap();
    }

    /// An open whose publication fails at any step fails and serves
    /// nothing. A crash then leaves a store without the commit whose sync
    /// failed, which no open resolved; an open that publishes, with no
    /// crash before it, serves it.
    #[test]
    fn an_open_whose_publication_fails_serves_nothing() {
        use crate::crash_model::FileOperation;
        for (operation, file) in [
            (FileOperation::Write, Some(JOURNAL_TEMP_FILE)),
            (FileOperation::SyncFile, Some(JOURNAL_TEMP_FILE)),
            (FileOperation::Rename, Some(JOURNAL_FILE)),
            (FileOperation::SyncDirectory, None),
        ] {
            let (root, directory, model, _) = store_with_a_failed_sync("publish-fault");
            let target = file.map_or_else(|| directory.clone(), |file| directory.join(file));
            model.fail_next(operation, &target);
            let error = FileStorage::open(&directory, SyncPolicy::Always).unwrap_err();
            assert!(
                format!("{error:#}").contains("before it is served: nothing is served"),
                "{operation:?}: {error:#}"
            );
            assert_eq!(
                meta_after_a_crash(&model, "publish-fault-crash"),
                b"acknowledged",
                "{operation:?}"
            );
            let store = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
            assert_eq!(store.meta(), b"unknown", "{operation:?}");
            drop(store);
            assert_eq!(
                meta_after_a_crash(&model, "publish-fault-after"),
                b"unknown",
                "{operation:?}"
            );
            drop(model);
            fs::remove_dir_all(root).unwrap();
        }
    }

    /// The journal's last entry, damaged or cut short, is cut off; a whole
    /// entry after a damaged one is not, and the journal is refused: it was
    /// appended after an append that failed, as an adapter that went on
    /// after a failure would append it.
    #[test]
    fn a_whole_entry_after_a_damaged_one_is_refused() {
        let directory = scratch_directory("damaged");
        let cipher = StoreCipher::random();
        let first = sealed(&cipher, &[1u8; 48]);
        let second = resealed(&cipher, &first, &[2u8; 48]);
        let third = resealed(&cipher, &second, &[3u8; 48]);
        let (deployed, middle) = {
            let mut store = FileStorage::create(&directory, SyncPolicy::Never).unwrap();
            store.reserve_seals("map", 8).unwrap();
            store.create("map", "map#0", &first).unwrap();
            store.commit(b"deployed").unwrap();
            let deployed = store.journal_bytes().unwrap();
            store.begin().unwrap();
            store.write("map#0", &second).unwrap();
            store.commit(b"middle").unwrap();
            let middle = store.journal_bytes().unwrap();
            store.begin().unwrap();
            store.write("map#0", &third).unwrap();
            store.commit(b"last").unwrap();
            (deployed, middle)
        };
        let journal = directory.join(JOURNAL_FILE);
        let bytes = fs::read(&journal).unwrap();
        // A byte flipped in the middle entry, which a whole one follows.
        let mut damaged = bytes.clone();
        damaged[((deployed + middle) / 2) as usize] ^= 1;
        fs::write(&journal, &damaged).unwrap();
        let error = FileStorage::open(&directory, SyncPolicy::Never).unwrap_err();
        assert!(
            error.to_string().contains(&format!(
                "whole entry at byte {middle} after a damaged one at byte {deployed}"
            )),
            "{error}"
        );
        // The middle entry cut short and the last appended after it, as an
        // adapter that went on after a failed write would leave them.
        let mut torn = bytes[..(deployed + 20) as usize].to_vec();
        torn.extend_from_slice(&bytes[middle as usize..]);
        fs::write(&journal, &torn).unwrap();
        assert!(FileStorage::open(&directory, SyncPolicy::Never).is_err());
        // The same bytes with nothing after the torn entry: cut off.
        fs::write(&journal, &bytes[..(deployed + 20) as usize]).unwrap();
        let store = FileStorage::open(&directory, SyncPolicy::Never).unwrap();
        assert_eq!(store.record("map#0"), Some(&*first));
        assert_eq!(store.meta(), b"deployed");
        assert_eq!(store.bytes_cut_on_open(), 20);
        drop(store);
        fs::remove_dir_all(&directory).unwrap();
    }
}
