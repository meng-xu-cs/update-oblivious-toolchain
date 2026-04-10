use crate::ir::CompiledContract;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ArtifactFormat {
    Json,
    Bincode,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CompiledArtifact {
    pub compiler_version: String,
    pub contract: CompiledContract,
    #[serde(default)]
    pub diagnostics: Vec<String>,
    #[serde(default)]
    pub transformed_source: Option<String>,
    #[serde(default)]
    pub disassembly: Vec<String>,
}
