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
Compiler Correctness**. Work Packages 0–3 are closed. WP4 subtasks
**W4.1**, **W4.1b**, **W4.3** (full theorem + paper facade),
**W4.1+**, **W4.1++**, **W4.1+++** (store-update threading),
**W4.4 Session A** (typed kernel DSL + semantics + lowering
definitions), and **W4.4 Session B-1** (forward-direction lowering
iff theorems at all four levels: Expr / Statement / schedule /
program) are all landed. The W4.1 evaluator is total over the
structural admitted fragment with masked-store semantics; the
kernel-DSL Lean mirror shares the same `IR.Outcome` type so the
W4.4 preservation theorem can be a literal outcome equality; and
every kernel-lowerable IR program is now provably lowerable to a
kernel program. The next subtask is W4.4 Session B-2 (semantics-
preservation theorem) followed by Session C (paper-facing facade).

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
- `proof/lean/UOToolchain/CompilerInvariant.lean`
- `proof/lean/UOToolchain/ConfidentialFragment.lean`
- `proof/lean/UOToolchain/CompilerExactness.lean`
- `proof/lean/UOToolchain/ProofGrade.lean`
- and as needed `proof/lean/UOToolchain/TranslationValidationJson.lean`

## Recommended Next Subtask

W4.4 Session B-1 is landed; the next subtask is **W4.4 Session B-2**:
the semantics-preservation theorem.

**Subtask W4.4 Session B-2: Semantics-preservation theorem.**

Concretely:

1. Prove per-Expr / per-Statement preservation lemmas in
   `KernelDsl.lean`:
   - `lowerExpr_preserves_semantics`: `lowerExpr e = .ok ke →
     evalExpr cfg env e = evalKernelExpr cfg env ke`
   - `lowerPureExpr_preserves_semantics`: analogous for pure exprs
   - `lowerStatement_preserves_semantics`: lifts to statements
   - `lowerStatements_preserves_semantics`: lifts to lists
2. Prove the program-level theorem:
   `lowerCompiledFunction fn = .ok kp →
     ∀ cfg env outcome, evalBody cfg env outcome fn.body =
       evalKernelBody cfg env outcome kp.body`
   (or the entrypoint-level form via `evalContract` /
   `evalKernelProgram`).
3. Session C will project this through `ProofGrade.lean` as
   `proofGrade_ir_to_kernel_correctness` and update the WP4 status
   text.

The structural recursion mirrors Session B-1's forward iff
proofs but is bigger because the `do`-notation reductions in both
`lowerExpr` (when `lowering = .ok ke`) and `evalExpr` /
`evalKernelExpr` need to be threaded together. Expect to reuse the
same `unfold + simp + rfl` tactic pattern that worked for the
Session B-1 forward iffs.

If you would prefer to drive **W4.2** (source-to-IR correctness)
instead, see the runbook's "Recommended Starting Subtask" section
for the AST-pull-back framing. W4.2 is roughly 2-3× the effort of
W4.4 because it requires a partial Lean Solidity parser AST
mirror.

After W4.4 lands, the natural sequence is:

- W4.2 — source-to-IR correctness theorem (deliverable 1).
- W4.5 — manifest-exactness lift (from exactness/export to
  semantics-preserving, per field).
- W4.6 — demote the direct artifact checker (charter task 6).

## Validation Slice (Standard WP4 Variant)

```bash
cd <repo-root>
cargo fmt --all
cd proof/lean
lake build UOToolchain.IRSyntax \
  UOToolchain.IRSemantics \
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

Begin with the runbook. The first technical step is W4.4 Session
B-2 (semantics-preservation theorem; B-1 forward iffs are landed).
If you prefer strict deliverable order, the runbook's "Recommended
Starting Subtask" section also documents the W4.2 source-to-IR
AST-pull-back framing.
