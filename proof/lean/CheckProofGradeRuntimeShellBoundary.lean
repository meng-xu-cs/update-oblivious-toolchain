import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeShellBoundary <shell-boundary-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
shell-boundary bundles preserve validity through the
`toRuntimeShellBoundaryBundle` projection. -/
theorem importedRuntimeShellBoundaryBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeShellBoundaryBundle)
  (hValid : bundle.Valid) :
  bundle.toRuntimeShellBoundaryBundle.Valid :=
  importedRuntimeShellBoundaryBundle_toRuntimeValid bundle hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
shell-boundary bundles satisfy the proof-grade shell refinement
between the imported `runtime_kernel_refinement_witness.shellTrace`
and the imported `kernel_witness.shellContract`. -/
theorem importedRuntimeShellBoundaryBundle_validates_witness_proofGradeRefines
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
      bundle.kernel_witness.shellContract :=
  importedRuntimeShellBoundaryBundle_witness_proofGradeRefines hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeShellBoundaryBundle path
      IO.println
        s!"validated proof-grade runtime shell-boundary bundle for {bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
