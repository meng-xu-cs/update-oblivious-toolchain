import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreSlot <bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core slot bundles bundle a proof-grade kernel witness
whose expected/emitted kernel steps agree with the confidential slot
program's expected runtime kernel steps, plus a runtime
kernel-refinement witness whose shell trace proof-grade refines the
kernel witness's shell contract. -/
theorem importedRuntimeConfidentialCoreSlotBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps =
        bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract :=
  importedRuntimeConfidentialCoreSlotBundle_proofGradeAssurance bundle modelTags hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
confidential-core slot bundles preserve validity through the
`toRuntimeConfidentialCoreSlotBundle` projection. -/
theorem importedRuntimeConfidentialCoreSlotBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreSlotBundle.Valid modelTags :=
  importedRuntimeConfidentialCoreSlotBundle_toRuntimeValid bundle modelTags hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [bundlePath, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreSlotBundle bundlePath modelTags
      IO.println
        s!"validated proof-grade runtime confidential core slot bundle for {bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
