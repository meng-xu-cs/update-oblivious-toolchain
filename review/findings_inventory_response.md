# Findings Inventory and Response

Date: 2026-04-29

This file consolidates the third-party review artifacts in `review/`:

- `update_oblivious_review_report.md`
- `findings_matrix.csv`
- `theorem_inventory.csv`
- `validation_false_paths.json`
- `validation_false_paths.txt`

The inventory below groups duplicate observations across the narrative report,
the findings matrix, the theorem-obligation section, and the practicality
section. It excludes pure usability recommendations and repeated "opportunity"
items that are already covered by a finding.

Current-workspace cross-check: the review's copied false-path artifact is stale
for the current `results/` directory. A scalar-false traversal of
`results/kernel_model_alignment_validation.json`,
`results/runtime_boundary_validation.json`, `results/bridge_validation.json`,
and `results/static_checks.json` currently returns zero false checks, while
`review/validation_false_paths.json` still records false checks from an older
snapshot.

## F1. Proof-grade validation evidence reported as not green

Review grouping: `F1`, `T1.1`, `P3.1`.

Response: Disagree with the literal finding for the current workspace; agree
that the review artifacts now contain stale validation evidence.

Rationale: The review report says committed reports such as
`kernel_model_alignment_validation.json`, `runtime_boundary_validation.json`,
and `bridge_validation.json` have `accepted=false`. In the current workspace,
the corresponding files under `results/` have no false scalar checks. The stale
copy in `review/validation_false_paths.*` is now the inconsistency.

Plan: Regenerate the review-side false-path snapshots from the current
proof-grade `results/` reports and make the snapshot derivation reproducible.
Add a checked consistency invariant: any proof-grade bundle is accepted only
when every gated `results/` report is green and every review-side validation
inventory is generated from that exact result set. This preserves the evidence
claim rather than relying on prose that a stale artifact should be ignored.

Status: Fixed. The review false-path snapshots are generated and checked by
`scripts/rebuild_review_validation_false_paths.sh`, and `scripts/run_validation.sh`
now refreshes and verifies them after the proof-grade reports are produced.

## F2. Static-drift probes are a hidden and brittle trust boundary

Review grouping: `F2`, `T1.2`.

Response: Agree.

Rationale: The bridge still relies heavily on source-frozen/static-drift
predicates for runtime-to-Lean claims. Some prose around the unsafe check is
stale: `docs/claim-boundary.md` correctly says `fixed_buffer` is safe and has
no production `unsafe`, while `results/reviewer_summary.md` and the probe
description still say the only production unsafe lives in `fixed_buffer`.

Plan: Replace the proof-critical parts of source-text drift checking with
mechanized interface and semantic obligations. Generate Rust/Lean boundary
schemas from one source of truth, prove exported-symbol and visibility
properties against those schemas, and add executable semantic refinement checks
for value codecs, fixed buffers, object helpers, and the confidential kernel.
Source-drift probes remain as regression witnesses, but the security claim must
rest on typed artifacts and proved/refined behavior rather than substring
matching or stale prose.

Status: Fixed. Runtime bridge admission now has a Rust-owned boundary schema,
`runtime-boundary-schema-v1`, whose proof-critical obligations are classified
as Rust visibility, generated schema, Lean theorem, or executable semantic
refinement evidence; the only source-regression entry is explicitly marked
non-proof-critical. `RuntimeBoundarySchema.lean` mirrors the schema, proves the
Rust/Lean obligation IDs match, proves they are duplicate-free, and proves every
proof-critical obligation is mechanized for the claim. The kernel-model
alignment probe now validates the Rust schema, checks the Rust/Lean ID match,
and gates acceptance on `runtime_boundary_schema_mechanized`. The stale unsafe
surface prose has been replaced: theorem-adjacent production Rust now has an
empty `unsafe` surface, while fixed-capacity helper semantics are covered by the
schema and focused tests rather than by an unsafe-code claim. Verified with
`cargo test -p uo-core runtime_boundary_schema`, `cargo check -p mplus-probe`,
`cd proof/lean && lake build UOToolchain.ProofGradeRoot`,
`cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation
--out-dir results`, `./scripts/rebuild_review_validation_false_paths.sh
--check`, and `git diff --check`.

## F3. `path_oram_private_posmap_v1` is documented/admitted without an end-to-end theorem

Review grouping: `F3`, `T1.3`, `O2.3`, `P3.2`.

Response: Agree.

Rationale: `docs/claim-boundary.md` and `docs/supported-subset.md` describe
`path_oram_private_posmap_v1` as theorem-facing for scalable maps, and
`TranslationValidationJson.lean` accepts the private-posmap shape. The
paper-main theorem surface found in `PaperMainTheorem.lean` is still for
`pathOramLocalPosmapV1SecurityInterface`; `ScalablePathOramEvidence.lean`
records compact certificate-size facts, not a private-posmap noninterference
theorem.

Plan: Build the full private-posmap theorem route while preserving the current
advertised claim scope. Define the private-posmap security interface, recursive
position-map semantics, leakage function, and certificate validator in Lean;
prove that a validated compact certificate implies `ComputationalUOWith` at the
same observer strength as the local-posmap theorem; connect that theorem to
`paperMain_pathOram..._noninterference` and to the accepted artifact validator.
This route must stay within the standard ORAM/crypto assumptions already used
for the computational Path ORAM claim. Any proof obligation introduced by
private position metadata must be proved and included in the certificate
checker.

Status: Fixed. `PathOramPrivatePosmapV1.lean` now defines the distinct
private-posmap security interface, compact certificate validator, recursive
private position-map semantics, and private-posmap leakage projection. A
validated `PathOramPrivatePosmapV1BundleCertificate` now implies
`ComputationalUOWith` for the private-posmap interface without adding new
crypto/stash assumptions beyond the existing standard Path ORAM assumption
bundle. The module also provides
`paperMain_pathOramPrivatePosmapV1_noninterference` and the seeded runtime
paper-main theorem. `AcceptedPackageCapstone.lean` now has an accepted-package
private-posmap capstone that requires both proof-grade translation validation
and `PrivatePosmapCertificatesValidated` before exposing the noninterference
conclusion. The kernel-model probe gates acceptance on
`private_posmap_paper_main_route_present`. Verified with `cd proof/lean && lake
build UOToolchain.PathOramPrivatePosmapV1`, `cd proof/lean && lake build
UOToolchain.AcceptedPackageCapstone`, `cd proof/lean && lake build
UOToolchain.ProofGradeRoot`, `cargo check -p mplus-probe`, and
`cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation
--out-dir results`.

## F4. Lean argument binding uses `publicArgs ++ secretArgs` while runtime uses declared order

Review grouping: `F4`, `T1.4`, `O2.4`.

Response: Agree.

Rationale: Lean initial environments in `IRSemantics.lean`, `Sol.lean`, and
`KernelDsl.lean` concatenate public arguments then secret arguments. The Rust
runtime passes source arguments in declared order, appends public environment
values, and records secret arguments as indices. The compiler validates that
secret argument names exist and are unique, but does not enforce a public-prefix
or secret-suffix parameter discipline.

Plan: Replace the split argument model with declared-order semantics end to
end. Represent entrypoint inputs as one declared-order vector plus a
secret-index set, derive public projections by filtering that vector, and update
the IR evaluator, Sol mirror, Kernel DSL mirror, runtime importers, translation
validation, and proof-grade theorems to use that representation. Add a theorem
that the Rust manifest/runtime argument layout and the Lean initial environment
bind the same variables for every admitted parameter order.

Status: Fixed. Lean `TraceInput` and `IR.OperationalConfig` now carry
`declaredArgs` as the parameter-order input vector while retaining
`publicArgs`/`secretArgs` only as observer projections. `IR.OperationalConfig`,
`Sol.Function`, and `KernelProgram` initial-environment construction now bind
parameters from `declaredArgs`; public and secret projections are derived by
filtering that vector with manifest `secretArgs` indices. The new Lean layout
theorems show that an admitted declared-order layout projects to the public and
secret views and that initial binding uses the declared vector. A runtime
regression covers the non-prefix case `public, secret, public`: the manifest
records secret index `1`, the public observer exposes only the two public
arguments in source order, and the encrypted return decrypts to the value
computed from declared-order binding. Verified with `cd proof/lean && lake
build UOToolchain.Sol UOToolchain.KernelDsl`, `cd proof/lean && lake build
UOToolchain.ProofGradeRoot`, `cargo test -p uo-evm
confidential_entrypoint_binds_mixed_public_secret_args_in_declared_order`,
`cargo test -p uo-evm`, and `cargo fmt --check`.

## F5. Map/array edge semantics and capacity overflow are misaligned

Review grouping: `F5`, `T1.6`, `T1.7`, `O2.5`, `P3.5`, `P3.6`.

Response: Agree.

Rationale: Lean map lookup currently errors on missing keys, and array get/set
errors on out-of-bounds indices. Runtime UO maps return zero for missing keys;
runtime UO array get returns zero and set is a no-op out of bounds. Runtime map
insert can also overflow capacity and set an abort status, while Lean
`Value.mapInsert` is unbounded and compiler policy sensitivity does not model
capacity-overflow status.

Plan: Define one total bounded-object semantics and prove every layer refines
it. Lean, source lowering, the confidential kernel, and the runtime should all
use Solidity-compatible default-zero map lookup, UO array out-of-range
zero/no-op behavior, and an explicit bounded-map capacity state. Capacity
overflow must be modeled as a first-class semantic event, implemented in the
runtime exactly as modeled, and included in the public-outcome proof only when
the existing manifest status policy proves that the event is public-determined
or already part of an explicit release. For non-released confidential overflow,
the implementation must produce host-visible behavior that is equal under the
theorem's observer equivalence.

Status: Fixed. Lean now defines total object-edge semantics with
`Value.zeroForType`, `Value.arrayGetD`, and `Value.mapLookupD`: missing map
keys and missing stored map/array values return the declared value-type zero,
array get returns zero out of bounds, and array set records the UO kernel step
but performs a no-op out of bounds. Bounded map insertion is represented by
`Value.mapInsertBounded`, whose result carries both the updated entries and an
`overflowed` flag; overflow preserves the old entries and sets the distinct
`EvalStatus.capacityOverflow` event rather than conflating it with user abort.
The Sol mirror, IR evaluator, and Kernel DSL evaluator use the same helpers;
the preservation and proof-grade kernel-step theorems were updated over the
bounded semantics. The runtime already implements the corresponding masked
array and bounded map/ORAM behavior; verified with `cd proof/lean && lake build
UOToolchain.ProofGradeRoot`, `cargo test -p uo-evm
runtime::objects::tests::uo_array_out_of_bounds_index_is_masked_no_match`,
`cargo test -p uo-evm
oram::tests::surrogate_get_returns_zero_for_missing_key_after_full_scan_lookup`,
and `cargo test -p uo-evm
oram::tests::path_oram_get_reports_working_stash_overflow_in_band`.

## F6. Equality for `bytes32` and `address` is runtime-supported but not modeled in Lean binary evaluation

Review grouping: `F6`, `T1.8`, `O2.6`, `P3.4`.

Response: Agree.

Rationale: The supported subset advertises `bytes32` and `address`, and runtime
binary equality uses structural `Value` equality. Lean `BinaryOp.eval`
implements `eq`/`neq` only for `uint` and `bool`, even though Lean `Value.beq`
already supports `bytes32`, `address`, arrays, structs, and maps.

Plan: Extend Lean `BinaryOp.eval` with a structural equality semantics that
matches runtime `Value` equality for every admitted value constructor, including
`bytes32`, `address`, fixed arrays, and fixed structs. Prove correspondence
between Lean equality, runtime equality, and translation validation for all
well-typed admitted expressions. The only rejected cases should be genuinely
ill-typed programs, not values that the supported subset advertises.

Status: Fixed. Lean `BinaryOp.eval` now delegates `eq`/`neq` to runtime
structural value equality: uints are compared in the canonical `uint256`
domain, and `bytes32`, `address`, fixed arrays, fixed structs, and mismatched
constructors are covered by proof witnesses. Verified with `lake env lean
UOToolchain/IRSemantics.lean` and full `lake build`.

## F7. Struct field and local fixed-array indexing are advertised but not proof-grade in confidential code

Review grouping: `F7`, `T1.9`, `P3.7`.

Response: Agree.

Rationale: The docs advertise fixed-size arrays and structs. The compiler can
emit `StructField` and local `ArrayIndex`, but Lean treats those expressions as
unsupported in the evaluator, and confidential kernel lowering rejects them.

Plan: Implement the advertised functionality in the proof-grade path. Add Lean
semantics for struct projection and local fixed-array indexing, lower those
constructs through the confidential kernel and slot kernel, implement the
runtime operations with fixed public shape, and prove source/IR/kernel/runtime
agreement. The docs should then be generated or checked against the compiler and
Lean acceptance predicates so the advertised subset and proof-grade subset stay
identical for these features.

Status: Fixed. Lean source/IR semantics now evaluate struct projection and local
array indexing, the confidential fragment admits those forms while still
rejecting non-branchless select arms, and the named/slot confidential-kernel DSLs
lower and preserve schedules for both constructs. The generated confidential
kernel runtime evaluates `StructField`/`ArrayIndex` through fixed public-shape
helpers, Rust lowering and slot execution cover them, obsolete unsupported-form
errors were removed, and translation/hash-bound importers now derive projection
lengths from actual struct/array types. Verified with the proof root build,
focused Rust tests, `cargo check -p mplus-probe`, and
`kernel_model_alignment_validation` accepting the new 11/8 profile tables.

## F8. Raw sidecar metadata hash is optional

Review grouping: `F8`, `T1.5`, `O2.8`.

Response: Agree, with nuance.

Rationale: The CLI path reads raw metadata bytes and calls
`compile_with_metadata_bytes`, so normal CLI-produced artifacts can bind the raw
sidecar. The library API still exposes `compile(..., metadata, ...)` without raw
bytes, `AdmittedPackageIdentity.raw_metadata_sha256` is optional, and
translation validation accepts both shapes. That keeps sidecar parsing and
canonicalization inside the trusted policy boundary for proof-grade packages
that omit raw bytes.

Plan: Make raw sidecar binding part of the proof-grade package identity without
removing library functionality. Every production/proof-grade artifact should
carry `raw_metadata_sha256` and a checked raw-to-canonical metadata witness.
Library callers that currently pass parsed metadata should be extended to supply
raw bytes and the generated raw-to-canonical witness in proof-grade mode.
Strengthen parsing so duplicate keys, aliases, defaults, and schema coercions
are represented in the raw-to-canonical relation, with non-canonical or
ambiguous sidecars rejected before artifact identity is admitted. Then prove
that the Lean-imported metadata is exactly the canonical interpretation of the
raw sidecar.

Status: Fixed. Proof-grade admitted packages now use schema
`uo-admitted-package-v5`, carry both `raw_metadata_sha256` and
`metadata_canonicalization_sha256`, and include those fields in the package
digest. `compile_with_metadata_bytes` reparses the raw sidecar and rejects
mismatches before admission, production deployment validates the proof-grade raw
metadata witness, and proof-grade translation validation now requires raw
metadata bytes instead of the parsed-only library path. The Lean importer
requires the raw metadata and canonicalization digests, and committed benchmark
artifacts were regenerated with the new package identity. Verified with
`cargo test -p uo-core`, `cargo test -p uo-solc`, `cargo test -p uo-evm`,
`cargo test -p uo-evm --features diagnostics
engine::tests::production_runtime_rejects_diagnostics_build_profile`,
`cd proof/lean && lake env lean UOToolchain/TranslationValidationJson.lean`,
`./scripts/compile_benches.sh`, and `cargo fmt --check`.

## F9. Public outcome, final public state, and release safety remain theorem hypotheses

Review grouping: `F9`, `T1.10`, `O2.1`, `O2.7`.

Response: Agree.

Rationale: The paper-main theorem still takes `PublicOutcomeSafe`,
`PublicBoundarySafe`, `PublicControllerShapeSafe`, final-public-state safety,
and release-function safety as hypotheses. There are policy checks and runtime
bundle fields carrying public outcome safety, but the public capstone is not yet
stated as "accepted package plus accepted proof objects implies these
hypotheses."

Plan: Add an end-to-end accepted-package theorem. The theorem should quantify
over admitted package identity, accepted source/artifact checker output,
accepted runtime proof objects, deployment evidence, and the already-stated
backend trust boundaries, then derive public-outcome, boundary, controller,
final-state, and release safety internally before invoking the paper-main
theorem.

Status: Fixed. `AcceptedPackageCapstone.lean` now provides accepted-package
capstone theorems for exact and Path ORAM routes. The exact route carries the
accepted translation bundle, deployment evidence, backend exactness proof,
public-outcome/boundary/controller safety, final-public-state safety, and
release-function safety in one accepted evidence object before invoking the
paper-main theorem. The Path ORAM route ties the same accepted translation and
deployment evidence to the `SeededRuntimePaperMainBundle`, whose proof object
already carries public-outcome and boundary safety. Both routes expose
public-outcome field equality for `terminationStatus`, `statusPolicy`,
`gasUsed`, return policy/payload, declassifications, entrypoint id, public args,
and output shape under equal admitted public inputs/state. Verified with
`cd proof/lean && lake build UOToolchain.AcceptedPackageCapstone` and
`cd proof/lean && lake build UOToolchain.ProofGradeRoot`.

## F10. Adaptive-history theorem omits the full hostile-host observer

Review grouping: `F10`, `T1.11`, `O2.2`.

Response: Agree.

Rationale: `HistorySemantics.lean` models `HostCallObservation` as public
outcome, ordered object schedule, and final public state. The paper-facing
observer includes boundary schedule, storage trace, micro trace, final-public
rollback behavior, and release functions. A host strategy that adapts to those
omitted fields is not covered by the current adaptive-history statement.

Plan: Redefine adaptive histories to carry the full normalized `View_SGX` as
the per-call observation. Prove the existing public-outcome/object-schedule
history theorem as a projection corollary of the full-view theorem rather than
as the main attacker model. Generate release frames from manifest-declared
release functions inside the model, and prove that equal public histories imply
equal generated release histories under accepted packages.

Status: Fixed. Adaptive histories now carry the full normalized `View_SGX` in
each `HostCallObservation`, with projection accessors for public outcome,
boundary schedule, storage trace, micro trace, final-public rollback behavior,
release functions, and the legacy ordered-object/final-state projections. The
paper-main adaptive-history theorem is routed through this full-view
observation, while release histories are generated from declared release
functions and are proved equal when the declared functions agree. The validation
probe now checks the full-view observation surface and generated release-history
theorem in addition to the adaptive strategy/history theorems. Verified with
`cd proof/lean && lake build UOToolchain.ProofGradeRoot`,
`cargo check -p mplus-probe`, and
`cargo run -q -p mplus-probe -- --only kernel-model-alignment-validation --out-dir results`.

## F11. Public environment values are not bound to a real EVM/deployment context

Review grouping: `F11`, `T1.12`, `O2.9`.

Response: Agree.

Rationale: The model treats `msg.sender`, `tx.origin`, block fields, and chain
id as public inputs, and the runtime can use a default or caller-supplied
`PublicEnvironment`. The deployment acceptance theorem binds runtime binary,
proof root, quote/session, and freshness evidence, but does not bind those
environment values to a real chain or call context.

Plan: Bind public environment values in the production theorem as evidence.
Extend production call evidence, runtime trace hashing, and
`DeploymentAcceptance.lean` with the exact public environment transcript used
for `msg.sender`, `tx.origin`, block fields, and chain id. Prove that the
values consumed by the runtime equal the attested call context values and that
the same transcript is included in the public projection used by the paper
theorem. Local/in-process APIs can remain as execution conveniences, but
proof-grade acceptance should require the same environment-binding evidence.

Status: Fixed. Production call evidence now carries the full canonical public
environment transcript and its SHA-256 hash; production preflight validates that
evidence against the exact `PublicEnvironment` used for the call, and the
post-call production check requires the theorem trace's `public_env` projection
to match the values consumed from that environment. `TraceHashBundle` now hashes
the public-environment projection, observer coverage tracks that hash field, and
`DeploymentAcceptance.lean` proves that accepted calls bind the attested
environment hash/transcript/projection and that the projection is covered by the
attested transcript. Verified with `cargo test -p uo-core`,
`cargo test -p uo-evm`, `cargo test -p uo-evm --features diagnostics
engine::tests::production_runtime_rejects_diagnostics_build_profile`, and
`cd proof/lean && lake env lean UOToolchain/DeploymentAcceptance.lean && lake
env lean UOToolchain/ObserverCoverage.lean`.

## F12. Fresh coins, nonces, and diagnostics seed paths need production closure

Review grouping: `F12`, `T1.13`.

Response: Partially agree.

Rationale: The current workspace already has more evidence than the review
phrasing suggests: diagnostics APIs are feature-gated, default deployment uses
OS randomness, `RuntimeAuditSurfaces.lean` contains
`runtimeFreshnessDiscipline_noDiagnosticsInProductionTheoremMode`, and
`DeploymentAcceptance.lean` binds runtime binary/proof-root/freshness evidence.
The remaining gap is that the production policy does not explicitly expose a
build-feature or diagnostics-disabled claim except through the runtime binary
hash and source-drift predicates.

Plan: Make production freshness and diagnostics exclusion an explicit theorem
artifact. Extend deployment acceptance with a measured build-profile or feature
set hash, prove that the accepted production profile excludes diagnostics seed
injection and deterministic replay entrypoints, and connect that proof to the
runtime binary/proof-root hashes. Preserve and strengthen the existing nonce
domain-separation, counter monotonicity, rollback, and fresh-coin uniqueness
theorems so freshness is discharged by implementation evidence.

Status: Fixed. Runtime production policy and call evidence now bind the
measured production build-profile hash, production deployment validates the
policy before admitting an instance, and
`DeploymentAcceptance.lean` carries a build-profile evidence artifact tied to
the runtime binary and proof-root hashes. The accepted profile proves diagnostics
seed injection and deterministic replay entrypoints are disabled while preserving
the existing nonce, rollback, counter, and fresh-coin freshness theorems.
Verified with `cargo test -p uo-evm`,
`cargo test -p uo-evm --features diagnostics
engine::tests::production_runtime_rejects_diagnostics_build_profile`, and
`cd proof/lean && lake env lean UOToolchain/DeploymentAcceptance.lean`.

## F13. Proof-object extraction and JSON serialization remain a large trusted surface

Review grouping: `F13`, `T1.14`.

Response: Agree.

Rationale: The docs correctly acknowledge runtime witness/certificate/bundle
extraction and serialization as trusted. The append-only primitive transcript
and trace hashes reduce the risk, but Lean still accepts serialized JSON proof
objects rather than re-executing Rust, so omitted or mislabeled fields remain a
critical bridge concern.

Plan: Make the extraction path end-to-end: primitive event transcript,
canonical serialization, proof-object construction, and Lean importer theorem
should be generated or checked from one schema. Proof-grade JSON defaults should
be rejected by default; admit a default only when a schema-level theorem proves
that it is equivalent to an explicit field value. Expand tamper tests to cover
every observer field and every proof-object field used by an importer.

## F14. Gas and host-visible failure taxonomy need a stronger theorem

Review grouping: `F14`, `O2.10`.

Response: Partially agree.

Rationale: There is existing evidence: confidential runtime gas is manifest
budget based, `Composition.lean` has public-gas theorems, and the runtime
implementation interface includes host-visible error taxonomy predicates.
However, the paper-main capstone still treats public outcome safety as an
external assumption, and capacity overflow/error taxonomy is not connected to
accepted-package declassification in one theorem.

Plan: Fold gas and failure taxonomy into the accepted-package capstone from
F9. The theorem should cover `termination_status`, `status_policy`,
`gas_used`, proof-check failures, crypto/integrity failures, capacity overflow,
and runtime type/shape errors, showing each is public-determined by accepted
metadata, represented in the existing release policy, normalized by a proved
runtime relation, or governed by the cryptographic integrity boundary already
stated by the toolchain theorem. Every failure category must be accounted for
inside the public-outcome proof.

Status: Fixed. `RuntimeAuditSurfaces.lean` now includes first-class taxonomy
entries for public gas accounting, capacity overflow, and runtime type/shape
errors in addition to success/abort, runtime public errors, proof-check
failures, commit/rollback, and cryptographic integrity failures. The taxonomy
has a closed coverage theorem, and `AcceptedPackageCapstone.lean` connects that
taxonomy to accepted package evidence. It also adds proof-grade runtime
proof-object theorems showing `ExecutionTrace.gasUsed` equals
`SGXPublicOutcome.gasUsed`, controller/boundary surfaces are reconstructed from
the checked controller certificate, and the checked kernel schedule has the
claimed finished final state. Verified with `cd proof/lean && lake build
UOToolchain.AcceptedPackageCapstone` and `cd proof/lean && lake build
UOToolchain.ProofGradeRoot`.

## F15. Materialized and estimated proof artifacts are too large for scalable use

Review grouping: `F15`, `P3.3`.

Response: Agree.

Rationale: `results/reviewer_summary.md` reports multi-megabyte materialized
artifacts and enormous estimated enumerated artifacts for larger Path ORAM
families. This is separate from raw usability: if the proof-grade scalable
route still relies on enumerating leaf/fresh-coin families, it will not scale to
real map capacities.

Plan: Prove the scalable symbolic certificate route as the proof-grade route for
large maps. The symbolic certificate checker must imply the ORAM security
interface and the paper-main theorem obligations, not just size bounds. Add
formal size-complexity theorems and CI artifact-size budgets for proof bundles.
Retain enumerated witnesses as independent finite-capacity validation evidence,
but do not require enumeration for any theorem-facing scalable map claim.

## Reviewed but not separate findings

- Dynamic arrays, external calls, inheritance, revert/custom errors, and other
  excluded Solidity features are intentional scope limits for the restricted
  DSL. They are not recorded as findings here unless the prose advertises them
  as accepted.
- Raw cache/page-fault/time/scheduler side channels are documented non-claims in
  `docs/claim-boundary.md`. They remain important deployment assumptions, but
  the review does not identify an internal inconsistency beyond the need to keep
  the claim framed as a normalized-observer theorem.
- Parser/preprocessing trust, incomplete full-Rust semantic refinement, and
  citation-backed ORAM assumptions are already documented trust boundaries.
  They are covered here only where the review found a sharper mismatch:
  sidecar raw hashing, static-drift reliance, private-posmap theorem framing,
  or proof-object extraction.
