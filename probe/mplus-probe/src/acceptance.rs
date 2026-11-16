//! Fail-closed proof-grade acceptance aggregation (Issues 02/03).
//!
//! Reads every generated `results/*.json` report, walks all boolean-`false`
//! leaves, assigns each leaf exactly one class, and emits an aggregate
//! `results/acceptance.json` carrying a final top-level `accepted` bit.
//!
//! The aggregate is fail-closed: any `unclassified` false path or any
//! `required_failure` drives `accepted: false`. Expected tamper rejections and
//! computational-ORAM differences count as success only via explicit
//! classification metadata, never by default.
//!
//! Each report's entry lists its false paths under their class
//! (`false_paths_by_class`), so that a reader of `acceptance.json`, and
//! `scripts/rebuild_review_validation_false_paths.sh`, which lists the false
//! leaves of the gated reports, take every class from these rules and from no
//! other.

use anyhow::{anyhow, Result};
use serde_json::{json, Value as JsonValue};
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

pub const ACCEPTANCE_SCHEMA: &str = "uo.acceptance.v1";

pub const CLASS_REQUIRED_FAILURE: &str = "required_failure";
pub const CLASS_EXPECTED_NEGATIVE: &str = "expected_negative";
pub const CLASS_EXPECTED_COMPUTATIONAL_DIFFERENCE: &str = "expected_computational_difference";
pub const CLASS_ADVISORY_NONCLAIM: &str = "advisory_nonclaim";
pub const CLASS_DEPRECATED_REPORT: &str = "deprecated_report";
pub const CLASS_UNCLASSIFIED: &str = "unclassified";

const ALL_CLASSES: &[&str] = &[
    CLASS_REQUIRED_FAILURE,
    CLASS_EXPECTED_NEGATIVE,
    CLASS_EXPECTED_COMPUTATIONAL_DIFFERENCE,
    CLASS_ADVISORY_NONCLAIM,
    CLASS_DEPRECATED_REPORT,
    CLASS_UNCLASSIFIED,
];

/// Report mode, used both to label the report and to decide which reports own
/// proof-grade required checks.
fn report_mode(report: &str) -> &'static str {
    match report {
        "tamper_validation" => "expected_negative",
        "overheads"
        | "correctness"
        | "leakage_auc"
        | "mutual_information"
        | "trace_equivalence"
        | "latency_memory"
        | "storage_growth"
        | "capacity_sweep"
        // Written by scripts/run_capacity_sweep_full.sh, not the validation
        // script.
        | "capacity_sweep_full"
        | "matched_baselines"
        | "matched_baselines_full"
        | "stash_occupancy"
        // Written by scripts/run_stash_occupancy_full.sh, not the validation
        // script.
        | "stash_occupancy_full"
        | "storage_boundary"
        | "public_state"
        // Written by scripts/measure_tree_eviction_instructions.sh, not the probe.
        | "tree_eviction_instructions"
        // Written by scripts/measure_kernel_operator_instructions.sh, not the
        // probe.
        | "kernel_operator_instructions"
        | "abort_rollback"
        | "admission_matrix"
        | "claim_status"
        | "claim_artifact_manifest"
        | "ablation_study"
        | "engineering_cost" => "evaluation",
        "reviewer_summary"
        | "artifact_configuration"
        | "reproducibility_manifest"
        | "acceptance" => "advisory",
        _ => "proof_grade",
    }
}

/// Reports that are no longer part of any active claim. None at present; kept
/// as an explicit, auditable list so a deprecation is a deliberate edit.
fn is_deprecated_report(_report: &str) -> bool {
    false
}

/// Field names whose `false` value is the *good* / structural / descriptive
/// value, not a failed obligation. Examples: `uses_legacy_umbrella: false`
/// means the report does not lean on the legacy umbrella; `present_in_engine_impl:
/// false` means a forbidden helper is absent from the engine; `executable:
/// false` records a non-executable baseline as data.
const ADVISORY_FIELDS: &[&str] = &[
    "uses_legacy_umbrella",
    "present_in_engine_impl",
    "forbidden_present",
    "rust_semantic_refinement_claimed",
    "runtime_witness_authority_eliminated",
    "separate_finish_slot_meeting_artifact_required",
    "requires_enumerated_witness_family_for_theorem",
    "in_current_proofgrade_tcb",
    "runtime_normal_form",
    "theorem_facing_large_artifacts_require_enumeration",
    "exceeds_compact_budget",
    "estimated",
    "aborted",
    "executable",
    // A trace-equivalence row in the computational/ORAM class declares
    // `equality_is_obligation: false`; that is descriptive, not a failure.
    "equality_is_obligation",
    // False means a representative large map carries a symbolic/sub-enumerative
    // certificate instead of a full seed-space enumeration, which is expected.
    // (Renamed from the misleading `coverage_complete`, which read like a
    // coverage failure.)
    "seed_space_fully_enumerated",
    // A cell of the stash-occupancy report says whether its run overflowed
    // the stash. False is what a run should say. A run that overflows makes
    // the report's `no_run_overflowed` check false, which is not advisory.
    "overflowed",
];

/// ORAM-intrinsic physical-trace fields. These only exist for the ORAM route
/// (there is no exact-backend counterpart), so a `false` is always an expected
/// computational difference, not a failed exact-equality obligation.
const ORAM_INTRINSIC_COMPUTATIONAL_FIELDS: &[&str] = &[
    "physical_write_shape_uniform",
    "physical_read_shape_uniform",
    "canonical_leaf_values_match_runtime_seed",
    "canonical_leaf_seed_space_matches",
    "oram_improves_physical_writes",
];

/// Trace-equality fields that apply to *both* exact and ORAM backends. For an
/// exact backend, equality is a hard obligation (a `false` is a real failure);
/// only inside a computational/ORAM context is a `false` an expected
/// computational difference. The classifier keys on the path context (e.g.
/// `computational_uo`) rather than blanket-accepting these fields, so an
/// exact-backend regression cannot hide as a computational difference.
const TRACE_EQUALITY_FIELDS: &[&str] = &[
    "physical_trace_equal",
    "physical_read_equal",
    "logical_access_equal",
];

/// Whether a path/parent sits in a computational (ORAM) comparison context.
fn is_computational_context(path: &[String], parent: Option<&JsonValue>) -> bool {
    if path
        .iter()
        .any(|seg| seg == "computational_uo" || seg == "computational" || seg == "oram")
    {
        return true;
    }
    parent
        .map(|parent| {
            parent.get("backend").and_then(JsonValue::as_str) == Some("oram")
                || parent.get("variant").and_then(JsonValue::as_str) == Some("oram")
        })
        .unwrap_or(false)
}

/// Classify a single boolean-`false` leaf. `path` holds the full json pointer
/// path as string segments (array indices rendered as decimal). `parent` is the
/// object/array directly containing the leaf.
fn classify(report: &str, path: &[String], parent: Option<&JsonValue>) -> &'static str {
    if is_deprecated_report(report) {
        return CLASS_DEPRECATED_REPORT;
    }
    let n = path.len();
    let last = path.last().map(String::as_str).unwrap_or("");
    let parent_key = if n >= 2 { path[n - 2].as_str() } else { "" };
    let in_tamper = report == "tamper_validation" || path.iter().any(|s| s == "tamper_validation");
    let parent_is_array = parent.map(JsonValue::is_array).unwrap_or(false);
    // For an array element the meaningful name is the array's field name.
    let field = if parent_is_array { parent_key } else { last };

    if parent_is_array && parent_key.ends_with("runtime_normal_form_flags") {
        return CLASS_ADVISORY_NONCLAIM; // per-statement structural flag vector
    }
    if field.starts_with("engine_") {
        return CLASS_ADVISORY_NONCLAIM; // engine source-freeze negatives (false == good)
    }
    if ADVISORY_FIELDS.contains(&field) {
        return CLASS_ADVISORY_NONCLAIM;
    }
    if ORAM_INTRINSIC_COMPUTATIONAL_FIELDS.contains(&field) {
        return CLASS_EXPECTED_COMPUTATIONAL_DIFFERENCE;
    }
    if TRACE_EQUALITY_FIELDS.contains(&field) {
        // Computational only inside an ORAM context; an exact-backend equality
        // failure must surface as a required failure.
        return if is_computational_context(path, parent) {
            CLASS_EXPECTED_COMPUTATIONAL_DIFFERENCE
        } else {
            CLASS_REQUIRED_FAILURE
        };
    }
    if field == "rejected" {
        // A false `rejected` is only a real escape for a tamper *mutation* row
        // that was supposed to be rejected. Positive-control rows (no
        // `mutation`) and `rejected: false` outside tamper just mean
        // "ran / not rejected".
        let is_tamper_mutation = in_tamper
            && parent
                .map(|parent| parent.get("mutation").is_some())
                .unwrap_or(false);
        return if is_tamper_mutation {
            CLASS_REQUIRED_FAILURE
        } else {
            CLASS_ADVISORY_NONCLAIM
        };
    }
    if field == "accepted" {
        if let Some(parent) = parent {
            // Expected-negative tamper scenario: paired with rejected == true.
            if parent.get("rejected") == Some(&JsonValue::Bool(true)) {
                return CLASS_EXPECTED_NEGATIVE;
            }
            if in_tamper {
                return CLASS_EXPECTED_NEGATIVE;
            }
            // Translation-checker row: the probe compiles each benchmark with its
            // raw sidecar bytes, so the artifact is self-certifying and a UO
            // artifact the proof-grade checker rejects is a real failure.
            // Raw-mode artifacts target raw confidential backends, which
            // proof-grade translation rejects by design.
            if parent.get("lean_stderr").is_some() && parent.get("mode").is_some() {
                if parent.get("mode").and_then(JsonValue::as_str) == Some("raw") {
                    return CLASS_EXPECTED_NEGATIVE;
                }
                return CLASS_REQUIRED_FAILURE;
            }
            let mode_raw = parent.get("mode").and_then(JsonValue::as_str) == Some("raw");
            let kind_raw = parent
                .get("artifact_kind")
                .and_then(JsonValue::as_str)
                .map(|kind| kind.starts_with("raw"))
                .unwrap_or(false);
            if mode_raw || parent_key.starts_with("raw_") || kind_raw {
                return CLASS_EXPECTED_NEGATIVE;
            }
        }
        // A genuine proof-grade acceptance bit that is false.
        return CLASS_REQUIRED_FAILURE;
    }
    CLASS_UNCLASSIFIED
}

fn walk(
    node: &JsonValue,
    path: &mut Vec<String>,
    parent: Option<&JsonValue>,
    sink: &mut dyn FnMut(&[String], Option<&JsonValue>),
) {
    match node {
        JsonValue::Bool(false) => sink(path, parent),
        JsonValue::Object(map) => {
            for (key, value) in map {
                path.push(key.clone());
                walk(value, path, Some(node), sink);
                path.pop();
            }
        }
        JsonValue::Array(items) => {
            for (index, value) in items.iter().enumerate() {
                path.push(index.to_string());
                walk(value, path, Some(node), sink);
                path.pop();
            }
        }
        _ => {}
    }
}

fn empty_class_counts() -> BTreeMap<String, usize> {
    ALL_CLASSES
        .iter()
        .map(|class| ((*class).to_string(), 0usize))
        .collect()
}

/// Per-report classification verdict.
struct ReportVerdict {
    entry: JsonValue,
    accepted: bool,
    required: bool,
    class_counts: BTreeMap<String, usize>,
    unclassified: Vec<String>,
    required_failures: Vec<String>,
}

fn classify_report(report: &str, root: &JsonValue) -> ReportVerdict {
    let mut class_counts = empty_class_counts();
    // Every false path under its class, each class listed even when empty.
    let mut paths_by_class: BTreeMap<String, Vec<String>> = ALL_CLASSES
        .iter()
        .map(|class| ((*class).to_string(), Vec::new()))
        .collect();
    let mut false_total = 0usize;
    {
        let mut path_buf = Vec::new();
        walk(root, &mut path_buf, None, &mut |segments, parent| {
            let class = classify(report, segments, parent);
            false_total += 1;
            *class_counts.get_mut(class).expect("known class") += 1;
            paths_by_class
                .get_mut(class)
                .expect("known class")
                .push(segments.join("."));
        });
    }
    let unclassified = paths_by_class[CLASS_UNCLASSIFIED].clone();
    let required_failures = paths_by_class[CLASS_REQUIRED_FAILURE].clone();
    let mode = report_mode(report);
    let required = mode == "proof_grade";
    let accepted = unclassified.is_empty() && required_failures.is_empty();
    let declared_accepted = root.get("accepted").and_then(JsonValue::as_bool);
    let entry = json!({
        "schema": "uo.acceptance.report.v2",
        "report": report,
        "mode": mode,
        "required": required,
        "declared_accepted": declared_accepted,
        "accepted": accepted,
        "false_count": false_total,
        "class_counts": class_counts.clone(),
        "false_paths_by_class": paths_by_class,
        "required_failures": required_failures.clone(),
        "unclassified_false_paths": unclassified.clone(),
    });
    ReportVerdict {
        entry,
        accepted,
        required,
        class_counts,
        unclassified,
        required_failures,
    }
}

/// Public per-report verdict: classify a single report's false leaves and
/// return its acceptance entry. Used to give `bridge_validation` a clear
/// proof-grade verdict at generation time.
pub fn report_verdict(report: &str, root: &JsonValue) -> JsonValue {
    classify_report(report, root).entry
}

/// Build the aggregate acceptance report from the generated reports in
/// `out_dir`. Does not write anything.
pub fn run_acceptance_check_report(out_dir: &str) -> Result<JsonValue> {
    let dir = Path::new(out_dir);
    let mut json_files: Vec<(String, std::path::PathBuf)> = Vec::new();
    for entry in fs::read_dir(dir)
        .map_err(|err| anyhow!("acceptance-check cannot read results dir {out_dir}: {err}"))?
    {
        let entry = entry?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        if !name.ends_with(".json") || name == "acceptance.json" {
            continue;
        }
        let stem = name.trim_end_matches(".json").to_string();
        json_files.push((stem, path));
    }
    json_files.sort();

    let mut report_entries = Vec::new();
    let mut total_counts = empty_class_counts();
    let mut unclassified_paths = Vec::new();
    let mut required_failure_paths = Vec::new();
    let mut all_proof_grade_accepted = true;

    for (report, path) in &json_files {
        let bytes = fs::read(path)
            .map_err(|err| anyhow!("acceptance-check cannot read {}: {err}", path.display()))?;
        // Fail closed: a report that does not parse cannot be classified.
        let root: JsonValue = serde_json::from_slice(&bytes)
            .map_err(|err| anyhow!("acceptance-check cannot parse {}: {err}", path.display()))?;

        let verdict = classify_report(report, &root);
        for class in ALL_CLASSES {
            *total_counts.get_mut(*class).expect("known class") += verdict.class_counts[*class];
        }
        for unclassified in &verdict.unclassified {
            unclassified_paths.push(json!({"report": report, "path": unclassified}));
        }
        for required in &verdict.required_failures {
            required_failure_paths.push(json!({"report": report, "path": required}));
        }
        if verdict.required && !verdict.accepted {
            all_proof_grade_accepted = false;
        }
        report_entries.push(verdict.entry);
    }

    let accepted = unclassified_paths.is_empty()
        && required_failure_paths.is_empty()
        && all_proof_grade_accepted;

    Ok(json!({
        "schema": ACCEPTANCE_SCHEMA,
        "report": "acceptance",
        "mode": "proof_grade",
        "required": true,
        "accepted": accepted,
        "classes": ALL_CLASSES,
        "reports_scanned": json_files.iter().map(|(r, _)| r.clone()).collect::<Vec<_>>(),
        "class_counts": total_counts,
        "unclassified_false_paths": unclassified_paths,
        "required_failures": required_failure_paths,
        "reports": report_entries,
    }))
}

/// Run the acceptance check and return an error when not accepted, so the CLI
/// and validation scripts fail closed.
pub fn run_acceptance_check_fail_closed(out_dir: &str) -> Result<JsonValue> {
    let report = run_acceptance_check_report(out_dir)?;
    if report["accepted"].as_bool() != Some(true) {
        let unclassified = report["unclassified_false_paths"]
            .as_array()
            .map(|a| a.len())
            .unwrap_or(0);
        let required = report["required_failures"]
            .as_array()
            .map(|a| a.len())
            .unwrap_or(0);
        return Err(anyhow!(
            "acceptance gate failed: {unclassified} unclassified false path(s), {required} required failure(s); see {out_dir}/acceptance.json"
        ));
    }
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn temp_results_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("uo-acceptance-{tag}-{}", process_unique()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn process_unique() -> u64 {
        // Distinct per test invocation without relying on wall-clock.
        use std::sync::atomic::{AtomicU64, Ordering};
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        (std::process::id() as u64) << 16 | COUNTER.fetch_add(1, Ordering::Relaxed)
    }

    fn write(dir: &Path, name: &str, value: JsonValue) {
        fs::write(dir.join(name), serde_json::to_vec_pretty(&value).unwrap()).unwrap();
    }

    #[test]
    fn tamper_rejection_is_expected_negative_and_accepted() {
        let dir = temp_results_dir("tamper");
        write(
            &dir,
            "tamper_validation.json",
            json!({
                "scenarios": [
                    // A rejected mutation: accepted:false is the expected negative.
                    {"scenario": "drift", "mutation": "flip", "accepted": false, "rejected": true},
                    // A positive control: accepted:true, rejected:false is fine.
                    {"scenario": "control", "accepted": true, "rejected": false}
                ]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(true));
        assert!(report["unclassified_false_paths"]
            .as_array()
            .unwrap()
            .is_empty());
        assert!(report["required_failures"].as_array().unwrap().is_empty());
        assert_eq!(report["class_counts"]["expected_negative"], json!(1));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn unrejected_tamper_mutation_is_required_failure() {
        let dir = temp_results_dir("escape");
        write(
            &dir,
            "tamper_validation.json",
            json!({
                "scenarios": [
                    // A mutation that slipped through: accepted:true but the
                    // checker did not reject it (rejected:false).
                    {"scenario": "escape", "mutation": "flip", "accepted": true, "rejected": false}
                ]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        // A tamper mutation that was not rejected is a real escape and must fail
        // the gate.
        assert_eq!(report["accepted"], json!(false));
        assert_eq!(report["required_failures"].as_array().unwrap().len(), 1);
        let _ = fs::remove_dir_all(&dir);
    }

    /// A report's entry lists each false path under the class it was given,
    /// and every class, so that a reader takes the classes from this module
    /// (Issue 61 of the review of 16 November 2026).
    #[test]
    fn entries_list_every_false_path_under_its_class() {
        let report = json!({
            "accepted": true,
            "tamper": [{"mutation": "flip", "accepted": false, "rejected": true}],
            "trace": {"backend": "oram", "physical_write_shape_uniform": false},
            "executable": false,
            "check": {"ok": false},
        });
        let entry = report_verdict("bridge_validation", &report);
        assert_eq!(entry["schema"], json!("uo.acceptance.report.v2"));
        let by_class = entry["false_paths_by_class"].as_object().unwrap();
        assert_eq!(by_class.keys().map(String::as_str).collect::<Vec<_>>(), {
            let mut classes = ALL_CLASSES.to_vec();
            classes.sort_unstable();
            classes
        });
        assert_eq!(
            by_class[CLASS_EXPECTED_NEGATIVE],
            json!(["tamper.0.accepted"])
        );
        assert_eq!(
            by_class[CLASS_EXPECTED_COMPUTATIONAL_DIFFERENCE],
            json!(["trace.physical_write_shape_uniform"])
        );
        assert_eq!(by_class[CLASS_ADVISORY_NONCLAIM], json!(["executable"]));
        assert_eq!(by_class[CLASS_UNCLASSIFIED], json!(["check.ok"]));
        assert_eq!(entry["unclassified_false_paths"], json!(["check.ok"]));
        let listed: usize = by_class
            .values()
            .map(|paths| paths.as_array().unwrap().len())
            .sum();
        assert_eq!(listed, entry["false_count"].as_u64().unwrap() as usize);
        assert_eq!(entry["accepted"], json!(false));
    }

    #[test]
    fn false_proof_grade_acceptance_is_required_failure() {
        let dir = temp_results_dir("proofgrade");
        write(
            &dir,
            "bridge_validation.json",
            json!({"accepted": false, "detail": {"ok": true}}),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(false));
        assert_eq!(report["required_failures"].as_array().unwrap().len(), 1);
        assert!(run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_err());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn rejected_uo_translation_row_is_required_failure() {
        let dir = temp_results_dir("translation");
        write(
            &dir,
            "static_checks.json",
            json!({
                "reports": [{
                    // Raw-mode artifacts target raw confidential backends, which
                    // proof-grade translation rejects by design.
                    "raw_artifact": {"mode": "raw", "lean_stderr": "rejected", "accepted": false},
                    // A self-certifying UO artifact the checker rejects is real.
                    "uo_artifact": {"mode": "uo", "lean_stderr": "rejected", "accepted": false}
                }]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(false));
        assert_eq!(report["required_failures"].as_array().unwrap().len(), 1);
        assert_eq!(report["class_counts"]["expected_negative"], json!(1));
        let _ = fs::remove_dir_all(&dir);
    }

    /// A stash-occupancy cell that did not overflow is not a failure, and
    /// a report whose overflow check is false is one.
    #[test]
    fn stash_overflow_flag_is_advisory_and_its_check_is_not() {
        let dir = temp_results_dir("stash");
        write(
            &dir,
            "stash_occupancy_full.json",
            json!({
                "accepted": true,
                "checks": {"no_run_overflowed": true},
                "cells": [{"capacity": 256, "overflowed": false}]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(true));
        assert!(run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_ok());
        write(
            &dir,
            "stash_occupancy_full.json",
            json!({
                "accepted": false,
                "checks": {"no_run_overflowed": false},
                "cells": [{"capacity": 256, "overflowed": true}]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(false));
        assert!(run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_err());
        let _ = fs::remove_dir_all(&dir);
    }

    /// A call of the storage-boundary report that did not abort is not a
    /// failure. A call whose store log differs from its trace is one, and so
    /// is a restart that sealed a record under a nonce the files held.
    #[test]
    fn a_storage_boundary_difference_fails_closed() {
        let dir = temp_results_dir("storage-boundary");
        let report = |agrees: bool, no_nonce_repeats: bool| {
            json!({
                "accepted": agrees && no_nonce_repeats,
                "checks": {
                    "store_log_agrees_with_trace_in_every_call": agrees,
                    "every_restart_continues_its_deployment": no_nonce_repeats,
                },
                "benchmarks": [{
                    "store_log_agrees_with_trace": agrees,
                    "calls": [{
                        "aborted": false,
                        "store_writes_equal_traced_writes": true,
                        "store_reads_equal_traced_reads": agrees,
                    }],
                }],
                "restarts": [{"no_nonce_repeats_after_restart": no_nonce_repeats}],
            })
        };
        write(&dir, "storage_boundary.json", report(true, true));
        let accepted = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(accepted["accepted"], json!(true));
        assert!(run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_ok());
        for (agrees, no_nonce_repeats) in [(false, true), (true, false)] {
            write(
                &dir,
                "storage_boundary.json",
                report(agrees, no_nonce_repeats),
            );
            let rejected = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
            assert_eq!(rejected["accepted"], json!(false));
            assert!(run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_err());
        }
        let _ = fs::remove_dir_all(&dir);
    }

    /// The reports that test the runtime against a model state no Rust
    /// refinement, which is not a failure. A sample run that is not the
    /// substituted run is one, and so is an AVL map replay whose checker
    /// did not compare every recorded tree.
    #[test]
    fn a_runtime_against_model_divergence_fails_closed() {
        let dir = temp_results_dir("runtime-against-model");
        let tape = |agrees: bool| {
            json!({
                "accepted": agrees,
                "rust_semantic_refinement_claimed": false,
                "checks": {
                    "every_sample_run_is_its_representative_run_under_its_own_tape": agrees,
                    "every_sample_ran": true,
                },
                "maps": [{"every_run_is_the_substituted_run": agrees, "rejections": []}],
            })
        };
        let replay = |compared: bool| {
            json!({
                "accepted": compared,
                "rust_semantic_refinement_claimed": false,
                "checks": {"the_checker_compared_every_recorded_tree": compared},
            })
        };
        let files = [
            ("tape_substitution.json", tape(true), tape(false)),
            ("tape_substitution_full.json", tape(true), tape(false)),
            ("path_oram_avl_map_replay.json", replay(true), replay(false)),
            (
                "path_oram_avl_map_replay_full.json",
                replay(true),
                replay(false),
            ),
        ];
        for (name, good, _) in &files {
            write(&dir, name, good.clone());
        }
        let accepted = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(accepted["accepted"], json!(true));
        assert_eq!(accepted["class_counts"]["advisory_nonclaim"], json!(4));
        assert!(run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_ok());
        for (name, good, bad) in &files {
            write(&dir, name, bad.clone());
            let rejected = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
            assert_eq!(rejected["accepted"], json!(false), "{name}");
            assert!(
                run_acceptance_check_fail_closed(dir.to_str().unwrap()).is_err(),
                "{name}"
            );
            write(&dir, name, good.clone());
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn unknown_false_field_is_unclassified_and_fails_closed() {
        let dir = temp_results_dir("unknown");
        write(
            &dir,
            "kernel_validation.json",
            json!({"some_new_obligation_holds": false}),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(false));
        assert_eq!(
            report["unclassified_false_paths"].as_array().unwrap().len(),
            1
        );
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn advisory_and_computational_false_paths_are_accepted() {
        let dir = temp_results_dir("advisory");
        write(
            &dir,
            "runtime_boundary_validation.json",
            json!({
                "accepted": true,
                "rows": [
                    {"present_in_engine_impl": false, "rust_semantic_refinement_claimed": false}
                ]
            }),
        );
        write(
            &dir,
            "trace_equivalence.json",
            json!({
                "exact_uo": [{"backend": "uo", "physical_trace_equal": true}],
                "computational_uo": [
                    {"backend": "oram", "physical_trace_equal": false, "logical_access_equal": false}
                ]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(true));
        assert_eq!(report["class_counts"]["advisory_nonclaim"], json!(2));
        assert_eq!(
            report["class_counts"]["expected_computational_difference"],
            json!(2)
        );
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn renamed_and_relabeled_fields_are_classified() {
        // Issue 03: the renamed seed-space field and the computational-row
        // `equality_is_obligation: false` are advisory, not unclassified.
        let dir = temp_results_dir("issue03");
        write(
            &dir,
            "fresh_coin_validation.json",
            json!({"scenarios": [{"seed_space_fully_enumerated": false}]}),
        );
        write(
            &dir,
            "trace_equivalence.json",
            json!({
                "computational_uo": [
                    {"comparison_class": "computational_oram", "equality_is_obligation": false,
                     "physical_trace_equal": false}
                ]
            }),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(true));
        assert_eq!(
            report["unclassified_false_paths"].as_array().unwrap().len(),
            0
        );
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn exact_backend_trace_inequality_is_required_failure() {
        // A `physical_trace_equal: false` outside any computational/ORAM context
        // is an exact-backend regression and must fail the gate, rather than
        // hiding as an expected computational difference.
        let dir = temp_results_dir("exact-regress");
        write(
            &dir,
            "trace_equivalence.json",
            json!({"exact_uo": [{"backend": "uo", "physical_trace_equal": false}]}),
        );
        let report = run_acceptance_check_report(dir.to_str().unwrap()).unwrap();
        assert_eq!(report["accepted"], json!(false));
        assert_eq!(report["required_failures"].as_array().unwrap().len(), 1);
        let _ = fs::remove_dir_all(&dir);
    }
}
