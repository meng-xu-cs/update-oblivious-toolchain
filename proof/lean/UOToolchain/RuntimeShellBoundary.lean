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

def RuntimeKernelRefinementEvent.objectIdOfKind?
  (kind : String)
  (event : RuntimeKernelRefinementEvent) : Option Nat :=
  if event.kind = kind then
    event.objectId
  else
    none

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

def RuntimeShellReplayState.ofPrefix
  (consumed : List RuntimeKernelRefinementEvent)
  (phase : RuntimeKernelRefinementPhase) : RuntimeShellReplayState :=
  { phase := phase
  , preCommittedColdIndex := (consumed.filterMap
      (RuntimeKernelRefinementEvent.objectIdOfKind? "pre_committed_cold_object")).length
  , kernelStepIndex :=
      (consumed.filterMap RuntimeKernelRefinementEvent.projectedKernelStep?).length
  , shadowLoadIndex := (consumed.filterMap
      (RuntimeKernelRefinementEvent.objectIdOfKind? "shadow_load_object")).length
  , commitIndex := (consumed.filterMap
      (RuntimeKernelRefinementEvent.objectIdOfKind? "commit_object")).length
  , coldStoreIndex := (consumed.filterMap
      (RuntimeKernelRefinementEvent.objectIdOfKind? "cold_store_object")).length
  , postCommittedColdIndex := (consumed.filterMap
      (RuntimeKernelRefinementEvent.objectIdOfKind? "post_committed_cold_object")).length
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

theorem list_filterMap_getElem?_of_append_some
  {α β : Type}
  {f : α → Option β}
  {consumed suffix : List α}
  {entry : α}
  {value : β}
  (hSome : f entry = some value) :
  ((consumed ++ entry :: suffix).filterMap f)[(consumed.filterMap f).length]? = some value := by
  rw [List.filterMap_append, List.filterMap_cons_some hSome,
    List.getElem?_append_right (by simp)]
  simp

theorem runtimeKernelRefinementPhase_step_shapeValid
  {phase : RuntimeKernelRefinementPhase}
  {event : RuntimeKernelRefinementEvent}
  {nextPhase : RuntimeKernelRefinementPhase}
  (hStep : RuntimeKernelRefinementPhase.step phase event = some nextPhase) :
  event.checkShapeValid = true := by
  cases hShape : event.checkShapeValid <;>
    simp [RuntimeKernelRefinementPhase.step, hShape] at hStep
  rfl

theorem runtimeShellReplayState_step?_of_phaseStep
  (contract : RuntimeShellContract)
  (consumed : List RuntimeKernelRefinementEvent)
  (event : RuntimeKernelRefinementEvent)
  (suffix : List RuntimeKernelRefinementEvent)
  (phase nextPhase : RuntimeKernelRefinementPhase)
  (hStep : RuntimeKernelRefinementPhase.step phase event = some nextPhase)
  (hProjected :
    ((consumed ++ event :: suffix).filterMap RuntimeKernelRefinementEvent.projectedKernelStep?) =
      contract.kernelSchedule.steps)
  (hPreCommitted :
    ((consumed ++ event :: suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "pre_committed_cold_object")) =
      contract.publicObjectUniverse)
  (hPostCommitted :
    ((consumed ++ event :: suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "post_committed_cold_object")) =
      contract.publicObjectUniverse)
  (hShadowLoad :
    ((consumed ++ event :: suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "shadow_load_object")) =
      contract.canonicalLoadedObjectSchedule)
  (hCommit :
    ((consumed ++ event :: suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "commit_object")) =
      contract.canonicalLoadedObjectSchedule)
  (hColdStore :
    ((consumed ++ event :: suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "cold_store_object")) =
      contract.canonicalLoadedObjectSchedule) :
  RuntimeShellReplayState.step? contract (RuntimeShellReplayState.ofPrefix consumed phase) event =
    some (RuntimeShellReplayState.ofPrefix (consumed ++ [event]) nextPhase) := by
  have hShape : event.checkShapeValid = true :=
    runtimeKernelRefinementPhase_step_shapeValid hStep
  by_cases hPre : event.kind = "pre_committed_cold_object"
  · cases hObjectId : event.objectId with
    | none =>
        unfold RuntimeKernelRefinementEvent.checkShapeValid at hShape
        simp [hPre, hObjectId] at hShape
    | some objectId =>
        have hExpected :
            contract.publicObjectUniverse[(consumed.filterMap
                (RuntimeKernelRefinementEvent.objectIdOfKind?
                  "pre_committed_cold_object")).length]? = some objectId := by
          rw [← hPreCommitted]
          exact list_filterMap_getElem?_of_append_some
            (consumed := consumed) (entry := event) (suffix := suffix)
            (by simp [RuntimeKernelRefinementEvent.objectIdOfKind?, hPre, hObjectId])
        simp [RuntimeShellReplayState.step?, RuntimeShellReplayState.ofPrefix, hStep, hPre,
          hObjectId, hExpected,
          RuntimeKernelRefinementEvent.projectedKernelStep?,
          RuntimeKernelRefinementEvent.objectIdOfKind?,
          List.filterMap_append]
  · by_cases hShadow : event.kind = "shadow_load_object"
    · cases hObjectId : event.objectId with
      | none =>
          unfold RuntimeKernelRefinementEvent.checkShapeValid at hShape
          simp [hShadow, hObjectId] at hShape
      | some objectId =>
          have hExpected :
              contract.canonicalLoadedObjectSchedule[(consumed.filterMap
                  (RuntimeKernelRefinementEvent.objectIdOfKind? "shadow_load_object")).length]? =
                some objectId := by
            rw [← hShadowLoad]
            exact list_filterMap_getElem?_of_append_some
              (consumed := consumed) (entry := event) (suffix := suffix)
              (by simp [RuntimeKernelRefinementEvent.objectIdOfKind?, hShadow, hObjectId])
          simp [RuntimeShellReplayState.step?, RuntimeShellReplayState.ofPrefix, hStep, hShadow,
            hObjectId, hExpected,
            RuntimeKernelRefinementEvent.projectedKernelStep?,
            RuntimeKernelRefinementEvent.objectIdOfKind?,
            List.filterMap_append]
    · by_cases hKernelStep : event.kind = "kernel_step"
      · cases hProjectedStep : event.projectedKernelStep? with
        | none =>
            have hShapeKernel := hShape
            unfold RuntimeKernelRefinementEvent.checkShapeValid at hShapeKernel
            simp [hKernelStep, RuntimeKernelRefinementEvent.projectedKernelStep?] at hShapeKernel
            have hOpcodeNone : event.opcode = none := by
              cases hOpcode : event.opcode with
              | none =>
                  rfl
              | some opcode =>
                  simp [RuntimeKernelRefinementEvent.projectedKernelStep?, hKernelStep, hOpcode] at hProjectedStep
            have : False := by
              simpa [hOpcodeNone] using hShapeKernel.2
            contradiction
        | some projectedStep =>
            have hExpected :
                contract.kernelSchedule.steps[(consumed.filterMap
                    RuntimeKernelRefinementEvent.projectedKernelStep?).length]? =
                  some projectedStep := by
              rw [← hProjected]
              exact list_filterMap_getElem?_of_append_some
                (consumed := consumed) (entry := event) (suffix := suffix) hProjectedStep
            simp [RuntimeShellReplayState.step?, RuntimeShellReplayState.ofPrefix, hStep,
              hKernelStep, hProjectedStep, hExpected,
              RuntimeKernelRefinementEvent.objectIdOfKind?, List.filterMap_append]
      · by_cases hCommitObject : event.kind = "commit_object"
        · cases hObjectId : event.objectId with
          | none =>
              unfold RuntimeKernelRefinementEvent.checkShapeValid at hShape
              simp [hCommitObject, hObjectId] at hShape
          | some objectId =>
              have hExpected :
                  contract.canonicalLoadedObjectSchedule[(consumed.filterMap
                      (RuntimeKernelRefinementEvent.objectIdOfKind? "commit_object")).length]? =
                    some objectId := by
                rw [← hCommit]
                exact list_filterMap_getElem?_of_append_some
                  (consumed := consumed) (entry := event) (suffix := suffix)
                  (by simp [RuntimeKernelRefinementEvent.objectIdOfKind?, hCommitObject,
                    hObjectId])
              simp [RuntimeShellReplayState.step?, RuntimeShellReplayState.ofPrefix, hStep,
                hCommitObject, hObjectId, hExpected,
                RuntimeKernelRefinementEvent.projectedKernelStep?,
                RuntimeKernelRefinementEvent.objectIdOfKind?, List.filterMap_append]
        · by_cases hColdStoreObject : event.kind = "cold_store_object"
          · cases hObjectId : event.objectId with
            | none =>
                unfold RuntimeKernelRefinementEvent.checkShapeValid at hShape
                simp [hColdStoreObject, hObjectId] at hShape
            | some objectId =>
                have hExpected :
                    contract.canonicalLoadedObjectSchedule[(consumed.filterMap
                        (RuntimeKernelRefinementEvent.objectIdOfKind?
                          "cold_store_object")).length]? =
                      some objectId := by
                  rw [← hColdStore]
                  exact list_filterMap_getElem?_of_append_some
                    (consumed := consumed) (entry := event) (suffix := suffix)
                    (by simp [RuntimeKernelRefinementEvent.objectIdOfKind?, hColdStoreObject,
                      hObjectId])
                simp [RuntimeShellReplayState.step?, RuntimeShellReplayState.ofPrefix, hStep,
                  hColdStoreObject, hObjectId, hExpected,
                  RuntimeKernelRefinementEvent.projectedKernelStep?,
                  RuntimeKernelRefinementEvent.objectIdOfKind?, List.filterMap_append]
          · by_cases hPost : event.kind = "post_committed_cold_object"
            · cases hObjectId : event.objectId with
              | none =>
                  unfold RuntimeKernelRefinementEvent.checkShapeValid at hShape
                  simp [hPost, hObjectId] at hShape
              | some objectId =>
                  have hExpected :
                      contract.publicObjectUniverse[(consumed.filterMap
                          (RuntimeKernelRefinementEvent.objectIdOfKind?
                            "post_committed_cold_object")).length]? =
                        some objectId := by
                    rw [← hPostCommitted]
                    exact list_filterMap_getElem?_of_append_some
                      (consumed := consumed) (entry := event) (suffix := suffix)
                      (by simp [RuntimeKernelRefinementEvent.objectIdOfKind?, hPost, hObjectId])
                  simp [RuntimeShellReplayState.step?, RuntimeShellReplayState.ofPrefix, hStep,
                    hPost, hObjectId, hExpected,
                    RuntimeKernelRefinementEvent.projectedKernelStep?,
                    RuntimeKernelRefinementEvent.objectIdOfKind?,
                    List.filterMap_append]
            · have : False := by
                unfold RuntimeKernelRefinementEvent.checkShapeValid at hShape
                simp [runtimeKernelRefinementEventKindNames, hPre, hShadow, hKernelStep,
                  hCommitObject, hColdStoreObject, hPost] at hShape
              contradiction

theorem runtimeShellReplayState_replaySuffix
  (contract : RuntimeShellContract)
  (consumed suffix : List RuntimeKernelRefinementEvent)
  (phase finalPhase : RuntimeKernelRefinementPhase)
  (hPhase : suffix.foldlM RuntimeKernelRefinementPhase.step phase = some finalPhase)
  (hProjected :
    ((consumed ++ suffix).filterMap RuntimeKernelRefinementEvent.projectedKernelStep?) =
      contract.kernelSchedule.steps)
  (hPreCommitted :
    ((consumed ++ suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "pre_committed_cold_object")) =
      contract.publicObjectUniverse)
  (hPostCommitted :
    ((consumed ++ suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "post_committed_cold_object")) =
      contract.publicObjectUniverse)
  (hShadowLoad :
    ((consumed ++ suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "shadow_load_object")) =
      contract.canonicalLoadedObjectSchedule)
  (hCommit :
    ((consumed ++ suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "commit_object")) =
      contract.canonicalLoadedObjectSchedule)
  (hColdStore :
    ((consumed ++ suffix).filterMap
        (RuntimeKernelRefinementEvent.objectIdOfKind? "cold_store_object")) =
      contract.canonicalLoadedObjectSchedule) :
  suffix.foldlM (RuntimeShellReplayState.step? contract)
      (RuntimeShellReplayState.ofPrefix consumed phase) =
    some (RuntimeShellReplayState.ofPrefix (consumed ++ suffix) finalPhase) := by
  induction suffix generalizing consumed phase with
  | nil =>
      simp at hPhase
      subst finalPhase
      simp [RuntimeShellReplayState.ofPrefix]
  | cons event rest ih =>
      cases hNext : RuntimeKernelRefinementPhase.step phase event with
      | none =>
          simp [List.foldlM_cons, hNext] at hPhase
      | some nextPhase =>
          simp [List.foldlM_cons, hNext] at hPhase
          have hHead :
              RuntimeShellReplayState.step? contract
                  (RuntimeShellReplayState.ofPrefix consumed phase) event =
                some (RuntimeShellReplayState.ofPrefix (consumed ++ [event]) nextPhase) := by
            exact runtimeShellReplayState_step?_of_phaseStep
              contract consumed event rest phase nextPhase hNext
              hProjected hPreCommitted hPostCommitted hShadowLoad hCommit hColdStore
          rw [List.foldlM_cons, hHead]
          have hTail :=
            ih (consumed := consumed ++ [event]) (phase := nextPhase) hPhase
              (by simpa [List.append_assoc] using hProjected)
              (by simpa [List.append_assoc] using hPreCommitted)
              (by simpa [List.append_assoc] using hPostCommitted)
              (by simpa [List.append_assoc] using hShadowLoad)
              (by simpa [List.append_assoc] using hCommit)
              (by simpa [List.append_assoc] using hColdStore)
          simpa [List.append_assoc] using hTail

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

instance (trace : RuntimeShellTrace) (contract : RuntimeShellContract) :
    Decidable (trace.Refines contract) := by
  unfold RuntimeShellTrace.Refines
  infer_instance

def RuntimeShellTrace.ProofGradeRefines
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) : Prop :=
  trace.eventsMatchSummaries ∧
    trace.replaysContract contract ∧
    trace.Refines contract

def RuntimeShellTrace.checkProofGradeRefines
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) : Bool :=
  trace.checkEventsMatchSummaries &&
    trace.checkReplaysContract contract &&
    decide (trace.Refines contract)

@[simp] theorem runtimeShellTrace_checkProofGradeRefines_eq_true_iff
  (trace : RuntimeShellTrace)
  (contract : RuntimeShellContract) :
  trace.checkProofGradeRefines contract = true ↔ trace.ProofGradeRefines contract := by
  unfold RuntimeShellTrace.checkProofGradeRefines RuntimeShellTrace.ProofGradeRefines
  simp [runtimeShellTrace_checkEventsMatchSummaries_eq_true_iff,
    runtimeShellTrace_checkReplaysContract_eq_true_iff, and_assoc]

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

structure RuntimeKernelInterfaceBundle where
  shellBoundaryBundle : RuntimeShellBoundaryBundle
  expectedKernelSteps : List RuntimeKernelStep
  expectedPublicObjectIds : List Nat
  expectedKernelSchedule : RuntimeKernelSchedule

def RuntimeRefinementWitness.shellBoundaryBundle?
  (witness : RuntimeRefinementWitness) : Option RuntimeShellBoundaryBundle := do
  let kernelWitness ← witness.kernelWitness
  let runtimeKernelRefinementWitness ← witness.runtimeKernelRefinementWitness
  pure
    { kernelWitness := kernelWitness
    , runtimeKernelRefinementWitness := runtimeKernelRefinementWitness
    , shellContract := kernelWitness.shellContract
    , shellTrace := runtimeKernelRefinementWitness.shellTrace
    }

def RuntimeRefinementWitness.kernelInterfaceBundle?
  (witness : RuntimeRefinementWitness) : Option RuntimeKernelInterfaceBundle := do
  let shellBoundaryBundle ← witness.shellBoundaryBundle?
  let expectedKernelSteps ← shellBoundaryBundle.kernelWitness.expectedKernelSteps
  let expectedPublicObjectIds ← shellBoundaryBundle.kernelWitness.expectedPublicObjectIds
  let expectedKernelSchedule ← shellBoundaryBundle.kernelWitness.expectedKernelSchedule?
  pure
    { shellBoundaryBundle := shellBoundaryBundle
    , expectedKernelSteps := expectedKernelSteps
    , expectedPublicObjectIds := expectedPublicObjectIds
    , expectedKernelSchedule := expectedKernelSchedule
    }

def RuntimeShellBoundaryBundle.Valid
  (bundle : RuntimeShellBoundaryBundle) : Prop :=
  bundle.kernelWitness.ProofGradeValid bundle.kernelWitness.entrypointId ∧
    bundle.runtimeKernelRefinementWitness.Valid bundle.kernelWitness ∧
    bundle.shellContract = bundle.kernelWitness.shellContract ∧
    bundle.shellTrace = bundle.runtimeKernelRefinementWitness.shellTrace ∧
    bundle.shellTrace.ProofGradeRefines bundle.shellContract

def RuntimeKernelInterfaceBundle.Valid
  (bundle : RuntimeKernelInterfaceBundle) : Prop :=
  bundle.shellBoundaryBundle.Valid ∧
    bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.RefinesLeanKernelState
      bundle.shellBoundaryBundle.kernelWitness ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.expectedKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps = bundle.expectedKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedPublicObjectIds =
      some bundle.expectedPublicObjectIds ∧
    bundle.shellBoundaryBundle.kernelWitness.publicObjectIds =
      bundle.expectedPublicObjectIds ∧
    bundle.shellBoundaryBundle.kernelWitness.replayedResourceState? =
      some bundle.shellBoundaryBundle.kernelWitness.claimedResourceState ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSchedule? =
      some bundle.expectedKernelSchedule ∧
    bundle.shellBoundaryBundle.kernelWitness.emittedKernelSchedule =
      bundle.expectedKernelSchedule ∧
    bundle.expectedKernelSchedule.finalState? =
      some
        { phase := .finished
        , publicObjectSchedule := bundle.expectedKernelSchedule.publicObjectSchedule
        }

/--
Explicit theorem object for the runtime-to-Lean kernel refinement boundary.
This packages the exact finished Lean schedule state witnessed by the shared
runtime/kernel interface, rather than leaving that relation only as an
existential proposition. This is the local proof target that a future
Rust-to-Lean implementation-refinement theorem should refine directly.
-/
structure RuntimeKernelRefinementBoundary where
  kernelWitness : RuntimeKernelWitness
  runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness
  expectedKernelSchedule : RuntimeKernelSchedule
  kernelWitnessProofGrade :
    kernelWitness.ProofGradeValid kernelWitness.entrypointId
  refinementValid :
    runtimeKernelRefinementWitness.Valid kernelWitness
  resourceStateExact :
    kernelWitness.replayedResourceState? = some kernelWitness.claimedResourceState
  expectedKernelScheduleExact :
    kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule
  emittedKernelScheduleExact :
    kernelWitness.emittedKernelSchedule = expectedKernelSchedule
  finalKernelScheduleStateExact :
    expectedKernelSchedule.finalState? =
      some
        { phase := .finished
        , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
        }
  projectedKernelScheduleExact :
    runtimeKernelRefinementWitness.projectedKernelSchedule =
      kernelWitness.emittedKernelSchedule
  preCommittedColdObjectScheduleExact :
    runtimeKernelRefinementWitness.preCommittedColdObjectSchedule =
      kernelWitness.publicObjectIds
  postCommittedColdObjectScheduleExact :
    runtimeKernelRefinementWitness.postCommittedColdObjectSchedule =
      kernelWitness.publicObjectIds
  shadowLoadObjectScheduleExact :
    runtimeKernelRefinementWitness.shadowLoadObjectSchedule =
      kernelWitness.canonicalLoadedObjectSchedule
  commitObjectScheduleExact :
    runtimeKernelRefinementWitness.commitObjectSchedule =
      kernelWitness.canonicalLoadedObjectSchedule
  coldStoreObjectScheduleExact :
    runtimeKernelRefinementWitness.coldStoreObjectSchedule =
      kernelWitness.canonicalLoadedObjectSchedule

theorem RuntimeKernelRefinementBoundary.toRefinesLeanKernelState
  (boundary : RuntimeKernelRefinementBoundary) :
  boundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.kernelWitness := by
  refine ⟨boundary.expectedKernelSchedule, boundary.kernelWitnessProofGrade,
    boundary.refinementValid, boundary.resourceStateExact,
    boundary.expectedKernelScheduleExact, boundary.emittedKernelScheduleExact,
    boundary.finalKernelScheduleStateExact, boundary.projectedKernelScheduleExact,
    boundary.preCommittedColdObjectScheduleExact,
    boundary.postCommittedColdObjectScheduleExact,
    boundary.shadowLoadObjectScheduleExact, boundary.commitObjectScheduleExact,
    boundary.coldStoreObjectScheduleExact⟩

noncomputable def RuntimeKernelInterfaceBundle.refinementBoundary
  {bundle : RuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) : RuntimeKernelRefinementBoundary := by
  let hKernelStateRefinementSpec := Classical.choose_spec hValid.2.1
  exact
    { kernelWitness := bundle.shellBoundaryBundle.kernelWitness
    , runtimeKernelRefinementWitness := bundle.shellBoundaryBundle.runtimeKernelRefinementWitness
    , expectedKernelSchedule := bundle.expectedKernelSchedule
    , kernelWitnessProofGrade := hValid.1.1
    , refinementValid := hValid.1.2.1
    , resourceStateExact := hValid.2.2.2.2.2.2.1
    , expectedKernelScheduleExact := hValid.2.2.2.2.2.2.2.1
    , emittedKernelScheduleExact := hValid.2.2.2.2.2.2.2.2.1
    , finalKernelScheduleStateExact := hValid.2.2.2.2.2.2.2.2.2
    , projectedKernelScheduleExact := hKernelStateRefinementSpec.2.2.2.2.2.2.1
    , preCommittedColdObjectScheduleExact := hKernelStateRefinementSpec.2.2.2.2.2.2.2.1
    , postCommittedColdObjectScheduleExact := hKernelStateRefinementSpec.2.2.2.2.2.2.2.2.1
    , shadowLoadObjectScheduleExact := hKernelStateRefinementSpec.2.2.2.2.2.2.2.2.2.1
    , commitObjectScheduleExact := hKernelStateRefinementSpec.2.2.2.2.2.2.2.2.2.2.1
    , coldStoreObjectScheduleExact := hKernelStateRefinementSpec.2.2.2.2.2.2.2.2.2.2.2
    }

theorem runtimeKernelInterfaceBundle_refinementBoundary_kernelWitness_exact
  {bundle : RuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  (bundle.refinementBoundary hValid).kernelWitness =
    bundle.shellBoundaryBundle.kernelWitness := by
  rfl

theorem runtimeKernelInterfaceBundle_refinementBoundary_runtimeKernelRefinementWitness_exact
  {bundle : RuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  (bundle.refinementBoundary hValid).runtimeKernelRefinementWitness =
    bundle.shellBoundaryBundle.runtimeKernelRefinementWitness := by
  rfl

theorem runtimeKernelInterfaceBundle_valid_projects_to_runtimeKernelRefinementBoundary
  {bundle : RuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (bundle.refinementBoundary hValid).runtimeKernelRefinementWitness
      (bundle.refinementBoundary hValid).kernelWitness := by
  exact RuntimeKernelRefinementBoundary.toRefinesLeanKernelState _

theorem runtimeRefinementWitness_shellBoundaryBundle_exact
  {witness : RuntimeRefinementWitness}
  {bundle : RuntimeShellBoundaryBundle}
  (hBundle : witness.shellBoundaryBundle? = some bundle) :
  witness.kernelWitness = some bundle.kernelWitness ∧
    witness.runtimeKernelRefinementWitness = some bundle.runtimeKernelRefinementWitness ∧
    bundle.shellContract = bundle.kernelWitness.shellContract ∧
    bundle.shellTrace = bundle.runtimeKernelRefinementWitness.shellTrace := by
  unfold RuntimeRefinementWitness.shellBoundaryBundle? at hBundle
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [hKernel] at hBundle
  | some kernelWitness =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [hKernel, hRefinement] at hBundle
      | some runtimeKernelRefinementWitness =>
          have hBundleSome :
              some
                  { kernelWitness := kernelWitness
                  , runtimeKernelRefinementWitness := runtimeKernelRefinementWitness
                  , shellContract := kernelWitness.shellContract
                  , shellTrace := runtimeKernelRefinementWitness.shellTrace
                  } =
                some bundle := by
            simpa [hKernel, hRefinement] using hBundle
          have hBundleEq :
              { kernelWitness := kernelWitness
              , runtimeKernelRefinementWitness := runtimeKernelRefinementWitness
              , shellContract := kernelWitness.shellContract
              , shellTrace := runtimeKernelRefinementWitness.shellTrace
              } = bundle := by
            exact Option.some.inj hBundleSome
          cases hBundleEq
          simp

theorem runtimeRefinementWitness_kernelInterfaceBundle_exact
  {witness : RuntimeRefinementWitness}
  {bundle : RuntimeKernelInterfaceBundle}
  (hBundle : witness.kernelInterfaceBundle? = some bundle) :
  witness.shellBoundaryBundle? = some bundle.shellBoundaryBundle ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.expectedKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedPublicObjectIds =
      some bundle.expectedPublicObjectIds ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSchedule? =
      some bundle.expectedKernelSchedule := by
  unfold RuntimeRefinementWitness.kernelInterfaceBundle? at hBundle
  cases hShell : witness.shellBoundaryBundle? with
  | none =>
      simp [hShell] at hBundle
  | some shellBoundaryBundle =>
      cases hExpectedSteps : shellBoundaryBundle.kernelWitness.expectedKernelSteps with
      | none =>
          simp [hShell, hExpectedSteps] at hBundle
      | some expectedKernelSteps =>
          cases hExpectedPublic :
              shellBoundaryBundle.kernelWitness.expectedPublicObjectIds with
          | none =>
              simp [hShell, hExpectedSteps, hExpectedPublic] at hBundle
          | some expectedPublicObjectIds =>
              cases hExpectedSchedule :
                  shellBoundaryBundle.kernelWitness.expectedKernelSchedule? with
              | none =>
                  simp [hShell, hExpectedSteps, hExpectedPublic, hExpectedSchedule] at hBundle
              | some expectedKernelSchedule =>
                  have hBundleSome :
                      some
                          { shellBoundaryBundle := shellBoundaryBundle
                          , expectedKernelSteps := expectedKernelSteps
                          , expectedPublicObjectIds := expectedPublicObjectIds
                          , expectedKernelSchedule := expectedKernelSchedule
                          } =
                        some bundle := by
                    simpa [hShell, hExpectedSteps, hExpectedPublic, hExpectedSchedule] using
                      hBundle
                  have hBundleEq :
                      { shellBoundaryBundle := shellBoundaryBundle
                      , expectedKernelSteps := expectedKernelSteps
                      , expectedPublicObjectIds := expectedPublicObjectIds
                      , expectedKernelSchedule := expectedKernelSchedule
                      } = bundle := by
                    exact Option.some.inj hBundleSome
                  cases hBundleEq
                  simp [hExpectedSteps, hExpectedPublic, hExpectedSchedule]

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

theorem runtimeKernelRefinementWitness_shellTrace_eventsMatchSummaries
  (runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness) :
  runtimeKernelRefinementWitness.shellTrace.eventsMatchSummaries := by
  unfold RuntimeKernelRefinementWitness.shellTrace RuntimeShellTrace.eventsMatchSummaries
    RuntimeShellTrace.projectedKernelScheduleFromEvents
    RuntimeShellTrace.preCommittedColdObjectScheduleFromEvents
    RuntimeShellTrace.shadowLoadObjectScheduleFromEvents
    RuntimeShellTrace.commitObjectScheduleFromEvents
    RuntimeShellTrace.coldStoreObjectScheduleFromEvents
    RuntimeShellTrace.postCommittedColdObjectScheduleFromEvents
    RuntimeShellTrace.objectScheduleFromEvents
    RuntimeKernelRefinementWitness.projectedKernelSchedule
    RuntimeKernelRefinementWitness.preCommittedColdObjectSchedule
    RuntimeKernelRefinementWitness.shadowLoadObjectSchedule
    RuntimeKernelRefinementWitness.commitObjectSchedule
    RuntimeKernelRefinementWitness.coldStoreObjectSchedule
    RuntimeKernelRefinementWitness.postCommittedColdObjectSchedule
  simp

theorem runtimeShellBoundaryBundle_trace_eventsMatchSummaries
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellTrace.eventsMatchSummaries := by
  exact hValid.2.2.2.2.1

theorem runtimeShellBoundaryBundle_refines
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellTrace.Refines bundle.shellContract := by
  exact hValid.2.2.2.2.2.2

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

theorem runtimeKernelRefinementWitness_valid_replaysShellContract
  {runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness}
  {kernelWitness : RuntimeKernelWitness}
  (hValid : runtimeKernelRefinementWitness.Valid kernelWitness) :
  runtimeKernelRefinementWitness.shellTrace.replaysContract kernelWitness.shellContract := by
  rcases hValid with
    ⟨_hShape, hTerminates, hProjectedKernelSchedule, hPreCommittedCold, hPostCommittedCold,
      hShadowEqualsCommit, hShadowEqualsColdStore, hShadowEqualsCanonical, _hCoverage⟩
  have hCommitCanonical :
      runtimeKernelRefinementWitness.commitObjectSchedule =
        kernelWitness.canonicalLoadedObjectSchedule := by
    calc
      runtimeKernelRefinementWitness.commitObjectSchedule =
          runtimeKernelRefinementWitness.shadowLoadObjectSchedule := by
            symm
            exact hShadowEqualsCommit
      _ = kernelWitness.canonicalLoadedObjectSchedule := hShadowEqualsCanonical
  have hColdStoreCanonical :
      runtimeKernelRefinementWitness.coldStoreObjectSchedule =
        kernelWitness.canonicalLoadedObjectSchedule := by
    calc
      runtimeKernelRefinementWitness.coldStoreObjectSchedule =
          runtimeKernelRefinementWitness.shadowLoadObjectSchedule := by
            symm
            exact hShadowEqualsColdStore
      _ = kernelWitness.canonicalLoadedObjectSchedule := hShadowEqualsCanonical
  have hTerminalPhase :
      ∃ finalPhase,
        runtimeKernelRefinementWitness.replayedPhase? = some finalPhase ∧
          (finalPhase = .afterWipe ∨
            finalPhase = .coldStoreWindow ∨
            finalPhase = .postCommittedColdWindow) := by
    unfold RuntimeKernelRefinementWitness.phaseTerminates
      RuntimeKernelRefinementWitness.replayedPhase? at hTerminates
    cases hReplay :
        runtimeKernelRefinementWitness.events.foldlM RuntimeKernelRefinementPhase.step .beforeBegin with
    | none =>
        simp [hReplay] at hTerminates
    | some finalPhase =>
        cases finalPhase with
        | beforeBegin =>
            simp [hReplay] at hTerminates
        | preCommittedColdWindow =>
            simp [hReplay] at hTerminates
        | shadowLoadWindow =>
            simp [hReplay] at hTerminates
        | activeKernel =>
            simp [hReplay] at hTerminates
        | commitObjectWindow =>
            simp [hReplay] at hTerminates
        | afterWipe =>
            exact ⟨.afterWipe, hReplay, Or.inl rfl⟩
        | coldStoreWindow =>
            exact ⟨.coldStoreWindow, hReplay, Or.inr (Or.inl rfl)⟩
        | postCommittedColdWindow =>
            exact ⟨.postCommittedColdWindow, hReplay, Or.inr (Or.inr rfl)⟩
  rcases hTerminalPhase with ⟨finalPhase, hReplay, hTerminal⟩
  have hProjectedSteps :
      runtimeKernelRefinementWitness.events.filterMap
          RuntimeKernelRefinementEvent.projectedKernelStep? =
        kernelWitness.emittedKernelSchedule.steps := by
    simpa [RuntimeKernelRefinementWitness.projectedKernelSchedule] using
      congrArg RuntimeKernelSchedule.steps hProjectedKernelSchedule
  have hPreCommittedEvents :
      runtimeKernelRefinementWitness.events.filterMap
          (RuntimeKernelRefinementEvent.objectIdOfKind? "pre_committed_cold_object") =
        kernelWitness.publicObjectIds := by
    simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.preCommittedColdObjectSchedule] using hPreCommittedCold
  have hPostCommittedEvents :
      runtimeKernelRefinementWitness.events.filterMap
          (RuntimeKernelRefinementEvent.objectIdOfKind? "post_committed_cold_object") =
        kernelWitness.publicObjectIds := by
    simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.postCommittedColdObjectSchedule] using hPostCommittedCold
  have hShadowEvents :
      runtimeKernelRefinementWitness.events.filterMap
          (RuntimeKernelRefinementEvent.objectIdOfKind? "shadow_load_object") =
        kernelWitness.canonicalLoadedObjectSchedule := by
    simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.shadowLoadObjectSchedule] using hShadowEqualsCanonical
  have hCommitEvents :
      runtimeKernelRefinementWitness.events.filterMap
          (RuntimeKernelRefinementEvent.objectIdOfKind? "commit_object") =
        kernelWitness.canonicalLoadedObjectSchedule := by
    simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.commitObjectSchedule] using hCommitCanonical
  have hColdStoreEvents :
      runtimeKernelRefinementWitness.events.filterMap
          (RuntimeKernelRefinementEvent.objectIdOfKind? "cold_store_object") =
        kernelWitness.canonicalLoadedObjectSchedule := by
    simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.coldStoreObjectSchedule] using hColdStoreCanonical
  have hReplayState :
      runtimeKernelRefinementWitness.shellTrace.replayedState? kernelWitness.shellContract =
        some (RuntimeShellReplayState.ofPrefix runtimeKernelRefinementWitness.events finalPhase) := by
    unfold RuntimeKernelRefinementWitness.shellTrace RuntimeShellTrace.replayedState?
      RuntimeKernelWitness.shellContract
    simpa [RuntimeShellReplayState.ofPrefix, RuntimeShellReplayState.initial] using
      runtimeShellReplayState_replaySuffix
        kernelWitness.shellContract [] runtimeKernelRefinementWitness.events .beforeBegin finalPhase
        hReplay hProjectedSteps hPreCommittedEvents hPostCommittedEvents hShadowEvents
        hCommitEvents hColdStoreEvents
  unfold RuntimeShellTrace.replaysContract
  rw [hReplayState]
  unfold RuntimeShellReplayState.terminal RuntimeShellReplayState.ofPrefix
    RuntimeKernelWitness.shellContract
  refine ⟨hTerminal, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.preCommittedColdObjectSchedule] using
      congrArg List.length hPreCommittedCold
  · have hProjectedStepLengths :
        runtimeKernelRefinementWitness.projectedKernelSchedule.steps.length =
          kernelWitness.emittedKernelSchedule.steps.length := by
      exact congrArg List.length (congrArg RuntimeKernelSchedule.steps hProjectedKernelSchedule)
    simpa [RuntimeKernelRefinementWitness.projectedKernelSchedule] using hProjectedStepLengths
  · simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.shadowLoadObjectSchedule] using
      congrArg List.length hShadowEqualsCanonical
  · simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.commitObjectSchedule] using
      congrArg List.length hCommitCanonical
  · simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.coldStoreObjectSchedule] using
      congrArg List.length hColdStoreCanonical
  · simpa [RuntimeKernelRefinementEvent.objectIdOfKind?,
      RuntimeKernelRefinementWitness.postCommittedColdObjectSchedule] using
      congrArg List.length hPostCommittedCold

theorem runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract
  {runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness}
  {kernelWitness : RuntimeKernelWitness}
  (hValid : runtimeKernelRefinementWitness.Valid kernelWitness) :
  runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines kernelWitness.shellContract := by
  refine ⟨runtimeKernelRefinementWitness_shellTrace_eventsMatchSummaries
      runtimeKernelRefinementWitness, ?_, ?_⟩
  · exact runtimeKernelRefinementWitness_valid_replaysShellContract hValid
  · exact runtimeKernelRefinementWitness_valid_refinesShellContract hValid

theorem RuntimeKernelRefinementBoundary.witness_refinesShellContract
  (boundary : RuntimeKernelRefinementBoundary) :
  boundary.runtimeKernelRefinementWitness.shellTrace.Refines
    boundary.kernelWitness.shellContract := by
  exact
    (runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract
      boundary.refinementValid).2.2

theorem runtimeWitness_proofGradeShellContractRefinement
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernelWitness = some kernelWitness ∧
      witness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract := by
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
            runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract hWitnessValid⟩

theorem runtimeWitness_proofGradeShellBoundaryBundle_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ bundle,
    witness.shellBoundaryBundle? = some bundle ∧
      bundle.Valid := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid :=
    runtimeWitness_proofGradeRuntimeKernelRefinementWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          have hKernelProofGrade :
              kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
            simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
              hKernelValid
          have hKernelProofGradeSelf :
              kernelWitness.ProofGradeValid kernelWitness.entrypointId :=
            runtimeKernelWitness_proofGradeValid_self hKernelProofGrade
          have hWitnessValid : runtimeKernelRefinementWitness.Valid kernelWitness := by
            simpa [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
              hKernel, hRefinement] using hRefinementValid
          let bundle : RuntimeShellBoundaryBundle :=
            { kernelWitness := kernelWitness
            , runtimeKernelRefinementWitness := runtimeKernelRefinementWitness
            , shellContract := kernelWitness.shellContract
            , shellTrace := runtimeKernelRefinementWitness.shellTrace
            }
          refine ⟨bundle, ?_, ?_⟩
          · simp [RuntimeRefinementWitness.shellBoundaryBundle?, hKernel, hRefinement, bundle]
          · refine ⟨hKernelProofGradeSelf, hWitnessValid, rfl, rfl, ?_⟩
            exact
              runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract
                hWitnessValid

theorem runtimeShellBoundaryBundle_trace_replaysContract
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellTrace.replaysContract bundle.shellContract := by
  exact hValid.2.2.2.2.2.1

theorem runtimeShellBoundaryBundle_proofGradeRefines
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.shellTrace.ProofGradeRefines bundle.shellContract := by
  exact hValid.2.2.2.2

theorem runtimeShellBoundaryBundle_witness_proofGradeRefines
  {bundle : RuntimeShellBoundaryBundle}
  (hValid : bundle.Valid) :
  bundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
      bundle.kernelWitness.shellContract := by
  have hContractExact := runtimeShellBoundaryBundle_contract_exact hValid
  have hTraceExact := runtimeShellBoundaryBundle_trace_exact hValid
  have hRefines := runtimeShellBoundaryBundle_proofGradeRefines hValid
  simpa [hContractExact, hTraceExact] using hRefines

/--
Explicit theorem object for the full runtime-side confinement boundary.
This packages both halves of the runtime story that the paper route now needs:
the lower-level runtime phase witness refines one exact finished Lean kernel
state, and the shell trace outside the confidential kernel refines the public
shell contract induced by that same witness.
-/
structure RuntimeKernelConfinementBoundary where
  refinementBoundary : RuntimeKernelRefinementBoundary
  shellContract : RuntimeShellContract
  shellTrace : RuntimeShellTrace
  shellContractExact :
    shellContract = refinementBoundary.kernelWitness.shellContract
  shellTraceExact :
    shellTrace = refinementBoundary.runtimeKernelRefinementWitness.shellTrace
  shellTraceProofGradeRefines :
    shellTrace.ProofGradeRefines shellContract

theorem RuntimeKernelConfinementBoundary.toRefinesLeanKernelState
  (boundary : RuntimeKernelConfinementBoundary) :
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.refinementBoundary.kernelWitness := by
  exact RuntimeKernelRefinementBoundary.toRefinesLeanKernelState
    boundary.refinementBoundary

theorem RuntimeKernelConfinementBoundary.toProofGradeRefinesShellContract
  (boundary : RuntimeKernelConfinementBoundary) :
  boundary.shellTrace.ProofGradeRefines boundary.shellContract := by
  exact boundary.shellTraceProofGradeRefines

theorem RuntimeKernelConfinementBoundary.toRefinesShellContract
  (boundary : RuntimeKernelConfinementBoundary) :
  boundary.shellTrace.Refines boundary.shellContract := by
  exact boundary.shellTraceProofGradeRefines.2.2

theorem RuntimeKernelConfinementBoundary.witness_refinesShellContract
  (boundary : RuntimeKernelConfinementBoundary) :
  boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
    boundary.refinementBoundary.kernelWitness.shellContract := by
  simpa [boundary.shellContractExact, boundary.shellTraceExact] using
    boundary.toRefinesShellContract

noncomputable def RuntimeKernelInterfaceBundle.confinementBoundary
  {bundle : RuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) : RuntimeKernelConfinementBoundary := by
  let refinementBoundary := bundle.refinementBoundary hValid
  refine
    { refinementBoundary := refinementBoundary
    , shellContract := refinementBoundary.kernelWitness.shellContract
    , shellTrace := refinementBoundary.runtimeKernelRefinementWitness.shellTrace
    , shellContractExact := rfl
    , shellTraceExact := rfl
    , shellTraceProofGradeRefines := ?_
    }
  exact runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract
    refinementBoundary.refinementValid

theorem runtimeKernelInterfaceBundle_valid_projects_to_runtimeKernelConfinementBoundary
  {bundle : RuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.confinementBoundary hValid
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract := by
  let boundary := bundle.confinementBoundary hValid
  exact
    ⟨RuntimeKernelConfinementBoundary.toRefinesLeanKernelState boundary,
      RuntimeKernelConfinementBoundary.witness_refinesShellContract boundary⟩

/--
Packaged proof-grade facts for the runtime/kernel boundary. This bundles the
exact kernel schedule, public object universe, resource-state replay, runtime
phase projection, and proof-grade shell-boundary refinement results that the
paper-facing argument needs from one accepted runtime witness.
-/
def RuntimeProofGradeKernelBoundaryFacts
  (witness : RuntimeRefinementWitness) : Prop :=
  ∃ kernelWitness runtimeKernelRefinementWitness
      expectedKernelSteps expectedPublicObjectIds expectedKernelSchedule,
    witness.kernelWitness = some kernelWitness ∧
      witness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      kernelWitness.expectedKernelSteps = some expectedKernelSteps ∧
      kernelWitness.kernelSteps = expectedKernelSteps ∧
      kernelWitness.expectedPublicObjectIds = some expectedPublicObjectIds ∧
      kernelWitness.publicObjectIds = expectedPublicObjectIds ∧
      kernelWitness.replayedResourceState? = some kernelWitness.claimedResourceState ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } ∧
      runtimeKernelRefinementWitness.projectedKernelSchedule =
        kernelWitness.emittedKernelSchedule ∧
      runtimeKernelRefinementWitness.preCommittedColdObjectSchedule =
        kernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.postCommittedColdObjectSchedule =
        kernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract

/--
Canonical theorem-facing runtime/kernel interface for one accepted runtime
witness. Besides the exact shell-boundary bundle, this packages the existing
kernel-step/object/resource exactness facts together with the theorem that the
lower-level runtime phase witness refines one exact finished Lean kernel state,
and the shell trace both matches its event summaries and replay-checks against
the exact shell contract.
-/
def RuntimeProofGradeKernelInterface
  (witness : RuntimeRefinementWitness) : Prop :=
  ∃ shellBoundaryBundle expectedKernelSteps expectedPublicObjectIds expectedKernelSchedule,
    witness.shellBoundaryBundle? = some shellBoundaryBundle ∧
      shellBoundaryBundle.Valid ∧
      shellBoundaryBundle.shellTrace.ProofGradeRefines shellBoundaryBundle.shellContract ∧
      shellBoundaryBundle.runtimeKernelRefinementWitness.RefinesLeanKernelState
        shellBoundaryBundle.kernelWitness ∧
      shellBoundaryBundle.kernelWitness.expectedKernelSteps = some expectedKernelSteps ∧
      shellBoundaryBundle.kernelWitness.kernelSteps = expectedKernelSteps ∧
      shellBoundaryBundle.kernelWitness.expectedPublicObjectIds = some expectedPublicObjectIds ∧
      shellBoundaryBundle.kernelWitness.publicObjectIds = expectedPublicObjectIds ∧
      shellBoundaryBundle.kernelWitness.replayedResourceState? =
        some shellBoundaryBundle.kernelWitness.claimedResourceState ∧
      shellBoundaryBundle.kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      shellBoundaryBundle.kernelWitness.emittedKernelSchedule = expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          }

/--
Explicit-bundle variant of the theorem-facing runtime/kernel interface. This
packages the same proof obligations through the runtime-exported
`RuntimeKernelInterfaceBundle`, so downstream theorem routes can name the
bundle object directly instead of reconstructing the interface shape from raw
witness fields.
-/
def RuntimeProofGradeKernelInterfaceBundle
  (witness : RuntimeRefinementWitness) : Prop :=
  ∃ bundle, witness.kernelInterfaceBundle? = some bundle ∧ bundle.Valid

@[simp] theorem runtimeRefinementWitness_shellBoundaryBundle_runtimeSeed
  (witness : RuntimeRefinementWitness)
  (runtimeSeed : Option Nat) :
  ({ witness with runtimeSeed := runtimeSeed }).shellBoundaryBundle? =
    witness.shellBoundaryBundle? := by
  cases witness <;> rfl

@[simp] theorem runtimeRefinementWitness_kernelInterfaceBundle_runtimeSeed
  (witness : RuntimeRefinementWitness)
  (runtimeSeed : Option Nat) :
  ({ witness with runtimeSeed := runtimeSeed }).kernelInterfaceBundle? =
    witness.kernelInterfaceBundle? := by
  cases witness <;> rfl

@[simp] theorem runtimeProofGradeKernelInterfaceBundle_runtimeSeed_iff
  (witness : RuntimeRefinementWitness)
  (runtimeSeed : Option Nat) :
  RuntimeProofGradeKernelInterfaceBundle { witness with runtimeSeed := runtimeSeed } ↔
    RuntimeProofGradeKernelInterfaceBundle witness := by
  unfold RuntimeProofGradeKernelInterfaceBundle
  simp

theorem runtimeKernelInterfaceBundle_toProofGradeKernelInterface
  {witness : RuntimeRefinementWitness}
  {bundle : RuntimeKernelInterfaceBundle}
  (hBundle : witness.kernelInterfaceBundle? = some bundle)
  (hValid : bundle.Valid) :
  RuntimeProofGradeKernelInterface witness := by
  rcases hValid with
    ⟨hShellValid, hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
      hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩
  have hExact := runtimeRefinementWitness_kernelInterfaceBundle_exact hBundle
  refine
    ⟨bundle.shellBoundaryBundle, bundle.expectedKernelSteps, bundle.expectedPublicObjectIds,
      bundle.expectedKernelSchedule, hExact.1, hShellValid, ?_, hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩
  exact runtimeShellBoundaryBundle_proofGradeRefines hShellValid

theorem runtimeKernelInterfaceBundle_toShellBoundaryBundle
  {witness : RuntimeRefinementWitness}
  {bundle : RuntimeKernelInterfaceBundle}
  (hBundle : witness.kernelInterfaceBundle? = some bundle)
  (hValid : bundle.Valid) :
  ∃ shellBoundaryBundle,
    witness.shellBoundaryBundle? = some shellBoundaryBundle ∧
      shellBoundaryBundle.Valid := by
  exact ⟨bundle.shellBoundaryBundle,
    (runtimeRefinementWitness_kernelInterfaceBundle_exact hBundle).1,
    hValid.1⟩

theorem runtimeProofGradeKernelInterfaceBundle_toProofGradeKernelInterface
  {witness : RuntimeRefinementWitness}
  (hBundle : RuntimeProofGradeKernelInterfaceBundle witness) :
  RuntimeProofGradeKernelInterface witness := by
  rcases hBundle with ⟨bundle, hExact, hValid⟩
  exact runtimeKernelInterfaceBundle_toProofGradeKernelInterface hExact hValid

theorem runtimeProofGradeKernelInterfaceBundle_toShellBoundaryBundle
  {witness : RuntimeRefinementWitness}
  (hBundle : RuntimeProofGradeKernelInterfaceBundle witness) :
  ∃ shellBoundaryBundle,
    witness.shellBoundaryBundle? = some shellBoundaryBundle ∧
      shellBoundaryBundle.Valid := by
  rcases hBundle with ⟨bundle, hExact, hValid⟩
  exact runtimeKernelInterfaceBundle_toShellBoundaryBundle hExact hValid

noncomputable def RuntimeProofGradeKernelInterfaceBundle.confinementBoundary
  {witness : RuntimeRefinementWitness}
  (hBundle : RuntimeProofGradeKernelInterfaceBundle witness) :
  RuntimeKernelConfinementBoundary := by
  let bundle := Classical.choose hBundle
  let hBundleSpec := Classical.choose_spec hBundle
  exact bundle.confinementBoundary hBundleSpec.2

theorem runtimeProofGradeKernelInterface_toShellBoundaryBundle
  {witness : RuntimeRefinementWitness}
  (hInterface : RuntimeProofGradeKernelInterface witness) :
  ∃ shellBoundaryBundle,
    witness.shellBoundaryBundle? = some shellBoundaryBundle ∧
      shellBoundaryBundle.Valid := by
  rcases hInterface with
    ⟨shellBoundaryBundle, _expectedKernelSteps, _expectedPublicObjectIds,
      _expectedKernelSchedule, hBundle, hValid, _hShellProofGradeRefinement,
      _hKernelStateRefinement, _hExpectedKernelSteps, _hKernelSteps,
      _hExpectedPublicObjectIds, _hPublicObjectIds, _hResourceState,
      _hExpectedKernelSchedule, _hEmittedKernelSchedule, _hFinalKernelScheduleState⟩
  exact ⟨shellBoundaryBundle, hBundle, hValid⟩

theorem runtimeProofGradeKernelInterface_toKernelBoundaryFacts
  {witness : RuntimeRefinementWitness}
  (hInterface : RuntimeProofGradeKernelInterface witness) :
  RuntimeProofGradeKernelBoundaryFacts witness := by
  rcases hInterface with
    ⟨shellBoundaryBundle, expectedKernelSteps, expectedPublicObjectIds, expectedKernelSchedule,
      hBundle, hBundleValid, _hShellProofGradeRefinement, hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩
  have hBundleExact := runtimeRefinementWitness_shellBoundaryBundle_exact hBundle
  rcases hKernelStateRefinement with
    ⟨expectedKernelScheduleFromRefinement, _hKernelProofGrade, _hRefinementValid,
      _hResourceStateFromRefinement, hExpectedKernelScheduleFromRefinement,
      _hEmittedKernelScheduleFromRefinement, _hFinalKernelScheduleStateFromRefinement,
      hProjectedKernelSchedule, hPreCommittedColdObjectSchedule,
      hPostCommittedColdObjectSchedule, _hShadowLoadObjectSchedule,
      _hCommitObjectSchedule, _hColdStoreObjectSchedule⟩
  have hExpectedKernelScheduleEq :
      some expectedKernelScheduleFromRefinement = some expectedKernelSchedule := by
    calc
      some expectedKernelScheduleFromRefinement =
          shellBoundaryBundle.kernelWitness.expectedKernelSchedule? := by
            symm
            exact hExpectedKernelScheduleFromRefinement
      _ = some expectedKernelSchedule := hExpectedKernelSchedule
  have hExpectedKernelScheduleEq' :
      expectedKernelScheduleFromRefinement = expectedKernelSchedule := by
    exact Option.some.inj hExpectedKernelScheduleEq
  subst expectedKernelScheduleFromRefinement
  exact
    ⟨shellBoundaryBundle.kernelWitness, shellBoundaryBundle.runtimeKernelRefinementWitness,
      expectedKernelSteps, expectedPublicObjectIds, expectedKernelSchedule,
      hBundleExact.1, hBundleExact.2.1, hExpectedKernelSteps, hKernelSteps,
      hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
      hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState,
      hProjectedKernelSchedule, hPreCommittedColdObjectSchedule,
      hPostCommittedColdObjectSchedule,
      runtimeShellBoundaryBundle_witness_proofGradeRefines hBundleValid⟩

theorem runtimeProofGradeKernelInterfaceBundle_toKernelBoundaryFacts
  {witness : RuntimeRefinementWitness}
  (hBundle : RuntimeProofGradeKernelInterfaceBundle witness) :
  RuntimeProofGradeKernelBoundaryFacts witness := by
  exact runtimeProofGradeKernelInterface_toKernelBoundaryFacts
    (runtimeProofGradeKernelInterfaceBundle_toProofGradeKernelInterface hBundle)

theorem runtimeWitness_proofGradeKernelBoundaryFacts
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  RuntimeProofGradeKernelBoundaryFacts witness := by
  rcases runtimeWitness_proofGradeShellContractRefinement witness modelTags hValid with
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel, hRefinement, hShellRefines⟩
  rcases runtimeWitness_proofGradeKernelSchedule_exact witness modelTags hValid with
    ⟨kernelWitnessSteps, expectedKernelSteps, hKernelStepsWitness, hExpectedKernelSteps,
      hKernelSteps⟩
  have hKernelEqSteps : kernelWitness = kernelWitnessSteps := by
    simpa [hKernelStepsWitness] using hKernel.symm
  subst kernelWitnessSteps
  rcases runtimeWitness_proofGradePublicObjectUniverse_exact witness modelTags hValid with
    ⟨kernelWitnessPublic, expectedPublicObjectIds, hKernelPublic,
      hExpectedPublicObjectIds, hPublicObjectIds⟩
  have hKernelEqPublic : kernelWitness = kernelWitnessPublic := by
    simpa [hKernelPublic] using hKernel.symm
  subst kernelWitnessPublic
  rcases runtimeWitness_proofGradeKernelResourceState_exact witness modelTags hValid with
    ⟨kernelWitnessResource, hKernelResource, hResourceState⟩
  have hKernelEqResource : kernelWitness = kernelWitnessResource := by
    simpa [hKernelResource] using hKernel.symm
  subst kernelWitnessResource
  rcases runtimeWitness_proofGradeKernelScheduleObject_exact witness modelTags hValid with
    ⟨kernelWitnessSchedule, expectedKernelSchedule, hKernelSchedule,
      hExpectedKernelSchedule, hEmittedKernelSchedule⟩
  have hKernelEqSchedule : kernelWitness = kernelWitnessSchedule := by
    simpa [hKernelSchedule] using hKernel.symm
  subst kernelWitnessSchedule
  rcases runtimeWitness_proofGradeKernelScheduleObject_finalState_exact
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
  rcases runtimeWitness_proofGradeRuntimeKernelRefinementProjection_exact
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
  rcases runtimeWitness_proofGradeRuntimeKernelRefinementBoundaryExact
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

theorem runtimeWitness_proofGradeKernelInterface
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  RuntimeProofGradeKernelInterface witness := by
  rcases runtimeWitness_proofGradeShellBoundaryBundle_valid witness modelTags hValid with
    ⟨shellBoundaryBundle, hBundle, hBundleValid⟩
  have hBundleExact :=
    runtimeRefinementWitness_shellBoundaryBundle_exact hBundle
  have hShellProofGradeRefinement :
      shellBoundaryBundle.shellTrace.ProofGradeRefines
        shellBoundaryBundle.shellContract :=
    runtimeShellBoundaryBundle_proofGradeRefines hBundleValid
  have hKernelStateRefinement :
      shellBoundaryBundle.runtimeKernelRefinementWitness.RefinesLeanKernelState
        shellBoundaryBundle.kernelWitness := by
    have hKernelProofGrade :
        shellBoundaryBundle.kernelWitness.ProofGradeValid
          shellBoundaryBundle.kernelWitness.entrypointId := hBundleValid.1
    have hRefinementWitnessValid :
        shellBoundaryBundle.runtimeKernelRefinementWitness.Valid
          shellBoundaryBundle.kernelWitness := hBundleValid.2.1
    exact runtimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
      hKernelProofGrade hRefinementWitnessValid
  rcases runtimeWitness_proofGradeKernelSchedule_exact witness modelTags hValid with
    ⟨kernelWitnessSteps, expectedKernelSteps, hKernelStepsWitness, hExpectedKernelSteps,
      hKernelSteps⟩
  have hKernelEqSteps : shellBoundaryBundle.kernelWitness = kernelWitnessSteps := by
    apply Option.some.inj
    exact hBundleExact.1.symm.trans hKernelStepsWitness
  subst hKernelEqSteps
  rcases runtimeWitness_proofGradePublicObjectUniverse_exact witness modelTags hValid with
    ⟨kernelWitnessPublic, expectedPublicObjectIds, hKernelPublic,
      hExpectedPublicObjectIds, hPublicObjectIds⟩
  have hKernelEqPublic : shellBoundaryBundle.kernelWitness = kernelWitnessPublic := by
    apply Option.some.inj
    exact hBundleExact.1.symm.trans hKernelPublic
  subst hKernelEqPublic
  rcases runtimeWitness_proofGradeKernelResourceState_exact witness modelTags hValid with
    ⟨kernelWitnessResource, hKernelResource, hResourceState⟩
  have hKernelEqResource : shellBoundaryBundle.kernelWitness = kernelWitnessResource := by
    apply Option.some.inj
    exact hBundleExact.1.symm.trans hKernelResource
  subst hKernelEqResource
  rcases runtimeWitness_proofGradeKernelScheduleObject_exact witness modelTags hValid with
    ⟨kernelWitnessSchedule, expectedKernelSchedule, hKernelSchedule,
      hExpectedKernelSchedule, hEmittedKernelSchedule⟩
  have hKernelEqSchedule : shellBoundaryBundle.kernelWitness = kernelWitnessSchedule := by
    apply Option.some.inj
    exact hBundleExact.1.symm.trans hKernelSchedule
  subst hKernelEqSchedule
  rcases runtimeWitness_proofGradeKernelScheduleObject_finalState_exact
      witness modelTags hValid with
    ⟨kernelWitnessFinal, expectedKernelScheduleFinal, hKernelFinal,
      hExpectedKernelScheduleFinal, hFinalKernelScheduleState⟩
  have hKernelEqFinal : shellBoundaryBundle.kernelWitness = kernelWitnessFinal := by
    apply Option.some.inj
    exact hBundleExact.1.symm.trans hKernelFinal
  subst hKernelEqFinal
  have hExpectedKernelScheduleEq :
      expectedKernelSchedule = expectedKernelScheduleFinal := by
    apply Option.some.inj
    rw [← hExpectedKernelSchedule, hExpectedKernelScheduleFinal]
  subst hExpectedKernelScheduleEq
  exact
    ⟨shellBoundaryBundle, expectedKernelSteps, expectedPublicObjectIds, expectedKernelSchedule,
      hBundle, hBundleValid, hShellProofGradeRefinement, hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩

theorem runtimeWitness_proofGradeKernelInterfaceBundle_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ bundle, witness.kernelInterfaceBundle? = some bundle ∧ bundle.Valid := by
  rcases runtimeWitness_proofGradeKernelInterface witness modelTags hValid with
    ⟨shellBoundaryBundle, expectedKernelSteps, expectedPublicObjectIds, expectedKernelSchedule,
      hBundle, hBundleValid, _hShellProofGradeRefinement, hKernelStateRefinement,
      hExpectedKernelSteps, hKernelSteps, hExpectedPublicObjectIds, hPublicObjectIds,
      hResourceState, hExpectedKernelSchedule, hEmittedKernelSchedule,
      hFinalKernelScheduleState⟩
  let bundle : RuntimeKernelInterfaceBundle :=
    { shellBoundaryBundle := shellBoundaryBundle
    , expectedKernelSteps := expectedKernelSteps
    , expectedPublicObjectIds := expectedPublicObjectIds
    , expectedKernelSchedule := expectedKernelSchedule
    }
  refine ⟨bundle, ?_, ?_⟩
  · simp [RuntimeRefinementWitness.kernelInterfaceBundle?, hBundle,
      hExpectedKernelSteps, hExpectedPublicObjectIds, hExpectedKernelSchedule, bundle]
  · exact
      ⟨hBundleValid, hKernelStateRefinement, hExpectedKernelSteps, hKernelSteps,
        hExpectedPublicObjectIds, hPublicObjectIds, hResourceState,
        hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩

theorem runtimeWitness_proofGradeKernelInterfaceBundle
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  RuntimeProofGradeKernelInterfaceBundle witness := by
  simpa [RuntimeProofGradeKernelInterfaceBundle] using
    runtimeWitness_proofGradeKernelInterfaceBundle_valid witness modelTags hValid

end UOToolchain
