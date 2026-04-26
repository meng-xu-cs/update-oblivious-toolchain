namespace UOToolchain

namespace RuntimeSmallMapLookupDiscipline

structure Parameters where
  capacity : Nat
deriving Repr, DecidableEq

structure Trace where
  capacity : Nat
  index : Nat
  matched : Bool
  overflowed : Bool
deriving Repr, DecidableEq

def initialTrace (parameters : Parameters) : Trace :=
  { capacity := parameters.capacity
  , index := 0
  , matched := false
  , overflowed := false
  }

def step (trace : Trace) (keyMatch : Bool) : Trace :=
  if trace.index < trace.capacity then
    { trace with
      index := trace.index + 1
      matched := trace.matched || keyMatch
    }
  else
    { trace with overflowed := true }

def scanMatches (keyMatches : List Bool) : Bool :=
  keyMatches.foldl (fun matched keyMatch => matched || keyMatch) false

def Precondition (parameters : Parameters) (keyMatches : List Bool) : Prop :=
  keyMatches.length = parameters.capacity

def scanMatches? (parameters : Parameters) (keyMatches : List Bool) : Option Trace :=
  if keyMatches.length = parameters.capacity then
    some
      { capacity := parameters.capacity
      , index := parameters.capacity
      , matched := scanMatches keyMatches
      , overflowed := false
      }
  else
    none

def acceptedLookup (parameters : Parameters) (trace : Trace) : Prop :=
  trace.capacity = parameters.capacity ∧
    trace.index = parameters.capacity ∧
    trace.overflowed = false

theorem initialTrace_capacity (parameters : Parameters) :
  (initialTrace parameters).capacity = parameters.capacity := by
  rfl

theorem step_incrementsIndex_beforeCapacity
  {trace : Trace} {keyMatch : Bool}
  (h : trace.index < trace.capacity) :
  (step trace keyMatch).index = trace.index + 1 := by
  simp [step, h]

theorem step_accumulatesMatch_beforeCapacity
  {trace : Trace} {keyMatch : Bool}
  (h : trace.index < trace.capacity) :
  (step trace keyMatch).matched = (trace.matched || keyMatch) := by
  simp [step, h]

theorem step_rejectsPastCapacity
  {trace : Trace} {keyMatch : Bool}
  (h : ¬ trace.index < trace.capacity) :
  (step trace keyMatch).overflowed = true := by
  simp [step, h]

theorem step_preservesMatchPastCapacity
  {trace : Trace} {keyMatch : Bool}
  (h : ¬ trace.index < trace.capacity) :
  (step trace keyMatch).matched = trace.matched := by
  simp [step, h]

theorem scanMatches?_acceptsExactPublicCapacity
  (parameters : Parameters)
  (keyMatches : List Bool)
  (h : Precondition parameters keyMatches) :
  scanMatches? parameters keyMatches =
    some
      { capacity := parameters.capacity
      , index := parameters.capacity
      , matched := scanMatches keyMatches
      , overflowed := false
      } := by
  simp [scanMatches?, Precondition] at h ⊢
  exact h

theorem scanMatches?_rejectsLengthMismatch
  (parameters : Parameters)
  (keyMatches : List Bool)
  (h : ¬ Precondition parameters keyMatches) :
  scanMatches? parameters keyMatches = none := by
  simp [scanMatches?, Precondition] at h ⊢
  exact h

theorem scanMatches?_someAcceptedLookup
  {parameters : Parameters}
  {keyMatches : List Bool}
  {trace : Trace}
  (h : scanMatches? parameters keyMatches = some trace) :
  acceptedLookup parameters trace := by
  unfold scanMatches? at h
  split at h
  · injection h with hTrace
    rw [← hTrace]
    exact ⟨rfl, ⟨rfl, rfl⟩⟩
  · contradiction

theorem scanMatches?_someMatchedEqualsFold
  {parameters : Parameters}
  {keyMatches : List Bool}
  {trace : Trace}
  (h : scanMatches? parameters keyMatches = some trace) :
  trace.matched = scanMatches keyMatches := by
  unfold scanMatches? at h
  split at h
  · injection h with hTrace
    rw [← hTrace]
  · contradiction

theorem acceptedLookup_scansPublicCapacity
  {parameters : Parameters} {trace : Trace}
  (h : acceptedLookup parameters trace) :
  trace.index = parameters.capacity := by
  exact h.2.1

theorem acceptedLookup_notOverflowed
  {parameters : Parameters} {trace : Trace}
  (h : acceptedLookup parameters trace) :
  trace.overflowed = false := by
  exact h.2.2

end RuntimeSmallMapLookupDiscipline

end UOToolchain
