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

- `cleared` Checked the explicit runtime trusted-kernel bundle for theorem-backed
  backends.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `proof/lean/UOToolchain/RuntimeTrustedKernel.lean`,
  `proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean`,
  `proof/lean/CheckRuntimeTrustedKernel.lean`,
  `results/trusted_kernel_validation.json`.
  The runtime now packages the public controller observer certificate together
  with the hidden Path-ORAM certificate as one small theorem-facing kernel
  bundle. Lean proves the validity condition for that bundle, the runtime now
  stores that direct bundle on emitted traces, and the probe validates real
  emitted bundles directly.

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
  `lake build` now builds `checkRuntimeTrustedKernel`,
  `checkRuntimeWitness`, and `checkRuntimeWitnessFamily`, so the evaluation
  harness no longer depends on a separate manual executable build step.

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
  The broader `*/oram/*` benchmark aliases now compile the same concrete
  `path_oram_local_posmap_v1` backend as the explicit theorem-facing
  `*/pathoram/*` cases. The Lean witness validators therefore report only the
  `pathoram` names and exclude the generic aliases purely to avoid duplicate
  theorem certificates.

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
  schedule against the observed bucket trace. The explicit trusted-kernel
  bundle and the full runtime witness are both now assembled from the
  standalone public controller certificate plus this standalone hidden
  Path-ORAM certificate.

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

- `cleared` Closed the end-to-end paper-main instantiation/refinement gap for
  explicit canonical Path-ORAM pair artifacts.
  Evidence:
  `proof/lean/UOToolchain/RuntimePaperInstantiation.lean`,
  `proof/lean/CheckCanonicalPathOramPaperInstantiation.lean`,
  `probe/mplus-probe/src/lib.rs`.
  The theorem-facing refinement no longer incorrectly requires the full
  canonical fresh-coin family to equal the hidden accessed-leaf seed space.
  Instead, Lean now checks that the explicit fresh-coin family covers the
  hidden accessed-leaf seed space induced by the public leaf scaffold and then
  quotients that family by selecting one representative witness per hidden
  leaf-value seed. The probe now runs this paper-instantiation checker on each
  explicitly materialized canonical pair certificate and records
  `paper_instantiation_status` in the canonical pair validation report. Small
  explicit cases such as `SingleAccessMap/pathoram/put-canonical-pair` and
  `SingleAccessMap/pathoram/add-canonical-pair` now validate end to end in
  both normal explicit mode and bounded heavy-artifact mode. Oversized cases
  that stay on the compact theorem-input path are now marked
  `paper_instantiation_status = not_materialized` explicitly rather than
  silently pretending to have a full explicit instantiation.

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
  sampled witnesses before materialization, rather than risking host OOM.
  Oversized canonical fresh-coin cases no longer need to stop at
  `skipped_by_budget`: the artifact layer now falls back to a compact
  theorem-facing seed-space certificate that validates a representative
  canonical seed together with the full public fresh-coin scaffold and seed
  count. Oversized canonical-pair cases now likewise fall back to a compact
  theorem-facing pair certificate that validates representative canonical
  seeds on both sides against one shared public observer summary, instead of
  stopping at `skipped_by_budget`. The current report accepts both
  `ConfidentialMixer/pathoram/deposit-canonical-pair` and
  `ERC20Lite/pathoram/transferFrom-canonical-pair` as explicit
  compact theorem-input cases with concrete size estimates. What remains
  missing is only the full explicit large-family materialization, not the
  theorem-facing large-case input coverage.

- `cleared` The concrete `path_oram_local_posmap_v1` standard-ORAM theorem is
  now discharged end to end under the explicit backend assumption bundle.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`,
  `proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`,
  `proof/lean/UOToolchain/PathOramJACMTheorem.lean`,
  `docs/paper-theorem-profile.md`,
  `docs/formal-proof-plan.md`.
  The repo now names the remaining backend-specific assumption bundle,
  specializes the generic path-ORAM reduction to that bundle, and packages the
  resulting computational-UO, paper-main SGX, joint-SGX, artifact-composition,
  and TEE-storage consequences into explicit theorem-boundary propositions. It
  now also exposes the explicit standard-theorem import boundary for the
  concrete backend, and the current seeded runtime proof bundle now matches
  that import boundary directly. In addition, the exact imported-theorem target
  is now frozen in `PathOramLocalPosmapV1StandardTheorem.lean`, and the
  abstract theorem proposition to be discharged is explicit as
  `StandardPathOramStorageTheoremAt`. The theorem path is now further split
  into a theorem-side `StandardPathOramCoreTheorem` and a runtime-side
  `PathOramStorageEnvelope`, so the remaining gap is no longer theorem
  plumbing or runtime/theorem interface alignment.
  The literature-faithful route is now also explicit in
  `PathOramJACMTheorem.lean` via `PathOramJACMLiteratureTheorem` and its formal
  mapping into `StandardPathOramCoreTheorem`. The strengthened
  `PathOramJACMLiteratureTheoremAt` route is now available as the preferred
  lowest-assumption import path because it fixes the theorem directly at the
  runtime’s theorem-facing `leafRun`.
  The concrete backend shape is now also aligned with the JACM bucket-size
  parameter `Z = 5`, so the earlier theorem/implementation parameter mismatch
  is removed.
  The concrete seeded runtime bundle now discharges
  `StandardPathOramStorageTheoremAt` directly via
  `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardPathOramStorageTheoremAt`,
  packages the resulting bridge as
  `PathOramLocalPosmapV1StandardTheoremRealization`, and also exposes the
  preferred literature-faithful closure route through
  `pathOramLocalPosmapV1_jacmLiteratureTheoremAt`,
  `pathOramLocalPosmapV1_standardPathOramStorageTheoremAtOfSelfJACMAt`, and
  `pathOramLocalPosmapV1_standardTheoremRealizationOfSelfJACMAt`.
  The old extra `leafRun` alignment gap now survives only as an optional
  general fallback route when importing an external theorem whose schedule is
  not already fixed at `bundle.leafRun`.
  The exact remaining import target is now documented in
  `docs/path-oram-core-theorem-import.md`.

## Open

- `cleared` Added a separate heavy-artifact mode for large feasible canonical
  Path-ORAM families and pair certificates.
  The default `results/` bundle stays on the compact theorem-input path once a
  canonical family or pair certificate exceeds the configured compact budget,
  so the default artifact remains memory-safe and reproducible. In addition,
  `scripts/run_heavy_artifact.sh` now switches the probe into a distinct heavy
  materialization mode backed by a larger explicit-size budget and a separate
  `results-heavy/heavy_artifacts/` directory. In that mode, cases that are too
  large for the default compact artifact but still physically feasible can now
  be materialized explicitly without changing the theorem boundary. Only
  astronomically large seed spaces, such as the current
  `ERC20Lite/pathoram/transferFrom` canonical family and canonical pair, still
  remain on the compact theorem-input path even in heavy mode because their
  full explicit witness space is not a practical artifact target.

- `cleared` The end-to-end SGX theorem packaging gap is closed for the current
  explicit canonical Path-ORAM artifact path.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`,
  `proof/lean/UOToolchain/RuntimePaperInstantiation.lean`,
  `proof/lean/CheckCanonicalPathOramPaperInstantiation.lean`,
  `probe/mplus-probe/src/lib.rs`,
  `docs/paper-theorem-profile.md`.
  The repository now has an explicit artifact-level paper-main bundle for the
  concrete backend and a concrete runtime-refinement bridge that instantiates
  that bundle from explicit canonical pair certificates. The remaining scope
  distinction is now artifact shape, not theorem packaging: explicitly
  materialized canonical pairs validate the paper-main boundary end to end,
  while oversized cases intentionally remain on the compact theorem-input path
  until a full explicit artifact is physically materialized.

## Current Exit Condition

The project should be treated as complete only when every `open` item above is
cleared without weakening the theorem boundary and without adding new proof
assumptions beyond those already made explicit in the formal plan.
