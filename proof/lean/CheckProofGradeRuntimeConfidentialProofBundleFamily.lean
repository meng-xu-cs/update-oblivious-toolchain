import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialProofBundleFamily <bundle.json> <page-model> <exit-model> <shared-resource-model>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeRuntimeConfidentialProofBundleFamily path modelTags
      IO.println
        s!"validated proof-grade runtime confidential proof bundle family for {bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
