import Lean.Data.Json
import UOToolchain.PathOramAvlMap

namespace UOToolchain.PathOramAvlMap

open Lean

/-- The runtime's record of one operation (`AvlMapReplayOperation` in
`runtime/uo-evm/src/avl_map_replay.rs`). -/
structure ReplayOperation where
  get : Bool
  key : Nat
  value : Nat
  apply : Bool
  result_value : Nat
  found : Bool
  overflow : Bool
  real : List Bool
  size : Nat
  tree : List (Option (List Nat))
  deriving FromJson

/-- The operations of one map, from empty. -/
structure ReplayRun where
  capacity : Nat
  seed : Nat
  avl_height : Nat
  operations : List ReplayOperation
  deriving FromJson

structure Replay where
  schema : String
  runs : List ReplayRun
  deriving FromJson

/-- The schema tag the runtime's replay carries. -/
def replaySchema : String := "uo-path-oram-avl-map-replay-v1"

/-- A tree in the replay's form: preorder, `[key, value, height]` per node and
`none` per absent child. -/
def Tree.preorder : Tree → List (Option (List Nat))
  | .leaf => [none]
  | .node l k v r => some [k, v, (Tree.node l k v r).height] :: (l.preorder ++ r.preorder)

/-- Check one recorded operation against the model from the model's map
before it, and return the model's map after it. -/
def checkOperation (capacity fuel index : Nat) (t : Tree) (size : Nat)
    (op : ReplayOperation) : Except String (Tree × Nat) := do
  let at_ := s!"operation {index} (key {op.key})"
  if op.get then
    let (value, found) := get op.key fuel t
    unless value == op.result_value && found == op.found do
      throw s!"{at_}: get returned ({op.result_value}, {op.found}), the model ({value}, {found})"
    unless getAccesses op.key fuel t == op.real do
      throw s!"{at_}: get accesses differ from the model's"
    unless size == op.size && t.preorder == op.tree do
      throw s!"{at_}: a get changed the map"
    pure (t, size)
  else
    let r := put capacity fuel t size op.key op.value op.apply
    unless r.overflow == op.overflow do
      throw s!"{at_}: put overflow {op.overflow}, the model {r.overflow}"
    unless putAccesses capacity fuel t size op.key op.value op.apply == op.real do
      throw s!"{at_}: put accesses differ from the model's"
    unless r.size == op.size do
      throw s!"{at_}: size {op.size} after the put, the model {r.size}"
    unless r.tree.preorder == op.tree do
      throw s!"{at_}: the tree after the put differs from the model's"
    pure (r.tree, r.size)

/-- Check a run from the empty map; returns its operation count. -/
def checkRun (run : ReplayRun) : Except String Nat := do
  let fuel := pathOramTreeAvlHeight run.capacity
  unless fuel == run.avl_height do
    throw s!"capacity {run.capacity}: AVL height {run.avl_height}, the model {fuel}"
  let mut state : Tree × Nat := (.leaf, 0)
  let mut index := 0
  for op in run.operations do
    state ← (checkOperation run.capacity fuel index state.1 state.2 op).mapError
      fun e => s!"capacity {run.capacity} seed {run.seed}: {e}"
    index := index + 1
  pure run.operations.length

/-- Check a replay; returns its run and operation counts. -/
def checkReplay (replay : Replay) : Except String (Nat × Nat) := do
  unless replay.schema == replaySchema do
    throw s!"replay schema {replay.schema}, expected {replaySchema}"
  if replay.runs.isEmpty then throw "the replay has no runs"
  let mut operations := 0
  for run in replay.runs do
    operations := operations + (← checkRun run)
  pure (replay.runs.length, operations)

def checkReplayText (input : String) : Except String (Nat × Nat) := do
  let json ← Json.parse input
  let replay : Replay ← fromJson? json
  checkReplay replay

end UOToolchain.PathOramAvlMap
