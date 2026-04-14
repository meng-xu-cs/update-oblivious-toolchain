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

/-- Imported standard Path ORAM theorem object. This is the external theorem
we intend to cite or mechanize separately, at the exact storage-semantics
boundary already used by the repo's concrete backend theorem. -/
structure ImportedStandardPathOramTheorem
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) where
  publicPart : OramConfig → OramViewPublicPart
  storageRun : OramStorageSemantics
  standardBoundary :
    PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart storageRun

/-- Concrete implementation conformance boundary for
`path_oram_local_posmap_v1`: the imported standard theorem is fixed at some
abstract public/storage semantics, and the seeded runtime witness family must
project to that same public/storage interface while exposing a valid hidden
witness slice for each sampled run. -/
structure PathOramLocalPosmapV1ImportedImplementationConformance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) where
  imported : ImportedStandardPathOramTheorem assumptions
  publicPartEq : imported.publicPart = bundle.publicView
  storageRunEq : imported.storageRun = bundle.storageRun
  sampleConformance :
    ∀ cfg seed, seed < (bundle.family cfg).seedCount →
      let witness := (bundle.family cfg).witnessAt seed
      witness.toImportedStandardPathOramSample.publicPart = imported.publicPart cfg ∧
        witness.toImportedStandardPathOramSample.storageView ∈ imported.storageRun cfg ∧
        witness.toImportedStandardPathOramSample.hidden.Valid

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedImplementationConformance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions := by
  refine
    { imported :=
        { publicPart := bundle.publicView
        , storageRun := bundle.storageRun
        , standardBoundary := bundle.pathOramLocalPosmapV1_standardStorageBoundary assumptions
        }
    , publicPartEq := rfl
    , storageRunEq := rfl
    , sampleConformance := ?_
    }
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

theorem PathOramLocalPosmapV1ImportedImplementationConformance.projects_to_standardStorageBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  simpa [conformance.publicPartEq, conformance.storageRunEq] using
    conformance.imported.standardBoundary

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
      conformance.imported.standardBoundary
      hOutcome
      hBoundary
  simpa [conformance.publicPartEq, conformance.storageRunEq] using hImported

end UOToolchain
