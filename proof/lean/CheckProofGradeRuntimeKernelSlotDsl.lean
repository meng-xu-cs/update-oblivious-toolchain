import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelSlotDsl <kernel-slot-dsl-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel slot DSL bundles witness `RuntimeNormalForm` of the imported
confidential slot program. -/
theorem importedRuntimeKernelSlotDslBundle_validates_runtimeNormalForm
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.confidential_slot_program.RuntimeNormalForm :=
  importedRuntimeKernelSlotDslBundle_runtimeNormalForm hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel slot DSL bundles project to a runtime kernel-DSL schedule whose
runtime-form expected and emitted kernel steps both agree exactly
with the confidential slot program's expected runtime kernel steps. -/
theorem importedRuntimeKernelSlotDslBundle_validates_runtimeSchedule_exact
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
      some bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
      bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps :=
  importedRuntimeKernelSlotDslBundle_toRuntimeSchedule_exact hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel slot DSL bundles agree on the entrypoint id between kernel
witness and confidential slot program. -/
theorem importedRuntimeKernelSlotDslBundle_validates_entrypoint_exact
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.entrypointId =
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram.entrypointId :=
  importedRuntimeKernelSlotDslBundle_toRuntimeEntrypoint_exact hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelSlotDslBundle path
      IO.println
        s!"validated proof-grade runtime kernel slot DSL bundle for {bundle.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
