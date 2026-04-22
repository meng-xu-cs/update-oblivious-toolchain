import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationInterface <interface.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let iface ← loadAndCheckImportedRuntimeImplementationInterface path
      IO.println
        s!"validated runtime implementation interface for source-backed uo-evm boundary ({iface.engine_source.length} engine bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
