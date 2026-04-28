# TEE Runtime Hardening Track

This note revives the runtime-hardening parts of the archived runbook, but
rewrites them against the current repository rather than the bootstrap-era
"build everything from scratch" plan.

The goal of this track is stronger than the repository's current bridge claim:

- not only that emitted certificates / bundles / witnesses satisfy the Lean
  predicates
- but also that `uo-evm` itself is pushed toward the same hostile-host TEE
  adversary model instead of being treated as an opaque enclave interior

## Why This Track Exists

The current repository already has:

- an explicit runtime controller observer and theorem trace
- runtime-enforced controller / hidden / trusted-kernel / refinement-witness
  extraction
- Lean validation for those emitted artifacts
- an explicit paper-route runtime/kernel boundary,
  `PaperMainRuntimeKernelBoundary`, plus the stronger shared-slot boundary
  `PaperMainRuntimeKernelSlotBoundary`, so the remaining trusted runtime gap is
  at least named precisely in Lean; the stronger proof-grade witness-
  acceptance wrappers remain available below that route to discharge those
  boundaries mechanically

What it still does not claim is:

- that every line of the Rust runtime is formally verified
- that the entire enclave implementation already satisfies a malicious-host SGX
  execution-oblivious theorem

That gap matters if the deployment story is "run `uo-evm` inside a TEE and
claim the runtime itself is aligned with the admitted observer."

## Frozen Observer For This Track

This hardening track now works against one fixed observer rather than an
informal "TEE leakage" story:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

with:

- exact `public_outcome`
- exact `boundary_schedule`
- backend-handled `storage_trace`
- SGX-specific `micro_trace` normalized and simulated from `L_sgx_micro`

This means the runtime-hardening task is not "emit some witness that looks
reasonable." It is:

1. reduce the real secret-dependent runtime to a tiny confidential kernel
2. prove the real kernel implementation refines the Lean kernel model
3. prove the rest of the runtime is public-only with respect to this observer
4. then close the hostile-host deployment theorem at exactly this observer

## W6.1 Frozen SGX Observer Surface

The W6 hostile-host theorem rests on the observer signature shared
across three artifacts:

- the Lean models in `proof/lean/UOToolchain/SgxBoundary.lean`,
  `SgxRelation.lean`, `SgxController.lean`, `SgxControllerTrace.lean`,
  and `SgxMicroModel.lean`;
- the Rust runtime controller recorder in
  `runtime/uo-evm/src/controller.rs`;
- the Rust public-trace projection in `crates/uo-core/src/trace.rs`.

W6.1 freezes the public observer signature explicitly so the W6.2
(boundary-call modeling) / W6.3 (controller refinement) / W6.4
(sealing-storage refinement) refinements have a stable target. The
Lean side carries a dedicated module
[`SgxObserverFreeze.lean`](../proof/lean/UOToolchain/SgxObserverFreeze.lean)
that pins each observer-surface component as an explicit constant
plus a structural theorem; the Rust side is pinned by the probe's
`sgx_observer_surface_pinned` static-drift check.

Claim taxonomy (per
[`docs/coding-agent-conventions.md`](./coding-agent-conventions.md#claim-and-tcb-discipline)):
**Lean-proved, semantics-preserving** for the W6.1 component freezes
themselves. The Lean equalities are exact and rejected by the build
if they ever drift; the static-drift check rejects representative
runtime drift. The freeze does not by itself discharge any
deployment assumption — it locks the observer signature so the
W6.2 / W6.3 / W6.4 / W6.5 / W6.6 closure layers compose against one
fixed surface.

### Frozen components

| Component | Canonical value | Lean anchor | Rust anchor |
| --- | --- | --- | --- |
| Page-region vocabulary | `["metadata", "position_map", "path", "stash"]` | `sgxObserverPageRegionNames` (`SgxObserverFreeze.lean`); paired with `controllerPageTraceRegionsOfLeakage_pageKinds` and `controllerWorksetRegionsOfLeakage_pageKinds` over the controller projections in `SgxController.lean` | `METADATA_REGION` / `POSITION_MAP_REGION` / `PATH_REGION` / `STASH_REGION` constants + `CONTROLLER_REGIONS` array in `runtime/uo-evm/src/controller.rs`; the controller's `bump_region` / `bump_workset` paths route through these names exclusively |
| Controller-phase vocabulary | 10 phases (enclaveEnter → stageRequest → descendPositionMap → loadMetadata → fetchPath → scanStash → rewritePath → ascendPositionMap → sealPersistentState → enclaveExit) | `SGXControllerPhase` inductive in `SgxRelation.lean`; canonical list `sgxObserverControllerPhases` and name list `sgxObserverControllerPhaseNames` in `SgxObserverFreeze.lean` | `ControllerPhase` enum in `crates/uo-core/src/trace.rs` (`EnclaveEnter` … `EnclaveExit`); used by `runtime/uo-evm/src/controller.rs` to record the public phase order |
| Page-event-kind vocabulary | `[faultIn, evictOut]` | `PageEventKind` inductive in `SgxBoundary.lean`; canonical list `sgxObserverPageEventKinds` and name list `sgxObserverPageEventKindNames` in `SgxObserverFreeze.lean` | `PageEventKind` enum in `crates/uo-core/src/trace.rs` (`FaultIn`, `EvictOut`); used by the public `normalized_micro_trace()` projection |
| Exit-event-kind vocabulary | `[interruptExit, resume, terminate]` | `ExitEvent` inductive in `SgxBoundary.lean`; canonical list `sgxObserverExitEvents` and name list `sgxObserverExitEventNames` in `SgxObserverFreeze.lean` | `ExitEvent` enum in `crates/uo-core/src/trace.rs` (`InterruptExit`, `Resume`, `Terminate`); used by the public `normalized_micro_trace()` exit pattern |
| Shared-resource pattern literal | `"shared_resource_tick"` | `sgxObserverSharedResourceTick` in `SgxObserverFreeze.lean`; paired with `controllerSharedResourcePatternOfShape_value` over the Lean controller projection in `SgxControllerTrace.lean` | The `vec!["shared_resource_tick".into(); self.shared_resource_budget]` literal in `SgxControllerShapeTrace::normalized_micro_trace` (`crates/uo-core/src/trace.rs`) |
| Page-event encoding formula | `pageId = index / 2`, `kind = if index % 2 = 0 then faultIn else evictOut` | `controllerPageEventOfIndex` in `SgxControllerTrace.lean`; paired with `controllerPageEventOfIndex_pageId`, `controllerPageEventOfIndex_kind_even`, `controllerPageEventOfIndex_kind_odd` in `SgxObserverFreeze.lean` | The `index / 2` / parity `if` block inside `SgxControllerShapeTrace::normalized_micro_trace` (`crates/uo-core/src/trace.rs`) |

### Provenance pairing

The W6.1 provenance record is `sgxObserverSurfaceProvenance` in
`SgxObserverFreeze.lean`. It carries:

- the four canonical name lists and the shared-resource tick literal;
- the documentation anchor (this section);
- the probe static-drift check name (`sgx_observer_surface_pinned`);
- the Lean and Rust file paths anchoring each pinned component.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_observer_*` prefix mirror the W5.4 / W5.3
provenance facade pattern: each facade is a one-line forwarder that
gives the paper a Lean theorem object referencing the canonical
constant or projection equality.

### Static-drift coverage

The probe's `sgx_observer_surface_pinned` flag, emitted by the
`kernel_model_alignment_validation.json` report, rejects
representative drift on the Rust side. Specifically it requires:

- `runtime/uo-evm/src/controller.rs` keeps the
  `METADATA_REGION = "metadata"`, `POSITION_MAP_REGION = "position_map"`,
  `PATH_REGION = "path"`, and `STASH_REGION = "stash"` constants.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `ControllerPhase`, `PageEventKind`, and `ExitEvent` enum variants
  in their declared order.
- `crates/uo-core/src/trace.rs` keeps the
  `vec!["shared_resource_tick".into(); self.shared_resource_budget]`
  literal inside `SgxControllerShapeTrace::normalized_micro_trace`.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `index / 2` / `index % 2 == 0` page-event alternation rule and the
  `if index + 1 == self.exit_trace_budget` / `index % 2 == 0`
  exit-pattern rule.

If any of those drift, the static-checks gate flips
`sgx_observer_surface_pinned` to `false` and the gate rejects the
checkpoint.

## W6.2 Frozen Boundary-Call Model

W6.2 closes the boundary-call surface: the canonical inner API
literal, the canonical boundary directions, the canonical
boundary-event budget formula, and the canonical boundary-schedule
shape that the runtime emits.

The Lean side extends `proof/lean/UOToolchain/SgxObserverFreeze.lean`
with the `sgxBoundaryCallProvenance` record. The runtime side is
pinned by the probe's `sgx_boundary_call_model_pinned` static-drift
check.

Claim taxonomy: **Lean-proved, semantics-preserving** for the W6.2
boundary-call model. The Lean equalities pin the canonical
boundary-call shape; the static-drift check rejects representative
runtime drift. The freeze does not by itself discharge any
deployment assumption.

### Frozen boundary-call components

| Component | Canonical value | Lean anchor | Rust anchor |
| --- | --- | --- | --- |
| Inner ORAM-access API literal | `"oram_access"` | `sgxObserverOramAccessApi`; paired with `sgxBoundaryCallProvenance` | `BoundaryEvent::enter("oram_access", 0)` / `BoundaryEvent::exit("oram_access", 0)` calls inside `runtime/uo-evm/src/controller.rs`; `api_id: "oram_access".into()` literal inside `RuntimeControllerCertificate::boundary_schedule` (`crates/uo-core/src/trace.rs`) |
| Boundary direction vocabulary | `[enter, exit]` | `BoundaryDirection` inductive in `SgxBoundary.lean`; canonical list `sgxObserverBoundaryDirections` and name list `sgxObserverBoundaryDirectionNames` in `SgxObserverFreeze.lean` | `BoundaryDirection` enum in `crates/uo-core/src/trace.rs` (`Enter`, `Exit`); used by the `BoundaryEvent::{enter,exit}` constructors |
| Boundary-event budget formula | `2 * total_oram_accesses + 2` | `sgxObserverBoundaryEventBudget` in `SgxObserverFreeze.lean`; paired with `sgxObserverBoundaryEventBudget_eq_controllerShape` over the Lean controller-shape constructor | `2 * self.observed_oram_accesses.len() + 2` capacity in `RuntimeControllerCertificate::boundary_schedule`; `boundary_event_budget: 2 * total_oram_accesses + 2` field in `RuntimeControllerCertificate::controller_shape` |
| Boundary-schedule structural shape | `Enter(<entry>, entry_input_len, 0); for each oram access: Exit("oram_access", 0, 0); Enter("oram_access", 0, 0); Exit(<entry>, 0, return_length)` | `sgxObserverBoundarySchedule` in `SgxObserverFreeze.lean`; paired with `sgxObserverBoundarySchedule_length`, `sgxObserverBoundarySchedule_head`, and `sgxObserverBoundarySchedule_getLast` | `RuntimeControllerCertificate::boundary_schedule` builder in `crates/uo-core/src/trace.rs`; `record_oram_access` site in `runtime/uo-evm/src/controller.rs` |

### Provenance pairing

The W6.2 provenance record is `sgxBoundaryCallProvenance` in
`SgxObserverFreeze.lean`. It carries the canonical inner API
literal, the boundary-direction names, free-form descriptions of
the canonical budget formula and schedule shape, the documentation
anchor (this section), the probe static-drift check name, and the
Lean / Rust file paths anchoring each pinned component.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_boundary_*` prefix mirror the W6.1 pattern: each
facade is a one-line forwarder that gives the paper a Lean theorem
object referencing the canonical constant or projection equality.

### Static-drift coverage

The probe's `sgx_boundary_call_model_pinned` flag, emitted by the
`kernel_model_alignment_validation.json` report, rejects
representative drift on the Rust side. Specifically it requires:

- `runtime/uo-evm/src/controller.rs` keeps the
  `BoundaryEvent::enter(entrypoint, total_input_len)` outer-enter
  call, the `BoundaryEvent::exit("oram_access", 0)` /
  `BoundaryEvent::enter("oram_access", 0)` inner pair, and the
  outer exit call.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `BoundaryDirection` enum (`Enter`, `Exit`), the canonical
  `BoundaryEvent` field schema (`direction`, `api_id`,
  `input_len`, `output_len`), and the canonical
  `BoundaryEvent::{enter, exit}` constructor signatures.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `Vec::with_capacity(2 * self.observed_oram_accesses.len() + 2)`
  schedule pre-allocation, the `api_id: "oram_access".into()`
  literal, and the `boundary_event_budget: 2 * total_oram_accesses
  + 2` field formula.

If any of those drift, the static-checks gate flips
`sgx_boundary_call_model_pinned` to `false` and the gate rejects
the checkpoint.

## W6.2 Frozen Persistent-I/O Model

W6.2 also closes the persistent-I/O surface: the canonical
`PhysicalRead` / `PhysicalWrite` field schemas and the canonical
`WriteClass` vocabulary that the runtime emits.

The Lean side extends `proof/lean/UOToolchain/SgxObserverFreeze.lean`
with the `sgxPersistentIoProvenance` record. The runtime side is
pinned by the probe's `sgx_persistent_io_model_pinned` static-drift
check.

Claim taxonomy: **Lean-proved, semantics-preserving** for the W6.2
persistent-I/O model. The Lean canonical lists pin the field
schemas and the four-element write-class vocabulary; the
static-drift check rejects representative runtime drift. The
freeze does not by itself discharge any deployment assumption.

### Frozen persistent-I/O components

| Component | Canonical value | Lean anchor | Rust anchor |
| --- | --- | --- | --- |
| `PhysicalRead` field schema | `["object", "location", "len"]` | `PhysicalRead` structure in `TraceModel.lean`; `sgxObserverPhysicalReadFieldNames` in `SgxObserverFreeze.lean` | `PhysicalReadEvent { object, location, len }` struct in `crates/uo-core/src/trace.rs` |
| `PhysicalWrite` field schema | `["object", "location", "writeClass", "len"]` (Lean) / `["object", "location", "len", "class"]` (Rust) | `PhysicalWrite` structure in `TraceModel.lean`; `sgxObserverPhysicalWriteFieldNames` in `SgxObserverFreeze.lean` | `PhysicalWriteEvent { object, location, len, class }` struct in `crates/uo-core/src/trace.rs`; `class : WriteClass` carries the classification |
| `WriteClass` vocabulary | `[Set, Clear, Same, Update]` | `sgxObserverWriteClassNames` in `SgxObserverFreeze.lean` | `WriteClass` enum in `crates/uo-core/src/trace.rs` (`Set`, `Clear`, `Same`, `Update`); the `as_refinement_label` projection emits the canonical labels |

### Provenance pairing

The W6.2 persistent-I/O provenance record is
`sgxPersistentIoProvenance` in `SgxObserverFreeze.lean`. It carries
the canonical field-name lists and the four-element write-class
vocabulary, the documentation anchor (this section), the probe
static-drift check name, and the Lean / Rust file paths anchoring
each pinned component.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_persistent_io_*` prefix mirror the W6.1 / W6.2
boundary-call pattern.

### Static-drift coverage

The probe's `sgx_persistent_io_model_pinned` flag, emitted by the
`kernel_model_alignment_validation.json` report, rejects
representative drift on the Rust side. Specifically it requires:

- `crates/uo-core/src/trace.rs` keeps the canonical
  `WriteClass` enum with exactly the `Set`, `Clear`, `Same`,
  `Update` variants in declared order.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `as_refinement_label` projection that emits `"Set"`, `"Clear"`,
  `"Same"`, `"Update"` strings.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `PhysicalReadEvent` and `PhysicalWriteEvent` struct field
  schemas, including the `class : WriteClass` field on the write
  event.

If any of those drift, the static-checks gate flips
`sgx_persistent_io_model_pinned` to `false` and the gate rejects
the checkpoint.

## W6.3 Controller-Refinement Integration

W6.3 packages the W6.1 / W6.2 freezes as a single Lean integration
theorem: every leakage list induces a canonical Lean controller
shape that refines the W6.1 / W6.2 frozen observer surface in four
structural senses.

The Lean side extends `proof/lean/UOToolchain/SgxObserverFreeze.lean`
with the `SgxControllerObserverRefinement` integration record, the
`sgxControllerObserverRefinementOf` constructor, and the
`sgxControllerObserverRefinement_exists` packaging theorem. The
runtime side is pinned by the probe's
`sgx_controller_refinement_pinned` static-drift check.

Claim taxonomy: **Lean-proved, semantics-preserving** for the W6.3
controller-refinement integration. The Lean integration is a
one-line forwarder over the existing W6.1 / W6.2 structural
equalities (`controllerPageTraceRegionsOfLeakage_pageKinds`,
`controllerWorksetRegionsOfLeakage_pageKinds`,
`sgxObserverBoundaryEventBudget_eq_controllerShape`,
`controllerSharedResourcePatternOfShape_value`); the static-drift
check rejects representative runtime drift in the Rust controller
emission path. The integration does not by itself discharge any
deployment assumption; it composes the W6.1 / W6.2 component
freezes into one named refinement statement.

### Frozen controller-refinement components

| Component | Refinement claim | Lean anchor | Rust anchor |
| --- | --- | --- | --- |
| Page-region names | `(controllerPageTraceRegionsOfLeakage leakage).map pageKind = sgxObserverPageRegionNames` | `SgxControllerObserverRefinement.pageRegionNamesMatch`; constructor uses `controllerPageTraceRegionsOfLeakage_pageKinds` | `RuntimeControllerCertificate::controller_shape` page-region builder in `crates/uo-core/src/trace.rs`, building each region with `page_kind: METADATA_REGION.into()` etc. |
| Workset-region names | `(controllerWorksetRegionsOfLeakage leakage).map pageKind = sgxObserverPageRegionNames` | `SgxControllerObserverRefinement.worksetRegionNamesMatch`; constructor uses `controllerWorksetRegionsOfLeakage_pageKinds` | `RuntimeControllerCertificate::controller_shape` workset-region builder in `crates/uo-core/src/trace.rs` |
| Boundary-event budget | `sgxObserverBoundaryEventBudget (totalOramAccesses leakage) = (sgxControllerShapeOfExecutionLeakage leakage).boundaryEventBudget` | `SgxControllerObserverRefinement.boundaryEventBudgetMatch`; constructor uses `sgxObserverBoundaryEventBudget_eq_controllerShape` | `boundary_event_budget: 2 * total_oram_accesses + 2,` field in the Rust `controller_shape()` constructor |
| Shared-resource pattern | `controllerSharedResourcePatternOfShape shape = List.replicate shape.sharedResourceBudget sgxObserverSharedResourceTick` | `SgxControllerObserverRefinement.sharedResourcePatternMatch`; constructor uses `controllerSharedResourcePatternOfShape_value` | `vec!["shared_resource_tick".into(); self.shared_resource_budget].into_boxed_slice();` line in `SgxControllerShapeTrace::normalized_micro_trace` |

### Provenance pairing

The W6.3 controller-refinement provenance record is
`sgxControllerRefinementProvenance` in `SgxObserverFreeze.lean`. It
carries the free-form refinement claim, the documentation anchor
(this section), the probe static-drift check name, and the Lean /
Rust file paths anchoring the controller-shape constructor.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_controller_observer_refinement_*` and
`proofGrade_sgx_controller_refinement_provenance_*` prefixes mirror
the W6.1 / W6.2 facade pattern.

### Static-drift coverage

The probe's `sgx_controller_refinement_pinned` flag, emitted by the
`kernel_model_alignment_validation.json` report, rejects
representative drift on the Rust side. Specifically it requires:

- `crates/uo-core/src/trace.rs` keeps the canonical
  `controller_phase_order = vec![ControllerPhase::EnclaveEnter]` /
  `ControllerPhase::StageRequest` / `DescendPositionMap` /
  `LoadMetadata` / `FetchPath` / `ScanStash` / `RewritePath` /
  `AscendPositionMap` / `SealPersistentState` / `EnclaveExit`
  emission path inside `RuntimeControllerCertificate::controller_shape`.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `page_kind: METADATA_REGION.into()` /
  `page_kind: POSITION_MAP_REGION.into()` / `PATH_REGION` /
  `STASH_REGION` page-region builder pattern with the canonical
  `metadata_budget` / `position_map_budget` / `metadata_workset` /
  `position_map_workset` derived counters.

If any of those drift, the static-checks gate flips
`sgx_controller_refinement_pinned` to `false` and the gate rejects
the checkpoint.

## W6.4 Sealing / Storage Refinement Integration

W6.4 packages the canonical sealing / storage projection rules as a
single Lean integration theorem. The Lean `TEEView` projection
`viewTEEStore` deterministically pulls every storage-relevant field
from the underlying `Config` and `DeploymentResult`, with the
`physicalReads` / `physicalWrites` lists forwarded unchanged at the
W6.2-frozen `PhysicalRead` / `PhysicalWrite` schema.

The Lean side extends `proof/lean/UOToolchain/SgxObserverFreeze.lean`
with the `SgxStorageRefinement` integration record, the
`sgxStorageRefinementOf` constructor, and the
`sgxStorageRefinement_exists` packaging theorem. The runtime side
is pinned by the probe's `sgx_storage_refinement_pinned`
static-drift check.

Claim taxonomy: **Lean-proved, semantics-preserving** for the W6.4
storage-refinement integration. Each component refinement is a
direct one-line `rfl` over `viewTEEStore`'s definitional
record-literal structure; the static-drift check rejects
representative drift in the Rust `RefinementTrace` /
`RuntimeRefinementWitness` shape. The integration does not by
itself discharge any deployment assumption.

### Frozen storage-refinement components

| Component | Refinement claim | Lean anchor | Rust anchor |
| --- | --- | --- | --- |
| Physical-read forwarding | `(viewTEEStore cfg result).physicalReads = result.trace.physicalReads` | `SgxStorageRefinement.physicalReadsMatch`; constructor uses `rfl` over `viewTEEStore`'s definitional structure | `RefinementTrace.physical_reads: Box<[PhysicalReadEvent]>` field in `crates/uo-core/src/trace.rs` |
| Physical-write forwarding | `(viewTEEStore cfg result).physicalWrites = result.trace.physicalWrites` | `SgxStorageRefinement.physicalWritesMatch` | `RefinementTrace.physical_writes: Box<[RefinementPhysicalWrite]>` field in `crates/uo-core/src/trace.rs` |
| Gas-used forwarding | `(viewTEEStore cfg result).gasUsed = result.trace.gasUsed` | `SgxStorageRefinement.gasUsedMatch` | `RefinementTrace.gas_used: u64` field in `crates/uo-core/src/trace.rs` |
| Entrypoint-id forwarding | `(viewTEEStore cfg result).entrypointId = cfg.program.entrypoint` | `SgxStorageRefinement.entrypointIdMatch` | `RuntimeRefinementWitness` carries the wrapped `RefinementTrace` plus the public outcome that names the entrypoint |

### Provenance pairing

The W6.4 storage-refinement provenance record is
`sgxStorageRefinementProvenance` in `SgxObserverFreeze.lean`. It
carries the free-form refinement claim, the documentation anchor
(this section), the probe static-drift check name, and the Lean /
Rust file paths anchoring each pinned component.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_storage_refinement_*` prefix mirror the W6.1 /
W6.2 / W6.3 facade pattern.

### Static-drift coverage

The probe's `sgx_storage_refinement_pinned` flag, emitted by the
`kernel_model_alignment_validation.json` report, rejects
representative drift on the Rust side. Specifically it requires:

- `crates/uo-core/src/trace.rs` keeps the canonical
  `RefinementTrace` field schema with
  `physical_reads: Box<[PhysicalReadEvent]>` and
  `physical_writes: Box<[RefinementPhysicalWrite]>`.
- `crates/uo-core/src/trace.rs` keeps the canonical
  `RefinementPhysicalWrite { object, location, write_class, len }`
  field schema (the AAD-shape projection used by the public-trace
  bridge).
- `crates/uo-core/src/trace.rs` keeps the canonical
  `RuntimeRefinementWitness { trace: RefinementTrace, ... }`
  wrapping pattern.

If any of those drift, the static-checks gate flips
`sgx_storage_refinement_pinned` to `false` and the gate rejects
the checkpoint.

## W6.5 Hostile-Host TEE Deployment-Assumption Bundle

W6.5 states the irreducible TEE deployment assumptions explicitly,
in one named bundle paired with explicit Intel SGX provenance
citations. These assumptions are **part of the deployment TCB**: the
hostile-host SGX execution-oblivious theorem holds against a TEE
platform that honors them. The bundle stays explicit at the Lean
type level — never silently absorbed into prose — and each field is
paired with a structured provenance record that names the
specification and BibTeX key.

The bundle covers every load-bearing TEE deployment assumption
called out by the WP6 charter task 5 (attestation, rollback, crash,
freshness, patch-level) plus the underlying enclave memory
isolation assumption that every TEE security claim depends on, in
six explicit fields:

The Lean side extends `proof/lean/UOToolchain/SgxObserverFreeze.lean`
with the `SgxDeploymentAssumptions` structure and six canonical
provenance records. The runtime side is pinned by the probe's
`sgx_deployment_assumption_bundle_pinned` static-drift check, which
reads the Lean source itself and rejects regressions that delete the
bundle, drop one of its fields, or remove a citation BibTeX key.

Claim taxonomy (per
[`docs/coding-agent-conventions.md`](./coding-agent-conventions.md#claim-and-tcb-discipline)):
**Cited / externally justified** for every assumption field. The
bundle does not Lean-discharge any of the six assumptions; they
are honored by the TEE platform under deployment.

### Frozen deployment-assumption components

| Field | Role | Provenance citation | BibTeX key |
| --- | --- | --- | --- |
| `attestationAuthenticity` | platform attestation produces a quote whose authenticity is established by the Intel Provisioning Service / DCAP attestation chain | Intel SGX Attestation Services Programming Reference (Intel Corporation, Reference Number 332680-008US) plus the DCAP Quote Generation Library Programming Reference | `IntelSGXAttestationReference` |
| `enclaveMemoryIsolation` | enclave memory pages are protected by the Memory Encryption Engine (MEE) for confidentiality and integrity against a hostile host | Intel 64 and IA-32 Architectures Software Developer's Manual, Volume 3D: Intel SGX (chapter on EPC Memory Encryption Engine), and Intel SGX Developer Reference, Memory Protection model section | `IntelSGXSDM3D` |
| `rollbackResistance` | sealed state cannot be silently rolled back to a prior epoch; replay protection comes from monotonic counters tied to the platform's TCB | Intel SGX SDK Developer Reference: `sgx_create_monotonic_counter` / `sgx_increment_monotonic_counter` / `sgx_read_monotonic_counter` interfaces (rollback-protection chapter) | `IntelSGXSDKDeveloperReference` |
| `freshnessGuarantee` | read from sealed state returns the most recent committed value; freshness is enforced by `sgx_get_trusted_time` and the trusted-clock substrate | Intel SGX SDK Developer Reference: `sgx_get_trusted_time` / `sgx_create_pse_session` interfaces (Trusted Time and freshness-enforcement chapter) | `IntelSGXSDKDeveloperReference` |
| `crashRecoveryDiscipline` | crash recovery from sealed state does not leak partial confidential state; the runtime's commit / wipe boundary is honored across enclave power transitions | Intel SGX SDK Developer Reference: Power transitions, sealing & unsealing chapter (`sgx_seal_data` / `sgx_unseal_data` discipline) | `IntelSGXSDKDeveloperReference` |
| `patchLevelTrust` | the deployed platform's security patch / microcode level supports the SGX security claims (no known unmitigated TEE vulnerabilities below the deployment patch level) | Intel Security Center: Intel SGX Platform Software (Intel SGX PSW), Trusted Computing Base (TCB) recovery, and Intel CPU microcode update advisories at https://www.intel.com/content/www/us/en/security-center/ | `IntelSGXSecurityCenter` |

### Provenance pairing

The W6.5 deployment-assumption provenance list is
`sgxDeploymentAssumptionProvenances` in `SgxObserverFreeze.lean`. It
contains six entries — one per bundle field — each with an Intel
SGX citation and BibTeX key. The Lean theorem
`sgxDeploymentAssumptionProvenances_allCited` proves every entry is
classified `"Cited / externally justified"`; the theorem
`sgxDeploymentAssumptionProvenances_sharedDriftCheck` proves every
entry references the same probe drift check name, so a single named
hook keeps the entire bundle pinned in lockstep.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_deployment_*` prefix mirror the W5.4 / W5.3
provenance facade pattern.

`proof/lean/UOToolchain/RuntimeAuditSurfaces.lean` now adds the
deployment mechanism layer requested by the review. The
`sgxDeploymentAssumptionMechanismMatrix` maps all six bundle fields
to a concrete mechanism and classifies each one as implementation
evidence, external/deployment-only, or removed from the implemented
claim. The companion `sgxDeploymentFirstMilestoneChecklist` names the
first deployment artifacts: enclave boundary, attestation transcript,
sealed storage, sealed-state freshness evidence, rollback counter, and
encrypted return channel. The encrypted return-channel entry is
classified as removed from the implemented claim because the current
runtime rejects `encrypted_to_client` returns until channel crypto is
implemented.

### Static-drift coverage

The probe's `sgx_deployment_assumption_bundle_pinned` flag, emitted
by the `kernel_model_alignment_validation.json` report, rejects
regressions in the Lean-side deployment-assumption surface itself.
Specifically it requires:

- `proof/lean/UOToolchain/SgxObserverFreeze.lean` keeps the
  `SgxDeploymentAssumptions` structure declaration plus its six
  `Prop` fields (`attestationAuthenticity`,
  `enclaveMemoryIsolation`, `rollbackResistance`,
  `freshnessGuarantee`, `crashRecoveryDiscipline`,
  `patchLevelTrust`).
- `proof/lean/UOToolchain/SgxObserverFreeze.lean` keeps the six
  `def sgxDeploymentProvenance_*` provenance constants.
- `proof/lean/UOToolchain/SgxObserverFreeze.lean` keeps the four
  canonical Intel SGX BibTeX keys (`IntelSGXAttestationReference`,
  `IntelSGXSDM3D`, `IntelSGXSDKDeveloperReference`,
  `IntelSGXSecurityCenter`).

If any of those drift, the static-checks gate flips
`sgx_deployment_assumption_bundle_pinned` to `false` and the gate
rejects the checkpoint.

The same report now emits
`sgx_deployment_assumption_mechanism_matrix_pinned` and
`return_channel_crypto_gate_pinned`. Those checks require the
assumption-to-mechanism matrix, the first deployment milestone
checklist, and the runtime gate that rejects `ReturnPolicy::EncryptedToClient`
until an encrypted return-channel transcript exists.

## W6.6 Hostile-Host Closure Audit

W6.6 is the bundle-housekeeping audit for WP6, mirroring the W5.6
pattern. It records the post-W6.1 / W6.2 / W6.3 / W6.4 / W6.5
closure summary at the Lean type level: the WP6 surface has six
explicit checkpoint fields, each paired either with a Lean
refinement theorem (W6.1–W6.4) or with an explicit Cited /
externally justified provenance pairing (W6.5 deployment
assumptions).

The Lean side extends `proof/lean/UOToolchain/SgxObserverFreeze.lean`
with the `SgxHostileHostClosureAuditEntry` audit-record structure,
the six-element `sgxHostileHostClosureAudit` summary list, and four
closure theorems:

- `sgxHostileHostClosureAudit_length` (= 6);
- `sgxHostileHostClosureAudit_leanProvedEntries` (the first five
  entries are all classified `"Lean-proved,
  semantics-preserving"`);
- `sgxHostileHostClosureAudit_allClassified` (every entry is in
  one of the two acceptable WP6 buckets — no entry is
  "trusted-without-citation" or "source-frozen-only");
- `sgxHostileHostClosureAudit_driftCheckNames` (the audit names
  the canonical six probe drift checks in canonical order).

Claim taxonomy: **Lean-proved, semantics-preserving** for the
audit closure itself. The audit conclusion ("WP6 closes the
hostile-host TEE theorem") is meta — it states that every
surviving WP6 surface field has a documented home, not that any
TEE-side `Prop` axiom has been Lean-discharged.

### W6.6 audit summary

| Checkpoint | Role | Classification | Lean anchor | Drift check |
| --- | --- | --- | --- | --- |
| W6.1 | observer-surface freeze (page-region names, controller-phase vocabulary, page/exit-event vocabularies, shared-resource pattern, page-event encoding) | Lean-proved, semantics-preserving | `sgxObserverSurfaceProvenance` | `sgx_observer_surface_pinned` |
| W6.2 boundary-call | boundary-call model (oram_access API literal, Enter/Exit direction vocabulary, boundary-event budget formula, schedule structural shape) | Lean-proved, semantics-preserving | `sgxBoundaryCallProvenance` | `sgx_boundary_call_model_pinned` |
| W6.2 persistent-I/O | persistent-I/O model (PhysicalRead / PhysicalWrite field schemas, WriteClass vocabulary) | Lean-proved, semantics-preserving | `sgxPersistentIoProvenance` | `sgx_persistent_io_model_pinned` |
| W6.3 | controller-refinement integration | Lean-proved, semantics-preserving | `sgxControllerRefinementProvenance` | `sgx_controller_refinement_pinned` |
| W6.4 | sealing / storage-refinement integration | Lean-proved, semantics-preserving | `sgxStorageRefinementProvenance` | `sgx_storage_refinement_pinned` |
| W6.5 | deployment-assumption bundle (attestation, enclave isolation, rollback, freshness, crash, patch level) paired with Intel SGX provenance citations | Cited / externally justified | `SgxDeploymentAssumptions` + `sgxDeploymentAssumptionProvenances` | `sgx_deployment_assumption_bundle_pinned` |

### Provenance pairing

The W6.6 closure-audit theorems pin the audit summary at the Lean
type level. Any future addition to the WP6 surface that does not
also extend the audit list will fail the
`sgxHostileHostClosureAudit_length` check. Any field that lands in
the "trusted-without-citation" or "source-frozen-only" bucket will
fail the `sgxHostileHostClosureAudit_allClassified` check.

The paper-facing facades exposed in
[`ProofGrade.lean`](../proof/lean/UOToolchain/ProofGrade.lean) under
the `proofGrade_sgx_hostile_host_closure_audit_*` prefix mirror the
W5.6 closure-audit facade pattern.

### Closure conclusion

WP6 now closes the hostile-host TEE theorem in the W6 charter
sense: the observer signature is frozen (W6.1), the boundary
calls / persistent I/O / exits / shared-resource observations /
paging observations are all modeled (W6.1 + W6.2), the controller
and sealing / storage paths are refined into the canonical
observer (W6.3 + W6.4), the deployment assumptions are stated
explicitly with Intel SGX provenance citations (W6.5: six
fields covering attestation, enclave isolation, rollback,
freshness, crash, patch level), and the audit closes the surface
at exactly six checkpoints (W6.6). Every surviving claim is either
**Lean-proved, semantics-preserving** (W6.1–W6.4) or **Cited /
externally justified** (W6.5). No WP6 surface field remains
optional, deferred, or recorded for follow-up; the separate F17
mechanism matrix records deployment artifacts that must be supplied by
an SGX deployment or are removed from the implemented claim until the
runtime supports them.

## Revived Runtime-Kernel Requirements

The archived runbook was directionally right about what the runtime needed:

- a small auditable UO kernel ABI for confidential persistent-state operations
- bounded per-entrypoint working state instead of ad hoc growth
- explicit wipe / scrub discipline for confidential scratch regions
- constant public gas per confidential entrypoint
- no secret-dependent host-visible logging or exceptions
- eventual proof of the kernel itself, or a proof that the real runtime
  refines the same observer

Those requirements remain the right target. The difference now is that the
repository already has the theorem-facing observer and proof bridge, so this
track can attach directly to the current runtime instead of starting from a
blank design.

## Current Implementation Status

### Implemented now

The current runtime has a first hardening layer:

- `runtime/uo-kernel-runtime/src/lib.rs` is now the shared small-kernel
  surface used by the runtime for confidential state access, and `uo-evm`
  reaches it directly from `state.rs` / `shell.rs` rather than through a
  runtime-local shim
- `runtime/uo-precompiles/src/lib.rs` provides the kernel opcode vocabulary:
  `Begin`, `CellGet`, `CellSet`, `ArrayGet`, `ArraySet`, `MapGet`, `MapPut`,
  `Commit`, `Wipe`
- `runtime/uo-allocator/src/lib.rs` now derives a manifest-facing
  `AllocatorPlan::from_manifest` and enforces a bounded `AllocatorSession`
  during each call
- the emitted manifest now records the canonical confidential named DSL
  object, the canonical confidential slot DSL object, and the exact public
  kernel-step trace `{ opcode, object_id? }` for each confidential entrypoint,
  and checker-side source/artifact validation plus `uo-evm` reject drift
  against that artifact-side kernel program/schedule package when it is present
- that allocator session enforces:
  - exact confidential-entrypoint kernel-op budgets derived from the checked
    manifest's stored slot program and step trace, plus `Begin` / `Commit` /
    `Wipe`
  - stack-word bounds using the manifest `max_stack_words`
  - bounded value/hash scratch regions
  - wipe completion before the call finishes
- `runtime/uo-evm/src/engine.rs` now routes confidential cell/array/map
  operations through that kernel instead of calling the runtime objects
  directly
- the low-level runtime object transition helpers that shadow-load sealed
  state, install or validate fresh-coin tapes, export hidden ORAM witnesses,
  and cold-store committed state are now compile-time restricted to the
  shared `crate::runtime` module, and `RuntimeObject` no longer implements
  `Clone`, so `engine.rs` cannot duplicate or directly invoke those
  secret-bearing paths; `engine.rs` now also carries only the opaque
  `ContractRuntime` wrapper, while the runtime boundary itself splits live
  reopened object state into a public `PublicRuntimeShadowState` shell handle
  and a distinct `ConfidentialRuntimeShadowState` kernel handle instead of
  exposing one generic shadow wrapper, and the raw `RuntimeShadowState` plus
  confidential shadow wrapper are now visibility-restricted to
  `crate::runtime`
- confidential `keccak256` evaluation now streams canonical bytes directly into
  the hasher under the existing scratch-budget accounting instead of
  materializing per-part heap buffers first
- confidential object commits and ORAM page/bucket rewrites now route
  caller-owned plaintext buffers through
  `StoreCipher::seal_and_wipe_boxed`, so the post-encryption plaintext
  staging buffers are scrubbed before they are dropped
- written UO cell/array/small-map commit paths, surrogate ORAM page/bucket/
  counter rewrites, theorem-facing ORAM bucket/counter rewrites, and the
  generic `uo-store` cell-write path now also reuse their existing sealed
  buffers in place through `StoreCipher::seal_and_wipe_into_slice`, so those
  write paths no longer replace the sealed boxed ciphertext buffers on each
  confidential write
- surrogate ORAM directory-page encode/decode now also stays on exact-size
  page buffers: the runtime fills caller-owned page slices before sealing and
  decodes opened metadata pages directly back into the caller-owned boxed
  entry array rather than widening secret-bearing map entries into a temporary
  growable `Vec<MapEntry>`
- the Path-ORAM metadata path now follows that same exact-size rule: position
  map pages and stash pages are filled through caller-owned fixed-size page
  slices, sealed metadata pages are collected into a boxed fixed-size page
  array rather than a growable page vector, and ORAM blocks serialize
  directly into fixed-size block slices rather than through growable
  plaintext page buffers; the live Path-ORAM position map now also stays in a
  boxed fixed-size buffer across decode and rewrite instead of widening into a
  temporary `Vec<Option<usize>>` on the confidential path; its
  `MaskedUsizeOption` entries are now non-`Clone`/non-`Copy`, and all
  metadata clone/assign/select/repeat work routes through typed generated
  borrowed helpers rather than a generic `repeat_boxed<T: Clone>` surface
- live ORAM bucket reconstruction now likewise writes directly into the fixed
  bucket block buffer instead of staging live blocks through temporary
  growable `Vec<OramBlock>` lists
- bucket plaintext serialization now also fills exact-size bucket slices
  before sealing instead of growing a temporary plaintext `Vec<u8>`
- the remaining exact-size bootstrap and helper seal paths now also emit boxed
  ciphertext outputs directly: full-scan array/small-map initialization, ORAM
  bucket bootstrap, ORAM metadata-page sealing, ORAM counter bootstrap, and
  the small-map record / bucket plaintext helpers now stay on exact-size boxed
  buffers rather than widening back to temporary `Vec<u8>` carriers before
  boxing
- the generic `uo-store` cell-write API now also takes mutable plaintext
  buffers and wipes caller-owned bytes after raw copy / confidential seal, so
  that helper path no longer routes borrowed plaintext slices straight into
  `StoreCipher::seal`; the fixed-size raw/UO store slot maps now also keep
  their ciphertext cells in boxed buffers, and the UO write path seals
  directly into those fixed-size boxed slots instead of routing through a
  growable `Vec<u8>` slot carrier
- the runtime's exported physical-write witness is now also shape-only rather
  than ciphertext-bearing: `PhysicalWriteEvent` and the internal ORAM
  write trace retain only the public write location, length, and write class,
  while zero-write counts are carried only as aggregate metrics; the
  runtime-boundary report now rejects regressions back to stored `old` /
  `new` ciphertext vectors
- the runtime now also stops emitting recomputable host-proxy analytics in
  theorem-facing `ExecutionTrace`; the theorem trace now omits runtime
  telemetry entirely, ordinary `ContractInstance::call` results do too,
  `mplus-probe` derives byte counts, backend counts, update fractions, and
  controller-shape counts from the raw trace, and the runtime keeps only the
  irreducible aggregate `zero_writes` count in an explicit feature-gated
  diagnostic channel that is absent from the default runtime surface
- `StoreCipher` itself now zeroizes its sealing key on drop, so transient
  runtime clones do not leave old per-object store keys behind in ordinary
  drop paths
- logical `Value` trees now scrub themselves on drop, so transient runtime
  copies of decoded contract values do not rely only on allocator release for
  cleanup
- hidden ORAM logical state now also scrubs itself on drop: map entries,
  stash/path blocks, position maps, and injected fresh-leaf coin queues are
  zeroed before ordinary drop completes
- per-object runtime RNG state now gets reset on drop for cell/array/map
  objects, reducing the lifetime of old nonce/leaf-generation state in
  transaction-shadow and replaced-object paths
- `engine.rs` no longer keeps a duplicate secret-bearing call-argument vector
  just to build the public theorem trace: it now retains only a
  `PublicCallSummary` derived from the checked manifest's `param_names`,
  `secret_args`, and manifest-stored `entry_input_len`, containing the
  already-public argument projection plus a type-derived total input length;
  `engine.rs` now delegates the traced-call lifecycle through the
  `runtime/uo-evm/src/runtime.rs` facade rather than importing theorem helpers
  directly, the shell now holds an opaque `ContractRuntime` wrapper rather
  than the raw committed confidential state, `engine.rs` now boxes call args
  once into a fixed-size slice for the traced-call/runtime path, and the
  runtime/state confidential branch then passes that payload directly to the
  shared `uo-kernel-runtime` confidential-call path, where the
  Lean-generated fixed-size `ConfidentialCallInputs` wrapper is created,
  consumed by `RuntimeKernelSlotCall`, checked for exact argument count, and
  wiped on drop before delegating to
  `uo_core::execute_confidential_kernel_slot_program(...)`,
  and the controller/theorem path now derives public return length from
  manifest-stored `return_canonical_len` and receives only the public
  `OutputShape` summary rather than the full return payload; `theorem.rs` also
  no longer depends on `CompiledFunction` and instead routes public execution
  by `(contract, entrypoint signature)` through `shell.rs`; injected
  fresh-coin plans now zero their stored leaf choices on drop, are consumed
  by value at the diagnostic runtime entrypoint, keep those per-object secret
  leaf tapes in fixed-size buffers while staged, and move them into the live
  shadow state without cloning them first; the live `PathOramLeafCoinSource`
  now keeps those injected leaf choices as a fixed-size tape plus cursor
  rather than widening them back into a growable queue, and the theorem-facing
  diagnostics fresh-coin grouping/replacement path now uses checked
  `get(...)` / `get_mut(...)` lookups rather than `old_entries[index]`,
  `coin_schedule[index]`, or schedule sub-slices
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
- ORAM refresh/metadata decode now uses `StoreCipher::with_opened_payload`, so
  decrypted position-map / stash / bucket payload buffers are scrubbed after
  parse instead of lingering as dropped plaintext heap allocations
- confidential transaction-shadow creation for all UO object classes now
  rebuilds logical state from sealed storage instead of cloning live logical
  caches: `UoCell`, `UoArray`, `UoSmallMap`, and `UoOramMap` all reconstruct
  their shadow state from sealed ciphertexts before execution starts
- the corresponding rollback / no-op commit paths now also restore old state
  from sealed storage instead of trusting the old in-memory logical caches, so
  abort recovery and untouched-object commit recovery are tied to the same
  sealed-state boundary for cells, arrays, full-scan maps, path ORAM, and
  surrogate ORAM
- committed UO runtime state is now also re-colded after each call: the
  long-lived contract instance keeps sealed storage plus public metadata, while
  the hidden before/after access-counter and position-map certificates are
  extracted from the opened shadow states before they are dropped back to that
  sealed boundary
- confidential calls no longer shadow-load every object in the contract: for
  proof-grade confidential entrypoints the runtime now reopens only the
  admitted touched object-id set, in canonical object-id order, while untouched
  committed objects remain sealed for the whole call and cold Path-ORAM
  position-map witnesses are reconstructed from ciphertext only when the
  hidden certificate needs them
- that decode path now also streams decrypted position-map / stash pages
  directly into the bounded live ORAM state instead of materializing
  per-page decoded temporary vectors first, and it rejects decoded path-ORAM
  stash contents that exceed the manifest public `stash_bound`
- path-ORAM stash handling now treats the stash as an unordered multiset at
  the runtime level: delete / bucket-fill paths use order-insensitive removal
  instead of shift-heavy `Vec::remove`, and the runtime test suite now checks
  that the witness-visible behavior of a delete access is invariant under a
  permutation of the same logical stash contents
- path-ORAM refresh now rejects malformed hidden state more aggressively:
  out-of-range position-map / stash leaves, out-of-range stash slots,
  duplicate live blocks for one logical slot, and live blocks whose leaf label
  disagrees with the decoded position map are all rejected before execution,
  and bucket-resident live blocks must actually lie on the declared leaf path
- path-ORAM bucket decode now also validates that the bucket header matches the
  storage location being opened and that the header’s live-entry count exactly
  matches the number of occupied blocks in the payload
- those seal/decrypt payload buffers are now also accounted under an explicit
  allocator/kernel `io` scratch region, so the exported runtime kernel witness
  carries public peak/wipe facts for confidential storage I/O staging rather
  than only for value/hash helpers
- `uo-allocator` now also emits the public resource-event trace that justifies
  those stack/scratch facts: stack checks, scratch reservations, and scratch
  wipes are recorded explicitly on the runtime kernel witness rather than only
  summarized as final counters
- the shared runtime-kernel statement recorder now uses exact-capacity storage
  through the safe owned `fixed_buffer::FixedPrefixBuffer<String>` wrapper
  rather than `vec![None; capacity]`, local raw unsafe moves/drops, or a
  `Vec`-repacking finish step, so the opcode-trace bridge stays on the same
  fixed-shape discipline as the rest of the tiny kernel
- the call-scoped kernel now begins before transaction shadow-state cloning, so
  the pre-call ORAM refresh/decode path is also covered by that `io` scratch
  accounting instead of happening entirely outside the witness boundary
- ORAM block/directory serialization now appends directly into the enclosing
  page/bucket payloads instead of allocating extra per-block or per-record
  temporary plaintext vectors along the way
- the path-ORAM access path no longer clones the full committed
  `entries`/`position_map`/`stash` logical state before each rewrite; it now
  moves the working vectors into the access routine and rebuilds them in place
- the runtime now emits a compact `RuntimeKernelWitness` containing the kernel
  public kernel-step trace, derived schedule facts, peak stack usage, public
  allocator bounds, scratch peaks, wipe counts, and the public object universe
- for accepted confidential entrypoints, `uo-evm` now validates that witness
  against the checked manifest's stored confidential slot program before
  returning the trace
- for accepted confidential entrypoints, the runtime kernel now also executes
  against the checked manifest's exact admitted public `{ opcode, object_id? }`
  step schedule and rejects missing, extra, or mismatched steps online rather
  than only by post-hoc witness comparison
- the exported runtime trusted-kernel bundle and `refinement-witness` JSON now
  carry that kernel witness directly, and the proof-grade `trusted-kernel`
  JSON path now also packages the admitted confidential slot program alongside
  that bundle
- the proof-facing boundary now also includes a standalone proof-grade kernel
  witness checker, so the small-kernel object can be validated directly rather
  than only through the larger trusted-kernel / refinement bundles
- the Lean imported trusted-kernel / refinement-witness validators now consume
  that exported kernel witness and check entrypoint alignment, opcode-envelope
  shape, scratch-budget consistency, wipe discipline, kernel-step shape, and
  exact kernel-step equality, while the proof-grade
  `checkProofGradeRuntimeWitness` validator still requires the exact expected
  public kernel-step trace to be embedded in confidential witnesses and
  `checkProofGradeRuntimeKernelInterface` now exposes the paper-facing
  shell/kernel interface theorem over that same accepted runtime witness, and
  `checkProofGradeRuntimeTrustedKernel` now requires the trusted-kernel proof
  artifact to package the admitted confidential slot program whose derived
  public schedule must match that embedded witness exactly
- the core Lean trusted-kernel / refinement-witness structures now also expose
  theorem-side `ProofGradeValid` predicates, and the trusted-kernel path now
  also exposes a theorem-side slot-wrapped bundle, so the "kernel witness is
  present and exact for this admitted slot program" condition is available
  above the JSON importer layer as well
- the Lean side now also exposes proof-grade schedule-exactness lemmas for the
  kernel witness, refinement witness, trusted-kernel bundle, and slot-wrapped
  trusted-kernel proof object, so a proof-grade accepted artifact carries one
  exact public kernel schedule rather than only a validator acceptance bit
- the Lean side now also packages that admitted schedule explicitly as a
  `RuntimeKernelSchedule` / `ImportedRuntimeKernelSchedule` object derived from
  the witness, so later refinement statements can target the schedule object
  directly instead of unpacking duplicated opcode-list and step-trace fields
- the Lean side now also gives that schedule an explicit small-kernel replay
  semantics, so accepted proof-grade kernel witnesses must not only carry the
  exact admitted public schedule but also replay it successfully from
  `ready` to `finished` under the modeled `Begin -> object ops* -> Commit ->
  Wipe` machine
- that modeled replay now also determines the exact final public object-id
  schedule seen by the kernel state, so the proof boundary fixes not only the
  admitted step trace but also the resulting public object-order
- the Lean side now also replays the emitted public resource-event trace
  against the kernel's public stack/scratch budgets and fixes one exact
  replayed resource state; the theorem surface now exposes that exact replayed
  resource state not only for the standalone kernel witness but also through
  the refinement-witness and trusted-kernel-bundle proof-grade lemmas
- the runtime now also emits a lower-level `RuntimeKernelRefinementWitness`
  under that public kernel witness: it records the concrete runtime phase trace
  `pre-committed-cold objects* -> Begin -> shadow-load objects* -> kernel
  steps* -> Commit -> commit objects* -> Wipe -> cold-store objects* ->
  post-committed-cold objects*` while keeping the theorem-facing public kernel
  ABI unchanged
- that lower-level phase witness is carried by the runtime refinement witness
  but not by the smaller trusted-kernel bundle, so the public theorem boundary
  remains the small kernel ABI while the runtime-to-kernel bridge gains a more
  concrete internal certificate
- confidential expression / statement interpretation for admitted entrypoints
  now also runs through the shared `RuntimeKernelMachine` path, while the
  non-confidential interpreter has been split into the explicit
  `runtime/uo-evm/src/shell.rs` public-shell module, so the engine is public
  orchestration only and the secret-bearing env / return-value machine is
  kernel-owned
- that confidential interpreter now executes a slot-lowered kernel DSL rather
  than the earlier name-keyed environment form: `uo-core` lowers admitted
  confidential entrypoints to a fixed-slot program, and the shared
  Lean-generated `uo-kernel-runtime` slot-support module now owns the bounded
  fixed-size `Box<[Option<Value>]>` slot file and confidential-argument
  staging, while the private `RuntimeKernelSlotCall` adapter keeps live
  slot-word accounting instead of leaving `uo-evm` or a public `uo-core` call
  wrapper to wire those pieces together by hand; the source-backed Lean
  boundary now checks that this adapter only forwards to generated slot
  support, object-store effects, and the generated interpreter and rejects raw
  confidential-argument observations in the adapter; the generated slot state
  wipes those values on drop. The same boundary now pins the
  `RuntimeKernelMachine` effect schedule so cell/array/map/commit operations
  record public opcodes, reserve bounded scratch, delegate to the object
  store, append the commit schedule, and wipe before finish; Lean exposes the
  expected effect shape as `RuntimeKernelMachineSchedule`. The checked
  implementation boundary now also imports `uo-allocator` source and checks
  allocator-session kernel-op, scratch, stack, guard-drop wipe, finish-wipe,
  bounded public resource-event logging, boxed finish-boundary resource
  events, and unsafe/forget-escape discipline, backed by
  `RuntimeAllocatorDiscipline`. F15 pins the remaining theorem-adjacent
  fixed-buffer `unsafe` to `crates/uo-core/src/fixed_buffer.rs`. The live
  confidential statement recorder is now exact-capacity and backed by
  `RuntimeStatementTraceDiscipline` rather than a growable `Vec<String>`.
  Confidential
  `keccak256` evaluation in the
  shared `uo-core` interpreter now also stages hash parts through an
  exact-size boxed buffer
  rather than a growable `Vec<Value>`, and the shared kernel/runtime path
  wipes each hashed part after it has streamed its canonical bytes; the same
  fixed-shape discipline now also covers the recursive runtime `Value`
  aggregates themselves, so both struct fields and array elements stay in
  boxed fixed-size buffers rather than growable `Vec` carriers, canonical
  payload extraction now has an exact-size boxed helper rather than
  `canonical_bytes().into_boxed_slice()` caller-side bouncing, the remaining
  generated `canonical_bytes()` `Vec` helper is test-only rather than part of
  the production runtime value API, and the discipline also covers the live
  confidential array / small-map logical buffers, the boxed UO cell
  ciphertext slot, the live fixed-shape Path-ORAM entry array, the live
  fixed-capacity stash, the fixed-shape bucket block buffer, and the fixed
  public-shape Path-ORAM page arrays plus boxed ORAM counter slot and live
  position-map buffer; handwritten array write bookkeeping now uses fixed-size
  boxed public flags instead of a growable `BTreeSet` of written indices; the
  hidden Path-ORAM position-map witness now also
  stores its leaf array in a boxed fixed-size buffer while the theorem-side
  leaf-state validator now keeps those leaves boxed too rather than reopening
  them into temporary `Vec` state, and the raw-backend
  `RawMapEntry` ciphertext slot is now boxed too, so the runtime object graph
  no longer keeps secret-bearing ciphertext in growable `Vec<u8>` buffers;
  raw-backend objects are also rejected as confidential slot-program targets
  by the direct Lean proof-grade translation checker, `uo-solc` lowering, and
  runtime admission
- the kernel-step witness journal and the lower-level runtime phase witness
  journal are now both explicit bounded-capacity journals derived from the
  public kernel-op/object bounds; the shared `uo-core` trackers now store those
  journals in fixed-capacity boxed `BoundedJournal<T>` buffers rather than
  growable `Vec` fields, and the remaining public shell-side commit / witness
  lists now start from explicit `Vec::with_capacity(...)` bounds under those
  same public object-count limits; ORAM placeholder states now use direct empty
  boxed slices instead of `Vec::new().into_boxed_slice()` bootstrap carriers
- live Path-ORAM stash state is now also rebuilt with public
  `working_stash_capacity(...)` headroom up front, preserved across cold
  commits with `.clear()`, and checked before use so the runtime no longer
  depends on a late mid-call `reserve(...)` on that secret-bearing stash
- path-bucket rebuilds now likewise materialize into fixed-shape block buffers
  under the public `blocks_per_bucket` budget rather than transient growable
  vectors
- Path-ORAM clones and storage refresh now also preserve and reuse the public
  entry / position-map / stash capacities in place rather than silently
  collapsing back to fresh zero-capacity vectors during clone or refresh
- touched Path-ORAM aborts now also restore old state in place via
  `OramState::restore_from_old(...)`, so neither untouched nor aborted
  `UoOramMap` commits replace the whole shadow ORAM object anymore
- the full-scan object array/small-map paths now also reuse their logical
  buffers in place across both cold commit and old-state restoration: cold
  commits clear and resize their `values` / `entries` vectors, and abort or
  untouched restore paths decode old sealed state back into those same
  vectors instead of allocating replacement secret-bearing buffers; written
  UO cell/array/small-map commits now also reuse their existing ciphertext
  slot buffers in place, while untouched commits keep those already-cloned
  buffers instead of re-cloning old physical slots
- the object-store confidential access schedule is now also source-pinned at
  the boundary: Path-ORAM commit write evidence uses fixed public write batches
  rather than a growable write log, ORAM read transcript evidence is held in
  boxed logical/physical-read arrays produced by generated fixed
  public-capacity builders rather than temporary growable trace vectors in handwritten runtime
  code, UO small-map lookup scans the full public capacity with
  masked selection rather than early exit, and UO array reads / writes scan
  the full public capacity with masked selection; UO-path
  out-of-range logical indices therefore become masked no-match/no-op behavior
  instead of a public error branch
- generated confidential-kernel return scheduling is now source-pinned at the
  same boundary: non-final source returns are rejected before lowering, the
  generated interpreter no longer uses a `state.returned` / `break` truncation
  branch, and the tamper suite rejects reintroducing that branch on the checked
  runtime implementation routes
- generated map read/write capacity/update failure is now source-pinned as an
  in-kernel confidential abort path: UO small-map and Path-ORAM helpers return
  overflow/update-failed bits for reads and writes, and the generated
  confidential-kernel interpreter records those bits with its generated
  `note_abort_generated(...)` helper; the checked source boundary and probe
  reject handwritten masked abort updates and the older generated host-visible
  `bail!` branches for deterministic small-map full, missing selected ORAM
  block, Path-ORAM stash insertion/working-stash
  overflow, and surrogate insert-capacity failure
- generated helper `Result` errors now have a checked taxonomy rather than a
  blanket exemption: public shape/capacity, authenticated decode/integrity,
  cold-restore, fresh-coin tape, and write-log discipline failures may surface
  to the host, but deterministic hidden-state map/ORAM capacity and update
  misses must be folded into the modeled abort bit
- the remaining secret-bearing runtime object transitions are now kept behind
  the same `crate::runtime` module boundary at compile time, so the engine
  cannot directly reopen, commit, duplicate, or hidden-state-export runtime
  objects outside that boundary; the shell's long-lived state is now an opaque
  committed-state handle rather than a directly owned object map, and that
  committed/shadow state is now represented internally by a boxed fixed-order
  object table keyed by the public object universe instead of a generic
  `BTreeMap<u32, RuntimeObject>`. The remaining confidential object-table
  rebuilds in `state.rs` now also go through one exact-size boxed builder
  rather than temporary growable `Vec<RuntimeObjectEntry>` staging buffers,
  and the hidden committed-state ORAM witness snapshot now uses that same
  exact-size builder discipline keyed by the public Path-ORAM object count.
  The committed-state duplicate-object guard now also uses a two-element slice
  pattern over public windows rather than `pair[0]` / `pair[1]` indexing.
- the shadow-load path, committed-shadow reconciliation path, and injected
  Path-ORAM fresh-coin routing path now also live in
  `runtime/uo-evm/src/state.rs` rather than being assembled directly in
  a separate `uo-evm` kernel module, which further shrinks the amount of
  object-level state surgery left inside the kernel body
- the shared `uo-kernel-runtime` machine now routes the remaining object-level
  `cell_get` / `cell_set` / `array_get` / `array_set` / `map_get` / `map_put`
  and commit logic through one private shared shadow-state interface
  implemented in `state.rs`, so the bespoke Rust kernel surface that still
  needs a refinement story is smaller and more uniform than before
- the live proof-critical kernel-boundary bookkeeping in
  `uo-kernel-runtime` now also routes through one shared
  `uo-core` `RuntimeKernelBoundaryTracker`, which owns the public-object
  bootstrap, admitted-schedule binding, runtime-phase tracking, and exact
  finish-snapshot handoff rather than leaving that coordination as ad hoc
  runtime-local glue
- Rust and Lean now both validate that the lower-level phase witness projects
  exactly to the emitted public kernel-step schedule, that shadow-load,
  commit-object, and cold-store schedules agree, that the witness includes the
  exact pre/post committed-cold object schedules over the full public object
  universe, and that every kernel-visible object id is covered by the
  shadow-load schedule
- the Lean side now also exposes an explicit
  `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem for that
  lower-level phase witness, so the refinement witness fixes not only the
  admitted public kernel schedule and resource replay state but also one exact
  modeled shell/kernel contract: the shell's pre/post committed-cold boundary
  schedules are fixed to the full public object universe, and its
  shadow-load / commit / cold-store schedules are fixed to the canonical
  touched-object set induced by the exported kernel schedule. The theorem
  surface still exposes the underlying exactness lemmas for the kernel
  witness's public object universe and for the runtime phase witness's
  pre/post committed-cold boundary schedules, and the exported shell trace now
  also includes the ordered public runtime-phase event sequence itself so Rust
  and Lean can both check that the summary schedules are honest projections
  and that the event trace replays the public shell contract
- the runtime and imported Lean paths now also package those exact shell and
  kernel-side consequences into one `RuntimeProofGradeKernelBoundaryFacts` /
  `ImportedRuntimeProofGradeKernelBoundaryFacts` theorem-facing interface, so
  the confidential-core proof route consumes one accepted runtime witness and
  derives the exact public kernel schedule, object universe, resource replay,
  runtime-phase projection, and shell refinement from that single packaged
  boundary theorem rather than re-deriving those facts separately
- `uo-core` now also exports that theorem-facing shell/kernel interface as a
  direct `RuntimeShellBoundaryBundle`: the proof-grade kernel witness, the
  runtime phase witness, and the explicit exported `RuntimeShellContract` /
  `RuntimeShellTrace` JSON all travel together, Lean checks that those shell
  objects exactly match the witnesses they claim to summarize, checks the
  shell-event trace replay, the witness-based
  `checkProofGradeRuntimeKernelInterface` checker still exposes the same
  paper-facing theorem surface directly from the full runtime witness JSON,
  the new `checkProofGradeRuntimeKernelInterfaceBundle` checker validates the
  explicit exported `RuntimeKernelInterfaceBundle`, the stronger
  `checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot` checker validates
  the exported `RuntimeConfidentialCoreKernelInterfaceSlotBundle`, and the
  native and imported shell-boundary developments now both prove that the
  explicit kernel-interface bundle surface subsumes the older
  kernel-boundary-facts theorem route directly, so the paper-facing path can
  cite the exported bundle object instead of reconstructing those facts from
  witnesses; that exported shell-boundary / kernel-interface layer now also
  keeps its public schedules, expected-step lists, and shell-event summaries
  in boxed fixed-shape buffers rather than reopening those theorem-facing
  carriers as growable `Vec` values, and the shared
  `RuntimeKernelScheduleWitness` now likewise keeps its opcode trace and step
  list boxed through that exported theorem-facing interface. The exported
  `RuntimeKernelWitness` now also keeps its resource-event trace, emitted and
  expected kernel-step lists, and emitted and expected public-object schedules
  boxed on that theorem-facing path
  raw witnesses,
  probe validates those explicit shell-boundary and confidential-core/kernel-
  interface/slot artifacts separately as `shell_boundary_validation.json`,
  `confidential_core_kernel_interface_slot_validation.json`,
  `kernel_slot_boundary_validation.json`, and now also
  validates the fully shared
  `RuntimeConfidentialProofBundleFamily` artifact as
  `confidential_proof_family_validation.json`
- that shell-boundary bundle is now also accessor-only on the Rust side: its
  witness / contract / trace fields are private, callers read them through
  explicit getter methods, the shell contract itself is now accessor-only, the
  shell-trace constructor is internal, and the probe rejects drift if those
  fields become public again or if the getter surface changes
- the lower-level runtime-phase witness constructor is now checked too, so
  malformed event-phase traces are rejected immediately instead of being
  carried deeper into the proof-facing bundle pipeline
- the proof-grade `RuntimeKernelWitness` now also uses one checked constructor
  plus accessor-only Rust fields, so the runtime producer cannot emit an
  obviously malformed kernel witness through a public field literal path
- the derived `RuntimeKernelScheduleWitness` now follows that same sealing
  rule: schedule fields are private, construction is checked, and the probe
  rejects new raw schedule-literal paths or reopened field access on the Rust
  side
- the shared DSL/interpreter bridge now also composes directly through that
  shell object: `uo-core` exports a `RuntimeShellBoundaryLoweringBundle`
  carrying the shell-boundary bundle plus the named and slot confidential
  programs for the same entrypoint, and Lean checks both the shell-boundary
  refinement claim and the named-to-slot lowering claim against the same
  proof-grade kernel witness; the probe validates that composed bridge
  separately as `shell_boundary_lowering_validation.json`
- that same shell interface now also has a direct slot-only proof path:
  `uo-core` exports a `RuntimeShellBoundarySlotBundle` carrying the
  shell-boundary bundle plus the exact fixed-slot confidential program that
  the shared runtime-kernel path executes, and Lean checks that the shell-boundary
  refinement claim and the slot-derived kernel schedule share the same
  proof-grade kernel witness; the probe validates that path separately as
  `shell_boundary_slot_validation.json`
- the confidential-kernel lowering functions on both the runtime and imported
  Lean sides are now structurally recursive total definitions rather than
  opaque `partial def`s, and the imported/runtime lowering bridge is restored
  all the way through program lowering: Lean now proves exact commutation for
  imported expression, statement-list, and whole-program lowering, so an
  imported named confidential program that lowers successfully must match the
  stored manifest slot program through `SlotLoweringMatches`
- the imported lowering bundles now also expose runtime-facing theorems and
  executable `toRuntime...LoweringBundle?` helpers over that stored manifest
  pair: after Lean validates an imported kernel-only, confidential-core,
  shell-boundary, or combined lowering bundle, the runtime-facing interface
  preserves the manifest-carried named/slot program pair rather than silently
  re-lowering from the named DSL object
- the post-call `cold_store_object` / `post_committed_cold_object` tail for
  that runtime phase witness is now also finalized inside the shared
  `uo-kernel-runtime` / `state.rs` boundary rather than being assembled in `engine.rs`;
  `state.rs` now only checks the committed-cold boundary after shadow state is
  turned back into committed storage, which further shrinks the amount of
  concrete runtime-phase witness construction left outside the kernel
- that lower-level runtime phase witness now also has a sealed Rust surface:
  `RuntimeKernelRefinementWitness` keeps its `events` vector private, exposes
  only shared constructor/accessor methods for cross-module use, no longer
  exposes public tail-appending mutators for commit/cold-store windows, and
  the probe now checks both that privacy boundary and the runtime-side
  `from_events(...)` helper path explicitly; the exact `RuntimeShellTrace`
  artifact exported above
  that witness now also keeps its stored event/schedule vectors private and is
  rebuilt through one explicit constructor/accessor surface instead of public
  field mutation
- the post-call proof-facing `ExecutionTrace` packaging now also lives in
  `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer constructs the
  controller-observer certificate, hidden Path-ORAM certificate, or
  trusted-kernel bundle directly, and the committed ORAM before/after snapshot
  used by that theorem packaging path is now captured through the theorem-side
  `CallTraceContext`; that same theorem-side context now also owns the public
  `PublicCallSummary` and `CallRecorder`, so `engine.rs` no longer calls
  `witness_snapshot()`, `PublicCallSummary::from_manifest_entry`, or
  `ExecutionTrace { ... }` directly; the proof-bearing runtime payloads stored
  on `ExecutionTrace` itself now also keep their fields private and expose only
  explicit accessors / validated reconstruction helpers, so post-call theorem
  artifacts cannot be silently rewritten through public field mutation outside
  `uo-core`; the hidden runtime ORAM witness slices carried by
  `ExecutionTrace` and by the intermediate `RuntimeExecutionTraceParts`
  constructor path now also stay in boxed fixed-size buffers rather than
  widening back into growable vectors, and the theorem-facing seeded witness
  families, paper-main family bundles, canonical fresh-coin families, and
  extracted fresh-coin scaffold/value accessors now likewise keep their fixed
  schedules and witness lists boxed rather than reopening them through generic
  growable containers. The same is now true for the deeper
  theorem-facing controller/refinement objects carried through `uo-core`: the
  runtime kernel-refinement event journal, controller certificate observed
  ORAM-access list, controller-observer boundary schedule, hidden
  controller/Path-ORAM certificate buffers, `TheoremTrace` boundary schedule,
  `RuntimeRefinementWitness` boundary/hidden buffers, and each emitted
  Path-ORAM position-map witness leaf array all stay boxed as well. The probe
  now keeps that deeper representation discipline pinned explicitly; the
  intermediate `RuntimeExecutionTraceParts` carrier is now also
  constructor-backed rather than a public-field bag, and the probe keeps its
  single production constructor use pinned to `runtime/uo-evm/src/theorem.rs`;
  the certificate-based `RuntimeRefinementWitness` reassembly helpers are now
  internal to `uo-core` as well
  `CallRecorder::begin_with_input_len` for the theorem path, and the
  shell/state traced-call route now constructs one shared `uo-core`
  `CommittedRuntimeWitnessSnapshotBuilder`, finalizes one shared
  `CommittedRuntimeWitnessSnapshot`, wraps it through shared
  `TracedRuntimeCallStart` / `TracedRuntimeCallOutcome` carriers, constructs
  one shared `uo-core` `RuntimeCallOutcome`, and then upgrades that to one shared
  `FinalizedRuntimeCallTraceParts` bundle before `theorem.rs` consumes that
  bundle through `into_execution_trace_inputs()`, rather than having the
  engine unpack kernel witnesses, opcode traces, and return values just to
  pass them straight back in; the old
  `ConfidentialKernelRunOutcome` and `ConfidentialCommittedKernelOutcome`
  wrappers are now gone, and both the kernel-to-state and
  state-to-runtime-call handoffs now either move through those shared
  constructor-backed wrappers or destructure directly into explicit tuples
  rather than keeping extra secret-bearing bundle types alive past the point
  where they are needed. The controller/theorem public trace path now follows
  the same pattern as well: `controller.rs` emits one shared `uo-core`
  `RuntimePublicCallTraceBundle`, and `theorem.rs` consumes it only through
  `into_runtime_finalization_input(...)` rather than unpacking logical/physical
  traces, controller certificates, and ORAM leaf witnesses field by field.
- the theorem-facing constructor surface is now pinned as well:
  `ExecutionTrace::from_runtime_finalization_input(...)` stays confined to
  `runtime/uo-evm/src/theorem.rs`, while
  `RuntimeExecutionTraceFinalizationInput::new(...)` and the shared
  `RuntimePublicCallTraceBundle::into_runtime_finalization_input(...)` path
  stay confined to `crates/uo-core/src/trace.rs`; the lower-level
  `ExecutionTrace::from_runtime_trace_parts(...)`,
  `ExecutionTrace::materialize_runtime_trusted_kernel_bundle(...)`, and
  `RuntimeExecutionTraceParts::new(...)` stay confined to
  `crates/uo-core/src/trace.rs`, where the finish-bundle pair validation,
  admitted runtime-ORAM object reconstruction, confidential proof-family
  recheck, and trusted-kernel materialization now live together, while the
  lower-level
  `RuntimeControllerObserverCertificate::new`,
  `RuntimePathOramHiddenCertificate::new`, and
  `RuntimeTrustedKernelBundle::new_with_kernel_witness(...)` constructors are
  no longer part of the runtime-facing theorem bridge and stay internal to
  `crates/uo-core/src/trace.rs`; production theorem-trace assembly now also
  routes through the shared `uo-core`
  `RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(...)`
  interface and its `theorem_trace()` projection rather than a runtime-local
  controller-certificate / controller-shape / theorem-trace reconstruction
  path; the underlying `RuntimeControllerCertificate::from_observed_oram_accesses(...)`,
  `TheoremTrace::from_public_observer_parts(...)`, and
  `SgxControllerShapeTrace::from_runtime_observer_parts(...)` constructors now
  stay in `uo-core`, and the production runtime no longer keeps local
  `RuntimeControllerCertificate`, `SgxControllerShapeTrace`,
  `PublicOutcomeTrace`, or `TheoremTrace` theorem-facing assembly logic on
  that path; the exported controller/public observer shape is now tighter too,
  with `PublicOutcomeTrace.public_args`,
  `SgxControllerShapeTrace.controller_phase_order`,
  `SgxControllerShapeTrace.page_trace_regions`,
  `SgxControllerShapeTrace.workset_regions`, and the derived
  `NormalizedMicroTrace` page/exit/shared-resource patterns all carried in
  boxed fixed-shape buffers rather than growable `Vec` carriers; the live
  recorder side now mirrors that discipline with fixed public
  `ControllerRegionCounters` for page/workset budgets and derives per-object
  ORAM access counts from the observed public schedule rather than maintaining
  a separate `BTreeMap<u32, usize>` counter
- the public-trace helper surface is pinned too:
  `PublicCallSummary::from_manifest_entry(...)` and
  `CallRecorder::begin_with_input_len(...)` stay confined to
  `runtime/uo-evm/src/state.rs`, `PublicCallSummary` now crosses the
  state/controller boundary only through the explicit
  `entry_input_len()` / `into_public_args()` API rather than raw field reads,
  `CallRecorder` itself is now non-`Clone`,
  while `output_shape_of(...)` stays confined to
  `runtime/uo-evm/src/controller.rs`, and the theorem bridge now routes
  public call-trace assembly through
  `finalize_public_call_trace(...)` instead of computing output shape or
  calling `CallRecorder::finish(...)` directly
- the shell-boundary bridge is now pinned in the same style:
  `RuntimeKernelWitness::shell_contract(...)`,
  `RuntimeKernelRefinementWitness::shell_trace(...)`, the exact
  `shell_contract` / `shell_trace` packaging inside
  `RuntimeShellBoundaryBundle::from_witnesses(...)`, and
  `ExecutionTrace::runtime_shell_boundary_bundle(...)` all stay confined to
  `crates/uo-core/src/shell_boundary.rs`, with the helper derivations now
  crate-confined instead of being part of the public `uo-core` API,
  `crates/uo-core/src/shell_boundary.rs`; the anti-drift report also requires
  that downstream confidential-core bundles reuse that explicit
  `RuntimeShellBoundaryBundle` rather than rederive shell summaries, and that
  Lean keeps checking exact equality between the exported shell bundle and the
  witness-induced shell views before accepting the public shell-refinement
  claim
- the confidential-core theorem bundle family is pinned too:
  `ExecutionTrace::runtime_confidential_core_bundle(...)`,
  `runtime_confidential_core_slot_bundle(...)`,
  `runtime_confidential_core_lowering_bundle(...)`,
  `runtime_confidential_core_shell_boundary_lowering_bundle(...)`, and
  `runtime_confidential_core_shell_boundary_slot_bundle(...)` stay confined to
  `crates/uo-core/src/confidential_core.rs`, and the anti-drift report now
  also checks that the Lean side still carries the exact proof-grade assurance
  / witness-equality / named-vs-slot exactness theorems for those bundles and
  that both the direct confidential-core bundle / slot-bundle / lowering-bundle
  trio and the confidential-core shell-boundary slot/lowering pair stay
  accessor-only on the Rust side; the checked shell-boundary slot/lowering
  composites and the checked kernel-interface slot composite no longer
  re-expose the raw `RuntimeRefinementWitness` accessor once the stronger
  checked boundary bundle is present
- the trusted-kernel slot bridge is pinned on the same path:
  `RuntimeTrustedKernelSlotBundle::from_trusted_kernel_bundle(...)`,
  `ExecutionTrace::runtime_trusted_kernel_slot_bundle(...)`, and the
  entrypoint-match helper stay confined to `crates/uo-core/src/trusted_kernel.rs`;
  the anti-drift report now also checks that this bridge still sources the
  exact manifest-carried slot DSL, that both `RuntimeTrustedKernelBundle` and
  `RuntimeTrustedKernelSlotBundle` keep their proof-facing fields private
  behind explicit accessors, that the Rust constructor now rejects slot-program
  entrypoint drift directly, and that Lean keeps the proof-grade trusted-kernel
  schedule exactness and slot-bundle validity path intact
- the shell-boundary slot/lowering bridge family is pinned too:
  `RuntimeShellBoundaryLoweringBundle::from_manifest_entry(...)`,
  `RuntimeShellBoundarySlotBundle::from_manifest_entry(...)`,
  `ExecutionTrace::runtime_shell_boundary_lowering_bundle(...)`, and
  `runtime_shell_boundary_slot_bundle(...)` stay confined to
  `crates/uo-core/src/kernel_dsl.rs`; the anti-drift report now also checks
  that these bridges continue to source the manifest-carried named and slot
  DSL programs exactly, that the shell-boundary slot/lowering bundles keep
  their proof-facing fields private behind explicit accessors, and that Lean
  keeps the shell-refinement, slot-schedule exactness, named-vs-slot lowering
  exactness, and to-runtime validity theorems for those bundles
- the direct runtime-kernel bundle family in that same module is pinned too:
  `RuntimeKernelDslBundle::from_manifest_entry(...)`,
  while the paper-facing runtime/kernel boundary itself is now also explicit on
  the Rust side as `ExecutionTrace::runtime_kernel_interface_bundle(...)`, with
  a private constructor that reuses the checked shell-boundary bundle plus the
  manifest-backed kernel witness exactness checks
  `RuntimeKernelSlotDslBundle::from_manifest_entry(...)`,
  `RuntimeKernelLoweringBundle::from_manifest_entry(...)`, and the
  `runtime_kernel_*_bundle_for_entrypoint(...)` entrypoints stay confined to
  `crates/uo-core/src/kernel_dsl.rs`; the anti-drift report now also checks
  that these bundles keep sourcing the manifest-carried named and slot DSL
  programs, that the direct runtime-kernel DSL / slot-DSL / lowering bundles
  keep their proof-facing fields private behind explicit accessors, and that
  Lean keeps the exact schedule, exact entrypoint, lowering, and to-runtime
  soundness theorems for them
- the direct runtime witness/export bridge is pinned too:
  `ExecutionTrace::materialize_runtime_trusted_kernel_bundle(...)`,
  `ExecutionTrace::runtime_trusted_kernel_bundle(...)`, and
  `ExecutionTrace::runtime_refinement_witness(...)` stay confined to
  `crates/uo-core/src/trace.rs`; the anti-drift report now also checks that
  `runtime/uo-evm/src/theorem.rs` stays the only production caller allowed to
  invoke the shared `ExecutionTrace::from_runtime_finalization_input(...)`
  route, that the lower-level
  `ExecutionTrace::from_runtime_trace_parts(...)` /
  `ExecutionTrace::materialize_runtime_trusted_kernel_bundle(...)` pair stays
  inside `uo-core`, that the only production assignment to the backing field
  stays inside the internal
  `ExecutionTrace::store_runtime_trusted_kernel_bundle(...)`, that the
  refinement export path reuses the trusted-kernel bundle rather than
  assembling a parallel witness path, that any stored trusted-kernel bundle is
  revalidated against the surrounding trace before export, that the theorem
  finalizer now feeds `ExecutionTrace` only the stored
  `RuntimeKernelFinishBundle` plus the theorem/public trace pieces and hidden
  ORAM witness slices rather than a separate raw witness pair, that
  `RuntimeExecutionTraceParts::new(...)` validates any supplied kernel /
  runtime-phase witness against that finish bundle and rejects drift
  immediately without repopulating the raw pair on the production path, that
  confidential `ExecutionTrace` JSON now omits the redundant
  `runtime_kernel_witness` / `runtime_kernel_refinement_witness` keys when the
  finish bundle is present and `runtime_boundary_validation.json` now
  benchmark-checks that omission directly, that the public trace surface now
  keeps both the exported trusted-kernel bundle and the exported
  `RuntimeKernelFinishBundle` move-only rather than `Clone`,
  that the theorem-facing public trace slices now also stay boxed end-to-end,
  with `RuntimeCallOutcome`, `RuntimePublicCallTraceBundle`,
  `RuntimeExecutionTraceFinalizationInput`, `RuntimeExecutionTraceParts`,
  `RefinementTrace`, and the exported `ExecutionTrace` all carrying opcode,
  logical-access, logical-write, and physical-access slices through boxed
  fixed-shape buffers rather than growable vectors,
  that the direct confidential-core witness / slot / lowering bundles are now
  move-only as well and `kernel_model_alignment_validation.json` pins that
  smaller theorem-artifact surface explicitly,
  that the public trace surface now
  routes the artifact-checked confidential-core kernel-finish slot bundle back
  out through a checked shell-boundary accessor instead of a raw witness-pair
  helper,
  exports the finish boundary only through
  `ExecutionTrace::exact_runtime_kernel_finish_bundle(...)`, that the old raw
  stored trusted-kernel / controller accessors plus the raw ORAM object / leaf
  / position-map / after-counter accessors have been removed from the public
  trace API, and that Lean keeps the imported
  runtime-refinement / trusted-kernel proof-grade exactness and
  paper-observer projection theorems aligned with those finish-bundle-first
  exports; the smaller confidential-core kernel-finish slot artifact now also
  projects back to one valid native `RuntimeKernelInterfaceBundle` and one
  valid native `RuntimeShellBoundaryBundle` through the shared native
  `RuntimeKernelFinishSlotBoundary` theorems rather than through checker-local
  reconstruction
- the hidden traced-call witness staging objects in `state.rs` now also wipe
  their access-counter and position-map vectors on drop unless the theorem
  finalizer explicitly consumes them
- the confidential-path shared-kernel entrypoints that shadow-load
  committed state, run confidential calls, and commit public shadows are now
  also visibility-restricted to `crate::runtime`, so the generic shell cannot
  call those kernel hooks directly
- `engine.rs` now delegates public execution to `runtime/uo-evm/src/shell.rs`
  and confidential execution to `runtime/uo-evm/src/state.rs`; confidential
  manifest-to-kernel planning is now fully internal to `ContractRuntime`, so
  the engine no longer stages a `ConfidentialEntrypointPlan`, imports either
  the shared `RuntimeKernelMachine` or the public kernel facade directly, or
  threads the allocator/kernel-budget/hash-budget/commit-budget setup itself.
  The old
  runtime-local plan wrapper inside `state.rs` is now gone too: that module
  consumes one shared `uo-core`
  `RuntimeConfidentialEntrypointPlan` produced by
  `EntrypointManifest::runtime_confidential_entrypoint_plan(...)`, so the
  admitted confidential slot program, exact public object universe, and the
  public runtime budgets all come from one shared admission object rather than
  local manifest repacking, and that public object universe now crosses the
  runtime boundary as boxed object-id slices from the committed object table
  through the shared plan and into the public shell/bootstrap path; the only
  `Vec` construction is the public-size collection step that builds that boxed
  slice. The theorem-side
  theorem-side `begin_call_trace` path now triggers that runtime preflight
  instead, and the runtime now validates the slot program against the stored
  `manifest.kernel_steps` once but then carries the checked slot program
  itself forward; downstream consumers read the canonical schedule through
  `EntrypointManifest::canonical_kernel_step_manifest()`, which derives from
  the slot program when present and falls back to the stored field only when
  no confidential slot program exists, so both the public kernel-step witness
  list and the confidential shadow-load object set now come from that
  canonical DSL object at the runtime boundary instead of from ad hoc
  duplicate schedule reads, with `PublicRuntimeKernel::begin(...)` now taking
  only the allocator plan plus the public object universe, and with
  `run_confidential_call(...)` binding the admitted runtime schedule from the
  canonical slot DSL program itself, while `PublicRuntimeKernel::begin(...)`
  also internalizes the exact public object universe (`expected_public_object_ids =
  public_object_ids`) instead of making callers pass both copies
- confidential `Expr::Select` now also evaluates both admitted pure arms and
  combines them with `Value::confidential_select` instead of branching on the
  secret condition in Rust, while the proof-grade translation checker, the
  confidential-fragment validation report, and the proof-grade
  kernel-witness validator reject confidential select arms outside that
  branchless pure fragment
- confidential `Expr::StructField` and `Expr::ArrayIndex` are now both
  rejected from the admitted confidential fragment entirely
- `confidential_fragment_validation.json` now scans the admitted UO benchmark
  artifacts directly and confirms that their confidential entrypoints contain
  no non-branchless select arms, no confidential `StructField`, and no
  confidential `ArrayIndex`
- `kernel_dsl_validation.json` now checks the shared DSL/interpreter bridge
  directly: the probe serializes the exact lowered confidential-kernel program
  that the runtime executes, Lean re-derives its small-kernel schedule, and
  the proof-grade runtime kernel witness must match that schedule exactly
- `kernel_slot_dsl_validation.json` now checks the fixed-slot confidential
  program that the concrete runtime executes against that same proof-grade
  kernel witness, and `kernel_lowering_validation.json` checks the canonical
  lowering from the named DSL to the slot DSL against that same exported
  witness
- `confidential_core_validation.json` now runs the combined Lean checker over
  each representative proof-grade runtime witness together with the exact
  manifest-carried named confidential program for the invoked entrypoint, so the
  shell-refinement theorem is tied to the same DSL body that the runtime
  actually executes; the artifact-derived confidential-fragment witness
  remains in the report as a separate diagnostic summary over the admitted
  fragment, the new `kernel_interface_validation.json` report runs those same
  representative runtime runs through
  `checkProofGradeRuntimeKernelInterfaceBundle` over the explicit exported
  `RuntimeKernelInterfaceBundle`, `kernel_interface_singleton_boundary_validation.json`
  now rechecks that same accepted runtime-witness JSON directly through
  `checkProofGradeRuntimeKernelInterface` so the exact witness-to-singleton
  `PaperMainRuntimeKernelBoundaryAt` route is benchmark-backed on its own,
  `kernel_interface_confinement_boundary_validation.json` now rechecks that
  same accepted runtime-witness JSON directly through
  `checkProofGradeRuntimeKernelInterfaceConfinementBoundary` so the
  witness-fed `RuntimeKernelConfinementBoundary` route is benchmark-backed
  separately from the exported-bundle confinement checker,
  and the confidential-core checker now consumes one serialized
  confidential-core bundle, while the new
  `confidential_proof_family_validation.json` report serializes the whole
  shared `RuntimeConfidentialProofBundleFamily` and checks the direct kernel
  DSL / slot DSL / lowering / trusted-kernel / confidential-core / paper-main
  bundle family as one theorem-facing artifact
- `confidential_core_slot_validation.json` ties that same proof-grade
  runtime/refinement guarantee directly to the fixed-slot confidential
  program that the concrete runtime executes, while
  `confidential_core_shell_boundary_slot_validation.json` lifts that slot-only
  path across the explicit shell-boundary bundle so the runtime witness,
  shell-boundary bundle, and exact slot schedule are checked together against
  one shared proof-grade kernel witness and runtime phase witness, while
  `confidential_core_lowering_validation.json` composes the named and slot
  DSL objects and checks their canonical lowering against the same exported
  witness
- `confidential_core_shell_boundary_lowering_validation.json` then closes the
  full shared-DSL/shell-boundary loop: the runtime witness, the explicit
  shell-boundary bundle, and the named/slot confidential programs are checked
  together, and Lean proves that they all share one exact proof-grade kernel
  witness and one exact runtime phase witness rather than being accepted only
  as separate artifacts; the native theorem route now also packages that
  joined story as one explicit `RuntimeKernelConfinementBoundary`, so the
  paper-facing runtime boundary projects not only to the exact
  `RuntimeKernelRefinementBoundary` but also to one formal shell-confinement
  object over the same accepted kernel/runtime witnesses
- the dedicated paper-main family / slot-family boundary checkers and the
  shared confidential proof-family boundary / slot-boundary checkers now all
  compile those imported artifact routes through that same explicit
  `RuntimeKernelConfinementBoundary`, so the anti-drift layer no longer stops
  at the older singleton `PaperMainRuntimeKernelBoundaryAt` /
  `PaperMainRuntimeKernelSlotBoundaryAt` objects alone
- the proof-grade runtime witness path still has the dedicated executable
  theorem-surface checker, `checkProofGradeRuntimeKernelInterface`, which
  accepts the same runtime witness JSON as `checkProofGradeRuntimeWitness`,
  now also discharges the exact singleton
  `PaperMainRuntimeKernelBoundaryAt` boundary for that same accepted witness
  through the generic `RuntimeProofGradeKernelInterfaceBundle` route, and the
  explicit theorem object now also has
  `checkProofGradeRuntimeKernelInterfaceBundle`, which accepts the exported
  `RuntimeKernelInterfaceBundle` and names the exact shell-boundary /
  kernel-state interface facts that the paper argument consumes; the same
  exported bundle route now also has
  `checkProofGradeRuntimeKernelConfinementBoundary`, which accepts one
  `RuntimeKernelInterfaceBundle` and checks the exact
  `RuntimeKernelConfinementBoundary` directly on benchmark-backed runtime
  artifacts, and the
  stronger confidential-core composite route now also has
  `checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot`, which accepts
  the exported `RuntimeConfidentialCoreKernelInterfaceSlotBundle` and checks
  that the fixed confidential slot program agrees with the same accepted
  runtime witness and explicit kernel-interface bundle; the seeded
  paper-route artifact path now also has
  `checkProofGradeRuntimePaperMainFamilyBundle`, which accepts the exported
  `SeededRuntimePaperMainFamilyBundle` and names the exact paper-route public
  outcome / boundary schedule that the stronger theorem route consumes, and
  `checkProofGradeRuntimePaperMainSlotFamilyBundle`, which accepts the
  exported `SeededRuntimePaperMainSlotFamilyBundle` and names those same
  paper-route facts together with one exact confidential slot program
- the theorem side now also mirrors those exported artifacts directly:
  `RuntimeShellBoundaryBundle`, `RuntimeShellBoundarySlotBundle`,
  `RuntimeShellBoundaryLoweringBundle`,
  `RuntimeConfidentialCoreBundle`, `RuntimeConfidentialCoreSlotBundle`,
  `RuntimeConfidentialCoreKernelInterfaceSlotBundle`,
  `RuntimeConfidentialCoreShellBoundarySlotBundle`,
  `RuntimeConfidentialCoreLoweringBundle`, and
  `RuntimeConfidentialCoreShellBoundaryLoweringBundle` are now first-class
  runtime theorem objects with `Valid` predicates, so the imported JSON
  bridge lands on an explicit runtime proof interface rather than stopping at
  importer-local checker statements
- the probe now also checks the Rust/Lean kernel ABI vocabulary directly:
  `kernel_model_alignment_validation.json` reads the Rust opcode/witness enum
  definitions, the Rust confidential-kernel DSL enums, and the Lean
  runtime-refinement / runtime-kernel-DSL vocabulary lists and rejects drift
  in opcode names, confidential DSL kind tags and struct field names,
  runtime shell-contract / shell-trace / shell-boundary /
  shell-boundary-lowering field names, resource-event kinds,
  scratch-region names, or refinement-event kinds
- the boundary report now also checks constructor authority for those runtime
  witnesses directly: production `RuntimeKernelRefinementEventWitness`
  construction is restricted to `runtime/uo-kernel-runtime/src/lib.rs` and
  `runtime/uo-evm/src/state.rs`, while production
  `RuntimeKernelResourceEventWitness` construction is restricted to
  `runtime/uo-allocator/src/lib.rs`
- that same boundary report now also checks finer internal helper authority
  inside the shared `crate::runtime` module: the secret-bearing
  `RuntimeObject` reopen / commit / cold-store / witness-export / fresh-coin
  helper calls must stay in `runtime/uo-evm/src/state.rs`, the shadow-state
  helpers that reopen committed state, install fresh coins, and reconcile
  committed shadows must be called only from `runtime/uo-evm/src/state.rs`,
  the public shadow-load / public-commit / confidential-execution shared-kernel
  hooks `shadow_load_with`, `commit_objects`, and `run_confidential_call`
  must be invoked only from `runtime/uo-evm/src/state.rs`, without exposing
  raw `inner_mut` / `into_inner` escape hatches on a runtime-local public
  kernel facade, and the confidential shadow-load helper itself stays
  private to `runtime/uo-evm/src/state.rs`; the same source-level report now also pins
  the top-level `ContractRuntime` authority split, so only `shell.rs` may
  drive `prepare_public_shadow`, `commit_public_shadow`, and
  `replace_with_cold_public_shadow`, while only `engine.rs` may call
  `self.state.run_confidential_entrypoint(...)`
- the boundary report now also checks the low-level store helper layer:
  direct `StoreCipher::seal` / `StoreCipher::open` use must stay inside
  `runtime/uo-store/src/codec.rs`, the Lean-generated exact-size
  seal/open/filler surface in `runtime/uo-store/src/generated_surface.rs`,
  the Lean-generated boxed-filler /
  seal-into helper surface in
  `runtime/uo-store/src/generated_store_helpers.rs`, and the thin call-site
  shell in `runtime/uo-store/src/store.rs`; public store evidence buffers now
  appear in that handwritten shell only as generated
  `StorePhysicalWriteTrace` / `StoreLogicalEventTrace` wrappers rather than raw
  `Vec<PhysicalWriteEvent>` / `Vec<LogicalEvent>` fields, and those generated
  wrappers now use exact boxed-slice backing with fallible fixed-builder
  appends rather than `Vec` storage; the public wipe-preserving helper
  surface must stay at `seal_and_wipe_boxed` /
  `seal_and_wipe_into_slice` / `filler_boxed` /
  `with_opened_payload`, the store write API must take mutable plaintext
  buffers, `StoreCipher` must zeroize its key on drop, and the internal
  nonzero transport plus sealed-payload encode/decode path must stay on
  exact-size boxed buffers and in-place AEAD helpers without `expect`,
  `unwrap`, or `panic!` rather than regressing to growable transport vectors;
  public-size `Vec` construction is allowed only inside the generated helper
  shells where it immediately becomes a boxed slice and is source-pinned
- the allocator side of the same boundary now also avoids panic-style
  resource-event finalization: `ResourceEventLog::into_events(...)` checks
  public length/capacity and every populated public-prefix entry before
  producing boxed finish telemetry instead of relying on
  `expect("resource event prefix is populated")`; it now also uses checked
  slot access before taking each event, and tamper validation rejects the stale
  `self.events[index].take()` extraction shape
- the same source-backed boundary now also checks the whole production
  `RuntimeImplementationInterface` for absence of `expect(`, `unwrap(`, and
  `panic!`; this includes the shared `uo-core` trace/types layer, whose
  proof-object JSON and trace-hash APIs are now fallible and whose aggregate
  canonical value encoding uses 64-bit length prefixes rather than panicking on
  `u32` conversion
- the probe-side production-source scan now strips `#[cfg(test)]` items
  without truncating the rest of the file, so those confinement checks cover
  production helpers that appear after mid-file test-only utilities rather
  than silently stopping at the first test block
- the same boundary report now also rejects regressions back to unbounded
  runtime witness buffers: the production path must keep its emitted
  kernel-step witness and lower-level runtime phase witness inside the shared
  `uo-core` `BoundedJournal` wrapper with bounds derived from public
  kernel-op/object counts, reject the old tracker-side `Vec` fields, reject
  the stale `BoundedJournal` `Vec` snapshot bounce and direct-index writes, and
  keep the remaining public shell-side commit / witness helper lists on
  explicit `Vec::with_capacity(...)` allocations rather than `Vec::new()`
- the shared `uo-core` schedule/refinement layer now also stays exact-size all
  the way down: `ConfidentialKernelProgram::expected_runtime_steps`,
  `ConfidentialKernelSlotProgram::expected_runtime_steps`, and the shared
  expression/statement step projections now return boxed fixed-shape buffers,
  while `RuntimeKernelFinishBundle::completed_runtime_phase_events` and
  `RuntimeKernelRefinementWitness::from_events` now meet on boxed refinement
  event slices instead of reopening that finish/refinement boundary through a
  temporary `Vec<RuntimeKernelRefinementEventWitness>`; the same checked
  source boundary now keeps named/slot confidential-kernel program bodies and
  Keccak part lists boxed as fixed-shape slices and requires named-to-slot
  lowering to use `FixedBoxBuilder` rather than growable `Vec` collection
- that same boundary report now also rejects regressions back to mid-call
  Path-ORAM stash growth: the production ORAM path must derive one public
  `working_stash_capacity(...)` bound, rebuild stash buffers with that headroom
  up front, preserve it across cold commits with `.clear()`, and avoid the
  old late `reserve(...)` expansion path
- the same report now also rejects regressions back to capacity-dropping ORAM
  clone / refresh paths: `OramState` must use the manual capacity-preserving
  `Clone` implementation, and the storage-refresh path must decode metadata and
  rebuild entries into the existing public-capacity buffers rather than
  replacing them with fresh vectors
- that same boundary report now also requires touched Path-ORAM aborts to go
  through the in-place `restore_from_old(...)` helper and forbids regressions
  back to replacing the whole `OramState` with
  `old.oram.clone_for_tx(...)`
- the same report now also rejects regressions back to fresh-vector full-scan
  cold commits: array and small-map object cold commits must clear and resize
  their existing logical buffers in place rather than allocating replacement
  secret-bearing vectors
- that same boundary report now also rejects regressions back to replacement
  full-scan restore buffers and redundant untouched-commit ciphertext clones:
  production `objects.rs` must keep the in-place decode helpers for old-state
  restoration, route array/small-map restore through those helpers, and avoid
  the old `next.physical = old.physical.clone()` /
  `next.physical_slots = old.physical_slots.clone()` assignments
- that same boundary report now also rejects regressions back to object-store
  schedule leaks: production `oram.rs` must keep fixed-public-batch ORAM write
  evidence, production `objects.rs` must keep UO small-map lookup as a masked
  full scan, and UO array access must keep masked full-scan read/write behavior
  without direct secret-indexing or a UO-path out-of-range public branch
- the direct machine-confinement report now also exposes the tightened
  handwritten ORAM write-batch consumer cut: object/commit code must enumerate
  fixed-public-batch write evidence through
  `OramWriteBatch::for_each_write(...)`, which checks public length/capacity and
  populated public-prefix entries, and the source-backed boundary rejects the
  older lossy `filter_map(Option::as_ref)` iterator path; the same focused
  report marks production handwritten `engine.rs` / `shell.rs` / `state.rs` /
  `objects.rs` / `oram.rs` as free of `expect(`, `unwrap(`, and `panic!` after
  test-only code is stripped
- that same boundary report now also rejects regressions back to a
  string-keyed confidential runtime environment: the production shell must
  load the checked manifest's `confidential_slot_program` through the shared
  `uo-core` admission helper rather than revalidating that match in
  `state.rs`, the production kernel must execute slot-based statements /
  expressions, and the confidential execution state must stay as a fixed slot
  vector rather than
  `BTreeMap<String, Value>`
- the proof-grade translation checker now also requires every confidential
  function to carry the same canonical named and slot DSL that the manifest
  carries, and it rejects any mismatch between the exact function-body
  lowering, the stored function-level DSL, and the stored manifest-level DSL,
  so the proof-grade path no longer depends on reconstructing only a public
  schedule when the full DSL program is already available; the same checker
  now also rejects any confidential kernel-step target that resolves to a raw
  or unknown state object, and the paper-facing Lean facade exports that
  non-raw target fact as a theorem
- the runtime-boundary report now also checks that the production confidential
  object API surface is routed only through `runtime/uo-evm/src/state.rs`:
  all direct `.get_cell`, `.set_cell`, `.get_array`, `.set_array`, `.get_map`,
  and `.put_map` call sites must stay inside the runtime state module, while the
  remaining runtime state surface is constrained to the committed-state
  wrapper and the fixed-slot kernel execution state; the report now also pins
  the private shared shadow-state traits in `uo-kernel-runtime` plus their
  `state.rs` implementations so the public and confidential paths keep
  sharing one internal object-operation helper stack
  rather than drifting back into duplicated kernel code
- the probe-side kernel witness summaries now expose the emitted
  `resource_events` trace together with the emitted and expected public object
  universe plus the kernel-step public object schedule, so the artifact
  evidence mirrors that theorem boundary rather than
  hiding it behind counts only
- the proof-grade translation checker now also rejects confidential `Select`
  arms that either contain storage-visible accesses or fall outside the
  admitted branchless pure fragment, because the confidential runtime now
  evaluates both arms and then performs a branchless data-level selection
- the proof-grade translation checker now also rejects confidential
  `StructField` and confidential `ArrayIndex` outright, because the current
  malicious-host hardening story does not carry a proof-grade runtime account
  for those projection forms in the admitted confidential fragment

This is the first point at which `uo-allocator` and `uo-precompiles` are real
enforcement surfaces rather than dead stubs, and the first point at which the
kernel discipline is exported as an explicit runtime artifact.

### Out-of-charter future strengthening

The WP3 / WP6 charters explicitly do not require a deeper
semantics-of-Rust refinement of the residual real kernel
implementation surface, a global runtime buffer-scrub theorem, an
operational semantics for every live plaintext buffer inside
in-call object state, or a Lean proof of the kernel implementation
itself. Those tracks are outside the closed WP3 / WP6 charters and are
not recorded as in-scope tasks in this document.

## Guardrails

These guardrails define the closed WP6 surface and should remain true for
future maintenance.

### 1. Keep the kernel ABI small and auditable

Status: completed on April 19, 2026 for the current confidential kernel ABI.

The confidential operation vocabulary should stay limited to:

- `Begin`
- `CellGet` / `CellSet`
- `ArrayGet` / `ArraySet`
- `MapGet` / `MapPut`
- `Commit`
- `Wipe`

Adding more host-visible power to the kernel should require an explicit
observer argument.

### 2. Keep per-entrypoint working state bounded

Status: completed under WP3 closure. The current source-backed
`RuntimeImplementationInterface` checker pins the per-entrypoint
working-state discipline:

- fixed-capacity kernel op journal (`BoundedJournal<T>` in `uo-core`)
- bounded scratch regions for key/value/hash staging
- explicit bounded `io` scratch for confidential storage payload staging
- manifest-derived stack/work budgets
- streamed canonical hashing for confidential `keccak256`
- wipe-on-seal handling for confidential object/ORAM plaintext payload buffers
- wipe-after-parse handling for ORAM metadata and bucket plaintext payloads

The `tamper_validation` suite rejects representative reintroduction of
secret-dependent growth through helper paths outside the kernel.

### 3. Export a checkable kernel-discipline witness

Status: completed on April 19, 2026.

The runtime now emits a compact witness stating:

- which kernel ABI was used
- the canonical confidential named and slot kernel programs for the admitted
  entrypoint
- the exact public kernel-step trace `{ opcode, object_id? }` derived from the
  stored slot program
- the exact public resource-event trace used to justify stack/scratch usage
- that scratch regions stayed within the admitted public bounds
- that wipe obligations were discharged

That witness is now in the proof-facing boundary:

- `uo-evm --format kernel-witness` exposes it directly
- `checkProofGradeRuntimeKernelWitness` validates it directly in Lean
- `uo-evm --format kernel-refinement-witness` now also exposes the lower-level
  runtime phase witness directly, and
  `checkProofGradeRuntimeKernelRefinementWitness` validates that artifact
  against the exported proof-grade kernel witness
- `uo-evm --format shell-boundary` and
  `uo-evm --format shell-boundary-lowering` now expose the public-only shell
  contract/trace witness and its shared-DSL lowering bridge directly, instead
  of leaving those proof objects probe-only
- `uo-evm --format confidential-core-kernel-interface-slot`,
  `confidential-core-shell-boundary-lowering`,
  `paper-main-family`, and `paper-main-slot-family` now also expose the
  stronger confidential-core/kernel-interface composite and both paper-route
  family objects directly from runtime traces, so offline validation no longer
  has to rebuild those proof interfaces from lower-level pieces
- `results/kernel_refinement_validation.json` now validates that same
  lower-level runtime phase witness directly on the benchmark-backed proof
  scenarios rather than only through the larger refinement-witness report
- the exported trusted-kernel bundle and refinement witness both carry it
- the Lean imported validators check that it matches the observed entrypoint,
  stays within public scratch/stack bounds, uses the admitted opcode
  vocabulary, has the expected `Begin` / `Commit` / `Wipe` envelope, and
  carries the exact admitted public kernel-step skeleton for proof-grade
  confidential calls, and now also that this public schedule replays to a
  finished small-kernel state under the modeled semantics while the emitted
  public resource-event trace replays to the exact claimed stack/scratch
  summary
- the runtime-side commit-object and cold-store/post-committed witness tails
  are now also routed through shared phase-aware helper methods rather than
  open-coded raw event-vector extension in the runtime modules

### 4. Connect the real runtime to the SGX observer by refinement

Status: addressed by W6.3 (controller-refinement integration) and
W6.4 (sealing / storage-refinement integration). The canonical Lean
controller-shape constructor refines the W6.1 / W6.2 frozen
observer in four structural senses, the `viewTEEStore` projection
forwards every storage-relevant field deterministically, and the
runtime side is pinned by the matched probe drift checks
`sgx_controller_refinement_pinned` and
`sgx_storage_refinement_pinned`. The link from the real Rust
runtime to the canonical Lean constructor goes through the
source-pinned drift checks rather than a full semantics-of-Rust
proof; that deeper proof remains a separate track outside the WP6
charter scope.

### 5. Upgrade the claim boundary only after the runtime path is closed

Status: addressed by the WP6 closure. The claim boundary has been
upgraded to the W6.1 / W6.2 frozen observer paired with the W6.5
explicit deployment-assumption bundle. The runtime kernel
discipline is explicit and checkable (WP3); the enclave controller
/ boundary / admitted micro observer are tied to the source-pinned
implementation by the W6.3 / W6.4 refinement integrations; the
remaining trusted Rust surface is bounded by the W6.5 deployment-
assumption bundle paired with Intel SGX provenance citations.

## Relationship To Existing Proof Artifacts

This track has been integrated additively into the existing controller
/ trusted-kernel / refinement-witness path. The repository now:

1. keeps the Lean-checked theorem boundary at the W6.1 / W6.2
   frozen observer surface
2. has a tiny trusted runtime interior; behavior is routed through
   the small kernel and the source-backed
   `RuntimeImplementationInterface` chain (WP3)
3. exports evidence for that kernel discipline as the
   `RuntimeKernelMachineFinishWitness` and the full
   `RuntimeImplementation*Boundary` family
4. ties the real runtime to the modeled observer via the W6.3
   controller-refinement and W6.4 storage-refinement integrations
   under the static-drift checks
   `sgx_controller_refinement_pinned` and
   `sgx_storage_refinement_pinned`
