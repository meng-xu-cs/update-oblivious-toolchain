import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreShellBoundarySlot <bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core shell-boundary slot bundles bundle five
paper-grade facts together: kernel-witness equality between the
runtime witness and the shell-boundary bundle, runtime
kernel-refinement-witness equality, the underlying shell-boundary
proof-grade shell refinement, and exact slot-schedule equality
between the kernel witness's expected/emitted steps and the
confidential slot program's expected runtime kernel steps. -/
theorem importedRuntimeConfidentialCoreShellBoundarySlotBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness ∧
    bundle.runtime_witness.runtime_kernel_refinement_witness =
      some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness ∧
    bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
      bundle.shell_boundary_bundle.kernel_witness.shellContract ∧
    bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
    bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_slot_program.expectedRuntimeKernelSteps :=
  importedRuntimeConfidentialCoreShellBoundarySlotBundle_proofGradeAssurance
    bundle modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core shell-boundary slot bundles preserve validity
through the `toRuntimeConfidentialCoreShellBoundarySlotBundle`
projection. -/
theorem importedRuntimeConfidentialCoreShellBoundarySlotBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreShellBoundarySlotBundle.Valid modelTags :=
  importedRuntimeConfidentialCoreShellBoundarySlotBundle_toRuntimeValid
    bundle modelTags hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundleToRuntimeBundle
          path modelTags
      IO.println
        s!"validated proof-grade runtime confidential-core shell-boundary slot bundle for {runtimeBundle.confidentialSlotProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
