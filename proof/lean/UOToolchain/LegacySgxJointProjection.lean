import UOToolchain.SgxJointProjection
import UOToolchain.LegacySgxOramProjection
import UOToolchain.SgxMicroGame
import UOToolchain.OramGame

/-! # Legacy joint storage/micro SGX projection mirror

This file demonstrates that the `legacyOramLocalTheorem`-axiom legacy
ORAM/micro security interface still routes through the canonical
paper-main joint projection theorem in `SgxJointProjection.lean`. It
is forbidden from import by the proof-grade core modules and exists
only as a legacy compatibility surface.

The earlier alternative-relation mirrors (`legacyJointStorageTheorem_projects_to_sgxStorage`,
`legacyJointMicroTheorem_projects_to_sgxMicro`,
`legacyJointSecurityWith_projects_to_sgxExecution`,
`legacyJointSecurity_projects_to_sgxExecution`,
`legacyJointSecurityWith_projects_to_sgxExecution_with_oramController`,
`legacyJointSecurity_projects_to_sgxExecution_with_oramController`)
are removed alongside the corresponding W7.1 cleanup of
`SgxOramProjection.lean` / `SgxMicroModel.lean`. The two surviving
theorems mirror the canonical normalized-micro paper-main theorem.
-/

namespace UOToolchain

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
