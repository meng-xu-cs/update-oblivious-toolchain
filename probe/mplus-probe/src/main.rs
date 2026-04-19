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
    StaticChecks,
    BridgeValidation,
    KernelValidation,
    KernelRefinementValidation,
    TrustedKernelValidation,
    TamperValidation,
    WitnessValidation,
    SeededWitnessValidation,
    PathoramPairValidation,
    ControllerValidation,
    PathoramHiddenValidation,
    RuntimeBoundaryValidation,
    KernelModelAlignmentValidation,
    ShellBoundaryValidation,
    ShellBoundaryLoweringValidation,
    ConfidentialFragmentValidation,
    KernelDslValidation,
    KernelSlotDslValidation,
    KernelLoweringValidation,
    ConfidentialCoreValidation,
    ConfidentialCoreSlotValidation,
    ConfidentialCoreLoweringValidation,
    ConfidentialCoreShellBoundaryLoweringValidation,
    CanonicalPathoramPairValidation,
    FreshCoinValidation,
}

#[derive(Debug, Parser)]
#[command(
    name = "mplus-probe",
    about = "Run the UO toolchain leakage/correctness validation reports"
)]
struct Cli {
    /// Output directory for generated reports and optional heavy artifacts.
    #[arg(long, default_value = "results")]
    out_dir: String,

    /// Restrict execution to a single report kind instead of generating the full bundle.
    #[arg(long)]
    only: Option<ReportKind>,

    /// Artifact materialization mode for canonical fresh-coin families and pairs.
    #[arg(long, value_enum, default_value = "compact")]
    artifact_mode: ArtifactModeArg,

    /// Compact artifact budget in bytes before theorem-input fallback is used.
    #[arg(long)]
    compact_budget_bytes: Option<u64>,

    /// Heavy artifact budget in bytes for explicit materialization in heavy mode.
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
        Some(ReportKind::StaticChecks) => {
            let report = mplus_probe::run_static_checks_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("static_checks.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "static_checks": report,
                }))?
            );
        }
        Some(ReportKind::BridgeValidation) => {
            let report = mplus_probe::run_bridge_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("bridge_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "bridge_validation": report,
                }))?
            );
        }
        Some(ReportKind::KernelValidation) => {
            let report = mplus_probe::run_kernel_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("kernel_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "kernel_validation": report,
                }))?
            );
        }
        Some(ReportKind::KernelRefinementValidation) => {
            let report = mplus_probe::run_kernel_refinement_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("kernel_refinement_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "kernel_refinement_validation": report,
                }))?
            );
        }
        Some(ReportKind::TrustedKernelValidation) => {
            let report = mplus_probe::run_trusted_kernel_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("trusted_kernel_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "trusted_kernel_validation": report,
                }))?
            );
        }
        Some(ReportKind::TamperValidation) => {
            let report = mplus_probe::run_tamper_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("tamper_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "tamper_validation": report,
                }))?
            );
        }
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
        Some(ReportKind::RuntimeBoundaryValidation) => {
            let report = mplus_probe::run_runtime_boundary_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("runtime_boundary_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "runtime_boundary_validation": report,
                }))?
            );
        }
        Some(ReportKind::KernelModelAlignmentValidation) => {
            let report = mplus_probe::run_kernel_model_alignment_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("kernel_model_alignment_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "kernel_model_alignment_validation": report,
                }))?
            );
        }
        Some(ReportKind::ShellBoundaryValidation) => {
            let report = mplus_probe::run_shell_boundary_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("shell_boundary_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "shell_boundary_validation": report,
                }))?
            );
        }
        Some(ReportKind::ShellBoundaryLoweringValidation) => {
            let report = mplus_probe::run_shell_boundary_lowering_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("shell_boundary_lowering_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "shell_boundary_lowering_validation": report,
                }))?
            );
        }
        Some(ReportKind::ConfidentialFragmentValidation) => {
            let report = mplus_probe::run_confidential_fragment_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("confidential_fragment_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "confidential_fragment_validation": report,
                }))?
            );
        }
        Some(ReportKind::KernelDslValidation) => {
            let report = mplus_probe::run_kernel_dsl_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("kernel_dsl_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "kernel_dsl_validation": report,
                }))?
            );
        }
        Some(ReportKind::KernelSlotDslValidation) => {
            let report = mplus_probe::run_kernel_slot_dsl_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("kernel_slot_dsl_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "kernel_slot_dsl_validation": report,
                }))?
            );
        }
        Some(ReportKind::KernelLoweringValidation) => {
            let report = mplus_probe::run_kernel_lowering_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("kernel_lowering_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "kernel_lowering_validation": report,
                }))?
            );
        }
        Some(ReportKind::ConfidentialCoreValidation) => {
            let report = mplus_probe::run_confidential_core_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("confidential_core_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "confidential_core_validation": report,
                }))?
            );
        }
        Some(ReportKind::ConfidentialCoreSlotValidation) => {
            let report = mplus_probe::run_confidential_core_slot_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("confidential_core_slot_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "confidential_core_slot_validation": report,
                }))?
            );
        }
        Some(ReportKind::ConfidentialCoreLoweringValidation) => {
            let report = mplus_probe::run_confidential_core_lowering_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir).join("confidential_core_lowering_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "confidential_core_lowering_validation": report,
                }))?
            );
        }
        Some(ReportKind::ConfidentialCoreShellBoundaryLoweringValidation) => {
            let report =
                mplus_probe::run_confidential_core_shell_boundary_lowering_validation_report()?;
            fs::create_dir_all(&cli.out_dir)?;
            fs::write(
                Path::new(&cli.out_dir)
                    .join("confidential_core_shell_boundary_lowering_validation.json"),
                serde_json::to_vec_pretty(&report)?,
            )?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "confidential_core_shell_boundary_lowering_validation": report,
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
