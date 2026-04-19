import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssurance
import UOToolchain.RuntimeKernelDslJson
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

def ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle
  (bundle : ImportedRuntimeShellBoundaryBundle) : RuntimeShellBoundaryBundle :=
  { kernelWitness := bundle.kernel_witness.toRuntimeKernelWitness
  , runtimeKernelRefinementWitness :=
      bundle.runtime_kernel_refinement_witness.toRuntimeKernelRefinementWitness
  , shellContract := bundle.shell_contract.toRuntimeShellContract
  , shellTrace := bundle.shell_trace.toRuntimeShellTrace
  }

theorem importedRuntimeShellBoundaryBundle_toRuntimeValid
  (bundle : ImportedRuntimeShellBoundaryBundle)
  (hValid : bundle.Valid) :
  bundle.toRuntimeShellBoundaryBundle.Valid := by
  unfold ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle
    RuntimeShellBoundaryBundle.Valid
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · exact
      importedRuntimeKernelWitness_toRuntimeKernelWitness_proofGradeValid
        bundle.kernel_witness bundle.kernel_witness.entrypoint_id hValid.1
  · simpa [ImportedRuntimeKernelRefinementWitness.Valid] using hValid.2.1
  · simpa using
      congrArg ImportedRuntimeShellContract.toRuntimeShellContract
        (importedRuntimeShellBoundaryBundle_contract_exact hValid)
  · simpa using
      congrArg ImportedRuntimeShellTrace.toRuntimeShellTrace
        (importedRuntimeShellBoundaryBundle_trace_exact hValid)
  · exact importedRuntimeShellTrace_refines_toRuntime
      (importedRuntimeShellBoundaryBundle_refines hValid)

def ImportedRuntimeConfidentialCoreAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelProgram)
  (modelTags : SGXModelTags) : Prop :=
  runtimeWitness.ProofGradeValid modelTags ∧
    ∃ kernelWitness,
      runtimeWitness.kernel_witness = some kernelWitness ∧
        (ImportedRuntimeKernelDslBundle.Valid
          { kernel_witness := kernelWitness
          , confidential_program := program
          })

def checkImportedRuntimeConfidentialCoreAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelProgram)
  (modelTags : SGXModelTags) : Bool :=
  runtimeWitness.checkProofGrade modelTags &&
    match runtimeWitness.kernel_witness with
    | none => false
    | some kernelWitness =>
        ImportedRuntimeKernelDslBundle.checkValid
          { kernel_witness := kernelWitness
          , confidential_program := program
          }

@[simp] theorem importedRuntimeConfidentialCoreAssurance_check_eq_true_iff
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelProgram)
  (modelTags : SGXModelTags) :
  checkImportedRuntimeConfidentialCoreAssurance runtimeWitness program modelTags = true ↔
    ImportedRuntimeConfidentialCoreAssurance runtimeWitness program modelTags := by
  cases hKernel : runtimeWitness.kernel_witness with
  | none =>
      unfold checkImportedRuntimeConfidentialCoreAssurance
        ImportedRuntimeConfidentialCoreAssurance
      simp [hKernel]
  | some kernelWitness =>
      unfold checkImportedRuntimeConfidentialCoreAssurance
        ImportedRuntimeConfidentialCoreAssurance
      simp [hKernel, importedWitness_checkProofGrade_eq_true_iff,
        importedRuntimeKernelDslBundle_checkValid_eq_true_iff]

theorem importedWitness_proofGradeConfidentialCoreAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelProgram)
  (modelTags : SGXModelTags)
  (hAssured : ImportedRuntimeConfidentialCoreAssurance runtimeWitness program modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    runtimeWitness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps = some program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = program.expectedRuntimeKernelSteps ∧
      runtimeWitness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  rcases hAssured with ⟨hRuntimeValid, kernelWitness, hKernel, hDslValid⟩
  have hScheduleExact :
      kernelWitness.expected_kernel_steps = some program.expectedRuntimeKernelSteps ∧
        kernelWitness.kernel_steps = program.expectedRuntimeKernelSteps :=
    importedRuntimeKernelDslBundle_schedule_exact hDslValid
  rcases importedWitness_proofGradeShellContractRefinement runtimeWitness modelTags hRuntimeValid with
    ⟨kernelWitness', runtimeKernelRefinementWitness, hKernel', hRefinement, hShellRefines⟩
  have hKernelEq : kernelWitness = kernelWitness' := by
    apply Option.some.inj
    exact hKernel.symm.trans hKernel'
  subst hKernelEq
  exact
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel', hScheduleExact.1,
      hScheduleExact.2, hRefinement, hShellRefines⟩

theorem importedWitness_toRuntimeWitness_proofGradeConfidentialCoreAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelProgram)
  (modelTags : SGXModelTags)
  (hAssured : ImportedRuntimeConfidentialCoreAssurance runtimeWitness program modelTags) :
  RuntimeConfidentialCoreAssurance
    runtimeWitness.toRuntimeWitness program.toConfidentialKernelProgram modelTags := by
  rcases hAssured with ⟨hRuntimeValid, kernelWitness, hKernel, hDslValid⟩
  have hRuntimeProofGrade :
      runtimeWitness.toRuntimeWitness.ProofGradeValid modelTags := by
    exact
      importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        runtimeWitness modelTags hRuntimeValid
  have hScheduleExact :
      kernelWitness.toRuntimeKernelWitness.expectedKernelSteps =
          some program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
        kernelWitness.toRuntimeKernelWitness.kernelSteps =
          program.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
    exact importedRuntimeKernelDslBundle_toRuntimeSchedule_exact hDslValid
  refine ⟨hRuntimeProofGrade, ?_⟩
  exact
    ⟨kernelWitness.toRuntimeKernelWitness,
      by simp [ImportedRuntimeRefinementWitness.toRuntimeWitness, hKernel],
      hScheduleExact.1, hScheduleExact.2⟩

structure ImportedRuntimeConfidentialCoreBundle where
  runtime_witness : ImportedRuntimeRefinementWitness
  confidential_program : ImportedConfidentialKernelProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags) : Prop :=
  ImportedRuntimeConfidentialCoreAssurance
    bundle.runtime_witness bundle.confidential_program modelTags

def ImportedRuntimeConfidentialCoreBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags) : Bool :=
  checkImportedRuntimeConfidentialCoreAssurance
    bundle.runtime_witness bundle.confidential_program modelTags

def ImportedRuntimeConfidentialCoreBundle.toRuntimeConfidentialCoreBundle
  (bundle : ImportedRuntimeConfidentialCoreBundle) : RuntimeConfidentialCoreBundle :=
  { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
  , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
  }

@[simp] theorem importedRuntimeConfidentialCoreBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialCoreBundle.checkValid
    ImportedRuntimeConfidentialCoreBundle.Valid
  simp [importedRuntimeConfidentialCoreAssurance_check_eq_true_iff]

theorem importedRuntimeConfidentialCoreBundle_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  exact importedWitness_proofGradeConfidentialCoreAssurance
    bundle.runtime_witness bundle.confidential_program modelTags hValid

theorem importedRuntimeConfidentialCoreBundle_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreBundle.Valid modelTags := by
  exact importedWitness_toRuntimeWitness_proofGradeConfidentialCoreAssurance
    bundle.runtime_witness bundle.confidential_program modelTags hValid

def parseImportedRuntimeConfidentialCoreBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeConfidentialCoreBundle
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeConfidentialCoreBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core bundle does not satisfy Lean validity checks"

def loadImportedRuntimeConfidentialCoreBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime confidential-core bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeConfidentialCoreBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeConfidentialCoreBundle input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core bundle: {err}"

def ImportedRuntimeConfidentialCoreSlotAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags) : Prop :=
  runtimeWitness.ProofGradeValid modelTags ∧
    ∃ kernelWitness,
      runtimeWitness.kernel_witness = some kernelWitness ∧
        (ImportedRuntimeKernelSlotDslBundle.Valid
          { kernel_witness := kernelWitness
          , confidential_slot_program := program
          })

def checkImportedRuntimeConfidentialCoreSlotAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags) : Bool :=
  runtimeWitness.checkProofGrade modelTags &&
    match runtimeWitness.kernel_witness with
    | none => false
    | some kernelWitness =>
        ImportedRuntimeKernelSlotDslBundle.checkValid
          { kernel_witness := kernelWitness
          , confidential_slot_program := program
          }

@[simp] theorem importedRuntimeConfidentialCoreSlotAssurance_check_eq_true_iff
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags) :
  checkImportedRuntimeConfidentialCoreSlotAssurance runtimeWitness program modelTags = true ↔
    ImportedRuntimeConfidentialCoreSlotAssurance runtimeWitness program modelTags := by
  cases hKernel : runtimeWitness.kernel_witness with
  | none =>
      unfold checkImportedRuntimeConfidentialCoreSlotAssurance
        ImportedRuntimeConfidentialCoreSlotAssurance
      simp [hKernel]
  | some kernelWitness =>
      unfold checkImportedRuntimeConfidentialCoreSlotAssurance
        ImportedRuntimeConfidentialCoreSlotAssurance
      simp [hKernel, importedWitness_checkProofGrade_eq_true_iff,
        importedRuntimeKernelSlotDslBundle_checkValid_eq_true_iff]

theorem importedWitness_proofGradeConfidentialCoreSlotAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured : ImportedRuntimeConfidentialCoreSlotAssurance runtimeWitness program modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    runtimeWitness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps = some program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = program.expectedRuntimeKernelSteps ∧
      runtimeWitness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  rcases hAssured with ⟨hRuntimeValid, kernelWitness, hKernel, hDslValid⟩
  have hScheduleExact :
      kernelWitness.expected_kernel_steps = some program.expectedRuntimeKernelSteps ∧
        kernelWitness.kernel_steps = program.expectedRuntimeKernelSteps :=
    importedRuntimeKernelSlotDslBundle_schedule_exact hDslValid
  rcases importedWitness_proofGradeShellContractRefinement runtimeWitness modelTags hRuntimeValid with
    ⟨kernelWitness', runtimeKernelRefinementWitness, hKernel', hRefinement, hShellRefines⟩
  have hKernelEq : kernelWitness = kernelWitness' := by
    apply Option.some.inj
    exact hKernel.symm.trans hKernel'
  subst hKernelEq
  exact
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel', hScheduleExact.1,
      hScheduleExact.2, hRefinement, hShellRefines⟩

theorem importedWitness_toRuntimeWitness_proofGradeConfidentialCoreSlotAssurance
  (runtimeWitness : ImportedRuntimeRefinementWitness)
  (program : ImportedConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured : ImportedRuntimeConfidentialCoreSlotAssurance runtimeWitness program modelTags) :
  RuntimeConfidentialCoreSlotAssurance
    runtimeWitness.toRuntimeWitness program.toConfidentialKernelSlotProgram modelTags := by
  rcases hAssured with ⟨hRuntimeValid, kernelWitness, hKernel, hDslValid⟩
  have hRuntimeProofGrade :
      runtimeWitness.toRuntimeWitness.ProofGradeValid modelTags := by
    exact
      importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
        runtimeWitness modelTags hRuntimeValid
  have hScheduleExact :
      kernelWitness.toRuntimeKernelWitness.expectedKernelSteps =
          some program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
        kernelWitness.toRuntimeKernelWitness.kernelSteps =
          program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    exact importedRuntimeKernelSlotDslBundle_toRuntimeSchedule_exact hDslValid
  refine ⟨hRuntimeProofGrade, ?_⟩
  exact
    ⟨kernelWitness.toRuntimeKernelWitness,
      by simp [ImportedRuntimeRefinementWitness.toRuntimeWitness, hKernel],
      hScheduleExact.1, hScheduleExact.2⟩

def importedRuntimeConfidentialCoreSlotBundleFieldNames : List String :=
  ["runtime_witness", "confidential_slot_program"]

structure ImportedRuntimeConfidentialCoreSlotBundle where
  runtime_witness : ImportedRuntimeRefinementWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreSlotBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  ImportedRuntimeConfidentialCoreSlotAssurance
    bundle.runtime_witness bundle.confidential_slot_program modelTags

def ImportedRuntimeConfidentialCoreSlotBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags) : Bool :=
  checkImportedRuntimeConfidentialCoreSlotAssurance
    bundle.runtime_witness bundle.confidential_slot_program modelTags

def ImportedRuntimeConfidentialCoreSlotBundle.toRuntimeConfidentialCoreSlotBundle
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle) : RuntimeConfidentialCoreSlotBundle :=
  { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
  , confidentialProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
  }

@[simp] theorem importedRuntimeConfidentialCoreSlotBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialCoreSlotBundle.checkValid
    ImportedRuntimeConfidentialCoreSlotBundle.Valid
  simp [importedRuntimeConfidentialCoreSlotAssurance_check_eq_true_iff]

theorem importedRuntimeConfidentialCoreSlotBundle_proofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = bundle.confidential_slot_program.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  exact importedWitness_proofGradeConfidentialCoreSlotAssurance
    bundle.runtime_witness bundle.confidential_slot_program modelTags hValid

theorem importedRuntimeConfidentialCoreSlotBundle_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreSlotBundle.Valid modelTags := by
  exact importedWitness_toRuntimeWitness_proofGradeConfidentialCoreSlotAssurance
    bundle.runtime_witness bundle.confidential_slot_program modelTags hValid

def parseImportedRuntimeConfidentialCoreSlotBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreSlotBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeConfidentialCoreSlotBundle
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeConfidentialCoreSlotBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreSlotBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core slot bundle does not satisfy Lean validity checks"

def loadImportedRuntimeConfidentialCoreSlotBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreSlotBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreSlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime confidential-core slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreSlotBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeConfidentialCoreSlotBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeConfidentialCoreSlotBundle input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core slot bundle: {err}"

def importedRuntimeConfidentialCoreLoweringBundleFieldNames : List String :=
  ["runtime_witness", "confidential_program", "confidential_slot_program"]

structure ImportedRuntimeConfidentialCoreLoweringBundle where
  runtime_witness : ImportedRuntimeRefinementWitness
  confidential_program : ImportedConfidentialKernelProgram
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreLoweringBundle.namedBundle
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle) : ImportedRuntimeConfidentialCoreBundle :=
  { runtime_witness := bundle.runtime_witness
  , confidential_program := bundle.confidential_program
  }

def ImportedRuntimeConfidentialCoreLoweringBundle.slotBundle
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle) :
  ImportedRuntimeConfidentialCoreSlotBundle :=
  { runtime_witness := bundle.runtime_witness
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeConfidentialCoreLoweringBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.namedBundle.Valid modelTags ∧
    bundle.confidential_program.SlotLoweringMatches bundle.confidential_slot_program

def ImportedRuntimeConfidentialCoreLoweringBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.namedBundle.checkValid modelTags &&
    checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program

def ImportedRuntimeConfidentialCoreLoweringBundle.toRuntimeConfidentialCoreLoweringBundle?
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle) :
  Except String RuntimeConfidentialCoreLoweringBundle := do
  let lowered ← bundle.confidential_program.toConfidentialKernelSlotProgram?
  pure
    { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    }

@[simp] theorem importedRuntimeConfidentialCoreLoweringBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialCoreLoweringBundle.checkValid
    ImportedRuntimeConfidentialCoreLoweringBundle.Valid
    ImportedRuntimeConfidentialCoreLoweringBundle.namedBundle
  simp [importedRuntimeConfidentialCoreBundle_checkValid_eq_true_iff,
    checkImportedConfidentialKernelProgramSlotLowering_eq_true_iff, and_assoc]

theorem importedRuntimeConfidentialCoreLoweringBundle_lowering_exact
  {bundle : ImportedRuntimeConfidentialCoreLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program = true := by
  exact hValid.2

theorem importedRuntimeConfidentialCoreLoweringBundle_namedProofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some bundle.confidential_program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = bundle.confidential_program.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  exact importedRuntimeConfidentialCoreBundle_proofGradeAssurance
    bundle.namedBundle modelTags hValid.1

theorem importedRuntimeConfidentialCoreLoweringBundle_recomputedSlotProofGradeAssurance
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered kernelWitness runtimeKernelRefinementWitness,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.runtime_witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps =
        some lowered.expectedRuntimeKernelSteps ∧
      kernelWitness.kernel_steps = lowered.expectedRuntimeKernelSteps ∧
      bundle.runtime_witness.runtime_kernel_refinement_witness =
        some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  rcases importedRuntimeConfidentialCoreLoweringBundle_namedProofGradeAssurance
      bundle modelTags hValid with
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel, hNamedExpected, hNamedSteps,
      hRefinement, hShellRefines⟩
  rcases importedConfidentialKernelProgram_slotLowering_exists
      bundle.confidential_program bundle.confidential_slot_program hValid.2 with
    ⟨lowered, hLowered⟩
  have hSteps :
      bundle.confidential_program.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps := by
    exact importedConfidentialKernelProgram_slotLowering_ok_expectedRuntimeKernelSteps hLowered
  exact
    ⟨lowered, kernelWitness, runtimeKernelRefinementWitness, hLowered, hKernel,
      by simpa [hSteps] using hNamedExpected,
      by simpa [hSteps] using hNamedSteps,
      hRefinement, hShellRefines⟩

theorem importedRuntimeConfidentialCoreLoweringBundle_lowered_toRuntimeValid
  {bundle : ImportedRuntimeConfidentialCoreLoweringBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags)
  {lowered : ImportedConfidentialKernelSlotProgram}
  (hLowered : bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered) :
  RuntimeConfidentialCoreLoweringBundle.Valid
    { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    } modelTags := by
  have hNamed :
      RuntimeConfidentialCoreAssurance
        bundle.runtime_witness.toRuntimeWitness
        bundle.confidential_program.toConfidentialKernelProgram modelTags := by
    simpa [ImportedRuntimeConfidentialCoreBundle.toRuntimeConfidentialCoreBundle,
      ImportedRuntimeConfidentialCoreLoweringBundle.namedBundle] using
      importedRuntimeConfidentialCoreBundle_toRuntimeValid
        bundle.namedBundle modelTags hValid.1
  have hLowering :
      bundle.confidential_program.toConfidentialKernelProgram.SlotLoweringMatches
        lowered.toConfidentialKernelSlotProgram := by
    exact importedConfidentialKernelProgram_slotLowering_ok_toRuntime hLowered
  exact ⟨hNamed, hLowering⟩

theorem importedRuntimeConfidentialCoreLoweringBundle_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      RuntimeConfidentialCoreLoweringBundle.Valid
        { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } modelTags := by
  rcases importedConfidentialKernelProgram_slotLowering_exists
      bundle.confidential_program bundle.confidential_slot_program hValid.2 with
    ⟨lowered, hLowered⟩
  exact
    ⟨lowered, hLowered,
      importedRuntimeConfidentialCoreLoweringBundle_lowered_toRuntimeValid
        hValid hLowered⟩

theorem importedRuntimeConfidentialCoreLoweringBundle_toRuntimeBundle_sound
  (bundle : ImportedRuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ runtimeBundle,
    bundle.toRuntimeConfidentialCoreLoweringBundle? = .ok runtimeBundle ∧
      runtimeBundle.Valid modelTags := by
  rcases importedRuntimeConfidentialCoreLoweringBundle_toRuntimeValid
      bundle modelTags hValid with
    ⟨lowered, hLowered, hRuntimeValid⟩
  refine ⟨{ runtimeWitness := bundle.runtime_witness.toRuntimeWitness
          , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
          , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
          }, ?_, hRuntimeValid⟩
  unfold ImportedRuntimeConfidentialCoreLoweringBundle.toRuntimeConfidentialCoreLoweringBundle?
  rw [hLowered]
  rfl

def parseImportedRuntimeConfidentialCoreLoweringBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreLoweringBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeConfidentialCoreLoweringBundle
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedRuntimeConfidentialCoreLoweringBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreLoweringBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core lowering bundle does not satisfy Lean validity checks"

def parseAndCheckImportedRuntimeConfidentialCoreLoweringBundleToRuntimeBundle
  (input : String)
  (modelTags : SGXModelTags) :
  Except String RuntimeConfidentialCoreLoweringBundle := do
  let bundle ← parseAndCheckImportedRuntimeConfidentialCoreLoweringBundle input modelTags
  match bundle.toRuntimeConfidentialCoreLoweringBundle? with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw
        s!"validated imported runtime confidential-core lowering bundle failed to recompute runtime lowering bundle: {err}"

def loadImportedRuntimeConfidentialCoreLoweringBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreLoweringBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime confidential-core lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreLoweringBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeConfidentialCoreLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeConfidentialCoreLoweringBundle input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreLoweringBundleToRuntimeBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO RuntimeConfidentialCoreLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeConfidentialCoreLoweringBundleToRuntimeBundle input modelTags with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate/recompute runtime confidential-core lowering bundle: {err}"

end UOToolchain
