import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialProofBundleFamilyKernelInterface <bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelInterface
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed, seed < bundle.runtime_paper_main_family_bundle.family.seed_count →
    RuntimeProofGradeKernelInterface
      ((bundle.runtime_paper_main_family_bundle.family.toSeededRuntimePathOramWitnessFamily
        modelTags
        (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
          (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid
            hValid).1.1)).witnessAt seed) :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelInterface
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
        s!"validated proof-grade runtime confidential proof bundle family kernel interface for {bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
