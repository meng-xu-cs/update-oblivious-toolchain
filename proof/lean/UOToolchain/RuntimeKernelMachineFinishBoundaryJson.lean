import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreKernelFinishSlotJson
import UOToolchain.RuntimeKernelMachineFinishWitnessJson

open Lean

namespace UOToolchain

def importedRuntimeKernelMachineFinishBoundaryFieldNames : List String :=
  [ "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

/--
Imported proof-grade runtime kernel machine-finish boundary. This is the
standalone emitted artifact that pairs the live `RuntimeKernelMachine` finish
witness with the fixed confidential slot program / opcode trace before that
closer-to-implementation state is embedded in the larger source-backed runtime
implementation boundary.
-/
structure ImportedRuntimeKernelMachineFinishBoundary where
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle
  (boundary : ImportedRuntimeKernelMachineFinishBoundary) :
  ImportedRuntimeConfidentialCoreKernelFinishSlotBundle :=
  { runtime_kernel_finish_bundle :=
      boundary.runtime_kernel_machine_finish_witness.projectedFinishBundle
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeKernelMachineFinishBoundary.Valid
  (boundary : ImportedRuntimeKernelMachineFinishBoundary) : Prop :=
  boundary.runtime_kernel_machine_finish_witness.Valid ∧
    boundary.projectedKernelFinishSlotBundle.Valid

def ImportedRuntimeKernelMachineFinishBoundary.checkValid
  (boundary : ImportedRuntimeKernelMachineFinishBoundary) : Bool :=
  boundary.runtime_kernel_machine_finish_witness.checkValid &&
    boundary.projectedKernelFinishSlotBundle.checkValid

@[simp] theorem importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeKernelMachineFinishBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeKernelMachineFinishBoundary.checkValid
    ImportedRuntimeKernelMachineFinishBoundary.Valid
    ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle
  simp [importedRuntimeKernelMachineFinishWitness_checkValid_eq_true_iff,
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff]

noncomputable def ImportedRuntimeKernelMachineFinishBoundary.toRuntimeKernelFinishSlotBoundary
  (boundary : ImportedRuntimeKernelMachineFinishBoundary)
  (hValid : boundary.Valid) :
  RuntimeKernelFinishSlotBoundary :=
  boundary.projectedKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary hValid.2

noncomputable def ImportedRuntimeKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary
  (boundary : ImportedRuntimeKernelMachineFinishBoundary)
  (hValid : boundary.Valid) :
  RuntimeKernelMachineFinishBoundary := by
  let runtimeKernelFinishSlotBoundary :=
    boundary.projectedKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary hValid.2
  have hExpectedKernelStepsExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_expectedKernelSteps_exact
      (bundle := boundary.projectedKernelFinishSlotBundle)
      hValid.2
  have hKernelStepsExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_kernelSteps_exact
      (bundle := boundary.projectedKernelFinishSlotBundle)
      hValid.2
  have hPublicObjectIdsExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_publicObjectIds_exact
      (bundle := boundary.projectedKernelFinishSlotBundle)
      hValid.2
  have hEventsLengthExact :=
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_events_length_exact
      (bundle := boundary.projectedKernelFinishSlotBundle)
      hValid.2
  have hExpectedKernelScheduleConsumed :
      match runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps =>
          boundary.runtime_kernel_machine_finish_witness.expected_kernel_step_index = steps.length
      | none =>
          boundary.runtime_kernel_machine_finish_witness.expected_kernel_step_index = 0 := by
    rw [hExpectedKernelStepsExact]
    cases hExpected : boundary.runtime_kernel_machine_finish_witness.expected_kernel_steps with
    | none =>
        simpa [ImportedRuntimeKernelMachineFinishWitness.expectedKernelScheduleConsumed,
          ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle,
          ImportedRuntimeKernelMachineFinishWitness.projectedFinishBundle, hExpected] using
          hValid.1.2.1
    | some steps =>
        simpa [ImportedRuntimeKernelMachineFinishWitness.expectedKernelScheduleConsumed,
          ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle,
          ImportedRuntimeKernelMachineFinishWitness.projectedFinishBundle, hExpected,
          List.length_map] using hValid.1.2.1
  have hKernelStepBudgetRespected :
      runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
        boundary.runtime_kernel_machine_finish_witness.max_kernel_ops := by
    rw [hKernelStepsExact]
    simpa [ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle,
      ImportedRuntimeKernelMachineFinishWitness.projectedFinishBundle,
      ImportedRuntimeKernelMachineFinishWitness.kernelStepBudgetRespected,
      List.length_map] using hValid.1.2.2.1
  have hRuntimePhaseEventCapacityMatches :
      boundary.runtime_kernel_machine_finish_witness.max_runtime_phase_event_count =
        runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.publicObjectIds.length * 5 +
          boundary.runtime_kernel_machine_finish_witness.max_kernel_ops := by
    rw [hPublicObjectIdsExact]
    simpa [ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle,
      ImportedRuntimeKernelMachineFinishWitness.projectedFinishBundle,
      ImportedRuntimeKernelMachineFinishWitness.runtimePhaseEventCapacityMatches] using
      hValid.1.2.2.2.1
  have hRuntimePhaseEventCapacityRespected :
      runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
        boundary.runtime_kernel_machine_finish_witness.max_runtime_phase_event_count := by
    rw [hEventsLengthExact]
    simpa [ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle,
      ImportedRuntimeKernelMachineFinishWitness.projectedFinishBundle,
      ImportedRuntimeKernelMachineFinishWitness.completedRuntimePhaseEventCapacityRespected] using
      hValid.1.2.2.2.2.2
  exact
    { runtimeKernelFinishSlotBoundary := runtimeKernelFinishSlotBoundary
    , expectedKernelStepIndex := boundary.runtime_kernel_machine_finish_witness.expected_kernel_step_index
    , maxKernelOps := boundary.runtime_kernel_machine_finish_witness.max_kernel_ops
    , maxRuntimePhaseEventCount := boundary.runtime_kernel_machine_finish_witness.max_runtime_phase_event_count
    , expectedKernelScheduleConsumed := hExpectedKernelScheduleConsumed
    , kernelStepBudgetRespected := hKernelStepBudgetRespected
    , runtimePhaseEventCapacityMatches := hRuntimePhaseEventCapacityMatches
    , runtimePhaseEventCapacityRespected := hRuntimePhaseEventCapacityRespected
    }

theorem
  importedRuntimeKernelMachineFinishBoundary_toRuntimeKernelMachineFinishBoundary_runtimeKernelFinishSlotBoundary_exact
  {boundary : ImportedRuntimeKernelMachineFinishBoundary}
  (hValid : boundary.Valid) :
  (boundary.toRuntimeKernelMachineFinishBoundary hValid).runtimeKernelFinishSlotBoundary =
    boundary.projectedKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary hValid.2 := by
  rfl

theorem importedRuntimeKernelMachineFinishBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeKernelMachineFinishBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeKernelMachineFinishBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeKernelMachineFinishBoundary.toRefinesLeanKernelState
      (boundary.toRuntimeKernelMachineFinishBoundary hValid)

theorem importedRuntimeKernelMachineFinishBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeKernelMachineFinishBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeKernelMachineFinishBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeKernelMachineFinishBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeKernelMachineFinishBoundary hValid)

def parseImportedRuntimeKernelMachineFinishBoundary
  (input : String) : Except String ImportedRuntimeKernelMachineFinishBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeKernelMachineFinishBoundary
  (input : String) : Except String ImportedRuntimeKernelMachineFinishBoundary := do
  let boundary ← parseImportedRuntimeKernelMachineFinishBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime kernel machine finish boundary does not satisfy Lean validity checks"

def loadImportedRuntimeKernelMachineFinishBoundary
  (path : System.FilePath) : IO ImportedRuntimeKernelMachineFinishBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelMachineFinishBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime kernel machine finish boundary: {err}"

def loadAndCheckImportedRuntimeKernelMachineFinishBoundary
  (path : System.FilePath) : IO ImportedRuntimeKernelMachineFinishBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeKernelMachineFinishBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime kernel machine finish boundary: {err}"

end UOToolchain
