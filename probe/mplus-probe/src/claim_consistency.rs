//! Claim-consistency probe (Issue 04).
//!
//! The Path ORAM claim language must agree across README, the topic docs, the
//! Lean proof-grade root, and the Rust admission surface. Today
//! `path_oram_private_posmap_v1` executes but its Lean theorems take an empty
//! proof bundle, so no doc may present it as theorem-facing or proof-grade,
//! and every doc that mentions it must say that it is not yet covered by a
//! theorem.
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

/// A line that presents the private-posmap scheme as theorem-facing or
/// proof-grade. While no theorem covers the scheme, any such line overclaims;
/// a line that negates the status ("not theorem-facing") is a status note.
fn promotes_private_scheme(doc: &str) -> Option<String> {
    for line in doc.lines() {
        if !line.contains(PRIVATE_SCHEME) {
            continue;
        }
        let lowered = line.to_lowercase();
        if lowered.contains("not ") {
            continue;
        }
        for marker in ["theorem-facing", "proof-grade", "proved"] {
            if lowered.contains(marker) {
                return Some(format!(
                    "line presents {PRIVATE_SCHEME} as `{marker}`: {line}"
                ));
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

    // No doc may present the private-posmap scheme as theorem-facing.
    for (name, body) in &docs {
        match promotes_private_scheme(body) {
            Some(detail) => checks.push(check(&format!("{name}:no-promotion"), false, detail)),
            None => checks.push(check(
                &format!("{name}:no-promotion"),
                true,
                format!("{name} does not present {PRIVATE_SCHEME} as theorem-facing"),
            )),
        }
    }

    // Every doc must state that no theorem covers the private-posmap scheme yet
    // (compared with whitespace collapsed, so line wrapping does not matter).
    for (name, body) in &docs {
        let collapsed = body.split_whitespace().collect::<Vec<_>>().join(" ");
        checks.push(check(
            &format!("{name}:states-private-scheme-unproved"),
            collapsed.contains("not yet covered by a theorem"),
            format!("{name} states that {PRIVATE_SCHEME} is not yet covered by a theorem"),
        ));
    }

    // The README must name the local-posmap scheme as the route with a Lean
    // instance.
    let readme = docs[0].1.split_whitespace().collect::<Vec<_>>().join(" ");
    checks.push(check(
        "README.md:names-local-route-with-lean-instance",
        readme.contains(&format!(
            "computational-UO route with a Lean instance is `{LOCAL_SCHEME}`"
        )),
        format!("README names {LOCAL_SCHEME} as the computational-UO route with a Lean instance"),
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
    fn private_scheme_promotion_is_detected() {
        let doc = format!("The {PRIVATE_SCHEME} route is theorem-facing for scalable maps.");
        assert!(promotes_private_scheme(&doc).is_some());
        let note = format!("The {PRIVATE_SCHEME} route executes but is not theorem-facing yet.");
        assert!(promotes_private_scheme(&note).is_none());
    }

    #[test]
    fn per_case_rejection_is_not_a_promotion() {
        let doc =
            format!("A multi-access {PRIVATE_SCHEME} entrypoint is rejected at compile time.");
        assert!(promotes_private_scheme(&doc).is_none());
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
