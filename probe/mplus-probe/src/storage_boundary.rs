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
//! already hold. The restart takes the files only with an attested
//! generation that is theirs or one below it, and says which; the files
//! from before the last call are refused with the generation after it. The
//! restarted runtime resumes each key at the reservation the files' last
//! commit names, and resumes before its first call, which commits the
//! reservations that call needs. On ERC20Lite a committed abort, which
//! leaves the rollback counter where it was, moves the generation too
//! (`committed_aborts`).
//!
//! Last, it makes the store fail (`fault_matrix`): every failure a file
//! store can be made to meet (`StorageFault::ALL`), on each sealed backend
//! of ERC20Lite, at each of the two commits a call makes: its own, and the
//! commit of no record that a call dropped after it ran makes before its
//! error returns, which reserves what the next call can seal. The store must
//! refuse every operation after the failure, so that the runtime refuses the
//! next call. A call whose commit's append failed, or whose reservation's
//! did, must not return, and its error must say that its outcome is unknown.
//! The files must hold every commit that returned, and the failed one whole
//! or not at all: whole when its sync failed after a whole write or a
//! checkpoint failed after it, not at all when its write stopped part way.
//! A restart from the files, with the generation of the last commit that
//! returned attested, takes them, and says that they are one past it when
//! they hold the failed append's commit; of the attested generations around
//! it, it accepts the files' own and the one below. Once resumed, it answers
//! reads as the state the files hold says. The production build runs the
//! same failures through the production
//! runtime, whose receipts say which state the files hold
//! (`every_storage_failure_fails_closed_and_a_restart_resolves_the_call` in
//! `runtime/uo-evm/tests/production_boundary.rs`).
//!
//! Those are the failures the store's fault hook injects. What a crash
//! keeps is less than what a process reads back: a file's bytes are on the
//! device once it is synced, a name once its directory is, and the bytes a
//! failed sync left off the device no later sync of that file puts there.
//! So the report also runs ERC20Lite on each sealed backend with every
//! commit synced, under a model of what a crash would leave of the files
//! (`crash_recovery`, `uo_store::crash_model`). A crash after the first
//! call must leave a store that a restart takes with it: creating the store
//! put its files and their names on the device. A call whose sync then fails
//! is lost by a crash before the files are opened again. Opened again with
//! no crash, the store publishes what it read before it serves it, so the
//! restart finds the files one past the counter, and a crash after it keeps
//! the call. When that publication fails, the open fails, nothing is
//! resolved, and a crash leaves the store without the call.

use crate::capacity_sweep::WitnessAuditOff;
use crate::{
    artifact_backend_label, benchmark_workloads, BenchArtifacts, BenchmarkWorkload, CallSpec,
    PROBE_DEPLOY_SEED,
};
use anyhow::{anyhow, bail, Context, Result};
use serde_json::{json, Value as JsonValue};
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use uo_core::ir::BackendKind;
use uo_core::{CompiledArtifact, PublicReceipt, Value, WriteClass};
use uo_evm::crash_model::{CrashModel, FileOperation};
use uo_evm::{
    storage_failure, AppendFailure, ContractInstance, FileStorage, MemoryStorage, SharedStorage,
    StorageAdapter, StorageFailure, StorageFault, StorageIo, StoreGeneration, SyncPolicy,
};

pub(crate) const STORAGE_BOUNDARY_SCHEMA: &str = "uo-storage-boundary-v6";

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

/// Every file of `from`, copied into a new directory `to`: the files a host
/// that keeps an older store holds.
fn copy_directory(from: &Path, to: &Path) -> Result<()> {
    std::fs::create_dir_all(to)?;
    for entry in std::fs::read_dir(from)? {
        let entry = entry?;
        let target = to.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_directory(&entry.path(), &target)?;
        } else {
            std::fs::copy(entry.path(), target)?;
        }
    }
    Ok(())
}

/// How a restart from the files in `directory` with `attested_generation`
/// ends, as a name: `attested`, `one_past` or `refused`.
fn restart_outcome(
    artifact: &CompiledArtifact,
    directory: &Path,
    attested_generation: u64,
) -> Result<&'static str> {
    let storage = SharedStorage::new(FileStorage::open(directory, SyncPolicy::Never)?);
    Ok(
        match ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage,
            attested_generation,
        ) {
            Ok((_, StoreGeneration::Attested)) => "attested",
            Ok((_, StoreGeneration::OnePast)) => "one_past",
            Err(_) => "refused",
        },
    )
}

/// The outcome of a restart from `directory` with each attested generation
/// from two below the files' `generation` to one above it. The files are
/// taken at their own generation, and as one past the generation below it;
/// they are refused as more than one past the generation two below it, and
/// as behind the generation above it.
fn generation_window(
    artifact: &CompiledArtifact,
    directory: &Path,
    generation: u64,
) -> Result<(JsonValue, bool)> {
    let expected = [
        (generation - 2, "refused"),
        (generation - 1, "one_past"),
        (generation, "attested"),
        (generation + 1, "refused"),
    ];
    let mut rows = Vec::new();
    let mut holds = true;
    for (attested, outcome) in expected {
        let restart = restart_outcome(artifact, directory, attested)?;
        holds &= restart == outcome;
        rows.push(json!({
            "attested_generation": attested,
            "restart": restart,
        }));
    }
    Ok((JsonValue::Array(rows), holds))
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
    let before_last_call = scratch_directory(&format!("{}-{backend}-before", workload.label));
    let _ = std::fs::remove_dir_all(&directory);
    let _ = std::fs::remove_dir_all(&before_last_call);
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
        let calls: Vec<&CallSpec> = workload
            .setup
            .iter()
            .chain(std::iter::once(&workload.target))
            .collect();
        for (index, call) in calls.iter().enumerate() {
            if index + 1 == calls.len() {
                // The files a host keeps from before the last call.
                copy_directory(&directory, &before_last_call)?;
            }
            let before = instance.storage_stats().persisted_bytes;
            instance.call(call.entrypoint, call.args.clone())?;
            journal_bytes.push(json!({
                "entrypoint": call.entrypoint,
                "bytes": instance.storage_stats().persisted_bytes - before,
            }));
        }
        // The deployment's commit and one for each call.
        let generation = instance.generation();
        let generation_counts_the_commits = generation == 1 + calls.len() as u64;
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
        // An attested generation the files are not at or one past, the
        // files from before the last call with the generation after it, and
        // another deployment's secret are refused before anything is
        // restored.
        let (generation_window, generation_window_holds) =
            generation_window(artifact, &directory, generation)?;
        let files_before_the_last_call = restart_outcome(artifact, &before_last_call, generation)?;
        let other_secret_refused = ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED ^ 1,
            reopen()?,
            generation,
        )
        .is_err();

        let storage = reopen()?;
        let files_hold_the_last_commit =
            storage.with(|adapter| adapter.sealed_records_sha256()) == sealed_records;
        let (mut restarted, _) = ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage.clone(),
            generation,
        )?;
        // Every key resumed at the reservation of the last commit; resuming
        // commits what the first call can seal.
        let keys_resume_at_their_reservations =
            nonce_state(&storage, artifact)
                .iter()
                .all(|(object, (_, reserved))| {
                    before.get(object).is_some_and(|(_, held)| held == reserved)
                });
        restarted.resume(generation)?;
        let resumed_with_one_commit = restarted.generation() == generation + 1;
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
        let holds = generation_counts_the_commits
            && generation_window_holds
            && files_before_the_last_call == "refused"
            && other_secret_refused
            && keys_resume_at_their_reservations
            && resumed_with_one_commit
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
                "generation": generation,
                "generation_counts_the_commits": generation_counts_the_commits,
                "restart_by_attested_generation": generation_window,
                "files_before_the_last_call_at_its_generation": files_before_the_last_call,
                "other_deployment_secret_refused": other_secret_refused,
                "keys_resume_at_the_reservations_of_the_last_commit": keys_resume_at_their_reservations,
                "resume_commits_the_first_calls_reservations": resumed_with_one_commit,
                "files_hold_the_last_commit": files_hold_the_last_commit,
                "public_state_restored": public_state_restored,
                "reads_answer_as_before_the_restart": getters_answer_as_before,
                "no_nonce_repeats_after_restart": no_nonce_repeats,
            }),
            holds,
        ))
    })();
    let _ = std::fs::remove_dir_all(&directory);
    let _ = std::fs::remove_dir_all(&before_last_call);
    outcome
}

/// A committed call that aborts, which leaves the rollback counter where it
/// was, still moves the generation a restart checks. After `setup`, the
/// files are kept; `aborting` commits an abort. The kept files are refused
/// with the generation after the abort, the files after it are taken with
/// their own and as one past the one before it.
fn committed_abort(
    artifact: &CompiledArtifact,
    backend: &str,
    setup: &CallSpec,
    aborting: &CallSpec,
) -> Result<JsonValue> {
    let directory = scratch_directory(&format!("abort-{backend}"));
    let before_abort = scratch_directory(&format!("abort-{backend}-before"));
    let _ = std::fs::remove_dir_all(&directory);
    let _ = std::fs::remove_dir_all(&before_abort);
    let outcome = (|| -> Result<JsonValue> {
        let storage = SharedStorage::new(FileStorage::create(&directory, SyncPolicy::Never)?);
        let mut instance = ContractInstance::deploy_with_seed_and_storage(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage,
        )?;
        instance.keep_decoded_position_map_witness()?;
        let set_up = instance.call(setup.entrypoint, setup.args.clone())?;
        let generation_before = instance.generation();
        copy_directory(&directory, &before_abort)?;
        let result = instance.call(aborting.entrypoint, aborting.args.clone())?;
        let generation_after = instance.generation();
        drop(instance);
        let before_at_the_generation_after =
            restart_outcome(artifact, &before_abort, generation_after)?;
        let before_at_its_generation = restart_outcome(artifact, &before_abort, generation_before)?;
        let after_at_its_generation = restart_outcome(artifact, &directory, generation_after)?;
        let after_at_the_generation_before =
            restart_outcome(artifact, &directory, generation_before)?;
        let holds = !set_up.aborted
            && result.aborted
            && generation_after == generation_before + 1
            && before_at_the_generation_after == "refused"
            && before_at_its_generation == "attested"
            && after_at_its_generation == "attested"
            && after_at_the_generation_before == "one_past";
        Ok(json!({
            "backend": backend,
            "setup": setup.entrypoint,
            "aborting_call": aborting.entrypoint,
            "call_aborted": result.aborted,
            "generation_before_the_abort": generation_before,
            "generation_after_the_abort": generation_after,
            "files_before_the_abort_at_the_generation_after_it": before_at_the_generation_after,
            "files_before_the_abort_at_their_generation": before_at_its_generation,
            "files_after_the_abort_at_their_generation": after_at_its_generation,
            "files_after_the_abort_at_the_generation_before_it": after_at_the_generation_before,
            "holds": holds,
        }))
    })();
    let _ = std::fs::remove_dir_all(&directory);
    let _ = std::fs::remove_dir_all(&before_abort);
    outcome
}

/// A call that fails after it handed records to the store: the store must
/// hold the records it held, its metadata must be a commit of no record that
/// reserves what the next call can seal, and it must take the next call.
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
    let records = |storage: &SharedStorage| storage.with(|adapter| adapter.sealed_records_sha256());
    let before = records(&storage);
    let generation = instance.generation();
    let commits_before = instance.storage_stats().commits;
    let writes_before = instance.storage_stats().writes;
    let failed = instance.call(call.entrypoint, call.args.clone()).is_err();
    let records_handed_over = instance.storage_stats().writes - writes_before;
    let records_unchanged = records(&storage) == before;
    // One commit, of no record: the reservations the next call needs.
    let reservation_committed = instance.generation() == generation + 1
        && instance.storage_stats().commits == commits_before + 1;
    let commits = instance.storage_stats().commits;
    let next_call_commits = instance.call(read.entrypoint, read.args.clone()).is_ok()
        && instance.storage_stats().commits == commits + 1;
    Ok(json!({
        "entrypoint": call.entrypoint,
        "call_failed": failed,
        "records_handed_to_the_store": records_handed_over,
        "store_holds_the_records_it_held": records_unchanged,
        "a_commit_of_no_record_reserves_for_the_next_call": reservation_committed,
        "store_commits_the_next_call": next_call_commits,
        "holds": failed
            && records_handed_over > 0
            && records_unchanged
            && reservation_committed
            && next_call_commits,
    }))
}

/// A deployment of `artifact` on a store in files meets `fault` at a commit
/// after one call that returned (`fault_matrix` in the module's comment).
/// `setup` returns. If `reservation`, the commit that meets the fault is the
/// one of no record that `dropped`, an entrypoint whose commit budget is
/// zero, makes after it ran and before its error returns, which reserves
/// what the next call can seal; otherwise it is `target`'s. `read` is a read
/// of what `setup` and `target` wrote.
fn storage_fault(
    artifact: &CompiledArtifact,
    backend: &str,
    fault: StorageFault,
    reservation: bool,
    calls: [&CallSpec; 4],
) -> Result<JsonValue> {
    let [setup, target, dropped, read] = calls;
    let mut artifact = artifact.clone();
    if reservation {
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(dropped.entrypoint)
            .ok_or_else(|| anyhow!("manifest entry missing for {}", dropped.entrypoint))?
            .max_commit_ops = 0;
    }
    let call = if reservation { dropped } else { target };
    // The state the files may hold after the call: the one before it, and
    // the one a twin that meets no fault reaches with it.
    let mut twin = ContractInstance::deploy_with_seed(artifact.clone(), PROBE_DEPLOY_SEED)?;
    twin.keep_decoded_position_map_witness()?;
    twin.call(setup.entrypoint, setup.args.clone())?;
    let state = |instance: &ContractInstance| -> Result<(String, String)> {
        Ok((
            instance.public_state_digest()?,
            instance.ciphertext_store_digest()?,
        ))
    };
    let before = state(&twin)?;
    let after = match twin.call(call.entrypoint, call.args.clone()) {
        Ok(_) => Some(state(&twin)?),
        Err(_) => None,
    };

    let commit = if reservation {
        "the_reservation_after_a_dropped_call"
    } else {
        "the_calls"
    };
    let label = format!("{backend}-{commit}-{}", serde_json::to_string(&fault)?);
    let directory = scratch_directory(&format!("fault-{label}"));
    let _ = std::fs::remove_dir_all(&directory);
    let outcome = (|| -> Result<JsonValue> {
        let mut store = FileStorage::create(&directory, SyncPolicy::Never)?;
        if let StorageFault::Checkpoint { .. } = fault {
            store = store.with_checkpoint_bytes(0);
        }
        let storage = SharedStorage::new(store);
        let mut instance = ContractInstance::deploy_with_seed_and_storage(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage.clone(),
        )?;
        instance.keep_decoded_position_map_witness()?;
        instance.call(setup.entrypoint, setup.args.clone())?;
        let generation_before = instance.generation();

        storage.inject_fault(fault)?;
        let result = instance.call(call.entrypoint, call.args.clone());
        // The platform's counter holds the generation of the instance's last
        // commit that returned: the one before the fault, or, when a
        // checkpoint failed, the commit that ran it.
        let counter = instance.generation();
        let checkpoint = matches!(fault, StorageFault::Checkpoint { .. });
        let counter_as_expected = counter == generation_before + u64::from(checkpoint);
        let (call_result, failure) = match &result {
            Ok(_) => ("returned", None),
            Err(error) => match storage_failure(error) {
                Some(StorageFailure::OutcomeUnknown) => {
                    ("outcome_unknown", Some(StorageFailure::OutcomeUnknown))
                }
                other => ("failed", other),
            },
        };
        let call_as_expected = match (checkpoint, reservation) {
            (false, _) => call_result == "outcome_unknown",
            (true, false) => call_result == "returned",
            (true, true) => call_result == "failed",
        };
        let store_refuses_operations = storage.poisoned().is_some();
        let next_call_refused = instance
            .call(read.entrypoint, read.args.clone())
            .err()
            .is_some_and(|error| error.to_string().contains("refuses every operation"));
        drop(instance);
        drop(storage);

        let opened = FileStorage::open(&directory, SyncPolicy::Never)?;
        let bytes_cut_on_open = opened.bytes_cut_on_open();
        drop(opened);
        let reopen = || -> Result<SharedStorage> {
            Ok(SharedStorage::new(FileStorage::open(
                &directory,
                SyncPolicy::Never,
            )?))
        };
        let mut accepted = Vec::new();
        for attested in [counter - 1, counter, counter + 1] {
            if restart_outcome(&artifact, &directory, attested)? != "refused" {
                accepted.push(attested);
            }
        }
        let (mut restarted, found) = ContractInstance::restart_with_seed(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            reopen()?,
            counter,
        )
        .with_context(|| format!("no restart at the counter {label}"))?;
        let restart_at_the_counter = match found {
            StoreGeneration::Attested => "attested",
            StoreGeneration::OnePast => "one_past",
        };
        // The files are one past the counter when they hold the commit of a
        // failed append: its sync failed after a whole write.
        let expected_restart = if !checkpoint && fault.leaves_the_entry_whole() {
            "one_past"
        } else {
            "attested"
        };
        let files_generation = restarted.generation();
        let files_hold_the_commit = files_generation == generation_before + 1;
        restarted.keep_decoded_position_map_witness()?;
        let files = state(&restarted)?;
        let files_hold_the_call = Some(&files) == after.as_ref();
        let files_hold_a_state_of_the_call = files == before || files_hold_the_call;
        // The counter catches up with the files, and the instance resumes.
        restarted.resume(files_generation)?;
        // Reads answer as the state the files hold says: as the twin, if
        // they hold the call, and as before it otherwise.
        let expected_read = if files_hold_the_call {
            twin.call(read.entrypoint, read.args.clone())?.return_value
        } else {
            let mut before_twin =
                ContractInstance::deploy_with_seed(artifact.clone(), PROBE_DEPLOY_SEED)?;
            before_twin.keep_decoded_position_map_witness()?;
            before_twin.call(setup.entrypoint, setup.args.clone())?;
            before_twin
                .call(read.entrypoint, read.args.clone())?
                .return_value
        };
        let reads_answer_as_the_files_say = restarted
            .call(read.entrypoint, read.args.clone())?
            .return_value
            == expected_read;
        let takes_calls_after_restart =
            restarted.call(setup.entrypoint, setup.args.clone()).is_ok();
        let holds = call_as_expected
            && counter_as_expected
            && store_refuses_operations
            && next_call_refused
            && restart_at_the_counter == expected_restart
            && accepted == [files_generation - 1, files_generation]
            && files_hold_the_commit == fault.leaves_the_entry_whole()
            && files_hold_a_state_of_the_call
            && files_hold_the_call == (files_hold_the_commit && !reservation)
            && (bytes_cut_on_open > 0) != fault.leaves_the_entry_whole()
            && reads_answer_as_the_files_say
            && takes_calls_after_restart;
        Ok(json!({
            "backend": backend,
            "commit": commit,
            "fault": fault,
            "entrypoint": call.entrypoint,
            "call": call_result,
            "storage_failure": failure,
            "store_refuses_operations": store_refuses_operations,
            "next_call_refused": next_call_refused,
            "bytes_cut_on_open": bytes_cut_on_open,
            "generation_of_the_last_commit_that_returned": counter,
            "restart_at_that_generation": restart_at_the_counter,
            "attested_generations_a_restart_accepts": accepted,
            // Which commit, as a name and not a flag: a false flag would be
            // a false leaf that the acceptance gate does not classify.
            "files_hold": if files_hold_the_commit {
                "the_commit_that_met_the_fault"
            } else {
                "the_commit_before_it"
            },
            "files_hold_the_state_before_or_after_the_call": files_hold_a_state_of_the_call,
            "reads_answer_as_the_files_say": reads_answer_as_the_files_say,
            "takes_calls_after_restart": takes_calls_after_restart,
            "holds": holds,
        }))
    })();
    let _ = std::fs::remove_dir_all(&directory);
    outcome
}

/// The name of where a restart found a store's generation.
fn found_name(found: StoreGeneration) -> &'static str {
    match found {
        StoreGeneration::Attested => "attested",
        StoreGeneration::OnePast => "one_past",
    }
}

/// A deployment of `artifact` on a store in files that syncs every commit,
/// under a crash model (`crash_recovery` in the module's comment): `setup`
/// returns, `target` meets a sync that fails after a whole write, and `read`
/// reads what `target` writes. If `publication_fails`, the open after it
/// fails to sync the journal it publishes.
fn crash_run(
    artifact: &CompiledArtifact,
    label: &str,
    calls: [&CallSpec; 3],
    publication_fails: bool,
) -> Result<JsonValue> {
    let [setup, target, read] = calls;
    let root = scratch_directory(label);
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root)?;
    let outcome = (|| -> Result<JsonValue> {
        let model = CrashModel::watch(&root)?;
        let directory = root.join("store");
        // What a restart at `attested` from what a crash now would leave
        // finds, and what `read` answers once it resumed.
        let after_a_crash = |attested: u64, name: &str| -> Result<(&'static str, JsonValue)> {
            let crashed = scratch_directory(&format!("{label}-{name}"));
            let _ = std::fs::remove_dir_all(&crashed);
            model.crash_into(&crashed)?;
            let found = (|| -> Result<(&'static str, JsonValue)> {
                let storage = SharedStorage::new(FileStorage::open(
                    crashed.join("store"),
                    SyncPolicy::Always,
                )?);
                let (mut restarted, found) = ContractInstance::restart_with_seed(
                    artifact.clone(),
                    PROBE_DEPLOY_SEED,
                    storage,
                    attested,
                )?;
                restarted.keep_decoded_position_map_witness()?;
                restarted.resume(restarted.generation())?;
                let value = restarted
                    .call(read.entrypoint, read.args.clone())?
                    .return_value;
                Ok((found_name(found), serde_json::to_value(value)?))
            })();
            let _ = std::fs::remove_dir_all(&crashed);
            found
        };
        let storage = SharedStorage::new(FileStorage::create(&directory, SyncPolicy::Always)?);
        let mut instance = ContractInstance::deploy_with_seed_and_storage(
            artifact.clone(),
            PROBE_DEPLOY_SEED,
            storage.clone(),
        )?;
        instance.keep_decoded_position_map_witness()?;
        instance.call(setup.entrypoint, setup.args.clone())?;
        let counter = instance.generation();
        let after_the_first_call = after_a_crash(counter, "first")?;
        storage.inject_fault(StorageFault::Append {
            failure: AppendFailure::SyncFails,
        })?;
        let failed = instance
            .call(target.entrypoint, target.args.clone())
            .err()
            .and_then(|error| storage_failure(&error));
        drop(instance);
        drop(storage);
        let before_any_reopen = after_a_crash(counter, "before")?;
        let mut row = json!({
            "failed_call": if failed == Some(StorageFailure::OutcomeUnknown) {
                "outcome_unknown"
            } else {
                "other"
            },
            "after_a_crash_after_the_first_call": {
                "restart": after_the_first_call.0,
                "read": after_the_first_call.1,
            },
            "after_a_crash_before_any_reopen": {
                "restart": before_any_reopen.0,
                "read": before_any_reopen.1,
            },
        });
        if publication_fails {
            model.fail_next(FileOperation::SyncFile, directory.join("journal.tmp"));
            let reopen = match FileStorage::open(&directory, SyncPolicy::Always) {
                Ok(_) => "served",
                Err(_) => "refused",
            };
            let after = after_a_crash(counter, "after")?;
            row["reopen"] = json!(reopen);
            row["after_a_crash_after_the_reopen"] = json!({
                "restart": after.0,
                "read": after.1,
            });
        } else {
            // The process restarts with no crash.
            let storage = SharedStorage::new(FileStorage::open(&directory, SyncPolicy::Always)?);
            let (mut restarted, found) = ContractInstance::restart_with_seed(
                artifact.clone(),
                PROBE_DEPLOY_SEED,
                storage,
                counter,
            )?;
            restarted.keep_decoded_position_map_witness()?;
            restarted.resume(restarted.generation())?;
            let served = restarted
                .call(read.entrypoint, read.args.clone())?
                .return_value;
            let attested = restarted.generation();
            drop(restarted);
            let after = after_a_crash(attested, "after")?;
            row["reopen"] = json!(found_name(found));
            row["read_after_the_reopen"] = serde_json::to_value(served)?;
            row["after_a_crash_after_the_reopen"] = json!({
                "restart": after.0,
                "read": after.1,
            });
        }
        drop(model);
        Ok(row)
    })();
    let _ = std::fs::remove_dir_all(&root);
    outcome
}

/// A store in files, under a crash model, on one sealed backend of
/// `artifact` (`crash_recovery` in the module's comment): the run whose open
/// publishes, and the run whose publication fails.
fn crash_recovery(
    artifact: &CompiledArtifact,
    backend: &str,
    calls: [&CallSpec; 3],
) -> Result<JsonValue> {
    let [setup, target, read] = calls;
    // What `read` answers before `target` and after it, on a runtime that
    // meets no fault.
    let mut twin = ContractInstance::deploy_with_seed(artifact.clone(), PROBE_DEPLOY_SEED)?;
    twin.keep_decoded_position_map_witness()?;
    twin.call(setup.entrypoint, setup.args.clone())?;
    let before = serde_json::to_value(twin.call(read.entrypoint, read.args.clone())?.return_value)?;
    twin.call(target.entrypoint, target.args.clone())?;
    let after = serde_json::to_value(twin.call(read.entrypoint, read.args.clone())?.return_value)?;
    let published = crash_run(artifact, &format!("crash-{backend}"), calls, false)?;
    let unpublished = crash_run(
        artifact,
        &format!("crash-{backend}-unpublished"),
        calls,
        true,
    )?;
    let state = |restart: &str, read: &JsonValue| json!({ "restart": restart, "read": read });
    let holds = published["failed_call"] == json!("outcome_unknown")
        && published["after_a_crash_after_the_first_call"] == state("attested", &before)
        && published["after_a_crash_before_any_reopen"] == state("attested", &before)
        && published["reopen"] == json!("one_past")
        && published["read_after_the_reopen"] == after
        && published["after_a_crash_after_the_reopen"] == state("attested", &after)
        && unpublished["failed_call"] == json!("outcome_unknown")
        && unpublished["reopen"] == json!("refused")
        && unpublished["after_a_crash_after_the_reopen"] == state("attested", &before);
    Ok(json!({
        "backend": backend,
        "setup": setup.entrypoint,
        "call_whose_sync_fails": target.entrypoint,
        "read": read.entrypoint,
        "read_before_the_call": before,
        "read_after_the_call": after,
        "published": published,
        "publication_fails": unpublished,
        "holds": holds,
    }))
}

/// A store takes a sealed record only when the record's nonce is below the
/// count it has reserved for the record's object: in a call, the count the
/// last commit reserved, since a reservation takes effect with the commit
/// that makes it durable. The record is one a deployment sealed.
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
    // In a call, a reservation made in the call does not cover a record
    // until the commit that makes it durable.
    let mut in_call = MemoryStorage::new();
    in_call.begin()?;
    in_call.reserve_seals(&object, own_count + 1)?;
    let refused_before_its_commit = in_call.create(&object, &location, &record).is_err();
    in_call.commit(b"reserved")?;
    in_call.begin()?;
    let taken_after_its_commit = in_call.create(&object, &location, &record).is_ok();
    let deployment_reserved_first =
        storage.with(|adapter| adapter.reserved_seals(&object)) > seal_count;
    Ok(json!({
        "object": object,
        "location": location,
        "record_refused_with_nothing_reserved": refused_unreserved,
        "record_refused_at_the_reserved_count": refused_at_the_reservation,
        "record_taken_once_its_count_is_reserved": taken_once_reserved,
        "record_in_a_call_refused_until_its_reservation_is_committed": refused_before_its_commit,
        "record_in_a_call_taken_once_its_reservation_is_committed": taken_after_its_commit,
        "a_deployment_reserves_before_it_hands_over_a_record": deployment_reserved_first,
        "holds": refused_unreserved
            && refused_at_the_reservation
            && taken_once_reserved
            && refused_before_its_commit
            && taken_after_its_commit
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

    // A transfer of more than the owner holds aborts, and is committed.
    let too_much = CallSpec {
        entrypoint: "transfer(address,address,uint256)",
        args: vec![
            Value::Address([0x11; 20]),
            Value::Address([0x22; 20]),
            Value::uint(100),
        ],
    };
    let mut committed_aborts = Vec::new();
    let mut every_committed_abort_moves_the_generation = true;
    for (backend, artifact) in sealed_variants(erc20) {
        let row = committed_abort(artifact, &backend, &mint, &too_much)
            .with_context(|| format!("committed abort on ERC20Lite/{backend}"))?;
        every_committed_abort_moves_the_generation &= row["holds"] == json!(true);
        committed_aborts.push(row);
    }

    let second_mint = CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![Value::Address([0x22; 20]), Value::uint(20)],
    };
    let approve = CallSpec {
        entrypoint: "approve(address,address,uint256)",
        args: vec![
            Value::Address([0x11; 20]),
            Value::Address([0x22; 20]),
            Value::uint(5),
        ],
    };
    let second_balance = CallSpec {
        entrypoint: "balanceOf(address)",
        args: vec![Value::Address([0x22; 20])],
    };
    let mut fault_matrix = Vec::new();
    let mut every_storage_fault_fails_closed = true;
    for (backend, artifact) in sealed_variants(erc20) {
        for reservation in [false, true] {
            for fault in StorageFault::ALL {
                let row = storage_fault(
                    artifact,
                    &backend,
                    fault,
                    reservation,
                    [&mint, &second_mint, &approve, &second_balance],
                )
                .with_context(|| {
                    format!("storage fault {fault:?} ({reservation}) on ERC20Lite/{backend}")
                })?;
                every_storage_fault_fails_closed &= row["holds"] == json!(true);
                fault_matrix.push(row);
            }
        }
    }

    let mut crash_rows = Vec::new();
    let mut restarts_resolve_only_what_is_on_the_device = true;
    for (backend, artifact) in sealed_variants(erc20) {
        let row = crash_recovery(artifact, &backend, [&mint, &second_mint, &second_balance])
            .with_context(|| format!("crash recovery on ERC20Lite/{backend}"))?;
        restarts_resolve_only_what_is_on_the_device &= row["holds"] == json!(true);
        crash_rows.push(row);
    }

    let checks = json!({
        "store_log_agrees_with_trace_in_every_call": every_log_agrees,
        "store_reads_are_the_traced_reads": totals.store_reads == totals.traced_reads,
        "store_writes_are_the_traced_writes": totals.store_writes == totals.traced_writes,
        "every_restart_continues_its_deployment": every_restart_holds,
        "a_restart_refuses_the_files_from_before_a_committed_abort": every_committed_abort_moves_the_generation,
        "a_dropped_call_leaves_the_records_as_they_were": every_dropped_call_holds,
        "a_record_reaches_the_store_only_under_a_reserved_nonce": nonce_reservation_holds,
        "every_storage_fault_fails_closed": every_storage_fault_fails_closed,
        "restarts_resolve_only_what_is_on_the_device": restarts_resolve_only_what_is_on_the_device,
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
        "committed_aborts": committed_aborts,
        "dropped_calls": dropped_calls,
        "nonce_reservation": nonce_reservation,
        "fault_matrix": fault_matrix,
        "crash_recovery": crash_rows,
        "checks": checks,
        "provenance": {
            "toolchain_manifest_sha256": toolchain,
            "restart": "a seeded deployment restarts from a store in files, with an attested generation that stands for the platform's monotonic counter; the sync policy is off, so the report times no device, but in crash_recovery, which syncs every commit and asks a model of the device what a crash would leave",
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
