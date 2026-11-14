//! The tape-substitution report: runtime runs of one call on many tapes,
//! each checked against the substituted run.
//!
//! The Path ORAM theorems hold for a family of runs of a call, one for each
//! tape: the leaves of the keys present before the call, and the coins the
//! call draws. The family is built in Lean from one runtime run, by
//! substituting a tape's leaves into it (`substituteWitness` in
//! `UOToolchain/PathOramTapeWitness.lean`). That the runtime's own run on a
//! tape is that substituted run is not proved of the Rust runtime. It is
//! tested: a run of the same call on the same contents, deployed with
//! another seed, holds other leaves and draws other coins, and the Lean
//! checker `checkPathOramTapeSamples` compares it, whole, with the
//! representative run under its tape (`sampleCheck`).
//!
//! This report makes that comparison over many seeds. For maps of both Path
//! ORAM schemes at several capacities it draws workloads from a seed: a
//! setup of puts, deletes and writes behind a guard that fails, and then one
//! call of each kind (a read that hits, one that misses, an insert, an
//! overwrite, a delete, a delete of an absent key and a write that aborts).
//! Each workload runs once as the representative and then on every sample
//! seed. A sample that differs from the substituted run fails the report.

use crate::capacity_sweep::{sweep_map_artifact, WitnessAuditOff};
use crate::{ensure_lean_checker, lean_checker_counts, write_temp_json};
use anyhow::{anyhow, bail, Context, Result};
use serde::Serialize;
use serde_json::{json, Value as JsonValue};
use std::collections::BTreeMap;
use std::path::Path;
use std::process::Command;
use uo_core::manifest::{PATH_ORAM_PRIVATE_POSMAP_SCHEME, PATH_ORAM_SCHEME};
use uo_core::{CompiledArtifact, RuntimeRefinementWitness, Value};
use uo_evm::ContractInstance;

pub(crate) const TAPE_SUBSTITUTION_SCHEMA: &str = "uo-tape-substitution-v1";

/// The schema tag of the samples file, which the Lean checker requires.
const TAPE_SAMPLES_SCHEMA: &str = "uo-tape-substitution-samples-v1";

/// The seed of the workloads and of the deployments ("TAPESUB1").
const TAPE_SUBSTITUTION_SEED: u64 = 0x5441_5045_5355_4231;

/// How long a run is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum TapeProfile {
    /// What CI and the validation script run, from a debug build.
    Quick,
    /// What the validation script runs from a release build.
    Full,
}

struct TapeParameters {
    profile: TapeProfile,
    /// Capacities of the local scheme's maps and of the private scheme's.
    local_capacities: Vec<usize>,
    private_capacities: Vec<usize>,
    /// Workloads drawn for each map: each has its own setup and one target
    /// call of every kind.
    workloads: usize,
    /// Calls of a workload's setup.
    setup_calls: usize,
    /// Runs of each call on other deployment seeds.
    samples: usize,
}

impl TapeParameters {
    fn of(profile: TapeProfile) -> Self {
        match profile {
            TapeProfile::Quick => Self {
                profile,
                local_capacities: vec![8],
                private_capacities: vec![16],
                workloads: 1,
                setup_calls: 6,
                samples: 3,
            },
            TapeProfile::Full => Self {
                profile,
                local_capacities: vec![8, 32, 128],
                private_capacities: vec![16, 64, 256],
                workloads: 2,
                setup_calls: 12,
                samples: 16,
            },
        }
    }
}

/// The kinds of call a workload ends with.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum TargetKind {
    ReadHit,
    ReadMiss,
    Insert,
    Overwrite,
    Delete,
    DeleteAbsent,
    Abort,
}

impl TargetKind {
    const ALL: [Self; 7] = [
        Self::ReadHit,
        Self::ReadMiss,
        Self::Insert,
        Self::Overwrite,
        Self::Delete,
        Self::DeleteAbsent,
        Self::Abort,
    ];

    fn label(self) -> &'static str {
        match self {
            Self::ReadHit => "read_hit",
            Self::ReadMiss => "read_miss",
            Self::Insert => "insert",
            Self::Overwrite => "overwrite",
            Self::Delete => "delete",
            Self::DeleteAbsent => "delete_absent",
            Self::Abort => "abort",
        }
    }
}

struct SplitMix64(u64);

impl SplitMix64 {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e37_79b9_7f4a_7c15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        z ^ (z >> 31)
    }

    fn below(&mut self, bound: usize) -> usize {
        ((u128::from(self.next()) * bound.max(1) as u128) >> 64) as usize
    }
}

#[derive(Clone)]
struct Call {
    entrypoint: &'static str,
    args: Vec<Value>,
    aborts: bool,
}

fn key(index: usize) -> Value {
    let mut bytes = [0x5au8; 32];
    bytes[24..].copy_from_slice(&(index as u64 + 1).to_be_bytes());
    Value::Bytes32(bytes)
}

fn put(index: usize, value: u64) -> Call {
    Call {
        entrypoint: "put(bytes32,uint256)",
        args: vec![key(index), Value::uint(value)],
        aborts: false,
    }
}

fn clear(index: usize) -> Call {
    Call {
        entrypoint: "clear(bytes32)",
        args: vec![key(index)],
        aborts: false,
    }
}

/// A write behind a guard that fails: no value is below a limit of zero.
fn put_below_zero(index: usize, value: u64) -> Call {
    Call {
        entrypoint: "putBelow(bytes32,uint256,uint256)",
        args: vec![key(index), Value::uint(value), Value::uint(0)],
        aborts: true,
    }
}

fn read(index: usize) -> Call {
    Call {
        entrypoint: "read(bytes32)",
        args: vec![key(index)],
        aborts: false,
    }
}

/// A workload: its setup, what the setup leaves in the map, and its targets.
struct Workload {
    setup: Vec<Call>,
    setup_counts: BTreeMap<&'static str, usize>,
    targets: Vec<(TargetKind, Call)>,
}

/// Draw a workload for a map of `capacity` entries. The keys come from a
/// space half again as large as what the map may hold after the setup, so
/// that reads and deletes miss as well as hit.
fn draw_workload(capacity: usize, setup_calls: usize, rng: &mut SplitMix64) -> Workload {
    // The setup stores at most `stored_limit` keys, which leaves room for
    // the insert of a target.
    let stored_limit = (capacity / 2).max(1);
    let key_space = stored_limit + stored_limit / 2 + 2;
    let mut contents: BTreeMap<usize, u64> = BTreeMap::new();
    let mut setup = Vec::with_capacity(setup_calls + 1);
    let mut setup_counts: BTreeMap<&'static str, usize> = BTreeMap::new();
    let mut count = |kind: &'static str| *setup_counts.entry(kind).or_default() += 1;
    // The first call stores a key, so that the targets have one to hit.
    let first = rng.below(key_space);
    contents.insert(first, 1 + rng.next() % 1000);
    setup.push(put(first, contents[&first]));
    count("puts");
    for _ in 0..setup_calls {
        let index = rng.below(key_space);
        let value = 1 + rng.next() % 1000;
        match rng.below(10) {
            0..=5 => {
                if contents.contains_key(&index) || contents.len() < stored_limit {
                    contents.insert(index, value);
                    setup.push(put(index, value));
                    count("puts");
                } else {
                    setup.push(read(index));
                    count("reads");
                }
            }
            6 | 7 => {
                // A delete, of a stored key more often than not.
                let index = match contents.keys().nth(rng.below(contents.len().max(1))) {
                    Some(stored) if contents.len() > 1 && rng.below(4) != 0 => *stored,
                    _ => index,
                };
                if contents.len() > 1 || !contents.contains_key(&index) {
                    contents.remove(&index);
                    setup.push(clear(index));
                    count("deletes");
                } else {
                    setup.push(read(index));
                    count("reads");
                }
            }
            8 => {
                setup.push(put_below_zero(index, value));
                count("aborts");
            }
            _ => {
                setup.push(read(index));
                count("reads");
            }
        }
    }
    let stored: Vec<usize> = contents.keys().copied().collect();
    let hit = stored[rng.below(stored.len())];
    let absent = (0..key_space)
        .cycle()
        .skip(rng.below(key_space))
        .find(|index| !contents.contains_key(index))
        .unwrap_or(key_space);
    let value = 1001 + rng.next() % 1000;
    let targets = TargetKind::ALL
        .into_iter()
        .map(|kind| {
            let call = match kind {
                TargetKind::ReadHit => read(hit),
                TargetKind::ReadMiss => read(absent),
                TargetKind::Insert => put(absent, value),
                TargetKind::Overwrite => put(hit, value),
                TargetKind::Delete => clear(hit),
                TargetKind::DeleteAbsent => clear(absent),
                TargetKind::Abort => put_below_zero(hit, value),
            };
            (kind, call)
        })
        .collect();
    Workload {
        setup,
        setup_counts,
        targets,
    }
}

/// Deploy with `seed`, run the setup and the target, and return the
/// target's witness.
fn run_on_seed(
    artifact: &CompiledArtifact,
    setup: &[Call],
    target: &Call,
    seed: u64,
) -> Result<RuntimeRefinementWitness> {
    let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), seed)?;
    for call in setup {
        let result = instance.call(call.entrypoint, call.args.clone())?;
        if result.aborted != call.aborts {
            bail!("a setup call {} did not end as planned", call.entrypoint);
        }
    }
    let result = instance.call(target.entrypoint, target.args.clone())?;
    if result.aborted != target.aborts {
        bail!(
            "the target call {} did not end as planned",
            target.entrypoint
        );
    }
    Ok(result.trace.runtime_refinement_witness()?)
}

#[derive(Serialize)]
struct TapeSampleCase {
    name: String,
    representative: RuntimeRefinementWitness,
    samples: Vec<RuntimeRefinementWitness>,
}

#[derive(Serialize)]
struct TapeSampleCases {
    schema: &'static str,
    cases: Vec<TapeSampleCase>,
}

fn run_checker(checker: &Path, label: &str, cases: &impl Serialize) -> Result<(bool, String, u64)> {
    let (path, bytes) = write_temp_json(label, cases)?;
    let output = Command::new(checker).arg(&path).output()?;
    let _ = std::fs::remove_file(&path);
    let text = if output.status.success() {
        String::from_utf8_lossy(&output.stdout).trim().to_string()
    } else {
        String::from_utf8_lossy(&output.stderr).trim().to_string()
    };
    Ok((output.status.success(), text, bytes))
}

/// Copies of a set of cases that the checker must reject: a sample with one
/// bucket read moved, a sample that is a run of another call, and a sample
/// with its last read dropped.
fn tampered_cases(cases: &TapeSampleCases) -> Result<Vec<(&'static str, JsonValue)>> {
    let original = serde_json::to_value(cases)?;
    let mut tampers = Vec::new();

    let mut moved = original.clone();
    let read = moved["cases"][0]["samples"][0]["trace"]["physical_reads"]
        .as_array_mut()
        .and_then(|reads| {
            reads.iter_mut().find(|read| {
                read["location"]
                    .as_str()
                    .is_some_and(|location| location.contains("@bucket"))
            })
        })
        .ok_or_else(|| anyhow!("no bucket read to move in a sample"))?;
    let location = read["location"].as_str().unwrap_or_default().to_string();
    let (object, index) = location
        .rsplit_once("@bucket")
        .ok_or_else(|| anyhow!("no bucket index in {location}"))?;
    let index: usize = index.parse()?;
    read["location"] = json!(format!("{object}@bucket{}", index ^ 1));
    tampers.push(("moved_bucket_read", moved));

    let mut other_call = original.clone();
    let cases_len = original["cases"].as_array().map(Vec::len).unwrap_or(0);
    if cases_len < 2 {
        bail!("the tamper suite needs two cases");
    }
    // The second case's first sample, under the first case.
    let foreign = original["cases"][1]["samples"][0].clone();
    other_call["cases"][0]["samples"][0] = foreign;
    tampers.push(("sample_of_another_call", other_call));

    let mut dropped = original;
    let reads = dropped["cases"][0]["samples"][0]["trace"]["physical_reads"]
        .as_array_mut()
        .ok_or_else(|| anyhow!("a sample has no physical reads"))?;
    if reads.pop().is_none() {
        bail!("a sample has no physical read to drop");
    }
    tampers.push(("dropped_read", dropped));
    Ok(tampers)
}

struct MapOutcome {
    row: JsonValue,
    accepted: bool,
    runs: usize,
    other_tapes: usize,
    other_starts: usize,
    cases: usize,
    rejected_tampers: Vec<&'static str>,
}

/// Run the workloads of one map and check every sample. The checker runs
/// once for each call, on the call's representative run and its samples.
fn check_map(
    parameters: &TapeParameters,
    checker: &Path,
    scheme: &'static str,
    capacity: usize,
    with_tampers: bool,
) -> Result<MapOutcome> {
    let artifact = sweep_map_artifact(capacity, "oram", Some(scheme))?;
    let mut rng = SplitMix64(
        TAPE_SUBSTITUTION_SEED
            ^ (capacity as u64).rotate_left(32)
            ^ u64::from(scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME),
    );
    let label = format!("tape-substitution-{scheme}-{capacity}");
    let mut kinds: BTreeMap<&'static str, usize> = BTreeMap::new();
    let mut setup_counts: BTreeMap<&'static str, usize> = BTreeMap::new();
    // What the probe ran, and what the checker says it checked.
    let (mut cases, mut sample_runs, mut bytes) = (0usize, 0usize, 0u64);
    let mut checked: BTreeMap<String, usize> = BTreeMap::new();
    let mut rejections: Vec<String> = Vec::new();
    // The first two calls of the map, for the tamper suite.
    let mut tamper_cases: Vec<TapeSampleCase> = Vec::new();
    for workload_index in 0..parameters.workloads {
        let workload = draw_workload(capacity, parameters.setup_calls, &mut rng);
        for (kind, count) in &workload.setup_counts {
            *setup_counts.entry(kind).or_default() += count;
        }
        for (kind, target) in &workload.targets {
            let name = format!(
                "{scheme}/{capacity}/workload{workload_index}/{}",
                kind.label()
            );
            let representative = run_on_seed(&artifact, &workload.setup, target, rng.next())
                .with_context(|| format!("representative run of {name}"))?;
            let samples = (0..parameters.samples)
                .map(|_| run_on_seed(&artifact, &workload.setup, target, rng.next()))
                .collect::<Result<Vec<_>>>()
                .with_context(|| format!("sample runs of {name}"))?;
            cases += 1;
            sample_runs += samples.len();
            *kinds.entry(kind.label()).or_default() += samples.len();
            let mut case = TapeSampleCases {
                schema: TAPE_SAMPLES_SCHEMA,
                cases: vec![TapeSampleCase {
                    name: name.clone(),
                    representative,
                    samples,
                }],
            };
            let (accepted, text, case_bytes) = run_checker(checker, &label, &case)?;
            bytes += case_bytes;
            if accepted {
                for (count, value) in lean_checker_counts(&text) {
                    *checked.entry(count).or_default() += value;
                }
            } else {
                rejections.push(format!("{name}: {text}"));
            }
            if with_tampers && tamper_cases.len() < 2 {
                tamper_cases.append(&mut case.cases);
            }
        }
    }
    // The tamper suite needs samples the checker accepts. Where it rejects
    // one, the suite does not run, and the report says so twice: the map's
    // samples are not all substituted runs, and no tamper was rejected.
    let mut rejected_tampers = Vec::new();
    if with_tampers && rejections.is_empty() {
        let tamper_cases = TapeSampleCases {
            schema: TAPE_SAMPLES_SCHEMA,
            cases: tamper_cases,
        };
        for (name, tampered) in tampered_cases(&tamper_cases)? {
            let (tamper_accepted, _, _) =
                run_checker(checker, &format!("{label}-{name}"), &tampered)?;
            if tamper_accepted {
                bail!("the Lean tape-sample checker accepted samples with {name}");
            }
            rejected_tampers.push(name);
        }
    }
    let count = |name: &str| checked.get(name).copied().unwrap_or(0);
    let accepted = rejections.is_empty() && count("runs") == sample_runs && count("cases") == cases;
    Ok(MapOutcome {
        row: json!({
            "scheme": scheme,
            "capacity": capacity,
            "workloads": parameters.workloads,
            "setup_calls": setup_counts,
            "calls": cases,
            "sample_runs": sample_runs,
            "sample_runs_by_kind": kinds,
            "runs_the_checker_compared": count("runs"),
            "runs_on_another_tape": count("other_tapes"),
            "runs_with_other_leaves_before_the_call": count("other_starts"),
            "samples_json_bytes": bytes,
            "rejections": rejections,
            "every_run_is_the_substituted_run": accepted,
        }),
        accepted,
        runs: count("runs"),
        other_tapes: count("other_tapes"),
        other_starts: count("other_starts"),
        cases,
        rejected_tampers,
    })
}

pub(crate) fn run_tape_substitution(profile: TapeProfile) -> Result<JsonValue> {
    let parameters = TapeParameters::of(profile);
    let checker = ensure_lean_checker("checkPathOramTapeSamples", "tape samples")?;
    // The checker compares whole witnesses, so the calls record theirs; the
    // audit of the kept witness is another matter and is off.
    let _audit_off = WitnessAuditOff::new();
    let maps: Vec<(&'static str, usize)> = parameters
        .local_capacities
        .iter()
        .map(|capacity| (PATH_ORAM_SCHEME, *capacity))
        .chain(
            parameters
                .private_capacities
                .iter()
                .map(|capacity| (PATH_ORAM_PRIVATE_POSMAP_SCHEME, *capacity)),
        )
        .collect();
    let mut rows = Vec::new();
    let mut accepted = true;
    let (mut cases, mut runs, mut other_tapes, mut other_starts) = (0usize, 0usize, 0usize, 0usize);
    let mut rejected_tampers: Vec<&'static str> = Vec::new();
    for (index, (scheme, capacity)) in maps.iter().enumerate() {
        // The tamper suite runs on the first map of each scheme.
        let with_tampers = index == 0 || maps.get(index - 1).map(|map| map.0) != Some(*scheme);
        let outcome = check_map(&parameters, &checker, scheme, *capacity, with_tampers)
            .with_context(|| format!("tape substitution on {scheme} at capacity {capacity}"))?;
        accepted &= outcome.accepted;
        cases += outcome.cases;
        runs += outcome.runs;
        other_tapes += outcome.other_tapes;
        other_starts += outcome.other_starts;
        for name in outcome.rejected_tampers {
            if !rejected_tampers.contains(&name) {
                rejected_tampers.push(name);
            }
        }
        rows.push(outcome.row);
    }
    let checks = json!({
        "every_sample_run_is_its_representative_run_under_its_own_tape": accepted,
        "every_sample_ran": runs == cases * parameters.samples && runs > 0,
        "samples_ran_on_other_tapes": other_tapes > 0,
        "tampered_samples_are_rejected": rejected_tampers.len() == 3,
    });
    let accepted = checks
        .as_object()
        .is_some_and(|checks| checks.values().all(|check| check == &json!(true)));
    Ok(json!({
        "schema": TAPE_SUBSTITUTION_SCHEMA,
        "profile": match parameters.profile {
            TapeProfile::Quick => "quick",
            TapeProfile::Full => "full",
        },
        "contract": "SweepMap",
        "checker": "proof/lean/.lake/build/bin/checkPathOramTapeSamples",
        "lean_check": "sampleCheck in proof/lean/UOToolchain/PathOramTapeWitness.lean",
        "what_is_tested": "a runtime run of a call on another deployment seed, which holds other leaves and draws other coins, equals the representative run of the call with that run's own tape substituted",
        "parameters": {
            "local_scheme_capacities": parameters.local_capacities,
            "private_scheme_capacities": parameters.private_capacities,
            "workloads_per_map": parameters.workloads,
            "setup_calls_per_workload": parameters.setup_calls + 1,
            "target_kinds": TargetKind::ALL.iter().map(|kind| kind.label()).collect::<Vec<_>>(),
            "sample_seeds_per_call": parameters.samples,
            "seed": format!("{TAPE_SUBSTITUTION_SEED:#018x}"),
        },
        "totals": {
            "maps": rows.len(),
            "calls": cases,
            "sample_runs": runs,
            "tapes_tested": runs,
            "runs_on_another_tape": other_tapes,
            "runs_with_other_leaves_before_the_call": other_starts,
        },
        "maps": rows,
        "rejected_tampers": rejected_tampers,
        "evidence_classification": "empirically tested",
        "rust_semantic_refinement_claimed": false,
        "checks": checks,
        "accepted": accepted,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_workload_has_a_target_of_every_kind_that_ends_as_planned() {
        let mut rng = SplitMix64(7);
        for capacity in [1usize, 2, 8, 64] {
            let workload = draw_workload(capacity, 12, &mut rng);
            assert_eq!(workload.targets.len(), TargetKind::ALL.len());
            assert_eq!(workload.setup.len(), 13);
            let total: usize = workload.setup_counts.values().sum();
            assert_eq!(total, 13);
            // Replay the setup on a model of the map.
            let mut contents: BTreeMap<Vec<u8>, u64> = BTreeMap::new();
            let name = |value: &Value| serde_json::to_vec(value).unwrap();
            for call in &workload.setup {
                match call.entrypoint {
                    "put(bytes32,uint256)" => {
                        let Value::Uint(_) = &call.args[1] else {
                            panic!("a put's value is a uint")
                        };
                        contents.insert(name(&call.args[0]), 1);
                    }
                    "clear(bytes32)" => {
                        contents.remove(&name(&call.args[0]));
                    }
                    _ => {}
                }
            }
            assert!(!contents.is_empty());
            assert!(contents.len() <= (capacity / 2).max(1));
            for (kind, call) in &workload.targets {
                let stored = contents.contains_key(&name(&call.args[0]));
                let hits = matches!(
                    kind,
                    TargetKind::ReadHit
                        | TargetKind::Overwrite
                        | TargetKind::Delete
                        | TargetKind::Abort
                );
                assert_eq!(stored, hits, "{} at capacity {capacity}", kind.label());
                assert_eq!(call.aborts, *kind == TargetKind::Abort);
            }
        }
    }

    /// A checker that rejects a call's samples makes the map's row, and so
    /// the report, not accepted; the probe does not stop at it.
    #[cfg(unix)]
    #[test]
    fn a_rejected_sample_is_reported_and_not_accepted() {
        use std::os::unix::fs::PermissionsExt;
        let dir = std::env::temp_dir().join(format!(
            "uo-tape-substitution-rejecting-checker-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let checker = dir.join("checker.sh");
        std::fs::write(
            &checker,
            "#!/bin/sh\necho 'a runtime run is not the representative run' >&2\nexit 1\n",
        )
        .unwrap();
        std::fs::set_permissions(&checker, std::fs::Permissions::from_mode(0o755)).unwrap();
        let parameters = TapeParameters {
            profile: TapeProfile::Quick,
            local_capacities: vec![8],
            private_capacities: vec![],
            workloads: 1,
            setup_calls: 1,
            samples: 1,
        };
        let _audit_off = WitnessAuditOff::new();
        let outcome = check_map(&parameters, &checker, PATH_ORAM_SCHEME, 8, true).unwrap();
        let _ = std::fs::remove_dir_all(&dir);
        assert!(!outcome.accepted);
        assert_eq!(outcome.cases, TargetKind::ALL.len());
        assert_eq!(outcome.runs, 0);
        assert!(outcome.rejected_tampers.is_empty());
        assert_eq!(
            outcome.row["every_run_is_the_substituted_run"],
            json!(false)
        );
        let rejections = outcome.row["rejections"].as_array().unwrap();
        assert_eq!(rejections.len(), TargetKind::ALL.len());
        assert!(rejections[0]
            .as_str()
            .unwrap()
            .contains("is not the representative run"));
    }

    #[test]
    fn checker_counts_are_read_from_its_line() {
        let counts = lean_checker_counts("cases=14 runs=42 other_tapes=40 other_starts=37");
        assert_eq!(counts["cases"], 14);
        assert_eq!(counts["runs"], 42);
        assert_eq!(counts["other_tapes"], 40);
        assert_eq!(counts["other_starts"], 37);
    }
}
