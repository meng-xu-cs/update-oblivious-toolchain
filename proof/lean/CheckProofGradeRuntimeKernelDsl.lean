import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelDsl <kernel-dsl-bundle.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelDslBundle path
      IO.println
        s!"validated proof-grade runtime kernel DSL bundle for {bundle.confidential_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
