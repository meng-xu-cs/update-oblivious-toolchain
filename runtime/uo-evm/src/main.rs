use anyhow::Result;
use clap::{Parser, ValueEnum};

#[derive(Clone, Copy, Debug, ValueEnum)]
enum OutputFormat {
    Trace,
    RefinementWitness,
}

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long)]
    artifact: String,
    #[arg(long)]
    entrypoint: String,
    #[arg(long, value_enum, default_value_t = OutputFormat::Trace)]
    format: OutputFormat,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let artifact: uo_core::CompiledArtifact =
        serde_json::from_slice(&std::fs::read(&cli.artifact)?)?;
    let trace = uo_evm::run_artifact(&artifact, &cli.entrypoint)?;
    match cli.format {
        OutputFormat::Trace => {
            println!("{}", serde_json::to_string_pretty(&trace)?);
        }
        OutputFormat::RefinementWitness => {
            let witness = trace.runtime_refinement_witness()?;
            println!("{}", witness.to_json_pretty());
        }
    }
    Ok(())
}
