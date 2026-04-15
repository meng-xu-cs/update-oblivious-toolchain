import UOToolchain.PathOramLocalPosmapV1StandardTheorem
import UOToolchain.RuntimeCanonicalPathOramPairJson

namespace UOToolchain

def CanonicalFreshCoinRuntimePathOramWitnessFamily.toSeededRuntimePathOramWitnessFamily
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) :
  SeededRuntimePathOramWitnessFamily modelTags :=
  { seedCount := family.seedCount
  , witnessAt := fun seed => { family.witnessAt seed with runtimeSeed := some seed }
  , seedTagged := by
      intro seed hSeed
      rfl
  , valid := by
      intro seed hSeed
      simpa using family.valid seed hSeed
  , publicLeafScaffold := family.publicLeafScaffold
  , publicLeafScaffoldExact := family.publicLeafScaffoldExact
  }

def CanonicalFreshCoinRuntimePathOramWitnessFamily.HiddenLeafValueRefinement
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) : Prop :=
  family.toSeededRuntimePathOramWitnessFamily.RealizesCanonicalLeafValueSeedSpace

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkHiddenLeafValueRefinement
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) : Bool :=
  decide
    (family.seed_count =
      pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold) &&
    (List.range family.seed_count).all fun seed =>
      decide
        (pathOramLeafValues (family.runtimeWitnessAt seed).pathOramLeafScheduleTrace =
          pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold seed)

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkHiddenLeafValueRefinement_eq_true_iff
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) :
  family.checkHiddenLeafValueRefinement = true ↔
    family.seed_count =
      pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold ∧
    ∀ seed, seed < family.seed_count →
      pathOramLeafValues (family.runtimeWitnessAt seed).pathOramLeafScheduleTrace =
        pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold seed := by
  constructor
  · intro hCheck
    unfold ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkHiddenLeafValueRefinement at hCheck
    rw [Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · simpa using hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          decide
            (pathOramLeafValues (family.runtimeWitnessAt seed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold seed) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      simpa using hSeedCheck
  · intro hRefine
    unfold ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkHiddenLeafValueRefinement
    rw [Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · simpa using hRefine.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      simpa using hRefine.2 seed hSeed

theorem ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.toSeededRuntimePathOramWitnessFamily_hiddenLeafValueRefinement
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hValid : family.Valid modelTags)
  (hRefine :
    family.seed_count =
      pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold ∧
    ∀ seed, seed < family.seed_count →
      pathOramLeafValues (family.runtimeWitnessAt seed).pathOramLeafScheduleTrace =
        pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold seed) :
  (family.toCanonicalFreshCoinRuntimePathOramWitnessFamily modelTags hValid).toSeededRuntimePathOramWitnessFamily
      |>.RealizesCanonicalLeafValueSeedSpace := by
  simpa [CanonicalFreshCoinRuntimePathOramWitnessFamily.toSeededRuntimePathOramWitnessFamily] using
    hRefine

def CanonicalFreshCoinRuntimePathOramWitnessFamily.HiddenLeafCoverage
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) : Prop :=
  ∀ hiddenSeed, hiddenSeed < pathOramLeafValueSeedSpaceSize family.publicLeafScaffold →
    ∃ freshSeed, freshSeed < family.seedCount ∧
      pathOramLeafValues ((family.witnessAt freshSeed).pathOramLeafScheduleTrace) =
        pathOramLeafValueTraceOfSeed family.publicLeafScaffold hiddenSeed

noncomputable def CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags)
  (hCoverage : family.HiddenLeafCoverage)
  (hiddenSeed : Nat) : Nat :=
  if hSeed : hiddenSeed < pathOramLeafValueSeedSpaceSize family.publicLeafScaffold then
    Classical.choose (hCoverage hiddenSeed hSeed)
  else
    0

theorem CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed_lt
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags)
  (hCoverage : family.HiddenLeafCoverage)
  {hiddenSeed : Nat}
  (hSeed : hiddenSeed < pathOramLeafValueSeedSpaceSize family.publicLeafScaffold) :
  family.hiddenLeafRepresentativeSeed hCoverage hiddenSeed < family.seedCount := by
  have hFind := Classical.choose_spec (hCoverage hiddenSeed hSeed)
  simpa [CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed, hSeed] using
    hFind.1

theorem CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed_values
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags)
  (hCoverage : family.HiddenLeafCoverage)
  {hiddenSeed : Nat}
  (hSeed : hiddenSeed < pathOramLeafValueSeedSpaceSize family.publicLeafScaffold) :
  pathOramLeafValues
      ((family.witnessAt (family.hiddenLeafRepresentativeSeed hCoverage hiddenSeed)).pathOramLeafScheduleTrace) =
    pathOramLeafValueTraceOfSeed family.publicLeafScaffold hiddenSeed := by
  have hFind := Classical.choose_spec (hCoverage hiddenSeed hSeed)
  simpa [CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed, hSeed] using
    hFind.2

noncomputable def CanonicalFreshCoinRuntimePathOramWitnessFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags)
  (hCoverage : family.HiddenLeafCoverage) :
  SeededRuntimePathOramWitnessFamily modelTags :=
  { seedCount := pathOramLeafValueSeedSpaceSize family.publicLeafScaffold
  , witnessAt := fun hiddenSeed =>
      { family.witnessAt (family.hiddenLeafRepresentativeSeed hCoverage hiddenSeed) with
        runtimeSeed := some hiddenSeed
      }
  , seedTagged := by
      intro hiddenSeed hSeed
      rfl
  , valid := by
      intro hiddenSeed hSeed
      have hFresh :=
        family.hiddenLeafRepresentativeSeed_lt hCoverage hSeed
      simpa
        [ CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed
        , hSeed
        ] using
        family.valid (family.hiddenLeafRepresentativeSeed hCoverage hiddenSeed) hFresh
  , publicLeafScaffold := family.publicLeafScaffold
  , publicLeafScaffoldExact := by
      intro hiddenSeed hSeed
      have hFresh :=
        family.hiddenLeafRepresentativeSeed_lt hCoverage hSeed
      simpa
        [ CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed
        , hSeed
        ] using
        family.publicLeafScaffoldExact
          (family.hiddenLeafRepresentativeSeed hCoverage hiddenSeed)
          hFresh
  }

theorem CanonicalFreshCoinRuntimePathOramWitnessFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily_hiddenLeafValueRefinement
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags)
  (hCoverage : family.HiddenLeafCoverage) :
  (family.toHiddenLeafSeededRuntimePathOramWitnessFamily hCoverage).RealizesCanonicalLeafValueSeedSpace := by
  constructor
  · rfl
  · intro hiddenSeed hSeed
    simpa
      [ CanonicalFreshCoinRuntimePathOramWitnessFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily
      , CanonicalFreshCoinRuntimePathOramWitnessFamily.hiddenLeafRepresentativeSeed
      , hSeed
      ] using
      family.hiddenLeafRepresentativeSeed_values hCoverage hSeed

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkHiddenLeafCoverage
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) : Bool :=
  (List.range (pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold)).all fun hiddenSeed =>
    (List.range family.seed_count).any fun freshSeed =>
      decide
        (pathOramLeafValues (family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
          pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold hiddenSeed)

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkHiddenLeafCoverage_eq_true_iff
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) :
  family.checkHiddenLeafCoverage = true ↔
    ∀ hiddenSeed, hiddenSeed < pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold →
      ∃ freshSeed, freshSeed < family.seed_count ∧
        pathOramLeafValues (family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
          pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold hiddenSeed := by
  constructor
  · intro hCheck
    unfold ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkHiddenLeafCoverage at hCheck
    intro hiddenSeed hSeed
    have hAny :
        (List.range family.seed_count).any
          (fun freshSeed =>
            decide
              (pathOramLeafValues (family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
                pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold hiddenSeed)) = true := by
      exact (List.all_eq_true.mp hCheck) hiddenSeed (List.mem_range.mpr hSeed)
    rcases (List.any_eq_true.mp hAny) with ⟨freshSeed, hFreshMem, hFreshEq⟩
    refine ⟨freshSeed, List.mem_range.mp hFreshMem, ?_⟩
    simpa using hFreshEq
  · intro hCoverage
    unfold ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkHiddenLeafCoverage
    refine List.all_eq_true.mpr ?_
    intro hiddenSeed hHiddenMem
    have hHidden :
        hiddenSeed <
          pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold :=
      List.mem_range.mp hHiddenMem
    rcases hCoverage hiddenSeed hHidden with ⟨freshSeed, hFresh, hEq⟩
    exact List.any_eq_true.mpr ⟨freshSeed, List.mem_range.mpr hFresh, by simpa using hEq⟩

theorem ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.toCanonicalFreshCoinRuntimePathOramWitnessFamily_hiddenLeafCoverage
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hValid : family.Valid modelTags)
  (hCoverage :
    ∀ hiddenSeed, hiddenSeed < pathOramLeafValueSeedSpaceSize family.projectedPublicLeafScaffold →
      ∃ freshSeed, freshSeed < family.seed_count ∧
        pathOramLeafValues (family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
          pathOramLeafValueTraceOfSeed family.projectedPublicLeafScaffold hiddenSeed) :
  (family.toCanonicalFreshCoinRuntimePathOramWitnessFamily modelTags hValid).HiddenLeafCoverage := by
  intro hiddenSeed hSeed
  rcases hCoverage hiddenSeed hSeed with ⟨freshSeed, hFresh, hEq⟩
  exact ⟨freshSeed, hFresh, by simpa using hEq⟩

structure ConcreteRuntimePathOramConfigSlice (modelTags : SGXModelTags) where
  cfg : OramConfig
  family : SeededRuntimePathOramWitnessFamily modelTags
  cfgWellFormed : PathOramConfigWellFormed cfg
  hiddenLeafValueRefinement : family.RealizesCanonicalLeafValueSeedSpace
  publicView : OramViewPublicPart
  publicViewExact :
    ∀ seed, seed < family.seedCount →
      pathOramViewPublicPart (viewMPlus ((family.witnessAt seed).trace)) = publicView
  objectsMatchPublicConfig :
    ∀ seed, seed < family.seedCount →
      ((family.witnessAt seed).ObjectsMatchPublicConfig cfg)
  publicLocation : PathOramStorageLocationTrace
  publicLocationExact :
    ∀ seed, seed < family.seedCount →
      pathOramPublicLocationTrace
        (pathOramStorageLocationTrace
          (oramStorageView (viewMPlus ((family.witnessAt seed).trace)))) =
        publicLocation
  storageShape : PathOramStorageShape
  storageShapeExact :
    ∀ seed, seed < family.seedCount →
      pathOramStorageShape
        (oramStorageView (viewMPlus ((family.witnessAt seed).trace))) =
        storageShape
  publicOutcome : SGXPublicOutcome
  publicOutcomeExact :
    ∀ seed, seed < family.seedCount →
      ((family.witnessAt seed).publicOutcome) = publicOutcome
  boundarySchedule : List BoundaryEvent
  boundaryExact :
    ∀ seed, seed < family.seedCount →
      ((family.witnessAt seed).boundarySchedule) = boundarySchedule

def ConcreteRuntimePathOramConfigSlice.run
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) : Distribution ViewMPlus :=
  slice.family.viewDistribution

def ConcreteRuntimePathOramConfigSlice.leafRun
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  Distribution PathOramLeafScheduleTrace :=
  slice.family.leafScheduleDistribution

def ConcreteRuntimePathOramConfigSlice.storageRun
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  Distribution OramStorageView :=
  slice.run.map oramStorageView

theorem ConcreteRuntimePathOramConfigSlice.publicViewConstantProjection
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  OramConstantProjection
    pathOramViewPublicPart
    slice.run
    slice.publicView := by
  exact slice.family.viewConstantProjection_of_exact
    pathOramViewPublicPart
    slice.publicView
    slice.publicViewExact

theorem ConcreteRuntimePathOramConfigSlice.publicScaffold
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  pathOramLeafScheduleScaffoldOfPublicPart
      slice.publicView
      (pathOramProjectedExecutionLeakage slice.cfg) =
    some slice.family.publicLeafScaffold := by
  have hSeedCountPos : 0 < slice.family.seedCount :=
    slice.family.seedCount_pos_of_seedSpace slice.hiddenLeafValueRefinement
  have hValid : (slice.family.witnessAt 0).Valid modelTags :=
    slice.family.valid 0 hSeedCountPos
  have hMatch : (slice.family.witnessAt 0).ObjectsMatchPublicConfig slice.cfg :=
    slice.objectsMatchPublicConfig 0 hSeedCountPos
  have hPublicView :
      pathOramViewPublicPart (viewMPlus ((slice.family.witnessAt 0).trace)) =
        slice.publicView :=
    slice.publicViewExact 0 hSeedCountPos
  calc
    pathOramLeafScheduleScaffoldOfPublicPart
        slice.publicView
        (pathOramProjectedExecutionLeakage slice.cfg) =
      pathOramLeafScheduleScaffoldOfPublicPart
        (pathOramViewPublicPart (viewMPlus ((slice.family.witnessAt 0).trace)))
        (pathOramProjectedExecutionLeakage slice.cfg) := by
          rw [← hPublicView]
    _ =
      some ((slice.family.witnessAt 0).projectedPublicPathOramLeafScaffold) := by
        exact runtimeWitness_publicPathOramLeafScaffold_of_matchPublicConfig
          (witness := slice.family.witnessAt 0)
          modelTags
          hValid
          hMatch
          slice.cfgWellFormed
    _ = some slice.family.publicLeafScaffold := by
        simp [SeededRuntimePathOramWitnessFamily.publicLeafScaffoldExact, hSeedCountPos]

theorem ConcreteRuntimePathOramConfigSlice.leafValueCanonicalOnPublicView
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  PathOramLeafValueCanonicalOnPublicPart
    (slice.leafRun.map pathOramLeafValues)
    slice.publicView
    (pathOramProjectedExecutionLeakage slice.cfg) := by
  simpa [ConcreteRuntimePathOramConfigSlice.leafRun,
    SeededRuntimePathOramWitnessFamily.map_leafScheduleDistribution_pathOramLeafValues] using
    slice.family.leafValueCanonicalOnPublicPart_of_publicPart_of_seedSpace
      (publicPart := slice.publicView)
      (leakage := pathOramProjectedExecutionLeakage slice.cfg)
      slice.hiddenLeafValueRefinement
      slice.publicScaffold

theorem ConcreteRuntimePathOramConfigSlice.leafSchedulePublicAlignment
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  PathOramLeafSchedulePublicAlignment
    slice.leafRun
    slice.publicView
    (pathOramProjectedExecutionLeakage slice.cfg) := by
  simpa [ConcreteRuntimePathOramConfigSlice.leafRun] using
    slice.family.leafSchedulePublicAlignment_of_publicPart
      (publicPart := slice.publicView)
      (leakage := pathOramProjectedExecutionLeakage slice.cfg)
      slice.publicScaffold

theorem ConcreteRuntimePathOramConfigSlice.bucketProjection
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  (slice.storageRun.map pathOramStorageLocationTrace).map pathOramBucketTrace =
    slice.leafRun.map pathOramBucketTraceOfLeafScheduleTrace := by
  unfold ConcreteRuntimePathOramConfigSlice.storageRun
    ConcreteRuntimePathOramConfigSlice.run
    ConcreteRuntimePathOramConfigSlice.leafRun
    SeededRuntimeWitnessFamily.viewDistribution
    SeededRuntimePathOramWitnessFamily.leafScheduleDistribution
  rw [List.map_map, List.map_map, List.map_map, List.map_map]
  apply List.map_congr_left
  intro seed hSeedMem
  have hSeedLt : seed < slice.family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  have hBucket :=
    runtimeWitness_pathOramBucketProjection_exact
      (slice.family.witnessAt seed)
      modelTags
      (slice.family.valid seed hSeedLt)
  simpa [pathOramBucketTraceOfView, RuntimeRefinementWitness.pathOramBucketTrace] using hBucket.symm

theorem ConcreteRuntimePathOramConfigSlice.publicLocationConstantProjection
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  OramConstantProjection
    pathOramPublicLocationTrace
    (slice.storageRun.map pathOramStorageLocationTrace)
    slice.publicLocation := by
  refine oramConstantProjection_map_of_const
    pathOramPublicLocationTrace
    slice.publicLocation
    pathOramStorageLocationTrace
    slice.storageRun
    ?_
  intro storage hMem
  have hMapped :
      storage ∈ slice.storageRun := hMem
  unfold ConcreteRuntimePathOramConfigSlice.storageRun
    ConcreteRuntimePathOramConfigSlice.run
    SeededRuntimeWitnessFamily.viewDistribution at hMapped
  simp at hMapped
  rcases hMapped with ⟨seed, hSeedMem, rfl⟩
  have hSeedLt : seed < slice.family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  exact slice.publicLocationExact seed hSeedLt

theorem ConcreteRuntimePathOramConfigSlice.storageShapeConstantProjection
  {modelTags : SGXModelTags}
  (slice : ConcreteRuntimePathOramConfigSlice modelTags) :
  OramConstantProjection
    pathOramStorageShape
    slice.storageRun
    slice.storageShape := by
  intro storage hMem
  unfold ConcreteRuntimePathOramConfigSlice.storageRun
    ConcreteRuntimePathOramConfigSlice.run
    SeededRuntimeWitnessFamily.viewDistribution at hMem
  simp at hMem
  rcases hMem with ⟨seed, hSeedMem, rfl⟩
  have hSeedLt : seed < slice.family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  exact slice.storageShapeExact seed hSeedLt

def ConcreteRuntimePathOramPaperPairBoundary
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (cfg : OramConfig)
  (publicOutcome : SGXPublicOutcome)
  (boundarySchedule : List BoundaryEvent)
  (lhs rhs : Distribution ViewMPlus) : Prop :=
  (pathOramLocalPosmapV1SecurityInterface assumptions).localTheorem
      lhs
      rhs
      (executionLeakage cfg) ∧
    SGXViewRelation
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (lhs.map (sgxViewOfOramView cfg publicOutcome boundarySchedule (oramControllerMicroTrace cfg)))
      (rhs.map (sgxViewOfOramView cfg publicOutcome boundarySchedule (oramControllerMicroTrace cfg)))
      (executionLeakage cfg)
      (oramMicroLeakage (fun _ => publicOutcome) modelTags cfg) ∧
    teeStorageLocalTheoremWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (lhs.map (viewTEEStoreFromOramView cfg publicOutcome.terminationStatus publicOutcome.outputShape))
      (rhs.map (viewTEEStoreFromOramView cfg publicOutcome.terminationStatus publicOutcome.outputShape))
      (executionLeakage cfg)

structure ConcreteRuntimePathOramPairSlice (modelTags : SGXModelTags) where
  lhs : ConcreteRuntimePathOramConfigSlice modelTags
  rhs : ConcreteRuntimePathOramConfigSlice modelTags
  sameCfg : lhs.cfg = rhs.cfg
  samePublicView : lhs.publicView = rhs.publicView
  samePublicLocation : lhs.publicLocation = rhs.publicLocation
  sameStorageShape : lhs.storageShape = rhs.storageShape
  samePublicOutcome : lhs.publicOutcome = rhs.publicOutcome
  sameBoundarySchedule : lhs.boundarySchedule = rhs.boundarySchedule

theorem ConcreteRuntimePathOramPairSlice.localPathOramViewRelation
  {modelTags : SGXModelTags}
  (pair : ConcreteRuntimePathOramPairSlice modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  (pathOramLocalPosmapV1SecurityInterface assumptions).localTheorem
    pair.lhs.run
    pair.rhs.run
    (executionLeakage pair.lhs.cfg) := by
  have hLeakage :
      PathOramLeakage (executionLeakage pair.lhs.cfg) := by
    exact pathOramConfigWellFormed_executionLeakage pair.lhs.cfgWellFormed
  have hPublic :
      OramExactProjectionRelation
        pathOramViewPublicPart
        pair.lhs.run
        pair.rhs.run := by
    apply oramExactProjectionRelation_of_constant pair.samePublicView
    · exact pair.lhs.publicViewConstantProjection
    · exact pair.rhs.publicViewConstantProjection
  have hScaffoldEq : pair.lhs.family.publicLeafScaffold = pair.rhs.family.publicLeafScaffold := by
    calc
      pair.lhs.family.publicLeafScaffold =
        Option.getD
          (pathOramLeafScheduleScaffoldOfPublicPart
            pair.lhs.publicView
            (pathOramProjectedExecutionLeakage pair.lhs.cfg))
          [] := by
            rw [pair.lhs.publicScaffold]
            simp
      _ =
        Option.getD
          (pathOramLeafScheduleScaffoldOfPublicPart
            pair.rhs.publicView
            (pathOramProjectedExecutionLeakage pair.rhs.cfg))
          [] := by
            simp [pair.sameCfg, pair.samePublicView]
      _ = pair.rhs.family.publicLeafScaffold := by
            rw [pair.rhs.publicScaffold]
            simp
  have hLeaf :
      pathOramLeafScheduleRelationFromLeafValueRelation canonicalPathOramLeafValueRelation
        pair.lhs.leafRun
        pair.rhs.leafRun
        (pathOramProjectedExecutionLeakage pair.lhs.cfg) := by
    exact seededRuntimePathOram_leafScheduleRelation_of_publicScaffoldEq_of_seedSpace
      pair.lhs.hiddenLeafValueRefinement
      pair.rhs.hiddenLeafValueRefinement
      hScaffoldEq
  have hPublicLocation :
      OramExactProjectionRelation
        pathOramPublicLocationTrace
        (pair.lhs.storageRun.map pathOramStorageLocationTrace)
        (pair.rhs.storageRun.map pathOramStorageLocationTrace) := by
    apply oramExactProjectionRelation_of_constant pair.samePublicLocation
    · exact pair.lhs.publicLocationConstantProjection
    · exact pair.rhs.publicLocationConstantProjection
  have hShape :
      OramExactProjectionRelation
        pathOramStorageShape
        pair.lhs.storageRun
        pair.rhs.storageRun := by
    apply oramExactProjectionRelation_of_constant pair.sameStorageShape
    · exact pair.lhs.storageShapeConstantProjection
    · exact pair.rhs.storageShapeConstantProjection
  have hStorage :
      pathOramStandardStorageTheorem
        assumptions.toPathOramSecurityAssumptions
        pair.lhs.storageRun
        pair.rhs.storageRun
        (executionLeakage pair.lhs.cfg) := by
    apply pathOramProjectedStorageTheorem_projects_to_standard
      assumptions.toPathOramSecurityAssumptions
    apply pathOramProjectedStorageTheorem_of_leafScheduleBucketLocationPublicTrace_and_shape
      assumptions.toCanonicalLeafValueSecurityAssumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions
    · exact hLeaf
    · exact hLeaf.2
    · simpa using pair.lhs.bucketProjection
    · simpa using pair.rhs.bucketProjection
    · exact hPublicLocation
    · exact hShape
  exact ⟨hLeakage, hPublic, hStorage⟩

theorem ConcreteRuntimePathOramPairSlice.paperPairBoundary
  {modelTags : SGXModelTags}
  (pair : ConcreteRuntimePathOramPairSlice modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ConcreteRuntimePathOramPaperPairBoundary
    (modelTags := modelTags)
    assumptions
    pair.lhs.cfg
    pair.lhs.publicOutcome
    pair.lhs.boundarySchedule
    pair.lhs.run
    pair.rhs.run := by
  constructor
  · exact pair.localPathOramViewRelation assumptions
  constructor
  · constructor
    · apply exactProjectionRelation_of_constant
        pair.samePublicOutcome
      · refine constantProjection_map_of_const sgxPublicOutcome pair.lhs.publicOutcome _ pair.lhs.run ?_
        intro view hMem
        simp
      · refine constantProjection_map_of_const sgxPublicOutcome pair.rhs.publicOutcome _ pair.rhs.run ?_
        intro view hMem
        simp [pair.samePublicOutcome]
    constructor
    · apply exactProjectionRelation_of_constant
        pair.sameBoundarySchedule
      · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) pair.lhs.boundarySchedule _ pair.lhs.run ?_
        intro view hMem
        simp
      · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule) pair.rhs.boundarySchedule _ pair.rhs.run ?_
        intro view hMem
        simp [pair.sameBoundarySchedule]
    constructor
    · simpa [ConcreteRuntimePathOramConfigSlice.run, sgxStorageDistribution] using
        (oramSecurity_projects_to_sgxStorage
          (pathOramLocalPosmapV1SecurityInterface assumptions)
          pair.lhs.cfg
          pair.rhs.cfg
          pair.lhs.run
          pair.rhs.run
          (by simpa [pair.sameCfg] using sameOramPublicProjection_refl pair.lhs.cfg)
          (pair.localPathOramViewRelation assumptions))
    · constructor
      · exact
          oramControllerMicroDistribution_normalized
            (run := fun _ => pair.lhs.run)
            (publicOutcome := fun _ => pair.lhs.publicOutcome)
            (boundarySchedule := fun _ => pair.lhs.boundarySchedule)
            (cfg := pair.lhs.cfg)
      · exact
          oramControllerMicroDistribution_normalized
            (run := fun _ => pair.rhs.run)
            (publicOutcome := fun _ => pair.lhs.publicOutcome)
            (boundarySchedule := fun _ => pair.lhs.boundarySchedule)
            (cfg := pair.lhs.cfg)
  · exact
      oramSecurity_projects_to_teeStorage
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        pair.lhs.cfg
        pair.lhs.cfg
        pair.lhs.publicOutcome.terminationStatus
        pair.lhs.publicOutcome.outputShape
        pair.lhs.run
        pair.rhs.run
        (sameOramPublicProjection_refl pair.lhs.cfg)
        (pair.localPathOramViewRelation assumptions)

noncomputable def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.toLhsConcreteSlice
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (hValid : certificate.Valid modelTags)
  (hCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.lhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.lhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.lhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.lhs_family.projectedPublicLeafScaffold
                hiddenSeed) :
  ConcreteRuntimePathOramConfigSlice modelTags :=
  let hFamValid : certificate.lhs_family.Valid modelTags := hValid.2.1.1
  let runtimeFamily :=
    certificate.lhs_family.toCanonicalFreshCoinRuntimePathOramWitnessFamily modelTags hFamValid
  let hRuntimeCover :=
    certificate.lhs_family.toCanonicalFreshCoinRuntimePathOramWitnessFamily_hiddenLeafCoverage
      modelTags
      hFamValid
      hCoverage
  let family := runtimeFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily hRuntimeCover
  let hSelected :
      ∀ hiddenSeed, hiddenSeed < family.seedCount →
        ∃ witness : ImportedRuntimeRefinementWitness,
          (family.witnessAt hiddenSeed =
            { ImportedRuntimeRefinementWitness.toRuntimeWitness witness with runtimeSeed := some hiddenSeed }) ∧
          ((ImportedRuntimeRefinementWitness.toRuntimeWitness witness).ObjectsMatchPublicConfig
            certificate.runtimeCfg) ∧
          pathOramViewPublicPart (viewMPlus (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).trace) =
            certificate.runtimePublicView ∧
          pathOramPublicLocationTrace
              (pathOramStorageLocationTrace
                (oramStorageView
                  (viewMPlus (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).trace))) =
            certificate.runtimePublicLocation ∧
          pathOramStorageShape
              (oramStorageView
                (viewMPlus (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).trace)) =
            certificate.runtimeStorageShape ∧
          (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).publicOutcome =
            certificate.runtimePublicOutcome ∧
          (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).boundarySchedule =
            certificate.runtimeBoundarySchedule := by
    intro hiddenSeed hSeed
    let freshSeed :=
      runtimeFamily.hiddenLeafRepresentativeSeed hRuntimeCover hiddenSeed
    have hFresh : freshSeed < certificate.lhs_family.seed_count := by
      simpa [runtimeFamily, freshSeed] using
        runtimeFamily.hiddenLeafRepresentativeSeed_lt hRuntimeCover hSeed
    rcases hValid.2.1.2 freshSeed hFresh with
      ⟨witness, hGet, hCfgMatch, hView, hLocation, hShape, hOutcome, hBoundary, _hController, _hMicro⟩
    have hRuntime0 :
        runtimeFamily.witnessAt freshSeed = ImportedRuntimeRefinementWitness.toRuntimeWitness witness := by
      simp
        [ runtimeFamily
        , ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.toCanonicalFreshCoinRuntimePathOramWitnessFamily
        , ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt
        , hGet
        ]
    have hChosen :
        runtimeFamily.witnessAt
            (runtimeFamily.hiddenLeafRepresentativeSeed hRuntimeCover hiddenSeed) =
          ImportedRuntimeRefinementWitness.toRuntimeWitness witness := by
      simpa [freshSeed] using hRuntime0
    have hRuntime :
        family.witnessAt hiddenSeed =
          { ImportedRuntimeRefinementWitness.toRuntimeWitness witness with runtimeSeed := some hiddenSeed } := by
      simp
        [ family
        , CanonicalFreshCoinRuntimePathOramWitnessFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily
        , hChosen
        ]
    exact ⟨witness, hRuntime, hCfgMatch, hView, hLocation, hShape, hOutcome, hBoundary⟩
  { cfg := certificate.runtimeCfg
  , family := family
  , cfgWellFormed := hValid.1
  , hiddenLeafValueRefinement :=
      by
        simpa [runtimeFamily, family] using
          runtimeFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily_hiddenLeafValueRefinement
            hRuntimeCover
  , publicView := certificate.runtimePublicView
  , publicViewExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, hView, _hLocation, _hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hView
  , objectsMatchPublicConfig := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, hCfgMatch, _hView, _hLocation, _hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hCfgMatch
  , publicLocation := certificate.runtimePublicLocation
  , publicLocationExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, hLocation, _hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hLocation
  , storageShape := certificate.runtimeStorageShape
  , storageShapeExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, _hLocation, hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hShape
  , publicOutcome := certificate.runtimePublicOutcome
  , publicOutcomeExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, _hLocation, _hShape, hOutcome, _hBoundary⟩
      simpa [hRuntime] using hOutcome
  , boundarySchedule := certificate.runtimeBoundarySchedule
  , boundaryExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, _hLocation, _hShape, _hOutcome, hBoundary⟩
      simpa [hRuntime] using hBoundary
  }

noncomputable def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.toRhsConcreteSlice
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (hValid : certificate.Valid modelTags)
  (hCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.rhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.rhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.rhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.rhs_family.projectedPublicLeafScaffold
                hiddenSeed) :
  ConcreteRuntimePathOramConfigSlice modelTags :=
  let hFamValid : certificate.rhs_family.Valid modelTags := hValid.2.2.1
  let runtimeFamily :=
    certificate.rhs_family.toCanonicalFreshCoinRuntimePathOramWitnessFamily modelTags hFamValid
  let hRuntimeCover :=
    certificate.rhs_family.toCanonicalFreshCoinRuntimePathOramWitnessFamily_hiddenLeafCoverage
      modelTags
      hFamValid
      hCoverage
  let family := runtimeFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily hRuntimeCover
  let hSelected :
      ∀ hiddenSeed, hiddenSeed < family.seedCount →
        ∃ witness : ImportedRuntimeRefinementWitness,
          (family.witnessAt hiddenSeed =
            { ImportedRuntimeRefinementWitness.toRuntimeWitness witness with runtimeSeed := some hiddenSeed }) ∧
          ((ImportedRuntimeRefinementWitness.toRuntimeWitness witness).ObjectsMatchPublicConfig
            certificate.runtimeCfg) ∧
          pathOramViewPublicPart (viewMPlus (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).trace) =
            certificate.runtimePublicView ∧
          pathOramPublicLocationTrace
              (pathOramStorageLocationTrace
                (oramStorageView
                  (viewMPlus (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).trace))) =
            certificate.runtimePublicLocation ∧
          pathOramStorageShape
              (oramStorageView
                (viewMPlus (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).trace)) =
            certificate.runtimeStorageShape ∧
          (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).publicOutcome =
            certificate.runtimePublicOutcome ∧
          (ImportedRuntimeRefinementWitness.toRuntimeWitness witness).boundarySchedule =
            certificate.runtimeBoundarySchedule := by
    intro hiddenSeed hSeed
    let freshSeed :=
      runtimeFamily.hiddenLeafRepresentativeSeed hRuntimeCover hiddenSeed
    have hFresh : freshSeed < certificate.rhs_family.seed_count := by
      simpa [runtimeFamily, freshSeed] using
        runtimeFamily.hiddenLeafRepresentativeSeed_lt hRuntimeCover hSeed
    rcases hValid.2.2.2 freshSeed hFresh with
      ⟨witness, hGet, hCfgMatch, hView, hLocation, hShape, hOutcome, hBoundary, _hController, _hMicro⟩
    have hRuntime0 :
        runtimeFamily.witnessAt freshSeed = ImportedRuntimeRefinementWitness.toRuntimeWitness witness := by
      simp
        [ runtimeFamily
        , ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.toCanonicalFreshCoinRuntimePathOramWitnessFamily
        , ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt
        , hGet
        ]
    have hChosen :
        runtimeFamily.witnessAt
            (runtimeFamily.hiddenLeafRepresentativeSeed hRuntimeCover hiddenSeed) =
          ImportedRuntimeRefinementWitness.toRuntimeWitness witness := by
      simpa [freshSeed] using hRuntime0
    have hRuntime :
        family.witnessAt hiddenSeed =
          { ImportedRuntimeRefinementWitness.toRuntimeWitness witness with runtimeSeed := some hiddenSeed } := by
      simp
        [ family
        , CanonicalFreshCoinRuntimePathOramWitnessFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily
        , hChosen
        ]
    exact ⟨witness, hRuntime, hCfgMatch, hView, hLocation, hShape, hOutcome, hBoundary⟩
  { cfg := certificate.runtimeCfg
  , family := family
  , cfgWellFormed := hValid.1
  , hiddenLeafValueRefinement :=
      by
        simpa [runtimeFamily, family] using
          runtimeFamily.toHiddenLeafSeededRuntimePathOramWitnessFamily_hiddenLeafValueRefinement
            hRuntimeCover
  , publicView := certificate.runtimePublicView
  , publicViewExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, hView, _hLocation, _hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hView
  , objectsMatchPublicConfig := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, hCfgMatch, _hView, _hLocation, _hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hCfgMatch
  , publicLocation := certificate.runtimePublicLocation
  , publicLocationExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, hLocation, _hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hLocation
  , storageShape := certificate.runtimeStorageShape
  , storageShapeExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, _hLocation, hShape, _hOutcome, _hBoundary⟩
      simpa [hRuntime] using hShape
  , publicOutcome := certificate.runtimePublicOutcome
  , publicOutcomeExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, _hLocation, _hShape, hOutcome, _hBoundary⟩
      simpa [hRuntime] using hOutcome
  , boundarySchedule := certificate.runtimeBoundarySchedule
  , boundaryExact := by
      intro hiddenSeed hSeed
      rcases hSelected hiddenSeed hSeed with
        ⟨witness, hRuntime, _hCfgMatch, _hView, _hLocation, _hShape, _hOutcome, hBoundary⟩
      simpa [hRuntime] using hBoundary
  }

noncomputable def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.toConcretePairSlice
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (hValid : certificate.Valid modelTags)
  (hLhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.lhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.lhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.lhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.lhs_family.projectedPublicLeafScaffold
                hiddenSeed)
  (hRhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.rhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.rhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.rhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.rhs_family.projectedPublicLeafScaffold
                hiddenSeed) :
  ConcreteRuntimePathOramPairSlice modelTags :=
  { lhs := certificate.toLhsConcreteSlice modelTags hValid hLhsCoverage
  , rhs := certificate.toRhsConcreteSlice modelTags hValid hRhsCoverage
  , sameCfg := rfl
  , samePublicView := rfl
  , samePublicLocation := rfl
  , sameStorageShape := rfl
  , samePublicOutcome := rfl
  , sameBoundarySchedule := rfl
  }

theorem ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.paperPairBoundary
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hValid : certificate.Valid modelTags)
  (hLhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.lhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.lhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.lhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.lhs_family.projectedPublicLeafScaffold
                hiddenSeed)
  (hRhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.rhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.rhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.rhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.rhs_family.projectedPublicLeafScaffold
                hiddenSeed) :
  ConcreteRuntimePathOramPaperPairBoundary
    (modelTags := modelTags)
    assumptions
    certificate.runtimeCfg
    certificate.runtimePublicOutcome
    certificate.runtimeBoundarySchedule
    ((certificate.toLhsConcreteSlice modelTags hValid hLhsCoverage).run)
    ((certificate.toRhsConcreteSlice modelTags hValid hRhsCoverage).run) := by
  exact
    (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).paperPairBoundary
      assumptions

end UOToolchain
