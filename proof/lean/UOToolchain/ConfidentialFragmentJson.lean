import Lean.Data.Json
import UOToolchain.ConfidentialFragment

open Lean

namespace UOToolchain

structure ImportedConfidentialFragmentEntrypointWitness where
  entrypoint_id : String
  select_count : Nat
  struct_field_count : Nat
  array_index_count : Nat
  non_branchless_select_arm_count : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedConfidentialFragmentEntrypointWitness.toConfidentialFragmentEntrypointWitness
  (witness : ImportedConfidentialFragmentEntrypointWitness) :
  ConfidentialFragmentEntrypointWitness :=
  { entrypointId := witness.entrypoint_id
  , selectCount := witness.select_count
  , structFieldCount := witness.struct_field_count
  , arrayIndexCount := witness.array_index_count
  , nonBranchlessSelectArmCount := witness.non_branchless_select_arm_count
  }

def ImportedConfidentialFragmentEntrypointWitness.Valid
  (witness : ImportedConfidentialFragmentEntrypointWitness) : Prop :=
  witness.toConfidentialFragmentEntrypointWitness.Valid

def ImportedConfidentialFragmentEntrypointWitness.checkValid
  (witness : ImportedConfidentialFragmentEntrypointWitness) : Bool :=
  witness.toConfidentialFragmentEntrypointWitness.checkValid

@[simp] theorem importedConfidentialFragmentEntrypointWitness_checkValid_eq_true_iff
  (witness : ImportedConfidentialFragmentEntrypointWitness) :
  witness.checkValid = true ↔ witness.Valid :=
  confidentialFragmentEntrypointWitness_checkValid_eq_true_iff
    witness.toConfidentialFragmentEntrypointWitness

structure ImportedConfidentialFragmentWitness where
  contract : String
  entrypoints : List ImportedConfidentialFragmentEntrypointWitness
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedConfidentialFragmentWitness.toConfidentialFragmentWitness
  (witness : ImportedConfidentialFragmentWitness) : ConfidentialFragmentWitness :=
  { contract := witness.contract
  , entrypoints := witness.entrypoints.map
      ImportedConfidentialFragmentEntrypointWitness.toConfidentialFragmentEntrypointWitness
  }

def ImportedConfidentialFragmentWitness.entrypoint?
  (witness : ImportedConfidentialFragmentWitness)
  (entrypointId : String) : Option ImportedConfidentialFragmentEntrypointWitness :=
  witness.entrypoints.find? (fun entrypoint => entrypoint.entrypoint_id == entrypointId)

def ImportedConfidentialFragmentWitness.Valid
  (witness : ImportedConfidentialFragmentWitness) : Prop :=
  witness.toConfidentialFragmentWitness.Valid

def ImportedConfidentialFragmentWitness.checkValid
  (witness : ImportedConfidentialFragmentWitness) : Bool :=
  witness.toConfidentialFragmentWitness.checkValid

@[simp] theorem importedConfidentialFragmentWitness_checkValid_eq_true_iff
  (witness : ImportedConfidentialFragmentWitness) :
  witness.checkValid = true ↔ witness.Valid :=
  confidentialFragmentWitness_checkValid_eq_true_iff witness.toConfidentialFragmentWitness

def ImportedConfidentialFragmentWitness.ValidForEntrypoint
  (witness : ImportedConfidentialFragmentWitness)
  (entrypointId : String) : Prop :=
  match witness.entrypoint? entrypointId with
  | none => False
  | some entrypoint => entrypoint.Valid

def ImportedConfidentialFragmentWitness.checkValidForEntrypoint
  (witness : ImportedConfidentialFragmentWitness)
  (entrypointId : String) : Bool :=
  match witness.entrypoint? entrypointId with
  | none => false
  | some entrypoint => entrypoint.checkValid

@[simp] theorem importedConfidentialFragmentWitness_checkValidForEntrypoint_eq_true_iff
  (witness : ImportedConfidentialFragmentWitness)
  (entrypointId : String) :
  witness.checkValidForEntrypoint entrypointId = true ↔
    witness.ValidForEntrypoint entrypointId := by
  cases hEntrypoint : witness.entrypoint? entrypointId with
  | none =>
      simp [ImportedConfidentialFragmentWitness.checkValidForEntrypoint,
        ImportedConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint]
  | some entrypoint =>
      simp [ImportedConfidentialFragmentWitness.checkValidForEntrypoint,
        ImportedConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint,
        importedConfidentialFragmentEntrypointWitness_checkValid_eq_true_iff]

theorem importedConfidentialFragmentWitness_validForEntrypoint_exists
  {witness : ImportedConfidentialFragmentWitness}
  {entrypointId : String}
  (hValid : witness.ValidForEntrypoint entrypointId) :
  ∃ entrypoint,
    witness.entrypoint? entrypointId = some entrypoint ∧
      entrypoint.Valid := by
  cases hEntrypoint : witness.entrypoint? entrypointId with
  | none =>
      simp [ImportedConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint] at hValid
  | some entrypoint =>
      refine ⟨entrypoint, rfl, ?_⟩
      simpa [ImportedConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint] using hValid

def parseImportedConfidentialFragmentWitness
  (input : String) : Except String ImportedConfidentialFragmentWitness := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedConfidentialFragmentWitness
  (input : String) : Except String ImportedConfidentialFragmentWitness := do
  let witness ← parseImportedConfidentialFragmentWitness input
  if witness.checkValid then
    pure witness
  else
    throw "imported confidential fragment witness does not satisfy Lean validity checks"

def parseAndCheckImportedConfidentialFragmentWitnessForEntrypoint
  (input : String)
  (entrypointId : String) : Except String ImportedConfidentialFragmentWitness := do
  let witness ← parseImportedConfidentialFragmentWitness input
  if witness.checkValidForEntrypoint entrypointId then
    pure witness
  else
    throw
      "imported confidential fragment witness does not validate for the requested entrypoint"

def loadImportedConfidentialFragmentWitness
  (path : System.FilePath) : IO ImportedConfidentialFragmentWitness := do
  let input ← IO.FS.readFile path
  match parseImportedConfidentialFragmentWitness input with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError s!"failed to parse confidential fragment witness: {err}"

def loadAndCheckImportedConfidentialFragmentWitness
  (path : System.FilePath) : IO ImportedConfidentialFragmentWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedConfidentialFragmentWitness input with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError s!"failed to validate confidential fragment witness: {err}"

def loadAndCheckImportedConfidentialFragmentWitnessForEntrypoint
  (path : System.FilePath)
  (entrypointId : String) : IO ImportedConfidentialFragmentWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedConfidentialFragmentWitnessForEntrypoint input entrypointId with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to validate confidential fragment witness for entrypoint {entrypointId}: {err}"

end UOToolchain
