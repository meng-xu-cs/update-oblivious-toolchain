# WP4 Handoff Runbook

This runbook hands off Work Package 4 (WP4) — *prove source-to-kernel
compiler correctness for the admitted Solidity subset* — to the next
coding agent.

It does not duplicate the engineering process. The authoritative
process document is
[`coding-agent-conventions.md`](./coding-agent-conventions.md). Read it
first; this runbook only carries the WP4-specific facts that don't
belong in a process doc.

## Where We Are

WP3 closed on 2026-04-26. WP4 then opened with the goal of replacing
the placeholder `abbrev Semantics := Config → Trace` and proving real
source-to-kernel correctness for the admitted Solidity subset.

Subtasks **W4.1**, **W4.1b**, **W4.3 (full theorem)**, and **W4.1+
(evaluator coverage extension)** landed on 2026-04-26 (commits
`6e234df`, `267dc89`, `63cdd36`, `4f30757`, `5ef3bdd`, `08f669a`,
`94ba337`, and `9f0e45e`):

- A structured Lean mirror of `crates/uo-core/src/{ir,types}.rs` lives
  in [`proof/lean/UOToolchain/IRSyntax.lean`](../proof/lean/UOToolchain/IRSyntax.lean).
  It covers `ProgramMode`, `ContainerKind`, `BackendKind`,
  `StateObject`, `UnaryOp`, `BinaryOp`, `Expr`, `Statement`,
  `CompiledFunction`, `CompiledContract`, plus a `Value` / `Ty`
  universe with composite struct/array variants.
- The placeholder `abbrev Semantics := Config → Trace` is replaced by
  `abbrev Semantics := IR.OperationalConfig → IR.Outcome` in
  [`proof/lean/UOToolchain/IRSemantics.lean`](../proof/lean/UOToolchain/IRSemantics.lean).
  `IR.Outcome` carries the existing `Trace`, the entrypoint's public
  return value, the per-object ORAM-access counts, the manifest-
  relevant kernel-step list, and an explicit `EvalStatus`
  (`completed`, `requireFailed`, `abortedByUser`, `unsupported kind`,
  `evalError msg`).
- `evalContract : IR.OperationalConfig → IR.Outcome` is a real big-
  step evaluator handling `Expr.{literal,var,unary,binary,select,
  cellGet}` and `Statement.{declare,assign,require,abortIf,cellSet,
  retStmt}` exactly. IR constructs not yet admitted to this cut return
  an explicit `EvalStatus.unsupported`. The unsupported set is the
  natural W4.2-W4.4 work surface:
  `Statement.{ifStmt,forLoop,arraySet,mapPut}` and
  `Expr.{arrayGet,mapGet,structField,arrayIndex,keccak256}`.
- `compilerSecrecyPreservation` and `publicGasSecretIndependent` were
  re-stated against the new evaluator surface as
  `evaluatorCompilerSecrecyPreservation` and
  `evaluatorPublicGasSecretIndependent` (with a matching
  `EvaluatorPublicGasSafe` predicate). The original trace-side
  statements remain so the abstract `ExactObjects` / `Composition`
  composition theorems continue to consume them directly.
- The abstract trace-producer abbreviation is preserved as
  `TraceSemantics := TraceConfig → Trace`, with `Config` /
  `Program` / `Input` / `PublicProjection` /
  `samePublicProjection` retained as alias `abbrev`s. The downstream
  modules `ExactObjects.lean`, `Composition.lean`,
  `LegacyComposition.lean`, `LegacyTeeDeployment.lean`,
  `TeeDeployment.lean`, `SgxExactProjection.lean`, and
  `PathOramLocalPosmapV1.lean` were updated to reference
  `TraceSemantics` rather than the new evaluator type.
- W4.3 (full theorem) landed in
  [`proof/lean/UOToolchain/ConfidentialFragment.lean`](../proof/lean/UOToolchain/ConfidentialFragment.lean)
  and re-exported from
  [`proof/lean/UOToolchain/ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean).
  `IR.branchlessPureExpr` / `branchlessPureExprList` mirror
  `lower_confidential_kernel_pure_expr`. `IR.Expr.fragmentValid` /
  `IR.Statement.fragmentValid` /
  `IR.CompiledFunction.fragmentValid` are mutual-recursion structural
  validity predicates. `IR.Expr.fragmentStats` /
  `IR.Statement.fragmentStats` /
  `IR.CompiledFunction.fragmentStats` plus
  `IR.confidentialFragmentEntrypointWitnessOf` mirror the Rust count-
  based classifier in `crates/uo-core/src/fragment.rs`.
  `FragmentStats.forbidden_zero` plus its
  `forbidden_zero_empty` / `forbidden_zero_add` simp lemmas factor
  the recurring "all three forbidden counts are zero" conjunction.
  The iff theorem
  `(IR.confidentialFragmentEntrypointWitnessOf fn).Valid ↔
  fn.fragmentValid = true` is Lean-proved via three mutual
  `theorem` blocks (`Expr.fragmentStats_valid_iff` /
  `Expr.fragmentStatsList_valid_iff`,
  `Statement.fragmentStats_valid_iff` /
  `Statement.fragmentStatsList_valid_iff`,
  `confidentialFragmentEntrypointWitnessOf_valid_iff`), with the
  paper-facing facade
  `proofGrade_confidential_fragment_valid_iff_structurally_valid`.
  The select-case `Expr.fragmentStats` definition uses the global
  `cond : Bool → α → α → α` primitive (qualified as `_root_.cond`
  to avoid shadowing the local `cond` pattern variable) instead of
  `if ... then ... else ...` on a Bool, because `if`-on-Bool
  silently introduces `decide` wrappers through Lean's Decidable
  elaboration.
- W4.1+ extension landed in
  [`proof/lean/UOToolchain/IRSemantics.lean`](../proof/lean/UOToolchain/IRSemantics.lean):
  `evalContract` now handles `Statement.{ifStmt,forLoop,arraySet,
  mapPut}` (statement evaluator restructured into a single `mutual`
  block with `evalBody` and a new `evalForLoop` helper) and
  `Expr.arrayGet` (using `Value.array` storage indexing).
- W4.1++ landing in `IRSyntax.lean` and `IRSemantics.lean` closes
  the last value-model gaps:
  `Value.map (entries : List (Value × Value))` constructor added;
  manual structural `Value.beq` (with `beqList` /
  `beqStructFields` / `beqMapEntries` mutual companions, plus a
  `BEq Value` instance and a `Value.mapLookup` helper) handles
  value equality without depending on `deriving BEq`;
  `Value.keccak256Mock` provides a deterministic placeholder for
  Keccak-256. `evalExpr` now handles `Expr.mapGet` (lookup
  `Value.map` entries by key) and `Expr.keccak256` (evaluate parts,
  apply the mock). The W4.1 evaluator is now total over the
  structural admitted fragment; the only `unsupported` constructors
  are `Expr.{structField,arrayIndex}`, which `Expr.fragmentValid`
  already rejects.
- W4.1+++ landing in `IRSemantics.lean` threads the updated
  `OperationalConfig` through `evalStatement` / `evalBody` /
  `evalForLoop` so `cellSet` / `arraySet` / `mapPut` perform the
  masked-store update. New helpers
  `OperationalConfig.{objectIsConfidential,writeObject,readObject}`
  route writes to the public store (non-confidential objects) or
  secret store (confidential), and `Value.{arraySetAt,mapInsert}`
  perform the structured value updates. The masked-store semantics
  writes when the predicate is `none` or `true` and leaves the cell
  unchanged when the predicate is `false`; the kernel step is
  recorded unconditionally to mirror the runtime's always-write
  access pattern. `evalContract` discards the final `cfg` and
  returns the outcome unchanged.
- W4.4 Session B-1 landed (forward-direction lowering iff theorems)
  in `KernelDsl.lean`:
  `branchlessPureExpr_implies_lowerPureExpr_ok` /
  `branchlessPureExprList_implies_lowerPureExprList_ok` (mutual);
  `fragmentValid_implies_lowerExpr_ok` /
  `fragmentValidList_implies_lowerExprList_ok` (mutual);
  `kernelLowerable_implies_lowerStatement_ok`;
  `kernelLowerableScheduleAux_implies_lowerStatementsAux_ok` /
  `kernelLowerableSchedule_implies_lowerStatements_ok`; and the
  program-level corollary
  `kernelLowerable_implies_lowerCompiledFunction_ok`. A
  `Statement.isReturn : Statement → Bool` helper was factored out
  to remove a `let`-binding obstacle in
  `kernelLowerableScheduleAux` / `lowerStatementsAux` that blocked
  `simp` reductions. The schedule-level proof case-splits on
  `stmt.isReturn` and on the structure of `rest`. The reverse
  iff direction (lowering succeeds → precondition holds) is
  deferred — useful for W4.6 (artifact-checker demotion), not
  strictly required by the W4.4 preservation theorem. The W4.4
  semantics-preservation theorem (Session B-2) and the paper-
  facing facade (Session C) remain open.
- W4.4 Session A landed in
  [`proof/lean/UOToolchain/KernelDsl.lean`](../proof/lean/UOToolchain/KernelDsl.lean):
  typed Lean mirror of the kernel DSL (`KernelExpr` /
  `KernelPureExpr` / `KernelStatement` / `KernelProgram`) using
  `IR.UnaryOp` / `IR.BinaryOp` / `IR.Ty` instead of the
  `RuntimeKernelDslJson.lean` JSON-typed versions; operational
  semantics sharing `IR.Outcome` / `OperationalConfig` / `LocalEnv`
  with the IR evaluator (`evalKernelExpr` / `evalKernelPureExpr` /
  `evalKernelStatement` / `evalKernelBody` / `evalKernelProgram`);
  IR-to-kernel lowering definitions (`lowerExpr` / `lowerPureExpr` /
  `lowerStatement` / `lowerStatementsAux` / `lowerStatements` /
  `lowerCompiledFunction`) mirroring the Rust
  `lower_confidential_kernel_*` functions; lowering precondition
  predicates (`Statement.kernelLowerable` /
  `Statement.kernelLowerableSchedule` /
  `CompiledFunction.kernelLowerable`); and a structural corollary
  `branchlessPureExpr_implies_fragmentValid` (with companion
  `branchlessPureExprList_implies_fragmentValidList`) that the
  Session B lowering iff theorem will use for the `Expr.select`
  case. The lowering iff theorems and semantics-preservation
  theorem are deferred to Session B.

The WP4 entry conditions therefore now also include the operational
evaluator surface; what is open is the actual semantics-preserving
lowering theorem stack on top of it.

## WP4 Charter (Verbatim From The Roadmap)

Objective: connect the admitted Solidity subset to the kernel DSL and
its public schedule by *proof*, not only by artifact conformance
checking.

Concrete tasks:

1. *(landed in W4.1 / W4.1b)* Define the admitted Solidity subset
   semantics precisely enough for theorem-level compilation claims.
2. Prove correctness of lowering into the UO IR.
3. Prove correctness of confidential-fragment admission and rejection.
4. Prove correctness of lowering into the kernel DSL and its public
   schedule.
5. Prove that every manifest field used by the theorem is an exact
   semantic consequence of the source program.
6. Keep the direct Lean artifact checker, but demote it from "main
   trust argument" to "executable proof witness for the proven compiler
   story."

Deliverables:

- one source-to-IR correctness theorem
- one IR-to-kernel correctness theorem
- one exactness theorem for proof-grade manifest fields

Exit gate: the paper has a real source-to-kernel theorem for the
admitted language.

## Existing Infrastructure (Do Not Rewrite)

These files already exist and are the right place to build on, not
parallel-track around:

- [`proof/lean/UOToolchain/IRSyntax.lean`](../proof/lean/UOToolchain/IRSyntax.lean)
  (~190 lines, *new in W4.1*). The structured Lean mirror of
  `crates/uo-core/src/{ir,types}.rs`. Add new IR cases here (kept in
  lockstep with `ir.rs`) before extending the evaluator.
- [`proof/lean/UOToolchain/IRSemantics.lean`](../proof/lean/UOToolchain/IRSemantics.lean)
  (~520 lines, *rewritten in W4.1*). Houses the operational
  `OperationalConfig` / `Outcome` / `Semantics` types, the abstract
  `TraceConfig` / `TraceProgram` / `TraceInput` / `TracePublicProjection` /
  `TraceSemantics` types preserved for backwards compatibility, and
  the real `evalContract` evaluator skeleton.
- [`proof/lean/UOToolchain/CompilerInvariant.lean`](../proof/lean/UOToolchain/CompilerInvariant.lean)
  (~100 lines, *re-stated in W4.1b*). Now exposes both
  `PublicGasSafe` / `compilerSecrecyPreservation` /
  `publicGasSecretIndependent` over `TraceSemantics` and
  `EvaluatorPublicGasSafe` / `evaluatorCompilerSecrecyPreservation` /
  `evaluatorPublicGasSecretIndependent` over the new `Semantics`
  evaluator.
- [`proof/lean/UOToolchain/ConfidentialFragment.lean`](../proof/lean/UOToolchain/ConfidentialFragment.lean)
  (~94 lines). Has `ConfidentialFragmentEntrypointWitness` /
  `ConfidentialFragmentWitness` with `selectCount`, `structFieldCount`,
  `arrayIndexCount`, `nonBranchlessSelectArmCount` fields plus a
  `Valid`/`checkValid` bridge. The shape is right; what is missing is
  a *theorem* showing that `Valid` implies the source program lies in
  the admitted confidential fragment under the new semantics. (W4.3.)
- [`proof/lean/UOToolchain/CompilerExactness.lean`](../proof/lean/UOToolchain/CompilerExactness.lean)
  (~1466 lines). Holds `ProofGradeCompilerFacts` (line 1165) — the
  exactness/export bundle that proves manifest fields, confidential
  kernel lowering, runtime kernel-step schedules, and ORAM bridge
  witnesses are exact consequences of `bundle.ProofGradeValid`. **This
  is exactness, not semantics-preserving correctness.** WP4 lifts
  these facts from "the same data appears on both sides" to "the
  compiler preserves the source semantics." (W4.5, per field.)
- [`proof/lean/UOToolchain/TranslationValidationJson.lean`](../proof/lean/UOToolchain/TranslationValidationJson.lean)
  (~3545 lines). Imported view structures and JSON projection layer.
  Touch only when a new theorem-facing field needs to be exposed.
- [`proof/lean/UOToolchain/ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean)
  (~548 lines). Paper-facing facade that re-exports
  `ProofGradeCompilerFacts` corollaries. New WP4 theorems that need
  paper-facing names go here.
- [`compiler/uo-solc/src/lib.rs`](../compiler/uo-solc/src/lib.rs)
  (~2638 lines). The actual Rust compiler. Includes Solidity parser,
  IR lowering, confidential-fragment classifier, kernel DSL lowering,
  manifest emission. **This is the operational semantics the Lean
  side has to refine.**
- [`crates/uo-core/src/ir.rs`](../crates/uo-core/src/ir.rs) (~191
  lines). The UO IR data types: `ProgramMode`, `StateObject`,
  `Statement`, `Expr`, `CompiledFunction`, `CompiledContract`. The
  Lean-side mirror in `IRSyntax.lean` follows this file field-for-
  field and constructor-for-constructor. **If `ir.rs` changes, the
  Lean mirror must move with it.** A static-drift check is not yet in
  place — adding one is in scope for any commit that extends the
  mirror.
- [`crates/uo-core/src/kernel_dsl.rs`](../crates/uo-core/src/kernel_dsl.rs)
  (~496 lines). Kernel DSL data types and slot lowering. The
  IR-to-kernel correctness theorem refines the Rust side of this
  file against a Lean-side kernel DSL semantics.
- [`crates/uo-core/src/confidential_kernel.rs`](../crates/uo-core/src/confidential_kernel.rs)
  (~2768 lines). The interpreter / generator surface used at runtime.
- [`crates/uo-core/src/manifest.rs`](../crates/uo-core/src/manifest.rs)
  (~490 lines). The manifest schema. The WP4 manifest-exactness
  theorem ties each field here back to its semantic origin in the
  source program.
- [`crates/uo-core/src/translation_validation.rs`](../crates/uo-core/src/translation_validation.rs)
  (~487 lines). The `ProofRelevantTranslationBundle` /
  `ProofRelevantContractView` pipeline that the existing checker
  consumes. Demote-not-delete (charter task 6).

## Claim Taxonomy For WP4

This is the most common confusion to avoid. From the
[Claim And TCB Discipline](./coding-agent-conventions.md#claim-and-tcb-discipline)
section of the conventions, every WP4 statement falls into one of:

- **Lean-proved, semantics-preserving** — the new bar. *e.g.*, "if the
  source statement `s` evaluates to value `v`, then the lowered IR
  statement `lower(s)` evaluates to `v` under the IR semantics." This
  is what WP4 deliverable 1, 2, 3 demand.
- **Lean-proved, exactness/export** — the *current* state of
  `ProofGradeCompilerFacts`. *e.g.*, "the manifest's `secret_args`
  equal the source function's `secret_args`." This is real and
  load-bearing, but it is a same-data fact, not a same-meaning fact.
- **Generated-and-checked / source-frozen** — the residual checker
  surface. The compiler is a Rust binary; the Rust binary remains in
  the TCB until WP4's lowering theorems are projected through a
  Lean-side compiler model (or alternatively a generated-from-Lean
  emitter). State this explicitly when you write the WP4 status
  paragraph.
- **Trusted** — `uo-solc` is currently in the TCB. WP4's exit gate
  removes it.

When the roadmap status text talks about WP4 "landings," classify each
claim before declaring success. Never say "WP4 proves source-to-kernel
correctness" until the deliverables are all real semantics-preserving
theorems projected through the paper-facing facade.

W4.1 / W4.1b explicitly do *not* move any compiler claim from
exactness/export to semantics-preserving. They establish the
operational evaluator surface that the W4.2-W4.5 theorems will refine
against; `uo-solc` therefore remains in the trusted surface.

## Recommended Starting Subtask

Charter task 1 (W4.1 / W4.1b) and charter task 3 (W4.3) are now
landed. The next still-open subtask per the runbook's deliverable
ordering is **W4.4** (charter task 4: IR-to-kernel correctness),
which has a clearer structural path than W4.2 because the kernel-
DSL Lean mirror already exists in
`proof/lean/UOToolchain/RuntimeKernelDslJson.lean`
(`ImportedConfidentialKernelStatement` /
`ImportedConfidentialKernelExpr` /
`ImportedConfidentialKernelPureExpr` are mutual inductives that
mirror the kernel-DSL Rust types).

**Subtask W4.4: Prove the IR-to-kernel correctness theorem.**

Concretely:

- Define a Lean-side semantics for `ImportedConfidentialKernelStatement`
  (operational evaluator over the kernel DSL). The semantics should
  produce an `IR.Outcome`-equivalent result so that the
  IR-side and kernel-side evaluators are directly comparable.
- Mirror the Rust lowering function
  `lower_confidential_kernel_*` from
  `crates/uo-core/src/confidential_kernel.rs` as a Lean-side
  `lowerToKernel : IR.CompiledFunction → Except Error
  ImportedConfidentialKernelProgram`. Note that the lowering is
  partial: `IR.Statement.{ifStmt,forLoop}` cannot lower to the
  kernel DSL because the kernel DSL is straight-line. The
  `Expr.fragmentValid` predicate from W4.3 is precisely the
  precondition for the lowering to succeed for `Expr`s; the
  statement-side precondition adds "no `ifStmt`, no `forLoop`."
- Prove the IR-to-kernel correctness theorem: if the lowering
  succeeds, the kernel program's semantics agrees with the IR
  semantics (suitably projected). Specifically, prove that
  `evalContract cfg` and `evalKernel (lower fn) cfg` produce the
  same `Outcome` for any `OperationalConfig cfg`.
- Project the result through `ProofGrade.lean` as
  `proofGrade_ir_to_kernel_correctness` (or similar) so the
  paper-facing facade has a named handle.

The W4.4 work is a multi-session effort because it requires both
the kernel-DSL semantics (~similar size to the W4.1 IR semantics)
and the lowering correctness theorem (~similar size to the W4.3
characterization). Recommend splitting it into:

1. Add the kernel-DSL semantics as `RuntimeKernelDslSemantics.lean`
   (or extend `RuntimeKernelDslJson.lean`).
2. Define the lowering `lowerToKernel` and prove that it succeeds
   exactly on `IR.Statement.fragmentValid && no ifStmt && no
   forLoop`.
3. Prove the semantics-preservation theorem.

Alternative ordering: drive **W4.2** (source-to-IR correctness)
first instead. W4.2 is roughly 2-3× the effort of W4.3 because it
requires either a partial Lean Solidity semantics or a Lean mirror
of `uo-solc`'s parser intermediate AST (`solang_parser::pt`).
Recommendation: pull back via the AST option — mirror the
`pt::Statement` / `pt::Expression` shapes for the *admitted subset*
in Lean and prove that `uo-solc::lower_block` is a faithful
translation from that AST to `IR.Statement`. The "source"
semantics in this framing is the AST-level evaluator; full Solidity
is treated as the trusted parser step.

After W4.4 lands, the natural sequence is:

- W4.2 — source-to-IR correctness theorem (deliverable 1). This is
  the deeper one because it requires either a partial Lean Solidity
  semantics or a Lean mirror of `uo-solc`'s parser intermediate AST.
  Recommendation: pull back via the AST option — mirror the
  `solang_parser::pt::Statement` / `pt::Expression` shapes in Lean
  and prove that `uo-solc::lower_block` is a faithful translation
  from that AST to `IR.Statement`. The "source" semantics in this
  framing is the AST-level evaluator; full Solidity is treated as the
  trusted parser step.
- W4.4 — IR-to-kernel correctness theorem (deliverable 2): refine
  `crates/uo-core/src/kernel_dsl.rs`'s lowering against a Lean kernel
  DSL semantics, reusing the helper-layer end-to-end theorems already
  proved in WP3.
- W4.5 — manifest-exactness theorem (deliverable 3): tighten
  `ProofGradeCompilerFacts.manifestFieldsExact` from
  "manifest fields equal what the compiler computed" to "manifest
  fields equal a semantic projection of the source program." This is
  the field-by-field upgrade from exactness/export to
  semantics-preserving.
- W4.6 — demote `uo-check`-equivalent direct artifact checker
  (charter task 6): keep the executable witness path but stop
  treating it as the trust root.

## Validation Slice

Doc-only edits run `git diff --check` only. For Lean / Rust / probe
edits, run the standard slice from
[`coding-agent-conventions.md`](./coding-agent-conventions.md#validation-slice-protocol),
plus the WP4-relevant scenarios:

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

For larger checkpoints (new boundary cuts, new tamper scenarios,
schema changes), run `scripts/run_validation.sh` to exercise the full
suite.

Cross-checks before declaring success: probe exit code 0, top-level
`"accepted": true` in each non-static report, the static-checks
restriction flags
(`legacy_axiom_definition_surface_restricted`,
`legacy_theorem_symbol_surface_restricted`,
`proofgrade_checker_import_surface_restricted`,
`proofgrade_checker_legacy_symbol_mentions_absent`,
`proofgrade_core_module_import_surface_restricted`)
all `true`, `git diff --check` clean, tamper-validation scenario count
matches `rejected: true` count.

## What WP4 Must NOT Do

- Do not regress WP3. The runtime residual-helper-shell route and the
  direct kernel-machine-confinement route must continue to expose the
  same helper-layer end-to-end theorems through their report bits.
  WP4 work happens *above* the kernel DSL boundary; WP3 lives below
  it. They share the kernel-DSL interface, so the IR-to-kernel
  correctness theorem must consume the kernel-DSL semantics that WP3
  refined runtime against, not invent a new one.
- Do not weaken `ProofGradeCompilerFacts`. The exactness/export layer
  is the floor; semantics-preserving theorems strengthen it, they
  don't replace it.
- Do not weaken the W4.1 evaluator. Adding new evaluator cases is
  fine; *removing* existing cases or downgrading them to
  `EvalStatus.unsupported` is a regression of the evaluator's coverage
  surface.
- Do not reintroduce `uo-check` as a gating step. The proof-grade
  acceptance path still goes through direct Lean source/artifact
  checking.
- Do not promote source-freeze checks to "proved." Charter task 6
  *demotes* the direct artifact checker; do not invert this.
- Do not add a new probe report bit unless the underlying claim is a
  Lean theorem in the appropriate work-package surface. The
  conventions' two-route discipline still applies if a new theorem
  family touches the runtime side, but WP4 mostly lands theorems
  *above* the runtime boundary; expose those through
  `confidential-fragment-validation` and any new compiler-correctness
  scenario you add, not through the runtime routes.

## Repository Conventions Cross-Reference

The following sections of
[`coding-agent-conventions.md`](./coding-agent-conventions.md) apply
to WP4 directly:

- **Scientifically-Strongest-Route Preference** — when a lowering
  theorem can either be proved over the Rust binary directly or
  proved over a Lean model that the Rust binary is generated from /
  exact-string-checked against, prefer the latter.
- **Five-Layer Projection Pattern** — does *not* apply identically to
  WP4 because WP4 theorems are above the runtime boundary. The
  analogous pattern for compiler theorems is: state in
  `IRSemantics.lean` / `CompilerInvariant.lean` / `ConfidentialFragment.lean`,
  bundle in `CompilerExactness.lean`, expose in `ProofGrade.lean`,
  optionally surface as a probe report bit if new external state is
  involved.
- **Claim And TCB Discipline** — applied above. Read it again before
  writing the WP4 status paragraph.
- **Working Practices For Coding Agents** — auto-continue, small
  commits, patch-style edits, preserve unrelated dirty files, lint
  warnings are not blockers, terminal hygiene, write a handoff
  before stopping.

## Suggested Per-Checkpoint Commit Cadence

The user has authorized checkpointing during implementation work
(see *Working Practices For Coding Agents* and the WP3 / W4.1 session
logs). Each coherent technical step that passes the validation slice
should be its own commit:

- *(landed)* IR semantics inductives + evaluator skeleton + secrecy
  lemma re-statement (W4.1 / W4.1b, commit `6e234df`).
- *(landed)* Roadmap / theorem-profile status update (commit
  `267dc89`).
- *(landed)* W4.3 definitions: structural confidential-fragment
  classifier + count-based classifier + primitive split lemma
  (commit `4f30757`).
- *(landed)* WP4 status / handoff status update for W4.3
  definitions (commit `5ef3bdd`).
- *(landed)* W4.3 iff theorem
  (`(confidentialFragmentEntrypointWitnessOf fn).Valid ↔
  fn.fragmentValid`) plus paper-facing facade in `ProofGrade.lean`
  (commit `08f669a`).
- *(landed)* WP4 status / handoff status update for W4.3 theorem
  (commit `94ba337`).
- *(landed)* W4.1+ evaluator coverage extension
  (`Statement.{ifStmt,forLoop,arraySet,mapPut}` and
  `Expr.arrayGet`, commit `9f0e45e`).
- *(landed)* WP4 status / handoff status update for W4.1+
  (commit `5d79540`).
- *(landed)* W4.1++ evaluator value-model gaps closed
  (`Value.map`, `Value.beq`, `Value.mapLookup`,
  `Value.keccak256Mock`, `Expr.{mapGet,keccak256}`,
  commit `2a6aa8b`).
- *(landed)* WP4 status / handoff status update for W4.1++
  (commit `e4c38e0`).
- *(landed)* W4.1+++ store-update threading
  (`OperationalConfig.{objectIsConfidential,writeObject,
  readObject}`, `Value.{arraySetAt,mapInsert}`, masked-store
  semantics for `cellSet` / `arraySet` / `mapPut`,
  commit `b4442f7`).
- *(landed)* W4.4 Session A: typed kernel DSL inductives,
  operational semantics, lowering definitions, lowering
  precondition predicates, and `branchlessPureExpr_implies_
  fragmentValid` corollary in `KernelDsl.lean` (commit `1bd6180`).
- *(landed)* W4.4 Session B-1: forward-direction lowering iff
  theorems at all four levels (Expr / Statement / schedule /
  program), with `Statement.isReturn` helper refactor (commits
  `1be2c58`, `90e9cde`, `1dcd8ef`).
- *(next)* W4.4 Session B-2: semantics-preservation theorem
  (`evalContract cfg = evalKernelProgram (lowerCompiledFunction
  fn) cfg` when the lowering succeeds). Structural mutual recursion
  comparing `evalExpr` / `evalKernelExpr` outcomes after lowering.
  Will use the Session B-1 forward iffs as preconditions.
- *(next)* W4.4 Session C: paper-facing `ProofGrade.lean`
  projection of the W4.4 preservation theorem and status / handoff
  doc updates.
- *(also next)* iff reverse directions for W4.6 artifact-checker
  demotion (low-priority, not on the W4.4 critical path).
- Source-to-IR lowering theorem (W4.2, probably split into
  expression-level, statement-level, function-level).
- IR-to-kernel lowering theorem (W4.4, likely split per kernel-DSL
  construct).
- Manifest exactness lift (W4.5, per-field).
- Direct artifact-checker demotion (W4.6, doc + roadmap update).

Commit messages should explain *what assumption moved from
exactness/export to semantics-preserving in this checkpoint, and what
manifest field or compiler stage it covers.* Future-you (or a fresh
agent) will read those messages to decide which checkpoint introduced
a regression in the static-drift suite three weeks later.

## Known Risks And Pitfalls

- **Scope creep into a verified Solidity compiler.** The "admitted
  Solidity subset" is intentionally narrow. If you find yourself
  proving real-world Solidity features (modifiers, inheritance,
  storage layout, ABI encoding edge cases), stop and re-read the
  charter. The admitted subset is whatever `uo-solc` already accepts,
  no more.
- **Rust IR drift.** The Lean IR mirror in `IRSyntax.lean` has to
  follow `crates/uo-core/src/{ir,types}.rs` constructor-for-
  constructor. If `ir.rs` changes during WP4, the Lean side must move
  with it. There is no static-drift check for the IR mirror yet —
  add one (in `mplus-probe`) when extending the mirror, or accept
  that drift is caught only at the next `lake build` of the
  evaluator.
- **`Semantics` vs `TraceSemantics` confusion.** The new `Semantics`
  is the operational evaluator (`IR.OperationalConfig → IR.Outcome`).
  The abstract trace-producer abbreviation is `TraceSemantics`
  (`TraceConfig → Trace`). Both names are now load-bearing. When
  introducing new theorems, classify which surface you mean and use
  the matching abbreviation; mixing them up will produce
  type-mismatch errors that look like "applied `Semantics` where
  `TraceSemantics` expected" or vice versa.
- **Confidential-fragment witness shape.** The current
  `ConfidentialFragmentEntrypointWitness` carries counts. The W4.3
  theorem may want stronger structural facts (e.g., "no
  `StructField` expression appears anywhere in the AST"). It is
  fine to extend the witness, but every extension means extending
  the Rust-side classifier (`crates/uo-core/src/fragment.rs`) and
  the source-freeze checks together.
- **Compiler in the TCB during WP4 work.** Until the lowering
  theorems are real, `uo-solc`'s compilation behavior remains
  trusted. Do not change the WP4 status paragraph to "compiler is
  no longer in the TCB" until the source-to-IR and IR-to-kernel
  theorems exist and are projected through `ProofGrade.lean`.
- **Evaluator coverage gaps.** The W4.1 evaluator returns
  `EvalStatus.unsupported` for `Statement.{ifStmt,forLoop,arraySet,
  mapPut}` and `Expr.{arrayGet,mapGet,structField,arrayIndex,
  keccak256}`. Theorems that need to evaluate programs containing
  those constructs must either extend the evaluator first or scope
  themselves to the supported subset.

## Where The Handoff Stops

This runbook hands off to subtask W4.3 (or W4.2 if you prefer to
sequence the deliverables strictly) with:

- Clean main branch at commit `267dc89` (W4.1/W4.1b landing + status
  update).
- All validation gates green at the standard WP4 validation slice
  (probe exit codes 0; `"accepted": true` on all non-static probe
  reports; static-checks restriction flags all `true`; full
  `lake build` 403/403; `git diff --check` clean).
- The companion handoff prompt
  [`wp4-handoff-prompt.md`](./wp4-handoff-prompt.md) ready to be
  pasted into a fresh coding-agent session.

When the next agent finishes a checkpoint, they update:

- `docs/top-tier-paper-execution-roadmap.md` — WP4 paragraph and
  status update.
- `docs/paper-theorem-profile.md` — "What is still open" list for
  WP4 (and the TCB / assumption tables if a compiler claim moves
  from "trusted" to "Lean-proved").
- `probe/mplus-probe/src/lib.rs` — only if a new theorem family
  needs a new report bit. Most WP4 theorems land in
  `ProofGrade.lean` and don't need new bits.
- This runbook — when subtask scope shifts or the recommended next
  step changes.
