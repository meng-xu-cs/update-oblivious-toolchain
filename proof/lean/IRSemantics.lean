import TraceModel

namespace UOToolchain

structure ObjectShape where
  objectId : Nat
  backend : String
  capacity : Nat
deriving Repr, DecidableEq

structure Program where
  contract : String
  entrypoint : String
  objects : List ObjectShape
deriving Repr, DecidableEq

structure Input where
  publicArgs : List String
  secretArgs : List String
deriving Repr, DecidableEq

structure Config where
  program : Program
  input : Input
  publicState : List String
  secretState : List String
deriving Repr, DecidableEq

abbrev Semantics := Config → Trace

def samePublicProjection (lhs rhs : Config) : Prop :=
  lhs.program = rhs.program ∧ lhs.input.publicArgs = rhs.input.publicArgs ∧ lhs.publicState = rhs.publicState

end UOToolchain
