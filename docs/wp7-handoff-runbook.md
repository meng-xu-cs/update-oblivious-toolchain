# WP7 Handoff Runbook

This runbook hands off Work Package 7 (WP7) — *canonicalize the proof
architecture and artifact story* — to the next coding agent.

It does not duplicate the engineering process. The authoritative
process document is
[`coding-agent-conventions.md`](./coding-agent-conventions.md). Read it
first; this runbook only carries the WP7-specific facts that don't
belong in a process doc.

## Where We Are

WP6 closed on 2026-04-27 in seven small commits on top of `77a7ef1`:

- `7fd2283` — W6.1 SGX observer freeze (page-region names,
  controller-phase vocabulary, page/exit-event vocabularies,
  shared-resource pattern literal, page-event encoding formula);
- `e500c26` — W6.2 boundary-call model (oram_access API literal,
  Enter/Exit direction vocabulary, boundary-event budget formula,
  schedule structural shape);
- `fc37f7c` — W6.2 persistent-I/O model (PhysicalRead / PhysicalWrite
  field schemas, WriteClass vocabulary);
- `ed956ce` — W6.3 controller-refinement integration (canonical Lean
  controller shape refines W6.1 / W6.2 freeze in four senses);
- `57803d3` — W6.4 sealing / storage-refinement integration
  (`viewTEEStore` projection forwards trace + config fields
  deterministically);
- `c95aaac` — W6.5 explicit deployment-assumption bundle
  (`SgxDeploymentAssumptions` with six `Prop` fields covering
  every WP6 charter task 5 enumeration — attestation, rollback,
  freshness, crash, patch-level — plus enclave memory isolation,
  paired with Intel SGX provenance citations);
- `1724852` — W6.6 closure audit (`sgxHostileHostClosureAudit` six-
  entry summary, closure theorems
  `sgxHostileHostClosureAudit_length` /
  `sgxHostileHostClosureAudit_leanProvedEntries` /
  `sgxHostileHostClosureAudit_allClassified` /
  `sgxHostileHostClosureAudit_driftCheckNames`).

All seven commits land in `proof/lean/UOToolchain/SgxObserverFreeze.lean`,
exposed through paper-facing `proofGrade_sgx_*` facades in
`proof/lean/UOToolchain/ProofGrade.lean`, paired with a unified
documentation section in `docs/tee-runtime-hardening.md`, and
backed by six probe drift checks in
`probe/mplus-probe/src/lib.rs`'s
`run_kernel_model_alignment_validation` function:

- `sgx_observer_surface_pinned`,
- `sgx_boundary_call_model_pinned`,
- `sgx_persistent_io_model_pinned`,
- `sgx_controller_refinement_pinned`,
- `sgx_storage_refinement_pinned`,
- `sgx_deployment_assumption_bundle_pinned`.

WP6 is therefore closed in the practical sense: the WP6 surface has
six explicit checkpoint fields, each paired either with a Lean
refinement theorem (W6.1–W6.4) or with an explicit Cited /
externally justified provenance pairing (W6.5). The closure audit
certifies the surface stays at exactly six entries.

The remaining open work below the WP6 surface — a deeper
semantics-of-Rust refinement of the real `uo-evm` runtime against
the W6.1 / W6.2 frozen observer — stays documented as future
strengthening, not as in-scope WP6 work. Do not re-open WP6 unless
the user explicitly redirects.

WP7 now opens with the goal of canonicalizing the proof architecture
and artifact story.

## WP7 Charter (Verbatim From The Roadmap)

Objective: make the final proof stack look minimal, inevitable, and
easy to review.

Concrete tasks:

1. Refactor the theorem stack so each layer has one abstraction
   function and one main theorem.
2. Make every proof-grade checker theorem-tight.
3. Remove compatibility shims from the main paper narrative.
4. Add tamper and negative tests for every theorem-facing artifact.
5. Make artifact generation deterministic and reproducible.
6. Report proof-checking cost, artifact size, runtime overhead, TCB
   size, and explicit assumptions.

Deliverables:

- one clean theorem stack
- one reproducible artifact pipeline
- one reviewer-facing proved/assumed/trusted table

Exit gate: the paper and artifact tell the same minimal story with
no hidden branches.

## Existing Infrastructure (Do Not Rewrite)

These files already exist and are the right place to build on:

### Theorem-facing surface (Lean)

- [`proof/lean/UOToolchain.lean`](../proof/lean/UOToolchain.lean) —
  the top-level umbrella module.
- [`proof/lean/UOToolchain/ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean)
  — the paper-facing facade module.
- [`proof/lean/lakefile.lean`](../proof/lean/lakefile.lean) — the
  Lake build manifest naming every checker executable.

### Probe / artifact surface

- [`probe/mplus-probe/src/lib.rs`](../probe/mplus-probe/src/lib.rs)
  — the probe binary that runs every Lean checker, every static
  drift check, every tamper-validation scenario, and emits the
  reviewer-facing summary.
- [`probe/mplus-probe/src/main.rs`](../probe/mplus-probe/src/main.rs)
  — the probe entrypoint.
- [`scripts/run_validation.sh`](../scripts/run_validation.sh) — the
  full validation-gate runner used at every major checkpoint.
- [`scripts/run_bridge_validation.sh`](../scripts/run_bridge_validation.sh)
  — the smaller bridge-validation runner.

### Reviewer-facing summary

- `results/reviewer_summary.json` and `results/reviewer_summary.md`
  are the machine-generated reviewer-facing tables over proof /
  report cost, artifact sizes, runtime overheads, TCB surface, and
  explicit assumptions.

## Claim Taxonomy For WP7

From the
[Claim And TCB Discipline](./coding-agent-conventions.md#claim-and-tcb-discipline)
section of the conventions, every WP7 statement falls into one of:

- **Lean-proved, semantics-preserving** — refactoring or tightening
  of existing theorems should keep this classification.
- **Lean-proved, exactness/export** — the named main paper theorem
  object plus the canonical artifact-export endpoints.
- **Cited / externally justified** — the W5 / W6.5 backend +
  deployment provenance pairings stay green at the same
  classification.
- **Trusted external assumption (irreducible)** — anything that
  cannot be discharged by Lean refinement.

WP7 should not introduce new fields in any of these buckets. The
work is canonicalization: removing duplicate theorem statements,
pruning compatibility shims, tightening tamper coverage, and
tightening the reviewer-facing summary so the story is minimal.

## Recommended Starting Subtask

The natural starting point is **W7.1: refactor the theorem stack so
each layer has one abstraction function and one main theorem.**

Concretely, audit the SGX projection chain
(`SgxBoundary.lean` → `SgxRelation.lean` → `SgxController.lean` →
`SgxControllerTrace.lean` → `SgxMicroModel.lean` →
`SgxExactProjection.lean` / `SgxOramProjection.lean` /
`SgxJointProjection.lean`) for layers that expose more than one
"main theorem" in the public API. Each layer should expose one
abstraction function (e.g., `viewTEEStore`, `sgxViewOfDeployment`)
and one main paper-facing theorem (e.g.,
`paperMain_exactUO_projects_to_sgxExecution`). Anything else should
be either an internal helper (private namespace) or a paper-facade
in `ProofGrade.lean`.

After W7.1 lands, the next subtasks in recommended order:

- **W7.2**: theorem-tighten every proof-grade checker, removing
  compatibility shims that exist only for legacy report bits.
- **W7.3**: remove compatibility shims from the main paper
  narrative — eg. legacy theorem aliases that are kept only for
  older probe report fields.
- **W7.4**: add tamper and negative tests for every theorem-facing
  artifact emitted by the runtime (witness JSONs, refinement
  bundles, public-trace projections).
- **W7.5**: make artifact generation deterministic and reproducible.
- **W7.6**: report proof-checking cost, artifact size, runtime
  overhead, TCB size, and explicit assumptions in the
  reviewer-facing summary.

## Validation Slice

Doc-only edits run `git diff --check` only. For Lean / Rust / probe
edits, run the standard slice from
[`coding-agent-conventions.md`](./coding-agent-conventions.md#validation-slice-protocol).
For larger checkpoints (new tamper scenarios, new probe scenarios,
schema changes), run `scripts/run_validation.sh` to exercise the
full suite.

The WP7-augmented slice (covering the entire SGX surface plus the
W6 freeze module):

```bash
cd <repo-root>
cargo fmt --all
cd proof/lean
lake build UOToolchain.SgxBoundary \
  UOToolchain.SgxRelation \
  UOToolchain.SgxController \
  UOToolchain.SgxControllerTrace \
  UOToolchain.SgxExactProjection \
  UOToolchain.SgxOramProjection \
  UOToolchain.SgxJointProjection \
  UOToolchain.SgxMicroModel \
  UOToolchain.SgxObserverFreeze \
  UOToolchain.TeeDeployment \
  UOToolchain.ProofGrade
cd ../..
cargo check -p mplus-probe
cargo run -q -p mplus-probe -- --only static-checks --out-dir results \
  > /tmp/uo-static-checks.json
cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation \
  --out-dir results > /tmp/uo-kernel-model-alignment-validation.json
git diff --check
```

Cross-checks before declaring success: probe exit code 0, top-level
`"accepted": true` in each non-static report, the static-checks
restriction flags all `true`, all six WP6 drift checks
(`sgx_observer_surface_pinned`, `sgx_boundary_call_model_pinned`,
`sgx_persistent_io_model_pinned`, `sgx_controller_refinement_pinned`,
`sgx_storage_refinement_pinned`,
`sgx_deployment_assumption_bundle_pinned`) plus the prior W5 drift
checks (`runtime_crypto_primitive_identity_pinned`,
`path_oram_deployed_stash_parameters_pinned`) all `true`,
`git diff --check` clean, tamper-validation scenario count matches
`rejected: true` count.

## What WP7 Must NOT Do

- Do not regress WP3, WP4, WP5, or WP6. The runtime
  residual-helper-shell route, the direct kernel-machine-confinement
  route, the W4.2 + W4.4 + W4.5 + W4.6 chain, the W5.3 / W5.4 /
  W5.5 / W5.6 provenance pairings, and the W6.1 / W6.2 / W6.3 /
  W6.4 / W6.5 / W6.6 freeze + refinement + bundle stay green.
- Do not weaken the
  `PathOramLocalPosmapV1SecurityAssumptions` bundle or the
  `SgxDeploymentAssumptions` bundle. WP7 leaves the assumption
  layer alone.
- Do not add new Lean axioms outside the already-explicit
  assumption bundles. The bundle is the only place TEE-side
  `Prop` axioms are allowed.
- Do not promote a static-drift check to "proved." A drift check
  pins the *target* of the assumption, not the assumption itself.

## Repository Conventions Cross-Reference

The following sections of
[`coding-agent-conventions.md`](./coding-agent-conventions.md) apply
to WP7 directly:

- **Scientifically-Strongest-Route Preference** — applies whenever a
  Lean refinement is feasible. Prefer Lean-proved refinements over
  source-freeze-only checks.
- **Claim And TCB Discipline** — read it again before tightening
  any proof-grade checker theorem statement or trimming any
  compatibility shim.
- **Working Practices For Coding Agents** — auto-continue, small
  commits, patch-style edits, preserve unrelated dirty files, lint
  warnings are not blockers, terminal hygiene, write a handoff
  before stopping.

## Suggested Per-Checkpoint Commit Cadence

Each coherent technical step that passes the validation slice should
be its own commit:

- W7.1 — theorem-stack refactor, one commit per refactored layer.
  Landed:
  - `ecc3a97` — W7.1.a SgxExactProjection canonicalization +
    `proofGrade_sgx_projection_*` SGX paper-main facades.
  - `d3924f7` — W7.1.b SgxOramProjection: drop alternative-controller
    chain (bare / `_with_controller` /
    `_with_budgetController` / `_with_canonicalController`) plus
    matching legacy mirrors and unused alternative-relation defs.
  - `280fecd` — W7.1.c SgxMicroModel: drop
    `publicControllerMicroSemantics` smoke-test family plus the
    entire `budgetConsistentSGXMicroRelation` /
    `canonicalizedSGXMicroRelation` / canonical-trace infra.
  - `d3a973b` — W7.1.d drop dead
    `MicroTraceConsistentWithLeakage` /
    `_consistentWithLeakage` helpers in `SgxRelation.lean` /
    `SgxControllerTrace.lean`.
  - `5434cdd` — W7.1.e SgxJointProjection + legacy joint-mirror
    trim, plus probe `legacy_theorem_symbol_surface_checks` update
    for the canonicalized legacy axiom-symbol footprint.
  - Final layer-level docstring pass: SgxBoundary, SgxRelation,
    SgxController, SgxControllerTrace, plus the rest.
- W7.2 — proof-grade checker theorem-tightening, one commit per
  checker.
- W7.3 — compatibility-shim removal, one commit per shim category.
- W7.4 — new tamper / negative-test scenarios, one commit per
  scenario.
- W7.5 — determinism / reproducibility tightening, one commit per
  source category.
- W7.6 — reviewer-facing summary tightening, one commit.

For each landed checkpoint, update the WP7 status paragraph in
`docs/top-tier-paper-execution-roadmap.md` (Work Package 7 section)
and `docs/paper-theorem-profile.md` (Final Theorem Target row of the
assumption table). The commit message should explain *which layer
or artifact was canonicalized* and *what compatibility surface was
removed or tightened*.

## Known Risks And Pitfalls

- **Compatibility-shim drift.** As theorem statements tighten, some
  legacy probe report bits or older alias names may become
  unreachable. Each shim removal needs a synchronized probe report
  and Lean alias update.
- **Tamper-coverage gaps.** The current tamper suite covers
  representative drift; W7.4 should systematically extend tamper
  coverage to every theorem-facing artifact.
- **Reproducibility drift.** Generated artifacts should be
  exact-string reproducible from the Lean source. Any non-determinism
  (e.g., sort orders, hash maps with random iteration) must be
  caught and pinned.
- **Reviewer-summary completeness.** The reviewer-facing
  proved/assumed/trusted table should mention every assumption,
  every Lean theorem family, and every static-drift check. Drift
  here is silent.

## Where The Handoff Stops

This runbook hands off to subtask **W7.1** (theorem-stack refactor)
with:

- Clean main branch with WP4 fully closed, WP5 charter tasks 3-6
  closed, and WP6 closed end-to-end (last commit `1724852`).
- All validation gates green at the WP6-augmented validation slice
  (probe exit codes 0; `"accepted": true` on all non-static probe
  reports; static-checks restriction flags all `true`; full
  `lake build` 83 jobs succeed; all six WP6 drift checks plus the
  prior W5 drift checks all `true`; `git diff --check` clean).
- The companion handoff prompt
  [`wp7-handoff-prompt.md`](./wp7-handoff-prompt.md) ready to be
  pasted into a fresh coding-agent session.

When the next agent finishes a checkpoint, they update:

- The WP7 status paragraph in
  `docs/top-tier-paper-execution-roadmap.md` (Work Package 7 section).
- The Final Theorem Target row in `docs/paper-theorem-profile.md`.
- This runbook's "Suggested Per-Checkpoint Commit Cadence" section,
  recording the landed commit hashes.

When WP7 closes, the paper and artifact story should tell the same
minimal narrative with no hidden branches; this runbook can then be
archived or replaced with an end-of-line "all WPs closed" status
document.
