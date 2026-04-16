use anyhow::Result;
use clap::{Parser, ValueEnum};

#[derive(Clone, Copy, Debug, ValueEnum)]
enum OutputFormat {
    Trace,
    TrustedKernel,
    RefinementWitness,
}

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long)]
    artifact: String,
    #[arg(long)]
    entrypoint: String,
    #[arg(long)]
    seed: Option<u64>,
    #[arg(long, value_enum, default_value_t = OutputFormat::Trace)]
    format: OutputFormat,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let artifact: uo_core::CompiledArtifact =
        serde_json::from_slice(&std::fs::read(&cli.artifact)?)?;
    let trace = match cli.seed {
        Some(seed) => uo_evm::run_artifact_with_seed(&artifact, &cli.entrypoint, seed)?,
        None => uo_evm::run_artifact(&artifact, &cli.entrypoint)?,
    };
    match cli.format {
        OutputFormat::Trace => {
            println!("{}", serde_json::to_string_pretty(&trace)?);
        }
        OutputFormat::TrustedKernel => {
            let bundle = trace.runtime_trusted_kernel_bundle()?;
            println!("{}", bundle.to_json_pretty());
        }
        OutputFormat::RefinementWitness => {
            let witness = trace.runtime_refinement_witness()?;
            println!("{}", witness.to_json_pretty());
        }
    }
    Ok(())
}
