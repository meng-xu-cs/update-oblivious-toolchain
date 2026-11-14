#!/usr/bin/env bash
# Run the stash-occupancy report's full profile and write
# results/stash_occupancy_full.json.
#
#   scripts/run_stash_occupancy_full.sh
#
# The validation script runs the report's quick profile: one map and a few
# thousand node accesses, with the forced overflow. This is the profile the
# stash claim rests on: more than ten million node accesses of the private
# scheme's tree, on maps of 256, 1,024, 4,096 and 16,384 entries, under
# random, repeated-key and insert-and-delete workloads. It runs the
# runtime's own tree operations, with their eviction and compaction, over
# buckets in memory and without the cryptography, and counts the stash after
# every node access. It takes about three quarters of an hour on four cores.
# Its counts are a function of its seed, so they repeat on any machine. Run
# it when the stash cap, the eviction or the tree's operations change.
#
# UO_STASH_CAPACITIES and UO_STASH_NODE_ACCESSES override the maps and the
# node accesses of each cell; UO_RESULTS_DIR overrides the output directory.
# Needs cargo and python3 on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RESULTS_DIR="${UO_RESULTS_DIR:-results}"
OUT="$RESULTS_DIR/stash_occupancy_full.json"

for tool in cargo python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s not found on PATH\n' "$tool" >&2
    exit 1
  fi
done

# The probe prints the report it writes; the file is what this script keeps.
cargo run -q --release -p mplus-probe -- --only stash-occupancy-full --out-dir "$RESULTS_DIR" \
  >/dev/null

# A report with a stash the assumption does not predict, an overflow in the
# simulation, or an overflow that lost a block is written and then refused.
python3 -I - "$OUT" <<'CHECK'
import json
import sys

report = json.load(open(sys.argv[1]))
failed = [name for name, held in report["checks"].items() if held is not True]
print(
    f"{sys.argv[1]}: {report['total_node_accesses']} node accesses in "
    f"{len(report['cells'])} cells, largest stash {report['largest_stash']} of a cap of "
    f"{report['stash_cap']}"
)
if failed or report["accepted"] is not True:
    print("stash checks failed: " + ", ".join(sorted(failed)), file=sys.stderr)
    sys.exit(1)
CHECK
