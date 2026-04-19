use crate::{
    CompiledArtifact, ConfidentialKernelProgram, ConfidentialKernelSlotProgram, ExecutionTrace,
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
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreSlotBundleError {
    #[error(
        "runtime confidential-core slot bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreLoweringBundleError {
    #[error(
        "runtime confidential-core lowering bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
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
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreShellBoundarySlotBundleError {
    #[error(
        "runtime confidential-core shell-boundary slot bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error(
        "runtime confidential-core shell-boundary slot bundle requires a valid runtime shell-boundary bundle: {0}"
    )]
    ShellBoundary(#[from] RuntimeShellBoundaryBundleError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreBundle {
    runtime_witness: RuntimeRefinementWitness,
    confidential_program: ConfidentialKernelProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreSlotBundle {
    runtime_witness: RuntimeRefinementWitness,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreLoweringBundle {
    runtime_witness: RuntimeRefinementWitness,
    confidential_program: ConfidentialKernelProgram,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreShellBoundaryLoweringBundle {
    runtime_witness: RuntimeRefinementWitness,
    shell_boundary_bundle: RuntimeShellBoundaryBundle,
    confidential_program: ConfidentialKernelProgram,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreShellBoundarySlotBundle {
    runtime_witness: RuntimeRefinementWitness,
    shell_boundary_bundle: RuntimeShellBoundaryBundle,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

impl RuntimeConfidentialCoreBundle {
    pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {
        &self.runtime_witness
    }

    pub fn confidential_program(&self) -> &ConfidentialKernelProgram {
        &self.confidential_program
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome().entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreBundleError> {
        let entrypoint = runtime_witness.public_outcome().entrypoint_id.clone();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| RuntimeConfidentialCoreBundleError::MissingEntrypoint {
                entrypoint: entrypoint.clone(),
            })?;
        Ok(Self {
            runtime_witness,
            confidential_program: manifest_entry.confidential_program.clone().ok_or_else(|| {
                RuntimeConfidentialCoreBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?,
        })
    }
}

impl RuntimeConfidentialCoreSlotBundle {
    pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {
        &self.runtime_witness
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome().entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreSlotBundleError> {
        let entrypoint = runtime_witness.public_outcome().entrypoint_id.clone();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(
                || RuntimeConfidentialCoreSlotBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        Ok(Self {
            runtime_witness,
            confidential_slot_program: manifest_entry
                .confidential_slot_program
                .clone()
                .ok_or_else(|| {
                    RuntimeConfidentialCoreSlotBundleError::MissingConfidentialSlotProgram {
                        entrypoint: entrypoint.clone(),
                    }
                })?,
        })
    }
}

impl RuntimeConfidentialCoreLoweringBundle {
    pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {
        &self.runtime_witness
    }

    pub fn confidential_program(&self) -> &ConfidentialKernelProgram {
        &self.confidential_program
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome().entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreLoweringBundleError> {
        let entrypoint = runtime_witness.public_outcome().entrypoint_id.clone();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(
                || RuntimeConfidentialCoreLoweringBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        Ok(Self {
            runtime_witness,
            confidential_program: manifest_entry.confidential_program.clone().ok_or_else(|| {
                RuntimeConfidentialCoreLoweringBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?,
            confidential_slot_program: manifest_entry
                .confidential_slot_program
                .clone()
                .ok_or_else(|| {
                    RuntimeConfidentialCoreLoweringBundleError::MissingConfidentialSlotProgram {
                        entrypoint: entrypoint.clone(),
                    }
                })?,
        })
    }
}

impl RuntimeConfidentialCoreShellBoundaryLoweringBundle {
    pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {
        &self.runtime_witness
    }

    pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {
        &self.shell_boundary_bundle
    }

    pub fn confidential_program(&self) -> &ConfidentialKernelProgram {
        &self.confidential_program
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome().entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.shell_boundary_bundle.entrypoint_id() == self.entrypoint_id()
            && self.confidential_program.entrypoint_id == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreShellBoundaryLoweringBundleError> {
        runtime_witness.validate()?;
        let shell_boundary_bundle =
            RuntimeShellBoundaryBundle::from_runtime_witness(runtime_witness.clone())?;
        let entrypoint = runtime_witness.public_outcome().entrypoint_id.clone();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        Ok(Self {
            runtime_witness,
            shell_boundary_bundle,
            confidential_program: manifest_entry.confidential_program.clone().ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?,
            confidential_slot_program: manifest_entry
                .confidential_slot_program
                .clone()
                .ok_or_else(|| {
                    RuntimeConfidentialCoreShellBoundaryLoweringBundleError::MissingConfidentialSlotProgram {
                        entrypoint: entrypoint.clone(),
                    }
                })?,
        })
    }
}

impl RuntimeConfidentialCoreShellBoundarySlotBundle {
    pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {
        &self.runtime_witness
    }

    pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {
        &self.shell_boundary_bundle
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome().entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.shell_boundary_bundle.entrypoint_id() == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreShellBoundarySlotBundleError> {
        runtime_witness.validate()?;
        let shell_boundary_bundle =
            RuntimeShellBoundaryBundle::from_runtime_witness(runtime_witness.clone())?;
        let entrypoint = runtime_witness.public_outcome().entrypoint_id.clone();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundarySlotBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        Ok(Self {
            runtime_witness,
            shell_boundary_bundle,
            confidential_slot_program: manifest_entry
                .confidential_slot_program
                .clone()
                .ok_or_else(|| {
                    RuntimeConfidentialCoreShellBoundarySlotBundleError::MissingConfidentialSlotProgram {
                        entrypoint: entrypoint.clone(),
                    }
                })?,
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

    pub fn runtime_confidential_core_shell_boundary_slot_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<
        RuntimeConfidentialCoreShellBoundarySlotBundle,
        RuntimeConfidentialCoreShellBoundarySlotBundleError,
    > {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeConfidentialCoreShellBoundarySlotBundle::from_runtime_witness(
            runtime_witness,
            artifact,
        )
    }
}
