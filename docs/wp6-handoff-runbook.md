# WP6 Handoff Runbook

This runbook hands off Work Package 6 (WP6) — *close the hostile-host
TEE theorem* — to the next coding agent.

It does not duplicate the engineering process. The authoritative
process document is
[`coding-agent-conventions.md`](./coding-agent-conventions.md). Read it
first; this runbook only carries the WP6-specific facts that don't
belong in a process doc.

## Where We Are

WP5 charter tasks **3, 4, 5, 6** closed on 2026-04-27 (commits across
the W5.5 → W5.4 → W5.3 → W5.6 chain on top of `7e50d42`). The
post-WP5 status of the explicit
`PathOramLocalPosmapV1SecurityAssumptions` bundle:

- **W5.5 (store/codec semantic alignment):** the existing 43-theorem
  `RuntimeStoreCodecSemantics` layer was extended with the
  `cipherKeyBytes = 32` constant pin, `sealedMagic` length /
  `ValidByte` proofs, the encoded-length-doubles-plain-length identity,
  the four `SealedRecordParts.{magic,nonce,ciphertext,tag}_length_of_validShape`
  projections, the open-shape magic-equality fact, the
  `decodeSealedRecord_some_componentLengths` named theorem, and the
  `uoStoreSlotAad_prefix_publicShape` AAD shape pin. Seven
  `proofGrade_runtime_store_codec_*` facades expose the new theorems on
  the paper-facing surface.
- **W5.4 (crypto-assumption provenance):** new structure
  `PathOramLocalPosmapV1CryptoProvenance` and runtime-pinned record
  `pathOramLocalPosmapV1_cryptoProvenance` pair the
  `bucketEncryptionINDCPA` / `metadataEncryptionINDCPA` assumptions
  with explicit citations (RFC 8439 ChaCha20-Poly1305, Procter 2014
  IACR ePrint AEAD-composition analysis), the
  `runtime_crypto_primitive_identity_pinned` static-drift check, and
  the codec-semantic constants pinned in W5.5. Five
  `proofGrade_path_oram_local_posmap_v1_crypto_provenance_*` facades
  expose the constants and the named drift check.
- **W5.3 (deployed-parameter stash-overflow provenance):** new
  structure `PathOramLocalPosmapV1StashOverflowProvenance` and
  runtime-pinned record `pathOramLocalPosmapV1_stashOverflowProvenance`
  pair the `stashOverflowBounded` assumption with the JACM 2018
  Theorem 5.1 citation (CCS 2013 fallback), the deployed parameter
  substitution (`Z = 5`, `stash_bound = max(capacity, 1)`), the
  working-stash capacity formula consumed by the runtime, the JACM
  tail-bound expression (`P[stash size > R] <= 14 * 0.6002^R`), and the
  named static-drift check `path_oram_deployed_stash_parameters_pinned`.
  The probe enforces this drift check by string-matching the deployed
  Path-ORAM construction and validation sites in
  `crates/uo-core/src/manifest.rs`. Four
  `proofGrade_path_oram_local_posmap_v1_stash_overflow_provenance_*`
  facades expose the constants.
- **W5.6 (bundle housekeeping):** new structure
  `PathOramLocalPosmapV1AssumptionAuditEntry` and the 3-element list
  `pathOramLocalPosmapV1_assumptionAudit` summarize the post-W5.3 /
  post-W5.4 closure: every surviving bundle field is **Cited /
  externally justified**, paired with a provenance record and a named
  probe drift check. The `pathOramLocalPosmapV1_assumptionAudit_length`
  and `pathOramLocalPosmapV1_assumptionAudit_allCited` theorems pin
  the audit at the Lean type level. Two
  `proofGrade_path_oram_local_posmap_v1_assumption_audit_*` facades
  expose the bundle-closure facts.

WP5 charter tasks **1 and 2** (machine-checked import vs companion
mechanization) remain open as a research-scope policy fork. Per
[`docs/stronger-import-route-feasibility.md`](./stronger-import-route-feasibility.md),
no external machine-checked Path-ORAM theorem object cleanly matches
`PaperMainPathOramTheoremSourceAt` today; closing W5.1 / W5.2 requires
either obtaining an external artifact whose Path-ORAM theorem matches
that interface or building a companion theorem-adapter project. Both
options are real research-scope decisions, not in-repo work.

WP6 now opens with the goal of upgrading the idealized TEE-storage
theorem to a real malicious-host execution theorem over an explicit
observer.

## WP6 Charter (Verbatim From The Roadmap)

Objective: move from an idealized TEE-storage theorem to a real
malicious-host execution theorem over an explicit observer.

Concrete tasks:

1. Freeze the exact hostile-host observer and keep it aligned across
   docs and Lean.
2. Model enclave-boundary calls, persistent I/O, exits, and any
   admitted shared-resource or paging observations.
3. Prove that the real controller/runtime behavior refines that
   observer.
4. Prove that the sealing/storage path matches the theorem-side
   persistent model.
5. State attestation, rollback, crash, freshness, and patch-level
   assumptions explicitly and minimally.
6. Remove any remaining ambiguity between idealized TEE-storage
   security and malicious-host execution obliviousness.

Deliverables:

- one hostile-host deployment theorem
- one explicit deployment assumption bundle

Exit gate: the paper can claim malicious-host security without hiding
the observer or the assumptions.

## Existing Infrastructure (Do Not Rewrite)

These files already exist and are the right place to build on:

### Theorem-facing surface (Lean)

- [`proof/lean/UOToolchain/SgxBoundary.lean`](../proof/lean/UOToolchain/SgxBoundary.lean)
  — boundary-event model and SGX execution-security predicate.
- [`proof/lean/UOToolchain/SgxRelation.lean`](../proof/lean/UOToolchain/SgxRelation.lean)
  — the SGX proof relation (storage + micro components).
- [`proof/lean/UOToolchain/SgxController.lean`](../proof/lean/UOToolchain/SgxController.lean)
  / [`SgxControllerTrace.lean`](../proof/lean/UOToolchain/SgxControllerTrace.lean)
  — SGX controller / micro-trace model.
- [`proof/lean/UOToolchain/SgxExactProjection.lean`](../proof/lean/UOToolchain/SgxExactProjection.lean),
  [`SgxOramProjection.lean`](../proof/lean/UOToolchain/SgxOramProjection.lean),
  [`SgxJointProjection.lean`](../proof/lean/UOToolchain/SgxJointProjection.lean)
  — exact, ORAM-side, and joint SGX projections.
- [`proof/lean/UOToolchain/SgxMicroModel.lean`](../proof/lean/UOToolchain/SgxMicroModel.lean)
  — modeled SGX micro-trace behavior.
- [`proof/lean/UOToolchain/TeeDeployment.lean`](../proof/lean/UOToolchain/TeeDeployment.lean)
  — TEE deployment / storage interface.

### Runtime / Rust controller surface

- [`runtime/uo-evm/src/controller.rs`](../runtime/uo-evm/src/controller.rs)
  and the supporting boundary/runtime modules.
- [`runtime/uo-evm/src/runtime.rs`](../runtime/uo-evm/src/runtime.rs).
- [`runtime/uo-evm/src/shell.rs`](../runtime/uo-evm/src/shell.rs).

### Provenance + plan docs

- [`docs/tee-runtime-hardening.md`](./tee-runtime-hardening.md)
  — TEE runtime hardening plan.
- [`docs/paper-theorem-profile.md`](./paper-theorem-profile.md)
  — TEE deployment row in the explicit-assumption table.

## Claim Taxonomy For WP6

From the
[Claim And TCB Discipline](./coding-agent-conventions.md#claim-and-tcb-discipline)
section of the conventions, every WP6 statement falls into one of:

- **Lean-proved, semantics-preserving** — refinements of the real
  controller/runtime against the modeled SGX observer.
- **Lean-proved, exactness/export** — the named hostile-host
  deployment theorem object that the paper cites.
- **Cited / externally justified** — TEE deployment hardware /
  attestation assumptions (rollback discipline, attestation
  authenticity, patch model). These remain as **trusted external
  assumptions** in the explicit deployment-assumption bundle, paired
  with explicit provenance citations to the relevant Intel SGX /
  attestation specifications.
- **Trusted external assumption (irreducible)** — anything that
  cannot be discharged by Lean refinement and is part of the deployment
  TCB.

## Recommended Starting Subtask

The natural starting point is **W6.1: freeze the exact hostile-host
observer** — the most procedurally similar to the WP5 provenance work.
Pin every component of the SGX boundary observer used by the paper's
SGX execution-security claim, document the components in
`docs/tee-runtime-hardening.md`, and align the Lean models with the
documented observer surface.

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

## Validation Slice

Doc-only edits run `git diff --check` only. For Lean / Rust / probe
edits, run the standard slice from
[`coding-agent-conventions.md`](./coding-agent-conventions.md#validation-slice-protocol),
plus the WP6-relevant scenarios:

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

For larger checkpoints (new boundary cuts, new tamper scenarios,
new probe scenarios), run `scripts/run_validation.sh` to exercise the
full suite.

Cross-checks before declaring success: probe exit code 0, top-level
`"accepted": true` in each non-static report, the static-checks
restriction flags
(`legacy_axiom_definition_surface_restricted`,
`legacy_theorem_symbol_surface_restricted`,
`proofgrade_checker_import_surface_restricted`,
`proofgrade_checker_legacy_symbol_mentions_absent`,
`proofgrade_core_module_import_surface_restricted`)
all `true`, `git diff --check` clean, tamper-validation scenario
count matches `rejected: true` count.

## What WP6 Must NOT Do

- Do not regress WP3, WP4, or WP5. The runtime residual-helper-shell
  route, the direct kernel-machine-confinement route, the W4.2 +
  W4.4 + W4.5 + W4.6 chain, and the W5.3 / W5.4 / W5.5 / W5.6
  provenance pairings stay green.
- Do not weaken the existing
  `PathOramLocalPosmapV1SecurityAssumptions` bundle. WP6 leaves the
  backend assumption layer alone.
- Do not add a new Lean axiom outside an explicit deployment-assumption
  bundle. The bundle is the only place TEE-side `Prop` axioms are
  allowed.
- Do not promote a static-drift check to "proved." A drift check pins
  the *target* of the assumption, not the assumption itself.

## Repository Conventions Cross-Reference

The following sections of
[`coding-agent-conventions.md`](./coding-agent-conventions.md) apply
to WP6 directly:

- **Scientifically-Strongest-Route Preference** — applies whenever a
  Lean refinement is feasible. Prefer Lean-proved refinements over
  source-freeze-only checks.
- **Claim And TCB Discipline** — read it again before writing the WP6
  status paragraph or annotating a deployment assumption with a
  provenance citation.
- **Working Practices For Coding Agents** — auto-continue, small
  commits, patch-style edits, preserve unrelated dirty files, lint
  warnings are not blockers, terminal hygiene, write a handoff before
  stopping.

## Suggested Per-Checkpoint Commit Cadence

Each coherent technical step that passes the validation slice should
be its own commit:

- W6.1 — observer freeze, one commit per pinned observer component.
- W6.2 — enclave-boundary modeling, one commit per modeled boundary
  type (boundary calls, persistent I/O, exits, shared-resource
  observations, paging observations).
- W6.3 — controller-refinement theorem, one commit per refinement step.
- W6.4 — sealing / storage refinement, one commit per refinement step.
- W6.5 — deployment-assumption bundle, one commit per assumption
  field landed.
- W6.6 — closure audit (mirroring W5.6), one commit.

For each landed checkpoint, update the WP6 status paragraph in
`docs/top-tier-paper-execution-roadmap.md` (Work Package 6 section)
and `docs/paper-theorem-profile.md` (TEE deployment row of the
assumption table). The commit message should explain *which observer
component or refinement was added* and *what provenance route the
remaining deployment assumptions follow*.

## Known Risks And Pitfalls

- **Observer freeze drift.** As the runtime evolves, the modeled SGX
  observer must remain aligned with the documented one. Add static
  drift checks in the probe to reject representative drift.
- **Implicit TEE assumptions.** TEE deployment carries many implicit
  hardware/firmware assumptions (microcode patches, side-channel
  hardening, attestation key management). Each must be made explicit
  in the deployment-assumption bundle.
- **Idealized vs malicious-host gap.** The current paper main route
  goes through `ComputationalTEEStorageObliviousWith`, which is an
  idealized storage model. The W6 work must close the gap between
  this idealized model and a real malicious-host execution.
- **Lean axiom discipline.** Any new TEE-side `Prop` axiom must live
  in the explicit deployment-assumption bundle, paired with provenance
  metadata and a named drift check (mirroring the W5.3 / W5.4
  pattern).

## Where The Handoff Stops

This runbook hands off to subtask **W6.1** (observer freeze) with:

- Clean main branch with WP4 fully closed and WP5 charter tasks 3-6
  closed (last commit `77a7ef1`).
- All validation gates green at the WP5-augmented validation slice
  (probe exit codes 0; `"accepted": true` on all non-static probe
  reports; static-checks restriction flags all `true`; full
  `lake build` 82 jobs succeed; `git diff --check` clean).
- The companion handoff prompt
  [`wp6-handoff-prompt.md`](./wp6-handoff-prompt.md) ready to be
  pasted into a fresh coding-agent session.

The W5.1 / W5.2 import-vs-companion mechanization fork remains open
and is documented in
[`docs/stronger-import-route-feasibility.md`](./stronger-import-route-feasibility.md).
The user must make this research-scope policy decision (companion
mechanization vs citation-route fall-back) separately from the WP6
work.

When the next agent finishes a checkpoint, they update:

- The WP6 status paragraph in
  `docs/top-tier-paper-execution-roadmap.md` (Work Package 6 section).
- The TEE deployment row in `docs/paper-theorem-profile.md`.
- This runbook's "Suggested Per-Checkpoint Commit Cadence" section,
  recording the landed commit hashes.

When WP6 closes, replace these handoff packages with WP7 handoff
packages following the same structure.
