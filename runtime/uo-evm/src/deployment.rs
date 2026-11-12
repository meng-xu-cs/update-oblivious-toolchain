use crate::freshness::RuntimeFreshnessSnapshot;
use crate::return_channel::ReturnChannelSession;
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uo_core::{CompiledArtifact, PublicEnvironment, PublicReceipt};

#[cfg(feature = "diagnostics")]
pub const RUNTIME_BUILD_PROFILE_DESCRIPTOR: &str =
    "uo-runtime-build-profile-v1:diagnostics-enabled";
#[cfg(not(feature = "diagnostics"))]
pub const RUNTIME_BUILD_PROFILE_DESCRIPTOR: &str =
    "uo-runtime-build-profile-v1:production-no-diagnostics";

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProductionRuntimePolicy {
    pub runtime_binary_sha256: String,
    pub proof_root_sha256: String,
    pub accepted_sgx_quote_sha256: String,
    pub build_profile_sha256: String,
}

/// What a caller shows for a production call. Every field is something the
/// caller can know before the call runs: the package and toolchain, the
/// measured runtime and its policy, the public environment, the session, and
/// the receipt the call follows with the counters that receipt carries.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProductionCallEvidence {
    pub admitted_package_sha256: String,
    pub toolchain_manifest_sha256: String,
    pub runtime_binary_sha256: String,
    pub proof_root_sha256: String,
    pub sgx_quote_sha256: String,
    pub build_profile_sha256: String,
    pub public_environment: Box<[String]>,
    pub public_environment_sha256: String,
    pub session_id: String,
    pub attestation_transcript_hash: String,
    pub freshness_epoch: u64,
    pub rollback_counter: u64,
    pub next_call_counter: u64,
    /// The hash of the receipt this call follows: the deployment's receipt
    /// for the first call, and then the receipt of the call before.
    pub previous_receipt_sha256: String,
    pub translation_validation_certificate_sha256: String,
}

/// The value of a receipt's hash fields that name nothing: the receipt
/// before a deployment's, and the public receipt of a deployment.
pub const PRODUCTION_NO_RECEIPT_SHA256: &str =
    "0000000000000000000000000000000000000000000000000000000000000000";

/// What the runtime issues for a deployment and for every call it accepts.
/// A receipt names its request, the receipt before it, the state before and
/// after, what the call's observer saw, and the freshness counters after the
/// call. The receipts of a deployment form a chain, which `follows` checks.
/// Nothing in a receipt derives from a call's private evidence.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProductionReceipt {
    /// The hash of the evidence the call was accepted on. For a deployment,
    /// the hash of what was deployed and under which policy.
    pub request_sha256: String,
    /// The hash of the receipt before this one.
    pub previous_receipt_sha256: String,
    pub public_state_before_sha256: String,
    pub public_state_after_sha256: String,
    /// A digest of every sealed record in storage, before and after.
    pub ciphertext_store_before_sha256: String,
    pub ciphertext_store_after_sha256: String,
    /// The hash of the call's public receipt.
    pub public_receipt_sha256: String,
    pub freshness_epoch: u64,
    pub rollback_counter: u64,
    pub next_call_counter: u64,
}

impl ProductionReceipt {
    /// The hash by which the next call's evidence and the next receipt name
    /// this one.
    pub fn sha256(&self) -> Result<String> {
        Ok(sha256_hex(&serde_json::to_vec(self)?))
    }

    /// Check that this receipt is the one that comes after `previous` in a
    /// deployment's chain: it names `previous` by hash, starts from the state
    /// `previous` ended in, keeps the epoch, and its counters moved on by
    /// one call. A receipt that is replayed, out of order, or changed in a
    /// field that `previous` or this check binds does not follow.
    pub fn follows(&self, previous: &ProductionReceipt) -> Result<()> {
        require_receipt_field(
            "previous_receipt_sha256",
            self.previous_receipt_sha256 == previous.sha256()?,
        )?;
        require_receipt_field(
            "public_state_before_sha256",
            self.public_state_before_sha256 == previous.public_state_after_sha256,
        )?;
        require_receipt_field(
            "ciphertext_store_before_sha256",
            self.ciphertext_store_before_sha256 == previous.ciphertext_store_after_sha256,
        )?;
        require_receipt_field(
            "freshness_epoch",
            self.freshness_epoch == previous.freshness_epoch,
        )?;
        require_receipt_field(
            "next_call_counter",
            Some(self.next_call_counter) == previous.next_call_counter.checked_add(1),
        )?;
        // A call that aborts leaves the rollback counter where it was.
        require_receipt_field(
            "rollback_counter",
            self.rollback_counter == previous.rollback_counter
                || Some(self.rollback_counter) == previous.rollback_counter.checked_add(1),
        )
    }

    /// Check that this receipt is for a call that was made on `evidence` and
    /// returned `receipt`: it names both by hash, its public state before
    /// and after are those of the public-state transition `receipt` records,
    /// and its epoch and counters are the evidence's, moved on by one call.
    ///
    /// The digest of the ciphertext store after the call is bound by neither
    /// argument. The next receipt binds it, and so does the storage itself,
    /// from which a holder can compute it again.
    pub fn binds_call(
        &self,
        evidence: &ProductionCallEvidence,
        receipt: &PublicReceipt,
    ) -> Result<()> {
        require_receipt_field(
            "request_sha256",
            self.request_sha256 == production_call_evidence_sha256(evidence)?,
        )?;
        let transition = receipt.public_state_transition.as_ref();
        require_receipt_field(
            "public_state_before_sha256",
            transition.is_some_and(|transition| {
                transition.initial_public_state_hash == self.public_state_before_sha256
            }),
        )?;
        require_receipt_field(
            "public_state_after_sha256",
            transition.is_some_and(|transition| {
                transition.committed_public_state_hash == self.public_state_after_sha256
            }),
        )?;
        require_receipt_field(
            "previous_receipt_sha256",
            self.previous_receipt_sha256 == evidence.previous_receipt_sha256,
        )?;
        require_receipt_field(
            "public_receipt_sha256",
            self.public_receipt_sha256 == production_public_receipt_sha256(receipt)?,
        )?;
        require_receipt_field(
            "freshness_epoch",
            self.freshness_epoch == evidence.freshness_epoch,
        )?;
        require_receipt_field(
            "next_call_counter",
            Some(self.next_call_counter) == evidence.next_call_counter.checked_add(1),
        )?;
        require_receipt_field(
            "rollback_counter",
            self.rollback_counter == evidence.rollback_counter
                || Some(self.rollback_counter) == evidence.rollback_counter.checked_add(1),
        )
    }

    /// Check that this is the first receipt of a deployment of `artifact`
    /// under `policy`: it names that deployment, no receipt before it and no
    /// call, and its counters are zero.
    pub fn binds_deployment(
        &self,
        artifact: &CompiledArtifact,
        policy: &ProductionRuntimePolicy,
    ) -> Result<()> {
        require_receipt_field(
            "request_sha256",
            self.request_sha256 == production_deployment_request_sha256(artifact, policy)?,
        )?;
        require_receipt_field(
            "previous_receipt_sha256",
            self.previous_receipt_sha256 == PRODUCTION_NO_RECEIPT_SHA256,
        )?;
        require_receipt_field(
            "public_receipt_sha256",
            self.public_receipt_sha256 == PRODUCTION_NO_RECEIPT_SHA256,
        )?;
        require_receipt_field(
            "public_state_before_sha256",
            self.public_state_before_sha256 == self.public_state_after_sha256,
        )?;
        require_receipt_field(
            "ciphertext_store_before_sha256",
            self.ciphertext_store_before_sha256 == self.ciphertext_store_after_sha256,
        )?;
        require_receipt_field("rollback_counter", self.rollback_counter == 0)?;
        require_receipt_field("next_call_counter", self.next_call_counter == 0)
    }

    /// The receipt of a deployment: the first of its chain.
    pub(crate) fn for_deployment(
        artifact: &CompiledArtifact,
        policy: &ProductionRuntimePolicy,
        counters: RuntimeFreshnessSnapshot,
        public_state_sha256: String,
        ciphertext_store_sha256: String,
    ) -> Result<Self> {
        let receipt = Self {
            request_sha256: production_deployment_request_sha256(artifact, policy)?,
            previous_receipt_sha256: PRODUCTION_NO_RECEIPT_SHA256.to_owned(),
            public_state_before_sha256: public_state_sha256.clone(),
            public_state_after_sha256: public_state_sha256,
            ciphertext_store_before_sha256: ciphertext_store_sha256.clone(),
            ciphertext_store_after_sha256: ciphertext_store_sha256,
            public_receipt_sha256: PRODUCTION_NO_RECEIPT_SHA256.to_owned(),
            freshness_epoch: counters.epoch,
            rollback_counter: counters.rollback_counter,
            next_call_counter: counters.next_call_counter,
        };
        receipt.binds_deployment(artifact, policy)?;
        Ok(receipt)
    }

    /// The receipt of a call accepted on `evidence` after `previous`. It is
    /// built before the call commits, from the staged state, and is checked
    /// against the two predicates a holder of the chain would apply.
    pub(crate) fn for_call(
        evidence: &ProductionCallEvidence,
        previous: &ProductionReceipt,
        public_receipt: &PublicReceipt,
        counters_after: RuntimeFreshnessSnapshot,
        public_state_after_sha256: String,
        ciphertext_store_after_sha256: String,
    ) -> Result<Self> {
        let receipt = Self {
            request_sha256: production_call_evidence_sha256(evidence)?,
            previous_receipt_sha256: evidence.previous_receipt_sha256.clone(),
            public_state_before_sha256: previous.public_state_after_sha256.clone(),
            public_state_after_sha256,
            ciphertext_store_before_sha256: previous.ciphertext_store_after_sha256.clone(),
            ciphertext_store_after_sha256,
            public_receipt_sha256: production_public_receipt_sha256(public_receipt)?,
            freshness_epoch: counters_after.epoch,
            rollback_counter: counters_after.rollback_counter,
            next_call_counter: counters_after.next_call_counter,
        };
        receipt.follows(previous)?;
        receipt.binds_call(evidence, public_receipt)?;
        Ok(receipt)
    }
}

/// The hash a receipt carries for the evidence its call was accepted on.
pub fn production_call_evidence_sha256(evidence: &ProductionCallEvidence) -> Result<String> {
    Ok(sha256_hex(&serde_json::to_vec(evidence)?))
}

/// The hash a receipt carries for what its call's observer saw.
pub fn production_public_receipt_sha256(receipt: &PublicReceipt) -> Result<String> {
    Ok(sha256_hex(&serde_json::to_vec(receipt)?))
}

/// The hash a deployment's receipt carries for its request: the package that
/// was deployed, the policy it was deployed under, and the certificate that
/// binds the artifact's contents.
pub fn production_deployment_request_sha256(
    artifact: &CompiledArtifact,
    policy: &ProductionRuntimePolicy,
) -> Result<String> {
    let identity = artifact
        .admitted_package
        .as_ref()
        .ok_or_else(|| anyhow!("production runtime requires admitted_package identity"))?;
    let request = serde_json::json!({
        "schema": "uo.production_deployment_request.v1",
        "admitted_package_sha256": identity.package_sha256,
        "toolchain_manifest_sha256": identity.toolchain_manifest_sha256,
        "runtime_binary_sha256": policy.runtime_binary_sha256,
        "proof_root_sha256": policy.proof_root_sha256,
        "accepted_sgx_quote_sha256": policy.accepted_sgx_quote_sha256,
        "build_profile_sha256": policy.build_profile_sha256,
        "translation_validation_certificate_sha256":
            production_translation_validation_certificate_sha256(artifact, policy)?,
    });
    Ok(sha256_hex(&serde_json::to_vec(&request)?))
}

/// Translation-validation certificate hash binding the admitted-package
/// identity, the proof-relevant artifact-view hash (the artifact contents), and
/// the deployment proof-root. Because the admitted-package identity binds only
/// source + sidecar metadata, this certificate is the separate binding that
/// detects post-compilation tampering of `contract.state`, `contract.functions`,
/// `manifest.objects`, or the confidential slot program: the runtime recomputes
/// it from the deployed artifact and compares it to the attested evidence.
pub fn production_translation_validation_certificate_sha256(
    artifact: &CompiledArtifact,
    policy: &ProductionRuntimePolicy,
) -> Result<String> {
    let identity = artifact
        .admitted_package
        .as_ref()
        .ok_or_else(|| anyhow!("production runtime requires admitted_package identity"))?;
    let view_sha256 = uo_core::proof_relevant_view_sha256(artifact)?;
    let certificate = serde_json::json!({
        "schema": "uo.translation_validation_certificate.v1",
        "admitted_package_sha256": identity.package_sha256,
        "toolchain_manifest_sha256": identity.toolchain_manifest_sha256,
        "proof_relevant_view_sha256": view_sha256,
        "proof_root_sha256": policy.proof_root_sha256,
    });
    Ok(sha256_hex(&serde_json::to_vec(&certificate)?))
}

pub fn production_build_profile_sha256() -> String {
    sha256_hex(RUNTIME_BUILD_PROFILE_DESCRIPTOR.as_bytes())
}

pub fn production_public_environment_transcript(environment: &PublicEnvironment) -> Box<[String]> {
    environment.full_public_bindings().into_boxed_slice()
}

pub fn production_public_environment_sha256(environment: &PublicEnvironment) -> Result<String> {
    Ok(sha256_hex(&serde_json::to_vec(
        &production_public_environment_transcript(environment),
    )?))
}

pub(crate) fn validate_production_artifact(artifact: &CompiledArtifact) -> Result<()> {
    let identity = artifact
        .admitted_package
        .as_ref()
        .ok_or_else(|| anyhow!("production runtime requires admitted_package identity"))?;
    identity
        .validate_proof_grade()
        .map_err(|err| anyhow!("production runtime admitted package validation failed: {err}"))?;
    validate_sha256_hex("admitted_package.package_sha256", &identity.package_sha256)?;
    validate_sha256_hex(
        "admitted_package.toolchain_manifest_sha256",
        &identity.toolchain_manifest_sha256,
    )?;
    Ok(())
}

pub(crate) fn validate_production_call_preflight(
    artifact: &CompiledArtifact,
    policy: &ProductionRuntimePolicy,
    evidence: &ProductionCallEvidence,
    session: &ReturnChannelSession,
    environment: &PublicEnvironment,
    freshness: RuntimeFreshnessSnapshot,
    last_receipt_sha256: &str,
) -> Result<()> {
    validate_production_artifact(artifact)?;
    validate_policy(policy)?;
    validate_evidence_hashes(evidence)?;
    validate_public_environment_evidence(evidence, environment)?;
    let identity = artifact
        .admitted_package
        .as_ref()
        .ok_or_else(|| anyhow!("production runtime requires admitted_package identity"))?;
    require_equal(
        "admitted_package_sha256",
        &evidence.admitted_package_sha256,
        &identity.package_sha256,
    )?;
    require_equal(
        "toolchain_manifest_sha256",
        &evidence.toolchain_manifest_sha256,
        &identity.toolchain_manifest_sha256,
    )?;
    require_equal(
        "runtime_binary_sha256",
        &evidence.runtime_binary_sha256,
        &policy.runtime_binary_sha256,
    )?;
    require_equal(
        "proof_root_sha256",
        &evidence.proof_root_sha256,
        &policy.proof_root_sha256,
    )?;
    require_equal(
        "sgx_quote_sha256",
        &evidence.sgx_quote_sha256,
        &policy.accepted_sgx_quote_sha256,
    )?;
    require_equal(
        "build_profile_sha256",
        &evidence.build_profile_sha256,
        &policy.build_profile_sha256,
    )?;
    // Recompute the translation-validation certificate from the deployed
    // artifact and require it to match the attested evidence, before execution.
    // This rejects post-compilation tampering of the artifact contents.
    require_equal(
        "translation_validation_certificate_sha256",
        &evidence.translation_validation_certificate_sha256,
        &production_translation_validation_certificate_sha256(artifact, policy)?,
    )?;
    require_equal(
        "session_id",
        &evidence.session_id,
        &session.binding().session_id,
    )?;
    require_equal(
        "attestation_transcript_hash",
        &evidence.attestation_transcript_hash,
        &session.binding().attestation_transcript_hash,
    )?;
    // A mismatch names the field and prints no value. An error reaches the
    // caller, and a caller whose evidence is wrong has not shown that it
    // knows the runtime's epoch and counters.
    require_equal_counter("freshness_epoch", evidence.freshness_epoch, freshness.epoch)?;
    require_equal_counter(
        "rollback_counter",
        evidence.rollback_counter,
        freshness.rollback_counter,
    )?;
    require_equal_counter(
        "next_call_counter",
        evidence.next_call_counter,
        freshness.next_call_counter,
    )?;
    // The call must follow the receipt the runtime issued last. A caller
    // that holds an older receipt, or one that was changed on its way, names
    // another hash.
    require_equal(
        "previous_receipt_sha256",
        &evidence.previous_receipt_sha256,
        last_receipt_sha256,
    )
}

pub(crate) fn validate_production_public_environment_trace(
    receipt: &PublicReceipt,
    expected_projection: &[String],
) -> Result<()> {
    let public_outcome = receipt
        .theorem_trace
        .public_outcome
        .as_ref()
        .ok_or_else(|| anyhow!("production runtime theorem trace missing public_outcome"))?;
    if public_outcome.public_env.as_ref() != expected_projection {
        bail!("production runtime public_environment projection mismatch");
    }
    Ok(())
}

pub(crate) fn validate_production_policy(policy: &ProductionRuntimePolicy) -> Result<()> {
    validate_policy(policy)
}

fn validate_policy(policy: &ProductionRuntimePolicy) -> Result<()> {
    validate_sha256_hex("runtime_binary_sha256", &policy.runtime_binary_sha256)?;
    validate_sha256_hex("proof_root_sha256", &policy.proof_root_sha256)?;
    validate_sha256_hex(
        "accepted_sgx_quote_sha256",
        &policy.accepted_sgx_quote_sha256,
    )?;
    validate_sha256_hex("build_profile_sha256", &policy.build_profile_sha256)?;
    require_equal(
        "build_profile_sha256",
        &policy.build_profile_sha256,
        &production_build_profile_sha256(),
    )?;
    if cfg!(feature = "diagnostics") {
        bail!("production runtime build profile enables diagnostics");
    }
    Ok(())
}

fn validate_evidence_hashes(evidence: &ProductionCallEvidence) -> Result<()> {
    validate_sha256_hex("admitted_package_sha256", &evidence.admitted_package_sha256)?;
    validate_sha256_hex(
        "toolchain_manifest_sha256",
        &evidence.toolchain_manifest_sha256,
    )?;
    validate_sha256_hex("runtime_binary_sha256", &evidence.runtime_binary_sha256)?;
    validate_sha256_hex("proof_root_sha256", &evidence.proof_root_sha256)?;
    validate_sha256_hex("sgx_quote_sha256", &evidence.sgx_quote_sha256)?;
    validate_sha256_hex("build_profile_sha256", &evidence.build_profile_sha256)?;
    validate_sha256_hex(
        "public_environment_sha256",
        &evidence.public_environment_sha256,
    )?;
    validate_sha256_hex("session_id", &evidence.session_id)?;
    validate_sha256_hex(
        "attestation_transcript_hash",
        &evidence.attestation_transcript_hash,
    )?;
    validate_sha256_hex("previous_receipt_sha256", &evidence.previous_receipt_sha256)?;
    validate_sha256_hex(
        "translation_validation_certificate_sha256",
        &evidence.translation_validation_certificate_sha256,
    )
}

fn validate_public_environment_evidence(
    evidence: &ProductionCallEvidence,
    environment: &PublicEnvironment,
) -> Result<()> {
    let expected_transcript = production_public_environment_transcript(environment);
    if evidence.public_environment.as_ref() != expected_transcript.as_ref() {
        bail!("production runtime public_environment transcript mismatch");
    }
    let expected_hash = production_public_environment_sha256(environment)?;
    require_equal(
        "public_environment_sha256",
        &evidence.public_environment_sha256,
        &expected_hash,
    )
}

fn validate_sha256_hex(label: &str, value: &str) -> Result<()> {
    if value.len() != 64 || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        bail!("{label} must be a 64-character hex SHA-256 digest");
    }
    Ok(())
}

fn require_equal(label: &str, actual: &str, expected: &str) -> Result<()> {
    if actual != expected {
        bail!("production runtime {label} mismatch");
    }
    Ok(())
}

fn require_receipt_field(label: &str, holds: bool) -> Result<()> {
    if !holds {
        bail!("production receipt {label} mismatch");
    }
    Ok(())
}

fn require_equal_counter(label: &str, evidence: u64, runtime: u64) -> Result<()> {
    if evidence != runtime {
        bail!("production runtime {label} mismatch");
    }
    Ok(())
}

fn sha256_hex(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}
