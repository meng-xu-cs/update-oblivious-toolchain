import Lean.Data.Json
import UOToolchain.ProofGrade
import UOToolchain.RustSourceSlice

open Lean
open UOToolchain

/-- Print, for each Rust source file named, its production part
(`productionSource`) and the lines on which `#[cfg(test)]` marks something
other than a module or a function (`misplacedCfgTestLines`), as JSON. The
probe compares both with its own slicer's. -/
def main (args : List String) : IO UInt32 := do
  if args.isEmpty then
    IO.eprintln "usage: checkRustSourceSlices <file.rs>..."
    return 2
  let mut files : Array Json := #[]
  for path in args do
    let source ← IO.FS.readFile path
    files := files.push <| Json.mkObj
      [ ("path", Json.str path)
      , ("slice", Json.str (productionSource source))
      , ("misplaced_cfg_test_lines", toJson (misplacedCfgTestLines source)) ]
  IO.println (Json.mkObj [("files", Json.arr files)]).compress
  pure 0
