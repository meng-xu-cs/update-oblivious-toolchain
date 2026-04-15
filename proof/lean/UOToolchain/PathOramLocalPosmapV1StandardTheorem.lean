import UOToolchain.PathOramLocalPosmapV1Refinement

namespace UOToolchain

/-- Exact theorem object that must be discharged in order to close the
remaining standard-Path-ORAM gap for the concrete
`path_oram_local_posmap_v1` backend. This fixes the public/storage semantics at
the repository boundary already used downstream, so once such an object exists
all repo-facing computational-UO, SGX, and TEE consequences are obtained by
projection rather than by reopening the theorem boundary. -/
abbrev PathOramLocalPosmapV1StandardTheoremTarget
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :=
  ImportedStandardPathOramTheorem assumptions

/-- Witness object for an abstract standard Path ORAM theorem at the exact
storage boundary used by the repository. A literature theorem or appendix proof
can target the proposition `StandardPathOramStorageTheoremAt`; this structure
is the proof-carrying witness behind that proposition. -/
structure StandardPathOramStorageTheoremWitness
  (_assumptions : PathOramLocalPosmapV1SecurityAssumptions)
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

/-- Abstract standard Path ORAM theorem statement at the exact storage boundary
used by the repository. This is the proposition that an imported literature
theorem or a self-contained appendix proof should discharge before the result
is packaged into the repo-facing theorem target. -/
abbrev StandardPathOramStorageTheoremAt
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (storageRun : OramStorageSemantics) : Prop :=
  Nonempty (StandardPathOramStorageTheoremWitness assumptions publicPart storageRun)

def StandardPathOramStorageTheoremWitness.toImportedImplementation
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (witness : StandardPathOramStorageTheoremWitness assumptions publicPart storageRun) :
  ImportedStandardPathOramImplementation assumptions publicPart storageRun := by
  exact
    { leafRun := witness.leafRun
    , cfgWellFormed := witness.cfgWellFormed
    , publicViewSafe := witness.publicViewSafe
    , leafValueCanonicalOnPublicPart := witness.leafValueCanonicalOnPublicPart
    , leafSchedulePublicAlignment := witness.leafSchedulePublicAlignment
    , bucketProjection := witness.bucketProjection
    , publicLocationRelation := witness.publicLocationRelation
    , storageShapeRelation := witness.storageShapeRelation
    }

noncomputable def StandardPathOramStorageTheoremAt.toImportedImplementation
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun) :
  ImportedStandardPathOramImplementation assumptions publicPart storageRun := by
  classical
  exact (Classical.choice hTheorem).toImportedImplementation

theorem ImportedStandardPathOramImplementation.standardPathOramStorageTheoremAt
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun) :
  StandardPathOramStorageTheoremAt assumptions publicPart storageRun := by
  exact
    ⟨ { leafRun := impl.leafRun
      , cfgWellFormed := impl.cfgWellFormed
      , publicViewSafe := impl.publicViewSafe
      , leafValueCanonicalOnPublicPart := impl.leafValueCanonicalOnPublicPart
      , leafSchedulePublicAlignment := impl.leafSchedulePublicAlignment
      , bucketProjection := impl.bucketProjection
      , publicLocationRelation := impl.publicLocationRelation
      , storageShapeRelation := impl.storageShapeRelation
      } ⟩

/-- The theorem-side core expected from a standard Path ORAM result. This is
the nontrivial cryptographic / ORAM statement: for the fixed public observer,
the hidden leaf-value schedule is canonical for each configuration. It does not
yet include the runtime-specific storage-envelope facts such as public metadata
pages, bucket projection, or exact storage-shape constancy. -/
structure StandardPathOramCoreTheorem
  (_assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart) where
  leafRun : OramConfig → Distribution PathOramLeafScheduleTrace
  cfgWellFormed : ∀ cfg, PathOramConfigWellFormed cfg
  publicViewSafe : OramPublicViewSafe publicPart
  leafValueCanonicalOnPublicPart :
    ∀ cfg,
      PathOramLeafValueCanonicalOnPublicPart
        ((leafRun cfg).map pathOramLeafValues)
        (publicPart cfg)
        (pathOramProjectedExecutionLeakage cfg)

/-- Runtime- and interface-specific storage-envelope facts needed to lift a
standard Path ORAM core theorem to the repo’s concrete storage observer. These
facts are about how the concrete runtime exposes a public scaffold, bucket
projection, public metadata/counter locations, and storage shape. -/
structure PathOramStorageEnvelope
  (publicPart : OramConfig → OramViewPublicPart)
  (storageRun : OramStorageSemantics)
  (leafRun : OramConfig → Distribution PathOramLeafScheduleTrace) where
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

def PathOramStorageEnvelope.realignLeafRun
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  {leafRun₁ leafRun₂ : OramConfig → Distribution PathOramLeafScheduleTrace}
  (envelope : PathOramStorageEnvelope publicPart storageRun leafRun₁)
  (hLeafRun : leafRun₁ = leafRun₂) :
  PathOramStorageEnvelope publicPart storageRun leafRun₂ := by
  cases hLeafRun
  exact envelope

def StandardPathOramCoreTheorem.toImportedImplementation
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (core : StandardPathOramCoreTheorem assumptions publicPart)
  (envelope : PathOramStorageEnvelope publicPart storageRun core.leafRun) :
  ImportedStandardPathOramImplementation assumptions publicPart storageRun :=
  { leafRun := core.leafRun
  , cfgWellFormed := core.cfgWellFormed
  , publicViewSafe := core.publicViewSafe
  , leafValueCanonicalOnPublicPart := core.leafValueCanonicalOnPublicPart
  , leafSchedulePublicAlignment := envelope.leafSchedulePublicAlignment
  , bucketProjection := envelope.bucketProjection
  , publicLocationRelation := envelope.publicLocationRelation
  , storageShapeRelation := envelope.storageShapeRelation
  }

def ImportedStandardPathOramImplementation.standardPathOramCoreTheorem
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun) :
  StandardPathOramCoreTheorem assumptions publicPart :=
  { leafRun := impl.leafRun
  , cfgWellFormed := impl.cfgWellFormed
  , publicViewSafe := impl.publicViewSafe
  , leafValueCanonicalOnPublicPart := impl.leafValueCanonicalOnPublicPart
  }

def ImportedStandardPathOramImplementation.pathOramStorageEnvelope
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (impl : ImportedStandardPathOramImplementation assumptions publicPart storageRun) :
  PathOramStorageEnvelope publicPart storageRun impl.leafRun :=
  { leafSchedulePublicAlignment := impl.leafSchedulePublicAlignment
  , bucketProjection := impl.bucketProjection
  , publicLocationRelation := impl.publicLocationRelation
  , storageShapeRelation := impl.storageShapeRelation
  }

theorem StandardPathOramCoreTheorem.standardPathOramStorageTheoremAt
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (core : StandardPathOramCoreTheorem assumptions publicPart)
  (envelope : PathOramStorageEnvelope publicPart storageRun core.leafRun) :
  StandardPathOramStorageTheoremAt assumptions publicPart storageRun := by
  exact (core.toImportedImplementation envelope).standardPathOramStorageTheoremAt

noncomputable def StandardPathOramStorageTheoremAt.toTarget
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun) :
  PathOramLocalPosmapV1StandardTheoremTarget assumptions :=
  { publicPart := publicPart
  , storageRun := storageRun
  , implementation := hTheorem.toImportedImplementation
  }

/-- Theorem-source object for an imported or appendix-level standard Path ORAM
result. This packages the exact public/storage semantics together with the
abstract theorem proposition `StandardPathOramStorageTheoremAt`, without
requiring the caller to explicitly construct the stronger repo-facing
implementation witness. -/
structure ImportedPathOramStorageTheorem
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) where
  publicPart : OramConfig → OramViewPublicPart
  storageRun : OramStorageSemantics
  theoremAt : StandardPathOramStorageTheoremAt assumptions publicPart storageRun

noncomputable def ImportedPathOramStorageTheorem.toTarget
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (theoremObj : ImportedPathOramStorageTheorem assumptions) :
  PathOramLocalPosmapV1StandardTheoremTarget assumptions :=
  theoremObj.theoremAt.toTarget

def PathOramLocalPosmapV1StandardTheoremTarget.toImportedPathOramStorageTheorem
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (target : PathOramLocalPosmapV1StandardTheoremTarget assumptions) :
  ImportedPathOramStorageTheorem assumptions :=
  { publicPart := target.publicPart
  , storageRun := target.storageRun
  , theoremAt := target.implementation.standardPathOramStorageTheoremAt
  }

namespace PathOramLocalPosmapV1StandardTheoremTarget

theorem standardStorageBoundary
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (target : PathOramLocalPosmapV1StandardTheoremTarget assumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    target.publicPart
    target.storageRun := by
  exact target.standardBoundary

theorem projects_to_computationalUOWith
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (target : PathOramLocalPosmapV1StandardTheoremTarget assumptions) :
  ComputationalUOWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    (liftOramStorageSemantics target.publicPart target.storageRun) := by
  exact
    pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
      assumptions
      target.standardStorageBoundary

theorem projects_to_standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (target : PathOramLocalPosmapV1StandardTheoremTarget assumptions)
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    target.publicPart
    target.storageRun
    publicOutcome
    boundarySchedule := by
  exact
    pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
      (modelTags := modelTags)
      assumptions
      target.standardStorageBoundary
      hOutcome
      hBoundary

end PathOramLocalPosmapV1StandardTheoremTarget

namespace ImportedPathOramStorageTheorem

theorem standardStorageBoundary
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (theoremObj : ImportedPathOramStorageTheorem assumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    theoremObj.publicPart
    theoremObj.storageRun := by
  exact theoremObj.toTarget.standardStorageBoundary

theorem standardStorageSecurity
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (theoremObj : ImportedPathOramStorageTheorem assumptions) :
  ComputationalStandardOramWith
    (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
    theoremObj.storageRun := by
  exact theoremObj.theoremAt.toImportedImplementation.standardStorageSecurity

theorem standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (theoremObj : ImportedPathOramStorageTheorem assumptions)
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    theoremObj.publicPart
    theoremObj.storageRun
    publicOutcome
    boundarySchedule := by
  exact theoremObj.toTarget.projects_to_standardPaperMainBoundary hOutcome hBoundary

end ImportedPathOramStorageTheorem

theorem StandardPathOramStorageTheoremAt.standardStorageBoundary
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    publicPart
    storageRun := by
  exact hTheorem.toTarget.standardStorageBoundary

theorem StandardPathOramStorageTheoremAt.standardStorageSecurity
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun) :
  ComputationalStandardOramWith
    (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
    storageRun := by
  exact hTheorem.toImportedImplementation.standardStorageSecurity

theorem StandardPathOramStorageTheoremAt.standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    publicPart
    storageRun
    publicOutcome
    boundarySchedule := by
  exact
    hTheorem.toTarget.projects_to_standardPaperMainBoundary
      (modelTags := modelTags)
      hOutcome
      hBoundary

/-- Concrete discharge object for the imported-theorem route: a standard Path
ORAM theorem target together with proof that the seeded runtime witness family
projects to that same public/storage interface and exposes a valid hidden
witness slice for every sampled execution. This is the exact proof object that
Steps 3 and 4 of the imported-theorem plan must construct. -/
structure PathOramLocalPosmapV1StandardTheoremRealization
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) where
  target : PathOramLocalPosmapV1StandardTheoremTarget assumptions
  publicPart_eq : target.publicPart = bundle.publicView
  storageRun_eq : target.storageRun = bundle.storageRun
  sampleConformance :
    ∀ cfg seed, seed < (bundle.family cfg).seedCount →
      let witness := (bundle.family cfg).witnessAt seed
      witness.toImportedStandardPathOramSample.publicPart = target.publicPart cfg ∧
      witness.toImportedStandardPathOramSample.storageView ∈ target.storageRun cfg ∧
        witness.toImportedStandardPathOramSample.hidden.Valid

def PathOramLocalPosmapV1ImportedImplementationConformance.realignStandardTheoremRealization
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions)
  (target : PathOramLocalPosmapV1StandardTheoremTarget assumptions)
  (hPublicPart : target.publicPart = bundle.publicView)
  (hStorageRun : target.storageRun = bundle.storageRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  { target := target
  , publicPart_eq := hPublicPart
  , storageRun_eq := hStorageRun
  , sampleConformance := by
      intro cfg seed hSeed
      simpa [hPublicPart, hStorageRun] using conformance.sampleConformance cfg seed hSeed
  }

def PathOramLocalPosmapV1ImportedImplementationConformance.standardTheoremRealization
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  conformance.realignStandardTheoremRealization conformance.imported rfl rfl

noncomputable def
    PathOramLocalPosmapV1ImportedImplementationConformance.realignImportedStorageTheoremRealization
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions)
  (theoremObj : ImportedPathOramStorageTheorem assumptions)
  (hPublicPart : theoremObj.publicPart = bundle.publicView)
  (hStorageRun : theoremObj.storageRun = bundle.storageRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  conformance.realignStandardTheoremRealization theoremObj.toTarget hPublicPart hStorageRun

noncomputable def
    PathOramLocalPosmapV1ImportedImplementationConformance.realignStandardTheoremAtRealization
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions)
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun)
  (hPublicPart : publicPart = bundle.publicView)
  (hStorageRun : storageRun = bundle.storageRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  conformance.realignStandardTheoremRealization hTheorem.toTarget hPublicPart hStorageRun

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealization
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  (bundle.pathOramLocalPosmapV1_importedImplementationConformance assumptions).standardTheoremRealization

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardPathOramCoreTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  StandardPathOramCoreTheorem assumptions bundle.publicView :=
  { leafRun := bundle.leafRun
  , cfgWellFormed := bundle.cfgWellFormed
  , publicViewSafe := bundle.publicViewSafe
  , leafValueCanonicalOnPublicPart := by
      intro cfg
      exact bundle.leafValueCanonicalOnPublicPart cfg (bundle.publicViewConstantProjection cfg)
  }

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_storageEnvelope
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags) :
  PathOramStorageEnvelope
    bundle.publicView
    bundle.storageRun
    bundle.leafRun :=
  { leafSchedulePublicAlignment := by
      intro cfg
      exact bundle.leafSchedulePublicAlignment cfg (bundle.publicViewConstantProjection cfg)
  , bucketProjection := by
      intro cfg
      unfold SeededRuntimePathOramProofBundle.storageRun
      rw [List.map_map]
      simpa [pathOramBucketTraceOfStorageView, pathOramBucketTraceOfView] using
        bundle.bucketProjection cfg
  , publicLocationRelation := by
      intro cfg₁ cfg₂ hSame
      simpa [SeededRuntimePathOramProofBundle.storageRun, List.map_map] using
        bundle.publicLocationRelation hSame
  , storageShapeRelation := by
      intro cfg₁ cfg₂ hSame
      simpa [SeededRuntimePathOramProofBundle.storageRun] using
        (oramExactProjectionRelation_map
          pathOramStorageShape
          oramStorageView
          (bundle.storageShapeRelation hSame))
  }

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardPathOramStorageTheoremAt
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  StandardPathOramStorageTheoremAt
    assumptions
    bundle.publicView
    bundle.storageRun := by
  exact
    StandardPathOramCoreTheorem.standardPathOramStorageTheoremAt
      (bundle.pathOramLocalPosmapV1_standardPathOramCoreTheorem assumptions)
      bundle.pathOramLocalPosmapV1_storageEnvelope

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfCore
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (core : StandardPathOramCoreTheorem assumptions bundle.publicView)
  (hLeafRun : core.leafRun = bundle.leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  { publicPart := bundle.publicView
  , storageRun := bundle.storageRun
  , theoremAt :=
      StandardPathOramCoreTheorem.standardPathOramStorageTheoremAt
        core
        (bundle.pathOramLocalPosmapV1_storageEnvelope.realignLeafRun hLeafRun.symm)
  }

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ImportedPathOramStorageTheorem assumptions :=
  { publicPart := bundle.publicView
  , storageRun := bundle.storageRun
  , theoremAt := bundle.pathOramLocalPosmapV1_standardPathOramStorageTheoremAt assumptions
  }

noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfCore
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (core : StandardPathOramCoreTheorem assumptions bundle.publicView)
  (hLeafRun : core.leafRun = bundle.leafRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  PathOramLocalPosmapV1ImportedImplementationConformance.realignImportedStorageTheoremRealization
    (bundle.pathOramLocalPosmapV1_importedImplementationConformance assumptions)
    (bundle.pathOramLocalPosmapV1_importedStorageTheoremOfCore assumptions core hLeafRun)
    rfl
    rfl

theorem PathOramLocalPosmapV1ImportedImplementationConformance.standardStorageBoundary_of_importedStorageTheorem
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions)
  (theoremObj : ImportedPathOramStorageTheorem assumptions)
  (hPublicPart : theoremObj.publicPart = bundle.publicView)
  (hStorageRun : theoremObj.storageRun = bundle.storageRun) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  let realization :=
    conformance.realignImportedStorageTheoremRealization
      theoremObj
      hPublicPart
      hStorageRun
  simpa [realization.publicPart_eq, realization.storageRun_eq] using
    realization.target.standardBoundary

theorem PathOramLocalPosmapV1ImportedImplementationConformance.standardStorageBoundary_of_standardTheoremAt
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (conformance : PathOramLocalPosmapV1ImportedImplementationConformance bundle assumptions)
  (hTheorem : StandardPathOramStorageTheoremAt assumptions publicPart storageRun)
  (hPublicPart : publicPart = bundle.publicView)
  (hStorageRun : storageRun = bundle.storageRun) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  let realization :=
    conformance.realignStandardTheoremAtRealization
      hTheorem
      hPublicPart
      hStorageRun
  simpa [realization.publicPart_eq, realization.storageRun_eq] using
    realization.target.standardBoundary

theorem PathOramLocalPosmapV1StandardTheoremRealization.standardStorageBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (realization : PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  simpa [realization.publicPart_eq, realization.storageRun_eq] using
    realization.target.standardBoundary

theorem PathOramLocalPosmapV1StandardTheoremRealization.standardPathOramStorageTheoremAt
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  (realization : PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions) :
  StandardPathOramStorageTheoremAt
    assumptions
    bundle.publicView
    bundle.storageRun := by
  simpa [realization.publicPart_eq, realization.storageRun_eq] using
    realization.target.implementation.standardPathOramStorageTheoremAt

theorem PathOramLocalPosmapV1StandardTheoremRealization.standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePathOramProofBundle modelTags}
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (realization : PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    bundle.publicView
    bundle.storageRun
    publicOutcome
    boundarySchedule := by
  exact
    pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
      (modelTags := modelTags)
      assumptions
      realization.standardStorageBoundary
      hOutcome
      hBoundary

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_standardPaperMainBoundaryOfStandardTheorem
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
    (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealization
      assumptions).standardPaperMainBoundary
      bundle.publicOutcomeSafe
      bundle.boundarySafe

end UOToolchain
