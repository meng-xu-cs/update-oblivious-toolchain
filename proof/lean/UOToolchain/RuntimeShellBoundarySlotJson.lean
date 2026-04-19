import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssuranceJson

open Lean

namespace UOToolchain

def importedRuntimeShellBoundarySlotBundleFieldNames : List String :=
  ["shell_boundary_bundle", "confidential_slot_program"]

structure ImportedRuntimeShellBoundarySlotBundle where
  shell_boundary_bundle : ImportedRuntimeShellBoundaryBundle
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeShellBoundarySlotBundle.slotBundle
  (bundle : ImportedRuntimeShellBoundarySlotBundle) :
  ImportedRuntimeKernelSlotDslBundle :=
  { kernel_witness := bundle.shell_boundary_bundle.kernel_witness
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeShellBoundarySlotBundle.Valid
  (bundle : ImportedRuntimeShellBoundarySlotBundle) : Prop :=
  bundle.shell_boundary_bundle.Valid ∧ bundle.slotBundle.Valid

def ImportedRuntimeShellBoundarySlotBundle.checkValid
  (bundle : ImportedRuntimeShellBoundarySlotBundle) : Bool :=
  bundle.shell_boundary_bundle.checkValid &&
    bundle.slotBundle.checkValid

def ImportedRuntimeShellBoundarySlotBundle.toRuntimeShellBoundarySlotBundle
  (bundle : ImportedRuntimeShellBoundarySlotBundle) : RuntimeShellBoundarySlotBundle :=
  { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
  , confidentialSlotProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
  }

@[simp] theorem importedRuntimeShellBoundarySlotBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeShellBoundarySlotBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeShellBoundarySlotBundle.checkValid
    ImportedRuntimeShellBoundarySlotBundle.Valid
    ImportedRuntimeShellBoundarySlotBundle.slotBundle
  simp [importedRuntimeShellBoundaryBundle_checkValid_eq_true_iff,
    importedRuntimeKernelSlotDslBundle_checkValid_eq_true_iff]

theorem importedRuntimeShellBoundarySlotBundle_shellRefines
  {bundle : ImportedRuntimeShellBoundarySlotBundle}
  (hValid : bundle.Valid) :
  bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.Refines
      bundle.shell_boundary_bundle.kernel_witness.shellContract := by
  exact importedRuntimeShellBoundaryBundle_witness_refines hValid.1

theorem importedRuntimeShellBoundarySlotBundle_slotSchedule_exact
  {bundle : ImportedRuntimeShellBoundarySlotBundle}
  (hValid : bundle.Valid) :
  bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
    bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_slot_program.expectedRuntimeKernelSteps := by
  exact importedRuntimeKernelSlotDslBundle_schedule_exact hValid.2

theorem importedRuntimeShellBoundarySlotBundle_toRuntimeValid
  (bundle : ImportedRuntimeShellBoundarySlotBundle)
  (hValid : bundle.Valid) :
  bundle.toRuntimeShellBoundarySlotBundle.Valid := by
  have hShell :
      bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.Valid := by
    exact importedRuntimeShellBoundaryBundle_toRuntimeValid
      bundle.shell_boundary_bundle hValid.1
  have hSlot :
      bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
          some bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
        bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
          bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    exact importedRuntimeKernelSlotDslBundle_toRuntimeSchedule_exact hValid.2
  unfold ImportedRuntimeShellBoundarySlotBundle.toRuntimeShellBoundarySlotBundle
    RuntimeShellBoundarySlotBundle.Valid
  simpa [ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using
    (show
      bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.Valid ∧
        bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
        bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness.kernelSteps =
          bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps from
      ⟨hShell, hSlot.1, hSlot.2⟩)

def parseImportedRuntimeShellBoundarySlotBundle
  (input : String) : Except String ImportedRuntimeShellBoundarySlotBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeShellBoundarySlotBundle
  (input : String) : Except String ImportedRuntimeShellBoundarySlotBundle := do
  let bundle ← parseImportedRuntimeShellBoundarySlotBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw
      "imported proof-grade runtime shell-boundary slot bundle does not satisfy Lean validity checks"

def loadImportedRuntimeShellBoundarySlotBundle
  (path : System.FilePath) : IO ImportedRuntimeShellBoundarySlotBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeShellBoundarySlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime shell-boundary slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeShellBoundarySlotBundle
  (path : System.FilePath) : IO ImportedRuntimeShellBoundarySlotBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeShellBoundarySlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime shell-boundary slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeShellBoundarySlotBundleToRuntimeBundle
  (path : System.FilePath) : IO RuntimeShellBoundarySlotBundle := do
  let bundle ← loadAndCheckImportedProofGradeRuntimeShellBoundarySlotBundle path
  pure bundle.toRuntimeShellBoundarySlotBundle

end UOToolchain
