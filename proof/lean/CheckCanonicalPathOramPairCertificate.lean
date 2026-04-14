import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkCanonicalPathOramPairCertificate <certificate.json> <page-model> <exit-model> <shared-resource-model>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let certificate ←
        loadAndCheckImportedCanonicalFreshCoinRuntimePathOramPairCertificate path modelTags
      IO.println
        s!"validated canonical fresh-coin path-ORAM pair certificate for {certificate.runtimePublicOutcome.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
