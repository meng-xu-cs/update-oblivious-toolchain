#!/usr/bin/env bash
# One-command reproducible baseline for the UO toolchain.
#
# Runs the documented baseline gate and records the exact tool versions and
# content hashes used into results/local-baseline/manifest.json so that a
# scientific claim does not silently depend on an unrecorded local setup.
#
# Usage:
#   scripts/baseline.sh            # full gate (tests + Lean root + full validation)
#   scripts/baseline.sh --focused  # fast gate (fmt + tests + probe check + Lean root)
#
# The focused gate is the per-PR CI target. The full gate additionally runs
# ./scripts/run_validation.sh and the review false-path snapshot check.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="full"
case "${1:-}" in
  "" | --full) MODE="full" ;;
  --focused) MODE="focused" ;;
  *)
    printf 'usage: %s [--full|--focused]\n' "$0" >&2
    exit 2
    ;;
esac

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

MANIFEST_DIR="$ROOT/results/local-baseline"
MANIFEST="$MANIFEST_DIR/manifest.json"
mkdir -p "$MANIFEST_DIR"

STEP_NAMES=()
STEP_STATUS=()

tool_version() {
  # Print the first line of `<tool> <args...>`; "unavailable" if missing.
  local tool="$1"
  shift
  if command -v "$tool" >/dev/null 2>&1; then
    "$tool" "$@" 2>&1 | head -n 1
  else
    printf 'unavailable'
  fi
}

lake_version() {
  ("$LAKE_BIN" --version 2>&1 | head -n 1) || printf 'unavailable'
}

lean_version() {
  (cd "$ROOT/proof/lean" && lake env lean --version 2>&1 | head -n 1) || printf 'unavailable'
}

sha256_file() {
  if [[ -f "$1" ]]; then
    sha256sum "$1" | awk '{print $1}'
  else
    printf 'absent'
  fi
}

write_manifest() {
  local outcome="$1"
  local steps_json="[]"
  if ((${#STEP_NAMES[@]} > 0)); then
    steps_json="$(
      for i in "${!STEP_NAMES[@]}"; do
        jq -n --arg name "${STEP_NAMES[$i]}" --arg status "${STEP_STATUS[$i]}" \
          '{name: $name, status: $status}'
      done | jq -s '.'
    )"
  fi

  jq -n \
    --arg schema "uo.local_baseline.manifest.v1" \
    --arg mode "$MODE" \
    --arg outcome "$outcome" \
    --arg git_commit "$(git rev-parse HEAD 2>/dev/null || echo unknown)" \
    --arg git_dirty "$(if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then echo false; else echo true; fi)" \
    --arg rustc "$(tool_version rustc --version)" \
    --arg cargo "$(tool_version cargo --version)" \
    --arg lake "$(lake_version)" \
    --arg lean "$(lean_version)" \
    --arg jq "$(tool_version jq --version)" \
    --arg python3 "$(tool_version python3 --version)" \
    --arg bash "${BASH_VERSION:-unknown}" \
    --arg pinned_rust_channel "$(grep -E '^channel' rust-toolchain.toml | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')" \
    --arg pinned_lean_toolchain "$(cat proof/lean/lean-toolchain 2>/dev/null || echo unknown)" \
    --arg hash_rust_toolchain "$(sha256_file rust-toolchain.toml)" \
    --arg hash_lean_toolchain "$(sha256_file proof/lean/lean-toolchain)" \
    --arg hash_cargo_lock "$(sha256_file Cargo.lock)" \
    --arg hash_lake_manifest "$(sha256_file proof/lean/lake-manifest.json)" \
    --arg hash_baseline_script "$(sha256_file scripts/baseline.sh)" \
    --argjson steps "$steps_json" \
    '{
      schema: $schema,
      mode: $mode,
      outcome: $outcome,
      git: { commit: $git_commit, dirty: ($git_dirty == "true") },
      tools: {
        rustc: $rustc,
        cargo: $cargo,
        lake: $lake,
        lean: $lean,
        jq: $jq,
        python3: $python3,
        bash: $bash
      },
      pinned: {
        rust_channel: $pinned_rust_channel,
        lean_toolchain: $pinned_lean_toolchain
      },
      content_hashes: {
        "rust-toolchain.toml": $hash_rust_toolchain,
        "proof/lean/lean-toolchain": $hash_lean_toolchain,
        "Cargo.lock": $hash_cargo_lock,
        "proof/lean/lake-manifest.json": $hash_lake_manifest,
        "scripts/baseline.sh": $hash_baseline_script
      },
      steps: $steps
    }' >"$MANIFEST"
  printf 'wrote %s (outcome=%s)\n' "$MANIFEST" "$outcome"
}

run_step() {
  local name="$1"
  shift
  printf '\n==> [%s] %s\n' "$MODE" "$name"
  if "$@"; then
    STEP_NAMES+=("$name")
    STEP_STATUS+=("pass")
  else
    STEP_NAMES+=("$name")
    STEP_STATUS+=("fail")
    printf '\nbaseline step failed: %s\n' "$name" >&2
    write_manifest "failed"
    exit 1
  fi
}

step_fmt() { cargo fmt --all --check; }
step_test() { cargo test --workspace; }
# A workspace build turns on uo-evm's diagnostics feature, which compiles out
# the tests of the production call path. This runs them.
step_test_production_runtime() { cargo test -p uo-evm; }
step_test_all_features() { cargo test --workspace --all-features; }
step_probe_check() { cargo check -p mplus-probe; }
step_lean_root() { (cd "$ROOT/proof/lean" && "$LAKE_BIN" build UOToolchain.ProofGradeRoot); }
step_full_validation() { ./scripts/run_validation.sh; }
step_review_snapshot() {
  ./scripts/rebuild_review_validation_false_paths.sh --check \
    && ./scripts/rebuild_review_validation_false_paths.sh --self-test
}
step_git_diff() { git diff --check; }

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq executable not found; install jq to record the baseline manifest\n' >&2
  exit 1
fi

run_step "cargo fmt --all --check" step_fmt
run_step "cargo check -p mplus-probe" step_probe_check
run_step "lake build UOToolchain.ProofGradeRoot" step_lean_root
run_step "cargo test --workspace" step_test
run_step "cargo test -p uo-evm" step_test_production_runtime

if [[ "$MODE" == "full" ]]; then
  run_step "cargo test --workspace --all-features" step_test_all_features
  run_step "scripts/run_validation.sh" step_full_validation
  run_step "rebuild_review_validation_false_paths.sh --check and --self-test" step_review_snapshot
  run_step "git diff --check" step_git_diff
fi

write_manifest "passed"
printf '\nbaseline (%s) passed\n' "$MODE"
