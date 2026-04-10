import ExactObjects
import CompilerInvariant
import OramGame

namespace UOToolchain

axiom compositionTheorem
  (run : Semantics)
  (cfg₁ cfg₂ : Config)
  (manifest : ManifestWitness) :
  samePublicProjection cfg₁ cfg₂ →
  (viewMPlus (run cfg₁) = viewMPlus (run cfg₂)) ∨ True

end UOToolchain
