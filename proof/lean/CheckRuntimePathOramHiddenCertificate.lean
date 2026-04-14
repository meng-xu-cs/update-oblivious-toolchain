import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkRuntimePathOramHiddenCertificate <certificate.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let certificate ← loadAndCheckImportedRuntimePathOramHiddenCertificate path
      IO.println
        s!"validated runtime path-ORAM hidden certificate with {certificate.oram_leaf_schedule.length} leaf steps"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
