import UOToolchain.AcceptedPackageCapstone

namespace UOToolchain

/-!
# Paper-main theorem modulo declared releases (`Obs ∖ rel`)

The paper states security as noninterference outside the declared release
policy. If two runs of an admitted package agree on the public projection
(admitted package, public arguments, public environment, initial public state),
their host observations agree once the declared releases are erased:

  `pub(x₁) = pub(x₂) → Obs(P, x₁) ∖ rel(P, x₁) = Obs(P, x₂) ∖ rel(P, x₂)`.

The released values may differ between the two runs. The theorems in
`PaperMainTheorem` and `AcceptedPackageCapstone` instead assume that every
observer component, released or not, is public-determined, so they apply only
to entrypoints without releases. This module states the paper-main theorem and
the accepted-package capstones modulo releases for the exact backend and for
both proof-grade Path ORAM routes.

The releases are read off the artifact-declared policies that every public
outcome carries (`statusPolicy`, `returnPolicy`):

- `status: declassified` releases whether the call completed or aborted. The
  release covers the termination status and the fields the runtime derives
  from it alone: the abort/rollback flag of the final public-state record, the
  output shape, and whether a plaintext or encrypted return payload is present.
- `returns: declassified` releases the plaintext return payload.
- `returns: encrypted_to_client` releases only the AEAD output bytes, i.e. the
  ciphertext and its tag. The session binding, AAD hash, nonce, and lengths
  stay in the constrained part.

Everything else must be equal for every pair of runs with the same public
projection: the storage trace (exactly, or up to the Path ORAM storage
relation), the boundary schedule, the normalized micro trace, the modeled gas,
the declared policies, and the declared release functions. Without declared
releases the erasure is the identity
(`PaperMainViewSGX.withoutReleases_eq_self`), so these theorems specialize to
full `View_SGX` equality.
-/

/-! ## Release erasure -/

/-- `status: declassified`: the termination status is released. -/
def SGXPublicOutcome.statusReleased (outcome : SGXPublicOutcome) : Bool :=
  outcome.statusPolicy == "declassified"

/-- `returns: declassified`: the plaintext return payload is released. -/
def SGXPublicOutcome.returnReleased (outcome : SGXPublicOutcome) : Bool :=
  outcome.returnPolicy == "declassified"

/-- `returns: encrypted_to_client`: the AEAD output bytes are released. -/
def SGXPublicOutcome.returnEncrypted (outcome : SGXPublicOutcome) : Bool :=
  outcome.returnPolicy == "encrypted_to_client"

/-- An encrypted return payload without its AEAD output bytes. -/
def EncryptedReturnPayload.withoutCiphertext
    (payload : EncryptedReturnPayload) : EncryptedReturnPayload :=
  { payload with ciphertext := "", tag := "" }

/-- The output shape of a call that returns nothing, such as an aborted call. -/
def OutputShape.erased : OutputShape :=
  { returnPresent := false, returnLength := 0 }

/-- Erase the declared releases from a public outcome. -/
def SGXPublicOutcome.withoutReleases (outcome : SGXPublicOutcome) :
    SGXPublicOutcome :=
  { outcome with
    terminationStatus :=
      if outcome.statusReleased then false else outcome.terminationStatus
    outputShape :=
      if outcome.statusReleased then OutputShape.erased else outcome.outputShape
    returnPayload :=
      if outcome.statusReleased || outcome.returnReleased then none
      else outcome.returnPayload
    encryptedReturnPayload :=
      if outcome.statusReleased then none
      else if outcome.returnEncrypted then
        outcome.encryptedReturnPayload.map
          EncryptedReturnPayload.withoutCiphertext
      else outcome.encryptedReturnPayload }

/-- Erase the abort/rollback flag when the status is released. -/
def PaperMainFinalPublicStateRollback.withoutStatusRelease
    (statusReleased : Bool) (rollback : PaperMainFinalPublicStateRollback) :
    PaperMainFinalPublicStateRollback :=
  if statusReleased then { rollback with aborted := false } else rollback

/-- `View_SGX ∖ rel`: the paper-main observation outside the declared
releases. -/
def PaperMainViewSGX.withoutReleases (view : View_SGX) : View_SGX :=
  { view with
    publicOutcome := view.publicOutcome.withoutReleases
    finalPublicStateRollback :=
      view.finalPublicStateRollback.withoutStatusRelease
        view.publicOutcome.statusReleased }

/-! The erasure keeps the public parts of the outcome. -/

@[simp] theorem SGXPublicOutcome.withoutReleases_entrypointId
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.entrypointId = outcome.entrypointId := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_publicArgs
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.publicArgs = outcome.publicArgs := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_publicEnv
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.publicEnv = outcome.publicEnv := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_statusPolicy
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.statusPolicy = outcome.statusPolicy := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_returnPolicy
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.returnPolicy = outcome.returnPolicy := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_declassifies
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.declassifies = outcome.declassifies := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_gasUsed
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.gasUsed = outcome.gasUsed := rfl

@[simp] theorem SGXPublicOutcome.withoutReleases_statusReleased
    (outcome : SGXPublicOutcome) :
    outcome.withoutReleases.statusReleased = outcome.statusReleased := rfl

/-- Without declared releases the outcome erasure is the identity. -/
theorem SGXPublicOutcome.withoutReleases_eq_self
    (outcome : SGXPublicOutcome)
    (hStatus : outcome.statusReleased = false)
    (hReturn : outcome.returnReleased = false)
    (hEncrypted : outcome.returnEncrypted = false) :
    outcome.withoutReleases = outcome := by
  simp only [SGXPublicOutcome.withoutReleases, hStatus, hReturn, hEncrypted,
    Bool.or_self, Bool.false_eq_true, if_false]

/-- Without declared releases `View_SGX ∖ rel` is `View_SGX` itself. -/
theorem PaperMainViewSGX.withoutReleases_eq_self
    (view : View_SGX)
    (hStatus : view.publicOutcome.statusReleased = false)
    (hReturn : view.publicOutcome.returnReleased = false)
    (hEncrypted : view.publicOutcome.returnEncrypted = false) :
    view.withoutReleases = view := by
  simp only [PaperMainViewSGX.withoutReleases,
    SGXPublicOutcome.withoutReleases_eq_self view.publicOutcome hStatus hReturn
      hEncrypted,
    PaperMainFinalPublicStateRollback.withoutStatusRelease, hStatus,
    Bool.false_eq_true, if_false]

/-! ## Safety premises modulo releases -/

/-- The public outcome is public-determined outside its declared releases. -/
def PublicOutcomeSafeModuloReleases
    {κ : Type}
    (samePublic : κ → κ → Prop)
    (publicOutcome : κ → SGXPublicOutcome) : Prop :=
  PaperMainPublicFieldSafe samePublic
    (fun cfg => (publicOutcome cfg).withoutReleases)

/-- The final public-state record is public-determined outside the status
release of the corresponding outcome. -/
def FinalPublicStateSafeModuloReleases
    {κ : Type}
    (samePublic : κ → κ → Prop)
    (publicOutcome : κ → SGXPublicOutcome)
    (finalPublicStateRollback : κ → PaperMainFinalPublicStateRollback) : Prop :=
  PaperMainPublicFieldSafe samePublic
    (fun cfg =>
      (finalPublicStateRollback cfg).withoutStatusRelease
        (publicOutcome cfg).statusReleased)

theorem PublicOutcomeSafeModuloReleases.of_publicFieldSafe
    {κ : Type}
    {samePublic : κ → κ → Prop}
    {publicOutcome : κ → SGXPublicOutcome}
    (hOutcome : PaperMainPublicFieldSafe samePublic publicOutcome) :
    PublicOutcomeSafeModuloReleases samePublic publicOutcome := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.withoutReleases (hOutcome cfg₁ cfg₂ hPublic)

theorem FinalPublicStateSafeModuloReleases.of_publicFieldSafe
    {κ : Type}
    {samePublic : κ → κ → Prop}
    {publicOutcome : κ → SGXPublicOutcome}
    {finalPublicStateRollback : κ → PaperMainFinalPublicStateRollback}
    (hOutcome : PaperMainPublicFieldSafe samePublic publicOutcome)
    (hFinal : PaperMainPublicFieldSafe samePublic finalPublicStateRollback) :
    FinalPublicStateSafeModuloReleases
      samePublic publicOutcome finalPublicStateRollback := by
  intro cfg₁ cfg₂ hPublic
  show
    (finalPublicStateRollback cfg₁).withoutStatusRelease
        (publicOutcome cfg₁).statusReleased =
      (finalPublicStateRollback cfg₂).withoutStatusRelease
        (publicOutcome cfg₂).statusReleased
  rw [hOutcome cfg₁ cfg₂ hPublic, hFinal cfg₁ cfg₂ hPublic]

/-- The exact-route outcome premise of the full-equality theorem implies its
premise modulo releases. -/
theorem PublicOutcomeSafe.moduloReleases
    {publicOutcome : Config → SGXPublicOutcome}
    (hOutcome : PublicOutcomeSafe publicOutcome) :
    PublicOutcomeSafeModuloReleases samePublicProjection publicOutcome :=
  PublicOutcomeSafeModuloReleases.of_publicFieldSafe
    (samePublic := samePublicProjection) hOutcome

/-- The Path ORAM outcome premise of the full-equality theorem implies its
premise modulo releases. -/
theorem OramPublicOutcomeSafe.moduloReleases
    {publicOutcome : OramConfig → SGXPublicOutcome}
    (hOutcome : OramPublicOutcomeSafe publicOutcome) :
    PublicOutcomeSafeModuloReleases sameOramPublicProjection publicOutcome :=
  PublicOutcomeSafeModuloReleases.of_publicFieldSafe
    (samePublic := sameOramPublicProjection) hOutcome

/-! ## Exact backend -/

theorem sgxPublicOutcome_sgxViewOfTrace
    (cfg : Config)
    (outcome : SGXPublicOutcome)
    (boundarySchedule : List BoundaryEvent)
    (microTrace : SGXMicroTrace)
    (trace : Trace) :
    sgxPublicOutcome (sgxViewOfTrace cfg outcome boundarySchedule microTrace trace) =
      outcome := by
  cases outcome
  rfl

/-- Exact-backend paper-main theorem modulo declared releases. Two runs of the
same admitted package with equal public inputs, public environment, and initial
public state have equal `View_SGX ∖ rel`, even when their released status,
return value, or return ciphertext differ. -/
theorem paperMain_exact_backend_noninterference_moduloReleases
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback :
    Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (hExact : ExactUO run)
  (hOutcome :
    PublicOutcomeSafeModuloReleases samePublicProjection publicOutcome)
  (hBoundary : PublicBoundarySafe boundarySchedule)
  (hController : PublicControllerShapeSafe controllerShape)
  (hFinal :
    FinalPublicStateSafeModuloReleases
      samePublicProjection
      publicOutcome
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      samePublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : Config}
  (hPublic :
    PaperMainExactSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  (paperMainExactView run publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions cfg₁).withoutReleases =
    (paperMainExactView run publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions cfg₂).withoutReleases := by
  have hTrace : run cfg₁ = run cfg₂ :=
    viewMPlus_injective (hExact cfg₁ cfg₂ hPublic)
  have hOutcomeEq :
      (publicOutcome cfg₁).withoutReleases =
        (publicOutcome cfg₂).withoutReleases :=
    hOutcome cfg₁ cfg₂ hPublic
  have hBoundaryEq : boundarySchedule cfg₁ = boundarySchedule cfg₂ :=
    hBoundary cfg₁ cfg₂ hPublic
  have hControllerEq : controllerShape cfg₁ = controllerShape cfg₂ :=
    hController cfg₁ cfg₂ hPublic
  have hFinalEq :
      (finalPublicStateRollback cfg₁).withoutStatusRelease
          (publicOutcome cfg₁).statusReleased =
        (finalPublicStateRollback cfg₂).withoutStatusRelease
          (publicOutcome cfg₂).statusReleased :=
    hFinal cfg₁ cfg₂ hPublic
  have hReleaseEq : releaseFunctions cfg₁ = releaseFunctions cfg₂ :=
    hRelease cfg₁ cfg₂ hPublic
  unfold paperMainExactView paperMainViewOfSGX PaperMainViewSGX.withoutReleases
  simp only [sgxPublicOutcome_sgxViewOfTrace]
  rw [hOutcomeEq, hFinalEq, hReleaseEq, hBoundaryEq, hControllerEq, hTrace]
  -- The boundary, storage, and micro components read only the boundary
  -- schedule, the trace, and the controller shape.
  rfl

/-! ## Path ORAM backends -/

/-- SGX micro leakage of the ORAM controller, computed from the release-erased
outcome. -/
def oramReleaseMicroLeakage
    (publicOutcome : OramConfig → SGXPublicOutcome)
    (modelTags : SGXModelTags) : OramConfig → SGXMicroLeakage :=
  oramMicroLeakage (fun cfg => (publicOutcome cfg).withoutReleases) modelTags

/-- The normalized controller micro trace does not depend on the outcome that
the leakage is computed from. -/
theorem oramControllerMicroDistribution_normalized_byLeakageOf
  {run : OramSemantics}
  {publicOutcome leakageOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (cfg : OramConfig) :
  NormalizedByLeakage
    (sgxMicroDistribution
      ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg))
    (oramMicroLeakage leakageOutcome modelTags cfg) := by
  intro trace hMem
  have hMapped :
      trace ∈
        (run cfg).map
          (fun sourceView =>
            sgxMicroTrace
              (sgxViewOfOramView
                cfg
                (publicOutcome cfg)
                (boundarySchedule cfg)
                (oramControllerMicroTrace cfg)
                sourceView)) := by
    simpa [oramToSGXSemantics, sgxMicroDistribution] using hMem
  rcases List.mem_map.mp hMapped with ⟨sourceView, _hSource, hEq⟩
  rw [← hEq]
  simpa [oramControllerMicroTrace, oramControllerShape] using
    normalizeMicroTrace_controllerMicroTraceOfShape
      (leakageOutcome cfg)
      modelTags
      (sgxControllerShapeOfExecutionLeakage (executionLeakage cfg))

/-- `SGXViewRelation` outside the declared releases. -/
def SGXViewRelationModuloReleases
  (R : SGXProofRelation)
  (views₁ views₂ : Distribution SGXView)
  (storageLeakage : List OramAccessLeakage)
  (microLeakage : SGXMicroLeakage) : Prop :=
  ExactProjectionRelation
      (fun view => (sgxPublicOutcome view).withoutReleases) views₁ views₂ ∧
    ExactProjectionRelation (fun view => view.boundarySchedule) views₁ views₂ ∧
    R.storageRel
      (sgxStorageDistribution views₁)
      (sgxStorageDistribution views₂)
      storageLeakage ∧
    R.microRel
      (sgxMicroDistribution views₁)
      (sgxMicroDistribution views₂)
      microLeakage

/-- Release-erased counterpart of
`paperMain_computationalUOWith_projects_to_sgxExecution`. -/
theorem computationalUOWith_projects_to_sgxView_moduloReleases
  (security : OramSecurityInterface)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  (hOram : ComputationalUOWith security run)
  (hOutcome :
    PublicOutcomeSafeModuloReleases sameOramPublicProjection publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic : sameOramPublicProjection cfg₁ cfg₂) :
  SGXViewRelationModuloReleases
    (oramNormalizedObservedSGXProofRelationWith security)
    ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₁)
    ((oramToSGXSemantics run publicOutcome boundarySchedule oramControllerMicroTrace) cfg₂)
    (executionLeakage cfg₁)
    (oramReleaseMicroLeakage publicOutcome modelTags cfg₁) := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · apply exactProjectionRelation_of_constant (hOutcome cfg₁ cfg₂ hPublic)
    · refine
        constantProjection_map_of_const
          (fun view : SGXView => (sgxPublicOutcome view).withoutReleases)
          ((publicOutcome cfg₁).withoutReleases) _ (run cfg₁) ?_
      intro view _hMem
      simp
    · refine
        constantProjection_map_of_const
          (fun view : SGXView => (sgxPublicOutcome view).withoutReleases)
          ((publicOutcome cfg₂).withoutReleases) _ (run cfg₂) ?_
      intro view _hMem
      simp
  · apply exactProjectionRelation_of_constant (hBoundary cfg₁ cfg₂ hPublic)
    · refine
        constantProjection_map_of_const
          (fun view : SGXView => view.boundarySchedule)
          (boundarySchedule cfg₁) _ (run cfg₁) ?_
      intro view _hMem
      simp
    · refine
        constantProjection_map_of_const
          (fun view : SGXView => view.boundarySchedule)
          (boundarySchedule cfg₂) _ (run cfg₂) ?_
      intro view _hMem
      simp
  · simpa [oramToSGXSemantics, sgxStorageDistribution] using
      (oramSecurity_projects_to_sgxStorage
        security
        cfg₁
        cfg₂
        (run cfg₁)
        (run cfg₂)
        hPublic
        (hOram cfg₁ cfg₂ hPublic))
  · have hLeakage :
        oramReleaseMicroLeakage publicOutcome modelTags cfg₂ =
          oramReleaseMicroLeakage publicOutcome modelTags cfg₁ :=
      oramControllerMicroLeakage_eq_of_samePublicProjection
        (publicOutcome := fun cfg => (publicOutcome cfg).withoutReleases)
        hOutcome
        (sameOramPublicProjection_symm hPublic)
    exact
      ⟨ oramControllerMicroDistribution_normalized_byLeakageOf (run := run) cfg₁
      , normalizedByLeakage_of_eq hLeakage
          (oramControllerMicroDistribution_normalized_byLeakageOf (run := run) cfg₂)
      ⟩

/-- Conclusion of the Path ORAM paper-main theorems modulo releases, for the
storage/micro relation `R` of the chosen Path ORAM route. -/
structure PaperMainPathOramReleaseConclusion
  (R : SGXProofRelation)
  (run : SGXSemantics OramConfig)
  (storageLeakage : OramConfig → List OramAccessLeakage)
  (microLeakage : OramConfig → SGXMicroLeakage)
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions)
  (cfg₁ cfg₂ : OramConfig) : Prop where
  publicOutcomeModuloReleases :
    ExactProjectionRelation
      (fun view : SGXView => (sgxPublicOutcome view).withoutReleases)
      (run cfg₁)
      (run cfg₂)
  boundarySchedule :
    ExactProjectionRelation (fun view : SGXView => view.boundarySchedule)
      (run cfg₁)
      (run cfg₂)
  storageTrace :
    R.storageRel
      (sgxStorageDistribution (run cfg₁))
      (sgxStorageDistribution (run cfg₂))
      (storageLeakage cfg₁)
  microTrace :
    R.microRel
      (sgxMicroDistribution (run cfg₁))
      (sgxMicroDistribution (run cfg₂))
      (microLeakage cfg₁)
  finalPublicStateModuloReleases :
    (finalPublicStateRollback cfg₁).withoutStatusRelease
        (publicOutcome cfg₁).statusReleased =
      (finalPublicStateRollback cfg₂).withoutStatusRelease
        (publicOutcome cfg₂).statusReleased
  releaseFunctions :
    releaseFunctions cfg₁ = releaseFunctions cfg₂

/-- `path_oram_local_posmap_v1` paper-main theorem modulo declared releases. -/
theorem paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hOram :
    ComputationalUOWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      run)
  (hOutcome :
    PublicOutcomeSafeModuloReleases sameOramPublicProjection publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hFinal :
    FinalPublicStateSafeModuloReleases
      sameOramPublicProjection
      publicOutcome
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramReleaseConclusion
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      run
      publicOutcome
      boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramReleaseMicroLeakage publicOutcome modelTags)
    publicOutcome
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  have hSGX :=
    computationalUOWith_projects_to_sgxView_moduloReleases
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (modelTags := modelTags)
      hOram
      hOutcome
      hBoundary
      hPublic
  exact
    { publicOutcomeModuloReleases := hSGX.1
    , boundarySchedule := hSGX.2.1
    , storageTrace := hSGX.2.2.1
    , microTrace := hSGX.2.2.2
    , finalPublicStateModuloReleases := hFinal cfg₁ cfg₂ hPublic
    , releaseFunctions := hRelease cfg₁ cfg₂ hPublic
    }

/-- `path_oram_private_posmap_v1` paper-main theorem modulo declared
releases. -/
theorem paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hOram :
    ComputationalUOWith
      (pathOramPrivatePosmapV1SecurityInterface assumptions)
      run)
  (hOutcome :
    PublicOutcomeSafeModuloReleases sameOramPublicProjection publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hFinal :
    FinalPublicStateSafeModuloReleases
      sameOramPublicProjection
      publicOutcome
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramReleaseConclusion
    (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      run
      publicOutcome
      boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramReleaseMicroLeakage publicOutcome modelTags)
    publicOutcome
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  have hSGX :=
    computationalUOWith_projects_to_sgxView_moduloReleases
      (pathOramPrivatePosmapV1SecurityInterface assumptions)
      (modelTags := modelTags)
      hOram
      hOutcome
      hBoundary
      hPublic
  exact
    { publicOutcomeModuloReleases := hSGX.1
    , boundarySchedule := hSGX.2.1
    , storageTrace := hSGX.2.2.1
    , microTrace := hSGX.2.2.2
    , finalPublicStateModuloReleases := hFinal cfg₁ cfg₂ hPublic
    , releaseFunctions := hRelease cfg₁ cfg₂ hPublic
    }

/-- `SeededRuntimePaperMainBundle` with the outcome premise weakened to hold
modulo releases. -/
structure SeededRuntimePaperMainReleaseBundle (modelTags : SGXModelTags)
    extends SeededRuntimePathOramProofBundle modelTags where
  publicOutcome : OramConfig → SGXPublicOutcome
  publicOutcomeExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).publicOutcome = publicOutcome cfg
  publicOutcomeSafeModuloReleases :
    PublicOutcomeSafeModuloReleases sameOramPublicProjection publicOutcome
  boundarySchedule : OramConfig → List BoundaryEvent
  boundaryExact :
    ∀ cfg seed, seed < (family cfg).seedCount →
      ((family cfg).witnessAt seed).boundarySchedule = boundarySchedule cfg
  boundarySafe :
    ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ →
      boundarySchedule cfg₁ = boundarySchedule cfg₂

/-- Every full-equality paper-main bundle is a release bundle. -/
def SeededRuntimePaperMainBundle.toReleaseBundle
    {modelTags : SGXModelTags}
    (bundle : SeededRuntimePaperMainBundle modelTags) :
    SeededRuntimePaperMainReleaseBundle modelTags :=
  { toSeededRuntimePathOramProofBundle := bundle.toSeededRuntimePathOramProofBundle
  , publicOutcome := bundle.publicOutcome
  , publicOutcomeExact := bundle.publicOutcomeExact
  , publicOutcomeSafeModuloReleases :=
      OramPublicOutcomeSafe.moduloReleases bundle.publicOutcomeSafe
  , boundarySchedule := bundle.boundarySchedule
  , boundaryExact := bundle.boundaryExact
  , boundarySafe := bundle.boundarySafe
  }

theorem SeededRuntimePaperMainReleaseBundle.pathOramLocalPosmapV1_paperMain_noninterference_moduloReleases
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainReleaseBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hFinal :
    FinalPublicStateSafeModuloReleases
      sameOramPublicProjection
      bundle.publicOutcome
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramReleaseConclusion
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramReleaseMicroLeakage bundle.publicOutcome modelTags)
    bundle.publicOutcome
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ :=
  paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases
    assumptions
    (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
      assumptions)
    bundle.publicOutcomeSafeModuloReleases
    bundle.boundarySafe
    hFinal
    hRelease
    hPublic

theorem SeededRuntimePaperMainReleaseBundle.pathOramPrivatePosmapV1_paperMain_noninterference_moduloReleases
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainReleaseBundle modelTags)
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  {cert : ScalablePathOramCertificate}
  (certificate :
    PathOramPrivatePosmapV1BundleCertificate
      cert
      bundle.toSeededRuntimePathOramProofBundle)
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hFinal :
    FinalPublicStateSafeModuloReleases
      sameOramPublicProjection
      bundle.publicOutcome
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramReleaseConclusion
    (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramReleaseMicroLeakage bundle.publicOutcome modelTags)
    bundle.publicOutcome
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ :=
  paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases
    assumptions
    (bundle.toSeededRuntimePathOramProofBundle
      |>.pathOramPrivatePosmapV1_computationalUOWith
        assumptions
        certificate)
    bundle.publicOutcomeSafeModuloReleases
    bundle.boundarySafe
    hFinal
    hRelease
    hPublic

/-! ## Accepted-package capstones modulo releases -/

structure AcceptedExactPackageReleaseCapstoneEvidence
  (translation : ImportedProofRelevantTranslationBundle)
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (deploymentState : DeploymentRuntimeState)
  (deploymentEvidence : DeploymentCallEvidence)
  (run : TraceSemantics)
  (publicOutcome : Config → SGXPublicOutcome)
  (boundarySchedule : Config → List BoundaryEvent)
  (controllerShape : Config → SGXControllerShape)
  (finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback)
  (releaseFunctions : Config → PaperMainDeclaredReleaseFunctions) : Prop where
  translationProofGrade : translation.ProofGradeValid
  deploymentAccepted :
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence
  backendExact : ExactUO run
  publicOutcomeSafe :
    PublicOutcomeSafeModuloReleases samePublicProjection publicOutcome
  boundarySafe : PublicBoundarySafe boundarySchedule
  controllerShapeSafe : PublicControllerShapeSafe controllerShape
  finalPublicStateSafe :
    FinalPublicStateSafeModuloReleases
      samePublicProjection publicOutcome finalPublicStateRollback
  releaseFunctionsSafe :
    PaperMainPublicFieldSafe samePublicProjection releaseFunctions

/-- Full-equality exact capstone evidence is release capstone evidence. -/
theorem AcceptedExactPackageCapstoneEvidence.moduloReleases
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedExactPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      run
      publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions) :
  AcceptedExactPackageReleaseCapstoneEvidence
    translation policy profile deploymentState deploymentEvidence
    run
    publicOutcome boundarySchedule controllerShape
    finalPublicStateRollback releaseFunctions :=
  { translationProofGrade := accepted.translationProofGrade
  , deploymentAccepted := accepted.deploymentAccepted
  , backendExact := accepted.backendExact
  , publicOutcomeSafe := PublicOutcomeSafe.moduloReleases accepted.publicOutcomeSafe
  , boundarySafe := accepted.boundarySafe
  , controllerShapeSafe := accepted.controllerShapeSafe
  , finalPublicStateSafe :=
      FinalPublicStateSafeModuloReleases.of_publicFieldSafe
        (samePublic := samePublicProjection)
        accepted.publicOutcomeSafe
        accepted.finalPublicStateSafe
  , releaseFunctionsSafe := accepted.releaseFunctionsSafe
  }

/-- Exact-backend accepted-package capstone modulo declared releases. -/
theorem acceptedExactPackageCapstone_noninterference_moduloReleases
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedExactPackageReleaseCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      run
      publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : Config}
  (hPublic :
    PaperMainExactSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  (paperMainExactView run publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions cfg₁).withoutReleases =
    (paperMainExactView run publicOutcome boundarySchedule controllerShape
      finalPublicStateRollback releaseFunctions cfg₂).withoutReleases :=
  paperMain_exact_backend_noninterference_moduloReleases
    accepted.backendExact
    accepted.publicOutcomeSafe
    accepted.boundarySafe
    accepted.controllerShapeSafe
    accepted.finalPublicStateSafe
    accepted.releaseFunctionsSafe
    hPublic

structure AcceptedPathOramPackageReleaseCapstoneEvidence
  {modelTags : SGXModelTags}
  (translation : ImportedProofRelevantTranslationBundle)
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (deploymentState : DeploymentRuntimeState)
  (deploymentEvidence : DeploymentCallEvidence)
  (bundle : SeededRuntimePaperMainReleaseBundle modelTags)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions) : Prop where
  translationProofGrade : translation.ProofGradeValid
  deploymentAccepted :
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence
  finalPublicStateSafe :
    FinalPublicStateSafeModuloReleases
      sameOramPublicProjection bundle.publicOutcome finalPublicStateRollback
  releaseFunctionsSafe :
    PaperMainPublicFieldSafe sameOramPublicProjection releaseFunctions

/-- Full-equality `path_oram_local_posmap_v1` capstone evidence is release
capstone evidence. -/
theorem AcceptedPathOramPackageCapstoneEvidence.moduloReleases
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle finalPublicStateRollback releaseFunctions) :
  AcceptedPathOramPackageReleaseCapstoneEvidence
    translation policy profile deploymentState deploymentEvidence
    bundle.toReleaseBundle finalPublicStateRollback releaseFunctions :=
  { translationProofGrade := accepted.translationProofGrade
  , deploymentAccepted := accepted.deploymentAccepted
  , finalPublicStateSafe :=
      FinalPublicStateSafeModuloReleases.of_publicFieldSafe
        (samePublic := sameOramPublicProjection)
        bundle.publicOutcomeSafe
        accepted.finalPublicStateSafe
  , releaseFunctionsSafe := accepted.releaseFunctionsSafe
  }

/-- `path_oram_local_posmap_v1` accepted-package capstone modulo declared
releases. -/
theorem acceptedPathOramPackageCapstone_noninterference_moduloReleases
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainReleaseBundle modelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (accepted :
    AcceptedPathOramPackageReleaseCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramReleaseConclusion
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramReleaseMicroLeakage bundle.publicOutcome modelTags)
    bundle.publicOutcome
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ :=
  bundle.pathOramLocalPosmapV1_paperMain_noninterference_moduloReleases
    assumptions
    accepted.finalPublicStateSafe
    accepted.releaseFunctionsSafe
    hPublic

structure AcceptedPrivatePosmapPathOramPackageReleaseCapstoneEvidence
  {modelTags : SGXModelTags}
  (translation : ImportedProofRelevantTranslationBundle)
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (deploymentState : DeploymentRuntimeState)
  (deploymentEvidence : DeploymentCallEvidence)
  (bundle : SeededRuntimePaperMainReleaseBundle modelTags)
  (cert : ScalablePathOramCertificate)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions) : Prop where
  translationProofGrade : translation.ProofGradeValid
  privatePosmapCertificatesValidated :
    translation.PrivatePosmapCertificatesValidated
  deploymentAccepted :
    DeploymentCallAccepted policy profile deploymentState deploymentEvidence
  privatePosmapCertificate :
    PathOramPrivatePosmapV1BundleCertificate
      cert
      bundle.toSeededRuntimePathOramProofBundle
  finalPublicStateSafe :
    FinalPublicStateSafeModuloReleases
      sameOramPublicProjection bundle.publicOutcome finalPublicStateRollback
  releaseFunctionsSafe :
    PaperMainPublicFieldSafe sameOramPublicProjection releaseFunctions

/-- Full-equality `path_oram_private_posmap_v1` capstone evidence is release
capstone evidence. -/
theorem AcceptedPrivatePosmapPathOramPackageCapstoneEvidence.moduloReleases
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainBundle modelTags}
  {cert : ScalablePathOramCertificate}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (accepted :
    AcceptedPrivatePosmapPathOramPackageCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle cert finalPublicStateRollback releaseFunctions) :
  AcceptedPrivatePosmapPathOramPackageReleaseCapstoneEvidence
    translation policy profile deploymentState deploymentEvidence
    bundle.toReleaseBundle cert finalPublicStateRollback releaseFunctions :=
  { translationProofGrade := accepted.translationProofGrade
  , privatePosmapCertificatesValidated :=
      accepted.privatePosmapCertificatesValidated
  , deploymentAccepted := accepted.deploymentAccepted
  , privatePosmapCertificate := accepted.privatePosmapCertificate
  , finalPublicStateSafe :=
      FinalPublicStateSafeModuloReleases.of_publicFieldSafe
        (samePublic := sameOramPublicProjection)
        bundle.publicOutcomeSafe
        accepted.finalPublicStateSafe
  , releaseFunctionsSafe := accepted.releaseFunctionsSafe
  }

/-- `path_oram_private_posmap_v1` accepted-package capstone modulo declared
releases. -/
theorem acceptedPrivatePosmapPathOramPackageCapstone_noninterference_moduloReleases
  {modelTags : SGXModelTags}
  {translation : ImportedProofRelevantTranslationBundle}
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {deploymentState : DeploymentRuntimeState}
  {deploymentEvidence : DeploymentCallEvidence}
  {bundle : SeededRuntimePaperMainReleaseBundle modelTags}
  {cert : ScalablePathOramCertificate}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  (accepted :
    AcceptedPrivatePosmapPathOramPackageReleaseCapstoneEvidence
      translation policy profile deploymentState deploymentEvidence
      bundle cert finalPublicStateRollback releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramReleaseConclusion
    (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramReleaseMicroLeakage bundle.publicOutcome modelTags)
    bundle.publicOutcome
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ :=
  bundle.pathOramPrivatePosmapV1_paperMain_noninterference_moduloReleases
    assumptions
    accepted.privatePosmapCertificate
    accepted.finalPublicStateSafe
    accepted.releaseFunctionsSafe
    hPublic

/-! ## Example: `ConfidentialMixer.withdraw`

`withdraw` declares `status: declassified` and `returns: declassified`. A
withdrawal that completes and returns `5` and one that aborts have different
public outcomes, and the same outcome outside the releases. Outcomes that
differ in a constrained field, such as the modeled gas, stay distinguished. -/

private def mixerWithdrawOutcome
    (completed : Bool) (payload : Option String) (gas : Nat) :
    SGXPublicOutcome :=
  { entrypointId := "withdraw(bytes32,uint256)"
  , publicArgs := []
  , publicEnv := []
  , terminationStatus := completed
  , statusPolicy := "declassified"
  , outputShape :=
      if completed then { returnPresent := true, returnLength := 32 }
      else OutputShape.erased
  , returnPolicy := "declassified"
  , returnPayload := payload
  , encryptedReturnPayload := none
  , declassifies := ["return", "success"]
  , gasUsed := gas
  }

example :
    mixerWithdrawOutcome true (some "5") 2428 ≠
      mixerWithdrawOutcome false none 2428 := by
  decide

example :
    (mixerWithdrawOutcome true (some "5") 2428).withoutReleases =
      (mixerWithdrawOutcome false none 2428).withoutReleases := by
  decide

example :
    (mixerWithdrawOutcome true (some "5") 2428).withoutReleases ≠
      (mixerWithdrawOutcome false none 2500).withoutReleases := by
  decide

/-! For `returns: encrypted_to_client` only the ciphertext and tag are
released: payloads that differ only there are equal outside the releases, while
a differing nonce stays distinguished. -/

private def encryptedReturnOutcome
    (nonce ciphertext tag : String) : SGXPublicOutcome :=
  { entrypointId := "balanceOf(bytes32)"
  , publicArgs := []
  , publicEnv := []
  , terminationStatus := true
  , statusPolicy := "public"
  , outputShape := { returnPresent := true, returnLength := 48 }
  , returnPolicy := "encrypted_to_client"
  , returnPayload := none
  , encryptedReturnPayload :=
      some
        { binding :=
            { scheme := "x25519-chacha20poly1305"
            , sessionId := "session"
            , clientPublicKeyHash := "client"
            , attestationTranscriptHash := "transcript"
            }
        , aadHash := "aad"
        , nonce := nonce
        , ciphertext := ciphertext
        , tag := tag
        , plaintextCanonicalLen := 32
        , wireLen := 48
        }
  , declassifies := []
  , gasUsed := 2100
  }

example :
    (encryptedReturnOutcome "n1" "c1" "t1").withoutReleases =
      (encryptedReturnOutcome "n1" "c2" "t2").withoutReleases := by
  decide

example :
    (encryptedReturnOutcome "n1" "c1" "t1").withoutReleases ≠
      (encryptedReturnOutcome "n2" "c1" "t1").withoutReleases := by
  decide

end UOToolchain
