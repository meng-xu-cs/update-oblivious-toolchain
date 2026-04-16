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

cd "$ROOT"
./scripts/compile_benches.sh
(
  cd "$ROOT/proof/lean"
  "$LAKE_BIN" build
)
cargo test
cargo run -q -p mplus-probe -- --only bridge-validation --out-dir "$RESULTS_DIR"
