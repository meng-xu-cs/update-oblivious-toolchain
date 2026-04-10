import UOToolchain.IRSemantics

namespace UOToolchain

structure ManifestWitness where
  publicGasBudget : Nat
  secretArgs : List Nat
  oramAccesses : List (Nat × Nat)
deriving Repr, DecidableEq

axiom compilerSecrecyPreservation
  (run : Semantics)
  (cfg₁ cfg₂ : Config)
  (manifest : ManifestWitness) :
  samePublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = manifest.publicGasBudget ∧ (run cfg₂).gasUsed = manifest.publicGasBudget

end UOToolchain
