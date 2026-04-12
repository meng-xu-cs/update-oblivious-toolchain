import UOToolchain.SgxMicroGame

namespace UOToolchain

structure RuntimeOramAccessCertificate where
  objectId : Nat
  scheme : String
  metadataPagesPerAccess : Nat
  bucketsPerAccess : Nat
  recursionDepth : Nat
  stashBound : Nat
deriving Repr, DecidableEq

structure RuntimeControllerCertificate where
  entryInputLen : Nat
  observedOramAccesses : List RuntimeOramAccessCertificate
deriving Repr, DecidableEq

def runtimeControllerAccessBoundaryEvents : List BoundaryEvent :=
  [ { direction := .exit
    , apiId := "oram_access"
    , inputLen := 0
    , outputLen := 0
    }
  , { direction := .enter
    , apiId := "oram_access"
    , inputLen := 0
    , outputLen := 0
    }
  ]

def runtimeControllerAccessPhasePlan
  (access : RuntimeOramAccessCertificate) : List SGXControllerPhase :=
  [SGXControllerPhase.stageRequest] ++
    List.replicate access.recursionDepth SGXControllerPhase.descendPositionMap ++
    [ SGXControllerPhase.loadMetadata
    , SGXControllerPhase.fetchPath
    , SGXControllerPhase.scanStash
    , SGXControllerPhase.rewritePath
    ] ++
    List.replicate access.recursionDepth SGXControllerPhase.ascendPositionMap

def RuntimeControllerCertificate.boundarySchedule
  (certificate : RuntimeControllerCertificate)
  (publicOutcome : SGXPublicOutcome) : List BoundaryEvent :=
  [ { direction := .enter
    , apiId := publicOutcome.entrypointId
    , inputLen := certificate.entryInputLen
    , outputLen := 0
    }
  ] ++
    concatLists
      (List.replicate certificate.observedOramAccesses.length runtimeControllerAccessBoundaryEvents) ++
    [ { direction := .exit
      , apiId := publicOutcome.entrypointId
      , inputLen := 0
      , outputLen := publicOutcome.outputShape.returnLength
      }
    ]

def RuntimeControllerCertificate.controllerShape
  (certificate : RuntimeControllerCertificate) : SGXControllerShape :=
  let phaseTrace :=
    [SGXControllerPhase.enclaveEnter] ++
      concatLists
        (certificate.observedOramAccesses.map runtimeControllerAccessPhasePlan) ++
      [SGXControllerPhase.sealPersistentState, SGXControllerPhase.enclaveExit]
  let pageTraceRegions :=
    [ { pageKind := "metadata"
      , eventBudget := certificate.observedOramAccesses.foldl
          (fun acc access => acc + access.metadataPagesPerAccess)
          0
      }
    , { pageKind := "position_map"
      , eventBudget := certificate.observedOramAccesses.foldl
          (fun acc access => acc + access.recursionDepth)
          0
      }
    , { pageKind := "path"
      , eventBudget := certificate.observedOramAccesses.foldl
          (fun acc access => acc + access.bucketsPerAccess)
          0
      }
    , { pageKind := "stash"
      , eventBudget := certificate.observedOramAccesses.foldl
          (fun acc access => acc + access.stashBound)
          0
      }
    ]
  let worksetRegions :=
    [ { pageKind := "metadata"
      , eventBudget := maxNatList
          (certificate.observedOramAccesses.map fun access => access.metadataPagesPerAccess)
      }
    , { pageKind := "position_map"
      , eventBudget := maxNatList
          (certificate.observedOramAccesses.map fun access => access.recursionDepth)
      }
    , { pageKind := "path"
      , eventBudget := maxNatList
          (certificate.observedOramAccesses.map fun access => access.bucketsPerAccess)
      }
    , { pageKind := "stash"
      , eventBudget := maxNatList
          (certificate.observedOramAccesses.map fun access => access.stashBound)
      }
    ]
  let totalAccesses := certificate.observedOramAccesses.length
  let pageTraceBudget := totalPageBudget pageTraceRegions
  { boundaryEventBudget := 2 * totalAccesses + 2
  , phaseTrace := phaseTrace
  , pageTraceRegions := pageTraceRegions
  , worksetRegions := worksetRegions
  , exitTraceBudget := phaseTrace.length + totalAccesses + 1
  , sharedResourceBudget := phaseTrace.length + pageTraceBudget
  , recursivePositionMapDepth := maxNatList
      (certificate.observedOramAccesses.map fun access => access.recursionDepth)
  , stashBound := maxNatList
      (certificate.observedOramAccesses.map fun access => access.stashBound)
  }

@[simp] theorem runtimeControllerAccessBoundaryEvents_length :
  runtimeControllerAccessBoundaryEvents.length = 2 := by
  rfl

@[simp] theorem concatLists_replicate_runtimeControllerAccessBoundaryEvents_length
  (count : Nat) :
  (concatLists (List.replicate count runtimeControllerAccessBoundaryEvents)).length =
    2 * count := by
  induction count with
  | zero =>
      simp [concatLists]
  | succ count ih =>
      simp [List.replicate, concatLists, ih, Nat.mul_add, Nat.add_comm]

@[simp] theorem runtimeControllerCertificate_boundarySchedule_length
  (certificate : RuntimeControllerCertificate)
  (publicOutcome : SGXPublicOutcome) :
  (certificate.boundarySchedule publicOutcome).length =
    2 * certificate.observedOramAccesses.length + 2 := by
  simp [RuntimeControllerCertificate.boundarySchedule]

@[simp] theorem runtimeControllerCertificate_boundarySchedule_budget
  (certificate : RuntimeControllerCertificate)
  (publicOutcome : SGXPublicOutcome) :
  (certificate.boundarySchedule publicOutcome).length =
    certificate.controllerShape.boundaryEventBudget := by
  simp [RuntimeControllerCertificate.controllerShape,
    runtimeControllerCertificate_boundarySchedule_length]

structure RuntimeRefinementWitness where
  trace : Trace
  publicOutcome : SGXPublicOutcome
  boundarySchedule : List BoundaryEvent
  controllerShape : SGXControllerShape
  normalizedMicroTrace : NormalizedMicroTrace
  controllerCertificate : RuntimeControllerCertificate
deriving Repr, DecidableEq

def RuntimeRefinementWitness.storageTrace
  (witness : RuntimeRefinementWitness) : SGXStorageTrace :=
  { persistentReads := witness.trace.physicalReads
  , persistentWrites := witness.trace.physicalWrites
  }

def RuntimeRefinementWitness.microLeakage
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : SGXMicroLeakage :=
  sgxMicroLeakageOfController witness.publicOutcome modelTags witness.controllerShape

def RuntimeRefinementWitness.reconstructedMicroTrace
  (witness : RuntimeRefinementWitness) : SGXMicroTrace :=
  controllerMicroTraceOfShape witness.controllerShape

def RuntimeRefinementWitness.sgxView
  (witness : RuntimeRefinementWitness) : SGXView :=
  let microTrace := witness.reconstructedMicroTrace
  { entrypointId := witness.publicOutcome.entrypointId
  , publicArgs := witness.publicOutcome.publicArgs
  , boundarySchedule := witness.boundarySchedule
  , persistentReads := witness.trace.physicalReads
  , persistentWrites := witness.trace.physicalWrites
  , pageTrace := microTrace.pageTrace
  , exitTrace := microTrace.exitTrace
  , sharedResourceTrace := microTrace.sharedResourceTrace
  , terminationStatus := witness.publicOutcome.terminationStatus
  , outputShape := witness.publicOutcome.outputShape
  , gasUsed := witness.publicOutcome.gasUsed
  }

def RuntimeRefinementWitness.Valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.trace.gasUsed = witness.publicOutcome.gasUsed ∧
    witness.boundarySchedule =
      witness.controllerCertificate.boundarySchedule witness.publicOutcome ∧
    witness.controllerShape = witness.controllerCertificate.controllerShape ∧
    witness.normalizedMicroTrace =
      simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags)

def RuntimeRefinementWitness.checkValid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  decide (witness.trace.gasUsed = witness.publicOutcome.gasUsed) &&
    decide
      (witness.boundarySchedule =
        witness.controllerCertificate.boundarySchedule witness.publicOutcome) &&
    decide (witness.controllerShape = witness.controllerCertificate.controllerShape) &&
    decide
      (witness.normalizedMicroTrace =
        simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags))

@[simp] theorem runtimeWitness_checkValid_eq_true_iff
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkValid modelTags = true ↔ witness.Valid modelTags := by
  simp [RuntimeRefinementWitness.checkValid, RuntimeRefinementWitness.Valid, and_assoc]

@[simp] theorem sgxPublicOutcome_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  sgxPublicOutcome witness.sgxView = witness.publicOutcome := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, sgxPublicOutcome,
    RuntimeRefinementWitness.reconstructedMicroTrace]

@[simp] theorem sgxBoundary_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  witness.sgxView.boundarySchedule = witness.boundarySchedule := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, RuntimeRefinementWitness.reconstructedMicroTrace]

@[simp] theorem sgxStorageTrace_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  sgxStorageTrace witness.sgxView = witness.storageTrace := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, RuntimeRefinementWitness.storageTrace,
    sgxStorageTrace, RuntimeRefinementWitness.reconstructedMicroTrace]

@[simp] theorem sgxMicroTrace_runtimeWitness
  (witness : RuntimeRefinementWitness) :
  sgxMicroTrace witness.sgxView = witness.reconstructedMicroTrace := by
  cases witness
  simp [RuntimeRefinementWitness.sgxView, sgxMicroTrace,
    RuntimeRefinementWitness.reconstructedMicroTrace]

theorem reconstructedMicroTrace_normalizedByLeakage
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  normalizeMicroTrace witness.reconstructedMicroTrace =
    simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags) := by
  cases witness
  simp [RuntimeRefinementWitness.reconstructedMicroTrace,
    RuntimeRefinementWitness.microLeakage]
  exact normalizeMicroTrace_controllerMicroTraceOfShape _ _ _

theorem sgxView_normalizedMicro_eq_witness
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  normalizeMicroTrace (sgxMicroTrace witness.sgxView) = witness.normalizedMicroTrace := by
  rcases hValid with ⟨_hGas, _hBoundary, _hShape, hNormalized⟩
  rw [sgxMicroTrace_runtimeWitness]
  rw [reconstructedMicroTrace_normalizedByLeakage]
  exact hNormalized.symm

theorem runtimeWitness_boundaryBudget_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.boundarySchedule.length = witness.controllerShape.boundaryEventBudget := by
  rcases hValid with ⟨_hGas, hBoundary, hShape, _hNormalized⟩
  rw [hBoundary, hShape]
  exact runtimeControllerCertificate_boundarySchedule_budget
    witness.controllerCertificate
    witness.publicOutcome

theorem runtimeWitness_publicOutcome_gas_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.trace.gasUsed = witness.publicOutcome.gasUsed := by
  exact hValid.1

theorem runtimeWitness_projects_to_paper_observer
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  sgxPublicOutcome witness.sgxView = witness.publicOutcome ∧
    witness.sgxView.boundarySchedule = witness.boundarySchedule ∧
    sgxStorageTrace witness.sgxView = witness.storageTrace ∧
    normalizeMicroTrace (sgxMicroTrace witness.sgxView) = witness.normalizedMicroTrace := by
  refine ⟨sgxPublicOutcome_runtimeWitness witness, sgxBoundary_runtimeWitness witness, ?_, ?_⟩
  · exact sgxStorageTrace_runtimeWitness witness
  · exact sgxView_normalizedMicro_eq_witness witness modelTags hValid

end UOToolchain
