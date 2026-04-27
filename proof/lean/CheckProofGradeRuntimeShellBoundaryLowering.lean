import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeShellBoundaryLowering <shell-boundary-lowering-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
shell-boundary lowering bundles bundle six paper-grade facts
together: a successful named→slot lowering, the underlying
shell-boundary's `ProofGradeRefines` between the runtime-kernel
refinement witness's shell trace and the kernel witness's shell
contract, exact named-schedule equality between the kernel witness's
expected/emitted steps and the named program's expected runtime
kernel steps, and the same equality after recomputing the slot
program. -/
theorem importedRuntimeShellBoundaryLoweringBundle_validates_proofGradeAssurance
  (bundle : ImportedRuntimeShellBoundaryLoweringBundle)
  (hValid : bundle.Valid) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
        bundle.shell_boundary_bundle.kernel_witness.shellContract ∧
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some lowered.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        lowered.expectedRuntimeKernelSteps ∧
      checkImportedConfidentialKernelProgramSlotLowering
        bundle.confidential_program bundle.confidential_slot_program = true :=
  importedRuntimeShellBoundaryLoweringBundle_proofGradeAssurance bundle hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeShellBoundaryLoweringBundleToRuntimeBundle path
      IO.println
        s!"validated/recomputed proof-grade runtime shell-boundary lowering bundle for {runtimeBundle.confidentialProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
