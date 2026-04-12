import UOToolchain.SgxMicroGame

namespace UOToolchain

structure RuntimeRefinementWitness where
  trace : Trace
  publicOutcome : SGXPublicOutcome
  boundarySchedule : List BoundaryEvent
  controllerShape : SGXControllerShape
  normalizedMicroTrace : NormalizedMicroTrace
deriving Repr, DecidableEq

def RuntimeRefinementWitness.storageTrace
  (witness : RuntimeRefinementWitness) : SGXStorageTrace :=
  { persistentReads := witness.trace.physicalReads
  , persistentWrites := witness.trace.physicalWrites
  }

def RuntimeRefinementWitness.microLeakage
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : SGXMicroLeakage :=
  sgxMicroLeakageOfController witness.publicOutcome modelTags witness.controllerShape

def RuntimeRefinementWitness.reconstructedMicroTrace
  (witness : RuntimeRefinementWitness) : SGXMicroTrace :=
  controllerMicroTraceOfShape witness.controllerShape

def RuntimeRefinementWitness.sgxView
  (witness : RuntimeRefinementWitness) : SGXView :=
  let microTrace := witness.reconstructedMicroTrace
  { entrypointId := witness.publicOutcome.entrypointId
  , publicArgs := witness.publicOutcome.publicArgs
  , boundarySchedule := witness.boundarySchedule
  , persistentReads := witness.trace.physicalReads
  , persistentWrites := witness.trace.physicalWrites
  , pageTrace := microTrace.pageTrace
  , exitTrace := microTrace.exitTrace
  , sharedResourceTrace := microTrace.sharedResourceTrace
  , terminationStatus := witness.publicOutcome.terminationStatus
  , outputShape := witness.publicOutcome.outputShape
  , gasUsed := witness.publicOutcome.gasUsed
  }

def RuntimeRefinementWitness.Valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.trace.gasUsed = witness.publicOutcome.gasUsed ∧
    witness.boundarySchedule.length = witness.controllerShape.boundaryEventBudget ∧
    witness.normalizedMicroTrace =
      simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags)

def RuntimeRefinementWitness.checkValid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  decide (witness.trace.gasUsed = witness.publicOutcome.gasUsed) &&
    decide (witness.boundarySchedule.length = witness.controllerShape.boundaryEventBudget) &&
    decide
      (witness.normalizedMicroTrace =
        simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags))

@[simp] theorem runtimeWitness_checkValid_eq_true_iff
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkValid modelTags = true ↔ witness.Valid modelTags := by
  simp [RuntimeRefinementWitness.checkValid, RuntimeRefinementWitness.Valid, and_assoc]

@[simp] theorem sgxPublicOutcome_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  sgxPublicOutcome witness.sgxView = witness.publicOutcome := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, sgxPublicOutcome,
    RuntimeRefinementWitness.reconstructedMicroTrace]

@[simp] theorem sgxBoundary_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  witness.sgxView.boundarySchedule = witness.boundarySchedule := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, RuntimeRefinementWitness.reconstructedMicroTrace]

@[simp] theorem sgxStorageTrace_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  sgxStorageTrace witness.sgxView = witness.storageTrace := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, RuntimeRefinementWitness.storageTrace,
    sgxStorageTrace, RuntimeRefinementWitness.reconstructedMicroTrace]

@[simp] theorem sgxMicroTrace_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  sgxMicroTrace witness.sgxView = witness.reconstructedMicroTrace := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, sgxMicroTrace,
    RuntimeRefinementWitness.reconstructedMicroTrace]

theorem reconstructedMicroTrace_normalizedByLeakage
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  normalizeMicroTrace witness.reconstructedMicroTrace =
    simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags) := by
  cases witness
  simp [RuntimeRefinementWitness.reconstructedMicroTrace,
    RuntimeRefinementWitness.microLeakage]
  exact normalizeMicroTrace_controllerMicroTraceOfShape _ _ _

theorem sgxView_normalizedMicro_eq_witness
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  normalizeMicroTrace (sgxMicroTrace witness.sgxView) = witness.normalizedMicroTrace := by
  rcases hValid with ⟨_hGas, _hBoundary, hNormalized⟩
  rw [sgxMicroTrace_runtimeWitness]
  rw [reconstructedMicroTrace_normalizedByLeakage]
  exact hNormalized.symm

theorem runtimeWitness_boundaryBudget_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.boundarySchedule.length = witness.controllerShape.boundaryEventBudget := by
  exact hValid.2.1

theorem runtimeWitness_publicOutcome_gas_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.trace.gasUsed = witness.publicOutcome.gasUsed := by
  exact hValid.1

theorem runtimeWitness_projects_to_paper_observer
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  sgxPublicOutcome witness.sgxView = witness.publicOutcome ∧
    witness.sgxView.boundarySchedule = witness.boundarySchedule ∧
    sgxStorageTrace witness.sgxView = witness.storageTrace ∧
    normalizeMicroTrace (sgxMicroTrace witness.sgxView) = witness.normalizedMicroTrace := by
  refine ⟨sgxPublicOutcome_runtimeWitness witness, sgxBoundary_runtimeWitness witness, ?_, ?_⟩
  · exact sgxStorageTrace_runtimeWitness witness
  · exact sgxView_normalizedMicro_eq_witness witness modelTags hValid

end UOToolchain
