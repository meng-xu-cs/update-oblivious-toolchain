import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlotFinishBoundary <bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness := by
  exact
    importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelFinishSlotBoundary
      hValid

theorem importedBundleProjectsToRuntimeKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid ∧
      runtimeKernelInterfaceBundle.expectedKernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
        some boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelInterfaceBundle
      hValid

theorem importedBundleProjectsToRuntimeShellBoundaryBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid := by
  exact
    importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeShellBoundaryBundle
      hValid

theorem importedBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelConfinementBoundary
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle
          path modelTags
      IO.println
        s!"validated proof-grade runtime confidential-core kernel-interface slot finish boundary and confinement route for {bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
