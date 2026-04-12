import UOToolchain.RuntimeRefinement

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

def SeededRuntimeWitnessFamily.witnessDistribution
  {modelTags : SGXModelTags}
  (family : SeededRuntimeWitnessFamily modelTags) : Distribution RuntimeRefinementWitness :=
  (runtimeSeedIndexDistribution family.seedCount).samples.map family.witnessAt

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

end UOToolchain
