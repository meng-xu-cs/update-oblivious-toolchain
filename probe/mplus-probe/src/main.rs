use anyhow::Result;
use clap::Parser;
use serde_json::json;
use std::fs;
use std::path::Path;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, clap::ValueEnum)]
enum ArtifactModeArg {
    Compact,
    Heavy,
}

impl From<ArtifactModeArg> for mplus_probe::ArtifactMaterializationMode {
    fn from(value: ArtifactModeArg) -> Self {
        match value {
            ArtifactModeArg::Compact => Self::Compact,
            ArtifactModeArg::Heavy => Self::Heavy,
        }
    }
}

#[derive(Debug, Clone, clap::ValueEnum)]
enum ReportKind {
    WitnessValidation,
    SeededWitnessValidation,
    PathoramPairValidation,
    ControllerValidation,
    PathoramHiddenValidation,
    CanonicalPathoramPairValidation,
    FreshCoinValidation,
}

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long, default_value = "results")]
    out_dir: String,

    #[arg(long)]
    only: Option<ReportKind>,

    #[arg(long, value_enum, default_value = "compact")]
    artifact_mode: ArtifactModeArg,

    #[arg(long)]
    compact_budget_bytes: Option<u64>,

    #[arg(long)]
    heavy_budget_bytes: Option<u64>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let options = mplus_probe::ProbeRunOptions {
        materialization_mode: cli.artifact_mode.into(),
        out_dir: Some(PathBuf::from(&cli.out_dir)),
        compact_budget_bytes: cli
            .compact_budget_bytes
            .or_else(|| {
                std::env::var("UO_CANONICAL_CERT_BUDGET_BYTES")
                    .ok()
                    .and_then(|value| value.parse::<u64>().ok())
            })
            .unwrap_or(10 * 1024 * 1024 * 1024),
        heavy_budget_bytes: cli
            .heavy_budget_bytes
            .or_else(|| {
                std::env::var("UO_HEAVY_ARTIFACT_BUDGET_BYTES")
                    .ok()
                    .and_then(|value| value.parse::<u64>().ok())
            })
            .unwrap_or(20 * 1024 * 1024 * 1024),
    };
    match cli.only {
        Some(ReportKind::WitnessValidation) => {
            let report = mplus_probe::run_witness_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("witness_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "witness_validation": report,
                }))?
            );
        }
        Some(ReportKind::SeededWitnessValidation) => {
            let report = mplus_probe::run_seeded_witness_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("seeded_witness_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "seeded_witness_validation": report,
                }))?
            );
        }
        Some(ReportKind::PathoramPairValidation) => {
            let report = mplus_probe::run_pathoram_pair_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("pathoram_pair_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "pathoram_pair_validation": report,
                }))?
            );
        }
        Some(ReportKind::ControllerValidation) => {
            let report = mplus_probe::run_controller_observer_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("controller_observer_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "controller_observer_validation": report,
                }))?
            );
        }
        Some(ReportKind::PathoramHiddenValidation) => {
            let report = mplus_probe::run_pathoram_hidden_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("pathoram_hidden_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "pathoram_hidden_validation": report,
                }))?
            );
        }
        Some(ReportKind::CanonicalPathoramPairValidation) => {
            let report =
                mplus_probe::run_canonical_pathoram_pair_validation_with_options(&options)?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("canonical_pathoram_pair_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "canonical_pathoram_pair_validation": report,
                }))?
            );
        }
        Some(ReportKind::FreshCoinValidation) => {
            let report = mplus_probe::run_fresh_coin_validation_with_options(&options)?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("fresh_coin_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "fresh_coin_validation": report,
                }))?
            );
        }
        None => {
            let report = mplus_probe::run_probe_with_options(&options)?;
            mplus_probe::write_results(&cli.out_dir, &report)?;
            println!("{}", serde_json::to_string_pretty(&report)?);
        }
    }
    Ok(())
}
