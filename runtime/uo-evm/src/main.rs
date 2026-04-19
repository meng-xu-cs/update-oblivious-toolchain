use anyhow::Result;
use clap::{Parser, ValueEnum};

#[derive(Clone, Copy, Debug, ValueEnum)]
enum OutputFormat {
    Trace,
    KernelWitness,
    KernelDsl,
    KernelSlotDsl,
    KernelLowering,
    KernelRefinementWitness,
    ShellBoundary,
    ShellBoundarySlot,
    ShellBoundaryLowering,
    TrustedKernel,
    RefinementWitness,
    ConfidentialCore,
    ConfidentialCoreSlot,
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
        OutputFormat::KernelWitness => {
            let witness = trace.runtime_kernel_witness.clone().ok_or_else(|| {
                anyhow::anyhow!("execution trace is missing runtime kernel witness")
            })?;
            println!("{}", witness.to_json_pretty());
        }
        OutputFormat::KernelDsl => {
            let witness = trace.runtime_kernel_witness.clone().ok_or_else(|| {
                anyhow::anyhow!("execution trace is missing runtime kernel witness")
            })?;
            let bundle =
                artifact.runtime_kernel_dsl_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::KernelSlotDsl => {
            let witness = trace.runtime_kernel_witness.clone().ok_or_else(|| {
                anyhow::anyhow!("execution trace is missing runtime kernel witness")
            })?;
            let bundle =
                artifact.runtime_kernel_slot_dsl_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::KernelLowering => {
            let witness = trace.runtime_kernel_witness.clone().ok_or_else(|| {
                anyhow::anyhow!("execution trace is missing runtime kernel witness")
            })?;
            let bundle =
                artifact.runtime_kernel_lowering_bundle_for_entrypoint(witness, &cli.entrypoint)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::KernelRefinementWitness => {
            let witness = trace
                .runtime_kernel_refinement_witness
                .clone()
                .ok_or_else(|| {
                    anyhow::anyhow!("execution trace is missing runtime kernel refinement witness")
                })?;
            println!("{}", witness.to_json_pretty());
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
        OutputFormat::RefinementWitness => {
            let witness = trace.runtime_refinement_witness()?;
            println!("{}", witness.to_json_pretty());
        }
        OutputFormat::ConfidentialCore => {
            let bundle = trace.runtime_confidential_core_bundle(&artifact)?;
            println!("{}", serde_json::to_string_pretty(&bundle)?);
        }
        OutputFormat::ConfidentialCoreSlot => {
            let bundle = trace.runtime_confidential_core_slot_bundle(&artifact)?;
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
