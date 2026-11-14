//! The public metadata a deployment leaves in its store with every commit,
//! and how a runtime that restarts from the store takes it back.
//!
//! The metadata is what a restart cannot read off the records: the
//! freshness counters, whether the contract is initialized, and the digest
//! of the public state. All of it is public. It carries a tag under a key
//! that derives from the master secret, so a restart takes only metadata
//! that a runtime with the same secret wrote. The tag does not say that the
//! metadata is the latest: that is the rollback counter's part, which a
//! restart compares with an attested one.

use crate::freshness::RuntimeFreshnessSnapshot;
use crate::secret::StoreMetaKey;
use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use uo_store::SharedStorage;

const STORE_META_SCHEMA: &str = "uo-runtime-store-meta-v1";
#[cfg_attr(not(any(test, feature = "diagnostics")), allow(dead_code))]
const STORE_META_TAG_BYTES: usize = 32;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct StoreMeta {
    schema: String,
    epoch: u64,
    rollback_counter: u64,
    next_call_counter: u64,
    pub(crate) initialized: bool,
    pub(crate) public_state_sha256: String,
}

impl StoreMeta {
    pub(crate) fn new(
        freshness: RuntimeFreshnessSnapshot,
        initialized: bool,
        public_state_sha256: String,
    ) -> Self {
        Self {
            schema: STORE_META_SCHEMA.into(),
            epoch: freshness.epoch,
            rollback_counter: freshness.rollback_counter,
            next_call_counter: freshness.next_call_counter,
            initialized,
            public_state_sha256,
        }
    }

    #[cfg_attr(not(any(test, feature = "diagnostics")), allow(dead_code))]
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
    #[cfg_attr(not(any(test, feature = "diagnostics")), allow(dead_code))]
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
    /// is dropped.
    pub(crate) fn make_durable(mut self, meta: &[u8]) -> Result<()> {
        self.storage.with(|adapter| adapter.commit(meta))?;
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

/// Commit the records a deployment handed the store, with the deployment's
/// commit metadata.
pub(crate) fn make_deployment_durable(storage: &SharedStorage, meta: &[u8]) -> Result<()> {
    storage.with(|adapter| adapter.commit(meta))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::secret::RuntimeMasterSecret;

    fn meta() -> StoreMeta {
        StoreMeta::new(
            RuntimeFreshnessSnapshot {
                epoch: 7,
                rollback_counter: 3,
                next_call_counter: 5,
            },
            true,
            "ab".repeat(32),
        )
    }

    #[test]
    fn commit_metadata_opens_only_with_its_tag() {
        let key = RuntimeMasterSecret::from_diagnostic_seed(1)
            .store_meta_key()
            .unwrap();
        let sealed = meta().tagged_bytes(&key).unwrap();
        let opened = StoreMeta::from_tagged_bytes(&key, &sealed).unwrap();
        assert_eq!(opened, meta());
        assert_eq!(opened.freshness().rollback_counter, 3);

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
    }
}
