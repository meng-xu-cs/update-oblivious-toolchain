import UOToolchain.ConfidentialKernelDsl

namespace UOToolchain

namespace RuntimeStatementTraceDiscipline

structure Trace where
  capacity : Nat
  len : Nat
  names : List String
  overflowed : Bool
deriving Repr, DecidableEq

def capacityForProgram (program : ConfidentialKernelSlotProgram) : Nat :=
  program.body.length

def initialTrace (program : ConfidentialKernelSlotProgram) : Trace :=
  { capacity := capacityForProgram program
  , len := 0
  , names := []
  , overflowed := false
  }

def recordStatement
  (trace : Trace)
  (statement : ConfidentialKernelSlotStatement) : Option Trace :=
  if trace.len < trace.capacity then
    some
      { trace with
        len := trace.len + 1
        names := trace.names ++ [statement.traceName]
      }
  else
    none

def boxedTrace (trace : Trace) : List String :=
  trace.names

def acceptedTraceForProgram
  (program : ConfidentialKernelSlotProgram)
  (trace : Trace) : Prop :=
  trace.capacity = capacityForProgram program ∧
    trace.len = program.statementTraceNames.length ∧
    trace.names = program.statementTraceNames ∧
    trace.overflowed = false

theorem statementTraceNames_length
  (program : ConfidentialKernelSlotProgram) :
  program.statementTraceNames.length = capacityForProgram program := by
  simp [ConfidentialKernelSlotProgram.statementTraceNames, capacityForProgram]

theorem initialTrace_capacityForProgram
  (program : ConfidentialKernelSlotProgram) :
  (initialTrace program).capacity = capacityForProgram program := by
  rfl

theorem initialTrace_noOverflow
  (program : ConfidentialKernelSlotProgram) :
  (initialTrace program).overflowed = false := by
  rfl

theorem initialTrace_namesEmpty
  (program : ConfidentialKernelSlotProgram) :
  (initialTrace program).names = [] := by
  rfl

theorem recordStatement_acceptsOnlyBelowCapacity
  {trace next : Trace} {statement : ConfidentialKernelSlotStatement}
  (h : recordStatement trace statement = some next) :
  trace.len < trace.capacity := by
  unfold recordStatement at h
  split at h
  · assumption
  · contradiction

theorem recordStatement_rejectsAtCapacity
  {trace : Trace} (statement : ConfidentialKernelSlotStatement)
  (h : ¬ trace.len < trace.capacity) :
  recordStatement trace statement = none := by
  unfold recordStatement
  simp [h]

theorem recordStatement_incrementsLength
  {trace next : Trace} {statement : ConfidentialKernelSlotStatement}
  (h : recordStatement trace statement = some next) :
  next.len = trace.len + 1 := by
  unfold recordStatement at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem recordStatement_appendsTraceName
  {trace next : Trace} {statement : ConfidentialKernelSlotStatement}
  (h : recordStatement trace statement = some next) :
  next.names = trace.names ++ [statement.traceName] := by
  unfold recordStatement at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem recordStatement_preservesNoOverflow
  {trace next : Trace} {statement : ConfidentialKernelSlotStatement}
  (h : recordStatement trace statement = some next)
  (hNoOverflow : trace.overflowed = false) :
  next.overflowed = false := by
  unfold recordStatement at h
  split at h
  · injection h with hnext
    rw [← hnext]
    exact hNoOverflow
  · contradiction

theorem acceptedTraceForProgram_exactLength
  {program : ConfidentialKernelSlotProgram}
  {trace : Trace}
  (h : acceptedTraceForProgram program trace) :
  trace.len = program.statementTraceNames.length :=
  h.2.1

theorem acceptedTraceForProgram_exactNames
  {program : ConfidentialKernelSlotProgram}
  {trace : Trace}
  (h : acceptedTraceForProgram program trace) :
  trace.names = program.statementTraceNames :=
  h.2.2.1

theorem acceptedTraceForProgram_noOverflow
  {program : ConfidentialKernelSlotProgram}
  {trace : Trace}
  (h : acceptedTraceForProgram program trace) :
  trace.overflowed = false :=
  h.2.2.2

theorem acceptedTraceForProgram_boxedTraceExact
  {program : ConfidentialKernelSlotProgram}
  {trace : Trace}
  (h : acceptedTraceForProgram program trace) :
  boxedTrace trace = program.statementTraceNames :=
  acceptedTraceForProgram_exactNames h

end RuntimeStatementTraceDiscipline

end UOToolchain
