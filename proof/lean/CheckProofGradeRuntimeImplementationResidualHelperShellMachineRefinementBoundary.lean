import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationResidualHelperShellMachineRefinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_toRuntimeResidualHelperShellConfinement
      boundary hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryMachineFinishScheduleConsumed
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_machine_finish_schedule_consumed
    hValid

theorem importedBoundaryMachineFinishKernelStepBudgetRespected
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
    hValid

theorem importedBoundaryMachineFinishRuntimePhaseBudgetRespected
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
    hValid

theorem importedBoundarySlotSemanticsExact
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_slot_semantics_exact
    hValid

theorem importedBoundaryNativeMachineRefinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
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
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_native_machine_refinement
    hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
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
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
    hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary
          path
      IO.println
        s!"validated runtime implementation residual helper-shell machine refinement boundary for {boundary.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
