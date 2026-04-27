import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot <bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core kernel-interface slot bundles witness an exact
kernel-interface bundle equality between the runtime witness and
the bundle's kernel-interface field, and the bundled
shell-boundary's kernel witness's expected/emitted kernel steps
agree exactly with the confidential slot program's expected runtime
kernel steps. -/
theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_witness.kernelInterfaceBundle? = some bundle.kernel_interface_bundle ∧
    bundle.kernel_interface_bundle.Valid ∧
    bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
    bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_slot_program.expectedRuntimeKernelSteps :=
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_proofGradeAssurance
    bundle modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core kernel-interface slot bundles project to a
`PaperMainRuntimeKernelSlotBoundaryAt` for the
runtime-side singleton-seeded path-ORAM witness family at the
runtime-form confidential slot program. -/
theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_validates_paperMainRuntimeKernelSlotBoundaryAt
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.runtime_witness.toRuntimeWitness.toSingletonSeededRuntimePathOramWitnessFamily
      (importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        bundle.runtime_witness
        modelTags
        hValid.1.1).1)
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram :=
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundleToRuntimeBundle
          path modelTags
      IO.println
        s!"validated proof-grade runtime confidential-core kernel-interface slot bundle for {runtimeBundle.confidentialSlotProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
