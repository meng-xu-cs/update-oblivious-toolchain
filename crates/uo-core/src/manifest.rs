use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeManifest {
    pub contract: String,
    pub compilation_mode: String,
    pub objects: Vec<StateObjectManifest>,
    pub entrypoints: BTreeMap<String, EntrypointManifest>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateObjectManifest {
    pub id: u32,
    pub name: String,
    pub kind: String,
    pub backend: String,
    #[serde(default)]
    pub capacity: Option<usize>,
    #[serde(default)]
    pub value_type: Option<String>,
    #[serde(default)]
    pub key_type: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct EntrypointManifest {
    #[serde(default)]
    pub secret_args: Vec<usize>,
    pub public_gas_budget: u64,
    pub arena_bytes: usize,
    pub max_stack_words: usize,
    pub uocell_reads: usize,
    pub uocell_writes: usize,
    pub uoarray_reads: usize,
    pub uoarray_writes: usize,
    pub uomap_reads: usize,
    pub uomap_writes: usize,
    pub max_commit_ops: usize,
}
