import UOToolchain.ExactObjects
import UOToolchain.CompilerInvariant
import UOToolchain.OramGame

namespace UOToolchain

def withPublicGas (run : Semantics) (budget : Nat) : Semantics :=
  fun cfg =>
    { (run cfg) with gasUsed := budget }

def exactEntrypointSemantics (runs : List Semantics) (manifest : ManifestWitness) : Semantics :=
  withPublicGas (composeExactRuns runs) manifest.publicGasBudget

def ArtifactSecurityWith
  (security : OramSecurityInterface)
  (exactRun : Semantics)
  (oramRun : OramSemantics) : Prop :=
  ExactUO exactRun ∧ ComputationalUOWith security oramRun

abbrev ArtifactSecurity (exactRun : Semantics) (oramRun : OramSemantics) : Prop :=
  ArtifactSecurityWith surrogateOramSecurityInterface exactRun oramRun

theorem exactUO_withPublicGas {run : Semantics} {budget : Nat}
  (hExact : ExactUO run) :
  ExactUO (withPublicGas run budget) := by
  intro cfg₁ cfg₂ hPublic
  exact viewMPlus_overwriteGas (budget := budget) (hExact cfg₁ cfg₂ hPublic)

theorem exactEntrypointPublicGasSafe
  (runs : List Semantics)
  (manifest : ManifestWitness) :
  PublicGasSafe (exactEntrypointSemantics runs manifest) manifest := by
  intro cfg
  simp [exactEntrypointSemantics, withPublicGas]

theorem compositionTheorem
  (runs : List Semantics)
  (manifest : ManifestWitness)
  (hRuns : ExactUOFamily runs) :
  ExactUO (exactEntrypointSemantics runs manifest) := by
  exact exactUO_withPublicGas (exactUO_compose hRuns)

theorem compositionGasTheorem
  (runs : List Semantics)
  (manifest : ManifestWitness)
  (cfg₁ cfg₂ : Config) :
  samePublicProjection cfg₁ cfg₂ →
  (exactEntrypointSemantics runs manifest cfg₁).gasUsed = manifest.publicGasBudget ∧
    (exactEntrypointSemantics runs manifest cfg₂).gasUsed = manifest.publicGasBudget := by
  intro hPublic
  exact compilerSecrecyPreservation
    (exactEntrypointSemantics runs manifest)
    cfg₁
    cfg₂
    manifest
    (exactEntrypointPublicGasSafe runs manifest)
    hPublic

theorem mixedArtifactComposition
  (runs : List Semantics)
  (manifest : ManifestWitness)
  (hRuns : ExactUOFamily runs)
  (oramRun : OramSemantics)
  (hOram : ComputationalUO oramRun) :
  ArtifactSecurity (exactEntrypointSemantics runs manifest) oramRun := by
  exact ⟨compositionTheorem runs manifest hRuns, hOram⟩

theorem mixedArtifactCompositionWith
  (security : OramSecurityInterface)
  (runs : List Semantics)
  (manifest : ManifestWitness)
  (hRuns : ExactUOFamily runs)
  (oramRun : OramSemantics)
  (hOram : ComputationalUOWith security oramRun) :
  ArtifactSecurityWith security (exactEntrypointSemantics runs manifest) oramRun := by
  exact ⟨compositionTheorem runs manifest hRuns, hOram⟩

end UOToolchain
