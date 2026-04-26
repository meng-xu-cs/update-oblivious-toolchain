import UOToolchain.RuntimeStoreCodecSemantics

namespace UOToolchain

namespace RuntimeStoreHelperSemantics

structure RawValueTakeResult where
  boxed : List Nat
  wiped : List Nat
deriving Repr, DecidableEq

def takeBoxedRawStoreValue (value : List Nat) : RawValueTakeResult :=
  { boxed := value
  , wiped := RuntimeStoreCodecSemantics.wipeBytes value
  }

structure StoreSlot where
  object : String
  value : List Nat
deriving Repr, DecidableEq

def zeroedRawSlots (objects : List String) (slotLen : Nat) :
    List StoreSlot :=
  objects.map
    (fun object =>
      { object := object
      , value := RuntimeStoreCodecSemantics.zeroedBytes slotLen
      })

def lookupSlot (object : String) : List StoreSlot → Option (List Nat)
  | [] => none
  | slot :: slots =>
      if slot.object == object then
        some slot.value
      else
        lookupSlot object slots

def insertOrReplaceSlot
    (object : String)
    (value : List Nat) :
    List StoreSlot → List StoreSlot
  | [] => [{ object := object, value := value }]
  | slot :: slots =>
      if slot.object == object then
        { slot with value := value } :: slots
      else
        slot :: insertOrReplaceSlot object value slots

def appendBoxedEvent (events : List α) (event : α) : List α :=
  events ++ [event]

abbrev StoreWriteShape := RuntimeStoreCodecSemantics.StoreWriteShape

def allUpdate (events : List StoreWriteShape) : Prop :=
  ∀ event,
    event ∈ events →
      event.writeClass = RuntimeStoreCodecSemantics.StoreWriteClass.update

def bootstrappedUoSlotShape
    (object : String)
    (logicalLen : Nat) : StoreSlot :=
  { object := object
  , value := RuntimeStoreCodecSemantics.zeroedBytes
      (RuntimeStoreCodecSemantics.sealedEncodedLen logicalLen)
  }

structure StoreMetrics where
  logicalReads : Nat
  physicalReads : Nat
  logicalWrites : Nat
  physicalWrites : Nat
  zeroWrites : Nat
deriving Repr, DecidableEq

def recordStoreRead (metrics : StoreMetrics) : StoreMetrics :=
  { metrics with
    logicalReads := metrics.logicalReads + 1
    physicalReads := metrics.physicalReads + 1
  }

def recordStoreWrite
    (metrics : StoreMetrics)
    (zeroWrite : Bool) : StoreMetrics :=
  { metrics with
    logicalWrites := metrics.logicalWrites + 1
    physicalWrites := metrics.physicalWrites + 1
    zeroWrites := metrics.zeroWrites + if zeroWrite then 1 else 0
  }

structure UoStoreWriteResult where
  metrics : StoreMetrics
  event : StoreWriteShape
deriving Repr, DecidableEq

def recordUoStoreWrite
    (metrics : StoreMetrics)
    (object : String)
    (slotLen : Nat) : UoStoreWriteResult :=
  { metrics := recordStoreWrite metrics false
  , event := RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen
  }

theorem takeBoxedRawStoreValue_copiesInput
    (value : List Nat) :
    (takeBoxedRawStoreValue value).boxed = value := by
  rfl

theorem takeBoxedRawStoreValue_wipesInputLength
    (value : List Nat) :
    (takeBoxedRawStoreValue value).wiped.length = value.length := by
  exact RuntimeStoreCodecSemantics.wipeBytes_length value

theorem takeBoxedRawStoreValue_wipesInputZeros
    {value : List Nat}
    {byte : Nat}
    (hMem : byte ∈ (takeBoxedRawStoreValue value).wiped) :
    byte = 0 := by
  exact RuntimeStoreCodecSemantics.wipeBytes_all_zero hMem

theorem zeroedRawSlots_length
    (objects : List String)
    (slotLen : Nat) :
    (zeroedRawSlots objects slotLen).length = objects.length := by
  simp [zeroedRawSlots]

theorem lookupSlot_zeroedRawSlots_some_shape
    {objects : List String}
    {object : String}
    {slotLen : Nat}
    {value : List Nat}
    (hLookup :
      lookupSlot object (zeroedRawSlots objects slotLen) = some value) :
    value.length = slotLen ∧
      ∀ byte, byte ∈ value → RuntimeStoreCodecSemantics.ValidByte byte ∧ byte = 0 := by
  induction objects with
  | nil =>
      simp [zeroedRawSlots, lookupSlot] at hLookup
  | cons head tail ih =>
      unfold zeroedRawSlots at hLookup
      simp only [List.map_cons] at hLookup
      unfold lookupSlot at hLookup
      by_cases hEq : head == object
      · simp [hEq] at hLookup
        cases hLookup
        constructor
        · exact RuntimeStoreCodecSemantics.zeroedBytes_length slotLen
        · intro byte hMem
          exact
            ⟨ RuntimeStoreCodecSemantics.zeroedBytes_validBytes slotLen byte hMem
            , RuntimeStoreCodecSemantics.zeroedBytes_all_zero hMem
            ⟩
      · simp [hEq] at hLookup
        exact ih hLookup

theorem insertOrReplaceSlot_lookup_self
    (slots : List StoreSlot)
    (object : String)
    (value : List Nat) :
    lookupSlot object (insertOrReplaceSlot object value slots) =
      some value := by
  induction slots with
  | nil =>
      simp [insertOrReplaceSlot, lookupSlot]
  | cons slot slots ih =>
      unfold insertOrReplaceSlot lookupSlot
      by_cases hEq : slot.object == object
      · simp [hEq]
      · simp [hEq, ih]

theorem insertOrReplaceSlot_length_le_succ
    (slots : List StoreSlot)
    (object : String)
    (value : List Nat) :
    (insertOrReplaceSlot object value slots).length ≤ slots.length + 1 := by
  induction slots with
  | nil =>
      simp [insertOrReplaceSlot]
  | cons slot slots ih =>
      unfold insertOrReplaceSlot
      by_cases hEq : slot.object == object
      · simp [hEq]
      · simp [hEq]
        omega

theorem appendBoxedEvent_length
    (events : List α)
    (event : α) :
    (appendBoxedEvent events event).length = events.length + 1 := by
  simp [appendBoxedEvent]

theorem appendBoxedEvent_preservesPrefix
    (events : List α)
    (event : α) :
    (appendBoxedEvent events event).take events.length = events := by
  simp [appendBoxedEvent]

theorem appendBoxedEvent_appendsSingleton
    (events : List α)
    (event : α) :
    (appendBoxedEvent events event).drop events.length = [event] := by
  simp [appendBoxedEvent]

theorem allUpdate_empty :
    allUpdate [] := by
  intro event hMem
  cases hMem

theorem allUpdate_append_update
    {events : List StoreWriteShape}
    (hEvents : allUpdate events)
    (object : String)
    (slotLen : Nat) :
    allUpdate
      (appendBoxedEvent events
        (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen)) := by
  intro event hMem
  simp [appendBoxedEvent] at hMem
  rcases hMem with hOld | hNew
  · exact hEvents event hOld
  · rw [hNew]
    rfl

theorem bootstrappedUoSlotShape_publicLength
    (object : String)
    (logicalLen : Nat) :
    (bootstrappedUoSlotShape object logicalLen).value.length =
      RuntimeStoreCodecSemantics.sealedEncodedLen logicalLen := by
  simp [bootstrappedUoSlotShape,
    RuntimeStoreCodecSemantics.zeroedBytes_length]

theorem bootstrappedUoSlotShape_validBytes
    (object : String)
    (logicalLen : Nat) :
    ∀ byte,
      byte ∈ (bootstrappedUoSlotShape object logicalLen).value →
        RuntimeStoreCodecSemantics.ValidByte byte := by
  intro byte hMem
  exact
    RuntimeStoreCodecSemantics.zeroedBytes_validBytes
      (RuntimeStoreCodecSemantics.sealedEncodedLen logicalLen)
      byte hMem

theorem resealUoStoreSlotTrace_publicUpdateShape
    (object : String)
    (slotLen : Nat) :
    allUpdate
      [RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen] ∧
      RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
        (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  constructor
  · exact allUpdate_append_update allUpdate_empty object slotLen
  · exact
      RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape_accepted
        object slotLen

theorem recordStoreRead_incrementsReadCounts
    (metrics : StoreMetrics) :
    (recordStoreRead metrics).logicalReads = metrics.logicalReads + 1 ∧
      (recordStoreRead metrics).physicalReads = metrics.physicalReads + 1 := by
  simp [recordStoreRead]

theorem recordStoreWrite_incrementsWriteCounts
    (metrics : StoreMetrics)
    (zeroWrite : Bool) :
    (recordStoreWrite metrics zeroWrite).logicalWrites =
        metrics.logicalWrites + 1 ∧
      (recordStoreWrite metrics zeroWrite).physicalWrites =
        metrics.physicalWrites + 1 := by
  simp [recordStoreWrite]

theorem recordUoStoreWrite_zeroWritesUnchanged
    (metrics : StoreMetrics)
    (object : String)
    (slotLen : Nat) :
    (recordUoStoreWrite metrics object slotLen).metrics.zeroWrites =
      metrics.zeroWrites := by
  simp [recordUoStoreWrite, recordStoreWrite]

theorem recordUoStoreWrite_eventAccepted
    (metrics : StoreMetrics)
    (object : String)
    (slotLen : Nat) :
    RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
      (recordUoStoreWrite metrics object slotLen).event := by
  exact RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape_accepted
    object slotLen

end RuntimeStoreHelperSemantics

end UOToolchain
