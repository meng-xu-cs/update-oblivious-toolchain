import UOToolchain.ConfidentialKernelDsl
import UOToolchain.RuntimeRefinement

namespace UOToolchain

structure RuntimeTrustedKernelBundle where
  runtimeSeed : Option Nat
  controllerObserver : RuntimeControllerObserverCertificate
  kernelWitness : Option RuntimeKernelWitness
  hiddenCertificate : RuntimePathOramHiddenCertificate
deriving Repr, DecidableEq

def RuntimeTrustedKernelBundle.toRuntimeWitness
  (bundle : RuntimeTrustedKernelBundle) : RuntimeRefinementWitness :=
  { trace := bundle.hiddenCertificate.trace
  , runtimeSeed := bundle.runtimeSeed
  , publicOutcome := bundle.controllerObserver.publicOutcome
  , kernelWitness := bundle.kernelWitness
  , runtimeKernelRefinementWitness := none
  , boundarySchedule := bundle.controllerObserver.boundarySchedule
  , controllerShape := bundle.controllerObserver.controllerShape
  , normalizedMicroTrace := bundle.controllerObserver.normalizedMicroTrace
  , controllerCertificate := bundle.controllerObserver.controllerCertificate
  , oramObjects := bundle.hiddenCertificate.oramObjects
  , oramLeafPublicScaffold := bundle.hiddenCertificate.oramLeafPublicScaffold
  , oramLeafSchedule := bundle.hiddenCertificate.oramLeafSchedule
  , oramPositionMapBefore := bundle.hiddenCertificate.oramPositionMapBefore
  , oramPositionMapAfter := bundle.hiddenCertificate.oramPositionMapAfter
  , oramLeafStateTransitions := bundle.hiddenCertificate.oramLeafStateTransitions
  }

def RuntimeTrustedKernelBundle.Valid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.toRuntimeWitness.Valid modelTags

def RuntimeTrustedKernelBundle.checkValid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.toRuntimeWitness.checkValid modelTags

def RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid
  (bundle : RuntimeTrustedKernelBundle) : Prop :=
  match bundle.kernelWitness with
  | none => False
  | some kernelWitness =>
      kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId

def RuntimeTrustedKernelBundle.checkProofGradeKernelWitness
  (bundle : RuntimeTrustedKernelBundle) : Bool :=
  match bundle.kernelWitness with
  | none => false
  | some kernelWitness =>
      kernelWitness.checkProofGradeForEntrypoint
        bundle.controllerObserver.publicOutcome.entrypointId

def RuntimeTrustedKernelBundle.ProofGradeValid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.Valid modelTags ∧ bundle.proofGradeKernelWitnessValid

def RuntimeTrustedKernelBundle.checkProofGrade
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.checkValid modelTags &&
    bundle.checkProofGradeKernelWitness

@[simp] theorem runtimeTrustedKernelBundle_checkValid_eq_true_iff
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold RuntimeTrustedKernelBundle.checkValid RuntimeTrustedKernelBundle.Valid
  exact runtimeWitness_checkValid_eq_true_iff bundle.toRuntimeWitness modelTags

@[simp] theorem runtimeTrustedKernelBundle_checkProofGradeKernelWitness_eq_true_iff
  (bundle : RuntimeTrustedKernelBundle) :
  bundle.checkProofGradeKernelWitness = true ↔
    bundle.proofGradeKernelWitnessValid := by
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.checkProofGradeKernelWitness,
        RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [RuntimeTrustedKernelBundle.checkProofGradeKernelWitness,
        RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel,
        runtimeKernelWitness_checkProofGradeForEntrypoint_eq_true_iff]

@[simp] theorem runtimeTrustedKernelBundle_checkProofGrade_eq_true_iff
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.checkProofGrade modelTags = true ↔ bundle.ProofGradeValid modelTags := by
  simp [RuntimeTrustedKernelBundle.checkProofGrade,
    RuntimeTrustedKernelBundle.ProofGradeValid]

@[simp] theorem runtimeTrustedKernelBundle_controllerObserver_exact
  (bundle : RuntimeTrustedKernelBundle) :
  bundle.toRuntimeWitness.controllerObserverCertificate = bundle.controllerObserver := by
  cases bundle
  rfl

@[simp] theorem runtimeTrustedKernelBundle_hiddenCertificate_exact
  (bundle : RuntimeTrustedKernelBundle) :
  bundle.toRuntimeWitness.pathOramHiddenCertificate = bundle.hiddenCertificate := by
  cases bundle
  rfl

theorem runtimeTrustedKernelBundle_valid_iff_subcertificates
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.Valid modelTags ↔
    bundle.hiddenCertificate.trace.gasUsed =
      bundle.controllerObserver.publicOutcome.gasUsed ∧
      reconstructObservedOramAccessesFromLogicalTrace
          bundle.hiddenCertificate.trace.logicalAccesses
          bundle.hiddenCertificate.oramObjects =
        some bundle.controllerObserver.controllerCertificate.observedOramAccesses ∧
      bundle.controllerObserver.Valid modelTags ∧
      bundle.hiddenCertificate.Valid ∧
      (match bundle.kernelWitness with
      | none => True
      | some kernelWitness =>
          kernelWitness.ValidForEntrypoint
            bundle.controllerObserver.publicOutcome.entrypointId) := by
  unfold RuntimeTrustedKernelBundle.Valid
  simpa [RuntimeTrustedKernelBundle.toRuntimeWitness,
    RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid] using
    runtimeWitness_valid_iff_subcertificates bundle.toRuntimeWitness modelTags

theorem runtimeTrustedKernelBundle_proofGradeValid_iff_subcertificates
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.ProofGradeValid modelTags ↔
    bundle.hiddenCertificate.trace.gasUsed =
      bundle.controllerObserver.publicOutcome.gasUsed ∧
      reconstructObservedOramAccessesFromLogicalTrace
          bundle.hiddenCertificate.trace.logicalAccesses
          bundle.hiddenCertificate.oramObjects =
        some bundle.controllerObserver.controllerCertificate.observedOramAccesses ∧
      bundle.controllerObserver.Valid modelTags ∧
      bundle.hiddenCertificate.Valid ∧
      bundle.proofGradeKernelWitnessValid := by
  unfold RuntimeTrustedKernelBundle.ProofGradeValid
  rw [runtimeTrustedKernelBundle_valid_iff_subcertificates]
  constructor
  · intro hValid
    exact ⟨hValid.1.1, hValid.1.2.1, hValid.1.2.2.1, hValid.1.2.2.2.1, hValid.2⟩
  · intro hValid
    have hKernelValid :
        match bundle.kernelWitness with
        | none => True
        | some kernelWitness =>
            kernelWitness.ValidForEntrypoint
              bundle.controllerObserver.publicOutcome.entrypointId := by
      cases hKernel : bundle.kernelWitness with
      | none =>
          simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hValid
      | some kernelWitness =>
          have hProofGrade :
              kernelWitness.ProofGradeValid
                bundle.controllerObserver.publicOutcome.entrypointId := by
            simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
              hValid.2.2.2.2
          exact hProofGrade.1
    exact ⟨⟨hValid.1, hValid.2.1, hValid.2.2.1, hValid.2.2.2.1, hKernelValid⟩,
      hValid.2.2.2.2⟩

theorem runtimeTrustedKernelBundle_controllerObserver_valid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.controllerObserver.Valid modelTags := by
  exact (runtimeTrustedKernelBundle_valid_iff_subcertificates bundle modelTags).mp hValid |>.2.2.1

theorem runtimeTrustedKernelBundle_hiddenCertificate_valid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.hiddenCertificate.Valid := by
  exact (runtimeTrustedKernelBundle_valid_iff_subcertificates bundle modelTags).mp hValid |>.2.2.2.1

theorem runtimeTrustedKernelBundle_kernelWitness_valid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  match bundle.kernelWitness with
  | none => True
  | some kernelWitness =>
      kernelWitness.ValidForEntrypoint
        bundle.controllerObserver.publicOutcome.entrypointId := by
  exact (runtimeTrustedKernelBundle_valid_iff_subcertificates bundle modelTags).mp hValid |>.2.2.2.2

theorem runtimeTrustedKernelBundle_proofGradeKernelWitness_valid
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  bundle.proofGradeKernelWitnessValid := by
  exact
    (runtimeTrustedKernelBundle_proofGradeValid_iff_subcertificates bundle modelTags).mp hValid
      |>.2.2.2.2

theorem runtimeTrustedKernelBundle_proofGradeKernelSchedule_exact
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSteps,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps = some expectedKernelSteps ∧
      kernelWitness.kernelSteps = expectedKernelSteps := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases runtimeKernelWitness_proofGradeKernelSchedule_exact hProofGrade with
        ⟨expectedKernelSteps, hExpectedSteps, hKernelSteps⟩
      exact ⟨kernelWitness, expectedKernelSteps, rfl, hExpectedSteps, hKernelSteps⟩

theorem runtimeTrustedKernelBundle_proofGradePublicObjectUniverse_exact
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedPublicObjectIds,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedPublicObjectIds = some expectedPublicObjectIds ∧
      kernelWitness.publicObjectIds = expectedPublicObjectIds := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases runtimeKernelWitness_proofGradePublicObjectUniverse_exact hProofGrade with
        ⟨expectedPublicObjectIds, hExpectedPublicObjectIds, hPublicObjectIds⟩
      exact
        ⟨kernelWitness, expectedPublicObjectIds, rfl, hExpectedPublicObjectIds,
          hPublicObjectIds⟩

theorem runtimeTrustedKernelBundle_proofGradeKernelResourceState_exact
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.replayedResourceState? = some kernelWitness.claimedResourceState := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      exact ⟨kernelWitness, rfl, runtimeKernelWitness_proofGradeResourceState_exact hProofGrade⟩

theorem runtimeTrustedKernelBundle_proofGradeKernelScheduleObject_exact
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases runtimeKernelWitness_proofGradeKernelScheduleObject_exact hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hKernelSchedule⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hKernelSchedule⟩

theorem runtimeTrustedKernelBundle_proofGradeKernelScheduleObject_completes
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_completes hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hFinished⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hFinished⟩

theorem runtimeTrustedKernelBundle_proofGradeKernelScheduleObject_publicObjects_exact
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? = some finalState ∧
      finalState.publicObjectSchedule = expectedKernelSchedule.publicObjectSchedule := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_publicObjects_exact hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hObjects⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hObjects⟩

theorem runtimeTrustedKernelBundle_proofGradeKernelScheduleObject_finalState_exact
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    bundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid :=
    runtimeTrustedKernelBundle_proofGradeKernelWitness_valid bundle modelTags hValid
  cases hKernel : bundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controllerObserver.publicOutcome.entrypointId := by
        simpa [RuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hFinalExact⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hFinalExact⟩

theorem runtimeTrustedKernelBundle_projects_to_paper_observer
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  sgxPublicOutcome bundle.toRuntimeWitness.sgxView =
      bundle.controllerObserver.publicOutcome ∧
    bundle.toRuntimeWitness.sgxView.boundarySchedule =
      bundle.controllerObserver.boundarySchedule ∧
    sgxStorageTrace bundle.toRuntimeWitness.sgxView =
      bundle.toRuntimeWitness.storageTrace ∧
    normalizeMicroTrace (sgxMicroTrace bundle.toRuntimeWitness.sgxView) =
      bundle.controllerObserver.normalizedMicroTrace := by
  simpa [RuntimeTrustedKernelBundle.toRuntimeWitness] using
    runtimeWitness_projects_to_paper_observer bundle.toRuntimeWitness modelTags hValid

/--
Proof-grade trusted-kernel theorem surface strengthened with the admitted slot
DSL object. The trusted-kernel certificate path still exports the direct
controller/hidden certificates, but the proof-grade interface now also fixes
the exact confidential slot program that is supposed to explain the kernel
schedule.
-/
structure RuntimeTrustedKernelSlotBundle where
  trustedKernelBundle : RuntimeTrustedKernelBundle
  confidentialSlotProgram : ConfidentialKernelSlotProgram
  opcodeTrace : List String

def RuntimeTrustedKernelSlotBundle.kernelSlotBundle?
  (bundle : RuntimeTrustedKernelSlotBundle) : Option RuntimeKernelSlotDslBundle :=
  bundle.trustedKernelBundle.kernelWitness.map fun kernelWitness =>
    { kernelWitness := kernelWitness
    , confidentialProgram := bundle.confidentialSlotProgram
    }

def RuntimeTrustedKernelSlotBundle.Valid
  (bundle : RuntimeTrustedKernelSlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.trustedKernelBundle.ProofGradeValid modelTags ∧
    bundle.opcodeTrace = bundle.confidentialSlotProgram.statementTraceNames ∧
    match bundle.kernelSlotBundle? with
    | none => False
    | some slotBundle => slotBundle.Valid

theorem runtimeTrustedKernelSlotBundle_proofGradeTrustedKernel
  (bundle : RuntimeTrustedKernelSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.trustedKernelBundle.ProofGradeValid modelTags := by
  exact hValid.1

theorem runtimeTrustedKernelSlotBundle_schedule_exact
  (bundle : RuntimeTrustedKernelSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness,
    bundle.trustedKernelBundle.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps =
        some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps =
        bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  cases hKernel : bundle.trustedKernelBundle.kernelWitness with
  | none =>
      simp [RuntimeTrustedKernelSlotBundle.Valid,
        RuntimeTrustedKernelSlotBundle.kernelSlotBundle?, hKernel] at hValid
  | some kernelWitness =>
      have hSlot :
          RuntimeKernelSlotDslBundle.Valid
            { kernelWitness := kernelWitness
            , confidentialProgram := bundle.confidentialSlotProgram
            } := by
        simpa [RuntimeTrustedKernelSlotBundle.Valid,
          RuntimeTrustedKernelSlotBundle.kernelSlotBundle?, hKernel] using hValid.2.2
      exact ⟨kernelWitness, rfl, hSlot.2.2.1, hSlot.2.2.2⟩

theorem runtimeTrustedKernelSlotBundle_controllerObserver_valid
  (bundle : RuntimeTrustedKernelSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.trustedKernelBundle.controllerObserver.Valid modelTags := by
  exact runtimeTrustedKernelBundle_controllerObserver_valid
    bundle.trustedKernelBundle modelTags hValid.1.1

theorem runtimeTrustedKernelSlotBundle_hiddenCertificate_valid
  (bundle : RuntimeTrustedKernelSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.trustedKernelBundle.hiddenCertificate.Valid := by
  exact runtimeTrustedKernelBundle_hiddenCertificate_valid
    bundle.trustedKernelBundle modelTags hValid.1.1

end UOToolchain
