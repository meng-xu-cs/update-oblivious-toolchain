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
