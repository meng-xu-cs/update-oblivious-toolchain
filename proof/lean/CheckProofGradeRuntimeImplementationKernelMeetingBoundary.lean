import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationKernelMeetingBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationKernelMeetingBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  let confinementBoundary := runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationKernelMeetingBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundarySharedKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingBoundary_toRuntimeSharedKernelConfinement
      boundary hValid

theorem importedBoundarySmallKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingBoundary_valid_smallKernelConfinement
      hValid

theorem importedBoundaryBridgeConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.ConfidentialStatementTraceBridgeBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingBoundary_valid_bridgeConfinement
      hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationKernelMeetingBoundary_valid_handwrittenRuntimePublicOnly
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationKernelMeetingBoundary path
      IO.println
        s!"validated runtime implementation kernel meeting boundary for {boundary.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
