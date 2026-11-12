use crate::freshness::RuntimeFreshnessSnapshot;
use crate::return_channel::ReturnChannelSession;
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uo_core::{CompiledArtifact, ExecutionTrace, PublicEnvironment};

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
    pub proof_bundle_sha256: String,
    pub translation_validation_certificate_sha256: String,
}

pub fn production_proof_bundle_sha256(
    artifact: &CompiledArtifact,
    trace: &ExecutionTrace,
) -> Result<String> {
    let bundle = trace.runtime_confidential_proof_bundle_family(artifact)?;
    Ok(sha256_hex(&serde_json::to_vec(&bundle)?))
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
    )
}

pub(crate) fn validate_production_public_environment_trace(
    trace: &ExecutionTrace,
    expected_projection: &[String],
) -> Result<()> {
    let public_outcome = trace
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

pub(crate) fn validate_production_proof_bundle(
    artifact: &CompiledArtifact,
    trace: &ExecutionTrace,
    evidence: &ProductionCallEvidence,
) -> Result<()> {
    let actual = production_proof_bundle_sha256(artifact, trace)?;
    require_equal(
        "proof_bundle_sha256",
        &evidence.proof_bundle_sha256,
        &actual,
    )
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
    validate_sha256_hex("proof_bundle_sha256", &evidence.proof_bundle_sha256)?;
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

fn require_equal_counter(label: &str, evidence: u64, runtime: u64) -> Result<()> {
    if evidence != runtime {
        bail!("production runtime {label} mismatch");
    }
    Ok(())
}

fn sha256_hex(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}
