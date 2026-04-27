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

The repository has closed the outer runtime-side proof/interface gap for the
chosen paper route. In addition to the exact checked
`RuntimeKernelRefinementBoundary`, `RuntimeKernelInterfaceSlotBoundary`, and
`RuntimeKernelConfinementBoundary` objects, it now exports and checks a
source-backed `RuntimeImplementationInterface` and
`RuntimeImplementationConfinementBoundary` over the actual `uo-evm` runtime
modules, and that checked implementation boundary now extends one layer
deeper into the shared `uo-core` confidential-kernel interpreter and
masked-selection/value layer used by the live runtime. Dedicated positive
reports and tamper rejections now cover both representative outer
secret-escape drift and representative shared-kernel secret-branch drift. That
same checked boundary now also covers the live Path ORAM masked full-scan
lookup/update/stash-rebuild path together with its exact transition-shaped
fresh-leaf schedule, with tamper rejection for reintroduced early-exit
lookup, secret-index mutation, stash `.position(...)` rebuilding, and the
older single-fresh-leaf approximation / conditional fresh-leaf schedule. It
also now covers fixed-public-batch Path-ORAM write evidence, masked
full-scan UO small-map lookup, masked full-scan UO array read/write
selection, and the public return-tail schedule for generated confidential
kernel slots. UO array out-of-range indices are handled as masked no-match /
no-op cases on the UO path rather than as pre-scan public errors, and the
source-backed boundary rejects reintroduction of direct array indexing, the
old OOB branch, or a generated post-return `state.returned` / `break`
truncation path. The
remaining gaps are:

- there is not yet a source-to-kernel compiler correctness theorem for the
  admitted Solidity subset
- the concrete `PathOramLocalPosmapV1SecurityAssumptions` bundle is still only
  partially discharged
- the SGX/TEE deployment story is still weaker than a full malicious-host
  execution theorem
- a deeper semantics-of-Rust refinement below the strengthened
  runtime/shared-confidential-kernel source interface would still be
  scientifically stronger and remains the live next strengthening step

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

- [runtime/uo-kernel-runtime/src/lib.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-kernel-runtime/src/lib.rs)
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
   the shared `RuntimeKernelMachine` path.
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
- [runtime/uo-kernel-runtime/src/lib.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-kernel-runtime/src/lib.rs)
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

Status: completed on April 26, 2026. WP3's exit-gate criteria are all met
under the explicit "without overclaiming a full below-interface refinement
theorem" disclaimer documented in the gate text: the emitted runtime
kernel/interface witness projects to the Lean confinement boundary, secret-
dependent runtime work is confined to the generated/Lean-backed kernel and
helper stack, the residual handwritten shell is checked public-only, the
shared confidential-kernel interpreter and the live Path-ORAM masked
lookup/update/stash-rebuild layer are pinned at the source-backed boundary,
the inner source cuts meet the live machine-finish witness directly at the
small-confidential-kernel and shared-confidential-kernel cuts, the direct
machine-confinement boundary lifts the full source interface plus live
machine-finish witness and fixed slot program/opcode trace straight to the
outer implementation-confinement theorem, and the Lean helper-semantics
layer now models the Path-ORAM reconstruction end-to-end (codec→bridge→
fold→success) with both routes (residual-helper-shell and direct
machine-confinement) exposing the matching theorem family. The full
deeper "semantics-of-Rust refinement" theorem for the residual real
kernel implementation surface remains open as a future scientific
strengthening track and is tracked separately below this WP3 closure;
it is not a WP3 blocker.

The outer proof/interface route was completed on April 21, 2026, and
the stronger shared-kernel strengthening track is now active below that outer
closure. The runtime-boundary confinement audit and the stronger
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
one shared `uo-core` `RuntimeKernelBoundaryTracker` rather than a runtime-local
`uo-evm` kernel shim hand-assembling the public-object bootstrap,
admitted-schedule binding, runtime-phase tracking, and finish-snapshot handoff
itself, the live confidential slot-file / argument-staging path now also
routes through the shared `uo-kernel-runtime` machine and its private
`RuntimeKernelSlotCall` wrapper rather than a runtime-local slot-state adapter
in `uo-evm` or a public `uo-core` call wrapper, and `state.rs` now loads
admitted confidential slot
programs plus the matching public runtime budgets/object universe through one
shared `uo-core`
`EntrypointManifest::runtime_confidential_entrypoint_plan(...)` helper rather
than revalidating manifest-vs-slot-program agreement or repacking the runtime
budget facts locally, with that public object universe now materialized only as
a public-shape boxed slice from the committed object table through the shared
manifest plan and into the public shell/bootstrap path, while the
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
`paper_main_slot_boundary_validation.json` outputs. The outer real-runtime
proof/interface route is now closed by the source-backed
`RuntimeImplementationInterface` and
`RuntimeImplementationConfinementBoundary` checkers, together with dedicated
`runtime_implementation_interface_validation.json`,
`runtime_implementation_confinement_boundary_validation.json`, and matching
tamper-rejection cases for representative engine-level confidential-bypass
drift. That source-backed implementation boundary now also reaches the shared
`uo-core` confidential-kernel interpreter and masked-selection/value layer
used by the live runtime: `state.rs` now invokes the shared
`uo-kernel-runtime` machine directly, that shared machine delegates
confidential slot execution to
`uo_core::execute_confidential_kernel_slot_program(...)`, Lean now also emits
the private `uo-kernel-runtime` slot-support module that stages
confidential arguments into the fixed slot file and wipes both buffers on
drop, the shared `uo-core` interpreter keeps confidential hash staging on an
exact-size boxed buffer, confidential value selection flows through shared
masked-selection helpers, confidential abort propagation no longer branches
directly on the confidential condition, and
`tamper_validation.json` now also rejects representative shared-kernel
secret-branch drift. The Rust/Lean
`kernel_model_alignment_validation.json` route now also checks the
Lean-first/generated-kernel path: Lean emits
`crates/uo-core/src/generated_confidential_kernel.rs` from
`proof/lean/GenerateConfidentialKernelRust.lean`, the probe checks exact
source equality against the generator output, and the live shared kernel
delegates slot-statement execution into that generated evaluator while
re-exporting the generated profile tables. Those generated tables cover
confidential statement, named-expression, named-pure-expression,
slot-expression, and slot-pure-expression metadata rather than only scattered
method names: statement kind, trace name, runtime-normal-form flag, effect
kind, operand-evaluation order, storage-tail opcode facts, and the
select/keccak operand structure for both named and slot pure expressions now
come from the Lean-generated Rust artifact, while Lean mirrors the same tables
on both the native and imported-JSON sides. The same alignment report now also
checks `runtime/uo-kernel-runtime/src/generated_slot_support.rs` against
`proof/lean/GenerateRuntimeKernelSlotSupportRust.lean`; Lean’s
`RuntimeKernelSlotSupport` model proves exact argument-count staging,
explicit rejection on argument-count mismatch or public slot-capacity
overflow, slot-file length preservation, and deterministic staging for the
generated slot-support interface. The direct machine-confinement report now
also emits the matching slot-support staging theorem bits for every scenario.
The same alignment report now also checks
`runtime/uo-evm/src/generated_object_helpers.rs` against
`proof/lean/GenerateRuntimeObjectHelpersRust.lean`, so the masked cell-value
update, full-scan UO array selector/update helpers, and first-match masked
small-map lookup/update helpers now travel through a Lean-generated object-
helper artifact rather than a handwritten helper layer in `objects.rs`. The
source-backed runtime implementation interface now requires `objects.rs` to
consume that generated helper module rather than defining those masked helper
routines inline, and the tamper suite now also rejects representative
generated object-helper drift. That same Lean-generated helper layer now also
owns the UO cell/array/small-map commit-control skeleton: aborted-or-cold
restore selection for UO cells, full-length restore/reseal traversal for UO
arrays, and full-length restore/reseal traversal for UO small maps now route
through generated `reconcile_*_commit_*` helpers, leaving `objects.rs` with
only the public sealing/tracing shell around those generated loops. The
source-backed implementation interface, kernel-model alignment report, and
tamper suite now all reject drift in that generated object-commit helper
surface as well. The same implementation boundary now also pins
the `state.rs` shadow-load/commit table discipline: the runtime must rebuild
confidential shadow state through `clone_for_shadow`, iterate the committed
table in sorted order against a peekable shadow iterator, rebuild the next
object table and committed-object schedule through `FixedBoxBuilder`, and keep
the public object-id list on a public-size boxed-slice collection path rather
than reopening ad hoc secret-bearing growable commit buffers. The same
implementation interface
now also imports the lower-level store shell: `RuntimeImplementationInterface`
pulls in `runtime/uo-store/src/codec.rs`,
`runtime/uo-store/src/generated_store_helpers.rs`, and
`runtime/uo-store/src/store.rs`, direct `StoreCipher::seal` /
`StoreCipher::open` use must stay inside `codec.rs`, the UO-store
bootstrap/write path must route through the Lean-generated
`filler_boxed_uo_store_slot` and `reseal_uo_store_slot_in_place` helpers, and
the tamper suite now rejects representative store boxed-filler and seal-into
helper drift at the implementation-interface, standalone small-kernel,
standalone shared-kernel, combined confinement, and direct
machine-confinement checkers. The same alignment report also pins the emitted
`RuntimeKernelMachineFinishWitness` field schema plus the
source-backed runtime implementation/shared-kernel boundary JSON schemas
against their Lean imports, and the source-backed runtime implementation
interface now requires both the generated profile route and the generated
interpreter entry points and the generated slot-support route to stay present
in the live shared kernel while also exact-matching
`runtime/uo-kernel-runtime/src/generated_machine.rs`,
`runtime/uo-kernel-runtime/src/generated_slot_support.rs`,
`crates/uo-core/src/generated_confidential_kernel.rs`,
`runtime/uo-evm/src/generated_object_helpers.rs`, and
`runtime/uo-store/src/generated_store_helpers.rs` against their Lean generator
outputs inside the checked source boundary itself, rather than leaving those
equalities only to the separate alignment report, while also pinning the
explicit named-to-slot
lowering bridge and the concrete live slot-statement / slot-expression /
slot-pure-expression evaluator order used by the interpreter; the tamper
suite now also rejects representative Lean-generated interpreter drift,
generated slot-support argument-count drift, named-expression profile-table
drift, named-pure-expression profile-table drift, and named-to-slot lowering
drift at the standalone
implementation-interface checker, the standalone
shared-confidential-kernel-boundary checker, and the combined
implementation-confinement-boundary checker. Lean now also factors that
checked source route into an explicit outer `PublicBridgeBoundary`, an
explicit `SmallConfidentialKernelBoundary` for the actual tiny kernel files,
an explicit `ConfidentialStatementTraceBridgeBoundary` for the exact
statement-trace/proof-bundle bridge, and a
`SharedConfidentialKernelBoundary` that conjoins those two confidential cuts;
the probe now emits dedicated
`runtime_small_confidential_kernel_boundary_validation.json`,
`runtime_confidential_statement_trace_bridge_boundary_validation.json`, and
`runtime_shared_confidential_kernel_boundary_validation.json` artifacts for
those standalone and combined inner cuts, the alignment report now pins all
three imported JSON schemas, and the tamper suite now rejects representative
secret-branch drift, centralized profile-table drift, named-to-slot lowering
drift, and Path ORAM early-exit scan drift already at the standalone
small-confidential-kernel boundary and the combined
small-confidential-kernel machine-refinement route, plus statement-trace
recording / bridge drift at the standalone confidential-statement-trace
bridge boundary and the combined confidential-statement-trace bridge
refinement route. That inner source cut now also meets the smaller emitted
artifact boundaries directly.
`runtime_kernel_machine_finish_witness_validation.json` checks the live
`RuntimeKernelMachineFinishWitness` itself,
`runtime_kernel_machine_finish_boundary_validation.json` now checks the
standalone imported/native `RuntimeKernelMachineFinishBoundary` route over
that same live machine finish state plus the fixed slot program/opcode trace,
`runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`
pairs the checked `RuntimeImplementationSlotAdapterBoundary` source interface
with that same exact live machine finish state plus the fixed slot
program/opcode trace,
`runtime_implementation_small_confidential_kernel_machine_refinement_boundary_validation.json`
pairs the checked `SmallConfidentialKernelBoundary` source interface with the
exact live machine finish state plus the fixed slot program/opcode trace,
`runtime_implementation_shared_kernel_machine_refinement_boundary_validation.json`
pairs the checked `SharedConfidentialKernelBoundary` source interface with the
same native machine-finish boundary object, and
`runtime_implementation_confidential_statement_trace_bridge_refinement_boundary_validation.json`
pairs the dedicated `ConfidentialStatementTraceBridgeBoundary` source
interface with the smaller emitted
`RuntimeConfidentialCoreKernelFinishSlotBundle`,
`runtime_implementation_kernel_meeting_boundary_validation.json` then checks
that the live machine-projected finish bundle and that emitted finish-slot
bundle agree at the native boundary, and only after that does the older wider
`runtime_implementation_shared_kernel_refinement_boundary_validation.json`
route recheck that same finish-slot artifact against the larger shared
boundary. The stronger direct route
`runtime_implementation_kernel_machine_confinement_boundary_validation.json`
now removes the separate finish-slot meeting artifact from the outer
confinement step: it pairs the full source-backed
`RuntimeImplementationInterface` directly with the live
`RuntimeKernelMachineFinishWitness`, the fixed confidential slot program, and
the opcode trace, checks the native machine-finish boundary, proves that the
machine consumed the admitted public kernel schedule, respects the live
kernel-op and runtime-phase capacity bounds, and that the slot semantics
exactly determine the kernel-step trace, and reconstructs the outer
`RuntimeImplementationConfinementBoundary` from that object. Lean now exposes
that direct route as the paper-facing
`RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`
theorem, which strengthens the older direct machine theorem by also stating
that handwritten runtime confidential work lives only in generated helpers,
alongside source-side confinement, Lean-kernel refinement, shell-trace
refinement, schedule consumption, both live capacity bounds, and
slot-program/kernel-step exactness in one native theorem rather than leaving
those facts only as checker-local claims. Lean projects all
of those paired objects through the native runtime-kernel finish/slot
boundaries to exact `RefinesLeanKernelState` and on to the larger
`RuntimeKernelConfinementBoundary`. The smaller confidential-statement-trace
bridge refinement, kernel-meeting, and shared-kernel refinement reports now
also mark `refines_lean_kernel_state_theorem_checked` and
`runtime_kernel_confinement_projection_theorem_checked` for those base
projection theorems directly. The outer implementation-confinement report now
also marks `runtime_kernel_confinement_projection_theorem_checked`, the
meeting-confinement report now marks
`runtime_implementation_confinement_projection_theorem_checked`, and the
direct machine-confinement report now marks
`runtime_implementation_machine_confinement_projection_theorem_checked`
together with `native_machine_semantics_theorem_checked`. The first
below-interface Lean-first
steps have now landed: the live slot-program/block/statement evaluator,
unary/binary operator semantics, all confidential-kernel profile tables, the
private confidential argument / slot-file support, and the masked object-
helper layer used by `runtime/uo-evm/src/objects.rs` are generated from Lean
and exact-source checked both by the checked source boundary and by the probe.
The handwritten shared-kernel
`RuntimeKernelSlotCall` / `RuntimeKernelEffectAdapter` layer is now checked as
a forwarding-only adapter: it may construct generated slot state, delegate
argument staging to the generated support module, forward slot/effect calls to
the machine/object-store path, and call the generated interpreter, but the
source-backed boundary rejects raw confidential-argument observations or ad
hoc `Value` environments in that adapter. The same boundary now also pins the
runtime machine's object-effect schedule: every cell/array/map/commit path
must record the public opcode, reserve the fixed scratch budget, perform the
object-store operation through the shared machine, and wipe before producing
the finish bundle. Lean now also has an explicit
`RuntimeKernelMachineSchedule` model proving that every machine effect starts
with a public-opcode / kernel-op prefix and that the finish schedule wipes all
scratch regions before snapshotting. The imported implementation boundary now
also includes `runtime/uo-allocator/src/lib.rs` and checks the allocator
session's kernel-op budget, scratch budget, guard-drop wipe, finish-time
wipe validation, stack-word budget, and absence of unsafe/forget-style escape
hatches. Lean now also has `RuntimeAllocatorDiscipline`, which models the
allocator kernel-op budget, scratch reservations, guard/drop wipes,
finish-time wipe acceptance, and public-capacity resource-event log; the live
allocator now uses that bounded `ResourceEventLog`, and `uo-core` carries
resource events as boxed slices at the finish boundary. The allocator
resource-event finalizer now also extracts each public-prefix event through a
checked `get_mut(...)` slot before taking it, and the implementation-interface
tamper suite rejects the stale `self.events[index].take()` shape. The live
confidential statement recorder has likewise moved from a growable
`Vec<String>` to an exact-capacity `RuntimeKernelStatementTrace` backed by
`RuntimeStatementTraceDiscipline`; Lean now models the recorded name list,
proves each accepted record appends exactly the public `traceName`, rejects
records at public capacity, and proves the boxed trace of an accepted recorder
is exactly `program.statementTraceNames`. That recorder now uses boxed
`MaybeUninit<String>` storage with checked `get_mut(...)` record slots,
iterator/zipped finish moves, and iterator-limited drop cleanup rather than
`vec![None; capacity]`, direct `trace[index]` / `self.statements[index]`
moves, initialized-prefix slicing, or a `Vec`-repacking finish path. The live
Path-ORAM commit path now emits
fixed-public-capacity `OramWriteBatch` / `OramWriteLog` evidence backed by
`RuntimeOramWriteLogDiscipline`, which now also models exact public-capacity
read-transcript builders; Lean now proves write/update/read-transcript pushes
reject at public capacity, preserve the public capacity/overflow flag on
accepted pushes, and update only the intended public counters, including
`zeroWrites` for generic writes and preservation of `zeroWrites = 0` for the
generated update-only write path. The generated ORAM codec layer initializes
the public-capacity write log with a boxed `Option` array, validates the public
length/capacity and populated prefix on finish, and materializes
logical/physical-read transcript arrays through fallible
`FixedBoxBuilder::new(public_access_count)` builders before finishing boxed
arrays. Those exact public-size builders are confined to the generated helper layer, while
handwritten `oram.rs` only consumes boxed transcript/write-batch values. UO
small-map lookup now uses a masked full-scan selector backed by
`RuntimeSmallMapLookupDiscipline`; Lean now models the accumulated `matched`
bit as the exact fold of per-slot key-match booleans and rejects match lists
whose public length differs from map capacity. UO array read/write access now
uses masked full-scan selectors backed by
`RuntimeArrayAccessDiscipline`; Lean now exposes an executable selected-slot
function that accepts exactly in-range public indices, rejects out-of-range
indices as no-match, and proves the selected slot is unique. Generated
confidential-kernel slots now also
reject non-final source returns before lowering and execute a source-pinned
public return-tail schedule backed by `RuntimeReturnScheduleDiscipline`, rather
than relying on a runtime `state.returned` / `break` truncation branch. The
checked source-backed runtime interface now also imports and pins
`runtime/uo-precompiles/src/lib.rs`, so the auditable
`uo-precompiles::UoOpcode` vocabulary consumed by the small kernel is frozen
at the same Lean/Rust interface cut, and tamper validation rejects
`precompiles_opcode_surface_drift` across the interface, small-kernel,
meeting, and confinement routes. That same source-backed interface now also
imports `runtime/uo-evm/src/fresh_coins.rs`, so the opaque fresh-leaf tape
carrier used by the exact transition-shaped Path-ORAM fresh-leaf schedule is
frozen as a boxed, non-`Clone`, move-only per-object entry table, and tamper
validation rejects `path_oram_fresh_coin_plan_surface_drift` across the
implementation, small-kernel, shared-kernel, meeting, and confinement routes.
The
remaining below-interface strengthening target is the full semantics-of-Rust
refinement theorem for the residual real kernel support beneath the now
source-pinned/public-only handwritten shell cuts and the
now-modeled/source-pinned machine/effect,
allocator, statement-trace, ORAM-write-log, small-map-lookup, array-access,
return-tail schedules, auditable opcode vocabulary, and fresh-leaf tape
carrier beneath this checked source/interface cut.

Objective: upgrade from "the runtime emits accepted proof objects" to "the
real runtime is checked at the explicit proof/interface boundary, and that
checked boundary is pushed downward until the remaining trusted confidential
runtime is a tiny shared kernel." Concretely: the emitted runtime
kernel/interface witness must project to the Lean confinement boundary, the
rest of the runtime must stay on the admitted public-only bridge, and the live
shared confidential-kernel interpreter must stay pinned to the fixed-buffer /
masked-selection discipline already modeled on the Lean side.

Primary files:

- [runtime/uo-kernel-runtime/src/lib.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-kernel-runtime/src/lib.rs)
- [runtime/uo-evm/src/engine.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/engine.rs)
- [runtime/uo-evm/src/state.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/state.rs)
- [runtime/uo-evm/src/runtime.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/runtime.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [crates/uo-core/src/generated_confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/generated_confidential_kernel.rs)
- [crates/uo-core/src/types.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/types.rs)
- [probe/mplus-probe/src/lib.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/lib.rs)
- [proof/lean/GenerateConfidentialKernelRust.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/GenerateConfidentialKernelRust.lean)
- [proof/lean/UOToolchain/RuntimeRefinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeRefinement.lean)
- [proof/lean/UOToolchain/RuntimeTrustedKernel.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeTrustedKernel.lean)
- [proof/lean/UOToolchain/RuntimeShellBoundary.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeShellBoundary.lean)
- [proof/lean/UOToolchain/RuntimeCoins.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeCoins.lean)
- [proof/lean/UOToolchain/RuntimeImplementationInterface.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeImplementationInterface.lean)
- [proof/lean/UOToolchain/RuntimeImplementationInterfaceJson.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeImplementationInterfaceJson.lean)

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
   bounded journal in `kernel.rs`; both shared tracker journals now use a
   fixed-capacity `BoundedJournal<T>` over boxed `MaybeUninit` storage, and the
   source-backed interface rejects the old tracker-side `Vec` fields and the
   stale direct-index / `Vec`-bounce journal snapshot forms. The
   final `RuntimeKernelWitness`
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
   program before the trace is returned. That stronger slot-family artifact
   now also carries the exact emitted confidential `opcode_trace` and rechecks
   that it matches the slot-program statement trace names, so both paper-route
   theorem objects are now checked in the production runtime path rather than
   only by the external probe/checker route. The Rust side now also packages the
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
   `RuntimeKernelConfinementBoundary`. That same source-backed interface now
   also yields a standalone `RuntimeImplementationPublicBridgeBoundary`, and
   tamper validation rejects representative bridge-module ownership,
   engine-bridge bypass, shell confidentiality bleed, state staging bypass, and
   theorem-side manual trace materialization drift on that public bridge cut on
   its own. The same checked source interface now
   also covers the shared `uo-core` confidential-kernel interpreter and
   masked-selection/value layer used by the live runtime, so the positive
   reports now pin the fixed-buffer / masked-selection / delegated-execution
   discipline at that lower layer as well. `tamper_validation.json` now
   rejects representative engine-level confidential-bypass drift for both the
   standalone implementation-interface checker and the combined
   implementation-confinement-boundary checker, and it also rejects
   representative shared-kernel secret-branch drift.
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
   the live `CallRecorder` implementation now accumulates those page/workset
   region budgets through the fixed public `ControllerRegionCounters` table
   rather than a generic `BTreeMap`, while expected ORAM access counts are
   derived from the observed public schedule instead of maintained in a second
   handwritten map. The theorem-facing public trace path now keeps opcode/logical/physical
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
   `RuntimeKernelFinishBundle` plus one fixed confidential slot program and
   its exact confidential statement trace are rechecked together directly at
   the finish-boundary interface before the larger runtime witness is
   reintroduced. The direct trusted-kernel slot route now carries that same
   exact confidential statement trace as well. The same audit path,
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
   then a Lean-generated `uo-kernel-runtime` slot-support module backed by
   fixed-size boxed slices rather than growable vectors, and the private
   shared kernel-runtime `RuntimeKernelSlotCall` adapter now delegates
   confidential-argument staging to that generated support while retaining live
   slot-word accounting, so neither `uo-evm` nor `uo-core` keeps a public
   slot-state adapter around that shared state; its shared
   `keccak256` evaluator now also stages confidential hash parts through an
   exact-size boxed buffer rather than a growable `Vec<Value>` and wipes each
   hashed part after use, while the recursive runtime `Value` representation
   now also keeps both struct fields and array elements in boxed fixed-size
   buffers rather than growable `Vec` carriers, exposes an exact-size boxed
   canonical-byte helper rather than `canonical_bytes().into_boxed_slice()`
   caller-side bouncing, with the remaining `Vec`-returning
   `canonical_bytes()` convenience method gated to tests instead of the
   production runtime value surface, and the live hash, fresh-coin install, boxed
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
   plus boxed ORAM counter slot are now boxed as well; handwritten array write
   bookkeeping now uses fixed-size boxed public flags rather than a growable
   `BTreeSet` of written indices, and the source-backed interface rejects the
   old growable written-index carrier. The long-lived
   committed/shadow object carrier has now been reduced to a boxed fixed-order
   table over the public object universe rather than a generic map, the
   remaining confidential object-table rebuilds in `state.rs` now also route
   through one exact-size boxed builder rather than temporary growable
   `Vec<RuntimeObjectEntry>` staging, table lookup uses fallible
   `entries.get(...)` / `entries.get_mut(...)` after the public object-id scan
   rather than direct `entries[index]` indexing, and the hidden committed-state ORAM
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
   separate raw witness pair, and the live Path ORAM access path now consumes
   exactly one fresh leaf per access, records that draw explicitly in
   `RuntimePathOramTransitionWitness`, and exposes a source-checked /
   tamper-checked boundary that rejects the older conditional `take_leaf(...)`
   schedule.
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
  buffers; those step buffers now use checked-slot push, iterator-based
  finish moves, and iterator-limited drop cleanup instead of direct uninit-slot
  indexing or initialized-prefix slicing, and slot-program statement-trace
  materialization now iterates over the body rather than indexing
  `self.body[index]`. `RuntimeKernelFinishBundle::completed_runtime_phase_events`
  and `RuntimeKernelRefinementWitness::from_events` meet on boxed refinement
  event buffers instead of reopening the finish/refinement boundary through
  temporary `Vec<RuntimeKernelRefinementEventWitness>` carriers. The same
  source-backed interface now also pins the named and slot confidential-kernel
  program bodies plus Keccak part lists to boxed fixed-shape slices, and pins
  named-to-slot lowering to `FixedBoxBuilder` construction rather than
  `.map(...).collect::<Result<Vec<_>, _>>()` or statement-body
  `Vec::with_capacity(...)` staging. The runtime's
  live public-object universe handoff now follows that same discipline too:
  `RuntimeObjectTable::object_ids()`,
  `ContractRuntime::public_object_ids()`, the shared confidential-entrypoint
  plan, and the public shell/bootstrap path all exchange boxed object-id
  slices; the only `Vec` step is the public-size collection used to build that
  boxed slice. That boxing
  discipline now also reaches the deeper
  theorem-facing certificates and witnesses in
  `uo-core`: the runtime kernel-refinement event journal, controller
  certificate observed ORAM-access list, controller-observer boundary
   schedule, hidden Path-ORAM certificate buffers, `TheoremTrace`
   boundary schedule, and `RuntimeRefinementWitness` boundary/hidden buffers
   all stay boxed, and `runtime_boundary_validation.json` now pins those
   representation choices explicitly alongside the older `ExecutionTrace` /
   `RuntimeExecutionTraceParts` checks. The remaining object-operation and
   commit bookkeeping now also routes through one private shared shadow-state
   interface rather than duplicated public-vs-confidential helper bodies, and
   the live public-object bootstrap /
   admitted-schedule / runtime-phase / finish-snapshot bookkeeping now also
   routes through one shared `uo-core` `RuntimeKernelBoundaryTracker` rather
   than dual tracker coordination in `kernel.rs`; the tracker-owned
   kernel-step/runtime-phase journals are now fixed-capacity boxed
   `BoundedJournal<T>` values rather than growable `Vec` fields, which further
   shrinks the bespoke Rust kernel surface that still needs a refinement
   argument. Each emitted Path-ORAM position-map
   witness now stores its leaf array in a boxed fixed-size buffer as well, and
   the theorem-side leaf-state validator now keeps those leaves boxed rather
   than reopening them into temporary `Vec` state. The
   raw-backend `RawMapEntry` ciphertext slot is now boxed too, so the runtime
   object graph no longer keeps secret-bearing ciphertext in growable `Vec<u8>`
   buffers. The low-level store codec now also keeps its nonzero transport and
   sealed-payload encode/decode path exact-size: sealing helpers write through
   fixed output buffers and opening uses in-place AEAD on exact-size decoded
   payload buffers rather than growable transport vectors, the generated
   store-codec artifact now exposes only the exact-size transport primitives
   (`sealed_encoded_len`, `write_nonzero_encoded`, and
   `decode_nonzero_into`) rather than older `Vec`-returning convenience
   wrappers; the generated nonzero encoder now returns a checked success bit,
   obtains the public output window with `get_mut(...)`, writes nibbles through
   chunk-local `get_mut(...)`, and decodes through `zip(out.iter_mut())`
   rather than the old `out[index * 2]` / `out[index]` forms. The generated
   store-surface reopen path also decodes magic, nonce, ciphertext, and tag
   through checked cursor/range helpers (`checked_end(...)` /
   `read_exact_range(...)`) and fills boxed plaintext staging buffers through
   `copy_exact_into(...)`, so the boundary rejects direct `split_at(...)`
   parsing and `payload.copy_from_slice(...)` reintroduction. Lean models that reopen surface as
   `RuntimeStoreCodecSemantics.decodeNonzeroInto?`, with checked roundtrip,
   encoded-length-mismatch rejection, and decoded-byte/nonzero-nibble soundness
   facts imported by both residual-helper-shell and direct machine-confinement
   checkers. The raw/UO store slot tables now also use generated boxed
   fixed-slot tables with public linear lookup rather than handwritten
   `BTreeMap<String, Box<[u8]>>` storage, while keeping ciphertext cells in
   boxed buffers; the public store evidence buffers are now generated
   `StorePhysicalWriteTrace` / `StoreLogicalEventTrace` wrappers instead of
   handwritten `Vec<PhysicalWriteEvent>` / `Vec<LogicalEvent>` fields in
   `store.rs`, and those generated wrappers themselves now use exact
   boxed-slice backing plus fallible fixed-builder appends rather than `Vec`
   storage. The UO bootstrap/write shell remains
   centralized through the Lean-generated `runtime/uo-store/src/generated_store_helpers.rs`
   `filler_boxed_uo_store_slot` / `reseal_uo_store_slot_in_place` layer, which
   is now imported into the source-backed implementation interface,
   exact-source checked against `GenerateRuntimeStoreHelpersRust.lean`,
   covered by dedicated tamper-rejection cases, and paired with a UO-store
   write path that now emits only public update-shape evidence rather than
   cloning old/new ciphertext snapshots. The surrogate ORAM
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
   temporary `Vec<u8>` carriers before boxing. The exact secret-bearing
   object/ORAM open/bootstrap/reseal shell now lives in the Lean-generated
   `generated_object_helpers.rs` layer: object reopen, bootstrap seal, and
   commit reseal/write paths now go through
   `with_opened_object_payload`, `seal_boxed_object_payload`, and
   `reseal_payload_and_trace_write`, while the ORAM counterparts now go
   through `with_opened_oram_payload`, `seal_boxed_oram_payload`,
   `filler_boxed_oram_payload`, and
   `reseal_oram_payload_and_record_write`. The same generated helper layer now
   also owns the typed object value/map open/bootstrap/commit wrappers and the
   exact-size map-record, directory-page, and scalar metadata codec used by
   small-map and surrogate-ORAM directory-page handling, and the generated ORAM reseal helper
   now records only public update-shape writes rather than threading prior
   ciphertext snapshots.
   The source-backed
   implementation-interface route, the standalone
   small/shared-confidential-kernel boundary reports, the Rust/Lean
   `kernel_model_alignment_validation.json` audit, and the tamper suite now
   all pin those shared helper routes explicitly. ORAM read transcript
   logical/physical-read evidence now also stays boxed after fallible fixed
   public-capacity generated construction, and the ORAM write-log fixed batch is initialized
   through the same generated public-capacity boxed-array discipline instead of
   handwritten `vec![None; capacity]`. The source-backed
   `RuntimeImplementationInterface` now pins the public engine/runtime/shell/
   theorem split and the state/kernel shared-boundary delegation directly over
   those production `uo-evm` modules, and it now also pins the live
   delegation into the shared `uo-core` confidential-kernel interpreter /
   masked-selection/value layer over
   [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
   and
   [crates/uo-core/src/types.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/types.rs),
   plus the exact confidential statement-trace bridge carried by
   [runtime/uo-kernel-runtime/src/lib.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-kernel-runtime/src/lib.rs),
   [runtime/uo-evm/src/state.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/state.rs),
   [crates/uo-core/src/trace.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/trace.rs),
   [crates/uo-core/src/confidential_core.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_core.rs),
   and
   [crates/uo-core/src/trusted_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/trusted_kernel.rs),
   while the combined
   `RuntimeImplementationConfinementBoundary` checker pairs that source
   interface with the exact emitted `RuntimeKernelInterfaceBundle` so the
   proof/interface route now states both halves of the WP3 claim together:
   the real emitted kernel/interface witness projects to the Lean confinement
   boundary, and the rest of the runtime is checked to stay on the admitted
   public-only bridge. The inner half of that split is now emitted as its own
   first-class reports too:
   `runtime_small_confidential_kernel_boundary_validation.json` checks the
   dedicated `SmallConfidentialKernelBoundary` cut directly over the actual
   tiny-kernel source files,
   `runtime_confidential_statement_trace_bridge_boundary_validation.json`
   checks the dedicated `ConfidentialStatementTraceBridgeBoundary` cut
   directly over the exact statement-trace/proof-bundle bridge files, and
   `runtime_shared_confidential_kernel_boundary_validation.json` checks the
   dedicated `SharedConfidentialKernelBoundary` conjunction directly rather
   than only as one conjunct inside the larger implementation interface. The
   current strengthening step below that outer closure is now explicit too:
   `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`
   now pairs the exact emitted `RuntimeKernelMachineFinishWitness` directly
   with the dedicated slot-adapter source cut,
   `runtime_implementation_small_confidential_kernel_machine_refinement_boundary_validation.json`
   now pairs the exact emitted `RuntimeKernelMachineFinishWitness` directly
   with the dedicated small-confidential-kernel source cut,
   `runtime_implementation_confidential_statement_trace_bridge_refinement_boundary_validation.json`
   now pairs the smaller emitted
   `RuntimeConfidentialCoreKernelFinishSlotBundle` directly with the
   dedicated confidential statement-trace bridge cut,
   `runtime_implementation_kernel_meeting_boundary_validation.json` now forces
   the emitted machine-finish route and emitted finish-slot route to meet on
   the same native finish bundle before the wider shared route is used, and
   now also marks `residual_helper_shell_boundary_theorem_checked` plus
   `handwritten_runtime_public_only_theorem_checked`,
   `runtime_implementation_kernel_meeting_confinement_boundary_validation.json`
   then requires the full source-backed implementation interface and
   reconstructs the outer `RuntimeImplementationConfinementBoundary` from that
   same meeting object,
   `runtime_implementation_kernel_machine_confinement_boundary_validation.json`
   now takes the stronger direct path by pairing the full source-backed
   implementation interface with the live machine-finish witness, fixed slot
   program, and opcode trace without requiring the separate emitted
   finish-slot meeting artifact for outer confinement, and
   the older shared machine/refinement routes remain available as wider
   conjunctions. The checked implementation boundary reaches the shared confidential
   interpreter's fixed-buffer and masked-selection discipline, and it now also
   pins the live Path ORAM path-get/path-put/stash-rebuild code to masked
   full-scan source shapes together with the exact transition-shaped fresh-
   leaf schedule used by the modeled witness extractor: reads consume one
   fresh leaf, write-noop/delete existing slots consume none, updates consume
   one remap leaf, and inserts consume one access leaf plus one remap leaf.
   It also pins Path-ORAM commit write evidence to exact public write batches,
   UO small-map lookup to masked full-capacity scans, and UO array reads/writes
   to masked full-capacity scans where out-of-range logical indices select no
   slot and do not raise a public UO-path error.
   That inner checked source boundary now also meets three emitted artifact
   cuts directly: the standalone
   `runtime_kernel_machine_finish_witness_validation.json` route checks the
   live `RuntimeKernelMachineFinishWitness`,
   `runtime_kernel_machine_finish_boundary_validation.json` checks the
   standalone imported/native `RuntimeKernelMachineFinishBoundary` route over
   that same live machine finish state plus the fixed slot program/opcode
   trace, and the combined
   `runtime_implementation_shared_kernel_machine_refinement_boundary_validation.json`
   route pairs the checked source interface with that exact live machine
   finish state plus the fixed slot program/opcode trace before Lean projects
   the pair through that same native runtime-kernel machine-finish boundary.
   The direct
   `runtime_implementation_kernel_machine_confinement_boundary_validation.json`
   route now lifts that same native machine-finish object all the way to the
   outer implementation-confinement boundary while proving the consumed
   public schedule, live kernel-op/runtime-phase capacity bounds, and exact
   slot-program/kernel-step semantics at that boundary, and the corresponding
   imported checker now exposes the consolidated paper-facing
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_end_to_end_confinement`
   theorem over those same facts.
   The older
   `runtime_implementation_shared_kernel_refinement_boundary_validation.json`
   route remains as the smaller flattened finish-slot artifact path and now
   also marks `residual_helper_shell_boundary_theorem_checked` plus
   `handwritten_runtime_public_only_theorem_checked`. The
   final below-interface semantics-of-Rust refinement theorem for that real
   kernel implementation is still open.

Deliverables:

- one checked runtime-kernel refinement/confinement boundary over emitted proof
  objects
- one checked source-backed runtime implementation interface, one checked
  standalone public-bridge boundary cut, one checked standalone slot-adapter
  boundary cut, one checked standalone residual-helper-shell boundary cut, one
  checked standalone small-confidential-kernel boundary cut, one checked
  standalone confidential-statement-trace bridge boundary cut, one checked
  standalone shared-confidential-kernel boundary cut, one checked standalone
  runtime-kernel machine-finish witness route, one checked standalone
  runtime-kernel machine-finish boundary over the live machine finish state
  plus the fixed slot program/opcode trace, one checked dedicated
  public-bridge observer-refinement boundary over that same native machine
  state, one checked dedicated slot-adapter machine-refinement boundary over
  that same native machine state, one checked dedicated residual-helper-shell
  machine-refinement boundary over that same native machine state, one checked
  combined small-confidential-kernel machine-refinement boundary over that
  same native machine-finish boundary, one checked combined shared-kernel
  machine-refinement boundary over that same native machine-finish boundary,
  one checked combined confidential-statement-trace bridge refinement
  boundary over the smaller finish-slot artifact, one checked combined
  shared-kernel refinement boundary over the smaller finish-slot artifact, one
  checked kernel-meeting boundary, one checked combined meeting-confinement
  boundary that reconstructs the outer implementation-confinement boundary
  from the same native meeting object, one checked direct machine-confinement
  boundary that reconstructs the same outer implementation-confinement
  boundary from the full source-backed implementation interface plus the live
  machine-finish witness and fixed slot program/opcode trace without the
  separate emitted finish-slot meeting artifact, and
  one checked combined implementation-confinement boundary
- one source-backed implementation boundary that now reaches the shared
  confidential-kernel interpreter / masked-selection layer and the live Path
  ORAM masked lookup/update/stash-rebuild layer plus the exact transition-
  shaped fresh-leaf schedule, fixed-public-batch ORAM write evidence,
  masked UO small-map lookup, masked UO array read/write access with
  out-of-range no-match behavior, and the exact confidential statement-trace
  bridge from the live recorder into the slot-coupled proof bundles, with the live
  emitted `RuntimeKernelMachineFinishWitness`, the standalone emitted
  machine-finish-boundary artifact, and the smaller emitted
  `RuntimeConfidentialCoreKernelFinishSlotBundle` now all meeting that
  checked source discipline directly on the native runtime-kernel finish/slot
  boundary route, first at the dedicated small-confidential-kernel cut, then
  at the wider shared-confidential-kernel cut, and finally at the dedicated
  confidential-statement-trace bridge cut before the wider shared-kernel
  refinement route
- one small, auditable Rust kernel boundary that matches the Lean model at the
  current explicit proof/interface boundary and is ready for a deeper
  below-interface refinement proof

Exit gate:

- the paper can honestly say, without overclaiming a full below-interface
  refinement theorem, that the emitted runtime kernel/interface witness
  projects to the Lean confinement boundary, that secret-dependent work does
  not escape the admitted kernel/public-bridge split, that the checked tiny
  kernel already has its own explicit source-backed boundary beneath the
  larger shared-kernel bridge cut, and that the checked implementation
  boundary already reaches the live shared confidential-kernel interpreter /
  masked-selection layer together with the live Path ORAM masked full-scan
  lookup/update/stash-rebuild layer, its exact transition-shaped fresh-leaf
  schedule, fixed-public-batch ORAM write evidence, masked UO small-map
  lookup, masked UO array read/write access with UO-path out-of-range
  no-match behavior, and the exact confidential statement-trace bridge into the checked
  slot-coupled proof bundles, with the inner source cut now also meeting the
  live machine finish witness directly at the small-confidential-kernel cut,
  the standalone native machine-finish boundary artifact directly at both the
  small and shared confidential-kernel cuts, and the smaller flattened
  finish-slot artifact directly at the dedicated confidential-statement-trace
  bridge cut before the wider shared-kernel refinement route, while the
  stronger direct machine-confinement boundary lifts the full implementation
  interface plus live machine-finish witness and fixed slot program/opcode
  trace straight to the outer implementation-confinement theorem

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
- [proof/lean/UOToolchain/CompilerExactness.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/CompilerExactness.lean)
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

Current status update:

- Landed in
  [proof/lean/UOToolchain/TranslationValidationJson.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/TranslationValidationJson.lean)
  together with the paper-facing facades in
  [proof/lean/UOToolchain/CompilerExactness.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/CompilerExactness.lean)
  and
  [proof/lean/UOToolchain/ProofGrade.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ProofGrade.lean):
  the proof-grade translation bundle now exports theorem-level exactness facts
  for source/artifact structural validity, per-entrypoint `secret_args` /
  `param_names`, manifest boundary lengths, replayed body resource counts,
  theorem-facing ORAM access/shape facts, `max_commit_ops`, and exact
  confidential-kernel / slot-program / kernel-step / hash-bound agreement,
  while also proving that every object-bearing confidential kernel step
  resolves to a non-raw state object; `CompilerExactness.lean` now packages
  that surface as one `ProofGradeCompilerFacts` theorem object.
- Landed in the same cut: the theorem-facing translation functions needed by
  those exactness lemmas are no longer file-private, so the paper-facing
  `ProofGrade` facade can reuse them directly instead of treating the checker
  as a black box.
- Landed after that exactness/export cut: `CompilerExactness.lean` now also
  exposes compiler-to-ORAM bridge definitions
  (`toManifestWitnessWithExpected`, `toOramObjectManifest?`,
  `buildExpectedOramObjectWitnesses`, `toOramEntrypointWitnessFromExpected`)
  plus theorem-facing witness facts showing that a proof-grade-valid source
  function determines a source-derived `ManifestWitness`, determines the full
  list of concrete ORAM object witnesses for its expected ORAM accesses, and
  determines an exact source-derived `OramEntrypointWitness` whose
  `entrypointId`, `secretArgs`, `publicGasBudget`, and `oramAccesses` fields
  match the validated entrypoint/source pair while every emitted ORAM object
  witness is well formed. The per-access witness theorem is also stronger now:
  whenever the source-level expected access count for an object is greater than
  one, the reconstructed ORAM object witness is proved to satisfy the path-ORAM
  shape predicate, not just the generic ORAM well-formedness disjunction, and
  that multi-access path-ORAM fact is also exported as its own direct
  proof-grade corollary rather than only as an implication hidden inside the
  generic witness theorem. The rebuilt ORAM object list is now also proved to
  stay aligned entry-by-entry with the source-level expected-access list, so
  the bridge preserves not just existence of witnesses but the ordering and
  per-entry classification needed by downstream backend arguments. There is now
  also a combined exact `OramEntrypointWitness` theorem carrying that
  alignment relation directly on `witness.oramObjects`, so downstream routes do
  not need to manually recombine the exact witness theorem with a separate list
  alignment lemma. The source-side exactness layer is now stronger on the
  kernel side too: for confidential entrypoints, one proof-grade-valid lookup
  now determines the aligned exact `OramEntrypointWitness`, the parsed named
  confidential program, the recomputed slot-lowered program obtained directly
  from that named program, runtime-normality of that recomputed lowered
  program, and a checked match back to the stored manifest slot program. The
  checker now also includes explicit schedule-equality checks from the
  source-body-derived confidential program to the stored source program and
  from the stored source program to the manifest program; Lean exposes those
  equalities theorem-level, and the combined lookup bridge pins the manifest
  kernel-step schedule, the recomputed slot-lowered imported schedule, and the
  runtime slot-program schedule to the same step list. The named
  `proofGrade_source_expected_kernel_schedule_exact_of_lookup` corollary now
  exposes the source-body-derived schedule-to-manifest-step theorem directly,
  and `proofGrade_source_to_runtime_slot_schedule_exact_of_lookup` packages the
  source-derived imported schedule, manifest imported schedule, recomputed
  slot-lowered imported schedule, and runtime slot-program schedule into one
  theorem-facing chain with the imported-to-runtime step conversion made
  explicit. The same facade now exports
  `proofGrade_source_confidential_kernel_step_targets_non_raw_of_lookup`, so
  downstream WP3 arguments can consume raw-target exclusion as a theorem rather
  than as an implementation-only admission check.
  Those witness facts are now included in `ProofGradeCompilerFacts` and
  re-exported through `ProofGrade`.
- Subtask W4.1 landed (commit `6e234df`,
  [proof/lean/UOToolchain/IRSyntax.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSyntax.lean)
  and
  [proof/lean/UOToolchain/IRSemantics.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSemantics.lean)):
  the placeholder `abbrev Semantics := Config → Trace` is replaced by a
  real operational evaluator type
  `abbrev Semantics := IR.OperationalConfig → IR.Outcome`. The structured
  IR mirror in `IRSyntax.lean` covers `crates/uo-core/src/{ir,types}.rs` —
  `ProgramMode`, `ContainerKind`, `BackendKind`, `StateObject`, `UnaryOp`,
  `BinaryOp`, `Expr`, `Statement`, `CompiledFunction`, `CompiledContract`,
  plus the `Value` / `Ty` universe with composite struct/array variants.
  The `IR.Outcome` carries the existing `Trace`, the entrypoint's public
  return value, the per-object ORAM-access counts, the manifest-relevant
  kernel-step list, and an explicit `EvalStatus` (`completed`,
  `requireFailed`, `abortedByUser`, `unsupported kind`, `evalError msg`).
  The W4.1 evaluator handles `Expr.{literal,var,unary,binary,select,
  cellGet}` and `Statement.{declare,assign,require,abortIf,cellSet,
  retStmt}` exactly; statements/expressions outside that subset return an
  explicit `EvalStatus.unsupported` so downstream theorems are honest
  about coverage. The abstract trace-producer abbreviation is preserved
  as `TraceSemantics := TraceConfig → Trace` so the abstract
  `ExactObjects` / `Composition` / `TeeDeployment` /
  `SgxExactProjection` / `PathOramLocalPosmapV1` / `Legacy*` composition
  theorems remain unchanged, projected over `TraceSemantics` rather than
  the new evaluator surface.
- Subtask W4.1b landed in the same commit:
  `compilerSecrecyPreservation` and `publicGasSecretIndependent` are now
  also stated against the new evaluator surface as
  `evaluatorCompilerSecrecyPreservation` and
  `evaluatorPublicGasSecretIndependent` (with a matching
  `EvaluatorPublicGasSafe` predicate over `IR.OperationalConfig`).
  The original trace-side statements remain so the abstract composition
  theorems still consume them directly.
- Subtask W4.3 (full theorem) landed (commit `08f669a`,
  [proof/lean/UOToolchain/ConfidentialFragment.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ConfidentialFragment.lean)
  and
  [proof/lean/UOToolchain/ProofGrade.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ProofGrade.lean)):
  the iff characterization
  `(IR.confidentialFragmentEntrypointWitnessOf fn).Valid ↔
  fn.fragmentValid = true` is now a Lean-proved, semantics-
  preserving theorem. The proof stack is three mutual `theorem`
  blocks (`Expr.fragmentStats_valid_iff` /
  `Expr.fragmentStatsList_valid_iff`,
  `Statement.fragmentStats_valid_iff` /
  `Statement.fragmentStatsList_valid_iff`,
  `confidentialFragmentEntrypointWitnessOf_valid_iff`) plus a paper-
  facing facade
  `proofGrade_confidential_fragment_valid_iff_structurally_valid` in
  `ProofGrade.lean`. The select-case `Expr.fragmentStats` definition
  now uses the global `cond : Bool → α → α → α` primitive instead of
  `if ... then ... else ...` on a Bool to avoid Lean's Decidable
  elaboration silently inserting `decide` wrappers. A
  `FragmentStats.forbidden_zero` predicate plus its
  `forbidden_zero_empty` / `forbidden_zero_add` simp lemmas factor
  the recurring "all three forbidden counts are zero" conjunction.
  The W4.3 charter task therefore moves from "Lean-defined
  classifier surface, deferred theorem" to "Lean-proved, semantics-
  preserving"; `uo-solc`'s Rust classifier is still the source of
  the classifier in production artifacts, so the trusted-surface
  change is "Lean now has a proved characterization theorem against
  a Lean-side mirror"; the Rust / Lean classifier agreement remains
  a source-freeze obligation (handled by the existing static-drift
  checks).
- Subtask W4.3 (definitions only) landed earlier (commit `4f30757`,
  [proof/lean/UOToolchain/ConfidentialFragment.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ConfidentialFragment.lean)):
  the structural confidential-fragment classifier surface is now
  Lean-defined.
  `IR.branchlessPureExpr` characterises the kernel-DSL branchless-
  pure expression surface; `IR.Expr.fragmentValid` /
  `IR.Statement.fragmentValid` /
  `IR.CompiledFunction.fragmentValid` decide structural validity (no
  `Expr.structField`, no `Expr.arrayIndex`, no non-branchless
  `Expr.select`); `IR.Expr.fragmentStats` /
  `IR.Statement.fragmentStats` /
  `IR.CompiledFunction.fragmentStats` are the count-based classifier
  mirroring `crates/uo-core/src/fragment.rs`;
  `IR.confidentialFragmentEntrypointWitnessOf` builds the count-based
  witness from a structured function; and
  `FragmentStats.add_zero_forbidden_iff` is a primitive split lemma.
  The W4.3 characterization theorem
  `(confidentialFragmentEntrypointWitnessOf fn).Valid ↔
  fn.fragmentValid` is deferred to a follow-up commit because the
  natural proof strategy uses structural induction on `Expr` /
  `Statement`, which Lean 4.30.0-rc2's default `induction` tactic
  does not support for nested-inductive types; the follow-up commit
  will use `Expr.recOn` / `Statement.recOn` directly or restructure
  the IR data types as explicitly mutual inductives.
- Subtask W4.1+ (evaluator coverage extension) landed (commit
  `9f0e45e`,
  [proof/lean/UOToolchain/IRSemantics.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSemantics.lean)):
  `evalContract` now also handles
  `Statement.{ifStmt,forLoop,arraySet,mapPut}` and
  `Expr.arrayGet`, with `evalStatement`/`evalBody`/`evalForLoop` in a
  single `mutual` block so that `ifStmt` / `forLoop` can recurse into
  nested statement bodies.
- Subtask W4.1+++ (store-update threading) landed (commit `b4442f7`,
  [proof/lean/UOToolchain/IRSemantics.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSemantics.lean)):
  `evalStatement` / `evalBody` / `evalForLoop` now thread the updated
  `OperationalConfig` so that `cellSet` / `arraySet` / `mapPut` actually
  modify the store, and so a later `cellGet` / `arrayGet` / `mapGet`
  observes the written value. The masked-store semantics writes when
  the predicate is `none` or evaluates to `true`, and leaves the store
  unchanged when the predicate is `false`; the kernel step (`CellSet`,
  `ArraySet`, `MapPut`) is recorded unconditionally, mirroring the
  runtime's always-write access pattern. New helpers
  `OperationalConfig.{objectIsConfidential,writeObject,readObject}`
  and `Value.{arraySetAt,mapInsert}` keep store-routing (public vs
  secret based on `StateObject.confidential`) and structured value
  updates clean. `evalContract` discards the final `cfg` and returns
  the outcome unchanged.
- **Charter task 4 (IR-to-kernel correctness) closed end-to-end**
  (commit `9f0fd7b`): the per-Statement, list-level (`evalBody`),
  and program-level (`evalContract`) preservation theorems are now
  all Lean-proved, with paper-facing facades
  `proofGrade_ir_to_kernel_statement_preservation`,
  `_body_preservation`, and `_program_preservation` in
  `ProofGrade.lean`. The program-level theorem
  `lowerCompiledFunction_preserves_semantics` certifies that for
  any `OperationalConfig` whose entrypoint resolves to a function
  `fn`, if `lowerCompiledFunction fn = .ok kp` then
  `evalContract cfg = evalKernelProgram kp cfg`. Combined with
  the W4.4 Session B-1 forward iff
  (`kernelLowerable_implies_lowerCompiledFunction_ok`), this
  gives the W4.4 charter deliverable: every kernel-lowerable
  program admitted by the W4.3 fragment classifier evaluates the
  same way under the IR semantics and the kernel-DSL semantics.
- Subtask W4.4 Session B-2 (per-Expr semantics-preservation
  theorem) landed (commits `de979bb` for the partial→def
  evaluator refactor, `326d710` for the proof, `849c1ae` for the
  ProofGrade projection). The W4.1 / W4.4 Session A evaluators
  (`evalExpr`, `evalExprList`, `evalStatement`, `evalBody`,
  `evalForLoop`, `evalKernelExpr`, `evalKernelPureExpr`,
  `evalKernelExprList`, `evalKernelPureExprList`,
  `evalKernelStatement`, `evalKernelBody`) are now `def` (not
  `partial def`) so their equations reduce by `rfl` / `simp` /
  `unfold`. The for-loop case in `IRSemantics.lean` uses an
  explicit `(sizeOf body, endN - i)` lex measure for well-founded
  recursion. The full per-Expr semantics-preservation theorem
  `IR.lowerExpr_preserves_semantics` (with mutual companions
  `lowerExprList_preserves_semantics`,
  `lowerPureExpr_preserves_semantics`,
  `lowerPureExprList_preserves_semantics`) covers all 11 `Expr`
  constructors. Each inductive case case-splits on the
  sub-lowering's success/error, extracts the kernel-side witness
  via `Except.ok.inj`, substitutes via `subst`, then unfolds both
  evaluators and applies the IH. The
  `select` and `arrayGet` / `mapGet` cases additionally case-split
  on the evaluated condition or storage value to align the IR-side
  inline lookups with the kernel-side `OperationalConfig.readObject`
  helper. A paper-facing facade
  `proofGrade_ir_to_kernel_expr_preservation` (and a pure-expression
  variant) re-exports through `ProofGrade.lean`.
- Subtask W4.4 Session B-1 (forward-direction lowering iff
  theorems) landed (commits `1be2c58`, `90e9cde`, `1dcd8ef`,
  [proof/lean/UOToolchain/KernelDsl.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/KernelDsl.lean)):
  the forward-direction lowering iff theorems are now Lean-proved
  at all four levels — `branchlessPureExpr_implies_lowerPureExpr_ok`
  / `…List_…_ok` (mutual), `fragmentValid_implies_lowerExpr_ok` /
  `…List_…_ok` (mutual), `kernelLowerable_implies_lowerStatement_ok`,
  `kernelLowerableScheduleAux_implies_lowerStatementsAux_ok`,
  `kernelLowerableSchedule_implies_lowerStatements_ok`, and the
  program-level `kernelLowerable_implies_lowerCompiledFunction_ok`.
  The schedule-level proof case-splits on `stmt.isReturn` (now
  factored out as a top-level `Statement.isReturn` helper) and on
  the structure of `rest`. The reverse direction of the iff
  (lowering succeeds → precondition holds) is deferred — it is
  useful for W4.6 (artifact-checker demotion) but not strictly
  required by the W4.4 preservation theorem. Session B-2 (the
  preservation theorem itself) and Session C (paper-facing facade)
  remain open.
- Subtask W4.4 Session A (kernel DSL definitions) landed (commit
  `1bd6180`, new file
  [proof/lean/UOToolchain/KernelDsl.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/KernelDsl.lean)):
  typed Lean mirror of the kernel DSL types
  (`IR.KernelExpr` / `KernelPureExpr` / `KernelStatement` /
  `KernelProgram`) using `IR.UnaryOp` / `IR.BinaryOp` / `IR.Ty`
  instead of the JSON-typed `RuntimeKernelDslJson.lean` versions, so
  operational semantics is well-defined; operational semantics
  (`evalKernelExpr` / `evalKernelPureExpr` / `evalKernelStatement` /
  `evalKernelBody` / `evalKernelProgram`) sharing the same
  `IR.Outcome` / `OperationalConfig` / `LocalEnv` types as the
  IR evaluator (so the W4.4 preservation theorem can be a literal
  outcome equality); IR-to-kernel lowering definitions
  (`lowerExpr` / `lowerPureExpr` / `lowerStatement` /
  `lowerStatementsAux` / `lowerStatements` /
  `lowerCompiledFunction`) mirroring the Rust
  `lower_confidential_kernel_*` functions; lowering precondition
  predicates `Statement.kernelLowerable` /
  `Statement.kernelLowerableSchedule` /
  `CompiledFunction.kernelLowerable`; and a structural corollary
  `branchlessPureExpr_implies_fragmentValid`. Deferred to Session B:
  the lowering succeeds-iff-precondition theorems (forward
  direction needed by the preservation theorem) and the
  semantics-preservation theorem itself.
- Subtask W4.1++ (evaluator value-model gaps closed) landed (commit
  `2a6aa8b`,
  [proof/lean/UOToolchain/IRSyntax.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSyntax.lean)
  and `IRSemantics.lean`): `Value.map (entries : List (Value × Value))`
  added, plus a manual `Value.beq` (with mutual companions
  `beqList` / `beqStructFields` / `beqMapEntries`) registered as a
  `BEq Value` instance, plus `Value.mapLookup` and a deterministic
  `Value.keccak256Mock` placeholder. `evalExpr` now handles
  `Expr.mapGet` (search `Value.map` entries by key) and
  `Expr.keccak256` (evaluate parts in order, apply the mock). The
  W4.1 evaluator is now total over the structural admitted fragment;
  the only `unsupported` constructors are `Expr.{structField,
  arrayIndex}`, which `Expr.fragmentValid` already rejects.
- **Charter task 2 (source-to-IR correctness) closed end-to-end at
  the program level for the full admitted post-resolution Sol AST**
  (commits `1ec7da6` + `d267e80`,
  [proof/lean/UOToolchain/Sol.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/Sol.lean)):
  a typed Lean mirror of the post-resolution Sol AST that `uo-solc`
  produces — covering literals, variables, unary / binary /
  conditional expressions, `keccak256`, declare / assign-to-local /
  require / abortIf / if / for / return statements (the source-
  syntax constructors), plus the resolved-state constructors
  `cellGet` / `arrayGet` / `mapGet` / `structField` / `arrayIndex` /
  `cellSet` / `arraySet` / `mapPut` carrying the object id /
  predicate that the parser's name-resolution pass has filled in.
  An operational semantics (`Sol.evalExpr` / `evalStatement` /
  `evalBody` / `evalForLoop` / `evalFunction`) defined with `def` +
  `termination_by` reduces by `rfl` / `unfold + rw`, mirroring the
  W4.4 evaluator style and matching every IR evaluator branch
  exactly. The AST → IR lowering (`lowerExpr` / `lowerStatement` /
  `lowerStatementList` / `lowerFunction`) maps each Sol constructor
  to its same-named IR counterpart constructor-for-constructor. The
  per-Expr / per-Statement / Body / Function preservation theorems
  are Lean-proved end-to-end in the Session B-2 style; the
  Function-level theorem is conditional on the IR config's
  entrypoint resolving to the lowered function (the same
  precondition shape as the W4.4 program-level theorem). Paper-
  facing facades `proofGrade_sol_to_ir_{expr,statement,body,
  program}_preservation` re-export through `ProofGrade.lean`.
  Combined with `proofGrade_ir_to_kernel_program_preservation`,
  this completes the source-to-kernel correctness chain at the
  full admitted Sol AST. The parser-level transformations that
  precede the Sol AST (state-name resolution, capacity literal
  lookup, `abi.encodePacked` unwrapping, helper-function inlining,
  `AssignAdd`-style desugaring) are syntactic preprocessing that
  belong to the trusted `solang_parser` step; the entire semantic
  Sol → IR step is now Lean-proved with no remaining surface.
- Still open: the manifest-exactness semantics-preserving lift
  (W4.5), the direct artifact checker demotion (W4.6), and the
  reverse direction of the W4.4 lowering iff (lowering succeeds →
  precondition holds; useful for W4.6 but not strictly required by
  the preservation theorem).

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
   runtime-kernel refinement and secret confinement, including the stronger
   shared-kernel implementation boundary below the outer `uo-evm` split.
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
6. Completed at the outer runtime boundary, and now strengthened one layer
   lower: discharge the real-runtime honesty gap for the chosen
   proof/interface route by pairing the exact
   `RuntimeKernelRefinementBoundary` /
   `RuntimeKernelInterfaceSlotBoundary` /
   `RuntimeKernelConfinementBoundary` objects with the source-backed
   `RuntimeImplementationInterface` and the combined
   `RuntimeImplementationConfinementBoundary`, plus the smaller
   `RuntimeImplementationSharedKernelRefinementBoundary` that pairs the
   checked inner shared-kernel source cut with the emitted
   `RuntimeConfidentialCoreKernelFinishSlotBundle`, plus direct positive
   reports and tamper rejections for representative confidential-bypass drift.
   The checked implementation boundary now also pins delegation into the
   shared `uo-core` confidential-kernel interpreter / masked-selection layer
   and rejects representative shared-kernel secret-branch drift,
   representative Path ORAM lookup/update/stash-rebuild drift, the older
   conditional fresh-leaf schedule, and statement-trace drift both on the
   source side and at the smaller finish-slot artifact boundary.
7. Completed: prove that the non-kernel shell is public-only and package that
   shell contract together with the exact proof-grade boundary facts needed by
   the confidential-core argument.
8. Active next item after the strengthened 6-7 route: continue the below-
   interface shared-kernel story after the Lean-first generated-kernel landing.
   The live slot-program/block/statement evaluator, operator semantics,
   profile tables, and the private confidential argument / slot-file support
   are now generated from Lean and exact-source checked. The residual
   handwritten shared-kernel adapter is now source-checked as a forwarding-only
   shell, and the runtime machine effect schedule is source-checked for public
   opcode recording, bounded scratch reservation, object-store delegation,
   commit-schedule append, and finish-time wiping, with a Lean
   `RuntimeKernelMachineSchedule` model for the public-opcode prefix,
   bounded-scratch, object-store-call, commit-append, and finish-wipe shape.
   The boundary now also imports `runtime/uo-allocator/src/lib.rs` and checks
   the allocator session's kernel-op/scratch/stack budgets, guard-drop wipe,
   finish-time wipe validation, bounded public-capacity resource-event log,
   boxed finish-boundary resource events, and lack of unsafe/forget-style
   escape hatches, with `RuntimeAllocatorDiscipline` proving the accepted
   allocator transition shape. The resource-event log now also validates its
   public length/capacity and populated public-prefix entries explicitly
   instead of relying on a prefix-populated `expect`. The live confidential
   statement recorder is now an exact-capacity kernel-owned buffer checked
   against `RuntimeStatementTraceDiscipline` rather than a growable
   `Vec<String>`; the model now carries the recorded trace-name list, proves
   capacity rejection, per-record public trace-name append, and exact boxed
   trace equality with the slot program's public statement trace. The live
   recorder implementation now records through checked slots and finishes/drops
   initialized entries through iterator-limited fixed buffers rather than
   direct `trace[index]` / `self.statements[index]` access or initialized-prefix
   slicing.
   The same checked source path now pins named/slot confidential-kernel program
   bodies and Keccak part lists to boxed fixed-shape slices, with source and
   named-to-slot lowering routed through `FixedBoxBuilder` rather than
   temporary growable collection.
   The shared `uo-core` value layer now uses 64-bit canonical length prefixes
   for aggregate value encoding/decoding instead of panicking on `u32`
   conversion, and proof-object JSON / trace-hash helpers return fallible
   results rather than assuming serialization cannot fail.
   Path-ORAM write evidence, UO small-map lookup, UO array access, and generated
   confidential-kernel return scheduling now have their own
   source-pinned/model-backed cuts (`RuntimeOramWriteLogDiscipline`,
   `RuntimeSmallMapLookupDiscipline`, `RuntimeArrayAccessDiscipline`, and
   `RuntimeReturnScheduleDiscipline`), including fixed-public-batch ORAM writes,
   masked full-scan small-map lookup with exact matched-fold semantics and
   public-capacity length rejection, masked full-scan UO array reads/writes,
   executable selected-slot acceptance/rejection/uniqueness, UO-path
   out-of-range no-match / no-op behavior, rejection of non-final source
   returns, and removal of generated post-return interpreter breaks. The UO
   cell/array/small-map commit-control skeleton now also routes through the
   Lean-generated object-helper layer; the exact secret-bearing open/bootstrap/
   reseal shell for both objects and ORAM now lives in that exact-source-
   checked generated helper module, including the object-side typed
   value/map open/bootstrap/commit wrappers that used to live in `objects.rs`
   while the exact-size map-record, directory-page, scalar-metadata, block,
   bucket, stash-page, Path-ORAM metadata-page encode/rewrite/open,
   bucket-payload validation, public ORAM geometry/addressing helpers, and the
   masked Path-ORAM selector / fixed-capacity stash-rebuild helper stack that
   used to live in `oram.rs`
   now lives in the dedicated Lean-generated
   `runtime/uo-evm/src/generated_oram_codecs.rs` module. That generated ORAM
   surface has been narrowed further: Path-ORAM `MaskedUsizeOption` metadata
   is no longer `Clone`/`Copy`, metadata clone/assign/select/repeat operations
   go through generated borrowed helpers, and the old generic
   `repeat_boxed<T: Clone>` helper has been replaced by typed generated
   builders such as `repeat_boxed_masked_usize_options` and
   `repeat_boxed_empty_byte_boxes`. The source-backed implementation
   interface and drift suite reject the old broad metadata clone/copy and
   generic-repeat patterns explicitly. The generated map read/write surface has
   also been strengthened: UO small-map capacity overflow, Path-ORAM read-side
   working-stash overflow, and Path-ORAM update/insert failure now return
   confidential overflow/update-failed bits from the generated helpers, and the
   Lean-generated confidential-kernel interpreter folds those bits through its
   generated `note_abort_generated(...)` helper instead of exposing a
   secret-conditioned host `Result` error or a handwritten masked abort update.
   The source-backed interface and probe now reject the old generated `bail!`
   branches for small-map full, missing ORAM block on a selected slot,
   Path-ORAM stash insert/working-stash failure, and surrogate insert-capacity
   failure. WP3 now also includes an explicit generated-helper
   host-visible error taxonomy: remaining `Result` failures are pinned as
   public-shape/public-capacity, authenticated decode/integrity,
   cold-restore, fresh-coin tape, or write-log discipline errors, and the old
   deterministic hidden-state capacity/update misses are rejected even if the
   Lean generators and generated Rust drift together. The Path-ORAM side is
   now pinned
   both at the restore-vs-exact-write-batch split and at the generated
   `with_opened_oram_payload` / `seal_boxed_oram_payload` /
   `filler_boxed_oram_payload` / `reseal_oram_payload_and_record_write`
   helper shell, whose write evidence is now reduced to public
   `push_update(location, physical_len)` batches rather than prior/new
   ciphertext snapshots. The generated write-log producer now fills public
   prefix slots through fallible `log.writes.get_mut(log.len)` access and
   validates the public prefix through `log.writes.get(index)` before exposing
   an exact batch. The handwritten object consumers now enumerate those
   batches only through `OramWriteBatch::for_each_write(...)`, which checks
   that the public batch length is within capacity, uses fallible
   `self.writes.get(index)` prefix access, and requires every public
   prefix slot to be populated before emitting a physical-write trace; the
   source-backed boundary rejects the old direct indexing and lossy
   `filter_map(Option::as_ref)` path and the old unchecked
   `physical_writes.iter()` / `writes.iter()` consumers. The same boundary now
   also rejects the old handwritten object direct-index shell: raw array
   get/set and commit now guard public value/physical/written-flag slots with
   `get(...)` / `get_mut(...)`, UO array and small-map commit closures obtain
   physical slots through fallible public schedule lookups, and UO small-map
   scan tracing no longer indexes the physical-slot array directly. The
   source-backed interface pins both the new guarded patterns and the absence
   of the stale `values[index]`, `physical_slots[index]`, and
   `written_slots[index]` forms in `objects.rs`. The same boundary now
   also checks that the full production `RuntimeImplementationInterface`
   source surface avoids `expect(`, `unwrap(`, and `panic!`, including
   generated object/ORAM/store helpers, `uo-allocator`, `uo-store`, and the
   shared `uo-core` trace/types/confidential-kernel support files; the focused
   `runtime_implementation_kernel_machine_confinement_boundary_validation.json`
   report exposes these as
   `oram_write_batch_iteration_is_checked` and
   `runtime_interface_production_avoids_panic_style_control_flow`, with the
   narrower `handwritten_runtime_production_avoids_panic_style_control_flow`
   bit retained for the local `uo-evm` handwritten shell, and
   `handwritten_runtime_lacks_direct_secret_ops` confirms production
   handwritten runtime sources no longer contain direct confidential value ops,
   masked-select abort updates, canonical secret serialization, hidden option
   declassification, `Value::zero_for_type(...)`, or `MapEntry::new(...)`;
   the same claim is separately exposed as the Lean theorem/report bit
   `handwritten_runtime_lacks_direct_secret_ops_theorem_checked`. The stronger
   generated-value-op side of that claim now also routes struct-field zero
   materialization, canonical byte-buffer writes, scalar canonical decoding,
   length-word parsing, `u128` tail writes, and masked byte-array
   select/equality through generated checked-range and iterator helpers, while
   the source boundary rejects the old direct `fields[index]`,
   `copy_from_slice(...)`, fixed-slice, and per-byte index forms in
   `generated_value_ops.rs`; the shared handwritten `FixedBoxBuilder<T>`
   backing boxed value construction now uses iterator initialization,
   checked `get_mut(...)` push, and iterator-limited drop cleanup rather than
   direct uninit-slot indexing or initialized-prefix slicing. That generated
   value-operation layer now also has a dedicated Lean semantics module,
   `RuntimeValueOpsSemantics`, covering scalar canonical byte lengths, the
   32-byte `u128` canonical field shape with a zero high prefix, masked
   bool/byte-array selection, and fixed-capacity byte-buffer extend/finish
   behavior. The direct machine-confinement boundary exports these as
   paper-native theorem/report bits, so the value layer is no longer checked
   only by source equality to the generator. The stronger
   split theorem/report bit
   `handwritten_host_coordination_lacks_secret_serialization_theorem_checked`
   now checks the handwritten host-coordination slice directly: engine,
   runtime bridge, fresh-coin, controller, state, object, ORAM, theorem,
   allocator, precompile, store coordination, and non-generated shared
   core proof/evidence/type carrier sources must not contain Keccak/canonical
   serialization, direct confidential value operations, hidden option
   materialization, `Value::zero_for_type(...)`, or `MapEntry::new(...)`. The
   confidential admission path now also rejects any raw-backend object id in
   the confidential slot-program kernel-step schedule, `uo-solc` performs the
   same check when it lowers a confidential entrypoint, and the direct Lean
   proof-grade translation checker exports the corresponding non-raw target
   theorem. Raw public state therefore cannot be used as a secret-dependent
   write/read target under the WP3 theorem route. The
   public shell is intentionally outside that slice because its remaining
   canonical hashing is guarded by the separate
   public-only/confidential-call rejection theorem. The ordered source theorem
   `public_shell_canonical_hashing_guarded_by_public_entry_theorem_checked`
   now pins that public shell exception directly by checking that the
   `eval_expr` confidential-function rejection appears before the
   `Expr::Keccak256` canonical-hashing branch; the direct kernel-machine
   scenarios emit the same bit next to `public_bridge_boundary_theorem_checked`.
   Generated helpers are the intended small confidential kernel surface.
   The lower-level
   store side is now pinned at the Lean-generated
   `runtime/uo-store/src/generated_store_helpers.rs`
   `filler_boxed_uo_store_slot` / `reseal_uo_store_slot_in_place` helper shell,
   and the exact-size store seal/open/filler surface that used to live in
   `runtime/uo-store/src/codec.rs` now lives in the dedicated
   Lean-generated `runtime/uo-store/src/generated_surface.rs` module.
   The residual helper-shell boundary now also carries theorem-facing codec
   semantics instead of only source-string equality: `RuntimeStoreCodecSemantics`
   proves the exact-size nonzero transport length, nonzero-nibble invariant,
   successful-decode soundness, fixed-public-length decode-into roundtrip,
   encoded-length-mismatch rejection and decoded-byte/nonzero-nibble soundness,
   encode/decode roundtrip for valid bytes,
   sealed plain/encoded length formulae, sealed UO-slot ciphertext shape, and
   public UO update-write shape. The same store semantics module now also
   models the generated store surface below the handwritten codec shell:
   zeroed exact-size buffers, exact-range reads, exact-copy staging,
   exact-length seal-into-slice acceptance/rejection, opened-payload shape, and
   wipe length/zeroing discipline are exposed through both the standalone
   residual-helper boundary and the direct machine-confinement route. Meanwhile
   `RuntimeOramCodecSemantics` states the public block/bucket/directory-page
   geometry, exact public count-guard acceptance/rejection, ORAM counter field
   semantics, and connects well-formed ORAM objects to the generated
   bucket-size formula used by the runtime. The
   `RuntimeOramHelperSemantics` module now pushes below those byte codecs into
   the generated ORAM helper operations themselves: masked Nat/Bool/option
   selection, first-match slot lookup, vacant-slot allocation, fixed-stash
   clear/push/overflow/take shape, position-map leaf/value selection,
   fresh/prior access-leaf selection, position-map/stash leaf updates, public
   failed-put cases, path-bucket rebuild length/live-count bounds, fixed
   path-access physical-read count, and the `rewrite_path_for_access` public
   shell shape for fixed physical-write count, counter increment, and
   load/effect/post-update/post-rebuild failure propagation are all modeled in
   Lean. The transition-witness kind is also modeled as masked selection with
   read-hit/read-miss cases and write-delete/update/insert/noop precedence
   rather than only source-frozen Rust, and the witness payload shape now covers
   slot/prior-leaf/next-leaf/fresh-leaf fields for read miss/hit and
   delete/update/insert/noop write cases. These facts are projected through the
   residual-helper boundary and direct machine-confinement route, and emitted as
   `oram_helper_*_theorem_checked` report bits. The static checker
   now requires both the residual-helper-shell and direct machine-confinement
   ORAM-helper theorem families, so this helper layer is no longer only a
   source-string equality claim.
   The
   ORAM write-log model now also has an update-only transition whose zero-write
   counter is invariant, and the source boundary rejects generated ORAM write
   evidence that classifies ciphertext bytes with `PhysicalWriteEvent::from_buffers`
   or `classify_write`.
   These facts are not extra paper assumptions: the
   `RuntimePaperNativeKernelAssumptions` facade now derives
   `storeCodecRoundtrip` and `oramBucketBytesMatchCodec` from the existing
   residual helper-shell boundary. The same facade now also derives the
   nonzero transport shape, sealed-record length formula, sealed-record
   decode split shape, sealed-record open magic-header shape and
   open-transport soundness for the split sealed-record components plus
   sealed-record transport roundtrip, sealed UO-slot ciphertext shape,
   public UO update-write shape, public ORAM block/bucket/directory-page
   length formulae, exact public count-guard acceptance/rejection,
   codec-vs-runtime block/bucket formula agreement,
   positive path-position-map page count, concrete surrogate/path bucket
   codec-size agreement, block-list encode/decode shape and aggregate
   block-list encode/decode roundtrip,
   ORAM counter encode/decode acceptance, fixed-width length, and encoded
   byte-validity,
   ORAM block
   encode/decode roundtrip, exact-length ORAM block decode/roundtrip,
   decoded-block valid-shape facts, aggregate decoded bucket/stash block
   valid-shape facts, ORAM bucket encoded length,
   exact-bucket encode/decode roundtrip,
   exact-bucket decode acceptance tying byte length, expected bucket index,
   block decoding, and live-count agreement together, bounded Path bucket
   decode for occupied block slot/leaf bounds and public bucket-on-leaf-path
   membership plus decoded position-map agreement and duplicate live-slot
   rejection plus position-map live-slot coverage and generic whole-block-list
   agreement/no-duplicate hooks, lower-level Path-ORAM position-map
   leaf/entry/page-list decode-shape facts, Path-ORAM position-map
   page coverage/capacity acceptance, exact position-map page decode
   acceptance, exact position-map page and page-list encode/decode
   roundtrips, public
   metadata page split, aggregate position-map-pages decode
   acceptance, position-map page byte-length mismatch rejection,
   position-map page-list public page-count mismatch rejection, exact
   stash-page decode acceptance, exact stash-page byte-length mismatch
   rejection, stash page-list public page-count mismatch rejection, exact stash-page
   and stash-pages encode/decode roundtrips, aggregate stash-pages decode
   shape/block validity, bounded aggregate stash decode for public
   stash/slot/leaf bounds, stash position-map agreement, stash duplicate
   live-slot rejection, and Path-ORAM position-map/stash page
   padding-length facts from that boundary. The generated ORAM metadata
   decoder now checks the public position-map/stash page counts before
   indexing and uses fallible `pages.get(...)` access; the matching metadata
   encoder now fills the sealed page array through fallible
   `pages.get_mut(next_page)` access instead of direct page-slot assignment.
   The generated ORAM block, bucket, counter, stash-page, and position-map
   byte codecs now route fixed-offset reads/writes through checked
   `read_exact_range` / `write_exact_range` and `read_u64_be_at` /
   `write_u64_be_at` helpers, including checked bucket-payload windows,
   instead of direct byte indexing, local copy staging, or fixed-offset slicing.
   The generated object-helper map-record and surrogate-directory codecs now
   follow the same discipline: map-record tag/key/value windows and directory
   record slots are checked with exact-range helpers and `get_mut(...)`, and
   the source boundary rejects the old `out[0]`, fixed byte-slice, and
   `out[slot]` decode paths.
   The generated `uo-core` value-operation layer follows the same checked
   iterator/exact-range rule for struct-field zero materialization, canonical
   byte-buffer writes, scalar canonical decoding, length words, and masked
   byte-array operations, so the source boundary rejects stale direct
   `fields[index]`, `copy_from_slice(...)`, fixed-slice, and
   `selected[index]` / `lhs[index]` byte loops there too. The shared
   `FixedBoxBuilder<T>` helper
   under that value layer likewise avoids direct slot indexing and prefix
   slicing by using iterator initialization, checked `get_mut(...)` push, and
   iterator-limited drop cleanup.
   The generated transcript/open/reseal paths check public directory-page and
   bucket counts before accessing storage pages through `get(...)` /
   `get_mut(...)`, surrogate directory decoding takes the remaining public
   entry tail through `entries.get_mut(next_entry_index..)`, and bucket /
   position-map decode and live-bucket construction use fallible
   `fixed_blocks.get_mut(slot)` / `position_map.get_mut(next_slot)` slots
   before writing decoded or selected blocks. The generated live Path-ORAM
   bucket validator also checks the public
   position-map and live-slot buffer lengths against capacity before using the
   decoded slot index through fallible `position_map.get(...)`,
   `live_slots.get(...)`, and `live_slots.get_mut(...)` access. Lean now also
   pins the validator's live-slot update discipline directly: unoccupied
   blocks are no-ops, valid occupied blocks replace exactly the decoded live
   slot with the decoded leaf, and occupied blocks with out-of-range slot
   indexes or duplicate live-slot occupancy are rejected. The final
   reconstruction coverage check is modeled as well: empty position maps
   accept, missing live-slot buffer entries reject, absent position-map heads
   are ignored, present heads with live slots continue, and present heads with
   empty live slots reject. The Path-entry reconstruction side is modeled at
   public shape level too: reset produces exactly `capacity` empty cells,
   unoccupied decoded blocks leave the entry buffer unchanged, occupied
   out-of-range slots reject, and valid occupied blocks preserve length while
   making exactly the decoded public slot point to the decoded block cell.
   Lean also exposes the combined reconstruction loop-body step: prior failures
   stay failed, unoccupied blocks leave the state unchanged, validation or
   install failures set the failed flag, and valid occupied blocks update both
   the live-slot buffer and entry buffer at the same decoded public slot. The
   final reconstruction result predicate is modeled as the disjunction of the
   step-failure flag and live-slot coverage failure, with the corresponding
   success theorem requiring both to be false. Lean also models the surrounding
   decoded-block-list fold: empty lists preserve the reconstruction state, cons
   lists execute one loop-body step and then the tail, and prior failure is
   absorbing across the remaining public block list. The whole decoded
   reconstruction shell is modeled too: initial reconstruction allocates exactly
   `capacity` empty live slots and entry cells with no failure flag, the state
   is exactly the stash fold followed by the decoded bucket-block fold,
   stash-side failure absorbs the bucket phase, and the final failure Boolean
   is exposed for prior-failure and success cases. The bucket phase now also
   has a bucket-indexed Lean variant that matches the runtime gate rejecting
   any occupied decoded bucket block whose leaf is not on that public bucket
   path before reconstruction; admitted bucket blocks reduce to the ordinary
   block-step semantics. The bridge between codec-level decoded path bucket
   payloads and the bucket-indexed helper reconstruction is now also explicit
   on both sides of the proof boundary: each `RuntimeOramCodecSemantics.CodecBlock`
   lifts canonically to a helper `StashBlock` (occupancy from the codec tag,
   slot/leaf from `decodeNatField`), each codec block paired with a public
   bucket index lifts to a helper `BucketBlock` preserving that bucket index,
   and the per-list bridge keeps the public block count and composes with
   `BucketBlock.block`. Codec blocks proven `LiveOnBucketPath` admit into the
   helper bucket-block reconstruction without short-circuit, all-`LiveOnBucketPath`
   lifted bucket-block lists admit pointwise, the bucket-indexed reconstruction
   collapses to the flat block reconstruction over the bridged stash list, and
   the bucket-indexed reconstruction state and final failure predicate over a
   decoded bucket payload coincide with the flat-list state and predicate.
   These bridge theorems are projected through the residual-helper-shell
   boundary, the direct machine-confinement boundary, and the imported JSON
   checker, and emitted as
   `oram_helper_bucket_block_of_codec_block_bucket_index_theorem_checked`,
   `oram_helper_bucket_block_of_codec_block_block_theorem_checked`,
   `oram_helper_stash_blocks_of_codec_blocks_length_theorem_checked`,
   `oram_helper_bucket_blocks_of_codec_blocks_length_theorem_checked`,
   `oram_helper_bucket_blocks_of_codec_blocks_map_block_theorem_checked`,
   `oram_helper_bucket_block_admission_failed_bridge_unoccupied_theorem_checked`,
   `oram_helper_bucket_block_admission_failed_bridge_live_on_bucket_path_theorem_checked`,
   `oram_helper_bucket_blocks_of_codec_blocks_admitted_of_live_on_bucket_path_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_blocks_eq_reconstruct_path_blocks_of_admitted_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_blocks_bucket_blocks_of_codec_blocks_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_state_bucket_blocks_of_codec_blocks_theorem_checked`,
   and
   `oram_helper_reconstruct_path_decoded_buckets_failed_bucket_blocks_of_codec_blocks_theorem_checked`.
   The bridge now also composes directly with the codec acceptance theorems
   `decodePathBucketPathBoundedExact_some_shape`,
   `decodePathBucketPositionMapBoundedExact_some_shape`, and
   `decodePathBucketUniquePositionMapBoundedExact_some_shape`, so once
   path-bucket bytes decode through any of those exact-decoders the
   bucket-indexed reconstruction state and final failure predicate over the
   bridged bucket blocks already coincide with the flat-list reconstruction
   over the bridged stash blocks without restating `LiveOnBucketPath` per
   call site. Those composed theorems land at every layer and are emitted as
   `oram_helper_reconstruct_path_decoded_buckets_state_decoded_path_bucket_path_bounded_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_failed_decoded_path_bucket_path_bounded_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_state_decoded_path_bucket_position_map_bounded_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_failed_decoded_path_bucket_position_map_bounded_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_state_decoded_path_bucket_unique_position_map_bounded_theorem_checked`,
   and
   `oram_helper_reconstruct_path_decoded_buckets_failed_decoded_path_bucket_unique_position_map_bounded_theorem_checked`.
   Lean now also models the runtime decoded-bucket callback fold directly
   through `reconstructPathDecodedBucketsListState` /
   `reconstructPathDecodedBucketsListFailed` over a `List DecodedBucket`
   (each carrying a public bucket index plus a codec-decoded payload), with
   `DecodedBuckets.LiveOnBucketPath leafCount decodedBuckets` capturing the
   per-bucket admission hypothesis. Under that hypothesis the list-level
   state and final failure collapse exactly to the flat-list state and
   failure over the bridged stash blocks; companion theorems expose
   `reconstructPathBucketBlocks_append`, `reconstructPathBlocks_append`,
   prior-failure absorption, success acceptance, and the no-buckets initial
   state. These facts land at every layer and are emitted as
   `oram_helper_reconstruct_path_bucket_blocks_append_theorem_checked`,
   `oram_helper_reconstruct_path_blocks_append_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_blocks_bucket_blocks_of_decoded_buckets_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_list_state_live_on_bucket_path_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_list_failed_live_on_bucket_path_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_list_failed_prior_failure_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_list_failed_success_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_list_state_no_buckets_theorem_checked`,
   and
   `oram_helper_reconstruct_path_decoded_buckets_list_failed_no_buckets_theorem_checked`.
   Runtime call sites can also build
   `DecodedBuckets.LiveOnBucketPath` directly from per-bucket codec
   acceptance: `decodedBuckets_liveOnBucketPath_cons` extends a tail proof
   with one head fact, and the three
   `decodedBucket_liveOnBucketPath_of_decodedPathBucket{Path,PositionMap,UniquePositionMap}Bounded`
   lemmas each derive the head from a single matching codec acceptance. These
   primitives land at every layer and are emitted as
   `oram_helper_decoded_buckets_live_on_bucket_path_cons_theorem_checked`,
   `oram_helper_decoded_bucket_live_on_bucket_path_of_decoded_path_bucket_path_bounded_theorem_checked`,
   `oram_helper_decoded_bucket_live_on_bucket_path_of_decoded_path_bucket_position_map_bounded_theorem_checked`,
   and
   `oram_helper_decoded_bucket_live_on_bucket_path_of_decoded_path_bucket_unique_position_map_bounded_theorem_checked`.
   The reconstruction shell now carries the absolute-capacity invariant on
   both the live-slots buffer and the path-entry buffer: each
   block-validation/install step, each per-bucket admission step, both
   list-folds, the decoded-buckets shell, and the runtime callback fold all
   preserve `liveSlots.length` and `entries.length`, so starting from
   `initialReconstructionState capacity` both buffers stay exactly
   `capacity` throughout the entire reconstruction. These length invariants
   land at every layer and are emitted as
   `oram_helper_live_slots_after_block_validation_length_theorem_checked`,
   `oram_helper_reconstruct_path_block_step_live_slots_length_theorem_checked`,
   `oram_helper_reconstruct_path_block_step_entries_length_theorem_checked`,
   `oram_helper_reconstruct_path_blocks_live_slots_length_theorem_checked`,
   `oram_helper_reconstruct_path_blocks_entries_length_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_block_step_live_slots_length_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_block_step_entries_length_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_blocks_live_slots_length_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_blocks_entries_length_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_state_live_slots_length_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_state_entries_length_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_list_state_live_slots_length_theorem_checked`,
   and
   `oram_helper_reconstruct_path_decoded_buckets_list_state_entries_length_theorem_checked`.
   Per-step non-failure preservation also holds: starting from a non-failed
   state, when validation and install both succeed for the running buffers,
   the post-step state remains non-failed. This holds for the basic block
   step and, under bucket-on-leaf-path admission, for the bucket-block step,
   landing as
   `oram_helper_reconstruct_path_block_step_preserves_non_failure_theorem_checked`
   and
   `oram_helper_reconstruct_path_bucket_block_step_preserves_non_failure_admitted_theorem_checked`.
   That preservation is now lifted to the fold level through the recursive
   well-formedness predicates `StashWellFormedFrom` and
   `BucketBlocksWellFormedFrom`, which thread per-block validation, install,
   and admission hypotheses through the list against the running
   reconstruction state. The fold-level success theorems
   `reconstructPathBlocks_preservesNonFailure_of_wellFormed`,
   `reconstructPathBucketBlocks_preservesNonFailure_of_wellFormed`,
   `reconstructPathDecodedBucketsState_preservesNonFailure`, and
   `reconstructPathDecodedBucketsListState_preservesNonFailure` give the
   runtime a clean "well-formed input → reconstruction does not fail" shell
   at every level. These bits land at every layer as
   `oram_helper_stash_well_formed_from_nil_theorem_checked`,
   `oram_helper_bucket_blocks_well_formed_from_nil_theorem_checked`,
   `oram_helper_reconstruct_path_blocks_preserves_non_failure_of_well_formed_theorem_checked`,
   `oram_helper_reconstruct_path_bucket_blocks_preserves_non_failure_of_well_formed_theorem_checked`,
   `oram_helper_reconstruct_path_decoded_buckets_state_preserves_non_failure_theorem_checked`,
   and
   `oram_helper_reconstruct_path_decoded_buckets_list_state_preserves_non_failure_theorem_checked`.
   Combining well-formed input with the position-map coverage hypothesis
   closes the end-to-end "successful reconstruction" theorem at the helper
   layer: `reconstructPathDecodedBucketsFailed_success_of_wellFormed` and
   `reconstructPathDecodedBucketsListFailed_success_of_wellFormed` give the
   runtime its accept condition for the entire `for index in 0..bucket_count`
   fold. The bits land at every layer as
   `oram_helper_reconstruct_path_decoded_buckets_failed_success_of_well_formed_theorem_checked`
   and
   `oram_helper_reconstruct_path_decoded_buckets_list_failed_success_of_well_formed_theorem_checked`.
   The list-level admission derivation
   `bucketBlocksOfDecodedBuckets_admitted_of_liveOnBucketPath` shows that
   under `DecodedBuckets.LiveOnBucketPath leafCount decodedBuckets`, every
   entry in the flattened bucket-block list satisfies admission, landing as
   `oram_helper_bucket_blocks_of_decoded_buckets_admitted_of_live_on_bucket_path_theorem_checked`.
   Public metadata,
   bucket-count, entry-tail, position-map-buffer, fixed-block-slot, or
   live-slot-buffer drift is therefore rejected before any unchecked page,
   slice, or decoded-slot access in the generated
   helper shell, and the residual/direct-machine reports mark
   `oram_directory_pages_reject_count_mismatch_theorem_checked`,
   `oram_buckets_reject_count_mismatch_theorem_checked`,
   `path_position_map_buffer_rejects_count_mismatch_theorem_checked`, and
   `path_live_slots_reject_count_mismatch_theorem_checked` for the matching
   Lean public-count guard facts.
   The imported JSON bridge now exposes the same derived facts directly through
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecTransportShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeSound`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedEncodedLen`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedPlainLen`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsLengthMismatch`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenTransportSound`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoSlotCiphertextShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordTransportRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordEncodedLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeEncodedUoSlotCiphertextShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsWrongMagic`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueCopiesInput`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueWipesInputLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperLookupZeroedRawSlotsShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperInsertOrReplaceLookupSelf`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAllUpdateAppendUoUpdate`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperBootstrappedUoSlotPublicLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperResealTracePublicUpdateShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWriteShapeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWritePublicShape`,
   and
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesMatchCodec`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBucketBytesMatchCodec`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBucketBytesMatchCodec`,
   plus the deeper ORAM-layout hooks
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBlockBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBlockBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDirectoryPageBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterFieldBytesMatchSlotIndex`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketHeaderBytesMatchesRuntimeHeader`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesSurrogateMatchesFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesPathMatchesFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketBytesMatchesRuntimeBucketBytes`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeValidBytes`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeExactEncode`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeValue`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBlockCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeValidShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlockLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlocksLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlocksDecodeCount`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketCodecLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeBlockValidShapes`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketPathBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketPositionMapBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketUniquePositionMapBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLiveSlotCoverage`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBlocksPositionMapAgreement`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBlocksNoDuplicateLiveSlots`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDecodedBucketPayloadAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCoverCapacity`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesPositive`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathMetadataPageSplit`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_positionMapDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLeafDecodeBounded`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapEntriesDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesAllDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeBlockValidShapes`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesAllDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesPositionMapBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesUniquePositionMapBoundedDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageCodecRoundtrip`,
   and
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesCodecRoundtrip`,
   so a checked runtime-boundary artifact can be used by later proofs without
   trusting an extra Rust-side codec checker.
   That remaining handwritten object/ORAM coordination plus thinner store support
   now also has its own named source-backed
   cut, `RuntimeImplementationInterface.ResidualHelperShellBoundary`,
   benchmark-backed by
   `runtime_residual_helper_shell_boundary_validation.json`. Lean now also
   projects exact Lean-generator equality at that same named cut for generated
   object helpers, ORAM codecs, store codec, store surface, and store helpers,
   and the emitted residual-helper-shell report names those five checks
   directly instead of relying only on the wider implementation-interface
   report. The standalone residual-helper-shell checker/report now also
   exposes the store codec semantic obligations directly at that smaller cut:
   nonzero transport roundtrip/soundness, generated store-surface checked
   split/copy reopen discipline, sealed-record length/shape/open transport
   soundness, sealed-record transport roundtrip and rejection, UO
   slot ciphertext shape, and public update-write shape. The standalone
   residual-helper-shell checker/report now also exposes the deeper ORAM
   codec-layout semantics directly at that smaller cut: public block,
   bucket, directory-page, and counter-field formulae; codec-vs-runtime
   bucket/header agreement; counter encode/decode acceptance and length;
   block and block-list encode/decode length/roundtrip facts; bucket
   encode/decode length, acceptance, and block-shape facts; bounded Path
   bucket decode shape including path, position-map, and duplicate-live-slot
   obligations; live-block validation/update effects; final live-slot
   coverage-check effects; Path-entry reset/install effects; combined
   reconstruction loop-body, decoded-block-list fold, bucket-indexed admission
   fold, whole decoded
   reconstruction shell, finish-predicate effects, and the codec-to-helper
   bridge that lifts decoded path bucket payload blocks into admitted
   helper bucket blocks so that the bucket-indexed reconstruction collapses
   onto the flat block reconstruction over those bridged blocks; position-map
   coverage/agreement hooks;
   page coverage,
   positivity, split, decode-acceptance, page-length, and exact
   position-map page/page-list roundtrips; public directory/bucket and
   live-position-map/live-slot buffer count mismatch rejection; and stash
   page/page-list decode-shape, bounded-shape, length, and roundtrip facts. These ORAM
   metadata-codec obligations are therefore available at the smaller
   helper-shell cut and not only at the larger machine-confinement boundary,
   and the source-backed interface now rejects reintroducing direct fixed-offset
   ORAM byte indexing/slicing in that generated codec stack.
   Lean now also
   packages the direct meeting between that helper-shell source cut and the
   emitted native machine witness as
   `RuntimeImplementationResidualHelperShellMachineRefinementBoundary`,
   benchmark-backed by
   `runtime_implementation_residual_helper_shell_machine_refinement_boundary_validation.json`;
   that residual-helper-shell machine route now states the same native
   machine-finish exactness facts directly at that smaller source cut too:
   consumed expected schedule index, respected kernel-op budget, respected
   runtime-phase-event budget, and exact slot-program/kernel-step agreement.
   Its emitted report now marks `native_machine_refinement_theorem_checked`
   for that lower-level theorem directly, in addition to the two public-only
   shell paper theorems, and now also marks
   `residual_helper_shell_boundary_theorem_checked` for the raw named cut.
   Lean now also exposes the corresponding public-only handwritten-runtime
   corollaries explicitly at that cut and at the wider implementation-facing
   routes:
   `RuntimeImplementationResidualHelperShellBoundary.handwrittenRuntimePublicOnly`,
   `RuntimeImplementationResidualHelperShellMachineRefinementBoundary.handwrittenRuntimePublicOnly`,
   `RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement`,
   `RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement`,
   `RuntimeImplementationPublicBridgeObserverRefinementBoundary.paperPublicBridgeObserverRefinement`,
   `RuntimeImplementationKernelMeetingBoundary.handwrittenRuntimePublicOnly`,
   `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell`,
   `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineObserverRefinement`,
   `RuntimeImplementationSharedKernelRefinementBoundary.handwrittenRuntimePublicOnly`,
   `RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelRefinementWithPublicOnlyHandwrittenShell`,
   `RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelObserverRefinement`,
   `RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell`,
   `RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSharedKernelMachineObserverRefinement`,
   `RuntimeImplementationConfinementBoundary.handwrittenRuntimePublicOnly`,
   `RuntimeImplementationConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`,
   `RuntimeImplementationConfinementBoundary.paperPublicBridgeObserverRefinement`, and
   `RuntimeImplementationKernelMachineConfinementBoundary.handwrittenRuntimePublicOnly`.
   The wider small-confidential-kernel-machine, shared-kernel-machine,
   kernel-meeting-confinement, implementation-confinement, and direct
   kernel-machine-confinement routes now also project the two
   public-only residual-helper-shell theorems explicitly and mark
   `paper_public_only_residual_helper_shell_refinement_theorem_checked` plus
   `paper_public_only_residual_helper_shell_observer_refinement_theorem_checked`
   in their emitted reports; the small-confidential-kernel-machine route now
   also marks
   `paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
   plus `paper_small_kernel_machine_observer_refinement_theorem_checked`;
   the shared-kernel-machine route now also marks
   `paper_shared_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
   plus `paper_shared_kernel_machine_observer_refinement_theorem_checked`;
   those same routes now also re-emit
   `residual_helper_shell_boundary_theorem_checked` and
   `slot_adapter_boundary_theorem_checked` for the raw named cuts, now also
   with the top-level source-backed implementation-interface route, the
   direct kernel-meeting route, and the direct shared-kernel-refinement
   route, mark `handwritten_runtime_public_only_theorem_checked` for the
   explicit `handwrittenRuntimePublicOnly` corollary, and those two direct
   routes now also re-emit `residual_helper_shell_boundary_theorem_checked`,
   while the direct shared-kernel-refinement route now also marks
   `paper_shared_kernel_refinement_with_public_only_handwritten_shell_theorem_checked`
   plus `paper_shared_kernel_observer_refinement_theorem_checked`,
   and the
   routes that sit on the corresponding kernel cuts now also mark
   `small_confidential_kernel_boundary_theorem_checked` and
   `shared_confidential_kernel_boundary_theorem_checked` whenever the route
   sits on those cuts, and the dedicated source-backed small/shared-kernel
   reports now also mark `residual_helper_shell_boundary_theorem_checked` plus
   `handwritten_runtime_public_only_theorem_checked`. The dedicated source-backed public-bridge report now
   also marks `public_bridge_boundary_theorem_checked`. The dedicated
   source-backed slot-adapter report now also marks
   `slot_adapter_boundary_theorem_checked`. The dedicated public-bridge observer report now also
   marks `public_bridge_boundary_theorem_checked`, the direct
   kernel-machine-confinement route now also marks that same public-bridge
   cut directly, and the dedicated
   source-backed confidential-statement-trace bridge report now also marks
   `confidential_statement_trace_bridge_boundary_theorem_checked`, while the dedicated
   confidential-statement-trace bridge refinement report now also marks
   `confidential_statement_trace_bridge_boundary_theorem_checked`. The combined
   `RuntimeImplementationConfinementBoundary` report now also marks
   `paper_end_to_end_confinement_with_public_only_handwritten_shell_theorem_checked`
   and `paper_public_bridge_observer_refinement_theorem_checked`. The
   `RuntimeImplementationKernelMeetingConfinementBoundary` report now marks
   those same two theorem checks after reconstructing the outer confinement
   boundary from the meeting artifact.
   The handwritten `uo-kernel-runtime` forwarding shell is now also isolated at
   the standalone source-backed `RuntimeImplementationSlotAdapterBoundary`,
   with a dedicated checker/report path and dedicated drift rejection for the
   generated slot-support, generated confidential-kernel interpreter,
   shared-kernel interpreter bridge, and handwritten raw-argument adapter
   surfaces before the larger small-kernel boundary is even invoked. Lean now
   also packages the direct meeting between that same source cut and the live
   machine-finish witness as
   `RuntimeImplementationSlotAdapterMachineRefinementBoundary`, benchmark-backed by
   `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`;
   Lean packages the paper-facing conjunction there as
   `RuntimeImplementationSlotAdapterMachineRefinementBoundary.paperSlotAdapterMachineRefinement`;
   the same route now also marks `native_machine_refinement_theorem_checked`
   for its lower-level machine theorem and
   `slot_adapter_boundary_theorem_checked` for the raw named cut;
   the wider small-confidential-kernel-machine, shared-kernel-machine,
   kernel-meeting-confinement, implementation-confinement, and direct
   kernel-machine-confinement routes now project through that same theorem
   explicitly and mark
   `paper_slot_adapter_machine_refinement_theorem_checked` in their emitted
   reports; the small-confidential-kernel-machine route now also marks
   `paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
   plus `paper_small_kernel_machine_observer_refinement_theorem_checked`,
   while the shared-kernel-machine route now also marks
   `paper_shared_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
   plus `paper_shared_kernel_machine_observer_refinement_theorem_checked`;
   the kernel-meeting and wider shared-kernel-refinement reports now also mark
   their local named boundary cuts directly via
   `shared_confidential_kernel_boundary_theorem_checked`, with the
   kernel-meeting report additionally marking
   `small_confidential_kernel_boundary_theorem_checked`,
   `confidential_statement_trace_bridge_boundary_theorem_checked`, and
   `slot_adapter_boundary_theorem_checked`, and with the wider
   shared-kernel-refinement report now also marking
   `slot_adapter_boundary_theorem_checked`;
   that direct machine-backed slot-adapter route now rejects expected-schedule-
   index drift, kernel-op/runtime-phase capacity drift, slot-program body
   drift, opcode-trace drift, generated confidential-interpreter drift,
   shared-kernel interpreter-bypass drift, generated post-return-break drift,
   generated slot-support argument-count drift, and handwritten raw-argument
   observation drift before the wider residual-helper-shell or small-kernel
   machine routes are used.
   The direct machine-backed public-observer half now sits on its own dedicated
   boundary
   `RuntimeImplementationPublicBridgeObserverRefinementBoundary.paperPublicBridgeObserverRefinement`,
   and the larger direct machine-backed paper theorem now also has the stronger
   explicit shell form
   `RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`,
   plus the narrower public-observer theorem
   `RuntimeImplementationKernelMachineConfinementBoundary.paperPublicBridgeObserverRefinement`,
   which now projects through that dedicated public-observer cut and keeps the
   old end-to-end confinement/refinement statement while adding the source-side
   claim that handwritten `objects.rs`, `oram.rs`, `codec.rs`, and `store.rs`
   perform no confidential work.
   Those theorems cover the handwritten store shell as well, so the residual
   claim now reads as intended: handwritten `objects.rs`, `oram.rs`,
   `codec.rs`, and `store.rs` are public-only shells, while confidential
   object/ORAM/store work lives only in Lean-generated helpers.
   The wider implementation-confinement and direct machine-confinement
   theorems project that same helper-shell boundary explicitly instead of
   leaving it buried as unnamed conjuncts inside the larger source interface.
   The checked source-backed interface beneath those routes now also pins the
   `uo-precompiles::UoOpcode` vocabulary through imported
   `runtime/uo-precompiles/src/lib.rs`, and the drift suite rejects
   `precompiles_opcode_surface_drift` already at the implementation,
   small-kernel, meeting, and confinement cuts. It also now pins
   `runtime/uo-evm/src/fresh_coins.rs`, so the opaque `PathOramFreshCoinPlan`
   carrier used by the exact transition-shaped fresh-leaf schedule is frozen
   as a boxed, non-`Clone`, move-only per-object entry table, and the drift
   suite rejects `path_oram_fresh_coin_plan_surface_drift` at those same
   implementation, small-kernel, shared-kernel, meeting, and confinement cuts.
   It now also requires the diagnostics/theorem-facing fresh-coin replacement
   and schedule grouping paths to use checked entry/schedule lookups rather
   than `old_entries[index]`, `coin_schedule[index]`, or schedule sub-slices;
   tamper validation rejects reintroducing the direct-index replacement form.
   The committed-state duplicate-object guard likewise uses a slice-pattern
   window match rather than `pair[0]` / `pair[1]`, and the implementation
   interface rejects that stale direct-index shell shape too.
   The public-bridge side of that same checked source interface now also pins
   the shared `uo-core` crate-root export shell in `crates/uo-core/src/lib.rs`,
   so the theorem-carrying public API for controller certificates, shell
   traces/contracts, runtime outcomes, and trusted-kernel bundles is frozen at
   the crate root while the generated confidential-kernel module remains
   non-exported. The drift suite now rejects
   `core_library_generated_kernel_export_drift` already at the implementation,
   standalone public-bridge, public-bridge observer-refinement,
   meeting-confinement, direct machine-confinement, and combined
   implementation-confinement cuts.
   The remaining target is therefore narrower still: replace the current
   source-plus-finish-slot proof/interface meeting point with a native
   semantics-of-Rust refinement theorem for the now-isolated real kernel
   support beneath the slot-adapter and public-only residual-helper shells.
   The generated store-helper side of that shell is no longer merely
   source-equality checked: `RuntimeStoreHelperSemantics` now models raw-value
   copy/wipe, zeroed slot-table lookup, insert-or-replace lookup/length shape,
   boxed event append, bootstrapped UO-slot public length, and update-only reseal
   traces. It also models the generated helper's public read/write metric
   shell: read/write counters advance publicly, UO writes leave zero-write
   classification unchanged, and the emitted UO physical write remains the
   public UPDATE shape. The residual/direct-machine reports expose matching
   `store_helper_*_theorem_checked` bits.
   The generated ORAM-helper side is likewise no longer only source-equality
   checked: `RuntimeOramHelperSemantics` now models the masked selector,
   slot/vacancy scan, fixed-stash push/take, position-map selection,
   access-leaf choice, position-map/stash leaf update, failed-put, and
   path-bucket rebuild primitives plus the fixed read-count and
   `rewrite_path_for_access` fixed write-count/counter/failure shell and
   transition-kind precedence, with matching
   `oram_helper_*_theorem_checked` bits at both the residual-helper-shell and
   direct machine-confinement cuts.
   Lean now packages that exact remaining target as the explicit assumption
   bundle `RuntimePaperNativeKernelAssumptions`, and the current direct
   machine-confinement route projects into it through
   `RuntimeImplementationKernelMachineConfinementBoundary.toRuntimePaperNativeKernelAssumptions`.
   That assumption bundle is now smaller than before: it keeps only the
   source-side confinement fact plus the native machine-finish boundary object.
   The kernel-state and shell-trace refinement facts are no longer stored as
   independent fields in that bundle; Lean derives them from the already
   checked `RuntimeKernelMachineFinishBoundary` / `RuntimeKernelConfinementBoundary`
   path through
   `RuntimePaperNativeKernelAssumptions.kernelStateRefinesLeanKernel` and
   `RuntimePaperNativeKernelAssumptions.shellTraceRefinesShellContract`.
   Schedule consumption, kernel/runtime budget
   bounds, slot-step exactness, and the current theorem-facing store/ORAM
   transport, exact boxed store-trace backing, sealed-record rejection/shape, public UO update-write,
   public block/bucket/directory-page formulae, codec-vs-runtime block/bucket
   formula agreement, path metadata page positivity, counter-field, block,
   aggregate block-shape, exact-bucket
   decode-acceptance, page-layout facts, and exact position-map/stash
   page encode/decode roundtrips
   are derived from the already checked machine-finish witness and residual
   helper-shell boundary.
   That route is now surfaced through the imported JSON bridge, the proof-grade
   checker, and the emitted
   `runtime_implementation_kernel_machine_confinement_boundary_validation`
   report via
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_assumptions`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_state_refinement`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_shell_trace_refinement`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeTraceUsesExactBoxedBacking`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecTransportShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeSound`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedEncodedLen`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedPlainLen`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsLengthMismatch`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenTransportSound`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoSlotCiphertextShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordTransportRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordEncodedLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeEncodedUoSlotCiphertextShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsWrongMagic`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueCopiesInput`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueWipesInputLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperLookupZeroedRawSlotsShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperInsertOrReplaceLookupSelf`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAllUpdateAppendUoUpdate`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperBootstrappedUoSlotPublicLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperResealTracePublicUpdateShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWriteShapeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWritePublicShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesMatchCodec`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBucketBytesMatchCodec`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBucketBytesMatchCodec`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBlockBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBlockBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDirectoryPageBytesPublicFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterFieldBytesMatchSlotIndex`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketHeaderBytesMatchesRuntimeHeader`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesSurrogateMatchesFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesPathMatchesFormula`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketBytesMatchesRuntimeBucketBytes`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeValidBytes`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeExactEncode`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeValue`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBlockCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeValidShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlockLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlocksLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlocksDecodeCount`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketCodecLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDecodedBucketPayloadAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCoverCapacity`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesPositive`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_positionMapDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLeafDecodeBounded`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapEntriesDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesAllDecodeShape`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeAccepted`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageLength`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesCodecRoundtrip`,
   `importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesAllDecodeShape`,
   `importedBoundaryPaperNativeKernelAssumptions`,
   `importedBoundaryPaperNativeKernelStateRefinement`,
   `importedBoundaryPaperNativeShellTraceRefinement`,
   `paper_native_kernel_assumptions_theorem_checked`,
   `paper_native_kernel_state_refinement_theorem_checked`, and
   `paper_native_shell_trace_refinement_theorem_checked`, plus
   `paper_native_store_trace_exact_boxed_backing_theorem_checked`, the
   generated-value-ops generator-match theorem, and the `value_ops_*` semantic
   theorem bits for canonical scalar lengths, `u128` canonical byte fields,
   masked selection, and fixed-byte-buffer extend/finish behavior. The umbrella
   `runtime-boundary-validation` report now also carries the matching
   minimized-bundle source check
   `runtime_implementation_kernel_machine_confinement_paper_native_kernel_assumption_bundle_minimized`
   and is accepted again with the current public-only handwritten shell /
   generated-helper split.
9. Remaining after 8: prove source-to-kernel compiler correctness.
10. Remaining after 9: minimize `PathOramLocalPosmapV1SecurityAssumptions`.
11. Remaining after 10: close the hostile-host TEE theorem over the frozen
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
  generateConfidentialKernelRust \
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
cd proof/lean && ./.lake/build/bin/generateConfidentialKernelRust | \
  diff -u ../../crates/uo-core/src/generated_confidential_kernel.rs -
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

## Working Practices

For follow-on coding agents: the engineering process — five-layer
projection pattern, naming conventions, validation-slice protocol,
tamper-suite interpretation, common pitfalls, and the onboarding read
order — is documented in
[`coding-agent-conventions.md`](./coding-agent-conventions.md).
That file is work-package-agnostic and should be the first reference for
how to land changes in this repository, regardless of which work package
is active.
