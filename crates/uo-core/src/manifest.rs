use crate::confidential_kernel::{ConfidentialKernelProgram, ConfidentialKernelSlotProgram};
use crate::ir::{BackendKind, ContainerKind, StateObject};
use crate::types::{ScalarType, Type};
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uo_precompiles::UoOpcode;

pub const SURROGATE_ORAM_SCHEME: &str = "surrogate_public_schedule_v1";
pub const PATH_ORAM_SCHEME: &str = "path_oram_local_posmap_v1";

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeManifest {
    pub contract: String,
    pub compilation_mode: String,
    pub objects: Vec<StateObjectManifest>,
    pub entrypoints: BTreeMap<String, EntrypointManifest>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateObjectManifest {
    pub id: u32,
    pub name: String,
    pub kind: String,
    pub backend: String,
    #[serde(default)]
    pub capacity: Option<usize>,
    #[serde(default)]
    pub value_type: Option<String>,
    #[serde(default)]
    pub key_type: Option<String>,
    #[serde(default)]
    pub oram: Option<OramManifest>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelStepManifest {
    pub opcode: UoOpcode,
    #[serde(default)]
    pub object_id: Option<u32>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct EntrypointManifest {
    #[serde(default)]
    pub secret_args: Vec<usize>,
    #[serde(default)]
    pub param_names: Vec<String>,
    pub public_gas_budget: u64,
    pub arena_bytes: usize,
    pub max_stack_words: usize,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confidential_program: Option<ConfidentialKernelProgram>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confidential_slot_program: Option<ConfidentialKernelSlotProgram>,
    #[serde(default)]
    pub kernel_steps: Vec<RuntimeKernelStepManifest>,
    pub uocell_reads: usize,
    pub uocell_writes: usize,
    pub uoarray_reads: usize,
    pub uoarray_writes: usize,
    pub uomap_reads: usize,
    pub uomap_writes: usize,
    pub max_commit_ops: usize,
    #[serde(default)]
    pub oram_accesses: BTreeMap<u32, usize>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct OramManifest {
    pub scheme: String,
    pub block_size: usize,
    pub bucket_size: usize,
    pub bucket_count: usize,
    pub blocks_per_bucket: usize,
    pub tree_height: usize,
    pub stash_bound: usize,
    pub recursion_depth: usize,
    pub metadata_pages: usize,
    pub metadata_pages_per_access: usize,
    pub buckets_per_access: usize,
    pub accesses_per_call: usize,
}

impl OramManifest {
    pub fn path_leaf_count(&self) -> Result<usize> {
        if self.scheme != PATH_ORAM_SCHEME {
            bail!("path_leaf_count is only defined for {}", PATH_ORAM_SCHEME);
        }
        if self.bucket_count == 0 || self.bucket_count % 2 == 0 {
            bail!("path ORAM bucket_count must equal 2 * leaf_count - 1");
        }
        Ok((self.bucket_count + 1) / 2)
    }

    pub fn for_object(object: &StateObject) -> Result<Self> {
        if object.kind != ContainerKind::Map || object.backend != BackendKind::Oram {
            bail!("object {} is not an ORAM-backed map", object.name);
        }
        let capacity = object
            .capacity
            .ok_or_else(|| anyhow!("map {} is missing capacity", object.name))?;
        let key_type = object
            .key_type
            .as_ref()
            .ok_or_else(|| anyhow!("map {} missing key type", object.name))?;
        let key_bytes = fixed_scalar_width(key_type)?;
        let value_bytes = fixed_scalar_width(&object.value_type)?;
        match object.oram_scheme.as_str() {
            SURROGATE_ORAM_SCHEME => {
                let block_size = 1 + key_bytes + value_bytes;
                let tree_height = log2_ceil(capacity.max(2));
                let metadata_pages = capacity.max(1).div_ceil(8);
                Ok(Self {
                    scheme: SURROGATE_ORAM_SCHEME.into(),
                    block_size,
                    bucket_size: 24 + 2 * block_size,
                    bucket_count: capacity.max(1).next_power_of_two().max(8) / 2,
                    blocks_per_bucket: 2,
                    tree_height,
                    stash_bound: 0,
                    recursion_depth: 0,
                    metadata_pages,
                    metadata_pages_per_access: metadata_pages + 1,
                    buckets_per_access: (tree_height + 2).max(3),
                    accesses_per_call: 1,
                })
            }
            PATH_ORAM_SCHEME => {
                let leaf_count = capacity.max(2).next_power_of_two();
                let tree_height = log2_ceil(leaf_count);
                let block_size = 1 + 8 + 8 + key_bytes + value_bytes;
                let blocks_per_bucket = 5usize;
                let stash_bound = capacity.max(1);
                let position_map_pages = capacity.max(1).div_ceil(8);
                let stash_pages = stash_bound.div_ceil(8);
                let metadata_pages = position_map_pages + stash_pages;
                Ok(Self {
                    scheme: PATH_ORAM_SCHEME.into(),
                    block_size,
                    bucket_size: 24 + blocks_per_bucket * block_size,
                    bucket_count: 2 * leaf_count - 1,
                    blocks_per_bucket,
                    tree_height,
                    stash_bound,
                    recursion_depth: 0,
                    metadata_pages,
                    metadata_pages_per_access: metadata_pages + 1,
                    buckets_per_access: tree_height + 1,
                    accesses_per_call: 1,
                })
            }
            other => bail!("unsupported ORAM scheme {}", other),
        }
    }

    pub fn total_commit_ops(&self) -> usize {
        self.metadata_pages_per_access + self.buckets_per_access
    }

    pub fn supports_multi_access_per_entrypoint(&self) -> bool {
        self.scheme == PATH_ORAM_SCHEME
    }

    pub fn validate_theorem_shape_for_object(&self, object: &StateObject) -> Result<()> {
        let capacity = object
            .capacity
            .ok_or_else(|| anyhow!("map {} is missing capacity", object.name))?;
        match self.scheme.as_str() {
            SURROGATE_ORAM_SCHEME => {
                if self.blocks_per_bucket != 2 {
                    bail!("surrogate ORAM requires 2 blocks per bucket");
                }
                if self.bucket_size != 24 + self.blocks_per_bucket * self.block_size {
                    bail!("surrogate ORAM bucket size does not match theorem shape");
                }
                if self.bucket_count == 0 {
                    bail!("surrogate ORAM bucket count must be positive");
                }
                if self.metadata_pages_per_access != self.metadata_pages + 1 {
                    bail!("surrogate ORAM metadata_pages_per_access must equal metadata_pages + 1");
                }
                if self.buckets_per_access != (self.tree_height + 2).max(3) {
                    bail!("surrogate ORAM buckets_per_access does not match theorem shape");
                }
                if self.stash_bound != 0 {
                    bail!("surrogate ORAM stash_bound must be 0");
                }
                if self.recursion_depth != 0 {
                    bail!("surrogate ORAM recursion_depth must be 0");
                }
                if self.accesses_per_call != 1 {
                    bail!("surrogate ORAM accesses_per_call must be 1");
                }
            }
            PATH_ORAM_SCHEME => {
                let leaf_count = self.path_leaf_count()?;
                if self.blocks_per_bucket != 5 {
                    bail!("path ORAM requires 5 blocks per bucket");
                }
                if self.bucket_size != 24 + self.blocks_per_bucket * self.block_size {
                    bail!("path ORAM bucket size does not match theorem shape");
                }
                if !leaf_count.is_power_of_two() {
                    bail!("path ORAM leaf count must be a power of two");
                }
                if self.stash_bound != capacity.max(1) {
                    bail!("path ORAM stash_bound must equal max(capacity, 1)");
                }
                if self.recursion_depth != 0 {
                    bail!("path ORAM recursion_depth must be 0");
                }
                if self.tree_height != log2_ceil(leaf_count) {
                    bail!("path ORAM tree_height must equal log2(leaf_count)");
                }
                if self.bucket_count != 2 * leaf_count - 1 {
                    bail!("path ORAM bucket_count must equal 2 * leaf_count - 1");
                }
                if self.metadata_pages_per_access != self.metadata_pages + 1 {
                    bail!("path ORAM metadata_pages_per_access must equal metadata_pages + 1");
                }
                if self.buckets_per_access != self.tree_height + 1 {
                    bail!("path ORAM buckets_per_access must equal tree_height + 1");
                }
                if self.accesses_per_call != 1 {
                    bail!("path ORAM accesses_per_call must be 1");
                }
            }
            other => bail!("unsupported ORAM scheme {}", other),
        }
        Ok(())
    }
}

pub fn validate_oram_access_shape(
    signature: &str,
    oram_accesses: &BTreeMap<u32, usize>,
    state: &[StateObject],
) -> Result<()> {
    for (object_id, accesses) in oram_accesses {
        let object = state_object_by_id(state, *object_id)?;
        if object.backend != BackendKind::Oram {
            bail!(
                "entrypoint {} records ORAM accesses for non-ORAM object {}",
                signature,
                object.name
            );
        }
        let manifest = OramManifest::for_object(object)?;
        manifest
            .validate_theorem_shape_for_object(object)
            .map_err(|err| {
                anyhow!(
                    "entrypoint {} object {} violates theorem-facing ORAM shape: {}",
                    signature,
                    object.name,
                    err
                )
            })?;
        if *accesses > 1 && !manifest.supports_multi_access_per_entrypoint() {
            bail!(
                "entrypoint {} performs {} ORAM accesses to {} but scheme {} only supports one access per entrypoint; use {} for multi-access workloads",
                signature,
                accesses,
                object.name,
                manifest.scheme,
                PATH_ORAM_SCHEME
            );
        }
    }
    Ok(())
}

fn fixed_scalar_width(ty: &Type) -> Result<usize> {
    match ty {
        Type::Scalar(ScalarType::Bool) => Ok(1),
        Type::Scalar(ScalarType::Uint(_)) => Ok(32),
        Type::Scalar(ScalarType::Bytes32) => Ok(32),
        Type::Scalar(ScalarType::Address) => Ok(20),
        _ => bail!("ORAM control metadata only supports scalar map key/value types"),
    }
}

fn log2_ceil(value: usize) -> usize {
    value.max(1).next_power_of_two().ilog2() as usize
}

fn state_object_by_id(state: &[StateObject], object_id: u32) -> Result<&StateObject> {
    state
        .iter()
        .find(|object| object.id == object_id)
        .ok_or_else(|| anyhow!("unknown object id {}", object_id))
}

#[cfg(test)]
mod tests {
    use super::{OramManifest, PATH_ORAM_SCHEME};
    use crate::ir::{BackendKind, ContainerKind, StateObject};
    use crate::types::{ScalarType, Type};

    fn path_oram_object(capacity: usize) -> StateObject {
        StateObject {
            id: 7,
            name: "balances".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
            oram_scheme: PATH_ORAM_SCHEME.into(),
            value_type: Type::Scalar(ScalarType::Uint(256)),
            key_type: Some(Type::Scalar(ScalarType::Bytes32)),
            capacity: Some(capacity),
            confidential: true,
        }
    }

    #[test]
    fn path_oram_manifest_uses_power_of_two_leaf_count() {
        let object = path_oram_object(9);
        let manifest = OramManifest::for_object(&object).expect("path ORAM manifest");
        let leaf_count = manifest.path_leaf_count().expect("path leaf count");
        assert!(leaf_count.is_power_of_two());
        assert_eq!(leaf_count, 16);
        assert_eq!(manifest.bucket_count, 2 * leaf_count - 1);
        assert_eq!(manifest.tree_height, 4);
    }

    #[test]
    fn theorem_shape_rejects_non_power_of_two_path_leaf_count() {
        let object = path_oram_object(9);
        let mut manifest = OramManifest::for_object(&object).expect("path ORAM manifest");
        manifest.bucket_count = 2 * 12 - 1;
        let err = manifest
            .validate_theorem_shape_for_object(&object)
            .expect_err("non-power-of-two leaf count must be rejected");
        assert!(err
            .to_string()
            .contains("path ORAM leaf count must be a power of two"));
    }
}
