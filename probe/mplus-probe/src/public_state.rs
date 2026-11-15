//! The public-state report (`--only public-state`): what the public-state
//! snapshot of a call costs, by the size of a public object the call does
//! not load.
//!
//! The contract is PublicLedger: a public array of `capacity` sealed slots,
//! which `record` writes, a public sealed cell, which `bump` adds to, and a
//! confidential cell, which `hide` adds to. A call takes the public-state
//! snapshot before it runs, at its commit and after. An object keeps the
//! digest of its public state, so a snapshot decodes from storage only the
//! public objects a call loaded. For each capacity the report deploys the
//! contract and, for each call in turn, runs warmup rounds of it and then
//! measured rounds, and reports for each call
//!
//! - the public objects its snapshots decoded, and in each round the bytes
//!   of their state, which do not depend on the capacity for a call that
//!   does not load the array; and
//! - its time, in `timing`: the median and the extremes over the rounds, and
//!   the medians of the parts of a call the runtime times.
//!
//! Everything outside `timing` is a function of the contract and the calls,
//! and `counts_sha256` is the digest of the report without `timing`.

use super::{env_usize, env_usize_list, percentile_sorted, PROBE_DEPLOY_SEED};
use anyhow::{bail, Context, Result};
use serde_json::{json, Value as JsonValue};
use sha2::{Digest, Sha256};
use std::fs;
use std::time::Instant;
use uo_core::{CompiledArtifact, ContractMetadata, ProgramMode, Value};
use uo_evm::ContractInstance;

pub(crate) const PUBLIC_STATE_SCHEMA: &str = "uo-public-state-v1";

/// The capacities of the public array.
const PUBLIC_STATE_CAPACITIES: [usize; 4] = [16, 256, 4096, 16384];
const PUBLIC_STATE_WARMUP_ROUNDS: usize = 2;
const PUBLIC_STATE_ROUNDS: usize = 9;

/// The calls of a round: (entrypoint, the object it loads).
const PUBLIC_STATE_CALLS: [(&str, &str); 3] = [
    ("bump(uint256)", "counter"),
    ("hide(uint256)", "secret"),
    ("record(uint256,uint256)", "history"),
];

fn public_ledger_source(capacity: usize) -> String {
    format!(
        r#"pragma solidity ^0.8.0;
contract PublicLedger {{
    uint256[{capacity}] private history;
    uint256 private counter;
    uint256 private secret;
    function bump(uint256 by) public {{
        counter = counter + by;
    }}
    function hide(uint256 by) public {{
        secret = secret + by;
    }}
    function record(uint256 index, uint256 value) public {{
        history[index] = value;
    }}
}}
"#
    )
}

fn public_ledger_metadata(capacity: usize) -> String {
    format!(
        r#"contract: PublicLedger
entrypoints:
  bump(uint256):
    confidential: false
    returns: forbidden
    status: public
  hide(uint256):
    secret_args: [by]
    confidential: true
    returns: forbidden
    status: public
  record(uint256,uint256):
    confidential: false
    returns: forbidden
    status: public
state:
  history:
    kind: array
    value: uint256
    capacity: {capacity}
    backend: full_scan
    confidential: false
  counter:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: false
  secret:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {{}}
"#
    )
}

/// PublicLedger with a public array of `capacity` slots. The source is
/// written to a private temp file, which the compiler reads and which is
/// removed before this returns.
fn public_ledger(capacity: usize) -> Result<CompiledArtifact> {
    let metadata: ContractMetadata = serde_yaml::from_str(&public_ledger_metadata(capacity))?;
    let dir = std::env::temp_dir().join(format!("uo-public-state-{}", std::process::id()));
    fs::create_dir_all(&dir)?;
    let path = dir.join(format!("PublicLedger{capacity}.sol"));
    fs::write(&path, public_ledger_source(capacity))?;
    let compiled = uo_solc::compile(
        path.to_str().context("temp path is not UTF-8")?,
        &metadata,
        ProgramMode::Uo,
    );
    let _ = fs::remove_file(&path);
    let _ = fs::remove_dir(&dir);
    compiled
}

/// One measured call: its time, and what the runtime's instrumentation
/// counted and timed of it, the public state its snapshots decoded among it.
struct PublicStateSample {
    latency_ns: u128,
    totals: uo_evm::InstrumentationTotals,
}

fn run_public_state_call(
    instance: &mut ContractInstance,
    entrypoint: &str,
    args: Vec<Value>,
) -> Result<PublicStateSample> {
    uo_evm::take_instrumentation_totals();
    let started = Instant::now();
    let result = instance.call(entrypoint, args)?;
    let latency_ns = started.elapsed().as_nanos();
    let totals = uo_evm::take_instrumentation_totals();
    if result.aborted {
        bail!("{entrypoint} aborted");
    }
    Ok(PublicStateSample { latency_ns, totals })
}

fn call_args(entrypoint: &str, round: usize) -> Vec<Value> {
    let round = round as u64;
    match entrypoint {
        "record(uint256,uint256)" => vec![Value::uint(round % 16), Value::uint(round + 1)],
        _ => vec![Value::uint(round + 1)],
    }
}

pub(crate) fn run_public_state() -> Result<JsonValue> {
    let capacities = env_usize_list("UO_PUBLIC_STATE_CAPACITIES", &PUBLIC_STATE_CAPACITIES);
    let warmup_rounds = env_usize("UO_PUBLIC_STATE_WARMUP_ROUNDS", PUBLIC_STATE_WARMUP_ROUNDS);
    let rounds = env_usize("UO_PUBLIC_STATE_ROUNDS", PUBLIC_STATE_ROUNDS).max(1);
    let mut rows = Vec::new();
    for &capacity in &capacities {
        if capacity < 16 {
            bail!("the public array needs at least 16 slots, not {capacity}");
        }
        let artifact = public_ledger(capacity)?;
        let mut instance = ContractInstance::deploy_with_seed(artifact, PROBE_DEPLOY_SEED)?;
        let mut samples: Vec<Vec<PublicStateSample>> =
            PUBLIC_STATE_CALLS.iter().map(|_| Vec::new()).collect();
        // The rounds of one call follow one another, so that no call is
        // timed on the memory another kind of call left behind.
        for (call, (entrypoint, _)) in PUBLIC_STATE_CALLS.iter().enumerate() {
            for round in 0..warmup_rounds + rounds {
                let sample =
                    run_public_state_call(&mut instance, entrypoint, call_args(entrypoint, round))?;
                if round >= warmup_rounds {
                    samples[call].push(sample);
                }
            }
        }
        for ((entrypoint, loads), samples) in PUBLIC_STATE_CALLS.iter().zip(samples) {
            let objects = samples[0].totals.public_state_objects_decoded;
            let same_every_round = samples
                .iter()
                .all(|sample| sample.totals.public_state_objects_decoded == objects);
            let bytes_by_round: Vec<u64> = samples
                .iter()
                .map(|sample| sample.totals.public_state_bytes_decoded)
                .collect();
            let median = |part: fn(&PublicStateSample) -> u128| {
                let mut values: Vec<u128> = samples.iter().map(part).collect();
                values.sort_unstable();
                percentile_sorted(&values, 0.5)
            };
            let mut latencies: Vec<u128> = samples.iter().map(|sample| sample.latency_ns).collect();
            latencies.sort_unstable();
            rows.push(json!({
                "capacity": capacity,
                "entrypoint": entrypoint,
                "loads": loads,
                "public_objects_decoded_per_call": objects,
                "public_state_bytes_decoded_by_round": bytes_by_round,
                "decoded_the_same_objects_every_round": same_every_round,
                "timing": {
                    "rounds": latencies.len(),
                    "median_ns": percentile_sorted(&latencies, 0.5),
                    "min_ns": latencies.first().copied().unwrap_or(0),
                    "max_ns": latencies.last().copied().unwrap_or(0),
                    "median_staging_ns": median(|sample| sample.totals.staging_ns),
                    "median_load_ns": median(|sample| sample.totals.load_ns),
                    "median_proof_objects_ns": median(|sample| sample.totals.proof_objects_ns),
                    "median_storage_commit_ns": median(|sample| sample.totals.storage_commit_ns),
                },
            }));
        }
    }
    let rows_of = |entrypoint: &str| -> Vec<&JsonValue> {
        rows.iter()
            .filter(|row| row["entrypoint"] == json!(entrypoint))
            .collect()
    };
    // A call that does not load the array decodes the same at every
    // capacity, and a confidential call decodes nothing.
    let same_at_every_capacity = |entrypoint: &str| {
        let rows = rows_of(entrypoint);
        rows.windows(2).all(|pair| {
            pair[0]["public_objects_decoded_per_call"] == pair[1]["public_objects_decoded_per_call"]
                && pair[0]["public_state_bytes_decoded_by_round"]
                    == pair[1]["public_state_bytes_decoded_by_round"]
        })
    };
    let hide_decodes_nothing = rows_of("hide(uint256)")
        .iter()
        .all(|row| row["public_objects_decoded_per_call"] == json!(0));
    let checks = json!({
        "decoded_the_same_objects_every_round": rows
            .iter()
            .all(|row| row["decoded_the_same_objects_every_round"] == json!(true)),
        "a_call_that_does_not_load_the_array_decodes_the_same_at_every_capacity":
            same_at_every_capacity("bump(uint256)") && same_at_every_capacity("hide(uint256)"),
        "a_confidential_call_decodes_no_public_object": hide_decodes_nothing,
    });
    let mut report = json!({
        "schema": PUBLIC_STATE_SCHEMA,
        "contract": "PublicLedger",
        "parameters": {
            "capacities": capacities,
            "warmup_rounds": warmup_rounds,
            "rounds": rounds,
            "deploy_seed": PROBE_DEPLOY_SEED,
        },
        "rows": rows,
        "checks": checks,
        "accepted": checks.as_object().map(|checks| checks.values().all(|check| check == &json!(true))),
    });
    let counts = without_timing(&report);
    report["counts_sha256"] = json!(hex::encode(Sha256::digest(serde_json::to_vec(&counts)?)));
    Ok(report)
}

/// The report without its `timing` objects: what repeats between runs.
fn without_timing(value: &JsonValue) -> JsonValue {
    match value {
        JsonValue::Object(fields) => JsonValue::Object(
            fields
                .iter()
                .filter(|(key, _)| key.as_str() != "timing")
                .map(|(key, value)| (key.clone(), without_timing(value)))
                .collect(),
        ),
        JsonValue::Array(items) => JsonValue::Array(items.iter().map(without_timing).collect()),
        other => other.clone(),
    }
}
