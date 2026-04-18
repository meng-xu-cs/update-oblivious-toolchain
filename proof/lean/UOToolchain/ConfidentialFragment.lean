namespace UOToolchain

structure ConfidentialFragmentEntrypointWitness where
  entrypointId : String
  selectCount : Nat
  structFieldCount : Nat
  arrayIndexCount : Nat
  nonBranchlessSelectArmCount : Nat
deriving Repr, DecidableEq

def ConfidentialFragmentEntrypointWitness.Valid
  (witness : ConfidentialFragmentEntrypointWitness) : Prop :=
  witness.structFieldCount = 0 ∧
    witness.arrayIndexCount = 0 ∧
    witness.nonBranchlessSelectArmCount = 0

def ConfidentialFragmentEntrypointWitness.checkValid
  (witness : ConfidentialFragmentEntrypointWitness) : Bool :=
  decide (witness.structFieldCount = 0) &&
    decide (witness.arrayIndexCount = 0) &&
    decide (witness.nonBranchlessSelectArmCount = 0)

@[simp] theorem confidentialFragmentEntrypointWitness_checkValid_eq_true_iff
  (witness : ConfidentialFragmentEntrypointWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  simp [ConfidentialFragmentEntrypointWitness.checkValid,
    ConfidentialFragmentEntrypointWitness.Valid, and_assoc]

structure ConfidentialFragmentWitness where
  contract : String
  entrypoints : List ConfidentialFragmentEntrypointWitness
deriving Repr, DecidableEq

def ConfidentialFragmentWitness.entrypoint?
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) : Option ConfidentialFragmentEntrypointWitness :=
  witness.entrypoints.find? (fun entrypoint => entrypoint.entrypointId == entrypointId)

def ConfidentialFragmentWitness.Valid
  (witness : ConfidentialFragmentWitness) : Prop :=
  witness.entrypoints.all ConfidentialFragmentEntrypointWitness.checkValid = true

def ConfidentialFragmentWitness.checkValid
  (witness : ConfidentialFragmentWitness) : Bool :=
  witness.entrypoints.all ConfidentialFragmentEntrypointWitness.checkValid

@[simp] theorem confidentialFragmentWitness_checkValid_eq_true_iff
  (witness : ConfidentialFragmentWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  rfl

def ConfidentialFragmentWitness.ValidForEntrypoint
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) : Prop :=
  match witness.entrypoint? entrypointId with
  | none => False
  | some entrypoint => entrypoint.Valid

def ConfidentialFragmentWitness.checkValidForEntrypoint
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) : Bool :=
  match witness.entrypoint? entrypointId with
  | none => false
  | some entrypoint => entrypoint.checkValid

@[simp] theorem confidentialFragmentWitness_checkValidForEntrypoint_eq_true_iff
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) :
  witness.checkValidForEntrypoint entrypointId = true ↔
    witness.ValidForEntrypoint entrypointId := by
  cases hEntrypoint : witness.entrypoint? entrypointId with
  | none =>
      simp [ConfidentialFragmentWitness.checkValidForEntrypoint,
        ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint]
  | some entrypoint =>
      simp [ConfidentialFragmentWitness.checkValidForEntrypoint,
        ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint,
        confidentialFragmentEntrypointWitness_checkValid_eq_true_iff]

theorem confidentialFragmentWitness_validForEntrypoint_exists
  {witness : ConfidentialFragmentWitness}
  {entrypointId : String}
  (hValid : witness.ValidForEntrypoint entrypointId) :
  ∃ entrypoint,
    witness.entrypoint? entrypointId = some entrypoint ∧
      entrypoint.Valid := by
  cases hEntrypoint : witness.entrypoint? entrypointId with
  | none =>
      simp [ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint] at hValid
  | some entrypoint =>
      refine ⟨entrypoint, rfl, ?_⟩
      simpa [ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint] using hValid

end UOToolchain
