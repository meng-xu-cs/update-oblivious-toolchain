# Evaluation Runbook for the Update-Oblivious Toolchain

This runbook is written for a local coding agent with Rust/Cargo, Lean/Lake, and enough disk/RAM to run compact and selected heavy validation modes. It focuses on adoption evidence: runtime cost, proof cost, artifact/evidence size, security sanity, and operational cost.

## 0. Evaluation outputs

Create a top-level evaluation directory for each run:

```bash
export RUN_ID="uo-eval-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "eval/$RUN_ID"/{logs,results,traces,time,csv,plots,artifacts,sidecars,negative}
```

The final output should include:

```text
eval/$RUN_ID/eval_summary.md
eval/$RUN_ID/csv/runtime_metrics.csv
eval/$RUN_ID/csv/proof_metrics.csv
eval/$RUN_ID/csv/artifact_sizes.csv
eval/$RUN_ID/csv/leakage_metrics.csv
eval/$RUN_ID/csv/adoption_scorecard.csv
eval/$RUN_ID/plots/*.png
eval/$RUN_ID/results*/
```

## 1. Install and verify prerequisites

```bash
rustup toolchain install 1.82.0
elan toolchain install leanprover/lean4:v4.30.0-rc2
sudo apt-get install -y jq time hyperfine python3 python3-venv git
```

Verify repository pins:

```bash
cat rust-toolchain.toml
cat proof/lean/lean-toolchain
rustc --version
cargo --version
(cd proof/lean && lean --version && lake --version)
```

Record hardware and OS:

```bash
uname -a > "eval/$RUN_ID/logs/uname.txt"
lscpu > "eval/$RUN_ID/logs/lscpu.txt" || true
free -h > "eval/$RUN_ID/logs/memory.txt" || true
df -h > "eval/$RUN_ID/logs/disk.txt" || true
```

## 2. Baseline validation

Run the project’s existing validation first:

```bash
UO_RESULTS_DIR="eval/$RUN_ID/results-baseline" ./scripts/run_validation.sh \
  > "eval/$RUN_ID/logs/run_validation.stdout" \
  2> "eval/$RUN_ID/logs/run_validation.stderr"
```

Run reproducibility for at least one focused report:

```bash
./scripts/check_probe_reproducibility.sh --only static-checks \
  > "eval/$RUN_ID/logs/repro_static.stdout" \
  2> "eval/$RUN_ID/logs/repro_static.stderr"
```

Extract baseline metrics:

```bash
jq '.proof_checking_cost_ms' "eval/$RUN_ID/results-baseline/reviewer_summary.json" \
  > "eval/$RUN_ID/results/proof_checking_cost_ms.json"
jq '.artifact_size_bytes' "eval/$RUN_ID/results-baseline/reviewer_summary.json" \
  > "eval/$RUN_ID/results/artifact_size_bytes.json"
jq '.runtime_overheads' "eval/$RUN_ID/results-baseline/reviewer_summary.json" \
  > "eval/$RUN_ID/results/runtime_overheads.json"
```

## 3. Benchmark matrix

Use the existing benchmarks:

```text
FixedSlotClassifier, AuthScan, RegistryCRUD, ConfidentialMixer, ERC20Lite, SingleAccessMap
```

Add or generate kernels for:

```text
private balance transfer
private allowance update/check
private registry lookup/update
membership/authentication scan
mixer deposit/withdraw
map-heavy multi-access update
abort-heavy public and declassified cases
```

Evaluate capacities:

```text
8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096
```

Evaluate backends when legal:

```text
raw-public baseline, full_scan, path_oram_local_posmap_v1
```

Evaluate workload parameters:

```text
occupancy: 0%, 25%, 50%, 90%
key distribution: uniform, hot-key, sequential
update type: insert, update, same-value update, no-op
history length: 1, 10, 100, 1000 calls
abort rate: 0%, 10%, 50%
secret pairs: same public inputs, different secret keys/values
```

## 4. Generate capacity/backend artifacts

Create `scripts/eval/generate_capacity_matrix.py`. It should:

1. Read `benches/raw/*.yaml` sidecars.
2. For every target capacity, copy the sidecar and patch every relevant state object capacity.
3. Set backend and `oram_scheme` consistently.
4. Emit `eval/$RUN_ID/csv/matrix.csv` with:

```text
case_id, benchmark, source, sidecar, backend, capacity, entrypoint, args_file, expected_policy
```

Then compile artifacts:

```bash
python3 scripts/eval/generate_capacity_matrix.py --out-dir "eval/$RUN_ID"

while IFS=, read -r case_id benchmark source sidecar backend capacity entrypoint args_file expected_policy; do
  [ "$case_id" = "case_id" ] && continue
  cargo run -q -p uo-solc -- \
    --source "$source" \
    --metadata "$sidecar" \
    --mode uo \
    --out "eval/$RUN_ID/artifacts/$case_id.json" \
    > "eval/$RUN_ID/logs/$case_id.compile.stdout" \
    2> "eval/$RUN_ID/logs/$case_id.compile.stderr" || \
    echo "$case_id,compile_failed" >> "eval/$RUN_ID/csv/failures.csv"
done < "eval/$RUN_ID/csv/matrix.csv"
```

## 5. Runtime measurement

Prefer a harness that calls the `uo_evm` crate API directly so arguments and call histories are controlled precisely. Create `scripts/eval/run_runtime_matrix.py` or a small Rust eval binary that:

- warms up each case;
- runs at least 30 measured repetitions;
- records wall-clock latency, CPU time, max RSS, trace metrics, return/status, and bytes/writes;
- supports multi-call histories and occupancy setup;
- writes one JSON per case and a consolidated CSV.

Example CLI fallback for simple cases:

```bash
/usr/bin/time -v cargo run -q -p uo-evm -- \
  --artifact "eval/$RUN_ID/artifacts/$case_id.json" \
  --entrypoint "$entrypoint" \
  --format trace \
  > "eval/$RUN_ID/traces/$case_id.json" \
  2> "eval/$RUN_ID/time/$case_id.txt"
```

Normalize metrics into `runtime_metrics.csv`:

```text
case_id,benchmark,backend,capacity,history_len,occupancy,abort_rate,
latency_ms_p50,latency_ms_p95,latency_ms_p99,cpu_ms,max_rss_kb,
gas_used,physical_reads,physical_writes,bytes_read,bytes_written,
boundary_events,normalized_page_events,controller_phase_count,aborted,return_policy,status_policy
```

## 6. Security sanity and negative tests

Run existing leakage/probe reports for every matrix slice, or extend `mplus-probe` to accept the generated matrix.

Required security sanity outputs:

```text
trace_equivalence.csv
mutual_information.csv
leakage_auc.csv
tamper_results.csv
negative_policy_results.csv
```

Negative-policy examples to add:

1. Secret-derived public return with `returns: public` must be rejected.
2. Secret-dependent `require` with `status: public` must be rejected.
3. Secret-derived public-state write with no public-state declassification must be rejected.
4. Secret-dependent public write predicate with no public-state declassification must be rejected.
5. `confidential:false` plus nonempty `secret_args` must be rejected after metadata-well-formedness is added.
6. Dynamic/state-dependent loop bound in proof-grade mode must be rejected.
7. Confidential state using raw backend must be rejected globally in UO mode.

For each negative test, record:

```text
test_id, expected_reject, actual_reject, error_contains, pass
```

## 7. Proof/checking and artifact-size measurement

Run compact proof validation on the generated/evaluation set:

```bash
UO_RESULTS_DIR="eval/$RUN_ID/results-compact" ./scripts/run_validation.sh
```

Run selected heavy validation under an explicit budget:

```bash
export UO_RESULTS_DIR="eval/$RUN_ID/results-heavy"
export UO_ARTIFACT_MODE=heavy
export UO_HEAVY_ARTIFACT_BUDGET_BYTES=${UO_HEAVY_ARTIFACT_BUDGET_BYTES:-21474836480}
./scripts/run_validation.sh
```

Normalize proof metrics into `proof_metrics.csv`:

```text
report, milliseconds, max_rss_kb, scenarios, pass, notes
```

Normalize artifact sizes into `artifact_sizes.csv`:

```text
case_id, artifact_json_bytes, runtime_witness_bytes, kernel_bundle_bytes,
trusted_kernel_bytes, shell_boundary_bytes, refinement_witness_bytes,
path_oram_certificate_bytes, fresh_coin_family_bytes, estimated_certificate_bytes
```

## 8. Operational cost measurement

Create `operational_costs.csv`:

```text
metric,value,unit,source
trusted_rust_runtime_loc,11403,non_empty_loc,reviewer_summary
outer_runtime_risk_loc,898,non_empty_loc,reviewer_summary
lean_theorem_checker_loc,103091,non_empty_loc,reviewer_summary
explicit_assumption_count,<fill>,count,claim_boundary/reviewer_summary
tee_attestation_time_ms,<fill>,ms,production_or_mock_measurement
quote_size_bytes,<fill>,bytes,production_or_mock_measurement
rollback_storage_bytes_per_object,<fill>,bytes,measurement
proof_evidence_bytes_per_call,<fill>,bytes,artifact_sizes
sidecar_loc_per_source_loc,<fill>,ratio,generated_matrix
capacity_headroom_ratio,<fill>,ratio,workload
```

If TEE deployment is not implemented locally, mark TEE rows as `not_measured` rather than omitting them.

## 9. Analysis formulas

For each backend/capacity:

```text
latency_ratio = latency_uo / latency_baseline
write_ratio   = physical_writes_uo / physical_writes_baseline
byte_ratio    = bytes_written_uo / bytes_written_baseline
gas_ratio     = gas_used_uo / gas_used_baseline
proof_ratio   = proof_evidence_bytes / artifact_json_bytes
capacity_headroom_ratio = public_capacity / max_observed_occupancy
```

Fit scaling curves:

```text
log(metric) ~ alpha + beta * log(capacity)
```

Interpretation:

- `beta ≈ 1`: linear capacity scaling.
- `beta ≈ log-like / < 0.5`: potentially scalable.
- `beta > 1`: superlinear; inspect before adoption.
- explosive estimated artifact sizes: proof-family strategy is not practical at that capacity.

## 10. Adoption scorecard

Create `adoption_scorecard.csv`:

```text
workload,target_capacity,backend,security_pass,latency_pass,storage_pass,
proof_pass,ops_pass,unresolved_critical_findings,recommendation,notes
```

Recommended categories:

```text
adopt: all gates pass and no unresolved critical/high correctness gaps
pilot: security sanity passes, costs acceptable at target capacity, but some medium issues remain
research_only: correctness architecture promising but cost or trust gaps block production
reject_for_now: target workload/capacity fails security or cost gates
```

Suggested default gates:

```text
mutual_information_bits <= 0.01 for every UO observable metric
0.49 <= leakage_auc <= 0.51 for every UO observable metric
trace_equivalence == pass for all same-public/different-secret pairs
p95 latency <= application SLO
bytes_written_per_call <= storage/network budget
proof validation time <= CI/release budget
proof evidence retention <= storage budget
capacity_headroom_ratio <= chosen max, e.g. 4x
no unresolved critical findings T1/T2/T3/T4/T5 for production
```

## 11. Final report template

The local coding agent should produce `eval_summary.md` with:

```markdown
# UO Toolchain Evaluation Summary

## Environment
- commit/hash:
- Rust:
- Lean/Lake:
- CPU/RAM:

## Executive recommendation
adopt / pilot / research_only / reject_for_now

## Security sanity
- trace equivalence:
- MI:
- AUC:
- negative policy tests:

## Runtime cost
- capacity scaling table
- latency ratios
- write/byte/gas ratios

## Proof and artifact cost
- checker times
- largest materialized artifacts
- largest estimated artifacts
- evidence per call

## Operational cost
- TCB LOC
- assumptions
- TEE/rollback/freshness/evidence retention

## Practical capacity ceiling
- full_scan:
- path_oram_local_posmap_v1:

## Open blockers
- correctness blockers
- practicality blockers

## Recommendation rationale
```
