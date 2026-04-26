import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelMachineFinishBoundary <machine-finish-boundary.json>"

theorem importedMachineFinishBoundaryProjectsToRuntimeKernelRefinementBoundary
  {boundary : ImportedRuntimeKernelMachineFinishBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeKernelMachineFinishBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeKernelMachineFinishBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedMachineFinishBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeKernelMachineFinishBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeKernelMachineFinishBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeKernelMachineFinishBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeKernelMachineFinishBoundary path
      IO.println
        s!"validated proof-grade runtime kernel machine finish boundary for {boundary.runtime_kernel_machine_finish_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
