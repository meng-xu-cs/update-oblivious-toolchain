import UOToolchain.KernelAdmission
import UOToolchain.PathOramAdmitted

/-!
# The Path ORAM paper-main theorems for admitted kernel programs

`paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on` and its
private-scheme counterpart take four premises beside the ORAM one: on admitted
pairs, the public outcome, the enclave-boundary schedule, the final public-state
record, and the release functions are public-determined outside the declared
releases. For an entrypoint whose kernel program is admitted, this module
discharges all four from the Lean models of the runtime's observables, as
`paperMain_admittedKernelRun_exact_noninterference_moduloReleases` does on the
exact route:

- the public outcome and the final public-state record are the kernel models
  (`kernelPublicOutcome`, `kernelFinalPublicState`) of the run a configuration
  denotes. Their safety comes from the information-flow analysis and from the
  program writing only confidential objects; neither depends on how a map is
  stored;
- the boundary schedule is the one the runtime controller certificate assigns
  to a call with the entrypoint's number of ORAM accesses
  (`kernelOramBoundarySchedule`, which is
  `RuntimeControllerCertificate.boundarySchedule`): enter, an exit and a
  re-entry around each access, and exit with the return length. The number of
  accesses is fixed by the program and its maps' schemes (the manifest's
  `oram_accesses`), so both runs of a pair make the same number;
- the release functions are the entrypoint's.

ORAM configurations and kernel runs are linked by a `KernelDenotation`: every
admitted configuration denotes an admitted run of the program, and two admitted
configurations with the same public projection denote runs that agree on
contract, entrypoint, public arguments, public environment, and public store.
The ORAM premise itself, computational UO of the configurations' runs, is the
one a bundle discharges (`SeededRuntimePathOramProofBundleOn`); with a bundle the
theorems have no premise left beyond the Path ORAM security assumptions.

That the runtime emits the modeled observables, and keeps a Path ORAM map with
the kernel's map semantics, is a refinement obligation: the probe checks the
outcome, boundary schedule, and final public-state record against these models
on every Path ORAM experiment run, and the private scheme's tree is replayed
against `PathOramAvlMap`, whose map semantics is proved.
-/

set_option autoImplicit false

namespace UOToolchain.IR

/-! ## The boundary schedule of a call with ORAM accesses -/

/-- The enclave-boundary schedule the runtime controller certificate assigns to
a call with `accessCount` ORAM accesses: enter with the entry input, exit and
re-enter around each access, and exit with the output shape's return length. -/
def kernelOramBoundarySchedule (policy : EntrypointPublicPolicy) (accessCount : Nat)
    (outcome : SGXPublicOutcome) : List BoundaryEvent :=
  [ { direction := .enter, apiId := policy.entrypointId, inputLen := policy.entryInputLen,
      outputLen := 0 } ] ++
    concatLists (List.replicate accessCount runtimeControllerAccessBoundaryEvents) ++
    [ { direction := .exit, apiId := policy.entrypointId, inputLen := 0,
        outputLen := outcome.outputShape.returnLength } ]

/-- Without ORAM accesses it is the exact route's schedule. -/
theorem kernelOramBoundarySchedule_zero (policy : EntrypointPublicPolicy)
    (outcome : SGXPublicOutcome) :
    kernelOramBoundarySchedule policy 0 outcome = kernelBoundarySchedule policy outcome := rfl

/-- It is the runtime controller certificate's schedule for a call of the
entrypoint whose certificate records `accessCount` ORAM accesses. -/
theorem kernelOramBoundarySchedule_eq_certificate (policy : EntrypointPublicPolicy)
    (certificate : RuntimeControllerCertificate) (outcome : SGXPublicOutcome)
    (hEntry : outcome.entrypointId = policy.entrypointId)
    (hInput : certificate.entryInputLen = policy.entryInputLen) :
    kernelOramBoundarySchedule policy certificate.observedOramAccesses.length outcome =
      certificate.boundarySchedule outcome := by
  simp [kernelOramBoundarySchedule, RuntimeControllerCertificate.boundarySchedule, hEntry,
    hInput]

theorem concatLists_replicate_length {α : Type} (count : Nat) (events : List α) :
    (concatLists (List.replicate count events)).length = count * events.length := by
  induction count with
  | zero => simp [concatLists]
  | succ count ih =>
      simp [List.replicate_succ, concatLists, ih, Nat.succ_mul, Nat.add_comm]

/-- Two events for each access, and the entry and the exit. -/
theorem kernelOramBoundarySchedule_length (policy : EntrypointPublicPolicy) (accessCount : Nat)
    (outcome : SGXPublicOutcome) :
    (kernelOramBoundarySchedule policy accessCount outcome).length = 2 * accessCount + 2 := by
  simp [kernelOramBoundarySchedule, concatLists_replicate_length,
    runtimeControllerAccessBoundaryEvents, Nat.mul_comm]

/-- The modeled schedule is public-determined outside the status release
whenever the outcome is public-determined outside its releases: only its last
event depends on the run, through the return length, which the status release
erases. -/
theorem kernelOramBoundarySchedule_safe {κ : Type} {samePublic : κ → κ → Prop}
    {outcome : κ → SGXPublicOutcome} (policy : EntrypointPublicPolicy) (accessCount : Nat)
    (hOutcome : PublicOutcomeSafeModuloReleases samePublic outcome)
    (hPolicy : ∀ cfg, (outcome cfg).statusPolicy = policy.statusPolicy) :
    BoundarySafeModuloReleases samePublic outcome
      (fun cfg => kernelOramBoundarySchedule policy accessCount (outcome cfg)) := by
  intro c₁ c₂ hPublic
  have hErased := hOutcome c₁ c₂ hPublic
  show boundaryWithoutStatusRelease (outcome c₁).statusReleased
      (kernelOramBoundarySchedule policy accessCount (outcome c₁)) =
    boundaryWithoutStatusRelease (outcome c₂).statusReleased
      (kernelOramBoundarySchedule policy accessCount (outcome c₂))
  have hReleased₁ : (outcome c₁).statusReleased = (policy.statusPolicy == "declassified") := by
    simp [SGXPublicOutcome.statusReleased, hPolicy]
  have hReleased₂ : (outcome c₂).statusReleased = (policy.statusPolicy == "declassified") := by
    simp [SGXPublicOutcome.statusReleased, hPolicy]
  rw [hReleased₁, hReleased₂]
  cases hDecl : (policy.statusPolicy == "declassified")
  · have hShape : (outcome c₁).outputShape = (outcome c₂).outputShape := by
      have := congrArg SGXPublicOutcome.outputShape hErased
      simpa [SGXPublicOutcome.withoutReleases, SGXPublicOutcome.statusReleased, hPolicy,
        hDecl] using this
    simp [kernelOramBoundarySchedule, hShape]
  · simp [boundaryWithoutStatusRelease, kernelOramBoundarySchedule,
      BoundaryEvent.withoutStatusRelease]

/-! ## Example

A call of an entrypoint with a declassified status whose program makes three
ORAM accesses crosses the enclave boundary eight times. A completed call that
returns 32 bytes and an aborted call differ only in the last exit's length,
which the status release erases. -/

private def sampleOramPolicy : EntrypointPublicPolicy :=
  { entrypointId := "deposit(bytes32,uint256)", statusPolicy := "declassified"
  , returnPolicy := "public", declassifies := ["success"], returnLength := 32
  , entryInputLen := 64, gas := 1000 }

example (completed aborted : SGXPublicOutcome)
    (hCompleted : completed.outputShape = { returnPresent := true, returnLength := 32 })
    (hAborted : aborted.outputShape = OutputShape.erased) :
    (kernelOramBoundarySchedule sampleOramPolicy 3 completed).length = 8 ∧
      kernelOramBoundarySchedule sampleOramPolicy 3 completed ≠
        kernelOramBoundarySchedule sampleOramPolicy 3 aborted ∧
      boundaryWithoutStatusRelease true (kernelOramBoundarySchedule sampleOramPolicy 3 completed) =
        boundaryWithoutStatusRelease true
          (kernelOramBoundarySchedule sampleOramPolicy 3 aborted) := by
  refine ⟨kernelOramBoundarySchedule_length _ _ _, ?_, ?_⟩ <;>
    simp [kernelOramBoundarySchedule, boundaryWithoutStatusRelease,
      BoundaryEvent.withoutStatusRelease, runtimeControllerAccessBoundaryEvents, concatLists,
      hCompleted, hAborted, OutputShape.erased]

end UOToolchain.IR

namespace UOToolchain

/-! ## ORAM configurations as kernel runs -/

/-- How admitted ORAM configurations denote runs of a kernel program: every
admitted configuration is the configuration of an admitted run, and two
admitted configurations with the same public projection denote runs that agree
on contract, entrypoint, public arguments, public environment, and public
store. -/
structure KernelDenotation (kp : IR.KernelProgram) (admitted : OramConfig → Prop) where
  kernelOf : OramConfig → IR.OperationalConfig
  admittedRun : ∀ cfg, admitted cfg → ∃ a : IR.AdmittedKernelRun kp, a.cfg = kernelOf cfg
  samePublic : ∀ cfg₁ cfg₂, AdmittedSamePublic admitted cfg₁ cfg₂ →
    IR.sameOperationalPublicProjection (kernelOf cfg₁) (kernelOf cfg₂)

namespace KernelDenotation

variable {kp : IR.KernelProgram} {admitted : OramConfig → Prop}
  (denote : KernelDenotation kp admitted)

/-- A field of the run that is public-determined on admitted runs is
public-determined on admitted configurations. -/
theorem fieldSafe {α : Type} {field : IR.OperationalConfig → α}
    (hSafe : PaperMainPublicFieldSafe IR.AdmittedKernelRun.samePublic
      (fun a : IR.AdmittedKernelRun kp => field a.cfg)) :
    PaperMainPublicFieldSafe (AdmittedSamePublic admitted)
      (fun cfg => field (denote.kernelOf cfg)) := by
  intro cfg₁ cfg₂ hPair
  obtain ⟨a₁, h₁⟩ := denote.admittedRun cfg₁ hPair.1
  obtain ⟨a₂, h₂⟩ := denote.admittedRun cfg₂ hPair.2.1
  have hPublic : a₁.samePublic a₂ := by
    show IR.sameOperationalPublicProjection a₁.cfg a₂.cfg
    rw [h₁, h₂]
    exact denote.samePublic cfg₁ cfg₂ hPair
  have hField : field a₁.cfg = field a₂.cfg := hSafe a₁ a₂ hPublic
  rw [h₁, h₂] at hField
  exact hField

/-- The modeled public outcome of the denoted run. -/
def publicOutcome (policy : IR.EntrypointPublicPolicy) (render : IR.Value → String)
    (renderEnv : String × IR.Value → String) (cfg : OramConfig) : SGXPublicOutcome :=
  IR.kernelPublicOutcome policy render renderEnv kp (denote.kernelOf cfg)

/-- The modeled boundary schedule of the denoted run, a call with
`accessCount` ORAM accesses. -/
def boundarySchedule (policy : IR.EntrypointPublicPolicy) (render : IR.Value → String)
    (renderEnv : String × IR.Value → String) (accessCount : Nat) (cfg : OramConfig) :
    List BoundaryEvent :=
  IR.kernelOramBoundarySchedule policy accessCount
    (denote.publicOutcome policy render renderEnv cfg)

/-- The modeled final public-state record of the denoted run. -/
def finalPublicState (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (cfg : OramConfig) : PaperMainFinalPublicStateRollback :=
  IR.kernelFinalPublicState digest deltaDigest kp (denote.kernelOf cfg)

theorem publicOutcome_safe (policy : IR.EntrypointPublicPolicy) (render : IR.Value → String)
    (renderEnv : String × IR.Value → String) (hAgree : IR.PolicyAgreesWithFlow kp policy) :
    PublicOutcomeSafeModuloReleases (AdmittedSamePublic admitted)
      (denote.publicOutcome policy render renderEnv) :=
  denote.fieldSafe
    (field := fun cfg => (IR.kernelPublicOutcome policy render renderEnv kp cfg).withoutReleases)
    (IR.kernelPublicOutcome_safe kp policy render renderEnv hAgree)

theorem boundarySchedule_safe (policy : IR.EntrypointPublicPolicy) (render : IR.Value → String)
    (renderEnv : String × IR.Value → String) (accessCount : Nat)
    (hAgree : IR.PolicyAgreesWithFlow kp policy) :
    BoundarySafeModuloReleases (AdmittedSamePublic admitted)
      (denote.publicOutcome policy render renderEnv)
      (denote.boundarySchedule policy render renderEnv accessCount) :=
  IR.kernelOramBoundarySchedule_safe policy accessCount
    (denote.publicOutcome_safe policy render renderEnv hAgree) (fun _ => rfl)

theorem finalPublicState_safe (policy : IR.EntrypointPublicPolicy) (render : IR.Value → String)
    (renderEnv : String × IR.Value → String) (digest : IR.ObjectStore → String)
    (deltaDigest : List Nat → String) (hAgree : IR.PolicyAgreesWithFlow kp policy) :
    FinalPublicStateSafeModuloReleases (AdmittedSamePublic admitted)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest) :=
  denote.fieldSafe
    (field := fun cfg =>
      (IR.kernelFinalPublicState digest deltaDigest kp cfg).withoutStatusRelease
        (IR.kernelPublicOutcome policy render renderEnv kp cfg).statusReleased)
    (IR.kernelFinalPublicState_safe kp policy render renderEnv digest deltaDigest hAgree)

end KernelDenotation

/-! ## The theorems -/

/-- **The `path_oram_local_posmap_v1` paper-main theorem modulo declared
releases for admitted kernel programs**, with the outcome, boundary,
final-state, and release premises discharged: two admitted configurations with
the same public projection, denoting runs of a kernel program whose declared
policies agree with the information-flow analysis, satisfy the theorem's
conclusion for the modeled public outcome, boundary schedule, and final
public-state record, given computational UO of their runs. -/
theorem paperMain_admittedKernelRun_pathOramLocalPosmapV1_noninterference_moduloReleases
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
    {kp : IR.KernelProgram} {admitted : OramConfig → Prop}
    (denote : KernelDenotation kp admitted)
    (policy : IR.EntrypointPublicPolicy) (hAgree : IR.PolicyAgreesWithFlow kp policy)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (accessCount : Nat) (modelTags : SGXModelTags)
    (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {run : OramSemantics}
    (hOram :
      ComputationalUOWithOn admitted (pathOramLocalPosmapV1SecurityInterface assumptions) run)
    {cfg₁ cfg₂ : OramConfig} (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics run (denote.publicOutcome policy render renderEnv)
        (denote.boundarySchedule policy render renderEnv accessCount) oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage (denote.publicOutcome policy render renderEnv) modelTags)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest)
      (fun _ => releaseFunctions)
      cfg₁
      cfg₂ :=
  paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on assumptions hOram
    (denote.publicOutcome_safe policy render renderEnv hAgree)
    (denote.boundarySchedule_safe policy render renderEnv accessCount hAgree)
    (denote.finalPublicState_safe policy render renderEnv digest deltaDigest hAgree)
    (fun _ _ _ => rfl) hPair

/-- **The `path_oram_private_posmap_v1` paper-main theorem modulo declared
releases for admitted kernel programs**, with the outcome, boundary,
final-state, and release premises discharged. -/
theorem paperMain_admittedKernelRun_pathOramPrivatePosmapV1_noninterference_moduloReleases
    (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
    {kp : IR.KernelProgram} {admitted : OramConfig → Prop}
    (denote : KernelDenotation kp admitted)
    (policy : IR.EntrypointPublicPolicy) (hAgree : IR.PolicyAgreesWithFlow kp policy)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (accessCount : Nat) (modelTags : SGXModelTags)
    (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {run : OramSemantics}
    (hOram :
      ComputationalUOWithOn admitted (pathOramPrivatePosmapV1SecurityInterface assumptions) run)
    {cfg₁ cfg₂ : OramConfig} (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics run (denote.publicOutcome policy render renderEnv)
        (denote.boundarySchedule policy render renderEnv accessCount) oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage (denote.publicOutcome policy render renderEnv) modelTags)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest)
      (fun _ => releaseFunctions)
      cfg₁
      cfg₂ :=
  paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases_on assumptions hOram
    (denote.publicOutcome_safe policy render renderEnv hAgree)
    (denote.boundarySchedule_safe policy render renderEnv accessCount hAgree)
    (denote.finalPublicState_safe policy render renderEnv digest deltaDigest hAgree)
    (fun _ _ _ => rfl) hPair

/-- The local-scheme theorem for an entrypoint whose program passes the
admission check that `checkKernelAdmission` runs on the compiled artifacts. -/
theorem paperMain_checkedKernel_pathOramLocalPosmapV1_noninterference_moduloReleases
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
    {kp : IR.KernelProgram} {state : List IR.StateObject} {policy : IR.EntrypointPublicPolicy}
    (hCheck : kp.admissionCheck state policy = true)
    {admitted : OramConfig → Prop} (denote : KernelDenotation kp admitted)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (accessCount : Nat) (modelTags : SGXModelTags)
    (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {run : OramSemantics}
    (hOram :
      ComputationalUOWithOn admitted (pathOramLocalPosmapV1SecurityInterface assumptions) run)
    {cfg₁ cfg₂ : OramConfig} (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics run (denote.publicOutcome policy render renderEnv)
        (denote.boundarySchedule policy render renderEnv accessCount) oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage (denote.publicOutcome policy render renderEnv) modelTags)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest)
      (fun _ => releaseFunctions)
      cfg₁
      cfg₂ :=
  paperMain_admittedKernelRun_pathOramLocalPosmapV1_noninterference_moduloReleases assumptions
    denote policy (IR.KernelProgram.admissionCheck_sound hCheck).policyAgrees render renderEnv
    digest deltaDigest accessCount modelTags releaseFunctions hOram hPair

/-- The private-scheme theorem for an entrypoint whose program passes the
admission check. -/
theorem paperMain_checkedKernel_pathOramPrivatePosmapV1_noninterference_moduloReleases
    (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
    {kp : IR.KernelProgram} {state : List IR.StateObject} {policy : IR.EntrypointPublicPolicy}
    (hCheck : kp.admissionCheck state policy = true)
    {admitted : OramConfig → Prop} (denote : KernelDenotation kp admitted)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (accessCount : Nat) (modelTags : SGXModelTags)
    (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {run : OramSemantics}
    (hOram :
      ComputationalUOWithOn admitted (pathOramPrivatePosmapV1SecurityInterface assumptions) run)
    {cfg₁ cfg₂ : OramConfig} (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics run (denote.publicOutcome policy render renderEnv)
        (denote.boundarySchedule policy render renderEnv accessCount) oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage (denote.publicOutcome policy render renderEnv) modelTags)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest)
      (fun _ => releaseFunctions)
      cfg₁
      cfg₂ :=
  paperMain_admittedKernelRun_pathOramPrivatePosmapV1_noninterference_moduloReleases assumptions
    denote policy (IR.KernelProgram.admissionCheck_sound hCheck).policyAgrees render renderEnv
    digest deltaDigest accessCount modelTags releaseFunctions hOram hPair

namespace SeededRuntimePathOramProofBundleOn

variable {modelTags : SGXModelTags} {admitted : OramConfig → Prop}
  (bundle : SeededRuntimePathOramProofBundleOn modelTags admitted)

/-- **The local-scheme theorem with no premise left beyond the security
assumptions**: a bundle for configurations that hold local-scheme objects only
discharges the ORAM premise, and a denotation as admitted kernel runs the
others, for every admitted pair. -/
theorem paperMain_admittedKernelRun_localPosmapV1_noninterference_moduloReleases
    (hLocal : ∀ cfg, admitted cfg → PathOramConfigWellFormed cfg)
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
    {kp : IR.KernelProgram} (denote : KernelDenotation kp admitted)
    (policy : IR.EntrypointPublicPolicy) (hAgree : IR.PolicyAgreesWithFlow kp policy)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (accessCount : Nat) (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {cfg₁ cfg₂ : OramConfig} (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics bundle.run (denote.publicOutcome policy render renderEnv)
        (denote.boundarySchedule policy render renderEnv accessCount) oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage (denote.publicOutcome policy render renderEnv) modelTags)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest)
      (fun _ => releaseFunctions)
      cfg₁
      cfg₂ :=
  paperMain_admittedKernelRun_pathOramLocalPosmapV1_noninterference_moduloReleases assumptions
    denote policy hAgree render renderEnv digest deltaDigest accessCount modelTags
    releaseFunctions
    (bundle.computationalUOWithOn hLocal assumptions.toCanonicalLeafValueSecurityAssumptions)
    hPair

/-- **The private-scheme theorem with no premise left beyond the security
assumptions**, from a bundle for configurations that hold Path ORAM objects of
either scheme. -/
theorem paperMain_admittedKernelRun_privatePosmapV1_noninterference_moduloReleases
    (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
    {kp : IR.KernelProgram} (denote : KernelDenotation kp admitted)
    (policy : IR.EntrypointPublicPolicy) (hAgree : IR.PolicyAgreesWithFlow kp policy)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (accessCount : Nat) (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {cfg₁ cfg₂ : OramConfig} (hPair : AdmittedSamePublic admitted cfg₁ cfg₂) :
    PaperMainPathOramReleaseConclusion
      (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics bundle.run (denote.publicOutcome policy render renderEnv)
        (denote.boundarySchedule policy render renderEnv accessCount) oramControllerMicroTrace)
      executionLeakage
      (oramReleaseMicroLeakage (denote.publicOutcome policy render renderEnv) modelTags)
      (denote.publicOutcome policy render renderEnv)
      (denote.finalPublicState digest deltaDigest)
      (fun _ => releaseFunctions)
      cfg₁
      cfg₂ :=
  paperMain_admittedKernelRun_pathOramPrivatePosmapV1_noninterference_moduloReleases assumptions
    denote policy hAgree render renderEnv digest deltaDigest accessCount modelTags
    releaseFunctions
    (bundle.computationalUOWithOnAny
      assumptions.localPosmapAssumptions.toCanonicalLeafValueSecurityAssumptions)
    hPair

end SeededRuntimePathOramProofBundleOn

end UOToolchain
