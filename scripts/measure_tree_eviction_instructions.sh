#!/usr/bin/env bash
# Count, with callgrind, the instructions the private Path ORAM scheme spends
# per tree node access at two revisions, and write the comparison to
# results/tree_eviction_instructions.json.
#
#   scripts/measure_tree_eviction_instructions.sh [BEFORE_REV [AFTER_REV]]
#
# BEFORE_REV defaults to 9522bd5, the last commit before a node access evicted
# its stash bucket by bucket with in-place masked moves (4b71895); AFTER_REV
# defaults to HEAD. Each revision is exported with `git archive` into a scratch
# directory, its mplus-probe is built in release, and the capacity sweep runs
# under callgrind on one map capacity (UO_SWEEP_CAPACITIES, default 4096) with
# one trial, UO_MEASURE_REPEATS times (default 2). A revision whose sweep has
# occupancy levels, workloads and Lean checks runs none of them: two stored
# keys and one call of each kind. The report gives, per
# revision and run, the calls and inclusive instruction counts (Ir) of the
# tree's node access (`tree_access`) and of the eviction, stash and copy
# functions under it, the counts per node access, and the before/after ratios
# per node access; it states whether the repeated runs counted the same.
#
# Needs git, cargo, valgrind and python3, and lean and lake on PATH (the probe
# records their versions in its reproducibility manifest). Set UO_KEEP_WORK=1
# to keep the scratch directory (sources, builds and callgrind outputs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BEFORE_REV="${1:-9522bd5}"
AFTER_REV="${2:-HEAD}"
CAPACITY="${UO_SWEEP_CAPACITIES:-4096}"
REPEATS="${UO_MEASURE_REPEATS:-2}"
OUT="${UO_RESULTS_DIR:-results}/tree_eviction_instructions.json"

for tool in git cargo valgrind python3 lean lake; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$tool" >&2
    exit 1
  fi
done
if [[ ! "$CAPACITY" =~ ^[0-9]+$ ]]; then
  printf 'UO_SWEEP_CAPACITIES must be one capacity, found `%s`\n' "$CAPACITY" >&2
  exit 1
fi
if [[ ! "$REPEATS" =~ ^[1-9][0-9]*$ ]]; then
  printf 'UO_MEASURE_REPEATS must be a positive integer, found `%s`\n' "$REPEATS" >&2
  exit 1
fi

BEFORE_COMMIT="$(git rev-parse --verify "${BEFORE_REV}^{commit}")"
AFTER_COMMIT="$(git rev-parse --verify "${AFTER_REV}^{commit}")"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/uo-eviction-instructions.XXXXXX")"
cleanup() {
  if [[ "${UO_KEEP_WORK:-0}" == "1" ]]; then
    printf 'kept scratch directory %s\n' "$WORK" >&2
  else
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

measure() {
  local label="$1" commit="$2"
  local src="$WORK/$label/src" target="$WORK/$label/target"
  mkdir -p "$src"
  git archive "$commit" | tar -x -C "$src"
  printf '[%s] building mplus-probe at %s in release\n' "$label" "${commit:0:12}" >&2
  (cd "$src" && CARGO_TARGET_DIR="$target" cargo build -q --release -p mplus-probe)
  local run
  for run in $(seq 1 "$REPEATS"); do
    printf '[%s] callgrind run %s of %s at capacity %s\n' "$label" "$run" "$REPEATS" "$CAPACITY" >&2
    (
      cd "$src"
      UO_SWEEP_CAPACITIES="$CAPACITY" UO_SWEEP_TRIALS=1 UO_SWEEP_WARMUPS=0 \
        UO_SWEEP_OCCUPANCY_MAX_CAPACITY=0 UO_SWEEP_WORKLOAD_CALLS=0 \
        UO_SWEEP_LEAN_CAPACITIES=0 \
        valgrind --tool=callgrind --callgrind-out-file="$WORK/$label/run$run.callgrind" \
        "$target/release/mplus-probe" --only capacity-sweep --out-dir "$WORK/$label/run$run-out" \
        >"$WORK/$label/run$run.log" 2>&1
    ) || {
      printf '[%s] callgrind run %s failed; last lines of its log:\n' "$label" "$run" >&2
      tail -20 "$WORK/$label/run$run.log" >&2
      exit 1
    }
  done
}

measure before "$BEFORE_COMMIT"
measure after "$AFTER_COMMIT"

mkdir -p "$(dirname "$OUT")"
python3 -I - "$WORK" "$REPEATS" "$BEFORE_COMMIT" "$AFTER_COMMIT" "$CAPACITY" \
  "$(valgrind --version)" "$(cd "$WORK/after/src" && rustc --version)" "$(uname -m)" \
  >"$OUT" <<'PY'
import json
import re
import sys
from collections import defaultdict

work, repeats, before_commit, after_commit, capacity, valgrind, rustc, arch = sys.argv[1:9]
repeats = int(repeats)

PREFIX = "uo_evm::oram::generated_oram_codecs::"
# The tree's node access and the functions under it whose cost the eviction
# rewrite changed (evict_tree_path is inlined into tree_access in release).
FUNCTIONS = [
    ("tree_access", PREFIX + "tree_access"),
    ("evict_bucket", PREFIX + "TreeStash::evict_bucket"),
    ("compact", PREFIX + "TreeStash::compact"),
    ("assign_tree_node", PREFIX + "assign_tree_node"),
]
NAME_REF = re.compile(r"^\((\d+)\)(?:\s+(.*))?$")
HASH_SUFFIX = re.compile(r"::h[0-9a-f]{16}$")


def parse(path):
    """Self cost, cost of the calls made, and calls received, per function."""
    names = {}
    self_ir = defaultdict(int)
    callee_ir = defaultdict(int)
    calls = defaultdict(int)
    current = callee = pending = None

    def resolve(value):
        match = NAME_REF.match(value)
        if not match:
            return HASH_SUFFIX.sub("", value)
        ident, name = match.groups()
        if name is not None:
            names[ident] = HASH_SUFFIX.sub("", name)
        return names[ident]

    with open(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            if line[0].isdigit() or line[0] in "+-*":
                fields = line.split()
                cost = int(fields[1]) if len(fields) > 1 else 0
                if pending is not None:
                    callee_ir[current] += cost
                    calls[pending[0]] += pending[1]
                    pending = None
                else:
                    self_ir[current] += cost
                continue
            key, sep, value = line.partition("=")
            if not sep:
                continue
            if key == "fn":
                current = resolve(value)
            elif key == "cfn":
                callee = resolve(value)
            elif key == "calls":
                pending = (callee, int(value.split()[0]))
    return self_ir, callee_ir, calls


def per_access(value, accesses):
    return round(value / accesses, 1) if accesses else None


revisions = []
for label, commit in (("before", before_commit), ("after", after_commit)):
    runs = []
    for run in range(1, repeats + 1):
        self_ir, callee_ir, calls = parse(f"{work}/{label}/run{run}.callgrind")
        accesses = calls[FUNCTIONS[0][1]]
        functions = {}
        for key, name in FUNCTIONS:
            inclusive = self_ir[name] + callee_ir[name]
            functions[key] = {
                "calls": calls[name],
                "inclusive_ir": inclusive,
                "inclusive_ir_per_node_access": per_access(inclusive, accesses),
            }
        runs.append({"node_accesses": accesses, "functions": functions})
    revisions.append(
        {
            "label": label,
            "commit": commit,
            "runs": runs,
            "runs_agree": all(run == runs[0] for run in runs),
        }
    )

before, after = (revision["runs"][0] for revision in revisions)
ratios = {}
for key, _ in FUNCTIONS:
    old = before["functions"][key]["inclusive_ir_per_node_access"]
    new = after["functions"][key]["inclusive_ir_per_node_access"]
    ratios[key] = round(old / new, 2) if old and new else None

report = {
    "schema": "uo-tree-eviction-instructions-v1",
    "metric": "callgrind instruction reads (Ir), inclusive of callees",
    "workload": {
        "command": "mplus-probe --only capacity-sweep (release build)",
        "UO_SWEEP_CAPACITIES": int(capacity),
        "UO_SWEEP_TRIALS": 1,
        "scheme": "path_oram_private_posmap_v1",
        "note": (
            "SingleAccessMap read and put on every backend of the sweep; the "
            "counts below are those of the private scheme's tree functions, "
            "and node_accesses is the number of calls to tree_access"
        ),
    },
    "tools": {"valgrind": valgrind, "rustc": rustc, "arch": arch},
    "repeats": repeats,
    "revisions": revisions,
    "before_over_after_per_node_access": ratios,
}
json.dump(report, sys.stdout, indent=2)
sys.stdout.write("\n")
PY

printf 'wrote %s\n' "$OUT" >&2
python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1])); print(json.dumps(r["before_over_after_per_node_access"]), "runs agree:", [v["runs_agree"] for v in r["revisions"]])' "$OUT"
