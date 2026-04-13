import UOToolchain.CompilerInvariant
import UOToolchain.IRSemantics

namespace UOToolchain

structure OramObjectManifest where
  objectId : Nat
  objectName : String
  capacity : Nat
  scheme : String
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

structure OramEntrypointWitness extends ManifestWitness where
  entrypointId : String
  oramObjects : List OramObjectManifest
deriving Repr, DecidableEq

structure OramSchedule where
  metadataPages : List Nat
  bucketIndices : List Nat
deriving Repr, DecidableEq

structure OramAccessLeakage where
  entrypointId : String
  publicGasBudget : Nat
  objectId : Nat
  objectName : String
  capacity : Nat
  scheme : String
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
  accessesPerEntrypoint : Nat
  schedule : OramSchedule
deriving Repr, DecidableEq

abbrev Distribution (α : Type) := List α
abbrev NatTable := List (Nat × Nat)
def oramBucketHeaderBytes : Nat := 24
def surrogateOramScheme : String := "surrogate_public_schedule_v1"
def pathOramScheme : String := "path_oram_local_posmap_v1"
def surrogateOramBlocksPerBucket : Nat := 2
def pathOramBlocksPerBucket : Nat := 4

structure OramPublicData where
  witness : OramEntrypointWitness
  publicArgs : List String
  accessCounters : NatTable
deriving Repr, DecidableEq

structure OramConfig where
  pubData : OramPublicData
  secretState : List String
  secretArgs : List String
deriving Repr, DecidableEq

abbrev OramSemantics := OramConfig → Distribution ViewMPlus

def sameOramPublicProjection (lhs rhs : OramConfig) : Prop :=
  lhs.pubData = rhs.pubData

def lookupNat (table : NatTable) (objectId : Nat) : Nat :=
  match table.find? (fun entry => entry.fst = objectId) with
  | some (_, value) => value
  | none => 0

def bucketWindow (object : OramObjectManifest) (accessCounter : Nat) : List Nat :=
  (List.range object.bucketsPerAccess).map fun offset =>
    if object.bucketCount = 0 then
      0
    else
      (accessCounter + offset) % object.bucketCount

def accessSchedule (object : OramObjectManifest) (accessCounter : Nat) : OramSchedule :=
  { metadataPages := List.range object.metadataPages
  , bucketIndices := bucketWindow object accessCounter
  }

def accessLeakage (cfg : OramConfig) (object : OramObjectManifest) : OramAccessLeakage :=
  let accessCounter := lookupNat cfg.pubData.accessCounters object.objectId
  { entrypointId := cfg.pubData.witness.entrypointId
  , publicGasBudget := cfg.pubData.witness.publicGasBudget
  , objectId := object.objectId
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
  , accessesPerEntrypoint := lookupNat cfg.pubData.witness.oramAccesses object.objectId
  , schedule := accessSchedule object accessCounter
  }

def executionLeakage (cfg : OramConfig) : List OramAccessLeakage :=
  cfg.pubData.witness.oramObjects.map (accessLeakage cfg)

def WellFormedSurrogateOramObject (object : OramObjectManifest) : Prop :=
  object.scheme = surrogateOramScheme ∧
  object.blocksPerBucket = surrogateOramBlocksPerBucket ∧
  object.bucketSize = oramBucketHeaderBytes + object.blocksPerBucket * object.blockSize ∧
  0 < object.bucketCount ∧
  object.metadataPagesPerAccess = object.metadataPages + 1 ∧
  object.bucketsPerAccess = max (object.treeHeight + 2) 3 ∧
  object.stashBound = 0 ∧
  object.recursionDepth = 0 ∧
  object.accessesPerCall = 1

def WellFormedPathOramObject (object : OramObjectManifest) : Prop :=
  object.scheme = pathOramScheme ∧
  object.blocksPerBucket = pathOramBlocksPerBucket ∧
  object.bucketSize = oramBucketHeaderBytes + object.blocksPerBucket * object.blockSize ∧
  0 < object.bucketCount ∧
  object.stashBound = max object.capacity 1 ∧
  object.recursionDepth = 0 ∧
  object.metadataPagesPerAccess = object.metadataPages + 1 ∧
  object.bucketsPerAccess = object.treeHeight + 1 ∧
  object.accessesPerCall = 1

def WellFormedOramObject (object : OramObjectManifest) : Prop :=
  WellFormedSurrogateOramObject object ∨ WellFormedPathOramObject object

def totalPhysicalReadsPerAccess (object : OramObjectManifest) (accessCounter : Nat) : Nat :=
  1 + (accessSchedule object accessCounter).metadataPages.length +
    (accessSchedule object accessCounter).bucketIndices.length

def totalPhysicalWritesPerAccess (object : OramObjectManifest) (accessCounter : Nat) : Nat :=
  1 + (accessSchedule object accessCounter).metadataPages.length +
    (accessSchedule object accessCounter).bucketIndices.length

/-- Legacy placeholder local theorem interface.
The proof-grade Path ORAM development does not depend on this axiom. -/
axiom legacyOramLocalTheorem
  (view₁ view₂ : Distribution ViewMPlus)
  (leakage : List OramAccessLeakage) :
  Prop

abbrev OramLocalTheorem :=
  Distribution ViewMPlus → Distribution ViewMPlus → List OramAccessLeakage → Prop

structure OramSecurityInterface where
  localTheorem : OramLocalTheorem

def legacyOramSecurityInterface : OramSecurityInterface :=
  { localTheorem := legacyOramLocalTheorem }

def ComputationalUOWith (security : OramSecurityInterface) (run : OramSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    security.localTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)

abbrev legacyComputationalUO (run : OramSemantics) : Prop :=
  ComputationalUOWith legacyOramSecurityInterface run

theorem sameOramPublicProjection_refl (cfg : OramConfig) : sameOramPublicProjection cfg cfg := rfl

theorem sameOramPublicProjection_symm {lhs rhs : OramConfig} :
    sameOramPublicProjection lhs rhs → sameOramPublicProjection rhs lhs := by
  intro h
  exact h.symm

theorem sameOramPublicProjection_trans {a b c : OramConfig} :
    sameOramPublicProjection a b → sameOramPublicProjection b c → sameOramPublicProjection a c := by
  intro hab hbc
  exact hab.trans hbc

@[simp] theorem bucketWindow_length (object : OramObjectManifest) (accessCounter : Nat) :
    (bucketWindow object accessCounter).length = object.bucketsPerAccess := by
  simp [bucketWindow]

@[simp] theorem accessSchedule_metadata_length (object : OramObjectManifest) (accessCounter : Nat) :
    (accessSchedule object accessCounter).metadataPages.length = object.metadataPages := by
  simp [accessSchedule]

@[simp] theorem accessSchedule_bucket_length (object : OramObjectManifest) (accessCounter : Nat) :
    (accessSchedule object accessCounter).bucketIndices.length = object.bucketsPerAccess := by
  simp [accessSchedule, bucketWindow]

theorem mem_metadataPages_lt {object : OramObjectManifest} {accessCounter page : Nat} :
    page ∈ (accessSchedule object accessCounter).metadataPages → page < object.metadataPages := by
  intro hMem
  simpa [accessSchedule] using List.mem_range.mp hMem

theorem mem_bucketWindow_lt_bucketCount
  {object : OramObjectManifest}
  {accessCounter bucket : Nat}
  (hPositive : 0 < object.bucketCount) :
  bucket ∈ bucketWindow object accessCounter →
  bucket < object.bucketCount := by
  intro hMem
  unfold bucketWindow at hMem
  simp [Nat.ne_of_gt hPositive] at hMem
  rcases hMem with ⟨offset, _hOffset, rfl⟩
  exact Nat.mod_lt _ hPositive

theorem totalPhysicalReadsPerAccess_eq_manifest
  {object : OramObjectManifest}
  {accessCounter : Nat}
  (hWellFormed : WellFormedOramObject object) :
  totalPhysicalReadsPerAccess object accessCounter =
    object.metadataPagesPerAccess + object.bucketsPerAccess := by
  rcases hWellFormed with hSurrogate | hPath
  · rcases hSurrogate with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, hMetadata, _hBuckets, _hStash, _hRecursion, _hAccesses⟩
    simp [totalPhysicalReadsPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]
  · rcases hPath with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, _hStash, _hRecursion, hMetadata, _hBuckets, _hAccesses⟩
    simp [totalPhysicalReadsPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]

theorem totalPhysicalWritesPerAccess_eq_manifest
  {object : OramObjectManifest}
  {accessCounter : Nat}
  (hWellFormed : WellFormedOramObject object) :
  totalPhysicalWritesPerAccess object accessCounter =
    object.metadataPagesPerAccess + object.bucketsPerAccess := by
  rcases hWellFormed with hSurrogate | hPath
  · rcases hSurrogate with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, hMetadata, _hBuckets, _hStash, _hRecursion, _hAccesses⟩
    simp [totalPhysicalWritesPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]
  · rcases hPath with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, _hStash, _hRecursion, hMetadata, _hBuckets, _hAccesses⟩
    simp [totalPhysicalWritesPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]

theorem totalPhysicalBudgets_match
  {object : OramObjectManifest}
  {accessCounter : Nat}
  (hWellFormed : WellFormedOramObject object) :
  totalPhysicalReadsPerAccess object accessCounter = totalPhysicalWritesPerAccess object accessCounter := by
  rw [totalPhysicalReadsPerAccess_eq_manifest hWellFormed, totalPhysicalWritesPerAccess_eq_manifest hWellFormed]

theorem accessLeakage_eq_of_samePublicProjection
  {cfg₁ cfg₂ : OramConfig}
  {object : OramObjectManifest} :
  sameOramPublicProjection cfg₁ cfg₂ →
  accessLeakage cfg₁ object = accessLeakage cfg₂ object := by
  cases cfg₁
  cases cfg₂
  intro hPublic
  cases hPublic
  rfl

theorem executionLeakage_eq_of_samePublicProjection
  {cfg₁ cfg₂ : OramConfig} :
  sameOramPublicProjection cfg₁ cfg₂ →
  executionLeakage cfg₁ = executionLeakage cfg₂ := by
  cases cfg₁
  cases cfg₂
  intro hPublic
  cases hPublic
  rfl

theorem computationalUOWith_uses_public_leakage
  (security : OramSecurityInterface)
  (run : OramSemantics)
  (hLocal :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      security.localTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)) :
  ComputationalUOWith security run := by
  intro cfg₁ cfg₂ hPublic
  exact hLocal cfg₁ cfg₂ hPublic

theorem legacyOramLocalTheorem_uses_public_leakage
  (run : OramSemantics)
  (hLocal :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      legacyOramLocalTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)) :
  legacyComputationalUO run := by
  exact computationalUOWith_uses_public_leakage legacyOramSecurityInterface run hLocal

end UOToolchain
