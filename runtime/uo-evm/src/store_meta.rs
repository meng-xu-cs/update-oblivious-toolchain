//! The public metadata a deployment leaves in its store with every commit,
//! and how a runtime that restarts from the store takes it back.
//!
//! The metadata is what a restart cannot read off the records: the
//! generation of the commit, the freshness counters, whether the contract is
//! initialized, the digest of the public state, each key's reserved seal
//! count, and for a production deployment the receipt it issued last, which
//! the next call must name. All of it is public. It carries a tag under a
//! key that derives from the master secret, so a restart takes only metadata
//! that a runtime with the same secret wrote. The tag does not say that the
//! metadata is the latest: that is the generation's part, which a restart
//! compares with the one the platform's monotonic counter attests.

use crate::deployment::ProductionReceipt;
use crate::freshness::RuntimeFreshnessSnapshot;
use crate::secret::StoreMetaKey;
use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uo_core::manifest::CALL_SEAL_BOUND;
use uo_store::{storage_failure, SharedStorage, StorageFailure, StoreCipher};

const STORE_META_SCHEMA: &str = "uo-runtime-store-meta-v3";
const STORE_META_TAG_BYTES: usize = 32;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct StoreMeta {
    schema: String,
    /// How many commits the store holds, this one among them: a
    /// deployment's, every committed call's, aborted or not, and every bulk
    /// load's of a diagnostics build.
    pub(crate) generation: u64,
    epoch: u64,
    rollback_counter: u64,
    next_call_counter: u64,
    pub(crate) initialized: bool,
    pub(crate) public_state_sha256: String,
    /// The count below which this commit reserved the seals of each sealed
    /// object's key, by object: every count a call from the state it leaves
    /// can seal is below it, and a restart from it resumes each key there.
    /// The store makes the reservations durable with the commit.
    reservations: BTreeMap<String, u64>,
    /// The receipt a production deployment issued last: a restart issues
    /// the next one after it. A deployment that issues no receipts keeps
    /// none.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub(crate) last_receipt: Option<ProductionReceipt>,
}

impl StoreMeta {
    pub(crate) fn new(
        generation: u64,
        freshness: RuntimeFreshnessSnapshot,
        initialized: bool,
        public_state_sha256: String,
    ) -> Self {
        Self {
            schema: STORE_META_SCHEMA.into(),
            generation,
            epoch: freshness.epoch,
            rollback_counter: freshness.rollback_counter,
            next_call_counter: freshness.next_call_counter,
            initialized,
            public_state_sha256,
            reservations: BTreeMap::new(),
            last_receipt: None,
        }
    }

    /// The metadata with `reservations`.
    pub(crate) fn with_reservations(mut self, reservations: BTreeMap<String, u64>) -> Self {
        self.reservations = reservations;
        self
    }

    /// The metadata of a commit of the same state at `generation`.
    pub(crate) fn at_generation(mut self, generation: u64) -> Self {
        self.generation = generation;
        self
    }

    /// The reservation of each sealed object's key.
    pub(crate) fn reservations(&self) -> &BTreeMap<String, u64> {
        &self.reservations
    }

    /// The reservations, as the store takes them for its commit.
    pub(crate) fn reservation_entries(&self) -> impl Iterator<Item = (&str, u64)> {
        self.reservations
            .iter()
            .map(|(object, below)| (object.as_str(), *below))
    }

    /// The metadata with the receipt a production deployment issued last.
    pub(crate) fn with_last_receipt(mut self, receipt: Option<&ProductionReceipt>) -> Self {
        self.last_receipt = receipt.cloned();
        self
    }

    /// Where the metadata's generation stands to `attested_generation`,
    /// the generation the platform's monotonic counter attests. A restart
    /// takes metadata at that generation or one past it, and refuses any
    /// other: metadata behind it is older than a commit whose result was
    /// released, and the counter is never more than one commit behind the
    /// store, since it catches up before the instance commits again.
    pub(crate) fn against_attested(&self, attested_generation: u64) -> Result<StoreGeneration> {
        if self.generation == attested_generation {
            return Ok(StoreGeneration::Attested);
        }
        if Some(self.generation) == attested_generation.checked_add(1) {
            return Ok(StoreGeneration::OnePast);
        }
        if self.generation < attested_generation {
            bail!(
                "the store's commit generation {} is behind the attested generation {}: its files are older than a commit whose result was released",
                self.generation,
                attested_generation
            );
        }
        bail!(
            "the store's commit generation {} is more than one past the attested generation {}",
            self.generation,
            attested_generation
        )
    }

    pub(crate) fn freshness(&self) -> RuntimeFreshnessSnapshot {
        RuntimeFreshnessSnapshot {
            epoch: self.epoch,
            rollback_counter: self.rollback_counter,
            next_call_counter: self.next_call_counter,
        }
    }

    /// The bytes a commit leaves in the store: the tag, then the metadata.
    pub(crate) fn tagged_bytes(&self, key: &StoreMetaKey) -> Result<Vec<u8>> {
        let body = serde_json::to_vec(self)?;
        let mut tagged = key.tag(&body)?.to_vec();
        tagged.extend_from_slice(&body);
        Ok(tagged)
    }

    /// The metadata of the bytes a commit left, if they carry the tag of
    /// `key`. The error names no value.
    pub(crate) fn from_tagged_bytes(key: &StoreMetaKey, tagged: &[u8]) -> Result<Self> {
        if tagged.len() < STORE_META_TAG_BYTES {
            bail!("the store holds no commit metadata");
        }
        let (tag, body) = tagged.split_at(STORE_META_TAG_BYTES);
        let expected = key.tag(body)?;
        // Every byte is compared, whatever the first difference is.
        let differs = tag
            .iter()
            .zip(expected.iter())
            .fold(0u8, |acc, (left, right)| acc | (left ^ right));
        if differs != 0 {
            bail!("the store's commit metadata does not carry this deployment's tag");
        }
        let meta: Self = serde_json::from_slice(body)?;
        if meta.schema != STORE_META_SCHEMA {
            bail!("the store's commit metadata has an unknown schema");
        }
        Ok(meta)
    }
}

/// Where the generation of the store a deployment restarted from stands to
/// the generation the platform's monotonic counter attests. The counter
/// follows the generation: before the deployment releases anything an
/// instance returned (a call's result, a receipt), and before the instance
/// commits again, the counter holds the instance's generation
/// (`ProductionCallResult::generation`,
/// `ProductionContractInstance::generation`). A restart takes no store
/// behind the counter, and none more than one commit past it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StoreGeneration {
    /// The store's last commit is the one the counter attests.
    Attested,
    /// The store's last commit is one past the one the counter attests: a
    /// commit whose result the deployment did not release, after a call
    /// whose outcome was unknown or a stop before the counter advanced. The
    /// deployment advances the counter to the restarted instance's
    /// generation before it releases anything the instance returns.
    OnePast,
}

/// The records a staged call handed the store, which are pending there. The
/// store makes them durable when the call is committed, and puts back what
/// they replaced when the call is dropped, whatever the reason.
#[derive(Debug)]
pub(crate) struct StagedStore {
    storage: SharedStorage,
    pending: bool,
}

impl StagedStore {
    /// Start a call in the store.
    pub(crate) fn begin(storage: &SharedStorage) -> Result<Self> {
        storage.with(|adapter| adapter.begin())?;
        Ok(Self {
            storage: storage.clone(),
            pending: true,
        })
    }

    /// Commit the call's records in the store, with the commit metadata. If
    /// the store cannot, the records stay pending and are put back when this
    /// is dropped, and the error says whether the commit may still be in
    /// the store's files (`uo_store::storage_failure`). If it may, the
    /// call's outcome is unknown: the store refuses every later operation,
    /// so the instance refuses every later call, and the deployment's files
    /// show whether the call committed once it restarts from them.
    pub(crate) fn make_durable(mut self, meta: &[u8]) -> Result<()> {
        self.storage
            .with(|adapter| adapter.commit(meta))
            .map_err(|error| match storage_failure(&error) {
                Some(StorageFailure::OutcomeUnknown) => error.context(
                    "the call's outcome is unknown: its commit may or may not be in the store's files, and the instance refuses every call until the deployment restarts from them, whose last commit says whether the call committed",
                ),
                _ => error,
            })?;
        self.pending = false;
        Ok(())
    }
}

impl Drop for StagedStore {
    fn drop(&mut self) {
        if self.pending {
            self.storage.with(|adapter| adapter.abandon());
        }
    }
}

/// A dropped call's keys resume at the second multiple of this quantum
/// above their count before the call. No entrypoint can seal this many
/// records under one key in a call (`uo_core::manifest::check_call_seal_bound`,
/// which the compiler, `uo-check` and every deployment apply), so that count
/// is above every count the call used and is a function of the count before
/// the call alone.
pub(crate) const DROPPED_CALL_SEAL_QUANTUM: u64 = CALL_SEAL_BOUND;

/// The reservations a commit makes, of a state whose keys' counts `ciphers`
/// hold: each key's reservation in `last`, raised to the count a call from
/// the key's count resumes at if it is dropped
/// (`seal_count_after_dropped_call`). Every count that call can seal is
/// below it, so the next call needs no reservation of its own, and the
/// commit that made it is attested before the call begins.
pub(crate) fn reservations_ahead(
    ciphers: &[StoreCipher],
    last: &BTreeMap<String, u64>,
) -> BTreeMap<String, u64> {
    let mut reservations = last.clone();
    for cipher in ciphers {
        let Some(storage) = cipher.storage() else {
            continue;
        };
        let ahead = seal_count_after_dropped_call(cipher.seal_count());
        let reserved = reservations.entry(storage.object().to_owned()).or_insert(0);
        *reserved = (*reserved).max(ahead);
    }
    reservations
}

/// The seal count a key resumes at after a call that started at `start` was
/// dropped: the second multiple of the quantum above `start`, or the end of
/// the count, which no seal can use.
pub(crate) fn seal_count_after_dropped_call(start: u64) -> u64 {
    (start / DROPPED_CALL_SEAL_QUANTUM)
        .checked_add(2)
        .and_then(|quanta| quanta.checked_mul(DROPPED_CALL_SEAL_QUANTUM))
        .unwrap_or(u64::MAX)
}

/// The seal count of every key of a deployment when a call is staged. A
/// call that is dropped, whatever the reason and wherever it stopped, leaves
/// each key's count at `seal_count_after_dropped_call` of its count before
/// the call, so that neither the next record's nonce nor a restart shows how
/// far the call got. The last commit reserved that count before the call
/// began, so a restart after a crash, when nothing runs at the end of the
/// call, resumes there too. A call that is committed keeps the counts its
/// seals reached, which its entrypoint fixes.
#[derive(Debug)]
pub(crate) struct DroppedCallSeals {
    starts: Vec<(StoreCipher, u64)>,
    dropped: bool,
}

impl DroppedCallSeals {
    /// The counts of `ciphers`, each sharing its key's count, before a call.
    /// The call writes no reservation: the last commit's, `reserved`, must
    /// cover the count each key resumes at if the call is dropped, and with
    /// it every count the call can seal. If they do not, which only an
    /// instance that restarted and has not resumed meets, the call fails
    /// before it seals anything.
    pub(crate) fn begin(
        ciphers: Vec<StoreCipher>,
        reserved: &BTreeMap<String, u64>,
    ) -> Result<Self> {
        let starts: Vec<(StoreCipher, u64)> = ciphers
            .into_iter()
            .map(|cipher| {
                let start = cipher.seal_count();
                (cipher, start)
            })
            .collect();
        for (cipher, start) in &starts {
            let Some(storage) = cipher.storage() else {
                continue;
            };
            let object = storage.object();
            if seal_count_after_dropped_call(*start) > reserved.get(object).copied().unwrap_or(0) {
                bail!(
                    "the last commit did not reserve the seal counts a call can use for {object}: an instance that restarted resumes before its first call, and one whose call was dropped commits the reservation the next call needs"
                );
            }
        }
        Ok(Self {
            starts,
            dropped: true,
        })
    }

    /// The call is committed: its keys keep the counts its seals reached.
    pub(crate) fn keep(mut self) {
        self.dropped = false;
    }
}

impl Drop for DroppedCallSeals {
    fn drop(&mut self) {
        if !self.dropped {
            return;
        }
        // The last commit reserved these counts before the call began, and
        // a restart resumes at them: nothing is written here.
        for (cipher, start) in &self.starts {
            cipher.resume_seal_count(seal_count_after_dropped_call(*start));
        }
    }
}

/// Commit the records a deployment handed the store, with the deployment's
/// commit metadata and the reservations it made.
pub(crate) fn make_deployment_durable(storage: &SharedStorage, meta: &[u8]) -> Result<()> {
    storage.with(|adapter| adapter.commit(meta))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::secret::RuntimeMasterSecret;

    fn meta() -> StoreMeta {
        StoreMeta::new(
            4,
            RuntimeFreshnessSnapshot {
                epoch: 7,
                rollback_counter: 3,
                next_call_counter: 5,
            },
            true,
            "ab".repeat(32),
        )
        .with_reservations(BTreeMap::from([("balances".to_owned(), 1 << 33)]))
    }

    #[test]
    fn commit_metadata_opens_only_with_its_tag() {
        let key = RuntimeMasterSecret::from_diagnostic_seed(1)
            .store_meta_key()
            .unwrap();
        let sealed = meta().tagged_bytes(&key).unwrap();
        let opened = StoreMeta::from_tagged_bytes(&key, &sealed).unwrap();
        assert_eq!(opened, meta());
        assert_eq!(opened.generation, 4);
        assert_eq!(opened.freshness().rollback_counter, 3);
        assert_eq!(opened.reservations()["balances"], 1 << 33);

        // A changed byte of the metadata or of the tag, metadata cut short,
        // and another deployment's key are all refused.
        for index in [
            0,
            STORE_META_TAG_BYTES - 1,
            STORE_META_TAG_BYTES,
            sealed.len() - 1,
        ] {
            let mut changed = sealed.clone();
            changed[index] ^= 1;
            assert!(
                StoreMeta::from_tagged_bytes(&key, &changed).is_err(),
                "byte {index}"
            );
        }
        assert!(StoreMeta::from_tagged_bytes(&key, &sealed[..STORE_META_TAG_BYTES - 1]).is_err());
        assert!(StoreMeta::from_tagged_bytes(&key, &[]).is_err());
        let other = RuntimeMasterSecret::from_diagnostic_seed(2)
            .store_meta_key()
            .unwrap();
        let refused = StoreMeta::from_tagged_bytes(&other, &sealed)
            .unwrap_err()
            .to_string();
        assert!(refused.contains("tag"), "{refused}");
        assert!(!refused.contains("ab"), "{refused}");

        // Metadata of the schemas before the generation and before the
        // reservations, under the right tag, is refused.
        let tagged = |body: &serde_json::Value| {
            let body = serde_json::to_vec(body).unwrap();
            let mut tagged = key.tag(&body).unwrap().to_vec();
            tagged.extend_from_slice(&body);
            tagged
        };
        let mut older = serde_json::to_value(meta()).unwrap();
        older.as_object_mut().unwrap().remove("reservations");
        older["schema"] = serde_json::json!("uo-runtime-store-meta-v2");
        assert!(StoreMeta::from_tagged_bytes(&key, &tagged(&older)).is_err());
        older.as_object_mut().unwrap().remove("generation");
        older["schema"] = serde_json::json!("uo-runtime-store-meta-v1");
        assert!(StoreMeta::from_tagged_bytes(&key, &tagged(&older)).is_err());

        // A reservation lowered in the metadata, under the tag it had, fails
        // the tag check.
        let mut lowered = serde_json::to_value(meta()).unwrap();
        lowered["reservations"]["balances"] = serde_json::json!(1);
        let mut changed = sealed[..STORE_META_TAG_BYTES].to_vec();
        changed.extend_from_slice(&serde_json::to_vec(&lowered).unwrap());
        let refused = StoreMeta::from_tagged_bytes(&key, &changed)
            .unwrap_err()
            .to_string();
        assert!(refused.contains("tag"), "{refused}");
    }

    /// A commit reserves, for each key, the count a call from its count
    /// resumes at if it is dropped, and so everything that call can seal.
    /// A call starts only if the last commit's reservations cover it: after
    /// a call was dropped, its keys moved to that count, and the next call
    /// waits for a commit that reserves ahead of it.
    #[test]
    fn a_commit_reserves_what_the_next_call_can_seal() {
        let storage = SharedStorage::memory();
        let mut cipher = StoreCipher::random();
        cipher.attach_storage(storage.handle("balances"));
        let ciphers = || vec![cipher.clone_for_runtime_state()];
        let quantum = DROPPED_CALL_SEAL_QUANTUM;
        let reserved = reservations_ahead(&ciphers(), &BTreeMap::new());
        assert_eq!(
            reserved,
            BTreeMap::from([("balances".to_owned(), 2 * quantum)])
        );
        // A call from count 0 starts, and is dropped: the key moves to the
        // reservation, from which no call starts.
        drop(DroppedCallSeals::begin(ciphers(), &reserved).unwrap());
        assert_eq!(cipher.seal_count(), 2 * quantum);
        let refused = DroppedCallSeals::begin(ciphers(), &reserved)
            .unwrap_err()
            .to_string();
        assert!(refused.contains("did not reserve"), "{refused}");
        // A commit that reserves ahead lets it start.
        let ahead = reservations_ahead(&ciphers(), &reserved);
        assert_eq!(ahead["balances"], 4 * quantum);
        DroppedCallSeals::begin(ciphers(), &ahead).unwrap().keep();
        assert_eq!(cipher.seal_count(), 2 * quantum);
        // A reservation never falls, and a key with none starts no call.
        assert_eq!(reservations_ahead(&[], &ahead), ahead);
        assert!(DroppedCallSeals::begin(ciphers(), &BTreeMap::new()).is_err());
    }

    #[test]
    fn a_restart_takes_the_attested_generation_or_one_past_it() {
        // The metadata's generation is 4.
        let meta = meta();
        assert_eq!(meta.against_attested(4).unwrap(), StoreGeneration::Attested);
        assert_eq!(meta.against_attested(3).unwrap(), StoreGeneration::OnePast);
        let behind = meta.against_attested(5).unwrap_err().to_string();
        assert!(
            behind.contains("behind the attested generation 5"),
            "{behind}"
        );
        let past = meta.against_attested(2).unwrap_err().to_string();
        assert!(past.contains("more than one past"), "{past}");
        assert!(meta.against_attested(0).is_err());
        assert!(meta.against_attested(u64::MAX).is_err());
    }
}
