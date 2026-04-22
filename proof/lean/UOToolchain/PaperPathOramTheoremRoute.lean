import UOToolchain.PathOramJACMTheorem
import UOToolchain.RuntimeConfidentialCoreAssurance

namespace UOToolchain

/-- Paper-main theorem target for the concrete `path_oram_local_posmap_v1`
backend. This keeps the theorem boundary identical to the executable artifact
route; only the theorem-source provenance differs. -/
abbrev PaperMainPathOramTheoremTarget
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :=
  PathOramLocalPosmapV1StandardTheoremTarget assumptions

/-- Explicit remaining runtime-side assumption bundle for the frozen paper
route. The current proof gap is no longer left as prose: every emitted witness
in the seeded runtime family must satisfy the same proof-grade acceptance
predicate enforced by the Lean runtime-witness checker. -/
structure PaperMainRuntimeKernelAssumptions
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) where
  proofGradeAccepted :
    ∀ cfg seed, seed < (bundle.family cfg).seedCount →
      ((bundle.family cfg).witnessAt seed).ProofGradeValid modelTags

/-- Remaining runtime/kernel proof boundary for the paper route. This is the
checked runtime/kernel-interface-bundle predicate that each emitted runtime
witness must satisfy in order to justify the trusted runtime/kernel story now
carried explicitly in Lean. -/
def PaperMainRuntimeKernelBoundaryAt
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags) : Prop :=
  ∀ seed, seed < family.seedCount →
    RuntimeProofGradeKernelInterfaceBundle (family.witnessAt seed)

/-- Remaining runtime/kernel proof boundary for the paper route. This is the
checked runtime/kernel-interface-bundle predicate that each emitted runtime
witness must satisfy in order to justify the trusted runtime/kernel story now
carried explicitly in Lean. -/
def PaperMainRuntimeKernelBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) : Prop :=
  ∀ cfg, PaperMainRuntimeKernelBoundaryAt (bundle.family cfg)

theorem PaperMainRuntimeKernelBoundaryAt.projects_to_runtimeKernelBoundaryFacts
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  (runtime : PaperMainRuntimeKernelBoundaryAt family) :
  ∀ seed, seed < family.seedCount →
    RuntimeProofGradeKernelBoundaryFacts (family.witnessAt seed) := by
  intro seed hSeed
  exact runtimeProofGradeKernelInterfaceBundle_toKernelBoundaryFacts
    (runtime seed hSeed)

theorem PaperMainRuntimeKernelBoundaryAt.projects_to_runtimeKernelInterface
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  (runtime : PaperMainRuntimeKernelBoundaryAt family) :
  ∀ seed, seed < family.seedCount →
    RuntimeProofGradeKernelInterface (family.witnessAt seed) := by
  intro seed hSeed
  exact runtimeProofGradeKernelInterfaceBundle_toProofGradeKernelInterface
    (runtime seed hSeed)

theorem PaperMainRuntimeKernelBoundaryAt.projects_to_shellBoundaryBundle
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  (runtime : PaperMainRuntimeKernelBoundaryAt family) :
  ∀ seed, seed < family.seedCount →
    ∃ shellBoundaryBundle,
      (family.witnessAt seed).shellBoundaryBundle? = some shellBoundaryBundle ∧
        shellBoundaryBundle.Valid := by
  intro seed hSeed
  exact runtimeProofGradeKernelInterfaceBundle_toShellBoundaryBundle
    (runtime seed hSeed)

noncomputable def PaperMainRuntimeKernelBoundaryAt.projects_to_runtimeKernelConfinementBoundary
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  (runtime : PaperMainRuntimeKernelBoundaryAt family) :
  ∀ seed, seed < family.seedCount →
    RuntimeKernelConfinementBoundary := by
  intro seed hSeed
  exact RuntimeProofGradeKernelInterfaceBundle.confinementBoundary
    (runtime seed hSeed)

theorem runtimeWitness_proofGradeKernelInterfaceBundle_projects_to_singletonRuntimeKernelBoundaryAt
  {modelTags : SGXModelTags}
  {runtimeWitness : RuntimeRefinementWitness}
  (hValid : runtimeWitness.ProofGradeValid modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (runtimeWitness.toSingletonSeededRuntimePathOramWitnessFamily hValid.1) := by
  intro seed hSeed
  change seed < 1 at hSeed
  have hZero : seed = 0 := by omega
  subst hZero
  simpa using runtimeWitness_proofGradeKernelInterfaceBundle
    runtimeWitness
    modelTags
    hValid

theorem PaperMainRuntimeKernelAssumptions.projects_to_runtimeKernelBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelAssumptions bundle) :
  PaperMainRuntimeKernelBoundary bundle := by
  intro cfg seed hSeed
  exact runtimeWitness_proofGradeKernelInterfaceBundle
    ((bundle.family cfg).witnessAt seed)
    modelTags
    (runtime.proofGradeAccepted cfg seed hSeed)

theorem PaperMainRuntimeKernelBoundary.projects_to_runtimeKernelBoundaryFacts
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelBoundary bundle) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelBoundaryFacts ((bundle.family cfg).witnessAt seed) := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelBoundaryAt.projects_to_runtimeKernelBoundaryFacts
    (runtime cfg)
    seed
    hSeed

theorem PaperMainRuntimeKernelBoundary.projects_to_runtimeKernelInterface
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelBoundary bundle) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelInterface ((bundle.family cfg).witnessAt seed) := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelBoundaryAt.projects_to_runtimeKernelInterface
    (runtime cfg)
    seed
    hSeed

theorem PaperMainRuntimeKernelBoundary.projects_to_shellBoundaryBundle
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelBoundary bundle) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    ∃ shellBoundaryBundle,
      ((bundle.family cfg).witnessAt seed).shellBoundaryBundle? = some shellBoundaryBundle ∧
        shellBoundaryBundle.Valid := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelBoundaryAt.projects_to_shellBoundaryBundle
    (runtime cfg)
    seed
    hSeed

noncomputable def PaperMainRuntimeKernelBoundary.projects_to_runtimeKernelConfinementBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelBoundary bundle) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeKernelConfinementBoundary := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelBoundaryAt.projects_to_runtimeKernelConfinementBoundary
    (runtime cfg)
    seed
    hSeed

/-- Stronger paper-side runtime assumption bundle for the shared slot-DSL
route. Besides proof-grade witness acceptance, this fixes the exact
confidential slot program that the real runtime is supposed to execute for
each public ORAM configuration. -/
structure PaperMainRuntimeKernelSlotAssumptions
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) where
  confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram
  proofGradeSlotAccepted :
    ∀ cfg seed, seed < (bundle.family cfg).seedCount →
      RuntimeConfidentialCoreKernelInterfaceSlotAssurance
        ((bundle.family cfg).witnessAt seed)
        (confidentialSlotProgram cfg)
        modelTags

/-- Stronger shared-DSL paper-side runtime boundary. For every admitted public
configuration and seed, the emitted runtime witness must line up exactly with
one fixed confidential slot program, and the resulting runtime/kernel
interface bundle must still expose the exact proof-grade interface facts needed
by the theorem route. -/
def PaperMainRuntimeKernelSlotBoundaryAt
  {modelTags : SGXModelTags}
  (family : SeededRuntimePathOramWitnessFamily modelTags)
  (confidentialSlotProgram : ConfidentialKernelSlotProgram) : Prop :=
  ∀ seed, seed < family.seedCount →
    ∃ kernelInterfaceBundle,
      (family.witnessAt seed).kernelInterfaceBundle? = some kernelInterfaceBundle ∧
        kernelInterfaceBundle.Valid ∧
        kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some confidentialSlotProgram.expectedRuntimeKernelSteps ∧
        kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
          confidentialSlotProgram.expectedRuntimeKernelSteps

/-- Stronger shared-DSL paper-side runtime boundary. For every admitted public
configuration and seed, the emitted runtime witness must line up exactly with
one fixed confidential slot program, and the resulting runtime/kernel
interface bundle must still expose the exact proof-grade interface facts needed
by the theorem route. -/
def PaperMainRuntimeKernelSlotBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram) : Prop :=
  ∀ cfg,
    PaperMainRuntimeKernelSlotBoundaryAt
      (bundle.family cfg)
      (confidentialSlotProgram cfg)

theorem PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelBoundaryFacts
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundaryAt family confidentialSlotProgram) :
  ∀ seed, seed < family.seedCount →
    RuntimeProofGradeKernelBoundaryFacts (family.witnessAt seed) := by
  intro seed hSeed
  rcases runtime seed hSeed with
    ⟨kernelInterfaceBundle, hBundle, hBundleValid, _hExpectedSteps, _hKernelSteps⟩
  exact runtimeProofGradeKernelInterfaceBundle_toKernelBoundaryFacts
    ⟨kernelInterfaceBundle, hBundle, hBundleValid⟩

theorem PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelInterface
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundaryAt family confidentialSlotProgram) :
  ∀ seed, seed < family.seedCount →
    RuntimeProofGradeKernelInterface (family.witnessAt seed) := by
  intro seed hSeed
  rcases runtime seed hSeed with
    ⟨kernelInterfaceBundle, hBundle, hBundleValid, _hExpectedSteps, _hKernelSteps⟩
  exact runtimeKernelInterfaceBundle_toProofGradeKernelInterface
    hBundle
    hBundleValid

theorem PaperMainRuntimeKernelSlotBoundaryAt.projects_to_shellBoundaryBundle
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundaryAt family confidentialSlotProgram) :
  ∀ seed, seed < family.seedCount →
    ∃ shellBoundaryBundle,
      (family.witnessAt seed).shellBoundaryBundle? = some shellBoundaryBundle ∧
        shellBoundaryBundle.Valid := by
  intro seed hSeed
  rcases runtime seed hSeed with
    ⟨kernelInterfaceBundle, hBundle, hBundleValid, _hExpectedSteps, _hKernelSteps⟩
  exact runtimeKernelInterfaceBundle_toShellBoundaryBundle
    hBundle
    hBundleValid

noncomputable def PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelInterfaceSlotBoundary
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundaryAt family confidentialSlotProgram) :
  ∀ seed, seed < family.seedCount →
    RuntimeKernelInterfaceSlotBoundary := by
  intro seed hSeed
  let hBundleExists :
      ∃ kernelInterfaceBundle,
        (family.witnessAt seed).kernelInterfaceBundle? = some kernelInterfaceBundle ∧
          kernelInterfaceBundle.Valid ∧
          kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
            some confidentialSlotProgram.expectedRuntimeKernelSteps ∧
          kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
            confidentialSlotProgram.expectedRuntimeKernelSteps := runtime seed hSeed
  let kernelInterfaceBundle := Classical.choose hBundleExists
  have hBundleSpec := Classical.choose_spec hBundleExists
  exact
    { kernelInterfaceBundle := kernelInterfaceBundle
    , confidentialSlotProgram := confidentialSlotProgram
    , kernelInterfaceValid := hBundleSpec.2.1
    , expectedKernelStepsExact := hBundleSpec.2.2.1
    , emittedKernelStepsExact := hBundleSpec.2.2.2
    }

noncomputable def PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelConfinementBoundary
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundaryAt family confidentialSlotProgram) :
  ∀ seed, seed < family.seedCount →
    RuntimeKernelConfinementBoundary := by
  intro seed hSeed
  let bundle := Classical.choose (runtime seed hSeed)
  let hBundle := Classical.choose_spec (runtime seed hSeed)
  let hBundleValid := hBundle.2.1
  exact bundle.confinementBoundary hBundleValid

theorem PaperMainRuntimeKernelSlotBoundaryAt.toRuntimeKernelBoundaryAt
  {modelTags : SGXModelTags}
  {family : SeededRuntimePathOramWitnessFamily modelTags}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundaryAt family confidentialSlotProgram) :
  PaperMainRuntimeKernelBoundaryAt family := by
  intro seed hSeed
  rcases runtime seed hSeed with
    ⟨kernelInterfaceBundle, hBundle, hBundleValid, _hExpectedSteps, _hKernelSteps⟩
  exact ⟨kernelInterfaceBundle, hBundle, hBundleValid⟩

def PaperMainRuntimeKernelSlotAssumptions.toRuntimeKernelAssumptions
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelSlotAssumptions bundle) :
  PaperMainRuntimeKernelAssumptions bundle :=
  { proofGradeAccepted := by
      intro cfg seed hSeed
      exact (runtime.proofGradeSlotAccepted cfg seed hSeed).1
  }

theorem PaperMainRuntimeKernelSlotAssumptions.projects_to_runtimeKernelSlotBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelSlotAssumptions bundle) :
  PaperMainRuntimeKernelSlotBoundary bundle runtime.confidentialSlotProgram := by
  intro cfg seed hSeed
  have hSlot := runtime.proofGradeSlotAccepted cfg seed hSeed
  rcases hSlot with
    ⟨_hWitnessValid, _hRuntimeNormalForm, kernelInterfaceBundle, hBundle, hBundleValid,
      hExpectedSteps, hKernelSteps⟩
  exact ⟨kernelInterfaceBundle, hBundle, hBundleValid, hExpectedSteps, hKernelSteps⟩

theorem PaperMainRuntimeKernelSlotAssumptions.projects_to_runtimeKernelBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (runtime : PaperMainRuntimeKernelSlotAssumptions bundle) :
  PaperMainRuntimeKernelBoundary bundle := by
  exact
    (runtime.toRuntimeKernelAssumptions).projects_to_runtimeKernelBoundary

theorem PaperMainRuntimeKernelSlotBoundary.projects_to_runtimeKernelBoundaryFacts
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelBoundaryFacts ((bundle.family cfg).witnessAt seed) := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelBoundaryFacts
    (runtime cfg)
    seed
    hSeed

theorem PaperMainRuntimeKernelSlotBoundary.projects_to_runtimeKernelInterface
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelInterface ((bundle.family cfg).witnessAt seed) := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelInterface
    (runtime cfg)
    seed
    hSeed

theorem PaperMainRuntimeKernelSlotBoundary.projects_to_shellBoundaryBundle
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    ∃ shellBoundaryBundle,
      ((bundle.family cfg).witnessAt seed).shellBoundaryBundle? = some shellBoundaryBundle ∧
        shellBoundaryBundle.Valid := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelSlotBoundaryAt.projects_to_shellBoundaryBundle
    (runtime cfg)
    seed
    hSeed

noncomputable def PaperMainRuntimeKernelSlotBoundary.projects_to_runtimeKernelInterfaceSlotBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeKernelInterfaceSlotBoundary := by
  intro cfg seed hSeed
  exact
    PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelInterfaceSlotBoundary
      (runtime cfg)
      seed
      hSeed

noncomputable def PaperMainRuntimeKernelSlotBoundary.projects_to_runtimeKernelConfinementBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeKernelConfinementBoundary := by
  intro cfg seed hSeed
  exact PaperMainRuntimeKernelSlotBoundaryAt.projects_to_runtimeKernelConfinementBoundary
    (runtime cfg)
    seed
    hSeed

theorem PaperMainRuntimeKernelSlotBoundary.toRuntimeKernelBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram}
  (runtime : PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram) :
  PaperMainRuntimeKernelBoundary bundle := by
  intro cfg
  exact PaperMainRuntimeKernelSlotBoundaryAt.toRuntimeKernelBoundaryAt (runtime cfg)

theorem runtimeConfidentialCoreKernelInterfaceSlotAssurance_projects_to_singletonRuntimeKernelSlotBoundaryAt
  {modelTags : SGXModelTags}
  {runtimeWitness : RuntimeRefinementWitness}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (hRuntime :
    RuntimeConfidentialCoreKernelInterfaceSlotAssurance
      runtimeWitness
      confidentialSlotProgram
      modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (runtimeWitness.toSingletonSeededRuntimePathOramWitnessFamily hRuntime.1.1)
    confidentialSlotProgram := by
  intro seed hSeed
  change seed < 1 at hSeed
  have hZero : seed = 0 := by omega
  subst hZero
  rcases hRuntime with
    ⟨_hRuntimeProofGrade, _hRuntimeNormalForm, kernelInterfaceBundle, hBundle, hBundleValid,
      hExpectedSteps, hKernelSteps⟩
  exact ⟨kernelInterfaceBundle, by simpa using hBundle, hBundleValid, hExpectedSteps,
    hKernelSteps⟩

theorem runtimeConfidentialCoreKernelInterfaceSlotAssurance_projects_to_singletonRuntimeKernelBoundaryAt
  {modelTags : SGXModelTags}
  {runtimeWitness : RuntimeRefinementWitness}
  {confidentialSlotProgram : ConfidentialKernelSlotProgram}
  (hRuntime :
    RuntimeConfidentialCoreKernelInterfaceSlotAssurance
      runtimeWitness
      confidentialSlotProgram
      modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (runtimeWitness.toSingletonSeededRuntimePathOramWitnessFamily hRuntime.1.1) := by
  exact
    PaperMainRuntimeKernelSlotBoundaryAt.toRuntimeKernelBoundaryAt
      (runtimeConfidentialCoreKernelInterfaceSlotAssurance_projects_to_singletonRuntimeKernelSlotBoundaryAt
        hRuntime)

theorem runtimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
  {modelTags : SGXModelTags}
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelSlotBoundaryAt
    (bundle.runtimeWitness.toSingletonSeededRuntimePathOramWitnessFamily hValid.1.1.1)
    bundle.confidentialSlotProgram := by
  have hRuntime :
      RuntimeConfidentialCoreKernelInterfaceSlotAssurance
        bundle.runtimeWitness
        bundle.confidentialSlotProgram
        modelTags := by
    rcases
        runtimeConfidentialCoreKernelInterfaceSlotBundle_proofGradeAssurance
          bundle
          modelTags
          hValid with
      ⟨hBundle, hBundleValid, hExpectedSteps, hKernelSteps⟩
    exact ⟨hValid.1.1, hValid.1.2.1, bundle.kernelInterfaceBundle, hBundle, hBundleValid,
      hExpectedSteps, hKernelSteps⟩
  exact
    runtimeConfidentialCoreKernelInterfaceSlotAssurance_projects_to_singletonRuntimeKernelSlotBoundaryAt
      hRuntime

theorem runtimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelBoundaryAt
  {modelTags : SGXModelTags}
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  (hValid : bundle.Valid modelTags) :
  PaperMainRuntimeKernelBoundaryAt
    (bundle.runtimeWitness.toSingletonSeededRuntimePathOramWitnessFamily hValid.1.1.1) := by
  exact
    PaperMainRuntimeKernelSlotBoundaryAt.toRuntimeKernelBoundaryAt
      (runtimeConfidentialCoreKernelInterfaceSlotBundle_valid_projects_to_singletonRuntimeKernelSlotBoundaryAt
        hValid)

/-- Strengthened seeded paper-main bundle whose emitted witnesses are already
known to satisfy proof-grade acceptance. This is the smallest current bundle
shape from which the explicit paper-route runtime assumption bundle can be
discharged mechanically rather than supplied as an unrelated external claim. -/
structure ProofGradeSeededRuntimePaperMainBundle (modelTags : SGXModelTags)
    extends SeededRuntimePaperMainBundle modelTags where
  proofGradeAccepted :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).ProofGradeValid modelTags

def ProofGradeSeededRuntimePaperMainBundle.paperMainRuntimeKernelAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags) :
  PaperMainRuntimeKernelAssumptions bundle.toSeededRuntimePaperMainBundle :=
  { proofGradeAccepted := bundle.proofGradeAccepted }

theorem ProofGradeSeededRuntimePaperMainBundle.runtimeKernelBoundary
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags) :
  PaperMainRuntimeKernelBoundary bundle.toSeededRuntimePaperMainBundle := by
  exact
    (bundle.paperMainRuntimeKernelAssumptions).projects_to_runtimeKernelBoundary

/-- Stronger seeded paper-main bundle for the shared slot-DSL route. This
packages the exact confidential slot program for each public ORAM
configuration together with the proof-grade runtime acceptance predicate that
ties every emitted witness back to that fixed slot program. -/
structure ProofGradeSeededRuntimePaperMainSlotBundle (modelTags : SGXModelTags)
    extends SeededRuntimePaperMainBundle modelTags where
  confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram
  proofGradeSlotAccepted :
    ∀ cfg seed, seed < (family cfg).seedCount →
      RuntimeConfidentialCoreKernelInterfaceSlotAssurance
        ((family cfg).witnessAt seed)
        (confidentialSlotProgram cfg)
        modelTags

def ProofGradeSeededRuntimePaperMainSlotBundle.paperMainRuntimeKernelSlotAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags) :
  PaperMainRuntimeKernelSlotAssumptions bundle.toSeededRuntimePaperMainBundle :=
  { confidentialSlotProgram := bundle.confidentialSlotProgram
  , proofGradeSlotAccepted := bundle.proofGradeSlotAccepted
  }

def ProofGradeSeededRuntimePaperMainSlotBundle.paperMainRuntimeKernelAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags) :
  PaperMainRuntimeKernelAssumptions bundle.toSeededRuntimePaperMainBundle :=
  (bundle.paperMainRuntimeKernelSlotAssumptions).toRuntimeKernelAssumptions

theorem ProofGradeSeededRuntimePaperMainSlotBundle.runtimeKernelSlotBoundary
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags) :
  PaperMainRuntimeKernelSlotBoundary
    bundle.toSeededRuntimePaperMainBundle
    bundle.confidentialSlotProgram := by
  exact
    (bundle.paperMainRuntimeKernelSlotAssumptions).projects_to_runtimeKernelSlotBoundary

theorem ProofGradeSeededRuntimePaperMainSlotBundle.runtimeKernelBoundary
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags) :
  PaperMainRuntimeKernelBoundary bundle.toSeededRuntimePaperMainBundle := by
  exact
    (bundle.paperMainRuntimeKernelAssumptions).projects_to_runtimeKernelBoundary

/-- Paper-facing explicit assumption bundle at the frozen theorem route.
Backend cryptographic assumptions and the remaining runtime/kernel proof
interface boundary are tracked separately so the paper and artifact story can
state exactly what is proved versus still trusted. This top-level paper route
now carries the minimal runtime-side boundary fact directly, rather than the
stronger proof-grade witness-acceptance assumption that can project to it. -/
structure PaperMainPathOramAssumptions
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) where
  backend : PathOramLocalPosmapV1SecurityAssumptions
  runtimeKernelBoundary : PaperMainRuntimeKernelBoundary bundle

/-- Stronger paper-facing assumption bundle that keeps the shared slot-DSL
runtime boundary explicit all the way to the end-to-end theorem route. -/
structure PaperMainPathOramSlotAssumptions
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) where
  backend : PathOramLocalPosmapV1SecurityAssumptions
  confidentialSlotProgram : OramConfig → ConfidentialKernelSlotProgram
  runtimeKernelSlotBoundary :
    PaperMainRuntimeKernelSlotBoundary bundle confidentialSlotProgram

def PaperMainPathOramSlotAssumptions.toPaperMainPathOramAssumptions
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  (assumptions : PaperMainPathOramSlotAssumptions bundle) :
  PaperMainPathOramAssumptions bundle :=
  { backend := assumptions.backend
  , runtimeKernelBoundary := by
      intro cfg seed hSeed
      rcases assumptions.runtimeKernelSlotBoundary cfg seed hSeed with
        ⟨kernelInterfaceBundle, hBundle, hBundleValid, _hExpectedSteps, _hKernelSteps⟩
      exact ⟨kernelInterfaceBundle, hBundle, hBundleValid⟩
  }

def ProofGradeSeededRuntimePaperMainBundle.paperMainPathOramAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions) :
  PaperMainPathOramAssumptions bundle.toSeededRuntimePaperMainBundle :=
  { backend := backend
  , runtimeKernelBoundary := bundle.runtimeKernelBoundary
  }

def ProofGradeSeededRuntimePaperMainSlotBundle.paperMainPathOramSlotAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions) :
  PaperMainPathOramSlotAssumptions bundle.toSeededRuntimePaperMainBundle :=
  { backend := backend
  , confidentialSlotProgram := bundle.confidentialSlotProgram
  , runtimeKernelSlotBoundary := bundle.runtimeKernelSlotBoundary
  }

def ProofGradeSeededRuntimePaperMainSlotBundle.paperMainPathOramAssumptions
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions) :
  PaperMainPathOramAssumptions bundle.toSeededRuntimePaperMainBundle :=
  (bundle.paperMainPathOramSlotAssumptions backend).toPaperMainPathOramAssumptions

/-- Paper-facing assurance object at the frozen route. The backend half is
discharged by the paper theorem source at the fixed standard-ORAM interface,
while the runtime half records the still-undischarged proof boundary for the
real kernel implementation. -/
structure PaperMainPathOramAssurance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramAssumptions bundle) where
  backendRealization :
    PathOramLocalPosmapV1StandardTheoremRealization
      bundle.toSeededRuntimePathOramProofBundle
      assumptions.backend
  runtimeKernelBoundary :
    PaperMainRuntimeKernelBoundary bundle

/-- Stronger paper-facing assurance object that keeps the shared slot-DSL
runtime/kernel boundary explicit at the same frozen paper route. -/
structure PaperMainPathOramSlotAssurance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramSlotAssumptions bundle) where
  backendRealization :
    PathOramLocalPosmapV1StandardTheoremRealization
      bundle.toSeededRuntimePathOramProofBundle
      assumptions.backend
  runtimeKernelSlotBoundary :
    PaperMainRuntimeKernelSlotBoundary
      bundle
      assumptions.confidentialSlotProgram

/-- Final paper-facing boundary currently supported by the repository at the
frozen route: the backend theorem consequence already follows for the seeded
runtime bundle, while the remaining runtime/kernel honesty gap is carried as an
explicit proof-interface boundary instead of being hidden in prose. -/
def PaperMainPathOramEndToEndBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramAssumptions bundle) : Prop :=
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions.backend ∧
    PaperMainRuntimeKernelBoundary bundle

/-- Stronger paper-facing boundary that carries the shared slot-DSL
runtime/kernel interface all the way to the end-to-end theorem route. -/
def PaperMainPathOramSlotEndToEndBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramSlotAssumptions bundle) : Prop :=
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions.backend ∧
    PaperMainRuntimeKernelSlotBoundary
      bundle
      assumptions.confidentialSlotProgram

theorem PaperMainPathOramEndToEndBoundary.projects_to_runtimeKernelInterface
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (boundary : PaperMainPathOramEndToEndBoundary bundle assumptions) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelInterface ((bundle.family cfg).witnessAt seed) := by
  exact PaperMainRuntimeKernelBoundary.projects_to_runtimeKernelInterface boundary.2

theorem PaperMainPathOramEndToEndBoundary.projects_to_shellBoundaryBundle
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (boundary : PaperMainPathOramEndToEndBoundary bundle assumptions) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    ∃ shellBoundaryBundle,
      ((bundle.family cfg).witnessAt seed).shellBoundaryBundle? = some shellBoundaryBundle ∧
        shellBoundaryBundle.Valid := by
  exact PaperMainRuntimeKernelBoundary.projects_to_shellBoundaryBundle boundary.2

noncomputable def PaperMainPathOramEndToEndBoundary.projects_to_runtimeKernelConfinementBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (boundary : PaperMainPathOramEndToEndBoundary bundle assumptions) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeKernelConfinementBoundary := by
  exact PaperMainRuntimeKernelBoundary.projects_to_runtimeKernelConfinementBoundary
    boundary.2

theorem PaperMainPathOramSlotEndToEndBoundary.projects_to_runtimeKernelInterface
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (boundary : PaperMainPathOramSlotEndToEndBoundary bundle assumptions) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeProofGradeKernelInterface ((bundle.family cfg).witnessAt seed) := by
  exact PaperMainRuntimeKernelSlotBoundary.projects_to_runtimeKernelInterface boundary.2

theorem PaperMainPathOramSlotEndToEndBoundary.projects_to_shellBoundaryBundle
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (boundary : PaperMainPathOramSlotEndToEndBoundary bundle assumptions) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    ∃ shellBoundaryBundle,
      ((bundle.family cfg).witnessAt seed).shellBoundaryBundle? = some shellBoundaryBundle ∧
        shellBoundaryBundle.Valid := by
  exact PaperMainRuntimeKernelSlotBoundary.projects_to_shellBoundaryBundle boundary.2

noncomputable def PaperMainPathOramSlotEndToEndBoundary.projects_to_runtimeKernelConfinementBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (boundary : PaperMainPathOramSlotEndToEndBoundary bundle assumptions) :
  ∀ cfg seed, seed < (bundle.family cfg).seedCount →
    RuntimeKernelConfinementBoundary := by
  exact PaperMainRuntimeKernelSlotBoundary.projects_to_runtimeKernelConfinementBoundary
    boundary.2

theorem PaperMainPathOramAssurance.standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (assurance : PaperMainPathOramAssurance bundle assumptions) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions.backend
    bundle.publicView
    bundle.toSeededRuntimePathOramProofBundle.storageRun
    bundle.publicOutcome
    bundle.boundarySchedule := by
  exact
    assurance.backendRealization.standardPaperMainBoundary
      bundle.publicOutcomeSafe
      bundle.boundarySafe

theorem PaperMainPathOramAssurance.paperTheoremBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (_assurance : PaperMainPathOramAssurance bundle assumptions) :
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions.backend := by
  exact bundle.pathOramLocalPosmapV1_paperTheoremBoundary assumptions.backend

theorem PaperMainPathOramAssurance.endToEndBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramAssumptions bundle}
  (assurance : PaperMainPathOramAssurance bundle assumptions) :
  PaperMainPathOramEndToEndBoundary bundle assumptions := by
  exact ⟨assurance.paperTheoremBoundary, assurance.runtimeKernelBoundary⟩

theorem PaperMainPathOramSlotAssurance.standardPaperMainBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (assurance : PaperMainPathOramSlotAssurance bundle assumptions) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions.backend
    bundle.publicView
    bundle.toSeededRuntimePathOramProofBundle.storageRun
    bundle.publicOutcome
    bundle.boundarySchedule := by
  exact
    assurance.backendRealization.standardPaperMainBoundary
      bundle.publicOutcomeSafe
      bundle.boundarySafe

theorem PaperMainPathOramSlotAssurance.paperTheoremBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (_assurance : PaperMainPathOramSlotAssurance bundle assumptions) :
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions.backend := by
  exact bundle.pathOramLocalPosmapV1_paperTheoremBoundary assumptions.backend

theorem PaperMainPathOramSlotAssurance.endToEndBoundary
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (assurance : PaperMainPathOramSlotAssurance bundle assumptions) :
  PaperMainPathOramSlotEndToEndBoundary bundle assumptions := by
  exact ⟨assurance.paperTheoremBoundary, assurance.runtimeKernelSlotBoundary⟩

def PaperMainPathOramSlotAssurance.toPaperMainPathOramAssurance
  {modelTags : SGXModelTags}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {assumptions : PaperMainPathOramSlotAssumptions bundle}
  (assurance : PaperMainPathOramSlotAssurance bundle assumptions) :
  PaperMainPathOramAssurance
    bundle
    assumptions.toPaperMainPathOramAssumptions :=
  { backendRealization := assurance.backendRealization
  , runtimeKernelBoundary := assumptions.toPaperMainPathOramAssumptions.runtimeKernelBoundary
  }

/-- Preferred paper-main theorem source: a literature-faithful Path ORAM
theorem fixed directly at the runtime-facing public observer and theorem-side
leaf schedule. This is the route the paper should cite or import. -/
abbrev PaperMainPathOramTheoremSourceAt
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (leafRun : OramConfig → Distribution PathOramLeafScheduleTrace) :=
  PathOramJACMLiteratureTheoremAt assumptions publicPart leafRun

/-- Appendix / executable-artifact theorem source. This stays at exactly the
same theorem interface as the paper-main route, but is self-instantiated from
the checked runtime witness family plus the explicit stash assumption so the
artifact can validate the bridge end to end today. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_artifactAppendixTheoremSource
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun :=
  bundle.pathOramLocalPosmapV1_jacmLiteratureTheoremAt assumptions hStash

/-- Paper-main imported-storage theorem: take an external or cited
literature-faithful theorem object at the frozen paper interface and lift it
through the already mechanized runtime storage envelope. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainImportedStorageTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun) :
  ImportedPathOramStorageTheorem assumptions :=
  bundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACMAt assumptions paper

/-- Paper-main standard-theorem realization: this is the named bridge object
the paper should use once the external theorem source is supplied at the frozen
interface. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (paper : PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  bundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACMAt assumptions paper

/-- Appendix / executable-artifact imported-storage theorem. This keeps the
same theorem interface as the paper-main route but closes it using the current
self-instantiated theorem source. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_artifactAppendixImportedStorageTheorem
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  ImportedPathOramStorageTheorem assumptions :=
  bundle.pathOramLocalPosmapV1_paperMainImportedStorageTheorem
    assumptions
    (bundle.pathOramLocalPosmapV1_artifactAppendixTheoremSource assumptions hStash)

/-- Appendix / executable-artifact standard-theorem realization. This is the
artifact-side cross-check route corresponding to the paper-main theorem source,
but closed internally from the seeded runtime family. -/
noncomputable def SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (hStash : assumptions.stashOverflowBounded) :
  PathOramLocalPosmapV1StandardTheoremRealization bundle assumptions :=
  bundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
    assumptions
    (bundle.pathOramLocalPosmapV1_artifactAppendixTheoremSource assumptions hStash)

/-- Paper-facing assurance object for the concrete `path_oram_local_posmap_v1`
route. The backend theorem source is supplied explicitly at the frozen paper
interface, and the remaining runtime/kernel trust point is packaged as the
separate runtime assumption bundle. -/
noncomputable def SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainAssurance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramAssumptions bundle)
  (paper :
    PaperMainPathOramTheoremSourceAt
      assumptions.backend
      bundle.publicView
      bundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramAssurance bundle assumptions :=
  { backendRealization :=
      SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
        bundle.toSeededRuntimePathOramProofBundle
        assumptions.backend
        paper
  , runtimeKernelBoundary := assumptions.runtimeKernelBoundary
  }

/-- Stronger paper-facing assurance bridge that keeps the shared slot-DSL
runtime boundary in the final theorem-facing object. -/
noncomputable def SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainSlotAssurance
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PaperMainPathOramSlotAssumptions bundle)
  (paper :
    PaperMainPathOramTheoremSourceAt
      assumptions.backend
      bundle.publicView
      bundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramSlotAssurance bundle assumptions :=
  { backendRealization :=
      SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_paperMainStandardTheoremRealization
        bundle.toSeededRuntimePathOramProofBundle
        assumptions.backend
        paper
  , runtimeKernelSlotBoundary := assumptions.runtimeKernelSlotBoundary
  }

noncomputable def ProofGradeSeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainAssurance
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions)
  (paper :
    PaperMainPathOramTheoremSourceAt
      backend
      bundle.publicView
      bundle.toSeededRuntimePaperMainBundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramAssumptions backend) :=
  SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramAssumptions backend)
    paper

noncomputable def ProofGradeSeededRuntimePaperMainSlotBundle.pathOramLocalPosmapV1_paperMainSlotAssurance
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions)
  (paper :
    PaperMainPathOramTheoremSourceAt
      backend
      bundle.publicView
      bundle.toSeededRuntimePaperMainBundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramSlotAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramSlotAssumptions backend) :=
  SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainSlotAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramSlotAssumptions backend)
    paper

noncomputable def ProofGradeSeededRuntimePaperMainSlotBundle.pathOramLocalPosmapV1_paperMainAssurance
  {modelTags : SGXModelTags}
  (bundle : ProofGradeSeededRuntimePaperMainSlotBundle modelTags)
  (backend : PathOramLocalPosmapV1SecurityAssumptions)
  (paper :
    PaperMainPathOramTheoremSourceAt
      backend
      bundle.publicView
      bundle.toSeededRuntimePaperMainBundle.toSeededRuntimePathOramProofBundle.leafRun) :
  PaperMainPathOramAssurance
    bundle.toSeededRuntimePaperMainBundle
    (bundle.paperMainPathOramAssumptions backend) :=
  (bundle.pathOramLocalPosmapV1_paperMainSlotAssurance backend paper).toPaperMainPathOramAssurance

end UOToolchain
