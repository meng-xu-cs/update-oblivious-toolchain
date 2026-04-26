import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationSharedKernelRefinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundaryPaperSharedKernelRefinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_paperSharedKernelRefinementWithPublicOnlyHandwrittenShell
    hValid

theorem importedBoundaryPaperSharedKernelObserverRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_paperSharedKernelObserverRefinement
    hValid

theorem importedBoundarySharedKernelConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationSharedKernelRefinementBoundary_toRuntimeSharedKernelConfinement
      boundary hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationSharedKernelRefinementBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationSharedKernelRefinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationSharedKernelRefinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationSharedKernelRefinementBoundary
          path
      IO.println
        s!"validated runtime implementation shared-kernel refinement boundary for {boundary.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
