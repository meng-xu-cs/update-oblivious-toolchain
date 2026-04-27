import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreLowering <confidential-core-lowering-bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core lowering bundles witness an exact slot lowering of
the imported confidential program. -/
theorem importedRuntimeConfidentialCoreLoweringBundle_validates_lowering_exact
  {bundle : ImportedRuntimeConfidentialCoreLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program = true :=
  importedRuntimeConfidentialCoreLoweringBundle_lowering_exact hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core lowering bundles project to a named runtime
confidential-core bundle whose proof-grade assurance is preserved. -/
theorem importedRuntimeConfidentialCoreLoweringBundle_validates_namedProofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps =
        bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract :=
  importedRuntimeConfidentialCoreLoweringBundle_namedProofGradeAssurance
    bundle modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core lowering bundles project to a runtime
confidential-core lowering bundle whose validity is preserved. -/
theorem importedRuntimeConfidentialCoreLoweringBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      RuntimeConfidentialCoreLoweringBundle.Valid
        { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } modelTags :=
  importedRuntimeConfidentialCoreLoweringBundle_toRuntimeValid bundle modelTags hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreLoweringBundleToRuntimeBundle
          path modelTags
      IO.println
        s!"validated/recomputed proof-grade runtime confidential-core lowering bundle for {runtimeBundle.confidentialProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
