import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeTranslationArtifacts <metadata-contract> <source-artifact.json> <artifact.json>"

/-- Paper-grade witness theorem (W7.2): a validated imported
proof-relevant translation bundle satisfies the bundle's structural
proof-grade validity (source view matches the raw contract
projection, artifact view matches the raw contract projection,
source view equals artifact view, both views are structurally
valid, and the metadata-contract matches both). -/
theorem importedProofRelevantTranslationBundle_validates_proofGradeValid
  {bundle : ImportedProofRelevantTranslationBundle}
  (hCheck : bundle.checkProofGrade = true) :
  bundle.ProofGradeValid :=
  (importedProofRelevantTranslationBundle_checkProofGrade_eq_true_iff bundle).mp hCheck

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
