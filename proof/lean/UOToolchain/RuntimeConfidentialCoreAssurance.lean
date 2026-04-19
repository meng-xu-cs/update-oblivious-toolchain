import UOToolchain.ConfidentialKernelDsl
import UOToolchain.RuntimeShellBoundary

namespace UOToolchain

/--
Proof-grade runtime assurance for the confidential core now uses the exact
small-kernel schedule derived from the shared confidential DSL object, not only
the coarser fragment summary. The concrete runtime witness must satisfy the
proof-grade shell/kernel bridge, and its embedded kernel witness must agree
exactly with the schedule extracted from that frozen confidential program
object.
-/
def RuntimeConfidentialCoreAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelProgram)
  (modelTags : SGXModelTags) : Prop :=
  runtimeWitness.ProofGradeValid modelTags ∧
    ∃ kernelWitness,
      runtimeWitness.kernelWitness = some kernelWitness ∧
        kernelWitness.expectedKernelSteps = some program.expectedRuntimeKernelSteps ∧
        kernelWitness.kernelSteps = program.expectedRuntimeKernelSteps

theorem runtimeWitness_proofGradeConfidentialCoreAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelProgram)
  (modelTags : SGXModelTags)
  (hAssured : RuntimeConfidentialCoreAssurance runtimeWitness program modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    runtimeWitness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps = some program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = program.expectedRuntimeKernelSteps ∧
      runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract := by
  rcases hAssured with ⟨hRuntimeValid, kernelWitness, hKernel, hExpectedSteps, hKernelSteps⟩
  rcases runtimeWitness_proofGradeKernelInterface runtimeWitness modelTags hRuntimeValid with
    ⟨shellBoundaryBundle, _expectedKernelSteps, _expectedPublicObjectIds,
      _expectedKernelSchedule, hBundle, hBundleValid, _hShellProofGradeRefinement,
      _hKernelStateRefinement, _hWitnessExpectedSteps, _hWitnessKernelSteps,
      _hExpectedPublicObjectIds, _hPublicObjectIds, _hResourceState,
      _hExpectedKernelSchedule, _hEmittedKernelSchedule, _hFinalKernelScheduleState⟩
  have hBundleExact := runtimeRefinementWitness_shellBoundaryBundle_exact hBundle
  have hKernelEq : kernelWitness = shellBoundaryBundle.kernelWitness := by
    apply Option.some.inj
    exact hKernel.symm.trans hBundleExact.1
  subst kernelWitness
  exact
    ⟨shellBoundaryBundle.kernelWitness, shellBoundaryBundle.runtimeKernelRefinementWitness,
      hBundleExact.1, hExpectedSteps, hKernelSteps, hBundleExact.2.1,
      runtimeShellBoundaryBundle_witness_proofGradeRefines hBundleValid⟩

/--
Slot-lowered variant of the confidential-core theorem surface. This is the
same proof-grade runtime/refinement guarantee, but tied directly to the fixed
slot program that the concrete runtime executes.
-/
def RuntimeConfidentialCoreSlotAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags) : Prop :=
  runtimeWitness.ProofGradeValid modelTags ∧
    program.RuntimeNormalForm ∧
    ∃ kernelWitness,
      runtimeWitness.kernelWitness = some kernelWitness ∧
        kernelWitness.expectedKernelSteps = some program.expectedRuntimeKernelSteps ∧
        kernelWitness.kernelSteps = program.expectedRuntimeKernelSteps

theorem runtimeWitness_proofGradeConfidentialCoreSlotAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured : RuntimeConfidentialCoreSlotAssurance runtimeWitness program modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    runtimeWitness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps = some program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = program.expectedRuntimeKernelSteps ∧
      runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract := by
  rcases hAssured with
    ⟨hRuntimeValid, _hRuntimeNormalForm, kernelWitness, hKernel, hExpectedSteps, hKernelSteps⟩
  rcases runtimeWitness_proofGradeKernelInterface runtimeWitness modelTags hRuntimeValid with
    ⟨shellBoundaryBundle, _expectedKernelSteps, _expectedPublicObjectIds,
      _expectedKernelSchedule, hBundle, hBundleValid, _hShellProofGradeRefinement,
      _hKernelStateRefinement, _hWitnessExpectedSteps, _hWitnessKernelSteps,
      _hExpectedPublicObjectIds, _hPublicObjectIds, _hResourceState,
      _hExpectedKernelSchedule, _hEmittedKernelSchedule, _hFinalKernelScheduleState⟩
  have hBundleExact := runtimeRefinementWitness_shellBoundaryBundle_exact hBundle
  have hKernelEq : kernelWitness = shellBoundaryBundle.kernelWitness := by
    apply Option.some.inj
    exact hKernel.symm.trans hBundleExact.1
  subst kernelWitness
  exact
    ⟨shellBoundaryBundle.kernelWitness, shellBoundaryBundle.runtimeKernelRefinementWitness,
      hBundleExact.1, hExpectedSteps, hKernelSteps, hBundleExact.2.1,
      runtimeShellBoundaryBundle_witness_proofGradeRefines hBundleValid⟩

theorem runtimeConfidentialCoreAssurance_slotAssurance_of_lowering
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelProgram)
  (slotProgram : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured : RuntimeConfidentialCoreAssurance runtimeWitness program modelTags)
  (hLowering : program.SlotLoweringMatches slotProgram) :
  RuntimeConfidentialCoreSlotAssurance runtimeWitness slotProgram modelTags := by
  rcases hAssured with ⟨hRuntimeValid, kernelWitness, hKernel, hExpectedSteps, hKernelSteps⟩
  have hStepEq :
      program.expectedRuntimeKernelSteps = slotProgram.expectedRuntimeKernelSteps := by
    exact confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps hLowering
  refine ⟨hRuntimeValid, confidentialKernelProgram_slotLowering_runtimeNormalForm hLowering,
    kernelWitness, hKernel, ?_, ?_⟩
  · simpa [hStepEq] using hExpectedSteps
  · simpa [hStepEq] using hKernelSteps

/--
Combined proof-grade runtime assurance for the shared named/slot confidential
DSL bridge. The same proof-grade runtime/refinement witness must agree with the
source-named DSL object and the named-to-slot lowering relation. Agreement with
the fixed-slot executable schedule is derived from that lowering witness.
-/
def RuntimeConfidentialCoreLoweringAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelProgram)
  (slotProgram : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreAssurance runtimeWitness program modelTags ∧
    program.SlotLoweringMatches slotProgram

theorem runtimeWitness_proofGradeConfidentialCoreLoweringAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelProgram)
  (slotProgram : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured : RuntimeConfidentialCoreLoweringAssurance
    runtimeWitness program slotProgram modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    runtimeWitness.kernelWitness = some kernelWitness ∧
      runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      kernelWitness.expectedKernelSteps = some program.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = program.expectedRuntimeKernelSteps ∧
      kernelWitness.expectedKernelSteps = some slotProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = slotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract ∧
      program.SlotLoweringMatches slotProgram := by
  rcases hAssured with ⟨hNamedAssured, hLowering⟩
  rcases runtimeWitness_proofGradeConfidentialCoreAssurance
      runtimeWitness program modelTags hNamedAssured with
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel, hNamedExpected, hNamedSteps,
      hRefinement, hShellRefines⟩
  have hStepEq :
      program.expectedRuntimeKernelSteps = slotProgram.expectedRuntimeKernelSteps := by
    exact confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps hLowering
  have hSlotExpected :
      kernelWitness.expectedKernelSteps = some slotProgram.expectedRuntimeKernelSteps := by
    simpa [hStepEq] using hNamedExpected
  have hSlotSteps :
      kernelWitness.kernelSteps = slotProgram.expectedRuntimeKernelSteps := by
    simpa [hStepEq] using hNamedSteps
  exact
    ⟨kernelWitness, runtimeKernelRefinementWitness, hKernel, hRefinement, hNamedExpected,
      hNamedSteps, hSlotExpected, hSlotSteps, hShellRefines, hLowering⟩

structure RuntimeConfidentialCoreBundle where
  runtimeWitness : RuntimeRefinementWitness
  confidentialProgram : ConfidentialKernelProgram

def RuntimeConfidentialCoreBundle.Valid
  (bundle : RuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreAssurance bundle.runtimeWitness bundle.confidentialProgram modelTags

theorem runtimeConfidentialCoreBundle_proofGradeAssurance
  (bundle : RuntimeConfidentialCoreBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtimeWitness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps = some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
      bundle.runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract := by
  exact runtimeWitness_proofGradeConfidentialCoreAssurance
    bundle.runtimeWitness bundle.confidentialProgram modelTags hValid

structure RuntimeConfidentialCoreSlotBundle where
  runtimeWitness : RuntimeRefinementWitness
  confidentialProgram : ConfidentialKernelSlotProgram

def RuntimeConfidentialCoreSlotBundle.Valid
  (bundle : RuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreSlotAssurance bundle.runtimeWitness bundle.confidentialProgram modelTags

theorem runtimeConfidentialCoreSlotBundle_proofGradeAssurance
  (bundle : RuntimeConfidentialCoreSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtimeWitness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps = some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
      bundle.runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract := by
  exact runtimeWitness_proofGradeConfidentialCoreSlotAssurance
    bundle.runtimeWitness bundle.confidentialProgram modelTags hValid

structure RuntimeConfidentialCoreLoweringBundle where
  runtimeWitness : RuntimeRefinementWitness
  confidentialProgram : ConfidentialKernelProgram
  confidentialSlotProgram : ConfidentialKernelSlotProgram

def RuntimeConfidentialCoreLoweringBundle.Valid
  (bundle : RuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreLoweringAssurance
    bundle.runtimeWitness bundle.confidentialProgram bundle.confidentialSlotProgram modelTags

theorem runtimeConfidentialCoreLoweringBundle_proofGradeAssurance
  (bundle : RuntimeConfidentialCoreLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    bundle.runtimeWitness.kernelWitness = some kernelWitness ∧
      bundle.runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      kernelWitness.expectedKernelSteps = some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.expectedKernelSteps = some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      kernelWitness.kernelSteps = bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
        kernelWitness.shellContract ∧
      bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram := by
  exact runtimeWitness_proofGradeConfidentialCoreLoweringAssurance
    bundle.runtimeWitness bundle.confidentialProgram bundle.confidentialSlotProgram modelTags hValid

structure RuntimeShellBoundaryLoweringBundle where
  shellBoundaryBundle : RuntimeShellBoundaryBundle
  confidentialProgram : ConfidentialKernelProgram
  confidentialSlotProgram : ConfidentialKernelSlotProgram

structure RuntimeShellBoundarySlotBundle where
  shellBoundaryBundle : RuntimeShellBoundaryBundle
  confidentialSlotProgram : ConfidentialKernelSlotProgram

def RuntimeShellBoundaryLoweringBundle.Valid
  (bundle : RuntimeShellBoundaryLoweringBundle) : Prop :=
  bundle.shellBoundaryBundle.Valid ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram

theorem runtimeShellBoundaryLoweringBundle_proofGradeAssurance
  (bundle : RuntimeShellBoundaryLoweringBundle)
  (hValid : bundle.Valid) :
  bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
      bundle.shellBoundaryBundle.kernelWitness.shellContract ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram := by
  have hStepEq :
      bundle.confidentialProgram.expectedRuntimeKernelSteps =
        bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    exact confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps hValid.2.2.2
  have hSlotExpected :
      bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
        some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    simpa [hStepEq] using hValid.2.1
  have hSlotSteps :
      bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
        bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    simpa [hStepEq] using hValid.2.2.1
  exact
    ⟨runtimeShellBoundaryBundle_witness_proofGradeRefines hValid.1, hValid.2.1, hValid.2.2.1,
      hSlotExpected, hSlotSteps, hValid.2.2.2⟩

def RuntimeShellBoundarySlotBundle.Valid
  (bundle : RuntimeShellBoundarySlotBundle) : Prop :=
  bundle.shellBoundaryBundle.Valid ∧
    bundle.confidentialSlotProgram.RuntimeNormalForm ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps

theorem runtimeShellBoundarySlotBundle_proofGradeAssurance
  (bundle : RuntimeShellBoundarySlotBundle)
  (hValid : bundle.Valid) :
  bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
      bundle.shellBoundaryBundle.kernelWitness.shellContract ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    ⟨runtimeShellBoundaryBundle_witness_proofGradeRefines hValid.1,
      hValid.2.2.1, hValid.2.2.2⟩

structure RuntimeConfidentialCoreShellBoundaryLoweringBundle where
  runtimeWitness : RuntimeRefinementWitness
  shellBoundaryBundle : RuntimeShellBoundaryBundle
  confidentialProgram : ConfidentialKernelProgram
  confidentialSlotProgram : ConfidentialKernelSlotProgram

structure RuntimeConfidentialCoreShellBoundarySlotBundle where
  runtimeWitness : RuntimeRefinementWitness
  shellBoundaryBundle : RuntimeShellBoundaryBundle
  confidentialSlotProgram : ConfidentialKernelSlotProgram

def RuntimeConfidentialCoreShellBoundaryLoweringBundle.Valid
  (bundle : RuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreLoweringBundle.Valid
      { runtimeWitness := bundle.runtimeWitness
      , confidentialProgram := bundle.confidentialProgram
      , confidentialSlotProgram := bundle.confidentialSlotProgram
      } modelTags ∧
    RuntimeShellBoundaryLoweringBundle.Valid
      { shellBoundaryBundle := bundle.shellBoundaryBundle
      , confidentialProgram := bundle.confidentialProgram
      , confidentialSlotProgram := bundle.confidentialSlotProgram
      } ∧
    bundle.runtimeWitness.kernelWitness = some bundle.shellBoundaryBundle.kernelWitness ∧
    bundle.runtimeWitness.runtimeKernelRefinementWitness =
      some bundle.shellBoundaryBundle.runtimeKernelRefinementWitness

def RuntimeConfidentialCoreShellBoundarySlotBundle.Valid
  (bundle : RuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreSlotBundle.Valid
      { runtimeWitness := bundle.runtimeWitness
      , confidentialProgram := bundle.confidentialSlotProgram
      } modelTags ∧
    RuntimeShellBoundarySlotBundle.Valid
      { shellBoundaryBundle := bundle.shellBoundaryBundle
      , confidentialSlotProgram := bundle.confidentialSlotProgram
      } ∧
    bundle.runtimeWitness.kernelWitness = some bundle.shellBoundaryBundle.kernelWitness ∧
    bundle.runtimeWitness.runtimeKernelRefinementWitness =
      some bundle.shellBoundaryBundle.runtimeKernelRefinementWitness

theorem runtimeConfidentialCoreShellBoundaryLoweringBundle_proofGradeAssurance
  (bundle : RuntimeConfidentialCoreShellBoundaryLoweringBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.runtimeWitness.kernelWitness = some bundle.shellBoundaryBundle.kernelWitness ∧
    bundle.runtimeWitness.runtimeKernelRefinementWitness =
      some bundle.shellBoundaryBundle.runtimeKernelRefinementWitness ∧
    bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
      bundle.shellBoundaryBundle.kernelWitness.shellContract ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram := by
  rcases hValid with ⟨hLoweringValid, hShellBoundaryLoweringValid, hKernelExact, hRefinementExact⟩
  have hLowering :
      ∃ kernelWitness runtimeKernelRefinementWitness,
        bundle.runtimeWitness.kernelWitness = some kernelWitness ∧
          bundle.runtimeWitness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
          kernelWitness.expectedKernelSteps = some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
          kernelWitness.kernelSteps = bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
          kernelWitness.expectedKernelSteps = some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
          kernelWitness.kernelSteps = bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
          runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
            kernelWitness.shellContract ∧
          bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram := by
    exact runtimeConfidentialCoreLoweringBundle_proofGradeAssurance
      { runtimeWitness := bundle.runtimeWitness
      , confidentialProgram := bundle.confidentialProgram
      , confidentialSlotProgram := bundle.confidentialSlotProgram
      } modelTags hLoweringValid
  have hShellBoundaryLowering :
      bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
          bundle.shellBoundaryBundle.kernelWitness.shellContract ∧
        bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
        bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
          bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
        bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
        bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
          bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
        bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram := by
    exact runtimeShellBoundaryLoweringBundle_proofGradeAssurance
      { shellBoundaryBundle := bundle.shellBoundaryBundle
      , confidentialProgram := bundle.confidentialProgram
      , confidentialSlotProgram := bundle.confidentialSlotProgram
      } hShellBoundaryLoweringValid
  rcases hLowering with
    ⟨kernelWitness, runtimeKernelRefinementWitness, hRuntimeKernel, hRuntimeRefinement,
      hNamedExpected, hNamedSteps, hSlotExpected, hSlotSteps, hShellRefines, hLoweringMatches⟩
  have hShellKernelEq : kernelWitness = bundle.shellBoundaryBundle.kernelWitness := by
    apply Option.some.inj
    exact hRuntimeKernel.symm.trans hKernelExact
  have hShellRefinementEq :
      runtimeKernelRefinementWitness = bundle.shellBoundaryBundle.runtimeKernelRefinementWitness := by
    apply Option.some.inj
    exact hRuntimeRefinement.symm.trans hRefinementExact
  subst hShellKernelEq
  subst hShellRefinementEq
  exact
    ⟨hKernelExact, hRefinementExact,
      hShellBoundaryLowering.1, hShellBoundaryLowering.2.1, hShellBoundaryLowering.2.2.1,
      hShellBoundaryLowering.2.2.2.1, hShellBoundaryLowering.2.2.2.2.1,
      hShellBoundaryLowering.2.2.2.2.2⟩

theorem runtimeConfidentialCoreShellBoundarySlotBundle_proofGradeAssurance
  (bundle : RuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.runtimeWitness.kernelWitness = some bundle.shellBoundaryBundle.kernelWitness ∧
    bundle.runtimeWitness.runtimeKernelRefinementWitness =
      some bundle.shellBoundaryBundle.runtimeKernelRefinementWitness ∧
    bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
      bundle.shellBoundaryBundle.kernelWitness.shellContract ∧
    bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  rcases hValid with ⟨hCoreValid, hShellSlotValid, hKernelExact, hRefinementExact⟩
  have hCore :
      ∃ kernelWitness runtimeKernelRefinementWitness,
        bundle.runtimeWitness.kernelWitness = some kernelWitness ∧
          kernelWitness.expectedKernelSteps =
            some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
          kernelWitness.kernelSteps = bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
          bundle.runtimeWitness.runtimeKernelRefinementWitness =
            some runtimeKernelRefinementWitness ∧
          runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
            kernelWitness.shellContract := by
    exact runtimeConfidentialCoreSlotBundle_proofGradeAssurance
      { runtimeWitness := bundle.runtimeWitness
      , confidentialProgram := bundle.confidentialSlotProgram
      } modelTags hCoreValid
  have hShell :
      bundle.shellBoundaryBundle.runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines
          bundle.shellBoundaryBundle.kernelWitness.shellContract ∧
        bundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
        bundle.shellBoundaryBundle.kernelWitness.kernelSteps =
          bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    exact runtimeShellBoundarySlotBundle_proofGradeAssurance
      { shellBoundaryBundle := bundle.shellBoundaryBundle
      , confidentialSlotProgram := bundle.confidentialSlotProgram
      } hShellSlotValid
  rcases hCore with
    ⟨kernelWitness, runtimeKernelRefinementWitness, hRuntimeKernel, hRuntimeExpected,
      hRuntimeSteps, hRuntimeRefinement, _hCoreShellRefines⟩
  have hShellKernelEq : kernelWitness = bundle.shellBoundaryBundle.kernelWitness := by
    apply Option.some.inj
    exact hRuntimeKernel.symm.trans hKernelExact
  have hShellRefinementEq :
      runtimeKernelRefinementWitness = bundle.shellBoundaryBundle.runtimeKernelRefinementWitness := by
    apply Option.some.inj
    exact hRuntimeRefinement.symm.trans hRefinementExact
  subst hShellKernelEq
  subst hShellRefinementEq
  exact ⟨hKernelExact, hRefinementExact, hShell.1, hRuntimeExpected, hRuntimeSteps⟩

end UOToolchain
