use crate::fixed_buffer;
use crate::ir::{BinaryOp, CompiledFunction, Expr, StateObject, Statement, UnaryOp};
use crate::types::{FixedBoxBuilder, Type, Value};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, mem::MaybeUninit};
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
    pub body: Box<[ConfidentialKernelStatement]>,
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
    pub body: Box<[ConfidentialKernelSlotStatement]>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfidentialKernelStatementKind {
    Declare,
    Assign,
    Require,
    AbortIf,
    CellSet,
    ArraySet,
    MapPut,
    Return,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfidentialKernelStatementEffectKind {
    StoreSlot,
    GuardOnly,
    AbortFlag,
    CellSet,
    ArraySet,
    MapPut,
    ReturnValue,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConfidentialKernelStatementProfile {
    pub kind: ConfidentialKernelStatementKind,
    pub trace_name: &'static str,
    pub runtime_normal_form: bool,
    pub effect_kind: ConfidentialKernelStatementEffectKind,
    pub evaluated_operands: &'static [&'static str],
    pub tail_opcode: Option<UoOpcode>,
}

#[path = "generated_confidential_kernel.rs"]
mod generated_confidential_kernel;

pub use generated_confidential_kernel::{
    CONFIDENTIAL_KERNEL_EXPR_PROFILES, CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES,
    CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES, CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES,
    CONFIDENTIAL_KERNEL_STATEMENT_PROFILES,
};

impl ConfidentialKernelStatementKind {
    pub const fn as_str(self) -> &'static str {
        self.profile().trace_name
    }

    pub const fn profile(self) -> ConfidentialKernelStatementProfile {
        match self {
            Self::Declare => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[0],
            Self::Assign => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[1],
            Self::Require => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[2],
            Self::AbortIf => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[3],
            Self::CellSet => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[4],
            Self::ArraySet => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[5],
            Self::MapPut => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[6],
            Self::Return => CONFIDENTIAL_KERNEL_STATEMENT_PROFILES[7],
        }
    }

    pub const fn all_profiles() -> &'static [ConfidentialKernelStatementProfile; 8] {
        &CONFIDENTIAL_KERNEL_STATEMENT_PROFILES
    }
}

impl ConfidentialKernelStatementEffectKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::StoreSlot => "store_slot",
            Self::GuardOnly => "guard_only",
            Self::AbortFlag => "abort_flag",
            Self::CellSet => "cell_set",
            Self::ArraySet => "array_set",
            Self::MapPut => "map_put",
            Self::ReturnValue => "return_value",
        }
    }
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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfidentialKernelSlotExprKind {
    Literal,
    Slot,
    Unary,
    Binary,
    Select,
    CellGet,
    ArrayGet,
    MapGet,
    Keccak256,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConfidentialKernelSlotExprProfile {
    pub kind: ConfidentialKernelSlotExprKind,
    pub evaluated_operands: &'static [&'static str],
    pub tail_opcode: Option<UoOpcode>,
}

impl ConfidentialKernelSlotExprKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Literal => "literal",
            Self::Slot => "slot",
            Self::Unary => "unary",
            Self::Binary => "binary",
            Self::Select => "select",
            Self::CellGet => "cell_get",
            Self::ArrayGet => "array_get",
            Self::MapGet => "map_get",
            Self::Keccak256 => "keccak256",
        }
    }

    pub const fn profile(self) -> ConfidentialKernelSlotExprProfile {
        match self {
            Self::Literal => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[0],
            Self::Slot => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[1],
            Self::Unary => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[2],
            Self::Binary => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[3],
            Self::Select => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[4],
            Self::CellGet => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[5],
            Self::ArrayGet => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[6],
            Self::MapGet => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[7],
            Self::Keccak256 => CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES[8],
        }
    }

    pub const fn all_profiles() -> &'static [ConfidentialKernelSlotExprProfile; 9] {
        &CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfidentialKernelSlotPureExprKind {
    Literal,
    Slot,
    Unary,
    Binary,
    Select,
    Keccak256,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConfidentialKernelSlotPureExprProfile {
    pub kind: ConfidentialKernelSlotPureExprKind,
    pub evaluated_operands: &'static [&'static str],
}

impl ConfidentialKernelSlotPureExprKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Literal => "literal",
            Self::Slot => "slot",
            Self::Unary => "unary",
            Self::Binary => "binary",
            Self::Select => "select",
            Self::Keccak256 => "keccak256",
        }
    }

    pub const fn profile(self) -> ConfidentialKernelSlotPureExprProfile {
        match self {
            Self::Literal => CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES[0],
            Self::Slot => CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES[1],
            Self::Unary => CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES[2],
            Self::Binary => CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES[3],
            Self::Select => CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES[4],
            Self::Keccak256 => CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES[5],
        }
    }

    pub const fn all_profiles() -> &'static [ConfidentialKernelSlotPureExprProfile; 6] {
        &CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfidentialKernelExprKind {
    Literal,
    Var,
    Unary,
    Binary,
    Select,
    CellGet,
    ArrayGet,
    MapGet,
    Keccak256,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConfidentialKernelExprProfile {
    pub kind: ConfidentialKernelExprKind,
    pub evaluated_operands: &'static [&'static str],
    pub tail_opcode: Option<UoOpcode>,
}

impl ConfidentialKernelExprKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Literal => "literal",
            Self::Var => "var",
            Self::Unary => "unary",
            Self::Binary => "binary",
            Self::Select => "select",
            Self::CellGet => "cell_get",
            Self::ArrayGet => "array_get",
            Self::MapGet => "map_get",
            Self::Keccak256 => "keccak256",
        }
    }

    pub const fn profile(self) -> ConfidentialKernelExprProfile {
        match self {
            Self::Literal => CONFIDENTIAL_KERNEL_EXPR_PROFILES[0],
            Self::Var => CONFIDENTIAL_KERNEL_EXPR_PROFILES[1],
            Self::Unary => CONFIDENTIAL_KERNEL_EXPR_PROFILES[2],
            Self::Binary => CONFIDENTIAL_KERNEL_EXPR_PROFILES[3],
            Self::Select => CONFIDENTIAL_KERNEL_EXPR_PROFILES[4],
            Self::CellGet => CONFIDENTIAL_KERNEL_EXPR_PROFILES[5],
            Self::ArrayGet => CONFIDENTIAL_KERNEL_EXPR_PROFILES[6],
            Self::MapGet => CONFIDENTIAL_KERNEL_EXPR_PROFILES[7],
            Self::Keccak256 => CONFIDENTIAL_KERNEL_EXPR_PROFILES[8],
        }
    }

    pub const fn all_profiles() -> &'static [ConfidentialKernelExprProfile; 9] {
        &CONFIDENTIAL_KERNEL_EXPR_PROFILES
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConfidentialKernelPureExprKind {
    Literal,
    Var,
    Unary,
    Binary,
    Select,
    Keccak256,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ConfidentialKernelPureExprProfile {
    pub kind: ConfidentialKernelPureExprKind,
    pub evaluated_operands: &'static [&'static str],
}

impl ConfidentialKernelPureExprKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Literal => "literal",
            Self::Var => "var",
            Self::Unary => "unary",
            Self::Binary => "binary",
            Self::Select => "select",
            Self::Keccak256 => "keccak256",
        }
    }

    pub const fn profile(self) -> ConfidentialKernelPureExprProfile {
        match self {
            Self::Literal => CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES[0],
            Self::Var => CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES[1],
            Self::Unary => CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES[2],
            Self::Binary => CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES[3],
            Self::Select => CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES[4],
            Self::Keccak256 => CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES[5],
        }
    }

    pub const fn all_profiles() -> &'static [ConfidentialKernelPureExprProfile; 6] {
        &CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES
    }
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
        parts: Box<[ConfidentialKernelExpr]>,
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
        parts: Box<[ConfidentialKernelSlotExpr]>,
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
        parts: Box<[ConfidentialKernelPureExpr]>,
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
        parts: Box<[ConfidentialKernelSlotPureExpr]>,
    },
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialKernelStep {
    pub opcode: UoOpcode,
    #[serde(default)]
    pub object_id: Option<u32>,
}

struct FixedKernelStepBuffer {
    steps: Box<[MaybeUninit<ConfidentialKernelStep>]>,
    len: usize,
}

impl FixedKernelStepBuffer {
    fn new(capacity: usize) -> Self {
        Self {
            steps: Box::<[ConfidentialKernelStep]>::new_uninit_slice(capacity),
            len: 0,
        }
    }

    fn push(&mut self, step: ConfidentialKernelStep) {
        if let Some(slot) = self.steps.get_mut(self.len) {
            slot.write(step);
            self.len += 1;
        }
    }

    fn finish(mut self) -> Box<[ConfidentialKernelStep]> {
        let out = fixed_buffer::move_initialized_prefix_to_box(&mut self.steps, self.len);
        self.len = 0;
        out
    }
}

impl Drop for FixedKernelStepBuffer {
    fn drop(&mut self) {
        fixed_buffer::drop_initialized_prefix(&mut self.steps, self.len);
    }
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
    #[error(
        "confidential entrypoint {entrypoint} contains statement {index} after a return; returns must be final in the admitted public schedule"
    )]
    NonFinalReturn { entrypoint: String, index: usize },
    #[error(
        "confidential entrypoint {entrypoint} fixed lowering buffer invariant failed: {detail}"
    )]
    FixedBufferInvariant { entrypoint: String, detail: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum ConfidentialKernelSlotLoweringError {
    #[error("slot-lowered confidential kernel program requires a valid confidential kernel program: {0}")]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error("confidential entrypoint {entrypoint} declares duplicate variable '{name}'")]
    DuplicateBinding { entrypoint: String, name: String },
    #[error("confidential entrypoint {entrypoint} refers to unknown variable '{name}'")]
    UnknownVariable { entrypoint: String, name: String },
    #[error(
        "confidential entrypoint {entrypoint} fixed slot-lowering buffer invariant failed: {detail}"
    )]
    FixedBufferInvariant { entrypoint: String, detail: String },
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

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<(Value, bool)>;

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<bool>;

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

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<(Value, bool)>;

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<bool>;

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value>;
}

fn collect_confidential_hash_parts(
    len: usize,
    parts: impl IntoIterator<Item = Result<Value>>,
) -> Result<Box<[Value]>> {
    let mut values = FixedBoxBuilder::new(len);
    for part in parts {
        values.push(part?)?;
    }
    values.finish()
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
    return_value: Option<Value>,
}

pub fn execute_confidential_kernel_slot_program<R: ConfidentialKernelSlotRuntime>(
    runtime: &mut R,
    program: &ConfidentialKernelSlotProgram,
) -> Result<ConfidentialKernelExecutionOutcome> {
    generated_confidential_kernel::execute_confidential_kernel_slot_program_generated(
        runtime, program,
    )
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
    pub fn runtime_step_count(&self) -> usize {
        1 + self
            .body
            .iter()
            .map(ConfidentialKernelStatement::kernel_step_count)
            .sum::<usize>()
            + 2
    }

    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = FixedKernelStepBuffer::new(self.runtime_step_count());
        steps.push(ConfidentialKernelStep {
            opcode: UoOpcode::Begin,
            object_id: None,
        });
        for statement in &self.body {
            statement.collect_kernel_steps(&mut steps);
        }
        steps.push(ConfidentialKernelStep {
            opcode: UoOpcode::Commit,
            object_id: None,
        });
        steps.push(ConfidentialKernelStep {
            opcode: UoOpcode::Wipe,
            object_id: None,
        });
        steps.finish()
    }

    pub fn to_slot_program(
        &self,
    ) -> Result<ConfidentialKernelSlotProgram, ConfidentialKernelSlotLoweringError> {
        let mut layout = ConfidentialKernelSlotLayout::new(&self.entrypoint_id, &self.params)?;
        let mut body = FixedBoxBuilder::new(self.body.len());
        for statement in self.body.iter() {
            body.push(statement.to_slot_statement(&mut layout)?)
                .map_err(
                    |error| ConfidentialKernelSlotLoweringError::FixedBufferInvariant {
                        entrypoint: self.entrypoint_id.clone(),
                        detail: error.to_string(),
                    },
                )?;
        }
        Ok(ConfidentialKernelSlotProgram {
            entrypoint_id: self.entrypoint_id.clone(),
            param_count: self.params.len(),
            return_type: self.return_type.clone(),
            secret_args: self.secret_args.clone(),
            slot_count: layout.slot_count(),
            body: body.finish().map_err(|error| {
                ConfidentialKernelSlotLoweringError::FixedBufferInvariant {
                    entrypoint: self.entrypoint_id.clone(),
                    detail: error.to_string(),
                }
            })?,
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
    pub fn runtime_step_count(&self) -> usize {
        1 + self
            .body
            .iter()
            .map(ConfidentialKernelSlotStatement::kernel_step_count)
            .sum::<usize>()
            + 2
    }

    pub fn statement_trace(&self) -> Box<[String]> {
        let mut statements = self.body.iter();
        FixedBoxBuilder::from_fn(self.body.len(), |_| {
            statements
                .next()
                .map(|statement| statement.trace_name().to_owned())
                .unwrap_or_default()
        })
    }

    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = FixedKernelStepBuffer::new(self.runtime_step_count());
        steps.push(ConfidentialKernelStep {
            opcode: UoOpcode::Begin,
            object_id: None,
        });
        for statement in &self.body {
            statement.collect_kernel_steps(&mut steps);
        }
        steps.push(ConfidentialKernelStep {
            opcode: UoOpcode::Commit,
            object_id: None,
        });
        steps.push(ConfidentialKernelStep {
            opcode: UoOpcode::Wipe,
            object_id: None,
        });
        steps.finish()
    }

    pub fn is_runtime_normal_form(&self) -> bool {
        let mut saw_return = false;
        for statement in &self.body {
            if saw_return || !statement.is_runtime_normal_form() {
                return false;
            }
            saw_return = matches!(statement, ConfidentialKernelSlotStatement::Return { .. });
        }
        true
    }
}

impl ConfidentialKernelStatement {
    pub fn kind(&self) -> ConfidentialKernelStatementKind {
        match self {
            Self::Declare { .. } => ConfidentialKernelStatementKind::Declare,
            Self::Assign { .. } => ConfidentialKernelStatementKind::Assign,
            Self::Require { .. } => ConfidentialKernelStatementKind::Require,
            Self::AbortIf { .. } => ConfidentialKernelStatementKind::AbortIf,
            Self::CellSet { .. } => ConfidentialKernelStatementKind::CellSet,
            Self::ArraySet { .. } => ConfidentialKernelStatementKind::ArraySet,
            Self::MapPut { .. } => ConfidentialKernelStatementKind::MapPut,
            Self::Return { .. } => ConfidentialKernelStatementKind::Return,
        }
    }

    pub fn profile(&self) -> ConfidentialKernelStatementProfile {
        self.kind().profile()
    }

    pub fn trace_name(&self) -> &'static str {
        self.profile().trace_name
    }

    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = FixedKernelStepBuffer::new(self.kernel_step_count());
        self.collect_kernel_steps(&mut steps);
        steps.finish()
    }

    pub fn kernel_step_count(&self) -> usize {
        let operand_count = match self {
            Self::Declare { value, .. } | Self::Assign { value, .. } => value.kernel_step_count(),
            Self::Require { cond } | Self::AbortIf { cond } => cond.kernel_step_count(),
            Self::CellSet {
                value, predicate, ..
            } => {
                value.kernel_step_count()
                    + predicate
                        .as_ref()
                        .map(ConfidentialKernelExpr::kernel_step_count)
                        .unwrap_or(0)
            }
            Self::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                index.kernel_step_count()
                    + value.kernel_step_count()
                    + predicate
                        .as_ref()
                        .map(ConfidentialKernelExpr::kernel_step_count)
                        .unwrap_or(0)
            }
            Self::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                key.kernel_step_count()
                    + value.kernel_step_count()
                    + predicate
                        .as_ref()
                        .map(ConfidentialKernelExpr::kernel_step_count)
                        .unwrap_or(0)
            }
            Self::Return { value } => value
                .as_ref()
                .map(ConfidentialKernelExpr::kernel_step_count)
                .unwrap_or(0),
        };
        operand_count + usize::from(self.storage_opcode().is_some())
    }

    pub fn effect_kind(&self) -> ConfidentialKernelStatementEffectKind {
        self.profile().effect_kind
    }

    pub fn storage_opcode(&self) -> Option<UoOpcode> {
        self.profile().tail_opcode
    }

    fn tail_object_id(&self) -> Option<u32> {
        match self {
            Self::CellSet { object_id, .. }
            | Self::ArraySet { object_id, .. }
            | Self::MapPut { object_id, .. } => Some(*object_id),
            Self::Declare { .. }
            | Self::Assign { .. }
            | Self::Require { .. }
            | Self::AbortIf { .. }
            | Self::Return { .. } => None,
        }
    }

    fn collect_kernel_steps(&self, steps: &mut FixedKernelStepBuffer) {
        match self {
            Self::Declare { value, .. } | Self::Assign { value, .. } => {
                value.collect_kernel_steps(steps);
            }
            Self::Require { cond } | Self::AbortIf { cond } => {
                cond.collect_kernel_steps(steps);
            }
            Self::CellSet {
                value, predicate, ..
            } => {
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
            }
            Self::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                index.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
            }
            Self::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                key.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
            }
            Self::Return { value } => {
                if let Some(value) = value {
                    value.collect_kernel_steps(steps);
                }
            }
        }
        if let Some(opcode) = self.storage_opcode() {
            steps.push(ConfidentialKernelStep {
                opcode,
                object_id: self.tail_object_id(),
            });
        }
    }
}

impl ConfidentialKernelSlotStatement {
    pub fn is_runtime_normal_form(&self) -> bool {
        self.profile().runtime_normal_form
    }

    pub fn kind(&self) -> ConfidentialKernelStatementKind {
        match self {
            Self::Declare { .. } => ConfidentialKernelStatementKind::Declare,
            Self::Assign { .. } => ConfidentialKernelStatementKind::Assign,
            Self::Require { .. } => ConfidentialKernelStatementKind::Require,
            Self::AbortIf { .. } => ConfidentialKernelStatementKind::AbortIf,
            Self::CellSet { .. } => ConfidentialKernelStatementKind::CellSet,
            Self::ArraySet { .. } => ConfidentialKernelStatementKind::ArraySet,
            Self::MapPut { .. } => ConfidentialKernelStatementKind::MapPut,
            Self::Return { .. } => ConfidentialKernelStatementKind::Return,
        }
    }

    pub fn profile(&self) -> ConfidentialKernelStatementProfile {
        self.kind().profile()
    }

    pub fn trace_name(&self) -> &'static str {
        self.profile().trace_name
    }

    pub fn expected_runtime_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = FixedKernelStepBuffer::new(self.kernel_step_count());
        self.collect_kernel_steps(&mut steps);
        steps.finish()
    }

    pub fn kernel_step_count(&self) -> usize {
        let operand_count = match self {
            Self::Declare { value, .. } | Self::Assign { value, .. } => value.kernel_step_count(),
            Self::Require { cond } | Self::AbortIf { cond } => cond.kernel_step_count(),
            Self::CellSet {
                value, predicate, ..
            } => {
                value.kernel_step_count()
                    + predicate
                        .as_ref()
                        .map(ConfidentialKernelSlotExpr::kernel_step_count)
                        .unwrap_or(0)
            }
            Self::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                index.kernel_step_count()
                    + value.kernel_step_count()
                    + predicate
                        .as_ref()
                        .map(ConfidentialKernelSlotExpr::kernel_step_count)
                        .unwrap_or(0)
            }
            Self::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                key.kernel_step_count()
                    + value.kernel_step_count()
                    + predicate
                        .as_ref()
                        .map(ConfidentialKernelSlotExpr::kernel_step_count)
                        .unwrap_or(0)
            }
            Self::Return { value } => value
                .as_ref()
                .map(ConfidentialKernelSlotExpr::kernel_step_count)
                .unwrap_or(0),
        };
        operand_count + usize::from(self.storage_opcode().is_some())
    }

    pub fn effect_kind(&self) -> ConfidentialKernelStatementEffectKind {
        self.profile().effect_kind
    }

    pub fn storage_opcode(&self) -> Option<UoOpcode> {
        self.profile().tail_opcode
    }

    fn tail_object_id(&self) -> Option<u32> {
        match self {
            Self::CellSet { object_id, .. }
            | Self::ArraySet { object_id, .. }
            | Self::MapPut { object_id, .. } => Some(*object_id),
            Self::Declare { .. }
            | Self::Assign { .. }
            | Self::Require { .. }
            | Self::AbortIf { .. }
            | Self::Return { .. } => None,
        }
    }

    fn collect_kernel_steps(&self, steps: &mut FixedKernelStepBuffer) {
        match self {
            Self::Declare { value, .. } | Self::Assign { value, .. } => {
                value.collect_kernel_steps(steps);
            }
            Self::Require { cond } | Self::AbortIf { cond } => {
                cond.collect_kernel_steps(steps);
            }
            Self::CellSet {
                value, predicate, ..
            } => {
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
            }
            Self::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                index.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
            }
            Self::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                key.collect_kernel_steps(steps);
                value.collect_kernel_steps(steps);
                if let Some(predicate) = predicate {
                    predicate.collect_kernel_steps(steps);
                }
            }
            Self::Return { value } => {
                if let Some(value) = value {
                    value.collect_kernel_steps(steps);
                }
            }
        }
        if let Some(opcode) = self.storage_opcode() {
            steps.push(ConfidentialKernelStep {
                opcode,
                object_id: self.tail_object_id(),
            });
        }
    }
}

impl ConfidentialKernelExpr {
    pub fn kind(&self) -> ConfidentialKernelExprKind {
        match self {
            Self::Literal { .. } => ConfidentialKernelExprKind::Literal,
            Self::Var { .. } => ConfidentialKernelExprKind::Var,
            Self::Unary { .. } => ConfidentialKernelExprKind::Unary,
            Self::Binary { .. } => ConfidentialKernelExprKind::Binary,
            Self::Select { .. } => ConfidentialKernelExprKind::Select,
            Self::CellGet { .. } => ConfidentialKernelExprKind::CellGet,
            Self::ArrayGet { .. } => ConfidentialKernelExprKind::ArrayGet,
            Self::MapGet { .. } => ConfidentialKernelExprKind::MapGet,
            Self::Keccak256 { .. } => ConfidentialKernelExprKind::Keccak256,
        }
    }

    pub fn profile(&self) -> ConfidentialKernelExprProfile {
        self.kind().profile()
    }

    pub fn kernel_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = FixedKernelStepBuffer::new(self.kernel_step_count());
        self.collect_kernel_steps(&mut steps);
        steps.finish()
    }

    pub fn kernel_step_count(&self) -> usize {
        let operand_count = match self {
            Self::Literal { .. } | Self::Var { .. } => 0,
            Self::Unary { expr, .. } => expr.kernel_step_count(),
            Self::Binary { lhs, rhs, .. } => lhs.kernel_step_count() + rhs.kernel_step_count(),
            Self::Select { cond, .. } => cond.kernel_step_count(),
            Self::CellGet { .. } => 0,
            Self::ArrayGet { index, .. } => index.kernel_step_count(),
            Self::MapGet { key, .. } => key.kernel_step_count(),
            Self::Keccak256 { parts } => parts
                .iter()
                .map(ConfidentialKernelExpr::kernel_step_count)
                .sum(),
        };
        operand_count + usize::from(self.storage_opcode().is_some())
    }

    pub fn storage_opcode(&self) -> Option<UoOpcode> {
        self.profile().tail_opcode
    }

    fn tail_object_id(&self) -> Option<u32> {
        match self {
            Self::CellGet { object_id }
            | Self::ArrayGet { object_id, .. }
            | Self::MapGet { object_id, .. } => Some(*object_id),
            Self::Literal { .. }
            | Self::Var { .. }
            | Self::Unary { .. }
            | Self::Binary { .. }
            | Self::Select { .. }
            | Self::Keccak256 { .. } => None,
        }
    }

    fn collect_kernel_steps(&self, steps: &mut FixedKernelStepBuffer) {
        match self {
            Self::Literal { .. } | Self::Var { .. } => {}
            Self::Unary { expr, .. } => expr.collect_kernel_steps(steps),
            Self::Binary { lhs, rhs, .. } => {
                lhs.collect_kernel_steps(steps);
                rhs.collect_kernel_steps(steps);
            }
            Self::Select { cond, .. } => cond.collect_kernel_steps(steps),
            Self::CellGet { .. } => {}
            Self::ArrayGet { index, .. } => {
                index.collect_kernel_steps(steps);
            }
            Self::MapGet { key, .. } => {
                key.collect_kernel_steps(steps);
            }
            Self::Keccak256 { parts } => {
                for part in parts {
                    part.collect_kernel_steps(steps);
                }
            }
        }
        if let Some(opcode) = self.storage_opcode() {
            steps.push(ConfidentialKernelStep {
                opcode,
                object_id: self.tail_object_id(),
            });
        }
    }
}

impl ConfidentialKernelSlotExpr {
    pub fn kind(&self) -> ConfidentialKernelSlotExprKind {
        match self {
            Self::Literal { .. } => ConfidentialKernelSlotExprKind::Literal,
            Self::Slot { .. } => ConfidentialKernelSlotExprKind::Slot,
            Self::Unary { .. } => ConfidentialKernelSlotExprKind::Unary,
            Self::Binary { .. } => ConfidentialKernelSlotExprKind::Binary,
            Self::Select { .. } => ConfidentialKernelSlotExprKind::Select,
            Self::CellGet { .. } => ConfidentialKernelSlotExprKind::CellGet,
            Self::ArrayGet { .. } => ConfidentialKernelSlotExprKind::ArrayGet,
            Self::MapGet { .. } => ConfidentialKernelSlotExprKind::MapGet,
            Self::Keccak256 { .. } => ConfidentialKernelSlotExprKind::Keccak256,
        }
    }

    pub fn profile(&self) -> ConfidentialKernelSlotExprProfile {
        self.kind().profile()
    }

    pub fn kernel_steps(&self) -> Box<[ConfidentialKernelStep]> {
        let mut steps = FixedKernelStepBuffer::new(self.kernel_step_count());
        self.collect_kernel_steps(&mut steps);
        steps.finish()
    }

    pub fn kernel_step_count(&self) -> usize {
        let operand_count = match self {
            Self::Literal { .. } | Self::Slot { .. } => 0,
            Self::Unary { expr, .. } => expr.kernel_step_count(),
            Self::Binary { lhs, rhs, .. } => lhs.kernel_step_count() + rhs.kernel_step_count(),
            Self::Select { cond, .. } => cond.kernel_step_count(),
            Self::CellGet { .. } => 0,
            Self::ArrayGet { index, .. } => index.kernel_step_count(),
            Self::MapGet { key, .. } => key.kernel_step_count(),
            Self::Keccak256 { parts } => parts
                .iter()
                .map(ConfidentialKernelSlotExpr::kernel_step_count)
                .sum(),
        };
        operand_count + usize::from(self.storage_opcode().is_some())
    }

    pub fn storage_opcode(&self) -> Option<UoOpcode> {
        self.profile().tail_opcode
    }

    fn tail_object_id(&self) -> Option<u32> {
        match self {
            Self::CellGet { object_id }
            | Self::ArrayGet { object_id, .. }
            | Self::MapGet { object_id, .. } => Some(*object_id),
            Self::Literal { .. }
            | Self::Slot { .. }
            | Self::Unary { .. }
            | Self::Binary { .. }
            | Self::Select { .. }
            | Self::Keccak256 { .. } => None,
        }
    }

    fn collect_kernel_steps(&self, steps: &mut FixedKernelStepBuffer) {
        match self {
            Self::Literal { .. } | Self::Slot { .. } => {}
            Self::Unary { expr, .. } => expr.collect_kernel_steps(steps),
            Self::Binary { lhs, rhs, .. } => {
                lhs.collect_kernel_steps(steps);
                rhs.collect_kernel_steps(steps);
            }
            Self::Select { cond, .. } => cond.collect_kernel_steps(steps),
            Self::CellGet { .. } => {}
            Self::ArrayGet { index, .. } => {
                index.collect_kernel_steps(steps);
            }
            Self::MapGet { key, .. } => {
                key.collect_kernel_steps(steps);
            }
            Self::Keccak256 { parts } => {
                for part in parts {
                    part.collect_kernel_steps(steps);
                }
            }
        }
        if let Some(opcode) = self.storage_opcode() {
            steps.push(ConfidentialKernelStep {
                opcode,
                object_id: self.tail_object_id(),
            });
        }
    }
}

impl ConfidentialKernelSlotPureExpr {
    pub fn kind(&self) -> ConfidentialKernelSlotPureExprKind {
        match self {
            Self::Literal { .. } => ConfidentialKernelSlotPureExprKind::Literal,
            Self::Slot { .. } => ConfidentialKernelSlotPureExprKind::Slot,
            Self::Unary { .. } => ConfidentialKernelSlotPureExprKind::Unary,
            Self::Binary { .. } => ConfidentialKernelSlotPureExprKind::Binary,
            Self::Select { .. } => ConfidentialKernelSlotPureExprKind::Select,
            Self::Keccak256 { .. } => ConfidentialKernelSlotPureExprKind::Keccak256,
        }
    }

    pub fn profile(&self) -> ConfidentialKernelSlotPureExprProfile {
        self.kind().profile()
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
    pub fn kind(&self) -> ConfidentialKernelPureExprKind {
        match self {
            Self::Literal { .. } => ConfidentialKernelPureExprKind::Literal,
            Self::Var { .. } => ConfidentialKernelPureExprKind::Var,
            Self::Unary { .. } => ConfidentialKernelPureExprKind::Unary,
            Self::Binary { .. } => ConfidentialKernelPureExprKind::Binary,
            Self::Select { .. } => ConfidentialKernelPureExprKind::Select,
            Self::Keccak256 { .. } => ConfidentialKernelPureExprKind::Keccak256,
        }
    }

    pub fn profile(&self) -> ConfidentialKernelPureExprProfile {
        self.kind().profile()
    }

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
            Self::Keccak256 { parts } => {
                let mut lowered = FixedBoxBuilder::new(parts.len());
                for part in parts.iter() {
                    lowered.push(part.to_slot_expr(layout)?).map_err(|error| {
                        ConfidentialKernelSlotLoweringError::FixedBufferInvariant {
                            entrypoint: layout.entrypoint.clone(),
                            detail: error.to_string(),
                        }
                    })?;
                }
                Ok(ConfidentialKernelSlotExpr::Keccak256 {
                    parts: lowered.finish().map_err(|error| {
                        ConfidentialKernelSlotLoweringError::FixedBufferInvariant {
                            entrypoint: layout.entrypoint.clone(),
                            detail: error.to_string(),
                        }
                    })?,
                })
            }
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
            Self::Keccak256 { parts } => {
                let mut lowered = FixedBoxBuilder::new(parts.len());
                for part in parts.iter() {
                    lowered
                        .push(part.to_slot_pure_expr(layout)?)
                        .map_err(|error| {
                            ConfidentialKernelSlotLoweringError::FixedBufferInvariant {
                                entrypoint: layout.entrypoint.clone(),
                                detail: error.to_string(),
                            }
                        })?;
                }
                Ok(ConfidentialKernelSlotPureExpr::Keccak256 {
                    parts: lowered.finish().map_err(|error| {
                        ConfidentialKernelSlotLoweringError::FixedBufferInvariant {
                            entrypoint: layout.entrypoint.clone(),
                            detail: error.to_string(),
                        }
                    })?,
                })
            }
        }
    }
}

pub fn lower_confidential_kernel_statements(
    statements: &[Statement],
    entrypoint: &str,
) -> Result<Box<[ConfidentialKernelStatement]>, ConfidentialKernelLoweringError> {
    let mut lowered = FixedBoxBuilder::new(statements.len());
    let mut saw_return = false;
    for (index, statement) in statements.iter().enumerate() {
        if saw_return {
            return Err(ConfidentialKernelLoweringError::NonFinalReturn {
                entrypoint: entrypoint.into(),
                index,
            });
        }
        saw_return = matches!(statement, Statement::Return { .. });
        lowered
            .push(lower_confidential_kernel_statement(
                statement, entrypoint, index,
            )?)
            .map_err(
                |error| ConfidentialKernelLoweringError::FixedBufferInvariant {
                    entrypoint: entrypoint.into(),
                    detail: error.to_string(),
                },
            )?;
    }
    Ok(lowered.finish().map_err(
        |error| ConfidentialKernelLoweringError::FixedBufferInvariant {
            entrypoint: entrypoint.into(),
            detail: error.to_string(),
        },
    )?)
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
        Expr::Keccak256 { parts } => {
            let mut lowered = FixedBoxBuilder::new(parts.len());
            for part in parts.iter() {
                lowered
                    .push(lower_confidential_kernel_expr(part, entrypoint)?)
                    .map_err(
                        |error| ConfidentialKernelLoweringError::FixedBufferInvariant {
                            entrypoint: entrypoint.into(),
                            detail: error.to_string(),
                        },
                    )?;
            }
            Ok(ConfidentialKernelExpr::Keccak256 {
                parts: lowered.finish().map_err(|error| {
                    ConfidentialKernelLoweringError::FixedBufferInvariant {
                        entrypoint: entrypoint.into(),
                        detail: error.to_string(),
                    }
                })?,
            })
        }
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
        Expr::Keccak256 { parts } => {
            let mut lowered = FixedBoxBuilder::new(parts.len());
            for part in parts.iter() {
                lowered
                    .push(lower_confidential_kernel_pure_expr(part, entrypoint)?)
                    .map_err(
                        |error| ConfidentialKernelLoweringError::FixedBufferInvariant {
                            entrypoint: entrypoint.into(),
                            detail: error.to_string(),
                        },
                    )?;
            }
            Ok(ConfidentialKernelPureExpr::Keccak256 {
                parts: lowered.finish().map_err(|error| {
                    ConfidentialKernelLoweringError::FixedBufferInvariant {
                        entrypoint: entrypoint.into(),
                        detail: error.to_string(),
                    }
                })?,
            })
        }
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
        execute_confidential_kernel_slot_program, ConfidentialKernelExecutionOutcome,
        ConfidentialKernelSlotExpr, ConfidentialKernelSlotLoweringError,
        ConfidentialKernelSlotProgram, ConfidentialKernelSlotRuntime,
        ConfidentialKernelSlotStatement,
    };
    use crate::{
        ir::StateObject, BackendKind, BinaryOp, CompiledFunction, ContainerKind, Expr, ScalarType,
        Statement, Type, Uint256, UnaryOp, Value,
    };
    use anyhow::{anyhow, Result};
    use uo_precompiles::UoOpcode;

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

        fn map_get(&mut self, object_id: u32, key: &Value) -> Result<(Value, bool)> {
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
        ) -> Result<bool> {
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
    fn confidential_kernel_expected_steps_use_exact_public_step_count() {
        let function = sample_confidential_function();
        let named = function.confidential_kernel_program().unwrap();
        let slot = named.to_slot_program().unwrap();

        let named_steps = named.expected_runtime_steps();
        let slot_steps = slot.expected_runtime_steps();
        assert_eq!(named.runtime_step_count(), named_steps.len());
        assert_eq!(slot.runtime_step_count(), slot_steps.len());
        assert_eq!(named_steps, slot_steps);
        assert_eq!(named_steps[0].opcode, UoOpcode::Begin);
        assert_eq!(named_steps[1].opcode, UoOpcode::CellSet);
        assert_eq!(named_steps[2].opcode, UoOpcode::Commit);
        assert_eq!(named_steps[3].opcode, UoOpcode::Wipe);

        for statement in &slot.body {
            assert_eq!(
                statement.kernel_step_count(),
                statement.expected_runtime_steps().len()
            );
        }

        let expr = ConfidentialKernelSlotExpr::Keccak256 {
            parts: vec![
                ConfidentialKernelSlotExpr::CellGet { object_id: 7 },
                ConfidentialKernelSlotExpr::ArrayGet {
                    object_id: 8,
                    index: Box::new(ConfidentialKernelSlotExpr::Literal {
                        value: Value::uint(0),
                    }),
                },
                ConfidentialKernelSlotExpr::MapGet {
                    object_id: 9,
                    key: Box::new(ConfidentialKernelSlotExpr::CellGet { object_id: 10 }),
                },
            ]
            .into_boxed_slice(),
        };
        let expr_steps = expr.kernel_steps();
        assert_eq!(expr.kernel_step_count(), expr_steps.len());
        assert_eq!(
            expr_steps
                .iter()
                .map(|step| step.opcode)
                .collect::<Vec<_>>(),
            vec![
                UoOpcode::CellGet,
                UoOpcode::ArrayGet,
                UoOpcode::CellGet,
                UoOpcode::MapGet
            ]
        );
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
            slot.body.as_ref(),
            [ConfidentialKernelSlotStatement::AbortIf { .. }]
        ));
    }

    #[test]
    fn confidential_kernel_slot_expr_json_roundtrips_large_uint_literals() {
        let expr = ConfidentialKernelSlotExpr::Literal {
            value: Value::uint((1u128 << 100) + 7),
        };
        let encoded = serde_json::to_vec(&expr).unwrap();
        let decoded: ConfidentialKernelSlotExpr = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(decoded, expr);
    }

    #[test]
    fn shared_slot_interpreter_executes_runtime_normal_form_program() {
        let mut runtime = MockRuntime::with_slot_count(2);
        runtime.store_slot(0, Value::uint(5)).unwrap();
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
                            value: Value::uint(2),
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
            ]
            .into_boxed_slice(),
        };

        let outcome = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap();

        assert_eq!(
            outcome,
            ConfidentialKernelExecutionOutcome {
                aborted: false,
                return_value: Some(Value::uint(7)),
            }
        );
        assert_eq!(runtime.load_slot(1).unwrap(), Value::uint(7));
        assert_eq!(runtime.cell_sets, vec![(7, Value::uint(7), Some(true))]);
        assert_eq!(runtime.statements, vec!["declare", "cell_set", "return"]);
    }

    #[test]
    fn shared_slot_interpreter_uses_uint256_evm_arithmetic() {
        let mut runtime = MockRuntime::with_slot_count(5);
        let high_bit = Uint256::from_hex_str(
            "8000000000000000000000000000000000000000000000000000000000000000",
        )
        .unwrap();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "arithmetic()".into(),
            param_count: 0,
            return_type: Some(uint_type()),
            secret_args: vec![],
            slot_count: 5,
            body: vec![
                ConfidentialKernelSlotStatement::Declare {
                    slot: 0,
                    value: ConfidentialKernelSlotExpr::Unary {
                        op: UnaryOp::Neg,
                        expr: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(1),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::Declare {
                    slot: 1,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Add,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(Uint256::MAX),
                        }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(1),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::Declare {
                    slot: 2,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Sub,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(0),
                        }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(1),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::Declare {
                    slot: 3,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Mul,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(high_bit),
                        }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(2),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::Declare {
                    slot: 4,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Div,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(7),
                        }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(0),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::Return {
                    value: Some(ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Mod,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(7),
                        }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(0),
                        }),
                    }),
                },
            ]
            .into_boxed_slice(),
        };

        let outcome = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap();

        assert_eq!(runtime.load_slot(0).unwrap(), Value::uint(Uint256::MAX));
        assert_eq!(runtime.load_slot(1).unwrap(), Value::uint(0));
        assert_eq!(runtime.load_slot(2).unwrap(), Value::uint(Uint256::MAX));
        assert_eq!(runtime.load_slot(3).unwrap(), Value::uint(0));
        assert_eq!(runtime.load_slot(4).unwrap(), Value::uint(0));
        assert_eq!(
            outcome,
            ConfidentialKernelExecutionOutcome {
                aborted: false,
                return_value: Some(Value::uint(0)),
            }
        );
    }

    #[test]
    fn shared_slot_interpreter_rejects_non_normalized_programs() {
        let mut runtime = MockRuntime::with_slot_count(1);
        runtime.store_slot(0, Value::uint(1)).unwrap();
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
            }]
            .into_boxed_slice(),
        };

        let err = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap_err();
        assert!(err.to_string().contains("not in runtime normal form"));
    }

    #[test]
    fn shared_slot_interpreter_rejects_non_final_return_schedule() {
        let mut runtime = MockRuntime::with_slot_count(1);
        runtime.store_slot(0, Value::uint(1)).unwrap();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "early_return(uint256)".into(),
            param_count: 1,
            return_type: Some(uint_type()),
            secret_args: vec![0],
            slot_count: 1,
            body: vec![
                ConfidentialKernelSlotStatement::Return {
                    value: Some(ConfidentialKernelSlotExpr::Slot { slot: 0 }),
                },
                ConfidentialKernelSlotStatement::Assign {
                    slot: 0,
                    value: ConfidentialKernelSlotExpr::Literal {
                        value: Value::uint(2),
                    },
                },
            ]
            .into_boxed_slice(),
        };

        let err = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap_err();
        assert!(err.to_string().contains("not in runtime normal form"));
        assert!(runtime.statements.is_empty());
    }

    #[test]
    fn shared_slot_interpreter_tracks_abort_without_schedule_drift() {
        let mut runtime = MockRuntime::with_slot_count(1);
        runtime.store_slot(0, Value::Bool(true)).unwrap();
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "guard(bool)".into(),
            param_count: 1,
            return_type: Some(uint_type()),
            secret_args: vec![0],
            slot_count: 1,
            body: vec![
                ConfidentialKernelSlotStatement::AbortIf {
                    cond: ConfidentialKernelSlotExpr::Slot { slot: 0 },
                },
                ConfidentialKernelSlotStatement::Return {
                    value: Some(ConfidentialKernelSlotExpr::Literal {
                        value: Value::uint(9),
                    }),
                },
            ]
            .into_boxed_slice(),
        };

        let outcome = execute_confidential_kernel_slot_program(&mut runtime, &program).unwrap();

        assert_eq!(
            outcome,
            ConfidentialKernelExecutionOutcome {
                aborted: true,
                return_value: Some(Value::uint(9)),
            }
        );
        assert_eq!(runtime.statements, vec!["abort_if", "return"]);
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
