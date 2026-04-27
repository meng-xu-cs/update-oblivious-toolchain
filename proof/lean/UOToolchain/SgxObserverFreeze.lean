import UOToolchain.SgxBoundary
import UOToolchain.SgxRelation
import UOToolchain.SgxController
import UOToolchain.SgxControllerTrace
import UOToolchain.SgxMicroModel

namespace UOToolchain

/-! ### W6.1: Hostile-host SGX observer surface freeze

The paper-facing SGX observer surface is shared across three artifacts:

- the Lean models in `SgxBoundary.lean` / `SgxRelation.lean` /
  `SgxController.lean` / `SgxControllerTrace.lean` / `SgxMicroModel.lean`,
- the Rust controller recorder in `runtime/uo-evm/src/controller.rs`,
- the Rust public-trace projection in `crates/uo-core/src/trace.rs`.

Every paper claim about hostile-host SGX execution obliviousness goes
through this observer surface. Drift between Lean and Rust silently
weakens the claim, so this module pins the surface as a frozen
**observer provenance** record paired with named probe drift checks,
mirroring the W5.3 / W5.4 provenance pattern.

The freeze covers five components:

1. **Page-region vocabulary**: the four region kinds
   (`metadata`, `position_map`, `path`, `stash`) that
   `controllerPageTraceRegionsOfLeakage` enumerates and that
   `runtime/uo-evm/src/controller.rs` records on every ORAM access.
2. **Controller-phase vocabulary**: the ten phases enumerated by
   `SGXControllerPhase`, matching the `ControllerPhase` Rust enum.
3. **Page-event vocabulary**: the two `PageEventKind` constructors
   (`faultIn`, `evictOut`).
4. **Exit-event vocabulary**: the three `ExitEvent` constructors
   (`interruptExit`, `resume`, `terminate`).
5. **Shared-resource pattern literal**: the public string
   `"shared_resource_tick"` used by both
   `controllerSharedResourcePatternOfShape` (Lean) and
   `SgxControllerShapeTrace::normalized_micro_trace` (Rust).

Claim taxonomy: this freeze is **Lean-proved, semantics-preserving**
in the W6.1 sense: the Lean side carries explicit equalities pinning
each component to its canonical value, and the runtime side is
pinned by the probe's `sgx_observer_surface_pinned` static-drift
check. The freeze does not by itself discharge any deployment
assumption; it locks the boundary-observer signature so that the
W6.2 / W6.3 / W6.4 refinements have a stable target. -/

/-! #### Page-region vocabulary -/

/-- Frozen list of the four SGX observer page-region names. The
canonical order is metadata → position_map → path → stash. -/
def sgxObserverPageRegionNames : List String :=
  ["metadata", "position_map", "path", "stash"]

@[simp] theorem sgxObserverPageRegionNames_length :
    sgxObserverPageRegionNames.length = 4 := by rfl

theorem sgxObserverPageRegionNames_value :
    sgxObserverPageRegionNames =
      ["metadata", "position_map", "path", "stash"] := by rfl

/-- The page-region names produced by
`controllerPageTraceRegionsOfLeakage` are exactly the frozen
`sgxObserverPageRegionNames`, regardless of which leakage list is
supplied. This pins the canonical ordering. -/
theorem controllerPageTraceRegionsOfLeakage_pageKinds
    (leakage : List OramAccessLeakage) :
    (controllerPageTraceRegionsOfLeakage leakage).map
        (fun region => region.pageKind) =
      sgxObserverPageRegionNames := by
  rfl

/-- The workset page-region names produced by
`controllerWorksetRegionsOfLeakage` are also exactly the frozen
`sgxObserverPageRegionNames`. -/
theorem controllerWorksetRegionsOfLeakage_pageKinds
    (leakage : List OramAccessLeakage) :
    (controllerWorksetRegionsOfLeakage leakage).map
        (fun region => region.pageKind) =
      sgxObserverPageRegionNames := by
  rfl

/-! #### Controller-phase vocabulary -/

/-- Frozen list of the ten SGX controller phases. The canonical order
is the order in which `SGXControllerPhase` is declared, and matches
the Rust `ControllerPhase` enum's variant order. -/
def sgxObserverControllerPhases : List SGXControllerPhase :=
  [ SGXControllerPhase.enclaveEnter
  , SGXControllerPhase.stageRequest
  , SGXControllerPhase.descendPositionMap
  , SGXControllerPhase.loadMetadata
  , SGXControllerPhase.fetchPath
  , SGXControllerPhase.scanStash
  , SGXControllerPhase.rewritePath
  , SGXControllerPhase.ascendPositionMap
  , SGXControllerPhase.sealPersistentState
  , SGXControllerPhase.enclaveExit
  ]

@[simp] theorem sgxObserverControllerPhases_length :
    sgxObserverControllerPhases.length = 10 := by rfl

/-- Frozen list of controller-phase observer names exposed at the
public boundary. The names use camelCase to match the Lean
`SGXControllerPhase` constructors; the Rust enum uses PascalCase but
Serde renames are kept structurally aligned by the
`kernel_model_alignment_validation` route. -/
def sgxObserverControllerPhaseNames : List String :=
  [ "enclaveEnter"
  , "stageRequest"
  , "descendPositionMap"
  , "loadMetadata"
  , "fetchPath"
  , "scanStash"
  , "rewritePath"
  , "ascendPositionMap"
  , "sealPersistentState"
  , "enclaveExit"
  ]

@[simp] theorem sgxObserverControllerPhaseNames_length :
    sgxObserverControllerPhaseNames.length = 10 := by rfl

/-! #### Page-event vocabulary -/

/-- Frozen list of the two SGX page-event kinds, in canonical order. -/
def sgxObserverPageEventKinds : List PageEventKind :=
  [PageEventKind.faultIn, PageEventKind.evictOut]

@[simp] theorem sgxObserverPageEventKinds_length :
    sgxObserverPageEventKinds.length = 2 := by rfl

/-- Frozen list of public-facing names for the two page-event kinds. -/
def sgxObserverPageEventKindNames : List String :=
  ["faultIn", "evictOut"]

@[simp] theorem sgxObserverPageEventKindNames_length :
    sgxObserverPageEventKindNames.length = 2 := by rfl

/-! #### Exit-event vocabulary -/

/-- Frozen list of the three SGX exit-event kinds, in canonical
order. -/
def sgxObserverExitEvents : List ExitEvent :=
  [ExitEvent.interruptExit, ExitEvent.resume, ExitEvent.terminate]

@[simp] theorem sgxObserverExitEvents_length :
    sgxObserverExitEvents.length = 3 := by rfl

/-- Frozen list of public-facing names for the three exit-event
kinds. -/
def sgxObserverExitEventNames : List String :=
  ["interruptExit", "resume", "terminate"]

@[simp] theorem sgxObserverExitEventNames_length :
    sgxObserverExitEventNames.length = 3 := by rfl

/-! #### Shared-resource pattern literal -/

/-- Frozen public string literal used by both
`controllerSharedResourcePatternOfShape` (Lean) and
`SgxControllerShapeTrace::normalized_micro_trace` (Rust) to fill the
shared-resource pattern budget with deterministic public ticks. -/
def sgxObserverSharedResourceTick : String := "shared_resource_tick"

theorem sgxObserverSharedResourceTick_value :
    sgxObserverSharedResourceTick = "shared_resource_tick" := by rfl

/-- The shared-resource pattern produced by
`controllerSharedResourcePatternOfShape` is a list of the frozen
`sgxObserverSharedResourceTick` literal, repeated `shape.sharedResourceBudget`
times. This pins the canonical literal as the only string the Lean
controller projects under that budget. -/
theorem controllerSharedResourcePatternOfShape_value
    (shape : SGXControllerShape) :
    controllerSharedResourcePatternOfShape shape =
      List.replicate shape.sharedResourceBudget
        sgxObserverSharedResourceTick := by
  rfl

/-! #### Page-event encoding formula -/

/-- The Lean page-event encoding `controllerPageEventOfIndex` uses the
`index / 2` page-id rule and the `index % 2 = 0` parity rule for
fault-in / evict-out alternation. This theorem states that fact at
the type level so refinements may rely on it without unfolding. -/
theorem controllerPageEventOfIndex_pageId
    (pageKind : String) (index : Nat) :
    (controllerPageEventOfIndex pageKind index).pageId = index / 2 := by
  rfl

/-- Even-indexed events are `faultIn`; odd-indexed events are
`evictOut`. This pins the alternation pattern at the Lean level. -/
theorem controllerPageEventOfIndex_kind_even
    (pageKind : String) (index : Nat)
    (hEven : index % 2 = 0) :
    (controllerPageEventOfIndex pageKind index).kind =
      PageEventKind.faultIn := by
  simp [controllerPageEventOfIndex, hEven]

theorem controllerPageEventOfIndex_kind_odd
    (pageKind : String) (index : Nat)
    (hOdd : index % 2 = 1) :
    (controllerPageEventOfIndex pageKind index).kind =
      PageEventKind.evictOut := by
  simp [controllerPageEventOfIndex, hOdd]

/-! #### Observer-surface provenance record -/

/-- Frozen observer-surface provenance record. Pairs each pinned
component with a structured record so the paper claim, the Lean
formalization, and the Rust runtime all reference one observer
signature. The provenance entries are metadata-only: the Lean
theorems above carry the actual equalities, and the probe's
`sgx_observer_surface_pinned` static-drift check carries the runtime
side. -/
structure SgxObserverSurfaceProvenance where
  /-- The four canonical page-region names. -/
  pageRegionNames : List String
  /-- The ten canonical controller-phase names. -/
  controllerPhaseNames : List String
  /-- The two canonical page-event-kind names. -/
  pageEventKindNames : List String
  /-- The three canonical exit-event-kind names. -/
  exitEventKindNames : List String
  /-- The public shared-resource-pattern literal. -/
  sharedResourceTick : String
  /-- Documentation anchor for the WP6 hardening track. -/
  observerDocSection : String
  /-- Probe static-drift check that pins the Rust observer surface. -/
  staticDriftCheckName : String
  /-- File path anchoring the Lean controller-phase enumeration. -/
  leanRelationModule : String
  /-- File path anchoring the Lean controller-trace constructor. -/
  leanControllerTraceModule : String
  /-- File path anchoring the Rust runtime controller recorder. -/
  rustControllerModule : String
  /-- File path anchoring the Rust public-trace projection. -/
  rustTraceModule : String
deriving Repr, DecidableEq

/-- The actual W6.1 observer-surface provenance record. -/
def sgxObserverSurfaceProvenance : SgxObserverSurfaceProvenance :=
  { pageRegionNames := sgxObserverPageRegionNames
  , controllerPhaseNames := sgxObserverControllerPhaseNames
  , pageEventKindNames := sgxObserverPageEventKindNames
  , exitEventKindNames := sgxObserverExitEventNames
  , sharedResourceTick := sgxObserverSharedResourceTick
  , observerDocSection :=
      "docs/tee-runtime-hardening.md \"W6.1 Frozen SGX Observer Surface\""
  , staticDriftCheckName := "sgx_observer_surface_pinned"
  , leanRelationModule := "proof/lean/UOToolchain/SgxRelation.lean"
  , leanControllerTraceModule := "proof/lean/UOToolchain/SgxControllerTrace.lean"
  , rustControllerModule := "runtime/uo-evm/src/controller.rs"
  , rustTraceModule := "crates/uo-core/src/trace.rs"
  }

/-- The provenance record's pinned page-region names match the frozen
`sgxObserverPageRegionNames` list. -/
theorem sgxObserverSurfaceProvenance_pageRegionNames :
    sgxObserverSurfaceProvenance.pageRegionNames =
      sgxObserverPageRegionNames := by rfl

/-- The provenance record's pinned controller-phase names match the
frozen `sgxObserverControllerPhaseNames` list. -/
theorem sgxObserverSurfaceProvenance_controllerPhaseNames :
    sgxObserverSurfaceProvenance.controllerPhaseNames =
      sgxObserverControllerPhaseNames := by rfl

/-- The provenance record's pinned page-event-kind names match the
frozen `sgxObserverPageEventKindNames` list. -/
theorem sgxObserverSurfaceProvenance_pageEventKindNames :
    sgxObserverSurfaceProvenance.pageEventKindNames =
      sgxObserverPageEventKindNames := by rfl

/-- The provenance record's pinned exit-event-kind names match the
frozen `sgxObserverExitEventNames` list. -/
theorem sgxObserverSurfaceProvenance_exitEventKindNames :
    sgxObserverSurfaceProvenance.exitEventKindNames =
      sgxObserverExitEventNames := by rfl

/-- The provenance record's pinned shared-resource tick matches the
frozen `sgxObserverSharedResourceTick` literal. -/
theorem sgxObserverSurfaceProvenance_sharedResourceTick :
    sgxObserverSurfaceProvenance.sharedResourceTick =
      sgxObserverSharedResourceTick := by rfl

/-- The provenance record references the
`sgx_observer_surface_pinned` probe static-drift check. This is the
named hook that rejects representative drift in the Rust observer
surface. -/
theorem sgxObserverSurfaceProvenance_staticDriftCheckName :
    sgxObserverSurfaceProvenance.staticDriftCheckName =
      "sgx_observer_surface_pinned" := by rfl

/-! ### W6.2 Boundary-Call Model

W6.2 models the enclave-boundary call schedule explicitly. The Lean
boundary observer (`SgxBoundary.lean`) carries the abstract
`BoundaryEvent` shape; W6.2 freezes the canonical structural
boundary-call model the runtime emits:

- **canonical inner API literal**: `"oram_access"` — the public API
  used to mark each ORAM-access ECALL/OCALL pair;
- **canonical boundary directions**: `enter` / `exit`;
- **canonical event budget formula**: `2 * total_oram_accesses + 2`,
  matching the
  `boundary_event_budget = 2 * (totalAccesses + 1)` formula in
  `controllerShape.boundaryEventBudget` (Lean) and the
  `boundary_event_budget: 2 * total_oram_accesses + 2` formula in
  `RuntimeControllerCertificate::controller_shape` (Rust);
- **canonical schedule shape**: a public-entrypoint enter/exit
  envelope wrapping `n` symmetric `oram_access` exit/enter pairs,
  matching the runtime's `RuntimeControllerCertificate::boundary_schedule`
  builder.

The runtime side is pinned by the probe's
`sgx_boundary_call_model_pinned` static-drift check. -/

/-- Frozen literal for the inner ORAM-access boundary API name. The
runtime uses this string for both the exit and the re-enter of every
ORAM access; the Lean controller-trace constructor and the Rust
controller recorder both stamp this exact literal. -/
def sgxObserverOramAccessApi : String := "oram_access"

theorem sgxObserverOramAccessApi_value :
    sgxObserverOramAccessApi = "oram_access" := by rfl

/-- Frozen list of the two `BoundaryDirection` constructors. -/
def sgxObserverBoundaryDirections : List BoundaryDirection :=
  [BoundaryDirection.enter, BoundaryDirection.exit]

@[simp] theorem sgxObserverBoundaryDirections_length :
    sgxObserverBoundaryDirections.length = 2 := by rfl

/-- Frozen list of public-facing names for the two boundary
directions. -/
def sgxObserverBoundaryDirectionNames : List String :=
  ["enter", "exit"]

@[simp] theorem sgxObserverBoundaryDirectionNames_length :
    sgxObserverBoundaryDirectionNames.length = 2 := by rfl

/-- Canonical boundary-event budget formula. The runtime emits one
ORAM-access exit/enter pair per access plus the outer
entrypoint enter/exit envelope: `budget = 2 * accesses + 2`. -/
def sgxObserverBoundaryEventBudget (totalAccesses : Nat) : Nat :=
  2 * totalAccesses + 2

theorem sgxObserverBoundaryEventBudget_eq_controllerShape
    (leakage : List OramAccessLeakage) :
    sgxObserverBoundaryEventBudget (totalOramAccesses leakage) =
      (sgxControllerShapeOfExecutionLeakage leakage).boundaryEventBudget := by
  unfold sgxObserverBoundaryEventBudget
  simp [sgxControllerShapeOfExecutionLeakage, Nat.mul_add]

/-- Canonical boundary-schedule builder. Given a public outer
entrypoint, an entry-input length, an output return length, and a
list of ORAM accesses, this builds the symmetric Enter/Exit
schedule the runtime emits. -/
def sgxObserverBoundarySchedule
    (entrypointId : String)
    (entryInputLen : Nat)
    (outputLen : Nat)
    (totalAccesses : Nat) : List BoundaryEvent :=
  [{ direction := BoundaryDirection.enter
   , apiId := entrypointId
   , inputLen := entryInputLen
   , outputLen := 0
   }] ++
  (List.range totalAccesses).flatMap (fun _ =>
    [ { direction := BoundaryDirection.exit
      , apiId := sgxObserverOramAccessApi
      , inputLen := 0
      , outputLen := 0
      }
    , { direction := BoundaryDirection.enter
      , apiId := sgxObserverOramAccessApi
      , inputLen := 0
      , outputLen := 0
      }
    ]) ++
  [{ direction := BoundaryDirection.exit
   , apiId := entrypointId
   , inputLen := 0
   , outputLen := outputLen
   }]

/-- The canonical boundary schedule has length exactly the canonical
`sgxObserverBoundaryEventBudget` for the supplied access count. -/
theorem sgxObserverBoundarySchedule_length
    (entrypointId : String)
    (entryInputLen : Nat)
    (outputLen : Nat)
    (totalAccesses : Nat) :
    (sgxObserverBoundarySchedule entrypointId entryInputLen
        outputLen totalAccesses).length =
      sgxObserverBoundaryEventBudget totalAccesses := by
  induction totalAccesses with
  | zero =>
      simp [sgxObserverBoundarySchedule, sgxObserverBoundaryEventBudget]
  | succ n ih =>
      simp [sgxObserverBoundarySchedule,
        sgxObserverBoundaryEventBudget,
        List.range_succ, List.flatMap_append] at ih ⊢
      omega

/-- The first event of the canonical schedule is the outer entrypoint
enter event, carrying the public entry-input length. -/
theorem sgxObserverBoundarySchedule_head
    (entrypointId : String)
    (entryInputLen : Nat)
    (outputLen : Nat)
    (totalAccesses : Nat) :
    (sgxObserverBoundarySchedule entrypointId entryInputLen
        outputLen totalAccesses).head?
      = some
        { direction := BoundaryDirection.enter
        , apiId := entrypointId
        , inputLen := entryInputLen
        , outputLen := 0
        } := by
  cases totalAccesses with
  | zero => simp [sgxObserverBoundarySchedule]
  | succ n => simp [sgxObserverBoundarySchedule]

/-- The schedule decomposes structurally as `<head>::<middle> ++
[<outer_exit>]`, so the last element is exactly the outer-exit
event. -/
theorem sgxObserverBoundarySchedule_eq_concat
    (entrypointId : String)
    (entryInputLen : Nat)
    (outputLen : Nat)
    (totalAccesses : Nat) :
    sgxObserverBoundarySchedule entrypointId entryInputLen
        outputLen totalAccesses =
      ({ direction := BoundaryDirection.enter
       , apiId := entrypointId
       , inputLen := entryInputLen
       , outputLen := 0
       } ::
        (List.range totalAccesses).flatMap (fun _ =>
          [ { direction := BoundaryDirection.exit
            , apiId := sgxObserverOramAccessApi
            , inputLen := 0
            , outputLen := 0
            }
          , { direction := BoundaryDirection.enter
            , apiId := sgxObserverOramAccessApi
            , inputLen := 0
            , outputLen := 0
            }
          ])) ++
        [{ direction := BoundaryDirection.exit
         , apiId := entrypointId
         , inputLen := 0
         , outputLen := outputLen
         }] := by
  rfl

/-- The last event of the canonical schedule is the outer entrypoint
exit event, carrying the public output return length. The schedule
is structurally `<prefix> ++ [outer_exit]`, so the last element is
fixed to the outer-exit event regardless of the access count. -/
theorem sgxObserverBoundarySchedule_getLast
    (entrypointId : String)
    (entryInputLen : Nat)
    (outputLen : Nat)
    (totalAccesses : Nat) :
    (sgxObserverBoundarySchedule entrypointId entryInputLen
        outputLen totalAccesses).getLast?
      = some
        { direction := BoundaryDirection.exit
        , apiId := entrypointId
        , inputLen := 0
        , outputLen := outputLen
        } := by
  rw [sgxObserverBoundarySchedule_eq_concat]
  exact List.getLast?_concat

/-! ### W6.2 boundary-call provenance record -/

/-- W6.2 frozen boundary-call provenance record. Pairs each
boundary-call component with the structural metadata so the paper
claim, the Lean formalization, and the Rust runtime all reference
one canonical boundary-call model. -/
structure SgxBoundaryCallProvenance where
  /-- The canonical inner ORAM-access API name literal. -/
  oramAccessApi : String
  /-- The two canonical boundary directions. -/
  boundaryDirectionNames : List String
  /-- Free-form description of the canonical boundary-event budget
  formula. -/
  boundaryEventBudgetFormula : String
  /-- Free-form description of the canonical boundary-schedule
  shape. -/
  boundaryScheduleShape : String
  /-- Documentation anchor for the WP6 hardening track. -/
  observerDocSection : String
  /-- Probe static-drift check that pins the Rust boundary-call
  surface. -/
  staticDriftCheckName : String
  /-- File path anchoring the Lean boundary-event model. -/
  leanBoundaryModule : String
  /-- File path anchoring the Lean boundary-schedule constructor. -/
  leanScheduleModule : String
  /-- File path anchoring the Rust runtime controller recorder. -/
  rustControllerModule : String
  /-- File path anchoring the Rust public-trace projection. -/
  rustTraceModule : String
deriving Repr, DecidableEq

/-- The actual W6.2 boundary-call provenance record. -/
def sgxBoundaryCallProvenance : SgxBoundaryCallProvenance :=
  { oramAccessApi := sgxObserverOramAccessApi
  , boundaryDirectionNames := sgxObserverBoundaryDirectionNames
  , boundaryEventBudgetFormula :=
      "boundary_event_budget = 2 * total_oram_accesses + 2"
  , boundaryScheduleShape :=
      "Enter(<entrypoint>, entry_input_len, 0); for each oram access: Exit(\"oram_access\", 0, 0); Enter(\"oram_access\", 0, 0); Exit(<entrypoint>, 0, return_length)"
  , observerDocSection :=
      "docs/tee-runtime-hardening.md \"W6.2 Frozen Boundary-Call Model\""
  , staticDriftCheckName := "sgx_boundary_call_model_pinned"
  , leanBoundaryModule := "proof/lean/UOToolchain/SgxBoundary.lean"
  , leanScheduleModule := "proof/lean/UOToolchain/SgxControllerTrace.lean"
  , rustControllerModule := "runtime/uo-evm/src/controller.rs"
  , rustTraceModule := "crates/uo-core/src/trace.rs"
  }

/-- The provenance record's pinned ORAM-access API matches the frozen
`sgxObserverOramAccessApi` literal. -/
theorem sgxBoundaryCallProvenance_oramAccessApi :
    sgxBoundaryCallProvenance.oramAccessApi =
      sgxObserverOramAccessApi := by rfl

/-- The provenance record's pinned boundary-direction names match the
frozen `sgxObserverBoundaryDirectionNames` list. -/
theorem sgxBoundaryCallProvenance_boundaryDirectionNames :
    sgxBoundaryCallProvenance.boundaryDirectionNames =
      sgxObserverBoundaryDirectionNames := by rfl

/-- The provenance record references the
`sgx_boundary_call_model_pinned` probe static-drift check. -/
theorem sgxBoundaryCallProvenance_staticDriftCheckName :
    sgxBoundaryCallProvenance.staticDriftCheckName =
      "sgx_boundary_call_model_pinned" := by rfl

/-! ### W6.2 Persistent-I/O Model

W6.2 also models the persistent-I/O surface explicitly. The Lean
trace model (`TraceModel.lean`) already carries the abstract
`PhysicalRead` / `PhysicalWrite` shapes (via `Trace`); W6.2 freezes
the canonical persistent-I/O field schema and the canonical
`WriteClass` vocabulary that the Rust runtime uses to classify
host-visible writes.

- **canonical `PhysicalRead` field schema**: `{ object, location,
  len }`, matching the Rust `PhysicalReadEvent` struct in
  `crates/uo-core/src/trace.rs`;
- **canonical `PhysicalWrite` field schema**: `{ object, location,
  writeClass, len }`, matching the Rust `PhysicalWriteEvent` struct
  (with `class : WriteClass`);
- **canonical `WriteClass` vocabulary**: `Set`, `Clear`, `Same`,
  `Update` — the four classifications the runtime emits via
  `classify_write` on each host-visible write.

The runtime side is pinned by the probe's
`sgx_persistent_io_model_pinned` static-drift check. -/

/-- Frozen list of the four canonical `WriteClass` labels in their
declared order. The runtime classifies every host-visible write into
one of these four classes via `classify_write`. -/
def sgxObserverWriteClassNames : List String :=
  ["Set", "Clear", "Same", "Update"]

@[simp] theorem sgxObserverWriteClassNames_length :
    sgxObserverWriteClassNames.length = 4 := by rfl

theorem sgxObserverWriteClassNames_value :
    sgxObserverWriteClassNames = ["Set", "Clear", "Same", "Update"] := by
  rfl

/-- Frozen list of the canonical `PhysicalRead` field names in
declared order. -/
def sgxObserverPhysicalReadFieldNames : List String :=
  ["object", "location", "len"]

@[simp] theorem sgxObserverPhysicalReadFieldNames_length :
    sgxObserverPhysicalReadFieldNames.length = 3 := by rfl

/-- Frozen list of the canonical `PhysicalWrite` field names in
declared order. The Lean structure uses `writeClass` as the
classification field; the Rust struct uses `class : WriteClass`. -/
def sgxObserverPhysicalWriteFieldNames : List String :=
  ["object", "location", "writeClass", "len"]

@[simp] theorem sgxObserverPhysicalWriteFieldNames_length :
    sgxObserverPhysicalWriteFieldNames.length = 4 := by rfl

/-! ### W6.2 persistent-I/O provenance record -/

/-- W6.2 frozen persistent-I/O provenance record. Pairs the canonical
`PhysicalRead` / `PhysicalWrite` field schemas and the canonical
`WriteClass` vocabulary with the structural metadata so the paper
claim, the Lean formalization, and the Rust runtime all reference
one canonical persistent-I/O model. -/
structure SgxPersistentIoProvenance where
  /-- The canonical `PhysicalRead` field-name list. -/
  physicalReadFieldNames : List String
  /-- The canonical `PhysicalWrite` field-name list. -/
  physicalWriteFieldNames : List String
  /-- The canonical four `WriteClass` labels. -/
  writeClassNames : List String
  /-- Documentation anchor for the WP6 hardening track. -/
  observerDocSection : String
  /-- Probe static-drift check that pins the Rust persistent-I/O
  surface. -/
  staticDriftCheckName : String
  /-- File path anchoring the Lean trace model. -/
  leanTraceModule : String
  /-- File path anchoring the Rust public-trace projection. -/
  rustTraceModule : String
deriving Repr, DecidableEq

/-- The actual W6.2 persistent-I/O provenance record. -/
def sgxPersistentIoProvenance : SgxPersistentIoProvenance :=
  { physicalReadFieldNames := sgxObserverPhysicalReadFieldNames
  , physicalWriteFieldNames := sgxObserverPhysicalWriteFieldNames
  , writeClassNames := sgxObserverWriteClassNames
  , observerDocSection :=
      "docs/tee-runtime-hardening.md \"W6.2 Frozen Persistent-I/O Model\""
  , staticDriftCheckName := "sgx_persistent_io_model_pinned"
  , leanTraceModule := "proof/lean/UOToolchain/TraceModel.lean"
  , rustTraceModule := "crates/uo-core/src/trace.rs"
  }

/-- The provenance record's pinned `WriteClass` names match the
canonical `sgxObserverWriteClassNames`. -/
theorem sgxPersistentIoProvenance_writeClassNames :
    sgxPersistentIoProvenance.writeClassNames =
      sgxObserverWriteClassNames := by rfl

/-- The provenance record's pinned `PhysicalRead` field names match
the canonical `sgxObserverPhysicalReadFieldNames`. -/
theorem sgxPersistentIoProvenance_physicalReadFieldNames :
    sgxPersistentIoProvenance.physicalReadFieldNames =
      sgxObserverPhysicalReadFieldNames := by rfl

/-- The provenance record's pinned `PhysicalWrite` field names match
the canonical `sgxObserverPhysicalWriteFieldNames`. -/
theorem sgxPersistentIoProvenance_physicalWriteFieldNames :
    sgxPersistentIoProvenance.physicalWriteFieldNames =
      sgxObserverPhysicalWriteFieldNames := by rfl

/-- The provenance record references the
`sgx_persistent_io_model_pinned` probe static-drift check. -/
theorem sgxPersistentIoProvenance_staticDriftCheckName :
    sgxPersistentIoProvenance.staticDriftCheckName =
      "sgx_persistent_io_model_pinned" := by rfl

/-! ### W6.3: Controller refinement against the frozen observer

W6.3 packages the W6.1 / W6.2 freezes as a single integration
theorem: the canonical Lean controller-shape constructor
`sgxControllerShapeOfExecutionLeakage` refines the W6.1 / W6.2
frozen observer surface for every leakage input. Concretely, for
any list of `OramAccessLeakage` records:

- the controller's page-region names equal `sgxObserverPageRegionNames`;
- the controller's workset-region names equal `sgxObserverPageRegionNames`;
- the controller's boundary-event budget equals
  `sgxObserverBoundaryEventBudget (totalOramAccesses leakage)`;
- the controller's shared-resource pattern is the canonical
  `List.replicate budget sgxObserverSharedResourceTick`.

The runtime side is pinned by the probe's
`sgx_controller_refinement_pinned` static-drift check, which
rejects representative drift in the Rust controller-shape and
boundary-schedule construction logic.

Claim taxonomy: this integration theorem is **Lean-proved,
semantics-preserving**. Each component refinement is a one-line
forwarder over an existing W6.1 / W6.2 structural equality; the
integration theorem shows the W6.1 / W6.2 freezes are coherent and
together pin the controller refinement at the public observer
surface. -/

/-- W6.3 controller-refinement integration record. Given a leakage
list, this record packages the four canonical structural equalities
that show the Lean controller shape refines the W6.1 / W6.2 frozen
observer surface. -/
structure SgxControllerObserverRefinement where
  /-- The leakage list under refinement. -/
  leakage : List OramAccessLeakage
  /-- The page-region names match the canonical observer set. -/
  pageRegionNamesMatch :
    (controllerPageTraceRegionsOfLeakage leakage).map
        (fun region => region.pageKind) = sgxObserverPageRegionNames
  /-- The workset-region names match the canonical observer set. -/
  worksetRegionNamesMatch :
    (controllerWorksetRegionsOfLeakage leakage).map
        (fun region => region.pageKind) = sgxObserverPageRegionNames
  /-- The boundary-event budget matches the canonical formula. -/
  boundaryEventBudgetMatch :
    sgxObserverBoundaryEventBudget (totalOramAccesses leakage) =
      (sgxControllerShapeOfExecutionLeakage leakage).boundaryEventBudget
  /-- The shared-resource pattern matches the canonical literal
  replicated to the public budget. -/
  sharedResourcePatternMatch :
    controllerSharedResourcePatternOfShape
        (sgxControllerShapeOfExecutionLeakage leakage) =
      List.replicate
        (sgxControllerShapeOfExecutionLeakage leakage).sharedResourceBudget
        sgxObserverSharedResourceTick

/-- W6.3 controller-refinement constructor: every leakage list
admits a controller-observer refinement witness. The four structural
equalities are direct consequences of the W6.1 / W6.2 freezes. -/
def sgxControllerObserverRefinementOf
    (leakage : List OramAccessLeakage) :
    SgxControllerObserverRefinement :=
  { leakage := leakage
  , pageRegionNamesMatch :=
      controllerPageTraceRegionsOfLeakage_pageKinds leakage
  , worksetRegionNamesMatch :=
      controllerWorksetRegionsOfLeakage_pageKinds leakage
  , boundaryEventBudgetMatch :=
      sgxObserverBoundaryEventBudget_eq_controllerShape leakage
  , sharedResourcePatternMatch :=
      controllerSharedResourcePatternOfShape_value
        (sgxControllerShapeOfExecutionLeakage leakage)
  }

/-- W6.3 theorem packaging: every leakage list refines the W6.1 /
W6.2 frozen observer in all four structural senses. -/
theorem sgxControllerObserverRefinement_exists
    (leakage : List OramAccessLeakage) :
    Nonempty SgxControllerObserverRefinement :=
  ⟨sgxControllerObserverRefinementOf leakage⟩

/-! ### W6.3 controller-refinement provenance record -/

/-- W6.3 frozen controller-refinement provenance record. Pairs the
controller-refinement integration theorem with the structural
metadata so the paper claim, the Lean formalization, and the Rust
runtime all reference one canonical refinement statement. -/
structure SgxControllerRefinementProvenance where
  /-- Free-form description of the refinement integration. -/
  refinementClaim : String
  /-- Documentation anchor for the WP6 hardening track. -/
  observerDocSection : String
  /-- Probe static-drift check that pins the Rust runtime's
  controller refinement. -/
  staticDriftCheckName : String
  /-- File path anchoring the Lean controller-shape constructor. -/
  leanControllerModule : String
  /-- File path anchoring the Rust public-trace projection. -/
  rustTraceModule : String
  /-- File path anchoring the Rust runtime controller recorder. -/
  rustControllerModule : String
deriving Repr, DecidableEq

/-- The actual W6.3 controller-refinement provenance record. -/
def sgxControllerRefinementProvenance : SgxControllerRefinementProvenance :=
  { refinementClaim :=
      "for every OramAccessLeakage list, the canonical Lean controller-shape constructor refines the W6.1 / W6.2 frozen observer surface in page-region names, workset-region names, boundary-event budget, and shared-resource pattern"
  , observerDocSection :=
      "docs/tee-runtime-hardening.md \"W6.3 Controller-Refinement Integration\""
  , staticDriftCheckName := "sgx_controller_refinement_pinned"
  , leanControllerModule := "proof/lean/UOToolchain/SgxController.lean"
  , rustTraceModule := "crates/uo-core/src/trace.rs"
  , rustControllerModule := "runtime/uo-evm/src/controller.rs"
  }

/-- The provenance record references the
`sgx_controller_refinement_pinned` probe static-drift check. -/
theorem sgxControllerRefinementProvenance_staticDriftCheckName :
    sgxControllerRefinementProvenance.staticDriftCheckName =
      "sgx_controller_refinement_pinned" := by rfl

/-! ### W6.4: Sealing / Storage Refinement Integration

W6.4 packages the canonical sealing / storage projection rules:
the Lean `TEEView` projection `viewTEEStore` maps a `Config` and a
`DeploymentResult` to a `TEEView` via deterministic field selection,
specifically pulling the `physicalReads` and `physicalWrites` lists
straight from the underlying `Trace`. The theorem-side persistent
model uses these lists at the W6.2-frozen `PhysicalRead` /
`PhysicalWrite` schema.

The Lean integration packages four canonical structural equalities:

- the `viewTEEStore` projection's `physicalReads` field equals the
  underlying `Trace.physicalReads` list;
- the `viewTEEStore` projection's `physicalWrites` field equals the
  underlying `Trace.physicalWrites` list;
- the `viewTEEStore` projection's `gasUsed` field equals the
  underlying `Trace.gasUsed` value;
- the `viewTEEStore` projection's `entrypointId` field equals the
  underlying `Config.program.entrypoint` value.

The runtime side is pinned by the probe's
`sgx_storage_refinement_pinned` static-drift check, which rejects
representative drift in the Rust `RefinementTrace` /
`RuntimeRefinementWitness` storage emission path.

Claim taxonomy: this integration is **Lean-proved,
semantics-preserving**. Each component refinement is a one-line
forwarder over `viewTEEStore`'s definitional structure; the
integration theorem composes them into a single named refinement
statement. The integration does not by itself discharge any
deployment assumption. -/

/-- W6.4 storage-refinement integration record. Given a `Config` and
a `DeploymentResult`, this record packages the four canonical
structural equalities that show the Lean `TEEView` projection
`viewTEEStore` deterministically pulls each storage-relevant field
from the underlying trace and config. -/
structure SgxStorageRefinement (cfg : Config) (result : DeploymentResult) where
  /-- The projection's `physicalReads` field equals the underlying
  trace's `physicalReads` list. -/
  physicalReadsMatch :
    (viewTEEStore cfg result).physicalReads = result.trace.physicalReads
  /-- The projection's `physicalWrites` field equals the underlying
  trace's `physicalWrites` list. -/
  physicalWritesMatch :
    (viewTEEStore cfg result).physicalWrites = result.trace.physicalWrites
  /-- The projection's `gasUsed` field equals the underlying trace's
  `gasUsed` value. -/
  gasUsedMatch :
    (viewTEEStore cfg result).gasUsed = result.trace.gasUsed
  /-- The projection's `entrypointId` field equals the underlying
  config's `program.entrypoint` value. -/
  entrypointIdMatch :
    (viewTEEStore cfg result).entrypointId = cfg.program.entrypoint

/-- W6.4 storage-refinement constructor: every `(cfg, result)` pair
admits a storage-refinement witness. The four structural equalities
all reduce to `rfl` because `viewTEEStore` is definitionally a
record literal. -/
def sgxStorageRefinementOf
    (cfg : Config) (result : DeploymentResult) :
    SgxStorageRefinement cfg result :=
  { physicalReadsMatch := by rfl
  , physicalWritesMatch := by rfl
  , gasUsedMatch := by rfl
  , entrypointIdMatch := by rfl
  }

/-- W6.4 packaging: every `(cfg, result)` pair admits a
storage-refinement witness. -/
theorem sgxStorageRefinement_exists
    (cfg : Config) (result : DeploymentResult) :
    Nonempty (SgxStorageRefinement cfg result) :=
  ⟨sgxStorageRefinementOf cfg result⟩

/-! ### W6.4 storage-refinement provenance record -/

/-- W6.4 frozen storage-refinement provenance record. Pairs the
storage-refinement integration theorem with the structural metadata
so the paper claim, the Lean formalization, and the Rust runtime
all reference one canonical sealing / storage projection. -/
structure SgxStorageRefinementProvenance where
  /-- Free-form description of the refinement integration. -/
  refinementClaim : String
  /-- Documentation anchor for the WP6 hardening track. -/
  observerDocSection : String
  /-- Probe static-drift check that pins the Rust runtime's
  storage-refinement emission. -/
  staticDriftCheckName : String
  /-- File path anchoring the Lean TEE-deployment model. -/
  leanTeeDeploymentModule : String
  /-- File path anchoring the Lean trace model. -/
  leanTraceModule : String
  /-- File path anchoring the Rust public-trace projection. -/
  rustTraceModule : String
deriving Repr, DecidableEq

/-- The actual W6.4 storage-refinement provenance record. -/
def sgxStorageRefinementProvenance : SgxStorageRefinementProvenance :=
  { refinementClaim :=
      "viewTEEStore projects every TEEView field deterministically from the underlying Config and DeploymentResult; the physicalReads / physicalWrites lists are forwarded unchanged at the W6.2-frozen PhysicalRead / PhysicalWrite schema"
  , observerDocSection :=
      "docs/tee-runtime-hardening.md \"W6.4 Sealing / Storage Refinement Integration\""
  , staticDriftCheckName := "sgx_storage_refinement_pinned"
  , leanTeeDeploymentModule := "proof/lean/UOToolchain/TeeDeployment.lean"
  , leanTraceModule := "proof/lean/UOToolchain/TraceModel.lean"
  , rustTraceModule := "crates/uo-core/src/trace.rs"
  }

/-- The provenance record references the
`sgx_storage_refinement_pinned` probe static-drift check. -/
theorem sgxStorageRefinementProvenance_staticDriftCheckName :
    sgxStorageRefinementProvenance.staticDriftCheckName =
      "sgx_storage_refinement_pinned" := by rfl

/-! ### W6.5: Hostile-Host TEE Deployment-Assumption Bundle

W6.5 states the irreducible TEE deployment assumptions explicitly,
in one named bundle, paired with explicit provenance citations. The
bundle stays explicit at the Lean type level rather than being
hidden in prose; each assumption is paired with the Intel SGX
specification it relies on.

The five canonical fields capture the load-bearing TEE deployment
assumptions called out by the WP6 charter:

- `attestationAuthenticity` — Intel SGX attestation produces a
  quote signed by the platform's attestation key whose
  authenticity is established by the Intel Provisioning Service /
  DCAP attestation chain;
- `enclaveMemoryIsolation` — enclave memory pages are protected by
  the Memory Encryption Engine (MEE) for confidentiality and
  integrity;
- `rollbackResistance` — sealed state cannot be silently rolled
  back to an earlier epoch (sgx_get_trusted_time / monotonic
  counters / replay protection);
- `crashRecoveryDiscipline` — crash recovery from sealed state does
  not leak partial confidential state;
- `patchLevelTrust` — the deployed platform's security
  patch / microcode level supports the SGX security claims.

Claim taxonomy (per
[`docs/coding-agent-conventions.md`](./coding-agent-conventions.md#claim-and-tcb-discipline)):
**Cited / externally justified** — the assumptions remain explicit
in the bundle, paired with provenance citations to the Intel SGX
specifications. They are not Lean-discharged; they are part of the
deployment TCB and must be honored by the TEE platform under
deployment. -/

/-- Explicit hostile-host TEE deployment-assumption bundle. The five
fields are the irreducible deployment-side trust assumptions for
the hostile-host SGX execution-oblivious theorem. Each field is
paired with an explicit provenance record (defined below). -/
structure SgxDeploymentAssumptions where
  /-- The platform's attestation produces a quote whose authenticity
  is established by the Intel Provisioning Service / DCAP
  attestation chain. -/
  attestationAuthenticity : Prop
  /-- Enclave memory pages are protected by the Memory Encryption
  Engine for both confidentiality and integrity against a hostile
  host. -/
  enclaveMemoryIsolation : Prop
  /-- Sealed state cannot be silently rolled back to a prior epoch
  (monotonic counters / `sgx_get_trusted_time` / replay
  protection). -/
  rollbackResistance : Prop
  /-- Crash recovery from sealed state does not leak partial
  confidential state. -/
  crashRecoveryDiscipline : Prop
  /-- The deployed platform's security patch / microcode level
  supports the SGX security claims (no known unmitigated TEE
  vulnerabilities below the deployment patch level). -/
  patchLevelTrust : Prop

/-- Generic provenance-marker structure for one TEE deployment
assumption. Pairs the assumption-bundle field name with the
canonical Intel SGX citation, the BibTeX key, the IETF / NIST
specification reference, and the named probe drift check. -/
structure SgxDeploymentAssumptionProvenance where
  /-- Assumption-bundle field name. -/
  fieldName : String
  /-- Plain-language description of the assumption's role. -/
  role : String
  /-- WP6 claim taxonomy classification ("Cited / externally
  justified"). -/
  classification : String
  /-- Human-readable Intel SGX specification citation. -/
  primaryCitation : String
  /-- BibTeX key for the Intel SGX specification. -/
  primaryBibKey : String
  /-- Probe static-drift check name pinning the runtime / build
  artifact surface that the deployment assumption talks about. -/
  staticDriftCheckName : String
deriving Repr, DecidableEq

/-- Provenance record for `attestationAuthenticity`. Cites the Intel
SGX Attestation Services Programming Reference and the DCAP
quoting library reference. -/
def sgxDeploymentProvenance_attestationAuthenticity :
    SgxDeploymentAssumptionProvenance :=
  { fieldName := "attestationAuthenticity"
  , role :=
      "platform attestation produces a quote whose authenticity is established by the Intel Provisioning Service / DCAP attestation chain"
  , classification := "Cited / externally justified"
  , primaryCitation :=
      "Intel Software Guard Extensions (SGX) Attestation Services Programming Reference. Intel Corporation, 2018-revised. Reference Number 332680-008US (Attestation Services), and DCAP Quote Generation Library Programming Reference."
  , primaryBibKey := "IntelSGXAttestationReference"
  , staticDriftCheckName := "sgx_deployment_assumption_bundle_pinned"
  }

/-- Provenance record for `enclaveMemoryIsolation`. Cites the Intel
SGX Developer Reference / Programming Reference (MEE chapter). -/
def sgxDeploymentProvenance_enclaveMemoryIsolation :
    SgxDeploymentAssumptionProvenance :=
  { fieldName := "enclaveMemoryIsolation"
  , role :=
      "enclave memory pages are protected by the Memory Encryption Engine (MEE) for confidentiality and integrity against a hostile host"
  , classification := "Cited / externally justified"
  , primaryCitation :=
      "Intel 64 and IA-32 Architectures Software Developer's Manual, Volume 3D: Intel SGX (chapter on EPC Memory Encryption Engine), and Intel SGX Developer Reference, Memory Protection model section."
  , primaryBibKey := "IntelSGXSDM3D"
  , staticDriftCheckName := "sgx_deployment_assumption_bundle_pinned"
  }

/-- Provenance record for `rollbackResistance`. Cites the Intel SGX
SDK monotonic counter / trusted time interfaces. -/
def sgxDeploymentProvenance_rollbackResistance :
    SgxDeploymentAssumptionProvenance :=
  { fieldName := "rollbackResistance"
  , role :=
      "sealed state cannot be silently rolled back to a prior epoch; replay protection comes from monotonic counters and sgx_get_trusted_time"
  , classification := "Cited / externally justified"
  , primaryCitation :=
      "Intel SGX SDK Developer Reference: sgx_create_monotonic_counter / sgx_increment_monotonic_counter and sgx_get_trusted_time interfaces. Sealing & freshness chapter."
  , primaryBibKey := "IntelSGXSDKDeveloperReference"
  , staticDriftCheckName := "sgx_deployment_assumption_bundle_pinned"
  }

/-- Provenance record for `crashRecoveryDiscipline`. Cites the Intel
SGX SDK power transitions / sealing notes. -/
def sgxDeploymentProvenance_crashRecoveryDiscipline :
    SgxDeploymentAssumptionProvenance :=
  { fieldName := "crashRecoveryDiscipline"
  , role :=
      "crash recovery from sealed state does not leak partial confidential state; the runtime's commit / wipe boundary is honored across enclave power transitions"
  , classification := "Cited / externally justified"
  , primaryCitation :=
      "Intel SGX SDK Developer Reference: Power transitions, sealing & unsealing chapter (`sgx_seal_data` / `sgx_unseal_data` discipline)."
  , primaryBibKey := "IntelSGXSDKDeveloperReference"
  , staticDriftCheckName := "sgx_deployment_assumption_bundle_pinned"
  }

/-- Provenance record for `patchLevelTrust`. Cites the Intel SGX
platform / microcode update advisory channel. -/
def sgxDeploymentProvenance_patchLevelTrust :
    SgxDeploymentAssumptionProvenance :=
  { fieldName := "patchLevelTrust"
  , role :=
      "the deployed platform's security patch / microcode level supports the SGX security claims (no known unmitigated TEE vulnerabilities below the deployment patch level)"
  , classification := "Cited / externally justified"
  , primaryCitation :=
      "Intel Security Center: Intel SGX Platform Software (Intel SGX PSW), Trusted Computing Base (TCB) recovery, and Intel CPU microcode update advisories at https://www.intel.com/content/www/us/en/security-center/."
  , primaryBibKey := "IntelSGXSecurityCenter"
  , staticDriftCheckName := "sgx_deployment_assumption_bundle_pinned"
  }

/-- Five-element provenance list for the deployment-assumption
bundle, in canonical declaration order. -/
def sgxDeploymentAssumptionProvenances :
    List SgxDeploymentAssumptionProvenance :=
  [ sgxDeploymentProvenance_attestationAuthenticity
  , sgxDeploymentProvenance_enclaveMemoryIsolation
  , sgxDeploymentProvenance_rollbackResistance
  , sgxDeploymentProvenance_crashRecoveryDiscipline
  , sgxDeploymentProvenance_patchLevelTrust
  ]

/-- The deployment-assumption provenance list has exactly five
entries — one per bundle field. -/
theorem sgxDeploymentAssumptionProvenances_length :
    sgxDeploymentAssumptionProvenances.length = 5 := by rfl

/-- Every entry in the deployment-assumption provenance list is
classified as "Cited / externally justified". -/
theorem sgxDeploymentAssumptionProvenances_allCited :
    ∀ entry, entry ∈ sgxDeploymentAssumptionProvenances →
      entry.classification = "Cited / externally justified" := by
  intro entry hMem
  unfold sgxDeploymentAssumptionProvenances at hMem
  simp at hMem
  rcases hMem with h | h | h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

/-- Every entry references the same probe drift check name,
`sgx_deployment_assumption_bundle_pinned`, which pins the
deployment-assumption bundle's runtime-facing surface in lockstep. -/
theorem sgxDeploymentAssumptionProvenances_sharedDriftCheck :
    ∀ entry, entry ∈ sgxDeploymentAssumptionProvenances →
      entry.staticDriftCheckName =
        "sgx_deployment_assumption_bundle_pinned" := by
  intro entry hMem
  unfold sgxDeploymentAssumptionProvenances at hMem
  simp at hMem
  rcases hMem with h | h | h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

end UOToolchain
