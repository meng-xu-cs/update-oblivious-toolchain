import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelInterfaceFamily <family.json> <page-model> <exit-model> <shared-resource-model>"

def familyEntrypoint
  (family : ImportedSeededRuntimePathOramWitnessFamily) : String :=
  match family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

/-- Paper-grade witness theorem (W7.2): a validated proof-grade
seeded path-ORAM kernel-interface family projects to a
`PaperMainRuntimeKernelBoundaryAt` at every seed in range, i.e.
the runtime witness at each seed satisfies the runtime-side
proof-grade kernel-interface bundle predicate. -/
theorem importedSeededRuntimePathOramKernelInterfaceFamily_validates_paperMainRuntimeKernelBoundaryAt
  {family : ImportedSeededRuntimePathOramWitnessFamily}
  {modelTags : SGXModelTags}
  (hAssurance : family.ProofGradeKernelInterfaceAssurance modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        hAssurance.1)) :=
  ImportedSeededRuntimePathOramWitnessFamily.proofGradeKernelInterfaceAssurance_projects_to_runtimeKernelBoundaryAt
    hAssurance

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let family ←
        loadAndCheckImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime kernel-interface family for {familyEntrypoint family} with {family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
