import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssurance
import UOToolchain.RuntimeKernelDslJson
import UOToolchain.RuntimeKernelFinishBundleJson

open Lean

namespace UOToolchain

def importedRuntimeConfidentialCoreKernelFinishSlotBundleFieldNames : List String :=
  ["runtime_kernel_finish_bundle", "confidential_slot_program"]

structure ImportedRuntimeConfidentialCoreKernelFinishSlotBundle where
  runtime_kernel_finish_bundle : ImportedRuntimeKernelFinishBundle
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle) : Prop :=
  bundle.runtime_kernel_finish_bundle.Valid ∧
    bundle.confidential_slot_program.RuntimeNormalForm ∧
    ∃ kernelInterfaceBundle,
      bundle.runtime_kernel_finish_bundle.kernelInterfaceBundle? = some kernelInterfaceBundle ∧
        kernelInterfaceBundle.Valid ∧
        kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
          some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
        kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.kernel_steps =
          bundle.confidential_slot_program.expectedRuntimeKernelSteps

def ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle) : Bool :=
  bundle.runtime_kernel_finish_bundle.checkValid &&
    bundle.confidential_slot_program.checkRuntimeNormalForm &&
    match bundle.runtime_kernel_finish_bundle.kernelInterfaceBundle? with
    | none => false
    | some kernelInterfaceBundle =>
        ImportedRuntimeKernelInterfaceBundle.checkValid kernelInterfaceBundle &&
          decide
            (kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
              some bundle.confidential_slot_program.expectedRuntimeKernelSteps) &&
          decide
            (kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.kernel_steps =
              bundle.confidential_slot_program.expectedRuntimeKernelSteps)

@[simp]
theorem importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  cases hBundle : bundle.runtime_kernel_finish_bundle.kernelInterfaceBundle? with
  | none =>
      unfold ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.checkValid
        ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.Valid
      simp [hBundle]
  | some kernelInterfaceBundle =>
      unfold ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.checkValid
        ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.Valid
      simp [hBundle, importedRuntimeKernelFinishBundle_checkValid_eq_true_iff,
        importedConfidentialKernelSlotProgram_checkRuntimeNormalForm_eq_true_iff,
        importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff,
        decide_eq_true_eq, and_assoc]

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelFinishSlotBoundary := by
  let hBundleExists :
      ∃ kernelInterfaceBundle,
        bundle.runtime_kernel_finish_bundle.kernelInterfaceBundle? = some kernelInterfaceBundle ∧
          kernelInterfaceBundle.Valid ∧
          kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
            some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
          kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.kernel_steps =
            bundle.confidential_slot_program.expectedRuntimeKernelSteps := hValid.2.2
  let kernelInterfaceBundle := Classical.choose hBundleExists
  have hBundleSpec := Classical.choose_spec hBundleExists
  have hRuntimeNormalForm : bundle.confidential_slot_program.RuntimeNormalForm := hValid.2.1
  have hBundleValid : kernelInterfaceBundle.Valid := hBundleSpec.2.1
  have hExpectedSteps :
      kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some bundle.confidential_slot_program.expectedRuntimeKernelSteps := hBundleSpec.2.2.1
  have hKernelSteps :
      kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        bundle.confidential_slot_program.expectedRuntimeKernelSteps := hBundleSpec.2.2.2
  let runtimeKernelInterfaceBundle := kernelInterfaceBundle.toRuntimeKernelInterfaceBundle
  have hRuntimeInterfaceValid : runtimeKernelInterfaceBundle.Valid := by
    exact importedRuntimeKernelInterfaceBundle_toRuntimeValid
      kernelInterfaceBundle hBundleValid
  rcases hRuntimeInterfaceValid with
    ⟨hShellValid, hKernelStateRefinement, hExpectedKernelStepsExact, hKernelStepsExact,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceStateExact,
      hExpectedKernelScheduleExact, hEmittedKernelScheduleExact,
      hFinalKernelScheduleStateExact⟩
  let runtimeExpectedKernelSchedule := Classical.choose hKernelStateRefinement
  have hKernelStateRefinementSpec := Classical.choose_spec hKernelStateRefinement
  rcases hKernelStateRefinementSpec with
    ⟨_hKernelWitnessProofGrade, _hRefinementValid,
      _hResourceStateExactFromRefinement, hExpectedKernelScheduleExactFromRefinement,
      _hEmittedKernelScheduleExactFromRefinement, _hFinalKernelScheduleStateExactFromRefinement,
      hProjectedKernelScheduleExact, hPreCommittedColdObjectScheduleExact,
      hPostCommittedColdObjectScheduleExact, hShadowLoadObjectScheduleExact,
      hCommitObjectScheduleExact, hColdStoreObjectScheduleExact⟩
  have hImportedBundleExpectedSteps :
      kernelInterfaceBundle.expected_kernel_steps =
        bundle.confidential_slot_program.expectedRuntimeKernelSteps := by
    apply Option.some.inj
    calc
      some kernelInterfaceBundle.expected_kernel_steps =
          kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps := by
            symm
            exact hBundleValid.2.2.1
      _ = some bundle.confidential_slot_program.expectedRuntimeKernelSteps := hExpectedSteps
  have hRuntimeBundleExpectedSteps :
      runtimeKernelInterfaceBundle.expectedKernelSteps =
        bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    simpa [runtimeKernelInterfaceBundle,
      ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram,
      importedConfidentialKernelSlotProgram_expectedRuntimeKernelSteps_toRuntime] using
      congrArg (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep)
        hImportedBundleExpectedSteps
  refine
    { runtimeKernelBoundary :=
        { kernelWitness := runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness
        , runtimeKernelRefinementWitness :=
            runtimeKernelInterfaceBundle.shellBoundaryBundle.runtimeKernelRefinementWitness
        , expectedKernelSchedule := runtimeKernelInterfaceBundle.expectedKernelSchedule
        , kernelWitnessProofGrade := hShellValid.1
        , refinementValid := hShellValid.2.1
        , resourceStateExact := hResourceStateExact
        , expectedKernelScheduleExact := hExpectedKernelScheduleExact
        , emittedKernelScheduleExact := hEmittedKernelScheduleExact
        , finalKernelScheduleStateExact := hFinalKernelScheduleStateExact
        , projectedKernelScheduleExact := hProjectedKernelScheduleExact
        , preCommittedColdObjectScheduleExact := hPreCommittedColdObjectScheduleExact
        , postCommittedColdObjectScheduleExact := hPostCommittedColdObjectScheduleExact
        , shadowLoadObjectScheduleExact := hShadowLoadObjectScheduleExact
        , commitObjectScheduleExact := hCommitObjectScheduleExact
        , coldStoreObjectScheduleExact := hColdStoreObjectScheduleExact
        }
    , confidentialSlotProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
    , runtimeNormalForm := hRuntimeNormalForm
    , expectedKernelStepsExact := ?_
    , emittedKernelStepsExact := ?_
    }
  · simpa [hRuntimeBundleExpectedSteps] using hExpectedKernelStepsExact
  · simpa [hRuntimeBundleExpectedSteps] using hKernelStepsExact

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_refinesLeanKernelState
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.toRefinesLeanKernelState boundary

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid ∧
      runtimeKernelInterfaceBundle.expectedKernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
        some boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  intro boundary
  refine
    ⟨boundary.kernelInterfaceBundle, boundary.kernelInterfaceBundle_valid, ?_, ?_, ?_⟩
  · simp [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle]
  · simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
      boundary.expectedKernelStepsExact
  · simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
      boundary.emittedKernelStepsExact

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeShellBoundaryBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.shellBoundaryBundle_valid boundary

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeKernelConfinementBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelInterfaceSlotBoundary :=
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelInterfaceSlotBoundary

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelInterfaceSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelInterfaceSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

def parseImportedRuntimeConfidentialCoreKernelFinishSlotBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreKernelFinishSlotBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeConfidentialCoreKernelFinishSlotBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreKernelFinishSlotBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreKernelFinishSlotBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core kernel-finish slot bundle does not satisfy Lean validity checks"

def loadImportedRuntimeConfidentialCoreKernelFinishSlotBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreKernelFinishSlotBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreKernelFinishSlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential-core kernel-finish slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelFinishSlotBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreKernelFinishSlotBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeConfidentialCoreKernelFinishSlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core kernel-finish slot bundle: {err}"

noncomputable def
  loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelFinishSlotBundleToRuntimeBoundary
  (path : System.FilePath) : IO RuntimeKernelFinishSlotBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreKernelFinishSlotBundle input with
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential-core kernel-finish slot bundle: {err}"
  | .ok bundle =>
      if hCheck : bundle.checkValid then
        pure <| bundle.toRuntimeKernelFinishSlotBoundary
          ((importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff bundle).mp
            hCheck)
      else
        throw <| IO.userError
          "failed to validate proof-grade runtime confidential-core kernel-finish slot bundle: imported proof-grade runtime confidential-core kernel-finish slot bundle does not satisfy Lean validity checks"

end UOToolchain
