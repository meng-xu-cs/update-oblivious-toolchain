import UOToolchain.Composition
import UOToolchain.OramGame

namespace UOToolchain

abbrev legacyArtifactSecurity (exactRun : Semantics) (oramRun : OramSemantics) : Prop :=
  ArtifactSecurityWith legacyOramSecurityInterface exactRun oramRun

theorem legacyMixedArtifactComposition
  (runs : List Semantics)
  (manifest : ManifestWitness)
  (hRuns : ExactUOFamily runs)
  (oramRun : OramSemantics)
  (hOram : legacyComputationalUO oramRun) :
  legacyArtifactSecurity (exactEntrypointSemantics runs manifest) oramRun := by
  exact ⟨compositionTheorem runs manifest hRuns, hOram⟩

end UOToolchain
