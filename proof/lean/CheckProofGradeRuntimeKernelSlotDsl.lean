import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelSlotDsl <kernel-slot-dsl-bundle.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelSlotDslBundle path
      IO.println
        s!"validated proof-grade runtime kernel slot DSL bundle for {bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
