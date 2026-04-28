import UOToolchain.SgxOramProjection

/-! # Exact UO → SGX projection layer

This file projects the exact-UO trace semantics into the SGX execution view
under the paper-facing normalized SGX micro observer.

* **Abstraction function:** `exactToSGXSemantics` (lifts `TraceSemantics` to
  `SGXSemantics Config` via `sgxViewOfTrace`).
* **Main theorem:** `paperMain_exactUO_projects_to_sgxExecution` —
  obliviousness of the exact-UO run lifts to `SGXExecutionSecurity` against
  `exactNormalizedObservedSGXProofRelation`.

All other declarations in this file are file-local helpers used by the proof
body `exactUO_projects_to_sgxExecution_with_normalizedController`. The
paper-facing entry point in `ProofGrade.lean` is
`proofGrade_sgx_projection_paper_main_exact_uo`.
-/

namespace UOToolchain

def PublicOutcomeSafe (publicOutcome : Config → SGXPublicOutcome) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂

def PublicBoundarySafe (boundarySchedule : Config → List BoundaryEvent) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → boundarySchedule cfg₁ = boundarySchedule cfg₂

def PublicControllerShapeSafe (controllerShape : Config → SGXControllerShape) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → controllerShape cfg₁ = controllerShape cfg₂

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
  , statusPolicy := publicOutcome.statusPolicy
  , outputShape := publicOutcome.outputShape
  , returnPolicy := publicOutcome.returnPolicy
  , returnPayload := publicOutcome.returnPayload
  , declassifies := publicOutcome.declassifies
  , gasUsed := publicOutcome.gasUsed
  }

def exactToSGXSemantics
  (run : TraceSemantics)
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

theorem exactControllerMicroDistribution_normalized
  {run : TraceSemantics}
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

/-- Internal proof body of `paperMain_exactUO_projects_to_sgxExecution`. -/
theorem exactUO_projects_to_sgxExecution_with_normalizedController
  {run : TraceSemantics}
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
  {run : TraceSemantics}
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
