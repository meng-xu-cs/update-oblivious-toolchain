use anyhow::Result;
use clap::Parser;
use serde_json::{json, Value as JsonValue};
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
    ReviewerSummary,
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

fn write_single_report(
    out_dir: &str,
    file_name: &str,
    report_name: &'static str,
    report: &JsonValue,
) -> Result<()> {
    fs::create_dir_all(out_dir)?;
    fs::write(Path::new(out_dir).join(file_name), serde_json::to_vec_pretty(report)?)?;
    if report_name == "reviewer_summary" {
        mplus_probe::write_reviewer_summary_markdown(out_dir, report)?;
    }
    mplus_probe::write_reproducibility_manifest(out_dir)?;
    println!(
        "{}",
        serde_json::to_string_pretty(&json!({
            report_name: report,
        }))?
    );
    Ok(())
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
            write_single_report(&cli.out_dir, "static_checks.json", "static_checks", &report)?;
        }
        Some(ReportKind::BridgeValidation) => {
            let report = mplus_probe::run_bridge_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "bridge_validation.json",
                "bridge_validation",
                &report,
            )?;
        }
        Some(ReportKind::KernelValidation) => {
            let report = mplus_probe::run_kernel_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "kernel_validation.json",
                "kernel_validation",
                &report,
            )?;
        }
        Some(ReportKind::KernelRefinementValidation) => {
            let report = mplus_probe::run_kernel_refinement_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "kernel_refinement_validation.json",
                "kernel_refinement_validation",
                &report,
            )?;
        }
        Some(ReportKind::TrustedKernelValidation) => {
            let report = mplus_probe::run_trusted_kernel_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "trusted_kernel_validation.json",
                "trusted_kernel_validation",
                &report,
            )?;
        }
        Some(ReportKind::TamperValidation) => {
            let report = mplus_probe::run_tamper_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "tamper_validation.json",
                "tamper_validation",
                &report,
            )?;
        }
        Some(ReportKind::WitnessValidation) => {
            let report = mplus_probe::run_witness_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "witness_validation.json",
                "witness_validation",
                &report,
            )?;
        }
        Some(ReportKind::SeededWitnessValidation) => {
            let report = mplus_probe::run_seeded_witness_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "seeded_witness_validation.json",
                "seeded_witness_validation",
                &report,
            )?;
        }
        Some(ReportKind::PathoramPairValidation) => {
            let report = mplus_probe::run_pathoram_pair_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "pathoram_pair_validation.json",
                "pathoram_pair_validation",
                &report,
            )?;
        }
        Some(ReportKind::ControllerValidation) => {
            let report = mplus_probe::run_controller_observer_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "controller_observer_validation.json",
                "controller_observer_validation",
                &report,
            )?;
        }
        Some(ReportKind::PathoramHiddenValidation) => {
            let report = mplus_probe::run_pathoram_hidden_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "pathoram_hidden_validation.json",
                "pathoram_hidden_validation",
                &report,
            )?;
        }
        Some(ReportKind::RuntimeBoundaryValidation) => {
            let report = mplus_probe::run_runtime_boundary_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "runtime_boundary_validation.json",
                "runtime_boundary_validation",
                &report,
            )?;
        }
        Some(ReportKind::KernelModelAlignmentValidation) => {
            let report = mplus_probe::run_kernel_model_alignment_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "kernel_model_alignment_validation.json",
                "kernel_model_alignment_validation",
                &report,
            )?;
        }
        Some(ReportKind::ShellBoundaryValidation) => {
            let report = mplus_probe::run_shell_boundary_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "shell_boundary_validation.json",
                "shell_boundary_validation",
                &report,
            )?;
        }
        Some(ReportKind::ShellBoundaryLoweringValidation) => {
            let report = mplus_probe::run_shell_boundary_lowering_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "shell_boundary_lowering_validation.json",
                "shell_boundary_lowering_validation",
                &report,
            )?;
        }
        Some(ReportKind::ConfidentialFragmentValidation) => {
            let report = mplus_probe::run_confidential_fragment_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "confidential_fragment_validation.json",
                "confidential_fragment_validation",
                &report,
            )?;
        }
        Some(ReportKind::KernelDslValidation) => {
            let report = mplus_probe::run_kernel_dsl_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "kernel_dsl_validation.json",
                "kernel_dsl_validation",
                &report,
            )?;
        }
        Some(ReportKind::KernelSlotDslValidation) => {
            let report = mplus_probe::run_kernel_slot_dsl_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "kernel_slot_dsl_validation.json",
                "kernel_slot_dsl_validation",
                &report,
            )?;
        }
        Some(ReportKind::KernelLoweringValidation) => {
            let report = mplus_probe::run_kernel_lowering_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "kernel_lowering_validation.json",
                "kernel_lowering_validation",
                &report,
            )?;
        }
        Some(ReportKind::ConfidentialCoreValidation) => {
            let report = mplus_probe::run_confidential_core_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "confidential_core_validation.json",
                "confidential_core_validation",
                &report,
            )?;
        }
        Some(ReportKind::ConfidentialCoreSlotValidation) => {
            let report = mplus_probe::run_confidential_core_slot_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "confidential_core_slot_validation.json",
                "confidential_core_slot_validation",
                &report,
            )?;
        }
        Some(ReportKind::ConfidentialCoreLoweringValidation) => {
            let report = mplus_probe::run_confidential_core_lowering_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "confidential_core_lowering_validation.json",
                "confidential_core_lowering_validation",
                &report,
            )?;
        }
        Some(ReportKind::ConfidentialCoreShellBoundaryLoweringValidation) => {
            let report =
                mplus_probe::run_confidential_core_shell_boundary_lowering_validation_report()?;
            write_single_report(
                &cli.out_dir,
                "confidential_core_shell_boundary_lowering_validation.json",
                "confidential_core_shell_boundary_lowering_validation",
                &report,
            )?;
        }
        Some(ReportKind::CanonicalPathoramPairValidation) => {
            let report =
                mplus_probe::run_canonical_pathoram_pair_validation_with_options(&options)?;
            write_single_report(
                &cli.out_dir,
                "canonical_pathoram_pair_validation.json",
                "canonical_pathoram_pair_validation",
                &report,
            )?;
        }
        Some(ReportKind::FreshCoinValidation) => {
            let report = mplus_probe::run_fresh_coin_validation_with_options(&options)?;
            write_single_report(
                &cli.out_dir,
                "fresh_coin_validation.json",
                "fresh_coin_validation",
                &report,
            )?;
        }
        Some(ReportKind::ReviewerSummary) => {
            let report = mplus_probe::run_reviewer_summary_report(&options)?;
            write_single_report(
                &cli.out_dir,
                "reviewer_summary.json",
                "reviewer_summary",
                &report,
            )?;
        }
        None => {
            let report = mplus_probe::run_probe_with_options(&options)?;
            mplus_probe::write_results(&cli.out_dir, &report)?;
            println!("{}", serde_json::to_string_pretty(&report)?);
        }
    }
    Ok(())
}
