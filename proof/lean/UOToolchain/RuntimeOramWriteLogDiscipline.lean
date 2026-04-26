namespace UOToolchain

namespace RuntimeOramWriteLogDiscipline

structure Parameters where
  metadataPages : Nat
  bucketsPerAccess : Nat
deriving Repr, DecidableEq

structure Log where
  capacity : Nat
  len : Nat
  zeroWrites : Nat
  overflowed : Bool
deriving Repr, DecidableEq

def writeLogCapacity (parameters : Parameters) : Nat :=
  parameters.metadataPages + parameters.bucketsPerAccess + 1

def readTranscriptCapacity (parameters : Parameters) : Nat :=
  1 + parameters.metadataPages + parameters.bucketsPerAccess

def initialLog (parameters : Parameters) : Log :=
  { capacity := writeLogCapacity parameters
  , len := 0
  , zeroWrites := 0
  , overflowed := false
  }

def pushWrite (log : Log) (isZeroWrite : Bool) : Option Log :=
  if log.len < log.capacity then
    some
      { log with
        len := log.len + 1
        zeroWrites := log.zeroWrites + if isZeroWrite then 1 else 0
      }
  else
    none

def pushUpdate (log : Log) : Option Log :=
  if log.len < log.capacity then
    some { log with len := log.len + 1 }
  else
    none

def exactBatchAccepted (parameters : Parameters) (log : Log) : Prop :=
  log.capacity = writeLogCapacity parameters ∧
    log.len = log.capacity ∧
    log.zeroWrites ≤ log.len ∧
    log.overflowed = false

def exactUpdateBatchAccepted (parameters : Parameters) (log : Log) : Prop :=
  exactBatchAccepted parameters log ∧ log.zeroWrites = 0

structure ReadTranscriptBuilder where
  capacity : Nat
  logicalLen : Nat
  physicalReadLen : Nat
  overflowed : Bool
deriving Repr, DecidableEq

def initialReadTranscriptBuilder
    (parameters : Parameters) : ReadTranscriptBuilder :=
  { capacity := readTranscriptCapacity parameters
  , logicalLen := 0
  , physicalReadLen := 0
  , overflowed := false
  }

def pushReadTranscriptPair
    (builder : ReadTranscriptBuilder) : Option ReadTranscriptBuilder :=
  if builder.logicalLen < builder.capacity ∧
      builder.physicalReadLen < builder.capacity then
    some
      { builder with
        logicalLen := builder.logicalLen + 1
        physicalReadLen := builder.physicalReadLen + 1
      }
  else
    none

def exactReadTranscriptAccepted
    (parameters : Parameters)
    (builder : ReadTranscriptBuilder) : Prop :=
  builder.capacity = readTranscriptCapacity parameters ∧
    builder.logicalLen = builder.capacity ∧
    builder.physicalReadLen = builder.capacity ∧
    builder.overflowed = false

theorem initialLog_capacity
  (parameters : Parameters) :
  (initialLog parameters).capacity = writeLogCapacity parameters := by
  rfl

theorem initialLog_zeroWrites
  (parameters : Parameters) :
  (initialLog parameters).zeroWrites = 0 := by
  rfl

theorem initialReadTranscriptBuilder_capacity
  (parameters : Parameters) :
  (initialReadTranscriptBuilder parameters).capacity =
    readTranscriptCapacity parameters := by
  rfl

theorem writeLogCapacity_public_formula
  (parameters : Parameters) :
  writeLogCapacity parameters =
    parameters.metadataPages + parameters.bucketsPerAccess + 1 := by
  rfl

theorem readTranscriptCapacity_public_formula
  (parameters : Parameters) :
  readTranscriptCapacity parameters =
    1 + parameters.metadataPages + parameters.bucketsPerAccess := by
  rfl

theorem pushWrite_acceptsOnlyBelowCapacity
  {log next : Log} {isZeroWrite : Bool}
  (h : pushWrite log isZeroWrite = some next) :
  log.len < log.capacity := by
  unfold pushWrite at h
  split at h
  · assumption
  · contradiction

theorem pushWrite_rejectsAtCapacity
  {log : Log} {isZeroWrite : Bool}
  (h : log.capacity ≤ log.len) :
  pushWrite log isZeroWrite = none := by
  unfold pushWrite
  split
  · exact False.elim ((Nat.not_lt_of_ge h) ‹log.len < log.capacity›)
  · rfl

theorem pushWrite_preservesCapacity
  {log next : Log} {isZeroWrite : Bool}
  (h : pushWrite log isZeroWrite = some next) :
  next.capacity = log.capacity := by
  unfold pushWrite at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushWrite_incrementsLength
  {log next : Log} {isZeroWrite : Bool}
  (h : pushWrite log isZeroWrite = some next) :
  next.len = log.len + 1 := by
  unfold pushWrite at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushWrite_updatesZeroWrites
  {log next : Log} {isZeroWrite : Bool}
  (h : pushWrite log isZeroWrite = some next) :
  next.zeroWrites = log.zeroWrites + if isZeroWrite then 1 else 0 := by
  unfold pushWrite at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushWrite_preservesOverflowFlag
  {log next : Log} {isZeroWrite : Bool}
  (h : pushWrite log isZeroWrite = some next) :
  next.overflowed = log.overflowed := by
  unfold pushWrite at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushUpdate_acceptsOnlyBelowCapacity
  {log next : Log}
  (h : pushUpdate log = some next) :
  log.len < log.capacity := by
  unfold pushUpdate at h
  split at h
  · assumption
  · contradiction

theorem pushUpdate_rejectsAtCapacity
  {log : Log}
  (h : log.capacity ≤ log.len) :
  pushUpdate log = none := by
  unfold pushUpdate
  split
  · exact False.elim ((Nat.not_lt_of_ge h) ‹log.len < log.capacity›)
  · rfl

theorem pushUpdate_preservesCapacity
  {log next : Log}
  (h : pushUpdate log = some next) :
  next.capacity = log.capacity := by
  unfold pushUpdate at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushUpdate_incrementsLength
  {log next : Log}
  (h : pushUpdate log = some next) :
  next.len = log.len + 1 := by
  unfold pushUpdate at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushUpdate_preservesZeroWrites
  {log next : Log}
  (h : pushUpdate log = some next) :
  next.zeroWrites = log.zeroWrites := by
  unfold pushUpdate at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushUpdate_preservesOverflowFlag
  {log next : Log}
  (h : pushUpdate log = some next) :
  next.overflowed = log.overflowed := by
  unfold pushUpdate at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushReadTranscriptPair_acceptsOnlyBelowCapacity
  {builder next : ReadTranscriptBuilder}
  (h : pushReadTranscriptPair builder = some next) :
  builder.logicalLen < builder.capacity ∧
    builder.physicalReadLen < builder.capacity := by
  unfold pushReadTranscriptPair at h
  split at h
  · assumption
  · contradiction

theorem pushReadTranscriptPair_rejectsAtLogicalCapacity
  {builder : ReadTranscriptBuilder}
  (h : builder.capacity ≤ builder.logicalLen) :
  pushReadTranscriptPair builder = none := by
  unfold pushReadTranscriptPair
  split
  · exact
      False.elim
        ((Nat.not_lt_of_ge h) ‹builder.logicalLen < builder.capacity ∧
          builder.physicalReadLen < builder.capacity›.1)
  · rfl

theorem pushReadTranscriptPair_rejectsAtPhysicalReadCapacity
  {builder : ReadTranscriptBuilder}
  (h : builder.capacity ≤ builder.physicalReadLen) :
  pushReadTranscriptPair builder = none := by
  unfold pushReadTranscriptPair
  split
  · exact
      False.elim
        ((Nat.not_lt_of_ge h) ‹builder.logicalLen < builder.capacity ∧
          builder.physicalReadLen < builder.capacity›.2)
  · rfl

theorem pushReadTranscriptPair_preservesCapacity
  {builder next : ReadTranscriptBuilder}
  (h : pushReadTranscriptPair builder = some next) :
  next.capacity = builder.capacity := by
  unfold pushReadTranscriptPair at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushReadTranscriptPair_incrementsLogicalLength
  {builder next : ReadTranscriptBuilder}
  (h : pushReadTranscriptPair builder = some next) :
  next.logicalLen = builder.logicalLen + 1 := by
  unfold pushReadTranscriptPair at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushReadTranscriptPair_incrementsPhysicalReadLength
  {builder next : ReadTranscriptBuilder}
  (h : pushReadTranscriptPair builder = some next) :
  next.physicalReadLen = builder.physicalReadLen + 1 := by
  unfold pushReadTranscriptPair at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem pushReadTranscriptPair_preservesOverflowFlag
  {builder next : ReadTranscriptBuilder}
  (h : pushReadTranscriptPair builder = some next) :
  next.overflowed = builder.overflowed := by
  unfold pushReadTranscriptPair at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem exactBatchAccepted_exactCapacity
  {parameters : Parameters} {log : Log}
  (h : exactBatchAccepted parameters log) :
  log.len = writeLogCapacity parameters := by
  exact Eq.trans h.2.1 h.1

theorem exactBatchAccepted_zeroWritesBounded
  {parameters : Parameters} {log : Log}
  (h : exactBatchAccepted parameters log) :
  log.zeroWrites ≤ log.len :=
  h.2.2.1

theorem exactBatchAccepted_noOverflow
  {parameters : Parameters} {log : Log}
  (h : exactBatchAccepted parameters log) :
  log.overflowed = false :=
  h.2.2.2

theorem exactUpdateBatchAccepted_exactCapacity
  {parameters : Parameters} {log : Log}
  (h : exactUpdateBatchAccepted parameters log) :
  log.len = writeLogCapacity parameters :=
  exactBatchAccepted_exactCapacity h.1

theorem exactUpdateBatchAccepted_zeroWrites
  {parameters : Parameters} {log : Log}
  (h : exactUpdateBatchAccepted parameters log) :
  log.zeroWrites = 0 :=
  h.2

theorem exactUpdateBatchAccepted_noOverflow
  {parameters : Parameters} {log : Log}
  (h : exactUpdateBatchAccepted parameters log) :
  log.overflowed = false :=
  exactBatchAccepted_noOverflow h.1

theorem exactReadTranscriptAccepted_exactLogicalCapacity
  {parameters : Parameters}
  {builder : ReadTranscriptBuilder}
  (h : exactReadTranscriptAccepted parameters builder) :
  builder.logicalLen = readTranscriptCapacity parameters := by
  exact Eq.trans h.2.1 h.1

theorem exactReadTranscriptAccepted_exactPhysicalCapacity
  {parameters : Parameters}
  {builder : ReadTranscriptBuilder}
  (h : exactReadTranscriptAccepted parameters builder) :
  builder.physicalReadLen = readTranscriptCapacity parameters := by
  exact Eq.trans h.2.2.1 h.1

theorem exactReadTranscriptAccepted_logicalPhysicalAligned
  {parameters : Parameters}
  {builder : ReadTranscriptBuilder}
  (h : exactReadTranscriptAccepted parameters builder) :
  builder.logicalLen = builder.physicalReadLen := by
  rw [h.2.1, h.2.2.1]

theorem exactReadTranscriptAccepted_noOverflow
  {parameters : Parameters}
  {builder : ReadTranscriptBuilder}
  (h : exactReadTranscriptAccepted parameters builder) :
  builder.overflowed = false :=
  h.2.2.2

end RuntimeOramWriteLogDiscipline

end UOToolchain
