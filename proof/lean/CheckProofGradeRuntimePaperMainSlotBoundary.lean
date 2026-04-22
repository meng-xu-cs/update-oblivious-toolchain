import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainSlotBoundary <paper-main-slot-family-bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelSlotBoundaryAt
  {bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        hValid.1))
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram :=
  importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_runtimeKernelSlotBoundaryAt
    hValid

noncomputable def importedBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed,
      seed <
          (bundle.family.toSeededRuntimePathOramWitnessFamily
            modelTags
            (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
              hValid.1)).seedCount →
        RuntimeKernelConfinementBoundary := by
  exact
    importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_runtimeKernelConfinementBoundary
      hValid

def bundleEntrypoint
  (bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle) : String :=
  bundle.confidential_slot_program.entrypoint_id

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeSeededRuntimePaperMainSlotFamilyBundle
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime paper-main slot boundary and confinement route for {bundleEntrypoint bundle} with {bundle.family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
