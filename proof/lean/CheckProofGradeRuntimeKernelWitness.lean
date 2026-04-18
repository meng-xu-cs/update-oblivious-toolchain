import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelWitness <kernel-witness.json> <entrypoint-id>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, entrypointId] =>
      let witness ← loadAndCheckImportedProofGradeRuntimeKernelWitness path entrypointId
      IO.println
        s!"validated proof-grade runtime kernel witness for {witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
