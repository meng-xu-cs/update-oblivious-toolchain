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
//! it, which is its nonce. The adapter takes a record only if that count is
//! below the count it has reserved for the record's object, and a
//! reservation is durable before `reserve_seals` returns. A runtime that
//! restarts from the adapter's files resumes each key's count at its
//! reservation, so no nonce that reached the adapter is used again.

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

/// How many seals a reservation covers beyond the ones already made. A
/// reservation is a durable write, so it is made in steps of this many; a
/// restart skips at most this many unused nonces of a key.
pub const SEAL_RESERVATION_STEP: u64 = 1 << 20;

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

/// Counts an adapter keeps of its work since it was made.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize)]
pub struct StorageStats {
    pub reads: u64,
    pub read_bytes: u64,
    pub writes: u64,
    pub written_bytes: u64,
    pub commits: u64,
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

    /// Reserve the seal counts below `below` for the key of `object`, and
    /// make that durable before returning. A reservation is never undone.
    fn reserve_seals(&mut self, object: &str, below: u64) -> Result<()>;

    /// The count below which the seals of `object`'s key are reserved.
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
    reserved_seals: u64,
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

    /// A sealed record of `object` may be taken only if its nonce is one the
    /// adapter has made durable a reservation for.
    fn ensure_nonce_reserved(&self, object: u32, location: &str, record: &[u8]) -> Result<()> {
        let count = sealed_record_seal_count(record).ok_or_else(|| {
            anyhow!("the bytes handed to the store for {location} are not a sealed record")
        })?;
        let reserved = self
            .objects
            .get(object as usize)
            .map(|object| object.reserved_seals)
            .unwrap_or(0);
        if count >= reserved {
            bail!(
                "the store refuses the record of {location}: its seal count is not below the durable reservation of its key"
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

    fn finish_commit(&mut self, meta: &[u8]) {
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

    fn load_reservation(&mut self, object: &str, below: u64) -> Result<()> {
        let id = self.object_id(object)?;
        if let Some(object) = self.objects.get_mut(id as usize) {
            object.reserved_seals = object.reserved_seals.max(below);
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
        self.load_reservation(object, below)?;
        self.stats.reservations += 1;
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
    /// After every commit and every reservation: a commit that returned is
    /// on the device.
    Always,
    /// Never: the files are written and the device is left to the operating
    /// system. A commit that returned survives the process, not a power
    /// failure.
    Never,
}

const SNAPSHOT_FILE: &str = "snapshot.bin";
const SNAPSHOT_TEMP_FILE: &str = "snapshot.tmp";
const JOURNAL_FILE: &str = "journal.bin";
const SNAPSHOT_MAGIC: u32 = 0x554F_534E;
const JOURNAL_MAGIC: u32 = 0x554F_4A4E;
const FRAME_HEADER_BYTES: usize = 12;
const FRAME_DIGEST_BYTES: usize = 32;
const ENTRY_COMMIT: u8 = 1;
const ENTRY_RESERVATION: u8 = 2;

/// An adapter that keeps its records in two files of a directory: a
/// snapshot of every record, and a journal of the commits and reservations
/// since. It serves reads from the image of them it holds in memory.
///
/// A commit is one journal entry with a digest, appended and then synced as
/// the policy says, so it is in the files whole or not at all: an entry that
/// was cut short is dropped when the directory is opened.
#[derive(Debug)]
pub struct FileStorage {
    image: MemoryStorage,
    directory: PathBuf,
    journal: File,
    journal_bytes: u64,
    /// The journal length above which a commit writes a snapshot and
    /// empties the journal.
    checkpoint_bytes: Option<u64>,
    sync: SyncPolicy,
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

impl FileStorage {
    /// A new store in `directory`, which must not hold one.
    pub fn create(directory: impl AsRef<Path>, sync: SyncPolicy) -> Result<Self> {
        let directory = directory.as_ref().to_path_buf();
        fs::create_dir_all(&directory)
            .with_context(|| format!("creating {}", directory.display()))?;
        if directory.join(SNAPSHOT_FILE).exists() || directory.join(JOURNAL_FILE).exists() {
            bail!("{} already holds a store", directory.display());
        }
        let image = MemoryStorage::new();
        write_snapshot(&directory, &image, sync)?;
        let journal = journal_file(&directory, true)
            .with_context(|| format!("creating the journal in {}", directory.display()))?;
        Ok(Self {
            image,
            directory,
            journal,
            journal_bytes: 0,
            checkpoint_bytes: None,
            sync,
        })
    }

    /// Write a snapshot and empty the journal after a commit that leaves
    /// the journal longer than `bytes`: the journal then stays near that
    /// length, whatever the number of commits.
    pub fn with_checkpoint_bytes(mut self, bytes: u64) -> Self {
        self.checkpoint_bytes = Some(bytes);
        self
    }

    /// The store in `directory`, as its last commit left it. A journal entry
    /// that was cut short is dropped.
    pub fn open(directory: impl AsRef<Path>, sync: SyncPolicy) -> Result<Self> {
        let directory = directory.as_ref().to_path_buf();
        let snapshot = fs::read(directory.join(SNAPSHOT_FILE))
            .with_context(|| format!("reading the snapshot in {}", directory.display()))?;
        let (payload, _) = read_frame(SNAPSHOT_MAGIC, &snapshot)
            .ok_or_else(|| anyhow!("the snapshot in {} is damaged", directory.display()))?;
        let mut image = MemoryStorage::new();
        load_snapshot(&mut image, payload)?;
        let mut journal = journal_file(&directory, false)
            .with_context(|| format!("opening the journal in {}", directory.display()))?;
        let mut entries = Vec::new();
        journal.read_to_end(&mut entries)?;
        let mut offset = 0usize;
        while let Some((payload, len)) = entries
            .get(offset..)
            .and_then(|rest| read_frame(JOURNAL_MAGIC, rest))
        {
            load_journal_entry(&mut image, payload)?;
            offset += len;
        }
        if offset != entries.len() {
            // What follows the last whole entry is a commit that did not
            // finish. Later entries must follow a whole one.
            journal.set_len(offset as u64)?;
            journal.seek(SeekFrom::End(0))?;
            journal.sync_data()?;
        }
        Ok(Self {
            image,
            directory,
            journal,
            journal_bytes: offset as u64,
            checkpoint_bytes: None,
            sync,
        })
    }

    /// Write a snapshot of every record and empty the journal.
    pub fn checkpoint(&mut self) -> Result<()> {
        if !self.image.pending.is_empty() {
            bail!("the store holds records that were neither committed nor abandoned");
        }
        write_snapshot(&self.directory, &self.image, self.sync)?;
        self.journal.set_len(0)?;
        self.journal.seek(SeekFrom::End(0))?;
        self.journal_bytes = 0;
        if self.sync == SyncPolicy::Always {
            self.journal.sync_data()?;
            self.image.stats.syncs += 1;
        }
        Ok(())
    }

    pub fn directory(&self) -> &Path {
        &self.directory
    }

    /// The bytes of the journal: what the commits and reservations since
    /// the last snapshot take on the device.
    pub fn journal_bytes(&self) -> Result<u64> {
        Ok(self.journal.metadata()?.len())
    }

    fn journal_passed_its_checkpoint(&self) -> bool {
        self.checkpoint_bytes
            .is_some_and(|limit| self.journal_bytes > limit)
    }

    fn append(&mut self, payload: &[u8]) -> Result<()> {
        let started = Instant::now();
        let entry = frame(JOURNAL_MAGIC, payload);
        self.journal.write_all(&entry)?;
        if self.sync == SyncPolicy::Always {
            self.journal.sync_data()?;
            self.image.stats.syncs += 1;
        }
        self.journal_bytes += entry.len() as u64;
        self.image.stats.persisted_bytes += entry.len() as u64;
        self.image.stats.persist_ns +=
            u64::try_from(started.elapsed().as_nanos()).unwrap_or(u64::MAX);
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

fn write_snapshot(directory: &Path, image: &MemoryStorage, sync: SyncPolicy) -> Result<()> {
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
    let mut file = File::create(&temp).with_context(|| format!("creating {}", temp.display()))?;
    file.write_all(&frame(SNAPSHOT_MAGIC, &payload))?;
    if sync == SyncPolicy::Always {
        file.sync_data()?;
    }
    drop(file);
    fs::rename(&temp, directory.join(SNAPSHOT_FILE))?;
    if sync == SyncPolicy::Always {
        // The rename is durable once the directory is.
        File::open(directory)?.sync_all()?;
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
    for _ in 0..decoder.u32()? {
        let object = decoder.text()?;
        let below = decoder.u64()?;
        image.load_reservation(object, below)?;
    }
    load_records(image, &mut decoder)?;
    decoder.finish()
}

fn load_journal_entry(image: &mut MemoryStorage, payload: &[u8]) -> Result<()> {
    let mut decoder = Decoder { bytes: payload };
    match decoder.u8()? {
        ENTRY_COMMIT => {
            let meta = decoder.blob()?.to_vec();
            load_records(image, &mut decoder)?;
            image.meta = meta;
        }
        ENTRY_RESERVATION => {
            let object = decoder.text()?;
            let below = decoder.u64()?;
            image.load_reservation(object, below)?;
        }
        other => bail!("the journal holds an entry of unknown kind {other}"),
    }
    decoder.finish()
}

impl StorageAdapter for FileStorage {
    fn create(&mut self, object: &str, location: &str, record: &[u8]) -> Result<()> {
        self.image.create(object, location, record)
    }

    fn read(&mut self, location: &str, len: usize) -> Result<Box<[u8]>> {
        self.image.read(location, len)
    }

    fn write(&mut self, location: &str, record: &[u8]) -> Result<WriteClass> {
        self.image.write(location, record)
    }

    fn put_public(&mut self, object: &str, location: &str, value: &[u8]) -> Result<()> {
        self.image.put_public(object, location, value)
    }

    fn reserve_seals(&mut self, object: &str, below: u64) -> Result<()> {
        if below <= self.image.reserved_seals(object) {
            return Ok(());
        }
        // The reservation is in the journal before a record that needs it
        // can be handed over.
        let mut payload = vec![ENTRY_RESERVATION];
        put_bytes(&mut payload, object.as_bytes())?;
        put_u64(&mut payload, below);
        self.append(&payload)?;
        self.image.reserve_seals(object, below)
    }

    fn reserved_seals(&self, object: &str) -> u64 {
        self.image.reserved_seals(object)
    }

    fn begin(&mut self) -> Result<()> {
        self.image.begin()
    }

    fn commit(&mut self, meta: &[u8]) -> Result<()> {
        let mut payload = vec![ENTRY_COMMIT];
        put_bytes(&mut payload, meta)?;
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
        self.append(&payload)?;
        self.image.finish_commit(meta);
        if self.journal_passed_its_checkpoint() {
            // The commit is in the journal already. A snapshot that cannot
            // be written leaves the journal as it is, for the next commit
            // to try again, and the commit stands.
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

    /// The part of the store that keeps the records of `object`.
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

    /// Make sure the store has reserved the seal counts below `sealed`, the
    /// count of the seals made under the object's key so far. The store
    /// reserves a step beyond it, so that most seals need no reservation.
    pub fn reserve_seals(&self, sealed: u64) -> Result<()> {
        self.storage.with(|adapter| {
            if sealed <= adapter.reserved_seals(&self.object) {
                return Ok(());
            }
            adapter.reserve_seals(&self.object, sealed.saturating_add(SEAL_RESERVATION_STEP))
        })
    }

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
        store.reserve_seals("cell", 1).unwrap();
        store.create("cell", "cell", &record).unwrap();
        // The next seal has count 1, which the reservation does not cover.
        let next = resealed(&cipher, &record, &[2u8; 32]);
        assert_eq!(sealed_record_seal_count(&next), Some(1));
        let refused = store.write("cell", &next).unwrap_err().to_string();
        assert!(refused.contains("durable reservation"), "{refused}");
        assert_eq!(store.record("cell"), Some(&*record));
        store.reserve_seals("cell", 2).unwrap();
        assert_eq!(store.write("cell", &next).unwrap(), WriteClass::Update);
        assert_eq!(store.seal_counts("cell"), vec![1]);
        // A reservation only grows, and bytes that are no record are refused.
        store.reserve_seals("cell", 1).unwrap();
        assert_eq!(store.reserved_seals("cell"), 2);
        assert!(store.write("cell", &vec![0u8; next.len()]).is_err());
        assert_eq!(store.reserved_seals("other"), 0);
    }

    #[test]
    fn a_handle_reserves_a_step_beyond_the_seals_made() {
        let storage = SharedStorage::memory();
        let handle = storage.handle("cell");
        handle.reserve_seals(0).unwrap();
        assert_eq!(handle.reserved_seals(), 0);
        handle.reserve_seals(3).unwrap();
        assert_eq!(handle.reserved_seals(), 3 + SEAL_RESERVATION_STEP);
        let reservations = storage.with(|adapter| adapter.stats().reservations);
        handle.reserve_seals(3 + SEAL_RESERVATION_STEP).unwrap();
        assert_eq!(
            storage.with(|adapter| adapter.stats().reservations),
            reservations
        );
        handle.reserve_seals(4 + SEAL_RESERVATION_STEP).unwrap();
        assert_eq!(handle.reserved_seals(), 4 + 2 * SEAL_RESERVATION_STEP);
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
            assert!(store.stats().syncs >= 3);
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
            store.reserve_seals("map", 20).unwrap();
        }
        {
            // A journal that passes its checkpoint is emptied by the commit
            // that takes it there, and the store reopens as that commit
            // left it.
            let mut store = FileStorage::open(&directory, SyncPolicy::Never)
                .unwrap()
                .with_checkpoint_bytes(64);
            let fourth = resealed(&cipher, &third, &[4u8; 48]);
            store.begin().unwrap();
            store.write("map#0", &fourth).unwrap();
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
}
