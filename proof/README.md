# Proof Workspace

This directory contains the mechanized theorem-facing artifacts referenced by
the repository docs. It is no longer just a placeholder scaffold.

The authoritative high-level claim boundary lives in
`docs/formal-proof-plan.md` and `docs/paper-theorem-profile.md`. This file is a
workspace map.

## Main Lean Layers

- Core artifact semantics:
  `TraceModel.lean`, `IRSemantics.lean`, `ExactObjects.lean`,
  `CompilerInvariant.lean`, `Composition.lean`
- SGX-facing observer and controller model:
  `SgxBoundary.lean`, `SgxRelation.lean`, `SgxController.lean`,
  `SgxControllerTrace.lean`, `SgxMicroGame.lean`,
  `SgxExactProjection.lean`, `SgxOramProjection.lean`,
  `SgxJointProjection.lean`, `TeeDeployment.lean`
- Runtime refinement and trusted-kernel bridge:
  `RuntimeRefinement.lean`, `RuntimeRefinementJson.lean`,
  `RuntimeTrustedKernel.lean`, `RuntimeTrustedKernelJson.lean`,
  `RuntimeCoins.lean`, `RuntimeCoinsJson.lean`
- Standard-ORAM and concrete Path-ORAM layers:
  `OramGame.lean`, `StandardOramReduction.lean`,
  `PathOramSecurity.lean`, `PathOramLocalPosmapV1.lean`,
  `PathOramLocalPosmapV1Refinement.lean`,
  `PathOramLocalPosmapV1StandardTheorem.lean`,
  `PathOramJACMTheorem.lean`, `PaperPathOramTheoremRoute.lean`

## Executable Checkers

`lake build` now materializes Lean-side validators for the runtime artifacts:

- `checkRuntimeTrustedKernel`
- `checkRuntimeControllerCertificate`
- `checkRuntimePathOramHiddenCertificate`
- `checkRuntimeWitness`
- `checkRuntimeWitnessFamily`
- `checkPathOramPairCertificate`
- `checkCanonicalPathOramPairCertificate`
- `checkCanonicalPathOramPaperInstantiation`

These are the executables the probe invokes when it validates emitted runtime
bundles, witnesses, seeded families, and canonical pair artifacts.

## Current Status

The proof workspace now fixes the following pieces explicitly:

- the paper-facing SGX observer profile keeps `public_outcome` and
  `boundary_schedule` exact while normalizing only the SGX micro observer
- the theorem-facing backend path is the concrete
  `path_oram_local_posmap_v1` candidate; the legacy surrogate path is retained
  only as a compatibility specialization
- the runtime bridge is explicit:
  controller certificate, hidden Path-ORAM certificate, trusted-kernel bundle,
  refinement witness, seeded witness family, and canonical fresh-coin artifacts
- the standard-theorem import target is frozen at
  `PathOramLocalPosmapV1StandardTheoremTarget`
- the paper route and the appendix / executable-artifact route share the same
  theorem interface while remaining distinct provenance claims

## What This Workspace Does Not Claim

- that every line of Rust is proved correct in Lean
- that the current repository already proves malicious-host SGX execution
  obliviousness
- that the stronger external-theorem import route is already complete

The repo instead keeps a small explicit trusted boundary and validates emitted
artifacts against the theorem-side predicates end to end.
