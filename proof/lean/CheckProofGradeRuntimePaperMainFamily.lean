import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainFamily <family.json> <page-model> <exit-model> <shared-resource-model>"

def familyEntrypoint
  (family : ImportedSeededRuntimePathOramWitnessFamily) : String :=
  match family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

/-- Paper-grade witness theorem (W7.2): a validated proof-grade
seeded path-ORAM paper-main family witnesses three paper-grade
facts together: the underlying kernel-interface assurance (every
seed has a proof-grade kernel-interface bundle witness), uniform
public outcome across seeds, and uniform boundary schedule across
seeds. -/
theorem importedSeededRuntimePathOramPaperMainFamily_validates_proofGradePaperMainRuntimeAssurance
  {family : ImportedSeededRuntimePathOramWitnessFamily}
  {modelTags : SGXModelTags}
  (hCheck :
    checkImportedProofGradeSeededRuntimePathOramPaperMainFamily family modelTags = true) :
  family.ProofGradePaperMainRuntimeAssurance modelTags :=
  (importedSeededRuntimePathOramPaperMainFamily_check_eq_true_iff family modelTags).mp hCheck

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let family ←
        loadAndCheckImportedProofGradeSeededRuntimePathOramPaperMainFamily
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime paper-main family for {familyEntrypoint family} with {family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
