import Lean.Data.Json
import UOToolchain.RuntimeTrustedKernel
import UOToolchain.RuntimeRefinementJson

open Lean

namespace UOToolchain

structure ImportedRuntimeTrustedKernelBundle where
  runtime_seed : Option Nat
  controller_observer : ImportedRuntimeControllerObserverCertificate
  kernel_witness : Option ImportedRuntimeKernelWitness
  hidden_certificate : ImportedRuntimePathOramHiddenCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeTrustedKernelBundle.toRuntimeTrustedKernelBundle
  (bundle : ImportedRuntimeTrustedKernelBundle) : RuntimeTrustedKernelBundle :=
  { runtimeSeed := bundle.runtime_seed
  , controllerObserver :=
      bundle.controller_observer.toRuntimeControllerObserverCertificate
  , kernelWitness := bundle.kernel_witness.map
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness
  , hiddenCertificate := bundle.hidden_certificate.toRuntimePathOramHiddenCertificate
  }

def ImportedRuntimeTrustedKernelBundle.kernelWitnessValid
  (bundle : ImportedRuntimeTrustedKernelBundle) : Prop :=
  match bundle.kernel_witness with
  | none => True
  | some kernelWitness =>
      kernelWitness.Valid bundle.controller_observer.public_outcome.entrypoint_id

def ImportedRuntimeTrustedKernelBundle.checkKernelWitness
  (bundle : ImportedRuntimeTrustedKernelBundle) : Bool :=
  match bundle.kernel_witness with
  | none => true
  | some kernelWitness =>
      kernelWitness.checkValid bundle.controller_observer.public_outcome.entrypoint_id

def ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid
  (bundle : ImportedRuntimeTrustedKernelBundle) : Prop :=
  match bundle.kernel_witness with
  | none => False
  | some kernelWitness =>
      kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id

def ImportedRuntimeTrustedKernelBundle.checkProofGradeKernelWitness
  (bundle : ImportedRuntimeTrustedKernelBundle) : Bool :=
  match bundle.kernel_witness with
  | none => false
  | some kernelWitness =>
      kernelWitness.checkProofGrade bundle.controller_observer.public_outcome.entrypoint_id

def ImportedRuntimeTrustedKernelBundle.Valid
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.toRuntimeTrustedKernelBundle.Valid modelTags ∧ bundle.kernelWitnessValid

def ImportedRuntimeTrustedKernelBundle.checkValid
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.toRuntimeTrustedKernelBundle.checkValid modelTags &&
    bundle.checkKernelWitness

def ImportedRuntimeTrustedKernelBundle.ProofGradeValid
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.toRuntimeTrustedKernelBundle.Valid modelTags ∧ bundle.proofGradeKernelWitnessValid

def ImportedRuntimeTrustedKernelBundle.checkProofGrade
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.toRuntimeTrustedKernelBundle.checkValid modelTags &&
    bundle.checkProofGradeKernelWitness

def parseImportedRuntimeTrustedKernelBundle
  (input : String) : Except String ImportedRuntimeTrustedKernelBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeTrustedKernelBundle
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeTrustedKernelBundle := do
  let bundle ← parseImportedRuntimeTrustedKernelBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw "imported runtime trusted kernel bundle does not satisfy Lean validity checks"

def parseAndCheckImportedProofGradeRuntimeTrustedKernelBundle
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeTrustedKernelBundle := do
  let bundle ← parseImportedRuntimeTrustedKernelBundle input
  if bundle.checkProofGrade modelTags then
    pure bundle
  else
    throw "imported proof-grade runtime trusted kernel bundle does not satisfy Lean validity checks"

def loadImportedRuntimeTrustedKernelBundle
  (path : System.FilePath) : IO ImportedRuntimeTrustedKernelBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeTrustedKernelBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime trusted kernel bundle: {err}"

def loadAndCheckImportedRuntimeTrustedKernelBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeTrustedKernelBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeTrustedKernelBundle input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to validate runtime trusted kernel bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeTrustedKernelBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeTrustedKernelBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeTrustedKernelBundle input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime trusted kernel bundle: {err}"

@[simp] theorem importedRuntimeTrustedKernelBundle_checkKernelWitness_eq_true_iff
  (bundle : ImportedRuntimeTrustedKernelBundle) :
  bundle.checkKernelWitness = true ↔ bundle.kernelWitnessValid := by
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.checkKernelWitness,
        ImportedRuntimeTrustedKernelBundle.kernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [ImportedRuntimeTrustedKernelBundle.checkKernelWitness,
        ImportedRuntimeTrustedKernelBundle.kernelWitnessValid, hKernel,
        importedRuntimeKernelWitness_checkValid_eq_true_iff]

@[simp] theorem importedRuntimeTrustedKernelBundle_checkProofGradeKernelWitness_eq_true_iff
  (bundle : ImportedRuntimeTrustedKernelBundle) :
  bundle.checkProofGradeKernelWitness = true ↔ bundle.proofGradeKernelWitnessValid := by
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.checkProofGradeKernelWitness,
        ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [ImportedRuntimeTrustedKernelBundle.checkProofGradeKernelWitness,
        ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel,
        importedRuntimeKernelWitness_checkProofGrade_eq_true_iff]

@[simp] theorem importedRuntimeTrustedKernelBundle_valid_iff
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.Valid modelTags ↔
    bundle.toRuntimeTrustedKernelBundle.Valid modelTags ∧ bundle.kernelWitnessValid := by
  rfl

@[simp] theorem importedRuntimeTrustedKernelBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeTrustedKernelBundle.checkValid ImportedRuntimeTrustedKernelBundle.Valid
  simp [runtimeTrustedKernelBundle_checkValid_eq_true_iff,
    importedRuntimeTrustedKernelBundle_checkKernelWitness_eq_true_iff]

@[simp] theorem importedRuntimeTrustedKernelBundle_checkProofGrade_eq_true_iff
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.checkProofGrade modelTags = true ↔ bundle.ProofGradeValid modelTags := by
  unfold ImportedRuntimeTrustedKernelBundle.checkProofGrade
    ImportedRuntimeTrustedKernelBundle.ProofGradeValid
  simp [runtimeTrustedKernelBundle_checkValid_eq_true_iff,
    importedRuntimeTrustedKernelBundle_checkProofGradeKernelWitness_eq_true_iff]

theorem importedRuntimeTrustedKernelBundle_proofGradeKernelSchedule_exact
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSteps,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps = some expectedKernelSteps ∧
      kernelWitness.kernel_steps = expectedKernelSteps := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeKernelSchedule_exact hProofGrade with
        ⟨expectedKernelSteps, hExpectedSteps, hKernelSteps⟩
      exact ⟨kernelWitness, expectedKernelSteps, rfl, hExpectedSteps, hKernelSteps⟩

theorem importedRuntimeTrustedKernelBundle_proofGradePublicObjectUniverse_exact
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedPublicObjectIds,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_public_object_ids = some expectedPublicObjectIds ∧
      kernelWitness.public_object_ids = expectedPublicObjectIds := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradePublicObjectUniverse_exact hProofGrade with
        ⟨expectedPublicObjectIds, hExpectedPublicObjectIds, hPublicObjectIds⟩
      exact
        ⟨kernelWitness, expectedPublicObjectIds, rfl, hExpectedPublicObjectIds,
          hPublicObjectIds⟩

theorem importedRuntimeTrustedKernelBundle_proofGradeKernelResourceState_exact
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.toRuntimeKernelWitness.replayedResourceState? =
        some kernelWitness.claimedResourceState := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      exact ⟨kernelWitness, rfl,
        importedRuntimeKernelWitness_proofGradeResourceState_exact hProofGrade⟩

theorem importedRuntimeTrustedKernelBundle_proofGradeKernelScheduleObject_exact
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeKernelScheduleObject_exact hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hKernelSchedule⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hKernelSchedule⟩

theorem importedRuntimeTrustedKernelBundle_proofGradeKernelScheduleObject_completes
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_completes hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hFinished⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hFinished⟩

theorem importedRuntimeTrustedKernelBundle_proofGradeKernelScheduleObject_publicObjects_exact
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.publicObjectSchedule = expectedKernelSchedule.publicObjectSchedule := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_publicObjects_exact
          hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hObjects⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hObjects⟩

theorem importedRuntimeTrustedKernelBundle_proofGradeKernelScheduleObject_finalState_exact
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    bundle.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  have hKernelValid : bundle.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeTrustedKernelBundle.ProofGradeValid at hValid
    exact hValid.2
  cases hKernel : bundle.kernel_witness with
  | none =>
      simp [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid bundle.controller_observer.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeTrustedKernelBundle.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact
          hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hFinalExact⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hFinalExact⟩

theorem importedRuntimeTrustedKernelBundle_projects_to_paper_observer
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  sgxPublicOutcome bundle.toRuntimeTrustedKernelBundle.toRuntimeWitness.sgxView =
      bundle.toRuntimeTrustedKernelBundle.controllerObserver.publicOutcome ∧
    bundle.toRuntimeTrustedKernelBundle.toRuntimeWitness.sgxView.boundarySchedule =
      bundle.toRuntimeTrustedKernelBundle.controllerObserver.boundarySchedule ∧
    sgxStorageTrace bundle.toRuntimeTrustedKernelBundle.toRuntimeWitness.sgxView =
      bundle.toRuntimeTrustedKernelBundle.toRuntimeWitness.storageTrace ∧
    normalizeMicroTrace
        (sgxMicroTrace bundle.toRuntimeTrustedKernelBundle.toRuntimeWitness.sgxView) =
      bundle.toRuntimeTrustedKernelBundle.controllerObserver.normalizedMicroTrace := by
  exact runtimeTrustedKernelBundle_projects_to_paper_observer
    bundle.toRuntimeTrustedKernelBundle
    modelTags
    hValid.1

def sampleImportedRuntimeTrustedKernelBundle : ImportedRuntimeTrustedKernelBundle :=
  { runtime_seed := sampleImportedRuntimeRefinementWitness.runtime_seed
  , controller_observer := sampleImportedRuntimeControllerObserverCertificate
  , kernel_witness := sampleImportedRuntimeRefinementWitness.kernel_witness
  , hidden_certificate := sampleImportedRuntimePathOramHiddenCertificate
  }

def sampleImportedRuntimeTrustedKernelBundleRoundtrip : Bool :=
  match
      parseImportedRuntimeTrustedKernelBundle
        (Json.compress (toJson sampleImportedRuntimeTrustedKernelBundle))
    with
    | .ok bundle => decide (bundle = sampleImportedRuntimeTrustedKernelBundle)
    | .error _ => false

example : sampleImportedRuntimeTrustedKernelBundleRoundtrip = true := by
  native_decide

end UOToolchain
