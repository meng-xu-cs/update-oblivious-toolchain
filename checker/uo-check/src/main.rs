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
    #[arg(long)]
    debug_translation_bundle_out: Option<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let debug_translation_bundle_out = cli.debug_translation_bundle_out.clone();
    let report = match (cli.artifact, cli.source, cli.metadata) {
        (Some(artifact_path), Some(source), Some(metadata_path)) => {
            let artifact: uo_core::CompiledArtifact =
                serde_json::from_slice(&std::fs::read(&artifact_path)?)?;
            let metadata: uo_core::ContractMetadata =
                serde_yaml::from_slice(&std::fs::read(&metadata_path)?)?;
            if let Some(output_path) = &debug_translation_bundle_out {
                let bundle = uo_check::translation_validation_bundle_against_source(
                    &source, &metadata, &artifact,
                )?;
                std::fs::write(output_path, serde_json::to_vec_pretty(&bundle)?)?;
            }
            let mut report = uo_check::check_artifact_against_source(&source, &metadata, &artifact)?;
            if let Some(output_path) = debug_translation_bundle_out.as_ref() {
                report.push(format!(
                    "debug translation bundle written to {}",
                    output_path
                ));
            }
            report
        }
        (Some(artifact_path), None, None) => {
            if debug_translation_bundle_out.is_some() {
                bail!(
                    "--debug-translation-bundle-out requires --artifact together with both --source and --metadata"
                );
            }
            let artifact: uo_core::CompiledArtifact =
                serde_json::from_slice(&std::fs::read(&artifact_path)?)?;
            uo_check::check_artifact(&artifact)?
        }
        (None, Some(source), Some(metadata_path)) => {
            if debug_translation_bundle_out.is_some() {
                bail!(
                    "--debug-translation-bundle-out requires --artifact together with both --source and --metadata"
                );
            }
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
        (None, None, None) => {
            if debug_translation_bundle_out.is_some() {
                bail!(
                    "--debug-translation-bundle-out requires --artifact together with both --source and --metadata"
                );
            }
            bail!("provide either --artifact or --source with --metadata")
        }
    };
    println!("{}", serde_json::to_string_pretty(&report)?);
    Ok(())
}
