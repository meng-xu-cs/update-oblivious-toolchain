# WP5 Handoff Runbook

This runbook hands off Work Package 5 (WP5) — *discharge the concrete
backend assumption bundle until only genuinely external cryptographic
and deployment assumptions remain* — to the next coding agent.

It does not duplicate the engineering process. The authoritative
process document is
[`coding-agent-conventions.md`](./coding-agent-conventions.md). Read it
first; this runbook only carries the WP5-specific facts that don't
belong in a process doc.

## Where We Are

WP4 closed on 2026-04-27. All six WP4 charter tasks are now Lean-
proved end-to-end (commits across the W4.1 → W4.6 chain, last
recorded in `7e50d42`):

- W4.1 / W4.1b / W4.1+ / W4.1++ / W4.1+++: real operational evaluator
  over the structured admitted IR, total over the W4.3 fragment, with
  masked-store updates.
- W4.2: full admitted post-resolution Sol AST + AST→IR lowering +
  per-Expr / per-Statement / Body / Function preservation theorems.
- W4.3: count-based confidential-fragment witness ↔ structural
  fragment-validity iff theorem.
- W4.4: typed kernel DSL + B-1 forward iff (all four levels) + B-2
  semantics-preservation (all four levels) + reverse iff (all four
  levels). The `proofGrade_ir_to_kernel_lower_compiled_function_iff_kernel_lowerable`
  facade exposes the full lowering biconditional.
- W4.5: enabling theorem `proofGrade_sol_to_kernel_outcome_preservation`
  composes W4.2 + W4.4; main-body static projections plus body- /
  program-level runtime-vs-static `kernelSteps` lift land the manifest-
  exactness chain on the happy path.
- W4.6: `proofGrade_compiler_correctness_supersedes_artifact_checker`
  bundles W4.2 + W4.4 + W4.5 into a single named statement that
  supersedes the direct artifact checker as the trust root.

The full source-to-manifest correctness chain on the happy path is now
Lean-proved: `Sol.evalFunction fn cfg` = `IR.evalContract cfg` =
`IR.evalKernelProgram kp cfg`, with runtime `kernelSteps` matching
`kp.expectedKernelSteps` matching the manifest's `kernel_steps` field.
The W4.4 forward + reverse iff equivalence pins the admission
condition precisely.

WP5 now opens with the goal of shrinking the explicit
`PathOramLocalPosmapV1SecurityAssumptions` bundle until only
genuinely external cryptographic / deployment assumptions remain.

## WP5 Charter (Verbatim From The Roadmap)

Objective: reduce the concrete backend assumption bundle until only
genuinely external cryptographic and deployment assumptions remain.

Concrete tasks:

1. Prefer a machine-checked theorem import at the frozen backend
   interface if a suitable external artifact can be imported cleanly.
2. Otherwise build the companion mechanization locally at that exact
   interface.
3. Discharge `stashOverflowBounded` for the deployed parameter regime.
4. Discharge `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA`
   for the concrete cryptographic scheme boundary actually used by
   the runtime.
5. Prove that the store/codec/serialization layer matches the
   theorem-side storage abstraction.
6. Remove any assumption that survives only because of convenience
   engineering.

Deliverables:

- one minimized backend assumption bundle
- one explicit provenance route for every remaining backend assumption

Exit gate: every remaining backend assumption is concrete, justified,
and unavoidable.

## Existing Infrastructure (Do Not Rewrite)

These files already exist and are the right place to build on, not
parallel-track around:

### Theorem-facing surface (Lean)

- [`proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`](../proof/lean/UOToolchain/PathOramLocalPosmapV1.lean)
  (~538 lines). Houses the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle:
  ```
  structure PathOramLocalPosmapV1SecurityAssumptions where
    bucketEncryptionINDCPA : Prop
    metadataEncryptionINDCPA : Prop
    stashOverflowBounded : Prop
  ```
  plus projections to `CanonicalLeafValueSecurityAssumptions`,
  `PathOramSecurityAssumptions`, `OramSecurityInterface`,
  `SGXProofRelation`, etc. Also exports the full theorem family
  `pathOramLocalPosmapV1_*` that lifts a discharged bundle through
  to the paper-facing TEE-storage / SGX / paper-main routes.
- [`proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean`](../proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean)
  (~412 lines). Refinement layer between the local-posmap candidate
  and the standard ORAM theorem.
- [`proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`](../proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean)
  (~664 lines). The standard-theorem packaging at the frozen
  backend interface.
- [`proof/lean/UOToolchain/PathOramJACMTheorem.lean`](../proof/lean/UOToolchain/PathOramJACMTheorem.lean)
  (~279 lines). `PathOramJACMLiteratureTheorem` /
  `PathOramJACMLiteratureTheoremAt` — the JACM 2018 theorem
  packaged at the repo's standard-storage interface, with `Z = 5`
  buckets-per-bucket pinned. The theorem object is parametrized
  over `PathOramLocalPosmapV1SecurityAssumptions`; the
  `stashOverflowTheorem : assumptions.stashOverflowBounded` field
  is the load-bearing hypothesis.
- [`proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`](../proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean)
  (~958 lines). Paper-main theorem route. The
  `PaperMainPathOramTheoremSourceAt` interface is the frozen
  imported-theorem target; the `pathOramLocalPosmapV1_artifactAppendixTheoremSource`
  self-instantiates it from `PathOramJACMLiteratureTheoremAt` plus
  the explicit stash assumption (the appendix / executable
  artifact route).
- [`proof/lean/UOToolchain/RuntimePaperInstantiation.lean`](../proof/lean/UOToolchain/RuntimePaperInstantiation.lean)
  (~1518 lines). Concrete runtime instantiation that ties the
  paper-main theorem to actual runtime config / parameters.

### Storage / codec semantic layer (Lean)

- [`proof/lean/UOToolchain/RuntimeStoreCodecSemantics.lean`](../proof/lean/UOToolchain/RuntimeStoreCodecSemantics.lean)
  (~821 lines, 43 theorems). Models the store codec layer: sealed
  encoding, nonzero encoding, AAD shape, write shape, etc. Already
  pins `sealedNonceBytes = 12` and `sealedTagBytes = 16` (matching
  the Rust ChaCha20Poly1305 nonce / tag sizes).
- [`proof/lean/UOToolchain/RuntimeOramCodecSemantics.lean`](../proof/lean/UOToolchain/RuntimeOramCodecSemantics.lean)
  (96 theorems). Models the ORAM codec layer.
- [`proof/lean/UOToolchain/RuntimeStoreHelperSemantics.lean`](../proof/lean/UOToolchain/RuntimeStoreHelperSemantics.lean)
  and [`RuntimeOramHelperSemantics.lean`](../proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean)
  — helper-layer semantic models.

### Runtime / Rust crypto surface (the real cryptography)

- [`runtime/uo-store/src/generated_surface.rs`](../runtime/uo-store/src/generated_surface.rs)
  — the actual `StoreCipher`. Implements `seal_and_wipe_*` and
  `with_opened_payload` over `chacha20poly1305::ChaCha20Poly1305`
  (RFC 8439 ChaCha20-Poly1305 AEAD), with 32-byte keys, 12-byte
  nonces, 16-byte tags, and per-write `WipeOnDrop` of plaintext
  buffers. **This is the concrete cryptographic scheme that
  `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` are
  claims about.**
- [`runtime/uo-store/src/codec.rs`](../runtime/uo-store/src/codec.rs)
  — wraps `generated_surface.rs` with `NonZeroCodec` and
  test-side fixtures.
- [`runtime/uo-store/src/store.rs`](../runtime/uo-store/src/store.rs)
  — store front-end consumed by `uo-evm`.
- [`runtime/uo-evm/src/oram.rs`](../runtime/uo-evm/src/oram.rs)
  — Path-ORAM access pattern over the sealed store. Uses
  `StoreCipher` indirectly through the store layer.

### Provenance plan docs

- [`docs/path-oram-citation-import-plan.md`](./path-oram-citation-import-plan.md)
  (~9.7 kB). The current paper-main provenance plan: cite Stefanov
  et al. JACM 2018 (DOI 10.1145/3177872) as the primary source for
  the Path ORAM theorem, with Stefanov et al. CCS 2013 as
  fallback. Also lists the FM 2024 Isabelle/HOL work and the
  CoqPL 2023 proposal as mechanization-candidate signposts (not
  ready as drop-in theorem objects today).
- [`docs/stronger-import-route-feasibility.md`](./stronger-import-route-feasibility.md)
  (~5.8 kB). Assesses whether the citation route can honestly be
  upgraded to a "machine-checked external artifact" route. The
  current verdict: **not yet**. Closing W5.1 (machine-checked
  import) requires either obtaining an external artifact whose
  Path ORAM theorem matches `PaperMainPathOramTheoremSourceAt` or
  building a companion theorem-adapter project that adapts an
  existing external mechanization. Both are real research-scope
  decisions.
- [`docs/path-oram-theorem-sources.bib`](./path-oram-theorem-sources.bib)
  — BibTeX entries for the JACM and CCS sources.

## Claim Taxonomy For WP5

This is the most common confusion to avoid. From the
[Claim And TCB Discipline](./coding-agent-conventions.md#claim-and-tcb-discipline)
section of the conventions, every WP5 statement falls into one of:

- **Lean-proved, semantics-preserving** — what most codec-side WP5
  work produces. *e.g.*, "the Lean `RuntimeStoreCodecSemantics`
  sealed-encoding shape matches the Rust `StoreCipher::seal_and_wipe_*`
  output shape." This is the scope of W5.5 (store/codec
  semantic alignment).
- **Lean-proved, exactness/export** — the Lean side proves a
  concrete theorem object that has the *shape* of the imported
  theorem, instantiated from explicit assumptions. *e.g.*, the
  `pathOramLocalPosmapV1_artifactAppendixTheoremSource` route
  delivers `PaperMainPathOramTheoremSourceAt` from the JACM
  theorem object plus the stash assumption.
- **Cited / externally justified** — the `bucketEncryptionINDCPA`
  and `metadataEncryptionINDCPA` route once W5.4 lands: the
  assumption stays explicit in Lean but is paired with an explicit
  provenance citation (RFC 8439, AEAD-security analyses) plus a
  Lean drift check that the Rust crypto surface still matches the
  cited primitive.
- **Trusted external assumption (irreducible)** — the final
  `PathOramLocalPosmapV1SecurityAssumptions` bundle after WP5
  closes. Each surviving assumption must have an explicit
  provenance entry; nothing remains as "convenience engineering."

Never write "WP5 discharges the backend assumption bundle" unless
every surviving assumption has either (a) been removed from the
bundle by a Lean proof, or (b) been paired with an explicit
provenance entry that survives the conventions' "trusted external
assumption" filter.

## Recommended Starting Subtask

The natural starting point depends on whether the user wants to
prioritize Lean-side mechanization (W5.5) or external-provenance
narrative (W5.1 / W5.4 / W5.3 in some order). The recommended
sequence:

**W5.5 first (store/codec semantic alignment).** This is the most
procedurally similar to the WP4 work landed by the previous agent:
a Lean-side refinement task that pins the `RuntimeStoreCodecSemantics`
abstract codec to the Rust `StoreCipher` surface in
`runtime/uo-store/src/generated_surface.rs`. The codec semantic
files already carry 43 + 96 = 139 theorems; the remaining work is
to (a) audit which Rust surface obligations are not yet covered
and (b) close the gaps. This work doesn't need any external
provenance decision and can be driven in pure auto-continue mode.

**W5.4 second (cryptographic-assumption provenance).** The runtime's
concrete crypto is RFC 8439 ChaCha20-Poly1305 (32-byte keys, 12-byte
nonces, 16-byte tags), implemented via the
`chacha20poly1305::ChaCha20Poly1305` crate. The provenance work:

- Pair `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA`
  with explicit citations (Procter "A Security Analysis of the
  Composition of ChaCha20 and Poly1305," RFC 8439, the IRTF CFRG
  AEAD-security analyses).
- Add a static-drift check that the Rust crypto surface still
  uses ChaCha20Poly1305 (a probe-side `crypto-primitive-validation`
  scenario that grep-checks the imports / type names).
- Add a Lean-side `PathOramLocalPosmapV1SecurityAssumptions.cryptoProvenance`
  field carrying the citation marker.

This work needs a small policy decision (which citations to pin)
but no research-scope decision.

**W5.3 third (`stashOverflowBounded` for deployed parameters).**
The `stashOverflowBounded` field is currently a `Prop` taken
on faith. The deployed-parameter discharge requires either:

- A Lean-side computation against the JACM-2018 stash bound at the
  deployed `Z = 5` / fixed stash size, or
- A direct citation of the JACM stash analysis with the deployed
  parameters substituted.

This is roughly W5.4-style work but requires more concrete
parameter handling.

**W5.1 / W5.2 last (import vs companion mechanization).** The
`docs/stronger-import-route-feasibility.md` verdict is that no
existing external mechanization cleanly matches
`PaperMainPathOramTheoremSourceAt` today. The user-side decision
is whether to:

- Stay on the citation route (the current state, with JACM as
  the cited source);
- Build a companion mechanization project (a real research-scope
  effort separate from this repo);
- Wait for an external artifact to mature (FM 2024
  Isabelle/HOL trajectory).

This decision belongs to the user. The handoff prompt should
flag this as a policy fork rather than auto-continuing through it.

**W5.6 (housekeeping).** As each assumption is discharged or
provenance-justified, audit the bundle for residual fields that
exist only because of convenience engineering. The exit-gate
criterion is "every remaining assumption is concrete, justified,
and unavoidable."

## Validation Slice

Doc-only edits run `git diff --check` only. For Lean / Rust / probe
edits, run the standard slice from
[`coding-agent-conventions.md`](./coding-agent-conventions.md#validation-slice-protocol),
plus the WP5-relevant scenarios:

```bash
cd <repo-root>
cargo fmt --all
cd proof/lean
lake build UOToolchain.PathOramLocalPosmapV1 \
  UOToolchain.PathOramLocalPosmapV1Refinement \
  UOToolchain.PathOramLocalPosmapV1StandardTheorem \
  UOToolchain.PathOramJACMTheorem \
  UOToolchain.PaperPathOramTheoremRoute \
  UOToolchain.RuntimePaperInstantiation \
  UOToolchain.RuntimeStoreCodecSemantics \
  UOToolchain.RuntimeOramCodecSemantics \
  UOToolchain.RuntimeStoreHelperSemantics \
  UOToolchain.RuntimeOramHelperSemantics \
  UOToolchain.ProofGrade
cd ../..
cargo check -p mplus-probe
cargo check -p uo-store -p uo-evm
cargo run -q -p mplus-probe -- --only static-checks --out-dir results \
  > /tmp/uo-static-checks.json
git diff --check
```

For larger checkpoints (new boundary cuts, new tamper scenarios,
new probe scenarios), run `scripts/run_validation.sh` to exercise
the full suite.

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

## What WP5 Must NOT Do

- Do not regress WP3 or WP4. The runtime residual-helper-shell
  route, the direct kernel-machine-confinement route, and the
  W4.2 + W4.4 + W4.5 + W4.6 chain must continue to be Lean-
  proved. WP5 work happens at the *backend assumption* layer and
  must consume the WP4 `proofGrade_*` facades unchanged.
- Do not weaken the existing `PathOramLocalPosmapV1SecurityAssumptions`
  bundle by removing fields that are still load-bearing for the
  paper theorem. WP5 *removes* a field only when a Lean proof
  discharges it; otherwise the field stays explicit (paired with
  provenance).
- Do not add a new Lean axiom outside the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` (or a successor)
  bundle. The bundle is the only place where backend-side `Prop`
  axioms are allowed; everything else must be Lean-proved or
  source-pinned.
- Do not promote source-freeze checks to "proved." A static-drift
  check on the Rust crypto surface (e.g., "the runtime still uses
  ChaCha20Poly1305") is a source-freeze check, not a discharge of
  the cryptographic assumption. The cryptographic assumption stays
  in the bundle even with the drift check; the drift check pins
  the *target* of the assumption, not the assumption itself.
- Do not add a probe report bit unless the underlying claim is
  either (a) a Lean theorem in the WP5 surface or (b) a static-
  drift check against the Rust crypto surface.

## Repository Conventions Cross-Reference

The following sections of
[`coding-agent-conventions.md`](./coding-agent-conventions.md) apply
to WP5 directly:

- **Scientifically-Strongest-Route Preference** — applies to the
  W5.1 / W5.2 import-vs-companion fork. Prefer machine-checked
  imports over citations; prefer companion mechanizations over
  trusted external artifacts.
- **Claim And TCB Discipline** — applied above. Read it again
  before writing the WP5 status paragraph or annotating an
  assumption with a provenance citation.
- **Working Practices For Coding Agents** — auto-continue, small
  commits, patch-style edits, preserve unrelated dirty files,
  lint warnings are not blockers, terminal hygiene, write a
  handoff before stopping.

## Suggested Per-Checkpoint Commit Cadence

The user has authorized checkpointing during implementation work
(see *Working Practices For Coding Agents* and the WP3 / W4.x
session logs). Each coherent technical step that passes the
validation slice should be its own commit:

- W5.5 — store/codec semantic alignment, per Rust surface
  obligation (one commit per gap closed).
- W5.4 — cryptographic-assumption provenance (one commit for the
  citation pinning, one commit for the static-drift check, one
  commit for the Lean-side provenance field).
- W5.3 — `stashOverflowBounded` discharge for deployed
  parameters (one commit for the parameter substitution, one
  commit for the Lean-side discharge, one commit for the
  paper-facing facade).
- W5.1 / W5.2 — import-vs-companion decision needs user input
  before any commits land.
- W5.6 — assumption-bundle housekeeping (one commit per residual
  field removed or provenance-justified).

For each landed checkpoint, update the WP5 status paragraph in
`docs/top-tier-paper-execution-roadmap.md` (Work Package 5
section) and `docs/paper-theorem-profile.md` (assumption table).
The commit message should explain *which assumption was
discharged or annotated* and *what provenance route the
remaining assumptions follow*.

## Known Risks And Pitfalls

- **Conflating discharge with provenance.** Discharging an
  assumption means proving it in Lean from already-trusted facts;
  providing provenance means pairing the assumption with an
  explicit external citation. Both are valid WP5 outcomes, but
  they are different. Don't mark an assumption as "discharged"
  when it is only "provenance-justified."
- **Citation drift.** External citations need to remain valid as
  the runtime evolves. If the runtime switches AEAD primitives
  (e.g., from ChaCha20Poly1305 to AES-256-GCM), the W5.4
  citations become stale. The static-drift check on the Rust
  crypto surface is what catches this.
- **Stash-bound parameter substitution.** The JACM stash bound is
  asymptotic; deployed parameters require concrete substitution.
  Be careful about whether the substituted bound is tight enough
  for the deployed memory budget.
- **Companion-mechanization scope creep.** If the user decides
  to pursue W5.1 (machine-checked import) by building a companion
  mechanization, scope it carefully — that is a separate research
  project, not an in-repo task. The handoff should make this
  decision explicit.
- **Lean axiom discipline.** The
  `PathOramLocalPosmapV1SecurityAssumptions` bundle is the only
  place backend `Prop` axioms are allowed. Adding a new axiom
  outside the bundle (even a small one) is a regression of the
  conventions' "minimize unjustified assumptions" rule.

## Where The Handoff Stops

This runbook hands off to subtask **W5.5** (or another WP5
subtask if the user prefers to sequence the deliverables
strictly) with:

- Clean main branch with WP4 fully closed (all six charter tasks
  Lean-proved, last commit `7e50d42`).
- All validation gates green at the standard WP4 / WP5
  validation slice (probe exit codes 0; `"accepted": true` on
  all non-static probe reports; static-checks restriction flags
  all `true`; full `lake build` 407/407; `git diff --check` clean).
- The companion handoff prompt
  [`wp5-handoff-prompt.md`](./wp5-handoff-prompt.md) ready to be
  pasted into a fresh coding-agent session.

When the next agent finishes a checkpoint, they update:

- The WP5 status paragraph in `docs/top-tier-paper-execution-roadmap.md`
  (Work Package 5 section).
- The assumption table in `docs/paper-theorem-profile.md` (around
  the `PathOramLocalPosmapV1SecurityAssumptions` rows).
- This runbook's "Suggested Per-Checkpoint Commit Cadence"
  section, recording the landed commit hashes.

When WP5 closes, replace these handoff packages with WP6 / WP7
handoff packages following the same structure.
