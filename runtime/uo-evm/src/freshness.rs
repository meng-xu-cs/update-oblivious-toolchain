use anyhow::{bail, Result};
use rand::rngs::OsRng;
use rand::RngCore;
use sha2::{Digest, Sha256};
use uo_core::ReturnChannelPublicBinding;

// The Path ORAM leaf coins derive from the runtime's secrets. The generated
// ORAM codecs import them from here.
pub(crate) use crate::secret::{derive_path_oram_leaf, PathOramLeafSeed};

const RUNTIME_FRESHNESS_DOMAIN: &[u8] = b"uo-runtime-freshness-v1";
const RETURN_NONCE_DOMAIN: &[u8] = b"return-channel-nonce";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct RuntimeCallFreshness {
    epoch: u64,
    rollback_counter: u64,
    call_counter: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct RuntimeFreshnessSnapshot {
    pub epoch: u64,
    pub rollback_counter: u64,
    pub next_call_counter: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct RuntimeFreshnessState {
    epoch: u64,
    rollback_counter: u64,
    next_call_counter: u64,
}

impl RuntimeFreshnessState {
    pub(crate) fn from_os_rng() -> Self {
        Self::from_epoch(OsRng.next_u64())
    }

    pub(crate) fn from_epoch(epoch: u64) -> Self {
        Self {
            epoch,
            rollback_counter: 0,
            next_call_counter: 0,
        }
    }

    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn recover(
        snapshot: RuntimeFreshnessSnapshot,
        attested_rollback_counter: u64,
    ) -> Result<Self> {
        if snapshot.rollback_counter != attested_rollback_counter {
            bail!(
                "runtime freshness rollback counter mismatch: sealed {}, attested {}",
                snapshot.rollback_counter,
                attested_rollback_counter
            );
        }
        Ok(Self {
            epoch: snapshot.epoch,
            rollback_counter: snapshot.rollback_counter,
            next_call_counter: snapshot.next_call_counter,
        })
    }

    pub(crate) fn snapshot(&self) -> RuntimeFreshnessSnapshot {
        RuntimeFreshnessSnapshot {
            epoch: self.epoch,
            rollback_counter: self.rollback_counter,
            next_call_counter: self.next_call_counter,
        }
    }

    pub(crate) fn begin_call(&mut self) -> Result<RuntimeCallFreshness> {
        let call_counter = self.next_call_counter;
        self.next_call_counter = self
            .next_call_counter
            .checked_add(1)
            .ok_or_else(|| anyhow::anyhow!("runtime freshness call counter overflow"))?;
        Ok(RuntimeCallFreshness {
            epoch: self.epoch,
            rollback_counter: self.rollback_counter,
            call_counter,
        })
    }

    pub(crate) fn finish_call(&mut self, aborted: bool) -> Result<()> {
        if aborted {
            return Ok(());
        }
        self.rollback_counter = self
            .rollback_counter
            .checked_add(1)
            .ok_or_else(|| anyhow::anyhow!("runtime freshness rollback counter overflow"))?;
        Ok(())
    }
}

impl RuntimeCallFreshness {
    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn call_counter(&self) -> u64 {
        self.call_counter
    }

    pub(crate) fn derive_return_nonce(
        &self,
        binding: &ReturnChannelPublicBinding,
        aad_hash: &str,
    ) -> [u8; 12] {
        let digest = freshness_digest(&[
            RETURN_NONCE_DOMAIN,
            &self.epoch.to_be_bytes(),
            &self.rollback_counter.to_be_bytes(),
            &self.call_counter.to_be_bytes(),
            binding.scheme.as_bytes(),
            binding.session_id.as_bytes(),
            binding.client_public_key_hash.as_bytes(),
            binding.attestation_transcript_hash.as_bytes(),
            aad_hash.as_bytes(),
        ]);
        let mut nonce = [0u8; 12];
        nonce.copy_from_slice(&digest[..12]);
        nonce
    }
}

fn freshness_digest(parts: &[&[u8]]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(RUNTIME_FRESHNESS_DOMAIN);
    for part in parts {
        hasher.update((part.len() as u64).to_be_bytes());
        hasher.update(part);
    }
    hasher.finalize().into()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn binding(session_byte: u8) -> ReturnChannelPublicBinding {
        ReturnChannelPublicBinding {
            scheme: "chacha20poly1305_session_v1".into(),
            session_id: format!("{session_byte:02x}").repeat(32),
            client_public_key_hash: "22".repeat(32),
            attestation_transcript_hash: "33".repeat(32),
        }
    }

    #[test]
    fn return_nonce_derivation_is_domain_separated() {
        let mut freshness = RuntimeFreshnessState::from_epoch(7);
        let first = freshness.begin_call().unwrap();
        let second = freshness.begin_call().unwrap();
        let binding_a = binding(0x11);
        let binding_b = binding(0x12);

        assert_ne!(
            first.derive_return_nonce(&binding_a, "aa"),
            second.derive_return_nonce(&binding_a, "aa")
        );
        assert_ne!(
            first.derive_return_nonce(&binding_a, "aa"),
            first.derive_return_nonce(&binding_b, "aa")
        );
        assert_ne!(
            first.derive_return_nonce(&binding_a, "aa"),
            first.derive_return_nonce(&binding_a, "bb")
        );
    }

    #[test]
    fn runtime_counters_are_monotone_and_abort_preserves_rollback_counter() {
        let mut freshness = RuntimeFreshnessState::from_epoch(9);
        let first = freshness.begin_call().unwrap();
        assert_eq!(first.call_counter(), 0);
        freshness.finish_call(false).unwrap();
        assert_eq!(freshness.snapshot().rollback_counter, 1);
        let second = freshness.begin_call().unwrap();
        assert_eq!(second.call_counter(), 1);
        freshness.finish_call(true).unwrap();
        assert_eq!(freshness.snapshot().rollback_counter, 1);
        assert_eq!(freshness.snapshot().next_call_counter, 2);
    }

    #[test]
    fn crash_recovery_resumes_monotone_counters() {
        let mut freshness = RuntimeFreshnessState::from_epoch(13);
        let _ = freshness.begin_call().unwrap();
        freshness.finish_call(false).unwrap();
        let snapshot = freshness.snapshot();
        let mut recovered =
            RuntimeFreshnessState::recover(snapshot, snapshot.rollback_counter).unwrap();
        let call = recovered.begin_call().unwrap();
        assert_eq!(call.call_counter(), snapshot.next_call_counter);
    }

    #[test]
    fn rollback_counter_mismatch_is_rejected() {
        let snapshot = RuntimeFreshnessSnapshot {
            epoch: 17,
            rollback_counter: 2,
            next_call_counter: 5,
        };
        let err = RuntimeFreshnessState::recover(snapshot, 1).unwrap_err();
        assert!(err.to_string().contains("rollback counter mismatch"));
    }

    #[test]
    fn production_sources_use_counter_freshness_not_ad_hoc_leaf_sampling() {
        let objects = include_str!("objects.rs")
            .split("#[cfg(test)]")
            .next()
            .expect("objects.rs should contain a test boundary marker");
        assert!(objects.contains("PathOramLeafCoinSource::from_domain_seed"));
        assert!(!objects.contains("PathOramLeafCoinSource::random()"));

        let codecs = include_str!("generated_oram_codecs.rs");
        assert!(codecs.contains("derive_path_oram_leaf("));
        assert!(!codecs.contains("rng.next_u64() as usize"));
    }
}
