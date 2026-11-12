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

## Index

| Question | Result files |
| --- | --- |
| Leakage: do admitted artifacts remove the update-class channels? | `leakage_auc.json` and `mutual_information.json` (per-metric AUC and mutual information, with raw-backend positive controls built with `--features insecure-eval-raw`); `trace_equivalence.json` (per benchmark pair, opcode, logical and physical trace comparisons, equality being an obligation on the exact backends and not on the Path ORAM route, plus a raw positive control) |
| Correctness | `correctness.json` (differential runs against the raw baseline), `abort_rollback.json`, `path_oram_avl_map_replay.json` (runtime AVL map operations replayed against the Lean model), and the model columns of `trace_equivalence.json` (each run's public outcome and final public state against their Lean models, and the exact store's encoding on the exact backends) |
| Runtime and storage cost | `overheads.json` (modeled gas, physical reads and writes, bytes moved, trace and artifact sizes per benchmark and backend) |
| Scalability | `capacity_sweep.json` (one map of 1 to 16,384 entries on every backend: costs, read/write mixes, break-even capacities, and release-build latencies split into proof-object and runtime work) |
| Cost of a tree node access | `tree_eviction_instructions.json` (callgrind instruction counts per node access of the private scheme, before and after the eviction rewrite) |
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
