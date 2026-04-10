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
    pub confidential: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateMetadata {
    pub kind: String,
    #[serde(default)]
    pub key: Option<String>,
    pub value: String,
    #[serde(default)]
    pub capacity: Option<usize>,
    #[serde(default = "default_backend")]
    pub backend: String,
    #[serde(default)]
    pub confidential: bool,
}

fn default_backend() -> String {
    "full_scan".to_string()
}

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct BoundsMetadata {
    #[serde(default)]
    pub loops: BTreeMap<String, usize>,
}
