import UOToolchain.IRSyntax
import UOToolchain.TraceModel

/-!
# The layout of an exact object and the events of its scan and rewrite

An exact object (a cell, an array or a full-scan map on a sealed backend) is
read whole when a call loads it and rewritten whole when a call that may write
it commits. `ExactObjectLayout` is the public shape of such an object, and
`scanReads` and `updateWrites` are the events of one scan and one rewrite.

`KernelExactTrace.lean` builds the exact store's trace of a kernel program
from them. A runtime trace holds a scan or a rewrite as one item, and the
importer of traces (`RuntimeRefinementJson.lean`) names its events with the
same two functions, so both mean the same events.
-/

namespace UOToolchain.IR

/-- Public layout of an exact-backend object: its name, kind, number of slots
(one for a cell, the capacity for an array or map), and sealed record length. -/
structure ExactObjectLayout where
  name : String
  kind : ContainerKind
  slots : Nat
  recordLen : Nat

/-- Storage location of a slot, in the runtime's naming: `name` for a cell,
`name[slot]` for an array, `name#slot` for a map. -/
def ExactObjectLayout.location (object : ExactObjectLayout) (slot : Nat) : String :=
  match object.kind with
  | .cell => object.name
  | .arrayKind => object.name ++ "[" ++ toString slot ++ "]"
  | .mapKind => object.name ++ "#" ++ toString slot

/-- A full scan: one read of every slot. -/
def ExactObjectLayout.scanReads (object : ExactObjectLayout) : List PhysicalRead :=
  (List.range object.slots).map fun slot =>
    { object := object.name, location := object.location slot, len := object.recordLen }

/-- A full rewrite: one `Update`-class write of every slot. -/
def ExactObjectLayout.updateWrites (object : ExactObjectLayout) : List PhysicalWrite :=
  (List.range object.slots).map fun slot =>
    { object := object.name, location := object.location slot, writeClass := "Update",
      len := object.recordLen }

end UOToolchain.IR
