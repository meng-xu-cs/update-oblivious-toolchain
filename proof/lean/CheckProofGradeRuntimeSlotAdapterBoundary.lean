import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeSlotAdapterBoundary <boundary.json>"

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSlotAdapterBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary :=
    importedRuntimeImplementationSlotAdapterBoundary_toRuntimeSlotAdapterConfinement
      boundary hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationSlotAdapterBoundary path
      IO.println
        s!"validated runtime slot-adapter boundary for source-backed uo-kernel adapter ({boundary.implementation_interface.kernel_runtime_source.length + boundary.implementation_interface.kernel_slot_support_source.length + boundary.implementation_interface.confidential_kernel_source.length + boundary.implementation_interface.generated_confidential_kernel_source.length} slot-adapter bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
