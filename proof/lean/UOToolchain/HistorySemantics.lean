import UOToolchain.RuntimeRefinement
import UOToolchain.SgxRelation

namespace UOToolchain

/-!
# Adaptive history and ordered object-schedule surface

This module names the public transcript shape used when lifting the single-call
observer to adaptive call histories. It also makes the ordered logical object
schedule and final public store projection explicit public leakage components
for mixed exact/ORAM backends.
-/

structure HostCallRequest where
  entrypointId : String
  publicArgs : List String
deriving Repr, DecidableEq

/-- Public rollback behavior included in the paper-main hostile-host view. -/
structure PaperMainFinalPublicStateRollback where
  initialPublicStateDigest : String
  candidatePublicStateDigest : String
  committedPublicStateDigest : String
  publicDeltaDigest : String
  aborted : Bool
deriving Repr, DecidableEq

/-- Declared release functions from the admitted package manifest. -/
structure PaperMainDeclaredReleaseFunctions where
  functions : List String
deriving Repr, DecidableEq

/-- The complete paper-facing SGX observer.  The fields intentionally name all
host-visible components required by the direct theorem statement: public
outcome, boundary schedule, storage trace, micro trace, final public
state/rollback behavior, and declared release functions. -/
structure PaperMainViewSGX where
  publicOutcome : SGXPublicOutcome
  boundarySchedule : List BoundaryEvent
  storageTrace : SGXStorageTrace
  microTrace : SGXMicroTrace
  finalPublicStateRollback : PaperMainFinalPublicStateRollback
  releaseFunctions : PaperMainDeclaredReleaseFunctions
deriving Repr, DecidableEq

/-- Paper notation for the complete hostile-host SGX observer. -/
abbrev View_SGX := PaperMainViewSGX

def paperMainViewOfSGX
  (finalPublicStateRollback : PaperMainFinalPublicStateRollback)
  (releaseFunctions : PaperMainDeclaredReleaseFunctions)
  (view : SGXView) : View_SGX :=
  { publicOutcome := sgxPublicOutcome view
  , boundarySchedule := view.boundarySchedule
  , storageTrace := sgxStorageTrace view
  , microTrace := sgxMicroTrace view
  , finalPublicStateRollback := finalPublicStateRollback
  , releaseFunctions := releaseFunctions
  }

structure HostCallObservation where
  view : View_SGX
  orderedObjectSchedule : List Nat
  finalPublicState : List String
deriving Repr, DecidableEq

def HostCallObservation.publicOutcome
  (observation : HostCallObservation) : SGXPublicOutcome :=
  observation.view.publicOutcome

def HostCallObservation.boundarySchedule
  (observation : HostCallObservation) : List BoundaryEvent :=
  observation.view.boundarySchedule

def HostCallObservation.storageTrace
  (observation : HostCallObservation) : SGXStorageTrace :=
  observation.view.storageTrace

def HostCallObservation.microTrace
  (observation : HostCallObservation) : SGXMicroTrace :=
  observation.view.microTrace

def HostCallObservation.finalPublicStateRollback
  (observation : HostCallObservation) : PaperMainFinalPublicStateRollback :=
  observation.view.finalPublicStateRollback

def HostCallObservation.releaseFunctions
  (observation : HostCallObservation) : PaperMainDeclaredReleaseFunctions :=
  observation.view.releaseFunctions

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

def RuntimeHistory.finalPublicStates
  (history : RuntimeHistory) : List (List String) :=
  history.steps.map (fun step => step.observation.finalPublicState)

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

theorem historyStepsPublicEq_finalPublicStates_eq
  {lhs rhs : List HistoryStepWitness}
  (hEq : HistoryStepsPublicEq lhs rhs) :
  lhs.map (fun step => step.observation.finalPublicState) =
    rhs.map (fun step => step.observation.finalPublicState) := by
  induction lhs generalizing rhs with
  | nil =>
      cases rhs <;> simp [HistoryStepsPublicEq] at hEq ⊢
  | cons lhsHead lhsTail ih =>
      cases rhs with
      | nil => simp [HistoryStepsPublicEq] at hEq
      | cons rhsHead rhsTail =>
          rcases hEq with ⟨hHead, hTail⟩
          rcases hHead with ⟨_hRequest, hObservation⟩
          simp [hObservation, ih hTail]

theorem runtimeHistory_finalPublicStates_eq_of_stepwise_publicEq
  {lhs rhs : RuntimeHistory}
  (hEq : HistoryStepsPublicEq lhs.steps rhs.steps) :
  lhs.finalPublicStates = rhs.finalPublicStates := by
  exact historyStepsPublicEq_finalPublicStates_eq hEq

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

/-! ## Inductive adaptive-history theorem

The definitions below model the missing theorem boundary directly.  A host
strategy is public because it receives only the accumulated host transcript.
Each generated call also carries the public release frame for that call.  The
single-call theorem is used modulo that release frame and the current public
state; the induction then derives equality of the whole public history rather
than assuming stepwise equality up front.
-/

abbrev HostReleaseFrame := List String
abbrev HostReleaseHistory := List HostReleaseFrame

def HostReleaseFrame.fromDeclaredReleaseFunctions
  (declared : PaperMainDeclaredReleaseFunctions) : HostReleaseFrame :=
  declared.functions

def HostReleaseHistory.fromDeclaredReleaseFunctions
  (declared : List PaperMainDeclaredReleaseFunctions) : HostReleaseHistory :=
  declared.map HostReleaseFrame.fromDeclaredReleaseFunctions

theorem hostReleaseHistory_fromDeclaredReleaseFunctions_eq_of_declared_eq
  {lhs rhs : List PaperMainDeclaredReleaseFunctions}
  (hDeclared : lhs = rhs) :
  HostReleaseHistory.fromDeclaredReleaseFunctions lhs =
    HostReleaseHistory.fromDeclaredReleaseFunctions rhs := by
  rw [hDeclared]

abbrev AdaptiveSingleCallObservation :=
  List String → HostTranscript → HostReleaseFrame → HostCallRequest →
    HostCallObservation

abbrev AdaptiveCallAdmission :=
  List String → HostTranscript → HostReleaseFrame → HostCallRequest → Prop

def SingleCallUOTheoremModuloReleases
  (admitted : AdaptiveCallAdmission)
  (observe₁ observe₂ : AdaptiveSingleCallObservation) : Prop :=
  ∀ publicState transcript releaseFrame request,
    admitted publicState transcript releaseFrame request →
      observe₁ publicState transcript releaseFrame request =
        observe₂ publicState transcript releaseFrame request

def HistoryGeneratedByPublicStrategyFrom
  (strategy : AdaptiveHostStrategy)
  (admitted : AdaptiveCallAdmission)
  (observe : AdaptiveSingleCallObservation) :
  List String → HostTranscript → HostReleaseHistory →
    List HistoryStepWitness → Prop
  | _publicState, transcript, _releaseHistory, [] =>
      strategy transcript = none
  | _publicState, _transcript, [], _step :: _rest =>
      False
  | publicState, transcript, releaseFrame :: releaseHistory, step :: rest =>
      strategy transcript = some step.request ∧
        admitted publicState transcript releaseFrame step.request ∧
        step.observation =
          observe publicState transcript releaseFrame step.request ∧
        HistoryGeneratedByPublicStrategyFrom
          strategy
          admitted
          observe
          step.observation.finalPublicState
          (transcript ++ [step.observation])
          releaseHistory
          rest

def RuntimeHistory.GeneratedByPublicStrategy
  (history : RuntimeHistory)
  (strategy : AdaptiveHostStrategy)
  (admitted : AdaptiveCallAdmission)
  (observe : AdaptiveSingleCallObservation)
  (initialPublicState : List String)
  (releaseHistory : HostReleaseHistory) : Prop :=
  HistoryGeneratedByPublicStrategyFrom
    strategy
    admitted
    observe
    initialPublicState
    []
    releaseHistory
    history.steps

structure AdaptiveHistoryNoninterferenceConclusion
  (lhs rhs : RuntimeHistory) : Prop where
  stepwisePublicEq : HistoryStepsPublicEq lhs.steps rhs.steps
  publicTranscript : lhs.publicTranscript = rhs.publicTranscript
  orderedObjectSchedule :
    lhs.orderedObjectSchedule = rhs.orderedObjectSchedule
  finalPublicStates : lhs.finalPublicStates = rhs.finalPublicStates

theorem adaptiveHistory_stepsPublicEq_from_singleCall_aux
  {strategy : AdaptiveHostStrategy}
  {admitted : AdaptiveCallAdmission}
  {observe₁ observe₂ : AdaptiveSingleCallObservation}
  (hSingle :
    SingleCallUOTheoremModuloReleases admitted observe₁ observe₂) :
  ∀ {publicState₁ publicState₂ : List String}
    {transcript₁ transcript₂ : HostTranscript}
    {releaseHistory : HostReleaseHistory}
    {steps₁ steps₂ : List HistoryStepWitness},
    publicState₁ = publicState₂ →
    transcript₁ = transcript₂ →
    HistoryGeneratedByPublicStrategyFrom
      strategy
      admitted
      observe₁
      publicState₁
      transcript₁
      releaseHistory
      steps₁ →
    HistoryGeneratedByPublicStrategyFrom
      strategy
      admitted
      observe₂
      publicState₂
      transcript₂
      releaseHistory
      steps₂ →
    HistoryStepsPublicEq steps₁ steps₂ := by
  intro publicState₁ publicState₂ transcript₁ transcript₂ releaseHistory steps₁
  induction steps₁ generalizing publicState₁ publicState₂ transcript₁ transcript₂ releaseHistory with
  | nil =>
      intro steps₂ hState hTranscript hRun₁ hRun₂
      cases steps₂ with
      | nil =>
          simp [HistoryStepsPublicEq]
      | cons step₂ rest₂ =>
          cases releaseHistory with
          | nil =>
              simp [HistoryGeneratedByPublicStrategyFrom] at hRun₂
          | cons releaseFrame releaseTail =>
              simp [HistoryGeneratedByPublicStrategyFrom] at hRun₁ hRun₂
              rw [← hTranscript, hRun₁] at hRun₂
              cases hRun₂.1
  | cons step₁ rest₁ ih =>
      intro steps₂ hState hTranscript hRun₁ hRun₂
      cases steps₂ with
      | nil =>
          cases releaseHistory with
          | nil =>
              simp [HistoryGeneratedByPublicStrategyFrom] at hRun₁
          | cons releaseFrame releaseTail =>
              simp [HistoryGeneratedByPublicStrategyFrom] at hRun₁ hRun₂
              rw [hTranscript, hRun₂] at hRun₁
              cases hRun₁.1
      | cons step₂ rest₂ =>
          cases releaseHistory with
          | nil =>
              simp [HistoryGeneratedByPublicStrategyFrom] at hRun₁
          | cons releaseFrame releaseTail =>
              simp [HistoryGeneratedByPublicStrategyFrom] at hRun₁ hRun₂
              rcases hRun₁ with ⟨hStrategy₁, hAdmitted₁, hObserve₁, hRest₁⟩
              rcases hRun₂ with ⟨hStrategy₂, _hAdmitted₂, hObserve₂, hRest₂⟩
              subst hState
              subst hTranscript
              have hRequest : step₁.request = step₂.request := by
                rw [hStrategy₁] at hStrategy₂
                exact Option.some.inj hStrategy₂
              have hObservation : step₁.observation = step₂.observation := by
                calc
                  step₁.observation =
                      observe₁ publicState₁ transcript₁ releaseFrame step₁.request := hObserve₁
                  _ =
                      observe₂ publicState₁ transcript₁ releaseFrame step₁.request :=
                        hSingle
                          publicState₁
                          transcript₁
                          releaseFrame
                          step₁.request
                          hAdmitted₁
                  _ =
                      observe₂ publicState₁ transcript₁ releaseFrame step₂.request := by
                        rw [hRequest]
                  _ = step₂.observation := hObserve₂.symm
              constructor
              · exact ⟨hRequest, hObservation⟩
              · have hNextState :
                    step₁.observation.finalPublicState =
                      step₂.observation.finalPublicState :=
                  congrArg HostCallObservation.finalPublicState hObservation
                have hNextTranscript :
                    transcript₁ ++ [step₁.observation] =
                      transcript₁ ++ [step₂.observation] := by
                  rw [hObservation]
                exact ih hNextState hNextTranscript hRest₁ hRest₂

/-- Inductive adaptive-history noninterference.  A public strategy that chooses
the next request from the full hostile-host transcript, admitted calls at every
step, equal initial public state, equal release history generated from declared
release functions, and the single-call UO theorem modulo releases imply equal
full host transcripts plus the legacy public projections. -/
theorem adaptiveHistory_noninterference_from_singleCall
  {strategy : AdaptiveHostStrategy}
  {admitted : AdaptiveCallAdmission}
  {observe₁ observe₂ : AdaptiveSingleCallObservation}
  {initialPublicState₁ initialPublicState₂ : List String}
  {releaseHistory₁ releaseHistory₂ : HostReleaseHistory}
  {history₁ history₂ : RuntimeHistory}
  (hInitialPublicState :
    initialPublicState₁ = initialPublicState₂)
  (hReleaseHistory : releaseHistory₁ = releaseHistory₂)
  (hSingle :
    SingleCallUOTheoremModuloReleases admitted observe₁ observe₂)
  (hHistory₁ :
    history₁.GeneratedByPublicStrategy
      strategy
      admitted
      observe₁
      initialPublicState₁
      releaseHistory₁)
  (hHistory₂ :
    history₂.GeneratedByPublicStrategy
      strategy
      admitted
      observe₂
      initialPublicState₂
      releaseHistory₂) :
  AdaptiveHistoryNoninterferenceConclusion history₁ history₂ := by
  subst hReleaseHistory
  have hSteps :
      HistoryStepsPublicEq history₁.steps history₂.steps := by
    exact
      adaptiveHistory_stepsPublicEq_from_singleCall_aux
        hSingle
        hInitialPublicState
        rfl
        hHistory₁
        hHistory₂
  exact
    { stepwisePublicEq := hSteps
    , publicTranscript :=
        runtimeHistory_publicTranscript_eq_of_stepwise_publicEq hSteps
    , orderedObjectSchedule :=
        runtimeHistory_orderedObjectSchedule_eq_of_stepwise_publicEq hSteps
    , finalPublicStates :=
        runtimeHistory_finalPublicStates_eq_of_stepwise_publicEq hSteps
    }

def adaptiveHistorySampleOutcome
  (entrypointId : String)
  (publicArgs declassifies : List String)
  (terminationStatus : Bool) : SGXPublicOutcome :=
  { entrypointId := entrypointId
  , publicArgs := publicArgs
  , terminationStatus := terminationStatus
  , statusPolicy := "public"
  , outputShape := { returnPresent := false, returnLength := 0 }
  , returnPolicy := "forbidden"
  , returnPayload := none
  , encryptedReturnPayload := none
  , declassifies := declassifies
  , gasUsed := 0
  }

def adaptiveHistorySampleRequest₁ : HostCallRequest :=
  { entrypointId := "first", publicArgs := ["0"] }

def adaptiveHistorySampleRequest₂Ok : HostCallRequest :=
  { entrypointId := "second_ok", publicArgs := ["1"] }

def adaptiveHistorySampleRequest₂Abort : HostCallRequest :=
  { entrypointId := "second_abort", publicArgs := ["0"] }

def adaptiveHistorySampleObservation
  (terminationStatus : Bool)
  (request : HostCallRequest)
  (releaseFrame : HostReleaseFrame) : HostCallObservation :=
  { view :=
      { publicOutcome :=
          adaptiveHistorySampleOutcome
            request.entrypointId
            request.publicArgs
            releaseFrame
            terminationStatus
      , boundarySchedule := []
      , storageTrace := { persistentReads := [], persistentWrites := [] }
      , microTrace := { pageTrace := [], exitTrace := [], sharedResourceTrace := [] }
      , finalPublicStateRollback :=
          { initialPublicStateDigest := "initial"
          , candidatePublicStateDigest := request.entrypointId
          , committedPublicStateDigest := request.entrypointId
          , publicDeltaDigest := request.entrypointId
          , aborted := !terminationStatus
          }
      , releaseFunctions :=
          { functions := releaseFrame }
      }
  , orderedObjectSchedule :=
      if request.entrypointId = "first" then [1] else [2]
  , finalPublicState := [request.entrypointId]
  }

def adaptiveHistorySampleFirstObservation : HostCallObservation :=
  adaptiveHistorySampleObservation true adaptiveHistorySampleRequest₁ ["r0"]

def adaptiveHistorySampleStrategy : AdaptiveHostStrategy
  | [] => some adaptiveHistorySampleRequest₁
  | first :: [] =>
      if first.publicOutcome.terminationStatus then
        some adaptiveHistorySampleRequest₂Ok
      else
        some adaptiveHistorySampleRequest₂Abort
  | _ => none

theorem adaptiveHistorySampleStrategy_second_request_depends_on_first_observation :
  adaptiveHistorySampleStrategy [adaptiveHistorySampleFirstObservation] =
      some adaptiveHistorySampleRequest₂Ok ∧
    adaptiveHistorySampleStrategy
      [adaptiveHistorySampleObservation
        false
        adaptiveHistorySampleRequest₁
        ["r0"]] =
      some adaptiveHistorySampleRequest₂Abort := by
  simp
    [ adaptiveHistorySampleStrategy
    , adaptiveHistorySampleFirstObservation
    , adaptiveHistorySampleObservation
    , adaptiveHistorySampleOutcome
    , HostCallObservation.publicOutcome
    ]

def adaptiveHistorySampleAdmitted : AdaptiveCallAdmission :=
  fun _publicState _transcript _releaseFrame _request => True

def adaptiveHistorySampleObserve : AdaptiveSingleCallObservation :=
  fun _publicState transcript releaseFrame request =>
    match transcript with
    | [] => adaptiveHistorySampleObservation true request releaseFrame
    | _ :: [] => adaptiveHistorySampleObservation true request releaseFrame
    | _ => adaptiveHistorySampleObservation true request releaseFrame

def adaptiveHistorySampleReleaseHistory : HostReleaseHistory :=
  [["r0"], ["r1"]]

def adaptiveHistorySampleHistory : RuntimeHistory :=
  { steps :=
      [ { request := adaptiveHistorySampleRequest₁
        , observation :=
            adaptiveHistorySampleObservation
              true
              adaptiveHistorySampleRequest₁
              ["r0"]
        }
      , { request := adaptiveHistorySampleRequest₂Ok
        , observation :=
            adaptiveHistorySampleObservation
              true
              adaptiveHistorySampleRequest₂Ok
              ["r1"]
        }
      ]
  }

example :
  adaptiveHistorySampleHistory.GeneratedByPublicStrategy
    adaptiveHistorySampleStrategy
    adaptiveHistorySampleAdmitted
    adaptiveHistorySampleObserve
    []
    adaptiveHistorySampleReleaseHistory := by
  simp
    [ RuntimeHistory.GeneratedByPublicStrategy
    , HistoryGeneratedByPublicStrategyFrom
    , adaptiveHistorySampleHistory
    , adaptiveHistorySampleStrategy
    , adaptiveHistorySampleReleaseHistory
    , adaptiveHistorySampleAdmitted
    , adaptiveHistorySampleObserve
    , adaptiveHistorySampleObservation
    , adaptiveHistorySampleOutcome
    , HostCallObservation.publicOutcome
    ]

theorem adaptiveHistorySampleHistory_generated :
  adaptiveHistorySampleHistory.GeneratedByPublicStrategy
    adaptiveHistorySampleStrategy
    adaptiveHistorySampleAdmitted
    adaptiveHistorySampleObserve
    []
    adaptiveHistorySampleReleaseHistory := by
  simp
    [ RuntimeHistory.GeneratedByPublicStrategy
    , HistoryGeneratedByPublicStrategyFrom
    , adaptiveHistorySampleHistory
    , adaptiveHistorySampleStrategy
    , adaptiveHistorySampleReleaseHistory
    , adaptiveHistorySampleAdmitted
    , adaptiveHistorySampleObserve
    , adaptiveHistorySampleObservation
    , adaptiveHistorySampleOutcome
    , HostCallObservation.publicOutcome
    ]

example :
  AdaptiveHistoryNoninterferenceConclusion
    adaptiveHistorySampleHistory
    adaptiveHistorySampleHistory := by
  exact
    adaptiveHistory_noninterference_from_singleCall
      (strategy := adaptiveHistorySampleStrategy)
      (admitted := adaptiveHistorySampleAdmitted)
      (observe₁ := adaptiveHistorySampleObserve)
      (observe₂ := adaptiveHistorySampleObserve)
      (initialPublicState₁ := [])
      (initialPublicState₂ := [])
      (releaseHistory₁ := adaptiveHistorySampleReleaseHistory)
      (releaseHistory₂ := adaptiveHistorySampleReleaseHistory)
      (history₁ := adaptiveHistorySampleHistory)
      (history₂ := adaptiveHistorySampleHistory)
      rfl
      rfl
      (by
        intro publicState transcript releaseFrame request hAdmitted
        rfl)
      adaptiveHistorySampleHistory_generated
      adaptiveHistorySampleHistory_generated

end UOToolchain
