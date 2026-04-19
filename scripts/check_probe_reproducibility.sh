#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  if [[ "$arg" == "--out-dir" || "$arg" == --out-dir=* ]]; then
    printf 'check_probe_reproducibility.sh manages --out-dir itself; remove %s\n' "$arg" >&2
    exit 1
  fi
done

RUN_A="$(mktemp -d "${TMPDIR:-/tmp}/uo-probe-repro-a.XXXXXX")"
RUN_B="$(mktemp -d "${TMPDIR:-/tmp}/uo-probe-repro-b.XXXXXX")"

cleanup() {
  local exit_status=$?
  if [[ $exit_status -eq 0 && "${UO_REPRO_KEEP:-0}" != "1" ]]; then
    rm -rf "$RUN_A" "$RUN_B"
  else
    printf 'Preserved reproducibility runs at %s and %s\n' "$RUN_A" "$RUN_B" >&2
  fi
}
trap cleanup EXIT

cd "$ROOT"
cargo run -q -p mplus-probe -- "$@" --out-dir "$RUN_A"
cargo run -q -p mplus-probe -- "$@" --out-dir "$RUN_B"
diff -ru "$RUN_A" "$RUN_B"

printf 'mplus-probe outputs are byte-for-byte reproducible for: cargo run -q -p mplus-probe --'
if [[ $# -gt 0 ]]; then
  printf ' %q' "$@"
fi
printf '\n'
