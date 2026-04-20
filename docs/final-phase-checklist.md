# Final-Phase Checklist

This checklist now records the endgame status of the repository after the main
runtime/proof bridge landed.

Status labels:

- `cleared`: implemented and rechecked in the current repository
- `future-work`: not required for the current repo-internal bridge, but still
  relevant for stronger provenance or deployment claims

## Cleared

- `cleared` Checked runtime refinement witnesses for the supported
  theorem-backed paths.
  Evidence:
  `results/witness_validation.json`,
  `proof/lean/CheckProofGradeRuntimeWitness.lean`.

- `cleared` Checked standalone controller-observer certificates.
  Evidence:
  `results/controller_observer_validation.json`,
  `proof/lean/CheckRuntimeControllerCertificate.lean`.

- `cleared` Checked standalone hidden Path-ORAM certificates.
  Evidence:
  `results/pathoram_hidden_validation.json`,
  `proof/lean/CheckRuntimePathOramHiddenCertificate.lean`.

- `cleared` Checked the explicit trusted-kernel bridge exported from emitted
  traces: the runtime stores `RuntimeTrustedKernelBundle` on emitted traces,
  and the proof-grade checker validates the slot-wrapped trusted-kernel
  artifact built from that bundle plus the admitted confidential slot
  program.
  Evidence:
  `results/trusted_kernel_validation.json`,
  `proof/lean/CheckProofGradeRuntimeTrustedKernel.lean`.

- `cleared` Checked the standalone kernel witness and the lower-level
  runtime-phase refinement witness exported from emitted traces.
  Evidence:
  `results/kernel_validation.json`,
  `results/kernel_refinement_validation.json`,
  `proof/lean/CheckProofGradeRuntimeKernelWitness.lean`,
  `proof/lean/CheckProofGradeRuntimeKernelRefinementWitness.lean`.

- `cleared` Checked the explicit shell/kernel proof interface and its shared
  DSL/interpreter compositions, up through the full runtime witness +
  shell-boundary + named/slot DSL bundle.
  Evidence:
  `results/kernel_dsl_validation.json`,
  `results/kernel_slot_dsl_validation.json`,
  `results/kernel_lowering_validation.json`,
  `results/shell_boundary_validation.json`,
  `results/shell_boundary_slot_validation.json`,
  `results/shell_boundary_lowering_validation.json`,
  `results/confidential_core_validation.json`,
  `results/confidential_core_slot_validation.json`,
  `results/confidential_core_kernel_interface_slot_validation.json`,
  `results/confidential_core_shell_boundary_slot_validation.json`,
  `results/confidential_core_lowering_validation.json`,
  `results/confidential_core_shell_boundary_lowering_validation.json`,
  `proof/lean/UOToolchain/RuntimeKernelDslJson.lean`,
  `proof/lean/UOToolchain/RuntimeShellBoundary.lean`,
  `proof/lean/UOToolchain/RuntimeConfidentialCoreAssurance.lean`,
  `proof/lean/UOToolchain/RuntimeShellBoundaryJson.lean`,
  `proof/lean/UOToolchain/RuntimeShellBoundarySlotJson.lean`,
  `proof/lean/UOToolchain/RuntimeShellBoundaryLoweringJson.lean`,
  `proof/lean/UOToolchain/RuntimeConfidentialCoreAssuranceJson.lean`,
  `proof/lean/UOToolchain/RuntimeConfidentialCoreKernelInterfaceSlotJson.lean`,
  `proof/lean/UOToolchain/RuntimeConfidentialCoreShellBoundarySlotJson.lean`,
  `proof/lean/UOToolchain/RuntimeConfidentialCoreShellBoundaryLoweringJson.lean`.

- `cleared` Checked seeded runtime witness families and paired Path-ORAM proof
  inputs.
  Evidence:
  `results/seeded_witness_validation.json`,
  `results/pathoram_pair_validation.json`,
  `proof/lean/CheckRuntimeWitnessFamily.lean`,
  `proof/lean/CheckPathOramPairCertificate.lean`.
  The seeded-family bridge now also exports and checks the stronger
  `SeededRuntimePaperMainSlotFamilyBundle` alongside the original seeded
  paper-main family bundle.

- `cleared` Checked canonical fresh-coin families and canonical pair
  certificates, with compact theorem-input fallback for oversized families and
  heavy-artifact support for feasible larger cases.
  Evidence:
  `results/fresh_coin_validation.json`,
  `results/canonical_pathoram_pair_validation.json`,
  `scripts/run_heavy_artifact.sh`,
  `proof/lean/CheckRuntimeFreshCoinTheoremInput.lean`,
  `proof/lean/CheckCanonicalPathOramPairCertificate.lean`,
  `proof/lean/CheckCanonicalPathOramPairTheoremInput.lean`,
  `proof/lean/CheckCanonicalPathOramPaperInstantiation.lean`.

- `cleared` Closed the source-to-artifact bridge for proof-relevant fields by
  checker-side translation validation.
  Evidence:
  `checker/uo-check/src/lib.rs`,
  `crates/uo-core/src/translation_validation.rs`,
  `compiler/uo-solc/src/lib.rs`,
  `proof/lean/UOToolchain/TranslationValidationJson.lean`,
  `proof/lean/CheckProofGradeTranslationArtifacts.lean`,
  `results/static_checks.json`,
  `results/bridge_validation.json`.
  The current bridge path now goes through a direct Lean acceptance check over
  separately materialized source and candidate artifacts, rather than a
  Rust-only translation validator, and the probe no longer depends on
  `uo-check` as a library on that path. The Lean check reconstructs the
  proof-relevant source/artifact views from raw contract JSON extracted
  directly from those artifacts, and then replays state-object manifests,
  confidential raw-backend rejection, resource counts/budgets, ORAM access
  metadata, `max_commit_ops`, and confidential kernel step/opcode schedules
  directly from those Lean-reconstructed views. The richer Rust-emitted
  proof-relevant view bundle is now debug-only and is no longer accepted by
  the proof-grade checker.

- `cleared` Kept the theorem-facing backend on the concrete
  `path_oram_local_posmap_v1` path and off any surrogate backend.
  Evidence:
  `crates/uo-core/src/manifest.rs`,
  `runtime/uo-evm/src/oram.rs`,
  `docs/formal-proof-plan.md`.

- `cleared` Extended proof-facing runtime validation beyond the original
  `SingleAccessMap` vehicle.
  Evidence:
  `results/witness_validation.json`,
  `results/seeded_witness_validation.json`,
  `results/controller_observer_validation.json`,
  `results/pathoram_hidden_validation.json`.
  The current reports cover multi-access `ConfidentialMixer/pathoram/deposit`
  and multi-object `ERC20Lite/pathoram/transferFrom` paths in addition to the
  small canonical `SingleAccessMap` families.

- `cleared` Froze the exact standard-theorem import target and separated the
  paper route from the appendix / executable-artifact route without changing
  the theorem boundary.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`,
  `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`,
  `docs/paper-main-theorem-checklist.md`.

## Future Work

- `future-work` Replace the current citation-based JACM paper route with a
  genuinely external machine-checked theorem import at the same frozen
  interface, if such an artifact becomes available.

- `future-work` Justify or import the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle more strongly than the
  current assumption-profile writeup.

- `future-work` Materialize very large canonical families explicitly when they
  are physically feasible and worthwhile as artifact objects; compact
  theorem-input certificates are already sufficient for the current bridge.

- `future-work` Upgrade from the current paper-facing SGX observer profile to a
  malicious-host SGX execution theorem only if the enclave controller and SGX
  observer are connected to the real runtime by the same refinement discipline.

## Current Exit Condition

The repo-internal engineering bridge should now be treated as closed. Remaining
items are future-strengthening work about theorem provenance, backend
assumption discharge, or larger artifact materialization, not missing bridge
plumbing.
