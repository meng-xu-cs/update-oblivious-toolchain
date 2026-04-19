import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialCoreShellBoundarySlot <bundle.json> <page-model> <exit-model> <shared-resource-model>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundleToRuntimeBundle
          path modelTags
      IO.println
        s!"validated proof-grade runtime confidential-core shell-boundary slot bundle for {runtimeBundle.confidentialSlotProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
