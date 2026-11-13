#!/usr/bin/env bash
# Run the capacity sweep's full profile and write
# results/capacity_sweep_full.json.
#
#   scripts/run_capacity_sweep_full.sh
#
# The validation script runs the sweep's quick profile, whose latencies are a
# smoke test. This is the profile a latency claim rests on: every map from 1
# to 16,384 entries on the full scan and on both Path ORAM schemes, filled to
# 2 keys and to 25%, 50%, 90% and 100% of its capacity, and at each level 30
# measured rounds of every kind of call after 5 warmup rounds, a workload of
# 20 calls at each read fraction, and Lean's check of one call of each kind.
# It takes about an hour on four cores, most of it on the two largest maps,
# and it should have the machine to itself. Run it when a
# change claims a saving, and compare with the baseline committed with the
# external review:
#
#   scripts/compare_capacity_sweep.py \
#     review/2026-11-external-review/capacity_sweep_baseline.json \
#     results/capacity_sweep_full.json
#
# UO_SWEEP_* overrides the grid, as for the quick profile; UO_RESULTS_DIR
# overrides the output directory. Needs cargo, python3, and lean and lake on
# PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RESULTS_DIR="${UO_RESULTS_DIR:-results}"
OUT="$RESULTS_DIR/capacity_sweep_full.json"

for tool in cargo python3 lean lake; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$tool" >&2
    exit 1
  fi
done

# The probe prints the report it writes; the file is what this script keeps.
cargo run -q --release -p mplus-probe -- --only capacity-sweep-full --out-dir "$RESULTS_DIR" \
  >/dev/null

# A report with a cell it could not measure, or with a count that moved
# between trials, occupancy levels or the kinds of call of one entrypoint, is
# written and then refused.
python3 -I - "$OUT" <<'CHECK'
import json
import sys

report = json.load(open(sys.argv[1]))
failed = [name for name, held in report["count_checks"].items() if held is not True]
print(
    f"{sys.argv[1]}: {len(report['rows'])} operation rows, "
    f"{len(report['workloads'])} workload rows, counts_sha256 {report['counts_sha256']}"
)
if failed:
    print("count checks failed: " + ", ".join(sorted(failed)), file=sys.stderr)
    sys.exit(1)
CHECK
