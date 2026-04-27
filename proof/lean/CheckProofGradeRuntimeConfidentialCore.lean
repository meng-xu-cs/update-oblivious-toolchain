import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCore <confidential-core-bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core bundles bundle a proof-grade kernel witness whose
expected/emitted kernel steps agree with the confidential program's
expected runtime kernel steps, plus a runtime kernel-refinement
witness whose shell trace proof-grade refines the kernel witness's
shell contract. -/
theorem importedRuntimeConfidentialCoreBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract :=
  importedRuntimeConfidentialCoreBundle_proofGradeAssurance bundle modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core bundles preserve validity through the
`toRuntimeConfidentialCoreBundle` projection. -/
theorem importedRuntimeConfidentialCoreBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreBundle.Valid modelTags :=
  importedRuntimeConfidentialCoreBundle_toRuntimeValid bundle modelTags hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [bundlePath, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreBundle bundlePath modelTags
      IO.println
        s!"validated proof-grade runtime confidential core for {bundle.runtime_witness.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
