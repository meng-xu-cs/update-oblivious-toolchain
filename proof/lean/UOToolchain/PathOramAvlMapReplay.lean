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
  /-- The tree after the operation, where the replay records it: a replay of
  a large map records it after every few operations and after the last. -/
  tree : Option (List (Option (List Nat)))
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
def replaySchema : String := "uo-path-oram-avl-map-replay-v2"

/-- A tree in the replay's form: preorder, `[key, value, height]` per node and
`none` per absent child. -/
def Tree.preorder : Tree → List (Option (List Nat))
  | .leaf => [none]
  | .node l k v r => some [k, v, (Tree.node l k v r).height] :: (l.preorder ++ r.preorder)

/-- Whether the model's tree is the one the replay recorded, if it recorded
one. -/
def treeAgrees (t : Tree) (recorded : Option (List (Option (List Nat)))) : Bool :=
  match recorded with
  | some tree => t.preorder == tree
  | none => true

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
    unless size == op.size && treeAgrees t op.tree do
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
    unless treeAgrees r.tree op.tree do
      throw s!"{at_}: the tree after the put differs from the model's"
    pure (r.tree, r.size)

/-- What a check of a replay counted. -/
structure ReplayCounts where
  runs : Nat := 0
  operations : Nat := 0
  /-- The recorded trees, each compared with the model's. -/
  trees : Nat := 0
  /-- The nodes of the largest of them. -/
  largestTree : Nat := 0

/-- The nodes of a recorded tree. -/
def recordedNodes (tree : List (Option (List Nat))) : Nat :=
  (tree.filter Option.isSome).length

/-- Check a run from the empty map, and add what it holds to `counts`. The
tree after the last operation must be recorded, so that every operation is
followed by a comparison of trees. -/
def checkRun (counts : ReplayCounts) (run : ReplayRun) : Except String ReplayCounts := do
  let fuel := pathOramTreeAvlHeight run.capacity
  unless fuel == run.avl_height do
    throw s!"capacity {run.capacity}: AVL height {run.avl_height}, the model {fuel}"
  if let some last := run.operations.getLast? then
    unless last.tree.isSome do
      throw s!"capacity {run.capacity} seed {run.seed}: no tree after the last operation"
  let mut state : Tree × Nat := (.leaf, 0)
  let mut index := 0
  let mut counts := { counts with runs := counts.runs + 1 }
  for op in run.operations do
    state ← (checkOperation run.capacity fuel index state.1 state.2 op).mapError
      fun e => s!"capacity {run.capacity} seed {run.seed}: {e}"
    index := index + 1
    counts := { counts with operations := counts.operations + 1 }
    if let some tree := op.tree then
      counts := { counts with
        trees := counts.trees + 1
        largestTree := max counts.largestTree (recordedNodes tree) }
  pure counts

/-- Check a replay; returns what it counted. -/
def checkReplay (replay : Replay) : Except String ReplayCounts := do
  unless replay.schema == replaySchema do
    throw s!"replay schema {replay.schema}, expected {replaySchema}"
  if replay.runs.isEmpty then throw "the replay has no runs"
  let mut counts : ReplayCounts := {}
  for run in replay.runs do
    counts ← checkRun counts run
  pure counts

def checkReplayText (input : String) : Except String ReplayCounts := do
  let json ← Json.parse input
  let replay : Replay ← fromJson? json
  checkReplay replay

end UOToolchain.PathOramAvlMap
