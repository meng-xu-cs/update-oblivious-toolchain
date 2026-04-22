use crate::{
    artifact::CompiledArtifact, manifest::EntrypointManifest, ConfidentialKernelProgram,
    ConfidentialKernelSlotLoweringError, ConfidentialKernelSlotProgram, ExecutionTrace,
    RuntimeKernelWitness, RuntimeShellBoundaryBundle, RuntimeShellBoundaryBundleError,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelDslBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error(
        "runtime kernel DSL bundle expected confidential_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelSlotDslBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime kernel slot DSL bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelLoweringBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime kernel lowering bundle expected confidential_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime kernel lowering bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error("runtime kernel lowering bundle requires a lowerable confidential_program: {0}")]
    ConfidentialProgramLowering(#[from] ConfidentialKernelSlotLoweringError),
    #[error(
        "runtime kernel lowering bundle expected confidential_program for '{entrypoint}' to lower exactly to the stored confidential_slot_program"
    )]
    ConfidentialProgramLoweringMismatch { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeShellBoundaryLoweringBundleError {
    #[error("runtime shell-boundary lowering bundle requires a valid shell-boundary bundle: {0}")]
    ShellBoundary(#[from] RuntimeShellBoundaryBundleError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime shell-boundary lowering bundle expected confidential_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime shell-boundary lowering bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime shell-boundary lowering bundle requires a lowerable confidential_program: {0}"
    )]
    ConfidentialProgramLowering(#[from] ConfidentialKernelSlotLoweringError),
    #[error(
        "runtime shell-boundary lowering bundle expected confidential_program for '{entrypoint}' to lower exactly to the stored confidential_slot_program"
    )]
    ConfidentialProgramLoweringMismatch { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeShellBoundarySlotBundleError {
    #[error("runtime shell-boundary slot bundle requires a valid shell-boundary bundle: {0}")]
    ShellBoundary(#[from] RuntimeShellBoundaryBundleError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime shell-boundary slot bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelDslBundle {
    kernel_witness: RuntimeKernelWitness,
    confidential_program: ConfidentialKernelProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelSlotDslBundle {
    kernel_witness: RuntimeKernelWitness,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelLoweringBundle {
    kernel_witness: RuntimeKernelWitness,
    confidential_program: ConfidentialKernelProgram,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellBoundaryLoweringBundle {
    shell_boundary_bundle: RuntimeShellBoundaryBundle,
    confidential_program: ConfidentialKernelProgram,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellBoundarySlotBundle {
    shell_boundary_bundle: RuntimeShellBoundaryBundle,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

impl RuntimeKernelDslBundle {
    pub fn kernel_witness(&self) -> &RuntimeKernelWitness {
        &self.kernel_witness
    }

    pub fn confidential_program(&self) -> &ConfidentialKernelProgram {
        &self.confidential_program
    }

    fn from_manifest_entry(
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeKernelDslBundleError> {
        let confidential_program = entry.confidential_program.clone().ok_or_else(|| {
            RuntimeKernelDslBundleError::MissingConfidentialProgram {
                entrypoint: entrypoint.into(),
            }
        })?;
        if confidential_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeKernelDslBundleError::ConfidentialProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.into(),
                    program_entrypoint: confidential_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            kernel_witness,
            confidential_program,
        })
    }
}

impl RuntimeKernelSlotDslBundle {
    pub fn kernel_witness(&self) -> &RuntimeKernelWitness {
        &self.kernel_witness
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    fn from_manifest_entry(
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeKernelSlotDslBundleError> {
        let confidential_slot_program =
            entry.confidential_slot_program.clone().ok_or_else(|| {
                RuntimeKernelSlotDslBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.into(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeKernelSlotDslBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.into(),
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            kernel_witness,
            confidential_slot_program,
        })
    }
}

impl RuntimeKernelLoweringBundle {
    pub fn kernel_witness(&self) -> &RuntimeKernelWitness {
        &self.kernel_witness
    }

    pub fn confidential_program(&self) -> &ConfidentialKernelProgram {
        &self.confidential_program
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    fn from_manifest_entry(
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeKernelLoweringBundleError> {
        let confidential_program = entry.confidential_program.clone().ok_or_else(|| {
            RuntimeKernelLoweringBundleError::MissingConfidentialProgram {
                entrypoint: entrypoint.into(),
            }
        })?;
        if confidential_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeKernelLoweringBundleError::ConfidentialProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.into(),
                    program_entrypoint: confidential_program.entrypoint_id.clone(),
                },
            );
        }
        let confidential_slot_program =
            entry.confidential_slot_program.clone().ok_or_else(|| {
                RuntimeKernelLoweringBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.into(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeKernelLoweringBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.into(),
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        if confidential_program.to_slot_program()? != confidential_slot_program {
            return Err(
                RuntimeKernelLoweringBundleError::ConfidentialProgramLoweringMismatch {
                    entrypoint: entrypoint.into(),
                },
            );
        }
        Ok(Self {
            kernel_witness,
            confidential_program,
            confidential_slot_program,
        })
    }
}

impl RuntimeShellBoundaryLoweringBundle {
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
        self.shell_boundary_bundle.entrypoint_id()
    }

    pub fn program_matches_shell_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_manifest_entry(
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeShellBoundaryLoweringBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        let confidential_program = entry.confidential_program.clone().ok_or_else(|| {
            RuntimeShellBoundaryLoweringBundleError::MissingConfidentialProgram {
                entrypoint: entrypoint.clone(),
            }
        })?;
        if confidential_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeShellBoundaryLoweringBundleError::ConfidentialProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.clone(),
                    program_entrypoint: confidential_program.entrypoint_id.clone(),
                },
            );
        }
        let confidential_slot_program =
            entry.confidential_slot_program.clone().ok_or_else(|| {
                RuntimeShellBoundaryLoweringBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeShellBoundaryLoweringBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint.clone(),
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        if confidential_program.to_slot_program()? != confidential_slot_program {
            return Err(
                RuntimeShellBoundaryLoweringBundleError::ConfidentialProgramLoweringMismatch {
                    entrypoint: entrypoint.clone(),
                },
            );
        }
        Ok(Self {
            shell_boundary_bundle,
            confidential_program,
            confidential_slot_program,
        })
    }
}

impl RuntimeShellBoundarySlotBundle {
    pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {
        &self.shell_boundary_bundle
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn entrypoint_id(&self) -> &str {
        self.shell_boundary_bundle.entrypoint_id()
    }

    pub fn program_matches_shell_entrypoint(&self) -> bool {
        self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_manifest_entry(
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeShellBoundarySlotBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        let confidential_slot_program =
            entry.confidential_slot_program.clone().ok_or_else(|| {
                RuntimeShellBoundarySlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeShellBoundarySlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            shell_boundary_bundle,
            confidential_slot_program,
        })
    }
}

impl CompiledArtifact {
    pub fn runtime_kernel_dsl_bundle_for_entrypoint(
        &self,
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
    ) -> Result<RuntimeKernelDslBundle, RuntimeKernelDslBundleError> {
        let manifest_entry = self
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| RuntimeKernelDslBundleError::MissingEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        RuntimeKernelDslBundle::from_manifest_entry(kernel_witness, entrypoint, manifest_entry)
    }

    pub fn runtime_kernel_slot_dsl_bundle_for_entrypoint(
        &self,
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
    ) -> Result<RuntimeKernelSlotDslBundle, RuntimeKernelSlotDslBundleError> {
        let manifest_entry = self
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| RuntimeKernelSlotDslBundleError::MissingEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        RuntimeKernelSlotDslBundle::from_manifest_entry(kernel_witness, entrypoint, manifest_entry)
    }

    pub fn runtime_kernel_lowering_bundle_for_entrypoint(
        &self,
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
    ) -> Result<RuntimeKernelLoweringBundle, RuntimeKernelLoweringBundleError> {
        let manifest_entry = self
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| RuntimeKernelLoweringBundleError::MissingEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        RuntimeKernelLoweringBundle::from_manifest_entry(kernel_witness, entrypoint, manifest_entry)
    }

    pub fn runtime_shell_boundary_lowering_bundle(
        &self,
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
    ) -> Result<RuntimeShellBoundaryLoweringBundle, RuntimeShellBoundaryLoweringBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        let manifest_entry = self
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(
                || RuntimeShellBoundaryLoweringBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        RuntimeShellBoundaryLoweringBundle::from_manifest_entry(
            shell_boundary_bundle,
            manifest_entry,
        )
    }

    pub fn runtime_shell_boundary_slot_bundle(
        &self,
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
    ) -> Result<RuntimeShellBoundarySlotBundle, RuntimeShellBoundarySlotBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        let manifest_entry = self
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| RuntimeShellBoundarySlotBundleError::MissingEntrypoint {
                entrypoint: entrypoint.clone(),
            })?;
        RuntimeShellBoundarySlotBundle::from_manifest_entry(shell_boundary_bundle, manifest_entry)
    }
}

impl ExecutionTrace {
    pub fn runtime_shell_boundary_lowering_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeShellBoundaryLoweringBundle, RuntimeShellBoundaryLoweringBundleError> {
        let shell_boundary_bundle = self.runtime_shell_boundary_bundle()?;
        artifact.runtime_shell_boundary_lowering_bundle(shell_boundary_bundle)
    }

    pub fn runtime_shell_boundary_slot_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeShellBoundarySlotBundle, RuntimeShellBoundarySlotBundleError> {
        let shell_boundary_bundle = self.runtime_shell_boundary_bundle()?;
        artifact.runtime_shell_boundary_slot_bundle(shell_boundary_bundle)
    }
}
