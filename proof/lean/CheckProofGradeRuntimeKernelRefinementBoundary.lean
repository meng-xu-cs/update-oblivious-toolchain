import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelRefinementBoundary <kernel-interface-bundle.json>"

theorem importedBundleProjectsToRuntimeKernelRefinementBoundary
  {bundle : ImportedRuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (bundle.toRuntimeKernelRefinementBoundary hValid).runtimeKernelRefinementWitness
      (bundle.toRuntimeKernelRefinementBoundary hValid).kernelWitness :=
  importedRuntimeKernelInterfaceBundle_valid_projects_to_runtimeKernelRefinementBoundary hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelInterfaceBundle path
      IO.println
        s!"validated proof-grade runtime kernel refinement boundary for {bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
