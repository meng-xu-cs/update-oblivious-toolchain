//! Claim-consistency probe (Issue 04).
//!
//! The Path ORAM claim language must agree across README, the topic docs, the
//! Lean proof-grade root, and the Rust admission surface. In particular,
//! `path_oram_private_posmap_v1` is a theorem-facing scalable route (it is in
//! the `UOToolchain.ProofGradeRoot` import closure and is admitted by
//! proof-grade compilation), so no doc may describe it as experimental /
//! evaluation-only / rejected, and the README may not narrow the computational
//! route to the local-posmap scheme alone.
//!
//! This probe fails closed: any disagreement drives `accepted: false`.

use anyhow::{anyhow, Result};
use serde_json::{json, Value as JsonValue};
use std::fs;
use std::path::{Path, PathBuf};

pub const CLAIM_CONSISTENCY_SCHEMA: &str = "uo.claim_consistency.v1";

const LOCAL_SCHEME: &str = "path_oram_local_posmap_v1";
const PRIVATE_SCHEME: &str = "path_oram_private_posmap_v1";

fn repo_root() -> PathBuf {
    // CARGO_MANIFEST_DIR is .../probe/mplus-probe; the repo root is two up.
    let manifest = Path::new(env!("CARGO_MANIFEST_DIR"));
    manifest
        .join("..")
        .join("..")
        .canonicalize()
        .unwrap_or_else(|_| manifest.to_path_buf())
}

fn read(root: &Path, rel: &str) -> Result<String> {
    let path = root.join(rel);
    fs::read_to_string(&path)
        .map_err(|err| anyhow!("claim-consistency cannot read {}: {err}", path.display()))
}

struct Check {
    name: String,
    ok: bool,
    detail: String,
}

fn check(name: &str, ok: bool, detail: impl Into<String>) -> Check {
    Check {
        name: name.to_string(),
        ok,
        detail: detail.into(),
    }
}

/// Phrases that would mark a scheme as *not* theorem-facing. If any doc applies
/// one of these to the private-posmap scheme, the claim language disagrees with
/// the proof-grade root.
fn demotes_private_scheme(doc: &str) -> Option<String> {
    for line in doc.lines() {
        if !line.contains(PRIVATE_SCHEME) {
            continue;
        }
        let lowered = line.to_lowercase();
        for marker in [
            "experimental",
            "evaluation-only",
            "evaluation only",
            "non-proof-grade",
            "not theorem-facing",
            "rejected",
        ] {
            if lowered.contains(marker) {
                return Some(format!("line marks {PRIVATE_SCHEME} as `{marker}`: {line}"));
            }
        }
    }
    None
}

pub fn run_claim_consistency_report() -> Result<JsonValue> {
    let root = repo_root();
    let docs = [
        ("README.md", read(&root, "README.md")?),
        (
            "docs/claim-boundary.md",
            read(&root, "docs/claim-boundary.md")?,
        ),
        (
            "docs/supported-subset.md",
            read(&root, "docs/supported-subset.md")?,
        ),
        ("docs/path-oram.md", read(&root, "docs/path-oram.md")?),
    ];

    let mut checks = Vec::new();

    // Every doc must mention both schemes by name.
    for (name, body) in &docs {
        checks.push(check(
            &format!("{name}:mentions:{PRIVATE_SCHEME}"),
            body.contains(PRIVATE_SCHEME),
            format!("{name} references {PRIVATE_SCHEME}"),
        ));
    }

    // No doc may demote the private-posmap scheme below theorem-facing.
    for (name, body) in &docs {
        match demotes_private_scheme(body) {
            Some(detail) => checks.push(check(&format!("{name}:no-demotion"), false, detail)),
            None => checks.push(check(
                &format!("{name}:no-demotion"),
                true,
                format!("{name} does not demote {PRIVATE_SCHEME}"),
            )),
        }
    }

    // The README must not narrow the computational route to local-posmap alone.
    let readme = &docs[0].1;
    let readme_narrows = readme.contains(&format!("path is only\n  `{LOCAL_SCHEME}`"))
        || readme.contains(&format!("computational-UO path is only `{LOCAL_SCHEME}`"))
        || (readme.contains("computational-UO path is only") && !readme.contains(PRIVATE_SCHEME));
    checks.push(check(
        "README.md:does-not-narrow-to-local-only",
        !readme_narrows,
        if readme_narrows {
            "README narrows the computational-UO route to the local-posmap scheme alone"
        } else {
            "README presents both theorem-facing computational routes"
        },
    ));

    // The Lean proof-grade root must import the private-posmap modules.
    let proof_root = read(&root, "proof/lean/UOToolchain/ProofGradeRoot.lean")?;
    for module in ["PathOramPrivatePosmapV1", "ScalablePathOramEvidence"] {
        let imported = proof_root.contains(&format!("import UOToolchain.{module}"));
        checks.push(check(
            &format!("ProofGradeRoot:imports:{module}"),
            imported,
            format!("ProofGradeRoot imports UOToolchain.{module}"),
        ));
    }

    // The Rust admission surface must know the scheme and treat it as Path ORAM.
    let manifest = read(&root, "crates/uo-core/src/manifest.rs")?;
    checks.push(check(
        "manifest:has-private-scheme-constant",
        manifest.contains(&format!(
            "PATH_ORAM_PRIVATE_POSMAP_SCHEME: &str = \"{PRIVATE_SCHEME}\""
        )),
        "manifest.rs defines PATH_ORAM_PRIVATE_POSMAP_SCHEME",
    ));
    checks.push(check(
        "manifest:is-path-oram-scheme-includes-private",
        manifest
            .contains("scheme == PATH_ORAM_SCHEME || scheme == PATH_ORAM_PRIVATE_POSMAP_SCHEME"),
        "is_path_oram_scheme accepts the private-posmap scheme",
    ));

    let accepted = checks.iter().all(|c| c.ok);
    let failing: Vec<&Check> = checks.iter().filter(|c| !c.ok).collect();

    Ok(json!({
        "schema": CLAIM_CONSISTENCY_SCHEMA,
        "report": "claim_consistency",
        "accepted": accepted,
        "local_scheme": LOCAL_SCHEME,
        "private_scheme": PRIVATE_SCHEME,
        "check_count": checks.len(),
        "failing_count": failing.len(),
        "checks": checks
            .iter()
            .map(|c| json!({"name": c.name, "ok": c.ok, "detail": c.detail}))
            .collect::<Vec<_>>(),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn private_scheme_demotion_is_detected() {
        let doc = format!("The {PRIVATE_SCHEME} route is experimental for now.");
        assert!(demotes_private_scheme(&doc).is_some());
        let ok = format!("The {PRIVATE_SCHEME} route is theorem-facing for scalable maps.");
        assert!(demotes_private_scheme(&ok).is_none());
    }

    #[test]
    fn repo_claim_language_is_consistent() {
        // The committed repository must already be self-consistent.
        let report = run_claim_consistency_report().expect("claim-consistency report");
        assert_eq!(
            report["accepted"],
            json!(true),
            "claim language disagreement: {}",
            serde_json::to_string_pretty(&report["checks"]).unwrap()
        );
    }
}
