# WP7 Handoff Prompt

Paste the block below into a fresh coding-agent session
(Claude Opus 4.7 with maximum reasoning, plan mode off, auto-continue
on) to resume Work Package 7. The prompt is self-contained: it sets
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

You are now picking up **Work Package 7: Canonicalize The Proof
Architecture And Artifact Story**. Work Packages 0–4 are closed. WP5
is closed: charter tasks 3, 4, 5, 6 are landed (last commit
`77a7ef1`), and the W5.1 / W5.2 import-vs-companion mechanization
fork was resolved on 2026-04-27 in favor of the citation route. The
repo's paper-main provenance is fixed at the **Cited / externally
justified** route; W5.1 and W5.2 are documented as future
strengthening, not in-scope work. WP6 is also closed end-to-end (last
commit `1724852`); the W6.1 observer freeze, the W6.2 boundary-call
and persistent-I/O models, the W6.3 controller-refinement integration,
the W6.4 sealing / storage-refinement integration, the W6.5 explicit
deployment-assumption bundle, and the W6.6 closure audit are all
landed in `proof/lean/UOToolchain/SgxObserverFreeze.lean` plus the
matching `proofGrade_sgx_*` facades in
`proof/lean/UOToolchain/ProofGrade.lean`. Do not re-open WP6 unless
the user explicitly redirects.

The post-WP6 status of the WP6 surface:

- W6.1 — `sgxObserverSurfaceProvenance` pins the canonical
  page-region / controller-phase / page-event / exit-event
  vocabularies plus the shared-resource tick literal and the
  page-event encoding formula; drift-checked by
  `sgx_observer_surface_pinned`.
- W6.2 boundary-call — `sgxBoundaryCallProvenance` pins the
  `"oram_access"` API literal, the `Enter` / `Exit` direction
  vocabulary, the boundary-event budget formula
  `2 * total_oram_accesses + 2`, and the canonical
  boundary-schedule shape; drift-checked by
  `sgx_boundary_call_model_pinned`.
- W6.2 persistent-I/O — `sgxPersistentIoProvenance` pins the
  `PhysicalRead` / `PhysicalWrite` field schemas and the
  `WriteClass` vocabulary `[Set, Clear, Same, Update]`;
  drift-checked by `sgx_persistent_io_model_pinned`.
- W6.3 — `sgxControllerRefinementProvenance` and
  `SgxControllerObserverRefinement` integrate the canonical Lean
  controller-shape constructor with the W6.1 / W6.2 freeze;
  drift-checked by `sgx_controller_refinement_pinned`.
- W6.4 — `sgxStorageRefinementProvenance` and
  `SgxStorageRefinement` package the `viewTEEStore` field
  projection rules; drift-checked by
  `sgx_storage_refinement_pinned`.
- W6.5 — `SgxDeploymentAssumptions` carries six explicit `Prop`
  fields (`attestationAuthenticity`, `enclaveMemoryIsolation`,
  `rollbackResistance`, `freshnessGuarantee`,
  `crashRecoveryDiscipline`, `patchLevelTrust`), each paired with
  a `SgxDeploymentAssumptionProvenance` record citing an Intel
  SGX specification (`IntelSGXAttestationReference`,
  `IntelSGXSDM3D`, `IntelSGXSDKDeveloperReference`,
  `IntelSGXSecurityCenter`); drift-checked by
  `sgx_deployment_assumption_bundle_pinned`.
- W6.6 — `sgxHostileHostClosureAudit` is the six-element
  audit-summary list, with closure theorems
  `sgxHostileHostClosureAudit_length` /
  `sgxHostileHostClosureAudit_leanProvedEntries` /
  `sgxHostileHostClosureAudit_allClassified` /
  `sgxHostileHostClosureAudit_driftCheckNames` pinning the audit
  conclusion at the Lean type level.

WP7 charter tasks **1, 2, 3, 4, 5, 6** are all open. The WP7 goal
is to make the final proof stack look minimal, inevitable, and easy
to review.

## First, Read These Files In This Exact Order

1. `docs/wp7-handoff-runbook.md` — your charter for this work
   package, the existing infrastructure, and the recommended
   starting subtask. This is the document that tells you *what to
   do*.
2. `docs/coding-agent-conventions.md` — the engineering process
   for this repository. This is the document that tells you *how
   to do it*. Pay special attention to:
   - "Scientifically-Strongest-Route Preference"
   - "Claim And TCB Discipline"
   - "Validation-Slice Protocol"
   - "Working Practices For Coding Agents"
   - "Common Pitfalls"
3. `docs/top-tier-paper-execution-roadmap.md` — the work-package
   narrative; section "Work Package 7" is your charter.
4. `docs/paper-theorem-profile.md` — the theorem profile, TCB
   table, "What is still open" list. The Final Theorem Target row
   is your starting state.
5. `docs/tee-runtime-hardening.md` — the TEE runtime hardening plan
   (now containing the W6.1–W6.6 frozen observer / boundary-call /
   persistent-I/O / controller-refinement / storage-refinement /
   deployment-assumption / closure-audit sections).

Then read the WP7-relevant Lean and Rust files listed in the
runbook. Pay special attention to:

- `proof/lean/UOToolchain.lean` — the umbrella module.
- `proof/lean/UOToolchain/ProofGrade.lean` — the paper-facing
  facade module.
- `proof/lean/lakefile.lean` — the Lake build manifest.
- `probe/mplus-probe/src/lib.rs` — the probe binary that runs every
  Lean checker, every static drift check, every tamper scenario.
- `probe/mplus-probe/src/main.rs` — the probe entrypoint.
- `scripts/run_validation.sh` — the full validation-gate runner.
- `scripts/run_bridge_validation.sh` — the smaller bridge-validation
  runner.
- `results/reviewer_summary.json` / `results/reviewer_summary.md` —
  the machine-generated reviewer-facing table.

## Operating Posture

- **Auto-continue.** Do not pause for confirmation when the next
  technical step is clear. Stop only if a human policy or design
  decision is genuinely required (e.g., which compatibility shim
  to retain for legacy probe reports), or if validation has failed
  in a way that needs human input to triage.
- **Small commits.** Each coherent technical step that passes the
  validation slice is its own commit. The commit message documents
  *which layer or artifact was canonicalized* and *what
  compatibility surface was removed or tightened*. Do not amend
  prior commits.
- **Patch-style edits.** Manual edits are reviewable patches.
  Generated artifacts (Rust emitted from Lean, Lean inductives
  mirroring Rust enums) prefer the source-of-truth path.
- **Run the validation slice before declaring success.** Probe
  exit code 0, top-level `"accepted": true` in each non-static
  report, static-checks restriction flags all `true`, all six WP6
  drift checks plus the prior W5 drift checks all `true`, `git
  diff --check` clean, tamper-validation `rejected: true` count
  matches scenario count. The conventions doc has the exact slice;
  the WP7 runbook has the WP7-augmented slice.
- **Preserve unrelated dirty files.** Do not run `git checkout .`,
  `git restore .`, or any destructive git command without
  confirming with the user.
- **Lean lint warnings are not blockers.** Build failures, missing
  probe bits, and `git diff --check` failures are blockers; lint
  noise is not.

## Scope Discipline

WP7 lives at the **proof-architecture and artifact layer**. The
compiler-side work closed in WP4 must stay green. The runtime
kernel / shell-boundary work closed in WP3 must stay green. The
backend assumption layer closed in WP5 charter tasks 3-6 must stay
green. The hostile-host TEE theorem closed in WP6 must stay green
(W6.1–W6.6 freeze + refinement + bundle + audit). WP7 work goes
into:

- `proof/lean/UOToolchain.lean` (umbrella imports)
- `proof/lean/UOToolchain/ProofGrade.lean` (paper-facing facades)
- the existing checker executables under `proof/lean/Check*.lean`
- the existing semantics modules (theorem-tightening, not
  rewriting)
- `probe/mplus-probe/src/lib.rs` (canonicalization, tamper
  coverage, reviewer-summary tightening)
- `scripts/run_validation.sh` and
  `scripts/run_bridge_validation.sh` (validation-gate
  canonicalization)
- and as needed `docs/top-tier-paper-execution-roadmap.md` /
  `docs/paper-theorem-profile.md` for status / TCB-table updates.

If your edits would change the W3 / W4 / W5 / W6 surface beyond
canonicalization, stop and reconsider — those are prior work
packages and their charters are closed for the relevant subtasks.

## Recommended Next Subtask

The natural starting point is **W7.1: refactor the theorem stack so
each layer has one abstraction function and one main theorem.**

Concretely:

1. Audit the SGX projection chain (`SgxBoundary.lean` →
   `SgxRelation.lean` → `SgxController.lean` →
   `SgxControllerTrace.lean` → `SgxMicroModel.lean` →
   `SgxExactProjection.lean` / `SgxOramProjection.lean` /
   `SgxJointProjection.lean`) for layers that expose more than one
   "main theorem" in the public API.
2. For each layer, identify the single abstraction function and the
   single main theorem; classify any other public symbols as
   internal helpers or paper-facade-only re-exports.
3. Move helpers to private namespaces or move re-exports to
   `ProofGrade.lean`.
4. Update the docs / probe accordingly.

After W7.1 lands, the next subtasks in recommended order:

- **W7.2**: theorem-tighten every proof-grade checker.
- **W7.3**: remove compatibility shims from the main paper
  narrative.
- **W7.4**: add tamper and negative tests for every theorem-facing
  artifact.
- **W7.5**: make artifact generation deterministic and reproducible.
- **W7.6**: report proof-checking cost, artifact size, runtime
  overhead, TCB size, and explicit assumptions in the
  reviewer-facing summary.

## Validation Slice (Standard WP7 Variant)

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

For larger checkpoints (new probe scenarios, new Cargo dependencies,
schema changes), run the full Validation Gates set
(`scripts/run_validation.sh`).

## Claim Discipline

When updating the roadmap status text or the paper theorem profile,
classify each WP7 claim explicitly:

- **Lean-proved, semantics-preserving** — refactoring or
  theorem-tightening that keeps existing semantics-preservation
  results.
- **Lean-proved, exactness/export** — the named main paper theorem
  object plus the canonical artifact-export endpoints.
- **Cited / externally justified** — the W5 / W6.5 backend +
  deployment provenance pairings stay at this classification; do
  not weaken them.
- **Trusted external assumption (irreducible)** — anything that
  cannot be discharged by Lean refinement.

WP7 should not introduce new fields in any of these buckets. The
work is canonicalization: removing duplicate theorem statements,
pruning compatibility shims, tightening tamper coverage, and
tightening the reviewer-facing summary so the story is minimal.

## When To Stop

Stop and write an updated handoff (replacing
`docs/wp7-handoff-runbook.md` and `docs/wp7-handoff-prompt.md`,
following the same content discipline) when any of:

- Context limits force a session boundary.
- A genuine human policy or design decision is needed (e.g., which
  compatibility shim to retain).
- A subtask is fully landed and the next one is scoped large
  enough to deserve its own session.
- Validation has failed in a way that needs human triage.

The handoff must name the exact subtask checkpoint, the validation
commands just run, the known remaining gaps, and the next
recommended technically-clear step. See *"Write a handoff before
stopping on a long-running work package"* in
[`coding-agent-conventions.md`](./coding-agent-conventions.md#working-practices-for-coding-agents)
for the content requirements.

## Final Reminders

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
  assumption bundles. The bundles are the only places TEE-side
  `Prop` axioms are allowed.
- Do not promote a static-drift check to "proved." A drift check
  pins the *target* of the assumption, not the assumption itself.
- Do not add a probe report bit unless the underlying claim is
  either (a) a Lean theorem in the WP7 surface or (b) a static-
  drift check against the runtime / shell / build-artifact surface.

Begin with the runbook. The recommended next subtask is **W7.1**
(theorem-stack refactor). After W7.1, sequence W7.2 (proof-grade
checker tightening), then W7.3 (compat-shim removal), then W7.4
(tamper / negative-test extension), then W7.5 (determinism /
reproducibility), then W7.6 (reviewer-facing summary tightening).
Complete WP7 end-to-end and do not stop for checkpoint unless you
need a policy decision.
