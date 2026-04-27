import UOToolchain.SgxControllerTrace

/-! # SGX micro-observer model layer

This file defines the paper-facing normalized SGX micro-observer
simulator and the corresponding `normalizedObservedSGXMicroRelation`
used by the SGX projection chain.

* **Abstraction function:** `simulateNormalizedMicroTraceFromLeakage`
  (deterministic public projection of `SGXMicroLeakage` into a
  `NormalizedMicroTrace`).
* **Main theorem:** `normalizeMicroTrace_controllerMicroTraceOfShape`
  — every controller-shaped micro trace normalizes exactly to the
  simulator output. The `normalizedObservedSGXMicroRelation` SGX
  micro relation (used by `paperMain_*` in the projection layers) is
  defined here as a thin wrapper.

The legacy `SGXMicroConfig`/`SGXMicroSemantics` data structures and
helper predicates `sameSGXMicroPublicProjection`, `ExactSGXMicroUO`,
`sgxMicroLeakage` survive only to support `SgxMicroGame.lean`'s
`legacyComputationalSGXMicroUO` legacy demonstration.

The earlier alternative-relation infrastructure
(`budgetConsistentSGXMicroRelation`, `canonicalizedSGXMicroRelation`,
`canonicalizeMicroTrace`, `canonicalLeakageSimulator`,
`simulateMicroTraceFromLeakage`, `canonicalPageTrace`/`canonicalExitTrace`/
`canonicalSharedResourceTrace`, the unused `publicControllerMicroSemantics`
smoke-test `SGXMicroSemantics` instance, plus the six smoke-test
theorems showing it satisfies budget/canonicalized/normalized variants)
has been removed: it had no consumer in the paper-grade narrative
after the W7.1 SgxOramProjection canonicalization.
-/

namespace UOToolchain

structure SGXMicroPublicData where
  publicOutcome : SGXPublicOutcome
  modelTags : SGXModelTags
  controllerShape : SGXControllerShape
deriving Repr, DecidableEq

structure SGXMicroConfig where
  pubData : SGXMicroPublicData
  secretState : List String
  secretArgs : List String
deriving Repr, DecidableEq

abbrev SGXMicroSemantics := SGXMicroConfig → Distribution SGXMicroTrace

def sameSGXMicroPublicProjection (lhs rhs : SGXMicroConfig) : Prop :=
  lhs.pubData = rhs.pubData

def sgxMicroLeakage (cfg : SGXMicroConfig) : SGXMicroLeakage :=
  sgxMicroLeakageOfController
    cfg.pubData.publicOutcome
    cfg.pubData.modelTags
    cfg.pubData.controllerShape

structure NormalizedPageEvent where
  pageKind : String
  kind : PageEventKind
deriving Repr, DecidableEq

structure NormalizedMicroTrace where
  pageTrace : List NormalizedPageEvent
  exitPattern : List ExitEvent
  sharedResourcePattern : SharedResourceTrace
deriving Repr, DecidableEq

def normalizePageEvent (event : PageEvent) : NormalizedPageEvent :=
  { pageKind := event.pageKind
  , kind := event.kind
  }

def normalizePageTrace (pageTrace : List PageEvent) : List NormalizedPageEvent :=
  pageTrace.map normalizePageEvent

def normalizeMicroTrace (trace : SGXMicroTrace) : NormalizedMicroTrace :=
  { pageTrace := normalizePageTrace trace.pageTrace
  , exitPattern := trace.exitTrace
  , sharedResourcePattern := trace.sharedResourceTrace
  }

def normalizedPageEventOfIndex
  (pageKind : String)
  (index : Nat) : NormalizedPageEvent :=
  { pageKind := pageKind
  , kind := if index % 2 = 0 then PageEventKind.faultIn else PageEventKind.evictOut
  }

def normalizedPageTraceOfRegion (region : SGXControllerPageBudget) : List NormalizedPageEvent :=
  (List.range region.eventBudget).map (normalizedPageEventOfIndex region.pageKind)

def simulateNormalizedPageTraceFromLeakage (leakage : SGXMicroLeakage) : List NormalizedPageEvent :=
  concatLists (leakage.pageTraceRegions.map normalizedPageTraceOfRegion)

def simulateNormalizedMicroTraceFromLeakage (leakage : SGXMicroLeakage) : NormalizedMicroTrace :=
  { pageTrace := simulateNormalizedPageTraceFromLeakage leakage
  , exitPattern := leakage.normalizedExitPattern
  , sharedResourcePattern := leakage.sharedResourcePattern
  }

abbrev NormalizedSGXMicroSimulator := SGXMicroLeakage → Distribution NormalizedMicroTrace

def normalizedLeakageSimulator : NormalizedSGXMicroSimulator :=
  fun leakage => [simulateNormalizedMicroTraceFromLeakage leakage]

def NormalizedByLeakage
  (traces : Distribution SGXMicroTrace)
  (leakage : SGXMicroLeakage) : Prop :=
  ∀ trace, trace ∈ traces → normalizeMicroTrace trace = simulateNormalizedMicroTraceFromLeakage leakage

def normalizedObservedSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ leakage =>
    NormalizedByLeakage micro₁ leakage ∧
      NormalizedByLeakage micro₂ leakage

@[simp] theorem normalizePageTrace_controllerPageEventsOfRegion
  (region : SGXControllerPageBudget) :
  normalizePageTrace (controllerPageEventsOfRegion region) =
    normalizedPageTraceOfRegion region := by
  simp [normalizePageTrace, controllerPageEventsOfRegion, normalizedPageTraceOfRegion,
    normalizePageEvent, controllerPageEventOfIndex, normalizedPageEventOfIndex]

theorem normalizePageTrace_controllerPageTraceRegions
  (regions : List SGXControllerPageBudget) :
  normalizePageTrace (concatLists (regions.map controllerPageEventsOfRegion)) =
    concatLists (regions.map normalizedPageTraceOfRegion) := by
  induction regions with
  | nil =>
      simp [normalizePageTrace, concatLists]
  | cons region regions ih =>
      have hRegion :
          List.map normalizePageEvent (controllerPageEventsOfRegion region) =
            normalizedPageTraceOfRegion region := by
        simpa [normalizePageTrace] using normalizePageTrace_controllerPageEventsOfRegion region
      have hTail :
          List.map normalizePageEvent (concatLists (List.map controllerPageEventsOfRegion regions)) =
            concatLists (List.map normalizedPageTraceOfRegion regions) := by
        simpa [normalizePageTrace] using ih
      simp [concatLists, normalizePageTrace, List.map_append]
      rw [hRegion, hTail]

theorem normalizeMicroTrace_controllerMicroTraceOfShape
  (publicOutcome : SGXPublicOutcome)
  (modelTags : SGXModelTags)
  (shape : SGXControllerShape) :
  normalizeMicroTrace (controllerMicroTraceOfShape shape) =
    simulateNormalizedMicroTraceFromLeakage
      (sgxMicroLeakageOfController publicOutcome modelTags shape) := by
  simp [normalizeMicroTrace, simulateNormalizedMicroTraceFromLeakage,
    controllerMicroTraceOfShape, controllerExitTraceOfShape,
    controllerSharedResourceTraceOfShape, sgxMicroLeakageOfController]
  exact normalizePageTrace_controllerPageTraceRegions shape.pageTraceRegions

theorem sameSGXMicroPublicProjection_refl (cfg : SGXMicroConfig) :
    sameSGXMicroPublicProjection cfg cfg := rfl

theorem sameSGXMicroPublicProjection_symm {lhs rhs : SGXMicroConfig} :
    sameSGXMicroPublicProjection lhs rhs → sameSGXMicroPublicProjection rhs lhs := by
  intro h
  exact h.symm

theorem sameSGXMicroPublicProjection_trans {a b c : SGXMicroConfig} :
    sameSGXMicroPublicProjection a b →
    sameSGXMicroPublicProjection b c →
    sameSGXMicroPublicProjection a c := by
  intro hab hbc
  exact hab.trans hbc

theorem sgxMicroLeakage_eq_of_samePublicProjection
  {cfg₁ cfg₂ : SGXMicroConfig} :
  sameSGXMicroPublicProjection cfg₁ cfg₂ →
  sgxMicroLeakage cfg₁ = sgxMicroLeakage cfg₂ := by
  cases cfg₁
  cases cfg₂
  intro hPublic
  cases hPublic
  rfl

theorem normalizedByLeakage_of_eq
  {traces : Distribution SGXMicroTrace}
  {leakage₁ leakage₂ : SGXMicroLeakage} :
  leakage₁ = leakage₂ →
  NormalizedByLeakage traces leakage₁ →
  NormalizedByLeakage traces leakage₂ := by
  intro hEq hNormalized
  subst hEq
  exact hNormalized

theorem normalizedLeakageSimulator_exact
  (leakage : SGXMicroLeakage) :
  ∀ trace, trace ∈ normalizedLeakageSimulator leakage →
    trace = simulateNormalizedMicroTraceFromLeakage leakage := by
  intro trace hMem
  simp [normalizedLeakageSimulator] at hMem
  rcases hMem with rfl
  rfl

end UOToolchain
