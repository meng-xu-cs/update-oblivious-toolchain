import UOToolchain.StandardOramReduction

namespace UOToolchain

structure PathOramProjectedAccessLeakage where
  entrypointId : String
  publicGasBudget : Nat
  objectId : Nat
  capacity : Nat
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
deriving Repr, DecidableEq

def projectPathOramAccessLeakage
  (access : OramAccessLeakage) : PathOramProjectedAccessLeakage :=
  { entrypointId := access.entrypointId
  , publicGasBudget := access.publicGasBudget
  , objectId := access.objectId
  , capacity := access.capacity
  , blockSize := access.blockSize
  , bucketSize := access.bucketSize
  , bucketCount := access.bucketCount
  , blocksPerBucket := access.blocksPerBucket
  , treeHeight := access.treeHeight
  , stashBound := access.stashBound
  , recursionDepth := access.recursionDepth
  , metadataPages := access.metadataPages
  , metadataPagesPerAccess := access.metadataPagesPerAccess
  , bucketsPerAccess := access.bucketsPerAccess
  , accessesPerCall := access.accessesPerCall
  , accessesPerEntrypoint := access.accessesPerEntrypoint
  }

abbrev PathOramProjectedLeakage := List PathOramProjectedAccessLeakage

def projectPathOramLeakage
  (leakage : List OramAccessLeakage) : PathOramProjectedLeakage :=
  leakage.map projectPathOramAccessLeakage

def pathOramProjectedExecutionLeakage
  (cfg : OramConfig) : PathOramProjectedLeakage :=
  projectPathOramLeakage (executionLeakage cfg)

def PathOramAccessLeakage (access : OramAccessLeakage) : Prop :=
  access.scheme = pathOramScheme ∧
  access.blocksPerBucket = pathOramBlocksPerBucket ∧
  access.bucketSize = oramBucketHeaderBytes + access.blocksPerBucket * access.blockSize ∧
  0 < access.bucketCount ∧
  access.stashBound = max access.capacity 1 ∧
  access.recursionDepth = 0 ∧
  access.metadataPagesPerAccess = access.metadataPages + 1 ∧
  access.bucketsPerAccess = access.treeHeight + 1 ∧
  access.accessesPerCall = 1

def PathOramLeakage (leakage : List OramAccessLeakage) : Prop :=
  ∀ access, access ∈ leakage → PathOramAccessLeakage access

def PathOramConfigWellFormed (cfg : OramConfig) : Prop :=
  ∀ object, object ∈ cfg.pubData.witness.oramObjects → WellFormedPathOramObject object

theorem pathOramAccessLeakage_of_wellFormedObject
  (cfg : OramConfig)
  {object : OramObjectManifest}
  (hObject : WellFormedPathOramObject object) :
  PathOramAccessLeakage (accessLeakage cfg object) := by
  rcases hObject with
    ⟨hScheme, hBlocks, hBucketSize, hBucketCount, hStash, hRecursion, hMetadata, hBuckets, hAccesses⟩
  simp [PathOramAccessLeakage, accessLeakage, hScheme, hBlocks, hBucketSize, hBucketCount,
    hStash, hRecursion, hMetadata, hBuckets, hAccesses]

theorem pathOramConfigWellFormed_executionLeakage
  {cfg : OramConfig}
  (hCfg : PathOramConfigWellFormed cfg) :
  PathOramLeakage (executionLeakage cfg) := by
  intro access hMem
  unfold executionLeakage at hMem
  rcases List.mem_map.mp hMem with ⟨object, hObjectMem, hEq⟩
  rw [← hEq]
  exact pathOramAccessLeakage_of_wellFormedObject cfg (hCfg object hObjectMem)

theorem pathOramProjectedLeakage_eq_of_samePublicProjection
  {cfg₁ cfg₂ : OramConfig} :
  sameOramPublicProjection cfg₁ cfg₂ →
  pathOramProjectedExecutionLeakage cfg₁ = pathOramProjectedExecutionLeakage cfg₂ := by
  intro hSame
  unfold pathOramProjectedExecutionLeakage
  rw [executionLeakage_eq_of_samePublicProjection hSame]

structure PathOramSecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  freshLeafResampling : Prop
  stashOverflowBounded : Prop

axiom pathOramProjectedStorageTheorem
  (assumptions : PathOramSecurityAssumptions)
  (storage₁ storage₂ : Distribution OramStorageView)
  (leakage : PathOramProjectedLeakage) :
  Prop

def pathOramStandardStorageTheorem
  (assumptions : PathOramSecurityAssumptions)
  (storage₁ storage₂ : Distribution OramStorageView)
  (leakage : List OramAccessLeakage) : Prop :=
  pathOramProjectedStorageTheorem assumptions storage₁ storage₂ (projectPathOramLeakage leakage)

def pathOramStandardSecurityInterface
  (assumptions : PathOramSecurityAssumptions) : StandardOramSecurityInterface :=
  { storageRel := fun storage₁ storage₂ leakage =>
      PathOramLeakage leakage ∧
        pathOramStandardStorageTheorem assumptions storage₁ storage₂ leakage
  }

abbrev proofGradePathOramSecurityInterface
  (assumptions : PathOramSecurityAssumptions) : OramSecurityInterface :=
  (pathOramStandardSecurityInterface assumptions).toOramSecurityInterface

theorem computationalPathOram_projects_to_computationalUOWith
  (assumptions : PathOramSecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : OramPublicViewSafe publicPart)
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      pathOramStandardStorageTheorem assumptions (run cfg₁) (run cfg₂) (executionLeakage cfg₁)) :
  ComputationalUOWith
    (proofGradePathOramSecurityInterface assumptions)
    (liftOramStorageSemantics publicPart run) := by
  apply computationalStandardOram_projects_to_computationalUOWith
  · exact hPublic
  · intro cfg₁ cfg₂ hSame
    exact ⟨pathOramConfigWellFormed_executionLeakage (hCfg cfg₁), hStorage cfg₁ cfg₂ hSame⟩

theorem pathOramStandardSecurityInterface_uses_pathLeakage
  (assumptions : PathOramSecurityAssumptions)
  {storage₁ storage₂ : Distribution OramStorageView}
  {leakage : List OramAccessLeakage}
  (hLeakage : PathOramLeakage leakage)
  (hStorage : pathOramStandardStorageTheorem assumptions storage₁ storage₂ leakage) :
  (pathOramStandardSecurityInterface assumptions).storageRel storage₁ storage₂ leakage := by
  exact ⟨hLeakage, hStorage⟩

theorem pathOramProjectedStorageTheorem_projects_to_standard
  (assumptions : PathOramSecurityAssumptions)
  {storage₁ storage₂ : Distribution OramStorageView}
  {leakage : List OramAccessLeakage} :
  pathOramProjectedStorageTheorem
      assumptions
      storage₁
      storage₂
      (projectPathOramLeakage leakage) →
    pathOramStandardStorageTheorem assumptions storage₁ storage₂ leakage := by
  intro h
  exact h

end UOToolchain
