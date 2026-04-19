import UOToolchain.OramModel
import UOToolchain.SgxMicroModel

namespace UOToolchain

def sgxStorageOfOramView (view : ViewMPlus) : SGXStorageTrace :=
  match view with
  | (_opcodeTrace, _logicalAccesses, _logicalWrites, persistentReads, persistentWrites, _gasUsed) =>
      { persistentReads := persistentReads
      , persistentWrites := persistentWrites
      }

def publicSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ _leakage => ExactProjectionRelation id micro₁ micro₂

def oramSGXStorageRelationWith (security : OramSecurityInterface) : SGXStorageRelation :=
  fun storage₁ storage₂ leakage =>
    ∃ cfg₁ cfg₂ view₁ view₂,
      sameOramPublicProjection cfg₁ cfg₂ ∧
      leakage = executionLeakage cfg₁ ∧
      security.localTheorem view₁ view₂ leakage ∧
      storage₁ = view₁.map sgxStorageOfOramView ∧
      storage₂ = view₂.map sgxStorageOfOramView

def oramSGXProofRelationWith (security : OramSecurityInterface) : SGXProofRelation :=
  { storageRel := oramSGXStorageRelationWith security
  , microRel := publicSGXMicroRelation
  }

def oramBudgetSGXProofRelationWith (security : OramSecurityInterface) : SGXProofRelation :=
  { storageRel := oramSGXStorageRelationWith security
  , microRel := budgetConsistentSGXMicroRelation
  }

def oramCanonicalizedSGXProofRelationWith (security : OramSecurityInterface) : SGXProofRelation :=
  { storageRel := oramSGXStorageRelationWith security
  , microRel := canonicalizedSGXMicroRelation
  }

def oramNormalizedObservedSGXProofRelationWith (security : OramSecurityInterface) : SGXProofRelation :=
  { storageRel := oramSGXStorageRelationWith security
  , microRel := normalizedObservedSGXMicroRelation
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

theorem oramSecurity_projects_to_sgxStorage
  (security : OramSecurityInterface)
  (cfg₁ cfg₂ : OramConfig)
  (view₁ view₂ : Distribution ViewMPlus) :
  sameOramPublicProjection cfg₁ cfg₂ →
  security.localTheorem view₁ view₂ (executionLeakage cfg₁) →
  oramSGXStorageRelationWith security
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

theorem oramControllerMicroTrace_public :
  OramPublicMicroTraceSafe oramControllerMicroTrace := by
  intro cfg₁ cfg₂ hPublic
  exact oramControllerMicroTrace_eq_of_samePublicProjection hPublic

theorem oramControllerMicroDistribution_consistent
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (cfg : OramConfig) :
  MicroDistributionConsistentWithLeakage
    (sgxMicroDistribution
      ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg))
    (oramMicroLeakage publicOutcome modelTags cfg) := by
  intro trace hMem
  have hMapped :
      trace ∈
        (run cfg).map
          (fun sourceView =>
            sgxMicroTrace
              (sgxViewOfOramView
                cfg
                (publicOutcome cfg)
                (boundarySchedule cfg)
                (oramControllerMicroTrace cfg)
                sourceView)) := by
    simpa [oramToSGXSemantics, sgxMicroDistribution] using hMem
  rcases List.mem_map.mp hMapped with ⟨sourceView, _hSource, hEq⟩
  rw [← hEq]
  simpa using oramControllerMicroTrace_consistentWithLeakage cfg publicOutcome modelTags

theorem oramControllerMicroDistribution_canonicalized
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (cfg : OramConfig) :
  CanonicalizedByLeakage
    (sgxMicroDistribution
      ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg))
    (oramMicroLeakage publicOutcome modelTags cfg) := by
  exact canonicalizedByLeakage_of_consistent
    (oramControllerMicroDistribution_consistent
      (run := run)
      (cfg := cfg))

theorem oramControllerMicroDistribution_normalized
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (cfg : OramConfig) :
  NormalizedByLeakage
    (sgxMicroDistribution
      ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg))
    (oramMicroLeakage publicOutcome modelTags cfg) := by
  intro trace hMem
  have hMapped :
      trace ∈
        (run cfg).map
          (fun sourceView =>
            sgxMicroTrace
              (sgxViewOfOramView
                cfg
                (publicOutcome cfg)
                (boundarySchedule cfg)
                (oramControllerMicroTrace cfg)
                sourceView)) := by
    simpa [oramToSGXSemantics, sgxMicroDistribution] using hMem
  rcases List.mem_map.mp hMapped with ⟨sourceView, _hSource, hEq⟩
  rw [← hEq]
  simpa [oramControllerMicroTrace, oramControllerShape] using
    normalizeMicroTrace_controllerMicroTraceOfShape
      (publicOutcome cfg)
      modelTags
      (sgxControllerShapeOfExecutionLeakage (executionLeakage cfg))

theorem oramStorageLeakage_public :
  PublicStorageLeakage sameOramPublicProjection executionLeakage := by
  intro cfg₁ cfg₂ hPublic
  exact executionLeakage_eq_of_samePublicProjection hPublic

theorem computationalUOWith_projects_to_sgxExecution
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microTrace : OramConfig → SGXMicroTrace}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicro : OramPublicMicroTraceSafe microTrace) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramSGXProofRelationWith security)
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
      (oramSecurity_projects_to_sgxStorage
        security
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hOram cfg₁ cfg₂ hPublic))
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

theorem computationalUOWith_projects_to_sgxExecution_with_controller
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramSGXProofRelationWith security)
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  apply computationalUOWith_projects_to_sgxExecution security hOram hOutcome hBoundary
  exact oramControllerMicroTrace_public

theorem computationalUOWith_projects_to_sgxExecution_with_budgetController
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramBudgetSGXProofRelationWith security)
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
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
      (oramSecurity_projects_to_sgxStorage
        security
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hOram cfg₁ cfg₂ hPublic))
  · change
      MicroDistributionConsistentWithLeakage
        (sgxMicroDistribution
          ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₁))
        (oramMicroLeakage publicOutcome modelTags cfg₁) ∧
      MicroDistributionConsistentWithLeakage
        (sgxMicroDistribution
          ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₂))
        (oramMicroLeakage publicOutcome modelTags cfg₁)
    constructor
    · exact oramControllerMicroDistribution_consistent (run := run) (cfg := cfg₁)
    · exact microDistributionConsistentWithLeakage_of_eq
        (oramMicroLeakage_public hOutcome cfg₂ cfg₁ (sameOramPublicProjection_symm hPublic))
        (oramControllerMicroDistribution_consistent
          (run := run)
          (cfg := cfg₂))

theorem computationalUOWith_projects_to_sgxExecution_with_canonicalController
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramCanonicalizedSGXProofRelationWith security)
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
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
      (oramSecurity_projects_to_sgxStorage
        security
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hOram cfg₁ cfg₂ hPublic))
  · change
      CanonicalizedByLeakage
        (sgxMicroDistribution
          ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₁))
        (oramMicroLeakage publicOutcome modelTags cfg₁) ∧
      CanonicalizedByLeakage
        (sgxMicroDistribution
          ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₂))
        (oramMicroLeakage publicOutcome modelTags cfg₁)
    constructor
    · exact oramControllerMicroDistribution_canonicalized (run := run) (cfg := cfg₁)
    · intro trace hMem
      have hCanon :=
        oramControllerMicroDistribution_canonicalized
          (run := run)
          (modelTags := modelTags)
          (cfg := cfg₂)
          trace
          hMem
      have hLeakageEq :
          oramMicroLeakage publicOutcome modelTags cfg₂ =
            oramMicroLeakage publicOutcome modelTags cfg₁ :=
        oramMicroLeakage_public hOutcome cfg₂ cfg₁ (sameOramPublicProjection_symm hPublic)
      simpa [hLeakageEq] using hCanon

theorem computationalUOWith_projects_to_sgxExecution_with_normalizedController
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramNormalizedObservedSGXProofRelationWith security)
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
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
      (oramSecurity_projects_to_sgxStorage
        security
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hOram cfg₁ cfg₂ hPublic))
  · change
      NormalizedByLeakage
        (sgxMicroDistribution
          ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₁))
        (oramMicroLeakage publicOutcome modelTags cfg₁) ∧
      NormalizedByLeakage
        (sgxMicroDistribution
          ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₂))
        (oramMicroLeakage publicOutcome modelTags cfg₁)
    constructor
    · exact oramControllerMicroDistribution_normalized (run := run) (cfg := cfg₁)
    · exact normalizedByLeakage_of_eq
        (oramMicroLeakage_public hOutcome cfg₂ cfg₁ (sameOramPublicProjection_symm hPublic))
        (oramControllerMicroDistribution_normalized
          (run := run)
          (cfg := cfg₂))

/-- Paper-facing main theorem profile:
exact public boundary schedule plus normalized SGX micro observer. -/
theorem paperMain_computationalUOWith_projects_to_sgxExecution
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramNormalizedObservedSGXProofRelationWith security)
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    computationalUOWith_projects_to_sgxExecution_with_normalizedController
      security
      hOram
      hOutcome
      hBoundary

end UOToolchain
