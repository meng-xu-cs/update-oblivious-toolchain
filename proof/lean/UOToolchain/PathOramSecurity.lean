import UOToolchain.FiniteDistribution
import UOToolchain.StandardOramReduction

namespace UOToolchain

structure PathOramProjectedAccessLeakage where
  entrypointId : String
  publicGasBudget : Nat
  objectId : Nat
  objectName : String
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

structure PathOramLeafScheduleStep where
  object : String
  bucketCount : Nat
  leaf : Nat
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
  , objectName := access.objectName
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

abbrev PathOramLeafScheduleTrace := List PathOramLeafScheduleStep
abbrev PathOramLeafScheduleScaffold := List (String × Nat)
abbrev PathOramLeafValueTrace := List Nat

def pathOramLeafScheduleScaffold
  (trace : PathOramLeafScheduleTrace) : PathOramLeafScheduleScaffold :=
  trace.map fun step => (step.object, step.bucketCount)

def pathOramLeafValues
  (trace : PathOramLeafScheduleTrace) : PathOramLeafValueTrace :=
  trace.map PathOramLeafScheduleStep.leaf

def pathOramBucketCountByObjectName?
  (leakage : PathOramProjectedLeakage)
  (objectName : String) : Option Nat :=
  match leakage.find? (fun access => access.objectName = objectName) with
  | some access => some access.bucketCount
  | none => none

def pathOramLeafScheduleScaffoldOfLogicalAccesses
  (logicalAccesses : List LogicalEvent)
  (leakage : PathOramProjectedLeakage) : Option PathOramLeafScheduleScaffold :=
  let counters :=
    logicalAccesses.filter fun event =>
      event.kind = "uooram_counter" && event.detail = "counter"
  let bucketCounts := counters.map fun event =>
    pathOramBucketCountByObjectName? leakage event.object
  if bucketCounts.all Option.isSome then
    some <|
      counters.zip bucketCounts |>.map fun
        | (event, some bucketCount) => (event.object, bucketCount)
        | (_event, none) => ("", 0)
  else
    none

def pathOramLeafScheduleScaffoldOfPublicPart
  (publicPart : OramViewPublicPart)
  (leakage : PathOramProjectedLeakage) : Option PathOramLeafScheduleScaffold :=
  pathOramLeafScheduleScaffoldOfLogicalAccesses publicPart.logicalAccesses leakage

def pathOramLeafCount
  (bucketCount : Nat) : Nat :=
  (bucketCount + 1) / 2

def pathOramLeafChoiceCount
  (bucketCount : Nat) : Nat :=
  max (pathOramLeafCount bucketCount) 1

def pathOramUniformLeafValueDistribution
  (bucketCount : Nat) : FiniteDistribution Nat :=
  FiniteDistribution.chooseNat (pathOramLeafChoiceCount bucketCount)

def pathOramLeafValueDistributionOfScaffold :
  PathOramLeafScheduleScaffold → FiniteDistribution PathOramLeafValueTrace
  | [] => FiniteDistribution.pure []
  | (_object, bucketCount) :: scaffold =>
      FiniteDistribution.productWith
        (pathOramUniformLeafValueDistribution bucketCount)
        (pathOramLeafValueDistributionOfScaffold scaffold)
        List.cons

def pathOramBucketPathOfNodeAux : Nat → Nat → List Nat
  | 0, _ => []
  | _fuel + 1, 0 => [0]
  | fuel + 1, node + 1 =>
      pathOramBucketPathOfNodeAux fuel (node / 2) ++ [node + 1]

def pathOramBucketPathOfNode
  (node : Nat) : List Nat :=
  pathOramBucketPathOfNodeAux (node + 1) node

def pathOramBucketIndicesOfLeafStep
  (step : PathOramLeafScheduleStep) : List Nat :=
  let leafCount := max (pathOramLeafCount step.bucketCount) 1
  let node := leafCount - 1 + step.leaf % leafCount
  pathOramBucketPathOfNode node

def pathOramBucketLabelOfIndex
  (object : String)
  (index : Nat) : PathOramPhysicalEventLabel :=
  { object := object
  , location := s!"{object}@bucket{index}"
  }

def concatPathOramPhysicalEventLabels :
  List (List PathOramPhysicalEventLabel) → List PathOramPhysicalEventLabel
  | [] => []
  | labels :: traces => labels ++ concatPathOramPhysicalEventLabels traces

def pathOramReadBucketLabelsOfLeafStep
  (step : PathOramLeafScheduleStep) : List PathOramPhysicalEventLabel :=
  (pathOramBucketIndicesOfLeafStep step).map fun index =>
    pathOramBucketLabelOfIndex step.object index

def pathOramWriteBucketLabelsOfLeafStep
  (step : PathOramLeafScheduleStep) : List PathOramPhysicalEventLabel :=
  (pathOramBucketIndicesOfLeafStep step).reverse.map fun index =>
    pathOramBucketLabelOfIndex step.object index

def pathOramBucketTraceOfLeafScheduleTrace
  (trace : PathOramLeafScheduleTrace) : PathOramBucketTrace :=
  { readBuckets := concatPathOramPhysicalEventLabels (trace.map pathOramReadBucketLabelsOfLeafStep)
  , writeBuckets := concatPathOramPhysicalEventLabels (trace.map pathOramWriteBucketLabelsOfLeafStep)
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

abbrev PathOramLeafScheduleRelation :=
  Distribution PathOramLeafScheduleTrace →
    Distribution PathOramLeafScheduleTrace →
    PathOramProjectedLeakage →
    Prop

abbrev PathOramLeafValueRelation :=
  Distribution PathOramLeafValueTrace →
    Distribution PathOramLeafValueTrace →
    PathOramProjectedLeakage →
    Prop

def canonicalPathOramLeafValueRelation : PathOramLeafValueRelation :=
  fun leaves₁ leaves₂ _leakage =>
    ∃ scaffold,
      leaves₁ = (pathOramLeafValueDistributionOfScaffold scaffold).samples ∧
      leaves₂ = (pathOramLeafValueDistributionOfScaffold scaffold).samples

def pathOramLeafScheduleRelationFromLeafValueRelation
  (leafValueRel : PathOramLeafValueRelation) : PathOramLeafScheduleRelation :=
  fun leaves₁ leaves₂ leakage =>
    leafValueRel
      (leaves₁.map pathOramLeafValues)
      (leaves₂.map pathOramLeafValues)
      leakage ∧
    OramExactProjectionRelation pathOramLeafScheduleScaffold leaves₁ leaves₂

def pathOramBucketRelationFromLeafScheduleRelation
  (leafRel : PathOramLeafScheduleRelation) : PathOramBucketRelation :=
  fun buckets₁ buckets₂ leakage =>
    ∃ leaves₁ leaves₂,
      leafRel leaves₁ leaves₂ leakage ∧
      OramExactProjectionRelation pathOramLeafScheduleScaffold leaves₁ leaves₂ ∧
      buckets₁ = leaves₁.map pathOramBucketTraceOfLeafScheduleTrace ∧
      buckets₂ = leaves₂.map pathOramBucketTraceOfLeafScheduleTrace

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

structure PathOramLeafSecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  freshLeafResampling : Prop
  stashOverflowBounded : Prop
  leafScheduleSecurity : PathOramLeafScheduleRelation

structure PathOramLeafValueSecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  freshLeafResampling : Prop
  stashOverflowBounded : Prop
  leafValueSecurity : PathOramLeafValueRelation

structure PathOramCanonicalLeafValueSecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  freshLeafResampling : Prop
  stashOverflowBounded : Prop

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

def PathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions
  (assumptions : PathOramLeafSecurityAssumptions) :
  PathOramBucketSecurityAssumptions :=
  { bucketEncryptionINDCPA := assumptions.bucketEncryptionINDCPA
  , metadataEncryptionINDCPA := assumptions.metadataEncryptionINDCPA
  , freshLeafResampling := assumptions.freshLeafResampling
  , stashOverflowBounded := assumptions.stashOverflowBounded
  , bucketLocationSecurity :=
      pathOramBucketRelationFromLeafScheduleRelation assumptions.leafScheduleSecurity
  }

def PathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions
  (assumptions : PathOramLeafValueSecurityAssumptions) :
  PathOramLeafSecurityAssumptions :=
  { bucketEncryptionINDCPA := assumptions.bucketEncryptionINDCPA
  , metadataEncryptionINDCPA := assumptions.metadataEncryptionINDCPA
  , freshLeafResampling := assumptions.freshLeafResampling
  , stashOverflowBounded := assumptions.stashOverflowBounded
  , leafScheduleSecurity :=
      pathOramLeafScheduleRelationFromLeafValueRelation assumptions.leafValueSecurity
  }

def PathOramCanonicalLeafValueSecurityAssumptions.toPathOramLeafValueSecurityAssumptions
  (assumptions : PathOramCanonicalLeafValueSecurityAssumptions) :
  PathOramLeafValueSecurityAssumptions :=
  { bucketEncryptionINDCPA := assumptions.bucketEncryptionINDCPA
  , metadataEncryptionINDCPA := assumptions.metadataEncryptionINDCPA
  , freshLeafResampling := assumptions.freshLeafResampling
  , stashOverflowBounded := assumptions.stashOverflowBounded
  , leafValueSecurity := canonicalPathOramLeafValueRelation
  }

def pathOramBucketTraceOfView
  (view : ViewMPlus) : PathOramBucketTrace :=
  pathOramBucketTrace (pathOramStorageLocationTrace (oramStorageView view))

def PathOramLeafSchedulePublicAlignment
  (leafs : Distribution PathOramLeafScheduleTrace)
  (publicPart : OramViewPublicPart)
  (leakage : PathOramProjectedLeakage) : Prop :=
  ∃ scaffold,
    pathOramLeafScheduleScaffoldOfPublicPart publicPart leakage = some scaffold ∧
    OramConstantProjection pathOramLeafScheduleScaffold leafs scaffold

def PathOramLeafValueCanonicalOnPublicPart
  (leafValues : Distribution PathOramLeafValueTrace)
  (publicPart : OramViewPublicPart)
  (leakage : PathOramProjectedLeakage) : Prop :=
  ∃ scaffold,
    pathOramLeafScheduleScaffoldOfPublicPart publicPart leakage = some scaffold ∧
    leafValues = (pathOramLeafValueDistributionOfScaffold scaffold).samples

theorem pathOramLeafSchedulePublicAlignment_exact
  {leafs₁ leafs₂ : Distribution PathOramLeafScheduleTrace}
  {publicPart : OramViewPublicPart}
  {leakage : PathOramProjectedLeakage}
  (hLeafs₁ : PathOramLeafSchedulePublicAlignment leafs₁ publicPart leakage)
  (hLeafs₂ : PathOramLeafSchedulePublicAlignment leafs₂ publicPart leakage) :
  OramExactProjectionRelation pathOramLeafScheduleScaffold leafs₁ leafs₂ := by
  rcases hLeafs₁ with ⟨scaffold₁, hScaffold₁, hConst₁⟩
  rcases hLeafs₂ with ⟨scaffold₂, hScaffold₂, hConst₂⟩
  apply oramExactProjectionRelation_of_constant
  · have hSome : some scaffold₁ = some scaffold₂ := hScaffold₁.symm.trans hScaffold₂
    exact Option.some.inj hSome
  · exact hConst₁
  · exact hConst₂

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

theorem pathOramLeafSchedulePublicAlignment_exact_of_samePublicProjection
  {run : OramSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (hPublic : PathOramPublicViewSafe run)
  (hLeafPublic :
    ∀ cfg publicPart,
      OramConstantProjection pathOramViewPublicPart (run cfg) publicPart →
      PathOramLeafSchedulePublicAlignment
        (leafRun cfg)
        publicPart
        (pathOramProjectedExecutionLeakage cfg))
  {cfg₁ cfg₂ : OramConfig}
  (hSame : sameOramPublicProjection cfg₁ cfg₂) :
  OramExactProjectionRelation
    pathOramLeafScheduleScaffold
    (leafRun cfg₁)
    (leafRun cfg₂) := by
  rcases hPublic cfg₁ cfg₂ hSame with ⟨publicPart, hPublicConst₁, hPublicConst₂⟩
  apply pathOramLeafSchedulePublicAlignment_exact
  · exact hLeafPublic cfg₁ publicPart hPublicConst₁
  · have hLeakageEq :
        pathOramProjectedExecutionLeakage cfg₁ = pathOramProjectedExecutionLeakage cfg₂ :=
      pathOramProjectedLeakage_eq_of_samePublicProjection hSame
    simpa [hLeakageEq] using hLeafPublic cfg₂ publicPart hPublicConst₂

theorem canonicalPathOramLeafValueRelation_of_samePublicProjection
  {run : OramSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (hPublic : PathOramPublicViewSafe run)
  (hLeafCanonical :
    ∀ cfg publicPart,
      OramConstantProjection pathOramViewPublicPart (run cfg) publicPart →
      PathOramLeafValueCanonicalOnPublicPart
        ((leafRun cfg).map pathOramLeafValues)
        publicPart
        (pathOramProjectedExecutionLeakage cfg))
  {cfg₁ cfg₂ : OramConfig}
  (hSame : sameOramPublicProjection cfg₁ cfg₂) :
  canonicalPathOramLeafValueRelation
    ((leafRun cfg₁).map pathOramLeafValues)
    ((leafRun cfg₂).map pathOramLeafValues)
    (pathOramProjectedExecutionLeakage cfg₁) := by
  rcases hPublic cfg₁ cfg₂ hSame with ⟨publicPart, hPublicConst₁, hPublicConst₂⟩
  rcases hLeafCanonical cfg₁ publicPart hPublicConst₁ with ⟨scaffold₁, hScaffold₁, hLeafs₁⟩
  rcases hLeafCanonical cfg₂ publicPart hPublicConst₂ with ⟨scaffold₂, hScaffold₂, hLeafs₂⟩
  have hLeakageEq :
      pathOramProjectedExecutionLeakage cfg₁ = pathOramProjectedExecutionLeakage cfg₂ :=
    pathOramProjectedLeakage_eq_of_samePublicProjection hSame
  have hScaffold₂' :
      pathOramLeafScheduleScaffoldOfPublicPart
        publicPart
        (pathOramProjectedExecutionLeakage cfg₁) = some scaffold₂ := by
    simpa [hLeakageEq] using hScaffold₂
  have hSome : some scaffold₁ = some scaffold₂ := hScaffold₁.symm.trans hScaffold₂'
  have hScaffoldEq : scaffold₁ = scaffold₂ := Option.some.inj hSome
  refine ⟨scaffold₁, hLeafs₁, ?_⟩
  simpa [hScaffoldEq] using hLeafs₂

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

theorem pathOramProjectedStorageTheorem_of_leafScheduleBucketLocationPublicTrace_and_shape
  (assumptions : PathOramLeafSecurityAssumptions)
  {storage₁ storage₂ : Distribution OramStorageView}
  {leafs₁ leafs₂ : Distribution PathOramLeafScheduleTrace}
  {leakage : PathOramProjectedLeakage}
  (hLeaf :
    assumptions.leafScheduleSecurity
      leafs₁
      leafs₂
      leakage)
  (hLeafScaffold :
    OramExactProjectionRelation
      pathOramLeafScheduleScaffold
      leafs₁
      leafs₂)
  (hBucket₁ :
    (storage₁.map pathOramStorageLocationTrace).map pathOramBucketTrace =
      leafs₁.map pathOramBucketTraceOfLeafScheduleTrace)
  (hBucket₂ :
    (storage₂.map pathOramStorageLocationTrace).map pathOramBucketTrace =
      leafs₂.map pathOramBucketTraceOfLeafScheduleTrace)
  (hPublicLocation :
    OramExactProjectionRelation
      pathOramPublicLocationTrace
      (storage₁.map pathOramStorageLocationTrace)
      (storage₂.map pathOramStorageLocationTrace))
  (hShape :
    OramExactProjectionRelation pathOramStorageShape storage₁ storage₂) :
  pathOramProjectedStorageTheorem
    assumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions
    storage₁
    storage₂
    leakage := by
  apply pathOramProjectedStorageTheorem_of_bucketLocationPublicTrace_and_shape
    assumptions.toPathOramBucketSecurityAssumptions
  · refine ⟨leafs₁, leafs₂, hLeaf, hLeafScaffold, hBucket₁, hBucket₂⟩
  · exact hPublicLocation
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

theorem computationalPathOram_fromPublicViewLeafScheduleBucketLocationAndShape_projects_to_computationalUOWith
  (assumptions : PathOramLeafSecurityAssumptions)
  {run : OramSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : PathOramPublicViewSafe run)
  (hLeaf :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      assumptions.leafScheduleSecurity
        (leafRun cfg₁)
        (leafRun cfg₂)
        (pathOramProjectedExecutionLeakage cfg₁))
  (hLeafPublic :
    ∀ cfg publicPart,
      OramConstantProjection pathOramViewPublicPart (run cfg) publicPart →
      PathOramLeafSchedulePublicAlignment
        (leafRun cfg)
        publicPart
        (pathOramProjectedExecutionLeakage cfg))
  (hBucketProjection :
    ∀ cfg,
      (run cfg).map pathOramBucketTraceOfView =
        (leafRun cfg).map pathOramBucketTraceOfLeafScheduleTrace)
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
    (proofGradePathOramSecurityInterface
      assumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions)
    run := by
  apply computationalPathOram_fromPublicViewBucketLocationAndShape_projects_to_computationalUOWith
    assumptions.toPathOramBucketSecurityAssumptions
    hCfg
    hPublic
  · intro cfg₁ cfg₂ hSame
    refine
      ⟨ leafRun cfg₁
      , leafRun cfg₂
      , hLeaf cfg₁ cfg₂ hSame
      , pathOramLeafSchedulePublicAlignment_exact_of_samePublicProjection hPublic hLeafPublic hSame
      , ?_
      , ?_
      ⟩
    · exact hBucketProjection cfg₁
    · exact hBucketProjection cfg₂
  · exact hPublicLocation
  · exact hShape

theorem computationalPathOram_fromPublicViewLeafValuesBucketLocationAndShape_projects_to_computationalUOWith
  (assumptions : PathOramLeafValueSecurityAssumptions)
  {run : OramSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : PathOramPublicViewSafe run)
  (hLeafValues :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      assumptions.leafValueSecurity
        ((leafRun cfg₁).map pathOramLeafValues)
        ((leafRun cfg₂).map pathOramLeafValues)
        (pathOramProjectedExecutionLeakage cfg₁))
  (hLeafPublic :
    ∀ cfg publicPart,
      OramConstantProjection pathOramViewPublicPart (run cfg) publicPart →
      PathOramLeafSchedulePublicAlignment
        (leafRun cfg)
        publicPart
        (pathOramProjectedExecutionLeakage cfg))
  (hBucketProjection :
    ∀ cfg,
      (run cfg).map pathOramBucketTraceOfView =
        (leafRun cfg).map pathOramBucketTraceOfLeafScheduleTrace)
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
    (proofGradePathOramSecurityInterface
      assumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions)
    run := by
  apply computationalPathOram_fromPublicViewLeafScheduleBucketLocationAndShape_projects_to_computationalUOWith
    assumptions.toPathOramLeafSecurityAssumptions
    hCfg
    hPublic
  · intro cfg₁ cfg₂ hSame
    refine
      ⟨ hLeafValues cfg₁ cfg₂ hSame
      , pathOramLeafSchedulePublicAlignment_exact_of_samePublicProjection hPublic hLeafPublic hSame
      ⟩
  · exact hLeafPublic
  · exact hBucketProjection
  · exact hPublicLocation
  · exact hShape

theorem computationalPathOram_fromPublicViewCanonicalLeafValuesBucketLocationAndShape_projects_to_computationalUOWith
  (assumptions : PathOramCanonicalLeafValueSecurityAssumptions)
  {run : OramSemantics}
  {leafRun : OramConfig → Distribution PathOramLeafScheduleTrace}
  (hCfg : ∀ cfg, PathOramConfigWellFormed cfg)
  (hPublic : PathOramPublicViewSafe run)
  (hLeafCanonical :
    ∀ cfg publicPart,
      OramConstantProjection pathOramViewPublicPart (run cfg) publicPart →
      PathOramLeafValueCanonicalOnPublicPart
        ((leafRun cfg).map pathOramLeafValues)
        publicPart
        (pathOramProjectedExecutionLeakage cfg))
  (hLeafPublic :
    ∀ cfg publicPart,
      OramConstantProjection pathOramViewPublicPart (run cfg) publicPart →
      PathOramLeafSchedulePublicAlignment
        (leafRun cfg)
        publicPart
        (pathOramProjectedExecutionLeakage cfg))
  (hBucketProjection :
    ∀ cfg,
      (run cfg).map pathOramBucketTraceOfView =
        (leafRun cfg).map pathOramBucketTraceOfLeafScheduleTrace)
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
    (proofGradePathOramSecurityInterface
      assumptions.toPathOramLeafValueSecurityAssumptions.toPathOramLeafSecurityAssumptions.toPathOramBucketSecurityAssumptions.toPathOramSecurityAssumptions)
    run := by
  apply computationalPathOram_fromPublicViewLeafValuesBucketLocationAndShape_projects_to_computationalUOWith
    assumptions.toPathOramLeafValueSecurityAssumptions
    hCfg
    hPublic
  · intro cfg₁ cfg₂ hSame
    exact canonicalPathOramLeafValueRelation_of_samePublicProjection hPublic hLeafCanonical hSame
  · exact hLeafPublic
  · exact hBucketProjection
  · exact hPublicLocation
  · exact hShape

end UOToolchain
