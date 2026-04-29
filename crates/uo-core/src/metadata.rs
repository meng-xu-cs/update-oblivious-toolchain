use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ContractMetadata {
    pub contract: String,
    #[serde(default)]
    pub entrypoints: BTreeMap<String, EntrypointMetadata>,
    #[serde(default)]
    pub state: BTreeMap<String, StateMetadata>,
    #[serde(default)]
    pub bounds: BoundsMetadata,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct EntrypointMetadata {
    #[serde(default)]
    pub secret_args: Vec<String>,
    #[serde(default)]
    pub public_gas_budget: Option<u64>,
    #[serde(default)]
    pub confidential: Option<bool>,
    #[serde(default)]
    pub returns: Option<ReturnPolicy>,
    #[serde(default)]
    pub status: Option<StatusPolicy>,
    #[serde(default)]
    pub declassifies: Vec<DeclassificationKind>,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum ReturnPolicy {
    #[default]
    Forbidden,
    Public,
    Declassified,
    EncryptedToClient,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum StatusPolicy {
    #[default]
    Public,
    Declassified,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum DeclassificationKind {
    Return,
    Success,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateMetadata {
    pub kind: String,
    #[serde(default)]
    pub key: Option<String>,
    pub value: String,
    #[serde(default)]
    pub capacity: Option<usize>,
    pub backend: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub oram_scheme: Option<String>,
    pub confidential: bool,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct BoundsMetadata {
    #[serde(default)]
    pub loops: BTreeMap<String, usize>,
}
