use crate::ir::{BackendKind, ContainerKind, StateObject};
use crate::types::{ScalarType, Type};
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

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
pub struct EntrypointManifest {
    #[serde(default)]
    pub secret_args: Vec<usize>,
    pub public_gas_budget: u64,
    pub arena_bytes: usize,
    pub max_stack_words: usize,
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
        let block_size =
            1 + fixed_scalar_width(key_type)? + fixed_scalar_width(&object.value_type)?;
        let tree_height = log2_ceil(capacity.max(2));
        let metadata_pages = capacity.max(1).div_ceil(8);
        Ok(Self {
            scheme: "surrogate_public_schedule_v1".into(),
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

    pub fn total_commit_ops(&self) -> usize {
        self.metadata_pages_per_access + self.buckets_per_access
    }
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
