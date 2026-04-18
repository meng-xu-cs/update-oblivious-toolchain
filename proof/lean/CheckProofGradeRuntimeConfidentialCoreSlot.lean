import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreSlot <bundle.json> <page-model> <exit-model> <shared-resource-model>"

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
        s!"validated proof-grade runtime confidential core slot bundle for {bundle.confidential_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
