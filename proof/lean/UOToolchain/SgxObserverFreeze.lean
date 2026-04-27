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

end UOToolchain
