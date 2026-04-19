import UOToolchain.SgxJointProjection
import UOToolchain.LegacySgxOramProjection
import UOToolchain.SgxMicroGame
import UOToolchain.OramGame

namespace UOToolchain

theorem legacyJointStorageTheorem_projects_to_sgxStorage
  (cfg₁ cfg₂ : OramConfig)
  (samples₁ samples₂ : Distribution SGXJointSample) :
  sameOramPublicProjection cfg₁ cfg₂ →
  legacyOramLocalTheorem (jointStorageViews samples₁) (jointStorageViews samples₂) (executionLeakage cfg₁) →
  legacyOramSGXStorageRelation
    ((jointStorageViews samples₁).map sgxStorageOfOramView)
    ((jointStorageViews samples₂).map sgxStorageOfOramView)
    (executionLeakage cfg₁) := by
  exact
    jointStorageTheoremWith_projects_to_sgxStorage
      legacyOramSecurityInterface
      cfg₁
      cfg₂
      samples₁
      samples₂

theorem legacyJointMicroTheorem_projects_to_sgxMicro
  (samples₁ samples₂ : Distribution SGXJointSample)
  (leakage : SGXMicroLeakage) :
  legacySgxMicroLocalTheorem (jointMicroViews samples₁) (jointMicroViews samples₂) leakage →
  legacyComputationalSGXMicroRelation
    (jointMicroViews samples₁)
    (jointMicroViews samples₂)
    leakage := by
  intro h
  exact h

theorem legacyJointSecurityWith_projects_to_sgxExecution
  (security : OramSecurityInterface)
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      security.localTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacySgxMicroLocalTheorem (jointMicroViews (run cfg₁)) (jointMicroViews (run cfg₂)) (microLeakage cfg₁))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelationWith security, microRel := legacyComputationalSGXMicroRelation }
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
      (jointStorageTheoremWith_projects_to_sgxStorage
        security
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hStorage cfg₁ cfg₂ hPublic))
  · simpa [jointToSGXSemantics, jointMicroViews, jointMicroLeakage, sgxMicroDistribution, List.map_map] using
      (legacyJointMicroTheorem_projects_to_sgxMicro
        (run cfg₁)
        (run cfg₂)
        (microLeakage cfg₁)
        (hMicro cfg₁ cfg₂ hPublic))

theorem legacyJointSecurity_projects_to_sgxExecution
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacyOramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacySgxMicroLocalTheorem (jointMicroViews (run cfg₁)) (jointMicroViews (run cfg₂)) (microLeakage cfg₁))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := legacyOramSGXStorageRelation, microRel := legacyComputationalSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact
    legacyJointSecurityWith_projects_to_sgxExecution
      legacyOramSecurityInterface
      hStorage
      hMicro
      hOutcome
      hBoundary
      hMicroLeakage

theorem legacyJointSecurityWith_projects_to_sgxExecution_with_oramController
  (security : OramSecurityInterface)
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      security.localTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacySgxMicroLocalTheorem
        (jointMicroViews (run cfg₁))
        (jointMicroViews (run cfg₂))
        (oramMicroLeakage publicOutcome modelTags cfg₁))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelationWith security, microRel := legacyComputationalSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage (oramMicroLeakage publicOutcome modelTags)) := by
  apply legacyJointSecurityWith_projects_to_sgxExecution security hStorage hMicro hOutcome hBoundary
  exact oramMicroLeakage_public hOutcome

theorem legacyJointSecurity_projects_to_sgxExecution_with_oramController
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacyOramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacySgxMicroLocalTheorem
        (jointMicroViews (run cfg₁))
        (jointMicroViews (run cfg₂))
        (oramMicroLeakage publicOutcome modelTags cfg₁))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := legacyOramSGXStorageRelation, microRel := legacyComputationalSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage (oramMicroLeakage publicOutcome modelTags)) := by
  exact
    legacyJointSecurityWith_projects_to_sgxExecution_with_oramController
      legacyOramSecurityInterface
      hStorage
      hMicro
      hOutcome
      hBoundary

theorem legacyJointSecurity_projects_to_sgxExecution_with_normalizedMicro
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacyOramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
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
    { storageRel := legacyOramSGXStorageRelation, microRel := normalizedObservedSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact
    jointSecurityWith_projects_to_sgxExecution_with_normalizedMicro
      legacyOramSecurityInterface
      hStorage
      hMicro
      hOutcome
      hBoundary
      hMicroLeakage

theorem legacyPaperMain_jointSecurity_projects_to_sgxExecution
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacyOramLocalTheorem (jointStorageViews (run cfg₁)) (jointStorageViews (run cfg₂)) (executionLeakage cfg₁))
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
    { storageRel := legacyOramSGXStorageRelation, microRel := normalizedObservedSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact
    paperMain_jointSecurityWith_projects_to_sgxExecution
      legacyOramSecurityInterface
      hStorage
      hMicro
      hOutcome
      hBoundary
      hMicroLeakage

end UOToolchain
