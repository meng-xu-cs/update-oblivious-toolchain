//! The matched baselines (Issue 49 of the external review): the full scan
//! and both Path ORAM schemes, compared at the same key and value widths,
//! capacities and occupancy levels by the bytes of the sealed records their
//! calls move, and by the enclave memory the backend planner's model gives
//! them (`uo_core::backend_plan`).
//!
//! Three maps differ in their key and value widths: SweepMap's 32-byte keys
//! and values, 20-byte keys (`SweepAddressMap`) and 1-byte values
//! (`SweepFlagMap`). Each is compiled on every backend at each capacity.
//! Which backends can hold it follows from the grid, by the rules of the
//! compiler and the planner (`admissibility`): a Path ORAM scheme holds
//! scalar keys and values, and the local scheme at most 128 entries. Every
//! admissible cell must compile and run, and every other one must be
//! rejected with the diagnostic its rule predicts; the planner must exclude
//! exactly those (Issue 63 of the review of 16 November 2026).
//!
//! A cell is filled through the bulk loader to each occupancy level, and
//! called: a read of a stored key and of an absent one, an overwrite of a
//! stored key, and an insert while the map has room. Every call must move
//! the bytes the planner's model gives its backend for a read or a write,
//! whatever the occupancy and whether the key is stored. At every share of
//! reads the planner must choose the backend whose measured calls move the
//! fewest bytes, and every admissible backend must be measured before they
//! are compared, so that a competitor that went missing fails the report
//! whether or not it would have won.
//!
//! The map is also compiled with `backend: auto`: at the planner's default
//! share of reads, at nine reads in ten, and with an enclave memory budget
//! halfway between the full scan's modeled memory and the private scheme's,
//! which excludes the larger. Its manifest must record the plan the planner
//! makes, the map must be on the backend the plan chose (within the budget,
//! if there is one), and a write and a read of one key must move the bytes
//! the plan's model gives that backend and read back what was written. With
//! a budget that no backend fits, the map must not compile. The report's
//! counts of cells, calls, planner checks and planned maps must be the
//! grid's. Any of these failing makes one of the report's verdicts false,
//! and `accepted` with it, which the acceptance gate rejects. No external
//! system is run.

use crate::capacity_sweep::break_even_over;
use crate::{compile_artifact_from_metadata, env_usize_list, load_metadata, PROBE_DEPLOY_SEED};
use anyhow::{anyhow, Result};
use serde_json::{json, Value as JsonValue};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use uo_core::backend_plan::{plan_backend, BackendCandidate, CallBytes};
use uo_core::ir::BackendKind;
use uo_core::manifest::PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY;
use uo_core::metadata::BackendPlanMetadata;
use uo_core::{ProgramMode, Type, Value};
use uo_evm::ContractInstance;

pub(crate) const MATCHED_BASELINES_SCHEMA: &str = "uo-matched-baselines-v2";

const MATCHED_MAP: &str = "records";

/// The shares of reads, in percent, at which the planner is checked.
const READ_PERCENTS: [u64; 6] = [0, 25, 50, 75, 90, 100];

/// The shares of reads a map compiled with `backend: auto` declares: none,
/// so the planner's default, and nine reads in ten.
const PLANNED_READ_PERCENTS: [Option<u64>; 2] = [None, Some(90)];

/// The backends, as the capacity sweep labels them, with their metadata.
const BACKENDS: [(&str, &str, Option<&str>); 3] = [
    ("full_scan", "full_scan", None),
    (
        "path_oram_local_posmap_v1",
        "oram",
        Some("path_oram_local_posmap_v1"),
    ),
    (
        "path_oram_private_posmap_v1",
        "oram",
        Some("path_oram_private_posmap_v1"),
    ),
];

#[derive(Clone, Copy)]
enum KeyKind {
    Bytes32,
    Address,
}

#[derive(Clone, Copy)]
enum ValueKind {
    Uint,
    Bool,
}

/// A map of one key and value width.
struct Width {
    label: &'static str,
    source: &'static str,
    metadata: &'static str,
    key: KeyKind,
    value: ValueKind,
    read: &'static str,
    put: &'static str,
}

const WIDTHS: [Width; 3] = [
    Width {
        label: "bytes32_to_uint256",
        source: "benches/raw/SweepMap.sol",
        metadata: "benches/raw/SweepMap.pathoram.yaml",
        key: KeyKind::Bytes32,
        value: ValueKind::Uint,
        read: "read(bytes32)",
        put: "put(bytes32,uint256)",
    },
    Width {
        label: "address_to_uint256",
        source: "benches/raw/SweepAddressMap.sol",
        metadata: "benches/raw/SweepAddressMap.yaml",
        key: KeyKind::Address,
        value: ValueKind::Uint,
        read: "read(address)",
        put: "put(address,uint256)",
    },
    Width {
        label: "bytes32_to_bool",
        source: "benches/raw/SweepFlagMap.sol",
        metadata: "benches/raw/SweepFlagMap.yaml",
        key: KeyKind::Bytes32,
        value: ValueKind::Bool,
        read: "read(bytes32)",
        put: "put(bytes32,bool)",
    },
];

impl Width {
    /// The `index`-th key of the map at `capacity`: a hash of the width, the
    /// capacity and the index.
    fn key(&self, capacity: usize, index: u64) -> Value {
        let mut hasher = Sha256::new();
        hasher.update(b"uo-matched-baselines/key/v1");
        hasher.update(self.label.as_bytes());
        hasher.update((capacity as u64).to_be_bytes());
        hasher.update(index.to_be_bytes());
        let digest: [u8; 32] = hasher.finalize().into();
        match self.key {
            KeyKind::Bytes32 => Value::Bytes32(digest),
            KeyKind::Address => {
                let mut address = [0u8; 20];
                address.copy_from_slice(&digest[..20]);
                Value::Address(address)
            }
        }
    }

    /// A value to store: never the zero value, which deletes.
    fn value(&self, index: u64) -> Value {
        match self.value {
            ValueKind::Uint => Value::uint(index + 1),
            ValueKind::Bool => Value::Bool(true),
        }
    }
}

/// The capacities and occupancy levels a profile compares.
pub(crate) struct MatchedParameters {
    capacities: Vec<usize>,
    /// The shares of its capacity a map is filled to, after two keys.
    occupancy_percents: Vec<usize>,
    /// The largest capacity filled to those shares; larger maps hold two
    /// keys.
    occupancy_capacity_limit: usize,
    /// A cell, by width and backend, made to fail to compile: the negative
    /// control of a test. `None` in every profile.
    fail_to_compile: Option<(&'static str, &'static str)>,
}

impl MatchedParameters {
    /// The quick profile, which the validation script runs, fills maps of up
    /// to 1,024 entries to every level and the larger ones to two keys; the
    /// full profile fills every map to every level.
    pub(crate) fn from_env(full: bool) -> Self {
        let capacities = env_usize_list(
            "UO_MATCHED_CAPACITIES",
            &[16, 128, 1024, 2048, 4096, 8192, 16384],
        );
        let largest = capacities.iter().copied().max().unwrap_or(0);
        Self {
            occupancy_percents: env_usize_list("UO_MATCHED_OCCUPANCY_PERCENTS", &[50, 100]),
            occupancy_capacity_limit: crate::env_usize(
                "UO_MATCHED_OCCUPANCY_MAX_CAPACITY",
                if full { largest } else { 1024 },
            ),
            capacities,
            fail_to_compile: None,
        }
    }

    /// The numbers of keys a map of `capacity` is filled to, in order.
    fn levels(&self, capacity: usize) -> Vec<usize> {
        let mut levels = vec![capacity.clamp(1, 2)];
        if capacity <= self.occupancy_capacity_limit {
            for percent in &self.occupancy_percents {
                let keys = (capacity * (*percent).min(100) / 100).clamp(1, capacity);
                if !levels.contains(&keys) {
                    levels.push(keys);
                }
            }
        }
        levels.sort_unstable();
        levels
    }

    /// A test's parameters: maps of `capacities`, each filled to two keys,
    /// and the cell, if any, made to fail to compile.
    #[cfg(test)]
    fn for_test(
        capacities: &[usize],
        fail_to_compile: Option<(&'static str, &'static str)>,
    ) -> Self {
        Self {
            capacities: capacities.to_vec(),
            occupancy_percents: Vec::new(),
            occupancy_capacity_limit: 0,
            fail_to_compile,
        }
    }

    /// The calls a measured cell of `capacity` makes: at each level three,
    /// and an insert while the map has room.
    fn calls(&self, capacity: usize) -> usize {
        let mut stored = 0;
        let mut calls = 0;
        for level in self.levels(capacity) {
            stored = stored.max(level);
            calls += 3;
            if stored < capacity {
                calls += 1;
                stored += 1;
            }
        }
        calls
    }
}

/// Why a backend cannot hold a map, and a part of the diagnostic the
/// compiler rejects it with.
struct Exclusion {
    reason: String,
    diagnostic: String,
}

/// Whether `label` can hold a map of `width` at `capacity`, by the rules of
/// the compiler and the planner: a Path ORAM scheme holds scalar keys and
/// values, and the local scheme at most 128 entries.
fn admissibility(width: &Width, label: &str, capacity: usize) -> Result<(), Exclusion> {
    let (key, value) = width_types(width);
    let scalar = matches!(key, Type::Scalar(_)) && matches!(value, Type::Scalar(_));
    match label {
        "full_scan" => Ok(()),
        _ if !scalar => Err(Exclusion {
            reason: "a Path ORAM map takes scalar keys and values".into(),
            diagnostic: "only supports scalar map key/value types".into(),
        }),
        "path_oram_local_posmap_v1" if capacity > PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY => {
            Err(Exclusion {
                reason: format!(
                    "the local scheme holds at most {PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY} entries"
                ),
                diagnostic: format!(
                    "supports capacities up to {PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY} "
                ),
            })
        }
        _ => Ok(()),
    }
}

/// What one call moved, and what it returned.
struct Moved {
    bytes: CallBytes,
    physical_reads: usize,
    physical_writes: usize,
    gas: u64,
    returned: Option<Value>,
}

fn call(instance: &mut ContractInstance, entrypoint: &str, args: Vec<Value>) -> Result<Moved> {
    let result = instance.call(entrypoint, args)?;
    if result.aborted {
        return Err(anyhow!("{entrypoint} aborted"));
    }
    let trace = &result.trace;
    Ok(Moved {
        bytes: CallBytes {
            read: trace.physical_reads.events().map(|event| event.len).sum(),
            written: trace.physical_writes.events().map(|event| event.len).sum(),
        },
        physical_reads: trace.physical_reads.event_count(),
        physical_writes: trace.physical_writes.event_count(),
        gas: trace.gas_used,
        returned: result.return_value.clone(),
    })
}

fn key_type_and_value_type(artifact: &uo_core::CompiledArtifact) -> Result<(Type, Type)> {
    let object = artifact
        .contract
        .state
        .iter()
        .find(|object| object.name == MATCHED_MAP)
        .ok_or_else(|| anyhow!("matched map missing its {MATCHED_MAP} state"))?;
    let key_type = object
        .key_type
        .clone()
        .ok_or_else(|| anyhow!("matched map has no key type"))?;
    Ok((key_type, object.value_type.clone()))
}

/// The model's candidate for `label` in a plan's candidates.
fn model_for<'a>(candidates: &'a [BackendCandidate], label: &str) -> Option<&'a BackendCandidate> {
    candidates.iter().find(|candidate| {
        candidate
            .oram_scheme
            .as_deref()
            .unwrap_or(candidate.backend.as_str())
            == label
    })
}

/// The map of `width` at `capacity` compiled with `backend: auto`, with
/// `read_percent` declared or left to the planner's default. It follows its
/// plan when its manifest records the plan the planner makes, it is on the
/// backend the plan chose, a write and a read of one key move the bytes the
/// plan's model gives that backend, and the read returns what was written.
fn run_planned_map(
    width: &Width,
    capacity: usize,
    read_percent: Option<u64>,
    budget: Option<usize>,
) -> Result<(JsonValue, bool)> {
    let metadata = planned_metadata(width, capacity, read_percent, budget)?;
    let artifact = compile_artifact_from_metadata(width.source, &metadata, ProgramMode::Uo)?;
    let (key_type, value_type) = key_type_and_value_type(&artifact)?;
    let plan = plan_backend(capacity, &key_type, &value_type, read_percent, budget)?;
    let object = artifact
        .contract
        .state
        .iter()
        .find(|object| object.name == MATCHED_MAP)
        .ok_or_else(|| anyhow!("planned map missing its {MATCHED_MAP} state"))?;
    let records_plan = artifact
        .contract
        .manifest
        .objects
        .iter()
        .find(|manifest_object| manifest_object.id == object.id)
        .and_then(|manifest_object| manifest_object.plan.as_ref())
        == Some(&plan);
    let chosen = plan
        .oram_scheme
        .clone()
        .unwrap_or_else(|| plan.backend.clone());
    let compiled = match object.backend {
        BackendKind::FullScan => "full_scan".to_string(),
        BackendKind::Oram => object.oram_scheme.clone(),
        BackendKind::Raw => "raw".to_string(),
    };
    let model = model_for(&plan.candidates, &chosen)
        .ok_or_else(|| anyhow!("the plan has no candidate {chosen}"))?
        .clone();
    let mut instance = ContractInstance::deploy_with_seed(artifact, PROBE_DEPLOY_SEED)?;
    let key = width.key(capacity, 0);
    let value = width.value(0);
    let write = call(&mut instance, width.put, vec![key.clone(), value.clone()])?;
    let read = call(&mut instance, width.read, vec![key])?;
    let on_chosen = compiled == chosen;
    let moves_modeled_bytes = write.bytes == model.write_call && read.bytes == model.read_call;
    let reads_back = read.returned.as_ref() == Some(&value);
    // With a budget, the backends it excludes: those the map could be on
    // whose modeled enclave memory exceeds it.
    let over_budget: Vec<String> = budget
        .map(|budget| {
            plan.candidates
                .iter()
                .filter(|candidate| {
                    candidate.excluded.is_none() && candidate.enclave_bytes > budget
                })
                .map(|candidate| {
                    candidate
                        .oram_scheme
                        .clone()
                        .unwrap_or_else(|| candidate.backend.clone())
                })
                .collect()
        })
        .unwrap_or_default();
    // The chosen backend fits the budget, which excludes another.
    let within_budget =
        budget.is_none_or(|budget| model.enclave_bytes <= budget && !over_budget.is_empty());
    let follows = records_plan && on_chosen && moves_modeled_bytes && reads_back && within_budget;
    let mut entry = json!({
        "width": width.label,
        "capacity": capacity,
        "read_percent": plan.inputs.read_percent,
        "read_percent_from": if plan.inputs.read_percent_declared {
            "metadata"
        } else {
            "default"
        },
        "planner_chooses": chosen,
        "compiled_backend": compiled,
        "manifest_records_the_plan": records_plan,
        "on_the_chosen_backend": on_chosen,
        "write_call": write.bytes,
        "read_call": read.bytes,
        "moves_the_modeled_bytes": moves_modeled_bytes,
        "reads_back_what_it_wrote": reads_back,
    });
    if let Some(budget) = budget {
        entry["enclave_memory_budget_bytes"] = json!(budget);
        entry["chosen_modeled_enclave_bytes"] = json!(model.enclave_bytes);
        entry["over_budget"] = json!(over_budget);
        entry["within_budget"] = json!(within_budget);
    }
    Ok((entry, follows))
}

/// The map of `width` at `capacity` with `backend: auto` and the plan's
/// inputs.
fn planned_metadata(
    width: &Width,
    capacity: usize,
    read_percent: Option<u64>,
    budget: Option<usize>,
) -> Result<uo_core::ContractMetadata> {
    let mut metadata = load_metadata(width.metadata)?;
    let state = metadata
        .state
        .get_mut(MATCHED_MAP)
        .ok_or_else(|| anyhow!("{} metadata missing its map", width.label))?;
    state.capacity = Some(capacity);
    state.backend = "auto".into();
    state.oram_scheme = None;
    state.plan = Some(BackendPlanMetadata {
        read_percent,
        enclave_memory_budget_bytes: budget,
    });
    Ok(metadata)
}

/// The budget halfway between the full scan's modeled enclave memory and the
/// private scheme's, which excludes the larger, and one byte less than the
/// least of all, which no backend fits.
fn budgets(width: &Width, capacity: usize) -> Result<(usize, usize)> {
    let (key_type, value_type) = width_types(width);
    let plan = plan_backend(capacity, &key_type, &value_type, None, None)?;
    let memory = |label: &str| {
        model_for(&plan.candidates, label)
            .filter(|candidate| candidate.excluded.is_none())
            .map(|candidate| candidate.enclave_bytes)
            .ok_or_else(|| anyhow!("the planner has no model of {label}"))
    };
    let full_scan = memory("full_scan")?;
    let tree = memory("path_oram_private_posmap_v1")?;
    let least = plan
        .candidates
        .iter()
        .filter(|candidate| candidate.excluded.is_none())
        .map(|candidate| candidate.enclave_bytes)
        .min()
        .ok_or_else(|| anyhow!("the planner weighed no backend"))?;
    Ok(((full_scan + tree) / 2, least.saturating_sub(1)))
}

/// The map of `width` at `capacity` with a budget that no backend fits: it
/// must not compile, and the diagnostic must say so.
fn run_impossible_budget(
    width: &Width,
    capacity: usize,
    budget: usize,
) -> Result<(JsonValue, bool)> {
    let metadata = planned_metadata(width, capacity, None, Some(budget))?;
    let predicted = format!(
        "no backend holds a map of {capacity} entries within an enclave memory budget of {budget} bytes"
    );
    let (diagnostic, as_predicted) =
        match compile_artifact_from_metadata(width.source, &metadata, ProgramMode::Uo) {
            Ok(_) => ("it compiled".to_string(), false),
            Err(err) => {
                let diagnostic = format!("{err:#}");
                let as_predicted = diagnostic.contains(&predicted);
                (diagnostic, as_predicted)
            }
        };
    Ok((
        json!({
            "width": width.label,
            "capacity": capacity,
            "enclave_memory_budget_bytes": budget,
            "diagnostic": diagnostic,
            "rejected_as_predicted": as_predicted,
        }),
        as_predicted,
    ))
}

pub(crate) fn run_matched_baselines(parameters: &MatchedParameters) -> Result<JsonValue> {
    // No call is timed, so the runtime audits the position-map witness it
    // keeps against a decode of the whole store before and after each call.
    let mut rows = Vec::new();
    let mut cells = Vec::new();
    let mut planner_checks = Vec::new();
    let mut planned_maps = Vec::new();
    let mut budget_rejections = Vec::new();
    let mut break_even = serde_json::Map::new();
    let mut every_call_matches_model = true;
    let mut every_admissible_cell_measured = true;
    let mut every_inadmissible_cell_rejected_as_predicted = true;
    let mut planner_excludes_the_inadmissible_cells = true;
    let mut planner_matches = true;
    let mut planned_maps_follow_their_plans = true;
    let mut impossible_budgets_rejected = true;
    let mut expected_cells = 0usize;
    let mut expected_measured_cells = 0usize;
    let mut expected_calls = 0usize;
    for width in &WIDTHS {
        // For each backend and capacity: the bytes of a read and a write, if
        // every call of each kind moved the same.
        let mut measured: BTreeMap<(&'static str, usize), (CallBytes, CallBytes)> = BTreeMap::new();
        for &capacity in &parameters.capacities {
            let (key_type, value_type) = width_types(width);
            let unplanned = plan_backend(capacity, &key_type, &value_type, None, None)?;
            for (label, backend, scheme) in BACKENDS {
                expected_cells += 1;
                let rule = admissibility(width, label, capacity);
                let planner_excludes = model_for(&unplanned.candidates, label)
                    .is_none_or(|candidate| candidate.excluded.is_some());
                planner_excludes_the_inadmissible_cells &= planner_excludes == rule.is_err();
                let mut metadata = load_metadata(width.metadata)?;
                let state = metadata
                    .state
                    .get_mut(MATCHED_MAP)
                    .ok_or_else(|| anyhow!("{} metadata missing its map", width.label))?;
                state.capacity = Some(capacity);
                state.backend = backend.into();
                state.oram_scheme = scheme.map(Into::into);
                if parameters.fail_to_compile == Some((width.label, label)) {
                    state.backend = "no_such_backend".into();
                }
                // The grid requires every admissible cell's calls, whether it
                // compiles or not.
                if rule.is_ok() {
                    expected_measured_cells += 1;
                    expected_calls += parameters.calls(capacity);
                }
                let compiled =
                    compile_artifact_from_metadata(width.source, &metadata, ProgramMode::Uo);
                let artifact = match (&rule, compiled) {
                    (Ok(()), Ok(artifact)) => artifact,
                    (Ok(()), Err(err)) => {
                        every_admissible_cell_measured = false;
                        cells.push(json!({
                            "width": width.label,
                            "backend": label,
                            "capacity": capacity,
                            "rule": "admissible",
                            "status": "rejected",
                            "error": format!("{err:#}"),
                        }));
                        continue;
                    }
                    (Err(exclusion), Err(err)) => {
                        let diagnostic = format!("{err:#}");
                        every_inadmissible_cell_rejected_as_predicted &=
                            diagnostic.contains(exclusion.diagnostic.as_str());
                        cells.push(json!({
                            "width": width.label,
                            "backend": label,
                            "capacity": capacity,
                            "rule": format!("inadmissible: {}", exclusion.reason),
                            "predicted_diagnostic": exclusion.diagnostic.trim_end(),
                            "status": "rejected",
                            "error": diagnostic,
                        }));
                        continue;
                    }
                    (Err(exclusion), Ok(_)) => {
                        every_inadmissible_cell_rejected_as_predicted = false;
                        cells.push(json!({
                            "width": width.label,
                            "backend": label,
                            "capacity": capacity,
                            "rule": format!("inadmissible: {}", exclusion.reason),
                            "predicted_diagnostic": exclusion.diagnostic.trim_end(),
                            "status": "compiled",
                        }));
                        continue;
                    }
                };
                let model = model_for(&unplanned.candidates, label)
                    .filter(|candidate| candidate.excluded.is_none())
                    .ok_or_else(|| anyhow!("the planner has no model of {label}"))?
                    .clone();
                let mut instance = ContractInstance::deploy_with_seed(artifact, PROBE_DEPLOY_SEED)?;
                instance.keep_decoded_position_map_witness()?;
                let mut stored = 0u64;
                let mut next = 0u64;
                let mut reads = Vec::new();
                let mut writes = Vec::new();
                for level in parameters.levels(capacity) {
                    let missing = level as u64 - stored.min(level as u64);
                    if missing > 0 {
                        let entries = (next..next + missing)
                            .map(|index| (width.key(capacity, index), width.value(index)))
                            .collect();
                        instance.bulk_load_map_for_diagnostics(MATCHED_MAP, entries)?;
                        instance.keep_decoded_position_map_witness()?;
                        next += missing;
                        stored += missing;
                    }
                    let mut kinds: Vec<(&str, &str, Vec<Value>)> = vec![
                        ("read_hit", width.read, vec![width.key(capacity, 0)]),
                        ("read_miss", width.read, vec![width.key(capacity, u64::MAX)]),
                        (
                            "overwrite",
                            width.put,
                            vec![width.key(capacity, 0), width.value(next + 7)],
                        ),
                    ];
                    if (stored as usize) < capacity {
                        kinds.push((
                            "insert",
                            width.put,
                            vec![width.key(capacity, next), width.value(next)],
                        ));
                    }
                    for (operation, entrypoint, args) in kinds {
                        let moved = call(&mut instance, entrypoint, args)?;
                        let is_read = operation.starts_with("read");
                        let want = if is_read {
                            model.read_call
                        } else {
                            model.write_call
                        };
                        let matches = moved.bytes == want;
                        every_call_matches_model &= matches;
                        if is_read {
                            reads.push(moved.bytes);
                        } else {
                            writes.push(moved.bytes);
                        }
                        if operation == "insert" {
                            next += 1;
                            stored += 1;
                        }
                        rows.push(json!({
                            "width": width.label,
                            "backend": label,
                            "capacity": capacity,
                            "stored_keys": level,
                            "operation": operation,
                            "bytes_read": moved.bytes.read,
                            "bytes_written": moved.bytes.written,
                            "physical_reads": moved.physical_reads,
                            "physical_writes": moved.physical_writes,
                            "gas": moved.gas,
                            "model_bytes_read": want.read,
                            "model_bytes_written": want.written,
                            "matches_model": matches,
                        }));
                    }
                }
                let same = |calls: &[CallBytes]| calls.windows(2).all(|pair| pair[0] == pair[1]);
                let consistent = same(&reads) && same(&writes);
                match (reads.first(), writes.first()) {
                    (Some(read), Some(write)) if consistent => {
                        measured.insert((label, capacity), (*read, *write));
                    }
                    _ => every_admissible_cell_measured = false,
                }
                cells.push(json!({
                    "width": width.label,
                    "backend": label,
                    "capacity": capacity,
                    "rule": "admissible",
                    "status": "ok",
                    "key_bytes": unplanned.inputs.key_bytes,
                    "value_bytes": unplanned.inputs.value_bytes,
                    "levels": parameters.levels(capacity),
                    "read_call": model.read_call,
                    "write_call": model.write_call,
                    "modeled_enclave_bytes": model.enclave_bytes,
                    "calls_of_a_kind_move_the_same": consistent,
                }));
            }
            // The map compiled with `backend: auto`: at the default share of
            // reads, at nine in ten, and within a budget that excludes the
            // backend whose modeled memory is the larger of the full scan's
            // and the private scheme's; and with a budget no backend fits.
            let (halfway, impossible) = budgets(width, capacity)?;
            for (read_percent, budget) in PLANNED_READ_PERCENTS
                .iter()
                .map(|percent| (*percent, None))
                .chain([(None, Some(halfway))])
            {
                let (entry, follows) = run_planned_map(width, capacity, read_percent, budget)?;
                planned_maps_follow_their_plans &= follows;
                planned_maps.push(entry);
            }
            let (entry, as_predicted) = run_impossible_budget(width, capacity, impossible)?;
            impossible_budgets_rejected &= as_predicted;
            budget_rejections.push(entry);
            // The planner against the measured calls, at every share of
            // reads, once every admissible backend is measured.
            let competitors: Vec<&str> = BACKENDS
                .iter()
                .map(|(label, _, _)| *label)
                .filter(|label| admissibility(width, label, capacity).is_ok())
                .collect();
            let missing: Vec<&str> = competitors
                .iter()
                .copied()
                .filter(|label| !measured.contains_key(&(*label, capacity)))
                .collect();
            for percent in READ_PERCENTS {
                let mixed = |costs: &(CallBytes, CallBytes)| {
                    percent * costs.0.moved() as u64 + (100 - percent) * costs.1.moved() as u64
                };
                let least = competitors
                    .iter()
                    .filter_map(|label| {
                        measured
                            .get(&(*label, capacity))
                            .map(|costs| (*label, mixed(costs)))
                    })
                    .min_by_key(|(_, bytes)| *bytes);
                let plan = plan_backend(capacity, &key_type, &value_type, Some(percent), None)?;
                let chosen = plan.oram_scheme.clone().unwrap_or(plan.backend.clone());
                let agrees = missing.is_empty()
                    && least.is_some_and(|(least_label, _)| chosen == least_label);
                planner_matches &= agrees;
                planner_checks.push(json!({
                    "width": width.label,
                    "capacity": capacity,
                    "read_fraction": percent as f64 / 100.0,
                    "competitors": competitors,
                    "missing_competitors": missing,
                    "planner_chooses": chosen,
                    "fewest_measured_bytes": least.map(|(label, _)| label),
                    "measured_bytes_per_call": least.map(|(_, bytes)| bytes as f64 / 100.0),
                    "agrees": agrees,
                }));
            }
        }
        break_even.insert(
            width.label.into(),
            break_even_over(
                &measured,
                &parameters.capacities,
                &READ_PERCENTS,
                &["bytes_moved"],
                |costs: &(CallBytes, CallBytes), _metric, percent| {
                    percent * costs.0.moved() as u64 + (100 - percent) * costs.1.moved() as u64
                },
            ),
        );
    }
    // The counts the grid makes: one cell for each width, capacity and
    // backend; the calls of every admissible cell; one planner check for each
    // share of reads, three planned maps and one impossible budget for each
    // width and capacity.
    let grid = WIDTHS.len() * parameters.capacities.len();
    let expected = json!({
        "cells": expected_cells,
        "measured_cells": expected_measured_cells,
        "rejected_cells": expected_cells - expected_measured_cells,
        "calls": expected_calls,
        "planner_checks": grid * READ_PERCENTS.len(),
        "planned_maps": grid * (PLANNED_READ_PERCENTS.len() + 1),
        "budget_rejections": grid,
    });
    let measured_cells = cells
        .iter()
        .filter(|cell| cell["status"] == json!("ok"))
        .count();
    let counts = json!({
        "cells": cells.len(),
        "measured_cells": measured_cells,
        "rejected_cells": cells.len() - measured_cells,
        "calls": rows.len(),
        "planner_checks": planner_checks.len(),
        "planned_maps": planned_maps.len(),
        "budget_rejections": budget_rejections.len(),
    });
    let counts_are_the_grids = counts == expected;
    Ok(json!({
        "schema": MATCHED_BASELINES_SCHEMA,
        "accepted": every_call_matches_model
            && every_admissible_cell_measured
            && every_inadmissible_cell_rejected_as_predicted
            && planner_excludes_the_inadmissible_cells
            && planner_matches
            && planned_maps_follow_their_plans
            && impossible_budgets_rejected
            && counts_are_the_grids,
        "widths": WIDTHS.iter().map(|width| json!({
            "label": width.label,
            "source": width.source,
            "read": width.read,
            "write": width.put,
        })).collect::<Vec<_>>(),
        "capacities": parameters.capacities,
        "occupancy_percents": parameters.occupancy_percents,
        "occupancy_capacity_limit": parameters.occupancy_capacity_limit,
        "planner_model": uo_core::backend_plan::BACKEND_PLAN_MODEL,
        "every_call_matches_model": every_call_matches_model,
        "every_admissible_cell_measured": every_admissible_cell_measured,
        "every_inadmissible_cell_rejected_as_predicted": every_inadmissible_cell_rejected_as_predicted,
        "planner_excludes_the_inadmissible_cells": planner_excludes_the_inadmissible_cells,
        "planner_chooses_fewest_measured_bytes": planner_matches,
        "planned_maps_follow_their_plans": planned_maps_follow_their_plans,
        "impossible_budgets_rejected": impossible_budgets_rejected,
        "counts_are_the_grids": counts_are_the_grids,
        "expected_counts": expected,
        "counts": counts,
        "cells": cells,
        "planner_checks": planner_checks,
        "planned_maps": planned_maps,
        "budget_rejections": budget_rejections,
        "break_even": break_even,
        "rows": rows,
    }))
}

/// The key and value types of a width's map, as the planner reads them.
fn width_types(width: &Width) -> (Type, Type) {
    use uo_core::ScalarType;
    let key = match width.key {
        KeyKind::Bytes32 => Type::Scalar(ScalarType::Bytes32),
        KeyKind::Address => Type::Scalar(ScalarType::Address),
    };
    let value = match width.value {
        ValueKind::Uint => Type::Scalar(ScalarType::Uint(256)),
        ValueKind::Bool => Type::Scalar(ScalarType::Bool),
    };
    (key, value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use uo_core::ScalarType;

    const VERDICTS: [&str; 9] = [
        "accepted",
        "every_call_matches_model",
        "every_admissible_cell_measured",
        "every_inadmissible_cell_rejected_as_predicted",
        "planner_excludes_the_inadmissible_cells",
        "planner_chooses_fewest_measured_bytes",
        "planned_maps_follow_their_plans",
        "impossible_budgets_rejected",
        "counts_are_the_grids",
    ];

    /// The positive control, on a grid of maps of 16 entries, which every
    /// backend holds, and of 256, which the local scheme does not: every
    /// verdict holds, the local scheme's three cells at 256 entries are
    /// rejected with the compiler's capacity diagnostic, and the counts are
    /// the grid's.
    #[test]
    fn a_small_grid_meets_every_verdict() {
        let report = run_matched_baselines(&MatchedParameters::for_test(&[16, 256], None)).unwrap();
        for verdict in VERDICTS {
            assert_eq!(report[verdict], json!(true), "{verdict}");
        }
        assert_eq!(
            report["counts"],
            json!({
                "cells": 18,
                "measured_cells": 15,
                "rejected_cells": 3,
                "calls": 60,
                "planner_checks": 36,
                "planned_maps": 18,
                "budget_rejections": 6,
            })
        );
        for cell in report["cells"].as_array().unwrap() {
            if cell["status"] == json!("rejected") {
                assert_eq!(cell["backend"], json!("path_oram_local_posmap_v1"));
                assert_eq!(cell["capacity"], json!(256));
                assert_eq!(
                    cell["rule"],
                    json!("inadmissible: the local scheme holds at most 128 entries")
                );
            }
        }
        // The budget halfway between the full scan's modeled memory and the
        // private scheme's excludes the larger, the private scheme at 16
        // entries; the chosen backend fits it and is not one it excludes.
        let budgeted: Vec<&JsonValue> = report["planned_maps"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|map| map.get("enclave_memory_budget_bytes").is_some())
            .collect();
        assert_eq!(budgeted.len(), 6);
        for map in budgeted {
            assert_eq!(map["within_budget"], json!(true), "{map}");
            let over = map["over_budget"].as_array().unwrap();
            assert!(!over.is_empty(), "{map}");
            assert!(!over.contains(&map["planner_chooses"]), "{map}");
            assert!(
                map["chosen_modeled_enclave_bytes"].as_u64()
                    <= map["enclave_memory_budget_bytes"].as_u64()
            );
            if map["capacity"] == json!(16) {
                assert!(
                    over.contains(&json!("path_oram_private_posmap_v1")),
                    "{map}"
                );
            }
        }
    }

    /// The negative control: an admissible cell that fails to compile fails
    /// the report, and the planner checks of its width and capacity name its
    /// backend as missing. The local scheme moves more bytes than the full
    /// scan at 16 entries, so it would not have won; the checks fail all the
    /// same.
    #[test]
    fn a_supported_backend_that_fails_to_compile_fails_the_report() {
        let broken = ("bytes32_to_uint256", "path_oram_local_posmap_v1");
        let report =
            run_matched_baselines(&MatchedParameters::for_test(&[16], Some(broken))).unwrap();
        for verdict in [
            "accepted",
            "every_admissible_cell_measured",
            "planner_chooses_fewest_measured_bytes",
            "counts_are_the_grids",
        ] {
            assert_eq!(report[verdict], json!(false), "{verdict}");
        }
        assert_eq!(report["every_call_matches_model"], json!(true));
        for check in report["planner_checks"].as_array().unwrap() {
            if check["width"] == json!("bytes32_to_uint256") {
                assert_eq!(
                    check["missing_competitors"],
                    json!(["path_oram_local_posmap_v1"])
                );
                assert_eq!(check["fewest_measured_bytes"], json!("full_scan"));
                assert_eq!(check["agrees"], json!(false));
            } else {
                assert_eq!(check["agrees"], json!(true), "{check}");
            }
        }
    }

    /// The model gives every call the capacity sweep's full profile measured
    /// for SweepMap (results/capacity_sweep_full.json): on every backend, at
    /// every capacity and occupancy, the bytes of each read, of each insert,
    /// overwrite, delete and write of the value already stored, and of each
    /// write that aborts.
    #[test]
    fn the_model_gives_every_call_the_full_sweep_measured() {
        let path = crate::workspace_path("results/capacity_sweep_full.json");
        let sweep: JsonValue = serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();
        let key = Type::Scalar(ScalarType::Bytes32);
        let value = Type::Scalar(ScalarType::Uint(256));
        let mut checked = 0;
        for row in sweep["rows"].as_array().unwrap() {
            if row["status"] != "ok" {
                continue;
            }
            let label = row["backend"].as_str().unwrap();
            let capacity = row["capacity"].as_u64().unwrap() as usize;
            let operation = row["operation"].as_str().unwrap();
            let plan = plan_backend(capacity, &key, &value, None, None).unwrap();
            let model = model_for(&plan.candidates, label)
                .filter(|candidate| candidate.excluded.is_none())
                .unwrap_or_else(|| panic!("no model of {label} at {capacity}"));
            let want = if operation.starts_with("read") {
                model.read_call
            } else {
                model.write_call
            };
            let measured = CallBytes {
                read: row["bytes_read"].as_u64().unwrap() as usize,
                written: row["bytes_written"].as_u64().unwrap() as usize,
            };
            assert_eq!(measured, want, "{label} at {capacity}: {operation}");
            checked += 1;
        }
        assert!(checked >= 1000, "{checked} calls");
    }

    /// The planner against the capacity sweep's full profile
    /// (results/capacity_sweep_full.json), SweepMap's 32-byte keys and
    /// values: at every capacity and share of reads the sweep measured, the
    /// planner chooses the backend whose measured calls moved the fewest
    /// bytes, and so never the full scan from the capacity at which the
    /// sweep found the private scheme to move fewer bytes for good.
    #[test]
    fn the_planner_chooses_what_the_full_sweep_measured_least() {
        let path = crate::workspace_path("results/capacity_sweep_full.json");
        let sweep: JsonValue = serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();
        let key = Type::Scalar(ScalarType::Bytes32);
        let value = Type::Scalar(ScalarType::Uint(256));
        let mut least: BTreeMap<(usize, u64), (u64, &str)> = BTreeMap::new();
        let order = |label: &str| BACKENDS.iter().position(|(other, _, _)| *other == label);
        for row in sweep["mix"].as_array().unwrap() {
            let label = row["backend"].as_str().unwrap();
            let capacity = row["capacity"].as_u64().unwrap() as usize;
            let percent = (row["read_fraction"].as_f64().unwrap() * 100.0).round() as u64;
            let bytes = (row["bytes_moved"].as_f64().unwrap() * 100.0).round() as u64;
            let entry = least.entry((capacity, percent)).or_insert((bytes, label));
            if bytes < entry.0 || (bytes == entry.0 && order(label) < order(entry.1)) {
                *entry = (bytes, label);
            }
        }
        assert!(least.len() >= 15 * 6);
        for ((capacity, percent), (_, label)) in &least {
            let plan = plan_backend(*capacity, &key, &value, Some(*percent), None).unwrap();
            let chosen = plan.oram_scheme.clone().unwrap_or(plan.backend.clone());
            assert_eq!(chosen, *label, "capacity {capacity}, {percent}% reads");
        }
        for row in sweep["break_even"].as_array().unwrap() {
            if row["baseline"] != "full_scan" || row["candidate"] != "path_oram_private_posmap_v1" {
                continue;
            }
            let Some(from) = row["bytes_moved_from_capacity"].as_u64() else {
                continue;
            };
            let percent = (row["read_fraction"].as_f64().unwrap() * 100.0).round() as u64;
            for capacity in row["capacities_compared"].as_array().unwrap() {
                let capacity = capacity.as_u64().unwrap();
                if capacity >= from {
                    let plan =
                        plan_backend(capacity as usize, &key, &value, Some(percent), None).unwrap();
                    assert_ne!(
                        plan.backend, "full_scan",
                        "capacity {capacity}, {percent}% reads"
                    );
                }
            }
        }
    }
}
