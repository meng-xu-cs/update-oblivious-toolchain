import UOToolchain.RuntimeRefinement
import UOToolchain.SgxRelation

namespace UOToolchain

/-!
# Adaptive history and ordered object-schedule surface

This module names the public transcript shape used when lifting the single-call
observer to adaptive call histories. It also makes the ordered logical object
schedule an explicit public leakage component for mixed exact/ORAM backends.
-/

structure HostCallRequest where
  entrypointId : String
  publicArgs : List String
deriving Repr, DecidableEq

structure HostCallObservation where
  publicOutcome : SGXPublicOutcome
  orderedObjectSchedule : List Nat
deriving Repr, DecidableEq

abbrev HostTranscript := List HostCallObservation

abbrev AdaptiveHostStrategy := HostTranscript → Option HostCallRequest

structure HistoryStepWitness where
  request : HostCallRequest
  observation : HostCallObservation
deriving Repr, DecidableEq

structure RuntimeHistory where
  steps : List HistoryStepWitness
deriving Repr, DecidableEq

def RuntimeHistory.publicTranscript
  (history : RuntimeHistory) : HostTranscript :=
  history.steps.map HistoryStepWitness.observation

def RuntimeHistory.orderedObjectSchedule
  (history : RuntimeHistory) : List Nat :=
  history.steps.flatMap (fun step => step.observation.orderedObjectSchedule)

def HistoryStepWitness.PublicEq
  (lhs rhs : HistoryStepWitness) : Prop :=
  lhs.request = rhs.request ∧ lhs.observation = rhs.observation

def HistoryStepWitness.checkPublicEq
  (lhs rhs : HistoryStepWitness) : Bool :=
  decide (lhs.request = rhs.request) && decide (lhs.observation = rhs.observation)

@[simp] theorem historyStepWitness_checkPublicEq_eq_true_iff
  (lhs rhs : HistoryStepWitness) :
  lhs.checkPublicEq rhs = true ↔ lhs.PublicEq rhs := by
  simp [HistoryStepWitness.checkPublicEq, HistoryStepWitness.PublicEq]

def HistoryStepsPublicEq : List HistoryStepWitness → List HistoryStepWitness → Prop
  | [], [] => True
  | lhs :: lhsTail, rhs :: rhsTail =>
      lhs.PublicEq rhs ∧ HistoryStepsPublicEq lhsTail rhsTail
  | _, _ => False

def checkHistoryStepsPublicEq : List HistoryStepWitness → List HistoryStepWitness → Bool
  | [], [] => true
  | lhs :: lhsTail, rhs :: rhsTail =>
      lhs.checkPublicEq rhs && checkHistoryStepsPublicEq lhsTail rhsTail
  | _, _ => false

@[simp] theorem checkHistoryStepsPublicEq_eq_true_iff
  (lhs rhs : List HistoryStepWitness) :
  checkHistoryStepsPublicEq lhs rhs = true ↔ HistoryStepsPublicEq lhs rhs := by
  induction lhs generalizing rhs with
  | nil =>
      cases rhs <;> simp [checkHistoryStepsPublicEq, HistoryStepsPublicEq]
  | cons lhsHead lhsTail ih =>
      cases rhs with
      | nil => simp [checkHistoryStepsPublicEq, HistoryStepsPublicEq]
      | cons rhsHead rhsTail =>
          simp [checkHistoryStepsPublicEq, HistoryStepsPublicEq, ih]

theorem historyStepsPublicEq_publicTranscript_eq
  {lhs rhs : List HistoryStepWitness}
  (hEq : HistoryStepsPublicEq lhs rhs) :
  lhs.map HistoryStepWitness.observation =
    rhs.map HistoryStepWitness.observation := by
  induction lhs generalizing rhs with
  | nil =>
      cases rhs <;> simp [HistoryStepsPublicEq] at hEq ⊢
  | cons lhsHead lhsTail ih =>
      cases rhs with
      | nil => simp [HistoryStepsPublicEq] at hEq
      | cons rhsHead rhsTail =>
          rcases hEq with ⟨hHead, hTail⟩
          simp [HistoryStepWitness.PublicEq] at hHead
          simp [hHead.2, ih hTail]

theorem runtimeHistory_publicTranscript_eq_of_stepwise_publicEq
  {lhs rhs : RuntimeHistory}
  (hEq : HistoryStepsPublicEq lhs.steps rhs.steps) :
  lhs.publicTranscript = rhs.publicTranscript := by
  exact historyStepsPublicEq_publicTranscript_eq hEq

theorem historyStepsPublicEq_orderedObjectSchedule_eq
  {lhs rhs : List HistoryStepWitness}
  (hEq : HistoryStepsPublicEq lhs rhs) :
  lhs.flatMap (fun step => step.observation.orderedObjectSchedule) =
    rhs.flatMap (fun step => step.observation.orderedObjectSchedule) := by
  induction lhs generalizing rhs with
  | nil =>
      cases rhs <;> simp [HistoryStepsPublicEq] at hEq ⊢
  | cons lhsHead lhsTail ih =>
      cases rhs with
      | nil => simp [HistoryStepsPublicEq] at hEq
      | cons rhsHead rhsTail =>
          rcases hEq with ⟨hHead, hTail⟩
          rcases hHead with ⟨_hRequest, hObservation⟩
          change
            lhsHead.observation.orderedObjectSchedule ++
                lhsTail.flatMap (fun step => step.observation.orderedObjectSchedule) =
              rhsHead.observation.orderedObjectSchedule ++
                rhsTail.flatMap (fun step => step.observation.orderedObjectSchedule)
          rw [hObservation, ih hTail]

theorem runtimeHistory_orderedObjectSchedule_eq_of_stepwise_publicEq
  {lhs rhs : RuntimeHistory}
  (hEq : HistoryStepsPublicEq lhs.steps rhs.steps) :
  lhs.orderedObjectSchedule = rhs.orderedObjectSchedule := by
  exact historyStepsPublicEq_orderedObjectSchedule_eq hEq

def HistoryFollowsStrategyFrom
  (strategy : AdaptiveHostStrategy) :
  HostTranscript → List HistoryStepWitness → Prop
  | transcript, [] => strategy transcript = none
  | transcript, step :: rest =>
      strategy transcript = some step.request ∧
        HistoryFollowsStrategyFrom strategy
          (transcript ++ [step.observation])
          rest

def RuntimeHistory.FollowsStrategy
  (history : RuntimeHistory)
  (strategy : AdaptiveHostStrategy) : Prop :=
  HistoryFollowsStrategyFrom strategy [] history.steps

theorem adaptiveHistory_nextRequest_eq_of_same_public_prefix
  {strategy : AdaptiveHostStrategy}
  {prefix₁ prefix₂ : HostTranscript}
  {request₁ request₂ : HostCallRequest}
  (hPrefix : prefix₁ = prefix₂)
  (h₁ : strategy prefix₁ = some request₁)
  (h₂ : strategy prefix₂ = some request₂) :
  request₁ = request₂ := by
  subst hPrefix
  rw [h₁] at h₂
  cases h₂
  rfl

inductive RuntimeObjectBackend where
  | exact
  | pathOram
deriving Repr, DecidableEq

structure PublicObjectBackend where
  objectId : Nat
  backend : RuntimeObjectBackend
deriving Repr, DecidableEq

structure MixedBackendObjectAccess where
  objectId : Nat
  backend : Option RuntimeObjectBackend
deriving Repr, DecidableEq

def lookupPublicObjectBackend?
  (objects : List PublicObjectBackend)
  (objectId : Nat) : Option RuntimeObjectBackend :=
  match objects.find? (fun object => object.objectId = objectId) with
  | some object => some object.backend
  | none => none

def RuntimeKernelSchedule.orderedMixedBackendSchedule
  (schedule : RuntimeKernelSchedule)
  (objects : List PublicObjectBackend) : List MixedBackendObjectAccess :=
  schedule.publicObjectSchedule.map (fun objectId =>
    { objectId := objectId
    , backend := lookupPublicObjectBackend? objects objectId
    })

theorem orderedMixedBackendSchedule_objectIds_eq_publicObjectSchedule
  (schedule : RuntimeKernelSchedule)
  (objects : List PublicObjectBackend) :
  (schedule.orderedMixedBackendSchedule objects).map
      MixedBackendObjectAccess.objectId =
    schedule.publicObjectSchedule := by
  unfold RuntimeKernelSchedule.orderedMixedBackendSchedule
  induction schedule.publicObjectSchedule with
  | nil => rfl
  | cons _ _ ih => simp [ih]

theorem orderedMixedBackendSchedule_eq_of_publicObjectSchedule_eq
  {lhs rhs : RuntimeKernelSchedule}
  {objects : List PublicObjectBackend}
  (hSchedule : lhs.publicObjectSchedule = rhs.publicObjectSchedule) :
  lhs.orderedMixedBackendSchedule objects =
    rhs.orderedMixedBackendSchedule objects := by
  simp [RuntimeKernelSchedule.orderedMixedBackendSchedule, hSchedule]

theorem runtimeKernelSchedule_orderedObjectSchedule_finalState_public
  {schedule : RuntimeKernelSchedule}
  {finalState : RuntimeKernelExecutionState}
  (hFinal : schedule.finalState? = some finalState) :
  finalState.publicObjectSchedule = schedule.publicObjectSchedule := by
  exact runtimeKernelSchedule_finalState_publicObjectSchedule hFinal

end UOToolchain
