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

structure PathOramPhysicalEventLabel where
  object : String
  location : String
deriving Repr, DecidableEq

structure PathOramStorageLocationTrace where
  readLabels : List PathOramPhysicalEventLabel
  writeLabels : List PathOramPhysicalEventLabel
deriving Repr, DecidableEq

structure PathOramBucketTrace where
  readBuckets : List PathOramPhysicalEventLabel
  writeBuckets : List PathOramPhysicalEventLabel
deriving Repr, DecidableEq

structure PathOramStorageShape where
  readLengths : List Nat
  writeClasses : List String
  writeLengths : List Nat
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

def pathOramPhysicalReadLabel (event : PhysicalRead) : PathOramPhysicalEventLabel :=
  { object := event.object
  , location := event.location
  }

def pathOramPhysicalWriteLabel (event : PhysicalWrite) : PathOramPhysicalEventLabel :=
  { object := event.object
  , location := event.location
  }

def isPathOramBucketLabel
  (label : PathOramPhysicalEventLabel) : Bool :=
  label.location.startsWith (label.object ++ "@bucket")

def pathOramNormalizeLocationLabel
  (label : PathOramPhysicalEventLabel) : PathOramPhysicalEventLabel :=
  if isPathOramBucketLabel label then
    { object := label.object
    , location := label.object ++ "@bucket*"
    }
  else
    label

def pathOramStorageLocationTrace
  (view : OramStorageView) : PathOramStorageLocationTrace :=
  { readLabels := view.physicalReads.map pathOramPhysicalReadLabel
  , writeLabels := view.physicalWrites.map pathOramPhysicalWriteLabel
  }

def pathOramPublicLocationTrace
  (trace : PathOramStorageLocationTrace) : PathOramStorageLocationTrace :=
  { readLabels := trace.readLabels.map pathOramNormalizeLocationLabel
  , writeLabels := trace.writeLabels.map pathOramNormalizeLocationLabel
  }

def pathOramBucketTrace
  (trace : PathOramStorageLocationTrace) : PathOramBucketTrace :=
  { readBuckets := trace.readLabels.filter isPathOramBucketLabel
  , writeBuckets := trace.writeLabels.filter isPathOramBucketLabel
  }

def pathOramStorageShape
  (view : OramStorageView) : PathOramStorageShape :=
  { readLengths := view.physicalReads.map PhysicalRead.len
  , writeClasses := view.physicalWrites.map PhysicalWrite.writeClass
  , writeLengths := view.physicalWrites.map PhysicalWrite.len
  }

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

def pathOramNormalizeLogicalEvent
  (event : LogicalEvent) : LogicalEvent :=
  match event.kind with
  | "uooram_counter" =>
      { kind := event.kind
      , object := event.object
      , detail := "counter"
      }
  | "uooram_metadata_load" =>
      { kind := event.kind
      , object := event.object
      , detail := "page:*"
      }
  | "uooram_path_read" =>
      { kind := event.kind
      , object := event.object
      , detail := "bucket:*"
      }
  | _ => event

def pathOramNormalizeLogicalAccesses
  (logicalAccesses : List LogicalEvent) : List LogicalEvent :=
  logicalAccesses.map pathOramNormalizeLogicalEvent

def pathOramNormalizePublicPart
  (publicPart : OramViewPublicPart) : OramViewPublicPart :=
  { publicPart with
      logicalAccesses := pathOramNormalizeLogicalAccesses publicPart.logicalAccesses
  }

def pathOramViewPublicPart
  (view : ViewMPlus) : OramViewPublicPart :=
  pathOramNormalizePublicPart (oramViewPublicPart view)

@[simp] theorem pathOramViewPublicPart_eq
  (view : ViewMPlus) :
  pathOramViewPublicPart view =
    pathOramNormalizePublicPart (oramViewPublicPart view) := by
  rfl

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

abbrev PathOramLocationRelation :=
  Distribution PathOramStorageLocationTrace →
    Distribution PathOramStorageLocationTrace →
    PathOramProjectedLeakage →
    Prop

abbrev PathOramBucketRelation :=
  Distribution PathOramBucketTrace →
    Distribution PathOramBucketTrace →
    PathOramProjectedLeakage →
    Prop

def pathOramLocationRelationFromBucketRelation
  (bucketRel : PathOramBucketRelation) : PathOramLocationRelation :=
  fun locations₁ locations₂ leakage =>
    bucketRel
      (locations₁.map pathOramBucketTrace)
      (locations₂.map pathOramBucketTrace)
      leakage ∧
    OramExactProjectionRelation pathOramPublicLocationTrace locations₁ locations₂

structure PathOramSecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  freshLeafResampling : Prop
  stashOverflowBounded : Prop
  locationSecurity : PathOramLocationRelation

structure PathOramBucketSecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  freshLeafResampling : Prop
  stashOverflowBounded : Prop
  bucketLocationSecurity : PathOramBucketRelation

def PathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions
  (assumptions : PathOramBucketSecurityAssumptions) :
  PathOramSecurityAssumptions :=
  { bucketEncryptionINDCPA := assumptions.bucketEncryptionINDCPA
  , metadataEncryptionINDCPA := assumptions.metadataEncryptionINDCPA
  , freshLeafResampling := assumptions.freshLeafResampling
  , stashOverflowBounded := assumptions.stashOverflowBounded
  , locationSecurity :=
      pathOramLocationRelationFromBucketRelation assumptions.bucketLocationSecurity
  }

def pathOramProjectedStorageTheorem
  (assumptions : PathOramSecurityAssumptions)
  (storage₁ storage₂ : Distribution OramStorageView)
  (leakage : PathOramProjectedLeakage) : Prop :=
  assumptions.locationSecurity
      (storage₁.map pathOramStorageLocationTrace)
      (storage₂.map pathOramStorageLocationTrace)
      leakage ∧
    OramExactProjectionRelation pathOramStorageShape storage₁ storage₂

def pathOramStandardStorageTheorem
  (assumptions : PathOramSecurityAssumptions)
  (storage₁ storage₂ : Distribution OramStorageView)
  (leakage : List OramAccessLeakage) : Prop :=
  pathOramProjectedStorageTheorem assumptions storage₁ storage₂ (projectPathOramLeakage leakage)

def pathOramViewRelation
  (assumptions : PathOramSecurityAssumptions)
  (views₁ views₂ : Distribution ViewMPlus)
  (leakage : List OramAccessLeakage) : Prop :=
  PathOramLeakage leakage ∧
    OramExactProjectionRelation pathOramViewPublicPart views₁ views₂ ∧
    pathOramStandardStorageTheorem
      assumptions
      (views₁.map oramStorageView)
      (views₂.map oramStorageView)
      leakage

def pathOramStandardSecurityInterface
  (assumptions : PathOramSecurityAssumptions) : StandardOramSecurityInterface :=
  { storageRel := fun storage₁ storage₂ leakage =>
      PathOramLeakage leakage ∧
        pathOramStandardStorageTheorem assumptions storage₁ storage₂ leakage
  }

abbrev proofGradePathOramSecurityInterface
  (assumptions : PathOramSecurityAssumptions) : OramSecurityInterface :=
  { localTheorem := pathOramViewRelation assumptions }

def PathOramPublicViewSafe
  (run : OramSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    OramExactProjectionRelation pathOramViewPublicPart (run cfg₁) (run cfg₂)

theorem oramExactProjectionRelation_projects_to_pathOramViewPublicPart
  {views₁ views₂ : Distribution ViewMPlus}
  (hExact : OramExactProjectionRelation oramViewPublicPart views₁ views₂) :
  OramExactProjectionRelation pathOramViewPublicPart views₁ views₂ := by
  rcases hExact with ⟨value, hViews₁, hViews₂⟩
  refine ⟨pathOramNormalizePublicPart value, ?_, ?_⟩
  · intro view hMem
    rw [pathOramViewPublicPart_eq, hViews₁ view hMem]
  · intro view hMem
    rw [pathOramViewPublicPart_eq, hViews₂ view hMem]

theorem pathOramStandardViewRelation_projects_to_pathOramViewRelation
  (assumptions : PathOramSecurityAssumptions)
  {views₁ views₂ : Distribution ViewMPlus}
  {leakage : List OramAccessLeakage}
  (hStandard :
    standardOramViewRelation
      (pathOramStandardSecurityInterface assumptions)
      views₁
      views₂
      leakage) :
  pathOramViewRelation assumptions views₁ views₂ leakage := by
  rcases hStandard with ⟨hPublic, hStorageRel⟩
  rcases hStorageRel with ⟨hLeakage, hStorage⟩
  exact
    ⟨ hLeakage
    , oramExactProjectionRelation_projects_to_pathOramViewPublicPart hPublic
    , hStorage
    ⟩

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
  intro cfg₁ cfg₂ hSame
  have hStandard :
      standardOramViewRelation
        (pathOramStandardSecurityInterface assumptions)
        (liftOramStorageSemantics publicPart run cfg₁)
        (liftOramStorageSemantics publicPart run cfg₂)
        (executionLeakage cfg₁) := by
    apply standardOramViewRelation_of_publicStorage
      (security := pathOramStandardSecurityInterface assumptions)
      (publicPart := publicPart)
      (run := run)
      cfg₁
      cfg₂
      hSame
      hPublic
    exact
      ⟨ pathOramConfigWellFormed_executionLeakage (hCfg cfg₁)
      , hStorage cfg₁ cfg₂ hSame
      ⟩
  exact pathOramStandardViewRelation_projects_to_pathOramViewRelation assumptions hStandard

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

theorem pathOramProjectedStorageTheorem_of_location_and_shape
  (assumptions : PathOramSecurityAssumptions)
  {storage₁ storage₂ : Distribution OramStorageView}
  {leakage : PathOramProjectedLeakage}
  (hLocation :
    assumptions.locationSecurity
      (storage₁.map pathOramStorageLocationTrace)
      (storage₂.map pathOramStorageLocationTrace)
      leakage)
  (hShape :
    OramExactProjectionRelation pathOramStorageShape storage₁ storage₂) :
  pathOramProjectedStorageTheorem assumptions storage₁ storage₂ leakage := by
  exact ⟨hLocation, hShape⟩

theorem pathOramProjectedStorageTheorem_of_bucketLocationPublicTrace_and_shape
  (assumptions : PathOramBucketSecurityAssumptions)
  {storage₁ storage₂ : Distribution OramStorageView}
  {leakage : PathOramProjectedLeakage}
  (hBucket :
    assumptions.bucketLocationSecurity
      ((storage₁.map pathOramStorageLocationTrace).map pathOramBucketTrace)
      ((storage₂.map pathOramStorageLocationTrace).map pathOramBucketTrace)
      leakage)
  (hPublicLocation :
    OramExactProjectionRelation
      pathOramPublicLocationTrace
      (storage₁.map pathOramStorageLocationTrace)
      (storage₂.map pathOramStorageLocationTrace))
  (hShape :
    OramExactProjectionRelation pathOramStorageShape storage₁ storage₂) :
  pathOramProjectedStorageTheorem
    assumptions.toPathOramSecurityAssumptions
    storage₁
    storage₂
    leakage := by
  apply pathOramProjectedStorageTheorem_of_location_and_shape
    assumptions.toPathOramSecurityAssumptions
  · exact ⟨hBucket, hPublicLocation⟩
  · exact hShape

theorem computationalPathOram_fromLocationAndShape_projects_to_computationalUOWith
  (assumptions : PathOramSecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : OramPublicViewSafe publicPart)
  (hLocation :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      assumptions.locationSecurity
        ((run cfg₁).map pathOramStorageLocationTrace)
        ((run cfg₂).map pathOramStorageLocationTrace)
        (pathOramProjectedExecutionLeakage cfg₁))
  (hShape :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      OramExactProjectionRelation pathOramStorageShape (run cfg₁) (run cfg₂)) :
  ComputationalUOWith
    (proofGradePathOramSecurityInterface assumptions)
    (liftOramStorageSemantics publicPart run) := by
  apply computationalPathOram_projects_to_computationalUOWith assumptions hCfg hPublic
  intro cfg₁ cfg₂ hSame
  apply pathOramProjectedStorageTheorem_projects_to_standard assumptions
  apply pathOramProjectedStorageTheorem_of_location_and_shape assumptions
  · have hLeakageEq :
      pathOramProjectedExecutionLeakage cfg₁ = pathOramProjectedExecutionLeakage cfg₂ :=
        pathOramProjectedLeakage_eq_of_samePublicProjection hSame
    have hLoc := hLocation cfg₁ cfg₂ hSame
    simpa [pathOramProjectedExecutionLeakage] using hLoc
  · exact hShape cfg₁ cfg₂ hSame

theorem computationalPathOram_fromPublicViewAndLocationAndShape_projects_to_computationalUOWith
  (assumptions : PathOramSecurityAssumptions)
  {run : OramSemantics}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : PathOramPublicViewSafe run)
  (hLocation :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      assumptions.locationSecurity
        ((run cfg₁).map (fun view => pathOramStorageLocationTrace (oramStorageView view)))
        ((run cfg₂).map (fun view => pathOramStorageLocationTrace (oramStorageView view)))
        (pathOramProjectedExecutionLeakage cfg₁))
  (hShape :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      OramExactProjectionRelation
        (fun view => pathOramStorageShape (oramStorageView view))
        (run cfg₁)
        (run cfg₂)) :
  ComputationalUOWith
    (proofGradePathOramSecurityInterface assumptions)
    run := by
  intro cfg₁ cfg₂ hSame
  refine
    ⟨ pathOramConfigWellFormed_executionLeakage (hCfg cfg₁)
    , hPublic cfg₁ cfg₂ hSame
    , ?_
    ⟩
  apply pathOramProjectedStorageTheorem_projects_to_standard assumptions
  apply pathOramProjectedStorageTheorem_of_location_and_shape assumptions
  · have hLeakageEq :
      pathOramProjectedExecutionLeakage cfg₁ = pathOramProjectedExecutionLeakage cfg₂ :=
        pathOramProjectedLeakage_eq_of_samePublicProjection hSame
    have hLoc := hLocation cfg₁ cfg₂ hSame
    simpa [pathOramProjectedExecutionLeakage] using hLoc
  · exact
      oramExactProjectionRelation_map
        pathOramStorageShape
        oramStorageView
        (hShape cfg₁ cfg₂ hSame)

theorem computationalPathOram_fromPublicViewBucketLocationAndShape_projects_to_computationalUOWith
  (assumptions : PathOramBucketSecurityAssumptions)
  {run : OramSemantics}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : PathOramPublicViewSafe run)
  (hBucket :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      assumptions.bucketLocationSecurity
        ((run cfg₁).map
          (fun view => pathOramBucketTrace (pathOramStorageLocationTrace (oramStorageView view))))
        ((run cfg₂).map
          (fun view => pathOramBucketTrace (pathOramStorageLocationTrace (oramStorageView view))))
        (pathOramProjectedExecutionLeakage cfg₁))
  (hPublicLocation :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      OramExactProjectionRelation
        pathOramPublicLocationTrace
        ((run cfg₁).map (fun view => pathOramStorageLocationTrace (oramStorageView view)))
        ((run cfg₂).map (fun view => pathOramStorageLocationTrace (oramStorageView view))))
  (hShape :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      OramExactProjectionRelation
        (fun view => pathOramStorageShape (oramStorageView view))
        (run cfg₁)
        (run cfg₂)) :
  ComputationalUOWith
    (proofGradePathOramSecurityInterface assumptions.toPathOramSecurityAssumptions)
    run := by
  apply computationalPathOram_fromPublicViewAndLocationAndShape_projects_to_computationalUOWith
    assumptions.toPathOramSecurityAssumptions
    hCfg
    hPublic
  · intro cfg₁ cfg₂ hSame
    refine ⟨?_, hPublicLocation cfg₁ cfg₂ hSame⟩
    simpa [List.map_map] using hBucket cfg₁ cfg₂ hSame
  · exact hShape

end UOToolchain
