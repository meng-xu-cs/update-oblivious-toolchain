import UOToolchain.DeploymentAcceptance
import UOToolchain.ObserverCoverage
import UOToolchain.PaperMainTheorem
import UOToolchain.PathOramPrivatePosmapV1
import UOToolchain.RuntimeRefinement
import UOToolchain.RuntimeAuditSurfaces
import UOToolchain.TranslationValidationJson

namespace UOToolchain

/-!
# Accepted-package paper-main capstone

This module closes the F9/F14 theorem shape: the paper-main theorem still keeps
its precise safety premises, but proof-grade callers no longer cite those
premises independently.  They are fields of accepted-package evidence, next to
translation validation, deployment acceptance, observer coverage, and the
host-visible gas/failure taxonomy.
-/

structure PublicOutcomeFieldEquality (lhs rhs : SGXPublicOutcome) : Prop where
  entrypointId : lhs.entrypointId = rhs.entrypointId
  publicArgs : lhs.publicArgs = rhs.publicArgs
  terminationStatus : lhs.terminationStatus = rhs.terminationStatus
  statusPolicy : lhs.statusPolicy = rhs.statusPolicy
  outputShape : lhs.outputShape = rhs.outputShape
  returnPolicy : lhs.returnPolicy = rhs.returnPolicy
  returnPayload : lhs.returnPayload = rhs.returnPayload
  encryptedReturnPayload :
    lhs.encryptedReturnPayload = rhs.encryptedReturnPayload
  declassifies : lhs.declassifies = rhs.declassifies
  gasUsed : lhs.gasUsed = rhs.gasUsed

theorem PublicOutcomeFieldEquality.of_eq
  {lhs rhs : SGXPublicOutcome}
  (hEq : lhs = rhs) :
  PublicOutcomeFieldEquality lhs rhs := by
  cases hEq
  exact
    { entrypointId := rfl
    , publicArgs := rfl
    , terminationStatus := rfl
    , statusPolicy := rfl
    , outputShape := rfl
    , returnPolicy := rfl
    , returnPayload := rfl
    , encryptedReturnPayload := rfl
    , declassifies := rfl
    , gasUsed := rfl
    }

structure AcceptedRuntimeProofObjectEvidence
  (modelTags : SGXModelTags)
  (witness : RuntimeRefinementWitness) : Prop where
  proofGradeValid : witness.ProofGradeValid modelTags

theorem acceptedRuntimeProofObjectEvidence_public_gas_exact
  {modelTags : SGXModelTags}
  {witness : RuntimeRefinementWitness}
  (accepted : AcceptedRuntimeProofObjectEvidence modelTags witness) :
  witness.trace.gasUsed = witness.publicOutcome.gasUsed := by
  exact
    runtimeWitness_publicOutcome_gas_exact
      witness modelTags accepted.proofGradeValid.1

theorem acceptedRuntimeProofObjectEvidence_controller_surface_exact
  {modelTags : SGXModelTags}
  {witness : RuntimeRefinementWitness}
  (accepted : AcceptedRuntimeProofObjectEvidence modelTags witness) :
  witness.boundarySchedule =
      witness.controllerCertificate.boundarySchedule witness.publicOutcome ∧
    witness.controllerShape = witness.controllerCertificate.controllerShape ∧
    witness.normalizedMicroTrace =
      simulateNormalizedMicroTraceFromLeakage
        (witness.microLeakage modelTags) := by
  simpa
    [ RuntimeRefinementWitness.controllerObserverCertificate
    , RuntimeControllerObserverCertificate.Valid
    ] using
      runtimeWitness_controllerObserverCertificate_valid
        witness modelTags accepted.proofGradeValid.1

theorem acceptedRuntimeProofObjectEvidence_kernel_final_state_exact
  {modelTags : SGXModelTags}
  {witness : RuntimeRefinementWitness}
  (accepted : AcceptedRuntimeProofObjectEvidence modelTags witness) :
  ∃ kernelWitness expectedKernelSchedule,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  exact
    runtimeWitness_proofGradeKernelScheduleObject_finalState_exact
      witness modelTags accepted.proofGradeValid

theorem acceptedRuntimeProofObjectEvidence_host_visible_taxonomy_closed
  {modelTags : SGXModelTags}
  {witness : RuntimeRefinementWitness}
  (_accepted : AcceptedRuntimeProofObjectEvidence modelTags witness) :
  forall entry, entry ∈ runtimeHostVisibleOutcomeTaxonomy ->
    entry.closed = true :=
  runtimeHostVisibleOutcomeTaxonomy_allClosed

structure AcceptedExactPackageCapstoneEvidence
  (translation : ImportedProofRelevantTranslationBundle)
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (deploymentState : DeploymentRuntimeState)
  (deploymentEvidence : DeploymentCallEvidence)
  (run : TraceSemantics)
  (publicOutcome : Config → SGXPublicOutcome)
  (boundarySchedule : Config → List BoundaryEvent)
  (controllerShape : Config → SGXControllerShape)
  (finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback)
  (releaseFunctions : Config → PaperMainDeclaredReleaseFunctions) : Prop where
  translationProofGrade : translation.ProofGradeValid
  deploymentAccepted :
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence
  backendExact : ExactUO run
  publicOutcomeSafe : PublicOutcomeSafe publicOutcome
  boundarySafe : PublicBoundarySafe boundarySchedule
  controllerShapeSafe : PublicControllerShapeSafe controllerShape
  finalPublicStateSafe :
    PaperMainPublicFieldSafe samePublicProjection finalPublicStateRollback
  releaseFunctionsSafe :
    PaperMainPublicFieldSafe samePublicProjection releaseFunctions

theorem acceptedExactPackageCapstoneEvidence_closes_public_surface
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedExactPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      run
      publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions) :
    translation.ProofGradeValid ∧
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence ∧
    ExactUO run ∧
    (forall entry, entry ∈ observerFieldCoverage -> entry.closed = true) ∧
    (forall entry, entry ∈ runtimeHostVisibleOutcomeTaxonomy -> entry.closed = true) ∧
    PublicOutcomeSafe publicOutcome ∧
    PublicBoundarySafe boundarySchedule ∧
    PublicControllerShapeSafe controllerShape ∧
    PaperMainPublicFieldSafe samePublicProjection finalPublicStateRollback ∧
    PaperMainPublicFieldSafe samePublicProjection releaseFunctions := by
  exact
    ⟨ accepted.translationProofGrade
    , accepted.deploymentAccepted
    , accepted.backendExact
    , observerCoverage_allClosed
    , runtimeHostVisibleOutcomeTaxonomy_allClosed
    , accepted.publicOutcomeSafe
    , accepted.boundarySafe
    , accepted.controllerShapeSafe
    , accepted.finalPublicStateSafe
    , accepted.releaseFunctionsSafe
    ⟩

theorem acceptedExactPackageCapstone_noninterference
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedExactPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      run
      publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : Config}
  (hPublic :
    PaperMainExactSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainExactNoninterferenceConclusion
    (paperMainExactView
      run
      publicOutcome
      boundarySchedule
      controllerShape
      finalPublicStateRollback
      releaseFunctions
      cfg₁)
    (paperMainExactView
      run
      publicOutcome
      boundarySchedule
      controllerShape
      finalPublicStateRollback
      releaseFunctions
      cfg₂) := by
  exact
    paperMain_exact_backend_noninterference
      accepted.backendExact
      accepted.publicOutcomeSafe
      accepted.boundarySafe
      accepted.controllerShapeSafe
      accepted.finalPublicStateSafe
      accepted.releaseFunctionsSafe
      hPublic

theorem acceptedExactPackageCapstone_publicOutcomeFields_closed
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedExactPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      run
      publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : Config}
  (hPublic :
    PaperMainExactSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PublicOutcomeFieldEquality
    (publicOutcome cfg₁)
    (publicOutcome cfg₂) := by
  exact
    PublicOutcomeFieldEquality.of_eq
      (accepted.publicOutcomeSafe cfg₁ cfg₂ hPublic)

structure AcceptedPathOramPackageCapstoneEvidence
  {modelTags : SGXModelTags}
  (translation : ImportedProofRelevantTranslationBundle)
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (deploymentState : DeploymentRuntimeState)
  (deploymentEvidence : DeploymentCallEvidence)
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions) : Prop where
  translationProofGrade : translation.ProofGradeValid
  deploymentAccepted :
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence
  finalPublicStateSafe :
    PaperMainPublicFieldSafe sameOramPublicProjection finalPublicStateRollback
  releaseFunctionsSafe :
    PaperMainPublicFieldSafe sameOramPublicProjection releaseFunctions

theorem acceptedPathOramPackageCapstoneEvidence_closes_public_surface
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle finalPublicStateRollback releaseFunctions) :
    translation.ProofGradeValid ∧
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence ∧
    (forall entry, entry ∈ observerFieldCoverage -> entry.closed = true) ∧
    (forall entry, entry ∈ runtimeHostVisibleOutcomeTaxonomy -> entry.closed = true) ∧
    OramPublicOutcomeSafe bundle.publicOutcome ∧
    OramPublicBoundarySafe bundle.boundarySchedule ∧
    PaperMainPublicFieldSafe sameOramPublicProjection finalPublicStateRollback ∧
    PaperMainPublicFieldSafe sameOramPublicProjection releaseFunctions := by
  exact
    ⟨ accepted.translationProofGrade
    , accepted.deploymentAccepted
    , observerCoverage_allClosed
    , runtimeHostVisibleOutcomeTaxonomy_allClosed
    , bundle.publicOutcomeSafe
    , bundle.boundarySafe
    , accepted.finalPublicStateSafe
    , accepted.releaseFunctionsSafe
    ⟩

theorem acceptedPathOramPackageCapstone_noninterference
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (accepted :
    AcceptedPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramLocalPosmapV1NoninterferenceConclusion
    assumptions
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags)
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  exact
    bundle.pathOramLocalPosmapV1_paperMain_noninterference
      assumptions
      accepted.finalPublicStateSafe
      accepted.releaseFunctionsSafe
    hPublic

structure AcceptedPrivatePosmapPathOramPackageCapstoneEvidence
  {modelTags : SGXModelTags}
  (translation : ImportedProofRelevantTranslationBundle)
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (deploymentState : DeploymentRuntimeState)
  (deploymentEvidence : DeploymentCallEvidence)
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (cert : ScalablePathOramCertificate)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions) : Prop where
  translationProofGrade : translation.ProofGradeValid
  privatePosmapCertificatesValidated :
    translation.PrivatePosmapCertificatesValidated
  deploymentAccepted :
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence
  privatePosmapCertificate :
    PathOramPrivatePosmapV1BundleCertificate
      cert
      bundle.toSeededRuntimePathOramProofBundle
  finalPublicStateSafe :
    PaperMainPublicFieldSafe sameOramPublicProjection finalPublicStateRollback
  releaseFunctionsSafe :
    PaperMainPublicFieldSafe sameOramPublicProjection releaseFunctions

theorem acceptedPrivatePosmapPathOramPackageCapstoneEvidence_closes_public_surface
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {cert : ScalablePathOramCertificate}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedPrivatePosmapPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle cert finalPublicStateRollback releaseFunctions) :
    translation.ProofGradeValid ∧
    translation.PrivatePosmapCertificatesValidated ∧
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence ∧
    (forall entry, entry ∈ observerFieldCoverage -> entry.closed = true) ∧
    (forall entry, entry ∈ runtimeHostVisibleOutcomeTaxonomy -> entry.closed = true) ∧
    OramPublicOutcomeSafe bundle.publicOutcome ∧
    OramPublicBoundarySafe bundle.boundarySchedule ∧
    PaperMainPublicFieldSafe sameOramPublicProjection finalPublicStateRollback ∧
    PaperMainPublicFieldSafe sameOramPublicProjection releaseFunctions := by
  exact
    ⟨ accepted.translationProofGrade
    , accepted.privatePosmapCertificatesValidated
    , accepted.deploymentAccepted
    , observerCoverage_allClosed
    , runtimeHostVisibleOutcomeTaxonomy_allClosed
    , bundle.publicOutcomeSafe
    , bundle.boundarySafe
    , accepted.finalPublicStateSafe
    , accepted.releaseFunctionsSafe
    ⟩

theorem acceptedPrivatePosmapPathOramPackageCapstone_noninterference
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {cert : ScalablePathOramCertificate}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  (accepted :
    AcceptedPrivatePosmapPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle cert finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramPrivatePosmapV1NoninterferenceConclusion
    assumptions
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags)
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  exact
    bundle.pathOramPrivatePosmapV1_paperMain_noninterference
      assumptions
      accepted.privatePosmapCertificate
      accepted.finalPublicStateSafe
      accepted.releaseFunctionsSafe
      hPublic

theorem acceptedPathOramPackageCapstone_publicOutcomeFields_closed
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (_accepted :
    AcceptedPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PublicOutcomeFieldEquality
    (bundle.publicOutcome cfg₁)
    (bundle.publicOutcome cfg₂) := by
  exact
    PublicOutcomeFieldEquality.of_eq
      (bundle.publicOutcomeSafe cfg₁ cfg₂ hPublic)

end UOToolchain
