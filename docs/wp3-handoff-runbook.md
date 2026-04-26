# WP3 Handoff Runbook

This runbook is written for a follow-on coding agent, specifically Claude Opus
4.7 with maximum reasoning effort. It records the project context, the current
checkpoint, the status-tracking convention, and the recommended path to finish
the strongest Work Package 3 route.

## Project Summary

The repository is the update-oblivious toolchain prototype. Its long-term
research goal is to give a reviewer-defensible, top-tier-paper assurance story
for running supported Solidity contracts without leaking secret-dependent
information to the M+ adversary model.

The strongest current route is not just "run `uo-evm` inside a TEE." The target
story is:

1. Shrink all confidential runtime work into a tiny kernel and generated helper
   stack.
2. Make the Rust runtime shell public-only: it may schedule public work,
   allocate fixed public buffers, serialize public metadata, and call generated
   helpers, but it must not branch, index, loop, allocate, or emit evidence based
   on secrets.
3. Define a Lean model for the tiny kernel and generated helper semantics.
4. Prove checked runtime/interface artifacts refine the Lean model.
5. Prove the remaining `uo-evm` handwritten shell cannot perform
   secret-dependent work outside the modeled/generated kernel.

The important project documents are:

- `docs/top-tier-paper-execution-roadmap.md`: primary execution roadmap.
- `docs/paper-theorem-profile.md`: current theorem and TCB profile.
- `docs/runtime-secret-state-inventory.md`: secret-state and runtime surface
  inventory.
- `docs/trusted-kernel-verification.md`: trusted-kernel/proof route.
- `docs/tee-runtime-hardening.md`: TEE deployment/security engineering notes.
- `docs/formal-proof-plan.md`: broader formal proof plan.

## Current Checkpoint

Stop point: Work Package 3, ORAM helper semantics, bucket-indexed reconstruction
admission.

The active subtask was to shrink the residual handwritten ORAM reconstruction
surface by moving more of `runtime/uo-evm/src/generated_oram_codecs.rs` into
Lean-facing helper semantics and imported checker routes.

This checkpoint completed:

- Lean helper semantics for live-slot validation and update.
- Lean helper semantics for final live-slot coverage checks.
- Lean helper semantics for path-entry reset/install effects.
- Lean helper semantics for a reconstruction loop-body step.
- Lean helper semantics for a list-level block reconstruction fold.
- Lean helper semantics for the whole decoded reconstruction shell:
  initial state, stash fold, bucket fold, final failure predicate.
- Lean helper semantics for the bucket-indexed admission gate:
  occupied bucket blocks off the public bucket path are rejected before entering
  reconstruction; admitted bucket blocks reduce to the ordinary block-step
  semantics.
- Projection of the new bucket-indexed checkpoint through:
  `RuntimeImplementationInterface`,
  `RuntimeImplementationInterfaceJson`,
  `CheckProofGradeRuntimeResidualHelperShellBoundary`, and
  `CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary`.
- Probe report/static checks for the newly exposed theorem names.
- Documentation updates in `docs/paper-theorem-profile.md` and
  `docs/top-tier-paper-execution-roadmap.md`.

Key files changed for this checkpoint:

- `proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean`
- `proof/lean/UOToolchain/RuntimeImplementationInterface.lean`
- `proof/lean/UOToolchain/RuntimeImplementationInterfaceJson.lean`
- `proof/lean/CheckProofGradeRuntimeResidualHelperShellBoundary.lean`
- `proof/lean/CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary.lean`
- `probe/mplus-probe/src/lib.rs`
- `docs/paper-theorem-profile.md`
- `docs/top-tier-paper-execution-roadmap.md`

The exact validation commands run at this stop point were:

```bash
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
```

All commands passed. Lean emitted existing linter warnings, not build failures.

## How To Resume

Start by reading these files in this order:

1. `docs/top-tier-paper-execution-roadmap.md`
2. `docs/paper-theorem-profile.md`
3. `docs/wp3-handoff-runbook.md`
4. `proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean`
5. `runtime/uo-evm/src/generated_oram_codecs.rs`
6. `probe/mplus-probe/src/lib.rs`

Then run the validation slice above before editing. Do not rely on stale local
mental state.

The next best technical target is to continue the same shrink-and-prove pattern
on the remaining Path-ORAM reconstruction and codec side:

1. Strengthen the bucket-indexed reconstruction model so the theorem exports
   cover the currently internal Lean facts not yet all projected through the
   imported checkers, especially:
   `bucketBlockAdmissionFailed_onPath`,
   `reconstructPathBucketBlockStep_priorFailure`,
   `reconstructPathBucketBlocks_cons`,
   `reconstructPathDecodedBucketsState_noBlocks`,
   `reconstructPathDecodedBucketsFailed_priorFailure`,
   `reconstructPathDecodedBucketsFailed_stashFailure`, and
   `reconstructPathDecodedBucketsFailed_noBlocks`.
2. Tie codec-level decoded bucket payload facts to helper-level `BucketBlock`
   reconstruction facts. Existing codec theorems prove decoded path buckets
   satisfy `LiveOnBucketPath`; the helper model now has the admission gate, but
   the next scientific step is a bridge theorem that maps decoded codec blocks
   into admitted helper bucket blocks.
3. Model the exact runtime callback structure:
   `with_opened_oram_payload` -> `decode_bucket_payload` -> per-block admission
   -> validation/update -> install.
4. Move any remaining public-only but currently handwritten reconstruction
   loops into generated Lean-backed helpers if the code still does meaningful
   work over decoded confidential payloads outside the helper model.
5. Extend the static drift suite to reject reintroduction of direct indexing,
   variable-size buffers, or secret-dependent control flow in those paths.

## End-To-End Completion Path

The full project should be completed by following the roadmap, not by claiming
WP3 done after local theorem additions.

Recommended order:

1. Complete the ORAM helper semantics side.
2. Complete the store codec semantics side.
3. Prove the generated Rust helper stack conforms to the Lean model or generate
   the Rust helper stack from Lean definitions with stable shape checks.
4. Shrink handwritten runtime shell code until it is public-only and small
   enough to audit mechanically.
5. Prove the residual shell cannot call secret-bearing operations except through
   the modeled/generated kernel APIs.
6. Run the full checker suite and regenerate reviewer artifacts.
7. Update the TCB table to distinguish formally proved pieces, generated pieces,
   checked Rust/Lean interface pieces, and remaining trusted pieces.

If a foreseeable step can be completed multiple ways, prefer the one with fewer
assumptions:

- Best scientific route: Lean-first/generated helper semantics. Define the
  model in Lean, generate or mechanically freeze the Rust helper, and prove the
  imported boundary route consumes that exact helper interface.
- Acceptable interim route: source-freeze plus static drift checks. This is
  useful for a checkpoint but should be treated as a temporary bridge, not a
  final paper claim.
- Weak route to avoid unless explicitly requested: document a runtime invariant
  without a Lean theorem, generated-code check, or static drift check.

## Exit Criteria

WP3 is fully complete only when all of the following hold:

- Every secret-bearing runtime operation in `uo-evm` is either inside the
  generated/Lean-backed kernel/helper stack or proved unreachable from the
  handwritten shell.
- The handwritten runtime shell has only public control flow, public indexing,
  fixed public buffer shapes, and public evidence emission.
- Lean exposes the small-kernel semantics, helper semantics, refinement route,
  and confinement theorem through paper-facing imported checker boundaries.
- The direct machine-confinement route and residual-helper-shell route expose
  the same relevant helper/kernel facts.
- The static drift suite fails on representative regressions:
  secret branch, secret index, early-exit ORAM scan, growable confidential
  buffer, handwritten generated-helper bypass, unchecked decoded-slot access,
  stale theorem name, stale report field, and stale source cut.
- `uo-check` is no longer in the trusted computing base for theorem checking,
  except for parsing/execution scaffolding that is independently cross-checked
  by Lean checker artifacts.
- The full Lean checker suite, targeted probe reports, static checks,
  `cargo check`, `cargo test` where applicable, and `git diff --check` pass.
- `docs/paper-theorem-profile.md` and `docs/top-tier-paper-execution-roadmap.md`
  accurately reflect the code, theorem exports, reports, and remaining TCB.

## Progress Tracking Convention

Use the matrix/checklist style already present in
`docs/top-tier-paper-execution-roadmap.md`. Do not maintain a hidden external
tracker.

When a theorem family or runtime shrink step lands:

1. Update the relevant work-package paragraph in
   `docs/top-tier-paper-execution-roadmap.md`.
2. Update `docs/paper-theorem-profile.md` if the guarantee, TCB, theorem list,
   or report surface changed.
3. Update `probe/mplus-probe/src/lib.rs` so the residual-helper and direct
   machine-confinement reports contain explicit `*_theorem_checked` bits.
4. Run targeted validation and record any new command in the handoff or roadmap
   if it becomes part of the standard checkpoint.
5. Commit only after the checkpoint is internally consistent and validation has
   passed.

Report fields should use snake case and end in `_theorem_checked` for theorem
facts, for example:

```json
{
  "oram_helper_reconstruct_path_decoded_buckets_failed_success_theorem_checked": true
}
```

Lean theorem exports should appear at all relevant layers:

- Base semantics in `UOToolchain.RuntimeOramHelperSemantics`.
- Interface projection in `RuntimeImplementationInterface`.
- Paper projection in `RuntimePaperNativeKernelAssumptions`.
- Imported JSON/checker projection in
  `RuntimeImplementationInterfaceJson` and the `CheckProofGrade*` files.
- Probe string checks in `probe/mplus-probe/src/lib.rs`.

## Context Not Fully Captured Elsewhere

The following details were learned while working and are easy to lose:

- `reconstruct_path_entries_from_storage_into` is the runtime function currently
  driving the Path-ORAM reconstruction shell. It resets entries, creates a fixed
  live-slot buffer, processes stash blocks, processes each bucket payload via a
  callback, rejects off-path occupied bucket blocks, validates live blocks,
  installs path entries, and finally checks position-map coverage.
- The current Lean model now has both a flat decoded-block shell and a stronger
  bucket-indexed shell. Prefer extending the bucket-indexed shell rather than
  adding more flat-list facts.
- Codec-level path bucket proofs already exist in
  `RuntimeOramCodecSemantics`: decoded path buckets can prove
  `LiveOnBucketPath`. The missing next bridge is not the path predicate itself;
  it is connecting those codec blocks to helper `BucketBlock` reconstruction.
- The probe intentionally checks both residual-helper-shell and direct
  machine-confinement routes. If only one route is updated, the paper story is
  weaker and the report can drift.
- Many files in the working tree are intentionally modified or untracked as part
  of the broader WP3 branch. Do not revert them unless the user explicitly asks.
- Existing Lean linter warnings in unrelated modules are not new blockers. Treat
  build failures, missing probe bits, and `git diff --check` failures as
  blockers.
