import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelDsl <kernel-dsl-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel DSL bundles project to a runtime kernel-DSL schedule whose
runtime-form expected and emitted kernel steps both agree exactly
with the confidential program's expected runtime kernel steps. -/
theorem importedRuntimeKernelDslBundle_validates_runtimeSchedule_exact
  {bundle : ImportedRuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
      some bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
    bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
      bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps :=
  importedRuntimeKernelDslBundle_toRuntimeSchedule_exact hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel DSL bundles agree on the entrypoint id between kernel witness
and confidential program. -/
theorem importedRuntimeKernelDslBundle_validates_entrypoint_exact
  {bundle : ImportedRuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.entrypointId =
    bundle.confidential_program.toConfidentialKernelProgram.entrypointId :=
  importedRuntimeKernelDslBundle_toRuntimeEntrypoint_exact hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelDslBundle path
      IO.println
        s!"validated proof-grade runtime kernel DSL bundle for {bundle.confidential_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
