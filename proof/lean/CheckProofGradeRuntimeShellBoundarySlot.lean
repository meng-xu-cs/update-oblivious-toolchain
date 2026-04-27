import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeShellBoundarySlot <shell-boundary-slot-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
shell-boundary slot bundles witness the underlying shell-boundary's
proof-grade refinement (between runtime kernel-refinement witness's
shell trace and kernel witness's shell contract) plus exact
slot-schedule equality between the kernel witness's expected/emitted
kernel steps and the confidential slot program's expected runtime
kernel steps. -/
theorem importedRuntimeShellBoundarySlotBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeShellBoundarySlotBundle)
  (hValid : bundle.Valid) :
  bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
      bundle.shell_boundary_bundle.kernel_witness.shellContract ∧
    bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
    bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_slot_program.expectedRuntimeKernelSteps :=
  importedRuntimeShellBoundarySlotBundle_proofGradeAssurance bundle hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeShellBoundarySlotBundleToRuntimeBundle path
      IO.println
        s!"validated proof-grade runtime shell-boundary slot bundle for {runtimeBundle.confidentialSlotProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
