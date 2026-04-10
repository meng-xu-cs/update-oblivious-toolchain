use anyhow::{bail, Result};
use uo_core::{CompiledArtifact, ContractMetadata, ProgramMode};

pub fn compile(
    _source_path: &str,
    _metadata: &ContractMetadata,
    _mode: ProgramMode,
) -> Result<CompiledArtifact> {
    bail!("uo-solc compilation is not implemented yet")
}
