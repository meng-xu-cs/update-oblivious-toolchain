import Lean.Data.Json
import UOToolchain.RuntimeKernelFinishBundleJson

open Lean

namespace UOToolchain

def importedRuntimeKernelMachineFinishWitnessFieldNames : List String :=
  [ "entrypoint_id"
  , "arena_bytes"
  , "max_stack_words"
  , "scratch_bytes"
  , "peak_stack_words"
  , "value_scratch_peak_bytes"
  , "value_scratch_live_bytes_end"
  , "value_scratch_wipe_count"
  , "hash_scratch_peak_bytes"
  , "hash_scratch_live_bytes_end"
  , "hash_scratch_wipe_count"
  , "io_scratch_peak_bytes"
  , "io_scratch_live_bytes_end"
  , "io_scratch_wipe_count"
  , "resource_events"
  , "expected_kernel_steps"
  , "expected_kernel_step_index"
  , "public_object_ids"
  , "expected_public_object_ids"
  , "kernel_steps"
  , "max_kernel_ops"
  , "max_runtime_phase_event_count"
  , "runtime_phase_events_before_finish"
  ]

/--
Imported proof-grade runtime kernel machine-finish witness. This is the closer-
to-implementation shared-kernel finish state emitted directly from the live
`RuntimeKernelMachine` before the machine state is flattened to the smaller
runtime-kernel finish bundle.
-/
structure ImportedRuntimeKernelMachineFinishWitness where
  entrypoint_id : String
  arena_bytes : Nat
  max_stack_words : Nat
  scratch_bytes : Nat
  peak_stack_words : Nat
  value_scratch_peak_bytes : Nat
  value_scratch_live_bytes_end : Nat
  value_scratch_wipe_count : Nat
  hash_scratch_peak_bytes : Nat
  hash_scratch_live_bytes_end : Nat
  hash_scratch_wipe_count : Nat
  io_scratch_peak_bytes : Nat
  io_scratch_live_bytes_end : Nat
  io_scratch_wipe_count : Nat
  resource_events : List ImportedRuntimeKernelResourceEvent
  expected_kernel_steps : Option (List ImportedRuntimeKernelStep)
  expected_kernel_step_index : Nat
  public_object_ids : List Nat
  expected_public_object_ids : Option (List Nat)
  kernel_steps : List ImportedRuntimeKernelStep
  max_kernel_ops : Nat
  max_runtime_phase_event_count : Nat
  runtime_phase_events_before_finish : List ImportedRuntimeKernelRefinementEvent
deriving Repr, DecidableEq, ToJson

instance : FromJson ImportedRuntimeKernelMachineFinishWitness where
  fromJson? json := do
    jsonRequireExactFields json importedRuntimeKernelMachineFinishWitnessFieldNames
    pure
      { entrypoint_id := ← jsonLookupFieldAs json "entrypoint_id"
      , arena_bytes := ← jsonLookupFieldAs json "arena_bytes"
      , max_stack_words := ← jsonLookupFieldAs json "max_stack_words"
      , scratch_bytes := ← jsonLookupFieldAs json "scratch_bytes"
      , peak_stack_words := ← jsonLookupFieldAs json "peak_stack_words"
      , value_scratch_peak_bytes := ← jsonLookupFieldAs json "value_scratch_peak_bytes"
      , value_scratch_live_bytes_end :=
          ← jsonLookupFieldAs json "value_scratch_live_bytes_end"
      , value_scratch_wipe_count := ← jsonLookupFieldAs json "value_scratch_wipe_count"
      , hash_scratch_peak_bytes := ← jsonLookupFieldAs json "hash_scratch_peak_bytes"
      , hash_scratch_live_bytes_end :=
          ← jsonLookupFieldAs json "hash_scratch_live_bytes_end"
      , hash_scratch_wipe_count := ← jsonLookupFieldAs json "hash_scratch_wipe_count"
      , io_scratch_peak_bytes := ← jsonLookupFieldAs json "io_scratch_peak_bytes"
      , io_scratch_live_bytes_end := ← jsonLookupFieldAs json "io_scratch_live_bytes_end"
      , io_scratch_wipe_count := ← jsonLookupFieldAs json "io_scratch_wipe_count"
      , resource_events := ← jsonLookupResourceEvents json "resource_events"
      , expected_kernel_steps :=
          ← jsonLookupExplicitOptionFieldAs json "expected_kernel_steps"
      , expected_kernel_step_index := ← jsonLookupFieldAs json "expected_kernel_step_index"
      , public_object_ids := ← jsonLookupFieldAs json "public_object_ids"
      , expected_public_object_ids :=
          ← jsonLookupExplicitOptionFieldAs json "expected_public_object_ids"
      , kernel_steps := ← jsonLookupFieldAs json "kernel_steps"
      , max_kernel_ops := ← jsonLookupFieldAs json "max_kernel_ops"
      , max_runtime_phase_event_count :=
          ← jsonLookupFieldAs json "max_runtime_phase_event_count"
      , runtime_phase_events_before_finish :=
          ← jsonLookupFieldAs json "runtime_phase_events_before_finish"
      }

def ImportedRuntimeKernelMachineFinishWitness.projectedFinishBundle
  (witness : ImportedRuntimeKernelMachineFinishWitness) : ImportedRuntimeKernelFinishBundle :=
  { entrypoint_id := witness.entrypoint_id
  , arena_bytes := witness.arena_bytes
  , max_stack_words := witness.max_stack_words
  , scratch_bytes := witness.scratch_bytes
  , peak_stack_words := witness.peak_stack_words
  , value_scratch_peak_bytes := witness.value_scratch_peak_bytes
  , value_scratch_live_bytes_end := witness.value_scratch_live_bytes_end
  , value_scratch_wipe_count := witness.value_scratch_wipe_count
  , hash_scratch_peak_bytes := witness.hash_scratch_peak_bytes
  , hash_scratch_live_bytes_end := witness.hash_scratch_live_bytes_end
  , hash_scratch_wipe_count := witness.hash_scratch_wipe_count
  , io_scratch_peak_bytes := witness.io_scratch_peak_bytes
  , io_scratch_live_bytes_end := witness.io_scratch_live_bytes_end
  , io_scratch_wipe_count := witness.io_scratch_wipe_count
  , resource_events := witness.resource_events
  , expected_kernel_steps := witness.expected_kernel_steps
  , public_object_ids := witness.public_object_ids
  , expected_public_object_ids := witness.expected_public_object_ids
  , kernel_steps := witness.kernel_steps
  , runtime_phase_events_before_finish := witness.runtime_phase_events_before_finish
  }

def ImportedRuntimeKernelMachineFinishWitness.expectedKernelScheduleConsumed
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Prop :=
  match witness.expected_kernel_steps with
  | some steps => witness.expected_kernel_step_index = steps.length
  | none => witness.expected_kernel_step_index = 0

def ImportedRuntimeKernelMachineFinishWitness.checkExpectedKernelScheduleConsumed
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Bool :=
  match witness.expected_kernel_steps with
  | some steps => decide (witness.expected_kernel_step_index = steps.length)
  | none => decide (witness.expected_kernel_step_index = 0)

@[simp] theorem importedRuntimeKernelMachineFinishWitness_checkExpectedKernelScheduleConsumed_eq_true_iff
  (witness : ImportedRuntimeKernelMachineFinishWitness) :
  witness.checkExpectedKernelScheduleConsumed = true ↔
    witness.expectedKernelScheduleConsumed := by
  unfold ImportedRuntimeKernelMachineFinishWitness.checkExpectedKernelScheduleConsumed
    ImportedRuntimeKernelMachineFinishWitness.expectedKernelScheduleConsumed
  cases witness.expected_kernel_steps <;> simp

def ImportedRuntimeKernelMachineFinishWitness.kernelStepBudgetRespected
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Prop :=
  witness.kernel_steps.length ≤ witness.max_kernel_ops

def ImportedRuntimeKernelMachineFinishWitness.checkKernelStepBudgetRespected
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Bool :=
  decide (witness.kernel_steps.length ≤ witness.max_kernel_ops)

@[simp] theorem importedRuntimeKernelMachineFinishWitness_checkKernelStepBudgetRespected_eq_true_iff
  (witness : ImportedRuntimeKernelMachineFinishWitness) :
  witness.checkKernelStepBudgetRespected = true ↔
    witness.kernelStepBudgetRespected := by
  unfold ImportedRuntimeKernelMachineFinishWitness.checkKernelStepBudgetRespected
    ImportedRuntimeKernelMachineFinishWitness.kernelStepBudgetRespected
  simp

def ImportedRuntimeKernelMachineFinishWitness.runtimePhaseEventCapacityMatches
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Prop :=
  witness.max_runtime_phase_event_count =
    witness.public_object_ids.length * 5 + witness.max_kernel_ops

def ImportedRuntimeKernelMachineFinishWitness.checkRuntimePhaseEventCapacityMatches
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Bool :=
  decide
    (witness.max_runtime_phase_event_count =
      witness.public_object_ids.length * 5 + witness.max_kernel_ops)

@[simp] theorem importedRuntimeKernelMachineFinishWitness_checkRuntimePhaseEventCapacityMatches_eq_true_iff
  (witness : ImportedRuntimeKernelMachineFinishWitness) :
  witness.checkRuntimePhaseEventCapacityMatches = true ↔
    witness.runtimePhaseEventCapacityMatches := by
  unfold ImportedRuntimeKernelMachineFinishWitness.checkRuntimePhaseEventCapacityMatches
    ImportedRuntimeKernelMachineFinishWitness.runtimePhaseEventCapacityMatches
  simp

def ImportedRuntimeKernelMachineFinishWitness.runtimePhaseEventCapacityRespected
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Prop :=
  witness.runtime_phase_events_before_finish.length ≤
    witness.max_runtime_phase_event_count

def ImportedRuntimeKernelMachineFinishWitness.completedRuntimePhaseEventCapacityRespected
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Prop :=
  witness.projectedFinishBundle.completedRuntimePhaseEvents.length ≤
    witness.max_runtime_phase_event_count

def ImportedRuntimeKernelMachineFinishWitness.checkRuntimePhaseEventCapacityRespected
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Bool :=
  decide
    (witness.runtime_phase_events_before_finish.length ≤
      witness.max_runtime_phase_event_count)

def ImportedRuntimeKernelMachineFinishWitness.checkCompletedRuntimePhaseEventCapacityRespected
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Bool :=
  decide
    (witness.projectedFinishBundle.completedRuntimePhaseEvents.length ≤
      witness.max_runtime_phase_event_count)

@[simp] theorem importedRuntimeKernelMachineFinishWitness_checkRuntimePhaseEventCapacityRespected_eq_true_iff
  (witness : ImportedRuntimeKernelMachineFinishWitness) :
  witness.checkRuntimePhaseEventCapacityRespected = true ↔
    witness.runtimePhaseEventCapacityRespected := by
  unfold ImportedRuntimeKernelMachineFinishWitness.checkRuntimePhaseEventCapacityRespected
    ImportedRuntimeKernelMachineFinishWitness.runtimePhaseEventCapacityRespected
  simp

@[simp] theorem
  importedRuntimeKernelMachineFinishWitness_checkCompletedRuntimePhaseEventCapacityRespected_eq_true_iff
  (witness : ImportedRuntimeKernelMachineFinishWitness) :
  witness.checkCompletedRuntimePhaseEventCapacityRespected = true ↔
    witness.completedRuntimePhaseEventCapacityRespected := by
  unfold ImportedRuntimeKernelMachineFinishWitness.checkCompletedRuntimePhaseEventCapacityRespected
    ImportedRuntimeKernelMachineFinishWitness.completedRuntimePhaseEventCapacityRespected
  simp

def ImportedRuntimeKernelMachineFinishWitness.Valid
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Prop :=
  witness.projectedFinishBundle.Valid ∧
    witness.expectedKernelScheduleConsumed ∧
    witness.kernelStepBudgetRespected ∧
    witness.runtimePhaseEventCapacityMatches ∧
    witness.runtimePhaseEventCapacityRespected ∧
    witness.completedRuntimePhaseEventCapacityRespected

def ImportedRuntimeKernelMachineFinishWitness.checkValid
  (witness : ImportedRuntimeKernelMachineFinishWitness) : Bool :=
  witness.projectedFinishBundle.checkValid &&
    witness.checkExpectedKernelScheduleConsumed &&
    witness.checkKernelStepBudgetRespected &&
    witness.checkRuntimePhaseEventCapacityMatches &&
    witness.checkRuntimePhaseEventCapacityRespected &&
    witness.checkCompletedRuntimePhaseEventCapacityRespected

@[simp] theorem importedRuntimeKernelMachineFinishWitness_checkValid_eq_true_iff
  (witness : ImportedRuntimeKernelMachineFinishWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  unfold ImportedRuntimeKernelMachineFinishWitness.checkValid
    ImportedRuntimeKernelMachineFinishWitness.Valid
  simp [importedRuntimeKernelFinishBundle_checkValid_eq_true_iff, and_assoc]

theorem importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeKernelRefinementBoundary
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (witness.projectedFinishBundle.toRuntimeKernelRefinementBoundary hValid.1).runtimeKernelRefinementWitness
      (witness.projectedFinishBundle.toRuntimeKernelRefinementBoundary hValid.1).kernelWitness := by
  exact
    importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelRefinementBoundary
      hValid.1

theorem importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeKernelConfinementBoundary
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  let boundary := witness.projectedFinishBundle.toRuntimeKernelConfinementBoundary hValid.1
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelConfinementBoundary
      hValid.1

theorem importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeKernelInterfaceBundle
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid := by
  exact
    importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelInterfaceBundle
      hValid.1

theorem importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeShellBoundaryBundle
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  ∃ shellBoundaryBundle : RuntimeShellBoundaryBundle,
    shellBoundaryBundle.Valid := by
  exact
    importedRuntimeKernelFinishBundle_valid_projects_to_runtimeShellBoundaryBundle
      hValid.1

def parseImportedRuntimeKernelMachineFinishWitness
  (input : String) : Except String ImportedRuntimeKernelMachineFinishWitness := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeKernelMachineFinishWitness
  (input : String) : Except String ImportedRuntimeKernelMachineFinishWitness := do
  let witness ← parseImportedRuntimeKernelMachineFinishWitness input
  if witness.checkValid then
    pure witness
  else
    throw
      "imported runtime kernel machine finish witness does not satisfy Lean validity checks"

def loadImportedRuntimeKernelMachineFinishWitness
  (path : System.FilePath) : IO ImportedRuntimeKernelMachineFinishWitness := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelMachineFinishWitness input with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime kernel machine finish witness: {err}"

def loadAndCheckImportedRuntimeKernelMachineFinishWitness
  (path : System.FilePath) : IO ImportedRuntimeKernelMachineFinishWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeKernelMachineFinishWitness input with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime kernel machine finish witness: {err}"

end UOToolchain
