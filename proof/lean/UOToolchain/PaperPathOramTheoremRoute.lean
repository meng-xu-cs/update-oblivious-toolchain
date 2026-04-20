import UOToolchain.PathOramJACMTheorem
import UOToolchain.RuntimeShellBoundary

namespace UOToolchain

/-- Paper-main theorem target for the concrete `path_oram_local_posmap_v1`
backend. This keeps the theorem boundary identical to the executable artifact
route; only the theorem-source provenance differs. -/
abbrev PaperMainPathOramTheoremTarget
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :=
  PathOramLocalPosmapV1StandardTheoremTarget assumptions

/-- Explicit remaining runtime-side assumption bundle for the frozen paper
route. The current proof gap is no longer left as prose: every emitted witness
in the seeded runtime family must satisfy the same proof-grade acceptance
predicate enforced by the Lean runtime-witness checker. -/
structure PaperMainRuntimeKernelAssumptions
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) where
  proofGradeAccepted :
    ∀ cfg seed, seed < (bundle.family cfg).seedCount →
      ((bundle.family cfg).witnessAt seed).ProofGradeValid modelTags

/-- Remaining runtime/kernel proof boundary for the paper route. This is the
checked shell-boundary / kernel-interface predicate that each emitted runtime
witness must satisfy in order to justify the trusted runtime/kernel story now
carried explicitly in Lean. -/
def PaperMainRuntimeKernelBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) : Prop :=
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelInterface ((bundle.family cfg).witnessAt seed)

theorem PaperMainRuntimeKernelAssumptions.projects_to_runtimeKernelBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelAssumptions bundle) :
  PaperMainRuntimeKernelBoundary bundle := by
  intro cfg seed hSeed
  exact runtimeWitness_proofGradeKernelInterface
    ((bundle.family cfg).witnessAt seed)
    modelTags
    (runtime.proofGradeAccepted cfg seed hSeed)

/-- Strengthened seeded paper-main bundle whose emitted witnesses are already
known to satisfy proof-grade acceptance. This is the smallest current bundle
shape from which the explicit paper-route runtime assumption bundle can be
discharged mechanically rather than supplied as an unrelated external claim. -/
structure ProofGradeSeededRuntimePaperMainBundle (modelTags : SGXModelTags)
    extends SeededRuntimePaperMainBundle modelTags where
  proofGradeAccepted :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).ProofGradeValid modelTags

def ProofGradeSeededRuntimePaperMainBundle.paperMainRuntimeKernelAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags) :
  PaperMainRuntimeKernelAssumptions bundle.toSeededRuntimePaperMainBundle :=
  { proofGradeAccepted := bundle.proofGradeAccepted }

theorem ProofGradeSeededRuntimePaperMainBundle.runtimeKernelBoundary
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags) :
  PaperMainRuntimeKernelBoundary bundle.toSeededRuntimePaperMainBundle := by
  exact
    (bundle.paperMainRuntimeKernelAssumptions).projects_to_runtimeKernelBoundary

/-- Paper-facing explicit assumption bundle at the frozen theorem route.
Backend cryptographic assumptions and the remaining runtime/kernel proof
interface assumptions are tracked separately so the paper and artifact story
can state exactly what is proved versus still trusted. -/
structure PaperMainPathOramAssumptions
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) where
  backend : PathOramLocalPosmapV1SecurityAssumptions
  runtime : PaperMainRuntimeKernelAssumptions bundle

def ProofGradeSeededRuntimePaperMainBundle.paperMainPathOramAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions) :
  PaperMainPathOramAssumptions bundle.toSeededRuntimePaperMainBundle :=
  { backend := backend
  , runtime := bundle.paperMainRuntimeKernelAssumptions
  }

/-- Paper-facing assurance object at the frozen route. The backend half is
discharged by the paper theorem source at the fixed standard-ORAM interface,
while the runtime half records the still-undischarged proof boundary for the
real kernel implementation. -/
structure PaperMainPathOramAssurance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramAssumptions bundle) where
  backendRealization :
    PathOramLocalPosmapV1StandardTheoremRealization
      bundle.toSeededRuntimePathOramProofBundle
      assumptions.backend
  runtimeKernelBoundary :
    PaperMainRuntimeKernelBoundary bundle

/-- Final paper-facing boundary currently supported by the repository at the
frozen route: the backend theorem consequence already follows for the seeded
runtime bundle, while the remaining runtime/kernel honesty gap is carried as an
explicit proof-interface boundary instead of being hidden in prose. -/
def PaperMainPathOramEndToEndBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramAssumptions bundle) : Prop :=
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions.backend ∧
    PaperMainRuntimeKernelBoundary bundle

theorem PaperMainPathOramAssurance.standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (assurance : PaperMainPathOramAssurance bundle assumptions) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions.backend
    bundle.publicView
    bundle.toSeededRuntimePathOramProofBundle.storageRun
    bundle.publicOutcome
    bundle.boundarySchedule := by
  exact
    assurance.backendRealization.standardPaperMainBoundary
      bundle.publicOutcomeSafe
      bundle.boundarySafe

theorem PaperMainPathOramAssurance.paperTheoremBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (_assurance : PaperMainPathOramAssurance bundle assumptions) :
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions.backend := by
  exact bundle.pathOramLocalPosmapV1_paperTheoremBoundary assumptions.backend

theorem PaperMainPathOramAssurance.endToEndBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (assurance : PaperMainPathOramAssurance bundle assumptions) :
  PaperMainPathOramEndToEndBoundary bundle assumptions := by
  exact ⟨assurance.paperTheoremBoundary, assurance.runtimeKernelBoundary⟩

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

/-- Paper-facing assurance object for the concrete `path_oram_local_posmap_v1`
route. The backend theorem source is supplied explicitly at the frozen paper
interface, and the remaining runtime/kernel trust point is packaged as the
separate runtime assumption bundle. -/
noncomputable def SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainAssurance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramAssumptions bundle)
  (paper :
    PaperMainPathOramTheoremSourceAt
      assumptions.backend
      bundle.publicView
      bundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramAssurance bundle assumptions :=
  { backendRealization :=
      SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
        bundle.toSeededRuntimePathOramProofBundle
        assumptions.backend
        paper
  , runtimeKernelBoundary :=
      assumptions.runtime.projects_to_runtimeKernelBoundary
  }

noncomputable def ProofGradeSeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainAssurance
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions)
  (paper :
    PaperMainPathOramTheoremSourceAt
      backend
      bundle.publicView
      bundle.toSeededRuntimePaperMainBundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramAssumptions backend) :=
  SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramAssumptions backend)
    paper

end UOToolchain
