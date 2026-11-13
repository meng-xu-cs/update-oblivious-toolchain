# Evaluation Results

This document indexes the toolchain's evaluation results: which file under
`results/` answers which evaluation question, and which command produces it.
The numbers live in the result files; the topic documents discuss them
([`path-oram.md`](./path-oram.md) for the Path ORAM costs and the capacity
sweep, [`claim-boundary.md`](./claim-boundary.md) for what the checks
establish and what they do not).

## Producing the Results

- `scripts/run_validation.sh` regenerates the committed `results/` bundle.
  `results/reproducibility_manifest.json` records the Rust and Lean toolchains
  and the SHA-256 of every file in the bundle. CI regenerates the reports it
  can afford (static checks, the Lean assumption budget, correctness, abort
  rollback, AVL map replay, acceptance, claim consistency and claim status) and
  fails if any differs from the committed one.
- `scripts/measure_tree_eviction_instructions.sh` writes
  `results/tree_eviction_instructions.json`. `run_validation.sh` does not
  regenerate it: the script exports two revisions, builds each in release and
  runs the capacity sweep under callgrind, which needs valgrind and takes about
  12 minutes on four cores.
- `scripts/measure_kernel_operator_instructions.sh` writes
  `results/kernel_operator_instructions.json`, which `run_validation.sh` does
  not regenerate either: it builds the example
  `crates/uo-core/examples/kernel_operator_classes.rs` in release at the last
  commit whose kernel operators branched on their operands and in the working
  tree, and counts under callgrind the instructions of one evaluation of each
  operator on every class of operands. It needs valgrind and takes about two
  minutes on four cores.
- The capacity sweep has two profiles with one schema
  (`uo-capacity-sweep-v4`). `run_validation.sh` runs the quick one into
  `results/capacity_sweep.json`: one warmup round and two measured rounds of
  each kind of call, workloads of five calls, and maps filled to their
  occupancy levels (2 keys, and 25%, 50%, 90% and 100% of the capacity) up to
  256 entries; larger maps hold 2 keys. Its counts repeat on every run and
  machine, and its latencies are a smoke test.
  `scripts/run_capacity_sweep_full.sh` runs the full one into
  `results/capacity_sweep_full.json`: five warmup rounds and 30 measured
  rounds of each kind of call, workloads of 20 calls at each read fraction,
  and every map from 1 to 16,384 entries filled to every level. It takes
  about an hour and a half on four cores and wants the machine to itself, so
  `run_validation.sh` does not run it; run it when a change claims a saving.
  `scripts/compare_capacity_sweep.py` compares two reports, and
  `review/2026-11-external-review/capacity_sweep_baseline.json` is the full
  profile from before the optimizations that review asked for. Until a
  change claims a saving the committed full report is that baseline, and
  its `provenance` names the build that measured it: its latencies and
  traced counts stand, and its gas is that of cost model v1, which charged
  no reads.

## Index

| Question | Result files |
| --- | --- |
| Leakage: do admitted artifacts remove the update-class channels? | `leakage_auc.json` and `mutual_information.json` (per-metric AUC and mutual information on the exact backends and on both Path ORAM schemes, the rows `oram` and `oram_private_posmap`, with raw-backend positive controls built with `--features insecure-eval-raw`); `trace_equivalence.json` (per benchmark pair, opcode, logical and physical trace comparisons, equality being an obligation on the exact backends and not on the Path ORAM route, plus a raw positive control) |
| Correctness | `correctness.json` (differential runs against the raw baseline), `abort_rollback.json` (aborting and committing calls on the exact backend and on both Path ORAM schemes), `path_oram_avl_map_replay.json` (runtime AVL map operations replayed against the Lean model), and the model columns of `trace_equivalence.json` (each run's public outcome and final public state against their Lean models, and the exact store's encoding on the exact backends) |
| Runtime and storage cost | `overheads.json` (modeled gas, physical reads and writes, bytes moved, trace and artifact sizes per benchmark and backend) |
| Scalability | `capacity_sweep.json` and `capacity_sweep_full.json` (one map of 1 to 16,384 entries on every backend, at five occupancy levels: the traced counts of seven kinds of call, the untraced reads at a call's start and in its witness snapshots, read/write mixes computed and executed, break-even capacities, and release-build latencies with medians, 95th percentiles and bootstrap intervals, split into staging, loading, the runtime's own work, witnesses, proof objects, JSON serialization and Lean's check of a sampled call, with peak resident memory and evidence sizes) |
| Cost of a tree node access | `tree_eviction_instructions.json` (callgrind instruction counts per node access of the private scheme, before and after the eviction rewrite) |
| Do the kernel's operators branch on their operands? | `kernel_operator_instructions.json` (callgrind instruction counts of one evaluation of each binary operator of the confidential kernel, and of an array index's conversion, for every class of operands, before and after the operators were made branch-free), with `kernel_operators_do_not_branch_on_operands` in `runtime_boundary_validation.json` for the source |
| Verification and TCB cost | `reviewer_summary.json` (proof-checking time per report, proof-artifact size budget, trusted line counts), `tamper_validation.json`, `lean_assumption_budget.json`, `static_checks.json` (including the kernel admission of every confidential entrypoint) |
| Theorem instances and runtime-to-theorem bridges | `bridge_validation.json`, `pathoram_pair_validation.json`, `canonical_pathoram_pair_validation.json`, `fresh_coin_validation.json`, `pathoram_hidden_validation.json`, and the `*_boundary_validation.json` and `*_refinement*_validation.json` reports |
| Language surface and porting effort | `admission_matrix.json` (accepted and rejected source features); the benchmark sources and sidecars under `benches/raw/` |
| Claims | `claim_status.json` and `claim_status.md`, `claim_consistency.json`, `claim_artifact_manifest.json`, `acceptance.json` |
| Bundle identity | `reproducibility_manifest.json`, `artifact_configuration.json` |

## Not in This Repository

The paper's evidence that the `M+` observer exists in deployed systems (the
Oasis Sapphire localnet attack, the SEV-SNP campaign, and the OpenSSL,
BoringSSL, AWS-LC and Mbed TLS audits) is not toolchain output. It stays with
the paper, under `docs/reporting/` in the paper repository (`paper-uop`).
