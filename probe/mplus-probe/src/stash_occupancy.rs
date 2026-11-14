//! The stash-occupancy report: how full the private scheme's stash gets, and
//! what an overflow does.
//!
//! The private scheme keeps a map as an AVL tree in one Path ORAM tree. An
//! operation holds the nodes it reads until it ends and then returns them to
//! the stash (deferred write-back), so the stash is sized for the Path ORAM
//! cap and the `3h + 1` nodes a put may return. The stash theorem is stated
//! for one access at a time; that its tail carries over to such operations is
//! assumed. This report measures it. A simulation runs the runtime's own tree
//! operations, with their eviction and compaction, over buckets in memory,
//! without the cryptography, and counts the stash after every node access.
//! The report compares what it counted with what the assumption predicts: a
//! stash of more than `3h + 1 + R` blocks with probability at most
//! `14 * 0.6002^R` per access.
//!
//! The report also forces an overflow, on the runtime itself, to show what
//! one does: the call that overflows the stash fails, nothing of it is
//! committed, and every key stored before still reads back.

use crate::capacity_sweep::{sweep_map_artifact, WitnessAuditOff};
use crate::PROBE_DEPLOY_SEED;
use anyhow::{anyhow, bail, Context, Result};
use rayon::prelude::*;
use serde_json::{json, Value as JsonValue};
use uo_core::manifest::{
    path_oram_tree_get_accesses, path_oram_tree_put_accesses, path_oram_tree_stash_bound,
    PATH_ORAM_PRIVATE_POSMAP_SCHEME, PATH_ORAM_STASH_BOUND_LIMIT,
};
use uo_core::Value;
use uo_evm::{
    simulate_stash_occupancy, ContractInstance, PathOramFreshCoinPlan, StashOccupancyRun,
    StashWorkload,
};

pub(crate) const STASH_OCCUPANCY_SCHEMA: &str = "uo-stash-occupancy-v1";

/// The seed of the simulation's keys and coins ("STASH_O1").
const STASH_OCCUPANCY_SEED: u64 = 0x5354_4153_485f_4f31;

/// The node accesses the full profile makes in all: the issue asks for at
/// least this many.
const FULL_PROFILE_NODE_ACCESSES: u64 = 10_000_000;

/// The constants of the stash theorem at 5 blocks per bucket: the stash
/// holds more than `R` blocks after an access with probability at most
/// `STASH_TAIL_FACTOR * STASH_TAIL_BASE^R`.
const STASH_TAIL_FACTOR: f64 = 14.0;
const STASH_TAIL_BASE: f64 = 0.6002;

/// How long a run is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum StashProfile {
    /// What the validation script runs, from a release build: a few seconds.
    Quick,
    /// What `scripts/run_stash_occupancy_full.sh` runs: at least
    /// `FULL_PROFILE_NODE_ACCESSES` node accesses.
    Full,
}

struct StashParameters {
    profile: StashProfile,
    capacities: Vec<usize>,
    node_accesses_per_cell: u64,
}

impl StashParameters {
    fn for_profile(profile: StashProfile) -> Result<Self> {
        let (capacities, node_accesses_per_cell) = match profile {
            StashProfile::Quick => (vec![256], 10_000),
            StashProfile::Full => (vec![256, 1024, 4096, 16384], 900_000),
        };
        let capacities = match std::env::var("UO_STASH_CAPACITIES") {
            Ok(list) => list
                .split(',')
                .map(|capacity| {
                    capacity
                        .trim()
                        .parse::<usize>()
                        .with_context(|| format!("UO_STASH_CAPACITIES entry {capacity:?}"))
                })
                .collect::<Result<Vec<_>>>()?,
            Err(_) => capacities,
        };
        let node_accesses_per_cell = match std::env::var("UO_STASH_NODE_ACCESSES") {
            Ok(accesses) => accesses
                .trim()
                .parse::<u64>()
                .context("UO_STASH_NODE_ACCESSES")?,
            Err(_) => node_accesses_per_cell,
        };
        if capacities.is_empty() || node_accesses_per_cell == 0 {
            bail!("the stash simulation needs a capacity and a number of node accesses");
        }
        Ok(Self {
            profile,
            capacities,
            node_accesses_per_cell,
        })
    }

    fn profile_label(&self) -> &'static str {
        match self.profile {
            StashProfile::Quick => "quick",
            StashProfile::Full => "full",
        }
    }
}

/// The samples of a histogram above `threshold`.
fn samples_above(histogram: &[u64], threshold: usize) -> u64 {
    histogram.iter().skip(threshold + 1).sum()
}

fn largest(histogram: &[u64]) -> usize {
    histogram.len().saturating_sub(1)
}

/// The samples the assumption allows above `allowance + excess` blocks, of
/// `samples` in all: `samples * 14 * 0.6002^excess`.
fn predicted_samples_above(samples: u64, excess: usize) -> f64 {
    samples as f64 * STASH_TAIL_FACTOR * STASH_TAIL_BASE.powi(excess as i32)
}

/// Whether the counted stash is one the assumption predicts. With
/// `allowance` the nodes an operation may return, the assumption bounds the
/// accesses that leave more than `allowance + R` blocks by
/// `14 * 0.6002^R` of them, for every `R`. A count above that bound, or any
/// sample where the bound is below one sample, is an occupancy the
/// assumption does not predict.
fn within_predicted_tail(histogram: &[u64], allowance: usize) -> bool {
    let samples: u64 = histogram.iter().sum();
    (0..histogram.len().saturating_sub(allowance)).all(|excess| {
        let observed = samples_above(histogram, allowance + excess);
        let predicted = predicted_samples_above(samples, excess);
        observed == 0 || (predicted >= 1.0 && observed as f64 <= predicted)
    })
}

/// The tail of a histogram at a few thresholds above `allowance`, beside
/// what the assumption allows.
fn tail_rows(histogram: &[u64], allowance: usize) -> Vec<JsonValue> {
    let samples: u64 = histogram.iter().sum();
    [0usize, 4, 8, 12, 16, 24, 32, 48, 64]
        .into_iter()
        .map(|excess| {
            json!({
                "more_than_blocks": allowance + excess,
                "samples": samples_above(histogram, allowance + excess),
                "predicted_at_most": predicted_samples_above(samples, excess),
            })
        })
        .collect()
}

fn mean(histogram: &[u64]) -> f64 {
    let samples: u64 = histogram.iter().sum();
    if samples == 0 {
        return 0.0;
    }
    histogram
        .iter()
        .enumerate()
        .map(|(occupancy, count)| occupancy as f64 * *count as f64)
        .sum::<f64>()
        / samples as f64
}

/// The smallest occupancy that at least `fraction` of the samples do not
/// exceed.
fn quantile(histogram: &[u64], fraction: f64) -> usize {
    let samples: u64 = histogram.iter().sum();
    let wanted = (samples as f64 * fraction).ceil() as u64;
    let mut seen = 0u64;
    for (occupancy, count) in histogram.iter().enumerate() {
        seen += count;
        if seen >= wanted {
            return occupancy;
        }
    }
    largest(histogram)
}

fn series(histogram: &[u64], allowance: usize) -> JsonValue {
    json!({
        "samples": histogram.iter().sum::<u64>(),
        "largest": largest(histogram),
        "mean": mean(histogram),
        "p50": quantile(histogram, 0.5),
        "p99": quantile(histogram, 0.99),
        "p999": quantile(histogram, 0.999),
        "tail": tail_rows(histogram, allowance),
        "histogram": histogram,
    })
}

fn cell_row(run: &StashOccupancyRun) -> JsonValue {
    let allowance = run.nodes_an_operation_returns;
    let largest_stash = largest(&run.within_operation).max(largest(&run.after_operation));
    // Every counted stash, within an operation and after one.
    let mut all = vec![0u64; run.within_operation.len().max(run.after_operation.len())];
    for histogram in [&run.within_operation, &run.after_operation] {
        for (slot, count) in all.iter_mut().zip(histogram.iter()) {
            *slot += count;
        }
    }
    json!({
        "capacity": run.capacity,
        "workload": run.workload,
        "seed": run.seed,
        "avl_height": run.avl_height,
        "nodes_an_operation_returns": allowance,
        "stash_bound": run.stash_bound,
        "operations": run.operations,
        "node_accesses": run.node_accesses,
        "stored_keys_at_end": run.stored_keys,
        "overflowed": run.overflowed,
        "largest_stash": largest_stash,
        "stash_bound_headroom": run.stash_bound.saturating_sub(largest_stash),
        "largest_stash_within_the_bound": largest_stash <= run.stash_bound,
        "occupancy_within_predicted_tail": within_predicted_tail(&all, allowance),
        // The stash while an operation holds the nodes it read.
        "within_operation": series(&run.within_operation, allowance),
        // The stash once an operation has returned them.
        "after_operation": series(&run.after_operation, allowance),
    })
}

/// A key of the sweep contract's map.
fn sweep_key(index: u64) -> Value {
    let mut bytes = [0u8; 32];
    bytes[24..].copy_from_slice(&index.to_be_bytes());
    Value::Bytes32(bytes)
}

/// Force a stash overflow on the runtime and report what it does. A
/// private-scheme map of 256 entries has a stash of 186 blocks, which honest
/// coins overflow with the probability the stash theorem bounds. Here every
/// node access of every put draws the same leaf, so each node a put reads is
/// sent to one path of 45 blocks, and the stash takes the rest until it is
/// full. The put that overflows it must fail with an error. The call is then
/// dropped: the committed ciphertext is what it was, every key stored before
/// reads back with honest coins, and the key of the dropped call is absent.
/// Returns the report and the digest of the toolchain that compiled the
/// contract.
fn forced_overflow() -> Result<(JsonValue, Option<String>)> {
    let capacity = 256usize;
    let artifact = sweep_map_artifact(capacity, "oram", Some(PATH_ORAM_PRIVATE_POSMAP_SCHEME))?;
    let toolchain = artifact
        .admitted_package
        .as_ref()
        .map(|package| package.toolchain_manifest_sha256.clone());
    let records = artifact
        .contract
        .state
        .first()
        .map(|object| object.id)
        .ok_or_else(|| anyhow!("SweepMap has no state object"))?;
    let stash_bound = path_oram_tree_stash_bound(capacity);
    // A put call makes a presence get and the put.
    let coins_per_put =
        path_oram_tree_get_accesses(capacity) + path_oram_tree_put_accesses(capacity);
    let value_of = |index: u64| Value::uint(1000 + index);

    // The calls are not measured; the audit of the kept witness would
    // decode the whole store around each of them.
    let _audit_off = WitnessAuditOff::new();
    let mut instance = ContractInstance::deploy_with_seed(artifact, PROBE_DEPLOY_SEED)?;
    let mut stored = Vec::new();
    let mut dropped = None;
    for index in 1..=capacity as u64 {
        let mut one_leaf = PathOramFreshCoinPlan::new();
        one_leaf.insert_object_coins(records, vec![0usize; coins_per_put].into_boxed_slice())?;
        let before = instance.ciphertext_store_digest()?;
        match instance.call_with_path_oram_fresh_coins(
            "put(bytes32,uint256)",
            vec![sweep_key(index), value_of(index)],
            one_leaf,
        ) {
            Ok(result) => {
                if result.aborted {
                    bail!("put {index} of the forced overflow aborted");
                }
                stored.push(index);
            }
            Err(error) => {
                dropped = Some((index, error.to_string(), before));
                break;
            }
        }
    }
    let Some((dropped_index, error, before)) = dropped else {
        return Ok((
            json!({
                "capacity": capacity,
                "stash_bound": stash_bound,
                "puts_before_the_overflow": stored.len(),
                "call_failed_with_stash_overflow": false,
                "accepted": false,
            }),
            toolchain,
        ));
    };
    let call_failed_with_stash_overflow = error.contains(&format!(
        "a Path ORAM stash overflowed its bound of {stash_bound} blocks"
    ));
    let committed_ciphertext_unchanged = instance.ciphertext_store_digest()? == before;
    let mut keys_read_back = 0usize;
    for index in &stored {
        let read = instance.call("read(bytes32)", vec![sweep_key(*index)])?;
        keys_read_back += usize::from(read.return_value == Some(value_of(*index)));
    }
    let dropped_key_absent = instance
        .call("read(bytes32)", vec![sweep_key(dropped_index)])?
        .return_value
        == Some(Value::uint(0));
    // The reads drew honest leaves for the nodes they read, so the map takes
    // writes again.
    let map_takes_a_write_again = instance
        .call("put(bytes32,uint256)", vec![sweep_key(1), Value::uint(7)])
        .map(|result| !result.aborted)
        .unwrap_or(false)
        && instance
            .call("read(bytes32)", vec![sweep_key(1)])?
            .return_value
            == Some(Value::uint(7));
    let every_stored_key_reads_back = keys_read_back == stored.len();
    let report = json!({
        "contract": "SweepMap",
        "scheme": PATH_ORAM_PRIVATE_POSMAP_SCHEME,
        "capacity": capacity,
        "stash_bound": stash_bound,
        "coins": "every node access of every put draws leaf 0",
        "node_accesses_per_put": coins_per_put,
        "puts_before_the_overflow": stored.len(),
        "overflow_error": error,
        "call_failed_with_stash_overflow": call_failed_with_stash_overflow,
        "committed_ciphertext_unchanged": committed_ciphertext_unchanged,
        "stored_keys_read_back": keys_read_back,
        "every_stored_key_reads_back": every_stored_key_reads_back,
        "dropped_key_absent": dropped_key_absent,
        "map_takes_a_write_again": map_takes_a_write_again,
        "accepted": call_failed_with_stash_overflow
            && committed_ciphertext_unchanged
            && every_stored_key_reads_back
            && dropped_key_absent
            && stored.len() > stash_bound,
    });
    Ok((report, toolchain))
}

pub(crate) fn run_stash_occupancy(profile: StashProfile) -> Result<JsonValue> {
    let parameters = StashParameters::for_profile(profile)?;
    let cells: Vec<(usize, StashWorkload, u64)> = parameters
        .capacities
        .iter()
        .flat_map(|capacity| {
            StashWorkload::ALL
                .into_iter()
                .enumerate()
                .map(move |(index, workload)| {
                    (
                        *capacity,
                        workload,
                        STASH_OCCUPANCY_SEED ^ ((*capacity as u64) << 8) ^ index as u64,
                    )
                })
        })
        .collect();
    let runs = cells
        .par_iter()
        .map(|(capacity, workload, seed)| {
            simulate_stash_occupancy(
                *capacity,
                *workload,
                parameters.node_accesses_per_cell,
                *seed,
            )
            .with_context(|| format!("stash simulation at {capacity} ({})", workload.label()))
        })
        .collect::<Result<Vec<_>>>()?;
    let rows: Vec<JsonValue> = runs.iter().map(cell_row).collect();
    let total_node_accesses: u64 = runs.iter().map(|run| run.node_accesses).sum();
    let no_run_overflowed = runs.iter().all(|run| !run.overflowed);
    let flag = |name: &str| rows.iter().all(|row| row[name] == json!(true));
    let every_largest_stash_within_the_bound = flag("largest_stash_within_the_bound");
    let every_occupancy_within_predicted_tail = flag("occupancy_within_predicted_tail");
    let node_accesses_meet_the_profile = match profile {
        StashProfile::Quick => true,
        StashProfile::Full => total_node_accesses >= FULL_PROFILE_NODE_ACCESSES,
    };
    let (forced_overflow, toolchain_manifest_sha256) =
        forced_overflow().context("forced stash overflow")?;
    let overflow_loses_nothing = forced_overflow["accepted"] == json!(true);
    Ok(json!({
        "schema": STASH_OCCUPANCY_SCHEMA,
        "profile": parameters.profile_label(),
        "scheme": PATH_ORAM_PRIVATE_POSMAP_SCHEME,
        "parameters": {
            "capacities": parameters.capacities,
            "workloads": StashWorkload::ALL.map(StashWorkload::label),
            "node_accesses_per_cell": parameters.node_accesses_per_cell,
            "seed": format!("{STASH_OCCUPANCY_SEED:#x}"),
            "blocks_per_bucket": 5,
        },
        "stash_cap": PATH_ORAM_STASH_BOUND_LIMIT,
        "assumed_tail": {
            "statement": "after a node access the stash holds more than 3h + 1 + R blocks with probability at most 14 * 0.6002^R, where 3h + 1 are the nodes an operation may return to it",
            "factor": STASH_TAIL_FACTOR,
            "base": STASH_TAIL_BASE,
        },
        "total_node_accesses": total_node_accesses,
        "largest_stash": rows
            .iter()
            .filter_map(|row| row["largest_stash"].as_u64())
            .max(),
        "smallest_stash_bound_headroom": rows
            .iter()
            .filter_map(|row| row["stash_bound_headroom"].as_u64())
            .min(),
        "checks": {
            "no_run_overflowed": no_run_overflowed,
            "every_largest_stash_within_the_bound": every_largest_stash_within_the_bound,
            "every_occupancy_within_predicted_tail": every_occupancy_within_predicted_tail,
            "node_accesses_meet_the_profile": node_accesses_meet_the_profile,
            "overflow_loses_nothing": overflow_loses_nothing,
        },
        "accepted": no_run_overflowed
            && every_largest_stash_within_the_bound
            && every_occupancy_within_predicted_tail
            && node_accesses_meet_the_profile
            && overflow_loses_nothing,
        "cells": rows,
        "forced_overflow": forced_overflow,
        // The build that ran the simulation and the forced overflow.
        "provenance": {
            "toolchain_manifest_sha256": toolchain_manifest_sha256,
        },
    }))
}

#[cfg(test)]
mod tests {
    use super::{largest, predicted_samples_above, quantile, samples_above, within_predicted_tail};

    /// The tail check accepts a stash the assumption predicts and rejects
    /// one it does not: a count above `samples * 14 * 0.6002^R`, or a single
    /// sample where that bound is below one.
    #[test]
    fn tail_check_rejects_an_occupancy_the_assumption_does_not_predict() {
        // A million samples at or below the allowance of 34 nodes.
        let mut histogram = vec![0u64; 100];
        histogram[3] = 900_000;
        histogram[34] = 100_000;
        assert!(within_predicted_tail(&histogram, 34));
        assert_eq!(largest(&histogram), 99);
        assert_eq!(samples_above(&histogram, 3), 100_000);
        assert_eq!(quantile(&histogram, 0.5), 3);
        assert_eq!(quantile(&histogram, 0.999), 34);

        // Ten blocks above the allowance, the assumption allows
        // 10^6 * 14 * 0.6002^10, about 85,000 samples.
        let allowed = predicted_samples_above(1_000_000, 10);
        assert!((84_000.0..86_000.0).contains(&allowed), "{allowed}");
        let mut within = histogram.clone();
        within[34] -= 80_000;
        within[45] = 80_000;
        assert!(within_predicted_tail(&within, 34));
        let mut above = histogram.clone();
        above[34] -= 90_000;
        above[45] = 90_000;
        assert!(!within_predicted_tail(&above, 34));

        // Thirty-five blocks above it, the bound is below one sample in a
        // million: one sample there is not predicted.
        assert!(predicted_samples_above(1_000_000, 35) < 1.0);
        let mut far = histogram.clone();
        far[34] -= 1;
        far[34 + 36] = 1;
        assert!(!within_predicted_tail(&far, 34));
        // With an allowance that covers it, it is.
        assert!(within_predicted_tail(&far, 70));
    }
}
