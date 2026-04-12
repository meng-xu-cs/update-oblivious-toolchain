import UOToolchain.CompilerInvariant
import UOToolchain.IRSemantics

namespace UOToolchain

structure OramObjectManifest where
  objectId : Nat
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

def WellFormedOramObject (object : OramObjectManifest) : Prop :=
  object.scheme = "surrogate_public_schedule_v1" ∧
  object.bucketSize = oramBucketHeaderBytes + object.blocksPerBucket * object.blockSize ∧
  0 < object.bucketCount ∧
  0 < object.blocksPerBucket ∧
  object.metadataPagesPerAccess = object.metadataPages + 1 ∧
  object.bucketsPerAccess = max (object.treeHeight + 2) 3 ∧
  object.accessesPerCall = 1

def totalPhysicalReadsPerAccess (object : OramObjectManifest) (accessCounter : Nat) : Nat :=
  1 + (accessSchedule object accessCounter).metadataPages.length +
    (accessSchedule object accessCounter).bucketIndices.length

def totalPhysicalWritesPerAccess (object : OramObjectManifest) (accessCounter : Nat) : Nat :=
  1 + (accessSchedule object accessCounter).metadataPages.length +
    (accessSchedule object accessCounter).bucketIndices.length

axiom oramLocalTheorem
  (view₁ view₂ : Distribution ViewMPlus)
  (leakage : List OramAccessLeakage) :
  Prop

abbrev OramLocalTheorem :=
  Distribution ViewMPlus → Distribution ViewMPlus → List OramAccessLeakage → Prop

structure OramSecurityInterface where
  localTheorem : OramLocalTheorem

def surrogateOramSecurityInterface : OramSecurityInterface :=
  { localTheorem := oramLocalTheorem }

def ComputationalUOWith (security : OramSecurityInterface) (run : OramSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    security.localTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)

abbrev ComputationalUO (run : OramSemantics) : Prop :=
  ComputationalUOWith surrogateOramSecurityInterface run

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
  rcases hWellFormed with ⟨_hScheme, _hBucketSize, _hBucketCount, _hBlocks, hMetadata, _hBuckets, _hAccesses⟩
  simp [totalPhysicalReadsPerAccess, hMetadata, Nat.add_left_comm, Nat.add_comm]

theorem totalPhysicalWritesPerAccess_eq_manifest
  {object : OramObjectManifest}
  {accessCounter : Nat}
  (hWellFormed : WellFormedOramObject object) :
  totalPhysicalWritesPerAccess object accessCounter =
    object.metadataPagesPerAccess + object.bucketsPerAccess := by
  rcases hWellFormed with ⟨_hScheme, _hBucketSize, _hBucketCount, _hBlocks, hMetadata, _hBuckets, _hAccesses⟩
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

theorem oramLocalTheorem_uses_public_leakage
  (run : OramSemantics)
  (hLocal :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      oramLocalTheorem (run cfg₁) (run cfg₂) (executionLeakage cfg₁)) :
  ComputationalUO run := by
  exact computationalUOWith_uses_public_leakage surrogateOramSecurityInterface run hLocal

end UOToolchain
