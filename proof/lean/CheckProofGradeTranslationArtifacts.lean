import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkProofGradeTranslationArtifacts <metadata-contract> <source-artifact.json> <artifact.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [metadataContract, sourceArtifactPath, artifactPath] =>
      let bundle ←
        loadAndCheckImportedProofGradeTranslationArtifacts
          metadataContract
          sourceArtifactPath
          artifactPath
      IO.println
        s!"validated proof-grade translation artifacts for {bundle.metadata_contract}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
