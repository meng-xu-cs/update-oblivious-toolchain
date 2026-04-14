use anyhow::Result;
use clap::Parser;
use serde_json::json;
use std::fs;
use std::path::Path;

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
}

fn main() -> Result<()> {
    let cli = Cli::parse();
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
            let report = mplus_probe::run_canonical_pathoram_pair_validation_report()?;
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
            let report = mplus_probe::run_fresh_coin_validation_report()?;
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
            let report = mplus_probe::run_probe()?;
            mplus_probe::write_results(&cli.out_dir, &report)?;
            println!("{}", serde_json::to_string_pretty(&report)?);
        }
    }
    Ok(())
}
