import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialProofBundleFamily <bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential proof-bundle families project to a
`RuntimeKernelRefinementBoundary` whose runtime kernel-refinement
witness refines the projected kernel witness's Lean kernel state. -/
theorem importedRuntimeConfidentialProofBundleFamily_validates_runtimeKernelRefinementBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  (bundle.toRuntimeKernelRefinementBoundary hValid).runtimeKernelRefinementWitness.RefinesLeanKernelState
    (bundle.toRuntimeKernelRefinementBoundary hValid).kernelWitness :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelRefinementBoundary
    hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential proof-bundle families project to a
`RuntimeKernelFinishSlotBoundary` whose runtime kernel-refinement
witness refines the projected kernel witness's Lean kernel state. -/
theorem importedRuntimeConfidentialProofBundleFamily_validates_runtimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelFinishSlotBoundary
    hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential proof-bundle families project to a
`RuntimeKernelInterfaceSlotBoundary` whose confinement boundary's
refinement-boundary runtime kernel-refinement witness refines the
kernel witness's Lean kernel state and whose shell trace refines
the kernel witness's shell contract. -/
theorem importedRuntimeConfidentialProofBundleFamily_validates_runtimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelInterfaceSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelInterfaceSlotBoundary
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
        s!"validated proof-grade runtime confidential proof bundle family for {bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
