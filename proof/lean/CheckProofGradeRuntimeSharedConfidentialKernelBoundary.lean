import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeSharedConfidentialKernelBoundary <boundary.json>"

theorem importedBoundarySharedKernelConfinement
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationSharedConfidentialKernelBoundary_toRuntimeSharedKernelConfinement
      boundary hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryHostVisibleErrorTaxonomy
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_hostVisibleErrorTaxonomy
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationSharedConfidentialKernelBoundary path
      IO.println
        s!"validated runtime shared confidential-kernel boundary for source-backed uo-evm/shared-kernel runtime ({boundary.implementation_interface.kernel_runtime_source.length} shared-kernel bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
