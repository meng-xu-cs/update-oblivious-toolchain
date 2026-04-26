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

WP3 closed on 2026-04-26. The runtime/below-interface story is now:

- A source-backed `RuntimeImplementationInterface` cut, exact-string
  pinned to the actual `runtime/uo-evm`, `runtime/uo-allocator`,
  `runtime/uo-store`, `runtime/uo-kernel-runtime`, and
  `runtime/uo-precompiles` source files.
- A residual-helper-shell route and a direct kernel-machine-confinement
  route that *both* expose the same helper/kernel theorems through
  matching report bits.
- A Lean-modeled Path-ORAM helper-and-codec semantics layer
  (`RuntimeOramHelperSemantics`, `RuntimeOramCodecSemantics`,
  `RuntimeStoreCodecSemantics`, `RuntimeStoreHelperSemantics`) projected
  through the five-layer pattern.
- A pinned crypto-primitive identity (`chacha20poly1305` AEAD,
  `tiny_keccak::Keccak::v256`) at the source-backed boundary.

The WP4 entry conditions are met: the runtime side is stable, the
proof-grade exactness/export layer for manifest fields has landed, and
the compiler-to-ORAM bridge already produces source-derived witnesses.
What is open is the actual semantics-preserving lowering theorem stack.

## WP4 Charter (Verbatim From The Roadmap)

Objective: connect the admitted Solidity subset to the kernel DSL and
its public schedule by *proof*, not only by artifact conformance
checking.

Concrete tasks:

1. Define the admitted Solidity subset semantics precisely enough for
   theorem-level compilation claims.
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

- [`proof/lean/UOToolchain/IRSemantics.lean`](../proof/lean/UOToolchain/IRSemantics.lean)
  (~73 lines). Stub: `ObjectShape`, `Program`, `Input`, `Config`,
  `PublicProjection`, `abbrev Semantics := Config → Trace`,
  `samePublicProjection` lemmas. **This is where the precise
  operational semantics has to land.** The `Semantics := Config →
  Trace` abbreviation is a placeholder; WP4 task 1 replaces it with an
  actual interpreter that captures the admitted Solidity subset.
- [`proof/lean/UOToolchain/CompilerInvariant.lean`](../proof/lean/UOToolchain/CompilerInvariant.lean)
  (~36 lines). Has `ManifestWitness`, `PublicGasSafe`,
  `compilerSecrecyPreservation`, `publicGasSecretIndependent`. These
  are placeholder secrecy lemmas over the abstract `Semantics`
  abbreviation; they need to be re-stated against the real semantics
  once it lands.
- [`proof/lean/UOToolchain/ConfidentialFragment.lean`](../proof/lean/UOToolchain/ConfidentialFragment.lean)
  (~94 lines). Has `ConfidentialFragmentEntrypointWitness` /
  `ConfidentialFragmentWitness` with `selectCount`, `structFieldCount`,
  `arrayIndexCount`, `nonBranchlessSelectArmCount` fields plus a
  `Valid`/`checkValid` bridge. The shape is right; what is missing is
  a *theorem* showing that `Valid` implies the source program lies in
  the admitted confidential fragment under the new semantics.
- [`proof/lean/UOToolchain/CompilerExactness.lean`](../proof/lean/UOToolchain/CompilerExactness.lean)
  (~1466 lines). Holds `ProofGradeCompilerFacts` (line 1165) — the
  exactness/export bundle that proves manifest fields, confidential
  kernel lowering, runtime kernel-step schedules, and ORAM bridge
  witnesses are exact consequences of `bundle.ProofGradeValid`. **This
  is exactness, not semantics-preserving correctness.** WP4 lifts
  these facts from "the same data appears on both sides" to "the
  compiler preserves the source semantics."
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
  Lean side currently models a much smaller `Program` /
  `ObjectShape`; the WP4 IR model in Lean must match these data types
  field-for-field.
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

## Recommended Starting Subtask

Charter task 1 is the prerequisite for tasks 2–5. Start there:

**Subtask W4.1: Replace the `IRSemantics.Semantics := Config → Trace`
abbreviation with a precise operational semantics for the admitted
subset.**

Concretely:

- Decide the admitted-subset surface in Lean. The Rust IR already
  pins it (`ir.rs`'s `Statement` / `Expr` enums); the Lean side should
  mirror these as inductives, not strings.
- Define environment / store / public-state / secret-state types.
- Define a `bigStep` (or `smallStep`) evaluator: `Config → Result
  Outcome` (where `Outcome` carries the public projection, the gas
  used, and the ORAM-access trace fields the manifest depends on).
- Re-state `compilerSecrecyPreservation` and
  `publicGasSecretIndependent` against the real evaluator.
- Audit every place in `CompilerExactness.lean` that uses the
  abbreviated `Semantics` to confirm the new evaluator is the right
  drop-in. Most call sites are likely paper-facing facade lines that
  will tighten naturally; some may need a richer `Outcome` type.

This subtask alone may be a ~one-week checkpoint. Land it as one
coherent commit, run the validation slice, then proceed to subtask
W4.2 (source-to-IR lowering correctness — i.e., the compiler from the
admitted Solidity AST to the IR refines the new evaluator).

After W4.1 lands, the natural sequence is:

- W4.2 — source-to-IR correctness theorem (deliverable 1).
- W4.3 — confidential-fragment admission/rejection theorem (charter
  task 3): show that
  `ConfidentialFragmentEntrypointWitness.Valid` exactly characterizes
  the subset of source programs whose IR lies in the confidential
  fragment.
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
lake build UOToolchain.IRSemantics \
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
`"accepted": true` in each report, `git diff --check` clean,
tamper-validation scenario count matches `rejected: true` count.

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
(see *Working Practices For Coding Agents* and the recent WP3
session log). Each coherent technical step that passes the
validation slice should be its own commit:

- IR semantics inductives + evaluator skeleton.
- `compilerSecrecyPreservation` re-stated against the real evaluator.
- Source-to-IR lowering theorem (probably split into
  expression-level, statement-level, function-level).
- Confidential-fragment admission theorem.
- IR-to-kernel lowering theorem (likely split per kernel-DSL
  construct).
- Manifest exactness lift (per-field).
- Direct artifact-checker demotion (doc + roadmap update).

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
- **Rust IR drift.** The Lean IR model has to follow `crates/uo-core/src/ir.rs`.
  If `ir.rs` changes during WP4, the Lean side must move with it,
  ideally via a generator that emits Lean inductives from the Rust
  enums. If a manual mirror is used, add an exact-string drift check
  to the probe.
- **`Semantics := Config → Trace` users.** Several files import
  `IRSemantics`. When you change the `Semantics` definition, audit
  every importer; do not silently change the type and let downstream
  files compile against a different abstraction. `lake build` will
  catch most of this; the static-drift suite catches the rest.
- **Confidential-fragment witness shape.** The current
  `ConfidentialFragmentEntrypointWitness` carries counts. The WP4
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

## Where The Handoff Stops

This runbook hands off to subtask W4.1 with:

- A clean main branch at WP3 closure (commit `b43624b` or later).
- All validation gates green at the doc-only `git diff --check`
  level on creation of this handoff.
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
