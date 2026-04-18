import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeShellBoundaryLoweringJson

open Lean

namespace UOToolchain

def importedRuntimeConfidentialCoreShellBoundaryLoweringBundleFieldNames : List String :=
  [ "runtime_witness"
  , "shell_boundary_bundle"
  , "confidential_program"
  , "confidential_slot_program"
  ]

structure ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle where
  runtime_witness : ImportedRuntimeRefinementWitness
  shell_boundary_bundle : ImportedRuntimeShellBoundaryBundle
  confidential_program : ImportedConfidentialKernelProgram
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.confidentialCoreLoweringBundle
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle) :
  ImportedRuntimeConfidentialCoreLoweringBundle :=
  { runtime_witness := bundle.runtime_witness
  , confidential_program := bundle.confidential_program
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.shellBoundaryLoweringBundle
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle) :
  ImportedRuntimeShellBoundaryLoweringBundle :=
  { shell_boundary_bundle := bundle.shell_boundary_bundle
  , confidential_program := bundle.confidential_program
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.confidentialCoreLoweringBundle.Valid modelTags ∧
    bundle.shellBoundaryLoweringBundle.Valid ∧
    bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness ∧
    bundle.runtime_witness.runtime_kernel_refinement_witness =
      some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness

def ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.confidentialCoreLoweringBundle.checkValid modelTags &&
    bundle.shellBoundaryLoweringBundle.checkValid &&
    decide (bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness) &&
    decide
      (bundle.runtime_witness.runtime_kernel_refinement_witness =
        some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness)

def ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.toRuntimeConfidentialCoreShellBoundaryLoweringBundle?
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle) :
  Except String RuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let lowered ← bundle.confidential_program.toConfidentialKernelSlotProgram?
  pure
    { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
    , shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    }

@[simp]
theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.checkValid
    ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.Valid
    ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.confidentialCoreLoweringBundle
    ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.shellBoundaryLoweringBundle
  simp [importedRuntimeConfidentialCoreLoweringBundle_checkValid_eq_true_iff,
    importedRuntimeShellBoundaryLoweringBundle_checkValid_eq_true_iff, and_assoc]

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_kernelWitness_exact
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness := by
  exact hValid.2.2.1

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_runtimeKernelRefinementWitness_exact
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.runtime_witness.runtime_kernel_refinement_witness =
      some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness := by
  exact hValid.2.2.2

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_shellRefines
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.Refines
      bundle.shell_boundary_bundle.kernel_witness.shellContract := by
  exact importedRuntimeShellBoundaryLoweringBundle_shellRefines hValid.2.1

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_lowering_exact
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program = true := by
  exact importedRuntimeShellBoundaryLoweringBundle_lowering_exact hValid.2.1

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_namedSchedule_exact
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_program.expectedRuntimeKernelSteps ∧
    bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.confidential_program.expectedRuntimeKernelSteps := by
  exact importedRuntimeShellBoundaryLoweringBundle_namedSchedule_exact hValid.2.1

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_recomputedSlotSchedule_exact
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some lowered.expectedRuntimeKernelSteps ∧
      bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        lowered.expectedRuntimeKernelSteps := by
  exact importedRuntimeShellBoundaryLoweringBundle_recomputedSlotSchedule_exact hValid.2.1

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness ∧
      bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.Refines
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
        bundle.confidential_program bundle.confidential_slot_program = true := by
  have hKernelExact :
      bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness := by
    exact
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_kernelWitness_exact
        hValid
  have hRefinementExact :
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness := by
    exact
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_runtimeKernelRefinementWitness_exact
        hValid
  have hShellRefines :
      bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.Refines
        bundle.shell_boundary_bundle.kernel_witness.shellContract := by
    exact
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_shellRefines
        hValid
  have hNamed :
      bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
          some bundle.confidential_program.expectedRuntimeKernelSteps ∧
        bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
          bundle.confidential_program.expectedRuntimeKernelSteps := by
    exact
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_namedSchedule_exact
        hValid
  rcases
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_recomputedSlotSchedule_exact
        hValid with
    ⟨lowered, hLowered, hLoweredExpected, hLoweredSteps⟩
  have hLowering :
      checkImportedConfidentialKernelProgramSlotLowering
          bundle.confidential_program bundle.confidential_slot_program = true := by
    exact
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_lowering_exact
        hValid
  exact
    ⟨lowered, hLowered, hKernelExact, hRefinementExact, hShellRefines, hNamed.1, hNamed.2,
      hLoweredExpected, hLoweredSteps, hLowering⟩

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_lowered_toRuntimeValid
  {bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags)
  {lowered : ImportedConfidentialKernelSlotProgram}
  (hLowered : bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered) :
  RuntimeConfidentialCoreShellBoundaryLoweringBundle.Valid
    { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
    , shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    } modelTags := by
  have hCore :
      RuntimeConfidentialCoreLoweringBundle.Valid
        { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } modelTags := by
    exact importedRuntimeConfidentialCoreLoweringBundle_lowered_toRuntimeValid
      hValid.1 hLowered
  have hShell :
      RuntimeShellBoundaryLoweringBundle.Valid
        { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } := by
    exact importedRuntimeShellBoundaryLoweringBundle_lowered_toRuntimeValid
      hValid.2.1 hLowered
  have hKernelExact :
      bundle.runtime_witness.toRuntimeWitness.kernelWitness =
        some bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness := by
    simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using
      congrArg (Option.map ImportedRuntimeKernelWitness.toRuntimeKernelWitness) hValid.2.2.1
  have hRefinementExact :
      bundle.runtime_witness.toRuntimeWitness.runtimeKernelRefinementWitness =
        some bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.runtimeKernelRefinementWitness := by
    simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using
      congrArg
        (Option.map ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness)
        hValid.2.2.2
  exact ⟨hCore, hShell, hKernelExact, hRefinementExact⟩

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      RuntimeConfidentialCoreShellBoundaryLoweringBundle.Valid
        { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
        , shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } modelTags := by
  rcases
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_recomputedSlotSchedule_exact
        hValid with
    ⟨lowered, hLowered, _, _⟩
  exact
    ⟨lowered, hLowered,
      importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_lowered_toRuntimeValid
        hValid hLowered⟩

theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_toRuntimeBundle_sound
  (bundle : ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ runtimeBundle,
    bundle.toRuntimeConfidentialCoreShellBoundaryLoweringBundle? = .ok runtimeBundle ∧
      runtimeBundle.Valid modelTags := by
  rcases importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_toRuntimeValid
      bundle modelTags hValid with
    ⟨lowered, hLowered, hRuntimeValid⟩
  refine ⟨{ runtimeWitness := bundle.runtime_witness.toRuntimeWitness
          , shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
          , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
          , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
          }, ?_, hRuntimeValid⟩
  unfold ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle.toRuntimeConfidentialCoreShellBoundaryLoweringBundle?
  rw [hLowered]
  rfl

def parseImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core shell-boundary lowering bundle does not satisfy Lean validity checks"

def parseAndCheckImportedRuntimeConfidentialCoreShellBoundaryLoweringBundleToRuntimeBundle
  (input : String)
  (modelTags : SGXModelTags) :
  Except String RuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let bundle ← parseAndCheckImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle input modelTags
  match bundle.toRuntimeConfidentialCoreShellBoundaryLoweringBundle? with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw
        s!"validated imported runtime confidential-core shell-boundary lowering bundle failed to recompute runtime lowering bundle: {err}"

def loadImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle
  (path : System.FilePath) :
  IO ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential-core shell-boundary lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundaryLoweringBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) :
  IO ImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeConfidentialCoreShellBoundaryLoweringBundle
      input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core shell-boundary lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundaryLoweringBundleToRuntimeBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) :
  IO RuntimeConfidentialCoreShellBoundaryLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeConfidentialCoreShellBoundaryLoweringBundleToRuntimeBundle
      input modelTags with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate/recompute runtime confidential-core shell-boundary lowering bundle: {err}"

end UOToolchain
