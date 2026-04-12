import Lean.Data.Json
import UOToolchain.RuntimeRefinement

open Lean

namespace UOToolchain

inductive ImportedWriteClass where
  | Set
  | Clear
  | Same
  | Update
deriving Repr, DecidableEq

instance : FromJson ImportedWriteClass where
  fromJson? j := do
    match (← j.getStr?) with
    | "Set" => pure .Set
    | "Clear" => pure .Clear
    | "Same" => pure .Same
    | "Update" => pure .Update
    | value => throw s!"unexpected write class '{value}'"

instance : ToJson ImportedWriteClass where
  toJson
    | .Set => Json.str "Set"
    | .Clear => Json.str "Clear"
    | .Same => Json.str "Same"
    | .Update => Json.str "Update"

def ImportedWriteClass.toWriteClassString : ImportedWriteClass → String
  | .Set => "Set"
  | .Clear => "Clear"
  | .Same => "Same"
  | .Update => "Update"

inductive ImportedBoundaryDirection where
  | Enter
  | Exit
deriving Repr, DecidableEq

instance : FromJson ImportedBoundaryDirection where
  fromJson? j := do
    match (← j.getStr?) with
    | "Enter" => pure .Enter
    | "Exit" => pure .Exit
    | value => throw s!"unexpected boundary direction '{value}'"

instance : ToJson ImportedBoundaryDirection where
  toJson
    | .Enter => Json.str "Enter"
    | .Exit => Json.str "Exit"

def ImportedBoundaryDirection.toBoundaryDirection : ImportedBoundaryDirection → BoundaryDirection
  | .Enter => .enter
  | .Exit => .exit

inductive ImportedControllerPhase where
  | EnclaveEnter
  | StageRequest
  | DescendPositionMap
  | LoadMetadata
  | FetchPath
  | ScanStash
  | RewritePath
  | AscendPositionMap
  | SealPersistentState
  | EnclaveExit
deriving Repr, DecidableEq

instance : FromJson ImportedControllerPhase where
  fromJson? j := do
    match (← j.getStr?) with
    | "EnclaveEnter" => pure .EnclaveEnter
    | "StageRequest" => pure .StageRequest
    | "DescendPositionMap" => pure .DescendPositionMap
    | "LoadMetadata" => pure .LoadMetadata
    | "FetchPath" => pure .FetchPath
    | "ScanStash" => pure .ScanStash
    | "RewritePath" => pure .RewritePath
    | "AscendPositionMap" => pure .AscendPositionMap
    | "SealPersistentState" => pure .SealPersistentState
    | "EnclaveExit" => pure .EnclaveExit
    | value => throw s!"unexpected controller phase '{value}'"

instance : ToJson ImportedControllerPhase where
  toJson
    | .EnclaveEnter => Json.str "EnclaveEnter"
    | .StageRequest => Json.str "StageRequest"
    | .DescendPositionMap => Json.str "DescendPositionMap"
    | .LoadMetadata => Json.str "LoadMetadata"
    | .FetchPath => Json.str "FetchPath"
    | .ScanStash => Json.str "ScanStash"
    | .RewritePath => Json.str "RewritePath"
    | .AscendPositionMap => Json.str "AscendPositionMap"
    | .SealPersistentState => Json.str "SealPersistentState"
    | .EnclaveExit => Json.str "EnclaveExit"

def ImportedControllerPhase.toControllerPhase : ImportedControllerPhase → SGXControllerPhase
  | .EnclaveEnter => .enclaveEnter
  | .StageRequest => .stageRequest
  | .DescendPositionMap => .descendPositionMap
  | .LoadMetadata => .loadMetadata
  | .FetchPath => .fetchPath
  | .ScanStash => .scanStash
  | .RewritePath => .rewritePath
  | .AscendPositionMap => .ascendPositionMap
  | .SealPersistentState => .sealPersistentState
  | .EnclaveExit => .enclaveExit

inductive ImportedPageEventKind where
  | FaultIn
  | EvictOut
deriving Repr, DecidableEq

instance : FromJson ImportedPageEventKind where
  fromJson? j := do
    match (← j.getStr?) with
    | "FaultIn" => pure .FaultIn
    | "EvictOut" => pure .EvictOut
    | value => throw s!"unexpected page event kind '{value}'"

instance : ToJson ImportedPageEventKind where
  toJson
    | .FaultIn => Json.str "FaultIn"
    | .EvictOut => Json.str "EvictOut"

def ImportedPageEventKind.toPageEventKind : ImportedPageEventKind → PageEventKind
  | .FaultIn => .faultIn
  | .EvictOut => .evictOut

inductive ImportedExitEvent where
  | InterruptExit
  | Resume
  | Terminate
deriving Repr, DecidableEq

instance : FromJson ImportedExitEvent where
  fromJson? j := do
    match (← j.getStr?) with
    | "InterruptExit" => pure .InterruptExit
    | "Resume" => pure .Resume
    | "Terminate" => pure .Terminate
    | value => throw s!"unexpected exit event '{value}'"

instance : ToJson ImportedExitEvent where
  toJson
    | .InterruptExit => Json.str "InterruptExit"
    | .Resume => Json.str "Resume"
    | .Terminate => Json.str "Terminate"

def ImportedExitEvent.toExitEvent : ImportedExitEvent → ExitEvent
  | .InterruptExit => .interruptExit
  | .Resume => .resume
  | .Terminate => .terminate

structure ImportedLogicalEvent where
  kind : String
  object : String
  detail : String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedLogicalEvent.toLogicalEvent (event : ImportedLogicalEvent) : LogicalEvent :=
  { kind := event.kind
  , object := event.object
  , detail := event.detail
  }

structure ImportedPhysicalReadEvent where
  object : String
  location : String
  len : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedPhysicalReadEvent.toPhysicalRead (event : ImportedPhysicalReadEvent) : PhysicalRead :=
  { object := event.object
  , location := event.location
  , len := event.len
  }

structure ImportedRefinementPhysicalWrite where
  object : String
  location : String
  write_class : ImportedWriteClass
  len : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRefinementPhysicalWrite.toPhysicalWrite
  (event : ImportedRefinementPhysicalWrite) : PhysicalWrite :=
  { object := event.object
  , location := event.location
  , writeClass := event.write_class.toWriteClassString
  , len := event.len
  }

structure ImportedRefinementTrace where
  opcode_trace : List String
  logical_accesses : List ImportedLogicalEvent
  logical_writes : List ImportedLogicalEvent
  physical_reads : List ImportedPhysicalReadEvent
  physical_writes : List ImportedRefinementPhysicalWrite
  gas_used : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRefinementTrace.toTrace (trace : ImportedRefinementTrace) : Trace :=
  { opcodeTrace := trace.opcode_trace
  , logicalAccesses := trace.logical_accesses.map ImportedLogicalEvent.toLogicalEvent
  , logicalWrites := trace.logical_writes.map ImportedLogicalEvent.toLogicalEvent
  , physicalReads := trace.physical_reads.map ImportedPhysicalReadEvent.toPhysicalRead
  , physicalWrites := trace.physical_writes.map ImportedRefinementPhysicalWrite.toPhysicalWrite
  , gasUsed := trace.gas_used
  }

structure ImportedOutputShape where
  return_present : Bool
  return_length : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedOutputShape.toOutputShape (shape : ImportedOutputShape) : OutputShape :=
  { returnPresent := shape.return_present
  , returnLength := shape.return_length
  }

structure ImportedPublicOutcomeTrace where
  entrypoint_id : String
  public_args : List String
  termination_status : Bool
  output_shape : ImportedOutputShape
  gas_used : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedPublicOutcomeTrace.toPublicOutcome
  (outcome : ImportedPublicOutcomeTrace) : SGXPublicOutcome :=
  { entrypointId := outcome.entrypoint_id
  , publicArgs := outcome.public_args
  , terminationStatus := outcome.termination_status
  , outputShape := outcome.output_shape.toOutputShape
  , gasUsed := outcome.gas_used
  }

structure ImportedBoundaryEvent where
  direction : ImportedBoundaryDirection
  api_id : String
  input_len : Nat
  output_len : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedBoundaryEvent.toBoundaryEvent (event : ImportedBoundaryEvent) : BoundaryEvent :=
  { direction := event.direction.toBoundaryDirection
  , apiId := event.api_id
  , inputLen := event.input_len
  , outputLen := event.output_len
  }

structure ImportedControllerPageBudget where
  page_kind : String
  event_budget : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedControllerPageBudget.toControllerPageBudget
  (budget : ImportedControllerPageBudget) : SGXControllerPageBudget :=
  { pageKind := budget.page_kind
  , eventBudget := budget.event_budget
  }

structure ImportedSgxControllerShapeTrace where
  boundary_event_budget : Nat
  controller_phase_order : List ImportedControllerPhase
  page_trace_regions : List ImportedControllerPageBudget
  workset_regions : List ImportedControllerPageBudget
  exit_trace_budget : Nat
  shared_resource_budget : Nat
  recursive_position_map_depth : Nat
  stash_bound : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedSgxControllerShapeTrace.toControllerShape
  (shape : ImportedSgxControllerShapeTrace) : SGXControllerShape :=
  { boundaryEventBudget := shape.boundary_event_budget
  , phaseTrace := shape.controller_phase_order.map ImportedControllerPhase.toControllerPhase
  , pageTraceRegions := shape.page_trace_regions.map ImportedControllerPageBudget.toControllerPageBudget
  , worksetRegions := shape.workset_regions.map ImportedControllerPageBudget.toControllerPageBudget
  , exitTraceBudget := shape.exit_trace_budget
  , sharedResourceBudget := shape.shared_resource_budget
  , recursivePositionMapDepth := shape.recursive_position_map_depth
  , stashBound := shape.stash_bound
  }

structure ImportedNormalizedPageEvent where
  page_kind : String
  kind : ImportedPageEventKind
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedNormalizedPageEvent.toNormalizedPageEvent
  (event : ImportedNormalizedPageEvent) : NormalizedPageEvent :=
  { pageKind := event.page_kind
  , kind := event.kind.toPageEventKind
  }

structure ImportedNormalizedMicroTrace where
  page_trace : List ImportedNormalizedPageEvent
  exit_pattern : List ImportedExitEvent
  shared_resource_pattern : List String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedNormalizedMicroTrace.toNormalizedMicroTrace
  (trace : ImportedNormalizedMicroTrace) : NormalizedMicroTrace :=
  { pageTrace := trace.page_trace.map ImportedNormalizedPageEvent.toNormalizedPageEvent
  , exitPattern := trace.exit_pattern.map ImportedExitEvent.toExitEvent
  , sharedResourcePattern := trace.shared_resource_pattern
  }

structure ImportedRuntimeOramAccessCertificate where
  object_id : Nat
  scheme : String
  metadata_pages_per_access : Nat
  buckets_per_access : Nat
  recursion_depth : Nat
  stash_bound : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeOramAccessCertificate.toRuntimeOramAccessCertificate
  (access : ImportedRuntimeOramAccessCertificate) : RuntimeOramAccessCertificate :=
  { objectId := access.object_id
  , scheme := access.scheme
  , metadataPagesPerAccess := access.metadata_pages_per_access
  , bucketsPerAccess := access.buckets_per_access
  , recursionDepth := access.recursion_depth
  , stashBound := access.stash_bound
  }

structure ImportedRuntimeControllerCertificate where
  entry_input_len : Nat
  observed_oram_accesses : List ImportedRuntimeOramAccessCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeControllerCertificate.toRuntimeControllerCertificate
  (certificate : ImportedRuntimeControllerCertificate) : RuntimeControllerCertificate :=
  { entryInputLen := certificate.entry_input_len
  , observedOramAccesses := certificate.observed_oram_accesses.map
      ImportedRuntimeOramAccessCertificate.toRuntimeOramAccessCertificate
  }

structure ImportedRuntimeOramLeafCertificate where
  object_id : Nat
  object_name : String
  bucket_count : Nat
  leaf : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeOramLeafCertificate.toRuntimeOramLeafCertificate
  (leaf : ImportedRuntimeOramLeafCertificate) : RuntimeOramLeafCertificate :=
  { objectId := leaf.object_id
  , objectName := leaf.object_name
  , bucketCount := leaf.bucket_count
  , leaf := leaf.leaf
  }

structure ImportedRuntimeOramLeafScaffoldCertificate where
  object_id : Nat
  object_name : String
  bucket_count : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep
  (leaf : ImportedRuntimeOramLeafScaffoldCertificate) : RuntimePathOramLeafScaffoldStep :=
  { objectId := leaf.object_id
  , objectName := leaf.object_name
  , bucketCount := leaf.bucket_count
  }

structure ImportedRuntimeOramObjectCertificate where
  object_id : Nat
  object_name : String
  scheme : String
  capacity : Nat
  block_size : Nat
  bucket_size : Nat
  bucket_count : Nat
  blocks_per_bucket : Nat
  tree_height : Nat
  stash_bound : Nat
  recursion_depth : Nat
  metadata_pages : Nat
  metadata_pages_per_access : Nat
  buckets_per_access : Nat
  accesses_per_call : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeOramObjectCertificate.toRuntimeOramObjectCertificate
  (object : ImportedRuntimeOramObjectCertificate) : RuntimeOramObjectCertificate :=
  { objectId := object.object_id
  , objectName := object.object_name
  , scheme := object.scheme
  , capacity := object.capacity
  , blockSize := object.block_size
  , bucketSize := object.bucket_size
  , bucketCount := object.bucket_count
  , blocksPerBucket := object.blocks_per_bucket
  , treeHeight := object.tree_height
  , stashBound := object.stash_bound
  , recursionDepth := object.recursion_depth
  , metadataPages := object.metadata_pages
  , metadataPagesPerAccess := object.metadata_pages_per_access
  , bucketsPerAccess := object.buckets_per_access
  , accessesPerCall := object.accesses_per_call
  }

structure ImportedRuntimeRefinementWitness where
  trace : ImportedRefinementTrace
  runtime_seed : Option Nat
  public_outcome : ImportedPublicOutcomeTrace
  boundary_schedule : List ImportedBoundaryEvent
  controller_shape : ImportedSgxControllerShapeTrace
  normalized_micro_trace : ImportedNormalizedMicroTrace
  controller_certificate : ImportedRuntimeControllerCertificate
  oram_objects : List ImportedRuntimeOramObjectCertificate
  oram_leaf_public_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
  oram_leaf_schedule : List ImportedRuntimeOramLeafCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeRefinementWitness.toRuntimeWitness
  (witness : ImportedRuntimeRefinementWitness) : RuntimeRefinementWitness :=
  { trace := witness.trace.toTrace
  , runtimeSeed := witness.runtime_seed
  , publicOutcome := witness.public_outcome.toPublicOutcome
  , boundarySchedule := witness.boundary_schedule.map ImportedBoundaryEvent.toBoundaryEvent
  , controllerShape := witness.controller_shape.toControllerShape
  , normalizedMicroTrace := witness.normalized_micro_trace.toNormalizedMicroTrace
  , controllerCertificate := witness.controller_certificate.toRuntimeControllerCertificate
  , oramObjects := witness.oram_objects.map
      ImportedRuntimeOramObjectCertificate.toRuntimeOramObjectCertificate
  , oramLeafPublicScaffold := witness.oram_leaf_public_scaffold.map
      ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep
  , oramLeafSchedule := witness.oram_leaf_schedule.map
      ImportedRuntimeOramLeafCertificate.toRuntimeOramLeafCertificate
  }

def ImportedRuntimeRefinementWitness.Valid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.toRuntimeWitness.Valid modelTags

def ImportedRuntimeRefinementWitness.checkValid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  witness.toRuntimeWitness.checkValid modelTags

def parseImportedRuntimeRefinementWitness
  (input : String) : Except String ImportedRuntimeRefinementWitness := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeRefinementWitness
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeRefinementWitness := do
  let witness ← parseImportedRuntimeRefinementWitness input
  if witness.checkValid modelTags then
    pure witness
  else
    throw "imported runtime refinement witness does not satisfy Lean validity checks"

def loadImportedRuntimeRefinementWitness
  (path : System.FilePath) : IO ImportedRuntimeRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeRefinementWitness input with
  | .ok witness => pure witness
  | .error err => throw <| IO.userError s!"failed to parse runtime refinement witness: {err}"

def loadAndCheckImportedRuntimeRefinementWitness
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeRefinementWitness input modelTags with
  | .ok witness => pure witness
  | .error err => throw <| IO.userError s!"failed to validate runtime refinement witness: {err}"

@[simp] theorem importedWitness_valid_iff
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.Valid modelTags ↔ witness.toRuntimeWitness.Valid modelTags := by
  rfl

@[simp] theorem importedWitness_checkValid_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkValid modelTags = true ↔ witness.Valid modelTags := by
  unfold ImportedRuntimeRefinementWitness.checkValid ImportedRuntimeRefinementWitness.Valid
  exact runtimeWitness_checkValid_eq_true_iff witness.toRuntimeWitness modelTags

theorem importedWitness_projects_to_paper_observer
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.Valid modelTags) :
  sgxPublicOutcome witness.toRuntimeWitness.sgxView = witness.toRuntimeWitness.publicOutcome ∧
    witness.toRuntimeWitness.sgxView.boundarySchedule =
      witness.toRuntimeWitness.boundarySchedule ∧
    sgxStorageTrace witness.toRuntimeWitness.sgxView =
      witness.toRuntimeWitness.storageTrace ∧
    normalizeMicroTrace (sgxMicroTrace witness.toRuntimeWitness.sgxView) =
      witness.toRuntimeWitness.normalizedMicroTrace := by
  exact runtimeWitness_projects_to_paper_observer witness.toRuntimeWitness modelTags hValid

def sampleImportedRuntimeRefinementWitness : ImportedRuntimeRefinementWitness :=
  { trace :=
      { opcode_trace := ["declare"]
      , logical_accesses := []
      , logical_writes := []
      , physical_reads :=
          [{ object := "records", location := "records@bucket0", len := 64 }]
      , physical_writes :=
          [{ object := "records"
           , location := "records@bucket0"
           , write_class := .Update
           , len := 64
           }]
      , gas_used := 7
      }
  , runtime_seed := none
  , public_outcome :=
      { entrypoint_id := "put(bytes32,uint256)"
      , public_args := []
      , termination_status := true
      , output_shape := { return_present := false, return_length := 0 }
      , gas_used := 7
      }
  , boundary_schedule :=
      [ { direction := .Enter
        , api_id := "put(bytes32,uint256)"
        , input_len := 64
        , output_len := 0
        }
      , { direction := .Exit
        , api_id := "put(bytes32,uint256)"
        , input_len := 0
        , output_len := 0
        }
      ]
  , controller_shape :=
      { boundary_event_budget := 2
      , controller_phase_order := [.EnclaveEnter, .SealPersistentState, .EnclaveExit]
      , page_trace_regions :=
          [ { page_kind := "metadata", event_budget := 0 }
          , { page_kind := "position_map", event_budget := 0 }
          , { page_kind := "path", event_budget := 0 }
          , { page_kind := "stash", event_budget := 0 }
          ]
      , workset_regions :=
          [ { page_kind := "metadata", event_budget := 0 }
          , { page_kind := "position_map", event_budget := 0 }
          , { page_kind := "path", event_budget := 0 }
          , { page_kind := "stash", event_budget := 0 }
          ]
      , exit_trace_budget := 4
      , shared_resource_budget := 3
      , recursive_position_map_depth := 0
      , stash_bound := 0
      }
  , normalized_micro_trace :=
      { page_trace := []
      , exit_pattern := [.Resume, .InterruptExit, .Resume, .Terminate]
      , shared_resource_pattern :=
          [ "shared_resource_tick"
          , "shared_resource_tick"
          , "shared_resource_tick"
          ]
      }
  , controller_certificate :=
      { entry_input_len := 64
      , observed_oram_accesses := []
      }
  , oram_objects := []
  , oram_leaf_public_scaffold := []
  , oram_leaf_schedule := []
  }

def sampleImportedRuntimeRefinementWitnessRoundtrip : Bool :=
  match
      parseImportedRuntimeRefinementWitness
        (Json.compress (toJson sampleImportedRuntimeRefinementWitness))
    with
    | .ok witness => decide (witness = sampleImportedRuntimeRefinementWitness)
    | .error _ => false

example : sampleImportedRuntimeRefinementWitnessRoundtrip = true := by
  native_decide

end UOToolchain
