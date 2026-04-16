import UOToolchain.RuntimeRefinement

namespace UOToolchain

structure RuntimeTrustedKernelBundle where
  runtimeSeed : Option Nat
  controllerObserver : RuntimeControllerObserverCertificate
  hiddenCertificate : RuntimePathOramHiddenCertificate
deriving Repr, DecidableEq

def RuntimeTrustedKernelBundle.toRuntimeWitness
  (bundle : RuntimeTrustedKernelBundle) : RuntimeRefinementWitness :=
  { trace := bundle.hiddenCertificate.trace
  , runtimeSeed := bundle.runtimeSeed
  , publicOutcome := bundle.controllerObserver.publicOutcome
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

@[simp] theorem runtimeTrustedKernelBundle_checkValid_eq_true_iff
  (bundle : RuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold RuntimeTrustedKernelBundle.checkValid RuntimeTrustedKernelBundle.Valid
  exact runtimeWitness_checkValid_eq_true_iff bundle.toRuntimeWitness modelTags

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
      bundle.hiddenCertificate.Valid := by
  unfold RuntimeTrustedKernelBundle.Valid
  simpa [RuntimeTrustedKernelBundle.toRuntimeWitness] using
    runtimeWitness_valid_iff_subcertificates bundle.toRuntimeWitness modelTags

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
  exact (runtimeTrustedKernelBundle_valid_iff_subcertificates bundle modelTags).mp hValid |>.2.2.2

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

end UOToolchain
