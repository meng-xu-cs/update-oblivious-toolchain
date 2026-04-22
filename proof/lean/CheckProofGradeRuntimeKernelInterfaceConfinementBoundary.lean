import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelInterfaceConfinementBoundary <witness.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedWitnessProjectsToRuntimeKernelConfinementBoundary
  {witness : ImportedRuntimeRefinementWitness}
  {modelTags : SGXModelTags}
  (hValid : ImportedRuntimeProofGradeKernelInterfaceAssurance witness modelTags) :
  let boundary := hValid.2.toRuntimeKernelConfinementBoundary
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract := by
  let boundary := hValid.2.toRuntimeKernelConfinementBoundary
  exact
    ⟨RuntimeKernelConfinementBoundary.toRefinesLeanKernelState boundary,
      RuntimeKernelConfinementBoundary.witness_refinesShellContract boundary⟩

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
        s!"validated proof-grade runtime kernel interface confinement boundary for {witness.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
