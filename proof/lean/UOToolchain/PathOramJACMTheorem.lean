import UOToolchain.PathOramLocalPosmapV1StandardTheorem

namespace UOToolchain

/-- The stash theorem cited from the Path ORAM JACM paper is stated for bucket
size `Z = 5` (Theorem 5.1). The concrete repo backend now uses the same bucket
size, so the literature-facing theorem route is shape-compatible at the bucket
parameter level. -/
def pathOramJACMBlocksPerBucket : Nat := 5

/-- Minimal theorem-shape compatibility predicate for a verbatim JACM import. -/
def PathOramJACMCompatibleObject (object : OramObjectManifest) : Prop :=
  object.scheme = pathOramScheme ∧
    object.blocksPerBucket = pathOramJACMBlocksPerBucket

theorem WellFormedPathOramObject.blocksPerBucket_eq_repo
  {object : OramObjectManifest}
  (hObject : WellFormedPathOramObject object) :
  object.blocksPerBucket = pathOramBlocksPerBucket := by
  exact hObject.2.1

theorem WellFormedPathOramObject.jacmCompatibleObject
  {object : OramObjectManifest}
  (hObject : WellFormedPathOramObject object) :
  PathOramJACMCompatibleObject object := by
  exact ⟨hObject.1, by simpa [pathOramBlocksPerBucket, pathOramJACMBlocksPerBucket] using hObject.2.1⟩

theorem PathOramConfigWellFormed.jacmCompatibleObject
  {cfg : OramConfig}
  {object : OramObjectManifest}
  (hCfg : PathOramConfigWellFormed cfg)
  (hMem : object ∈ cfg.pubData.witness.oramObjects) :
  PathOramJACMCompatibleObject object := by
  exact (hCfg object hMem).jacmCompatibleObject

/-- Literature-facing Path ORAM theorem object aligned to the JACM paper:

- Section 3.6: the server-observed access-path labels are fresh random labels
  independent of the logical access sequence beyond the public scaffold
- Theorem 5.1: stash overflow is bounded with negligible failure probability
  under the chosen stash parameters

The repository keeps the stash-overflow statement as the explicit backend
assumption `stashOverflowBounded`, while this structure packages the paper-side
access-pattern theorem in a form that can be mapped into the repo’s
`StandardPathOramCoreTheorem`. -/
structure PathOramJACMLiteratureTheorem
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart) where
  leafRun : OramConfig → Distribution PathOramLeafScheduleTrace
  cfgWellFormed : ∀ cfg, PathOramConfigWellFormed cfg
  publicViewSafe : OramPublicViewSafe publicPart
  /-- Literature-style access-pattern statement: for each configuration, the
  observed Path ORAM path-label sequence is distributed exactly as the
  canonical fresh-leaf distribution determined by the public scaffold. -/
  accessPatternTheorem :
    ∀ cfg,
      PathOramLeafValueCanonicalOnPublicPart
        ((leafRun cfg).map pathOramLeafValues)
        (publicPart cfg)
        (pathOramProjectedExecutionLeakage cfg)
  /-- The paper’s stash theorem is represented at the repo boundary by the
  existing explicit backend assumption field. Including it here keeps the
  literature mapping honest without enlarging the final theorem boundary. -/
  stashOverflowTheorem : assumptions.stashOverflowBounded

/-- Literature-facing theorem fixed at a chosen theorem-side `leafRun`. This
is the cleanest paper route when the imported theorem is stated directly on the
runtime’s theorem-facing leaf schedule, because it removes the need for a
separate post hoc `leafRun` alignment proof. -/
structure PathOramJACMLiteratureTheoremAt
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (leafRun : OramConfig → Distribution PathOramLeafScheduleTrace) where
  cfgWellFormed : ∀ cfg, PathOramConfigWellFormed cfg
  publicViewSafe : OramPublicViewSafe publicPart
  accessPatternTheorem :
    ∀ cfg,
      PathOramLeafValueCanonicalOnPublicPart
        ((leafRun cfg).map pathOramLeafValues)
        (publicPart cfg)
        (pathOramProjectedExecutionLeakage cfg)
  stashOverflowTheorem : assumptions.stashOverflowBounded

def PathOramJACMLiteratureTheorem.toAt
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  (paper : PathOramJACMLiteratureTheorem assumptions publicPart) :
  PathOramJACMLiteratureTheoremAt assumptions publicPart paper.leafRun :=
  { cfgWellFormed := paper.cfgWellFormed
  , publicViewSafe := paper.publicViewSafe
  , accessPatternTheorem := paper.accessPatternTheorem
  , stashOverflowTheorem := paper.stashOverflowTheorem
  }

def PathOramJACMLiteratureTheorem.toStandardPathOramCoreTheorem
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  (paper : PathOramJACMLiteratureTheorem assumptions publicPart) :
  StandardPathOramCoreTheorem assumptions publicPart :=
  { leafRun := paper.leafRun
  , cfgWellFormed := paper.cfgWellFormed
  , publicViewSafe := paper.publicViewSafe
  , leafValueCanonicalOnPublicPart := paper.accessPatternTheorem
  }

def PathOramJACMLiteratureTheoremAt.toStandardPathOramCoreTheorem
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (paper : PathOramJACMLiteratureTheoremAt assumptions publicPart leafRun) :
  StandardPathOramCoreTheorem assumptions publicPart :=
  { leafRun := leafRun
  , cfgWellFormed := paper.cfgWellFormed
  , publicViewSafe := paper.publicViewSafe
  , leafValueCanonicalOnPublicPart := paper.accessPatternTheorem
  }

theorem PathOramJACMLiteratureTheorem.standardPathOramStorageTheoremAt
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (paper : PathOramJACMLiteratureTheorem assumptions publicPart)
  (envelope : PathOramStorageEnvelope publicPart storageRun paper.leafRun) :
  StandardPathOramStorageTheoremAt assumptions publicPart storageRun := by
  exact
    StandardPathOramCoreTheorem.standardPathOramStorageTheoremAt
      paper.toStandardPathOramCoreTheorem
      envelope

theorem PathOramJACMLiteratureTheoremAt.standardPathOramStorageTheoremAt
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (paper : PathOramJACMLiteratureTheoremAt assumptions publicPart leafRun)
  (envelope : PathOramStorageEnvelope publicPart storageRun leafRun) :
  StandardPathOramStorageTheoremAt assumptions publicPart storageRun := by
  exact
    StandardPathOramCoreTheorem.standardPathOramStorageTheoremAt
      paper.toStandardPathOramCoreTheorem
      envelope

noncomputable def PathOramJACMLiteratureTheorem.toImportedStorageTheorem
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  (paper : PathOramJACMLiteratureTheorem assumptions publicPart)
  (envelope : PathOramStorageEnvelope publicPart storageRun paper.leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  { publicPart := publicPart
  , storageRun := storageRun
  , theoremAt := paper.standardPathOramStorageTheoremAt envelope
  }

noncomputable def PathOramJACMLiteratureTheoremAt.toImportedStorageTheorem
  {assumptions : PathOramLocalPosmapV1SecurityAssumptions}
  {publicPart : OramConfig → OramViewPublicPart}
  {storageRun : OramStorageSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (paper : PathOramJACMLiteratureTheoremAt assumptions publicPart leafRun)
  (envelope : PathOramStorageEnvelope publicPart storageRun leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  { publicPart := publicPart
  , storageRun := storageRun
  , theoremAt := paper.standardPathOramStorageTheoremAt envelope
  }

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_jacmLiteratureTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  PathOramJACMLiteratureTheorem assumptions bundle.publicView :=
  { leafRun := bundle.leafRun
  , cfgWellFormed := bundle.cfgWellFormed
  , publicViewSafe := bundle.publicViewSafe
  , accessPatternTheorem := by
      intro cfg
      exact bundle.leafValueCanonicalOnPublicPart cfg (bundle.publicViewConstantProjection cfg)
  , stashOverflowTheorem := hStash
  }

def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_jacmLiteratureTheoremAt
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  PathOramJACMLiteratureTheoremAt assumptions bundle.publicView bundle.leafRun :=
  (bundle.pathOramLocalPosmapV1_jacmLiteratureTheorem assumptions hStash).toAt

noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACM
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PathOramJACMLiteratureTheorem assumptions bundle.publicView)
  (hLeafRun : paper.leafRun = bundle.leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  paper.toImportedStorageTheorem
    (bundle.pathOramLocalPosmapV1_storageEnvelope.realignLeafRun hLeafRun.symm)

noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACMAt
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PathOramJACMLiteratureTheoremAt assumptions bundle.publicView bundle.leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  paper.toImportedStorageTheorem bundle.pathOramLocalPosmapV1_storageEnvelope

noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACM
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PathOramJACMLiteratureTheorem assumptions bundle.publicView)
  (hLeafRun : paper.leafRun = bundle.leafRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  PathOramLocalPosmapV1ImportedImplementationConformance.realignImportedStorageTheoremRealization
    (bundle.pathOramLocalPosmapV1_importedImplementationConformance assumptions)
    (bundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACM assumptions paper hLeafRun)
    rfl
    rfl

noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACMAt
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PathOramJACMLiteratureTheoremAt assumptions bundle.publicView bundle.leafRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  PathOramLocalPosmapV1ImportedImplementationConformance.realignImportedStorageTheoremRealization
    (bundle.pathOramLocalPosmapV1_importedImplementationConformance assumptions)
    (bundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACMAt assumptions paper)
    rfl
    rfl

end UOToolchain
