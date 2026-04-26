import UOToolchain.IRSemantics

/-!
# Compiler-secrecy lemmas

After WP4.1 these lemmas are stated in two layers:

* `PublicGasSafe`, `compilerSecrecyPreservation`, and
  `publicGasSecretIndependent` over the abstract `TraceSemantics` surface
  used by `ExactObjects` / `Composition`. These are the older statements
  that the abstract trace-producer composition theorems consume directly.
* `EvaluatorPublicGasSafe`,
  `evaluatorCompilerSecrecyPreservation`, and
  `evaluatorPublicGasSecretIndependent` over the new operational
  `Semantics` (the WP4 evaluator surface). These are the WP4 versions
  that talk about the *real* evaluator's outcome rather than an abstract
  trace producer.

The existing trace-side statements are preserved unchanged so that the
abstract composition theorems remain unaffected. The new operational
versions are the ones the WP4 source-to-kernel compiler-correctness story
projects through.
-/

namespace UOToolchain

structure ManifestWitness where
  publicGasBudget : Nat
  secretArgs : List Nat
  oramAccesses : List (Nat × Nat)
deriving Repr, DecidableEq

/-! ## Trace-side abstract statements

These statements are over the older `TraceSemantics := TraceConfig → Trace`
abstraction. They are unchanged from the pre-WP4 placeholder: they say
that any abstract trace-producer whose `gasUsed` matches the manifest
budget yields equal `gasUsed` across configurations with equal public
projection.
-/

def PublicGasSafe (run : TraceSemantics) (manifest : ManifestWitness) : Prop :=
  ∀ cfg, (run cfg).gasUsed = manifest.publicGasBudget

theorem compilerSecrecyPreservation
  (run : TraceSemantics)
  (cfg₁ cfg₂ : TraceConfig)
  (manifest : ManifestWitness)
  (hGas : PublicGasSafe run manifest) :
  sameTracePublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = manifest.publicGasBudget ∧
    (run cfg₂).gasUsed = manifest.publicGasBudget := by
  intro _hPublic
  exact ⟨hGas cfg₁, hGas cfg₂⟩

theorem publicGasSecretIndependent
  (run : TraceSemantics)
  (cfg₁ cfg₂ : TraceConfig)
  (manifest : ManifestWitness)
  (hGas : PublicGasSafe run manifest) :
  sameTracePublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = (run cfg₂).gasUsed := by
  intro hPublic
  have hBudget := compilerSecrecyPreservation run cfg₁ cfg₂ manifest hGas hPublic
  rcases hBudget with ⟨h₁, h₂⟩
  rw [h₁, h₂]

/-! ## Operational evaluator statements (real WP4 surface)

These statements are over the new operational evaluator
`Semantics := IR.OperationalConfig → IR.Outcome`. They restate the gas
discipline against the *real* evaluator: an evaluator is gas-safe
relative to the manifest when, for every operational configuration, the
evaluator's reported gas usage equals the manifest's public gas budget.
-/

def EvaluatorPublicGasSafe (run : Semantics) (manifest : ManifestWitness) : Prop :=
  ∀ cfg, (run cfg).gasUsed = manifest.publicGasBudget

theorem evaluatorCompilerSecrecyPreservation
  (run : Semantics)
  (cfg₁ cfg₂ : IR.OperationalConfig)
  (manifest : ManifestWitness)
  (hGas : EvaluatorPublicGasSafe run manifest) :
  IR.sameOperationalPublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = manifest.publicGasBudget ∧
    (run cfg₂).gasUsed = manifest.publicGasBudget := by
  intro _hPublic
  exact ⟨hGas cfg₁, hGas cfg₂⟩

theorem evaluatorPublicGasSecretIndependent
  (run : Semantics)
  (cfg₁ cfg₂ : IR.OperationalConfig)
  (manifest : ManifestWitness)
  (hGas : EvaluatorPublicGasSafe run manifest) :
  IR.sameOperationalPublicProjection cfg₁ cfg₂ →
  (run cfg₁).gasUsed = (run cfg₂).gasUsed := by
  intro hPublic
  have hBudget :=
    evaluatorCompilerSecrecyPreservation run cfg₁ cfg₂ manifest hGas hPublic
  rcases hBudget with ⟨h₁, h₂⟩
  rw [h₁, h₂]

end UOToolchain
