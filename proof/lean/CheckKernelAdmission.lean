import UOToolchain.ProofGradeRoot

open UOToolchain.IR.ArtifactJson

def usage : String :=
  "usage: checkKernelAdmission <uo-artifact.json>"

/-- Decide the program-side premises of
`paperMain_checkedKernel_exact_noninterference_moduloReleases` for every
confidential entrypoint of a `uo-solc` artifact. Prints one JSON report and
exits nonzero unless every entrypoint is admitted. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let contents ← IO.FS.readFile path
      match Lean.Json.parse contents >>= checkArtifact with
      | .error err =>
          IO.eprintln s!"{path}: {err}"
          pure 1
      | .ok (contract, reports) =>
          let admitted := reports.all (·.admitted)
          IO.println (Lean.Json.mkObj
            [ ("contract", contract)
            , ("entrypoint_count", reports.length)
            , ("all_admitted", admitted)
            , ("entrypoints", Lean.Json.arr (reports.map EntrypointReport.toJson).toArray) ]).pretty
          pure (if admitted then 0 else 1)
  | _ =>
      IO.eprintln usage
      pure 1
