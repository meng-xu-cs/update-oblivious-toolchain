import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimePaperMainSlotFamilyBundle <paper-main-slot-family-bundle.json> <page-model> <exit-model> <shared-resource-model>"

def bundleEntrypoint
  (bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle) : String :=
  bundle.confidential_slot_program.entrypoint_id

/-- Paper-grade witness theorem (W7.2): a validated proof-grade
seeded runtime paper-main slot family bundle witnesses five
paper-grade facts together: kernel-interface assurance with uniform
public outcome and boundary schedule across seeds, runtime normal
form of the confidential slot program, entrypoint id agreement
between the slot program and the bundle's runtime public outcome,
opcode-trace equality with the slot program's statement-trace
names, and per-seed kernel-interface-slot assurance pairing each
witness with the bundle's confidential slot program. -/
theorem importedSeededRuntimePaperMainSlotFamilyBundle_validates_proofGradePaperMainSlotAssurance
  {bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.family.ProofGradePaperMainRuntimeAssurance modelTags ∧
    bundle.confidential_slot_program.RuntimeNormalForm ∧
    bundle.confidential_slot_program.entrypoint_id = bundle.runtimePublicOutcome.entrypointId ∧
    bundle.opcode_trace = bundle.confidential_slot_program.statementTraceNames ∧
    ∀ seed, seed < bundle.family.seed_count →
      ∃ witness,
        bundle.family.witnessAt? seed = some witness ∧
          ImportedRuntimeConfidentialCoreKernelInterfaceSlotAssurance
            witness
            bundle.confidential_slot_program
            modelTags :=
  importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_family_slot_assurance hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let bundle ←
        loadAndCheckImportedProofGradeSeededRuntimePaperMainSlotFamilyBundle
          path
          modelTags
      IO.println
        s!"validated proof-grade seeded runtime paper-main slot family bundle for {bundleEntrypoint bundle} with {bundle.family.seed_count} seeds"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
