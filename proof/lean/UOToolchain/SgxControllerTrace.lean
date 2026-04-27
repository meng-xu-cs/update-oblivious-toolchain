import UOToolchain.SgxController

namespace UOToolchain

def controllerPageEventOfIndex
  (pageKind : String)
  (index : Nat) : PageEvent :=
  { pageKind := pageKind
  , pageId := index / 2
  , kind := if index % 2 = 0 then PageEventKind.faultIn else PageEventKind.evictOut
  }

def controllerPageEventsOfRegion (region : SGXControllerPageBudget) : List PageEvent :=
  (List.range region.eventBudget).map (controllerPageEventOfIndex region.pageKind)

@[simp] theorem controllerPageEventsOfRegion_length (region : SGXControllerPageBudget) :
    (controllerPageEventsOfRegion region).length = region.eventBudget := by
  simp [controllerPageEventsOfRegion]

theorem pageBudgetFoldl_add
  (regions : List SGXControllerPageBudget)
  (acc seed : Nat) :
    acc + regions.foldl (fun acc region => acc + region.eventBudget) seed =
      regions.foldl (fun acc region => acc + region.eventBudget) (acc + seed) := by
  induction regions generalizing acc seed with
  | nil =>
      simp
  | cons region regions ih =>
      simp [ih, Nat.add_left_comm, Nat.add_comm]

theorem totalPageBudget_acc (regions : List SGXControllerPageBudget) (acc : Nat) :
    acc + totalPageBudget regions =
      regions.foldl (fun acc region => acc + region.eventBudget) acc := by
  simpa [totalPageBudget] using pageBudgetFoldl_add regions acc 0

theorem controllerPageTraceRegions_length (regions : List SGXControllerPageBudget) :
    (concatLists (regions.map controllerPageEventsOfRegion)).length = totalPageBudget regions := by
  induction regions with
  | nil =>
      simp [concatLists, totalPageBudget]
  | cons region regions ih =>
      rw [show totalPageBudget (region :: regions) =
        regions.foldl (fun acc region => acc + region.eventBudget) region.eventBudget by
          simp [totalPageBudget]]
      simp [concatLists, ih, totalPageBudget_acc]

def controllerPageTraceOfShape (shape : SGXControllerShape) : List PageEvent :=
  concatLists (shape.pageTraceRegions.map controllerPageEventsOfRegion)

@[simp] theorem controllerPageTraceOfShape_length (shape : SGXControllerShape) :
    (controllerPageTraceOfShape shape).length = shape.pageTraceBudget := by
  simpa [controllerPageTraceOfShape, SGXControllerShape.pageTraceBudget] using
    controllerPageTraceRegions_length shape.pageTraceRegions

def controllerExitTraceOfShape (shape : SGXControllerShape) : List ExitEvent :=
  controllerExitPatternOfShape shape

@[simp] theorem controllerExitTraceOfShape_length (shape : SGXControllerShape) :
    (controllerExitTraceOfShape shape).length = shape.exitTraceBudget := by
  simp [controllerExitTraceOfShape, controllerExitPatternOfShape]

def controllerSharedResourceTraceOfShape (shape : SGXControllerShape) : SharedResourceTrace :=
  controllerSharedResourcePatternOfShape shape

@[simp] theorem controllerSharedResourceTraceOfShape_length (shape : SGXControllerShape) :
    (controllerSharedResourceTraceOfShape shape).length = shape.sharedResourceBudget := by
  simp [controllerSharedResourceTraceOfShape, controllerSharedResourcePatternOfShape]

def controllerMicroTraceOfShape (shape : SGXControllerShape) : SGXMicroTrace :=
  { pageTrace := controllerPageTraceOfShape shape
  , exitTrace := controllerExitTraceOfShape shape
  , sharedResourceTrace := controllerSharedResourceTraceOfShape shape
  }

theorem controllerMicroTraceOfShape_eq_of_eq
  {shape₁ shape₂ : SGXControllerShape} :
  shape₁ = shape₂ →
  controllerMicroTraceOfShape shape₁ = controllerMicroTraceOfShape shape₂ := by
  intro h
  subst h
  rfl

def oramControllerMicroTrace (cfg : OramConfig) : SGXMicroTrace :=
  controllerMicroTraceOfShape (oramControllerShape cfg)

theorem oramControllerMicroTrace_eq_of_samePublicProjection
  {cfg₁ cfg₂ : OramConfig} :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramControllerMicroTrace cfg₁ = oramControllerMicroTrace cfg₂ := by
  intro hPublic
  apply controllerMicroTraceOfShape_eq_of_eq
  exact oramControllerShape_eq_of_samePublicProjection hPublic

end UOToolchain
