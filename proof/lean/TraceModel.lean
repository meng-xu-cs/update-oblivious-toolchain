namespace UOToolchain

structure LogicalEvent where
  kind : String
  object : String
  detail : String
deriving Repr, DecidableEq

structure PhysicalRead where
  object : String
  location : String
  len : Nat
deriving Repr, DecidableEq

structure PhysicalWrite where
  object : String
  location : String
  writeClass : String
  len : Nat
deriving Repr, DecidableEq

structure Trace where
  opcodeTrace : List String
  logicalAccesses : List LogicalEvent
  logicalWrites : List LogicalEvent
  physicalReads : List PhysicalRead
  physicalWrites : List PhysicalWrite
  gasUsed : Nat
deriving Repr, DecidableEq

abbrev ViewMPlus := List String × List LogicalEvent × List LogicalEvent × List PhysicalRead × List PhysicalWrite × Nat

def viewMPlus (trace : Trace) : ViewMPlus :=
  ( trace.opcodeTrace
  , trace.logicalAccesses
  , trace.logicalWrites
  , trace.physicalReads
  , trace.physicalWrites
  , trace.gasUsed
  )

end UOToolchain
