import UOToolchain.OramModel

namespace UOToolchain

/-- Legacy placeholder local theorem interface.
The proof-grade Path ORAM development does not depend on this axiom. -/
axiom legacyOramLocalTheorem
  (view₁ view₂ : Distribution ViewMPlus)
  (leakage : List OramAccessLeakage) :
  Prop

def legacyOramSecurityInterface : OramSecurityInterface :=
  { localTheorem := legacyOramLocalTheorem }

abbrev legacyComputationalUO (run : OramSemantics) : Prop :=
  ComputationalUOWith legacyOramSecurityInterface run

theorem legacyOramLocalTheorem_uses_public_leakage
  (run : OramSemantics)
  (hLocal :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacyOramLocalTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)) :
  legacyComputationalUO run := by
  exact computationalUOWith_uses_public_leakage legacyOramSecurityInterface run hLocal

end UOToolchain
