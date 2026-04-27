# WP5 Handoff Prompt

Paste the block below into a fresh coding-agent session
(Claude Opus 4.7 with maximum reasoning, plan mode off, auto-continue
on) to resume Work Package 5. The prompt is self-contained: it sets
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

You are now picking up **Work Package 5: Discharge The Concrete
Backend Assumptions**. Work Packages 0–4 are closed. **All six WP4
charter tasks (W4.1–W4.6) are now Lean-proved end-to-end** (last
commit `7e50d42`):

- W4.1: real operational evaluator over the structured admitted IR,
  total over the W4.3 fragment, with masked-store updates.
- W4.2: full admitted post-resolution Sol AST + AST→IR lowering +
  per-Expr / per-Statement / Body / Function preservation theorems.
- W4.3: count-based confidential-fragment witness ↔ structural
  fragment-validity iff theorem.
- W4.4: typed kernel DSL + B-1 forward iff (all four levels) + B-2
  semantics-preservation (all four levels) + reverse iff (all four
  levels). The
  `proofGrade_ir_to_kernel_lower_compiled_function_iff_kernel_lowerable`
  facade exposes the full lowering biconditional.
- W4.5: enabling theorem `proofGrade_sol_to_kernel_outcome_preservation`
  composes W4.2 + W4.4; main-body static projections plus body /
  program-level runtime-vs-static `kernelSteps` lift land the
  manifest-exactness chain on the happy path.
- W4.6: `proofGrade_compiler_correctness_supersedes_artifact_checker`
  bundles W4.2 + W4.4 + W4.5 into a single named statement that
  supersedes the direct artifact checker as the trust root.

The full source-to-manifest correctness chain on the happy path is
now Lean-proved: `Sol.evalFunction fn cfg` = `IR.evalContract cfg` =
`IR.evalKernelProgram kp cfg`, with runtime `kernelSteps` matching
`kp.expectedKernelSteps` matching the manifest's `kernel_steps`
field. The W4.4 forward + reverse iff equivalence pins admission
precisely.

WP5 charter tasks **1, 2, 3, 4, 5, 6** are all open. Per the
roadmap, the current explicit backend assumption bundle is

```
structure PathOramLocalPosmapV1SecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  stashOverflowBounded : Prop
```

(in `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`). The WP5
goal is to shrink this bundle until only genuinely external
cryptographic and deployment assumptions remain, by either (a)
discharging an assumption with a Lean proof, (b) pairing it with
an explicit external provenance citation, or (c) replacing the
ambient citation route with a machine-checked external import.

## First, Read These Files In This Exact Order

1. `docs/wp5-handoff-runbook.md` — your charter for this work
   package, the existing infrastructure, the assumption bundle,
   and the recommended starting subtask. This is the document
   that tells you *what to do*.
2. `docs/coding-agent-conventions.md` — the engineering process
   for this repository. This is the document that tells you *how
   to do it*. Pay special attention to:
   - "Scientifically-Strongest-Route Preference"
   - "Claim And TCB Discipline"
   - "Validation-Slice Protocol"
   - "Working Practices For Coding Agents"
   - "Common Pitfalls"
3. `docs/top-tier-paper-execution-roadmap.md` — the work-package
   narrative; section "Work Package 5" is your charter.
4. `docs/paper-theorem-profile.md` — the theorem profile, TCB
   table, "What is still open" list. The
   `PathOramLocalPosmapV1SecurityAssumptions` rows in the
   assumption table are your starting state.
5. `docs/path-oram-citation-import-plan.md` — the current
   citation-route plan for the Path ORAM theorem (JACM 2018 as
   primary, CCS 2013 as fallback).
6. `docs/stronger-import-route-feasibility.md` — the assessment
   of whether a machine-checked external import is currently
   crisp and complete (verdict: not yet).
7. `docs/formal-proof-plan.md` — the broader proof structure;
   section 6 enumerates remaining gaps including the WP5 ones.

Then read the WP5-relevant Lean and Rust files listed in the
runbook. Pay special attention to:

- `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean` — the
  explicit `PathOramLocalPosmapV1SecurityAssumptions` bundle and
  the `pathOramLocalPosmapV1_*` theorem family that lifts a
  discharged bundle through to the paper-facing TEE-storage / SGX
  / paper-main routes.
- `proof/lean/UOToolchain/PathOramJACMTheorem.lean` — the JACM
  literature theorem packaged at the standard-storage interface.
- `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean` — the
  paper-main theorem route and the
  `PaperMainPathOramTheoremSourceAt` interface (the frozen
  imported-theorem target).
- `proof/lean/UOToolchain/RuntimeStoreCodecSemantics.lean`
  (~821 lines, 43 theorems) — Lean model of the store codec
  layer; pins `sealedNonceBytes = 12` and `sealedTagBytes = 16`
  matching the Rust ChaCha20Poly1305 nonce / tag sizes.
- `proof/lean/UOToolchain/RuntimeOramCodecSemantics.lean`
  (96 theorems) — Lean model of the ORAM codec layer.
- `runtime/uo-store/src/generated_surface.rs` — the actual
  `StoreCipher` over `chacha20poly1305::ChaCha20Poly1305` (RFC 8439
  ChaCha20-Poly1305 AEAD, 32-byte keys, 12-byte nonces, 16-byte
  tags). **This is the concrete cryptographic scheme that
  `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` are
  claims about.**
- `runtime/uo-store/src/codec.rs` and `store.rs` — store
  front-end consumed by `uo-evm`.
- `runtime/uo-evm/src/oram.rs` — Path-ORAM access pattern over
  the sealed store.

## Operating Posture

- **Auto-continue.** Do not pause for confirmation when the next
  technical step is clear. Stop only if a human policy or design
  decision is genuinely required (e.g., the W5.1 / W5.2
  import-vs-companion fork), or if validation has failed in a way
  that needs human input to triage.
- **Small commits.** Each coherent technical step that passes the
  validation slice is its own commit. The commit message documents
  *which assumption was discharged or annotated* and *what
  provenance route the remaining assumptions follow*. Do not
  amend prior commits.
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
  slice; the WP5 runbook has the WP5-augmented slice.
- **Preserve unrelated dirty files.** Do not run `git checkout .`,
  `git restore .`, or any destructive git command without
  confirming with the user.
- **Lean lint warnings are not blockers.** Build failures,
  missing probe bits, and `git diff --check` failures are
  blockers; lint noise is not.

## Scope Discipline

WP5 lives at the **backend assumption layer**. The compiler-side
work closed in WP4 and must stay green. The runtime kernel /
shell-boundary work closed in WP3 and must stay green. WP5
modifies the explicit `PathOramLocalPosmapV1SecurityAssumptions`
bundle and its provenance, plus the `RuntimeStoreCodecSemantics` /
`RuntimeOramCodecSemantics` codec-alignment layer. WP5 theorems
land in:

- `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`
- `proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean`
- `proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`
- `proof/lean/UOToolchain/PathOramJACMTheorem.lean`
- `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`
- `proof/lean/UOToolchain/RuntimePaperInstantiation.lean`
- `proof/lean/UOToolchain/RuntimeStoreCodecSemantics.lean`
- `proof/lean/UOToolchain/RuntimeOramCodecSemantics.lean`
- `proof/lean/UOToolchain/RuntimeStoreHelperSemantics.lean`
- `proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean`
- `proof/lean/UOToolchain/ProofGrade.lean` (paper-facing facades)
- and as needed `docs/path-oram-citation-import-plan.md` /
  `docs/stronger-import-route-feasibility.md` for provenance
  doc updates.

If your edits would change the W4 `Sol` / `KernelDsl` /
`IRSemantics` / `ProofGrade` compiler-side surface beyond exposing
new WP5 facades, stop and reconsider — that is WP4 territory and
WP4 is closed.

## Recommended Next Subtask

The natural starting point is **W5.5: store/codec semantic
alignment** — the most procedurally similar to the just-landed
WP4 work. The codec semantic files
(`RuntimeStoreCodecSemantics.lean`, `RuntimeOramCodecSemantics.lean`)
already carry 43 + 96 = 139 theorems pinning the abstract codec
shape to the Rust surface. The remaining W5.5 work:

1. Audit the Rust `StoreCipher` surface in
   `runtime/uo-store/src/generated_surface.rs` for any obligations
   not yet covered by the existing Lean codec semantics (length
   bounds, AAD shape, nonce / tag size constants, sealed-encoded
   length, etc.).
2. For each gap, add a Lean theorem in the appropriate codec-
   semantics file pinning the Rust surface obligation.
3. Expose each new theorem through `ProofGrade.lean` as a
   paper-facing `proofGrade_runtime_store_codec_*` facade if it
   strengthens a paper-facing claim.

After W5.5 lands, the next subtasks in recommended order:

- **W5.4**: cryptographic-assumption provenance. Pair
  `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` with
  explicit citations (RFC 8439, Procter "A Security Analysis of
  the Composition of ChaCha20 and Poly1305," IRTF CFRG
  AEAD-security analyses). Add a static-drift check that the
  Rust crypto surface still uses ChaCha20Poly1305. Add a
  Lean-side `cryptoProvenance` field in the assumptions bundle
  carrying the citation marker.
- **W5.3**: discharge `stashOverflowBounded` for the deployed
  parameter regime. The JACM stash analysis at `Z = 5` and the
  deployed stash size needs concrete parameter substitution and
  either a Lean-side computation against the bound or a direct
  citation with substituted parameters.
- **W5.1 / W5.2**: import-vs-companion mechanization. This is a
  research-scope policy fork — present the options to the user
  rather than auto-continuing through it.
- **W5.6**: bundle housekeeping. As each assumption is
  discharged or provenance-justified, audit the bundle for
  residual fields that exist only because of convenience
  engineering.

## Validation Slice (Standard WP5 Variant)

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

For larger checkpoints (new probe scenarios, new Cargo dependencies,
schema changes), run the full Validation Gates set
(`scripts/run_validation.sh`).

## Claim Discipline

When updating the roadmap status text or the paper theorem profile,
classify each WP5 claim explicitly:

- **Lean-proved, semantics-preserving** — the W5.5 store/codec
  alignment work; new theorems in
  `RuntimeStoreCodecSemantics.lean` /
  `RuntimeOramCodecSemantics.lean`.
- **Lean-proved, exactness/export** — the
  `pathOramLocalPosmapV1_artifactAppendixTheoremSource`-style
  construction that delivers `PaperMainPathOramTheoremSourceAt`
  from the JACM theorem object plus explicit assumptions.
- **Cited / externally justified** — the `bucketEncryptionINDCPA`
  / `metadataEncryptionINDCPA` route after W5.4 lands. The
  assumption stays explicit in Lean but is paired with an
  explicit provenance citation plus a Lean drift check that the
  Rust crypto surface still matches the cited primitive.
- **Trusted external assumption (irreducible)** — the final
  bundle after WP5 closes. Each surviving assumption must have
  an explicit provenance entry; nothing remains as "convenience
  engineering."

Never write "WP5 discharges the backend assumption bundle" unless
every surviving assumption has either (a) been removed from the
bundle by a Lean proof, or (b) been paired with an explicit
provenance entry that survives the conventions' "trusted external
assumption" filter.

## When To Stop

Stop and write an updated handoff (replacing
`docs/wp5-handoff-runbook.md` and `docs/wp5-handoff-prompt.md`,
following the same content discipline) when any of:

- Context limits force a session boundary.
- A genuine human policy or design decision is needed (e.g., the
  W5.1 / W5.2 import-vs-companion fork; or which crypto-security
  citation to pin in W5.4).
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

- Do not regress WP3 or WP4. The runtime residual-helper-shell
  route, the direct kernel-machine-confinement route, and the
  W4.2 + W4.4 + W4.5 + W4.6 chain stay green.
- Do not weaken the existing `PathOramLocalPosmapV1SecurityAssumptions`
  bundle by removing fields that are still load-bearing for the
  paper theorem. Remove a field only when a Lean proof discharges
  it.
- Do not add a new Lean axiom outside the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` (or a successor)
  bundle. The bundle is the only place backend `Prop` axioms are
  allowed.
- Do not promote a static-drift check to "proved." A drift check
  pins the *target* of the assumption, not the assumption itself.
- Do not add a probe report bit unless the underlying claim is
  either (a) a Lean theorem in the WP5 surface or (b) a static-
  drift check against the Rust crypto surface.

Begin with the runbook. The recommended next subtask is **W5.5**
(store/codec semantic alignment). After W5.5, sequence W5.4
(crypto provenance), then W5.3 (`stashOverflowBounded` deployed-
parameter discharge), then W5.1 / W5.2 (import-vs-companion
fork; needs user input), then W5.6 (housekeeping).
