use anyhow::{bail, Result};
use clap::Parser;

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long)]
    artifact: Option<String>,
    #[arg(long)]
    source: Option<String>,
    #[arg(long)]
    metadata: Option<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let report = match (cli.artifact, cli.source, cli.metadata) {
        (Some(artifact_path), Some(source), Some(metadata_path)) => {
            let artifact: uo_core::CompiledArtifact =
                serde_json::from_slice(&std::fs::read(&artifact_path)?)?;
            let metadata: uo_core::ContractMetadata =
                serde_yaml::from_slice(&std::fs::read(&metadata_path)?)?;
            uo_check::check_artifact_against_source(&source, &metadata, &artifact)?
        }
        (Some(artifact_path), None, None) => {
            let artifact: uo_core::CompiledArtifact =
                serde_json::from_slice(&std::fs::read(&artifact_path)?)?;
            uo_check::check_artifact(&artifact)?
        }
        (None, Some(source), Some(metadata_path)) => {
            let metadata: uo_core::ContractMetadata =
                serde_yaml::from_slice(&std::fs::read(&metadata_path)?)?;
            uo_check::check_source(&source, &metadata)?
        }
        (Some(_), _, _) => bail!(
            "when validating an artifact against source, provide --artifact together with both --source and --metadata"
        ),
        (None, Some(_), None) | (None, None, Some(_)) => {
            bail!("--source and --metadata must be provided together")
        }
        (None, None, None) => bail!("provide either --artifact or --source with --metadata"),
    };
    println!("{}", serde_json::to_string_pretty(&report)?);
    Ok(())
}
