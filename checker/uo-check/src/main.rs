use anyhow::Result;
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
    let report = if let Some(artifact_path) = cli.artifact {
        let artifact: uo_core::CompiledArtifact =
            serde_json::from_slice(&std::fs::read(&artifact_path)?)?;
        uo_check::check_artifact(&artifact)?
    } else {
        let source = cli.source.expect("missing --source");
        let metadata = cli.metadata.expect("missing --metadata");
        let metadata: uo_core::ContractMetadata =
            serde_yaml::from_slice(&std::fs::read(&metadata)?)?;
        uo_check::check_source(&source, &metadata)?
    };
    println!("{}", serde_json::to_string_pretty(&report)?);
    Ok(())
}
