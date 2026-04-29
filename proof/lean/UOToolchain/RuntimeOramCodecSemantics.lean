import UOToolchain.OramModel

namespace UOToolchain

namespace RuntimeOramCodecSemantics

def directoryPageEntries : Nat := 8
def slotIndexBytes : Nat := 8
def leafLabelBytes : Nat := 8
def occupancyTagBytes : Nat := 1

def surrogateBlockBytes (keyBytes valueBytes : Nat) : Nat :=
  occupancyTagBytes + keyBytes + valueBytes

def pathBlockBytes (keyBytes valueBytes : Nat) : Nat :=
  occupancyTagBytes + slotIndexBytes + leafLabelBytes + keyBytes + valueBytes

def bucketBytes (blocksPerBucket blockBytes : Nat) : Nat :=
  oramBucketHeaderBytes + blocksPerBucket * blockBytes

def directoryPageBytes (blockBytes : Nat) : Nat :=
  directoryPageEntries * blockBytes

def pathPositionMapPages (capacity : Nat) : Nat :=
  (max capacity 1 + directoryPageEntries - 1) / directoryPageEntries

def pathStashPages (metadataPages capacity : Nat) : Nat :=
  metadataPages - pathPositionMapPages capacity

def pathPositionMapEntryBytes : Nat :=
  directoryPageEntries * leafLabelBytes

def pathPositionMapEmptySentinel : Nat :=
  2 ^ (8 * leafLabelBytes) - 1

def decodeNatField (field : List Nat) : Nat :=
  field.foldl (fun acc byte => acc * 256 + byte) 0

def counterFieldBytes : Nat := slotIndexBytes

def ValidByte (byte : Nat) : Prop :=
  byte < 256

def ValidByteField (bytes : List Nat) : Prop :=
  ∀ byte, byte ∈ bytes → ValidByte byte

def CounterDecodeAccepted (bytes : List Nat) : Prop :=
  bytes.length = counterFieldBytes ∧ ValidByteField bytes

def encodeNatField (width value : Nat) : List Nat :=
  (List.range width).map
    (fun index => (value / (256 ^ (width - 1 - index))) % 256)

def encodeCounterField (counter : Nat) : List Nat :=
  encodeNatField counterFieldBytes counter

def decodeCounterExact? (bytes : List Nat) : Option Nat :=
  if bytes.length = counterFieldBytes then
    some (decodeNatField bytes)
  else
    none

def lookupPositionMap : List (Option Nat) → Nat → Option (Option Nat)
  | [], _ => none
  | entry :: _entries, 0 => some entry
  | _entry :: entries, index + 1 => lookupPositionMap entries index

structure CodecBlock where
  occupiedTag : Nat
  slotIndexField : List Nat
  leafLabelField : List Nat
  keyField : List Nat
  valueField : List Nat
deriving Repr, DecidableEq

structure CodecBucket where
  accessCounterField : List Nat
  bucketIndexField : List Nat
  liveEntryCountField : List Nat
  blocks : List CodecBlock
deriving Repr, DecidableEq

def codecPathFieldBytes (isPath : Bool) : Nat :=
  if isPath then slotIndexBytes + leafLabelBytes else 0

def codecBlockBytes (isPath : Bool) (keyBytes valueBytes : Nat) : Nat :=
  occupancyTagBytes + codecPathFieldBytes isPath + keyBytes + valueBytes

def codecBucketHeaderBytes : Nat :=
  slotIndexBytes + slotIndexBytes + slotIndexBytes

def codecBucketBytes
    (isPath : Bool)
    (blocksPerBucket keyBytes valueBytes : Nat) : Nat :=
  codecBucketHeaderBytes +
    blocksPerBucket * codecBlockBytes isPath keyBytes valueBytes

def CodecBlock.ValidShape
    (isPath : Bool)
    (keyBytes valueBytes : Nat)
    (block : CodecBlock) : Prop :=
  (block.occupiedTag = 0 ∨ block.occupiedTag = 1) ∧
    (match isPath with
      | true =>
          block.slotIndexField.length = slotIndexBytes ∧
            block.leafLabelField.length = leafLabelBytes
      | false =>
          block.slotIndexField = [] ∧ block.leafLabelField = []) ∧
    block.keyField.length = keyBytes ∧
    block.valueField.length = valueBytes

def CodecBlock.LivePathWithinBounds
    (capacity leafCount : Nat)
    (block : CodecBlock) : Prop :=
  block.occupiedTag = 1 →
    decodeNatField block.slotIndexField < capacity ∧
      decodeNatField block.leafLabelField < leafCount

def pathLeafNode (leafCount leaf : Nat) : Nat :=
  leafCount - 1 + (leaf % max leafCount 1)

def bucketOnLeafPathFromNode : Nat → Nat → Nat → Bool
  | 0, bucketIndex, node => node == bucketIndex
  | fuel + 1, bucketIndex, node =>
      if node == bucketIndex then
        true
      else if node == 0 then
        false
      else
        bucketOnLeafPathFromNode fuel bucketIndex ((node - 1) / 2)

def bucketOnLeafPath
    (leafCount bucketIndex leaf : Nat) : Bool :=
  let node := pathLeafNode leafCount leaf
  bucketOnLeafPathFromNode (node + 1) bucketIndex node

def CodecBlock.LiveOnBucketPath
    (leafCount bucketIndex : Nat)
    (block : CodecBlock) : Prop :=
  block.occupiedTag = 1 →
    bucketOnLeafPath leafCount bucketIndex
      (decodeNatField block.leafLabelField) = true

def CodecBlock.AgreesWithPositionMap
    (positionMap : List (Option Nat))
    (block : CodecBlock) : Prop :=
  block.occupiedTag = 1 →
    lookupPositionMap positionMap (decodeNatField block.slotIndexField) =
      some (some (decodeNatField block.leafLabelField))

def CodecBucket.ValidShape
    (isPath : Bool)
    (blocksPerBucket keyBytes valueBytes : Nat)
    (bucket : CodecBucket) : Prop :=
  bucket.accessCounterField.length = slotIndexBytes ∧
    bucket.bucketIndexField.length = slotIndexBytes ∧
    bucket.liveEntryCountField.length = slotIndexBytes ∧
    bucket.blocks.length = blocksPerBucket ∧
    ∀ block, block ∈ bucket.blocks →
      block.ValidShape isPath keyBytes valueBytes

def liveBlockCount : List CodecBlock → Nat
  | [] => 0
  | block :: blocks =>
      (if block.occupiedTag = 1 then 1 else 0) + liveBlockCount blocks

def LiveSlotDistinctFromSeen : List Nat → List CodecBlock → Prop
  | _seen, [] => True
  | seen, block :: blocks =>
      if block.occupiedTag = 1 then
        decodeNatField block.slotIndexField ∉ seen ∧
          LiveSlotDistinctFromSeen
            (decodeNatField block.slotIndexField :: seen) blocks
      else
        LiveSlotDistinctFromSeen seen blocks

def LiveSlotNoDuplicates (blocks : List CodecBlock) : Prop :=
  LiveSlotDistinctFromSeen [] blocks

def LiveSlotPresent
    (blocks : List CodecBlock)
    (slot : Nat) : Prop :=
  ∃ block, block ∈ blocks ∧
    block.occupiedTag = 1 ∧
    decodeNatField block.slotIndexField = slot

def PositionMapCoveredFromSlot
    (slot : Nat) :
    List (Option Nat) → List CodecBlock → Prop
  | [], _blocks => True
  | none :: entries, blocks =>
      PositionMapCoveredFromSlot (slot + 1) entries blocks
  | some _leaf :: entries, blocks =>
      LiveSlotPresent blocks slot ∧
        PositionMapCoveredFromSlot (slot + 1) entries blocks

def PositionMapCoveredByLiveBlocks
    (positionMap : List (Option Nat))
    (blocks : List CodecBlock) : Prop :=
  PositionMapCoveredFromSlot 0 positionMap blocks

structure DecodedBucketPayload where
  bucketIndex : Nat
  liveEntryCount : Nat
  blocks : List CodecBlock
deriving Repr, DecidableEq

def DecodedBucketPayload.Accepted
    (expectedBucketIndex blocksPerBucket : Nat)
    (payload : DecodedBucketPayload) : Prop :=
  payload.bucketIndex = expectedBucketIndex ∧
    payload.blocks.length = blocksPerBucket ∧
    payload.liveEntryCount ≤ blocksPerBucket ∧
    liveBlockCount payload.blocks = payload.liveEntryCount

instance DecodedBucketPayload.decidableAccepted
    (expectedBucketIndex blocksPerBucket : Nat)
    (payload : DecodedBucketPayload) :
    Decidable (payload.Accepted expectedBucketIndex blocksPerBucket) := by
  unfold DecodedBucketPayload.Accepted
  infer_instance

def PositionMapLeafBounded
    (leafCount : Nat)
    (positionMap : List (Option Nat)) : Prop :=
  ∀ leaf, some leaf ∈ positionMap → leaf < leafCount

def PositionMapDecodeAccepted
    (capacity leafCount : Nat)
    (positionMap : List (Option Nat)) : Prop :=
  positionMap.length = capacity ∧
    PositionMapLeafBounded leafCount positionMap

def PositionMapEntryLeafBounded
    (leafCount : Nat) : Option Nat → Prop
  | none => True
  | some leaf => leaf < leafCount

structure DecodedPathPositionMapPage where
  entries : List (Option Nat)
  padding : List Nat
deriving Repr, DecidableEq

def DecodedPathPositionMapPage.Accepted
    (leafCount directoryPageBytes : Nat)
    (page : DecodedPathPositionMapPage) : Prop :=
  page.entries.length = directoryPageEntries ∧
    PositionMapLeafBounded leafCount page.entries ∧
    page.padding.length = directoryPageBytes - pathPositionMapEntryBytes

structure DecodedPathStashPage where
  blocks : List CodecBlock
deriving Repr, DecidableEq

def DecodedPathStashPage.Accepted
    (blocksPerPage : Nat)
    (page : DecodedPathStashPage) : Prop :=
  page.blocks.length = blocksPerPage ∧
    liveBlockCount page.blocks ≤ blocksPerPage

def encodeBlock (isPath : Bool) (block : CodecBlock) : List Nat :=
  [block.occupiedTag] ++
    (if isPath then block.slotIndexField ++ block.leafLabelField else []) ++
    block.keyField ++
    block.valueField

def decodeBlock?
    (isPath : Bool)
    (keyBytes valueBytes : Nat)
    (bytes : List Nat) : Option CodecBlock :=
  let occupiedTag := bytes.getD 0 0
  if occupiedTag = 0 ∨ occupiedTag = 1 then
    let rest := bytes.drop occupancyTagBytes
    let slotIndexField :=
      if isPath then rest.take slotIndexBytes else []
    let rest :=
      if isPath then rest.drop slotIndexBytes else rest
    let leafLabelField :=
      if isPath then rest.take leafLabelBytes else []
    let rest :=
      if isPath then rest.drop leafLabelBytes else rest
    some
      { occupiedTag
      , slotIndexField
      , leafLabelField
      , keyField := rest.take keyBytes
      , valueField := (rest.drop keyBytes).take valueBytes
      }
  else
    none

def decodeBlockExact?
    (isPath : Bool)
    (keyBytes valueBytes : Nat)
    (bytes : List Nat) : Option CodecBlock :=
  if bytes.length = codecBlockBytes isPath keyBytes valueBytes then
    decodeBlock? isPath keyBytes valueBytes bytes
  else
    none

def decodePositionMapLeaf?
    (leafCount : Nat)
    (field : List Nat) : Option (Option Nat) :=
  let value := decodeNatField field
  if value = pathPositionMapEmptySentinel then
    some none
  else if value < leafCount then
    some (some value)
  else
    none

def decodePositionMapEntriesExact?
    (leafCount : Nat) :
    Nat → List Nat → Option (List (Option Nat))
  | 0, bytes =>
      if bytes = [] then some [] else none
  | count + 1, bytes =>
      match
          decodePositionMapLeaf? leafCount (bytes.take leafLabelBytes),
          decodePositionMapEntriesExact? leafCount count
            (bytes.drop leafLabelBytes) with
      | some entry, some entries => some (entry :: entries)
      | _, _ => none

def decodePathPositionMapPageExact?
    (leafCount directoryPageBytes : Nat)
    (bytes : List Nat) : Option DecodedPathPositionMapPage :=
  if bytes.length = directoryPageBytes ∧
      pathPositionMapEntryBytes ≤ directoryPageBytes then
    match
        decodePositionMapEntriesExact? leafCount directoryPageEntries
          (bytes.take pathPositionMapEntryBytes) with
    | some entries =>
        some
          { entries
          , padding := bytes.drop pathPositionMapEntryBytes
          }
    | none => none
  else
    none

def decodePathPositionMapPagesAll?
    (leafCount directoryPageBytes : Nat) :
    List (List Nat) → Option (List (Option Nat))
  | [] => some []
  | pageBytes :: pages =>
      match
          decodePathPositionMapPageExact?
            leafCount directoryPageBytes pageBytes,
          decodePathPositionMapPagesAll?
            leafCount directoryPageBytes pages with
      | some page, some entries => some (page.entries ++ entries)
      | _, _ => none

def decodePathPositionMapPagesExact?
    (leafCount directoryPageBytes capacity : Nat)
    (pages : List (List Nat)) : Option (List (Option Nat)) :=
  if pages.length = pathPositionMapPages capacity then
    match decodePathPositionMapPagesAll? leafCount directoryPageBytes pages with
    | some entries =>
        if capacity ≤ entries.length then
          some (entries.take capacity)
        else
          none
    | none => none
  else
    none

def decodeExactBlocks?
    (isPath : Bool)
    (keyBytes valueBytes : Nat) :
    Nat → List Nat → Option (List CodecBlock)
  | 0, bytes =>
      if bytes = [] then some [] else none
  | blockCount + 1, bytes =>
      let blockBytes := codecBlockBytes isPath keyBytes valueBytes
      match
          decodeBlockExact? isPath keyBytes valueBytes
            (bytes.take blockBytes),
          decodeExactBlocks? isPath keyBytes valueBytes
            blockCount (bytes.drop blockBytes) with
      | some block, some blocks => some (block :: blocks)
      | _, _ => none

def decodePathStashPageExact?
    (isPath : Bool)
    (keyBytes valueBytes directoryPageBytes : Nat)
    (bytes : List Nat) : Option DecodedPathStashPage :=
  if bytes.length = directoryPageBytes ∧
      directoryPageBytes =
        directoryPageEntries *
          codecBlockBytes isPath keyBytes valueBytes then
    match
        decodeExactBlocks? isPath keyBytes valueBytes
          directoryPageEntries bytes with
    | some blocks => some { blocks }
    | none => none
  else
    none

def decodePathStashPagesAll?
    (isPath : Bool)
    (keyBytes valueBytes directoryPageBytes : Nat) :
    List (List Nat) → Option (List CodecBlock)
  | [] => some []
  | pageBytes :: pages =>
      match
          decodePathStashPageExact?
            isPath keyBytes valueBytes directoryPageBytes pageBytes,
          decodePathStashPagesAll?
            isPath keyBytes valueBytes directoryPageBytes pages with
      | some page, some blocks => some (page.blocks ++ blocks)
      | _, _ => none

def decodePathStashPagesExact?
    (isPath : Bool)
    (keyBytes valueBytes directoryPageBytes stashPageCount : Nat)
    (pages : List (List Nat)) : Option (List CodecBlock) :=
  if pages.length = stashPageCount then
    decodePathStashPagesAll?
      isPath keyBytes valueBytes directoryPageBytes pages
  else
    none

def checkPathBlockLiveWithinBounds
    (capacity leafCount : Nat)
    (block : CodecBlock) : Bool :=
  if block.occupiedTag = 1 then
    (decide (decodeNatField block.slotIndexField < capacity)) &&
      (decide (decodeNatField block.leafLabelField < leafCount))
  else
    true

def checkPathBlocksLiveWithinBounds
    (capacity leafCount : Nat) :
    List CodecBlock → Bool
  | [] => true
  | block :: blocks =>
      checkPathBlockLiveWithinBounds capacity leafCount block &&
        checkPathBlocksLiveWithinBounds capacity leafCount blocks

def checkPathBlockLiveOnBucketPath
    (leafCount bucketIndex : Nat)
    (block : CodecBlock) : Bool :=
  if block.occupiedTag = 1 then
    bucketOnLeafPath leafCount bucketIndex
      (decodeNatField block.leafLabelField)
  else
    true

def checkPathBlocksLiveOnBucketPath
    (leafCount bucketIndex : Nat) :
    List CodecBlock → Bool
  | [] => true
  | block :: blocks =>
      checkPathBlockLiveOnBucketPath leafCount bucketIndex block &&
        checkPathBlocksLiveOnBucketPath leafCount bucketIndex blocks

def checkPathBlockPositionMapAgreement
    (positionMap : List (Option Nat))
    (block : CodecBlock) : Bool :=
  if block.occupiedTag = 1 then
    lookupPositionMap positionMap (decodeNatField block.slotIndexField) ==
      some (some (decodeNatField block.leafLabelField))
  else
    true

def checkPathBlocksPositionMapAgreement
    (positionMap : List (Option Nat)) :
    List CodecBlock → Bool
  | [] => true
  | block :: blocks =>
      checkPathBlockPositionMapAgreement positionMap block &&
        checkPathBlocksPositionMapAgreement positionMap blocks

def checkPathBlocksNoDuplicateLiveSlotsFromSeen
    (seen : List Nat) :
    List CodecBlock → Bool
  | [] => true
  | block :: blocks =>
      if block.occupiedTag = 1 then
        (decide (decodeNatField block.slotIndexField ∉ seen)) &&
          checkPathBlocksNoDuplicateLiveSlotsFromSeen
            (decodeNatField block.slotIndexField :: seen) blocks
      else
        checkPathBlocksNoDuplicateLiveSlotsFromSeen seen blocks

def checkPathBlocksNoDuplicateLiveSlots
    (blocks : List CodecBlock) : Bool :=
  checkPathBlocksNoDuplicateLiveSlotsFromSeen [] blocks

def checkLiveSlotPresent : List CodecBlock → Nat → Bool
  | [], _slot => false
  | block :: blocks, slot =>
      if block.occupiedTag = 1 ∧
          decodeNatField block.slotIndexField = slot then
        true
      else
        checkLiveSlotPresent blocks slot

def checkPositionMapCoveredFromSlot
    (slot : Nat) :
    List (Option Nat) → List CodecBlock → Bool
  | [], _blocks => true
  | none :: entries, blocks =>
      checkPositionMapCoveredFromSlot (slot + 1) entries blocks
  | some _leaf :: entries, blocks =>
      checkLiveSlotPresent blocks slot &&
        checkPositionMapCoveredFromSlot (slot + 1) entries blocks

def checkPositionMapCoveredByLiveBlocks
    (positionMap : List (Option Nat))
    (blocks : List CodecBlock) : Bool :=
  checkPositionMapCoveredFromSlot 0 positionMap blocks

def decodePathStashPagesBoundedExact?
    (keyBytes valueBytes directoryPageBytes stashPageCount
      capacity leafCount stashBound : Nat)
    (pages : List (List Nat)) : Option (List CodecBlock) :=
  match
      decodePathStashPagesExact?
        true keyBytes valueBytes directoryPageBytes stashPageCount pages with
  | some blocks =>
      if liveBlockCount blocks ≤ stashBound ∧
          checkPathBlocksLiveWithinBounds capacity leafCount blocks = true then
        some blocks
      else
        none
  | none => none

def decodePathStashPagesPositionMapBoundedExact?
    (keyBytes valueBytes directoryPageBytes stashPageCount
      capacity leafCount stashBound : Nat)
    (positionMap : List (Option Nat))
    (pages : List (List Nat)) : Option (List CodecBlock) :=
  match
      decodePathStashPagesBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound pages with
  | some blocks =>
      if checkPathBlocksPositionMapAgreement positionMap blocks = true then
        some blocks
      else
        none
  | none => none

def decodePathStashPagesUniquePositionMapBoundedExact?
    (keyBytes valueBytes directoryPageBytes stashPageCount
      capacity leafCount stashBound : Nat)
    (positionMap : List (Option Nat))
    (pages : List (List Nat)) : Option (List CodecBlock) :=
  match
      decodePathStashPagesPositionMapBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound positionMap pages with
  | some blocks =>
      if checkPathBlocksNoDuplicateLiveSlots blocks = true then
        some blocks
      else
        none
  | none => none

def decodeBucketExact?
    (isPath : Bool)
    (blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat)
    (bytes : List Nat) : Option DecodedBucketPayload :=
  if bytes.length =
      codecBucketBytes isPath blocksPerBucket keyBytes valueBytes then
    let afterAccessCounter := bytes.drop slotIndexBytes
    let bucketIndexField := afterAccessCounter.take slotIndexBytes
    let afterBucketIndex := afterAccessCounter.drop slotIndexBytes
    let liveEntryCountField := afterBucketIndex.take slotIndexBytes
    let blockPayload := afterBucketIndex.drop slotIndexBytes
    match
        decodeExactBlocks? isPath keyBytes valueBytes
          blocksPerBucket blockPayload with
    | none => none
    | some blocks =>
        let payload : DecodedBucketPayload :=
          { bucketIndex := decodeNatField bucketIndexField
          , liveEntryCount := decodeNatField liveEntryCountField
          , blocks
          }
        if payload.Accepted expectedBucketIndex blocksPerBucket then
          some payload
        else
          none
  else
    none

def decodePathBucketBoundedExact?
    (blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat)
    (bytes : List Nat) : Option DecodedBucketPayload :=
  match
      decodeBucketExact?
        true blocksPerBucket keyBytes valueBytes expectedBucketIndex bytes with
  | some payload =>
      if checkPathBlocksLiveWithinBounds
          capacity leafCount payload.blocks = true then
        some payload
      else
        none
  | none => none

def decodePathBucketPathBoundedExact?
    (blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat)
    (bytes : List Nat) : Option DecodedBucketPayload :=
  match
      decodePathBucketBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes with
  | some payload =>
      if checkPathBlocksLiveOnBucketPath
          leafCount expectedBucketIndex payload.blocks = true then
        some payload
      else
        none
  | none => none

def decodePathBucketPositionMapBoundedExact?
    (blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat)
    (positionMap : List (Option Nat))
    (bytes : List Nat) : Option DecodedBucketPayload :=
  match
      decodePathBucketPathBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes with
  | some payload =>
      if checkPathBlocksPositionMapAgreement positionMap payload.blocks = true then
        some payload
      else
        none
  | none => none

def decodePathBucketUniquePositionMapBoundedExact?
    (blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat)
    (positionMap : List (Option Nat))
    (bytes : List Nat) : Option DecodedBucketPayload :=
  match
      decodePathBucketPositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMap bytes with
  | some payload =>
      if checkPathBlocksNoDuplicateLiveSlots payload.blocks = true then
        some payload
      else
        none
  | none => none

def encodeBlocks (isPath : Bool) : List CodecBlock → List Nat
  | [] => []
  | block :: blocks => encodeBlock isPath block ++ encodeBlocks isPath blocks

def encodeBucket (isPath : Bool) (bucket : CodecBucket) : List Nat :=
  bucket.accessCounterField ++
    bucket.bucketIndexField ++
    bucket.liveEntryCountField ++
    encodeBlocks isPath bucket.blocks

def zeroPadTo (len : Nat) (bytes : List Nat) : List Nat :=
  bytes ++ List.replicate (len - bytes.length) 0

def encodePathPositionMapPageBytes
    (directoryPageBytes : Nat)
    (positionMapPrefixBytes : List Nat) : List Nat :=
  zeroPadTo directoryPageBytes positionMapPrefixBytes

def encodePositionMapEntryFields : List (List Nat) → List Nat
  | [] => []
  | field :: fields => field ++ encodePositionMapEntryFields fields

def PositionMapEntryFieldsEncode
    (leafCount : Nat) :
    List (List Nat) → List (Option Nat) → Prop
  | [], [] => True
  | field :: fields, entry :: entries =>
      field.length = leafLabelBytes ∧
        decodePositionMapLeaf? leafCount field = some entry ∧
        PositionMapEntryFieldsEncode leafCount fields entries
  | _, _ => False

def encodePathStashPageBytes
    (directoryPageBytes : Nat)
    (stashBlockBytes : List Nat) : List Nat :=
  zeroPadTo directoryPageBytes stashBlockBytes

def encodePathPositionMapPagesBytes
    (directoryPageBytes : Nat) :
    List (List (List Nat)) → List (List Nat)
  | [] => []
  | fields :: pages =>
      encodePathPositionMapPageBytes directoryPageBytes
        (encodePositionMapEntryFields fields) ::
        encodePathPositionMapPagesBytes directoryPageBytes pages

def flattenPositionMapPages :
    List (List (Option Nat)) → List (Option Nat)
  | [] => []
  | entries :: pages => entries ++ flattenPositionMapPages pages

def PositionMapPageEntryFieldsEncode
    (leafCount : Nat) :
    List (List (List Nat)) → List (List (Option Nat)) → Prop
  | [], [] => True
  | fields :: fieldPages, entries :: entryPages =>
      PositionMapEntryFieldsEncode leafCount fields entries ∧
        entries.length = directoryPageEntries ∧
        PositionMapPageEntryFieldsEncode leafCount fieldPages entryPages
  | _, _ => False

def encodePathStashPagesBytes
    (directoryPageBytes : Nat) :
    List (List CodecBlock) → List (List Nat)
  | [] => []
  | blocks :: pages =>
      encodePathStashPageBytes directoryPageBytes
        (encodeBlocks true blocks) ::
        encodePathStashPagesBytes directoryPageBytes pages

def flattenStashPages :
    List (List CodecBlock) → List CodecBlock
  | [] => []
  | blocks :: pages => blocks ++ flattenStashPages pages

def PathStashPageBlocksValid
    (keyBytes valueBytes : Nat) :
    List (List CodecBlock) → Prop
  | [] => True
  | blocks :: pages =>
      blocks.length = directoryPageEntries ∧
        (∀ block, block ∈ blocks →
          block.ValidShape true keyBytes valueBytes) ∧
        PathStashPageBlocksValid keyBytes valueBytes pages

theorem surrogateBlockBytes_public_formula
    (keyBytes valueBytes : Nat) :
    surrogateBlockBytes keyBytes valueBytes =
      occupancyTagBytes + keyBytes + valueBytes := by
  rfl

theorem pathBlockBytes_public_formula
    (keyBytes valueBytes : Nat) :
    pathBlockBytes keyBytes valueBytes =
      occupancyTagBytes + slotIndexBytes + leafLabelBytes + keyBytes + valueBytes := by
  rfl

theorem bucketBytes_public_formula
    (blocksPerBucket blockBytes : Nat) :
    bucketBytes blocksPerBucket blockBytes =
      oramBucketHeaderBytes + blocksPerBucket * blockBytes := by
  rfl

theorem directoryPageBytes_public_formula
    (blockBytes : Nat) :
    directoryPageBytes blockBytes = directoryPageEntries * blockBytes := by
  rfl

def publicCountGuard? (expected actual : Nat) : Option Unit :=
  if actual = expected then some () else none

theorem publicCountGuard?_acceptsExact
    (expected : Nat) :
    publicCountGuard? expected expected = some () := by
  simp [publicCountGuard?]

theorem publicCountGuard?_rejectsMismatch
    {expected actual : Nat}
    (hCount : actual ≠ expected) :
    publicCountGuard? expected actual = none := by
  simp [publicCountGuard?, hCount]

theorem counterFieldBytes_matchesSlotIndexBytes :
    counterFieldBytes = slotIndexBytes := by
  rfl

theorem encodeNatField_length
    (width value : Nat) :
    (encodeNatField width value).length = width := by
  simp [encodeNatField]

theorem encodeNatField_validBytes
    (width value : Nat) :
    ValidByteField (encodeNatField width value) := by
  intro byte hMem
  unfold encodeNatField at hMem
  simp only [List.mem_map, List.mem_range] at hMem
  rcases hMem with ⟨index, _hIndex, hByte⟩
  rw [← hByte]
  exact Nat.mod_lt _ (by decide : 0 < 256)

theorem encodeCounterField_length
    (counter : Nat) :
    (encodeCounterField counter).length = counterFieldBytes := by
  simp [encodeCounterField, encodeNatField_length]

theorem encodeCounterField_validBytes
    (counter : Nat) :
    ValidByteField (encodeCounterField counter) := by
  exact encodeNatField_validBytes counterFieldBytes counter

theorem decodeCounterExact_encodeCounterField
    (counter : Nat) :
    decodeCounterExact? (encodeCounterField counter) =
      some (decodeNatField (encodeCounterField counter)) := by
  unfold decodeCounterExact?
  simp [encodeCounterField_length]

theorem decodeCounterExact_some_length
    {bytes : List Nat}
    {counter : Nat}
    (hDecode : decodeCounterExact? bytes = some counter) :
    bytes.length = counterFieldBytes := by
  unfold decodeCounterExact? at hDecode
  split at hDecode
  · rename_i hLen
    exact hLen
  · contradiction

theorem decodeCounterExact_some_value
    {bytes : List Nat}
    {counter : Nat}
    (hDecode : decodeCounterExact? bytes = some counter) :
    counter = decodeNatField bytes := by
  unfold decodeCounterExact? at hDecode
  split at hDecode
  · cases hDecode
    rfl
  · contradiction

theorem decodeCounterExact_some_accepted
    {bytes : List Nat}
    {counter : Nat}
    (hDecode : decodeCounterExact? bytes = some counter)
    (hBytes : ValidByteField bytes) :
    CounterDecodeAccepted bytes := by
  exact ⟨decodeCounterExact_some_length hDecode, hBytes⟩

theorem encodeCounterField_accepted
    (counter : Nat) :
    CounterDecodeAccepted (encodeCounterField counter) := by
  exact
    ⟨encodeCounterField_length counter,
      encodeCounterField_validBytes counter⟩

theorem pathPositionMapPages_positive
    (capacity : Nat) :
    0 < pathPositionMapPages capacity := by
  unfold pathPositionMapPages directoryPageEntries
  apply Nat.div_pos
  · have hMax : 1 ≤ max capacity 1 := Nat.le_max_right capacity 1
    omega
  · decide

theorem pathPositionMapPages_covers_capacity
    (capacity : Nat) :
    capacity ≤ pathPositionMapPages capacity * directoryPageEntries := by
  unfold pathPositionMapPages directoryPageEntries
  let pageCount := (max capacity 1 + 8 - 1) / 8
  have hDivUpper : max capacity 1 + 8 - 1 ≤ 8 * pageCount + (8 - 1) := by
    have hSelf : pageCount ≤ pageCount := Nat.le_refl pageCount
    exact (Nat.div_le_iff_le_mul_add_pred (by decide : 0 < 8)).mp hSelf
  have hMax : capacity ≤ max capacity 1 := Nat.le_max_left capacity 1
  omega

theorem pathMetadataPageSplit_exact
    {metadataPages capacity : Nat}
    (hPages : pathPositionMapPages capacity ≤ metadataPages) :
    pathPositionMapPages capacity + pathStashPages metadataPages capacity =
      metadataPages := by
  unfold pathStashPages
  exact Nat.add_sub_of_le hPages

theorem codecBucketHeaderBytes_matchesRuntimeHeader :
    codecBucketHeaderBytes = oramBucketHeaderBytes := by
  unfold codecBucketHeaderBytes slotIndexBytes oramBucketHeaderBytes
  rfl

theorem codecBlockBytes_surrogate_matchesFormula
    (keyBytes valueBytes : Nat) :
    codecBlockBytes false keyBytes valueBytes =
      surrogateBlockBytes keyBytes valueBytes := by
  simp [codecBlockBytes, codecPathFieldBytes, surrogateBlockBytes,
    occupancyTagBytes]

theorem codecBlockBytes_path_matchesFormula
    (keyBytes valueBytes : Nat) :
    codecBlockBytes true keyBytes valueBytes =
      pathBlockBytes keyBytes valueBytes := by
  simp [codecBlockBytes, codecPathFieldBytes, pathBlockBytes,
    occupancyTagBytes, slotIndexBytes, leafLabelBytes]

theorem codecBucketBytes_matchesRuntimeBucketBytes
    (isPath : Bool)
    (blocksPerBucket keyBytes valueBytes : Nat) :
    codecBucketBytes isPath blocksPerBucket keyBytes valueBytes =
      bucketBytes blocksPerBucket
        (codecBlockBytes isPath keyBytes valueBytes) := by
  unfold codecBucketBytes bucketBytes
  rw [codecBucketHeaderBytes_matchesRuntimeHeader]

theorem liveBlockCount_le_length
    (blocks : List CodecBlock) :
    liveBlockCount blocks ≤ blocks.length := by
  induction blocks with
  | nil =>
      simp [liveBlockCount]
  | cons block blocks ih =>
      by_cases h : block.occupiedTag = 1
      · simp [liveBlockCount, h]
        omega
      · simp [liveBlockCount, h]
        omega

theorem liveBlockCount_append
    (left right : List CodecBlock) :
    liveBlockCount (left ++ right) =
      liveBlockCount left + liveBlockCount right := by
  induction left with
  | nil =>
      simp [liveBlockCount]
  | cons block left ih =>
      by_cases h : block.occupiedTag = 1
      · simp [liveBlockCount, h, ih]
        omega
      · simp [liveBlockCount, h, ih]

theorem decodedBucketPayload_accepted_of_exact_live_count
    {expectedBucketIndex blocksPerBucket : Nat}
    {payload : DecodedBucketPayload}
    (hIndex : payload.bucketIndex = expectedBucketIndex)
    (hBlocks : payload.blocks.length = blocksPerBucket)
    (hLive :
      liveBlockCount payload.blocks = payload.liveEntryCount) :
    payload.Accepted expectedBucketIndex blocksPerBucket := by
  refine ⟨hIndex, hBlocks, ?_, hLive⟩
  rw [← hLive, ← hBlocks]
  exact liveBlockCount_le_length payload.blocks

theorem positionMapDecodeAccepted_of_exact_capacity_and_leaf_bound
    {capacity leafCount : Nat}
    {positionMap : List (Option Nat)}
    (hCapacity : positionMap.length = capacity)
    (hLeaves : PositionMapLeafBounded leafCount positionMap) :
    PositionMapDecodeAccepted capacity leafCount positionMap := by
  exact ⟨hCapacity, hLeaves⟩

theorem decodePositionMapLeaf_some_bounded
    {leafCount : Nat}
    {field : List Nat}
    {entry : Option Nat}
    (hDecode : decodePositionMapLeaf? leafCount field = some entry) :
    PositionMapEntryLeafBounded leafCount entry := by
  unfold decodePositionMapLeaf? at hDecode
  dsimp at hDecode
  split at hDecode
  · cases hDecode
    simp [PositionMapEntryLeafBounded]
  · split at hDecode
    · rename_i hLeaf
      cases hDecode
      simpa [PositionMapEntryLeafBounded] using hLeaf
    · contradiction

theorem positionMapLeafBounded_cons
    {leafCount : Nat}
    {entry : Option Nat}
    {entries : List (Option Nat)}
    (hEntry : PositionMapEntryLeafBounded leafCount entry)
    (hEntries : PositionMapLeafBounded leafCount entries) :
    PositionMapLeafBounded leafCount (entry :: entries) := by
  intro leaf hMem
  simp at hMem
  rcases hMem with hHead | hTail
  · cases entry with
    | none =>
        contradiction
    | some entryLeaf =>
        cases hHead
        exact hEntry
  · exact hEntries leaf hTail

theorem positionMapLeafBounded_append
    {leafCount : Nat}
    {left right : List (Option Nat)}
    (hLeft : PositionMapLeafBounded leafCount left)
    (hRight : PositionMapLeafBounded leafCount right) :
    PositionMapLeafBounded leafCount (left ++ right) := by
  intro leaf hMem
  simp at hMem
  rcases hMem with hLeftMem | hRightMem
  · exact hLeft leaf hLeftMem
  · exact hRight leaf hRightMem

theorem positionMapLeafBounded_take
    {leafCount n : Nat}
    {entries : List (Option Nat)}
    (hEntries : PositionMapLeafBounded leafCount entries) :
    PositionMapLeafBounded leafCount (entries.take n) := by
  intro leaf hMem
  exact hEntries leaf (List.mem_of_mem_take hMem)

theorem decodePositionMapEntriesExact_some_shape
    {leafCount count : Nat}
    {bytes : List Nat}
    {entries : List (Option Nat)}
    (hDecode :
      decodePositionMapEntriesExact? leafCount count bytes =
        some entries) :
    entries.length = count ∧
      PositionMapLeafBounded leafCount entries := by
  induction count generalizing bytes entries with
  | zero =>
      unfold decodePositionMapEntriesExact? at hDecode
      split at hDecode
      · cases hDecode
        simp [PositionMapLeafBounded]
      · contradiction
  | succ count ih =>
      unfold decodePositionMapEntriesExact? at hDecode
      cases hLeaf :
          decodePositionMapLeaf? leafCount (bytes.take leafLabelBytes) with
      | none =>
          simp [hLeaf] at hDecode
      | some entry =>
          cases hTail :
              decodePositionMapEntriesExact? leafCount count
                (bytes.drop leafLabelBytes) with
          | none =>
              simp [hLeaf, hTail] at hDecode
          | some tailEntries =>
              simp [hLeaf, hTail] at hDecode
              cases hDecode
              have hEntryBound :
                  PositionMapEntryLeafBounded leafCount entry :=
                decodePositionMapLeaf_some_bounded hLeaf
              have hTailShape := ih hTail
              constructor
              · simp [hTailShape.1]
              · exact
                  positionMapLeafBounded_cons
                    hEntryBound hTailShape.2

theorem decodePathPositionMapPageExact_some_length_and_accepted
    {leafCount directoryPageBytes : Nat}
    {bytes : List Nat}
    {page : DecodedPathPositionMapPage}
    (hDecode :
      decodePathPositionMapPageExact? leafCount directoryPageBytes bytes =
        some page) :
    bytes.length = directoryPageBytes ∧
      page.Accepted leafCount directoryPageBytes := by
  unfold decodePathPositionMapPageExact? at hDecode
  split at hDecode
  · rename_i hShape
    rcases hShape with ⟨hLen, hEntryBytes⟩
    cases hEntries :
        decodePositionMapEntriesExact? leafCount directoryPageEntries
          (bytes.take pathPositionMapEntryBytes) with
    | none =>
        simp [hEntries] at hDecode
    | some entries =>
        simp [hEntries] at hDecode
        cases hDecode
        have hEntriesShape :=
          decodePositionMapEntriesExact_some_shape hEntries
        refine ⟨hLen, ?_⟩
        unfold DecodedPathPositionMapPage.Accepted
        constructor
        · exact hEntriesShape.1
        constructor
        · exact hEntriesShape.2
        · simp [hLen, List.length_drop]
  · contradiction

theorem decodePathPositionMapPageExact?_rejectsLengthMismatch
    {leafCount directoryPageBytes : Nat}
    {bytes : List Nat}
    (hLen : bytes.length ≠ directoryPageBytes) :
    decodePathPositionMapPageExact?
        leafCount directoryPageBytes bytes = none := by
  unfold decodePathPositionMapPageExact?
  have hShape :
      ¬(bytes.length = directoryPageBytes ∧
        pathPositionMapEntryBytes ≤ directoryPageBytes) := by
    intro h
    exact hLen h.1
  simp [hShape]

theorem decodePathPositionMapPagesAll_some_shape
    {leafCount directoryPageBytes : Nat}
    {pages : List (List Nat)}
    {entries : List (Option Nat)}
    (hDecode :
      decodePathPositionMapPagesAll?
          leafCount directoryPageBytes pages = some entries) :
    entries.length = pages.length * directoryPageEntries ∧
      PositionMapLeafBounded leafCount entries := by
  induction pages generalizing entries with
  | nil =>
      unfold decodePathPositionMapPagesAll? at hDecode
      cases hDecode
      simp [PositionMapLeafBounded]
  | cons pageBytes pages ih =>
      unfold decodePathPositionMapPagesAll? at hDecode
      cases hPage :
          decodePathPositionMapPageExact?
            leafCount directoryPageBytes pageBytes with
      | none =>
          simp [hPage] at hDecode
      | some page =>
          cases hTail :
              decodePathPositionMapPagesAll?
                leafCount directoryPageBytes pages with
          | none =>
              simp [hPage, hTail] at hDecode
          | some tailEntries =>
              simp [hPage, hTail] at hDecode
              cases hDecode
              have hPageAccepted :=
                (decodePathPositionMapPageExact_some_length_and_accepted hPage).2
              have hTailShape := ih hTail
              unfold DecodedPathPositionMapPage.Accepted at hPageAccepted
              rcases hPageAccepted with ⟨hPageEntriesLen, hPageLeaves, _hPadding⟩
              constructor
              · simp [hPageEntriesLen, hTailShape.1, Nat.succ_mul]
                omega
              · exact
                  positionMapLeafBounded_append
                    hPageLeaves hTailShape.2

theorem decodePathPositionMapPagesExact_some_accepted
    {leafCount directoryPageBytes capacity : Nat}
    {pages : List (List Nat)}
    {positionMap : List (Option Nat)}
    (hDecode :
      decodePathPositionMapPagesExact?
          leafCount directoryPageBytes capacity pages =
        some positionMap) :
    pages.length = pathPositionMapPages capacity ∧
      PositionMapDecodeAccepted capacity leafCount positionMap := by
  unfold decodePathPositionMapPagesExact? at hDecode
  split at hDecode
  · rename_i hPageCount
    cases hAll :
        decodePathPositionMapPagesAll?
          leafCount directoryPageBytes pages with
    | none =>
        simp [hAll] at hDecode
    | some entries =>
        by_cases hCapacity : capacity ≤ entries.length
        · simp [hAll, hCapacity] at hDecode
          cases hDecode
          have hAllShape :=
            decodePathPositionMapPagesAll_some_shape hAll
          refine ⟨hPageCount, ?_⟩
          unfold PositionMapDecodeAccepted
          constructor
          · simp [hCapacity]
          · exact positionMapLeafBounded_take hAllShape.2
        · simp [hAll, hCapacity] at hDecode
  · contradiction

theorem decodePathPositionMapPagesExact?_rejectsPageCountMismatch
    {leafCount directoryPageBytes capacity : Nat}
    {pages : List (List Nat)}
    (hCount : pages.length ≠ pathPositionMapPages capacity) :
    decodePathPositionMapPagesExact?
        leafCount directoryPageBytes capacity pages = none := by
  unfold decodePathPositionMapPagesExact?
  simp [hCount]

theorem decodeExactBlocks_some_block_count
    {isPath : Bool}
    {keyBytes valueBytes count : Nat}
    {bytes : List Nat}
    {blocks : List CodecBlock}
    (hDecode :
      decodeExactBlocks? isPath keyBytes valueBytes count bytes =
        some blocks) :
    blocks.length = count := by
  induction count generalizing bytes blocks with
  | zero =>
      unfold decodeExactBlocks? at hDecode
      split at hDecode
      · cases hDecode
        rfl
      · contradiction
  | succ count ih =>
      unfold decodeExactBlocks? at hDecode
      cases hBlock :
          decodeBlockExact? isPath keyBytes valueBytes
            (bytes.take (codecBlockBytes isPath keyBytes valueBytes)) with
      | none =>
          simp [hBlock] at hDecode
      | some block =>
          cases hTail :
              decodeExactBlocks? isPath keyBytes valueBytes count
                (bytes.drop
                  (codecBlockBytes isPath keyBytes valueBytes)) with
          | none =>
              simp [hBlock, hTail] at hDecode
          | some tailBlocks =>
              simp [hBlock, hTail] at hDecode
              cases hDecode
              simp [ih hTail]

theorem decodePathStashPageExact_some_length_and_accepted
    {isPath : Bool}
    {keyBytes valueBytes directoryPageBytes : Nat}
    {bytes : List Nat}
    {page : DecodedPathStashPage}
    (hDecode :
      decodePathStashPageExact?
          isPath keyBytes valueBytes directoryPageBytes bytes =
        some page) :
    bytes.length = directoryPageBytes ∧
      page.Accepted directoryPageEntries := by
  unfold decodePathStashPageExact? at hDecode
  split at hDecode
  · rename_i hShape
    rcases hShape with ⟨hLen, _hDirectoryLen⟩
    cases hBlocks :
        decodeExactBlocks? isPath keyBytes valueBytes
          directoryPageEntries bytes with
    | none =>
        simp [hBlocks] at hDecode
    | some blocks =>
        simp [hBlocks] at hDecode
        cases hDecode
        refine ⟨hLen, ?_⟩
        unfold DecodedPathStashPage.Accepted
        have hBlockCount :=
          decodeExactBlocks_some_block_count hBlocks
        constructor
        · exact hBlockCount
        · rw [← hBlockCount]
          exact liveBlockCount_le_length blocks
  · contradiction

theorem decodePathStashPageExact?_rejectsLengthMismatch
    {isPath : Bool}
    {keyBytes valueBytes directoryPageBytes : Nat}
    {bytes : List Nat}
    (hLen : bytes.length ≠ directoryPageBytes) :
    decodePathStashPageExact?
        isPath keyBytes valueBytes directoryPageBytes bytes = none := by
  unfold decodePathStashPageExact?
  have hShape :
      ¬(bytes.length = directoryPageBytes ∧
        directoryPageBytes =
          directoryPageEntries *
            codecBlockBytes isPath keyBytes valueBytes) := by
    intro h
    exact hLen h.1
  simp [hShape]

theorem encodeBlock_length
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {block : CodecBlock}
    (hBlock : block.ValidShape isPath keyBytes valueBytes) :
    (encodeBlock isPath block).length =
      codecBlockBytes isPath keyBytes valueBytes := by
  rcases hBlock with ⟨_hTag, hPath, hKey, hValue⟩
  cases isPath
  · rcases hPath with ⟨_, _⟩
    simp [encodeBlock, codecBlockBytes, codecPathFieldBytes, hKey, hValue,
      occupancyTagBytes]
    omega
  · rcases hPath with ⟨hSlot, hLeaf⟩
    simp [encodeBlock, codecBlockBytes, codecPathFieldBytes, hSlot,
      hLeaf, hKey, hValue, occupancyTagBytes,
      slotIndexBytes, leafLabelBytes]
    omega

theorem decodeBlock_encodeBlock
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {block : CodecBlock}
    (hBlock : block.ValidShape isPath keyBytes valueBytes) :
    decodeBlock? isPath keyBytes valueBytes (encodeBlock isPath block) =
      some block := by
  cases block with
  | mk occupiedTag slotIndexField leafLabelField keyField valueField =>
  simp [CodecBlock.ValidShape] at hBlock
  rcases hBlock with ⟨hTag, hPath, hKey, hValue⟩
  cases isPath
  · rcases hPath with ⟨hSlot, hLeaf⟩
    have hValueTake :
        valueField.take valueBytes = valueField := by
      apply List.take_of_length_le
      omega
    rcases hTag with hTag | hTag
    · subst occupiedTag
      simp [decodeBlock?, encodeBlock, hSlot, hLeaf, hKey, hValue,
        hValueTake, occupancyTagBytes]
    · subst occupiedTag
      simp [decodeBlock?, encodeBlock, hSlot, hLeaf, hKey, hValue,
        hValueTake, occupancyTagBytes]
  · rcases hPath with ⟨hSlot, hLeaf⟩
    have hValueTake :
        valueField.take valueBytes = valueField := by
      apply List.take_of_length_le
      omega
    rcases hTag with hTag | hTag
    · subst occupiedTag
      simp [decodeBlock?, encodeBlock, hSlot, hLeaf, hKey, hValue,
        hValueTake, occupancyTagBytes, slotIndexBytes, leafLabelBytes]
    · subst occupiedTag
      simp [decodeBlock?, encodeBlock, hSlot, hLeaf, hKey, hValue,
        hValueTake, occupancyTagBytes, slotIndexBytes, leafLabelBytes]

theorem decodeBlockExact_encodeBlock
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {block : CodecBlock}
    (hBlock : block.ValidShape isPath keyBytes valueBytes) :
    decodeBlockExact? isPath keyBytes valueBytes
        (encodeBlock isPath block) =
      some block := by
  unfold decodeBlockExact?
  simp [encodeBlock_length hBlock, decodeBlock_encodeBlock hBlock]

theorem decodeBlockExact_some_exact_length
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {bytes : List Nat}
    {block : CodecBlock}
    (hDecode :
      decodeBlockExact? isPath keyBytes valueBytes bytes = some block) :
    bytes.length = codecBlockBytes isPath keyBytes valueBytes := by
  unfold decodeBlockExact? at hDecode
  split at hDecode
  · assumption
  · contradiction

theorem decodeBlockExact_some_validShape
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {bytes : List Nat}
    {block : CodecBlock}
    (hDecode :
      decodeBlockExact? isPath keyBytes valueBytes bytes = some block) :
    block.ValidShape isPath keyBytes valueBytes := by
  unfold decodeBlockExact? at hDecode
  split at hDecode
  · rename_i hLen
    cases isPath
    · unfold decodeBlock? at hDecode
      simp [codecBlockBytes, codecPathFieldBytes, occupancyTagBytes] at hLen
      simp [occupancyTagBytes] at hDecode
      rcases hDecode with ⟨hTag, hBlockEq⟩
      rw [← hBlockEq]
      simp [CodecBlock.ValidShape, hTag] at hLen ⊢
      omega
    · unfold decodeBlock? at hDecode
      simp [codecBlockBytes, codecPathFieldBytes, occupancyTagBytes,
        slotIndexBytes, leafLabelBytes] at hLen
      simp [occupancyTagBytes, slotIndexBytes, leafLabelBytes] at hDecode
      rcases hDecode with ⟨hTag, hBlockEq⟩
      rw [← hBlockEq]
      simp [CodecBlock.ValidShape, hTag, slotIndexBytes, leafLabelBytes] at hLen ⊢
      omega
  · contradiction

theorem decodeExactBlocks_some_validShapes
    {isPath : Bool}
    {keyBytes valueBytes count : Nat}
    {bytes : List Nat}
    {blocks : List CodecBlock}
    (hDecode :
      decodeExactBlocks? isPath keyBytes valueBytes count bytes =
        some blocks) :
    ∀ block, block ∈ blocks →
      block.ValidShape isPath keyBytes valueBytes := by
  induction count generalizing bytes blocks with
  | zero =>
      unfold decodeExactBlocks? at hDecode
      split at hDecode
      · cases hDecode
        simp
      · contradiction
  | succ count ih =>
      unfold decodeExactBlocks? at hDecode
      cases hBlock :
          decodeBlockExact? isPath keyBytes valueBytes
            (bytes.take (codecBlockBytes isPath keyBytes valueBytes)) with
      | none =>
          simp [hBlock] at hDecode
      | some headBlock =>
          cases hTail :
              decodeExactBlocks? isPath keyBytes valueBytes count
                (bytes.drop
                  (codecBlockBytes isPath keyBytes valueBytes)) with
          | none =>
              simp [hBlock, hTail] at hDecode
          | some tailBlocks =>
              simp [hBlock, hTail] at hDecode
              cases hDecode
              intro block hMem
              simp at hMem
              rcases hMem with hHead | hTailMem
              · subst block
                exact decodeBlockExact_some_validShape hBlock
              · exact ih hTail block hTailMem

theorem decodePathStashPageExact_some_block_validShapes
    {isPath : Bool}
    {keyBytes valueBytes directoryPageBytes : Nat}
    {bytes : List Nat}
    {page : DecodedPathStashPage}
    (hDecode :
      decodePathStashPageExact?
          isPath keyBytes valueBytes directoryPageBytes bytes =
        some page) :
    ∀ block, block ∈ page.blocks →
      block.ValidShape isPath keyBytes valueBytes := by
  unfold decodePathStashPageExact? at hDecode
  split at hDecode
  · cases hBlocks :
        decodeExactBlocks? isPath keyBytes valueBytes
          directoryPageEntries bytes with
    | none =>
        simp [hBlocks] at hDecode
    | some blocks =>
        simp [hBlocks] at hDecode
        cases hDecode
        exact decodeExactBlocks_some_validShapes hBlocks
  · contradiction

theorem decodePathStashPagesAll_some_shape
    {isPath : Bool}
    {keyBytes valueBytes directoryPageBytes : Nat}
    {pages : List (List Nat)}
    {blocks : List CodecBlock}
    (hDecode :
      decodePathStashPagesAll?
          isPath keyBytes valueBytes directoryPageBytes pages =
        some blocks) :
    blocks.length = pages.length * directoryPageEntries ∧
      liveBlockCount blocks ≤ pages.length * directoryPageEntries ∧
      ∀ block, block ∈ blocks →
        block.ValidShape isPath keyBytes valueBytes := by
  induction pages generalizing blocks with
  | nil =>
      unfold decodePathStashPagesAll? at hDecode
      cases hDecode
      simp [liveBlockCount]
  | cons pageBytes pages ih =>
      unfold decodePathStashPagesAll? at hDecode
      cases hPage :
          decodePathStashPageExact?
            isPath keyBytes valueBytes directoryPageBytes pageBytes with
      | none =>
          simp [hPage] at hDecode
      | some page =>
          cases hTail :
              decodePathStashPagesAll?
                isPath keyBytes valueBytes directoryPageBytes pages with
          | none =>
              simp [hPage, hTail] at hDecode
          | some tailBlocks =>
              simp [hPage, hTail] at hDecode
              cases hDecode
              have hPageAccepted :=
                (decodePathStashPageExact_some_length_and_accepted hPage).2
              have hPageValid :=
                decodePathStashPageExact_some_block_validShapes hPage
              have hTailShape := ih hTail
              unfold DecodedPathStashPage.Accepted at hPageAccepted
              rcases hPageAccepted with ⟨hPageLen, hPageLive⟩
              refine ⟨?_, ?_, ?_⟩
              · simp [hPageLen, hTailShape.1, Nat.succ_mul]
                omega
              · rw [liveBlockCount_append]
                simp [Nat.succ_mul]
                omega
              · intro block hMem
                simp at hMem
                rcases hMem with hPageMem | hTailMem
                · exact hPageValid block hPageMem
                · exact hTailShape.2.2 block hTailMem

theorem decodePathStashPagesExact_some_shape
    {isPath : Bool}
    {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
    {pages : List (List Nat)}
    {blocks : List CodecBlock}
    (hDecode :
      decodePathStashPagesExact?
          isPath keyBytes valueBytes directoryPageBytes stashPageCount pages =
        some blocks) :
    pages.length = stashPageCount ∧
      blocks.length = stashPageCount * directoryPageEntries ∧
      liveBlockCount blocks ≤ stashPageCount * directoryPageEntries ∧
      ∀ block, block ∈ blocks →
        block.ValidShape isPath keyBytes valueBytes := by
  unfold decodePathStashPagesExact? at hDecode
  split at hDecode
  · rename_i hPageCount
    have hAllShape :=
      decodePathStashPagesAll_some_shape hDecode
    rw [hPageCount] at hAllShape
    exact ⟨hPageCount, hAllShape.1, hAllShape.2.1, hAllShape.2.2⟩
  · contradiction

theorem decodePathStashPagesExact?_rejectsPageCountMismatch
    {isPath : Bool}
    {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
    {pages : List (List Nat)}
    (hCount : pages.length ≠ stashPageCount) :
    decodePathStashPagesExact?
        isPath keyBytes valueBytes directoryPageBytes stashPageCount pages =
      none := by
  unfold decodePathStashPagesExact?
  simp [hCount]

theorem checkPathBlockLiveWithinBounds_true
    {capacity leafCount : Nat}
    {block : CodecBlock}
    (hCheck :
      checkPathBlockLiveWithinBounds capacity leafCount block = true) :
    block.LivePathWithinBounds capacity leafCount := by
  unfold checkPathBlockLiveWithinBounds CodecBlock.LivePathWithinBounds at *
  by_cases hOcc : block.occupiedTag = 1
  · simp [hOcc] at hCheck
    intro _hLive
    exact hCheck
  · intro hLive
    exact False.elim (hOcc hLive)

theorem checkPathBlocksLiveWithinBounds_true
    {capacity leafCount : Nat}
    {blocks : List CodecBlock}
    (hCheck :
      checkPathBlocksLiveWithinBounds capacity leafCount blocks = true) :
    ∀ block, block ∈ blocks →
      block.LivePathWithinBounds capacity leafCount := by
  induction blocks with
  | nil =>
      intro block hMem
      simp at hMem
  | cons head tail ih =>
      unfold checkPathBlocksLiveWithinBounds at hCheck
      simp at hCheck
      rcases hCheck with ⟨hHead, hTail⟩
      intro block hMem
      simp at hMem
      rcases hMem with hEq | hTailMem
      · subst block
        exact checkPathBlockLiveWithinBounds_true hHead
      · exact ih hTail block hTailMem

theorem checkPathBlockLiveOnBucketPath_true
    {leafCount bucketIndex : Nat}
    {block : CodecBlock}
    (hCheck :
      checkPathBlockLiveOnBucketPath leafCount bucketIndex block = true) :
    block.LiveOnBucketPath leafCount bucketIndex := by
  unfold checkPathBlockLiveOnBucketPath CodecBlock.LiveOnBucketPath at *
  by_cases hOcc : block.occupiedTag = 1
  · simp [hOcc] at hCheck
    intro _hLive
    exact hCheck
  · intro hLive
    exact False.elim (hOcc hLive)

theorem checkPathBlocksLiveOnBucketPath_true
    {leafCount bucketIndex : Nat}
    {blocks : List CodecBlock}
    (hCheck :
      checkPathBlocksLiveOnBucketPath leafCount bucketIndex blocks = true) :
    ∀ block, block ∈ blocks →
      block.LiveOnBucketPath leafCount bucketIndex := by
  induction blocks with
  | nil =>
      intro block hMem
      simp at hMem
  | cons head tail ih =>
      unfold checkPathBlocksLiveOnBucketPath at hCheck
      simp at hCheck
      rcases hCheck with ⟨hHead, hTail⟩
      intro block hMem
      simp at hMem
      rcases hMem with hEq | hTailMem
      · subst block
        exact checkPathBlockLiveOnBucketPath_true hHead
      · exact ih hTail block hTailMem

theorem checkPathBlockPositionMapAgreement_true
    {positionMap : List (Option Nat)}
    {block : CodecBlock}
    (hCheck :
      checkPathBlockPositionMapAgreement positionMap block = true) :
    block.AgreesWithPositionMap positionMap := by
  unfold checkPathBlockPositionMapAgreement
    CodecBlock.AgreesWithPositionMap at *
  by_cases hOcc : block.occupiedTag = 1
  · simp [hOcc] at hCheck
    intro _hLive
    exact hCheck
  · intro hLive
    exact False.elim (hOcc hLive)

theorem checkPathBlocksPositionMapAgreement_true
    {positionMap : List (Option Nat)}
    {blocks : List CodecBlock}
    (hCheck :
      checkPathBlocksPositionMapAgreement positionMap blocks = true) :
    ∀ block, block ∈ blocks →
      block.AgreesWithPositionMap positionMap := by
  induction blocks with
  | nil =>
      intro block hMem
      simp at hMem
  | cons head tail ih =>
      unfold checkPathBlocksPositionMapAgreement at hCheck
      simp at hCheck
      rcases hCheck with ⟨hHead, hTail⟩
      intro block hMem
      simp at hMem
      rcases hMem with hEq | hTailMem
      · subst block
        exact checkPathBlockPositionMapAgreement_true hHead
      · exact ih hTail block hTailMem

theorem checkPathBlocksNoDuplicateLiveSlotsFromSeen_true
    {seen : List Nat}
    {blocks : List CodecBlock}
    (hCheck :
      checkPathBlocksNoDuplicateLiveSlotsFromSeen seen blocks = true) :
    LiveSlotDistinctFromSeen seen blocks := by
  induction blocks generalizing seen with
  | nil =>
      simp [LiveSlotDistinctFromSeen]
  | cons head tail ih =>
      by_cases hOcc : head.occupiedTag = 1
      · simp [checkPathBlocksNoDuplicateLiveSlotsFromSeen,
          LiveSlotDistinctFromSeen, hOcc] at hCheck ⊢
        rcases hCheck with ⟨hFresh, hTail⟩
        exact ⟨hFresh, ih hTail⟩
      · simp [checkPathBlocksNoDuplicateLiveSlotsFromSeen,
          LiveSlotDistinctFromSeen, hOcc] at hCheck ⊢
        exact ih hCheck

theorem checkPathBlocksNoDuplicateLiveSlots_true
    {blocks : List CodecBlock}
    (hCheck :
      checkPathBlocksNoDuplicateLiveSlots blocks = true) :
    LiveSlotNoDuplicates blocks := by
  exact checkPathBlocksNoDuplicateLiveSlotsFromSeen_true hCheck

theorem checkLiveSlotPresent_true
    {blocks : List CodecBlock}
    {slot : Nat}
    (hCheck : checkLiveSlotPresent blocks slot = true) :
    LiveSlotPresent blocks slot := by
  induction blocks with
  | nil =>
      simp [checkLiveSlotPresent] at hCheck
  | cons head tail ih =>
      unfold checkLiveSlotPresent at hCheck
      by_cases hHead :
          head.occupiedTag = 1 ∧
            decodeNatField head.slotIndexField = slot
      · simp [hHead] at hCheck
        exact ⟨head, by simp, hHead.1, hHead.2⟩
      · simp [hHead] at hCheck
        rcases ih hCheck with ⟨block, hMem, hOcc, hSlot⟩
        exact ⟨block, by simp [hMem], hOcc, hSlot⟩

theorem checkPositionMapCoveredFromSlot_true
    {slot : Nat}
    {positionMap : List (Option Nat)}
    {blocks : List CodecBlock}
    (hCheck :
      checkPositionMapCoveredFromSlot slot positionMap blocks = true) :
    PositionMapCoveredFromSlot slot positionMap blocks := by
  induction positionMap generalizing slot with
  | nil =>
      simp [PositionMapCoveredFromSlot]
  | cons entry entries ih =>
      cases entry with
      | none =>
          simp [checkPositionMapCoveredFromSlot,
            PositionMapCoveredFromSlot] at hCheck ⊢
          exact ih hCheck
      | some leaf =>
          simp [checkPositionMapCoveredFromSlot,
            PositionMapCoveredFromSlot] at hCheck ⊢
          exact ⟨checkLiveSlotPresent_true hCheck.1, ih hCheck.2⟩

theorem checkPositionMapCoveredByLiveBlocks_true
    {positionMap : List (Option Nat)}
    {blocks : List CodecBlock}
    (hCheck :
      checkPositionMapCoveredByLiveBlocks positionMap blocks = true) :
    PositionMapCoveredByLiveBlocks positionMap blocks := by
  exact checkPositionMapCoveredFromSlot_true hCheck

theorem decodePathStashPagesBoundedExact_some_shape
    {keyBytes valueBytes directoryPageBytes stashPageCount
      capacity leafCount stashBound : Nat}
    {pages : List (List Nat)}
    {blocks : List CodecBlock}
    (hDecode :
      decodePathStashPagesBoundedExact?
          keyBytes valueBytes directoryPageBytes stashPageCount
          capacity leafCount stashBound pages =
        some blocks) :
    pages.length = stashPageCount ∧
      blocks.length = stashPageCount * directoryPageEntries ∧
      liveBlockCount blocks ≤ stashBound ∧
      ∀ block, block ∈ blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount := by
  unfold decodePathStashPagesBoundedExact? at hDecode
  cases hBase :
      decodePathStashPagesExact?
        true keyBytes valueBytes directoryPageBytes stashPageCount pages with
  | none =>
      simp [hBase] at hDecode
  | some decodedBlocks =>
      by_cases hAccepted :
          liveBlockCount decodedBlocks ≤ stashBound ∧
            checkPathBlocksLiveWithinBounds capacity leafCount decodedBlocks =
              true
      · simp [hBase, hAccepted] at hDecode
        cases hDecode
        rcases hAccepted with ⟨hLiveBound, hBoundsCheck⟩
        have hBaseShape :=
          decodePathStashPagesExact_some_shape hBase
        have hBounds :=
          checkPathBlocksLiveWithinBounds_true hBoundsCheck
        refine ⟨hBaseShape.1, hBaseShape.2.1, hLiveBound, ?_⟩
        intro block hMem
        exact ⟨hBaseShape.2.2.2 block hMem, hBounds block hMem⟩
      · simp [hBase, hAccepted] at hDecode

theorem decodePathStashPagesPositionMapBoundedExact_some_shape
    {keyBytes valueBytes directoryPageBytes stashPageCount
      capacity leafCount stashBound : Nat}
    {positionMap : List (Option Nat)}
    {pages : List (List Nat)}
    {blocks : List CodecBlock}
    (hDecode :
      decodePathStashPagesPositionMapBoundedExact?
          keyBytes valueBytes directoryPageBytes stashPageCount
          capacity leafCount stashBound positionMap pages =
        some blocks) :
    pages.length = stashPageCount ∧
      blocks.length = stashPageCount * directoryPageEntries ∧
      liveBlockCount blocks ≤ stashBound ∧
      ∀ block, block ∈ blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount ∧
          block.AgreesWithPositionMap positionMap := by
  unfold decodePathStashPagesPositionMapBoundedExact? at hDecode
  cases hBase :
      decodePathStashPagesBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound pages with
  | none =>
      simp [hBase] at hDecode
  | some decodedBlocks =>
      by_cases hPositionMapCheck :
          checkPathBlocksPositionMapAgreement positionMap decodedBlocks =
            true
      · simp [hBase, hPositionMapCheck] at hDecode
        cases hDecode
        have hBaseShape :=
          decodePathStashPagesBoundedExact_some_shape hBase
        have hPositionMap :=
          checkPathBlocksPositionMapAgreement_true hPositionMapCheck
        refine ⟨hBaseShape.1, hBaseShape.2.1, hBaseShape.2.2.1, ?_⟩
        intro block hMem
        exact
          ⟨(hBaseShape.2.2.2 block hMem).1,
            (hBaseShape.2.2.2 block hMem).2,
            hPositionMap block hMem⟩
      · simp [hBase, hPositionMapCheck] at hDecode

theorem decodePathStashPagesUniquePositionMapBoundedExact_some_shape
    {keyBytes valueBytes directoryPageBytes stashPageCount
      capacity leafCount stashBound : Nat}
    {positionMap : List (Option Nat)}
    {pages : List (List Nat)}
    {blocks : List CodecBlock}
    (hDecode :
      decodePathStashPagesUniquePositionMapBoundedExact?
          keyBytes valueBytes directoryPageBytes stashPageCount
          capacity leafCount stashBound positionMap pages =
        some blocks) :
    pages.length = stashPageCount ∧
      blocks.length = stashPageCount * directoryPageEntries ∧
      liveBlockCount blocks ≤ stashBound ∧
      LiveSlotNoDuplicates blocks ∧
      ∀ block, block ∈ blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount ∧
          block.AgreesWithPositionMap positionMap := by
  unfold decodePathStashPagesUniquePositionMapBoundedExact? at hDecode
  cases hBase :
      decodePathStashPagesPositionMapBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound positionMap pages with
  | none =>
      simp [hBase] at hDecode
  | some decodedBlocks =>
      by_cases hNoDuplicates :
          checkPathBlocksNoDuplicateLiveSlots decodedBlocks = true
      · simp [hBase, hNoDuplicates] at hDecode
        cases hDecode
        have hBaseShape :=
          decodePathStashPagesPositionMapBoundedExact_some_shape hBase
        have hDistinct :=
          checkPathBlocksNoDuplicateLiveSlots_true hNoDuplicates
        exact
          ⟨hBaseShape.1, hBaseShape.2.1, hBaseShape.2.2.1,
            hDistinct, hBaseShape.2.2.2⟩
      · simp [hBase, hNoDuplicates] at hDecode

theorem decodeBucketExact_some_exact_length_and_accepted
    {isPath : Bool}
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodeBucketExact?
          isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
          bytes = some payload) :
    bytes.length =
        codecBucketBytes isPath blocksPerBucket keyBytes valueBytes ∧
      payload.Accepted expectedBucketIndex blocksPerBucket := by
  unfold decodeBucketExact? at hDecode
  split at hDecode
  · rename_i hLen
    dsimp at hDecode
    cases hBlocks :
        decodeExactBlocks? isPath keyBytes valueBytes
          blocksPerBucket
          (bytes.drop (slotIndexBytes + slotIndexBytes + slotIndexBytes)) with
    | none =>
        simp [hBlocks] at hDecode
    | some blocks =>
        let decodedPayload : DecodedBucketPayload :=
          { bucketIndex :=
              decodeNatField ((bytes.drop slotIndexBytes).take slotIndexBytes)
          , liveEntryCount :=
              decodeNatField
                ((bytes.drop (slotIndexBytes + slotIndexBytes)).take
                  slotIndexBytes)
          , blocks := blocks
          }
        by_cases hAccepted :
            decodedPayload.Accepted expectedBucketIndex blocksPerBucket
        · simp [hBlocks, hAccepted, decodedPayload] at hDecode
          cases hDecode
          exact ⟨hLen, hAccepted⟩
        · simp [hBlocks, hAccepted, decodedPayload] at hDecode
  · contradiction

theorem decodeBucketExact_some_exact_length
    {isPath : Bool}
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodeBucketExact?
          isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
          bytes = some payload) :
    bytes.length =
      codecBucketBytes isPath blocksPerBucket keyBytes valueBytes := by
  exact
    (decodeBucketExact_some_exact_length_and_accepted hDecode).1

theorem decodeBucketExact_some_accepted
    {isPath : Bool}
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodeBucketExact?
          isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
          bytes = some payload) :
    payload.Accepted expectedBucketIndex blocksPerBucket := by
  exact
    (decodeBucketExact_some_exact_length_and_accepted hDecode).2

theorem decodeBucketExact_some_block_validShapes
    {isPath : Bool}
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodeBucketExact?
          isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
          bytes = some payload) :
    ∀ block, block ∈ payload.blocks →
      block.ValidShape isPath keyBytes valueBytes := by
  unfold decodeBucketExact? at hDecode
  split at hDecode
  · dsimp at hDecode
    cases hBlocks :
        decodeExactBlocks? isPath keyBytes valueBytes
          blocksPerBucket
          (bytes.drop (slotIndexBytes + slotIndexBytes + slotIndexBytes)) with
    | none =>
        simp [hBlocks] at hDecode
    | some blocks =>
        let decodedPayload : DecodedBucketPayload :=
          { bucketIndex :=
              decodeNatField ((bytes.drop slotIndexBytes).take slotIndexBytes)
          , liveEntryCount :=
              decodeNatField
                ((bytes.drop (slotIndexBytes + slotIndexBytes)).take
                  slotIndexBytes)
          , blocks := blocks
          }
        by_cases hAccepted :
            decodedPayload.Accepted expectedBucketIndex blocksPerBucket
        · simp [hBlocks, hAccepted, decodedPayload] at hDecode
          cases hDecode
          exact decodeExactBlocks_some_validShapes hBlocks
        · simp [hBlocks, hAccepted, decodedPayload] at hDecode
  · contradiction

theorem decodePathBucketBoundedExact_some_shape
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodePathBucketBoundedExact?
          blocksPerBucket keyBytes valueBytes expectedBucketIndex
          capacity leafCount bytes = some payload) :
    bytes.length =
        codecBucketBytes true blocksPerBucket keyBytes valueBytes ∧
      payload.Accepted expectedBucketIndex blocksPerBucket ∧
      ∀ block, block ∈ payload.blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount := by
  unfold decodePathBucketBoundedExact? at hDecode
  cases hBucket :
      decodeBucketExact?
        true blocksPerBucket keyBytes valueBytes expectedBucketIndex bytes with
  | none =>
      simp [hBucket] at hDecode
  | some decodedPayload =>
      by_cases hBoundsCheck :
          checkPathBlocksLiveWithinBounds
            capacity leafCount decodedPayload.blocks = true
      · simp [hBucket, hBoundsCheck] at hDecode
        cases hDecode
        have hAccepted :=
          decodeBucketExact_some_exact_length_and_accepted hBucket
        have hValid :=
          decodeBucketExact_some_block_validShapes hBucket
        have hBounds :=
          checkPathBlocksLiveWithinBounds_true hBoundsCheck
        refine ⟨hAccepted.1, hAccepted.2, ?_⟩
        intro block hMem
        exact ⟨hValid block hMem, hBounds block hMem⟩
      · simp [hBucket, hBoundsCheck] at hDecode

theorem decodePathBucketPathBoundedExact_some_shape
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodePathBucketPathBoundedExact?
          blocksPerBucket keyBytes valueBytes expectedBucketIndex
          capacity leafCount bytes = some payload) :
    bytes.length =
        codecBucketBytes true blocksPerBucket keyBytes valueBytes ∧
      payload.Accepted expectedBucketIndex blocksPerBucket ∧
      ∀ block, block ∈ payload.blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount ∧
          block.LiveOnBucketPath leafCount expectedBucketIndex := by
  unfold decodePathBucketPathBoundedExact? at hDecode
  cases hBase :
      decodePathBucketBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes with
  | none =>
      simp [hBase] at hDecode
  | some decodedPayload =>
      by_cases hPathCheck :
          checkPathBlocksLiveOnBucketPath
            leafCount expectedBucketIndex decodedPayload.blocks = true
      · simp [hBase, hPathCheck] at hDecode
        cases hDecode
        have hBaseShape :=
          decodePathBucketBoundedExact_some_shape hBase
        have hPath :=
          checkPathBlocksLiveOnBucketPath_true hPathCheck
        refine ⟨hBaseShape.1, hBaseShape.2.1, ?_⟩
        intro block hMem
        exact
          ⟨(hBaseShape.2.2 block hMem).1,
            (hBaseShape.2.2 block hMem).2,
            hPath block hMem⟩
      · simp [hBase, hPathCheck] at hDecode

theorem decodePathBucketPositionMapBoundedExact_some_shape
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat}
    {positionMap : List (Option Nat)}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodePathBucketPositionMapBoundedExact?
          blocksPerBucket keyBytes valueBytes expectedBucketIndex
          capacity leafCount positionMap bytes = some payload) :
    bytes.length =
        codecBucketBytes true blocksPerBucket keyBytes valueBytes ∧
      payload.Accepted expectedBucketIndex blocksPerBucket ∧
      ∀ block, block ∈ payload.blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount ∧
          block.LiveOnBucketPath leafCount expectedBucketIndex ∧
          block.AgreesWithPositionMap positionMap := by
  unfold decodePathBucketPositionMapBoundedExact? at hDecode
  cases hBase :
      decodePathBucketPathBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes with
  | none =>
      simp [hBase] at hDecode
  | some decodedPayload =>
      by_cases hPositionMapCheck :
          checkPathBlocksPositionMapAgreement positionMap
            decodedPayload.blocks = true
      · simp [hBase, hPositionMapCheck] at hDecode
        cases hDecode
        have hBaseShape :=
          decodePathBucketPathBoundedExact_some_shape hBase
        have hPositionMap :=
          checkPathBlocksPositionMapAgreement_true hPositionMapCheck
        refine ⟨hBaseShape.1, hBaseShape.2.1, ?_⟩
        intro block hMem
        exact
          ⟨(hBaseShape.2.2 block hMem).1,
            (hBaseShape.2.2 block hMem).2.1,
            (hBaseShape.2.2 block hMem).2.2,
            hPositionMap block hMem⟩
      · simp [hBase, hPositionMapCheck] at hDecode

theorem decodePathBucketUniquePositionMapBoundedExact_some_shape
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex
      capacity leafCount : Nat}
    {positionMap : List (Option Nat)}
    {bytes : List Nat}
    {payload : DecodedBucketPayload}
    (hDecode :
      decodePathBucketUniquePositionMapBoundedExact?
          blocksPerBucket keyBytes valueBytes expectedBucketIndex
          capacity leafCount positionMap bytes = some payload) :
    bytes.length =
        codecBucketBytes true blocksPerBucket keyBytes valueBytes ∧
      payload.Accepted expectedBucketIndex blocksPerBucket ∧
      LiveSlotNoDuplicates payload.blocks ∧
      ∀ block, block ∈ payload.blocks →
        block.ValidShape true keyBytes valueBytes ∧
          block.LivePathWithinBounds capacity leafCount ∧
          block.LiveOnBucketPath leafCount expectedBucketIndex ∧
          block.AgreesWithPositionMap positionMap := by
  unfold decodePathBucketUniquePositionMapBoundedExact? at hDecode
  cases hBase :
      decodePathBucketPositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMap bytes with
  | none =>
      simp [hBase] at hDecode
  | some decodedPayload =>
      by_cases hNoDuplicates :
          checkPathBlocksNoDuplicateLiveSlots decodedPayload.blocks = true
      · simp [hBase, hNoDuplicates] at hDecode
        cases hDecode
        have hBaseShape :=
          decodePathBucketPositionMapBoundedExact_some_shape hBase
        have hDistinct :=
          checkPathBlocksNoDuplicateLiveSlots_true hNoDuplicates
        exact ⟨hBaseShape.1, hBaseShape.2.1, hDistinct, hBaseShape.2.2⟩
      · simp [hBase, hNoDuplicates] at hDecode

theorem encodeBlocks_length
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {blocks : List CodecBlock}
    (hBlocks :
      ∀ block, block ∈ blocks →
        block.ValidShape isPath keyBytes valueBytes) :
    (encodeBlocks isPath blocks).length =
      blocks.length * codecBlockBytes isPath keyBytes valueBytes := by
  induction blocks with
  | nil =>
      simp [encodeBlocks]
  | cons block blocks ih =>
      have hBlock :
          block.ValidShape isPath keyBytes valueBytes :=
        hBlocks block (by simp)
      have hTail :
          ∀ tailBlock, tailBlock ∈ blocks →
            tailBlock.ValidShape isPath keyBytes valueBytes := by
        intro tailBlock hMem
        exact hBlocks tailBlock (by simp [hMem])
      simp [encodeBlocks, encodeBlock_length hBlock, ih hTail,
        Nat.succ_mul, Nat.add_comm]

theorem decodeExactBlocks_encodeBlocks
    {isPath : Bool}
    {keyBytes valueBytes : Nat}
    {blocks : List CodecBlock}
    (hBlocks :
      ∀ block, block ∈ blocks →
        block.ValidShape isPath keyBytes valueBytes) :
    decodeExactBlocks? isPath keyBytes valueBytes
        blocks.length (encodeBlocks isPath blocks) =
      some blocks := by
  induction blocks with
  | nil =>
      rfl
  | cons block blocks ih =>
      have hBlock :
          block.ValidShape isPath keyBytes valueBytes :=
        hBlocks block (by simp)
      have hTail :
          ∀ tailBlock, tailBlock ∈ blocks →
            tailBlock.ValidShape isPath keyBytes valueBytes := by
        intro tailBlock hMem
        exact hBlocks tailBlock (by simp [hMem])
      have hBlockLen :
          (encodeBlock isPath block).length =
            codecBlockBytes isPath keyBytes valueBytes :=
        encodeBlock_length hBlock
      simp [decodeExactBlocks?, encodeBlocks, hBlockLen,
        decodeBlockExact_encodeBlock hBlock, ih hTail]

theorem encodeBucket_length
    {isPath : Bool}
    {blocksPerBucket keyBytes valueBytes : Nat}
    {bucket : CodecBucket}
    (hBucket :
      bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes) :
    (encodeBucket isPath bucket).length =
      codecBucketBytes isPath blocksPerBucket keyBytes valueBytes := by
  rcases hBucket with
    ⟨hAccess, hIndex, hLive, hBlockCount, hBlocks⟩
  simp [encodeBucket, codecBucketBytes, codecBucketHeaderBytes,
    hAccess, hIndex, hLive, encodeBlocks_length hBlocks,
    hBlockCount, Nat.add_assoc]

theorem decodeBucketExact_encodeBucket
    {isPath : Bool}
    {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
    {bucket : CodecBucket}
    (hBucket :
      bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes)
    (hBucketIndex :
      decodeNatField bucket.bucketIndexField = expectedBucketIndex)
    (hLiveCount :
      decodeNatField bucket.liveEntryCountField =
        liveBlockCount bucket.blocks) :
    decodeBucketExact?
        isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
        (encodeBucket isPath bucket) =
      some
        { bucketIndex := expectedBucketIndex
        , liveEntryCount := liveBlockCount bucket.blocks
        , blocks := bucket.blocks
        } := by
  cases bucket with
  | mk accessCounterField bucketIndexField liveEntryCountField blocks =>
      unfold CodecBucket.ValidShape at hBucket
      simp at hBucket hBucketIndex hLiveCount
      rcases hBucket with
        ⟨hAccess, hBucketIndexLen, hLiveLen, hBlockCount, hBlocks⟩
      have hEncodedLen :
          (encodeBucket isPath
            { accessCounterField := accessCounterField
            , bucketIndexField := bucketIndexField
            , liveEntryCountField := liveEntryCountField
            , blocks := blocks
            }).length =
            codecBucketBytes isPath blocksPerBucket keyBytes valueBytes :=
        encodeBucket_length
          ⟨hAccess, hBucketIndexLen, hLiveLen, hBlockCount, hBlocks⟩
      have hDecodeBlocks :
          decodeExactBlocks? isPath keyBytes valueBytes
              blocks.length (encodeBlocks isPath blocks) =
            some blocks :=
        decodeExactBlocks_encodeBlocks hBlocks
      have hDecodeBlocksCount :
          decodeExactBlocks? isPath keyBytes valueBytes
              blocksPerBucket (encodeBlocks isPath blocks) =
            some blocks := by
        rw [← hBlockCount]
        exact hDecodeBlocks
      have hEncodedLen' :
          slotIndexBytes +
              (slotIndexBytes +
                (slotIndexBytes + (encodeBlocks isPath blocks).length)) =
            codecBucketBytes isPath blocksPerBucket keyBytes valueBytes := by
        simpa [encodeBucket, hAccess, hBucketIndexLen, hLiveLen] using
          hEncodedLen
      have hAcceptedExpected :
          DecodedBucketPayload.Accepted expectedBucketIndex blocksPerBucket
            { bucketIndex := expectedBucketIndex
            , liveEntryCount := liveBlockCount blocks
            , blocks := blocks
            } := by
        refine ⟨rfl, hBlockCount, ?_, rfl⟩
        rw [← hBlockCount]
        exact liveBlockCount_le_length blocks
      simp [decodeBucketExact?, encodeBucket, hEncodedLen', hAccess,
        hBucketIndexLen, hLiveLen, hDecodeBlocksCount, hAcceptedExpected,
        hBucketIndex, hLiveCount]

theorem zeroPadTo_length
    {len : Nat}
    {bytes : List Nat}
    (hLen : bytes.length ≤ len) :
    (zeroPadTo len bytes).length = len := by
  simp [zeroPadTo, Nat.add_sub_of_le hLen]

theorem encodePathPositionMapPageBytes_length
    {directoryPageBytes : Nat}
    {positionMapPrefixBytes : List Nat}
    (hLen : positionMapPrefixBytes.length ≤ directoryPageBytes) :
    (encodePathPositionMapPageBytes directoryPageBytes
      positionMapPrefixBytes).length = directoryPageBytes := by
  exact zeroPadTo_length hLen

theorem positionMapEntryFieldsEncode_entry_count
    {leafCount : Nat}
    {fields : List (List Nat)}
    {entries : List (Option Nat)}
    (hFields : PositionMapEntryFieldsEncode leafCount fields entries) :
    fields.length = entries.length := by
  induction fields generalizing entries with
  | nil =>
      cases entries with
      | nil => rfl
      | cons entry entries =>
          simp [PositionMapEntryFieldsEncode] at hFields
  | cons field fields ih =>
      cases entries with
      | nil =>
          simp [PositionMapEntryFieldsEncode] at hFields
      | cons entry entries =>
          unfold PositionMapEntryFieldsEncode at hFields
          exact congrArg Nat.succ (ih hFields.2.2)

theorem encodePositionMapEntryFields_length
    {leafCount : Nat}
    {fields : List (List Nat)}
    {entries : List (Option Nat)}
    (hFields : PositionMapEntryFieldsEncode leafCount fields entries) :
    (encodePositionMapEntryFields fields).length =
      entries.length * leafLabelBytes := by
  induction fields generalizing entries with
  | nil =>
      cases entries with
      | nil => rfl
      | cons entry entries =>
          simp [PositionMapEntryFieldsEncode] at hFields
  | cons field fields ih =>
      cases entries with
      | nil =>
          simp [PositionMapEntryFieldsEncode] at hFields
      | cons entry entries =>
          unfold PositionMapEntryFieldsEncode at hFields
          rcases hFields with ⟨hFieldLen, _hDecode, hTail⟩
          simp [encodePositionMapEntryFields, hFieldLen, ih hTail,
            Nat.succ_mul]
          omega

theorem decodePositionMapEntriesExact_encodePositionMapEntryFields
    {leafCount : Nat}
    {fields : List (List Nat)}
    {entries : List (Option Nat)}
    (hFields : PositionMapEntryFieldsEncode leafCount fields entries) :
    decodePositionMapEntriesExact? leafCount entries.length
        (encodePositionMapEntryFields fields) =
      some entries := by
  induction fields generalizing entries with
  | nil =>
      cases entries with
      | nil => rfl
      | cons entry entries =>
          simp [PositionMapEntryFieldsEncode] at hFields
  | cons field fields ih =>
      cases entries with
      | nil =>
          simp [PositionMapEntryFieldsEncode] at hFields
      | cons entry entries =>
          unfold PositionMapEntryFieldsEncode at hFields
          rcases hFields with ⟨hFieldLen, hFieldDecode, hTail⟩
          have hTailDecode := ih hTail
          simp [decodePositionMapEntriesExact?, encodePositionMapEntryFields,
            hFieldLen, hFieldDecode, hTailDecode]

theorem decodePathPositionMapPageExact_encodePositionMapEntryFields
    {leafCount directoryPageBytes : Nat}
    {fields : List (List Nat)}
    {entries : List (Option Nat)}
    (hFields : PositionMapEntryFieldsEncode leafCount fields entries)
    (hEntryCount : entries.length = directoryPageEntries)
    (hDirectoryBytes : pathPositionMapEntryBytes ≤ directoryPageBytes) :
    decodePathPositionMapPageExact? leafCount directoryPageBytes
        (encodePathPositionMapPageBytes directoryPageBytes
          (encodePositionMapEntryFields fields)) =
      some
        { entries := entries
        , padding :=
            List.replicate
              (directoryPageBytes - pathPositionMapEntryBytes) 0
        } := by
  have hPrefixLen :
      (encodePositionMapEntryFields fields).length =
        pathPositionMapEntryBytes := by
    rw [encodePositionMapEntryFields_length hFields, hEntryCount]
    rfl
  have hPageLen :
      (encodePathPositionMapPageBytes directoryPageBytes
          (encodePositionMapEntryFields fields)).length =
        directoryPageBytes := by
    exact encodePathPositionMapPageBytes_length
      (by rw [hPrefixLen]; exact hDirectoryBytes)
  have hEntryDecode :
      decodePositionMapEntriesExact? leafCount directoryPageEntries
          (encodePositionMapEntryFields fields) =
        some entries := by
    rw [← hEntryCount]
    exact decodePositionMapEntriesExact_encodePositionMapEntryFields hFields
  unfold decodePathPositionMapPageExact?
  rw [if_pos ⟨hPageLen, hDirectoryBytes⟩]
  simp [encodePathPositionMapPageBytes, zeroPadTo, hPrefixLen, hEntryDecode]

theorem encodePathPositionMapPagesBytes_length
    {directoryPageBytes : Nat}
    {fieldPages : List (List (List Nat))} :
    (encodePathPositionMapPagesBytes directoryPageBytes fieldPages).length =
      fieldPages.length := by
  induction fieldPages with
  | nil =>
      rfl
  | cons fields fieldPages ih =>
      simp [encodePathPositionMapPagesBytes, ih]

theorem positionMapPageEntryFieldsEncode_page_count
    {leafCount : Nat}
    {fieldPages : List (List (List Nat))}
    {entryPages : List (List (Option Nat))}
    (hPages :
      PositionMapPageEntryFieldsEncode leafCount fieldPages entryPages) :
    fieldPages.length = entryPages.length := by
  induction fieldPages generalizing entryPages with
  | nil =>
      cases entryPages with
      | nil => rfl
      | cons entries entryPages =>
          simp [PositionMapPageEntryFieldsEncode] at hPages
  | cons fields fieldPages ih =>
      cases entryPages with
      | nil =>
          simp [PositionMapPageEntryFieldsEncode] at hPages
      | cons entries entryPages =>
          unfold PositionMapPageEntryFieldsEncode at hPages
          exact congrArg Nat.succ (ih hPages.2.2)

theorem flattenPositionMapPages_length
    {leafCount : Nat}
    {fieldPages : List (List (List Nat))}
    {entryPages : List (List (Option Nat))}
    (hPages :
      PositionMapPageEntryFieldsEncode leafCount fieldPages entryPages) :
    (flattenPositionMapPages entryPages).length =
      entryPages.length * directoryPageEntries := by
  induction fieldPages generalizing entryPages with
  | nil =>
      cases entryPages with
      | nil =>
          rfl
      | cons entries entryPages =>
          simp [PositionMapPageEntryFieldsEncode] at hPages
  | cons fields fieldPages ih =>
      cases entryPages with
      | nil =>
          simp [PositionMapPageEntryFieldsEncode] at hPages
      | cons entries entryPages =>
          unfold PositionMapPageEntryFieldsEncode at hPages
          rcases hPages with ⟨_hFields, hEntriesLen, hTail⟩
          simp [flattenPositionMapPages, hEntriesLen, ih hTail,
            Nat.succ_mul]
          omega

theorem decodePathPositionMapPagesAll_encodePathPositionMapPagesBytes
    {leafCount directoryPageBytes : Nat}
    {fieldPages : List (List (List Nat))}
    {entryPages : List (List (Option Nat))}
    (hPages :
      PositionMapPageEntryFieldsEncode leafCount fieldPages entryPages)
    (hDirectoryBytes : pathPositionMapEntryBytes ≤ directoryPageBytes) :
    decodePathPositionMapPagesAll? leafCount directoryPageBytes
        (encodePathPositionMapPagesBytes directoryPageBytes fieldPages) =
      some (flattenPositionMapPages entryPages) := by
  induction fieldPages generalizing entryPages with
  | nil =>
      cases entryPages with
      | nil =>
          rfl
      | cons entries entryPages =>
          simp [PositionMapPageEntryFieldsEncode] at hPages
  | cons fields fieldPages ih =>
      cases entryPages with
      | nil =>
          simp [PositionMapPageEntryFieldsEncode] at hPages
      | cons entries entryPages =>
          unfold PositionMapPageEntryFieldsEncode at hPages
          rcases hPages with ⟨hFields, hEntryCount, hTail⟩
          have hHeadDecode :
              decodePathPositionMapPageExact?
                  leafCount directoryPageBytes
                  (encodePathPositionMapPageBytes directoryPageBytes
                    (encodePositionMapEntryFields fields)) =
                some
                  { entries := entries
                  , padding :=
                      List.replicate
                        (directoryPageBytes - pathPositionMapEntryBytes) 0
                  } :=
            decodePathPositionMapPageExact_encodePositionMapEntryFields
              hFields hEntryCount hDirectoryBytes
          have hTailDecode := ih hTail
          simp [decodePathPositionMapPagesAll?,
            encodePathPositionMapPagesBytes, flattenPositionMapPages,
            hHeadDecode, hTailDecode]

theorem decodePathPositionMapPagesExact_encodePathPositionMapPagesBytes
    {leafCount directoryPageBytes capacity : Nat}
    {fieldPages : List (List (List Nat))}
    {entryPages : List (List (Option Nat))}
    (hPages :
      PositionMapPageEntryFieldsEncode leafCount fieldPages entryPages)
    (hPageCount :
      entryPages.length = pathPositionMapPages capacity)
    (hDirectoryBytes : pathPositionMapEntryBytes ≤ directoryPageBytes) :
    decodePathPositionMapPagesExact?
        leafCount directoryPageBytes capacity
        (encodePathPositionMapPagesBytes directoryPageBytes fieldPages) =
      some ((flattenPositionMapPages entryPages).take capacity) := by
  have hFieldPageCount :=
    positionMapPageEntryFieldsEncode_page_count hPages
  have hEncodedPageCount :
      (encodePathPositionMapPagesBytes
          directoryPageBytes fieldPages).length =
        pathPositionMapPages capacity := by
    rw [encodePathPositionMapPagesBytes_length, hFieldPageCount,
      hPageCount]
  have hAllDecode :
      decodePathPositionMapPagesAll? leafCount directoryPageBytes
          (encodePathPositionMapPagesBytes directoryPageBytes fieldPages) =
        some (flattenPositionMapPages entryPages) :=
    decodePathPositionMapPagesAll_encodePathPositionMapPagesBytes
      hPages hDirectoryBytes
  have hCapacity :
      capacity ≤ (flattenPositionMapPages entryPages).length := by
    rw [flattenPositionMapPages_length hPages, hPageCount]
    exact pathPositionMapPages_covers_capacity capacity
  unfold decodePathPositionMapPagesExact?
  rw [if_pos hEncodedPageCount]
  rw [hAllDecode]
  simp [hCapacity]

theorem encodePathStashPageBytes_length
    {directoryPageBytes : Nat}
    {stashBlockBytes : List Nat}
    (hLen : stashBlockBytes.length ≤ directoryPageBytes) :
    (encodePathStashPageBytes directoryPageBytes
      stashBlockBytes).length = directoryPageBytes := by
  exact zeroPadTo_length hLen

theorem decodePathStashPageExact_encodeBlocks
    {keyBytes valueBytes directoryPageBytes : Nat}
    {blocks : List CodecBlock}
    (hBlockCount : blocks.length = directoryPageEntries)
    (hBlocks :
      ∀ block, block ∈ blocks →
        block.ValidShape true keyBytes valueBytes)
    (hDirectoryBytes :
      directoryPageBytes =
        directoryPageEntries * codecBlockBytes true keyBytes valueBytes) :
    decodePathStashPageExact?
        true keyBytes valueBytes directoryPageBytes
        (encodePathStashPageBytes directoryPageBytes
          (encodeBlocks true blocks)) =
      some { blocks := blocks } := by
  have hPrefixLen :
      (encodeBlocks true blocks).length = directoryPageBytes := by
    rw [encodeBlocks_length hBlocks, hBlockCount, hDirectoryBytes]
  have hPageLen :
      (encodePathStashPageBytes directoryPageBytes
          (encodeBlocks true blocks)).length =
        directoryPageBytes := by
    exact encodePathStashPageBytes_length
      (by rw [hPrefixLen]; exact Nat.le_refl directoryPageBytes)
  have hPageEq :
      encodePathStashPageBytes directoryPageBytes
          (encodeBlocks true blocks) =
        encodeBlocks true blocks := by
    simp [encodePathStashPageBytes, zeroPadTo, hPrefixLen]
  have hDecodeBlocks :
      decodeExactBlocks? true keyBytes valueBytes directoryPageEntries
          (encodeBlocks true blocks) =
        some blocks := by
    rw [← hBlockCount]
    exact decodeExactBlocks_encodeBlocks hBlocks
  unfold decodePathStashPageExact?
  rw [if_pos ⟨hPageLen, hDirectoryBytes⟩]
  rw [hPageEq]
  simp [hDecodeBlocks]

theorem encodePathStashPagesBytes_length
    {directoryPageBytes : Nat}
    {blockPages : List (List CodecBlock)} :
    (encodePathStashPagesBytes directoryPageBytes blockPages).length =
      blockPages.length := by
  induction blockPages with
  | nil =>
      rfl
  | cons blocks blockPages ih =>
      simp [encodePathStashPagesBytes, ih]

theorem flattenStashPages_length
    {keyBytes valueBytes : Nat}
    {blockPages : List (List CodecBlock)}
    (hPages :
      PathStashPageBlocksValid keyBytes valueBytes blockPages) :
    (flattenStashPages blockPages).length =
      blockPages.length * directoryPageEntries := by
  induction blockPages with
  | nil =>
      rfl
  | cons blocks blockPages ih =>
      unfold PathStashPageBlocksValid at hPages
      rcases hPages with ⟨hBlockCount, _hBlocks, hTail⟩
      simp [flattenStashPages, hBlockCount, ih hTail, Nat.succ_mul]
      omega

theorem decodePathStashPagesAll_encodePathStashPagesBytes
    {keyBytes valueBytes directoryPageBytes : Nat}
    {blockPages : List (List CodecBlock)}
    (hPages :
      PathStashPageBlocksValid keyBytes valueBytes blockPages)
    (hDirectoryBytes :
      directoryPageBytes =
        directoryPageEntries * codecBlockBytes true keyBytes valueBytes) :
    decodePathStashPagesAll?
        true keyBytes valueBytes directoryPageBytes
        (encodePathStashPagesBytes directoryPageBytes blockPages) =
      some (flattenStashPages blockPages) := by
  induction blockPages with
  | nil =>
      rfl
  | cons blocks blockPages ih =>
      unfold PathStashPageBlocksValid at hPages
      rcases hPages with ⟨hBlockCount, hBlocks, hTail⟩
      have hHeadDecode :
          decodePathStashPageExact?
              true keyBytes valueBytes directoryPageBytes
              (encodePathStashPageBytes directoryPageBytes
                (encodeBlocks true blocks)) =
            some { blocks := blocks } :=
        decodePathStashPageExact_encodeBlocks
          hBlockCount hBlocks hDirectoryBytes
      have hTailDecode := ih hTail
      simp [decodePathStashPagesAll?, encodePathStashPagesBytes,
        flattenStashPages, hHeadDecode, hTailDecode]

theorem decodePathStashPagesExact_encodePathStashPagesBytes
    {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
    {blockPages : List (List CodecBlock)}
    (hPages :
      PathStashPageBlocksValid keyBytes valueBytes blockPages)
    (hPageCount : blockPages.length = stashPageCount)
    (hDirectoryBytes :
      directoryPageBytes =
        directoryPageEntries * codecBlockBytes true keyBytes valueBytes) :
    decodePathStashPagesExact?
        true keyBytes valueBytes directoryPageBytes stashPageCount
        (encodePathStashPagesBytes directoryPageBytes blockPages) =
      some (flattenStashPages blockPages) := by
  have hEncodedPageCount :
      (encodePathStashPagesBytes directoryPageBytes blockPages).length =
        stashPageCount := by
    rw [encodePathStashPagesBytes_length, hPageCount]
  unfold decodePathStashPagesExact?
  rw [if_pos hEncodedPageCount]
  exact
    decodePathStashPagesAll_encodePathStashPagesBytes
      hPages hDirectoryBytes


theorem wellFormedSurrogateBucketBytes_matchesCodec
    {object : OramObjectManifest}
    (hObject : WellFormedSurrogateOramObject object) :
    object.bucketSize =
      bucketBytes object.blocksPerBucket object.blockSize := by
  exact hObject.2.2.1

theorem wellFormedPathBucketBytes_matchesCodec
    {object : OramObjectManifest}
    (hObject : WellFormedPathOramObject object) :
    object.bucketSize =
      bucketBytes object.blocksPerBucket object.blockSize := by
  exact hObject.2.2.1

theorem wellFormedPrivatePathBucketBytes_matchesCodec
    {object : OramObjectManifest}
    (hObject : WellFormedPrivatePathOramObject object) :
    object.bucketSize =
      bucketBytes object.blocksPerBucket object.blockSize := by
  exact hObject.2.2.1

theorem wellFormedOramBucketBytes_matchesCodec
    {object : OramObjectManifest}
    (hObject : WellFormedOramObject object) :
    object.bucketSize =
      bucketBytes object.blocksPerBucket object.blockSize := by
  rcases hObject with hSurrogate | hPathOrPrivate
  · exact wellFormedSurrogateBucketBytes_matchesCodec hSurrogate
  · rcases hPathOrPrivate with hPath | hPrivate
    · exact wellFormedPathBucketBytes_matchesCodec hPath
    · exact wellFormedPrivatePathBucketBytes_matchesCodec hPrivate

end RuntimeOramCodecSemantics

end UOToolchain
