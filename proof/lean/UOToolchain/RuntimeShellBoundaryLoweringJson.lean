import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeKernelDslJson
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

def importedRuntimeShellBoundaryLoweringBundleFieldNames : List String :=
  ["shell_boundary_bundle", "confidential_program", "confidential_slot_program"]

structure ImportedRuntimeShellBoundaryLoweringBundle where
  shell_boundary_bundle : ImportedRuntimeShellBoundaryBundle
  confidential_program : ImportedConfidentialKernelProgram
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeShellBoundaryLoweringBundle.loweringBundle
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle) :
  ImportedRuntimeKernelLoweringBundle :=
  { kernel_witness := bundle.shell_boundary_bundle.kernel_witness
  , confidential_program := bundle.confidential_program
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeShellBoundaryLoweringBundle.Valid
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle) : Prop :=
  bundle.shell_boundary_bundle.Valid ∧ bundle.loweringBundle.Valid

def ImportedRuntimeShellBoundaryLoweringBundle.checkValid
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle) : Bool :=
  bundle.shell_boundary_bundle.checkValid &&
    bundle.loweringBundle.checkValid

def ImportedRuntimeShellBoundaryLoweringBundle.toRuntimeShellBoundaryLoweringBundle?
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle) :
  Except String RuntimeShellBoundaryLoweringBundle := do
  let lowered ← bundle.confidential_program.toConfidentialKernelSlotProgram?
  pure
    { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    }

@[simp] theorem importedRuntimeShellBoundaryLoweringBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeShellBoundaryLoweringBundle.checkValid
    ImportedRuntimeShellBoundaryLoweringBundle.Valid
    ImportedRuntimeShellBoundaryLoweringBundle.loweringBundle
  simp [importedRuntimeShellBoundaryBundle_checkValid_eq_true_iff,
    importedRuntimeKernelLoweringBundle_checkValid_eq_true_iff]

theorem importedRuntimeShellBoundaryLoweringBundle_shellRefines
  {bundle : ImportedRuntimeShellBoundaryLoweringBundle}
  (hValid : bundle.Valid) :
  bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.Refines
      bundle.shell_boundary_bundle.kernel_witness.shellContract := by
  exact importedRuntimeShellBoundaryBundle_witness_refines hValid.1

theorem importedRuntimeShellBoundaryLoweringBundle_lowering_exact
  {bundle : ImportedRuntimeShellBoundaryLoweringBundle}
  (hValid : bundle.Valid) :
  checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program = true := by
  exact importedRuntimeKernelLoweringBundle_lowering_exact hValid.2

theorem importedRuntimeShellBoundaryLoweringBundle_namedSchedule_exact
  {bundle : ImportedRuntimeShellBoundaryLoweringBundle}
  (hValid : bundle.Valid) :
  bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_program.expectedRuntimeKernelSteps ∧
    bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_program.expectedRuntimeKernelSteps := by
  exact importedRuntimeKernelLoweringBundle_namedSchedule_exact hValid.2

theorem importedRuntimeShellBoundaryLoweringBundle_recomputedSlotSchedule_exact
  {bundle : ImportedRuntimeShellBoundaryLoweringBundle}
  (hValid : bundle.Valid) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some lowered.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        lowered.expectedRuntimeKernelSteps := by
  exact importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_exact hValid.2

theorem importedRuntimeShellBoundaryLoweringBundle_lowered_toRuntimeValid
  {bundle : ImportedRuntimeShellBoundaryLoweringBundle}
  (hValid : bundle.Valid)
  {lowered : ImportedConfidentialKernelSlotProgram}
  (hLowered : bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered) :
  RuntimeShellBoundaryLoweringBundle.Valid
    { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    } := by
  have hShell :
      bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.Valid := by
    exact importedRuntimeShellBoundaryBundle_toRuntimeValid
      bundle.shell_boundary_bundle hValid.1
  have hNamed :
      bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
        some bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
        bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
    simpa [ImportedRuntimeShellBoundaryLoweringBundle.loweringBundle,
      ImportedRuntimeKernelLoweringBundle.namedBundle] using
      importedRuntimeKernelDslBundle_toRuntimeSchedule_exact hValid.2.1
  have hLowering :
      bundle.confidential_program.toConfidentialKernelProgram.SlotLoweringMatches
        lowered.toConfidentialKernelSlotProgram := by
    exact importedConfidentialKernelProgram_slotLowering_ok_toRuntime hLowered
  unfold RuntimeShellBoundaryLoweringBundle.Valid
  simpa [ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using
    (show
      bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.Valid ∧
        bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
        bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness.kernelSteps =
          bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
        bundle.confidential_program.toConfidentialKernelProgram.SlotLoweringMatches
          lowered.toConfidentialKernelSlotProgram from
      ⟨hShell, hNamed.1, hNamed.2, hLowering⟩)

theorem importedRuntimeShellBoundaryLoweringBundle_toRuntimeValid
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle)
  (hValid : bundle.Valid) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      RuntimeShellBoundaryLoweringBundle.Valid
        { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } := by
  rcases importedRuntimeShellBoundaryLoweringBundle_recomputedSlotSchedule_exact hValid with
    ⟨lowered, hLowered, _, _⟩
  exact
    ⟨lowered, hLowered,
      importedRuntimeShellBoundaryLoweringBundle_lowered_toRuntimeValid
        hValid hLowered⟩

theorem importedRuntimeShellBoundaryLoweringBundle_toRuntimeBundle_sound
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle)
  (hValid : bundle.Valid) :
  ∃ runtimeBundle,
    bundle.toRuntimeShellBoundaryLoweringBundle? = .ok runtimeBundle ∧
      runtimeBundle.Valid := by
  rcases importedRuntimeShellBoundaryLoweringBundle_toRuntimeValid bundle hValid with
    ⟨lowered, hLowered, hRuntimeValid⟩
  refine ⟨{ shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
          , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
          , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
          }, ?_, hRuntimeValid⟩
  unfold ImportedRuntimeShellBoundaryLoweringBundle.toRuntimeShellBoundaryLoweringBundle?
  rw [hLowered]
  rfl

def parseImportedRuntimeShellBoundaryLoweringBundle
  (input : String) : Except String ImportedRuntimeShellBoundaryLoweringBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundle
  (input : String) : Except String ImportedRuntimeShellBoundaryLoweringBundle := do
  let bundle ← parseImportedRuntimeShellBoundaryLoweringBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw
      "imported proof-grade runtime shell-boundary lowering bundle does not satisfy Lean validity checks"

def parseAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundleToRuntimeBundle
  (input : String) : Except String RuntimeShellBoundaryLoweringBundle := do
  let bundle ← parseAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundle input
  match bundle.toRuntimeShellBoundaryLoweringBundle? with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw
        s!"validated imported runtime shell-boundary lowering bundle failed to recompute runtime lowering bundle: {err}"

def loadImportedRuntimeShellBoundaryLoweringBundle
  (path : System.FilePath) : IO ImportedRuntimeShellBoundaryLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeShellBoundaryLoweringBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime shell-boundary lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundle
  (path : System.FilePath) : IO ImportedRuntimeShellBoundaryLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime shell-boundary lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundleToRuntimeBundle
  (path : System.FilePath) : IO RuntimeShellBoundaryLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundleToRuntimeBundle input with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate/recompute runtime shell-boundary lowering bundle: {err}"

end UOToolchain
