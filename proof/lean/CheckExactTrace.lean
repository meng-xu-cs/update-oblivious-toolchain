import Lean.Data.Json
import UOToolchain.ProofGrade
import UOToolchain.KernelExactTraceCheck

open Lean
open UOToolchain.ExactTraceJson

/-- Check runtime traces of exact-route calls against the exact store's
encoding of their entrypoints' kernel programs (`exactTraceMatches`).
Prints a verdict for each call and exits 0 only if every trace is the
encoding. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
    let input ← IO.FS.readFile path
    match Json.parse input >>= checkInput with
    | .error message =>
      IO.eprintln s!"exact trace check failed: {message}"
      pure 2
    | .ok verdicts =>
      let cases := verdicts.toArray.map fun verdict =>
        Json.mkObj
          [ ("name", Json.str verdict.name)
          , ("reads", toJson verdict.reads)
          , ("writes", toJson verdict.writes)
          , ("error", toJson verdict.error) ]
      IO.println (Json.mkObj [("cases", Json.arr cases)]).compress
      pure (if verdicts.all (·.error.isNone) then 0 else 1)
  | _ =>
    IO.eprintln "usage: checkExactTrace <exact-trace-cases.json>"
    pure 2
