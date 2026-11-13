use crate::confidential_kernel::{ConfidentialKernelProgram, ConfidentialKernelSlotProgram};
use crate::manifest::RuntimeManifest;
use crate::types::{ScalarType, Type, Value};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ProgramMode {
    Raw,
    Uo,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ContainerKind {
    Cell,
    Array,
    Map,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum BackendKind {
    Raw,
    FullScan,
    Oram,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum PublicEnvField {
    MsgSender,
    TxOrigin,
    BlockNumber,
    BlockTimestamp,
    BlockChainId,
}

impl PublicEnvField {
    pub const ALL: [Self; 5] = [
        Self::MsgSender,
        Self::TxOrigin,
        Self::BlockNumber,
        Self::BlockTimestamp,
        Self::BlockChainId,
    ];

    pub fn param_name(self) -> &'static str {
        match self {
            Self::MsgSender => "__uo_env_msg_sender",
            Self::TxOrigin => "__uo_env_tx_origin",
            Self::BlockNumber => "__uo_env_block_number",
            Self::BlockTimestamp => "__uo_env_block_timestamp",
            Self::BlockChainId => "__uo_env_block_chainid",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::MsgSender => "msg.sender",
            Self::TxOrigin => "tx.origin",
            Self::BlockNumber => "block.number",
            Self::BlockTimestamp => "block.timestamp",
            Self::BlockChainId => "block.chainid",
        }
    }

    pub fn ty(self) -> Type {
        match self {
            Self::MsgSender | Self::TxOrigin => Type::Scalar(ScalarType::Address),
            Self::BlockNumber | Self::BlockTimestamp | Self::BlockChainId => {
                Type::Scalar(ScalarType::Uint(256))
            }
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PublicEnvironment {
    pub caller: [u8; 20],
    pub tx_origin: [u8; 20],
    pub block_number: u64,
    pub block_timestamp: u64,
    pub chain_id: u64,
}

impl Default for PublicEnvironment {
    fn default() -> Self {
        Self {
            caller: [0u8; 20],
            tx_origin: [0u8; 20],
            block_number: 0,
            block_timestamp: 0,
            chain_id: 1,
        }
    }
}

impl PublicEnvironment {
    pub fn with_caller(caller: [u8; 20]) -> Self {
        Self {
            caller,
            tx_origin: caller,
            ..Self::default()
        }
    }

    pub fn value_for(&self, field: PublicEnvField) -> Value {
        match field {
            PublicEnvField::MsgSender => Value::Address(self.caller),
            PublicEnvField::TxOrigin => Value::Address(self.tx_origin),
            PublicEnvField::BlockNumber => Value::uint(self.block_number),
            PublicEnvField::BlockTimestamp => Value::uint(self.block_timestamp),
            PublicEnvField::BlockChainId => Value::uint(self.chain_id),
        }
    }

    pub fn public_bindings(&self, fields: &[PublicEnvField]) -> Vec<String> {
        fields
            .iter()
            .map(|field| format!("{}={}", field.label(), self.value_for(*field)))
            .collect()
    }

    pub fn full_public_bindings(&self) -> Vec<String> {
        self.public_bindings(&PublicEnvField::ALL)
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateObject {
    pub id: u32,
    pub name: String,
    pub kind: ContainerKind,
    pub backend: BackendKind,
    #[serde(default = "default_oram_scheme")]
    pub oram_scheme: String,
    pub value_type: Type,
    #[serde(default)]
    pub key_type: Option<Type>,
    #[serde(default)]
    pub capacity: Option<usize>,
    #[serde(default)]
    pub confidential: bool,
}

fn default_oram_scheme() -> String {
    "surrogate_public_schedule_v1".to_string()
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum UnaryOp {
    Not,
    Neg,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum BinaryOp {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    BitAnd,
    BitOr,
    BitXor,
    Eq,
    Neq,
    Lt,
    Lte,
    Gt,
    Gte,
    And,
    Or,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Expr {
    Literal(Value),
    Var(String),
    Unary {
        op: UnaryOp,
        expr: Box<Expr>,
    },
    Binary {
        op: BinaryOp,
        lhs: Box<Expr>,
        rhs: Box<Expr>,
    },
    Select {
        cond: Box<Expr>,
        when_true: Box<Expr>,
        when_false: Box<Expr>,
    },
    CellGet {
        object_id: u32,
    },
    ArrayGet {
        object_id: u32,
        index: Box<Expr>,
    },
    MapGet {
        object_id: u32,
        key: Box<Expr>,
    },
    StructField {
        base: Box<Expr>,
        field: String,
    },
    ArrayIndex {
        base: Box<Expr>,
        index: Box<Expr>,
    },
    Keccak256 {
        parts: Vec<Expr>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Statement {
    Declare {
        name: String,
        ty: Type,
        value: Expr,
    },
    Assign {
        name: String,
        value: Expr,
    },
    Require {
        cond: Expr,
    },
    AbortIf {
        cond: Expr,
    },
    If {
        cond: Expr,
        then_body: Vec<Statement>,
        else_body: Vec<Statement>,
    },
    For {
        loop_id: String,
        index_var: String,
        start: Expr,
        end: Expr,
        body: Vec<Statement>,
    },
    CellSet {
        object_id: u32,
        value: Expr,
        predicate: Option<Expr>,
    },
    ArraySet {
        object_id: u32,
        index: Expr,
        value: Expr,
        predicate: Option<Expr>,
    },
    MapPut {
        object_id: u32,
        key: Expr,
        value: Expr,
        predicate: Option<Expr>,
    },
    Return {
        value: Option<Expr>,
    },
}

/// The objects the statements access, by a get expression or a set
/// statement, in any branch or loop: the objects a call that runs them
/// loads.
pub fn accessed_objects(statements: &[Statement]) -> BTreeSet<u32> {
    let mut ids = BTreeSet::new();
    for statement in statements {
        collect_statement_objects(statement, &mut ids);
    }
    ids
}

/// The objects the statements have a write statement for, whether or not it
/// has a predicate and whatever branch or loop holds it: the objects a call
/// that runs them may write.
pub fn written_objects(statements: &[Statement]) -> BTreeSet<u32> {
    fn collect(statement: &Statement, ids: &mut BTreeSet<u32>) {
        match statement {
            Statement::CellSet { object_id, .. }
            | Statement::ArraySet { object_id, .. }
            | Statement::MapPut { object_id, .. } => {
                ids.insert(*object_id);
            }
            Statement::If {
                then_body,
                else_body,
                ..
            } => {
                for stmt in then_body.iter().chain(else_body) {
                    collect(stmt, ids);
                }
            }
            Statement::For { body, .. } => {
                for stmt in body {
                    collect(stmt, ids);
                }
            }
            Statement::Declare { .. }
            | Statement::Assign { .. }
            | Statement::Require { .. }
            | Statement::AbortIf { .. }
            | Statement::Return { .. } => {}
        }
    }
    let mut ids = BTreeSet::new();
    for statement in statements {
        collect(statement, &mut ids);
    }
    ids
}

fn collect_statement_objects(statement: &Statement, ids: &mut BTreeSet<u32>) {
    match statement {
        Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
            collect_expr_objects(value, ids);
        }
        Statement::Require { cond } | Statement::AbortIf { cond } => {
            collect_expr_objects(cond, ids)
        }
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            collect_expr_objects(cond, ids);
            for stmt in then_body {
                collect_statement_objects(stmt, ids);
            }
            for stmt in else_body {
                collect_statement_objects(stmt, ids);
            }
        }
        Statement::For {
            start, end, body, ..
        } => {
            collect_expr_objects(start, ids);
            collect_expr_objects(end, ids);
            for stmt in body {
                collect_statement_objects(stmt, ids);
            }
        }
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => {
            ids.insert(*object_id);
            collect_expr_objects(value, ids);
            if let Some(predicate) = predicate {
                collect_expr_objects(predicate, ids);
            }
        }
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => {
            ids.insert(*object_id);
            collect_expr_objects(index, ids);
            collect_expr_objects(value, ids);
            if let Some(predicate) = predicate {
                collect_expr_objects(predicate, ids);
            }
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            ids.insert(*object_id);
            collect_expr_objects(key, ids);
            collect_expr_objects(value, ids);
            if let Some(predicate) = predicate {
                collect_expr_objects(predicate, ids);
            }
        }
        Statement::Return { value } => {
            if let Some(value) = value {
                collect_expr_objects(value, ids);
            }
        }
    }
}

fn collect_expr_objects(expr: &Expr, ids: &mut BTreeSet<u32>) {
    match expr {
        Expr::Unary { expr, .. } => collect_expr_objects(expr, ids),
        Expr::Binary { lhs, rhs, .. } => {
            collect_expr_objects(lhs, ids);
            collect_expr_objects(rhs, ids);
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            collect_expr_objects(cond, ids);
            collect_expr_objects(when_true, ids);
            collect_expr_objects(when_false, ids);
        }
        Expr::CellGet { object_id } => {
            ids.insert(*object_id);
        }
        Expr::ArrayGet { object_id, index } => {
            ids.insert(*object_id);
            collect_expr_objects(index, ids);
        }
        Expr::MapGet { object_id, key } => {
            ids.insert(*object_id);
            collect_expr_objects(key, ids);
        }
        Expr::StructField { base, .. } => collect_expr_objects(base, ids),
        Expr::ArrayIndex { base, index } => {
            collect_expr_objects(base, ids);
            collect_expr_objects(index, ids);
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                collect_expr_objects(part, ids);
            }
        }
        Expr::Literal(_) | Expr::Var(_) => {}
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CompiledFunction {
    pub signature: String,
    pub params: Vec<(String, Type)>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub public_env: Vec<PublicEnvField>,
    #[serde(default)]
    pub return_type: Option<Type>,
    pub body: Vec<Statement>,
    #[serde(default)]
    pub secret_args: Vec<usize>,
    #[serde(default)]
    pub confidential: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confidential_program: Option<ConfidentialKernelProgram>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confidential_slot_program: Option<ConfidentialKernelSlotProgram>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CompiledContract {
    pub contract: String,
    pub mode: ProgramMode,
    pub source_file: String,
    pub state: Vec<StateObject>,
    pub functions: Vec<CompiledFunction>,
    pub manifest: RuntimeManifest,
}
