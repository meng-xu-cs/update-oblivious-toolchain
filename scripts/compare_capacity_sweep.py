#!/usr/bin/env python3
"""Compare two capacity-sweep reports of schema uo-capacity-sweep-v4.

    scripts/compare_capacity_sweep.py BASELINE CURRENT [options]

For each kind of call that both reports measured on the same backend, at the
same capacity and with the same number of stored keys, prints the counts that
changed and, for each timing, the baseline's median, the current one and
their ratio. By default it compares the largest capacity both reports have;
--capacity, --backend, --stored-keys and --operation select other rows, and
--all compares every row. The exit status is 0 whether or not anything moved:
the script reports, it does not judge.
"""

import argparse
import json
import sys

COUNTS = [
    "physical_reads",
    "physical_writes",
    "bytes_read",
    "bytes_written",
    "gas",
    "call_start_reads",
    "call_start_bytes",
    "witness_scan_records",
    "trace_json_bytes",
    "receipt_json_bytes",
    "evidence_json_bytes",
]

TIMINGS = [
    ("call", "p50_latency_ns"),
    ("runtime", "p50_runtime_ns"),
    ("staging", "p50_staging_ns"),
    ("load", "p50_load_ns"),
    ("execution", "p50_execution_ns"),
    ("witness", "p50_witness_ns"),
    ("proof objects", "p50_proof_objects_ns"),
    ("JSON", "p50_json_serialization_ns"),
]


def load(path):
    with open(path, encoding="utf-8") as handle:
        report = json.load(handle)
    if report.get("schema") != "uo-capacity-sweep-v4":
        sys.exit(f"{path}: schema {report.get('schema')!r} is not uo-capacity-sweep-v4")
    rows = {}
    for row in report["rows"]:
        if row.get("status") != "ok":
            continue
        key = (row["backend"], row["capacity"], row["stored_keys"], row["operation"])
        rows[key] = row
    return report, rows


def milliseconds(nanoseconds):
    return f"{nanoseconds / 1e6:.3f}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("baseline")
    parser.add_argument("current")
    parser.add_argument("--capacity", type=int, action="append")
    parser.add_argument("--backend", action="append")
    parser.add_argument("--stored-keys", type=int, action="append")
    parser.add_argument("--operation", action="append")
    parser.add_argument("--all", action="store_true", help="compare every common row")
    args = parser.parse_args()

    baseline, baseline_rows = load(args.baseline)
    current, current_rows = load(args.current)
    common = sorted(set(baseline_rows) & set(current_rows))
    if not common:
        sys.exit("the reports have no row in common")
    capacities = args.capacity
    if not capacities and not args.all:
        capacities = [max(key[1] for key in common)]

    print(f"baseline: {args.baseline} ({baseline['profile']}, counts {baseline['counts_sha256'][:12]})")
    print(f"current:  {args.current} ({current['profile']}, counts {current['counts_sha256'][:12]})")
    for name in ("warmup_rounds", "trials"):
        before, after = baseline["parameters"][name], current["parameters"][name]
        if before != after:
            print(f"note: {name} differs ({before} against {after})")
    only_baseline = len(set(baseline_rows) - set(current_rows))
    only_current = len(set(current_rows) - set(baseline_rows))
    if only_baseline or only_current:
        print(f"rows only in the baseline: {only_baseline}; only in the current report: {only_current}")

    compared = 0
    for key in common:
        backend, capacity, stored_keys, operation = key
        if capacities and capacity not in capacities:
            continue
        if args.backend and backend not in args.backend:
            continue
        if args.stored_keys and stored_keys not in args.stored_keys:
            continue
        if args.operation and operation not in args.operation:
            continue
        compared += 1
        before, after = baseline_rows[key], current_rows[key]
        print(f"\n{backend}, capacity {capacity}, {stored_keys} keys stored, {operation}")
        changed = [name for name in COUNTS if before.get(name) != after.get(name)]
        if changed:
            for name in changed:
                print(f"  {name}: {before.get(name)} -> {after.get(name)}")
        else:
            print("  counts: unchanged")
        for label, name in TIMINGS:
            old, new = before["timing"].get(name), after["timing"].get(name)
            if old is None or new is None:
                continue
            ratio = f"{new / old:.2f}x" if old else "n/a"
            print(f"  {label + ':':<15}{milliseconds(old):>12} ms -> {milliseconds(new):>12} ms  {ratio}")
        old, new = before["timing"]["p50_peak_rss_bytes"], after["timing"]["p50_peak_rss_bytes"]
        print(f"  {'peak RSS:':<15}{old / 2**20:>12.1f} MB -> {new / 2**20:>12.1f} MB")
    if not compared:
        sys.exit("no common row matches the selection")


if __name__ == "__main__":
    main()
