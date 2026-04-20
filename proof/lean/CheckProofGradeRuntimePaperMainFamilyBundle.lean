import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainFamilyBundle <paper-main-family-bundle.json> <page-model> <exit-model> <shared-resource-model>"

def bundleEntrypoint
  (bundle : ImportedSeededRuntimePaperMainFamilyBundle) : String :=
  match bundle.family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeSeededRuntimePaperMainFamilyBundle
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime paper-main family bundle for {bundleEntrypoint bundle} with {bundle.family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
