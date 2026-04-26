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
**W4.1** (real operational evaluator surface), **W4.1b** (secrecy-
lemma re-statement against the new evaluator), and the **W4.3
definitions side** (structural and count-based confidential-fragment
classifiers, definitions only) are landed as commits `6e234df`,
`267dc89`, `63cdd36`, and `4f30757`.

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
- `proof/lean/UOToolchain/ConfidentialFragment.lean` — the count-
  based witness that W4.3 will lift to a structural characterization.
- `crates/uo-core/src/ir.rs` — the canonical surface the Lean IR
  mirror tracks.
- `crates/uo-core/src/fragment.rs` — the Rust confidential-fragment
  classifier whose Lean mirror is part of W4.3.

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

The W4.3 *definitions* side is landed; the next subtask is the
**W4.3 iff theorem proper**:
`(confidentialFragmentEntrypointWitnessOf fn).Valid ↔
fn.fragmentValid = true`. The classifier
(`IR.confidentialFragmentEntrypointWitnessOf`), the structural
predicate (`IR.CompiledFunction.fragmentValid`), and the count-
based classifier (`IR.CompiledFunction.fragmentStats`) all exist.
What is missing is the iff proof.

**Subtask W4.3 (theorem): prove the confidential-fragment iff
characterization.**

The natural proof strategy is structural induction on `Expr` and
`Statement`. Lean 4.30.0-rc2's default `induction` tactic does not
support nested-inductive types, so the proof needs one of:

1. **Mutual recursive `def`-style proof** — define the iff proof as
   a `def` returning `Iff` propositions, structured with mutual
   recursion (mirroring the existing
   `Expr.fragmentValid` / `Expr.fragmentValidList` mutual pair).
   Lean's structural recursion accepts this form. Probably the
   cleanest path.
2. **Manual recursor application** — use `Expr.recOn` /
   `Statement.recOn` directly via `refine` with explicit motives for
   `Expr`/`Statement` and the nested `List Expr`/`List Statement`.
3. **Restructure the IR types** — replace nested-inductive
   `Statement.ifStmt cond (List Statement) (List Statement)` with
   explicit mutual `Statement` / `StatementList` inductives. Higher
   churn but enables the standard `induction` tactic.

Recommendation: try approach (1) first.

Prove three lemmas in sequence (see the runbook's "Recommended
Starting Subtask" section for the exact statements):

1. `Expr.fragmentStats_valid_iff` per expression.
2. `Statement.fragmentStats_valid_iff` per statement.
3. `confidentialFragmentEntrypointWitnessOf_valid_iff` per function.

Project through `ProofGrade.lean` as
`proofGrade_confidential_fragment_valid_iff_structurally_valid` (or
similar). Optionally also prove that `fragmentValid → evalContract`
never returns `EvalStatus.unsupported`, which establishes that the
W4.1 evaluator covers the confidential-fragment surface.

If you would prefer to drive W4.2 (source-to-IR correctness)
instead, the runbook's "Recommended Starting Subtask" section
explains the AST-pull-back framing that makes W4.2 tractable. W4.2
is roughly 2-3× the effort of completing W4.3.

After W4.3 (theorem) lands, the natural sequence is:

- W4.2 — source-to-IR correctness theorem (deliverable 1).
- W4.4 — IR-to-kernel correctness theorem (deliverable 2).
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

Begin with the runbook. The first technical step is the W4.3 iff
theorem (its definitions side is already landed). If you prefer
strict deliverable order, the runbook's "Recommended Starting
Subtask" section also documents the W4.2 AST-pull-back framing.
