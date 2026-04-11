import UOToolchain.SgxControllerTrace

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

def ExactSGXMicroUO (run : SGXMicroSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameSGXMicroPublicProjection cfg₁ cfg₂ →
    run cfg₁ = run cfg₂

def sgxMicroLeakage (cfg : SGXMicroConfig) : SGXMicroLeakage :=
  sgxMicroLeakageOfController
    cfg.pubData.publicOutcome
    cfg.pubData.modelTags
    cfg.pubData.controllerShape

axiom sgxMicroLocalTheorem
  (micro₁ micro₂ : Distribution SGXMicroTrace)
  (leakage : SGXMicroLeakage) :
  Prop

def ComputationalSGXMicroUO (run : SGXMicroSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameSGXMicroPublicProjection cfg₁ cfg₂ →
    sgxMicroLocalTheorem (run cfg₁) (run cfg₂) (sgxMicroLeakage cfg₁)

def publicControllerMicroSemantics : SGXMicroSemantics :=
  fun cfg => [controllerMicroTraceOfShape cfg.pubData.controllerShape]

def computationalSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ leakage => sgxMicroLocalTheorem micro₁ micro₂ leakage

def budgetConsistentSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ leakage =>
    MicroDistributionConsistentWithLeakage micro₁ leakage ∧
      MicroDistributionConsistentWithLeakage micro₂ leakage

def canonicalPageTrace (budget : Nat) : List PageEvent :=
  (List.range budget).map (controllerPageEventOfIndex "simulated")

@[simp] theorem canonicalPageTrace_length (budget : Nat) :
    (canonicalPageTrace budget).length = budget := by
  simp [canonicalPageTrace]

def canonicalExitTrace (budget : Nat) : List ExitEvent :=
  (List.range budget).map (controllerExitEventOfIndex budget)

@[simp] theorem canonicalExitTrace_length (budget : Nat) :
    (canonicalExitTrace budget).length = budget := by
  simp [canonicalExitTrace]

def canonicalSharedResourceTrace (budget : Nat) : SharedResourceTrace :=
  List.replicate budget "shared_resource_tick"

@[simp] theorem canonicalSharedResourceTrace_length (budget : Nat) :
    (canonicalSharedResourceTrace budget).length = budget := by
  simp [canonicalSharedResourceTrace]

def simulateMicroTraceFromLeakage (leakage : SGXMicroLeakage) : SGXMicroTrace :=
  { pageTrace := canonicalPageTrace leakage.pageTraceBudget
  , exitTrace := canonicalExitTrace leakage.exitTraceBudget
  , sharedResourceTrace := canonicalSharedResourceTrace leakage.sharedResourceBudget
  }

abbrev SGXMicroSimulator := SGXMicroLeakage → Distribution SGXMicroTrace

def canonicalLeakageSimulator : SGXMicroSimulator :=
  fun leakage => [simulateMicroTraceFromLeakage leakage]

def canonicalizeMicroTrace (trace : SGXMicroTrace) : SGXMicroTrace :=
  { pageTrace := canonicalPageTrace trace.pageTrace.length
  , exitTrace := canonicalExitTrace trace.exitTrace.length
  , sharedResourceTrace := canonicalSharedResourceTrace trace.sharedResourceTrace.length
  }

def CanonicalizedByLeakage
  (traces : Distribution SGXMicroTrace)
  (leakage : SGXMicroLeakage) : Prop :=
  ∀ trace, trace ∈ traces → canonicalizeMicroTrace trace = simulateMicroTraceFromLeakage leakage

def canonicalizedSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ leakage =>
    CanonicalizedByLeakage micro₁ leakage ∧
      CanonicalizedByLeakage micro₂ leakage

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

theorem sgxMicroLocalTheorem_uses_public_leakage
  (run : SGXMicroSemantics)
  (hLocal :
    ∀ cfg₁ cfg₂,
      sameSGXMicroPublicProjection cfg₁ cfg₂ →
      sgxMicroLocalTheorem (run cfg₁) (run cfg₂) (sgxMicroLeakage cfg₁)) :
  ComputationalSGXMicroUO run := by
  intro cfg₁ cfg₂ hPublic
  exact hLocal cfg₁ cfg₂ hPublic

theorem publicControllerMicroSemantics_exact :
  ExactSGXMicroUO publicControllerMicroSemantics := by
  intro cfg₁ cfg₂ hPublic
  cases cfg₁
  cases cfg₂
  cases hPublic
  rfl

theorem publicControllerMicroSemantics_consistent
  (cfg : SGXMicroConfig) :
  MicroDistributionConsistentWithLeakage
    (publicControllerMicroSemantics cfg)
    (sgxMicroLeakage cfg) := by
  intro trace hMem
  simp [publicControllerMicroSemantics] at hMem
  rcases hMem with rfl
  exact controllerMicroTraceOfShape_consistentWithLeakage
    cfg.pubData.publicOutcome
    cfg.pubData.modelTags
    cfg.pubData.controllerShape

theorem canonicalizeMicroTrace_eq_simulate_of_consistent
  {trace : SGXMicroTrace}
  {leakage : SGXMicroLeakage} :
  MicroTraceConsistentWithLeakage trace leakage →
  canonicalizeMicroTrace trace = simulateMicroTraceFromLeakage leakage := by
  intro hConsistent
  cases trace
  rcases hConsistent with ⟨hPage, hExit, hShared⟩
  simp [canonicalizeMicroTrace, simulateMicroTraceFromLeakage, hPage, hExit, hShared]

theorem canonicalizedByLeakage_of_consistent
  {traces : Distribution SGXMicroTrace}
  {leakage : SGXMicroLeakage} :
  MicroDistributionConsistentWithLeakage traces leakage →
  CanonicalizedByLeakage traces leakage := by
  intro hConsistent trace hMem
  exact canonicalizeMicroTrace_eq_simulate_of_consistent (hConsistent trace hMem)

theorem canonicalLeakageSimulator_consistent
  (leakage : SGXMicroLeakage) :
  MicroDistributionConsistentWithLeakage
    (canonicalLeakageSimulator leakage)
    leakage := by
  intro trace hMem
  simp [canonicalLeakageSimulator, simulateMicroTraceFromLeakage, MicroTraceConsistentWithLeakage] at hMem ⊢
  rcases hMem with rfl
  simp

theorem canonicalLeakageSimulator_canonicalized
  (leakage : SGXMicroLeakage) :
  CanonicalizedByLeakage
    (canonicalLeakageSimulator leakage)
    leakage := by
  exact canonicalizedByLeakage_of_consistent
    (canonicalLeakageSimulator_consistent leakage)

theorem publicControllerMicroSemantics_budgetRelation
  {cfg₁ cfg₂ : SGXMicroConfig} :
  sameSGXMicroPublicProjection cfg₁ cfg₂ →
  budgetConsistentSGXMicroRelation
    (publicControllerMicroSemantics cfg₁)
    (publicControllerMicroSemantics cfg₂)
    (sgxMicroLeakage cfg₁) := by
  intro hPublic
  constructor
  · exact publicControllerMicroSemantics_consistent cfg₁
  · exact microDistributionConsistentWithLeakage_of_eq
      (sgxMicroLeakage_eq_of_samePublicProjection hPublic).symm
      (publicControllerMicroSemantics_consistent cfg₂)

theorem publicControllerMicroSemantics_canonicalizedRelation
  {cfg₁ cfg₂ : SGXMicroConfig} :
  sameSGXMicroPublicProjection cfg₁ cfg₂ →
  canonicalizedSGXMicroRelation
    (publicControllerMicroSemantics cfg₁)
    (publicControllerMicroSemantics cfg₂)
    (sgxMicroLeakage cfg₁) := by
  intro hPublic
  constructor
  · exact canonicalizedByLeakage_of_consistent
      (publicControllerMicroSemantics_consistent cfg₁)
  · exact canonicalizedByLeakage_of_consistent
      (microDistributionConsistentWithLeakage_of_eq
        (sgxMicroLeakage_eq_of_samePublicProjection hPublic).symm
        (publicControllerMicroSemantics_consistent cfg₂))

end UOToolchain
