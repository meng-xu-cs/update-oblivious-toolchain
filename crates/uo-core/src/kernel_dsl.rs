use crate::{
    artifact::CompiledArtifact, manifest::EntrypointManifest, ConfidentialKernelProgram,
    ConfidentialKernelSlotProgram, RuntimeKernelWitness, RuntimeShellBoundaryBundle,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelDslBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelSlotDslBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeKernelLoweringBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeShellBoundaryLoweringBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_program")]
    MissingConfidentialProgram { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeShellBoundarySlotBundleError {
    #[error("artifact is missing confidential entrypoint '{entrypoint}'")]
    MissingEntrypoint { entrypoint: String },
    #[error("artifact manifest entrypoint '{entrypoint}' is missing confidential_slot_program")]
    MissingConfidentialSlotProgram { entrypoint: String },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelDslBundle {
    pub kernel_witness: RuntimeKernelWitness,
    pub confidential_program: ConfidentialKernelProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelSlotDslBundle {
    pub kernel_witness: RuntimeKernelWitness,
    pub confidential_slot_program: ConfidentialKernelSlotProgram,
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellBoundarySlotBundle {
    pub shell_boundary_bundle: RuntimeShellBoundaryBundle,
    pub confidential_slot_program: ConfidentialKernelSlotProgram,
}

impl RuntimeKernelDslBundle {
    pub fn from_manifest_entry(
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeKernelDslBundleError> {
        Ok(Self {
            kernel_witness,
            confidential_program: entry.confidential_program.clone().ok_or_else(|| {
                RuntimeKernelDslBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.into(),
                }
            })?,
        })
    }
}

impl RuntimeKernelSlotDslBundle {
    pub fn from_manifest_entry(
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeKernelSlotDslBundleError> {
        Ok(Self {
            kernel_witness,
            confidential_slot_program: entry.confidential_slot_program.clone().ok_or_else(
                || RuntimeKernelSlotDslBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.into(),
                },
            )?,
        })
    }
}

impl RuntimeKernelLoweringBundle {
    pub fn from_manifest_entry(
        kernel_witness: RuntimeKernelWitness,
        entrypoint: &str,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeKernelLoweringBundleError> {
        Ok(Self {
            kernel_witness,
            confidential_program: entry.confidential_program.clone().ok_or_else(|| {
                RuntimeKernelLoweringBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.into(),
                }
            })?,
            confidential_slot_program: entry.confidential_slot_program.clone().ok_or_else(
                || RuntimeKernelLoweringBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.into(),
                },
            )?,
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

    pub fn from_manifest_entry(
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeShellBoundaryLoweringBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        Ok(Self {
            shell_boundary_bundle,
            confidential_program: entry.confidential_program.clone().ok_or_else(|| {
                RuntimeShellBoundaryLoweringBundleError::MissingConfidentialProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?,
            confidential_slot_program: entry.confidential_slot_program.clone().ok_or_else(
                || RuntimeShellBoundaryLoweringBundleError::MissingConfidentialSlotProgram {
                    entrypoint,
                },
            )?,
        })
    }
}

impl RuntimeShellBoundarySlotBundle {
    pub fn entrypoint_id(&self) -> &str {
        self.shell_boundary_bundle.entrypoint_id()
    }

    pub fn program_matches_shell_entrypoint(&self) -> bool {
        self.confidential_slot_program.entrypoint_id == self.entrypoint_id()
    }

    pub fn from_manifest_entry(
        shell_boundary_bundle: RuntimeShellBoundaryBundle,
        entry: &EntrypointManifest,
    ) -> Result<Self, RuntimeShellBoundarySlotBundleError> {
        let entrypoint = shell_boundary_bundle.entrypoint_id().to_owned();
        Ok(Self {
            shell_boundary_bundle,
            confidential_slot_program: entry.confidential_slot_program.clone().ok_or_else(
                || RuntimeShellBoundarySlotBundleError::MissingConfidentialSlotProgram {
                    entrypoint,
                },
            )?,
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
