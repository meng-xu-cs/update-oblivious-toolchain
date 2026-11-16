//! The evidence contract of the committed results bundle (Issue 62 of the
//! review of 16 November 2026).
//!
//! The acceptance gate classifies the false leaves of whatever reports it
//! finds, so a report that is missing, empty or short of a check adds no
//! false leaf and passes it. The contract says what the bundle holds: every
//! report, by name; the schema each declares, if any; and its fields, at the
//! top level and one level down, each with a descriptor of what it must be:
//!
//! - `true`: a check, which must be the boolean `true`;
//! - `boolean`, `null`, `string`, `number` or `object`: a value of that type;
//! - `array N`: an array of exactly `N` items, a population;
//! - `count N`: a count (a field named `count` or `..._count`, or one listed
//!   in `NAMED_POPULATIONS`) whose value must be exactly `N`.
//!
//! A field that is an object at the top level has its children described in
//! a nested map. The final acceptance check of the validation and of CI holds
//! the bundle to the contract and fails closed, naming every violation: a
//! report missing or unknown, a schema changed, a field missing, unknown or of
//! another type, a check that is not true, a population moved.
//!
//! The contract is `probe/mplus-probe/evidence_contract.json`. `--only
//! evidence-contract-draft` writes one from a bundle, and the committed one is
//! such a draft, reviewed. A change that adds a report or a field, or that
//! moves a population, regenerates it in the same commit, so that the diff of
//! the contract shows what moved.

use anyhow::{anyhow, bail, Context, Result};
use serde_json::{json, Map, Value as JsonValue};
use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

pub const EVIDENCE_CONTRACT_SCHEMA: &str = "uo.evidence_contract.v1";

const COMMITTED_CONTRACT: &str = include_str!("../evidence_contract.json");

/// Counts below the top level that are populations although their names do
/// not end in `_count`: the calls and the pairs of benchmark and backend that
/// the storage boundary covers.
const NAMED_POPULATIONS: &[(&str, &str)] = &[
    ("storage_boundary", "coverage.calls"),
    ("storage_boundary", "coverage.benchmark_backend_pairs"),
];

/// The report a contract does not describe: the aggregate the gate writes.
const ACCEPTANCE_REPORT: &str = "acceptance";

fn type_name(value: &JsonValue) -> &'static str {
    match value {
        JsonValue::Null => "null",
        JsonValue::Bool(_) => "boolean",
        JsonValue::Number(_) => "number",
        JsonValue::String(_) => "string",
        JsonValue::Array(_) => "array",
        JsonValue::Object(_) => "object",
    }
}

fn is_population(report: &str, path: &str, name: &str) -> bool {
    name == "count"
        || name.ends_with("_count")
        || NAMED_POPULATIONS
            .iter()
            .any(|(named_report, named)| *named_report == report && *named == path)
}

/// What the contract requires of `value`, the field `path` of `report`.
fn descriptor(report: &str, path: &str, name: &str, value: &JsonValue) -> String {
    match value {
        JsonValue::Bool(true) => "true".into(),
        JsonValue::Array(items) => format!("array {}", items.len()),
        JsonValue::Number(number) => match number.as_u64() {
            Some(count) if is_population(report, path, name) => format!("count {count}"),
            _ => "number".into(),
        },
        other => type_name(other).into(),
    }
}

fn check_name(name: &str, parent: Option<&str>) -> Result<()> {
    if name.contains('.') {
        match parent {
            Some(parent) => bail!("the field {parent}.{name:?} has a dot in its name"),
            None => bail!("the field {name:?} has a dot in its name"),
        }
    }
    Ok(())
}

/// The fields of a report, as the contract describes them.
fn shape(report: &str, root: &Map<String, JsonValue>) -> Result<Map<String, JsonValue>> {
    let mut fields = Map::new();
    for (name, value) in root {
        check_name(name, None)?;
        let described = match value {
            JsonValue::Object(children) => {
                let mut nested = Map::new();
                for (child, child_value) in children {
                    check_name(child, Some(name))?;
                    let path = format!("{name}.{child}");
                    nested.insert(
                        child.clone(),
                        json!(descriptor(report, &path, child, child_value)),
                    );
                }
                JsonValue::Object(nested)
            }
            other => json!(descriptor(report, name, name, other)),
        };
        fields.insert(name.clone(), described);
    }
    Ok(fields)
}

/// The names of the reports in `out_dir`: its JSON files but the gate's own.
fn report_names(out_dir: &Path) -> Result<BTreeSet<String>> {
    let mut names = BTreeSet::new();
    for entry in fs::read_dir(out_dir).with_context(|| format!("reading {}", out_dir.display()))? {
        let path = entry?.path();
        if !path.is_file() {
            continue;
        }
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if let Some(stem) = name.strip_suffix(".json") {
            if stem != ACCEPTANCE_REPORT {
                names.insert(stem.to_string());
            }
        }
    }
    Ok(names)
}

fn read_report(out_dir: &Path, name: &str) -> Result<JsonValue> {
    let path = out_dir.join(format!("{name}.json"));
    let bytes = fs::read(&path).with_context(|| format!("reading {}", path.display()))?;
    serde_json::from_slice(&bytes).with_context(|| format!("parsing {}", path.display()))
}

/// The contract that the bundle in `out_dir` satisfies as it is.
pub fn draft_evidence_contract(out_dir: &Path) -> Result<JsonValue> {
    let mut reports = Map::new();
    for name in report_names(out_dir)? {
        let root = read_report(out_dir, &name)?;
        let object = root
            .as_object()
            .ok_or_else(|| anyhow!("{name}.json is not a JSON object"))?;
        reports.insert(
            name.clone(),
            json!({
                "declared_schema": root.get("schema").cloned().unwrap_or(JsonValue::Null),
                "fields": shape(&name, object)?,
            }),
        );
    }
    Ok(json!({
        "schema": EVIDENCE_CONTRACT_SCHEMA,
        "what": "every report of the committed results bundle: the schema it declares, and its fields at the top level and one level down, each with what it must be (true, a type, an array of N items, or a count of N); written by `mplus-probe --only evidence-contract-draft` and reviewed; see probe/mplus-probe/src/evidence_contract.rs",
        "reports": reports,
    }))
}

/// The contract committed with the probe.
pub fn committed_evidence_contract() -> Result<JsonValue> {
    let contract: JsonValue = serde_json::from_str(COMMITTED_CONTRACT)
        .context("parsing probe/mplus-probe/evidence_contract.json")?;
    if contract["schema"] != json!(EVIDENCE_CONTRACT_SCHEMA) {
        bail!("probe/mplus-probe/evidence_contract.json has an unknown schema");
    }
    Ok(contract)
}

struct Violations(Vec<JsonValue>);

impl Violations {
    fn push(
        &mut self,
        report: &str,
        kind: &str,
        path: &str,
        expected: JsonValue,
        found: JsonValue,
    ) {
        self.0.push(json!({
            "report": report,
            "kind": kind,
            "path": path,
            "expected": expected,
            "found": found,
        }));
    }
}

/// Hold one field to its descriptor.
fn check_field(
    violations: &mut Violations,
    report: &str,
    path: &str,
    descriptor: &str,
    value: &JsonValue,
) -> Result<()> {
    let found_type = type_name(value);
    let (kind, bound) = match descriptor.split_once(' ') {
        Some((kind, bound)) => (
            kind,
            Some(
                bound
                    .parse::<u64>()
                    .map_err(|_| anyhow!("the contract's descriptor {descriptor:?} of {report}.{path} is not a type and a count"))?,
            ),
        ),
        None => (descriptor, None),
    };
    match (kind, bound) {
        ("true", None) => match value {
            JsonValue::Bool(true) => {}
            JsonValue::Bool(false) => {
                violations.push(report, "check_not_true", path, json!(true), json!(false))
            }
            _ => violations.push(
                report,
                "field_type_mismatch",
                path,
                json!("boolean"),
                json!(found_type),
            ),
        },
        ("boolean" | "null" | "string" | "number" | "object", None) => {
            if found_type != kind {
                violations.push(
                    report,
                    "field_type_mismatch",
                    path,
                    json!(kind),
                    json!(found_type),
                );
            }
        }
        ("array", Some(expected)) => match value {
            JsonValue::Array(items) if items.len() as u64 == expected => {}
            JsonValue::Array(items) => violations.push(
                report,
                "population_mismatch",
                path,
                json!(expected),
                json!(items.len()),
            ),
            _ => violations.push(
                report,
                "field_type_mismatch",
                path,
                json!("array"),
                json!(found_type),
            ),
        },
        ("count", Some(expected)) => match value.as_u64() {
            Some(found) if found == expected => {}
            Some(found) => violations.push(
                report,
                "population_mismatch",
                path,
                json!(expected),
                json!(found),
            ),
            None => violations.push(
                report,
                "field_type_mismatch",
                path,
                json!("count"),
                json!(found_type),
            ),
        },
        _ => {
            bail!("the contract's descriptor {descriptor:?} of {report}.{path} is not one it knows")
        }
    }
    Ok(())
}

/// Hold the fields of a report, or of one of its objects, to their
/// descriptors: each must be there and satisfy its descriptor, and no other
/// field may be there.
fn check_fields(
    violations: &mut Violations,
    report: &str,
    parent: Option<&str>,
    expected: &Map<String, JsonValue>,
    actual: &Map<String, JsonValue>,
) -> Result<()> {
    let path_of = |name: &str| match parent {
        Some(parent) => format!("{parent}.{name}"),
        None => name.to_string(),
    };
    for (name, described) in expected {
        let path = path_of(name);
        let Some(value) = actual.get(name) else {
            violations.push(
                report,
                "missing_field",
                &path,
                described.clone(),
                JsonValue::Null,
            );
            continue;
        };
        match (described, value) {
            (JsonValue::Object(children), JsonValue::Object(found)) if parent.is_none() => {
                check_fields(violations, report, Some(name), children, found)?;
            }
            (JsonValue::Object(_), other) => violations.push(
                report,
                "field_type_mismatch",
                &path,
                json!("object"),
                json!(type_name(other)),
            ),
            (JsonValue::String(descriptor), value) => {
                check_field(violations, report, &path, descriptor, value)?;
            }
            _ => {
                bail!("the contract describes {report}.{path} with neither a descriptor nor fields")
            }
        }
    }
    for (name, value) in actual {
        if !expected.contains_key(name) {
            violations.push(
                report,
                "unexpected_field",
                &path_of(name),
                JsonValue::Null,
                json!(type_name(value)),
            );
        }
    }
    Ok(())
}

/// Hold the bundle in `out_dir` to `contract`. Every violation is listed,
/// with the report, the kind, the field's path, and what the contract
/// expects and what the bundle has; an error is returned only for a contract
/// that is malformed.
pub fn check_evidence_contract(out_dir: &Path, contract: &JsonValue) -> Result<JsonValue> {
    let reports = contract["reports"]
        .as_object()
        .ok_or_else(|| anyhow!("the evidence contract lists no reports"))?;
    let present = report_names(out_dir)?;
    let mut violations = Violations(Vec::new());
    for (name, spec) in reports {
        if !present.contains(name) {
            violations.push(
                name,
                "missing_report",
                "",
                json!(format!("{name}.json")),
                JsonValue::Null,
            );
            continue;
        }
        let root = match read_report(out_dir, name) {
            Ok(root) => root,
            Err(err) => {
                violations.push(
                    name,
                    "unreadable_report",
                    "",
                    json!("a JSON object"),
                    json!(format!("{err:#}")),
                );
                continue;
            }
        };
        let Some(object) = root.as_object() else {
            violations.push(
                name,
                "not_an_object",
                "",
                json!("object"),
                json!(type_name(&root)),
            );
            continue;
        };
        let declared = root.get("schema").cloned().unwrap_or(JsonValue::Null);
        if declared != spec["declared_schema"] {
            violations.push(
                name,
                "schema_mismatch",
                "schema",
                spec["declared_schema"].clone(),
                declared,
            );
        }
        let expected = spec["fields"]
            .as_object()
            .ok_or_else(|| anyhow!("the evidence contract's entry for {name} has no fields"))?;
        check_fields(&mut violations, name, None, expected, object)?;
    }
    for name in &present {
        if !reports.contains_key(name) {
            violations.push(
                name,
                "unexpected_report",
                "",
                JsonValue::Null,
                json!(format!("{name}.json")),
            );
        }
    }
    let violations = violations.0;
    Ok(json!({
        "schema": EVIDENCE_CONTRACT_SCHEMA,
        "enforced": true,
        "reports_in_contract": reports.len(),
        "reports_present": present.len(),
        "satisfied": violations.is_empty(),
        "violations": violations,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn temp_dir(tag: &str) -> PathBuf {
        use std::sync::atomic::{AtomicU64, Ordering};
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let dir = std::env::temp_dir().join(format!(
            "uo-evidence-contract-{tag}-{}-{}",
            std::process::id(),
            COUNTER.fetch_add(1, Ordering::Relaxed)
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn write(dir: &Path, name: &str, value: &JsonValue) {
        fs::write(
            dir.join(format!("{name}.json")),
            serde_json::to_vec_pretty(value).unwrap(),
        )
        .unwrap();
    }

    /// A bundle of two reports and the gate's aggregate, and the contract
    /// drafted from it.
    fn bundle(tag: &str) -> (PathBuf, JsonValue) {
        let dir = temp_dir(tag);
        write(
            &dir,
            "tamper_validation",
            &json!({
                "scenario_count": 2,
                "scenarios": [
                    {"scenario": "a", "accepted": false, "rejected": true},
                    {"scenario": "b", "accepted": false, "rejected": true},
                ],
            }),
        );
        write(
            &dir,
            "storage_boundary",
            &json!({
                "schema": "uo-storage-boundary-v2",
                "accepted": true,
                "checks": {"store_log_agrees_with_trace_in_every_call": true},
                "coverage": {"calls": 47, "benchmark_backend_pairs": 14},
                "totals": {"store_reads": 3862},
                "benchmarks": [1, 2, 3],
                "advisory": false,
            }),
        );
        write(&dir, ACCEPTANCE_REPORT, &json!({"accepted": true}));
        let contract = draft_evidence_contract(&dir).unwrap();
        (dir, contract)
    }

    fn found(dir: &Path, contract: &JsonValue) -> Vec<(String, String, String)> {
        check_evidence_contract(dir, contract).unwrap()["violations"]
            .as_array()
            .unwrap()
            .iter()
            .map(|violation| {
                (
                    violation["report"].as_str().unwrap().to_string(),
                    violation["kind"].as_str().unwrap().to_string(),
                    violation["path"].as_str().unwrap().to_string(),
                )
            })
            .collect()
    }

    fn triple(report: &str, kind: &str, path: &str) -> (String, String, String) {
        (report.into(), kind.into(), path.into())
    }

    /// A draft describes what the bundle holds, nested one level down, with
    /// its checks, populations and named populations; the gate's aggregate is
    /// not in it; and the bundle it was drafted from satisfies it.
    #[test]
    fn a_draft_describes_the_bundle_and_the_bundle_satisfies_it() {
        let (dir, contract) = bundle("draft");
        assert_eq!(
            contract["reports"]["storage_boundary"],
            json!({
                "declared_schema": "uo-storage-boundary-v2",
                "fields": {
                    "accepted": "true",
                    "advisory": "boolean",
                    "benchmarks": "array 3",
                    "checks": {"store_log_agrees_with_trace_in_every_call": "true"},
                    "coverage": {"benchmark_backend_pairs": "count 14", "calls": "count 47"},
                    "schema": "string",
                    "totals": {"store_reads": "number"},
                },
            })
        );
        assert_eq!(
            contract["reports"]["tamper_validation"]["fields"],
            json!({"scenario_count": "count 2", "scenarios": "array 2"})
        );
        assert!(contract["reports"].get(ACCEPTANCE_REPORT).is_none());
        let section = check_evidence_contract(&dir, &contract).unwrap();
        assert_eq!(section["satisfied"], json!(true), "{section:#}");
        let _ = fs::remove_dir_all(&dir);
    }

    /// The negative controls: each way a bundle can fall short fails the
    /// contract, naming the report, the kind and the field.
    #[test]
    fn the_contract_fails_closed_on_missing_empty_and_incomplete_evidence() {
        // A report removed.
        let (dir, contract) = bundle("removed");
        fs::remove_file(dir.join("tamper_validation.json")).unwrap();
        let section = check_evidence_contract(&dir, &contract).unwrap();
        assert_eq!(section["satisfied"], json!(false));
        assert_eq!(
            found(&dir, &contract),
            vec![triple("tamper_validation", "missing_report", "")]
        );
        let _ = fs::remove_dir_all(&dir);

        // A report emptied: its schema and every field go.
        let (dir, contract) = bundle("emptied");
        write(&dir, "storage_boundary", &json!({}));
        let violations = found(&dir, &contract);
        for expected in [
            triple("storage_boundary", "schema_mismatch", "schema"),
            triple("storage_boundary", "missing_field", "accepted"),
            triple("storage_boundary", "missing_field", "checks"),
            triple("storage_boundary", "missing_field", "coverage"),
            triple("storage_boundary", "missing_field", "benchmarks"),
        ] {
            assert!(
                violations.contains(&expected),
                "{expected:?} in {violations:?}"
            );
        }
        let _ = fs::remove_dir_all(&dir);

        // A check field deleted, one level down.
        let (dir, contract) = bundle("field");
        let mut storage = read_report(&dir, "storage_boundary").unwrap();
        storage["checks"]
            .as_object_mut()
            .unwrap()
            .remove("store_log_agrees_with_trace_in_every_call");
        write(&dir, "storage_boundary", &storage);
        assert_eq!(
            found(&dir, &contract),
            vec![triple(
                "storage_boundary",
                "missing_field",
                "checks.store_log_agrees_with_trace_in_every_call"
            )]
        );
        let _ = fs::remove_dir_all(&dir);

        // Populations moved: one tamper scenario fewer, and a call fewer.
        let (dir, contract) = bundle("population");
        let mut tamper = read_report(&dir, "tamper_validation").unwrap();
        tamper["scenarios"].as_array_mut().unwrap().pop();
        write(&dir, "tamper_validation", &tamper);
        let mut storage = read_report(&dir, "storage_boundary").unwrap();
        storage["coverage"]["calls"] = json!(46);
        write(&dir, "storage_boundary", &storage);
        let section = check_evidence_contract(&dir, &contract).unwrap();
        assert_eq!(
            found(&dir, &contract),
            vec![
                triple("storage_boundary", "population_mismatch", "coverage.calls"),
                triple("tamper_validation", "population_mismatch", "scenarios"),
            ]
        );
        assert_eq!(section["violations"][1]["expected"], json!(2));
        assert_eq!(section["violations"][1]["found"], json!(1));
        let _ = fs::remove_dir_all(&dir);

        // A check that turned false, a field of another type, a field the
        // contract does not know, a schema changed, and a report it does not
        // know.
        let (dir, contract) = bundle("drift");
        let mut storage = read_report(&dir, "storage_boundary").unwrap();
        storage["accepted"] = json!(false);
        storage["totals"]["store_reads"] = json!("3862");
        storage["new_check"] = json!(true);
        storage["schema"] = json!("uo-storage-boundary-v3");
        write(&dir, "storage_boundary", &storage);
        write(&dir, "new_report", &json!({"accepted": true}));
        let violations = found(&dir, &contract);
        for expected in [
            triple("storage_boundary", "check_not_true", "accepted"),
            triple(
                "storage_boundary",
                "field_type_mismatch",
                "totals.store_reads",
            ),
            triple("storage_boundary", "unexpected_field", "new_check"),
            triple("storage_boundary", "schema_mismatch", "schema"),
            triple("new_report", "unexpected_report", ""),
        ] {
            assert!(
                violations.contains(&expected),
                "{expected:?} in {violations:?}"
            );
        }
        let _ = fs::remove_dir_all(&dir);
    }

    /// The positive control: the committed bundle satisfies the committed
    /// contract.
    #[test]
    fn the_committed_bundle_satisfies_the_committed_contract() {
        let contract = committed_evidence_contract().unwrap();
        let results = crate::workspace_path("results");
        let section = check_evidence_contract(&results, &contract).unwrap();
        assert_eq!(
            section["satisfied"],
            json!(true),
            "violations: {:#}",
            section["violations"]
        );
        assert!(section["reports_in_contract"].as_u64().unwrap() >= 90);
    }
}
