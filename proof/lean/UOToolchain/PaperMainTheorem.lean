import UOToolchain.SgxExactProjection
import UOToolchain.PathOramLocalPosmapV1

/-!
# Direct paper-main noninterference theorem

This module states the paper-facing theorem directly over the complete
normalized hostile-host observer.  The older SGX projection files remain the
proof machinery; this file fixes the theorem shape readers should cite.
-/

namespace UOToolchain

/-- Public rollback behavior included in the paper-main hostile-host view. -/
structure PaperMainFinalPublicStateRollback where
  initialPublicStateDigest : String
  candidatePublicStateDigest : String
  committedPublicStateDigest : String
  publicDeltaDigest : String
  aborted : Bool
deriving Repr, DecidableEq

/-- Declared release functions from the admitted package manifest. -/
structure PaperMainDeclaredReleaseFunctions where
  functions : List String
deriving Repr, DecidableEq

/-- The complete paper-facing SGX observer.  The fields intentionally name all
host-visible components required by the direct theorem statement: public
outcome, boundary schedule, storage trace, micro trace, final public
state/rollback behavior, and declared release functions. -/
structure PaperMainViewSGX where
  publicOutcome : SGXPublicOutcome
  boundarySchedule : List BoundaryEvent
  storageTrace : SGXStorageTrace
  microTrace : SGXMicroTrace
  finalPublicStateRollback : PaperMainFinalPublicStateRollback
  releaseFunctions : PaperMainDeclaredReleaseFunctions
deriving Repr, DecidableEq

/-- Paper notation for the complete hostile-host SGX observer. -/
abbrev View_SGX := PaperMainViewSGX

def paperMainViewOfSGX
  (finalPublicStateRollback : PaperMainFinalPublicStateRollback)
  (releaseFunctions : PaperMainDeclaredReleaseFunctions)
  (view : SGXView) : View_SGX :=
  { publicOutcome := sgxPublicOutcome view
  , boundarySchedule := view.boundarySchedule
  , storageTrace := sgxStorageTrace view
  , microTrace := sgxMicroTrace view
  , finalPublicStateRollback := finalPublicStateRollback
  , releaseFunctions := releaseFunctions
  }

structure PaperMainViewSGXComponentsEq (lhs rhs : View_SGX) : Prop where
  publicOutcome : lhs.publicOutcome = rhs.publicOutcome
  boundarySchedule : lhs.boundarySchedule = rhs.boundarySchedule
  storageTrace : lhs.storageTrace = rhs.storageTrace
  microTrace : lhs.microTrace = rhs.microTrace
  finalPublicStateRollback :
    lhs.finalPublicStateRollback = rhs.finalPublicStateRollback
  releaseFunctions : lhs.releaseFunctions = rhs.releaseFunctions

theorem PaperMainViewSGXComponentsEq.of_eq
  {lhs rhs : View_SGX}
  (hEq : lhs = rhs) :
  PaperMainViewSGXComponentsEq lhs rhs := by
  cases hEq
  exact
    { publicOutcome := rfl
    , boundarySchedule := rfl
    , storageTrace := rfl
    , microTrace := rfl
    , finalPublicStateRollback := rfl
    , releaseFunctions := rfl
    }

structure PaperMainExactNoninterferenceConclusion
  (lhs rhs : View_SGX) : Prop where
  view_SGX : lhs = rhs
  components : PaperMainViewSGXComponentsEq lhs rhs

def PaperMainPublicFieldSafe
  {κ : Type}
  (samePublic : κ → κ → Prop)
  (field : κ → α) : Prop :=
  ∀ cfg₁ cfg₂, samePublic cfg₁ cfg₂ → field cfg₁ = field cfg₂

abbrev PaperMainExactSameAdmittedPackagePublicInputsAndState
  (lhs rhs : Config) : Prop :=
  samePublicProjection lhs rhs

abbrev PaperMainPathOramSameAdmittedPackagePublicInputsAndState
  (lhs rhs : OramConfig) : Prop :=
  sameOramPublicProjection lhs rhs

theorem paperMainExact_sameAdmittedPackage_of_publicAgreement
  {lhs rhs : Config}
  (hPublic : PaperMainExactSameAdmittedPackagePublicInputsAndState lhs rhs) :
  lhs.program = rhs.program :=
  samePublicProjection_program_eq hPublic

theorem paperMainExact_publicInputs_of_publicAgreement
  {lhs rhs : Config}
  (hPublic : PaperMainExactSameAdmittedPackagePublicInputsAndState lhs rhs) :
  lhs.input.publicArgs = rhs.input.publicArgs :=
  samePublicProjection_publicArgs_eq hPublic

theorem paperMainExact_initialPublicState_of_publicAgreement
  {lhs rhs : Config}
  (hPublic : PaperMainExactSameAdmittedPackagePublicInputsAndState lhs rhs) :
  lhs.publicState = rhs.publicState :=
  samePublicProjection_publicState_eq hPublic

theorem paperMainPathOram_sameAdmittedPackage_of_publicAgreement
  {lhs rhs : OramConfig}
  (hPublic : PaperMainPathOramSameAdmittedPackagePublicInputsAndState lhs rhs) :
  lhs.pubData.witness = rhs.pubData.witness := by
  cases lhs
  cases rhs
  cases hPublic
  rfl

theorem paperMainPathOram_publicInputs_of_publicAgreement
  {lhs rhs : OramConfig}
  (hPublic : PaperMainPathOramSameAdmittedPackagePublicInputsAndState lhs rhs) :
  lhs.pubData.publicArgs = rhs.pubData.publicArgs := by
  cases lhs
  cases rhs
  cases hPublic
  rfl

theorem paperMainPathOram_initialPublicState_of_publicAgreement
  {lhs rhs : OramConfig}
  (hPublic : PaperMainPathOramSameAdmittedPackagePublicInputsAndState lhs rhs) :
  lhs.pubData.accessCounters = rhs.pubData.accessCounters := by
  cases lhs
  cases rhs
  cases hPublic
  rfl

def paperMainExactView
  (run : TraceSemantics)
  (publicOutcome : Config → SGXPublicOutcome)
  (boundarySchedule : Config → List BoundaryEvent)
  (controllerShape : Config → SGXControllerShape)
  (finalPublicStateRollback :
    Config → PaperMainFinalPublicStateRollback)
  (releaseFunctions : Config → PaperMainDeclaredReleaseFunctions)
  (cfg : Config) : View_SGX :=
  paperMainViewOfSGX
    (finalPublicStateRollback cfg)
    (releaseFunctions cfg)
    (sgxViewOfTrace
      cfg
      (publicOutcome cfg)
      (boundarySchedule cfg)
      (controllerMicroTraceOfShape (controllerShape cfg))
      (run cfg))

/-- Direct exact-backend paper-main theorem.  For two executions of the same
admitted package with equal public inputs, equal public initial state, and
equal declared release functions, the complete `View_SGX` is identical. -/
theorem paperMain_exact_backend_noninterference
  {run : TraceSemantics}
  {publicOutcome : Config → SGXPublicOutcome}
  {boundarySchedule : Config → List BoundaryEvent}
  {controllerShape : Config → SGXControllerShape}
  {finalPublicStateRollback :
    Config → PaperMainFinalPublicStateRollback}
  {releaseFunctions : Config → PaperMainDeclaredReleaseFunctions}
  (hExact : ExactUO run)
  (hOutcome : PublicOutcomeSafe publicOutcome)
  (hBoundary : PublicBoundarySafe boundarySchedule)
  (hController : PublicControllerShapeSafe controllerShape)
  (hFinal :
    PaperMainPublicFieldSafe
      samePublicProjection
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      samePublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : Config}
  (hPublic :
    PaperMainExactSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainExactNoninterferenceConclusion
    (paperMainExactView
      run
      publicOutcome
      boundarySchedule
      controllerShape
      finalPublicStateRollback
      releaseFunctions
      cfg₁)
    (paperMainExactView
      run
      publicOutcome
      boundarySchedule
      controllerShape
      finalPublicStateRollback
      releaseFunctions
      cfg₂) := by
  have hTrace : run cfg₁ = run cfg₂ :=
    viewMPlus_injective (hExact cfg₁ cfg₂ hPublic)
  have hOutcomeEq : publicOutcome cfg₁ = publicOutcome cfg₂ :=
    hOutcome cfg₁ cfg₂ hPublic
  have hBoundaryEq : boundarySchedule cfg₁ = boundarySchedule cfg₂ :=
    hBoundary cfg₁ cfg₂ hPublic
  have hControllerEq : controllerShape cfg₁ = controllerShape cfg₂ :=
    hController cfg₁ cfg₂ hPublic
  have hMicroEq :
      controllerMicroTraceOfShape (controllerShape cfg₁) =
        controllerMicroTraceOfShape (controllerShape cfg₂) :=
    controllerMicroTraceOfShape_eq_of_eq hControllerEq
  have hSGX :
      sgxViewOfTrace
          cfg₁
          (publicOutcome cfg₁)
          (boundarySchedule cfg₁)
          (controllerMicroTraceOfShape (controllerShape cfg₁))
          (run cfg₁) =
        sgxViewOfTrace
          cfg₂
          (publicOutcome cfg₂)
          (boundarySchedule cfg₂)
          (controllerMicroTraceOfShape (controllerShape cfg₂))
          (run cfg₂) :=
    sgxViewOfTrace_eq_of_trace_eq hOutcomeEq hBoundaryEq hMicroEq hTrace
  have hFinalEq :
      finalPublicStateRollback cfg₁ = finalPublicStateRollback cfg₂ :=
    hFinal cfg₁ cfg₂ hPublic
  have hReleaseEq :
      releaseFunctions cfg₁ = releaseFunctions cfg₂ :=
    hRelease cfg₁ cfg₂ hPublic
  have hView :
      paperMainExactView
          run
          publicOutcome
          boundarySchedule
          controllerShape
          finalPublicStateRollback
          releaseFunctions
          cfg₁ =
        paperMainExactView
          run
          publicOutcome
          boundarySchedule
          controllerShape
          finalPublicStateRollback
          releaseFunctions
          cfg₂ := by
    unfold paperMainExactView
    rw [hFinalEq, hReleaseEq, hSGX]
  exact
    { view_SGX := hView
    , components := PaperMainViewSGXComponentsEq.of_eq hView
    }

abbrev PathOramLocalPosmapV1StorageComponentIndistinguishable
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (storage₁ storage₂ : Distribution SGXStorageTrace)
  (leakage : List OramAccessLeakage) : Prop :=
  (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions).storageRel
    storage₁
    storage₂
    leakage

structure PaperMainPathOramLocalPosmapV1NoninterferenceConclusion
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (run : SGXSemantics OramConfig)
  (storageLeakage : OramConfig → List OramAccessLeakage)
  (microLeakage : OramConfig → SGXMicroLeakage)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions)
  (cfg₁ cfg₂ : OramConfig) : Prop where
  publicOutcome :
    ExactProjectionRelation sgxPublicOutcome (run cfg₁) (run cfg₂)
  boundarySchedule :
    ExactProjectionRelation (fun view : SGXView => view.boundarySchedule)
      (run cfg₁)
      (run cfg₂)
  storageTrace :
    PathOramLocalPosmapV1StorageComponentIndistinguishable
      assumptions
      (sgxStorageDistribution (run cfg₁))
      (sgxStorageDistribution (run cfg₂))
      (storageLeakage cfg₁)
  microTrace :
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions).microRel
      (sgxMicroDistribution (run cfg₁))
      (sgxMicroDistribution (run cfg₂))
      (microLeakage cfg₁)
  finalPublicStateRollback :
    finalPublicStateRollback cfg₁ = finalPublicStateRollback cfg₂
  releaseFunctions :
    releaseFunctions cfg₁ = releaseFunctions cfg₂

/-- Direct `path_oram_local_posmap_v1` paper-main theorem.  The complete
public observer components are equal, while the Path ORAM storage component is
related by the backend's computational storage relation. -/
theorem paperMain_pathOramLocalPosmapV1_noninterference
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
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hFinal :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramLocalPosmapV1NoninterferenceConclusion
    assumptions
    (oramToSGXSemantics
      run
      publicOutcome
      boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags)
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  have hSGX :
      SGXViewRelation
        (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
        ((oramToSGXSemantics
          run
          publicOutcome
          boundarySchedule
          oramControllerMicroTrace) cfg₁)
        ((oramToSGXSemantics
          run
          publicOutcome
          boundarySchedule
          oramControllerMicroTrace) cfg₂)
        (executionLeakage cfg₁)
        ((oramMicroLeakage publicOutcome modelTags) cfg₁) := by
    unfold pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
    exact
      paperMain_computationalUOWith_projects_to_sgxExecution
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        hOram
        hOutcome
        hBoundary
        cfg₁
        cfg₂
        hPublic
  exact
    { publicOutcome := hSGX.1
    , boundarySchedule := hSGX.2.1
    , storageTrace := hSGX.2.2.1
    , microTrace := hSGX.2.2.2
    , finalPublicStateRollback := hFinal cfg₁ cfg₂ hPublic
    , releaseFunctions := hRelease cfg₁ cfg₂ hPublic
    }

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMain_noninterference
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hFinal :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramLocalPosmapV1NoninterferenceConclusion
    assumptions
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags)
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  exact
    paperMain_pathOramLocalPosmapV1_noninterference
      assumptions
      (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
        assumptions)
      bundle.publicOutcomeSafe
      bundle.boundarySafe
      hFinal
      hRelease
      hPublic

end UOToolchain
