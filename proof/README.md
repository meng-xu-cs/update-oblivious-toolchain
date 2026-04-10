# Proof Workspace

This directory is reserved for the mechanized proof artifacts referenced in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).

The repository now includes the first Lean scaffold under `proof/lean/`:

- `proof/lean/lakefile.lean`
- `proof/lean/lean-toolchain`
- `proof/lean/UOToolchain.lean`
- `proof/lean/TraceModel.lean`
- `proof/lean/IRSemantics.lean`
- `proof/lean/ExactObjects.lean`
- `proof/lean/CompilerInvariant.lean`
- `proof/lean/Composition.lean`
- `proof/lean/OramGame.lean`

These files only freeze the module split and theorem boundary. They do not yet
contain mechanized proofs of the UO claims.

The theorem boundary and the required runtime/compiler changes are defined in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).
