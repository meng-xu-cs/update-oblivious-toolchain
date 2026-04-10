use anyhow::{bail, Result};
use uo_core::{CompiledArtifact, ExecutionTrace};

pub fn run_artifact(_artifact: &CompiledArtifact, _entrypoint: &str) -> Result<ExecutionTrace> {
    bail!("uo-evm execution is not implemented yet")
}
