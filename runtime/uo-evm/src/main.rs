use anyhow::Result;
use clap::{Parser, ValueEnum};

/// What to print of the call. A default build prints the receipt, which is
/// what the observer of the call sees. The whole trace and the proof objects
/// hold the call's private evidence, so only a build with the `diagnostics`
/// feature can print them.
#[derive(Clone, Copy, Debug, ValueEnum)]
enum OutputFormat {
    Receipt,
    #[cfg(feature = "diagnostics")]
    Trace,
    #[cfg(feature = "diagnostics")]
    KernelFinish,
    #[cfg(feature = "diagnostics")]
    KernelWitness,
    #[cfg(feature = "diagnostics")]
    KernelDsl,
    #[cfg(feature = "diagnostics")]
    KernelSlotDsl,
    #[cfg(feature = "diagnostics")]
    KernelLowering,
    #[cfg(feature = "diagnostics")]
    KernelRefinementWitness,
    #[cfg(feature = "diagnostics")]
    KernelInterface,
    #[cfg(feature = "diagnostics")]
    ShellBoundary,
    #[cfg(feature = "diagnostics")]
    ShellBoundarySlot,
    #[cfg(feature = "diagnostics")]
    ShellBoundaryLowering,
    #[cfg(feature = "diagnostics")]
    TrustedKernel,
    #[cfg(feature = "diagnostics")]
    ConfidentialProofFamily,
    #[cfg(feature = "diagnostics")]
    PaperMainFamily,
    #[cfg(feature = "diagnostics")]
    PaperMainSlotFamily,
    #[cfg(feature = "diagnostics")]
    RefinementWitness,
    #[cfg(feature = "diagnostics")]
    ConfidentialCore,
    #[cfg(feature = "diagnostics")]
    ConfidentialCoreSlot,
    #[cfg(feature = "diagnostics")]
    ConfidentialCoreKernelFinishSlot,
    #[cfg(feature = "diagnostics")]
    ConfidentialCoreKernelInterfaceSlot,
    #[cfg(feature = "diagnostics")]
    ConfidentialCoreShellBoundarySlot,
    #[cfg(feature = "diagnostics")]
    ConfidentialCoreLowering,
    #[cfg(feature = "diagnostics")]
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
    #[arg(long, value_enum, default_value_t = OutputFormat::Receipt)]
    format: OutputFormat,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let artifact: uo_core::CompiledArtifact =
        serde_json::from_slice(&std::fs::read(&cli.artifact)?)?;
    #[cfg(feature = "diagnostics")]
    let result = match cli.seed {
        Some(seed) => uo_evm::run_artifact_with_seed(&artifact, &cli.entrypoint, seed)?,
        None => uo_evm::run_artifact(&artifact, &cli.entrypoint)?,
    };
    #[cfg(not(feature = "diagnostics"))]
    let result = uo_evm::run_artifact(&artifact, &cli.entrypoint)?;
    #[cfg(feature = "diagnostics")]
    let trace = &result.trace;
    match cli.format {
        OutputFormat::Receipt => {
            println!("{}", serde_json::to_string_pretty(result.receipt())?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::Trace => {
            println!("{}", serde_json::to_string_pretty(trace)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelFinish => {
            let bundle = trace.exact_runtime_kernel_finish_bundle()?;
            println!("{}", bundle.to_json_pretty()?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelWitness => {
            let witness = trace.exact_runtime_kernel_witness()?;
            println!("{}", witness.to_json_pretty()?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelDsl => {
            let witness = trace.exact_runtime_kernel_witness()?;
            let bundle =
                artifact.runtime_kernel_dsl_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelSlotDsl => {
            let witness = trace.exact_runtime_kernel_witness()?;
            let bundle =
                artifact.runtime_kernel_slot_dsl_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelLowering => {
            let witness = trace.exact_runtime_kernel_witness()?;
            let bundle =
                artifact.runtime_kernel_lowering_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelRefinementWitness => {
            let witness = trace.exact_runtime_kernel_refinement_witness()?;
            println!("{}", witness.to_json_pretty()?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::KernelInterface => {
            let bundle = trace.runtime_kernel_interface_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ShellBoundary => {
            let bundle = trace.runtime_shell_boundary_bundle()?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ShellBoundarySlot => {
            let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
            let bundle = artifact.runtime_shell_boundary_slot_bundle(shell_boundary_bundle)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ShellBoundaryLowering => {
            let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
            let bundle = artifact.runtime_shell_boundary_lowering_bundle(shell_boundary_bundle)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::TrustedKernel => {
            let bundle = trace.runtime_trusted_kernel_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialProofFamily => {
            let bundle = trace.runtime_confidential_proof_bundle_family(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::PaperMainFamily => {
            let bundle = trace.runtime_paper_main_family_bundle()?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::PaperMainSlotFamily => {
            let bundle = trace.runtime_paper_main_slot_family_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::RefinementWitness => {
            let witness = trace.runtime_refinement_witness()?;
            println!("{}", witness.to_json_pretty()?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCore => {
            let bundle = trace.runtime_confidential_core_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCoreSlot => {
            let bundle = trace.runtime_confidential_core_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCoreKernelFinishSlot => {
            let bundle = trace.runtime_confidential_core_kernel_finish_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCoreKernelInterfaceSlot => {
            let bundle = trace.runtime_confidential_core_kernel_interface_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCoreShellBoundarySlot => {
            let bundle = trace.runtime_confidential_core_shell_boundary_slot_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCoreLowering => {
            let bundle = trace.runtime_confidential_core_lowering_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        #[cfg(feature = "diagnostics")]
        OutputFormat::ConfidentialCoreShellBoundaryLowering => {
            let bundle =
                trace.runtime_confidential_core_shell_boundary_lowering_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
    }
    Ok(())
}
