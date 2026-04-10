use anyhow::Result;
use clap::Parser;

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long)]
    artifact: String,
    #[arg(long)]
    entrypoint: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let artifact: uo_core::CompiledArtifact =
        serde_json::from_slice(&std::fs::read(&cli.artifact)?)?;
    let trace = uo_evm::run_artifact(&artifact, &cli.entrypoint)?;
    println!("{}", serde_json::to_string_pretty(&trace)?);
    Ok(())
}
