namespace UOToolchain

namespace RuntimeValueOpsSemantics

def byteModulus : Nat := 256
def canonicalLengthPrefixBytes : Nat := 8
def boolCanonicalBytes : Nat := 1
def uintCanonicalBytes : Nat := 32
def bytes32CanonicalBytes : Nat := 32
def addressCanonicalBytes : Nat := 20
def uint256PayloadBytes : Nat := 32

def ValidByte (byte : Nat) : Prop :=
  byte < byteModulus

def ValidByteField (bytes : List Nat) : Prop :=
  ∀ byte, byte ∈ bytes → ValidByte byte

def encodeNatField (width value : Nat) : List Nat :=
  (List.range width).map
    (fun index => (value / (byteModulus ^ (width - 1 - index))) % byteModulus)

def uint256CanonicalByteField (value : Nat) : List Nat :=
  encodeNatField uint256PayloadBytes value

def addressCanonicalByteField (bytes : List Nat) : Prop :=
  bytes.length = addressCanonicalBytes ∧ ValidByteField bytes

def bytes32CanonicalByteField (bytes : List Nat) : Prop :=
  bytes.length = bytes32CanonicalBytes ∧ ValidByteField bytes

def maskedSelect (cond : Bool) (whenTrue whenFalse : α) : α :=
  if cond then whenTrue else whenFalse

def maskedSelectByte (cond : Bool) (whenTrue whenFalse : Nat) : Nat :=
  maskedSelect cond whenTrue whenFalse

def maskedSelectBool (cond : Bool) (whenTrue whenFalse : Bool) : Bool :=
  maskedSelect cond whenTrue whenFalse

def maskedSelectBytes
    (cond : Bool)
    (whenTrue whenFalse : List Nat) : List Nat :=
  maskedSelect cond whenTrue whenFalse

def maskedEqByte (lhs rhs : Nat) : Bool :=
  lhs == rhs

def maskedEqBytes (lhs rhs : List Nat) : Bool :=
  lhs == rhs

def bytesAreZero (bytes : List Nat) : Prop :=
  ∀ byte, byte ∈ bytes → byte = 0

structure FixedByteBufferState where
  capacity : Nat
  initialized : Nat
deriving Repr, DecidableEq

def FixedByteBufferState.Valid (state : FixedByteBufferState) : Prop :=
  state.initialized ≤ state.capacity

def FixedByteBufferState.empty (capacity : Nat) : FixedByteBufferState :=
  { capacity := capacity, initialized := 0 }

def FixedByteBufferState.extend?
    (state : FixedByteBufferState)
    (chunk : List Nat) : Option FixedByteBufferState :=
  if state.initialized + chunk.length ≤ state.capacity then
    some { state with initialized := state.initialized + chunk.length }
  else
    none

def FixedByteBufferState.finish?
    (state : FixedByteBufferState) : Option Nat :=
  if state.initialized = state.capacity then
    some state.capacity
  else
    none

theorem encodeNatField_length
    (width value : Nat) :
    (encodeNatField width value).length = width := by
  simp [encodeNatField]

theorem encodeNatField_validBytes
    (width value : Nat) :
    ValidByteField (encodeNatField width value) := by
  intro byte hMem
  unfold encodeNatField at hMem
  rw [List.mem_map] at hMem
  rcases hMem with ⟨index, _hIndex, hByte⟩
  rw [← hByte]
  unfold ValidByte byteModulus
  exact Nat.mod_lt _ (by decide)

theorem uint256CanonicalByteField_length
    (value : Nat) :
    (uint256CanonicalByteField value).length = uintCanonicalBytes := by
  simp [uint256CanonicalByteField, uintCanonicalBytes,
    uint256PayloadBytes, encodeNatField_length]

theorem uint256CanonicalByteField_validBytes
    (value : Nat) :
    ValidByteField (uint256CanonicalByteField value) := by
  intro byte hMem
  unfold uint256CanonicalByteField at hMem
  exact encodeNatField_validBytes uint256PayloadBytes value byte hMem

theorem maskedSelect_true
    (whenTrue whenFalse : α) :
    maskedSelect true whenTrue whenFalse = whenTrue := by
  rfl

theorem maskedSelect_false
    (whenTrue whenFalse : α) :
    maskedSelect false whenTrue whenFalse = whenFalse := by
  rfl

theorem maskedSelectBool_true
    (whenTrue whenFalse : Bool) :
    maskedSelectBool true whenTrue whenFalse = whenTrue := by
  rfl

theorem maskedSelectBool_false
    (whenTrue whenFalse : Bool) :
    maskedSelectBool false whenTrue whenFalse = whenFalse := by
  rfl

theorem maskedSelectBytes_true
    (whenTrue whenFalse : List Nat) :
    maskedSelectBytes true whenTrue whenFalse = whenTrue := by
  rfl

theorem maskedSelectBytes_false
    (whenTrue whenFalse : List Nat) :
    maskedSelectBytes false whenTrue whenFalse = whenFalse := by
  rfl

theorem maskedSelectBytes_length_of_equal
    {cond : Bool}
    {whenTrue whenFalse : List Nat}
    (hLen : whenTrue.length = whenFalse.length) :
    (maskedSelectBytes cond whenTrue whenFalse).length = whenTrue.length := by
  cases cond <;> simp [maskedSelectBytes, maskedSelect, hLen]

theorem maskedEqByte_true_iff
    {lhs rhs : Nat} :
    maskedEqByte lhs rhs = true ↔ lhs = rhs := by
  unfold maskedEqByte
  simp

theorem maskedEqBytes_true_iff
    {lhs rhs : List Nat} :
    maskedEqBytes lhs rhs = true ↔ lhs = rhs := by
  unfold maskedEqBytes
  simp

theorem bytesAreZero_replicate_zero
    (len : Nat) :
    bytesAreZero (List.replicate len 0) := by
  intro byte hMem
  simp [List.mem_replicate] at hMem
  exact hMem.2

theorem fixedByteBuffer_empty_valid
    (capacity : Nat) :
    (FixedByteBufferState.empty capacity).Valid := by
  unfold FixedByteBufferState.Valid FixedByteBufferState.empty
  exact Nat.zero_le capacity

theorem fixedByteBuffer_extend?_some_preservesCapacity
    {state next : FixedByteBufferState}
    {chunk : List Nat}
    (hExtend : state.extend? chunk = some next) :
    next.capacity = state.capacity := by
  unfold FixedByteBufferState.extend? at hExtend
  split at hExtend
  · cases hExtend
    rfl
  · contradiction

theorem fixedByteBuffer_extend?_some_initialized
    {state next : FixedByteBufferState}
    {chunk : List Nat}
    (hExtend : state.extend? chunk = some next) :
    next.initialized = state.initialized + chunk.length := by
  unfold FixedByteBufferState.extend? at hExtend
  split at hExtend
  · cases hExtend
    rfl
  · contradiction

theorem fixedByteBuffer_extend?_some_valid
    {state next : FixedByteBufferState}
    {chunk : List Nat}
    (hExtend : state.extend? chunk = some next) :
    next.Valid := by
  unfold FixedByteBufferState.extend? at hExtend
  split at hExtend
  · rename_i hCapacity
    cases hExtend
    exact hCapacity
  · contradiction

theorem fixedByteBuffer_extend?_rejectsOverflow
    {state : FixedByteBufferState}
    {chunk : List Nat}
    (hOverflow : state.capacity < state.initialized + chunk.length) :
    state.extend? chunk = none := by
  unfold FixedByteBufferState.extend?
  split
  · rename_i hCapacity
    exact False.elim (Nat.not_lt_of_ge hCapacity hOverflow)
  · rfl

theorem fixedByteBuffer_finish?_some_exactlyFilled
    {state : FixedByteBufferState}
    {capacity : Nat}
    (hFinish : state.finish? = some capacity) :
    state.initialized = state.capacity ∧ capacity = state.capacity := by
  unfold FixedByteBufferState.finish? at hFinish
  split at hFinish
  · rename_i hExact
    cases hFinish
    exact ⟨hExact, rfl⟩
  · contradiction

theorem fixedByteBuffer_finish?_rejectsUnderfilled
    {state : FixedByteBufferState}
    (hUnderfilled : state.initialized ≠ state.capacity) :
    state.finish? = none := by
  unfold FixedByteBufferState.finish?
  split
  · rename_i hExact
    exact False.elim (hUnderfilled hExact)
  · rfl

theorem scalarCanonicalLengths_public :
    boolCanonicalBytes = 1 ∧
    uintCanonicalBytes = 32 ∧
    bytes32CanonicalBytes = 32 ∧
    addressCanonicalBytes = 20 ∧
    canonicalLengthPrefixBytes = 8 := by
  simp [boolCanonicalBytes, uintCanonicalBytes, bytes32CanonicalBytes,
    addressCanonicalBytes, canonicalLengthPrefixBytes]

end RuntimeValueOpsSemantics

end UOToolchain
