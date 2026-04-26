import UOToolchain.Composition
import UOToolchain.RuntimeCoins
import UOToolchain.SgxExactProjection
import UOToolchain.SgxJointProjection
import UOToolchain.TeeDeployment

namespace UOToolchain

/-- Explicit remaining security assumptions for the concrete
`path_oram_local_posmap_v1` backend candidate. The canonical leaf-value
realization is no longer an additional assumption here; it is discharged by the
runtime-family bundle interface, so the remaining backend assumptions are only
the encryption and stash components. -/
structure PathOramLocalPosmapV1SecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  stashOverflowBounded : Prop

def PathOramLocalPosmapV1SecurityAssumptions.toCanonicalLeafValueSecurityAssumptions
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramCanonicalLeafValueSecurityAssumptions :=
  { bucketEncryptionINDCPA := assumptions.bucketEncryptionINDCPA
  , metadataEncryptionINDCPA := assumptions.metadataEncryptionINDCPA
  , stashOverflowBounded := assumptions.stashOverflowBounded
  }

def PathOramLocalPosmapV1SecurityAssumptions.toPathOramSecurityAssumptions
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramSecurityAssumptions := by
  let leafValue :=
    assumptions.toCanonicalLeafValueSecurityAssumptions.toPathOramLeafValueSecurityAssumptions
  let leaf := leafValue.toPathOramLeafSecurityAssumptions
  let bucket := leaf.toPathOramBucketSecurityAssumptions
  exact bucket.toPathOramSecurityAssumptions

abbrev pathOramLocalPosmapV1SecurityInterface
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : OramSecurityInterface :=
  proofGradePathOramSecurityInterface
    assumptions.toPathOramSecurityAssumptions

abbrev pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : SGXProofRelation :=
  oramNormalizedObservedSGXProofRelationWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)

abbrev pathOramLocalPosmapV1JointObservedSGXProofRelation
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : SGXProofRelation :=
  { storageRel := oramSGXStorageRelationWith (pathOramLocalPosmapV1SecurityInterface assumptions)
  , microRel := normalizedObservedSGXMicroRelation
  }

def oramPublicTermination
  (publicOutcome : OramConfig → SGXPublicOutcome) : OramConfig → Bool :=
  fun cfg => (publicOutcome cfg).terminationStatus

def oramPublicOutputShape
  (publicOutcome : OramConfig → SGXPublicOutcome) : OramConfig → OutputShape :=
  fun cfg => (publicOutcome cfg).outputShape

def SeededRuntimePaperMainBundle.publicTermination
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramConfig → Bool :=
  oramPublicTermination bundle.publicOutcome

def SeededRuntimePaperMainBundle.publicOutputShape
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramConfig → OutputShape :=
  oramPublicOutputShape bundle.publicOutcome

def exactPublicTermination
  (publicOutcome : Config → SGXPublicOutcome) : Config → Bool :=
  fun cfg => (publicOutcome cfg).terminationStatus

def exactPublicOutputShape
  (publicOutcome : Config → SGXPublicOutcome) : Config → OutputShape :=
  fun cfg => (publicOutcome cfg).outputShape

/-- Explicit import boundary for a standard-ORAM theorem specialized to the
concrete `path_oram_local_posmap_v1` candidate. This is the remaining
theorem-discharge interface for the backend itself: once a standard Path ORAM
storage theorem is available at this boundary, the repo's concrete
computational-UO, SGX, and TEE consequences follow without adding any further
backend assumptions. -/
def PathOramLocalPosmapV1StandardStorageBoundary
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (run : OramStorageSemantics) : Prop :=
  (∀ cfg, PathOramConfigWellFormed cfg) ∧
    OramPublicViewSafe publicPart ∧
    ComputationalStandardOramWith
      (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
      run

def PathOramLocalPosmapV1StandardPaperMainBoundary
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (run : OramStorageSemantics)
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (boundarySchedule : OramConfig → List BoundaryEvent) : Prop :=
  ComputationalUOWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (liftOramStorageSemantics publicPart run) ∧
    SGXExecutionSecurity
      sameOramPublicProjection
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics
        (liftOramStorageSemantics publicPart run)
        publicOutcome
        boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage publicOutcome modelTags) ∧
    ComputationalTEEStorageObliviousWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (liftOramStorageSemantics publicPart run)
      (oramPublicTermination publicOutcome)
      (oramPublicOutputShape publicOutcome)

def PathOramLocalPosmapV1PaperTheoremBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : Prop :=
  ComputationalUOWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      bundle.toSeededRuntimePathOramProofBundle.run ∧
    SGXExecutionSecurity
      sameOramPublicProjection
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics
        bundle.toSeededRuntimePathOramProofBundle.run
        bundle.publicOutcome
        bundle.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage bundle.publicOutcome modelTags) ∧
    ComputationalTEEStorageObliviousWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicTermination
      bundle.publicOutputShape

def PathOramLocalPosmapV1ArtifactPaperMainBoundary
  {modelTags : SGXModelTags}
  (runs : List TraceSemantics)
  (manifest : ManifestWitness)
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (exactOutcome : Config → SGXPublicOutcome)
  (exactBoundarySchedule : Config → List BoundaryEvent)
  (exactControllerShape : Config → SGXControllerShape) : Prop :=
  ArtifactSecurityWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (exactEntrypointSemantics runs manifest)
      bundle.toSeededRuntimePathOramProofBundle.run ∧
    SGXExecutionSecurity
      samePublicProjection
      exactNormalizedObservedSGXProofRelation
      (exactToSGXSemantics
        (exactEntrypointSemantics runs manifest)
        exactOutcome
        exactBoundarySchedule
        (fun cfg => controllerMicroTraceOfShape (exactControllerShape cfg)))
      emptyStorageLeakage
      (exactMicroLeakage exactOutcome exactControllerShape modelTags) ∧
    SGXExecutionSecurity
      sameOramPublicProjection
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics
        bundle.toSeededRuntimePathOramProofBundle.run
        bundle.publicOutcome
        bundle.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage bundle.publicOutcome modelTags) ∧
    TEEStorageSecurityWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (exactEntrypointSemantics runs manifest)
      (exactPublicTermination exactOutcome)
      (exactPublicOutputShape exactOutcome)
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicTermination
      bundle.publicOutputShape

theorem SeededRuntimePaperMainBundle.publicTerminationSafe
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramPublicTerminationSafe bundle.publicTermination := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.terminationStatus (bundle.publicOutcomeSafe cfg₁ cfg₂ hPublic)

theorem SeededRuntimePaperMainBundle.publicOutputShapeSafe
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramPublicOutputShapeSafe bundle.publicOutputShape := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.outputShape (bundle.publicOutcomeSafe cfg₁ cfg₂ hPublic)

theorem oramPublicTerminationSafe
  {publicOutcome : OramConfig → SGXPublicOutcome}
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  OramPublicTerminationSafe (oramPublicTermination publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.terminationStatus (hOutcome cfg₁ cfg₂ hPublic)

theorem oramPublicOutputShapeSafe
  {publicOutcome : OramConfig → SGXPublicOutcome}
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  OramPublicOutputShapeSafe (oramPublicOutputShape publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.outputShape (hOutcome cfg₁ cfg₂ hPublic)

theorem exactPublicTerminationSafe
  {publicOutcome : Config → SGXPublicOutcome}
  (hOutcome : PublicOutcomeSafe publicOutcome) :
  PublicTerminationSafe (exactPublicTermination publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.terminationStatus (hOutcome cfg₁ cfg₂ hPublic)

theorem exactPublicOutputShapeSafe
  {publicOutcome : Config → SGXPublicOutcome}
  (hOutcome : PublicOutcomeSafe publicOutcome) :
  PublicOutputShapeSafe (exactPublicOutputShape publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.outputShape (hOutcome cfg₁ cfg₂ hPublic)

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ComputationalUOWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    bundle.run := by
  unfold pathOramLocalPosmapV1SecurityInterface
  simp [PathOramLocalPosmapV1SecurityAssumptions.toPathOramSecurityAssumptions]
  simpa using
    bundle.computationalUOWith assumptions.toCanonicalLeafValueSecurityAssumptions

def SeededRuntimePathOramProofBundle.storageRun
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags) : OramStorageSemantics :=
  fun cfg => (bundle.run cfg).map oramStorageView

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageSecurity
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ComputationalStandardOramWith
    (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
    bundle.storageRun := by
  intro cfg₁ cfg₂ hSame
  have hOram :=
    bundle.pathOramLocalPosmapV1_computationalUOWith assumptions cfg₁ cfg₂ hSame
  refine ⟨hOram.1, ?_⟩
  simpa [SeededRuntimePathOramProofBundle.storageRun] using hOram.2.2

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  exact
    ⟨ bundle.cfgWellFormed
    , bundle.publicViewSafe
    , bundle.pathOramLocalPosmapV1_standardStorageSecurity assumptions
    ⟩

theorem pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run) :
  ComputationalUOWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    (liftOramStorageSemantics publicPart run) := by
  rcases hStandard with ⟨hCfg, hPublic, hStorage⟩
  apply computationalPathOram_projects_to_computationalUOWith
    assumptions.toPathOramSecurityAssumptions
    hCfg
    hPublic
  intro cfg₁ cfg₂ hSame
  exact (hStorage cfg₁ cfg₂ hSame).2

theorem pathOramLocalPosmapV1_standardStorageBoundary_projects_to_paperMainSgxExecution
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      (liftOramStorageSemantics publicPart run)
      publicOutcome
      boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  unfold pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
  simpa using
    paperMain_computationalUOWith_projects_to_sgxExecution
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
        assumptions
        hStandard)
      hOutcome
      hBoundary

theorem pathOramLocalPosmapV1_standardStorageBoundary_projects_to_teeStorage
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  ComputationalTEEStorageObliviousWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    (liftOramStorageSemantics publicPart run)
    (oramPublicTermination publicOutcome)
    (oramPublicOutputShape publicOutcome) := by
  apply
    computationalUOWith_projects_to_teeStorage
      (pathOramLocalPosmapV1SecurityInterface assumptions)
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
        assumptions
        hStandard
  · exact oramPublicTerminationSafe hOutcome
  · exact oramPublicOutputShapeSafe hOutcome

theorem pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    publicPart
    run
    publicOutcome
    boundarySchedule := by
  constructor
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
        assumptions
        hStandard
  constructor
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_paperMainSgxExecution
        assumptions
        hStandard
        hOutcome
        hBoundary
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_teeStorage
        assumptions
        hStandard
        hOutcome

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainSgxExecution
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags) := by
  unfold pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
  simp [pathOramLocalPosmapV1SecurityInterface,
    PathOramLocalPosmapV1SecurityAssumptions.toPathOramSecurityAssumptions]
  simpa using
    bundle.paperMainSgxExecution assumptions.toCanonicalLeafValueSecurityAssumptions

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_standardPaperMainBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    bundle.publicView
    bundle.toSeededRuntimePathOramProofBundle.storageRun
    bundle.publicOutcome
    bundle.boundarySchedule := by
  exact
    pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
      (modelTags := modelTags)
      assumptions
      (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageBoundary
        assumptions)
      bundle.publicOutcomeSafe
      bundle.boundarySafe

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_projects_to_teeStorage
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ComputationalTEEStorageObliviousWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    bundle.toSeededRuntimePathOramProofBundle.run
    bundle.publicTermination
    bundle.publicOutputShape := by
  apply
    computationalUOWith_projects_to_teeStorage
      (pathOramLocalPosmapV1SecurityInterface assumptions)
  · exact
      bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
        assumptions
  · exact bundle.publicTerminationSafe
  · exact bundle.publicOutputShapeSafe

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperTheoremBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions := by
  constructor
  · exact
      bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
        assumptions
  constructor
  · exact bundle.pathOramLocalPosmapV1_paperMainSgxExecution assumptions
  · exact bundle.pathOramLocalPosmapV1_projects_to_teeStorage assumptions

theorem pathOramLocalPosmapV1_paperMain_jointSecurity_projects_to_sgxExecution
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      (pathOramLocalPosmapV1SecurityInterface assumptions).localTheorem
        (jointStorageViews (run cfg₁))
        (jointStorageViews (run cfg₂))
        (executionLeakage cfg₁))
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
    (pathOramLocalPosmapV1JointObservedSGXProofRelation assumptions)
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact
    paperMain_jointSecurityWith_projects_to_sgxExecution
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      hStorage
      hMicro
      hOutcome
      hBoundary
      hMicroLeakage

theorem pathOramLocalPosmapV1_artifactPaperMainBoundary
  {modelTags : SGXModelTags}
  (runs : List TraceSemantics)
  (manifest : ManifestWitness)
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (exactOutcome : Config → SGXPublicOutcome)
  (exactBoundarySchedule : Config → List BoundaryEvent)
  (exactControllerShape : Config → SGXControllerShape)
  (hRuns : ExactUOFamily runs)
  (hExactOutcome : PublicOutcomeSafe exactOutcome)
  (hExactBoundary : PublicBoundarySafe exactBoundarySchedule)
  (hExactController : PublicControllerShapeSafe exactControllerShape) :
  PathOramLocalPosmapV1ArtifactPaperMainBoundary
    runs
    manifest
    bundle
    assumptions
    exactOutcome
    exactBoundarySchedule
    exactControllerShape := by
  have hArtifact :
      ArtifactSecurityWith
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        (exactEntrypointSemantics runs manifest)
        bundle.toSeededRuntimePathOramProofBundle.run := by
    exact
      mixedArtifactCompositionWith
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        runs
        manifest
        hRuns
        bundle.toSeededRuntimePathOramProofBundle.run
        (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
          assumptions)
  constructor
  · exact hArtifact
  constructor
  · exact
      paperMain_exactUO_projects_to_sgxExecution
        (compositionTheorem runs manifest hRuns)
        hExactOutcome
        hExactBoundary
        hExactController
  constructor
  · exact bundle.pathOramLocalPosmapV1_paperMainSgxExecution assumptions
  · exact
      artifactSecurityWith_projects_to_teeStorage
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        hArtifact
        (exactPublicTerminationSafe hExactOutcome)
        (exactPublicOutputShapeSafe hExactOutcome)
        bundle.publicTerminationSafe
        bundle.publicOutputShapeSafe

end UOToolchain
