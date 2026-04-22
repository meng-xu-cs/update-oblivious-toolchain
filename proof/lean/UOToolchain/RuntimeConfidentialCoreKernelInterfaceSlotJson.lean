import Lean.Data.Json
import UOToolchain.PaperPathOramTheoremRoute
import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

def importedRuntimeConfidentialCoreKernelInterfaceSlotBundleFieldNames : List String :=
  ["runtime_witness", "kernel_interface_bundle", "confidential_slot_program"]

structure ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle where
  runtime_witness : ImportedRuntimeRefinementWitness
  kernel_interface_bundle : ImportedRuntimeKernelInterfaceBundle
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.confidentialCoreSlotBundle
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle) :
  ImportedRuntimeConfidentialCoreSlotBundle :=
  { runtime_witness := bundle.runtime_witness
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.confidentialCoreSlotBundle.Valid modelTags ∧
    bundle.kernel_interface_bundle.Valid ∧
    bundle.runtime_witness.kernelInterfaceBundle? = some bundle.kernel_interface_bundle

def ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.confidentialCoreSlotBundle.checkValid modelTags &&
    bundle.kernel_interface_bundle.checkValid &&
    decide
      (bundle.runtime_witness.kernelInterfaceBundle? = some bundle.kernel_interface_bundle)

def ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle) :
  RuntimeConfidentialCoreKernelInterfaceSlotBundle :=
  { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
  , kernelInterfaceBundle := bundle.kernel_interface_bundle.toRuntimeKernelInterfaceBundle
  , confidentialSlotProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
  }

@[simp]
theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.checkValid
    ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.Valid
    ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.confidentialCoreSlotBundle
  simp [importedRuntimeConfidentialCoreSlotBundle_checkValid_eq_true_iff,
    importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff, and_assoc]

theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle.Valid modelTags := by
  have hCore :
      bundle.confidentialCoreSlotBundle.toRuntimeConfidentialCoreSlotBundle.Valid modelTags := by
    exact importedRuntimeConfidentialCoreSlotBundle_toRuntimeValid
      bundle.confidentialCoreSlotBundle modelTags hValid.1
  let runtimeKernelInterfaceBundle := bundle.kernel_interface_bundle.toRuntimeKernelInterfaceBundle
  let runtimeShellBoundaryBundle := runtimeKernelInterfaceBundle.shellBoundaryBundle
  let runtimeKernelWitness := runtimeShellBoundaryBundle.kernelWitness
  have hInterface : runtimeKernelInterfaceBundle.Valid := by
    simpa [runtimeKernelInterfaceBundle] using
      importedRuntimeKernelInterfaceBundle_toRuntimeValid bundle.kernel_interface_bundle hValid.2.1
  have hImportedInterfaceExact :=
      importedRuntimeRefinementWitness_kernelInterfaceBundle_exact hValid.2.2
  have hImportedShellExact :=
      importedRuntimeRefinementWitness_shellBoundaryBundle_exact hImportedInterfaceExact.1
  have hKernelExact :
      bundle.runtime_witness.toRuntimeWitness.kernelWitness =
        some runtimeKernelWitness := by
    have hKernelMapped :=
      congrArg (Option.map ImportedRuntimeKernelWitness.toRuntimeKernelWitness)
        hImportedShellExact.1
    simpa [runtimeKernelInterfaceBundle, runtimeShellBoundaryBundle, runtimeKernelWitness,
      ImportedRuntimeRefinementWitness.toRuntimeWitness,
      ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using hKernelMapped
  have hRefinementExact :
      bundle.runtime_witness.toRuntimeWitness.runtimeKernelRefinementWitness =
        some runtimeShellBoundaryBundle.runtimeKernelRefinementWitness := by
    have hRefinementMapped :=
      congrArg
        (Option.map ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness)
        hImportedShellExact.2.1
    simpa [runtimeKernelInterfaceBundle, runtimeShellBoundaryBundle, runtimeKernelWitness,
      ImportedRuntimeRefinementWitness.toRuntimeWitness,
      ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using hRefinementMapped
  have hShellValid : runtimeShellBoundaryBundle.Valid := by
    simpa [runtimeShellBoundaryBundle] using hInterface.1
  have hShellBoundaryRebuild :
      { kernelWitness := runtimeShellBoundaryBundle.kernelWitness
      , runtimeKernelRefinementWitness := runtimeShellBoundaryBundle.runtimeKernelRefinementWitness
      , shellContract := runtimeShellBoundaryBundle.kernelWitness.shellContract
      , shellTrace := runtimeShellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace
      } = runtimeShellBoundaryBundle := by
    cases hShellEq : runtimeShellBoundaryBundle with
    | mk kernelWitness runtimeKernelRefinementWitness shellContract shellTrace =>
        have hContractExact :
            shellContract = kernelWitness.shellContract := by
          simpa [hShellEq] using runtimeShellBoundaryBundle_contract_exact hShellValid
        have hTraceExact :
            shellTrace = runtimeKernelRefinementWitness.shellTrace := by
          simpa [hShellEq] using runtimeShellBoundaryBundle_trace_exact hShellValid
        simp [hShellEq, hContractExact, hTraceExact]
  have hShellBoundaryBundleExact :
      bundle.runtime_witness.toRuntimeWitness.shellBoundaryBundle? =
        some runtimeShellBoundaryBundle := by
    simp [RuntimeRefinementWitness.shellBoundaryBundle?, runtimeShellBoundaryBundle,
      runtimeKernelWitness, hKernelExact, hRefinementExact, hShellBoundaryRebuild]
  have hRuntimeExpectedKernelSteps :
      runtimeKernelWitness.expectedKernelSteps =
        some runtimeKernelInterfaceBundle.expectedKernelSteps := by
    simpa [runtimeKernelInterfaceBundle, runtimeShellBoundaryBundle, runtimeKernelWitness,
      ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness] using
      congrArg (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep))
        hImportedInterfaceExact.2.1
  have hRuntimeExpectedPublicObjectIds :
      runtimeKernelWitness.expectedPublicObjectIds =
        some runtimeKernelInterfaceBundle.expectedPublicObjectIds := by
    simpa [runtimeKernelInterfaceBundle, runtimeShellBoundaryBundle, runtimeKernelWitness,
      ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using
      hImportedInterfaceExact.2.2.1
  have hRuntimeExpectedKernelSchedule :
      runtimeKernelWitness.expectedKernelSchedule? =
        some runtimeKernelInterfaceBundle.expectedKernelSchedule := by
    have hImportedExpectedKernelScheduleExact :
        bundle.kernel_interface_bundle.expected_kernel_schedule =
          { opcodes := bundle.kernel_interface_bundle.expected_kernel_steps.map
              ImportedRuntimeKernelStep.opcode
          , steps := bundle.kernel_interface_bundle.expected_kernel_steps
          } := by
      have hSchedule := hImportedInterfaceExact.2.2.2
      simp [ImportedRuntimeKernelWitness.expectedKernelSchedule?, hImportedInterfaceExact.2.1] at hSchedule
      exact hSchedule.symm
    change
      ((Option.map (List.map ImportedRuntimeKernelStep.opcode)
            bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps).bind
          fun opcodes =>
          (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep)
                bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps).bind
            fun steps => some { opcodes := opcodes, steps := steps }) =
        some bundle.kernel_interface_bundle.expected_kernel_schedule.toRuntimeKernelSchedule
    rw [hImportedInterfaceExact.2.1, hImportedExpectedKernelScheduleExact]
    simp [ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule]
  have hBundleExact :
      bundle.runtime_witness.toRuntimeWitness.kernelInterfaceBundle? =
        some runtimeKernelInterfaceBundle := by
    simp [RuntimeRefinementWitness.kernelInterfaceBundle?, runtimeKernelInterfaceBundle,
      runtimeShellBoundaryBundle, runtimeKernelWitness, hShellBoundaryBundleExact,
      hRuntimeExpectedKernelSteps, hRuntimeExpectedPublicObjectIds,
      hRuntimeExpectedKernelSchedule]
  unfold ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle
    RuntimeConfidentialCoreKernelInterfaceSlotBundle.Valid
  simpa [runtimeKernelInterfaceBundle, runtimeShellBoundaryBundle, runtimeKernelWitness,
    ImportedRuntimeRefinementWitness.toRuntimeWitness,
    ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
    ImportedRuntimeConfidentialCoreSlotBundle.toRuntimeConfidentialCoreSlotBundle] using
    (show
      RuntimeConfidentialCoreSlotBundle.Valid
          { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
          , confidentialProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
          } modelTags ∧
        runtimeKernelInterfaceBundle.Valid ∧
        bundle.runtime_witness.toRuntimeWitness.kernelInterfaceBundle? =
          some runtimeKernelInterfaceBundle from
      ⟨hCore, hInterface, hBundleExact⟩)

theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_witness.kernelInterfaceBundle? = some bundle.kernel_interface_bundle ∧
    bundle.kernel_interface_bundle.Valid ∧
    bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
    bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_slot_program.expectedRuntimeKernelSteps := by
  rcases hValid with ⟨hCoreValid, hInterfaceValid, hBundleExact⟩
  have hCore :
      ∃ kernelWitness runtimeKernelRefinementWitness,
        bundle.runtime_witness.kernel_witness = some kernelWitness ∧
          kernelWitness.expected_kernel_steps =
            some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
          kernelWitness.kernel_steps = bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
          bundle.runtime_witness.runtime_kernel_refinement_witness =
            some runtimeKernelRefinementWitness ∧
          runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
            kernelWitness.shellContract := by
    exact importedRuntimeConfidentialCoreSlotBundle_proofGradeAssurance
      bundle.confidentialCoreSlotBundle modelTags hCoreValid
  have hInterfaceExact := importedRuntimeRefinementWitness_kernelInterfaceBundle_exact hBundleExact
  have hShellExact := importedRuntimeRefinementWitness_shellBoundaryBundle_exact hInterfaceExact.1
  rcases hCore with
    ⟨kernelWitness, _runtimeKernelRefinementWitness, hRuntimeKernel, hRuntimeExpected,
      hRuntimeSteps, _hRuntimeRefinement, _hRuntimeShellRefines⟩
  have hKernelEq :
      kernelWitness = bundle.kernel_interface_bundle.shell_boundary_bundle.kernel_witness := by
    apply Option.some.inj
    exact hRuntimeKernel.symm.trans hShellExact.1
  subst hKernelEq
  exact ⟨hBundleExact, hInterfaceValid, hRuntimeExpected, hRuntimeSteps⟩

theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.runtime_witness.toRuntimeWitness.toSingletonSeededRuntimePathOramWitnessFamily
      (importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        bundle.runtime_witness
        modelTags
        hValid.1.1).1)
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram := by
  exact
    runtimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
      (importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_toRuntimeValid
        bundle
        modelTags
        hValid)

theorem importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelBoundaryAt
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (bundle.runtime_witness.toRuntimeWitness.toSingletonSeededRuntimePathOramWitnessFamily
      (importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        bundle.runtime_witness
        modelTags
        hValid.1.1).1) := by
  exact
    PaperMainRuntimeKernelSlotBoundaryAt.toRuntimeKernelBoundaryAt
      (importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
        hValid)

noncomputable def
  ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.toRuntimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelInterfaceSlotBoundary :=
  bundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelInterfaceSlotBoundary
    (importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_toRuntimeValid
      bundle
      modelTags
      hValid)

noncomputable def
  ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle.toRuntimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelFinishSlotBoundary :=
  bundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelFinishSlotBoundary
    (importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_toRuntimeValid
      bundle
      modelTags
      hValid)

theorem
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelFinishSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.toRefinesLeanKernelState boundary

theorem
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelInterfaceBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
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
  exact
    RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelFinishSlotBoundary_kernelInterfaceBundle_valid
      (bundle :=
        bundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle)
      (modelTags := modelTags)
      (importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_toRuntimeValid
        bundle
        modelTags
        hValid)

theorem
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeShellBoundaryBundle
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.shellBoundaryBundle_valid boundary

theorem
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelConfinementBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelFinishSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

theorem
  importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_runtimeKernelInterfaceSlotBoundary
  {bundle : ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.toRuntimeKernelInterfaceSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelInterfaceSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

def parseImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core kernel-interface slot bundle does not satisfy Lean validity checks"

def loadImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential-core kernel-interface slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle
      input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core kernel-interface slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundleToRuntimeBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO RuntimeConfidentialCoreKernelInterfaceSlotBundle := do
  let bundle ←
    loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle path modelTags
  pure bundle.toRuntimeConfidentialCoreKernelInterfaceSlotBundle

noncomputable def
  loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundleToRuntimeBoundary
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO RuntimeKernelFinishSlotBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreKernelInterfaceSlotBundle input with
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential-core kernel-interface slot bundle: {err}"
  | .ok bundle =>
      if hCheck : bundle.checkValid modelTags then
        let hValid :
            bundle.Valid modelTags :=
          (importedRuntimeConfidentialCoreKernelInterfaceSlotBundle_checkValid_eq_true_iff
            bundle
            modelTags).mp hCheck
        pure <| bundle.toRuntimeKernelFinishSlotBoundary hValid
      else
        throw <| IO.userError
          "failed to validate proof-grade runtime confidential-core kernel-interface slot bundle"

end UOToolchain
