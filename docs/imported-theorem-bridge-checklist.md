# Imported-Theorem Bridge Checklist

This checklist fixes the concrete closure path for the strongest repo-facing
claim the current artifact can honestly make:

1. import a standard Path ORAM theorem at an exact formal interface
2. prove or check that the concrete toolchain implementation conforms to that
   interface
3. derive the repo's computational-UO, TEE-storage, and paper-facing SGX
   consequences from that composition

This is deliberately not a claim that every line of Rust is formally verified.
The repo path here is:

- imported standard theorem for the cryptographic / ORAM core
- an explicit proof-relevant source/artifact translation boundary plus a Lean
  checker over that boundary, now driven on the proof-grade path by direct
  checking of separately materialized artifacts
- runtime-emitted controller and hidden-state certificates
- an explicit runtime trusted-kernel bundle packaging those certificates
- a proof-grade trusted-kernel slot bundle packaging that trusted-kernel
  bundle together with the admitted confidential slot DSL object
- direct runtime witness reconstruction from that trusted-kernel bundle
- Lean-checked theorem-facing validation of the resulting witness artifacts

Status labels:

- `cleared`: implemented and exercised in the current repo
- `optional`: useful paper-presentation or future-proofing work, but not
  required for the imported-theorem bridge to be complete under the current
  explicit assumption bundle

## Checklist

- `cleared` Freeze the exact imported standard Path ORAM theorem target in Lean.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`,
  `proof/lean/UOToolchain/PathOramJACMTheorem.lean`,
  `docs/path-oram-core-theorem-import.md`.
  The repo now fixes one exact import boundary,
  `PathOramLocalPosmapV1StandardTheoremTarget`, plus a literature-facing JACM
  mapping.

- `cleared` Isolate the concrete backend assumption bundle at one theorem-facing
  boundary.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`.
  The remaining backend assumptions are explicit as
  `bucketEncryptionINDCPA`, `metadataEncryptionINDCPA`, and
  `stashOverflowBounded`.

- `cleared` Keep the legacy surrogate and legacy theorem shims off the
  proof-grade dependency path.
  Evidence:
  `proof/lean/UOToolchain/OramGame.lean`,
  `proof/lean/UOToolchain/LegacySgxOramProjection.lean`,
  `proof/lean/UOToolchain/LegacySgxJointProjection.lean`,
  `proof/lean/UOToolchain/LegacyTeeDeployment.lean`,
  `proof/lean/UOToolchain/ProofGrade.lean`,
  `proof/lean/UOToolchain/SgxMicroGame.lean`,
  `probe/mplus-probe/src/lib.rs`,
  `docs/formal-proof-plan.md`.
  The only remaining Lean `axiom`s are marked legacy, and the proof-grade
  `path_oram_local_posmap_v1` development does not depend on them.
  The `static-checks` probe also pins the legacy axiom definitions to the
  legacy game modules, restricts legacy theorem-symbol mentions to the
  `Legacy*` bridge/projection companions, and checks that every top-level
  `Check*.lean` entrypoint imports `UOToolchain.ProofGrade` instead of the
  legacy umbrella, that the `ProofGrade` umbrella plus the generic theorem
  modules do not import the legacy surface, and that those checker entrypoints
  do not mention the legacy shims directly.

- `cleared` Translation-validate proof-relevant compiler output against source
  and metadata.
  Evidence:
  `crates/uo-core/src/translation_validation.rs`,
  `compiler/uo-solc/src/lib.rs`,
  `checker/uo-check/src/lib.rs`,
  `checker/uo-check/src/main.rs`,
  `proof/lean/UOToolchain/TranslationValidationJson.lean`,
  `proof/lean/CheckProofGradeTranslationArtifacts.lean`,
  `probe/mplus-probe/src/lib.rs`.
  The bridge path now builds a proof-relevant source/artifact translation
  payload from `uo-solc` plus `uo-core`, but the strongest proof-grade checker
  path now consumes separately materialized source and candidate artifacts and
  extracts the raw contract JSON internally. Lean reconstructs the
  proof-relevant views internally, accepts only when those reconstructed views
  match, and then checks the current proof-grade replay obligations used by
  `results/static_checks.json` and `results/bridge_validation.json`:
  state-object / manifest exactness, secret-arg agreement, confidential
  raw-backend rejection, arena/stack budgets, logical access counters, ORAM
  access counts and theorem-facing ORAM shape, `max_commit_ops`, and
  confidential kernel opcode / step replay from the admitted fragment.
  The probe no longer depends on `uo-check` as a library, and `uo-check` now
  remains only as a diagnostics/debug wrapper on this path. The remaining gap
  is no longer a Rust-side proof-relevant projection decision and is no longer
  a proof-grade acceptance dependency in the automated path; the richer
  Rust-emitted proof-relevant view bundle is now outside the proof-grade
  acceptance path and treated as debug-only output.

- `cleared` Export the public SGX/controller slice as a standalone theorem-facing
  runtime certificate.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `runtime/uo-evm/src/engine.rs`,
  `proof/lean/CheckRuntimeControllerCertificate.lean`.
  The public observer path is no longer hidden inside the full runtime witness.

- `cleared` Export the hidden Path ORAM state slice as a standalone
  theorem-facing runtime certificate.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `runtime/uo-evm/src/engine.rs`,
  `proof/lean/CheckRuntimePathOramHiddenCertificate.lean`.
  The hidden leaf schedule and position-map transition argument is now a
  first-class certificate path rather than an implicit sidecar.

- `cleared` Construct the runtime refinement witness directly from the runtime
  certificates and check agreement with trace-based reconstruction.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `runtime/uo-evm/src/engine.rs`.
  The runtime now builds a direct certificate-derived witness and rejects any
  execution whose returned `ExecutionTrace` reconstructs a different witness.

- `cleared` Package the runtime-side trusted boundary as an explicit
  theorem-facing kernel bundle.
  Evidence:
  `crates/uo-core/src/trace.rs`,
  `proof/lean/UOToolchain/RuntimeTrustedKernel.lean`,
  `proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean`,
  `proof/lean/CheckProofGradeRuntimeTrustedKernel.lean`,
  `results/trusted_kernel_validation.json`.
  The runtime now emits a `RuntimeTrustedKernelBundle` containing the public
  controller observer certificate, the hidden Path-ORAM certificate, and the
  optional replay seed. That direct bundle is now stored on emitted runtime
  traces, while the older trace-based reconstruction path survives only as an
  internal audit check. For the proof-grade bridge, the runtime now also
  packages that bundle with the admitted confidential slot program in a
  `RuntimeTrustedKernelSlotBundle`, and the Lean checker validates that
  stronger artifact directly on the benchmark-backed runtime scenarios.

- `cleared` Validate the theorem-facing bridge artifacts with Lean-backed
  checkers.
  Evidence:
  `proof/lean/lakefile.lean`,
  `probe/mplus-probe/src/lib.rs`,
  `scripts/run_validation.sh`.
  The default Lean build materializes the runtime-witness and certificate
  checkers, and the probe runs the corresponding validation reports. The probe
  now also emits `tamper_validation.json`, which mutates representative direct
  controller/hidden certificates, every proof-grade translation/runtime bridge
  artifact, and the theorem-facing seeded/canonical witness-family,
  theorem-input, and pair-certificate artifacts, then checks that the shipped
  Lean executables reject those semantically drifted but still parseable
  artifacts end to end.

- `cleared` Provide a dedicated bridge-validation report rather than forcing
  users to infer bridge status from the full probe bundle.
  Evidence:
  `probe/mplus-probe/src/lib.rs`,
  `probe/mplus-probe/src/main.rs`,
  `scripts/run_bridge_validation.sh`.
  The repo now has a focused `bridge_validation.json` path that runs
  translation validation plus the controller / hidden / kernel /
  kernel-refinement / trusted-kernel / witness bridge reports, and the
  companion `tamper_validation.json` report extends the negative testing to
  those bridge artifacts plus the seeded/canonical witness-family,
  theorem-input, and pair-certificate interfaces.

- `optional` The paper-main theorem provenance step is tracked separately in
  `docs/paper-main-theorem-checklist.md`: supply or cite an external
  literature-proof object at exactly the same frozen interface while keeping
  the current self-instantiated route for executable artifact closure. This is
  still a theorem provenance choice, not a repo-completeness blocker.

## Exit Condition

This checklist is complete when every non-optional item above is `cleared`
without weakening the theorem boundary and without introducing backend
assumptions beyond the explicit `PathOramLocalPosmapV1SecurityAssumptions`
bundle.
