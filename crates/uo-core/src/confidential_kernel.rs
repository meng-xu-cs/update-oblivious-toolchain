use crate::ir::{BinaryOp, CompiledFunction, Expr, StateObject, Statement, UnaryOp};
use crate::types::{Type, Value};
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::mem::MaybeUninit;
use thiserror::Error;
use uo_precompiles::UoOpcode;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialKernelParam {
    pub name: String,
    pub ty: Type,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialKernelProgram {
    pub entrypoint_id: String,
    #[serde(default)]
    pub params: Vec<ConfidentialKernelParam>,
    #[serde(default)]
    pub return_type: Option<Type>,
    #[serde(default)]
    pub secret_args: Vec<usize>,
    #[serde(default)]
    pub body: Vec<ConfidentialKernelStatement>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialKernelSlotProgram {
    pub entrypoint_id: String,
    pub param_count: usize,
    #[serde(default)]
    pub return_type: Option<Type>,
    #[serde(default)]
    pub secret_args: Vec<usize>,
    pub slot_count: usize,
    #[serde(default)]
    pub body: Vec<ConfidentialKernelSlotStatement>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConfidentialKernelStatement {
    Declare {
        name: String,
        ty: Type,
        value: ConfidentialKernelExpr,
    },
    Assign {
        name: String,
        value: ConfidentialKernelExpr,
    },
    Require {
        cond: ConfidentialKernelExpr,
    },
    AbortIf {
        cond: ConfidentialKernelExpr,
    },
    CellSet {
        object_id: u32,
        value: ConfidentialKernelExpr,
        predicate: Option<ConfidentialKernelExpr>,
    },
    ArraySet {
        object_id: u32,
        index: ConfidentialKernelExpr,
        value: ConfidentialKernelExpr,
        predicate: Option<ConfidentialKernelExpr>,
    },
    MapPut {
        object_id: u32,
        key: ConfidentialKernelExpr,
        value: ConfidentialKernelExpr,
        predicate: Option<ConfidentialKernelExpr>,
    },
    Return {
        value: Option<ConfidentialKernelExpr>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConfidentialKernelSlotStatement {
    Declare {
        slot: usize,
        value: ConfidentialKernelSlotExpr,
    },
    Assign {
        slot: usize,
        value: ConfidentialKernelSlotExpr,
    },
    Require {
        cond: ConfidentialKernelSlotExpr,
    },
    AbortIf {
        cond: ConfidentialKernelSlotExpr,
    },
    CellSet {
        object_id: u32,
        value: ConfidentialKernelSlotExpr,
        predicate: Option<ConfidentialKernelSlotExpr>,
    },
    ArraySet {
        object_id: u32,
        index: ConfidentialKernelSlotExpr,
        value: ConfidentialKernelSlotExpr,
        predicate: Option<ConfidentialKernelSlotExpr>,
    },
    MapPut {
        object_id: u32,
        key: ConfidentialKernelSlotExpr,
        value: ConfidentialKernelSlotExpr,
        predicate: Option<ConfidentialKernelSlotExpr>,
    },
    Return {
        value: Option<ConfidentialKernelSlotExpr>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConfidentialKernelExpr {
    Literal {
        value: Value,
    },
    Var {
        name: String,
    },
    Unary {
        op: UnaryOp,
        expr: Box<ConfidentialKernelExpr>,
    },
    Binary {
        op: BinaryOp,
        lhs: Box<ConfidentialKernelExpr>,
        rhs: Box<ConfidentialKernelExpr>,
    },
    Select {
        cond: Box<ConfidentialKernelExpr>,
        when_true: Box<ConfidentialKernelPureExpr>,
        when_false: Box<ConfidentialKernelPureExpr>,
    },
    CellGet {
        object_id: u32,
    },
    ArrayGet {
        object_id: u32,
        index: Box<ConfidentialKernelExpr>,
    },
    MapGet {
        object_id: u32,
        key: Box<ConfidentialKernelExpr>,
    },
    Keccak256 {
        parts: Vec<ConfidentialKernelExpr>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConfidentialKernelSlotExpr {
    Literal {
        value: Value,
    },
    Slot {
        slot: usize,
    },
    Unary {
        op: UnaryOp,
        expr: Box<ConfidentialKernelSlotExpr>,
    },
    Binary {
        op: BinaryOp,
        lhs: Box<ConfidentialKernelSlotExpr>,
        rhs: Box<ConfidentialKernelSlotExpr>,
    },
    Select {
        cond: Box<ConfidentialKernelSlotExpr>,
        when_true: Box<ConfidentialKernelSlotPureExpr>,
        when_false: Box<ConfidentialKernelSlotPureExpr>,
    },
    CellGet {
        object_id: u32,
    },
    ArrayGet {
        object_id: u32,
        index: Box<ConfidentialKernelSlotExpr>,
    },
    MapGet {
        object_id: u32,
        key: Box<ConfidentialKernelSlotExpr>,
    },
    Keccak256 {
        parts: Vec<ConfidentialKernelSlotExpr>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConfidentialKernelPureExpr {
    Literal {
        value: Value,
    },
    Var {
        name: String,
    },
    Unary {
        op: UnaryOp,
        expr: Box<ConfidentialKernelPureExpr>,
    },
    Binary {
        op: BinaryOp,
        lhs: Box<ConfidentialKernelPureExpr>,
        rhs: Box<ConfidentialKernelPureExpr>,
    },
    Select {
        cond: Box<ConfidentialKernelPureExpr>,
        when_true: Box<ConfidentialKernelPureExpr>,
        when_false: Box<ConfidentialKernelPureExpr>,
    },
    Keccak256 {
        parts: Vec<ConfidentialKernelPureExpr>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConfidentialKernelSlotPureExpr {
    Literal {
        value: Value,
    },
    Slot {
        slot: usize,
    },
    Unary {
        op: UnaryOp,
        expr: Box<ConfidentialKernelSlotPureExpr>,
    },
    Binary {
        op: BinaryOp,
        lhs: Box<ConfidentialKernelSlotPureExpr>,
        rhs: Box<ConfidentialKernelSlotPureExpr>,
    },
    Select {
        cond: Box<ConfidentialKernelSlotPureExpr>,
        when_true: Box<ConfidentialKernelSlotPureExpr>,
        when_false: Box<ConfidentialKernelSlotPureExpr>,
    },
    Keccak256 {
        parts: Vec<ConfidentialKernelSlotPureExpr>,
    },
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialKernelStep {
    pub opcode: UoOpcode,
    #[serde(default)]
    pub object_id: Option<u32>,
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum ConfidentialKernelLoweringError {
    #[error("entrypoint '{entrypoint}' is not confidential")]
    EntrypointNotConfidential { entrypoint: String },
    #[error("confidential entrypoint {entrypoint} still contains control flow")]
    ConfidentialControlFlow {
        entrypoint: String,
        statement: String,
    },
    #[error("confidential entrypoint {entrypoint} contains a select arm with storage access")]
    SelectContainsKernelAccess { entrypoint: String },
    #[error(
        "confidential entrypoint {entrypoint} contains a select arm outside the branchless pure fragment"
    )]
    SelectArmOutsideBranchlessFragment { entrypoint: String },
    #[error(
        "confidential entrypoint {entrypoint} contains unsupported struct-field projection in the confidential fragment"
    )]
    ConfidentialStructField { entrypoint: String },
    #[error(
        "confidential entrypoint {entrypoint} contains unsupported array indexing in the confidential fragment"
    )]
    ConfidentialArrayIndex { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum ConfidentialKernelSlotLoweringError {
    #[error("slot-lowered confidential kernel program requires a valid confidential kernel program: {0}")]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error("confidential entrypoint {entrypoint} declares duplicate variable '{name}'")]
    DuplicateBinding { entrypoint: String, name: String },
    #[error("confidential entrypoint {entrypoint} refers to unknown variable '{name}'")]
    UnknownVariable { entrypoint: String, name: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum ConfidentialKernelHashShapeError {
    #[error("entrypoint {entrypoint} references unknown confidential variable '{name}'")]
    UnknownVariable { entrypoint: String, name: String },
    #[error("entrypoint {entrypoint} references unknown state object id {object_id}")]
    UnknownObjectId { entrypoint: String, object_id: u32 },
    #[error(
        "entrypoint {entrypoint} keccak select arms disagree on canonical length: {when_true} != {when_false}"
    )]
    SelectArmLengthMismatch {
        entrypoint: String,
        when_true: usize,
        when_false: usize,
    },
}

pub trait ConfidentialKernelSlotRuntime {
    fn note_statement(&mut self, _statement: &ConfidentialKernelSlotStatement) -> Result<()> {
        Ok(())
    }

    fn load_slot(&self, slot: usize) -> Result<Value>;

    fn store_slot(&mut self, slot: usize, value: Value) -> Result<()>;

    fn cell_get(&mut self, object_id: u32) -> Result<Value>;

    fn cell_set(&mut self, object_id: u32, value: Value, predicate: Option<bool>) -> Result<()>;

    fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value>;

    fn array_set(
        &mut self,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()>;

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<Value>;

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()>;

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value>;
}

pub trait ConfidentialKernelEffectRuntime {
    fn note_statement(&mut self, _statement: &ConfidentialKernelSlotStatement) -> Result<()> {
        Ok(())
    }

    fn note_live_slot_words(&mut self, _words: usize) -> Result<()> {
        Ok(())
    }

    fn cell_get(&mut self, object_id: u32) -> Result<Value>;

    fn cell_set(&mut self, object_id: u32, value: Value, predicate: Option<bool>) -> Result<()>;

    fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value>;

    fn array_set(
        &mut self,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()>;

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<Value>;

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()>;

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value>;
}

struct ConfidentialKernelSlotExecutor<'a, R> {
    runtime: &'a mut R,
    state: ConfidentialKernelSlotState,
}

impl<'a, R: ConfidentialKernelEffectRuntime> ConfidentialKernelSlotExecutor<'a, R> {
    fn new(runtime: &'a mut R, slot_count: usize) -> Self {
        Self {
            runtime,
            state: ConfidentialKernelSlotState::new(slot_count),
        }
    }

    fn store_call_inputs(
        &mut self,
        program: &ConfidentialKernelSlotProgram,
        call_inputs: ConfidentialCallInputs,
    ) -> Result<()> {
        let mut supplied_args = 0usize;
        for (slot, arg) in call_inputs.into_raw_args().enumerate() {
            supplied_args = slot + 1;
            if slot >= program.param_count {
                bail!(
                    "confidential slot program {} expected {} confidential arguments but runtime supplied {}",
                    program.entrypoint_id,
                    program.param_count,
                    supplied_args
                );
            }
            self.store_slot(slot, arg)?;
        }
        if supplied_args != program.param_count {
            bail!(
                "confidential slot program {} expected {} confidential arguments but runtime supplied {}",
                program.entrypoint_id,
                program.param_count,
                supplied_args
            );
        }
        Ok(())
    }
}

impl<R: ConfidentialKernelEffectRuntime> ConfidentialKernelSlotRuntime
    for ConfidentialKernelSlotExecutor<'_, R>
{
    fn note_statement(&mut self, statement: &ConfidentialKernelSlotStatement) -> Result<()> {
        self.runtime.note_statement(statement)
    }

    fn load_slot(&self, slot: usize) -> Result<Value> {
        self.state.load_slot(slot)
    }

    fn store_slot(&mut self, slot: usize, value: Value) -> Result<()> {
        self.state.store_slot(slot, value)?;
        self.runtime
            .note_live_slot_words(self.state.live_slot_words())?;
        Ok(())
    }

    fn cell_get(&mut self, object_id: u32) -> Result<Value> {
        self.runtime.cell_get(object_id)
    }

    fn cell_set(&mut self, object_id: u32, value: Value, predicate: Option<bool>) -> Result<()> {
        self.runtime.cell_set(object_id, value, predicate)
    }

    fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value> {
        self.runtime.array_get(object_id, index)
    }

    fn array_set(
        &mut self,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.runtime.array_set(object_id, index, value, predicate)
    }

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<Value> {
        self.runtime.map_get(object_id, key)
    }

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.runtime.map_put(object_id, key, value, predicate)
    }

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value> {
        self.runtime.keccak256(parts)
    }
}

struct FixedConfidentialValueBuffer {
    values: Box<[MaybeUninit<Value>]>,
    initialized: usize,
}

impl FixedConfidentialValueBuffer {
    fn new(len: usize) -> Self {
        Self {
            values: Box::<[Value]>::new_uninit_slice(len),
            initialized: 0,
        }
    }

    fn push(&mut self, value: Value) {
        assert!(
            self.initialized < self.values.len(),
            "fixed confidential value buffer overflow"
        );
        self.values[self.initialized].write(value);
        self.initialized += 1;
    }

    fn finish(mut self) -> Box<[Value]> {
        assert_eq!(
            self.initialized,
            self.values.len(),
            "fixed confidential value buffer underfilled"
        );
        let values = std::mem::take(&mut self.values);
        self.initialized = 0;
        let raw = Box::into_raw(values) as *mut [Value];
        unsafe { Box::from_raw(raw) }
    }
}

impl Drop for FixedConfidentialValueBuffer {
    fn drop(&mut self) {
        for value in &mut self.values[..self.initialized] {
            unsafe {
                value.assume_init_mut().wipe_secrets();
                value.assume_init_drop();
            }
        }
    }
}

fn collect_confidential_hash_parts(
    len: usize,
    parts: impl IntoIterator<Item = Result<Value>>,
) -> Result<Box<[Value]>> {
    let mut values = FixedConfidentialValueBuffer::new(len);
    for part in parts {
        values.push(part?);
    }
    Ok(values.finish())
}

#[derive(Debug)]
pub struct ConfidentialCallInputs {
    raw_args: Box<[Value]>,
}

impl ConfidentialCallInputs {
    pub fn from_raw_args(args: Box<[Value]>) -> Self {
        Self { raw_args: args }
    }

    pub fn into_raw_args(mut self) -> impl Iterator<Item = Value> {
        std::iter::IntoIterator::into_iter(std::mem::take(&mut self.raw_args))
    }
}

impl Drop for ConfidentialCallInputs {
    fn drop(&mut self) {
        for value in self.raw_args.iter_mut() {
            value.wipe_secrets();
        }
    }
}

#[derive(Debug)]
pub struct ConfidentialKernelSlotState {
    slots: Box<[Option<Value>]>,
    initialized_slots: usize,
}

impl ConfidentialKernelSlotState {
    pub fn new(slot_count: usize) -> Self {
        Self {
            slots: vec![None; slot_count].into_boxed_slice(),
            initialized_slots: 0,
        }
    }

    pub fn load_slot(&self, slot: usize) -> Result<Value> {
        self.slots
            .get(slot)
            .and_then(Option::as_ref)
            .cloned()
            .ok_or_else(|| anyhow!("unknown slot {slot}"))
    }

    pub fn store_slot(&mut self, slot: usize, value: Value) -> Result<()> {
        let cell = self
            .slots
            .get_mut(slot)
            .ok_or_else(|| anyhow!("unknown slot {slot}"))?;
        if cell.is_none() {
            self.initialized_slots += 1;
        }
        *cell = Some(value);
        Ok(())
    }

    pub fn live_slot_words(&self) -> usize {
        self.initialized_slots
    }
}

impl Drop for ConfidentialKernelSlotState {
    fn drop(&mut self) {
        for slot in &mut self.slots {
            if let Some(value) = slot.as_mut() {
                value.wipe_secrets();
            }
            *slot = None;
        }
        self.initialized_slots = 0;
    }
}

#[derive(Debug, Default, PartialEq, Eq)]
pub struct ConfidentialKernelExecutionOutcome {
    aborted: bool,
    return_value: Option<Value>,
}

impl ConfidentialKernelExecutionOutcome {
    pub fn new(aborted: bool, return_value: Option<Value>) -> Self {
        Self {
            aborted,
            return_value,
        }
    }

    pub fn aborted(&self) -> bool {
        self.aborted
    }

    pub fn return_value(&self) -> Option<&Value> {
        self.return_value.as_ref()
    }

    pub fn into_parts(self) -> (bool, Option<Value>) {
        (self.aborted, self.return_value)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct ConfidentialKernelInterpreterState {
    aborted: bool,
    returned: bool,
    return_value: Option<Value>,
}

pub fn execute_confidential_kernel_slot_program<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    program: &ConfidentialKernelSlotProgram,
) -> Result<ConfidentialKernelExecutionOutcome> {
    if !program.is_runtime_normal_form() {
        bail!(
            "confidential slot program {} is not in runtime normal form",
            program.entrypoint_id
        );
    }
    let mut state = ConfidentialKernelInterpreterState::default();
    execute_confidential_kernel_slot_block(runtime, &program.body, &mut state)?;
    Ok(ConfidentialKernelExecutionOutcome::new(
        state.aborted,
        state.return_value,
    ))
}

pub fn execute_confidential_kernel_slot_call<R: ConfidentialKernelEffectRuntime>(
    runtime: &mut R,
    program: &ConfidentialKernelSlotProgram,
    call_inputs: ConfidentialCallInputs,
) -> Result<ConfidentialKernelExecutionOutcome> {
    let mut executor = ConfidentialKernelSlotExecutor::new(runtime, program.slot_count);
    executor.store_call_inputs(program, call_inputs)?;
    execute_confidential_kernel_slot_program(&mut executor, program)
}

fn execute_confidential_kernel_slot_block<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    statements: &[ConfidentialKernelSlotStatement],
    state: &mut ConfidentialKernelInterpreterState,
) -> Result<()> {
    for statement in statements {
        if state.returned {
            break;
        }
        runtime.note_statement(statement)?;
        execute_confidential_kernel_slot_statement(runtime, statement, state)?;
    }
    Ok(())
}

fn execute_confidential_kernel_slot_statement<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    statement: &ConfidentialKernelSlotStatement,
    state: &mut ConfidentialKernelInterpreterState,
) -> Result<()> {
    match statement {
        ConfidentialKernelSlotStatement::Declare { slot, value }
        | ConfidentialKernelSlotStatement::Assign { slot, value } => {
            let value = eval_confidential_kernel_slot_expr(runtime, value)?;
            runtime.store_slot(*slot, value)?;
        }
        ConfidentialKernelSlotStatement::Require { .. } => {
            bail!("confidential slot program must be normalized before runtime execution");
        }
        ConfidentialKernelSlotStatement::AbortIf { cond } => {
            let cond = eval_confidential_kernel_slot_expr(runtime, cond)?
                .as_bool()
                .ok_or_else(|| anyhow!("abort condition must be boolean"))?;
            if cond {
                state.aborted = true;
            }
        }
        ConfidentialKernelSlotStatement::CellSet {
            object_id,
            value,
            predicate,
        } => {
            let value = eval_confidential_kernel_slot_expr(runtime, value)?;
            let predicate =
                eval_optional_confidential_kernel_predicate(runtime, predicate, "cell")?;
            runtime.cell_set(*object_id, value, predicate)?;
        }
        ConfidentialKernelSlotStatement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => {
            let index = eval_confidential_kernel_slot_expr(runtime, index)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            let value = eval_confidential_kernel_slot_expr(runtime, value)?;
            let predicate =
                eval_optional_confidential_kernel_predicate(runtime, predicate, "array")?;
            runtime.array_set(*object_id, index, value, predicate)?;
        }
        ConfidentialKernelSlotStatement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            let key = eval_confidential_kernel_slot_expr(runtime, key)?;
            let value = eval_confidential_kernel_slot_expr(runtime, value)?;
            let predicate = eval_optional_confidential_kernel_predicate(runtime, predicate, "map")?;
            runtime.map_put(*object_id, key, value, predicate)?;
        }
        ConfidentialKernelSlotStatement::Return { value } => {
            state.return_value = value
                .as_ref()
                .map(|expr| eval_confidential_kernel_slot_expr(runtime, expr))
                .transpose()?;
            state.returned = true;
        }
    }
    Ok(())
}

fn eval_optional_confidential_kernel_predicate<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    predicate: &Option<ConfidentialKernelSlotExpr>,
    label: &str,
) -> Result<Option<bool>> {
    predicate
        .as_ref()
        .map(|expr| eval_confidential_kernel_slot_expr(runtime, expr))
        .transpose()?
        .map(|value| {
            value
                .as_bool()
                .ok_or_else(|| anyhow!("{label} predicate must be boolean"))
        })
        .transpose()
}

fn eval_confidential_kernel_slot_expr<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    expr: &ConfidentialKernelSlotExpr,
) -> Result<Value> {
    match expr {
        ConfidentialKernelSlotExpr::Literal { value } => Ok(value.clone()),
        ConfidentialKernelSlotExpr::Slot { slot } => runtime.load_slot(*slot),
        ConfidentialKernelSlotExpr::Unary { op, expr } => {
            let value = eval_confidential_kernel_slot_expr(runtime, expr)?;
            eval_confidential_kernel_unary(op, value)
        }
        ConfidentialKernelSlotExpr::Binary { op, lhs, rhs } => {
            let lhs = eval_confidential_kernel_slot_expr(runtime, lhs)?;
            let rhs = eval_confidential_kernel_slot_expr(runtime, rhs)?;
            eval_confidential_kernel_binary(op, lhs, rhs)
        }
        ConfidentialKernelSlotExpr::Select {
            cond,
            when_true,
            when_false,
        } => {
            let cond = eval_confidential_kernel_slot_expr(runtime, cond)?
                .as_bool()
                .ok_or_else(|| anyhow!("select condition must be boolean"))?;
            let when_true = eval_confidential_kernel_slot_pure_expr(runtime, when_true)?;
            let when_false = eval_confidential_kernel_slot_pure_expr(runtime, when_false)?;
            Value::confidential_select(cond, when_true, when_false)
        }
        ConfidentialKernelSlotExpr::CellGet { object_id } => runtime.cell_get(*object_id),
        ConfidentialKernelSlotExpr::ArrayGet { object_id, index } => {
            let index = eval_confidential_kernel_slot_expr(runtime, index)?
                .as_uint()
                .ok_or_else(|| anyhow!("array index must be uint"))?
                as usize;
            runtime.array_get(*object_id, index)
        }
        ConfidentialKernelSlotExpr::MapGet { object_id, key } => {
            let key = eval_confidential_kernel_slot_expr(runtime, key)?;
            runtime.map_get(*object_id, &key)
        }
        ConfidentialKernelSlotExpr::Keccak256 { parts } => {
            let values = collect_confidential_hash_parts(
                parts.len(),
                parts
                    .iter()
                    .map(|part| eval_confidential_kernel_slot_expr(runtime, part)),
            )?;
            runtime.keccak256(values)
        }
    }
}

fn eval_confidential_kernel_slot_pure_expr<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    expr: &ConfidentialKernelSlotPureExpr,
) -> Result<Value> {
    match expr {
        ConfidentialKernelSlotPureExpr::Literal { value } => Ok(value.clone()),
        ConfidentialKernelSlotPureExpr::Slot { slot } => runtime.load_slot(*slot),
        ConfidentialKernelSlotPureExpr::Unary { op, expr } => {
            let value = eval_confidential_kernel_slot_pure_expr(runtime, expr)?;
            eval_confidential_kernel_unary(op, value)
        }
        ConfidentialKernelSlotPureExpr::Binary { op, lhs, rhs } => {
            let lhs = eval_confidential_kernel_slot_pure_expr(runtime, lhs)?;
            let rhs = eval_confidential_kernel_slot_pure_expr(runtime, rhs)?;
            eval_confidential_kernel_binary(op, lhs, rhs)
        }
        ConfidentialKernelSlotPureExpr::Select {
            cond,
            when_true,
            when_false,
        } => {
            let cond = eval_confidential_kernel_slot_pure_expr(runtime, cond)?
                .as_bool()
                .ok_or_else(|| anyhow!("select condition must be boolean"))?;
            let when_true = eval_confidential_kernel_slot_pure_expr(runtime, when_true)?;
            let when_false = eval_confidential_kernel_slot_pure_expr(runtime, when_false)?;
            Value::confidential_select(cond, when_true, when_false)
        }
        ConfidentialKernelSlotPureExpr::Keccak256 { parts } => {
            let values = collect_confidential_hash_parts(
                parts.len(),
                parts
                    .iter()
                    .map(|part| eval_confidential_kernel_slot_pure_expr(runtime, part)),
            )?;
            runtime.keccak256(values)
        }
    }
}

fn eval_confidential_kernel_unary(op: &UnaryOp, value: Value) -> Result<Value> {
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

fn eval_confidential_kernel_binary(op: &BinaryOp, lhs: Value, rhs: Value) -> Result<Value> {
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

impl CompiledFunction {
    pub fn confidential_kernel_program(
        &self,
    ) -> Result<ConfidentialKernelProgram, ConfidentialKernelLoweringError> {
        if !self.confidential {
            return Err(ConfidentialKernelLoweringError::EntrypointNotConfidential {
                entrypoint: self.signature.clone(),
            });
        }
        if let Some(program) = &self.confidential_program {
            return Ok(program.clone());
        }
        Ok(ConfidentialKernelProgram {
            entrypoint_id: self.signature.clone(),
            params: self
                .params
                .iter()
                .map(|(name, ty)| ConfidentialKernelParam {
                    name: name.clone(),
                    ty: ty.clone(),
                })
                .collect(),
            return_type: self.return_type.clone(),
            secret_args: self.secret_args.clone(),
            body: lower_confidential_kernel_statements(&self.body, &self.signature)?,
        })
    }
}

impl ConfidentialKernelProgram {
    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = vec![ConfidentialKernelStep {
            opcode: UoOpcode::Begin,
            object_id: None,
        }];
        for statement in &self.body {
            statement.collect_kernel_steps(&mut steps);
        }
        steps.extend([
            ConfidentialKernelStep {
                opcode: UoOpcode::Commit,
                object_id: None,
            },
            ConfidentialKernelStep {
                opcode: UoOpcode::Wipe,
                object_id: None,
            },
        ]);
        steps.into_boxed_slice()
    }

    pub fn to_slot_program(
        &self,
    ) -> Result<ConfidentialKernelSlotProgram, ConfidentialKernelSlotLoweringError> {
        let mut layout = ConfidentialKernelSlotLayout::new(&self.entrypoint_id, &self.params)?;
        let body = self
            .body
            .iter()
            .map(|statement| statement.to_slot_statement(&mut layout))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(ConfidentialKernelSlotProgram {
            entrypoint_id: self.entrypoint_id.clone(),
            param_count: self.params.len(),
            return_type: self.return_type.clone(),
            secret_args: self.secret_args.clone(),
            slot_count: layout.slot_count(),
            body,
        })
    }

    pub fn max_keccak_part_canonical_len_for_state(
        &self,
        state: &[StateObject],
    ) -> Result<usize, ConfidentialKernelHashShapeError> {
        let object_value_lens = state
            .iter()
            .map(|object| (object.id, object.value_type.canonical_len()))
            .collect::<BTreeMap<_, _>>();
        let mut env = self
            .params
            .iter()
            .map(|param| (param.name.clone(), param.ty.canonical_len()))
            .collect::<BTreeMap<_, _>>();
        let mut max_len = 0;
        for statement in &self.body {
            max_len = max_len.max(statement.max_keccak_part_canonical_len(
                self.entrypoint_id.as_str(),
                &mut env,
                &object_value_lens,
            )?);
        }
        Ok(max_len)
    }
}

impl ConfidentialKernelSlotProgram {
    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = vec![ConfidentialKernelStep {
            opcode: UoOpcode::Begin,
            object_id: None,
        }];
        for statement in &self.body {
            statement.collect_kernel_steps(&mut steps);
        }
        steps.extend([
            ConfidentialKernelStep {
                opcode: UoOpcode::Commit,
                object_id: None,
            },
            ConfidentialKernelStep {
                opcode: UoOpcode::Wipe,
                object_id: None,
            },
        ]);
        steps.into_boxed_slice()
    }

    pub fn is_runtime_normal_form(&self) -> bool {
        self.body
            .iter()
            .all(ConfidentialKernelSlotStatement::is_runtime_normal_form)
    }
}

impl ConfidentialKernelStatement {
    pub fn trace_name(&self) -> &'static str {
        match self {
            Self::Declare { .. } => "declare",
            Self::Assign { .. } => "assign",
            Self::Require { .. } => "require",
            Self::AbortIf { .. } => "abort_if",
            Self::CellSet { .. } => "cell_set",
            Self::ArraySet { .. } => "array_set",
            Self::MapPut { .. } => "map_put",
            Self::Return { .. } => "return",
        }
    }

    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps.into_boxed_slice()
    }

    fn collect_kernel_steps(&self, steps: &mut Vec<ConfidentialKernelStep>) {
        match self {
            Self::Declare { value, .. } | Self::Assign { value, .. } => {
                value.collect_kernel_steps(steps);
            }
            Self::Require { cond } | Self::AbortIf { cond } => {
                cond.collect_kernel_steps(steps);
            }
            Self::CellSet {
                object_id,
                value,
                predicate,
            } => {
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::CellSet,
                    object_id: Some(*object_id),
                });
            }
            Self::ArraySet {
                object_id,
                index,
                value,
                predicate,
            } => {
                index.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::ArraySet,
                    object_id: Some(*object_id),
                });
            }
            Self::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                key.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(*object_id),
                });
            }
            Self::Return { value } => {
                if let Some(value) = value {
                    value.collect_kernel_steps(steps);
                }
            }
        }
    }
}

impl ConfidentialKernelSlotStatement {
    pub fn is_runtime_normal_form(&self) -> bool {
        !matches!(self, Self::Require { .. })
    }

    pub fn trace_name(&self) -> &'static str {
        match self {
            Self::Declare { .. } => "declare",
            Self::Assign { .. } => "assign",
            Self::Require { .. } => "require",
            Self::AbortIf { .. } => "abort_if",
            Self::CellSet { .. } => "cell_set",
            Self::ArraySet { .. } => "array_set",
            Self::MapPut { .. } => "map_put",
            Self::Return { .. } => "return",
        }
    }

    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps.into_boxed_slice()
    }

    fn collect_kernel_steps(&self, steps: &mut Vec<ConfidentialKernelStep>) {
        match self {
            Self::Declare { value, .. } | Self::Assign { value, .. } => {
                value.collect_kernel_steps(steps);
            }
            Self::Require { cond } | Self::AbortIf { cond } => {
                cond.collect_kernel_steps(steps);
            }
            Self::CellSet {
                object_id,
                value,
                predicate,
            } => {
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::CellSet,
                    object_id: Some(*object_id),
                });
            }
            Self::ArraySet {
                object_id,
                index,
                value,
                predicate,
            } => {
                index.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::ArraySet,
                    object_id: Some(*object_id),
                });
            }
            Self::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                key.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(*object_id),
                });
            }
            Self::Return { value } => {
                if let Some(value) = value {
                    value.collect_kernel_steps(steps);
                }
            }
        }
    }
}

impl ConfidentialKernelExpr {
    pub fn kernel_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps.into_boxed_slice()
    }

    fn collect_kernel_steps(&self, steps: &mut Vec<ConfidentialKernelStep>) {
        match self {
            Self::Literal { .. } | Self::Var { .. } => {}
            Self::Unary { expr, .. } => expr.collect_kernel_steps(steps),
            Self::Binary { lhs, rhs, .. } => {
                lhs.collect_kernel_steps(steps);
                rhs.collect_kernel_steps(steps);
            }
            Self::Select { cond, .. } => cond.collect_kernel_steps(steps),
            Self::CellGet { object_id } => steps.push(ConfidentialKernelStep {
                opcode: UoOpcode::CellGet,
                object_id: Some(*object_id),
            }),
            Self::ArrayGet { object_id, index } => {
                index.collect_kernel_steps(steps);
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::ArrayGet,
                    object_id: Some(*object_id),
                });
            }
            Self::MapGet { object_id, key } => {
                key.collect_kernel_steps(steps);
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(*object_id),
                });
            }
            Self::Keccak256 { parts } => {
                for part in parts {
                    part.collect_kernel_steps(steps);
                }
            }
        }
    }
}

impl ConfidentialKernelSlotExpr {
    pub fn kernel_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps.into_boxed_slice()
    }

    fn collect_kernel_steps(&self, steps: &mut Vec<ConfidentialKernelStep>) {
        match self {
            Self::Literal { .. } | Self::Slot { .. } => {}
            Self::Unary { expr, .. } => expr.collect_kernel_steps(steps),
            Self::Binary { lhs, rhs, .. } => {
                lhs.collect_kernel_steps(steps);
                rhs.collect_kernel_steps(steps);
            }
            Self::Select { cond, .. } => cond.collect_kernel_steps(steps),
            Self::CellGet { object_id } => steps.push(ConfidentialKernelStep {
                opcode: UoOpcode::CellGet,
                object_id: Some(*object_id),
            }),
            Self::ArrayGet { object_id, index } => {
                index.collect_kernel_steps(steps);
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::ArrayGet,
                    object_id: Some(*object_id),
                });
            }
            Self::MapGet { object_id, key } => {
                key.collect_kernel_steps(steps);
                steps.push(ConfidentialKernelStep {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(*object_id),
                });
            }
            Self::Keccak256 { parts } => {
                for part in parts {
                    part.collect_kernel_steps(steps);
                }
            }
        }
    }
}

impl ConfidentialKernelStatement {
    fn max_keccak_part_canonical_len(
        &self,
        entrypoint: &str,
        env: &mut BTreeMap<String, usize>,
        object_value_lens: &BTreeMap<u32, usize>,
    ) -> Result<usize, ConfidentialKernelHashShapeError> {
        match self {
            Self::Declare { name, ty, value } => {
                env.insert(name.clone(), ty.canonical_len());
                value.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)
            }
            Self::Assign { value, .. }
            | Self::Require { cond: value }
            | Self::AbortIf { cond: value } => {
                value.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)
            }
            Self::CellSet {
                value, predicate, ..
            } => {
                let mut max_len =
                    value.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)?;
                if let Some(predicate) = predicate {
                    max_len = max_len.max(predicate.max_keccak_part_canonical_len(
                        entrypoint,
                        env,
                        object_value_lens,
                    )?);
                }
                Ok(max_len)
            }
            Self::ArraySet {
                index,
                value,
                predicate,
                ..
            }
            | Self::MapPut {
                key: index,
                value,
                predicate,
                ..
            } => {
                let mut max_len =
                    index.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)?;
                max_len = max_len.max(value.max_keccak_part_canonical_len(
                    entrypoint,
                    env,
                    object_value_lens,
                )?);
                if let Some(predicate) = predicate {
                    max_len = max_len.max(predicate.max_keccak_part_canonical_len(
                        entrypoint,
                        env,
                        object_value_lens,
                    )?);
                }
                Ok(max_len)
            }
            Self::Return { value } => value
                .as_ref()
                .map(|value| {
                    value.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)
                })
                .transpose()
                .map(|value| value.unwrap_or(0)),
        }
    }
}

impl ConfidentialKernelExpr {
    fn max_keccak_part_canonical_len(
        &self,
        entrypoint: &str,
        env: &BTreeMap<String, usize>,
        object_value_lens: &BTreeMap<u32, usize>,
    ) -> Result<usize, ConfidentialKernelHashShapeError> {
        match self {
            Self::Literal { .. } | Self::Var { .. } | Self::CellGet { .. } => Ok(0),
            Self::Unary { expr, .. } => {
                expr.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)
            }
            Self::Binary { lhs, rhs, .. } => Ok(lhs
                .max_keccak_part_canonical_len(entrypoint, env, object_value_lens)?
                .max(rhs.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)?)),
            Self::Select {
                cond,
                when_true,
                when_false,
            } => Ok(cond
                .max_keccak_part_canonical_len(entrypoint, env, object_value_lens)?
                .max(when_true.max_keccak_part_canonical_len(entrypoint, env)?)
                .max(when_false.max_keccak_part_canonical_len(entrypoint, env)?)),
            Self::ArrayGet { index, .. } => {
                index.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)
            }
            Self::MapGet { key, .. } => {
                key.max_keccak_part_canonical_len(entrypoint, env, object_value_lens)
            }
            Self::Keccak256 { parts } => {
                let mut max_len = 0;
                for part in parts {
                    max_len =
                        max_len.max(part.canonical_len(entrypoint, env, object_value_lens)?);
                    max_len = max_len.max(part.max_keccak_part_canonical_len(
                        entrypoint,
                        env,
                        object_value_lens,
                    )?);
                }
                Ok(max_len)
            }
        }
    }

    fn canonical_len(
        &self,
        entrypoint: &str,
        env: &BTreeMap<String, usize>,
        object_value_lens: &BTreeMap<u32, usize>,
    ) -> Result<usize, ConfidentialKernelHashShapeError> {
        match self {
            Self::Literal { value } => Ok(value.canonical_len()),
            Self::Var { name } => env.get(name).copied().ok_or_else(|| {
                ConfidentialKernelHashShapeError::UnknownVariable {
                    entrypoint: entrypoint.into(),
                    name: name.clone(),
                }
            }),
            Self::Unary { op, .. } => Ok(match op {
                UnaryOp::Not => Type::Scalar(crate::types::ScalarType::Bool).canonical_len(),
                UnaryOp::Neg => Type::Scalar(crate::types::ScalarType::Uint(256)).canonical_len(),
            }),
            Self::Binary { op, .. } => Ok(match op {
                BinaryOp::Eq
                | BinaryOp::Neq
                | BinaryOp::Lt
                | BinaryOp::Lte
                | BinaryOp::Gt
                | BinaryOp::Gte
                | BinaryOp::And
                | BinaryOp::Or => Type::Scalar(crate::types::ScalarType::Bool).canonical_len(),
                BinaryOp::Add
                | BinaryOp::Sub
                | BinaryOp::Mul
                | BinaryOp::Div
                | BinaryOp::Mod
                | BinaryOp::BitAnd
                | BinaryOp::BitOr
                | BinaryOp::BitXor => {
                    Type::Scalar(crate::types::ScalarType::Uint(256)).canonical_len()
                }
            }),
            Self::Select {
                when_true,
                when_false,
                ..
            } => {
                let when_true_len = when_true.canonical_len(entrypoint, env)?;
                let when_false_len = when_false.canonical_len(entrypoint, env)?;
                if when_true_len != when_false_len {
                    return Err(ConfidentialKernelHashShapeError::SelectArmLengthMismatch {
                        entrypoint: entrypoint.into(),
                        when_true: when_true_len,
                        when_false: when_false_len,
                    });
                }
                Ok(when_true_len)
            }
            Self::CellGet { object_id }
            | Self::ArrayGet { object_id, .. }
            | Self::MapGet { object_id, .. } => object_value_lens
                .get(object_id)
                .copied()
                .ok_or_else(|| ConfidentialKernelHashShapeError::UnknownObjectId {
                    entrypoint: entrypoint.into(),
                    object_id: *object_id,
                }),
            Self::Keccak256 { .. } => {
                Ok(Type::Scalar(crate::types::ScalarType::Bytes32).canonical_len())
            }
        }
    }
}

impl ConfidentialKernelPureExpr {
    fn max_keccak_part_canonical_len(
        &self,
        entrypoint: &str,
        env: &BTreeMap<String, usize>,
    ) -> Result<usize, ConfidentialKernelHashShapeError> {
        match self {
            Self::Literal { .. } | Self::Var { .. } => Ok(0),
            Self::Unary { expr, .. } => expr.max_keccak_part_canonical_len(entrypoint, env),
            Self::Binary { lhs, rhs, .. } => Ok(lhs
                .max_keccak_part_canonical_len(entrypoint, env)?
                .max(rhs.max_keccak_part_canonical_len(entrypoint, env)?)),
            Self::Select {
                cond,
                when_true,
                when_false,
            } => Ok(cond
                .max_keccak_part_canonical_len(entrypoint, env)?
                .max(when_true.max_keccak_part_canonical_len(entrypoint, env)?)
                .max(when_false.max_keccak_part_canonical_len(entrypoint, env)?)),
            Self::Keccak256 { parts } => {
                let mut max_len = 0;
                for part in parts {
                    max_len = max_len.max(part.canonical_len(entrypoint, env)?);
                    max_len = max_len.max(part.max_keccak_part_canonical_len(entrypoint, env)?);
                }
                Ok(max_len)
            }
        }
    }

    fn canonical_len(
        &self,
        entrypoint: &str,
        env: &BTreeMap<String, usize>,
    ) -> Result<usize, ConfidentialKernelHashShapeError> {
        match self {
            Self::Literal { value } => Ok(value.canonical_len()),
            Self::Var { name } => env.get(name).copied().ok_or_else(|| {
                ConfidentialKernelHashShapeError::UnknownVariable {
                    entrypoint: entrypoint.into(),
                    name: name.clone(),
                }
            }),
            Self::Unary { op, .. } => Ok(match op {
                UnaryOp::Not => Type::Scalar(crate::types::ScalarType::Bool).canonical_len(),
                UnaryOp::Neg => Type::Scalar(crate::types::ScalarType::Uint(256)).canonical_len(),
            }),
            Self::Binary { op, .. } => Ok(match op {
                BinaryOp::Eq
                | BinaryOp::Neq
                | BinaryOp::Lt
                | BinaryOp::Lte
                | BinaryOp::Gt
                | BinaryOp::Gte
                | BinaryOp::And
                | BinaryOp::Or => Type::Scalar(crate::types::ScalarType::Bool).canonical_len(),
                BinaryOp::Add
                | BinaryOp::Sub
                | BinaryOp::Mul
                | BinaryOp::Div
                | BinaryOp::Mod
                | BinaryOp::BitAnd
                | BinaryOp::BitOr
                | BinaryOp::BitXor => {
                    Type::Scalar(crate::types::ScalarType::Uint(256)).canonical_len()
                }
            }),
            Self::Select {
                when_true,
                when_false,
                ..
            } => {
                let when_true_len = when_true.canonical_len(entrypoint, env)?;
                let when_false_len = when_false.canonical_len(entrypoint, env)?;
                if when_true_len != when_false_len {
                    return Err(ConfidentialKernelHashShapeError::SelectArmLengthMismatch {
                        entrypoint: entrypoint.into(),
                        when_true: when_true_len,
                        when_false: when_false_len,
                    });
                }
                Ok(when_true_len)
            }
            Self::Keccak256 { .. } => {
                Ok(Type::Scalar(crate::types::ScalarType::Bytes32).canonical_len())
            }
        }
    }
}

#[derive(Debug)]
struct ConfidentialKernelSlotLayout {
    entrypoint: String,
    slots: BTreeMap<String, usize>,
    next_slot: usize,
}

impl ConfidentialKernelSlotLayout {
    fn new(
        entrypoint: &str,
        params: &[ConfidentialKernelParam],
    ) -> Result<Self, ConfidentialKernelSlotLoweringError> {
        let mut layout = Self {
            entrypoint: entrypoint.into(),
            slots: BTreeMap::new(),
            next_slot: 0,
        };
        for param in params {
            layout.declare(&param.name)?;
        }
        Ok(layout)
    }

    fn declare(&mut self, name: &str) -> Result<usize, ConfidentialKernelSlotLoweringError> {
        if self.slots.contains_key(name) {
            return Err(ConfidentialKernelSlotLoweringError::DuplicateBinding {
                entrypoint: self.entrypoint.clone(),
                name: name.into(),
            });
        }
        let slot = self.next_slot;
        self.slots.insert(name.into(), slot);
        self.next_slot += 1;
        Ok(slot)
    }

    fn resolve(&self, name: &str) -> Result<usize, ConfidentialKernelSlotLoweringError> {
        self.slots.get(name).copied().ok_or_else(|| {
            ConfidentialKernelSlotLoweringError::UnknownVariable {
                entrypoint: self.entrypoint.clone(),
                name: name.into(),
            }
        })
    }

    fn slot_count(&self) -> usize {
        self.next_slot
    }
}

impl ConfidentialKernelStatement {
    fn to_slot_statement(
        &self,
        layout: &mut ConfidentialKernelSlotLayout,
    ) -> Result<ConfidentialKernelSlotStatement, ConfidentialKernelSlotLoweringError> {
        match self {
            Self::Declare { name, value, .. } => Ok(ConfidentialKernelSlotStatement::Declare {
                slot: layout.declare(name)?,
                value: value.to_slot_expr(layout)?,
            }),
            Self::Assign { name, value } => Ok(ConfidentialKernelSlotStatement::Assign {
                slot: layout.resolve(name)?,
                value: value.to_slot_expr(layout)?,
            }),
            Self::Require { cond } => Ok(ConfidentialKernelSlotStatement::AbortIf {
                cond: cond.to_slot_expr(layout)?,
            }),
            Self::AbortIf { cond } => Ok(ConfidentialKernelSlotStatement::AbortIf {
                cond: cond.to_slot_expr(layout)?,
            }),
            Self::CellSet {
                object_id,
                value,
                predicate,
            } => Ok(ConfidentialKernelSlotStatement::CellSet {
                object_id: *object_id,
                value: value.to_slot_expr(layout)?,
                predicate: predicate
                    .as_ref()
                    .map(|expr| expr.to_slot_expr(layout))
                    .transpose()?,
            }),
            Self::ArraySet {
                object_id,
                index,
                value,
                predicate,
            } => Ok(ConfidentialKernelSlotStatement::ArraySet {
                object_id: *object_id,
                index: index.to_slot_expr(layout)?,
                value: value.to_slot_expr(layout)?,
                predicate: predicate
                    .as_ref()
                    .map(|expr| expr.to_slot_expr(layout))
                    .transpose()?,
            }),
            Self::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => Ok(ConfidentialKernelSlotStatement::MapPut {
                object_id: *object_id,
                key: key.to_slot_expr(layout)?,
                value: value.to_slot_expr(layout)?,
                predicate: predicate
                    .as_ref()
                    .map(|expr| expr.to_slot_expr(layout))
                    .transpose()?,
            }),
            Self::Return { value } => Ok(ConfidentialKernelSlotStatement::Return {
                value: value
                    .as_ref()
                    .map(|expr| expr.to_slot_expr(layout))
                    .transpose()?,
            }),
        }
    }
}

impl ConfidentialKernelExpr {
    fn to_slot_expr(
        &self,
        layout: &ConfidentialKernelSlotLayout,
    ) -> Result<ConfidentialKernelSlotExpr, ConfidentialKernelSlotLoweringError> {
        match self {
            Self::Literal { value } => Ok(ConfidentialKernelSlotExpr::Literal {
                value: value.clone(),
            }),
            Self::Var { name } => Ok(ConfidentialKernelSlotExpr::Slot {
                slot: layout.resolve(name)?,
            }),
            Self::Unary { op, expr } => Ok(ConfidentialKernelSlotExpr::Unary {
                op: op.clone(),
                expr: Box::new(expr.to_slot_expr(layout)?),
            }),
            Self::Binary { op, lhs, rhs } => Ok(ConfidentialKernelSlotExpr::Binary {
                op: op.clone(),
                lhs: Box::new(lhs.to_slot_expr(layout)?),
                rhs: Box::new(rhs.to_slot_expr(layout)?),
            }),
            Self::Select {
                cond,
                when_true,
                when_false,
            } => Ok(ConfidentialKernelSlotExpr::Select {
                cond: Box::new(cond.to_slot_expr(layout)?),
                when_true: Box::new(when_true.to_slot_pure_expr(layout)?),
                when_false: Box::new(when_false.to_slot_pure_expr(layout)?),
            }),
            Self::CellGet { object_id } => Ok(ConfidentialKernelSlotExpr::CellGet {
                object_id: *object_id,
            }),
            Self::ArrayGet { object_id, index } => Ok(ConfidentialKernelSlotExpr::ArrayGet {
                object_id: *object_id,
                index: Box::new(index.to_slot_expr(layout)?),
            }),
            Self::MapGet { object_id, key } => Ok(ConfidentialKernelSlotExpr::MapGet {
                object_id: *object_id,
                key: Box::new(key.to_slot_expr(layout)?),
            }),
            Self::Keccak256 { parts } => Ok(ConfidentialKernelSlotExpr::Keccak256 {
                parts: parts
                    .iter()
                    .map(|part| part.to_slot_expr(layout))
                    .collect::<Result<Vec<_>, _>>()?,
            }),
        }
    }
}

impl ConfidentialKernelPureExpr {
    fn to_slot_pure_expr(
        &self,
        layout: &ConfidentialKernelSlotLayout,
    ) -> Result<ConfidentialKernelSlotPureExpr, ConfidentialKernelSlotLoweringError> {
        match self {
            Self::Literal { value } => Ok(ConfidentialKernelSlotPureExpr::Literal {
                value: value.clone(),
            }),
            Self::Var { name } => Ok(ConfidentialKernelSlotPureExpr::Slot {
                slot: layout.resolve(name)?,
            }),
            Self::Unary { op, expr } => Ok(ConfidentialKernelSlotPureExpr::Unary {
                op: op.clone(),
                expr: Box::new(expr.to_slot_pure_expr(layout)?),
            }),
            Self::Binary { op, lhs, rhs } => Ok(ConfidentialKernelSlotPureExpr::Binary {
                op: op.clone(),
                lhs: Box::new(lhs.to_slot_pure_expr(layout)?),
                rhs: Box::new(rhs.to_slot_pure_expr(layout)?),
            }),
            Self::Select {
                cond,
                when_true,
                when_false,
            } => Ok(ConfidentialKernelSlotPureExpr::Select {
                cond: Box::new(cond.to_slot_pure_expr(layout)?),
                when_true: Box::new(when_true.to_slot_pure_expr(layout)?),
                when_false: Box::new(when_false.to_slot_pure_expr(layout)?),
            }),
            Self::Keccak256 { parts } => Ok(ConfidentialKernelSlotPureExpr::Keccak256 {
                parts: parts
                    .iter()
                    .map(|part| part.to_slot_pure_expr(layout))
                    .collect::<Result<Vec<_>, _>>()?,
            }),
        }
    }
}

pub fn lower_confidential_kernel_statements(
    statements: &[Statement],
    entrypoint: &str,
) -> Result<Vec<ConfidentialKernelStatement>, ConfidentialKernelLoweringError> {
    statements
        .iter()
        .enumerate()
        .map(|(index, statement)| lower_confidential_kernel_statement(statement, entrypoint, index))
        .collect()
}

pub fn lower_confidential_kernel_expr(
    expr: &Expr,
    entrypoint: &str,
) -> Result<ConfidentialKernelExpr, ConfidentialKernelLoweringError> {
    match expr {
        Expr::Literal(value) => Ok(ConfidentialKernelExpr::Literal {
            value: value.clone(),
        }),
        Expr::Var(name) => Ok(ConfidentialKernelExpr::Var { name: name.clone() }),
        Expr::Unary { op, expr } => Ok(ConfidentialKernelExpr::Unary {
            op: op.clone(),
            expr: Box::new(lower_confidential_kernel_expr(expr, entrypoint)?),
        }),
        Expr::Binary { op, lhs, rhs } => Ok(ConfidentialKernelExpr::Binary {
            op: op.clone(),
            lhs: Box::new(lower_confidential_kernel_expr(lhs, entrypoint)?),
            rhs: Box::new(lower_confidential_kernel_expr(rhs, entrypoint)?),
        }),
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            if expr_contains_kernel_access(when_true) || expr_contains_kernel_access(when_false) {
                return Err(
                    ConfidentialKernelLoweringError::SelectContainsKernelAccess {
                        entrypoint: entrypoint.into(),
                    },
                );
            }
            let when_true =
                lower_confidential_kernel_pure_expr(when_true, entrypoint).map_err(|_| {
                    ConfidentialKernelLoweringError::SelectArmOutsideBranchlessFragment {
                        entrypoint: entrypoint.into(),
                    }
                })?;
            let when_false =
                lower_confidential_kernel_pure_expr(when_false, entrypoint).map_err(|_| {
                    ConfidentialKernelLoweringError::SelectArmOutsideBranchlessFragment {
                        entrypoint: entrypoint.into(),
                    }
                })?;
            Ok(ConfidentialKernelExpr::Select {
                cond: Box::new(lower_confidential_kernel_expr(cond, entrypoint)?),
                when_true: Box::new(when_true),
                when_false: Box::new(when_false),
            })
        }
        Expr::CellGet { object_id } => Ok(ConfidentialKernelExpr::CellGet {
            object_id: *object_id,
        }),
        Expr::ArrayGet { object_id, index } => Ok(ConfidentialKernelExpr::ArrayGet {
            object_id: *object_id,
            index: Box::new(lower_confidential_kernel_expr(index, entrypoint)?),
        }),
        Expr::MapGet { object_id, key } => Ok(ConfidentialKernelExpr::MapGet {
            object_id: *object_id,
            key: Box::new(lower_confidential_kernel_expr(key, entrypoint)?),
        }),
        Expr::StructField { .. } => Err(ConfidentialKernelLoweringError::ConfidentialStructField {
            entrypoint: entrypoint.into(),
        }),
        Expr::ArrayIndex { .. } => Err(ConfidentialKernelLoweringError::ConfidentialArrayIndex {
            entrypoint: entrypoint.into(),
        }),
        Expr::Keccak256 { parts } => Ok(ConfidentialKernelExpr::Keccak256 {
            parts: parts
                .iter()
                .map(|part| lower_confidential_kernel_expr(part, entrypoint))
                .collect::<Result<Vec<_>, _>>()?,
        }),
    }
}

pub fn lower_confidential_kernel_pure_expr(
    expr: &Expr,
    entrypoint: &str,
) -> Result<ConfidentialKernelPureExpr, ConfidentialKernelLoweringError> {
    match expr {
        Expr::Literal(value) => Ok(ConfidentialKernelPureExpr::Literal {
            value: value.clone(),
        }),
        Expr::Var(name) => Ok(ConfidentialKernelPureExpr::Var { name: name.clone() }),
        Expr::Unary { op, expr } => Ok(ConfidentialKernelPureExpr::Unary {
            op: op.clone(),
            expr: Box::new(lower_confidential_kernel_pure_expr(expr, entrypoint)?),
        }),
        Expr::Binary { op, lhs, rhs } => Ok(ConfidentialKernelPureExpr::Binary {
            op: op.clone(),
            lhs: Box::new(lower_confidential_kernel_pure_expr(lhs, entrypoint)?),
            rhs: Box::new(lower_confidential_kernel_pure_expr(rhs, entrypoint)?),
        }),
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => Ok(ConfidentialKernelPureExpr::Select {
            cond: Box::new(lower_confidential_kernel_pure_expr(cond, entrypoint)?),
            when_true: Box::new(lower_confidential_kernel_pure_expr(when_true, entrypoint)?),
            when_false: Box::new(lower_confidential_kernel_pure_expr(when_false, entrypoint)?),
        }),
        Expr::Keccak256 { parts } => Ok(ConfidentialKernelPureExpr::Keccak256 {
            parts: parts
                .iter()
                .map(|part| lower_confidential_kernel_pure_expr(part, entrypoint))
                .collect::<Result<Vec<_>, _>>()?,
        }),
        Expr::StructField { .. } => Err(ConfidentialKernelLoweringError::ConfidentialStructField {
            entrypoint: entrypoint.into(),
        }),
        Expr::ArrayIndex { .. } => Err(ConfidentialKernelLoweringError::ConfidentialArrayIndex {
            entrypoint: entrypoint.into(),
        }),
        Expr::CellGet { .. } | Expr::ArrayGet { .. } | Expr::MapGet { .. } => Err(
            ConfidentialKernelLoweringError::SelectArmOutsideBranchlessFragment {
                entrypoint: entrypoint.into(),
            },
        ),
    }
}

fn lower_confidential_kernel_statement(
    statement: &Statement,
    entrypoint: &str,
    index: usize,
) -> Result<ConfidentialKernelStatement, ConfidentialKernelLoweringError> {
    match statement {
        Statement::Declare { name, ty, value } => Ok(ConfidentialKernelStatement::Declare {
            name: name.clone(),
            ty: ty.clone(),
            value: lower_confidential_kernel_expr(value, entrypoint)?,
        }),
        Statement::Assign { name, value } => Ok(ConfidentialKernelStatement::Assign {
            name: name.clone(),
            value: lower_confidential_kernel_expr(value, entrypoint)?,
        }),
        Statement::Require { cond } => Ok(ConfidentialKernelStatement::Require {
            cond: lower_confidential_kernel_expr(cond, entrypoint)?,
        }),
        Statement::AbortIf { cond } => Ok(ConfidentialKernelStatement::AbortIf {
            cond: lower_confidential_kernel_expr(cond, entrypoint)?,
        }),
        Statement::If { .. } => Err(ConfidentialKernelLoweringError::ConfidentialControlFlow {
            entrypoint: entrypoint.into(),
            statement: format!("if[{index}]"),
        }),
        Statement::For { .. } => Err(ConfidentialKernelLoweringError::ConfidentialControlFlow {
            entrypoint: entrypoint.into(),
            statement: format!("for[{index}]"),
        }),
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => Ok(ConfidentialKernelStatement::CellSet {
            object_id: *object_id,
            value: lower_confidential_kernel_expr(value, entrypoint)?,
            predicate: predicate
                .as_ref()
                .map(|expr| lower_confidential_kernel_expr(expr, entrypoint))
                .transpose()?,
        }),
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => Ok(ConfidentialKernelStatement::ArraySet {
            object_id: *object_id,
            index: lower_confidential_kernel_expr(index, entrypoint)?,
            value: lower_confidential_kernel_expr(value, entrypoint)?,
            predicate: predicate
                .as_ref()
                .map(|expr| lower_confidential_kernel_expr(expr, entrypoint))
                .transpose()?,
        }),
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => Ok(ConfidentialKernelStatement::MapPut {
            object_id: *object_id,
            key: lower_confidential_kernel_expr(key, entrypoint)?,
            value: lower_confidential_kernel_expr(value, entrypoint)?,
            predicate: predicate
                .as_ref()
                .map(|expr| lower_confidential_kernel_expr(expr, entrypoint))
                .transpose()?,
        }),
        Statement::Return { value } => Ok(ConfidentialKernelStatement::Return {
            value: value
                .as_ref()
                .map(|expr| lower_confidential_kernel_expr(expr, entrypoint))
                .transpose()?,
        }),
    }
}

fn expr_contains_kernel_access(expr: &Expr) -> bool {
    match expr {
        Expr::Literal(_) | Expr::Var(_) => false,
        Expr::Unary { expr, .. } => expr_contains_kernel_access(expr),
        Expr::Binary { lhs, rhs, .. } => {
            expr_contains_kernel_access(lhs) || expr_contains_kernel_access(rhs)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            expr_contains_kernel_access(cond)
                || expr_contains_kernel_access(when_true)
                || expr_contains_kernel_access(when_false)
        }
        Expr::CellGet { .. } | Expr::ArrayGet { .. } | Expr::MapGet { .. } => true,
        Expr::StructField { base, .. } => expr_contains_kernel_access(base),
        Expr::ArrayIndex { base, index } => {
            expr_contains_kernel_access(base) || expr_contains_kernel_access(index)
        }
        Expr::Keccak256 { parts } => parts.iter().any(expr_contains_kernel_access),
    }
}

#[cfg(test)]
mod tests {
    use super::{
        execute_confidential_kernel_slot_call, execute_confidential_kernel_slot_program,
        ConfidentialCallInputs, ConfidentialKernelEffectRuntime,
        ConfidentialKernelExecutionOutcome, ConfidentialKernelSlotExpr,
        ConfidentialKernelSlotLoweringError, ConfidentialKernelSlotProgram,
        ConfidentialKernelSlotRuntime, ConfidentialKernelSlotStatement,
    };
    use crate::{
        ir::StateObject, BackendKind, BinaryOp, CompiledFunction, ContainerKind, Expr, ScalarType,
        Statement, Type, Value,
    };
    use anyhow::{anyhow, Result};

    fn uint_type() -> Type {
        Type::Scalar(ScalarType::Uint(256))
    }

    fn sample_confidential_function() -> CompiledFunction {
        CompiledFunction {
            signature: "demo(uint256)".into(),
            params: vec![("arg".into(), uint_type())],
            return_type: Some(uint_type()),
            body: vec![
                Statement::Declare {
                    name: "tmp".into(),
                    ty: uint_type(),
                    value: Expr::Binary {
                        op: BinaryOp::Add,
                        lhs: Box::new(Expr::Var("arg".into())),
                        rhs: Box::new(Expr::Literal(Value::uint(1))),
                    },
                },
                Statement::Assign {
                    name: "tmp".into(),
                    value: Expr::Binary {
                        op: BinaryOp::Mul,
                        lhs: Box::new(Expr::Var("tmp".into())),
                        rhs: Box::new(Expr::Literal(Value::uint(2))),
                    },
                },
                Statement::CellSet {
                    object_id: 7,
                    value: Expr::Var("tmp".into()),
                    predicate: Some(Expr::Literal(Value::bool(true))),
                },
                Statement::Return {
                    value: Some(Expr::Var("tmp".into())),
                },
            ],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        }
    }

    fn sample_cell_state_object() -> StateObject {
        StateObject {
            id: 7,
            name: "counter".into(),
            kind: ContainerKind::Cell,
            backend: BackendKind::FullScan,
            oram_scheme: "surrogate_public_schedule_v1".into(),
            value_type: uint_type(),
            key_type: None,
            capacity: None,
            confidential: true,
        }
    }

    #[derive(Default)]
    struct MockRuntime {
        slots: Vec<Option<Value>>,
        statements: Vec<&'static str>,
        cell_sets: Vec<(u32, Value, Option<bool>)>,
    }

    impl MockRuntime {
        fn with_slot_count(slot_count: usize) -> Self {
            Self {
                slots: vec![None; slot_count],
                statements: Vec::new(),
                cell_sets: Vec::new(),
            }
        }
    }

    impl ConfidentialKernelSlotRuntime for MockRuntime {
        fn note_statement(&mut self, statement: &ConfidentialKernelSlotStatement) -> Result<()> {
            self.statements.push(statement.trace_name());
            Ok(())
        }

        fn load_slot(&self, slot: usize) -> Result<Value> {
            self.slots
                .get(slot)
                .and_then(Option::as_ref)
                .cloned()
                .ok_or_else(|| anyhow!("missing mock slot {slot}"))
        }

        fn store_slot(&mut self, slot: usize, value: Value) -> Result<()> {
            let cell = self
                .slots
                .get_mut(slot)
                .ok_or_else(|| anyhow!("missing mock slot {slot}"))?;
            *cell = Some(value);
            Ok(())
        }

        fn cell_get(&mut self, object_id: u32) -> Result<Value> {
            Err(anyhow!("unexpected cell_get({object_id}) in mock runtime"))
        }

        fn cell_set(
            &mut self,
            object_id: u32,
            value: Value,
            predicate: Option<bool>,
        ) -> Result<()> {
            self.cell_sets.push((object_id, value, predicate));
            Ok(())
        }

        fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value> {
            Err(anyhow!(
                "unexpected array_get({object_id}, {index}) in mock runtime"
            ))
        }

        fn array_set(
            &mut self,
            object_id: u32,
            index: usize,
            _value: Value,
            _predicate: Option<bool>,
        ) -> Result<()> {
            Err(anyhow!(
                "unexpected array_set({object_id}, {index}) in mock runtime"
            ))
        }

        fn map_get(&mut self, object_id: u32, key: &Value) -> Result<Value> {
            Err(anyhow!(
                "unexpected map_get({object_id}, {key:?}) in mock runtime"
            ))
        }

        fn map_put(
            &mut self,
            object_id: u32,
            key: Value,
            value: Value,
            predicate: Option<bool>,
        ) -> Result<()> {
            Err(anyhow!(
                "unexpected map_put({object_id}, {key:?}, {value:?}, {predicate:?}) in mock runtime"
            ))
        }

        fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value> {
            Err(anyhow!("unexpected keccak256({parts:?}) in mock runtime"))
        }
    }

    impl ConfidentialKernelEffectRuntime for MockRuntime {
        fn note_statement(&mut self, statement: &ConfidentialKernelSlotStatement) -> Result<()> {
            self.statements.push(statement.trace_name());
            Ok(())
        }

        fn cell_get(&mut self, object_id: u32) -> Result<Value> {
            Err(anyhow!("unexpected cell_get({object_id}) in mock runtime"))
        }

        fn cell_set(
            &mut self,
            object_id: u32,
            value: Value,
            predicate: Option<bool>,
        ) -> Result<()> {
            self.cell_sets.push((object_id, value, predicate));
            Ok(())
        }

        fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value> {
            Err(anyhow!(
                "unexpected array_get({object_id}, {index}) in mock runtime"
            ))
        }

        fn array_set(
            &mut self,
            object_id: u32,
            index: usize,
            _value: Value,
            _predicate: Option<bool>,
        ) -> Result<()> {
            Err(anyhow!(
                "unexpected array_set({object_id}, {index}) in mock runtime"
            ))
        }

        fn map_get(&mut self, object_id: u32, key: &Value) -> Result<Value> {
            Err(anyhow!(
                "unexpected map_get({object_id}, {key:?}) in mock runtime"
            ))
        }

        fn map_put(
            &mut self,
            object_id: u32,
            key: Value,
            value: Value,
            predicate: Option<bool>,
        ) -> Result<()> {
            Err(anyhow!(
                "unexpected map_put({object_id}, {key:?}, {value:?}, {predicate:?}) in mock runtime"
            ))
        }

        fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value> {
            Err(anyhow!("unexpected keccak256({parts:?}) in mock runtime"))
        }
    }

    #[test]
    fn confidential_kernel_slot_program_preserves_schedule() {
        let function = sample_confidential_function();
        let named = function.confidential_kernel_program().unwrap();
        let slot = named.to_slot_program().unwrap();

        assert_eq!(slot.entrypoint_id, named.entrypoint_id);
        assert_eq!(slot.param_count, 1);
        assert_eq!(slot.slot_count, 2);
        assert_eq!(slot.secret_args, vec![0]);
        assert_eq!(
            slot.expected_runtime_steps(),
            named.expected_runtime_steps()
        );

        match &slot.body[0] {
            ConfidentialKernelSlotStatement::Declare { slot, value } => {
                assert_eq!(*slot, 1);
                match value {
                    ConfidentialKernelSlotExpr::Binary { lhs, .. } => {
                        assert!(matches!(
                            lhs.as_ref(),
                            ConfidentialKernelSlotExpr::Slot { slot: 0 }
                        ));
                    }
                    other => panic!("unexpected slot-lowered declare expr: {other:?}"),
                }
            }
            other => panic!("unexpected first statement: {other:?}"),
        }
    }

    #[test]
    fn confidential_kernel_slot_program_rejects_duplicate_binding() {
        let function = CompiledFunction {
            signature: "dup(uint256)".into(),
            params: vec![("arg".into(), uint_type())],
            return_type: None,
            body: vec![Statement::Declare {
                name: "arg".into(),
                ty: uint_type(),
                value: Expr::Literal(Value::uint(1)),
            }],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        };

        let err = function
            .confidential_kernel_program()
            .unwrap()
            .to_slot_program()
            .unwrap_err();
        assert!(matches!(
            err,
            ConfidentialKernelSlotLoweringError::DuplicateBinding { .. }
        ));
    }

    #[test]
    fn confidential_kernel_slot_program_rejects_unknown_variable() {
        let function = CompiledFunction {
            signature: "unknown(uint256)".into(),
            params: vec![("arg".into(), uint_type())],
            return_type: None,
            body: vec![Statement::Assign {
                name: "missing".into(),
                value: Expr::Var("arg".into()),
            }],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        };

        let err = function
            .confidential_kernel_program()
            .unwrap()
            .to_slot_program()
            .unwrap_err();
        assert!(matches!(
            err,
            ConfidentialKernelSlotLoweringError::UnknownVariable { .. }
        ));
    }

    #[test]
    fn confidential_kernel_slot_program_normalizes_require_to_abort_if() {
        let function = CompiledFunction {
            signature: "guard(uint256)".into(),
            params: vec![("arg".into(), uint_type())],
            return_type: None,
            body: vec![Statement::Require {
                cond: Expr::Var("arg".into()),
            }],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        };

        let slot = function
            .confidential_kernel_program()
            .unwrap()
            .to_slot_program()
            .unwrap();

        assert!(slot.is_runtime_normal_form());
        assert!(matches!(
            slot.body.as_slice(),
            [ConfidentialKernelSlotStatement::AbortIf { .. }]
        ));
    }

    #[test]
    fn confidential_kernel_slot_expr_json_roundtrips_large_uint_literals() {
        let expr = ConfidentialKernelSlotExpr::Literal {
            value: Value::Uint((1u128 << 100) + 7),
        };
        let encoded = serde_json::to_vec(&expr).unwrap();
        let decoded: ConfidentialKernelSlotExpr = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(decoded, expr);
    }

    #[test]
    fn shared_slot_interpreter_executes_runtime_normal_form_program() {
        let mut runtime = MockRuntime::with_slot_count(2);
        runtime.store_slot(0, Value::Uint(5)).unwrap();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "demo(uint256)".into(),
            param_count: 1,
            return_type: Some(uint_type()),
            secret_args: vec![0],
            slot_count: 2,
            body: vec![
                ConfidentialKernelSlotStatement::Declare {
                    slot: 1,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Add,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Slot { slot: 0 }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::Uint(2),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::CellSet {
                    object_id: 7,
                    value: ConfidentialKernelSlotExpr::Slot { slot: 1 },
                    predicate: Some(ConfidentialKernelSlotExpr::Literal {
                        value: Value::Bool(true),
                    }),
                },
                ConfidentialKernelSlotStatement::Return {
                    value: Some(ConfidentialKernelSlotExpr::Slot { slot: 1 }),
                },
            ],
        };

        let outcome = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap();

        assert_eq!(
            outcome,
            ConfidentialKernelExecutionOutcome {
                aborted: false,
                return_value: Some(Value::Uint(7)),
            }
        );
        assert_eq!(runtime.load_slot(1).unwrap(), Value::Uint(7));
        assert_eq!(runtime.cell_sets, vec![(7, Value::Uint(7), Some(true))]);
        assert_eq!(runtime.statements, vec!["declare", "cell_set", "return"]);
    }

    #[test]
    fn shared_slot_interpreter_rejects_non_normalized_programs() {
        let mut runtime = MockRuntime::with_slot_count(1);
        runtime.store_slot(0, Value::Uint(1)).unwrap();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "guard(uint256)".into(),
            param_count: 1,
            return_type: None,
            secret_args: vec![0],
            slot_count: 1,
            body: vec![ConfidentialKernelSlotStatement::Require {
                cond: ConfidentialKernelSlotExpr::Literal {
                    value: Value::Bool(true),
                },
            }],
        };

        let err = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap_err();
        assert!(err.to_string().contains("not in runtime normal form"));
    }

    #[test]
    fn shared_slot_call_executor_stages_args_inside_uo_core() {
        let mut runtime = MockRuntime::default();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "demo(uint256)".into(),
            param_count: 1,
            return_type: Some(uint_type()),
            secret_args: vec![0],
            slot_count: 2,
            body: vec![
                ConfidentialKernelSlotStatement::Declare {
                    slot: 1,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Add,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Slot { slot: 0 }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::Uint(2),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::CellSet {
                    object_id: 7,
                    value: ConfidentialKernelSlotExpr::Slot { slot: 1 },
                    predicate: Some(ConfidentialKernelSlotExpr::Literal {
                        value: Value::Bool(true),
                    }),
                },
                ConfidentialKernelSlotStatement::Return {
                    value: Some(ConfidentialKernelSlotExpr::Slot { slot: 1 }),
                },
            ],
        };

        let outcome = execute_confidential_kernel_slot_call(
            &mut runtime,
            &program,
            ConfidentialCallInputs::from_raw_args(vec![Value::Uint(5)].into_boxed_slice()),
        )
        .unwrap();

        assert_eq!(
            outcome,
            ConfidentialKernelExecutionOutcome {
                aborted: false,
                return_value: Some(Value::Uint(7)),
            }
        );
        assert_eq!(runtime.cell_sets, vec![(7, Value::Uint(7), Some(true))]);
        assert_eq!(runtime.statements, vec!["declare", "cell_set", "return"]);
    }

    #[test]
    fn shared_slot_call_executor_rejects_confidential_arg_count_mismatch() {
        let mut runtime = MockRuntime::default();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "demo(uint256)".into(),
            param_count: 1,
            return_type: None,
            secret_args: vec![0],
            slot_count: 1,
            body: vec![ConfidentialKernelSlotStatement::Return { value: None }],
        };

        let err = execute_confidential_kernel_slot_call(
            &mut runtime,
            &program,
            ConfidentialCallInputs::from_raw_args(vec![].into_boxed_slice()),
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("expected 1 confidential arguments but runtime supplied 0"));

        let err = execute_confidential_kernel_slot_call(
            &mut runtime,
            &program,
            ConfidentialCallInputs::from_raw_args(
                vec![Value::Uint(1), Value::Uint(2)].into_boxed_slice(),
            ),
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("expected 1 confidential arguments but runtime supplied 2"));
    }

    #[test]
    fn max_keccak_part_canonical_len_tracks_largest_public_shape() {
        let function = CompiledFunction {
            signature: "hashy(uint256)".into(),
            params: vec![("arg".into(), uint_type())],
            return_type: Some(Type::Scalar(ScalarType::Bytes32)),
            body: vec![
                Statement::Declare {
                    name: "digest".into(),
                    ty: Type::Scalar(ScalarType::Bytes32),
                    value: Expr::Keccak256 {
                        parts: vec![
                            Expr::Var("arg".into()),
                            Expr::CellGet { object_id: 7 },
                            Expr::Literal(Value::Bytes32([1u8; 32])),
                        ],
                    },
                },
                Statement::Return {
                    value: Some(Expr::Var("digest".into())),
                },
            ],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        };

        let program = function.confidential_kernel_program().unwrap();
        assert_eq!(
            program
                .max_keccak_part_canonical_len_for_state(&[sample_cell_state_object()])
                .unwrap(),
            32
        );
    }
}
