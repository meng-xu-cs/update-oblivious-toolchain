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

/--
Stronger slot-lowered confidential-core assurance that packages the explicit
runtime kernel-interface bundle together with the same fixed slot program. This
is the proof interface that matches the shared-slot paper route directly.
-/
def RuntimeConfidentialCoreKernelInterfaceSlotAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags) : Prop :=
  runtimeWitness.ProofGradeValid modelTags ∧
    program.RuntimeNormalForm ∧
    ∃ kernelInterfaceBundle,
      runtimeWitness.kernelInterfaceBundle? = some kernelInterfaceBundle ∧
        kernelInterfaceBundle.Valid ∧
        kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
          some program.expectedRuntimeKernelSteps ∧
        kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
          program.expectedRuntimeKernelSteps

theorem runtimeConfidentialCoreKernelInterfaceSlotAssurance_of_slotAssurance
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured : RuntimeConfidentialCoreSlotAssurance runtimeWitness program modelTags) :
  RuntimeConfidentialCoreKernelInterfaceSlotAssurance runtimeWitness program modelTags := by
  rcases hAssured with
    ⟨hRuntimeValid, hRuntimeNormalForm, kernelWitness, hKernel, hExpectedSteps, hKernelSteps⟩
  rcases runtimeWitness_proofGradeKernelInterfaceBundle_valid
      runtimeWitness
      modelTags
      hRuntimeValid with
    ⟨kernelInterfaceBundle, hBundle, hBundleValid⟩
  have hBundleExact := runtimeRefinementWitness_kernelInterfaceBundle_exact hBundle
  have hShellExact := runtimeRefinementWitness_shellBoundaryBundle_exact hBundleExact.1
  have hKernelEq :
      kernelWitness = kernelInterfaceBundle.shellBoundaryBundle.kernelWitness := by
    apply Option.some.inj
    exact hKernel.symm.trans hShellExact.1
  subst kernelWitness
  exact
    ⟨hRuntimeValid, hRuntimeNormalForm, kernelInterfaceBundle, hBundle, hBundleValid,
      hExpectedSteps, hKernelSteps⟩

/--
Witness-free shared slot-kernel interface boundary: one valid explicit
runtime-kernel interface bundle together with the fixed confidential slot
program whose expected/emitted steps match that bundle exactly. This is the
small common theorem object where the witness-facing route, the smaller
finish-boundary route, and the paper-facing shared-slot route can all meet.
-/
structure RuntimeKernelInterfaceSlotBoundary where
  kernelInterfaceBundle : RuntimeKernelInterfaceBundle
  confidentialSlotProgram : ConfidentialKernelSlotProgram
  kernelInterfaceValid : kernelInterfaceBundle.Valid
  expectedKernelStepsExact :
    kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some confidentialSlotProgram.expectedRuntimeKernelSteps
  emittedKernelStepsExact :
    kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      confidentialSlotProgram.expectedRuntimeKernelSteps

noncomputable def RuntimeKernelInterfaceSlotBoundary.refinementBoundary
  (boundary : RuntimeKernelInterfaceSlotBoundary) : RuntimeKernelRefinementBoundary :=
  boundary.kernelInterfaceBundle.refinementBoundary boundary.kernelInterfaceValid

theorem RuntimeKernelInterfaceSlotBoundary.toRefinesLeanKernelState
  (boundary : RuntimeKernelInterfaceSlotBoundary) :
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.refinementBoundary.kernelWitness := by
  simpa [RuntimeKernelInterfaceSlotBoundary.refinementBoundary] using
    (runtimeKernelInterfaceBundle_valid_projects_to_runtimeKernelRefinementBoundary
      boundary.kernelInterfaceValid)

theorem RuntimeKernelInterfaceSlotBoundary.shellBoundaryBundle_valid
  (boundary : RuntimeKernelInterfaceSlotBoundary) :
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid := by
  exact boundary.kernelInterfaceValid.1

noncomputable def RuntimeKernelInterfaceSlotBoundary.confinementBoundary
  (boundary : RuntimeKernelInterfaceSlotBoundary) : RuntimeKernelConfinementBoundary :=
  boundary.kernelInterfaceBundle.confinementBoundary boundary.kernelInterfaceValid

theorem RuntimeKernelInterfaceSlotBoundary.projects_to_runtimeKernelConfinementBoundary
  (boundary : RuntimeKernelInterfaceSlotBoundary) :
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  simpa [RuntimeKernelInterfaceSlotBoundary.confinementBoundary] using
    (runtimeKernelInterfaceBundle_valid_projects_to_runtimeKernelConfinementBoundary
      boundary.kernelInterfaceValid)

noncomputable def runtimeConfidentialCoreKernelInterfaceSlotAssurance_projects_to_runtimeKernelInterfaceSlotBoundary
  (runtimeWitness : RuntimeRefinementWitness)
  (program : ConfidentialKernelSlotProgram)
  (modelTags : SGXModelTags)
  (hAssured :
    RuntimeConfidentialCoreKernelInterfaceSlotAssurance
      runtimeWitness
      program
      modelTags) :
  RuntimeKernelInterfaceSlotBoundary := by
  let hBundleExists :
      ∃ kernelInterfaceBundle,
        runtimeWitness.kernelInterfaceBundle? = some kernelInterfaceBundle ∧
          kernelInterfaceBundle.Valid ∧
          kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
            some program.expectedRuntimeKernelSteps ∧
          kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
            program.expectedRuntimeKernelSteps := hAssured.2.2
  let kernelInterfaceBundle := Classical.choose hBundleExists
  have hBundleSpec := Classical.choose_spec hBundleExists
  exact
    { kernelInterfaceBundle := kernelInterfaceBundle
    , confidentialSlotProgram := program
    , kernelInterfaceValid := hBundleSpec.2.1
    , expectedKernelStepsExact := hBundleSpec.2.2.1
    , emittedKernelStepsExact := hBundleSpec.2.2.2
    }

/--
Kernel-local theorem object for the stronger pre-witness runtime boundary:
one exact finished Lean kernel-refinement boundary together with the fixed slot
program that the concrete runtime is supposed to execute.
-/
structure RuntimeKernelFinishSlotBoundary where
  runtimeKernelBoundary : RuntimeKernelRefinementBoundary
  confidentialSlotProgram : ConfidentialKernelSlotProgram
  runtimeNormalForm : confidentialSlotProgram.RuntimeNormalForm
  expectedKernelStepsExact :
    runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some confidentialSlotProgram.expectedRuntimeKernelSteps
  emittedKernelStepsExact :
    runtimeKernelBoundary.kernelWitness.kernelSteps =
      confidentialSlotProgram.expectedRuntimeKernelSteps

theorem RuntimeKernelFinishSlotBoundary.toRefinesLeanKernelState
  (boundary : RuntimeKernelFinishSlotBoundary) :
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness := by
  exact RuntimeKernelRefinementBoundary.toRefinesLeanKernelState
    boundary.runtimeKernelBoundary

noncomputable def RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle
  (boundary : RuntimeKernelFinishSlotBoundary) : RuntimeKernelInterfaceBundle :=
  let expectedPublicObjectIds :=
    Classical.choose
      (runtimeKernelWitness_proofGradePublicObjectUniverse_exact
        boundary.runtimeKernelBoundary.kernelWitnessProofGrade)
  { shellBoundaryBundle :=
      { kernelWitness := boundary.runtimeKernelBoundary.kernelWitness
      , runtimeKernelRefinementWitness :=
          boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      , shellContract := boundary.runtimeKernelBoundary.kernelWitness.shellContract
      , shellTrace := boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.shellTrace
      }
  , expectedKernelSteps := boundary.confidentialSlotProgram.expectedRuntimeKernelSteps
  , expectedPublicObjectIds := expectedPublicObjectIds
  , expectedKernelSchedule := boundary.runtimeKernelBoundary.expectedKernelSchedule
  }

theorem RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle_valid
  (boundary : RuntimeKernelFinishSlotBoundary) :
  boundary.kernelInterfaceBundle.Valid := by
  let hPublicExact :=
    Classical.choose_spec
      (runtimeKernelWitness_proofGradePublicObjectUniverse_exact
        boundary.runtimeKernelBoundary.kernelWitnessProofGrade)
  refine
    ⟨?_, boundary.toRefinesLeanKernelState, boundary.expectedKernelStepsExact,
      boundary.emittedKernelStepsExact, ?_, ?_,
      boundary.runtimeKernelBoundary.resourceStateExact,
      boundary.runtimeKernelBoundary.expectedKernelScheduleExact,
      boundary.runtimeKernelBoundary.emittedKernelScheduleExact,
      boundary.runtimeKernelBoundary.finalKernelScheduleStateExact⟩
  · refine ⟨boundary.runtimeKernelBoundary.kernelWitnessProofGrade,
      boundary.runtimeKernelBoundary.refinementValid, rfl, rfl, ?_⟩
    exact runtimeKernelRefinementWitness_valid_proofGradeRefinesShellContract
      boundary.runtimeKernelBoundary.refinementValid
  · exact hPublicExact.1
  · exact hPublicExact.2

theorem RuntimeKernelFinishSlotBoundary.shellBoundaryBundle_valid
  (boundary : RuntimeKernelFinishSlotBoundary) :
  boundary.kernelInterfaceBundle.shellBoundaryBundle.Valid := by
  exact boundary.kernelInterfaceBundle_valid.1

noncomputable def RuntimeKernelFinishSlotBoundary.confinementBoundary
  (boundary : RuntimeKernelFinishSlotBoundary) : RuntimeKernelConfinementBoundary :=
  boundary.kernelInterfaceBundle.confinementBoundary
    boundary.kernelInterfaceBundle_valid

theorem RuntimeKernelFinishSlotBoundary.projects_to_runtimeKernelConfinementBoundary
  (boundary : RuntimeKernelFinishSlotBoundary) :
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    runtimeKernelInterfaceBundle_valid_projects_to_runtimeKernelConfinementBoundary
      boundary.kernelInterfaceBundle_valid

noncomputable def RuntimeKernelFinishSlotBoundary.runtimeKernelInterfaceSlotBoundary
  (boundary : RuntimeKernelFinishSlotBoundary) : RuntimeKernelInterfaceSlotBoundary :=
  { kernelInterfaceBundle := boundary.kernelInterfaceBundle
  , confidentialSlotProgram := boundary.confidentialSlotProgram
  , kernelInterfaceValid := boundary.kernelInterfaceBundle_valid
  , expectedKernelStepsExact := by
      simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
        boundary.expectedKernelStepsExact
  , emittedKernelStepsExact := by
      simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
        boundary.emittedKernelStepsExact
  }

/--
Native theorem object for the closer-to-implementation machine-finish route:
one exact finished kernel-finish-slot boundary plus the extra live
`RuntimeKernelMachine` bookkeeping facts that are checked before the runtime
flattens that machine state to the smaller finish bundle.
-/
structure RuntimeKernelMachineFinishBoundary where
  runtimeKernelFinishSlotBoundary : RuntimeKernelFinishSlotBoundary
  expectedKernelStepIndex : Nat
  maxKernelOps : Nat
  maxRuntimePhaseEventCount : Nat
  expectedKernelScheduleConsumed :
    match runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
    | some steps => expectedKernelStepIndex = steps.length
    | none => expectedKernelStepIndex = 0
  kernelStepBudgetRespected :
    runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      maxKernelOps
  runtimePhaseEventCapacityMatches :
    maxRuntimePhaseEventCount =
      runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.publicObjectIds.length * 5
        + maxKernelOps
  runtimePhaseEventCapacityRespected :
    runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length
      ≤ maxRuntimePhaseEventCount

theorem RuntimeKernelMachineFinishBoundary.toRefinesLeanKernelState
  (boundary : RuntimeKernelMachineFinishBoundary) :
  boundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact RuntimeKernelFinishSlotBoundary.toRefinesLeanKernelState
    boundary.runtimeKernelFinishSlotBoundary

noncomputable def RuntimeKernelMachineFinishBoundary.runtimeKernelInterfaceSlotBoundary
  (boundary : RuntimeKernelMachineFinishBoundary) : RuntimeKernelInterfaceSlotBoundary :=
  boundary.runtimeKernelFinishSlotBoundary.runtimeKernelInterfaceSlotBoundary

theorem RuntimeKernelMachineFinishBoundary.projects_to_runtimeKernelConfinementBoundary
  (boundary : RuntimeKernelMachineFinishBoundary) :
  let runtimeBoundary :=
    boundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  runtimeBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.refinementBoundary.kernelWitness ∧
    runtimeBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact RuntimeKernelFinishSlotBoundary.projects_to_runtimeKernelConfinementBoundary
    boundary.runtimeKernelFinishSlotBoundary

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

structure RuntimeConfidentialCoreKernelInterfaceSlotBundle where
  runtimeWitness : RuntimeRefinementWitness
  kernelInterfaceBundle : RuntimeKernelInterfaceBundle
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

def RuntimeConfidentialCoreKernelInterfaceSlotBundle.Valid
  (bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  RuntimeConfidentialCoreSlotBundle.Valid
      { runtimeWitness := bundle.runtimeWitness
      , confidentialProgram := bundle.confidentialSlotProgram
      } modelTags ∧
    bundle.kernelInterfaceBundle.Valid ∧
    bundle.runtimeWitness.kernelInterfaceBundle? = some bundle.kernelInterfaceBundle

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

theorem runtimeConfidentialCoreKernelInterfaceSlotBundle_proofGradeAssurance
  (bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.runtimeWitness.kernelInterfaceBundle? = some bundle.kernelInterfaceBundle ∧
    bundle.kernelInterfaceBundle.Valid ∧
    bundle.kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  rcases hValid with ⟨hCoreValid, hInterfaceValid, hBundleExact⟩
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
  have hInterfaceExact := runtimeRefinementWitness_kernelInterfaceBundle_exact hBundleExact
  have hShellExact := runtimeRefinementWitness_shellBoundaryBundle_exact hInterfaceExact.1
  rcases hCore with
    ⟨kernelWitness, _runtimeKernelRefinementWitness, hRuntimeKernel, hRuntimeExpected,
      hRuntimeSteps, _hRuntimeRefinement, _hRuntimeShellRefines⟩
  have hKernelEq :
      kernelWitness = bundle.kernelInterfaceBundle.shellBoundaryBundle.kernelWitness := by
    apply Option.some.inj
    exact hRuntimeKernel.symm.trans hShellExact.1
  subst hKernelEq
  exact ⟨hBundleExact, hInterfaceValid, hRuntimeExpected, hRuntimeSteps⟩

/--
Exact native midpoint where the stronger runtime-witness/kernel-interface/slot
bundle is collapsed back down to the smaller finish-slot theorem object. This
lets the larger witness-facing route and the smaller pre-witness finish route
meet on one shared exact boundary rather than only agreeing indirectly on
schedule facts.
-/
noncomputable def RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelFinishSlotBoundary
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelFinishSlotBoundary := by
  classical
  have hProofGrade :=
    runtimeConfidentialCoreKernelInterfaceSlotBundle_proofGradeAssurance
      bundle
      modelTags
      hValid
  rcases hValid with ⟨hCoreValid, hInterfaceValid, _hBundleExact⟩
  rcases hInterfaceValid with
    ⟨hShellValid, hKernelStateRefinement, _hExpectedKernelSteps, _hKernelSteps,
      _hExpectedPublicObjectIds, _hPublicObjectIds, hResourceState,
      hExpectedKernelSchedule, hEmittedKernelSchedule, hFinalKernelScheduleState⟩
  rcases hShellValid with
    ⟨hKernelWitnessProofGrade, hRefinementValid, _hShellContractExact, _hShellTraceExact,
      _hShellProofGrade⟩
  let expectedKernelSchedule := Classical.choose hKernelStateRefinement
  have hKernelStateRefinementSpec := Classical.choose_spec hKernelStateRefinement
  rcases hKernelStateRefinementSpec with
    ⟨_hKernelWitnessProofGradeFromRefinement, _hRefinementValidFromRefinement,
      _hResourceStateFromRefinement, hExpectedKernelScheduleFromRefinement,
      _hEmittedKernelScheduleFromRefinement, _hFinalKernelScheduleStateFromRefinement,
      hProjectedKernelSchedule, hPreCommittedColdObjectSchedule,
      hPostCommittedColdObjectSchedule, hShadowLoadObjectSchedule,
      hCommitObjectSchedule, hColdStoreObjectSchedule⟩
  have hExpectedKernelScheduleEq :
      expectedKernelSchedule = bundle.kernelInterfaceBundle.expectedKernelSchedule := by
    apply Option.some.inj
    calc
      some expectedKernelSchedule =
          bundle.kernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSchedule? := by
            simpa using hExpectedKernelScheduleFromRefinement.symm
      _ = some bundle.kernelInterfaceBundle.expectedKernelSchedule := hExpectedKernelSchedule
  subst expectedKernelSchedule
  exact
    { runtimeKernelBoundary :=
        { kernelWitness := bundle.kernelInterfaceBundle.shellBoundaryBundle.kernelWitness
        , runtimeKernelRefinementWitness :=
            bundle.kernelInterfaceBundle.shellBoundaryBundle.runtimeKernelRefinementWitness
        , expectedKernelSchedule := bundle.kernelInterfaceBundle.expectedKernelSchedule
        , kernelWitnessProofGrade := hKernelWitnessProofGrade
        , refinementValid := hRefinementValid
        , resourceStateExact := hResourceState
        , expectedKernelScheduleExact := hExpectedKernelSchedule
        , emittedKernelScheduleExact := hEmittedKernelSchedule
        , finalKernelScheduleStateExact := hFinalKernelScheduleState
        , projectedKernelScheduleExact := hProjectedKernelSchedule
        , preCommittedColdObjectScheduleExact := hPreCommittedColdObjectSchedule
        , postCommittedColdObjectScheduleExact := hPostCommittedColdObjectSchedule
        , shadowLoadObjectScheduleExact := hShadowLoadObjectSchedule
        , commitObjectScheduleExact := hCommitObjectSchedule
        , coldStoreObjectScheduleExact := hColdStoreObjectSchedule
        }
    , confidentialSlotProgram := bundle.confidentialSlotProgram
    , runtimeNormalForm := hCoreValid.2.1
    , expectedKernelStepsExact := hProofGrade.2.2.1
    , emittedKernelStepsExact := hProofGrade.2.2.2
    }

theorem
  RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelFinishSlotBoundary_refinesLeanKernelState
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.runtimeKernelFinishSlotBoundary hValid
  boundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    boundary.runtimeKernelBoundary.kernelWitness := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.toRefinesLeanKernelState boundary

theorem
  RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelFinishSlotBoundary_kernelInterfaceBundle_valid
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.runtimeKernelFinishSlotBoundary hValid
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid ∧
      runtimeKernelInterfaceBundle.expectedKernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.expectedKernelSteps =
        some boundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeKernelInterfaceBundle.shellBoundaryBundle.kernelWitness.kernelSteps =
        boundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  intro boundary
  refine
    ⟨boundary.kernelInterfaceBundle, boundary.kernelInterfaceBundle_valid, ?_, ?_, ?_⟩
  · simp [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle]
  · simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
      boundary.expectedKernelStepsExact
  · simpa [RuntimeKernelFinishSlotBoundary.kernelInterfaceBundle] using
      boundary.emittedKernelStepsExact

theorem
  RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelFinishSlotBoundary_projects_to_runtimeKernelConfinementBoundary
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.runtimeKernelFinishSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelFinishSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

noncomputable def RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelInterfaceSlotBoundary
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) : RuntimeKernelInterfaceSlotBoundary := by
  have hAssurance :
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
    runtimeConfidentialCoreKernelInterfaceSlotAssurance_projects_to_runtimeKernelInterfaceSlotBoundary
      bundle.runtimeWitness
      bundle.confidentialSlotProgram
      modelTags
      hAssurance

theorem
  RuntimeConfidentialCoreKernelInterfaceSlotBundle.runtimeKernelInterfaceSlotBoundary_projects_to_runtimeKernelConfinementBoundary
  {bundle : RuntimeConfidentialCoreKernelInterfaceSlotBundle}
  {modelTags : SGXModelTags}
  (hValid : bundle.Valid modelTags) :
  let boundary := bundle.runtimeKernelInterfaceSlotBoundary hValid
  boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.confinementBoundary.refinementBoundary.kernelWitness ∧
    boundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  intro boundary
  exact RuntimeKernelInterfaceSlotBoundary.projects_to_runtimeKernelConfinementBoundary boundary

end UOToolchain
