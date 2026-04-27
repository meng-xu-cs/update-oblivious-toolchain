import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelLowering <kernel-lowering-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel lowering bundles witness an exact slot lowering of the imported
confidential program, plus exact named-schedule and recomputed
slot-schedule equality between the kernel witness's runtime-form
expected/emitted steps and the (named/lowered) program's expected
runtime kernel steps. -/
theorem importedRuntimeKernelLoweringBundle_validates_proofGradeAssurance
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid) :
  checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program = true ∧
    (bundle.kernel_witness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.kernel_witness.kernel_steps =
        bundle.confidential_program.expectedRuntimeKernelSteps) ∧
    (∃ lowered,
      bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
        bundle.kernel_witness.expected_kernel_steps =
          some lowered.expectedRuntimeKernelSteps ∧
        bundle.kernel_witness.kernel_steps =
          lowered.expectedRuntimeKernelSteps) :=
  ⟨importedRuntimeKernelLoweringBundle_lowering_exact hValid,
    importedRuntimeKernelLoweringBundle_namedSchedule_exact hValid,
    importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_exact hValid⟩

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let runtimeBundle ←
        loadAndCheckImportedProofGradeRuntimeKernelLoweringBundleToRuntimeBundle path
      IO.println
        s!"validated/recomputed proof-grade runtime kernel lowering bundle for {runtimeBundle.confidentialProgram.entrypointId}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
