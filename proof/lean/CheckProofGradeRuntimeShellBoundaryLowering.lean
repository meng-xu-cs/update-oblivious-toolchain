import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeShellBoundaryLowering <shell-boundary-lowering-bundle.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundleToRuntimeBundle path
      IO.println
        s!"validated/recomputed proof-grade runtime shell-boundary lowering bundle for {runtimeBundle.confidentialProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
