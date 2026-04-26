namespace UOToolchain

namespace RuntimeArrayAccessDiscipline

structure Parameters where
  capacity : Nat
deriving Repr, DecidableEq

structure Trace where
  capacity : Nat
  index : Nat
  overflowed : Bool
deriving Repr, DecidableEq

def initialTrace (parameters : Parameters) : Trace :=
  { capacity := parameters.capacity
  , index := 0
  , overflowed := false
  }

def step (trace : Trace) : Trace :=
  if trace.index < trace.capacity then
    { trace with index := trace.index + 1 }
  else
    { trace with overflowed := true }

def acceptedAccess (parameters : Parameters) (trace : Trace) : Prop :=
  trace.capacity = parameters.capacity ∧
    trace.index = parameters.capacity ∧
    trace.overflowed = false

def selectsSlot (parameters : Parameters) (logicalIndex slot : Nat) : Prop :=
  slot < parameters.capacity ∧ slot = logicalIndex

def selectedSlot? (parameters : Parameters) (logicalIndex : Nat) : Option Nat :=
  if logicalIndex < parameters.capacity then
    some logicalIndex
  else
    none

theorem initialTrace_capacity (parameters : Parameters) :
  (initialTrace parameters).capacity = parameters.capacity := by
  rfl

theorem step_incrementsIndex_beforeCapacity
  {trace : Trace}
  (h : trace.index < trace.capacity) :
  (step trace).index = trace.index + 1 := by
  simp [step, h]

theorem step_rejectsPastCapacity
  {trace : Trace}
  (h : ¬ trace.index < trace.capacity) :
  (step trace).overflowed = true := by
  simp [step, h]

theorem acceptedAccess_scansPublicCapacity
  {parameters : Parameters} {trace : Trace}
  (h : acceptedAccess parameters trace) :
  trace.index = parameters.capacity := by
  exact h.2.1

theorem acceptedAccess_notOverflowed
  {parameters : Parameters} {trace : Trace}
  (h : acceptedAccess parameters trace) :
  trace.overflowed = false := by
  exact h.2.2

theorem selectedSlot?_acceptsInBounds
  {parameters : Parameters} {logicalIndex : Nat}
  (h : logicalIndex < parameters.capacity) :
  selectedSlot? parameters logicalIndex = some logicalIndex := by
  simp [selectedSlot?, h]

theorem selectedSlot?_rejectsOutOfRange
  {parameters : Parameters} {logicalIndex : Nat}
  (h : ¬ logicalIndex < parameters.capacity) :
  selectedSlot? parameters logicalIndex = none := by
  simp [selectedSlot?, h]

theorem selectedSlot?_someSelectsSlot
  {parameters : Parameters} {logicalIndex slot : Nat}
  (h : selectedSlot? parameters logicalIndex = some slot) :
  selectsSlot parameters logicalIndex slot := by
  unfold selectedSlot? at h
  split at h
  · injection h with hSlot
    rw [← hSlot]
    exact ⟨by assumption, rfl⟩
  · contradiction

theorem selectsSlot_unique
  {parameters : Parameters} {logicalIndex slot₁ slot₂ : Nat}
  (h₁ : selectsSlot parameters logicalIndex slot₁)
  (h₂ : selectsSlot parameters logicalIndex slot₂) :
  slot₁ = slot₂ := by
  rw [h₁.2, h₂.2]

theorem selectsSlot_false_for_outOfRange
  {parameters : Parameters} {logicalIndex slot : Nat}
  (hOob : parameters.capacity ≤ logicalIndex)
  (hSlot : slot < parameters.capacity) :
  ¬ selectsSlot parameters logicalIndex slot := by
  intro h
  rcases h with ⟨_, hEq⟩
  rw [hEq] at hSlot
  exact Nat.not_lt_of_ge hOob hSlot

end RuntimeArrayAccessDiscipline

end UOToolchain
