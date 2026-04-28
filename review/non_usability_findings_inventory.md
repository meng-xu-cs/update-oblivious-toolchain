# Non-usability findings inventory

This is a grouped and de-duplicated inventory of the third-party review findings in
`review/`, excluding pure usability, developer-experience, and performance roadmap
items. Practical items are retained only when they affect security, theorem
framing, proof auditability, reproducibility, or deployment trust assumptions.

Excluded as usability-only or performance-only: missing CLI calldata/ABI input,
Foundry/Hardhat integration, policy-report UX, contract migration tooling,
artifact caching for developer feedback, capacity-planning UX, ORAM overhead
reporting, and "drop-in Solidity tool" positioning.

## Summary

| ID | Priority | Group | Finding |
| --- | --- | --- | --- |
| F01 | P0 | Host-visible leakage | Return payloads are host-visible but omitted from the observer. |
| F02 | P0 | Host-visible leakage | Secret-dependent abort, success, termination, and commit/rollback status are public. |
| F03 | P1 | Host-visible leakage | Error and failure channels are not comprehensively normalized, modeled, or declassified. |
| F04 | P1 | Policy/admission | Public/declassification policy is not first-class, including public getters over confidential state. |
| F05 | P1 | Policy/admission | Missing sidecar entrypoint metadata is fail-open and defaults to public. |
| F06 | P0 | Semantics | Lean value semantics do not match runtime/Solidity arithmetic or real Keccak. |
| F07 | P1 | Front end | Semantic preprocessing is trusted outside the Lean source model. |
| F08 | P1 | Theorem shape | Real source/runtime semantic preservation is weak or claim-dependent. |
| F09 | P2 | Theorem shape | The current theorem framing is per-call, not sequential/adaptive-history based. |
| F10 | P1 | Theorem shape | Mixed-backend ordered object schedule leakage needs an explicit theorem. |
| F11 | P1 | Proof audit | Legacy axiom modules remain imported through the umbrella module. |
| F12 | P1 | Runtime boundary | Source-backed runtime checks are syntactic drift checks, not Rust semantic refinement. |
| F13 | P1 | Runtime boundary | Runtime witness/certificate extraction remains a trusted producer. |
| F14 | P2 | Runtime boundary | Public gas theorem does not imply real-cost or wall-clock obliviousness. |
| F15 | P2 | Implementation safety | Rust `unsafe` appears in theorem-adjacent production code. |
| F16 | P1 | Assumptions | Randomness, crypto nonce, and fresh-coin implementation discipline is not fully connected to the formal assumptions. |
| F17 | P1 | Assumptions | TEE deployment assumptions lack a concrete mapped implementation story. |
| F18 | P2 | Reproducibility | Lean toolchain is pinned to `stable`, not an exact release. |

## Detailed inventory and proposed fixes

### F01. Return payloads are host-visible but omitted from the observer

Source reports: `executive_findings.md`, `trust_boundaries.md` section 1,
`theorem_framing.md` missing theorem 1, `practicality.md` blocker 1,
`evidence_index.md`.

Evidence cited by review: `OutputShape` / `PublicOutcomeTrace` carry only
presence and length; Lean TEE/SGX public outcome also records shape only; the
runtime returns `Option<Value>`. `SingleAccessMap.read` is a concrete example of
a confidential read returning a value.

Best fix: make host-visible returns part of the security policy and theorem
surface. Add an explicit return policy per entrypoint:
`forbidden`, `public`, `declassified`, or `encrypted_to_client`. Include plaintext
public/declassified return payloads in `public_outcome`; for encrypted returns,
model ciphertext length plus an IND-CPA/freshness assumption for the return
channel. Reject confidential plaintext returns unless the policy and proof
witness justify them.

Initial tests: add a negative test using `SingleAccessMap.read` with equal public
projection but different hidden values and assert the current observer equality
is insufficient unless return policy catches it.

### F02. Secret-dependent abort, success, termination, and commit/rollback status are public

Source reports: `executive_findings.md`, `trust_boundaries.md` section 2,
`theorem_framing.md` missing theorem 2, `practicality.md` blocker 2,
`evaluation_plan_runbook.md` red-team test B.

Evidence cited by review: `termination_status` is part of public outcome; runtime
maps `!aborted` to public status; aborted calls clear return values; `require`
lowers to `abort_if`. Benchmarks include secret-dependent balance checks.

Best fix: choose one policy route and encode it consistently:
strictly reject secret-dependent termination, or require explicit
`declassifies: [success]`, or implement private failure semantics with fixed
public status and encrypted/private error details. The least disruptive route for
smart contracts is likely explicit success/status declassification, because
transfer/withdraw preconditions often intentionally reveal success.

Initial tests: add balance-present and balance-absent variants for
`ConfidentialMixer.withdraw` or `ERC20Lite.transfer`; compiler/checker should
reject without status declassification and accept only with declared leakage.

### F03. Error and failure channels are not comprehensively normalized, modeled, or declassified

Source reports: `theorem_framing.md` missing theorems 10 and 12,
`trust_boundaries.md` section 2, `evaluation_plan_runbook.md` acceptance gate.

Evidence cited by review: host-visible failure status and commit behavior are
public; possible failure sources include capacity overflow, stash overflow,
allocator failure, decode/serialization errors, checker errors, panics, and
`anyhow` error strings.

Best fix: define a single host-visible outcome model covering success, abort,
errors, checker failures, and commit/rollback. Require each failure class to be
public-determined, negligible under stated parameters, or explicitly
declassified. Normalize secret-dependent internal failures to fixed public
outcomes with private/encrypted details.

Initial tests: create capacity/stash/decode boundary cases and assert
host-visible errors do not include secret-dependent payloads or status variation
unless declared.

### F04. Public/declassification policy is not first-class

Source reports: `executive_findings.md`, `practicality.md` blockers 1 and 10,
`theorem_framing.md` missing theorem 5.

Evidence cited by review: public getters can return confidential state;
confidential entrypoints can return secret-dependent values; public outcome
omits return values; the current metadata does not make declassification a
proof-relevant object.

Best fix: add a policy language used by the compiler, artifact checker, runtime,
and Lean model. At minimum it should classify entrypoints, arguments, state
objects, return values, success/status bits, public getters, and error channels.
The proof statement should quantify over an explicit leakage/declassification
policy rather than leaving host-visible values implicit.

Initial tests: public getters over confidential state fail by default; they pass
only when a matching declassification clause states what value is released and in
what form.

### F05. Missing sidecar entrypoint metadata is fail-open

Source reports: `executive_findings.md`, `trust_boundaries.md` section 5,
`practicality.md` blocker 3, `evaluation_plan_runbook.md` red-team test E.

Evidence cited by review: `uo-solc` treats functions missing from metadata as
public entrypoints.

Best fix: fail closed. Require explicit metadata for every externally callable
function and every state object. A missing stanza should be a compiler error,
not a public default. Public entrypoints should also be explicitly declared
public so omission and intent are distinguishable.

Initial tests: mutate each sidecar by deleting one entrypoint stanza and expect
compiler rejection.

### F06. Lean value semantics do not match runtime/Solidity arithmetic or real Keccak

Source reports: `executive_findings.md`, `trust_boundaries.md` section 3,
`theorem_framing.md` missing theorem 4, `practicality.md` blockers 6 and 7,
`evaluation_plan_runbook.md` red-team tests C and D.

Evidence cited by review: Lean models `Value.uint` as `Nat`; unsigned negation is
a no-op; arithmetic is mathematical; div/mod-by-zero fail. Generated Rust uses
`u128` wrapping arithmetic and returns zero for div/mod-by-zero. Lean Keccak is a
zero mock; runtime uses real Keccak.

Best fix: decide the actual admitted value language, then make all layers match
it. For the current prototype, model `UInt128` wrapping arithmetic in Lean and
rename/docs the source type accordingly, or implement/prove Solidity-compatible
`uint256` semantics. Reject div/mod-by-zero at admission or make the semantics
match exactly. For Keccak, use an uninterpreted deterministic function plus a
runtime refinement/test-vector bridge, or specify enough of Keccak to prove
agreement on canonical bytes. Narrow any theorem that remains trace-only.

Initial tests: overflow, underflow, unary negation, div/mod-by-zero, and
Keccak-derived key examples comparing Lean and runtime behavior.

### F07. Semantic preprocessing is trusted outside the Lean source model

Source reports: `executive_findings.md`, `trust_boundaries.md` section 4,
`theorem_framing.md` main theorem-family notes.

Evidence cited by review: `Sol.lean` leaves state-name resolution, capacity
literal lookup, `abi.encodePacked` unwrapping, helper-function inlining, and
`AssignAdd` desugaring outside the Lean model.

Best fix: emit a proof-relevant preprocessing witness containing raw parsed AST,
post-resolution AST, and the semantic transformations. Mechanize a Lean relation
for resolution, helper inlining, `abi.encodePacked` lowering, and assignment
desugaring. Until then, state the accepted source language as the post-resolution
UO IR, not full Solidity source.

Initial tests: mutation tests for misresolved state objects, wrong capacity
literals, incorrect helper inlining, and mismatched hash packing.

### F08. Real source/runtime semantic preservation is weak or claim-dependent

Source reports: `theorem_framing.md` missing theorem 4,
`executive_findings.md` overall judgment, `trust_boundaries.md` sections 3, 4,
and 7.

Evidence cited by review: source-to-kernel theorems are over the Lean source
model; runtime value semantics and Rust execution are not fully refined from
that model; runtime implementation checks are source-string/interface checks.

Best fix: either narrow the claim to trace/certificate properties for accepted
artifacts, or prove a semantic preservation theorem from admitted source plus
policy to runtime public/declassified results and state transitions. The
pragmatic near-term fix is to reframe the paper theorem narrowly while adding
differential witnesses for value-level behavior.

Initial tests: end-to-end differential tests between Lean/source expected
semantics and runtime for admitted examples, especially around F06 and F07.

### F09. The current theorem framing is per-call, not sequential/adaptive-history based

Source reports: `executive_findings.md`, `trust_boundaries.md` section 11,
`theorem_framing.md` missing theorem 3, `evaluation_plan_runbook.md` acceptance
gate.

Evidence cited by review: frozen observer and existing trace comparisons are
per-entrypoint/per-call; `run_artifact` executes one entrypoint; update
obliviousness is naturally a property of call histories under adaptive hosts.

Best fix: define an interactive history semantics where the host chooses public
inputs adaptively after seeing previous public outcomes, returns, errors, and
state effects. Prove sequential composition with accumulated leakage. Start with
exact backends, then lift ORAM through a hybrid/computational composition
argument.

Initial tests: multi-call scripts that compare histories, including calls whose
later public inputs depend on earlier status or return observations.

### F10. Mixed-backend ordered object schedule leakage needs an explicit theorem

Source reports: `theorem_framing.md` missing theorem 8,
`evaluation_plan_runbook.md` red-team test F.

Evidence cited by review: mixed exact and ORAM objects compose, but the review
calls out that counts alone are insufficient if the ordered interleaving of
object accesses can depend on secrets.

Best fix: make the ordered logical object-access schedule an explicit public
leakage component, and prove it is public-determined for admitted artifacts, or
transform/reject programs whose object access order can vary with secrets. The
whole-storage theorem should compose exact and ORAM object theorems over this
ordered schedule.

Initial tests: a program with two confidential objects where a secret predicate
can swap access order; expect schedule padding/linearization or rejection.

### F11. Legacy axiom modules remain imported through the umbrella module

Source reports: `executive_findings.md`, `trust_boundaries.md` section 6,
`theorem_framing.md` inventory overview and missing theorem 6,
`theorem_inventory.md`, `theorem_inventory.tsv`.

Evidence cited by review: two legacy axioms exist:
`legacyOramLocalTheorem` and `legacySgxMicroLocalTheorem`. Static checks say
proof-grade checkers avoid them, but `UOToolchain.lean` imports the legacy
modules.

Best fix: split `UOToolchain.ProofGradeRoot` from `UOToolchain.LegacyRoot`.
The proof-grade root and default CI target should not import legacy axiom
modules. Add theorem-level `#print axioms` or environment dependency checks for
named final theorems and fail CI on unwhitelisted axioms.

Initial tests: grep/import checks as a backstop, plus a machine-readable axiom
report for final theorem names.

### F12. Source-backed runtime checks are syntactic drift checks, not Rust semantic refinement

Source reports: `executive_findings.md`, `trust_boundaries.md` section 7,
`theorem_framing.md` main theorem-family notes and missing theorem 7.

Evidence cited by review: `RuntimeImplementationInterface.lean` proves
substring, ordered-line, and lack-of-substring predicates over Rust source
strings.

Best fix: label these checks as source-drift evidence, not Rust semantic
verification. Strengthen high-risk paths with generated code hashes, Lean-derived
semantic tests, Kani/Prusti/Creusot/MIR proofs where feasible, or a smaller
runtime core generated from Lean.

Initial tests: tamper cases that add required needles in dead code/comments and
ensure the checker cannot be fooled, or explicitly document the limitation.

### F13. Runtime witness/certificate extraction remains a trusted producer

Source reports: `trust_boundaries.md` section 8, `theorem_framing.md` missing
theorem 7, `evaluation_plan_runbook.md` acceptance gate.

Evidence cited by review: the real runtime emits proof objects that Lean accepts;
acceptance proves the object satisfies predicates, not necessarily that it
faithfully describes the actual execution.

Best fix: reduce witness authority. Have the runtime emit minimal primitive
events and a transcript hash; make Lean or a small independent checker
reconstruct derived witnesses/certificates. Alternatively, semantically verify
the extraction code for the hot path.

Initial tests: second-interpreter or replay checks that reconstruct the minimal
trace from runtime events and compare it with emitted certificates.

### F14. Public gas theorem does not imply real-cost or wall-clock obliviousness

Source reports: `theorem_framing.md` main theorem-family notes and missing
theorem 11.

Evidence cited by review: public gas is modeled; wall-clock/runtime resource
usage is outside the stated claim unless separately modeled.

Best fix: keep the paper claim explicit: the theorem covers the modeled public
gas metric only. Do not imply CPU time, cache behavior, page faults, or wall-clock
obliviousness unless a platform cost model and proof are added.

Initial tests: none needed for the narrow claim; this is primarily theorem text
and documentation hygiene.

### F15. Rust `unsafe` appears in theorem-adjacent production code

Source reports: `trust_boundaries.md` section 9, `evidence_index.md`.

Evidence cited by review: `unsafe` appears in core type builders, kernel runtime
slot-program boxing, confidential kernel step boxing, and trace/buffer code.

Best fix: remove `unsafe` where safe `Vec`/`Box<[T]>` construction suffices.
Where it remains, isolate it in a small audited module with documented invariants,
Miri tests, fuzz tests, and code review gates.

Initial tests: `cargo miri test` for the isolated builders and fuzz/property
tests over lengths and initialization patterns.

### F16. Randomness, crypto nonce, and fresh-coin implementation discipline is not fully connected to formal assumptions

Source reports: `trust_boundaries.md` section 10, `theorem_framing.md` missing
theorem 9, `evaluation_plan_runbook.md` red-team test G.

Evidence cited by review: README lists crypto/TEE/ORAM assumptions; runtime uses
RNG seeds/fresh coins and concrete crypto crates; existing fresh-coin validation
exists, but the complete connection from runtime nonces/seeds to formal
freshness/IND-CPA preconditions is not visible.

Best fix: add an executable checker or theorem connecting runtime encryption and
ORAM remap calls to unique nonces, domain-separated associated data, fresh
leaf/remap randomness, and disabled diagnostics in production theorem mode.

Initial tests: instrument multi-call histories to assert no nonce/seed reuse and
no proof-grade path can inject repeated diagnostic coins.

### F17. TEE deployment assumptions lack a concrete mapped implementation story

Source reports: `practicality.md` blocker 11, `evaluation_plan_runbook.md` phase
6, `evidence_index.md` claim and TCB references.

Evidence cited by review: theorem names SGX/TEE assumptions; practical deployment
needs key management, attestation, rollback protection, crash recovery, sealing,
versioning, and encrypted returns.

Best fix: create an assumption-to-mechanism matrix for SGX/TEE deployment. For
each assumption, either point to implementation evidence, mark it explicitly
external/deployment-only, or remove it from the implemented claim. The first
implementation milestone should include attestation transcript, sealed-state
freshness/rollback counter, and encrypted return-channel integration.

Initial tests: deployment checklist tests for presence of enclave boundary,
attestation artifact, sealed storage, rollback counter, and return-channel crypto.

### F18. Lean toolchain is pinned to `stable`, not an exact release

Source reports: `trust_boundaries.md` section 12,
`evaluation_plan_runbook.md` phase 0, `review_metadata.json`.

Evidence cited by review: `proof/lean/lean-toolchain` contains
`leanprover/lean4:stable`; Cargo dependencies are exact-pinned.

Best fix: pin an exact Lean release, record the exact `lake --version` in
reproducibility artifacts, and commit dependency manifests when external Lean
dependencies are added.

Initial tests: reproducibility preflight should fail if the Lean toolchain is
`stable` or otherwise non-exact.

## Recommended fix order

1. F01, F02, F04, F05: establish fail-closed policy and explicit leakage for all
   host-visible returns/status/getters/errors.
2. F06, F07, F08: align semantics or narrow the theorem claim while adding
   differential witnesses.
3. F11, F12, F13: clean proof audit and runtime witness trust boundaries.
4. F09, F10: lift from single-call/object-local statements to history and
   ordered mixed-backend composition.
5. F03, F16, F17: close remaining host-visible failure and assumption-mapping
   gaps.
6. F15, F18: reduce implementation-safety and reproducibility audit risk.
7. F14: state the public-gas versus real-cost boundary explicitly.
