import Lean.Data.Json
import UOToolchain.RuntimeKernelDslJson
import UOToolchain.RuntimeTrustedKernelJson
import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeConfidentialCoreKernelFinishSlotJson
import UOToolchain.RuntimeConfidentialCoreKernelInterfaceSlotJson
import UOToolchain.RuntimeConfidentialCoreShellBoundarySlotJson
import UOToolchain.RuntimeConfidentialCoreShellBoundaryLoweringJson
import UOToolchain.RuntimeCoinsJson

open Lean

namespace UOToolchain

def importedRuntimeConfidentialProofBundleFamilyFieldNames : List String :=
  [ "runtime_kernel_interface_bundle"
  , "runtime_confidential_core_kernel_interface_slot_bundle"
  , "runtime_kernel_dsl_bundle"
  , "runtime_kernel_slot_dsl_bundle"
  , "runtime_kernel_lowering_bundle"
  , "runtime_trusted_kernel_slot_bundle"
  , "runtime_confidential_core_bundle"
  , "runtime_confidential_core_slot_bundle"
  , "runtime_confidential_core_kernel_finish_slot_bundle"
  , "runtime_confidential_core_lowering_bundle"
  , "runtime_confidential_core_shell_boundary_slot_bundle"
  , "runtime_confidential_core_shell_boundary_lowering_bundle"
  , "runtime_paper_main_family_bundle"
  , "runtime_paper_main_slot_family_bundle"
  ]

structure ImportedRuntimeConfidentialProofBundleFamily where
  runtime_kernel_interface_bundle : ImportedRuntimeKernelInterfaceBundle
  runtime_confidential_core_kernel_interface_slot_bundle :
    ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle
  runtime_kernel_dsl_bundle : ImportedRuntimeKernelDslBundle
  runtime_kernel_slot_dsl_bundle : ImportedRuntimeKernelSlotDslBundle
  runtime_kernel_lowering_bundle : ImportedRuntimeKernelLoweringBundle
  runtime_trusted_kernel_slot_bundle : ImportedRuntimeTrustedKernelSlotBundle
  runtime_confidential_core_bundle : ImportedRuntimeConfidentialCoreBundle
  runtime_confidential_core_slot_bundle : ImportedRuntimeConfidentialCoreSlotBundle
  runtime_confidential_core_kernel_finish_slot_bundle :
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle
  runtime_confidential_core_lowering_bundle : ImportedRuntimeConfidentialCoreLoweringBundle
  runtime_confidential_core_shell_boundary_slot_bundle :
    ImportedRuntimeConfidentialCoreShellBoundarySlotBundle
  runtime_confidential_core_shell_boundary_lowering_bundle :
    ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle
  runtime_paper_main_family_bundle : ImportedSeededRuntimePaperMainFamilyBundle
  runtime_paper_main_slot_family_bundle : ImportedSeededRuntimePaperMainSlotFamilyBundle
deriving FromJson

def ImportedRuntimeConfidentialProofBundleFamily.sharedRuntimeWitness
  (bundle : ImportedRuntimeConfidentialProofBundleFamily) :
  ImportedRuntimeRefinementWitness :=
  bundle.runtime_confidential_core_kernel_interface_slot_bundle.runtime_witness

def ImportedRuntimeConfidentialProofBundleFamily.sharedKernelInterfaceBundle
  (bundle : ImportedRuntimeConfidentialProofBundleFamily) :
  ImportedRuntimeKernelInterfaceBundle :=
  bundle.runtime_kernel_interface_bundle

def ImportedRuntimeConfidentialProofBundleFamily.sharedShellBoundaryBundle
  (bundle : ImportedRuntimeConfidentialProofBundleFamily) :
  ImportedRuntimeShellBoundaryBundle :=
  bundle.runtime_kernel_interface_bundle.shell_boundary_bundle

def ImportedRuntimeConfidentialProofBundleFamily.sharedKernelWitness
  (bundle : ImportedRuntimeConfidentialProofBundleFamily) :
  ImportedRuntimeKernelWitness :=
  bundle.runtime_kernel_interface_bundle.shell_boundary_bundle.kernel_witness

def ImportedRuntimeConfidentialProofBundleFamily.sharedNamedProgram
  (bundle : ImportedRuntimeConfidentialProofBundleFamily) :
  ImportedConfidentialKernelProgram :=
  bundle.runtime_confidential_core_bundle.confidential_program

def ImportedRuntimeConfidentialProofBundleFamily.sharedSlotProgram
  (bundle : ImportedRuntimeConfidentialProofBundleFamily) :
  ImportedConfidentialKernelSlotProgram :=
  bundle.runtime_confidential_core_kernel_interface_slot_bundle.confidential_slot_program

def ImportedRuntimeConfidentialProofBundleFamily.Valid
  (bundle : ImportedRuntimeConfidentialProofBundleFamily)
  (modelTags : SGXModelTags) : Prop :=
  let finishSlotProgram :=
    bundle.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program
  let finishBundle :=
    bundle.runtime_confidential_core_kernel_finish_slot_bundle.runtime_kernel_finish_bundle
  bundle.runtime_kernel_interface_bundle.Valid ∧
    bundle.runtime_confidential_core_kernel_interface_slot_bundle.Valid modelTags ∧
    bundle.runtime_kernel_dsl_bundle.Valid ∧
    bundle.runtime_kernel_slot_dsl_bundle.Valid ∧
    bundle.runtime_kernel_lowering_bundle.Valid ∧
    bundle.runtime_trusted_kernel_slot_bundle.Valid modelTags ∧
    bundle.runtime_confidential_core_bundle.Valid modelTags ∧
    bundle.runtime_confidential_core_slot_bundle.Valid modelTags ∧
    bundle.runtime_confidential_core_kernel_finish_slot_bundle.Valid ∧
    bundle.runtime_confidential_core_lowering_bundle.Valid modelTags ∧
    bundle.runtime_confidential_core_shell_boundary_slot_bundle.Valid modelTags ∧
    bundle.runtime_confidential_core_shell_boundary_lowering_bundle.Valid modelTags ∧
    bundle.runtime_paper_main_family_bundle.Valid modelTags ∧
    bundle.runtime_paper_main_slot_family_bundle.Valid modelTags ∧
    bundle.runtime_confidential_core_kernel_interface_slot_bundle.kernel_interface_bundle =
      bundle.sharedKernelInterfaceBundle ∧
    bundle.runtime_confidential_core_bundle.runtime_witness = bundle.sharedRuntimeWitness ∧
    bundle.runtime_confidential_core_slot_bundle.runtime_witness = bundle.sharedRuntimeWitness ∧
    finishSlotProgram.entrypoint_id =
      (bundle.sharedSlotProgram).entrypoint_id ∧
    finishSlotProgram.expectedRuntimeKernelSteps =
      (bundle.sharedSlotProgram).expectedRuntimeKernelSteps ∧
    finishBundle.kernelInterfaceBundle? =
      some bundle.sharedKernelInterfaceBundle ∧
    bundle.runtime_confidential_core_lowering_bundle.runtime_witness =
      bundle.sharedRuntimeWitness ∧
    bundle.runtime_confidential_core_shell_boundary_slot_bundle.runtime_witness =
      bundle.sharedRuntimeWitness ∧
    bundle.runtime_confidential_core_shell_boundary_lowering_bundle.runtime_witness =
      bundle.sharedRuntimeWitness ∧
    bundle.runtime_kernel_dsl_bundle.kernel_witness = bundle.sharedKernelWitness ∧
    bundle.runtime_kernel_slot_dsl_bundle.kernel_witness = bundle.sharedKernelWitness ∧
    bundle.runtime_kernel_lowering_bundle.kernel_witness = bundle.sharedKernelWitness ∧
    bundle.runtime_trusted_kernel_slot_bundle.trusted_kernel_bundle.kernel_witness =
      some bundle.sharedKernelWitness ∧
    bundle.runtime_confidential_core_shell_boundary_slot_bundle.shell_boundary_bundle =
      bundle.sharedShellBoundaryBundle ∧
    bundle.runtime_confidential_core_shell_boundary_lowering_bundle.shell_boundary_bundle =
      bundle.sharedShellBoundaryBundle ∧
    bundle.runtime_paper_main_slot_family_bundle.family =
      bundle.runtime_paper_main_family_bundle.family ∧
    bundle.runtime_paper_main_slot_family_bundle.public_outcome =
      bundle.runtime_paper_main_family_bundle.public_outcome ∧
    bundle.runtime_paper_main_slot_family_bundle.boundary_schedule =
      bundle.runtime_paper_main_family_bundle.boundary_schedule ∧
    bundle.runtime_paper_main_family_bundle.family.seed_count = 1 ∧
    bundle.runtime_paper_main_slot_family_bundle.family.seed_count = 1

def ImportedRuntimeConfidentialProofBundleFamily.checkValid
  (bundle : ImportedRuntimeConfidentialProofBundleFamily)
  (modelTags : SGXModelTags) : Bool :=
  let finishSlotProgram :=
    bundle.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program
  let finishBundle :=
    bundle.runtime_confidential_core_kernel_finish_slot_bundle.runtime_kernel_finish_bundle
  bundle.runtime_kernel_interface_bundle.checkValid &&
    bundle.runtime_confidential_core_kernel_interface_slot_bundle.checkValid modelTags &&
    bundle.runtime_kernel_dsl_bundle.checkValid &&
    bundle.runtime_kernel_slot_dsl_bundle.checkValid &&
    bundle.runtime_kernel_lowering_bundle.checkValid &&
    bundle.runtime_trusted_kernel_slot_bundle.checkValid modelTags &&
    bundle.runtime_confidential_core_bundle.checkValid modelTags &&
    bundle.runtime_confidential_core_slot_bundle.checkValid modelTags &&
    bundle.runtime_confidential_core_kernel_finish_slot_bundle.checkValid &&
    bundle.runtime_confidential_core_lowering_bundle.checkValid modelTags &&
    bundle.runtime_confidential_core_shell_boundary_slot_bundle.checkValid modelTags &&
    bundle.runtime_confidential_core_shell_boundary_lowering_bundle.checkValid modelTags &&
    bundle.runtime_paper_main_family_bundle.checkValid modelTags &&
    bundle.runtime_paper_main_slot_family_bundle.checkValid modelTags &&
    decide
      (bundle.runtime_confidential_core_kernel_interface_slot_bundle.kernel_interface_bundle =
        bundle.sharedKernelInterfaceBundle) &&
    decide (bundle.runtime_confidential_core_bundle.runtime_witness = bundle.sharedRuntimeWitness) &&
    decide
      (bundle.runtime_confidential_core_slot_bundle.runtime_witness = bundle.sharedRuntimeWitness) &&
    decide
      (finishSlotProgram.entrypoint_id =
        (bundle.sharedSlotProgram).entrypoint_id) &&
    decide
      (finishSlotProgram.expectedRuntimeKernelSteps =
        (bundle.sharedSlotProgram).expectedRuntimeKernelSteps) &&
    decide
      (finishBundle.kernelInterfaceBundle? =
        some bundle.sharedKernelInterfaceBundle) &&
    decide
      (bundle.runtime_confidential_core_lowering_bundle.runtime_witness =
        bundle.sharedRuntimeWitness) &&
    decide
      (bundle.runtime_confidential_core_shell_boundary_slot_bundle.runtime_witness =
        bundle.sharedRuntimeWitness) &&
    decide
      (bundle.runtime_confidential_core_shell_boundary_lowering_bundle.runtime_witness =
        bundle.sharedRuntimeWitness) &&
    decide (bundle.runtime_kernel_dsl_bundle.kernel_witness = bundle.sharedKernelWitness) &&
    decide
      (bundle.runtime_kernel_slot_dsl_bundle.kernel_witness = bundle.sharedKernelWitness) &&
    decide (bundle.runtime_kernel_lowering_bundle.kernel_witness = bundle.sharedKernelWitness) &&
    decide
      (bundle.runtime_trusted_kernel_slot_bundle.trusted_kernel_bundle.kernel_witness =
        some bundle.sharedKernelWitness) &&
    decide
      (bundle.runtime_confidential_core_shell_boundary_slot_bundle.shell_boundary_bundle =
        bundle.sharedShellBoundaryBundle) &&
    decide
      (bundle.runtime_confidential_core_shell_boundary_lowering_bundle.shell_boundary_bundle =
        bundle.sharedShellBoundaryBundle) &&
    decide
      (bundle.runtime_paper_main_slot_family_bundle.family =
        bundle.runtime_paper_main_family_bundle.family) &&
    decide
      (bundle.runtime_paper_main_slot_family_bundle.public_outcome =
        bundle.runtime_paper_main_family_bundle.public_outcome) &&
    decide
      (bundle.runtime_paper_main_slot_family_bundle.boundary_schedule =
        bundle.runtime_paper_main_family_bundle.boundary_schedule) &&
    decide (bundle.runtime_paper_main_family_bundle.family.seed_count = 1) &&
    decide (bundle.runtime_paper_main_slot_family_bundle.family.seed_count = 1)

@[simp] theorem importedRuntimeConfidentialProofBundleFamily_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialProofBundleFamily)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialProofBundleFamily.checkValid
    ImportedRuntimeConfidentialProofBundleFamily.Valid
    ImportedRuntimeConfidentialProofBundleFamily.sharedRuntimeWitness
    ImportedRuntimeConfidentialProofBundleFamily.sharedKernelInterfaceBundle
    ImportedRuntimeConfidentialProofBundleFamily.sharedShellBoundaryBundle
    ImportedRuntimeConfidentialProofBundleFamily.sharedKernelWitness
    ImportedRuntimeConfidentialProofBundleFamily.sharedSlotProgram
  simp
    [ importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_checkValid_eq_true_iff
    , importedRuntimeKernelDslBundle_checkValid_eq_true_iff
    , importedRuntimeKernelSlotDslBundle_checkValid_eq_true_iff
    , importedRuntimeKernelLoweringBundle_checkValid_eq_true_iff
    , importedRuntimeTrustedKernelSlotBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreSlotBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreLoweringBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreShellBoundarySlotBundle_checkValid_eq_true_iff
    , importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_checkValid_eq_true_iff
    , importedSeededRuntimePaperMainFamilyBundle_checkValid_eq_true_iff
    , importedSeededRuntimePaperMainSlotFamilyBundle_checkValid_eq_true_iff
    , and_assoc
    ]

theorem importedRuntimeConfidentialProofBundleFamily_runtimeKernelInterfaceBundle_valid
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_kernel_interface_bundle.Valid := by
  exact hValid.1

theorem importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_paper_main_family_bundle.Valid modelTags := by
  exact hValid.2.2.2.2.2.2.2.2.2.2.2.2.1

theorem importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_paper_main_slot_family_bundle.Valid modelTags := by
  exact hValid.2.2.2.2.2.2.2.2.2.2.2.2.2.1

theorem importedRuntimeConfidentialProofBundleFamily_runtimeKernelFinishSlotBundle_valid
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_confidential_core_kernel_finish_slot_bundle.Valid := by
  exact hValid.2.2.2.2.2.2.2.2.1

noncomputable def ImportedRuntimeConfidentialProofBundleFamily.toRuntimeKernelRefinementBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelRefinementBoundary :=
  bundle.runtime_kernel_interface_bundle.toRuntimeKernelRefinementBoundary
    (importedRuntimeConfidentialProofBundleFamily_runtimeKernelInterfaceBundle_valid hValid)

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelRefinementBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  (bundle.toRuntimeKernelRefinementBoundary hValid).runtimeKernelRefinementWitness.RefinesLeanKernelState
    (bundle.toRuntimeKernelRefinementBoundary hValid).kernelWitness := by
  exact RuntimeKernelRefinementBoundary.toRefinesLeanKernelState _

noncomputable def ImportedRuntimeConfidentialProofBundleFamily.toRuntimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelFinishSlotBoundary :=
  bundle.runtime_confidential_core_kernel_finish_slot_bundle.toRuntimeKernelFinishSlotBoundary
    (importedRuntimeConfidentialProofBundleFamily_runtimeKernelFinishSlotBundle_valid hValid)

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.toRefinesLeanKernelState boundary

noncomputable def ImportedRuntimeConfidentialProofBundleFamily.toRuntimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelInterfaceSlotBoundary :=
  (bundle.toRuntimeKernelFinishSlotBoundary hValid).runtimeKernelInterfaceSlotBoundary

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelInterfaceSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelInterfaceSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid ∧
      runtimeKernelInterfaceBundle.expectedKernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
        some boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  intro boundary
  refine
    ⟨boundary.kernelInterfaceBundle, boundary.kernelInterfaceBundle_valid, ?_, ?_, ?_⟩
  · simp [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle]
  · simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
      boundary.expectedKernelStepsExact
  · simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
      boundary.emittedKernelStepsExact

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeShellBoundaryBundle
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.shellBoundaryBundle_valid boundary

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_family_assurance
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_paper_main_family_bundle.family.ProofGradePaperMainRuntimeAssurance modelTags := by
  exact
    importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_family_assurance
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid hValid)

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelBoundaryAt
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (bundle.runtime_paper_main_family_bundle.family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid hValid).1.1)) := by
  exact
    importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_runtimeKernelBoundaryAt
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid hValid)

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelInterface
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed, seed < bundle.runtime_paper_main_family_bundle.family.seed_count →
    RuntimeProofGradeKernelInterface
      ((bundle.runtime_paper_main_family_bundle.family.toSeededRuntimePathOramWitnessFamily
        modelTags
        (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
          (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid hValid).1.1)).witnessAt seed) := by
  exact
    importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_runtimeKernelInterface
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid hValid)

noncomputable def importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelConfinementBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed,
      seed <
          (bundle.runtime_paper_main_family_bundle.family.toSeededRuntimePathOramWitnessFamily
            modelTags
            (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
              (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid
                hValid).1.1)).seedCount →
        RuntimeKernelConfinementBoundary := by
  exact
    importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_runtimeKernelConfinementBoundary
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainFamilyBundle_valid hValid)

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_family_slot_assurance
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_paper_main_slot_family_bundle.family.ProofGradePaperMainRuntimeAssurance modelTags ∧
    bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program.RuntimeNormalForm ∧
    bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program.entrypoint_id =
      bundle.runtime_paper_main_slot_family_bundle.runtimePublicOutcome.entrypointId ∧
    ∀ seed, seed < bundle.runtime_paper_main_slot_family_bundle.family.seed_count →
      ∃ witness,
        bundle.runtime_paper_main_slot_family_bundle.family.witnessAt? seed = some witness ∧
          ImportedRuntimeConfidentialCoreKernelInterfaceSlotAssurance
            witness
            bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program
            modelTags := by
  exact
    importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_family_slot_assurance
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid hValid)

theorem importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelSlotBoundaryAt
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.runtime_paper_main_slot_family_bundle.family.toSeededRuntimePathOramWitnessFamily
      modelTags
      (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
        (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid hValid).1))
    bundle.runtime_paper_main_slot_family_bundle.confidential_slot_program.toConfidentialKernelSlotProgram := by
  exact
    importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_runtimeKernelSlotBoundaryAt
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid hValid)

noncomputable def importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelSlotInterfaceBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed,
      seed <
          (bundle.runtime_paper_main_slot_family_bundle.family.toSeededRuntimePathOramWitnessFamily
            modelTags
            (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
              (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid
                hValid).1)).seedCount →
        RuntimeKernelInterfaceSlotBoundary := by
  exact
    importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_runtimeKernelInterfaceSlotBoundary
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid hValid)

noncomputable def importedRuntimeConfidentialProofBundleFamily_valid_projects_to_runtimeKernelSlotConfinementBoundary
  {bundle : ImportedRuntimeConfidentialProofBundleFamily}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∀ seed,
      seed <
          (bundle.runtime_paper_main_slot_family_bundle.family.toSeededRuntimePathOramWitnessFamily
            modelTags
            (importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
              (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid
                hValid).1)).seedCount →
        RuntimeKernelConfinementBoundary := by
  exact
    importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_runtimeKernelConfinementBoundary
      (importedRuntimeConfidentialProofBundleFamily_runtimePaperMainSlotFamilyBundle_valid hValid)

def parseImportedRuntimeConfidentialProofBundleFamily
  (input : String) : Except String ImportedRuntimeConfidentialProofBundleFamily := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeConfidentialProofBundleFamily
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedRuntimeConfidentialProofBundleFamily := do
  let bundle ← parseImportedRuntimeConfidentialProofBundleFamily input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential proof bundle family does not satisfy Lean validity checks"

def loadImportedRuntimeConfidentialProofBundleFamily
  (path : System.FilePath) : IO ImportedRuntimeConfidentialProofBundleFamily := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialProofBundleFamily input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential proof bundle family: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialProofBundleFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeConfidentialProofBundleFamily := do
  let input ← IO.FS.readFile path
  match
      parseAndCheckImportedProofGradeRuntimeConfidentialProofBundleFamily
        input
        modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential proof bundle family: {err}"

end UOToolchain
