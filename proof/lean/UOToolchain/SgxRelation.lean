import UOToolchain.SgxBoundary

/-! # SGX view-relation layer

This file projects an `SGXView` into its component public outcome,
storage trace, and micro trace, and ties together the pieces a
paper-grade SGX security claim consumes:

* **Abstraction function:** `sgxViewOfDeployment` (lifts a
  `DeploymentResult` to an `SGXView`). The companion
  `deploymentToSGXSemantics` lifts a `DeploymentSemantics` to an
  `SGXSemantics Config`.
* **Main theorem:** `exactTEEStorage_projects_to_exactSGX` — every
  deployment satisfying `ExactTEEStorageOblivious` lifts to
  `SGXExecutionSecurity` against `exactSGXProofRelation`.

The file also defines the foundational predicates
`ExactProjectionRelation`, `SGXViewRelation`, `SGXExecutionSecurity`,
`PublicStorageLeakage`, `PublicMicroLeakage` consumed by the rest of
the SGX projection chain (`SgxExactProjection.lean`,
`SgxOramProjection.lean`, `SgxJointProjection.lean`). -/

namespace UOToolchain

structure SGXPublicOutcome where
  entrypointId : String
  publicArgs : List String
  terminationStatus : Bool
  statusPolicy : String
  outputShape : OutputShape
  returnPolicy : String
  returnPayload : Option String
  encryptedReturnPayload : Option EncryptedReturnPayload
  declassifies : List String
  gasUsed : Nat
deriving Repr, DecidableEq

structure SGXStorageTrace where
  persistentReads : List PhysicalRead
  persistentWrites : List PhysicalWrite
deriving Repr, DecidableEq

structure SGXMicroTrace where
  pageTrace : List PageEvent
  exitTrace : List ExitEvent
  sharedResourceTrace : SharedResourceTrace
deriving Repr, DecidableEq

structure SGXModelTags where
  pageModel : String
  exitModel : String
  sharedResourceModel : String
deriving Repr, DecidableEq

inductive SGXControllerPhase where
  | enclaveEnter
  | stageRequest
  | descendPositionMap
  | loadMetadata
  | fetchPath
  | scanStash
  | rewritePath
  | ascendPositionMap
  | sealPersistentState
  | enclaveExit
deriving Repr, DecidableEq

structure SGXControllerPageBudget where
  pageKind : String
  eventBudget : Nat
deriving Repr, DecidableEq

structure SGXMicroLeakage where
  publicOutcome : SGXPublicOutcome
  modelTags : SGXModelTags
  boundaryEventBudget : Nat
  controllerPhaseCount : Nat
  controllerPhaseOrder : List SGXControllerPhase
  pageTraceBudget : Nat
  pageTraceRegions : List SGXControllerPageBudget
  exitTraceBudget : Nat
  normalizedExitPattern : List ExitEvent
  sharedResourceBudget : Nat
  sharedResourcePattern : SharedResourceTrace
  controllerWorksetPages : Nat
  worksetRegions : List SGXControllerPageBudget
  recursivePositionMapDepth : Nat
  stashBound : Nat
deriving Repr, DecidableEq

def sgxPublicOutcome (view : SGXView) : SGXPublicOutcome :=
  { entrypointId := view.entrypointId
  , publicArgs := view.publicArgs
  , terminationStatus := view.terminationStatus
  , statusPolicy := view.statusPolicy
  , outputShape := view.outputShape
  , returnPolicy := view.returnPolicy
  , returnPayload := view.returnPayload
  , encryptedReturnPayload := view.encryptedReturnPayload
  , declassifies := view.declassifies
  , gasUsed := view.gasUsed
  }

def sgxStorageTrace (view : SGXView) : SGXStorageTrace :=
  { persistentReads := view.persistentReads
  , persistentWrites := view.persistentWrites
  }

def sgxMicroTrace (view : SGXView) : SGXMicroTrace :=
  { pageTrace := view.pageTrace
  , exitTrace := view.exitTrace
  , sharedResourceTrace := view.sharedResourceTrace
  }

def microLeakageOfView (tags : SGXModelTags) (view : SGXView) : SGXMicroLeakage :=
  { publicOutcome := sgxPublicOutcome view
  , modelTags := tags
  , boundaryEventBudget := 0
  , controllerPhaseCount := 0
  , controllerPhaseOrder := []
  , pageTraceBudget := 0
  , pageTraceRegions := []
  , exitTraceBudget := 0
  , normalizedExitPattern := []
  , sharedResourceBudget := 0
  , sharedResourcePattern := []
  , controllerWorksetPages := 0
  , worksetRegions := []
  , recursivePositionMapDepth := 0
  , stashBound := 0
  }

def sgxPublicOutcomeDistribution (views : Distribution SGXView) : Distribution SGXPublicOutcome :=
  views.map sgxPublicOutcome

def sgxBoundaryDistribution (views : Distribution SGXView) : Distribution (List BoundaryEvent) :=
  views.map (fun view => view.boundarySchedule)

def sgxStorageDistribution (views : Distribution SGXView) : Distribution SGXStorageTrace :=
  views.map sgxStorageTrace

def sgxMicroDistribution (views : Distribution SGXView) : Distribution SGXMicroTrace :=
  views.map sgxMicroTrace

def ConstantProjection
  {α β : Type}
  (project : α → β)
  (views : Distribution α)
  (value : β) : Prop :=
  ∀ view, view ∈ views → project view = value

def ExactProjectionRelation
  {α β : Type}
  (project : α → β)
  (views₁ views₂ : Distribution α) : Prop :=
  ∃ value,
    ConstantProjection project views₁ value ∧
    ConstantProjection project views₂ value

theorem exactProjectionRelation_of_constant
  {α β : Type}
  {project : α → β}
  {views₁ views₂ : Distribution α}
  {value₁ value₂ : β}
  (hValue : value₁ = value₂)
  (hViews₁ : ConstantProjection project views₁ value₁)
  (hViews₂ : ConstantProjection project views₂ value₂) :
  ExactProjectionRelation project views₁ views₂ := by
  refine ⟨value₁, hViews₁, ?_⟩
  intro view hMem
  rw [hValue]
  exact hViews₂ view hMem

theorem constantProjection_map_of_const
  {α β γ : Type}
  (project : β → γ)
  (value : γ)
  (f : α → β)
  (views : Distribution α)
  (hConst : ∀ view, view ∈ views → project (f view) = value) :
  ConstantProjection project (views.map f) value := by
  intro projectedView hMem
  simp at hMem
  rcases hMem with ⟨view, hView, rfl⟩
  exact hConst view hView

abbrev SGXStorageRelation :=
  Distribution SGXStorageTrace → Distribution SGXStorageTrace → List OramAccessLeakage → Prop

abbrev SGXMicroRelation :=
  Distribution SGXMicroTrace → Distribution SGXMicroTrace → SGXMicroLeakage → Prop

structure SGXProofRelation where
  storageRel : SGXStorageRelation
  microRel : SGXMicroRelation

def SGXViewRelation
  (R : SGXProofRelation)
  (views₁ views₂ : Distribution SGXView)
  (storageLeakage : List OramAccessLeakage)
  (microLeakage : SGXMicroLeakage) : Prop :=
  ExactProjectionRelation sgxPublicOutcome views₁ views₂ ∧
  ExactProjectionRelation (fun view => view.boundarySchedule) views₁ views₂ ∧
  R.storageRel (sgxStorageDistribution views₁) (sgxStorageDistribution views₂) storageLeakage ∧
  R.microRel (sgxMicroDistribution views₁) (sgxMicroDistribution views₂) microLeakage

def exactSGXStorageRelation : SGXStorageRelation :=
  fun storage₁ storage₂ _leakage => storage₁ = storage₂

def exactSGXMicroRelation : SGXMicroRelation :=
  fun micro₁ micro₂ _leakage => micro₁ = micro₂

def exactSGXProofRelation : SGXProofRelation :=
  { storageRel := exactSGXStorageRelation
  , microRel := exactSGXMicroRelation
  }

def PublicStorageLeakage
  {κ : Type}
  (samePublic : κ → κ → Prop)
  (storageLeakage : κ → List OramAccessLeakage) : Prop :=
  ∀ cfg₁ cfg₂, samePublic cfg₁ cfg₂ → storageLeakage cfg₁ = storageLeakage cfg₂

def PublicMicroLeakage
  {κ : Type}
  (samePublic : κ → κ → Prop)
  (microLeakage : κ → SGXMicroLeakage) : Prop :=
  ∀ cfg₁ cfg₂, samePublic cfg₁ cfg₂ → microLeakage cfg₁ = microLeakage cfg₂

def SGXExecutionSecurity
  {κ : Type}
  (samePublic : κ → κ → Prop)
  (R : SGXProofRelation)
  (run : SGXSemantics κ)
  (storageLeakage : κ → List OramAccessLeakage)
  (microLeakage : κ → SGXMicroLeakage) : Prop :=
  ∀ cfg₁ cfg₂,
    samePublic cfg₁ cfg₂ →
    SGXViewRelation R (run cfg₁) (run cfg₂) (storageLeakage cfg₁) (microLeakage cfg₁)

theorem microLeakageOfView_eq_of_publicOutcome_eq
  {tags : SGXModelTags}
  {lhs rhs : SGXView} :
  sgxPublicOutcome lhs = sgxPublicOutcome rhs →
  microLeakageOfView tags lhs = microLeakageOfView tags rhs := by
  intro h
  simp [microLeakageOfView, h]

theorem exactProjectionRelation_singleton
  {α β : Type}
  (project : α → β)
  (lhs rhs : α)
  (hProject : project lhs = project rhs) :
  ExactProjectionRelation project [lhs] [rhs] := by
  refine ⟨project lhs, ?_, ?_⟩
  · intro view hMem
    simp at hMem
    simp [hMem]
  · intro view hMem
    simp at hMem
    simp [hMem, hProject]

theorem exactSGXViewRelation_of_singleton_eq
  {view₁ view₂ : SGXView}
  (hEq : view₁ = view₂)
  (storageLeakage : List OramAccessLeakage)
  (microLeakage : SGXMicroLeakage) :
  SGXViewRelation exactSGXProofRelation [view₁] [view₂] storageLeakage microLeakage := by
  subst hEq
  constructor
  · exact exactProjectionRelation_singleton sgxPublicOutcome view₁ view₁ rfl
  constructor
  · exact exactProjectionRelation_singleton (fun view => view.boundarySchedule) view₁ view₁ rfl
  · simp [exactSGXProofRelation, exactSGXStorageRelation, exactSGXMicroRelation]

def sgxViewOfDeployment (cfg : Config) (result : DeploymentResult) : SGXView :=
  { entrypointId := cfg.program.entrypoint
  , publicArgs := cfg.input.publicArgs
  , boundarySchedule := []
  , persistentReads := result.trace.physicalReads
  , persistentWrites := result.trace.physicalWrites
  , pageTrace := []
  , exitTrace := []
  , sharedResourceTrace := []
  , terminationStatus := result.terminationStatus
  , statusPolicy := "public"
  , outputShape := result.outputShape
  , returnPolicy := "forbidden"
  , returnPayload := none
  , encryptedReturnPayload := none
  , declassifies := []
  , gasUsed := result.trace.gasUsed
  }

def deploymentToSGXSemantics (run : DeploymentSemantics) : SGXSemantics Config :=
  fun cfg => [sgxViewOfDeployment cfg (run cfg)]

def emptyStorageLeakage : Config → List OramAccessLeakage :=
  fun _ => []

def deploymentMicroLeakage
  (run : DeploymentSemantics)
  (tags : SGXModelTags) : Config → SGXMicroLeakage :=
  fun cfg => microLeakageOfView tags (sgxViewOfDeployment cfg (run cfg))

theorem sgxViewOfDeployment_eq_of_viewTEEStore_eq
  {cfg₁ cfg₂ : Config}
  {result₁ result₂ : DeploymentResult} :
  viewTEEStore cfg₁ result₁ = viewTEEStore cfg₂ result₂ →
  sgxViewOfDeployment cfg₁ result₁ = sgxViewOfDeployment cfg₂ result₂ := by
  intro h
  cases cfg₁
  cases cfg₂
  cases result₁
  cases result₂
  simp [viewTEEStore, sgxViewOfDeployment] at h ⊢
  rcases h with ⟨hEntry, hArgs, hTerm, hOutput, hReads, hWrites, hGas⟩
  exact ⟨hEntry, hArgs, hReads, hWrites, hTerm, hOutput, hGas⟩

theorem exactTEEStorage_projects_to_exactSGX
  {run : DeploymentSemantics}
  (tags : SGXModelTags)
  (hTEE : ExactTEEStorageOblivious run) :
  SGXExecutionSecurity
    samePublicProjection
    exactSGXProofRelation
    (deploymentToSGXSemantics run)
    emptyStorageLeakage
    (deploymentMicroLeakage run tags) := by
  intro cfg₁ cfg₂ hPublic
  have hTEEView : viewTEEStore cfg₁ (run cfg₁) = viewTEEStore cfg₂ (run cfg₂) :=
    hTEE cfg₁ cfg₂ hPublic
  have hSGXView : sgxViewOfDeployment cfg₁ (run cfg₁) = sgxViewOfDeployment cfg₂ (run cfg₂) :=
    sgxViewOfDeployment_eq_of_viewTEEStore_eq hTEEView
  simpa [deploymentToSGXSemantics] using
    exactSGXViewRelation_of_singleton_eq hSGXView [] (deploymentMicroLeakage run tags cfg₁)

end UOToolchain
