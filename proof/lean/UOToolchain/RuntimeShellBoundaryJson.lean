import Lean.Data.Json
import UOToolchain.RuntimeShellBoundary
import UOToolchain.RuntimeRefinementJson

open Lean

namespace UOToolchain

instance : FromJson ImportedRuntimeKernelSchedule where
  fromJson? j := do
    pure
      { opcodes := ← j.getObjValAs? (List String) "opcodes"
      , steps := ← j.getObjValAs? (List ImportedRuntimeKernelStep) "steps"
      }

instance : ToJson ImportedRuntimeKernelSchedule where
  toJson schedule :=
    Json.mkObj
      [ ("opcodes", toJson schedule.opcodes)
      , ("steps", toJson schedule.steps)
      ]

def importedRuntimeShellContractFieldNames : List String :=
  ["public_object_universe", "canonical_loaded_object_schedule", "kernel_schedule"]

def importedRuntimeShellTraceFieldNames : List String :=
  [ "events"
  , "projected_kernel_schedule"
  , "pre_committed_cold_object_schedule"
  , "shadow_load_object_schedule"
  , "commit_object_schedule"
  , "cold_store_object_schedule"
  , "post_committed_cold_object_schedule"
  ]

def importedRuntimeShellBoundaryBundleFieldNames : List String :=
  [ "kernel_witness"
  , "runtime_kernel_refinement_witness"
  , "shell_contract"
  , "shell_trace"
  ]

structure ImportedRuntimeShellContract where
  public_object_universe : List Nat
  canonical_loaded_object_schedule : List Nat
  kernel_schedule : ImportedRuntimeKernelSchedule
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedRuntimeShellTrace where
  events : List ImportedRuntimeKernelRefinementEvent
  projected_kernel_schedule : ImportedRuntimeKernelSchedule
  pre_committed_cold_object_schedule : List Nat
  shadow_load_object_schedule : List Nat
  commit_object_schedule : List Nat
  cold_store_object_schedule : List Nat
  post_committed_cold_object_schedule : List Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeShellContract.toRuntimeShellContract
  (contract : ImportedRuntimeShellContract) : RuntimeShellContract :=
  { publicObjectUniverse := contract.public_object_universe
  , canonicalLoadedObjectSchedule := contract.canonical_loaded_object_schedule
  , kernelSchedule := contract.kernel_schedule.toRuntimeKernelSchedule
  }

def ImportedRuntimeShellTrace.toRuntimeShellTrace
  (trace : ImportedRuntimeShellTrace) : RuntimeShellTrace :=
  { events := trace.events.map ImportedRuntimeKernelRefinementEvent.toRuntimeKernelRefinementEvent
  , projectedKernelSchedule := trace.projected_kernel_schedule.toRuntimeKernelSchedule
  , preCommittedColdObjectSchedule := trace.pre_committed_cold_object_schedule
  , shadowLoadObjectSchedule := trace.shadow_load_object_schedule
  , commitObjectSchedule := trace.commit_object_schedule
  , coldStoreObjectSchedule := trace.cold_store_object_schedule
  , postCommittedColdObjectSchedule := trace.post_committed_cold_object_schedule
  }

def ImportedRuntimeShellTrace.Refines
  (trace : ImportedRuntimeShellTrace)
  (contract : ImportedRuntimeShellContract) : Prop :=
  trace.toRuntimeShellTrace.ProofGradeRefines contract.toRuntimeShellContract

def ImportedRuntimeShellTrace.checkRefines
  (trace : ImportedRuntimeShellTrace)
  (contract : ImportedRuntimeShellContract) : Bool :=
  trace.toRuntimeShellTrace.checkProofGradeRefines contract.toRuntimeShellContract

@[simp] theorem importedRuntimeShellTrace_checkRefines_eq_true_iff
  (trace : ImportedRuntimeShellTrace)
  (contract : ImportedRuntimeShellContract) :
  trace.checkRefines contract = true ↔ trace.Refines contract := by
  unfold ImportedRuntimeShellTrace.checkRefines ImportedRuntimeShellTrace.Refines
  simp [runtimeShellTrace_checkProofGradeRefines_eq_true_iff]

theorem importedRuntimeShellTrace_refines_toRuntime
  {trace : ImportedRuntimeShellTrace}
  {contract : ImportedRuntimeShellContract}
  (hRefines : trace.Refines contract) :
  trace.toRuntimeShellTrace.ProofGradeRefines contract.toRuntimeShellContract := by
  exact hRefines

theorem importedRuntimeShellTrace_refines_toRuntimeRefines
  {trace : ImportedRuntimeShellTrace}
  {contract : ImportedRuntimeShellContract}
  (hRefines : trace.Refines contract) :
  trace.toRuntimeShellTrace.Refines contract.toRuntimeShellContract := by
  exact (importedRuntimeShellTrace_refines_toRuntime hRefines).2.2

def ImportedRuntimeKernelWitness.importedShellContract
  (witness : ImportedRuntimeKernelWitness) : ImportedRuntimeShellContract :=
  { public_object_universe := witness.public_object_ids
  , canonical_loaded_object_schedule :=
      witness.toRuntimeKernelWitness.canonicalLoadedObjectSchedule
  , kernel_schedule := witness.emittedKernelSchedule
  }

def ImportedRuntimeKernelWitness.shellContract
  (witness : ImportedRuntimeKernelWitness) : RuntimeShellContract :=
  witness.importedShellContract.toRuntimeShellContract

@[simp] theorem importedRuntimeKernelWitness_importedShellContract_toRuntime
  (witness : ImportedRuntimeKernelWitness) :
  witness.importedShellContract.toRuntimeShellContract =
    witness.toRuntimeKernelWitness.shellContract := by
  unfold ImportedRuntimeKernelWitness.importedShellContract
    ImportedRuntimeShellContract.toRuntimeShellContract RuntimeKernelWitness.shellContract
    ImportedRuntimeKernelWitness.emittedKernelSchedule
  simp [ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule,
    RuntimeKernelWitness.emittedKernelSchedule, ImportedRuntimeKernelWitness.toRuntimeKernelWitness]

def ImportedRuntimeKernelRefinementWitness.importedShellTrace
  (witness : ImportedRuntimeKernelRefinementWitness) : ImportedRuntimeShellTrace :=
  { events := witness.events
  , projected_kernel_schedule :=
      { opcodes := witness.toRuntimeKernelRefinementWitness.projectedKernelSchedule.opcodes
      , steps := witness.toRuntimeKernelRefinementWitness.projectedKernelSchedule.steps.map
          fun step =>
            { opcode := step.opcode
            , object_id := step.objectId
            }
      }
  , pre_committed_cold_object_schedule :=
      witness.toRuntimeKernelRefinementWitness.preCommittedColdObjectSchedule
  , shadow_load_object_schedule :=
      witness.toRuntimeKernelRefinementWitness.shadowLoadObjectSchedule
  , commit_object_schedule :=
      witness.toRuntimeKernelRefinementWitness.commitObjectSchedule
  , cold_store_object_schedule :=
      witness.toRuntimeKernelRefinementWitness.coldStoreObjectSchedule
  , post_committed_cold_object_schedule :=
      witness.toRuntimeKernelRefinementWitness.postCommittedColdObjectSchedule
  }

def ImportedRuntimeKernelRefinementWitness.shellTrace
  (witness : ImportedRuntimeKernelRefinementWitness) : RuntimeShellTrace :=
  witness.importedShellTrace.toRuntimeShellTrace

@[simp] theorem importedRuntimeKernelStep_runtimeRoundtrip
  (step : RuntimeKernelStep) :
  ({ opcode := step.opcode, object_id := step.objectId } :
      ImportedRuntimeKernelStep).toRuntimeKernelStep = step := by
  cases step
  rfl

@[simp] theorem importedRuntimeKernelStep_runtimeRoundtrip_comp :
  ImportedRuntimeKernelStep.toRuntimeKernelStep ∘
      (fun step : RuntimeKernelStep =>
        ({ opcode := step.opcode, object_id := step.objectId } : ImportedRuntimeKernelStep)) =
    id := by
  funext step
  exact importedRuntimeKernelStep_runtimeRoundtrip step

@[simp] theorem importedRuntimeKernelRefinementWitness_importedShellTrace_toRuntime
  (witness : ImportedRuntimeKernelRefinementWitness) :
  witness.importedShellTrace.toRuntimeShellTrace =
    witness.toRuntimeKernelRefinementWitness.shellTrace := by
  unfold ImportedRuntimeKernelRefinementWitness.importedShellTrace
    ImportedRuntimeShellTrace.toRuntimeShellTrace RuntimeKernelRefinementWitness.shellTrace
    RuntimeKernelRefinementWitness.projectedKernelSchedule
    RuntimeKernelRefinementWitness.preCommittedColdObjectSchedule
    RuntimeKernelRefinementWitness.shadowLoadObjectSchedule
    RuntimeKernelRefinementWitness.commitObjectSchedule
    RuntimeKernelRefinementWitness.coldStoreObjectSchedule
    RuntimeKernelRefinementWitness.postCommittedColdObjectSchedule
    ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness
    ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule
    ImportedRuntimeKernelRefinementEvent.toRuntimeKernelRefinementEvent
  simp [importedRuntimeKernelStep_runtimeRoundtrip_comp]

structure ImportedRuntimeShellBoundaryBundle where
  kernel_witness : ImportedRuntimeKernelWitness
  runtime_kernel_refinement_witness : ImportedRuntimeKernelRefinementWitness
  shell_contract : ImportedRuntimeShellContract
  shell_trace : ImportedRuntimeShellTrace
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeRefinementWitness.shellBoundaryBundle?
  (witness : ImportedRuntimeRefinementWitness) : Option ImportedRuntimeShellBoundaryBundle := do
  let kernelWitness ← witness.kernel_witness
  let runtimeKernelRefinementWitness ← witness.runtime_kernel_refinement_witness
  pure
    { kernel_witness := kernelWitness
    , runtime_kernel_refinement_witness := runtimeKernelRefinementWitness
    , shell_contract := kernelWitness.importedShellContract
    , shell_trace := runtimeKernelRefinementWitness.importedShellTrace
    }

def ImportedRuntimeShellBoundaryBundle.Valid
  (bundle : ImportedRuntimeShellBoundaryBundle) : Prop :=
  bundle.kernel_witness.ProofGradeValid bundle.kernel_witness.entrypoint_id ∧
    bundle.runtime_kernel_refinement_witness.Valid bundle.kernel_witness ∧
    bundle.shell_contract = bundle.kernel_witness.importedShellContract ∧
    bundle.shell_trace = bundle.runtime_kernel_refinement_witness.importedShellTrace ∧
    bundle.shell_trace.Refines bundle.shell_contract

theorem importedRuntimeRefinementWitness_shellBoundaryBundle_exact
  {witness : ImportedRuntimeRefinementWitness}
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hBundle : witness.shellBoundaryBundle? = some bundle) :
  witness.kernel_witness = some bundle.kernel_witness ∧
    witness.runtime_kernel_refinement_witness = some bundle.runtime_kernel_refinement_witness ∧
    bundle.shell_contract = bundle.kernel_witness.importedShellContract ∧
    bundle.shell_trace = bundle.runtime_kernel_refinement_witness.importedShellTrace := by
  unfold ImportedRuntimeRefinementWitness.shellBoundaryBundle? at hBundle
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [hKernel] at hBundle
  | some kernelWitness =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [hKernel, hRefinement] at hBundle
      | some runtimeKernelRefinementWitness =>
          have hBundleSome :
              some
                  { kernel_witness := kernelWitness
                  , runtime_kernel_refinement_witness := runtimeKernelRefinementWitness
                  , shell_contract := kernelWitness.importedShellContract
                  , shell_trace := runtimeKernelRefinementWitness.importedShellTrace
                  } =
                some bundle := by
            simpa [hKernel, hRefinement] using hBundle
          have hBundleEq :
              { kernel_witness := kernelWitness
              , runtime_kernel_refinement_witness := runtimeKernelRefinementWitness
              , shell_contract := kernelWitness.importedShellContract
              , shell_trace := runtimeKernelRefinementWitness.importedShellTrace
              } = bundle := by
            exact Option.some.inj hBundleSome
          cases hBundleEq
          simp

def ImportedRuntimeShellBoundaryBundle.checkValid
  (bundle : ImportedRuntimeShellBoundaryBundle) : Bool :=
  bundle.kernel_witness.checkProofGrade bundle.kernel_witness.entrypoint_id &&
    bundle.runtime_kernel_refinement_witness.checkValid bundle.kernel_witness &&
    decide (bundle.shell_contract = bundle.kernel_witness.importedShellContract) &&
    decide (bundle.shell_trace = bundle.runtime_kernel_refinement_witness.importedShellTrace) &&
    bundle.shell_trace.checkRefines bundle.shell_contract

@[simp] theorem importedRuntimeShellBoundaryBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeShellBoundaryBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeShellBoundaryBundle.checkValid ImportedRuntimeShellBoundaryBundle.Valid
  simp [importedRuntimeKernelWitness_checkProofGrade_eq_true_iff,
    importedRuntimeKernelRefinementWitness_checkValid_eq_true_iff,
    importedRuntimeShellTrace_checkRefines_eq_true_iff, and_assoc]

theorem importedRuntimeShellBoundaryBundle_contract_exact
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shell_contract = bundle.kernel_witness.importedShellContract := by
  exact hValid.2.2.1

theorem importedRuntimeShellBoundaryBundle_trace_exact
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shell_trace = bundle.runtime_kernel_refinement_witness.importedShellTrace := by
  exact hValid.2.2.2.1

theorem importedRuntimeShellBoundaryBundle_refines
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shell_trace.Refines bundle.shell_contract := by
  exact hValid.2.2.2.2

theorem importedRuntimeShellBoundaryBundle_witness_refines
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.runtime_kernel_refinement_witness.shellTrace.Refines
      bundle.kernel_witness.shellContract := by
  have hContractExact := importedRuntimeShellBoundaryBundle_contract_exact hValid
  have hTraceExact := importedRuntimeShellBoundaryBundle_trace_exact hValid
  have hRefines := importedRuntimeShellBoundaryBundle_refines hValid
  have hRuntimeRefines :
      bundle.shell_trace.toRuntimeShellTrace.Refines
        bundle.shell_contract.toRuntimeShellContract :=
    importedRuntimeShellTrace_refines_toRuntimeRefines hRefines
  simpa [ImportedRuntimeKernelWitness.shellContract,
    ImportedRuntimeKernelRefinementWitness.shellTrace, hContractExact, hTraceExact] using
    hRuntimeRefines

theorem importedRuntimeShellBoundaryBundle_witness_proofGradeRefines
  {bundle : ImportedRuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
      bundle.kernel_witness.shellContract := by
  have hContractExact := importedRuntimeShellBoundaryBundle_contract_exact hValid
  have hTraceExact := importedRuntimeShellBoundaryBundle_trace_exact hValid
  simpa [ImportedRuntimeKernelWitness.shellContract,
    ImportedRuntimeKernelRefinementWitness.shellTrace, hContractExact, hTraceExact] using
    importedRuntimeShellTrace_refines_toRuntime
      (importedRuntimeShellBoundaryBundle_refines hValid)

def parseImportedRuntimeShellBoundaryBundle
  (input : String) : Except String ImportedRuntimeShellBoundaryBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeShellBoundaryBundle
  (input : String) : Except String ImportedRuntimeShellBoundaryBundle := do
  let bundle ← parseImportedRuntimeShellBoundaryBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw "imported proof-grade runtime shell-boundary bundle does not satisfy Lean validity checks"

def loadImportedRuntimeShellBoundaryBundle
  (path : System.FilePath) : IO ImportedRuntimeShellBoundaryBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeShellBoundaryBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime shell-boundary bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeShellBoundaryBundle
  (path : System.FilePath) : IO ImportedRuntimeShellBoundaryBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeShellBoundaryBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime shell-boundary bundle: {err}"

theorem importedWitness_proofGradeShellContractRefinement
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernel_witness = some kernelWitness ∧
      witness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract := by
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.2
  cases hKernel : witness.kernel_witness with
  | none =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
  | some kernelWitness =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          have hWitnessValid :
              runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.Valid
                kernelWitness.toRuntimeKernelWitness := by
            simpa [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
              ImportedRuntimeKernelRefinementWitness.Valid, hKernel, hRefinement] using
              hRefinementValid
          have hImportedTraceToRuntime :
              runtimeKernelRefinementWitness.importedShellTrace.toRuntimeShellTrace =
                runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.shellTrace := by
            simp
          have hImportedContractToRuntime :
              kernelWitness.importedShellContract.toRuntimeShellContract =
                kernelWitness.toRuntimeKernelWitness.shellContract := by
            simp
          have hImportedRefines :
              runtimeKernelRefinementWitness.importedShellTrace.toRuntimeShellTrace.ProofGradeRefines
                kernelWitness.importedShellContract.toRuntimeShellContract := by
            simpa [hImportedTraceToRuntime, hImportedContractToRuntime] using
              runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract hWitnessValid
          exact
            ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
              by
                simpa [ImportedRuntimeKernelRefinementWitness.shellTrace,
                  ImportedRuntimeKernelWitness.shellContract] using hImportedRefines⟩

/--
Packaged imported proof-grade facts for the runtime/kernel boundary. This is
the imported-JSON analogue of `RuntimeProofGradeKernelBoundaryFacts`: one
accepted imported runtime witness yields the exact public kernel schedule,
public object universe, resource replay, runtime-phase projection, and
proof-grade shell-boundary refinement facts used by the paper-facing argument.
-/
def ImportedRuntimeProofGradeKernelBoundaryFacts
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  ∃ kernelWitness runtimeKernelRefinementWitness
      expectedKernelSteps expectedPublicObjectIds expectedKernelSchedule,
    witness.kernel_witness = some kernelWitness ∧
      witness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      kernelWitness.expected_kernel_steps = some expectedKernelSteps ∧
      kernelWitness.kernel_steps = expectedKernelSteps ∧
      kernelWitness.expected_public_object_ids = some expectedPublicObjectIds ∧
      kernelWitness.public_object_ids = expectedPublicObjectIds ∧
      kernelWitness.toRuntimeKernelWitness.replayedResourceState? =
        some kernelWitness.claimedResourceState ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } ∧
      runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.projectedKernelSchedule =
        kernelWitness.toRuntimeKernelWitness.emittedKernelSchedule ∧
      runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.preCommittedColdObjectSchedule =
        kernelWitness.toRuntimeKernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.postCommittedColdObjectSchedule =
        kernelWitness.toRuntimeKernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract

theorem importedWitness_proofGradeKernelBoundaryFacts
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ImportedRuntimeProofGradeKernelBoundaryFacts witness := by
  rcases importedWitness_proofGradeShellContractRefinement witness modelTags hValid with
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel, hRefinement, hShellRefines⟩
  rcases importedWitness_proofGradeKernelSchedule_exact witness modelTags hValid with
    ⟨kernelWitnessSteps, expectedKernelSteps, hKernelStepsWitness, hExpectedKernelSteps,
      hKernelSteps⟩
  have hKernelEqSteps : kernelWitness = kernelWitnessSteps := by
    simpa [hKernelStepsWitness] using hKernel.symm
  subst kernelWitnessSteps
  rcases importedWitness_proofGradePublicObjectUniverse_exact witness modelTags hValid with
    ⟨kernelWitnessPublic, expectedPublicObjectIds, hKernelPublic,
      hExpectedPublicObjectIds, hPublicObjectIds⟩
  have hKernelEqPublic : kernelWitness = kernelWitnessPublic := by
    simpa [hKernelPublic] using hKernel.symm
  subst kernelWitnessPublic
  rcases importedWitness_proofGradeKernelResourceState_exact witness modelTags hValid with
    ⟨kernelWitnessResource, hKernelResource, hResourceState⟩
  have hKernelEqResource : kernelWitness = kernelWitnessResource := by
    simpa [hKernelResource] using hKernel.symm
  subst kernelWitnessResource
  rcases importedWitness_proofGradeKernelScheduleObject_exact witness modelTags hValid with
    ⟨kernelWitnessSchedule, expectedKernelSchedule, hKernelSchedule,
      hExpectedKernelSchedule, hEmittedKernelSchedule⟩
  have hKernelEqSchedule : kernelWitness = kernelWitnessSchedule := by
    simpa [hKernelSchedule] using hKernel.symm
  subst kernelWitnessSchedule
  rcases importedWitness_proofGradeKernelScheduleObject_finalState_exact
      witness modelTags hValid with
    ⟨kernelWitnessFinal, expectedKernelScheduleFinal, hKernelFinal,
      hExpectedKernelScheduleFinal, hFinalKernelScheduleState⟩
  have hKernelEqFinal : kernelWitness = kernelWitnessFinal := by
    simpa [hKernelFinal] using hKernel.symm
  subst kernelWitnessFinal
  have hExpectedKernelScheduleEq :
      expectedKernelSchedule = expectedKernelScheduleFinal := by
    apply Option.some.inj
    rw [← hExpectedKernelSchedule, hExpectedKernelScheduleFinal]
  subst expectedKernelScheduleFinal
  rcases importedWitness_proofGradeRuntimeKernelRefinementProjection_exact
      witness modelTags hValid with
    ⟨kernelWitnessProjected, runtimeKernelRefinementWitnessProjected,
      hKernelProjected, hRefinementProjected, hProjectedKernelSchedule⟩
  have hKernelEqProjected : kernelWitness = kernelWitnessProjected := by
    simpa [hKernelProjected] using hKernel.symm
  subst kernelWitnessProjected
  have hRefinementEqProjected :
      runtimeKernelRefinementWitness = runtimeKernelRefinementWitnessProjected := by
    simpa [hRefinementProjected] using hRefinement.symm
  subst runtimeKernelRefinementWitnessProjected
  rcases importedWitness_proofGradeRuntimeKernelRefinementBoundaryExact
      witness modelTags hValid with
    ⟨kernelWitnessBoundary, runtimeKernelRefinementWitnessBoundary,
      hKernelBoundary, hRefinementBoundary,
      hPreCommittedColdObjectSchedule, hPostCommittedColdObjectSchedule⟩
  have hKernelEqBoundary : kernelWitness = kernelWitnessBoundary := by
    simpa [hKernelBoundary] using hKernel.symm
  subst kernelWitnessBoundary
  have hRefinementEqBoundary :
      runtimeKernelRefinementWitness = runtimeKernelRefinementWitnessBoundary := by
    simpa [hRefinementBoundary] using hRefinement.symm
  subst runtimeKernelRefinementWitnessBoundary
  exact
    ⟨kernelWitness, runtimeKernelRefinementWitness, expectedKernelSteps,
      expectedPublicObjectIds, expectedKernelSchedule, hKernel, hRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds,
      hPublicObjectIds, hResourceState, hExpectedKernelSchedule,
      hEmittedKernelSchedule, hFinalKernelScheduleState,
      hProjectedKernelSchedule, hPreCommittedColdObjectSchedule,
      hPostCommittedColdObjectSchedule, hShellRefines⟩

/--
Imported-JSON analogue of `RuntimeProofGradeKernelInterface`: one accepted
imported runtime witness canonically induces the exact shell-boundary bundle,
the lower-level runtime phase witness still refines one exact Lean kernel
state, and the exact kernel-step/object/resource facts stay aligned with that
same bundle while the shell trace satisfies the same proof-grade shell
refinement notion as the native theorem surface.
-/
def ImportedRuntimeProofGradeKernelInterface
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  ∃ shellBoundaryBundle expectedKernelSteps expectedPublicObjectIds expectedKernelSchedule,
    witness.shellBoundaryBundle? = some shellBoundaryBundle ∧
      shellBoundaryBundle.kernel_witness.ProofGradeValid
        shellBoundaryBundle.kernel_witness.entrypoint_id ∧
      shellBoundaryBundle.runtime_kernel_refinement_witness.Valid
        shellBoundaryBundle.kernel_witness ∧
      shellBoundaryBundle.shell_contract =
        shellBoundaryBundle.kernel_witness.importedShellContract ∧
      shellBoundaryBundle.shell_trace =
        shellBoundaryBundle.runtime_kernel_refinement_witness.importedShellTrace ∧
      shellBoundaryBundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines
        shellBoundaryBundle.kernel_witness.shellContract ∧
      shellBoundaryBundle.runtime_kernel_refinement_witness.RefinesLeanKernelState
        shellBoundaryBundle.kernel_witness ∧
      shellBoundaryBundle.kernel_witness.expected_kernel_steps = some expectedKernelSteps ∧
      shellBoundaryBundle.kernel_witness.kernel_steps = expectedKernelSteps ∧
      shellBoundaryBundle.kernel_witness.expected_public_object_ids =
        some expectedPublicObjectIds ∧
      shellBoundaryBundle.kernel_witness.public_object_ids = expectedPublicObjectIds ∧
      shellBoundaryBundle.kernel_witness.toRuntimeKernelWitness.replayedResourceState? =
        some shellBoundaryBundle.kernel_witness.claimedResourceState ∧
      shellBoundaryBundle.kernel_witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      shellBoundaryBundle.kernel_witness.emittedKernelSchedule = expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          }

theorem importedWitness_proofGradeKernelInterface
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ImportedRuntimeProofGradeKernelInterface witness := by
  rcases importedWitness_proofGradeKernelBoundaryFacts witness modelTags hValid with
    ⟨kernelWitness, runtimeKernelRefinementWitness, expectedKernelSteps,
      expectedPublicObjectIds, expectedKernelSchedule, hKernel, hRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds,
      hPublicObjectIds, hResourceState, hExpectedKernelSchedule,
      hEmittedKernelSchedule, hFinalKernelScheduleState,
      _hProjectedKernelSchedule, _hPreCommittedColdObjectSchedule,
      _hPostCommittedColdObjectSchedule, hShellRefines⟩
  rcases importedWitness_proofGradeKernelStateRefinement witness modelTags hValid with
    ⟨kernelWitnessState, runtimeKernelRefinementWitnessState, hKernelState,
      hRefinementState, hKernelStateRefinement⟩
  let shellBoundaryBundle : ImportedRuntimeShellBoundaryBundle :=
    { kernel_witness := kernelWitness
    , runtime_kernel_refinement_witness := runtimeKernelRefinementWitness
    , shell_contract := kernelWitness.importedShellContract
    , shell_trace := runtimeKernelRefinementWitness.importedShellTrace
    }
  have hBundle :
      witness.shellBoundaryBundle? = some shellBoundaryBundle := by
    simp [ImportedRuntimeRefinementWitness.shellBoundaryBundle?, hKernel, hRefinement,
      shellBoundaryBundle]
  have hBundleExact := importedRuntimeRefinementWitness_shellBoundaryBundle_exact hBundle
  have hKernelEqState : kernelWitness = kernelWitnessState := by
    apply Option.some.inj
    exact hKernel.symm.trans hKernelState
  have hRefinementEqState :
      runtimeKernelRefinementWitness = runtimeKernelRefinementWitnessState := by
    apply Option.some.inj
    exact hRefinement.symm.trans hRefinementState
  subst hKernelEqState
  subst hRefinementEqState
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  have hKernelProofGradeAtRuntimeWitness :
      kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
    simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
      hKernelValid
  have hKernelProofGrade :
      shellBoundaryBundle.kernel_witness.ProofGradeValid
        shellBoundaryBundle.kernel_witness.entrypoint_id := by
    have hEntryEq : kernelWitness.entrypoint_id = witness.public_outcome.entrypoint_id := by
      have hKernelWitnessValid :
          kernelWitness.Valid witness.public_outcome.entrypoint_id :=
        hKernelProofGradeAtRuntimeWitness.1
      unfold ImportedRuntimeKernelWitness.Valid at hKernelWitnessValid
      simpa using hKernelWitnessValid.1
    simpa [shellBoundaryBundle, hEntryEq] using hKernelProofGradeAtRuntimeWitness
  have hRefinementWitnessValid :
      shellBoundaryBundle.runtime_kernel_refinement_witness.Valid
        shellBoundaryBundle.kernel_witness := by
    simpa [shellBoundaryBundle, ImportedRuntimeKernelRefinementWitness.Valid] using
      (by
        have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid := by
          unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
          exact hValid.2.2
        simpa [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
          hKernel, hRefinement] using hRefinementValid)
  exact
    ⟨shellBoundaryBundle, expectedKernelSteps, expectedPublicObjectIds, expectedKernelSchedule,
      hBundle, hKernelProofGrade, hRefinementWitnessValid, hBundleExact.2.2.1,
      hBundleExact.2.2.2, by simpa [shellBoundaryBundle] using hShellRefines,
      by simpa [shellBoundaryBundle] using hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩

end UOToolchain
