# Proof Workspace

This directory is reserved for the mechanized proof artifacts referenced in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).

The repository now includes the first Lean scaffold under `proof/lean/`:

- `proof/lean/lakefile.lean`
- `proof/lean/lean-toolchain`
- `proof/lean/UOToolchain.lean`
- `proof/lean/UOToolchain/TraceModel.lean`
- `proof/lean/UOToolchain/IRSemantics.lean`
- `proof/lean/UOToolchain/ExactObjects.lean`
- `proof/lean/UOToolchain/CompilerInvariant.lean`
- `proof/lean/UOToolchain/Composition.lean`
- `proof/lean/UOToolchain/OramGame.lean`
- `proof/lean/UOToolchain/TeeDeployment.lean`
- `proof/lean/UOToolchain/SgxBoundary.lean`
- `proof/lean/UOToolchain/SgxRelation.lean`
- `proof/lean/UOToolchain/SgxController.lean`
- `proof/lean/UOToolchain/SgxMicroGame.lean`
- `proof/lean/UOToolchain/SgxOramProjection.lean`
- `proof/lean/UOToolchain/SgxExactProjection.lean`
- `proof/lean/UOToolchain/SgxJointProjection.lean`

These files only freeze the module split and theorem boundary. They do not yet
contain mechanized proofs of the UO claims.

Current status:

- `TraceModel.lean`, `IRSemantics.lean`, `ExactObjects.lean`, `CompilerInvariant.lean`, and
  `Composition.lean` now contain executable definitions and proved lemmas for
  normalized trace composition, public-projection equality, exact-UO closure
  under composition, and public-gas equalization.
- `OramGame.lean` now contains the concrete ORAM public-manifest model,
  public schedule extraction, secret-independence lemmas for leakage
  extraction, and manifest-budget lemmas for the current access schedule.
- `TeeDeployment.lean` now defines the idealized `View_TEE-Store` observer,
  proves that exact-UO artifact semantics transport to the TEE storage view,
  and packages the TEE deployment theorem boundary for the ORAM side.
- `SgxBoundary.lean` now fixes a concrete future `View_SGX` shape in Lean,
  including enclave-boundary events, paging, exits, shared-resource traces, and
  public output shape, while leaving raw timing and physical side channels out
  of scope.
- `SgxRelation.lean` now defines the recommended mixed proof relation for
  `View_SGX`: exact public constancy on public outcome and boundary schedule,
  plus
  abstract storage and micro-trace subrelations.
- `SgxRelation.lean` also proves that the current exact TEE-storage theorem
  embeds into a degenerate SGX semantics with empty boundary, paging, exit, and
  shared-resource traces.
- `SgxOramProjection.lean` now lifts the existing ORAM computational boundary
  into the mixed SGX relation, assuming the SGX public outcome, boundary
  schedule, and micro-trace envelope are public-safe functions of the public
  projection.
- `SgxExactProjection.lean` now lifts the exact artifact theorem into the same
  SGX relation under an arbitrary public-safe SGX envelope, not just the
  degenerate empty-trace case.
- `SgxMicroGame.lean` now introduces an explicit SGX-controller leakage object
  `L_sgx_micro` and a separate computational SGX micro-trace theorem boundary.
- `SgxController.lean` now models a nontrivial SGX controller shape with public
  phase plans, page-budget regions, workset bounds, and a derivation of
  `L_sgx_micro` from ORAM execution leakage.
- `SgxJointProjection.lean` now models joint SGX samples carrying both storage
  and controller traces, and proves a joint lifting theorem into the mixed
  `View_SGX` relation from separate storage and controller assumptions.
- the SGX observer boundary in
  [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md)
  now includes explicit public output shape plus a ZeroTrace-derived split into
  boundary, paging, exit, and shared-resource traces
- The remaining unproved boundary is the actual computational indistinguishability
  theorem for the ORAM backend. The TEE storage layer now reduces
  definitionally to that existing ORAM boundary rather than introducing a
  second projection axiom.
- [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md)
  now also fixes a separate TEE/SGX deployment boundary:
  an idealized TEE storage theorem is in scope as a future deployment theorem,
  while SGX execution obliviousness against a malicious host is explicitly out
  of scope for the current repository state.

The theorem boundary and the required runtime/compiler changes are defined in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).
