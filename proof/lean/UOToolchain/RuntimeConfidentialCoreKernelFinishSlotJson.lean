import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssurance
import UOToolchain.RuntimeKernelDslJson
import UOToolchain.RuntimeKernelFinishBundleJson

open Lean

namespace UOToolchain

def importedRuntimeConfidentialCoreKernelFinishSlotBundleFieldNames : List String :=
  ["runtime_kernel_finish_bundle", "confidential_slot_program", "opcode_trace"]

structure ImportedRuntimeConfidentialCoreKernelFinishSlotBundle where
  runtime_kernel_finish_bundle : ImportedRuntimeKernelFinishBundle
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

theorem importedRuntimeConfidentialCoreKernelFinishSlotBundle_eq_of_fields_eq
  {bundle1 bundle2 : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hFinishBundle :
    bundle1.runtime_kernel_finish_bundle = bundle2.runtime_kernel_finish_bundle)
  (hProgram :
    bundle1.confidential_slot_program = bundle2.confidential_slot_program)
  (hTrace : bundle1.opcode_trace = bundle2.opcode_trace) :
  bundle1 = bundle2 := by
  cases bundle1
  cases bundle2
  cases hFinishBundle
  cases hProgram
  cases hTrace
  rfl

def ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle) : Prop :=
  bundle.runtime_kernel_finish_bundle.Valid ∧
    bundle.confidential_slot_program.RuntimeNormalForm ∧
    bundle.opcode_trace = bundle.confidential_slot_program.statementTraceNames ∧
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
    decide (bundle.opcode_trace = bundle.confidential_slot_program.statementTraceNames) &&
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
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.importedKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : ImportedRuntimeKernelInterfaceBundle :=
  Classical.choose hValid.2.2.2

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_spec
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  bundle.runtime_kernel_finish_bundle.kernelInterfaceBundle? =
      some (bundle.importedKernelInterfaceBundle hValid) ∧
    (bundle.importedKernelInterfaceBundle hValid).Valid ∧
    (bundle.importedKernelInterfaceBundle hValid).shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
    (bundle.importedKernelInterfaceBundle hValid).shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_slot_program.expectedRuntimeKernelSteps := by
  exact Classical.choose_spec hValid.2.2.2

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_eq_finishBundleChoice
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  bundle.importedKernelInterfaceBundle hValid =
    Classical.choose hValid.1 := by
  have hSlotSpec :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_spec
      hValid
  have hFinishSpec := Classical.choose_spec hValid.1
  apply Option.some.inj
  calc
    some (bundle.importedKernelInterfaceBundle hValid) =
        bundle.runtime_kernel_finish_bundle.kernelInterfaceBundle? := by
          symm
          exact hSlotSpec.1
    _ = some (Classical.choose hValid.1) := hFinishSpec.1

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelInterfaceBundle :=
  (bundle.importedKernelInterfaceBundle hValid).toRuntimeKernelInterfaceBundle

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelInterfaceBundle hValid).Valid := by
  exact importedRuntimeKernelInterfaceBundle_toRuntimeValid
    (bundle.importedKernelInterfaceBundle hValid)
    (importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_spec
      hValid).2.1

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelWitness
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelWitness :=
  (bundle.toRuntimeKernelInterfaceBundle hValid).shellBoundaryBundle.kernelWitness

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelRefinementWitness
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelRefinementWitness :=
  (bundle.toRuntimeKernelInterfaceBundle hValid).shellBoundaryBundle.runtimeKernelRefinementWitness

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeExpectedKernelSchedule
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelSchedule :=
  (bundle.toRuntimeKernelInterfaceBundle hValid).expectedKernelSchedule

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelRefinementBoundary :=
  (bundle.toRuntimeKernelInterfaceBundle hValid).refinementBoundary
    (importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
      hValid)

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_expectedKernelSteps_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelBoundary hValid).kernelWitness.expectedKernelSteps =
    some bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
  let kernelInterfaceBundle := bundle.importedKernelInterfaceBundle hValid
  have hBundleSpec :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_spec
      hValid
  have hBundleValid : kernelInterfaceBundle.Valid := hBundleSpec.2.1
  have hExpectedSteps :
      kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some bundle.confidential_slot_program.expectedRuntimeKernelSteps := hBundleSpec.2.2.1
  let runtimeKernelInterfaceBundle := bundle.toRuntimeKernelInterfaceBundle hValid
  have hRuntimeInterfaceValid : runtimeKernelInterfaceBundle.Valid := by
    exact
      importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
        hValid
  rcases hRuntimeInterfaceValid with
    ⟨hShellValid, hKernelStateRefinement, hExpectedKernelStepsExact, hKernelStepsExact,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceStateExact,
      hExpectedKernelScheduleExact, hEmittedKernelScheduleExact,
      hFinalKernelScheduleStateExact⟩
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
  let runtimeKernelBoundary := bundle.toRuntimeKernelBoundary hValid
  have hRuntimeKernelBoundaryWitnessExact :
      runtimeKernelBoundary.kernelWitness = bundle.toRuntimeKernelWitness hValid := by
    simpa [runtimeKernelBoundary,
      ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelBoundary,
      ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelWitness] using
      runtimeKernelInterfaceBundle_refinementBoundary_kernelWitness_exact
        (bundle := runtimeKernelInterfaceBundle)
        (importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
          hValid)
  have hBoundaryExpectedKernelStepsExact :
      runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    simpa [runtimeKernelBoundary, hRuntimeKernelBoundaryWitnessExact, hRuntimeBundleExpectedSteps] using
      hExpectedKernelStepsExact
  simpa [runtimeKernelBoundary] using hBoundaryExpectedKernelStepsExact

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_emittedKernelSteps_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelBoundary hValid).kernelWitness.kernelSteps =
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
  let kernelInterfaceBundle := bundle.importedKernelInterfaceBundle hValid
  have hBundleSpec :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_spec
      hValid
  have hBundleValid : kernelInterfaceBundle.Valid := hBundleSpec.2.1
  have hExpectedSteps :
      kernelInterfaceBundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some bundle.confidential_slot_program.expectedRuntimeKernelSteps := hBundleSpec.2.2.1
  let runtimeKernelInterfaceBundle := bundle.toRuntimeKernelInterfaceBundle hValid
  have hRuntimeInterfaceValid : runtimeKernelInterfaceBundle.Valid := by
    exact
      importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
        hValid
  rcases hRuntimeInterfaceValid with
    ⟨hShellValid, hKernelStateRefinement, hExpectedKernelStepsExact, hKernelStepsExact,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceStateExact,
      hExpectedKernelScheduleExact, hEmittedKernelScheduleExact,
      hFinalKernelScheduleStateExact⟩
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
  let runtimeKernelBoundary := bundle.toRuntimeKernelBoundary hValid
  have hRuntimeKernelBoundaryWitnessExact :
      runtimeKernelBoundary.kernelWitness = bundle.toRuntimeKernelWitness hValid := by
    simpa [runtimeKernelBoundary,
      ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelBoundary,
      ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelWitness] using
      runtimeKernelInterfaceBundle_refinementBoundary_kernelWitness_exact
        (bundle := runtimeKernelInterfaceBundle)
        (importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
          hValid)
  simpa [runtimeKernelBoundary, hRuntimeKernelBoundaryWitnessExact, hRuntimeBundleExpectedSteps] using
    hKernelStepsExact

noncomputable def
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) : RuntimeKernelFinishSlotBoundary :=
  { runtimeKernelBoundary := bundle.toRuntimeKernelBoundary hValid
  , confidentialSlotProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
  , runtimeNormalForm := hValid.2.1
  , expectedKernelStepsExact :=
      importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_expectedKernelSteps_exact
        hValid
  , emittedKernelStepsExact :=
      importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_emittedKernelSteps_exact
        hValid
  }

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_congr
  {bundle1 bundle2 : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hEq : bundle1 = bundle2)
  {hValid1 : bundle1.Valid}
  {hValid2 : bundle2.Valid} :
  bundle1.toRuntimeKernelFinishSlotBoundary hValid1 =
    bundle2.toRuntimeKernelFinishSlotBoundary hValid2 := by
  cases hEq
  have hProof : HEq hValid1 hValid2 := by
    exact proof_irrel_heq _ _
  cases hProof
  rfl

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_kernelWitness_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelBoundary hValid).kernelWitness =
    bundle.toRuntimeKernelWitness hValid := by
  simpa [ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelBoundary,
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelWitness] using
    runtimeKernelInterfaceBundle_refinementBoundary_kernelWitness_exact
      (bundle := bundle.toRuntimeKernelInterfaceBundle hValid)
      (importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
        hValid)

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_runtimeKernelRefinementWitness_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelBoundary hValid).runtimeKernelRefinementWitness =
    bundle.toRuntimeKernelRefinementWitness hValid := by
  simpa [ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelBoundary,
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelRefinementWitness] using
    runtimeKernelInterfaceBundle_refinementBoundary_runtimeKernelRefinementWitness_exact
      (bundle := bundle.toRuntimeKernelInterfaceBundle hValid)
      (importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelInterfaceBundle_valid
        hValid)

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_kernelWitness_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.kernelWitness =
    bundle.toRuntimeKernelWitness hValid := by
  simpa [ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary] using
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_kernelWitness_exact
      hValid

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_runtimeKernelRefinementWitness_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.runtimeKernelRefinementWitness =
    bundle.toRuntimeKernelRefinementWitness hValid := by
  simpa [ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary] using
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelBoundary_runtimeKernelRefinementWitness_exact
      hValid

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelWitness_eq_finishBundleWitness
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  bundle.toRuntimeKernelWitness hValid =
    (bundle.runtime_kernel_finish_bundle.toRuntimeKernelInterfaceBundle hValid.1).shellBoundaryBundle.kernelWitness := by
  have hImportedKernelInterfaceBundleEq :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_eq_finishBundleChoice
      hValid
  simp [ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelWitness,
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelInterfaceBundle,
    ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle,
    hImportedKernelInterfaceBundleEq]

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelRefinementWitness_eq_finishBundleWitness
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  bundle.toRuntimeKernelRefinementWitness hValid =
    (bundle.runtime_kernel_finish_bundle.toRuntimeKernelInterfaceBundle hValid.1).shellBoundaryBundle.runtimeKernelRefinementWitness := by
  have hImportedKernelInterfaceBundleEq :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_importedKernelInterfaceBundle_eq_finishBundleChoice
      hValid
  simp [ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelRefinementWitness,
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle.toRuntimeKernelInterfaceBundle,
    ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle,
    hImportedKernelInterfaceBundleEq]

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_expectedKernelSteps_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
    bundle.runtime_kernel_finish_bundle.expected_kernel_steps.map
      (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep) := by
  have hKernelWitnessExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_kernelWitness_exact
      hValid
  have hKernelWitnessFinishBundleEq :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelWitness_eq_finishBundleWitness
      hValid
  have hFinishBundleExact :=
    importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_kernelWitness_exact
      (bundle := bundle.runtime_kernel_finish_bundle)
      hValid.1
  simpa [hKernelWitnessExact, hKernelWitnessFinishBundleEq] using
    congrArg RuntimeKernelWitness.expectedKernelSteps hFinishBundleExact

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_kernelSteps_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.kernelWitness.kernelSteps =
    bundle.runtime_kernel_finish_bundle.kernel_steps.map ImportedRuntimeKernelStep.toRuntimeKernelStep := by
  have hKernelWitnessExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_kernelWitness_exact
      hValid
  have hKernelWitnessFinishBundleEq :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelWitness_eq_finishBundleWitness
      hValid
  have hFinishBundleExact :=
    importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_kernelWitness_exact
      (bundle := bundle.runtime_kernel_finish_bundle)
      hValid.1
  simpa [hKernelWitnessExact, hKernelWitnessFinishBundleEq] using
    congrArg RuntimeKernelWitness.kernelSteps hFinishBundleExact

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_publicObjectIds_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.kernelWitness.publicObjectIds =
    bundle.runtime_kernel_finish_bundle.public_object_ids := by
  have hKernelWitnessExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_kernelWitness_exact
      hValid
  have hKernelWitnessFinishBundleEq :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelWitness_eq_finishBundleWitness
      hValid
  have hFinishBundleExact :=
    importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_kernelWitness_exact
      (bundle := bundle.runtime_kernel_finish_bundle)
      hValid.1
  simpa [hKernelWitnessExact, hKernelWitnessFinishBundleEq] using
    congrArg RuntimeKernelWitness.publicObjectIds hFinishBundleExact

theorem
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_events_length_exact
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length =
    bundle.runtime_kernel_finish_bundle.completedRuntimePhaseEvents.length := by
  have hBoundaryEventsLength :
      (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length =
        (bundle.toRuntimeKernelRefinementWitness hValid).events.length := by
    simpa [importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_runtimeKernelRefinementWitness_exact
      hValid]
  have hRuntimeRefinementFinishBundleEq :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelRefinementWitness_eq_finishBundleWitness
      hValid
  have hFinishBundleExact :=
    importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_runtimeKernelRefinementWitness_exact
      (bundle := bundle.runtime_kernel_finish_bundle)
      hValid.1
  have hFinishBundleEventsLength :
      (bundle.toRuntimeKernelRefinementWitness hValid).events.length =
        bundle.runtime_kernel_finish_bundle.completedRuntimePhaseEvents.length := by
    simpa [hRuntimeRefinementFinishBundleEq,
    ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness,
    ImportedRuntimeKernelFinishBundle.runtimeKernelRefinementWitness,
    List.length_map] using congrArg (fun witness => witness.events.length) hFinishBundleExact
  exact hBoundaryEventsLength.trans hFinishBundleEventsLength

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
