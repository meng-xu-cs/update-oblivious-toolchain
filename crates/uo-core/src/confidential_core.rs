use crate::{
    CompiledArtifact, ConfidentialKernelLoweringError, ConfidentialKernelProgram,
    ConfidentialKernelSlotLoweringError, ConfidentialKernelSlotProgram, ExecutionTrace,
    RefinementWitnessError, RuntimeRefinementWitness, RuntimeShellBoundaryBundle,
    RuntimeShellBoundaryBundleError,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreBundleError {
    #[error("runtime confidential-core bundle requires a valid runtime refinement witness: {0}")]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("runtime confidential-core bundle requires a valid confidential kernel program: {0}")]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreSlotBundleError {
    #[error(
        "runtime confidential-core slot bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("runtime confidential-core slot bundle requires a valid confidential kernel slot program: {0}")]
    ConfidentialKernelSlot(#[from] ConfidentialKernelSlotLoweringError),
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreLoweringBundleError {
    #[error(
        "runtime confidential-core lowering bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error(
        "runtime confidential-core lowering bundle requires a valid confidential kernel program: {0}"
    )]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error(
        "runtime confidential-core lowering bundle requires a valid confidential kernel slot program: {0}"
    )]
    ConfidentialKernelSlot(#[from] ConfidentialKernelSlotLoweringError),
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreShellBoundaryLoweringBundleError {
    #[error(
        "runtime confidential-core shell-boundary lowering bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error(
        "runtime confidential-core shell-boundary lowering bundle requires a valid runtime shell-boundary bundle: {0}"
    )]
    ShellBoundary(#[from] RuntimeShellBoundaryBundleError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error(
        "runtime confidential-core shell-boundary lowering bundle requires a valid confidential kernel program: {0}"
    )]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error(
        "runtime confidential-core shell-boundary lowering bundle requires a valid confidential kernel slot program: {0}"
    )]
    ConfidentialKernelSlot(#[from] ConfidentialKernelSlotLoweringError),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreBundle {
    pub runtime_witness: RuntimeRefinementWitness,
    pub confidential_program: ConfidentialKernelProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreSlotBundle {
    pub runtime_witness: RuntimeRefinementWitness,
    pub confidential_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreLoweringBundle {
    pub runtime_witness: RuntimeRefinementWitness,
    pub confidential_program: ConfidentialKernelProgram,
    pub confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreShellBoundaryLoweringBundle {
    pub runtime_witness: RuntimeRefinementWitness,
    pub shell_boundary_bundle: RuntimeShellBoundaryBundle,
    pub confidential_program: ConfidentialKernelProgram,
    pub confidential_slot_program: ConfidentialKernelSlotProgram,
}

impl RuntimeConfidentialCoreBundle {
    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome.entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreBundleError> {
        let entrypoint = runtime_witness.public_outcome.entrypoint_id.clone();
        let function = artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(|| RuntimeConfidentialCoreBundleError::MissingEntrypoint {
                entrypoint: entrypoint.clone(),
            })?;
        Ok(Self {
            runtime_witness,
            confidential_program: function.confidential_kernel_program()?,
        })
    }
}

impl RuntimeConfidentialCoreSlotBundle {
    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome.entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreSlotBundleError> {
        let entrypoint = runtime_witness.public_outcome.entrypoint_id.clone();
        let function = artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(
                || RuntimeConfidentialCoreSlotBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        Ok(Self {
            runtime_witness,
            confidential_program: function.confidential_kernel_slot_program()?,
        })
    }
}

impl RuntimeConfidentialCoreLoweringBundle {
    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome.entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreLoweringBundleError> {
        let entrypoint = runtime_witness.public_outcome.entrypoint_id.clone();
        let function = artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(
                || RuntimeConfidentialCoreLoweringBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        let confidential_program = function.confidential_kernel_program()?;
        let confidential_slot_program = confidential_program.to_slot_program()?;
        Ok(Self {
            runtime_witness,
            confidential_program,
            confidential_slot_program,
        })
    }
}

impl RuntimeConfidentialCoreShellBoundaryLoweringBundle {
    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome.entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.shell_boundary_bundle.entrypoint_id() == self.entrypoint_id()
            && self.confidential_program.entrypoint_id == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreShellBoundaryLoweringBundleError> {
        runtime_witness.validate()?;
        let shell_boundary_bundle =
            RuntimeShellBoundaryBundle::from_runtime_witness(runtime_witness.clone())?;
        let entrypoint = runtime_witness.public_outcome.entrypoint_id.clone();
        let function = artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        let confidential_program = function.confidential_kernel_program()?;
        let confidential_slot_program = confidential_program.to_slot_program()?;
        Ok(Self {
            runtime_witness,
            shell_boundary_bundle,
            confidential_program,
            confidential_slot_program,
        })
    }
}

impl ExecutionTrace {
    pub fn runtime_confidential_core_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeConfidentialCoreBundle, RuntimeConfidentialCoreBundleError> {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeConfidentialCoreBundle::from_runtime_witness(runtime_witness, artifact)
    }

    pub fn runtime_confidential_core_slot_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeConfidentialCoreSlotBundle, RuntimeConfidentialCoreSlotBundleError> {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeConfidentialCoreSlotBundle::from_runtime_witness(runtime_witness, artifact)
    }

    pub fn runtime_confidential_core_lowering_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeConfidentialCoreLoweringBundle, RuntimeConfidentialCoreLoweringBundleError>
    {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeConfidentialCoreLoweringBundle::from_runtime_witness(runtime_witness, artifact)
    }

    pub fn runtime_confidential_core_shell_boundary_lowering_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<
        RuntimeConfidentialCoreShellBoundaryLoweringBundle,
        RuntimeConfidentialCoreShellBoundaryLoweringBundleError,
    > {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeConfidentialCoreShellBoundaryLoweringBundle::from_runtime_witness(
            runtime_witness,
            artifact,
        )
    }
}
