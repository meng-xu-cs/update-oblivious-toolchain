namespace UOToolchain

namespace RuntimeStoreCodecSemantics

def sealedMagicLen : Nat := 2
def sealedNonceBytes : Nat := 12
def sealedTagBytes : Nat := 16
def byteRadix : Nat := 16
def sealedMagic : List Nat := [165, 90]

/-- ChaCha20-Poly1305 cipher key length in bytes, matching RFC 8439 section 2.5
(32-byte / 256-bit key). The Rust runtime pins this to `key: [u8; 32]` in
`runtime/uo-store/src/generated_surface.rs`, and the probe's
`runtime_crypto_primitive_identity_pinned` static-drift check rejects any other
key shape. The Lean constant lets WP5 codec theorems refer to this length
without re-deriving it from the Rust source. -/
def cipherKeyBytes : Nat := 32

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
  simp [hValidShape.2.2.1]

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

/-! ### The class of a sealed write, from its bytes

A sealed write is an `Update` for the storage observer because the record it
writes differs, in every unit the observer classifies, from the record it
replaces, and neither has a zero unit. The label is not taken on trust: the
runtime keeps the record a write replaces and fails the call unless
`is_update_write` holds of the two (`crates/uo-core/src/trace.rs`,
`reseal_payload_and_record_write` and `reseal_uo_store_slot_and_trace_write`
in the generated helpers). This section states that check. The unit length
is a parameter; the runtime uses 32 bytes, a storage word. That a fresh
nonce makes every unit differ is not proved here: it holds except with
negligible probability, and the check turns a failure into an error. -/

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

/-- A record written over itself is not an update: a seal that repeats the
nonce of the record it replaces, for the same value, is refused. -/
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

/-- Two units without a zero byte, as every unit of a sealed record is
(`encodeNonzero_validEncodedNibbles`), are a `Same` if they are equal and an
`Update` otherwise. So a write of a sealed record over a sealed record can
fail the check only in a unit that it leaves unchanged. -/
theorem classifyWrite_of_nonzero {old new : List Nat}
    (hOld : old ≠ []) (hNew : new ≠ [])
    (hOldNonzero : ∀ byte ∈ old, 0 < byte) (hNewNonzero : ∀ byte ∈ new, 0 < byte) :
    classifyWrite old new =
      if old = new then StoreWriteClass.same else StoreWriteClass.update := by
  simp [classifyWrite, allZero_false_of_nonzero hOld hOldNonzero,
    allZero_false_of_nonzero hNew hNewNonzero]

/-- The unit the storage observer classifies: a 32-byte word
(`STORAGE_OBSERVER_UNIT_BYTES`). -/
def storageObserverUnitBytes : Nat := 32

example : isUpdateWrite 2 [1, 2, 3, 4, 5] [2, 3, 4, 5, 6] = true := by decide
-- One unit unchanged, zero before or zero after: not an update, though the
-- record as a whole changes.
example : isUpdateWrite 2 [1, 2, 3, 4, 5] [2, 3, 3, 4, 6] = false := by decide
example : classifyWrite [1, 2, 3, 4, 5] [2, 3, 3, 4, 6] = StoreWriteClass.update := by decide
example : isUpdateWrite 2 [1, 2, 0, 0, 5] [2, 3, 4, 5, 6] = false := by decide
example : isUpdateWrite 2 [1, 2, 3, 4, 5] [2, 3, 4, 5, 0] = false := by decide
example : isUpdateWrite 2 [1, 2, 3, 4] [2, 3, 4, 5, 6] = false := by decide

/-! ### W5.5: Concrete Rust StoreCipher surface obligations

The theorems below pin obligations of the concrete Rust StoreCipher surface
(`runtime/uo-store/src/generated_surface.rs`) at the Lean codec semantic
level. They project the abstract codec model onto the structural facts the
Rust seal/open implementation actually relies on (cipher-key length, magic
constant length / byte validity, sealed-record component lengths, AAD shape).
The probe `runtime_crypto_primitive_identity_pinned` static-drift check pins
the Rust side; these Lean theorems pin the corresponding mathematical
obligations referenced by the WP5 paper-facing claims. -/

/-- The Lean cipher-key-length constant matches the Rust `key: [u8; 32]`
buffer pinned by the probe's crypto-primitive identity check. This makes the
RFC 8439 32-byte key length a Lean-side fact rather than only a Rust
source-pin. -/
theorem cipherKeyBytes_value :
    cipherKeyBytes = 32 := by
  rfl

/-- The sealed-record magic constant has length `sealedMagicLen = 2`,
matching the Rust `SEALED_MAGIC: [u8; 2] = [0xA5, 0x5A]` constant pinned by
the static-drift suite. -/
theorem sealedMagic_length :
    sealedMagic.length = sealedMagicLen := by
  rfl

/-- Each byte of the public sealed-record magic is a valid byte (`< 256`).
This is what allows the magic to flow through `encodeNonzero` (which only
accepts `ValidByte` inputs) without producing zero bytes in the transport
record. -/
theorem sealedMagic_validBytes :
    ∀ byte, byte ∈ sealedMagic → ValidByte byte := by
  intro byte hMem
  unfold ValidByte
  unfold sealedMagic at hMem
  simp at hMem
  rcases hMem with h | h
  · subst h
    decide
  · subst h
    decide

/-- The transport-encoded sealed record is exactly twice the plain sealed
record. Each plain byte is encoded as two non-zero nibble bytes (high and
low), so `sealedEncodedLen = 2 * sealedPlainLen` for any payload size. This
is the mathematical fact behind the Rust `seal_and_wipe_into_slice` cursor
arithmetic. -/
theorem sealedEncodedLen_eq_two_times_sealedPlainLen
    (payloadLen : Nat) :
    sealedEncodedLen payloadLen = 2 * sealedPlainLen payloadLen := by
  rfl

/-- A valid-shape sealed record's magic component has the public
`sealedMagicLen` length. This is the structural projection from
`SealedRecordParts.ValidShape` for the magic field. -/
theorem SealedRecordParts.magic_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.magic.length = sealedMagicLen :=
  hShape.1

/-- A valid-shape sealed record's nonce component has the public
`sealedNonceBytes` length. This is the structural projection from
`SealedRecordParts.ValidShape` for the nonce field; matches the Rust
`Nonce::from_slice(&nonce_bytes)` 12-byte requirement. -/
theorem SealedRecordParts.nonce_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.nonce.length = sealedNonceBytes :=
  hShape.2.1

/-- A valid-shape sealed record's ciphertext component has length exactly
equal to the payload length. Matches the Rust convention that ChaCha20-Poly1305
in detached mode produces ciphertext of the same length as the plaintext
input. -/
theorem SealedRecordParts.ciphertext_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.ciphertext.length = payloadLen :=
  hShape.2.2.1

/-- A valid-shape sealed record's tag component has the public
`sealedTagBytes` length. Matches the Rust `Tag::from_slice(tag_bytes)`
16-byte requirement and the ChaCha20-Poly1305 detached-tag size from
RFC 8439. -/
theorem SealedRecordParts.tag_length_of_validShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidShape payloadLen) :
    parts.tag.length = sealedTagBytes :=
  hShape.2.2.2

/-- An open-shape sealed record's magic component is exactly the public
`sealedMagic` constant. This is the magic-constant equality projection from
`SealedRecordParts.ValidOpenShape`, mirroring the Rust open-path check
`if magic != SEALED_MAGIC { return None; }`. -/
theorem SealedRecordParts.magic_eq_of_validOpenShape
    {payloadLen : Nat}
    {parts : SealedRecordParts}
    (hShape : parts.ValidOpenShape payloadLen) :
    parts.magic = sealedMagic :=
  hShape.2

/-- A successful `decodeSealedRecord?` outcome witnesses the magic-equality
fact at the open-shape level. This is the named theorem capturing the
Rust open-path invariant that an accepted sealed record always exhibits the
public magic constant. -/
theorem decodeSealedRecord_some_magic
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    parts.magic = sealedMagic :=
  (decodeSealedRecord_some_validOpenShape hDecode).2.2

/-- A successful `decodeSealedRecord?` outcome witnesses the
component-length facts. This is the named theorem capturing the structural
decomposition fact at the open-shape level. -/
theorem decodeSealedRecord_some_componentLengths
    {payloadLen : Nat}
    {encoded : List Nat}
    {parts : SealedRecordParts}
    (hDecode : decodeSealedRecord? payloadLen encoded = some parts) :
    parts.magic.length = sealedMagicLen ∧
      parts.nonce.length = sealedNonceBytes ∧
      parts.ciphertext.length = payloadLen ∧
      parts.tag.length = sealedTagBytes := by
  have hShape := (decodeSealedRecord_some_validOpenShape hDecode).2.1
  exact ⟨hShape.1, hShape.2.1, hShape.2.2.1, hShape.2.2.2⟩

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

end RuntimeStoreCodecSemantics

end UOToolchain
