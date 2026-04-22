import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelFinishBoundary <kernel-finish-bundle.json>"

theorem importedFinishBundleProjectsToRuntimeKernelRefinementBoundary
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (bundle.toRuntimeKernelRefinementBoundary hValid).runtimeKernelRefinementWitness
      (bundle.toRuntimeKernelRefinementBoundary hValid).kernelWitness :=
  importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelRefinementBoundary hValid

theorem importedFinishBundleProjectsToRuntimeKernelConfinementBoundary
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelConfinementBoundary hValid
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelConfinementBoundary hValid

theorem importedFinishBundleProjectsToRuntimeKernelInterfaceBundle
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid :=
  importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelInterfaceBundle hValid

theorem importedFinishBundleProjectsToRuntimeShellBoundaryBundle
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  ∃ shellBoundaryBundle : RuntimeShellBoundaryBundle,
    shellBoundaryBundle.Valid :=
  importedRuntimeKernelFinishBundle_valid_projects_to_runtimeShellBoundaryBundle hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelFinishBundle path
      IO.println
        s!"validated proof-grade runtime kernel finish boundary and confinement route for {bundle.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
