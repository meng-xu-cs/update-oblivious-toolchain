import UOToolchain.PathOramJACMTheorem

namespace UOToolchain

/-- Paper-main theorem target for the concrete `path_oram_local_posmap_v1`
backend. This keeps the theorem boundary identical to the executable artifact
route; only the theorem-source provenance differs. -/
abbrev PaperMainPathOramTheoremTarget
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :=
  PathOramLocalPosmapV1StandardTheoremTarget assumptions

/-- Preferred paper-main theorem source: a literature-faithful Path ORAM
theorem fixed directly at the runtime-facing public observer and theorem-side
leaf schedule. This is the route the paper should cite or import. -/
abbrev PaperMainPathOramTheoremSourceAt
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (leafRun : OramConfig → Distribution PathOramLeafScheduleTrace) :=
  PathOramJACMLiteratureTheoremAt assumptions publicPart leafRun

/-- Appendix / executable-artifact theorem source. This stays at exactly the
same theorem interface as the paper-main route, but is self-instantiated from
the checked runtime witness family plus the explicit stash assumption so the
artifact can validate the bridge end to end today. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_artifactAppendixTheoremSource
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun :=
  bundle.pathOramLocalPosmapV1_jacmLiteratureTheoremAt assumptions hStash

/-- Paper-main imported-storage theorem: take an external or cited
literature-faithful theorem object at the frozen paper interface and lift it
through the already mechanized runtime storage envelope. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainImportedStorageTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  bundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACMAt assumptions paper

/-- Paper-main standard-theorem realization: this is the named bridge object
the paper should use once the external theorem source is supplied at the frozen
interface. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  bundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACMAt assumptions paper

/-- Appendix / executable-artifact imported-storage theorem. This keeps the
same theorem interface as the paper-main route but closes it using the current
self-instantiated theorem source. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_artifactAppendixImportedStorageTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  ImportedPathOramStorageTheorem assumptions :=
  bundle.pathOramLocalPosmapV1_paperMainImportedStorageTheorem
    assumptions
    (bundle.pathOramLocalPosmapV1_artifactAppendixTheoremSource assumptions hStash)

/-- Appendix / executable-artifact standard-theorem realization. This is the
artifact-side cross-check route corresponding to the paper-main theorem source,
but closed internally from the seeded runtime family. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  bundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
    assumptions
    (bundle.pathOramLocalPosmapV1_artifactAppendixTheoremSource assumptions hStash)

end UOToolchain
