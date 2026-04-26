import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationSharedKernelMachineRefinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundarySharedKernelConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationSharedKernelMachineRefinementBoundary_toRuntimeSharedKernelConfinement
      boundary hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryMachineFinishScheduleConsumed
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_machine_finish_schedule_consumed
    hValid

theorem importedBoundaryMachineFinishKernelStepBudgetRespected
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
    hValid

theorem importedBoundaryMachineFinishRuntimePhaseBudgetRespected
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
    hValid

theorem importedBoundarySlotSemanticsExact
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_slot_semantics_exact
    hValid

theorem importedBoundaryNativeMachineRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
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
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_native_machine_refinement
    hValid

theorem importedBoundaryPaperSlotAdapterMachineRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
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
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paper_slot_adapter_machine_refinement
    hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
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
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
    hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
    hValid

theorem importedBoundaryPaperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
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
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell
    hValid

theorem importedBoundaryPaperSharedKernelMachineObserverRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperSharedKernelMachineObserverRefinement
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationSharedKernelMachineRefinementBoundary
          path
      IO.println
        s!"validated runtime implementation shared-kernel machine refinement boundary for {boundary.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
