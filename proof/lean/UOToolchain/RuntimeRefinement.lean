import UOToolchain.PathOramSecurity
import UOToolchain.SgxMicroModel

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
  | "path_oram_private_posmap_v1" => some "uooram_metadata_load"
  | _ => none

def RuntimeOramObjectCertificate.bucketEventKind?
  (object : RuntimeOramObjectCertificate) : Option String :=
  match object.scheme with
  | "surrogate_public_schedule_v1" => some "uooram_bucket_scan"
  | "path_oram_local_posmap_v1" => some "uooram_path_read"
  | "path_oram_private_posmap_v1" => some "uooram_path_read"
  | _ => none

def RuntimeOramObjectCertificate.isPathOram
  (object : RuntimeOramObjectCertificate) : Bool :=
  isPathOramScheme object.scheme

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

def RuntimeOramObjectCertificate.toOramObjectManifest
  (object : RuntimeOramObjectCertificate) : OramObjectManifest :=
  { objectId := object.objectId
  , objectName := object.objectName
  , capacity := object.capacity
  , scheme := object.scheme
  , blockSize := object.blockSize
  , bucketSize := object.bucketSize
  , bucketCount := object.bucketCount
  , blocksPerBucket := object.blocksPerBucket
  , treeHeight := object.treeHeight
  , stashBound := object.stashBound
  , recursionDepth := object.recursionDepth
  , metadataPages := object.metadataPages
  , metadataPagesPerAccess := object.metadataPagesPerAccess
  , bucketsPerAccess := object.bucketsPerAccess
  , accessesPerCall := object.accessesPerCall
  }

def runtimeOramObjectByName?
  (oramObjects : List RuntimeOramObjectCertificate)
  (objectName : String) : Option RuntimeOramObjectCertificate :=
  oramObjects.find? (fun object => object.objectName = objectName)

def runtimeOramObjectById?
  (oramObjects : List RuntimeOramObjectCertificate)
  (objectId : Nat) : Option RuntimeOramObjectCertificate :=
  oramObjects.find? (fun object => object.objectId = objectId)

theorem runtimeOramObjectByName?_mem
  {oramObjects : List RuntimeOramObjectCertificate}
  {objectName : String}
  {object : RuntimeOramObjectCertificate}
  (hLookup : runtimeOramObjectByName? oramObjects objectName = some object) :
  object ∈ oramObjects := by
  unfold runtimeOramObjectByName? at hLookup
  induction oramObjects with
  | nil =>
      simp at hLookup
  | cons head tail ih =>
      by_cases hHead : head.objectName = objectName
      · simp [List.find?, hHead] at hLookup
        cases hLookup
        simp
      · simp [List.find?, hHead] at hLookup
        simp [ih hLookup]

theorem runtimeOramObjectByName?_objectName
  {oramObjects : List RuntimeOramObjectCertificate}
  {objectName : String}
  {object : RuntimeOramObjectCertificate}
  (hLookup : runtimeOramObjectByName? oramObjects objectName = some object) :
  object.objectName = objectName := by
  unfold runtimeOramObjectByName? at hLookup
  induction oramObjects with
  | nil =>
      simp at hLookup
  | cons head tail ih =>
      by_cases hHead : head.objectName = objectName
      · simp [List.find?, hHead] at hLookup
        cases hLookup
        exact hHead
      · simp [List.find?, hHead] at hLookup
        exact ih hLookup

def RuntimeOramObjectsMatchPublicConfig
  (oramObjects : List RuntimeOramObjectCertificate)
  (cfg : OramConfig) : Prop :=
  cfg.pubData.witness.oramObjects =
    oramObjects.map RuntimeOramObjectCertificate.toOramObjectManifest

theorem runtimeOramObject_toManifest_mem_of_matchPublicConfig
  {oramObjects : List RuntimeOramObjectCertificate}
  {cfg : OramConfig}
  (hMatch : RuntimeOramObjectsMatchPublicConfig oramObjects cfg)
  {object : RuntimeOramObjectCertificate}
  (hMem : object ∈ oramObjects) :
  object.toOramObjectManifest ∈ cfg.pubData.witness.oramObjects := by
  rw [hMatch]
  exact List.mem_map.mpr ⟨object, hMem, rfl⟩

theorem runtimeOramObject_isPathOram_of_matchPublicConfig
  {oramObjects : List RuntimeOramObjectCertificate}
  {cfg : OramConfig}
  (hMatch : RuntimeOramObjectsMatchPublicConfig oramObjects cfg)
  (hCfg : PathOramAnyConfigWellFormed cfg)
  {object : RuntimeOramObjectCertificate}
  (hMem : object ∈ oramObjects) :
  object.isPathOram = true := by
  have hManifestMem :
      object.toOramObjectManifest ∈ cfg.pubData.witness.oramObjects :=
    runtimeOramObject_toManifest_mem_of_matchPublicConfig hMatch hMem
  have hScheme := isPathOramScheme_of_wellFormedAny (hCfg object.toOramObjectManifest hManifestMem)
  simpa [RuntimeOramObjectCertificate.isPathOram, RuntimeOramObjectCertificate.toOramObjectManifest]
    using hScheme

theorem runtimeOramObjectByName?_isPathOram_of_matchPublicConfig
  {oramObjects : List RuntimeOramObjectCertificate}
  {cfg : OramConfig}
  (hMatch : RuntimeOramObjectsMatchPublicConfig oramObjects cfg)
  (hCfg : PathOramAnyConfigWellFormed cfg)
  {objectName : String}
  {object : RuntimeOramObjectCertificate}
  (hLookup : runtimeOramObjectByName? oramObjects objectName = some object) :
  object.isPathOram = true := by
  exact runtimeOramObject_isPathOram_of_matchPublicConfig
    hMatch
    hCfg
    (runtimeOramObjectByName?_mem hLookup)

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

def runtimePathOramPositionMapCertificateById?
  (states : List RuntimePathOramPositionMapCertificate)
  (objectId : Nat) : Option RuntimePathOramPositionMapCertificate :=
  states.find? (fun state => state.objectId = objectId)

def runtimePathOramPositionMapStateByObject
  (states : List RuntimePathOramPositionMapCertificate)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option RuntimePathOramPositionMapState := do
  let pathObjects := oramObjects.filter RuntimeOramObjectCertificate.isPathOram
  if states.length != pathObjects.length then
    none
  else
    pathObjects.mapM fun object => do
      let state ← runtimePathOramPositionMapCertificateById? states object.objectId
      if state.objectName = object.objectName &&
          state.leaves.length = object.capacity &&
          runtimePathOramLeavesWithinBound
            state.leaves
            object.pathOramLeafChoiceCount then
        some (object.objectId, state.leaves)
      else
        none

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
  if !isPathOramScheme object.scheme ||
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
        -- A no-op on a present key remaps it, as a read hit does.
        match transition.slotIndex, transition.priorLeaf, transition.nextLeaf with
        | none, none, none => some state
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
        match transition.slotIndex, transition.nextLeaf with
        | some _, some _ => some [scaffoldStep]
        | some _, none => none
        | none, _ => some [scaffoldStep]
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
        match transition.slotIndex, transition.nextLeaf with
        | some _, some nextLeaf => some [nextLeaf]
        | some _, none => none
        | none, _ => some [leaf.leaf]
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
  if !isPathOramScheme object.scheme ||
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
            | some (some priorLeaf) => do
                let (nextLeaf, coins) ← runtimePathOramTakeFreshCoin? leafCount coins
                let updated ← runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf)
                let nextState ← runtimePathOramStateUpdate? state transition.objectId updated
                some (mkLeaf priorLeaf, nextState, coins)
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

theorem runtimePathOramApplyTransitionShapeWithCoins_of_explicit
  {state : RuntimePathOramPositionMapState}
  {oramObjects : List RuntimeOramObjectCertificate}
  {leaf : RuntimeOramLeafCertificate}
  {transition : RuntimePathOramTransitionCertificate}
  {nextState : RuntimePathOramPositionMapState}
  (hExplicit :
    runtimePathOramApplyTransition? state oramObjects leaf transition =
      some nextState) :
  ∃ coins,
    runtimePathOramFreshCoinValuesOfStep leaf transition = some coins ∧
    runtimePathOramApplyTransitionShapeWithCoins?
      state
      oramObjects
      transition.shape
      coins =
      some (leaf, nextState, []) := by
  cases leaf with
  | mk leafObjectId leafObjectName leafBucketCount leafValue =>
      cases transition with
      | mk transitionObjectId transitionObjectName transitionBucketCount transitionKind
          transitionSlotIndex transitionPriorLeaf transitionNextLeaf =>
          cases transitionKind <;>
            cases transitionSlotIndex <;>
            cases transitionPriorLeaf <;>
            cases transitionNextLeaf <;>
            simp [ runtimePathOramApplyTransition?
              , runtimePathOramFreshCoinValuesOfStep
              , runtimePathOramApplyTransitionShapeWithCoins?
              , RuntimePathOramTransitionCertificate.shape
              ] at hExplicit ⊢
          case mk.mk.readMiss.none.none.none =>
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                have hLeafLt : leafValue < object.pathOramLeafChoiceCount := by
                  by_cases hLt : leafValue < object.pathOramLeafChoiceCount
                  · exact hLt
                  · have hLe : object.pathOramLeafChoiceCount ≤ leafValue :=
                      Nat.le_of_not_gt hLt
                    have hFalse : False := by
                      simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hLe] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp
                      [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    simp
                      [hObj, hScheme, hObjName, hObjBucket, hLeafLt, hState] at hExplicit
                    rcases hExplicit with ⟨_, hNextStateEq⟩
                    cases hNextStateEq
                    subst transitionObjectId
                    subst transitionObjectName
                    subst transitionBucketCount
                    refine ⟨[leafValue], ?_, ?_⟩
                    · simp
                    · simp
                        [ hObj, hScheme, hObjName, hObjBucket, hState
                        , runtimePathOramTakeFreshCoin?, hLeafLt
                        ]
          case mk.mk.readHit.some.some.some =>
            rename_i slotIndex priorLeaf nextLeaf
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                have hAccessLeafLt : leafValue < object.pathOramLeafChoiceCount := by
                  by_cases hLt : leafValue < object.pathOramLeafChoiceCount
                  · exact hLt
                  · have hLe : object.pathOramLeafChoiceCount ≤ leafValue :=
                      Nat.le_of_not_gt hLt
                    have hFalse : False := by
                      simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hLe] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    have hLeafEq : leafValue = priorLeaf := by
                      by_cases hEq : leafValue = priorLeaf
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hEq] at hExplicit
                        exact False.elim hFalse
                    have hNextLt : nextLeaf < object.pathOramLeafChoiceCount := by
                      by_cases hLt : nextLeaf < object.pathOramLeafChoiceCount
                      · exact hLt
                      · have hNotLt : ¬ nextLeaf < object.pathOramLeafChoiceCount :=
                          hLt
                        have hFalse : False := by
                          simp
                            [ hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket
                            , hState, hLeafEq, hNotLt
                            ] at hExplicit
                        exact False.elim hFalse
                    have hGetEq :
                        runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) := by
                      by_cases hEq : runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf)
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hEq] at hExplicit
                        exact False.elim hFalse
                    cases hSet : runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf) with
                    | none =>
                        simp
                          [ hObj, hId, hName, hBucket, hState, hLeafEq
                          , hGetEq, hSet
                          ] at hExplicit
                    | some updated =>
                        cases hUpdate : runtimePathOramStateUpdate? state leafObjectId updated with
                        | none =>
                            simp
                              [ hObj, hId, hName, hBucket, hState, hLeafEq
                              , hGetEq, hSet, hUpdate
                              ] at hExplicit
                        | some updatedState =>
                            simp
                              [ hObj, hId, hName, hBucket, hState, hLeafEq
                              , hGetEq, hSet, hUpdate
                              ] at hExplicit
                            rcases hExplicit with ⟨_, _, hNextStateEq⟩
                            cases hNextStateEq
                            subst transitionObjectId
                            subst transitionObjectName
                            subst transitionBucketCount
                            subst leafValue
                            refine ⟨[nextLeaf], ?_, ?_⟩
                            · simp
                            · simp
                                [ hObj, hScheme, hObjName, hObjBucket, hState
                                , hGetEq, hSet, hUpdate
                                , runtimePathOramTakeFreshCoin?, hNextLt
                                ]
          case mk.mk.writeNoop.none.none.none =>
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                    rcases hExplicit with ⟨hLeafLt, hStateEq⟩
                    cases hStateEq
                    subst transitionObjectId
                    subst transitionObjectName
                    subst transitionBucketCount
                    refine ⟨[leafValue], ?_, ?_⟩
                    · simp
                    · simp
                        [ hObj, hScheme, hObjName, hObjBucket, hState
                        , runtimePathOramTakeFreshCoin?, hLeafLt
                        ]
          case mk.mk.writeNoop.some.some.some =>
            rename_i slotIndex priorLeaf nextLeaf
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                have hAccessLeafLt : leafValue < object.pathOramLeafChoiceCount := by
                  by_cases hLt : leafValue < object.pathOramLeafChoiceCount
                  · exact hLt
                  · have hLe : object.pathOramLeafChoiceCount ≤ leafValue :=
                      Nat.le_of_not_gt hLt
                    have hFalse : False := by
                      simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hLe] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    have hLeafEq : leafValue = priorLeaf := by
                      by_cases hEq : leafValue = priorLeaf
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hEq] at hExplicit
                        exact False.elim hFalse
                    have hNextLt : nextLeaf < object.pathOramLeafChoiceCount := by
                      by_cases hLt : nextLeaf < object.pathOramLeafChoiceCount
                      · exact hLt
                      · have hNotLt : ¬ nextLeaf < object.pathOramLeafChoiceCount :=
                          hLt
                        have hFalse : False := by
                          simp
                            [ hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket
                            , hState, hLeafEq, hNotLt
                            ] at hExplicit
                        exact False.elim hFalse
                    have hGetEq :
                        runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) := by
                      by_cases hEq : runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf)
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hEq] at hExplicit
                        exact False.elim hFalse
                    cases hSet : runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf) with
                    | none =>
                        simp
                          [ hObj, hId, hName, hBucket, hState, hLeafEq
                          , hGetEq, hSet
                          ] at hExplicit
                    | some updated =>
                        cases hUpdate : runtimePathOramStateUpdate? state leafObjectId updated with
                        | none =>
                            simp
                              [ hObj, hId, hName, hBucket, hState, hLeafEq
                              , hGetEq, hSet, hUpdate
                              ] at hExplicit
                        | some updatedState =>
                            simp
                              [ hObj, hId, hName, hBucket, hState, hLeafEq
                              , hGetEq, hSet, hUpdate
                              ] at hExplicit
                            rcases hExplicit with ⟨_, _, hNextStateEq⟩
                            cases hNextStateEq
                            subst transitionObjectId
                            subst transitionObjectName
                            subst transitionBucketCount
                            subst leafValue
                            refine ⟨[nextLeaf], ?_, ?_⟩
                            · simp
                            · simp
                                [ hObj, hScheme, hObjName, hObjBucket, hState
                                , hGetEq, hSet, hUpdate
                                , runtimePathOramTakeFreshCoin?, hNextLt
                                ]
          case mk.mk.writeInsert.some.none.some =>
            rename_i slotIndex nextLeaf
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                have hAccessLeafLt : leafValue < object.pathOramLeafChoiceCount := by
                  by_cases hLt : leafValue < object.pathOramLeafChoiceCount
                  · exact hLt
                  · have hLe : object.pathOramLeafChoiceCount ≤ leafValue :=
                      Nat.le_of_not_gt hLt
                    have hFalse : False := by
                      simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hLe] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    have hNextLt : nextLeaf < object.pathOramLeafChoiceCount := by
                      by_cases hLt : nextLeaf < object.pathOramLeafChoiceCount
                      · exact hLt
                      · have hNotLt : ¬ nextLeaf < object.pathOramLeafChoiceCount := hLt
                        have hFalse : False := by
                          simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hState, hNotLt] at hExplicit
                        exact False.elim hFalse
                    have hGetEq :
                        runtimePathOramGetLeafAt? leaves slotIndex = some none := by
                      by_cases hEq : runtimePathOramGetLeafAt? leaves slotIndex = some none
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hEq] at hExplicit
                        exact False.elim hFalse
                    cases hSet : runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf) with
                    | none =>
                        simp [hObj, hId, hName, hBucket, hState, hGetEq, hSet] at hExplicit
                    | some updated =>
                        cases hUpdate : runtimePathOramStateUpdate? state leafObjectId updated with
                        | none =>
                            simp [hObj, hId, hName, hBucket, hState, hGetEq, hSet, hUpdate] at hExplicit
                        | some updatedState =>
                            simp [hObj, hId, hName, hBucket, hState, hGetEq, hSet, hUpdate] at hExplicit
                            rcases hExplicit with ⟨_, _, hNextStateEq⟩
                            cases hNextStateEq
                            subst transitionObjectId
                            subst transitionObjectName
                            subst transitionBucketCount
                            refine ⟨[leafValue, nextLeaf], ?_, ?_⟩
                            · simp
                            · simp
                                [ hObj, hScheme, hObjName, hObjBucket, hState
                                , hGetEq, hSet, hUpdate
                                , runtimePathOramTakeFreshCoin?, hAccessLeafLt, hNextLt
                                ]
          case mk.mk.writeUpdate.some.some.some =>
            rename_i slotIndex priorLeaf nextLeaf
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                have hAccessLeafLt : leafValue < object.pathOramLeafChoiceCount := by
                  by_cases hLt : leafValue < object.pathOramLeafChoiceCount
                  · exact hLt
                  · have hLe : object.pathOramLeafChoiceCount ≤ leafValue :=
                      Nat.le_of_not_gt hLt
                    have hFalse : False := by
                      simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hLe] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    have hLeafEq : leafValue = priorLeaf := by
                      by_cases hEq : leafValue = priorLeaf
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hEq] at hExplicit
                        exact False.elim hFalse
                    have hNextLt : nextLeaf < object.pathOramLeafChoiceCount := by
                      by_cases hLt : nextLeaf < object.pathOramLeafChoiceCount
                      · exact hLt
                      · have hNotLt : ¬ nextLeaf < object.pathOramLeafChoiceCount := hLt
                        have hFalse : False := by
                          simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hState, hLeafEq, hNotLt] at hExplicit
                        exact False.elim hFalse
                    have hGetEq :
                        runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) := by
                      by_cases hEq : runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf)
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hEq] at hExplicit
                        exact False.elim hFalse
                    cases hSet : runtimePathOramSetLeafAt? leaves slotIndex (some nextLeaf) with
                    | none =>
                        simp [hObj, hId, hName, hBucket, hState, hLeafEq, hGetEq, hSet] at hExplicit
                    | some updated =>
                        cases hUpdate : runtimePathOramStateUpdate? state leafObjectId updated with
                        | none =>
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hGetEq, hSet, hUpdate] at hExplicit
                        | some updatedState =>
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hGetEq, hSet, hUpdate] at hExplicit
                            rcases hExplicit with ⟨_, _, hNextStateEq⟩
                            cases hNextStateEq
                            subst transitionObjectId
                            subst transitionObjectName
                            subst transitionBucketCount
                            subst leafValue
                            refine ⟨[nextLeaf], ?_, ?_⟩
                            · simp
                            · simp
                                [ hObj, hScheme, hObjName, hObjBucket, hState
                                , hGetEq, hSet, hUpdate
                                , runtimePathOramTakeFreshCoin?, hNextLt
                                ]
          case mk.mk.writeDelete.some.some.none =>
            rename_i slotIndex priorLeaf
            cases hObj : runtimeOramObjectById? oramObjects leafObjectId with
            | none =>
                simp [hObj] at hExplicit
            | some object =>
                have hScheme : isPathOramScheme object.scheme = true := by
                  by_cases hEq : isPathOramScheme object.scheme = true
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hId : transitionObjectId = leafObjectId := by
                  by_cases hEq : transitionObjectId = leafObjectId
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hEq] at hExplicit
                    exact False.elim hFalse
                have hName : transitionObjectName = leafObjectName := by
                  by_cases hEq : transitionObjectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hEq] at hExplicit
                    exact False.elim hFalse
                have hBucket : transitionBucketCount = leafBucketCount := by
                  by_cases hEq : transitionBucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hId, hName, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjName : object.objectName = leafObjectName := by
                  by_cases hEq : object.objectName = leafObjectName
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hEq] at hExplicit
                    exact False.elim hFalse
                have hObjBucket : object.bucketCount = leafBucketCount := by
                  by_cases hEq : object.bucketCount = leafBucketCount
                  · exact hEq
                  · have hFalse : False := by
                        simp [hObj, hScheme, hId, hName, hBucket, hObjName, hEq] at hExplicit
                    exact False.elim hFalse
                have hAccessLeafLt : leafValue < object.pathOramLeafChoiceCount := by
                  by_cases hLt : leafValue < object.pathOramLeafChoiceCount
                  · exact hLt
                  · have hLe : object.pathOramLeafChoiceCount ≤ leafValue :=
                      Nat.le_of_not_gt hLt
                    have hFalse : False := by
                      simp [hObj, hScheme, hId, hName, hBucket, hObjName, hObjBucket, hLe] at hExplicit
                    exact False.elim hFalse
                cases hState : runtimePathOramStateLookup? state leafObjectId with
                | none =>
                    simp [hObj, hId, hName, hBucket, hState] at hExplicit
                | some leaves =>
                    have hLeafEq : leafValue = priorLeaf := by
                      by_cases hEq : leafValue = priorLeaf
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hEq] at hExplicit
                        exact False.elim hFalse
                    have hGetEq :
                        runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf) := by
                      by_cases hEq : runtimePathOramGetLeafAt? leaves slotIndex = some (some priorLeaf)
                      · exact hEq
                      · have hFalse : False := by
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hEq] at hExplicit
                        exact False.elim hFalse
                    cases hSet : runtimePathOramSetLeafAt? leaves slotIndex none with
                    | none =>
                        simp [hObj, hId, hName, hBucket, hState, hLeafEq, hGetEq, hSet] at hExplicit
                    | some updated =>
                        cases hUpdate : runtimePathOramStateUpdate? state leafObjectId updated with
                        | none =>
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hGetEq, hSet, hUpdate] at hExplicit
                        | some updatedState =>
                            simp [hObj, hId, hName, hBucket, hState, hLeafEq, hGetEq, hSet, hUpdate] at hExplicit
                            rcases hExplicit with ⟨_, hNextStateEq⟩
                            cases hNextStateEq
                            subst transitionObjectId
                            subst transitionObjectName
                            subst transitionBucketCount
                            subst leafValue
                            refine ⟨[], ?_, ?_⟩
                            · simp
                            · simp [hObj, hScheme, hObjName, hObjBucket, hState, hGetEq, hSet, hUpdate]

def extractRuntimePathOramFreshCoinBlocksAux
  (leafs : List RuntimeOramLeafCertificate)
  (transitions : List RuntimePathOramTransitionCertificate) :
  Option (List (List Nat)) :=
  match leafs, transitions with
  | [], [] => some []
  | leaf :: leafs, transition :: transitions => do
      let head ← runtimePathOramFreshCoinValuesOfStep leaf transition
      let tail ← extractRuntimePathOramFreshCoinBlocksAux leafs transitions
      some (head :: tail)
  | _, _ => none

def replayRuntimePathOramLeafScheduleFromCoinBlocksAux
  (state : RuntimePathOramPositionMapState)
  (oramObjects : List RuntimeOramObjectCertificate)
  (transitions : List RuntimePathOramTransitionShape)
  (coinBlocks : List (List Nat)) :
  Option (List RuntimeOramLeafCertificate × RuntimePathOramPositionMapState) :=
  match transitions, coinBlocks with
  | [], [] => some ([], state)
  | transition :: transitions, coins :: coinBlocks => do
      let (leaf, nextState, remaining) ←
        runtimePathOramApplyTransitionShapeWithCoins? state oramObjects transition coins
      if remaining = [] then
        let (tail, finalState) ←
          replayRuntimePathOramLeafScheduleFromCoinBlocksAux
            nextState
            oramObjects
            transitions
            coinBlocks
        some (leaf :: tail, finalState)
      else
        none
  | _, _ => none

def replayRuntimePathOramLeafScheduleFromCoinBlocks
  (before : List RuntimePathOramPositionMapCertificate)
  (oramObjects : List RuntimeOramObjectCertificate)
  (transitions : List RuntimePathOramTransitionShape)
  (coinBlocks : List (List Nat)) :
  Option (List RuntimeOramLeafCertificate × RuntimePathOramPositionMapState) := do
  let state ← runtimePathOramPositionMapStateByObject before oramObjects
  replayRuntimePathOramLeafScheduleFromCoinBlocksAux
    state
    oramObjects
    transitions
    coinBlocks

theorem replayRuntimePathOramLeafScheduleFromCoinBlocksAux_of_explicit
  {state : RuntimePathOramPositionMapState}
  {oramObjects : List RuntimeOramObjectCertificate}
  {leafs : List RuntimeOramLeafCertificate}
  {transitions : List RuntimePathOramTransitionCertificate}
  {finalState : RuntimePathOramPositionMapState}
  (hExplicit :
    replayRuntimePathOramTransitionsAux state oramObjects leafs transitions =
      some finalState) :
  ∃ coinBlocks,
    extractRuntimePathOramFreshCoinBlocksAux leafs transitions = some coinBlocks ∧
    replayRuntimePathOramLeafScheduleFromCoinBlocksAux
      state
      oramObjects
      (transitions.map RuntimePathOramTransitionCertificate.shape)
      coinBlocks =
      some (leafs, finalState) := by
  induction leafs generalizing state transitions finalState with
  | nil =>
      cases transitions with
      | nil =>
          have hStateEq : state = finalState := by
            simpa [replayRuntimePathOramTransitionsAux] using hExplicit
          subst finalState
          refine ⟨[], rfl, rfl⟩
      | cons transition transitions =>
          simp [replayRuntimePathOramTransitionsAux] at hExplicit
  | cons leaf leafs ih =>
      cases transitions with
      | nil =>
          simp [replayRuntimePathOramTransitionsAux] at hExplicit
      | cons transition transitions =>
          simp [replayRuntimePathOramTransitionsAux] at hExplicit
          cases hStep : runtimePathOramApplyTransition? state oramObjects leaf transition with
          | none =>
              simp [hStep] at hExplicit
          | some nextState =>
              have hTailExplicit :
                  replayRuntimePathOramTransitionsAux
                    nextState
                    oramObjects
                    leafs
                    transitions =
                    some finalState := by
                simpa [hStep] using hExplicit
              rcases
                runtimePathOramApplyTransitionShapeWithCoins_of_explicit hStep
                with ⟨headCoins, hHeadCoins, hHeadReplay⟩
              rcases ih hTailExplicit with ⟨tailBlocks, hTailBlocks, hTailReplay⟩
              refine ⟨headCoins :: tailBlocks, ?_, ?_⟩
              · simp [extractRuntimePathOramFreshCoinBlocksAux, hHeadCoins, hTailBlocks]
              · simp
                  [ replayRuntimePathOramLeafScheduleFromCoinBlocksAux
                  , hHeadReplay
                  , hTailReplay
                  ]

theorem replayRuntimePathOramLeafScheduleFromCoinBlocks_of_explicit
  {before : List RuntimePathOramPositionMapCertificate}
  {oramObjects : List RuntimeOramObjectCertificate}
  {leafs : List RuntimeOramLeafCertificate}
  {transitions : List RuntimePathOramTransitionCertificate}
  {finalState : RuntimePathOramPositionMapState}
  (hExplicit :
    replayRuntimePathOramTransitions before oramObjects leafs transitions =
      some finalState) :
  ∃ coinBlocks,
    extractRuntimePathOramFreshCoinBlocksAux leafs transitions = some coinBlocks ∧
    replayRuntimePathOramLeafScheduleFromCoinBlocks
      before
      oramObjects
      (transitions.map RuntimePathOramTransitionCertificate.shape)
      coinBlocks =
      some (leafs, finalState) := by
  cases hState : runtimePathOramPositionMapStateByObject before oramObjects with
  | none =>
      simp [replayRuntimePathOramTransitions, hState] at hExplicit
  | some state =>
      have hAux :
          replayRuntimePathOramTransitionsAux state oramObjects leafs transitions =
            some finalState := by
        simpa [replayRuntimePathOramTransitions, hState] using hExplicit
      rcases replayRuntimePathOramLeafScheduleFromCoinBlocksAux_of_explicit hAux with
        ⟨coinBlocks, hCoinBlocks, hReplay⟩
      refine ⟨coinBlocks, hCoinBlocks, ?_⟩
      simp [replayRuntimePathOramLeafScheduleFromCoinBlocks, hState, hReplay]

theorem extractRuntimePathOramFreshCoinValuesAux_of_blocks
  {leafs : List RuntimeOramLeafCertificate}
  {transitions : List RuntimePathOramTransitionCertificate}
  {coinBlocks : List (List Nat)}
  (hBlocks :
    extractRuntimePathOramFreshCoinBlocksAux leafs transitions =
      some coinBlocks) :
  extractRuntimePathOramFreshCoinValuesAux leafs transitions =
    some (concatLists coinBlocks) := by
  induction leafs generalizing transitions coinBlocks with
  | nil =>
      cases transitions with
      | nil =>
          simp [extractRuntimePathOramFreshCoinBlocksAux] at hBlocks
          cases hBlocks
          simp [extractRuntimePathOramFreshCoinValuesAux, concatLists]
      | cons transition transitions =>
          simp [extractRuntimePathOramFreshCoinBlocksAux] at hBlocks
  | cons leaf leafs ih =>
      cases transitions with
      | nil =>
          simp
            [extractRuntimePathOramFreshCoinBlocksAux] at hBlocks
      | cons transition transitions =>
          cases hHead : runtimePathOramFreshCoinValuesOfStep leaf transition with
          | none =>
              simp
                [extractRuntimePathOramFreshCoinBlocksAux, hHead] at hBlocks
          | some head =>
              cases hTail : extractRuntimePathOramFreshCoinBlocksAux leafs transitions with
              | none =>
                  simp
                    [extractRuntimePathOramFreshCoinBlocksAux, hHead, hTail] at hBlocks
              | some tailBlocks =>
                  simp [extractRuntimePathOramFreshCoinBlocksAux, hHead, hTail] at hBlocks
                  cases hBlocks
                  simp [extractRuntimePathOramFreshCoinValuesAux, hHead, ih hTail, concatLists]

def isOramLogicalKind (kind : String) : Bool :=
  kind = "uooram_counter" ||
    kind = "uooram_meta_scan" ||
    kind = "uooram_bucket_scan" ||
    kind = "uooram_metadata_load" ||
    kind = "uooram_path_read"

def isOramCounterLogicalEvent
  (event : LogicalEvent) : Bool :=
  event.kind = "uooram_counter" && event.detail = "counter"

def runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
  (logicalAccesses : List LogicalEvent)
  (oramObjects : List RuntimeOramObjectCertificate) :
  Option PathOramLeafScheduleScaffold :=
  match logicalAccesses with
  | [] => some []
  | event :: events =>
      if !(isOramLogicalKind event.kind) then
        runtimePathOramLeafScheduleScaffoldOfLogicalAccesses events oramObjects
      else if !isOramCounterLogicalEvent event then
        runtimePathOramLeafScheduleScaffoldOfLogicalAccesses events oramObjects
      else
        do
          let object ← runtimeOramObjectByName? oramObjects event.object
          let tail ← runtimePathOramLeafScheduleScaffoldOfLogicalAccesses events oramObjects
          if object.isPathOram then
            some ((object.objectName, object.bucketCount) :: tail)
          else
            some tail

def projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
  (logicalAccesses : List LogicalEvent)
  (leakage : PathOramProjectedLeakage) :
  Option PathOramLeafScheduleScaffold :=
  match logicalAccesses with
  | [] => some []
  | event :: events =>
      if isOramCounterLogicalEvent event then
        do
          let bucketCount ← pathOramBucketCountByObjectName? leakage event.object
          let tail ← projectedPathOramLeafScheduleScaffoldOfLogicalAccesses events leakage
          some ((event.object, bucketCount) :: tail)
      else
        projectedPathOramLeafScheduleScaffoldOfLogicalAccesses events leakage

theorem projectedPathOramLeafScheduleScaffoldOfLogicalAccesses_eq
  (logicalAccesses : List LogicalEvent)
  (leakage : PathOramProjectedLeakage) :
  projectedPathOramLeafScheduleScaffoldOfLogicalAccesses logicalAccesses leakage =
    pathOramLeafScheduleScaffoldOfLogicalAccesses logicalAccesses leakage := by
  induction logicalAccesses with
  | nil =>
      simp
        [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
        , pathOramLeafScheduleScaffoldOfLogicalAccesses
        ]
  | cons event events ih =>
      by_cases hCounter : isOramCounterLogicalEvent event = true
      · have hKind : event.kind = "uooram_counter" := by
          unfold isOramCounterLogicalEvent at hCounter
          simp at hCounter
          exact hCounter.1
        have hDetail : event.detail = "counter" := by
          unfold isOramCounterLogicalEvent at hCounter
          simp at hCounter
          exact hCounter.2
        cases hBucket : pathOramBucketCountByObjectName? leakage event.object with
        | none =>
            simp
              [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
              , pathOramLeafScheduleScaffoldOfLogicalAccesses
              , isOramCounterLogicalEvent
              , hKind
              , hDetail
              , hBucket
              ]
        | some bucketCount =>
            let P : Prop :=
              ∀ (x : LogicalEvent),
                x ∈ events →
                  (¬x.kind = "uooram_counter" ∨ ¬x.detail = "counter") ∨
                    (pathOramBucketCountByObjectName? leakage x.object).isSome = true
            have hStep :
                (pathOramLeafScheduleScaffoldOfLogicalAccesses events leakage).bind
                    (fun tail => some ((event.object, bucketCount) :: tail)) =
                  pathOramLeafScheduleScaffoldOfLogicalAccesses
                    (event :: events)
                    leakage := by
              by_cases hP : P
              · simp
                  [ pathOramLeafScheduleScaffoldOfLogicalAccesses
                  , hKind
                  , hDetail
                  , hBucket
                  ]
                rw [if_pos hP, if_pos hP]
                simp
              · simp
                  [ pathOramLeafScheduleScaffoldOfLogicalAccesses
                  , hKind
                  , hDetail
                  , hBucket
                  ]
                rw [if_neg hP, if_neg hP]
                rfl
            calc
              projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                  (event :: events)
                  leakage =
                (projectedPathOramLeafScheduleScaffoldOfLogicalAccesses events leakage).bind
                  (fun tail => some ((event.object, bucketCount) :: tail)) := by
                    rw [projectedPathOramLeafScheduleScaffoldOfLogicalAccesses, if_pos hCounter, hBucket]
                    simp
              _ =
                (pathOramLeafScheduleScaffoldOfLogicalAccesses events leakage).bind
                  (fun tail => some ((event.object, bucketCount) :: tail)) := by
                    rw [ih]
              _ =
                pathOramLeafScheduleScaffoldOfLogicalAccesses
                  (event :: events)
                  leakage := hStep
      · have hCounterFalse : isOramCounterLogicalEvent event = false := by
          cases hEq : isOramCounterLogicalEvent event <;> simp [hEq] at hCounter ⊢
        by_cases hKind : event.kind = "uooram_counter"
        · have hDetailNe : event.detail ≠ "counter" := by
            intro hDetail
            have hEq : isOramCounterLogicalEvent event = true := by
              unfold isOramCounterLogicalEvent
              simp [hKind, hDetail]
            rw [hCounterFalse] at hEq
            contradiction
          simp
            [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
            , pathOramLeafScheduleScaffoldOfLogicalAccesses
            , isOramCounterLogicalEvent
            , hKind
            , hDetailNe
            , ih
            ]
        · simp
            [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
            , pathOramLeafScheduleScaffoldOfLogicalAccesses
            , isOramCounterLogicalEvent
            , hKind
            , ih
            ]

@[simp] theorem pathOramNormalizeLogicalEvent_kind
  (event : LogicalEvent) :
  (pathOramNormalizeLogicalEvent event).kind = event.kind := by
  cases event with
  | mk kind object detail =>
      unfold pathOramNormalizeLogicalEvent
      split <;> rfl

@[simp] theorem pathOramNormalizeLogicalEvent_object
  (event : LogicalEvent) :
  (pathOramNormalizeLogicalEvent event).object = event.object := by
  cases event with
  | mk kind object detail =>
      unfold pathOramNormalizeLogicalEvent
      split <;> rfl

theorem pathOramNormalizeLogicalEvent_eq_self_of_not_oram
  {event : LogicalEvent}
  (hOram : isOramLogicalKind event.kind = false) :
  pathOramNormalizeLogicalEvent event = event := by
  cases event with
  | mk kind object detail =>
      unfold pathOramNormalizeLogicalEvent
      split
      · rename_i hEq
        exfalso
        have hCounter : kind ≠ "uooram_counter" := by
          intro hk
          simp [isOramLogicalKind, hk] at hOram
        exact hCounter (by simpa using hEq)
      · rename_i hEq
        exfalso
        have hMetadata : kind ≠ "uooram_metadata_load" := by
          intro hk
          simp [isOramLogicalKind, hk] at hOram
        exact hMetadata (by simpa using hEq)
      · rename_i hEq
        exfalso
        have hPathRead : kind ≠ "uooram_path_read" := by
          intro hk
          simp [isOramLogicalKind, hk] at hOram
        exact hPathRead (by simpa using hEq)
      · rfl

theorem pathOramNormalizeLogicalEvent_eq_self_of_counter
  {event : LogicalEvent}
  (hKind : event.kind = "uooram_counter")
  (hDetail : event.detail = "counter") :
  pathOramNormalizeLogicalEvent event = event := by
  cases event with
  | mk kind object detail =>
      simp at hKind hDetail
      simp [pathOramNormalizeLogicalEvent, hKind, hDetail]

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

theorem consumeExpectedOramLogicalEvents_runtimePathOramLeafScheduleScaffold
  {events remaining : List LogicalEvent}
  {oramObjects : List RuntimeOramObjectCertificate}
  {objectName expectedKind detailPrefix : String}
  {expectedCount : Nat}
  (hNotCounter : expectedKind ≠ "uooram_counter")
  (hConsume :
    consumeExpectedOramLogicalEvents
      events
      objectName
      expectedKind
      expectedCount
      detailPrefix =
    some remaining) :
  runtimePathOramLeafScheduleScaffoldOfLogicalAccesses events oramObjects =
    runtimePathOramLeafScheduleScaffoldOfLogicalAccesses remaining oramObjects := by
  induction expectedCount generalizing events remaining with
  | zero =>
      simp [consumeExpectedOramLogicalEvents] at hConsume
      cases hConsume
      rfl
  | succ expectedCount ih =>
      cases events with
      | nil =>
          simp [consumeExpectedOramLogicalEvents] at hConsume
      | cons event events =>
          simp [consumeExpectedOramLogicalEvents] at hConsume
          rcases hConsume with ⟨hMatch, hConsume⟩
          rcases hMatch with ⟨⟨_hObj, hKind⟩, _hPrefix⟩
          have hNotCounterEvent : isOramCounterLogicalEvent event = false := by
            unfold isOramCounterLogicalEvent
            have hKindNe : event.kind ≠ "uooram_counter" := by
              intro hEq
              apply hNotCounter
              exact hKind.symm.trans hEq
            by_cases hCounter : event.kind = "uooram_counter"
            · exact False.elim (hKindNe hCounter)
            · simp [hCounter]
          have hSkip :
              runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                  (event :: events)
                  oramObjects =
                runtimePathOramLeafScheduleScaffoldOfLogicalAccesses events oramObjects := by
            by_cases hOram : isOramLogicalKind event.kind
            · simp [runtimePathOramLeafScheduleScaffoldOfLogicalAccesses, hOram, hNotCounterEvent]
            · simp [runtimePathOramLeafScheduleScaffoldOfLogicalAccesses, hOram]
          rw [hSkip]
          exact ih hConsume

theorem consumeExpectedOramLogicalEvents_projectedPathOramLeafScheduleScaffold
  {events remaining : List LogicalEvent}
  {leakage : PathOramProjectedLeakage}
  {objectName expectedKind detailPrefix : String}
  {expectedCount : Nat}
  (hNotCounter : expectedKind ≠ "uooram_counter")
  (hConsume :
    consumeExpectedOramLogicalEvents
      events
      objectName
      expectedKind
      expectedCount
      detailPrefix =
    some remaining) :
  projectedPathOramLeafScheduleScaffoldOfLogicalAccesses events leakage =
    projectedPathOramLeafScheduleScaffoldOfLogicalAccesses remaining leakage := by
  induction expectedCount generalizing events remaining with
  | zero =>
      simp [consumeExpectedOramLogicalEvents] at hConsume
      cases hConsume
      rfl
  | succ expectedCount ih =>
      cases events with
      | nil =>
          simp [consumeExpectedOramLogicalEvents] at hConsume
      | cons event events =>
          simp [consumeExpectedOramLogicalEvents] at hConsume
          rcases hConsume with ⟨hMatch, hConsume⟩
          rcases hMatch with ⟨⟨_hObj, hKind⟩, _hPrefix⟩
          have hNotCounterEvent : isOramCounterLogicalEvent event = false := by
            unfold isOramCounterLogicalEvent
            have hKindNe : event.kind ≠ "uooram_counter" := by
              intro hEq
              apply hNotCounter
              exact hKind.symm.trans hEq
            by_cases hCounter : event.kind = "uooram_counter"
            · exact False.elim (hKindNe hCounter)
            · simp [hCounter]
          have hSkip :
              projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                  (event :: events)
                  leakage =
                projectedPathOramLeafScheduleScaffoldOfLogicalAccesses events leakage := by
            simp [projectedPathOramLeafScheduleScaffoldOfLogicalAccesses, hNotCounterEvent]
          rw [hSkip]
          exact ih hConsume

theorem consumeExpectedOramLogicalEvents_normalized_projectedPathOramLeafScheduleScaffold
  {events remaining : List LogicalEvent}
  {leakage : PathOramProjectedLeakage}
  {objectName expectedKind detailPrefix : String}
  {expectedCount : Nat}
  (hNotCounter : expectedKind ≠ "uooram_counter")
  (hConsume :
    consumeExpectedOramLogicalEvents
      events
      objectName
      expectedKind
      expectedCount
      detailPrefix =
    some remaining) :
  projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      (pathOramNormalizeLogicalAccesses events)
      leakage =
    projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      (pathOramNormalizeLogicalAccesses remaining)
      leakage := by
  induction expectedCount generalizing events remaining with
  | zero =>
      simp [consumeExpectedOramLogicalEvents] at hConsume
      cases hConsume
      rfl
  | succ expectedCount ih =>
      cases events with
      | nil =>
          simp [consumeExpectedOramLogicalEvents] at hConsume
      | cons event events =>
          simp [consumeExpectedOramLogicalEvents] at hConsume
          rcases hConsume with ⟨hMatch, hConsume⟩
          rcases hMatch with ⟨⟨_hObj, hKind⟩, _hPrefix⟩
          have hNormKind :
              (pathOramNormalizeLogicalEvent event).kind = event.kind :=
            pathOramNormalizeLogicalEvent_kind event
          have hNotCounterEvent :
              isOramCounterLogicalEvent (pathOramNormalizeLogicalEvent event) = false := by
            by_cases hEq :
                isOramCounterLogicalEvent (pathOramNormalizeLogicalEvent event) = true
            · unfold isOramCounterLogicalEvent at hEq
              simp at hEq
              have hFalse : False := by
                apply hNotCounter
                calc
                  expectedKind = event.kind := hKind.symm
                  _ = "uooram_counter" := hEq.1
              exact False.elim hFalse
            · cases hVal : isOramCounterLogicalEvent (pathOramNormalizeLogicalEvent event) <;>
                simp [hVal] at hEq ⊢
          have hSkip :
              projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                  (pathOramNormalizeLogicalAccesses (event :: events))
                  leakage =
                projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                  (pathOramNormalizeLogicalAccesses events)
                  leakage := by
            simp
              [ pathOramNormalizeLogicalAccesses
              , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
              , hNotCounterEvent
              ]
          rw [hSkip]
          exact ih hConsume

theorem runtimeOramObjectByName?_map_toManifest
  (oramObjects : List RuntimeOramObjectCertificate)
  (objectName : String) :
  (oramObjects.map RuntimeOramObjectCertificate.toOramObjectManifest).find?
      (fun object => object.objectName = objectName) =
    (runtimeOramObjectByName? oramObjects objectName).map
      RuntimeOramObjectCertificate.toOramObjectManifest := by
  induction oramObjects with
  | nil =>
      simp [runtimeOramObjectByName?]
  | cons head tail ih =>
      by_cases hHead : head.objectName = objectName
      · simp
          [ runtimeOramObjectByName?
          , List.find?
          , hHead
          , RuntimeOramObjectCertificate.toOramObjectManifest
          ]
      · simp
          [ runtimeOramObjectByName?
          , List.find?
          , hHead
          , RuntimeOramObjectCertificate.toOramObjectManifest
          , ih
          ]

theorem pathOramProjectedLeakage_find_byObjectName_of_manifests
  (cfg : OramConfig)
  (objects : List OramObjectManifest)
  (objectName : String) :
  (projectPathOramLeakage (objects.map (accessLeakage cfg))).find?
      (fun access => access.objectName = objectName) =
    (objects.find? (fun object => object.objectName = objectName)).map
      (fun object => projectPathOramAccessLeakage (accessLeakage cfg object)) := by
  induction objects with
  | nil =>
      simp [projectPathOramLeakage]
  | cons head tail ih =>
      by_cases hHead : head.objectName = objectName
      · simp
          [ projectPathOramLeakage
          , List.find?
          , hHead
          , accessLeakage
          , projectPathOramAccessLeakage
          ]
      · simp
          [ projectPathOramLeakage
          , List.find?
          , hHead
          , accessLeakage
          , projectPathOramAccessLeakage
          ]
        simpa [projectPathOramLeakage] using ih

theorem pathOramBucketCountByObjectName?_of_manifests
  (cfg : OramConfig)
  (objects : List OramObjectManifest)
  (objectName : String) :
  pathOramBucketCountByObjectName?
      (projectPathOramLeakage (objects.map (accessLeakage cfg)))
      objectName =
    (objects.find? (fun object => object.objectName = objectName)).map
      OramObjectManifest.bucketCount := by
  unfold pathOramBucketCountByObjectName?
  rw [pathOramProjectedLeakage_find_byObjectName_of_manifests]
  cases hFind : List.find? (fun object => object.objectName = objectName) objects with
  | none =>
      rfl
  | some object =>
      simp [accessLeakage, projectPathOramAccessLeakage]

theorem pathOramBucketCountByObjectName?_of_matchPublicConfig
  {oramObjects : List RuntimeOramObjectCertificate}
  {cfg : OramConfig}
  (hMatch : RuntimeOramObjectsMatchPublicConfig oramObjects cfg)
  (objectName : String) :
  pathOramBucketCountByObjectName?
      (pathOramProjectedExecutionLeakage cfg)
      objectName =
    (runtimeOramObjectByName? oramObjects objectName).map
      RuntimeOramObjectCertificate.bucketCount := by
  unfold pathOramProjectedExecutionLeakage executionLeakage projectPathOramLeakage
  rw [hMatch]
  have hManifest :
      pathOramBucketCountByObjectName?
          (List.map projectPathOramAccessLeakage
            (List.map (accessLeakage cfg)
              (List.map RuntimeOramObjectCertificate.toOramObjectManifest oramObjects)))
          objectName =
        ((oramObjects.map RuntimeOramObjectCertificate.toOramObjectManifest).find?
          (fun object => object.objectName = objectName)).map
          OramObjectManifest.bucketCount := by
    simpa [projectPathOramLeakage, List.map_map] using
      (pathOramBucketCountByObjectName?_of_manifests cfg
        (oramObjects.map RuntimeOramObjectCertificate.toOramObjectManifest)
        objectName)
  rw [hManifest]
  rw [runtimeOramObjectByName?_map_toManifest]
  cases hLookup : runtimeOramObjectByName? oramObjects objectName <;>
    simp [RuntimeOramObjectCertificate.toOramObjectManifest]

theorem runtimePathOramLeafScheduleScaffold_eq_projected_of_matchPublicConfig
  {logicalAccesses : List LogicalEvent}
  {oramObjects : List RuntimeOramObjectCertificate}
  {cfg : OramConfig}
  (hMatch : RuntimeOramObjectsMatchPublicConfig oramObjects cfg)
  (hCfg : PathOramAnyConfigWellFormed cfg) :
  runtimePathOramLeafScheduleScaffoldOfLogicalAccesses logicalAccesses oramObjects =
    projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      logicalAccesses
      (pathOramProjectedExecutionLeakage cfg) := by
  induction logicalAccesses with
  | nil =>
      simp
        [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
        , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
        ]
  | cons event events ih =>
      by_cases hOram : isOramLogicalKind event.kind
      · by_cases hCounter : isOramCounterLogicalEvent event
        · have hBucketLookup :
            pathOramBucketCountByObjectName?
                (pathOramProjectedExecutionLeakage cfg)
                event.object =
              (runtimeOramObjectByName? oramObjects event.object).map
                RuntimeOramObjectCertificate.bucketCount :=
            pathOramBucketCountByObjectName?_of_matchPublicConfig hMatch event.object
          cases hLookup : runtimeOramObjectByName? oramObjects event.object with
          | none =>
              have hProjectedLookup :
                  pathOramBucketCountByObjectName?
                      (pathOramProjectedExecutionLeakage cfg)
                      event.object =
                    none := by
                simpa [hLookup] using hBucketLookup
              simp
                [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                , hOram
                , hCounter
                , hLookup
                , hProjectedLookup
                ]
          | some object =>
              have hProjectedLookup :
                  pathOramBucketCountByObjectName?
                      (pathOramProjectedExecutionLeakage cfg)
                      event.object =
                    some object.bucketCount := by
                simpa [hLookup] using hBucketLookup
              have hObjectName : object.objectName = event.object :=
                runtimeOramObjectByName?_objectName hLookup
              have hIsPath : object.isPathOram = true :=
                runtimeOramObjectByName?_isPathOram_of_matchPublicConfig
                  hMatch hCfg hLookup
              simp
                [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                , hOram
                , hCounter
                , hLookup
                , hProjectedLookup
                , hObjectName
                , hIsPath
                , ih
                ]
        · simp
            [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
            , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
            , hOram
            , hCounter
            , ih
            ]
      · have hNotCounter : isOramCounterLogicalEvent event = false := by
          unfold isOramCounterLogicalEvent
          by_cases hKind : event.kind = "uooram_counter"
          · have hFalse : False := by
              simp [isOramLogicalKind, hKind] at hOram
            exact False.elim hFalse
          · simp [hKind]
        simp
          [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
          , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
          , hOram
          , hNotCounter
          , ih
          ]

theorem runtimeOramObject_metadataEventKind_ne_counter
  {object : RuntimeOramObjectCertificate}
  {metadataKind : String}
  (hKind : object.metadataEventKind? = some metadataKind) :
  metadataKind ≠ "uooram_counter" := by
  unfold RuntimeOramObjectCertificate.metadataEventKind? at hKind
  split at hKind <;> simp at hKind
  all_goals subst metadataKind <;> decide

theorem runtimeOramObject_bucketEventKind_ne_counter
  {object : RuntimeOramObjectCertificate}
  {bucketKind : String}
  (hKind : object.bucketEventKind? = some bucketKind) :
  bucketKind ≠ "uooram_counter" := by
  unfold RuntimeOramObjectCertificate.bucketEventKind? at hKind
  split at hKind <;> simp at hKind
  all_goals subst bucketKind <;> decide

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

theorem reconstructPathOramLeafScaffoldFromLogicalTraceAux_runtime
  {fuel : Nat}
  {logicalAccesses : List LogicalEvent}
  {oramObjects : List RuntimeOramObjectCertificate}
  {scaffold : List RuntimePathOramLeafScaffoldStep}
  (hRecon :
    reconstructPathOramLeafScaffoldFromLogicalTraceAux
      fuel
      logicalAccesses
      oramObjects =
    some scaffold) :
  runtimePathOramLeafScheduleScaffoldOfLogicalAccesses logicalAccesses oramObjects =
    some (scaffold.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep) := by
  induction fuel generalizing logicalAccesses scaffold with
  | zero =>
      cases logicalAccesses with
      | nil =>
          simp [reconstructPathOramLeafScaffoldFromLogicalTraceAux, runtimePathOramLeafScheduleScaffoldOfLogicalAccesses] at hRecon ⊢
          cases hRecon
          rfl
      | cons event events =>
          simp [reconstructPathOramLeafScaffoldFromLogicalTraceAux] at hRecon
  | succ fuel ih =>
      cases logicalAccesses with
      | nil =>
          simp [reconstructPathOramLeafScaffoldFromLogicalTraceAux, runtimePathOramLeafScheduleScaffoldOfLogicalAccesses] at hRecon ⊢
          cases hRecon
          rfl
      | cons event events =>
          by_cases hOram : isOramLogicalKind event.kind
          · by_cases hCounter : isOramCounterLogicalEvent event
            · have hCounterEq : event.kind = "uooram_counter" ∧ event.detail = "counter" := by
                unfold isOramCounterLogicalEvent at hCounter
                simp at hCounter
                exact hCounter
              rcases hCounterEq with ⟨hKindCounter, hDetailCounter⟩
              cases hLookup : runtimeOramObjectByName? oramObjects event.object with
              | none =>
                  simp
                    [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                    , hKindCounter
                    , hDetailCounter
                    , hLookup
                    ] at hRecon
                  have hFalse : False := by
                    simpa [isOramLogicalKind] using hRecon.1
                  exact False.elim hFalse
              | some object =>
                  cases hMeta : object.metadataEventKind? with
                  | none =>
                      simp
                        [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                        , hKindCounter
                        , hDetailCounter
                        , hLookup
                        , hMeta
                        ] at hRecon
                      have hFalse : False := by
                        simpa [isOramLogicalKind] using hRecon.1
                      exact False.elim hFalse
                  | some metadataKind =>
                      cases hBucket : object.bucketEventKind? with
                      | none =>
                          simp
                            [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                            , hKindCounter
                            , hDetailCounter
                            , hLookup
                            , hMeta
                            , hBucket
                            ] at hRecon
                          have hFalse : False := by
                            simpa [isOramLogicalKind] using hRecon.1
                          exact False.elim hFalse
                      | some bucketKind =>
                          cases hConsumeMeta :
                              consumeExpectedOramLogicalEvents
                                events
                                event.object
                                metadataKind
                                object.metadataPages
                                "page:" with
                          | none =>
                              simp
                                [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                , hKindCounter
                                , hDetailCounter
                                , hLookup
                                , hMeta
                                , hBucket
                                , hConsumeMeta
                                ] at hRecon
                              have hFalse : False := by
                                simpa [isOramLogicalKind] using hRecon.1
                              exact False.elim hFalse
                          | some afterMeta =>
                              cases hConsumeBucket :
                                  consumeExpectedOramLogicalEvents
                                    afterMeta
                                    event.object
                                    bucketKind
                                    object.bucketsPerAccess
                                    "bucket:" with
                              | none =>
                                  simp
                                    [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                    , hKindCounter
                                    , hDetailCounter
                                    , hLookup
                                    , hMeta
                                    , hBucket
                                    , hConsumeMeta
                                    , hConsumeBucket
                                    ] at hRecon
                                  have hFalse : False := by
                                    simpa [isOramLogicalKind] using hRecon.1
                                  exact False.elim hFalse
                              | some remaining =>
                                  cases hTail :
                                      reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                        fuel
                                        remaining
                                        oramObjects with
                                  | none =>
                                      simp
                                        [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                        , hKindCounter
                                        , hDetailCounter
                                        , hLookup
                                        , hMeta
                                        , hBucket
                                        , hConsumeMeta
                                        , hConsumeBucket
                                        , hTail
                                        ] at hRecon
                                      have hFalse : False := by
                                        simpa [isOramLogicalKind] using hRecon.1
                                      exact False.elim hFalse
                                  | some tailScaffold =>
                                      have hSkipMeta :
                                          runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                              events
                                              oramObjects =
                                            runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                              afterMeta
                                              oramObjects :=
                                        consumeExpectedOramLogicalEvents_runtimePathOramLeafScheduleScaffold
                                          (runtimeOramObject_metadataEventKind_ne_counter hMeta)
                                          hConsumeMeta
                                      have hSkipBucket :
                                          runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                              afterMeta
                                              oramObjects =
                                            runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                              remaining
                                              oramObjects :=
                                        consumeExpectedOramLogicalEvents_runtimePathOramLeafScheduleScaffold
                                          (runtimeOramObject_bucketEventKind_ne_counter hBucket)
                                          hConsumeBucket
                                      have hTailRuntime :
                                          runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                              remaining
                                              oramObjects =
                                            some
                                              (tailScaffold.map
                                                RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep) :=
                                        ih hTail
                                      have hEventsRuntime :
                                          runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                              events
                                              oramObjects =
                                            some
                                              (tailScaffold.map
                                                RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep) := by
                                        rw [hSkipMeta, hSkipBucket]
                                        exact hTailRuntime
                                      by_cases hPath : object.isPathOram
                                      · simp
                                          [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                          , hKindCounter
                                          , hDetailCounter
                                          , hLookup
                                          , hMeta
                                          , hBucket
                                          , hConsumeMeta
                                          , hConsumeBucket
                                          , hTail
                                          , hPath
                                          ] at hRecon
                                        cases hRecon
                                        simp
                                          [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                          , hOram
                                          , hCounter
                                          , hLookup
                                          , hPath
                                          , hEventsRuntime
                                          , RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep
                                          ]
                                      · simp
                                          [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                          , hKindCounter
                                          , hDetailCounter
                                          , hLookup
                                          , hMeta
                                          , hBucket
                                          , hConsumeMeta
                                          , hConsumeBucket
                                          , hTail
                                          , hPath
                                          ] at hRecon
                                        cases hRecon
                                        simp
                                          [ runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
                                          , hOram
                                          , hCounter
                                          , hLookup
                                          , hPath
                                          , hEventsRuntime
                                          ]
            · have hBadCounter :
                (event.kind != "uooram_counter" || event.detail != "counter") = true := by
                unfold isOramCounterLogicalEvent at hCounter
                by_cases hKind : event.kind = "uooram_counter"
                · by_cases hDetail : event.detail = "counter"
                  · simp [hKind, hDetail] at hCounter
                  · simp [hKind, hDetail]
                · simp [hKind]
              simp
                [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                , hOram
                , hBadCounter
                ] at hRecon
          · have hTail :
                reconstructPathOramLeafScaffoldFromLogicalTraceAux fuel events oramObjects =
                  some scaffold := by
              simpa [reconstructPathOramLeafScaffoldFromLogicalTraceAux, hOram] using hRecon
            have hTailRuntime := ih hTail
            simpa [runtimePathOramLeafScheduleScaffoldOfLogicalAccesses, hOram] using hTailRuntime

theorem reconstructPathOramLeafScaffoldFromLogicalTrace_runtime
  {logicalAccesses : List LogicalEvent}
  {oramObjects : List RuntimeOramObjectCertificate}
  {scaffold : List RuntimePathOramLeafScaffoldStep}
  (hRecon :
    reconstructPathOramLeafScaffoldFromLogicalTrace
      logicalAccesses
      oramObjects =
    some scaffold) :
  runtimePathOramLeafScheduleScaffoldOfLogicalAccesses logicalAccesses oramObjects =
    some (scaffold.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep) := by
  simpa [reconstructPathOramLeafScaffoldFromLogicalTrace] using
    (reconstructPathOramLeafScaffoldFromLogicalTraceAux_runtime hRecon)

theorem projectedPathOramLeafScheduleScaffoldOfLogicalAccesses_normalize_of_reconstructAux
  {fuel : Nat}
  {logicalAccesses : List LogicalEvent}
  {oramObjects : List RuntimeOramObjectCertificate}
  {scaffold : List RuntimePathOramLeafScaffoldStep}
  {leakage : PathOramProjectedLeakage}
  (hRecon :
    reconstructPathOramLeafScaffoldFromLogicalTraceAux
      fuel
      logicalAccesses
      oramObjects =
    some scaffold) :
  projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      (pathOramNormalizeLogicalAccesses logicalAccesses)
      leakage =
    projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      logicalAccesses
      leakage := by
  induction fuel generalizing logicalAccesses scaffold with
  | zero =>
      cases logicalAccesses with
      | nil =>
          simp
            [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
            , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
            , pathOramNormalizeLogicalAccesses
            ] at hRecon ⊢
      | cons event events =>
          simp [reconstructPathOramLeafScaffoldFromLogicalTraceAux] at hRecon
  | succ fuel ih =>
      cases logicalAccesses with
      | nil =>
          simp
            [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
            , projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
            , pathOramNormalizeLogicalAccesses
            ] at hRecon ⊢
      | cons event events =>
          by_cases hOram : isOramLogicalKind event.kind
          · by_cases hCounter : isOramCounterLogicalEvent event
            · unfold isOramCounterLogicalEvent at hCounter
              simp at hCounter
              rcases hCounter with ⟨hKindCounter, hDetailCounter⟩
              cases hLookup : runtimeOramObjectByName? oramObjects event.object with
              | none =>
                  simp
                    [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                    , hKindCounter
                    , hDetailCounter
                    , hLookup
                    ] at hRecon
                  have hFalse : False := by
                    simpa [isOramLogicalKind] using hRecon.1
                  exact False.elim hFalse
              | some object =>
                  cases hMeta : object.metadataEventKind? with
                  | none =>
                      simp
                        [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                        , hKindCounter
                        , hDetailCounter
                        , hLookup
                        , hMeta
                        ] at hRecon
                      have hFalse : False := by
                        simpa [isOramLogicalKind] using hRecon.1
                      exact False.elim hFalse
                  | some metadataKind =>
                      cases hBucket : object.bucketEventKind? with
                      | none =>
                          simp
                            [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                            , hKindCounter
                            , hDetailCounter
                            , hLookup
                            , hMeta
                            , hBucket
                            ] at hRecon
                          have hFalse : False := by
                            simpa [isOramLogicalKind] using hRecon.1
                          exact False.elim hFalse
                      | some bucketKind =>
                          cases hConsumeMeta :
                              consumeExpectedOramLogicalEvents
                                events
                                event.object
                                metadataKind
                                object.metadataPages
                                "page:" with
                          | none =>
                              simp
                                [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                , hKindCounter
                                , hDetailCounter
                                , hLookup
                                , hMeta
                                , hBucket
                                , hConsumeMeta
                                ] at hRecon
                              have hFalse : False := by
                                simpa [isOramLogicalKind] using hRecon.1
                              exact False.elim hFalse
                          | some afterMeta =>
                              cases hConsumeBucket :
                                  consumeExpectedOramLogicalEvents
                                    afterMeta
                                    event.object
                                    bucketKind
                                    object.bucketsPerAccess
                                    "bucket:" with
                              | none =>
                                  simp
                                    [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                    , hKindCounter
                                    , hDetailCounter
                                    , hLookup
                                    , hMeta
                                    , hBucket
                                    , hConsumeMeta
                                    , hConsumeBucket
                                    ] at hRecon
                                  have hFalse : False := by
                                    simpa [isOramLogicalKind] using hRecon.1
                                  exact False.elim hFalse
                              | some remaining =>
                                  cases hTail :
                                      reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                        fuel
                                        remaining
                                        oramObjects with
                                  | none =>
                                      simp
                                        [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                                        , hKindCounter
                                        , hDetailCounter
                                        , hLookup
                                        , hMeta
                                        , hBucket
                                        , hConsumeMeta
                                        , hConsumeBucket
                                        , hTail
                                        ] at hRecon
                                      have hFalse : False := by
                                        simpa [isOramLogicalKind] using hRecon.1
                                      exact False.elim hFalse
                                  | some tailScaffold =>
                                      have hSkipMeta :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              events
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              afterMeta
                                              leakage :=
                                        consumeExpectedOramLogicalEvents_projectedPathOramLeafScheduleScaffold
                                          (runtimeOramObject_metadataEventKind_ne_counter hMeta)
                                          hConsumeMeta
                                      have hSkipBucket :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              afterMeta
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              remaining
                                              leakage :=
                                        consumeExpectedOramLogicalEvents_projectedPathOramLeafScheduleScaffold
                                          (runtimeOramObject_bucketEventKind_ne_counter hBucket)
                                          hConsumeBucket
                                      have hSkipMetaNorm :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              (pathOramNormalizeLogicalAccesses events)
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              (pathOramNormalizeLogicalAccesses afterMeta)
                                              leakage :=
                                        consumeExpectedOramLogicalEvents_normalized_projectedPathOramLeafScheduleScaffold
                                          (runtimeOramObject_metadataEventKind_ne_counter hMeta)
                                          hConsumeMeta
                                      have hSkipBucketNorm :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              (pathOramNormalizeLogicalAccesses afterMeta)
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              (pathOramNormalizeLogicalAccesses remaining)
                                              leakage :=
                                        consumeExpectedOramLogicalEvents_normalized_projectedPathOramLeafScheduleScaffold
                                          (runtimeOramObject_bucketEventKind_ne_counter hBucket)
                                          hConsumeBucket
                                      have hTailNorm :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              (pathOramNormalizeLogicalAccesses remaining)
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              remaining
                                              leakage :=
                                        ih hTail
                                      have hEventsNorm :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              (pathOramNormalizeLogicalAccesses events)
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              remaining
                                              leakage := by
                                        rw [hSkipMetaNorm, hSkipBucketNorm]
                                        exact hTailNorm
                                      have hEvents :
                                          projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              events
                                              leakage =
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                              remaining
                                              leakage := by
                                        rw [hSkipMeta, hSkipBucket]
                                      cases hProjectedBucket :
                                          pathOramBucketCountByObjectName? leakage event.object with
                                      | none =>
                                          have hCounterTrue :
                                              isOramCounterLogicalEvent event = true := by
                                            unfold isOramCounterLogicalEvent
                                            simp [hKindCounter, hDetailCounter]
                                          have hNormEvent :
                                              pathOramNormalizeLogicalEvent event = event :=
                                            pathOramNormalizeLogicalEvent_eq_self_of_counter
                                              hKindCounter
                                              hDetailCounter
                                          simp
                                            [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                            , pathOramNormalizeLogicalAccesses
                                            , hNormEvent
                                            , hCounterTrue
                                            , hProjectedBucket
                                            ]
                                      | some bucketCount =>
                                          have hCounterTrue :
                                              isOramCounterLogicalEvent event = true := by
                                            unfold isOramCounterLogicalEvent
                                            simp [hKindCounter, hDetailCounter]
                                          have hNormEvent :
                                              pathOramNormalizeLogicalEvent event = event :=
                                            pathOramNormalizeLogicalEvent_eq_self_of_counter
                                              hKindCounter
                                              hDetailCounter
                                          calc
                                            projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                                (pathOramNormalizeLogicalAccesses (event :: events))
                                                leakage =
                                              (projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                                  (pathOramNormalizeLogicalAccesses events)
                                                  leakage).bind
                                                (fun tail =>
                                                  some ((event.object, bucketCount) :: tail)) := by
                                                    simp
                                                      [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                                      , pathOramNormalizeLogicalAccesses
                                                      , hNormEvent
                                                      , hCounterTrue
                                                      , hProjectedBucket
                                                      ]
                                            _ =
                                              (projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                                  remaining
                                                  leakage).bind
                                                (fun tail =>
                                                  some ((event.object, bucketCount) :: tail)) := by
                                                    rw [hEventsNorm]
                                            _ =
                                              projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
                                                (event :: events)
                                                leakage := by
                                                  rw [projectedPathOramLeafScheduleScaffoldOfLogicalAccesses]
                                                  simp [hCounterTrue, hProjectedBucket]
                                                  rw [hEvents]
            · have hBadCounter :
                (event.kind != "uooram_counter" || event.detail != "counter") = true := by
                unfold isOramCounterLogicalEvent at hCounter
                by_cases hKind : event.kind = "uooram_counter"
                · by_cases hDetail : event.detail = "counter"
                  · simp [hKind, hDetail] at hCounter
                  · simp [hKind, hDetail]
                · simp [hKind]
              simp
                [ reconstructPathOramLeafScaffoldFromLogicalTraceAux
                , hOram
                , hBadCounter
                ] at hRecon
          · have hTail :
              reconstructPathOramLeafScaffoldFromLogicalTraceAux fuel events oramObjects =
                some scaffold := by
              simpa [reconstructPathOramLeafScaffoldFromLogicalTraceAux, hOram] using hRecon
            have hOramFalse : isOramLogicalKind event.kind = false := by
              cases hKind : isOramLogicalKind event.kind <;> simp [hKind] at hOram ⊢
            have hKindNe : event.kind ≠ "uooram_counter" := by
              intro hKind
              have hFalse : False := by
                simp [isOramLogicalKind, hKind] at hOram
              exact False.elim hFalse
            have hNotCounter :
                isOramCounterLogicalEvent event = false := by
              unfold isOramCounterLogicalEvent
              simp [hKindNe]
            have hNormEvent :
                pathOramNormalizeLogicalEvent event = event :=
              pathOramNormalizeLogicalEvent_eq_self_of_not_oram hOramFalse
            have hTailNorm := ih hTail
            simpa
              [ projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
              , pathOramNormalizeLogicalAccesses
              , hNormEvent
              , hNotCounter
              ] using hTailNorm

theorem projectedPathOramLeafScheduleScaffoldOfLogicalAccesses_normalize_of_reconstruct
  {logicalAccesses : List LogicalEvent}
  {oramObjects : List RuntimeOramObjectCertificate}
  {scaffold : List RuntimePathOramLeafScaffoldStep}
  {leakage : PathOramProjectedLeakage}
  (hRecon :
    reconstructPathOramLeafScaffoldFromLogicalTrace
      logicalAccesses
      oramObjects =
    some scaffold) :
  projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      (pathOramNormalizeLogicalAccesses logicalAccesses)
      leakage =
    projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
      logicalAccesses
      leakage := by
  simpa [reconstructPathOramLeafScaffoldFromLogicalTrace] using
    (projectedPathOramLeafScheduleScaffoldOfLogicalAccesses_normalize_of_reconstructAux
      (leakage := leakage)
      hRecon)

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

structure RuntimeControllerObserverCertificate where
  publicOutcome : SGXPublicOutcome
  boundarySchedule : List BoundaryEvent
  controllerShape : SGXControllerShape
  normalizedMicroTrace : NormalizedMicroTrace
  controllerCertificate : RuntimeControllerCertificate
deriving Repr, DecidableEq

def RuntimeControllerObserverCertificate.microLeakage
  (certificate : RuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) : SGXMicroLeakage :=
  sgxMicroLeakageOfController
    certificate.publicOutcome
    modelTags
    certificate.controllerShape

def RuntimeControllerObserverCertificate.Valid
  (certificate : RuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) : Prop :=
  certificate.boundarySchedule =
      certificate.controllerCertificate.boundarySchedule certificate.publicOutcome ∧
    certificate.controllerShape = certificate.controllerCertificate.controllerShape ∧
    certificate.normalizedMicroTrace =
      simulateNormalizedMicroTraceFromLeakage (certificate.microLeakage modelTags)

def RuntimeControllerObserverCertificate.checkValid
  (certificate : RuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) : Bool :=
  decide
      (certificate.boundarySchedule =
        certificate.controllerCertificate.boundarySchedule certificate.publicOutcome) &&
    decide
      (certificate.controllerShape = certificate.controllerCertificate.controllerShape) &&
    decide
      (certificate.normalizedMicroTrace =
        simulateNormalizedMicroTraceFromLeakage (certificate.microLeakage modelTags))

@[simp] theorem runtimeControllerObserverCertificate_checkValid_eq_true_iff
  (certificate : RuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) :
  certificate.checkValid modelTags = true ↔ certificate.Valid modelTags := by
  simp [RuntimeControllerObserverCertificate.checkValid,
    RuntimeControllerObserverCertificate.Valid, and_assoc]

theorem runtimeControllerObserverCertificate_boundaryBudget_exact
  (certificate : RuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags)
  (hValid : certificate.Valid modelTags) :
  certificate.boundarySchedule.length = certificate.controllerShape.boundaryEventBudget := by
  rcases hValid with ⟨hBoundary, hShape, _hNormalized⟩
  rw [hBoundary, hShape]
  exact runtimeControllerCertificate_boundarySchedule_budget
    certificate.controllerCertificate
    certificate.publicOutcome

theorem runtimeControllerObserverCertificate_normalizedMicro_exact
  (certificate : RuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags)
  (hValid : certificate.Valid modelTags) :
  certificate.normalizedMicroTrace =
    simulateNormalizedMicroTraceFromLeakage (certificate.microLeakage modelTags) := by
  exact hValid.2.2

structure RuntimePathOramHiddenCertificate where
  trace : Trace
  oramObjects : List RuntimeOramObjectCertificate
  oramLeafPublicScaffold : List RuntimePathOramLeafScaffoldStep
  oramLeafSchedule : List RuntimeOramLeafCertificate
  oramPositionMapBefore : List RuntimePathOramPositionMapCertificate
  oramPositionMapAfter : List RuntimePathOramPositionMapCertificate
  oramLeafStateTransitions : List RuntimePathOramTransitionCertificate
deriving Repr, DecidableEq

def RuntimePathOramHiddenCertificate.pathOramLeafScheduleTrace
  (certificate : RuntimePathOramHiddenCertificate) : PathOramLeafScheduleTrace :=
  certificate.oramLeafSchedule.map RuntimeOramLeafCertificate.toPathOramLeafScheduleStep

def RuntimePathOramHiddenCertificate.pathOramLeafScaffold
  (certificate : RuntimePathOramHiddenCertificate) : List RuntimePathOramLeafScaffoldStep :=
  certificate.oramLeafSchedule.map RuntimeOramLeafCertificate.scaffoldStep

def RuntimePathOramHiddenCertificate.projectedPathOramLeafScaffold
  (certificate : RuntimePathOramHiddenCertificate) : PathOramLeafScheduleScaffold :=
  certificate.pathOramLeafScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def RuntimePathOramHiddenCertificate.projectedPublicPathOramLeafScaffold
  (certificate : RuntimePathOramHiddenCertificate) : PathOramLeafScheduleScaffold :=
  certificate.oramLeafPublicScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def RuntimePathOramHiddenCertificate.pathOramBucketTrace
  (certificate : RuntimePathOramHiddenCertificate) : PathOramBucketTrace :=
  pathOramBucketTraceOfView (viewMPlus certificate.trace)

def RuntimePathOramHiddenCertificate.pathOramTransitionShapes
  (certificate : RuntimePathOramHiddenCertificate) : List RuntimePathOramTransitionShape :=
  certificate.oramLeafStateTransitions.map RuntimePathOramTransitionCertificate.shape

def RuntimePathOramHiddenCertificate.replayedPathOramPositionMapState
  (certificate : RuntimePathOramHiddenCertificate) : Option RuntimePathOramPositionMapState :=
  replayRuntimePathOramTransitions
    certificate.oramPositionMapBefore
    certificate.oramObjects
    certificate.oramLeafSchedule
    certificate.oramLeafStateTransitions

def RuntimePathOramHiddenCertificate.expectedPathOramPositionMapState
  (certificate : RuntimePathOramHiddenCertificate) : Option RuntimePathOramPositionMapState :=
  runtimePathOramPositionMapStateByObject
    certificate.oramPositionMapAfter
    certificate.oramObjects

def RuntimePathOramHiddenCertificate.Valid
  (certificate : RuntimePathOramHiddenCertificate) : Prop :=
  reconstructPathOramLeafScaffoldFromLogicalTrace
      certificate.trace.logicalAccesses
      certificate.oramObjects =
    some certificate.pathOramLeafScaffold ∧
    certificate.oramLeafPublicScaffold = certificate.pathOramLeafScaffold ∧
    certificate.replayedPathOramPositionMapState =
      certificate.expectedPathOramPositionMapState ∧
    certificate.replayedPathOramPositionMapState.isSome = true ∧
    pathOramBucketTraceOfLeafScheduleTrace certificate.pathOramLeafScheduleTrace =
      certificate.pathOramBucketTrace

def RuntimePathOramHiddenCertificate.checkValid
  (certificate : RuntimePathOramHiddenCertificate) : Bool :=
  decide
      (reconstructPathOramLeafScaffoldFromLogicalTrace
          certificate.trace.logicalAccesses
          certificate.oramObjects =
        some certificate.pathOramLeafScaffold) &&
    decide (certificate.oramLeafPublicScaffold = certificate.pathOramLeafScaffold) &&
    decide
      (certificate.replayedPathOramPositionMapState =
        certificate.expectedPathOramPositionMapState) &&
    decide (certificate.replayedPathOramPositionMapState.isSome = true) &&
    decide
      (pathOramBucketTraceOfLeafScheduleTrace certificate.pathOramLeafScheduleTrace =
        certificate.pathOramBucketTrace)

@[simp] theorem runtimePathOramHiddenCertificate_checkValid_eq_true_iff
  (certificate : RuntimePathOramHiddenCertificate) :
  certificate.checkValid = true ↔ certificate.Valid := by
  simp [RuntimePathOramHiddenCertificate.checkValid,
    RuntimePathOramHiddenCertificate.Valid, and_assoc]

theorem runtimePathOramHiddenCertificate_publicPathOramLeafScaffold_matches_hidden
  (certificate : RuntimePathOramHiddenCertificate)
  (hValid : certificate.Valid) :
  certificate.oramLeafPublicScaffold = certificate.pathOramLeafScaffold := by
  exact hValid.2.1

theorem runtimePathOramHiddenCertificate_pathOramLeafScaffold_exact
  (certificate : RuntimePathOramHiddenCertificate)
  (hValid : certificate.Valid) :
  reconstructPathOramLeafScaffoldFromLogicalTrace
      certificate.trace.logicalAccesses
      certificate.oramObjects =
    some certificate.pathOramLeafScaffold := by
  exact hValid.1

theorem runtimePathOramHiddenCertificate_pathOramLeafStateReplay_exact
  (certificate : RuntimePathOramHiddenCertificate)
  (hValid : certificate.Valid) :
  certificate.replayedPathOramPositionMapState =
    certificate.expectedPathOramPositionMapState := by
  exact hValid.2.2.1

theorem runtimePathOramHiddenCertificate_pathOramLeafStateReplay_some
  (certificate : RuntimePathOramHiddenCertificate)
  (hValid : certificate.Valid) :
  certificate.replayedPathOramPositionMapState.isSome = true := by
  exact hValid.2.2.2.1

theorem runtimePathOramHiddenCertificate_pathOramBucketProjection_exact
  (certificate : RuntimePathOramHiddenCertificate)
  (hValid : certificate.Valid) :
  pathOramBucketTraceOfLeafScheduleTrace certificate.pathOramLeafScheduleTrace =
    certificate.pathOramBucketTrace := by
  exact hValid.2.2.2.2

def runtimeKernelOpcodeNames : List String :=
  [ "Begin"
  , "CellGet"
  , "CellSet"
  , "ArrayGet"
  , "ArraySet"
  , "MapGet"
  , "MapPut"
  , "Commit"
  , "Wipe"
  ]

def runtimeKernelObjectOpcodeNames : List String :=
  [ "CellGet"
  , "CellSet"
  , "ArrayGet"
  , "ArraySet"
  , "MapGet"
  , "MapPut"
  ]

def runtimeKernelOpcodeRequiresObjectId
  (opcode : String) : Bool :=
  decide (opcode ∈ runtimeKernelObjectOpcodeNames)

structure RuntimeKernelStep where
  opcode : String
  objectId : Option Nat
deriving Repr, DecidableEq

def RuntimeKernelStep.checkShapeValid
  (step : RuntimeKernelStep) : Bool :=
  decide (step.objectId.isSome = runtimeKernelOpcodeRequiresObjectId step.opcode)

def RuntimeKernelStep.publicObjectFragment
  (step : RuntimeKernelStep) : List Nat :=
  match step.objectId with
  | none => []
  | some objectId => [objectId]

structure RuntimeKernelSchedule where
  opcodes : List String
  steps : List RuntimeKernelStep
deriving Repr, DecidableEq

def RuntimeKernelSchedule.projectedOpcodes
  (schedule : RuntimeKernelSchedule) : List String :=
  schedule.steps.map RuntimeKernelStep.opcode

def RuntimeKernelSchedule.publicObjectSchedule
  (schedule : RuntimeKernelSchedule) : List Nat :=
  schedule.steps.filterMap RuntimeKernelStep.objectId

def RuntimeKernelSchedule.opcodesAllowed
  (schedule : RuntimeKernelSchedule) : Bool :=
  schedule.opcodes.all (fun opcode => decide (opcode ∈ runtimeKernelOpcodeNames))

def RuntimeKernelSchedule.checkShapeValid
  (schedule : RuntimeKernelSchedule) : Bool :=
  schedule.steps.all RuntimeKernelStep.checkShapeValid &&
    decide (schedule.steps = [] ∨ schedule.projectedOpcodes = schedule.opcodes)

inductive RuntimeKernelExecutionPhase
  | ready
  | active
  | committed
  | finished
deriving Repr, DecidableEq

structure RuntimeKernelExecutionState where
  phase : RuntimeKernelExecutionPhase
  publicObjectSchedule : List Nat
deriving Repr, DecidableEq

def RuntimeKernelExecutionState.init : RuntimeKernelExecutionState :=
  { phase := .ready
  , publicObjectSchedule := []
  }

def RuntimeKernelExecutionState.step
  (state : RuntimeKernelExecutionState)
  (step : RuntimeKernelStep) : Option RuntimeKernelExecutionState :=
  match state.phase, step.objectId with
  | .ready, none =>
      if step.opcode = "Begin" then
        some { state with phase := .active }
      else
        none
  | .active, some objectId =>
      if runtimeKernelOpcodeRequiresObjectId step.opcode then
        some
          { state with
              publicObjectSchedule := state.publicObjectSchedule ++ [objectId] }
      else
        none
  | .active, none =>
      if step.opcode = "Commit" then
        some { state with phase := .committed }
      else
        none
  | .committed, none =>
      if step.opcode = "Wipe" then
        some { state with phase := .finished }
      else
        none
  | _, _ =>
      none

def RuntimeKernelSchedule.finalState?
  (schedule : RuntimeKernelSchedule) : Option RuntimeKernelExecutionState :=
  schedule.steps.foldlM RuntimeKernelExecutionState.step RuntimeKernelExecutionState.init

def RuntimeKernelSchedule.checkRunsToCompletion
  (schedule : RuntimeKernelSchedule) : Bool :=
  match schedule.finalState? with
  | some finalState => decide (finalState.phase = .finished)
  | none => false

def RuntimeKernelSchedule.hasBeginCommitWipeEnvelope
  (schedule : RuntimeKernelSchedule) : Bool :=
  decide (schedule.opcodes.head? = some "Begin") &&
    decide
      (schedule.opcodes.drop (schedule.opcodes.length - 2) = ["Commit", "Wipe"])

def RuntimeKernelSchedule.Valid
  (schedule : RuntimeKernelSchedule) : Prop :=
  schedule.opcodesAllowed = true ∧
    schedule.checkShapeValid = true ∧
    schedule.hasBeginCommitWipeEnvelope = true ∧
    schedule.checkRunsToCompletion = true

def RuntimeKernelSchedule.checkValid
  (schedule : RuntimeKernelSchedule) : Bool :=
  schedule.opcodesAllowed &&
    schedule.checkShapeValid &&
    schedule.hasBeginCommitWipeEnvelope &&
    schedule.checkRunsToCompletion

@[simp] theorem runtimeKernelSchedule_checkValid_eq_true_iff
  (schedule : RuntimeKernelSchedule) :
  schedule.checkValid = true ↔ schedule.Valid := by
  simp [RuntimeKernelSchedule.checkValid, RuntimeKernelSchedule.Valid, and_assoc]

@[simp] theorem runtimeKernelSchedule_checkRunsToCompletion_eq_true_iff
  (schedule : RuntimeKernelSchedule) :
  schedule.checkRunsToCompletion = true ↔
    ∃ finalState, schedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  unfold RuntimeKernelSchedule.checkRunsToCompletion
  cases hFinal : schedule.finalState? with
  | none =>
      simp
  | some finalState =>
      simp

theorem runtimeKernelExecutionState_step_publicObjectSchedule
  {state nextState : RuntimeKernelExecutionState}
  {step : RuntimeKernelStep}
  (hStep : RuntimeKernelExecutionState.step state step = some nextState) :
  nextState.publicObjectSchedule =
    state.publicObjectSchedule ++ step.publicObjectFragment := by
  cases hPhase : state.phase <;> cases hObject : step.objectId <;>
    simp [RuntimeKernelExecutionState.step, RuntimeKernelStep.publicObjectFragment,
      hPhase, hObject] at hStep ⊢
  case ready.none =>
    rcases hStep with ⟨_, hEq⟩
    cases hEq
    simp
  case active.some objectId =>
    rcases hStep with ⟨_, hEq⟩
    cases hEq
    simp
  case active.none =>
    rcases hStep with ⟨_, hEq⟩
    cases hEq
    simp
  case committed.none =>
    rcases hStep with ⟨_, hEq⟩
    cases hEq
    simp

theorem runtimeKernelExecutionState_runSteps_publicObjectSchedule
  {steps : List RuntimeKernelStep}
  {state finalState : RuntimeKernelExecutionState}
  (hRun : steps.foldlM RuntimeKernelExecutionState.step state = some finalState) :
  finalState.publicObjectSchedule =
    state.publicObjectSchedule ++ steps.filterMap RuntimeKernelStep.objectId := by
  induction steps generalizing state with
  | nil =>
      simp at hRun
      cases hRun
      simp
  | cons step rest ih =>
      simp [List.foldlM] at hRun
      cases hStep : RuntimeKernelExecutionState.step state step with
      | none =>
          simp [hStep] at hRun
      | some nextState =>
          have hStepSchedule :
              nextState.publicObjectSchedule =
                state.publicObjectSchedule ++ step.publicObjectFragment :=
            runtimeKernelExecutionState_step_publicObjectSchedule hStep
          have hRunRest :
              rest.foldlM RuntimeKernelExecutionState.step nextState = some finalState := by
            simpa [hStep] using hRun
          have hRest :
              finalState.publicObjectSchedule =
                nextState.publicObjectSchedule ++ rest.filterMap RuntimeKernelStep.objectId := by
            exact ih hRunRest
          rw [hRest, hStepSchedule]
          cases hObject : step.objectId <;>
            simp [RuntimeKernelStep.publicObjectFragment, hObject, List.append_assoc]

theorem runtimeKernelSchedule_finalState_publicObjectSchedule
  {schedule : RuntimeKernelSchedule}
  {finalState : RuntimeKernelExecutionState}
  (hFinal : schedule.finalState? = some finalState) :
  finalState.publicObjectSchedule = schedule.publicObjectSchedule := by
  unfold RuntimeKernelSchedule.finalState? at hFinal
  simpa [RuntimeKernelSchedule.publicObjectSchedule, RuntimeKernelExecutionState.init] using
    runtimeKernelExecutionState_runSteps_publicObjectSchedule hFinal

theorem runtimeKernelSchedule_finalState_finished
  {schedule : RuntimeKernelSchedule}
  {finalState : RuntimeKernelExecutionState}
  (hCompletion : schedule.checkRunsToCompletion = true)
  (hFinal : schedule.finalState? = some finalState) :
  finalState.phase = .finished := by
  rcases (runtimeKernelSchedule_checkRunsToCompletion_eq_true_iff schedule).mp hCompletion with
    ⟨finishedState, hFinishedState, hFinished⟩
  rw [hFinal] at hFinishedState
  cases hFinishedState
  exact hFinished

theorem runtimeKernelSchedule_finalState_exact
  {schedule : RuntimeKernelSchedule}
  {finalState : RuntimeKernelExecutionState}
  (hCompletion : schedule.checkRunsToCompletion = true)
  (hFinal : schedule.finalState? = some finalState) :
  finalState =
    { phase := .finished, publicObjectSchedule := schedule.publicObjectSchedule } := by
  have hFinished : finalState.phase = .finished :=
    runtimeKernelSchedule_finalState_finished hCompletion hFinal
  have hObjects : finalState.publicObjectSchedule = schedule.publicObjectSchedule :=
    runtimeKernelSchedule_finalState_publicObjectSchedule hFinal
  cases finalState with
  | mk phase publicObjectSchedule =>
      simp at hFinished hObjects
      simp [hFinished, hObjects]

theorem runtimeKernelSchedule_valid_finalState_exact
  {schedule : RuntimeKernelSchedule}
  (hValid : schedule.Valid) :
  schedule.finalState? =
    some { phase := .finished, publicObjectSchedule := schedule.publicObjectSchedule } := by
  rcases (runtimeKernelSchedule_checkRunsToCompletion_eq_true_iff schedule).mp hValid.2.2.2 with
    ⟨finalState, hFinal, _⟩
  rw [runtimeKernelSchedule_finalState_exact hValid.2.2.2 hFinal] at hFinal
  exact hFinal

def runtimeKernelResourceEventKindNames : List String :=
  [ "stack_check"
  , "reserve_scratch"
  , "wipe_scratch"
  ]

def runtimeKernelScratchRegionNames : List String :=
  [ "value_scratch"
  , "hash_scratch"
  , "io_scratch"
  ]

structure RuntimeKernelResourceEvent where
  kind : String
  region : Option String
  words : Option Nat
  bytes : Option Nat
deriving Repr, DecidableEq

def RuntimeKernelResourceEvent.checkShapeValid
  (event : RuntimeKernelResourceEvent) : Bool :=
  decide (event.kind ∈ runtimeKernelResourceEventKindNames) &&
    match event.kind, event.region, event.words, event.bytes with
    | "stack_check", none, some _, none =>
        true
    | "reserve_scratch", some region, none, some _ =>
        decide (region ∈ runtimeKernelScratchRegionNames)
    | "wipe_scratch", some region, none, none =>
        decide (region ∈ runtimeKernelScratchRegionNames)
    | _, _, _, _ =>
        false

structure RuntimeKernelScratchUsage where
  liveBytes : Nat
  peakBytes : Nat
  wipeCount : Nat
deriving Repr, DecidableEq

def RuntimeKernelScratchUsage.reserve
  (usage : RuntimeKernelScratchUsage)
  (bytes : Nat) : RuntimeKernelScratchUsage :=
  { liveBytes := bytes
  , peakBytes := max usage.peakBytes bytes
  , wipeCount := usage.wipeCount
  }

def RuntimeKernelScratchUsage.wipe
  (usage : RuntimeKernelScratchUsage) : RuntimeKernelScratchUsage :=
  { liveBytes := 0
  , peakBytes := usage.peakBytes
  , wipeCount := usage.wipeCount + 1
  }

structure RuntimeKernelResourceState where
  peakStackWords : Nat
  valueScratch : RuntimeKernelScratchUsage
  hashScratch : RuntimeKernelScratchUsage
  ioScratch : RuntimeKernelScratchUsage
deriving Repr, DecidableEq

def RuntimeKernelResourceState.init : RuntimeKernelResourceState :=
  { peakStackWords := 0
  , valueScratch := { liveBytes := 0, peakBytes := 0, wipeCount := 0 }
  , hashScratch := { liveBytes := 0, peakBytes := 0, wipeCount := 0 }
  , ioScratch := { liveBytes := 0, peakBytes := 0, wipeCount := 0 }
  }

def RuntimeKernelResourceState.step
  (maxStackWords scratchBytes : Nat)
  (state : RuntimeKernelResourceState)
  (event : RuntimeKernelResourceEvent) : Option RuntimeKernelResourceState :=
  match event.kind, event.region, event.words, event.bytes with
  | "stack_check", none, some words, none =>
      if words ≤ maxStackWords then
        some { state with peakStackWords := max state.peakStackWords words }
      else
        none
  | "reserve_scratch", some "value_scratch", none, some bytes =>
      if bytes ≤ scratchBytes then
        some { state with valueScratch := state.valueScratch.reserve bytes }
      else
        none
  | "reserve_scratch", some "hash_scratch", none, some bytes =>
      if bytes ≤ scratchBytes then
        some { state with hashScratch := state.hashScratch.reserve bytes }
      else
        none
  | "reserve_scratch", some "io_scratch", none, some bytes =>
      if bytes ≤ scratchBytes then
        some { state with ioScratch := state.ioScratch.reserve bytes }
      else
        none
  | "wipe_scratch", some "value_scratch", none, none =>
      some { state with valueScratch := state.valueScratch.wipe }
  | "wipe_scratch", some "hash_scratch", none, none =>
      some { state with hashScratch := state.hashScratch.wipe }
  | "wipe_scratch", some "io_scratch", none, none =>
      some { state with ioScratch := state.ioScratch.wipe }
  | _, _, _, _ =>
      none

structure RuntimeKernelWitness where
  entrypointId : String
  arenaBytes : Nat
  maxStackWords : Nat
  scratchBytes : Nat
  peakStackWords : Nat
  valueScratchPeakBytes : Nat
  valueScratchLiveBytesEnd : Nat
  valueScratchWipeCount : Nat
  hashScratchPeakBytes : Nat
  hashScratchLiveBytesEnd : Nat
  hashScratchWipeCount : Nat
  ioScratchPeakBytes : Nat
  ioScratchLiveBytesEnd : Nat
  ioScratchWipeCount : Nat
  resourceEvents : List RuntimeKernelResourceEvent
  expectedKernelOpcodes : Option (List String)
  expectedKernelSteps : Option (List RuntimeKernelStep)
  publicObjectIds : List Nat
  expectedPublicObjectIds : Option (List Nat)
  kernelOpcodes : List String
  kernelSteps : List RuntimeKernelStep
deriving Repr, DecidableEq

def RuntimeKernelWitness.emittedKernelSchedule
  (witness : RuntimeKernelWitness) : RuntimeKernelSchedule :=
  { opcodes := witness.kernelOpcodes
  , steps := witness.kernelSteps
  }

def RuntimeKernelWitness.expectedKernelSchedule?
  (witness : RuntimeKernelWitness) : Option RuntimeKernelSchedule := do
  let opcodes ← witness.expectedKernelOpcodes
  let steps ← witness.expectedKernelSteps
  some { opcodes := opcodes, steps := steps }

def RuntimeKernelWitness.replayedResourceState?
  (witness : RuntimeKernelWitness) : Option RuntimeKernelResourceState :=
  witness.resourceEvents.foldlM
    (RuntimeKernelResourceState.step witness.maxStackWords witness.scratchBytes)
    RuntimeKernelResourceState.init

def RuntimeKernelWitness.claimedResourceState
  (witness : RuntimeKernelWitness) : RuntimeKernelResourceState :=
  { peakStackWords := witness.peakStackWords
  , valueScratch :=
      { liveBytes := witness.valueScratchLiveBytesEnd
      , peakBytes := witness.valueScratchPeakBytes
      , wipeCount := witness.valueScratchWipeCount
      }
  , hashScratch :=
      { liveBytes := witness.hashScratchLiveBytesEnd
      , peakBytes := witness.hashScratchPeakBytes
      , wipeCount := witness.hashScratchWipeCount
      }
  , ioScratch :=
      { liveBytes := witness.ioScratchLiveBytesEnd
      , peakBytes := witness.ioScratchPeakBytes
      , wipeCount := witness.ioScratchWipeCount
      }
  }

def RuntimeKernelWitness.ResourceReplayExact
  (witness : RuntimeKernelWitness) : Prop :=
  ∃ state, witness.replayedResourceState? = some state ∧
    state.peakStackWords = witness.peakStackWords ∧
    state.valueScratch.peakBytes = witness.valueScratchPeakBytes ∧
    state.valueScratch.liveBytes = witness.valueScratchLiveBytesEnd ∧
    state.valueScratch.wipeCount = witness.valueScratchWipeCount ∧
    state.hashScratch.peakBytes = witness.hashScratchPeakBytes ∧
    state.hashScratch.liveBytes = witness.hashScratchLiveBytesEnd ∧
    state.hashScratch.wipeCount = witness.hashScratchWipeCount ∧
    state.ioScratch.peakBytes = witness.ioScratchPeakBytes ∧
    state.ioScratch.liveBytes = witness.ioScratchLiveBytesEnd ∧
    state.ioScratch.wipeCount = witness.ioScratchWipeCount

def RuntimeKernelWitness.checkResourceReplayExact
  (witness : RuntimeKernelWitness) : Bool :=
  match witness.replayedResourceState? with
  | none => false
  | some state =>
      decide (state.peakStackWords = witness.peakStackWords) &&
        decide (state.valueScratch.peakBytes = witness.valueScratchPeakBytes) &&
        decide (state.valueScratch.liveBytes = witness.valueScratchLiveBytesEnd) &&
        decide (state.valueScratch.wipeCount = witness.valueScratchWipeCount) &&
        decide (state.hashScratch.peakBytes = witness.hashScratchPeakBytes) &&
        decide (state.hashScratch.liveBytes = witness.hashScratchLiveBytesEnd) &&
        decide (state.hashScratch.wipeCount = witness.hashScratchWipeCount) &&
        decide (state.ioScratch.peakBytes = witness.ioScratchPeakBytes) &&
        decide (state.ioScratch.liveBytes = witness.ioScratchLiveBytesEnd) &&
        decide (state.ioScratch.wipeCount = witness.ioScratchWipeCount)

@[simp] theorem runtimeKernelWitness_checkResourceReplayExact_eq_true_iff
  (witness : RuntimeKernelWitness) :
  witness.checkResourceReplayExact = true ↔ witness.ResourceReplayExact := by
  unfold RuntimeKernelWitness.checkResourceReplayExact
    RuntimeKernelWitness.ResourceReplayExact
  cases hReplay : witness.replayedResourceState? with
  | none =>
      simp
  | some state =>
      simp [and_assoc]

theorem runtimeKernelWitness_resourceReplayExact_eq_claimed
  (witness : RuntimeKernelWitness) :
  witness.ResourceReplayExact ↔
    witness.replayedResourceState? = some witness.claimedResourceState := by
  constructor
  · intro hReplay
    rcases hReplay with
      ⟨⟨peakStackWords, ⟨valueLiveBytes, valuePeakBytes, valueWipeCount⟩,
          ⟨hashLiveBytes, hashPeakBytes, hashWipeCount⟩,
          ⟨ioLiveBytes, ioPeakBytes, ioWipeCount⟩⟩,
        hState, hPeakStack, hValuePeak, hValueLive, hValueWipe, hHashPeak, hHashLive,
        hHashWipe, hIoPeak, hIoLive, hIoWipe⟩
    cases hPeakStack
    cases hValuePeak
    cases hValueLive
    cases hValueWipe
    cases hHashPeak
    cases hHashLive
    cases hHashWipe
    cases hIoPeak
    cases hIoLive
    cases hIoWipe
    simpa [RuntimeKernelWitness.claimedResourceState] using hState
  · intro hReplay
    refine ⟨witness.claimedResourceState, hReplay, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;>
      simp [RuntimeKernelWitness.claimedResourceState]

def RuntimeKernelWitness.kernelOpcodesAllowed
  (witness : RuntimeKernelWitness) : Bool :=
  witness.kernelOpcodes.all (fun opcode => decide (opcode ∈ runtimeKernelOpcodeNames))

def RuntimeKernelWitness.kernelStepsShapeValid
  (witness : RuntimeKernelWitness) : Bool :=
  witness.kernelSteps.all RuntimeKernelStep.checkShapeValid

def RuntimeKernelWitness.projectedKernelOpcodes
  (witness : RuntimeKernelWitness) : List String :=
  witness.emittedKernelSchedule.projectedOpcodes

def RuntimeKernelWitness.kernelStepOpcodesMatch
  (witness : RuntimeKernelWitness) : Bool :=
  decide (witness.kernelSteps = [] ∨ witness.projectedKernelOpcodes = witness.kernelOpcodes)

def RuntimeKernelWitness.hasBeginCommitWipeEnvelope
  (witness : RuntimeKernelWitness) : Bool :=
  decide (witness.kernelOpcodes.head? = some "Begin") &&
    decide
      (witness.kernelOpcodes.drop (witness.kernelOpcodes.length - 2) = ["Commit", "Wipe"])

def runtimeKernelObjectIdScheduleCanonical : List Nat → Bool
  | [] => true
  | [_] => true
  | head :: next :: tail =>
      decide (head < next) && runtimeKernelObjectIdScheduleCanonical (next :: tail)

def RuntimeKernelWitness.publicObjectIdsShapeValid
  (witness : RuntimeKernelWitness) : Bool :=
  runtimeKernelObjectIdScheduleCanonical witness.publicObjectIds

def RuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch
  (witness : RuntimeKernelWitness) : Bool :=
  match witness.expectedPublicObjectIds with
  | none => true
  | some expectedPublicObjectIds =>
      runtimeKernelObjectIdScheduleCanonical expectedPublicObjectIds &&
        decide (witness.publicObjectIds = expectedPublicObjectIds)

def RuntimeKernelWitness.kernelObjectsInPublicObjectUniverse
  (witness : RuntimeKernelWitness) : Bool :=
  witness.kernelSteps.filterMap RuntimeKernelStep.objectId |>.all (fun objectId =>
    decide (objectId ∈ witness.publicObjectIds))

def RuntimeKernelWitness.ValidForEntrypoint
  (witness : RuntimeKernelWitness)
  (entrypointId : String) : Prop :=
  witness.entrypointId = entrypointId ∧
    witness.scratchBytes = witness.arenaBytes / 4 ∧
    witness.peakStackWords ≤ witness.maxStackWords ∧
    witness.valueScratchPeakBytes ≤ witness.scratchBytes ∧
    witness.hashScratchPeakBytes ≤ witness.scratchBytes ∧
    witness.ioScratchPeakBytes ≤ witness.scratchBytes ∧
    witness.valueScratchLiveBytesEnd = 0 ∧
    (witness.valueScratchPeakBytes = 0 ∨ 0 < witness.valueScratchWipeCount) ∧
    witness.hashScratchLiveBytesEnd = 0 ∧
    (witness.hashScratchPeakBytes = 0 ∨ 0 < witness.hashScratchWipeCount) ∧
    witness.ioScratchLiveBytesEnd = 0 ∧
    (witness.ioScratchPeakBytes = 0 ∨ 0 < witness.ioScratchWipeCount) ∧
    witness.ResourceReplayExact ∧
    witness.kernelOpcodesAllowed = true ∧
    witness.kernelStepsShapeValid = true ∧
    witness.kernelStepOpcodesMatch = true ∧
    witness.hasBeginCommitWipeEnvelope = true ∧
    witness.emittedKernelSchedule.checkRunsToCompletion = true ∧
    (match witness.expectedKernelOpcodes with
    | none => True
    | some expectedKernelOpcodes => witness.kernelOpcodes = expectedKernelOpcodes) ∧
    (match witness.expectedKernelSteps with
    | none => True
    | some expectedKernelSteps => witness.kernelSteps = expectedKernelSteps) ∧
    witness.publicObjectIdsShapeValid = true ∧
    witness.expectedPublicObjectIdsShapeAndMatch = true ∧
    witness.kernelObjectsInPublicObjectUniverse = true

def RuntimeKernelWitness.checkValidForEntrypoint
  (witness : RuntimeKernelWitness)
  (entrypointId : String) : Bool :=
  decide (witness.entrypointId = entrypointId) &&
    decide (witness.scratchBytes = witness.arenaBytes / 4) &&
    decide (witness.peakStackWords ≤ witness.maxStackWords) &&
    decide (witness.valueScratchPeakBytes ≤ witness.scratchBytes) &&
    decide (witness.hashScratchPeakBytes ≤ witness.scratchBytes) &&
    decide (witness.ioScratchPeakBytes ≤ witness.scratchBytes) &&
    decide (witness.valueScratchLiveBytesEnd = 0) &&
    decide
      (witness.valueScratchPeakBytes = 0 ∨ 0 < witness.valueScratchWipeCount) &&
    decide (witness.hashScratchLiveBytesEnd = 0) &&
    decide
      (witness.hashScratchPeakBytes = 0 ∨ 0 < witness.hashScratchWipeCount) &&
    decide (witness.ioScratchLiveBytesEnd = 0) &&
    decide
      (witness.ioScratchPeakBytes = 0 ∨ 0 < witness.ioScratchWipeCount) &&
    witness.checkResourceReplayExact &&
    witness.kernelOpcodesAllowed &&
    witness.kernelStepsShapeValid &&
    witness.kernelStepOpcodesMatch &&
    witness.hasBeginCommitWipeEnvelope &&
    witness.emittedKernelSchedule.checkRunsToCompletion &&
    (match witness.expectedKernelOpcodes with
    | none => true
    | some expectedKernelOpcodes => decide (witness.kernelOpcodes = expectedKernelOpcodes)) &&
    (match witness.expectedKernelSteps with
    | none => true
    | some expectedKernelSteps => decide (witness.kernelSteps = expectedKernelSteps)) &&
    witness.publicObjectIdsShapeValid &&
    witness.expectedPublicObjectIdsShapeAndMatch &&
    witness.kernelObjectsInPublicObjectUniverse

def RuntimeKernelWitness.ProofGradeValid
  (witness : RuntimeKernelWitness)
  (entrypointId : String) : Prop :=
  witness.ValidForEntrypoint entrypointId ∧
    match witness.expectedKernelOpcodes with
    | none => False
    | some _ =>
        match witness.expectedKernelSteps with
        | none => False
        | some _ =>
            match witness.expectedPublicObjectIds with
            | none => False
            | some _ => True

def RuntimeKernelWitness.checkProofGradeForEntrypoint
  (witness : RuntimeKernelWitness)
  (entrypointId : String) : Bool :=
  witness.checkValidForEntrypoint entrypointId &&
    witness.expectedKernelOpcodes.isSome &&
    witness.expectedKernelSteps.isSome &&
    witness.expectedPublicObjectIds.isSome

@[simp] theorem runtimeKernelWitness_checkValidForEntrypoint_eq_true_iff
  (witness : RuntimeKernelWitness)
  (entrypointId : String) :
  witness.checkValidForEntrypoint entrypointId = true ↔
    witness.ValidForEntrypoint entrypointId := by
  cases hExpectedOpcodes : witness.expectedKernelOpcodes <;>
    cases hExpectedSteps : witness.expectedKernelSteps <;>
    cases hExpectedPublicObjectIds : witness.expectedPublicObjectIds <;>
    simp [RuntimeKernelWitness.checkValidForEntrypoint,
      RuntimeKernelWitness.ValidForEntrypoint,
      runtimeKernelWitness_checkResourceReplayExact_eq_true_iff,
      RuntimeKernelWitness.kernelOpcodesAllowed,
      RuntimeKernelWitness.kernelStepsShapeValid,
      RuntimeKernelWitness.projectedKernelOpcodes,
      RuntimeKernelWitness.kernelStepOpcodesMatch,
      RuntimeKernelStep.checkShapeValid,
      RuntimeKernelWitness.hasBeginCommitWipeEnvelope,
      RuntimeKernelWitness.publicObjectIdsShapeValid,
      RuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch,
      RuntimeKernelWitness.kernelObjectsInPublicObjectUniverse,
      hExpectedOpcodes, hExpectedSteps, hExpectedPublicObjectIds,
      List.all_eq_true, and_assoc]

@[simp] theorem runtimeKernelWitness_checkProofGradeForEntrypoint_eq_true_iff
  (witness : RuntimeKernelWitness)
  (entrypointId : String) :
  witness.checkProofGradeForEntrypoint entrypointId = true ↔
    witness.ProofGradeValid entrypointId := by
  cases hExpectedOpcodes : witness.expectedKernelOpcodes <;>
    cases hExpectedSteps : witness.expectedKernelSteps <;>
    cases hExpectedPublicObjectIds : witness.expectedPublicObjectIds <;>
    simp [RuntimeKernelWitness.checkProofGradeForEntrypoint,
      RuntimeKernelWitness.ProofGradeValid,
      hExpectedOpcodes, hExpectedSteps, hExpectedPublicObjectIds]

theorem runtimeKernelWitness_proofGradeValid_self
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  witness.ProofGradeValid witness.entrypointId := by
  rcases hValid with ⟨hWitnessValid, hProofGradeShape⟩
  rcases hWitnessValid with
    ⟨hEntrypoint, hScratch, hPeakStack, hValuePeak, hHashPeak, hIoPeak,
      hValueEnd, hValueWipe, hHashEnd, hHashWipe, hIoEnd, hIoWipe, hReplay,
      hOpcodesAllowed, hShape, hOpcodeMatch, hEnvelope, hCompletion,
      hExpectedOpcodes, hExpectedSteps, hPublicShape, hExpectedPublic, hUniverse⟩
  refine ⟨?_, hProofGradeShape⟩
  subst hEntrypoint
  exact
    ⟨rfl, hScratch, hPeakStack, hValuePeak, hHashPeak, hIoPeak, hValueEnd, hValueWipe,
      hHashEnd, hHashWipe, hIoEnd, hIoWipe, hReplay, hOpcodesAllowed, hShape,
      hOpcodeMatch, hEnvelope, hCompletion, hExpectedOpcodes, hExpectedSteps,
      hPublicShape, hExpectedPublic, hUniverse⟩

theorem runtimeKernelWitness_valid_replayedResourceState_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ValidForEntrypoint entrypointId) :
  witness.replayedResourceState? = some witness.claimedResourceState := by
  rcases hValid with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, hReplay, _, _, _, _, _, _, _, _, _⟩
  exact (runtimeKernelWitness_resourceReplayExact_eq_claimed witness).mp hReplay

theorem runtimeKernelWitness_proofGradeKernelSchedule_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSteps,
    witness.expectedKernelSteps = some expectedKernelSteps ∧
      witness.kernelSteps = expectedKernelSteps := by
  rcases hValid with ⟨hValidForEntrypoint, hProofGrade⟩
  cases hExpectedSteps : witness.expectedKernelSteps with
  | none =>
      cases hExpectedOpcodes : witness.expectedKernelOpcodes <;>
        simp [hExpectedSteps, hExpectedOpcodes] at hProofGrade
  | some expectedKernelSteps =>
      refine ⟨expectedKernelSteps, rfl, ?_⟩
      rcases hValidForEntrypoint with
        ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hKernelSteps, _, _, _⟩
      simpa [hExpectedSteps] using hKernelSteps

theorem runtimeKernelWitness_proofGradeKernelScheduleObject_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      witness.emittedKernelSchedule = expectedKernelSchedule := by
  rcases hValid with ⟨hValidForEntrypoint, hProofGrade⟩
  cases hExpectedOpcodes : witness.expectedKernelOpcodes with
  | none =>
      simp [hExpectedOpcodes] at hProofGrade
  | some expectedKernelOpcodes =>
      cases hExpectedSteps : witness.expectedKernelSteps with
      | none =>
          simp [hExpectedOpcodes, hExpectedSteps] at hProofGrade
      | some expectedKernelSteps =>
          refine ⟨{ opcodes := expectedKernelOpcodes, steps := expectedKernelSteps }, ?_, ?_⟩
          · simp [RuntimeKernelWitness.expectedKernelSchedule?, hExpectedOpcodes, hExpectedSteps]
          · rcases hValidForEntrypoint with
              ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hKernelOpcodes,
                hKernelSteps, _, _, _⟩
            simp [hExpectedOpcodes] at hKernelOpcodes
            simp [hExpectedSteps] at hKernelSteps
            cases hKernelOpcodes
            cases hKernelSteps
            rfl

theorem runtimeKernelWitness_proofGradePublicObjectUniverse_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedPublicObjectIds,
    witness.expectedPublicObjectIds = some expectedPublicObjectIds ∧
      witness.publicObjectIds = expectedPublicObjectIds := by
  rcases hValid with ⟨hValidForEntrypoint, hProofGrade⟩
  cases hExpectedPublicObjectIds : witness.expectedPublicObjectIds with
  | none =>
      cases hExpectedOpcodes : witness.expectedKernelOpcodes <;>
        cases hExpectedSteps : witness.expectedKernelSteps <;>
        simp [hExpectedOpcodes, hExpectedSteps, hExpectedPublicObjectIds] at hProofGrade
  | some expectedPublicObjectIds =>
      refine ⟨expectedPublicObjectIds, rfl, ?_⟩
      rcases hValidForEntrypoint with
        ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _,
          hPublicObjectIdsMatch, _⟩
      simp [RuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch, hExpectedPublicObjectIds]
        at hPublicObjectIdsMatch
      exact hPublicObjectIdsMatch.2

theorem runtimeKernelWitness_emittedKernelSchedule_valid
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ValidForEntrypoint entrypointId) :
  witness.emittedKernelSchedule.Valid := by
  rcases hValid with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, hOpcodesAllowed, hStepsShape, hOpcodeMatch,
      hEnvelope, hCompletion, _, _, _, _, _⟩
  have hAllowedEq :
      witness.emittedKernelSchedule.opcodesAllowed = witness.kernelOpcodesAllowed := by
    simp [RuntimeKernelSchedule.opcodesAllowed, RuntimeKernelWitness.kernelOpcodesAllowed,
      RuntimeKernelWitness.emittedKernelSchedule]
  have hCheckShape : witness.emittedKernelSchedule.checkShapeValid = true := by
    have hShapeEq :
        witness.emittedKernelSchedule.checkShapeValid =
          (witness.kernelStepsShapeValid && witness.kernelStepOpcodesMatch) := by
      simp [RuntimeKernelSchedule.checkShapeValid, RuntimeKernelWitness.emittedKernelSchedule,
        RuntimeKernelWitness.kernelStepsShapeValid, RuntimeKernelWitness.kernelStepOpcodesMatch,
        RuntimeKernelSchedule.projectedOpcodes, RuntimeKernelWitness.projectedKernelOpcodes]
    rw [hShapeEq]
    simp [hStepsShape, hOpcodeMatch]
  have hEnvelopeEq :
      witness.emittedKernelSchedule.hasBeginCommitWipeEnvelope =
        witness.hasBeginCommitWipeEnvelope := by
    unfold RuntimeKernelSchedule.hasBeginCommitWipeEnvelope
      RuntimeKernelWitness.emittedKernelSchedule
      RuntimeKernelWitness.hasBeginCommitWipeEnvelope
    rfl
  have hScheduleCheck : witness.emittedKernelSchedule.checkValid = true := by
    rw [RuntimeKernelSchedule.checkValid, hAllowedEq, hEnvelopeEq]
    simp [hOpcodesAllowed, hCheckShape, hEnvelope, hCompletion]
  exact (runtimeKernelSchedule_checkValid_eq_true_iff witness.emittedKernelSchedule).mp
    hScheduleCheck

theorem runtimeKernelWitness_emittedKernelSchedule_completes
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ValidForEntrypoint entrypointId) :
  ∃ finalState, witness.emittedKernelSchedule.finalState? = some finalState ∧
    finalState.phase = .finished := by
  rcases runtimeKernelWitness_emittedKernelSchedule_valid hValid with
    ⟨_, _, _, hCompletion⟩
  exact
    (runtimeKernelSchedule_checkRunsToCompletion_eq_true_iff witness.emittedKernelSchedule).mp
      hCompletion

theorem runtimeKernelWitness_proofGradeResourceState_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  witness.replayedResourceState? = some witness.claimedResourceState := by
  exact runtimeKernelWitness_valid_replayedResourceState_exact hValid.1

theorem runtimeKernelWitness_proofGradeExpectedKernelSchedule_valid
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.Valid := by
  rcases runtimeKernelWitness_proofGradeKernelScheduleObject_exact hValid with
    ⟨expectedKernelSchedule, hExpectedSchedule, hScheduleExact⟩
  refine ⟨expectedKernelSchedule, hExpectedSchedule, ?_⟩
  have hEmittedValid :
      witness.emittedKernelSchedule.Valid :=
    runtimeKernelWitness_emittedKernelSchedule_valid hValid.1
  simpa [hScheduleExact] using hEmittedValid

theorem runtimeKernelWitness_proofGradeExpectedKernelSchedule_completes
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule finalState,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  rcases runtimeKernelWitness_proofGradeKernelScheduleObject_exact hValid with
    ⟨expectedKernelSchedule, hExpectedSchedule, hScheduleExact⟩
  rcases runtimeKernelWitness_emittedKernelSchedule_completes hValid.1 with
    ⟨finalState, hFinalState, hFinished⟩
  refine ⟨expectedKernelSchedule, finalState, hExpectedSchedule, ?_, hFinished⟩
  simpa [hScheduleExact] using hFinalState

theorem runtimeKernelWitness_proofGradeExpectedKernelSchedule_publicObjects_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule finalState,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? = some finalState ∧
      finalState.publicObjectSchedule = expectedKernelSchedule.publicObjectSchedule := by
  rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_completes hValid with
    ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, _⟩
  refine ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, ?_⟩
  exact runtimeKernelSchedule_finalState_publicObjectSchedule hFinalState

theorem runtimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact
  {witness : RuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_valid hValid with
    ⟨expectedKernelSchedule, hExpectedSchedule, hScheduleValid⟩
  exact ⟨expectedKernelSchedule, hExpectedSchedule,
    runtimeKernelSchedule_valid_finalState_exact hScheduleValid⟩

structure RuntimeKernelRefinementEvent where
  kind : String
  objectId : Option Nat
  opcode : Option String
deriving Repr, DecidableEq

def runtimeKernelRefinementEventKindNames : List String :=
  [ "pre_committed_cold_object"
  , "shadow_load_object"
  , "kernel_step"
  , "commit_object"
  , "cold_store_object"
  , "post_committed_cold_object"
  ]

def RuntimeKernelRefinementEvent.projectedKernelStep?
  (event : RuntimeKernelRefinementEvent) : Option RuntimeKernelStep := do
  if event.kind = "kernel_step" then
    let opcode ← event.opcode
    some
      { opcode := opcode
      , objectId := event.objectId
      }
  else
    none

def RuntimeKernelRefinementEvent.checkShapeValid
  (event : RuntimeKernelRefinementEvent) : Bool :=
  decide (event.kind ∈ runtimeKernelRefinementEventKindNames) &&
    match event.kind with
    | "pre_committed_cold_object" =>
        decide (event.objectId.isSome ∧ event.opcode.isNone)
    | "shadow_load_object" =>
        decide (event.objectId.isSome ∧ event.opcode.isNone)
    | "kernel_step" =>
        match event.projectedKernelStep? with
        | some step => RuntimeKernelStep.checkShapeValid step
        | none => false
    | "commit_object" =>
        decide (event.objectId.isSome ∧ event.opcode.isNone)
    | "cold_store_object" =>
        decide (event.objectId.isSome ∧ event.opcode.isNone)
    | "post_committed_cold_object" =>
        decide (event.objectId.isSome ∧ event.opcode.isNone)
    | _ =>
        false

inductive RuntimeKernelRefinementPhase
  | beforeBegin
  | preCommittedColdWindow
  | shadowLoadWindow
  | activeKernel
  | commitObjectWindow
  | afterWipe
  | coldStoreWindow
  | postCommittedColdWindow
deriving Repr, DecidableEq

def RuntimeKernelRefinementPhase.step
  (phase : RuntimeKernelRefinementPhase)
  (event : RuntimeKernelRefinementEvent) : Option RuntimeKernelRefinementPhase :=
  if event.checkShapeValid then
    match phase, event.kind, event.opcode with
    | .beforeBegin, "pre_committed_cold_object", _ =>
        some .preCommittedColdWindow
    | .preCommittedColdWindow, "pre_committed_cold_object", _ =>
        some .preCommittedColdWindow
    | .beforeBegin, "kernel_step", some "Begin" =>
        some .shadowLoadWindow
    | .preCommittedColdWindow, "kernel_step", some "Begin" =>
        some .shadowLoadWindow
    | .shadowLoadWindow, "shadow_load_object", _ =>
        some .shadowLoadWindow
    | .shadowLoadWindow, "kernel_step", some "Commit" =>
        some .commitObjectWindow
    | .shadowLoadWindow, "kernel_step", some "Wipe" =>
        none
    | .shadowLoadWindow, "kernel_step", some _ =>
        some .activeKernel
    | .activeKernel, "kernel_step", some "Commit" =>
        some .commitObjectWindow
    | .activeKernel, "kernel_step", some "Wipe" =>
        none
    | .activeKernel, "kernel_step", some "Begin" =>
        none
    | .activeKernel, "kernel_step", some _ =>
        some .activeKernel
    | .commitObjectWindow, "commit_object", _ =>
        some .commitObjectWindow
    | .commitObjectWindow, "kernel_step", some "Wipe" =>
        some .afterWipe
    | .afterWipe, "cold_store_object", _ =>
        some .coldStoreWindow
    | .coldStoreWindow, "cold_store_object", _ =>
        some .coldStoreWindow
    | .afterWipe, "post_committed_cold_object", _ =>
        some .postCommittedColdWindow
    | .coldStoreWindow, "post_committed_cold_object", _ =>
        some .postCommittedColdWindow
    | .postCommittedColdWindow, "post_committed_cold_object", _ =>
        some .postCommittedColdWindow
    | _, _, _ =>
        none
  else
    none

structure RuntimeKernelRefinementWitness where
  events : List RuntimeKernelRefinementEvent
deriving Repr, DecidableEq

def RuntimeKernelRefinementWitness.projectedKernelSchedule
  (witness : RuntimeKernelRefinementWitness) : RuntimeKernelSchedule :=
  let steps := witness.events.filterMap RuntimeKernelRefinementEvent.projectedKernelStep?
  { opcodes := steps.map RuntimeKernelStep.opcode
  , steps := steps
  }

def RuntimeKernelRefinementWitness.shadowLoadObjectSchedule
  (witness : RuntimeKernelRefinementWitness) : List Nat :=
  witness.events.filterMap (fun event =>
    if event.kind = "shadow_load_object" then
      event.objectId
    else
      none)

def RuntimeKernelRefinementWitness.preCommittedColdObjectSchedule
  (witness : RuntimeKernelRefinementWitness) : List Nat :=
  witness.events.filterMap (fun event =>
    if event.kind = "pre_committed_cold_object" then
      event.objectId
    else
      none)

def RuntimeKernelRefinementWitness.commitObjectSchedule
  (witness : RuntimeKernelRefinementWitness) : List Nat :=
  witness.events.filterMap (fun event =>
    if event.kind = "commit_object" then
      event.objectId
    else
      none)

def RuntimeKernelRefinementWitness.coldStoreObjectSchedule
  (witness : RuntimeKernelRefinementWitness) : List Nat :=
  witness.events.filterMap (fun event =>
    if event.kind = "cold_store_object" then
      event.objectId
    else
      none)

def RuntimeKernelRefinementWitness.postCommittedColdObjectSchedule
  (witness : RuntimeKernelRefinementWitness) : List Nat :=
  witness.events.filterMap (fun event =>
    if event.kind = "post_committed_cold_object" then
      event.objectId
    else
      none)

def runtimeKernelInsertCanonicalObjectId (objectId : Nat) : List Nat → List Nat
  | [] => [objectId]
  | head :: tail =>
      if objectId = head then
        head :: tail
      else if objectId < head then
        objectId :: head :: tail
      else
        head :: runtimeKernelInsertCanonicalObjectId objectId tail

def RuntimeKernelWitness.canonicalLoadedObjectSchedule
  (witness : RuntimeKernelWitness) : List Nat :=
  witness.kernelSteps.foldl
    (fun acc step =>
      match step.objectId with
      | some objectId => runtimeKernelInsertCanonicalObjectId objectId acc
      | none => acc)
    []

def RuntimeKernelRefinementWitness.replayedPhase?
  (witness : RuntimeKernelRefinementWitness) : Option RuntimeKernelRefinementPhase :=
  witness.events.foldlM RuntimeKernelRefinementPhase.step .beforeBegin

def RuntimeKernelRefinementWitness.phaseTerminates
  (witness : RuntimeKernelRefinementWitness) : Bool :=
  match witness.replayedPhase? with
  | some .afterWipe => true
  | some .coldStoreWindow => true
  | some .postCommittedColdWindow => true
  | _ => false

def RuntimeKernelRefinementWitness.kernelObjectCoverage
  (witness : RuntimeKernelRefinementWitness) : Bool :=
  witness.projectedKernelSchedule.publicObjectSchedule.all (fun objectId =>
    decide (objectId ∈ witness.shadowLoadObjectSchedule))

def RuntimeKernelRefinementWitness.Valid
  (witness : RuntimeKernelRefinementWitness)
  (kernelWitness : RuntimeKernelWitness) : Prop :=
  witness.events.all RuntimeKernelRefinementEvent.checkShapeValid = true ∧
    witness.phaseTerminates = true ∧
    witness.projectedKernelSchedule = kernelWitness.emittedKernelSchedule ∧
    witness.preCommittedColdObjectSchedule = kernelWitness.publicObjectIds ∧
    witness.postCommittedColdObjectSchedule = kernelWitness.publicObjectIds ∧
    witness.shadowLoadObjectSchedule = witness.commitObjectSchedule ∧
    witness.shadowLoadObjectSchedule = witness.coldStoreObjectSchedule ∧
    witness.shadowLoadObjectSchedule = kernelWitness.canonicalLoadedObjectSchedule ∧
    witness.kernelObjectCoverage = true

def RuntimeKernelRefinementWitness.checkValid
  (witness : RuntimeKernelRefinementWitness)
  (kernelWitness : RuntimeKernelWitness) : Bool :=
  witness.events.all RuntimeKernelRefinementEvent.checkShapeValid &&
    witness.phaseTerminates &&
    decide (witness.projectedKernelSchedule = kernelWitness.emittedKernelSchedule) &&
    decide (witness.preCommittedColdObjectSchedule = kernelWitness.publicObjectIds) &&
    decide (witness.postCommittedColdObjectSchedule = kernelWitness.publicObjectIds) &&
    decide (witness.shadowLoadObjectSchedule = witness.commitObjectSchedule) &&
    decide (witness.shadowLoadObjectSchedule = witness.coldStoreObjectSchedule) &&
    decide (witness.shadowLoadObjectSchedule = kernelWitness.canonicalLoadedObjectSchedule) &&
    witness.kernelObjectCoverage

@[simp] theorem runtimeKernelRefinementWitness_checkValid_eq_true_iff
  (witness : RuntimeKernelRefinementWitness)
  (kernelWitness : RuntimeKernelWitness) :
  witness.checkValid kernelWitness = true ↔ witness.Valid kernelWitness := by
  simp [RuntimeKernelRefinementWitness.checkValid, RuntimeKernelRefinementWitness.Valid,
    RuntimeKernelRefinementWitness.phaseTerminates, and_assoc]

def RuntimeKernelRefinementWitness.RefinesLeanKernelState
  (runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness)
  (kernelWitness : RuntimeKernelWitness) : Prop :=
  ∃ expectedKernelSchedule,
    kernelWitness.ProofGradeValid kernelWitness.entrypointId ∧
      runtimeKernelRefinementWitness.Valid kernelWitness ∧
      kernelWitness.replayedResourceState? = some kernelWitness.claimedResourceState ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } ∧
      runtimeKernelRefinementWitness.projectedKernelSchedule =
        kernelWitness.emittedKernelSchedule ∧
      runtimeKernelRefinementWitness.preCommittedColdObjectSchedule =
        kernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.postCommittedColdObjectSchedule =
        kernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.shadowLoadObjectSchedule =
        kernelWitness.canonicalLoadedObjectSchedule ∧
      runtimeKernelRefinementWitness.commitObjectSchedule =
        kernelWitness.canonicalLoadedObjectSchedule ∧
      runtimeKernelRefinementWitness.coldStoreObjectSchedule =
        kernelWitness.canonicalLoadedObjectSchedule

theorem runtimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
  {runtimeKernelRefinementWitness : RuntimeKernelRefinementWitness}
  {kernelWitness : RuntimeKernelWitness}
  (hKernel : kernelWitness.ProofGradeValid kernelWitness.entrypointId)
  (hRefinement : runtimeKernelRefinementWitness.Valid kernelWitness) :
  runtimeKernelRefinementWitness.RefinesLeanKernelState kernelWitness := by
  have hWitnessValid := hRefinement
  rcases runtimeKernelWitness_proofGradeKernelScheduleObject_exact hKernel with
    ⟨expectedKernelSchedule, hExpectedKernelSchedule, hEmittedKernelSchedule⟩
  have hResourceState :
      kernelWitness.replayedResourceState? = some kernelWitness.claimedResourceState :=
    runtimeKernelWitness_proofGradeResourceState_exact hKernel
  have hFinalStateExact :
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
    rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact hKernel with
      ⟨expectedKernelSchedule', hExpectedKernelSchedule', hFinalStateExact⟩
    have hExpectedKernelScheduleEq : expectedKernelSchedule = expectedKernelSchedule' := by
      apply Option.some.inj
      calc
        some expectedKernelSchedule = kernelWitness.expectedKernelSchedule? := by
          symm
          exact hExpectedKernelSchedule
        _ = some expectedKernelSchedule' := hExpectedKernelSchedule'
    cases hExpectedKernelScheduleEq
    exact hFinalStateExact
  rcases hRefinement with
    ⟨_hShape, _hTerminates, hProjectedKernelSchedule, hPreCommittedCold,
      hPostCommittedCold, hShadowEqualsCommit, hShadowEqualsColdStore,
      hShadowEqualsCanonical, _hCoverage⟩
  refine
    ⟨expectedKernelSchedule, hKernel, hWitnessValid, hResourceState, hExpectedKernelSchedule,
      hEmittedKernelSchedule, hFinalStateExact, hProjectedKernelSchedule,
      hPreCommittedCold, hPostCommittedCold, hShadowEqualsCanonical, ?_, ?_⟩
  · calc
      runtimeKernelRefinementWitness.commitObjectSchedule =
          runtimeKernelRefinementWitness.shadowLoadObjectSchedule := by
            symm
            exact hShadowEqualsCommit
      _ = kernelWitness.canonicalLoadedObjectSchedule := hShadowEqualsCanonical
  · calc
      runtimeKernelRefinementWitness.coldStoreObjectSchedule =
          runtimeKernelRefinementWitness.shadowLoadObjectSchedule := by
            symm
            exact hShadowEqualsColdStore
      _ = kernelWitness.canonicalLoadedObjectSchedule := hShadowEqualsCanonical

structure RuntimeRefinementWitness where
  trace : Trace
  runtimeSeed : Option Nat
  publicOutcome : SGXPublicOutcome
  kernelWitness : Option RuntimeKernelWitness
  runtimeKernelRefinementWitness : Option RuntimeKernelRefinementWitness
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
  , publicEnv := witness.publicOutcome.publicEnv
  , boundarySchedule := witness.boundarySchedule
  , persistentReads := witness.trace.physicalReads
  , persistentWrites := witness.trace.physicalWrites
  , pageTrace := microTrace.pageTrace
  , exitTrace := microTrace.exitTrace
  , sharedResourceTrace := microTrace.sharedResourceTrace
  , terminationStatus := witness.publicOutcome.terminationStatus
  , statusPolicy := witness.publicOutcome.statusPolicy
  , outputShape := witness.publicOutcome.outputShape
  , returnPolicy := witness.publicOutcome.returnPolicy
  , returnPayload := witness.publicOutcome.returnPayload
  , encryptedReturnPayload := witness.publicOutcome.encryptedReturnPayload
  , declassifies := witness.publicOutcome.declassifies
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

def RuntimeRefinementWitness.pathOramFreshCoinBlocks?
  (witness : RuntimeRefinementWitness) : Option (List (List Nat)) :=
  extractRuntimePathOramFreshCoinBlocksAux
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

def RuntimeRefinementWitness.replayedPathOramLeafScheduleFromFreshCoinBlocks
  (witness : RuntimeRefinementWitness) : Option (List RuntimeOramLeafCertificate × RuntimePathOramPositionMapState) := do
  let coinBlocks ← witness.pathOramFreshCoinBlocks?
  replayRuntimePathOramLeafScheduleFromCoinBlocks
    witness.oramPositionMapBefore
    witness.oramObjects
    witness.pathOramTransitionShapes
    coinBlocks

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

def RuntimeRefinementWitness.controllerObserverCertificate
  (witness : RuntimeRefinementWitness) : RuntimeControllerObserverCertificate :=
  { publicOutcome := witness.publicOutcome
  , boundarySchedule := witness.boundarySchedule
  , controllerShape := witness.controllerShape
  , normalizedMicroTrace := witness.normalizedMicroTrace
  , controllerCertificate := witness.controllerCertificate
  }

def RuntimeRefinementWitness.pathOramHiddenCertificate
  (witness : RuntimeRefinementWitness) : RuntimePathOramHiddenCertificate :=
  { trace := witness.trace
  , oramObjects := witness.oramObjects
  , oramLeafPublicScaffold := witness.oramLeafPublicScaffold
  , oramLeafSchedule := witness.oramLeafSchedule
  , oramPositionMapBefore := witness.oramPositionMapBefore
  , oramPositionMapAfter := witness.oramPositionMapAfter
  , oramLeafStateTransitions := witness.oramLeafStateTransitions
  }

def RuntimeRefinementWitness.ObjectsMatchPublicConfig
  (witness : RuntimeRefinementWitness)
  (cfg : OramConfig) : Prop :=
  RuntimeOramObjectsMatchPublicConfig witness.oramObjects cfg

def RuntimeRefinementWitness.kernelWitnessValid
  (witness : RuntimeRefinementWitness) : Prop :=
  match witness.kernelWitness with
  | none => True
  | some kernelWitness =>
      kernelWitness.ValidForEntrypoint witness.publicOutcome.entrypointId

def RuntimeRefinementWitness.checkKernelWitness
  (witness : RuntimeRefinementWitness) : Bool :=
  match witness.kernelWitness with
  | none => true
  | some kernelWitness =>
      kernelWitness.checkValidForEntrypoint witness.publicOutcome.entrypointId

def RuntimeRefinementWitness.proofGradeKernelWitnessValid
  (witness : RuntimeRefinementWitness) : Prop :=
  match witness.kernelWitness with
  | none => False
  | some kernelWitness =>
      kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId

def RuntimeRefinementWitness.checkProofGradeKernelWitness
  (witness : RuntimeRefinementWitness) : Bool :=
  match witness.kernelWitness with
  | none => false
  | some kernelWitness =>
      kernelWitness.checkProofGradeForEntrypoint witness.publicOutcome.entrypointId

def RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid
  (witness : RuntimeRefinementWitness) : Prop :=
  match witness.runtimeKernelRefinementWitness with
  | none => True
  | some runtimeKernelRefinementWitness =>
      match witness.kernelWitness with
      | none => False
      | some kernelWitness =>
          runtimeKernelRefinementWitness.Valid kernelWitness

def RuntimeRefinementWitness.checkRuntimeKernelRefinementWitness
  (witness : RuntimeRefinementWitness) : Bool :=
  match witness.runtimeKernelRefinementWitness with
  | none => true
  | some runtimeKernelRefinementWitness =>
      match witness.kernelWitness with
      | none => false
      | some kernelWitness =>
          runtimeKernelRefinementWitness.checkValid kernelWitness

def RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid
  (witness : RuntimeRefinementWitness) : Prop :=
  match witness.kernelWitness, witness.runtimeKernelRefinementWitness with
  | some kernelWitness, some runtimeKernelRefinementWitness =>
      runtimeKernelRefinementWitness.Valid kernelWitness
  | _, _ =>
      False

def RuntimeRefinementWitness.checkProofGradeRuntimeKernelRefinementWitness
  (witness : RuntimeRefinementWitness) : Bool :=
  match witness.kernelWitness, witness.runtimeKernelRefinementWitness with
  | some kernelWitness, some runtimeKernelRefinementWitness =>
      runtimeKernelRefinementWitness.checkValid kernelWitness
  | _, _ =>
      false

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
      simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags) ∧
    witness.kernelWitnessValid ∧
    witness.runtimeKernelRefinementWitnessValid

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
        simulateNormalizedMicroTraceFromLeakage (witness.microLeakage modelTags)) &&
    witness.checkKernelWitness &&
    witness.checkRuntimeKernelRefinementWitness

def RuntimeRefinementWitness.ProofGradeValid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.Valid modelTags ∧
    witness.proofGradeKernelWitnessValid ∧
    witness.proofGradeRuntimeKernelRefinementWitnessValid

def RuntimeRefinementWitness.checkProofGrade
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  witness.checkValid modelTags &&
    witness.checkProofGradeKernelWitness &&
    witness.checkProofGradeRuntimeKernelRefinementWitness

@[simp] theorem runtimeWitness_checkKernelWitness_eq_true_iff
  (witness : RuntimeRefinementWitness) :
  witness.checkKernelWitness = true ↔ witness.kernelWitnessValid := by
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.checkKernelWitness,
        RuntimeRefinementWitness.kernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [RuntimeRefinementWitness.checkKernelWitness,
        RuntimeRefinementWitness.kernelWitnessValid, hKernel,
        runtimeKernelWitness_checkValidForEntrypoint_eq_true_iff]

@[simp] theorem runtimeWitness_checkProofGradeKernelWitness_eq_true_iff
  (witness : RuntimeRefinementWitness) :
  witness.checkProofGradeKernelWitness = true ↔
    witness.proofGradeKernelWitnessValid := by
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.checkProofGradeKernelWitness,
        RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [RuntimeRefinementWitness.checkProofGradeKernelWitness,
        RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel,
        runtimeKernelWitness_checkProofGradeForEntrypoint_eq_true_iff]

@[simp] theorem runtimeWitness_checkRuntimeKernelRefinementWitness_eq_true_iff
  (witness : RuntimeRefinementWitness) :
  witness.checkRuntimeKernelRefinementWitness = true ↔
    witness.runtimeKernelRefinementWitnessValid := by
  cases hRefinement : witness.runtimeKernelRefinementWitness with
  | none =>
      simp [RuntimeRefinementWitness.checkRuntimeKernelRefinementWitness,
        RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid, hRefinement]
  | some runtimeKernelRefinementWitness =>
      cases hKernel : witness.kernelWitness with
      | none =>
          simp [RuntimeRefinementWitness.checkRuntimeKernelRefinementWitness,
            RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid, hRefinement, hKernel]
      | some kernelWitness =>
          simp [RuntimeRefinementWitness.checkRuntimeKernelRefinementWitness,
            RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid, hRefinement, hKernel,
            runtimeKernelRefinementWitness_checkValid_eq_true_iff]

@[simp] theorem runtimeWitness_checkProofGradeRuntimeKernelRefinementWitness_eq_true_iff
  (witness : RuntimeRefinementWitness) :
  witness.checkProofGradeRuntimeKernelRefinementWitness = true ↔
    witness.proofGradeRuntimeKernelRefinementWitnessValid := by
  cases hKernel : witness.kernelWitness <;>
    cases hRefinement : witness.runtimeKernelRefinementWitness <;>
    simp [RuntimeRefinementWitness.checkProofGradeRuntimeKernelRefinementWitness,
      RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
      hKernel, hRefinement, runtimeKernelRefinementWitness_checkValid_eq_true_iff]

@[simp] theorem runtimeWitness_checkValid_eq_true_iff
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkValid modelTags = true ↔ witness.Valid modelTags := by
  simp [RuntimeRefinementWitness.checkValid, RuntimeRefinementWitness.Valid, and_assoc]

@[simp] theorem runtimeWitness_checkProofGrade_eq_true_iff
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkProofGrade modelTags = true ↔ witness.ProofGradeValid modelTags := by
  simp [RuntimeRefinementWitness.checkProofGrade,
    RuntimeRefinementWitness.ProofGradeValid, and_assoc]

theorem runtimeWitness_valid_iff_subcertificates
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.Valid modelTags ↔
    witness.trace.gasUsed = witness.publicOutcome.gasUsed ∧
      reconstructObservedOramAccessesFromLogicalTrace
          witness.trace.logicalAccesses
          witness.oramObjects =
        some witness.controllerCertificate.observedOramAccesses ∧
      witness.controllerObserverCertificate.Valid modelTags ∧
      witness.pathOramHiddenCertificate.Valid ∧
      witness.kernelWitnessValid ∧
      witness.runtimeKernelRefinementWitnessValid := by
  constructor
  · intro hValid
    rcases hValid with
      ⟨hGas, hBoundary, hShape, hAccess, hLeafScaffold, hPublicLeafScaffold,
        hLeafStateEq, hLeafStateSome, hLeafBuckets, hNormalized, hKernel, hRefinement⟩
    refine ⟨hGas, hAccess, ?_, ?_, hKernel, hRefinement⟩
    · exact ⟨hBoundary, hShape, hNormalized⟩
    · exact ⟨hLeafScaffold, hPublicLeafScaffold, hLeafStateEq, hLeafStateSome, hLeafBuckets⟩
  · intro hValid
    rcases hValid with ⟨hGas, hAccess, hController, hHidden, hKernel, hRefinement⟩
    rcases hController with ⟨hBoundary, hShape, hNormalized⟩
    rcases hHidden with
      ⟨hLeafScaffold, hPublicLeafScaffold, hLeafStateEq, hLeafStateSome, hLeafBuckets⟩
    exact
      ⟨hGas, hBoundary, hShape, hAccess, hLeafScaffold, hPublicLeafScaffold,
        hLeafStateEq, hLeafStateSome, hLeafBuckets, hNormalized, hKernel, hRefinement⟩

theorem runtimeWitness_proofGradeValid_iff_subcertificates
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.ProofGradeValid modelTags ↔
    witness.trace.gasUsed = witness.publicOutcome.gasUsed ∧
      reconstructObservedOramAccessesFromLogicalTrace
          witness.trace.logicalAccesses
          witness.oramObjects =
        some witness.controllerCertificate.observedOramAccesses ∧
      witness.controllerObserverCertificate.Valid modelTags ∧
      witness.pathOramHiddenCertificate.Valid ∧
      witness.proofGradeKernelWitnessValid ∧
      witness.proofGradeRuntimeKernelRefinementWitnessValid := by
  unfold RuntimeRefinementWitness.ProofGradeValid
  rw [runtimeWitness_valid_iff_subcertificates]
  constructor
  · intro hValid
    exact
      ⟨hValid.1.1, hValid.1.2.1, hValid.1.2.2.1, hValid.1.2.2.2.1,
        hValid.2.1, hValid.2.2⟩
  · intro hValid
    have hKernelValid : witness.kernelWitnessValid := by
      cases hKernel : witness.kernelWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hValid
      | some kernelWitness =>
          have hProofGrade :
              kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
            simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hValid.2.2.2.2.1
          simpa [RuntimeRefinementWitness.kernelWitnessValid, hKernel] using hProofGrade.1
    have hRefinementValid : witness.runtimeKernelRefinementWitnessValid := by
      cases hKernel : witness.kernelWitness with
      | none =>
          cases hRefinement : witness.runtimeKernelRefinementWitness with
          | none =>
              simp [RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid,
                hRefinement]
          | some runtimeKernelRefinementWitness =>
              simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
                hKernel, hRefinement] at hValid
      | some kernelWitness =>
          cases hRefinement : witness.runtimeKernelRefinementWitness with
          | none =>
              simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
                hKernel, hRefinement] at hValid
          | some runtimeKernelRefinementWitness =>
              simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
                hKernel, hRefinement] at hValid
              simp [RuntimeRefinementWitness.runtimeKernelRefinementWitnessValid,
                hKernel, hRefinement]
              exact hValid.2.2.2.2.2
    exact
      ⟨⟨hValid.1, hValid.2.1, hValid.2.2.1, hValid.2.2.2.1, hKernelValid, hRefinementValid⟩,
        hValid.2.2.2.2.1, hValid.2.2.2.2.2⟩

theorem runtimeWitness_controllerObserverCertificate_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.controllerObserverCertificate.Valid modelTags := by
  exact (runtimeWitness_valid_iff_subcertificates witness modelTags).mp hValid |>.2.2.1

theorem runtimeWitness_pathOramHiddenCertificate_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.pathOramHiddenCertificate.Valid := by
  exact (runtimeWitness_valid_iff_subcertificates witness modelTags).mp hValid |>.2.2.2.1

theorem runtimeWitness_kernelWitness_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.kernelWitnessValid := by
  exact (runtimeWitness_valid_iff_subcertificates witness modelTags).mp hValid |>.2.2.2.2.1

theorem runtimeWitness_runtimeKernelRefinementWitness_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.runtimeKernelRefinementWitnessValid := by
  exact (runtimeWitness_valid_iff_subcertificates witness modelTags).mp hValid |>.2.2.2.2.2

theorem runtimeWitness_proofGradeKernelWitness_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  witness.proofGradeKernelWitnessValid := by
  exact
    (runtimeWitness_proofGradeValid_iff_subcertificates witness modelTags).mp hValid |>.2.2.2.2.1

theorem runtimeWitness_proofGradeRuntimeKernelRefinementWitness_valid
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  witness.proofGradeRuntimeKernelRefinementWitnessValid := by
  exact
    (runtimeWitness_proofGradeValid_iff_subcertificates witness modelTags).mp hValid |>.2.2.2.2.2

theorem runtimeWitness_proofGradeKernelSchedule_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSteps,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSteps = some expectedKernelSteps ∧
      kernelWitness.kernelSteps = expectedKernelSteps := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      rcases runtimeKernelWitness_proofGradeKernelSchedule_exact hProofGrade with
        ⟨expectedKernelSteps, hExpectedSteps, hKernelSteps⟩
      exact ⟨kernelWitness, expectedKernelSteps, rfl, hExpectedSteps, hKernelSteps⟩

theorem runtimeWitness_proofGradePublicObjectUniverse_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedPublicObjectIds,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedPublicObjectIds = some expectedPublicObjectIds ∧
      kernelWitness.publicObjectIds = expectedPublicObjectIds := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      rcases runtimeKernelWitness_proofGradePublicObjectUniverse_exact hProofGrade with
        ⟨expectedPublicObjectIds, hExpectedPublicObjectIds, hPublicObjectIds⟩
      exact
        ⟨kernelWitness, expectedPublicObjectIds, rfl, hExpectedPublicObjectIds,
          hPublicObjectIds⟩

theorem runtimeWitness_proofGradeKernelResourceState_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.replayedResourceState? = some kernelWitness.claimedResourceState := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      exact ⟨kernelWitness, rfl, runtimeKernelWitness_proofGradeResourceState_exact hProofGrade⟩

theorem runtimeWitness_proofGradeRuntimeKernelRefinementProjection_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernelWitness = some kernelWitness ∧
      witness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.projectedKernelSchedule =
        kernelWitness.emittedKernelSchedule := by
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid :=
    runtimeWitness_proofGradeRuntimeKernelRefinementWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
  | some kernelWitness =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
              simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
                hKernel, hRefinement, RuntimeKernelRefinementWitness.Valid] at hRefinementValid
              exact ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
                hRefinementValid.2.2.1⟩

theorem runtimeWitness_proofGradeRuntimeKernelRefinementBoundaryExact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernelWitness = some kernelWitness ∧
      witness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.preCommittedColdObjectSchedule =
        kernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.postCommittedColdObjectSchedule =
        kernelWitness.publicObjectIds := by
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid :=
    runtimeWitness_proofGradeRuntimeKernelRefinementWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
  | some kernelWitness =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement, RuntimeKernelRefinementWitness.Valid] at hRefinementValid
          exact
            ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
              hRefinementValid.2.2.2.1, hRefinementValid.2.2.2.2.1⟩

theorem runtimeWitness_proofGradeKernelStateRefinement
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernelWitness = some kernelWitness ∧
      witness.runtimeKernelRefinementWitness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.RefinesLeanKernelState kernelWitness := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid :=
    runtimeWitness_proofGradeRuntimeKernelRefinementWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
      | some runtimeKernelRefinementWitness =>
          simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      cases hRefinement : witness.runtimeKernelRefinementWitness with
      | none =>
          simp [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          have hProofGrade :
              kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
            simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
          have hProofGradeSelf :
              kernelWitness.ProofGradeValid kernelWitness.entrypointId :=
            runtimeKernelWitness_proofGradeValid_self hProofGrade
          have hWitnessValid : runtimeKernelRefinementWitness.Valid kernelWitness := by
            simpa [RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
              hKernel, hRefinement] using hRefinementValid
          exact
            ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
              runtimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
                hProofGradeSelf hWitnessValid⟩

theorem runtimeWitness_proofGradeKernelScheduleObject_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      rcases runtimeKernelWitness_proofGradeKernelScheduleObject_exact hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hKernelSchedule⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hKernelSchedule⟩

theorem runtimeWitness_proofGradeKernelScheduleObject_completes
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_completes hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hFinished⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hFinished⟩

theorem runtimeWitness_proofGradeKernelScheduleObject_publicObjects_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? = some finalState ∧
      finalState.publicObjectSchedule = expectedKernelSchedule.publicObjectSchedule := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_publicObjects_exact hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hObjects⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hObjects⟩

theorem runtimeWitness_proofGradeKernelScheduleObject_finalState_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    witness.kernelWitness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  have hKernelValid : witness.proofGradeKernelWitnessValid :=
    runtimeWitness_proofGradeKernelWitness_valid witness modelTags hValid
  cases hKernel : witness.kernelWitness with
  | none =>
      simp [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.publicOutcome.entrypointId := by
        simpa [RuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using hKernelValid
      rcases runtimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hFinalExact⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hFinalExact⟩

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
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, hNormalized, _hKernel⟩
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
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized, _hKernel⟩
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
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized, _hKernel⟩
  exact hLeafScaffold

theorem runtimeWitness_object_isPathOram_of_matchPublicConfig
  (witness : RuntimeRefinementWitness)
  {cfg : OramConfig}
  (hMatch : witness.ObjectsMatchPublicConfig cfg)
  (hCfg : PathOramAnyConfigWellFormed cfg)
  {object : RuntimeOramObjectCertificate}
  (hMem : object ∈ witness.oramObjects) :
  object.isPathOram = true := by
  exact runtimeOramObject_isPathOram_of_matchPublicConfig hMatch hCfg hMem

theorem runtimeWitness_objectByName_isPathOram_of_matchPublicConfig
  (witness : RuntimeRefinementWitness)
  {cfg : OramConfig}
  (hMatch : witness.ObjectsMatchPublicConfig cfg)
  (hCfg : PathOramAnyConfigWellFormed cfg)
  {objectName : String}
  {object : RuntimeOramObjectCertificate}
  (hLookup : runtimeOramObjectByName? witness.oramObjects objectName = some object) :
  object.isPathOram = true := by
  exact runtimeOramObjectByName?_isPathOram_of_matchPublicConfig hMatch hCfg hLookup

theorem runtimeWitness_publicPathOramLeafScaffold_matches_hidden
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.oramLeafPublicScaffold = witness.pathOramLeafScaffold := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, hPublicLeafScaffold,
      _hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized, _hKernel⟩
  exact hPublicLeafScaffold

theorem runtimeWitness_pathOramLeafStateReplay_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.replayedPathOramPositionMapState =
    witness.expectedPathOramPositionMapState := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      hLeafStateEq, _hLeafStateSome, _hLeafBuckets, _hNormalized, _hKernel⟩
  exact hLeafStateEq

theorem runtimeWitness_pathOramLeafStateReplay_some
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.replayedPathOramPositionMapState.isSome = true := by
  rcases hValid with
    ⟨_hGas, _hBoundary, _hShape, _hAccesses, _hLeafScaffold, _hPublicLeafScaffold,
      _hLeafStateEq, hLeafStateSome, _hLeafBuckets, _hNormalized, _hKernel⟩
  exact hLeafStateSome

theorem runtimeWitness_pathOramFreshCoinValues_of_blocks
  (witness : RuntimeRefinementWitness)
  {coinBlocks : List (List Nat)}
  (hBlocks : witness.pathOramFreshCoinBlocks? = some coinBlocks) :
  witness.pathOramFreshCoinValues? = some (concatLists coinBlocks) := by
  exact extractRuntimePathOramFreshCoinValuesAux_of_blocks (by
    simpa [RuntimeRefinementWitness.pathOramFreshCoinBlocks?] using hBlocks)

theorem runtimeWitness_replayedPathOramLeafScheduleFromFreshCoinBlocks_exact
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  ∃ finalState,
    witness.expectedPathOramPositionMapState = some finalState ∧
    witness.replayedPathOramLeafScheduleFromFreshCoinBlocks =
      some (witness.oramLeafSchedule, finalState) := by
  have hReplayEq :=
    runtimeWitness_pathOramLeafStateReplay_exact witness modelTags hValid
  have hReplaySome :=
    runtimeWitness_pathOramLeafStateReplay_some witness modelTags hValid
  cases hExpected : witness.expectedPathOramPositionMapState with
  | none =>
      have hReplayNone : witness.replayedPathOramPositionMapState = none := by
        simpa [hExpected] using hReplayEq
      have hFalse : False := by
        simp [hReplayNone] at hReplaySome
      exact False.elim hFalse
  | some finalState =>
      refine ⟨finalState, rfl, ?_⟩
      have hExplicitReplay :
          replayRuntimePathOramTransitions
            witness.oramPositionMapBefore
            witness.oramObjects
            witness.oramLeafSchedule
            witness.oramLeafStateTransitions =
            some finalState := by
        simpa
          [ RuntimeRefinementWitness.replayedPathOramPositionMapState
          , hExpected
          ] using hReplayEq
      rcases replayRuntimePathOramLeafScheduleFromCoinBlocks_of_explicit hExplicitReplay with
        ⟨coinBlocks, hCoinBlocks, hReplayBlocks⟩
      simp
        [ RuntimeRefinementWitness.replayedPathOramLeafScheduleFromFreshCoinBlocks
        , RuntimeRefinementWitness.pathOramFreshCoinBlocks?
        , hCoinBlocks
        ]
      simpa [RuntimeRefinementWitness.pathOramTransitionShapes] using hReplayBlocks

theorem runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  witness.projectedPublicPathOramLeafScaffold =
    witness.projectedPathOramLeafScaffold := by
  rw [RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold,
    RuntimeRefinementWitness.projectedPathOramLeafScaffold,
    runtimeWitness_publicPathOramLeafScaffold_matches_hidden witness modelTags hValid]

theorem runtimeWitness_publicPathOramLeafScaffold_of_matchPublicConfig
  (witness : RuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  {cfg : OramConfig}
  (hValid : witness.Valid modelTags)
  (hMatch : witness.ObjectsMatchPublicConfig cfg)
  (hCfg : PathOramAnyConfigWellFormed cfg) :
  pathOramLeafScheduleScaffoldOfPublicPart
      (pathOramViewPublicPart (viewMPlus witness.trace))
      (pathOramProjectedExecutionLeakage cfg) =
    some witness.projectedPublicPathOramLeafScaffold := by
  have hRecon :=
    runtimeWitness_pathOramLeafScaffold_exact witness modelTags hValid
  have hNormalize :=
    projectedPathOramLeafScheduleScaffoldOfLogicalAccesses_normalize_of_reconstruct
      (leakage := pathOramProjectedExecutionLeakage cfg)
      hRecon
  have hRuntime :
      runtimePathOramLeafScheduleScaffoldOfLogicalAccesses
          witness.trace.logicalAccesses
          witness.oramObjects =
        some witness.projectedPathOramLeafScaffold := by
    exact reconstructPathOramLeafScaffoldFromLogicalTrace_runtime hRecon
  have hProjected :
      projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
          witness.trace.logicalAccesses
          (pathOramProjectedExecutionLeakage cfg) =
        some witness.projectedPathOramLeafScaffold := by
    have hEq :=
      runtimePathOramLeafScheduleScaffold_eq_projected_of_matchPublicConfig
        (logicalAccesses := witness.trace.logicalAccesses)
        (oramObjects := witness.oramObjects)
        (cfg := cfg)
        hMatch
        hCfg
    rw [← hEq]
    exact hRuntime
  calc
    pathOramLeafScheduleScaffoldOfPublicPart
        (pathOramViewPublicPart (viewMPlus witness.trace))
        (pathOramProjectedExecutionLeakage cfg) =
      projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
        (pathOramNormalizeLogicalAccesses witness.trace.logicalAccesses)
        (pathOramProjectedExecutionLeakage cfg) := by
          simpa
            [ pathOramLeafScheduleScaffoldOfPublicPart
            , pathOramViewPublicPart
            , pathOramNormalizePublicPart
            ] using
            (projectedPathOramLeafScheduleScaffoldOfLogicalAccesses_eq
              (pathOramNormalizeLogicalAccesses witness.trace.logicalAccesses)
              (pathOramProjectedExecutionLeakage cfg)).symm
    _ =
      projectedPathOramLeafScheduleScaffoldOfLogicalAccesses
        witness.trace.logicalAccesses
        (pathOramProjectedExecutionLeakage cfg) := hNormalize
    _ = some witness.projectedPathOramLeafScaffold := hProjected
    _ = some witness.projectedPublicPathOramLeafScaffold := by
          simp [runtimeWitness_projectedPublicPathOramLeafScaffold_matches_hidden
            witness modelTags hValid]

@[simp] theorem runtimeWitness_projectedPathOramLeafScaffold_exact
  (witness : RuntimeRefinementWitness) :
  pathOramLeafScheduleScaffold witness.pathOramLeafScheduleTrace =
    witness.projectedPathOramLeafScaffold := by
  cases witness with
  | mk trace runtimeSeed publicOutcome kernelWitness runtimeKernelRefinementWitness
      boundarySchedule controllerShape normalizedMicroTrace controllerCertificate
      oramObjects oramLeafPublicScaffold oramLeafSchedule
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
      _hLeafStateEq, _hLeafStateSome, hLeafBuckets, _hNormalized, _hKernel⟩
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
