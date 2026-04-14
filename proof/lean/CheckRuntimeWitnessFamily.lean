import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkRuntimeWitnessFamily <family.json> <page-model> <exit-model> <shared-resource-model>"

def familyEntrypoint
  (family : ImportedSeededRuntimePathOramWitnessFamily) : String :=
  match family.witnesses.head? with
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
      let family ← loadAndCheckImportedSeededRuntimePathOramWitnessFamily path modelTags
      IO.println
        s!"validated seeded path-ORAM runtime witness family for {familyEntrypoint family} with {family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
