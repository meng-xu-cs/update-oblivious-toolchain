use anyhow::Result;
use clap::{Parser, ValueEnum};

#[derive(Clone, Copy, Debug, ValueEnum)]
enum OutputFormat {
    Trace,
    KernelFinish,
    KernelWitness,
    KernelDsl,
    KernelSlotDsl,
    KernelLowering,
    KernelRefinementWitness,
    KernelInterface,
    ShellBoundary,
    ShellBoundarySlot,
    ShellBoundaryLowering,
    TrustedKernel,
    ConfidentialProofFamily,
    PaperMainFamily,
    PaperMainSlotFamily,
    RefinementWitness,
    ConfidentialCore,
    ConfidentialCoreSlot,
    ConfidentialCoreKernelFinishSlot,
    ConfidentialCoreKernelInterfaceSlot,
    ConfidentialCoreShellBoundarySlot,
    ConfidentialCoreLowering,
    ConfidentialCoreShellBoundaryLowering,
}

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long)]
    artifact: String,
    #[arg(long)]
    entrypoint: String,
    #[cfg(feature = "diagnostics")]
    #[arg(long)]
    seed: Option<u64>,
    #[arg(long, value_enum, default_value_t = OutputFormat::Trace)]
    format: OutputFormat,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let artifact: uo_core::CompiledArtifact =
        serde_json::from_slice(&std::fs::read(&cli.artifact)?)?;
    #[cfg(feature = "diagnostics")]
    let trace = match cli.seed {
        Some(seed) => uo_evm::run_artifact_with_seed(&artifact, &cli.entrypoint, seed)?,
        None => uo_evm::run_artifact(&artifact, &cli.entrypoint)?,
    };
    #[cfg(not(feature = "diagnostics"))]
    let trace = uo_evm::run_artifact(&artifact, &cli.entrypoint)?;
    match cli.format {
        OutputFormat::Trace => {
            println!("{}", serde_json::to_string_pretty(&trace)?);
        }
        OutputFormat::KernelFinish => {
            let bundle = trace.exact_runtime_kernel_finish_bundle()?;
            println!("{}", bundle.to_json_pretty()?);
        }
        OutputFormat::KernelWitness => {
            let witness = trace.exact_runtime_kernel_witness()?;
            println!("{}", witness.to_json_pretty()?);
        }
        OutputFormat::KernelDsl => {
            let witness = trace.exact_runtime_kernel_witness()?;
            let bundle =
                artifact.runtime_kernel_dsl_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::KernelSlotDsl => {
            let witness = trace.exact_runtime_kernel_witness()?;
            let bundle =
                artifact.runtime_kernel_slot_dsl_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::KernelLowering => {
            let witness = trace.exact_runtime_kernel_witness()?;
            let bundle =
                artifact.runtime_kernel_lowering_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::KernelRefinementWitness => {
            let witness = trace.exact_runtime_kernel_refinement_witness()?;
            println!("{}", witness.to_json_pretty()?);
        }
        OutputFormat::KernelInterface => {
            let bundle = trace.runtime_kernel_interface_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ShellBoundary => {
            let bundle = trace.runtime_shell_boundary_bundle()?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ShellBoundarySlot => {
            let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
            let bundle = artifact.runtime_shell_boundary_slot_bundle(shell_boundary_bundle)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ShellBoundaryLowering => {
            let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
            let bundle = artifact.runtime_shell_boundary_lowering_bundle(shell_boundary_bundle)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::TrustedKernel => {
            let bundle = trace.runtime_trusted_kernel_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialProofFamily => {
            let bundle = trace.runtime_confidential_proof_bundle_family(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::PaperMainFamily => {
            let bundle = trace.runtime_paper_main_family_bundle()?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::PaperMainSlotFamily => {
            let bundle = trace.runtime_paper_main_slot_family_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::RefinementWitness => {
            let witness = trace.runtime_refinement_witness()?;
            println!("{}", witness.to_json_pretty()?);
        }
        OutputFormat::ConfidentialCore => {
            let bundle = trace.runtime_confidential_core_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreSlot => {
            let bundle = trace.runtime_confidential_core_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreKernelFinishSlot => {
            let bundle = trace.runtime_confidential_core_kernel_finish_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreKernelInterfaceSlot => {
            let bundle = trace.runtime_confidential_core_kernel_interface_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreShellBoundarySlot => {
            let bundle = trace.runtime_confidential_core_shell_boundary_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreLowering => {
            let bundle = trace.runtime_confidential_core_lowering_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreShellBoundaryLowering => {
            let bundle =
                trace.runtime_confidential_core_shell_boundary_lowering_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
    }
    Ok(())
}
