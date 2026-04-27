import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelWitness <kernel-witness.json> <entrypoint-id>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel witnesses agree on the entrypoint id. -/
theorem importedRuntimeKernelWitness_validates_proofGrade_entrypoint_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  witness.entrypoint_id = entrypointId :=
  hValid.1.1

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel witnesses witness an exact expected-kernel-schedule whose
runtime-form `finalState?` is the canonical finished phase carrying
the same public object schedule as the expected schedule. -/
theorem importedRuntimeKernelWitness_validates_proofGrade_expectedKernelSchedule_finalState_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } :=
  importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, entrypointId] =>
      let witness ← loadAndCheckImportedProofGradeRuntimeKernelWitness path entrypointId
      IO.println
        s!"validated proof-grade runtime kernel witness for {witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
