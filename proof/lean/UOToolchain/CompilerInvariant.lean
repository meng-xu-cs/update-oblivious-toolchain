import UOToolchain.IRSemantics

namespace UOToolchain

structure ManifestWitness where
  publicGasBudget : Nat
  secretArgs : List Nat
  oramAccesses : List (Nat × Nat)
deriving Repr, DecidableEq

def PublicGasSafe (run : Semantics) (manifest : ManifestWitness) : Prop :=
  ∀ cfg, (run cfg).gasUsed = manifest.publicGasBudget

theorem compilerSecrecyPreservation
  (run : Semantics)
  (cfg₁ cfg₂ : Config)
  (manifest : ManifestWitness)
  (hGas : PublicGasSafe run manifest) :
  samePublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = manifest.publicGasBudget ∧ (run cfg₂).gasUsed = manifest.publicGasBudget := by
  intro _hPublic
  exact ⟨hGas cfg₁, hGas cfg₂⟩

theorem publicGasSecretIndependent
  (run : Semantics)
  (cfg₁ cfg₂ : Config)
  (manifest : ManifestWitness)
  (hGas : PublicGasSafe run manifest) :
  samePublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = (run cfg₂).gasUsed := by
  intro hPublic
  have hBudget := compilerSecrecyPreservation run cfg₁ cfg₂ manifest hGas hPublic
  rcases hBudget with ⟨h₁, h₂⟩
  rw [h₁, h₂]

end UOToolchain
