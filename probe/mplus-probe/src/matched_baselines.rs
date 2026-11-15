//! The matched baselines (Issue 49 of the external review): the full scan
//! and both Path ORAM schemes, compared at the same key and value widths,
//! capacities and occupancy levels by the bytes of the sealed records their
//! calls move, and by the enclave memory the backend planner's model gives
//! them (`uo_core::backend_plan`).
//!
//! Three maps differ in their key and value widths: SweepMap's 32-byte keys
//! and values, 20-byte keys (`SweepAddressMap`) and 1-byte values
//! (`SweepFlagMap`). Each is compiled on every backend that can hold it at
//! each capacity, filled through the bulk loader to each occupancy level,
//! and called: a read of a stored key and of an absent one, an overwrite of
//! a stored key, and an insert while the map has room. Every call must move
//! the bytes the planner's model gives its backend for a read or a write,
//! whatever the occupancy and whether the key is stored, and at every share
//! of reads the planner must choose the backend whose measured calls move
//! the fewest bytes. The map is also compiled with `backend: auto`, at the
//! planner's default share of reads and at nine reads in ten: its manifest
//! must record the plan the planner makes, the map must be on the backend
//! the plan chose, and a write and a read of one key must move the bytes the
//! plan's model gives that backend and read back what was written. Any of
//! these failing makes one of the report's verdicts false, and `accepted`
//! with it, which the acceptance gate rejects. No external system is run.

use crate::capacity_sweep::break_even_over;
use crate::{compile_artifact_from_metadata, env_usize_list, load_metadata, PROBE_DEPLOY_SEED};
use anyhow::{anyhow, Result};
use serde_json::{json, Value as JsonValue};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use uo_core::backend_plan::{plan_backend, BackendCandidate, CallBytes};
use uo_core::ir::BackendKind;
use uo_core::metadata::BackendPlanMetadata;
use uo_core::{ProgramMode, Type, Value};
use uo_evm::ContractInstance;

pub(crate) const MATCHED_BASELINES_SCHEMA: &str = "uo-matched-baselines-v1";

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
) -> Result<(JsonValue, bool)> {
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
        enclave_memory_budget_bytes: None,
    });
    let artifact = compile_artifact_from_metadata(width.source, &metadata, ProgramMode::Uo)?;
    let (key_type, value_type) = key_type_and_value_type(&artifact)?;
    let plan = plan_backend(capacity, &key_type, &value_type, read_percent, None)?;
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
    let follows = records_plan && on_chosen && moves_modeled_bytes && reads_back;
    Ok((
        json!({
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
        }),
        follows,
    ))
}

pub(crate) fn run_matched_baselines(parameters: &MatchedParameters) -> Result<JsonValue> {
    // No call is timed, so the runtime audits the position-map witness it
    // keeps against a decode of the whole store before and after each call.
    let mut rows = Vec::new();
    let mut cells = Vec::new();
    let mut planner_checks = Vec::new();
    let mut planned_maps = Vec::new();
    let mut break_even = serde_json::Map::new();
    let mut every_call_matches_model = true;
    let mut planner_matches = true;
    let mut planned_maps_follow_their_plans = true;
    for width in &WIDTHS {
        // For each backend and capacity: the bytes of a read and a write, if
        // every call of each kind moved the same.
        let mut measured: BTreeMap<(&'static str, usize), (CallBytes, CallBytes)> = BTreeMap::new();
        for &capacity in &parameters.capacities {
            for (label, backend, scheme) in BACKENDS {
                let mut metadata = load_metadata(width.metadata)?;
                let state = metadata
                    .state
                    .get_mut(MATCHED_MAP)
                    .ok_or_else(|| anyhow!("{} metadata missing its map", width.label))?;
                state.capacity = Some(capacity);
                state.backend = backend.into();
                state.oram_scheme = scheme.map(Into::into);
                let artifact = match compile_artifact_from_metadata(
                    width.source,
                    &metadata,
                    ProgramMode::Uo,
                ) {
                    Ok(artifact) => artifact,
                    Err(err) => {
                        cells.push(json!({
                            "width": width.label,
                            "backend": label,
                            "capacity": capacity,
                            "status": "rejected",
                            "error": format!("{err:#}"),
                        }));
                        continue;
                    }
                };
                let (key_type, value_type) = key_type_and_value_type(&artifact)?;
                let plan = plan_backend(capacity, &key_type, &value_type, None, None)?;
                let model = model_for(&plan.candidates, label)
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
                if let (Some(read), Some(write)) = (reads.first(), writes.first()) {
                    if same(&reads) && same(&writes) {
                        measured.insert((label, capacity), (*read, *write));
                    }
                }
                cells.push(json!({
                    "width": width.label,
                    "backend": label,
                    "capacity": capacity,
                    "status": "ok",
                    "key_bytes": plan.inputs.key_bytes,
                    "value_bytes": plan.inputs.value_bytes,
                    "levels": parameters.levels(capacity),
                    "read_call": model.read_call,
                    "write_call": model.write_call,
                    "modeled_enclave_bytes": model.enclave_bytes,
                    "calls_of_a_kind_move_the_same": same(&reads) && same(&writes),
                }));
            }
            // The map compiled with `backend: auto`.
            for read_percent in PLANNED_READ_PERCENTS {
                let (entry, follows) = run_planned_map(width, capacity, read_percent)?;
                planned_maps_follow_their_plans &= follows;
                planned_maps.push(entry);
            }
            // The planner against the measured calls, at every share of reads.
            for percent in READ_PERCENTS {
                let mixed = |costs: &(CallBytes, CallBytes)| {
                    percent * costs.0.moved() as u64 + (100 - percent) * costs.1.moved() as u64
                };
                let least = BACKENDS
                    .iter()
                    .filter_map(|(label, _, _)| {
                        measured
                            .get(&(*label, capacity))
                            .map(|costs| (*label, mixed(costs)))
                    })
                    .min_by_key(|(_, bytes)| *bytes);
                let Some((least_label, least_bytes)) = least else {
                    continue;
                };
                let (key_type, value_type) = width_types(width);
                let plan = plan_backend(capacity, &key_type, &value_type, Some(percent), None)?;
                let chosen = plan.oram_scheme.clone().unwrap_or(plan.backend.clone());
                let agrees = chosen == least_label;
                planner_matches &= agrees;
                planner_checks.push(json!({
                    "width": width.label,
                    "capacity": capacity,
                    "read_fraction": percent as f64 / 100.0,
                    "planner_chooses": chosen,
                    "fewest_measured_bytes": least_label,
                    "measured_bytes_per_call": least_bytes as f64 / 100.0,
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
    Ok(json!({
        "schema": MATCHED_BASELINES_SCHEMA,
        "accepted": every_call_matches_model
            && planner_matches
            && planned_maps_follow_their_plans,
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
        "planner_chooses_fewest_measured_bytes": planner_matches,
        "planned_maps_follow_their_plans": planned_maps_follow_their_plans,
        "cells": cells,
        "planner_checks": planner_checks,
        "planned_maps": planned_maps,
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
