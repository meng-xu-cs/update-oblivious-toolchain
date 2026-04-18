use crate::{
    artifact::CompiledArtifact, CompiledFunction, ConfidentialKernelLoweringError,
    ConfidentialKernelProgram, ConfidentialKernelSlotLoweringError, ConfidentialKernelSlotProgram,
    RuntimeKernelWitness, RuntimeShellBoundaryBundle,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelDslBundleError {
    #[error("runtime kernel DSL bundle requires a valid confidential kernel program: {0}")]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelSlotDslBundleError {
    #[error(
        "runtime kernel slot-DSL bundle requires a valid confidential kernel slot program: {0}"
    )]
    ConfidentialKernelSlot(#[from] ConfidentialKernelSlotLoweringError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelLoweringBundleError {
    #[error("runtime kernel lowering bundle requires a valid confidential kernel program: {0}")]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error(
        "runtime kernel lowering bundle requires a valid confidential kernel slot program: {0}"
    )]
    ConfidentialKernelSlot(#[from] ConfidentialKernelSlotLoweringError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeShellBoundaryLoweringBundleError {
    #[error(
        "runtime shell-boundary lowering bundle requires a valid confidential kernel program: {0}"
    )]
    ConfidentialKernel(#[from] ConfidentialKernelLoweringError),
    #[error(
        "runtime shell-boundary lowering bundle requires a valid confidential kernel slot program: {0}"
    )]
    ConfidentialKernelSlot(#[from] ConfidentialKernelSlotLoweringError),
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelDslBundle {
    pub kernel_witness: RuntimeKernelWitness,
    pub confidential_program: ConfidentialKernelProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelSlotDslBundle {
    pub kernel_witness: RuntimeKernelWitness,
    pub confidential_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelLoweringBundle {
    pub kernel_witness: RuntimeKernelWitness,
    pub confidential_program: ConfidentialKernelProgram,
    pub confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellBoundaryLoweringBundle {
    pub shell_boundary_bundle: RuntimeShellBoundaryBundle,
    pub confidential_program: ConfidentialKernelProgram,
    pub confidential_slot_program: ConfidentialKernelSlotProgram,
}

impl RuntimeKernelDslBundle {
    pub fn from_function(
        kernel_witness: RuntimeKernelWitness,
        function: &CompiledFunction,
    ) -> Result<Self, RuntimeKernelDslBundleError> {
        Ok(Self {
            kernel_witness,
            confidential_program: function.confidential_kernel_program()?,
        })
    }
}

impl RuntimeKernelSlotDslBundle {
    pub fn from_function(
        kernel_witness: RuntimeKernelWitness,
        function: &CompiledFunction,
    ) -> Result<Self, RuntimeKernelSlotDslBundleError> {
        Ok(Self {
            kernel_witness,
            confidential_program: function.confidential_kernel_slot_program()?,
        })
    }
}

impl RuntimeKernelLoweringBundle {
    pub fn from_function(
        kernel_witness: RuntimeKernelWitness,
        function: &CompiledFunction,
    ) -> Result<Self, RuntimeKernelLoweringBundleError> {
        let confidential_program = function.confidential_kernel_program()?;
        let confidential_slot_program = confidential_program.to_slot_program()?;
        Ok(Self {
            kernel_witness,
            confidential_program,
            confidential_slot_program,
        })
    }
}

impl RuntimeShellBoundaryLoweringBundle {
    pub fn entrypoint_id(&self) -> &str {
        self.shell_boundary_bundle.entrypoint_id()
    }

    pub fn program_matches_shell_entrypoint(&self) -> bool {
        self.confidential_program.entrypoint_id == self.entrypoint_id()
            && self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn from_function(
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        function: &CompiledFunction,
    ) -> Result<Self, RuntimeShellBoundaryLoweringBundleError> {
        let confidential_program = function.confidential_kernel_program()?;
        let confidential_slot_program = confidential_program.to_slot_program()?;
        Ok(Self {
            shell_boundary_bundle,
            confidential_program,
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
        let function = self
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(|| RuntimeKernelDslBundleError::MissingEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        RuntimeKernelDslBundle::from_function(kernel_witness, function)
    }

    pub fn runtime_kernel_slot_dsl_bundle_for_entrypoint(
        &self,
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
    ) -> Result<RuntimeKernelSlotDslBundle, RuntimeKernelSlotDslBundleError> {
        let function = self
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(|| RuntimeKernelSlotDslBundleError::MissingEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        RuntimeKernelSlotDslBundle::from_function(kernel_witness, function)
    }

    pub fn runtime_kernel_lowering_bundle_for_entrypoint(
        &self,
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
    ) -> Result<RuntimeKernelLoweringBundle, RuntimeKernelLoweringBundleError> {
        let function = self
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(|| RuntimeKernelLoweringBundleError::MissingEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        RuntimeKernelLoweringBundle::from_function(kernel_witness, function)
    }

    pub fn runtime_shell_boundary_lowering_bundle(
        &self,
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
    ) -> Result<RuntimeShellBoundaryLoweringBundle, RuntimeShellBoundaryLoweringBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        let function = self
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(
                || RuntimeShellBoundaryLoweringBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?;
        RuntimeShellBoundaryLoweringBundle::from_function(shell_boundary_bundle, function)
    }
}
