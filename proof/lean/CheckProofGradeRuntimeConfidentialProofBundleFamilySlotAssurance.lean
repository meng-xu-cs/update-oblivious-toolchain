import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialProofBundleFamilySlotAssurance <bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToFamilySlotAssurance
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_paper_main_slot_family_bundle.family.ProofGradePaperMainRuntimeAssurance
      modelTags ∧
    bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program.RuntimeNormalForm ∧
    bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program.entrypoint_id =
      bundle.runtime_paper_main_slot_family_bundle.runtimePublicOutcome.entrypointId ∧
    ∀ seed, seed < bundle.runtime_paper_main_slot_family_bundle.family.seed_count →
      ∃ witness,
        bundle.runtime_paper_main_slot_family_bundle.family.witnessAt? seed = some witness ∧
          ImportedRuntimeConfidentialCoreKernelInterfaceSlotAssurance
            witness
            bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program
            modelTags :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_family_slot_assurance
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
        s!"validated proof-grade runtime confidential proof bundle family slot assurance for {bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
