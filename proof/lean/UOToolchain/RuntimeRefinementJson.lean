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

structure ImportedRuntimeControllerObserverCertificate where
  public_outcome : ImportedPublicOutcomeTrace
  boundary_schedule : List ImportedBoundaryEvent
  controller_shape : ImportedSgxControllerShapeTrace
  normalized_micro_trace : ImportedNormalizedMicroTrace
  controller_certificate : ImportedRuntimeControllerCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeControllerObserverCertificate.toRuntimeControllerObserverCertificate
  (certificate : ImportedRuntimeControllerObserverCertificate) :
  RuntimeControllerObserverCertificate :=
  { publicOutcome := certificate.public_outcome.toPublicOutcome
  , boundarySchedule := certificate.boundary_schedule.map ImportedBoundaryEvent.toBoundaryEvent
  , controllerShape := certificate.controller_shape.toControllerShape
  , normalizedMicroTrace := certificate.normalized_micro_trace.toNormalizedMicroTrace
  , controllerCertificate := certificate.controller_certificate.toRuntimeControllerCertificate
  }

def ImportedRuntimeControllerObserverCertificate.Valid
  (certificate : ImportedRuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) : Prop :=
  certificate.toRuntimeControllerObserverCertificate.Valid modelTags

def ImportedRuntimeControllerObserverCertificate.checkValid
  (certificate : ImportedRuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) : Bool :=
  certificate.toRuntimeControllerObserverCertificate.checkValid modelTags

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

inductive ImportedRuntimePathOramTransitionKind where
  | ReadMiss
  | ReadHit
  | WriteNoop
  | WriteInsert
  | WriteUpdate
  | WriteDelete
deriving Repr, DecidableEq

instance : FromJson ImportedRuntimePathOramTransitionKind where
  fromJson? j := do
    match (← j.getStr?) with
    | "ReadMiss" => pure .ReadMiss
    | "ReadHit" => pure .ReadHit
    | "WriteNoop" => pure .WriteNoop
    | "WriteInsert" => pure .WriteInsert
    | "WriteUpdate" => pure .WriteUpdate
    | "WriteDelete" => pure .WriteDelete
    | value => throw s!"unexpected path-ORAM transition kind '{value}'"

instance : ToJson ImportedRuntimePathOramTransitionKind where
  toJson
    | .ReadMiss => Json.str "ReadMiss"
    | .ReadHit => Json.str "ReadHit"
    | .WriteNoop => Json.str "WriteNoop"
    | .WriteInsert => Json.str "WriteInsert"
    | .WriteUpdate => Json.str "WriteUpdate"
    | .WriteDelete => Json.str "WriteDelete"

def ImportedRuntimePathOramTransitionKind.toRuntimePathOramTransitionKind :
  ImportedRuntimePathOramTransitionKind → RuntimePathOramTransitionKind
  | .ReadMiss => .readMiss
  | .ReadHit => .readHit
  | .WriteNoop => .writeNoop
  | .WriteInsert => .writeInsert
  | .WriteUpdate => .writeUpdate
  | .WriteDelete => .writeDelete

structure ImportedRuntimeMaskedUsizeOptionWitness where
  present : Bool
  value : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeMaskedUsizeOptionWitness.toOption
  (witness : ImportedRuntimeMaskedUsizeOptionWitness) : Option Nat :=
  if witness.present then some witness.value else none

def ImportedRuntimeMaskedUsizeOptionWitness.Valid
  (witness : ImportedRuntimeMaskedUsizeOptionWitness) : Prop :=
  witness.present = true ∨ witness.value = 0

def ImportedRuntimeMaskedUsizeOptionWitness.checkValid
  (witness : ImportedRuntimeMaskedUsizeOptionWitness) : Bool :=
  witness.present || witness.value == 0

@[simp] theorem importedRuntimeMaskedUsizeOptionWitness_checkValid_eq_true_iff
  (witness : ImportedRuntimeMaskedUsizeOptionWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  cases witness.present <;>
    simp [ImportedRuntimeMaskedUsizeOptionWitness.checkValid,
      ImportedRuntimeMaskedUsizeOptionWitness.Valid]

theorem importedRuntimeMaskedUsizeOptionWitness_rejects_noncanonical_absent
  (value : Nat) :
  ({ present := false, value := value + 1 } :
      ImportedRuntimeMaskedUsizeOptionWitness).checkValid = false := by
  simp [ImportedRuntimeMaskedUsizeOptionWitness.checkValid]

structure ImportedRuntimePathOramTransitionCertificate where
  object_id : Nat
  object_name : String
  bucket_count : Nat
  kind : ImportedRuntimePathOramTransitionKind
  slot_index : ImportedRuntimeMaskedUsizeOptionWitness
  prior_leaf : ImportedRuntimeMaskedUsizeOptionWitness
  next_leaf : ImportedRuntimeMaskedUsizeOptionWitness
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimePathOramTransitionCertificate.maskedOptionShapeValid
  (transition : ImportedRuntimePathOramTransitionCertificate) : Bool :=
  transition.slot_index.checkValid &&
    transition.prior_leaf.checkValid &&
    transition.next_leaf.checkValid

def ImportedRuntimePathOramTransitionCertificate.toRuntimePathOramTransitionCertificate
  (transition : ImportedRuntimePathOramTransitionCertificate) :
  RuntimePathOramTransitionCertificate :=
  { objectId := transition.object_id
  , objectName := transition.object_name
  , bucketCount := transition.bucket_count
  , kind := transition.kind.toRuntimePathOramTransitionKind
  , slotIndex := transition.slot_index.toOption
  , priorLeaf := transition.prior_leaf.toOption
  , nextLeaf := transition.next_leaf.toOption
  }

structure ImportedRuntimePathOramPositionMapCertificate where
  object_id : Nat
  object_name : String
  leaves : List ImportedRuntimeMaskedUsizeOptionWitness
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimePathOramPositionMapCertificate.maskedOptionShapeValid
  (state : ImportedRuntimePathOramPositionMapCertificate) : Bool :=
  state.leaves.all ImportedRuntimeMaskedUsizeOptionWitness.checkValid

def ImportedRuntimePathOramPositionMapCertificate.toRuntimePathOramPositionMapCertificate
  (state : ImportedRuntimePathOramPositionMapCertificate) :
  RuntimePathOramPositionMapCertificate :=
  { objectId := state.object_id
  , objectName := state.object_name
  , leaves := state.leaves.map ImportedRuntimeMaskedUsizeOptionWitness.toOption
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

structure ImportedRuntimePathOramHiddenCertificate where
  trace : ImportedRefinementTrace
  oram_objects : List ImportedRuntimeOramObjectCertificate
  oram_leaf_public_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
  oram_leaf_schedule : List ImportedRuntimeOramLeafCertificate
  oram_position_map_before : List ImportedRuntimePathOramPositionMapCertificate
  oram_position_map_after : List ImportedRuntimePathOramPositionMapCertificate
  oram_leaf_state_transitions : List ImportedRuntimePathOramTransitionCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimePathOramHiddenCertificate.toRuntimePathOramHiddenCertificate
  (certificate : ImportedRuntimePathOramHiddenCertificate) :
  RuntimePathOramHiddenCertificate :=
  { trace := certificate.trace.toTrace
  , oramObjects := certificate.oram_objects.map
      ImportedRuntimeOramObjectCertificate.toRuntimeOramObjectCertificate
  , oramLeafPublicScaffold := certificate.oram_leaf_public_scaffold.map
      ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep
  , oramLeafSchedule := certificate.oram_leaf_schedule.map
      ImportedRuntimeOramLeafCertificate.toRuntimeOramLeafCertificate
  , oramPositionMapBefore := certificate.oram_position_map_before.map
      ImportedRuntimePathOramPositionMapCertificate.toRuntimePathOramPositionMapCertificate
  , oramPositionMapAfter := certificate.oram_position_map_after.map
      ImportedRuntimePathOramPositionMapCertificate.toRuntimePathOramPositionMapCertificate
  , oramLeafStateTransitions := certificate.oram_leaf_state_transitions.map
      ImportedRuntimePathOramTransitionCertificate.toRuntimePathOramTransitionCertificate
  }

def ImportedRuntimePathOramHiddenCertificate.maskedOptionShapeValid
  (certificate : ImportedRuntimePathOramHiddenCertificate) : Bool :=
  certificate.oram_position_map_before.all
      ImportedRuntimePathOramPositionMapCertificate.maskedOptionShapeValid &&
    certificate.oram_position_map_after.all
      ImportedRuntimePathOramPositionMapCertificate.maskedOptionShapeValid &&
    certificate.oram_leaf_state_transitions.all
      ImportedRuntimePathOramTransitionCertificate.maskedOptionShapeValid

def ImportedRuntimePathOramHiddenCertificate.Valid
  (certificate : ImportedRuntimePathOramHiddenCertificate) : Prop :=
  certificate.toRuntimePathOramHiddenCertificate.Valid ∧
    certificate.maskedOptionShapeValid = true

def ImportedRuntimePathOramHiddenCertificate.checkValid
  (certificate : ImportedRuntimePathOramHiddenCertificate) : Bool :=
  certificate.toRuntimePathOramHiddenCertificate.checkValid &&
    certificate.maskedOptionShapeValid

def importedRuntimeKernelOpcodeNames : List String :=
  [ "Begin"
  , "CellGet"
  , "CellSet"
  , "ArrayGet"
  , "ArraySet"
  , "MapGet"
  , "MapPut"
  , "Commit"
  , "Wipe"
  ]

def importedRuntimeKernelObjectOpcodeNames : List String :=
  [ "CellGet"
  , "CellSet"
  , "ArrayGet"
  , "ArraySet"
  , "MapGet"
  , "MapPut"
  ]

def importedRuntimeKernelOpcodeRequiresObjectId
  (opcode : String) : Bool :=
  decide (opcode ∈ importedRuntimeKernelObjectOpcodeNames)

structure ImportedRuntimeKernelStep where
  opcode : String
  object_id : Option Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeKernelStep.toRuntimeKernelStep
  (step : ImportedRuntimeKernelStep) : RuntimeKernelStep :=
  { opcode := step.opcode
  , objectId := step.object_id
  }

def ImportedRuntimeKernelStep.checkShapeValid
  (step : ImportedRuntimeKernelStep) : Bool :=
  decide (step.object_id.isSome = importedRuntimeKernelOpcodeRequiresObjectId step.opcode)

structure ImportedRuntimeKernelSchedule where
  opcodes : List String
  steps : List ImportedRuntimeKernelStep
deriving Repr, DecidableEq

def ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule
  (schedule : ImportedRuntimeKernelSchedule) : RuntimeKernelSchedule :=
  { opcodes := schedule.opcodes
  , steps := schedule.steps.map ImportedRuntimeKernelStep.toRuntimeKernelStep
  }

def ImportedRuntimeKernelSchedule.projectedOpcodes
  (schedule : ImportedRuntimeKernelSchedule) : List String :=
  schedule.steps.map ImportedRuntimeKernelStep.opcode

def ImportedRuntimeKernelSchedule.publicObjectSchedule
  (schedule : ImportedRuntimeKernelSchedule) : List Nat :=
  schedule.steps.filterMap ImportedRuntimeKernelStep.object_id

@[simp] theorem importedRuntimeKernelStepList_toRuntime_publicObjectSchedule
  (steps : List ImportedRuntimeKernelStep) :
  List.filterMap (RuntimeKernelStep.objectId ∘ ImportedRuntimeKernelStep.toRuntimeKernelStep) steps =
    List.filterMap ImportedRuntimeKernelStep.object_id steps := by
  induction steps with
  | nil =>
      simp
  | cons step rest ih =>
      cases hObject : step.object_id <;>
        simp [ImportedRuntimeKernelStep.toRuntimeKernelStep, hObject, ih]

@[simp] theorem importedRuntimeKernelSchedule_toRuntimeKernelSchedule_publicObjectSchedule
  (schedule : ImportedRuntimeKernelSchedule) :
  schedule.toRuntimeKernelSchedule.publicObjectSchedule = schedule.publicObjectSchedule := by
  cases schedule with
  | mk opcodes steps =>
      simp [ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule,
        ImportedRuntimeKernelSchedule.publicObjectSchedule,
        RuntimeKernelSchedule.publicObjectSchedule]

def ImportedRuntimeKernelSchedule.opcodesAllowed
  (schedule : ImportedRuntimeKernelSchedule) : Bool :=
  schedule.opcodes.all (fun opcode => decide (opcode ∈ importedRuntimeKernelOpcodeNames))

def ImportedRuntimeKernelSchedule.checkShapeValid
  (schedule : ImportedRuntimeKernelSchedule) : Bool :=
  schedule.steps.all ImportedRuntimeKernelStep.checkShapeValid &&
    decide (schedule.steps = [] ∨ schedule.projectedOpcodes = schedule.opcodes)

def ImportedRuntimeKernelSchedule.checkRunsToCompletion
  (schedule : ImportedRuntimeKernelSchedule) : Bool :=
  schedule.toRuntimeKernelSchedule.checkRunsToCompletion

def ImportedRuntimeKernelSchedule.hasBeginCommitWipeEnvelope
  (schedule : ImportedRuntimeKernelSchedule) : Bool :=
  decide (schedule.opcodes.head? = some "Begin") &&
    decide
      (schedule.opcodes.drop (schedule.opcodes.length - 2) = ["Commit", "Wipe"])

def ImportedRuntimeKernelSchedule.Valid
  (schedule : ImportedRuntimeKernelSchedule) : Prop :=
  schedule.opcodesAllowed = true ∧
    schedule.checkShapeValid = true ∧
    schedule.hasBeginCommitWipeEnvelope = true ∧
    schedule.checkRunsToCompletion = true

def ImportedRuntimeKernelSchedule.checkValid
  (schedule : ImportedRuntimeKernelSchedule) : Bool :=
  schedule.opcodesAllowed &&
    schedule.checkShapeValid &&
    schedule.hasBeginCommitWipeEnvelope &&
    schedule.checkRunsToCompletion

@[simp] theorem importedRuntimeKernelSchedule_checkValid_eq_true_iff
  (schedule : ImportedRuntimeKernelSchedule) :
  schedule.checkValid = true ↔ schedule.Valid := by
  simp [ImportedRuntimeKernelSchedule.checkValid, ImportedRuntimeKernelSchedule.Valid, and_assoc]

@[simp] theorem importedRuntimeKernelSchedule_checkRunsToCompletion_eq_true_iff
  (schedule : ImportedRuntimeKernelSchedule) :
  schedule.checkRunsToCompletion = true ↔
    ∃ finalState, schedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  simp [ImportedRuntimeKernelSchedule.checkRunsToCompletion,
    runtimeKernelSchedule_checkRunsToCompletion_eq_true_iff]

theorem importedRuntimeKernelSchedule_valid_finalState_exact
  {schedule : ImportedRuntimeKernelSchedule}
  (hValid : schedule.Valid) :
  schedule.toRuntimeKernelSchedule.finalState? =
    some { phase := .finished, publicObjectSchedule := schedule.publicObjectSchedule } := by
  rcases (importedRuntimeKernelSchedule_checkRunsToCompletion_eq_true_iff schedule).mp
      hValid.2.2.2 with
    ⟨finalState, hFinal, hFinished⟩
  have hObjects : finalState.publicObjectSchedule = schedule.publicObjectSchedule := by
    simpa [ImportedRuntimeKernelSchedule.publicObjectSchedule] using
      runtimeKernelSchedule_finalState_publicObjectSchedule hFinal
  cases finalState with
  | mk phase publicObjectSchedule =>
      simp at hFinished hObjects
      simp [hFinal, hFinished, hObjects]

structure ImportedRuntimeKernelResourceEvent where
  kind : String
  region : Option String
  words : Option Nat
  bytes : Option Nat
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedRuntimeKernelWitness where
  entrypoint_id : String
  arena_bytes : Nat
  max_stack_words : Nat
  scratch_bytes : Nat
  peak_stack_words : Nat
  value_scratch_peak_bytes : Nat
  value_scratch_live_bytes_end : Nat
  value_scratch_wipe_count : Nat
  hash_scratch_peak_bytes : Nat
  hash_scratch_live_bytes_end : Nat
  hash_scratch_wipe_count : Nat
  io_scratch_peak_bytes : Nat
  io_scratch_live_bytes_end : Nat
  io_scratch_wipe_count : Nat
  resource_events : List ImportedRuntimeKernelResourceEvent
  expected_kernel_steps : Option (List ImportedRuntimeKernelStep)
  public_object_ids : List Nat
  expected_public_object_ids : Option (List Nat)
  kernel_steps : List ImportedRuntimeKernelStep
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeKernelWitness.emittedKernelSchedule
  (witness : ImportedRuntimeKernelWitness) : ImportedRuntimeKernelSchedule :=
  { opcodes := witness.kernel_steps.map ImportedRuntimeKernelStep.opcode
  , steps := witness.kernel_steps
  }

def ImportedRuntimeKernelWitness.expectedKernelSchedule?
  (witness : ImportedRuntimeKernelWitness) : Option ImportedRuntimeKernelSchedule := do
  let steps ← witness.expected_kernel_steps
  some { opcodes := steps.map ImportedRuntimeKernelStep.opcode, steps := steps }

def ImportedRuntimeKernelWitness.toRuntimeKernelWitness
  (witness : ImportedRuntimeKernelWitness) : RuntimeKernelWitness :=
  { entrypointId := witness.entrypoint_id
  , arenaBytes := witness.arena_bytes
  , maxStackWords := witness.max_stack_words
  , scratchBytes := witness.scratch_bytes
  , peakStackWords := witness.peak_stack_words
  , valueScratchPeakBytes := witness.value_scratch_peak_bytes
  , valueScratchLiveBytesEnd := witness.value_scratch_live_bytes_end
  , valueScratchWipeCount := witness.value_scratch_wipe_count
  , hashScratchPeakBytes := witness.hash_scratch_peak_bytes
  , hashScratchLiveBytesEnd := witness.hash_scratch_live_bytes_end
  , hashScratchWipeCount := witness.hash_scratch_wipe_count
  , ioScratchPeakBytes := witness.io_scratch_peak_bytes
  , ioScratchLiveBytesEnd := witness.io_scratch_live_bytes_end
  , ioScratchWipeCount := witness.io_scratch_wipe_count
  , resourceEvents := witness.resource_events.map (fun event =>
      { kind := event.kind
      , region := event.region
      , words := event.words
      , bytes := event.bytes
      })
  , expectedKernelOpcodes := witness.expected_kernel_steps.map
      (List.map ImportedRuntimeKernelStep.opcode)
  , expectedKernelSteps := witness.expected_kernel_steps.map
      (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep)
  , publicObjectIds := witness.public_object_ids
  , expectedPublicObjectIds := witness.expected_public_object_ids
  , kernelOpcodes := witness.kernel_steps.map ImportedRuntimeKernelStep.opcode
  , kernelSteps := witness.kernel_steps.map ImportedRuntimeKernelStep.toRuntimeKernelStep
  }

def ImportedRuntimeKernelWitness.resourceReplayExact
  (witness : ImportedRuntimeKernelWitness) : Prop :=
  witness.toRuntimeKernelWitness.ResourceReplayExact

def ImportedRuntimeKernelWitness.claimedResourceState
  (witness : ImportedRuntimeKernelWitness) : RuntimeKernelResourceState :=
  witness.toRuntimeKernelWitness.claimedResourceState

def ImportedRuntimeKernelWitness.checkResourceReplayExact
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  witness.toRuntimeKernelWitness.checkResourceReplayExact

@[simp] theorem importedRuntimeKernelWitness_checkResourceReplayExact_eq_true_iff
  (witness : ImportedRuntimeKernelWitness) :
  witness.checkResourceReplayExact = true ↔ witness.resourceReplayExact := by
  simp [ImportedRuntimeKernelWitness.checkResourceReplayExact,
    ImportedRuntimeKernelWitness.resourceReplayExact,
    runtimeKernelWitness_checkResourceReplayExact_eq_true_iff]

def ImportedRuntimeKernelWitness.kernelOpcodesAllowed
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  (witness.kernel_steps.map ImportedRuntimeKernelStep.opcode).all
    (fun opcode => decide (opcode ∈ importedRuntimeKernelOpcodeNames))

def ImportedRuntimeKernelWitness.kernelStepsShapeValid
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  witness.kernel_steps.all ImportedRuntimeKernelStep.checkShapeValid

def ImportedRuntimeKernelWitness.projectedKernelOpcodes
  (witness : ImportedRuntimeKernelWitness) : List String :=
  witness.kernel_steps.map ImportedRuntimeKernelStep.opcode

def ImportedRuntimeKernelWitness.kernelStepOpcodesMatch
  (_witness : ImportedRuntimeKernelWitness) : Bool :=
  true

def ImportedRuntimeKernelWitness.HasBeginCommitWipeEnvelope
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  decide (witness.projectedKernelOpcodes.head? = some "Begin") &&
    decide
      (witness.projectedKernelOpcodes.drop (witness.projectedKernelOpcodes.length - 2) =
        ["Commit", "Wipe"])

def importedRuntimeKernelObjectIdScheduleCanonical : List Nat → Bool
  | [] => true
  | [_] => true
  | head :: next :: tail =>
      decide (head < next) && importedRuntimeKernelObjectIdScheduleCanonical (next :: tail)

def ImportedRuntimeKernelWitness.publicObjectIdsShapeValid
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  importedRuntimeKernelObjectIdScheduleCanonical witness.public_object_ids

def ImportedRuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  match witness.expected_public_object_ids with
  | none => true
  | some expectedPublicObjectIds =>
      importedRuntimeKernelObjectIdScheduleCanonical expectedPublicObjectIds &&
        decide (witness.public_object_ids = expectedPublicObjectIds)

def ImportedRuntimeKernelWitness.kernelObjectsInPublicObjectUniverse
  (witness : ImportedRuntimeKernelWitness) : Bool :=
  witness.kernel_steps.filterMap ImportedRuntimeKernelStep.object_id |>.all (fun objectId =>
    decide (objectId ∈ witness.public_object_ids))

def ImportedRuntimeKernelWitness.Valid
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String) : Prop :=
  witness.entrypoint_id = entrypointId ∧
    witness.scratch_bytes = witness.arena_bytes / 4 ∧
    witness.peak_stack_words ≤ witness.max_stack_words ∧
    witness.value_scratch_peak_bytes ≤ witness.scratch_bytes ∧
    witness.hash_scratch_peak_bytes ≤ witness.scratch_bytes ∧
    witness.io_scratch_peak_bytes ≤ witness.scratch_bytes ∧
    witness.value_scratch_live_bytes_end = 0 ∧
    (witness.value_scratch_peak_bytes = 0 ∨ 0 < witness.value_scratch_wipe_count) ∧
    witness.hash_scratch_live_bytes_end = 0 ∧
    (witness.hash_scratch_peak_bytes = 0 ∨ 0 < witness.hash_scratch_wipe_count) ∧
    witness.io_scratch_live_bytes_end = 0 ∧
    (witness.io_scratch_peak_bytes = 0 ∨ 0 < witness.io_scratch_wipe_count) ∧
    witness.resourceReplayExact ∧
    witness.kernelOpcodesAllowed = true ∧
    witness.kernelStepsShapeValid = true ∧
    witness.kernelStepOpcodesMatch = true ∧
    witness.HasBeginCommitWipeEnvelope = true ∧
    witness.emittedKernelSchedule.checkRunsToCompletion = true ∧
    (match witness.expected_kernel_steps with
    | none => True
    | some expectedKernelSteps =>
        witness.projectedKernelOpcodes = expectedKernelSteps.map ImportedRuntimeKernelStep.opcode) ∧
    (match witness.expected_kernel_steps with
    | none => True
    | some expectedKernelSteps => witness.kernel_steps = expectedKernelSteps) ∧
    witness.publicObjectIdsShapeValid = true ∧
    witness.expectedPublicObjectIdsShapeAndMatch = true ∧
    witness.kernelObjectsInPublicObjectUniverse = true

def ImportedRuntimeKernelWitness.checkValid
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String) : Bool :=
  decide (witness.entrypoint_id = entrypointId) &&
    decide (witness.scratch_bytes = witness.arena_bytes / 4) &&
    decide (witness.peak_stack_words ≤ witness.max_stack_words) &&
    decide (witness.value_scratch_peak_bytes ≤ witness.scratch_bytes) &&
    decide (witness.hash_scratch_peak_bytes ≤ witness.scratch_bytes) &&
    decide (witness.io_scratch_peak_bytes ≤ witness.scratch_bytes) &&
    decide (witness.value_scratch_live_bytes_end = 0) &&
    decide
      (witness.value_scratch_peak_bytes = 0 ∨ 0 < witness.value_scratch_wipe_count) &&
    decide (witness.hash_scratch_live_bytes_end = 0) &&
    decide
      (witness.hash_scratch_peak_bytes = 0 ∨ 0 < witness.hash_scratch_wipe_count) &&
    decide (witness.io_scratch_live_bytes_end = 0) &&
    decide
      (witness.io_scratch_peak_bytes = 0 ∨ 0 < witness.io_scratch_wipe_count) &&
    witness.checkResourceReplayExact &&
    witness.kernelOpcodesAllowed &&
    witness.kernelStepsShapeValid &&
    witness.kernelStepOpcodesMatch &&
    witness.HasBeginCommitWipeEnvelope &&
    witness.emittedKernelSchedule.checkRunsToCompletion &&
    (match witness.expected_kernel_steps with
    | none => true
    | some expectedKernelSteps =>
        decide
          (witness.projectedKernelOpcodes =
            expectedKernelSteps.map ImportedRuntimeKernelStep.opcode)) &&
    (match witness.expected_kernel_steps with
    | none => true
    | some expectedKernelSteps => decide (witness.kernel_steps = expectedKernelSteps)) &&
    witness.publicObjectIdsShapeValid &&
    witness.expectedPublicObjectIdsShapeAndMatch &&
    witness.kernelObjectsInPublicObjectUniverse

def ImportedRuntimeKernelWitness.ProofGradeValid
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String) : Prop :=
  witness.Valid entrypointId ∧
    match witness.expected_kernel_steps with
    | none => False
    | some _ =>
        match witness.expected_public_object_ids with
        | none => False
        | some _ => True

def ImportedRuntimeKernelWitness.checkProofGrade
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String) : Bool :=
  witness.checkValid entrypointId &&
    witness.expected_kernel_steps.isSome &&
    witness.expected_public_object_ids.isSome

@[simp] theorem importedRuntimeKernelWitness_checkValid_eq_true_iff
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String) :
  witness.checkValid entrypointId = true ↔ witness.Valid entrypointId := by
  cases hExpectedSteps : witness.expected_kernel_steps <;>
    cases hExpectedPublicObjectIds : witness.expected_public_object_ids <;>
    simp [ImportedRuntimeKernelWitness.checkValid,
      ImportedRuntimeKernelWitness.Valid,
      importedRuntimeKernelWitness_checkResourceReplayExact_eq_true_iff,
      ImportedRuntimeKernelWitness.kernelOpcodesAllowed,
      ImportedRuntimeKernelWitness.kernelStepsShapeValid,
      ImportedRuntimeKernelWitness.projectedKernelOpcodes,
      ImportedRuntimeKernelWitness.kernelStepOpcodesMatch,
      ImportedRuntimeKernelStep.checkShapeValid,
      ImportedRuntimeKernelWitness.HasBeginCommitWipeEnvelope,
      ImportedRuntimeKernelWitness.publicObjectIdsShapeValid,
      ImportedRuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch,
      ImportedRuntimeKernelWitness.kernelObjectsInPublicObjectUniverse,
      hExpectedSteps, hExpectedPublicObjectIds,
      List.all_eq_true, and_assoc]

@[simp] theorem importedRuntimeKernelWitness_checkProofGrade_eq_true_iff
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String) :
  witness.checkProofGrade entrypointId = true ↔ witness.ProofGradeValid entrypointId := by
  cases hExpectedSteps : witness.expected_kernel_steps <;>
    cases hExpectedPublicObjectIds : witness.expected_public_object_ids <;>
    simp [ImportedRuntimeKernelWitness.checkProofGrade,
      ImportedRuntimeKernelWitness.ProofGradeValid,
      hExpectedSteps, hExpectedPublicObjectIds]

@[simp] theorem importedRuntimeKernelStep_toRuntimeKernelStep_opcode
  (step : ImportedRuntimeKernelStep) :
  step.toRuntimeKernelStep.opcode = step.opcode := by
  cases step
  rfl

@[simp] theorem importedRuntimeKernelStep_toRuntimeKernelStep_objectId
  (step : ImportedRuntimeKernelStep) :
  step.toRuntimeKernelStep.objectId = step.object_id := by
  cases step
  rfl

@[simp] theorem importedRuntimeKernelStep_opcode_comp_toRuntimeKernelStep :
  RuntimeKernelStep.opcode ∘ ImportedRuntimeKernelStep.toRuntimeKernelStep =
    ImportedRuntimeKernelStep.opcode := by
  funext step
  cases step
  rfl

@[simp] theorem importedRuntimeKernelStep_checkShapeValid_comp_toRuntimeKernelStep :
  RuntimeKernelStep.checkShapeValid ∘ ImportedRuntimeKernelStep.toRuntimeKernelStep =
    ImportedRuntimeKernelStep.checkShapeValid := by
  funext step
  cases step
  simp [ImportedRuntimeKernelStep.checkShapeValid, RuntimeKernelStep.checkShapeValid,
    importedRuntimeKernelOpcodeRequiresObjectId, runtimeKernelOpcodeRequiresObjectId,
    importedRuntimeKernelObjectOpcodeNames, runtimeKernelObjectOpcodeNames]

theorem importedRuntimeKernelStep_toRuntimeKernelStep_injective :
  Function.Injective ImportedRuntimeKernelStep.toRuntimeKernelStep := by
  intro step₁ step₂ hEq
  cases step₁
  cases step₂
  cases hEq
  rfl

@[simp] theorem importedRuntimeKernelStep_list_map_toRuntimeKernelStep_eq_iff
  (lhs rhs : List ImportedRuntimeKernelStep) :
  lhs.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      rhs.map ImportedRuntimeKernelStep.toRuntimeKernelStep ↔
    lhs = rhs := by
  simpa using
    (List.map_inj_right
      (f := ImportedRuntimeKernelStep.toRuntimeKernelStep)
      (l := lhs)
      (l' := rhs)
      (w := fun _ _ hEq => importedRuntimeKernelStep_toRuntimeKernelStep_injective hEq))

@[simp] theorem importedRuntimeKernelExpectedSteps_check_eq_toRuntime
  (expected : Option (List ImportedRuntimeKernelStep))
  (actual : List ImportedRuntimeKernelStep) :
  (match expected with
    | none => true
    | some expectedSteps => decide (actual = expectedSteps)) =
    (match expected.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep) with
    | none => true
    | some expectedSteps =>
        decide (actual.map ImportedRuntimeKernelStep.toRuntimeKernelStep = expectedSteps)) := by
  cases expected with
  | none => rfl
  | some expectedSteps =>
      simp

@[simp] theorem importedRuntimeKernelObjectIdScheduleCanonical_eq_runtime
  (objectIds : List Nat) :
  importedRuntimeKernelObjectIdScheduleCanonical objectIds =
    runtimeKernelObjectIdScheduleCanonical objectIds := by
  induction objectIds with
  | nil =>
      rfl
  | cons head tail ih =>
      cases tail with
      | nil =>
          rfl
      | cons next tail =>
          simp [importedRuntimeKernelObjectIdScheduleCanonical,
            runtimeKernelObjectIdScheduleCanonical, ih]

theorem importedRuntimeKernelWitness_toRuntimeKernelWitness_valid
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String)
  (hValid : witness.Valid entrypointId) :
  witness.toRuntimeKernelWitness.ValidForEntrypoint entrypointId := by
  cases hExpectedSteps : witness.expected_kernel_steps <;>
    cases hExpectedPublicObjectIds : witness.expected_public_object_ids <;>
  simpa [ImportedRuntimeKernelWitness.Valid,
      RuntimeKernelWitness.ValidForEntrypoint,
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness,
      ImportedRuntimeKernelWitness.resourceReplayExact,
      RuntimeKernelWitness.ResourceReplayExact,
      ImportedRuntimeKernelWitness.emittedKernelSchedule,
      RuntimeKernelWitness.emittedKernelSchedule,
      ImportedRuntimeKernelWitness.kernelOpcodesAllowed,
      RuntimeKernelWitness.kernelOpcodesAllowed,
      ImportedRuntimeKernelWitness.kernelStepsShapeValid,
      RuntimeKernelWitness.kernelStepsShapeValid,
      ImportedRuntimeKernelWitness.projectedKernelOpcodes,
      RuntimeKernelWitness.projectedKernelOpcodes,
      ImportedRuntimeKernelWitness.kernelStepOpcodesMatch,
      RuntimeKernelWitness.kernelStepOpcodesMatch,
      ImportedRuntimeKernelWitness.HasBeginCommitWipeEnvelope,
      RuntimeKernelWitness.hasBeginCommitWipeEnvelope,
      ImportedRuntimeKernelWitness.publicObjectIdsShapeValid,
      RuntimeKernelWitness.publicObjectIdsShapeValid,
      ImportedRuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch,
      RuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch,
      ImportedRuntimeKernelWitness.kernelObjectsInPublicObjectUniverse,
      RuntimeKernelWitness.kernelObjectsInPublicObjectUniverse,
      ImportedRuntimeKernelSchedule.toRuntimeKernelSchedule,
      ImportedRuntimeKernelSchedule.checkRunsToCompletion,
      RuntimeKernelSchedule.checkRunsToCompletion,
      RuntimeKernelSchedule.projectedOpcodes,
      importedRuntimeKernelOpcodeNames,
      runtimeKernelOpcodeNames,
      importedRuntimeKernelObjectIdScheduleCanonical_eq_runtime,
      importedRuntimeKernelStep_opcode_comp_toRuntimeKernelStep,
      hExpectedSteps, hExpectedPublicObjectIds] using hValid

theorem importedRuntimeKernelWitness_toRuntimeKernelWitness_proofGradeValid
  (witness : ImportedRuntimeKernelWitness)
  (entrypointId : String)
  (hValid : witness.ProofGradeValid entrypointId) :
  witness.toRuntimeKernelWitness.ProofGradeValid entrypointId := by
  refine ⟨importedRuntimeKernelWitness_toRuntimeKernelWitness_valid
      witness entrypointId hValid.1, ?_⟩
  cases hExpectedSteps : witness.expected_kernel_steps with
  | none =>
      simp [ImportedRuntimeKernelWitness.ProofGradeValid, hExpectedSteps] at hValid
  | some expectedKernelSteps =>
      cases hExpectedPublicObjectIds : witness.expected_public_object_ids with
      | none =>
          simp [ImportedRuntimeKernelWitness.ProofGradeValid, hExpectedSteps,
            hExpectedPublicObjectIds] at hValid
      | some expectedPublicObjectIds =>
          simp [ImportedRuntimeKernelWitness.toRuntimeKernelWitness, hExpectedSteps,
            hExpectedPublicObjectIds]

theorem importedRuntimeKernelWitness_proofGradeKernelSchedule_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSteps,
    witness.expected_kernel_steps = some expectedKernelSteps ∧
      witness.kernel_steps = expectedKernelSteps := by
  rcases hValid with ⟨hValidForEntrypoint, hProofGrade⟩
  cases hExpectedSteps : witness.expected_kernel_steps with
  | none =>
      simp [hExpectedSteps] at hProofGrade
  | some expectedKernelSteps =>
      refine ⟨expectedKernelSteps, rfl, ?_⟩
      rcases hValidForEntrypoint with
        ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hKernelSteps, _, _, _⟩
      simpa [hExpectedSteps] using hKernelSteps

theorem importedRuntimeKernelWitness_proofGradeKernelScheduleObject_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      witness.emittedKernelSchedule = expectedKernelSchedule := by
  rcases importedRuntimeKernelWitness_proofGradeKernelSchedule_exact hValid with
    ⟨expectedKernelSteps, hExpectedSteps, hKernelSteps⟩
  refine
    ⟨{ opcodes := expectedKernelSteps.map ImportedRuntimeKernelStep.opcode
     , steps := expectedKernelSteps
     }, ?_, ?_⟩
  · simp [ImportedRuntimeKernelWitness.expectedKernelSchedule?, hExpectedSteps]
  · simp [ImportedRuntimeKernelWitness.emittedKernelSchedule, hKernelSteps]

theorem importedRuntimeKernelWitness_proofGradePublicObjectUniverse_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedPublicObjectIds,
    witness.expected_public_object_ids = some expectedPublicObjectIds ∧
      witness.public_object_ids = expectedPublicObjectIds := by
  rcases hValid with ⟨hValidForEntrypoint, hProofGrade⟩
  cases hExpectedPublicObjectIds : witness.expected_public_object_ids with
  | none =>
      cases hExpectedSteps : witness.expected_kernel_steps <;>
        simp [hExpectedSteps, hExpectedPublicObjectIds] at hProofGrade
  | some expectedPublicObjectIds =>
      refine ⟨expectedPublicObjectIds, rfl, ?_⟩
      rcases hValidForEntrypoint with
        ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _,
          hPublicObjectIdsMatch, _⟩
      simp [ImportedRuntimeKernelWitness.expectedPublicObjectIdsShapeAndMatch,
        hExpectedPublicObjectIds] at hPublicObjectIdsMatch
      exact hPublicObjectIdsMatch.2

theorem importedRuntimeKernelWitness_emittedKernelSchedule_valid
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.Valid entrypointId) :
  witness.emittedKernelSchedule.Valid := by
  rcases hValid with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, hOpcodesAllowed, hStepsShape, hOpcodeMatch,
      hEnvelope, hCompletion, _, _, _, _, _⟩
  have hAllowedEq :
      witness.emittedKernelSchedule.opcodesAllowed = witness.kernelOpcodesAllowed := by
    simp [ImportedRuntimeKernelSchedule.opcodesAllowed,
      ImportedRuntimeKernelWitness.kernelOpcodesAllowed,
      ImportedRuntimeKernelWitness.emittedKernelSchedule]
  have hCheckShape : witness.emittedKernelSchedule.checkShapeValid = true := by
    have hShapeEq :
        witness.emittedKernelSchedule.checkShapeValid =
          (witness.kernelStepsShapeValid && witness.kernelStepOpcodesMatch) := by
      simp [ImportedRuntimeKernelSchedule.checkShapeValid,
        ImportedRuntimeKernelWitness.emittedKernelSchedule,
        ImportedRuntimeKernelWitness.kernelStepsShapeValid,
        ImportedRuntimeKernelWitness.kernelStepOpcodesMatch,
        ImportedRuntimeKernelSchedule.projectedOpcodes]
    rw [hShapeEq]
    simp [hStepsShape, hOpcodeMatch]
  have hEnvelopeEq :
      witness.emittedKernelSchedule.hasBeginCommitWipeEnvelope =
        witness.HasBeginCommitWipeEnvelope := by
    unfold ImportedRuntimeKernelSchedule.hasBeginCommitWipeEnvelope
      ImportedRuntimeKernelWitness.emittedKernelSchedule
      ImportedRuntimeKernelWitness.HasBeginCommitWipeEnvelope
    rfl
  have hScheduleCheck : witness.emittedKernelSchedule.checkValid = true := by
    rw [ImportedRuntimeKernelSchedule.checkValid, hAllowedEq, hEnvelopeEq]
    simp [hOpcodesAllowed, hCheckShape, hEnvelope, hCompletion]
  exact
    (importedRuntimeKernelSchedule_checkValid_eq_true_iff witness.emittedKernelSchedule).mp
      hScheduleCheck

theorem importedRuntimeKernelWitness_emittedKernelSchedule_completes
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.Valid entrypointId) :
  ∃ finalState, witness.emittedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
    finalState.phase = .finished := by
  rcases importedRuntimeKernelWitness_emittedKernelSchedule_valid hValid with
    ⟨_, _, _, hCompletion⟩
  exact
    (importedRuntimeKernelSchedule_checkRunsToCompletion_eq_true_iff
      witness.emittedKernelSchedule).mp hCompletion

theorem importedRuntimeKernelWitness_valid_replayedResourceState_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.Valid entrypointId) :
  witness.toRuntimeKernelWitness.replayedResourceState? =
    some witness.claimedResourceState := by
  rcases hValid with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, hReplay, _, _, _, _, _, _, _, _, _⟩
  have hReplayExact : witness.toRuntimeKernelWitness.ResourceReplayExact := by
    simpa [ImportedRuntimeKernelWitness.resourceReplayExact] using hReplay
  exact
    (runtimeKernelWitness_resourceReplayExact_eq_claimed witness.toRuntimeKernelWitness).mp
      hReplayExact

theorem importedRuntimeKernelWitness_proofGradeResourceState_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  witness.toRuntimeKernelWitness.replayedResourceState? =
    some witness.claimedResourceState := by
  exact importedRuntimeKernelWitness_valid_replayedResourceState_exact hValid.1

theorem importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_valid
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.Valid := by
  rcases importedRuntimeKernelWitness_proofGradeKernelScheduleObject_exact hValid with
    ⟨expectedKernelSchedule, hExpectedSchedule, hScheduleExact⟩
  refine ⟨expectedKernelSchedule, hExpectedSchedule, ?_⟩
  have hEmittedValid :
      witness.emittedKernelSchedule.Valid :=
    importedRuntimeKernelWitness_emittedKernelSchedule_valid hValid.1
  simpa [hScheduleExact] using hEmittedValid

theorem importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_completes
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule finalState,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  rcases importedRuntimeKernelWitness_proofGradeKernelScheduleObject_exact hValid with
    ⟨expectedKernelSchedule, hExpectedSchedule, hScheduleExact⟩
  rcases importedRuntimeKernelWitness_emittedKernelSchedule_completes hValid.1 with
    ⟨finalState, hFinalState, hFinished⟩
  refine ⟨expectedKernelSchedule, finalState, hExpectedSchedule, ?_, hFinished⟩
  simpa [hScheduleExact] using hFinalState

theorem importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_publicObjects_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule finalState,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.publicObjectSchedule = expectedKernelSchedule.publicObjectSchedule := by
  rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_completes hValid with
    ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, _⟩
  refine ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, ?_⟩
  simpa [ImportedRuntimeKernelSchedule.publicObjectSchedule] using
    runtimeKernelSchedule_finalState_publicObjectSchedule hFinalState

theorem importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact
  {witness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hValid : witness.ProofGradeValid entrypointId) :
  ∃ expectedKernelSchedule,
    witness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_valid hValid with
    ⟨expectedKernelSchedule, hExpectedSchedule, hScheduleValid⟩
  exact ⟨expectedKernelSchedule, hExpectedSchedule,
    importedRuntimeKernelSchedule_valid_finalState_exact hScheduleValid⟩

def parseImportedRuntimeKernelWitness
  (input : String) : Except String ImportedRuntimeKernelWitness := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeKernelWitness
  (input : String)
  (entrypointId : String) : Except String ImportedRuntimeKernelWitness := do
  let witness ← parseImportedRuntimeKernelWitness input
  if witness.checkValid entrypointId then
    pure witness
  else
    throw "imported runtime kernel witness does not satisfy Lean validity checks"

def parseAndCheckImportedProofGradeRuntimeKernelWitness
  (input : String)
  (entrypointId : String) : Except String ImportedRuntimeKernelWitness := do
  let witness ← parseImportedRuntimeKernelWitness input
  if witness.checkProofGrade entrypointId then
    pure witness
  else
    throw "imported proof-grade runtime kernel witness does not satisfy Lean validity checks"

def loadImportedRuntimeKernelWitness
  (path : System.FilePath) : IO ImportedRuntimeKernelWitness := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelWitness input with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime kernel witness: {err}"

def loadAndCheckImportedRuntimeKernelWitness
  (path : System.FilePath)
  (entrypointId : String) : IO ImportedRuntimeKernelWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeKernelWitness input entrypointId with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError s!"failed to validate runtime kernel witness: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelWitness
  (path : System.FilePath)
  (entrypointId : String) : IO ImportedRuntimeKernelWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelWitness input entrypointId with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel witness: {err}"

structure ImportedRuntimeKernelRefinementEvent where
  kind : String
  object_id : Option Nat
  opcode : Option String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeKernelRefinementEvent.toRuntimeKernelRefinementEvent
  (event : ImportedRuntimeKernelRefinementEvent) : RuntimeKernelRefinementEvent :=
  { kind := event.kind
  , objectId := event.object_id
  , opcode := event.opcode
  }

structure ImportedRuntimeKernelRefinementWitness where
  events : List ImportedRuntimeKernelRefinementEvent
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness
  (witness : ImportedRuntimeKernelRefinementWitness) : RuntimeKernelRefinementWitness :=
  { events := witness.events.map
      ImportedRuntimeKernelRefinementEvent.toRuntimeKernelRefinementEvent
  }

def ImportedRuntimeKernelRefinementWitness.Valid
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness) : Prop :=
  witness.toRuntimeKernelRefinementWitness.Valid kernelWitness.toRuntimeKernelWitness

def ImportedRuntimeKernelRefinementWitness.checkValid
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness) : Bool :=
  witness.toRuntimeKernelRefinementWitness.checkValid kernelWitness.toRuntimeKernelWitness

def ImportedRuntimeKernelRefinementWitness.ProofGradeValid
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness)
  (entrypointId : String) : Prop :=
  kernelWitness.ProofGradeValid entrypointId ∧ witness.Valid kernelWitness

def ImportedRuntimeKernelRefinementWitness.checkProofGrade
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness)
  (entrypointId : String) : Bool :=
  kernelWitness.checkProofGrade entrypointId && witness.checkValid kernelWitness

@[simp] theorem importedRuntimeKernelRefinementWitness_checkValid_eq_true_iff
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness) :
  witness.checkValid kernelWitness = true ↔ witness.Valid kernelWitness := by
  simp [ImportedRuntimeKernelRefinementWitness.checkValid,
    ImportedRuntimeKernelRefinementWitness.Valid,
    runtimeKernelRefinementWitness_checkValid_eq_true_iff]

@[simp] theorem importedRuntimeKernelRefinementWitness_checkProofGrade_eq_true_iff
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness)
  (entrypointId : String) :
  witness.checkProofGrade kernelWitness entrypointId = true ↔
    witness.ProofGradeValid kernelWitness entrypointId := by
  simp [ImportedRuntimeKernelRefinementWitness.checkProofGrade,
    ImportedRuntimeKernelRefinementWitness.ProofGradeValid,
    importedRuntimeKernelWitness_checkProofGrade_eq_true_iff,
    importedRuntimeKernelRefinementWitness_checkValid_eq_true_iff]

def ImportedRuntimeKernelRefinementWitness.RefinesLeanKernelState
  (witness : ImportedRuntimeKernelRefinementWitness)
  (kernelWitness : ImportedRuntimeKernelWitness) : Prop :=
  witness.toRuntimeKernelRefinementWitness.RefinesLeanKernelState
    kernelWitness.toRuntimeKernelWitness

theorem importedRuntimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
  {witness : ImportedRuntimeKernelRefinementWitness}
  {kernelWitness : ImportedRuntimeKernelWitness}
  {entrypointId : String}
  (hKernel : kernelWitness.ProofGradeValid entrypointId)
  (hRefinement : witness.Valid kernelWitness) :
  witness.RefinesLeanKernelState kernelWitness := by
  have hRuntimeKernel :
      kernelWitness.toRuntimeKernelWitness.ProofGradeValid
        kernelWitness.toRuntimeKernelWitness.entrypointId := by
    exact
      runtimeKernelWitness_proofGradeValid_self
        (importedRuntimeKernelWitness_toRuntimeKernelWitness_proofGradeValid
          kernelWitness entrypointId hKernel)
  have hRuntimeRefinement :
      witness.toRuntimeKernelRefinementWitness.Valid kernelWitness.toRuntimeKernelWitness := by
    simpa [ImportedRuntimeKernelRefinementWitness.Valid] using hRefinement
  exact
    runtimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
      hRuntimeKernel hRuntimeRefinement

def parseImportedRuntimeKernelRefinementWitness
  (input : String) : Except String ImportedRuntimeKernelRefinementWitness := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeKernelRefinementWitness
  (input : String)
  (kernelWitness : ImportedRuntimeKernelWitness) :
  Except String ImportedRuntimeKernelRefinementWitness := do
  let witness ← parseImportedRuntimeKernelRefinementWitness input
  if witness.checkValid kernelWitness then
    pure witness
  else
    throw "imported runtime kernel refinement witness does not satisfy Lean validity checks"

def parseAndCheckImportedProofGradeRuntimeKernelRefinementWitness
  (input : String)
  (kernelWitness : ImportedRuntimeKernelWitness)
  (entrypointId : String) :
  Except String ImportedRuntimeKernelRefinementWitness := do
  let witness ← parseImportedRuntimeKernelRefinementWitness input
  if witness.checkProofGrade kernelWitness entrypointId then
    pure witness
  else
    throw
      "imported proof-grade runtime kernel refinement witness does not satisfy Lean validity checks"

def loadImportedRuntimeKernelRefinementWitness
  (path : System.FilePath) : IO ImportedRuntimeKernelRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelRefinementWitness input with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime kernel refinement witness: {err}"

def loadAndCheckImportedRuntimeKernelRefinementWitness
  (path : System.FilePath)
  (kernelWitness : ImportedRuntimeKernelWitness) :
  IO ImportedRuntimeKernelRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeKernelRefinementWitness input kernelWitness with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime kernel refinement witness: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelRefinementWitness
  (path : System.FilePath)
  (kernelWitness : ImportedRuntimeKernelWitness)
  (entrypointId : String) :
  IO ImportedRuntimeKernelRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelRefinementWitness
      input kernelWitness entrypointId with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel refinement witness: {err}"

structure ImportedRuntimeRefinementWitness where
  trace : ImportedRefinementTrace
  runtime_seed : Option Nat
  public_outcome : ImportedPublicOutcomeTrace
  kernel_witness : Option ImportedRuntimeKernelWitness
  runtime_kernel_refinement_witness : Option ImportedRuntimeKernelRefinementWitness
  boundary_schedule : List ImportedBoundaryEvent
  controller_shape : ImportedSgxControllerShapeTrace
  normalized_micro_trace : ImportedNormalizedMicroTrace
  controller_certificate : ImportedRuntimeControllerCertificate
  oram_objects : List ImportedRuntimeOramObjectCertificate
  oram_leaf_public_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
  oram_leaf_schedule : List ImportedRuntimeOramLeafCertificate
  oram_position_map_before : List ImportedRuntimePathOramPositionMapCertificate
  oram_position_map_after : List ImportedRuntimePathOramPositionMapCertificate
  oram_leaf_state_transitions : List ImportedRuntimePathOramTransitionCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeRefinementWitness.toRuntimeWitness
  (witness : ImportedRuntimeRefinementWitness) : RuntimeRefinementWitness :=
  { trace := witness.trace.toTrace
  , runtimeSeed := witness.runtime_seed
  , publicOutcome := witness.public_outcome.toPublicOutcome
  , kernelWitness := witness.kernel_witness.map
      ImportedRuntimeKernelWitness.toRuntimeKernelWitness
  , runtimeKernelRefinementWitness := witness.runtime_kernel_refinement_witness.map
      ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness
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
  , oramPositionMapBefore := witness.oram_position_map_before.map
      ImportedRuntimePathOramPositionMapCertificate.toRuntimePathOramPositionMapCertificate
  , oramPositionMapAfter := witness.oram_position_map_after.map
      ImportedRuntimePathOramPositionMapCertificate.toRuntimePathOramPositionMapCertificate
  , oramLeafStateTransitions := witness.oram_leaf_state_transitions.map
      ImportedRuntimePathOramTransitionCertificate.toRuntimePathOramTransitionCertificate
  }

def ImportedRuntimeRefinementWitness.maskedOptionShapeValid
  (witness : ImportedRuntimeRefinementWitness) : Bool :=
  witness.oram_position_map_before.all
      ImportedRuntimePathOramPositionMapCertificate.maskedOptionShapeValid &&
    witness.oram_position_map_after.all
      ImportedRuntimePathOramPositionMapCertificate.maskedOptionShapeValid &&
    witness.oram_leaf_state_transitions.all
      ImportedRuntimePathOramTransitionCertificate.maskedOptionShapeValid

def ImportedRuntimeRefinementWitness.kernelWitnessValid
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  match witness.kernel_witness with
  | none => True
  | some kernelWitness => kernelWitness.Valid witness.public_outcome.entrypoint_id

def ImportedRuntimeRefinementWitness.checkKernelWitness
  (witness : ImportedRuntimeRefinementWitness) : Bool :=
  match witness.kernel_witness with
  | none => true
  | some kernelWitness => kernelWitness.checkValid witness.public_outcome.entrypoint_id

def ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  match witness.kernel_witness with
  | none => False
  | some kernelWitness => kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id

def ImportedRuntimeRefinementWitness.checkProofGradeKernelWitness
  (witness : ImportedRuntimeRefinementWitness) : Bool :=
  match witness.kernel_witness with
  | none => false
  | some kernelWitness => kernelWitness.checkProofGrade witness.public_outcome.entrypoint_id

def ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  match witness.runtime_kernel_refinement_witness with
  | none => True
  | some runtimeKernelRefinementWitness =>
      match witness.kernel_witness with
      | none => False
      | some kernelWitness =>
          runtimeKernelRefinementWitness.Valid kernelWitness

def ImportedRuntimeRefinementWitness.checkRuntimeKernelRefinementWitness
  (witness : ImportedRuntimeRefinementWitness) : Bool :=
  match witness.runtime_kernel_refinement_witness with
  | none => true
  | some runtimeKernelRefinementWitness =>
      match witness.kernel_witness with
      | none => false
      | some kernelWitness =>
          runtimeKernelRefinementWitness.checkValid kernelWitness

def ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  match witness.kernel_witness, witness.runtime_kernel_refinement_witness with
  | some kernelWitness, some runtimeKernelRefinementWitness =>
      runtimeKernelRefinementWitness.Valid kernelWitness
  | _, _ =>
      False

def ImportedRuntimeRefinementWitness.checkProofGradeRuntimeKernelRefinementWitness
  (witness : ImportedRuntimeRefinementWitness) : Bool :=
  match witness.kernel_witness, witness.runtime_kernel_refinement_witness with
  | some kernelWitness, some runtimeKernelRefinementWitness =>
      runtimeKernelRefinementWitness.checkValid kernelWitness
  | _, _ =>
      false

def ImportedRuntimeRefinementWitness.Valid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.toRuntimeWitness.Valid modelTags ∧
    witness.kernelWitnessValid ∧
    witness.runtimeKernelRefinementWitnessValid ∧
    witness.maskedOptionShapeValid = true

def ImportedRuntimeRefinementWitness.checkValid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  witness.toRuntimeWitness.checkValid modelTags &&
    witness.checkKernelWitness &&
    witness.checkRuntimeKernelRefinementWitness &&
    witness.maskedOptionShapeValid

def ImportedRuntimeRefinementWitness.ProofGradeValid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Prop :=
  witness.toRuntimeWitness.Valid modelTags ∧
    witness.proofGradeKernelWitnessValid ∧
    witness.proofGradeRuntimeKernelRefinementWitnessValid ∧
    witness.maskedOptionShapeValid = true

def ImportedRuntimeRefinementWitness.checkProofGrade
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Bool :=
  witness.toRuntimeWitness.checkValid modelTags &&
    witness.checkProofGradeKernelWitness &&
    witness.checkProofGradeRuntimeKernelRefinementWitness &&
    witness.maskedOptionShapeValid

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

def parseAndCheckImportedProofGradeRuntimeRefinementWitness
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeRefinementWitness := do
  let witness ← parseImportedRuntimeRefinementWitness input
  if witness.checkProofGrade modelTags then
    pure witness
  else
    throw "imported proof-grade runtime refinement witness does not satisfy Lean validity checks"

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

def loadAndCheckImportedProofGradeRuntimeRefinementWitness
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeRefinementWitness := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeRefinementWitness input modelTags with
  | .ok witness => pure witness
  | .error err =>
      throw <| IO.userError s!"failed to validate proof-grade runtime refinement witness: {err}"

@[simp] theorem importedWitness_checkKernelWitness_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness) :
  witness.checkKernelWitness = true ↔ witness.kernelWitnessValid := by
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.checkKernelWitness,
        ImportedRuntimeRefinementWitness.kernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [ImportedRuntimeRefinementWitness.checkKernelWitness,
        ImportedRuntimeRefinementWitness.kernelWitnessValid, hKernel,
        importedRuntimeKernelWitness_checkValid_eq_true_iff]

@[simp] theorem importedWitness_checkProofGradeKernelWitness_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness) :
  witness.checkProofGradeKernelWitness = true ↔ witness.proofGradeKernelWitnessValid := by
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.checkProofGradeKernelWitness,
        ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel]
  | some kernelWitness =>
      simp [ImportedRuntimeRefinementWitness.checkProofGradeKernelWitness,
        ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel,
        importedRuntimeKernelWitness_checkProofGrade_eq_true_iff]

@[simp] theorem importedWitness_checkRuntimeKernelRefinementWitness_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness) :
  witness.checkRuntimeKernelRefinementWitness = true ↔
    witness.runtimeKernelRefinementWitnessValid := by
  cases hRefinement : witness.runtime_kernel_refinement_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.checkRuntimeKernelRefinementWitness,
        ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid, hRefinement]
  | some runtimeKernelRefinementWitness =>
      cases hKernel : witness.kernel_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.checkRuntimeKernelRefinementWitness,
            ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid,
            hRefinement, hKernel]
      | some kernelWitness =>
          simp [ImportedRuntimeRefinementWitness.checkRuntimeKernelRefinementWitness,
            ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid,
            hRefinement, hKernel,
            importedRuntimeKernelRefinementWitness_checkValid_eq_true_iff]

@[simp] theorem importedWitness_checkProofGradeRuntimeKernelRefinementWitness_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness) :
  witness.checkProofGradeRuntimeKernelRefinementWitness = true ↔
    witness.proofGradeRuntimeKernelRefinementWitnessValid := by
  cases hKernel : witness.kernel_witness <;>
    cases hRefinement : witness.runtime_kernel_refinement_witness <;>
    simp [ImportedRuntimeRefinementWitness.checkProofGradeRuntimeKernelRefinementWitness,
      ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
      hKernel, hRefinement, importedRuntimeKernelRefinementWitness_checkValid_eq_true_iff]

@[simp] theorem importedWitness_valid_iff
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.Valid modelTags ↔
    witness.toRuntimeWitness.Valid modelTags ∧
      witness.kernelWitnessValid ∧
      witness.runtimeKernelRefinementWitnessValid ∧
      witness.maskedOptionShapeValid = true := by
  rfl

@[simp] theorem importedWitness_checkValid_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkValid modelTags = true ↔ witness.Valid modelTags := by
  unfold ImportedRuntimeRefinementWitness.checkValid ImportedRuntimeRefinementWitness.Valid
  simp [runtimeWitness_checkValid_eq_true_iff, importedWitness_checkKernelWitness_eq_true_iff,
    importedWitness_checkRuntimeKernelRefinementWitness_eq_true_iff, and_assoc]

@[simp] theorem importedWitness_checkProofGrade_eq_true_iff
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) :
  witness.checkProofGrade modelTags = true ↔ witness.ProofGradeValid modelTags := by
  unfold ImportedRuntimeRefinementWitness.checkProofGrade
    ImportedRuntimeRefinementWitness.ProofGradeValid
  simp [runtimeWitness_checkValid_eq_true_iff,
    importedWitness_checkProofGradeKernelWitness_eq_true_iff,
    importedWitness_checkProofGradeRuntimeKernelRefinementWitness_eq_true_iff, and_assoc]

theorem importedWitness_proofGradeValid_implies_valid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  witness.Valid modelTags := by
  rcases hValid with ⟨hRuntimeValid, hKernelProofGrade, hRefinementProofGrade, hMaskedShape⟩
  refine ⟨hRuntimeValid, ?_, ?_, hMaskedShape⟩
  · cases hKernel : witness.kernel_witness with
    | none =>
        simp [ImportedRuntimeRefinementWitness.kernelWitnessValid, hKernel]
    | some kernelWitness =>
        have hKernelProof :
            kernelWitness.Valid witness.public_outcome.entrypoint_id ∧
              (match kernelWitness.expected_kernel_steps with
              | none => False
              | some _ =>
                  match kernelWitness.expected_public_object_ids with
                  | none => False
                  | some _ => True) := by
          simpa
            [ ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid
            , ImportedRuntimeKernelWitness.ProofGradeValid
            , hKernel
            ] using hKernelProofGrade
        simpa [ImportedRuntimeRefinementWitness.kernelWitnessValid, hKernel] using hKernelProof.1
  · cases hRefinement : witness.runtime_kernel_refinement_witness with
    | none =>
        simp [ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid, hRefinement]
    | some runtimeKernelRefinementWitness =>
        cases hKernel : witness.kernel_witness with
        | none =>
            simp
              [ ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid
              , hKernel
              , hRefinement
              ] at hRefinementProofGrade
        | some kernelWitness =>
            have hRefinementValid :
                runtimeKernelRefinementWitness.Valid kernelWitness := by
              simpa
                [ ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid
                , ImportedRuntimeKernelRefinementWitness.ProofGradeValid
                , hKernel
                , hRefinement
                ] using hRefinementProofGrade
            simpa
              [ ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid
              , hKernel
              , hRefinement
              ] using hRefinementValid

theorem importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  witness.toRuntimeWitness.ProofGradeValid modelTags := by
  rcases hValid with ⟨hRuntimeValid, hKernelValid, hRefinementValid, _hMaskedShape⟩
  refine ⟨hRuntimeValid, ?_, ?_⟩
  · unfold RuntimeRefinementWitness.proofGradeKernelWitnessValid
      ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid at *
    cases hKernel : witness.kernel_witness with
    | none =>
        simp [hKernel] at hKernelValid
    | some kernelWitness =>
        have hKernelProofGrade :
            kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
          simpa [hKernel] using hKernelValid
        simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness, hKernel] using
          importedRuntimeKernelWitness_toRuntimeKernelWitness_proofGradeValid
            kernelWitness witness.public_outcome.entrypoint_id hKernelProofGrade
  · unfold RuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid
      ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid at *
    cases hKernel : witness.kernel_witness with
    | none =>
        cases hRefinement : witness.runtime_kernel_refinement_witness with
        | none =>
            simp [hKernel, hRefinement] at hRefinementValid
        | some runtimeKernelRefinementWitness =>
            simp [hKernel, hRefinement] at hRefinementValid
    | some kernelWitness =>
        cases hRefinement : witness.runtime_kernel_refinement_witness with
        | none =>
            simp [hKernel, hRefinement] at hRefinementValid
        | some runtimeKernelRefinementWitness =>
            simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness, hKernel, hRefinement,
              ImportedRuntimeKernelRefinementWitness.Valid] using hRefinementValid

theorem importedWitness_proofGradeKernelSchedule_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSteps,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_kernel_steps = some expectedKernelSteps ∧
      kernelWitness.kernel_steps = expectedKernelSteps := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeKernelSchedule_exact hProofGrade with
        ⟨expectedKernelSteps, hExpectedSteps, hKernelSteps⟩
      exact ⟨kernelWitness, expectedKernelSteps, rfl, hExpectedSteps, hKernelSteps⟩

theorem importedWitness_proofGradePublicObjectUniverse_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedPublicObjectIds,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expected_public_object_ids = some expectedPublicObjectIds ∧
      kernelWitness.public_object_ids = expectedPublicObjectIds := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradePublicObjectUniverse_exact hProofGrade with
        ⟨expectedPublicObjectIds, hExpectedPublicObjectIds, hPublicObjectIds⟩
      exact
        ⟨kernelWitness, expectedPublicObjectIds, rfl, hExpectedPublicObjectIds,
          hPublicObjectIds⟩

theorem importedWitness_proofGradeKernelResourceState_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.toRuntimeKernelWitness.replayedResourceState? =
        some kernelWitness.claimedResourceState := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      exact ⟨kernelWitness, rfl,
        importedRuntimeKernelWitness_proofGradeResourceState_exact hProofGrade⟩

theorem importedWitness_proofGradeRuntimeKernelRefinementProjection_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernel_witness = some kernelWitness ∧
      witness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.projectedKernelSchedule =
        kernelWitness.toRuntimeKernelWitness.emittedKernelSchedule := by
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
  | some kernelWitness =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            ImportedRuntimeKernelRefinementWitness.Valid, hKernel, hRefinement,
            RuntimeKernelRefinementWitness.Valid] at hRefinementValid
          exact ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
            hRefinementValid.2.2.1⟩

theorem importedWitness_proofGradeRuntimeKernelRefinementBoundaryExact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernel_witness = some kernelWitness ∧
      witness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.preCommittedColdObjectSchedule =
        kernelWitness.toRuntimeKernelWitness.publicObjectIds ∧
      runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness.postCommittedColdObjectSchedule =
        kernelWitness.toRuntimeKernelWitness.publicObjectIds := by
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
  | some kernelWitness =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            ImportedRuntimeKernelRefinementWitness.Valid, hKernel, hRefinement,
            RuntimeKernelRefinementWitness.Valid] at hRefinementValid
          exact
            ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
              hRefinementValid.2.2.2.1, hRefinementValid.2.2.2.2.1⟩

theorem importedWitness_proofGradeKernelStateRefinement
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness runtimeKernelRefinementWitness,
    witness.kernel_witness = some kernelWitness ∧
      witness.runtime_kernel_refinement_witness = some runtimeKernelRefinementWitness ∧
      runtimeKernelRefinementWitness.RefinesLeanKernelState kernelWitness := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  have hRefinementValid : witness.proofGradeRuntimeKernelRefinementWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
      | some runtimeKernelRefinementWitness =>
          simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      cases hRefinement : witness.runtime_kernel_refinement_witness with
      | none =>
          simp [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
            hKernel, hRefinement] at hRefinementValid
      | some runtimeKernelRefinementWitness =>
          have hProofGrade :
              kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
            simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
              hKernelValid
          have hWitnessValid : runtimeKernelRefinementWitness.Valid kernelWitness := by
            simpa [ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid,
              hKernel, hRefinement] using hRefinementValid
          exact
            ⟨kernelWitness, runtimeKernelRefinementWitness, rfl, rfl,
              importedRuntimeKernelRefinementWitness_refinesLeanKernelState_of_proofGrade
                hProofGrade hWitnessValid⟩

theorem importedWitness_proofGradeKernelScheduleObject_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      kernelWitness.emittedKernelSchedule = expectedKernelSchedule := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeKernelScheduleObject_exact hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hKernelSchedule⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hKernelSchedule⟩

theorem importedWitness_proofGradeKernelScheduleObject_completes
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.phase = .finished := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_completes hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hFinished⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hFinished⟩

theorem importedWitness_proofGradeKernelScheduleObject_publicObjects_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule finalState,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? = some finalState ∧
      finalState.publicObjectSchedule = expectedKernelSchedule.publicObjectSchedule := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_publicObjects_exact
          hProofGrade with
        ⟨expectedKernelSchedule, finalState, hExpectedSchedule, hFinalState, hObjects⟩
      exact ⟨kernelWitness, expectedKernelSchedule, finalState, rfl, hExpectedSchedule,
        hFinalState, hObjects⟩

theorem importedWitness_proofGradeKernelScheduleObject_finalState_exact
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags)
  (hValid : witness.ProofGradeValid modelTags) :
  ∃ kernelWitness expectedKernelSchedule,
    witness.kernel_witness = some kernelWitness ∧
      kernelWitness.expectedKernelSchedule? = some expectedKernelSchedule ∧
      expectedKernelSchedule.toRuntimeKernelSchedule.finalState? =
        some
          { phase := .finished
          , publicObjectSchedule := expectedKernelSchedule.publicObjectSchedule
          } := by
  have hKernelValid : witness.proofGradeKernelWitnessValid := by
    unfold ImportedRuntimeRefinementWitness.ProofGradeValid at hValid
    exact hValid.2.1
  cases hKernel : witness.kernel_witness with
  | none =>
      simp [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] at hKernelValid
  | some kernelWitness =>
      have hProofGrade :
          kernelWitness.ProofGradeValid witness.public_outcome.entrypoint_id := by
        simpa [ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid, hKernel] using
          hKernelValid
      rcases importedRuntimeKernelWitness_proofGradeExpectedKernelSchedule_finalState_exact
          hProofGrade with
        ⟨expectedKernelSchedule, hExpectedSchedule, hFinalExact⟩
      exact ⟨kernelWitness, expectedKernelSchedule, rfl, hExpectedSchedule, hFinalExact⟩

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
  exact runtimeWitness_projects_to_paper_observer witness.toRuntimeWitness modelTags hValid.1

def parseImportedRuntimePathOramHiddenCertificate
  (input : String) : Except String ImportedRuntimePathOramHiddenCertificate := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimePathOramHiddenCertificate
  (input : String) : Except String ImportedRuntimePathOramHiddenCertificate := do
  let certificate ← parseImportedRuntimePathOramHiddenCertificate input
  if certificate.checkValid then
    pure certificate
  else
    throw "imported runtime path-ORAM hidden certificate does not satisfy Lean validity checks"

def loadImportedRuntimePathOramHiddenCertificate
  (path : System.FilePath) : IO ImportedRuntimePathOramHiddenCertificate := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimePathOramHiddenCertificate input with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime path-ORAM hidden certificate: {err}"

def loadAndCheckImportedRuntimePathOramHiddenCertificate
  (path : System.FilePath) : IO ImportedRuntimePathOramHiddenCertificate := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimePathOramHiddenCertificate input with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime path-ORAM hidden certificate: {err}"

def parseImportedRuntimeControllerObserverCertificate
  (input : String) : Except String ImportedRuntimeControllerObserverCertificate := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeControllerObserverCertificate
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeControllerObserverCertificate := do
  let certificate ← parseImportedRuntimeControllerObserverCertificate input
  if certificate.checkValid modelTags then
    pure certificate
  else
    throw "imported runtime controller observer certificate does not satisfy Lean validity checks"

def loadImportedRuntimeControllerObserverCertificate
  (path : System.FilePath) : IO ImportedRuntimeControllerObserverCertificate := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeControllerObserverCertificate input with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime controller observer certificate: {err}"

def loadAndCheckImportedRuntimeControllerObserverCertificate
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeControllerObserverCertificate := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeControllerObserverCertificate input modelTags with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime controller observer certificate: {err}"

@[simp] theorem importedRuntimeControllerObserverCertificate_valid_iff
  (certificate : ImportedRuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) :
  certificate.Valid modelTags ↔
    certificate.toRuntimeControllerObserverCertificate.Valid modelTags := by
  rfl

@[simp] theorem importedRuntimeControllerObserverCertificate_checkValid_eq_true_iff
  (certificate : ImportedRuntimeControllerObserverCertificate)
  (modelTags : SGXModelTags) :
  certificate.checkValid modelTags = true ↔ certificate.Valid modelTags := by
  unfold ImportedRuntimeControllerObserverCertificate.checkValid
    ImportedRuntimeControllerObserverCertificate.Valid
  exact runtimeControllerObserverCertificate_checkValid_eq_true_iff
    certificate.toRuntimeControllerObserverCertificate
    modelTags

@[simp] theorem importedRuntimePathOramHiddenCertificate_valid_iff
  (certificate : ImportedRuntimePathOramHiddenCertificate) :
  certificate.Valid ↔
    certificate.toRuntimePathOramHiddenCertificate.Valid ∧
      certificate.maskedOptionShapeValid = true := by
  rfl

@[simp] theorem importedRuntimePathOramHiddenCertificate_checkValid_eq_true_iff
  (certificate : ImportedRuntimePathOramHiddenCertificate) :
  certificate.checkValid = true ↔ certificate.Valid := by
  unfold ImportedRuntimePathOramHiddenCertificate.checkValid
    ImportedRuntimePathOramHiddenCertificate.Valid
  simp [runtimePathOramHiddenCertificate_checkValid_eq_true_iff]

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
  , kernel_witness := none
  , runtime_kernel_refinement_witness := none
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
  , oram_position_map_before := []
  , oram_position_map_after := []
  , oram_leaf_state_transitions := []
  }

def sampleImportedRuntimeControllerObserverCertificate :
  ImportedRuntimeControllerObserverCertificate :=
  { public_outcome := sampleImportedRuntimeRefinementWitness.public_outcome
  , boundary_schedule := sampleImportedRuntimeRefinementWitness.boundary_schedule
  , controller_shape := sampleImportedRuntimeRefinementWitness.controller_shape
  , normalized_micro_trace := sampleImportedRuntimeRefinementWitness.normalized_micro_trace
  , controller_certificate := sampleImportedRuntimeRefinementWitness.controller_certificate
  }

def sampleImportedRuntimePathOramHiddenCertificate :
  ImportedRuntimePathOramHiddenCertificate :=
  { trace := sampleImportedRuntimeRefinementWitness.trace
  , oram_objects := sampleImportedRuntimeRefinementWitness.oram_objects
  , oram_leaf_public_scaffold := sampleImportedRuntimeRefinementWitness.oram_leaf_public_scaffold
  , oram_leaf_schedule := sampleImportedRuntimeRefinementWitness.oram_leaf_schedule
  , oram_position_map_before := sampleImportedRuntimeRefinementWitness.oram_position_map_before
  , oram_position_map_after := sampleImportedRuntimeRefinementWitness.oram_position_map_after
  , oram_leaf_state_transitions := sampleImportedRuntimeRefinementWitness.oram_leaf_state_transitions
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

def sampleImportedRuntimeControllerObserverCertificateRoundtrip : Bool :=
  match
      parseImportedRuntimeControllerObserverCertificate
        (Json.compress (toJson sampleImportedRuntimeControllerObserverCertificate))
    with
    | .ok certificate => decide (certificate = sampleImportedRuntimeControllerObserverCertificate)
    | .error _ => false

example : sampleImportedRuntimeControllerObserverCertificateRoundtrip = true := by
  native_decide

def sampleImportedRuntimePathOramHiddenCertificateRoundtrip : Bool :=
  match
      parseImportedRuntimePathOramHiddenCertificate
        (Json.compress (toJson sampleImportedRuntimePathOramHiddenCertificate))
    with
    | .ok certificate => decide (certificate = sampleImportedRuntimePathOramHiddenCertificate)
    | .error _ => false

example : sampleImportedRuntimePathOramHiddenCertificateRoundtrip = true := by
  native_decide

end UOToolchain
