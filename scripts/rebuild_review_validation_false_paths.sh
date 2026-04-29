#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="check"

case "${1:-}" in
  "")
    ;;
  --check)
    MODE="check"
    ;;
  --write)
    MODE="write"
    ;;
  *)
    printf 'usage: %s [--check|--write]\n' "$0" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq executable not found; install jq to rebuild review validation snapshots\n' >&2
  exit 1
fi

GATED_REPORTS=(
  "results/kernel_model_alignment_validation.json"
  "results/runtime_boundary_validation.json"
  "results/bridge_validation.json"
  "results/static_checks.json"
)

JSON_OUT="$ROOT/review/validation_false_paths.json"
TXT_OUT="$ROOT/review/validation_false_paths.txt"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uo-review-validation.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

render_json() {
  local report
  for report in "${GATED_REPORTS[@]}"; do
    if [[ ! -f "$ROOT/$report" ]]; then
      printf 'missing gated validation report: %s\n' "$report" >&2
      exit 1
    fi
    jq -c --arg report "$report" '
      def path_string($p): $p | map(tostring) | join(".");
      def false_paths:
        [paths(scalars) as $p | select(getpath($p) == false) | path_string($p)];
      {
        ($report): {
          false_count: (false_paths | length),
          top_level_booleans: (
            to_entries
            | map(select(.value | type == "boolean"))
            | sort_by(.key)
            | from_entries
          ),
          false_paths: false_paths
        }
      }
    ' "$ROOT/$report"
  done | jq -S -s 'add'
}

render_txt() {
  jq -r '
    to_entries[]
    | "## \(.key)",
      "false_count: \(.value.false_count)",
      "top_level_booleans:",
      (
        if (.value.top_level_booleans | length) == 0 then
          "  []"
        else
          (.value.top_level_booleans | to_entries[] | "  \(.key): \(.value | tostring)")
        end
      ),
      "false_paths:",
      (
        if (.value.false_paths | length) == 0 then
          "  []"
        else
          (.value.false_paths[] | "  - \(.)")
        end
      ),
      ""
  ' "$1"
}

assert_green() {
  local snapshot="$1"
  if ! jq -e 'all(.[]; .false_count == 0)' "$snapshot" >/dev/null; then
    printf 'review validation snapshot contains false proof-grade checks:\n' >&2
    jq -r '
      to_entries[]
      | select(.value.false_count != 0)
      | "\(.key): \(.value.false_count) false checks",
        (.value.false_paths[] | "  - \(.)")
    ' "$snapshot" >&2
    exit 1
  fi
}

render_json >"$TMP_DIR/validation_false_paths.json"
render_txt "$TMP_DIR/validation_false_paths.json" >"$TMP_DIR/validation_false_paths.txt"
assert_green "$TMP_DIR/validation_false_paths.json"

case "$MODE" in
  write)
    cp "$TMP_DIR/validation_false_paths.json" "$JSON_OUT"
    cp "$TMP_DIR/validation_false_paths.txt" "$TXT_OUT"
    ;;
  check)
    if ! cmp -s "$TMP_DIR/validation_false_paths.json" "$JSON_OUT"; then
      printf 'review/validation_false_paths.json is stale; run %s --write\n' "$0" >&2
      diff -u "$JSON_OUT" "$TMP_DIR/validation_false_paths.json" >&2 || true
      exit 1
    fi
    if ! cmp -s "$TMP_DIR/validation_false_paths.txt" "$TXT_OUT"; then
      printf 'review/validation_false_paths.txt is stale; run %s --write\n' "$0" >&2
      diff -u "$TXT_OUT" "$TMP_DIR/validation_false_paths.txt" >&2 || true
      exit 1
    fi
    ;;
esac

printf 'review validation false-path snapshot is consistent with gated results\n'
