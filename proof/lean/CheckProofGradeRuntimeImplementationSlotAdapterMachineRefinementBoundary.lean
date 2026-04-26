import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationSlotAdapterMachineRefinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_toRuntimeSlotAdapterConfinement
      boundary hValid

theorem importedBoundaryMachineFinishScheduleConsumed
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_machine_finish_schedule_consumed
    hValid

theorem importedBoundaryMachineFinishKernelStepBudgetRespected
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
    hValid

theorem importedBoundaryMachineFinishRuntimePhaseBudgetRespected
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
    hValid

theorem importedBoundarySlotSemanticsExact
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_slot_semantics_exact
    hValid

theorem importedBoundaryNativeMachineRefinement
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_native_machine_refinement
    hValid

theorem importedBoundaryPaperSlotAdapterMachineRefinement
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_paper_slot_adapter_machine_refinement
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary
          path
      IO.println
        s!"validated runtime implementation slot-adapter machine refinement boundary for {boundary.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
