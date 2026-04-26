import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationConfinementBoundary <boundary.json>"

theorem importedRuntimeImplementationBoundary_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  refine ⟨?_, ?_⟩
  · exact
      importedRuntimeImplementationConfinementBoundary_toRuntimeImplementationConfinement
        boundary hValid
  · exact
      importedRuntimeImplementationConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
        hValid

theorem importedRuntimeImplementationBoundary_sharedKernelConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_sharedKernelConfinement hValid

theorem importedRuntimeImplementationBoundary_smallKernelConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_smallKernelConfinement hValid

theorem importedRuntimeImplementationBoundary_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedRuntimeImplementationBoundary_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_slotAdapterConfinement
      hValid

theorem importedRuntimeImplementationBoundary_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedRuntimeImplementationBoundary_paperEndToEndConfinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_paperEndToEndConfinementWithPublicOnlyHandwrittenShell
      hValid

theorem importedRuntimeImplementationBoundary_paperPublicBridgeObserverRefinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationConfinementBoundary_valid_paperPublicBridgeObserverRefinement
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationConfinementBoundary path
      IO.println
        s!"validated runtime implementation confinement boundary for source-backed uo-evm/shared-kernel interface ({boundary.implementation_interface.kernel_runtime_source.length} shared-kernel bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
