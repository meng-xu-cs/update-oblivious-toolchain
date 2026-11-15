//! The storage-boundary report: what a store that keeps a contract's sealed
//! records sees of a call, next to what the call's trace says.
//!
//! The runtime hands every record it seals to a `StorageAdapter`, and names
//! to it every record it opens. The adapter logs both from its own side: a
//! read with the record it holds, a write with the class it computes from
//! the record it held and the one it is handed. The call's recorder writes
//! the trace; the adapter writes this log. The report runs every benchmark
//! on every sealed backend and compares the two.
//!
//! What it finds, and checks from then on:
//!
//! - The store's writes are the trace's writes of sealed objects, one for
//!   one and in order, and the store classifies each as an `Update`.
//! - The store's reads of each sealed object are the trace's reads of it,
//!   one for one and in order: every slot of an exact object (a cell, an
//!   array, a full-scan map), where the call loads it; and the counter and
//!   the metadata pages of an ORAM map, where the call loads the map and
//!   which it holds through the call, then the buckets of each access.
//! - So the store sees every read the trace names, and no other.
//!
//! The report then runs each benchmark on a store that keeps its records in
//! files, drops the runtime after the workload's calls, and starts another
//! from the files alone. The restarted runtime must answer the workload's
//! reads as the first one did and seal no record under a nonce the files
//! already hold.

use crate::capacity_sweep::WitnessAuditOff;
use crate::{
    artifact_backend_label, benchmark_workloads, BenchArtifacts, BenchmarkWorkload, CallSpec,
    PROBE_DEPLOY_SEED,
};
use anyhow::{anyhow, bail, Context, Result};
use serde_json::{json, Value as JsonValue};
use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;
use uo_core::ir::BackendKind;
use uo_core::{CompiledArtifact, PublicReceipt, Value, WriteClass};
use uo_evm::{
    ContractInstance, FileStorage, MemoryStorage, SharedStorage, StorageAdapter, StorageIo,
    SyncPolicy,
};

pub(crate) const STORAGE_BOUNDARY_SCHEMA: &str = "uo-storage-boundary-v2";

/// The sealed objects of an artifact.
fn sealed_objects(artifact: &CompiledArtifact) -> BTreeSet<String> {
    artifact
        .contract
        .state
        .iter()
        .filter(|object| object.backend != BackendKind::Raw)
        .map(|object| object.name.clone())
        .collect()
}

/// What one call's store log and trace say, and whether they agree.
#[derive(Default)]
struct CallComparison {
    store_reads: usize,
    store_read_bytes: usize,
    store_writes: usize,
    store_written_bytes: usize,
    traced_reads: usize,
    traced_read_bytes: usize,
    traced_writes: usize,
    traced_written_bytes: usize,
    traced_public_reads: usize,
    traced_public_writes: usize,
    store_writes_equal_traced_writes: bool,
    store_classifies_every_write_as_update: bool,
    store_reads_equal_traced_reads: bool,
    /// The first difference, for a report that fails.
    difference: Option<String>,
}

fn compare_call(
    artifact: &CompiledArtifact,
    log: &[StorageIo],
    receipt: &PublicReceipt,
) -> CallComparison {
    let sealed = sealed_objects(artifact);
    let mut comparison = CallComparison::default();

    let traced_writes: Vec<(String, String, usize, WriteClass)> = receipt
        .physical_writes
        .events()
        .filter_map(|event| {
            if sealed.contains(&event.object) {
                Some((event.object, event.location, event.len, event.class))
            } else {
                comparison.traced_public_writes += 1;
                None
            }
        })
        .collect();
    let store_writes: Vec<(String, String, usize, WriteClass)> = log
        .iter()
        .filter_map(|io| match io {
            StorageIo::Write {
                object,
                location,
                len,
                class,
            } => Some((object.clone(), location.clone(), *len, *class)),
            StorageIo::Read { .. } => None,
        })
        .collect();
    comparison.traced_writes = traced_writes.len();
    comparison.traced_written_bytes = traced_writes.iter().map(|write| write.2).sum();
    comparison.store_writes = store_writes.len();
    comparison.store_written_bytes = store_writes.iter().map(|write| write.2).sum();
    comparison.store_writes_equal_traced_writes = store_writes == traced_writes;
    comparison.store_classifies_every_write_as_update = store_writes
        .iter()
        .all(|write| write.3 == WriteClass::Update);
    if !comparison.store_writes_equal_traced_writes {
        let index = store_writes
            .iter()
            .zip(traced_writes.iter())
            .position(|(store, traced)| store != traced)
            .unwrap_or_else(|| store_writes.len().min(traced_writes.len()));
        comparison.difference = Some(format!(
            "write {index}: the store has {:?}, the trace {:?}",
            store_writes.get(index),
            traced_writes.get(index)
        ));
    }

    // Per object: the trace's reads against the store's, one for one and in
    // order.
    let mut traced_reads: BTreeMap<String, Vec<(String, usize)>> = BTreeMap::new();
    for event in receipt.physical_reads.events() {
        if !sealed.contains(&event.object) {
            comparison.traced_public_reads += 1;
            continue;
        }
        comparison.traced_reads += 1;
        comparison.traced_read_bytes += event.len;
        traced_reads
            .entry(event.object)
            .or_default()
            .push((event.location, event.len));
    }
    let mut store_reads: BTreeMap<String, Vec<(String, usize)>> = BTreeMap::new();
    for io in log {
        if let StorageIo::Read {
            object,
            location,
            len,
        } = io
        {
            comparison.store_reads += 1;
            comparison.store_read_bytes += len;
            store_reads
                .entry(object.clone())
                .or_default()
                .push((location.clone(), *len));
        }
    }
    comparison.store_reads_equal_traced_reads = store_reads == traced_reads;
    if !comparison.store_reads_equal_traced_reads && comparison.difference.is_none() {
        let objects: BTreeSet<&String> = store_reads.keys().chain(traced_reads.keys()).collect();
        for object in objects {
            let store = store_reads.get(object).map(Vec::as_slice).unwrap_or(&[]);
            let traced = traced_reads.get(object).map(Vec::as_slice).unwrap_or(&[]);
            if store != traced {
                let index = store
                    .iter()
                    .zip(traced.iter())
                    .position(|(store, traced)| store != traced)
                    .unwrap_or_else(|| store.len().min(traced.len()));
                comparison.difference = Some(format!(
                    "read {index} of {object}: the store has {:?}, the trace {:?}",
                    store.get(index),
                    traced.get(index)
                ));
                break;
            }
        }
    }
    comparison
}

impl CallComparison {
    fn agrees(&self) -> bool {
        self.store_writes_equal_traced_writes
            && self.store_classifies_every_write_as_update
            && self.store_reads_equal_traced_reads
    }

    fn row(&self, role: &str, call: &CallSpec, aborted: bool) -> JsonValue {
        let mut row = json!({
            "role": role,
            "entrypoint": call.entrypoint,
            "aborted": aborted,
            "store": {
                "reads": self.store_reads,
                "read_bytes": self.store_read_bytes,
                "writes": self.store_writes,
                "written_bytes": self.store_written_bytes,
            },
            "trace": {
                "sealed_reads": self.traced_reads,
                "sealed_read_bytes": self.traced_read_bytes,
                "sealed_writes": self.traced_writes,
                "sealed_written_bytes": self.traced_written_bytes,
                "public_reads": self.traced_public_reads,
                "public_writes": self.traced_public_writes,
            },
            "store_writes_equal_traced_writes": self.store_writes_equal_traced_writes,
            "store_classifies_every_write_as_update": self.store_classifies_every_write_as_update,
            "store_reads_equal_traced_reads": self.store_reads_equal_traced_reads,
        });
        if let Some(difference) = &self.difference {
            row["first_difference"] = json!(difference);
        }
        row
    }
}

/// The calls of a workload in the order they run, each with its role.
fn workload_calls(workload: &BenchmarkWorkload) -> Vec<(&'static str, &CallSpec)> {
    workload
        .setup
        .iter()
        .map(|call| ("setup", call))
        .chain(std::iter::once(("target", &workload.target)))
        .chain(workload.getters.iter().map(|call| ("getter", call)))
        .collect()
}

/// The sealed variants of a benchmark, by the label the overhead report
/// gives each.
fn sealed_variants(artifacts: &BenchArtifacts) -> Vec<(String, &CompiledArtifact)> {
    let mut variants = vec![(artifact_backend_label(&artifacts.uo), &artifacts.uo)];
    if let Some(artifact) = artifacts.fullscan64.as_ref() {
        variants.push(("full_scan_64".to_string(), artifact));
    }
    if let Some(artifact) = artifacts.oram.as_ref() {
        variants.push(("oram".to_string(), artifact));
    }
    if let Some(artifact) = artifacts.private_posmap.as_ref() {
        variants.push(("oram_private_posmap".to_string(), artifact));
    }
    variants
}

/// What a workload's reads returned and showed, to compare a restarted run
/// with.
type GetterOutcome = (Option<Value>, PublicReceipt);

struct BoundaryRun {
    row: JsonValue,
    agrees: bool,
    totals: BoundaryTotals,
    getters: Vec<GetterOutcome>,
}

#[derive(Default)]
struct BoundaryTotals {
    calls: usize,
    store_reads: usize,
    store_writes: usize,
    traced_reads: usize,
    traced_writes: usize,
}

/// Run a workload on a store in memory and compare each call's log with its
/// trace. The calls are timed by no one, so the witness is kept from the
/// deployment on and the audit is off: neither then opens a record inside a
/// call, where the store would log it.
fn run_boundary(
    workload: &BenchmarkWorkload,
    backend: &str,
    artifact: &CompiledArtifact,
) -> Result<BoundaryRun> {
    let _audit_off = WitnessAuditOff::new();
    let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), PROBE_DEPLOY_SEED)?;
    instance.keep_decoded_position_map_witness()?;
    let mut calls = Vec::new();
    let mut agrees = true;
    let mut totals = BoundaryTotals::default();
    let mut getters = Vec::new();
    for (role, call) in workload_calls(workload) {
        let result = instance
            .call(call.entrypoint, call.args.clone())
            .with_context(|| format!("{role} call {}", call.entrypoint))?;
        let comparison = compare_call(artifact, &instance.storage_io_log(), &result.trace.receipt);
        agrees &= comparison.agrees();
        totals.calls += 1;
        totals.store_reads += comparison.store_reads;
        totals.store_writes += comparison.store_writes;
        totals.traced_reads += comparison.traced_reads;
        totals.traced_writes += comparison.traced_writes;
        calls.push(comparison.row(role, call, result.aborted));
        if role == "getter" {
            getters.push((result.return_value, result.trace.receipt));
        }
    }
    Ok(BoundaryRun {
        row: json!({
            "benchmark": workload.label,
            "backend": backend,
            "sealed_objects": sealed_objects(artifact).into_iter().collect::<Vec<_>>(),
            "calls": calls,
            "store_log_agrees_with_trace": agrees,
        }),
        agrees,
        totals,
        getters,
    })
}

fn scratch_directory(label: &str) -> PathBuf {
    let name: String = label
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect();
    std::env::temp_dir().join(format!("uo-storage-boundary-{}-{name}", std::process::id()))
}

/// The seal counts the store holds for each sealed object, and the count it
/// has reserved for the object's key.
fn nonce_state(
    storage: &SharedStorage,
    artifact: &CompiledArtifact,
) -> BTreeMap<String, (Vec<u64>, u64)> {
    sealed_objects(artifact)
        .into_iter()
        .map(|object| {
            let state = storage.with(|adapter| {
                (
                    adapter.seal_counts(&object),
                    adapter.reserved_seals(&object),
                )
            });
            (object, state)
        })
        .collect()
}

/// Run a workload's writes on a store that keeps its records in files, drop
/// the runtime, start another from the files, and run the workload's reads
/// on it. The reads must return and show what `expected` did, on a runtime
/// that never restarted, and the restarted runtime must seal no record
/// under a nonce the files held before.
fn run_restart(
    workload: &BenchmarkWorkload,
    backend: &str,
    artifact: &CompiledArtifact,
    expected: &[GetterOutcome],
) -> Result<(JsonValue, bool)> {
    let _audit_off = WitnessAuditOff::new();
    let directory = scratch_directory(&format!("{}-{backend}", workload.label));
    let _ = std::fs::remove_dir_all(&directory);
    let outcome = (|| -> Result<(JsonValue, bool)> {
        let storage = SharedStorage::new(FileStorage::create(&directory, SyncPolicy::Never)?);
        let mut instance = ContractInstance::deploy_with_seed_and_storage(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage.clone(),
        )?;
        instance.keep_decoded_position_map_witness()?;
        let deployed_bytes = instance.storage_stats().persisted_bytes;
        let mut journal_bytes = Vec::new();
        let mut rollback_counter = 0u64;
        for call in workload
            .setup
            .iter()
            .chain(std::iter::once(&workload.target))
        {
            let before = instance.storage_stats().persisted_bytes;
            let result = instance.call(call.entrypoint, call.args.clone())?;
            if !result.aborted {
                rollback_counter += 1;
            }
            journal_bytes.push(json!({
                "entrypoint": call.entrypoint,
                "bytes": instance.storage_stats().persisted_bytes - before,
            }));
        }
        let public_state = instance.public_state_digest()?;
        let sealed_records = storage.with(|adapter| adapter.sealed_records_sha256());
        let before = nonce_state(&storage, artifact);
        drop(instance);
        drop(storage);

        let reopen = || -> Result<SharedStorage> {
            Ok(SharedStorage::new(FileStorage::open(
                &directory,
                SyncPolicy::Never,
            )?))
        };
        // A stale attested counter and another deployment's secret are
        // refused before anything is restored.
        let stale_counter_refused = ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            reopen()?,
            rollback_counter + 1,
        )
        .is_err();
        let other_secret_refused = ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED ^ 1,
            reopen()?,
            rollback_counter,
        )
        .is_err();

        let storage = reopen()?;
        let files_hold_the_last_commit =
            storage.with(|adapter| adapter.sealed_records_sha256()) == sealed_records;
        let mut restarted = ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage.clone(),
            rollback_counter,
        )?;
        restarted.keep_decoded_position_map_witness()?;
        let public_state_restored = restarted.public_state_digest()? == public_state;
        let mut getters_answer_as_before = workload.getters.len() == expected.len();
        for (call, (value, receipt)) in workload.getters.iter().zip(expected.iter()) {
            let result = restarted.call(call.entrypoint, call.args.clone())?;
            getters_answer_as_before &=
                &result.return_value == value && &result.trace.receipt == receipt;
        }
        // Every seal count the store holds now is one it held before the
        // restart, or is at or above the count it had reserved then, which
        // is above every count it held.
        let after = nonce_state(&storage, artifact);
        let mut no_nonce_repeats = true;
        let mut records_sealed_after_restart = 0usize;
        for (object, (counts, _)) in &after {
            let (held, reserved) = before
                .get(object)
                .ok_or_else(|| anyhow!("no nonce state for {object} before the restart"))?;
            no_nonce_repeats &= held.iter().all(|count| count < reserved);
            for count in counts {
                if held.binary_search(count).is_err() {
                    records_sealed_after_restart += 1;
                    no_nonce_repeats &= count >= reserved;
                }
            }
        }
        let holds = stale_counter_refused
            && other_secret_refused
            && files_hold_the_last_commit
            && public_state_restored
            && getters_answer_as_before
            && no_nonce_repeats;
        Ok((
            json!({
                "benchmark": workload.label,
                "backend": backend,
                "deployment_bytes": deployed_bytes,
                "journal_bytes_by_call": journal_bytes,
                "records_sealed_after_restart": records_sealed_after_restart,
                "stale_attested_counter_refused": stale_counter_refused,
                "other_deployment_secret_refused": other_secret_refused,
                "files_hold_the_last_commit": files_hold_the_last_commit,
                "public_state_restored": public_state_restored,
                "reads_answer_as_before_the_restart": getters_answer_as_before,
                "no_nonce_repeats_after_restart": no_nonce_repeats,
            }),
            holds,
        ))
    })();
    let _ = std::fs::remove_dir_all(&directory);
    outcome
}

/// A call that fails after it handed records to the store: the store must
/// hold what it held, and take the next call.
fn dropped_call(
    artifact: &CompiledArtifact,
    call: &CallSpec,
    read: &CallSpec,
) -> Result<JsonValue> {
    let _audit_off = WitnessAuditOff::new();
    let mut failing = artifact.clone();
    failing
        .contract
        .manifest
        .entrypoints
        .get_mut(call.entrypoint)
        .ok_or_else(|| anyhow!("manifest entry missing for {}", call.entrypoint))?
        .max_commit_ops = 0;
    let storage = SharedStorage::memory();
    let mut instance = ContractInstance::deploy_with_seed_and_storage(
        failing,
        PROBE_DEPLOY_SEED,
        storage.clone(),
    )?;
    instance.keep_decoded_position_map_witness()?;
    let held = |storage: &SharedStorage| {
        storage.with(|adapter| (adapter.sealed_records_sha256(), adapter.meta().to_vec()))
    };
    let before = held(&storage);
    let writes_before = instance.storage_stats().writes;
    let failed = instance.call(call.entrypoint, call.args.clone()).is_err();
    let records_handed_over = instance.storage_stats().writes - writes_before;
    let store_unchanged = held(&storage) == before;
    let commits = instance.storage_stats().commits;
    let next_call_commits = instance.call(read.entrypoint, read.args.clone()).is_ok()
        && instance.storage_stats().commits == commits + 1;
    Ok(json!({
        "entrypoint": call.entrypoint,
        "call_failed": failed,
        "records_handed_to_the_store": records_handed_over,
        "store_holds_what_it_held": store_unchanged,
        "store_commits_the_next_call": next_call_commits,
        "holds": failed && records_handed_over > 0 && store_unchanged && next_call_commits,
    }))
}

/// A store takes a sealed record only when the record's nonce is below the
/// count it has reserved for the record's object. The record is one a
/// deployment sealed.
fn nonce_reservation(artifact: &CompiledArtifact) -> Result<JsonValue> {
    let storage = SharedStorage::memory();
    let instance = ContractInstance::deploy_with_seed_and_storage(
        artifact.clone(),
        PROBE_DEPLOY_SEED,
        storage.clone(),
    )?;
    let object = sealed_objects(artifact)
        .into_iter()
        .next()
        .ok_or_else(|| anyhow!("the artifact has no sealed object"))?;
    // A full-scan map's first slot, or a cell.
    let (location, record) = [format!("{object}#0"), object.clone()]
        .into_iter()
        .find_map(|location| {
            storage
                .with(|adapter| adapter.record(&location).map(<[u8]>::to_vec))
                .map(|record| (location, record))
        })
        .ok_or_else(|| anyhow!("no record of {object} to try"))?;
    let seal_count = storage
        .with(|adapter| adapter.seal_counts(&object))
        .into_iter()
        .max()
        .ok_or_else(|| anyhow!("{object} has no sealed record"))?;
    drop(instance);

    let mut fresh = MemoryStorage::new();
    let refused_unreserved = fresh.create(&object, &location, &record).is_err();
    let own_count = uo_evm_seal_count(&record)?;
    fresh.reserve_seals(&object, own_count)?;
    let refused_at_the_reservation = fresh.create(&object, &location, &record).is_err();
    fresh.reserve_seals(&object, own_count + 1)?;
    let taken_once_reserved = fresh.create(&object, &location, &record).is_ok();
    let deployment_reserved_first =
        storage.with(|adapter| adapter.reserved_seals(&object)) > seal_count;
    Ok(json!({
        "object": object,
        "location": location,
        "record_refused_with_nothing_reserved": refused_unreserved,
        "record_refused_at_the_reserved_count": refused_at_the_reservation,
        "record_taken_once_its_count_is_reserved": taken_once_reserved,
        "a_deployment_reserves_before_it_hands_over_a_record": deployment_reserved_first,
        "holds": refused_unreserved
            && refused_at_the_reservation
            && taken_once_reserved
            && deployment_reserved_first,
    }))
}

/// The seal count a record carries, read as the store reads it: the marker,
/// four zero bytes, then the count's eight bytes.
fn uo_evm_seal_count(record: &[u8]) -> Result<u64> {
    let count = record
        .get(5..13)
        .ok_or_else(|| anyhow!("a sealed record is at least one unit"))?;
    let mut bytes = [0u8; 8];
    bytes.copy_from_slice(count);
    Ok(u64::from_be_bytes(bytes))
}

pub(crate) fn run_storage_boundary(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let mut benchmarks = Vec::new();
    let mut restarts = Vec::new();
    let mut every_log_agrees = true;
    let mut every_restart_holds = true;
    let mut totals = BoundaryTotals::default();
    let mut toolchain = None;
    for workload in benchmark_workloads() {
        let artifacts = suite
            .get(workload.suite)
            .ok_or_else(|| anyhow!("no benchmark {} in the suite", workload.suite))?;
        for (backend, artifact) in sealed_variants(artifacts) {
            toolchain = toolchain.or_else(|| {
                artifact
                    .admitted_package
                    .as_ref()
                    .map(|package| package.toolchain_manifest_sha256.clone())
            });
            let run = run_boundary(&workload, &backend, artifact)
                .with_context(|| format!("storage boundary of {}/{backend}", workload.label))?;
            every_log_agrees &= run.agrees;
            totals.calls += run.totals.calls;
            totals.store_reads += run.totals.store_reads;
            totals.store_writes += run.totals.store_writes;
            totals.traced_reads += run.totals.traced_reads;
            totals.traced_writes += run.totals.traced_writes;
            benchmarks.push(run.row);
            let (restart, holds) = run_restart(&workload, &backend, artifact, &run.getters)
                .with_context(|| format!("restart of {}/{backend}", workload.label))?;
            every_restart_holds &= holds;
            restarts.push(restart);
        }
    }
    if benchmarks.is_empty() {
        bail!("the storage-boundary report ran no benchmark");
    }

    let erc20 = suite
        .get("ERC20Lite")
        .ok_or_else(|| anyhow!("no ERC20Lite in the suite"))?;
    let mint = CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![Value::Address([0x11; 20]), Value::uint(10)],
    };
    let balance = CallSpec {
        entrypoint: "balanceOf(address)",
        args: vec![Value::Address([0x11; 20])],
    };
    let mut dropped_calls = Vec::new();
    let mut every_dropped_call_holds = true;
    for (backend, artifact) in sealed_variants(erc20) {
        let mut row = dropped_call(artifact, &mint, &balance)
            .with_context(|| format!("dropped call on ERC20Lite/{backend}"))?;
        every_dropped_call_holds &= row["holds"] == json!(true);
        row["backend"] = json!(backend);
        dropped_calls.push(row);
    }
    let nonce_reservation = nonce_reservation(&erc20.uo).context("nonce reservation")?;
    let nonce_reservation_holds = nonce_reservation["holds"] == json!(true);

    let checks = json!({
        "store_log_agrees_with_trace_in_every_call": every_log_agrees,
        "store_reads_are_the_traced_reads": totals.store_reads == totals.traced_reads,
        "store_writes_are_the_traced_writes": totals.store_writes == totals.traced_writes,
        "every_restart_continues_its_deployment": every_restart_holds,
        "a_dropped_call_leaves_the_store_as_it_was": every_dropped_call_holds,
        "a_record_reaches_the_store_only_under_a_reserved_nonce": nonce_reservation_holds,
    });
    let accepted = checks
        .as_object()
        .is_some_and(|checks| checks.values().all(|check| check == &json!(true)));
    Ok(json!({
        "schema": STORAGE_BOUNDARY_SCHEMA,
        "what_is_compared": "the log a storage adapter keeps of the sealed records the runtime opens and seals, against the physical reads and writes of sealed objects in the call's trace",
        "oram_reads": "a call reads the counter and the metadata pages of an ORAM map once, where it loads the map, and holds them through the call; each access reads its buckets; the trace names each of those reads where the call makes it",
        "coverage": {
            "benchmark_backend_pairs": benchmarks.len(),
            "calls": totals.calls,
        },
        "totals": {
            "store_reads": totals.store_reads,
            "store_writes": totals.store_writes,
            "traced_sealed_reads": totals.traced_reads,
            "traced_sealed_writes": totals.traced_writes,
        },
        "benchmarks": benchmarks,
        "restarts": restarts,
        "dropped_calls": dropped_calls,
        "nonce_reservation": nonce_reservation,
        "checks": checks,
        "provenance": {
            "toolchain_manifest_sha256": toolchain,
            "restart": "a seeded deployment restarts from a store in files; the sync policy is off, so the report times no device",
        },
        "accepted": accepted,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use uo_core::{PhysicalReadEvent, PhysicalWriteEvent};

    fn artifact() -> CompiledArtifact {
        crate::erc20_private_posmap_artifact(256).unwrap()
    }

    fn receipt(reads: &[(&str, &str, usize)], writes: &[(&str, &str, usize)]) -> PublicReceipt {
        PublicReceipt {
            physical_reads: reads
                .iter()
                .map(|(object, location, len)| PhysicalReadEvent {
                    object: (*object).into(),
                    location: (*location).into(),
                    len: *len,
                })
                .collect::<Vec<_>>()
                .into(),
            physical_writes: writes
                .iter()
                .map(|(object, location, len)| {
                    PhysicalWriteEvent::from_shape(*object, *location, *len, WriteClass::Update)
                })
                .collect::<Vec<_>>()
                .into(),
            ..PublicReceipt::default()
        }
    }

    fn read(object: &str, location: &str, len: usize) -> StorageIo {
        StorageIo::Read {
            object: object.into(),
            location: location.into(),
            len,
        }
    }

    fn write(object: &str, location: &str, len: usize, class: WriteClass) -> StorageIo {
        StorageIo::Write {
            object: object.into(),
            location: location.into(),
            len,
            class,
        }
    }

    #[test]
    fn the_comparison_rejects_the_differences_it_guards_against() {
        let artifact = artifact();
        // A call that loads the tree and makes two accesses: the counter and
        // the metadata page where it loads the map, then a bucket at each
        // access.
        let traced = receipt(
            &[
                ("balances", "balances@counter", 64),
                ("balances", "balances@meta0", 960),
                ("balances", "balances@bucket0", 800),
                ("balances", "balances@bucket0", 800),
            ],
            &[
                ("balances", "balances@bucket0", 800),
                ("balances", "balances@counter", 64),
            ],
        );
        let log = vec![
            read("balances", "balances@counter", 64),
            read("balances", "balances@meta0", 960),
            read("balances", "balances@bucket0", 800),
            write("balances", "balances@bucket0", 800, WriteClass::Update),
            read("balances", "balances@bucket0", 800),
            write("balances", "balances@counter", 64, WriteClass::Update),
        ];
        let agreed = compare_call(&artifact, &log, &traced);
        assert!(agreed.agrees(), "{:?}", agreed.difference);
        assert_eq!(agreed.store_reads, agreed.traced_reads);

        // A trace that names the counter again at the second access, as
        // traces did before Issue 57, names a read the store did not see.
        let named_again = receipt(
            &[
                ("balances", "balances@counter", 64),
                ("balances", "balances@meta0", 960),
                ("balances", "balances@bucket0", 800),
                ("balances", "balances@counter", 64),
                ("balances", "balances@bucket0", 800),
            ],
            &[
                ("balances", "balances@bucket0", 800),
                ("balances", "balances@counter", 64),
            ],
        );
        assert!(!compare_call(&artifact, &log, &named_again).agrees());

        // A bucket read the trace names and the store did not see.
        let mut missing = log.clone();
        missing.remove(4);
        assert!(!compare_call(&artifact, &missing, &traced).agrees());
        // A read the store saw and the trace does not name.
        let mut extra = log.clone();
        extra.push(read("balances", "balances@bucket7", 800));
        assert!(!compare_call(&artifact, &extra, &traced).agrees());
        // A bucket read twice is seen twice.
        let mut once = log.clone();
        once.remove(2);
        assert!(!compare_call(&artifact, &once, &traced).agrees());
        // A write the store classified as something else.
        let mut same = log.clone();
        same[3] = write("balances", "balances@bucket0", 800, WriteClass::Same);
        let rejected = compare_call(&artifact, &same, &traced);
        assert!(!rejected.store_classifies_every_write_as_update);
        assert!(!rejected.agrees());
        // Writes out of the trace's order.
        let mut swapped = log.clone();
        swapped.swap(3, 5);
        assert!(!compare_call(&artifact, &swapped, &traced).store_writes_equal_traced_writes);
        // Another length.
        let mut shorter = log;
        shorter[0] = read("balances", "balances@counter", 32);
        let rejected = compare_call(&artifact, &shorter, &traced);
        assert!(!rejected.agrees());
        assert!(rejected.difference.unwrap().contains("balances"));
    }
}
