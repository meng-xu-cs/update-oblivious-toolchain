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
- checker-side translation validation for proof-relevant compiler output
- runtime-emitted controller and hidden-state certificates
- direct runtime witness construction from those certificates
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
  `bucketEncryptionINDCPA`, `metadataEncryptionINDCPA`,
  `freshLeafResampling`, and `stashOverflowBounded`.

- `cleared` Keep the legacy surrogate and legacy theorem shims off the
  proof-grade dependency path.
  Evidence:
  `proof/lean/UOToolchain/OramGame.lean`,
  `proof/lean/UOToolchain/SgxMicroGame.lean`,
  `docs/formal-proof-plan.md`.
  The only remaining Lean `axiom`s are marked legacy, and the proof-grade
  `path_oram_local_posmap_v1` development does not depend on them.

- `cleared` Translation-validate proof-relevant compiler output against source
  and metadata.
  Evidence:
  `checker/uo-check/src/lib.rs`,
  `checker/uo-check/src/main.rs`,
  `probe/mplus-probe/src/lib.rs`.
  `uo-check` now re-derives theorem-relevant manifest/object/function fields
  and also supports explicit source-to-artifact validation via
  `check_artifact_against_source`.

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

- `cleared` Validate the theorem-facing bridge artifacts with Lean-backed
  checkers.
  Evidence:
  `proof/lean/lakefile.lean`,
  `probe/mplus-probe/src/lib.rs`,
  `scripts/run_validation.sh`.
  The default Lean build materializes the runtime-witness and certificate
  checkers, and the probe runs the corresponding validation reports.

- `cleared` Provide a dedicated bridge-validation report rather than forcing
  users to infer bridge status from the full probe bundle.
  Evidence:
  `probe/mplus-probe/src/lib.rs`,
  `probe/mplus-probe/src/main.rs`,
  `scripts/run_bridge_validation.sh`.
  The repo now has a focused `bridge_validation.json` path that runs
  translation validation plus the controller / hidden / witness bridge reports.

- `optional` For paper-facing exposition, present an external literature-proof
  object at exactly the same frozen interface while keeping the current
  self-instantiated route for executable artifact closure. This is a theorem
  provenance choice, not a repo-completeness blocker. The current repo already
  exposes the exact import target and a literature-facing JACM mapping;
  swapping in an external imported theorem would strengthen exposition, not
  change the engineering bridge.

## Exit Condition

This checklist is complete when every non-optional item above is `cleared`
without weakening the theorem boundary and without introducing backend
assumptions beyond the explicit `PathOramLocalPosmapV1SecurityAssumptions`
bundle.
