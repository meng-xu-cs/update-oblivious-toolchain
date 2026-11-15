//! What a caller of a production runtime can learn from it.
//!
//! These tests use only the crate's public API, in the build a production
//! runtime uses. The `diagnostics` feature adds seeded deployments and is
//! rejected by the production policy, so they do not apply to it. A workspace
//! build turns that feature on (`mplus-probe` depends on it), so run them
//! with `cargo test -p uo-evm`.
#![cfg(not(feature = "diagnostics"))]

use std::collections::BTreeSet;
use uo_core::{
    CompiledArtifact, ContractMetadata, ProgramMode, PublicEnvironment, ReturnChannelPublicBinding,
    Value,
};
use uo_evm::{
    production_build_profile_sha256, production_public_environment_sha256,
    production_public_environment_transcript, production_translation_validation_certificate_sha256,
    verify_production_receipt, ContractInstance, ProductionCallEvidence,
    ProductionContractInstance, ProductionReceipt, ProductionRuntimePolicy, ReturnChannelSession,
    PRODUCTION_NO_RECEIPT_SHA256, RETURN_CHANNEL_SCHEME,
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

/// A contract with a map of each Path ORAM scheme: `balances` keeps its
/// position map in a private tree, `allowances` keeps it in the enclave.
/// Every entrypoint is confidential.
fn two_scheme_token() -> CompiledArtifact {
    let source = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../benches/raw/ERC20Lite.sol"
    );
    let metadata = include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../benches/raw/ERC20Lite.private-posmap.yaml"
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

/// Call evidence built from what a caller knows: the artifact, the policy,
/// the session, the public environment, and the receipt the call follows,
/// which carries the runtime's epoch and counters.
fn public_evidence(
    artifact: &CompiledArtifact,
    policy: &ProductionRuntimePolicy,
    session: &ReturnChannelSession,
    environment: &PublicEnvironment,
    previous: &ProductionReceipt,
) -> ProductionCallEvidence {
    let identity = artifact.admitted_package.as_ref().unwrap();
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
        freshness_epoch: previous.freshness_epoch,
        rollback_counter: previous.rollback_counter,
        next_call_counter: previous.next_call_counter,
        previous_receipt_sha256: previous.sha256().unwrap(),
        translation_validation_certificate_sha256:
            production_translation_validation_certificate_sha256(artifact, policy).unwrap(),
    }
}

fn put(key: u8, value: u64) -> Vec<Value> {
    vec![Value::Bytes32([key; 32]), Value::uint(value)]
}

/// A deployment from OS randomness accepts calls from public evidence alone:
/// the caller needs no seed and no second instance. Each accepted call
/// returns a receipt that follows the one its evidence named.
#[test]
fn a_production_deployment_accepts_calls_from_public_evidence_alone() {
    let artifact = single_access_map();
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let mut production =
        ProductionContractInstance::deploy(artifact.clone(), policy.clone()).unwrap();

    let deployed = production.last_receipt().clone();
    deployed.binds_deployment(&artifact, &policy).unwrap();
    assert_eq!(
        deployed.previous_receipt_sha256,
        PRODUCTION_NO_RECEIPT_SHA256
    );
    assert_eq!(
        (deployed.rollback_counter, deployed.next_call_counter),
        (0, 0)
    );

    let mut head = deployed.clone();
    let mut chain = vec![deployed];
    for (key, value) in [(7u8, 5u64), (8, 6), (7, 9)] {
        let evidence = public_evidence(&artifact, &policy, &session, &environment, &head);
        let accepted = production
            .call_authorized("put(bytes32,uint256)", put(key, value), &session, &evidence)
            .unwrap();
        assert!(!accepted.call.aborted);
        accepted.receipt.follows(&head).unwrap();
        accepted
            .receipt
            .binds_call(&evidence, accepted.call.receipt())
            .unwrap();
        // The call wrote sealed records and no public state.
        assert_ne!(
            accepted.receipt.ciphertext_store_after_sha256,
            accepted.receipt.ciphertext_store_before_sha256
        );
        assert_eq!(
            accepted.receipt.public_state_after_sha256,
            accepted.receipt.public_state_before_sha256
        );
        assert_eq!(production.last_receipt(), &accepted.receipt);
        head = accepted.receipt.clone();
        chain.push(accepted.receipt);
    }
    assert_eq!(chain.len(), 4);
    assert_eq!((head.rollback_counter, head.next_call_counter), (3, 3));
    for pair in chain.windows(2) {
        pair[1].follows(&pair[0]).unwrap();
    }

    // A second deployment of the same artifact starts another chain.
    let other = ProductionContractInstance::deploy(artifact.clone(), policy.clone()).unwrap();
    assert_ne!(other.last_receipt(), &chain[0]);
    assert_ne!(
        other.last_receipt().freshness_epoch,
        chain[0].freshness_epoch
    );
    assert_ne!(
        other.last_receipt().ciphertext_store_after_sha256,
        chain[0].ciphertext_store_after_sha256
    );
    assert!(chain[1].follows(other.last_receipt()).is_err());
}

/// The receipts of a deployment chain. A receipt that is replayed, out of
/// order or changed in any field is rejected: by the predicates a holder of
/// the chain applies, and by the runtime when the next call names it.
#[test]
fn a_replayed_reordered_or_changed_receipt_is_rejected() {
    let artifact = single_access_map();
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let mut production =
        ProductionContractInstance::deploy(artifact.clone(), policy.clone()).unwrap();
    let deployed = production.last_receipt().clone();
    let first_evidence = public_evidence(&artifact, &policy, &session, &environment, &deployed);
    let first = production
        .call_authorized("put(bytes32,uint256)", put(7, 5), &session, &first_evidence)
        .unwrap();
    let second_evidence =
        public_evidence(&artifact, &policy, &session, &environment, &first.receipt);
    let second = production
        .call_authorized(
            "put(bytes32,uint256)",
            put(8, 6),
            &session,
            &second_evidence,
        )
        .unwrap();
    let (first_receipt, second_receipt) = (&first.receipt, &second.receipt);
    first_receipt.follows(&deployed).unwrap();
    second_receipt.follows(first_receipt).unwrap();

    // Replayed, skipped and reordered receipts do not follow.
    assert!(first_receipt.follows(first_receipt).is_err());
    assert!(second_receipt.follows(&deployed).is_err());
    assert!(first_receipt.follows(second_receipt).is_err());
    assert!(deployed.follows(first_receipt).is_err());
    assert!(first_receipt.binds_deployment(&artifact, &policy).is_err());

    // Every field of a receipt is bound. Change each one in the first
    // call's receipt and see which check rejects the result: that it follows
    // the deployment's receipt, that it is the receipt of its call, or only
    // that the next receipt follows it.
    type Change = Box<dyn Fn(&mut ProductionReceipt)>;
    let hash = || "5a".repeat(32);
    // (field, the change, rejected by `follows`, rejected by `binds_call`)
    let changes: Vec<(&str, Change, bool, bool)> = vec![
        (
            "request_sha256",
            Box::new(move |r| r.request_sha256 = hash()),
            false,
            true,
        ),
        (
            "previous_receipt_sha256",
            Box::new(move |r| r.previous_receipt_sha256 = hash()),
            true,
            true,
        ),
        (
            "public_state_before_sha256",
            Box::new(move |r| r.public_state_before_sha256 = hash()),
            true,
            true,
        ),
        (
            "public_state_after_sha256",
            Box::new(move |r| r.public_state_after_sha256 = hash()),
            false,
            true,
        ),
        (
            "ciphertext_store_before_sha256",
            Box::new(move |r| r.ciphertext_store_before_sha256 = hash()),
            true,
            false,
        ),
        // Bound by the next receipt, and by the storage itself.
        (
            "ciphertext_store_after_sha256",
            Box::new(move |r| r.ciphertext_store_after_sha256 = hash()),
            false,
            false,
        ),
        (
            "public_receipt_sha256",
            Box::new(move |r| r.public_receipt_sha256 = hash()),
            false,
            true,
        ),
        (
            "freshness_epoch",
            Box::new(|r| r.freshness_epoch ^= 1),
            true,
            true,
        ),
        (
            "rollback_counter",
            Box::new(|r| r.rollback_counter += 2),
            true,
            true,
        ),
        (
            "next_call_counter",
            Box::new(|r| r.next_call_counter += 1),
            true,
            true,
        ),
    ];
    let fields: Vec<String> = serde_json::to_value(first_receipt)
        .unwrap()
        .as_object()
        .unwrap()
        .keys()
        .cloned()
        .collect();
    assert_eq!(changes.len(), fields.len());
    for (field, change, follows_rejects, binds_rejects) in &changes {
        assert!(fields.iter().any(|name| name == field), "{field}");
        let mut changed = first_receipt.clone();
        change(&mut changed);
        assert_ne!(&changed, first_receipt, "{field}");
        // Whatever the field, the next receipt names the unchanged receipt
        // by hash and does not follow the changed one.
        assert!(second_receipt.follows(&changed).is_err(), "{field}");
        assert_eq!(
            changed.follows(&deployed).is_err(),
            *follows_rejects,
            "{field}"
        );
        assert_eq!(
            changed
                .binds_call(&first_evidence, first.call.receipt())
                .is_err(),
            *binds_rejects,
            "{field}"
        );
    }
    let other_hash = hash();

    // The runtime rejects a call that names any receipt but the last one it
    // issued: an old one, a changed one, or none.
    let args = || put(9, 1);
    let stale = public_evidence(&artifact, &policy, &session, &environment, first_receipt);
    let err = production
        .call_authorized("put(bytes32,uint256)", args(), &session, &stale)
        .unwrap_err();
    assert!(err.to_string().starts_with("production runtime "), "{err}");
    let current = public_evidence(&artifact, &policy, &session, &environment, second_receipt);
    for other in [
        first_receipt.sha256().unwrap(),
        deployed.sha256().unwrap(),
        PRODUCTION_NO_RECEIPT_SHA256.to_owned(),
        other_hash.clone(),
    ] {
        let mut evidence = current.clone();
        evidence.previous_receipt_sha256 = other;
        let err = production
            .call_authorized("put(bytes32,uint256)", args(), &session, &evidence)
            .unwrap_err();
        assert_eq!(
            err.to_string(),
            "production runtime previous_receipt_sha256 mismatch"
        );
    }
    // A rejected call issued no receipt, and the right evidence still works.
    assert_eq!(production.last_receipt(), second_receipt);
    let third = production
        .call_authorized("put(bytes32,uint256)", args(), &session, &current)
        .unwrap();
    third.receipt.follows(second_receipt).unwrap();
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
        // A caller that does not hold the deployment's receipt guesses.
        let mut guessed = production.last_receipt().clone();
        guessed.freshness_epoch = guess;
        let evidence = public_evidence(&artifact, &policy, &session, &environment, &guessed);
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
        // The instance's `Debug` form shows the receipt it issued last,
        // which is public, and none of the runtime's state.
        let debug = format!("{production:?}");
        assert!(debug.contains("ContractInstance { .. }"), "{debug}");
        assert!(debug.contains("last_receipt: ProductionReceipt"));
    }
}

/// Every key of a JSON value, at any depth.
fn collect_keys(value: &serde_json::Value, keys: &mut BTreeSet<String>) {
    match value {
        serde_json::Value::Object(fields) => {
            for (key, field) in fields {
                keys.insert(key.clone());
                collect_keys(field, keys);
            }
        }
        serde_json::Value::Array(items) => {
            for item in items {
                collect_keys(item, keys);
            }
        }
        _ => {}
    }
}

/// A call returns its receipt and none of its private evidence. In this
/// build the result has no field for the call's whole trace, so this test
/// reads what the result does have.
#[test]
fn a_call_returns_its_receipt_and_no_private_evidence() {
    let artifact = single_access_map();
    let mut instance = ContractInstance::deploy(artifact).unwrap();
    let result = instance
        .call(
            "put(bytes32,uint256)",
            vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
        )
        .unwrap();

    // The receipt is what the observer sees: the call's storage events and
    // the theorems' view of it.
    assert_eq!(result.receipt(), &result.receipt);
    assert!(!result.receipt.physical_reads.has_no_event());
    assert!(!result.receipt.physical_writes.has_no_event());
    assert!(result.receipt.theorem_trace.public_outcome.is_some());

    let receipt = serde_json::to_value(&result.receipt).unwrap();
    for key in receipt.as_object().unwrap().keys() {
        assert!(
            uo_core::PUBLIC_RECEIPT_FIELDS.contains(&key.as_str()),
            "{key}"
        );
    }
    // No field of the private evidence, and no part of a hidden certificate
    // or a kernel witness, appears in it at any depth.
    let mut keys = BTreeSet::new();
    collect_keys(&receipt, &mut keys);
    for field in uo_core::PRIVATE_EVIDENCE_FIELDS {
        assert!(!keys.contains(*field), "{field}");
    }
    for field in [
        "oram_leaf_schedule",
        "oram_position_map_before",
        "oram_position_map_after",
        "oram_leaf_state_transitions",
        "hidden_certificate",
        "kernel_witness",
        "access_counter",
        "leaves",
    ] {
        assert!(!keys.contains(field), "{field}");
    }
    // Nor does the result's `Debug` form show any of it.
    let debug = format!("{result:?}");
    for field in uo_core::PRIVATE_EVIDENCE_FIELDS {
        assert!(!debug.contains(field), "{field}");
    }
}

/// A production call records no position-map witness: it decodes no map for
/// one and keeps none, and it builds no proof object, since those carry the
/// position maps. It still runs every check of its evidence that needs no
/// position map, and a call that fails one returns an error. This test runs
/// calls of a contract with a map of each Path ORAM scheme, all through
/// confidential entrypoints: calls that touch one map, the other and both,
/// an abort, reads that hit and miss, and a refused call. Each returns what
/// the contract computes.
#[test]
fn production_calls_run_without_a_position_map_witness() {
    let artifact = two_scheme_token();
    let mut instance = ContractInstance::deploy(artifact).unwrap();
    let owner = Value::Address([0xA1; 20]);
    let spender = Value::Address([0xB2; 20]);
    let to = Value::Address([0xC3; 20]);
    let stranger = Value::Address([0xEE; 20]);
    // (entrypoint, arguments, aborts, the value it returns)
    let calls: Vec<(&str, Vec<Value>, bool, Option<Value>)> = vec![
        // The tree alone: an insert.
        (
            "mint(address,uint256)",
            vec![owner.clone(), Value::uint(10)],
            false,
            None,
        ),
        // The local scheme's map alone.
        (
            "approve(address,address,uint256)",
            vec![owner.clone(), spender.clone(), Value::uint(5)],
            false,
            None,
        ),
        // The tree: an update and an insert.
        (
            "transfer(address,address,uint256)",
            vec![owner.clone(), to.clone(), Value::uint(3)],
            false,
            Some(Value::uint(1)),
        ),
        // More than the owner has: the call aborts and changes nothing.
        (
            "transfer(address,address,uint256)",
            vec![owner.clone(), to.clone(), Value::uint(100)],
            true,
            None,
        ),
        // Both maps.
        (
            "transferFrom(address,address,address,uint256)",
            vec![owner.clone(), spender.clone(), to.clone(), Value::uint(2)],
            false,
            Some(Value::uint(1)),
        ),
        // Reads that hit, and one that misses.
        (
            "balanceOf(address)",
            vec![owner.clone()],
            false,
            Some(Value::uint(5)),
        ),
        (
            "balanceOf(address)",
            vec![to.clone()],
            false,
            Some(Value::uint(5)),
        ),
        (
            "allowanceOf(address,address)",
            vec![owner.clone(), spender.clone()],
            false,
            Some(Value::uint(3)),
        ),
        (
            "balanceOf(address)",
            vec![stranger],
            false,
            Some(Value::uint(0)),
        ),
        // A write of zero, which deletes the key, and a read of it.
        (
            "approve(address,address,uint256)",
            vec![owner.clone(), spender.clone(), Value::uint(0)],
            false,
            None,
        ),
        (
            "allowanceOf(address,address)",
            vec![owner.clone(), spender.clone()],
            false,
            Some(Value::uint(0)),
        ),
    ];
    for (index, (entrypoint, args, aborts, returns)) in calls.into_iter().enumerate() {
        let result = instance.call(entrypoint, args).unwrap();
        assert_eq!(result.aborted, aborts, "call {index}, {entrypoint}");
        assert_eq!(result.return_value, returns, "call {index}, {entrypoint}");
        // The call ran its checks: its receipt carries the theorems' view
        // of it, and its storage events.
        assert!(result.receipt.theorem_trace.public_outcome.is_some());
        assert!(!result.receipt.physical_reads.has_no_event());
        assert!(!result.receipt.physical_writes.has_no_event());
    }

    // A call that is refused before it runs changes nothing.
    assert!(instance
        .call("mint(address,uint256)", vec![owner.clone()])
        .is_err());
    let read = instance.call("balanceOf(address)", vec![owner]).unwrap();
    assert_eq!(read.return_value, Some(Value::uint(5)));
}

/// A second session, with another key and another id.
fn other_session() -> ReturnChannelSession {
    ReturnChannelSession::new(
        [9u8; 32],
        ReturnChannelPublicBinding {
            scheme: RETURN_CHANNEL_SCHEME.into(),
            session_id: "44".repeat(32),
            client_public_key_hash: "55".repeat(32),
            attestation_transcript_hash: "33".repeat(32),
        },
    )
    .unwrap()
}

/// A caller holding a session checks the tag of the receipt it holds, the
/// last one included, and makes no call. A receipt changed in any field is
/// rejected, the digest of the ciphertext after the call among them, which
/// nothing else the caller holds binds; so is a changed tag, and a tag under
/// another session. The deployment's receipt gets its tag on request.
#[test]
fn a_changed_last_receipt_is_rejected_by_its_tag() {
    let artifact = single_access_map();
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let mut production =
        ProductionContractInstance::deploy(artifact.clone(), policy.clone()).unwrap();
    let (deployed, deployed_tag) = production.authenticated_last_receipt(&session).unwrap();
    assert_eq!(&deployed, production.last_receipt());
    verify_production_receipt(&session, &deployed, &deployed_tag).unwrap();
    let evidence = public_evidence(&artifact, &policy, &session, &environment, &deployed);
    let result = production
        .call_authorized("put(bytes32,uint256)", put(7, 5), &session, &evidence)
        .unwrap();
    let (receipt, tag) = (&result.receipt, &result.receipt_tag);
    verify_production_receipt(&session, receipt, tag).unwrap();
    assert_eq!(
        production.authenticated_last_receipt(&session).unwrap(),
        (receipt.clone(), tag.clone())
    );

    // Every field of the last receipt is bound by its tag.
    let fields = serde_json::to_value(receipt).unwrap();
    let fields = fields.as_object().unwrap();
    assert_eq!(fields.len(), 10);
    for (field, value) in fields {
        let mut changed = serde_json::to_value(receipt).unwrap();
        changed[field] = match value {
            serde_json::Value::String(_) => serde_json::json!("5a".repeat(32)),
            serde_json::Value::Number(number) => serde_json::json!(number.as_u64().unwrap() + 1),
            other => panic!("{field}: {other}"),
        };
        let changed: ProductionReceipt = serde_json::from_value(changed).unwrap();
        assert_ne!(&changed, receipt, "{field}");
        assert!(
            verify_production_receipt(&session, &changed, tag).is_err(),
            "{field}"
        );
    }
    // A changed tag, and a tag that is not hex, are rejected.
    let mut flipped = tag.clone().into_bytes();
    flipped[0] = if flipped[0] == b'0' { b'1' } else { b'0' };
    let flipped = String::from_utf8(flipped).unwrap();
    assert!(verify_production_receipt(&session, receipt, &flipped).is_err());
    assert!(verify_production_receipt(&session, receipt, "not hex").is_err());
    // A tag is its session's: another session's check rejects it, and the
    // runtime gives the other session a tag of its own.
    let other = other_session();
    assert!(verify_production_receipt(&other, receipt, tag).is_err());
    let (_, other_tag) = production.authenticated_last_receipt(&other).unwrap();
    assert_ne!(&other_tag, tag);
    verify_production_receipt(&other, receipt, &other_tag).unwrap();
    assert!(verify_production_receipt(&session, receipt, &other_tag).is_err());
}
