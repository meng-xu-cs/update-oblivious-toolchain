import UOToolchain.RuntimeTrustedKernel

namespace UOToolchain

/--
Public shell-side contract induced by the theorem-facing kernel witness.
Outside the confidential kernel, the runtime shell is only allowed to touch the
full public object universe and the canonical touched-object set derived from
the public kernel schedule.
-/
structure RuntimeShellContract where
  publicObjectUniverse : List Nat
  canonicalLoadedObjectSchedule : List Nat
  kernelSchedule : RuntimeKernelSchedule
deriving Repr, DecidableEq

def RuntimeKernelWitness.shellContract
  (witness : RuntimeKernelWitness) : RuntimeShellContract :=
  { publicObjectUniverse := witness.publicObjectIds
  , canonicalLoadedObjectSchedule := witness.canonicalLoadedObjectSchedule
  , kernelSchedule := witness.emittedKernelSchedule
  }

/--
Concrete shell-facing schedule reconstructed from the runtime phase witness.
These are precisely the operations that the real runtime performs outside the
small confidential kernel.
-/
structure RuntimeShellTrace where
  events : List RuntimeKernelRefinementEvent
  projectedKernelSchedule : RuntimeKernelSchedule
  preCommittedColdObjectSchedule : List Nat
  shadowLoadObjectSchedule : List Nat
  commitObjectSchedule : List Nat
  coldStoreObjectSchedule : List Nat
  postCommittedColdObjectSchedule : List Nat
deriving Repr, DecidableEq

def RuntimeKernelRefinementWitness.shellTrace
  (witness : RuntimeKernelRefinementWitness) : RuntimeShellTrace :=
  { events := witness.events
  , projectedKernelSchedule := witness.projectedKernelSchedule
  , preCommittedColdObjectSchedule := witness.preCommittedColdObjectSchedule
  , shadowLoadObjectSchedule := witness.shadowLoadObjectSchedule
  , commitObjectSchedule := witness.commitObjectSchedule
  , coldStoreObjectSchedule := witness.coldStoreObjectSchedule
  , postCommittedColdObjectSchedule := witness.postCommittedColdObjectSchedule
  }

def RuntimeShellTrace.projectedKernelScheduleFromEvents
  (trace : RuntimeShellTrace) : RuntimeKernelSchedule :=
  let steps := trace.events.filterMap RuntimeKernelRefinementEvent.projectedKernelStep?
  { opcodes := steps.map RuntimeKernelStep.opcode
  , steps := steps
  }

def RuntimeShellTrace.objectScheduleFromEvents
  (trace : RuntimeShellTrace)
  (kind : String) : List Nat :=
  trace.events.filterMap (fun event =>
    if event.kind = kind then
      event.objectId
    else
      none)

def RuntimeShellTrace.preCommittedColdObjectScheduleFromEvents
  (trace : RuntimeShellTrace) : List Nat :=
  trace.objectScheduleFromEvents "pre_committed_cold_object"

def RuntimeShellTrace.shadowLoadObjectScheduleFromEvents
  (trace : RuntimeShellTrace) : List Nat :=
  trace.objectScheduleFromEvents "shadow_load_object"

def RuntimeShellTrace.commitObjectScheduleFromEvents
  (trace : RuntimeShellTrace) : List Nat :=
  trace.objectScheduleFromEvents "commit_object"

def RuntimeShellTrace.coldStoreObjectScheduleFromEvents
  (trace : RuntimeShellTrace) : List Nat :=
  trace.objectScheduleFromEvents "cold_store_object"

def RuntimeShellTrace.postCommittedColdObjectScheduleFromEvents
  (trace : RuntimeShellTrace) : List Nat :=
  trace.objectScheduleFromEvents "post_committed_cold_object"

def RuntimeShellTrace.eventsMatchSummaries
  (trace : RuntimeShellTrace) : Prop :=
  trace.projectedKernelSchedule = trace.projectedKernelScheduleFromEvents ∧
    trace.preCommittedColdObjectSchedule = trace.preCommittedColdObjectScheduleFromEvents ∧
    trace.shadowLoadObjectSchedule = trace.shadowLoadObjectScheduleFromEvents ∧
    trace.commitObjectSchedule = trace.commitObjectScheduleFromEvents ∧
    trace.coldStoreObjectSchedule = trace.coldStoreObjectScheduleFromEvents ∧
    trace.postCommittedColdObjectSchedule = trace.postCommittedColdObjectScheduleFromEvents

def RuntimeShellTrace.checkEventsMatchSummaries
  (trace : RuntimeShellTrace) : Bool :=
  decide (trace.projectedKernelSchedule = trace.projectedKernelScheduleFromEvents) &&
    decide
      (trace.preCommittedColdObjectSchedule = trace.preCommittedColdObjectScheduleFromEvents) &&
    decide (trace.shadowLoadObjectSchedule = trace.shadowLoadObjectScheduleFromEvents) &&
    decide (trace.commitObjectSchedule = trace.commitObjectScheduleFromEvents) &&
    decide (trace.coldStoreObjectSchedule = trace.coldStoreObjectScheduleFromEvents) &&
    decide
      (trace.postCommittedColdObjectSchedule = trace.postCommittedColdObjectScheduleFromEvents)

@[simp] theorem runtimeShellTrace_checkEventsMatchSummaries_eq_true_iff
  (trace : RuntimeShellTrace) :
  trace.checkEventsMatchSummaries = true ↔ trace.eventsMatchSummaries := by
  unfold RuntimeShellTrace.checkEventsMatchSummaries RuntimeShellTrace.eventsMatchSummaries
  simp [and_assoc]

structure RuntimeShellReplayState where
  phase : RuntimeKernelRefinementPhase
  preCommittedColdIndex : Nat
  kernelStepIndex : Nat
  shadowLoadIndex : Nat
  commitIndex : Nat
  coldStoreIndex : Nat
  postCommittedColdIndex : Nat
deriving Repr, DecidableEq

def RuntimeShellReplayState.initial : RuntimeShellReplayState :=
  { phase := .beforeBegin
  , preCommittedColdIndex := 0
  , kernelStepIndex := 0
  , shadowLoadIndex := 0
  , commitIndex := 0
  , coldStoreIndex := 0
  , postCommittedColdIndex := 0
  }

def RuntimeShellReplayState.terminal
  (state : RuntimeShellReplayState)
  (contract : RuntimeShellContract) : Prop :=
  (state.phase = .afterWipe ∨
      state.phase = .coldStoreWindow ∨
      state.phase = .postCommittedColdWindow) ∧
    state.preCommittedColdIndex = contract.publicObjectUniverse.length ∧
    state.kernelStepIndex = contract.kernelSchedule.steps.length ∧
    state.shadowLoadIndex = contract.canonicalLoadedObjectSchedule.length ∧
    state.commitIndex = contract.canonicalLoadedObjectSchedule.length ∧
    state.coldStoreIndex = contract.canonicalLoadedObjectSchedule.length ∧
    state.postCommittedColdIndex = contract.publicObjectUniverse.length

instance (state : RuntimeShellReplayState) (contract : RuntimeShellContract) :
    Decidable (RuntimeShellReplayState.terminal state contract) := by
  unfold RuntimeShellReplayState.terminal
  infer_instance

def RuntimeShellReplayState.step?
  (contract : RuntimeShellContract)
  (state : RuntimeShellReplayState)
  (event : RuntimeKernelRefinementEvent) : Option RuntimeShellReplayState := do
  let nextPhase ← RuntimeKernelRefinementPhase.step state.phase event
  match event.kind with
  | "pre_committed_cold_object" =>
      let expectedObjectId ← contract.publicObjectUniverse[state.preCommittedColdIndex]?
      let objectId ← event.objectId
      if objectId = expectedObjectId then
        pure { state with
          phase := nextPhase
          preCommittedColdIndex := state.preCommittedColdIndex + 1 }
      else
        none
  | "shadow_load_object" =>
      let expectedObjectId ← contract.canonicalLoadedObjectSchedule[state.shadowLoadIndex]?
      let objectId ← event.objectId
      if objectId = expectedObjectId then
        pure { state with
          phase := nextPhase
          shadowLoadIndex := state.shadowLoadIndex + 1 }
      else
        none
  | "commit_object" =>
      let expectedObjectId ← contract.canonicalLoadedObjectSchedule[state.commitIndex]?
      let objectId ← event.objectId
      if objectId = expectedObjectId then
        pure { state with
          phase := nextPhase
          commitIndex := state.commitIndex + 1 }
      else
        none
  | "cold_store_object" =>
      let expectedObjectId ← contract.canonicalLoadedObjectSchedule[state.coldStoreIndex]?
      let objectId ← event.objectId
      if objectId = expectedObjectId then
        pure { state with
          phase := nextPhase
          coldStoreIndex := state.coldStoreIndex + 1 }
      else
        none
  | "post_committed_cold_object" =>
      let expectedObjectId ← contract.publicObjectUniverse[state.postCommittedColdIndex]?
      let objectId ← event.objectId
      if objectId = expectedObjectId then
        pure { state with
          phase := nextPhase
          postCommittedColdIndex := state.postCommittedColdIndex + 1 }
      else
        none
  | "kernel_step" =>
      let expectedStep ← contract.kernelSchedule.steps[state.kernelStepIndex]?
      let step ← event.projectedKernelStep?
      if step = expectedStep then
        pure { state with
          phase := nextPhase
          kernelStepIndex := state.kernelStepIndex + 1 }
      else
        none
  | _ =>
      none

def RuntimeShellTrace.replayedState?
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) : Option RuntimeShellReplayState :=
  trace.events.foldlM (RuntimeShellReplayState.step? contract) RuntimeShellReplayState.initial

def RuntimeShellTrace.replaysContract
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) : Prop :=
  match trace.replayedState? contract with
  | some state => state.terminal contract
  | none => False

def RuntimeShellTrace.checkReplaysContract
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) : Bool :=
  match trace.replayedState? contract with
  | some state =>
      decide (RuntimeShellReplayState.terminal state contract)
  | none =>
      false

@[simp] theorem runtimeShellTrace_checkReplaysContract_eq_true_iff
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) :
  trace.checkReplaysContract contract = true ↔ trace.replaysContract contract := by
  unfold RuntimeShellTrace.checkReplaysContract RuntimeShellTrace.replaysContract
  cases hReplay : trace.replayedState? contract <;> simp

/--
The shell trace refines the shell contract exactly when every operation outside
the confidential kernel is fixed by the public kernel contract.
-/
def RuntimeShellTrace.Refines
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) : Prop :=
  trace.projectedKernelSchedule = contract.kernelSchedule ∧
    trace.preCommittedColdObjectSchedule = contract.publicObjectUniverse ∧
    trace.postCommittedColdObjectSchedule = contract.publicObjectUniverse ∧
    trace.shadowLoadObjectSchedule = contract.canonicalLoadedObjectSchedule ∧
    trace.commitObjectSchedule = contract.canonicalLoadedObjectSchedule ∧
    trace.coldStoreObjectSchedule = contract.canonicalLoadedObjectSchedule

/--
First-class theorem-facing shell/kernel bundle mirroring the runtime export:
the proof-grade kernel witness, the lower-level runtime phase witness, and the
explicit shell contract/trace summary objects all travel together.
-/
structure RuntimeShellBoundaryBundle where
  kernelWitness : RuntimeKernelWitness
  runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness
  shellContract : RuntimeShellContract
  shellTrace : RuntimeShellTrace

def RuntimeShellBoundaryBundle.Valid
  (bundle : RuntimeShellBoundaryBundle) : Prop :=
  bundle.kernelWitness.ProofGradeValid bundle.kernelWitness.entrypointId ∧
    bundle.runtimeKernelRefinementWitness.Valid bundle.kernelWitness ∧
    bundle.shellContract = bundle.kernelWitness.shellContract ∧
    bundle.shellTrace = bundle.runtimeKernelRefinementWitness.shellTrace ∧
    bundle.shellTrace.Refines bundle.shellContract

theorem runtimeShellBoundaryBundle_contract_exact
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellContract = bundle.kernelWitness.shellContract := by
  exact hValid.2.2.1

theorem runtimeShellBoundaryBundle_trace_exact
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellTrace = bundle.runtimeKernelRefinementWitness.shellTrace := by
  exact hValid.2.2.2.1

theorem runtimeShellBoundaryBundle_refines
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellTrace.Refines bundle.shellContract := by
  exact hValid.2.2.2.2

theorem runtimeShellBoundaryBundle_witness_refines
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.runtimeKernelRefinementWitness.shellTrace.Refines
      bundle.kernelWitness.shellContract := by
  have hContractExact := runtimeShellBoundaryBundle_contract_exact hValid
  have hTraceExact := runtimeShellBoundaryBundle_trace_exact hValid
  have hRefines := runtimeShellBoundaryBundle_refines hValid
  simpa [hContractExact, hTraceExact] using hRefines

theorem runtimeKernelRefinementWitness_valid_refinesShellContract
  {runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness}
  {kernelWitness : RuntimeKernelWitness}
  (hValid : runtimeKernelRefinementWitness.Valid kernelWitness) :
  runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  rcases hValid with
    ⟨_hShape, _hTerminates, hProjectedKernelSchedule, hPreCommittedCold, hPostCommittedCold,
      hShadowEqualsCommit, hShadowEqualsColdStore, hShadowEqualsCanonical, _hCoverage⟩
  unfold RuntimeKernelRefinementWitness.shellTrace RuntimeKernelWitness.shellContract
    RuntimeShellTrace.Refines
  refine ⟨hProjectedKernelSchedule, hPreCommittedCold, hPostCommittedCold,
    hShadowEqualsCanonical, ?_, ?_⟩
  · calc
      runtimeKernelRefinementWitness.commitObjectSchedule =
          runtimeKernelRefinementWitness.shadowLoadObjectSchedule := by
            symm
            exact hShadowEqualsCommit
      _ = kernelWitness.canonicalLoadedObjectSchedule := hShadowEqualsCanonical
  · calc
      runtimeKernelRefinementWitness.coldStoreObjectSchedule =
          runtimeKernelRefinementWitness.shadowLoadObjectSchedule := by
            symm
            exact hShadowEqualsColdStore
      _ = kernelWitness.canonicalLoadedObjectSchedule := hShadowEqualsCanonical

theorem runtimeWitness_proofGradeShellContractRefinement
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernelWitness = some kernelWitness ∧
      witness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.Refines kernelWitness.shellContract := by
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid :=
    runtimeWitness_proofGradeRuntimeKernelRefinementWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
  | some kernelWitness =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          have hWitnessValid : runtimeKernelRefinementWitness.Valid kernelWitness := by
            simpa [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
              hKernel, hRefinement] using hRefinementValid
          exact ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
            runtimeKernelRefinementWitness_valid_refinesShellContract hWitnessValid⟩

end UOToolchain
