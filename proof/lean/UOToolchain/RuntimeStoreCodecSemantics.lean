namespace UOToolchain

namespace RuntimeStoreCodecSemantics

def sealedMagicLen : Nat := 2
def sealedNonceBytes : Nat := 12
def sealedTagBytes : Nat := 16
def byteRadix : Nat := 16
def sealedMagic : List Nat := [165, 90]

def sealedEncodedLen (payloadLen : Nat) : Nat :=
  2 * (sealedMagicLen + sealedNonceBytes + payloadLen + sealedTagBytes)

def sealedPlainLen (payloadLen : Nat) : Nat :=
  sealedMagicLen + sealedNonceBytes + payloadLen + sealedTagBytes

def encodeByte (byte : Nat) : List Nat :=
  [byte / byteRadix + 1, byte % byteRadix + 1]

def encodeNonzero : List Nat → List Nat
  | [] => []
  | byte :: bytes => encodeByte byte ++ encodeNonzero bytes

def decodeByte (hi lo : Nat) : Option Nat :=
  if hi = 0 ∨ byteRadix < hi ∨ lo = 0 ∨ byteRadix < lo then
    none
  else
    some ((hi - 1) * byteRadix + (lo - 1))

def decodeNonzero : List Nat → Option (List Nat)
  | [] => some []
  | hi :: lo :: rest => do
      let byte ← decodeByte hi lo
      let bytes ← decodeNonzero rest
      some (byte :: bytes)
  | [_] => none

def decodeNonzeroInto?
    (byteLen : Nat)
    (encoded : List Nat) : Option (List Nat) :=
  match decodeNonzero encoded with
  | none => none
  | some bytes =>
      if bytes.length = byteLen then some bytes else none

def ValidByte (byte : Nat) : Prop :=
  byte < 256

def ValidEncodedNibble (nibble : Nat) : Prop :=
  0 < nibble ∧ nibble ≤ byteRadix

def UoStoreSlotCiphertextShape
    (payloadLen : Nat)
    (encoded : List Nat) : Prop :=
  encoded.length = sealedEncodedLen payloadLen ∧
    ∀ nibble, nibble ∈ encoded → ValidEncodedNibble nibble

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

structure SealedRecordParts where
  magic : List Nat
  nonce : List Nat
  ciphertext : List Nat
  tag : List Nat
deriving Repr, DecidableEq

def SealedRecordParts.ValidShape
    (payloadLen : Nat)
    (parts : SealedRecordParts) : Prop :=
  parts.magic.length = sealedMagicLen ∧
    parts.nonce.length = sealedNonceBytes ∧
    parts.ciphertext.length = payloadLen ∧
    parts.tag.length = sealedTagBytes

def SealedRecordParts.ValidOpenShape
    (payloadLen : Nat)
    (parts : SealedRecordParts) : Prop :=
  parts.ValidShape payloadLen ∧
    parts.magic = sealedMagic

def SealedRecordParts.bytes
    (parts : SealedRecordParts) : List Nat :=
  parts.magic ++ parts.nonce ++ parts.ciphertext ++ parts.tag

def sealedRecordParts
    (payloadLen : Nat)
    (sealed : List Nat) : SealedRecordParts :=
  let afterMagic := sealed.drop sealedMagicLen
  let afterNonce := afterMagic.drop sealedNonceBytes
  { magic := sealed.take sealedMagicLen
  , nonce := afterMagic.take sealedNonceBytes
  , ciphertext := afterNonce.take payloadLen
  , tag := (afterNonce.drop payloadLen).take sealedTagBytes
  }

def splitSealedRecord?
    (payloadLen : Nat)
    (sealed : List Nat) : Option SealedRecordParts :=
  if sealed.length = sealedPlainLen payloadLen then
    some (sealedRecordParts payloadLen sealed)
  else
    none

def decodeSealedRecord?
    (payloadLen : Nat)
    (encoded : List Nat) : Option SealedRecordParts :=
  match decodeNonzero encoded with
  | none => none
  | some sealed =>
      match splitSealedRecord? payloadLen sealed with
      | none => none
      | some parts =>
          if parts.magic = sealedMagic then some parts else none

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

def sealAndWipeIntoSliceAccepted
    (payloadLen outLen : Nat) : Prop :=
  outLen = sealedEncodedLen payloadLen

def openBoxedPayloadShape?
    (payloadLen : Nat)
    (encoded : List Nat) : Option Nat :=
  match decodeSealedRecord? payloadLen encoded with
  | none => none
  | some parts => some parts.ciphertext.length

theorem sealedEncodedLen_public_formula
    (payloadLen : Nat) :
  sealedEncodedLen payloadLen =
      2 * (sealedMagicLen + sealedNonceBytes + payloadLen + sealedTagBytes) := by
  rfl

theorem sealedPlainLen_public_formula
    (payloadLen : Nat) :
    sealedPlainLen payloadLen =
      sealedMagicLen + sealedNonceBytes + payloadLen + sealedTagBytes := by
  rfl

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

theorem encodeByte_length
    (byte : Nat) :
    (encodeByte byte).length = 2 := by
  rfl

theorem encodeNonzero_length
    (bytes : List Nat) :
    (encodeNonzero bytes).length = 2 * bytes.length := by
  induction bytes with
  | nil => rfl
  | cons byte bytes ih =>
      simp [encodeNonzero, encodeByte, ih, Nat.mul_succ]

theorem encodeByte_validEncodedNibble
    {byte nibble : Nat}
    (hByte : ValidByte byte)
    (hMem : nibble ∈ encodeByte byte) :
    ValidEncodedNibble nibble := by
  have hRadixPos : 0 < byteRadix := by decide
  have hDiv : byte / byteRadix < byteRadix := by
    unfold ValidByte at hByte
    unfold byteRadix
    exact Nat.div_lt_of_lt_mul (by simpa using hByte)
  have hMod : byte % byteRadix < byteRadix :=
    Nat.mod_lt byte hRadixPos
  unfold byteRadix at hDiv hMod
  simp [encodeByte] at hMem
  rcases hMem with hNibble | hNibble
  · rw [hNibble]
    unfold ValidEncodedNibble byteRadix
    omega
  · rw [hNibble]
    unfold ValidEncodedNibble byteRadix
    omega

theorem encodeNonzero_validEncodedNibbles
    {bytes : List Nat}
    (hBytes : ∀ byte, byte ∈ bytes → ValidByte byte)
    {nibble : Nat}
    (hMem : nibble ∈ encodeNonzero bytes) :
    ValidEncodedNibble nibble := by
  induction bytes with
  | nil =>
      simp [encodeNonzero] at hMem
  | cons byte bytes ih =>
      simp [encodeNonzero] at hMem
      rcases hMem with hHead | hTail
      · exact encodeByte_validEncodedNibble (hBytes byte (by simp)) hHead
      · exact
          ih
            (fun tailByte hTailByte =>
              hBytes tailByte (by simp [hTailByte]))
            hTail

theorem decodeByte_encodeByte
    {byte : Nat}
    (hByte : ValidByte byte) :
    decodeByte (byte / byteRadix + 1) (byte % byteRadix + 1) =
      some byte := by
  have hRadixPos : 0 < byteRadix := by decide
  have hDiv : byte / byteRadix < byteRadix := by
    unfold ValidByte at hByte
    unfold byteRadix
    exact Nat.div_lt_of_lt_mul (by simpa using hByte)
  have hMod : byte % byteRadix < byteRadix :=
    Nat.mod_lt byte hRadixPos
  unfold byteRadix at hDiv hMod
  have hCond :
      ¬ (byte / byteRadix + 1 = 0 ∨
        byteRadix < byte / byteRadix + 1 ∨
        byte % byteRadix + 1 = 0 ∨
        byteRadix < byte % byteRadix + 1) := by
    unfold byteRadix
    omega
  unfold decodeByte
  split
  · rename_i hBad
    exact False.elim (hCond hBad)
  · simp [Nat.div_add_mod']

theorem decodeByte_sound
    {hi lo byte : Nat}
    (hDecode : decodeByte hi lo = some byte) :
    ValidEncodedNibble hi ∧ ValidEncodedNibble lo ∧ ValidByte byte := by
  unfold decodeByte at hDecode
  split at hDecode
  · contradiction
  · rename_i hGood
    cases hDecode
    have hHiLower : 0 < hi := by
      by_cases hZero : hi = 0
      · exact False.elim (hGood (Or.inl hZero))
      · exact Nat.pos_of_ne_zero hZero
    have hLoLower : 0 < lo := by
      by_cases hZero : lo = 0
      · exact False.elim (hGood (Or.inr (Or.inr (Or.inl hZero))))
      · exact Nat.pos_of_ne_zero hZero
    have hHiUpper : hi ≤ byteRadix := by
      by_cases hGt : byteRadix < hi
      · exact False.elim (hGood (Or.inr (Or.inl hGt)))
      · exact Nat.le_of_not_gt hGt
    have hLoUpper : lo ≤ byteRadix := by
      by_cases hGt : byteRadix < lo
      · exact False.elim (hGood (Or.inr (Or.inr (Or.inr hGt))))
      · exact Nat.le_of_not_gt hGt
    unfold ValidEncodedNibble ValidByte byteRadix at *
    omega

theorem decodeNonzero_sound
    {encoded bytes : List Nat}
    (hDecode : decodeNonzero encoded = some bytes) :
    encoded.length = 2 * bytes.length ∧
      (∀ byte, byte ∈ bytes → ValidByte byte) ∧
      (∀ nibble, nibble ∈ encoded → ValidEncodedNibble nibble) := by
  have hMain : ∀ n encoded bytes,
      encoded.length = n →
      decodeNonzero encoded = some bytes →
      encoded.length = 2 * bytes.length ∧
        (∀ byte, byte ∈ bytes → ValidByte byte) ∧
        (∀ nibble, nibble ∈ encoded → ValidEncodedNibble nibble) := by
    intro n
    induction n using Nat.strongRecOn with
    | ind n ih =>
        intro encoded bytes hLen hDecode
        cases encoded with
        | nil =>
            simp [decodeNonzero] at hDecode
            cases hDecode
            simp
        | cons hi tail =>
            cases tail with
            | nil =>
                simp [decodeNonzero] at hDecode
            | cons lo rest =>
                simp [decodeNonzero] at hDecode
                cases hByte : decodeByte hi lo with
                | none =>
                    simp [hByte] at hDecode
                | some byte =>
                    cases hRest : decodeNonzero rest with
                    | none =>
                        simp [hByte, hRest] at hDecode
                    | some tailBytes =>
                        simp [hByte, hRest] at hDecode
                        cases hDecode
                        have hRestLenLt : rest.length < n := by
                          simp at hLen
                          omega
                        have hTailSound :=
                          ih rest.length hRestLenLt rest tailBytes rfl hRest
                        have hByteSound := decodeByte_sound hByte
                        rcases hByteSound with ⟨hHi, hLo, hByteValid⟩
                        rcases hTailSound with
                          ⟨hLenRest, hTailValid, hEncodedValid⟩
                        constructor
                        · simp [hLenRest]
                          omega
                        constructor
                        · intro candidate hMem
                          simp at hMem
                          rcases hMem with hEq | hTailMem
                          · subst candidate
                            exact hByteValid
                          · exact hTailValid candidate hTailMem
                        · intro nibble hMem
                          simp at hMem
                          rcases hMem with hEq | hEq | hTailMem
                          · subst nibble
                            exact hHi
                          · subst nibble
                            exact hLo
                          · exact hEncodedValid nibble hTailMem
  exact hMain encoded.length encoded bytes rfl hDecode

theorem decodeNonzeroInto?_rejectsEncodedLengthMismatch
    {byteLen : Nat}
    {encoded : List Nat}
    (hLen : encoded.length ≠ 2 * byteLen) :
    decodeNonzeroInto? byteLen encoded = none := by
  unfold decodeNonzeroInto?
  cases hDecode : decodeNonzero encoded with
  | none => rfl
  | some bytes =>
      have hSound := decodeNonzero_sound hDecode
      by_cases hBytesLen : bytes.length = byteLen
      · simp [hBytesLen]
        exact False.elim (hLen (by rw [hSound.1, hBytesLen]))
      · simp [hBytesLen]

theorem decodeNonzeroInto?_some_sound
    {byteLen : Nat}
    {encoded bytes : List Nat}
    (hDecode : decodeNonzeroInto? byteLen encoded = some bytes) :
    encoded.length = 2 * byteLen ∧
      bytes.length = byteLen ∧
      (∀ byte, byte ∈ bytes → ValidByte byte) ∧
      (∀ nibble, nibble ∈ encoded → ValidEncodedNibble nibble) := by
  unfold decodeNonzeroInto? at hDecode
  cases hNonzero : decodeNonzero encoded with
  | none =>
      simp [hNonzero] at hDecode
  | some decoded =>
      by_cases hLen : decoded.length = byteLen
      · simp [hNonzero, hLen] at hDecode
        cases hDecode
        have hSound := decodeNonzero_sound hNonzero
        exact
          ⟨ by rw [hSound.1, hLen]
          , hLen
          , hSound.2.1
          , hSound.2.2
          ⟩
      · simp [hNonzero, hLen] at hDecode

theorem sealedRecordParts_validShape_of_length
    {payloadLen : Nat}
    {sealed : List Nat}
    (hLen : sealed.length = sealedPlainLen payloadLen) :
    (sealedRecordParts payloadLen sealed).ValidShape payloadLen := by
  unfold SealedRecordParts.ValidShape sealedRecordParts
  constructor
  · simp [hLen, sealedPlainLen, sealedMagicLen, sealedNonceBytes,
      sealedTagBytes]
  constructor
  · simp [hLen, sealedPlainLen, sealedMagicLen, sealedNonceBytes,
      sealedTagBytes]
  constructor
  · simp [hLen, sealedPlainLen, sealedMagicLen, sealedNonceBytes,
      sealedTagBytes]
    omega
  · simp [hLen, sealedPlainLen, sealedMagicLen, sealedNonceBytes,
      sealedTagBytes]

theorem sealedRecordParts_bytes_of_length
    {payloadLen : Nat}
    {sealed : List Nat}
    (hLen : sealed.length = sealedPlainLen payloadLen) :
    (sealedRecordParts payloadLen sealed).bytes = sealed := by
  have hTake :
      sealed.take (sealedPlainLen payloadLen) = sealed := by
    rw [← hLen]
    exact List.take_length
  conv =>
    rhs
    rw [← hTake]
  simp [SealedRecordParts.bytes, sealedRecordParts, sealedPlainLen,
    sealedMagicLen, sealedNonceBytes, sealedTagBytes, List.take_add,
    Nat.add_assoc, List.append_assoc]
  rw [← List.append_assoc]
  rw [← List.take_add (l := sealed) (i := 2) (j := 12)]

theorem sealedRecordParts_bytes_valid_of_length
    {payloadLen : Nat}
    {sealed : List Nat}
    (hLen : sealed.length = sealedPlainLen payloadLen)
    (hSealedBytes : ∀ byte, byte ∈ sealed → ValidByte byte) :
    ∀ byte,
      byte ∈ (sealedRecordParts payloadLen sealed).bytes →
        ValidByte byte := by
  intro byte hMem
  exact
    hSealedBytes byte
      (by
        rw [sealedRecordParts_bytes_of_length hLen] at hMem
        exact hMem)

theorem SealedRecordParts.bytes_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.bytes.length = sealedPlainLen payloadLen := by
  unfold SealedRecordParts.ValidShape at hShape
  unfold SealedRecordParts.bytes
  rcases hShape with ⟨hMagicLen, hNonceLen, hCiphertextLen, hTagLen⟩
  simp [hMagicLen, hNonceLen, hCiphertextLen, hTagLen,
    sealedPlainLen, sealedMagicLen, sealedNonceBytes, sealedTagBytes]
  omega

theorem sealedRecordParts_bytes_roundtrip
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    sealedRecordParts payloadLen parts.bytes = parts := by
  cases parts with
  | mk magic nonce ciphertext tag =>
      unfold SealedRecordParts.ValidShape at hShape
      unfold SealedRecordParts.bytes
      rcases hShape with
        ⟨hMagicLen, hNonceLen, hCiphertextLen, hTagLen⟩
      have hTagLenLe : tag.length ≤ 16 := by
        have hTagLenEq : tag.length = 16 := by
          simpa [sealedTagBytes] using hTagLen
        omega
      simp [sealedRecordParts, hMagicLen, hNonceLen, hCiphertextLen,
        sealedMagicLen, sealedNonceBytes, sealedTagBytes,
        List.take_of_length_le hTagLenLe]

theorem splitSealedRecord_some_validShape
    {payloadLen : Nat}
    {sealed : List Nat}
    {parts : SealedRecordParts}
    (hSplit : splitSealedRecord? payloadLen sealed = some parts) :
    sealed.length = sealedPlainLen payloadLen ∧
      parts.ValidShape payloadLen := by
  unfold splitSealedRecord? at hSplit
  split at hSplit
  · rename_i hLen
    cases hSplit
    exact ⟨hLen, sealedRecordParts_validShape_of_length hLen⟩
  · contradiction

theorem splitSealedRecord_some_bytes
    {payloadLen : Nat}
    {sealed : List Nat}
    {parts : SealedRecordParts}
    (hSplit : splitSealedRecord? payloadLen sealed = some parts) :
    parts.bytes = sealed := by
  unfold splitSealedRecord? at hSplit
  split at hSplit
  · rename_i hLen
    cases hSplit
    exact sealedRecordParts_bytes_of_length hLen
  · contradiction

theorem decodeSealedRecord_some_validOpenShape
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    encoded.length = sealedEncodedLen payloadLen ∧
      parts.ValidOpenShape payloadLen := by
  unfold decodeSealedRecord? at hDecode
  cases hNonzero : decodeNonzero encoded with
  | none =>
      simp [hNonzero] at hDecode
  | some sealed =>
      cases hSplit : splitSealedRecord? payloadLen sealed with
      | none =>
          simp [hNonzero, hSplit] at hDecode
      | some decodedParts =>
          by_cases hMagic : decodedParts.magic = sealedMagic
          · simp [hNonzero, hSplit, hMagic] at hDecode
            cases hDecode
            have hSplitShape := splitSealedRecord_some_validShape hSplit
            have hDecodeSound := decodeNonzero_sound hNonzero
            have hLen :
                encoded.length = sealedEncodedLen payloadLen := by
              rw [hDecodeSound.1, hSplitShape.1]
              unfold sealedEncodedLen sealedPlainLen
              omega
            exact ⟨hLen, ⟨hSplitShape.2, hMagic⟩⟩
          · simp [hNonzero, hSplit, hMagic] at hDecode

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
  simpa [hValidShape.2.2.1]

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

theorem decodeSealedRecord_some_transport_sound
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    encoded.length = sealedEncodedLen payloadLen ∧
      parts.ValidOpenShape payloadLen ∧
      (∀ nibble, nibble ∈ encoded → ValidEncodedNibble nibble) ∧
      ∃ sealed,
        decodeNonzero encoded = some sealed ∧
          splitSealedRecord? payloadLen sealed = some parts ∧
          parts.bytes = sealed ∧
          sealed.length = sealedPlainLen payloadLen ∧
          (∀ byte, byte ∈ sealed → ValidByte byte) ∧
          (∀ byte, byte ∈ parts.bytes → ValidByte byte) := by
  unfold decodeSealedRecord? at hDecode
  cases hNonzero : decodeNonzero encoded with
  | none =>
      simp [hNonzero] at hDecode
  | some sealed =>
      cases hSplit : splitSealedRecord? payloadLen sealed with
      | none =>
          simp [hNonzero, hSplit] at hDecode
      | some decodedParts =>
          by_cases hMagic : decodedParts.magic = sealedMagic
          · simp [hNonzero, hSplit, hMagic] at hDecode
            cases hDecode
            have hSplitShape := splitSealedRecord_some_validShape hSplit
            have hPartsBytes := splitSealedRecord_some_bytes hSplit
            have hDecodeSound := decodeNonzero_sound hNonzero
            have hLen :
                encoded.length = sealedEncodedLen payloadLen := by
              rw [hDecodeSound.1, hSplitShape.1]
              unfold sealedEncodedLen sealedPlainLen
              omega
            exact
              ⟨ hLen
              , ⟨hSplitShape.2, hMagic⟩
              , hDecodeSound.2.2
              , ⟨ sealed
                , rfl
                , hSplit
                , hPartsBytes
                , hSplitShape.1
                , hDecodeSound.2.1
                , fun byte hMem =>
                    hDecodeSound.2.1 byte (by
                      rw [hPartsBytes] at hMem
                      exact hMem)
                ⟩
              ⟩
          · simp [hNonzero, hSplit, hMagic] at hDecode

theorem decodeSealedRecord_some_uoSlotCiphertextShape
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    UoStoreSlotCiphertextShape payloadLen encoded := by
  have hSound := decodeSealedRecord_some_transport_sound hDecode
  exact ⟨hSound.1, hSound.2.2.1⟩

theorem decodeNonzero_sealedRecordShape
    {payloadLen : Nat}
    {encoded sealed : List Nat}
    (hDecode : decodeNonzero encoded = some sealed)
    (hEncodedLen : encoded.length = sealedEncodedLen payloadLen) :
    sealed.length = sealedPlainLen payloadLen ∧
      ∃ parts,
        splitSealedRecord? payloadLen sealed = some parts ∧
          parts.ValidShape payloadLen := by
  have hDecodeLen := (decodeNonzero_sound hDecode).1
  have hSealedLen : sealed.length = sealedPlainLen payloadLen := by
    rw [hEncodedLen] at hDecodeLen
    unfold sealedEncodedLen at hDecodeLen
    unfold sealedPlainLen
    omega
  refine ⟨hSealedLen, sealedRecordParts payloadLen sealed, ?_, ?_⟩
  · unfold splitSealedRecord?
    simp [hSealedLen]
  · exact sealedRecordParts_validShape_of_length hSealedLen

theorem decodeNonzero_encodeNonzero
    {bytes : List Nat}
    (hBytes : ∀ byte, byte ∈ bytes → ValidByte byte) :
    decodeNonzero (encodeNonzero bytes) = some bytes := by
  induction bytes with
  | nil => rfl
  | cons byte bytes ih =>
      have hByte : ValidByte byte := hBytes byte (by simp)
      have hTail : ∀ tailByte, tailByte ∈ bytes → ValidByte tailByte := by
        intro tailByte hTailByte
        exact hBytes tailByte (by simp [hTailByte])
      simp [encodeNonzero, encodeByte, decodeNonzero,
        decodeByte_encodeByte hByte, ih hTail]

theorem decodeNonzeroInto?_encodeNonzero
    {bytes : List Nat}
    (hBytes : ∀ byte, byte ∈ bytes → ValidByte byte) :
    decodeNonzeroInto? bytes.length (encodeNonzero bytes) = some bytes := by
  unfold decodeNonzeroInto?
  rw [decodeNonzero_encodeNonzero hBytes]
  simp

theorem decodeSealedRecord_encodeSealedRecordParts
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hOpenShape : parts.ValidOpenShape payloadLen)
    (hBytes : ∀ byte, byte ∈ parts.bytes → ValidByte byte) :
    decodeSealedRecord? payloadLen (encodeNonzero parts.bytes) =
      some parts := by
  rcases hOpenShape with ⟨hShape, hMagic⟩
  have hPlainLen := SealedRecordParts.bytes_length_of_validShape hShape
  have hRoundtrip := sealedRecordParts_bytes_roundtrip hShape
  unfold decodeSealedRecord?
  rw [decodeNonzero_encodeNonzero hBytes]
  unfold splitSealedRecord?
  simp [hPlainLen, hRoundtrip, hMagic]

theorem encodeSealedRecordParts_length
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    (encodeNonzero parts.bytes).length = sealedEncodedLen payloadLen := by
  rw [encodeNonzero_length]
  rw [SealedRecordParts.bytes_length_of_validShape hShape]
  unfold sealedEncodedLen sealedPlainLen
  omega

theorem encodeSealedRecordParts_uoSlotCiphertextShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen)
    (hBytes : ∀ byte, byte ∈ parts.bytes → ValidByte byte) :
    UoStoreSlotCiphertextShape payloadLen (encodeNonzero parts.bytes) := by
  exact
    ⟨ encodeSealedRecordParts_length hShape
    , fun nibble hMem =>
        encodeNonzero_validEncodedNibbles hBytes hMem
    ⟩

theorem decodeSealedRecord_encodeSealedRecordParts_wrong_magic_none
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen)
    (hMagic : parts.magic ≠ sealedMagic)
    (hBytes : ∀ byte, byte ∈ parts.bytes → ValidByte byte) :
    decodeSealedRecord? payloadLen (encodeNonzero parts.bytes) = none := by
  have hPlainLen := SealedRecordParts.bytes_length_of_validShape hShape
  have hRoundtrip := sealedRecordParts_bytes_roundtrip hShape
  unfold decodeSealedRecord?
  rw [decodeNonzero_encodeNonzero hBytes]
  unfold splitSealedRecord?
  simp [hPlainLen, hRoundtrip, hMagic]

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

end RuntimeStoreCodecSemantics

end UOToolchain
