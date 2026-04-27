import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeWitness <witness.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
refinement witnesses pin a proof-grade kernel witness whose
expected/emitted kernel steps agree exactly. -/
theorem importedRuntimeRefinementWitness_validates_proofGrade_kernelSchedule_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSteps,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps = some expectedKernelSteps ∧
      kernelWitness.kernel_steps = expectedKernelSteps :=
  importedWitness_proofGradeKernelSchedule_exact witness modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
refinement witnesses pin a proof-grade kernel witness whose
expected/emitted public object id universes agree exactly. -/
theorem importedRuntimeRefinementWitness_validates_proofGrade_publicObjectUniverse_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedPublicObjectIds,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_public_object_ids = some expectedPublicObjectIds ∧
      kernelWitness.public_object_ids = expectedPublicObjectIds :=
  importedWitness_proofGradePublicObjectUniverse_exact witness modelTags hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let witness ← loadAndCheckImportedProofGradeRuntimeRefinementWitness path modelTags
      IO.println
        s!"validated proof-grade runtime refinement witness for {witness.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
