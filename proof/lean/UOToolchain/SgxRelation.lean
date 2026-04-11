import UOToolchain.SgxBoundary

namespace UOToolchain

structure SGXPublicOutcome where
  entrypointId : String
  publicArgs : List String
  terminationStatus : Bool
  outputShape : OutputShape
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

structure SGXMicroLeakage where
  publicOutcome : SGXPublicOutcome
  modelTags : SGXModelTags
deriving Repr, DecidableEq

def sgxPublicOutcome (view : SGXView) : SGXPublicOutcome :=
  { entrypointId := view.entrypointId
  , publicArgs := view.publicArgs
  , terminationStatus := view.terminationStatus
  , outputShape := view.outputShape
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
  }

def sgxPublicOutcomeDistribution (views : Distribution SGXView) : Distribution SGXPublicOutcome :=
  views.map sgxPublicOutcome

def sgxBoundaryDistribution (views : Distribution SGXView) : Distribution (List BoundaryEvent) :=
  views.map (fun view => view.boundarySchedule)

def sgxStorageDistribution (views : Distribution SGXView) : Distribution SGXStorageTrace :=
  views.map sgxStorageTrace

def sgxMicroDistribution (views : Distribution SGXView) : Distribution SGXMicroTrace :=
  views.map sgxMicroTrace

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
  sgxPublicOutcomeDistribution views₁ = sgxPublicOutcomeDistribution views₂ ∧
  sgxBoundaryDistribution views₁ = sgxBoundaryDistribution views₂ ∧
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

theorem exactSGXViewRelation_of_eq
  {views₁ views₂ : Distribution SGXView}
  (hEq : views₁ = views₂)
  (storageLeakage : List OramAccessLeakage)
  (microLeakage : SGXMicroLeakage) :
  SGXViewRelation exactSGXProofRelation views₁ views₂ storageLeakage microLeakage := by
  subst hEq
  simp [SGXViewRelation, exactSGXProofRelation, exactSGXStorageRelation, exactSGXMicroRelation]

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
  , outputShape := result.outputShape
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
  apply exactSGXViewRelation_of_eq
  simp [deploymentToSGXSemantics, hSGXView]

end UOToolchain
