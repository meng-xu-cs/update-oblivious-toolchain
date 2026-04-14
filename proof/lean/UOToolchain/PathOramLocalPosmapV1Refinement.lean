import UOToolchain.PathOramLocalPosmapV1
import UOToolchain.RuntimeRefinement

namespace UOToolchain

/-- Hidden witness slice expected by an imported standard Path ORAM theorem for
the concrete `path_oram_local_posmap_v1` backend. This is the theorem-facing
state that a concrete runtime witness must expose in order to justify that the
observed storage sample is a valid sample of the imported abstract theorem. -/
structure ImportedPathOramHiddenWitness where
  oramObjects : List RuntimeOramObjectCertificate
  publicLeafScaffold : List RuntimePathOramLeafScaffoldStep
  hiddenLeafSchedule : List RuntimeOramLeafCertificate
  positionMapBefore : List RuntimePathOramPositionMapCertificate
  positionMapAfter : List RuntimePathOramPositionMapCertificate
  transitions : List RuntimePathOramTransitionCertificate
deriving Repr, DecidableEq

def ImportedPathOramHiddenWitness.projectedPublicLeafScaffold
  (witness : ImportedPathOramHiddenWitness) : PathOramLeafScheduleScaffold :=
  witness.publicLeafScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedPathOramHiddenWitness.projectedHiddenLeafScaffold
  (witness : ImportedPathOramHiddenWitness) : PathOramLeafScheduleScaffold :=
  witness.hiddenLeafSchedule.map RuntimeOramLeafCertificate.scaffoldStep |>.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedPathOramHiddenWitness.replayedPositionMapState
  (witness : ImportedPathOramHiddenWitness) : Option RuntimePathOramPositionMapState :=
  replayRuntimePathOramTransitions
    witness.positionMapBefore
    witness.oramObjects
    witness.hiddenLeafSchedule
    witness.transitions

def ImportedPathOramHiddenWitness.expectedPositionMapState
  (witness : ImportedPathOramHiddenWitness) : Option RuntimePathOramPositionMapState :=
  runtimePathOramPositionMapStateByObject
    witness.positionMapAfter
    witness.oramObjects

def ImportedPathOramHiddenWitness.Valid
  (witness : ImportedPathOramHiddenWitness) : Prop :=
  witness.projectedPublicLeafScaffold = witness.projectedHiddenLeafScaffold ∧
    witness.replayedPositionMapState = witness.expectedPositionMapState ∧
    witness.replayedPositionMapState.isSome = true

/-- One concrete sample consumed by the imported standard Path ORAM theorem:
the exact public observer plus the storage view and hidden witness slice used
to justify conformance to the theorem's abstract execution. -/
structure ImportedStandardPathOramSample where
  publicPart : OramViewPublicPart
  storageView : OramStorageView
  hidden : ImportedPathOramHiddenWitness
deriving Repr, DecidableEq

def RuntimeRefinementWitness.toImportedPathOramHiddenWitness
  (witness : RuntimeRefinementWitness) : ImportedPathOramHiddenWitness :=
  { oramObjects := witness.oramObjects
  , publicLeafScaffold := witness.oramLeafPublicScaffold
  , hiddenLeafSchedule := witness.oramLeafSchedule
  , positionMapBefore := witness.oramPositionMapBefore
  , positionMapAfter := witness.oramPositionMapAfter
  , transitions := witness.oramLeafStateTransitions
  }

def RuntimeRefinementWitness.toImportedStandardPathOramSample
  (witness : RuntimeRefinementWitness) : ImportedStandardPathOramSample :=
  { publicPart := pathOramViewPublicPart (viewMPlus witness.trace)
  , storageView := oramStorageView (viewMPlus witness.trace)
  , hidden := witness.toImportedPathOramHiddenWitness
  }

@[simp] theorem runtimeWitness_toImportedStandardPathOramSample_publicPart
  (witness : RuntimeRefinementWitness) :
  witness.toImportedStandardPathOramSample.publicPart =
    pathOramViewPublicPart (viewMPlus witness.trace) := by
  rfl

@[simp] theorem runtimeWitness_toImportedStandardPathOramSample_storageView
  (witness : RuntimeRefinementWitness) :
  witness.toImportedStandardPathOramSample.storageView =
    oramStorageView (viewMPlus witness.trace) := by
  rfl

theorem runtimeWitness_toImportedPathOramHiddenWitness_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.toImportedPathOramHiddenWitness.Valid := by
  refine ⟨?_, ?_, ?_⟩
  · simpa
      [ RuntimeRefinementWitness.toImportedPathOramHiddenWitness
      , ImportedPathOramHiddenWitness.projectedPublicLeafScaffold
      , ImportedPathOramHiddenWitness.projectedHiddenLeafScaffold
      , RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold
      , RuntimeRefinementWitness.projectedPathOramLeafScaffold
      , RuntimeRefinementWitness.pathOramLeafScaffold
      ] using
      runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
        witness modelTags hValid
  · unfold RuntimeRefinementWitness.toImportedPathOramHiddenWitness
      ImportedPathOramHiddenWitness.replayedPositionMapState
      ImportedPathOramHiddenWitness.expectedPositionMapState
    simpa using runtimeWitness_pathOramLeafStateReplay_exact witness modelTags hValid
  · unfold RuntimeRefinementWitness.toImportedPathOramHiddenWitness
      ImportedPathOramHiddenWitness.replayedPositionMapState
    simpa using runtimeWitness_pathOramLeafStateReplay_some witness modelTags hValid

/-- Bucket-trace projection on raw storage samples. -/
def pathOramBucketTraceOfStorageView
  (storage : OramStorageView) : PathOramBucketTrace :=
  pathOramBucketTrace (pathOramStorageLocationTrace storage)

/-- Theorem-facing standard Path ORAM implementation interface. This packages
the exact internal hypotheses consumed by the standard Path ORAM theorem at the
storage boundary used by `path_oram_local_posmap_v1`. -/
structure ImportedStandardPathOramImplementation
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (storageRun : OramStorageSemantics) where
  leafRun : OramConfig → Distribution PathOramLeafScheduleTrace
  cfgWellFormed : ∀ cfg, PathOramConfigWellFormed cfg
  publicViewSafe : OramPublicViewSafe publicPart
  leafValueCanonicalOnPublicPart :
    ∀ cfg,
      PathOramLeafValueCanonicalOnPublicPart
        ((leafRun cfg).map pathOramLeafValues)
        (publicPart cfg)
        (pathOramProjectedExecutionLeakage cfg)
  leafSchedulePublicAlignment :
    ∀ cfg,
      PathOramLeafSchedulePublicAlignment
        (leafRun cfg)
        (publicPart cfg)
        (pathOramProjectedExecutionLeakage cfg)
  bucketProjection :
    ∀ cfg,
      (storageRun cfg).map pathOramBucketTraceOfStorageView =
        (leafRun cfg).map pathOramBucketTraceOfLeafScheduleTrace
  publicLocationRelation :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      OramExactProjectionRelation
        pathOramPublicLocationTrace
        ((storageRun cfg₁).map pathOramStorageLocationTrace)
        ((storageRun cfg₂).map pathOramStorageLocationTrace)
  storageShapeRelation :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      OramExactProjectionRelation
        pathOramStorageShape
        (storageRun cfg₁)
        (storageRun cfg₂)

theorem ImportedStandardPathOramImplementation.leafScaffoldRelation
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun)
  {cfg₁ cfg₂ : OramConfig}
  (hSame : sameOramPublicProjection cfg₁ cfg₂) :
  OramExactProjectionRelation
    pathOramLeafScheduleScaffold
    (impl.leafRun cfg₁)
    (impl.leafRun cfg₂) := by
  have hPublicEq : publicPart cfg₁ = publicPart cfg₂ :=
    impl.publicViewSafe cfg₁ cfg₂ hSame
  have hLeakageEq :
      pathOramProjectedExecutionLeakage cfg₁ =
        pathOramProjectedExecutionLeakage cfg₂ :=
    pathOramProjectedLeakage_eq_of_samePublicProjection hSame
  apply pathOramLeafSchedulePublicAlignment_exact
  · exact impl.leafSchedulePublicAlignment cfg₁
  · simpa [hPublicEq, hLeakageEq] using impl.leafSchedulePublicAlignment cfg₂

theorem ImportedStandardPathOramImplementation.canonicalLeafValueRelation
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun)
  {cfg₁ cfg₂ : OramConfig}
  (hSame : sameOramPublicProjection cfg₁ cfg₂) :
  canonicalPathOramLeafValueRelation
    ((impl.leafRun cfg₁).map pathOramLeafValues)
    ((impl.leafRun cfg₂).map pathOramLeafValues)
    (pathOramProjectedExecutionLeakage cfg₁) := by
  rcases impl.leafValueCanonicalOnPublicPart cfg₁ with
    ⟨scaffold₁, hScaffold₁, hLeafs₁⟩
  rcases impl.leafValueCanonicalOnPublicPart cfg₂ with
    ⟨scaffold₂, hScaffold₂, hLeafs₂⟩
  have hPublicEq : publicPart cfg₁ = publicPart cfg₂ :=
    impl.publicViewSafe cfg₁ cfg₂ hSame
  have hLeakageEq :
      pathOramProjectedExecutionLeakage cfg₁ =
        pathOramProjectedExecutionLeakage cfg₂ :=
    pathOramProjectedLeakage_eq_of_samePublicProjection hSame
  have hScaffold₂' :
      pathOramLeafScheduleScaffoldOfPublicPart
        (publicPart cfg₁)
        (pathOramProjectedExecutionLeakage cfg₁) = some scaffold₂ := by
    simpa [hPublicEq, hLeakageEq] using hScaffold₂
  have hScaffoldEq : scaffold₁ = scaffold₂ := by
    exact Option.some.inj (hScaffold₁.symm.trans hScaffold₂')
  refine ⟨scaffold₁, hLeafs₁, ?_⟩
  simpa [hScaffoldEq] using hLeafs₂

theorem ImportedStandardPathOramImplementation.standardStorageSecurity
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun) :
  ComputationalStandardOramWith
    (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
    storageRun := by
  intro cfg₁ cfg₂ hSame
  apply pathOramStandardSecurityInterface_uses_pathLeakage
    assumptions.toPathOramSecurityAssumptions
  · exact pathOramConfigWellFormed_executionLeakage (impl.cfgWellFormed cfg₁)
  · apply pathOramProjectedStorageTheorem_projects_to_standard
      assumptions.toPathOramSecurityAssumptions
    apply pathOramProjectedStorageTheorem_of_leafScheduleBucketLocationPublicTrace_and_shape
      assumptions.toCanonicalLeafValueSecurityAssumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions
    · exact
        ⟨ impl.canonicalLeafValueRelation hSame
        , impl.leafScaffoldRelation hSame
        ⟩
    · exact impl.leafScaffoldRelation hSame
    · simpa [pathOramBucketTraceOfStorageView] using impl.bucketProjection cfg₁
    · simpa [pathOramBucketTraceOfStorageView] using impl.bucketProjection cfg₂
    · exact impl.publicLocationRelation cfg₁ cfg₂ hSame
    · exact impl.storageShapeRelation cfg₁ cfg₂ hSame

theorem ImportedStandardPathOramImplementation.standardStorageBoundary
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun) :
  PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart storageRun := by
  exact
    ⟨ impl.cfgWellFormed
    , impl.publicViewSafe
    , impl.standardStorageSecurity
    ⟩

/-- Imported standard Path ORAM theorem object. This fixes both the public and
storage semantics and exposes the theorem-facing implementation witness that
discharges the standard storage boundary. -/
structure ImportedStandardPathOramTheorem
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) where
  publicPart : OramConfig → OramViewPublicPart
  storageRun : OramStorageSemantics
  implementation :
    ImportedStandardPathOramImplementation assumptions publicPart storageRun

theorem ImportedStandardPathOramTheorem.standardBoundary
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (theoremObj : ImportedStandardPathOramTheorem assumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    theoremObj.publicPart
    theoremObj.storageRun := by
  exact theoremObj.implementation.standardStorageBoundary

/-- Concrete implementation conformance boundary for
`path_oram_local_posmap_v1`: the imported standard theorem is fixed at some
abstract public/storage semantics, and the seeded runtime witness family must
project to that same public/storage interface while exposing a valid hidden
witness slice for each sampled run. -/
structure PathOramLocalPosmapV1ImportedImplementationConformance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) where
  implementation :
    ImportedStandardPathOramImplementation
      assumptions
      bundle.publicView
      bundle.storageRun
  sampleConformance :
    ∀ cfg seed, seed < (bundle.family cfg).seedCount →
      let witness := (bundle.family cfg).witnessAt seed
      witness.toImportedStandardPathOramSample.publicPart = bundle.publicView cfg ∧
        witness.toImportedStandardPathOramSample.storageView ∈ bundle.storageRun cfg ∧
        witness.toImportedStandardPathOramSample.hidden.Valid

def PathOramLocalPosmapV1ImportedImplementationConformance.imported
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions) :
  ImportedStandardPathOramTheorem assumptions :=
  { publicPart := bundle.publicView
  , storageRun := bundle.storageRun
  , implementation := conformance.implementation
  }

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedImplementationConformance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions := by
  refine
    { implementation :=
        { leafRun := bundle.leafRun
        , cfgWellFormed := bundle.cfgWellFormed
        , publicViewSafe := bundle.publicViewSafe
        , leafValueCanonicalOnPublicPart := ?_
        , leafSchedulePublicAlignment := ?_
        , bucketProjection := ?_
        , publicLocationRelation := ?_
        , storageShapeRelation := ?_
        }
    , sampleConformance := ?_
    }
  · intro cfg
    exact bundle.leafValueCanonicalOnPublicPart cfg (bundle.publicViewConstantProjection cfg)
  · intro cfg
    exact bundle.leafSchedulePublicAlignment cfg (bundle.publicViewConstantProjection cfg)
  · intro cfg
    unfold SeededRuntimePathOramProofBundle.storageRun
    rw [List.map_map]
    simpa [pathOramBucketTraceOfStorageView, pathOramBucketTraceOfView] using
      bundle.bucketProjection cfg
  · intro cfg₁ cfg₂ hSame
    simpa [SeededRuntimePathOramProofBundle.storageRun] using
      bundle.publicLocationRelation hSame
  · intro cfg₁ cfg₂ hSame
    simpa [SeededRuntimePathOramProofBundle.storageRun] using
      (oramExactProjectionRelation_map
        pathOramStorageShape
        oramStorageView
        (bundle.storageShapeRelation hSame))
  intro cfg seed hSeed
  constructor
  · exact bundle.publicViewExact cfg seed hSeed
  constructor
  · have hSeedMem :
        seed ∈ (runtimeSeedIndexDistribution (bundle.family cfg).seedCount).samples := by
      simpa [runtimeSeedIndexDistribution] using List.mem_range.mpr hSeed
    unfold SeededRuntimePathOramProofBundle.storageRun
      SeededRuntimePathOramProofBundle.run
      SeededRuntimeWitnessFamily.viewDistribution
    change
      oramStorageView (viewMPlus (((bundle.family cfg).witnessAt seed).trace)) ∈
        List.map oramStorageView
          (List.map
            (fun seed => viewMPlus (((bundle.family cfg).witnessAt seed).trace))
            (runtimeSeedIndexDistribution (bundle.family cfg).seedCount).samples)
    apply List.mem_map.mpr
    refine ⟨viewMPlus (((bundle.family cfg).witnessAt seed).trace), ?_, rfl⟩
    exact List.mem_map.mpr ⟨seed, hSeedMem, rfl⟩
  · exact
      runtimeWitness_toImportedPathOramHiddenWitness_valid
        ((bundle.family cfg).witnessAt seed)
        modelTags
        ((bundle.family cfg).valid seed hSeed)

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedImplementation
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ImportedStandardPathOramImplementation
    assumptions
    bundle.publicView
    bundle.storageRun :=
  (bundle.pathOramLocalPosmapV1_importedImplementationConformance assumptions).implementation

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ImportedStandardPathOramTheorem assumptions :=
  (bundle.pathOramLocalPosmapV1_importedImplementationConformance assumptions).imported

theorem PathOramLocalPosmapV1ImportedImplementationConformance.projects_to_standardStorageBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  exact conformance.implementation.standardStorageBoundary

theorem PathOramLocalPosmapV1ImportedImplementationConformance.projects_to_standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    bundle.publicView
    bundle.storageRun
    publicOutcome
    boundarySchedule := by
  have hImported :=
    pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
      (modelTags := modelTags)
      assumptions
      conformance.implementation.standardStorageBoundary
      hOutcome
      hBoundary
  simpa using hImported

end UOToolchain
