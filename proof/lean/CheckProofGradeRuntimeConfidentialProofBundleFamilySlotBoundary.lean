import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialProofBundleFamilySlotBoundary <bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.runtime_paper_main_slot_family_bundle.family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid
          hValid).1))
    bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program.toConfidentialKernelSlotProgram :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelSlotBoundaryAt
    hValid

noncomputable def importedBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed,
      seed <
          (bundle.runtime_paper_main_slot_family_bundle.family.toSeededRuntimePathOramWitnessFamily
            modelTags
            (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
              (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid
                hValid).1)).seedCount →
        RuntimeKernelConfinementBoundary := by
  exact
    importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelSlotConfinementBoundary
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialProofBundleFamily path modelTags
      IO.println
        s!"validated proof-grade runtime confidential proof bundle family slot boundary and confinement route for {bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
