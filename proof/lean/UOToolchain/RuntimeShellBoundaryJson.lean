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

def importedRuntimeKernelInterfaceBundleFieldNames : List String :=
  [ "shell_boundary_bundle"
  , "expected_kernel_steps"
  , "expected_public_object_ids"
  , "expected_kernel_schedule"
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

structure ImportedRuntimeKernelInterfaceBundle where
  shell_boundary_bundle : ImportedRuntimeShellBoundaryBundle
  expected_kernel_steps : List ImportedRuntimeKernelStep
  expected_public_object_ids : List Nat
  expected_kernel_schedule : ImportedRuntimeKernelSchedule
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

def ImportedRuntimeRefinementWitness.kernelInterfaceBundle?
  (witness : ImportedRuntimeRefinementWitness) : Option ImportedRuntimeKernelInterfaceBundle := do
  let shellBoundaryBundle ← witness.shellBoundaryBundle?
  let expectedKernelSteps ← shellBoundaryBundle.kernel_witness.expected_kernel_steps
  let expectedPublicObjectIds ← shellBoundaryBundle.kernel_witness.expected_public_object_ids
  let expectedKernelSchedule ← shellBoundaryBundle.kernel_witness.expectedKernelSchedule?
  pure
    { shell_boundary_bundle := shellBoundaryBundle
    , expected_kernel_steps := expectedKernelSteps
    , expected_public_object_ids := expectedPublicObjectIds
    , expected_kernel_schedule := expectedKernelSchedule
    }

def ImportedRuntimeShellBoundaryBundle.Valid
  (bundle : ImportedRuntimeShellBoundaryBundle) : Prop :=
  bundle.kernel_witness.ProofGradeValid bundle.kernel_witness.entrypoint_id ∧
    bundle.runtime_kernel_refinement_witness.Valid bundle.kernel_witness ∧
    bundle.shell_contract = bundle.kernel_witness.importedShellContract ∧
    bundle.shell_trace = bundle.runtime_kernel_refinement_witness.importedShellTrace ∧
    bundle.shell_trace.Refines bundle.shell_contract

def ImportedRuntimeKernelInterfaceBundle.Valid
  (bundle : ImportedRuntimeKernelInterfaceBundle) : Prop :=
  bundle.shell_boundary_bundle.Valid ∧
    bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.RefinesLeanKernelState
      bundle.shell_boundary_bundle.kernel_witness ∧
    bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.expected_kernel_steps ∧
    bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
      bundle.expected_kernel_steps ∧
    bundle.shell_boundary_bundle.kernel_witness.expected_public_object_ids =
      some bundle.expected_public_object_ids ∧
    bundle.shell_boundary_bundle.kernel_witness.public_object_ids =
      bundle.expected_public_object_ids ∧
    bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.replayedResourceState? =
      some bundle.shell_boundary_bundle.kernel_witness.claimedResourceState ∧
    bundle.shell_boundary_bundle.kernel_witness.expectedKernelSchedule? =
      some bundle.expected_kernel_schedule ∧
    bundle.shell_boundary_bundle.kernel_witness.emittedKernelSchedule =
      bundle.expected_kernel_schedule ∧
    bundle.expected_kernel_schedule.toRuntimeKernelSchedule.finalState? =
      some
        { phase := .finished
        , publicObjectSchedule := bundle.expected_kernel_schedule.publicObjectSchedule
        }

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

theorem importedRuntimeRefinementWitness_kernelInterfaceBundle_exact
  {witness : ImportedRuntimeRefinementWitness}
  {bundle : ImportedRuntimeKernelInterfaceBundle}
  (hBundle : witness.kernelInterfaceBundle? = some bundle) :
  witness.shellBoundaryBundle? = some bundle.shell_boundary_bundle ∧
    bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
      some bundle.expected_kernel_steps ∧
    bundle.shell_boundary_bundle.kernel_witness.expected_public_object_ids =
      some bundle.expected_public_object_ids ∧
    bundle.shell_boundary_bundle.kernel_witness.expectedKernelSchedule? =
      some bundle.expected_kernel_schedule := by
  unfold ImportedRuntimeRefinementWitness.kernelInterfaceBundle? at hBundle
  cases hShell : witness.shellBoundaryBundle? with
  | none =>
      simp [hShell] at hBundle
  | some shellBoundaryBundle =>
      cases hExpectedSteps : shellBoundaryBundle.kernel_witness.expected_kernel_steps with
      | none =>
          simp [hShell, hExpectedSteps] at hBundle
      | some expectedKernelSteps =>
          cases hExpectedPublic :
              shellBoundaryBundle.kernel_witness.expected_public_object_ids with
          | none =>
              simp [hShell, hExpectedSteps, hExpectedPublic] at hBundle
          | some expectedPublicObjectIds =>
              cases hExpectedSchedule :
                  shellBoundaryBundle.kernel_witness.expectedKernelSchedule? with
              | none =>
                  simp [hShell, hExpectedSteps, hExpectedPublic, hExpectedSchedule] at hBundle
              | some expectedKernelSchedule =>
                  have hBundleSome :
                      some
                          { shell_boundary_bundle := shellBoundaryBundle
                          , expected_kernel_steps := expectedKernelSteps
                          , expected_public_object_ids := expectedPublicObjectIds
                          , expected_kernel_schedule := expectedKernelSchedule
                          } =
                        some bundle := by
                    simpa [hShell, hExpectedSteps, hExpectedPublic, hExpectedSchedule] using
                      hBundle
                  have hBundleEq :
                      { shell_boundary_bundle := shellBoundaryBundle
                      , expected_kernel_steps := expectedKernelSteps
                      , expected_public_object_ids := expectedPublicObjectIds
                      , expected_kernel_schedule := expectedKernelSchedule
                      } = bundle := by
                    exact Option.some.inj hBundleSome
                  cases hBundleEq
                  simp [hShell, hExpectedSteps, hExpectedPublic, hExpectedSchedule]

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

def ImportedRuntimeKernelInterfaceBundle.checkValid
  (bundle : ImportedRuntimeKernelInterfaceBundle) : Bool :=
  bundle.shell_boundary_bundle.checkValid &&
      (bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
        some bundle.expected_kernel_steps) &&
    decide
      (bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
        bundle.expected_kernel_steps) &&
    decide
      (bundle.shell_boundary_bundle.kernel_witness.expected_public_object_ids =
        some bundle.expected_public_object_ids) &&
    decide
      (bundle.shell_boundary_bundle.kernel_witness.public_object_ids =
        bundle.expected_public_object_ids) &&
    decide
      (bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.replayedResourceState? =
        some bundle.shell_boundary_bundle.kernel_witness.claimedResourceState) &&
    decide
      (bundle.shell_boundary_bundle.kernel_witness.expectedKernelSchedule? =
        some bundle.expected_kernel_schedule) &&
    decide
      (bundle.shell_boundary_bundle.kernel_witness.emittedKernelSchedule =
        bundle.expected_kernel_schedule) &&
    decide
      (bundle.expected_kernel_schedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := bundle.expected_kernel_schedule.publicObjectSchedule
          })

@[simp] theorem importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeKernelInterfaceBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  constructor
  · intro hCheck
    have hChecks :
        bundle.shell_boundary_bundle.checkValid = true ∧
          bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps =
            some bundle.expected_kernel_steps ∧
          bundle.shell_boundary_bundle.kernel_witness.kernel_steps =
            bundle.expected_kernel_steps ∧
          bundle.shell_boundary_bundle.kernel_witness.expected_public_object_ids =
            some bundle.expected_public_object_ids ∧
          bundle.shell_boundary_bundle.kernel_witness.public_object_ids =
            bundle.expected_public_object_ids ∧
          bundle.shell_boundary_bundle.kernel_witness.toRuntimeKernelWitness.replayedResourceState? =
            some bundle.shell_boundary_bundle.kernel_witness.claimedResourceState ∧
          bundle.shell_boundary_bundle.kernel_witness.expectedKernelSchedule? =
            some bundle.expected_kernel_schedule ∧
          bundle.shell_boundary_bundle.kernel_witness.emittedKernelSchedule =
            bundle.expected_kernel_schedule ∧
          bundle.expected_kernel_schedule.toRuntimeKernelSchedule.finalState? =
            some
              { phase := .finished
              , publicObjectSchedule := bundle.expected_kernel_schedule.publicObjectSchedule
              } := by
      simpa [ImportedRuntimeKernelInterfaceBundle.checkValid, and_assoc] using hCheck
    rcases hChecks with
      ⟨hShellCheck, hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds,
        hPublicObjectIds, hResourceState, hExpectedKernelSchedule,
        hEmittedKernelSchedule, hFinalKernelScheduleState⟩
    have hShellValid : bundle.shell_boundary_bundle.Valid := by
      exact
        (importedRuntimeShellBoundaryBundle_checkValid_eq_true_iff
          bundle.shell_boundary_bundle).mp hShellCheck
    have hKernelStateRefinement :
        bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.RefinesLeanKernelState
          bundle.shell_boundary_bundle.kernel_witness := by
      exact
        importedRuntimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
          hShellValid.1 hShellValid.2.1
    exact
      ⟨hShellValid, hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
        hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
        hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩
  · intro hValid
    rcases hValid with
      ⟨hShellValid, _hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
        hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
        hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩
    have hShellCheck : bundle.shell_boundary_bundle.checkValid = true := by
      exact
        (importedRuntimeShellBoundaryBundle_checkValid_eq_true_iff
          bundle.shell_boundary_bundle).mpr hShellValid
    simp [ImportedRuntimeKernelInterfaceBundle.checkValid, hShellCheck,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState, and_assoc]

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

def ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle
  (bundle : ImportedRuntimeShellBoundaryBundle) : RuntimeShellBoundaryBundle :=
  { kernelWitness := bundle.kernel_witness.toRuntimeKernelWitness
  , runtimeKernelRefinementWitness :=
      bundle.runtime_kernel_refinement_witness.toRuntimeKernelRefinementWitness
  , shellContract := bundle.shell_contract.toRuntimeShellContract
  , shellTrace := bundle.shell_trace.toRuntimeShellTrace
  }

def ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle
  (bundle : ImportedRuntimeKernelInterfaceBundle) : RuntimeKernelInterfaceBundle :=
  { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
  , expectedKernelSteps := bundle.expected_kernel_steps.map
      ImportedRuntimeKernelStep.toRuntimeKernelStep
  , expectedPublicObjectIds := bundle.expected_public_object_ids
  , expectedKernelSchedule := bundle.expected_kernel_schedule.toRuntimeKernelSchedule
  }

theorem importedRuntimeShellBoundaryBundle_toRuntimeValid
  (bundle : ImportedRuntimeShellBoundaryBundle)
  (hValid : bundle.Valid) :
  bundle.toRuntimeShellBoundaryBundle.Valid := by
  rcases hValid with
    ⟨hKernelProofGrade, hRefinementValid, hContractExact, hTraceExact, hRefines⟩
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · exact
      runtimeKernelWitness_proofGradeValid_self
        (importedRuntimeKernelWitness_toRuntimeKernelWitness_proofGradeValid
          bundle.kernel_witness bundle.kernel_witness.entrypoint_id hKernelProofGrade)
  · simpa [ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelRefinementWitness.Valid] using hRefinementValid
  · simpa [ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle, hContractExact] using
      importedRuntimeKernelWitness_importedShellContract_toRuntime bundle.kernel_witness
  · simpa [ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle, hTraceExact] using
      importedRuntimeKernelRefinementWitness_importedShellTrace_toRuntime
        bundle.runtime_kernel_refinement_witness
  · unfold ImportedRuntimeShellTrace.Refines at hRefines
    simpa [ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.shellContract,
      ImportedRuntimeKernelRefinementWitness.shellTrace, hContractExact, hTraceExact] using
      hRefines

theorem importedRuntimeKernelInterfaceBundle_toRuntimeValid
  (bundle : ImportedRuntimeKernelInterfaceBundle)
  (hValid : bundle.Valid) :
  bundle.toRuntimeKernelInterfaceBundle.Valid := by
  rcases hValid with
    ⟨hShellValid, hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
      hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · exact
      importedRuntimeShellBoundaryBundle_toRuntimeValid
        bundle.shell_boundary_bundle hShellValid
  · simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelRefinementWitness.RefinesLeanKernelState] using
      hKernelStateRefinement
  · simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness] using
      congrArg
        (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep))
        hExpectedKernelSteps
  · simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness] using
      congrArg (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep) hKernelSteps
  · simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness] using
      hExpectedPublicObjectIds
  · simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness] using
      hPublicObjectIds
  · simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness,
      ImportedRuntimeKernelWitness.claimedResourceState] using
      hResourceState
  · have hExpectedKernelScheduleExact :
        bundle.expected_kernel_schedule =
          { opcodes := bundle.expected_kernel_steps.map ImportedRuntimeKernelStep.opcode
          , steps := bundle.expected_kernel_steps
          } := by
      have hSchedule := hExpectedKernelSchedule
      simp [ImportedRuntimeKernelWitness.expectedKernelSchedule?, hExpectedKernelSteps] at hSchedule
      exact hSchedule.symm
    change
      ((Option.map (List.map ImportedRuntimeKernelStep.opcode)
            bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps).bind
          fun opcodes =>
          (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep)
                bundle.shell_boundary_bundle.kernel_witness.expected_kernel_steps).bind
            fun steps => some { opcodes := opcodes, steps := steps }) =
        some bundle.expected_kernel_schedule.toRuntimeKernelSchedule
    rw [hExpectedKernelSteps, hExpectedKernelScheduleExact]
    simp [ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule]
  · have hExpectedKernelScheduleExact :
        bundle.expected_kernel_schedule =
          { opcodes := bundle.expected_kernel_steps.map ImportedRuntimeKernelStep.opcode
          , steps := bundle.expected_kernel_steps
          } := by
      have hSchedule := hExpectedKernelSchedule
      simp [ImportedRuntimeKernelWitness.expectedKernelSchedule?, hExpectedKernelSteps] at hSchedule
      exact hSchedule.symm
    change
      { opcodes := bundle.shell_boundary_bundle.kernel_witness.kernel_steps.map ImportedRuntimeKernelStep.opcode
      , steps := bundle.shell_boundary_bundle.kernel_witness.kernel_steps.map
          ImportedRuntimeKernelStep.toRuntimeKernelStep
      } = bundle.expected_kernel_schedule.toRuntimeKernelSchedule
    rw [hKernelSteps, hExpectedKernelScheduleExact]
    simp [ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule]
  · change
      bundle.expected_kernel_schedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule :=
              bundle.expected_kernel_schedule.toRuntimeKernelSchedule.publicObjectSchedule
          }
    simpa using hFinalKernelScheduleState

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

def parseImportedRuntimeKernelInterfaceBundle
  (input : String) : Except String ImportedRuntimeKernelInterfaceBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeKernelInterfaceBundle
  (input : String) : Except String ImportedRuntimeKernelInterfaceBundle := do
  let bundle ← parseImportedRuntimeKernelInterfaceBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw "imported proof-grade runtime kernel-interface bundle does not satisfy Lean validity checks"

def loadImportedRuntimeKernelInterfaceBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelInterfaceBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelInterfaceBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime kernel-interface bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelInterfaceBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelInterfaceBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelInterfaceBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel-interface bundle: {err}"

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

/--
Explicit-bundle imported analogue of the theorem-facing runtime/kernel
interface. This keeps the imported checker route phrased over the same
runtime-exported `RuntimeKernelInterfaceBundle` object as the native theorem
surface.
-/
def ImportedRuntimeProofGradeKernelInterfaceBundle
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  ∃ bundle, witness.kernelInterfaceBundle? = some bundle ∧ bundle.Valid

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

theorem importedWitness_proofGradeKernelInterfaceBundle_valid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ bundle, witness.kernelInterfaceBundle? = some bundle ∧ bundle.Valid := by
  rcases importedWitness_proofGradeKernelInterface witness modelTags hValid with
    ⟨shellBoundaryBundle, expectedKernelSteps, expectedPublicObjectIds,
      expectedKernelSchedule, hBundle, hKernelProofGrade, hRefinementWitnessValid,
      hContractExact, hTraceExact, hShellRefines, hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩
  let bundle : ImportedRuntimeKernelInterfaceBundle :=
    { shell_boundary_bundle := shellBoundaryBundle
    , expected_kernel_steps := expectedKernelSteps
    , expected_public_object_ids := expectedPublicObjectIds
    , expected_kernel_schedule := expectedKernelSchedule
    }
  have hShellBoundaryValid : shellBoundaryBundle.Valid := by
    refine
      ⟨hKernelProofGrade, hRefinementWitnessValid, hContractExact, hTraceExact, ?_⟩
    unfold ImportedRuntimeShellTrace.Refines
    simpa [ImportedRuntimeKernelWitness.shellContract,
      ImportedRuntimeKernelRefinementWitness.shellTrace, hContractExact, hTraceExact] using
      hShellRefines
  refine ⟨bundle, ?_, ?_⟩
  · simpa [ImportedRuntimeRefinementWitness.kernelInterfaceBundle?, hBundle,
      hExpectedKernelSteps, hExpectedPublicObjectIds, hExpectedKernelSchedule, bundle]
  · exact
      ⟨hShellBoundaryValid, hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
        hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
        hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩

theorem importedRuntimeProofGradeKernelInterfaceBundle_toProofGradeKernelInterface
  {witness : ImportedRuntimeRefinementWitness}
  (hBundle : ImportedRuntimeProofGradeKernelInterfaceBundle witness) :
  ImportedRuntimeProofGradeKernelInterface witness := by
  rcases hBundle with ⟨bundle, hExact, hValid⟩
  rcases hValid with
    ⟨hShellValid, hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
      hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩
  have hBundleExact := importedRuntimeRefinementWitness_kernelInterfaceBundle_exact hExact
  refine
    ⟨bundle.shell_boundary_bundle, bundle.expected_kernel_steps, bundle.expected_public_object_ids,
      bundle.expected_kernel_schedule, hBundleExact.1, hShellValid.1, hShellValid.2.1,
      hShellValid.2.2.1, hShellValid.2.2.2.1, ?_, hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩
  exact importedRuntimeShellBoundaryBundle_witness_proofGradeRefines hShellValid

theorem importedWitness_proofGradeKernelInterfaceBundle
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ImportedRuntimeProofGradeKernelInterfaceBundle witness := by
  simpa [ImportedRuntimeProofGradeKernelInterfaceBundle] using
    importedWitness_proofGradeKernelInterfaceBundle_valid witness modelTags hValid

def ImportedRuntimeProofGradeKernelInterfaceAssurance
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.ProofGradeValid modelTags ∧
    ImportedRuntimeProofGradeKernelInterfaceBundle witness

def checkImportedRuntimeProofGradeKernelInterface
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  witness.checkProofGrade modelTags

@[simp] theorem importedRuntimeProofGradeKernelInterface_check_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  checkImportedRuntimeProofGradeKernelInterface witness modelTags = true ↔
    ImportedRuntimeProofGradeKernelInterfaceAssurance witness modelTags := by
  unfold checkImportedRuntimeProofGradeKernelInterface
    ImportedRuntimeProofGradeKernelInterfaceAssurance
  constructor
  · intro hCheck
    have hValid : witness.ProofGradeValid modelTags := by
      exact (importedWitness_checkProofGrade_eq_true_iff witness modelTags).mp hCheck
    exact ⟨hValid, importedWitness_proofGradeKernelInterfaceBundle witness modelTags hValid⟩
  · intro hAssurance
    exact (importedWitness_checkProofGrade_eq_true_iff witness modelTags).mpr hAssurance.1

def parseAndCheckImportedProofGradeRuntimeKernelInterfaceWitness
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeRefinementWitness := do
  let witness ← parseImportedRuntimeRefinementWitness input
  if checkImportedRuntimeProofGradeKernelInterface witness modelTags then
    pure witness
  else
    throw
      "imported proof-grade runtime kernel-interface witness does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeRuntimeKernelInterfaceWitness
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelInterfaceWitness input modelTags with
  | .ok witness => pure witness
  | .error err =>
      throw
        <| IO.userError
            s!"failed to validate proof-grade runtime kernel-interface witness: {err}"

end UOToolchain
