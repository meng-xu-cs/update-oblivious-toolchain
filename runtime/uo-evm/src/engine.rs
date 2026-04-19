use crate::controller::{CallRecorder, PublicCallSummary};
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::kernel::PublicRuntimeKernel;
use crate::runtime::state::{CommittedRuntimeState, PublicRuntimeShadowState};
use crate::theorem::{build_theorem_trace, finalize_execution_trace, FinalizeExecutionTraceInput};
use anyhow::{anyhow, bail, Result};
use rand::rngs::OsRng;
use rand::RngCore;
use std::collections::{BTreeMap, BTreeSet};
use tiny_keccak::{Hasher, Keccak};
use uo_allocator::AllocatorPlan;
use uo_core::ir::{BinaryOp, CompiledContract, CompiledFunction, Expr, Statement, UnaryOp};
use uo_core::{
    canonical_runtime_public_object_ids, CompiledArtifact, ExecutionTrace,
    RuntimeKernelStepWitness, Value,
};

#[derive(Debug)]
pub struct ContractInstance {
    artifact: CompiledArtifact,
    state: CommittedRuntimeState,
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

#[derive(Clone, Debug, Default)]
struct ExecState {
    env: BTreeMap<String, Value>,
    aborted: bool,
    returned: bool,
    return_value: Option<Value>,
}

impl ContractInstance {
    pub fn deploy(artifact: CompiledArtifact) -> Result<Self> {
        let deploy_seed = OsRng.next_u64();
        Self::deploy_with_seed(artifact, deploy_seed)
    }

    pub fn deploy_with_seed(artifact: CompiledArtifact, deploy_seed: u64) -> Result<Self> {
        Ok(Self {
            state: CommittedRuntimeState::deploy(&artifact.contract.state, deploy_seed)?,
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
        fresh_coins: &PathOramFreshCoinPlan,
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
        fresh_coins: Option<&PathOramFreshCoinPlan>,
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
        let public_call = PublicCallSummary::from_call(&function, &manifest_entry, &args);
        let mut allocator = AllocatorPlan::from_manifest(&manifest_entry);
        let manifest_expected_kernel_steps = if function.confidential {
            Some(
                manifest_entry
                    .kernel_steps
                    .iter()
                    .map(|step| RuntimeKernelStepWitness {
                        opcode: step.opcode,
                        object_id: step.object_id,
                    })
                    .collect::<Vec<_>>(),
            )
        } else {
            None
        };
        let confidential_slot_program = if function.confidential {
            let program = manifest_entry
                .confidential_slot_program
                .clone()
                .ok_or_else(|| anyhow!("manifest confidential_slot_program missing for {entrypoint}"))?;
            let expected_kernel_steps = program
                .expected_runtime_steps()
                .into_iter()
                .map(RuntimeKernelStepWitness::from)
                .collect::<Vec<_>>();
            if manifest_expected_kernel_steps.as_ref() != Some(&expected_kernel_steps) {
                bail!("manifest kernel step trace drifted from confidential slot program for {entrypoint}");
            }
            allocator.max_kernel_ops = expected_kernel_steps.len();
            Some((program, expected_kernel_steps))
        } else {
            None
        };
        let expected_kernel_steps = confidential_slot_program
            .as_ref()
            .map(|(_, expected_kernel_steps)| expected_kernel_steps.clone());
        if function.confidential {
            if manifest_entry.confidential_program.is_none() {
                bail!("manifest confidential_program missing for {entrypoint}");
            }
        }
        let public_object_ids = canonical_runtime_public_object_ids(&self.artifact.contract.state);
        self.state.ensure_cold(
            &public_object_ids,
            "before executing the next call from committed storage",
        )?;
        let runtime_state_before = self.state.witness_snapshot()?;
        let shadow_load_object_ids = if function.confidential {
            expected_kernel_steps
                .as_ref()
                .expect("confidential entrypoint must derive expected kernel steps")
                .iter()
                .filter_map(|step| step.object_id)
                .collect::<BTreeSet<_>>()
                .into_iter()
                .collect::<Vec<_>>()
        } else {
            public_object_ids.clone()
        };
        let execution = (|| -> Result<_> {
            let kernel = PublicRuntimeKernel::begin(
                allocator,
                expected_kernel_steps,
                public_object_ids.clone(),
                Some(public_object_ids.clone()),
            )?;
            let mut recorder =
                CallRecorder::begin_with_input_len(entrypoint, public_call.entry_input_len);
            let mut opcode_trace = Vec::new();
            let (runtime_kernel_witness, runtime_kernel_refinement_witness, aborted, return_value) =
                if function.confidential {
                    let (slot_program, _) = confidential_slot_program
                        .as_ref()
                        .expect("confidential entrypoint must carry slot program");
                    let outcome = self.state.run_confidential_call(
                        kernel,
                        slot_program,
                        &shadow_load_object_ids,
                        args,
                        fresh_coins,
                        &mut recorder,
                        &mut opcode_trace,
                    )?;
                    (
                        outcome.runtime_kernel_witness,
                        outcome.runtime_kernel_refinement_witness,
                        outcome.aborted,
                        outcome.return_value,
                    )
                } else {
                    let mut kernel = kernel;
                    let mut shadow = self
                        .state
                        .prepare_public_shadow(&mut kernel, &shadow_load_object_ids)?;
                    let mut state = ExecState::default();
                    for ((param_name, _), arg) in function.params.iter().zip(args.into_iter()) {
                        store_env_value(&mut state, &mut kernel, param_name, arg)?;
                    }
                    exec_block(
                        &self.artifact.contract,
                        &function,
                        &function.body,
                        &mut shadow,
                        &mut state,
                        &mut opcode_trace,
                        &mut recorder,
                        &mut kernel,
                    )?;
                    let aborted = state.aborted;
                    let return_value = state.return_value.take();
                    self.state.commit_public_shadow(
                        &mut kernel,
                        &mut shadow,
                        aborted,
                        &mut recorder,
                    )?;
                    let (runtime_kernel_witness, runtime_kernel_refinement_witness) =
                        kernel.finish(&function.signature)?;
                    self.state.replace_with_cold_public_shadow(shadow);
                    (
                        runtime_kernel_witness,
                        runtime_kernel_refinement_witness,
                        aborted,
                        return_value,
                    )
                };
            let mut gas_used = 0u64;
            gas_used += recorder.metrics().logical_reads as u64 * 3;
            gas_used += recorder.metrics().logical_writes as u64 * 5;
            gas_used += recorder.metrics().physical_writes as u64 * 17;
            let manifest_budget = manifest_entry.public_gas_budget;
            if function.confidential {
                if recorder.physical_write_count() > manifest_entry.max_commit_ops {
                    bail!(
                        "entrypoint {} exceeded manifest commit budget: {} > {}",
                        entrypoint,
                        recorder.physical_write_count(),
                        manifest_entry.max_commit_ops
                    );
                }
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
        let trace_bundle = build_theorem_trace(
            recorder,
            &function,
            &manifest_entry,
            &self.artifact.contract.manifest.objects,
            public_call,
            &return_value,
            aborted,
            gas_used,
        )?;
        let zero_writes = trace_bundle.metrics.zero_writes;
        let trace = finalize_execution_trace(FinalizeExecutionTraceInput {
            artifact: &self.artifact,
            function: &function,
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

fn exec_block(
    contract: &CompiledContract,
    function: &CompiledFunction,
    statements: &[Statement],
    objects: &mut PublicRuntimeShadowState,
    state: &mut ExecState,
    opcode_trace: &mut Vec<String>,
    recorder: &mut CallRecorder,
    kernel: &mut PublicRuntimeKernel,
) -> Result<()> {
    debug_assert!(
        !function.confidential,
        "public interpreter must not execute confidential entrypoints"
    );
    for statement in statements {
        if state.returned {
            break;
        }
        exec_statement(
            contract,
            function,
            statement,
            objects,
            state,
            opcode_trace,
            recorder,
            kernel,
        )?;
    }
    Ok(())
}

fn exec_statement(
    contract: &CompiledContract,
    function: &CompiledFunction,
    statement: &Statement,
    objects: &mut PublicRuntimeShadowState,
    state: &mut ExecState,
    opcode_trace: &mut Vec<String>,
    recorder: &mut CallRecorder,
    kernel: &mut PublicRuntimeKernel,
) -> Result<()> {
    opcode_trace.push(statement_name(statement).into());
    match statement {
        Statement::Declare { name, value, .. } => {
            let value = eval_expr(contract, function, value, objects, state, recorder, kernel)?;
            store_env_value(state, kernel, name, value)?;
        }
        Statement::Assign { name, value } => {
            let value = eval_expr(contract, function, value, objects, state, recorder, kernel)?;
            store_env_value(state, kernel, name, value)?;
        }
        Statement::Require { cond } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder, kernel)?
                .as_bool()
                .ok_or_else(|| anyhow!("require condition must be boolean"))?;
            if !cond {
                state.aborted = true;
                state.returned = true;
            }
        }
        Statement::AbortIf { cond } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder, kernel)?
                .as_bool()
                .ok_or_else(|| anyhow!("abort condition must be boolean"))?;
            if cond {
                state.aborted = true;
            }
        }
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder, kernel)?
                .as_bool()
                .ok_or_else(|| anyhow!("if condition must be boolean"))?;
            if cond {
                exec_block(
                    contract,
                    function,
                    then_body,
                    objects,
                    state,
                    opcode_trace,
                    recorder,
                    kernel,
                )?;
            } else {
                exec_block(
                    contract,
                    function,
                    else_body,
                    objects,
                    state,
                    opcode_trace,
                    recorder,
                    kernel,
                )?;
            }
        }
        Statement::For {
            index_var,
            start,
            end,
            body,
            ..
        } => {
            let start = eval_expr(contract, function, start, objects, state, recorder, kernel)?
                .as_uint()
                .ok_or_else(|| anyhow!("for loop start must be uint"))?;
            let end = eval_expr(contract, function, end, objects, state, recorder, kernel)?
                .as_uint()
                .ok_or_else(|| anyhow!("for loop end must be uint"))?;
            for index in start..end {
                if state.returned {
                    break;
                }
                store_env_value(state, kernel, index_var, Value::uint(index))?;
                exec_block(
                    contract,
                    function,
                    body,
                    objects,
                    state,
                    opcode_trace,
                    recorder,
                    kernel,
                )?;
            }
        }
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => {
            let value = eval_expr(contract, function, value, objects, state, recorder, kernel)?;
            let predicate = predicate
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder, kernel))
                .transpose()?
                .map(|value| {
                    value
                        .as_bool()
                        .ok_or_else(|| anyhow!("cell predicate must be boolean"))
                })
                .transpose()?;
            kernel.cell_set(objects, recorder, *object_id, value, predicate)?;
        }
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => {
            let index = eval_expr(contract, function, index, objects, state, recorder, kernel)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            let value = eval_expr(contract, function, value, objects, state, recorder, kernel)?;
            let predicate = predicate
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder, kernel))
                .transpose()?
                .map(|value| {
                    value
                        .as_bool()
                        .ok_or_else(|| anyhow!("array predicate must be boolean"))
                })
                .transpose()?;
            kernel.array_set(objects, recorder, *object_id, index, value, predicate)?;
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            let key = eval_expr(contract, function, key, objects, state, recorder, kernel)?;
            let value = eval_expr(contract, function, value, objects, state, recorder, kernel)?;
            let predicate = predicate
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder, kernel))
                .transpose()?
                .map(|value| {
                    value
                        .as_bool()
                        .ok_or_else(|| anyhow!("map predicate must be boolean"))
                })
                .transpose()?;
            kernel.map_put(objects, recorder, *object_id, key, value, predicate)?;
        }
        Statement::Return { value } => {
            state.return_value = value
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder, kernel))
                .transpose()?;
            state.returned = true;
        }
    }
    Ok(())
}

fn eval_expr(
    contract: &CompiledContract,
    function: &CompiledFunction,
    expr: &Expr,
    objects: &mut PublicRuntimeShadowState,
    state: &mut ExecState,
    recorder: &mut CallRecorder,
    kernel: &mut PublicRuntimeKernel,
) -> Result<Value> {
    debug_assert!(
        !function.confidential,
        "public interpreter must not evaluate confidential expressions"
    );
    match expr {
        Expr::Literal(value) => Ok(value.clone()),
        Expr::Var(name) => state
            .env
            .get(name)
            .cloned()
            .ok_or_else(|| anyhow!("unknown variable {name}")),
        Expr::Unary { op, expr } => {
            let value = eval_expr(contract, function, expr, objects, state, recorder, kernel)?;
            match op {
                UnaryOp::Not => Ok(Value::Bool(
                    !value
                        .as_bool()
                        .ok_or_else(|| anyhow!("logical not expects bool"))?,
                )),
                UnaryOp::Neg => Ok(Value::Uint(
                    0u128.wrapping_sub(
                        value
                            .as_uint()
                            .ok_or_else(|| anyhow!("negation expects uint"))?,
                    ),
                )),
            }
        }
        Expr::Binary { op, lhs, rhs } => {
            let lhs = eval_expr(contract, function, lhs, objects, state, recorder, kernel)?;
            let rhs = eval_expr(contract, function, rhs, objects, state, recorder, kernel)?;
            eval_binary(op, lhs, rhs)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder, kernel)?
                .as_bool()
                .ok_or_else(|| anyhow!("select condition must be boolean"))?;
            if cond {
                eval_expr(
                    contract, function, when_true, objects, state, recorder, kernel,
                )
            } else {
                eval_expr(
                    contract, function, when_false, objects, state, recorder, kernel,
                )
            }
        }
        Expr::CellGet { object_id } => kernel.cell_get(objects, recorder, *object_id),
        Expr::ArrayGet { object_id, index } => {
            let index = eval_expr(contract, function, index, objects, state, recorder, kernel)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            kernel.array_get(objects, recorder, *object_id, index)
        }
        Expr::MapGet { object_id, key } => {
            let key = eval_expr(contract, function, key, objects, state, recorder, kernel)?;
            kernel.map_get(objects, recorder, *object_id, &key)
        }
        Expr::StructField { base, field } => {
            let base = eval_expr(contract, function, base, objects, state, recorder, kernel)?;
            match &base {
                Value::Struct(fields) => fields
                    .iter()
                    .find_map(|(name, value)| {
                        if name == field {
                            Some(value.clone())
                        } else {
                            None
                        }
                    })
                    .ok_or_else(|| anyhow!("unknown struct field {field}")),
                _ => bail!("struct field access requires struct value"),
            }
        }
        Expr::ArrayIndex { base, index } => {
            let base = eval_expr(contract, function, base, objects, state, recorder, kernel)?;
            let index = eval_expr(contract, function, index, objects, state, recorder, kernel)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            match &base {
                Value::Array(values) => values
                    .get(index)
                    .cloned()
                    .ok_or_else(|| anyhow!("array literal index out of bounds")),
                _ => bail!("array indexing requires an array value"),
            }
        }
        Expr::Keccak256 { parts } => {
            let mut hasher = Keccak::v256();
            for part in parts {
                let value = eval_expr(contract, function, part, objects, state, recorder, kernel)?;
                kernel.note_hash_bytes(value.canonical_len())?;
                value.visit_canonical_chunks(&mut |chunk| hasher.update(chunk));
                kernel.wipe_hash_scratch();
            }
            let mut out = [0u8; 32];
            hasher.finalize(&mut out);
            Ok(Value::Bytes32(out))
        }
    }
}

fn eval_binary(op: &BinaryOp, lhs: Value, rhs: Value) -> Result<Value> {
    match op {
        BinaryOp::Add => Ok(Value::Uint(lhs_uint(&lhs)?.wrapping_add(lhs_uint(&rhs)?))),
        BinaryOp::Sub => Ok(Value::Uint(lhs_uint(&lhs)?.wrapping_sub(lhs_uint(&rhs)?))),
        BinaryOp::Mul => Ok(Value::Uint(lhs_uint(&lhs)?.wrapping_mul(lhs_uint(&rhs)?))),
        BinaryOp::Div => {
            let divisor = lhs_uint(&rhs)?;
            Ok(Value::Uint(if divisor == 0 {
                0
            } else {
                lhs_uint(&lhs)? / divisor
            }))
        }
        BinaryOp::Mod => {
            let divisor = lhs_uint(&rhs)?;
            Ok(Value::Uint(if divisor == 0 {
                0
            } else {
                lhs_uint(&lhs)? % divisor
            }))
        }
        BinaryOp::BitAnd => Ok(Value::Uint(lhs_uint(&lhs)? & lhs_uint(&rhs)?)),
        BinaryOp::BitOr => Ok(Value::Uint(lhs_uint(&lhs)? | lhs_uint(&rhs)?)),
        BinaryOp::BitXor => Ok(Value::Uint(lhs_uint(&lhs)? ^ lhs_uint(&rhs)?)),
        BinaryOp::Eq => Ok(Value::Bool(lhs == rhs)),
        BinaryOp::Neq => Ok(Value::Bool(lhs != rhs)),
        BinaryOp::Lt => Ok(Value::Bool(lhs_uint(&lhs)? < lhs_uint(&rhs)?)),
        BinaryOp::Lte => Ok(Value::Bool(lhs_uint(&lhs)? <= lhs_uint(&rhs)?)),
        BinaryOp::Gt => Ok(Value::Bool(lhs_uint(&lhs)? > lhs_uint(&rhs)?)),
        BinaryOp::Gte => Ok(Value::Bool(lhs_uint(&lhs)? >= lhs_uint(&rhs)?)),
        BinaryOp::And => Ok(Value::Bool(lhs_bool(&lhs)? && lhs_bool(&rhs)?)),
        BinaryOp::Or => Ok(Value::Bool(lhs_bool(&lhs)? || lhs_bool(&rhs)?)),
    }
}

fn lhs_uint(value: &Value) -> Result<u128> {
    value
        .as_uint()
        .ok_or_else(|| anyhow!("expected uint-compatible value"))
}

fn lhs_bool(value: &Value) -> Result<bool> {
    value
        .as_bool()
        .ok_or_else(|| anyhow!("expected bool-compatible value"))
}

fn statement_name(statement: &Statement) -> &'static str {
    match statement {
        Statement::Declare { .. } => "declare",
        Statement::Assign { .. } => "assign",
        Statement::Require { .. } => "require",
        Statement::AbortIf { .. } => "abort_if",
        Statement::If { .. } => "if",
        Statement::For { .. } => "for",
        Statement::CellSet { .. } => "cell_set",
        Statement::ArraySet { .. } => "array_set",
        Statement::MapPut { .. } => "map_put",
        Statement::Return { .. } => "return",
    }
}

fn store_env_value(
    state: &mut ExecState,
    kernel: &mut PublicRuntimeKernel,
    name: &str,
    value: Value,
) -> Result<()> {
    state.env.insert(name.into(), value);
    kernel.enforce_stack_words(state.env.len())
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
            source.contains("state: CommittedRuntimeState"),
            "engine.rs should hold an opaque committed runtime state handle"
        );
        assert!(
            source.contains("objects: &mut PublicRuntimeShadowState"),
            "engine.rs public interpreter should run over the public shadow-state wrapper"
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
            source.contains("use crate::runtime::kernel::PublicRuntimeKernel;"),
            "engine.rs implementation should use the public kernel facade"
        );
        assert!(
            !source.contains("RuntimeKernelRefinementEventWitness"),
            "engine.rs implementation should not construct runtime phase witness events directly"
        );
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
        assert!(
            !source.contains("ExecutionTrace {"),
            "engine.rs implementation should not assemble ExecutionTrace directly"
        );
        for forbidden in [
            "clone_for_tx(",
            "commit(",
            "shadow_load_objects(",
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
