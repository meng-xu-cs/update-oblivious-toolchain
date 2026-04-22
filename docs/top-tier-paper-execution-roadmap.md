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
  point as explicit objects: the lower-level projection bundles
  `PaperMainRuntimeKernelAssumptions` and
  `PaperMainRuntimeKernelSlotAssumptions`, the checked boundaries
  `PaperMainRuntimeKernelBoundary` and
  `PaperMainRuntimeKernelSlotBoundary`, and the top-level paper routes
  `PaperMainPathOramAssumptions`,
  `PaperMainPathOramEndToEndBoundary`,
  `PaperMainPathOramSlotAssumptions`, and
  `PaperMainPathOramSlotEndToEndBoundary`; the top-level paper assumptions now
  carry the minimal runtime boundary facts directly, while the stronger
  proof-grade witness-acceptance bundles remain available to discharge those
  boundaries mechanically
- the runtime already enforces the admitted public kernel schedule online for
  confidential entrypoints, and that online check plus emitted kernel-step
  tracking now route through shared `uo-core` execution/schedule trackers
  rather than runtime-local cursors or bounded journals

The repository has now closed the runtime-side proof/interface gap for the
chosen paper route. In addition to the exact checked
`RuntimeKernelRefinementBoundary`, `RuntimeKernelInterfaceSlotBoundary`, and
`RuntimeKernelConfinementBoundary` objects, it now exports and checks a
source-backed `RuntimeImplementationInterface` and
`RuntimeImplementationConfinementBoundary` over the actual `uo-evm` runtime
modules, with dedicated positive reports and dedicated tamper rejections for
representative secret-escape drift. The remaining gaps are:

- there is not yet a source-to-kernel compiler correctness theorem for the
  admitted Solidity subset
- the concrete `PathOramLocalPosmapV1SecurityAssumptions` bundle is still only
  partially discharged
- the SGX/TEE deployment story is still weaker than a full malicious-host
  execution theorem
- a deeper semantics-of-Rust refinement below the checked source-backed
  runtime interface would still be scientifically stronger, but it is no
  longer part of the current paper-route honesty gap

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

Status: completed on April 21, 2026 under the checked proof/interface route.
The runtime-boundary confinement audit and the stronger
confidential-core/kernel-interface/slot composite validation are now green,
the pre-witness confidential-core/kernel-finish/slot composite validation is
now green,
the imported/native shell-boundary bridge is now green, and the canonical
fresh-coin pair-instantiation route now also carries proof-grade
runtime-kernel boundary facts and the direct runtime/kernel interface theorem
through the concrete hidden-seed slices; the imported kernel-interface family
and the imported paper-main family / slot-family artifacts now also project
directly to the native paper-route local runtime boundaries and to the native
`RuntimeProofGradeKernelInterface` surface, and those paper-route boundaries
now also project mechanically to the native public shell-boundary interface,
the shared confidential proof-family artifact now also has dedicated
benchmark-backed family-assurance and slot-assurance checker routes plus
matching runtime-boundary anti-drift audits and tamper rejections,
the Rust proof-bearing shell-boundary / kernel-interface bundle family is now
move-only rather than `Clone`, and the runtime kernel finalizer now routes
through one shared `uo-core` `RuntimeKernelFinishSnapshot` that consumes the
allocator telemetry snapshot, execution tracker, refinement tracker, and
public-object universe together before materializing the emitted witness pair;
the exported trusted-kernel bundle and the smaller exported kernel-finish
bundle are now move-only on the Rust side as well, so theorem-bearing runtime
payloads no longer keep a generic clone path open once the checked export
surface is available, and the direct confidential-core witness / slot /
lowering bundles are now move-only too, so the remaining public theorem
artifacts are consistently accessor-driven rather than clone-friendly,
the live runtime-side coordination for that boundary now also routes through
one shared `uo-core` `RuntimeKernelBoundaryTracker` rather than `kernel.rs`
hand-assembling the public-object bootstrap, admitted-schedule binding,
runtime-phase tracking, and finish-snapshot handoff itself, the live
confidential slot-file / argument-staging path now also routes through one
shared `uo-core` slot-call executor rather than a runtime-local slot-state
adapter in `kernel.rs`, and `state.rs` now loads admitted confidential slot
programs plus the matching public runtime budgets/object universe through one
shared `uo-core`
`EntrypointManifest::runtime_confidential_entrypoint_plan(...)` helper rather
than revalidating manifest-vs-slot-program agreement or repacking the runtime
budget facts locally, with that public object universe now also staying on
boxed exact-size slices from the committed object table through the shared
manifest plan and into the public shell/bootstrap path rather than widening
back into a temporary `Vec<u32>` at the runtime boundary, while the
theorem-facing execution-trace assembly now also routes through one shared
`uo-core` `ExecutionTrace::from_runtime_finalization_input(...)` path so
`theorem.rs` no longer reconstructs runtime ORAM objects, reruns the
confidential proof-family check piecemeal, or materializes trusted-kernel
bundles through a separate local trace-parts path, and the public
controller-observer path now also routes through one shared `uo-core`
`RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(...)`
interface plus shared `BoundaryEvent`, `OutputShape`, and
`PublicOutcomeTrace` constructors, so `controller.rs` no longer hand-assembles
the theorem-facing controller shape or theorem trace on the production path,
and the traced-call runtime/theorem handoff now also routes through shared
`uo-core` `CommittedRuntimeWitnessSnapshot`, `TracedRuntimeCallStart`,
`TracedRuntimeCallOutcome`, `RuntimeCallOutcome`,
`FinalizedRuntimeCallTraceParts`, and `TracedRuntimeCallWitnessState`
wrappers rather than runtime-local secret-bearing handoff structs for the
finalized witness bundle, and `state.rs` now stages the hidden before/after
ORAM witness slices through the shared `uo-core`
`CommittedRuntimeWitnessSnapshotBuilder` rather than hand-packing those
exact-size boxed buffers locally, and the runtime-side artifact boundary is now
packaged through the exact `RuntimeKernelRefinementBoundary`, the shared
`RuntimeKernelInterfaceSlotBoundary`, and the explicit
`RuntimeKernelConfinementBoundary`, all backed by direct Lean checkers plus
dedicated probe reports, including first-class
`paper_main_family_boundary_validation.json` and
`paper_main_slot_boundary_validation.json` outputs. The real-runtime
proof/interface route is now closed by the source-backed
`RuntimeImplementationInterface` and
`RuntimeImplementationConfinementBoundary` checkers, together with dedicated
`runtime_implementation_interface_validation.json`,
`runtime_implementation_confinement_boundary_validation.json`, and matching
tamper-rejection cases for representative engine-level confidential-bypass
drift.

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
2. Completed on April 21, 2026 under the checked proof/interface route: prove
   witness honesty by construction, not merely by post hoc checking. The
   runtime theorem bridge
   no longer hand-assembles controller/hidden/trusted-kernel certificates; it
   now asks `ExecutionTrace` to materialize the trusted-kernel bundle from the
   trace's own reconstructed state, while the lower-level certificate
   constructors stay internal to `uo-core` and the trusted-kernel proof object
   family is now accessor-only on the Rust side rather than a public-field bag.
   The runtime kernel now also emits the complete runtime-phase witness tail
   itself, with the live journal and the witness validator now sharing the same
   phase-transition function for commit/cold-store progression before the
   witness is materialized, and that live runtime-phase journal now routes
   through a shared `uo-core` refinement tracker rather than a runtime-local
   phase helper, so the old tail-appending witness mutators are no longer part
   of the production API surface. The emitted kernel-step trace now likewise
   routes through a shared `uo-core` execution tracker rather than a local
   bounded journal in `kernel.rs`, and the final `RuntimeKernelWitness`
   assembly now also routes through a `uo-core` telemetry/execution helper,
   with `uo-allocator` handing that helper a consumed `finish()` snapshot
   rather than `kernel.rs` field-packing allocator state by hand. The final
   witness pair is now emitted through one shared `RuntimeKernelFinishSnapshot`
   in `uo-core`, so `kernel.rs` no longer separately appends the cold-store
   tail and then reconstructs the theorem-facing witnesses itself; allocator
   kernel-op tracking is now count-only and its stale public telemetry getters
   have been removed from the production API. The production theorem finalizer
   now likewise routes through one shared
   `ExecutionTrace::from_runtime_finalization_input(...)` constructor in
   `uo-core`, so `theorem.rs` no longer calls
   `RuntimeExecutionTraceParts::new(...)`,
   `ExecutionTrace::from_runtime_trace_parts(...)`, or
   `ExecutionTrace::materialize_runtime_trusted_kernel_bundle(...)` directly
   on the production path, and the admitted runtime-ORAM object reconstruction
   plus the confidential proof-family recheck now also stay inside `uo-core`.
   The public controller-observer path has now been tightened in the same
   style: `controller.rs` records boundary events and controller budgets, but
   the validated public observer is now rebuilt through
   `RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(...)`
   plus the shared `SgxControllerShapeTrace::from_runtime_observer_parts(...)`
   / `RuntimeControllerCertificate::from_observed_oram_accesses(...)` /
   `TheoremTrace` projection path in `uo-core`, so the production runtime no
   longer keeps a second local controller-certificate, theorem-facing
   controller-shape, or theorem-trace assembly routine.
   The traced-call theorem handoff now follows the same pattern as well:
   `RuntimeCallOutcome`, the finalized hidden before/after witness carrier,
   the shared public call-trace bundle, and the last step that flattens those
   secret/public handoffs into
   `RuntimeExecutionTraceFinalizationInput::new(...)` now all live in shared
   `uo-core` wrapper types, so `theorem.rs` no longer depends on a
   runtime-local finalized witness-state struct, a runtime-local public
   trace bundle, or a raw state-local tuple for that last handoff.
   The
   production trace finalizer
   now also re-derives and validates the admitted confidential proof-bearing
   bundle family online for confidential calls: direct kernel DSL / slot /
   lowering bundles, the trusted-kernel slot bundle, and the confidential-core
   direct / slot / kernel-finish-slot / kernel-interface-slot / lowering /
   shell-boundary slot / shell-boundary lowering bundle family all have to
   agree with the admitted artifact before a trace is returned. That recheck
   now routes through one shared `uo-core` `RuntimeConfidentialProofBundleFamily`,
   so `theorem.rs` no longer enumerates those proof-bearing bundle constructors
   one by one. The
   confidential theorem finalizer now also re-derives a
   single-trace seeded witness, retags it canonically, and rebuilds the
   explicit `SeededRuntimePaperMainFamilyBundle` online before a confidential
   trace returns, and it now also rebuilds the stronger
   `SeededRuntimePaperMainSlotFamilyBundle` against the admitted manifest slot
   program before the trace is returned, so both paper-route theorem objects
   are now checked in the production runtime path rather than only by the
   external probe/checker route. The Rust side now also packages the
   paper-facing shell-boundary / expected-step / expected-public-object /
   expected-schedule facts as an explicit `RuntimeKernelInterfaceBundle`, so
   the runtime/kernel interface is now first-class on both the Lean and Rust
   sides even though the final implementation-refinement theorem is still
   open. The frozen paper route now phrases
   `PaperMainRuntimeKernelBoundary` over that explicit kernel-interface bundle
   object, and the stronger shared-slot route now phrases
   `PaperMainRuntimeKernelSlotBoundary` as "one fixed confidential slot
   program plus one valid explicit runtime kernel-interface bundle" rather
   than only an existential shell-refinement fact.
   The imported shared proof-family artifact now also projects directly to the
   exact `RuntimeKernelRefinementBoundary`, to the explicit
   `RuntimeKernelConfinementBoundary`, to the paper-main family runtime
   assurance, and to the stronger paper-main slot-family assurance, and the
   probe now exercises that whole shared family through a dedicated
   `confidential_proof_family_validation.json` report backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamily`, plus the exact
   `confidential_proof_family_assurance_validation.json` route backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamilyAssurance`, plus the
   exact
   `confidential_proof_family_boundary_validation.json` route backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamilyBoundary`, plus the
   exact
   `confidential_proof_family_kernel_interface_validation.json` route backed
   by
   `checkProofGradeRuntimeConfidentialProofBundleFamilyKernelInterface`, plus
   the exact
   `confidential_proof_family_slot_assurance_validation.json` route backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamilySlotAssurance`, plus
   the exact
   `confidential_proof_family_slot_boundary_validation.json` route backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamilySlotBoundary`, plus the
   exact
   `confidential_proof_family_finish_slot_boundary_validation.json` route
   backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamilyFinishSlotBoundary`,
   plus the exact
   `confidential_proof_family_refinement_boundary_validation.json` route
   backed by
   `checkProofGradeRuntimeConfidentialProofBundleFamilyRefinementBoundary`.
   The final real-runtime bridge is now explicit as well: the probe strips
   `#[cfg(test)]` items from the live `uo-evm` runtime source files, materializes
   one source-backed `RuntimeImplementationInterface`, pairs that interface with
   the exact emitted `RuntimeKernelInterfaceBundle`, and feeds both to
   `checkProofGradeRuntimeImplementationConfinementBoundary`. Lean then checks
   both that the non-kernel runtime modules stay on the admitted public bridge
   and that the resulting kernel-interface bundle still projects to the native
   `RuntimeKernelConfinementBoundary`. `tamper_validation.json` now also
   rejects representative engine-level confidential-bypass drift for both the
   standalone implementation-interface checker and the combined
   implementation-confinement-boundary checker.
3. Completed in the current proof-grade path: trusted-kernel bundles and
   runtime-kernel refinement witnesses now have exactness theorems for
   schedule, public-object universe, resource state, and boundary projections,
   and those proof-grade witness objects are packaged by an explicit Lean
   refinement relation on both the native and imported-JSON sides.
4. Completed in the current proof-grade path: the shell-boundary theorem
   proves that the non-kernel shell refines a public contract over admitted
   public data, and the proof stack now packages the exact schedule /
   public-object / resource / shell facts needed downstream through one
   theorem-facing runtime-kernel boundary interface. The explicit
   `RuntimeKernelInterfaceBundle` route now also provably subsumes the older
   `RuntimeProofGradeKernelBoundaryFacts` /
   `ImportedRuntimeProofGradeKernelBoundaryFacts` surfaces on both the native
   and imported-JSON sides, so downstream theorem routes can normalize on the
   bundle object without reopening the raw witness shape.
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
   with the full confidential-core bundle family including the new
   `RuntimeConfidentialCoreKernelInterfaceSlotBundle` and the older
   shell-boundary slot/lowering composites. Those checked shell-boundary and
   kernel-interface composites now expose only the checked boundary bundle plus
   the matched DSL program on the Rust side, rather than re-exporting the raw
   `RuntimeRefinementWitness` again, and the smaller confidential-core
   kernel-finish-slot composite now likewise exposes only the checked
   shell-boundary reconstruction route rather than handing the raw stored
   finish bundle back out. The post-call `ExecutionTrace` now follows the
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
   `RuntimeKernelInterfaceBundle`, plus the exact-boundary checker
   `checkProofGradeRuntimeKernelRefinementBoundary`, which validates that same
   exported bundle at the more exact `RuntimeKernelRefinementBoundary`
   interface rather than stopping at bundle validity alone. The exported shell
   contract / shell trace / kernel-interface bundle now also keep their public
   schedules, event summaries, and expected-step lists in boxed fixed-shape
   buffers rather than reopening those theorem-facing surfaces as growable
   vectors, and the shared `RuntimeKernelScheduleWitness` under those exported
   interfaces now keeps both opcodes and step lists boxed as well. The
   theorem-facing `RuntimeKernelWitness` now also keeps its resource trace,
   emitted/expected kernel-step lists, and emitted/expected public-object
   schedules boxed. The controller/public-observer side now follows the same
   discipline: `PublicOutcomeTrace.public_args`,
   `SgxControllerShapeTrace.controller_phase_order`,
   `SgxControllerShapeTrace.page_trace_regions`,
   `SgxControllerShapeTrace.workset_regions`, and the derived
   `NormalizedMicroTrace` page/exit/shared-resource patterns are all boxed, and
   the theorem-facing public trace path now keeps opcode/logical/physical
   slices boxed end-to-end across `RuntimeCallOutcome`,
   `RuntimePublicCallTraceBundle`,
   `RuntimeExecutionTraceFinalizationInput`, `RuntimeExecutionTraceParts`,
   `RefinementTrace`, and the exported `ExecutionTrace`. That direct
   runtime-witness checker path now also projects mechanically to the exact
   singleton `PaperMainRuntimeKernelBoundaryAt` paper boundary through the
   generic `RuntimeProofGradeKernelInterfaceBundle` interface, so the frozen
   paper route is tied directly to the same accepted runtime witness JSON and
   not only to the later seeded-family artifacts, and
   `kernel_interface_singleton_boundary_validation.json` now benchmark-checks
   that exact witness-to-singleton-boundary route directly rather than only
   exposing it through the generic witness checker binary, while
   `kernel_interface_confinement_boundary_validation.json` now benchmark-checks
   the matching witness-to-`RuntimeKernelConfinementBoundary` route directly
   through `checkProofGradeRuntimeKernelInterfaceConfinementBoundary` rather
   than only through the exported-bundle confinement checker. The stronger
   confidential-core composite
   route now also has
   `checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot`, over the
   exported `RuntimeConfidentialCoreKernelInterfaceSlotBundle`, so one
   accepted runtime witness, one valid explicit runtime kernel-interface
   bundle, and one fixed confidential slot program are rechecked together at
   the artifact boundary. The new smaller pre-witness route now also has
   `checkProofGradeRuntimeConfidentialCoreKernelFinishSlot`, over the
   exported `RuntimeConfidentialCoreKernelFinishSlotBundle`, so one exact
   `RuntimeKernelFinishBundle` plus one fixed confidential slot program are
   rechecked together directly at the finish-boundary interface before the
   larger runtime witness is reintroduced. The same audit path,
   `runtime_boundary_validation.json`, is now green on the current tree while
   still rejecting any regression that reintroduces secret-bearing runtime
   work outside the kernel-owned boundary, `kernel_refinement_boundary_validation.json`
   now benchmark-checks the exact imported `RuntimeKernelRefinementBoundary`
   route directly, `kernel_confinement_boundary_validation.json` now
   benchmark-checks the exact imported `RuntimeKernelConfinementBoundary`
   route from that same exported `RuntimeKernelInterfaceBundle` directly,
   `kernel_slot_boundary_validation.json` now benchmark-checks
   the exact imported singleton `PaperMainRuntimeKernelSlotBoundaryAt` route
   directly, `confidential_proof_family_boundary_validation.json` now
   benchmark-checks the exact imported singleton
   `PaperMainRuntimeKernelBoundaryAt` route for the full shared confidential
   proof-family artifact directly while also compiling that same imported
   shared family to the explicit `RuntimeKernelConfinementBoundary`,
   `confidential_proof_family_kernel_interface_validation.json` now
   benchmark-checks the exact native `RuntimeProofGradeKernelInterface` route
   for that same shared confidential proof-family artifact directly,
   the stronger runtime-witness/kernel-interface/slot route now also
   collapses directly to the exact native `RuntimeKernelFinishSlotBoundary`,
   and
   `confidential_core_kernel_interface_slot_finish_boundary_validation.json`
   benchmark-checks that exact imported shared bundle against the same
   finish-slot boundary so the runtime-witness route and the smaller
   pre-witness finish route meet on one central theorem object,
   `confidential_core_kernel_finish_slot_validation.json` now
   benchmark-checks the exact imported pre-witness
   finish-boundary-plus-slot route directly while also proving that the same
   tiny imported bundle reconstructs one valid native runtime-kernel
   interface bundle, one valid native shell-boundary bundle, and one explicit
   native `RuntimeKernelConfinementBoundary` with the exact fixed slot
   schedule. That smaller imported route now does so by delegating to the native
   `RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle_valid` and
   `RuntimeKernelFinishSlotBoundary.shellBoundaryBundle_valid` theorems plus
   the shared `RuntimeKernelFinishSlotBoundary.projects_to_runtimeKernelConfinementBoundary`
   theorem, so the imported and native sides meet on the same central
   finish-slot boundary object rather than on checker-specific reconstruction
   logic, and
   `tamper_validation.json` now also rejects both witness-fed runtime-kernel
   confinement-route drift inside the dedicated
   `checkProofGradeRuntimeKernelInterfaceConfinementBoundary` checker and
   runtime-kernel boundary drift inside that exact boundary checker, exact
   shared-family paper-main boundary drift inside the dedicated family-level
   boundary checker, exact shared-family runtime-kernel interface drift inside
   the dedicated family-level interface checker, exact shared-family paper-main
   assurance public-outcome drift inside the dedicated assurance checker, exact
   shared-family slot-assurance entrypoint drift inside the
   dedicated slot-assurance checker, exact slot-boundary drift inside the
   dedicated slot-boundary checker, both slot-program drift and finish-boundary
   public-object drift inside the new pre-witness finish-slot checker,
   kernel-finish slot-program drift inside the shared confidential proof
   family, and slot-program drift inside that stronger confidential-core/
   kernel-interface composite.
6. Completed on April 20, 2026, and tightened further on April 20, 2026: the
   remaining runtime-side trust point is now frozen explicitly in Lean as the
   checked boundaries `PaperMainRuntimeKernelBoundary` and
   `PaperMainRuntimeKernelSlotBoundary`, and as the paper-facing bundles
   `PaperMainPathOramAssumptions`,
   `PaperMainPathOramEndToEndBoundary`,
   `PaperMainPathOramSlotAssumptions`,
   `PaperMainPathOramSlotAssurance`, and
   `PaperMainPathOramSlotEndToEndBoundary`. The lower-level projection bundles
   `PaperMainRuntimeKernelAssumptions` and
   `PaperMainRuntimeKernelSlotAssumptions` remain in Lean, but the top-level
   paper assumptions now carry the minimal runtime boundary facts directly
   rather than carrying stronger witness-acceptance claims and projecting down
   later.
7. Completed on April 20, 2026: that explicit paper-route runtime bundle is no
   longer only a documentation object. Lean now has
   `ProofGradeSeededRuntimePaperMainBundle`, which discharges
   the paper-route runtime boundary mechanically whenever a seeded paper-main
   bundle already carries proof-grade witness acceptance, and it now also has
   the stronger `ProofGradeSeededRuntimePaperMainSlotBundle` route for the
   shared slot-DSL boundary whenever the family is paired with the exact
   confidential slot program. The executable artifact path now also has a
   family-level proof-grade runtime kernel-interface checker plus explicit
   `SeededRuntimePaperMainFamilyBundle` and
   `SeededRuntimePaperMainSlotFamilyBundle` checkers over seeded path-ORAM
   witness families, plus the dedicated exact
   `checkProofGradeRuntimePaperMainFamilyBoundary` and
   `checkProofGradeRuntimePaperMainSlotBoundary` routes over those exported
   seeded bundles; those dedicated boundary checkers now also compile the
   imported family / slot-family routes to valid native shell-boundary bundles
   and to the explicit `RuntimeKernelConfinementBoundary`. The runtime now also
   exposes canonical single-seed
   paper-main family and slot-family artifacts through shared `ExecutionTrace`
   constructors and direct `uo-evm` output formats, and the probe now runs
   both the positive acceptance path and tamper rejection cases for the
   slot-family bundle, covering both shared slot-program entrypoint drift and
   slot-program body drift while the seeded family stays fixed, and it now
   also rejects exported paper-main family public-outcome drift plus exported
   paper-main slot-boundary entrypoint drift through those dedicated boundary
   checkers, so the paper-route runtime/kernel boundary and exact public-outcome /
   boundary-schedule / shared-slot-program facts are rechecked against
   exported theorem-facing objects rather than only inferred witness by
   witness. On the imported Lean side, the paper-main family artifact projects
   to `importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_family_assurance`
   and directly to `PaperMainRuntimeKernelBoundaryAt`, the imported
   kernel-interface family route now also projects those accepted family
   artifacts directly both to per-witness
   `ImportedRuntimeProofGradeKernelBoundaryFacts` and to
   `PaperMainRuntimeKernelBoundaryAt`, the stronger slot-family artifact
   projects to
   `importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_family_slot_assurance`
   and directly to `PaperMainRuntimeKernelSlotBoundaryAt` /
   `PaperMainRuntimeKernelBoundaryAt`, and the paper theorem route now also projects both
   `PaperMainRuntimeKernelBoundary` and
   `PaperMainRuntimeKernelSlotBoundary` back down to the older
   `RuntimeProofGradeKernelBoundaryFacts` surface mechanically. The probe now
   pins those projection theorems together with the stronger
   kernel-interface-slot theorem route as part of the production anti-drift
   audit.
   The canonical fresh-coin instantiation path is now also tightened further:
   `RuntimePaperInstantiation.lean` packages proof-grade kernel-interface
   bundles through `ProofGradeConcreteRuntimePathOramConfigSlice`,
   `ProofGradeConcreteRuntimePathOramPairSlice`, and
   `ConcreteRuntimePathOramProofGradePairBoundary`, so the concrete pair route
   now carries both the public ORAM theorem boundary and the per-side
   runtime-kernel boundary facts, the direct
   `RuntimeProofGradeKernelInterface` theorem, and the local paper-route
   `PaperMainRuntimeKernelBoundaryAt` interface rather than dropping the
   runtime side at the hidden-seed quotient step. The paper theorem route now
   also has the matching stronger native concrete slot route:
   `ProofGradeConcreteRuntimePathOramConfigSlotSlice` packages one fixed
   confidential slot program together with the concrete proof-grade runtime
   family for one public ORAM configuration, and it projects directly both to
   `PaperMainRuntimeKernelSlotBoundaryAt`,
   to the new witness-free shared `RuntimeKernelInterfaceSlotBoundary`, and to
   `RuntimeKernelConfinementBoundary` without detouring back through imported
   JSON artifacts. The concrete pair
   route now has the matching stronger slot object as well:
   `ProofGradeConcreteRuntimePathOramPairSlotSlice` and
   `ConcreteRuntimePathOramProofGradeSlotPairBoundary` keep the paired concrete
   ORAM theorem boundary together with the per-side native slot boundary,
   slot-interface-boundary, and confinement-boundary objects. The paper theorem route now
   also exposes the matching per-configuration interfaces
   `PaperMainRuntimeKernelBoundaryAt` and
   `PaperMainRuntimeKernelSlotBoundaryAt`, and those paper-route interfaces
   now project directly both to the native runtime/kernel interface theorem,
   to the shared explicit `RuntimeKernelInterfaceSlotBoundary`, and to the
   explicit `RuntimeKernelConfinementBoundary` plus a valid native
   shell-boundary bundle, so the concrete proof objects and the final
   bundle-level runtime boundary now meet on one explicit interface.
8. Completed on April 21, 2026 under the checked proof/interface route:
   non-kernel secret buffers have been aggressively removed or put under wipe
   discipline, and that discipline is now tied to the formal runtime boundary
   through the checked source-backed implementation interface. The
   confidential kernel now also routes its live slot file and staged
   confidential argument buffer through an engine-boxed traced-call slice and
   then a once-boxed shared `uo-core` wrapper
   backed by fixed-size boxed slices rather than growable vectors, and the shared
   `uo-core` slot-call executor now owns confidential-argument staging plus
   live slot-word accounting so `runtime/uo-evm/src/kernel.rs` no longer keeps
   a runtime-local slot-state adapter around that shared state; its shared
   `keccak256` evaluator now also stages confidential hash parts through an
   exact-size boxed buffer rather than a growable `Vec<Value>` and wipes each
   hashed part after use, while the recursive runtime `Value` representation
   now also keeps both struct fields and array elements in boxed fixed-size
   buffers rather than growable `Vec` carriers, exposes an exact-size boxed
   canonical-byte helper rather than `canonical_bytes().into_boxed_slice()`
   caller-side bouncing, and the live hash, fresh-coin install, boxed
   shadow-entry commit, and Path-ORAM position-map rewrite paths now also
   iterate or preserve those boxed carriers directly rather than bouncing
   them through temporary `Vec` wrappers on the confidential path, and the injected
   Path-ORAM fresh-leaf source now keeps a
   fixed-size tape plus cursor rather than widening staged tapes into a
   growable queue. The fixed-shape confidential array / small-map logical
   buffers, the boxed UO cell ciphertext slot, and the fixed-shape live
   Path-ORAM entry array, live stash, and live position map now likewise live
   in fixed-capacity containers, the path-bucket payload now uses a
   fixed-shape block buffer, and the fixed public-shape Path-ORAM page arrays
   plus boxed ORAM counter slot are now boxed as well, and the long-lived
   committed/shadow object carrier has now been reduced to a boxed fixed-order
   table over the public object universe rather than a generic map, the
   remaining confidential object-table rebuilds in `state.rs` now also route
   through one exact-size boxed builder rather than temporary growable
   `Vec<RuntimeObjectEntry>` staging, and the hidden committed-state ORAM
   witness snapshot now uses that same exact-size builder discipline keyed by
   the public Path-ORAM object count, the
   injected fresh-coin plan now likewise uses boxed per-object entries rather
   than a generic map, and the kernel/runtime witness path now finishes the
   emitted kernel witness plus runtime-phase witness through one shared
   `uo-core` `RuntimeKernelFinishSnapshot` rather than through split
   `kernel.rs` assembly or a post-hoc state-side append. That finish boundary
   has now been tightened again: `uo-evm` now carries only the
   `RuntimeKernelFinishBundle` across the runtime/theorem handoff, with
   `RuntimeKernel::finish` emitting that bundle through the shared
   `RuntimeKernelFinishSnapshot::into_finish_bundle` path rather than handing
   the theorem bridge a separate raw witness pair. `RuntimeExecutionTraceParts::new`
   now validates any supplied kernel witness / runtime-phase witness against
   the finish bundle and rejects finish-bundle drift immediately, but it no
   longer repopulates that raw pair on the production path. As a result,
   confidential `ExecutionTrace` serialization now omits the redundant
   `runtime_kernel_witness` and `runtime_kernel_refinement_witness` keys
   entirely when the stored finish bundle is present, and
   `runtime_boundary_validation.json` now probe-checks that serialized omission,
   while the exact exported finish-bundle accessor plus the exact witness and
   trusted-kernel/refinement projections reconstruct from that finish bundle on
   demand. The raw
   `RuntimeKernelFinishBundle` still does not expose public witness-reconstruction helpers, and the already
   artifact-checked `RuntimeConfidentialCoreKernelFinishSlotBundle` now also
   exports only the checked shell-boundary reconstruction route rather than a
   raw witness-pair helper, so the
   manifest-bounded working-set story is tighter than before even prior to the
   final refinement theorem. The post-call proof-bearing `ExecutionTrace`
   surface has now tightened again as well: the raw stored trusted-kernel
   bundle and controller-certificate accessors are gone, the CLI/kernel-finish
   path now exports only the checked `exact_runtime_kernel_finish_bundle()`
   route, and the old raw ORAM object / leaf / position-map / after-counter
   accessors plus the stray raw `ExecutionTrace::refinement_trace()` getter
   have been removed from the public trace API entirely. Only the
   theorem-facing public ORAM access-counter map needed by the canonical
   fresh-coin / pair instantiation route remains exported directly from
   `ExecutionTrace`, and `runtime_boundary_validation.json` now pins that
   smaller public trace surface. The post-call
   hidden ORAM witness handoff and the proof-facing `ExecutionTrace` runtime
   witness slices now also stay in boxed fixed-size buffers rather than
  widening back into growable vectors, and the public opcode/logical/physical
  trace slices now stay boxed as well all the way from `RuntimeCallOutcome`
  through `ExecutionTrace` / `RefinementTrace`. The theorem-facing seeded witness
  families, paper-main family bundles, canonical fresh-coin families, and the
  extracted fresh-coin scaffold/value accessors now also keep their fixed-shape
  schedules and witness lists boxed instead of reopening them as growable
  `Vec` carriers. The shared confidential-kernel schedule layer now follows
  the same rule as well: `ConfidentialKernelProgram::expected_runtime_steps`,
  `ConfidentialKernelSlotProgram::expected_runtime_steps`, and the lower
  expression/statement step projections now return boxed exact-size step
  buffers, while `RuntimeKernelFinishBundle::completed_runtime_phase_events`
  and `RuntimeKernelRefinementWitness::from_events` meet on boxed refinement
  event buffers instead of reopening the finish/refinement boundary through
  temporary `Vec<RuntimeKernelRefinementEventWitness>` carriers. The runtime's
  live public-object universe handoff now follows that same discipline too:
  `RuntimeObjectTable::object_ids()`,
  `ContractRuntime::public_object_ids()`, the shared confidential-entrypoint
  plan, and the public shell/bootstrap path all stay on boxed exact-size
  object-id slices instead of temporary `Vec<u32>` carriers. That boxing
  discipline now also reaches the deeper
  theorem-facing certificates and witnesses in
  `uo-core`: the runtime kernel-refinement event journal, controller
  certificate observed ORAM-access list, controller-observer boundary
   schedule, hidden Path-ORAM certificate buffers, `TheoremTrace`
   boundary schedule, and `RuntimeRefinementWitness` boundary/hidden buffers
   all stay boxed, and `runtime_boundary_validation.json` now pins those
   representation choices explicitly alongside the older `ExecutionTrace` /
   `RuntimeExecutionTraceParts` checks. The remaining object-operation and
   commit bookkeeping in `runtime/uo-evm/src/kernel.rs` now also routes
   through one private shared shadow-state interface rather than duplicated
   public-vs-confidential helper bodies, and the live public-object bootstrap /
   admitted-schedule / runtime-phase / finish-snapshot bookkeeping now also
   routes through one shared `uo-core` `RuntimeKernelBoundaryTracker` rather
   than dual tracker coordination in `kernel.rs`, which further shrinks the
   bespoke Rust kernel surface that still needs a refinement argument. Each emitted
   Path-ORAM position-map
   witness now stores its leaf array in a boxed fixed-size buffer as well, and
   the theorem-side leaf-state validator now keeps those leaves boxed rather
   than reopening them into temporary `Vec` state. The
   raw-backend `RawMapEntry` ciphertext slot is now boxed too, so the runtime
   object graph no longer keeps secret-bearing ciphertext in growable `Vec<u8>`
   buffers. The low-level store codec now also keeps its nonzero transport and
   sealed-payload encode/decode path exact-size: sealing helpers write through
   fixed output buffers and opening uses in-place AEAD on exact-size decoded
   payload buffers rather than growable transport vectors, and the fixed-size
   raw/UO store slot maps now also keep their ciphertext cells in boxed
   buffers while the UO write path seals directly into those fixed-size boxed
   slots. The surrogate ORAM
   metadata path now also keeps its page scratch
   exact-size: directory-page encoding fills caller-owned page slices before
   sealing, and directory-page decode writes directly back into the caller's
   boxed entry array instead of widening secret-bearing map entries into a
   temporary growable vector. The Path-ORAM metadata path now follows that
   same discipline too: position-map and stash pages are filled through
   exact-size page slices, sealed metadata pages are collected into a boxed
   fixed-size page array rather than a growable page vector, stash blocks
   serialize directly into fixed-size block slices rather than through
   growable plaintext page buffers, and the live Path-ORAM position map now
   stays boxed across decode and rewrite instead of widening into a temporary
   `Vec<Option<usize>>`. Live
   bucket reconstruction now also writes directly into the fixed bucket block
   buffer instead of staging blocks through temporary growable vectors first,
   and bucket plaintext serialization now fills exact-size bucket slices
   before sealing rather than growing a temporary plaintext buffer. The
   remaining exact-size bootstrap seal paths now also emit boxed ciphertext
   outputs directly, and the small-map record / bucket plaintext helpers now
   likewise stay on exact-size boxed buffers rather than widening back into
   temporary `Vec<u8>` carriers before boxing. The source-backed
   `RuntimeImplementationInterface` now pins the public engine/runtime/shell/
   theorem split and the state/kernel shared-boundary delegation directly over
   those production `uo-evm` modules, while the combined
   `RuntimeImplementationConfinementBoundary` checker pairs that source
   interface with the exact emitted `RuntimeKernelInterfaceBundle` so the
   proof/interface route now states both halves of the WP3 claim together:
   the real emitted kernel/interface witness projects to the Lean confinement
   boundary, and the rest of the runtime is checked to stay on the admitted
   public-only bridge.

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
4. Work Package 3: complete the runtime proof/interface route for
   runtime-kernel refinement and secret confinement.
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
6. Completed: discharge the real-runtime honesty gap for the chosen
   proof/interface route by pairing the exact
   `RuntimeKernelRefinementBoundary` /
   `RuntimeKernelInterfaceSlotBoundary` /
   `RuntimeKernelConfinementBoundary` objects with the source-backed
   `RuntimeImplementationInterface` and the combined
   `RuntimeImplementationConfinementBoundary`, plus direct positive reports and
   tamper rejections for representative confidential-bypass drift.
7. Completed: prove that the non-kernel shell is public-only and package that
   shell contract together with the exact proof-grade boundary facts needed by
   the confidential-core argument.
8. Active next item after 6-7: prove source-to-kernel compiler correctness.
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
  checkProofGradeRuntimeKernelRefinementBoundary \
  checkProofGradeRuntimeImplementationInterface \
  checkProofGradeRuntimeImplementationConfinementBoundary \
  checkProofGradeRuntimePaperMainFamilyBundle \
  checkProofGradeRuntimePaperMainSlotFamilyBundle \
  checkProofGradeRuntimeShellBoundary \
  checkProofGradeRuntimeShellBoundarySlot \
  checkProofGradeRuntimeShellBoundaryLowering \
  checkProofGradeRuntimeConfidentialCore \
  checkProofGradeRuntimeConfidentialCoreSlot \
  checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot \
  checkProofGradeRuntimeConfidentialCoreShellBoundarySlot \
  checkProofGradeRuntimeConfidentialCoreLowering \
  checkProofGradeRuntimeConfidentialCoreShellBoundaryLowering \
  checkProofGradeRuntimeTrustedKernel
cargo run -q -p mplus-probe -- --only static-checks --out-dir /tmp/uo-static
cargo run -q -p mplus-probe -- --only runtime-boundary-validation --out-dir /tmp/uo-runtime-boundary
cargo run -q -p mplus-probe -- --only runtime-implementation-interface-validation --out-dir /tmp/uo-runtime-implementation-interface
cargo run -q -p mplus-probe -- --only runtime-implementation-confinement-boundary-validation --out-dir /tmp/uo-runtime-implementation-confinement-boundary
cargo run -q -p mplus-probe -- --only shell-boundary-validation --out-dir /tmp/uo-shell-boundary
cargo run -q -p mplus-probe -- --only shell-boundary-slot-validation --out-dir /tmp/uo-shell-boundary-slot
cargo run -q -p mplus-probe -- --only shell-boundary-lowering-validation --out-dir /tmp/uo-shell-boundary-lowering
cargo run -q -p mplus-probe -- --only confidential-core-validation --out-dir /tmp/uo-confidential-core
cargo run -q -p mplus-probe -- --only confidential-core-slot-validation --out-dir /tmp/uo-confidential-core-slot
cargo run -q -p mplus-probe -- --only confidential-core-kernel-interface-slot-validation --out-dir /tmp/uo-confidential-core-kernel-interface-slot
cargo run -q -p mplus-probe -- --only confidential-core-shell-boundary-slot-validation --out-dir /tmp/uo-confidential-core-shell-boundary-slot
cargo run -q -p mplus-probe -- --only confidential-core-lowering-validation --out-dir /tmp/uo-confidential-core-lowering
cargo run -q -p mplus-probe -- --only confidential-core-shell-boundary-lowering-validation --out-dir /tmp/uo-confidential-core-shell-boundary-lowering
cargo run -q -p mplus-probe -- --only kernel-interface-validation --out-dir /tmp/uo-kernel-interface
cargo run -q -p mplus-probe -- --only kernel-refinement-boundary-validation --out-dir /tmp/uo-kernel-refinement-boundary
cargo run -q -p mplus-probe -- --only kernel-validation --out-dir /tmp/uo-kernel
cargo run -q -p mplus-probe -- --only kernel-refinement-validation --out-dir /tmp/uo-kernel-refinement
cargo run -q -p mplus-probe -- --only trusted-kernel-validation --out-dir /tmp/uo-tk
cargo run -q -p mplus-probe -- --only witness-validation --out-dir /tmp/uo-witness
cargo run -q -p mplus-probe -- --only seeded-witness-validation --out-dir /tmp/uo-seeded
cargo run -q -p mplus-probe -- --only tamper-validation --out-dir /tmp/uo-tamper
./scripts/check_probe_reproducibility.sh --only static-checks
```

Any phase that broadens the theorem, observer, or TCB must update the paper
docs and the Lean interface in the same change set.
