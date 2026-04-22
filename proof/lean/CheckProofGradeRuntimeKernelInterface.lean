import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelInterface <witness.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedWitnessProjectsToSingletonRuntimeKernelBoundaryAt
  {witness : ImportedRuntimeRefinementWitness}
  {modelTags : SGXModelTags}
  (hValid : ImportedRuntimeProofGradeKernelInterfaceAssurance witness modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (witness.toRuntimeWitness.toSingletonSeededRuntimePathOramWitnessFamily
      (importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        witness
        modelTags
        hValid.1).1) := by
  exact
    runtimeWitness_proofGradeKernelInterfaceBundle_projects_to_singletonRuntimeKernelBoundaryAt
      (runtimeWitness := witness.toRuntimeWitness)
      (modelTags := modelTags)
      (importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        witness
        modelTags
        hValid.1)

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let witness ←
        loadAndCheckImportedProofGradeRuntimeKernelInterfaceWitness path modelTags
      IO.println
        s!"validated proof-grade runtime kernel interface for {witness.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
