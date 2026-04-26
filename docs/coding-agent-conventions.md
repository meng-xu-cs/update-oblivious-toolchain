# Coding-Agent Conventions

This note collects the working practices that follow-on coding agents
(typically Claude Opus 4.7 with maximum reasoning effort) should rely on
when adding theorems, runtime cuts, or proof-grade artifacts to this
repository. These conventions are work-package-agnostic: they apply equally
to WP3 polish, WP4 source-to-kernel correctness, WP5 backend assumption
discharge, WP6 hostile-host TEE work, and any future-strengthening tracks.

The repository's authoritative status documents remain
`docs/top-tier-paper-execution-roadmap.md` (work-package narrative + exit
gates), `docs/paper-theorem-profile.md` (theorem and TCB profile),
`docs/formal-proof-plan.md` (proof structure), and
`docs/implementation-roadmap.md` (milestone status). This file describes
*how to do work* in the repository, not *what work remains*.

## Project Strategy In One Block

The strongest current route is not just "run `uo-evm` inside a TEE." The
target story is:

1. Shrink all confidential runtime work into a tiny kernel and generated
   helper stack.
2. Make the Rust runtime shell public-only: it may schedule public work,
   allocate fixed public buffers, serialize public metadata, and call
   generated helpers, but it must not branch, index, loop, allocate, or
   emit evidence based on secrets.
3. Define a Lean model for the tiny kernel and the generated helper
   semantics.
4. Prove checked runtime/interface artifacts refine the Lean model.
5. Prove the remaining handwritten shell cannot perform secret-dependent
   work outside the modeled/generated kernel.

Every concrete deliverable should fit somewhere on this five-step axis.
When in doubt, classify the work, then pick the existing pattern.

## Scientifically-Strongest-Route Preference

When a step can be completed multiple ways, prefer the route with the
fewest external assumptions and the strongest mechanically-checked
surface:

- **Best (default).** Lean-first / generated-helper semantics. Define the
  model in Lean, generate the Rust helper from the Lean definition, and
  prove the imported boundary route consumes that exact helper interface.
  The generator output is exact-string-checked against the on-disk Rust
  file by the probe.
- **Acceptable interim.** Source-freeze plus static drift checks at the
  source-backed implementation interface. This is a real boundary cut
  but not a deep refinement; it is appropriate for runtime cuts that are
  too large to model directly in one checkpoint.
- **Avoid unless explicitly requested.** A documented runtime invariant
  with no Lean theorem, no generated-code check, and no static drift
  check. This buys nothing for the paper.

Treat source-freeze-only checks as temporary bridge work, not final
paper claims.

## Five-Layer Projection Pattern

When a new helper-semantics theorem lands at the base layer, project it
through five layers in this exact order, then expose it from the probe.
This pattern is uniform across the codebase:

1. **Base semantics.** The proof is stated and proved in the appropriate
   `proof/lean/UOToolchain/<X>Semantics.lean` (`RuntimeOramHelperSemantics`,
   `RuntimeOramCodecSemantics`, `RuntimeStoreCodecSemantics`,
   `RuntimeStoreHelperSemantics`, etc.).
2. **Implementation-interface projection.** Forward the theorem under
   `RuntimeImplementationInterface.residualHelperShellBoundary_<theoremName>`
   in `proof/lean/UOToolchain/RuntimeImplementationInterface.lean`. This
   is a one-line forwarding lemma: assume `iface.ResidualHelperShellBoundary`,
   produce the base theorem.
3. **Paper-native projection.** Forward again under
   `RuntimePaperNativeKernelAssumptions.<theoremName>` in the same file,
   using `RuntimePaperNativeKernelAssumptions.residualHelperShellValid`
   to discharge the boundary precondition.
4. **Imported JSON projection.** Forward again under
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_<theoremName>`
   in `proof/lean/UOToolchain/RuntimeImplementationInterfaceJson.lean`,
   using `boundary.toRuntimePaperNativeKernelAssumptions hValid`.
5. **Both checker-side projections.**
   - In `proof/lean/CheckProofGradeRuntimeResidualHelperShellBoundary.lean`,
     forward under `importedBoundaryOramHelper<TheoremName>`.
   - In `proof/lean/CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary.lean`,
     forward under `importedBoundaryPaperNative<TheoremName>`.

After Lean compiles, expose the theorem in the probe (`probe/mplus-probe/src/lib.rs`):

- Emit the report bit `<snake_case_theorem_name>_theorem_checked: true` in
  both the `runtime_residual_helper_shell_boundary_validation.json` and
  `runtime_implementation_kernel_machine_confinement_boundary_validation.json`
  reports (two emission sites per route: the inline JSON literal and the
  static-drift `oram_helper_report_bits` list).
- Add the snake_case theorem name to the static-drift `oram_helper_semantics_bits`
  list so that *deletion of the base theorem* is rejected.
- Add the projection identifier to each of the four projection-name lists
  (residual-helper interface, residual-helper checker, kernel-machine
  imported, kernel-machine checker).

If only one of the two routes is updated, the probe report will pass on
that route but drift will appear at the other. The two-route discipline is
not optional: the paper claim depends on both routes exposing the same
relevant helper/kernel facts.

## Naming Conventions

- **Probe report fields.** `snake_case`, ending in `_theorem_checked` for
  theorem facts. Example: `oram_helper_reconstruct_path_decoded_buckets_failed_success_theorem_checked`.
- **Lean theorem aliases.** The base name is the theorem itself; the
  forwarding lemmas at each layer mechanically follow the layer's prefix
  convention (`residualHelperShellBoundary_oramHelper<...>`,
  `RuntimePaperNativeKernelAssumptions.oramHelper<...>`,
  `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelper<...>`,
  `importedBoundaryOramHelper<...>` for residual-helper, and
  `importedBoundaryPaperNativeOramHelper<...>` for the direct-machine
  route).
- **Drift suite enumeration.** When extending the drift suite for a new
  theorem family, add the theorem name to `oram_helper_semantics_bits`
  (the lean source the suite checks for) AND the report bit string to
  `oram_helper_report_bits` AND the projection alias to each of the
  matching alias lists. Forgetting any one of these allows silent
  regression.

## Progress Tracking Convention

Use the matrix/checklist style already present in
`docs/top-tier-paper-execution-roadmap.md`. Do not maintain a hidden
external tracker.

When a theorem family or runtime shrink step lands:

1. Update the relevant work-package paragraph in
   `docs/top-tier-paper-execution-roadmap.md`. The work-package status
   text is the canonical place for "what we just proved."
2. Update `docs/paper-theorem-profile.md` if the guarantee, TCB, theorem
   list, or report surface changed. The "What is still open" list and the
   TCB table are the canonical place for "what we still trust" vs "what we
   now prove."
3. Update `probe/mplus-probe/src/lib.rs` so the residual-helper-shell and
   direct machine-confinement reports emit explicit `*_theorem_checked`
   bits, matching the new theorems.
4. Run the targeted validation slice (see below). Record any new probe
   scenario in the roadmap if it becomes part of the standard checkpoint.
5. Commit only after the checkpoint is internally consistent and validation
   has passed.

Do not document a runtime invariant in only the roadmap or only the theorem
profile. The convention is: theorem-level facts go through the five-layer
projection AND get a probe report bit AND get static-drift coverage. A fact
that lives only in prose drifts.

## Validation-Slice Protocol

The minimum recurring set is in
`docs/top-tier-paper-execution-roadmap.md`'s Validation Gates section.
For incremental theorem additions in any work package, this shorter
slice is normally sufficient before commit:

```bash
cd <repo-root>
cargo fmt --all
cd proof/lean
lake build UOToolchain.RuntimeImplementationInterfaceJson \
  CheckProofGradeRuntimeResidualHelperShellBoundary \
  CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary
cd ..
cargo check -p mplus-probe
cargo run -q -p mplus-probe -- --only runtime-residual-helper-shell-boundary-validation \
  --out-dir results > /tmp/uo-residual-helper-validation.json
cargo run -q -p mplus-probe -- --only runtime-implementation-kernel-machine-confinement-boundary-validation \
  --out-dir results > /tmp/uo-kernel-machine-validation.json
cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation \
  --out-dir results > /tmp/uo-kernel-model-alignment-validation.json
cargo run -q -p mplus-probe -- --only static-checks \
  --out-dir results > /tmp/uo-static-checks.json
git diff --check
```

For larger checkpoints (new boundary cuts, new tamper scenarios, new
Cargo dependencies, schema changes), run the full Validation Gates set.

Always cross-check before declaring success:

- Probe exit code is `0` for every scenario.
- Top-level `"accepted": true` in each report (one of the first JSON keys).
- `git diff --check` clean (no whitespace damage).
- For `tamper-validation` specifically: every individual scenario has
  `"accepted": false` AND `"rejected": true`. Counting scenarios with
  `"accepted": false` and treating them as failures is wrong — those are
  the negative tests. Confirm `rejected: true` matches `scenario_count`.

## Working Practices For Coding Agents

- **Auto-continue when the next step is clear.** Do not ask for a
  checkpoint or status-only pause if a clear next technical step is
  available. Stop only if a human policy or design decision is genuinely
  needed.
- **Prefer plurality of small commits over one large commit.** Each
  coherent checkpoint that passes validation is a commit. Large
  refactor-everything commits are hard to bisect when the static drift
  suite reports a regression three weeks later.
- **Commit messages document the *why*.** Explain what assumption the
  checkpoint addresses, what theorem family lands, what specific drift it
  closes. The body should outlive the diff.
- **Do not revert unrelated dirty files.** Many files in the working tree
  are intentionally modified or untracked as part of the broader branch.
  Do not run `git checkout .` or `git restore .`. If a file looks
  unfamiliar, ask before deleting it.
- **Lean linter warnings are not blockers.** The Lean development emits
  background `simp` lint warnings and unused-argument warnings in older
  modules. These have been triaged. Treat *build failures*, *missing probe
  bits*, and `git diff --check` failures as blockers; treat lint-only
  warnings as background noise.
- **`cargo fmt` only works from the repo root.** Running `cargo fmt` from
  inside `proof/lean` fails because that directory is not a Cargo
  workspace. Use `cargo fmt --all` from the repo root.
- **`lake build` only works from `proof/lean`.** The validation slice
  always switches to that directory first; remember to switch back before
  running cargo commands again.
- **The probe's source-cut list lives in
  `runtime_implementation_interface_artifact()`.** When new files are
  added under `runtime/uo-evm/src/`, `runtime/uo-allocator/src/`,
  `runtime/uo-store/src/`, `runtime/uo-kernel-runtime/src/`, or
  `runtime/uo-precompiles/src/`, they must also be added to that
  enumeration AND to the `RuntimeImplementationInterface` Lean struct.
  Otherwise the new file slips past the source-backed boundary entirely.
- **Crypto-primitive identity is part of the source cut.** The AEAD
  primitive (`chacha20poly1305`) and the hash primitive
  (`tiny_keccak::Keccak::v256()`) are pinned at the source-backed
  boundary, including the workspace `Cargo.toml` versions. Substituting
  alternative primitives must be a deliberate, documented change that
  updates the pin in lockstep.
- **`uo-check` is no longer in the proof-grade TCB.** The proof-grade
  acceptance path goes through direct Lean source/artifact checking. Do
  not reintroduce `uo-check` as a gating step.
- **The `probe/mplus-probe` binary is not in the proof-grade TCB.** It
  orchestrates Lean checkers and source-cut checks. The probe's
  correctness affects which scenarios are run, but the proof terms it
  invokes live in Lean. Bugs in the probe surface as missing report bits;
  bugs in Lean surface as build failures or rejected witnesses.
- **Both checker routes must agree.** Every helper/kernel theorem that
  lands at the residual-helper-shell route should also land at the direct
  kernel-machine confinement route. The probe intentionally checks both;
  if only one route is updated, the paper story is weaker and the report
  drifts.

## Common Pitfalls (From Lived Experience)

- **String mismatches between Rust crate name and `use` form.** Cargo
  uses `tiny-keccak`; Rust uses `tiny_keccak`. The pin must check the
  right form on each side.
- **Workspace `Cargo.toml` has crates not used by the runtime.** `sha2`
  is used by the probe for content hashing, not by the runtime. Negative
  pins like `!workspace_cargo_toml.contains("sha2")` are wrong; restrict
  negative pins to the actual runtime crates' `Cargo.toml` files.
- **`accepted: false` in tamper output is *expected*.** Each tamper
  scenario constructs a malformed artifact and confirms rejection. The
  failure signal is the *number* of scenarios with `rejected: true`
  matching `scenario_count`, not the presence of `accepted: false`.
- **Five-layer projection requires consistent argument ordering.** When
  forwarding through layers, the argument order in the forwarding lemma
  must match the base theorem's argument order. Lean will complain if it
  doesn't, but a lemma that compiles can still expose the wrong argument
  order at the report bit level. Cross-check by reading the base
  theorem's signature.
- **`List.mem_cons_self` does not take arguments.** In the Lean version
  used here it is `bb ∈ bb :: bs` directly; pattern `(by simp)` is the
  reliable way to discharge the head-membership obligation.
- **Probe edits without `cargo check -p mplus-probe`.** The probe is a
  big Rust file with many tightly-coupled string literals. Always run
  `cargo check -p mplus-probe` before declaring an edit done.
- **Forgetting one of the four projection-alias lists in the static
  drift suite.** Each new theorem requires entries in all four lists
  (residual-helper interface aliases, residual-helper checker aliases,
  kernel-machine imported aliases, kernel-machine paper-native aliases).
  Missing entries cause silent drift.
- **`lake build` from the wrong directory.** From repo root, the command
  is `cd proof/lean && lake build ...`. From `proof/lean`, it is just
  `lake build ...`. Mixing them up gives "no such target" errors.
- **`results/*.json` regenerate on every probe run.** They will appear in
  `git status`. They are committed deliberately as part of the
  reproducibility audit; include them in the commit if you ran the
  probe.

## Onboarding Path For A Fresh Agent

A new agent picking up work in this repository should read in this order:

1. `docs/top-tier-paper-execution-roadmap.md` — the work-package
   narrative, exit gates, and validation slice.
2. `docs/paper-theorem-profile.md` — the theorem profile, the explicit
   assumption table, the TCB table.
3. `docs/coding-agent-conventions.md` (this file) — engineering process.
4. `docs/formal-proof-plan.md` — the broader proof structure.
5. The Lean files relevant to the chosen work package (e.g.,
   `proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean` for ORAM
   work, `proof/lean/UOToolchain/RuntimeImplementationInterface.lean`
   for the source-backed boundary).
6. The probe file `probe/mplus-probe/src/lib.rs` — the orchestration and
   drift suite.

Before editing anything, run the validation slice. Do not rely on stale
local mental state about which scenarios are green.
