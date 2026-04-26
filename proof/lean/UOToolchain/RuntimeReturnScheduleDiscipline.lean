import UOToolchain.ConfidentialKernelDsl

namespace UOToolchain

namespace RuntimeReturnScheduleDiscipline

def tailEmpty {α : Type} : List α → Prop
  | [] => True
  | _ :: _ => False

def checkTailEmpty {α : Type} : List α → Bool
  | [] => true
  | _ :: _ => false

@[simp] theorem checkTailEmpty_eq_true_iff {α : Type} (xs : List α) :
    checkTailEmpty xs = true ↔ tailEmpty xs := by
  cases xs <;> simp [checkTailEmpty, tailEmpty]

def noStatementsAfterReturn : List String → Prop
  | [] => True
  | name :: rest =>
      if name = "return" then tailEmpty rest else noStatementsAfterReturn rest

def checkNoStatementsAfterReturn : List String → Bool
  | [] => true
  | name :: rest =>
      if name = "return" then checkTailEmpty rest else checkNoStatementsAfterReturn rest

@[simp] theorem checkNoStatementsAfterReturn_eq_true_iff (trace : List String) :
    checkNoStatementsAfterReturn trace = true ↔ noStatementsAfterReturn trace := by
  induction trace with
  | nil =>
      simp [checkNoStatementsAfterReturn, noStatementsAfterReturn]
  | cons name rest ih =>
      by_cases h : name = "return"
      · cases rest <;> simp [checkNoStatementsAfterReturn, noStatementsAfterReturn, h, tailEmpty]
      · simp [checkNoStatementsAfterReturn, noStatementsAfterReturn, h, ih]

theorem returnAtHead_forcesTailEmpty {rest : List String}
    (h : noStatementsAfterReturn ("return" :: rest)) :
    tailEmpty rest := by
  simpa [noStatementsAfterReturn]

def statementTraceHasPublicReturnTail (program : ConfidentialKernelSlotProgram) : Prop :=
  noStatementsAfterReturn program.statementTraceNames

def checkStatementTraceHasPublicReturnTail
    (program : ConfidentialKernelSlotProgram) : Bool :=
  checkNoStatementsAfterReturn program.statementTraceNames

@[simp] theorem checkStatementTraceHasPublicReturnTail_eq_true_iff
    (program : ConfidentialKernelSlotProgram) :
    checkStatementTraceHasPublicReturnTail program = true ↔
      statementTraceHasPublicReturnTail program := by
  simp [checkStatementTraceHasPublicReturnTail, statementTraceHasPublicReturnTail]

end RuntimeReturnScheduleDiscipline

end UOToolchain
