import UOToolchain.SgxOramProjection
import UOToolchain.OramGame

/-! # Legacy ORAM-game SGX projection mirror

This file demonstrates that the `legacyOramLocalTheorem` axiom-style
ORAM-game security interface still routes through the canonical
paper-main projection theorem in `SgxOramProjection.lean`. It is
forbidden from import by the proof-grade core modules and exists only
as a legacy compatibility surface.

The earlier alternative-relation mirrors (bare unparameterized form,
`_with_controller`, `_with_budgetController`,
`_with_canonicalController`) are removed alongside the corresponding
removals in `SgxOramProjection.lean` (W7.1 canonicalization).
-/

namespace UOToolchain

abbrev legacyOramSGXStorageRelation : SGXStorageRelation :=
  oramSGXStorageRelationWith legacyOramSecurityInterface

abbrev legacyOramNormalizedObservedSGXProofRelation : SGXProofRelation :=
  oramNormalizedObservedSGXProofRelationWith legacyOramSecurityInterface

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
