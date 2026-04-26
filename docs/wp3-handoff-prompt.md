# Handoff Prompt For Claude Opus 4.7

Use this prompt to resume the WP3 work from the checkpoint commit that added
`docs/wp3-handoff-runbook.md`.

```text
You are Claude Opus 4.7 running with maximum reasoning effort as a coding agent
in /home/m285xu/update-oblivious-toolchain.

Your task is to continue Work Package 3 of the update-oblivious toolchain:
reduce the confidential runtime to a tiny generated/Lean-backed kernel, prove
the real runtime helper/kernel implementation refines the Lean model, and prove
uo-evm cannot do secret-dependent work outside that kernel.

Start by reading:

1. docs/wp3-handoff-runbook.md
2. docs/top-tier-paper-execution-roadmap.md
3. docs/paper-theorem-profile.md
4. proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean
5. runtime/uo-evm/src/generated_oram_codecs.rs
6. probe/mplus-probe/src/lib.rs

Do not ask for a checkpoint or status-only pause if a clear next technical step
is available. Stop only if a human policy or design decision is genuinely
needed.

Before editing, verify the checkpoint with:

cd /home/m285xu/update-oblivious-toolchain
cargo fmt
cd proof/lean
lake build UOToolchain.RuntimeImplementationInterfaceJson \
  CheckProofGradeRuntimeResidualHelperShellBoundary \
  CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary
cd ../..
cargo check -p mplus-probe
cargo run -q -p mplus-probe -- --only runtime-residual-helper-shell-boundary-validation --out-dir results > /tmp/uo-residual-helper-validation.json
cargo run -q -p mplus-probe -- --only runtime-implementation-kernel-machine-confinement-boundary-validation --out-dir results > /tmp/uo-kernel-machine-validation.json
cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation --out-dir results > /tmp/uo-kernel-model-alignment-validation.json
cargo run -q -p mplus-probe -- --only static-checks --out-dir results > /tmp/uo-static-checks.json
git diff --check

The current stopping point is WP3 / ORAM helper semantics /
bucket-indexed reconstruction admission. The latest checkpoint added a
bucket-indexed Lean reconstruction fold that models the runtime rejection of
occupied decoded bucket blocks whose leaf is not on that public bucket path.
It is projected through the residual-helper-shell and direct
machine-confinement checker routes and reflected in the probe reports.

The next recommended task is to complete the bridge between codec-level decoded
bucket facts and helper-level BucketBlock reconstruction facts:

1. In RuntimeOramCodecSemantics, decoded path buckets already prove
   LiveOnBucketPath for occupied blocks.
2. In RuntimeOramHelperSemantics, BucketBlock admission now rejects off-path
   occupied bucket blocks and admitted blocks reduce to the ordinary block step.
3. Add theorem(s) that convert decoded bucket payload blocks into admitted
   helper BucketBlock reconstruction input, preserving the public bucket index.
4. Project those theorems through RuntimeImplementationInterface,
   RuntimeImplementationInterfaceJson, CheckProofGradeRuntimeResidualHelperShellBoundary,
   and CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary.
5. Add explicit report bits to probe/mplus-probe/src/lib.rs.
6. Update docs/top-tier-paper-execution-roadmap.md and
   docs/paper-theorem-profile.md.
7. Run the same validation slice and git diff --check.

Keep using apply_patch for manual edits. Do not revert unrelated dirty files.
When a coherent checkpoint passes validation, commit it with a concise message.

Prefer the scientifically strongest route whenever there is a choice:
Lean-first/generated helper semantics, fewer assumptions, stronger theorem
surface, explicit checker/report projection, and production-level static drift
tests. Treat source-freeze-only checks as temporary bridge work, not final
paper claims.
```
