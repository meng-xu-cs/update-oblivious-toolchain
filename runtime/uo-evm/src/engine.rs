use crate::freshness::RuntimeFreshnessState;
use crate::return_channel::ReturnChannelSession;
use crate::runtime::{
    deploy_contract_runtime, run_contract_call, ContractRuntime, PathOramFreshCoinPlan,
};
use anyhow::{anyhow, bail, Result};
use uo_core::{CompiledArtifact, EncryptedReturnPayload, ExecutionTrace, Value};

#[derive(Debug)]
pub struct ContractInstance {
    artifact: CompiledArtifact,
    state: ContractRuntime,
    deploy_seed: u64,
    freshness: RuntimeFreshnessState,
}

#[cfg(feature = "diagnostics")]
#[derive(Clone, Debug)]
pub struct CallTelemetry {
    pub zero_writes: usize,
}

#[derive(Debug)]
pub struct CallResult {
    pub return_value: Option<Value>,
    pub encrypted_return: Option<EncryptedReturnPayload>,
    pub aborted: bool,
    pub trace: ExecutionTrace,
}

#[cfg(feature = "diagnostics")]
#[derive(Debug)]
pub struct DiagnosticCallResult {
    pub call: CallResult,
    pub telemetry: CallTelemetry,
}

impl ContractInstance {
    pub fn deploy(artifact: CompiledArtifact) -> Result<Self> {
        let freshness = RuntimeFreshnessState::from_os_rng();
        let deploy_seed = freshness.snapshot().epoch;
        Self::deploy_with_seed_internal(artifact, deploy_seed)
    }

    #[cfg(any(test, feature = "diagnostics"))]
    pub fn deploy_with_seed(artifact: CompiledArtifact, deploy_seed: u64) -> Result<Self> {
        Self::deploy_with_seed_internal(artifact, deploy_seed)
    }

    fn deploy_with_seed_internal(artifact: CompiledArtifact, deploy_seed: u64) -> Result<Self> {
        Ok(Self {
            state: deploy_contract_runtime(&artifact.contract.state, deploy_seed)?,
            artifact,
            deploy_seed,
            freshness: RuntimeFreshnessState::from_epoch(deploy_seed),
        })
    }

    pub fn call(&mut self, entrypoint: &str, args: Vec<Value>) -> Result<CallResult> {
        Ok(self.call_impl(entrypoint, args, None, None)?.0)
    }

    pub fn call_with_return_channel(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        session: &ReturnChannelSession,
    ) -> Result<CallResult> {
        Ok(self.call_impl(entrypoint, args, None, Some(session))?.0)
    }

    #[cfg(feature = "diagnostics")]
    pub fn call_with_path_oram_fresh_coins(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: PathOramFreshCoinPlan,
    ) -> Result<CallResult> {
        Ok(self.call_impl(entrypoint, args, Some(fresh_coins), None)?.0)
    }

    #[cfg(feature = "diagnostics")]
    pub fn call_with_diagnostics(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
    ) -> Result<DiagnosticCallResult> {
        let (call, zero_writes) = self.call_impl(entrypoint, args, None, None)?;
        Ok(DiagnosticCallResult {
            call,
            telemetry: CallTelemetry { zero_writes },
        })
    }

    fn call_impl(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        return_channel: Option<&ReturnChannelSession>,
    ) -> Result<(CallResult, usize)> {
        let function = self
            .artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .cloned()
            .ok_or_else(|| anyhow!("unknown entrypoint: {entrypoint}"))?;
        if function.params.len() != args.len() {
            bail!(
                "entrypoint {} expects {} args, got {}",
                function.signature,
                function.params.len(),
                args.len()
            );
        }
        let args = args.into_boxed_slice();
        let call_freshness = self.freshness.begin_call()?;
        let (return_value, encrypted_return, aborted, trace, zero_writes) = run_contract_call(
            &mut self.state,
            &self.artifact,
            &function,
            self.deploy_seed,
            call_freshness,
            args,
            fresh_coins,
            return_channel,
        )?;
        self.freshness.finish_call(aborted)?;
        Ok((
            CallResult {
                return_value,
                encrypted_return,
                aborted,
                trace,
            },
            zero_writes,
        ))
    }
}

pub fn run_artifact(artifact: &CompiledArtifact, entrypoint: &str) -> Result<ExecutionTrace> {
    let mut instance = ContractInstance::deploy(artifact.clone())?;
    Ok(instance.call(entrypoint, Vec::new())?.trace)
}

#[cfg(any(test, feature = "diagnostics"))]
pub fn run_artifact_with_seed(
    artifact: &CompiledArtifact,
    entrypoint: &str,
    deploy_seed: u64,
) -> Result<ExecutionTrace> {
    let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), deploy_seed)?;
    Ok(instance.call(entrypoint, Vec::new())?.trace)
}

#[cfg(test)]
mod tests {
    use super::ContractInstance;
    use crate::return_channel::{
        return_channel_aad_bytes, ReturnChannelSession, RETURN_CHANNEL_SCHEME,
    };
    use crate::runtime::ensure_contract_runtime_cold;
    use crate::runtime::objects::RuntimeObject;
    use chacha20poly1305::aead::AeadInPlace;
    use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce, Tag};
    use sha2::{Digest, Sha256};
    use std::fs;
    use std::path::PathBuf;
    use uo_core::{
        canonical_runtime_public_object_ids, ContractMetadata, EncryptedReturnPayload, ProgramMode,
        ReturnChannelPublicBinding, Value,
    };

    fn compile_bench(source: &str, metadata: &str, mode: ProgramMode) -> uo_core::CompiledArtifact {
        let metadata: ContractMetadata = serde_yaml::from_str(metadata).unwrap();
        uo_solc::compile(source, &metadata, mode).unwrap()
    }

    fn write_temp(name: &str, contents: &str) -> PathBuf {
        let path = PathBuf::from(format!(
            "/tmp/uo-evm-engine-test-{}-{}.sol",
            name,
            std::process::id()
        ));
        fs::write(&path, contents).unwrap();
        path
    }

    fn return_channel_session() -> ReturnChannelSession {
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

    fn decrypt_return_payload(
        artifact: &uo_core::CompiledArtifact,
        entrypoint: &str,
        public_args: &[String],
        payload: &EncryptedReturnPayload,
        session: &ReturnChannelSession,
    ) -> Vec<u8> {
        let aad = return_channel_aad_bytes(
            artifact,
            entrypoint,
            payload.plaintext_canonical_len,
            public_args,
            &payload.binding,
        )
        .unwrap();
        assert_eq!(payload.aad_hash, hex::encode(Sha256::digest(&aad)));
        let mut ciphertext = hex::decode(&payload.ciphertext).unwrap();
        let nonce = hex::decode(&payload.nonce).unwrap();
        let tag = hex::decode(&payload.tag).unwrap();
        let cipher = ChaCha20Poly1305::new_from_slice(session.key_for_test()).unwrap();
        cipher
            .decrypt_in_place_detached(
                Nonce::from_slice(&nonce),
                &aad,
                ciphertext.as_mut_slice(),
                Tag::from_slice(&tag),
            )
            .unwrap();
        ciphertext
    }

    fn b32(byte: u8) -> Value {
        Value::Bytes32([byte; 32])
    }

    fn assert_objects_are_cold(instance: &ContractInstance) {
        ensure_contract_runtime_cold(
            &instance.state,
            &canonical_runtime_public_object_ids(&instance.artifact.contract.state),
            "in engine test",
        )
        .unwrap();
    }

    #[test]
    fn public_require_after_write_rolls_back_committed_public_state() {
        let source = write_temp(
            "rollback-require",
            r#"
            contract C {
                uint256 private x;
                function setThenFail(uint256 v) public {
                    x = v;
                    require(false);
                }
                function read() public returns (uint256) {
                    return x;
                }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: C
entrypoints:
  setThenFail(uint256):
    confidential: false
    returns: forbidden
    status: public
  read():
    confidential: false
    returns: public
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
            ProgramMode::Raw,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 17).unwrap();

        let failed = instance
            .call("setThenFail(uint256)", vec![Value::uint(7)])
            .unwrap();
        assert!(failed.aborted);
        let transition = failed.trace.public_state_transition.as_ref().unwrap();
        assert!(transition.aborted);
        assert!(transition.commits_initial_on_abort());
        assert_eq!(
            transition.committed_public_state_hash,
            transition.initial_public_state_hash
        );
        assert_ne!(
            transition.candidate_public_state_hash,
            transition.initial_public_state_hash
        );

        let read = instance.call("read()", vec![]).unwrap();
        assert!(!read.aborted);
        assert_eq!(read.return_value, Some(Value::uint(0)));
    }

    #[test]
    fn encrypted_return_requires_session_and_keeps_plaintext_out_of_public_outcome() {
        let source = write_temp(
            "encrypted-return",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#,
            ProgramMode::Uo,
        );

        let mut missing_session = ContractInstance::deploy(artifact.clone()).unwrap();
        let err = missing_session
            .call("f(uint256)", vec![Value::uint(7)])
            .unwrap_err()
            .to_string();
        assert!(err.contains("requires a return channel session"));

        let session = return_channel_session();
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call_with_return_channel("f(uint256)", vec![Value::uint(7)], &session)
            .unwrap();
        let payload = result.encrypted_return.as_ref().unwrap();
        let public_outcome = result.trace.theorem_trace.public_outcome.as_ref().unwrap();

        assert_eq!(result.return_value, None);
        assert_eq!(public_outcome.return_payload, None);
        assert_eq!(
            public_outcome.return_policy,
            uo_core::ReturnPolicy::EncryptedToClient
        );
        assert_eq!(
            public_outcome.encrypted_return_payload.as_ref(),
            Some(payload)
        );
        assert_eq!(public_outcome.output_shape.return_length, payload.wire_len);
        assert_eq!(payload.plaintext_canonical_len, 32);
        assert_eq!(payload.wire_len, 12 + 32 + 16);
        assert_eq!(payload.nonce.len(), 24);
        assert_eq!(payload.tag.len(), 32);
        assert_eq!(payload.ciphertext.len(), 64);
        assert!(!public_outcome
            .declassifies
            .contains(&uo_core::DeclassificationKind::Return));

        let decrypted = decrypt_return_payload(
            &artifact,
            "f(uint256)",
            &public_outcome.public_args,
            payload,
            &session,
        );
        assert_eq!(
            decrypted,
            Value::uint(7).canonical_bytes_boxed().unwrap().into_vec()
        );

        let second = instance
            .call_with_return_channel("f(uint256)", vec![Value::uint(8)], &session)
            .unwrap();
        let second_payload = second.encrypted_return.as_ref().unwrap();
        assert_ne!(payload.nonce, second_payload.nonce);
        let second_decrypted = decrypt_return_payload(
            &artifact,
            "f(uint256)",
            second
                .trace
                .theorem_trace
                .public_outcome
                .as_ref()
                .unwrap()
                .public_args
                .as_ref(),
            second_payload,
            &session,
        );
        assert_eq!(
            second_decrypted,
            Value::uint(8).canonical_bytes_boxed().unwrap().into_vec()
        );
    }

    #[test]
    fn engine_source_keeps_secret_object_helpers_behind_runtime_boundary() {
        let source = include_str!("engine.rs")
            .split("#[cfg(test)]")
            .next()
            .expect("engine.rs should contain a test boundary marker");
        let seeded_deploy = source
            .find("pub fn deploy_with_seed")
            .expect("seeded deployment API should exist for diagnostics/tests");
        assert!(
            source[..seeded_deploy]
                .trim_end()
                .ends_with("#[cfg(any(test, feature = \"diagnostics\"))]"),
            "seeded deployment must stay out of the default production API"
        );
        let injected_fresh_coins = source
            .find("pub fn call_with_path_oram_fresh_coins")
            .expect("fresh-coin injection API should exist for diagnostics");
        assert!(
            source[..injected_fresh_coins]
                .trim_end()
                .ends_with("#[cfg(feature = \"diagnostics\")]"),
            "fresh-coin injection must stay out of the default production API"
        );
        assert!(
            source.contains("state: ContractRuntime"),
            "engine.rs should hold an opaque runtime wrapper rather than the raw committed state"
        );
        assert!(
            source.contains("run_contract_call"),
            "engine.rs should delegate call execution through the runtime-owned call bridge"
        );
        assert!(
            !source.contains("use crate::runtime::theorem::run_traced_call;"),
            "engine.rs should not import the theorem bridge module directly once runtime.rs owns that boundary"
        );
        assert!(
            !source.contains("use crate::runtime::shell::run_public_entrypoint;"),
            "engine.rs should not import the public shell directly once the runtime bridge owns dispatch"
        );
        assert!(
            !source.contains("ConfidentialCallInputs"),
            "engine.rs should not construct confidential runtime call wrappers directly"
        );
        assert!(
            !source.contains("PublicRuntimeShadowState"),
            "engine.rs should not manipulate the public shadow wrapper type directly once the shell is split out"
        );
        assert!(
            !source.contains("use crate::runtime::objects::RuntimeObject;"),
            "engine.rs implementation should not import RuntimeObject directly"
        );
        assert!(
            !source.contains("use crate::runtime::kernel::RuntimeKernel;"),
            "engine.rs implementation should not import the raw RuntimeKernel directly"
        );
        assert!(
            !source.contains("use crate::runtime::kernel::PublicRuntimeKernel;"),
            "engine.rs should not import the public kernel facade directly once the public and confidential setup paths are delegated"
        );
        assert!(
            source.contains("run_contract_call("),
            "engine.rs should delegate call execution through run_contract_call"
        );
        assert!(
            !source.contains("run_confidential_entrypoint("),
            "engine.rs should not dispatch confidential calls directly once the theorem bridge owns runtime branching"
        );
        assert!(
            !source.contains("run_public_entrypoint("),
            "engine.rs should not dispatch public calls directly once the theorem bridge owns runtime branching"
        );
        assert!(
            !source.contains("prepare_confidential_entrypoint("),
            "engine.rs should not stage confidential manifest-to-kernel planning outside ContractRuntime"
        );
        assert!(
            !source.contains("ConfidentialEntrypointPlan"),
            "engine.rs should not mention the confidential entrypoint plan directly"
        );
        assert!(
            !source.contains("RuntimeKernelRefinementEventWitness"),
            "engine.rs implementation should not construct runtime phase witness events directly"
        );
        for forbidden in [
            ".confidential_slot_program",
            "RuntimeKernelStepWitness",
            "expected_runtime_steps()",
            "max_hash_part_bytes",
            "kernel_steps",
            "max_commit_ops",
        ] {
            assert!(
                !source.contains(forbidden),
                "engine.rs should not derive confidential runtime plan detail `{forbidden}` directly"
            );
        }
        for forbidden_type in [
            "RuntimeControllerObserverCertificate",
            "RuntimePathOramHiddenCertificate",
            "RuntimeTrustedKernelBundle",
        ] {
            assert!(
                !source.contains(forbidden_type),
                "engine.rs implementation should not construct theorem-side certificate type `{forbidden_type}` directly"
            );
        }
        assert!(
            !source.contains("BTreeMap<u32, RuntimeObject>"),
            "engine.rs implementation should not own raw runtime object maps"
        );
        for forbidden in [
            "fn exec_block(",
            "fn exec_statement(",
            "fn eval_expr(",
            "fn eval_binary(",
            "fn store_env_value(",
        ] {
            assert!(
                !source.contains(forbidden),
                "engine.rs should not keep inline public-shell helper `{forbidden}` after the shell split"
            );
        }
        assert!(
            !source.contains("ExecutionTrace {"),
            "engine.rs implementation should not assemble ExecutionTrace directly"
        );
        for forbidden in [
            "prepare_public_shadow(",
            "commit_public_shadow(",
            "replace_with_cold_public_shadow(",
            "ensure_cold_call_boundary(",
            "build_theorem_trace(",
            "finalize_execution_trace(",
            "output_shape_of(",
            "clone_for_tx(",
            "commit(",
            "shadow_load_objects(",
            "shadow_load_public_objects(",
            "shadow_load_confidential_objects(",
            "enable_injected_path_oram_leaf_coins(",
            "install_path_oram_leaf_coins(",
            "ensure_path_oram_leaf_coins_consumed(",
            "path_oram_position_map_witness(",
            "path_oram_access_counter_witness(",
            "into_cold_committed(",
            "committed_cache_is_cold(",
            "cold_store_object(",
            "post_committed_cold_object(",
        ] {
            assert!(
                !source.contains(forbidden),
                "engine.rs should not call low-level runtime object helper `{forbidden}` directly"
            );
        }
    }

    #[test]
    fn committed_uo_cell_state_is_cold_between_calls() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 7).unwrap();
        instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap();

        instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoCell(_)))
            .expect("expected one UO cell object");
        assert_objects_are_cold(&instance);

        let peek = instance.call("peek()", vec![]).unwrap();
        assert_eq!(peek.return_value, Some(Value::uint(1)));
    }

    #[test]
    fn call_rejects_hot_committed_state_before_execution() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 11).unwrap();
        instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap();

        let (cell_id, mut hot_cell) = {
            let (cell_id, _) = instance
                .state
                .object_entries_for_test()
                .find(|(_, object)| matches!(object, RuntimeObject::UoCell(_)))
                .expect("expected one UO cell object");
            let hot_cell = instance
                .state
                .shadow_remove_object_for_test(cell_id)
                .unwrap();
            (cell_id, hot_cell)
        };
        hot_cell.force_committed_cache_hot_for_test().unwrap();
        instance.state.insert_object_for_test(cell_id, hot_cell);

        let err = instance.call("peek()", vec![]).unwrap_err();
        assert!(
            err.to_string().contains(&format!(
                "object {} was not cold before executing the next call from committed storage",
                cell_id
            )),
            "unexpected error: {err:?}"
        );
    }

    #[test]
    fn committed_path_oram_state_is_cold_between_calls() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 9).unwrap();
        instance
            .call("put(bytes32,uint256)", vec![b32(7), Value::uint(9)])
            .unwrap();

        let committed_map = instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(1));

        let read = instance.call("read(bytes32)", vec![b32(7)]).unwrap();
        assert_eq!(read.return_value, Some(Value::uint(9)));
    }

    #[test]
    fn deployed_path_oram_state_is_cold_before_first_call() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let instance = ContractInstance::deploy_with_seed(artifact, 13).unwrap();
        let committed_map = instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(0));
    }
}
