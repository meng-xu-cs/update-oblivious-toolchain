import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeTrustedKernel <bundle.json> <page-model> <exit-model> <shared-resource-model>"

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
