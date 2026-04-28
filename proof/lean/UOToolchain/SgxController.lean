import UOToolchain.OramModel
import UOToolchain.SgxRelation

/-! # SGX controller-shape layer

This file defines the canonical SGX controller shape an ORAM execution
leakage induces — phase trace, page-region budgets, workset regions,
exit-trace budget, shared-resource budget, recursion depth, stash
bound — and lifts the shape into an `SGXMicroLeakage`.

* **Abstraction function:** `oramControllerShape` (lifts an
  `OramConfig` to an `SGXControllerShape` via
  `sgxControllerShapeOfExecutionLeakage`). The companion
  `oramControllerMicroLeakage` lifts the shape further into an
  `SGXMicroLeakage`.
* **Main theorem:** `oramControllerShape_eq_of_samePublicProjection`
  — same-public ORAM configs share the same controller shape. The
  derived consequence
  `oramControllerMicroLeakage_eq_of_samePublicProjection` is the
  paper-relevant public-leakage equality.

All other declarations are file-local helpers (`maxNatList`,
`concatLists`, `controllerExitEventOfIndex`,
`controllerExitPatternOfShape`,
`controllerSharedResourcePatternOfShape`,
`sgxMicroLeakageOfController_eq_of_eq`). -/

namespace UOToolchain

structure SGXControllerShape where
  boundaryEventBudget : Nat
  phaseTrace : List SGXControllerPhase
  pageTraceRegions : List SGXControllerPageBudget
  worksetRegions : List SGXControllerPageBudget
  exitTraceBudget : Nat
  sharedResourceBudget : Nat
  recursivePositionMapDepth : Nat
  stashBound : Nat
deriving Repr, DecidableEq

def emptySGXControllerShape : SGXControllerShape :=
  { boundaryEventBudget := 0
  , phaseTrace := []
  , pageTraceRegions := []
  , worksetRegions := []
  , exitTraceBudget := 0
  , sharedResourceBudget := 0
  , recursivePositionMapDepth := 0
  , stashBound := 0
  }

def SGXControllerShape.controllerPhaseCount (shape : SGXControllerShape) : Nat :=
  shape.phaseTrace.length

def totalPageBudget (regions : List SGXControllerPageBudget) : Nat :=
  regions.foldl (fun acc region => acc + region.eventBudget) 0

def SGXControllerShape.pageTraceBudget (shape : SGXControllerShape) : Nat :=
  totalPageBudget shape.pageTraceRegions

def SGXControllerShape.controllerWorksetPages (shape : SGXControllerShape) : Nat :=
  totalPageBudget shape.worksetRegions

def maxNatList : List Nat → Nat
  | [] => 0
  | value :: values => max value (maxNatList values)

def concatLists {α : Type} : List (List α) → List α
  | [] => []
  | xs :: xss => xs ++ concatLists xss

def totalOramAccesses (leakage : List OramAccessLeakage) : Nat :=
  leakage.foldl (fun acc leak => acc + leak.accessesPerEntrypoint) 0

def controllerAccessPhasePlan (leak : OramAccessLeakage) : List SGXControllerPhase :=
  [SGXControllerPhase.stageRequest] ++
    List.replicate leak.recursionDepth SGXControllerPhase.descendPositionMap ++
    [ SGXControllerPhase.loadMetadata
    , SGXControllerPhase.fetchPath
    , SGXControllerPhase.scanStash
    , SGXControllerPhase.rewritePath
    ] ++
    List.replicate leak.recursionDepth SGXControllerPhase.ascendPositionMap

def controllerObjectPhasePlan (leak : OramAccessLeakage) : List SGXControllerPhase :=
  concatLists (List.replicate leak.accessesPerEntrypoint (controllerAccessPhasePlan leak))

def controllerPhaseTraceOfLeakage (leakage : List OramAccessLeakage) : List SGXControllerPhase :=
  [SGXControllerPhase.enclaveEnter] ++
    concatLists (leakage.map controllerObjectPhasePlan) ++
    [SGXControllerPhase.sealPersistentState, SGXControllerPhase.enclaveExit]

def totalMetadataPageBudget (leakage : List OramAccessLeakage) : Nat :=
  leakage.foldl (fun acc leak => acc + leak.accessesPerEntrypoint * leak.metadataPagesPerAccess) 0

def totalPositionMapPageBudget (leakage : List OramAccessLeakage) : Nat :=
  leakage.foldl (fun acc leak => acc + leak.accessesPerEntrypoint * leak.recursionDepth) 0

def totalPathPageBudget (leakage : List OramAccessLeakage) : Nat :=
  leakage.foldl (fun acc leak => acc + leak.accessesPerEntrypoint * leak.bucketsPerAccess) 0

def totalStashPageBudget (leakage : List OramAccessLeakage) : Nat :=
  leakage.foldl (fun acc leak => acc + leak.accessesPerEntrypoint * leak.stashBound) 0

def maxMetadataWorkset (leakage : List OramAccessLeakage) : Nat :=
  maxNatList (leakage.map fun leak => leak.metadataPagesPerAccess)

def maxPositionMapWorkset (leakage : List OramAccessLeakage) : Nat :=
  maxNatList (leakage.map fun leak => leak.recursionDepth)

def maxPathWorkset (leakage : List OramAccessLeakage) : Nat :=
  maxNatList (leakage.map fun leak => leak.bucketsPerAccess)

def maxStashWorkset (leakage : List OramAccessLeakage) : Nat :=
  maxNatList (leakage.map fun leak => leak.stashBound)

def controllerPageTraceRegionsOfLeakage (leakage : List OramAccessLeakage) :
    List SGXControllerPageBudget :=
  [ { pageKind := "metadata", eventBudget := totalMetadataPageBudget leakage }
  , { pageKind := "position_map", eventBudget := totalPositionMapPageBudget leakage }
  , { pageKind := "path", eventBudget := totalPathPageBudget leakage }
  , { pageKind := "stash", eventBudget := totalStashPageBudget leakage }
  ]

def controllerWorksetRegionsOfLeakage (leakage : List OramAccessLeakage) :
    List SGXControllerPageBudget :=
  [ { pageKind := "metadata", eventBudget := maxMetadataWorkset leakage }
  , { pageKind := "position_map", eventBudget := maxPositionMapWorkset leakage }
  , { pageKind := "path", eventBudget := maxPathWorkset leakage }
  , { pageKind := "stash", eventBudget := maxStashWorkset leakage }
  ]

def controllerRecursionDepthOfLeakage (leakage : List OramAccessLeakage) : Nat :=
  maxNatList (leakage.map fun leak => leak.recursionDepth)

def controllerStashBoundOfLeakage (leakage : List OramAccessLeakage) : Nat :=
  maxNatList (leakage.map fun leak => leak.stashBound)

def controllerExitEventOfIndex
  (budget : Nat)
  (index : Nat) : ExitEvent :=
  if index + 1 = budget then
    ExitEvent.terminate
  else if index % 2 = 0 then
    ExitEvent.resume
  else
    ExitEvent.interruptExit

def controllerExitPatternOfShape (shape : SGXControllerShape) : List ExitEvent :=
  (List.range shape.exitTraceBudget).map (controllerExitEventOfIndex shape.exitTraceBudget)

def controllerSharedResourcePatternOfShape (shape : SGXControllerShape) : SharedResourceTrace :=
  List.replicate shape.sharedResourceBudget "shared_resource_tick"

def sgxControllerShapeOfExecutionLeakage (leakage : List OramAccessLeakage) : SGXControllerShape :=
  let phaseTrace := controllerPhaseTraceOfLeakage leakage
  let pageTraceRegions := controllerPageTraceRegionsOfLeakage leakage
  let worksetRegions := controllerWorksetRegionsOfLeakage leakage
  let totalAccesses := totalOramAccesses leakage
  let pageTraceBudget := totalPageBudget pageTraceRegions
  { boundaryEventBudget := 2 * (totalAccesses + 1)
  , phaseTrace := phaseTrace
  , pageTraceRegions := pageTraceRegions
  , worksetRegions := worksetRegions
  , exitTraceBudget := phaseTrace.length + totalAccesses + 1
  , sharedResourceBudget := phaseTrace.length + pageTraceBudget
  , recursivePositionMapDepth := controllerRecursionDepthOfLeakage leakage
  , stashBound := controllerStashBoundOfLeakage leakage
  }

def sgxMicroLeakageOfController
  (publicOutcome : SGXPublicOutcome)
  (modelTags : SGXModelTags)
  (controllerShape : SGXControllerShape) : SGXMicroLeakage :=
  { publicOutcome := publicOutcome
  , modelTags := modelTags
  , boundaryEventBudget := controllerShape.boundaryEventBudget
  , controllerPhaseCount := controllerShape.controllerPhaseCount
  , controllerPhaseOrder := controllerShape.phaseTrace
  , pageTraceBudget := controllerShape.pageTraceBudget
  , pageTraceRegions := controllerShape.pageTraceRegions
  , exitTraceBudget := controllerShape.exitTraceBudget
  , normalizedExitPattern := controllerExitPatternOfShape controllerShape
  , sharedResourceBudget := controllerShape.sharedResourceBudget
  , sharedResourcePattern := controllerSharedResourcePatternOfShape controllerShape
  , controllerWorksetPages := controllerShape.controllerWorksetPages
  , worksetRegions := controllerShape.worksetRegions
  , recursivePositionMapDepth := controllerShape.recursivePositionMapDepth
  , stashBound := controllerShape.stashBound
  }

def oramControllerShape (cfg : OramConfig) : SGXControllerShape :=
  sgxControllerShapeOfExecutionLeakage (executionLeakage cfg)

def oramControllerMicroLeakage
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (modelTags : SGXModelTags) : OramConfig → SGXMicroLeakage :=
  fun cfg => sgxMicroLeakageOfController (publicOutcome cfg) modelTags (oramControllerShape cfg)

theorem sgxMicroLeakageOfController_eq_of_eq
  {publicOutcome₁ publicOutcome₂ : SGXPublicOutcome}
  {modelTags₁ modelTags₂ : SGXModelTags}
  {controllerShape₁ controllerShape₂ : SGXControllerShape}
  (hOutcome : publicOutcome₁ = publicOutcome₂)
  (hTags : modelTags₁ = modelTags₂)
  (hShape : controllerShape₁ = controllerShape₂) :
  sgxMicroLeakageOfController publicOutcome₁ modelTags₁ controllerShape₁ =
    sgxMicroLeakageOfController publicOutcome₂ modelTags₂ controllerShape₂ := by
  subst hOutcome
  subst hTags
  subst hShape
  rfl

theorem oramControllerShape_eq_of_samePublicProjection
  {cfg₁ cfg₂ : OramConfig} :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramControllerShape cfg₁ = oramControllerShape cfg₂ := by
  intro hPublic
  simp [oramControllerShape, executionLeakage_eq_of_samePublicProjection hPublic]

theorem oramControllerMicroLeakage_eq_of_samePublicProjection
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {modelTags : SGXModelTags}
  (hOutcome :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂)
  {cfg₁ cfg₂ : OramConfig} :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramControllerMicroLeakage publicOutcome modelTags cfg₁ =
    oramControllerMicroLeakage publicOutcome modelTags cfg₂ := by
  intro hPublic
  apply sgxMicroLeakageOfController_eq_of_eq
  · exact hOutcome cfg₁ cfg₂ hPublic
  · rfl
  · exact oramControllerShape_eq_of_samePublicProjection hPublic

end UOToolchain
