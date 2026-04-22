import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreKernelFinishSlot <bundle.json>"

theorem importedBundleProjectsToRefinesLeanKernelState
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.runtimeKernelRefinementWitness
      (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelBoundary.kernelWitness :=
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBundleProjectsToRuntimeKernelInterfaceBundle
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
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeKernelInterfaceBundle
    hValid

theorem importedBundleProjectsToRuntimeShellBoundaryBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid :=
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeShellBoundaryBundle
    hValid

theorem importedBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelFinishSlotBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeConfidentialCoreKernelFinishSlotBundle_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelFinishSlotBundle
          path
      IO.println
        s!"validated proof-grade runtime confidential-core kernel-finish slot bundle and confinement route for {bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
