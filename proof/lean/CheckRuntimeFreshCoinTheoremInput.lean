import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkRuntimeFreshCoinTheoremInput <theorem-input.json> <page-model> <exit-model> <shared-resource-model>"

def theoremInputEntrypoint
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput) : String :=
  input.representative_witness.public_outcome.entrypoint_id

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let theoremInput ←
        loadAndCheckImportedCanonicalFreshCoinRuntimePathOramTheoremInput path modelTags
      IO.println
        s!"validated canonical fresh-coin path-ORAM theorem input for {theoremInputEntrypoint theoremInput} with {theoremInput.seed_count} canonical seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
