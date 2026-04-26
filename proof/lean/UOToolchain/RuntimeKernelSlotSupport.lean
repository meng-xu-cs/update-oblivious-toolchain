import UOToolchain.ConfidentialKernelDsl

open Lean

namespace UOToolchain

namespace RuntimeKernelSlotSupport

abbrev SlotFile := List (Option Json)

def Precondition
  (program : ConfidentialKernelSlotProgram)
  (args : List Json) : Prop :=
  args.length = program.paramCount ∧ program.paramCount ≤ program.slotCount

def checkPrecondition
  (program : ConfidentialKernelSlotProgram)
  (args : List Json) : Bool :=
  args.length == program.paramCount &&
    decide (program.paramCount ≤ program.slotCount)

def emptySlotFile (slotCount : Nat) : SlotFile :=
  List.replicate slotCount none

def getArg? : List Json → Nat → Option Json
  | [], _ => none
  | arg :: _, 0 => some arg
  | _ :: args, slot + 1 => getArg? args slot

def stageArgs (slotCount : Nat) (args : List Json) : SlotFile :=
  (List.range slotCount).map (fun slot => getArg? args slot)

def stageArgs?
  (program : ConfidentialKernelSlotProgram)
  (args : List Json) : Option SlotFile :=
  if checkPrecondition program args then
    some (stageArgs program.slotCount args)
  else
    none

def StagesCallInputs
  (program : ConfidentialKernelSlotProgram)
  (args : List Json)
  (slots : SlotFile) : Prop :=
  Precondition program args ∧ slots = stageArgs program.slotCount args

def liveSlotWords (slots : SlotFile) : Nat :=
  (slots.filter (fun slot => slot.isSome)).length

theorem emptySlotFile_length (slotCount : Nat) :
  (emptySlotFile slotCount).length = slotCount := by
  simp [emptySlotFile]

theorem stageArgs_length (slotCount : Nat) (args : List Json) :
  (stageArgs slotCount args).length = slotCount := by
  simp [stageArgs]

theorem stageArgs?_acceptsPrecondition
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  (h : Precondition program args) :
  stageArgs? program args = some (stageArgs program.slotCount args) := by
  simp [stageArgs?, checkPrecondition, h.1, h.2]

theorem stageArgs?_rejectsArgCountMismatch
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  (h : args.length ≠ program.paramCount) :
  stageArgs? program args = none := by
  simp [stageArgs?, checkPrecondition, h]

theorem stageArgs?_rejectsParamSlotOverflow
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  (h : ¬ program.paramCount ≤ program.slotCount) :
  stageArgs? program args = none := by
  simp [stageArgs?, checkPrecondition, h]

theorem stageArgs?_some_stagesCallInputs
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  {slots : SlotFile}
  (h : stageArgs? program args = some slots) :
  StagesCallInputs program args slots := by
  unfold stageArgs? checkPrecondition at h
  split at h
  · rename_i hCheck
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hCheck
    simp at h
    exact ⟨hCheck, h.symm⟩
  · contradiction

theorem stagesCallInputs_argCountExact
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  {slots : SlotFile}
  (h : StagesCallInputs program args slots) :
  args.length = program.paramCount :=
  h.1.1

theorem stagesCallInputs_paramSlotsBounded
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  {slots : SlotFile}
  (h : StagesCallInputs program args slots) :
  program.paramCount ≤ program.slotCount :=
  h.1.2

theorem stagesCallInputs_slotFileLength
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  {slots : SlotFile}
  (h : StagesCallInputs program args slots) :
  slots.length = program.slotCount := by
  rw [h.2]
  exact stageArgs_length program.slotCount args

theorem stagesCallInputs_deterministic
  {program : ConfidentialKernelSlotProgram}
  {args : List Json}
  {lhs rhs : SlotFile}
  (hLhs : StagesCallInputs program args lhs)
  (hRhs : StagesCallInputs program args rhs) :
  lhs = rhs := by
  rw [hLhs.2, hRhs.2]

end RuntimeKernelSlotSupport

end UOToolchain
