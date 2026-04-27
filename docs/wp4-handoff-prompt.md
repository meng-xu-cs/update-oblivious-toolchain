# WP4 Handoff Prompt

Paste the block below into a fresh coding-agent session
(Claude Opus 4.7 with maximum reasoning, plan mode off, auto-continue
on) to resume Work Package 4. The prompt is self-contained: it sets
the role, the scope, the auto-continue posture, and the first
technically-clear step.

If a prior conversation summary is supplied, this prompt is still
authoritative for what the agent should do next; the summary is
context, not instruction.

---

You are continuing work on the **update-oblivious-toolchain** research
artifact, a top-tier paper submission targeting ACM CCS or IEEE S&P.
The headline theorem is end-to-end obliviousness for an admitted
Solidity subset compiled to a tiny confidential kernel running inside
a TEE under a hostile-host adversary (M+ model).

You are now picking up **Work Package 4: Prove Source-To-Kernel
Compiler Correctness**. Work Packages 0–3 are closed. WP4 charter
tasks **1, 2, 3, and 4 are now Lean-proved**:

- W4.1 / W4.1b / W4.1+ / W4.1++ / W4.1+++: real operational
  evaluator over the structured admitted IR, total over the W4.3
  fragment, with masked-store updates.
- W4.2 (Sol AST mirror + evaluator + AST → IR lowering + per-Expr
  / per-Statement / Body / Function preservation theorems +
  paper-facing facade): the `proofGrade_sol_to_ir_program_
  preservation` theorem certifies that for every Sol function
  `fn` and IR `OperationalConfig` whose entrypoint resolves to
  `lowerFunction fn`, the Sol-side `evalFunction` and the IR-side
  `evalContract` produce identical outcomes. Closed end-to-end
  for the full admitted post-resolution Sol AST. The parser-level
  syntactic preprocessing (state-name resolution, capacity
  literal lookup, `abi.encodePacked` unwrapping, helper-function
  inlining, `AssignAdd`-style desugaring) is the trusted
  front-end that produces the post-resolution Sol AST consumed by
  the theorem.
- W4.3 (full theorem + paper facade):
  `(IR.confidentialFragmentEntrypointWitnessOf fn).Valid ↔
  fn.fragmentValid = true`.
- W4.4 (Session A typed kernel DSL + B-1 forward iff at all four
  levels + B-2 semantics-preservation theorem at all four levels +
  C paper-facing facade): the `proofGrade_ir_to_kernel_program_
  preservation` theorem certifies that for every kernel-lowerable
  function `fn` and IR `OperationalConfig` whose entrypoint
  resolves to `fn`, the IR-side `evalContract` and the kernel-side
  `evalKernelProgram` (on `lowerCompiledFunction fn`) produce
  identical outcomes.

Combined, W4.2 + W4.4 yield the source-to-kernel correctness chain
end-to-end on the full admitted post-resolution Sol AST. The W4.5
enabling theorem `proofGrade_sol_to_kernel_outcome_preservation`
projects this composition through `ProofGrade.lean`: for every Sol
function `fn` whose lowering to a kernel program `kp` succeeds and
every IR `OperationalConfig` whose entrypoint resolves to the
lowered function, `Sol.evalFunction fn cfg = IR.evalKernelProgram
kp cfg`. The W4.5 main body adds static projections on
`IR.KernelProgram` (`expectedKernelSteps`,
`expectedKernelStepCount`, `expectedObjectWriteIds`), paper-facing
facades exposing each, source-side handles via the lowering chain,
and per-statement / body-level / program-level runtime-vs-static
lifts. The supporting invariant
`evalKernelExpr_status_ne_completed` (the kernel-DSL expression
evaluator never returns `.status .completed`) is the prerequisite
for the runtime-vs-static lift; with it, the per-statement
`evalKernelStatement_kernelSteps_eq_expected_of_completed`,
body-level
`evalKernelBody_kernelSteps_eq_expected_of_completed`, and program-
level
`evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_completed`
theorems are all Lean-proved end-to-end. Paper-facing facades
`proofGrade_kernel_program_runtime_kernel_steps_eq_expected` and
`proofGrade_sol_to_kernel_runtime_kernel_steps_eq_expected` expose
the program-level fact and its source-side composition.

The W4.4 reverse iff direction is now also landed: the per-Expr /
per-Statement / program-level theorems
(`lowerExpr_ok_implies_fragmentValid` and friends in
`KernelDsl.lean`) plus the paper-facing iff facades in
`ProofGrade.lean` close the W4.4 lowering iff at every level.

WP4 charter task **6** (direct artifact-checker demotion) is the
only remaining open task — and with W4.4 reverse iff now landed,
W4.6 reduces to a doc / role-swap task.

## First, Read These Files In This Exact Order

1. `docs/wp4-handoff-runbook.md` — your charter for this work
   package, the existing infrastructure, and the recommended next
   subtask. This is the document that tells you *what to do*.
2. `docs/coding-agent-conventions.md` — the engineering process for
   this repository. This is the document that tells you *how to do
   it*. Pay special attention to:
   - "Scientifically-Strongest-Route Preference"
   - "Claim And TCB Discipline"
   - "Validation-Slice Protocol"
   - "Working Practices For Coding Agents"
   - "Common Pitfalls"
3. `docs/top-tier-paper-execution-roadmap.md` — the work-package
   narrative; section "Work Package 4" is your charter.
4. `docs/paper-theorem-profile.md` — the theorem profile, TCB table,
   "What is still open" list.
5. `docs/formal-proof-plan.md` — the broader proof structure.

Then read the WP4-relevant Lean and Rust files listed in the runbook.
Pay special attention to:

- `proof/lean/UOToolchain/Sol.lean` — the typed Sol AST mirror,
  evaluator, AST → IR lowering, and the W4.2 preservation
  theorems for the structural fragment.
- `proof/lean/UOToolchain/IRSyntax.lean` — the structured IR mirror
  of `crates/uo-core/src/{ir,types}.rs` that landed in W4.1.
- `proof/lean/UOToolchain/IRSemantics.lean` — the new operational
  evaluator (`Semantics := IR.OperationalConfig → IR.Outcome`,
  `evalContract`) plus the preserved abstract trace-producer surface
  (`TraceSemantics`).
- `proof/lean/UOToolchain/CompilerInvariant.lean` — both the
  trace-side `compilerSecrecyPreservation` and the new evaluator-side
  `evaluatorCompilerSecrecyPreservation`.
- `proof/lean/UOToolchain/ConfidentialFragment.lean` — the
  W4.3-landed structural classifier and characterization theorem;
  the W4.4 lowering theorem will use the `Expr.fragmentValid`
  predicate as the lowering precondition.
- `proof/lean/UOToolchain/RuntimeKernelDslJson.lean` — the kernel-
  DSL Lean mirror (`ImportedConfidentialKernelStatement` /
  `Expr` / `PureExpr` mutual inductives); W4.4 adds an operational
  semantics on top.
- `crates/uo-core/src/ir.rs` — the canonical IR surface the Lean
  IR mirror tracks.
- `crates/uo-core/src/confidential_kernel.rs` — the Rust kernel-DSL
  data types and the lowering function `lower_confidential_kernel_*`
  that W4.4 mirrors and proves correct.

## Operating Posture

- **Auto-continue.** Do not pause for confirmation when the next
  technical step is clear. Stop only if a human policy or design
  decision is genuinely required, or if validation has failed in a
  way that needs human input to triage.
- **Small commits.** Each coherent technical step that passes the
  validation slice is its own commit. The commit message documents
  *why* (which assumption moved from exactness/export to
  semantics-preserving, which manifest field or lowering stage it
  covers). Do not amend prior commits.
- **Patch-style edits.** Manual edits are reviewable patches.
  Generated artifacts (Rust emitted from Lean, Lean inductives
  mirroring Rust enums) prefer the source-of-truth path; if you
  edit a generated file directly, update the generator/source-freeze
  checks in the same checkpoint.
- **Run the validation slice before declaring success.** Probe exit
  code 0, top-level `"accepted": true` in each non-static report,
  static-checks restriction flags all `true`, `git diff --check`
  clean, tamper-validation `rejected: true` count matches scenario
  count. The conventions doc has the exact slice; the runbook has
  the WP4-augmented slice.
- **Preserve unrelated dirty files.** Do not run `git checkout .`,
  `git restore .`, or any destructive git command without confirming
  with the user.
- **Lean lint warnings are not blockers.** Build failures, missing
  probe bits, and `git diff --check` failures are blockers; lint
  noise is not.

## Scope Discipline

WP4 lives *above* the kernel DSL boundary. The runtime side closed
in WP3 and must stay green. If your edits would change the
residual-helper-shell route or the direct kernel-machine-confinement
route, stop and reconsider — that is WP3 territory. WP4 theorems
land in:

- `proof/lean/UOToolchain/IRSyntax.lean`
- `proof/lean/UOToolchain/IRSemantics.lean`
- `proof/lean/UOToolchain/Sol.lean`
- `proof/lean/UOToolchain/KernelDsl.lean`
- `proof/lean/UOToolchain/CompilerInvariant.lean`
- `proof/lean/UOToolchain/ConfidentialFragment.lean`
- `proof/lean/UOToolchain/CompilerExactness.lean`
- `proof/lean/UOToolchain/ProofGrade.lean`
- and as needed `proof/lean/UOToolchain/TranslationValidationJson.lean`

## Recommended Next Subtask

W4.4 Session B-1 is landed; the next subtask is **W4.4 Session B-2**:
the semantics-preservation theorem.

The next subtask is one of:

**Option (a) — W4.6 direct artifact-checker demotion.**
With W4.2 + W4.4 + W4.5 all closed, the only remaining "compiler-
side" charter task is W4.6: demote `checkProofGradeTranslationArtifacts`
from "main trust argument" to "executable proof witness for the
proven compiler story." This requires the reverse direction of the
W4.4 lowering iff (`lowerExpr e = .ok ke → Expr.fragmentValid e =
true`) plus a doc update to the WP4 trust narrative.

**Option (b) — W4.6 direct artifact-checker demotion.**
Demote the existing `checkProofGradeTranslationArtifacts` Lean
checker from "main trust argument" to "executable proof witness for
the proven compiler story." The checker doesn't need to disappear
— it just changes role from gating step to corroborating witness.
This requires the reverse direction of the W4.4 lowering iff
(`lowerExpr e = .ok ke → Expr.fragmentValid e = true`) plus a doc
update to the WP4 trust narrative.

Recommend option (a) — W4.6 — as the last remaining compiler-side
charter task; the W4.5 chain is now fully landed.

After W4.6 lands, all six WP4 charter tasks are closed.

## Validation Slice (Standard WP4 Variant)

```bash
cd <repo-root>
cargo fmt --all
cd proof/lean
lake build UOToolchain.IRSyntax \
  UOToolchain.IRSemantics \
  UOToolchain.Sol \
  UOToolchain.KernelDsl \
  UOToolchain.CompilerInvariant \
  UOToolchain.CompilerExactness \
  UOToolchain.ConfidentialFragment \
  UOToolchain.ProofGrade \
  UOToolchain.RuntimeImplementationInterfaceJson \
  CheckProofGradeRuntimeResidualHelperShellBoundary \
  CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary
cd ../..
cargo check -p mplus-probe
cargo check -p uo-core -p uo-solc
cargo run -q -p mplus-probe -- --only confidential-fragment-validation \
  --out-dir results > /tmp/uo-confidential-fragment-validation.json
cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation \
  --out-dir results > /tmp/uo-kernel-model-alignment-validation.json
cargo run -q -p mplus-probe -- --only runtime-residual-helper-shell-boundary-validation \
  --out-dir results > /tmp/uo-residual-helper-validation.json
cargo run -q -p mplus-probe -- --only runtime-implementation-kernel-machine-confinement-boundary-validation \
  --out-dir results > /tmp/uo-kernel-machine-validation.json
cargo run -q -p mplus-probe -- --only static-checks --out-dir results \
  > /tmp/uo-static-checks.json
git diff --check
```

For larger checkpoints (new probe scenarios, new Cargo dependencies,
schema changes), run the full Validation Gates set
(`scripts/run_validation.sh`).

## Claim Discipline

When updating the roadmap status text or the paper theorem profile,
classify each WP4 claim explicitly:

- **Lean-proved, semantics-preserving.** A theorem in
  `IRSemantics.lean` / `CompilerInvariant.lean` /
  `ConfidentialFragment.lean` / `CompilerExactness.lean` /
  `ProofGrade.lean` that relates the source program's *meaning* to
  the lowered IR or kernel's *meaning*. This is the WP4 bar.
- **Lean-proved, exactness/export.** Same-data fact (e.g., manifest
  field equals compiler-computed value). `ProofGradeCompilerFacts`
  is currently in this bucket; WP4 promotes it field-by-field.
- **Source-frozen / static-drift checked.** Probe rejects drift in
  Rust source; not a semantic theorem.
- **Trusted.** `uo-solc` is currently in this bucket; the WP4 exit
  gate removes it. W4.1 / W4.1b did *not* remove it — they only
  added the Lean-side operational evaluator the WP4 theorems will
  refine against.

Never write "WP4 proves source-to-kernel correctness" unless
deliverables 1, 2, 3 are all real semantics-preserving theorems
projected through `ProofGrade.lean`.

## When To Stop

Stop and write an updated handoff (replacing
`docs/wp4-handoff-runbook.md` and `docs/wp4-handoff-prompt.md`,
following the same content discipline) when any of:

- Context limits force a session boundary.
- A genuine human policy or design decision is needed (e.g., a
  trade-off between richer admitted subset vs. proof effort).
- A subtask is fully landed and the next one is scoped large enough
  to deserve its own session.
- Validation has failed in a way that needs human triage.

The handoff must name the exact subtask checkpoint, the validation
commands just run, the known remaining gaps, and the next
recommended technically-clear step. See *"Write a handoff before
stopping on a long-running work package"* in
[`coding-agent-conventions.md`](./coding-agent-conventions.md#working-practices-for-coding-agents)
for the content requirements.

## Final Reminders

- Do not regress WP3. The runtime residual-helper-shell route and
  the direct kernel-machine-confinement route stay green.
- Do not weaken `ProofGradeCompilerFacts`. Strengthen it.
- Do not weaken the W4.1 evaluator. Adding new evaluator cases is
  fine; *removing* existing cases or downgrading them to
  `EvalStatus.unsupported` is a regression of the evaluator's
  coverage surface.
- Do not promote source-freeze checks to "proved." Demote the
  direct artifact checker (charter task 6); do not invert this.
- Do not reintroduce `uo-check` as a gating step.
- Do not add a probe report bit unless it is backed by a Lean
  theorem.

Begin with the runbook. The recommended next subtask is W4.6
(artifact-checker demotion, the last remaining "compiler-side"
charter task — smaller scope but mostly a doc / role-swap).
