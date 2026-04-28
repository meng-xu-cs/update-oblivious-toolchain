# Implementation Roadmap To Proof-Grade SGX/TEE Conformance

This note no longer describes a speculative implementation plan. It records the
current milestone status of the repository and the remaining work needed for
stronger theorem provenance claims.

## Goal

The implementation target remains:

- confidential entrypoints emit an explicit public observer consisting of
  `public_outcome`, exact `boundary_schedule`, protected `storage_trace`, and a
  normalized SGX controller `micro_trace`
- persistent state leaving the enclave boundary is confidential and integral
- unsupported programs are rejected rather than accepted under an inexact
  public witness
- the Rust implementation is connected to the Lean theorem boundary by an
  explicit certificate / witness bridge rather than by documentation alone

The theorem-facing backend path is
`path_oram_local_posmap_v1`. The legacy surrogate backend remains in the
repository only as a non-proof-grade benchmark surface; it is outside the
paper-facing and proof-grade claim set.

## Theorem-Preserving Principles

- Do not relax the theorem to fit the implementation.
- Reject unsupported programs instead of widening the public leakage witness.
- Keep every public observer field explicit in the runtime trace.
- Keep the trusted Rust surface small and explicit.

## Milestones

### M1. Runtime theorem observer

Status: implemented.

The runtime now emits:

- `public_outcome`
- exact `boundary_schedule`
- public controller shape
- normalized SGX micro trace derived from that controller shape

That observer is now validated through the shared `uo-core`
`RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(...)`
interface: `uo-evm` records the observed boundary schedule, controller
budgets, and public ORAM-access witness sequence, while `uo-core` reconstructs
the controller certificate plus theorem-facing controller observer and rejects
drift before a trace is returned. The production controller path no longer
hand-assembles `SgxControllerShapeTrace`, `RuntimeControllerCertificate`, or
`TheoremTrace` struct literals / low-level constructor calls.

### M2. Sealed persistent storage

Status: implemented.

Confidential storage records now use authenticated encryption with associated
data before nonzero transport encoding. The old marker-hiding placeholder codec
is no longer the only storage story:

- exact backends keep post-initialization writes on the update-only path
- decode/open rejects tampering
- sealed-storage facts are now part of the explicit assumption provenance
  surface

### M3. Exact public leakage witnesses

Status: implemented on the current admitted subset.

The compiler/checker path now enforces compile-time-exact loop structure for
admitted confidential code and validates the manifest fields that the theorem
bridge consumes:

- confidential entrypoints do not target raw-backend objects on the
  proof-grade path; the direct Lean proof-grade translation checker rejects
  raw-backend kernel-step targets, and both `uo-solc` lowering and the runtime
  admission path enforce the same exclusion
- secret-argument positions
- exact confidential kernel lowering acceptance and kernel step/opcode replay
- arena and stack budgets
- exact object manifests
- exact logical read/write counters
- exact ORAM access counts
- exact `max_commit_ops`

The strongest proof-grade path now feeds a source-side compiled artifact and
the candidate artifact directly to the Lean checker
`checkProofGradeTranslationArtifacts`, which re-projects the proof-relevant
source/artifact views from raw contract JSON extracted from those artifacts.
The current trust point is therefore no longer a Rust-side proof-relevant
projection decision. The probe now builds and checks that direct artifacts
path from `uo-solc` plus `uo-core`, `uo-check` is no longer on the
proof-grade library or CLI path, and the static-check report records
confidential raw artifacts plus raw-backend confidential-kernel targets as
explicit proof-grade rejections. The proof-grade theorem facade now also
exports the corresponding per-step fact: every object-bearing confidential
kernel step resolves to a non-raw state object in the validated source view.

### M4. Proof-grade ORAM backend path

Status: implemented for the theorem-facing path.

The repository now contains a concrete standard-style backend candidate,
`path_oram_local_posmap_v1`, with:

- a real tree and real path rewrites
- persisted access counters
- persisted position-map state
- persisted stash state
- immediate access execution on transaction shadow state rather than a
  one-shot staged commit surrogate
- multi-access-per-entrypoint support on the theorem-facing path
- manifest/runtime parameter sharing through `OramManifest::for_object`

The stronger backend is already exercised beyond `SingleAccessMap` in the probe
and witness reports, including multi-access `ConfidentialMixer` and multi-map
`ERC20Lite` paths.

### M5. Explicit SGX/controller runtime path

Status: implemented.

The runtime now has a call-scoped controller recorder that emits:

- ordered logical accesses and logical writes
- ordered physical reads and writes
- exact enclave-boundary events
- controller-phase observations
- public region page budgets and workset budgets

The emitted theorem trace now comes back out of the shared `uo-core`
controller-observer certificate path: `uo-evm` records the public controller
observations, `RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(...)`
rebuilds the controller certificate plus theorem-facing observer from those
observations and the recorded public ORAM access witness sequence, and the
resulting `TheoremTrace` is projected from that validated shared object rather
than from a runtime-local theorem/controller reconstruction path.

### M6. Runtime refinement and trusted kernel

Status: completed on April 21, 2026 under the explicit proof/interface route.

The runtime/proof bridge now includes:

- standalone controller-observer certificates
- standalone hidden Path-ORAM certificates
- an explicit `RuntimeTrustedKernelBundle`
- a proof-grade `RuntimeTrustedKernelSlotBundle` that ties that bundle to the
  admitted fixed-slot confidential program
- runtime-enforced refinement-witness extraction
- Lean JSON import and executable validation for the bundle and witness
- seeded witness-family and paired-certificate validation
- a family-level proof-grade runtime kernel-interface checker over seeded
  path-ORAM witness families, so the paper-route runtime/kernel boundary is
  executable over emitted witness families rather than only over single
  witnesses
- a family-level proof-grade runtime paper-main checker over those same seeded
  families, enforcing exact public-outcome and exact boundary-schedule
  uniformity at the emitted artifact boundary
- a family-level proof-grade runtime paper-main slot checker over those same
  seeded families plus one exact confidential slot program, enforcing shared
  slot-program alignment at the emitted artifact boundary
- shared `ExecutionTrace` constructors plus direct `uo-evm` output formats for
  the canonical single-seed paper-main family and slot-family artifacts, so
  the theorem-facing family objects are first-class runtime outputs rather than
  probe-only reconstructions
- a source-backed `RuntimeImplementationInterface` over the actual
  `runtime/uo-evm/src/{lib,engine,runtime,shell,state,objects,oram,theorem}.rs`
  modules together with
  `runtime/uo-kernel-runtime/src/{lib,generated_slot_support,generated_machine}.rs`,
  `runtime/uo-evm/src/generated_object_helpers.rs`,
  `runtime/uo-evm/src/generated_oram_codecs.rs`,
  `runtime/uo-store/src/{codec,generated_surface,generated_store_helpers,store}.rs`,
  `runtime/uo-allocator/src/lib.rs`,
  and the shared `uo-core` confidential-kernel/runtime-support files, with
  the probe stripping `#[cfg(test)]` items before Lean checks the production
  bridge/interface split
- a combined `RuntimeImplementationConfinementBoundary` that pairs that
  source-backed runtime interface with the exact emitted
  `RuntimeKernelInterfaceBundle`, so the real runtime proof/interface route
  speaks about both the emitted kernel witness path and the non-kernel public
  bridge in one checked object
- dedicated positive reports and dedicated tamper rejections for both the
  standalone implementation-interface checker and the combined
  implementation-confinement-boundary checker
- canonical fresh-coin family and pair validation, with compact and heavy
  artifact modes
- a paper-facing Lean runtime boundary,
  `PaperMainRuntimeKernelBoundary`, plus lower-level projection wrappers
  `PaperMainRuntimeKernelAssumptions`, so the remaining runtime/kernel trust
  point is explicitly named at the theorem route while the top-level paper
  assumptions stay minimal
- a stronger shared-slot-DSL paper route,
  `PaperMainRuntimeKernelSlotBoundary`, plus the end-to-end
  `PaperMainPathOramSlotAssumptions` /
  `PaperMainPathOramSlotEndToEndBoundary`, which fix the exact slot program per
  public ORAM configuration and now speak directly about the explicit runtime
  kernel-interface bundle rather than only witness acceptance; the stronger
  wrapper `PaperMainRuntimeKernelSlotAssumptions` remains available below that
  route to discharge the boundary mechanically from proof-grade witness
  acceptance

This milestone is now closed on the repository's runtime proof/interface route,
and the layers above it are closed for the current paper theorem surface: WP4
supplies the source-to-kernel compiler-correctness chain, WP5 supplies the
backend-assumption provenance/audit route, and WP6 supplies the hostile-host
observer and deployment-assumption closure. The remaining non-claim is below
this interface: the repository does not prove downstream machine code or a full
semantics-of-Rust refinement for every residual implementation detail beneath
the checked source-backed runtime boundary.

### M7. Paper-main standard-theorem route

Status: implemented at the frozen interface. The paper route uses the cited
JACM Path-ORAM source at that interface; a separately imported
machine-checked external theorem would be out-of-charter future strengthening,
not an open roadmap task.

The repository now has:

- a frozen standard-theorem target:
  `PathOramLocalPosmapV1StandardTheoremTarget`
- an explicit literature-facing JACM theorem object and mapping
- a self-instantiated artifact-side closure at exactly the same interface
- a separate paper-main provenance route documented for the citation-based
  presentation

That means the theorem boundary is fixed, the engineering bridge is closed, and
the provenance choice is no longer pending for this submission.

## Runtime-Hardening Closure Track

The former active strengthening track for pushing `uo-evm` itself toward the
hostile-host adversary model is closed for the current paper surface. This
section records the closure evidence and the narrower out-of-charter
below-interface strengthening target.

Status: the outer proof/interface route is completed, and the stronger
shared-kernel strengthening track has been carried to the checked boundary
needed by the current theorem. The
checked implementation boundary now reaches the shared `uo-core`
confidential-kernel interpreter / masked-selection layer used by the live
runtime, and it now also reaches the Path ORAM masked full-scan
lookup/update/stash-rebuild layer in `runtime/uo-evm/src/oram.rs`, including
the exact transition-shaped fresh-leaf schedule recorded in the runtime
transition witness and checked by the source-backed interface. That inner
source cut now also meets the closer-to-implementation emitted
`RuntimeKernelMachineFinishWitness` directly through the checked
`RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary` and
`RuntimeImplementationSharedKernelMachineRefinementBoundary`, so the real
implementation-side small and shared confidential-kernel interfaces are both
paired with the live shared-kernel machine finish state before that state is
flattened to the smaller emitted
`RuntimeConfidentialCoreKernelFinishSlotBundle`; that smaller finish-slot
artifact now also meets the dedicated checked
`RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary`
before the new checked `RuntimeImplementationKernelMeetingBoundary` proves that
the live machine-projected finish bundle and the emitted finish-slot bundle
agree at the native boundary, and the new checked
`RuntimeImplementationKernelMeetingConfinementBoundary` then requires the full
source-backed implementation interface and reconstructs the outer
implementation-confinement boundary from that same meeting object before the
older wider finish-slot route through the checked
`RuntimeImplementationSharedKernelRefinementBoundary`
come into play; the stronger
`RuntimeImplementationKernelMachineConfinementBoundary` route now also pairs
the full source-backed implementation interface directly with the live
machine-finish witness, fixed confidential slot program, and opcode trace,
checks schedule consumption plus kernel-op/runtime-phase capacity bounds, and
then reconstructs the outer implementation-confinement boundary without the
separate emitted finish-slot meeting artifact; Lean now packages that direct
route as
`RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`,
which strengthens the older direct theorem by also stating that handwritten
runtime confidential work lives only in generated helpers, alongside source
confinement, Lean-kernel refinement, shell-trace refinement, schedule
consumption, both live capacity bounds, and slot-program/kernel-step exactness
together. The closer machine-backed residual-helper-shell route is also now
packaged as
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement`,
with the narrower public-observer slice exposed as
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement`,
and the wider small-confidential-kernel-machine, shared-kernel-machine,
kernel-meeting-confinement, implementation-confinement, and direct
kernel-machine-confinement routes now project those same public-only
shell theorems explicitly and emit
`paper_public_only_residual_helper_shell_refinement_theorem_checked` together
with
`paper_public_only_residual_helper_shell_observer_refinement_theorem_checked`,
as well as the named small/shared-kernel cut checks
`small_confidential_kernel_boundary_theorem_checked` and
`shared_confidential_kernel_boundary_theorem_checked` on the corresponding
machine-backed, source-backed, and outer routes,
while the dedicated residual-helper-shell machine route now also emits
`native_machine_refinement_theorem_checked` for its lower-level theorem and the
dedicated slot-adapter, small-confidential-kernel-machine, and shared-kernel-
machine reports now do the same for their own native machine theorems,
with the dedicated slot-adapter machine and residual-helper-shell machine
routes now also marking `slot_adapter_boundary_theorem_checked` and
`residual_helper_shell_boundary_theorem_checked` for their raw named cuts,
the dedicated residual-helper-shell boundary, dedicated public-bridge observer
boundary, dedicated residual-helper-shell machine boundary,
small-confidential-kernel-machine and shared-kernel-machine routes, and the
kernel-meeting-confinement, implementation-confinement, and direct
kernel-machine-confinement routes, together with the top-level source-backed
implementation-interface route, now also marking
`handwritten_runtime_public_only_theorem_checked` for the explicit
`handwrittenRuntimePublicOnly` corollary, with the
small-confidential-kernel-machine route now also exposing
`RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell`
and
`RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineObserverRefinement`
and marking
`paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
plus `paper_small_kernel_machine_observer_refinement_theorem_checked`,
the dedicated source-backed small/shared-kernel routes also marking
`slot_adapter_boundary_theorem_checked` together with their local
small/shared-kernel named-cut checks, and now also marking
`residual_helper_shell_boundary_theorem_checked` plus
`handwritten_runtime_public_only_theorem_checked`; the direct shared-kernel
refinement route now also marks
`paper_shared_kernel_refinement_with_public_only_handwritten_shell_theorem_checked`
plus `paper_shared_kernel_observer_refinement_theorem_checked` for
`RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelRefinementWithPublicOnlyHandwrittenShell`
and `RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelObserverRefinement`,
and the wider implementation-facing
confinement routes now also re-emitting the raw
`slot_adapter_boundary_theorem_checked` /
`residual_helper_shell_boundary_theorem_checked` pair,
with the dedicated source-backed public-bridge route now also marking
`public_bridge_boundary_theorem_checked`,
with the dedicated source-backed slot-adapter route now also marking
`slot_adapter_boundary_theorem_checked`,
with the abstract source-backed public bridge cut checked separately as
`RuntimeImplementationPublicBridgeBoundary`,
the direct public-bridge observer half now also exposed first through the
dedicated machine-backed
`RuntimeImplementationPublicBridgeObserverRefinementBoundary.paperPublicBridgeObserverRefinement`,
with the outer direct route now projecting through that smaller cut as
`RuntimeImplementationKernelMachineConfinementBoundary.paperPublicBridgeObserverRefinement`.
The combined `RuntimeImplementationConfinementBoundary` now also exposes
`paperEndToEndConfinementWithPublicOnlyHandwrittenShell` together with the
matching `paperPublicBridgeObserverRefinement` theorem on the non-machine outer
route.
The meeting-point reconstruction route
`RuntimeImplementationKernelMeetingConfinementBoundary` now projects those same
two outer paper theorems explicitly and its emitted validation report marks
`paper_end_to_end_confinement_with_public_only_handwritten_shell_theorem_checked`
and `paper_public_bridge_observer_refinement_theorem_checked`.
These direct routes meet on the native
`RuntimeKernelFinishSlotBoundary` before projecting to the larger
`RuntimeKernelConfinementBoundary`. A full below-interface semantics-of-Rust
refinement theorem for that real shared-kernel / Path ORAM implementation
surface is outside the closed roadmap.

The first implementation step is now present in the codebase:

- `uo-evm` routes confidential cell/array/map operations through an internal
  small-kernel layer
- that layer uses `uo-precompiles::UoOpcode` as its auditable operation
  vocabulary
- the checked source-backed `RuntimeImplementationInterface` and
  `SmallConfidentialKernelBoundary` now pin that opcode vocabulary directly by
  importing and rechecking `runtime/uo-precompiles/src/lib.rs`, so the tiny
  kernel's public operation alphabet is part of the Lean-audited boundary
- `uo-allocator` now enforces manifest-derived kernel-op budgets, stack-word
  budgets, bounded scratch regions, and end-of-call wipe checks
- `uo-allocator` now also uses a public-capacity `ResourceEventLog`, and
  `RuntimeKernelTelemetrySnapshot` carries resource events as boxed slices at
  the finish boundary; Lean models this allocator transition discipline in
  `RuntimeAllocatorDiscipline`
- the shared runtime-kernel statement recorder now also uses exact-capacity
  boxed `MaybeUninit<String>` storage rather than `vec![None; capacity]` plus
  a `Vec`-based repacking step at finish
- that allocator-side kernel-op accounting is now count-only rather than a
  redundant opcode log, so the runtime boundary keeps the authoritative
  kernel-step witness stream inside the shared `uo-core` execution tracker
- each confidential compiled function and emitted manifest entry now records
  the same canonical confidential named DSL object, canonical confidential
  slot DSL object, and exact public kernel-step trace `{ opcode, object_id? }`
  so checker-side source/artifact validation and `uo-evm` can reject drift
  across the exact function body lowering, the stored function metadata, the
  stored manifest metadata, and the runtime confidential-kernel boundary
- the runtime kernel now also enforces that admitted public schedule online
  while the confidential call is executing, which narrows the remaining gap to
  proving the kernel/runtime refines the modeled observer rather than merely
  spotting schedule drift after the fact
- `tamper_validation.json` now also rejects representative
  `precompiles_opcode_surface_drift` at the source-backed implementation
  interface, small-kernel, shared-kernel, meeting, and confinement cuts, so
  handwritten opcode-surface drift below the interface is caught mechanically
- the checked source-backed interface now also imports
  `runtime/uo-evm/src/fresh_coins.rs`, pins `PathOramFreshCoinPlan` as a
  boxed, non-`Clone`, move-only per-object tape carrier, and rejects
  `path_oram_fresh_coin_plan_surface_drift` across the implementation,
  small-kernel, shared-kernel, meeting, and confinement routes
- the runtime now emits a compact `RuntimeKernelWitness` and validates it
  against the checked manifest's stored confidential slot program and derived
  public step trace before returning the trace
- the smaller pre-witness
  `RuntimeConfidentialCoreKernelFinishSlotBundle` and the direct
  `RuntimeTrustedKernelSlotBundle` now also recheck the emitted confidential
  statement trace against that same fixed confidential slot program, so the
  live interpreter's statement-level path is frozen at the proof boundary in
  addition to the public kernel-step schedule
- the live statement recorder is now the exact-capacity
  `RuntimeKernelStatementTrace`, modeled by `RuntimeStatementTraceDiscipline`,
  rather than a growable `Vec<String>` on the confidential path
- the shared confidential-kernel DSL carriers are fixed-shape as well:
  named/slot program bodies and named/slot Keccak part lists are boxed slices,
  and source/name-to-slot lowering fills them through `FixedBoxBuilder` rather
  than temporary growable collection
- `state.rs` now invokes the shared `uo-kernel-runtime`
  `RuntimeKernelMachine` directly, and that shared machine delegates live
  confidential slot execution into the shared `uo-core`
  `execute_confidential_kernel_slot_program(...)` generated interpreter rather
  than keeping a separate runtime-local confidential evaluator
- the shared kernel runtime now keeps confidential arguments and slot state in
  a Lean-generated private fixed-size slot-support module consumed by
  `RuntimeKernelSlotCall`, while the shared interpreter in
  `crates/uo-core/src/confidential_kernel.rs` keeps hash staging on an
  exact-size boxed buffer and
  `crates/uo-core/src/types.rs` carries the shared masked-selection helpers
  used by confidential value flow
- the source-backed `RuntimeImplementationInterface` and combined
  `RuntimeImplementationConfinementBoundary` now pin that lower shared-kernel
  boundary directly, including the live statement recorder in
  `runtime/uo-kernel-runtime/src/lib.rs`, the `ExecutionTrace` opcode-trace
  carry path in `crates/uo-core/src/trace.rs`, and the exact slot-bundle
  rechecks in `crates/uo-core/src/confidential_core.rs` and
  `crates/uo-core/src/trusted_kernel.rs`; `tamper_validation.json` now rejects
  representative shared-kernel secret-branch drift and statement-trace bridge
  drift not only at the standalone small / statement-trace source cuts but
  also at the new combined machine-backed small-kernel and combined
  statement-trace bridge refinement routes, in addition to the older outer
  confidential-bypass drift cases
- the smaller emitted `RuntimeConfidentialCoreKernelFinishSlotBundle` now also
  meets that checked inner shared-kernel source cut directly through the new
  `RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary`,
  `RuntimeImplementationKernelMeetingBoundary`, and
  `RuntimeImplementationKernelMeetingConfinementBoundary`, plus
  `RuntimeImplementationSharedKernelRefinementBoundary`, which recheck one
  emitted finish-slot bundle together with the checked dedicated
  statement-trace bridge cut, then explicitly meet that finish-slot route back
  up with the emitted machine-finish route by checking equality of the native
  finish bundle, require the full checked implementation interface in the
  meeting-confinement object, and only then appeal to the larger checked
  shared-kernel source interface; the stronger direct
  `RuntimeImplementationKernelMachineConfinementBoundary` checker then takes
  the full source-backed implementation interface, the live machine-finish
  witness, the fixed slot program, and the opcode trace straight to the
  outer implementation-confinement boundary while pinning the consumed
  public schedule, live kernel-op/runtime-phase capacity bounds, and the
  consolidated
  `paperEndToEndConfinementWithPublicOnlyHandwrittenShell` theorem without the
  separate emitted finish-slot meeting artifact while also stating that the
  handwritten runtime shell is public-only; the same direct route now also
  exposes the narrower `paperPublicBridgeObserverRefinement` theorem for the
  public observer half. The combined
  `RuntimeImplementationConfinementBoundary` now packages the same public-only
  outer theorem and matching public-bridge observer refinement without the
  machine witness. Those paired objects project directly to the native
  `RuntimeKernelFinishSlotBoundary`, to exact `RefinesLeanKernelState`, and on
  to `RuntimeKernelConfinementBoundary`. `tamper_validation.json` now rejects
  both source-side and artifact-side statement-trace drift plus emitted
  finish-slot public-schedule drift on that direct statement-trace refinement
  route, on the new kernel-meeting / kernel-meeting-confinement routes, and
  on the direct kernel-machine-confinement route as well as on the older
  shared-kernel refinement route
- the live emitted `RuntimeKernelMachineFinishWitness` now also freezes the
  closer-to-implementation shared-kernel machine finish state, including the
  consumed expected-kernel schedule index, the machine's kernel-op budget,
  and the runtime-phase event capacity bound; Lean now validates that witness
  directly in `runtime_kernel_machine_finish_witness_validation.json` and
  validates the standalone imported/native machine-finish-boundary route in
  `runtime_kernel_machine_finish_boundary_validation.json`, and
  also validates the combined source/artifact pairings in
  `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`
  and
  `runtime_implementation_small_confidential_kernel_machine_refinement_boundary_validation.json`
  and
  `runtime_implementation_shared_kernel_machine_refinement_boundary_validation.json`,
  while `tamper_validation.json` rejects representative machine-finish
  schedule-consumption and runtime-phase-capacity drift at the standalone
  witness checker, the standalone native machine-finish boundary, and the
  slot-adapter, small-confidential-kernel, and shared-kernel machine-backed
  source/artifact pairings
  the combined machine-backed small-confidential-kernel and shared-kernel
  boundaries
- that kernel witness now also carries an explicit public kernel-step trace
  over `{ opcode, object_id? }`, so the proof-grade interface fixes the
  kernel-visible persistent-object schedule rather than only a flat opcode
  journal
- that kernel witness now also carries an explicit public resource-event trace
  over stack checks plus scratch reservations and wipes, so the proof-grade
  interface fixes not only the admitted public object schedule but also the
  exact public evidence used to justify the exported stack/scratch summary
- the repo now also validates that smaller proof object directly through a
  standalone proof-grade kernel-witness checker before lifting it into the
  trusted-kernel and full refinement bundles
- the theorem-facing kernel schedule is now an explicit object with a modeled
  replay semantics, and the proof-grade kernel / trusted-kernel / refinement
  validators now require that the admitted public schedule actually reaches a
  finished small-kernel state rather than only matching by static shape
- that modeled final state now also exposes the exact public object-id schedule
  induced by the admitted `{ opcode, object_id? }` trace, so the proof-grade
  boundary fixes both successful replay and the resulting public object-order
- the runtime phase witness now also has a first-class theorem-facing
  refinement relation to that finished Lean kernel state, and the checked
  source-backed `RuntimeImplementationInterface` now closes the corresponding
  non-kernel honesty gap at the real `uo-evm` module boundary by pairing that
  interface with the exact emitted `RuntimeKernelInterfaceBundle` inside the
  explicit `RuntimeImplementationConfinementBoundary`
- the runtime now also emits a lower-level
  `RuntimeKernelRefinementWitness` under the public kernel witness: it records
  the concrete runtime phase order `pre-committed-cold objects* -> Begin ->
  shadow-load objects* -> kernel steps* -> Commit -> commit objects* -> Wipe
  -> cold-store objects* -> post-committed-cold objects*` while keeping the
  theorem-facing public kernel ABI unchanged
- that lower-level phase witness lives in the runtime refinement witness, not
  the smaller trusted-kernel bundle, and Rust plus Lean both validate that it
  projects exactly to the emitted public kernel-step schedule and reaches the
  modeled final phase
- confidential expression / statement interpretation for admitted entrypoints
  now also runs through the shared `RuntimeKernelMachine` path, while the
  non-confidential interpreter has been split into the explicit
  `runtime/uo-evm/src/shell.rs` public-shell module, so the engine is public
  orchestration only and the remaining secret-bearing execution state sits
  behind the smaller kernel boundary
- that confidential execution state is now also slot-lowered and fixed-width:
  `uo-core` lowers admitted confidential entrypoints to a slot program, and
  the shared runtime-kernel path executes that form with a bounded fixed-size
  `Box<[Option<Value>]>` slot file rather than a
  `BTreeMap<String, Value>` name environment; the fixed-shape confidential
  array / small-map logical buffers, the boxed UO cell ciphertext slot, the
  live Path-ORAM entry array, live stash, and live Path-ORAM position map now
  also use fixed-capacity buffers, the path-bucket payload uses a fixed-shape
  block buffer, and the fixed public-shape Path-ORAM page arrays plus boxed
  ORAM counter slot are fixed boxed buffers as well; the raw-backend
  `RawMapEntry` ciphertext slot is now boxed too, so the runtime object graph
  no longer keeps secret-bearing ciphertext in growable `Vec<u8>` buffers, and
  the remaining exact-size bootstrap seal paths plus the small-map record /
  bucket plaintext helpers now also stay on exact-size boxed buffers rather
  than widening back into temporary `Vec<u8>` carriers before boxing
- the emitted kernel-step witness and lower-level runtime phase witness now
  also live inside shared `uo-core` execution/refinement trackers derived from
  public kernel-op/object bounds; those tracker journals now use the shared
  fixed-capacity `BoundedJournal<T>` over boxed `MaybeUninit` storage and the
  source-backed interface rejects the old `Vec` tracker fields, while the
  remaining public shell-side commit / witness helper lists start from
  explicit `Vec::with_capacity(...)` bounds rather than plain `Vec::new()`,
  and ORAM placeholder states now use direct empty boxed slices instead of
  `Vec::new().into_boxed_slice()` bootstrap carriers
- the runtime phase witness commit/cold-store windows now also append through
  the shared `uo-core` `RuntimeKernelRefinementTracker`, so `kernel.rs` /
  `state.rs` no longer extend those witness tails by mutating raw event
  vectors directly
- that runtime-phase journal now also lives behind the shared
  `RuntimeKernelRefinementTracker` in `uo-core`, so `kernel.rs` no longer owns
  a separate phase-machine helper or local event-bound calculation for the
  lower-level refinement witness
- the final `RuntimeKernelWitness` constructor call in `kernel.rs` has now
  collapsed into a shared `uo-core` telemetry/execution helper, so the runtime
  no longer owns the field-by-field assembly of the theorem-facing kernel
  witness after execution finishes
- that finalization path has now tightened further into one shared
  `uo-core` `RuntimeKernelFinishSnapshot`, so `kernel.rs` no longer separately
  appends the runtime-phase cold-store tail and then reconstructs the emitted
  witness pair by hand; the kernel now hands one consumed finish object to
  `uo-core` and gets back the checked theorem-facing witness pair
- the public `ExecutionTrace` boundary has now tightened around that finish
  object as well: kernel-finish export goes through the checked
  `exact_runtime_kernel_finish_bundle()` path, the raw stored trusted-kernel
  / controller accessors are gone, and the old raw ORAM object / leaf /
  position-map / after-counter accessors have been removed from the public
  trace API in favor of higher-level exact bundles plus one theorem-facing
  public ORAM access-counter map
- `uo-allocator` now hands that helper the corresponding
  `RuntimeKernelTelemetrySnapshot` directly from its consumed `finish()` path,
  so `kernel.rs` no longer repacks allocator plan/scratch/resource telemetry
  by hand and no longer exposes a separate snapshot-conversion API
- that runtime phase witness is now also exported through a sealed
  `RuntimeKernelRefinementWitness` surface: the `events` vector is private,
  cross-module consumers rebuild or inspect witnesses through explicit
  `from_events(...)` / `events()` / `event_count()` / `first_event()` /
  `last_event()` APIs, and the probe statically checks that the runtime helper
  path keeps using those shared constructors rather than raw field literals;
  the derived `RuntimeShellTrace` now follows the same pattern with private
  stored schedules/events plus explicit constructor/accessor APIs, and those
  exported shell-trace event/schedule summaries now stay boxed rather than
  reopening into growable `Vec` carriers; the shared
  `RuntimeKernelScheduleWitness` under that interface now keeps both opcodes
  and steps boxed as well
- live Path-ORAM stash state now also carries one public
  `working_stash_capacity(...)` bound, is rebuilt with that headroom up front,
  preserved across cold commits with `.clear()`, and checked before use so the
  runtime no longer depends on a late mid-call stash `reserve(...)`
- path-bucket rebuilds now also use fixed-shape block buffers keyed by the
  manifest `blocks_per_bucket` budget rather than transient growable block
  vectors
- Path-ORAM clones and refresh now also preserve and reuse the public
  entry / position-map / stash capacities in place rather than replacing them
  with fresh zero-capacity vectors
- touched Path-ORAM aborts now also restore old state in place via
  `OramState::restore_from_old(...)`, so neither untouched nor aborted
  `UoOramMap` commits replace the whole shadow ORAM object anymore
- the full-scan array/small-map paths now also reuse their logical buffers in
  place across both cold commit and old-state restoration: cold commits clear
  and resize `values` / `entries`, while abort and untouched restore paths
  decode old sealed state back into those same boxed buffers rather than
  replacing them; written UO cell/array/small-map commits now also reuse their existing
  ciphertext slot buffers in place, while untouched commits keep their
  already-cloned ciphertext buffers instead of re-cloning old physical slots
- the remaining object-store schedule cuts have also been tightened at the
  source/proof interface: Path-ORAM write evidence is fixed to exact public
  batches (`OramWriteBatch` / `OramWriteLog`) and modeled by
  `RuntimeOramWriteLogDiscipline`, which also models exact public-capacity
  read-transcript builders; the live ORAM read transcript now uses
  boxed logical/physical-read arrays materialized only by generated fixed
  public-capacity builders rather than temporary growable trace vectors in
  handwritten `oram.rs`; the ORAM
  commit path now also routes its reopen/bootstrap/commit shell through the
  shared `with_opened_oram_payload(...)`,
  `seal_boxed_oram_payload(...)`, `filler_boxed_oram_payload(...)`, and
  `reseal_oram_payload_and_record_write(...)` helpers while the source-backed
  interface separately freezes the restore-vs-exact-write-batch split; the
  handwritten consumers of those fixed batches now go through
  `OramWriteBatch::for_each_write(...)`, which rejects malformed public-prefix
  batches instead of silently filtering missing entries, and the direct
  machine-confinement report exposes this as
  `oram_write_batch_iteration_is_checked`; the same report now also marks
  `runtime_interface_production_avoids_panic_style_control_flow` for the full
  production source-backed interface, after converting allocator event
  finalization, proof-object JSON/trace hashing, and aggregate canonical value
  length encoding away from panic-style assumptions; UO
  small-map lookup is a masked full-capacity scan modeled by
  `RuntimeSmallMapLookupDiscipline`, and UO array reads/writes are masked
  full-capacity scans modeled by `RuntimeArrayAccessDiscipline`, with UO-path
  out-of-range indices selecting no slot / updating no slot rather than taking
  a public OOB branch
- generated confidential-kernel return scheduling is now source-pinned too:
  lowering rejects non-final source returns, the generated interpreter no longer
  contains a post-return `state.returned` / `break` path, and
  `RuntimeReturnScheduleDiscipline` models the accepted public return-tail shape
- the low-level runtime object transition helpers that reopen shadow state,
  commit objects, export hidden ORAM witnesses, and cold-store committed
  state are now compile-time restricted to the shared `crate::runtime`
  module, and `RuntimeObject` no longer implements `Clone`, so those
  secret-bearing paths are no longer callable or duplicable from `engine.rs`;
  the runtime boundary now also distinguishes the public-shell
  `PublicRuntimeShadowState` handle from the confidential-kernel
  `ConfidentialRuntimeShadowState` handle instead of exposing one generic
  shadow wrapper across both sides
- the remaining shadow-load, shadow-commit reconciliation, and injected
  Path-ORAM fresh-coin routing steps now also live in `runtime/uo-evm/src/state.rs`
  rather than being assembled in a separate `uo-evm` kernel module, so the
  shared-kernel/runtime boundary no longer clones committed objects or rewrites
  shadow maps from a runtime-local shim; the long-lived committed/shadow object carrier in `state.rs` has
  also now been reduced from a generic `BTreeMap<u32, RuntimeObject>` to a
  boxed fixed-order object table over the public object universe
  itself; the live controller observer has likewise shed its generic
  page/workset/access-count maps in favor of fixed public
  `ControllerRegionCounters` plus per-object counts derived from the observed
  public ORAM schedule
- the theorem side now exposes a proof-grade exactness lemma for that
  lower-level phase witness, and now packages it as an explicit
  `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem: the shell's
  pre/post committed-cold boundary schedules are fixed to the full public
  object universe, and its shadow-load / commit / cold-store schedules are
  fixed to the canonical public touched-object set induced by the admitted
  kernel schedule. The strongest current bridge story is therefore "the real
  shell implementation refines the modeled shell/kernel contract" rather than
  only "public kernel schedule was emitted and checked"; the exported shell
  trace now also carries the ordered public runtime-phase event list, and
  Rust/Lean both check that the summary schedules are honest projections of
  those events and that the event trace replays the public shell contract
- `uo-core` now also exports that shell/kernel boundary directly as a
  `RuntimeShellBoundaryBundle` carrying the proof-grade kernel witness, the
  runtime phase witness, and the explicit `RuntimeShellContract` /
  `RuntimeShellTrace` JSON views; Lean now validates that those exported shell
  objects are exactly the ones reconstructed from the witnesses, that the
  shell-event trace replays the shell contract, and that the shell trace
  refines the shell contract, and the probe reports that checker separately as
  `shell_boundary_validation.json`
- that shell-boundary bundle is now sealed on the Rust side as well: the
  witness / contract / trace fields stay private behind explicit accessor
  methods, the shell contract itself is now accessor-only rather than a public
  field bag, the internal shell-trace constructor is no longer public, and the
  probe treats any re-publication of those fields or drift in the getter
  surface as a proof-interface regression; the exported shell contract's
  public-object schedules and the exported shell trace's event/schedule
  summaries now also stay in boxed fixed-shape buffers, and the shared
  exported `RuntimeKernelScheduleWitness` now keeps its opcode trace and step
  list boxed on the theorem-facing path too. The theorem-facing
  `RuntimeKernelWitness` now follows that same discipline for its resource
  trace, emitted/expected kernel-step lists, and emitted/expected public
  object schedules
- the lower-level runtime-phase witness constructor is now checked as well:
  malformed phase traces are rejected at construction time before they can be
  packaged into shell-boundary or larger runtime proof artifacts
- the proof-grade `RuntimeKernelWitness` now follows the same discipline: its
  Rust fields are no longer public, the runtime producer uses one checked
  constructor instead of a field literal, and the probe now treats any return
  to public-field access or unchecked construction as proof-interface drift
- the derived `RuntimeKernelScheduleWitness` is now sealed the same way:
  schedule opcodes/steps are private behind explicit accessors, construction
  flows through one checked constructor, and the probe treats any new raw
  schedule-literal path or reopened field access as proof-interface drift
- the shared DSL/interpreter route now also composes directly through that
  shell interface: `uo-core` exports a
  `RuntimeShellBoundaryLoweringBundle` carrying the shell-boundary bundle plus
  the named and slot confidential programs for the same entrypoint, and Lean
  checks both the shell-boundary refinement claim and the named-to-slot
  lowering claim against one shared proof-grade kernel witness; the probe
  reports that composition step separately as
  `shell_boundary_lowering_validation.json`
- that shell interface now also has a direct slot-only proof path:
  `uo-core` exports a `RuntimeShellBoundarySlotBundle` carrying the
  shell-boundary bundle plus the exact fixed-slot confidential program that
  the shared runtime-kernel path actually executes, and Lean checks that the shell-boundary
  refinement claim and the slot-derived kernel schedule share one exact
  proof-grade kernel witness; the probe reports that slot-only path
  separately as `shell_boundary_slot_validation.json`
- the confidential-kernel lowering definitions that underlie that bridge are
  now total structurally recursive Lean definitions on both the runtime and
  imported sides rather than opaque `partial def`s, which removes the old
  definitional-opacity blocker; the imported/runtime commutation layer is now
  restored through whole-program lowering, and the runtime-facing kernel-only,
  confidential-core, shell-boundary, and combined lowering bundles now source
  the canonical named and slot confidential programs directly from the checked
  manifest entry rather than reconstructing them ad hoc from the IR body
- the post-call `cold_store_object` / `post_committed_cold_object` tail of
  that phase witness now also gets finalized inside the shared
  `uo-kernel-runtime` / `state.rs` boundary, while `state.rs` only checks that the
  resulting committed state is cold at the public boundary, so `engine.rs` no
  longer constructs runtime phase-witness events directly
- the post-call proof-facing `ExecutionTrace` packaging now also lives in
  `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer constructs the
  controller-observer certificate, hidden Path-ORAM certificate, or
  trusted-kernel bundle directly; the proof-bearing runtime fields carried by
  `ExecutionTrace` now also keep their stored state private and are exported
  only through explicit accessors / validated reconstruction helpers, so the
  theorem bridge no longer depends on public field mutation after trace
  materialization; `RuntimeKernelRefinementWitness` now likewise keeps its
  tail-appending mutators private, and the intermediate
  `RuntimeExecutionTraceParts` carrier now also uses one explicit constructor
  instead of a public-field literal surface
- the confidential-path shared-kernel entrypoints that shadow-load
  committed state, run confidential calls, and commit public shadows are now
  also visibility-restricted to `crate::runtime`, so the generic shell cannot
  call those kernel hooks directly
- `engine.rs` now delegates public execution to `runtime/uo-evm/src/shell.rs`
  and both confidential manifest-to-kernel planning plus confidential-kernel
  setup to `runtime/uo-evm/src/state.rs`, so the engine no longer imports
  either the shared `RuntimeKernelMachine` or the public kernel facade
  directly, and it no longer loads the manifest-carried confidential slot
  program, derives the
  admitted runtime kernel-step trace, or threads the manifest hash-scratch
  bound or confidential commit budget itself; the runtime now validates the
  slot program against `manifest.kernel_steps` once and then carries the
  checked slot program forward as the canonical public budget / witness
  schedule, with downstream consumers reading that schedule through
  `EntrypointManifest::canonical_kernel_step_manifest()` instead of directly
  from the duplicated raw manifest field
- confidential `Expr::Select` now also evaluates both admitted pure arms and
  combines them with `Value::confidential_select` instead of branching on the
  secret condition in Rust, while checker-side compiler validation and the
  proof-grade kernel-witness validator reject confidential select arms outside
  that branchless pure fragment
- confidential `Expr::StructField` and `Expr::ArrayIndex` are now both
  rejected from the admitted confidential fragment entirely
- `confidential_fragment_validation.json` now scans the admitted UO benchmark
  artifacts directly and confirms that their confidential entrypoints contain
  no non-branchless select arms, no confidential `StructField`, and no
  confidential `ArrayIndex`
- `kernel_dsl_validation.json` now bridges the shared confidential-kernel DSL
  across Rust and Lean: it serializes the exact manifest-carried named
  confidential program and checks that the DSL-derived kernel schedule matches
  the proof-grade runtime kernel witness exactly
- `kernel_slot_dsl_validation.json` now checks the fixed-slot confidential
  program that the shared runtime-kernel path actually executes against that same
  proof-grade runtime kernel witness, and
  `kernel_lowering_validation.json` checks the canonical lowering from the
  named DSL to the slot DSL against that same exported witness
- `confidential_core_validation.json` now runs the combined Lean checker over
  each representative proof-grade runtime witness plus the exact lowered
  confidential program for the invoked entrypoint, so the shell-refinement
  guarantee is discharged only for executions whose embedded kernel witness
  matches the same DSL body that Rust executes; the artifact-derived
  confidential-fragment witness remains in the report as a separate
  diagnostic summary over the admitted fragment, and the checker now consumes
  one serialized confidential-core bundle
- `confidential_core_slot_validation.json` ties that same proof-grade
  runtime/refinement claim directly to the manifest-carried fixed-slot
  confidential program that the shared runtime-kernel path actually executes, while
  `confidential_core_kernel_interface_slot_validation.json` now lifts that
  same fixed-slot route across the explicit exported
  `RuntimeKernelInterfaceBundle`, so one runtime witness, one valid explicit
  runtime kernel-interface bundle, and one exact confidential slot program are
  checked together by Lean before the artifact is accepted, while
  `kernel_slot_boundary_validation.json` now rechecks that same shared bundle
  through the more exact
  `checkProofGradeRuntimeKernelSlotBoundary` interface so the imported
  singleton `PaperMainRuntimeKernelSlotBoundaryAt` route is benchmark-backed
  directly instead of being visible only through the larger composite checker,
  while
  `confidential_core_shell_boundary_slot_validation.json` lifts that slot-only
  path across the explicit shell-boundary bundle so the runtime witness,
  shell-boundary bundle, and exact slot schedule are checked together against
  one shared proof-grade kernel witness and runtime phase witness, while
  `kernel_interface_validation.json` now runs those same representative
  runtime runs through the dedicated paper-facing
  `checkProofGradeRuntimeKernelInterfaceBundle` checker over the explicit
  exported `RuntimeKernelInterfaceBundle`,
  `kernel_refinement_boundary_validation.json` now rechecks that same
  exported bundle through the more exact
  `checkProofGradeRuntimeKernelRefinementBoundary` interface,
  `kernel_interface_confinement_boundary_validation.json` now rechecks the
  accepted runtime-witness JSON directly through the dedicated
  `checkProofGradeRuntimeKernelInterfaceConfinementBoundary` executable,
  `kernel_confinement_boundary_validation.json` now rechecks that same
  exported bundle through the exact
  `checkProofGradeRuntimeKernelConfinementBoundary` interface, and
  `confidential_core_lowering_validation.json` composes the named and slot
  DSL objects and checks canonical lowering against the same exported witness
- `confidential_core_shell_boundary_lowering_validation.json` now lifts the
  proof interface one layer higher still: the runtime witness, explicit
  shell-boundary bundle, named DSL, and slot DSL travel together in one
  exported object, and Lean proves that those artifacts share one exact
  proof-grade kernel witness and one exact runtime phase witness rather than
  only validating each layer independently
- the same runtime witness path still has the direct paper-facing Lean
  executable, `checkProofGradeRuntimeKernelInterface`, while the stronger
  explicit theorem surface now also has
  `checkProofGradeRuntimeKernelInterfaceBundle`, which accepts the exported
  `RuntimeKernelInterfaceBundle` and checks the exact shell-boundary /
  Lean-kernel interface facts consumed by the stronger theorem story; the
  imported bridge now also proves that one accepted runtime witness projects
  directly to the explicit `RuntimeKernelConfinementBoundary`, and that one
  accepted explicit bundle projects directly both to the exact
  `RuntimeKernelRefinementBoundary` and to the explicit
  `RuntimeKernelConfinementBoundary`, and the dedicated
  `checkProofGradeRuntimeKernelInterfaceConfinementBoundary` executable plus
  `kernel_interface_confinement_boundary_validation.json` artifact report now
  exercise that exact witness-fed confinement route on the benchmark-backed
  runtime scenarios; the dedicated
  `checkProofGradeRuntimeKernelRefinementBoundary` executable plus
  `kernel_refinement_boundary_validation.json` artifact report now exercise
  that exact refinement-boundary route on the benchmark-backed runtime
  scenarios while the dedicated
  `checkProofGradeRuntimeKernelConfinementBoundary` executable plus
  `kernel_confinement_boundary_validation.json` exercise the matching
  confinement-boundary route on those same scenarios; the
  stronger confidential-core/kernel-interface/slot bridge now likewise
  projects directly to the exact singleton
  `PaperMainRuntimeKernelSlotBoundaryAt`, and the dedicated
  `checkProofGradeRuntimeKernelSlotBoundary` executable plus
  `kernel_slot_boundary_validation.json` artifact report now exercise that
  exact slot-boundary route on the same benchmark-backed runtime scenarios; the
  native and imported theorem routes now both prove that this explicit bundle
  surface projects back to the older proof-grade runtime/kernel boundary
  facts, so downstream paper routes can stay on the explicit bundle object
  without losing access to the legacy boundary-facts interface,
  the paper theorem route now also projects both
  `PaperMainRuntimeKernelBoundary` and
  `PaperMainRuntimeKernelSlotBoundary` mechanically back to that older
  `RuntimeProofGradeKernelBoundaryFacts` surface,
  stronger confidential-core composite route now also has
  `checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot`, which accepts
  the exported `RuntimeConfidentialCoreKernelInterfaceSlotBundle` and checks
  that the admitted confidential slot program agrees with the same exported
  runtime witness and explicit kernel-interface bundle; the seeded paper-route
  artifact path now likewise has
  `checkProofGradeRuntimePaperMainFamilyBundle`, which accepts the exported
  `SeededRuntimePaperMainFamilyBundle` and checks exact paper-route
  public-outcome / boundary-schedule agreement across the seeded family,
  `checkProofGradeRuntimePaperMainSlotFamilyBundle`, which accepts the
  exported `SeededRuntimePaperMainSlotFamilyBundle` and checks the same
  shared-family facts together with one exact confidential slot program and
  one exact exported `opcode_trace`, so the paper-route slot-family object
  now binds the live confidential statement trace to the admitted manifest
  slot program instead of only rechecking entrypoint and expected-kernel-step
  agreement, and the confidential theorem finalizer now also rebuilds both
  explicit seeded paper-route bundles online from the emitted runtime
  refinement witness before returning the production trace. That online
  proof-bearing bundle recheck now routes through one shared `uo-core`
  `RuntimeConfidentialProofBundleFamily`, so `runtime/uo-evm/src/theorem.rs`
  no longer manually sequences the kernel/slot/lowering/trusted-kernel/
  confidential-core bundle constructors itself; on the imported Lean side, the
  family and stronger slot-family bundles now also project to the reusable
  theorems
  `importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_family_assurance`
  and
  `importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_family_slot_assurance`,
  and the runtime-boundary anti-drift report pins both theorem surfaces
  alongside the stronger kernel-interface-slot paper route, including the
  direct imported family / slot-family projections to valid native
  shell-boundary bundles and to the explicit
  `RuntimeKernelConfinementBoundary`. The imported shared proof-family
  artifact now also projects directly to the exact
  `RuntimeKernelRefinementBoundary`, to the paper-main family runtime
  assurance, and to the stronger paper-main slot-family assurance, and the
  probe now runs a dedicated `confidential_proof_family_validation.json`
  report backed by `checkProofGradeRuntimeConfidentialProofBundleFamily`,
  plus the exact-boundary
  `confidential_proof_family_slot_boundary_validation.json` route backed by
  `checkProofGradeRuntimeConfidentialProofBundleFamilySlotBoundary`, plus the
  exact-boundary
  `confidential_proof_family_refinement_boundary_validation.json` route backed
  by `checkProofGradeRuntimeConfidentialProofBundleFamilyRefinementBoundary`,
  and the seeded paper-main slot boundary plus confidential proof-family slot
  assurance reports now publish explicit statement-trace length/match fields
  so the strengthened slot-family route is visible in the emitted validation
  artifacts rather than only inside the checker proofs,
  so the whole shared runtime bundle family is exercised both as one
  theorem-facing artifact and at the exact singleton slot-boundary,
  confinement-boundary, and exact runtime-kernel refinement-boundary theorem
  surfaces rather than only as source-level anti-drift structure
- the theorem-facing Lean side now also exposes matching runtime bundle
  objects, not only imported JSON checkers:
  `RuntimeShellBoundaryBundle`, `RuntimeShellBoundarySlotBundle`,
  `RuntimeShellBoundaryLoweringBundle`,
  `RuntimeConfidentialCoreBundle`, `RuntimeConfidentialCoreSlotBundle`,
  `RuntimeConfidentialCoreKernelInterfaceSlotBundle`,
  `RuntimeConfidentialCoreShellBoundarySlotBundle`,
  `RuntimeConfidentialCoreLoweringBundle`, and
  `RuntimeConfidentialCoreShellBoundaryLoweringBundle` all now exist as direct
  theorem objects with corresponding `Valid` predicates, so the imported
  artifact bridge lands on a first-class runtime proof interface rather than
  stopping at importer-local acceptance lemmas; those bundle interfaces now
  also preserve the manifest-carried named and slot confidential programs all
  the way through the runtime proof boundary, so the imported slot artifact is
  no longer silently rederived before crossing that proof/runtime boundary
- the probe now also runs a source-level anti-drift report,
  `kernel_model_alignment_validation.json`, that checks the Rust kernel
  opcode vocabulary, the confidential-kernel DSL kind tags and struct field
  names, and the Rust witness event alphabets against the explicit Lean
  vocabularies for opcodes, DSL variants and fields, runtime shell-contract /
  shell-trace / shell-boundary / shell-boundary-lowering field names,
  resource-event kinds, scratch regions, and refinement-event kinds, and it
  now also pins the `RuntimeKernelMachineFinishWitness` field schema plus the
  source-backed runtime implementation/shared-kernel boundary JSON schemas to
  their Lean import surfaces; that same report now also pins the exact
  shell-boundary bridge surface to
  `crates/uo-core/src/shell_boundary.rs`, requires the Rust bridge to derive
  `shell_contract` and `shell_trace` only from the kernel/refinement witness
  views plus an explicit `refines_contract` guard while keeping those helper
  derivations crate-confined to `uo-core`, requires downstream
  confidential-core bundles to reuse `RuntimeShellBoundaryBundle` rather than
  rederive shell summaries, requires the confidential-core theorem bundle
  entrypoints to stay confined to `crates/uo-core/src/confidential_core.rs`
  while keeping both the direct confidential-core bundle / slot-bundle /
  lowering-bundle trio and the confidential-core shell-boundary slot/lowering
  pair accessor-only on the Rust side,
  requires the trusted-kernel slot bundle bridge to stay confined to
  `crates/uo-core/src/trusted_kernel.rs` while continuing to source the exact
  manifest-carried slot DSL, reject slot-program entrypoint drift by
  construction, and keep both the trusted-kernel bundle and its slot wrapper
  accessor-only on the Rust side, requires the shell-boundary slot/lowering
  bundle bridge family to stay confined to
  `crates/uo-core/src/kernel_dsl.rs` while continuing to source the
  manifest-carried named and slot DSL programs and keep those shell-boundary
  slot/lowering bundles accessor-only on the Rust side,
  requires the direct runtime-kernel DSL / slot-DSL / lowering bridge family
  in that same `kernel_dsl.rs` module to stay confined and manifest-sourced as
  well while keeping the direct runtime-kernel DSL / slot-DSL / lowering
  bundles accessor-only on the Rust side, requires the direct runtime trusted-
  kernel / refinement export bridge
  in `crates/uo-core/src/trace.rs` to stay confined to exactness-checked
  trusted-kernel storage and export rather than parallel bundle assembly,
  requires `runtime/uo-evm/src/theorem.rs` to stay the only production caller
  of `ExecutionTrace::from_runtime_finalization_input(...)`, while
  `RuntimeExecutionTraceFinalizationInput::new(...)` and the shared
  `RuntimePublicCallTraceBundle::into_runtime_finalization_input(...)` route
  remain confined to `crates/uo-core/src/trace.rs`; the lower-level
  `ExecutionTrace::from_runtime_trace_parts(...)`,
  `ExecutionTrace::materialize_runtime_trusted_kernel_bundle(...)`, and
  `RuntimeExecutionTraceParts::new(...)` remain confined to
  `crates/uo-core/src/trace.rs`, and
  `trace.rs` to stay the only production site that performs the backing field
  assignment through its internal
  `store_runtime_trusted_kernel_bundle(...)`,
  now also checks explicit confidential statement, named-expression,
  named-pure-expression, slot-expression, and slot-pure-expression profile
  tables shared across the Rust and Lean sides, and it source-checks the live
  named-to-slot lowering bridge plus the live slot-statement / slot-expression
  / slot-pure-expression evaluator order against that shared structure, so
  trace names, runtime-normal-form flags, effect kinds, operand-evaluation
  order, storage-tail opcodes, and the named/slot pure-expression
  select/keccak operand structure are pinned together rather than being
  compared only through scattered per-method facts, while the tamper suite now
  also rejects representative named-expression profile-table drift,
  named-pure-expression profile-table drift, and named-to-slot lowering drift
  at the standalone implementation-interface checker, the standalone shared
  confidential-kernel-boundary checker, and the combined
  implementation-confinement boundary, and Lean now factors that checked
  source route into an explicit `PublicBridgeBoundary`, an explicit
  `SmallConfidentialKernelBoundary` for the actual tiny kernel files, an
  explicit `ConfidentialStatementTraceBridgeBoundary` for the exact
  statement-trace/proof-bundle bridge, and the larger
  `SharedConfidentialKernelBoundary` that conjoins those two confidential
  cuts, with dedicated emitted
  `runtime_small_confidential_kernel_boundary_validation.json`,
  `runtime_confidential_statement_trace_bridge_boundary_validation.json`,
  and `runtime_shared_confidential_kernel_boundary_validation.json`
  artifacts for those standalone and combined inner cuts, so the future
  below-interface refinement theorem can target one named tiny-kernel
  interface rather than one flat runtime conjunction; the tamper suite now
  also rejects representative secret-branch drift, centralized profile-table
  drift, named-to-slot lowering drift, and Path ORAM early-exit scan drift
  already at the standalone small-confidential-kernel boundary and the
  combined small-confidential-kernel machine-refinement route, plus
  statement-trace recording / bridge drift at the standalone
  confidential-statement-trace bridge boundary and the combined
  confidential-statement-trace bridge refinement route; the probe now also
  pins the first Lean-first generated-kernel step: Lean emits
  `crates/uo-core/src/generated_confidential_kernel.rs` from
  `proof/lean/GenerateConfidentialKernelRust.lean`, the shared kernel
  delegates live slot-program/block/statement execution and unary/binary
  operator semantics into that generated evaluator, profile tables are
  re-exported from the generated artifact, and the checked
  `SmallConfidentialKernelBoundary` now exact-matches the generated
  confidential-kernel interpreter/profile tables, generated runtime-kernel
  machine schedule, and generated slot-support module against their Lean
  generators while `kernel_model_alignment_validation.json` rechecks the same
  equalities as a separate Rust/Lean audit; `tamper_validation.json` now also rejects
  representative generated-interpreter drift at the implementation-interface,
  standalone small-kernel, standalone shared-kernel, and combined confinement
  cuts; the implementation boundary now also checks that the remaining
  handwritten `uo-kernel-runtime` slot/effect adapter is only a forwarding
  shell and rejects raw confidential-argument observation drift, Lean now
  exposes that narrower cut as the standalone
  `RuntimeImplementationSlotAdapterBoundary`, the probe emits
  `runtime_slot_adapter_boundary_validation.json`, and tamper validation now
  also rejects generated slot-support argument-count drift, generated
  confidential-interpreter drift, and shared-kernel interpreter-bypass drift
  there. Lean now also exposes the direct machine-backed meeting between that
  same source cut and the emitted live machine-finish witness as
  `RuntimeImplementationSlotAdapterMachineRefinementBoundary`, and the probe
  emits
  `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`;
  Lean packages the paper-facing conjunction there as
  `RuntimeImplementationSlotAdapterMachineRefinementBoundary.paperSlotAdapterMachineRefinement`;
  the wider
  `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary`,
  `RuntimeImplementationSharedKernelMachineRefinementBoundary`, and
  `RuntimeImplementationKernelMachineConfinementBoundary` routes now also
  project through that same theorem and emit
  `paper_slot_adapter_machine_refinement_theorem_checked` in their reports;
  the small-confidential-kernel-machine route now also emits
  `paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
  and `paper_small_kernel_machine_observer_refinement_theorem_checked` for
  `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell`
  and
  `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineObserverRefinement`;
  the shared-kernel-machine route now also emits
  `paper_shared_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
  and `paper_shared_kernel_machine_observer_refinement_theorem_checked` for
  `RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell`
  and
  `RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSharedKernelMachineObserverRefinement`,
  tamper validation rejects representative expected-schedule-index drift,
  kernel-op/runtime-phase capacity drift, slot-program body drift,
  opcode-trace drift, generated confidential-interpreter drift, shared-kernel
  interpreter-bypass drift, generated post-return-break drift, generated
  slot-support argument-count drift, and handwritten raw-argument observation
  drift there, and it pins
  the runtime machine effect schedule for public opcode recording, bounded
  scratch reservation, object-store delegation, commit-schedule append, and
  finish-time wiping; Lean now exposes that effect shape as
  `RuntimeKernelMachineSchedule`, and tamper cases exercise the direct
  machine-confinement checker; the source-backed boundary now also imports
  `runtime/uo-allocator/src/lib.rs` and checks allocator-session
  kernel-op/scratch/stack budgets, guard-drop wipe, finish-time wipe
  validation, public-capacity resource-event logging, boxed finish-boundary
  resource events, and absence of unsafe/forget-style escape hatches, with
  `RuntimeAllocatorDiscipline` backing the allocator transition shape and
  allocator scratch-budget / resource-event-log tamper cases through the
  direct machine-confinement checker; the statement-trace recorder is now
  exact-capacity and modeled by `RuntimeStatementTraceDiscipline`; the generated
  confidential-kernel return schedule is now modeled by
  `RuntimeReturnScheduleDiscipline`, and return-break drift is rejected by the
  implementation-interface, standalone small-kernel, standalone shared-kernel,
  direct machine-confinement, and combined confinement routes; the probe
  now also
  emits the
  standalone
  `runtime_kernel_machine_finish_witness_validation.json` report, the
  standalone
  `runtime_kernel_machine_finish_boundary_validation.json` report, plus the
  combined
  `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`
  report, the combined
  `runtime_implementation_small_confidential_kernel_machine_refinement_boundary_validation.json`
  report, the combined
  `runtime_implementation_confidential_statement_trace_bridge_refinement_boundary_validation.json`
  report, the combined
  `runtime_implementation_kernel_meeting_boundary_validation.json` report, plus the
  combined
  `runtime_implementation_shared_kernel_machine_refinement_boundary_validation.json`
  report, so the closer-to-implementation live machine finish state is now
  checked by itself, checked as a standalone native machine-finish boundary
  over the fixed slot program/opcode trace, checked together first with the
  smaller finish-slot bridge/meeting/shared-refinement routes whose reports
  now also mark `refines_lean_kernel_state_theorem_checked` and
  `runtime_kernel_confinement_projection_theorem_checked`,
  with the confidential-statement-trace bridge refinement report now also
  marking `confidential_statement_trace_bridge_boundary_theorem_checked`,
  the kernel-meeting report now also marking
  `shared_confidential_kernel_boundary_theorem_checked`,
  `small_confidential_kernel_boundary_theorem_checked`,
  `confidential_statement_trace_bridge_boundary_theorem_checked`, and
  `slot_adapter_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `handwritten_runtime_public_only_theorem_checked`,
  the shared-kernel refinement report now also marking
  `shared_confidential_kernel_boundary_theorem_checked`,
  `slot_adapter_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `handwritten_runtime_public_only_theorem_checked`,
  and the outer implementation-confinement report now also marking
  `runtime_kernel_confinement_projection_theorem_checked` together with
  `shared_confidential_kernel_boundary_theorem_checked` and
  `small_confidential_kernel_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `slot_adapter_boundary_theorem_checked`, the
  meeting-confinement report marking
  `runtime_implementation_confinement_projection_theorem_checked` together
  with `shared_confidential_kernel_boundary_theorem_checked` and
  `small_confidential_kernel_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `slot_adapter_boundary_theorem_checked`, and the
  direct machine-confinement report marking
  `runtime_implementation_machine_confinement_projection_theorem_checked`
  together with `native_machine_semantics_theorem_checked`,
  `shared_confidential_kernel_boundary_theorem_checked`,
  `small_confidential_kernel_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`,
  `slot_adapter_boundary_theorem_checked`, and
  `public_bridge_boundary_theorem_checked`,
  dedicated small-confidential-kernel source cut and then with the checked
  shared confidential-kernel source interface before that machine state is
  flattened to the smaller finish-slot artifact, while the smaller finish-slot
  artifact itself is also paired directly with the dedicated confidential
  statement-trace bridge cut and then re-met with the machine-finish route at
  the native finish-bundle boundary before the wider shared-kernel refinement route,
  requires any stored trusted-kernel bundle to match the surrounding
  execution trace exactly before it can be re-exported, requires confidential
  kernel witnesses on the production path to be reconstructed only through the
  checked finish-bundle route rather than through a separate serialized
  `runtime_kernel_witness` field, requires the live machine finish witness to
  preserve exact schedule-consumption and machine-capacity facts before it can
  be paired with the source-backed shared-kernel boundary, and requires Lean
  to keep validating exact equality to those witness-induced shell views plus
  the runtime-kernel, confidential-core, shell-boundary slot/lowering,
  trusted-kernel, and runtime-refinement proof-grade equalities
- the boundary report now also checks constructor authority for those witness
  alphabets: production runtime phase-witness events are restricted to
  `runtime/uo-kernel-runtime/src/lib.rs` plus `runtime/uo-evm/src/state.rs`, and
  production resource-event witnesses are restricted to
  `runtime/uo-allocator/src/lib.rs`
- that same boundary report now also checks finer helper authority inside the
  shared runtime module: the secret-bearing `RuntimeObject` reopen / commit /
  cold-store / witness-export / fresh-coin helpers must be used only from
  `runtime/uo-evm/src/state.rs`, the shadow-state helpers that reopen
  committed state, install fresh coins, or reconcile committed shadows must
  be used only from `runtime/uo-evm/src/state.rs`, the shared-kernel hooks
  `shadow_load_with`, `commit_objects`, and `run_confidential_call` must be
  used only from `runtime/uo-evm/src/state.rs`, without exposing raw
  `inner_mut` / `into_inner` escape hatches on a runtime-local public-kernel
  wrapper, and
  the confidential shadow-load helper itself stays private to
  `runtime/uo-evm/src/state.rs`
- the same source-backed runtime implementation interface now also imports the
  low-level store helper layer:
  direct `StoreCipher::seal` / `StoreCipher::open` use must stay inside
  `runtime/uo-store/src/codec.rs`, the Lean-generated boxed-filler /
  seal-into helper surface in
  `runtime/uo-store/src/generated_store_helpers.rs`,
  and the thin call-site shell in `runtime/uo-store/src/store.rs`; the public
  store evidence buffers now cross that handwritten shell only as generated
  `StorePhysicalWriteTrace` / `StoreLogicalEventTrace` wrappers rather than raw
  `Vec<PhysicalWriteEvent>` / `Vec<LogicalEvent>` fields, and the generated
  wrappers themselves now use exact boxed-slice backing with fallible
  fixed-builder appends rather than `Vec` storage; the public wipe-preserving helper surface
  stays at `seal_and_wipe_boxed` / `seal_and_wipe_into_slice` /
  `filler_boxed` / `with_opened_payload`, the store write API takes mutable
  plaintext buffers, the generated store-codec artifact is now limited to the
  exact-size transport primitives rather than `Vec` convenience wrappers, the
  UO-store bootstrap/write shell must route through `filler_boxed_uo_store_slot` and
  `reseal_uo_store_slot_in_place`, confidential UO-store writes now emit only
  public update-shape write evidence instead of cloning ciphertext snapshots,
  `StoreCipher` zeroizes its key on drop, the generated store surface avoids
  `expect`, `unwrap`, and `panic!`, and Lean now exposes theorem-facing
  nonzero transport shape plus sealed-record public length facts for this
  residual generated codec stack,
  and the tamper suite now rejects boxed-filler / seal-into helper drift at
  the implementation-interface, standalone small-kernel, standalone shared-
  kernel, combined confinement, and direct machine-confinement routes
- the probe-side production-source scan now strips `#[cfg(test)]` items
  without truncating later production code, so those confinement checks cover
  files that place test-only utilities before additional production helpers
- Lean now also replays the emitted public resource-event trace against the
  kernel's public budgets and fixes one exact replayed resource state, and the
  theorem surface exposes that exact replayed state through the standalone
  kernel witness as well as the lifted refinement-witness and trusted-kernel
  bundle proof-grade lemmas
- the exported trusted-kernel bundle and refinement witness now embed that
  kernel witness, and Lean now threads it through both imported validation and
  theorem-side runtime / trusted-kernel validity checks for its envelope /
  budget / wipe invariants, with the proof-grade checker path now requiring
  the artifact-side exact expected public kernel-step trace and checking exact
  equality against it
- the kernel witness now also carries an explicit `io` scratch region for
  confidential storage payload staging, and the runtime accounts ORAM
  refresh/decode plus confidential commit/rewrite payload buffers under that
  region before exporting the witness
- confidential `keccak256` evaluation now streams canonical bytes into the
  hasher instead of allocating per-part plaintext buffers first
- confidential object commits and ORAM rewrites now use a wipe-on-seal path
  for owned plaintext buffers, and ORAM serialization no longer allocates
  extra per-block/per-record plaintext vectors just to append them into larger
  payloads
- committed UO state is now cold-stored after each call: the long-lived
  contract instance keeps sealed storage plus public metadata, and the hidden
  Path-ORAM before/after certificates are extracted from the opened shadow
  states before those decrypted caches are dropped again; Path-ORAM committed
  state is now also born cold at deployment, and the runtime rejects any
  call boundary where a committed object cache is still live
- proof-grade confidential calls now reopen only the admitted touched object
  set instead of eagerly shadow-loading every object in the contract, while
  untouched committed objects remain sealed and cold Path-ORAM position-map
  witnesses are reopened from ciphertext only when the hidden certificate
  needs them
- per-object store keys now zeroize on `StoreCipher` drop, which tightens the
  secret-key lifetime story for transaction-shadow and old-state clones
- the generic `uo-store` cell-write path now takes mutable plaintext buffers
  and wipes caller-owned bytes after raw copy / confidential seal, which
  removes one remaining borrowed-slice crypto path from the helper surface;
  the fixed-size raw/UO store slot maps now also keep their ciphertext cells
  in boxed buffers, and the UO write path seals directly into those fixed-size
  boxed slots instead of routing through a growable `Vec<u8>` slot carrier;
  the exact-size store seal/open/filler surface is now centralized through the
  Lean-generated `runtime/uo-store/src/generated_surface.rs` module, and the
  corresponding UO bootstrap/write shell is now centralized through the
  Lean-generated `runtime/uo-store/src/generated_store_helpers.rs`
  `filler_boxed_uo_store_slot` / `reseal_uo_store_slot_in_place` layer, and those
  helper routes are now pinned by the Lean-backed
  `RuntimeImplementationInterface`
- dropped logical `Value` trees, hidden ORAM state, injected fresh-coin tapes,
  and per-object runtime RNG state now scrub themselves more aggressively, and
  `engine.rs` now keeps only a public `PublicCallSummary` derived from the
  checked manifest's `param_names`, `secret_args`, and manifest-stored
  `entry_input_len` during theorem-trace construction instead of cloning the
  full secret-bearing call-argument vector or recomputing input length from
  those values; `engine.rs` now holds an opaque `ContractRuntime` wrapper
  rather than the raw committed confidential state, `engine.rs` now boxes call
  args once into a fixed-size slice for the traced-call/runtime path, and the
  runtime/state confidential branch then passes that payload directly to the
  shared `uo-kernel-runtime` confidential-call path, where the Lean-generated
  fixed-size `ConfidentialCallInputs` wrapper is created, consumed by
  `RuntimeKernelSlotCall`, checked for exact argument count, and wiped on
  drop;
  diagnostic
  fresh-coin plans now also keep per-object secret leaf tapes in fixed-size
  buffers, are consumed by value, and move into the live shadow state without
  cloning the per-object secret leaf tapes first, while the live
  `PathOramLeafCoinSource` now consumes those tapes through a fixed-size
  `(Box<[usize]>, cursor)` representation rather than a growable queue; the
  live hash-part iteration, fresh-coin install path, and boxed committed/shadow
  entry iteration now also stay on boxed carriers directly rather than
  bouncing confidential hot-path buffers through temporary `Vec` wrappers, and
  the proof-facing fresh-coin scaffold/value extractors plus the seeded /
  canonical runtime witness-family scaffolds, witness lists, and paper-main
  boundary schedules now likewise stay boxed instead of widening back into
  growable theorem-artifact containers, and
  the recursive runtime `Value` representation now also keeps both struct
  fields and array elements in boxed fixed-size buffers rather than growable
  `Vec` carriers while canonical payload extraction now goes through an
  exact-size boxed helper rather than `canonical_bytes().into_boxed_slice()`;
  the remaining generated `canonical_bytes()` `Vec` convenience method is
  test-only and is rejected from the production source-backed interface,
  and the theorem-side Path-ORAM leaf-state validator now keeps witness leaves
  boxed rather than reopening them into temporary `Vec` state, and
  the live Path-ORAM position map now also stays boxed across decode and
  rewrite instead of widening into a temporary `Vec<Option<usize>>`; the
  handwritten array object shell now keeps public write bookkeeping in a
  fixed-size boxed flag array rather than a growable `BTreeSet` of written
  indices, and the source-backed interface rejects the old written-index set;
  the
  hidden traced-call ORAM
  witness snapshots in
  `state.rs` now also wipe on drop unless the theorem finalizer explicitly
  consumes them; the theorem-facing certificate constructors plus final
  `ExecutionTrace` assembly are now also confined to
  `runtime/uo-evm/src/theorem.rs`, while production theorem-trace assembly now
  also routes through the shared `uo-core`
  `TheoremTrace::from_public_observer_parts(...)` constructor rather than a
  runtime-local struct literal; the public-trace
  helper surface is now also pinned, with `PublicCallSummary`/`CallRecorder`
  creation staying in `state.rs`, `output_shape_of(...)` staying in
  `controller.rs`, and the theorem bridge routing public call-trace assembly
  through `finalize_public_call_trace(...)` instead of computing output shape
  or calling `CallRecorder::finish(...)` directly; the controller/theorem path
  now also derives output length from manifest-stored `return_canonical_len`
  and consumes only the public `OutputShape` summary rather than the full
  return payload
- kernel object-operation scratch reservations and UO object commit `io`
  scratch reservations now derive from admitted object/type metadata instead
  of live confidential value lengths wherever the runtime already knows the
  canonical shape statically, which removes another residual secret-to-budget
  dependency from cell/array/map mutation and commit paths
- confidential `keccak256` hash-scratch reservations now also use the checked
  manifest's explicit `max_hash_part_bytes` field, which `uo-solc`,
  `uo-check`, and the Lean translation validator all derive from the stored
  confidential DSL plus admitted object metadata, instead of sizing the hash
  scratch region from each live hashed value as the kernel evaluates the
  expression
- ORAM refresh/metadata decode now wipes decrypted payload buffers after parse
  rather than dropping them as ordinary plaintext heap allocations, and it now
  streams decoded position-map / stash pages directly into bounded live ORAM
  state while rejecting decoded stash contents that exceed the manifest public
  `stash_bound`
- confidential transaction-shadow creation and rollback / no-op recovery now
  rebuild all UO object classes from sealed storage instead of cloning old
  live logical caches, so cells, arrays, full-scan maps, path ORAM, and
  surrogate ORAM all tie those recovery paths back to the sealed-state
  boundary
- path-ORAM access no longer preclones the full committed
  `entries`/`position_map`/`stash` logical state before each rewrite; it now
  moves those working vectors into the access routine and rebuilds them there
- path-ORAM stash delete / eviction paths now treat the stash as an unordered
  multiset and avoid shift-heavy order-preserving removals, with a regression
  test that checks witness-visible delete behavior stays invariant under stash
  permutation
- path-ORAM refresh/decode now rejects more malformed hidden states up front:
  out-of-range position-map or stash leaves, out-of-range stash slots,
  duplicate live blocks, leaf/position-map disagreement, bucket-header index
  mismatch, bucket live-count underreporting, and bucket-resident blocks that
  do not lie on their declared leaf path

That strengthens the runtime discipline, but it does not by itself prove the
runtime against the full SGX observer. The remaining below-interface target is
the native semantics-of-Rust refinement theorem for the residual real kernel
support, after the current source-pinned/model-backed cuts for the machine,
allocator, statement trace, ORAM write log, small-map lookup, array access,
the exact ORAM commit restore-vs-write-batch split, and the now explicitly
public-only handwritten shell in `runtime/uo-evm/src/{objects,oram}.rs`,
`runtime/uo-store/src/codec.rs`, and the thin `runtime/uo-store/src/store.rs`
call-site shell. The exact secret-bearing object/ORAM
open/bootstrap/reseal shell is no longer handwritten: object
reopen/bootstrap/commit flows now route through the exact-source-checked
generated helper module's `with_opened_object_payload`,
`seal_boxed_object_payload`, and `reseal_payload_and_trace_write`, and the
typed value/map open/bootstrap/commit wrappers that used to live in
`objects.rs` now live in that same generated helper module as well; the exact-
size map-record, directory-page, and scalar metadata codec that used to live
in `oram.rs` now does too. ORAM
reopen/bootstrap/commit flows now route through the same generated module's
`with_opened_oram_payload`, `seal_boxed_oram_payload`,
`filler_boxed_oram_payload`, and `reseal_oram_payload_and_record_write`,
whose write evidence is now public update-shape only, and the lower-level
deeper ORAM block/bucket/stash-page plus Path-ORAM metadata-page
encode/rewrite/open, bucket-payload validation, public ORAM geometry/addressing
helpers, and masked Path-ORAM selector / fixed-capacity stash-rebuild helpers
now route through the
Lean-generated `runtime/uo-evm/src/generated_oram_codecs.rs` module. That
generated module now also owns the narrow metadata-copy surface: Path-ORAM
`MaskedUsizeOption` is non-`Clone`/non-`Copy`, position-map metadata
clone/assign/select/repeat operations use explicit generated borrowed helpers,
and empty metadata-page initialization uses the typed
`repeat_boxed_empty_byte_boxes` builder instead of a generic
`repeat_boxed<T: Clone>` helper. The implementation-interface and probe checks
pin those restrictions and reject the older generic repeat and by-value
metadata select shapes. The generated small-map and ORAM map read/write
helpers now also return confidential overflow/update-failed bits for
deterministic capacity/update failures, and the Lean-generated
confidential-kernel interpreter folds those bits into masked abort state; this
removes the older secret-conditioned host-visible `bail!` path for full small
maps, missing selected ORAM blocks, Path-ORAM stash insert/working-stash
failure, and surrogate insert-capacity failure. The same source-backed
boundary now pins a residual host-visible error taxonomy for generated
object/ORAM/store helpers: public shape/capacity, authenticated
decode/integrity, cold-restore, fresh-coin tape, and write-log discipline
failures may still return `Result` errors, while deterministic hidden-state
map/ORAM capacity or update misses must remain in-band abort effects. Lean now
also states the generated ORAM codec byte layout directly, including ORAM block
encode/decode roundtrip, exact-length ORAM block decode/roundtrip facts, ORAM
decoded-block valid-shape facts, aggregate decoded bucket/stash block
valid-shape facts, ORAM bucket encoded length, exact-bucket decode acceptance
tying byte length, expected bucket index, exact block decoding, and live-count
agreement together, bounded Path bucket decode for occupied block slot/leaf
bounds, public bucket-on-leaf-path membership, and decoded position-map
agreement plus duplicate live-slot rejection and position-map live-slot
coverage, generic whole-block-list position-map agreement/no-duplicate hooks,
Path-ORAM position-map page coverage, exact position-map
page decode acceptance under the public leaf bound, public metadata page split,
aggregate position-map-pages decode acceptance for a capacity-sized map,
exact stash-page decode acceptance, aggregate stash-pages decode shape/block
validity, bounded aggregate stash decode for public stash/slot/leaf bounds,
stash position-map agreement, stash duplicate live-slot rejection,
and Path-ORAM
position-map/stash page padding lengths, so these are theorem-facing layout
facts rather than only generated-source facts. The lower-level
store write path now routes through the Lean-generated
`runtime/uo-store/src/generated_surface.rs` exact-size seal/open/filler surface plus the Lean-generated
`runtime/uo-store/src/generated_store_helpers.rs`
`filler_boxed_uo_store_slot` and
`reseal_uo_store_slot_in_place` layer. The source-backed
`RuntimeImplementationInterface` now also names that residual surface as its
own `ResidualHelperShellBoundary`, benchmark-backed through
`runtime_residual_helper_shell_boundary_validation.json`. Lean now also
packages the direct meeting between that source cut and the emitted native
machine witness as
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary`,
benchmark-backed through
`runtime_implementation_residual_helper_shell_machine_refinement_boundary_validation.json`;
that route now also states the native machine-finish facts explicitly at the
residual helper-shell cut itself: expected-kernel schedule consumption,
kernel-op budget respect, runtime-phase-event budget respect, and exact slot
program/kernel-step agreement,
and the standalone small/shared-confidential-kernel boundaries, the
kernel-model alignment report, and the tamper suite all pin those shared
helper routes explicitly, with the generated object/store helper artifacts
living as exact obligations of `ResidualHelperShellBoundary` and the generated
kernel/machine/slot-support artifacts living as exact obligations of
`SmallConfidentialKernelBoundary`.
The direct machine-confinement report now also exposes the derived codec-layout
bits for that same residual surface: nonzero transport shape, sealed-record
length, sealed-record decode split shape, sealed-record open magic-header
shape, sealed-record open-transport soundness for the split components,
sealed-record transport roundtrip, successful nonzero decode soundness,
ORAM block encode/decode roundtrip,
exact-length ORAM block decode/roundtrip facts, ORAM bucket encoded
length, decoded-block and aggregate bucket/stash block valid-shape facts,
exact-bucket decode acceptance, exact position-map/stash page decode
acceptance, bounded Path bucket decode for occupied block slot/leaf bounds,
public bucket-on-leaf-path membership, decoded position-map agreement,
duplicate live-slot rejection, position-map live-slot coverage, public metadata page split,
aggregate position-map-pages decode
acceptance, aggregate stash-pages decode shape/block validity, bounded
aggregate stash decode for public stash/slot/leaf bounds, stash position-map
agreement, stash duplicate live-slot rejection, and Path-ORAM
position-map/stash page lengths are all marked as checked theorem hooks rather
than left as implicit Rust-side codec claims.
The corresponding WP6 hostile-host closure is documented in
`docs/tee-runtime-hardening.md`; it is no longer an active step list.

## Practical Readout

The implementation roadmap is no longer blocked on missing runtime/controller
plumbing, missing witness extraction, theorem-interface alignment, backend
assumption provenance, or hostile-host observer closure. The remaining caution
is claim discipline: do not extend the theorem below the checked runtime
boundary or beyond the cited backend/deployment assumptions without adding a new
proof route.
