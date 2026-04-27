import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainFamilyBundle <paper-main-family-bundle.json> <page-model> <exit-model> <shared-resource-model>"

def bundleEntrypoint
  (bundle : ImportedSeededRuntimePaperMainFamilyBundle) : String :=
  match bundle.family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

/-- Paper-grade witness theorem (W7.2): a validated proof-grade
seeded runtime paper-main family bundle projects to the bundle's
underlying family-assurance fact: kernel-interface assurance plus
public-outcome and boundary-schedule uniformity across seeds. -/
theorem importedSeededRuntimePaperMainFamilyBundle_validates_proofGradePaperMainRuntimeAssurance
  {bundle : ImportedSeededRuntimePaperMainFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.family.ProofGradePaperMainRuntimeAssurance modelTags :=
  importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_family_assurance hValid

/-- Paper-grade witness theorem (W7.2): a validated proof-grade
seeded runtime paper-main family bundle projects to a
`PaperMainRuntimeKernelBoundaryAt` for the runtime path-ORAM
witness family at every seed in range. -/
theorem importedSeededRuntimePaperMainFamilyBundle_validates_paperMainRuntimeKernelBoundaryAt
  {bundle : ImportedSeededRuntimePaperMainFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (bundle.family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        hValid.1.1)) :=
  importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_runtimeKernelBoundaryAt hValid

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
