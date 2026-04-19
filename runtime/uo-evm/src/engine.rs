use crate::controller::{output_shape_of, CallRecorder, PublicCallSummary};
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::state::ContractRuntime;
use crate::shell::run_public_entrypoint;
use crate::theorem::{build_theorem_trace, finalize_execution_trace, FinalizeExecutionTraceInput};
use anyhow::{anyhow, bail, Result};
use rand::rngs::OsRng;
use rand::RngCore;
use uo_allocator::AllocatorPlan;
use uo_core::{canonical_runtime_public_object_ids, CompiledArtifact, ExecutionTrace, Value};

#[derive(Debug)]
pub struct ContractInstance {
    artifact: CompiledArtifact,
    state: ContractRuntime,
    deploy_seed: u64,
}

impl Clone for ContractInstance {
    fn clone(&self) -> Self {
        Self {
            artifact: self.artifact.clone(),
            state: self.state.clone(),
            deploy_seed: self.deploy_seed,
        }
    }
}

#[cfg(feature = "diagnostics")]
#[derive(Clone, Debug)]
pub struct CallTelemetry {
    pub zero_writes: usize,
}

#[derive(Clone, Debug)]
pub struct CallResult {
    pub return_value: Option<Value>,
    pub aborted: bool,
    pub trace: ExecutionTrace,
}

#[cfg(feature = "diagnostics")]
#[derive(Clone, Debug)]
pub struct DiagnosticCallResult {
    pub call: CallResult,
    pub telemetry: CallTelemetry,
}

impl ContractInstance {
    pub fn deploy(artifact: CompiledArtifact) -> Result<Self> {
        let deploy_seed = OsRng.next_u64();
        Self::deploy_with_seed(artifact, deploy_seed)
    }

    pub fn deploy_with_seed(artifact: CompiledArtifact, deploy_seed: u64) -> Result<Self> {
        Ok(Self {
            state: ContractRuntime::deploy(&artifact.contract.state, deploy_seed)?,
            artifact,
            deploy_seed,
        })
    }

    pub fn call(&mut self, entrypoint: &str, args: Vec<Value>) -> Result<CallResult> {
        Ok(self.call_impl(entrypoint, args, None)?.0)
    }

    #[cfg(feature = "diagnostics")]
    pub fn call_with_path_oram_fresh_coins(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: PathOramFreshCoinPlan,
    ) -> Result<CallResult> {
        Ok(self.call_impl(entrypoint, args, Some(fresh_coins))?.0)
    }

    #[cfg(feature = "diagnostics")]
    pub fn call_with_diagnostics(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
    ) -> Result<DiagnosticCallResult> {
        let (call, zero_writes) = self.call_impl(entrypoint, args, None)?;
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
        let manifest_entry = self
            .artifact
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| anyhow!("manifest entry missing for {entrypoint}"))?
            .clone();
        let (public_call, confidential_args, public_args) = if function.confidential {
            let public_call = PublicCallSummary::from_manifest_entry(&manifest_entry, &args)?;
            (public_call, Some(args), None)
        } else {
            let public_call = PublicCallSummary::from_manifest_entry(&manifest_entry, &args)?;
            (public_call, None, Some(args))
        };
        let public_object_ids = canonical_runtime_public_object_ids(&self.artifact.contract.state);
        let confidential_entrypoint_plan = if function.confidential {
            Some(self.state.prepare_confidential_entrypoint(
                entrypoint,
                &manifest_entry,
                public_object_ids.clone(),
            )?)
        } else {
            None
        };
        self.state.ensure_cold(
            &public_object_ids,
            "before executing the next call from committed storage",
        )?;
        let runtime_state_before = self.state.witness_snapshot()?;
        let execution = (|| -> Result<_> {
            let mut recorder =
                CallRecorder::begin_with_input_len(entrypoint, public_call.entry_input_len);
            let (
                runtime_kernel_witness,
                runtime_kernel_refinement_witness,
                aborted,
                return_value,
                opcode_trace,
            ) = if function.confidential {
                let confidential_args = confidential_args
                    .expect("confidential entrypoint must carry confidential call args");
                let outcome = self.state.run_confidential_entrypoint(
                    confidential_entrypoint_plan
                        .clone()
                        .expect("confidential entrypoint must derive runtime plan"),
                    confidential_args,
                    fresh_coins,
                    &mut recorder,
                )?;
                (
                    outcome.runtime_kernel_witness,
                    outcome.runtime_kernel_refinement_witness,
                    outcome.aborted,
                    outcome.return_value,
                    outcome.opcode_trace,
                )
            } else {
                let public_args =
                    public_args.expect("public entrypoint must keep raw argument vector");
                let public_execution = run_public_entrypoint(
                    &mut self.state,
                    &self.artifact.contract,
                    &function,
                    public_args,
                    AllocatorPlan::from_manifest(&manifest_entry),
                    public_object_ids.clone(),
                    &mut recorder,
                )?;
                (
                    public_execution.runtime_kernel_witness,
                    public_execution.runtime_kernel_refinement_witness,
                    public_execution.aborted,
                    public_execution.return_value,
                    public_execution.opcode_trace,
                )
            };
            let mut gas_used = 0u64;
            gas_used += recorder.metrics().logical_reads as u64 * 3;
            gas_used += recorder.metrics().logical_writes as u64 * 5;
            gas_used += recorder.metrics().physical_writes as u64 * 17;
            let manifest_budget = manifest_entry.public_gas_budget;
            if function.confidential {
                gas_used = manifest_budget;
            }
            Ok((
                runtime_kernel_witness,
                runtime_kernel_refinement_witness,
                gas_used,
                recorder,
                aborted,
                return_value,
                opcode_trace,
            ))
        })();
        let (
            runtime_kernel_witness,
            mut runtime_kernel_refinement_witness,
            gas_used,
            recorder,
            aborted,
            return_value,
            opcode_trace,
        ) = match execution {
            Ok(result) => result,
            Err(err) => return Err(err),
        };
        self.state.finalize_runtime_kernel_refinement_witness(
            &mut runtime_kernel_refinement_witness,
            &public_object_ids,
            "after completing the call and returning to committed storage",
        )?;
        let runtime_state_after = self.state.witness_snapshot()?;
        let output_shape = output_shape_of(&manifest_entry, &return_value)?;
        let trace_bundle = build_theorem_trace(
            recorder,
            &manifest_entry,
            &self.artifact.contract.manifest.objects,
            public_call,
            output_shape,
            aborted,
            gas_used,
        )?;
        let zero_writes = trace_bundle.metrics.zero_writes;
        let trace = finalize_execution_trace(FinalizeExecutionTraceInput {
            artifact: &self.artifact,
            entrypoint: &function.signature,
            confidential: function.confidential,
            deploy_seed: self.deploy_seed,
            opcode_trace,
            gas_used,
            trace_bundle,
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            runtime_state_before,
            runtime_state_after,
        })?;
        Ok((
            CallResult {
                return_value,
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
    use crate::runtime::kernel::PublicRuntimeKernel;
    use crate::runtime::objects::RuntimeObject;
    use uo_allocator::AllocatorPlan;
    use uo_core::{canonical_runtime_public_object_ids, ContractMetadata, ProgramMode, Value};

    fn compile_bench(source: &str, metadata: &str, mode: ProgramMode) -> uo_core::CompiledArtifact {
        let metadata: ContractMetadata = serde_yaml::from_str(metadata).unwrap();
        uo_solc::compile(source, &metadata, mode).unwrap()
    }

    fn b32(byte: u8) -> Value {
        Value::Bytes32([byte; 32])
    }

    fn assert_objects_are_cold(instance: &ContractInstance) {
        instance
            .state
            .ensure_cold(
                &canonical_runtime_public_object_ids(&instance.artifact.contract.state),
                "in engine test",
            )
            .unwrap();
    }

    #[test]
    fn engine_source_keeps_secret_object_helpers_behind_runtime_boundary() {
        let source = include_str!("engine.rs")
            .split("#[cfg(test)]")
            .next()
            .expect("engine.rs should contain a test boundary marker");
        assert!(
            source.contains("state: ContractRuntime"),
            "engine.rs should hold an opaque runtime wrapper rather than the raw committed state"
        );
        assert!(
            source.contains("use crate::shell::run_public_entrypoint;"),
            "engine.rs should delegate public execution to the explicit public shell module"
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
            source.contains("run_confidential_entrypoint("),
            "engine.rs should delegate confidential-kernel setup to ContractRuntime"
        );
        assert!(
            source.contains("prepare_confidential_entrypoint("),
            "engine.rs should delegate confidential manifest-to-kernel planning to ContractRuntime"
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
            .call("classify(uint256)", vec![Value::Uint(1)])
            .unwrap();

        instance
            .state
            .objects_for_test()
            .values()
            .find(|object| matches!(object, RuntimeObject::UoCell(_)))
            .expect("expected one UO cell object");
        assert_objects_are_cold(&instance);

        let peek = instance.call("peek()", vec![]).unwrap();
        assert_eq!(peek.return_value, Some(Value::Uint(1)));
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
            .call("classify(uint256)", vec![Value::Uint(1)])
            .unwrap();

        let (cell_id, hot_cell) = {
            let (&cell_id, _) = instance
                .state
                .objects_for_test()
                .iter()
                .find(|(_, object)| matches!(object, RuntimeObject::UoCell(_)))
                .expect("expected one UO cell object");
            let mut kernel = PublicRuntimeKernel::begin(
                AllocatorPlan {
                    arena_bytes: 4096,
                    max_stack_words: 64,
                    scratch_bytes: 1024,
                    max_kernel_ops: 16,
                },
                None,
                vec![],
                Some(vec![]),
            )
            .unwrap();
            let mut shadow = instance
                .state
                .shadow_load_for_test(&mut kernel, &[cell_id])
                .unwrap();
            let hot_cell = shadow.remove_object_for_test(cell_id).unwrap();
            (cell_id, hot_cell)
        };
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
            .call("put(bytes32,uint256)", vec![b32(7), Value::Uint(9)])
            .unwrap();

        let committed_map = instance
            .state
            .objects_for_test()
            .values()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(1));

        let read = instance.call("read(bytes32)", vec![b32(7)]).unwrap();
        assert_eq!(read.return_value, Some(Value::Uint(9)));
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
            .objects_for_test()
            .values()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(0));
    }
}
