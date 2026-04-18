import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelRefinementWitness <kernel-refinement-witness.json> <kernel-witness.json> <entrypoint-id>"

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
