import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeTrustedKernel <bundle.json> <page-model> <exit-model> <shared-resource-model>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
trusted-kernel slot bundles preserve validity through the
`toRuntimeTrustedKernelSlotBundle` projection. -/
theorem importedRuntimeTrustedKernelSlotBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeTrustedKernelSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeTrustedKernelSlotBundle.Valid modelTags :=
  importedRuntimeTrustedKernelSlotBundle_toRuntimeValid bundle modelTags hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ← loadAndCheckImportedProofGradeRuntimeTrustedKernelSlotBundle path modelTags
      IO.println
        s!"validated proof-grade runtime trusted kernel bundle for {bundle.trusted_kernel_bundle.controller_observer.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
