use crate::{
    CompiledArtifact, ConfidentialKernelProgram, ConfidentialKernelSlotLoweringError,
    ConfidentialKernelSlotProgram, ExecutionTrace, RefinementWitnessError,
    RuntimeKernelInterfaceBundle, RuntimeKernelInterfaceBundleError, RuntimeRefinementWitness,
    RuntimeShellBoundaryBundle, RuntimeShellBoundaryBundleError,
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
    #[error(
        "runtime confidential-core bundle expected confidential_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
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
    #[error(
        "runtime confidential-core slot bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
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
    #[error(
        "runtime confidential-core lowering bundle expected confidential_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime confidential-core lowering bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime confidential-core lowering bundle requires a lowerable confidential_program: {0}"
    )]
    ConfidentialProgramLowering(#[from] ConfidentialKernelSlotLoweringError),
    #[error(
        "runtime confidential-core lowering bundle expected confidential_program for '{entrypoint}' to lower exactly to the stored confidential_slot_program"
    )]
    ConfidentialProgramLoweringMismatch { entrypoint: String },
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
    #[error(
        "runtime confidential-core shell-boundary lowering bundle expected shell-boundary bundle for '{runtime_entrypoint}' but found shell-boundary bundle for '{shell_entrypoint}'"
    )]
    ShellBoundaryEntrypointMismatch {
        runtime_entrypoint: String,
        shell_entrypoint: String,
    },
    #[error(
        "runtime confidential-core shell-boundary lowering bundle expected confidential_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime confidential-core shell-boundary lowering bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime confidential-core shell-boundary lowering bundle requires a lowerable confidential_program: {0}"
    )]
    ConfidentialProgramLowering(#[from] ConfidentialKernelSlotLoweringError),
    #[error(
        "runtime confidential-core shell-boundary lowering bundle expected confidential_program for '{entrypoint}' to lower exactly to the stored confidential_slot_program"
    )]
    ConfidentialProgramLoweringMismatch { entrypoint: String },
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
    #[error(
        "runtime confidential-core shell-boundary slot bundle expected shell-boundary bundle for '{runtime_entrypoint}' but found shell-boundary bundle for '{shell_entrypoint}'"
    )]
    ShellBoundaryEntrypointMismatch {
        runtime_entrypoint: String,
        shell_entrypoint: String,
    },
    #[error(
        "runtime confidential-core shell-boundary slot bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreKernelInterfaceSlotBundleError {
    #[error(
        "runtime confidential-core kernel-interface slot bundle requires a valid runtime refinement witness: {0}"
    )]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error(
        "runtime confidential-core kernel-interface slot bundle requires a valid runtime kernel-interface bundle: {0}"
    )]
    KernelInterface(#[from] RuntimeKernelInterfaceBundleError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime confidential-core kernel-interface slot bundle expected kernel-interface bundle for '{runtime_entrypoint}' but found kernel-interface bundle for '{kernel_interface_entrypoint}'"
    )]
    KernelInterfaceEntrypointMismatch {
        runtime_entrypoint: String,
        kernel_interface_entrypoint: String,
    },
    #[error(
        "runtime confidential-core kernel-interface slot bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreKernelInterfaceSlotBundle {
    runtime_witness: RuntimeRefinementWitness,
    kernel_interface_bundle: RuntimeKernelInterfaceBundle,
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
        let confidential_program =
            manifest_entry.confidential_program.clone().ok_or_else(|| {
                RuntimeConfidentialCoreBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreBundleError::ConfidentialProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_witness,
            confidential_program,
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
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimeConfidentialCoreSlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_witness,
            confidential_slot_program,
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
        let confidential_program =
            manifest_entry.confidential_program.clone().ok_or_else(|| {
                RuntimeConfidentialCoreLoweringBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreLoweringBundleError::ConfidentialProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.clone(),
                    program_entrypoint: confidential_program.entrypoint_id.clone(),
                },
            );
        }
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimeConfidentialCoreLoweringBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreLoweringBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        if confidential_program.to_slot_program()? != confidential_slot_program {
            return Err(
                RuntimeConfidentialCoreLoweringBundleError::ConfidentialProgramLoweringMismatch {
                    entrypoint: runtime_witness.public_outcome().entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_witness,
            confidential_program,
            confidential_slot_program,
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
        if shell_boundary_bundle.entrypoint_id() != entrypoint {
            return Err(
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::ShellBoundaryEntrypointMismatch {
                    runtime_entrypoint: entrypoint.clone(),
                    shell_entrypoint: shell_boundary_bundle.entrypoint_id().to_owned(),
                },
            );
        }
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
        let confidential_program =
            manifest_entry.confidential_program.clone().ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::ConfidentialProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.clone(),
                    program_entrypoint: confidential_program.entrypoint_id.clone(),
                },
            );
        }
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        if confidential_program.to_slot_program()? != confidential_slot_program {
            return Err(
                RuntimeConfidentialCoreShellBoundaryLoweringBundleError::ConfidentialProgramLoweringMismatch {
                    entrypoint: runtime_witness.public_outcome().entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_witness,
            shell_boundary_bundle,
            confidential_program,
            confidential_slot_program,
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
        if shell_boundary_bundle.entrypoint_id() != entrypoint {
            return Err(
                RuntimeConfidentialCoreShellBoundarySlotBundleError::ShellBoundaryEntrypointMismatch {
                    runtime_entrypoint: entrypoint.clone(),
                    shell_entrypoint: shell_boundary_bundle.entrypoint_id().to_owned(),
                },
            );
        }
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
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimeConfidentialCoreShellBoundarySlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreShellBoundarySlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_witness,
            shell_boundary_bundle,
            confidential_slot_program,
        })
    }
}

impl RuntimeConfidentialCoreKernelInterfaceSlotBundle {
    pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {
        &self.runtime_witness
    }

    pub fn kernel_interface_bundle(&self) -> &RuntimeKernelInterfaceBundle {
        &self.kernel_interface_bundle
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.runtime_witness.public_outcome().entrypoint_id
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.kernel_interface_bundle.entrypoint_id() == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreKernelInterfaceSlotBundleError> {
        runtime_witness.validate()?;
        let kernel_interface_bundle =
            RuntimeKernelInterfaceBundle::from_runtime_witness(runtime_witness.clone(), artifact)?;
        let entrypoint = runtime_witness.public_outcome().entrypoint_id.clone();
        if kernel_interface_bundle.entrypoint_id() != entrypoint {
            return Err(
                RuntimeConfidentialCoreKernelInterfaceSlotBundleError::KernelInterfaceEntrypointMismatch {
                    runtime_entrypoint: entrypoint.clone(),
                    kernel_interface_entrypoint: kernel_interface_bundle.entrypoint_id().to_owned(),
                },
            );
        }
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| {
                RuntimeConfidentialCoreKernelInterfaceSlotBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimeConfidentialCoreKernelInterfaceSlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreKernelInterfaceSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_witness,
            kernel_interface_bundle,
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

    pub fn runtime_confidential_core_kernel_interface_slot_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<
        RuntimeConfidentialCoreKernelInterfaceSlotBundle,
        RuntimeConfidentialCoreKernelInterfaceSlotBundleError,
    > {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeConfidentialCoreKernelInterfaceSlotBundle::from_runtime_witness(
            runtime_witness,
            artifact,
        )
    }
}
