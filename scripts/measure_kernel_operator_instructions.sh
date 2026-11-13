#!/usr/bin/env bash
# Count, with callgrind, the instructions the confidential kernel's slot
# interpreter spends on one evaluation of each binary operator, for every
# class of operands that an operator with branches would tell apart, and
# write the counts to results/kernel_operator_instructions.json.
#
#   scripts/measure_kernel_operator_instructions.sh [BEFORE_REV [AFTER_REV]]
#
# BEFORE_REV defaults to a3eb01a, the last commit whose 256-bit subtraction,
# division, comparisons, equality and boolean operators branched on their
# operands. AFTER_REV defaults to WORKTREE, the files of the working tree
# (tracked or not ignored); any other value is a revision, exported with
# `git archive`. Each side is built in release with the example
# crates/uo-core/examples/kernel_operator_classes.rs of the working tree,
# which evaluates `slot0 <operator> slot1` sixteen times on one class of
# operands. Callgrind counts the instructions inside those evaluations
# (--toggle-collect on the example's `evaluate_operator`), UO_MEASURE_REPEATS
# times per operator and class (default 2).
#
# The report gives, per side, operator and class, the instructions of the
# sixteen evaluations, and for each operator how many distinct counts its
# classes have: one when the count does not depend on the operands. It states
# whether the repeated runs agree and whether every operator of the "after"
# side has one count. These are instruction counts of one release build under
# callgrind. They say nothing about cache or branch-predictor state, and are
# not a claim about the machine code a compiler may emit elsewhere.
#
# Needs git, cargo, valgrind and python3. Takes about 10 minutes on four
# cores. Set UO_KEEP_WORK=1 to keep the scratch directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BEFORE_REV="${1:-a3eb01a}"
AFTER_REV="${2:-WORKTREE}"
REPEATS="${UO_MEASURE_REPEATS:-2}"
JOBS="${UO_MEASURE_JOBS:-$(nproc 2>/dev/null || echo 2)}"
OUT="${UO_RESULTS_DIR:-results}/kernel_operator_instructions.json"
EXAMPLE="crates/uo-core/examples/kernel_operator_classes.rs"
# The sources whose operations the example runs.
MEASURED_SOURCES=(
  "crates/uo-core/src/types.rs"
  "crates/uo-core/src/generated_confidential_kernel.rs"
  "crates/uo-core/src/generated_value_ops.rs"
  "$EXAMPLE"
)

for tool in git cargo valgrind python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$tool" >&2
    exit 1
  fi
done
if [[ ! "$REPEATS" =~ ^[1-9][0-9]*$ ]]; then
  printf 'UO_MEASURE_REPEATS must be a positive integer, found `%s`\n' "$REPEATS" >&2
  exit 1
fi
if [[ ! -f "$EXAMPLE" ]]; then
  printf '%s is missing\n' "$EXAMPLE" >&2
  exit 1
fi

BEFORE_COMMIT="$(git rev-parse --verify "${BEFORE_REV}^{commit}")"
if [[ "$AFTER_REV" == "WORKTREE" ]]; then
  AFTER_COMMIT="WORKTREE"
else
  AFTER_COMMIT="$(git rev-parse --verify "${AFTER_REV}^{commit}")"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/uo-kernel-operators.XXXXXX")"
cleanup() {
  if [[ "${UO_KEEP_WORK:-0}" == "1" ]]; then
    printf 'kept scratch directory %s\n' "$WORK" >&2
  else
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

export_side() {
  local label="$1" commit="$2"
  local src="$WORK/$label/src"
  mkdir -p "$src"
  if [[ "$commit" == "WORKTREE" ]]; then
    git ls-files -z --cached --others --exclude-standard |
      while IFS= read -r -d '' path; do
        if [[ -f "$path" ]]; then
          mkdir -p "$src/$(dirname "$path")"
          cp "$path" "$src/$path"
        fi
      done
  else
    git archive "$commit" | tar -x -C "$src"
    mkdir -p "$src/$(dirname "$EXAMPLE")"
    cp "$EXAMPLE" "$src/$EXAMPLE"
  fi
}

measure() {
  local label="$1" commit="$2"
  local src="$WORK/$label/src" target="$WORK/$label/target" runs="$WORK/$label/runs"
  export_side "$label" "$commit"
  printf '[%s] building the example in release\n' "$label" >&2
  (cd "$src" && CARGO_TARGET_DIR="$target" cargo build -q --release -p uo-core \
    --example kernel_operator_classes)
  local binary="$target/release/examples/kernel_operator_classes"
  "$binary" list >"$WORK/$label/cases.txt"
  mkdir -p "$runs"
  printf '[%s] %s operator classes, %s callgrind runs each\n' \
    "$label" "$(wc -l <"$WORK/$label/cases.txt")" "$REPEATS" >&2
  local run
  for run in $(seq 1 "$REPEATS"); do
    # One callgrind process per operator and class; the counts are of the
    # traced process alone, so the runs can share the machine.
    xargs -P "$JOBS" -L 1 bash -c '
      operator="$3"; class="$4"
      out="$1/$operator.$class.run$2"
      valgrind --tool=callgrind --collect-atstart=no \
        "--toggle-collect=*evaluate_operator*" \
        --callgrind-out-file="$out.callgrind" \
        "$0" "$operator" "$class" >"$out.log" 2>&1 || {
          printf "callgrind failed on %s %s; its log:\n" "$operator" "$class" >&2
          tail -20 "$out.log" >&2
          exit 255
        }
    ' "$binary" "$runs" "$run" <"$WORK/$label/cases.txt"
  done
  (cd "$src" && sha256sum "${MEASURED_SOURCES[@]}") >"$WORK/$label/sources.sha256"
}

measure before "$BEFORE_COMMIT"
measure after "$AFTER_COMMIT"

mkdir -p "$(dirname "$OUT")"
python3 -I - "$WORK" "$REPEATS" "$BEFORE_COMMIT" "$AFTER_COMMIT" \
  "$(valgrind --version)" "$(cd "$WORK/after/src" && rustc --version)" "$(uname -m)" \
  >"$OUT" <<'PY'
import json
import re
import sys

work, repeats, before_commit, after_commit, valgrind, rustc, arch = sys.argv[1:8]
repeats = int(repeats)
EVALUATIONS = 16
TOTALS = re.compile(r"^totals:\s+(\d+)\s*$", re.M)
RESULT = re.compile(r"^(\S+) (\S+) (\d+) (.*)$", re.M)


def instructions(path):
    match = TOTALS.search(open(path).read())
    if not match:
        raise SystemExit(f"no totals line in {path}")
    return int(match.group(1))


def result(path, operator, class_name):
    """The value the example printed, after checking that it ran the case."""
    for match in RESULT.finditer(open(path).read()):
        if match.group(1) == operator and match.group(2) == class_name:
            if int(match.group(3)) != EVALUATIONS:
                raise SystemExit(f"{path}: {match.group(3)} evaluations, not {EVALUATIONS}")
            return match.group(4)
    raise SystemExit(f"no result line for {operator} {class_name} in {path}")


def side(label, commit):
    cases = [line.split() for line in open(f"{work}/{label}/cases.txt") if line.strip()]
    operators = {}
    runs_agree = True
    for operator, class_name in cases:
        counts, values = [], []
        for run in range(1, repeats + 1):
            stem = f"{work}/{label}/runs/{operator}.{class_name}.run{run}"
            counts.append(instructions(stem + ".callgrind"))
            values.append(result(stem + ".log", operator, class_name))
        runs_agree = runs_agree and len(set(counts)) == 1 and len(set(values)) == 1
        entry = operators.setdefault(operator, {"instructions": {}, "values": {}})
        entry["instructions"][class_name] = counts[0]
        entry["values"][class_name] = values[0]
    rows = []
    for operator, entry in operators.items():
        distinct = sorted(set(entry["instructions"].values()))
        rows.append(
            {
                "operator": operator,
                "classes": len(entry["instructions"]),
                "distinct_counts": len(distinct),
                "fewest_instructions": distinct[0],
                "most_instructions": distinct[-1],
                "instructions": entry["instructions"],
            }
        )
    sources = {}
    for line in open(f"{work}/{label}/sources.sha256"):
        digest, path = line.split()
        sources[path] = digest
    return (
        {
            "label": label,
            "revision": "working tree" if commit == "WORKTREE" else commit,
            "source_sha256": sources,
            "operators_measured": len(rows),
            "operators_with_one_count": sum(1 for row in rows if row["distinct_counts"] == 1),
            "operators": rows,
        },
        runs_agree,
        {name: entry["values"] for name, entry in operators.items()},
    )


before, before_agree, before_values = side("before", before_commit)
after, after_agree, after_values = side("after", after_commit)
report = {
    "schema": "uo-kernel-operator-instructions-v1",
    "metric": (
        "callgrind instruction reads (Ir) inside the slot interpreter's evaluation of "
        "`return slot0 <operator> slot1` (`index`: `return array[slot0]`), inclusive of "
        "callees, summed over the evaluations of one process"
    ),
    "scope": (
        "instruction counts of one release build under callgrind; not a claim about "
        "cache or branch-predictor state, nor about machine code built elsewhere"
    ),
    "evaluations_per_run": EVALUATIONS,
    "repeats": repeats,
    "tools": {"valgrind": valgrind, "rustc": rustc, "arch": arch},
    "example": "crates/uo-core/examples/kernel_operator_classes.rs",
    "revisions": [before, after],
    "runs_agree": before_agree and after_agree,
    "same_values_before_and_after": before_values == after_values,
    "after_every_operator_has_one_count": (
        after["operators_with_one_count"] == after["operators_measured"]
    ),
}
json.dump(report, sys.stdout, indent=2)
sys.stdout.write("\n")
PY

printf 'wrote %s\n' "$OUT" >&2
python3 -I -c '
import json, sys
report = json.load(open(sys.argv[1]))
for revision in report["revisions"]:
    print(revision["label"], "operators with one count:", revision["operators_with_one_count"], "of", revision["operators_measured"])
print("runs agree:", report["runs_agree"], "| same values:", report["same_values_before_and_after"], "| after has one count per operator:", report["after_every_operator_has_one_count"])
sys.exit(0 if report["runs_agree"] and report["same_values_before_and_after"] and report["after_every_operator_has_one_count"] else 1)
' "$OUT"
