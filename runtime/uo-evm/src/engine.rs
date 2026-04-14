use crate::controller::CallRecorder;
use crate::objects::RuntimeObject;
use crate::theorem::{attach_theorem_metrics, build_theorem_trace};
use anyhow::{anyhow, bail, Result};
use rand::rngs::OsRng;
use rand::RngCore;
use std::collections::BTreeMap;
use tiny_keccak::{Hasher, Keccak};
use uo_allocator::AllocatorPlan;
use uo_core::ir::{BinaryOp, CompiledContract, CompiledFunction, Expr, Statement, UnaryOp};
use uo_core::{
    CompiledArtifact, ExecutionTrace, RuntimeOramAccessCounterWitness,
    RuntimeOramLeafScaffoldWitness, RuntimeOramObjectWitness, RuntimePathOramPositionMapWitness,
    Value,
};

#[derive(Clone, Debug)]
pub struct ContractInstance {
    artifact: CompiledArtifact,
    objects: BTreeMap<u32, RuntimeObject>,
    deploy_seed: u64,
}

#[derive(Clone, Debug)]
pub struct CallResult {
    pub return_value: Option<Value>,
    pub aborted: bool,
    pub trace: ExecutionTrace,
}

#[derive(Clone, Debug, Default)]
pub struct PathOramFreshCoinPlan {
    by_object: BTreeMap<u32, Vec<usize>>,
}

impl PathOramFreshCoinPlan {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn insert_object_coins(&mut self, object_id: u32, coins: Vec<usize>) -> Option<Vec<usize>> {
        self.by_object.insert(object_id, coins)
    }

    pub fn from_scaffold_and_values(
        scaffold: &[RuntimeOramLeafScaffoldWitness],
        values: &[usize],
    ) -> Result<Self> {
        if scaffold.len() != values.len() {
            bail!(
                "path-ORAM fresh-coin scaffold length {} does not match value length {}",
                scaffold.len(),
                values.len()
            );
        }
        let mut plan = Self::new();
        for (step, value) in scaffold.iter().zip(values.iter()) {
            plan.by_object
                .entry(step.object_id)
                .or_default()
                .push(*value);
        }
        Ok(plan)
    }
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
        let mut objects = BTreeMap::new();
        let mut master_seed = deploy_seed;
        for spec in &artifact.contract.state {
            objects.insert(
                spec.id,
                RuntimeObject::instantiate_with_seed(spec, master_seed)?,
            );
            master_seed = master_seed
                .wrapping_mul(0x9E37_79B9_7F4A_7C15)
                .wrapping_add(0xA5A5_A5A5_A5A5_A5A5);
        }
        Ok(Self {
            artifact,
            objects,
            deploy_seed,
        })
    }

    pub fn call(&mut self, entrypoint: &str, args: Vec<Value>) -> Result<CallResult> {
        self.call_impl(entrypoint, args, None)
    }

    pub fn call_with_path_oram_fresh_coins(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: &PathOramFreshCoinPlan,
    ) -> Result<CallResult> {
        self.call_impl(entrypoint, args, Some(fresh_coins))
    }

    fn call_impl(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: Option<&PathOramFreshCoinPlan>,
    ) -> Result<CallResult> {
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
        let call_args = args.clone();
        let manifest_entry = self
            .artifact
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| anyhow!("manifest entry missing for {entrypoint}"))?
            .clone();
        let _allocator = AllocatorPlan::for_entrypoint(
            manifest_entry.arena_bytes,
            manifest_entry.max_stack_words,
        );
        let committed = self.objects.clone();
        let runtime_oram_access_counters_before = runtime_path_oram_access_counters(&committed);
        let runtime_oram_position_map_before = runtime_path_oram_position_maps(&committed);
        let mut shadow = committed
            .iter()
            .map(|(id, object)| (*id, object.clone_for_tx()))
            .collect::<BTreeMap<_, _>>();
        if let Some(fresh_coins) = fresh_coins {
            for object in shadow.values_mut() {
                object.enable_injected_path_oram_leaf_coins();
            }
            for (object_id, coins) in &fresh_coins.by_object {
                let object = shadow.get_mut(object_id).ok_or_else(|| {
                    anyhow!(
                        "path-ORAM fresh-coin plan references unknown object {}",
                        object_id
                    )
                })?;
                object.install_path_oram_leaf_coins(coins.clone())?;
            }
        }
        let mut recorder = CallRecorder::begin(entrypoint, &call_args);
        let mut state = ExecState::default();
        for ((param_name, _), arg) in function.params.iter().zip(args.into_iter()) {
            state.env.insert(param_name.clone(), arg);
        }
        let mut opcode_trace = Vec::new();
        exec_block(
            &self.artifact.contract,
            &function,
            &function.body,
            &mut shadow,
            &mut state,
            &mut opcode_trace,
            &mut recorder,
        )?;
        if fresh_coins.is_some() {
            for object in shadow.values() {
                object.ensure_path_oram_leaf_coins_consumed()?;
            }
        }
        let mut next_objects = BTreeMap::new();
        for (id, object) in shadow {
            let old = committed
                .get(&id)
                .ok_or_else(|| anyhow!("missing committed object {id}"))?;
            let committed_object = object.commit(old, state.aborted, &mut recorder)?;
            next_objects.insert(id, committed_object);
        }
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
        self.objects = next_objects;
        let runtime_oram_access_counters_after = runtime_path_oram_access_counters(&self.objects);
        let runtime_oram_position_map_after = runtime_path_oram_position_maps(&self.objects);
        let return_value = if function.confidential && state.aborted {
            None
        } else {
            state.return_value
        };
        let trace_bundle = build_theorem_trace(
            recorder,
            &function,
            &manifest_entry,
            &self.artifact.contract.manifest.objects,
            &call_args,
            &return_value,
            state.aborted,
            gas_used,
        )?;
        let mut host_proxy_metrics = BTreeMap::new();
        host_proxy_metrics.insert(
            "bytes_read".into(),
            bytes_read(&trace_bundle.physical_reads) as f64,
        );
        host_proxy_metrics.insert(
            "backend_reads".into(),
            trace_bundle.physical_reads.len() as f64,
        );
        host_proxy_metrics.insert(
            "bytes_written".into(),
            bytes_written(&trace_bundle.physical_writes) as f64,
        );
        host_proxy_metrics.insert(
            "backend_writes".into(),
            trace_bundle.physical_writes.len() as f64,
        );
        host_proxy_metrics.insert(
            "zero_writes".into(),
            trace_bundle
                .physical_writes
                .iter()
                .filter(|event| event.new.iter().all(|byte| *byte == 0))
                .count() as f64,
        );
        host_proxy_metrics.insert(
            "update_only_fraction".into(),
            if trace_bundle.physical_writes.is_empty() {
                1.0
            } else {
                trace_bundle
                    .physical_writes
                    .iter()
                    .filter(|event| event.class == uo_core::WriteClass::Update)
                    .count() as f64
                    / trace_bundle.physical_writes.len() as f64
            },
        );
        let mut trace = ExecutionTrace {
            opcode_trace,
            logical_accesses: trace_bundle.logical_accesses,
            logical_writes: trace_bundle.logical_writes,
            physical_reads: trace_bundle.physical_reads,
            physical_writes: trace_bundle.physical_writes,
            host_proxy_metrics,
            gas_used,
            theorem_trace: trace_bundle.theorem_trace,
            runtime_seed: Some(self.deploy_seed),
            runtime_controller_certificate: Some(trace_bundle.controller_certificate),
            runtime_oram_objects: runtime_oram_objects(&self.artifact),
            runtime_oram_leaf_schedule: trace_bundle.oram_leaf_schedule,
            runtime_oram_access_counters_before,
            runtime_oram_access_counters_after,
            runtime_oram_position_map_before,
            runtime_oram_position_map_after,
            runtime_oram_leaf_state_transitions: trace_bundle.oram_leaf_state_transitions,
        };
        attach_theorem_metrics(&mut trace);
        trace.runtime_refinement_witness()?;
        Ok(CallResult {
            return_value,
            aborted: state.aborted,
            trace,
        })
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
    objects: &mut BTreeMap<u32, RuntimeObject>,
    state: &mut ExecState,
    opcode_trace: &mut Vec<String>,
    recorder: &mut CallRecorder,
) -> Result<()> {
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
        )?;
    }
    Ok(())
}

fn bytes_read(reads: &[uo_core::PhysicalReadEvent]) -> usize {
    reads.iter().map(|event| event.len).sum()
}

fn runtime_oram_objects(artifact: &CompiledArtifact) -> Vec<RuntimeOramObjectWitness> {
    artifact
        .contract
        .manifest
        .objects
        .iter()
        .filter_map(|object| {
            let oram = object.oram.as_ref()?;
            Some(RuntimeOramObjectWitness {
                object_id: object.id,
                object_name: object.name.clone(),
                scheme: oram.scheme.clone(),
                capacity: object.capacity.unwrap_or_default(),
                block_size: oram.block_size,
                bucket_size: oram.bucket_size,
                bucket_count: oram.bucket_count,
                blocks_per_bucket: oram.blocks_per_bucket,
                tree_height: oram.tree_height,
                stash_bound: oram.stash_bound,
                recursion_depth: oram.recursion_depth,
                metadata_pages: oram.metadata_pages,
                metadata_pages_per_access: oram.metadata_pages_per_access,
                buckets_per_access: oram.buckets_per_access,
                accesses_per_call: oram.accesses_per_call,
            })
        })
        .collect()
}

fn runtime_path_oram_position_maps(
    objects: &BTreeMap<u32, RuntimeObject>,
) -> Vec<RuntimePathOramPositionMapWitness> {
    objects
        .values()
        .filter_map(RuntimeObject::path_oram_position_map_witness)
        .collect()
}

fn runtime_path_oram_access_counters(
    objects: &BTreeMap<u32, RuntimeObject>,
) -> Vec<RuntimeOramAccessCounterWitness> {
    objects
        .values()
        .filter_map(RuntimeObject::path_oram_access_counter_witness)
        .collect()
}

fn exec_statement(
    contract: &CompiledContract,
    function: &CompiledFunction,
    statement: &Statement,
    objects: &mut BTreeMap<u32, RuntimeObject>,
    state: &mut ExecState,
    opcode_trace: &mut Vec<String>,
    recorder: &mut CallRecorder,
) -> Result<()> {
    opcode_trace.push(statement_name(statement).into());
    match statement {
        Statement::Declare { name, value, .. } => {
            let value = eval_expr(contract, function, value, objects, state, recorder)?;
            state.env.insert(name.clone(), value);
        }
        Statement::Assign { name, value } => {
            let value = eval_expr(contract, function, value, objects, state, recorder)?;
            state.env.insert(name.clone(), value);
        }
        Statement::Require { cond } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder)?
                .as_bool()
                .ok_or_else(|| anyhow!("require condition must be boolean"))?;
            if !cond {
                state.aborted = true;
                state.returned = true;
            }
        }
        Statement::AbortIf { cond } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder)?
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
            let cond = eval_expr(contract, function, cond, objects, state, recorder)?
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
            let start = eval_expr(contract, function, start, objects, state, recorder)?
                .as_uint()
                .ok_or_else(|| anyhow!("for loop start must be uint"))?;
            let end = eval_expr(contract, function, end, objects, state, recorder)?
                .as_uint()
                .ok_or_else(|| anyhow!("for loop end must be uint"))?;
            for index in start..end {
                if state.returned {
                    break;
                }
                state.env.insert(index_var.clone(), Value::uint(index));
                exec_block(
                    contract,
                    function,
                    body,
                    objects,
                    state,
                    opcode_trace,
                    recorder,
                )?;
            }
        }
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => {
            let value = eval_expr(contract, function, value, objects, state, recorder)?;
            let predicate = predicate
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder))
                .transpose()?
                .map(|value| {
                    value
                        .as_bool()
                        .ok_or_else(|| anyhow!("cell predicate must be boolean"))
                })
                .transpose()?;
            object_mut(objects, *object_id)?.set_cell(value, predicate, recorder)?;
        }
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => {
            let index = eval_expr(contract, function, index, objects, state, recorder)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            let value = eval_expr(contract, function, value, objects, state, recorder)?;
            let predicate = predicate
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder))
                .transpose()?
                .map(|value| {
                    value
                        .as_bool()
                        .ok_or_else(|| anyhow!("array predicate must be boolean"))
                })
                .transpose()?;
            object_mut(objects, *object_id)?.set_array(index, value, predicate, recorder)?;
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            let key = eval_expr(contract, function, key, objects, state, recorder)?;
            let value = eval_expr(contract, function, value, objects, state, recorder)?;
            let predicate = predicate
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder))
                .transpose()?
                .map(|value| {
                    value
                        .as_bool()
                        .ok_or_else(|| anyhow!("map predicate must be boolean"))
                })
                .transpose()?;
            object_mut(objects, *object_id)?.put_map(key, value, predicate, recorder)?;
        }
        Statement::Return { value } => {
            state.return_value = value
                .as_ref()
                .map(|expr| eval_expr(contract, function, expr, objects, state, recorder))
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
    objects: &mut BTreeMap<u32, RuntimeObject>,
    state: &mut ExecState,
    recorder: &mut CallRecorder,
) -> Result<Value> {
    match expr {
        Expr::Literal(value) => Ok(value.clone()),
        Expr::Var(name) => state
            .env
            .get(name)
            .cloned()
            .ok_or_else(|| anyhow!("unknown variable {name}")),
        Expr::Unary { op, expr } => {
            let value = eval_expr(contract, function, expr, objects, state, recorder)?;
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
            let lhs = eval_expr(contract, function, lhs, objects, state, recorder)?;
            let rhs = eval_expr(contract, function, rhs, objects, state, recorder)?;
            eval_binary(op, lhs, rhs)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            let cond = eval_expr(contract, function, cond, objects, state, recorder)?
                .as_bool()
                .ok_or_else(|| anyhow!("select condition must be boolean"))?;
            if cond {
                eval_expr(contract, function, when_true, objects, state, recorder)
            } else {
                eval_expr(contract, function, when_false, objects, state, recorder)
            }
        }
        Expr::CellGet { object_id } => object_mut(objects, *object_id)?.get_cell(recorder),
        Expr::ArrayGet { object_id, index } => {
            let index = eval_expr(contract, function, index, objects, state, recorder)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            object_mut(objects, *object_id)?.get_array(index, recorder)
        }
        Expr::MapGet { object_id, key } => {
            let key = eval_expr(contract, function, key, objects, state, recorder)?;
            object_mut(objects, *object_id)?.get_map(&key, recorder)
        }
        Expr::StructField { base, field } => {
            match eval_expr(contract, function, base, objects, state, recorder)? {
                Value::Struct(fields) => fields
                    .into_iter()
                    .find_map(|(name, value)| if name == *field { Some(value) } else { None })
                    .ok_or_else(|| anyhow!("unknown struct field {field}")),
                _ => bail!("struct field access requires struct value"),
            }
        }
        Expr::ArrayIndex { base, index } => {
            let base = eval_expr(contract, function, base, objects, state, recorder)?;
            let index = eval_expr(contract, function, index, objects, state, recorder)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            match base {
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
                let bytes = eval_expr(contract, function, part, objects, state, recorder)?
                    .canonical_bytes();
                hasher.update(&bytes);
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

fn object_mut(objects: &mut BTreeMap<u32, RuntimeObject>, id: u32) -> Result<&mut RuntimeObject> {
    objects
        .get_mut(&id)
        .ok_or_else(|| anyhow!("unknown object id {id}"))
}

fn bytes_written(events: &[uo_core::PhysicalWriteEvent]) -> usize {
    events.iter().map(|event| event.new.len()).sum()
}
