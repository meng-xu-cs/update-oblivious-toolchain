import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreShellBoundaryLowering <bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core shell-boundary lowering bundles bundle nine
paper-grade facts together: a successful named→slot lowering of the
confidential program, kernel-witness equality between the runtime
witness and the shell-boundary bundle, runtime kernel-refinement
witness equality, the underlying shell-boundary proof-grade shell
refinement, exact named-schedule equality between the kernel
witness's expected/emitted steps and the named program's expected
runtime kernel steps, the same equality after recomputing the slot
program, and the slot-lowering checker accepting. -/
theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness ∧
      bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
        bundle.shell_boundary_bundle.kernel_witness.shellContract ∧
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some lowered.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        lowered.expectedRuntimeKernelSteps ∧
      checkImportedConfidentialKernelProgramSlotLowering
        bundle.confidential_program bundle.confidential_slot_program = true :=
  importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_proofGradeAssurance
    bundle modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core shell-boundary lowering bundles project to a
runtime confidential-core shell-boundary lowering bundle whose
validity is preserved through the recomputed slot lowering. -/
theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      RuntimeConfidentialCoreShellBoundaryLoweringBundle.Valid
        { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
        , shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } modelTags :=
  importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_toRuntimeValid
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
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundaryLoweringBundleToRuntimeBundle
          path modelTags
      IO.println
        s!"validated/recomputed proof-grade runtime confidential-core shell-boundary lowering bundle for {runtimeBundle.confidentialProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
