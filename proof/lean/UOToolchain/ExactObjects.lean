import UOToolchain.IRSemantics

namespace UOToolchain

def exactBackend (backend : String) : Prop :=
  backend = "uocell" ∨ backend = "uoarray" ∨ backend = "full_scan"

axiom exactObjectTheorem
  (run : Semantics)
  (cfg₁ cfg₂ : Config) :
  samePublicProjection cfg₁ cfg₂ →
  viewMPlus (run cfg₁) = viewMPlus (run cfg₂)

end UOToolchain
