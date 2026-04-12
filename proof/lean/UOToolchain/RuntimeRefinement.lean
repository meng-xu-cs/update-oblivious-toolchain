import UOToolchain.PathOramSecurity
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

structure RuntimeOramObjectCertificate where
  objectId : Nat
  objectName : String
  scheme : String
  capacity : Nat
  blockSize : Nat
  bucketSize : Nat
  bucketCount : Nat
  blocksPerBucket : Nat
  treeHeight : Nat
  stashBound : Nat
  recursionDepth : Nat
  metadataPages : Nat
  metadataPagesPerAccess : Nat
  bucketsPerAccess : Nat
  accessesPerCall : Nat
deriving Repr, DecidableEq

structure RuntimeControllerCertificate where
  entryInputLen : Nat
  observedOramAccesses : List RuntimeOramAccessCertificate
deriving Repr, DecidableEq

structure RuntimeOramLeafCertificate where
  objectId : Nat
  objectName : String
  bucketCount : Nat
  leaf : Nat
deriving Repr, DecidableEq

structure RuntimePathOramLeafScaffoldStep where
  objectId : Nat
  objectName : String
  bucketCount : Nat
deriving Repr, DecidableEq

def RuntimeOramObjectCertificate.accessCertificate
  (object : RuntimeOramObjectCertificate) : RuntimeOramAccessCertificate :=
  { objectId := object.objectId
  , scheme := object.scheme
  , metadataPagesPerAccess := object.metadataPagesPerAccess
  , bucketsPerAccess := object.bucketsPerAccess
  , recursionDepth := object.recursionDepth
  , stashBound := object.stashBound
  }

def RuntimeOramObjectCertificate.metadataEventKind?
  (object : RuntimeOramObjectCertificate) : Option String :=
  match object.scheme with
  | "surrogate_public_schedule_v1" => some "uooram_meta_scan"
  | "path_oram_local_posmap_v1" => some "uooram_metadata_load"
  | _ => none

def RuntimeOramObjectCertificate.bucketEventKind?
  (object : RuntimeOramObjectCertificate) : Option String :=
  match object.scheme with
  | "surrogate_public_schedule_v1" => some "uooram_bucket_scan"
  | "path_oram_local_posmap_v1" => some "uooram_path_read"
  | _ => none

def RuntimeOramObjectCertificate.isPathOram
  (object : RuntimeOramObjectCertificate) : Bool :=
  object.scheme = pathOramScheme

def RuntimeOramLeafCertificate.toPathOramLeafScheduleStep
  (leaf : RuntimeOramLeafCertificate) : PathOramLeafScheduleStep :=
  { object := leaf.objectName
  , bucketCount := leaf.bucketCount
  , leaf := leaf.leaf
  }

def RuntimeOramLeafCertificate.scaffoldStep
  (leaf : RuntimeOramLeafCertificate) : RuntimePathOramLeafScaffoldStep :=
  { objectId := leaf.objectId
  , objectName := leaf.objectName
  , bucketCount := leaf.bucketCount
  }

def runtimeOramObjectByName?
  (oramObjects : List RuntimeOramObjectCertificate)
  (objectName : String) : Option RuntimeOramObjectCertificate :=
  oramObjects.find? (fun object => object.objectName = objectName)

def isOramLogicalKind (kind : String) : Bool :=
  kind = "uooram_counter" ||
    kind = "uooram_meta_scan" ||
    kind = "uooram_bucket_scan" ||
    kind = "uooram_metadata_load" ||
    kind = "uooram_path_read"

def consumeExpectedOramLogicalEvents
  (events : List LogicalEvent)
  (objectName : String)
  (expectedKind : String)
  (expectedCount : Nat)
  (detailPrefix : String) : Option (List LogicalEvent) :=
  match expectedCount, events with
  | 0, _ => some events
  | _ + 1, [] => none
  | count + 1, event :: events =>
      if event.object = objectName &&
          event.kind = expectedKind &&
          event.detail.startsWith detailPrefix then
        consumeExpectedOramLogicalEvents events objectName expectedKind count detailPrefix
      else
        none

def reconstructObservedOramAccessesFromLogicalTraceAux
  (fuel : Nat)
  (logicalAccesses : List LogicalEvent)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option (List RuntimeOramAccessCertificate) :=
  match fuel with
  | 0 =>
      match logicalAccesses with
      | [] => some []
      | _ => none
  | fuel + 1 =>
      match logicalAccesses with
      | [] => some []
      | event :: events =>
          if !(isOramLogicalKind event.kind) then
            reconstructObservedOramAccessesFromLogicalTraceAux fuel events oramObjects
          else if event.kind != "uooram_counter" || event.detail != "counter" then
            none
          else
            do
            let object ← runtimeOramObjectByName? oramObjects event.object
            let metadataKind ← object.metadataEventKind?
            let bucketKind ← object.bucketEventKind?
            let events ←
              consumeExpectedOramLogicalEvents
                events
                event.object
                metadataKind
                object.metadataPages
                "page:"
            let events ←
              consumeExpectedOramLogicalEvents
                events
                event.object
                bucketKind
                object.bucketsPerAccess
                "bucket:"
            let accesses ← reconstructObservedOramAccessesFromLogicalTraceAux fuel events oramObjects
            some (object.accessCertificate :: accesses)

def reconstructObservedOramAccessesFromLogicalTrace
  (logicalAccesses : List LogicalEvent)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option (List RuntimeOramAccessCertificate) :=
  reconstructObservedOramAccessesFromLogicalTraceAux logicalAccesses.length logicalAccesses oramObjects

def reconstructPathOramLeafScaffoldFromLogicalTraceAux
  (fuel : Nat)
  (logicalAccesses : List LogicalEvent)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option (List RuntimePathOramLeafScaffoldStep) :=
  match fuel with
  | 0 =>
      match logicalAccesses with
      | [] => some []
      | _ => none
  | fuel + 1 =>
      match logicalAccesses with
      | [] => some []
      | event :: events =>
          if !(isOramLogicalKind event.kind) then
            reconstructPathOramLeafScaffoldFromLogicalTraceAux fuel events oramObjects
          else if event.kind != "uooram_counter" || event.detail != "counter" then
            none
          else
            do
            let object ← runtimeOramObjectByName? oramObjects event.object
            let metadataKind ← object.metadataEventKind?
            let bucketKind ← object.bucketEventKind?
            let events ←
              consumeExpectedOramLogicalEvents
                events
                event.object
                metadataKind
                object.metadataPages
                "page:"
            let events ←
              consumeExpectedOramLogicalEvents
                events
                event.object
                bucketKind
                object.bucketsPerAccess
                "bucket:"
            let scaffold ←
              reconstructPathOramLeafScaffoldFromLogicalTraceAux fuel events oramObjects
            if object.isPathOram then
              some
                ({ objectId := object.objectId
                 , objectName := object.objectName
                 , bucketCount := object.bucketCount
                 } :: scaffold)
            else
              some scaffold

def reconstructPathOramLeafScaffoldFromLogicalTrace
  (logicalAccesses : List LogicalEvent)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option (List RuntimePathOramLeafScaffoldStep) :=
  reconstructPathOramLeafScaffoldFromLogicalTraceAux
    logicalAccesses.length
    logicalAccesses
    oramObjects

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
  oramObjects : List RuntimeOramObjectCertificate
  oramLeafSchedule : List RuntimeOramLeafCertificate
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

def RuntimeRefinementWitness.pathOramLeafScheduleTrace
  (witness : RuntimeRefinementWitness) : PathOramLeafScheduleTrace :=
  witness.oramLeafSchedule.map RuntimeOramLeafCertificate.toPathOramLeafScheduleStep

def RuntimeRefinementWitness.pathOramLeafScaffold
  (witness : RuntimeRefinementWitness) : List RuntimePathOramLeafScaffoldStep :=
  witness.oramLeafSchedule.map RuntimeOramLeafCertificate.scaffoldStep

def RuntimeRefinementWitness.pathOramBucketTrace
  (witness : RuntimeRefinementWitness) : PathOramBucketTrace :=
  pathOramBucketTraceOfView (viewMPlus witness.trace)

def RuntimeRefinementWitness.Valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.trace.gasUsed = witness.publicOutcome.gasUsed ∧
    witness.boundarySchedule =
      witness.controllerCertificate.boundarySchedule witness.publicOutcome ∧
    witness.controllerShape = witness.controllerCertificate.controllerShape ∧
    reconstructObservedOramAccessesFromLogicalTrace
        witness.trace.logicalAccesses
        witness.oramObjects =
      some witness.controllerCertificate.observedOramAccesses ∧
    reconstructPathOramLeafScaffoldFromLogicalTrace
        witness.trace.logicalAccesses
        witness.oramObjects =
      some witness.pathOramLeafScaffold ∧
    pathOramBucketTraceOfLeafScheduleTrace witness.pathOramLeafScheduleTrace =
      witness.pathOramBucketTrace ∧
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
      (reconstructObservedOramAccessesFromLogicalTrace
          witness.trace.logicalAccesses
          witness.oramObjects =
        some witness.controllerCertificate.observedOramAccesses) &&
    decide
      (reconstructPathOramLeafScaffoldFromLogicalTrace
          witness.trace.logicalAccesses
          witness.oramObjects =
        some witness.pathOramLeafScaffold) &&
    decide
      (pathOramBucketTraceOfLeafScheduleTrace witness.pathOramLeafScheduleTrace =
        witness.pathOramBucketTrace) &&
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
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hLeafBuckets, hNormalized⟩
  rw [sgxMicroTrace_runtimeWitness]
  rw [reconstructedMicroTrace_normalizedByLeakage]
  exact hNormalized.symm

theorem runtimeWitness_boundaryBudget_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.boundarySchedule.length = witness.controllerShape.boundaryEventBudget := by
  rcases hValid with
    ⟨_hGas, hBoundary, hShape, _hAccesses, _hLeafScaffold, _hLeafBuckets, _hNormalized⟩
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

theorem runtimeWitness_pathOramLeafScaffold_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  reconstructPathOramLeafScaffoldFromLogicalTrace
      witness.trace.logicalAccesses
      witness.oramObjects =
    some witness.pathOramLeafScaffold := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, hLeafScaffold, _hLeafBuckets, _hNormalized⟩
  exact hLeafScaffold

theorem runtimeWitness_pathOramBucketProjection_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  pathOramBucketTraceOfLeafScheduleTrace witness.pathOramLeafScheduleTrace =
    witness.pathOramBucketTrace := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, hLeafBuckets, _hNormalized⟩
  exact hLeafBuckets

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
