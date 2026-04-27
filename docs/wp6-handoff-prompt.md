# WP6 Handoff Prompt

Paste the block below into a fresh coding-agent session
(Claude Opus 4.7 with maximum reasoning, plan mode off, auto-continue
on) to resume Work Package 6. The prompt is self-contained: it sets
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

You are now picking up **Work Package 6: Close The Hostile-Host TEE
Theorem**. Work Packages 0–4 are closed. WP5 charter tasks **3, 4, 5,
6** are also closed (last commit `77a7ef1`); W5.1 / W5.2 (import vs
companion mechanization) remain open as a research-scope policy fork
documented in `docs/stronger-import-route-feasibility.md`.

The post-WP5 status of the explicit
`PathOramLocalPosmapV1SecurityAssumptions` bundle:

- `bucketEncryptionINDCPA` — paired with
  `pathOramLocalPosmapV1_cryptoProvenance` (RFC 8439 ChaCha20-Poly1305,
  Procter 2014 IACR ePrint composition analysis), drift-checked by
  `runtime_crypto_primitive_identity_pinned`.
- `metadataEncryptionINDCPA` — paired with the same record.
- `stashOverflowBounded` — paired with
  `pathOramLocalPosmapV1_stashOverflowProvenance` (Stefanov et al.
  JACM 2018 Theorem 5.1 at `Z = 5`, CCS 2013 fallback,
  `stash_bound = max(capacity, 1)`), drift-checked by
  `path_oram_deployed_stash_parameters_pinned`.

The 3-element list `pathOramLocalPosmapV1_assumptionAudit` and the
`pathOramLocalPosmapV1_assumptionAudit_length` /
`pathOramLocalPosmapV1_assumptionAudit_allCited` theorems pin the
post-WP5 bundle closure: every surviving assumption is **Cited /
externally justified**.

WP6 charter tasks **1, 2, 3, 4, 5, 6** are all open. The WP6 goal is
to upgrade from the idealized TEE-storage theorem
(`ComputationalTEEStorageObliviousWith`) to a real malicious-host
execution theorem over an explicit observer.

## First, Read These Files In This Exact Order

1. `docs/wp6-handoff-runbook.md` — your charter for this work
   package, the existing infrastructure, and the recommended starting
   subtask. This is the document that tells you *what to do*.
2. `docs/coding-agent-conventions.md` — the engineering process
   for this repository. This is the document that tells you *how
   to do it*. Pay special attention to:
   - "Scientifically-Strongest-Route Preference"
   - "Claim And TCB Discipline"
   - "Validation-Slice Protocol"
   - "Working Practices For Coding Agents"
   - "Common Pitfalls"
3. `docs/top-tier-paper-execution-roadmap.md` — the work-package
   narrative; section "Work Package 6" is your charter.
4. `docs/paper-theorem-profile.md` — the theorem profile, TCB
   table, "What is still open" list. The TEE deployment row is your
   starting state.
5. `docs/tee-runtime-hardening.md` — the TEE runtime hardening plan.

Then read the WP6-relevant Lean and Rust files listed in the
runbook. Pay special attention to:

- `proof/lean/UOToolchain/SgxBoundary.lean` — boundary-event model.
- `proof/lean/UOToolchain/SgxRelation.lean` — SGX proof relation.
- `proof/lean/UOToolchain/SgxController.lean` /
  `SgxControllerTrace.lean` — SGX controller / micro-trace model.
- `proof/lean/UOToolchain/SgxExactProjection.lean`,
  `SgxOramProjection.lean`, `SgxJointProjection.lean` — SGX
  projections.
- `proof/lean/UOToolchain/TeeDeployment.lean` — TEE deployment /
  storage interface.
- `runtime/uo-evm/src/controller.rs`,
  `runtime/uo-evm/src/runtime.rs`, `runtime/uo-evm/src/shell.rs` —
  the live controller and runtime shell.

## Operating Posture

- **Auto-continue.** Do not pause for confirmation when the next
  technical step is clear. Stop only if a human policy or design
  decision is genuinely required (e.g., which TEE attestation source
  to pin in W6.5), or if validation has failed in a way that needs
  human input to triage.
- **Small commits.** Each coherent technical step that passes the
  validation slice is its own commit. The commit message documents
  *which observer component or refinement was added* and *what
  provenance route the remaining deployment assumptions follow*. Do
  not amend prior commits.
- **Patch-style edits.** Manual edits are reviewable patches.
  Generated artifacts (Rust emitted from Lean, Lean inductives
  mirroring Rust enums) prefer the source-of-truth path; if you
  edit a generated file directly, update the generator/source-
  freeze checks in the same checkpoint.
- **Run the validation slice before declaring success.** Probe
  exit code 0, top-level `"accepted": true` in each non-static
  report, static-checks restriction flags all `true`, `git diff
  --check` clean, tamper-validation `rejected: true` count
  matches scenario count. The conventions doc has the exact
  slice; the WP6 runbook has the WP6-augmented slice.
- **Preserve unrelated dirty files.** Do not run `git checkout .`,
  `git restore .`, or any destructive git command without
  confirming with the user.
- **Lean lint warnings are not blockers.** Build failures,
  missing probe bits, and `git diff --check` failures are
  blockers; lint noise is not.

## Scope Discipline

WP6 lives at the **TEE deployment layer**. The compiler-side work
closed in WP4 and must stay green. The runtime kernel /
shell-boundary work closed in WP3 and must stay green. The backend
assumption layer closed in WP5 charter tasks 3-6 and must stay green.
WP6 modifies the SGX boundary observer model, the controller-refinement
theorem, the sealing/storage refinement theorem, and the explicit
deployment-assumption bundle. WP6 theorems land in:

- `proof/lean/UOToolchain/SgxBoundary.lean`
- `proof/lean/UOToolchain/SgxRelation.lean`
- `proof/lean/UOToolchain/SgxController.lean` /
  `SgxControllerTrace.lean`
- `proof/lean/UOToolchain/SgxExactProjection.lean` /
  `SgxOramProjection.lean` / `SgxJointProjection.lean`
- `proof/lean/UOToolchain/SgxMicroModel.lean`
- `proof/lean/UOToolchain/TeeDeployment.lean`
- `proof/lean/UOToolchain/ProofGrade.lean` (paper-facing facades)
- and as needed `docs/tee-runtime-hardening.md` /
  `docs/paper-theorem-profile.md` for provenance doc updates.

If your edits would change the W4 / W5 backend / runtime surface
beyond exposing new WP6 facades, stop and reconsider — that is WP4 /
WP5 territory and those charters are closed for the relevant subtasks.

## Recommended Next Subtask

The natural starting point is **W6.1: freeze the exact hostile-host
observer** — the most procedurally similar to the just-landed WP5
provenance work. The W6.1 work:

1. Audit the SGX boundary-event model in
   `proof/lean/UOToolchain/SgxBoundary.lean` and the related
   projection / micro-trace files for any observer components not
   yet pinned at the documented surface.
2. For each gap, freeze the component in Lean and pair it with an
   explicit provenance entry in `docs/tee-runtime-hardening.md`.
3. Add a probe-side static-drift check (mirroring the
   `runtime_crypto_primitive_identity_pinned` and
   `path_oram_deployed_stash_parameters_pinned` patterns) that
   pins the documented observer surface in the runtime source.
4. Expose each pinned component through `ProofGrade.lean` as a
   paper-facing `proofGrade_sgx_observer_*` facade if it
   strengthens a paper-facing claim.

After W6.1 lands, the next subtasks in recommended order:

- **W6.2**: model enclave-boundary calls, persistent I/O, exits, and
  any admitted shared-resource / paging observations.
- **W6.3**: prove the real controller/runtime behavior refines the
  frozen observer.
- **W6.4**: prove the sealing / storage path matches the theorem-side
  persistent model.
- **W6.5**: state attestation, rollback, crash, freshness, and
  patch-level assumptions explicitly and minimally.
- **W6.6**: remove any remaining ambiguity between idealized
  TEE-storage security and malicious-host execution obliviousness.

## Validation Slice (Standard WP6 Variant)

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
classify each WP6 claim explicitly:

- **Lean-proved, semantics-preserving** — the W6.1 / W6.3 / W6.4
  refinement / pinning work; new theorems in `SgxBoundary.lean` /
  `SgxRelation.lean` / `TeeDeployment.lean`.
- **Lean-proved, exactness/export** — the named hostile-host
  deployment theorem object that delivers the paper-facing
  malicious-host obliviousness statement.
- **Cited / externally justified** — the W6.5 deployment-assumption
  bundle: attestation, rollback, crash, freshness, patch-level
  assumptions stay explicit in Lean but are paired with explicit
  provenance citations to the relevant Intel SGX / attestation
  specifications.
- **Trusted external assumption (irreducible)** — anything that
  cannot be discharged by Lean refinement and is part of the
  deployment TCB.

Never write "WP6 closes the hostile-host TEE theorem" unless every
surviving deployment assumption has either (a) been removed from the
bundle by a Lean proof, or (b) been paired with an explicit
provenance entry that survives the conventions' "trusted external
assumption" filter.

## When To Stop

Stop and write an updated handoff (replacing
`docs/wp6-handoff-runbook.md` and `docs/wp6-handoff-prompt.md`,
following the same content discipline) when any of:

- Context limits force a session boundary.
- A genuine human policy or design decision is needed (e.g., which
  TEE attestation specification to pin in W6.5; or how to handle
  side-channel hardening assumptions).
- A subtask is fully landed and the next one is scoped large
  enough to deserve its own session.
- Validation has failed in a way that needs human triage.

The handoff must name the exact subtask checkpoint, the
validation commands just run, the known remaining gaps, and the
next recommended technically-clear step. See *"Write a handoff
before stopping on a long-running work package"* in
[`coding-agent-conventions.md`](./coding-agent-conventions.md#working-practices-for-coding-agents)
for the content requirements.

## Final Reminders

- Do not regress WP3, WP4, or WP5. The runtime residual-helper-shell
  route, the direct kernel-machine-confinement route, the
  W4.2 + W4.4 + W4.5 + W4.6 chain, and the W5.3 / W5.4 / W5.5 /
  W5.6 provenance pairings stay green.
- Do not weaken the existing
  `PathOramLocalPosmapV1SecurityAssumptions` bundle. WP6 leaves the
  backend assumption layer alone.
- Do not add a new Lean axiom outside an explicit
  deployment-assumption bundle. The bundle is the only place TEE-side
  `Prop` axioms are allowed.
- Do not promote a static-drift check to "proved." A drift check
  pins the *target* of the assumption, not the assumption itself.
- Do not add a probe report bit unless the underlying claim is
  either (a) a Lean theorem in the WP6 surface or (b) a static-
  drift check against the Rust controller / runtime / shell surface.

Begin with the runbook. The recommended next subtask is **W6.1**
(observer freeze). After W6.1, sequence W6.2 (enclave-boundary
modeling), then W6.3 (controller refinement), then W6.4 (sealing /
storage refinement), then W6.5 (deployment-assumption bundle), then
W6.6 (closure audit). Complete WP6 end-to-end and do not stop for
checkpoint unless you need a policy decision.
