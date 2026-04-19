import UOToolchain.SgxOramProjection
import UOToolchain.OramGame

namespace UOToolchain

abbrev legacyOramSGXStorageRelation : SGXStorageRelation :=
  oramSGXStorageRelationWith legacyOramSecurityInterface

abbrev legacyOramSGXProofRelation : SGXProofRelation :=
  oramSGXProofRelationWith legacyOramSecurityInterface

abbrev legacyOramBudgetSGXProofRelation : SGXProofRelation :=
  oramBudgetSGXProofRelationWith legacyOramSecurityInterface

abbrev legacyOramCanonicalizedSGXProofRelation : SGXProofRelation :=
  oramCanonicalizedSGXProofRelationWith legacyOramSecurityInterface

abbrev legacyOramNormalizedObservedSGXProofRelation : SGXProofRelation :=
  oramNormalizedObservedSGXProofRelationWith legacyOramSecurityInterface

theorem legacyOramLocalTheorem_projects_to_sgxStorage
  (cfg₁ cfg₂ : OramConfig)
  (view₁ view₂ : Distribution ViewMPlus) :
  sameOramPublicProjection cfg₁ cfg₂ →
  legacyOramLocalTheorem view₁ view₂ (executionLeakage cfg₁) →
  legacyOramSGXStorageRelation
    (view₁.map sgxStorageOfOramView)
    (view₂.map sgxStorageOfOramView)
    (executionLeakage cfg₁) := by
  exact oramSecurity_projects_to_sgxStorage legacyOramSecurityInterface cfg₁ cfg₂ view₁ view₂

theorem legacyComputationalUO_projects_to_sgxExecution
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microTrace : OramConfig → SGXMicroTrace}
  {modelTags : SGXModelTags}
  (hOram : legacyComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicro : OramPublicMicroTraceSafe microTrace) :
  SGXExecutionSecurity
    sameOramPublicProjection
    legacyOramSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule microTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    computationalUOWith_projects_to_sgxExecution
      legacyOramSecurityInterface
      hOram
      hOutcome
      hBoundary
      hMicro

theorem legacyComputationalUO_projects_to_sgxExecution_with_controller
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : legacyComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    legacyOramSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    computationalUOWith_projects_to_sgxExecution_with_controller
      legacyOramSecurityInterface
      hOram
      hOutcome
      hBoundary

theorem legacyComputationalUO_projects_to_sgxExecution_with_budgetController
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : legacyComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    legacyOramBudgetSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    computationalUOWith_projects_to_sgxExecution_with_budgetController
      legacyOramSecurityInterface
      hOram
      hOutcome
      hBoundary

theorem legacyComputationalUO_projects_to_sgxExecution_with_canonicalController
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : legacyComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    legacyOramCanonicalizedSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    computationalUOWith_projects_to_sgxExecution_with_canonicalController
      legacyOramSecurityInterface
      hOram
      hOutcome
      hBoundary

theorem legacyComputationalUO_projects_to_sgxExecution_with_normalizedController
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : legacyComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    legacyOramNormalizedObservedSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    computationalUOWith_projects_to_sgxExecution_with_normalizedController
      legacyOramSecurityInterface
      hOram
      hOutcome
      hBoundary

theorem legacyPaperMain_computationalUO_projects_to_sgxExecution
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : legacyComputationalUO run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    legacyOramNormalizedObservedSGXProofRelation
    (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  exact
    paperMain_computationalUOWith_projects_to_sgxExecution
      legacyOramSecurityInterface
      hOram
      hOutcome
      hBoundary

end UOToolchain
