import UOToolchain.CompilerInvariant
import UOToolchain.IRSemantics
import UOToolchain.PathOramTreeShape

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
def privatePathOramScheme : String := "path_oram_private_posmap_v1"

/-- The two Path ORAM schemes: a flat position map (local) and an oblivious
AVL tree whose nodes hold their children's leaves (private). -/
def isPathOramScheme (scheme : String) : Bool :=
  scheme == pathOramScheme || scheme == privatePathOramScheme
def surrogateOramBlocksPerBucket : Nat := 2
def pathOramBlocksPerBucket : Nat := 5

/-- The largest Path ORAM stash bound. By the Path ORAM stash theorem, with
`pathOramBlocksPerBucket = 5` blocks per bucket the stash exceeds `R` blocks
after an access with probability at most `14 · 0.6002 ^ R`, below `2 ^ -108`
at `R = 152`: at most `2 ^ -60` over the `2 ^ 48` node accesses budgeted for
the lifetime of a map. `stashOverflowBounded` assumes this bound. -/
def pathOramStashBoundLimit : Nat := 152

/-- A Path ORAM map's stash bound: its capacity, capped at the limit. A map no
larger than the limit cannot overflow its stash. -/
def pathOramStashBound (capacity : Nat) : Nat :=
  min (max capacity 1) pathOramStashBoundLimit

/-- The private scheme's stash bound: an operation of its AVL map returns
the nodes it read, up to a put's `pathOramTreePutAccesses`, to the stash when
it ends, so the stash bound is the Path ORAM limit plus those nodes, and at
most the capacity. -/
def pathOramTreeStashBound (capacity : Nat) : Nat :=
  pathOramTreeStashBoundWith pathOramStashBoundLimit capacity

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
  object.stashBound = pathOramStashBound object.capacity ∧
  object.recursionDepth = 0 ∧
  object.metadataPagesPerAccess = object.metadataPages + 1 ∧
  object.bucketsPerAccess = object.treeHeight + 1 ∧
  object.accessesPerCall = 1

def WellFormedPrivatePathOramObject (object : OramObjectManifest) : Prop :=
  object.scheme = privatePathOramScheme ∧
  object.blocksPerBucket = pathOramBlocksPerBucket ∧
  object.bucketSize = oramBucketHeaderBytes + object.blocksPerBucket * object.blockSize ∧
  0 < object.bucketCount ∧
  object.stashBound = pathOramTreeStashBound object.capacity ∧
  object.recursionDepth = 1 ∧
  object.metadataPagesPerAccess = object.metadataPages + 1 ∧
  object.bucketsPerAccess = object.treeHeight + 1 ∧
  object.accessesPerCall = 1

def WellFormedOramObject (object : OramObjectManifest) : Prop :=
  WellFormedSurrogateOramObject object ∨
    WellFormedPathOramObject object ∨
    WellFormedPrivatePathOramObject object

/-- A Path ORAM object of either scheme. Both admit several accesses per
call; only the surrogate scheme is single-access. -/
def WellFormedAnyPathOramObject (object : OramObjectManifest) : Prop :=
  WellFormedPathOramObject object ∨ WellFormedPrivatePathOramObject object

/-- The sealed records an access reads: its buckets. The call reads the
map's counter and metadata pages once, when it loads the map
(`callStartPhysicalReads`), and holds them. -/
def totalPhysicalReadsPerAccess (object : OramObjectManifest) (accessCounter : Nat) : Nat :=
  (accessSchedule object accessCounter).bucketIndices.length

/-- The sealed records a call reads from a map when it loads it: the counter
and every metadata page. -/
def callStartPhysicalReads (object : OramObjectManifest) : Nat :=
  1 + object.metadataPages

def totalPhysicalWritesPerAccess (object : OramObjectManifest) (accessCounter : Nat) : Nat :=
  1 + (accessSchedule object accessCounter).metadataPages.length +
    (accessSchedule object accessCounter).bucketIndices.length

abbrev OramLocalTheorem :=
  Distribution ViewMPlus → Distribution ViewMPlus → List OramAccessLeakage → Prop

structure OramSecurityInterface where
  localTheorem : OramLocalTheorem

def ComputationalUOWith (security : OramSecurityInterface) (run : OramSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    security.localTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)

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
  {accessCounter : Nat} :
  totalPhysicalReadsPerAccess object accessCounter = object.bucketsPerAccess := by
  simp [totalPhysicalReadsPerAccess, accessSchedule, bucketWindow]

theorem callStartPhysicalReads_eq_manifest
  {object : OramObjectManifest}
  (hWellFormed : WellFormedOramObject object) :
  callStartPhysicalReads object = object.metadataPagesPerAccess := by
  rcases hWellFormed with hSurrogate | hPathOrPrivate
  · rcases hSurrogate with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, hMetadata, _hBuckets, _hStash, _hRecursion, _hAccesses⟩
    unfold callStartPhysicalReads; omega
  · rcases hPathOrPrivate with hPath | hPrivate
    · rcases hPath with
        ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, _hStash, _hRecursion, hMetadata, _hBuckets, _hAccesses⟩
      unfold callStartPhysicalReads; omega
    · rcases hPrivate with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, _hStash, _hRecursion, hMetadata, _hBuckets, _hAccesses⟩
      unfold callStartPhysicalReads; omega

theorem totalPhysicalWritesPerAccess_eq_manifest
  {object : OramObjectManifest}
  {accessCounter : Nat}
  (hWellFormed : WellFormedOramObject object) :
  totalPhysicalWritesPerAccess object accessCounter =
    object.metadataPagesPerAccess + object.bucketsPerAccess := by
  rcases hWellFormed with hSurrogate | hPathOrPrivate
  · rcases hSurrogate with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, hMetadata, _hBuckets, _hStash, _hRecursion, _hAccesses⟩
    simp [totalPhysicalWritesPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]
  · rcases hPathOrPrivate with hPath | hPrivate
    · rcases hPath with
        ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, _hStash, _hRecursion, hMetadata, _hBuckets, _hAccesses⟩
      simp [totalPhysicalWritesPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]
    · rcases hPrivate with
      ⟨_hScheme, _hBlocks, _hBucketSize, _hBucketCount, _hStash, _hRecursion, hMetadata, _hBuckets, _hAccesses⟩
      simp [totalPhysicalWritesPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]

/-- A call that makes one access to a map reads what it writes: the counter
and the metadata pages when it loads the map, and the access's buckets. -/
theorem totalPhysicalBudgets_match
  {object : OramObjectManifest}
  {accessCounter : Nat}
  (hWellFormed : WellFormedOramObject object) :
  callStartPhysicalReads object + totalPhysicalReadsPerAccess object accessCounter =
    totalPhysicalWritesPerAccess object accessCounter := by
  rw [callStartPhysicalReads_eq_manifest hWellFormed, totalPhysicalReadsPerAccess_eq_manifest,
    totalPhysicalWritesPerAccess_eq_manifest hWellFormed]

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

end UOToolchain
