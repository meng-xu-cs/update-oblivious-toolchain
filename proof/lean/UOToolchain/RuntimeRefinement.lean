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

inductive RuntimePathOramTransitionKind where
  | readMiss
  | readHit
  | writeNoop
  | writeInsert
  | writeUpdate
  | writeDelete
deriving Repr, DecidableEq

structure RuntimePathOramTransitionCertificate where
  objectId : Nat
  objectName : String
  bucketCount : Nat
  kind : RuntimePathOramTransitionKind
  slotIndex : Option Nat
  priorLeaf : Option Nat
  nextLeaf : Option Nat
deriving Repr, DecidableEq

structure RuntimePathOramPositionMapCertificate where
  objectId : Nat
  objectName : String
  leaves : List (Option Nat)
deriving Repr, DecidableEq

abbrev RuntimePathOramPositionMapState := List (Nat × List (Option Nat))

structure RuntimePathOramTransitionShape where
  objectId : Nat
  objectName : String
  bucketCount : Nat
  kind : RuntimePathOramTransitionKind
  slotIndex : Option Nat
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

def RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep
  (step : RuntimePathOramLeafScaffoldStep) : String × Nat :=
  (step.objectName, step.bucketCount)

def runtimeOramObjectByName?
  (oramObjects : List RuntimeOramObjectCertificate)
  (objectName : String) : Option RuntimeOramObjectCertificate :=
  oramObjects.find? (fun object => object.objectName = objectName)

def runtimeOramObjectById?
  (oramObjects : List RuntimeOramObjectCertificate)
  (objectId : Nat) : Option RuntimeOramObjectCertificate :=
  oramObjects.find? (fun object => object.objectId = objectId)

def RuntimeOramObjectCertificate.pathOramLeafChoiceCount
  (object : RuntimeOramObjectCertificate) : Nat :=
  max ((object.bucketCount + 1) / 2) 1

def runtimePathOramLeavesWithinBound
  (leaves : List (Option Nat))
  (leafCount : Nat) : Bool :=
  leaves.all fun leaf =>
    match leaf with
    | some value => value < leafCount
    | none => true

def runtimePathOramPositionMapStateByObjectAux
  (states : List RuntimePathOramPositionMapCertificate)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option RuntimePathOramPositionMapState :=
  match states, oramObjects with
  | [], [] => some []
  | state :: states, object :: objects =>
      if state.objectId = object.objectId &&
          state.objectName = object.objectName &&
          state.leaves.length = object.capacity &&
          runtimePathOramLeavesWithinBound
            state.leaves
            object.pathOramLeafChoiceCount then
        do
          let tail ← runtimePathOramPositionMapStateByObjectAux states objects
          some ((object.objectId, state.leaves) :: tail)
      else
        none
  | _, _ => none

def runtimePathOramPositionMapStateByObject
  (states : List RuntimePathOramPositionMapCertificate)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option RuntimePathOramPositionMapState :=
  runtimePathOramPositionMapStateByObjectAux
    states
    (oramObjects.filter RuntimeOramObjectCertificate.isPathOram)

def runtimePathOramStateLookup?
  (state : RuntimePathOramPositionMapState)
  (objectId : Nat) : Option (List (Option Nat)) :=
  match state.find? (fun entry => entry.fst = objectId) with
  | some (_objectId, leaves) => some leaves
  | none => none

def runtimePathOramSetLeafAt? :
  List (Option Nat) → Nat → Option Nat → Option (List (Option Nat))
  | [], _index, _leaf => none
  | _current :: leaves, 0, leaf => some (leaf :: leaves)
  | current :: leaves, index + 1, leaf => do
      let tail ← runtimePathOramSetLeafAt? leaves index leaf
      some (current :: tail)

def runtimePathOramGetLeafAt? :
  List (Option Nat) → Nat → Option (Option Nat)
  | [], _index => none
  | current :: _leaves, 0 => some current
  | _current :: leaves, index + 1 => runtimePathOramGetLeafAt? leaves index

def runtimePathOramStateUpdate?
  (state : RuntimePathOramPositionMapState)
  (objectId : Nat)
  (leaves : List (Option Nat)) : Option RuntimePathOramPositionMapState :=
  match state with
  | [] => none
  | (entryId, entryLeaves) :: entries =>
      if entryId = objectId then
        some ((entryId, leaves) :: entries)
      else
        do
          let tail ← runtimePathOramStateUpdate? entries objectId leaves
          some ((entryId, entryLeaves) :: tail)

def runtimePathOramApplyTransition?
  (state : RuntimePathOramPositionMapState)
  (oramObjects : List RuntimeOramObjectCertificate)
  (leaf : RuntimeOramLeafCertificate)
  (transition : RuntimePathOramTransitionCertificate) :
  Option RuntimePathOramPositionMapState := do
  let object ← runtimeOramObjectById? oramObjects leaf.objectId
  if object.scheme != pathOramScheme ||
      transition.objectId != leaf.objectId ||
      transition.objectName != leaf.objectName ||
      transition.bucketCount != leaf.bucketCount ||
      object.objectName != leaf.objectName ||
      object.bucketCount != leaf.bucketCount ||
      object.pathOramLeafChoiceCount ≤ leaf.leaf then
    none
  else
    let leaves ← runtimePathOramStateLookup? state leaf.objectId
    match transition.kind with
    | .readMiss =>
        if transition.slotIndex.isNone &&
            transition.priorLeaf.isNone &&
            transition.nextLeaf.isNone then
          some state
        else
          none
    | .readHit =>
        match transition.slotIndex, transition.priorLeaf, transition.nextLeaf with
        | some slotIndex, some priorLeaf, some nextLeaf =>
            if leaf.leaf = priorLeaf &&
                nextLeaf < object.pathOramLeafChoiceCount &&
                runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) then
              do
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                runtimePathOramStateUpdate? state leaf.objectId updated
            else
              none
        | _, _, _ => none
    | .writeNoop =>
        match transition.slotIndex, transition.priorLeaf, transition.nextLeaf with
        | none, none, none => some state
        | some slotIndex, some priorLeaf, some nextLeaf =>
            if leaf.leaf = priorLeaf &&
                nextLeaf = priorLeaf &&
                runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) then
              some state
            else
              none
        | _, _, _ => none
    | .writeInsert =>
        match transition.slotIndex, transition.priorLeaf, transition.nextLeaf with
        | some slotIndex, none, some nextLeaf =>
            if nextLeaf < object.pathOramLeafChoiceCount &&
                runtimePathOramGetLeafAt? leaves slotIndex = some none then
              do
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                runtimePathOramStateUpdate? state leaf.objectId updated
            else
              none
        | _, _, _ => none
    | .writeUpdate =>
        match transition.slotIndex, transition.priorLeaf, transition.nextLeaf with
        | some slotIndex, some priorLeaf, some nextLeaf =>
            if leaf.leaf = priorLeaf &&
                nextLeaf < object.pathOramLeafChoiceCount &&
                runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) then
              do
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                runtimePathOramStateUpdate? state leaf.objectId updated
            else
              none
        | _, _, _ => none
    | .writeDelete =>
        match transition.slotIndex, transition.priorLeaf, transition.nextLeaf with
        | some slotIndex, some priorLeaf, none =>
            if leaf.leaf = priorLeaf &&
                runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) then
              do
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex none
                runtimePathOramStateUpdate? state leaf.objectId updated
            else
              none
        | _, _, _ => none

def replayRuntimePathOramTransitionsAux
  (state : RuntimePathOramPositionMapState)
  (oramObjects : List RuntimeOramObjectCertificate)
  (leafs : List RuntimeOramLeafCertificate)
  (transitions : List RuntimePathOramTransitionCertificate) :
  Option RuntimePathOramPositionMapState :=
  match leafs, transitions with
  | [], [] => some state
  | leaf :: leafs, transition :: transitions => do
      let next ← runtimePathOramApplyTransition? state oramObjects leaf transition
      replayRuntimePathOramTransitionsAux next oramObjects leafs transitions
  | _, _ => none

def replayRuntimePathOramTransitions
  (before : List RuntimePathOramPositionMapCertificate)
  (oramObjects : List RuntimeOramObjectCertificate)
  (leafs : List RuntimeOramLeafCertificate)
  (transitions : List RuntimePathOramTransitionCertificate) :
  Option RuntimePathOramPositionMapState := do
  let state ← runtimePathOramPositionMapStateByObject before oramObjects
  replayRuntimePathOramTransitionsAux state oramObjects leafs transitions

def RuntimePathOramTransitionCertificate.shape
  (transition : RuntimePathOramTransitionCertificate) : RuntimePathOramTransitionShape :=
  { objectId := transition.objectId
  , objectName := transition.objectName
  , bucketCount := transition.bucketCount
  , kind := transition.kind
  , slotIndex := transition.slotIndex
  }

def runtimePathOramFreshCoinScaffoldOfStep
  (leaf : RuntimeOramLeafCertificate)
  (transition : RuntimePathOramTransitionCertificate) :
  Option (List RuntimePathOramLeafScaffoldStep) :=
  if transition.objectId != leaf.objectId ||
      transition.objectName != leaf.objectName ||
      transition.bucketCount != leaf.bucketCount then
    none
  else
    let scaffoldStep := leaf.scaffoldStep
    match transition.kind with
    | .readMiss => some [scaffoldStep]
    | .readHit =>
        match transition.nextLeaf with
        | some _ => some [scaffoldStep]
        | none => none
    | .writeNoop =>
        match transition.slotIndex with
        | some _ => some []
        | none => some [scaffoldStep]
    | .writeInsert =>
        match transition.nextLeaf with
        | some _ => some [scaffoldStep, scaffoldStep]
        | none => none
    | .writeUpdate =>
        match transition.nextLeaf with
        | some _ => some [scaffoldStep]
        | none => none
    | .writeDelete => some []

def runtimePathOramFreshCoinValuesOfStep
  (leaf : RuntimeOramLeafCertificate)
  (transition : RuntimePathOramTransitionCertificate) :
  Option (List Nat) :=
  if transition.objectId != leaf.objectId ||
      transition.objectName != leaf.objectName ||
      transition.bucketCount != leaf.bucketCount then
    none
  else
    match transition.kind with
    | .readMiss => some [leaf.leaf]
    | .readHit =>
        match transition.nextLeaf with
        | some nextLeaf => some [nextLeaf]
        | none => none
    | .writeNoop =>
        match transition.slotIndex with
        | some _ => some []
        | none => some [leaf.leaf]
    | .writeInsert =>
        match transition.nextLeaf with
        | some nextLeaf => some [leaf.leaf, nextLeaf]
        | none => none
    | .writeUpdate =>
        match transition.nextLeaf with
        | some nextLeaf => some [nextLeaf]
        | none => none
    | .writeDelete => some []

def extractRuntimePathOramFreshCoinScaffoldAux
  (leafs : List RuntimeOramLeafCertificate)
  (transitions : List RuntimePathOramTransitionCertificate) :
  Option (List RuntimePathOramLeafScaffoldStep) :=
  match leafs, transitions with
  | [], [] => some []
  | leaf :: leafs, transition :: transitions => do
      let head ← runtimePathOramFreshCoinScaffoldOfStep leaf transition
      let tail ← extractRuntimePathOramFreshCoinScaffoldAux leafs transitions
      some (head ++ tail)
  | _, _ => none

def extractRuntimePathOramFreshCoinValuesAux
  (leafs : List RuntimeOramLeafCertificate)
  (transitions : List RuntimePathOramTransitionCertificate) :
  Option (List Nat) :=
  match leafs, transitions with
  | [], [] => some []
  | leaf :: leafs, transition :: transitions => do
      let head ← runtimePathOramFreshCoinValuesOfStep leaf transition
      let tail ← extractRuntimePathOramFreshCoinValuesAux leafs transitions
      some (head ++ tail)
  | _, _ => none

def runtimePathOramTakeFreshCoin?
  (leafCount : Nat)
  (coins : List Nat) : Option (Nat × List Nat) :=
  match coins with
  | [] => none
  | coin :: coins =>
      if coin < leafCount then
        some (coin, coins)
      else
        none

def runtimePathOramApplyTransitionShapeWithCoins?
  (state : RuntimePathOramPositionMapState)
  (oramObjects : List RuntimeOramObjectCertificate)
  (transition : RuntimePathOramTransitionShape)
  (coins : List Nat) :
  Option (RuntimeOramLeafCertificate × RuntimePathOramPositionMapState × List Nat) := do
  let object ← runtimeOramObjectById? oramObjects transition.objectId
  if object.scheme != pathOramScheme ||
      object.objectName != transition.objectName ||
      object.bucketCount != transition.bucketCount then
    none
  else
    let leafCount := object.pathOramLeafChoiceCount
    let leaves ← runtimePathOramStateLookup? state transition.objectId
    let mkLeaf := fun leaf =>
      { objectId := transition.objectId
      , objectName := transition.objectName
      , bucketCount := transition.bucketCount
      , leaf := leaf
      }
    match transition.kind with
    | .readMiss => do
        let (accessLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
        some (mkLeaf accessLeaf, state, coins)
    | .readHit =>
        match transition.slotIndex with
        | some slotIndex =>
            match runtimePathOramGetLeafAt? leaves slotIndex with
            | some (some priorLeaf) => do
                let (nextLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                let nextState ← runtimePathOramStateUpdate? state transition.objectId updated
                some (mkLeaf priorLeaf, nextState, coins)
            | _ => none
        | none => none
    | .writeNoop =>
        match transition.slotIndex with
        | some slotIndex =>
            match runtimePathOramGetLeafAt? leaves slotIndex with
            | some (some priorLeaf) => some (mkLeaf priorLeaf, state, coins)
            | _ => none
        | none => do
            let (accessLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
            some (mkLeaf accessLeaf, state, coins)
    | .writeInsert =>
        match transition.slotIndex with
        | some slotIndex =>
            if runtimePathOramGetLeafAt? leaves slotIndex = some none then
              do
                let (accessLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
                let (nextLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                let nextState ← runtimePathOramStateUpdate? state transition.objectId updated
                some (mkLeaf accessLeaf, nextState, coins)
            else
              none
        | none => none
    | .writeUpdate =>
        match transition.slotIndex with
        | some slotIndex =>
            match runtimePathOramGetLeafAt? leaves slotIndex with
            | some (some priorLeaf) => do
                let (nextLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                let nextState ← runtimePathOramStateUpdate? state transition.objectId updated
                some (mkLeaf priorLeaf, nextState, coins)
            | _ => none
        | none => none
    | .writeDelete =>
        match transition.slotIndex with
        | some slotIndex =>
            match runtimePathOramGetLeafAt? leaves slotIndex with
            | some (some priorLeaf) => do
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex none
                let nextState ← runtimePathOramStateUpdate? state transition.objectId updated
                some (mkLeaf priorLeaf, nextState, coins)
            | _ => none
        | none => none

def replayRuntimePathOramLeafScheduleFromCoinsAux
  (state : RuntimePathOramPositionMapState)
  (oramObjects : List RuntimeOramObjectCertificate)
  (transitions : List RuntimePathOramTransitionShape)
  (coins : List Nat) :
  Option (List RuntimeOramLeafCertificate × RuntimePathOramPositionMapState × List Nat) :=
  match transitions with
  | [] => some ([], state, coins)
  | transition :: transitions => do
      let (leaf, nextState, coins) ←
        runtimePathOramApplyTransitionShapeWithCoins? state oramObjects transition coins
      let (tail, finalState, coins) ←
        replayRuntimePathOramLeafScheduleFromCoinsAux nextState oramObjects transitions coins
      some (leaf :: tail, finalState, coins)

def replayRuntimePathOramLeafScheduleFromCoins
  (before : List RuntimePathOramPositionMapCertificate)
  (oramObjects : List RuntimeOramObjectCertificate)
  (transitions : List RuntimePathOramTransitionShape)
  (coins : List Nat) :
  Option (List RuntimeOramLeafCertificate × RuntimePathOramPositionMapState) := do
  let state ← runtimePathOramPositionMapStateByObject before oramObjects
  let (leafs, finalState, coins) ←
    replayRuntimePathOramLeafScheduleFromCoinsAux state oramObjects transitions coins
  if coins = [] then
    some (leafs, finalState)
  else
    none

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
  runtimeSeed : Option Nat
  publicOutcome : SGXPublicOutcome
  boundarySchedule : List BoundaryEvent
  controllerShape : SGXControllerShape
  normalizedMicroTrace : NormalizedMicroTrace
  controllerCertificate : RuntimeControllerCertificate
  oramObjects : List RuntimeOramObjectCertificate
  oramLeafPublicScaffold : List RuntimePathOramLeafScaffoldStep
  oramLeafSchedule : List RuntimeOramLeafCertificate
  oramPositionMapBefore : List RuntimePathOramPositionMapCertificate
  oramPositionMapAfter : List RuntimePathOramPositionMapCertificate
  oramLeafStateTransitions : List RuntimePathOramTransitionCertificate
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

def RuntimeRefinementWitness.projectedPathOramLeafScaffold
  (witness : RuntimeRefinementWitness) : PathOramLeafScheduleScaffold :=
  witness.pathOramLeafScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold
  (witness : RuntimeRefinementWitness) : PathOramLeafScheduleScaffold :=
  witness.oramLeafPublicScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def RuntimeRefinementWitness.pathOramBucketTrace
  (witness : RuntimeRefinementWitness) : PathOramBucketTrace :=
  pathOramBucketTraceOfView (viewMPlus witness.trace)

def RuntimeRefinementWitness.pathOramTransitionShapes
  (witness : RuntimeRefinementWitness) : List RuntimePathOramTransitionShape :=
  witness.oramLeafStateTransitions.map RuntimePathOramTransitionCertificate.shape

def RuntimeRefinementWitness.pathOramFreshCoinScaffold?
  (witness : RuntimeRefinementWitness) : Option PathOramLeafScheduleScaffold := do
  let scaffold ←
    extractRuntimePathOramFreshCoinScaffoldAux
      witness.oramLeafSchedule
      witness.oramLeafStateTransitions
  some (scaffold.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep)

def RuntimeRefinementWitness.pathOramFreshCoinValues?
  (witness : RuntimeRefinementWitness) : Option PathOramLeafValueTrace :=
  extractRuntimePathOramFreshCoinValuesAux
    witness.oramLeafSchedule
    witness.oramLeafStateTransitions

def RuntimeRefinementWitness.replayedPathOramLeafScheduleFromFreshCoins
  (witness : RuntimeRefinementWitness) : Option (List RuntimeOramLeafCertificate × RuntimePathOramPositionMapState) := do
  let coins ← witness.pathOramFreshCoinValues?
  replayRuntimePathOramLeafScheduleFromCoins
    witness.oramPositionMapBefore
    witness.oramObjects
    witness.pathOramTransitionShapes
    coins

def RuntimeRefinementWitness.replayedPathOramPositionMapState
  (witness : RuntimeRefinementWitness) : Option RuntimePathOramPositionMapState :=
  replayRuntimePathOramTransitions
    witness.oramPositionMapBefore
    witness.oramObjects
    witness.oramLeafSchedule
    witness.oramLeafStateTransitions

def RuntimeRefinementWitness.expectedPathOramPositionMapState
  (witness : RuntimeRefinementWitness) : Option RuntimePathOramPositionMapState :=
  runtimePathOramPositionMapStateByObject
    witness.oramPositionMapAfter
    witness.oramObjects

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
    witness.oramLeafPublicScaffold = witness.pathOramLeafScaffold ∧
    witness.replayedPathOramPositionMapState =
      witness.expectedPathOramPositionMapState ∧
    witness.replayedPathOramPositionMapState.isSome = true ∧
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
    decide (witness.oramLeafPublicScaffold = witness.pathOramLeafScaffold) &&
    decide
      (witness.replayedPathOramPositionMapState =
        witness.expectedPathOramPositionMapState) &&
    decide (witness.replayedPathOramPositionMapState.isSome = true) &&
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
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, hNormalized⟩
  rw [sgxMicroTrace_runtimeWitness]
  rw [reconstructedMicroTrace_normalizedByLeakage]
  exact hNormalized.symm

theorem runtimeWitness_boundaryBudget_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.boundarySchedule.length = witness.controllerShape.boundaryEventBudget := by
  rcases hValid with
    ⟨_hGas, hBoundary, hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized⟩
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
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, hLeafScaffold, _hPublicLeafScaffold,
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized⟩
  exact hLeafScaffold

theorem runtimeWitness_publicPathOramLeafScaffold_matches_hidden
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.oramLeafPublicScaffold = witness.pathOramLeafScaffold := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, hPublicLeafScaffold,
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized⟩
  exact hPublicLeafScaffold

theorem runtimeWitness_pathOramLeafStateReplay_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.replayedPathOramPositionMapState =
    witness.expectedPathOramPositionMapState := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized⟩
  exact hLeafStateEq

theorem runtimeWitness_pathOramLeafStateReplay_some
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.replayedPathOramPositionMapState.isSome = true := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      _hLeafStateEq, hLeafStateSome, _hLeafBuckets, _hNormalized⟩
  exact hLeafStateSome

theorem runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.projectedPublicPathOramLeafScaffold =
    witness.projectedPathOramLeafScaffold := by
  rw [RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold,
    RuntimeRefinementWitness.projectedPathOramLeafScaffold,
    runtimeWitness_publicPathOramLeafScaffold_matches_hidden witness modelTags hValid]

@[simp] theorem runtimeWitness_projectedPathOramLeafScaffold_exact
  (witness : RuntimeRefinementWitness) :
  pathOramLeafScheduleScaffold witness.pathOramLeafScheduleTrace =
    witness.projectedPathOramLeafScaffold := by
  cases witness with
  | mk trace runtimeSeed publicOutcome boundarySchedule controllerShape normalizedMicroTrace
      controllerCertificate oramObjects oramLeafPublicScaffold oramLeafSchedule
      oramPositionMapBefore oramPositionMapAfter oramLeafStateTransitions =>
      induction oramLeafSchedule with
      | nil =>
          rfl
      | cons head tail ih =>
          cases head
          simp [ RuntimeRefinementWitness.pathOramLeafScheduleTrace
            , RuntimeRefinementWitness.pathOramLeafScaffold
            , RuntimeRefinementWitness.projectedPathOramLeafScaffold
            , pathOramLeafScheduleScaffold
            , RuntimeOramLeafCertificate.toPathOramLeafScheduleStep
            , RuntimeOramLeafCertificate.scaffoldStep
            , RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep
            ]

theorem runtimeWitness_pathOramBucketProjection_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  pathOramBucketTraceOfLeafScheduleTrace witness.pathOramLeafScheduleTrace =
    witness.pathOramBucketTrace := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      _hLeafStateEq, _hLeafStateSome, hLeafBuckets, _hNormalized⟩
  exact hLeafBuckets

theorem runtimeWitness_pathOramLeafScaffold_singletonExactProjection
  (witness : RuntimeRefinementWitness) :
  OramExactProjectionRelation
    pathOramLeafScheduleScaffold
    [witness.pathOramLeafScheduleTrace]
    [witness.pathOramLeafScheduleTrace] := by
  refine ⟨witness.projectedPathOramLeafScaffold, ?_, ?_⟩
  · intro trace hMem
    simp at hMem
    rcases hMem with rfl
    exact runtimeWitness_projectedPathOramLeafScaffold_exact witness
  · intro trace hMem
    simp at hMem
    rcases hMem with rfl
    exact runtimeWitness_projectedPathOramLeafScaffold_exact witness

theorem runtimeWitness_pathOramLeafScaffold_exactProjection_of_publicScaffold
  (witness₁ witness₂ : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid₁ : witness₁.Valid modelTags)
  (hValid₂ : witness₂.Valid modelTags)
  (hPublic :
    witness₁.projectedPublicPathOramLeafScaffold =
      witness₂.projectedPublicPathOramLeafScaffold) :
  OramExactProjectionRelation
    pathOramLeafScheduleScaffold
    [witness₁.pathOramLeafScheduleTrace]
    [witness₂.pathOramLeafScheduleTrace] := by
  refine ⟨witness₁.projectedPublicPathOramLeafScaffold, ?_, ?_⟩
  · intro trace hMem
    simp at hMem
    rcases hMem with rfl
    rw [runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
      witness₁ modelTags hValid₁]
    exact runtimeWitness_projectedPathOramLeafScaffold_exact witness₁
  · intro trace hMem
    simp at hMem
    rcases hMem with rfl
    rw [hPublic]
    rw [runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
      witness₂ modelTags hValid₂]
    exact runtimeWitness_projectedPathOramLeafScaffold_exact witness₂

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
