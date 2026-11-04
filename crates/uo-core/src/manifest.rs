use crate::confidential_kernel::{ConfidentialKernelProgram, ConfidentialKernelSlotProgram};
use crate::ir::{BackendKind, ContainerKind, PublicEnvField, StateObject};
use crate::metadata::{DeclassificationKind, ReturnPolicy, StatusPolicy};
use crate::types::{ScalarType, Type};
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uo_precompiles::UoOpcode;

pub const SURROGATE_ORAM_SCHEME: &str = "surrogate_public_schedule_v1";
pub const PATH_ORAM_SCHEME: &str = "path_oram_local_posmap_v1";
pub const PATH_ORAM_PRIVATE_POSMAP_SCHEME: &str = "path_oram_private_posmap_v1";
pub const PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY: usize = 128;

pub fn is_path_oram_scheme(scheme: &str) -> bool {
    scheme == PATH_ORAM_SCHEME || scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME
}

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
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub public_env: Vec<PublicEnvField>,
    #[serde(default)]
    pub entry_input_len: usize,
    #[serde(default, skip_serializing_if = "is_false")]
    pub initializer: bool,
    #[serde(default, skip_serializing_if = "is_false")]
    pub requires_initialized: bool,
    pub public_gas_budget: u64,
    pub arena_bytes: usize,
    pub max_stack_words: usize,
    #[serde(default)]
    pub max_hash_part_bytes: usize,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub return_canonical_len: Option<usize>,
    #[serde(default)]
    pub returns: ReturnPolicy,
    #[serde(default)]
    pub status: StatusPolicy,
    #[serde(default)]
    pub declassifies: Vec<DeclassificationKind>,
    #[serde(default)]
    pub public_state_declassifies: Vec<String>,
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

fn is_false(value: &bool) -> bool {
    !*value
}

#[derive(Debug, PartialEq, Eq)]
pub struct RuntimeConfidentialEntrypointPlan {
    public_object_ids: Box<[u32]>,
    max_kernel_ops: usize,
    max_commit_ops: usize,
    confidential_slot_program: ConfidentialKernelSlotProgram,
    max_hash_part_bytes: usize,
}

impl EntrypointManifest {
    pub fn canonical_kernel_step_manifest(&self) -> Box<[RuntimeKernelStepManifest]> {
        self.confidential_slot_program
            .as_ref()
            .map(ConfidentialKernelSlotProgram::expected_runtime_step_manifest)
            .unwrap_or_else(|| self.kernel_steps.clone().into_boxed_slice())
    }

    pub fn runtime_confidential_entrypoint_plan(
        &self,
        entrypoint: &str,
        public_object_ids: Box<[u32]>,
    ) -> Result<RuntimeConfidentialEntrypointPlan> {
        let confidential_slot_program = self.checked_confidential_slot_program(entrypoint)?;
        let max_kernel_ops = confidential_slot_program
            .expected_runtime_step_witnesses()
            .len();
        Ok(RuntimeConfidentialEntrypointPlan {
            public_object_ids,
            max_kernel_ops,
            max_commit_ops: self.max_commit_ops,
            confidential_slot_program,
            max_hash_part_bytes: self.max_hash_part_bytes,
        })
    }
}

impl RuntimeConfidentialEntrypointPlan {
    pub fn public_object_ids(&self) -> &[u32] {
        &self.public_object_ids
    }

    pub fn max_kernel_ops(&self) -> usize {
        self.max_kernel_ops
    }

    pub fn max_commit_ops(&self) -> usize {
        self.max_commit_ops
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn max_hash_part_bytes(&self) -> usize {
        self.max_hash_part_bytes
    }
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct OramResourceBounds {
    pub scheme: String,
    pub capacity: usize,
    pub metadata_pages: usize,
    pub metadata_pages_per_access: usize,
    pub buckets_per_access: usize,
    pub commit_ops_per_access: usize,
    pub accesses: usize,
    pub commit_ops_for_entrypoint: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct EntrypointResourceBounds {
    pub signature: String,
    pub max_commit_ops: usize,
    pub oram_bounds: Vec<OramResourceBounds>,
}

impl ConfidentialKernelSlotProgram {
    pub fn expected_runtime_step_manifest(&self) -> Box<[RuntimeKernelStepManifest]> {
        self.expected_runtime_steps()
            .iter()
            .map(|step| RuntimeKernelStepManifest {
                opcode: step.opcode,
                object_id: step.object_id,
            })
            .collect::<Vec<_>>()
            .into_boxed_slice()
    }
}

impl OramManifest {
    pub fn path_leaf_count(&self) -> Result<usize> {
        if !is_path_oram_scheme(&self.scheme) {
            bail!("path_leaf_count is only defined for Path ORAM schemes");
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
            scheme @ (PATH_ORAM_SCHEME | PATH_ORAM_PRIVATE_POSMAP_SCHEME) => {
                if scheme == PATH_ORAM_SCHEME && capacity > PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY {
                    bail!(
                        "{} supports capacities up to {} in the current proof-grade route; use a recursive/private position map before admitting capacity {}",
                        PATH_ORAM_SCHEME,
                        PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY,
                        capacity
                    );
                }
                let leaf_count = capacity.max(2).next_power_of_two();
                let tree_height = log2_ceil(leaf_count);
                let block_size = 1 + 8 + 8 + key_bytes + value_bytes;
                let blocks_per_bucket = 5usize;
                let stash_bound = capacity.max(1);
                let position_map_pages = capacity.max(1).div_ceil(8);
                let stash_pages = stash_bound.div_ceil(8);
                let metadata_pages = position_map_pages + stash_pages;
                Ok(Self {
                    scheme: scheme.into(),
                    block_size,
                    bucket_size: 24 + blocks_per_bucket * block_size,
                    bucket_count: 2 * leaf_count - 1,
                    blocks_per_bucket,
                    tree_height,
                    stash_bound,
                    recursion_depth: if scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME {
                        1
                    } else {
                        0
                    },
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

    pub fn resource_bounds_for_capacity(
        &self,
        capacity: usize,
        accesses: usize,
    ) -> OramResourceBounds {
        let commit_ops_per_access = self.total_commit_ops();
        OramResourceBounds {
            scheme: self.scheme.clone(),
            capacity,
            metadata_pages: self.metadata_pages,
            metadata_pages_per_access: self.metadata_pages_per_access,
            buckets_per_access: self.buckets_per_access,
            commit_ops_per_access,
            accesses,
            commit_ops_for_entrypoint: commit_ops_per_access.saturating_mul(accesses),
        }
    }

    /// Whether the scheme admits more than one logical access to the same map
    /// within a single entrypoint. Both Path ORAM schemes do: every access
    /// draws fresh leaves and rewrites its path and the metadata pages, and
    /// the per-entrypoint resource bounds scale with the access count. The
    /// surrogate scheme is single-access.
    pub fn supports_multi_access_per_entrypoint(&self) -> bool {
        is_path_oram_scheme(&self.scheme)
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
            PATH_ORAM_SCHEME | PATH_ORAM_PRIVATE_POSMAP_SCHEME => {
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
                let expected_recursion_depth = if self.scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME {
                    1
                } else {
                    0
                };
                if self.recursion_depth != expected_recursion_depth {
                    bail!("path ORAM recursion_depth does not match position-map route");
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

impl RuntimeManifest {
    pub fn entrypoint_resource_bounds(&self, signature: &str) -> Result<EntrypointResourceBounds> {
        let entrypoint = self
            .entrypoints
            .get(signature)
            .ok_or_else(|| anyhow!("manifest entrypoint {} is missing", signature))?;
        let mut oram_bounds = Vec::new();
        for (object_id, accesses) in &entrypoint.oram_accesses {
            let object = self
                .objects
                .iter()
                .find(|object| object.id == *object_id)
                .ok_or_else(|| anyhow!("manifest object id {} is missing", object_id))?;
            let oram = object
                .oram
                .as_ref()
                .ok_or_else(|| anyhow!("manifest object {} is missing ORAM bounds", object.name))?;
            oram_bounds
                .push(oram.resource_bounds_for_capacity(object.capacity.unwrap_or(0), *accesses));
        }
        Ok(EntrypointResourceBounds {
            signature: signature.into(),
            max_commit_ops: entrypoint.max_commit_ops,
            oram_bounds,
        })
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
                "entrypoint {} performs {} ORAM accesses to {} but scheme {} supports only one logical access per map per entrypoint; multi-access maps must use a Path ORAM scheme ({} or {})",
                signature,
                accesses,
                object.name,
                manifest.scheme,
                PATH_ORAM_SCHEME,
                PATH_ORAM_PRIVATE_POSMAP_SCHEME
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
    use super::{
        validate_oram_access_shape, EntrypointManifest, OramManifest, RuntimeKernelStepManifest,
        RuntimeManifest, StateObjectManifest, PATH_ORAM_PRIVATE_POSMAP_SCHEME, PATH_ORAM_SCHEME,
        SURROGATE_ORAM_SCHEME,
    };
    use crate::confidential_kernel::ConfidentialKernelSlotProgram;
    use crate::ir::{BackendKind, ContainerKind, StateObject};
    use crate::types::{ScalarType, Type};
    use std::collections::BTreeMap;
    use uo_precompiles::UoOpcode;

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

    #[test]
    fn path_oram_local_posmap_rejects_capacity_above_current_ceiling() {
        let object = path_oram_object(super::PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY + 1);
        let err = OramManifest::for_object(&object)
            .expect_err("oversized local-posmap path ORAM capacity must be rejected");
        assert!(err.to_string().contains("supports capacities up to 128"));
    }

    fn private_posmap_object(capacity: usize) -> StateObject {
        StateObject {
            id: 7,
            name: "balances".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
            oram_scheme: PATH_ORAM_PRIVATE_POSMAP_SCHEME.into(),
            value_type: Type::Scalar(ScalarType::Uint(256)),
            key_type: Some(Type::Scalar(ScalarType::Bytes32)),
            capacity: Some(capacity),
            confidential: true,
        }
    }

    #[test]
    fn private_posmap_admits_multi_access_per_entrypoint() {
        // ERC20Lite.transfer reads and writes two balances: four accesses.
        let object = private_posmap_object(256);
        let mut accesses = BTreeMap::new();
        accesses.insert(7u32, 4usize);
        validate_oram_access_shape(
            "transfer(address,address,uint256)",
            &accesses,
            std::slice::from_ref(&object),
        )
        .expect("private-posmap multi-access is supported");
    }

    #[test]
    fn surrogate_rejects_multi_access_with_documented_diagnostic() {
        let object = StateObject {
            oram_scheme: SURROGATE_ORAM_SCHEME.into(),
            ..private_posmap_object(16)
        };
        let mut accesses = BTreeMap::new();
        accesses.insert(7u32, 2usize);
        let err = validate_oram_access_shape(
            "transfer(address,address,uint256)",
            &accesses,
            std::slice::from_ref(&object),
        )
        .expect_err("surrogate multi-access must be rejected");
        let msg = err.to_string();
        assert!(
            msg.contains("only one logical access per map per entrypoint"),
            "unexpected diagnostic: {msg}"
        );
        assert!(
            msg.contains("path_oram_private_posmap_v1"),
            "unexpected diagnostic: {msg}"
        );
    }

    #[test]
    fn local_posmap_admits_multi_access_per_entrypoint() {
        let object = path_oram_object(64);
        let mut accesses = BTreeMap::new();
        accesses.insert(7u32, 4usize);
        validate_oram_access_shape(
            "transfer(address,address,uint256)",
            &accesses,
            std::slice::from_ref(&object),
        )
        .expect("local-posmap multi-access is supported");
    }

    #[test]
    fn entrypoint_resource_bounds_expose_public_oram_cost_formula() {
        let object = path_oram_object(9);
        let oram = OramManifest::for_object(&object).expect("path ORAM manifest");
        let mut entrypoints = BTreeMap::new();
        entrypoints.insert(
            "touch(bytes32)".into(),
            EntrypointManifest {
                secret_args: vec![0],
                param_names: vec!["key".into()],
                public_env: vec![],
                entry_input_len: 32,
                initializer: false,
                requires_initialized: false,
                public_gas_budget: 4096,
                arena_bytes: 4096,
                max_stack_words: 64,
                max_hash_part_bytes: 0,
                return_canonical_len: None,
                returns: Default::default(),
                status: Default::default(),
                declassifies: Vec::new(),
                public_state_declassifies: Vec::new(),
                confidential_program: None,
                confidential_slot_program: None,
                kernel_steps: Vec::new(),
                uocell_reads: 0,
                uocell_writes: 0,
                uoarray_reads: 0,
                uoarray_writes: 0,
                uomap_reads: 0,
                uomap_writes: 1,
                max_commit_ops: oram.total_commit_ops() * 2,
                oram_accesses: BTreeMap::from([(7, 2)]),
            },
        );
        let manifest = RuntimeManifest {
            contract: "Bounds".into(),
            compilation_mode: "uo".into(),
            objects: vec![StateObjectManifest {
                id: 7,
                name: "balances".into(),
                kind: "map".into(),
                backend: "oram".into(),
                capacity: Some(9),
                value_type: Some("uint256".into()),
                key_type: Some("bytes32".into()),
                oram: Some(oram.clone()),
            }],
            entrypoints,
        };

        let bounds = manifest
            .entrypoint_resource_bounds("touch(bytes32)")
            .expect("resource bounds");
        assert_eq!(bounds.max_commit_ops, oram.total_commit_ops() * 2);
        assert_eq!(bounds.oram_bounds[0].capacity, 9);
        assert_eq!(
            bounds.oram_bounds[0].commit_ops_per_access,
            oram.metadata_pages_per_access + oram.buckets_per_access
        );
        assert_eq!(
            bounds.oram_bounds[0].commit_ops_for_entrypoint,
            bounds.oram_bounds[0].commit_ops_per_access * 2
        );
    }

    #[test]
    fn confidential_slot_program_projects_runtime_step_manifest() {
        let program = ConfidentialKernelSlotProgram {
            entrypoint_id: "ping(uint256)".into(),
            param_count: 1,
            return_type: None,
            secret_args: vec![0],
            slot_count: 1,
            body: Box::default(),
        };

        assert_eq!(
            program.expected_runtime_step_manifest(),
            vec![
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::Begin,
                    object_id: None,
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::Commit,
                    object_id: None,
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::Wipe,
                    object_id: None,
                },
            ]
            .into_boxed_slice()
        );
    }

    #[test]
    fn entrypoint_manifest_prefers_slot_program_for_canonical_kernel_steps() {
        let slot_program = ConfidentialKernelSlotProgram {
            entrypoint_id: "ping(uint256)".into(),
            param_count: 1,
            return_type: None,
            secret_args: vec![0],
            slot_count: 1,
            body: Box::default(),
        };
        let manifest = EntrypointManifest {
            secret_args: vec![0],
            param_names: vec!["secret".into()],
            public_env: vec![],
            entry_input_len: 32,
            initializer: false,
            requires_initialized: false,
            public_gas_budget: 4096,
            arena_bytes: 4096,
            max_stack_words: 64,
            max_hash_part_bytes: 0,
            return_canonical_len: None,
            returns: Default::default(),
            status: Default::default(),
            declassifies: Vec::new(),
            public_state_declassifies: Vec::new(),
            confidential_program: None,
            confidential_slot_program: Some(slot_program.clone()),
            kernel_steps: vec![RuntimeKernelStepManifest {
                opcode: UoOpcode::MapPut,
                object_id: Some(99),
            }],
            uocell_reads: 0,
            uocell_writes: 0,
            uoarray_reads: 0,
            uoarray_writes: 0,
            uomap_reads: 0,
            uomap_writes: 0,
            max_commit_ops: 0,
            oram_accesses: BTreeMap::new(),
        };

        assert_eq!(
            manifest.canonical_kernel_step_manifest(),
            slot_program.expected_runtime_step_manifest()
        );
    }
}
