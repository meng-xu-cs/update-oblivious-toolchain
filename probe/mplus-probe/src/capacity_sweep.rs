//! The capacity sweep (`--only capacity-sweep` and `--only
//! capacity-sweep-full`): what one map operation costs on the full scan and on
//! both Path ORAM schemes, by capacity and by how full the map is.
//!
//! The contract is SweepMap: SingleAccessMap's `read` and `put`, a `clear`,
//! and `putBelow`, a write behind a `require` guard, which is how a call
//! aborts at any occupancy. For each backend and capacity one deployment is
//! filled, level by level, to 2 keys and to each configured share of the
//! capacity, with keys drawn from a fixed seed, through the runtime's
//! diagnostics-only bulk loader. At each level the sweep
//!
//! 1. measures seven kinds of call in rounds (a read of a stored key and of
//!    an absent one, an overwrite, a write of the value a key already has, a
//!    delete, an insert, and an aborting write), after unmeasured warmup
//!    rounds; and
//! 2. executes, for each read fraction, a seeded sequence of reads and of
//!    writes of every kind, and reports what it measured next to the mix
//!    computed from a read's and a write's counts.
//!
//! Everything that is a function of the seed (the traced counts, the untraced
//! reads at a call's start and in its witness snapshots, the sizes of the
//! JSON a call exports) is reported outside the `timing` objects, and
//! `counts_sha256` is the digest of the report without them: it repeats
//! between runs and machines. Wall-clock times, memory and the provenance of
//! the build are inside `timing` and `provenance`.
//!
//! Two profiles share the schema. The quick one, which the validation script
//! runs, takes few trials and fills only small maps. The full one takes the
//! trials a latency claim needs and fills every map; `scripts/` has a script
//! that runs it into a file of its own. `UO_SWEEP_*` overrides either.

use super::{
    call_start_decode, compile_artifact_from_metadata, display_report_path, env_f64_list,
    env_usize, env_usize_list, lean_proofgrade_witness_checker_path, load_metadata,
    percentile_sorted, read_max_rss_kb, write_temp_json, PROBE_DEPLOY_SEED,
};
use anyhow::{anyhow, bail, Context, Result};
use serde_json::{json, Value as JsonValue};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;
use uo_core::{CompiledArtifact, ExecutionTrace, ProgramMode, Value};
use uo_evm::{ContractInstance, InstrumentationTotals};

pub(crate) const CAPACITY_SWEEP_SCHEMA: &str = "uo-capacity-sweep-v4";

const SWEEP_SOURCE: &str = "benches/raw/SweepMap.sol";
const SWEEP_METADATA: &str = "benches/raw/SweepMap.pathoram.yaml";
const SWEEP_MAP: &str = "records";

/// The seed of the sweep's keys and of the order of its workloads.
const SWEEP_KEY_SEED: u64 = 0x5357_4545_505f_4b31;

/// Resamples behind each bootstrap interval.
const SWEEP_BOOTSTRAP_RESAMPLES: usize = 1000;

/// The capacity sweep's map backends, as (label, backend, ORAM scheme): the
/// full scan and both Path ORAM schemes.
const CAPACITY_SWEEP_BACKENDS: [(&str, &str, Option<&str>); 3] = [
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

/// The largest map the local scheme's flat position map admits; the sweep
/// keeps one capacity past it to record the rejection.
const CAPACITY_SWEEP_LOCAL_LIMIT: usize = 128;

const CAPACITY_SWEEP_METRICS: [&str; 3] = ["bytes_moved", "physical_operations", "gas"];

const CAPACITY_SWEEP_LATENCY_METRICS: [&str; 2] = ["call_latency_ns", "runtime_latency_ns"];

/// Which sweep to run.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum SweepProfile {
    /// Few trials, and occupancy levels on small maps only: the validation
    /// script's.
    Quick,
    /// The trials a latency claim needs, and every level on every map.
    Full,
}

/// How full the sweep makes a map.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum OccupancyLevel {
    /// Two keys, or one in a map of capacity 1: what the sweep stored
    /// before it measured occupancy.
    TwoKeys,
    /// This share of the capacity, rounded down, and at least one key.
    Percent(u64),
}

impl OccupancyLevel {
    fn label(self) -> String {
        match self {
            Self::TwoKeys => "2_keys".into(),
            Self::Percent(percent) => format!("{percent}_percent"),
        }
    }

    fn stored_keys(self, capacity: usize) -> usize {
        match self {
            Self::TwoKeys => capacity.clamp(1, 2),
            Self::Percent(percent) => {
                let share = (capacity as u128 * u128::from(percent.min(100))) / 100;
                usize::try_from(share)
                    .unwrap_or(capacity)
                    .clamp(1, capacity)
            }
        }
    }
}

struct SweepParameters {
    profile: SweepProfile,
    capacities: Vec<usize>,
    /// The shares of its capacity a map is filled to, after its two keys.
    occupancy_percents: Vec<u64>,
    /// The largest capacity that is filled to those shares.
    occupancy_capacity_limit: usize,
    read_percents: Vec<u64>,
    warmups: usize,
    trials: usize,
    /// The calls of each executed workload.
    workload_calls: usize,
    /// The capacities at which Lean checks one sampled call of each kind.
    lean_capacities: Vec<usize>,
}

impl SweepParameters {
    fn from_env(profile: SweepProfile) -> Self {
        let quick = profile == SweepProfile::Quick;
        let capacities = env_usize_list(
            "UO_SWEEP_CAPACITIES",
            &[
                1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384,
            ],
        );
        let largest = capacities.iter().copied().max().unwrap_or(0);
        Self {
            profile,
            occupancy_percents: env_usize_list("UO_SWEEP_OCCUPANCY_PERCENTS", &[25, 50, 90, 100])
                .into_iter()
                .filter(|percent| (1..=100).contains(percent))
                .map(|percent| percent as u64)
                .collect(),
            occupancy_capacity_limit: env_usize(
                "UO_SWEEP_OCCUPANCY_MAX_CAPACITY",
                if quick { 256 } else { largest },
            ),
            read_percents: env_f64_list(
                "UO_SWEEP_READ_FRACTIONS",
                &[0.0, 0.25, 0.5, 0.75, 0.9, 1.0],
            )
            .into_iter()
            .map(|fraction| (fraction.clamp(0.0, 1.0) * 100.0).round() as u64)
            .collect(),
            warmups: env_usize("UO_SWEEP_WARMUPS", if quick { 1 } else { 5 }),
            trials: env_usize("UO_SWEEP_TRIALS", if quick { 2 } else { 30 }).max(1),
            workload_calls: env_usize("UO_SWEEP_WORKLOAD_CALLS", if quick { 5 } else { 20 }),
            lean_capacities: env_usize_list(
                "UO_SWEEP_LEAN_CAPACITIES",
                if quick { &[16, 256] } else { &capacities },
            ),
            capacities,
        }
    }

    /// The levels a map of `capacity` is filled to, as the number of keys
    /// stored and the labels of the levels that store that many, in the order
    /// the sweep fills them.
    fn cells(&self, capacity: usize) -> Vec<(usize, Vec<String>)> {
        let mut cells: BTreeMap<usize, Vec<String>> = BTreeMap::new();
        let mut levels = vec![OccupancyLevel::TwoKeys];
        if capacity <= self.occupancy_capacity_limit {
            levels.extend(
                self.occupancy_percents
                    .iter()
                    .map(|percent| OccupancyLevel::Percent(*percent)),
            );
        }
        for level in levels {
            let labels = cells.entry(level.stored_keys(capacity)).or_default();
            if !labels.contains(&level.label()) {
                labels.push(level.label());
            }
        }
        cells.into_iter().collect()
    }

    fn occupancy_labels(&self) -> Vec<String> {
        let mut labels = vec![OccupancyLevel::TwoKeys.label()];
        for percent in &self.occupancy_percents {
            let label = OccupancyLevel::Percent(*percent).label();
            if !labels.contains(&label) {
                labels.push(label);
            }
        }
        labels
    }
}

/// The kinds of call the sweep measures.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum SweepOperation {
    ReadHit,
    ReadMiss,
    Insert,
    Overwrite,
    NoopWrite,
    Delete,
    Abort,
}

impl SweepOperation {
    /// One round of measurements: every kind once, the delete before the
    /// insert, so that a map never holds more keys than its level.
    const ROUND: [Self; 7] = [
        Self::ReadHit,
        Self::ReadMiss,
        Self::Overwrite,
        Self::NoopWrite,
        Self::Delete,
        Self::Insert,
        Self::Abort,
    ];

    /// The reads a workload alternates, and the writes it cycles through.
    const WORKLOAD_READS: [Self; 2] = [Self::ReadHit, Self::ReadMiss];
    const WORKLOAD_WRITES: [Self; 5] = [
        Self::Overwrite,
        Self::Delete,
        Self::Insert,
        Self::NoopWrite,
        Self::Abort,
    ];

    fn label(self) -> &'static str {
        match self {
            Self::ReadHit => "read_hit",
            Self::ReadMiss => "read_miss",
            Self::Insert => "insert",
            Self::Overwrite => "overwrite",
            Self::NoopWrite => "noop_write",
            Self::Delete => "delete",
            Self::Abort => "abort",
        }
    }

    fn entrypoint(self) -> &'static str {
        match self {
            Self::ReadHit | Self::ReadMiss => "read(bytes32)",
            Self::Insert | Self::Overwrite | Self::NoopWrite => "put(bytes32,uint256)",
            Self::Delete => "clear(bytes32)",
            Self::Abort => "putBelow(bytes32,uint256,uint256)",
        }
    }

    fn description(self) -> &'static str {
        match self {
            Self::ReadHit => "read(bytes32) of a stored key: one map get",
            Self::ReadMiss => "read(bytes32) of an absent key: one map get",
            Self::Insert => "put(bytes32,uint256) of an absent key: one map write",
            Self::Overwrite => {
                "put(bytes32,uint256) of a stored key with another value: one map write"
            }
            Self::NoopWrite => {
                "put(bytes32,uint256) of a stored key with the value it has: one map write"
            }
            Self::Delete => "clear(bytes32) of a stored key: one map write of zero",
            Self::Abort => {
                "putBelow(bytes32,uint256,uint256) of a stored key with a limit of zero: the guard fails and the call aborts"
            }
        }
    }

    fn is_read(self) -> bool {
        matches!(self, Self::ReadHit | Self::ReadMiss)
    }

    /// Whether the kind needs a key the map holds.
    fn needs_stored_key(self) -> bool {
        !matches!(self, Self::ReadMiss | Self::Insert)
    }
}

/// SplitMix64: the sweep's generator for picks, shuffles and resamples, so
/// that a run is a function of its seed.
struct SplitMix64(u64);

impl SplitMix64 {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        z ^ (z >> 31)
    }

    /// A value below `bound`, which is positive.
    fn below(&mut self, bound: usize) -> usize {
        ((u128::from(self.next()) * bound as u128) >> 64) as usize
    }
}

/// The keys a sweep map holds, with their values, and the source of the keys
/// and values it has not held.
struct SweepKeys {
    capacity: usize,
    next_key: u64,
    next_value: u64,
    picks: SplitMix64,
    stored: Vec<([u8; 32], u64)>,
}

impl SweepKeys {
    fn new(capacity: usize) -> Self {
        Self {
            capacity,
            next_key: 0,
            next_value: 0,
            picks: SplitMix64(SWEEP_KEY_SEED ^ (capacity as u64).wrapping_mul(0x1000_0000_01b3)),
            stored: Vec::new(),
        }
    }

    /// A key the map has never held: a hash of the seed, the capacity and a
    /// counter.
    fn fresh_key(&mut self) -> [u8; 32] {
        let mut hasher = Sha256::new();
        hasher.update(b"uo-capacity-sweep/key/v1");
        hasher.update(SWEEP_KEY_SEED.to_be_bytes());
        hasher.update((self.capacity as u64).to_be_bytes());
        hasher.update(self.next_key.to_be_bytes());
        self.next_key += 1;
        hasher.finalize().into()
    }

    /// A value no key has had; never zero, which would delete.
    fn fresh_value(&mut self) -> u64 {
        self.next_value += 1;
        self.next_value
    }

    fn pick_stored(&mut self) -> usize {
        self.picks.below(self.stored.len())
    }
}

/// What a call leaves in the map.
enum SweepEffect {
    Unchanged,
    Insert([u8; 32], u64),
    Overwrite(usize, u64),
    Delete(usize),
}

/// One planned call.
struct SweepCallPlan {
    operation: SweepOperation,
    args: Vec<Value>,
    /// What a read returns.
    expected_return: Option<u64>,
    effect: SweepEffect,
}

/// Plan a call of kind `wanted` on a map that may hold `level` keys. A kind
/// that needs a stored key becomes a read of an absent key or an insert when
/// the map is empty, and an insert becomes an overwrite when the map is at
/// its level; the plan names the kind it makes.
fn plan_sweep_call(wanted: SweepOperation, keys: &mut SweepKeys, level: usize) -> SweepCallPlan {
    let operation = if wanted.needs_stored_key() && keys.stored.is_empty() {
        if wanted.is_read() {
            SweepOperation::ReadMiss
        } else {
            SweepOperation::Insert
        }
    } else if wanted == SweepOperation::Insert && keys.stored.len() >= level {
        SweepOperation::Overwrite
    } else {
        wanted
    };
    let key = |bytes: [u8; 32]| Value::Bytes32(bytes);
    match operation {
        SweepOperation::ReadHit => {
            let index = keys.pick_stored();
            let (stored_key, value) = keys.stored[index];
            SweepCallPlan {
                operation,
                args: vec![key(stored_key)],
                expected_return: Some(value),
                effect: SweepEffect::Unchanged,
            }
        }
        SweepOperation::ReadMiss => SweepCallPlan {
            operation,
            args: vec![key(keys.fresh_key())],
            expected_return: Some(0),
            effect: SweepEffect::Unchanged,
        },
        SweepOperation::Insert => {
            let (new_key, value) = (keys.fresh_key(), keys.fresh_value());
            SweepCallPlan {
                operation,
                args: vec![key(new_key), Value::uint(value)],
                expected_return: None,
                effect: SweepEffect::Insert(new_key, value),
            }
        }
        SweepOperation::Overwrite => {
            let index = keys.pick_stored();
            let value = keys.fresh_value();
            SweepCallPlan {
                operation,
                args: vec![key(keys.stored[index].0), Value::uint(value)],
                expected_return: None,
                effect: SweepEffect::Overwrite(index, value),
            }
        }
        SweepOperation::NoopWrite => {
            let index = keys.pick_stored();
            let (stored_key, value) = keys.stored[index];
            SweepCallPlan {
                operation,
                args: vec![key(stored_key), Value::uint(value)],
                expected_return: None,
                effect: SweepEffect::Unchanged,
            }
        }
        SweepOperation::Delete => {
            let index = keys.pick_stored();
            SweepCallPlan {
                operation,
                args: vec![key(keys.stored[index].0)],
                expected_return: None,
                effect: SweepEffect::Delete(index),
            }
        }
        SweepOperation::Abort => {
            let index = keys.pick_stored();
            let value = keys.fresh_value();
            SweepCallPlan {
                operation,
                // No value is below a limit of zero.
                args: vec![
                    key(keys.stored[index].0),
                    Value::uint(value),
                    Value::uint(0),
                ],
                expected_return: None,
                effect: SweepEffect::Unchanged,
            }
        }
    }
}

/// One map operation's traced cost. An oblivious backend makes it the same
/// for every key and value, which the sweep checks across its trials, its
/// occupancy levels and the kinds of call an entrypoint serves.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct SweepCost {
    physical_reads: usize,
    physical_writes: usize,
    bytes_read: usize,
    bytes_written: usize,
    gas: u64,
}

impl SweepCost {
    fn bytes_moved(&self) -> usize {
        self.bytes_read + self.bytes_written
    }

    fn physical_operations(&self) -> usize {
        self.physical_reads + self.physical_writes
    }

    /// The metric the break-even compares, by name.
    fn metric(&self, metric: &str) -> u64 {
        match metric {
            "bytes_moved" => self.bytes_moved() as u64,
            "physical_operations" => self.physical_operations() as u64,
            _ => self.gas,
        }
    }
}

/// A read's and a write's traced cost on one backend and capacity.
#[derive(Clone, Copy)]
struct SweepCosts {
    read: SweepCost,
    write: SweepCost,
}

impl SweepCosts {
    /// The cost of a mix with `read_percent` reads, times 100: exact, so the
    /// break-even compares integers.
    fn mixed_times_100(&self, metric: &str, read_percent: u64) -> u64 {
        read_percent * self.read.metric(metric) + (100 - read_percent) * self.write.metric(metric)
    }
}

/// The mean latencies per call of the workloads one backend and capacity
/// executed at one occupancy level, in nanoseconds by read percent: the whole
/// call, and the call without the proof objects the instrumented runtime
/// builds.
#[derive(Clone, Default)]
struct SweepWorkloadLatencies {
    by_read_percent: BTreeMap<u64, (u64, u64)>,
}

impl SweepWorkloadLatencies {
    fn times_100(&self, metric: &str, read_percent: u64) -> u64 {
        let (call_ns, runtime_ns) = self
            .by_read_percent
            .get(&read_percent)
            .copied()
            .unwrap_or((u64::MAX / 100, u64::MAX / 100));
        100 * match metric {
            "call_latency_ns" => call_ns,
            _ => runtime_ns,
        }
    }
}

/// What Lean made of one sampled call.
struct SweepLeanCheck {
    checker: String,
    witness_json_bytes: u64,
    check_ns: u128,
}

/// One measured call.
struct SweepSample {
    operation: SweepOperation,
    cost: SweepCost,
    /// What the call read at its start, outside the trace: reads and bytes.
    call_start: (usize, usize),
    /// Sealed records the call's two witness snapshots opened.
    witness_records: u64,
    trace_json_bytes: usize,
    receipt_json_bytes: usize,
    latency_ns: u128,
    totals: InstrumentationTotals,
    /// Serializing the call's trace to JSON, after the call.
    json_ns: u128,
    rss_before_kb: u64,
    peak_rss_kb: u64,
    lean: Option<SweepLeanCheck>,
}

impl SweepSample {
    /// The call without its witnesses and proof objects: the runtime's own
    /// work, staging and loading included.
    fn runtime_ns(&self) -> u128 {
        self.latency_ns
            .saturating_sub(self.totals.witness_ns + self.totals.proof_objects_ns)
    }

    /// The runtime's own work without staging and loading.
    fn execution_ns(&self) -> u128 {
        self.runtime_ns()
            .saturating_sub(self.totals.staging_ns + self.totals.load_ns)
    }
}

fn read_rss_kb() -> u64 {
    fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|status| {
            status.lines().find_map(|line| {
                line.strip_prefix("VmRSS:")
                    .and_then(|rest| rest.split_whitespace().next()?.parse::<u64>().ok())
            })
        })
        .unwrap_or(0)
}

/// Start the process's resident-memory high-water mark again from its
/// current size, where the kernel allows it.
fn reset_peak_rss() -> bool {
    fs::write("/proc/self/clear_refs", "5").is_ok()
}

/// Lean's check of one call: the proof-grade runtime witness checker on the
/// call's refinement witness.
fn lean_check_call(checker: &Path, name: &str, trace: &ExecutionTrace) -> Result<SweepLeanCheck> {
    let witness = trace
        .runtime_refinement_witness()
        .map_err(|err| anyhow!("materializing the runtime refinement witness of {name}: {err}"))?;
    let (witness_path, witness_json_bytes) = write_temp_json(name, &witness)?;
    let started = Instant::now();
    let output = Command::new(checker)
        .arg(&witness_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()
        .with_context(|| format!("running the Lean witness checker on {name}"))?;
    let check_ns = started.elapsed().as_nanos();
    if !output.status.success() {
        bail!(
            "Lean rejected the witness of {name}: {} (witness kept at {})",
            String::from_utf8_lossy(&output.stderr).trim(),
            witness_path.display()
        );
    }
    let _ = fs::remove_file(&witness_path);
    Ok(SweepLeanCheck {
        checker: display_report_path(checker),
        witness_json_bytes,
        check_ns,
    })
}

/// Make one planned call, check what it did, and apply it to `keys`.
fn run_sweep_call(
    instance: &mut ContractInstance,
    artifact: &CompiledArtifact,
    plan: SweepCallPlan,
    keys: &mut SweepKeys,
    lean_checker: Option<(&Path, &str)>,
) -> Result<SweepSample> {
    let operation = plan.operation;
    let entrypoint = operation.entrypoint();
    uo_evm::take_instrumentation_totals();
    reset_peak_rss();
    let rss_before_kb = read_rss_kb();
    let started = Instant::now();
    let result = instance.call(entrypoint, plan.args)?;
    let latency_ns = started.elapsed().as_nanos();
    let totals = uo_evm::take_instrumentation_totals();
    let peak_rss_kb = read_max_rss_kb().unwrap_or(0);

    let aborts = operation == SweepOperation::Abort;
    if result.aborted != aborts {
        bail!(
            "{} {}",
            operation.label(),
            if result.aborted {
                "aborted"
            } else {
                "did not abort"
            }
        );
    }
    if let Some(expected) = plan.expected_return {
        if result.return_value != Some(Value::uint(expected)) {
            bail!(
                "{} returned {:?}, not {expected}",
                operation.label(),
                result.return_value
            );
        }
    }
    match plan.effect {
        SweepEffect::Unchanged => {}
        SweepEffect::Insert(key, value) => keys.stored.push((key, value)),
        SweepEffect::Overwrite(index, value) => keys.stored[index].1 = value,
        SweepEffect::Delete(index) => {
            keys.stored.swap_remove(index);
        }
    }

    let trace = &result.trace;
    let json_started = Instant::now();
    let trace_json_bytes = serde_json::to_vec(trace)?.len();
    let json_ns = json_started.elapsed().as_nanos();
    let receipt_json_bytes = serde_json::to_vec(result.receipt())?.len();
    let lean = lean_checker
        .map(|(checker, name)| lean_check_call(checker, name, trace))
        .transpose()?;
    Ok(SweepSample {
        operation,
        cost: SweepCost {
            physical_reads: trace.physical_reads.len(),
            physical_writes: trace.physical_writes.len(),
            bytes_read: trace.physical_reads.iter().map(|event| event.len).sum(),
            bytes_written: trace.physical_writes.iter().map(|event| event.len).sum(),
            gas: trace.gas_used,
        },
        call_start: call_start_decode(artifact, entrypoint, &trace.physical_reads)?,
        witness_records: totals.witness_records_opened,
        trace_json_bytes,
        receipt_json_bytes,
        latency_ns,
        totals,
        json_ns,
        rss_before_kb,
        peak_rss_kb,
        lean,
    })
}

fn sorted(mut values: Vec<u128>) -> Vec<u128> {
    values.sort_unstable();
    values
}

fn median_of(values: impl Iterator<Item = u128>) -> u128 {
    percentile_sorted(&sorted(values.collect()), 0.50)
}

/// A 95% percentile-bootstrap interval of `statistic` over `samples`: the
/// 2.5th and 97.5th percentiles of the statistic over resamples drawn with
/// replacement from a fixed seed.
fn bootstrap_ci95(samples: &[u128], statistic: impl Fn(&[u128]) -> f64) -> [f64; 2] {
    if samples.len() < 2 {
        let value = statistic(samples);
        return [value, value];
    }
    let mut rng = SplitMix64(SWEEP_KEY_SEED ^ samples.len() as u64);
    let mut resample = vec![0u128; samples.len()];
    let mut statistics = Vec::with_capacity(SWEEP_BOOTSTRAP_RESAMPLES);
    for _ in 0..SWEEP_BOOTSTRAP_RESAMPLES {
        for slot in resample.iter_mut() {
            *slot = samples[rng.below(samples.len())];
        }
        statistics.push(statistic(&resample));
    }
    statistics.sort_by(f64::total_cmp);
    let at =
        |quantile: f64| statistics[((statistics.len() - 1) as f64 * quantile).round() as usize];
    [at(0.025), at(0.975)]
}

fn median_statistic(samples: &[u128]) -> f64 {
    percentile_sorted(&sorted(samples.to_vec()), 0.50) as f64
}

fn mean_statistic(samples: &[u128]) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    samples.iter().map(|value| *value as f64).sum::<f64>() / samples.len() as f64
}

/// The compiled sweep contract with its map on `backend` at `capacity`.
fn sweep_map_artifact(
    capacity: usize,
    backend: &str,
    scheme: Option<&str>,
) -> Result<CompiledArtifact> {
    let mut metadata = load_metadata(SWEEP_METADATA)?;
    let state = metadata
        .state
        .get_mut(SWEEP_MAP)
        .ok_or_else(|| anyhow!("SweepMap metadata missing its {SWEEP_MAP} state"))?;
    state.capacity = Some(capacity);
    state.backend = backend.into();
    state.oram_scheme = scheme.map(Into::into);
    compile_artifact_from_metadata(SWEEP_SOURCE, &metadata, ProgramMode::Uo)
}

fn max_stash_bound(artifact: &CompiledArtifact) -> usize {
    artifact
        .contract
        .manifest
        .objects
        .iter()
        .filter_map(|object| object.oram.as_ref().map(|oram| oram.stash_bound))
        .max()
        .unwrap_or_default()
}

/// Fill the map up to `level` keys through the bulk loader.
fn fill_to_level(
    instance: &mut ContractInstance,
    keys: &mut SweepKeys,
    level: usize,
) -> Result<usize> {
    let missing = level.saturating_sub(keys.stored.len());
    if missing == 0 {
        return Ok(0);
    }
    let added: Vec<([u8; 32], u64)> = (0..missing)
        .map(|_| (keys.fresh_key(), keys.fresh_value()))
        .collect();
    instance.bulk_load_map_for_diagnostics(
        SWEEP_MAP,
        added
            .iter()
            .map(|(key, value)| (Value::Bytes32(*key), Value::uint(*value)))
            .collect(),
    )?;
    keys.stored.extend(added);
    Ok(missing)
}

/// The identification every row of one cell starts with.
fn cell_row(
    backend: &str,
    capacity: usize,
    stored_keys: usize,
    labels: &[String],
) -> serde_json::Map<String, JsonValue> {
    let mut row = serde_json::Map::new();
    row.insert("backend".into(), json!(backend));
    row.insert("capacity".into(), json!(capacity));
    row.insert("stored_keys".into(), json!(stored_keys));
    row.insert("occupancy".into(), json!(labels));
    row
}

/// The row of one kind of call at one cell, from its measured samples.
fn operation_row(
    mut row: serde_json::Map<String, JsonValue>,
    operation: SweepOperation,
    samples: &[SweepSample],
    artifact: &CompiledArtifact,
) -> Result<(JsonValue, SweepCost, bool, bool)> {
    let first = samples
        .first()
        .ok_or_else(|| anyhow!("no {} was measured", operation.label()))?;
    // The manifest's bounds on the sealed records the call reads and writes,
    // which the modeled cost charges. The reads include those at the call's
    // start, which no trace records.
    let entry = artifact
        .contract
        .manifest
        .entrypoints
        .get(operation.entrypoint())
        .ok_or_else(|| anyhow!("manifest entry missing for {}", operation.entrypoint()))?;
    let within_manifest_bounds = samples.iter().all(|sample| {
        sample.cost.physical_reads + sample.call_start.0 <= entry.max_load_ops
            && sample.cost.physical_writes <= entry.max_commit_ops
    });
    let same_for_every_trial = samples.iter().all(|sample| {
        sample.cost == first.cost
            && sample.call_start == first.call_start
            && sample.witness_records == first.witness_records
    });
    let median = |pick: &dyn Fn(&SweepSample) -> u128| median_of(samples.iter().map(pick));
    let series = |pick: &dyn Fn(&SweepSample) -> u128| -> Vec<u128> {
        sorted(samples.iter().map(pick).collect())
    };
    let latencies = series(&|sample| sample.latency_ns);
    let runtimes = series(&|sample| sample.runtime_ns());
    let trace_json_bytes = median(&|sample| sample.trace_json_bytes as u128);
    let receipt_json_bytes = median(&|sample| sample.receipt_json_bytes as u128);
    let mut timing = serde_json::Map::new();
    for (name, value) in [
        ("p50_latency_ns", percentile_sorted(&latencies, 0.50)),
        ("p95_latency_ns", percentile_sorted(&latencies, 0.95)),
        ("p50_runtime_ns", percentile_sorted(&runtimes, 0.50)),
        ("p95_runtime_ns", percentile_sorted(&runtimes, 0.95)),
        ("p50_staging_ns", median(&|sample| sample.totals.staging_ns)),
        ("p50_load_ns", median(&|sample| sample.totals.load_ns)),
        ("p50_execution_ns", median(&|sample| sample.execution_ns())),
        ("p50_witness_ns", median(&|sample| sample.totals.witness_ns)),
        (
            "p50_proof_objects_ns",
            median(&|sample| sample.totals.proof_objects_ns),
        ),
        (
            "p50_json_serialization_ns",
            median(&|sample| sample.json_ns),
        ),
        (
            "p50_rss_before_bytes",
            median(&|sample| u128::from(sample.rss_before_kb) * 1024),
        ),
        (
            "p50_peak_rss_bytes",
            median(&|sample| u128::from(sample.peak_rss_kb) * 1024),
        ),
        (
            "max_peak_rss_bytes",
            samples
                .iter()
                .map(|sample| u128::from(sample.peak_rss_kb) * 1024)
                .max()
                .unwrap_or(0),
        ),
    ] {
        timing.insert(name.into(), json!(value));
    }
    timing.insert(
        "ci95_latency_ns".into(),
        json!(bootstrap_ci95(&latencies, median_statistic)),
    );
    timing.insert(
        "ci95_runtime_ns".into(),
        json!(bootstrap_ci95(&runtimes, median_statistic)),
    );
    if let Some(lean) = samples.iter().find_map(|sample| sample.lean.as_ref()) {
        timing.insert(
            "lean_check".into(),
            json!({
                "checker": lean.checker,
                "sampled_calls": 1,
                "check_ns": lean.check_ns,
            }),
        );
        row.insert(
            "lean_checked_witness_json_bytes".into(),
            json!(lean.witness_json_bytes),
        );
        row.insert("lean_accepted".into(), json!(true));
    }
    row.insert("operation".into(), json!(operation.label()));
    row.insert("entrypoint".into(), json!(operation.entrypoint()));
    row.insert("status".into(), json!("ok"));
    row.insert("completed_trials".into(), json!(samples.len()));
    // A string, not a flag: the acceptance check reads every `false` in a
    // report as a failed obligation unless it is told otherwise.
    row.insert(
        "outcome".into(),
        json!(if operation == SweepOperation::Abort {
            "aborted"
        } else {
            "committed"
        }),
    );
    row.insert(
        "cost_same_for_every_trial".into(),
        json!(same_for_every_trial),
    );
    row.insert("physical_reads".into(), json!(first.cost.physical_reads));
    row.insert("physical_writes".into(), json!(first.cost.physical_writes));
    row.insert("bytes_read".into(), json!(first.cost.bytes_read));
    row.insert("bytes_written".into(), json!(first.cost.bytes_written));
    row.insert("bytes_moved".into(), json!(first.cost.bytes_moved()));
    row.insert("gas".into(), json!(first.cost.gas));
    row.insert("max_load_ops".into(), json!(entry.max_load_ops));
    row.insert("max_commit_ops".into(), json!(entry.max_commit_ops));
    row.insert("call_start_reads".into(), json!(first.call_start.0));
    row.insert("call_start_bytes".into(), json!(first.call_start.1));
    row.insert("witness_scan_records".into(), json!(first.witness_records));
    row.insert("trace_json_bytes".into(), json!(trace_json_bytes));
    row.insert("receipt_json_bytes".into(), json!(receipt_json_bytes));
    row.insert(
        "evidence_json_bytes".into(),
        json!(trace_json_bytes.saturating_sub(receipt_json_bytes)),
    );
    row.insert("timing".into(), JsonValue::Object(timing));
    Ok((
        JsonValue::Object(row),
        first.cost,
        same_for_every_trial,
        within_manifest_bounds,
    ))
}

/// The kinds a workload of `calls` calls with `read_percent` reads makes, in
/// order: the reads alternate a stored and an absent key, the writes cycle
/// through every kind, and a seeded shuffle places the reads among them.
fn workload_schedule(calls: usize, read_percent: u64, rng: &mut SplitMix64) -> Vec<SweepOperation> {
    let reads = ((calls as u64 * read_percent + 50) / 100) as usize;
    let mut is_read: Vec<bool> = (0..calls).map(|index| index < reads).collect();
    for index in (1..calls).rev() {
        is_read.swap(index, rng.below(index + 1));
    }
    let (mut next_read, mut next_write) = (0usize, 0usize);
    is_read
        .into_iter()
        .map(|read| {
            if read {
                next_read += 1;
                SweepOperation::WORKLOAD_READS
                    [(next_read - 1) % SweepOperation::WORKLOAD_READS.len()]
            } else {
                next_write += 1;
                SweepOperation::WORKLOAD_WRITES
                    [(next_write - 1) % SweepOperation::WORKLOAD_WRITES.len()]
            }
        })
        .collect()
}

/// The row of one executed workload, from its calls and the cell's computed
/// read and write costs.
fn workload_row(
    mut row: serde_json::Map<String, JsonValue>,
    read_percent: u64,
    samples: &[SweepSample],
    costs: Option<&SweepCosts>,
) -> (JsonValue, (u64, u64)) {
    let calls = samples.len().max(1) as u64;
    let reads = samples
        .iter()
        .filter(|sample| sample.operation.is_read())
        .count() as u64;
    let mut operations = serde_json::Map::new();
    for operation in SweepOperation::ROUND {
        let count = samples
            .iter()
            .filter(|sample| sample.operation == operation)
            .count();
        operations.insert(operation.label().into(), json!(count));
    }
    let total = |metric: &str| -> u64 {
        samples
            .iter()
            .map(|sample| sample.cost.metric(metric))
            .sum()
    };
    let mut executed = serde_json::Map::new();
    let mut computed = serde_json::Map::new();
    for metric in CAPACITY_SWEEP_METRICS {
        executed.insert(metric.into(), json!(total(metric) as f64 / calls as f64));
        if let Some(costs) = costs {
            // The mix of this many reads and writes, from one read's and one
            // write's cost.
            let mixed =
                reads * costs.read.metric(metric) + (calls - reads) * costs.write.metric(metric);
            computed.insert(metric.into(), json!(mixed as f64 / calls as f64));
        }
    }
    let latencies: Vec<u128> = samples.iter().map(|sample| sample.latency_ns).collect();
    let runtimes: Vec<u128> = samples.iter().map(|sample| sample.runtime_ns()).collect();
    let mean_latency = mean_statistic(&latencies);
    let mean_runtime = mean_statistic(&runtimes);
    let sorted_latencies = sorted(latencies.clone());
    row.insert("read_fraction".into(), json!(read_percent as f64 / 100.0));
    row.insert("status".into(), json!("ok"));
    row.insert("calls".into(), json!(samples.len()));
    row.insert("reads".into(), json!(reads));
    row.insert("writes".into(), json!(calls - reads));
    row.insert("operations".into(), JsonValue::Object(operations));
    row.insert("executed_per_call".into(), JsonValue::Object(executed));
    row.insert("computed_per_call".into(), JsonValue::Object(computed));
    row.insert(
        "timing".into(),
        json!({
            "mean_latency_ns": mean_latency,
            "ci95_mean_latency_ns": bootstrap_ci95(&latencies, mean_statistic),
            "p50_latency_ns": percentile_sorted(&sorted_latencies, 0.50),
            "p95_latency_ns": percentile_sorted(&sorted_latencies, 0.95),
            "mean_runtime_ns": mean_runtime,
            "ci95_mean_runtime_ns": bootstrap_ci95(&runtimes, mean_statistic),
        }),
    );
    (
        JsonValue::Object(row),
        (mean_latency.round() as u64, mean_runtime.round() as u64),
    )
}

/// What one backend and capacity add to the report.
#[derive(Default)]
struct SweepOutput {
    artifacts: Vec<JsonValue>,
    fills: Vec<JsonValue>,
    rows: Vec<JsonValue>,
    workloads: Vec<JsonValue>,
    /// The cells that could not be measured.
    failed_cells: usize,
    /// Per occupancy cell, in order: each kind's cost, and whether it was
    /// the same in every trial.
    cell_costs: Vec<BTreeMap<SweepOperation, SweepCost>>,
    cost_same_for_every_trial: bool,
    /// Whether every call read and wrote within its manifest's bounds.
    within_manifest_bounds: bool,
    /// Per occupancy label: the executed workloads' mean latencies.
    workload_latencies: BTreeMap<String, SweepWorkloadLatencies>,
    toolchain_manifest_sha256: Option<String>,
}

/// Measure one backend at one capacity: compile, deploy, and at each
/// occupancy level fill, measure every kind of call and execute every
/// workload.
fn sweep_backend_capacity(
    parameters: &SweepParameters,
    label: &'static str,
    backend: &str,
    scheme: Option<&str>,
    capacity: usize,
    lean_checker: Option<&Path>,
) -> Result<SweepOutput> {
    let mut output = SweepOutput {
        cost_same_for_every_trial: true,
        within_manifest_bounds: true,
        ..SweepOutput::default()
    };
    let compile_started = Instant::now();
    let artifact = match sweep_map_artifact(capacity, backend, scheme) {
        Ok(artifact) => artifact,
        Err(err) => {
            output.artifacts.push(json!({
                "backend": label,
                "capacity": capacity,
                "status": "rejected",
                "error": format!("{err:#}"),
            }));
            return Ok(output);
        }
    };
    let compile_ms = compile_started.elapsed().as_millis();
    output.toolchain_manifest_sha256 = artifact
        .admitted_package
        .as_ref()
        .map(|package| package.toolchain_manifest_sha256.clone());
    let mut resource_bounds = serde_json::Map::new();
    for entrypoint in [
        "read(bytes32)",
        "put(bytes32,uint256)",
        "clear(bytes32)",
        "putBelow(bytes32,uint256,uint256)",
    ] {
        resource_bounds.insert(
            entrypoint.into(),
            json!(serde_json::to_vec(
                &artifact
                    .contract
                    .manifest
                    .entrypoint_resource_bounds(entrypoint)?
            )?
            .len()),
        );
    }
    output.artifacts.push(json!({
        "backend": label,
        "capacity": capacity,
        "status": "ok",
        "artifact_json_bytes": serde_json::to_vec(&artifact)?.len(),
        "resource_bounds_json_bytes": resource_bounds,
        "stash_bound": max_stash_bound(&artifact),
        "timing": { "compile_ms": compile_ms },
    }));

    let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), PROBE_DEPLOY_SEED)?;
    let mut keys = SweepKeys::new(capacity);
    let mut workload_order =
        SplitMix64(SWEEP_KEY_SEED.rotate_left(17).wrapping_add(capacity as u64));
    let lean_here = lean_checker.filter(|_| parameters.lean_capacities.contains(&capacity));
    for (cell_index, (level, labels)) in parameters.cells(capacity).into_iter().enumerate() {
        let cell = || cell_row(label, capacity, level, &labels);
        let fill_started = Instant::now();
        let loaded = match fill_to_level(&mut instance, &mut keys, level) {
            Ok(loaded) => loaded,
            Err(err) => {
                // The map is as the last level left it, and the levels above
                // need this one.
                let mut row = cell();
                row.insert("status".into(), json!("error"));
                row.insert("error".into(), json!(format!("{err:#}")));
                output.fills.push(JsonValue::Object(row));
                output.failed_cells += 1;
                break;
            }
        };
        let fill_ms = fill_started.elapsed().as_millis();
        let digest_ns = median_of(
            (0..3)
                .map(|_| -> Result<u128> {
                    let started = Instant::now();
                    instance.ciphertext_store_digest()?;
                    Ok(started.elapsed().as_nanos())
                })
                .collect::<Result<Vec<_>>>()?
                .into_iter(),
        );
        let mut fill = cell();
        fill.insert("status".into(), json!("ok"));
        fill.insert("keys_loaded".into(), json!(loaded));
        fill.insert(
            "timing".into(),
            json!({
                "fill_ms": fill_ms,
                "p50_store_digest_ns": digest_ns,
                "rss_after_fill_bytes": read_rss_kb() * 1024,
            }),
        );
        output.fills.push(JsonValue::Object(fill));

        let measured = (|| -> Result<(Vec<JsonValue>, Vec<JsonValue>)> {
            // Each kind of call, in rounds.
            let mut samples: BTreeMap<SweepOperation, Vec<SweepSample>> = BTreeMap::new();
            for round in 0..parameters.warmups + parameters.trials {
                for wanted in SweepOperation::ROUND {
                    let plan = plan_sweep_call(wanted, &mut keys, level);
                    let operation = plan.operation;
                    // Lean checks the first measured call of each kind at
                    // the first level.
                    let lean_name =
                        format!("capacity-sweep-{label}-{capacity}-{}", operation.label());
                    let lean = lean_here
                        .filter(|_| cell_index == 0 && round == parameters.warmups)
                        .map(|checker| (checker, lean_name.as_str()));
                    let sample = run_sweep_call(&mut instance, &artifact, plan, &mut keys, lean)
                        .with_context(|| format!("round {round}, {}", operation.label()))?;
                    if round >= parameters.warmups {
                        samples.entry(operation).or_default().push(sample);
                    }
                }
            }
            let mut rows = Vec::new();
            let mut costs = BTreeMap::new();
            for operation in SweepOperation::ROUND {
                let Some(operation_samples) = samples.get(&operation) else {
                    continue;
                };
                let (row, cost, same, within_bounds) =
                    operation_row(cell(), operation, operation_samples, &artifact)?;
                rows.push(row);
                costs.insert(operation, cost);
                output.cost_same_for_every_trial &= same;
                output.within_manifest_bounds &= within_bounds;
            }
            let mix_costs = match (
                costs.get(&SweepOperation::ReadHit),
                costs.get(&SweepOperation::Overwrite),
            ) {
                (Some(read), Some(write)) => Some(SweepCosts {
                    read: *read,
                    write: *write,
                }),
                _ => None,
            };
            output.cell_costs.push(costs);

            // The workloads, each restored to the level afterwards.
            let mut workloads = Vec::new();
            let mut latencies = SweepWorkloadLatencies::default();
            for &read_percent in &parameters.read_percents {
                if parameters.workload_calls == 0 {
                    break;
                }
                let schedule =
                    workload_schedule(parameters.workload_calls, read_percent, &mut workload_order);
                let mut workload_samples = Vec::with_capacity(schedule.len());
                for (index, wanted) in schedule.into_iter().enumerate() {
                    let plan = plan_sweep_call(wanted, &mut keys, level);
                    let operation = plan.operation;
                    workload_samples.push(
                        run_sweep_call(&mut instance, &artifact, plan, &mut keys, None)
                            .with_context(|| {
                                format!(
                                    "workload with {read_percent}% reads, call {index}, {}",
                                    operation.label()
                                )
                            })?,
                    );
                }
                fill_to_level(&mut instance, &mut keys, level)?;
                let (row, means) =
                    workload_row(cell(), read_percent, &workload_samples, mix_costs.as_ref());
                workloads.push(row);
                latencies.by_read_percent.insert(read_percent, means);
            }
            if latencies.by_read_percent.len() == parameters.read_percents.len() {
                for label in &labels {
                    output
                        .workload_latencies
                        .insert(label.clone(), latencies.clone());
                }
            }
            Ok((rows, workloads))
        })();
        match measured {
            Ok((rows, workloads)) => {
                output.rows.extend(rows);
                output.workloads.extend(workloads);
            }
            Err(err) => {
                // A failed call may have left the map off its level.
                let mut row = cell();
                row.insert("status".into(), json!("error"));
                row.insert("error".into(), json!(format!("{err:#}")));
                output.rows.push(JsonValue::Object(row));
                output.failed_cells += 1;
                break;
            }
        }
    }
    Ok(output)
}

pub(crate) fn run_capacity_sweep(profile: SweepProfile) -> Result<JsonValue> {
    sweep_with_parameters(&SweepParameters::from_env(profile))
}

fn sweep_with_parameters(parameters: &SweepParameters) -> Result<JsonValue> {
    let lean_checker: Option<PathBuf> = if parameters
        .lean_capacities
        .iter()
        .any(|capacity| parameters.capacities.contains(capacity))
    {
        Some(lean_proofgrade_witness_checker_path()?)
    } else {
        None
    };
    let peak_rss_scope = if reset_peak_rss() {
        "the resident-set high-water mark of the probe process, started again before each call"
    } else {
        "the resident-set high-water mark of the probe process since it started"
    };

    let mut artifacts = Vec::new();
    let mut fills = Vec::new();
    let mut rows = Vec::new();
    let mut workloads = Vec::new();
    let mut failed_cells = 0usize;
    let mut cost_same_for_every_trial = true;
    let mut reads_and_writes_within_manifest_bounds = true;
    let mut cost_same_at_every_occupancy = true;
    let mut cost_same_for_every_kind_of_an_entrypoint = true;
    let mut costs: BTreeMap<(&'static str, usize), SweepCosts> = BTreeMap::new();
    let mut latencies: BTreeMap<String, BTreeMap<(&'static str, usize), SweepWorkloadLatencies>> =
        BTreeMap::new();
    let mut toolchain_manifest_sha256 = None;
    for &capacity in &parameters.capacities {
        for (label, backend, scheme) in CAPACITY_SWEEP_BACKENDS {
            let past_local_limit = scheme == Some("path_oram_local_posmap_v1")
                && capacity > CAPACITY_SWEEP_LOCAL_LIMIT;
            if past_local_limit && capacity > 2 * CAPACITY_SWEEP_LOCAL_LIMIT {
                continue;
            }
            let output = sweep_backend_capacity(
                parameters,
                label,
                backend,
                scheme,
                capacity,
                lean_checker.as_deref(),
            )
            .with_context(|| format!("capacity sweep of {label} at capacity {capacity}"))?;
            artifacts.extend(output.artifacts);
            fills.extend(output.fills);
            rows.extend(output.rows);
            workloads.extend(output.workloads);
            failed_cells += output.failed_cells;
            cost_same_for_every_trial &= output.cost_same_for_every_trial;
            reads_and_writes_within_manifest_bounds &= output.within_manifest_bounds;
            toolchain_manifest_sha256 =
                toolchain_manifest_sha256.or(output.toolchain_manifest_sha256);
            if let Some(first) = output.cell_costs.first() {
                cost_same_at_every_occupancy &= output.cell_costs.iter().all(|cell| cell == first);
                if let (Some(read), Some(write)) = (
                    first.get(&SweepOperation::ReadHit),
                    first.get(&SweepOperation::Overwrite),
                ) {
                    costs.insert(
                        (label, capacity),
                        SweepCosts {
                            read: *read,
                            write: *write,
                        },
                    );
                }
            }
            for cell in &output.cell_costs {
                let mut by_entrypoint: BTreeMap<&str, SweepCost> = BTreeMap::new();
                for (operation, cost) in cell {
                    let first = by_entrypoint.entry(operation.entrypoint()).or_insert(*cost);
                    cost_same_for_every_kind_of_an_entrypoint &= first == cost;
                }
            }
            for (occupancy, workload_latencies) in output.workload_latencies {
                latencies
                    .entry(occupancy)
                    .or_default()
                    .insert((label, capacity), workload_latencies);
            }
        }
    }

    let mut latency_break_even = Vec::new();
    for occupancy in parameters.occupancy_labels() {
        let Some(at_level) = latencies.get(&occupancy) else {
            continue;
        };
        let JsonValue::Array(pairs) = break_even_over(
            at_level,
            &parameters.capacities,
            &parameters.read_percents,
            &CAPACITY_SWEEP_LATENCY_METRICS,
            |latencies: &SweepWorkloadLatencies, metric, percent| {
                latencies.times_100(metric, percent)
            },
        ) else {
            continue;
        };
        for pair in pairs {
            let JsonValue::Object(mut pair) = pair else {
                continue;
            };
            latency_break_even.push(json!({
                "occupancy": occupancy,
                "baseline": pair.remove("baseline"),
                "candidate": pair.remove("candidate"),
                "read_fraction": pair.remove("read_fraction"),
                "capacities_compared": pair.remove("capacities_compared"),
                "timing": {
                    "call_latency_ns_from_capacity": pair.remove("call_latency_ns_from_capacity"),
                    "runtime_latency_ns_from_capacity":
                        pair.remove("runtime_latency_ns_from_capacity"),
                },
            }));
        }
    }

    let mut operations = serde_json::Map::new();
    for operation in SweepOperation::ROUND {
        operations.insert(operation.label().into(), json!(operation.description()));
    }
    let mut report = json!({
        "schema": CAPACITY_SWEEP_SCHEMA,
        "contract": "SweepMap",
        "cost_model": super::RESOURCE_COST_MODEL,
        "profile": match parameters.profile {
            SweepProfile::Quick => "quick",
            SweepProfile::Full => "full",
        },
        "build_profile": if cfg!(debug_assertions) { "debug" } else { "release" },
        "operations": operations,
        "parameters": {
            "capacities": parameters.capacities,
            "occupancy_levels": parameters.occupancy_labels(),
            "occupancy_capacity_limit": parameters.occupancy_capacity_limit,
            "read_fractions": parameters
                .read_percents
                .iter()
                .map(|percent| *percent as f64 / 100.0)
                .collect::<Vec<_>>(),
            "warmup_rounds": parameters.warmups,
            "trials": parameters.trials,
            "workload_calls": parameters.workload_calls,
            "lean_checked_capacities": parameters.lean_capacities,
            "bootstrap_resamples": SWEEP_BOOTSTRAP_RESAMPLES,
            "key_seed": format!("{SWEEP_KEY_SEED:#018x}"),
        },
        "count_checks": {
            "every_cell_measured": failed_cells == 0,
            "cost_same_for_every_trial": cost_same_for_every_trial,
            "reads_and_writes_within_manifest_bounds": reads_and_writes_within_manifest_bounds,
            "cost_same_at_every_occupancy": cost_same_at_every_occupancy,
            "cost_same_for_every_kind_of_an_entrypoint": cost_same_for_every_kind_of_an_entrypoint,
        },
        "artifacts": artifacts,
        "fills": fills,
        "rows": rows,
        "workloads": workloads,
        "mix": capacity_sweep_mix(&costs, &parameters.read_percents),
        "break_even": capacity_sweep_break_even(
            &costs,
            &parameters.capacities,
            &parameters.read_percents,
        ),
        "latency_break_even": latency_break_even,
        "provenance": {
            "toolchain_manifest_sha256": toolchain_manifest_sha256,
            "peak_rss": peak_rss_scope,
        },
    });
    let digest = counts_sha256(&report);
    if let JsonValue::Object(report) = &mut report {
        report.insert("counts_sha256".into(), json!(digest));
    }
    Ok(report)
}

/// The digest of everything in the report that is a function of the seed:
/// the report without its `timing` objects, the provenance of the build, the
/// build profile and the digest itself.
pub(crate) fn counts_sha256(report: &JsonValue) -> String {
    fn without_timing(value: &JsonValue) -> JsonValue {
        match value {
            JsonValue::Object(map) => JsonValue::Object(
                map.iter()
                    .filter(|(key, _)| key.as_str() != "timing")
                    .map(|(key, value)| (key.clone(), without_timing(value)))
                    .collect(),
            ),
            JsonValue::Array(items) => JsonValue::Array(items.iter().map(without_timing).collect()),
            other => other.clone(),
        }
    }
    let mut counts = without_timing(report);
    if let JsonValue::Object(counts) = &mut counts {
        for key in ["provenance", "build_profile", "counts_sha256"] {
            counts.remove(key);
        }
    }
    hex::encode(Sha256::digest(
        serde_json::to_vec(&counts).unwrap_or_default(),
    ))
}

/// Each backend's and capacity's mixed cost at each read fraction.
fn capacity_sweep_mix(
    costs: &BTreeMap<(&'static str, usize), SweepCosts>,
    read_percents: &[u64],
) -> Vec<JsonValue> {
    let mut mix = Vec::new();
    for ((label, capacity), measured) in costs {
        for &percent in read_percents {
            let mut row = serde_json::Map::new();
            row.insert("backend".into(), json!(label));
            row.insert("capacity".into(), json!(capacity));
            row.insert("read_fraction".into(), json!(percent as f64 / 100.0));
            for metric in CAPACITY_SWEEP_METRICS {
                row.insert(
                    metric.into(),
                    json!(measured.mixed_times_100(metric, percent) as f64 / 100.0),
                );
            }
            mix.push(JsonValue::Object(row));
        }
    }
    mix
}

/// For each pair of backends, read fraction and metric: the smallest swept
/// capacity from which the second backend's mixed cost is at most the
/// first's at every larger capacity both reach, or null if there is none.
fn capacity_sweep_break_even(
    costs: &BTreeMap<(&'static str, usize), SweepCosts>,
    capacities: &[usize],
    read_percents: &[u64],
) -> JsonValue {
    break_even_over(
        costs,
        capacities,
        read_percents,
        &CAPACITY_SWEEP_METRICS,
        |costs: &SweepCosts, metric, percent| costs.mixed_times_100(metric, percent),
    )
}

fn break_even_over<T>(
    costs: &BTreeMap<(&'static str, usize), T>,
    capacities: &[usize],
    read_percents: &[u64],
    metrics: &[&str],
    mixed_times_100: impl Fn(&T, &str, u64) -> u64,
) -> JsonValue {
    let pairs = [
        ("full_scan", "path_oram_local_posmap_v1"),
        ("full_scan", "path_oram_private_posmap_v1"),
        ("path_oram_local_posmap_v1", "path_oram_private_posmap_v1"),
    ];
    let mut sorted = capacities.to_vec();
    sorted.sort_unstable();
    sorted.dedup();
    let mut result = Vec::new();
    for (base, other) in pairs {
        let compared: Vec<usize> = sorted
            .iter()
            .copied()
            .filter(|capacity| {
                costs.contains_key(&(base, *capacity)) && costs.contains_key(&(other, *capacity))
            })
            .collect();
        for &percent in read_percents {
            let mut row = serde_json::Map::new();
            row.insert("baseline".into(), json!(base));
            row.insert("candidate".into(), json!(other));
            row.insert("read_fraction".into(), json!(percent as f64 / 100.0));
            row.insert("capacities_compared".into(), json!(compared));
            for &metric in metrics {
                let mut from = None;
                for &capacity in compared.iter().rev() {
                    let (Some(base_costs), Some(other_costs)) =
                        (costs.get(&(base, capacity)), costs.get(&(other, capacity)))
                    else {
                        break;
                    };
                    if mixed_times_100(other_costs, metric, percent)
                        <= mixed_times_100(base_costs, metric, percent)
                    {
                        from = Some(capacity);
                    } else {
                        break;
                    }
                }
                row.insert(format!("{metric}_from_capacity"), json!(from));
            }
            result.push(JsonValue::Object(row));
        }
    }
    JsonValue::Array(result)
}

#[cfg(test)]
mod tests {
    use super::{
        bootstrap_ci95, capacity_sweep_break_even, counts_sha256, mean_statistic, median_statistic,
        plan_sweep_call, workload_schedule, OccupancyLevel, SplitMix64, SweepCost, SweepCosts,
        SweepEffect, SweepKeys, SweepOperation, SweepParameters, SweepProfile,
    };
    use serde_json::json;

    #[test]
    fn capacity_sweep_break_even_is_the_stable_crossover() {
        let cost = |ops: usize| SweepCost {
            physical_reads: ops,
            physical_writes: 0,
            bytes_read: ops,
            bytes_written: 0,
            gas: ops as u64,
        };
        let costs_of = |read: usize, write: usize| SweepCosts {
            read: cost(read),
            write: cost(write),
        };
        let mut costs = std::collections::BTreeMap::new();
        // The full scan grows linearly. The candidate's reads are cheaper from
        // 4, after a dip at 1 that does not last; its writes only at 8.
        for (capacity, full, read, write) in
            [(1, 1, 0, 9), (2, 2, 3, 9), (4, 4, 4, 9), (8, 8, 5, 8)]
        {
            costs.insert(("full_scan", capacity), costs_of(full, full));
            costs.insert(
                ("path_oram_private_posmap_v1", capacity),
                costs_of(read, write),
            );
        }
        let rows = capacity_sweep_break_even(&costs, &[1, 2, 4, 8], &[0, 50, 100]);
        let from = |read_fraction: f64| {
            rows.as_array()
                .unwrap()
                .iter()
                .find(|row| {
                    row["candidate"] == "path_oram_private_posmap_v1"
                        && row["baseline"] == "full_scan"
                        && row["read_fraction"].as_f64() == Some(read_fraction)
                })
                .unwrap()["bytes_moved_from_capacity"]
                .clone()
        };
        assert_eq!(from(1.0), json!(4));
        assert_eq!(from(0.5), json!(8));
        assert_eq!(from(0.0), json!(8));
        // A pair with no capacity in common has no break-even.
        let local = rows
            .as_array()
            .unwrap()
            .iter()
            .find(|row| row["candidate"] == "path_oram_local_posmap_v1")
            .unwrap();
        assert_eq!(local["bytes_moved_from_capacity"], serde_json::Value::Null);
        assert_eq!(local["capacities_compared"], json!([]));
    }

    #[test]
    fn the_counts_of_a_sweep_repeat_between_runs() {
        let parameters = SweepParameters {
            profile: SweepProfile::Quick,
            capacities: vec![4, 16],
            occupancy_percents: vec![50, 100],
            occupancy_capacity_limit: 16,
            read_percents: vec![0, 50, 100],
            warmups: 0,
            trials: 2,
            workload_calls: 4,
            // No Lean check: the test needs no built checker.
            lean_capacities: Vec::new(),
        };
        let first = super::sweep_with_parameters(&parameters).unwrap();
        let second = super::sweep_with_parameters(&parameters).unwrap();
        assert_eq!(first["schema"], json!("uo-capacity-sweep-v4"));
        assert_eq!(first["counts_sha256"], second["counts_sha256"]);
        assert_eq!(first["counts_sha256"], json!(counts_sha256(&first)));
        for check in [
            "every_cell_measured",
            "cost_same_for_every_trial",
            "reads_and_writes_within_manifest_bounds",
            "cost_same_at_every_occupancy",
            "cost_same_for_every_kind_of_an_entrypoint",
        ] {
            assert_eq!(first["count_checks"][check], json!(true), "{check}");
        }
        // Three backends at two capacities, the levels of each (2, 4 keys;
        // 2, 8, 16 keys), seven kinds of call and three workloads at each.
        let rows = first["rows"].as_array().unwrap();
        assert_eq!(rows.len(), 3 * (2 + 3) * 7);
        assert_eq!(
            first["workloads"].as_array().unwrap().len(),
            3 * (2 + 3) * 3
        );
        assert_eq!(first["fills"].as_array().unwrap().len(), 3 * (2 + 3));
        assert!(rows.iter().all(|row| row["status"] == "ok"
            && row["completed_trials"] == json!(2)
            && row["timing"]["ci95_latency_ns"].as_array().map(Vec::len) == Some(2)));
        // An abort is the only kind that aborts, and a workload runs what
        // its mix computes.
        for row in rows {
            let outcome = if row["operation"] == "abort" {
                "aborted"
            } else {
                "committed"
            };
            assert_eq!(row["outcome"], json!(outcome));
        }
        // The untraced work is what the map's public shape says: a call on
        // a Path ORAM map reads the counter and the metadata pages at its
        // start, and its two witness snapshots open every bucket and
        // metadata page of a tree, or every position-map page of the local
        // scheme. The full scan has neither.
        for (label, backend, scheme) in super::CAPACITY_SWEEP_BACKENDS {
            for capacity in [4usize, 16] {
                let artifact = super::sweep_map_artifact(capacity, backend, scheme).unwrap();
                let oram = artifact
                    .contract
                    .manifest
                    .objects
                    .iter()
                    .find_map(|object| object.oram.as_ref());
                let (call_start, witness) = match oram {
                    None => (0, 0),
                    Some(oram) => {
                        let opened = if scheme == Some("path_oram_private_posmap_v1") {
                            oram.bucket_count + oram.metadata_pages
                        } else {
                            capacity.div_ceil(8)
                        };
                        (1 + oram.metadata_pages, 2 * opened)
                    }
                };
                let mut seen = 0;
                for row in rows
                    .iter()
                    .filter(|row| row["backend"] == label && row["capacity"] == json!(capacity))
                {
                    seen += 1;
                    assert_eq!(
                        row["call_start_reads"],
                        json!(call_start),
                        "{label} {capacity}"
                    );
                    assert_eq!(
                        row["witness_scan_records"],
                        json!(witness),
                        "{label} {capacity}"
                    );
                    // The manifest's load bound, which the modeled cost
                    // charges, is what the call reads, traced and at its
                    // start, on the full scan and the local scheme; on the
                    // tree it is a bound, which counts the metadata pages
                    // once per node access.
                    let count = |field: &str| row[field].as_u64().unwrap();
                    let reads = count("physical_reads") + count("call_start_reads");
                    if scheme == Some("path_oram_private_posmap_v1") {
                        assert!(reads <= count("max_load_ops"), "{label} {capacity}");
                        assert!(
                            count("physical_writes") <= count("max_commit_ops"),
                            "{label} {capacity}"
                        );
                    } else {
                        assert_eq!(reads, count("max_load_ops"), "{label} {capacity}");
                        assert_eq!(
                            count("physical_writes"),
                            count("max_commit_ops"),
                            "{label} {capacity}"
                        );
                    }
                }
                assert!(seen > 0, "{label} {capacity}");
                assert_eq!(oram.is_some(), witness > 0, "{label} {capacity}");
            }
        }
        for workload in first["workloads"].as_array().unwrap() {
            assert_eq!(workload["calls"], json!(4));
            for metric in ["bytes_moved", "physical_operations"] {
                assert_eq!(
                    workload["executed_per_call"][metric], workload["computed_per_call"][metric],
                    "{metric}"
                );
            }
        }
    }

    #[test]
    fn occupancy_levels_fill_in_order_and_merge_equal_counts() {
        assert_eq!(OccupancyLevel::TwoKeys.stored_keys(1), 1);
        assert_eq!(OccupancyLevel::TwoKeys.stored_keys(16384), 2);
        assert_eq!(OccupancyLevel::Percent(25).stored_keys(2), 1);
        assert_eq!(OccupancyLevel::Percent(90).stored_keys(16384), 14745);
        assert_eq!(OccupancyLevel::Percent(100).stored_keys(16384), 16384);

        let parameters = |limit: usize| SweepParameters {
            profile: SweepProfile::Quick,
            capacities: vec![4, 64],
            occupancy_percents: vec![25, 50, 90, 100],
            occupancy_capacity_limit: limit,
            read_percents: vec![0, 100],
            warmups: 0,
            trials: 1,
            workload_calls: 0,
            lean_capacities: Vec::new(),
        };
        // At capacity 4 the two keys are also half the map.
        assert_eq!(
            parameters(64).cells(4),
            vec![
                (1, vec!["25_percent".to_string()]),
                (2, vec!["2_keys".to_string(), "50_percent".to_string()]),
                (3, vec!["90_percent".to_string()]),
                (4, vec!["100_percent".to_string()]),
            ]
        );
        assert_eq!(
            parameters(64)
                .cells(64)
                .into_iter()
                .map(|(stored, _)| stored)
                .collect::<Vec<_>>(),
            vec![2, 16, 32, 57, 64]
        );
        // Past the limit a map holds its two keys only.
        assert_eq!(
            parameters(4).cells(64),
            vec![(2, vec!["2_keys".to_string()])]
        );
    }

    #[test]
    fn planned_calls_keep_a_map_between_empty_and_its_level() {
        let mut keys = SweepKeys::new(8);
        let apply = |keys: &mut SweepKeys, wanted: SweepOperation, level: usize| {
            let plan = plan_sweep_call(wanted, keys, level);
            match plan.effect {
                SweepEffect::Unchanged => {}
                SweepEffect::Insert(key, value) => keys.stored.push((key, value)),
                SweepEffect::Overwrite(index, value) => keys.stored[index].1 = value,
                SweepEffect::Delete(index) => {
                    keys.stored.swap_remove(index);
                }
            }
            plan.operation
        };
        // On an empty map a kind that needs a stored key reads an absent
        // one or inserts.
        assert_eq!(
            apply(&mut keys, SweepOperation::ReadHit, 2),
            SweepOperation::ReadMiss
        );
        assert_eq!(
            apply(&mut keys, SweepOperation::Delete, 2),
            SweepOperation::Insert
        );
        assert_eq!(
            apply(&mut keys, SweepOperation::Insert, 2),
            SweepOperation::Insert
        );
        // At its level an insert overwrites.
        assert_eq!(
            apply(&mut keys, SweepOperation::Insert, 2),
            SweepOperation::Overwrite
        );
        assert_eq!(keys.stored.len(), 2);
        // Rounds leave the map at its level, and every key and value is new.
        for _ in 0..5 {
            for wanted in SweepOperation::ROUND {
                assert_eq!(apply(&mut keys, wanted, 2), wanted);
                assert!((1..=2).contains(&keys.stored.len()));
            }
            assert_eq!(keys.stored.len(), 2);
        }
        let mut seen = std::collections::BTreeSet::new();
        let mut other = SweepKeys::new(8);
        for _ in 0..64 {
            assert!(seen.insert(other.fresh_key()));
            assert_ne!(other.fresh_value(), 0);
        }
        // Another capacity draws other keys.
        assert!(!seen.contains(&SweepKeys::new(16).fresh_key()));
    }

    #[test]
    fn a_workload_has_its_share_of_reads_and_every_kind_of_write() {
        let mut rng = SplitMix64(7);
        for (calls, read_percent, reads) in [(40, 25, 10), (40, 90, 36), (5, 50, 3), (5, 0, 0)] {
            let schedule = workload_schedule(calls, read_percent, &mut rng);
            assert_eq!(schedule.len(), calls);
            assert_eq!(schedule.iter().filter(|kind| kind.is_read()).count(), reads);
        }
        let writes = workload_schedule(5, 0, &mut rng);
        assert_eq!(writes, SweepOperation::WORKLOAD_WRITES.to_vec());
        // The same seed orders a workload the same way.
        assert_eq!(
            workload_schedule(40, 50, &mut SplitMix64(11)),
            workload_schedule(40, 50, &mut SplitMix64(11))
        );
        assert_ne!(
            workload_schedule(40, 50, &mut SplitMix64(11)),
            workload_schedule(40, 50, &mut SplitMix64(12))
        );
    }

    #[test]
    fn a_bootstrap_interval_brackets_its_statistic() {
        let samples: Vec<u128> = (1..=30).map(|value| value * 10).collect();
        let [low, high] = bootstrap_ci95(&samples, median_statistic);
        let median = median_statistic(&samples);
        assert!(low <= median && median <= high, "{low} {median} {high}");
        assert!(low > 10.0 && high < 300.0, "{low} {high}");
        let [low, high] = bootstrap_ci95(&samples, mean_statistic);
        assert!(low < 155.0 && 155.0 < high, "{low} {high}");
        // The interval is a function of the samples.
        assert_eq!(
            bootstrap_ci95(&samples, mean_statistic),
            bootstrap_ci95(&samples, mean_statistic)
        );
        // One sample has no spread, and equal samples none either.
        assert_eq!(bootstrap_ci95(&[7], median_statistic), [7.0, 7.0]);
        assert_eq!(bootstrap_ci95(&[7, 7, 7], mean_statistic), [7.0, 7.0]);
    }

    #[test]
    fn the_counts_digest_ignores_timing_and_provenance_and_nothing_else() {
        let report = |latency: u64, reads: u64, toolchain: &str| {
            json!({
                "schema": "uo-capacity-sweep-v4",
                "build_profile": "release",
                "rows": [{
                    "physical_reads": reads,
                    "timing": { "p50_latency_ns": latency },
                }],
                "latency_break_even": [{ "timing": { "call_latency_ns_from_capacity": latency } }],
                "provenance": { "toolchain_manifest_sha256": toolchain },
            })
        };
        let digest = counts_sha256(&report(1, 5, "a"));
        assert_eq!(digest.len(), 64);
        assert_eq!(digest, counts_sha256(&report(2, 5, "b")));
        assert_ne!(digest, counts_sha256(&report(1, 6, "a")));
        // The digest a report carries is not part of what it digests.
        let mut with_digest = report(1, 5, "a");
        with_digest["counts_sha256"] = json!(digest);
        assert_eq!(digest, counts_sha256(&with_digest));
    }
}
