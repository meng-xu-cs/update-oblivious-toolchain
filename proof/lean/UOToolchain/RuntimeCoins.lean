import UOToolchain.RuntimeRefinement
import UOToolchain.SgxOramProjection

namespace UOToolchain

def runtimeSeedIndexDistribution (seedCount : Nat) : FiniteDistribution Nat :=
  FiniteDistribution.chooseNat seedCount

structure SeededRuntimeWitnessFamily (modelTags : SGXModelTags) where
  seedCount : Nat
  witnessAt : Nat → RuntimeRefinementWitness
  seedTagged :
    ∀ seed, seed < seedCount → (witnessAt seed).runtimeSeed = some seed
  valid :
    ∀ seed, seed < seedCount → (witnessAt seed).Valid modelTags

structure SeededRuntimePathOramWitnessFamily (modelTags : SGXModelTags)
    extends SeededRuntimeWitnessFamily modelTags where
  publicLeafScaffold : PathOramLeafScheduleScaffold
  publicLeafScaffoldExact :
    ∀ seed, seed < seedCount →
      (witnessAt seed).projectedPublicPathOramLeafScaffold = publicLeafScaffold

@[simp] theorem runtimeWitness_valid_runtimeSeed_iff
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (runtimeSeed : Option Nat) :
  ({ witness with runtimeSeed := runtimeSeed }).Valid modelTags ↔
    witness.Valid modelTags := by
  cases witness <;> rfl

@[simp] theorem runtimeWitness_proofGradeValid_runtimeSeed_iff
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (runtimeSeed : Option Nat) :
  ({ witness with runtimeSeed := runtimeSeed }).ProofGradeValid modelTags ↔
    witness.ProofGradeValid modelTags := by
  cases witness <;> rfl

def RuntimeRefinementWitness.toSingletonSeededRuntimeWitnessFamily
  {modelTags : SGXModelTags}
  (witness : RuntimeRefinementWitness)
  (hValid : witness.Valid modelTags) :
  SeededRuntimeWitnessFamily modelTags :=
  { seedCount := 1
  , witnessAt := fun _ => { witness with runtimeSeed := some 0 }
  , seedTagged := by
      intro seed hSeed
      change seed < 1 at hSeed
      have hZero : seed = 0 := by omega
      subst hZero
      rfl
  , valid := by
      intro seed hSeed
      change seed < 1 at hSeed
      have hZero : seed = 0 := by omega
      subst hZero
      simpa using hValid
  }

def RuntimeRefinementWitness.toSingletonSeededRuntimePathOramWitnessFamily
  {modelTags : SGXModelTags}
  (witness : RuntimeRefinementWitness)
  (hValid : witness.Valid modelTags) :
  SeededRuntimePathOramWitnessFamily modelTags :=
  { witness.toSingletonSeededRuntimeWitnessFamily hValid with
    publicLeafScaffold := witness.projectedPublicPathOramLeafScaffold
    publicLeafScaffoldExact := by
      intro seed hSeed
      change seed < 1 at hSeed
      have hZero : seed = 0 := by omega
      subst hZero
      cases witness <;> rfl
  }

def SeededRuntimeWitnessFamily.witnessDistribution
  {modelTags : SGXModelTags}
  (family : SeededRuntimeWitnessFamily modelTags) : Distribution RuntimeRefinementWitness :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map family.witnessAt

def SeededRuntimeWitnessFamily.viewDistribution
  {modelTags : SGXModelTags}
  (family : SeededRuntimeWitnessFamily modelTags) : Distribution ViewMPlus :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map
    (fun seed => viewMPlus ((family.witnessAt seed).trace))

def SeededRuntimePathOramWitnessFamily.leafScheduleDistribution
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags) :
  Distribution PathOramLeafScheduleTrace :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map
    (fun seed => (family.witnessAt seed).pathOramLeafScheduleTrace)

def SeededRuntimePathOramWitnessFamily.leafValueDistribution
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags) :
  Distribution PathOramLeafValueTrace :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map
    (fun seed => pathOramLeafValues ((family.witnessAt seed).pathOramLeafScheduleTrace))

def SeededRuntimePathOramWitnessFamily.RealizesCanonicalLeafValueSeedSpace
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags) : Prop :=
  family.seedCount = pathOramLeafValueSeedSpaceSize family.publicLeafScaffold ∧
    ∀ seed, seed < family.seedCount →
      pathOramLeafValues ((family.witnessAt seed).pathOramLeafScheduleTrace) =
        pathOramLeafValueTraceOfSeed family.publicLeafScaffold seed

structure CanonicalFreshCoinRuntimePathOramWitnessFamily (modelTags : SGXModelTags) where
  seedCount : Nat
  witnessAt : Nat → RuntimeRefinementWitness
  valid :
    ∀ seed, seed < seedCount → (witnessAt seed).Valid modelTags
  publicLeafScaffold : PathOramLeafScheduleScaffold
  publicLeafScaffoldExact :
    ∀ seed, seed < seedCount →
      (witnessAt seed).projectedPublicPathOramLeafScaffold = publicLeafScaffold
  publicFreshCoinScaffold : PathOramLeafScheduleScaffold
  freshCoinScaffoldExact :
    ∀ seed, seed < seedCount →
      (witnessAt seed).pathOramFreshCoinScaffold? = some publicFreshCoinScaffold
  freshCoinSeedSpaceExact :
    seedCount = pathOramLeafValueSeedSpaceSize publicFreshCoinScaffold
  freshCoinValuesExact :
    ∀ seed, seed < seedCount →
      (witnessAt seed).pathOramFreshCoinValues? =
        some (pathOramLeafValueTraceOfSeed publicFreshCoinScaffold seed)

def CanonicalFreshCoinRuntimePathOramWitnessFamily.witnessDistribution
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) :
  Distribution RuntimeRefinementWitness :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map family.witnessAt

def CanonicalFreshCoinRuntimePathOramWitnessFamily.viewDistribution
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) :
  Distribution ViewMPlus :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map
    (fun seed => viewMPlus ((family.witnessAt seed).trace))

def CanonicalFreshCoinRuntimePathOramWitnessFamily.freshCoinValueDistribution
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) :
  Distribution PathOramLeafValueTrace :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map
    (fun seed =>
      match (family.witnessAt seed).pathOramFreshCoinValues? with
      | some coins => coins
      | none => [])

theorem CanonicalFreshCoinRuntimePathOramWitnessFamily.seedCount_pos
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) :
  0 < family.seedCount := by
  rw [family.freshCoinSeedSpaceExact]
  exact pathOramLeafValueSeedSpaceSize_pos family.publicFreshCoinScaffold

theorem CanonicalFreshCoinRuntimePathOramWitnessFamily.freshCoinValueDistribution_eq_canonical
  {modelTags : SGXModelTags}
  (family : CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags) :
  family.freshCoinValueDistribution =
    (pathOramLeafValueDistributionOfScaffold family.publicFreshCoinScaffold).samples := by
  rw [CanonicalFreshCoinRuntimePathOramWitnessFamily.freshCoinValueDistribution]
  rw [runtimeSeedIndexDistribution, family.freshCoinSeedSpaceExact]
  rw [pathOramLeafValueDistributionOfScaffold_samples_eq_seedRange]
  apply List.map_congr_left
  intro seed hSeedMem
  have hSeedLt : seed < family.seedCount := by
    simpa [family.freshCoinSeedSpaceExact] using
      (List.mem_range.mp hSeedMem :
        seed < pathOramLeafValueSeedSpaceSize family.publicFreshCoinScaffold)
  have hValues := family.freshCoinValuesExact seed hSeedLt
  simp [hValues]

theorem SeededRuntimeWitnessFamily.viewConstantProjection_of_exact
  {modelTags : SGXModelTags}
  (family : SeededRuntimeWitnessFamily modelTags)
  {α : Type}
  (project : ViewMPlus → α)
  (value : α)
  (hExact :
    ∀ seed, seed < family.seedCount →
      project (viewMPlus ((family.witnessAt seed).trace)) = value) :
  OramConstantProjection
    project
    family.viewDistribution
    value := by
  intro view hMem
  have hMapped :
      view ∈
        (runtimeSeedIndexDistribution family.seedCount).samples.map
          (fun seed => viewMPlus ((family.witnessAt seed).trace)) := by
    simpa [SeededRuntimeWitnessFamily.viewDistribution] using hMem
  simp at hMapped
  rcases hMapped with ⟨seed, hSeedMem, rfl⟩
  have hSeedLt : seed < family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  exact hExact seed hSeedLt

theorem SeededRuntimeWitnessFamily.viewDistribution_zero_mem
  {modelTags : SGXModelTags}
  (family : SeededRuntimeWitnessFamily modelTags)
  (hSeedCountPos : 0 < family.seedCount) :
  viewMPlus ((family.witnessAt 0).trace) ∈ family.viewDistribution := by
  unfold SeededRuntimeWitnessFamily.viewDistribution runtimeSeedIndexDistribution
  apply List.mem_map.mpr
  refine ⟨0, ?_, rfl⟩
  simpa using hSeedCountPos

theorem SeededRuntimeWitnessFamily.eq_of_viewConstantProjection
  {modelTags : SGXModelTags}
  (family : SeededRuntimeWitnessFamily modelTags)
  {α : Type}
  {project : ViewMPlus → α}
  {value₁ value₂ : α}
  (hSeedCountPos : 0 < family.seedCount)
  (hConst₁ : OramConstantProjection project family.viewDistribution value₁)
  (hConst₂ : OramConstantProjection project family.viewDistribution value₂) :
  value₁ = value₂ := by
  have hMem :
      viewMPlus ((family.witnessAt 0).trace) ∈ family.viewDistribution :=
    family.viewDistribution_zero_mem hSeedCountPos
  calc
    value₁ = project (viewMPlus ((family.witnessAt 0).trace)) := by
      symm
      exact hConst₁ _ hMem
    _ = value₂ := by
      exact hConst₂ _ hMem

theorem SeededRuntimePathOramWitnessFamily.seedCount_pos_of_seedSpace
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  (hSeedSpace : family.RealizesCanonicalLeafValueSeedSpace) :
  0 < family.seedCount := by
  rcases hSeedSpace with ⟨hCount, _hValues⟩
  rw [hCount]
  exact pathOramLeafValueSeedSpaceSize_pos family.publicLeafScaffold

theorem SeededRuntimePathOramWitnessFamily.leafScaffoldConstantProjection
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags) :
  OramConstantProjection
    pathOramLeafScheduleScaffold
    family.leafScheduleDistribution
    family.publicLeafScaffold := by
  intro trace hMem
  have hMapped :
      trace ∈
        (runtimeSeedIndexDistribution family.seedCount).samples.map
          (fun seed => (family.witnessAt seed).pathOramLeafScheduleTrace) := by
    simpa [SeededRuntimePathOramWitnessFamily.leafScheduleDistribution] using hMem
  simp at hMapped
  rcases hMapped with ⟨seed, hSeedMem, rfl⟩
  have hSeedLt : seed < family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  calc
    pathOramLeafScheduleScaffold ((family.witnessAt seed).pathOramLeafScheduleTrace) =
        (family.witnessAt seed).projectedPathOramLeafScaffold := by
          exact runtimeWitness_projectedPathOramLeafScaffold_exact (family.witnessAt seed)
    _ = (family.witnessAt seed).projectedPublicPathOramLeafScaffold := by
          symm
          exact runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
            (family.witnessAt seed)
            modelTags
            (family.valid seed hSeedLt)
    _ = family.publicLeafScaffold := by
          exact family.publicLeafScaffoldExact seed hSeedLt

theorem SeededRuntimePathOramWitnessFamily.leafValueDistribution_eq_canonical
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  (hCanonical :
    family.leafValueDistribution =
      (pathOramLeafValueDistributionOfScaffold family.publicLeafScaffold).samples) :
  family.leafValueDistribution =
    (pathOramLeafValueDistributionOfScaffold family.publicLeafScaffold).samples := by
  exact hCanonical

theorem SeededRuntimePathOramWitnessFamily.leafValueDistribution_eq_canonical_of_seedSpace
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  (hSeedSpace : family.RealizesCanonicalLeafValueSeedSpace) :
  family.leafValueDistribution =
    (pathOramLeafValueDistributionOfScaffold family.publicLeafScaffold).samples := by
  rcases hSeedSpace with ⟨hCount, hSeedValues⟩
  rw [SeededRuntimePathOramWitnessFamily.leafValueDistribution, runtimeSeedIndexDistribution]
  rw [hCount, pathOramLeafValueDistributionOfScaffold_samples_eq_seedRange]
  apply List.map_congr_left
  intro seed hSeedMem
  have hSeedLt : seed < family.seedCount := by
    simpa [hCount] using
      (List.mem_range.mp hSeedMem :
        seed < pathOramLeafValueSeedSpaceSize family.publicLeafScaffold)
  exact hSeedValues seed hSeedLt

@[simp] theorem SeededRuntimePathOramWitnessFamily.map_leafScheduleDistribution_pathOramLeafValues
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags) :
  family.leafScheduleDistribution.map pathOramLeafValues =
    family.leafValueDistribution := by
  simp [ SeededRuntimePathOramWitnessFamily.leafScheduleDistribution
    , SeededRuntimePathOramWitnessFamily.leafValueDistribution
    , List.map_map
    ]

theorem SeededRuntimePathOramWitnessFamily.leafSchedulePublicAlignment_of_publicPart
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  {publicPart : OramViewPublicPart}
  {leakage : PathOramProjectedLeakage}
  (hScaffold :
    pathOramLeafScheduleScaffoldOfPublicPart publicPart leakage =
      some family.publicLeafScaffold) :
  PathOramLeafSchedulePublicAlignment
    family.leafScheduleDistribution
    publicPart
    leakage := by
  exact ⟨family.publicLeafScaffold, hScaffold, family.leafScaffoldConstantProjection⟩

theorem SeededRuntimePathOramWitnessFamily.leafValueCanonicalOnPublicPart_of_publicPart
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  {publicPart : OramViewPublicPart}
  {leakage : PathOramProjectedLeakage}
  (hCanonical :
    family.leafValueDistribution =
      (pathOramLeafValueDistributionOfScaffold family.publicLeafScaffold).samples)
  (hScaffold :
    pathOramLeafScheduleScaffoldOfPublicPart publicPart leakage =
      some family.publicLeafScaffold) :
  PathOramLeafValueCanonicalOnPublicPart
    family.leafValueDistribution
    publicPart
    leakage := by
  exact ⟨family.publicLeafScaffold, hScaffold,
    family.leafValueDistribution_eq_canonical hCanonical⟩

theorem SeededRuntimePathOramWitnessFamily.leafValueCanonicalOnPublicPart_of_publicPart_of_seedSpace
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  {publicPart : OramViewPublicPart}
  {leakage : PathOramProjectedLeakage}
  (hSeedSpace : family.RealizesCanonicalLeafValueSeedSpace)
  (hScaffold :
    pathOramLeafScheduleScaffoldOfPublicPart publicPart leakage =
      some family.publicLeafScaffold) :
  PathOramLeafValueCanonicalOnPublicPart
    family.leafValueDistribution
    publicPart
    leakage := by
  exact family.leafValueCanonicalOnPublicPart_of_publicPart
    (family.leafValueDistribution_eq_canonical_of_seedSpace hSeedSpace)
    hScaffold

theorem seededRuntimePathOram_leafScaffoldExactProjection_of_publicScaffoldEq
  {modelTags : SGXModelTags}
  {family₁ family₂ : SeededRuntimePathOramWitnessFamily modelTags}
  (hPublic : family₁.publicLeafScaffold = family₂.publicLeafScaffold) :
  OramExactProjectionRelation
    pathOramLeafScheduleScaffold
    family₁.leafScheduleDistribution
    family₂.leafScheduleDistribution := by
  apply oramExactProjectionRelation_of_constant hPublic
  · exact family₁.leafScaffoldConstantProjection
  · exact family₂.leafScaffoldConstantProjection

theorem seededRuntimePathOram_canonicalLeafValueRelation_of_publicScaffoldEq
  {modelTags : SGXModelTags}
  {family₁ family₂ : SeededRuntimePathOramWitnessFamily modelTags}
  {leakage : PathOramProjectedLeakage}
  (hCanonical₁ :
    family₁.leafValueDistribution =
      (pathOramLeafValueDistributionOfScaffold family₁.publicLeafScaffold).samples)
  (hCanonical₂ :
    family₂.leafValueDistribution =
      (pathOramLeafValueDistributionOfScaffold family₂.publicLeafScaffold).samples)
  (hPublic : family₁.publicLeafScaffold = family₂.publicLeafScaffold) :
  canonicalPathOramLeafValueRelation
    family₁.leafValueDistribution
    family₂.leafValueDistribution
    leakage := by
  refine ⟨family₁.publicLeafScaffold, family₁.leafValueDistribution_eq_canonical hCanonical₁, ?_⟩
  simpa [hPublic.symm] using family₂.leafValueDistribution_eq_canonical hCanonical₂

theorem seededRuntimePathOram_canonicalLeafValueRelation_of_publicScaffoldEq_of_seedSpace
  {modelTags : SGXModelTags}
  {family₁ family₂ : SeededRuntimePathOramWitnessFamily modelTags}
  {leakage : PathOramProjectedLeakage}
  (hSeedSpace₁ : family₁.RealizesCanonicalLeafValueSeedSpace)
  (hSeedSpace₂ : family₂.RealizesCanonicalLeafValueSeedSpace)
  (hPublic : family₁.publicLeafScaffold = family₂.publicLeafScaffold) :
  canonicalPathOramLeafValueRelation
    family₁.leafValueDistribution
    family₂.leafValueDistribution
    leakage := by
  exact seededRuntimePathOram_canonicalLeafValueRelation_of_publicScaffoldEq
    (family₁ := family₁)
    (family₂ := family₂)
    (leakage := leakage)
    (family₁.leafValueDistribution_eq_canonical_of_seedSpace hSeedSpace₁)
    (family₂.leafValueDistribution_eq_canonical_of_seedSpace hSeedSpace₂)
    hPublic

theorem seededRuntimePathOram_leafScheduleRelation_of_publicScaffoldEq
  {modelTags : SGXModelTags}
  {family₁ family₂ : SeededRuntimePathOramWitnessFamily modelTags}
  {leakage : PathOramProjectedLeakage}
  (hCanonical₁ :
    family₁.leafValueDistribution =
      (pathOramLeafValueDistributionOfScaffold family₁.publicLeafScaffold).samples)
  (hCanonical₂ :
    family₂.leafValueDistribution =
      (pathOramLeafValueDistributionOfScaffold family₂.publicLeafScaffold).samples)
  (hPublic : family₁.publicLeafScaffold = family₂.publicLeafScaffold) :
  pathOramLeafScheduleRelationFromLeafValueRelation canonicalPathOramLeafValueRelation
    family₁.leafScheduleDistribution
    family₂.leafScheduleDistribution
    leakage := by
  refine ⟨?_, ?_⟩
  · simpa [SeededRuntimePathOramWitnessFamily.map_leafScheduleDistribution_pathOramLeafValues]
      using seededRuntimePathOram_canonicalLeafValueRelation_of_publicScaffoldEq
        (family₁ := family₁) (family₂ := family₂) (leakage := leakage)
        hCanonical₁ hCanonical₂ hPublic
  · exact seededRuntimePathOram_leafScaffoldExactProjection_of_publicScaffoldEq hPublic

theorem seededRuntimePathOram_leafScheduleRelation_of_publicScaffoldEq_of_seedSpace
  {modelTags : SGXModelTags}
  {family₁ family₂ : SeededRuntimePathOramWitnessFamily modelTags}
  {leakage : PathOramProjectedLeakage}
  (hSeedSpace₁ : family₁.RealizesCanonicalLeafValueSeedSpace)
  (hSeedSpace₂ : family₂.RealizesCanonicalLeafValueSeedSpace)
  (hPublic : family₁.publicLeafScaffold = family₂.publicLeafScaffold) :
  pathOramLeafScheduleRelationFromLeafValueRelation canonicalPathOramLeafValueRelation
    family₁.leafScheduleDistribution
    family₂.leafScheduleDistribution
    leakage := by
  exact seededRuntimePathOram_leafScheduleRelation_of_publicScaffoldEq
    (family₁ := family₁)
    (family₂ := family₂)
    (leakage := leakage)
    (family₁.leafValueDistribution_eq_canonical_of_seedSpace hSeedSpace₁)
    (family₂.leafValueDistribution_eq_canonical_of_seedSpace hSeedSpace₂)
    hPublic

structure SeededRuntimePathOramProofBundle (modelTags : SGXModelTags) where
  family : OramConfig → SeededRuntimePathOramWitnessFamily modelTags
  cfgWellFormed : ∀ cfg, PathOramConfigWellFormed cfg
  publicView : OramConfig → OramViewPublicPart
  publicViewExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      pathOramViewPublicPart (viewMPlus (((family cfg).witnessAt seed).trace)) =
        publicView cfg
  publicViewSafe :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ →
      publicView cfg₁ = publicView cfg₂
  objectsMatchPublicConfig :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).ObjectsMatchPublicConfig cfg
  publicLocation : OramConfig → PathOramStorageLocationTrace
  publicLocationExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      pathOramPublicLocationTrace
        (pathOramStorageLocationTrace
          (oramStorageView (viewMPlus (((family cfg).witnessAt seed).trace)))) =
        publicLocation cfg
  publicLocationSafe :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ →
      publicLocation cfg₁ = publicLocation cfg₂
  storageShape : OramConfig → PathOramStorageShape
  storageShapeExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      pathOramStorageShape
        (oramStorageView (viewMPlus (((family cfg).witnessAt seed).trace))) =
        storageShape cfg
  storageShapeSafe :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ →
      storageShape cfg₁ = storageShape cfg₂
  canonicalSeedSpace :
    ∀ cfg, (family cfg).RealizesCanonicalLeafValueSeedSpace

def SeededRuntimePathOramProofBundle.run
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags) : OramSemantics :=
  fun cfg => (bundle.family cfg).viewDistribution

def SeededRuntimePathOramProofBundle.leafRun
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags) :
  OramConfig → Distribution PathOramLeafScheduleTrace :=
  fun cfg => (bundle.family cfg).leafScheduleDistribution

theorem SeededRuntimePathOramProofBundle.publicScaffold
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig) :
  pathOramLeafScheduleScaffoldOfPublicPart
      (bundle.publicView cfg)
      (pathOramProjectedExecutionLeakage cfg) =
    some ((bundle.family cfg).publicLeafScaffold) := by
  let family := bundle.family cfg
  have hSeedCountPos : 0 < family.seedCount :=
    family.seedCount_pos_of_seedSpace (bundle.canonicalSeedSpace cfg)
  have hValid : (family.witnessAt 0).Valid modelTags :=
    family.valid 0 hSeedCountPos
  have hMatch : (family.witnessAt 0).ObjectsMatchPublicConfig cfg :=
    bundle.objectsMatchPublicConfig cfg 0 hSeedCountPos
  have hCfg : PathOramConfigWellFormed cfg :=
    bundle.cfgWellFormed cfg
  have hPublicView :
      pathOramViewPublicPart (viewMPlus ((family.witnessAt 0).trace)) =
        bundle.publicView cfg :=
    bundle.publicViewExact cfg 0 hSeedCountPos
  calc
    pathOramLeafScheduleScaffoldOfPublicPart
        (bundle.publicView cfg)
        (pathOramProjectedExecutionLeakage cfg) =
      pathOramLeafScheduleScaffoldOfPublicPart
        (pathOramViewPublicPart (viewMPlus ((family.witnessAt 0).trace)))
        (pathOramProjectedExecutionLeakage cfg) := by
          rw [← hPublicView]
    _ =
      some ((family.witnessAt 0).projectedPublicPathOramLeafScaffold) := by
        exact runtimeWitness_publicPathOramLeafScaffold_of_matchPublicConfig
          (witness := family.witnessAt 0)
          modelTags
          (cfg := cfg)
          hValid
          hMatch
          hCfg
    _ = some family.publicLeafScaffold := by
        simp [SeededRuntimePathOramWitnessFamily.publicLeafScaffoldExact, hSeedCountPos]

theorem SeededRuntimePathOramProofBundle.publicViewConstantProjection
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig) :
  OramConstantProjection
    pathOramViewPublicPart
    (bundle.run cfg)
    (bundle.publicView cfg) := by
  exact (bundle.family cfg).viewConstantProjection_of_exact
    pathOramViewPublicPart
    (bundle.publicView cfg)
    (bundle.publicViewExact cfg)

theorem SeededRuntimePathOramProofBundle.pathOramPublicViewSafe
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags) :
  PathOramPublicViewSafe bundle.run := by
  intro cfg₁ cfg₂ hSame
  apply oramExactProjectionRelation_of_constant (bundle.publicViewSafe cfg₁ cfg₂ hSame)
  · exact bundle.publicViewConstantProjection cfg₁
  · exact bundle.publicViewConstantProjection cfg₂

theorem SeededRuntimePathOramProofBundle.leafSchedulePublicAlignment
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig)
  {publicPart : OramViewPublicPart}
  (hPublic :
    OramConstantProjection
      pathOramViewPublicPart
      (bundle.run cfg)
      publicPart) :
  PathOramLeafSchedulePublicAlignment
    (bundle.leafRun cfg)
    publicPart
    (pathOramProjectedExecutionLeakage cfg) := by
  let family := bundle.family cfg
  have hSeedCountPos : 0 < family.seedCount :=
    family.seedCount_pos_of_seedSpace (bundle.canonicalSeedSpace cfg)
  have hPublicEq : publicPart = bundle.publicView cfg :=
    family.eq_of_viewConstantProjection
      hSeedCountPos
      hPublic
      (bundle.publicViewConstantProjection cfg)
  have hScaffold :
      pathOramLeafScheduleScaffoldOfPublicPart
        publicPart
        (pathOramProjectedExecutionLeakage cfg) =
      some family.publicLeafScaffold := by
    simpa [hPublicEq] using bundle.publicScaffold cfg
  simpa using family.leafSchedulePublicAlignment_of_publicPart
    (publicPart := publicPart)
    (leakage := pathOramProjectedExecutionLeakage cfg)
    hScaffold

theorem SeededRuntimePathOramProofBundle.leafValueCanonicalOnPublicPart
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig)
  {publicPart : OramViewPublicPart}
  (hPublic :
    OramConstantProjection
      pathOramViewPublicPart
      (bundle.run cfg)
      publicPart) :
  PathOramLeafValueCanonicalOnPublicPart
    ((bundle.leafRun cfg).map pathOramLeafValues)
    publicPart
    (pathOramProjectedExecutionLeakage cfg) := by
  let family := bundle.family cfg
  have hSeedSpace := bundle.canonicalSeedSpace cfg
  have hSeedCountPos : 0 < family.seedCount :=
    family.seedCount_pos_of_seedSpace hSeedSpace
  have hPublicEq : publicPart = bundle.publicView cfg :=
    family.eq_of_viewConstantProjection
      hSeedCountPos
      hPublic
      (bundle.publicViewConstantProjection cfg)
  have hScaffold :
      pathOramLeafScheduleScaffoldOfPublicPart
        publicPart
        (pathOramProjectedExecutionLeakage cfg) =
      some family.publicLeafScaffold := by
    simpa [hPublicEq] using bundle.publicScaffold cfg
  simpa [SeededRuntimePathOramProofBundle.leafRun] using
    family.leafValueCanonicalOnPublicPart_of_publicPart_of_seedSpace
      (publicPart := publicPart)
      (leakage := pathOramProjectedExecutionLeakage cfg)
      hSeedSpace
      hScaffold

theorem SeededRuntimePathOramProofBundle.bucketProjection
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig) :
  (bundle.run cfg).map pathOramBucketTraceOfView =
    (bundle.leafRun cfg).map pathOramBucketTraceOfLeafScheduleTrace := by
  let family := bundle.family cfg
  unfold SeededRuntimePathOramProofBundle.run
    SeededRuntimePathOramProofBundle.leafRun
    SeededRuntimeWitnessFamily.viewDistribution
    SeededRuntimePathOramWitnessFamily.leafScheduleDistribution
  rw [List.map_map, List.map_map]
  apply List.map_congr_left
  intro seed hSeedMem
  have hSeedLt : seed < family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  have hBucket :=
    runtimeWitness_pathOramBucketProjection_exact
      (family.witnessAt seed)
      modelTags
      (family.valid seed hSeedLt)
  simpa [RuntimeRefinementWitness.pathOramBucketTrace] using hBucket.symm

theorem SeededRuntimePathOramProofBundle.publicLocationConstantProjection
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig) :
  OramConstantProjection
    pathOramPublicLocationTrace
    ((bundle.run cfg).map (fun view => pathOramStorageLocationTrace (oramStorageView view)))
    (bundle.publicLocation cfg) := by
  refine oramConstantProjection_map_of_const
    pathOramPublicLocationTrace
    (bundle.publicLocation cfg)
    (fun view => pathOramStorageLocationTrace (oramStorageView view))
    (bundle.run cfg)
    ?_
  intro view hMem
  exact (bundle.family cfg).viewConstantProjection_of_exact
    (fun runtimeView =>
      pathOramPublicLocationTrace
        (pathOramStorageLocationTrace (oramStorageView runtimeView)))
    (bundle.publicLocation cfg)
    (bundle.publicLocationExact cfg)
    view
    hMem

theorem SeededRuntimePathOramProofBundle.publicLocationRelation
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  {cfg₁ cfg₂ : OramConfig}
  (hSame : sameOramPublicProjection cfg₁ cfg₂) :
  OramExactProjectionRelation
    pathOramPublicLocationTrace
    ((bundle.run cfg₁).map (fun view => pathOramStorageLocationTrace (oramStorageView view)))
    ((bundle.run cfg₂).map (fun view => pathOramStorageLocationTrace (oramStorageView view))) := by
  apply oramExactProjectionRelation_of_constant
    (bundle.publicLocationSafe cfg₁ cfg₂ hSame)
  · exact bundle.publicLocationConstantProjection cfg₁
  · exact bundle.publicLocationConstantProjection cfg₂

theorem SeededRuntimePathOramProofBundle.storageShapeConstantProjection
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (cfg : OramConfig) :
  OramConstantProjection
    (fun view => pathOramStorageShape (oramStorageView view))
    (bundle.run cfg)
    (bundle.storageShape cfg) := by
  exact (bundle.family cfg).viewConstantProjection_of_exact
    (fun runtimeView => pathOramStorageShape (oramStorageView runtimeView))
    (bundle.storageShape cfg)
    (bundle.storageShapeExact cfg)

theorem SeededRuntimePathOramProofBundle.storageShapeRelation
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  {cfg₁ cfg₂ : OramConfig}
  (hSame : sameOramPublicProjection cfg₁ cfg₂) :
  OramExactProjectionRelation
    (fun view => pathOramStorageShape (oramStorageView view))
    (bundle.run cfg₁)
    (bundle.run cfg₂) := by
  apply oramExactProjectionRelation_of_constant
    (bundle.storageShapeSafe cfg₁ cfg₂ hSame)
  · exact bundle.storageShapeConstantProjection cfg₁
  · exact bundle.storageShapeConstantProjection cfg₂

theorem SeededRuntimePathOramProofBundle.computationalUOWith
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramCanonicalLeafValueSecurityAssumptions) :
  ComputationalUOWith
    (proofGradePathOramSecurityInterface
      assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions)
    bundle.run := by
  apply
    computationalPathOram_fromPublicViewCanonicalLeafValuesBucketLocationAndShape_projects_to_computationalUOWith
      assumptions
  · exact bundle.cfgWellFormed
  · exact bundle.pathOramPublicViewSafe
  · intro cfg publicPart hPublic
    exact bundle.leafValueCanonicalOnPublicPart cfg hPublic
  · intro cfg publicPart hPublic
    exact bundle.leafSchedulePublicAlignment cfg hPublic
  · exact bundle.bucketProjection
  · intro cfg₁ cfg₂ hSame
    exact bundle.publicLocationRelation hSame
  · intro cfg₁ cfg₂ hSame
    exact bundle.storageShapeRelation hSame

structure SeededRuntimePaperMainBundle (modelTags : SGXModelTags)
    extends SeededRuntimePathOramProofBundle modelTags where
  publicOutcome : OramConfig → SGXPublicOutcome
  publicOutcomeExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).publicOutcome = publicOutcome cfg
  publicOutcomeSafe :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ →
      publicOutcome cfg₁ = publicOutcome cfg₂
  boundarySchedule : OramConfig → List BoundaryEvent
  boundaryExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).boundarySchedule = boundarySchedule cfg
  boundarySafe :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ →
      boundarySchedule cfg₁ = boundarySchedule cfg₂

theorem SeededRuntimePaperMainBundle.paperMainSgxExecution
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramCanonicalLeafValueSecurityAssumptions) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (oramNormalizedObservedSGXProofRelationWith
      (proofGradePathOramSecurityInterface
        assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions))
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags) := by
  apply paperMain_computationalUOWith_projects_to_sgxExecution
  · exact bundle.toSeededRuntimePathOramProofBundle.computationalUOWith assumptions
  · exact bundle.publicOutcomeSafe
  · exact bundle.boundarySafe

end UOToolchain
