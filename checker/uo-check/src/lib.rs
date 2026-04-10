use anyhow::{bail, Result};
use uo_core::{CompiledArtifact, ContractMetadata};

pub fn check_source(_source_path: &str, _metadata: &ContractMetadata) -> Result<Vec<String>> {
    bail!("uo-check source validation is not implemented yet")
}

pub fn check_artifact(_artifact: &CompiledArtifact) -> Result<Vec<String>> {
    bail!("uo-check bytecode validation is not implemented yet")
}
