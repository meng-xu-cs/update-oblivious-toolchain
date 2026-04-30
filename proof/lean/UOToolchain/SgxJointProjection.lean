import UOToolchain.SgxMicroModel
import UOToolchain.SgxOramProjection

/-! # Joint storage/micro-trace SGX projection layer

This file projects a joint `SGXJointSemantics` (storage view paired with
micro trace) into the SGX execution view under the paper-facing
normalized SGX micro observer.

* **Abstraction function:** `jointToSGXSemantics` (lifts a
  `SGXJointSemantics` to `SGXSemantics OramConfig` via
  `sgxViewOfJointSample`).
* **Main theorem:** `paperMain_jointSecurityWith_projects_to_sgxExecution`
  — joint storage security plus normalized-by-leakage micro traces lift
  to `SGXExecutionSecurity` under the
  `oramSGXStorageRelationWith security` / `normalizedObservedSGXMicroRelation`
  pair.

All other declarations in this file are file-local helpers used by the
proof body
`jointSecurityWith_projects_to_sgxExecution_with_normalizedMicro`.
The paper-facing entry point in `ProofGrade.lean` is
`proofGrade_sgx_projection_paper_main_joint_security`.
-/

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
  , publicEnv := publicOutcome.publicEnv
  , boundarySchedule := boundarySchedule
  , persistentReads := storage.persistentReads
  , persistentWrites := storage.persistentWrites
  , pageTrace := sample.microTrace.pageTrace
  , exitTrace := sample.microTrace.exitTrace
  , sharedResourceTrace := sample.microTrace.sharedResourceTrace
  , terminationStatus := publicOutcome.terminationStatus
  , statusPolicy := publicOutcome.statusPolicy
  , outputShape := publicOutcome.outputShape
  , returnPolicy := publicOutcome.returnPolicy
  , returnPayload := publicOutcome.returnPayload
  , encryptedReturnPayload := publicOutcome.encryptedReturnPayload
  , declassifies := publicOutcome.declassifies
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

theorem jointStorageTheoremWith_projects_to_sgxStorage
  (security : OramSecurityInterface)
  (cfg₁ cfg₂ : OramConfig)
  (samples₁ samples₂ : Distribution SGXJointSample) :
  sameOramPublicProjection cfg₁ cfg₂ →
  security.localTheorem (jointStorageViews samples₁) (jointStorageViews samples₂) (executionLeakage cfg₁) →
  oramSGXStorageRelationWith security
    ((jointStorageViews samples₁).map sgxStorageOfOramView)
    ((jointStorageViews samples₂).map sgxStorageOfOramView)
    (executionLeakage cfg₁) := by
  intro hPublic hLocal
  exact ⟨cfg₁, cfg₂, jointStorageViews samples₁, jointStorageViews samples₂, hPublic, rfl, hLocal, rfl, rfl⟩

theorem jointSecurityWith_projects_to_sgxExecution_with_normalizedMicro
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
    ∀ cfg,
      NormalizedByLeakage
        (jointMicroViews (run cfg))
        (microLeakage cfg))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelationWith security, microRel := normalizedObservedSGXMicroRelation }
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
theorem paperMain_jointSecurityWith_projects_to_sgxExecution
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
    ∀ cfg,
      NormalizedByLeakage
        (jointMicroViews (run cfg))
        (microLeakage cfg))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    { storageRel := oramSGXStorageRelationWith security, microRel := normalizedObservedSGXMicroRelation }
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact
    jointSecurityWith_projects_to_sgxExecution_with_normalizedMicro
      security
      hStorage
      hMicro
      hOutcome
      hBoundary
      hMicroLeakage

end UOToolchain
