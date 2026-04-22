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

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationConfinementBoundary path
      IO.println
        s!"validated runtime implementation confinement boundary for source-backed uo-evm kernel interface ({boundary.implementation_interface.kernel_source.length} kernel bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
