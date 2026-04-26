import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationKernelMeetingConfinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRuntimeImplementationConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  refine ⟨?_, ?_⟩
  · exact
      importedRuntimeImplementationKernelMeetingConfinementBoundary_toRuntimeImplementationConfinement
        boundary hValid
  · exact
      importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
        hValid

theorem importedBoundarySharedKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_sharedKernelConfinement
      hValid

theorem importedBoundarySmallKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_smallKernelConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryPaperEndToEndConfinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_paperEndToEndConfinementWithPublicOnlyHandwrittenShell
      hValid

theorem importedBoundaryPaperPublicBridgeObserverRefinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_paperPublicBridgeObserverRefinement
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationKernelMeetingConfinementBoundary path
      IO.println
        s!"validated runtime implementation kernel meeting confinement boundary for {boundary.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
