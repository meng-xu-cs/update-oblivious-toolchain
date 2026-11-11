import UOToolchain.ProofGrade
import UOToolchain.PathOramAvlMapReplay

open UOToolchain.PathOramAvlMap

/-- Check a replay of the runtime's AVL map against the Lean model: every
result, every node access's kind, every size and every tree. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
    let input ← IO.FS.readFile path
    match checkReplayText input with
    | .ok (runs, operations) =>
      IO.println s!"runs={runs} operations={operations}"
      pure 0
    | .error message =>
      IO.eprintln s!"AVL map replay rejected: {message}"
      pure 1
  | _ =>
    IO.eprintln "usage: checkPathOramAvlMapReplay <replay.json>"
    pure 2
