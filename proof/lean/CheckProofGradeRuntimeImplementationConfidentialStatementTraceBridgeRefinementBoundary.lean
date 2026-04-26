import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRefinesLeanKernelState
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness :=
  importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_valid_projects_to_refinesLeanKernelState
    hValid

theorem importedBoundaryProjectsToRuntimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid
  let confinementBoundary := runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
    hValid

theorem importedBoundaryBridgeConfinement
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ConfidentialStatementTraceBridgeBoundary := by
  exact
    importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_toRuntimeBridgeConfinement
      boundary hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
          path
      IO.println
        s!"validated runtime implementation confidential statement-trace bridge refinement boundary for {boundary.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
