import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeSmallConfidentialKernelBoundary <boundary.json>"

theorem importedBoundarySmallKernelConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelBoundary_toRuntimeSmallKernelConfinement
      boundary hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryHostVisibleErrorTaxonomy
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_hostVisibleErrorTaxonomy
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationSmallConfidentialKernelBoundary path
      IO.println
        s!"validated runtime small confidential-kernel boundary for source-backed uo-evm/shared-kernel runtime ({boundary.implementation_interface.kernel_runtime_source.length} shared-kernel bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
