import UOToolchain.SgxMicroGame
import UOToolchain.SgxOramProjection

namespace UOToolchain

structure SGXJointSample where
  storageView : ViewMPlus
  microTrace : SGXMicroTrace
deriving Repr, DecidableEq

abbrev SGXJointSemantics := OramConfig → Distribution SGXJointSample

def jointStorageViews (samples : Distribution SGXJointSample) : Distribution ViewMPlus :=
  samples.map SGXJointSample.storageView

def jointMicroViews (samples : Distribution SGXJointSample) : Distribution SGXMicroTrace :=
  samples.map SGXJointSample.microTrace

def sgxViewOfJointSample
  (_cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (sample : SGXJointSample) : SGXView :=
  let storage := sgxStorageOfOramView sample.storageView
  { entrypointId := publicOutcome.entrypointId
  , publicArgs := publicOutcome.publicArgs
  , boundarySchedule := boundarySchedule
  , persistentReads := storage.persistentReads
  , persistentWrites := storage.persistentWrites
  , pageTrace := sample.microTrace.pageTrace
  , exitTrace := sample.microTrace.exitTrace
  , sharedResourceTrace := sample.microTrace.sharedResourceTrace
  , terminationStatus := publicOutcome.terminationStatus
  , outputShape := publicOutcome.outputShape
  , gasUsed := publicOutcome.gasUsed
  }

def jointToSGXSemantics
  (run : SGXJointSemantics)
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (boundarySchedule : OramConfig → List BoundaryEvent) :
  SGXSemantics OramConfig :=
  fun cfg => (run cfg).map (sgxViewOfJointSample cfg (publicOutcome cfg) (boundarySchedule cfg))

@[simp] theorem sgxPublicOutcome_sgxViewOfJointSample
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (sample : SGXJointSample) :
  sgxPublicOutcome (sgxViewOfJointSample cfg publicOutcome boundarySchedule sample) = publicOutcome := by
  cases publicOutcome
  cases sample
  rfl

@[simp] theorem sgxBoundary_sgxViewOfJointSample
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (sample : SGXJointSample) :
  (sgxViewOfJointSample cfg publicOutcome boundarySchedule sample).boundarySchedule = boundarySchedule := by
  cases publicOutcome
  cases sample
  rfl

@[simp] theorem sgxStorageTrace_sgxViewOfJointSample
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (sample : SGXJointSample) :
  sgxStorageTrace (sgxViewOfJointSample cfg publicOutcome boundarySchedule sample) =
    sgxStorageOfOramView sample.storageView := by
  cases publicOutcome
  cases sample
  rfl

@[simp] theorem sgxMicroTrace_sgxViewOfJointSample
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (sample : SGXJointSample) :
  sgxMicroTrace (sgxViewOfJointSample cfg publicOutcome boundarySchedule sample) = sample.microTrace := by
  cases publicOutcome
  cases sample
  rfl

def jointMicroLeakage
  (microLeakage : OramConfig → SGXMicroLeakage) : OramConfig → SGXMicroLeakage :=
  microLeakage

def OramPublicMicroLeakageSafe (microLeakage : OramConfig → SGXMicroLeakage) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → microLeakage cfg₁ = microLeakage cfg₂

theorem jointMicroLeakage_public
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hPublic : OramPublicMicroLeakageSafe microLeakage) :
  PublicMicroLeakage sameOramPublicProjection (jointMicroLeakage microLeakage) := by
  intro cfg₁ cfg₂ hSame
  exact hPublic cfg₁ cfg₂ hSame

theorem jointStorageTheorem_projects_to_sgxStorage
  (cfg₁ cfg₂ : OramConfig)
  (samples₁ samples₂ : Distribution SGXJointSample) :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramLocalTheorem (jointStorageViews samples₁) (jointStorageViews samples₂) (executionLeakage cfg₁) →
  oramSGXStorageRelation
    ((jointStorageViews samples₁).map sgxStorageOfOramView)
    ((jointStorageViews samples₂).map sgxStorageOfOramView)
    (executionLeakage cfg₁) := by
  intro hPublic hLocal
  exact ⟨cfg₁, cfg₂, jointStorageViews samples₁, jointStorageViews samples₂, hPublic, rfl, hLocal, rfl, rfl⟩

theorem jointMicroTheorem_projects_to_sgxMicro
  (samples₁ samples₂ : Distribution SGXJointSample)
  (leakage : SGXMicroLeakage) :
  sgxMicroLocalTheorem (jointMicroViews samples₁) (jointMicroViews samples₂) leakage →
  computationalSGXMicroRelation
    (jointMicroViews samples₁)
    (jointMicroViews samples₂)
    leakage := by
  intro h
  exact h

theorem jointSecurity_projects_to_sgxExecution
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      oramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      sgxMicroLocalTheorem (jointMicroViews (run cfg₁)) (jointMicroViews (run cfg₂)) (microLeakage cfg₁))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelation, microRel := computationalSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  intro cfg₁ cfg₂ hPublic
  have _ := hMicroLeakage cfg₁ cfg₂ hPublic
  constructor
  · apply exactProjectionRelation_of_constant (hOutcome cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₁) _ (run cfg₁) ?_
      intro sample hMem
      simp
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₂) _ (run cfg₂) ?_
      intro sample hMem
      simp
  constructor
  · apply exactProjectionRelation_of_constant (hBoundary cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) (boundarySchedule cfg₁) _ (run cfg₁) ?_
      intro sample hMem
      simp
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) (boundarySchedule cfg₂) _ (run cfg₂) ?_
      intro sample hMem
      simp
  constructor
  · simpa [jointToSGXSemantics, sgxStorageDistribution, jointStorageViews, List.map_map] using
      (jointStorageTheorem_projects_to_sgxStorage
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hStorage cfg₁ cfg₂ hPublic))
  · simpa [jointToSGXSemantics, jointMicroViews, jointMicroLeakage, sgxMicroDistribution, List.map_map] using
      (jointMicroTheorem_projects_to_sgxMicro
        (run cfg₁)
        (run cfg₂)
        (microLeakage cfg₁)
        (hMicro cfg₁ cfg₂ hPublic))

theorem jointSecurity_projects_to_sgxExecution_with_oramController
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      oramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      sgxMicroLocalTheorem
        (jointMicroViews (run cfg₁))
        (jointMicroViews (run cfg₂))
        (oramMicroLeakage publicOutcome modelTags cfg₁))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelation, microRel := computationalSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage (oramMicroLeakage publicOutcome modelTags)) := by
  apply jointSecurity_projects_to_sgxExecution hStorage hMicro hOutcome hBoundary
  exact oramMicroLeakage_public hOutcome

theorem jointSecurity_projects_to_sgxExecution_with_normalizedMicro
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      oramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg,
      NormalizedByLeakage
        (jointMicroViews (run cfg))
        (microLeakage cfg))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelation, microRel := normalizedObservedSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  intro cfg₁ cfg₂ hPublic
  have _ := hMicroLeakage cfg₁ cfg₂ hPublic
  constructor
  · apply exactProjectionRelation_of_constant (hOutcome cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₁) _ (run cfg₁) ?_
      intro sample hMem
      simp
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₂) _ (run cfg₂) ?_
      intro sample hMem
      simp
  constructor
  · apply exactProjectionRelation_of_constant (hBoundary cfg₁ cfg₂ hPublic)
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) (boundarySchedule cfg₁) _ (run cfg₁) ?_
      intro sample hMem
      simp
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) (boundarySchedule cfg₂) _ (run cfg₂) ?_
      intro sample hMem
      simp
  constructor
  · simpa [jointToSGXSemantics, sgxStorageDistribution, jointStorageViews, List.map_map] using
      (jointStorageTheorem_projects_to_sgxStorage
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hStorage cfg₁ cfg₂ hPublic))
  · change
      NormalizedByLeakage
        (sgxMicroDistribution
          ((jointToSGXSemantics run publicOutcome boundarySchedule) cfg₁))
        (jointMicroLeakage microLeakage cfg₁) ∧
      NormalizedByLeakage
        (sgxMicroDistribution
          ((jointToSGXSemantics run publicOutcome boundarySchedule) cfg₂))
        (jointMicroLeakage microLeakage cfg₁)
    constructor
    · simpa [jointToSGXSemantics, jointMicroViews, jointMicroLeakage, sgxMicroDistribution, List.map_map] using
        hMicro cfg₁
    · exact normalizedByLeakage_of_eq
        (hMicroLeakage cfg₂ cfg₁ (sameOramPublicProjection_symm hPublic))
        (by
          simpa [jointToSGXSemantics, jointMicroViews, jointMicroLeakage, sgxMicroDistribution, List.map_map] using
            hMicro cfg₂)

/-- Paper-facing joint theorem profile:
exact public boundary schedule plus normalized SGX micro observer. -/
theorem paperMain_jointSecurity_projects_to_sgxExecution
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      oramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg,
      NormalizedByLeakage
        (jointMicroViews (run cfg))
        (microLeakage cfg))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelation, microRel := normalizedObservedSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact jointSecurity_projects_to_sgxExecution_with_normalizedMicro
    hStorage hMicro hOutcome hBoundary hMicroLeakage

end UOToolchain
