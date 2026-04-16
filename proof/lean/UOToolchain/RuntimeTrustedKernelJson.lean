import Lean.Data.Json
import UOToolchain.RuntimeTrustedKernel
import UOToolchain.RuntimeRefinementJson

open Lean

namespace UOToolchain

structure ImportedRuntimeTrustedKernelBundle where
  runtime_seed : Option Nat
  controller_observer : ImportedRuntimeControllerObserverCertificate
  hidden_certificate : ImportedRuntimePathOramHiddenCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeTrustedKernelBundle.toRuntimeTrustedKernelBundle
  (bundle : ImportedRuntimeTrustedKernelBundle) : RuntimeTrustedKernelBundle :=
  { runtimeSeed := bundle.runtime_seed
  , controllerObserver :=
      bundle.controller_observer.toRuntimeControllerObserverCertificate
  , hiddenCertificate := bundle.hidden_certificate.toRuntimePathOramHiddenCertificate
  }

def ImportedRuntimeTrustedKernelBundle.Valid
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.toRuntimeTrustedKernelBundle.Valid modelTags

def ImportedRuntimeTrustedKernelBundle.checkValid
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.toRuntimeTrustedKernelBundle.checkValid modelTags

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

@[simp] theorem importedRuntimeTrustedKernelBundle_valid_iff
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.Valid modelTags ↔ bundle.toRuntimeTrustedKernelBundle.Valid modelTags := by
  rfl

@[simp] theorem importedRuntimeTrustedKernelBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeTrustedKernelBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeTrustedKernelBundle.checkValid ImportedRuntimeTrustedKernelBundle.Valid
  exact runtimeTrustedKernelBundle_checkValid_eq_true_iff
    bundle.toRuntimeTrustedKernelBundle
    modelTags

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
    hValid

def sampleImportedRuntimeTrustedKernelBundle : ImportedRuntimeTrustedKernelBundle :=
  { runtime_seed := sampleImportedRuntimeRefinementWitness.runtime_seed
  , controller_observer := sampleImportedRuntimeControllerObserverCertificate
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
