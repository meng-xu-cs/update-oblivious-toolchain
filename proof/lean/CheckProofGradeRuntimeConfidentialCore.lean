import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCore <confidential-core-bundle.json> <page-model> <exit-model> <shared-resource-model>"

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
