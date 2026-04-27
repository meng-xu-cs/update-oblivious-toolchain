import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeWitnessFamily <family.json> <page-model> <exit-model> <shared-resource-model>"

def familyEntrypoint
  (family : ImportedSeededRuntimePathOramWitnessFamily) : String :=
  match family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

/-- Paper-grade witness theorem (W7.2): validated proof-grade
imported seeded path-ORAM runtime witness families satisfy the
underlying validity bundle (i.e., the proof-grade discharge implies
the structural validity required by the runtime path-ORAM family
entrypoints). -/
theorem importedSeededRuntimePathOramWitnessFamily_validates_proofGrade_implies_valid
  {family : ImportedSeededRuntimePathOramWitnessFamily}
  {modelTags : SGXModelTags}
  (hValid : family.ProofGradeValid modelTags) :
  family.Valid modelTags :=
  importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let family ← loadAndCheckImportedProofGradeSeededRuntimePathOramWitnessFamily path modelTags
      IO.println
        s!"validated proof-grade seeded path-ORAM runtime witness family for {familyEntrypoint family} with {family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
