import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationPublicBridgeObserverRefinementBoundary <boundary.json>"

theorem importedBoundaryPaperPublicBridgeObserverRefinement
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract :=
  importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_paper_public_bridge_observer_refinement
    hValid

theorem importedBoundaryPublicBridgeConfinement
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary := by
  exact
    importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_publicBridgeConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary path
      IO.println
        s!"validated runtime implementation public bridge observer-refinement boundary for source-backed uo-evm bridge ({boundary.implementation_interface.runtime_evm_lib_source.length + boundary.implementation_interface.engine_source.length + boundary.implementation_interface.runtime_module_source.length + boundary.implementation_interface.shell_source.length + boundary.implementation_interface.state_source.length + boundary.implementation_interface.theorem_source.length} bridge bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
