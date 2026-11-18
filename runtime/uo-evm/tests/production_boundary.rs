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

/// Every file of `from`, copied into a new directory `to`.
fn copy_directory(from: &std::path::Path, to: &std::path::Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let target = to.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            copy_directory(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), target).unwrap();
        }
    }
}

/// A production deployment restarts from its files, in the build a
/// production runtime uses, with the master secret it sealed to its
/// platform: the restarted instance's last receipt is the one the
/// deployment issued last, its next receipt follows it, and the map holds
/// what was written before the restart. The restart is refused with an
/// attested generation the store is behind, with the secret on another
/// platform, and with a store whose records were changed after the last
/// receipt.
#[test]
fn a_production_deployment_restarts_from_its_files_on_its_platform() {
    use uo_evm::{PlatformSealingKey, SealedMasterSecret, StoreGeneration};
    use uo_store::{FileStorage, SharedStorage, SyncPolicy};
    let directory =
        std::env::temp_dir().join(format!("uo-production-restart-{}", std::process::id()));
    let changed = directory.with_extension("changed");
    let _ = std::fs::remove_dir_all(&directory);
    let _ = std::fs::remove_dir_all(&changed);
    let artifact = single_access_map();
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let platform = || PlatformSealingKey::from_platform([0x5A; 32]);
    let (mut production, sealed) = ProductionContractInstance::deploy_with_storage(
        artifact.clone(),
        policy.clone(),
        SharedStorage::new(FileStorage::create(&directory, SyncPolicy::Always).unwrap()),
        &platform(),
    )
    .unwrap();
    for (key, value) in [(1, 10), (2, 20)] {
        let evidence = public_evidence(
            &artifact,
            &policy,
            &session,
            &environment,
            production.last_receipt(),
        );
        let result = production
            .call_authorized("put(bytes32,uint256)", put(key, value), &session, &evidence)
            .unwrap();
        assert_eq!(result.generation, production.generation());
    }
    let last = production.last_receipt().clone();
    // The platform's counter holds the generation of the last result.
    let generation = production.generation();
    drop(production);
    let reopen = |directory: &std::path::Path| {
        SharedStorage::new(FileStorage::open(directory, SyncPolicy::Always).unwrap())
    };
    let restart = |storage: SharedStorage,
                   sealed: &SealedMasterSecret,
                   platform: &PlatformSealingKey,
                   attested_generation: u64| {
        ProductionContractInstance::restart(
            artifact.clone(),
            policy.clone(),
            storage,
            sealed,
            platform,
            attested_generation,
        )
    };

    // An attested generation the store is behind.
    let error = restart(reopen(&directory), &sealed, &platform(), generation + 1).unwrap_err();
    assert!(
        error.to_string().contains("behind the attested generation"),
        "{error}"
    );
    // The secret on another platform, or changed.
    let other = PlatformSealingKey::from_platform([0x5B; 32]);
    let error = restart(reopen(&directory), &sealed, &other, generation).unwrap_err();
    assert!(
        error.to_string().contains("does not open on this platform"),
        "{error}"
    );
    let mut flipped = sealed.clone();
    let first = u8::from_str_radix(&sealed.ciphertext[..2], 16).unwrap() ^ 1;
    flipped.ciphertext = format!("{first:02x}{}", &sealed.ciphertext[2..]);
    assert_ne!(flipped, sealed);
    assert!(restart(reopen(&directory), &flipped, &platform(), generation).is_err());
    // A store changed in one record after the last receipt, with the
    // metadata of the last commit kept: a copy of the files in which a byte
    // of a bucket's ciphertext is flipped.
    copy_directory(&directory, &changed);
    let storage = reopen(&changed);
    storage.with(|adapter| {
        let location = "records@bucket0";
        let mut record = adapter.record(location).unwrap().to_vec();
        record[40] ^= 1;
        adapter.write(location, &record).unwrap();
        let meta = adapter.meta().to_vec();
        adapter.commit(&meta).unwrap();
    });
    drop(storage);
    let error = restart(reopen(&changed), &sealed, &platform(), generation).unwrap_err();
    assert!(
        error.to_string().contains("ciphertext_store_after_sha256"),
        "{error}"
    );

    // The restart, and the chain goes on once the instance resumed: it
    // takes no call before.
    let (mut restarted, found) =
        restart(reopen(&directory), &sealed, &platform(), generation).unwrap();
    assert_eq!(found, StoreGeneration::Attested);
    assert_eq!(restarted.generation(), generation);
    assert_eq!(restarted.last_receipt(), &last);
    let evidence = public_evidence(
        &artifact,
        &policy,
        &session,
        &environment,
        restarted.last_receipt(),
    );
    let refused = restarted
        .call_authorized(
            "read(bytes32)",
            vec![Value::Bytes32([2; 32])],
            &session,
            &evidence,
        )
        .unwrap_err();
    assert!(refused.to_string().contains("has not resumed"), "{refused}");
    restarted.resume(generation).unwrap();
    assert_eq!(restarted.generation(), generation + 1);
    let evidence = public_evidence(
        &artifact,
        &policy,
        &session,
        &environment,
        restarted.last_receipt(),
    );
    let result = restarted
        .call_authorized(
            "read(bytes32)",
            vec![Value::Bytes32([2; 32])],
            &session,
            &evidence,
        )
        .unwrap();
    result.receipt.follows(&last).unwrap();
    assert_eq!(result.call.return_value, Some(Value::uint(20)));
    assert_eq!(result.generation, generation + 2);
    drop(restarted);
    std::fs::remove_dir_all(&directory).unwrap();
    std::fs::remove_dir_all(&changed).unwrap();
}

/// A committed call that aborts leaves the rollback counter where it was,
/// and advances the commit generation, which a restart compares with the
/// attested one. A `mint` commits, then two `transfer`s of more than the
/// owner has commit aborts. The files from before the first abort pass with
/// no later generation; the files of each state pass with their own; and the
/// files after an abort pass with the generation before it only as one past
/// it, while files two commits past it are refused.
#[test]
fn a_restart_refuses_the_files_from_before_a_committed_abort() {
    use uo_evm::{PlatformSealingKey, StoreGeneration};
    use uo_store::{FileStorage, SharedStorage, SyncPolicy};
    let directory =
        std::env::temp_dir().join(format!("uo-production-abort-{}", std::process::id()));
    let before_abort = directory.with_extension("before-abort");
    let after_abort = directory.with_extension("after-abort");
    for path in [&directory, &before_abort, &after_abort] {
        let _ = std::fs::remove_dir_all(path);
    }
    let artifact = two_scheme_token();
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let platform = || PlatformSealingKey::from_platform([0x5C; 32]);
    let (mut production, sealed) = ProductionContractInstance::deploy_with_storage(
        artifact.clone(),
        policy.clone(),
        SharedStorage::new(FileStorage::create(&directory, SyncPolicy::Always).unwrap()),
        &platform(),
    )
    .unwrap();
    let call = |production: &mut ProductionContractInstance, entrypoint: &str, args: Vec<Value>| {
        let evidence = public_evidence(
            &artifact,
            &policy,
            &session,
            &environment,
            production.last_receipt(),
        );
        let result = production
            .call_authorized(entrypoint, args, &session, &evidence)
            .unwrap();
        assert_eq!(result.generation, production.generation());
        result
    };
    let owner = Value::Address([0xA1; 20]);
    let to = Value::Address([0xC3; 20]);
    let too_much = vec![owner.clone(), to.clone(), Value::uint(100)];

    let deployed = production.generation();
    let minted = call(
        &mut production,
        "mint(address,uint256)",
        vec![owner.clone(), Value::uint(10)],
    );
    assert!(!minted.call.aborted);
    assert_eq!(minted.generation, deployed + 1);
    copy_directory(&directory, &before_abort);
    let aborted = call(
        &mut production,
        "transfer(address,address,uint256)",
        too_much.clone(),
    );
    assert!(aborted.call.aborted);
    // The abort is committed: the generation moves, and the rollback
    // counter, which a restart compared before, does not.
    assert_eq!(aborted.generation, minted.generation + 1);
    assert_eq!(
        aborted.receipt.rollback_counter,
        minted.receipt.rollback_counter
    );
    copy_directory(&directory, &after_abort);
    let again = call(
        &mut production,
        "transfer(address,address,uint256)",
        too_much,
    );
    assert!(again.call.aborted);
    assert_eq!(again.generation, aborted.generation + 1);
    drop(production);

    let restart = |files: &std::path::Path, attested_generation: u64| {
        ProductionContractInstance::restart(
            artifact.clone(),
            policy.clone(),
            SharedStorage::new(FileStorage::open(files, SyncPolicy::Always).unwrap()),
            &sealed,
            &platform(),
            attested_generation,
        )
    };
    // The files from before the abort, with the generation after it, or
    // a later one.
    for attested in [aborted.generation, again.generation] {
        let error = restart(&before_abort, attested).unwrap_err();
        assert!(
            error.to_string().contains("behind the attested generation"),
            "{error}"
        );
    }
    // The files of each state, with its generation: the restarted instance
    // has the state's last receipt.
    for (files, result) in [
        (&before_abort, &minted),
        (&after_abort, &aborted),
        (&directory, &again),
    ] {
        let (restarted, found) = restart(files, result.generation).unwrap();
        assert_eq!(found, StoreGeneration::Attested);
        assert_eq!(restarted.generation(), result.generation);
        assert_eq!(restarted.last_receipt(), &result.receipt);
    }
    // The converse: the files after the abort, with the generation before
    // it, hold a commit the counter has not reached, which a restart takes
    // only as one past it; files two commits past it are refused.
    let (restarted, found) = restart(&after_abort, minted.generation).unwrap();
    assert_eq!(found, StoreGeneration::OnePast);
    assert_eq!(restarted.generation(), aborted.generation);
    assert_eq!(restarted.last_receipt(), &aborted.receipt);
    drop(restarted);
    let error = restart(&directory, minted.generation).unwrap_err();
    assert!(error.to_string().contains("more than one past"), "{error}");
    for path in [&directory, &before_abort, &after_abort] {
        std::fs::remove_dir_all(path).unwrap();
    }
}

/// A call dropped after it ran leaves its keys at counts the next call needs
/// a reservation above, and the instance commits it, with no record, before
/// the call's error returns: one generation more, which the platform's
/// counter follows. The files from before that reservation are refused with
/// the generation after it. The files with it are taken, and their last
/// receipt is the one before the dropped call. The instance restarted from
/// them resumes, and its next call seals each key above the reservation the
/// dropped call's commit made, so no nonce of a record handed over before
/// the restart is used again.
#[test]
fn a_restart_refuses_the_files_from_before_a_dropped_calls_reservation() {
    use uo_evm::{PlatformSealingKey, StoreGeneration};
    use uo_store::{FileStorage, SharedStorage, SyncPolicy};
    let directory =
        std::env::temp_dir().join(format!("uo-production-dropped-{}", std::process::id()));
    let before_drop = directory.with_extension("before-drop");
    for path in [&directory, &before_drop] {
        let _ = std::fs::remove_dir_all(path);
    }
    let mut artifact = single_access_map();
    artifact
        .contract
        .manifest
        .entrypoints
        .get_mut("read(bytes32)")
        .unwrap()
        .max_commit_ops = 0;
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let platform = || PlatformSealingKey::from_platform([0x5D; 32]);
    let storage = SharedStorage::new(FileStorage::create(&directory, SyncPolicy::Always).unwrap());
    let (mut production, sealed) = ProductionContractInstance::deploy_with_storage(
        artifact.clone(),
        policy.clone(),
        storage.clone(),
        &platform(),
    )
    .unwrap();
    let evidence = |production: &ProductionContractInstance| {
        public_evidence(
            &artifact,
            &policy,
            &session,
            &environment,
            production.last_receipt(),
        )
    };
    let put_result = production
        .call_authorized(
            "put(bytes32,uint256)",
            put(1, 10),
            &session,
            &evidence(&production),
        )
        .unwrap();
    copy_directory(&directory, &before_drop);
    production
        .call_authorized(
            "read(bytes32)",
            vec![Value::Bytes32([1; 32])],
            &session,
            &evidence(&production),
        )
        .unwrap_err();
    // The reservation is a commit after the last receipt.
    let counter = production.generation();
    assert_eq!(counter, put_result.generation + 1);
    assert_eq!(production.last_receipt(), &put_result.receipt);
    let records = storage.with(|adapter| adapter.sealed_records_sha256());
    let reserved: Vec<(String, u64)> = ["records"]
        .into_iter()
        .map(|object| {
            (
                object.to_owned(),
                storage.with(|adapter| adapter.reserved_seals(object)),
            )
        })
        .collect();
    assert!(reserved.iter().all(|(_, below)| *below > 0));
    let held: Vec<u64> = storage.with(|adapter| adapter.seal_counts("records"));
    drop(production);
    drop(storage);

    let restart = |files: &std::path::Path, attested_generation: u64| {
        let storage = SharedStorage::new(FileStorage::open(files, SyncPolicy::Always).unwrap());
        ProductionContractInstance::restart(
            artifact.clone(),
            policy.clone(),
            storage.clone(),
            &sealed,
            &platform(),
            attested_generation,
        )
        .map(|(instance, found)| (instance, found, storage))
    };
    let error = restart(&before_drop, counter).unwrap_err();
    assert!(
        error.to_string().contains("behind the attested generation"),
        "{error}"
    );
    let (mut restarted, found, storage) = restart(&directory, counter).unwrap();
    assert_eq!(found, StoreGeneration::Attested);
    assert_eq!(restarted.last_receipt(), &put_result.receipt);
    assert_eq!(
        storage.with(|adapter| adapter.sealed_records_sha256()),
        records
    );
    restarted.resume(counter).unwrap();
    let result = restarted
        .call_authorized(
            "put(bytes32,uint256)",
            put(2, 20),
            &session,
            &evidence(&restarted),
        )
        .unwrap();
    result.receipt.follows(&put_result.receipt).unwrap();
    // Every record sealed after the restart carries a count at or above the
    // reservation the dropped call's commit made; the others are the ones
    // held before.
    for (object, below) in &reserved {
        let counts = storage.with(|adapter| adapter.seal_counts(object));
        assert!(counts.iter().any(|count| !held.contains(count)), "{object}");
        for count in counts {
            assert!(
                held.contains(&count) || count >= *below,
                "{object}: {count} below {below}"
            );
        }
    }
    drop(restarted);
    for path in [&directory, &before_drop] {
        std::fs::remove_dir_all(path).unwrap();
    }
}

/// What a production call meets when its store fails, for every failure a
/// file store can be made to meet (`StorageFault::ALL`), on each of the two
/// commits a call can make, in the build a production runtime uses. Two
/// calls return their receipts first. Then the store is made to fail at:
///
/// - the next call's commit. Its append's failure makes the call return an
///   error that says its outcome is unknown, and no receipt. A checkpoint
///   the commit runs fails after the commit is in the journal, and the call
///   returns its receipt.
/// - the commit of no record that a call dropped after it ran makes before
///   its error returns, which reserves what the next call can seal (a read
///   whose commit budget is zero). Its append's failure makes the error say
///   that the outcome is unknown. A checkpoint it runs fails after the
///   reservation is in the journal, and the read returns its own error.
///
/// In every case the store refuses every operation, so the instance refuses
/// the next call and to vouch for its last receipt. The platform's counter
/// followed the instance, and holds the generation of its last commit that
/// returned. The deployment restarts from its files with that generation
/// attested. The files hold it, or one past it when they hold a commit whose
/// append failed after a whole write, and the restart says which, so that
/// the counter catches up. Of the generations one below the files' and the
/// files' own, both are accepted; any other is refused. The restart's last
/// receipt resolves the call: the call's when its commit is in the files
/// whole, the one the caller held when it is not, and when the call was the
/// dropped read. The instance resumes once the counter caught up. Every
/// receipt a call returned is in the files, the map holds what those calls
/// wrote, and the deployment takes calls again, each result one generation
/// past the last.
#[test]
fn every_storage_failure_fails_closed_and_a_restart_resolves_the_call() {
    use uo_evm::{
        resolve_production_call_outcome, storage_failure, AppendFailure, PlatformSealingKey,
        ProductionCallOutcome, StorageFailure, StorageFault, StoreGeneration,
    };
    use uo_store::{FileStorage, SharedStorage, SyncPolicy};
    let policy = policy();
    let session = session();
    let environment = PublicEnvironment::default();
    let platform = || PlatformSealingKey::from_platform([0x5A; 32]);
    let read = |key: u8| vec![Value::Bytes32([key; 32])];
    let mut checked = 0;
    let cases = StorageFault::ALL
        .into_iter()
        .flat_map(|fault| [(fault, false), (fault, true)]);
    for (index, (fault, reservation)) in cases.enumerate() {
        let directory = std::env::temp_dir().join(format!(
            "uo-production-fault-{}-{index}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&directory);
        // A read with no commit budget is dropped after it ran, and its keys
        // move on in memory to the counts the last commit reserved; before
        // its error returns, the instance commits the reservation the next
        // call needs, and that is the commit the store fails.
        let mut artifact = single_access_map();
        if reservation {
            artifact
                .contract
                .manifest
                .entrypoints
                .get_mut("read(bytes32)")
                .unwrap()
                .max_commit_ops = 0;
        }
        let mut store = FileStorage::create(&directory, SyncPolicy::Always).unwrap();
        if let StorageFault::Checkpoint { .. } = fault {
            store = store.with_checkpoint_bytes(0);
        }
        let storage = SharedStorage::new(store);
        let (mut production, sealed) = ProductionContractInstance::deploy_with_storage(
            artifact.clone(),
            policy.clone(),
            storage.clone(),
            &platform(),
        )
        .unwrap();
        for (key, value) in [(1, 10), (2, 20)] {
            let evidence = public_evidence(
                &artifact,
                &policy,
                &session,
                &environment,
                production.last_receipt(),
            );
            production
                .call_authorized("put(bytes32,uint256)", put(key, value), &session, &evidence)
                .unwrap();
        }

        storage.inject_fault(fault).unwrap();
        let held = production.last_receipt().clone();
        let held_generation = production.generation();
        let evidence = public_evidence(&artifact, &policy, &session, &environment, &held);
        let result = if reservation {
            production.call_authorized("read(bytes32)", read(1), &session, &evidence)
        } else {
            production.call_authorized("put(bytes32,uint256)", put(3, 30), &session, &evidence)
        };
        // The generation of the instance's last commit, which the platform's
        // counter follows once the call returned, with a result or an error.
        let counter = production.generation();
        let returned = match fault {
            StorageFault::Append { .. } => {
                let error = result.unwrap_err();
                assert_eq!(
                    storage_failure(&error),
                    Some(StorageFailure::OutcomeUnknown),
                    "{fault:?} {reservation}: {error:#}"
                );
                let says = if reservation {
                    "did not commit"
                } else {
                    "outcome is unknown"
                };
                assert!(
                    error.to_string().contains(says),
                    "{fault:?} {reservation}: {error:#}"
                );
                assert_eq!(counter, held_generation, "{fault:?} {reservation}");
                held.clone()
            }
            StorageFault::Checkpoint { .. } if reservation => {
                // The read failed and did not commit; the reservation after
                // it did, and the checkpoint it ran failed.
                let error = result.unwrap_err();
                assert_eq!(storage_failure(&error), None, "{fault:?}: {error:#}");
                assert_eq!(counter, held_generation + 1, "{fault:?}");
                held.clone()
            }
            StorageFault::Checkpoint { .. } => {
                let result = result.unwrap();
                result.receipt.follows(&held).unwrap();
                assert_eq!(result.generation, held_generation + 1, "{fault:?}");
                assert_eq!(counter, result.generation, "{fault:?}");
                result.receipt
            }
        };
        assert!(storage.poisoned().is_some(), "{fault:?}");
        let next = public_evidence(
            &artifact,
            &policy,
            &session,
            &environment,
            production.last_receipt(),
        );
        let refused = production
            .call_authorized("put(bytes32,uint256)", put(4, 40), &session, &next)
            .unwrap_err();
        assert!(
            refused.to_string().contains("refuses every operation"),
            "{fault:?}: {refused:#}"
        );
        assert!(production.authenticated_last_receipt(&session).is_err());
        drop(production);
        drop(storage);

        // The first open cuts off an append that stopped part way.
        let opened = FileStorage::open(&directory, SyncPolicy::Always).unwrap();
        let stopped_part_way = matches!(
            fault,
            StorageFault::Append { failure, .. } if failure != AppendFailure::SyncFails
        );
        assert_eq!(
            opened.bytes_cut_on_open() > 0,
            stopped_part_way,
            "{fault:?}"
        );
        drop(opened);
        let reopen =
            || SharedStorage::new(FileStorage::open(&directory, SyncPolicy::Always).unwrap());
        let restart = |attested_generation: u64| {
            ProductionContractInstance::restart(
                artifact.clone(),
                policy.clone(),
                reopen(),
                &sealed,
                &platform(),
                attested_generation,
            )
        };
        let committed = fault.leaves_the_entry_whole() && !reservation;
        // A commit is in the files that the counter does not hold: the
        // failed append's, when it reached them whole.
        let unreleased =
            fault.leaves_the_entry_whole() && matches!(fault, StorageFault::Append { .. });
        let files_generation = counter + u64::from(unreleased);
        let accepted: Vec<u64> = [counter - 1, counter, counter + 1]
            .into_iter()
            .filter(|attested| restart(*attested).is_ok())
            .collect();
        assert_eq!(
            accepted,
            vec![files_generation - 1, files_generation],
            "{fault:?}"
        );
        let (mut restarted, found) = restart(counter).unwrap();
        let expected_found = if unreleased {
            StoreGeneration::OnePast
        } else {
            StoreGeneration::Attested
        };
        assert_eq!(found, expected_found, "{fault:?}");
        // The counter catches up with the restarted instance.
        assert_eq!(restarted.generation(), files_generation, "{fault:?}");
        let outcome =
            resolve_production_call_outcome(&held, &evidence, restarted.last_receipt()).unwrap();
        let expected = if committed {
            ProductionCallOutcome::Committed
        } else {
            ProductionCallOutcome::NotCommitted
        };
        assert_eq!(outcome, expected, "{fault:?} {reservation}");
        // The counter catches up, and the instance resumes.
        restarted.resume(files_generation).unwrap();
        // Every receipt a call returned is in the files.
        let last = restarted.last_receipt().clone();
        assert!(
            last == returned || last.follows(&returned).is_ok(),
            "{fault:?}"
        );
        // The map holds what the calls that committed wrote, and the
        // deployment takes calls again.
        if !reservation {
            for (key, value) in [(1, 10), (2, 20), (3, if committed { 30 } else { 0 })] {
                let evidence = public_evidence(
                    &artifact,
                    &policy,
                    &session,
                    &environment,
                    restarted.last_receipt(),
                );
                let result = restarted
                    .call_authorized("read(bytes32)", read(key), &session, &evidence)
                    .unwrap();
                assert_eq!(
                    result.call.return_value,
                    Some(Value::uint(value)),
                    "{fault:?}: key {key}"
                );
            }
        }
        let evidence = public_evidence(
            &artifact,
            &policy,
            &session,
            &environment,
            restarted.last_receipt(),
        );
        let previous = restarted.last_receipt().clone();
        let previous_generation = restarted.generation();
        let result = restarted
            .call_authorized("put(bytes32,uint256)", put(5, 50), &session, &evidence)
            .unwrap();
        result.receipt.follows(&previous).unwrap();
        assert_eq!(result.generation, previous_generation + 1, "{fault:?}");
        drop(restarted);
        std::fs::remove_dir_all(&directory).unwrap();
        checked += 1;
    }
    assert_eq!(checked, 2 * StorageFault::ALL.len());
}
