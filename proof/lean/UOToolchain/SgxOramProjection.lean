import UOToolchain.SgxController

namespace UOToolchain

def sgxStorageOfOramView (view : ViewMPlus) : SGXStorageTrace :=
  match view with
  | (_opcodeTrace, _logicalAccesses, _logicalWrites, persistentReads, persistentWrites, _gasUsed) =>
      { persistentReads := persistentReads
      , persistentWrites := persistentWrites
      }

def publicSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ _leakage => ExactProjectionRelation id micro₁ micro₂

def oramSGXStorageRelation : SGXStorageRelation :=
  fun storage₁ storage₂ leakage =>
    ∃ cfg₁ cfg₂ view₁ view₂,
      sameOramPublicProjection cfg₁ cfg₂ ∧
      leakage = executionLeakage cfg₁ ∧
      oramLocalTheorem view₁ view₂ leakage ∧
      storage₁ = view₁.map sgxStorageOfOramView ∧
      storage₂ = view₂.map sgxStorageOfOramView

def oramSGXProofRelation : SGXProofRelation :=
  { storageRel := oramSGXStorageRelation
  , microRel := publicSGXMicroRelation
  }

def OramPublicOutcomeSafe (publicOutcome : OramConfig → SGXPublicOutcome) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂

def OramPublicBoundarySafe (boundarySchedule : OramConfig → List BoundaryEvent) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → boundarySchedule cfg₁ = boundarySchedule cfg₂

def OramPublicMicroTraceSafe (microTrace : OramConfig → SGXMicroTrace) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → microTrace cfg₁ = microTrace cfg₂

def sgxViewOfOramView
  (_cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (microTrace : SGXMicroTrace)
  (view : ViewMPlus) : SGXView :=
  let storage := sgxStorageOfOramView view
  { entrypointId := publicOutcome.entrypointId
  , publicArgs := publicOutcome.publicArgs
  , boundarySchedule := boundarySchedule
  , persistentReads := storage.persistentReads
  , persistentWrites := storage.persistentWrites
  , pageTrace := microTrace.pageTrace
  , exitTrace := microTrace.exitTrace
  , sharedResourceTrace := microTrace.sharedResourceTrace
  , terminationStatus := publicOutcome.terminationStatus
  , outputShape := publicOutcome.outputShape
  , gasUsed := publicOutcome.gasUsed
  }

def oramToSGXSemantics
  (run : OramSemantics)
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (boundarySchedule : OramConfig → List BoundaryEvent)
  (microTrace : OramConfig → SGXMicroTrace) :
  SGXSemantics OramConfig :=
  fun cfg =>
    (run cfg).map (sgxViewOfOramView cfg (publicOutcome cfg) (boundarySchedule cfg) (microTrace cfg))

def oramMicroLeakage
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (modelTags : SGXModelTags) : OramConfig → SGXMicroLeakage :=
  oramControllerMicroLeakage publicOutcome modelTags

@[simp] theorem sgxPublicOutcome_sgxViewOfOramView
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (microTrace : SGXMicroTrace)
  (view : ViewMPlus) :
  sgxPublicOutcome (sgxViewOfOramView cfg publicOutcome boundarySchedule microTrace view) = publicOutcome := by
  cases publicOutcome
  cases microTrace
  cases view
  rfl

@[simp] theorem sgxBoundary_sgxViewOfOramView
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (microTrace : SGXMicroTrace)
  (view : ViewMPlus) :
  (sgxViewOfOramView cfg publicOutcome boundarySchedule microTrace view).boundarySchedule = boundarySchedule := by
  cases publicOutcome
  cases microTrace
  cases view
  rfl

@[simp] theorem sgxStorageTrace_sgxViewOfOramView
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (microTrace : SGXMicroTrace)
  (view : ViewMPlus) :
  sgxStorageTrace (sgxViewOfOramView cfg publicOutcome boundarySchedule microTrace view) =
    sgxStorageOfOramView view := by
  cases publicOutcome
  cases microTrace
  cases view
  rfl

@[simp] theorem sgxMicroTrace_sgxViewOfOramView
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (microTrace : SGXMicroTrace)
  (view : ViewMPlus) :
  sgxMicroTrace (sgxViewOfOramView cfg publicOutcome boundarySchedule microTrace view) = microTrace := by
  cases publicOutcome
  cases microTrace
  cases view
  rfl

theorem oramLocalTheorem_projects_to_sgxStorage
  (cfg₁ cfg₂ : OramConfig)
  (view₁ view₂ : Distribution ViewMPlus) :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramLocalTheorem view₁ view₂ (executionLeakage cfg₁) →
  oramSGXStorageRelation
    (view₁.map sgxStorageOfOramView)
    (view₂.map sgxStorageOfOramView)
    (executionLeakage cfg₁) := by
  intro hPublic hLocal
  exact ⟨cfg₁, cfg₂, view₁, view₂, hPublic, rfl, hLocal, rfl, rfl⟩

theorem oramMicroLeakage_public
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {modelTags : SGXModelTags}
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  PublicMicroLeakage sameOramPublicProjection (oramMicroLeakage publicOutcome modelTags) := by
  intro cfg₁ cfg₂ hPublic
  exact oramControllerMicroLeakage_eq_of_samePublicProjection hOutcome hPublic

theorem oramStorageLeakage_public :
  PublicStorageLeakage sameOramPublicProjection executionLeakage := by
  intro cfg₁ cfg₂ hPublic
  exact executionLeakage_eq_of_samePublicProjection hPublic

theorem computationalUO_projects_to_sgxExecution
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microTrace : OramConfig → SGXMicroTrace}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicro : OramPublicMicroTraceSafe microTrace) :
  SGXExecutionSecurity
    sameOramPublicProjection
    oramSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule microTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  intro cfg₁ cfg₂ hPublic
  constructor
  · apply exactProjectionRelation_of_constant (hOutcome cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₁) _ (run cfg₁) ?_
      intro view hMem
      simp
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₂) _ (run cfg₂) ?_
      intro view hMem
      simp
  constructor
  · apply exactProjectionRelation_of_constant (hBoundary cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) (boundarySchedule cfg₁) _ (run cfg₁) ?_
      intro view hMem
      simp
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) (boundarySchedule cfg₂) _ (run cfg₂) ?_
      intro view hMem
      simp
  constructor
  · simpa [oramToSGXSemantics, sgxStorageDistribution] using
      (oramLocalTheorem_projects_to_sgxStorage cfg₁ cfg₂ (run cfg₁) (run cfg₂) hPublic (hOram cfg₁ cfg₂ hPublic))
  · apply exactProjectionRelation_of_constant (hMicro cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const id (microTrace cfg₁) sgxMicroTrace ((oramToSGXSemantics run publicOutcome boundarySchedule microTrace) cfg₁) ?_
      intro view hMem
      have hMapped : view ∈ (run cfg₁).map (sgxViewOfOramView cfg₁ (publicOutcome cfg₁) (boundarySchedule cfg₁) (microTrace cfg₁)) := by
        simpa [oramToSGXSemantics] using hMem
      rcases List.mem_map.mp hMapped with ⟨sourceView, hSource, hEq⟩
      rw [← hEq]
      simp
    · refine constantProjection_map_of_const id (microTrace cfg₂) sgxMicroTrace ((oramToSGXSemantics run publicOutcome boundarySchedule microTrace) cfg₂) ?_
      intro view hMem
      have hMapped : view ∈ (run cfg₂).map (sgxViewOfOramView cfg₂ (publicOutcome cfg₂) (boundarySchedule cfg₂) (microTrace cfg₂)) := by
        simpa [oramToSGXSemantics] using hMem
      rcases List.mem_map.mp hMapped with ⟨sourceView, hSource, hEq⟩
      rw [← hEq]
      simp

end UOToolchain
