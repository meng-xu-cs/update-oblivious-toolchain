import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeShellBoundarySlot <shell-boundary-slot-bundle.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeShellBoundarySlotBundleToRuntimeBundle path
      IO.println
        s!"validated proof-grade runtime shell-boundary slot bundle for {runtimeBundle.confidentialSlotProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
