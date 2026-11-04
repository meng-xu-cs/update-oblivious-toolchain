import UOToolchain.PaperMainReleases
import UOToolchain.RuntimePaperInstantiation
import UOToolchain.PathOramFreshLeaves

/-!
# Path ORAM over admitted configurations

`ComputationalUOWith` and `SeededRuntimePathOramProofBundle` quantify over every
`OramConfig`, which constrains nothing, so the bundle cannot exist
(`seededRuntimePathOramProofBundle_empty`) and the theorems that take it hold
vacuously. This module states the Path ORAM route over the configurations an
admission predicate selects, shows that such a bundle exists, and discharges
its leaf obligation from the leaf model without enumerating seeds.

- `ComputationalUOWithOn admitted`: the local theorem for every pair of
  admitted configurations with the same public projection
  (`AdmittedSamePublic`). With every configuration admitted it is
  `ComputationalUOWith` (`computationalUOWithOn_true_iff`).
- `pathOramViewRelation_of_pair`: the Path ORAM reduction for one pair of runs.
- `SeededRuntimePathOramProofBundleOn` and `SeededRuntimePaperMainBundleOn`:
  the seeded bundles with every field guarded by admission. They give
  `ComputationalUOWithOn`, the SGX execution theorem over admitted pairs, and
  the `path_oram_local_posmap_v1` paper-main theorem modulo releases
  (`paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on`). A
  bundle over all configurations is one over `fun _ => True`
  (`SeededRuntimePaperMainBundle.toOn`).
- `ConcreteRuntimePathOramPairSlice.toPaperMainBundleOn`: a runtime pair slice,
  which the paper instantiation checker builds from a runtime certificate, is a
  bundle that admits the pair's two sides. They agree on the public projection
  and differ in their secret inputs, so the bundle exists and the theorem it
  gives compares two different runs (`sgxViewRelation_sides`).
- `TapeRuntimePathOramWitnessFamily`: a runtime family that runs every coin
  tape of a call (the leaves of the keys present before the call and the
  call's coins). Its leaf values are the canonical distribution, each schedule
  equally often (`leafValues_perm_canonical`, from
  `multiObservedLeaves_canonical`), and one tape per schedule gives a seeded
  family that realizes the canonical seed space
  (`toSeeded_realizesCanonicalLeafValueSeedSpace`). So the bundle's leaf
  obligation needs no seed enumeration: `TapePathOramPaperMainEvidenceOn.toBundle`
  builds the bundle from facts that hold on every tape.
-/

set_option autoImplicit false

namespace UOToolchain

/-! ## Admitted pairs -/

/-- Two admitted configurations with the same public projection. -/
def AdmittedSamePublic (admitted : OramConfig → Prop) (cfg₁ cfg₂ : OramConfig) : Prop :=
  admitted cfg₁ ∧ admitted cfg₂ ∧ sameOramPublicProjection cfg₁ cfg₂

theorem AdmittedSamePublic.symm {admitted : OramConfig → Prop} {cfg₁ cfg₂ : OramConfig}
    (h : AdmittedSamePublic admitted cfg₁ cfg₂) : AdmittedSamePublic admitted cfg₂ cfg₁ :=
  ⟨h.2.1, h.1, sameOramPublicProjection_symm h.2.2⟩

/-- `ComputationalUOWith` over the pairs of admitted configurations. -/
def ComputationalUOWithOn (admitted : OramConfig → Prop) (security : OramSecurityInterface)
    (run : OramSemantics) : Prop :=
  ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
    security.localTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)

theorem ComputationalUOWith.on {security : OramSecurityInterface} {run : OramSemantics}
    (h : ComputationalUOWith security run) (admitted : OramConfig → Prop) :
    ComputationalUOWithOn admitted security run :=
  fun cfg₁ cfg₂ hPair => h cfg₁ cfg₂ hPair.2.2

theorem computationalUOWithOn_true_iff {security : OramSecurityInterface} {run : OramSemantics} :
    ComputationalUOWithOn (fun _ => True) security run ↔ ComputationalUOWith security run :=
  ⟨fun h cfg₁ cfg₂ hSame => h cfg₁ cfg₂ ⟨trivial, trivial, hSame⟩, fun h => h.on _⟩

/-! ## The Path ORAM reduction for one pair of runs -/

/-- **The Path ORAM local theorem for one pair of runs.** For two
configurations with the same public projection, if both runs show one public
view, their leaf values are the canonical distribution of the scaffold that
view fixes, their bucket traces are those of their leaf schedules, and their
public locations and storage shapes agree, the runs satisfy the Path ORAM view
relation. -/
theorem pathOramViewRelation_of_pair
    (assumptions : PathOramCanonicalLeafValueSecurityAssumptions)
    {cfg₁ cfg₂ : OramConfig}
    (hSame : sameOramPublicProjection cfg₁ cfg₂)
    (hCfg : PathOramConfigWellFormed cfg₁)
    {views₁ views₂ : Distribution ViewMPlus}
    {leafs₁ leafs₂ : Distribution PathOramLeafScheduleTrace}
    {publicPart : OramViewPublicPart}
    (hPublic₁ : OramConstantProjection pathOramViewPublicPart views₁ publicPart)
    (hPublic₂ : OramConstantProjection pathOramViewPublicPart views₂ publicPart)
    (hCanonical₁ :
      PathOramLeafValueCanonicalOnPublicPart (leafs₁.map pathOramLeafValues) publicPart
        (pathOramProjectedExecutionLeakage cfg₁))
    (hCanonical₂ :
      PathOramLeafValueCanonicalOnPublicPart (leafs₂.map pathOramLeafValues) publicPart
        (pathOramProjectedExecutionLeakage cfg₂))
    (hAlign₁ :
      PathOramLeafSchedulePublicAlignment leafs₁ publicPart
        (pathOramProjectedExecutionLeakage cfg₁))
    (hAlign₂ :
      PathOramLeafSchedulePublicAlignment leafs₂ publicPart
        (pathOramProjectedExecutionLeakage cfg₂))
    (hBucket₁ :
      views₁.map pathOramBucketTraceOfView =
        leafs₁.map pathOramBucketTraceOfLeafScheduleTrace)
    (hBucket₂ :
      views₂.map pathOramBucketTraceOfView =
        leafs₂.map pathOramBucketTraceOfLeafScheduleTrace)
    (hPublicLocation :
      OramExactProjectionRelation pathOramPublicLocationTrace
        (views₁.map fun view => pathOramStorageLocationTrace (oramStorageView view))
        (views₂.map fun view => pathOramStorageLocationTrace (oramStorageView view)))
    (hShape :
      OramExactProjectionRelation (fun view => pathOramStorageShape (oramStorageView view))
        views₁ views₂) :
    pathOramViewRelation
      assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions
      views₁ views₂ (executionLeakage cfg₁) := by
  have hLeakageEq :
      pathOramProjectedExecutionLeakage cfg₁ = pathOramProjectedExecutionLeakage cfg₂ :=
    pathOramProjectedLeakage_eq_of_samePublicProjection hSame
  rw [← hLeakageEq] at hCanonical₂ hAlign₂
  have hScaffold : OramExactProjectionRelation pathOramLeafScheduleScaffold leafs₁ leafs₂ :=
    pathOramLeafSchedulePublicAlignment_exact hAlign₁ hAlign₂
  have hValues :
      canonicalPathOramLeafValueRelation (leafs₁.map pathOramLeafValues)
        (leafs₂.map pathOramLeafValues) (pathOramProjectedExecutionLeakage cfg₁) := by
    rcases hCanonical₁ with ⟨scaffold₁, hScaffold₁, hLeafs₁⟩
    rcases hCanonical₂ with ⟨scaffold₂, hScaffold₂, hLeafs₂⟩
    have hEq : scaffold₁ = scaffold₂ := Option.some.inj (hScaffold₁.symm.trans hScaffold₂)
    subst hEq
    exact ⟨scaffold₁, hLeafs₁, hLeafs₂⟩
  have hLeaf :
      pathOramLeafScheduleRelationFromLeafValueRelation canonicalPathOramLeafValueRelation
        leafs₁ leafs₂ (pathOramProjectedExecutionLeakage cfg₁) :=
    ⟨hValues, hScaffold⟩
  have hLocation₁ :
      (views₁.map oramStorageView).map pathOramStorageLocationTrace =
        views₁.map fun view => pathOramStorageLocationTrace (oramStorageView view) := by
    simp [List.map_map, Function.comp_def]
  have hLocation₂ :
      (views₂.map oramStorageView).map pathOramStorageLocationTrace =
        views₂.map fun view => pathOramStorageLocationTrace (oramStorageView view) := by
    simp [List.map_map, Function.comp_def]
  refine ⟨pathOramConfigWellFormed_executionLeakage hCfg, ⟨publicPart, hPublic₁, hPublic₂⟩, ?_⟩
  apply pathOramProjectedStorageTheorem_projects_to_standard
  apply pathOramProjectedStorageTheorem_of_leafScheduleBucketLocationPublicTrace_and_shape
    assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions
    (leafs₁ := leafs₁) (leafs₂ := leafs₂)
  · exact hLeaf
  · exact hScaffold
  · rw [hLocation₁, List.map_map]
    exact hBucket₁
  · rw [hLocation₂, List.map_map]
    exact hBucket₂
  · rw [hLocation₁, hLocation₂]
    exact hPublicLocation
  · exact oramExactProjectionRelation_map pathOramStorageShape oramStorageView hShape

/-! ## Facts of one seeded family -/

namespace SeededRuntimePathOramWitnessFamily

variable {modelTags : SGXModelTags} (family : SeededRuntimePathOramWitnessFamily modelTags)

/-- The scaffold a family's public view fixes is the family's public leaf
scaffold. -/
theorem publicScaffold_of_publicView {cfg : OramConfig} {publicView : OramViewPublicPart}
    (hCfg : PathOramConfigWellFormed cfg)
    (hSeedSpace : family.RealizesCanonicalLeafValueSeedSpace)
    (hPublicViewExact :
      ∀ seed, seed < family.seedCount →
        pathOramViewPublicPart (viewMPlus ((family.witnessAt seed).trace)) = publicView)
    (hMatch :
      ∀ seed, seed < family.seedCount → (family.witnessAt seed).ObjectsMatchPublicConfig cfg) :
    pathOramLeafScheduleScaffoldOfPublicPart publicView (pathOramProjectedExecutionLeakage cfg) =
      some family.publicLeafScaffold := by
  have hSeedCountPos : 0 < family.seedCount := family.seedCount_pos_of_seedSpace hSeedSpace
  rw [← hPublicViewExact 0 hSeedCountPos,
    runtimeWitness_publicPathOramLeafScaffold_of_matchPublicConfig (family.witnessAt 0) modelTags
      (family.valid 0 hSeedCountPos) (hMatch 0 hSeedCountPos) hCfg,
    family.publicLeafScaffoldExact 0 hSeedCountPos]

/-- A family's runs show the bucket traces of their leaf schedules. -/
theorem bucketProjection :
    family.viewDistribution.map pathOramBucketTraceOfView =
      family.leafScheduleDistribution.map pathOramBucketTraceOfLeafScheduleTrace := by
  unfold SeededRuntimeWitnessFamily.viewDistribution
    SeededRuntimePathOramWitnessFamily.leafScheduleDistribution
  rw [List.map_map, List.map_map]
  apply List.map_congr_left
  intro seed hSeedMem
  have hSeedLt : seed < family.seedCount := by
    simpa [runtimeSeedIndexDistribution] using List.mem_range.mp hSeedMem
  have hBucket :=
    runtimeWitness_pathOramBucketProjection_exact (family.witnessAt seed) modelTags
      (family.valid seed hSeedLt)
  simpa [pathOramBucketTraceOfView, RuntimeRefinementWitness.pathOramBucketTrace] using
    hBucket.symm

theorem publicLocationConstantProjection {publicLocation : PathOramStorageLocationTrace}
    (hExact :
      ∀ seed, seed < family.seedCount →
        pathOramPublicLocationTrace
            (pathOramStorageLocationTrace
              (oramStorageView (viewMPlus ((family.witnessAt seed).trace)))) =
          publicLocation) :
    OramConstantProjection pathOramPublicLocationTrace
      (family.viewDistribution.map fun view =>
        pathOramStorageLocationTrace (oramStorageView view))
      publicLocation := by
  refine oramConstantProjection_map_of_const pathOramPublicLocationTrace publicLocation
    (fun view => pathOramStorageLocationTrace (oramStorageView view))
    family.viewDistribution ?_
  intro view hMem
  exact family.viewConstantProjection_of_exact
    (fun runtimeView =>
      pathOramPublicLocationTrace (pathOramStorageLocationTrace (oramStorageView runtimeView)))
    publicLocation hExact view hMem

end SeededRuntimePathOramWitnessFamily

/-! ## The seeded bundles over admitted configurations -/

/-- `SeededRuntimePathOramProofBundle` over the configurations `admitted`
selects: every field speaks of admitted configurations only. -/
structure SeededRuntimePathOramProofBundleOn (modelTags : SGXModelTags)
    (admitted : OramConfig → Prop) where
  family : OramConfig → SeededRuntimePathOramWitnessFamily modelTags
  cfgWellFormed : ∀ cfg, admitted cfg → PathOramConfigWellFormed cfg
  publicView : OramConfig → OramViewPublicPart
  publicViewExact :
    ∀ cfg, admitted cfg → ∀ seed, seed < (family cfg).seedCount →
      pathOramViewPublicPart (viewMPlus (((family cfg).witnessAt seed).trace)) =
        publicView cfg
  publicViewSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → publicView cfg₁ = publicView cfg₂
  objectsMatchPublicConfig :
    ∀ cfg, admitted cfg → ∀ seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).ObjectsMatchPublicConfig cfg
  publicLocation : OramConfig → PathOramStorageLocationTrace
  publicLocationExact :
    ∀ cfg, admitted cfg → ∀ seed, seed < (family cfg).seedCount →
      pathOramPublicLocationTrace
          (pathOramStorageLocationTrace
            (oramStorageView (viewMPlus (((family cfg).witnessAt seed).trace)))) =
        publicLocation cfg
  publicLocationSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
      publicLocation cfg₁ = publicLocation cfg₂
  storageShape : OramConfig → PathOramStorageShape
  storageShapeExact :
    ∀ cfg, admitted cfg → ∀ seed, seed < (family cfg).seedCount →
      pathOramStorageShape (oramStorageView (viewMPlus (((family cfg).witnessAt seed).trace))) =
        storageShape cfg
  storageShapeSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → storageShape cfg₁ = storageShape cfg₂
  canonicalSeedSpace :
    ∀ cfg, admitted cfg → (family cfg).RealizesCanonicalLeafValueSeedSpace

namespace SeededRuntimePathOramProofBundleOn

variable {modelTags : SGXModelTags} {admitted : OramConfig → Prop}
  (bundle : SeededRuntimePathOramProofBundleOn modelTags admitted)

def run : OramSemantics := fun cfg => (bundle.family cfg).viewDistribution

def leafRun : OramConfig → Distribution PathOramLeafScheduleTrace :=
  fun cfg => (bundle.family cfg).leafScheduleDistribution

theorem publicViewConstantProjection {cfg : OramConfig} (h : admitted cfg) :
    OramConstantProjection pathOramViewPublicPart (bundle.run cfg) (bundle.publicView cfg) :=
  (bundle.family cfg).viewConstantProjection_of_exact pathOramViewPublicPart
    (bundle.publicView cfg) (bundle.publicViewExact cfg h)

theorem publicScaffold {cfg : OramConfig} (h : admitted cfg) :
    pathOramLeafScheduleScaffoldOfPublicPart (bundle.publicView cfg)
        (pathOramProjectedExecutionLeakage cfg) =
      some (bundle.family cfg).publicLeafScaffold :=
  (bundle.family cfg).publicScaffold_of_publicView (bundle.cfgWellFormed cfg h)
    (bundle.canonicalSeedSpace cfg h) (bundle.publicViewExact cfg h)
    (bundle.objectsMatchPublicConfig cfg h)

theorem leafValueCanonicalOnPublicView {cfg : OramConfig} (h : admitted cfg) :
    PathOramLeafValueCanonicalOnPublicPart ((bundle.leafRun cfg).map pathOramLeafValues)
      (bundle.publicView cfg) (pathOramProjectedExecutionLeakage cfg) := by
  simpa [leafRun,
    SeededRuntimePathOramWitnessFamily.map_leafScheduleDistribution_pathOramLeafValues] using
    (bundle.family cfg).leafValueCanonicalOnPublicPart_of_publicPart_of_seedSpace
      (bundle.canonicalSeedSpace cfg h) (bundle.publicScaffold h)

theorem leafSchedulePublicAlignment {cfg : OramConfig} (h : admitted cfg) :
    PathOramLeafSchedulePublicAlignment (bundle.leafRun cfg) (bundle.publicView cfg)
      (pathOramProjectedExecutionLeakage cfg) :=
  (bundle.family cfg).leafSchedulePublicAlignment_of_publicPart (bundle.publicScaffold h)

theorem storageShapeConstantProjection {cfg : OramConfig} (h : admitted cfg) :
    OramConstantProjection (fun view => pathOramStorageShape (oramStorageView view))
      (bundle.run cfg) (bundle.storageShape cfg) :=
  (bundle.family cfg).viewConstantProjection_of_exact
    (fun runtimeView => pathOramStorageShape (oramStorageView runtimeView))
    (bundle.storageShape cfg) (bundle.storageShapeExact cfg h)

/-- **Path ORAM over admitted configurations.** A bundle gives the Path ORAM
local theorem for every pair of admitted configurations with the same public
projection. -/
theorem computationalUOWithOn (assumptions : PathOramCanonicalLeafValueSecurityAssumptions) :
    ComputationalUOWithOn admitted
      (proofGradePathOramSecurityInterface
        assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions)
      bundle.run := by
  intro cfg₁ cfg₂ hPair
  obtain ⟨h₁, h₂, hSame⟩ := hPair
  have hView : bundle.publicView cfg₁ = bundle.publicView cfg₂ :=
    bundle.publicViewSafe cfg₁ cfg₂ ⟨h₁, h₂, hSame⟩
  have hPublic₂ := bundle.publicViewConstantProjection h₂
  have hCanonical₂ := bundle.leafValueCanonicalOnPublicView h₂
  have hAlign₂ := bundle.leafSchedulePublicAlignment h₂
  rw [← hView] at hPublic₂ hCanonical₂ hAlign₂
  exact pathOramViewRelation_of_pair assumptions hSame (bundle.cfgWellFormed cfg₁ h₁)
    (bundle.publicViewConstantProjection h₁) hPublic₂
    (bundle.leafValueCanonicalOnPublicView h₁) hCanonical₂
    (bundle.leafSchedulePublicAlignment h₁) hAlign₂
    ((bundle.family cfg₁).bucketProjection) ((bundle.family cfg₂).bucketProjection)
    (oramExactProjectionRelation_of_constant (bundle.publicLocationSafe cfg₁ cfg₂ ⟨h₁, h₂, hSame⟩)
      ((bundle.family cfg₁).publicLocationConstantProjection (bundle.publicLocationExact cfg₁ h₁))
      ((bundle.family cfg₂).publicLocationConstantProjection (bundle.publicLocationExact cfg₂ h₂)))
    (oramExactProjectionRelation_of_constant (bundle.storageShapeSafe cfg₁ cfg₂ ⟨h₁, h₂, hSame⟩)
      (bundle.storageShapeConstantProjection h₁) (bundle.storageShapeConstantProjection h₂))

end SeededRuntimePathOramProofBundleOn

/-- `SeededRuntimePaperMainBundle` over the configurations `admitted`
selects. -/
structure SeededRuntimePaperMainBundleOn (modelTags : SGXModelTags)
    (admitted : OramConfig → Prop)
    extends SeededRuntimePathOramProofBundleOn modelTags admitted where
  publicOutcome : OramConfig → SGXPublicOutcome
  publicOutcomeExact :
    ∀ cfg, admitted cfg → ∀ seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).publicOutcome = publicOutcome cfg
  publicOutcomeSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂
  boundarySchedule : OramConfig → List BoundaryEvent
  boundaryExact :
    ∀ cfg, admitted cfg → ∀ seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).boundarySchedule = boundarySchedule cfg
  boundarySafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
      boundarySchedule cfg₁ = boundarySchedule cfg₂

/-- A bundle over every configuration is a bundle over `fun _ => True`. -/
def SeededRuntimePathOramProofBundle.toOn {modelTags : SGXModelTags}
    (bundle : SeededRuntimePathOramProofBundle modelTags) :
    SeededRuntimePathOramProofBundleOn modelTags (fun _ => True) :=
  { family := bundle.family
    cfgWellFormed := fun cfg _ => bundle.cfgWellFormed cfg
    publicView := bundle.publicView
    publicViewExact := fun cfg _ => bundle.publicViewExact cfg
    publicViewSafe := fun cfg₁ cfg₂ hPair => bundle.publicViewSafe cfg₁ cfg₂ hPair.2.2
    objectsMatchPublicConfig := fun cfg _ => bundle.objectsMatchPublicConfig cfg
    publicLocation := bundle.publicLocation
    publicLocationExact := fun cfg _ => bundle.publicLocationExact cfg
    publicLocationSafe := fun cfg₁ cfg₂ hPair => bundle.publicLocationSafe cfg₁ cfg₂ hPair.2.2
    storageShape := bundle.storageShape
    storageShapeExact := fun cfg _ => bundle.storageShapeExact cfg
    storageShapeSafe := fun cfg₁ cfg₂ hPair => bundle.storageShapeSafe cfg₁ cfg₂ hPair.2.2
    canonicalSeedSpace := fun cfg _ => bundle.canonicalSeedSpace cfg }

def SeededRuntimePaperMainBundle.toOn {modelTags : SGXModelTags}
    (bundle : SeededRuntimePaperMainBundle modelTags) :
    SeededRuntimePaperMainBundleOn modelTags (fun _ => True) :=
  { bundle.toSeededRuntimePathOramProofBundle.toOn with
    publicOutcome := bundle.publicOutcome
    publicOutcomeExact := fun cfg _ => bundle.publicOutcomeExact cfg
    publicOutcomeSafe := fun cfg₁ cfg₂ hPair => bundle.publicOutcomeSafe cfg₁ cfg₂ hPair.2.2
    boundarySchedule := bundle.boundarySchedule
    boundaryExact := fun cfg _ => bundle.boundaryExact cfg
    boundarySafe := fun cfg₁ cfg₂ hPair => bundle.boundarySafe cfg₁ cfg₂ hPair.2.2 }

/-! ## SGX execution and the paper-main theorem over admitted pairs -/

/-- `computationalUOWith_projects_to_sgxExecution_with_normalizedController`
over admitted pairs. -/
theorem computationalUOWithOn_projects_to_sgxExecution
    (security : OramSecurityInterface)
    {admitted : OramConfig → Prop}
    {run : OramSemantics}
    {publicOutcome : OramConfig → SGXPublicOutcome}
    {boundarySchedule : OramConfig → List BoundaryEvent}
    {modelTags : SGXModelTags}
    (hOram : ComputationalUOWithOn admitted security run)
    (hOutcome :
      ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂)
    (hBoundary :
      ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
        boundarySchedule cfg₁ = boundarySchedule cfg₂) :
    SGXExecutionSecurity
      (AdmittedSamePublic admitted)
      (oramNormalizedObservedSGXProofRelationWith security)
      (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage publicOutcome modelTags) := by
  intro cfg₁ cfg₂ hPair
  have hPublic : sameOramPublicProjection cfg₁ cfg₂ := hPair.2.2
  constructor
  · apply exactProjectionRelation_of_constant (hOutcome cfg₁ cfg₂ hPair)
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₁) _ (run cfg₁) ?_
      intro view _hMem
      simp
    · refine constantProjection_map_of_const sgxPublicOutcome (publicOutcome cfg₂) _ (run cfg₂) ?_
      intro view _hMem
      simp
  constructor
  · apply exactProjectionRelation_of_constant (hBoundary cfg₁ cfg₂ hPair)
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule)
        (boundarySchedule cfg₁) _ (run cfg₁) ?_
      intro view _hMem
      simp
    · refine constantProjection_map_of_const (fun view : SGXView => view.boundarySchedule)
        (boundarySchedule cfg₂) _ (run cfg₂) ?_
      intro view _hMem
      simp
  constructor
  · simpa [oramToSGXSemantics, sgxStorageDistribution] using
      (oramSecurity_projects_to_sgxStorage security cfg₁ cfg₂ (run cfg₁) (run cfg₂) hPublic
        (hOram cfg₁ cfg₂ hPair))
  · have hLeakage :
        oramMicroLeakage publicOutcome modelTags cfg₂ =
          oramMicroLeakage publicOutcome modelTags cfg₁ := by
      apply sgxMicroLeakageOfController_eq_of_eq
      · exact hOutcome cfg₂ cfg₁ hPair.symm
      · rfl
      · exact oramControllerShape_eq_of_samePublicProjection (sameOramPublicProjection_symm hPublic)
    exact
      ⟨ oramControllerMicroDistribution_normalized (run := run) (cfg := cfg₁)
      , normalizedByLeakage_of_eq hLeakage
          (oramControllerMicroDistribution_normalized (run := run) (cfg := cfg₂))
      ⟩

/-- `computationalUOWith_projects_to_sgxView_moduloReleases` over admitted
pairs. -/
theorem computationalUOWithOn_projects_to_sgxView_moduloReleases
    (security : OramSecurityInterface)
    {admitted : OramConfig → Prop}
    {run : OramSemantics}
    {publicOutcome : OramConfig → SGXPublicOutcome}
    {boundarySchedule : OramConfig → List BoundaryEvent}
    {modelTags : SGXModelTags}
    (hOram : ComputationalUOWithOn admitted security run)
    (hOutcome : PublicOutcomeSafeModuloReleases (AdmittedSamePublic admitted) publicOutcome)
    (hBoundary :
      BoundarySafeModuloReleases (AdmittedSamePublic admitted) publicOutcome boundarySchedule)
    {cfg₁ cfg₂ : OramConfig}
    (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    SGXViewRelationModuloReleases
      (oramNormalizedObservedSGXProofRelationWith security)
      ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₁)
      ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₂)
      (executionLeakage cfg₁)
      (oramReleaseMicroLeakage publicOutcome modelTags cfg₁) := by
  have hPublic : sameOramPublicProjection cfg₁ cfg₂ := hPair.2.2
  refine ⟨?_, ?_, ?_, ?_⟩
  · apply exactProjectionRelation_of_constant (hOutcome cfg₁ cfg₂ hPair)
    · refine
        constantProjection_map_of_const
          (fun view : SGXView => (sgxPublicOutcome view).withoutReleases)
          ((publicOutcome cfg₁).withoutReleases) _ (run cfg₁) ?_
      intro view _hMem
      simp
    · refine
        constantProjection_map_of_const
          (fun view : SGXView => (sgxPublicOutcome view).withoutReleases)
          ((publicOutcome cfg₂).withoutReleases) _ (run cfg₂) ?_
      intro view _hMem
      simp
  · apply exactProjectionRelation_of_constant (hBoundary cfg₁ cfg₂ hPair)
    · refine
        constantProjection_map_of_const
          (fun view : SGXView =>
            boundaryWithoutStatusRelease (sgxPublicOutcome view).statusReleased
              view.boundarySchedule)
          (boundaryWithoutStatusRelease (publicOutcome cfg₁).statusReleased
            (boundarySchedule cfg₁)) _ (run cfg₁) ?_
      intro view _hMem
      simp
    · refine
        constantProjection_map_of_const
          (fun view : SGXView =>
            boundaryWithoutStatusRelease (sgxPublicOutcome view).statusReleased
              view.boundarySchedule)
          (boundaryWithoutStatusRelease (publicOutcome cfg₂).statusReleased
            (boundarySchedule cfg₂)) _ (run cfg₂) ?_
      intro view _hMem
      simp
  · simpa [oramToSGXSemantics, sgxStorageDistribution] using
      (oramSecurity_projects_to_sgxStorage security cfg₁ cfg₂ (run cfg₁) (run cfg₂) hPublic
        (hOram cfg₁ cfg₂ hPair))
  · have hLeakage :
        oramReleaseMicroLeakage publicOutcome modelTags cfg₂ =
          oramReleaseMicroLeakage publicOutcome modelTags cfg₁ := by
      apply sgxMicroLeakageOfController_eq_of_eq
      · exact hOutcome cfg₂ cfg₁ hPair.symm
      · rfl
      · exact oramControllerShape_eq_of_samePublicProjection (sameOramPublicProjection_symm hPublic)
    exact
      ⟨ oramControllerMicroDistribution_normalized_byLeakageOf (run := run) cfg₁
      , normalizedByLeakage_of_eq hLeakage
          (oramControllerMicroDistribution_normalized_byLeakageOf (run := run) cfg₂)
      ⟩

/-- **`path_oram_local_posmap_v1` paper-main theorem modulo declared releases,
over admitted configurations.** -/
theorem paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
    {admitted : OramConfig → Prop}
    {run : OramSemantics}
    {publicOutcome : OramConfig → SGXPublicOutcome}
    {boundarySchedule : OramConfig → List BoundaryEvent}
    {modelTags : SGXModelTags}
    {finalPublicStateRollback : OramConfig → PaperMainFinalPublicStateRollback}
    {releaseFunctions : OramConfig → PaperMainDeclaredReleaseFunctions}
    (hOram :
      ComputationalUOWithOn admitted (pathOramLocalPosmapV1SecurityInterface assumptions) run)
    (hOutcome : PublicOutcomeSafeModuloReleases (AdmittedSamePublic admitted) publicOutcome)
    (hBoundary :
      BoundarySafeModuloReleases (AdmittedSamePublic admitted) publicOutcome boundarySchedule)
    (hFinal :
      FinalPublicStateSafeModuloReleases (AdmittedSamePublic admitted) publicOutcome
        finalPublicStateRollback)
    (hRelease : PaperMainPublicFieldSafe (AdmittedSamePublic admitted) releaseFunctions)
    {cfg₁ cfg₂ : OramConfig}
    (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage publicOutcome modelTags)
      publicOutcome
      finalPublicStateRollback
      releaseFunctions
      cfg₁
      cfg₂ := by
  have hSGX :=
    computationalUOWithOn_projects_to_sgxView_moduloReleases
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (modelTags := modelTags)
      hOram hOutcome hBoundary hPair
  exact
    { publicOutcomeModuloReleases := hSGX.1
      boundarySchedule := hSGX.2.1
      storageTrace := hSGX.2.2.1
      microTrace := hSGX.2.2.2
      finalPublicStateModuloReleases := hFinal cfg₁ cfg₂ hPair
      releaseFunctions := hRelease cfg₁ cfg₂ hPair }

namespace SeededRuntimePaperMainBundleOn

variable {modelTags : SGXModelTags} {admitted : OramConfig → Prop}
  (bundle : SeededRuntimePaperMainBundleOn modelTags admitted)

/-- The SGX execution theorem over admitted pairs, from a bundle. -/
theorem paperMainSgxExecution (assumptions : PathOramCanonicalLeafValueSecurityAssumptions) :
    SGXExecutionSecurity
      (AdmittedSamePublic admitted)
      (oramNormalizedObservedSGXProofRelationWith
        (proofGradePathOramSecurityInterface
          assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions))
      (oramToSGXSemantics bundle.run bundle.publicOutcome bundle.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage bundle.publicOutcome modelTags) :=
  computationalUOWithOn_projects_to_sgxExecution _
    (bundle.toSeededRuntimePathOramProofBundleOn.computationalUOWithOn assumptions)
    bundle.publicOutcomeSafe bundle.boundarySafe

/-- **The `path_oram_local_posmap_v1` paper-main theorem modulo releases for
every admitted pair**, from a bundle. -/
theorem paperMain_noninterference_moduloReleases
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
    {finalPublicStateRollback : OramConfig → PaperMainFinalPublicStateRollback}
    {releaseFunctions : OramConfig → PaperMainDeclaredReleaseFunctions}
    (hFinal :
      FinalPublicStateSafeModuloReleases (AdmittedSamePublic admitted) bundle.publicOutcome
        finalPublicStateRollback)
    (hRelease : PaperMainPublicFieldSafe (AdmittedSamePublic admitted) releaseFunctions)
    {cfg₁ cfg₂ : OramConfig}
    (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics bundle.run bundle.publicOutcome bundle.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage bundle.publicOutcome modelTags)
      bundle.publicOutcome
      finalPublicStateRollback
      releaseFunctions
      cfg₁
      cfg₂ := by
  apply paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on assumptions
    (bundle.toSeededRuntimePathOramProofBundleOn.computationalUOWithOn
      assumptions.toCanonicalLeafValueSecurityAssumptions)
  · intro c₁ c₂ hPair'
    simp [bundle.publicOutcomeSafe c₁ c₂ hPair']
  · intro c₁ c₂ hPair'
    simp [bundle.publicOutcomeSafe c₁ c₂ hPair', bundle.boundarySafe c₁ c₂ hPair']
  · exact hFinal
  · exact hRelease
  · exact hPair

end SeededRuntimePaperMainBundleOn

/-! ## The bundle exists: a runtime pair slice -/

/-- One side of a runtime pair as a configuration. The pair certificate records
the public configuration, with empty secret fields; the side's name, put first
in the secret arguments, stands for the secret inputs that tell the two runs
apart. -/
def pairSideCfg (cfg : OramConfig) (side : String) : OramConfig :=
  { cfg with secretArgs := side :: cfg.secretArgs }

namespace ConcreteRuntimePathOramPairSlice

variable {modelTags : SGXModelTags} (pair : ConcreteRuntimePathOramPairSlice modelTags)

def lhsCfg : OramConfig := pairSideCfg pair.lhs.cfg "lhs"

def rhsCfg : OramConfig := pairSideCfg pair.lhs.cfg "rhs"

/-- A pair slice admits its two sides. -/
def Admitted (cfg : OramConfig) : Prop := cfg = pair.lhsCfg ∨ cfg = pair.rhsCfg

theorem lhsCfg_ne_rhsCfg : pair.lhsCfg ≠ pair.rhsCfg := by
  intro h
  have hArgs := congrArg OramConfig.secretArgs h
  simp [lhsCfg, rhsCfg, pairSideCfg] at hArgs

theorem sameOramPublicProjection_sides : sameOramPublicProjection pair.lhsCfg pair.rhsCfg := rfl

theorem admittedSamePublic_sides : AdmittedSamePublic pair.Admitted pair.lhsCfg pair.rhsCfg :=
  ⟨Or.inl rfl, Or.inr rfl, pair.sameOramPublicProjection_sides⟩

/-- The runtime family of each side. -/
def sideFamily (cfg : OramConfig) : SeededRuntimePathOramWitnessFamily modelTags :=
  if cfg = pair.rhsCfg then pair.rhs.family else pair.lhs.family

theorem sideFamily_lhs : pair.sideFamily pair.lhsCfg = pair.lhs.family :=
  if_neg pair.lhsCfg_ne_rhsCfg

theorem sideFamily_rhs : pair.sideFamily pair.rhsCfg = pair.rhs.family := if_pos rfl

/-- A property of both sides' families holds of the family of every admitted
configuration. -/
theorem side_cases {cfg : OramConfig} (h : pair.Admitted cfg)
    (P : SeededRuntimePathOramWitnessFamily modelTags → Prop)
    (hLhs : P pair.lhs.family) (hRhs : P pair.rhs.family) :
    P (pair.sideFamily cfg) := by
  rcases h with rfl | rfl
  · rw [sideFamily_lhs]; exact hLhs
  · rw [sideFamily_rhs]; exact hRhs

/-- **A runtime pair slice is a paper-main bundle** whose admitted
configurations are the pair's two sides. -/
def toPaperMainBundleOn : SeededRuntimePaperMainBundleOn modelTags pair.Admitted :=
  { family := pair.sideFamily
    cfgWellFormed := fun cfg h => by
      rcases h with rfl | rfl <;> exact pair.lhs.cfgWellFormed
    publicView := fun _ => pair.lhs.publicView
    publicViewExact := fun cfg h =>
      pair.side_cases h
        (fun family => ∀ seed, seed < family.seedCount →
          pathOramViewPublicPart (viewMPlus ((family.witnessAt seed).trace)) =
            pair.lhs.publicView)
        pair.lhs.publicViewExact
        (by rw [pair.samePublicView]; exact pair.rhs.publicViewExact)
    publicViewSafe := fun _ _ _ => rfl
    objectsMatchPublicConfig := fun cfg h => by
      rcases h with rfl | rfl
      · rw [sideFamily_lhs]; exact pair.lhs.objectsMatchPublicConfig
      · rw [sideFamily_rhs]
        intro seed hSeed
        have hMatch := pair.rhs.objectsMatchPublicConfig seed hSeed
        rw [← pair.sameCfg] at hMatch
        exact hMatch
    publicLocation := fun _ => pair.lhs.publicLocation
    publicLocationExact := fun cfg h =>
      pair.side_cases h
        (fun family => ∀ seed, seed < family.seedCount →
          pathOramPublicLocationTrace
              (pathOramStorageLocationTrace
                (oramStorageView (viewMPlus ((family.witnessAt seed).trace)))) =
            pair.lhs.publicLocation)
        pair.lhs.publicLocationExact
        (by rw [pair.samePublicLocation]; exact pair.rhs.publicLocationExact)
    publicLocationSafe := fun _ _ _ => rfl
    storageShape := fun _ => pair.lhs.storageShape
    storageShapeExact := fun cfg h =>
      pair.side_cases h
        (fun family => ∀ seed, seed < family.seedCount →
          pathOramStorageShape (oramStorageView (viewMPlus ((family.witnessAt seed).trace))) =
            pair.lhs.storageShape)
        pair.lhs.storageShapeExact
        (by rw [pair.sameStorageShape]; exact pair.rhs.storageShapeExact)
    storageShapeSafe := fun _ _ _ => rfl
    canonicalSeedSpace := fun cfg h =>
      pair.side_cases h (fun family => family.RealizesCanonicalLeafValueSeedSpace)
        pair.lhs.hiddenLeafValueRefinement pair.rhs.hiddenLeafValueRefinement
    publicOutcome := fun _ => pair.lhs.publicOutcome
    publicOutcomeExact := fun cfg h =>
      pair.side_cases h
        (fun family => ∀ seed, seed < family.seedCount →
          (family.witnessAt seed).publicOutcome = pair.lhs.publicOutcome)
        pair.lhs.publicOutcomeExact
        (by rw [pair.samePublicOutcome]; exact pair.rhs.publicOutcomeExact)
    publicOutcomeSafe := fun _ _ _ => rfl
    boundarySchedule := fun _ => pair.lhs.boundarySchedule
    boundaryExact := fun cfg h =>
      pair.side_cases h
        (fun family => ∀ seed, seed < family.seedCount →
          (family.witnessAt seed).boundarySchedule = pair.lhs.boundarySchedule)
        pair.lhs.boundaryExact
        (by rw [pair.sameBoundarySchedule]; exact pair.rhs.boundaryExact)
    boundarySafe := fun _ _ _ => rfl }

theorem toPaperMainBundleOn_run_lhs :
    pair.toPaperMainBundleOn.run pair.lhsCfg = pair.lhs.run := by
  show (pair.sideFamily pair.lhsCfg).viewDistribution = pair.lhs.family.viewDistribution
  rw [sideFamily_lhs]

theorem toPaperMainBundleOn_run_rhs :
    pair.toPaperMainBundleOn.run pair.rhsCfg = pair.rhs.run := by
  show (pair.sideFamily pair.rhsCfg).viewDistribution = pair.rhs.family.viewDistribution
  rw [sideFamily_rhs]

/-- **The bundle is not vacuous.** A pair slice's bundle admits two different
configurations with the same public projection. -/
theorem toPaperMainBundleOn_admits_distinct_pair :
    pair.Admitted pair.lhsCfg ∧ pair.Admitted pair.rhsCfg ∧
      sameOramPublicProjection pair.lhsCfg pair.rhsCfg ∧ pair.lhsCfg ≠ pair.rhsCfg :=
  ⟨Or.inl rfl, Or.inr rfl, pair.sameOramPublicProjection_sides, pair.lhsCfg_ne_rhsCfg⟩

/-- The general SGX execution theorem, at the pair's two sides: the left and
right runtime families' runs are related. -/
theorem sgxViewRelation_sides (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
    SGXViewRelation
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (pair.lhs.run.map
        (sgxViewOfOramView pair.lhsCfg pair.lhs.publicOutcome pair.lhs.boundarySchedule
          (oramControllerMicroTrace pair.lhsCfg)))
      (pair.rhs.run.map
        (sgxViewOfOramView pair.rhsCfg pair.lhs.publicOutcome pair.lhs.boundarySchedule
          (oramControllerMicroTrace pair.rhsCfg)))
      (executionLeakage pair.lhsCfg)
      (oramMicroLeakage (fun _ => pair.lhs.publicOutcome) modelTags pair.lhsCfg) := by
  have h :=
    pair.toPaperMainBundleOn.paperMainSgxExecution
      assumptions.toCanonicalLeafValueSecurityAssumptions
      pair.lhsCfg pair.rhsCfg pair.admittedSamePublic_sides
  rw [oramToSGXSemantics, oramToSGXSemantics, toPaperMainBundleOn_run_lhs,
    toPaperMainBundleOn_run_rhs] at h
  exact h

end ConcreteRuntimePathOramPairSlice

/-! ## The leaf obligation from the leaf model -/

open PathOramFreshLeaves CoinTape in
/-- The scaffold of a call on several maps: one step per access, on the
accessed map. -/
def callScaffold (name : Nat → String) (bucketCount : Nat → Nat)
    (accesses : List PathOramFreshLeaves.MapAccess) : PathOramLeafScheduleScaffold :=
  accesses.map fun access => (name access.1, bucketCount access.1)

open PathOramFreshLeaves CoinTape in
/-- Every tape of a call: the leaves of the keys present before the call, then
two coins per access, each below its map's leaf count. -/
def callTapes (bucketCount : Nat → Nat) (present : List (Nat × Nat))
    (accesses : List PathOramFreshLeaves.MapAccess) : List (List Nat) :=
  boundedTapes (multiBounds (fun map => pathOramLeafChoiceCount (bucketCount map)) present accesses)

theorem pathOramLeafChoiceCount_pos (bucketCount : Nat) : 0 < pathOramLeafChoiceCount bucketCount := by
  unfold pathOramLeafChoiceCount
  omega

open PathOramFreshLeaves CoinTape in
theorem callTapes_ne_nil (bucketCount : Nat → Nat) (present : List (Nat × Nat))
    (accesses : List PathOramFreshLeaves.MapAccess) :
    callTapes bucketCount present accesses ≠ [] := by
  have hPos : ∀ b ∈ multiBounds (fun map => pathOramLeafChoiceCount (bucketCount map)) present accesses,
      0 < b := by
    intro b hb
    simp only [multiBounds, coinBounds, List.mem_append, List.mem_map, List.mem_flatMap,
      List.mem_cons, List.not_mem_nil, or_false] at hb
    rcases hb with ⟨key, _, rfl⟩ | ⟨access, _, rfl | rfl⟩ <;> exact pathOramLeafChoiceCount_pos _
  intro hNil
  have hMem : List.replicate
      (multiBounds (fun map => pathOramLeafChoiceCount (bucketCount map)) present accesses).length 0 ∈
      callTapes bucketCount present accesses := by
    apply mem_boundedTapes.mpr
    refine ⟨by simp, ?_⟩
    intro i hi hb
    simp only [List.getElem_replicate]
    exact hPos _ (List.getElem_mem hb)
  rw [hNil] at hMem
  simp at hMem

open PathOramFreshLeaves CoinTape in
/-- **Every canonical schedule is the schedule of some tape**, by
`multiObservedLeaves_canonical`: each schedule appears equally often among the
tapes' schedules, and there are tapes. -/
theorem exists_tape_of_mem_canonical (name : Nat → String) (bucketCount : Nat → Nat)
    (present : List (Nat × Nat)) (accesses : List PathOramFreshLeaves.MapAccess)
    {v : List Nat}
    (hv : v ∈ (pathOramLeafValueDistributionOfScaffold (callScaffold name bucketCount accesses)).samples) :
    ∃ tape ∈ callTapes bucketCount present accesses,
      observedLeaves present (liftSteps accesses) tape = v := by
  obtain ⟨K, hPerm⟩ := multiObservedLeaves_canonical name bucketCount present accesses
  have hK : K ≠ 0 := by
    intro hK
    subst hK
    have hNil := hPerm.length_eq
    simp at hNil
    have hZero : ∀ l : List (List Nat), (l.map fun _ => (0 : Nat)).sum = 0 := by
      intro l
      induction l with
      | nil => rfl
      | cons a l ih => simp [ih]
    rw [hZero] at hNil
    exact callTapes_ne_nil bucketCount present accesses (List.eq_nil_of_length_eq_zero hNil)
  have hMem : v ∈ (pathOramLeafValueDistributionOfScaffold
      (callScaffold name bucketCount accesses)).samples.flatMap fun v => List.replicate K v :=
    List.mem_flatMap.mpr ⟨v, hv, List.mem_replicate.mpr ⟨hK, rfl⟩⟩
  obtain ⟨tape, hTape, hObs⟩ := List.mem_map.mp (hPerm.mem_iff.mpr hMem)
  exact ⟨tape, hTape, hObs⟩

theorem mem_samples_of_lt {scaffold : PathOramLeafScheduleScaffold} {seed : Nat}
    (hSeed : seed < pathOramLeafValueSeedSpaceSize scaffold) :
    pathOramLeafValueTraceOfSeed scaffold seed ∈
      (pathOramLeafValueDistributionOfScaffold scaffold).samples := by
  rw [pathOramLeafValueDistributionOfScaffold_samples_eq_seedRange]
  exact List.mem_map.mpr ⟨seed, List.mem_range.mpr hSeed, rfl⟩

/-- A runtime family that runs every coin tape of a call: for each tape (the
leaves of the keys `present` before the call, then two coins per access, each
below its map's leaf count), a run of the call. Each run's leaf values are
those the leaf model reads from its tape (`followsModel`). An accepted replay
is the leaf model on the coins its run recorded
(`replay_runLeaves_interleaved`), so a run whose starting leaves and recorded
coins are its tape meets this. -/
structure TapeRuntimePathOramWitnessFamily (modelTags : SGXModelTags) where
  name : Nat → String
  bucketCount : Nat → Nat
  present : List (Nat × Nat)
  accesses : List PathOramFreshLeaves.MapAccess
  witnessAt : List Nat → RuntimeRefinementWitness
  valid : ∀ tape ∈ callTapes bucketCount present accesses, (witnessAt tape).Valid modelTags
  publicLeafScaffoldExact :
    ∀ tape ∈ callTapes bucketCount present accesses,
      (witnessAt tape).projectedPublicPathOramLeafScaffold = callScaffold name bucketCount accesses
  followsModel :
    ∀ tape ∈ callTapes bucketCount present accesses,
      pathOramLeafValues (witnessAt tape).pathOramLeafScheduleTrace =
        PathOramFreshLeaves.observedLeaves present (PathOramFreshLeaves.liftSteps accesses) tape

namespace TapeRuntimePathOramWitnessFamily

variable {modelTags : SGXModelTags} (family : TapeRuntimePathOramWitnessFamily modelTags)

def tapes : List (List Nat) := callTapes family.bucketCount family.present family.accesses

def scaffold : PathOramLeafScheduleScaffold :=
  callScaffold family.name family.bucketCount family.accesses

/-- **Over all tapes, the runtime's leaf values are the canonical
distribution**, each schedule equally often. -/
theorem leafValues_perm_canonical :
    ∃ K, (family.tapes.map fun tape =>
        pathOramLeafValues (family.witnessAt tape).pathOramLeafScheduleTrace).Perm
      ((pathOramLeafValueDistributionOfScaffold family.scaffold).samples.flatMap fun v =>
        List.replicate K v) := by
  obtain ⟨K, hPerm⟩ := PathOramFreshLeaves.multiObservedLeaves_canonical family.name
    family.bucketCount family.present family.accesses
  refine ⟨K, ?_⟩
  have hMap :
      (family.tapes.map fun tape =>
          pathOramLeafValues (family.witnessAt tape).pathOramLeafScheduleTrace) =
        family.tapes.map
          (PathOramFreshLeaves.observedLeaves family.present
            (PathOramFreshLeaves.liftSteps family.accesses)) :=
    List.map_congr_left fun tape hTape => family.followsModel tape hTape
  rw [hMap]
  exact hPerm

/-- A tape whose schedule is the `seed`-th canonical schedule. -/
noncomputable def tapeOf (seed : Nat) : List Nat :=
  if hSeed : seed < pathOramLeafValueSeedSpaceSize family.scaffold then
    Classical.choose
      (exists_tape_of_mem_canonical family.name family.bucketCount family.present family.accesses
        (mem_samples_of_lt hSeed))
  else
    []

theorem tapeOf_spec {seed : Nat} (hSeed : seed < pathOramLeafValueSeedSpaceSize family.scaffold) :
    family.tapeOf seed ∈ family.tapes ∧
      PathOramFreshLeaves.observedLeaves family.present
          (PathOramFreshLeaves.liftSteps family.accesses) (family.tapeOf seed) =
        pathOramLeafValueTraceOfSeed family.scaffold seed := by
  rw [tapeOf, dif_pos hSeed]
  exact Classical.choose_spec
    (exists_tape_of_mem_canonical family.name family.bucketCount family.present family.accesses
      (mem_samples_of_lt hSeed))

/-- One tape per canonical schedule, as a seeded family. -/
noncomputable def toSeeded : SeededRuntimePathOramWitnessFamily modelTags :=
  { seedCount := pathOramLeafValueSeedSpaceSize family.scaffold
    witnessAt := fun seed => { family.witnessAt (family.tapeOf seed) with runtimeSeed := some seed }
    seedTagged := fun _ _ => rfl
    valid := fun _ hSeed => by
      simpa using family.valid _ (family.tapeOf_spec hSeed).1
    publicLeafScaffold := family.scaffold
    publicLeafScaffoldExact := fun _ hSeed =>
      family.publicLeafScaffoldExact _ (family.tapeOf_spec hSeed).1 }

/-- **The leaf obligation, without seed enumeration.** One tape per canonical
schedule realizes the canonical seed space: the `seed`-th run's leaf values
are the `seed`-th canonical schedule. -/
theorem toSeeded_realizesCanonicalLeafValueSeedSpace :
    family.toSeeded.RealizesCanonicalLeafValueSeedSpace := by
  refine ⟨rfl, fun seed hSeed => ?_⟩
  have hSpec := family.tapeOf_spec hSeed
  show pathOramLeafValues (family.witnessAt (family.tapeOf seed)).pathOramLeafScheduleTrace =
    pathOramLeafValueTraceOfSeed family.scaffold seed
  rw [family.followsModel _ hSpec.1]
  exact hSpec.2

theorem tapeOf_mem_tapes {seed : Nat} (hSeed : seed < family.toSeeded.seedCount) :
    family.tapeOf seed ∈ family.tapes :=
  (family.tapeOf_spec hSeed).1

end TapeRuntimePathOramWitnessFamily

/-- **Bundle evidence from tape families.** Every admitted configuration has a
runtime family that runs every coin tape of its call, and the public facts the
bundle needs hold on every tape. -/
structure TapePathOramPaperMainEvidenceOn (modelTags : SGXModelTags)
    (admitted : OramConfig → Prop) where
  tapeFamily : OramConfig → TapeRuntimePathOramWitnessFamily modelTags
  cfgWellFormed : ∀ cfg, admitted cfg → PathOramConfigWellFormed cfg
  publicView : OramConfig → OramViewPublicPart
  publicViewExact :
    ∀ cfg, admitted cfg → ∀ tape ∈ (tapeFamily cfg).tapes,
      pathOramViewPublicPart (viewMPlus (((tapeFamily cfg).witnessAt tape).trace)) =
        publicView cfg
  publicViewSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → publicView cfg₁ = publicView cfg₂
  objectsMatchPublicConfig :
    ∀ cfg, admitted cfg → ∀ tape ∈ (tapeFamily cfg).tapes,
      ((tapeFamily cfg).witnessAt tape).ObjectsMatchPublicConfig cfg
  publicLocation : OramConfig → PathOramStorageLocationTrace
  publicLocationExact :
    ∀ cfg, admitted cfg → ∀ tape ∈ (tapeFamily cfg).tapes,
      pathOramPublicLocationTrace
          (pathOramStorageLocationTrace
            (oramStorageView (viewMPlus (((tapeFamily cfg).witnessAt tape).trace)))) =
        publicLocation cfg
  publicLocationSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
      publicLocation cfg₁ = publicLocation cfg₂
  storageShape : OramConfig → PathOramStorageShape
  storageShapeExact :
    ∀ cfg, admitted cfg → ∀ tape ∈ (tapeFamily cfg).tapes,
      pathOramStorageShape
          (oramStorageView (viewMPlus (((tapeFamily cfg).witnessAt tape).trace))) =
        storageShape cfg
  storageShapeSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → storageShape cfg₁ = storageShape cfg₂
  publicOutcome : OramConfig → SGXPublicOutcome
  publicOutcomeExact :
    ∀ cfg, admitted cfg → ∀ tape ∈ (tapeFamily cfg).tapes,
      ((tapeFamily cfg).witnessAt tape).publicOutcome = publicOutcome cfg
  publicOutcomeSafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ → publicOutcome cfg₁ = publicOutcome cfg₂
  boundarySchedule : OramConfig → List BoundaryEvent
  boundaryExact :
    ∀ cfg, admitted cfg → ∀ tape ∈ (tapeFamily cfg).tapes,
      ((tapeFamily cfg).witnessAt tape).boundarySchedule = boundarySchedule cfg
  boundarySafe :
    ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
      boundarySchedule cfg₁ = boundarySchedule cfg₂

namespace TapePathOramPaperMainEvidenceOn

variable {modelTags : SGXModelTags} {admitted : OramConfig → Prop}
  (evidence : TapePathOramPaperMainEvidenceOn modelTags admitted)

/-- The bundle of tape-family evidence: each admitted configuration's family is
one tape per canonical schedule, and its leaf obligation is
`toSeeded_realizesCanonicalLeafValueSeedSpace`. -/
noncomputable def toBundle : SeededRuntimePaperMainBundleOn modelTags admitted :=
  { family := fun cfg => (evidence.tapeFamily cfg).toSeeded
    cfgWellFormed := evidence.cfgWellFormed
    publicView := evidence.publicView
    publicViewExact := fun cfg h _ hSeed =>
      evidence.publicViewExact cfg h _ ((evidence.tapeFamily cfg).tapeOf_mem_tapes hSeed)
    publicViewSafe := evidence.publicViewSafe
    objectsMatchPublicConfig := fun cfg h _ hSeed =>
      evidence.objectsMatchPublicConfig cfg h _ ((evidence.tapeFamily cfg).tapeOf_mem_tapes hSeed)
    publicLocation := evidence.publicLocation
    publicLocationExact := fun cfg h _ hSeed =>
      evidence.publicLocationExact cfg h _ ((evidence.tapeFamily cfg).tapeOf_mem_tapes hSeed)
    publicLocationSafe := evidence.publicLocationSafe
    storageShape := evidence.storageShape
    storageShapeExact := fun cfg h _ hSeed =>
      evidence.storageShapeExact cfg h _ ((evidence.tapeFamily cfg).tapeOf_mem_tapes hSeed)
    storageShapeSafe := evidence.storageShapeSafe
    canonicalSeedSpace := fun cfg _ =>
      (evidence.tapeFamily cfg).toSeeded_realizesCanonicalLeafValueSeedSpace
    publicOutcome := evidence.publicOutcome
    publicOutcomeExact := fun cfg h _ hSeed =>
      evidence.publicOutcomeExact cfg h _ ((evidence.tapeFamily cfg).tapeOf_mem_tapes hSeed)
    publicOutcomeSafe := evidence.publicOutcomeSafe
    boundarySchedule := evidence.boundarySchedule
    boundaryExact := fun cfg h _ hSeed =>
      evidence.boundaryExact cfg h _ ((evidence.tapeFamily cfg).tapeOf_mem_tapes hSeed)
    boundarySafe := evidence.boundarySafe }

/-- **The `path_oram_local_posmap_v1` paper-main theorem over admitted
configurations, without seed enumeration.** Tape-family evidence gives the
theorem for every admitted pair; the leaf schedule's distribution comes from
`multiObservedLeaves_canonical`. -/
theorem paperMain_noninterference_moduloReleases
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
    {finalPublicStateRollback : OramConfig → PaperMainFinalPublicStateRollback}
    {releaseFunctions : OramConfig → PaperMainDeclaredReleaseFunctions}
    (hFinal :
      FinalPublicStateSafeModuloReleases (AdmittedSamePublic admitted) evidence.publicOutcome
        finalPublicStateRollback)
    (hRelease : PaperMainPublicFieldSafe (AdmittedSamePublic admitted) releaseFunctions)
    {cfg₁ cfg₂ : OramConfig}
    (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics evidence.toBundle.run evidence.publicOutcome evidence.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage evidence.publicOutcome modelTags)
      evidence.publicOutcome
      finalPublicStateRollback
      releaseFunctions
      cfg₁
      cfg₂ :=
  evidence.toBundle.paperMain_noninterference_moduloReleases assumptions hFinal hRelease hPair

end TapePathOramPaperMainEvidenceOn

end UOToolchain
