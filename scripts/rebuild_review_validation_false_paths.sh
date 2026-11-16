#!/usr/bin/env bash
# The false leaves of the gated validation reports, each with the class the
# acceptance gate gives it, in review/validation_false_paths.json and .txt.
#
#   --check      fail unless the snapshot regenerates as committed (default)
#   --write      regenerate the snapshot
#   --self-test  run the controls: a report whose only false leaf is an
#                expected negative must pass, and one with a required false
#                leaf must fail
#
# The script finds the false leaves of each gated report itself and takes
# their classes from results/acceptance.json, which the probe's acceptance
# check writes from the rules of probe/mplus-probe/src/acceptance.rs; no rule
# is repeated here. It fails when the two lists of false leaves differ (an
# acceptance.json that is stale), when a gated report has a false leaf classed
# required_failure or unclassified, and with --check when the committed
# snapshot differs. False leaves of the other classes are expected: rejected
# tamper scenarios, computational differences of the Path ORAM route, and
# advisory or non-claim bits.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="check"

case "${1:-}" in
  "" | --check)
    MODE="check"
    ;;
  --write)
    MODE="write"
    ;;
  --self-test)
    MODE="self-test"
    ;;
  *)
    printf 'usage: %s [--check|--write|--self-test]\n' "$0" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq executable not found; install jq to rebuild review validation snapshots\n' >&2
  exit 1
fi

GATED_REPORTS=(
  "kernel_model_alignment_validation"
  "runtime_boundary_validation"
  "bridge_validation"
  "static_checks"
)

# The classes a gated report may not have a false leaf in.
FAILING_CLASSES='["required_failure", "unclassified"]'

JSON_OUT="$ROOT/review/validation_false_paths.json"
TXT_OUT="$ROOT/review/validation_false_paths.txt"

# The probe that classifies the controls' reports; a built binary may be
# named instead.
PROBE="${UO_PROBE:-cargo run -q -p mplus-probe --}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uo-review-validation.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# The snapshot of the gated reports in the results directory $1, as JSON.
render_json() {
  local results="$1"
  local acceptance="$results/acceptance.json"
  local report
  if [[ ! -f "$acceptance" ]]; then
    printf 'missing %s; run the acceptance check first\n' "$acceptance" >&2
    return 1
  fi
  for report in "${GATED_REPORTS[@]}"; do
    if [[ ! -f "$results/$report.json" ]]; then
      printf 'missing gated validation report: %s\n' "$results/$report.json" >&2
      return 1
    fi
    jq -c --arg report "$report" --slurpfile acceptance "$acceptance" '
      def path_string($p): $p | map(tostring) | join(".");
      # The false leaves, as found here, in the order of the report.
      [paths(type == "boolean") as $p | select(getpath($p) == false) | path_string($p)]
        as $found
      # Their classes, as the acceptance gate gave them.
      | (first($acceptance[0].reports[] | select(.report == $report))
          // error("results/acceptance.json has no entry for \($report); run the acceptance check"))
        as $entry
      | ($entry.false_paths_by_class
          // error("results/acceptance.json lists no false paths by class for \($report); run the acceptance check"))
        as $by_class
      | [$by_class | to_entries[] | .key as $class | .value[] | {path: ., class: $class}]
        as $classified
      | if ($found | sort) != ($classified | map(.path) | sort) then
          error("\($report): the false leaves found here differ from those results/acceptance.json classifies; run the acceptance check")
        else . end
      | (reduce $classified[] as $leaf ({}; .[$leaf.path] = $leaf.class)) as $class_of
      | {
          ("results/\($report).json"): {
            false_count: ($found | length),
            class_counts: $entry.class_counts,
            top_level_booleans: (
              to_entries
              | map(select(.value | type == "boolean"))
              | sort_by(.key)
              | from_entries
            ),
            false_paths: [$found[] | {path: ., class: $class_of[.]}]
          }
        }
    ' "$results/$report.json" || return 1
  done | jq -S -s 'add'
}

render_txt() {
  jq -r '
    to_entries[]
    | "## \(.key)",
      "false_count: \(.value.false_count)",
      "class_counts:",
      (.value.class_counts | to_entries[] | "  \(.key): \(.value)"),
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
          (.value.false_paths[] | "  - \(.class): \(.path)")
        end
      ),
      ""
  ' "$1"
}

# Fail when a gated report has a false leaf of a failing class.
assert_green() {
  local snapshot="$1"
  if ! jq -e --argjson failing "$FAILING_CLASSES" '
    all(.[]; all(.false_paths[]; .class as $class | $failing | index($class) | not))
  ' "$snapshot" >/dev/null; then
    printf 'review validation snapshot contains false leaves the acceptance gate does not accept:\n' >&2
    jq -r --argjson failing "$FAILING_CLASSES" '
      to_entries[]
      | .key as $report
      | .value.false_paths[]
      | select(.class as $class | $failing | index($class))
      | "\($report): \(.class): \(.path)"
    ' "$snapshot" >&2
    return 1
  fi
}

# A results directory, $1, with the gated reports: each accepts and has no
# false leaf, except static_checks, which is $2. The acceptance check
# classifies them; it rejects a required false leaf after it has written
# acceptance.json, which the snapshot reads either way.
control_results() {
  local dir="$1"
  local static_checks="$2"
  local report
  mkdir -p "$dir"
  for report in "${GATED_REPORTS[@]}"; do
    printf '{"accepted": true}\n' >"$dir/$report.json"
  done
  printf '%s\n' "$static_checks" >"$dir/static_checks.json"
  (cd "$ROOT" && $PROBE --only acceptance-check --out-dir "$dir") >/dev/null 2>&1 || true
}

self_test() {
  local positive="$TMP_DIR/control-expected-negative"
  local negative="$TMP_DIR/control-required-failure"

  # A rejected tamper mutation: `accepted: false` beside `rejected: true`.
  control_results "$positive" \
    '{"accepted": true, "scenarios": [{"mutation": "flip a bit", "accepted": false, "rejected": true}]}'
  if ! render_json "$positive" >"$positive.snapshot.json" \
    || ! assert_green "$positive.snapshot.json"; then
    printf 'false-path control failed: an expected negative was not accepted\n' >&2
    return 1
  fi
  if ! jq -e '
    .["results/static_checks.json"].false_paths
      == [{"path": "scenarios.0.accepted", "class": "expected_negative"}]
  ' "$positive.snapshot.json" >/dev/null; then
    printf 'false-path control failed: the expected negative was not listed with its class\n' >&2
    return 1
  fi

  # A report that does not accept: a top-level `accepted: false`. It must be
  # classified, as a required failure, and then fail the check.
  control_results "$negative" '{"accepted": false}'
  if ! render_json "$negative" >"$negative.snapshot.json"; then
    printf 'false-path control failed: the required false leaf was not classified\n' >&2
    return 1
  fi
  if ! jq -e '
    .["results/static_checks.json"].false_paths
      == [{"path": "accepted", "class": "required_failure"}]
  ' "$negative.snapshot.json" >/dev/null; then
    printf 'false-path control failed: the required false leaf was not listed with its class\n' >&2
    return 1
  fi
  if assert_green "$negative.snapshot.json" 2>/dev/null; then
    printf 'false-path control failed: a required false leaf was accepted\n' >&2
    return 1
  fi

  printf 'false-path controls: an expected negative passes and a required false leaf fails\n'
}

if [[ "$MODE" == "self-test" ]]; then
  self_test
  exit 0
fi

render_json "$ROOT/results" >"$TMP_DIR/validation_false_paths.json"
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
      diff -u "$JSON_OUT" "$TMP_DIR/validation_false_paths.json" | head -100 >&2 || true
      exit 1
    fi
    if ! cmp -s "$TMP_DIR/validation_false_paths.txt" "$TXT_OUT"; then
      printf 'review/validation_false_paths.txt is stale; run %s --write\n' "$0" >&2
      diff -u "$TXT_OUT" "$TMP_DIR/validation_false_paths.txt" | head -100 >&2 || true
      exit 1
    fi
    ;;
esac

printf 'review validation false-path snapshot is consistent with gated results\n'
