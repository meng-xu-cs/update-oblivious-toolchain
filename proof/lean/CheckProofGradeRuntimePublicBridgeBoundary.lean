import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePublicBridgeBoundary <boundary.json>"

theorem importedBoundaryPublicBridgeConfinement
  {boundary : ImportedRuntimeImplementationPublicBridgeBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary := by
  exact
    importedRuntimeImplementationPublicBridgeBoundary_valid_publicBridgeConfinement
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationPublicBridgeBoundary path
      IO.println
        s!"validated runtime public bridge boundary for source-backed uo-evm bridge ({boundary.implementation_interface.runtime_evm_lib_source.length + boundary.implementation_interface.engine_source.length + boundary.implementation_interface.runtime_module_source.length + boundary.implementation_interface.shell_source.length + boundary.implementation_interface.state_source.length + boundary.implementation_interface.theorem_source.length} bridge bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
