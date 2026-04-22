import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelConfinementBoundary <kernel-interface-bundle.json>"

theorem importedBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedRuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelConfinementBoundary hValid
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeKernelInterfaceBundle_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelInterfaceBundle path
      IO.println
        s!"validated proof-grade runtime kernel confinement boundary for {bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
