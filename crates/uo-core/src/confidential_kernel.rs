use crate::ir::{BinaryOp, CompiledFunction, Expr, Statement, UnaryOp};
use crate::types::{Type, Value};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
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

impl CompiledFunction {
    pub fn confidential_kernel_program(
        &self,
    ) -> Result<ConfidentialKernelProgram, ConfidentialKernelLoweringError> {
        if !self.confidential {
            return Err(ConfidentialKernelLoweringError::EntrypointNotConfidential {
                entrypoint: self.signature.clone(),
            });
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

    pub fn confidential_kernel_slot_program(
        &self,
    ) -> Result<ConfidentialKernelSlotProgram, ConfidentialKernelSlotLoweringError> {
        self.confidential_kernel_program()?.to_slot_program()
    }
}

impl ConfidentialKernelProgram {
    pub fn expected_runtime_steps(&self) -> Vec<ConfidentialKernelStep> {
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
        steps
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
}

impl ConfidentialKernelSlotProgram {
    pub fn expected_runtime_steps(&self) -> Vec<ConfidentialKernelStep> {
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
        steps
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

    pub fn expected_runtime_steps(&self) -> Vec<ConfidentialKernelStep> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps
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

    pub fn expected_runtime_steps(&self) -> Vec<ConfidentialKernelStep> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps
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
    pub fn kernel_steps(&self) -> Vec<ConfidentialKernelStep> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps
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
    pub fn kernel_steps(&self) -> Vec<ConfidentialKernelStep> {
        let mut steps = Vec::new();
        self.collect_kernel_steps(&mut steps);
        steps
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
            Self::Require { cond } => Ok(ConfidentialKernelSlotStatement::Require {
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
        ConfidentialKernelSlotExpr, ConfidentialKernelSlotLoweringError,
        ConfidentialKernelSlotStatement,
    };
    use crate::{BinaryOp, CompiledFunction, Expr, ScalarType, Statement, Type, Value};

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
        }
    }

    #[test]
    fn confidential_kernel_slot_program_preserves_schedule() {
        let function = sample_confidential_function();
        let named = function.confidential_kernel_program().unwrap();
        let slot = function.confidential_kernel_slot_program().unwrap();

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
        };

        let err = function.confidential_kernel_slot_program().unwrap_err();
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
        };

        let err = function.confidential_kernel_slot_program().unwrap_err();
        assert!(matches!(
            err,
            ConfidentialKernelSlotLoweringError::UnknownVariable { .. }
        ));
    }
}
