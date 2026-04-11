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

def Trace.empty : Trace :=
  { opcodeTrace := []
  , logicalAccesses := []
  , logicalWrites := []
  , physicalReads := []
  , physicalWrites := []
  , gasUsed := 0
  }

def Trace.append (lhs rhs : Trace) : Trace :=
  { opcodeTrace := lhs.opcodeTrace ++ rhs.opcodeTrace
  , logicalAccesses := lhs.logicalAccesses ++ rhs.logicalAccesses
  , logicalWrites := lhs.logicalWrites ++ rhs.logicalWrites
  , physicalReads := lhs.physicalReads ++ rhs.physicalReads
  , physicalWrites := lhs.physicalWrites ++ rhs.physicalWrites
  , gasUsed := lhs.gasUsed + rhs.gasUsed
  }

def Trace.concat : List Trace → Trace
  | [] => Trace.empty
  | trace :: traces => Trace.append trace (Trace.concat traces)

@[simp] theorem viewMPlus_empty : viewMPlus Trace.empty = ([], [], [], [], [], 0) := rfl

@[simp] theorem viewMPlus_append (lhs rhs : Trace) :
    viewMPlus (Trace.append lhs rhs) =
      ( lhs.opcodeTrace ++ rhs.opcodeTrace
      , lhs.logicalAccesses ++ rhs.logicalAccesses
      , lhs.logicalWrites ++ rhs.logicalWrites
      , lhs.physicalReads ++ rhs.physicalReads
      , lhs.physicalWrites ++ rhs.physicalWrites
      , lhs.gasUsed + rhs.gasUsed
      ) := rfl

@[simp] theorem concat_nil : Trace.concat [] = Trace.empty := rfl

@[simp] theorem concat_cons (trace : Trace) (traces : List Trace) :
    Trace.concat (trace :: traces) = Trace.append trace (Trace.concat traces) := rfl

@[simp] theorem append_empty_left (trace : Trace) : Trace.append Trace.empty trace = trace := by
  cases trace
  simp [Trace.append, Trace.empty]

@[simp] theorem append_empty_right (trace : Trace) : Trace.append trace Trace.empty = trace := by
  cases trace
  simp [Trace.append, Trace.empty]

theorem append_assoc (a b c : Trace) :
    Trace.append (Trace.append a b) c = Trace.append a (Trace.append b c) := by
  cases a
  cases b
  cases c
  simp [Trace.append, List.append_assoc, Nat.add_assoc]

theorem viewMPlus_injective {lhs rhs : Trace} :
    viewMPlus lhs = viewMPlus rhs → lhs = rhs := by
  intro h
  cases lhs
  cases rhs
  simpa [viewMPlus] using h

theorem viewMPlus_overwriteGas {lhs rhs : Trace} {budget : Nat} :
    viewMPlus lhs = viewMPlus rhs →
    viewMPlus ({ lhs with gasUsed := budget }) = viewMPlus ({ rhs with gasUsed := budget }) := by
  intro h
  cases lhs with
  | mk opcodeTrace logicalAccesses logicalWrites physicalReads physicalWrites gasUsed =>
      cases rhs with
      | mk opcodeTrace' logicalAccesses' logicalWrites' physicalReads' physicalWrites' gasUsed' =>
          simp [viewMPlus] at h ⊢
          rcases h with ⟨hOpcode, hLogicalAccesses, hLogicalWrites, hPhysicalReads, hPhysicalWrites, _hGas⟩
          exact ⟨hOpcode, hLogicalAccesses, hLogicalWrites, hPhysicalReads, hPhysicalWrites⟩

end UOToolchain
