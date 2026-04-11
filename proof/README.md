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

These files only freeze the module split and theorem boundary. They do not yet
contain mechanized proofs of the UO claims.

Current status:

- `TraceModel.lean`, `IRSemantics.lean`, `ExactObjects.lean`, `CompilerInvariant.lean`, and
  `Composition.lean` now contain executable definitions and proved lemmas for
  normalized trace composition, public-projection equality, exact-UO closure
  under composition, and public-gas equalization.
- `OramGame.lean` remains the proof boundary for the computational-UO ORAM
  theorem; that cryptographic game argument is not mechanized yet.

The theorem boundary and the required runtime/compiler changes are defined in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).
