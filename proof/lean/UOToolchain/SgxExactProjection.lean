import UOToolchain.SgxOramProjection

namespace UOToolchain

def PublicOutcomeSafe (publicOutcome : Config → SGXPublicOutcome) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂

def PublicBoundarySafe (boundarySchedule : Config → List BoundaryEvent) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → boundarySchedule cfg₁ = boundarySchedule cfg₂

def PublicControllerShapeSafe (controllerShape : Config → SGXControllerShape) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → controllerShape cfg₁ = controllerShape cfg₂

def PublicMicroTraceSafe (microTrace : Config → SGXMicroTrace) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → microTrace cfg₁ = microTrace cfg₂

def sgxViewOfTrace
  (_cfg : Config)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (microTrace : SGXMicroTrace)
  (trace : Trace) : SGXView :=
  { entrypointId := publicOutcome.entrypointId
  , publicArgs := publicOutcome.publicArgs
  , boundarySchedule := boundarySchedule
  , persistentReads := trace.physicalReads
  , persistentWrites := trace.physicalWrites
  , pageTrace := microTrace.pageTrace
  , exitTrace := microTrace.exitTrace
  , sharedResourceTrace := microTrace.sharedResourceTrace
  , terminationStatus := publicOutcome.terminationStatus
  , outputShape := publicOutcome.outputShape
  , gasUsed := publicOutcome.gasUsed
  }

def exactToSGXSemantics
  (run : Semantics)
  (publicOutcome : Config → SGXPublicOutcome)
  (boundarySchedule : Config → List BoundaryEvent)
  (microTrace : Config → SGXMicroTrace) :
  SGXSemantics Config :=
  fun cfg => [sgxViewOfTrace cfg (publicOutcome cfg) (boundarySchedule cfg) (microTrace cfg) (run cfg)]

def exactMicroLeakage
  (publicOutcome : Config → SGXPublicOutcome)
  (controllerShape : Config → SGXControllerShape)
  (modelTags : SGXModelTags) : Config → SGXMicroLeakage :=
  fun cfg => sgxMicroLeakageOfController (publicOutcome cfg) modelTags (controllerShape cfg)

def exactNormalizedObservedSGXProofRelation : SGXProofRelation :=
  { storageRel := exactSGXStorageRelation
  , microRel := normalizedObservedSGXMicroRelation
  }

theorem sgxViewOfTrace_eq_of_trace_eq
  {cfg₁ cfg₂ : Config}
  {publicOutcome₁ publicOutcome₂ : SGXPublicOutcome}
  {boundary₁ boundary₂ : List BoundaryEvent}
  {micro₁ micro₂ : SGXMicroTrace}
  {trace₁ trace₂ : Trace}
  (hOutcome : publicOutcome₁ = publicOutcome₂)
  (hBoundary : boundary₁ = boundary₂)
  (hMicro : micro₁ = micro₂)
  (hTrace : trace₁ = trace₂) :
  sgxViewOfTrace cfg₁ publicOutcome₁ boundary₁ micro₁ trace₁ =
    sgxViewOfTrace cfg₂ publicOutcome₂ boundary₂ micro₂ trace₂ := by
  subst hOutcome
  subst hBoundary
  subst hMicro
  subst hTrace
  rfl

theorem exactMicroLeakage_public
  {publicOutcome : Config → SGXPublicOutcome}
  {controllerShape : Config → SGXControllerShape}
  {modelTags : SGXModelTags}
  (hOutcome : PublicOutcomeSafe publicOutcome)
  (hController : PublicControllerShapeSafe controllerShape) :
  PublicMicroLeakage samePublicProjection (exactMicroLeakage publicOutcome controllerShape modelTags) := by
  intro cfg₁ cfg₂ hPublic
  apply sgxMicroLeakageOfController_eq_of_eq
  · exact hOutcome cfg₁ cfg₂ hPublic
  · rfl
  · exact hController cfg₁ cfg₂ hPublic

theorem exactControllerMicroTrace_public
  {controllerShape : Config → SGXControllerShape}
  (hController : PublicControllerShapeSafe controllerShape) :
  PublicMicroTraceSafe (fun cfg => controllerMicroTraceOfShape (controllerShape cfg)) := by
  intro cfg₁ cfg₂ hPublic
  apply controllerMicroTraceOfShape_eq_of_eq
  exact hController cfg₁ cfg₂ hPublic

theorem exactControllerMicroDistribution_normalized
  {run : Semantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {modelTags : SGXModelTags}
  (cfg : Config) :
  NormalizedByLeakage
    (sgxMicroDistribution
      ((exactToSGXSemantics
        run
        publicOutcome
        boundarySchedule
        (fun cfg => controllerMicroTraceOfShape (controllerShape cfg))) cfg))
    (exactMicroLeakage publicOutcome controllerShape modelTags cfg) := by
  intro trace hMem
  simp [exactToSGXSemantics, sgxMicroDistribution] at hMem
  rcases hMem with rfl
  simpa [exactMicroLeakage] using
    normalizeMicroTrace_controllerMicroTraceOfShape
      (publicOutcome cfg)
      modelTags
      (controllerShape cfg)

theorem exactUO_projects_to_sgxExecution
  {run : Semantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {microTrace : Config → SGXMicroTrace}
  {modelTags : SGXModelTags}
  (hExact : ExactUO run)
  (hOutcome : PublicOutcomeSafe publicOutcome)
  (hBoundary : PublicBoundarySafe boundarySchedule)
  (hController : PublicControllerShapeSafe controllerShape)
  (hMicro : PublicMicroTraceSafe microTrace) :
  SGXExecutionSecurity
    samePublicProjection
    exactSGXProofRelation
    (exactToSGXSemantics run publicOutcome boundarySchedule microTrace)
    emptyStorageLeakage
    (exactMicroLeakage publicOutcome controllerShape modelTags) := by
  intro cfg₁ cfg₂ hPublic
  have _ := hController cfg₁ cfg₂ hPublic
  have hTrace : run cfg₁ = run cfg₂ :=
    viewMPlus_injective (hExact cfg₁ cfg₂ hPublic)
  have hOutcomeEq : publicOutcome cfg₁ = publicOutcome cfg₂ :=
    hOutcome cfg₁ cfg₂ hPublic
  have hBoundaryEq : boundarySchedule cfg₁ = boundarySchedule cfg₂ :=
    hBoundary cfg₁ cfg₂ hPublic
  have hMicroEq : microTrace cfg₁ = microTrace cfg₂ :=
    hMicro cfg₁ cfg₂ hPublic
  have hView :
      sgxViewOfTrace cfg₁ (publicOutcome cfg₁) (boundarySchedule cfg₁) (microTrace cfg₁) (run cfg₁) =
        sgxViewOfTrace cfg₂ (publicOutcome cfg₂) (boundarySchedule cfg₂) (microTrace cfg₂) (run cfg₂) :=
    sgxViewOfTrace_eq_of_trace_eq hOutcomeEq hBoundaryEq hMicroEq hTrace
  simpa [exactToSGXSemantics] using
    exactSGXViewRelation_of_singleton_eq hView [] (exactMicroLeakage publicOutcome controllerShape modelTags cfg₁)

theorem exactUO_projects_to_sgxExecution_with_normalizedController
  {run : Semantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {modelTags : SGXModelTags}
  (hExact : ExactUO run)
  (hOutcome : PublicOutcomeSafe publicOutcome)
  (hBoundary : PublicBoundarySafe boundarySchedule)
  (hController : PublicControllerShapeSafe controllerShape) :
  SGXExecutionSecurity
    samePublicProjection
    exactNormalizedObservedSGXProofRelation
    (exactToSGXSemantics
      run
      publicOutcome
      boundarySchedule
      (fun cfg => controllerMicroTraceOfShape (controllerShape cfg)))
    emptyStorageLeakage
    (exactMicroLeakage publicOutcome controllerShape modelTags) := by
  intro cfg₁ cfg₂ hPublic
  have hTrace : run cfg₁ = run cfg₂ :=
    viewMPlus_injective (hExact cfg₁ cfg₂ hPublic)
  have hOutcomeEq : publicOutcome cfg₁ = publicOutcome cfg₂ :=
    hOutcome cfg₁ cfg₂ hPublic
  have hBoundaryEq : boundarySchedule cfg₁ = boundarySchedule cfg₂ :=
    hBoundary cfg₁ cfg₂ hPublic
  have hControllerEq : controllerShape cfg₁ = controllerShape cfg₂ :=
    hController cfg₁ cfg₂ hPublic
  have hMicroEq :
      controllerMicroTraceOfShape (controllerShape cfg₁) =
        controllerMicroTraceOfShape (controllerShape cfg₂) :=
    controllerMicroTraceOfShape_eq_of_eq hControllerEq
  have hView :
      sgxViewOfTrace
          cfg₁
          (publicOutcome cfg₁)
          (boundarySchedule cfg₁)
          (controllerMicroTraceOfShape (controllerShape cfg₁))
          (run cfg₁) =
        sgxViewOfTrace
          cfg₂
          (publicOutcome cfg₂)
          (boundarySchedule cfg₂)
          (controllerMicroTraceOfShape (controllerShape cfg₂))
          (run cfg₂) :=
    sgxViewOfTrace_eq_of_trace_eq hOutcomeEq hBoundaryEq hMicroEq hTrace
  constructor
  · simpa [exactToSGXSemantics] using
      exactProjectionRelation_singleton
        sgxPublicOutcome
        (sgxViewOfTrace
          cfg₁
          (publicOutcome cfg₁)
          (boundarySchedule cfg₁)
          (controllerMicroTraceOfShape (controllerShape cfg₁))
          (run cfg₁))
        (sgxViewOfTrace
          cfg₂
          (publicOutcome cfg₂)
          (boundarySchedule cfg₂)
          (controllerMicroTraceOfShape (controllerShape cfg₂))
          (run cfg₂))
        (by simp [hView])
  constructor
  · simpa [exactToSGXSemantics] using
      exactProjectionRelation_singleton
        (fun view : SGXView => view.boundarySchedule)
        (sgxViewOfTrace
          cfg₁
          (publicOutcome cfg₁)
          (boundarySchedule cfg₁)
          (controllerMicroTraceOfShape (controllerShape cfg₁))
          (run cfg₁))
        (sgxViewOfTrace
          cfg₂
          (publicOutcome cfg₂)
          (boundarySchedule cfg₂)
          (controllerMicroTraceOfShape (controllerShape cfg₂))
          (run cfg₂))
        (by simp [hView])
  constructor
  · simp [exactNormalizedObservedSGXProofRelation, exactSGXStorageRelation, exactToSGXSemantics, hView]
  · change
      NormalizedByLeakage
        (sgxMicroDistribution
          ((exactToSGXSemantics
            run
            publicOutcome
            boundarySchedule
            (fun cfg => controllerMicroTraceOfShape (controllerShape cfg))) cfg₁))
        (exactMicroLeakage publicOutcome controllerShape modelTags cfg₁) ∧
      NormalizedByLeakage
        (sgxMicroDistribution
          ((exactToSGXSemantics
            run
            publicOutcome
            boundarySchedule
            (fun cfg => controllerMicroTraceOfShape (controllerShape cfg))) cfg₂))
        (exactMicroLeakage publicOutcome controllerShape modelTags cfg₁)
    constructor
    · exact exactControllerMicroDistribution_normalized (run := run) (cfg := cfg₁)
    · exact normalizedByLeakage_of_eq
        (exactMicroLeakage_public hOutcome hController cfg₂ cfg₁ (samePublicProjection_symm hPublic))
        (exactControllerMicroDistribution_normalized
          (run := run)
          (cfg := cfg₂))

/-- Paper-facing main theorem profile:
exact public boundary schedule plus normalized SGX micro observer. -/
theorem paperMain_exactUO_projects_to_sgxExecution
  {run : Semantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {modelTags : SGXModelTags}
  (hExact : ExactUO run)
  (hOutcome : PublicOutcomeSafe publicOutcome)
  (hBoundary : PublicBoundarySafe boundarySchedule)
  (hController : PublicControllerShapeSafe controllerShape) :
  SGXExecutionSecurity
    samePublicProjection
    exactNormalizedObservedSGXProofRelation
    (exactToSGXSemantics
      run
      publicOutcome
      boundarySchedule
      (fun cfg => controllerMicroTraceOfShape (controllerShape cfg)))
    emptyStorageLeakage
    (exactMicroLeakage publicOutcome controllerShape modelTags) := by
  exact exactUO_projects_to_sgxExecution_with_normalizedController
    hExact hOutcome hBoundary hController

end UOToolchain
