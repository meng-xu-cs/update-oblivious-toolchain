//! The backend planner: which backend a map that declares `backend: auto`
//! gets (Issue 49 of the external review).
//!
//! The planner reads only public parameters: the map's capacity, the widths
//! of its keys and values, the enclave memory a deployment gives it, and the
//! share of its operations that read, declared or 50 percent. For each
//! backend that can hold the map, the full scan, the local Path ORAM scheme
//! up to its capacity limit and the private scheme, it models the bytes of
//! the sealed records a call of one read moves and a call of one write
//! moves, and the enclave memory a call holds for the map; it takes the
//! backend that moves the fewest bytes per call, at the declared share of
//! reads, among those whose enclave memory fits. Ties go to the full scan,
//! then to the local scheme.
//!
//! The bytes are those a call's trace names (`bytes_read` and
//! `bytes_written` of its physical events). The model counts the records a
//! call reads and writes and the length of each:
//!
//! * the full scan reads every slot of the map, and a call that writes the
//!   map writes every slot back;
//! * the local scheme reads the access counter and every metadata page when
//!   a call loads the map, and the path of its one access, and writes them
//!   all back, for a read and a write alike;
//! * on the private scheme a call reads the counter and the metadata pages
//!   once, and the path of each node access; it writes the path and the
//!   counter at each node access and the metadata pages at the end of each
//!   operation. A read is a get of `h` node accesses, and a write a get and a
//!   put of `4h + 1` node accesses in two operations, `h` the largest height
//!   of an AVL tree of the capacity.
//!
//! The capacity sweep's measurements check the model: every backend, every
//! capacity and every kind of call, at each key and value width the matched
//! baselines run.
//!
//! The enclave memory is a model too: the sealed records a call holds for
//! the map and the plaintext it decodes from them, at their canonical
//! widths, as the runtime allocates them. The full scan holds every slot,
//! sealed and decoded, and a second copy of the decoded entries once the call
//! writes; the local scheme holds the counter, the metadata pages and a path,
//! sealed, and its decoded entries, position map and working stash; the
//! private scheme the same records and its working stash of tree nodes.

use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};

use crate::manifest::{
    path_oram_stash_bound, path_oram_tree_avl_height, path_oram_tree_node_block_size,
    path_oram_tree_stash_bound, PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY,
    PATH_ORAM_PRIVATE_POSMAP_SCHEME, PATH_ORAM_SCHEME,
};
use crate::types::{ScalarType, Type};

/// The planner's model, named in every plan it makes.
pub const BACKEND_PLAN_MODEL: &str = "uo-backend-plan-v1";
/// What the planner minimizes.
pub const BACKEND_PLAN_OBJECTIVE: &str = "bytes_moved_per_call";
/// The share of reads, in percent, of a map that declares none.
pub const DEFAULT_READ_PERCENT: u64 = 50;

const SEALED_UNIT_BYTES: usize = 32;
const SEALED_NONCE_BYTES: usize = 12;
const SEALED_TAG_BYTES: usize = 16;
/// The blocks of a Path ORAM bucket, on both schemes.
const BLOCKS_PER_BUCKET: usize = 5;
/// The bytes of a bucket besides its blocks.
const BUCKET_HEADER_BYTES: usize = 24;
/// The blocks of a metadata page.
const PAGE_BLOCKS: usize = 8;
/// The bytes of the access counter.
const COUNTER_BYTES: usize = 8;
/// The bytes of a position-map entry the local scheme decodes.
const POSITION_ENTRY_BYTES: usize = 9;

/// The length of a sealed record of `payload` bytes: nonce, ciphertext and
/// tag in 32-byte units, each of which begins with a marker byte
/// (`uo_store::sealed_record_len`).
pub fn sealed_record_bytes(payload: usize) -> usize {
    SEALED_UNIT_BYTES
        * (SEALED_NONCE_BYTES + payload + SEALED_TAG_BYTES).div_ceil(SEALED_UNIT_BYTES - 1)
}

/// The bytes of the sealed records a call reads and writes.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CallBytes {
    pub read: usize,
    pub written: usize,
}

impl CallBytes {
    pub fn moved(&self) -> usize {
        self.read + self.written
    }
}

/// A backend the planner weighed.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackendCandidate {
    /// `full_scan` or `oram`.
    pub backend: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub oram_scheme: Option<String>,
    /// Why the backend cannot hold the map, if it cannot; its costs are then
    /// zero.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub excluded: Option<String>,
    /// A call that reads the map once.
    pub read_call: CallBytes,
    /// A call that writes the map once.
    pub write_call: CallBytes,
    /// The bytes per call at the share of reads, times 100.
    pub mixed_bytes_times_100: u64,
    /// The enclave memory a call holds for the map.
    pub enclave_bytes: usize,
    /// Whether the enclave memory fits the budget.
    pub fits_budget: bool,
}

/// What the planner read.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackendPlanInputs {
    pub capacity: usize,
    pub key_type: String,
    pub value_type: String,
    pub key_bytes: usize,
    pub value_bytes: usize,
    /// Reads among the map's operations, in percent.
    pub read_percent: u64,
    pub read_percent_declared: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub enclave_memory_budget_bytes: Option<usize>,
}

/// The planner's choice for a map, with what it read and weighed.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackendPlan {
    pub model: String,
    pub objective: String,
    pub inputs: BackendPlanInputs,
    pub candidates: Vec<BackendCandidate>,
    pub backend: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub oram_scheme: Option<String>,
}

/// The width of a Path ORAM map's key or value, which must be a scalar.
fn oram_scalar_width(ty: &Type) -> Option<usize> {
    match ty {
        Type::Scalar(ScalarType::Bool) => Some(1),
        Type::Scalar(ScalarType::Uint(_)) | Type::Scalar(ScalarType::Bytes32) => Some(32),
        Type::Scalar(ScalarType::Address) => Some(20),
        _ => None,
    }
}

fn log2_ceil(value: usize) -> usize {
    value.max(1).next_power_of_two().ilog2() as usize
}

/// The full scan's costs: every slot read, and written back by a write.
fn full_scan_costs(
    capacity: usize,
    key_bytes: usize,
    value_bytes: usize,
) -> (CallBytes, CallBytes, usize) {
    let entry = 1 + key_bytes + value_bytes;
    let slots = capacity * sealed_record_bytes(entry);
    let read = CallBytes {
        read: slots,
        written: 0,
    };
    let write = CallBytes {
        read: slots,
        written: slots,
    };
    // Every slot sealed and decoded, and the decoded entries the call loaded,
    // which it keeps once it writes.
    let enclave = slots + 2 * capacity * entry;
    (read, write, enclave)
}

/// A Path ORAM tree's shared terms: the path length, and the lengths of a
/// sealed bucket, metadata page and access counter.
struct PathTerms {
    path_buckets: usize,
    bucket: usize,
    page: usize,
    counter: usize,
}

fn path_terms(capacity: usize, block: usize) -> PathTerms {
    let leaf_count = capacity.max(2).next_power_of_two();
    PathTerms {
        path_buckets: log2_ceil(leaf_count) + 1,
        bucket: sealed_record_bytes(BUCKET_HEADER_BYTES + BLOCKS_PER_BUCKET * block),
        page: sealed_record_bytes(PAGE_BLOCKS * block),
        counter: sealed_record_bytes(COUNTER_BYTES),
    }
}

/// The local scheme's costs: the counter, the metadata pages and one path,
/// read and written back by a read and a write alike.
fn local_costs(
    capacity: usize,
    key_bytes: usize,
    value_bytes: usize,
) -> (CallBytes, CallBytes, usize) {
    let block = 1 + 8 + 8 + key_bytes + value_bytes;
    let terms = path_terms(capacity, block);
    let stash = path_oram_stash_bound(capacity);
    let pages = capacity.max(1).div_ceil(PAGE_BLOCKS) + stash.div_ceil(PAGE_BLOCKS);
    let records = terms.counter + pages * terms.page + terms.path_buckets * terms.bucket;
    let call = CallBytes {
        read: records,
        written: records,
    };
    let working_stash = stash + terms.path_buckets * BLOCKS_PER_BUCKET;
    let enclave = records
        + capacity * (1 + key_bytes + value_bytes + POSITION_ENTRY_BYTES)
        + working_stash * block;
    (call, call, enclave)
}

/// The private scheme's costs: a read is one get, a write a get and a put.
fn tree_costs(
    capacity: usize,
    key_bytes: usize,
    value_bytes: usize,
) -> (CallBytes, CallBytes, usize) {
    let block = path_oram_tree_node_block_size(key_bytes, value_bytes);
    let terms = path_terms(capacity, block);
    let stash = path_oram_tree_stash_bound(capacity);
    let pages = 1 + stash.div_ceil(PAGE_BLOCKS);
    let height = path_oram_tree_avl_height(capacity);
    let call = |node_accesses: usize, operations: usize| CallBytes {
        read: terms.counter
            + pages * terms.page
            + node_accesses * terms.path_buckets * terms.bucket,
        written: node_accesses * (terms.path_buckets * terms.bucket + terms.counter)
            + operations * pages * terms.page,
    };
    let read = call(height, 1);
    let write = call(height + 3 * height + 1, 2);
    let working_stash = stash + terms.path_buckets * BLOCKS_PER_BUCKET;
    let enclave = terms.counter
        + pages * terms.page
        + terms.path_buckets * terms.bucket
        + working_stash * block;
    (read, write, enclave)
}

/// The bytes per call of a mix with `read_percent` reads, times 100.
fn mixed_times_100(read: &CallBytes, write: &CallBytes, read_percent: u64) -> u64 {
    read_percent * read.moved() as u64 + (100 - read_percent) * write.moved() as u64
}

/// The plan for a map of `capacity` entries from `key_type` to
/// `value_type`, with `read_percent` reads (50 if `None`) and the enclave
/// memory budget, if any.
pub fn plan_backend(
    capacity: usize,
    key_type: &Type,
    value_type: &Type,
    read_percent: Option<u64>,
    enclave_memory_budget_bytes: Option<usize>,
) -> Result<BackendPlan> {
    if capacity == 0 {
        bail!("a map of capacity 0 has no backend to plan");
    }
    let declared = read_percent.is_some();
    let read_percent = read_percent.unwrap_or(DEFAULT_READ_PERCENT);
    if read_percent > 100 {
        bail!("a map's read percent is at most 100, not {read_percent}");
    }
    let key_bytes = key_type.canonical_len();
    let value_bytes = value_type.canonical_len();
    let scalar = oram_scalar_width(key_type).is_some() && oram_scalar_width(value_type).is_some();
    let fits = |enclave: usize| enclave_memory_budget_bytes.is_none_or(|budget| enclave <= budget);
    let mut candidates = Vec::new();
    let mut push = |backend: &str,
                    scheme: Option<&str>,
                    excluded: Option<String>,
                    costs: Option<(CallBytes, CallBytes, usize)>| {
        let (read_call, write_call, enclave_bytes) = costs.unwrap_or_default();
        candidates.push(BackendCandidate {
            backend: backend.into(),
            oram_scheme: scheme.map(Into::into),
            fits_budget: excluded.is_none() && fits(enclave_bytes),
            excluded,
            read_call,
            write_call,
            mixed_bytes_times_100: mixed_times_100(&read_call, &write_call, read_percent),
            enclave_bytes,
        });
    };
    push(
        "full_scan",
        None,
        None,
        Some(full_scan_costs(capacity, key_bytes, value_bytes)),
    );
    if !scalar {
        let reason = "Path ORAM maps take scalar keys and values".to_string();
        push("oram", Some(PATH_ORAM_SCHEME), Some(reason.clone()), None);
        push(
            "oram",
            Some(PATH_ORAM_PRIVATE_POSMAP_SCHEME),
            Some(reason),
            None,
        );
    } else {
        if capacity > PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY {
            push(
                "oram",
                Some(PATH_ORAM_SCHEME),
                Some(format!(
                    "the local scheme holds at most {PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY} entries"
                )),
                None,
            );
        } else {
            push(
                "oram",
                Some(PATH_ORAM_SCHEME),
                None,
                Some(local_costs(capacity, key_bytes, value_bytes)),
            );
        }
        push(
            "oram",
            Some(PATH_ORAM_PRIVATE_POSMAP_SCHEME),
            None,
            Some(tree_costs(capacity, key_bytes, value_bytes)),
        );
    }
    // The first candidate of least bytes that fits: the order breaks ties.
    let Some(chosen) = candidates
        .iter()
        .filter(|candidate| candidate.fits_budget)
        .min_by_key(|candidate| candidate.mixed_bytes_times_100)
        .cloned()
    else {
        bail!(
            "no backend holds a map of {capacity} entries within an enclave memory budget of {} bytes",
            enclave_memory_budget_bytes.unwrap_or(0)
        );
    };
    Ok(BackendPlan {
        model: BACKEND_PLAN_MODEL.into(),
        objective: BACKEND_PLAN_OBJECTIVE.into(),
        inputs: BackendPlanInputs {
            capacity,
            key_type: key_type.short_name(),
            value_type: value_type.short_name(),
            key_bytes,
            value_bytes,
            read_percent,
            read_percent_declared: declared,
            enclave_memory_budget_bytes,
        },
        candidates,
        backend: chosen.backend,
        oram_scheme: chosen.oram_scheme,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bytes32() -> Type {
        Type::Scalar(ScalarType::Bytes32)
    }

    fn uint256() -> Type {
        Type::Scalar(ScalarType::Uint(256))
    }

    fn candidate<'a>(plan: &'a BackendPlan, label: &str) -> &'a BackendCandidate {
        plan.candidates
            .iter()
            .find(|candidate| {
                candidate
                    .oram_scheme
                    .as_deref()
                    .unwrap_or(candidate.backend.as_str())
                    == label
            })
            .unwrap()
    }

    fn bytes(read: usize, written: usize) -> CallBytes {
        CallBytes { read, written }
    }

    /// The model gives the bytes the capacity sweep's full profile measured
    /// for SweepMap's reads and writes (results/capacity_sweep_full.json).
    #[test]
    fn the_model_gives_the_bytes_the_sweep_measured() {
        let cases = [
            ("full_scan", 16, bytes(1536, 0), bytes(1536, 1536)),
            (
                "full_scan",
                16384,
                bytes(1_572_864, 0),
                bytes(1_572_864, 1_572_864),
            ),
            (
                "path_oram_local_posmap_v1",
                16,
                bytes(5280, 5280),
                bytes(5280, 5280),
            ),
            (
                "path_oram_local_posmap_v1",
                128,
                bytes(26432, 26432),
                bytes(26432, 26432),
            ),
            (
                "path_oram_private_posmap_v1",
                16,
                bytes(19840, 20096),
                bytes(73600, 77856),
            ),
            (
                "path_oram_private_posmap_v1",
                1024,
                bytes(129_344, 130_176),
                bytes(447_200, 476_576),
            ),
            (
                "path_oram_private_posmap_v1",
                16384,
                bytes(219_360, 220_512),
                bytes(804_000, 836_640),
            ),
        ];
        for (label, capacity, read, write) in cases {
            let plan = plan_backend(capacity, &bytes32(), &uint256(), None, None).unwrap();
            let model = candidate(&plan, label);
            assert_eq!(
                (model.read_call, model.write_call),
                (read, write),
                "{label} {capacity}"
            );
        }
    }

    /// The full scan moves the fewest bytes for small maps and the private
    /// scheme for large ones; reads favour the tree sooner than writes do.
    #[test]
    fn the_planner_takes_the_fewest_bytes() {
        let chosen = |capacity, percent| {
            let plan = plan_backend(capacity, &bytes32(), &uint256(), Some(percent), None).unwrap();
            plan.oram_scheme.unwrap_or(plan.backend)
        };
        assert_eq!(chosen(16, 50), "full_scan");
        assert_eq!(chosen(16384, 50), "path_oram_private_posmap_v1");
        assert_eq!(chosen(16384, 0), "path_oram_private_posmap_v1");
        let plan = plan_backend(4096, &bytes32(), &uint256(), None, None).unwrap();
        assert_eq!(plan.inputs.read_percent, DEFAULT_READ_PERCENT);
        assert!(!plan.inputs.read_percent_declared);
        // Every candidate is weighed, the local scheme excluded past its limit.
        assert_eq!(plan.candidates.len(), 3);
        assert!(candidate(&plan, "path_oram_local_posmap_v1")
            .excluded
            .is_some());
    }

    /// A budget excludes the backends whose enclave memory exceeds it: a
    /// full scan of 4,096 entries holds every slot, sealed and decoded.
    #[test]
    fn a_budget_excludes_what_does_not_fit() {
        let unbounded = plan_backend(4096, &bytes32(), &uint256(), Some(50), None).unwrap();
        let full_scan = candidate(&unbounded, "full_scan").enclave_bytes;
        let tree = candidate(&unbounded, "path_oram_private_posmap_v1").enclave_bytes;
        assert!(tree < full_scan);
        let budget = (tree + full_scan) / 2;
        let planned = plan_backend(4096, &bytes32(), &uint256(), Some(50), Some(budget)).unwrap();
        assert!(!candidate(&planned, "full_scan").fits_budget);
        assert_eq!(planned.backend, "oram");
        assert_eq!(
            planned.oram_scheme.as_deref(),
            Some(PATH_ORAM_PRIVATE_POSMAP_SCHEME)
        );
        let none_fits = plan_backend(4096, &bytes32(), &uint256(), Some(50), Some(tree - 1));
        assert!(none_fits.is_err());
    }

    /// A map with a key or value that is not a scalar can only be scanned.
    #[test]
    fn a_map_of_structured_values_is_scanned() {
        let value = Type::Array(Box::new(uint256()), 4);
        let plan = plan_backend(16384, &bytes32(), &value, Some(100), None).unwrap();
        assert_eq!(plan.backend, "full_scan");
        assert_eq!(plan.oram_scheme, None);
        assert!(plan
            .candidates
            .iter()
            .filter(|c| c.backend == "oram")
            .all(|c| c.excluded.is_some()));
        assert!(plan_backend(16, &bytes32(), &uint256(), Some(101), None).is_err());
        assert!(plan_backend(0, &bytes32(), &uint256(), None, None).is_err());
    }
}
