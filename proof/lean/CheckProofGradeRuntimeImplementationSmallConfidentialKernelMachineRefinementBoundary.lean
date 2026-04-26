import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundarySmallKernelConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_toRuntimeSmallKernelConfinement
      boundary hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryMachineFinishScheduleConsumed
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_machine_finish_schedule_consumed
    hValid

theorem importedBoundaryMachineFinishKernelStepBudgetRespected
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
    hValid

theorem importedBoundaryMachineFinishRuntimePhaseBudgetRespected
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
    hValid

theorem importedBoundarySlotSemanticsExact
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_slot_semantics_exact
    hValid

theorem importedBoundaryNativeMachineRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary ∧
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
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_native_machine_refinement
    hValid

theorem importedBoundaryPaperSlotAdapterMachineRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
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
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paper_slot_adapter_machine_refinement
    hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
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
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
    hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
    hValid

theorem importedBoundaryPaperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary ∧
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
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell
    hValid

theorem importedBoundaryPaperSmallKernelMachineObserverRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperSmallKernelMachineObserverRefinement
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
          path
      IO.println
        s!"validated runtime implementation small confidential-kernel machine refinement boundary for {boundary.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
