import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkPathOramPairCertificate <pair.json> <page-model> <exit-model> <shared-resource-model>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let certificate ←
        loadAndCheckImportedProofGradeSeededRuntimePathOramPairCertificate path modelTags
      IO.println
        s!"validated proof-grade seeded path-ORAM pair certificate for {certificate.public_outcome.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
