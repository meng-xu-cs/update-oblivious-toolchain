#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_lake() {
  if [[ -n "${LAKE_BIN:-}" ]]; then
    printf '%s\n' "$LAKE_BIN"
    return
  fi
  if command -v lake >/dev/null 2>&1; then
    printf '%s\n' "lake"
    return
  fi
  if [[ -x "${HOME}/.elan/bin/lake" ]]; then
    printf '%s\n' "${HOME}/.elan/bin/lake"
    return
  fi
  printf 'lake executable not found; set LAKE_BIN or install Lean/Lake\n' >&2
  exit 1
}

LAKE_BIN="$(resolve_lake)"
RESULTS_DIR="${UO_RESULTS_DIR:-results}"
PROBE_ARGS=(--out-dir "$RESULTS_DIR")

if [[ "${UO_ARTIFACT_MODE:-compact}" == "heavy" ]]; then
  PROBE_ARGS+=(--artifact-mode heavy)
fi
if [[ -n "${UO_CANONICAL_CERT_BUDGET_BYTES:-}" ]]; then
  PROBE_ARGS+=(--compact-budget-bytes "$UO_CANONICAL_CERT_BUDGET_BYTES")
fi
if [[ -n "${UO_HEAVY_ARTIFACT_BUDGET_BYTES:-}" ]]; then
  PROBE_ARGS+=(--heavy-budget-bytes "$UO_HEAVY_ARTIFACT_BUDGET_BYTES")
fi

cd "$ROOT"
./scripts/compile_benches.sh
(
  cd "$ROOT/proof/lean"
  "$LAKE_BIN" build
)
cargo test
cargo run -q -p mplus-probe -- "${PROBE_ARGS[@]}"
# Executable insecure baselines (Issue 16): regenerate overheads + leakage with
# the insecure-eval-raw feature so every benchmark carries an executable raw
# insecure-baseline row and a positive-control leakage measurement. This build
# bypasses the confidential-object targeting restriction and is evaluation-only;
# the proof-grade reports above and the acceptance gate below use the strict
# default build, and production/proof-grade translation reject these artifacts.
cargo run -q -p mplus-probe --features insecure-eval-raw -- --only overheads "${PROBE_ARGS[@]}"
cargo run -q -p mplus-probe --features insecure-eval-raw -- --only leakage-auc "${PROBE_ARGS[@]}"
# Differential correctness (Issue 17): with the insecure-eval-raw feature the raw
# baseline is executable, so each seeded trial compares the raw baseline and the
# UO artifact on the same logical inputs and requires equal public outputs. The
# raw baselines execute the insecure path, which is slow per trial, so this gate
# defaults to a feasible 4-trial subset (matching CI's focused run); raise
# UO_CORRECTNESS_TRIALS for deeper small-domain coverage (cost ~linear in trials).
UO_CORRECTNESS_TRIALS="${UO_CORRECTNESS_TRIALS:-4}" \
  cargo run -q -p mplus-probe --features insecure-eval-raw -- --only correctness "${PROBE_ARGS[@]}"
# End-to-end edge cases (Issue 19), strict default build. The capacity sweep
# drives a bounded map past the proof-grade ORAM position-map bound (overflow
# rows recorded explicitly); the abort/rollback study drives confidential calls
# past a require(...) guard and checks public state rolls back on abort and
# commits otherwise. Override UO_SWEEP_* for deeper capacity sweeps. The sweep
# reports wall-clock latencies, so it runs from a release build.
cargo run -q --release -p mplus-probe -- --only capacity-sweep "${PROBE_ARGS[@]}"
cargo run -q -p mplus-probe -- --only path-oram-avl-map-replay "${PROBE_ARGS[@]}"
cargo run -q -p mplus-probe -- --only abort-rollback "${PROBE_ARGS[@]}"
# Compiler admission matrix (Issue 20): compile-and-run every accepted DSL
# feature and reject every unsupported one with a diagnostic that names the
# feature. Generated on the strict default build; fail-closed via acceptance.
cargo run -q -p mplus-probe -- --only admission-matrix "${PROBE_ARGS[@]}"
# Fail-closed proof-grade acceptance aggregate over the generated reports.
cargo run -q -p mplus-probe -- --only acceptance-check "${PROBE_ARGS[@]}"
# Fail-closed Path ORAM claim-consistency check (README/docs/proof/code agree).
cargo run -q -p mplus-probe -- --only claim-consistency "${PROBE_ARGS[@]}"
# Generated claim/evaluation artifact manifests (Issue 21). Fails closed if
# docs/claim-boundary.md names a claim/assumption/non-claim/TCB row that the
# manifest does not carry, or if a referenced artifact is missing.
cargo run -q -p mplus-probe -- --only claim-status "${PROBE_ARGS[@]}"
./scripts/rebuild_review_validation_false_paths.sh --write
./scripts/rebuild_review_validation_false_paths.sh --check
