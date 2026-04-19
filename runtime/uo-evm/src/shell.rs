use crate::controller::CallRecorder;
use crate::runtime::kernel::PublicRuntimeKernel;
use crate::runtime::state::{ContractRuntime, PublicRuntimeShadowState};
use anyhow::{anyhow, bail, Result};
use std::collections::BTreeMap;
use tiny_keccak::{Hasher, Keccak};
use uo_allocator::AllocatorPlan;
use uo_core::ir::{BinaryOp, CompiledContract, CompiledFunction, Expr, Statement, UnaryOp};
use uo_core::{RuntimeKernelRefinementWitness, RuntimeKernelWitness, Value};

#[derive(Clone, Debug)]
pub(crate) struct PublicCallOutcome {
    pub runtime_kernel_witness: RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    pub aborted: bool,
    pub return_value: Option<Value>,
    pub opcode_trace: Vec<String>,
}

#[derive(Clone, Debug)]
struct PublicExecutionOutcome {
    aborted: bool,
    return_value: Option<Value>,
    opcode_trace: Vec<String>,
}

#[derive(Clone, Debug, Default)]
struct ExecState {
    env: BTreeMap<String, Value>,
    aborted: bool,
    returned: bool,
    return_value: Option<Value>,
}

pub(crate) fn run_public_entrypoint(
    runtime: &mut ContractRuntime,
    contract: &CompiledContract,
    function: &CompiledFunction,
    public_args: Vec<Value>,
    allocator: AllocatorPlan,
    public_object_ids: Vec<u32>,
    recorder: &mut CallRecorder,
) -> Result<PublicCallOutcome> {
    let mut kernel = PublicRuntimeKernel::begin(
        allocator,
        None,
        public_object_ids.clone(),
        Some(public_object_ids.clone()),
    )?;
    let mut shadow = runtime.prepare_public_shadow(&mut kernel, &public_object_ids)?;
    let execution = interpret_public_entrypoint(
        contract,
        function,
        public_args,
        &mut shadow,
        recorder,
        &mut kernel,
    )?;
    runtime.commit_public_shadow(&mut kernel, &mut shadow, execution.aborted, recorder)?;
    let (runtime_kernel_witness, runtime_kernel_refinement_witness) =
        kernel.finish(&function.signature)?;
    runtime.replace_with_cold_public_shadow(shadow);
    let mut runtime_kernel_refinement_witness = runtime_kernel_refinement_witness;
    runtime.finalize_runtime_kernel_refinement_witness(
        &mut runtime_kernel_refinement_witness,
        &public_object_ids,
        "after completing the call and returning to committed storage",
    )?;
    Ok(PublicCallOutcome {
        runtime_kernel_witness,
        runtime_kernel_refinement_witness,
        aborted: execution.aborted,
        return_value: execution.return_value,
        opcode_trace: execution.opcode_trace,
    })
}

fn interpret_public_entrypoint(
    contract: &CompiledContract,
    function: &CompiledFunction,
    public_args: Vec<Value>,
    objects: &mut PublicRuntimeShadowState,
    recorder: &mut CallRecorder,
    kernel: &mut PublicRuntimeKernel,
) -> Result<PublicExecutionOutcome> {
    debug_assert!(
        !function.confidential,
        "public shell must not execute confidential entrypoints"
    );
    let mut state = ExecState::default();
    for ((param_name, _), arg) in function.params.iter().zip(public_args.into_iter()) {
        store_env_value(&mut state, kernel, param_name, arg)?;
    }
    let mut opcode_trace = Vec::with_capacity(function.body.len().max(1));
    exec_block(
        contract,
        function,
        &function.body,
        objects,
        &mut state,
        &mut opcode_trace,
        recorder,
        kernel,
    )?;
    Ok(PublicExecutionOutcome {
        aborted: state.aborted,
        return_value: state.return_value.take(),
        opcode_trace,
    })
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
        "public shell must not execute confidential blocks"
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
        "public shell must not evaluate confidential expressions"
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
    #[test]
    fn shell_source_stays_public_only() {
        let source = include_str!("shell.rs")
            .split("#[cfg(test)]")
            .next()
            .expect("shell.rs should contain a test boundary marker");
        assert!(
            source.contains("use crate::runtime::kernel::PublicRuntimeKernel;"),
            "shell.rs should run through the public kernel facade"
        );
        assert!(
            source.contains("PublicRuntimeShadowState"),
            "shell.rs should manipulate only the public shadow wrapper"
        );
        for forbidden in [
            "ConfidentialCallInputs",
            "RuntimeKernelRefinementEventWitness",
            "RuntimeTrustedKernelBundle",
            "ConfidentialKernelSlotProgram",
            "use crate::runtime::kernel::RuntimeKernel;",
            "use crate::runtime::objects::RuntimeObject;",
        ] {
            assert!(
                !source.contains(forbidden),
                "shell.rs should not import confidential runtime surface `{forbidden}`"
            );
        }
    }
}
