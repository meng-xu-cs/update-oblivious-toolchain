#!/usr/bin/env bash
set -euo pipefail

# Local evaluation driver for update-oblivious-toolchain-main.
# Run from the repository root. This script records evidence in eval_out/.

ROOT="$(pwd)"
OUT="$ROOT/eval_out"
mkdir -p "$OUT" "$OUT/build_logs" "$OUT/lean_logs" "$OUT/static" "$OUT/results"

log() { printf '\n== %s ==\n' "$*" | tee -a "$OUT/runbook.log"; }
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" | tee -a "$OUT/runbook.log"
    exit 2
  fi
}

log "tool availability"
need cargo
need rustc
need jq
need rg
need sha256sum
if ! command -v lake >/dev/null 2>&1 || ! command -v lean >/dev/null 2>&1; then
  echo "missing Lean/Lake; install elan and use proof/lean/lean-toolchain" | tee -a "$OUT/runbook.log"
  exit 2
fi

log "environment capture"
{
  echo "root=$ROOT"
  date -u
  uname -a || true
  git rev-parse HEAD 2>/dev/null || echo "no git hash"
  rustc --version --verbose
  cargo --version
  (cd proof/lean && lean --version && lake --version)
} | tee "$OUT/environment.txt"
find . -maxdepth 3 -type f | sort > "$OUT/file_inventory.txt"
sha256sum Cargo.lock proof/lean/lean-toolchain 2>/dev/null | tee "$OUT/source_hashes.txt" || true

log "static red-flag scan"
rg -n "\baxiom\b|\bsorry\b|admit|unsafe|unwrap\(|panic!|todo!|unimplemented!" proof compiler crates runtime checker benches scripts > "$OUT/static/red_flags.txt" || true
rg -n "legacyOramLocalTheorem|legacySgxMicroLocalTheorem" proof/lean > "$OUT/static/legacy_symbol_surface.txt" || true
rg -n "returns|status|declassifies|PublicOutcomeTrace|SGXPublicOutcome|ProofRelevantEntrypointView" proof crates compiler runtime checker > "$OUT/static/policy_surface.txt" || true

log "Rust format/check/test"
cargo fmt --all --check | tee "$OUT/build_logs/cargo_fmt.log"
cargo check --workspace --all-targets | tee "$OUT/build_logs/cargo_check.log"
cargo test --workspace --all-targets --no-fail-fast | tee "$OUT/build_logs/cargo_test.log"

log "Rust clippy"
# If this fails due existing warnings, keep the log and triage; do not silently ignore.
cargo clippy --workspace --all-targets -- -D warnings | tee "$OUT/build_logs/cargo_clippy.log"

log "Lean proof-grade build and axiom report"
(
  cd proof/lean
  lake build UOToolchain.ProofGradeRoot | tee "$OUT/lean_logs/lake_build_proofgrade.log"
  lake build | tee "$OUT/lean_logs/lake_build_all.log"
  lake env lean CheckProofGradeAxiomReport.lean | tee "$OUT/lean_logs/axiom_report.log"
)

log "repository validation scripts"
./scripts/run_validation.sh | tee "$OUT/results/run_validation.log"
./scripts/run_bridge_validation.sh | tee "$OUT/results/run_bridge_validation.log"
./scripts/check_probe_reproducibility.sh | tee "$OUT/results/check_probe_reproducibility.log"
./scripts/run_heavy_artifact.sh | tee "$OUT/results/run_heavy_artifact.log"
./scripts/run_all.sh | tee "$OUT/results/run_all.log"

log "summarize committed/generated JSON"
for f in results/*.json; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  sha256sum "$f" >> "$OUT/results/result_hashes.txt"
  jq 'def walkstats: [.. | objects | select(has("accepted")) | .accepted] | {accepted: map(select(.==true))|length, rejected: map(select(.==false))|length}; {file: input_filename, scenario_count: (.scenario_count // null), accept_reject: walkstats}' "$f" > "$OUT/results/${base%.json}_summary.json" 2>/dev/null || true
 done

log "policy-surface smoke assertion"
# This is intentionally a smoke check, not a proof. After the recommended fix,
# the proof-relevant view and Lean public outcome should contain policy fields.
if ! rg -n "returns|status|declassifies" crates/uo-core/src/translation_validation.rs proof/lean/UOToolchain >/dev/null; then
  echo "WARNING: policy fields do not appear in proof-relevant translation/Lean surface" | tee -a "$OUT/runbook.log"
fi

log "complete"
find "$OUT" -type f -print0 | sort -z | xargs -0 sha256sum > "$OUT/eval_out_hashes.txt"
echo "Evidence written to $OUT"
