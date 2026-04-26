import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeConfidentialStatementTraceBridgeBoundary <boundary.json>"

theorem importedBoundaryBridgeConfinement
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeBoundary hValid
  runtimeBoundary.implementationInterface.ConfidentialStatementTraceBridgeBoundary := by
  exact
    importedRuntimeImplementationConfidentialStatementTraceBridgeBoundary_valid_bridgeConfinement
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ←
        loadAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary path
      IO.println
        s!"validated runtime confidential statement-trace bridge boundary for source-backed uo-evm/shared-kernel runtime ({boundary.implementation_interface.trace_source.length} trace bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
