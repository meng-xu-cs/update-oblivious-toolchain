import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialProofBundleFamilyFinishSlotBoundary <bundle.json> <page-model> <exit-model> <shared-resource-model>"

theorem importedBundleProjectsToRuntimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      boundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelFinishSlotBoundary
    hValid

theorem importedBundleProjectsToRuntimeKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
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
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelInterfaceBundle
    hValid

theorem importedBundleProjectsToRuntimeShellBoundaryBundle
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeShellBoundaryBundle
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
        loadAndCheckImportedProofGradeRuntimeConfidentialProofBundleFamily path modelTags
      IO.println
        s!"validated proof-grade runtime confidential proof bundle family finish-slot boundary for {bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
