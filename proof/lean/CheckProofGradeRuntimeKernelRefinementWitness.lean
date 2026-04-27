import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelRefinementWitness <kernel-refinement-witness.json> <kernel-witness.json> <entrypoint-id>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel refinement witnesses witness `RefinesLeanKernelState` against
the paired proof-grade kernel witness. -/
theorem importedRuntimeKernelRefinementWitness_validates_refinesLeanKernelState
  {witness : ImportedRuntimeKernelRefinementWitness}
  {kernelWitness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hKernel : kernelWitness.ProofGradeValid entrypointId)
  (hRefinement : witness.Valid kernelWitness) :
  witness.RefinesLeanKernelState kernelWitness :=
  importedRuntimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
    hKernel hRefinement

def main (args : List String) : IO UInt32 := do
  match args with
  | [refinementPath, kernelPath, entrypointId] =>
      let kernelWitness ←
        loadAndCheckImportedProofGradeRuntimeKernelWitness kernelPath entrypointId
      let refinementWitness ←
        loadAndCheckImportedProofGradeRuntimeKernelRefinementWitness
          refinementPath kernelWitness entrypointId
      IO.println
        s!"validated proof-grade runtime kernel refinement witness for {kernelWitness.entrypoint_id} ({refinementWitness.events.length} events)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
