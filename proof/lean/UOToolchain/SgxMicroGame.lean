import UOToolchain.SgxController

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

axiom sgxMicroLocalTheorem
  (micro₁ micro₂ : Distribution SGXMicroTrace)
  (leakage : SGXMicroLeakage) :
  Prop

def ComputationalSGXMicroUO (run : SGXMicroSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameSGXMicroPublicProjection cfg₁ cfg₂ →
    sgxMicroLocalTheorem (run cfg₁) (run cfg₂) (sgxMicroLeakage cfg₁)

def computationalSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ leakage => sgxMicroLocalTheorem micro₁ micro₂ leakage

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

end UOToolchain
