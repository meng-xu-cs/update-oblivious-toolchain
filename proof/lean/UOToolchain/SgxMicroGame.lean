import UOToolchain.SgxMicroModel

namespace UOToolchain

/-- Legacy placeholder SGX micro local theorem interface.
The proof-grade normalized-controller path does not depend on this axiom. -/
axiom legacySgxMicroLocalTheorem
  (micro₁ micro₂ : Distribution SGXMicroTrace)
  (leakage : SGXMicroLeakage) :
  Prop

def legacyComputationalSGXMicroUO (run : SGXMicroSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameSGXMicroPublicProjection cfg₁ cfg₂ →
    legacySgxMicroLocalTheorem (run cfg₁) (run cfg₂) (sgxMicroLeakage cfg₁)

def legacyComputationalSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ leakage => legacySgxMicroLocalTheorem micro₁ micro₂ leakage

theorem legacySgxMicroLocalTheorem_uses_public_leakage
  (run : SGXMicroSemantics)
  (hLocal :
    ∀ cfg₁ cfg₂,
      sameSGXMicroPublicProjection cfg₁ cfg₂ →
      legacySgxMicroLocalTheorem (run cfg₁) (run cfg₂) (sgxMicroLeakage cfg₁)) :
  legacyComputationalSGXMicroUO run := by
  intro cfg₁ cfg₂ hPublic
  exact hLocal cfg₁ cfg₂ hPublic

end UOToolchain
