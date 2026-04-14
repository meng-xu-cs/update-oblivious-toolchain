import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkRuntimeControllerCertificate <certificate.json> <page-model> <exit-model> <shared-resource-model>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let certificate ←
        loadAndCheckImportedRuntimeControllerObserverCertificate path modelTags
      IO.println
        s!"validated runtime controller observer certificate for {certificate.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
