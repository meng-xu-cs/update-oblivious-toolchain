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
  rollback, the quick profiles of the AVL map replay and of the tape
  substitution, the storage boundary, acceptance, claim consistency and
  claim status) and fails if any differs from the committed one.
- The two reports that test the runtime against a model have a quick and a
  full profile each, with one schema per report
  (`uo-path-oram-avl-map-replay-v2`, `uo-tape-substitution-v1`). The quick
  ones run from the debug build, in the validation script and in CI: 2,400
  operations on AVL maps of at most 31 nodes into
  `results/path_oram_avl_map_replay.json`, and 14 calls on 3 other deployment
  seeds each into `results/tape_substitution.json`. The full ones run from the
  release build, in the validation script only, because the runtime is about
  twenty times slower in a debug build: 7,398 operations on maps of up to
  2,048 nodes into `results/path_oram_avl_map_replay_full.json` (about four
  minutes on four cores), and 84 calls on 16 other deployment seeds each into
  `results/tape_substitution_full.json` (about eight minutes). All four are
  functions of their seeds, and each states its counts.
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
- The stash-occupancy report has two profiles with one schema
  (`uo-stash-occupancy-v1`). `run_validation.sh` runs the quick one into
  `results/stash_occupancy.json` from a release build: a few thousand node
  accesses of a simulated map of 256 entries, and a stash overflow forced on
  the runtime, which must fail the call and lose nothing.
  `scripts/run_stash_occupancy_full.sh` runs the full one into
  `results/stash_occupancy_full.json`: more than ten million node accesses on
  maps of 256 to 16,384 entries under three workloads, about 45 minutes on
  four cores. Both are functions of their seed. Run the full one when the
  stash cap, the eviction or the tree's operations change.
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
  and every map from 1 to 16,384 entries filled to every level. The quick
  profile keeps its maps' sealed records in memory. The full profile keeps
  them in files and syncs every commit, so a call's latency includes its
  persistence, which the report gives as a part of its own
  (`p50_persistence_ns`, `p50_persisted_bytes`; `UO_SWEEP_STORAGE` is
  `memory`, `files` or `files_synced`, and `provenance.storage` says which
  ran). Where the records are kept changes no count. It takes
  about an hour on four cores and wants the machine to itself, so
  `run_validation.sh` does not run it; run it when a change claims a saving.
  `scripts/compare_capacity_sweep.py` compares two reports, and
  `review/2026-11-external-review/capacity_sweep_baseline.json` is the full
  profile from before the optimizations that review asked for; its gas is
  that of cost model v1, which charged no reads. The committed full report
  was measured when Issues 30 to 42 and 51 to 59 of that review were in,
  and its `provenance` names the build that measured it and where the
  records were kept. The latencies of two reports compare only if one
  machine in one state measured both, so the review directory also holds
  four controls, for Issues 36 to 38, for the stash cap of Issue 40, for
  the storage adapter of Issue 41 and for the eviction networks of Issue
  47: the largest maps measured on the code before the change and on the
  code after it, one run after the other. No control covers Issues 51 to
  59 (see [`path-oram.md`](./path-oram.md)).
- The matched baselines have two profiles with one schema
  (`uo-matched-baselines-v1`). `run_validation.sh` runs the quick one into
  `results/matched_baselines.json` from a release build: three maps, with
  32-byte keys and values, with 20-byte keys and with 1-byte values, on the
  full scan and both Path ORAM schemes at seven capacities from 16 to 16,384
  entries, filled to two keys and, up to 1,024 entries, to half and all of
  their capacity (about a minute). The full one fills every map to every
  level into `results/matched_baselines_full.json`
  (`mplus-probe --only matched-baselines-full`, about 27 minutes on four
  cores, most of them filling the trees). Both count bytes, which are a
  function of the programs and the capacities and repeat on every run and
  machine, and neither times anything.

## Index

| Question | Result files |
| --- | --- |
| Leakage: do admitted artifacts remove the update-class channels? | `leakage_auc.json` and `mutual_information.json` (per-metric AUC and mutual information on the exact backends and on both Path ORAM schemes, the rows `oram` and `oram_private_posmap`, with raw-backend positive controls built with `--features insecure-eval-raw`); `trace_equivalence.json` (per benchmark pair, opcode, logical and physical trace comparisons, equality being an obligation on the exact backends and not on the Path ORAM route, plus a raw positive control; for an `encrypted_to_client` entrypoint, what its runs show of the return channel) |
| Correctness | `correctness.json` (differential runs against the raw baseline), `abort_rollback.json` (aborting and committing calls on the exact backend and on both Path ORAM schemes), and the model columns of `trace_equivalence.json` (each run's public outcome and final public state against their Lean models, and the exact store's encoding on the exact backends) |
| Does the runtime's Path ORAM follow its Lean models? Tested, not proved | `path_oram_avl_map_replay.json` and `path_oram_avl_map_replay_full.json` (random operations on the runtime's AVL map replayed on the Lean model: every result, every node access's kind, every size and the recorded trees, on maps of up to 31 and up to 2,048 nodes, with the map's pointers, free list and stash checked after every operation); `tape_substitution.json` and `tape_substitution_full.json` (calls of seven kinds on maps of both schemes, each run on other deployment seeds and compared, whole, with the representative run under that run's own tape: 42 and 1,344 tapes) |
| Runtime and storage cost | `overheads.json` (modeled gas, physical reads and writes, bytes moved, trace and artifact sizes per benchmark and backend) |
| Scalability | `capacity_sweep.json` and `capacity_sweep_full.json` (one map of 1 to 16,384 entries on every backend, at five occupancy levels: the traced counts of seven kinds of call, the untraced reads in the decode of the position-map witness, which the runtime keeps from call to call, with an audit of the kept witness after every level, read/write mixes computed and executed, break-even capacities, and release-build latencies with medians, 95th percentiles and bootstrap intervals, split into staging, loading, the runtime's own work, witnesses, proof objects, JSON serialization and Lean's check of a sampled call, with peak resident memory and evidence sizes) |
| Which backend moves the fewest bytes at a map's key and value widths, and does the compiler's backend planner choose it? | `matched_baselines.json` and `matched_baselines_full.json` (three maps of different key and value widths on every backend at seven capacities and up to three occupancy levels: each call's bytes against the planner's model, the planner's choice against the measured calls at six shares of reads, maps compiled with `backend: auto`, the break-even capacities of each width, and each backend's modeled enclave memory) |
| Does a call's public-state snapshot cost more as public objects it does not load grow? | `public_state.json` (a contract with a public array of 16 to 16,384 sealed slots, a public cell and a confidential cell: for a call on each, the public objects its snapshots decode and the bytes of their state, which do not depend on the array's size for the calls that do not load it, and the time of each call) |
| What crosses the storage boundary, and does a runtime start again from its files? | `storage_boundary.json` (every benchmark on every sealed backend: the log a storage adapter keeps of the sealed records the runtime opens and seals against the reads and writes of each call's trace, one for one; a call dropped after it handed records over; a record refused before its nonce is reserved; and each benchmark restarted from a store in files, which must answer as before and repeat no nonce) |
| How full does the private scheme's stash get, and what does an overflow do? | `stash_occupancy.json` and `stash_occupancy_full.json` (the stash counted after every node access of a simulation that runs the runtime's tree operations without the cryptography, against the assumed tail; and a stash overflow forced on the runtime: the call fails, the committed ciphertext is unchanged, and every stored key reads back) |
| Cost of a tree node access | `tree_eviction_instructions.json` (callgrind instruction counts and masked node moves per node access of the private scheme, before and after the eviction networks of Issue 47 of the external review) |
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
