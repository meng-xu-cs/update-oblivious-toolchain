import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkCanonicalPathOramPairTheoremInput <theorem-input.json> <page-model> <exit-model> <shared-resource-model>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let theoremInput ←
        loadAndCheckImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput path modelTags
      IO.println
        s!"validated canonical fresh-coin path-ORAM pair theorem input for {theoremInput.runtimePublicOutcome.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
