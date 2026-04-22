import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelSlotBoundary <bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.runtime_witness.toRuntimeWitness.toSingletonSeededRuntimePathOramWitnessFamily
      (importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        bundle.runtime_witness
        modelTags
        hValid.1.1).1)
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram :=
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
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
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle
          path modelTags
      IO.println
        s!"validated proof-grade runtime kernel slot boundary for {bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
