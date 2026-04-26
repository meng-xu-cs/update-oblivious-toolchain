import UOToolchain.RuntimeOramCodecSemantics
import UOToolchain.RuntimeOramWriteLogDiscipline

namespace UOToolchain

namespace RuntimeOramHelperSemantics

structure Parameters where
  stashBound : Nat
  bucketsPerAccess : Nat
  blocksPerBucket : Nat
deriving Repr, DecidableEq

structure MaskedUsizeOption where
  present : Bool
  value : Nat
deriving Repr, DecidableEq

def noneOption : MaskedUsizeOption :=
  { present := false, value := 0 }

def presentOption (value : Nat) : MaskedUsizeOption :=
  { present := true, value }

def unwrapOr (slot : MaskedUsizeOption) (default : Nat) : Nat :=
  if slot.present then slot.value else default

def maskedSelectNat (cond : Bool) (whenTrue whenFalse : Nat) : Nat :=
  if cond then whenTrue else whenFalse

def maskedSelectBool (cond whenTrue whenFalse : Bool) : Bool :=
  if cond then whenTrue else whenFalse

def maskedSelectOption
    (cond : Bool)
    (whenTrue whenFalse : MaskedUsizeOption) : MaskedUsizeOption :=
  { present := maskedSelectBool cond whenTrue.present whenFalse.present
  , value := maskedSelectNat cond whenTrue.value whenFalse.value
  }

inductive PathTransitionKind where
  | readMiss
  | readHit
  | writeNoop
  | writeInsert
  | writeUpdate
  | writeDelete
deriving Repr, DecidableEq

def transitionKindCode : PathTransitionKind → Nat
  | .readMiss => 0
  | .readHit => 1
  | .writeNoop => 2
  | .writeInsert => 3
  | .writeUpdate => 4
  | .writeDelete => 5

def transitionKindOfCode : Nat → PathTransitionKind
  | 0 => .readMiss
  | 1 => .readHit
  | 2 => .writeNoop
  | 3 => .writeInsert
  | 4 => .writeUpdate
  | _ => .writeDelete

def maskedSelectTransitionKind
    (cond : Bool)
    (whenTrue whenFalse : PathTransitionKind) :
    PathTransitionKind :=
  transitionKindOfCode
    (maskedSelectNat cond
      (transitionKindCode whenTrue)
      (transitionKindCode whenFalse))

def pathPutTransitionKind
    (insertNew updateExisting deleteExisting : Bool) :
    PathTransitionKind :=
  maskedSelectTransitionKind deleteExisting .writeDelete
    (maskedSelectTransitionKind updateExisting .writeUpdate
      (maskedSelectTransitionKind insertNew .writeInsert .writeNoop))

def pathGetTransitionKind (slotPresent : Bool) : PathTransitionKind :=
  maskedSelectTransitionKind slotPresent .readHit .readMiss

def pathGetTransitionNextLeaf
    (slotPresent : Bool)
    (freshLeaf : Nat) : MaskedUsizeOption :=
  maskedSelectOption slotPresent (presentOption freshLeaf) noneOption

def pathTransitionFreshLeaf
    (accessLeaf : Nat)
    (nextLeaf : MaskedUsizeOption) : Nat :=
  unwrapOr nextLeaf accessLeaf

def pathPutTransitionSlot
    (insertNew : Bool)
    (slot insertSlot : MaskedUsizeOption) : MaskedUsizeOption :=
  maskedSelectOption insertNew insertSlot slot

def pathPutTransitionNextLeaf
    (apply updateExisting insertNew : Bool)
    (slot priorLeaf nextLeaf : MaskedUsizeOption) :
    MaskedUsizeOption :=
  let retainedPriorLeaf :=
    maskedSelectOption (!apply && slot.present) priorLeaf noneOption
  maskedSelectOption (updateExisting || insertNew) nextLeaf retainedPriorLeaf

def workingStashCapacity (parameters : Parameters) : Nat :=
  parameters.stashBound +
    parameters.bucketsPerAccess * parameters.blocksPerBucket

def firstTrueIndexFrom : Nat → List Bool → Option Nat
  | _offset, [] => none
  | offset, flag :: flags =>
      if flag then some offset else firstTrueIndexFrom (offset + 1) flags

def firstTrueIndex? (flags : List Bool) : Option Nat :=
  firstTrueIndexFrom 0 flags

def lookupAt? : List α → Nat → Option α
  | [], _index => none
  | value :: _tail, 0 => some value
  | _value :: tail, index + 1 => lookupAt? tail index

def slotForKey? (keyMatches : List Bool) : Option Nat :=
  firstTrueIndex? keyMatches

def allocateSlot? (occupied : List Bool) : Option Nat :=
  firstTrueIndex? (occupied.map fun flag => !flag)

structure StashBlock where
  occupied : Bool
  slotIndex : Nat
  leaf : Nat
deriving Repr, DecidableEq

def emptyBlock : StashBlock :=
  { occupied := false, slotIndex := 0, leaf := 0 }

def wipeBlock (_block : StashBlock) : StashBlock :=
  emptyBlock

def clearFixedStash (blocks : List StashBlock) : List StashBlock :=
  List.replicate blocks.length emptyBlock

def firstVacantIndex (blocks : List StashBlock) : Option Nat :=
  firstTrueIndex? (blocks.map fun block => !block.occupied)

def replaceAt : List α → Nat → α → List α
  | [], _index, _value => []
  | _head :: tail, 0, value => value :: tail
  | head :: tail, index + 1, value => head :: replaceAt tail index value

def livePathBlockValidationFailed
    (capacity leafCount : Nat)
    (positionMap liveSlots : List MaskedUsizeOption)
    (block : StashBlock) : Bool :=
  if block.occupied then
    (decide (capacity ≤ block.slotIndex)) ||
      (decide (leafCount ≤ block.leaf)) ||
      match
          lookupAt? positionMap block.slotIndex,
          lookupAt? liveSlots block.slotIndex with
      | some expectedLeaf, some liveSlot =>
          (!expectedLeaf.present) ||
            (!(expectedLeaf.value == block.leaf)) ||
            liveSlot.present
      | _, _ => true
  else
    false

def liveSlotsAfterBlockValidation
    (capacity leafCount : Nat)
    (positionMap liveSlots : List MaskedUsizeOption)
    (block : StashBlock) : List MaskedUsizeOption :=
  if livePathBlockValidationFailed capacity leafCount
      positionMap liveSlots block then
    liveSlots
  else if block.occupied then
    replaceAt liveSlots block.slotIndex (presentOption block.leaf)
  else
    liveSlots

def liveSlotCoverageFailed :
    List MaskedUsizeOption → List MaskedUsizeOption → Bool
  | [], _liveSlots => false
  | _leaf :: _positionMap, [] => true
  | leaf :: positionMap, liveSlot :: liveSlots =>
      (leaf.present && !liveSlot.present) ||
        liveSlotCoverageFailed positionMap liveSlots

structure PathEntryCell where
  occupied : Bool
  slotIndex : Nat
  leaf : Nat
deriving Repr, DecidableEq

def emptyPathEntryCell : PathEntryCell :=
  { occupied := false, slotIndex := 0, leaf := 0 }

def pathEntryCellFromBlock (block : StashBlock) : PathEntryCell :=
  { occupied := true, slotIndex := block.slotIndex, leaf := block.leaf }

def resetPathEntryCells (capacity : Nat) : List PathEntryCell :=
  List.replicate capacity emptyPathEntryCell

def installPathEntryFailed
    (entries : List PathEntryCell)
    (block : StashBlock) : Bool :=
  block.occupied && decide (entries.length ≤ block.slotIndex)

def installPathEntryFromBlock
    (entries : List PathEntryCell)
    (block : StashBlock) : List PathEntryCell :=
  if installPathEntryFailed entries block then
    entries
  else if block.occupied then
    replaceAt entries block.slotIndex (pathEntryCellFromBlock block)
  else
    entries

structure ReconstructionState where
  liveSlots : List MaskedUsizeOption
  entries : List PathEntryCell
  failed : Bool
deriving Repr, DecidableEq

def reconstructPathBlockStep
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState)
    (block : StashBlock) : ReconstructionState :=
  if state.failed then
    state
  else if livePathBlockValidationFailed
      capacity leafCount positionMap state.liveSlots block then
    { state with failed := true }
  else if installPathEntryFailed state.entries block then
    { state with failed := true }
  else
    { liveSlots :=
        liveSlotsAfterBlockValidation
          capacity leafCount positionMap state.liveSlots block
    , entries := installPathEntryFromBlock state.entries block
    , failed := false
    }

def reconstructPathFinishFailed
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState) : Bool :=
  state.failed || liveSlotCoverageFailed positionMap state.liveSlots

def reconstructPathBlocks
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    ReconstructionState → List StashBlock → ReconstructionState
  | state, [] => state
  | state, block :: blocks =>
      reconstructPathBlocks capacity leafCount positionMap
        (reconstructPathBlockStep
          capacity leafCount positionMap state block)
        blocks

def initialReconstructionState (capacity : Nat) : ReconstructionState :=
  { liveSlots := List.replicate capacity noneOption
  , entries := resetPathEntryCells capacity
  , failed := false
  }

def reconstructPathDecodedBlocksState
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock) : ReconstructionState :=
  let afterStash :=
    reconstructPathBlocks capacity leafCount positionMap
      (initialReconstructionState capacity)
      stashBlocks
  reconstructPathBlocks capacity leafCount positionMap afterStash bucketBlocks

def reconstructPathDecodedBlocksFailed
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock) : Bool :=
  reconstructPathFinishFailed positionMap
    (reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks bucketBlocks)

structure BucketBlock where
  bucketIndex : Nat
  block : StashBlock
deriving Repr, DecidableEq

def bucketBlockAdmissionFailed
    (leafCount : Nat)
    (bucketBlock : BucketBlock) : Bool :=
  bucketBlock.block.occupied &&
    !RuntimeOramCodecSemantics.bucketOnLeafPath
      leafCount bucketBlock.bucketIndex bucketBlock.block.leaf

def reconstructPathBucketBlockStep
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState)
    (bucketBlock : BucketBlock) : ReconstructionState :=
  if state.failed then
    state
  else if bucketBlockAdmissionFailed leafCount bucketBlock then
    { state with failed := true }
  else
    reconstructPathBlockStep
      capacity leafCount positionMap state bucketBlock.block

def reconstructPathBucketBlocks
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    ReconstructionState → List BucketBlock → ReconstructionState
  | state, [] => state
  | state, bucketBlock :: bucketBlocks =>
      reconstructPathBucketBlocks capacity leafCount positionMap
        (reconstructPathBucketBlockStep
          capacity leafCount positionMap state bucketBlock)
        bucketBlocks

def reconstructPathDecodedBucketsState
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock) : ReconstructionState :=
  let afterStash :=
    reconstructPathBlocks capacity leafCount positionMap
      (initialReconstructionState capacity)
      stashBlocks
  reconstructPathBucketBlocks
    capacity leafCount positionMap afterStash bucketBlocks

def reconstructPathDecodedBucketsFailed
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock) : Bool :=
  reconstructPathFinishFailed positionMap
    (reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks bucketBlocks)

structure PushResult where
  blocks : List StashBlock
  overflowed : Bool
deriving Repr, DecidableEq

def pushFixedStash
    (blocks : List StashBlock)
    (overflowed : Bool)
    (block : StashBlock) : PushResult :=
  if block.occupied then
    match firstVacantIndex blocks with
    | some index =>
        { blocks := replaceAt blocks index block
        , overflowed
        }
    | none =>
        { blocks
        , overflowed := true
        }
  else
    { blocks
    , overflowed
    }

structure TakeResult where
  removed : StashBlock
  blocks : List StashBlock
deriving Repr, DecidableEq

def takeSelectedBlock
    (blocks : List StashBlock)
    (selectedIndex : Nat)
    (present : Bool) : Option TakeResult :=
  if present then
    match lookupAt? blocks selectedIndex with
    | some block =>
        some
          { removed := block
          , blocks := replaceAt blocks selectedIndex emptyBlock
          }
    | none => none
  else
    some
      { removed := emptyBlock
      , blocks
      }

def selectPositionMapLeaf
    (positionMap : List MaskedUsizeOption)
    (slot : MaskedUsizeOption) : MaskedUsizeOption :=
  if slot.present then
    match lookupAt? positionMap slot.value with
    | some leaf => leaf
    | none => noneOption
  else
    noneOption

def selectValueAt
    (values : List α)
    (slot : MaskedUsizeOption)
    (default : α) : α :=
  if slot.present then
    match lookupAt? values slot.value with
    | some value => value
    | none => default
  else
    default

def accessLeafForSlot
    (positionMap : List MaskedUsizeOption)
    (slot : MaskedUsizeOption)
    (freshLeaf : Nat) : Nat :=
  unwrapOr (selectPositionMapLeaf positionMap slot) freshLeaf

def updatePositionMapLeafAt :
    Nat → List MaskedUsizeOption → MaskedUsizeOption →
      MaskedUsizeOption → List MaskedUsizeOption
  | _offset, [], _slot, _nextLeaf => []
  | offset, leaf :: leaves, slot, nextLeaf =>
      let updateHere :=
        slot.present && nextLeaf.present && (offset == slot.value)
      maskedSelectOption updateHere nextLeaf leaf ::
        updatePositionMapLeafAt (offset + 1) leaves slot nextLeaf

def updatePositionMapLeaf
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption) :
    List MaskedUsizeOption :=
  updatePositionMapLeafAt 0 positionMap slot nextLeaf

def updateStashLeafForSlot :
    List StashBlock → MaskedUsizeOption → MaskedUsizeOption →
      List StashBlock
  | [], _slot, _nextLeaf => []
  | block :: blocks, slot, nextLeaf =>
      let updateHere :=
        slot.present && nextLeaf.present && block.occupied &&
          (block.slotIndex == slot.value)
      { block with leaf := maskedSelectNat updateHere nextLeaf.value block.leaf } ::
        updateStashLeafForSlot blocks slot nextLeaf

def stashContainsSlot (blocks : List StashBlock) (slot : Nat) : Bool :=
  (firstTrueIndex? (blocks.map fun block =>
    block.occupied && (block.slotIndex == slot))).isSome

def stashHasVacant (blocks : List StashBlock) : Bool :=
  (firstVacantIndex blocks).isSome

def pathPutUpdateExisting
    (apply valueIsZero : Bool)
    (slot : MaskedUsizeOption) : Bool :=
  apply && slot.present && !valueIsZero

def pathPutDeleteExisting
    (apply valueIsZero : Bool)
    (slot : MaskedUsizeOption) : Bool :=
  apply && slot.present && valueIsZero

def pathPutInsertNew
    (apply valueIsZero : Bool)
    (slot insertSlot : MaskedUsizeOption) : Bool :=
  apply && !slot.present && !valueIsZero && insertSlot.present

def pathPutUpdateFailed
    (entryCapacity : Nat)
    (blocks : List StashBlock)
    (apply valueIsZero : Bool)
    (slot insertSlot : MaskedUsizeOption) : Bool :=
  let updateExisting := pathPutUpdateExisting apply valueIsZero slot
  let deleteExisting := pathPutDeleteExisting apply valueIsZero slot
  let insertNew := pathPutInsertNew apply valueIsZero slot insertSlot
  let matchedSlot :=
    if slot.present then stashContainsSlot blocks slot.value else false
  let insertedSlot := stashHasVacant blocks
  ((updateExisting || deleteExisting) && !matchedSlot) ||
    (insertNew && !insertedSlot) ||
    (insertNew && decide (entryCapacity ≤ insertSlot.value))

structure PathTransitionFields where
  kind : PathTransitionKind
  freshLeaf : Nat
  slotIndex : MaskedUsizeOption
  priorLeaf : MaskedUsizeOption
  nextLeaf : MaskedUsizeOption
deriving Repr, DecidableEq

def pathGetTransitionFields
    (positionMap : List MaskedUsizeOption)
    (slot : MaskedUsizeOption)
    (accessLeaf freshLeaf : Nat) :
    PathTransitionFields :=
  let priorLeaf := selectPositionMapLeaf positionMap slot
  let nextLeaf := pathGetTransitionNextLeaf slot.present freshLeaf
  { kind := pathGetTransitionKind slot.present
  , freshLeaf := pathTransitionFreshLeaf accessLeaf nextLeaf
  , slotIndex := slot
  , priorLeaf
  , nextLeaf
  }

def pathPutTransitionFields
    (apply valueIsZero : Bool)
    (slot insertSlot priorLeaf : MaskedUsizeOption)
    (accessLeaf nextLeafValue : Nat) :
    PathTransitionFields :=
  let updateExisting := pathPutUpdateExisting apply valueIsZero slot
  let deleteExisting := pathPutDeleteExisting apply valueIsZero slot
  let insertNew := pathPutInsertNew apply valueIsZero slot insertSlot
  let selectedNextLeaf :=
    maskedSelectOption (updateExisting || insertNew)
      (presentOption nextLeafValue)
      noneOption
  let transitionNextLeaf :=
    pathPutTransitionNextLeaf
      apply updateExisting insertNew slot priorLeaf selectedNextLeaf
  { kind := pathPutTransitionKind insertNew updateExisting deleteExisting
  , freshLeaf := pathTransitionFreshLeaf accessLeaf transitionNextLeaf
  , slotIndex := pathPutTransitionSlot insertNew slot insertSlot
  , priorLeaf
  , nextLeaf := transitionNextLeaf
  }

def blockOnBucketPath
    (leafCount bucketIndex : Nat)
    (block : StashBlock) : Bool :=
  block.occupied &&
    RuntimeOramCodecSemantics.bucketOnLeafPath
      leafCount bucketIndex block.leaf

def selectPathBlockIndex
    (leafCount bucketIndex : Nat)
    (blocks : List StashBlock) : Option Nat :=
  firstTrueIndex? (blocks.map fun block =>
    blockOnBucketPath leafCount bucketIndex block)

def takeSelectedBlockOrEmpty
    (blocks : List StashBlock)
    (selectedIndex : Nat)
    (present : Bool) : TakeResult :=
  match takeSelectedBlock blocks selectedIndex present with
  | some result => result
  | none => { removed := emptyBlock, blocks }

structure BuildPathBucketResult where
  bucket : List StashBlock
  stash : List StashBlock
  liveCount : Nat
deriving Repr, DecidableEq

def buildPathBucket :
    Nat → Nat → Nat → List StashBlock → BuildPathBucketResult
  | 0, _leafCount, _bucketIndex, blocks =>
      { bucket := [], stash := blocks, liveCount := 0 }
  | blocksPerBucket + 1, leafCount, bucketIndex, blocks =>
      let selected := selectPathBlockIndex leafCount bucketIndex blocks
      let present := selected.isSome
      let taken := takeSelectedBlockOrEmpty blocks (selected.getD 0) present
      let rest :=
        buildPathBucket blocksPerBucket leafCount bucketIndex taken.blocks
      { bucket := taken.removed :: rest.bucket
      , stash := rest.stash
      , liveCount := (if present then 1 else 0) + rest.liveCount
      }

structure RewriteParameters where
  stashBound : Nat
  bucketsPerAccess : Nat
  metadataPages : Nat
deriving Repr, DecidableEq

structure RewritePathSummary where
  nextCounter : Nat
  physicalWriteCount : Nat
  updateFailed : Bool
deriving Repr, DecidableEq

def rewriteWorkingStashBound (parameters : RewriteParameters) : Nat :=
  parameters.stashBound + parameters.bucketsPerAccess

def rewritePathWriteCount (parameters : RewriteParameters) : Nat :=
  parameters.metadataPages + parameters.bucketsPerAccess + 1

def pathAccessReadCount (parameters : RewriteParameters) : Nat :=
  1 + parameters.metadataPages + parameters.bucketsPerAccess

def rewriteWriteLogParameters
    (parameters : RewriteParameters) :
    RuntimeOramWriteLogDiscipline.Parameters :=
  { metadataPages := parameters.metadataPages
  , bucketsPerAccess := parameters.bucketsPerAccess
  }

def rewritePathUpdateFailed
    (parameters : RewriteParameters)
    (loadOverflowed effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat) : Bool :=
  loadOverflowed ||
    effectFailed ||
    decide (rewriteWorkingStashBound parameters < postUpdateStashLen) ||
    decide (parameters.stashBound < postRebuildStashLen)

def rewritePathSummary
    (parameters : RewriteParameters)
    (currentCounter : Nat)
    (loadOverflowed effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat) :
    RewritePathSummary :=
  { nextCounter := currentCounter + 1
  , physicalWriteCount := rewritePathWriteCount parameters
  , updateFailed :=
      rewritePathUpdateFailed parameters loadOverflowed effectFailed
        postUpdateStashLen postRebuildStashLen
  }

theorem noneOption_absent :
    noneOption.present = false := by
  rfl

theorem presentOption_present (value : Nat) :
    (presentOption value).present = true := by
  rfl

theorem presentOption_value (value : Nat) :
    (presentOption value).value = value := by
  rfl

theorem unwrapOr_noneOption (default : Nat) :
    unwrapOr noneOption default = default := by
  rfl

theorem unwrapOr_presentOption (value default : Nat) :
    unwrapOr (presentOption value) default = value := by
  rfl

theorem maskedSelectNat_true (whenTrue whenFalse : Nat) :
    maskedSelectNat true whenTrue whenFalse = whenTrue := by
  rfl

theorem maskedSelectNat_false (whenTrue whenFalse : Nat) :
    maskedSelectNat false whenTrue whenFalse = whenFalse := by
  rfl

theorem maskedSelectBool_true (whenTrue whenFalse : Bool) :
    maskedSelectBool true whenTrue whenFalse = whenTrue := by
  rfl

theorem maskedSelectBool_false (whenTrue whenFalse : Bool) :
    maskedSelectBool false whenTrue whenFalse = whenFalse := by
  rfl

theorem maskedSelectOption_true
    (whenTrue whenFalse : MaskedUsizeOption) :
    maskedSelectOption true whenTrue whenFalse = whenTrue := by
  cases whenTrue
  rfl

theorem maskedSelectOption_false
    (whenTrue whenFalse : MaskedUsizeOption) :
    maskedSelectOption false whenTrue whenFalse = whenFalse := by
  cases whenFalse
  rfl

theorem transitionKindOfCode_code
    (kind : PathTransitionKind) :
    transitionKindOfCode (transitionKindCode kind) = kind := by
  cases kind <;> rfl

theorem maskedSelectTransitionKind_true
    (whenTrue whenFalse : PathTransitionKind) :
    maskedSelectTransitionKind true whenTrue whenFalse = whenTrue := by
  simp [maskedSelectTransitionKind, maskedSelectNat_true,
    transitionKindOfCode_code]

theorem maskedSelectTransitionKind_false
    (whenTrue whenFalse : PathTransitionKind) :
    maskedSelectTransitionKind false whenTrue whenFalse = whenFalse := by
  simp [maskedSelectTransitionKind, maskedSelectNat_false,
    transitionKindOfCode_code]

theorem pathPutTransitionKind_delete
    (insertNew updateExisting : Bool) :
    pathPutTransitionKind insertNew updateExisting true =
      PathTransitionKind.writeDelete := by
  rfl

theorem pathPutTransitionKind_update
    (insertNew : Bool) :
    pathPutTransitionKind insertNew true false =
      PathTransitionKind.writeUpdate := by
  simp [pathPutTransitionKind, maskedSelectTransitionKind_true,
    maskedSelectTransitionKind_false]

theorem pathPutTransitionKind_insert :
    pathPutTransitionKind true false false =
      PathTransitionKind.writeInsert := by
  rfl

theorem pathPutTransitionKind_noop :
    pathPutTransitionKind false false false =
      PathTransitionKind.writeNoop := by
  rfl

theorem pathGetTransitionKind_hit :
    pathGetTransitionKind true = PathTransitionKind.readHit := by
  rfl

theorem pathGetTransitionKind_miss :
    pathGetTransitionKind false = PathTransitionKind.readMiss := by
  rfl

theorem pathGetTransitionNextLeaf_hit (freshLeaf : Nat) :
    pathGetTransitionNextLeaf true freshLeaf = presentOption freshLeaf := by
  simp [pathGetTransitionNextLeaf, maskedSelectOption_true]

theorem pathGetTransitionNextLeaf_miss (freshLeaf : Nat) :
    pathGetTransitionNextLeaf false freshLeaf = noneOption := by
  simp [pathGetTransitionNextLeaf, maskedSelectOption_false]

theorem pathTransitionFreshLeaf_none (accessLeaf : Nat) :
    pathTransitionFreshLeaf accessLeaf noneOption = accessLeaf := by
  rfl

theorem pathTransitionFreshLeaf_present (accessLeaf leaf : Nat) :
    pathTransitionFreshLeaf accessLeaf (presentOption leaf) = leaf := by
  rfl

theorem pathPutTransitionSlot_insert
    (slot insertSlot : MaskedUsizeOption) :
    pathPutTransitionSlot true slot insertSlot = insertSlot := by
  simp [pathPutTransitionSlot, maskedSelectOption_true]

theorem pathPutTransitionSlot_existing
    (slot insertSlot : MaskedUsizeOption) :
    pathPutTransitionSlot false slot insertSlot = slot := by
  simp [pathPutTransitionSlot, maskedSelectOption_false]

theorem pathPutTransitionNextLeaf_update
    (apply insertNew : Bool)
    (slot priorLeaf nextLeaf : MaskedUsizeOption) :
    pathPutTransitionNextLeaf apply true insertNew slot priorLeaf nextLeaf =
      nextLeaf := by
  simp [pathPutTransitionNextLeaf, maskedSelectOption_true]

theorem pathPutTransitionNextLeaf_insert
    (apply : Bool)
    (slot priorLeaf nextLeaf : MaskedUsizeOption) :
    pathPutTransitionNextLeaf apply false true slot priorLeaf nextLeaf =
      nextLeaf := by
  simp [pathPutTransitionNextLeaf, maskedSelectOption_true]

theorem pathPutTransitionNextLeaf_appliedNoChange
    (slot priorLeaf nextLeaf : MaskedUsizeOption) :
    pathPutTransitionNextLeaf true false false slot priorLeaf nextLeaf =
      noneOption := by
  simp [pathPutTransitionNextLeaf, maskedSelectOption_false]

theorem pathPutTransitionNextLeaf_retainsPrior
    (slotIndex : Nat)
    (priorLeaf nextLeaf : MaskedUsizeOption) :
    pathPutTransitionNextLeaf
        false false false (presentOption slotIndex) priorLeaf nextLeaf =
      priorLeaf := by
  simp [pathPutTransitionNextLeaf, presentOption, maskedSelectOption,
    maskedSelectBool, maskedSelectNat]

theorem pathGetTransitionFields_miss
    (positionMap : List MaskedUsizeOption)
    (accessLeaf freshLeaf : Nat) :
    pathGetTransitionFields positionMap noneOption accessLeaf freshLeaf =
      { kind := PathTransitionKind.readMiss
      , freshLeaf := accessLeaf
      , slotIndex := noneOption
      , priorLeaf := noneOption
      , nextLeaf := noneOption
      } := by
  rfl

theorem pathGetTransitionFields_hit
    {positionMap : List MaskedUsizeOption}
    {slotIndex accessLeaf freshLeaf : Nat}
    {priorLeaf : MaskedUsizeOption}
    (hLookup : lookupAt? positionMap slotIndex = some priorLeaf) :
    pathGetTransitionFields
        positionMap (presentOption slotIndex) accessLeaf freshLeaf =
      { kind := PathTransitionKind.readHit
      , freshLeaf
      , slotIndex := presentOption slotIndex
      , priorLeaf
      , nextLeaf := presentOption freshLeaf
      } := by
  simp [pathGetTransitionFields, selectPositionMapLeaf,
    pathGetTransitionNextLeaf, pathGetTransitionKind, pathTransitionFreshLeaf,
    hLookup, presentOption, maskedSelectOption, maskedSelectBool,
    maskedSelectNat, maskedSelectTransitionKind, transitionKindCode,
    transitionKindOfCode, unwrapOr]

theorem pathPutTransitionFields_delete
    (slotIndex priorLeaf accessLeaf nextLeafValue : Nat)
    (insertSlot : MaskedUsizeOption) :
    pathPutTransitionFields
        true true (presentOption slotIndex) insertSlot
        (presentOption priorLeaf) accessLeaf nextLeafValue =
      { kind := PathTransitionKind.writeDelete
      , freshLeaf := accessLeaf
      , slotIndex := presentOption slotIndex
      , priorLeaf := presentOption priorLeaf
      , nextLeaf := noneOption
      } := by
  simp [pathPutTransitionFields, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew, pathPutTransitionKind,
    pathPutTransitionSlot, pathPutTransitionNextLeaf,
    pathTransitionFreshLeaf, presentOption, noneOption,
    maskedSelectOption, maskedSelectBool, maskedSelectNat,
    maskedSelectTransitionKind, transitionKindCode, transitionKindOfCode,
    unwrapOr]

theorem pathPutTransitionFields_update
    (slotIndex priorLeaf accessLeaf nextLeafValue : Nat)
    (insertSlot : MaskedUsizeOption) :
    pathPutTransitionFields
        true false (presentOption slotIndex) insertSlot
        (presentOption priorLeaf) accessLeaf nextLeafValue =
      { kind := PathTransitionKind.writeUpdate
      , freshLeaf := nextLeafValue
      , slotIndex := presentOption slotIndex
      , priorLeaf := presentOption priorLeaf
      , nextLeaf := presentOption nextLeafValue
      } := by
  simp [pathPutTransitionFields, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew, pathPutTransitionKind,
    pathPutTransitionSlot, pathPutTransitionNextLeaf,
    pathTransitionFreshLeaf, presentOption, maskedSelectOption,
    maskedSelectBool, maskedSelectNat,
    maskedSelectTransitionKind, transitionKindCode, transitionKindOfCode,
    unwrapOr]

theorem pathPutTransitionFields_insert
    (insertSlot accessLeaf nextLeafValue : Nat) :
    pathPutTransitionFields
        true false noneOption (presentOption insertSlot)
        noneOption accessLeaf nextLeafValue =
      { kind := PathTransitionKind.writeInsert
      , freshLeaf := nextLeafValue
      , slotIndex := presentOption insertSlot
      , priorLeaf := noneOption
      , nextLeaf := presentOption nextLeafValue
      } := by
  simp [pathPutTransitionFields, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew, pathPutTransitionKind,
    pathPutTransitionSlot, pathPutTransitionNextLeaf,
    pathTransitionFreshLeaf, presentOption, noneOption,
    maskedSelectOption, maskedSelectBool, maskedSelectNat,
    maskedSelectTransitionKind, transitionKindCode, transitionKindOfCode,
    unwrapOr]

theorem pathPutTransitionFields_noopAbsent
    (valueIsZero : Bool)
    (insertSlot : MaskedUsizeOption)
    (accessLeaf nextLeafValue : Nat) :
    pathPutTransitionFields
        false valueIsZero noneOption insertSlot noneOption
        accessLeaf nextLeafValue =
      { kind := PathTransitionKind.writeNoop
      , freshLeaf := accessLeaf
      , slotIndex := noneOption
      , priorLeaf := noneOption
      , nextLeaf := noneOption
      } := by
  cases valueIsZero <;>
    simp [pathPutTransitionFields, pathPutUpdateExisting,
      pathPutDeleteExisting, pathPutInsertNew, pathPutTransitionKind,
      pathPutTransitionSlot, pathPutTransitionNextLeaf,
      pathTransitionFreshLeaf, noneOption,
      maskedSelectOption, maskedSelectBool, maskedSelectNat,
      maskedSelectTransitionKind, transitionKindCode, transitionKindOfCode,
      unwrapOr]

theorem pathPutTransitionFields_noopPresentRetainsPrior
    (valueIsZero : Bool)
    (slotIndex priorLeaf accessLeaf nextLeafValue : Nat)
    (insertSlot : MaskedUsizeOption) :
    pathPutTransitionFields
        false valueIsZero (presentOption slotIndex) insertSlot
        (presentOption priorLeaf) accessLeaf nextLeafValue =
      { kind := PathTransitionKind.writeNoop
      , freshLeaf := priorLeaf
      , slotIndex := presentOption slotIndex
      , priorLeaf := presentOption priorLeaf
      , nextLeaf := presentOption priorLeaf
      } := by
  cases valueIsZero <;>
    simp [pathPutTransitionFields, pathPutUpdateExisting,
      pathPutDeleteExisting, pathPutInsertNew, pathPutTransitionKind,
      pathPutTransitionSlot, pathPutTransitionNextLeaf,
      pathTransitionFreshLeaf, presentOption, maskedSelectOption,
      maskedSelectBool, maskedSelectNat,
      maskedSelectTransitionKind, transitionKindCode, transitionKindOfCode,
      unwrapOr]

theorem workingStashCapacity_formula
    (parameters : Parameters) :
    workingStashCapacity parameters =
      parameters.stashBound +
        parameters.bucketsPerAccess * parameters.blocksPerBucket := by
  rfl

theorem firstTrueIndexFrom_some_bound
    {flags : List Bool}
    {offset index : Nat}
    (hIndex : firstTrueIndexFrom offset flags = some index) :
    offset ≤ index ∧ index < offset + flags.length := by
  induction flags generalizing offset index with
  | nil =>
      simp [firstTrueIndexFrom] at hIndex
  | cons flag flags ih =>
      cases flag
      · simp [firstTrueIndexFrom] at hIndex
        have hTail := ih hIndex
        constructor
        · exact Nat.le_trans (Nat.le_succ offset) hTail.1
        · simpa [Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using hTail.2
      · simp [firstTrueIndexFrom] at hIndex
        cases hIndex
        constructor
        · exact Nat.le_refl offset
        · exact Nat.lt_add_of_pos_right (by simp)

theorem firstTrueIndex?_some_lt_length
    {flags : List Bool}
    {index : Nat}
    (hIndex : firstTrueIndex? flags = some index) :
    index < flags.length := by
  have hBound :=
    firstTrueIndexFrom_some_bound (offset := 0) hIndex
  omega

theorem firstTrueIndex?_cons_true
    (flags : List Bool) :
    firstTrueIndex? (true :: flags) = some 0 := by
  rfl

theorem slotForKey?_some_lt_capacity
    {keyMatches : List Bool}
    {slot : Nat}
    (hSlot : slotForKey? keyMatches = some slot) :
    slot < keyMatches.length := by
  exact firstTrueIndex?_some_lt_length hSlot

theorem allocateSlot?_some_lt_capacity
    {occupied : List Bool}
    {slot : Nat}
    (hSlot : allocateSlot? occupied = some slot) :
    slot < occupied.length := by
  have hSlot' := firstTrueIndex?_some_lt_length hSlot
  simpa [allocateSlot?] using hSlot'

theorem emptyBlock_wiped :
    emptyBlock.occupied = false ∧
      emptyBlock.slotIndex = 0 ∧
      emptyBlock.leaf = 0 := by
  exact ⟨rfl, rfl, rfl⟩

theorem wipeBlock_wiped (block : StashBlock) :
    (wipeBlock block).occupied = false ∧
      (wipeBlock block).slotIndex = 0 ∧
      (wipeBlock block).leaf = 0 := by
  exact emptyBlock_wiped

theorem clearFixedStash_length (blocks : List StashBlock) :
    (clearFixedStash blocks).length = blocks.length := by
  simp [clearFixedStash]

theorem clearFixedStash_allEmpty
    {blocks : List StashBlock}
    {block : StashBlock}
    (hMem : block ∈ clearFixedStash blocks) :
    block = emptyBlock := by
  simp [clearFixedStash] at hMem
  exact hMem.2

theorem firstVacantIndex_some_lt_length
    {blocks : List StashBlock}
    {index : Nat}
    (hIndex : firstVacantIndex blocks = some index) :
    index < blocks.length := by
  have hIndex' := firstTrueIndex?_some_lt_length hIndex
  simpa [firstVacantIndex] using hIndex'

theorem replaceAt_length
    (values : List α)
    (index : Nat)
    (value : α) :
    (replaceAt values index value).length = values.length := by
  induction values generalizing index with
  | nil =>
      simp [replaceAt]
  | cons head tail ih =>
      cases index with
      | zero =>
          simp [replaceAt]
      | succ index =>
          simp [replaceAt, ih]

theorem lookupAt?_some_lt_length
    {values : List α}
    {index : Nat}
    {value : α}
    (hGet : lookupAt? values index = some value) :
    index < values.length := by
  induction values generalizing index with
  | nil =>
      cases index <;> simp [lookupAt?] at hGet
  | cons head tail ih =>
      cases index with
      | zero =>
          simp
      | succ index =>
          simp [lookupAt?] at hGet
          have hTail := ih hGet
          exact Nat.succ_lt_succ hTail

theorem lookupAt?_replaceAt_same
    (values : List α)
    (index : Nat)
    (value : α)
    (hIndex : index < values.length) :
    lookupAt? (replaceAt values index value) index = some value := by
  induction values generalizing index with
  | nil =>
      simp at hIndex
  | cons head tail ih =>
      cases index with
      | zero =>
          simp [lookupAt?, replaceAt]
      | succ index =>
          simp [lookupAt?, replaceAt]
          exact ih index (Nat.lt_of_succ_lt_succ hIndex)

theorem livePathBlockValidationFailed_unoccupied
    (capacity leafCount : Nat)
    (positionMap liveSlots : List MaskedUsizeOption)
    {block : StashBlock}
    (hOccupied : block.occupied = false) :
    livePathBlockValidationFailed
        capacity leafCount positionMap liveSlots block = false := by
  simp [livePathBlockValidationFailed, hOccupied]

theorem liveSlotsAfterBlockValidation_unoccupied
    (capacity leafCount : Nat)
    (positionMap liveSlots : List MaskedUsizeOption)
    {block : StashBlock}
    (hOccupied : block.occupied = false) :
    liveSlotsAfterBlockValidation
        capacity leafCount positionMap liveSlots block = liveSlots := by
  simp [liveSlotsAfterBlockValidation,
    livePathBlockValidationFailed_unoccupied
      capacity leafCount positionMap liveSlots hOccupied,
    hOccupied]

theorem livePathBlockValidationFailed_validOccupied
    {capacity leafCount : Nat}
    {positionMap liveSlots : List MaskedUsizeOption}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < capacity)
    (hLeaf : block.leaf < leafCount)
    (hPosition :
      lookupAt? positionMap block.slotIndex =
        some (presentOption block.leaf))
    (hLive :
      lookupAt? liveSlots block.slotIndex = some noneOption) :
    livePathBlockValidationFailed
        capacity leafCount positionMap liveSlots block = false := by
  have hSlotNot : ¬ capacity ≤ block.slotIndex := by omega
  have hLeafNot : ¬ leafCount ≤ block.leaf := by omega
  simp [livePathBlockValidationFailed, hOccupied, hSlotNot, hLeafNot,
    hPosition, hLive, presentOption, noneOption]

theorem liveSlotsAfterBlockValidation_validOccupied
    {capacity leafCount : Nat}
    {positionMap liveSlots : List MaskedUsizeOption}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < capacity)
    (hLeaf : block.leaf < leafCount)
    (hPosition :
      lookupAt? positionMap block.slotIndex =
        some (presentOption block.leaf))
    (hLive :
      lookupAt? liveSlots block.slotIndex = some noneOption) :
    liveSlotsAfterBlockValidation
        capacity leafCount positionMap liveSlots block =
      replaceAt liveSlots block.slotIndex (presentOption block.leaf) := by
  have hValid :=
    livePathBlockValidationFailed_validOccupied
      hOccupied hSlot hLeaf hPosition hLive
  simp [liveSlotsAfterBlockValidation, hValid, hOccupied]

theorem liveSlotsAfterBlockValidation_validOccupied_lookup
    {capacity leafCount : Nat}
    {positionMap liveSlots : List MaskedUsizeOption}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < capacity)
    (hLeaf : block.leaf < leafCount)
    (hPosition :
      lookupAt? positionMap block.slotIndex =
        some (presentOption block.leaf))
    (hLive :
      lookupAt? liveSlots block.slotIndex = some noneOption) :
    lookupAt?
        (liveSlotsAfterBlockValidation
          capacity leafCount positionMap liveSlots block)
        block.slotIndex =
      some (presentOption block.leaf) := by
  rw [liveSlotsAfterBlockValidation_validOccupied
    hOccupied hSlot hLeaf hPosition hLive]
  exact lookupAt?_replaceAt_same liveSlots block.slotIndex
    (presentOption block.leaf) (lookupAt?_some_lt_length hLive)

theorem livePathBlockValidationFailed_slotOutOfRange
    {capacity leafCount : Nat}
    {positionMap liveSlots : List MaskedUsizeOption}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : capacity ≤ block.slotIndex) :
    livePathBlockValidationFailed
        capacity leafCount positionMap liveSlots block = true := by
  simp [livePathBlockValidationFailed, hOccupied, hSlot]

theorem livePathBlockValidationFailed_duplicateLiveSlot
    {capacity leafCount liveLeaf : Nat}
    {positionMap liveSlots : List MaskedUsizeOption}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < capacity)
    (hLeaf : block.leaf < leafCount)
    (hPosition :
      lookupAt? positionMap block.slotIndex =
        some (presentOption block.leaf))
    (hLive :
      lookupAt? liveSlots block.slotIndex =
        some (presentOption liveLeaf)) :
    livePathBlockValidationFailed
        capacity leafCount positionMap liveSlots block = true := by
  have hSlotNot : ¬ capacity ≤ block.slotIndex := by omega
  have hLeafNot : ¬ leafCount ≤ block.leaf := by omega
  simp [livePathBlockValidationFailed, hOccupied, hSlotNot, hLeafNot,
    hPosition, hLive, presentOption]

theorem liveSlotCoverageFailed_empty
    (liveSlots : List MaskedUsizeOption) :
    liveSlotCoverageFailed [] liveSlots = false := by
  simp [liveSlotCoverageFailed]

theorem liveSlotCoverageFailed_missingLiveSlot
    (leaf : MaskedUsizeOption)
    (positionMap : List MaskedUsizeOption) :
    liveSlotCoverageFailed (leaf :: positionMap) [] = true := by
  simp [liveSlotCoverageFailed]

theorem liveSlotCoverageFailed_absentHead
    (positionMap liveSlots : List MaskedUsizeOption)
    (liveSlot : MaskedUsizeOption) :
    liveSlotCoverageFailed
        (noneOption :: positionMap) (liveSlot :: liveSlots) =
      liveSlotCoverageFailed positionMap liveSlots := by
  simp [liveSlotCoverageFailed, noneOption]

theorem liveSlotCoverageFailed_presentLiveHead
    (leaf liveLeaf : Nat)
    (positionMap liveSlots : List MaskedUsizeOption) :
    liveSlotCoverageFailed
        (presentOption leaf :: positionMap)
        (presentOption liveLeaf :: liveSlots) =
      liveSlotCoverageFailed positionMap liveSlots := by
  simp [liveSlotCoverageFailed, presentOption]

theorem liveSlotCoverageFailed_presentMissingHead
    (leaf : Nat)
    (positionMap liveSlots : List MaskedUsizeOption) :
    liveSlotCoverageFailed
        (presentOption leaf :: positionMap)
        (noneOption :: liveSlots) = true := by
  simp [liveSlotCoverageFailed, presentOption, noneOption]

theorem resetPathEntryCells_length
    (capacity : Nat) :
    (resetPathEntryCells capacity).length = capacity := by
  simp [resetPathEntryCells]

theorem resetPathEntryCells_all_empty
    {capacity : Nat}
    {entry : PathEntryCell}
    (hEntry : entry ∈ resetPathEntryCells capacity) :
    entry = emptyPathEntryCell := by
  simp [resetPathEntryCells] at hEntry
  exact hEntry.2

theorem installPathEntryFailed_unoccupied
    (entries : List PathEntryCell)
    {block : StashBlock}
    (hOccupied : block.occupied = false) :
    installPathEntryFailed entries block = false := by
  simp [installPathEntryFailed, hOccupied]

theorem installPathEntryFromBlock_unoccupied
    (entries : List PathEntryCell)
    {block : StashBlock}
    (hOccupied : block.occupied = false) :
    installPathEntryFromBlock entries block = entries := by
  simp [installPathEntryFromBlock,
    installPathEntryFailed_unoccupied entries hOccupied, hOccupied]

theorem installPathEntryFailed_outOfRange
    {entries : List PathEntryCell}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : entries.length ≤ block.slotIndex) :
    installPathEntryFailed entries block = true := by
  simp [installPathEntryFailed, hOccupied, hSlot]

theorem installPathEntryFailed_validOccupied
    {entries : List PathEntryCell}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < entries.length) :
    installPathEntryFailed entries block = false := by
  have hSlotNot : ¬ entries.length ≤ block.slotIndex := by omega
  simp [installPathEntryFailed, hOccupied, hSlotNot]

theorem installPathEntryFromBlock_validOccupied
    {entries : List PathEntryCell}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < entries.length) :
    installPathEntryFromBlock entries block =
      replaceAt entries block.slotIndex (pathEntryCellFromBlock block) := by
  have hFailed := installPathEntryFailed_validOccupied hOccupied hSlot
  simp [installPathEntryFromBlock, hFailed, hOccupied]

theorem installPathEntryFromBlock_preservesLength
    (entries : List PathEntryCell)
    (block : StashBlock) :
    (installPathEntryFromBlock entries block).length = entries.length := by
  by_cases hFailed : installPathEntryFailed entries block = true
  · simp [installPathEntryFromBlock, hFailed]
  · by_cases hOccupied : block.occupied = true
    · simp [installPathEntryFromBlock, hFailed, hOccupied, replaceAt_length]
    · cases hOcc : block.occupied
      · simp [installPathEntryFromBlock, installPathEntryFailed, hOcc]
      · simp [hOcc] at hOccupied

theorem installPathEntryFromBlock_validOccupied_lookup
    {entries : List PathEntryCell}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < entries.length) :
    lookupAt? (installPathEntryFromBlock entries block) block.slotIndex =
      some (pathEntryCellFromBlock block) := by
  rw [installPathEntryFromBlock_validOccupied hOccupied hSlot]
  exact lookupAt?_replaceAt_same entries block.slotIndex
    (pathEntryCellFromBlock block) hSlot

theorem reconstructPathBlockStep_priorFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (block : StashBlock)
    (hFailed : state.failed = true) :
    reconstructPathBlockStep
      capacity leafCount positionMap state block = state := by
  rcases state with ⟨liveSlots, entries, failed⟩
  simp at hFailed
  simp [reconstructPathBlockStep, hFailed]

theorem reconstructPathBlockStep_unoccupied
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    {block : StashBlock}
    (hState : state.failed = false)
    (hOccupied : block.occupied = false) :
    reconstructPathBlockStep
      capacity leafCount positionMap state block = state := by
  rcases state with ⟨liveSlots, entries, failed⟩
  simp at hState
  simp [reconstructPathBlockStep, hState,
    livePathBlockValidationFailed_unoccupied
      capacity leafCount positionMap liveSlots hOccupied,
    installPathEntryFailed_unoccupied entries hOccupied,
    liveSlotsAfterBlockValidation_unoccupied
      capacity leafCount positionMap liveSlots hOccupied,
    installPathEntryFromBlock_unoccupied entries hOccupied]

theorem reconstructPathBlockStep_validationFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    {block : StashBlock}
    (hState : state.failed = false)
    (hValidation :
      livePathBlockValidationFailed
        capacity leafCount positionMap state.liveSlots block = true) :
    (reconstructPathBlockStep
      capacity leafCount positionMap state block).failed = true := by
  rcases state with ⟨liveSlots, entries, failed⟩
  simp at hState hValidation
  simp [reconstructPathBlockStep, hState, hValidation]

theorem reconstructPathBlockStep_installFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    {block : StashBlock}
    (hState : state.failed = false)
    (hValidation :
      livePathBlockValidationFailed
        capacity leafCount positionMap state.liveSlots block = false)
    (hInstall :
      installPathEntryFailed state.entries block = true) :
    (reconstructPathBlockStep
      capacity leafCount positionMap state block).failed = true := by
  rcases state with ⟨liveSlots, entries, failed⟩
  simp at hState hValidation hInstall
  simp [reconstructPathBlockStep, hState, hValidation, hInstall]

theorem reconstructPathBlockStep_validOccupied
    {capacity leafCount : Nat}
    {positionMap : List MaskedUsizeOption}
    {state : ReconstructionState}
    {block : StashBlock}
    (hState : state.failed = false)
    (hOccupied : block.occupied = true)
    (hSlot : block.slotIndex < capacity)
    (hLeaf : block.leaf < leafCount)
    (hPosition :
      lookupAt? positionMap block.slotIndex =
        some (presentOption block.leaf))
    (hLive :
      lookupAt? state.liveSlots block.slotIndex = some noneOption)
    (hEntrySlot : block.slotIndex < state.entries.length) :
    reconstructPathBlockStep
        capacity leafCount positionMap state block =
      { liveSlots :=
          replaceAt state.liveSlots block.slotIndex
            (presentOption block.leaf)
      , entries :=
          replaceAt state.entries block.slotIndex
            (pathEntryCellFromBlock block)
      , failed := false
      } := by
  rcases state with ⟨liveSlots, entries, failed⟩
  simp at hState hLive hEntrySlot
  have hValidation :=
    livePathBlockValidationFailed_validOccupied
      hOccupied hSlot hLeaf hPosition hLive
  have hLiveAfter :=
    liveSlotsAfterBlockValidation_validOccupied
      hOccupied hSlot hLeaf hPosition hLive
  have hInstallFailed :=
    installPathEntryFailed_validOccupied hOccupied hEntrySlot
  have hInstall :=
    installPathEntryFromBlock_validOccupied hOccupied hEntrySlot
  simp [reconstructPathBlockStep, hState, hValidation,
    hInstallFailed, hLiveAfter, hInstall]

theorem reconstructPathFinishFailed_priorFailure
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (hFailed : state.failed = true) :
    reconstructPathFinishFailed positionMap state = true := by
  cases state
  simp [reconstructPathFinishFailed] at hFailed ⊢
  exact Or.inl hFailed

theorem reconstructPathFinishFailed_coverageFailure
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (hFailed : state.failed = false)
    (hCoverage :
      liveSlotCoverageFailed positionMap state.liveSlots = true) :
    reconstructPathFinishFailed positionMap state = true := by
  cases state
  simp [reconstructPathFinishFailed] at hFailed hCoverage ⊢
  exact Or.inr hCoverage

theorem reconstructPathFinishFailed_success
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (hFailed : state.failed = false)
    (hCoverage :
      liveSlotCoverageFailed positionMap state.liveSlots = false) :
    reconstructPathFinishFailed positionMap state = false := by
  cases state
  simp [reconstructPathFinishFailed] at hFailed hCoverage ⊢
  exact ⟨hFailed, hCoverage⟩

theorem reconstructPathBlocks_empty
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState) :
    reconstructPathBlocks capacity leafCount positionMap state [] = state := by
  simp [reconstructPathBlocks]

theorem reconstructPathBlocks_cons
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState)
    (block : StashBlock)
    (blocks : List StashBlock) :
    reconstructPathBlocks
        capacity leafCount positionMap state (block :: blocks) =
      reconstructPathBlocks capacity leafCount positionMap
        (reconstructPathBlockStep
          capacity leafCount positionMap state block)
        blocks := by
  simp [reconstructPathBlocks]

theorem reconstructPathBlocks_priorFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (blocks : List StashBlock)
    (hFailed : state.failed = true) :
    reconstructPathBlocks
      capacity leafCount positionMap state blocks = state := by
  induction blocks generalizing state with
  | nil =>
      simp [reconstructPathBlocks]
  | cons block blocks ih =>
      have hStep :=
        reconstructPathBlockStep_priorFailure
          capacity leafCount positionMap block hFailed
      simp [reconstructPathBlocks, hStep, ih hFailed]

theorem initialReconstructionState_liveSlots_length
    (capacity : Nat) :
    (initialReconstructionState capacity).liveSlots.length = capacity := by
  simp [initialReconstructionState]

theorem initialReconstructionState_entries_length
    (capacity : Nat) :
    (initialReconstructionState capacity).entries.length = capacity := by
  simp [initialReconstructionState, resetPathEntryCells]

theorem initialReconstructionState_failed
    (capacity : Nat) :
    (initialReconstructionState capacity).failed = false := by
  simp [initialReconstructionState]

theorem reconstructPathDecodedBlocksState_stashThenBuckets
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock) :
    reconstructPathDecodedBlocksState
        capacity leafCount positionMap stashBlocks bucketBlocks =
      reconstructPathBlocks capacity leafCount positionMap
        (reconstructPathBlocks capacity leafCount positionMap
          (initialReconstructionState capacity)
          stashBlocks)
        bucketBlocks := by
  simp [reconstructPathDecodedBlocksState]

theorem reconstructPathDecodedBlocksState_noBlocks
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    reconstructPathDecodedBlocksState
        capacity leafCount positionMap [] [] =
      initialReconstructionState capacity := by
  simp [reconstructPathDecodedBlocksState, reconstructPathBlocks]

theorem reconstructPathDecodedBlocksState_stashFailureAbsorbs
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock)
    (hFailed :
      (reconstructPathBlocks capacity leafCount positionMap
        (initialReconstructionState capacity)
        stashBlocks).failed = true) :
    reconstructPathDecodedBlocksState
        capacity leafCount positionMap stashBlocks bucketBlocks =
      reconstructPathBlocks capacity leafCount positionMap
        (initialReconstructionState capacity)
        stashBlocks := by
  simp [reconstructPathDecodedBlocksState]
  exact reconstructPathBlocks_priorFailure
    capacity leafCount positionMap bucketBlocks hFailed

theorem reconstructPathDecodedBlocksFailed_priorFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock)
    (hFailed :
      (reconstructPathDecodedBlocksState
        capacity leafCount positionMap stashBlocks bucketBlocks).failed =
          true) :
    reconstructPathDecodedBlocksFailed
        capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  exact reconstructPathFinishFailed_priorFailure positionMap hFailed

theorem reconstructPathDecodedBlocksFailed_success
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock)
    (hFailed :
      (reconstructPathDecodedBlocksState
        capacity leafCount positionMap stashBlocks bucketBlocks).failed =
          false)
    (hCoverage :
      liveSlotCoverageFailed positionMap
        (reconstructPathDecodedBlocksState
          capacity leafCount positionMap stashBlocks bucketBlocks).liveSlots =
          false) :
    reconstructPathDecodedBlocksFailed
        capacity leafCount positionMap stashBlocks bucketBlocks = false := by
  exact reconstructPathFinishFailed_success positionMap hFailed hCoverage

theorem reconstructPathDecodedBlocksFailed_stashFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks bucketBlocks : List StashBlock)
    (hFailed :
      (reconstructPathBlocks capacity leafCount positionMap
        (initialReconstructionState capacity)
        stashBlocks).failed = true) :
    reconstructPathDecodedBlocksFailed
        capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  have hState :=
    reconstructPathDecodedBlocksState_stashFailureAbsorbs
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed
  have hFinalFailed :
      (reconstructPathDecodedBlocksState
        capacity leafCount positionMap stashBlocks bucketBlocks).failed =
        true := by
    simp [hState, hFailed]
  exact reconstructPathDecodedBlocksFailed_priorFailure
    capacity leafCount positionMap stashBlocks bucketBlocks hFinalFailed

theorem reconstructPathDecodedBlocksFailed_noBlocks
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    reconstructPathDecodedBlocksFailed
        capacity leafCount positionMap [] [] =
      liveSlotCoverageFailed
        positionMap
        (List.replicate capacity noneOption) := by
  simp [reconstructPathDecodedBlocksFailed,
    reconstructPathDecodedBlocksState,
    initialReconstructionState,
    reconstructPathBlocks,
    reconstructPathFinishFailed]

theorem bucketBlockAdmissionFailed_unoccupied
    (leafCount bucketIndex leaf : Nat) :
    bucketBlockAdmissionFailed leafCount
      { bucketIndex
      , block := { occupied := false, slotIndex := 0, leaf }
      } = false := by
  simp [bucketBlockAdmissionFailed]

theorem bucketBlockAdmissionFailed_onPath
    {leafCount bucketIndex : Nat}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hPath :
      RuntimeOramCodecSemantics.bucketOnLeafPath
        leafCount bucketIndex block.leaf = true) :
    bucketBlockAdmissionFailed leafCount
      { bucketIndex, block } = false := by
  simp [bucketBlockAdmissionFailed, hOccupied, hPath]

theorem bucketBlockAdmissionFailed_offPath
    {leafCount bucketIndex : Nat}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hPath :
      RuntimeOramCodecSemantics.bucketOnLeafPath
        leafCount bucketIndex block.leaf = false) :
    bucketBlockAdmissionFailed leafCount
      { bucketIndex, block } = true := by
  simp [bucketBlockAdmissionFailed, hOccupied, hPath]

theorem reconstructPathBucketBlockStep_priorFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (bucketBlock : BucketBlock)
  (hFailed : state.failed = true) :
    reconstructPathBucketBlockStep
        capacity leafCount positionMap state bucketBlock = state := by
  cases state with
  | mk liveSlots entries failed =>
      cases failed <;> simp [reconstructPathBucketBlockStep] at hFailed ⊢

theorem reconstructPathBucketBlockStep_offPathFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    {bucketBlock : BucketBlock}
    (hState : state.failed = false)
    (hAdmission :
      bucketBlockAdmissionFailed leafCount bucketBlock = true) :
    reconstructPathBucketBlockStep
        capacity leafCount positionMap state bucketBlock =
      { state with failed := true } := by
  cases state
  simp [reconstructPathBucketBlockStep] at hState ⊢
  simp [hState, hAdmission]

theorem reconstructPathBucketBlockStep_admitted
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    {bucketBlock : BucketBlock}
    (hState : state.failed = false)
    (hAdmission :
      bucketBlockAdmissionFailed leafCount bucketBlock = false) :
    reconstructPathBucketBlockStep
        capacity leafCount positionMap state bucketBlock =
      reconstructPathBlockStep
        capacity leafCount positionMap state bucketBlock.block := by
  cases state
  simp [reconstructPathBucketBlockStep] at hState ⊢
  simp [hState, hAdmission]

theorem reconstructPathBucketBlocks_empty
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState) :
    reconstructPathBucketBlocks
        capacity leafCount positionMap state [] = state := by
  simp [reconstructPathBucketBlocks]

theorem reconstructPathBucketBlocks_cons
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState)
    (bucketBlock : BucketBlock)
    (bucketBlocks : List BucketBlock) :
    reconstructPathBucketBlocks
        capacity leafCount positionMap state
        (bucketBlock :: bucketBlocks) =
      reconstructPathBucketBlocks capacity leafCount positionMap
        (reconstructPathBucketBlockStep
          capacity leafCount positionMap state bucketBlock)
        bucketBlocks := by
  simp [reconstructPathBucketBlocks]

theorem reconstructPathBucketBlocks_priorFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    {state : ReconstructionState}
    (bucketBlocks : List BucketBlock)
    (hFailed : state.failed = true) :
    reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks = state := by
  induction bucketBlocks generalizing state with
  | nil =>
      simp [reconstructPathBucketBlocks]
  | cons bucketBlock bucketBlocks ih =>
      have hStep :=
        reconstructPathBucketBlockStep_priorFailure
          capacity leafCount positionMap bucketBlock hFailed
      simp [reconstructPathBucketBlocks, hStep, ih hFailed]

theorem reconstructPathDecodedBucketsState_stashThenBuckets
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock) :
    reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks bucketBlocks =
      reconstructPathBucketBlocks capacity leafCount positionMap
        (reconstructPathBlocks capacity leafCount positionMap
          (initialReconstructionState capacity)
          stashBlocks)
        bucketBlocks := by
  simp [reconstructPathDecodedBucketsState]

theorem reconstructPathDecodedBucketsState_noBlocks
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    reconstructPathDecodedBucketsState
        capacity leafCount positionMap [] [] =
      initialReconstructionState capacity := by
  simp [reconstructPathDecodedBucketsState,
    reconstructPathBlocks,
    reconstructPathBucketBlocks]

theorem reconstructPathDecodedBucketsState_stashFailureAbsorbs
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock)
    (hFailed :
      (reconstructPathBlocks capacity leafCount positionMap
        (initialReconstructionState capacity)
        stashBlocks).failed = true) :
    reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks bucketBlocks =
      reconstructPathBlocks capacity leafCount positionMap
        (initialReconstructionState capacity)
        stashBlocks := by
  simp [reconstructPathDecodedBucketsState]
  exact reconstructPathBucketBlocks_priorFailure
    capacity leafCount positionMap bucketBlocks hFailed

theorem reconstructPathDecodedBucketsFailed_priorFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock)
    (hFailed :
      (reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks bucketBlocks).failed =
          true) :
    reconstructPathDecodedBucketsFailed
        capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  exact reconstructPathFinishFailed_priorFailure positionMap hFailed

theorem reconstructPathDecodedBucketsFailed_success
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock)
    (hFailed :
      (reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks bucketBlocks).failed =
          false)
    (hCoverage :
      liveSlotCoverageFailed positionMap
        (reconstructPathDecodedBucketsState
          capacity leafCount positionMap stashBlocks bucketBlocks).liveSlots =
          false) :
    reconstructPathDecodedBucketsFailed
        capacity leafCount positionMap stashBlocks bucketBlocks = false := by
  exact reconstructPathFinishFailed_success positionMap hFailed hCoverage

theorem reconstructPathDecodedBucketsFailed_stashFailure
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (bucketBlocks : List BucketBlock)
    (hFailed :
      (reconstructPathBlocks capacity leafCount positionMap
        (initialReconstructionState capacity)
        stashBlocks).failed = true) :
    reconstructPathDecodedBucketsFailed
        capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  have hState :=
    reconstructPathDecodedBucketsState_stashFailureAbsorbs
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed
  have hFinalFailed :
      (reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks bucketBlocks).failed =
        true := by
    simp [hState, hFailed]
  exact reconstructPathDecodedBucketsFailed_priorFailure
    capacity leafCount positionMap stashBlocks bucketBlocks hFinalFailed

theorem reconstructPathDecodedBucketsFailed_noBlocks
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    reconstructPathDecodedBucketsFailed
        capacity leafCount positionMap [] [] =
      liveSlotCoverageFailed
        positionMap
        (List.replicate capacity noneOption) := by
  simp [reconstructPathDecodedBucketsFailed,
    reconstructPathDecodedBucketsState,
    initialReconstructionState,
    reconstructPathBlocks,
    reconstructPathBucketBlocks,
    reconstructPathFinishFailed]

theorem pushFixedStash_preservesLength
    (blocks : List StashBlock)
    (overflowed : Bool)
    (block : StashBlock) :
    (pushFixedStash blocks overflowed block).blocks.length =
      blocks.length := by
  cases hOccupied : block.occupied
  · simp [pushFixedStash, hOccupied]
  · simp [pushFixedStash, hOccupied]
    cases firstVacantIndex blocks <;> simp [replaceAt_length]

theorem pushFixedStash_vacant_preservesOverflow
    {blocks : List StashBlock}
    {overflowed : Bool}
    {block : StashBlock}
    {index : Nat}
    (hOccupied : block.occupied = true)
    (hVacant : firstVacantIndex blocks = some index) :
    (pushFixedStash blocks overflowed block).overflowed = overflowed := by
  simp [pushFixedStash, hOccupied, hVacant]

theorem pushFixedStash_noVacant_overflows
    {blocks : List StashBlock}
    {overflowed : Bool}
    {block : StashBlock}
    (hOccupied : block.occupied = true)
    (hVacant : firstVacantIndex blocks = none) :
    (pushFixedStash blocks overflowed block).overflowed = true := by
  simp [pushFixedStash, hOccupied, hVacant]

theorem takeSelectedBlock_some_preservesLength
    {blocks : List StashBlock}
    {selectedIndex : Nat}
    {present : Bool}
    {result : TakeResult}
    (hTake :
      takeSelectedBlock blocks selectedIndex present = some result) :
    result.blocks.length = blocks.length := by
  unfold takeSelectedBlock at hTake
  cases present
  · simp at hTake
    cases hTake
    rfl
  · cases hGet : lookupAt? blocks selectedIndex
    · simp [hGet] at hTake
    · simp [hGet] at hTake
      cases hTake
      simp [replaceAt_length]

theorem takeSelectedBlock_present_selectedInBounds
    {blocks : List StashBlock}
    {selectedIndex : Nat}
    {result : TakeResult}
    (hTake :
      takeSelectedBlock blocks selectedIndex true = some result) :
    selectedIndex < blocks.length := by
  unfold takeSelectedBlock at hTake
  cases hGet : lookupAt? blocks selectedIndex
  · simp [hGet] at hTake
  · exact lookupAt?_some_lt_length hGet

theorem selectPositionMapLeaf_absent
    (positionMap : List MaskedUsizeOption)
    (slot : MaskedUsizeOption)
    (hAbsent : slot.present = false) :
    selectPositionMapLeaf positionMap slot = noneOption := by
  simp [selectPositionMapLeaf, hAbsent]

theorem selectPositionMapLeaf_present_get
    {positionMap : List MaskedUsizeOption}
    {slot leaf : MaskedUsizeOption}
    (hPresent : slot.present = true)
    (hGet : lookupAt? positionMap slot.value = some leaf) :
    selectPositionMapLeaf positionMap slot = leaf := by
  simp [selectPositionMapLeaf, hPresent, hGet]

theorem selectValueAt_absent
    (values : List α)
    (slot : MaskedUsizeOption)
    (default : α)
    (hAbsent : slot.present = false) :
    selectValueAt values slot default = default := by
  simp [selectValueAt, hAbsent]

theorem selectValueAt_present_get
    {values : List α}
    {slot : MaskedUsizeOption}
    {default value : α}
    (hPresent : slot.present = true)
    (hGet : lookupAt? values slot.value = some value) :
    selectValueAt values slot default = value := by
  simp [selectValueAt, hPresent, hGet]

theorem accessLeafForSlot_usesFreshWhenNoPrior
    (positionMap : List MaskedUsizeOption)
    (slot : MaskedUsizeOption)
    (freshLeaf : Nat)
    (hNoPrior :
      (selectPositionMapLeaf positionMap slot).present = false) :
    accessLeafForSlot positionMap slot freshLeaf = freshLeaf := by
  simp [accessLeafForSlot, unwrapOr, hNoPrior]

theorem accessLeafForSlot_usesPriorWhenPresent
    (positionMap : List MaskedUsizeOption)
    (slot : MaskedUsizeOption)
    (freshLeaf : Nat)
    (hPrior :
      (selectPositionMapLeaf positionMap slot).present = true) :
    accessLeafForSlot positionMap slot freshLeaf =
      (selectPositionMapLeaf positionMap slot).value := by
  simp [accessLeafForSlot, unwrapOr, hPrior]

theorem updatePositionMapLeafAt_preservesLength
    (offset : Nat)
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption) :
    (updatePositionMapLeafAt offset positionMap slot nextLeaf).length =
      positionMap.length := by
  induction positionMap generalizing offset with
  | nil => rfl
  | cons leaf leaves ih =>
      simp [updatePositionMapLeafAt, ih]

theorem updatePositionMapLeaf_preservesLength
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption) :
    (updatePositionMapLeaf positionMap slot nextLeaf).length =
      positionMap.length := by
  exact updatePositionMapLeafAt_preservesLength 0 positionMap slot nextLeaf

theorem updatePositionMapLeafAt_absent
    (offset : Nat)
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption)
    (hAbsent : slot.present = false) :
    updatePositionMapLeafAt offset positionMap slot nextLeaf = positionMap := by
  induction positionMap generalizing offset with
  | nil => rfl
  | cons leaf leaves ih =>
      simp [updatePositionMapLeafAt, hAbsent, ih,
        maskedSelectOption_false]

theorem updatePositionMapLeaf_absent
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption)
    (hAbsent : slot.present = false) :
    updatePositionMapLeaf positionMap slot nextLeaf = positionMap := by
  exact updatePositionMapLeafAt_absent 0 positionMap slot nextLeaf hAbsent

theorem updatePositionMapLeafAt_nextAbsent
    (offset : Nat)
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption)
    (hAbsent : nextLeaf.present = false) :
    updatePositionMapLeafAt offset positionMap slot nextLeaf = positionMap := by
  induction positionMap generalizing offset with
  | nil => rfl
  | cons leaf leaves ih =>
      simp [updatePositionMapLeafAt, hAbsent, ih,
        maskedSelectOption_false]

theorem updatePositionMapLeaf_nextAbsent
    (positionMap : List MaskedUsizeOption)
    (slot nextLeaf : MaskedUsizeOption)
    (hAbsent : nextLeaf.present = false) :
    updatePositionMapLeaf positionMap slot nextLeaf = positionMap := by
  exact updatePositionMapLeafAt_nextAbsent 0 positionMap slot nextLeaf hAbsent

theorem updateStashLeafForSlot_preservesLength
    (blocks : List StashBlock)
    (slot nextLeaf : MaskedUsizeOption) :
    (updateStashLeafForSlot blocks slot nextLeaf).length = blocks.length := by
  induction blocks with
  | nil => rfl
  | cons block blocks ih =>
      simp [updateStashLeafForSlot, ih]

theorem updateStashLeafForSlot_absent
    (blocks : List StashBlock)
    (slot nextLeaf : MaskedUsizeOption)
    (hAbsent : slot.present = false) :
    updateStashLeafForSlot blocks slot nextLeaf = blocks := by
  induction blocks with
  | nil => rfl
  | cons block blocks ih =>
      cases block
      simp [updateStashLeafForSlot, hAbsent, ih, maskedSelectNat]

theorem updateStashLeafForSlot_nextAbsent
    (blocks : List StashBlock)
    (slot nextLeaf : MaskedUsizeOption)
    (hAbsent : nextLeaf.present = false) :
    updateStashLeafForSlot blocks slot nextLeaf = blocks := by
  induction blocks with
  | nil => rfl
  | cons block blocks ih =>
      cases block
      simp [updateStashLeafForSlot, hAbsent, ih, maskedSelectNat]

theorem pathPutUpdateFailed_noApply
    (entryCapacity : Nat)
    (blocks : List StashBlock)
    (valueIsZero : Bool)
    (slot insertSlot : MaskedUsizeOption) :
    pathPutUpdateFailed entryCapacity blocks false valueIsZero slot insertSlot =
      false := by
  simp [pathPutUpdateFailed, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew]

theorem pathPutUpdateFailed_updateMissing
    (entryCapacity : Nat)
    (blocks : List StashBlock)
    (slot insertSlot : MaskedUsizeOption)
    (hSlot : slot.present = true)
    (hMissing : stashContainsSlot blocks slot.value = false) :
    pathPutUpdateFailed entryCapacity blocks true false slot insertSlot =
      true := by
  simp [pathPutUpdateFailed, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew, hSlot, hMissing]

theorem pathPutUpdateFailed_insertNoVacancy
    (entryCapacity : Nat)
    (blocks : List StashBlock)
    (slot insertSlot : MaskedUsizeOption)
    (hSlotAbsent : slot.present = false)
    (hInsert : insertSlot.present = true)
    (hVacant : stashHasVacant blocks = false) :
    pathPutUpdateFailed entryCapacity blocks true false slot insertSlot =
      true := by
  simp [pathPutUpdateFailed, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew, hSlotAbsent, hInsert, hVacant]

theorem pathPutUpdateFailed_insertOutOfRange
    (entryCapacity : Nat)
    (blocks : List StashBlock)
    (slot insertSlot : MaskedUsizeOption)
    (hSlotAbsent : slot.present = false)
    (hInsert : insertSlot.present = true)
    (hOutOfRange : entryCapacity ≤ insertSlot.value) :
    pathPutUpdateFailed entryCapacity blocks true false slot insertSlot =
      true := by
  simp [pathPutUpdateFailed, pathPutUpdateExisting,
    pathPutDeleteExisting, pathPutInsertNew, hSlotAbsent, hInsert,
    hOutOfRange]

theorem takeSelectedBlockOrEmpty_preservesLength
    (blocks : List StashBlock)
    (selectedIndex : Nat)
    (present : Bool) :
    (takeSelectedBlockOrEmpty blocks selectedIndex present).blocks.length =
      blocks.length := by
  unfold takeSelectedBlockOrEmpty
  cases hTake : takeSelectedBlock blocks selectedIndex present with
  | none => rfl
  | some result =>
      exact takeSelectedBlock_some_preservesLength hTake

theorem buildPathBucket_bucketLength
    (blocksPerBucket leafCount bucketIndex : Nat)
    (blocks : List StashBlock) :
    (buildPathBucket blocksPerBucket leafCount bucketIndex blocks).bucket.length =
      blocksPerBucket := by
  induction blocksPerBucket generalizing blocks with
  | zero => rfl
  | succ blocksPerBucket ih =>
      simp [buildPathBucket, ih]

theorem buildPathBucket_stashLength
    (blocksPerBucket leafCount bucketIndex : Nat)
    (blocks : List StashBlock) :
    (buildPathBucket blocksPerBucket leafCount bucketIndex blocks).stash.length =
      blocks.length := by
  induction blocksPerBucket generalizing blocks with
  | zero => rfl
  | succ blocksPerBucket ih =>
      simp [buildPathBucket, ih,
        takeSelectedBlockOrEmpty_preservesLength]

theorem buildPathBucket_liveCountBound
    (blocksPerBucket leafCount bucketIndex : Nat)
    (blocks : List StashBlock) :
    (buildPathBucket blocksPerBucket leafCount bucketIndex blocks).liveCount ≤
      blocksPerBucket := by
  induction blocksPerBucket generalizing blocks with
  | zero => exact Nat.le_refl _
  | succ blocksPerBucket ih =>
      by_cases hPresent :
        (selectPathBlockIndex leafCount bucketIndex blocks).isSome = true
      · have hRest :=
          ih (takeSelectedBlockOrEmpty blocks
            ((selectPathBlockIndex leafCount bucketIndex blocks).getD 0)
            true).blocks
        simp [buildPathBucket, hPresent]
        omega
      · have hFalse :
            (selectPathBlockIndex leafCount bucketIndex blocks).isSome =
              false := by
          cases hSome :
              (selectPathBlockIndex leafCount bucketIndex blocks).isSome with
          | false => rfl
          | true => exact False.elim (hPresent hSome)
        have hRest := ih (takeSelectedBlockOrEmpty blocks
          ((selectPathBlockIndex leafCount bucketIndex blocks).getD 0)
          false).blocks
        simp [buildPathBucket, hFalse]
        omega

theorem rewritePathWriteCount_matchesWriteLogCapacity
    (parameters : RewriteParameters) :
    rewritePathWriteCount parameters =
      RuntimeOramWriteLogDiscipline.writeLogCapacity
        (rewriteWriteLogParameters parameters) := by
  rfl

theorem pathAccessReadCount_matchesReadTranscriptCapacity
    (parameters : RewriteParameters) :
    pathAccessReadCount parameters =
      RuntimeOramWriteLogDiscipline.readTranscriptCapacity
        (rewriteWriteLogParameters parameters) := by
  rfl

theorem rewritePathSummary_nextCounter
    (parameters : RewriteParameters)
    (currentCounter : Nat)
    (loadOverflowed effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat) :
    (rewritePathSummary parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen).nextCounter =
        currentCounter + 1 := by
  rfl

theorem rewritePathSummary_physicalWriteCount
    (parameters : RewriteParameters)
    (currentCounter : Nat)
    (loadOverflowed effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat) :
    (rewritePathSummary parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen).physicalWriteCount =
        rewritePathWriteCount parameters := by
  rfl

theorem rewritePathUpdateFailed_loadOverflow
    (parameters : RewriteParameters)
    (effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat) :
    rewritePathUpdateFailed parameters true effectFailed
      postUpdateStashLen postRebuildStashLen = true := by
  rfl

theorem rewritePathUpdateFailed_effectFailed
    (parameters : RewriteParameters)
    (loadOverflowed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat) :
    rewritePathUpdateFailed parameters loadOverflowed true
      postUpdateStashLen postRebuildStashLen = true := by
  cases loadOverflowed <;> rfl

theorem rewritePathUpdateFailed_postUpdateOverflow
    (parameters : RewriteParameters)
    (loadOverflowed effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat)
    (hOverflow : rewriteWorkingStashBound parameters < postUpdateStashLen) :
    rewritePathUpdateFailed parameters loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen = true := by
  simp [rewritePathUpdateFailed, hOverflow]

theorem rewritePathUpdateFailed_postRebuildOverflow
    (parameters : RewriteParameters)
    (loadOverflowed effectFailed : Bool)
    (postUpdateStashLen postRebuildStashLen : Nat)
    (hOverflow : parameters.stashBound < postRebuildStashLen) :
    rewritePathUpdateFailed parameters loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen = true := by
  simp [rewritePathUpdateFailed, hOverflow]

theorem rewritePathUpdateFailed_noFailure
    (parameters : RewriteParameters)
    (postUpdateStashLen postRebuildStashLen : Nat)
    (hPostUpdate :
      postUpdateStashLen ≤ rewriteWorkingStashBound parameters)
    (hPostRebuild :
      postRebuildStashLen ≤ parameters.stashBound) :
    rewritePathUpdateFailed parameters false false
      postUpdateStashLen postRebuildStashLen = false := by
  have hPostUpdateNot :
      ¬ rewriteWorkingStashBound parameters < postUpdateStashLen :=
    Nat.not_lt_of_ge hPostUpdate
  have hPostRebuildNot :
      ¬ parameters.stashBound < postRebuildStashLen :=
    Nat.not_lt_of_ge hPostRebuild
  simp [rewritePathUpdateFailed, hPostUpdateNot, hPostRebuildNot]

theorem rewritePathSummary_noFailure
    (parameters : RewriteParameters)
    (currentCounter postUpdateStashLen postRebuildStashLen : Nat)
    (hPostUpdate :
      postUpdateStashLen ≤ rewriteWorkingStashBound parameters)
    (hPostRebuild :
      postRebuildStashLen ≤ parameters.stashBound) :
    (rewritePathSummary parameters currentCounter false false
      postUpdateStashLen postRebuildStashLen).updateFailed = false := by
  exact rewritePathUpdateFailed_noFailure parameters postUpdateStashLen
    postRebuildStashLen hPostUpdate hPostRebuild

/-! ### Bridge: codec decoded path bucket blocks to helper bucket blocks -/

def stashBlockOfCodecBlock
    (block : RuntimeOramCodecSemantics.CodecBlock) : StashBlock :=
  { occupied := decide (block.occupiedTag = 1)
  , slotIndex :=
      RuntimeOramCodecSemantics.decodeNatField block.slotIndexField
  , leaf :=
      RuntimeOramCodecSemantics.decodeNatField block.leafLabelField
  }

def bucketBlockOfCodecBlock
    (bucketIndex : Nat)
    (block : RuntimeOramCodecSemantics.CodecBlock) : BucketBlock :=
  { bucketIndex
  , block := stashBlockOfCodecBlock block
  }

def stashBlocksOfCodecBlocks
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    List StashBlock :=
  blocks.map stashBlockOfCodecBlock

def bucketBlocksOfCodecBlocks
    (bucketIndex : Nat)
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    List BucketBlock :=
  blocks.map (bucketBlockOfCodecBlock bucketIndex)

theorem stashBlockOfCodecBlock_occupied
    (block : RuntimeOramCodecSemantics.CodecBlock) :
    (stashBlockOfCodecBlock block).occupied =
      decide (block.occupiedTag = 1) := by
  simp [stashBlockOfCodecBlock]

theorem stashBlockOfCodecBlock_occupied_iff
    (block : RuntimeOramCodecSemantics.CodecBlock) :
    (stashBlockOfCodecBlock block).occupied = true ↔
      block.occupiedTag = 1 := by
  simp [stashBlockOfCodecBlock_occupied]

theorem stashBlockOfCodecBlock_slotIndex
    (block : RuntimeOramCodecSemantics.CodecBlock) :
    (stashBlockOfCodecBlock block).slotIndex =
      RuntimeOramCodecSemantics.decodeNatField block.slotIndexField := by
  rfl

theorem stashBlockOfCodecBlock_leaf
    (block : RuntimeOramCodecSemantics.CodecBlock) :
    (stashBlockOfCodecBlock block).leaf =
      RuntimeOramCodecSemantics.decodeNatField block.leafLabelField := by
  rfl

theorem bucketBlockOfCodecBlock_bucketIndex
    (bucketIndex : Nat)
    (block : RuntimeOramCodecSemantics.CodecBlock) :
    (bucketBlockOfCodecBlock bucketIndex block).bucketIndex = bucketIndex := by
  rfl

theorem bucketBlockOfCodecBlock_block
    (bucketIndex : Nat)
    (block : RuntimeOramCodecSemantics.CodecBlock) :
    (bucketBlockOfCodecBlock bucketIndex block).block =
      stashBlockOfCodecBlock block := by
  rfl

theorem stashBlocksOfCodecBlocks_length
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    (stashBlocksOfCodecBlocks blocks).length = blocks.length := by
  simp [stashBlocksOfCodecBlocks]

theorem bucketBlocksOfCodecBlocks_length
    (bucketIndex : Nat)
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    (bucketBlocksOfCodecBlocks bucketIndex blocks).length = blocks.length := by
  simp [bucketBlocksOfCodecBlocks]

theorem bucketBlocksOfCodecBlocks_map_block
    (bucketIndex : Nat)
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    (bucketBlocksOfCodecBlocks bucketIndex blocks).map BucketBlock.block =
      stashBlocksOfCodecBlocks blocks := by
  simp [bucketBlocksOfCodecBlocks, stashBlocksOfCodecBlocks,
    bucketBlockOfCodecBlock]

theorem bucketBlocksOfCodecBlocks_nil
    (bucketIndex : Nat) :
    bucketBlocksOfCodecBlocks bucketIndex [] = [] := by
  rfl

theorem bucketBlocksOfCodecBlocks_cons
    (bucketIndex : Nat)
    (block : RuntimeOramCodecSemantics.CodecBlock)
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    bucketBlocksOfCodecBlocks bucketIndex (block :: blocks) =
      bucketBlockOfCodecBlock bucketIndex block ::
        bucketBlocksOfCodecBlocks bucketIndex blocks := by
  simp [bucketBlocksOfCodecBlocks]

theorem stashBlocksOfCodecBlocks_nil :
    stashBlocksOfCodecBlocks [] = [] := by
  rfl

theorem stashBlocksOfCodecBlocks_cons
    (block : RuntimeOramCodecSemantics.CodecBlock)
    (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
    stashBlocksOfCodecBlocks (block :: blocks) =
      stashBlockOfCodecBlock block :: stashBlocksOfCodecBlocks blocks := by
  simp [stashBlocksOfCodecBlocks]

theorem bucketBlockAdmissionFailed_bridge_unoccupied
    {leafCount bucketIndex : Nat}
    {block : RuntimeOramCodecSemantics.CodecBlock}
    (hUnoccupied : block.occupiedTag ≠ 1) :
    bucketBlockAdmissionFailed leafCount
        (bucketBlockOfCodecBlock bucketIndex block) = false := by
  simp [bucketBlockAdmissionFailed, bucketBlockOfCodecBlock,
    stashBlockOfCodecBlock]
  intro hOcc
  exact (hUnoccupied hOcc).elim

theorem bucketBlockAdmissionFailed_bridge_liveOnBucketPath
    {leafCount bucketIndex : Nat}
    {block : RuntimeOramCodecSemantics.CodecBlock}
    (hLive : block.LiveOnBucketPath leafCount bucketIndex) :
    bucketBlockAdmissionFailed leafCount
        (bucketBlockOfCodecBlock bucketIndex block) = false := by
  by_cases hOcc : block.occupiedTag = 1
  · have hPath := hLive hOcc
    simp [bucketBlockAdmissionFailed, bucketBlockOfCodecBlock,
      stashBlockOfCodecBlock, hOcc, hPath]
  · exact bucketBlockAdmissionFailed_bridge_unoccupied (bucketIndex := bucketIndex)
      hOcc

theorem bucketBlocksOfCodecBlocks_admitted_of_liveOnBucketPath
    {leafCount bucketIndex : Nat}
    {blocks : List RuntimeOramCodecSemantics.CodecBlock}
    (hLive :
      ∀ block, block ∈ blocks →
        block.LiveOnBucketPath leafCount bucketIndex) :
    ∀ bucketBlock,
      bucketBlock ∈ bucketBlocksOfCodecBlocks bucketIndex blocks →
        bucketBlockAdmissionFailed leafCount bucketBlock = false := by
  intro bucketBlock hMem
  rcases List.mem_map.mp hMem with ⟨block, hBlock, hEq⟩
  subst hEq
  exact bucketBlockAdmissionFailed_bridge_liveOnBucketPath
    (hLive block hBlock)

theorem reconstructPathBucketBlocks_eq_reconstructPathBlocks_of_admitted
    (capacity leafCount : Nat)
    (positionMap : List MaskedUsizeOption) :
    ∀ (state : ReconstructionState)
      (bucketBlocks : List BucketBlock),
      (∀ bb, bb ∈ bucketBlocks →
        bucketBlockAdmissionFailed leafCount bb = false) →
      reconstructPathBucketBlocks
          capacity leafCount positionMap state bucketBlocks =
        reconstructPathBlocks capacity leafCount positionMap state
          (bucketBlocks.map BucketBlock.block) := by
  intro state bucketBlocks
  induction bucketBlocks generalizing state with
  | nil =>
      intro _hAdmit
      simp [reconstructPathBucketBlocks, reconstructPathBlocks]
  | cons bb tail ih =>
      intro hAdmit
      have hHead :
          bucketBlockAdmissionFailed leafCount bb = false :=
        hAdmit bb (by simp)
      have hTail :
          ∀ bb', bb' ∈ tail →
            bucketBlockAdmissionFailed leafCount bb' = false := by
        intro bb' hbb'
        exact hAdmit bb' (List.mem_cons_of_mem _ hbb')
      by_cases hFailed : state.failed = true
      · have hStep :=
          reconstructPathBucketBlockStep_priorFailure
            capacity leafCount positionMap bb hFailed
        have hStepFlat :=
          reconstructPathBlockStep_priorFailure
            capacity leafCount positionMap bb.block hFailed
        have hRecBucket :=
          reconstructPathBucketBlocks_priorFailure
            capacity leafCount positionMap tail hFailed
        have hRecFlat :=
          reconstructPathBlocks_priorFailure
            capacity leafCount positionMap (tail.map BucketBlock.block) hFailed
        simp [reconstructPathBucketBlocks, hStep, hRecBucket,
          reconstructPathBlocks, hStepFlat, hRecFlat]
      · have hStateNotFailed : state.failed = false := by
          cases h : state.failed
          · rfl
          · simp [h] at hFailed
        have hStep :=
          reconstructPathBucketBlockStep_admitted
            capacity leafCount positionMap hStateNotFailed hHead
        rw [reconstructPathBucketBlocks_cons,
          hStep,
          List.map_cons,
          reconstructPathBlocks_cons]
        exact ih _ hTail

theorem reconstructPathBucketBlocks_bucketBlocksOfCodecBlocks
    {capacity leafCount bucketIndex : Nat}
    (positionMap : List MaskedUsizeOption)
    (state : ReconstructionState)
    (codecBlocks : List RuntimeOramCodecSemantics.CodecBlock)
    (hLive :
      ∀ block, block ∈ codecBlocks →
        block.LiveOnBucketPath leafCount bucketIndex) :
    reconstructPathBucketBlocks capacity leafCount positionMap state
        (bucketBlocksOfCodecBlocks bucketIndex codecBlocks) =
      reconstructPathBlocks capacity leafCount positionMap state
        (stashBlocksOfCodecBlocks codecBlocks) := by
  have hAdmit :
      ∀ bb, bb ∈ bucketBlocksOfCodecBlocks bucketIndex codecBlocks →
        bucketBlockAdmissionFailed leafCount bb = false :=
    bucketBlocksOfCodecBlocks_admitted_of_liveOnBucketPath hLive
  rw [reconstructPathBucketBlocks_eq_reconstructPathBlocks_of_admitted
    capacity leafCount positionMap state
    (bucketBlocksOfCodecBlocks bucketIndex codecBlocks) hAdmit,
    bucketBlocksOfCodecBlocks_map_block]

theorem reconstructPathDecodedBucketsState_bucketBlocksOfCodecBlocks
    {capacity leafCount bucketIndex : Nat}
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (codecBlocks : List RuntimeOramCodecSemantics.CodecBlock)
    (hLive :
      ∀ block, block ∈ codecBlocks →
        block.LiveOnBucketPath leafCount bucketIndex) :
    reconstructPathDecodedBucketsState capacity leafCount positionMap
        stashBlocks (bucketBlocksOfCodecBlocks bucketIndex codecBlocks) =
      reconstructPathDecodedBlocksState capacity leafCount positionMap
        stashBlocks (stashBlocksOfCodecBlocks codecBlocks) := by
  unfold reconstructPathDecodedBucketsState reconstructPathDecodedBlocksState
  exact reconstructPathBucketBlocks_bucketBlocksOfCodecBlocks
    positionMap _ codecBlocks hLive

theorem reconstructPathDecodedBucketsFailed_bucketBlocksOfCodecBlocks
    {capacity leafCount bucketIndex : Nat}
    (positionMap : List MaskedUsizeOption)
    (stashBlocks : List StashBlock)
    (codecBlocks : List RuntimeOramCodecSemantics.CodecBlock)
    (hLive :
      ∀ block, block ∈ codecBlocks →
        block.LiveOnBucketPath leafCount bucketIndex) :
    reconstructPathDecodedBucketsFailed capacity leafCount positionMap
        stashBlocks (bucketBlocksOfCodecBlocks bucketIndex codecBlocks) =
      reconstructPathDecodedBlocksFailed capacity leafCount positionMap
        stashBlocks (stashBlocksOfCodecBlocks codecBlocks) := by
  unfold reconstructPathDecodedBucketsFailed reconstructPathDecodedBlocksFailed
  rw [reconstructPathDecodedBucketsState_bucketBlocksOfCodecBlocks
    positionMap stashBlocks codecBlocks hLive]

end RuntimeOramHelperSemantics

end UOToolchain
