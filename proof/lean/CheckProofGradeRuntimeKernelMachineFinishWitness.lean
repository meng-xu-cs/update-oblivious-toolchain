import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelMachineFinishWitness <machine-finish-witness.json>"

theorem importedMachineFinishWitnessProjectsToRuntimeKernelRefinementBoundary
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (witness.projectedFinishBundle.toRuntimeKernelRefinementBoundary hValid.1).runtimeKernelRefinementWitness
      (witness.projectedFinishBundle.toRuntimeKernelRefinementBoundary hValid.1).kernelWitness :=
  importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeKernelRefinementBoundary
    hValid

theorem importedMachineFinishWitnessProjectsToRuntimeKernelConfinementBoundary
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  let boundary := witness.projectedFinishBundle.toRuntimeKernelConfinementBoundary hValid.1
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedMachineFinishWitnessProjectsToRuntimeKernelInterfaceBundle
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid :=
  importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeKernelInterfaceBundle
    hValid

theorem importedMachineFinishWitnessProjectsToRuntimeShellBoundaryBundle
  {witness : ImportedRuntimeKernelMachineFinishWitness}
  (hValid : witness.Valid) :
  ∃ shellBoundaryBundle : RuntimeShellBoundaryBundle,
    shellBoundaryBundle.Valid :=
  importedRuntimeKernelMachineFinishWitness_valid_projects_to_runtimeShellBoundaryBundle
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let witness ← loadAndCheckImportedRuntimeKernelMachineFinishWitness path
      IO.println
        s!"validated proof-grade runtime kernel machine finish witness for {witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
