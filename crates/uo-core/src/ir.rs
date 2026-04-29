use crate::confidential_kernel::{ConfidentialKernelProgram, ConfidentialKernelSlotProgram};
use crate::manifest::RuntimeManifest;
use crate::types::{ScalarType, Type, Value};
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
