# Finding Inventory and Required Remediation

Review date: 2026-04-29

This document groups and de-duplicates the non-usability findings from the
independent review bundle in `review/`. It records our response to each finding
and the required fix. Phase order controls only sequencing. Every finding marked
`Agreed` in this inventory is required to land before the review is considered
closed.

Documents examined:

- `review/review_report.md`
- `review/executive_summary.md`
- `review/issue_register.csv`
- `review/theorem_gap_register.csv`
- `review/action_plan.md`
- `review/negative_test_sketches.md`
- `review/theorem_inventory.csv`
- `review/theorem_inventory_summary.csv`

`theorem_inventory*.csv` are treated as evidence and theorem-surface context,
not as independent findings.

## Mandatory Landing Policy

- All agreed findings below are required fixes.
- A later phase is not an optional phase. It is only the planned order of work.
- No item may be closed with documentation-only mitigation unless the required
  fix below explicitly says the durable fix is a claim-boundary change.
- Review closure requires all entries to move from `Open` to `Landed` with the
  stated acceptance gate satisfied.
- `TB-11` is excluded from the inventory because it is review-artifact hygiene
  and falls under the requested exclusion of usability improvements.

## Summary

| ID | Group | Sources | Response | Phase | Status |
| --- | --- | --- | --- | --- | --- |
| F-01 | Public entrypoint observer leak | TB-01, TH-01, negative tests 1-2 | Agree | P0 | Landed |
| F-02 | Strict sidecar parse/hash boundary | TB-02, negative test 4 | Agree | P0 | Landed |
| F-03 | Full `(P, M, V)` identity binding | TB-03, TH-08, practical blocker 6 | Agree | P0 | Landed |
| F-04 | Abort/rollback theorem | TB-04, TH-04, negative test 3 | Agree | P0 | Landed |
| F-05 | Exact declassification framing | TB-05, TH-05, negative test 5 | Agree | P0 | Landed |
| F-06 | Proof-relevant observer coverage | TB-06, TH-06 | Agree | P0 | Landed |
| F-07 | Freshness and randomness discipline | TB-07 | Agree | P1 | Landed |
| F-08 | Theorem-adjacent unsafe Rust | TB-08 | Agree | P1 | Landed |
| F-09 | Path ORAM capacity cap mirrored in Lean | TB-09, TH-09 | Agree | P1 | Landed |
| F-10 | Smaller metadata canonicality gaps | TB-10, negative tests 5-6 | Agree | P1 | Landed |
| F-11 | Direct paper-main noninterference theorem | TH-02 | Agree | P1 | Open - required |
| F-12 | Adaptive history theorem | TH-03 | Agree | P1 | Open - required |
| F-13 | Solidity dialect theorem or boundary | TH-07, practical blocker 5 | Agree | P2 | Open - required |
| F-14 | Environment/auth model | practical blocker 4 | Agree | P2 | Open - required |
| F-15 | Capacity/evidence scaling | practical blocker 2, action plan P3 | Agree | P3 | Open - required |
| F-16 | Deployment theorem and runtime acceptance | practical blocker 3, practical blocker 6 | Agree | P3 | Open - required |

No non-usability findings are rejected.

## P0 Claim-Safety Findings

### F-01 - Public EntryPoint Observer Leak

Grouped finding:
Public entrypoints can read confidential state and then perform
secret-dependent work that changes modeled gas, storage trace, object schedule,
boundary/proof traces, or opcode/kernel traces without being caught as a
return/status/public-state leak.

Sources:
`TB-01`, `TH-01`, negative tests 1 and 2.

Response:
Agree. This is the highest-priority soundness issue. The current policy
sensitivity analysis tracks sensitive return values, sensitive status, and
sensitive writes to public state, but it does not fail closed on every
observer-relevant effect of reading confidential state from a non-confidential
entrypoint.

Required fix:
Non-confidential entrypoints must be forbidden from reading confidential state.
Entry points that need confidential reads must be compiled as confidential and
use the linearized confidential-kernel path. The current requirement that
`confidential: true` always has at least one `secret_args` entry must be relaxed
so a confidential entrypoint may have no secret arguments but still touch
confidential state.

Acceptance gate:
Add compiler negative tests for public confidential reads with no return/write,
secret-dependent public reads, secret-dependent public writes, and
secret-dependent status. Add a Lean-mirrored admission predicate proving accepted
public entrypoints have observer traces determined only by public inputs and
declared releases.

Status:
Landed.

Landing notes:
Admitted package identity is now schema `uo-admitted-package-v3` and includes
`toolchain_manifest_sha256`. The manifest digest is generated from build-time
hashes covering the Rust toolchain file, `Cargo.lock`, workspace/crate
manifests, the pinned parser version, Lean toolchain, `ProofGradeRoot` and Lean
import set, generated-code surfaces, runtime model source, and deployment/SGX
binding model source/tags. The checker rejects missing/stale identities,
schema drift, toolchain digest drift, package-hash drift, and source/artifact
admitted-package mismatch. Bench artifacts were regenerated with v3 identities.

### F-02 - Strict Sidecar Parse/Hash Boundary

Grouped finding:
Sidecar metadata structs do not reject unknown fields, and the
admitted-package hash is computed over parsed canonical metadata rather than the
raw sidecar bytes.

Sources:
`TB-02`, negative test 4.

Response:
Agree. Silent unknown fields can hide misspelled or stale policy and can leave
two different sidecars with the same admitted-package metadata hash.

Required fix:
Add `#[serde(deny_unknown_fields)]` to sidecar metadata structs and relevant
runtime/proof JSON inputs where strictness is part of admission. Add
`raw_metadata_sha256` to `AdmittedPackageIdentityV2`, while continuing to hash
the normalized policy for stable equality.

Acceptance gate:
Unknown top-level, state, entrypoint, and bounds fields must fail tests. The
same parsed policy with different raw sidecar bytes must produce distinct raw
sidecar hashes, and admitted-package v2 equality must check the raw digest.

Status:
Landed.

### F-03 - Full `(P, M, V)` Identity Binding

Grouped finding:
The claim boundary defines admitted packages as `(P, M, V)`, but the current
package identity binds source, parsed metadata, compilation mode, compiler
version, and schema only. It omits the proof/runtime model and deployment
version tuple.

Sources:
`TB-03`, `TH-08`, practical blocker 6.

Response:
Agree. The current hash is useful for source/artifact equality, but it is not
strong enough to identify the proof/runtime/deployment model that the theorem
quantifies over.

Required fix:
Introduce `AdmittedPackageIdentityV2` with `toolchain_manifest_sha256`. The
toolchain manifest must cover the Rust toolchain, `Cargo.lock`, parser crate
version, `uo-core` and runtime versions, generated code hashes, Lean toolchain,
`ProofGradeRoot` plus its import set, proof checker schema, runtime model tags,
and deployment/attestation binding inputs.

Acceptance gate:
Compiler/checker artifacts must carry and compare the same toolchain manifest
digest. Tampering any covered version, generated file hash, proof root/import,
or runtime model tag must fail validation. Deployment must bind the digest into
the SGX quote/session transcript.

Status:
Landed.

### F-04 - Abort/Rollback Theorem

Grouped finding:
The source/IR theorem surface includes final public state, and the runtime
rolls back writes on abort, but there is no pinned theorem proving that the
source/IR and runtime agree on commit/rollback behavior.

Sources:
`TB-04`, `TH-04`, negative test 3.

Response:
Agree. The inspected Lean evaluator threads `cfg'.publicState` through abort,
which risks a prefix-commit semantics if not corrected or explicitly refined.
The runtime tests indicate rollback-on-abort is the intended behavior.

Required fix:
Adopt rollback-on-abort as the semantic contract. Extend source/IR/runtime
surfaces with initial public state, candidate public state, committed public
state, public delta, and abort status. Prove that an aborted call commits the
initial public state and that source/IR/runtime traces agree on final public
state.

Acceptance gate:
Add tests where a public write is followed by `require(false)` or `abortIf`.
The Rust runtime, compiler IR, Lean evaluator, and proof-grade checker must all
agree that the committed public state equals the initial public state.

Status:
Landed.

Landing notes:
Source, IR, kernel, and runtime traces now carry a public-state transition with
initial, candidate, committed, delta, and abort-status fields. Lean
`evalContract`, Sol evaluation, and kernel evaluation use rollback-on-abort:
non-completed calls commit the initial public state, with dedicated theorems
for `requireFailed` and `abortedByUser`. Runtime public calls hash the initial,
candidate, and committed public states, include the transition in primitive and
proof-object transcripts, and stop executing after `abortIf`. A runtime test
checks a public write followed by `require(false)` rolls back the committed
state. Proof-grade Lean root and regenerated benchmark artifact validation pass
against the updated manifest digest.

### F-05 - Exact Declassification Framing

Grouped finding:
Declassification is currently mostly label- and whole-object-based. The checker
requires some labels to be present but does not enforce exact/minimal release,
structured public-state release, or all duplicate/extraneous label cases.

Sources:
`TB-05`, `TH-05`, negative test 5.

Response:
Agree. Whole-object public-state declassification and unused labels make the
least-release claim too coarse and increase audit ambiguity.

Required fix:
Define declassification as explicit release functions for return value, success
bit, and public-state key/delta/expression. Reject duplicate `secret_args`,
duplicate `declassifies`, duplicate public-state releases, and unused or
extraneous release labels by default. Hash the normalized policy into
admitted-package identity.

Acceptance gate:
Tests must reject duplicate secret args, duplicate declassification labels,
unused `declassifies: [success]`, plaintext return declassification drift, and
public-state releases wider than the declared release function. Lean must prove
relational noninterference modulo exactly these release functions.

Status:
Landed.

Landing notes:
Declassification labels are now exact: `return` is allowed only for
`returns: declassified`, `success` only for `status: declassified`, and unused
or missing labels fail compiler and checker validation. Declassified plaintext
returns must be confidential or return-sensitive; declassified status must be
status-sensitive. Public-state releases must exactly match the sensitive public
write target set, so unused or broader `public_state_declassifies` entries are
rejected. The proof-relevant Lean import predicate mirrors exact return,
status, and public-state release checks. Added compiler and checker tests for
duplicate labels, unused `success`, plaintext return policy drift, and
public-state release drift; regenerated and validated benchmark artifacts.

### F-06 - Proof-Relevant Observer Coverage

Grouped finding:
The proof-relevant translation view has exact-field checks for its curated
view, but there is no generated proof that every runtime field influencing the
observer is included, classified, or explicitly out of claim.

Sources:
`TB-06`, `TH-06`.

Response:
Agree. Exactness of a curated view is necessary but not sufficient. A new
observer-affecting runtime field could be missed by the proof view.

Required fix:
Generate a proof-relevance coverage table from runtime observer, manifest,
trace, return-channel, and execution-trace schemas. Every field must be
classified as included in Lean, public input, declared release,
cryptographically hidden under a named assumption, normalized away, or outside
the claim with an explicit non-claim.

Acceptance gate:
Mutation tests must fail when a new observer-affecting field is added to
`RuntimeManifest`, `PublicOutcomeTrace`, `ExecutionTrace`, return-channel
evidence, or runtime observer certificates without adding coverage and Lean
mirror evidence.

Status:
Landed.

Landing notes:
Added a Rust observer coverage table for the runtime manifest, public outcome,
return-channel AAD and ciphertext evidence, controller observer certificates,
hidden ORAM certificates, theorem traces, trace hashes, primitive events,
public-state transitions, and the full `ExecutionTrace` schema. The coverage
table classifies fields as Lean-included, public input, exact declared release,
or cryptographically hidden under the named AEAD/freshness/ORAM assumptions.
Added source-structure mutation gates that parse the Rust struct definitions in
`uo-core` and `uo-evm`, so adding an observer-affecting field to the covered
schemas fails unless the coverage table is updated. Added a Lean
`ObserverCoverage` mirror and imported it into the proof-grade root; Rust tests
also require every Rust coverage key to appear in the Lean mirror.

## P1 Runtime And Proof Hardening

### F-07 - Freshness And Randomness Discipline

Grouped finding:
Freshness is documented and audited, but production nonce/coin uniqueness and
crash/rollback interactions are still assumption-heavy rather than fully
mechanized end to end.

Sources:
`TB-07`.

Response:
Agree. ORAM and AEAD arguments depend on freshness. Runtime randomness and
diagnostic coin injection need an operationally checkable production boundary.

Required fix:
Replace ad hoc production randomness for ORAM leaves, AEAD nonces, and related
coins with domain-separated derivation from attested sealed counters covering
epoch, call, object, and access domains. Model counter monotonicity,
crash recovery, and rollback resistance in Lean. Feature-gate diagnostic seed
injection out of production artifacts.

Acceptance gate:
Production builds must reject diagnostic seed injection. Tests must cover nonce
domain separation, counter monotonicity, crash/restart handling, and rollback
counter mismatch. Lean must expose the counter/freshness preconditions consumed
by the ORAM/AEAD theorem route.

Status:
Landed.

Landing notes:
Added runtime freshness state with epoch, call, and rollback counters. Encrypted
return nonces now derive from epoch, rollback counter, call counter,
return-channel binding, and AAD hash rather than ad hoc `OsRng` sampling.
Runtime object seeds derive from the deployment epoch and object identity, and
Path ORAM production fresh leaves derive from object seed, object id, access
counter, and per-access coin counter. Diagnostic fresh-coin injection remains
behind `cfg(feature = "diagnostics")`, with source guards confirming production
code uses counter-derived leaves. Added tests for nonce domain separation,
counter monotonicity, crash/restart counter resumption, rollback-counter
mismatch rejection, ORAM leaf counter domain separation, and the production
source guard. Lean now exposes runtime freshness counter preconditions and the
freshness taxonomy includes return-channel nonces.

### F-08 - Theorem-Adjacent Unsafe Rust

Grouped finding:
Production `unsafe` Rust is isolated to fixed-buffer helpers, but the prefix
initialization, move, and drop invariants are still trusted below the checked
boundary.

Sources:
`TB-08`.

Response:
Agree. The blast radius is narrow, but it is theorem-adjacent and should not
remain an informal trust point.

Required fix:
Replace the helper with safe bounded containers where feasible. If any unsafe
code remains, minimize it, document its invariants locally, and verify it with
Miri plus property tests under sanitizers. Update the TCB table to reflect the
remaining or removed unsafe surface.

Acceptance gate:
No production `unsafe` remains in `fixed_buffer` unless accompanied by Miri and
property-test coverage in CI/probe evidence. Any remaining unsafe block must
have a specific invariant and a test that would fail if the invariant is
violated.

Status:
Landed.

### F-09 - Path ORAM Capacity Cap Mirrored In Lean

Grouped finding:
Rust enforces the current `path_oram_local_posmap_v1` capacity cap of 128, but
the inspected Lean imported ORAM shape predicate does not enforce the same cap.

Sources:
`TB-09`, `TH-09`.

Response:
Agree. If the cap is part of the proof-grade route, it must be visible in Lean
admission, not only Rust generation.

Required fix:
Add a Lean constant and imported-manifest field for the
`path_oram_local_posmap_v1` proof-grade maximum capacity. Make
`validateImportedOramShape` require `capacity <= 128` for the current route.
Keep documentation aligned with the Lean/Rust predicate.

Acceptance gate:
An imported proof view or manifest with `path_oram_local_posmap_v1` capacity
above 128 must fail Lean validation even if the Rust generator would not
normally emit it.

Status:
Landed.

### F-10 - Smaller Metadata Canonicality Gaps

Grouped finding:
Several metadata checks are lenient: non-ORAM state can carry `oram_scheme`,
array sidecar capacity is optional despite docs requiring map/array capacities,
and some duplicate policy entries are not rejected.

Sources:
`TB-10`, negative tests 5 and 6.

Response:
Agree. These gaps are not the main UO break, but they weaken fail-closed
admission and can misrepresent sidecar author intent.

Required fix:
Reject `oram_scheme` unless `backend: oram`. Require array capacity in sidecar
metadata and verify it equals the source fixed length. Fold duplicate policy
checks into policy normalization from F-05.

Acceptance gate:
Tests must reject non-ORAM `oram_scheme`, omitted array capacity, array
capacity mismatch, duplicate `secret_args`, duplicate `declassifies`, and
duplicate `public_state_declassifies`.

Status:
Landed.

### F-11 - Direct Paper-Main Noninterference Theorem

Grouped finding:
The paper-facing theorem should be stated directly as relational
noninterference over the complete normalized hostile-host observer rather than
requiring readers to reconstruct the final claim from bridge/interface
theorems.

Sources:
`TH-02`.

Response:
Agree. The existing theorem stack has many useful components, but the main
claim needs a direct public theorem shape.

Required fix:
Add `PaperMainTheorem.lean` exposing a theorem over two executions of the same
admitted package with equal public inputs/public initial state and equal
declared release functions. The conclusion must be equality of complete
`View_SGX` for exact backends and computational indistinguishability of the
Path ORAM storage component for `path_oram_local_posmap_v1`.

Acceptance gate:
`ProofGradeRoot.lean` imports the new theorem. The theorem statement must name
the complete observer components: public outcome, boundary schedule, storage
trace, micro trace, final public state/rollback behavior, and release
functions.

Status:
Open - required.

### F-12 - Adaptive History Theorem

Grouped finding:
The current adaptive-history surface proves transcript/schedule/final-state
projections equal when stepwise public equality is already assumed. It does not
derive that equality from a single-call theorem plus a public adaptive
strategy.

Sources:
`TH-03`.

Response:
Agree. The current theorem is a useful projection lemma but not the stronger
history noninterference theorem.

Required fix:
Prove an inductive adaptive-history theorem: if a strategy observes only the
host transcript, every next call is admitted, and the single-call UO theorem
holds modulo releases, then two runs with equal initial public state and equal
release history produce equal public transcripts, ordered object schedules,
and final public states.

Acceptance gate:
Lean must expose the inductive theorem and connect it to the paper-main theorem
route. Tests/checks must cover at least a two-call adaptive strategy where the
second public request depends on the first public observation.

Status:
Open - required.

## P2 Language And Environment Completeness

### F-13 - Solidity Dialect Boundary

Grouped finding:
The accepted source semantics diverge from Solidity 0.8 in important places,
including modulo `uint256` arithmetic and division/modulo-by-zero returning
zero. The claim should either name a Solidity-like DSL or prove a relation from
a selected Solidity semantics.

Sources:
`TH-07`, practical blocker 5.

Response:
Agree. Calling the language simply "Solidity" overstates the current semantic
bridge.

Required fix:
Land both parts in sequence. First, update claim/docs/artifact metadata to name
the source language as a restricted Solidity-like UO DSL until the bridge is
proved. Second, add a versioned Solidity semantics bridge if the toolchain is
to regain a "restricted Solidity subset" theorem claim. The bridge must cover
checked arithmetic, division/modulo-by-zero, ABI encoding, revert/rollback,
and context variables used by the supported subset.

Acceptance gate:
No claim document may present the current post-resolution language as full
Solidity semantics without the bridge. Once the bridge lands, Lean must state
the versioned relation and tests must cover semantic divergences.

Status:
Open - required.

### F-14 - Environment/Auth Model

Grouped finding:
The current subset lacks transaction/context variables such as `msg.sender`,
`block.*`, and `tx.*`, plus constructors, modifiers, events, and external
calls. That leaves practical authorization and integration to an external
trusted layer.

Sources:
Practical blocker 4 and action plan P3.

Response:
Agree as a practical and claim-boundary gap. Authorization is too important to
leave only as an informal wrapper when the toolchain is presented beyond toy
workflows.

Required fix:
Add a minimal public environment/auth model with caller or attested session
principal, chain/context fields that are explicitly public, and a one-time
initialization/setup phase. Prove these fields are public inputs and that
authorization decisions do not create secret-dependent observer effects unless
covered by explicit releases.

Acceptance gate:
Add compiler/runtime/Lean tests for caller-gated public setup, caller-gated
confidential entrypoints, unauthorized abort behavior, and initialization
state. The theorem surface must include the environment as public input.

Status:
Open - required.

## P3 Scaling And Deployment Completion

### F-15 - Capacity/Evidence Scaling

Grouped finding:
The current local position map, capacity cap, and enumerated proof families
make the toolchain realistic for small fixed-capacity prototypes but not for
larger account maps, order books, mixers, voting, or crowdfunding scenarios.

Sources:
Practical blocker 2 and action plan P3.

Response:
Agree. This is a scalability blocker for the broader toolchain, not a
cosmetic limitation.

Required fix:
Replace the local position map route with recursive or private position maps.
Replace enumerated proof families with compact symbolic certificates where the
proof route currently expands across large seed/family spaces.

Acceptance gate:
The proof-grade Path ORAM route must support capacities above the current 128
limit with private/recursive position metadata. Probe evidence must show
certificate size and validation time scale sub-enumeratively for representative
larger capacities.

Status:
Open - required.

### F-16 - Deployment Theorem And Runtime Acceptance

Grouped finding:
The runtime target is not raw deployed EVM bytecode, gas is modeled rather than
chain gas, and runtime attestation/proof acceptance are not unified. Production
users need a single acceptance path binding source, sidecar, proof root,
runtime binary, SGX quote, and return-channel session.

Sources:
Practical blockers 3 and 6, `TH-08`, `TB-03`.

Response:
Agree. This should be addressed as a deployment theorem and runtime acceptance
path, not by silently implying raw on-chain EVM compatibility.

Required fix:
Split the formal claims into a research theorem for the instrumented runtime
and a deployment theorem. The deployment theorem must require attestation,
runtime binary hash, proof-root hash, rollback/freshness counters,
session binding, and admitted-package v2 identity. Production runtime mode must
refuse unchecked or unattested artifacts.

Acceptance gate:
A production-mode runtime call must fail without a validated proof bundle,
matching toolchain manifest digest, accepted SGX quote/session transcript, and
freshness/rollback evidence. Claim docs must explicitly separate instrumented
runtime execution from raw EVM bytecode deployment.

Status:
Open - required.

## Excluded Finding

`TB-11` is excluded from the required finding inventory. It concerns stale
review artifacts and reviewer hygiene. It may still be useful to archive or
label historical reports, but it is outside this document because the requested
inventory excludes usability improvements.

## Required Test Matrix

The remediation work must add or update tests for:

- public entrypoint reads confidential state and branches without
  return/status/public write;
- public entrypoint conditionally reads public state based on confidential
  state;
- public entrypoint writes public state based on confidential state;
- write followed by abort/require failure;
- unknown sidecar fields at top, entrypoint, state, and bounds levels;
- duplicate or unused declassification and secret-argument labels;
- observer-affecting runtime schema fields without Rust coverage and Lean
  mirror entries;
- irrelevant `oram_scheme` on non-ORAM state;
- omitted or mismatched array capacity;
- Path ORAM capacity above 128 in imported Lean proof view;
- production diagnostic seed injection rejection;
- caller/session authorization and initialization semantics;
- deployment artifact rejection when attestation, proof root, runtime binary,
  or toolchain manifest binding is missing or mismatched.

## Closure Checklist

- [x] F-01 landed and tested.
- [x] F-02 landed and tested.
- [x] F-03 landed and tested.
- [x] F-04 landed and tested.
- [x] F-05 landed and tested.
- [x] F-06 landed and tested.
- [x] F-07 landed and tested.
- [x] F-08 landed and tested.
- [x] F-09 landed and tested.
- [x] F-10 landed and tested.
- [ ] F-11 landed and checked by Lean.
- [ ] F-12 landed and checked by Lean.
- [ ] F-13 landed and checked against claim wording/semantics tests.
- [ ] F-14 landed and checked by compiler/runtime/Lean tests.
- [ ] F-15 landed with scalable proof evidence.
- [ ] F-16 landed with production runtime acceptance tests.
