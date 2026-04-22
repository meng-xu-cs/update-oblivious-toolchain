import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainFamilyBoundary <paper-main-family-bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelBoundaryAt
  {bundle : ImportedSeededRuntimePaperMainFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (bundle.family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        hValid.1.1)) :=
  importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_runtimeKernelBoundaryAt
    hValid

noncomputable def importedBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedSeededRuntimePaperMainFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed,
      seed <
          (bundle.family.toSeededRuntimePathOramWitnessFamily
            modelTags
            (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
              hValid.1.1)).seedCount →
        RuntimeKernelConfinementBoundary := by
  exact
    importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_runtimeKernelConfinementBoundary
      hValid

def bundleEntrypoint
  (bundle : ImportedSeededRuntimePaperMainFamilyBundle) : String :=
  match bundle.family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeSeededRuntimePaperMainFamilyBundle
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime paper-main family boundary and confinement route for {bundleEntrypoint bundle} with {bundle.family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
