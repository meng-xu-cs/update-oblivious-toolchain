import UOToolchain.ExactObjects
import UOToolchain.CompilerInvariant
import UOToolchain.OramModel

namespace UOToolchain

def withPublicGas (run : TraceSemantics) (budget : Nat) : TraceSemantics :=
  fun cfg =>
    { (run cfg) with gasUsed := budget }

def exactEntrypointSemantics (runs : List TraceSemantics) (manifest : ManifestWitness) : TraceSemantics :=
  withPublicGas (composeExactRuns runs) manifest.publicGasBudget

def ArtifactSecurityWith
  (security : OramSecurityInterface)
  (exactRun : TraceSemantics)
  (oramRun : OramSemantics) : Prop :=
  ExactUO exactRun ∧ ComputationalUOWith security oramRun

theorem exactUO_withPublicGas {run : TraceSemantics} {budget : Nat}
  (hExact : ExactUO run) :
  ExactUO (withPublicGas run budget) := by
  intro cfg₁ cfg₂ hPublic
  exact viewMPlus_overwriteGas (budget := budget) (hExact cfg₁ cfg₂ hPublic)

theorem exactEntrypointPublicGasSafe
  (runs : List TraceSemantics)
  (manifest : ManifestWitness) :
  PublicGasSafe (exactEntrypointSemantics runs manifest) manifest := by
  intro cfg
  simp [exactEntrypointSemantics, withPublicGas]

theorem compositionTheorem
  (runs : List TraceSemantics)
  (manifest : ManifestWitness)
  (hRuns : ExactUOFamily runs) :
  ExactUO (exactEntrypointSemantics runs manifest) := by
  exact exactUO_withPublicGas (exactUO_compose hRuns)

theorem compositionGasTheorem
  (runs : List TraceSemantics)
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

theorem mixedArtifactCompositionWith
  (security : OramSecurityInterface)
  (runs : List TraceSemantics)
  (manifest : ManifestWitness)
  (hRuns : ExactUOFamily runs)
  (oramRun : OramSemantics)
  (hOram : ComputationalUOWith security oramRun) :
  ArtifactSecurityWith security (exactEntrypointSemantics runs manifest) oramRun := by
  exact ⟨compositionTheorem runs manifest hRuns, hOram⟩

end UOToolchain
