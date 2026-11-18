namespace UOToolchain

namespace RuntimeStoreCodecSemantics

def sealedNonceBytes : Nat := 12
def sealedTagBytes : Nat := 16

/-- The unit of a sealed record (`SEALED_UNIT_BYTES` in
`runtime/uo-store/src/generated_codec.rs`): a 32-byte storage word, the unit
the storage observer classifies. A sealed record is a whole number of them. -/
def sealedUnitBytes : Nat := 32

/-- The two values of a record's marker, the first byte of each of its units
(`SEALED_MARKERS`). Neither is zero. -/
def sealedMarkers : List Nat := [165, 90]

/-- ChaCha20-Poly1305 cipher key length in bytes, matching RFC 8439 section 2.5
(32-byte / 256-bit key). The Rust runtime pins this to `key: [u8; 32]` in
`runtime/uo-store/src/generated_surface.rs`, and the probe's
`runtime_crypto_primitive_identity_pinned` static-drift check rejects any other
key shape. The Lean constant lets WP5 codec theorems refer to this length
without re-deriving it from the Rust source. -/
def cipherKeyBytes : Nat := 32

def ValidByte (byte : Nat) : Prop :=
  byte < 256

inductive StoreWriteClass where
  | set
  | same
  | clear
  | update
deriving Repr, DecidableEq

structure StoreWriteShape where
  object : String
  location : String
  len : Nat
  writeClass : StoreWriteClass
deriving Repr, DecidableEq

def uoStoreSlotAad (object : String) : String :=
  "uo_store:" ++ object

def uoStoreUpdateWriteShape
    (object : String)
    (slotLen : Nat) : StoreWriteShape :=
  { object := object
  , location := object
  , len := slotLen
  , writeClass := StoreWriteClass.update
  }

def UoStoreUpdateWriteAccepted
    (object : String)
    (slotLen : Nat)
    (write : StoreWriteShape) : Prop :=
  write = uoStoreUpdateWriteShape object slotLen

def zeroedBytes (len : Nat) : List Nat :=
  List.replicate len 0

def wipeBytes (bytes : List Nat) : List Nat :=
  List.replicate bytes.length 0

def readExactRange?
    (bytes : List Nat)
    (start len : Nat) : Option (List Nat) :=
  if start + len ≤ bytes.length then
    some ((bytes.drop start).take len)
  else
    none

def copyExactInto?
    (out input : List Nat) : Option (List Nat) :=
  if out.length = input.length then some input else none

theorem zeroedBytes_length
    (len : Nat) :
    (zeroedBytes len).length = len := by
  simp [zeroedBytes]

theorem zeroedBytes_all_zero
    {len byte : Nat}
    (hMem : byte ∈ zeroedBytes len) :
    byte = 0 := by
  simp [zeroedBytes] at hMem
  exact hMem.2

theorem zeroedBytes_validBytes
    (len : Nat) :
    ∀ byte, byte ∈ zeroedBytes len → ValidByte byte := by
  intro byte hMem
  have hZero := zeroedBytes_all_zero hMem
  unfold ValidByte
  omega

theorem wipeBytes_length
    (bytes : List Nat) :
    (wipeBytes bytes).length = bytes.length := by
  simp [wipeBytes]

theorem wipeBytes_all_zero
    {bytes : List Nat}
    {byte : Nat}
    (hMem : byte ∈ wipeBytes bytes) :
    byte = 0 := by
  simp [wipeBytes] at hMem
  exact hMem.2

theorem readExactRange?_some_length
    {bytes out : List Nat}
    {start len : Nat}
    (hRead : readExactRange? bytes start len = some out) :
    out.length = len := by
  unfold readExactRange? at hRead
  by_cases hRange : start + len ≤ bytes.length
  · simp [hRange] at hRead
    cases hRead
    simp [List.length_take, List.length_drop]
    omega
  · simp [hRange] at hRead

theorem readExactRange?_rejectsOutOfRange
    {bytes : List Nat}
    {start len : Nat}
    (hRange : ¬ start + len ≤ bytes.length) :
    readExactRange? bytes start len = none := by
  simp [readExactRange?, hRange]

theorem copyExactInto?_some_shape
    {out input copied : List Nat}
    (hCopy : copyExactInto? out input = some copied) :
    copied = input ∧ copied.length = out.length := by
  unfold copyExactInto? at hCopy
  by_cases hLen : out.length = input.length
  · simp [hLen] at hCopy
    cases hCopy
    exact ⟨rfl, by omega⟩
  · simp [hLen] at hCopy

theorem copyExactInto?_rejectsLengthMismatch
    {out input : List Nat}
    (hLen : out.length ≠ input.length) :
    copyExactInto? out input = none := by
  simp [copyExactInto?, hLen]

theorem uoStoreUpdateWriteShape_accepted
    (object : String)
    (slotLen : Nat) :
    UoStoreUpdateWriteAccepted object slotLen
      (uoStoreUpdateWriteShape object slotLen) := by
  rfl

theorem uoStoreUpdateWriteAccepted_publicShape
    {object : String}
    {slotLen : Nat}
    {write : StoreWriteShape}
    (hAccepted : UoStoreUpdateWriteAccepted object slotLen write) :
    write.object = object ∧
      write.location = object ∧
      write.len = slotLen ∧
      write.writeClass = StoreWriteClass.update := by
  unfold UoStoreUpdateWriteAccepted uoStoreUpdateWriteShape at hAccepted
  cases hAccepted
  simp

/-! ### The class of a sealed write, from its bytes

A sealed write is an `Update` for the storage observer because the record it
writes differs, in every unit the observer classifies, from the record it
replaces, and neither has a zero unit. The label is not taken on trust: the
runtime keeps the record a write replaces and fails the call unless
`is_update_write` holds of the two (`crates/uo-core/src/trace.rs`,
`reseal_payload_and_record_write` and `reseal_uo_store_slot_and_trace_write`
in the generated helpers). This section states that check. The unit length
is a parameter; the runtime uses 32 bytes, a storage word. That a sealed
record written over a sealed record passes the check is proved in the next
section (`isUpdateWrite_of_markers`): the two carry different markers in
every unit, so it does not rest on the ciphertexts. -/

/-- Whether every byte of a record is zero. -/
def allZero (bytes : List Nat) : Bool :=
  bytes.all fun byte => byte == 0

/-- The class the storage observer gives a write of `new` over `old`
(`classify_write` in `crates/uo-core/src/trace.rs`). -/
def classifyWrite (old new : List Nat) : StoreWriteClass :=
  if old = new then StoreWriteClass.same
  else if allZero old && !allZero new then StoreWriteClass.set
  else if !allZero old && allZero new then StoreWriteClass.clear
  else StoreWriteClass.update

/-- The units of a record the observer classifies: `unitLen` bytes each, the
last one as far as the record reaches. -/
def unitsOf (unitLen : Nat) (bytes : List Nat) : List (List Nat) :=
  (List.range ((bytes.length + unitLen - 1) / unitLen)).map fun index =>
    (bytes.drop (index * unitLen)).take unitLen

/-- `is_update_write` in `crates/uo-core/src/trace.rs`, with the unit length
as a parameter: the records have one length, are not empty, and every unit
of the new record is an `Update` of the unit it replaces. -/
def isUpdateWrite (unitLen : Nat) (old new : List Nat) : Bool :=
  old.length == new.length && !new.isEmpty &&
    ((unitsOf unitLen old).zip (unitsOf unitLen new)).all fun units =>
      decide (classifyWrite units.1 units.2 = StoreWriteClass.update)

theorem classifyWrite_self (record : List Nat) :
    classifyWrite record record = StoreWriteClass.same := by
  simp [classifyWrite]

/-- A write that the check accepts is an `Update` in every unit. -/
theorem isUpdateWrite_units {unitLen : Nat} {old new : List Nat}
    (h : isUpdateWrite unitLen old new = true) :
    old.length = new.length ∧
      ∀ units ∈ (unitsOf unitLen old).zip (unitsOf unitLen new),
        classifyWrite units.1 units.2 = StoreWriteClass.update := by
  simp only [isUpdateWrite, Bool.and_eq_true, beq_iff_eq, List.all_eq_true,
    decide_eq_true_eq] at h
  exact ⟨h.1.1, h.2⟩

theorem unitsOf_ne_nil {unitLen : Nat} {bytes : List Nat}
    (hUnit : 0 < unitLen) (hBytes : bytes ≠ []) :
    ∃ rest, unitsOf unitLen bytes = bytes.take unitLen :: rest := by
  unfold unitsOf
  have hLen : 0 < bytes.length := List.length_pos_iff.mpr hBytes
  have hCount : 0 < (bytes.length + unitLen - 1) / unitLen := by
    apply Nat.div_pos
    · omega
    · exact hUnit
  obtain ⟨count, hEq⟩ : ∃ count, (bytes.length + unitLen - 1) / unitLen = count + 1 :=
    ⟨(bytes.length + unitLen - 1) / unitLen - 1, by omega⟩
  rw [hEq, List.range_succ_eq_map]
  simp

/-- A record written over itself is not an update: a write that leaves a
record as it was is refused. -/
theorem isUpdateWrite_self_false {unitLen : Nat} (hUnit : 0 < unitLen)
    (record : List Nat) : isUpdateWrite unitLen record record = false := by
  cases hRecord : record with
  | nil => simp [isUpdateWrite]
  | cons byte bytes =>
      obtain ⟨rest, hUnits⟩ :=
        unitsOf_ne_nil (unitLen := unitLen) (bytes := byte :: bytes) hUnit (by simp)
      simp [isUpdateWrite, hUnits, classifyWrite_self]

theorem allZero_false_of_nonzero {bytes : List Nat}
    (hBytes : bytes ≠ []) (hNonzero : ∀ byte ∈ bytes, 0 < byte) :
    allZero bytes = false := by
  cases bytes with
  | nil => exact absurd rfl hBytes
  | cons byte rest =>
      have hByte : 0 < byte := hNonzero byte (by simp)
      have hNe : (byte == 0) = false := by
        simp
        omega
      simp [allZero, hNe]

/-- Two units without a zero byte are a `Same` if they are equal and an
`Update` otherwise. -/
theorem classifyWrite_of_nonzero {old new : List Nat}
    (hOld : old ≠ []) (hNew : new ≠ [])
    (hOldNonzero : ∀ byte ∈ old, 0 < byte) (hNewNonzero : ∀ byte ∈ new, 0 < byte) :
    classifyWrite old new =
      if old = new then StoreWriteClass.same else StoreWriteClass.update := by
  simp [classifyWrite, allZero_false_of_nonzero hOld hOldNonzero,
    allZero_false_of_nonzero hNew hNewNonzero]

/-- A unit that begins with a nonzero byte is not zero. -/
theorem allZero_false_of_head {unit : List Nat} {marker : Nat}
    (hHead : unit.head? = some marker) (hMarker : 0 < marker) :
    allZero unit = false := by
  cases unit with
  | nil => simp at hHead
  | cons first others =>
      simp at hHead
      subst hHead
      have hNe : (first == 0) = false := by
        simp
        omega
      simp [allZero, hNe]

/-- Two units that begin with different nonzero bytes: the write of one over
the other is an `Update`, whatever else they hold. -/
theorem classifyWrite_update_of_heads {old new : List Nat} {oldMarker newMarker : Nat}
    (hOld : old.head? = some oldMarker) (hNew : new.head? = some newMarker)
    (hOldPos : 0 < oldMarker) (hNewPos : 0 < newMarker) (hNe : oldMarker ≠ newMarker) :
    classifyWrite old new = StoreWriteClass.update := by
  have hDiffer : old ≠ new := by
    intro hEq
    rw [hEq, hNew] at hOld
    exact hNe (Option.some.inj hOld).symm
  simp [classifyWrite, hDiffer, allZero_false_of_head hOld hOldPos,
    allZero_false_of_head hNew hNewPos]

theorem unitsOf_nil {unitLen : Nat} (hUnit : 0 < unitLen) :
    unitsOf unitLen [] = [] := by
  unfold unitsOf
  have hCount : (([] : List Nat).length + unitLen - 1) / unitLen = 0 := by
    apply Nat.div_eq_of_lt
    simp
    omega
  rw [hCount]
  rfl

/-- The units of a record that begins with a whole unit. -/
theorem unitsOf_append {unitLen : Nat} (hUnit : 0 < unitLen) {unit rest : List Nat}
    (hLen : unit.length = unitLen) :
    unitsOf unitLen (unit ++ rest) = unit :: unitsOf unitLen rest := by
  unfold unitsOf
  have hCount :
      ((unit ++ rest).length + unitLen - 1) / unitLen =
        (rest.length + unitLen - 1) / unitLen + 1 := by
    rw [List.length_append, hLen]
    have hSum :
        unitLen + rest.length + unitLen - 1 = (rest.length + unitLen - 1) + unitLen := by
      omega
    rw [hSum, Nat.add_div_right _ hUnit]
  rw [hCount, List.range_succ_eq_map]
  simp only [List.map_cons, List.map_map]
  congr 1
  · simp [hLen]
  · apply List.map_congr_left
    intro index _
    simp only [Function.comp]
    have hIndex : (index + 1) * unitLen = unit.length + index * unitLen := by
      rw [hLen, Nat.succ_mul]
      omega
    rw [hIndex, List.drop_append, List.drop_eq_nil_of_le (Nat.le_add_right _ _),
      Nat.add_sub_cancel_left, List.nil_append]

/-- The unit the storage observer classifies: a 32-byte word
(`STORAGE_OBSERVER_UNIT_BYTES`). -/
def storageObserverUnitBytes : Nat := 32

/-- A sealed record's unit is the unit the observer classifies. -/
theorem sealedUnitBytes_eq_storageObserverUnitBytes :
    sealedUnitBytes = storageObserverUnitBytes := by
  rfl

example : isUpdateWrite 2 [1, 2, 3, 4, 5] [2, 3, 4, 5, 6] = true := by decide
-- One unit unchanged, zero before or zero after: not an update, though the
-- record as a whole changes.
example : isUpdateWrite 2 [1, 2, 3, 4, 5] [2, 3, 3, 4, 6] = false := by decide
example : classifyWrite [1, 2, 3, 4, 5] [2, 3, 3, 4, 6] = StoreWriteClass.update := by decide
example : isUpdateWrite 2 [1, 2, 0, 0, 5] [2, 3, 4, 5, 6] = false := by decide
example : isUpdateWrite 2 [1, 2, 3, 4, 5] [2, 3, 4, 5, 0] = false := by decide
example : isUpdateWrite 2 [1, 2, 3, 4] [2, 3, 4, 5, 6] = false := by decide

/-! ## The unit codec

A record is a whole number of units of `unitLen` bytes. Each unit is one
marker byte and `unitLen - 1` bytes of content; the content's last unit is
filled with zeros. Every unit of a record carries the same marker, one of
the two of `sealedMarkers`. A record that replaces none carries the first; a
record written over another carries the one its predecessor does not
(`next_marker`). So no unit of a record is zero, and no unit of a record
equals the unit it replaces, whatever the content is: the write is an
`Update` in every unit (`isUpdateWrite_of_markers`).

The definitions model `write_units`, `read_units`, `record_marker` and
`next_marker` of `runtime/uo-store/src/generated_codec.rs`. The unit length
is a parameter of every statement, with `2 ≤ unitLen` where a unit must hold
content; the runtime's is `sealedUnitBytes`. That the Rust functions compute
these models is tested (`runtime/uo-store/src/codec.rs`), not proved. -/

/-- One of the two markers. -/
def ValidMarker (marker : Nat) : Prop :=
  marker = 165 ∨ marker = 90

instance (marker : Nat) : Decidable (ValidMarker marker) := by
  unfold ValidMarker
  infer_instance

/-- `next_marker`: the marker of a record written over one that carries
`marker`, the other of the two. -/
def nextMarker? (marker : Nat) : Option Nat :=
  if marker = 165 then some 90 else if marker = 90 then some 165 else none

/-- The units of `contentLen` bytes of content: a unit holds its marker and
`unitLen - 1` bytes, so this is `contentLen / (unitLen - 1)` rounded up. -/
def unitCount (unitLen contentLen : Nat) : Nat :=
  (contentLen + (unitLen - 2)) / (unitLen - 1)

/-- `count` units: in each the marker, then the next `unitLen - 1` bytes. -/
def frameUnits (unitLen marker : Nat) : Nat → List Nat → List Nat
  | 0, _ => []
  | count + 1, padded =>
      marker :: padded.take (unitLen - 1) ++
        frameUnits unitLen marker count (padded.drop (unitLen - 1))

/-- The content with the zeros that fill its last unit. -/
def padContent (unitLen : Nat) (content : List Nat) : List Nat :=
  content ++
    zeroedBytes ((unitLen - 1) * unitCount unitLen content.length - content.length)

/-- `write_units`: the record of `content` under `marker`. -/
def encodeUnits (unitLen marker : Nat) (content : List Nat) : List Nat :=
  frameUnits unitLen marker (unitCount unitLen content.length) (padContent unitLen content)

/-- The bytes that `count` units hold after their markers; `none` unless the
record is `count` units that each begin with `marker`. -/
def unframeUnits (unitLen marker : Nat) : Nat → List Nat → Option (List Nat)
  | 0, encoded => if encoded = [] then some [] else none
  | _ + 1, [] => none
  | count + 1, head :: tail =>
      if head = marker ∧ unitLen - 1 ≤ tail.length then
        match unframeUnits unitLen marker count (tail.drop (unitLen - 1)) with
        | none => none
        | some rest => some (tail.take (unitLen - 1) ++ rest)
      else none

/-- `read_units`: the record's marker and its `contentLen` bytes of content.
`none` unless the record has the units of that much content, its units carry
one valid marker, and the bytes after the content are zero. -/
def decodeUnitsInto? (unitLen contentLen : Nat) (encoded : List Nat) :
    Option (Nat × List Nat) :=
  match encoded.head? with
  | none => none
  | some marker =>
      if ValidMarker marker then
        match unframeUnits unitLen marker (unitCount unitLen contentLen) encoded with
        | none => none
        | some padded =>
            if padded.drop contentLen = zeroedBytes (padded.length - contentLen) then
              some (marker, padded.take contentLen)
            else none
      else none

/-- Whether `bytes` is `count` units of `unitLen` bytes that each begin with
`marker`. -/
def unitsCarry (unitLen marker : Nat) : Nat → List Nat → Bool
  | 0, bytes => bytes.isEmpty
  | count + 1, bytes =>
      bytes.head? == some marker && decide (unitLen ≤ bytes.length) &&
        unitsCarry unitLen marker count (bytes.drop unitLen)

/-- `record_marker`: the marker every unit of a record carries. `none` when
the bytes are not a whole number of units, the first marker is neither of
the two, or a unit carries another: a unit that is zero has no marker. -/
def recordMarker? (unitLen : Nat) (encoded : List Nat) : Option Nat :=
  match encoded.head? with
  | none => none
  | some marker =>
      if ValidMarker marker ∧
          unitsCarry unitLen marker (encoded.length / unitLen) encoded = true then
        some marker
      else none

theorem validMarker_iff_mem (marker : Nat) :
    ValidMarker marker ↔ marker ∈ sealedMarkers := by
  simp [ValidMarker, sealedMarkers]

theorem validMarker_pos {marker : Nat} (h : ValidMarker marker) : 0 < marker := by
  unfold ValidMarker at h
  omega

theorem validMarker_validByte {marker : Nat} (h : ValidMarker marker) :
    ValidByte marker := by
  unfold ValidMarker at h
  unfold ValidByte
  omega

/-- The next marker of a valid marker is the other valid one. -/
theorem nextMarker?_some {marker next : Nat} (h : nextMarker? marker = some next) :
    ValidMarker marker ∧ ValidMarker next ∧ marker ≠ next := by
  unfold nextMarker? at h
  unfold ValidMarker
  by_cases h165 : marker = 165
  · simp [h165] at h
    omega
  · by_cases h90 : marker = 90
    · simp [h90] at h
      omega
    · simp [h165, h90] at h

theorem nextMarker?_of_valid {marker : Nat} (h : ValidMarker marker) :
    ∃ next, nextMarker? marker = some next := by
  unfold ValidMarker at h
  rcases h with h | h
  · exact ⟨90, by simp [nextMarker?, h]⟩
  · exact ⟨165, by simp [nextMarker?, h]⟩

/-- The units of a record hold its content. -/
theorem unitCount_covers {unitLen : Nat} (hUnit : 2 ≤ unitLen) (contentLen : Nat) :
    contentLen ≤ (unitLen - 1) * unitCount unitLen contentLen := by
  unfold unitCount
  have hPos : 0 < unitLen - 1 := by omega
  have h := Nat.lt_mul_div_succ (contentLen + (unitLen - 2)) hPos
  rw [Nat.mul_add, Nat.mul_one] at h
  generalize (unitLen - 1) * ((contentLen + (unitLen - 2)) / (unitLen - 1)) = product at h ⊢
  omega

theorem unitCount_pos {unitLen contentLen : Nat} (hUnit : 2 ≤ unitLen)
    (hContent : 0 < contentLen) : 0 < unitCount unitLen contentLen := by
  unfold unitCount
  apply Nat.div_pos
  · omega
  · omega

theorem padContent_length {unitLen : Nat} (hUnit : 2 ≤ unitLen) (content : List Nat) :
    (padContent unitLen content).length =
      (unitLen - 1) * unitCount unitLen content.length := by
  have hCovers := unitCount_covers hUnit content.length
  unfold padContent
  rw [List.length_append, zeroedBytes_length]
  omega

theorem frameUnits_length {unitLen marker : Nat} (hUnit : 1 ≤ unitLen) :
    ∀ (count : Nat) (padded : List Nat),
      padded.length = (unitLen - 1) * count →
        (frameUnits unitLen marker count padded).length = unitLen * count := by
  intro count
  induction count with
  | zero =>
      intro padded _
      simp [frameUnits]
  | succ count ih =>
      intro padded hLen
      rw [Nat.mul_succ] at hLen
      have hRest : (padded.drop (unitLen - 1)).length = (unitLen - 1) * count := by
        rw [List.length_drop]
        omega
      have hTake : (padded.take (unitLen - 1)).length = unitLen - 1 := by
        rw [List.length_take]
        omega
      simp only [frameUnits, List.length_cons, List.length_append, hTake, ih _ hRest]
      rw [Nat.mul_succ]
      omega

/-- A byte of framed units is the marker or a byte of what they hold. -/
theorem mem_frameUnits {unitLen marker byte : Nat} :
    ∀ (count : Nat) (padded : List Nat),
      byte ∈ frameUnits unitLen marker count padded →
        byte = marker ∨ byte ∈ padded := by
  intro count
  induction count with
  | zero =>
      intro padded hMem
      simp [frameUnits] at hMem
  | succ count ih =>
      intro padded hMem
      simp only [frameUnits, List.mem_append, List.mem_cons] at hMem
      rcases hMem with (hMarker | hTake) | hRest
      · exact Or.inl hMarker
      · exact Or.inr (List.mem_of_mem_take hTake)
      · rcases ih _ hRest with hMarker | hDrop
        · exact Or.inl hMarker
        · exact Or.inr (List.mem_of_mem_drop hDrop)

theorem unitsCarry_length {unitLen marker : Nat} :
    ∀ (count : Nat) (bytes : List Nat),
      unitsCarry unitLen marker count bytes = true →
        bytes.length = unitLen * count := by
  intro count
  induction count with
  | zero =>
      intro bytes h
      simp [unitsCarry] at h
      simp [h]
  | succ count ih =>
      intro bytes h
      simp only [unitsCarry, Bool.and_eq_true, decide_eq_true_eq] at h
      have hRest := ih _ h.2
      rw [List.length_drop] at hRest
      rw [Nat.mul_succ]
      omega

theorem unitsCarry_frameUnits {unitLen marker : Nat} (hUnit : 1 ≤ unitLen) :
    ∀ (count : Nat) (padded : List Nat),
      padded.length = (unitLen - 1) * count →
        unitsCarry unitLen marker count (frameUnits unitLen marker count padded) = true := by
  intro count
  induction count with
  | zero =>
      intro padded _
      simp [frameUnits, unitsCarry]
  | succ count ih =>
      intro padded hLen
      rw [Nat.mul_succ] at hLen
      have hRest : (padded.drop (unitLen - 1)).length = (unitLen - 1) * count := by
        rw [List.length_drop]
        omega
      have hTake : (padded.take (unitLen - 1)).length = unitLen - 1 := by
        rw [List.length_take]
        omega
      have hHead :
          (marker :: padded.take (unitLen - 1)).length = unitLen := by
        simp only [List.length_cons, hTake]
        omega
      have hDrop :
          (marker :: padded.take (unitLen - 1) ++
              frameUnits unitLen marker count (padded.drop (unitLen - 1))).drop unitLen =
            frameUnits unitLen marker count (padded.drop (unitLen - 1)) := by
        exact List.drop_left' hHead
      simp only [unitsCarry, frameUnits, Bool.and_eq_true, decide_eq_true_eq]
      refine ⟨⟨by simp, ?_⟩, ?_⟩
      · simp only [List.length_cons, List.length_append, hTake]
        omega
      · rw [hDrop]
        exact ih _ hRest

theorem unframeUnits_frameUnits {unitLen marker : Nat} :
    ∀ (count : Nat) (padded : List Nat),
      padded.length = (unitLen - 1) * count →
        unframeUnits unitLen marker count (frameUnits unitLen marker count padded) =
          some padded := by
  intro count
  induction count with
  | zero =>
      intro padded hLen
      have hNil : padded = [] := by
        apply List.eq_nil_of_length_eq_zero
        simpa using hLen
      simp [frameUnits, unframeUnits, hNil]
  | succ count ih =>
      intro padded hLen
      rw [Nat.mul_succ] at hLen
      have hRest : (padded.drop (unitLen - 1)).length = (unitLen - 1) * count := by
        rw [List.length_drop]
        omega
      have hTake : (padded.take (unitLen - 1)).length = unitLen - 1 := by
        rw [List.length_take]
        omega
      have hLe :
          unitLen - 1 ≤
            (padded.take (unitLen - 1) ++
              frameUnits unitLen marker count (padded.drop (unitLen - 1))).length := by
        rw [List.length_append, hTake]
        omega
      have hDrop :
          (padded.take (unitLen - 1) ++
              frameUnits unitLen marker count (padded.drop (unitLen - 1))).drop (unitLen - 1) =
            frameUnits unitLen marker count (padded.drop (unitLen - 1)) :=
        List.drop_left' hTake
      have hTakeLeft :
          (padded.take (unitLen - 1) ++
              frameUnits unitLen marker count (padded.drop (unitLen - 1))).take (unitLen - 1) =
            padded.take (unitLen - 1) :=
        List.take_left' hTake
      simp only [frameUnits, unframeUnits, List.cons_append, true_and, hLe, if_true,
        hDrop, hTakeLeft, ih _ hRest, List.take_append_drop]

theorem unframeUnits_some {unitLen marker : Nat} :
    ∀ (count : Nat) (encoded padded : List Nat),
      unframeUnits unitLen marker count encoded = some padded →
        padded.length = (unitLen - 1) * count ∧
          encoded = frameUnits unitLen marker count padded := by
  intro count
  induction count with
  | zero =>
      intro encoded padded h
      unfold unframeUnits at h
      by_cases hNil : encoded = []
      · simp [hNil] at h
        subst h
        simp [hNil, frameUnits]
      · simp [hNil] at h
  | succ count ih =>
      intro encoded padded h
      cases encoded with
      | nil => simp [unframeUnits] at h
      | cons head tail =>
          unfold unframeUnits at h
          by_cases hHead : head = marker ∧ unitLen - 1 ≤ tail.length
          · rw [if_pos hHead] at h
            cases hRest : unframeUnits unitLen marker count (tail.drop (unitLen - 1)) with
            | none => simp [hRest] at h
            | some rest =>
                simp only [hRest, Option.some.injEq] at h
                subst h
                have hInner := ih _ _ hRest
                have hTake : (tail.take (unitLen - 1)).length = unitLen - 1 := by
                  rw [List.length_take]
                  omega
                refine ⟨?_, ?_⟩
                · rw [List.length_append, hTake, hInner.1, Nat.mul_succ]
                  omega
                · have hDropLeft :
                      (tail.take (unitLen - 1) ++ rest).drop (unitLen - 1) = rest :=
                    List.drop_left' hTake
                  have hTakeLeft :
                      (tail.take (unitLen - 1) ++ rest).take (unitLen - 1) =
                        tail.take (unitLen - 1) :=
                    List.take_left' hTake
                  simp only [frameUnits, hDropLeft, hTakeLeft]
                  rw [← hInner.2, hHead.1, List.cons_append, List.take_append_drop]
          · rw [if_neg hHead] at h
            simp at h

/-- A record's length is the public one: `unitLen` bytes for every
`unitLen - 1` bytes of content, rounded up. -/
theorem encodeUnits_length {unitLen : Nat} (hUnit : 2 ≤ unitLen) (marker : Nat)
    (content : List Nat) :
    (encodeUnits unitLen marker content).length =
      unitLen * unitCount unitLen content.length := by
  unfold encodeUnits
  exact frameUnits_length (by omega) _ _ (padContent_length hUnit content)

/-- A record of valid bytes under a valid marker is made of valid bytes. -/
theorem encodeUnits_validBytes {unitLen marker : Nat} (hMarker : ValidMarker marker)
    {content : List Nat} (hBytes : ∀ byte, byte ∈ content → ValidByte byte) :
    ∀ byte, byte ∈ encodeUnits unitLen marker content → ValidByte byte := by
  intro byte hMem
  unfold encodeUnits at hMem
  rcases mem_frameUnits _ _ hMem with hEq | hPadded
  · rw [hEq]
    exact validMarker_validByte hMarker
  · unfold padContent at hPadded
    rcases List.mem_append.mp hPadded with hContent | hZero
    · exact hBytes byte hContent
    · exact zeroedBytes_validBytes _ byte hZero

theorem encodeUnits_head? {unitLen marker : Nat} (hUnit : 2 ≤ unitLen)
    {content : List Nat} (hContent : content ≠ []) :
    (encodeUnits unitLen marker content).head? = some marker := by
  have hPos : 0 < unitCount unitLen content.length :=
    unitCount_pos hUnit (List.length_pos_iff.mpr hContent)
  obtain ⟨count, hCount⟩ : ∃ count, unitCount unitLen content.length = count + 1 :=
    ⟨unitCount unitLen content.length - 1, by omega⟩
  unfold encodeUnits
  rw [hCount]
  rfl

theorem unitsCarry_encodeUnits {unitLen : Nat} (hUnit : 2 ≤ unitLen) (marker : Nat)
    (content : List Nat) :
    unitsCarry unitLen marker (unitCount unitLen content.length)
        (encodeUnits unitLen marker content) = true := by
  unfold encodeUnits
  exact unitsCarry_frameUnits (by omega) _ _ (padContent_length hUnit content)

/-- Round trip: decoding a record gives back its marker and its content. -/
theorem decodeUnitsInto?_encodeUnits {unitLen marker : Nat} (hUnit : 2 ≤ unitLen)
    (hMarker : ValidMarker marker) {content : List Nat} (hContent : content ≠ []) :
    decodeUnitsInto? unitLen content.length (encodeUnits unitLen marker content) =
      some (marker, content) := by
  have hHead := encodeUnits_head? (marker := marker) hUnit hContent
  have hUnframe :
      unframeUnits unitLen marker (unitCount unitLen content.length)
          (encodeUnits unitLen marker content) =
        some (padContent unitLen content) := by
    unfold encodeUnits
    exact unframeUnits_frameUnits _ _ (padContent_length hUnit content)
  have hDrop :
      (padContent unitLen content).drop content.length =
        zeroedBytes ((padContent unitLen content).length - content.length) := by
    rw [padContent_length hUnit content]
    unfold padContent
    exact List.drop_left
  have hTake : (padContent unitLen content).take content.length = content := by
    unfold padContent
    exact List.take_left
  simp only [decodeUnitsInto?, hHead, if_pos hMarker, hUnframe, hDrop, if_true, hTake]

/-- A record that decodes is the encoding of what it decodes to: its units
carry one valid marker, and the bytes after the content are zero. -/
theorem decodeUnitsInto?_some {unitLen contentLen marker : Nat} (hUnit : 2 ≤ unitLen)
    {encoded content : List Nat}
    (hDecode : decodeUnitsInto? unitLen contentLen encoded = some (marker, content)) :
    ValidMarker marker ∧ content.length = contentLen ∧
      encoded = encodeUnits unitLen marker content := by
  cases hFirst : encoded.head? with
  | none => simp [decodeUnitsInto?, hFirst] at hDecode
  | some head =>
      simp only [decodeUnitsInto?, hFirst] at hDecode
      by_cases hValid : ValidMarker head
      · rw [if_pos hValid] at hDecode
        cases hUnframe :
            unframeUnits unitLen head (unitCount unitLen contentLen) encoded with
        | none => simp [hUnframe] at hDecode
        | some padded =>
            simp only [hUnframe] at hDecode
            by_cases hZeros :
                padded.drop contentLen = zeroedBytes (padded.length - contentLen)
            · rw [if_pos hZeros] at hDecode
              simp only [Option.some.injEq, Prod.mk.injEq] at hDecode
              obtain ⟨hHead, hContent⟩ := hDecode
              subst hHead
              have hShape := unframeUnits_some _ _ _ hUnframe
              have hCovers := unitCount_covers hUnit contentLen
              have hLen : content.length = contentLen := by
                rw [← hContent, List.length_take, hShape.1]
                omega
              refine ⟨hValid, hLen, ?_⟩
              have hPadded : padded = padContent unitLen content := by
                unfold padContent
                rw [hLen, ← hShape.1, ← hZeros, ← hContent, List.take_append_drop]
              rw [hShape.2]
              unfold encodeUnits
              rw [hLen, ← hPadded]
            · rw [if_neg hZeros] at hDecode
              simp at hDecode
      · rw [if_neg hValid] at hDecode
        simp at hDecode

/-- A record whose length is not the public one does not decode. -/
theorem decodeUnitsInto?_none_of_length_ne {unitLen contentLen : Nat}
    (hUnit : 2 ≤ unitLen) {encoded : List Nat}
    (hLen : encoded.length ≠ unitLen * unitCount unitLen contentLen) :
    decodeUnitsInto? unitLen contentLen encoded = none := by
  cases hDecode : decodeUnitsInto? unitLen contentLen encoded with
  | none => rfl
  | some result =>
      obtain ⟨marker, content⟩ := result
      have hSound := decodeUnitsInto?_some hUnit hDecode
      exfalso
      apply hLen
      rw [hSound.2.2, encodeUnits_length hUnit, hSound.2.1]

/-- The units of a record whose units carry `marker`: each begins with it. -/
theorem unitsOf_of_unitsCarry {unitLen marker : Nat} (hUnit : 0 < unitLen) :
    ∀ (count : Nat) (bytes : List Nat),
      unitsCarry unitLen marker count bytes = true →
        ∀ unit ∈ unitsOf unitLen bytes, unit.head? = some marker := by
  intro count
  induction count with
  | zero =>
      intro bytes h unit hMem
      simp [unitsCarry] at h
      rw [h, unitsOf_nil hUnit] at hMem
      simp at hMem
  | succ count ih =>
      intro bytes h unit hMem
      simp only [unitsCarry, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
      obtain ⟨⟨hHead, hLe⟩, hRest⟩ := h
      have hTake : (bytes.take unitLen).length = unitLen := by
        rw [List.length_take]
        omega
      have hSplit : bytes = bytes.take unitLen ++ bytes.drop unitLen :=
        (List.take_append_drop unitLen bytes).symm
      rw [hSplit, unitsOf_append hUnit hTake] at hMem
      rcases List.mem_cons.mp hMem with hEq | hTail
      · rw [hEq]
        cases bytes with
        | nil => simp at hHead
        | cons first others =>
            obtain ⟨width, hWidth⟩ : ∃ width, unitLen = width + 1 := ⟨unitLen - 1, by omega⟩
            rw [hWidth]
            simpa using hHead
      · exact ih _ hRest unit hTail

theorem unitsCarry_all_update {unitLen oldMarker newMarker : Nat} (hUnit : 0 < unitLen)
    (hOldPos : 0 < oldMarker) (hNewPos : 0 < newMarker) (hNe : oldMarker ≠ newMarker) :
    ∀ (count : Nat) (old new : List Nat),
      unitsCarry unitLen oldMarker count old = true →
        unitsCarry unitLen newMarker count new = true →
          (((unitsOf unitLen old).zip (unitsOf unitLen new)).all fun units =>
            decide (classifyWrite units.1 units.2 = StoreWriteClass.update)) = true := by
  intro count
  induction count with
  | zero =>
      intro old new hOld hNew
      simp [unitsCarry] at hOld hNew
      rw [hOld, hNew, unitsOf_nil hUnit]
      rfl
  | succ count ih =>
      intro old new hOld hNew
      have hOldUnits := unitsOf_of_unitsCarry hUnit _ _ hOld
      have hNewUnits := unitsOf_of_unitsCarry hUnit _ _ hNew
      simp only [unitsCarry, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at hOld hNew
      obtain ⟨⟨_, hOldLe⟩, hOldRest⟩ := hOld
      obtain ⟨⟨_, hNewLe⟩, hNewRest⟩ := hNew
      have hOldTake : (old.take unitLen).length = unitLen := by
        rw [List.length_take]
        omega
      have hNewTake : (new.take unitLen).length = unitLen := by
        rw [List.length_take]
        omega
      have hOldSplit : old = old.take unitLen ++ old.drop unitLen :=
        (List.take_append_drop unitLen old).symm
      have hNewSplit : new = new.take unitLen ++ new.drop unitLen :=
        (List.take_append_drop unitLen new).symm
      rw [hOldSplit, unitsOf_append hUnit hOldTake] at hOldUnits ⊢
      rw [hNewSplit, unitsOf_append hUnit hNewTake] at hNewUnits ⊢
      have hHead :
          classifyWrite (old.take unitLen) (new.take unitLen) = StoreWriteClass.update :=
        classifyWrite_update_of_heads
          (hOldUnits _ (List.mem_cons_self))
          (hNewUnits _ (List.mem_cons_self))
          hOldPos hNewPos hNe
      simp only [List.zip_cons_cons, List.all_cons, hHead, decide_true, Bool.true_and]
      exact ih _ _ hOldRest hNewRest

theorem recordMarker?_some {unitLen marker : Nat} {encoded : List Nat}
    (h : recordMarker? unitLen encoded = some marker) :
    ValidMarker marker ∧
      unitsCarry unitLen marker (encoded.length / unitLen) encoded = true := by
  cases hFirst : encoded.head? with
  | none => simp [recordMarker?, hFirst] at h
  | some head =>
      simp only [recordMarker?, hFirst] at h
      by_cases hCond :
          ValidMarker head ∧
            unitsCarry unitLen head (encoded.length / unitLen) encoded = true
      · rw [if_pos hCond] at h
        simp only [Option.some.injEq] at h
        subst h
        exact hCond
      · rw [if_neg hCond] at h
        simp at h

/-- Every unit different from its predecessor: a record written over a record
of the same length that carries the other marker is an `Update` in every
unit, whatever the two records hold besides their markers. -/
theorem isUpdateWrite_of_markers {unitLen oldMarker newMarker : Nat} (hUnit : 0 < unitLen)
    {old new : List Nat}
    (hOld : recordMarker? unitLen old = some oldMarker)
    (hNew : recordMarker? unitLen new = some newMarker)
    (hNe : oldMarker ≠ newMarker)
    (hLen : old.length = new.length) :
    isUpdateWrite unitLen old new = true := by
  have hOldShape := recordMarker?_some hOld
  have hNewShape := recordMarker?_some hNew
  have hNonempty : new ≠ [] := by
    intro hNil
    rw [hNil] at hNew
    simp [recordMarker?] at hNew
  have hAll :=
    unitsCarry_all_update hUnit (validMarker_pos hOldShape.1) (validMarker_pos hNewShape.1)
      hNe (new.length / unitLen) old new (by rw [← hLen]; exact hOldShape.2) hNewShape.2
  simp only [isUpdateWrite, Bool.and_eq_true, beq_iff_eq, Bool.not_eq_true',
    List.isEmpty_eq_false_iff]
  exact ⟨⟨hLen, hNonempty⟩, hAll⟩

/-- The marker of an encoded record is the one it was written with. -/
theorem recordMarker?_encodeUnits {unitLen marker : Nat} (hUnit : 2 ≤ unitLen)
    (hMarker : ValidMarker marker) {content : List Nat} (hContent : content ≠ []) :
    recordMarker? unitLen (encodeUnits unitLen marker content) = some marker := by
  have hHead := encodeUnits_head? (marker := marker) hUnit hContent
  have hCount :
      (encodeUnits unitLen marker content).length / unitLen =
        unitCount unitLen content.length := by
    rw [encodeUnits_length hUnit]
    exact Nat.mul_div_cancel_left _ (by omega)
  have hCarry :
      unitsCarry unitLen marker ((encodeUnits unitLen marker content).length / unitLen)
          (encodeUnits unitLen marker content) = true := by
    rw [hCount]
    exact unitsCarry_encodeUnits hUnit marker content
  simp only [recordMarker?, hHead, if_pos (And.intro hMarker hCarry)]

/-- Every unit nonzero: each unit of an encoded record begins with the
marker. -/
theorem encodeUnits_units_nonzero {unitLen marker : Nat} (hUnit : 2 ≤ unitLen)
    (hMarker : ValidMarker marker) (content : List Nat) :
    ∀ unit ∈ unitsOf unitLen (encodeUnits unitLen marker content),
      unit.head? = some marker ∧ allZero unit = false := by
  intro unit hMem
  have hHead :=
    unitsOf_of_unitsCarry (by omega) _ _ (unitsCarry_encodeUnits hUnit marker content)
      unit hMem
  exact ⟨hHead, allZero_false_of_head hHead (validMarker_pos hMarker)⟩

/-- A record with a zero unit has no marker. -/
theorem recordMarker?_none_of_zero_unit {unitLen : Nat} (hUnit : 0 < unitLen)
    {encoded unit : List Nat}
    (hMem : unit ∈ unitsOf unitLen encoded) (hZero : allZero unit = true) :
    recordMarker? unitLen encoded = none := by
  cases hMarker : recordMarker? unitLen encoded with
  | none => rfl
  | some marker =>
      have hShape := recordMarker?_some hMarker
      have hHead := unitsOf_of_unitsCarry hUnit _ _ hShape.2 unit hMem
      rw [allZero_false_of_head hHead (validMarker_pos hShape.1)] at hZero
      cases hZero

/-- A record with a zero unit does not decode. -/
theorem decodeUnitsInto?_none_of_zero_unit {unitLen contentLen : Nat} (hUnit : 2 ≤ unitLen)
    {encoded unit : List Nat}
    (hMem : unit ∈ unitsOf unitLen encoded) (hZero : allZero unit = true) :
    decodeUnitsInto? unitLen contentLen encoded = none := by
  cases hDecode : decodeUnitsInto? unitLen contentLen encoded with
  | none => rfl
  | some result =>
      obtain ⟨marker, content⟩ := result
      have hSound := decodeUnitsInto?_some hUnit hDecode
      rw [hSound.2.2] at hMem
      have hNonzero := encodeUnits_units_nonzero hUnit hSound.1 content unit hMem
      rw [hNonzero.2] at hZero
      cases hZero

/-- The reseal of a record: writing `content` over a record that has a
marker, under the marker `next_marker` gives, is an `Update` in every unit. -/
theorem isUpdateWrite_encodeUnits {unitLen oldMarker newMarker : Nat} (hUnit : 2 ≤ unitLen)
    {old content : List Nat}
    (hOld : recordMarker? unitLen old = some oldMarker)
    (hNext : nextMarker? oldMarker = some newMarker)
    (hContent : content ≠ [])
    (hLen : old.length = unitLen * unitCount unitLen content.length) :
    isUpdateWrite unitLen old (encodeUnits unitLen newMarker content) = true := by
  have hNextShape := nextMarker?_some hNext
  exact
    isUpdateWrite_of_markers (by omega) hOld
      (recordMarker?_encodeUnits hUnit hNextShape.2.1 hContent) hNextShape.2.2
      (by rw [hLen, encodeUnits_length hUnit])

example : unitCount 32 60 = 2 := by decide
example : unitCount 32 93 = 3 := by decide
example : encodeUnits 4 165 [1, 2, 3, 4] = [165, 1, 2, 3, 165, 4, 0, 0] := by decide
example :
    decodeUnitsInto? 4 4 [165, 1, 2, 3, 165, 4, 0, 0] = some (165, [1, 2, 3, 4]) := by
  decide
-- A zero unit, a unit with the other marker, and a byte after the content:
-- none of them decodes.
example : decodeUnitsInto? 4 4 [165, 1, 2, 3, 0, 0, 0, 0] = none := by decide
example : decodeUnitsInto? 4 4 [165, 1, 2, 3, 90, 4, 0, 0] = none := by decide
example : decodeUnitsInto? 4 4 [165, 1, 2, 3, 165, 4, 0, 7] = none := by decide
-- The same content under the other marker: an update in both units.
example :
    isUpdateWrite 4 [165, 1, 2, 3, 165, 4, 0, 0] (encodeUnits 4 90 [1, 2, 3, 4]) = true := by
  decide

/-! ## Sealed records

The content of a sealed record is the nonce, the ciphertext and the tag of
one ChaCha20-Poly1305 seal; the record is the unit codec's encoding of that
content at `sealedUnitBytes`. -/

/-- The bytes of a sealed record besides its markers (`sealed_content_len`). -/
def sealedContentLen (payloadLen : Nat) : Nat :=
  sealedNonceBytes + payloadLen + sealedTagBytes

/-- The units of a sealed record (`sealed_unit_count`). -/
def sealedUnitCount (payloadLen : Nat) : Nat :=
  unitCount sealedUnitBytes (sealedContentLen payloadLen)

/-- The length of a sealed record (`sealed_encoded_len`): a function of the
payload's length alone. -/
def sealedEncodedLen (payloadLen : Nat) : Nat :=
  sealedUnitBytes * sealedUnitCount payloadLen

/-- What the storage observer finds in a sealed slot: the public length, and
one marker in every unit. -/
def UoStoreSlotCiphertextShape
    (payloadLen : Nat)
    (encoded : List Nat) : Prop :=
  encoded.length = sealedEncodedLen payloadLen ∧
    ∃ marker, recordMarker? sealedUnitBytes encoded = some marker

structure SealedRecordParts where
  marker : Nat
  nonce : List Nat
  ciphertext : List Nat
  tag : List Nat
deriving Repr, DecidableEq

def SealedRecordParts.ValidShape
    (payloadLen : Nat)
    (parts : SealedRecordParts) : Prop :=
  parts.nonce.length = sealedNonceBytes ∧
    parts.ciphertext.length = payloadLen ∧
    parts.tag.length = sealedTagBytes

def SealedRecordParts.ValidOpenShape
    (payloadLen : Nat)
    (parts : SealedRecordParts) : Prop :=
  parts.ValidShape payloadLen ∧
    ValidMarker parts.marker

/-- The content of the record: what its units hold after their markers. -/
def SealedRecordParts.bytes
    (parts : SealedRecordParts) : List Nat :=
  parts.nonce ++ parts.ciphertext ++ parts.tag

def sealedRecordParts
    (payloadLen marker : Nat)
    (content : List Nat) : SealedRecordParts :=
  let afterNonce := content.drop sealedNonceBytes
  { marker := marker
  , nonce := content.take sealedNonceBytes
  , ciphertext := afterNonce.take payloadLen
  , tag := (afterNonce.drop payloadLen).take sealedTagBytes
  }

def splitSealedRecord?
    (payloadLen marker : Nat)
    (content : List Nat) : Option SealedRecordParts :=
  if content.length = sealedContentLen payloadLen then
    some (sealedRecordParts payloadLen marker content)
  else
    none

/-- The record of a seal: its content in units under its marker. -/
def encodeSealedRecord
    (parts : SealedRecordParts) : List Nat :=
  encodeUnits sealedUnitBytes parts.marker parts.bytes

def decodeSealedRecord?
    (payloadLen : Nat)
    (encoded : List Nat) : Option SealedRecordParts :=
  match decodeUnitsInto? sealedUnitBytes (sealedContentLen payloadLen) encoded with
  | none => none
  | some (marker, content) => splitSealedRecord? payloadLen marker content

def sealAndWipeIntoSliceAccepted
    (payloadLen outLen : Nat) : Prop :=
  outLen = sealedEncodedLen payloadLen

def openBoxedPayloadShape?
    (payloadLen : Nat)
    (encoded : List Nat) : Option Nat :=
  match decodeSealedRecord? payloadLen encoded with
  | none => none
  | some parts => some parts.ciphertext.length

theorem sealedUnitBytes_two_le : 2 ≤ sealedUnitBytes := by
  decide

theorem sealedEncodedLen_public_formula
    (payloadLen : Nat) :
    sealedEncodedLen payloadLen =
      sealedUnitBytes *
        unitCount sealedUnitBytes (sealedNonceBytes + payloadLen + sealedTagBytes) := by
  rfl

theorem sealedContentLen_public_formula
    (payloadLen : Nat) :
    sealedContentLen payloadLen =
      sealedNonceBytes + payloadLen + sealedTagBytes := by
  rfl

theorem sealAndWipeIntoSliceAccepted_exactLength
    (payloadLen : Nat) :
    sealAndWipeIntoSliceAccepted payloadLen
      (sealedEncodedLen payloadLen) := by
  rfl

theorem sealAndWipeIntoSliceAccepted_rejectsLengthMismatch
    {payloadLen outLen : Nat}
    (hLen : outLen ≠ sealedEncodedLen payloadLen) :
    ¬ sealAndWipeIntoSliceAccepted payloadLen outLen := by
  intro hAccepted
  exact hLen hAccepted

theorem sealedRecordParts_validShape_of_length
    {payloadLen marker : Nat}
    {content : List Nat}
    (hLen : content.length = sealedContentLen payloadLen) :
    (sealedRecordParts payloadLen marker content).ValidShape payloadLen := by
  unfold SealedRecordParts.ValidShape sealedRecordParts
  unfold sealedContentLen at hLen
  simp only [List.length_take, List.length_drop, hLen]
  omega

theorem sealedRecordParts_bytes_of_length
    {payloadLen marker : Nat}
    {content : List Nat}
    (hLen : content.length = sealedContentLen payloadLen) :
    (sealedRecordParts payloadLen marker content).bytes = content := by
  have hTag :
      ((content.drop sealedNonceBytes).drop payloadLen).take sealedTagBytes =
        (content.drop sealedNonceBytes).drop payloadLen := by
    apply List.take_of_length_le
    rw [List.length_drop, List.length_drop, hLen]
    unfold sealedContentLen
    omega
  unfold SealedRecordParts.bytes sealedRecordParts
  simp only [hTag]
  rw [List.append_assoc, List.take_append_drop, List.take_append_drop]

theorem sealedRecordParts_bytes_valid_of_length
    {payloadLen marker : Nat}
    {content : List Nat}
    (hLen : content.length = sealedContentLen payloadLen)
    (hContentBytes : ∀ byte, byte ∈ content → ValidByte byte) :
    ∀ byte,
      byte ∈ (sealedRecordParts payloadLen marker content).bytes →
        ValidByte byte := by
  intro byte hMem
  exact
    hContentBytes byte
      (by
        rw [sealedRecordParts_bytes_of_length hLen] at hMem
        exact hMem)

theorem SealedRecordParts.bytes_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.bytes.length = sealedContentLen payloadLen := by
  unfold SealedRecordParts.ValidShape at hShape
  unfold SealedRecordParts.bytes
  rcases hShape with ⟨hNonceLen, hCiphertextLen, hTagLen⟩
  simp only [List.length_append, hNonceLen, hCiphertextLen, hTagLen, sealedContentLen]

theorem SealedRecordParts.bytes_ne_nil_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.bytes ≠ [] := by
  intro hNil
  have hLen := SealedRecordParts.bytes_length_of_validShape hShape
  rw [hNil] at hLen
  unfold sealedContentLen sealedNonceBytes at hLen
  simp at hLen
  omega

theorem sealedRecordParts_bytes_roundtrip
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    sealedRecordParts payloadLen parts.marker parts.bytes = parts := by
  cases parts with
  | mk marker nonce ciphertext tag =>
      unfold SealedRecordParts.ValidShape at hShape
      unfold SealedRecordParts.bytes
      rcases hShape with ⟨hNonceLen, hCiphertextLen, hTagLen⟩
      have hTagLenLe : tag.length ≤ 16 := by
        have hTagLenEq : tag.length = 16 := by
          simpa [sealedTagBytes] using hTagLen
        omega
      simp [sealedRecordParts, hNonceLen, hCiphertextLen,
        sealedNonceBytes, sealedTagBytes,
        List.take_of_length_le hTagLenLe]

theorem splitSealedRecord_some_validShape
    {payloadLen marker : Nat}
    {content : List Nat}
    {parts : SealedRecordParts}
    (hSplit : splitSealedRecord? payloadLen marker content = some parts) :
    content.length = sealedContentLen payloadLen ∧
      parts.ValidShape payloadLen ∧
      parts.marker = marker := by
  unfold splitSealedRecord? at hSplit
  split at hSplit
  · rename_i hLen
    cases hSplit
    exact ⟨hLen, sealedRecordParts_validShape_of_length hLen, rfl⟩
  · contradiction

theorem splitSealedRecord_some_bytes
    {payloadLen marker : Nat}
    {content : List Nat}
    {parts : SealedRecordParts}
    (hSplit : splitSealedRecord? payloadLen marker content = some parts) :
    parts.bytes = content := by
  unfold splitSealedRecord? at hSplit
  split at hSplit
  · rename_i hLen
    cases hSplit
    exact sealedRecordParts_bytes_of_length hLen
  · contradiction

/-- A sealed record's length is the public one. -/
theorem encodeSealedRecord_length
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    (encodeSealedRecord parts).length = sealedEncodedLen payloadLen := by
  unfold encodeSealedRecord
  rw [encodeUnits_length sealedUnitBytes_two_le,
    SealedRecordParts.bytes_length_of_validShape hShape]
  rfl

/-- A record that opens is the record of its parts, and its parts have the
public lengths and a valid marker. -/
theorem decodeSealedRecord_some_transport_sound
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    encoded.length = sealedEncodedLen payloadLen ∧
      parts.ValidOpenShape payloadLen ∧
      encoded = encodeSealedRecord parts ∧
      decodeUnitsInto? sealedUnitBytes (sealedContentLen payloadLen) encoded =
        some (parts.marker, parts.bytes) ∧
      splitSealedRecord? payloadLen parts.marker parts.bytes = some parts ∧
      parts.bytes.length = sealedContentLen payloadLen := by
  unfold decodeSealedRecord? at hDecode
  cases hUnits :
      decodeUnitsInto? sealedUnitBytes (sealedContentLen payloadLen) encoded with
  | none => simp [hUnits] at hDecode
  | some result =>
      obtain ⟨marker, content⟩ := result
      simp only [hUnits] at hDecode
      have hSound := decodeUnitsInto?_some sealedUnitBytes_two_le hUnits
      have hSplitShape := splitSealedRecord_some_validShape hDecode
      have hPartsBytes := splitSealedRecord_some_bytes hDecode
      have hEncoded : encoded = encodeSealedRecord parts := by
        unfold encodeSealedRecord
        rw [hSplitShape.2.2, hPartsBytes]
        exact hSound.2.2
      have hShape : parts.ValidShape payloadLen := hSplitShape.2.1
      refine ⟨?_, ⟨hShape, ?_⟩, hEncoded, ?_, ?_, ?_⟩
      · rw [hEncoded]
        exact encodeSealedRecord_length hShape
      · rw [hSplitShape.2.2]
        exact hSound.1
      · rw [hSplitShape.2.2, hPartsBytes]
      · rw [hSplitShape.2.2, hPartsBytes]
        exact hDecode
      · exact SealedRecordParts.bytes_length_of_validShape hShape

theorem decodeSealedRecord_some_validOpenShape
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    encoded.length = sealedEncodedLen payloadLen ∧
      parts.ValidOpenShape payloadLen := by
  have hSound := decodeSealedRecord_some_transport_sound hDecode
  exact ⟨hSound.1, hSound.2.1⟩

theorem openBoxedPayloadShape?_some_payloadLen
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    openBoxedPayloadShape? payloadLen encoded = some payloadLen := by
  unfold openBoxedPayloadShape?
  rw [hDecode]
  have hOpenShape := (decodeSealedRecord_some_validOpenShape hDecode).2
  have hValidShape : parts.ValidShape payloadLen := hOpenShape.1
  unfold SealedRecordParts.ValidShape at hValidShape
  simp [hValidShape.2.1]

theorem decodeSealedRecord_none_of_encoded_length_ne
    {payloadLen : Nat}
    {encoded : List Nat}
    (hLen : encoded.length ≠ sealedEncodedLen payloadLen) :
    decodeSealedRecord? payloadLen encoded = none := by
  cases hDecode : decodeSealedRecord? payloadLen encoded with
  | none => rfl
  | some parts =>
      have hLenEq := (decodeSealedRecord_some_validOpenShape hDecode).1
      exact False.elim (hLen hLenEq)

/-- The record of parts with the public lengths and a valid marker has the
shape of a sealed slot. -/
theorem encodeSealedRecord_uoSlotCiphertextShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hOpenShape : parts.ValidOpenShape payloadLen) :
    UoStoreSlotCiphertextShape payloadLen (encodeSealedRecord parts) := by
  rcases hOpenShape with ⟨hShape, hMarker⟩
  exact
    ⟨ encodeSealedRecord_length hShape
    , parts.marker
    , recordMarker?_encodeUnits sealedUnitBytes_two_le hMarker
        (SealedRecordParts.bytes_ne_nil_of_validShape hShape)
    ⟩

theorem decodeSealedRecord_some_uoSlotCiphertextShape
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    UoStoreSlotCiphertextShape payloadLen encoded := by
  have hSound := decodeSealedRecord_some_transport_sound hDecode
  rw [hSound.2.2.1]
  exact encodeSealedRecord_uoSlotCiphertextShape hSound.2.1

/-- The content of a record that decodes at a sealed record's length splits
into the parts of a seal. -/
theorem decodeUnitsInto?_sealedRecordShape
    {payloadLen marker : Nat}
    {encoded content : List Nat}
    (hDecode :
      decodeUnitsInto? sealedUnitBytes (sealedContentLen payloadLen) encoded =
        some (marker, content)) :
    encoded.length = sealedEncodedLen payloadLen ∧
      content.length = sealedContentLen payloadLen ∧
      ∃ parts,
        splitSealedRecord? payloadLen marker content = some parts ∧
          parts.ValidOpenShape payloadLen := by
  have hSound := decodeUnitsInto?_some sealedUnitBytes_two_le hDecode
  have hShape :
      (sealedRecordParts payloadLen marker content).ValidShape payloadLen :=
    sealedRecordParts_validShape_of_length hSound.2.1
  refine ⟨?_, hSound.2.1, sealedRecordParts payloadLen marker content, ?_, ⟨hShape, hSound.1⟩⟩
  · rw [hSound.2.2, encodeUnits_length sealedUnitBytes_two_le, hSound.2.1]
    rfl
  · unfold splitSealedRecord?
    simp [hSound.2.1]

/-- Round trip of a sealed record. -/
theorem decodeSealedRecord_encodeSealedRecord
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hOpenShape : parts.ValidOpenShape payloadLen) :
    decodeSealedRecord? payloadLen (encodeSealedRecord parts) =
      some parts := by
  rcases hOpenShape with ⟨hShape, hMarker⟩
  have hContentLen := SealedRecordParts.bytes_length_of_validShape hShape
  have hRoundtrip := sealedRecordParts_bytes_roundtrip hShape
  have hUnits :
      decodeUnitsInto? sealedUnitBytes (sealedContentLen payloadLen)
          (encodeSealedRecord parts) =
        some (parts.marker, parts.bytes) := by
    unfold encodeSealedRecord
    rw [← hContentLen]
    exact
      decodeUnitsInto?_encodeUnits sealedUnitBytes_two_le hMarker
        (SealedRecordParts.bytes_ne_nil_of_validShape hShape)
  unfold decodeSealedRecord?
  rw [hUnits]
  simp [splitSealedRecord?, hContentLen, hRoundtrip]

/-- A record whose units carry a byte that is not one of the two markers does
not open. -/
theorem decodeSealedRecord_encodeSealedRecord_wrong_marker_none
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen)
    (hMarker : ¬ ValidMarker parts.marker) :
    decodeSealedRecord? payloadLen (encodeSealedRecord parts) = none := by
  cases hDecode : decodeSealedRecord? payloadLen (encodeSealedRecord parts) with
  | none => rfl
  | some decoded =>
      exfalso
      have hSound := decodeSealedRecord_some_transport_sound hDecode
      have hHeadParts :
          (encodeSealedRecord parts).head? = some parts.marker :=
        encodeUnits_head? sealedUnitBytes_two_le
          (SealedRecordParts.bytes_ne_nil_of_validShape hShape)
      have hHeadDecoded :
          (encodeSealedRecord decoded).head? = some decoded.marker :=
        encodeUnits_head? sealedUnitBytes_two_le
          (SealedRecordParts.bytes_ne_nil_of_validShape hSound.2.1.1)
      rw [← hSound.2.2.1, hHeadParts] at hHeadDecoded
      have hSame : parts.marker = decoded.marker := Option.some.inj hHeadDecoded
      exact hMarker (hSame ▸ hSound.2.1.2)

/-- A slot with a zero unit does not open. -/
theorem decodeSealedRecord_none_of_zero_unit
    {payloadLen : Nat}
    {encoded unit : List Nat}
    (hMem : unit ∈ unitsOf sealedUnitBytes encoded)
    (hZero : allZero unit = true) :
    decodeSealedRecord? payloadLen encoded = none := by
  unfold decodeSealedRecord?
  rw [decodeUnitsInto?_none_of_zero_unit sealedUnitBytes_two_le hMem hZero]

/-- The reseal of a sealed slot: a record written over a slot that has the
shape of a sealed one, under the marker `next_marker` gives for the slot's,
is an `Update` in every unit the storage observer classifies. The parts are
any of the public lengths: the claim does not rest on the nonce or on the
ciphertext. -/
theorem encodeSealedRecord_reseal_isUpdate
    {payloadLen oldMarker : Nat}
    {old : List Nat}
    {parts : SealedRecordParts}
    (hOldLen : old.length = sealedEncodedLen payloadLen)
    (hOldMarker : recordMarker? sealedUnitBytes old = some oldMarker)
    (hShape : parts.ValidShape payloadLen)
    (hNext : nextMarker? oldMarker = some parts.marker) :
    isUpdateWrite storageObserverUnitBytes old (encodeSealedRecord parts) = true := by
  rw [← sealedUnitBytes_eq_storageObserverUnitBytes]
  unfold encodeSealedRecord
  refine
    isUpdateWrite_encodeUnits sealedUnitBytes_two_le hOldMarker hNext
      (SealedRecordParts.bytes_ne_nil_of_validShape hShape) ?_
  rw [hOldLen, SealedRecordParts.bytes_length_of_validShape hShape]
  rfl

example : sealedEncodedLen 32 = 64 := by decide
example : sealedEncodedLen 65 = 96 := by decide

/-! ### W5.5: Concrete Rust StoreCipher surface obligations

The theorems below pin obligations of the concrete Rust StoreCipher surface
(`runtime/uo-store/src/generated_surface.rs`) at the Lean codec semantic
level. They project the abstract codec model onto the structural facts the
Rust seal/open implementation actually relies on (cipher-key length, marker
values, sealed-record component lengths, AAD shape). The probe
`runtime_crypto_primitive_identity_pinned` static-drift check pins the Rust
side; these Lean theorems pin the corresponding mathematical obligations
referenced by the WP5 paper-facing claims. -/

/-- The Lean cipher-key-length constant matches the Rust `key: [u8; 32]`
buffer pinned by the probe's crypto-primitive identity check. This makes the
RFC 8439 32-byte key length a Lean-side fact rather than only a Rust
source-pin. -/
theorem cipherKeyBytes_value :
    cipherKeyBytes = 32 := by
  rfl

/-- There are two markers, matching the Rust
`SEALED_MARKERS: [u8; 2] = [0xA5, 0x5A]` constant pinned by the static-drift
suite. -/
theorem sealedMarkers_length :
    sealedMarkers.length = 2 := by
  rfl

/-- Each marker is a byte and is not zero. This is why no unit of a sealed
record is zero. -/
theorem sealedMarkers_validBytes :
    ∀ marker, marker ∈ sealedMarkers → ValidByte marker ∧ 0 < marker := by
  intro marker hMem
  have hValid := (validMarker_iff_mem marker).mpr hMem
  exact ⟨validMarker_validByte hValid, validMarker_pos hValid⟩

/-- A sealed record is `sealedUnitBytes` bytes for each of its units, and its
units hold its content. This is the mathematical fact behind the lengths
`seal_and_wipe_units` and `open_boxed` hand to `write_units` and
`read_units`. -/
theorem sealedEncodedLen_eq_unitBytes_times_unitCount
    (payloadLen : Nat) :
    sealedEncodedLen payloadLen = sealedUnitBytes * sealedUnitCount payloadLen ∧
      sealedContentLen payloadLen ≤
        (sealedUnitBytes - 1) * sealedUnitCount payloadLen := by
  exact ⟨rfl, unitCount_covers sealedUnitBytes_two_le (sealedContentLen payloadLen)⟩

/-- A valid-shape sealed record's nonce component has the public
`sealedNonceBytes` length. This is the structural projection from
`SealedRecordParts.ValidShape` for the nonce field; matches the Rust
`Nonce::from_slice(&nonce_bytes)` 12-byte requirement. -/
theorem SealedRecordParts.nonce_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.nonce.length = sealedNonceBytes :=
  hShape.1

/-- A valid-shape sealed record's ciphertext component has length exactly
equal to the payload length. Matches the Rust convention that ChaCha20-Poly1305
in detached mode produces ciphertext of the same length as the plaintext
input. -/
theorem SealedRecordParts.ciphertext_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.ciphertext.length = payloadLen :=
  hShape.2.1

/-- A valid-shape sealed record's tag component has the public
`sealedTagBytes` length. Matches the Rust `Tag::from_slice(tag_bytes)`
16-byte requirement and the ChaCha20-Poly1305 detached-tag size from
RFC 8439. -/
theorem SealedRecordParts.tag_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.tag.length = sealedTagBytes :=
  hShape.2.2

/-- An open-shape sealed record's marker is one of the two. This is the
projection from `SealedRecordParts.ValidOpenShape`, mirroring the check of
`record_marker` on the open path. -/
theorem SealedRecordParts.marker_valid_of_validOpenShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidOpenShape payloadLen) :
    ValidMarker parts.marker :=
  hShape.2

/-- A successful `decodeSealedRecord?` outcome witnesses a valid marker.
This is the named theorem capturing the Rust open-path invariant that an
accepted sealed record carries one of the two markers in every unit. -/
theorem decodeSealedRecord_some_marker
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    ValidMarker parts.marker :=
  (decodeSealedRecord_some_validOpenShape hDecode).2.2

/-- A successful `decodeSealedRecord?` outcome witnesses the
component-length facts. This is the named theorem capturing the structural
decomposition fact at the open-shape level. -/
theorem decodeSealedRecord_some_componentLengths
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    parts.nonce.length = sealedNonceBytes ∧
      parts.ciphertext.length = payloadLen ∧
      parts.tag.length = sealedTagBytes := by
  have hShape := (decodeSealedRecord_some_validOpenShape hDecode).2.1
  exact ⟨hShape.1, hShape.2.1, hShape.2.2⟩

/-- The store-slot AAD constructed by `uoStoreSlotAad` is the deterministic
public concatenation `"uo_store:" ++ object`. This pins the AAD shape: the
AAD depends only on the public object identifier and a fixed public prefix,
so it carries no secret-dependent content. The Rust runtime's
`UoObjectStore` builds the AAD this way; this Lean theorem makes the
decomposition explicit at the codec layer. -/
theorem uoStoreSlotAad_prefix_publicShape
    (object : String) :
    uoStoreSlotAad object = "uo_store:" ++ object := by
  rfl

/-- The store-slot AAD shape is fully determined by the public object
identifier: two AAD bytes derived from the same object name agree. This
restates `uoStoreSlotAad_prefix_publicShape` as an extensionality fact that
is more directly useful when an AAD obligation is phrased as a same-object
agreement check. -/
theorem uoStoreSlotAad_publicProjection
    {objectA objectB : String}
    (hObject : objectA = objectB) :
    uoStoreSlotAad objectA = uoStoreSlotAad objectB := by
  rw [hObject]

/-! ## Seal nonces

A record's nonce is the count of the seals made under its key before it:
four zero bytes, then the count's eight bytes, most significant first. The
Rust `seal_nonce` builds the same bytes and `StoreCipher::next_seal_nonce`
hands out the counts. The theorems below are about this model. That the Rust
function computes it is tested (`seal_nonce_is_the_big_endian_counter` in
`runtime/uo-store/src/codec.rs`), not proved. -/

/-- The `width` base-256 digits of `n`, most significant first. Digits above
the width are dropped. -/
def natToBytesBE : Nat → Nat → List Nat
  | 0, _ => []
  | width + 1, n => natToBytesBE width (n / 256) ++ [n % 256]

/-- The number whose base-256 digits, most significant first, are `bytes`. -/
def bytesToNatBE (bytes : List Nat) : Nat :=
  bytes.foldl (fun acc byte => acc * 256 + byte) 0

theorem natToBytesBE_length (width n : Nat) :
    (natToBytesBE width n).length = width := by
  induction width generalizing n with
  | zero => rfl
  | succ width ih => simp [natToBytesBE, ih]

theorem natToBytesBE_validBytes (width n : Nat) :
    ∀ byte, byte ∈ natToBytesBE width n → ValidByte byte := by
  induction width generalizing n with
  | zero =>
    intro byte hMem
    simp [natToBytesBE] at hMem
  | succ width ih =>
    intro byte hMem
    simp only [natToBytesBE, List.mem_append, List.mem_singleton] at hMem
    rcases hMem with hMem | hMem
    · exact ih (n / 256) byte hMem
    · subst hMem
      unfold ValidByte
      exact Nat.mod_lt n (by decide)

/-- Reading the digits back gives the number, up to the width. -/
theorem bytesToNatBE_natToBytesBE (width n : Nat) :
    bytesToNatBE (natToBytesBE width n) = n % 256 ^ width := by
  induction width generalizing n with
  | zero => simp [natToBytesBE, bytesToNatBE, Nat.mod_one]
  | succ width ih =>
    have hPrefix := ih (n / 256)
    unfold bytesToNatBE at hPrefix
    simp only [natToBytesBE, bytesToNatBE, List.foldl_append, List.foldl_cons,
      List.foldl_nil]
    rw [hPrefix, Nat.pow_succ, Nat.mul_comm (256 ^ width) 256, Nat.mod_mul]
    omega

/-- Two numbers that fit the width and have the same digits are equal. -/
theorem natToBytesBE_injective
    {width a b : Nat}
    (hA : a < 256 ^ width)
    (hB : b < 256 ^ width)
    (hEq : natToBytesBE width a = natToBytesBE width b) :
    a = b := by
  have hRead := congrArg bytesToNatBE hEq
  rw [bytesToNatBE_natToBytesBE, bytesToNatBE_natToBytesBE,
    Nat.mod_eq_of_lt hA, Nat.mod_eq_of_lt hB] at hRead
  exact hRead

/-- The zero bytes ahead of the count in a nonce. -/
def sealNoncePrefixBytes : Nat := 4

/-- The bytes of the count in a nonce: a Rust `u64`. -/
def sealCounterBytes : Nat := 8

/-- One more than the largest count a nonce can carry: `2 ^ 64`. -/
def sealCounterLimit : Nat := 256 ^ sealCounterBytes

/-- The nonce of the seal numbered `counter` under a key. -/
def sealNonce (counter : Nat) : List Nat :=
  List.replicate sealNoncePrefixBytes 0 ++ natToBytesBE sealCounterBytes counter

theorem sealCounterLimit_value :
    sealCounterLimit = 2 ^ 64 := by
  decide

theorem sealNonce_length (counter : Nat) :
    (sealNonce counter).length = sealedNonceBytes := by
  simp [sealNonce, natToBytesBE_length, sealNoncePrefixBytes, sealCounterBytes,
    sealedNonceBytes]

theorem sealNonce_validBytes (counter : Nat) :
    ∀ byte, byte ∈ sealNonce counter → ValidByte byte := by
  intro byte hMem
  simp only [sealNonce, List.mem_append, List.mem_replicate] at hMem
  rcases hMem with hMem | hMem
  · rw [hMem.2]
    unfold ValidByte
    decide
  · exact natToBytesBE_validBytes sealCounterBytes counter byte hMem

/-- Two counts below the limit with the same nonce are the same count. -/
theorem sealNonce_injective
    {a b : Nat}
    (hA : a < sealCounterLimit)
    (hB : b < sealCounterLimit)
    (hEq : sealNonce a = sealNonce b) :
    a = b :=
  natToBytesBE_injective hA hB (List.append_cancel_left hEq)

/-- Different counts below the limit have different nonces. -/
theorem sealNonce_ne_of_counter_ne
    {a b : Nat}
    (hA : a < sealCounterLimit)
    (hB : b < sealCounterLimit)
    (hNe : a ≠ b) :
    sealNonce a ≠ sealNonce b :=
  fun hEq => hNe (sealNonce_injective hA hB hEq)

/-- The count 258 is the bytes `1, 2` after ten zero bytes. -/
example : sealNonce 258 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2] := by
  decide

/-- One step of the Rust `StoreCipher::next_seal_nonce`: with `seals` seals
made so far, the nonce of the next seal and the new count, or `none` once the
new count would not fit a `u64`. -/
def nextSealNonce? (seals : Nat) : Option (List Nat × Nat) :=
  if seals + 1 < sealCounterLimit then
    some (sealNonce seals, seals + 1)
  else
    none

theorem nextSealNonce?_some
    {seals next : Nat}
    {nonce : List Nat}
    (hNext : nextSealNonce? seals = some (nonce, next)) :
    nonce = sealNonce seals ∧ next = seals + 1 ∧ next < sealCounterLimit := by
  unfold nextSealNonce? at hNext
  by_cases hRoom : seals + 1 < sealCounterLimit
  · simp only [hRoom, if_true, Option.some.injEq, Prod.mk.injEq] at hNext
    exact ⟨hNext.1.symm, hNext.2.symm, hNext.2 ▸ hRoom⟩
  · simp [hRoom] at hNext

/-- The count is exhausted, and no nonce is handed out, once it reaches the
largest `u64`. -/
theorem nextSealNonce?_none_of_exhausted
    {seals : Nat}
    (hFull : sealCounterLimit ≤ seals + 1) :
    nextSealNonce? seals = none := by
  unfold nextSealNonce?
  have hRoom : ¬ seals + 1 < sealCounterLimit := Nat.not_lt.mpr hFull
  simp [hRoom]

/-- The nonces of up to `count` seals in a row, starting with `seals` seals
already made. The run stops early if the count is exhausted. -/
def sealNonceRun : Nat → Nat → List (List Nat)
  | _, 0 => []
  | seals, count + 1 =>
      match nextSealNonce? seals with
      | some (nonce, next) => nonce :: sealNonceRun next count
      | none => []

/-- Every nonce of a run is the nonce of a count at or after the run's
start. -/
theorem mem_sealNonceRun
    {seals count : Nat}
    {nonce : List Nat}
    (hMem : nonce ∈ sealNonceRun seals count) :
    ∃ counter,
      seals ≤ counter ∧ counter + 1 < sealCounterLimit ∧
        nonce = sealNonce counter := by
  induction count generalizing seals with
  | zero => simp [sealNonceRun] at hMem
  | succ count ih =>
    unfold sealNonceRun nextSealNonce? at hMem
    by_cases hRoom : seals + 1 < sealCounterLimit
    · simp only [hRoom, if_true, List.mem_cons] at hMem
      rcases hMem with hHead | hTail
      · exact ⟨seals, Nat.le_refl seals, hRoom, hHead⟩
      · obtain ⟨counter, hLe, hLt, hEq⟩ := ih hTail
        exact ⟨counter, Nat.le_of_succ_le hLe, hLt, hEq⟩
    · simp [hRoom] at hMem

/-- No nonce is handed out twice: the nonces of any run of seals under one
key are pairwise different. The count is kept with the key and only grows,
so this covers the seals of a call that is later dropped as well. -/
theorem sealNonceRun_nodup (seals count : Nat) :
    (sealNonceRun seals count).Nodup := by
  induction count generalizing seals with
  | zero => simp [sealNonceRun]
  | succ count ih =>
    unfold sealNonceRun nextSealNonce?
    by_cases hRoom : seals + 1 < sealCounterLimit
    · simp only [hRoom, if_true]
      rw [List.nodup_cons]
      refine ⟨?_, ih (seals + 1)⟩
      intro hMem
      obtain ⟨counter, hLe, hLt, hEq⟩ := mem_sealNonceRun hMem
      have hSame : seals = counter :=
        sealNonce_injective (Nat.lt_of_succ_lt hRoom) (Nat.lt_of_succ_lt hLt) hEq
      omega
    · simp [hRoom]

/-- Two runs that follow one another under a key share no nonce: the second
starts from the count the first reached. This is the case of a staged call
that is dropped and the call that follows it. -/
theorem sealNonceRun_disjoint_of_le
    {seals later countA countB : Nat}
    {nonce : List Nat}
    (hLater : seals + countA ≤ later)
    (hA : nonce ∈ sealNonceRun seals countA) :
    nonce ∉ sealNonceRun later countB := by
  intro hB
  obtain ⟨counterB, hLeB, hLtB, hEqB⟩ := mem_sealNonceRun hB
  have hBound :
      ∀ (count start : Nat) (candidate : List Nat),
        candidate ∈ sealNonceRun start count →
          ∃ counter,
            counter < start + count ∧ counter + 1 < sealCounterLimit ∧
              candidate = sealNonce counter := by
    intro count
    induction count with
    | zero =>
      intro start candidate hMem
      simp [sealNonceRun] at hMem
    | succ count ih =>
      intro start candidate hMem
      unfold sealNonceRun nextSealNonce? at hMem
      by_cases hRoom : start + 1 < sealCounterLimit
      · simp only [hRoom, if_true, List.mem_cons] at hMem
        rcases hMem with hHead | hTail
        · exact ⟨start, by omega, hRoom, hHead⟩
        · obtain ⟨counter, hLt, hFit, hEq⟩ := ih (start + 1) candidate hTail
          exact ⟨counter, by omega, hFit, hEq⟩
      · simp [hRoom] at hMem
  obtain ⟨counterA, hLtA, hFitA, hEqA⟩ := hBound countA seals nonce hA
  have hSame : counterA = counterB :=
    sealNonce_injective (Nat.lt_of_succ_lt hFitA) (Nat.lt_of_succ_lt hLtB)
      (hEqA.symm.trans hEqB)
  omega

/-- The nonces of a history of runs of seals under one key, in order. A run
is its start, the count of the seals made under the key before it, and the
most seals it makes. -/
def sealNonceHistory (runs : List (Nat × Nat)) : List (List Nat) :=
  runs.flatMap fun run => sealNonceRun run.1 run.2

/-- A history of runs under one key is continuous when every run starts at or
above the count each run before it reached: no run starts below a count an
earlier run used. A deployment's runs of one key make such a history when it
restarts only from the files its last operation left, since a restart
resumes each key above every count a call used; two stores that one
generation names do not. -/
def SealHistoryContinuous : List (Nat × Nat) → Prop
  | [] => True
  | run :: later =>
      (∀ next ∈ later, run.1 + run.2 ≤ next.1) ∧ SealHistoryContinuous later

/-- No nonce is handed out twice over a continuous history of runs under one
key: the zero nonce reuse of the Path ORAM route's bound, over one history.
Each run hands out no nonce twice (`sealNonceRun_nodup`), and a run shares no
nonce with one that starts at or above the count it reached
(`sealNonceRun_disjoint_of_le`). -/
theorem sealNonceHistory_nodup {runs : List (Nat × Nat)}
    (hContinuous : SealHistoryContinuous runs) :
    (sealNonceHistory runs).Nodup := by
  induction runs with
  | nil => simp [sealNonceHistory]
  | cons run later ih =>
    obtain ⟨hAfter, hLater⟩ := hContinuous
    have hRest := ih hLater
    unfold sealNonceHistory at hRest ⊢
    rw [List.flatMap_cons, List.nodup_append]
    refine ⟨sealNonceRun_nodup run.1 run.2, hRest, ?_⟩
    intro nonce hFirst other hOther hSame
    subst hSame
    obtain ⟨next, hNext, hIn⟩ := List.mem_flatMap.mp hOther
    exact sealNonceRun_disjoint_of_le (hAfter next hNext) hFirst hIn

end RuntimeStoreCodecSemantics

end UOToolchain
