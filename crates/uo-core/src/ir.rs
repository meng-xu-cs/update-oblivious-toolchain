use crate::manifest::RuntimeManifest;
use crate::types::{Type, Value};
use serde::{Deserialize, Serialize};

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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateObject {
    pub id: u32,
    pub name: String,
    pub kind: ContainerKind,
    pub backend: BackendKind,
    pub value_type: Type,
    #[serde(default)]
    pub key_type: Option<Type>,
    #[serde(default)]
    pub capacity: Option<usize>,
    #[serde(default)]
    pub confidential: bool,
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CompiledFunction {
    pub signature: String,
    pub params: Vec<(String, Type)>,
    #[serde(default)]
    pub return_type: Option<Type>,
    pub body: Vec<Statement>,
    #[serde(default)]
    pub secret_args: Vec<usize>,
    #[serde(default)]
    pub confidential: bool,
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
