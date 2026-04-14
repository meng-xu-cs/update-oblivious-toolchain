# Final-Phase Checklist

This checklist is the concrete endgame for the current repository. It is
strictly aligned with the proof-grade SGX/TEE boundary already documented in
`docs/formal-proof-plan.md` and `docs/implementation-roadmap.md`.

Status labels:

- `cleared`: implemented and rechecked in the current artifact
- `active`: started, but not yet sufficient for the final claim
- `open`: still required before the repo can honestly claim end-to-end
  proof-grade completion under the runbook standard

## Cleared

- `cleared` Checked runtime refinement witnesses for theorem-backed backends.
  Evidence:
  `proof/lean/CheckRuntimeWitness.lean`,
  `results/witness_validation.json`.
  The validator now accepts the exact-UO benchmark witnesses plus the concrete
  `SingleAccessMap` path-ORAM witnesses.

- `cleared` Checked seeded path-ORAM witness families.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `proof/lean/UOToolchain/RuntimeCoinsJson.lean`,
  `proof/lean/CheckRuntimeWitnessFamily.lean`,
  `results/seeded_witness_validation.json`.
  The runtime now emits a first-class seeded family artifact, Lean imports and
  validates that family, and the probe exercises it on seeded `put` and `add`
  path-ORAM executions.

- `cleared` Default Lean build now materializes theorem-facing checkers.
  Evidence:
  `proof/lean/lakefile.lean`.
  `lake build` now builds both `checkRuntimeWitness` and
  `checkRuntimeWitnessFamily`, so the evaluation harness no longer depends on a
  separate manual executable build step.

- `cleared` Checked theorem-tight paired path-ORAM certificates for concrete
  class-pair workloads.
  Evidence:
  `runtime/uo-evm/src/engine.rs`,
  `proof/lean/UOToolchain/RuntimePathOramPairJson.lean`,
  `proof/lean/CheckPathOramPairCertificate.lean`,
  `results/pathoram_pair_validation.json`.
  The runtime now emits the exact public ORAM access-counter state needed by
  the theorem boundary, the probe materializes class0/class1 pair certificates
  for seeded `SingleAccessMap` path-ORAM runs, and the Lean import layer proves
  `checkValid = true ↔ Valid` for both the seeded-family and paired-certificate
  validators instead of relying on an executable-only checker.

- `cleared` Theorem-facing validation scope is explicit about exclusions.
  Evidence:
  `probe/mplus-probe/src/lib.rs`,
  `results/witness_validation.json`.
  Legacy surrogate ORAM scenarios remain in the broader benchmark and leakage
  reports, but they are now explicitly excluded from the Lean witness validators
  instead of being ambiguously mixed into the proof-facing checks.

- `cleared` The public SGX/controller observer now has a standalone theorem-facing
  certificate exported directly from `ExecutionTrace`.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `proof/lean/CheckRuntimeControllerCertificate.lean`,
  `results/controller_observer_validation.json`.
  The runtime now exports a controller-observer certificate containing
  `public_outcome`, exact `boundary_schedule`, `controller_shape`,
  `normalized_micro_trace`, and the runtime controller certificate itself,
  without going through the hidden runtime-witness extractor. Lean validates
  that certificate directly for the current theorem-backed benchmark set, so
  the public SGX/controller path is now separated cleanly from the remaining
  hidden-witness closure work.

- `cleared` The hidden Path-ORAM state argument now has a standalone
  theorem-facing certificate exported directly from `ExecutionTrace`.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `proof/lean/CheckRuntimePathOramHiddenCertificate.lean`,
  `results/pathoram_hidden_validation.json`.
  The runtime now exports a direct Path-ORAM hidden-state certificate carrying
  the runtime trace slice, public ORAM object configuration, public leaf
  scaffold, hidden leaf schedule, hidden position-map states, and transition
  certificates. Lean validates that certificate independently of the full
  runtime-witness extractor by reconstructing the public scaffold from the
  logical trace, replaying the hidden transitions, and matching the hidden leaf
  schedule against the observed bucket trace. The full runtime witness is now
  assembled from the standalone public controller certificate plus this
  standalone hidden Path-ORAM certificate.

- `cleared` The concrete runtime now realizes the exact canonical fresh-coin
  family required by the theorem-facing Path-ORAM witness interface.
  Evidence:
  `runtime/uo-evm/src/oram.rs`,
  `runtime/uo-evm/src/objects.rs`,
  `runtime/uo-evm/src/engine.rs`,
  `probe/mplus-probe/src/lib.rs`,
  `results/fresh_coin_validation.json`.
  The runtime now supports call-scoped injected Path-ORAM leaf-coin tapes,
  the probe enumerates the full canonical fresh-coin seed space directly from
  the public scaffold, and the Lean checker validates the resulting witness
  family for both theorem-backed `SingleAccessMap` scenarios. The repaired
  theorem-facing boundary now reaches full coverage for both
  `put(bytes32,uint256)` with `256` seeds and `add(bytes32,uint256)` with
  `4096` seeds. The legacy `runtime_seed` path remains available as a replay /
  seeded-family handle, but it is no longer the mechanism used to realize the
  theorem-tight fresh-coin family.

- `cleared` Checked theorem-tight canonical fresh-coin paired Path-ORAM
  certificates for the concrete benchmark pair workloads.
  Evidence:
  `probe/mplus-probe/src/lib.rs`,
  `proof/lean/UOToolchain/RuntimeCanonicalPathOramPairJson.lean`,
  `proof/lean/CheckCanonicalPathOramPairCertificate.lean`,
  `results/canonical_pathoram_pair_validation.json`.
  The probe now materializes benchmark-specific canonical fresh-coin pair
  certificates with one common public observer for the theorem-backed
  `SingleAccessMap` Path-ORAM vehicle, and Lean validates that observer
  projection directly for the full `256`-seed `put(bytes32,uint256)` family
  pair and full `4096`-seed `add(bytes32,uint256)` family pair.

- `cleared` Removed the hidden Path-ORAM position-map ordering assumption from
  the Lean theorem-facing checker.
  Evidence:
  `proof/lean/UOToolchain/RuntimeRefinement.lean`,
  `results/pathoram_hidden_validation.json`,
  `results/witness_validation.json`.
  The hidden-state checker now keys exported position-map certificates by
  `object_id` instead of assuming they appear in exactly the same list order as
  `oram_objects`. This does not weaken the theorem boundary; it removes an
  accidental interface assumption and aligns the Lean checker with the Rust
  hidden-state validator. As a result, the proof-grade multi-object
  `ERC20Lite/pathoram/transferFrom` witness now validates cleanly.

- `cleared` Compiler/checker ORAM access-shape validation now enforces the
  theorem-facing backend boundary.
  Evidence:
  `crates/uo-core/src/manifest.rs`,
  `compiler/uo-solc/src/lib.rs`,
  `checker/uo-check/src/lib.rs`.
  The shared validation path now checks the Lean-aligned ORAM parameter shape
  used by the theorem boundary and rejects multi-access entrypoints on the
  legacy surrogate ORAM backend. Only `path_oram_local_posmap_v1` is now
  admitted for multi-access-per-entrypoint ORAM workloads, which closes a
  compile-time/runtime drift path in `max_commit_ops` budgeting and keeps the
  implementation aligned with the proof-grade backend claim.

- `cleared` Runtime ORAM parameter construction now shares the same manifest
  formulas as the compiler/checker, and theorem-facing runtime tests target the
  proof-grade path-ORAM configs.
  Evidence:
  `crates/uo-core/src/manifest.rs`,
  `runtime/uo-evm/src/oram.rs`,
  `runtime/uo-evm/src/lib.rs`.
  The runtime no longer re-derives the common ORAM parameter formulas in a
  separate code path; it now builds its concrete ORAM parameters from the
  shared `OramManifest::for_object` result. The runtime theorem-facing tests
  for multi-access workloads now run against the existing `.pathoram.yaml`
  benchmark configs and assert the proof-grade theorem observer rather than
  legacy exact physical-trace equality, which keeps the test suite aligned with
  the computational-UO theorem boundary for `path_oram_local_posmap_v1`.

## Active

- `active` Theorem-backed path-ORAM benchmark coverage now extends beyond the
  original `SingleAccessMap` witness vehicle, but not yet through every
  theorem-facing artifact layer.
  Evidence:
  `benches/raw/ConfidentialMixer.pathoram.yaml`,
  `benches/raw/ERC20Lite.pathoram.yaml`,
  `results/witness_validation.json`,
  `results/seeded_witness_validation.json`,
  `results/fresh_coin_validation.json`,
  `results/pathoram_pair_validation.json`,
  `results/controller_observer_validation.json`,
  `results/pathoram_hidden_validation.json`.
  The current artifact now validates:
  the multi-access `ConfidentialMixer/pathoram/deposit` run, and
  the multi-object `ERC20Lite/pathoram/transferFrom` run
  at the full runtime-witness layer, the standalone public controller-observer
  layer, the standalone hidden Path-ORAM layer, the finite seeded-family
  layer, and the finite seeded-pair certificate layer. In addition, the full
  canonical fresh-coin family layer now reaches the multi-access
  `ConfidentialMixer/pathoram/deposit` workload with its complete `262144`-seed
  family. The canonical fresh-coin and canonical-pair probes now also have an
  explicit memory-safety guard: they preflight compact artifact size from
  sampled witnesses and skip oversized cases before materialization, rather
  than risking host OOM.
  The current report now records both
  `ConfidentialMixer/pathoram/deposit-canonical-pair` and
  `ERC20Lite/pathoram/transferFrom-canonical-pair` as explicit
  `skipped_by_budget` cases with concrete size estimates. The fresh-coin family
  report now likewise records `ERC20Lite/pathoram/transferFrom-fresh-coins` as
  an explicit `skipped_by_budget` case. What remains missing is the larger
  canonical-pair layer and the full canonical-family /
  canonical-pair coverage for workloads such as
  `ERC20Lite/pathoram/transferFrom`.

- `active` The concrete `path_oram_local_posmap_v1` theorem boundary is now
  explicit at the Lean surface, but the standard-ORAM discharge is still open.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`,
  `docs/paper-theorem-profile.md`,
  `docs/formal-proof-plan.md`.
  The repo now names the remaining backend-specific assumption bundle,
  specializes the generic path-ORAM reduction to that bundle, and packages the
  resulting computational-UO, paper-main SGX, joint-SGX, artifact-composition,
  and TEE-storage consequences into explicit theorem-boundary propositions. It
  now also exposes the explicit standard-theorem import boundary for the
  concrete backend, and the current seeded runtime proof bundle now matches
  that import boundary directly, so the remaining gap is no longer theorem
  plumbing or runtime/theorem interface alignment.
  What remains missing is the actual reduction from the implementation
  candidate to a proved standard Path ORAM theorem under those explicit
  assumptions.

## Open

- `open` Discharge the ORAM theorem for the concrete
  `path_oram_local_posmap_v1` implementation.
  The runtime candidate, hidden witness interface, theorem-tight seeded-family
  checker, theorem-tight paired-certificate checker, and a concrete
  backend-specific Lean theorem boundary now all exist, but the reduction from
  the implementation candidate to the standard Path ORAM theorem itself is
  still not finished.

- `open` Extend the full canonical-family and canonical-pair path-ORAM coverage
  beyond the current small benchmark vehicles.
  The witness/controller/hidden-certificate pipeline, the finite seeded-family
  pipeline, and the finite seeded-pair certificate pipeline now all cover
  additional admitted path-ORAM workloads, including a multi-access
  `ConfidentialMixer/pathoram/deposit` run and a multi-object
  `ERC20Lite/pathoram/transferFrom` run. The full canonical fresh-coin family
  layer now also covers `ConfidentialMixer/pathoram/deposit`, but the larger
  canonical-pair layer is still not materialized and the canonical-family /
  canonical-pair theorem inputs are still not instantiated for very large
  workloads such as `ERC20Lite/pathoram/transferFrom`. The evaluation harness
  now skips oversized canonical-pair instances by an explicit preflight size
  budget instead of trying to materialize them and risking memory exhaustion.

- `active` The end-to-end SGX theorem packaging gap is now narrowed to
  instantiation, not theorem-surface design.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`,
  `docs/paper-theorem-profile.md`.
  The repository now has an explicit artifact-level paper-main bundle for the
  concrete backend that combines exact artifact composition, exact SGX
  execution security, concrete ORAM SGX execution security, and mixed
  exact/ORAM TEE storage security into one Lean proposition. What remains is
  to instantiate that bundle all the way through runtime refinement and the
  still-open concrete ORAM theorem discharge for the supported backend set.

## Current Exit Condition

The project should be treated as complete only when every `open` item above is
cleared without weakening the theorem boundary and without adding new proof
assumptions beyond those already made explicit in the formal plan.
