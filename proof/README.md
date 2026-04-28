# Proof Workspace

This directory contains the Lean theorem models and executable proof-grade
checkers referenced by the repository docs.

For the high-level claim boundary, use
[`docs/claim-boundary.md`](../docs/claim-boundary.md). For the proof-layer map
and validation reports, use
[`docs/proof-architecture.md`](../docs/proof-architecture.md).

## Main Lean Layers

- Core artifact semantics:
  `TraceModel.lean`, `HistorySemantics.lean`, `IRSemantics.lean`,
  `ExactObjects.lean`, `CompilerInvariant.lean`, `Composition.lean`.
- Confidential fragment and kernel DSL:
  `ConfidentialFragment.lean`, `ConfidentialFragmentJson.lean`,
  `ConfidentialKernelDsl.lean`, `KernelDsl.lean`.
- Runtime bridge:
  `RuntimeRefinement.lean`, `RuntimeRefinementJson.lean`,
  `RuntimeTrustedKernel.lean`, `RuntimeTrustedKernelJson.lean`,
  `RuntimeShellBoundary.lean`, `RuntimeShellBoundaryJson.lean`,
  `RuntimeImplementationInterface.lean`.
- Path ORAM route:
  `OramGame.lean`, `FiniteDistribution.lean`,
  `StandardOramReduction.lean`, `PathOramSecurity.lean`,
  `PathOramLocalPosmapV1.lean`, `PathOramLocalPosmapV1StandardTheorem.lean`,
  `PathOramJACMTheorem.lean`, `PaperPathOramTheoremRoute.lean`.
- SGX/TEE observer:
  `SgxBoundary.lean`, `SgxRelation.lean`, `SgxController.lean`,
  `SgxControllerTrace.lean`, `SgxMicroModel.lean`,
  `SgxObserverFreeze.lean`, `TeeDeployment.lean`.

## Executable Checkers

`lake build` materializes Lean-side validators for runtime and translation
artifacts. Common probe-driven checkers include:

- `checkProofGradeTranslationArtifacts`
- `checkProofGradeRuntimeKernelWitness`
- `checkProofGradeRuntimeKernelRefinementWitness`
- `checkProofGradeRuntimeTrustedKernel`
- `checkProofGradeRuntimeWitness`
- `checkProofGradeRuntimeShellBoundary`
- `checkProofGradeRuntimeKernelDsl`
- `checkProofGradeRuntimeKernelSlotDsl`
- `checkProofGradeRuntimeConfidentialCore`
- `checkProofGradeRuntimeConfidentialCoreSlot`
- `checkProofGradeRuntimeConfidentialProofBundleFamily`
- `checkRuntimeControllerCertificate`
- `checkRuntimePathOramHiddenCertificate`
- `checkRuntimeWitnessFamily`
- `checkRuntimeFreshCoinFamily`
- `checkCanonicalPathOramPairCertificate`
- `checkCanonicalPathOramPaperInstantiation`

## Status

The default `UOToolchain` umbrella imports `UOToolchain.ProofGradeRoot`.
Legacy axiom-backed demonstrations are isolated behind
`UOToolchain.LegacyRoot` and are not proof-grade dependencies.

The current paper route is closed at the documented boundary under explicit
backend, cryptographic, and TEE deployment assumptions. The workspace still
does not claim full verification of every Rust implementation detail or
downstream machine code.
