//! What a caller of a production runtime can learn from it.
//!
//! These tests use only the crate's public API, in the build a production
//! runtime uses. The `diagnostics` feature adds seeded deployments and is
//! rejected by the production policy, so they do not apply to it. A workspace
//! build turns that feature on (`mplus-probe` depends on it), so run them
//! with `cargo test -p uo-evm`.
#![cfg(not(feature = "diagnostics"))]

use sha2::{Digest, Sha256};
use uo_core::{
    CompiledArtifact, ContractMetadata, ProgramMode, PublicEnvironment, ReturnChannelPublicBinding,
    Value,
};
use uo_evm::{
    production_build_profile_sha256, production_public_environment_sha256,
    production_public_environment_transcript, ContractInstance, ProductionCallEvidence,
    ProductionContractInstance, ProductionRuntimePolicy, ReturnChannelSession,
    RETURN_CHANNEL_SCHEME,
};

fn single_access_map() -> CompiledArtifact {
    let source = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../benches/raw/SingleAccessMap.sol"
    );
    let metadata = include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../benches/raw/SingleAccessMap.pathoram.yaml"
    ));
    let parsed: ContractMetadata = serde_yaml::from_str(metadata).unwrap();
    uo_solc::compile_with_metadata_bytes(source, &parsed, metadata.as_bytes(), ProgramMode::Uo)
        .unwrap()
}

fn policy() -> ProductionRuntimePolicy {
    ProductionRuntimePolicy {
        runtime_binary_sha256: "aa".repeat(32),
        proof_root_sha256: "bb".repeat(32),
        accepted_sgx_quote_sha256: "cc".repeat(32),
        build_profile_sha256: production_build_profile_sha256(),
    }
}

fn session() -> ReturnChannelSession {
    ReturnChannelSession::new(
        [7u8; 32],
        ReturnChannelPublicBinding {
            scheme: RETURN_CHANNEL_SCHEME.into(),
            session_id: "11".repeat(32),
            client_public_key_hash: "22".repeat(32),
            attestation_transcript_hash: "33".repeat(32),
        },
    )
    .unwrap()
}

/// Call evidence built from values a host knows, with a guessed freshness
/// epoch. The translation certificate is a hash over public values.
fn public_evidence(
    artifact: &CompiledArtifact,
    policy: &ProductionRuntimePolicy,
    session: &ReturnChannelSession,
    environment: &PublicEnvironment,
    freshness_epoch: u64,
) -> ProductionCallEvidence {
    let identity = artifact.admitted_package.as_ref().unwrap();
    let certificate = serde_json::json!({
        "schema": "uo.translation_validation_certificate.v1",
        "admitted_package_sha256": identity.package_sha256,
        "toolchain_manifest_sha256": identity.toolchain_manifest_sha256,
        "proof_relevant_view_sha256": uo_core::proof_relevant_view_sha256(artifact).unwrap(),
        "proof_root_sha256": policy.proof_root_sha256,
    });
    ProductionCallEvidence {
        admitted_package_sha256: identity.package_sha256.clone(),
        toolchain_manifest_sha256: identity.toolchain_manifest_sha256.clone(),
        runtime_binary_sha256: policy.runtime_binary_sha256.clone(),
        proof_root_sha256: policy.proof_root_sha256.clone(),
        sgx_quote_sha256: policy.accepted_sgx_quote_sha256.clone(),
        build_profile_sha256: policy.build_profile_sha256.clone(),
        public_environment: production_public_environment_transcript(environment),
        public_environment_sha256: production_public_environment_sha256(environment).unwrap(),
        session_id: session.binding().session_id.clone(),
        attestation_transcript_hash: session.binding().attestation_transcript_hash.clone(),
        freshness_epoch,
        rollback_counter: 0,
        next_call_counter: 0,
        proof_bundle_sha256: "00".repeat(32),
        translation_validation_certificate_sha256: hex::encode(Sha256::digest(
            serde_json::to_vec(&certificate).unwrap(),
        )),
    }
}

/// A production deployment draws its freshness epoch from the OS. A call
/// whose evidence guesses the epoch wrong is rejected with an error that
/// names the field and carries no value of the runtime's.
#[test]
fn a_rejected_production_call_returns_no_runtime_value() {
    let artifact = single_access_map();
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    for guess in [0, 1, u64::MAX] {
        let mut production =
            ProductionContractInstance::deploy(artifact.clone(), policy.clone()).unwrap();
        let evidence = public_evidence(&artifact, &policy, &session, &environment, guess);
        let err = production
            .call_authorized(
                "put(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
                &session,
                &evidence,
            )
            .unwrap_err();
        assert_eq!(
            err.to_string(),
            "production runtime freshness_epoch mismatch"
        );
        assert!(!format!("{production:?}").contains("epoch"));
    }
}

/// The trace of a deployment from OS randomness carries no seed.
#[test]
fn the_trace_of_an_unseeded_deployment_carries_no_seed() {
    let artifact = single_access_map();
    let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
    let result = instance
        .call(
            "put(bytes32,uint256)",
            vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
        )
        .unwrap();
    assert_eq!(result.trace.runtime_seed(), None);
    let trace = serde_json::to_value(&result.trace).unwrap();
    assert!(trace["runtime_seed"].is_null());
    let bundle =
        serde_json::to_value(result.trace.runtime_trusted_kernel_bundle().unwrap()).unwrap();
    assert!(bundle["runtime_seed"].is_null());
    let family = serde_json::to_string(
        &result
            .trace
            .runtime_confidential_proof_bundle_family(&artifact)
            .unwrap(),
    )
    .unwrap();
    // A seed tag in the proof bundles is absent, or is the index 0 of a
    // singleton family. It is never a deployment seed.
    let tag = "\"runtime_seed\":";
    assert!(family.contains(tag));
    for (at, _) in family.match_indices(tag) {
        let value = &family[at + tag.len()..];
        assert!(
            value.starts_with("null") || value.starts_with("0,") || value.starts_with("0}"),
            "unexpected seed tag {}",
            &value[..value.len().min(24)]
        );
    }
}
