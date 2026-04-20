# Top-Tier Paper Execution Roadmap

This roadmap treats every theorem-strengthening, assumption-reducing, and
trusted-surface-shrinking task as mandatory work for the final paper.

The target is not merely "Lean checks some emitted artifacts." The target is
one end-to-end theorem over the admitted Solidity subset, the concrete
`path_oram_local_posmap_v1` backend, the real confidential runtime kernel, and
an explicit hostile-host observer.

## Current Baseline

The repository has already closed several important proof-grade gaps.

- the proof-grade translation boundary is now the direct Lean checker
  `checkProofGradeTranslationArtifacts`, fed by separately materialized source
  and candidate artifacts
- `uo-check` is no longer part of that proof-grade acceptance path and is no
  longer in the proof-grade TCB
- confidential functions now carry the canonical named and slot DSL programs
  directly, and the direct Lean checker validates exact body-to-function-to-
  manifest agreement instead of relying on an ad hoc schedule-reconstruction
  path
- the theorem-facing backend path is frozen to `path_oram_local_posmap_v1`
- the runtime exports proof-grade kernel, refinement, and trusted-kernel proof
  objects, and Lean checks those objects with theorem-tight executable
  checkers; the trusted-kernel bundle is now materialized through
  `ExecutionTrace`'s internal reconstruction path rather than by hand-assembling
  theorem certificates in `uo-evm`
- the paper-facing Lean route now also freezes the remaining runtime-side trust
  point as explicit objects,
  `PaperMainRuntimeKernelAssumptions`,
  `PaperMainRuntimeKernelBoundary`, `PaperMainPathOramAssumptions`, and
  `PaperMainPathOramEndToEndBoundary`, so the end-to-end claim surface now
  names the runtime/kernel gap instead of leaving it informal
- the runtime already enforces the admitted public kernel schedule online for
  confidential entrypoints, and that online check now routes through a shared
  core schedule tracker rather than an ad hoc runtime-local cursor

The repository has not yet closed the scientifically strongest end-to-end
story. The remaining gaps are:

- there is not yet a machine-checked theorem that the real Rust kernel
  implementation refines the Lean kernel model; the repo now has an explicit
  witness-to-finished-Lean-state refinement relation, but not yet an
  honesty-by-construction theorem connecting the actual Rust states to that
  relation
- there is not yet a machine-checked theorem that all secret-dependent runtime
  behavior is confined to that kernel
- the explicit runtime-side paper bundle
  `PaperMainRuntimeKernelAssumptions` is still assumed rather than discharged
- there is not yet a source-to-kernel compiler correctness theorem for the
  admitted Solidity subset
- the concrete `PathOramLocalPosmapV1SecurityAssumptions` bundle is still only
  partially discharged
- the SGX/TEE deployment story is still weaker than a full malicious-host
  execution theorem

## Final Theorem Target

The paper should aim for exactly one flagship theorem:

> For every admitted Solidity source program `P`, if `uo-solc` compiles `P`
> to artifact `A`, the direct Lean source/artifact checker accepts that pair,
> the real runtime executes `A` and emits runtime proof objects accepted by
> Lean, and the explicit concrete backend / cryptographic / TEE assumptions
> hold, then the real host-visible execution satisfies the paper's update-
> obliviousness theorem against the stated hostile-host observer.

The exact claim surface should be frozen to:

- source language: the admitted Solidity subset only
- backend set: `path_oram_local_posmap_v1` only
- translation boundary: direct Lean checking of raw source/candidate artifacts
- runtime boundary: the tiny confidential kernel and its emitted proof objects
- deployment boundary: one explicit hostile-host observer
- trusted implementation surface: Lean kernel, explicit external assumptions,
  tiny runtime kernel, and nothing else

Everything else in this roadmap exists only to make that statement true.

## Non-Negotiable Design Decisions

These decisions make the paper scientifically stronger and more reviewer-proof.

- Keep exactly one proof-grade compiler boundary: direct source/candidate
  artifact checking in Lean.
- Keep exactly one proof-grade backend path: `path_oram_local_posmap_v1`.
- Keep exactly one runtime theorem boundary: a tiny confidential kernel with
  explicit proof objects.
- Keep exactly one hostile-host observer and state it explicitly in both docs
  and Lean.
- Prefer shared representations and shared interpreters over parallel
  implementations that merely agree by tests.
- Shrink the trusted Rust surface until no further meaningful shrinkage is
  possible; then prove the remaining kernel implementation refines the model.
- Do not broaden the theorem to fit the code. Reject unsupported behavior
  instead.

## Work Package 0: Freeze The Claim Surface

Objective: make the paper's theorem, observer, assumptions, and TCB precise
enough that every subsequent proof obligation is forced by them.

Primary files:

- [README.md](/home/m285xu/update-oblivious-toolchain/README.md)
- [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md)
- [docs/paper-theorem-profile.md](/home/m285xu/update-oblivious-toolchain/docs/paper-theorem-profile.md)
- [docs/paper-main-theorem-checklist.md](/home/m285xu/update-oblivious-toolchain/docs/paper-main-theorem-checklist.md)
- [docs/tee-runtime-hardening.md](/home/m285xu/update-oblivious-toolchain/docs/tee-runtime-hardening.md)
- [docs/trusted-kernel-verification.md](/home/m285xu/update-oblivious-toolchain/docs/trusted-kernel-verification.md)

Concrete tasks:

1. Write the flagship theorem in paper-ready and repo-ready form.
2. Freeze the hostile-host observer and make it the only deployment observer
   mentioned in top-level docs.
3. Freeze the backend, admitted Solidity subset, and proof-grade translation
   path.
4. Freeze the TCB statement and the explicit assumption table.
5. Remove any stale language that still sounds like "artifact validation near a
   theorem boundary" instead of "real implementation refinement to a model."

Deliverables:

- one theorem box
- one observer definition
- one assumption table
- one TCB table

Exit gate:

- every top-level security statement in the repository is traceable to either a
  theorem, an explicit assumption, or a trusted implementation component

## Work Package 1: Finish Shrinking To A Tiny Kernel

Status: completed on April 19, 2026. Confidential runtime work is now routed
through the kernel boundary, the public shell and theorem bridge are internal
to `crate::runtime`, and the remaining Rust surface is down to the core
runtime-owned types needed by the proof interface.

Objective: ensure every secret-dependent runtime effect is genuinely routed
through a tiny, auditable confidential kernel.

Primary files:

- [runtime/uo-evm/src/kernel.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/kernel.rs)
- [runtime/uo-evm/src/runtime.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/runtime.rs)
- [runtime/uo-evm/src/state.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/state.rs)
- [runtime/uo-evm/src/controller.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/controller.rs)
- [runtime/uo-evm/src/theorem.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/theorem.rs)
- [runtime/uo-allocator/src/lib.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-allocator/src/lib.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [crates/uo-core/src/kernel_dsl.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/kernel_dsl.rs)
- [crates/uo-core/src/trace.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/trace.rs)

Concrete tasks:

1. Audit every confidential runtime entrypoint and ensure it goes through
   `RuntimeKernel`.
2. Move allocator budget checks, scratch reservations, scratch wipes, and any
   runtime coin usage into explicit kernel-owned state transitions.
3. Remove or isolate any helper that can still perform secret-bearing work
   outside the kernel API.
4. Ensure witness generation is derived from real kernel execution rather than
   a parallel reconstruction path.
5. Keep the public shell outside the kernel limited to public-only logic.
6. Record a complete kernel-owned secret-state inventory and keep it current.

Deliverables:

- one closed kernel API for confidential work
- one explicit kernel state machine over objects, resources, and coins
- one auditable inventory of every remaining secret-bearing runtime structure

Exit gate:

- confidential work can be audited by reading the kernel boundary, not the
  entire runtime

## Work Package 2: Converge On A Shared DSL / Interpreter Route

Status: completed on April 19, 2026. The confidential slot DSL is now the
canonical runtime schedule source, downstream consumers use
`EntrypointManifest::canonical_kernel_step_manifest()`, and the runtime,
compiler artifacts, probe checks, and Lean proof-grade path all track the same
kernel program object.

Objective: have one canonical confidential-kernel program representation and
one semantics that both Rust and Lean use, rather than two parallel descriptions
that are only compared after the fact.

Primary files:

- [crates/uo-core/src/kernel_dsl.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/kernel_dsl.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [runtime/uo-evm/src/kernel.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/kernel.rs)
- [compiler/uo-solc/src/lib.rs](/home/m285xu/update-oblivious-toolchain/compiler/uo-solc/src/lib.rs)
- [crates/uo-core/src/manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs)
- [proof/lean/UOToolchain/ConfidentialKernelDsl.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ConfidentialKernelDsl.lean)
- [proof/lean/UOToolchain/RuntimeTrustedKernel.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeTrustedKernel.lean)
- [proof/lean/UOToolchain/RuntimeRefinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeRefinement.lean)

Concrete tasks:

1. Make the kernel DSL the canonical representation of admitted confidential
   work.
2. Make the runtime kernel execute that DSL directly or through a mechanically
   obvious interpreter boundary.
3. Make the Lean small-kernel semantics replay the same DSL, not a separately
   reconstructed schedule.
4. Make manifests and runtime witnesses point at that DSL-level program and its
   public schedule, not merely at duplicated opcode lists.
5. Eliminate any proof-grade path that relies on ad hoc schedule
   reconstruction when the DSL program is already available.

Deliverables:

- one shared DSL
- one shared public schedule notion
- one kernel interpreter story that exists in both Rust and Lean

Exit gate:

- the compiler, runtime, and Lean checker all talk about the same kernel
  program object

## Work Package 3: Prove Runtime-Kernel Refinement And Secret Confinement

Status: active. The runtime-boundary confinement audit is now green, but the
final runtime-implementation refinement theorem is still the next
proof-critical obligation on the critical path.

Objective: upgrade from "the runtime emits accepted proof objects" to "the real
runtime kernel implementation refines the Lean model, and the rest of the
runtime is public-only."

Primary files:

- [runtime/uo-evm/src/kernel.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/kernel.rs)
- [runtime/uo-evm/src/engine.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/engine.rs)
- [runtime/uo-evm/src/state.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/state.rs)
- [runtime/uo-evm/src/runtime.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/runtime.rs)
- [probe/mplus-probe/src/lib.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/lib.rs)
- [proof/lean/UOToolchain/RuntimeRefinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeRefinement.lean)
- [proof/lean/UOToolchain/RuntimeTrustedKernel.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeTrustedKernel.lean)
- [proof/lean/UOToolchain/RuntimeShellBoundary.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeShellBoundary.lean)
- [proof/lean/UOToolchain/RuntimeCoins.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeCoins.lean)

Concrete tasks:

1. Completed on April 19, 2026: define the theorem-facing refinement relation
   from the proof-grade runtime phase witness and kernel witness to one exact
   finished Lean `RuntimeKernelSchedule` state, including exact schedule,
   resource-state, and boundary/public-object projections.
2. Remaining, but tightened substantially: prove witness honesty by
   construction, not merely by post hoc checking. The runtime theorem bridge
   no longer hand-assembles controller/hidden/trusted-kernel certificates; it
   now asks `ExecutionTrace` to materialize the trusted-kernel bundle from the
   trace's own reconstructed state, while the lower-level certificate
   constructors stay internal to `uo-core` and the trusted-kernel proof object
   family is now accessor-only on the Rust side rather than a public-field bag.
   The runtime kernel now also emits the complete runtime-phase witness tail
   itself, with the live journal and the witness validator now sharing the same
   phase-transition function for commit/cold-store progression before the
   witness is materialized, and the old tail-appending witness mutators are no
   longer part of the production API surface. The production trace finalizer
   now also re-derives and validates the admitted confidential proof-bearing
   bundle family online for confidential calls: direct kernel DSL / slot /
   lowering bundles, the trusted-kernel slot bundle, and the confidential-core
   direct / slot / lowering / shell-boundary slot / shell-boundary lowering
   bundle family all have to agree with the admitted artifact before a trace is
   returned. The confidential theorem finalizer now also re-derives a
   single-trace seeded witness, retags it canonically, and rebuilds the
   explicit `SeededRuntimePaperMainFamilyBundle` online before a confidential
   trace returns, so the paper-route theorem object is now checked in the
   production runtime path rather than only by the external probe/checker
   route. The Rust side now also packages the paper-facing shell-boundary /
   expected-step / expected-public-object / expected-schedule facts as an
   explicit `RuntimeKernelInterfaceBundle`, so the runtime/kernel interface is
   now first-class on both the Lean and Rust sides even though the final
   implementation-refinement theorem is still open.
3. Completed in the current proof-grade path: trusted-kernel bundles and
   runtime-kernel refinement witnesses now have exactness theorems for
   schedule, public-object universe, resource state, and boundary projections,
   and those proof-grade witness objects are packaged by an explicit Lean
   refinement relation on both the native and imported-JSON sides.
4. Completed in the current proof-grade path: the shell-boundary theorem
   proves that the non-kernel shell refines a public contract over admitted
   public data, and the proof stack now packages the exact schedule /
   public-object / resource / shell facts needed downstream through one
   theorem-facing runtime-kernel boundary interface.
5. Completed for the Rust/static side on April 20, 2026: visibility restrictions, wrapper
   elimination, and probe-time confinement assertions now keep secret-bearing
   runtime structures inside the runtime/kernel boundary; this now includes a
   sealed runtime-phase witness API with probe-checked constructor/accessor
   boundaries rather than raw cross-module event-vector mutation, where the
   public constructor now rejects malformed phase traces up front, plus the
   same explicit API discipline for the exact shell-boundary trace derived from
   that witness, an accessor-only shell-boundary bundle whose witness /
   contract / trace fields are probe-checked to stay non-public, with the
   shell contract now accessor-only and the shell-trace derivation helpers
   confined inside `uo-core`, and accessor-only
   trusted-kernel plus direct runtime-kernel DSL bundle families whose
   proof-facing fields are likewise probe-checked against re-publication, along
   with the full confidential-core bundle family including the shell-boundary
   slot/lowering composites. The post-call `ExecutionTrace` now follows the
   same rule for every proof-bearing runtime payload: seed, kernel witness,
   runtime-phase witness, stored trusted-kernel bundle, controller certificate,
   and ORAM witness snapshots are all accessor-only on the Rust side, with the
   public kernel-witness constructor now checked as well, the derived runtime
   kernel schedule witness likewise sealed behind checked construction plus
   accessor-only reads, and the probe checks both that privacy boundary and
   accessor-only consumer usage. The lower-level runtime-refinement witness now
   also keeps its tail-appending helpers private, so the production runtime
   path cannot mutate a finished witness to append commit/cold-store windows
   outside `uo-core`.
   The intermediate `RuntimeExecutionTraceParts` carrier now also has one
   explicit constructor and one production construction site. The certificate-
   based `RuntimeRefinementWitness` constructors are now internal to `uo-core`
   The trusted-kernel slot bridge now also rejects manifest slot-program
   entrypoint drift by construction rather than exposing it only as a post hoc
   boolean helper.
   rather than a public reassembly surface. On the Lean/imported-JSON side,
   the paper-facing runtime/kernel interface now has both the witness-based
   executable checker, `checkProofGradeRuntimeKernelInterface`, over the same
   runtime witness JSON accepted by `checkProofGradeRuntimeWitness`, and the
   explicit-bundle checker,
   `checkProofGradeRuntimeKernelInterfaceBundle`, over the exported
   `RuntimeKernelInterfaceBundle`. The same audit path,
   `runtime_boundary_validation.json`, is now green on the current tree while
   still rejecting any regression that reintroduces secret-bearing runtime
   work outside the kernel-owned boundary.
6. Completed on April 20, 2026: the remaining runtime-side trust point is now
   frozen explicitly in Lean as
   `PaperMainRuntimeKernelAssumptions`,
   `PaperMainRuntimeKernelBoundary`, `PaperMainPathOramAssumptions`, and
   `PaperMainPathOramEndToEndBoundary`, so the paper route now carries the
   undischarged runtime/kernel honesty gap as a named assumption bundle rather
   than prose.
7. Completed on April 20, 2026: that explicit paper-route runtime bundle is no
   longer only a documentation object. Lean now has
   `ProofGradeSeededRuntimePaperMainBundle`, which discharges
   `PaperMainRuntimeKernelAssumptions` mechanically whenever a seeded
   paper-main bundle already carries proof-grade witness acceptance. The
   executable artifact path now also has a family-level proof-grade runtime
   kernel-interface checker plus an explicit
   `SeededRuntimePaperMainFamilyBundle` checker over seeded path-ORAM witness
   families, so the paper-route runtime/kernel boundary and exact
   public-outcome / boundary-schedule uniformity are rechecked against one
   exported theorem-facing object rather than only inferred witness by witness.
8. Mostly completed on the Rust side: non-kernel secret buffers have been
   aggressively removed or put under wipe discipline; the remaining theorem
   work is to connect that discipline to the final formal model. The
   confidential kernel now also keeps its live slot file and staged
   confidential argument buffer in fixed-size boxed slices rather than
   growable vectors, and the injected Path-ORAM fresh-leaf source now keeps a
   fixed-size tape plus cursor rather than widening staged tapes into a
   growable queue. The fixed-shape confidential array / small-map logical
   buffers, the boxed UO cell ciphertext slot, and the fixed-shape live
   Path-ORAM entry array, live stash, and live position map now likewise live
   in fixed-capacity containers, the path-bucket payload now uses a
   fixed-shape block buffer, and the fixed public-shape Path-ORAM page arrays
   plus boxed ORAM counter slot are now boxed as well, and the long-lived
   committed/shadow object carrier has now been reduced to a boxed fixed-order
   table over the public object universe rather than a generic map, the
   injected fresh-coin plan now likewise uses boxed per-object entries rather
   than a generic map, and the kernel/runtime witness path now finishes the
   full runtime-phase tail inside `kernel.rs` rather than through a post-hoc
   state-side append, so the manifest-bounded working-set story is tighter
   than before even prior to the final refinement theorem. The raw-backend
   `RawMapEntry` ciphertext slot is
   now boxed as well, so the runtime object graph no longer keeps
   secret-bearing ciphertext in growable `Vec<u8>` buffers.

Deliverables:

- one runtime-to-Lean refinement theorem
- one secret-confinement theorem or explicit confinement interface
- one small, auditable Rust kernel boundary that matches the Lean model

Exit gate:

- the paper can honestly say that the real runtime kernel refines the model and
  that secret-dependent work does not escape that kernel boundary

## Work Package 4: Prove Source-To-Kernel Compiler Correctness

Objective: connect the admitted Solidity subset to the kernel DSL and its
public schedule by proof, not only by artifact conformance checking.

Primary files:

- [compiler/uo-solc/src/lib.rs](/home/m285xu/update-oblivious-toolchain/compiler/uo-solc/src/lib.rs)
- [crates/uo-core/src/ir.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/ir.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [crates/uo-core/src/kernel_dsl.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/kernel_dsl.rs)
- [crates/uo-core/src/manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs)
- [crates/uo-core/src/translation_validation.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/translation_validation.rs)
- [proof/lean/UOToolchain/IRSemantics.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSemantics.lean)
- [proof/lean/UOToolchain/CompilerInvariant.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/CompilerInvariant.lean)
- [proof/lean/UOToolchain/ConfidentialFragment.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ConfidentialFragment.lean)
- [proof/lean/UOToolchain/TranslationValidationJson.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/TranslationValidationJson.lean)

Concrete tasks:

1. Define the admitted Solidity subset semantics precisely enough for
   theorem-level compilation claims.
2. Prove correctness of lowering into the UO IR.
3. Prove correctness of confidential-fragment admission and rejection.
4. Prove correctness of lowering into the kernel DSL and its public schedule.
5. Prove that every manifest field used by the theorem is an exact semantic
   consequence of the source program.
6. Keep the direct Lean artifact checker, but demote it from "main trust
   argument" to "executable proof witness for the proven compiler story."

Deliverables:

- one source-to-IR correctness theorem
- one IR-to-kernel correctness theorem
- one exactness theorem for proof-grade manifest fields

Exit gate:

- the paper has a real source-to-kernel theorem for the admitted language

## Work Package 5: Discharge The Concrete Backend Assumptions

Objective: reduce the concrete backend assumption bundle until only genuinely
external cryptographic and deployment assumptions remain.

Primary files:

- [proof/lean/UOToolchain/PathOramLocalPosmapV1.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1.lean)
- [proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean)
- [proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean)
- [proof/lean/UOToolchain/PathOramJACMTheorem.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramJACMTheorem.lean)
- [proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean)
- [proof/lean/UOToolchain/RuntimePaperInstantiation.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimePaperInstantiation.lean)
- [runtime/uo-evm/src/oram.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/oram.rs)
- [runtime/uo-store/src/store.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-store/src/store.rs)
- [runtime/uo-store/src/codec.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-store/src/codec.rs)
- [docs/path-oram-citation-import-plan.md](/home/m285xu/update-oblivious-toolchain/docs/path-oram-citation-import-plan.md)
- [docs/stronger-import-route-feasibility.md](/home/m285xu/update-oblivious-toolchain/docs/stronger-import-route-feasibility.md)

Concrete tasks:

1. Prefer a machine-checked theorem import at the frozen backend interface if a
   suitable external artifact can be imported cleanly.
2. Otherwise build the companion mechanization locally at that exact interface.
3. Discharge `stashOverflowBounded` for the deployed parameter regime.
4. Discharge `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` for the
   concrete cryptographic scheme boundary actually used by the runtime.
5. Prove that the store/codec/serialization layer matches the theorem-side
   storage abstraction.
6. Remove any assumption that survives only because of convenience engineering.

Deliverables:

- one minimized backend assumption bundle
- one explicit provenance route for every remaining backend assumption

Exit gate:

- every remaining backend assumption is concrete, justified, and unavoidable

## Work Package 6: Close The Hostile-Host TEE Theorem

Objective: move from an idealized TEE-storage theorem to a real malicious-host
execution theorem over an explicit observer.

Primary files:

- [proof/lean/UOToolchain/SgxBoundary.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxBoundary.lean)
- [proof/lean/UOToolchain/SgxRelation.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxRelation.lean)
- [proof/lean/UOToolchain/SgxController.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxController.lean)
- [proof/lean/UOToolchain/SgxControllerTrace.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxControllerTrace.lean)
- [proof/lean/UOToolchain/SgxExactProjection.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxExactProjection.lean)
- [proof/lean/UOToolchain/SgxOramProjection.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxOramProjection.lean)
- [proof/lean/UOToolchain/SgxJointProjection.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxJointProjection.lean)
- [proof/lean/UOToolchain/TeeDeployment.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/TeeDeployment.lean)
- [docs/tee-runtime-hardening.md](/home/m285xu/update-oblivious-toolchain/docs/tee-runtime-hardening.md)

Concrete tasks:

1. Freeze the exact hostile-host observer and keep it aligned across docs and
   Lean.
2. Model enclave-boundary calls, persistent I/O, exits, and any admitted
   shared-resource or paging observations.
3. Prove that the real controller/runtime behavior refines that observer.
4. Prove that the sealing/storage path matches the theorem-side persistent
   model.
5. State attestation, rollback, crash, freshness, and patch-level assumptions
   explicitly and minimally.
6. Remove any remaining ambiguity between idealized TEE-storage security and
   malicious-host execution obliviousness.

Deliverables:

- one hostile-host deployment theorem
- one explicit deployment assumption bundle

Exit gate:

- the paper can claim malicious-host security without hiding the observer or
  the assumptions

## Work Package 7: Canonicalize The Proof Architecture And Artifact Story

Objective: make the final proof stack look minimal, inevitable, and easy to
review.

Primary files:

- [proof/lean/UOToolchain.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain.lean)
- [proof/lean/lakefile.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/lakefile.lean)
- [probe/mplus-probe/src/lib.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/lib.rs)
- [probe/mplus-probe/src/main.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/main.rs)
- [scripts/run_validation.sh](/home/m285xu/update-oblivious-toolchain/scripts/run_validation.sh)
- [scripts/run_bridge_validation.sh](/home/m285xu/update-oblivious-toolchain/scripts/run_bridge_validation.sh)

Concrete tasks:

1. Refactor the theorem stack so each layer has one abstraction function and
   one main theorem.
2. Make every proof-grade checker theorem-tight.
3. Remove compatibility shims from the main paper narrative.
4. Add tamper and negative tests for every theorem-facing artifact.
5. Make artifact generation deterministic and reproducible.
6. Report proof-checking cost, artifact size, runtime overhead, TCB size, and
   explicit assumptions.

Deliverables:

- one clean theorem stack
- one reproducible artifact pipeline
- one reviewer-facing proved/assumed/trusted table

Current artifact-side realization: the full probe bundle emits
`reviewer_summary.json` plus `reviewer_summary.md` as the machine-generated
reviewer-facing table over proof/report cost, artifact sizes, runtime
overheads, TCB surface, and explicit assumptions.

Exit gate:

- the paper and artifact tell the same minimal story with no hidden branches

## Critical Path

The shortest path to the strongest result is:

1. Work Package 0: freeze the exact theorem, observer, assumptions, and TCB.
2. Work Package 1: finish shrinking all secret-dependent behavior into the
   tiny kernel.
3. Work Package 2: finish the shared DSL / interpreter route so the compiler,
   runtime, and Lean semantics share one program object.
4. Work Package 3: prove runtime-kernel refinement and secret confinement.
5. Work Package 4: prove source-to-kernel compiler correctness.
6. Work Package 5: discharge or minimize the concrete backend assumptions.
7. Work Package 6: close the hostile-host TEE theorem.
8. Work Package 7: canonicalize the proof architecture and finalize the
   artifact story.

Work Packages 5 and 7 can progress in parallel once the interfaces from Work
Packages 0 through 4 are stable. Work Package 6 should not outrun Work Package
3, because the malicious-host theorem depends on a stable runtime/kernel
refinement story.

## Immediate Execution Queue

If implementation resumes immediately, the next concrete sequence should be:

1. Completed: freeze the flagship theorem, observer, assumption table, and TCB
   table in the paper-facing docs.
2. Completed: complete the confidential-kernel inventory and remove any
   remaining secret-bearing helpers outside the kernel boundary.
3. Completed: make the kernel DSL the sole canonical representation of
   admitted confidential work across compiler, runtime, and Lean.
4. Completed: eliminate proof-grade schedule reconstruction paths that
   duplicate an already available DSL program.
5. Completed: add static confinement guardrails so only the kernel can own or
   manipulate secret-bearing runtime structures.
6. Active next item: discharge `PaperMainRuntimeKernelAssumptions` by proving
   runtime-kernel refinement for the shared DSL/interpreter route.
7. Completed: prove that the non-kernel shell is public-only and package that
   shell contract together with the exact proof-grade boundary facts needed by
   the confidential-core argument.
8. Remaining after 6-7: prove source-to-kernel compiler correctness.
9. Remaining after 8: minimize `PathOramLocalPosmapV1SecurityAssumptions`.
10. Remaining after 9: close the hostile-host TEE theorem over the frozen
    observer.

## Validation Gates

Each milestone should keep the proof-grade path live. The minimum recurring
validation set is:

```bash
cargo test -p uo-solc
cargo test -p uo-check
cargo test -p uo-evm
cargo check -p mplus-probe
cd proof/lean && lake build \
  checkProofGradeTranslationArtifacts \
  checkProofGradeRuntimeKernelWitness \
  checkProofGradeRuntimeKernelRefinementWitness \
  checkProofGradeRuntimeWitness \
  checkProofGradeRuntimeKernelInterface \
  checkProofGradeRuntimeKernelInterfaceBundle \
  checkProofGradeRuntimeShellBoundary \
  checkProofGradeRuntimeShellBoundarySlot \
  checkProofGradeRuntimeShellBoundaryLowering \
  checkProofGradeRuntimeConfidentialCore \
  checkProofGradeRuntimeConfidentialCoreSlot \
  checkProofGradeRuntimeConfidentialCoreShellBoundarySlot \
  checkProofGradeRuntimeConfidentialCoreLowering \
  checkProofGradeRuntimeConfidentialCoreShellBoundaryLowering \
  checkProofGradeRuntimeTrustedKernel
cargo run -q -p mplus-probe -- --only static-checks --out-dir /tmp/uo-static
cargo run -q -p mplus-probe -- --only shell-boundary-validation --out-dir /tmp/uo-shell-boundary
cargo run -q -p mplus-probe -- --only shell-boundary-slot-validation --out-dir /tmp/uo-shell-boundary-slot
cargo run -q -p mplus-probe -- --only shell-boundary-lowering-validation --out-dir /tmp/uo-shell-boundary-lowering
cargo run -q -p mplus-probe -- --only confidential-core-validation --out-dir /tmp/uo-confidential-core
cargo run -q -p mplus-probe -- --only confidential-core-shell-boundary-slot-validation --out-dir /tmp/uo-confidential-core-shell-boundary-slot
cargo run -q -p mplus-probe -- --only confidential-core-lowering-validation --out-dir /tmp/uo-confidential-core-lowering
cargo run -q -p mplus-probe -- --only confidential-core-shell-boundary-lowering-validation --out-dir /tmp/uo-confidential-core-shell-boundary-lowering
cargo run -q -p mplus-probe -- --only kernel-interface-validation --out-dir /tmp/uo-kernel-interface
cargo run -q -p mplus-probe -- --only kernel-validation --out-dir /tmp/uo-kernel
cargo run -q -p mplus-probe -- --only trusted-kernel-validation --out-dir /tmp/uo-tk
cargo run -q -p mplus-probe -- --only tamper-validation --out-dir /tmp/uo-tamper
./scripts/check_probe_reproducibility.sh --only static-checks
```

Any phase that broadens the theorem, observer, or TCB must update the paper
docs and the Lean interface in the same change set.
