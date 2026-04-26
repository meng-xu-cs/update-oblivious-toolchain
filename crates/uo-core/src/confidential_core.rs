use crate::{
    CompiledArtifact, ConfidentialKernelProgram, ConfidentialKernelSlotLoweringError,
    ConfidentialKernelSlotProgram, ExecutionTrace, RefinementWitnessError, RuntimeKernelDslBundle,
    RuntimeKernelDslBundleError, RuntimeKernelFinishBundle, RuntimeKernelFinishBundleAccessError,
    RuntimeKernelFinishBundleError, RuntimeKernelInterfaceBundle,
    RuntimeKernelInterfaceBundleError, RuntimeKernelLoweringBundle,
    RuntimeKernelLoweringBundleError, RuntimeKernelSlotDslBundle, RuntimeKernelSlotDslBundleError,
    RuntimePaperMainFamilyBundleError, RuntimePaperMainSlotFamilyBundleError,
    RuntimeRefinementWitness, RuntimeShellBoundaryBundle, RuntimeShellBoundaryBundleError,
    RuntimeTrustedKernelSlotBundle, RuntimeTrustedKernelSlotBundleError,
    SeededRuntimePaperMainFamilyBundle, SeededRuntimePaperMainSlotFamilyBundle,
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

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialCoreKernelFinishSlotBundleError {
    #[error(
        "runtime confidential-core kernel-finish slot bundle requires a stored runtime kernel finish bundle"
    )]
    MissingRuntimeKernelFinishBundle,
    #[error(
        "runtime confidential-core kernel-finish slot bundle requires a finish bundle consistent with the execution trace: {0}"
    )]
    FinishBundleAccess(#[from] RuntimeKernelFinishBundleAccessError),
    #[error(
        "runtime confidential-core kernel-finish slot bundle requires a valid runtime kernel finish bundle: {0}"
    )]
    KernelFinish(#[from] RuntimeKernelFinishBundleError),
    #[error(
        "runtime confidential-core kernel-finish slot bundle requires a valid runtime shell-boundary bundle: {0}"
    )]
    ShellBoundary(#[from] RuntimeShellBoundaryBundleError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime confidential-core kernel-finish slot bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    #[error(
        "runtime confidential-core kernel-finish slot bundle statement trace drifted from confidential_slot_program for '{entrypoint}'"
    )]
    ConfidentialSlotProgramOpcodeTraceMismatch { entrypoint: String },
    #[error(
        "runtime confidential-core kernel-finish slot bundle expected admitted kernel steps for '{entrypoint}' to match the fixed confidential_slot_program"
    )]
    ConfidentialSlotProgramScheduleMismatch { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeConfidentialProofBundleFamilyError {
    #[error(
        "runtime confidential proof bundle family requires a valid runtime kernel-interface bundle: {0}"
    )]
    KernelInterface(#[from] RuntimeKernelInterfaceBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core kernel-interface slot bundle: {0}"
    )]
    KernelInterfaceSlot(#[from] RuntimeConfidentialCoreKernelInterfaceSlotBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime kernel DSL bundle: {0}"
    )]
    KernelDsl(#[from] RuntimeKernelDslBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime kernel slot DSL bundle: {0}"
    )]
    KernelSlotDsl(#[from] RuntimeKernelSlotDslBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime kernel lowering bundle: {0}"
    )]
    KernelLowering(#[from] RuntimeKernelLoweringBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime trusted-kernel slot bundle: {0}"
    )]
    TrustedKernelSlot(#[from] RuntimeTrustedKernelSlotBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core bundle: {0}"
    )]
    ConfidentialCore(#[from] RuntimeConfidentialCoreBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core slot bundle: {0}"
    )]
    ConfidentialCoreSlot(#[from] RuntimeConfidentialCoreSlotBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core kernel-finish slot bundle: {0}"
    )]
    ConfidentialCoreKernelFinishSlot(#[from] RuntimeConfidentialCoreKernelFinishSlotBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core lowering bundle: {0}"
    )]
    ConfidentialCoreLowering(#[from] RuntimeConfidentialCoreLoweringBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core shell-boundary slot bundle: {0}"
    )]
    ConfidentialCoreShellBoundarySlot(#[from] RuntimeConfidentialCoreShellBoundarySlotBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime confidential-core shell-boundary lowering bundle: {0}"
    )]
    ConfidentialCoreShellBoundaryLowering(
        #[from] RuntimeConfidentialCoreShellBoundaryLoweringBundleError,
    ),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime paper-main family bundle: {0}"
    )]
    PaperMainFamily(#[from] RuntimePaperMainFamilyBundleError),
    #[error(
        "runtime confidential proof bundle family requires a valid runtime paper-main slot family bundle: {0}"
    )]
    PaperMainSlotFamily(#[from] RuntimePaperMainSlotFamilyBundleError),
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreBundle {
    runtime_witness: RuntimeRefinementWitness,
    confidential_program: ConfidentialKernelProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreSlotBundle {
    runtime_witness: RuntimeRefinementWitness,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreLoweringBundle {
    runtime_witness: RuntimeRefinementWitness,
    confidential_program: ConfidentialKernelProgram,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreShellBoundaryLoweringBundle {
    runtime_witness: RuntimeRefinementWitness,
    shell_boundary_bundle: RuntimeShellBoundaryBundle,
    confidential_program: ConfidentialKernelProgram,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreShellBoundarySlotBundle {
    runtime_witness: RuntimeRefinementWitness,
    shell_boundary_bundle: RuntimeShellBoundaryBundle,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreKernelInterfaceSlotBundle {
    runtime_witness: RuntimeRefinementWitness,
    kernel_interface_bundle: RuntimeKernelInterfaceBundle,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialCoreKernelFinishSlotBundle {
    runtime_kernel_finish_bundle: RuntimeKernelFinishBundle,
    confidential_slot_program: ConfidentialKernelSlotProgram,
    opcode_trace: Box<[String]>,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeConfidentialProofBundleFamily {
    runtime_kernel_interface_bundle: RuntimeKernelInterfaceBundle,
    runtime_confidential_core_kernel_interface_slot_bundle:
        RuntimeConfidentialCoreKernelInterfaceSlotBundle,
    runtime_kernel_dsl_bundle: RuntimeKernelDslBundle,
    runtime_kernel_slot_dsl_bundle: RuntimeKernelSlotDslBundle,
    runtime_kernel_lowering_bundle: RuntimeKernelLoweringBundle,
    runtime_trusted_kernel_slot_bundle: RuntimeTrustedKernelSlotBundle,
    runtime_confidential_core_bundle: RuntimeConfidentialCoreBundle,
    runtime_confidential_core_slot_bundle: RuntimeConfidentialCoreSlotBundle,
    runtime_confidential_core_kernel_finish_slot_bundle:
        RuntimeConfidentialCoreKernelFinishSlotBundle,
    runtime_confidential_core_lowering_bundle: RuntimeConfidentialCoreLoweringBundle,
    runtime_confidential_core_shell_boundary_slot_bundle:
        RuntimeConfidentialCoreShellBoundarySlotBundle,
    runtime_confidential_core_shell_boundary_lowering_bundle:
        RuntimeConfidentialCoreShellBoundaryLoweringBundle,
    runtime_paper_main_family_bundle: SeededRuntimePaperMainFamilyBundle,
    runtime_paper_main_slot_family_bundle: SeededRuntimePaperMainSlotFamilyBundle,
}

impl RuntimeConfidentialProofBundleFamily {
    pub fn entrypoint_id(&self) -> &str {
        self.runtime_kernel_interface_bundle.entrypoint_id()
    }

    pub fn runtime_kernel_dsl_bundle(&self) -> &RuntimeKernelDslBundle {
        &self.runtime_kernel_dsl_bundle
    }

    pub fn runtime_kernel_slot_dsl_bundle(&self) -> &RuntimeKernelSlotDslBundle {
        &self.runtime_kernel_slot_dsl_bundle
    }

    pub fn runtime_kernel_lowering_bundle(&self) -> &RuntimeKernelLoweringBundle {
        &self.runtime_kernel_lowering_bundle
    }

    pub fn runtime_kernel_interface_bundle(&self) -> &RuntimeKernelInterfaceBundle {
        &self.runtime_kernel_interface_bundle
    }

    pub fn runtime_trusted_kernel_slot_bundle(&self) -> &RuntimeTrustedKernelSlotBundle {
        &self.runtime_trusted_kernel_slot_bundle
    }

    pub fn runtime_confidential_core_bundle(&self) -> &RuntimeConfidentialCoreBundle {
        &self.runtime_confidential_core_bundle
    }

    pub fn runtime_confidential_core_slot_bundle(&self) -> &RuntimeConfidentialCoreSlotBundle {
        &self.runtime_confidential_core_slot_bundle
    }

    pub fn runtime_confidential_core_kernel_finish_slot_bundle(
        &self,
    ) -> &RuntimeConfidentialCoreKernelFinishSlotBundle {
        &self.runtime_confidential_core_kernel_finish_slot_bundle
    }

    pub fn runtime_confidential_core_lowering_bundle(
        &self,
    ) -> &RuntimeConfidentialCoreLoweringBundle {
        &self.runtime_confidential_core_lowering_bundle
    }

    pub fn runtime_confidential_core_shell_boundary_slot_bundle(
        &self,
    ) -> &RuntimeConfidentialCoreShellBoundarySlotBundle {
        &self.runtime_confidential_core_shell_boundary_slot_bundle
    }

    pub fn runtime_confidential_core_shell_boundary_lowering_bundle(
        &self,
    ) -> &RuntimeConfidentialCoreShellBoundaryLoweringBundle {
        &self.runtime_confidential_core_shell_boundary_lowering_bundle
    }

    pub fn runtime_confidential_core_kernel_interface_slot_bundle(
        &self,
    ) -> &RuntimeConfidentialCoreKernelInterfaceSlotBundle {
        &self.runtime_confidential_core_kernel_interface_slot_bundle
    }

    pub fn runtime_paper_main_family_bundle(&self) -> &SeededRuntimePaperMainFamilyBundle {
        &self.runtime_paper_main_family_bundle
    }

    pub fn runtime_paper_main_slot_family_bundle(&self) -> &SeededRuntimePaperMainSlotFamilyBundle {
        &self.runtime_paper_main_slot_family_bundle
    }
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

    fn from_runtime_witness_and_shell_boundary_bundle(
        runtime_witness: RuntimeRefinementWitness,
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreShellBoundaryLoweringBundleError> {
        runtime_witness.validate()?;
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

    fn from_runtime_witness_and_shell_boundary_bundle(
        runtime_witness: RuntimeRefinementWitness,
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreShellBoundarySlotBundleError> {
        runtime_witness.validate()?;
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

    fn from_runtime_witness_and_kernel_interface_bundle(
        runtime_witness: RuntimeRefinementWitness,
        kernel_interface_bundle: RuntimeKernelInterfaceBundle,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreKernelInterfaceSlotBundleError> {
        runtime_witness.validate()?;
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

impl RuntimeConfidentialCoreKernelFinishSlotBundle {
    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn opcode_trace(&self) -> &[String] {
        &self.opcode_trace
    }

    pub fn entrypoint_id(&self) -> &str {
        self.runtime_kernel_finish_bundle.entrypoint_id()
    }

    pub fn program_matches_runtime_entrypoint(&self) -> bool {
        self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn runtime_shell_boundary_bundle(
        &self,
    ) -> Result<RuntimeShellBoundaryBundle, RuntimeConfidentialCoreKernelFinishSlotBundleError>
    {
        RuntimeShellBoundaryBundle::from_runtime_kernel_finish_bundle_ref(
            &self.runtime_kernel_finish_bundle,
        )
        .map_err(Into::into)
    }

    fn from_runtime_kernel_finish_bundle(
        runtime_kernel_finish_bundle: RuntimeKernelFinishBundle,
        opcode_trace: Box<[String]>,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeConfidentialCoreKernelFinishSlotBundleError> {
        runtime_kernel_finish_bundle.validate()?;
        let entrypoint = runtime_kernel_finish_bundle.entrypoint_id().to_owned();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| {
                RuntimeConfidentialCoreKernelFinishSlotBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimeConfidentialCoreKernelFinishSlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeConfidentialCoreKernelFinishSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        if opcode_trace.as_ref() != confidential_slot_program.statement_trace().as_ref() {
            return Err(
                RuntimeConfidentialCoreKernelFinishSlotBundleError::ConfidentialSlotProgramOpcodeTraceMismatch {
                    entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        let program_expected_kernel_steps =
            confidential_slot_program.expected_runtime_step_witnesses();
        if runtime_kernel_finish_bundle.expected_kernel_steps()
            != Some(program_expected_kernel_steps.as_ref())
            || runtime_kernel_finish_bundle.kernel_steps() != program_expected_kernel_steps.as_ref()
        {
            return Err(
                RuntimeConfidentialCoreKernelFinishSlotBundleError::ConfidentialSlotProgramScheduleMismatch {
                    entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            runtime_kernel_finish_bundle,
            confidential_slot_program,
            opcode_trace,
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
        let shell_boundary_bundle = self.runtime_shell_boundary_bundle()?;
        RuntimeConfidentialCoreShellBoundaryLoweringBundle::from_runtime_witness_and_shell_boundary_bundle(
            runtime_witness,
            shell_boundary_bundle,
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
        let shell_boundary_bundle = self.runtime_shell_boundary_bundle()?;
        RuntimeConfidentialCoreShellBoundarySlotBundle::from_runtime_witness_and_shell_boundary_bundle(
            runtime_witness,
            shell_boundary_bundle,
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
        let kernel_interface_bundle = self.runtime_kernel_interface_bundle(artifact)?;
        RuntimeConfidentialCoreKernelInterfaceSlotBundle::from_runtime_witness_and_kernel_interface_bundle(
            runtime_witness,
            kernel_interface_bundle,
            artifact,
        )
    }

    pub fn runtime_confidential_core_kernel_finish_slot_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<
        RuntimeConfidentialCoreKernelFinishSlotBundle,
        RuntimeConfidentialCoreKernelFinishSlotBundleError,
    > {
        let runtime_kernel_finish_bundle = self.exact_runtime_kernel_finish_bundle().map_err(
            |err| match err {
                RuntimeKernelFinishBundleAccessError::MissingRuntimeKernelFinishBundle => {
                    RuntimeConfidentialCoreKernelFinishSlotBundleError::MissingRuntimeKernelFinishBundle
                }
                err => RuntimeConfidentialCoreKernelFinishSlotBundleError::FinishBundleAccess(err),
            },
        )?;
        RuntimeConfidentialCoreKernelFinishSlotBundle::from_runtime_kernel_finish_bundle(
            runtime_kernel_finish_bundle,
            self.opcode_trace.clone(),
            artifact,
        )
    }

    pub fn runtime_confidential_proof_bundle_family(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeConfidentialProofBundleFamily, RuntimeConfidentialProofBundleFamilyError>
    {
        let runtime_kernel_interface_bundle = self.runtime_kernel_interface_bundle(artifact)?;
        let entrypoint = runtime_kernel_interface_bundle.entrypoint_id().to_owned();
        let runtime_confidential_core_kernel_interface_slot_bundle =
            self.runtime_confidential_core_kernel_interface_slot_bundle(artifact)?;
        let runtime_kernel_witness = runtime_kernel_interface_bundle.kernel_witness().clone();
        let runtime_kernel_dsl_bundle = artifact.runtime_kernel_dsl_bundle_for_entrypoint(
            runtime_kernel_witness.clone(),
            &entrypoint,
        )?;
        let runtime_kernel_slot_dsl_bundle = artifact
            .runtime_kernel_slot_dsl_bundle_for_entrypoint(
                runtime_kernel_witness.clone(),
                &entrypoint,
            )?;
        let runtime_kernel_lowering_bundle = artifact
            .runtime_kernel_lowering_bundle_for_entrypoint(runtime_kernel_witness, &entrypoint)?;
        let runtime_trusted_kernel_slot_bundle =
            self.runtime_trusted_kernel_slot_bundle(artifact)?;
        let runtime_confidential_core_bundle = self.runtime_confidential_core_bundle(artifact)?;
        let runtime_confidential_core_slot_bundle =
            self.runtime_confidential_core_slot_bundle(artifact)?;
        let runtime_confidential_core_kernel_finish_slot_bundle =
            self.runtime_confidential_core_kernel_finish_slot_bundle(artifact)?;
        let runtime_confidential_core_lowering_bundle =
            self.runtime_confidential_core_lowering_bundle(artifact)?;
        let runtime_confidential_core_shell_boundary_slot_bundle =
            self.runtime_confidential_core_shell_boundary_slot_bundle(artifact)?;
        let runtime_confidential_core_shell_boundary_lowering_bundle =
            self.runtime_confidential_core_shell_boundary_lowering_bundle(artifact)?;
        let runtime_paper_main_family_bundle = self.runtime_paper_main_family_bundle()?;
        let runtime_paper_main_slot_family_bundle =
            self.runtime_paper_main_slot_family_bundle(artifact)?;
        Ok(RuntimeConfidentialProofBundleFamily {
            runtime_kernel_interface_bundle,
            runtime_confidential_core_kernel_interface_slot_bundle,
            runtime_kernel_dsl_bundle,
            runtime_kernel_slot_dsl_bundle,
            runtime_kernel_lowering_bundle,
            runtime_trusted_kernel_slot_bundle,
            runtime_confidential_core_bundle,
            runtime_confidential_core_slot_bundle,
            runtime_confidential_core_kernel_finish_slot_bundle,
            runtime_confidential_core_lowering_bundle,
            runtime_confidential_core_shell_boundary_slot_bundle,
            runtime_confidential_core_shell_boundary_lowering_bundle,
            runtime_paper_main_family_bundle,
            runtime_paper_main_slot_family_bundle,
        })
    }
}
