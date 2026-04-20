import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainSlotFamilyBundle <paper-main-slot-family-bundle.json> <page-model> <exit-model> <shared-resource-model>"

def bundleEntrypoint
  (bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle) : String :=
  bundle.confidential_slot_program.entrypoint_id

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeSeededRuntimePaperMainSlotFamilyBundle
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime paper-main slot family bundle for {bundleEntrypoint bundle} with {bundle.family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
