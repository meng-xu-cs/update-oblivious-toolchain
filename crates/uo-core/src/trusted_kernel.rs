use crate::{
    CompiledArtifact, ConfidentialKernelSlotProgram, ExecutionTrace, RefinementWitnessError,
    RuntimeTrustedKernelBundle,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeTrustedKernelSlotBundleError {
    #[error(
        "runtime trusted-kernel slot bundle requires a valid runtime trusted-kernel bundle: {0}"
    )]
    TrustedKernel(#[from] RefinementWitnessError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
    #[error(
        "runtime trusted-kernel slot bundle expected confidential_slot_program for '{expected_entrypoint}' but found program for '{program_entrypoint}'"
    )]
    ConfidentialSlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeTrustedKernelSlotBundle {
    trusted_kernel_bundle: RuntimeTrustedKernelBundle,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

impl RuntimeTrustedKernelSlotBundle {
    pub fn entrypoint_id(&self) -> &str {
        &self
            .trusted_kernel_bundle
            .controller_observer()
            .public_outcome()
            .entrypoint_id
    }

    pub fn trusted_kernel_bundle(&self) -> &RuntimeTrustedKernelBundle {
        &self.trusted_kernel_bundle
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn program_matches_trusted_kernel_entrypoint(&self) -> bool {
        self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    fn from_trusted_kernel_bundle(
        trusted_kernel_bundle: RuntimeTrustedKernelBundle,
        artifact: &CompiledArtifact,
    ) -> Result<Self, RuntimeTrustedKernelSlotBundleError> {
        let entrypoint = trusted_kernel_bundle
            .controller_observer()
            .public_outcome()
            .entrypoint_id
            .clone();
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(|| RuntimeTrustedKernelSlotBundleError::MissingEntrypoint {
                entrypoint: entrypoint.clone(),
            })?;
        let confidential_slot_program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(
                || RuntimeTrustedKernelSlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        if confidential_slot_program.entrypoint_id != entrypoint {
            return Err(
                RuntimeTrustedKernelSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: entrypoint,
                    program_entrypoint: confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        Ok(Self {
            trusted_kernel_bundle,
            confidential_slot_program,
        })
    }
}

impl ExecutionTrace {
    pub fn runtime_trusted_kernel_slot_bundle(
        &self,
        artifact: &CompiledArtifact,
    ) -> Result<RuntimeTrustedKernelSlotBundle, RuntimeTrustedKernelSlotBundleError> {
        let trusted_kernel_bundle = self.runtime_trusted_kernel_bundle()?;
        RuntimeTrustedKernelSlotBundle::from_trusted_kernel_bundle(trusted_kernel_bundle, artifact)
    }
}
