use crate::confidential_kernel::{
    ConfidentialKernelLoweringError, ConfidentialKernelSlotProgram, ConfidentialKernelStep,
};
use crate::ir::StateObject;
use crate::manifest::{
    EntrypointManifest, RuntimeKernelStepManifest, PATH_ORAM_SCHEME, SURROGATE_ORAM_SCHEME,
};
use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::hash::{Hash, Hasher};
use uo_precompiles::UoOpcode;

#[cfg(test)]
use crate::confidential_kernel::lower_confidential_kernel_expr;
#[cfg(test)]
use crate::ir::Expr;

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum WriteClass {
    Set,
    Clear,
    Same,
    Update,
}

impl WriteClass {
    pub fn as_refinement_label(self) -> &'static str {
        match self {
            Self::Set => "Set",
            Self::Clear => "Clear",
            Self::Same => "Same",
            Self::Update => "Update",
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PhysicalWriteEvent {
    pub object: String,
    pub location: String,
    pub len: usize,
    pub class: WriteClass,
}

impl PhysicalWriteEvent {
    pub fn from_buffers(
        object: impl Into<String>,
        location: impl Into<String>,
        old: &[u8],
        new: &[u8],
    ) -> Self {
        Self {
            object: object.into(),
            location: location.into(),
            len: new.len(),
            class: classify_write(old, new),
        }
    }

    pub fn from_shape(
        object: impl Into<String>,
        location: impl Into<String>,
        len: usize,
        class: WriteClass,
    ) -> Self {
        Self {
            object: object.into(),
            location: location.into(),
            len,
            class,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PhysicalReadEvent {
    pub object: String,
    pub location: String,
    pub len: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct LogicalEvent {
    pub kind: String,
    pub object: String,
    pub detail: String,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum BoundaryDirection {
    Enter,
    Exit,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct BoundaryEvent {
    pub direction: BoundaryDirection,
    pub api_id: String,
    pub input_len: usize,
    pub output_len: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Default)]
pub struct OutputShape {
    pub return_present: bool,
    pub return_length: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct PublicOutcomeTrace {
    pub entrypoint_id: String,
    pub public_args: Vec<String>,
    pub termination_status: bool,
    pub output_shape: OutputShape,
    pub gas_used: u64,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ControllerPhase {
    EnclaveEnter,
    StageRequest,
    DescendPositionMap,
    LoadMetadata,
    FetchPath,
    ScanStash,
    RewritePath,
    AscendPositionMap,
    SealPersistentState,
    EnclaveExit,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct ControllerPageBudget {
    pub page_kind: String,
    pub event_budget: usize,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum PageEventKind {
    FaultIn,
    EvictOut,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ExitEvent {
    InterruptExit,
    Resume,
    Terminate,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct SgxControllerShapeTrace {
    pub boundary_event_budget: usize,
    pub controller_phase_order: Vec<ControllerPhase>,
    pub page_trace_regions: Vec<ControllerPageBudget>,
    pub workset_regions: Vec<ControllerPageBudget>,
    pub exit_trace_budget: usize,
    pub shared_resource_budget: usize,
    pub recursive_position_map_depth: usize,
    pub stash_bound: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct NormalizedPageEvent {
    pub page_kind: String,
    pub kind: PageEventKind,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Default)]
pub struct NormalizedMicroTrace {
    pub page_trace: Vec<NormalizedPageEvent>,
    pub exit_pattern: Vec<ExitEvent>,
    pub shared_resource_pattern: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeOramAccessWitness {
    pub object_id: u32,
    pub scheme: String,
    pub metadata_pages_per_access: usize,
    pub buckets_per_access: usize,
    pub recursion_depth: usize,
    pub stash_bound: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeOramLeafWitness {
    pub object_id: u32,
    pub object_name: String,
    pub bucket_count: usize,
    pub leaf: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeOramLeafScaffoldWitness {
    pub object_id: u32,
    pub object_name: String,
    pub bucket_count: usize,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum RuntimePathOramTransitionKind {
    ReadMiss,
    ReadHit,
    WriteNoop,
    WriteInsert,
    WriteUpdate,
    WriteDelete,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimePathOramTransitionWitness {
    pub object_id: u32,
    pub object_name: String,
    pub bucket_count: usize,
    pub kind: RuntimePathOramTransitionKind,
    pub slot_index: Option<usize>,
    pub prior_leaf: Option<usize>,
    pub next_leaf: Option<usize>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimePathOramPositionMapWitness {
    pub object_id: u32,
    pub object_name: String,
    pub leaves: Vec<Option<usize>>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeOramAccessCounterWitness {
    pub object_id: u32,
    pub object_name: String,
    pub access_counter: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeOramObjectWitness {
    pub object_id: u32,
    pub object_name: String,
    pub scheme: String,
    pub capacity: usize,
    pub block_size: usize,
    pub bucket_size: usize,
    pub bucket_count: usize,
    pub blocks_per_bucket: usize,
    pub tree_height: usize,
    pub stash_bound: usize,
    pub recursion_depth: usize,
    pub metadata_pages: usize,
    pub metadata_pages_per_access: usize,
    pub buckets_per_access: usize,
    pub accesses_per_call: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelStepWitness {
    opcode: UoOpcode,
    #[serde(default)]
    object_id: Option<u32>,
}

impl ConfidentialKernelSlotProgram {
    pub fn expected_runtime_step_witnesses(&self) -> Vec<RuntimeKernelStepWitness> {
        self.expected_runtime_steps()
            .into_iter()
            .map(RuntimeKernelStepWitness::from)
            .collect()
    }
}

impl EntrypointManifest {
    pub fn stored_kernel_step_witnesses(&self) -> Vec<RuntimeKernelStepWitness> {
        manifest_kernel_steps_as_witness(&self.kernel_steps)
    }

    pub fn kernel_step_witnesses(&self) -> Vec<RuntimeKernelStepWitness> {
        manifest_kernel_steps_as_witness(&self.canonical_kernel_step_manifest())
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum RuntimeKernelResourceEventKindWitness {
    StackCheck,
    ReserveScratch,
    WipeScratch,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum RuntimeKernelScratchRegionWitness {
    ValueScratch,
    HashScratch,
    IoScratch,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelResourceEventWitness {
    kind: RuntimeKernelResourceEventKindWitness,
    #[serde(default)]
    region: Option<RuntimeKernelScratchRegionWitness>,
    #[serde(default)]
    words: Option<usize>,
    #[serde(default)]
    bytes: Option<usize>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelScheduleWitness {
    #[serde(default)]
    opcodes: Vec<UoOpcode>,
    #[serde(default)]
    steps: Vec<RuntimeKernelStepWitness>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct RuntimeKernelScheduleTracker {
    expected_kernel_steps: Option<Vec<RuntimeKernelStepWitness>>,
    expected_kernel_step_index: usize,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RuntimeKernelExecutionTracker {
    expected_kernel_schedule: RuntimeKernelScheduleTracker,
    emitted_kernel_steps: Vec<RuntimeKernelStepWitness>,
    max_kernel_ops: usize,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RuntimeKernelRefinementTracker {
    events: Vec<RuntimeKernelRefinementEventWitness>,
    max_event_count: usize,
    phase: RuntimeKernelRefinementPhase,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum RuntimeKernelRefinementEventKindWitness {
    PreCommittedColdObject,
    ShadowLoadObject,
    KernelStep,
    CommitObject,
    ColdStoreObject,
    PostCommittedColdObject,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelRefinementEventWitness {
    kind: RuntimeKernelRefinementEventKindWitness,
    #[serde(default)]
    object_id: Option<u32>,
    #[serde(default)]
    opcode: Option<UoOpcode>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct RuntimeKernelRefinementWitness {
    #[serde(default)]
    events: Vec<RuntimeKernelRefinementEventWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct RuntimeControllerCertificate {
    entry_input_len: usize,
    observed_oram_accesses: Vec<RuntimeOramAccessWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeControllerObserverCertificate {
    public_outcome: PublicOutcomeTrace,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_shape: SgxControllerShapeTrace,
    normalized_micro_trace: NormalizedMicroTrace,
    controller_certificate: RuntimeControllerCertificate,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimePathOramHiddenCertificate {
    trace: RefinementTrace,
    oram_objects: Vec<RuntimeOramObjectWitness>,
    #[serde(default)]
    oram_leaf_public_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    #[serde(default)]
    oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
    #[serde(default)]
    oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
    #[serde(default)]
    oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
    #[serde(default)]
    oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Default)]
pub struct TheoremTrace {
    #[serde(default)]
    pub public_outcome: Option<PublicOutcomeTrace>,
    #[serde(default)]
    pub boundary_schedule: Vec<BoundaryEvent>,
    #[serde(default)]
    pub controller_shape: Option<SgxControllerShapeTrace>,
    #[serde(default)]
    pub normalized_micro_trace: Option<NormalizedMicroTrace>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RefinementPhysicalWrite {
    pub object: String,
    pub location: String,
    pub write_class: String,
    pub len: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct RefinementTrace {
    pub opcode_trace: Vec<String>,
    pub logical_accesses: Vec<LogicalEvent>,
    pub logical_writes: Vec<LogicalEvent>,
    pub physical_reads: Vec<PhysicalReadEvent>,
    pub physical_writes: Vec<RefinementPhysicalWrite>,
    pub gas_used: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeRefinementWitness {
    trace: RefinementTrace,
    runtime_seed: Option<u64>,
    public_outcome: PublicOutcomeTrace,
    #[serde(default)]
    kernel_witness: Option<RuntimeKernelWitness>,
    #[serde(default)]
    runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_shape: SgxControllerShapeTrace,
    normalized_micro_trace: NormalizedMicroTrace,
    controller_certificate: RuntimeControllerCertificate,
    oram_objects: Vec<RuntimeOramObjectWitness>,
    #[serde(default)]
    oram_leaf_public_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    #[serde(default)]
    oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
    #[serde(default)]
    oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
    #[serde(default)]
    oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
    #[serde(default)]
    oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeTrustedKernelBundle {
    runtime_seed: Option<u64>,
    controller_observer: RuntimeControllerObserverCertificate,
    #[serde(default)]
    kernel_witness: Option<RuntimeKernelWitness>,
    hidden_certificate: RuntimePathOramHiddenCertificate,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeKernelWitness {
    entrypoint_id: String,
    arena_bytes: usize,
    max_stack_words: usize,
    scratch_bytes: usize,
    peak_stack_words: usize,
    value_scratch_peak_bytes: usize,
    value_scratch_live_bytes_end: usize,
    value_scratch_wipe_count: usize,
    hash_scratch_peak_bytes: usize,
    hash_scratch_live_bytes_end: usize,
    hash_scratch_wipe_count: usize,
    io_scratch_peak_bytes: usize,
    io_scratch_live_bytes_end: usize,
    io_scratch_wipe_count: usize,
    #[serde(default)]
    resource_events: Vec<RuntimeKernelResourceEventWitness>,
    #[serde(default)]
    expected_kernel_steps: Option<Vec<RuntimeKernelStepWitness>>,
    #[serde(default)]
    public_object_ids: Vec<u32>,
    #[serde(default)]
    expected_public_object_ids: Option<Vec<u32>>,
    #[serde(default)]
    kernel_steps: Vec<RuntimeKernelStepWitness>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RuntimeKernelTelemetrySnapshot {
    arena_bytes: usize,
    max_stack_words: usize,
    scratch_bytes: usize,
    peak_stack_words: usize,
    value_scratch_peak_bytes: usize,
    value_scratch_live_bytes_end: usize,
    value_scratch_wipe_count: usize,
    hash_scratch_peak_bytes: usize,
    hash_scratch_live_bytes_end: usize,
    hash_scratch_wipe_count: usize,
    io_scratch_peak_bytes: usize,
    io_scratch_live_bytes_end: usize,
    io_scratch_wipe_count: usize,
    resource_events: Vec<RuntimeKernelResourceEventWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SeededRuntimeWitnessFamily {
    seed_count: usize,
    witnesses: Vec<RuntimeRefinementWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SeededRuntimePathOramWitnessFamily {
    seed_count: usize,
    witnesses: Vec<RuntimeRefinementWitness>,
    #[serde(default)]
    public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SeededRuntimePaperMainFamilyBundle {
    family: SeededRuntimePathOramWitnessFamily,
    public_outcome: PublicOutcomeTrace,
    #[serde(default)]
    boundary_schedule: Vec<BoundaryEvent>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SeededRuntimePaperMainSlotFamilyBundle {
    family: SeededRuntimePathOramWitnessFamily,
    public_outcome: PublicOutcomeTrace,
    #[serde(default)]
    boundary_schedule: Vec<BoundaryEvent>,
    confidential_slot_program: ConfidentialKernelSlotProgram,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CanonicalFreshCoinRuntimePathOramWitnessFamily {
    seed_count: usize,
    witnesses: Vec<RuntimeRefinementWitness>,
    #[serde(default)]
    public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    #[serde(default)]
    public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CanonicalFreshCoinRuntimePathOramTheoremInput {
    seed_count: usize,
    representative_seed: usize,
    representative_witness: RuntimeRefinementWitness,
    #[serde(default)]
    public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    #[serde(default)]
    public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RefinementWitnessError {
    MissingPublicOutcome,
    MissingControllerShape,
    MissingNormalizedMicroTrace,
    MissingControllerCertificate,
    ControllerObserverTraceMismatch,
    HiddenCertificateTraceMismatch,
    TrustedKernelBundleTraceMismatch,
    KernelWitnessTraceMismatch,
    KernelWitness(KernelWitnessError),
    RuntimeKernelRefinement(RuntimeKernelRefinementWitnessError),
    UnknownOramLogicalObject {
        object: String,
    },
    UnsupportedOramScheme {
        scheme: String,
    },
    MalformedOramLogicalTrace {
        object: String,
        expected_kind: String,
        detail_prefix: String,
    },
    OramAccessScheduleMismatch,
    GasMismatch {
        trace_gas: u64,
        public_outcome_gas: u64,
    },
    BoundaryBudgetMismatch {
        boundary_events: usize,
        boundary_budget: usize,
    },
    BoundaryScheduleMismatch,
    ControllerShapeMismatch,
    NormalizedMicroTraceMismatch,
    OramLeafScheduleMismatch,
    OramLeafStateMismatch,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimeKernelRefinementWitnessError {
    MissingKernelWitness,
    MalformedRuntimePhaseTrace {
        witnessed: Vec<RuntimeKernelRefinementEventWitness>,
    },
    KernelProjectionMismatch {
        expected: Vec<RuntimeKernelStepWitness>,
        witnessed: Vec<RuntimeKernelStepWitness>,
    },
    ObjectScheduleMismatch {
        loaded: Vec<u32>,
        committed: Vec<u32>,
        cold_stored: Vec<u32>,
    },
    PreCommittedColdObjectScheduleMismatch {
        expected: Vec<u32>,
        witnessed: Vec<u32>,
    },
    PostCommittedColdObjectScheduleMismatch {
        expected: Vec<u32>,
        witnessed: Vec<u32>,
    },
    CanonicalObjectScheduleMismatch {
        expected: Vec<u32>,
        witnessed: Vec<u32>,
    },
    KernelObjectCoverageMismatch {
        kernel_objects: Vec<u32>,
        loaded_objects: Vec<u32>,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimeKernelRefinementTrackerError {
    EventCapacityOverflow {
        public_object_count: usize,
        max_kernel_ops: usize,
    },
    EventCapacityExceeded {
        attempted_events: usize,
        max_events: usize,
    },
    UnexpectedPhaseEvent {
        phase: RuntimeKernelRefinementPhase,
        event: RuntimeKernelRefinementEventWitness,
    },
    PhaseMismatch {
        action: &'static str,
        observed: RuntimeKernelRefinementPhase,
        expected: RuntimeKernelRefinementPhase,
    },
    Witness(RuntimeKernelRefinementWitnessError),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KernelWitnessError {
    MissingKernelWitness,
    UnknownEntrypoint {
        entrypoint: String,
    },
    MissingManifestEntrypoint {
        entrypoint: String,
    },
    EntrypointNotConfidential {
        entrypoint: String,
    },
    EntrypointMismatch {
        expected: String,
        witnessed: String,
    },
    ArenaBudgetMismatch {
        witnessed: usize,
        expected: usize,
    },
    StackBudgetMismatch {
        witnessed: usize,
        expected: usize,
    },
    ScratchBudgetMismatch {
        witnessed: usize,
        expected: usize,
    },
    MalformedKernelOpcodeEnvelope {
        witnessed: Vec<UoOpcode>,
    },
    MalformedKernelStepTrace {
        witnessed: Vec<RuntimeKernelStepWitness>,
    },
    MalformedKernelResourceTrace {
        witnessed: Vec<RuntimeKernelResourceEventWitness>,
    },
    PeakStackWordsExceeded {
        peak: usize,
        budget: usize,
    },
    ValueScratchPeakExceeded {
        peak: usize,
        budget: usize,
    },
    HashScratchPeakExceeded {
        peak: usize,
        budget: usize,
    },
    IoScratchPeakExceeded {
        peak: usize,
        budget: usize,
    },
    ValueScratchNotWiped {
        live_bytes_end: usize,
        wipe_count: usize,
    },
    HashScratchNotWiped {
        live_bytes_end: usize,
        wipe_count: usize,
    },
    IoScratchNotWiped {
        live_bytes_end: usize,
        wipe_count: usize,
    },
    ConfidentialControlFlow {
        entrypoint: String,
        statement: String,
    },
    SelectContainsKernelAccess {
        entrypoint: String,
    },
    SelectArmOutsideBranchlessFragment {
        entrypoint: String,
    },
    ConfidentialStructField {
        entrypoint: String,
    },
    ConfidentialArrayIndex {
        entrypoint: String,
    },
    MissingExpectedKernelSteps {
        entrypoint: String,
    },
    MissingManifestConfidentialSlotProgram {
        entrypoint: String,
    },
    MissingExpectedPublicObjectIds {
        entrypoint: String,
    },
    ExpectedKernelScheduleEmpty,
    ExpectedKernelScheduleMustBegin {
        witnessed: RuntimeKernelStepWitness,
    },
    ExpectedKernelScheduleExtraStep {
        observed: RuntimeKernelStepWitness,
    },
    ExpectedKernelScheduleStepMismatch {
        index: usize,
        expected: RuntimeKernelStepWitness,
        observed: RuntimeKernelStepWitness,
    },
    ExpectedKernelScheduleIncomplete {
        observed_steps: usize,
        expected_steps: usize,
    },
    KernelStepBudgetExceeded {
        attempted_steps: usize,
        budget: usize,
    },
    MalformedPublicObjectUniverse {
        witnessed: Vec<u32>,
    },
    PublicObjectUniverseMismatch {
        expected: Vec<u32>,
        witnessed: Vec<u32>,
    },
    KernelObjectOutsidePublicUniverse {
        object_id: u32,
        public_object_ids: Vec<u32>,
    },
    KernelOpcodeTraceMismatch {
        expected: Vec<UoOpcode>,
        witnessed: Vec<UoOpcode>,
    },
    KernelStepTraceMismatch {
        expected: Vec<RuntimeKernelStepWitness>,
        witnessed: Vec<RuntimeKernelStepWitness>,
    },
    KernelResourceTraceMismatch {
        field: String,
        expected: usize,
        witnessed: usize,
    },
}

impl From<ConfidentialKernelLoweringError> for KernelWitnessError {
    fn from(err: ConfidentialKernelLoweringError) -> Self {
        match err {
            ConfidentialKernelLoweringError::EntrypointNotConfidential { entrypoint } => {
                Self::EntrypointNotConfidential { entrypoint }
            }
            ConfidentialKernelLoweringError::ConfidentialControlFlow {
                entrypoint,
                statement,
            } => Self::ConfidentialControlFlow {
                entrypoint,
                statement,
            },
            ConfidentialKernelLoweringError::SelectContainsKernelAccess { entrypoint } => {
                Self::SelectContainsKernelAccess { entrypoint }
            }
            ConfidentialKernelLoweringError::SelectArmOutsideBranchlessFragment { entrypoint } => {
                Self::SelectArmOutsideBranchlessFragment { entrypoint }
            }
            ConfidentialKernelLoweringError::ConfidentialStructField { entrypoint } => {
                Self::ConfidentialStructField { entrypoint }
            }
            ConfidentialKernelLoweringError::ConfidentialArrayIndex { entrypoint } => {
                Self::ConfidentialArrayIndex { entrypoint }
            }
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SeededRuntimeWitnessFamilyError {
    SeedCountMismatch {
        seed_count: usize,
        witness_count: usize,
    },
    SeedIndexTooLarge {
        index: usize,
    },
    MissingSeedTag {
        index: usize,
    },
    SeedTagMismatch {
        index: usize,
        tagged_seed: u64,
    },
    PublicLeafScaffoldMismatch {
        index: usize,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SeededRuntimePaperMainFamilyBundleError {
    Family(SeededRuntimeWitnessFamilyError),
    EmptyFamily,
    PublicOutcomeMismatch { index: usize },
    BoundaryScheduleMismatch { index: usize },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SeededRuntimePaperMainSlotFamilyBundleError {
    Family(SeededRuntimePaperMainFamilyBundleError),
    SlotProgramEntrypointMismatch {
        expected_entrypoint: String,
        program_entrypoint: String,
    },
    SlotProgramNotRuntimeNormalForm {
        entrypoint: String,
    },
    MissingKernelWitness {
        index: usize,
    },
    ExpectedKernelStepsMismatch {
        index: usize,
    },
    EmittedKernelStepsMismatch {
        index: usize,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimePaperMainFamilyBundleError {
    RuntimeWitness(RefinementWitnessError),
    Family(SeededRuntimeWitnessFamilyError),
    PaperMain(SeededRuntimePaperMainFamilyBundleError),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimePaperMainSlotFamilyBundleError {
    Family(RuntimePaperMainFamilyBundleError),
    MissingEntrypoint { entrypoint: String },
    MissingConfidentialSlotProgram { entrypoint: String },
    PaperMainSlot(SeededRuntimePaperMainSlotFamilyBundleError),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CanonicalFreshCoinWitnessFamilyError {
    SeedCountMismatch {
        seed_count: usize,
        witness_count: usize,
    },
    CanonicalSeedSpaceOverflow,
    CanonicalSeedCountMismatch {
        seed_count: usize,
        canonical_seed_count: usize,
    },
    PublicLeafScaffoldMismatch {
        index: usize,
    },
    FreshCoinScaffoldExtractionMismatch {
        index: usize,
    },
    FreshCoinScaffoldMismatch {
        index: usize,
    },
    FreshCoinValuesExtractionMismatch {
        index: usize,
    },
    CanonicalFreshCoinValuesMismatch {
        index: usize,
    },
    DuplicateCanonicalSeed {
        seed: usize,
    },
    MissingCanonicalSeed {
        seed: usize,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CanonicalFreshCoinTheoremInputError {
    CanonicalSeedSpaceOverflow,
    CanonicalSeedCountMismatch {
        seed_count: usize,
        canonical_seed_count: usize,
    },
    RepresentativeSeedOutOfRange {
        representative_seed: usize,
        seed_count: usize,
    },
    PublicLeafScaffoldMismatch,
    FreshCoinScaffoldExtractionMismatch,
    FreshCoinScaffoldMismatch,
    FreshCoinValuesExtractionMismatch,
    CanonicalFreshCoinValuesMismatch {
        representative_seed: usize,
    },
}

impl fmt::Display for RefinementWitnessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingPublicOutcome => write!(f, "theorem trace is missing public_outcome"),
            Self::MissingControllerShape => write!(f, "theorem trace is missing controller_shape"),
            Self::MissingNormalizedMicroTrace => {
                write!(f, "theorem trace is missing normalized_micro_trace")
            }
            Self::MissingControllerCertificate => {
                write!(f, "execution trace is missing runtime_controller_certificate")
            }
            Self::ControllerObserverTraceMismatch => write!(
                f,
                "stored runtime trusted kernel bundle disagrees with execution trace controller observer"
            ),
            Self::HiddenCertificateTraceMismatch => write!(
                f,
                "stored runtime trusted kernel bundle disagrees with execution trace hidden certificate"
            ),
            Self::TrustedKernelBundleTraceMismatch => write!(
                f,
                "stored runtime trusted kernel bundle disagrees with execution trace reconstruction"
            ),
            Self::KernelWitnessTraceMismatch => write!(
                f,
                "stored runtime trusted kernel bundle disagrees with execution trace kernel witness"
            ),
            Self::KernelWitness(err) => {
                write!(f, "runtime refinement witness carries an invalid kernel witness: {err}")
            }
            Self::RuntimeKernelRefinement(err) => {
                write!(
                    f,
                    "runtime refinement witness carries an invalid runtime-phase witness: {err}"
                )
            }
            Self::UnknownOramLogicalObject { object } => write!(
                f,
                "logical ORAM trace references unknown ORAM object '{}'",
                object
            ),
            Self::UnsupportedOramScheme { scheme } => write!(
                f,
                "runtime refinement witness does not support ORAM scheme '{}'",
                scheme
            ),
            Self::MalformedOramLogicalTrace {
                object,
                expected_kind,
                detail_prefix,
            } => write!(
                f,
                "logical ORAM trace for object '{}' is missing expected '{}' event with '{}' detail",
                object, expected_kind, detail_prefix
            ),
            Self::OramAccessScheduleMismatch => write!(
                f,
                "controller certificate does not match the ORAM schedule reconstructed from logical trace"
            ),
            Self::GasMismatch {
                trace_gas,
                public_outcome_gas,
            } => write!(
                f,
                "trace gas {} does not match public outcome gas {}",
                trace_gas, public_outcome_gas
            ),
            Self::BoundaryBudgetMismatch {
                boundary_events,
                boundary_budget,
            } => write!(
                f,
                "boundary schedule length {} does not match controller budget {}",
                boundary_events, boundary_budget
            ),
            Self::BoundaryScheduleMismatch => write!(
                f,
                "boundary schedule does not match the controller-certificate reconstruction"
            ),
            Self::ControllerShapeMismatch => write!(
                f,
                "controller shape does not match the controller-certificate reconstruction"
            ),
            Self::NormalizedMicroTraceMismatch => write!(
                f,
                "normalized micro trace does not match the controller-shape simulation"
            ),
            Self::OramLeafScheduleMismatch => write!(
                f,
                "hidden path-ORAM leaf schedule does not match the reconstructed public scaffold or bucket trace"
            ),
            Self::OramLeafStateMismatch => write!(
                f,
                "hidden path-ORAM state witness does not match the emitted leaf schedule evolution"
            ),
        }
    }
}

impl std::error::Error for RefinementWitnessError {}

impl fmt::Display for RuntimeKernelRefinementWitnessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingKernelWitness => write!(
                f,
                "runtime-phase witness requires the public kernel witness to be present"
            ),
            Self::MalformedRuntimePhaseTrace { witnessed } => write!(
                f,
                "runtime-phase trace has malformed internal shape or ordering: {:?}",
                witnessed
            ),
            Self::KernelProjectionMismatch { expected, witnessed } => write!(
                f,
                "runtime-phase kernel-step projection mismatch: expected {:?}, got {:?}",
                expected, witnessed
            ),
            Self::ObjectScheduleMismatch {
                loaded,
                committed,
                cold_stored,
            } => write!(
                f,
                "runtime-phase object schedules disagree between shadow-load, commit, and cold-store: loaded {:?}, committed {:?}, cold_stored {:?}",
                loaded, committed, cold_stored
            ),
            Self::PreCommittedColdObjectScheduleMismatch { expected, witnessed } => write!(
                f,
                "runtime-phase pre-begin committed-cold schedule does not match the public object universe: expected {:?}, witnessed {:?}",
                expected, witnessed
            ),
            Self::PostCommittedColdObjectScheduleMismatch { expected, witnessed } => write!(
                f,
                "runtime-phase post-wipe committed-cold schedule does not match the public object universe: expected {:?}, witnessed {:?}",
                expected, witnessed
            ),
            Self::CanonicalObjectScheduleMismatch { expected, witnessed } => write!(
                f,
                "runtime-phase shadow-load schedule does not match the canonical kernel object set: expected {:?}, witnessed {:?}",
                expected, witnessed
            ),
            Self::KernelObjectCoverageMismatch {
                kernel_objects,
                loaded_objects,
            } => write!(
                f,
                "runtime-phase shadow-load schedule does not cover every kernel-visible object: kernel {:?}, loaded {:?}",
                kernel_objects, loaded_objects
            ),
        }
    }
}

impl std::error::Error for RuntimeKernelRefinementWitnessError {}

impl fmt::Display for RuntimeKernelRefinementTrackerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EventCapacityOverflow {
                public_object_count,
                max_kernel_ops,
            } => write!(
                f,
                "runtime-phase event bound overflowed for {} public objects and {} kernel ops",
                public_object_count, max_kernel_ops
            ),
            Self::EventCapacityExceeded {
                attempted_events,
                max_events,
            } => write!(
                f,
                "runtime-phase tracker exceeded bound: attempted {} events with bound {}",
                attempted_events, max_events
            ),
            Self::UnexpectedPhaseEvent { phase, event } => write!(
                f,
                "runtime-phase tracker rejected event {:?} in phase {:?}",
                event.kind(),
                phase
            ),
            Self::PhaseMismatch {
                action,
                observed,
                expected,
            } => write!(
                f,
                "runtime-phase tracker cannot {} in phase {:?}; expected {:?}",
                action, observed, expected
            ),
            Self::Witness(err) => err.fmt(f),
        }
    }
}

impl std::error::Error for RuntimeKernelRefinementTrackerError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Witness(err) => Some(err),
            _ => None,
        }
    }
}

impl fmt::Display for KernelWitnessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingKernelWitness => write!(f, "execution trace is missing runtime kernel witness"),
            Self::UnknownEntrypoint { entrypoint } => {
                write!(f, "artifact is missing entrypoint {}", entrypoint)
            }
            Self::MissingManifestEntrypoint { entrypoint } => {
                write!(f, "manifest is missing entrypoint {}", entrypoint)
            }
            Self::EntrypointNotConfidential { entrypoint } => write!(
                f,
                "entrypoint {} is not confidential, so the exact kernel witness is not part of the claim boundary",
                entrypoint
            ),
            Self::EntrypointMismatch {
                expected,
                witnessed,
            } => write!(
                f,
                "kernel witness entrypoint mismatch: witnessed {}, expected {}",
                witnessed, expected
            ),
            Self::ArenaBudgetMismatch {
                witnessed,
                expected,
            } => write!(
                f,
                "kernel witness arena budget mismatch: {} != {}",
                witnessed, expected
            ),
            Self::StackBudgetMismatch {
                witnessed,
                expected,
            } => write!(
                f,
                "kernel witness stack budget mismatch: {} != {}",
                witnessed, expected
            ),
            Self::ScratchBudgetMismatch {
                witnessed,
                expected,
            } => write!(
                f,
                "kernel witness scratch budget mismatch: {} != {}",
                witnessed, expected
            ),
            Self::MalformedKernelOpcodeEnvelope { witnessed } => write!(
                f,
                "kernel opcode trace has malformed Begin/.../Commit/Wipe envelope: {:?}",
                witnessed
            ),
            Self::MalformedKernelStepTrace { witnessed } => write!(
                f,
                "kernel step trace has malformed public shape: {:?}",
                witnessed
            ),
            Self::MalformedKernelResourceTrace { witnessed } => write!(
                f,
                "kernel resource trace has malformed public shape: {:?}",
                witnessed
            ),
            Self::PeakStackWordsExceeded { peak, budget } => write!(
                f,
                "kernel witness peak stack words {} exceed budget {}",
                peak, budget
            ),
            Self::ValueScratchPeakExceeded { peak, budget } => write!(
                f,
                "kernel witness value scratch peak {} exceeds budget {}",
                peak, budget
            ),
            Self::HashScratchPeakExceeded { peak, budget } => write!(
                f,
                "kernel witness hash scratch peak {} exceeds budget {}",
                peak, budget
            ),
            Self::IoScratchPeakExceeded { peak, budget } => write!(
                f,
                "kernel witness io scratch peak {} exceeds budget {}",
                peak, budget
            ),
            Self::ValueScratchNotWiped {
                live_bytes_end,
                wipe_count,
            } => write!(
                f,
                "kernel witness value scratch not wiped: live {} bytes, wipe count {}",
                live_bytes_end, wipe_count
            ),
            Self::HashScratchNotWiped {
                live_bytes_end,
                wipe_count,
            } => write!(
                f,
                "kernel witness hash scratch not wiped: live {} bytes, wipe count {}",
                live_bytes_end, wipe_count
            ),
            Self::IoScratchNotWiped {
                live_bytes_end,
                wipe_count,
            } => write!(
                f,
                "kernel witness io scratch not wiped: live {} bytes, wipe count {}",
                live_bytes_end, wipe_count
            ),
            Self::ConfidentialControlFlow {
                entrypoint,
                statement,
            } => write!(
                f,
                "confidential entrypoint {} still contains unsupported control flow at {}",
                entrypoint, statement
            ),
            Self::SelectContainsKernelAccess { entrypoint } => write!(
                f,
                "confidential entrypoint {} contains a select expression with kernel-visible storage access",
                entrypoint
            ),
            Self::SelectArmOutsideBranchlessFragment { entrypoint } => write!(
                f,
                "confidential entrypoint {} contains a select arm outside the branchless pure fragment admitted by the confidential runtime",
                entrypoint
            ),
            Self::ConfidentialStructField { entrypoint } => write!(
                f,
                "confidential entrypoint {} contains unsupported struct-field projection in the confidential fragment",
                entrypoint
            ),
            Self::ConfidentialArrayIndex { entrypoint } => write!(
                f,
                "confidential entrypoint {} contains unsupported array indexing in the confidential fragment",
                entrypoint
            ),
            Self::MissingExpectedKernelSteps { entrypoint } => write!(
                f,
                "confidential runtime kernel witness for {} is missing the artifact-derived expected step trace",
                entrypoint
            ),
            Self::MissingManifestConfidentialSlotProgram { entrypoint } => write!(
                f,
                "confidential manifest entrypoint {} is missing confidential_slot_program",
                entrypoint
            ),
            Self::MissingExpectedPublicObjectIds { entrypoint } => write!(
                f,
                "confidential runtime kernel witness for {} is missing the artifact-derived public object universe",
                entrypoint
            ),
            Self::ExpectedKernelScheduleEmpty => write!(
                f,
                "runtime kernel admitted schedule was empty"
            ),
            Self::ExpectedKernelScheduleMustBegin { witnessed } => write!(
                f,
                "runtime kernel admitted schedule does not begin with the admitted Begin step: {:?}",
                witnessed
            ),
            Self::ExpectedKernelScheduleExtraStep { observed } => write!(
                f,
                "runtime kernel emitted unexpected extra step {:?} after exhausting admitted schedule",
                observed
            ),
            Self::ExpectedKernelScheduleStepMismatch {
                index,
                expected,
                observed,
            } => write!(
                f,
                "runtime kernel step schedule mismatch at index {}: expected {:?}, got {:?}",
                index,
                expected,
                observed
            ),
            Self::ExpectedKernelScheduleIncomplete {
                observed_steps,
                expected_steps,
            } => write!(
                f,
                "runtime kernel stopped after {} admitted steps but {} were required",
                observed_steps,
                expected_steps
            ),
            Self::KernelStepBudgetExceeded {
                attempted_steps,
                budget,
            } => write!(
                f,
                "kernel step trace exceeded public budget: attempted {} steps with budget {}",
                attempted_steps, budget
            ),
            Self::MalformedPublicObjectUniverse { witnessed } => write!(
                f,
                "kernel witness public object universe is not canonical strictly ascending unique order: {:?}",
                witnessed
            ),
            Self::PublicObjectUniverseMismatch { expected, witnessed } => write!(
                f,
                "kernel public object universe mismatch: witnessed {:?}, expected {:?}",
                witnessed, expected
            ),
            Self::KernelObjectOutsidePublicUniverse {
                object_id,
                public_object_ids,
            } => write!(
                f,
                "kernel step references object {} outside the public object universe {:?}",
                object_id, public_object_ids
            ),
            Self::KernelOpcodeTraceMismatch {
                expected,
                witnessed,
            } => write!(
                f,
                "kernel opcode trace mismatch: witnessed {:?}, expected {:?}",
                witnessed, expected
            ),
            Self::KernelStepTraceMismatch {
                expected,
                witnessed,
            } => write!(
                f,
                "kernel step trace mismatch: witnessed {:?}, expected {:?}",
                witnessed, expected
            ),
            Self::KernelResourceTraceMismatch {
                field,
                expected,
                witnessed,
            } => write!(
                f,
                "kernel resource trace mismatch for {}: witnessed {}, expected {}",
                field, witnessed, expected
            ),
        }
    }
}

impl std::error::Error for KernelWitnessError {}

impl fmt::Display for SeededRuntimeWitnessFamilyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::SeedCountMismatch {
                seed_count,
                witness_count,
            } => write!(
                f,
                "seed count {} does not match witness count {}",
                seed_count, witness_count
            ),
            Self::SeedIndexTooLarge { index } => {
                write!(f, "seeded witness index {} does not fit in u64", index)
            }
            Self::MissingSeedTag { index } => write!(
                f,
                "seeded witness at index {} is missing a runtime_seed tag",
                index
            ),
            Self::SeedTagMismatch { index, tagged_seed } => write!(
                f,
                "seeded witness at index {} is tagged with runtime_seed {}",
                index, tagged_seed
            ),
            Self::PublicLeafScaffoldMismatch { index } => write!(
                f,
                "seeded path-ORAM witness at index {} does not match the shared public leaf scaffold",
                index
            ),
        }
    }
}

impl std::error::Error for SeededRuntimeWitnessFamilyError {}

impl fmt::Display for SeededRuntimePaperMainFamilyBundleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Family(err) => write!(
                f,
                "seeded runtime paper-main family bundle requires a valid seeded runtime family: {}",
                err
            ),
            Self::EmptyFamily => write!(
                f,
                "seeded runtime paper-main family bundle requires at least one witness"
            ),
            Self::PublicOutcomeMismatch { index } => write!(
                f,
                "seeded runtime paper-main family witness at index {} does not match the shared public outcome",
                index
            ),
            Self::BoundaryScheduleMismatch { index } => write!(
                f,
                "seeded runtime paper-main family witness at index {} does not match the shared boundary schedule",
                index
            ),
        }
    }
}

impl std::error::Error for SeededRuntimePaperMainFamilyBundleError {}

impl fmt::Display for SeededRuntimePaperMainSlotFamilyBundleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Family(err) => write!(
                f,
                "seeded runtime paper-main slot family bundle requires a valid paper-main family bundle: {}",
                err
            ),
            Self::SlotProgramEntrypointMismatch {
                expected_entrypoint,
                program_entrypoint,
            } => write!(
                f,
                "seeded runtime paper-main slot family bundle expected confidential slot program for '{}' but found program for '{}'",
                expected_entrypoint, program_entrypoint
            ),
            Self::SlotProgramNotRuntimeNormalForm { entrypoint } => write!(
                f,
                "seeded runtime paper-main slot family bundle requires a runtime-normal-form confidential slot program for '{}'",
                entrypoint
            ),
            Self::MissingKernelWitness { index } => write!(
                f,
                "seeded runtime paper-main slot family witness at index {} is missing a kernel witness",
                index
            ),
            Self::ExpectedKernelStepsMismatch { index } => write!(
                f,
                "seeded runtime paper-main slot family witness at index {} does not match the shared slot program's expected kernel schedule",
                index
            ),
            Self::EmittedKernelStepsMismatch { index } => write!(
                f,
                "seeded runtime paper-main slot family witness at index {} does not emit the shared slot program's exact kernel schedule",
                index
            ),
        }
    }
}

impl std::error::Error for SeededRuntimePaperMainSlotFamilyBundleError {}

impl fmt::Display for RuntimePaperMainFamilyBundleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::RuntimeWitness(err) => write!(
                f,
                "runtime paper-main family bundle requires a valid runtime refinement witness: {}",
                err
            ),
            Self::Family(err) => write!(
                f,
                "runtime paper-main family bundle requires a valid canonical seeded family: {}",
                err
            ),
            Self::PaperMain(err) => write!(
                f,
                "runtime paper-main family bundle failed proof-grade validation: {}",
                err
            ),
        }
    }
}

impl std::error::Error for RuntimePaperMainFamilyBundleError {}

impl fmt::Display for RuntimePaperMainSlotFamilyBundleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Family(err) => write!(
                f,
                "runtime paper-main slot family bundle requires a valid canonical paper-main family bundle: {}",
                err
            ),
            Self::MissingEntrypoint { entrypoint } => write!(
                f,
                "runtime paper-main slot family bundle is missing manifest entrypoint '{}'",
                entrypoint
            ),
            Self::MissingConfidentialSlotProgram { entrypoint } => write!(
                f,
                "runtime paper-main slot family bundle is missing confidential_slot_program for '{}'",
                entrypoint
            ),
            Self::PaperMainSlot(err) => write!(
                f,
                "runtime paper-main slot family bundle failed proof-grade validation: {}",
                err
            ),
        }
    }
}

impl std::error::Error for RuntimePaperMainSlotFamilyBundleError {}

impl fmt::Display for CanonicalFreshCoinWitnessFamilyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::SeedCountMismatch {
                seed_count,
                witness_count,
            } => write!(
                f,
                "seed count {} does not match witness count {}",
                seed_count, witness_count
            ),
            Self::CanonicalSeedSpaceOverflow => write!(
                f,
                "canonical fresh-coin seed space does not fit in usize"
            ),
            Self::CanonicalSeedCountMismatch {
                seed_count,
                canonical_seed_count,
            } => write!(
                f,
                "seed count {} does not match canonical fresh-coin seed space {}",
                seed_count, canonical_seed_count
            ),
            Self::PublicLeafScaffoldMismatch { index } => write!(
                f,
                "canonical fresh-coin witness at index {} does not match the shared public leaf scaffold",
                index
            ),
            Self::FreshCoinScaffoldExtractionMismatch { index } => write!(
                f,
                "canonical fresh-coin witness at index {} does not admit fresh-coin scaffold extraction",
                index
            ),
            Self::FreshCoinScaffoldMismatch { index } => write!(
                f,
                "canonical fresh-coin witness at index {} does not match the shared fresh-coin scaffold",
                index
            ),
            Self::FreshCoinValuesExtractionMismatch { index } => write!(
                f,
                "canonical fresh-coin witness at index {} does not admit fresh-coin value extraction",
                index
            ),
            Self::CanonicalFreshCoinValuesMismatch { index } => write!(
                f,
                "canonical fresh-coin witness at index {} does not match the canonical fresh-coin seed trace",
                index
            ),
            Self::DuplicateCanonicalSeed { seed } => write!(
                f,
                "canonical fresh-coin family contains multiple witnesses for canonical seed {}",
                seed
            ),
            Self::MissingCanonicalSeed { seed } => write!(
                f,
                "canonical fresh-coin family is missing a witness for canonical seed {}",
                seed
            ),
        }
    }
}

impl std::error::Error for CanonicalFreshCoinWitnessFamilyError {}

impl fmt::Display for CanonicalFreshCoinTheoremInputError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::CanonicalSeedSpaceOverflow => write!(
                f,
                "canonical fresh-coin seed space does not fit in usize"
            ),
            Self::CanonicalSeedCountMismatch {
                seed_count,
                canonical_seed_count,
            } => write!(
                f,
                "seed count {} does not match canonical fresh-coin seed space {}",
                seed_count, canonical_seed_count
            ),
            Self::RepresentativeSeedOutOfRange {
                representative_seed,
                seed_count,
            } => write!(
                f,
                "representative canonical seed {} is outside seed space {}",
                representative_seed, seed_count
            ),
            Self::PublicLeafScaffoldMismatch => write!(
                f,
                "representative canonical fresh-coin witness does not match the shared public leaf scaffold"
            ),
            Self::FreshCoinScaffoldExtractionMismatch => write!(
                f,
                "representative canonical fresh-coin witness does not admit fresh-coin scaffold extraction"
            ),
            Self::FreshCoinScaffoldMismatch => write!(
                f,
                "representative canonical fresh-coin witness does not match the shared fresh-coin scaffold"
            ),
            Self::FreshCoinValuesExtractionMismatch => write!(
                f,
                "representative canonical fresh-coin witness does not admit fresh-coin value extraction"
            ),
            Self::CanonicalFreshCoinValuesMismatch { representative_seed } => write!(
                f,
                "representative canonical fresh-coin witness does not match canonical seed {}",
                representative_seed
            ),
        }
    }
}

impl std::error::Error for CanonicalFreshCoinTheoremInputError {}

impl RuntimeRefinementWitness {
    pub fn trace(&self) -> &RefinementTrace {
        &self.trace
    }

    pub fn runtime_seed(&self) -> Option<u64> {
        self.runtime_seed
    }

    pub fn with_runtime_seed(mut self, runtime_seed: u64) -> Result<Self, RefinementWitnessError> {
        self.runtime_seed = Some(runtime_seed);
        self.validate()?;
        Ok(self)
    }

    pub fn public_outcome(&self) -> &PublicOutcomeTrace {
        &self.public_outcome
    }

    pub fn kernel_witness(&self) -> Option<&RuntimeKernelWitness> {
        self.kernel_witness.as_ref()
    }

    pub fn runtime_kernel_refinement_witness(&self) -> Option<&RuntimeKernelRefinementWitness> {
        self.runtime_kernel_refinement_witness.as_ref()
    }

    pub fn boundary_schedule(&self) -> &[BoundaryEvent] {
        &self.boundary_schedule
    }

    pub fn controller_shape(&self) -> &SgxControllerShapeTrace {
        &self.controller_shape
    }

    pub fn normalized_micro_trace(&self) -> &NormalizedMicroTrace {
        &self.normalized_micro_trace
    }

    pub fn controller_certificate(&self) -> &RuntimeControllerCertificate {
        &self.controller_certificate
    }

    pub fn oram_objects(&self) -> &[RuntimeOramObjectWitness] {
        &self.oram_objects
    }

    pub fn oram_leaf_public_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.oram_leaf_public_scaffold
    }

    pub fn oram_leaf_schedule(&self) -> &[RuntimeOramLeafWitness] {
        &self.oram_leaf_schedule
    }

    pub fn oram_position_map_before(&self) -> &[RuntimePathOramPositionMapWitness] {
        &self.oram_position_map_before
    }

    pub fn oram_position_map_after(&self) -> &[RuntimePathOramPositionMapWitness] {
        &self.oram_position_map_after
    }

    pub fn oram_leaf_state_transitions(&self) -> &[RuntimePathOramTransitionWitness] {
        &self.oram_leaf_state_transitions
    }

    #[cfg(test)]
    fn from_certificates(
        runtime_seed: Option<u64>,
        controller_observer: RuntimeControllerObserverCertificate,
        hidden_certificate: RuntimePathOramHiddenCertificate,
    ) -> Result<Self, RefinementWitnessError> {
        Self::from_certificates_with_runtime_witnesses(
            runtime_seed,
            controller_observer,
            None,
            None,
            hidden_certificate,
        )
    }

    fn from_certificates_with_kernel_witness(
        runtime_seed: Option<u64>,
        controller_observer: RuntimeControllerObserverCertificate,
        kernel_witness: Option<RuntimeKernelWitness>,
        hidden_certificate: RuntimePathOramHiddenCertificate,
    ) -> Result<Self, RefinementWitnessError> {
        Self::from_certificates_with_runtime_witnesses(
            runtime_seed,
            controller_observer,
            kernel_witness,
            None,
            hidden_certificate,
        )
    }

    fn from_certificates_with_runtime_witnesses(
        runtime_seed: Option<u64>,
        controller_observer: RuntimeControllerObserverCertificate,
        kernel_witness: Option<RuntimeKernelWitness>,
        runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,
        hidden_certificate: RuntimePathOramHiddenCertificate,
    ) -> Result<Self, RefinementWitnessError> {
        let witness = Self {
            trace: hidden_certificate.trace,
            runtime_seed,
            public_outcome: controller_observer.public_outcome,
            kernel_witness,
            runtime_kernel_refinement_witness,
            boundary_schedule: controller_observer.boundary_schedule,
            controller_shape: controller_observer.controller_shape,
            normalized_micro_trace: controller_observer.normalized_micro_trace,
            controller_certificate: controller_observer.controller_certificate,
            oram_objects: hidden_certificate.oram_objects,
            oram_leaf_public_scaffold: hidden_certificate.oram_leaf_public_scaffold,
            oram_leaf_schedule: hidden_certificate.oram_leaf_schedule,
            oram_position_map_before: hidden_certificate.oram_position_map_before,
            oram_position_map_after: hidden_certificate.oram_position_map_after,
            oram_leaf_state_transitions: hidden_certificate.oram_leaf_state_transitions,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), RefinementWitnessError> {
        RuntimeControllerObserverCertificate::new(
            self.public_outcome.clone(),
            self.boundary_schedule.clone(),
            self.controller_shape.clone(),
            self.normalized_micro_trace.clone(),
            self.controller_certificate.clone(),
        )?;
        RuntimePathOramHiddenCertificate::new(
            self.trace.clone(),
            self.oram_objects.clone(),
            self.oram_leaf_schedule.clone(),
            self.oram_position_map_before.clone(),
            self.oram_position_map_after.clone(),
            self.oram_leaf_state_transitions.clone(),
        )?;
        let reconstructed_accesses = reconstruct_oram_accesses_from_logical_trace(
            &self.trace.logical_accesses,
            &self.oram_objects,
        )?;
        if self.trace.gas_used != self.public_outcome.gas_used {
            return Err(RefinementWitnessError::GasMismatch {
                trace_gas: self.trace.gas_used,
                public_outcome_gas: self.public_outcome.gas_used,
            });
        }
        if let Some(kernel_witness) = &self.kernel_witness {
            kernel_witness
                .validate_for_entrypoint(&self.public_outcome.entrypoint_id)
                .map_err(RefinementWitnessError::KernelWitness)?;
        }
        if let Some(runtime_kernel_refinement_witness) = &self.runtime_kernel_refinement_witness {
            let kernel_witness = self.kernel_witness.as_ref().ok_or(
                RefinementWitnessError::RuntimeKernelRefinement(
                    RuntimeKernelRefinementWitnessError::MissingKernelWitness,
                ),
            )?;
            runtime_kernel_refinement_witness
                .validate_with_kernel_witness(kernel_witness)
                .map_err(RefinementWitnessError::RuntimeKernelRefinement)?;
        }
        if self.controller_certificate.observed_oram_accesses != reconstructed_accesses {
            return Err(RefinementWitnessError::OramAccessScheduleMismatch);
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("runtime refinement witness is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self).expect("runtime refinement witness is JSON serializable")
    }

    pub fn path_oram_fresh_coin_scaffold(&self) -> Option<Vec<RuntimeOramLeafScaffoldWitness>> {
        extract_runtime_path_oram_fresh_coin_scaffold(
            &self.oram_leaf_schedule,
            &self.oram_leaf_state_transitions,
        )
    }

    pub fn path_oram_fresh_coin_values(&self) -> Option<Vec<usize>> {
        extract_runtime_path_oram_fresh_coin_values(
            &self.oram_leaf_schedule,
            &self.oram_leaf_state_transitions,
        )
    }
}

impl RuntimeTrustedKernelBundle {
    pub fn runtime_seed(&self) -> Option<u64> {
        self.runtime_seed
    }

    pub fn controller_observer(&self) -> &RuntimeControllerObserverCertificate {
        &self.controller_observer
    }

    pub fn kernel_witness(&self) -> Option<&RuntimeKernelWitness> {
        self.kernel_witness.as_ref()
    }

    pub fn hidden_certificate(&self) -> &RuntimePathOramHiddenCertificate {
        &self.hidden_certificate
    }

    fn new_with_kernel_witness(
        runtime_seed: Option<u64>,
        controller_observer: RuntimeControllerObserverCertificate,
        kernel_witness: Option<RuntimeKernelWitness>,
        hidden_certificate: RuntimePathOramHiddenCertificate,
    ) -> Result<Self, RefinementWitnessError> {
        let bundle = Self {
            runtime_seed,
            controller_observer,
            kernel_witness,
            hidden_certificate,
        };
        bundle.validate()?;
        Ok(bundle)
    }

    pub fn to_witness(&self) -> Result<RuntimeRefinementWitness, RefinementWitnessError> {
        RuntimeRefinementWitness::from_certificates_with_kernel_witness(
            self.runtime_seed,
            self.controller_observer.clone(),
            self.kernel_witness.clone(),
            self.hidden_certificate.clone(),
        )
    }

    pub fn validate(&self) -> Result<(), RefinementWitnessError> {
        self.to_witness().map(|_| ())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("runtime trusted kernel bundle is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("runtime trusted kernel bundle is JSON serializable")
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct RuntimeKernelResourceReplayUsage {
    live_bytes: usize,
    peak_bytes: usize,
    wipe_count: usize,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct RuntimeKernelResourceReplayState {
    peak_stack_words: usize,
    value_scratch: RuntimeKernelResourceReplayUsage,
    hash_scratch: RuntimeKernelResourceReplayUsage,
    io_scratch: RuntimeKernelResourceReplayUsage,
}

impl RuntimeKernelTelemetrySnapshot {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        arena_bytes: usize,
        max_stack_words: usize,
        scratch_bytes: usize,
        peak_stack_words: usize,
        value_scratch_peak_bytes: usize,
        value_scratch_live_bytes_end: usize,
        value_scratch_wipe_count: usize,
        hash_scratch_peak_bytes: usize,
        hash_scratch_live_bytes_end: usize,
        hash_scratch_wipe_count: usize,
        io_scratch_peak_bytes: usize,
        io_scratch_live_bytes_end: usize,
        io_scratch_wipe_count: usize,
        resource_events: Vec<RuntimeKernelResourceEventWitness>,
    ) -> Self {
        Self {
            arena_bytes,
            max_stack_words,
            scratch_bytes,
            peak_stack_words,
            value_scratch_peak_bytes,
            value_scratch_live_bytes_end,
            value_scratch_wipe_count,
            hash_scratch_peak_bytes,
            hash_scratch_live_bytes_end,
            hash_scratch_wipe_count,
            io_scratch_peak_bytes,
            io_scratch_live_bytes_end,
            io_scratch_wipe_count,
            resource_events,
        }
    }

    pub fn resource_events(&self) -> &[RuntimeKernelResourceEventWitness] {
        &self.resource_events
    }
}

impl RuntimeKernelWitness {
    pub fn from_telemetry_and_execution_tracker(
        entrypoint_id: String,
        telemetry: RuntimeKernelTelemetrySnapshot,
        kernel_execution: RuntimeKernelExecutionTracker,
        public_object_ids: Vec<u32>,
        expected_public_object_ids: Option<Vec<u32>>,
    ) -> Result<Self, KernelWitnessError> {
        let expected_kernel_steps = kernel_execution
            .expected_kernel_steps()
            .map(|steps| steps.to_vec());
        let kernel_steps = kernel_execution.into_emitted_kernel_steps();
        Self::new(
            entrypoint_id,
            telemetry.arena_bytes,
            telemetry.max_stack_words,
            telemetry.scratch_bytes,
            telemetry.peak_stack_words,
            telemetry.value_scratch_peak_bytes,
            telemetry.value_scratch_live_bytes_end,
            telemetry.value_scratch_wipe_count,
            telemetry.hash_scratch_peak_bytes,
            telemetry.hash_scratch_live_bytes_end,
            telemetry.hash_scratch_wipe_count,
            telemetry.io_scratch_peak_bytes,
            telemetry.io_scratch_live_bytes_end,
            telemetry.io_scratch_wipe_count,
            telemetry.resource_events,
            expected_kernel_steps,
            public_object_ids,
            expected_public_object_ids,
            kernel_steps,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn new(
        entrypoint_id: String,
        arena_bytes: usize,
        max_stack_words: usize,
        scratch_bytes: usize,
        peak_stack_words: usize,
        value_scratch_peak_bytes: usize,
        value_scratch_live_bytes_end: usize,
        value_scratch_wipe_count: usize,
        hash_scratch_peak_bytes: usize,
        hash_scratch_live_bytes_end: usize,
        hash_scratch_wipe_count: usize,
        io_scratch_peak_bytes: usize,
        io_scratch_live_bytes_end: usize,
        io_scratch_wipe_count: usize,
        resource_events: Vec<RuntimeKernelResourceEventWitness>,
        expected_kernel_steps: Option<Vec<RuntimeKernelStepWitness>>,
        public_object_ids: Vec<u32>,
        expected_public_object_ids: Option<Vec<u32>>,
        kernel_steps: Vec<RuntimeKernelStepWitness>,
    ) -> Result<Self, KernelWitnessError> {
        let witness = Self {
            entrypoint_id,
            arena_bytes,
            max_stack_words,
            scratch_bytes,
            peak_stack_words,
            value_scratch_peak_bytes,
            value_scratch_live_bytes_end,
            value_scratch_wipe_count,
            hash_scratch_peak_bytes,
            hash_scratch_live_bytes_end,
            hash_scratch_wipe_count,
            io_scratch_peak_bytes,
            io_scratch_live_bytes_end,
            io_scratch_wipe_count,
            resource_events,
            expected_kernel_steps,
            public_object_ids,
            expected_public_object_ids,
            kernel_steps,
        };
        witness.validate_shape()?;
        Ok(witness)
    }

    pub fn entrypoint_id(&self) -> &str {
        &self.entrypoint_id
    }

    pub fn arena_bytes(&self) -> usize {
        self.arena_bytes
    }

    pub fn max_stack_words(&self) -> usize {
        self.max_stack_words
    }

    pub fn scratch_bytes(&self) -> usize {
        self.scratch_bytes
    }

    pub fn peak_stack_words(&self) -> usize {
        self.peak_stack_words
    }

    pub fn value_scratch_peak_bytes(&self) -> usize {
        self.value_scratch_peak_bytes
    }

    pub fn value_scratch_live_bytes_end(&self) -> usize {
        self.value_scratch_live_bytes_end
    }

    pub fn value_scratch_wipe_count(&self) -> usize {
        self.value_scratch_wipe_count
    }

    pub fn hash_scratch_peak_bytes(&self) -> usize {
        self.hash_scratch_peak_bytes
    }

    pub fn hash_scratch_live_bytes_end(&self) -> usize {
        self.hash_scratch_live_bytes_end
    }

    pub fn hash_scratch_wipe_count(&self) -> usize {
        self.hash_scratch_wipe_count
    }

    pub fn io_scratch_peak_bytes(&self) -> usize {
        self.io_scratch_peak_bytes
    }

    pub fn io_scratch_live_bytes_end(&self) -> usize {
        self.io_scratch_live_bytes_end
    }

    pub fn io_scratch_wipe_count(&self) -> usize {
        self.io_scratch_wipe_count
    }

    pub fn resource_events(&self) -> &[RuntimeKernelResourceEventWitness] {
        &self.resource_events
    }

    pub fn expected_kernel_steps(&self) -> Option<&[RuntimeKernelStepWitness]> {
        self.expected_kernel_steps.as_deref()
    }

    pub fn kernel_steps(&self) -> &[RuntimeKernelStepWitness] {
        &self.kernel_steps
    }

    pub fn emitted_kernel_schedule(&self) -> RuntimeKernelScheduleWitness {
        RuntimeKernelScheduleWitness::new(
            self.kernel_steps
                .iter()
                .map(RuntimeKernelStepWitness::projected_opcode)
                .collect(),
            self.kernel_steps.clone(),
        )
        .expect("kernel witness already validates emitted schedule shape")
    }

    pub fn expected_kernel_schedule(&self) -> Option<RuntimeKernelScheduleWitness> {
        let steps = self.expected_kernel_steps.clone()?;
        Some(
            RuntimeKernelScheduleWitness::new(
                steps
                    .iter()
                    .map(RuntimeKernelStepWitness::projected_opcode)
                    .collect(),
                steps,
            )
            .expect("manifest-backed expected kernel schedule must satisfy shape invariants"),
        )
    }

    pub fn validate_shape(&self) -> Result<(), KernelWitnessError> {
        let expected_scratch = self.arena_bytes / 4;
        if self.scratch_bytes != expected_scratch {
            return Err(KernelWitnessError::ScratchBudgetMismatch {
                witnessed: self.scratch_bytes,
                expected: expected_scratch,
            });
        }
        if self.peak_stack_words > self.max_stack_words {
            return Err(KernelWitnessError::PeakStackWordsExceeded {
                peak: self.peak_stack_words,
                budget: self.max_stack_words,
            });
        }
        if self.value_scratch_peak_bytes > self.scratch_bytes {
            return Err(KernelWitnessError::ValueScratchPeakExceeded {
                peak: self.value_scratch_peak_bytes,
                budget: self.scratch_bytes,
            });
        }
        if self.hash_scratch_peak_bytes > self.scratch_bytes {
            return Err(KernelWitnessError::HashScratchPeakExceeded {
                peak: self.hash_scratch_peak_bytes,
                budget: self.scratch_bytes,
            });
        }
        if self.io_scratch_peak_bytes > self.scratch_bytes {
            return Err(KernelWitnessError::IoScratchPeakExceeded {
                peak: self.io_scratch_peak_bytes,
                budget: self.scratch_bytes,
            });
        }
        if self.value_scratch_live_bytes_end != 0
            || (self.value_scratch_peak_bytes != 0 && self.value_scratch_wipe_count == 0)
        {
            return Err(KernelWitnessError::ValueScratchNotWiped {
                live_bytes_end: self.value_scratch_live_bytes_end,
                wipe_count: self.value_scratch_wipe_count,
            });
        }
        if self.hash_scratch_live_bytes_end != 0
            || (self.hash_scratch_peak_bytes != 0 && self.hash_scratch_wipe_count == 0)
        {
            return Err(KernelWitnessError::HashScratchNotWiped {
                live_bytes_end: self.hash_scratch_live_bytes_end,
                wipe_count: self.hash_scratch_wipe_count,
            });
        }
        if self.io_scratch_live_bytes_end != 0
            || (self.io_scratch_peak_bytes != 0 && self.io_scratch_wipe_count == 0)
        {
            return Err(KernelWitnessError::IoScratchNotWiped {
                live_bytes_end: self.io_scratch_live_bytes_end,
                wipe_count: self.io_scratch_wipe_count,
            });
        }
        let emitted_kernel_opcodes = self
            .kernel_steps
            .iter()
            .map(RuntimeKernelStepWitness::projected_opcode)
            .collect::<Vec<_>>();
        if !matches!(
            emitted_kernel_opcodes.as_slice(),
            [UoOpcode::Begin, .., UoOpcode::Commit, UoOpcode::Wipe]
        ) {
            return Err(KernelWitnessError::MalformedKernelOpcodeEnvelope {
                witnessed: emitted_kernel_opcodes,
            });
        }
        self.emitted_kernel_schedule().validate_shape()?;
        if let Some(expected_schedule) = self.expected_kernel_schedule() {
            expected_schedule.validate_shape()?;
        }
        if let Some(expected) = &self.expected_kernel_steps {
            if &self.kernel_steps != expected {
                return Err(KernelWitnessError::KernelStepTraceMismatch {
                    expected: expected.clone(),
                    witnessed: self.kernel_steps.clone(),
                });
            }
        }
        if !is_canonical_object_id_schedule(&self.public_object_ids) {
            return Err(KernelWitnessError::MalformedPublicObjectUniverse {
                witnessed: self.public_object_ids.clone(),
            });
        }
        if let Some(expected_public_object_ids) = &self.expected_public_object_ids {
            if !is_canonical_object_id_schedule(expected_public_object_ids) {
                return Err(KernelWitnessError::MalformedPublicObjectUniverse {
                    witnessed: expected_public_object_ids.clone(),
                });
            }
            if &self.public_object_ids != expected_public_object_ids {
                return Err(KernelWitnessError::PublicObjectUniverseMismatch {
                    expected: expected_public_object_ids.clone(),
                    witnessed: self.public_object_ids.clone(),
                });
            }
        }
        let public_object_ids = self
            .public_object_ids
            .iter()
            .copied()
            .collect::<BTreeSet<_>>();
        for object_id in self.kernel_steps.iter().filter_map(|step| step.object_id) {
            if !public_object_ids.contains(&object_id) {
                return Err(KernelWitnessError::KernelObjectOutsidePublicUniverse {
                    object_id,
                    public_object_ids: self.public_object_ids.clone(),
                });
            }
        }
        let replayed_resources = self.replay_resource_events()?;
        self.validate_replayed_resources(&replayed_resources)?;
        Ok(())
    }

    pub fn validate_for_entrypoint(&self, entrypoint: &str) -> Result<(), KernelWitnessError> {
        self.validate_shape()?;
        if self.entrypoint_id != entrypoint {
            return Err(KernelWitnessError::EntrypointMismatch {
                expected: entrypoint.into(),
                witnessed: self.entrypoint_id.clone(),
            });
        }
        Ok(())
    }

    pub fn validate_for_confidential(
        &self,
        entrypoint: &str,
        manifest_entry: &EntrypointManifest,
        public_object_ids: &[u32],
    ) -> Result<(), KernelWitnessError> {
        self.validate_for_entrypoint(entrypoint)?;
        if self.arena_bytes != manifest_entry.arena_bytes {
            return Err(KernelWitnessError::ArenaBudgetMismatch {
                witnessed: self.arena_bytes,
                expected: manifest_entry.arena_bytes,
            });
        }
        if self.max_stack_words != manifest_entry.max_stack_words {
            return Err(KernelWitnessError::StackBudgetMismatch {
                witnessed: self.max_stack_words,
                expected: manifest_entry.max_stack_words,
            });
        }
        let manifest_slot_program = manifest_entry
            .confidential_slot_program
            .as_ref()
            .ok_or_else(
                || KernelWitnessError::MissingManifestConfidentialSlotProgram {
                    entrypoint: entrypoint.into(),
                },
            )?;
        let expected_steps = manifest_slot_program.expected_runtime_step_manifest();
        if manifest_entry.kernel_steps != expected_steps {
            return Err(KernelWitnessError::KernelStepTraceMismatch {
                expected: manifest_kernel_steps_as_witness(&expected_steps),
                witnessed: manifest_kernel_steps_as_witness(&manifest_entry.kernel_steps),
            });
        }
        let manifest_expected_steps = manifest_entry.kernel_step_witnesses();
        let witness_expected_steps = self.expected_kernel_steps.as_ref().ok_or_else(|| {
            KernelWitnessError::MissingExpectedKernelSteps {
                entrypoint: entrypoint.into(),
            }
        })?;
        if witness_expected_steps != &manifest_expected_steps {
            return Err(KernelWitnessError::KernelStepTraceMismatch {
                expected: manifest_expected_steps.clone(),
                witnessed: witness_expected_steps.clone(),
            });
        }
        if self.kernel_steps != manifest_expected_steps {
            return Err(KernelWitnessError::KernelStepTraceMismatch {
                expected: witness_expected_steps.clone(),
                witnessed: self.kernel_steps.clone(),
            });
        }
        let witness_expected_public_object_ids = self
            .expected_public_object_ids
            .as_ref()
            .ok_or_else(|| KernelWitnessError::MissingExpectedPublicObjectIds {
                entrypoint: entrypoint.into(),
            })?;
        if witness_expected_public_object_ids != public_object_ids {
            return Err(KernelWitnessError::PublicObjectUniverseMismatch {
                expected: public_object_ids.to_vec(),
                witnessed: witness_expected_public_object_ids.clone(),
            });
        }
        if self.public_object_ids != public_object_ids {
            return Err(KernelWitnessError::PublicObjectUniverseMismatch {
                expected: public_object_ids.to_vec(),
                witnessed: self.public_object_ids.clone(),
            });
        }
        Ok(())
    }

    fn replay_resource_events(
        &self,
    ) -> Result<RuntimeKernelResourceReplayState, KernelWitnessError> {
        let mut state = RuntimeKernelResourceReplayState::default();
        for event in &self.resource_events {
            event.validate_shape()?;
            match event.kind {
                RuntimeKernelResourceEventKindWitness::StackCheck => {
                    let words = event
                        .words
                        .expect("validated stack-check event carries words");
                    if words > self.max_stack_words {
                        return Err(KernelWitnessError::PeakStackWordsExceeded {
                            peak: words,
                            budget: self.max_stack_words,
                        });
                    }
                    state.peak_stack_words = state.peak_stack_words.max(words);
                }
                RuntimeKernelResourceEventKindWitness::ReserveScratch => {
                    let bytes = event
                        .bytes
                        .expect("validated reserve-scratch event carries bytes");
                    let region = event
                        .region
                        .expect("validated reserve-scratch event carries region");
                    if bytes > self.scratch_bytes {
                        return Err(match region {
                            RuntimeKernelScratchRegionWitness::ValueScratch => {
                                KernelWitnessError::ValueScratchPeakExceeded {
                                    peak: bytes,
                                    budget: self.scratch_bytes,
                                }
                            }
                            RuntimeKernelScratchRegionWitness::HashScratch => {
                                KernelWitnessError::HashScratchPeakExceeded {
                                    peak: bytes,
                                    budget: self.scratch_bytes,
                                }
                            }
                            RuntimeKernelScratchRegionWitness::IoScratch => {
                                KernelWitnessError::IoScratchPeakExceeded {
                                    peak: bytes,
                                    budget: self.scratch_bytes,
                                }
                            }
                        });
                    }
                    let usage = state.usage_mut(region);
                    usage.live_bytes = bytes;
                    usage.peak_bytes = usage.peak_bytes.max(bytes);
                }
                RuntimeKernelResourceEventKindWitness::WipeScratch => {
                    let region = event
                        .region
                        .expect("validated wipe-scratch event carries region");
                    let usage = state.usage_mut(region);
                    usage.live_bytes = 0;
                    usage.wipe_count += 1;
                }
            }
        }
        Ok(state)
    }

    fn validate_replayed_resources(
        &self,
        replayed: &RuntimeKernelResourceReplayState,
    ) -> Result<(), KernelWitnessError> {
        self.validate_replayed_usage(
            "peak_stack_words",
            self.peak_stack_words,
            replayed.peak_stack_words,
        )?;
        self.validate_replayed_usage(
            "value_scratch_peak_bytes",
            self.value_scratch_peak_bytes,
            replayed.value_scratch.peak_bytes,
        )?;
        self.validate_replayed_usage(
            "value_scratch_live_bytes_end",
            self.value_scratch_live_bytes_end,
            replayed.value_scratch.live_bytes,
        )?;
        self.validate_replayed_usage(
            "value_scratch_wipe_count",
            self.value_scratch_wipe_count,
            replayed.value_scratch.wipe_count,
        )?;
        self.validate_replayed_usage(
            "hash_scratch_peak_bytes",
            self.hash_scratch_peak_bytes,
            replayed.hash_scratch.peak_bytes,
        )?;
        self.validate_replayed_usage(
            "hash_scratch_live_bytes_end",
            self.hash_scratch_live_bytes_end,
            replayed.hash_scratch.live_bytes,
        )?;
        self.validate_replayed_usage(
            "hash_scratch_wipe_count",
            self.hash_scratch_wipe_count,
            replayed.hash_scratch.wipe_count,
        )?;
        self.validate_replayed_usage(
            "io_scratch_peak_bytes",
            self.io_scratch_peak_bytes,
            replayed.io_scratch.peak_bytes,
        )?;
        self.validate_replayed_usage(
            "io_scratch_live_bytes_end",
            self.io_scratch_live_bytes_end,
            replayed.io_scratch.live_bytes,
        )?;
        self.validate_replayed_usage(
            "io_scratch_wipe_count",
            self.io_scratch_wipe_count,
            replayed.io_scratch.wipe_count,
        )?;
        Ok(())
    }

    fn validate_replayed_usage(
        &self,
        field: &str,
        witnessed: usize,
        replayed: usize,
    ) -> Result<(), KernelWitnessError> {
        if witnessed != replayed {
            return Err(KernelWitnessError::KernelResourceTraceMismatch {
                field: field.into(),
                expected: replayed,
                witnessed,
            });
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("runtime kernel witness is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self).expect("runtime kernel witness is JSON serializable")
    }
}

impl RuntimeKernelStepWitness {
    pub fn new(opcode: UoOpcode, object_id: Option<u32>) -> Result<Self, KernelWitnessError> {
        let step = Self { opcode, object_id };
        step.validate_shape()?;
        Ok(step)
    }

    pub fn projected_opcode(&self) -> UoOpcode {
        self.opcode
    }

    pub fn object_id(&self) -> Option<u32> {
        self.object_id
    }

    pub fn validate_shape(&self) -> Result<(), KernelWitnessError> {
        let has_object = self.object_id.is_some();
        let object_required = matches!(
            self.opcode,
            UoOpcode::CellGet
                | UoOpcode::CellSet
                | UoOpcode::ArrayGet
                | UoOpcode::ArraySet
                | UoOpcode::MapGet
                | UoOpcode::MapPut
        );
        if has_object != object_required {
            return Err(KernelWitnessError::MalformedKernelStepTrace {
                witnessed: vec![self.clone()],
            });
        }
        Ok(())
    }
}

impl From<ConfidentialKernelStep> for RuntimeKernelStepWitness {
    fn from(step: ConfidentialKernelStep) -> Self {
        Self::new(step.opcode, step.object_id)
            .expect("confidential kernel step should satisfy runtime witness shape")
    }
}

impl From<&RuntimeKernelStepManifest> for RuntimeKernelStepWitness {
    fn from(step: &RuntimeKernelStepManifest) -> Self {
        Self::new(step.opcode, step.object_id)
            .expect("manifest kernel step should satisfy runtime witness shape")
    }
}

impl RuntimeKernelResourceEventWitness {
    pub fn stack_check(words: usize) -> Self {
        Self {
            kind: RuntimeKernelResourceEventKindWitness::StackCheck,
            region: None,
            words: Some(words),
            bytes: None,
        }
    }

    pub fn reserve_scratch(region: RuntimeKernelScratchRegionWitness, bytes: usize) -> Self {
        Self {
            kind: RuntimeKernelResourceEventKindWitness::ReserveScratch,
            region: Some(region),
            words: None,
            bytes: Some(bytes),
        }
    }

    pub fn wipe_scratch(region: RuntimeKernelScratchRegionWitness) -> Self {
        Self {
            kind: RuntimeKernelResourceEventKindWitness::WipeScratch,
            region: Some(region),
            words: None,
            bytes: None,
        }
    }

    pub fn kind(&self) -> RuntimeKernelResourceEventKindWitness {
        self.kind
    }

    pub fn region(&self) -> Option<RuntimeKernelScratchRegionWitness> {
        self.region
    }

    pub fn words(&self) -> Option<usize> {
        self.words
    }

    pub fn bytes(&self) -> Option<usize> {
        self.bytes
    }

    pub fn validate_shape(&self) -> Result<(), KernelWitnessError> {
        let shape_valid = match self.kind {
            RuntimeKernelResourceEventKindWitness::StackCheck => {
                self.region.is_none() && self.words.is_some() && self.bytes.is_none()
            }
            RuntimeKernelResourceEventKindWitness::ReserveScratch => {
                self.region.is_some() && self.words.is_none() && self.bytes.is_some()
            }
            RuntimeKernelResourceEventKindWitness::WipeScratch => {
                self.region.is_some() && self.words.is_none() && self.bytes.is_none()
            }
        };
        if !shape_valid {
            return Err(KernelWitnessError::MalformedKernelResourceTrace {
                witnessed: vec![self.clone()],
            });
        }
        Ok(())
    }
}

impl RuntimeKernelResourceReplayState {
    fn usage_mut(
        &mut self,
        region: RuntimeKernelScratchRegionWitness,
    ) -> &mut RuntimeKernelResourceReplayUsage {
        match region {
            RuntimeKernelScratchRegionWitness::ValueScratch => &mut self.value_scratch,
            RuntimeKernelScratchRegionWitness::HashScratch => &mut self.hash_scratch,
            RuntimeKernelScratchRegionWitness::IoScratch => &mut self.io_scratch,
        }
    }
}

impl RuntimeKernelScheduleWitness {
    pub fn new(
        opcodes: Vec<UoOpcode>,
        steps: Vec<RuntimeKernelStepWitness>,
    ) -> Result<Self, KernelWitnessError> {
        let witness = Self { opcodes, steps };
        witness.validate_shape()?;
        Ok(witness)
    }

    pub fn opcodes(&self) -> &[UoOpcode] {
        &self.opcodes
    }

    pub fn steps(&self) -> &[RuntimeKernelStepWitness] {
        &self.steps
    }

    pub fn public_object_schedule(&self) -> Vec<u32> {
        self.steps
            .iter()
            .filter_map(RuntimeKernelStepWitness::object_id)
            .collect()
    }

    pub fn validate_shape(&self) -> Result<(), KernelWitnessError> {
        for step in &self.steps {
            step.validate_shape()?;
        }
        if !self.steps.is_empty() {
            let projected = self
                .steps
                .iter()
                .map(RuntimeKernelStepWitness::projected_opcode)
                .collect::<Vec<_>>();
            if projected != self.opcodes {
                return Err(KernelWitnessError::KernelOpcodeTraceMismatch {
                    expected: projected,
                    witnessed: self.opcodes.clone(),
                });
            }
        }
        Ok(())
    }
}

impl RuntimeKernelScheduleTracker {
    pub fn bind_expected_kernel_steps(
        &mut self,
        expected_kernel_steps: Vec<RuntimeKernelStepWitness>,
    ) -> Result<(), KernelWitnessError> {
        if self.expected_kernel_steps.is_some() {
            return Ok(());
        }
        let Some(begin_step) = expected_kernel_steps.first() else {
            return Err(KernelWitnessError::ExpectedKernelScheduleEmpty);
        };
        if begin_step.projected_opcode() != UoOpcode::Begin || begin_step.object_id().is_some() {
            return Err(KernelWitnessError::ExpectedKernelScheduleMustBegin {
                witnessed: begin_step.clone(),
            });
        }
        self.expected_kernel_step_index = 1;
        self.expected_kernel_steps = Some(expected_kernel_steps);
        Ok(())
    }

    pub fn observe_step(
        &mut self,
        observed: RuntimeKernelStepWitness,
    ) -> Result<(), KernelWitnessError> {
        let Some(expected_kernel_steps) = &self.expected_kernel_steps else {
            return Ok(());
        };
        let Some(expected) = expected_kernel_steps.get(self.expected_kernel_step_index) else {
            return Err(KernelWitnessError::ExpectedKernelScheduleExtraStep { observed });
        };
        if expected != &observed {
            return Err(KernelWitnessError::ExpectedKernelScheduleStepMismatch {
                index: self.expected_kernel_step_index,
                expected: expected.clone(),
                observed,
            });
        }
        self.expected_kernel_step_index += 1;
        Ok(())
    }

    pub fn ensure_expected_kernel_schedule_consumed(&self) -> Result<(), KernelWitnessError> {
        let Some(expected_kernel_steps) = &self.expected_kernel_steps else {
            return Ok(());
        };
        if self.expected_kernel_step_index != expected_kernel_steps.len() {
            return Err(KernelWitnessError::ExpectedKernelScheduleIncomplete {
                observed_steps: self.expected_kernel_step_index,
                expected_steps: expected_kernel_steps.len(),
            });
        }
        Ok(())
    }

    pub fn expected_kernel_steps(&self) -> Option<&[RuntimeKernelStepWitness]> {
        self.expected_kernel_steps.as_deref()
    }
}

impl RuntimeKernelExecutionTracker {
    pub fn with_kernel_op_budget(max_kernel_ops: usize) -> Self {
        Self {
            expected_kernel_schedule: RuntimeKernelScheduleTracker::default(),
            emitted_kernel_steps: Vec::with_capacity(max_kernel_ops.max(1)),
            max_kernel_ops,
        }
    }

    pub fn bind_expected_kernel_steps(
        &mut self,
        expected_kernel_steps: Vec<RuntimeKernelStepWitness>,
    ) -> Result<(), KernelWitnessError> {
        self.expected_kernel_schedule
            .bind_expected_kernel_steps(expected_kernel_steps)
    }

    pub fn record_step(
        &mut self,
        observed: RuntimeKernelStepWitness,
    ) -> Result<(), KernelWitnessError> {
        if self.emitted_kernel_steps.len() >= self.max_kernel_ops {
            return Err(KernelWitnessError::KernelStepBudgetExceeded {
                attempted_steps: self.emitted_kernel_steps.len() + 1,
                budget: self.max_kernel_ops,
            });
        }
        self.expected_kernel_schedule
            .observe_step(observed.clone())?;
        self.emitted_kernel_steps.push(observed);
        Ok(())
    }

    pub fn ensure_expected_kernel_schedule_consumed(&self) -> Result<(), KernelWitnessError> {
        self.expected_kernel_schedule
            .ensure_expected_kernel_schedule_consumed()
    }

    pub fn expected_kernel_steps(&self) -> Option<&[RuntimeKernelStepWitness]> {
        self.expected_kernel_schedule.expected_kernel_steps()
    }

    pub fn emitted_kernel_steps(&self) -> &[RuntimeKernelStepWitness] {
        &self.emitted_kernel_steps
    }

    pub fn into_emitted_kernel_steps(self) -> Vec<RuntimeKernelStepWitness> {
        self.emitted_kernel_steps
    }
}

pub fn max_runtime_kernel_refinement_event_count(
    public_object_count: usize,
    max_kernel_ops: usize,
) -> Result<usize, RuntimeKernelRefinementTrackerError> {
    public_object_count
        .checked_mul(5)
        .and_then(|count| count.checked_add(max_kernel_ops))
        .ok_or(RuntimeKernelRefinementTrackerError::EventCapacityOverflow {
            public_object_count,
            max_kernel_ops,
        })
}

impl RuntimeKernelRefinementTracker {
    pub fn with_public_object_count_and_kernel_ops(
        public_object_count: usize,
        max_kernel_ops: usize,
    ) -> Result<Self, RuntimeKernelRefinementTrackerError> {
        let max_event_count =
            max_runtime_kernel_refinement_event_count(public_object_count, max_kernel_ops)?;
        Ok(Self {
            events: Vec::with_capacity(max_event_count.max(1)),
            max_event_count,
            phase: RuntimeKernelRefinementPhase::BeforeBegin,
        })
    }

    fn push_observed_event(
        &mut self,
        event: RuntimeKernelRefinementEventWitness,
    ) -> Result<(), RuntimeKernelRefinementTrackerError> {
        if self.events.len() >= self.max_event_count {
            return Err(RuntimeKernelRefinementTrackerError::EventCapacityExceeded {
                attempted_events: self.events.len() + 1,
                max_events: self.max_event_count,
            });
        }
        let next_phase =
            runtime_kernel_refinement_phase_step(self.phase, &event).ok_or_else(|| {
                RuntimeKernelRefinementTrackerError::UnexpectedPhaseEvent {
                    phase: self.phase,
                    event: event.clone(),
                }
            })?;
        self.events.push(event);
        self.phase = next_phase;
        Ok(())
    }

    pub fn push_pre_committed_cold_object(
        &mut self,
        object_id: u32,
    ) -> Result<(), RuntimeKernelRefinementTrackerError> {
        self.push_observed_event(
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(object_id),
        )
    }

    pub fn push_shadow_load_object(
        &mut self,
        object_id: u32,
    ) -> Result<(), RuntimeKernelRefinementTrackerError> {
        self.push_observed_event(RuntimeKernelRefinementEventWitness::shadow_load_object(
            object_id,
        ))
    }

    pub fn push_kernel_step(
        &mut self,
        opcode: UoOpcode,
        object_id: Option<u32>,
    ) -> Result<(), RuntimeKernelRefinementTrackerError> {
        self.push_observed_event(RuntimeKernelRefinementEventWitness::kernel_step(
            opcode, object_id,
        ))
    }

    pub fn append_commit_object_schedule<I>(
        &mut self,
        object_ids: I,
    ) -> Result<(), RuntimeKernelRefinementTrackerError>
    where
        I: IntoIterator<Item = u32>,
    {
        if self.phase != RuntimeKernelRefinementPhase::CommitObjectWindow {
            return Err(RuntimeKernelRefinementTrackerError::PhaseMismatch {
                action: "append commit-object schedule",
                observed: self.phase,
                expected: RuntimeKernelRefinementPhase::CommitObjectWindow,
            });
        }
        for object_id in object_ids {
            self.push_observed_event(RuntimeKernelRefinementEventWitness::commit_object(
                object_id,
            ))?;
        }
        Ok(())
    }

    pub fn append_cold_store_window(
        &mut self,
        public_object_ids: &[u32],
    ) -> Result<(), RuntimeKernelRefinementTrackerError> {
        if self.phase != RuntimeKernelRefinementPhase::AfterWipe {
            return Err(RuntimeKernelRefinementTrackerError::PhaseMismatch {
                action: "append cold-store window",
                observed: self.phase,
                expected: RuntimeKernelRefinementPhase::AfterWipe,
            });
        }
        let cold_stored_object_ids = self.shadow_load_object_schedule();
        for object_id in cold_stored_object_ids {
            self.push_observed_event(RuntimeKernelRefinementEventWitness::cold_store_object(
                object_id,
            ))?;
        }
        for object_id in public_object_ids.iter().copied() {
            self.push_observed_event(
                RuntimeKernelRefinementEventWitness::post_committed_cold_object(object_id),
            )?;
        }
        Ok(())
    }

    pub fn shadow_load_object_schedule(&self) -> Vec<u32> {
        self.events
            .iter()
            .filter(|event| {
                event.kind() == RuntimeKernelRefinementEventKindWitness::ShadowLoadObject
            })
            .filter_map(RuntimeKernelRefinementEventWitness::object_id)
            .collect()
    }

    pub fn into_witness(
        self,
    ) -> Result<RuntimeKernelRefinementWitness, RuntimeKernelRefinementTrackerError> {
        RuntimeKernelRefinementWitness::from_events(self.events)
            .map_err(RuntimeKernelRefinementTrackerError::Witness)
    }
}

fn is_canonical_object_id_schedule(object_ids: &[u32]) -> bool {
    object_ids.windows(2).all(|window| window[0] < window[1])
}

impl RuntimeKernelRefinementEventWitness {
    pub fn kind(&self) -> RuntimeKernelRefinementEventKindWitness {
        self.kind
    }

    pub fn pre_committed_cold_object(object_id: u32) -> Self {
        Self {
            kind: RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject,
            object_id: Some(object_id),
            opcode: None,
        }
    }

    pub fn shadow_load_object(object_id: u32) -> Self {
        Self {
            kind: RuntimeKernelRefinementEventKindWitness::ShadowLoadObject,
            object_id: Some(object_id),
            opcode: None,
        }
    }

    pub fn kernel_step(opcode: UoOpcode, object_id: Option<u32>) -> Self {
        Self {
            kind: RuntimeKernelRefinementEventKindWitness::KernelStep,
            object_id,
            opcode: Some(opcode),
        }
    }

    pub fn commit_object(object_id: u32) -> Self {
        Self {
            kind: RuntimeKernelRefinementEventKindWitness::CommitObject,
            object_id: Some(object_id),
            opcode: None,
        }
    }

    pub fn cold_store_object(object_id: u32) -> Self {
        Self {
            kind: RuntimeKernelRefinementEventKindWitness::ColdStoreObject,
            object_id: Some(object_id),
            opcode: None,
        }
    }

    pub fn post_committed_cold_object(object_id: u32) -> Self {
        Self {
            kind: RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject,
            object_id: Some(object_id),
            opcode: None,
        }
    }

    pub fn object_id(&self) -> Option<u32> {
        self.object_id
    }

    pub fn opcode(&self) -> Option<UoOpcode> {
        self.opcode
    }

    pub fn projected_kernel_step(&self) -> Option<RuntimeKernelStepWitness> {
        Some(RuntimeKernelStepWitness {
            opcode: self.opcode?,
            object_id: self.object_id,
        })
    }

    pub fn validate_shape(&self) -> Result<(), RuntimeKernelRefinementWitnessError> {
        let shape_valid = match self.kind {
            RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject
            | RuntimeKernelRefinementEventKindWitness::ShadowLoadObject
            | RuntimeKernelRefinementEventKindWitness::CommitObject
            | RuntimeKernelRefinementEventKindWitness::ColdStoreObject
            | RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject => {
                self.object_id.is_some() && self.opcode.is_none()
            }
            RuntimeKernelRefinementEventKindWitness::KernelStep => {
                let Some(step) = self.projected_kernel_step() else {
                    return Err(
                        RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                            witnessed: vec![self.clone()],
                        },
                    );
                };
                step.validate_shape().is_ok()
            }
        };
        if !shape_valid {
            return Err(
                RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                    witnessed: vec![self.clone()],
                },
            );
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RuntimeKernelRefinementPhase {
    BeforeBegin,
    PreCommittedColdWindow,
    ShadowLoadWindow,
    ActiveKernel,
    CommitObjectWindow,
    AfterWipe,
    ColdStoreWindow,
    PostCommittedColdWindow,
}

pub fn runtime_kernel_refinement_phase_step(
    phase: RuntimeKernelRefinementPhase,
    event: &RuntimeKernelRefinementEventWitness,
) -> Option<RuntimeKernelRefinementPhase> {
    event.validate_shape().ok()?;
    match event.kind() {
        RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject => match phase {
            RuntimeKernelRefinementPhase::BeforeBegin
            | RuntimeKernelRefinementPhase::PreCommittedColdWindow => {
                Some(RuntimeKernelRefinementPhase::PreCommittedColdWindow)
            }
            _ => None,
        },
        RuntimeKernelRefinementEventKindWitness::ShadowLoadObject => {
            (phase == RuntimeKernelRefinementPhase::ShadowLoadWindow).then_some(phase)
        }
        RuntimeKernelRefinementEventKindWitness::CommitObject => {
            (phase == RuntimeKernelRefinementPhase::CommitObjectWindow).then_some(phase)
        }
        RuntimeKernelRefinementEventKindWitness::ColdStoreObject => match phase {
            RuntimeKernelRefinementPhase::AfterWipe
            | RuntimeKernelRefinementPhase::ColdStoreWindow => {
                Some(RuntimeKernelRefinementPhase::ColdStoreWindow)
            }
            _ => None,
        },
        RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject => match phase {
            RuntimeKernelRefinementPhase::AfterWipe
            | RuntimeKernelRefinementPhase::ColdStoreWindow
            | RuntimeKernelRefinementPhase::PostCommittedColdWindow => {
                Some(RuntimeKernelRefinementPhase::PostCommittedColdWindow)
            }
            _ => None,
        },
        RuntimeKernelRefinementEventKindWitness::KernelStep => {
            let step = event.projected_kernel_step()?;
            match (phase, step.opcode) {
                (RuntimeKernelRefinementPhase::BeforeBegin, UoOpcode::Begin)
                | (RuntimeKernelRefinementPhase::PreCommittedColdWindow, UoOpcode::Begin) => {
                    Some(RuntimeKernelRefinementPhase::ShadowLoadWindow)
                }
                (RuntimeKernelRefinementPhase::ShadowLoadWindow, UoOpcode::Commit) => {
                    Some(RuntimeKernelRefinementPhase::CommitObjectWindow)
                }
                (RuntimeKernelRefinementPhase::ShadowLoadWindow, UoOpcode::Wipe) => None,
                (RuntimeKernelRefinementPhase::ShadowLoadWindow, _) => {
                    Some(RuntimeKernelRefinementPhase::ActiveKernel)
                }
                (RuntimeKernelRefinementPhase::ActiveKernel, UoOpcode::Commit) => {
                    Some(RuntimeKernelRefinementPhase::CommitObjectWindow)
                }
                (RuntimeKernelRefinementPhase::ActiveKernel, UoOpcode::Wipe) => None,
                (RuntimeKernelRefinementPhase::ActiveKernel, UoOpcode::Begin) => None,
                (RuntimeKernelRefinementPhase::ActiveKernel, _) => {
                    Some(RuntimeKernelRefinementPhase::ActiveKernel)
                }
                (RuntimeKernelRefinementPhase::CommitObjectWindow, UoOpcode::Wipe) => {
                    Some(RuntimeKernelRefinementPhase::AfterWipe)
                }
                _ => None,
            }
        }
    }
}

impl RuntimeKernelRefinementWitness {
    pub fn from_events(
        events: Vec<RuntimeKernelRefinementEventWitness>,
    ) -> Result<Self, RuntimeKernelRefinementWitnessError> {
        let witness = Self { events };
        witness.replay_phase()?;
        Ok(witness)
    }

    pub fn events(&self) -> &[RuntimeKernelRefinementEventWitness] {
        &self.events
    }

    pub fn event_count(&self) -> usize {
        self.events.len()
    }

    pub fn first_event(&self) -> Option<&RuntimeKernelRefinementEventWitness> {
        self.events.first()
    }

    pub fn last_event(&self) -> Option<&RuntimeKernelRefinementEventWitness> {
        self.events.last()
    }

    fn replay_phase(
        &self,
    ) -> Result<RuntimeKernelRefinementPhase, RuntimeKernelRefinementWitnessError> {
        let mut phase = RuntimeKernelRefinementPhase::BeforeBegin;
        for event in &self.events {
            phase = runtime_kernel_refinement_phase_step(phase, event).ok_or_else(|| {
                RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                    witnessed: self.events.clone(),
                }
            })?;
        }
        Ok(phase)
    }

    #[cfg(test)]
    #[allow(dead_code)]
    fn append_commit_object_schedule<I>(
        &mut self,
        object_ids: I,
    ) -> Result<(), RuntimeKernelRefinementWitnessError>
    where
        I: IntoIterator<Item = u32>,
    {
        if self.replay_phase()? != RuntimeKernelRefinementPhase::CommitObjectWindow {
            return Err(
                RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                    witnessed: self.events.clone(),
                },
            );
        }
        self.events.extend(
            object_ids
                .into_iter()
                .map(RuntimeKernelRefinementEventWitness::commit_object),
        );
        Ok(())
    }

    #[cfg(test)]
    #[allow(dead_code)]
    fn append_cold_store_window(
        &mut self,
        public_object_ids: &[u32],
    ) -> Result<(), RuntimeKernelRefinementWitnessError> {
        if self.replay_phase()? != RuntimeKernelRefinementPhase::AfterWipe {
            return Err(
                RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                    witnessed: self.events.clone(),
                },
            );
        }
        let cold_stored_object_ids = self.shadow_load_object_schedule();
        self.events.extend(
            cold_stored_object_ids
                .into_iter()
                .map(RuntimeKernelRefinementEventWitness::cold_store_object),
        );
        self.events.extend(
            public_object_ids
                .iter()
                .copied()
                .map(RuntimeKernelRefinementEventWitness::post_committed_cold_object),
        );
        Ok(())
    }

    pub fn projected_kernel_schedule(&self) -> RuntimeKernelScheduleWitness {
        let steps = self
            .events
            .iter()
            .filter_map(RuntimeKernelRefinementEventWitness::projected_kernel_step)
            .collect::<Vec<_>>();
        RuntimeKernelScheduleWitness::new(
            steps
                .iter()
                .map(RuntimeKernelStepWitness::projected_opcode)
                .collect(),
            steps,
        )
        .expect(
            "projected kernel schedule derived from validated events must satisfy shape invariants",
        )
    }

    pub fn shadow_load_object_schedule(&self) -> Vec<u32> {
        self.events
            .iter()
            .filter(|event| event.kind == RuntimeKernelRefinementEventKindWitness::ShadowLoadObject)
            .filter_map(|event| event.object_id)
            .collect()
    }

    pub fn pre_committed_cold_object_schedule(&self) -> Vec<u32> {
        self.events
            .iter()
            .filter(|event| {
                event.kind == RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject
            })
            .filter_map(|event| event.object_id)
            .collect()
    }

    pub fn commit_object_schedule(&self) -> Vec<u32> {
        self.events
            .iter()
            .filter(|event| event.kind == RuntimeKernelRefinementEventKindWitness::CommitObject)
            .filter_map(|event| event.object_id)
            .collect()
    }

    pub fn cold_store_object_schedule(&self) -> Vec<u32> {
        self.events
            .iter()
            .filter(|event| event.kind == RuntimeKernelRefinementEventKindWitness::ColdStoreObject)
            .filter_map(|event| event.object_id)
            .collect()
    }

    pub fn post_committed_cold_object_schedule(&self) -> Vec<u32> {
        self.events
            .iter()
            .filter(|event| {
                event.kind == RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject
            })
            .filter_map(|event| event.object_id)
            .collect()
    }

    pub fn validate_with_kernel_witness(
        &self,
        kernel_witness: &RuntimeKernelWitness,
    ) -> Result<(), RuntimeKernelRefinementWitnessError> {
        let phase = self.replay_phase()?;
        if !matches!(
            phase,
            RuntimeKernelRefinementPhase::AfterWipe
                | RuntimeKernelRefinementPhase::ColdStoreWindow
                | RuntimeKernelRefinementPhase::PostCommittedColdWindow
        ) {
            return Err(
                RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                    witnessed: self.events.clone(),
                },
            );
        }
        let projected = self.projected_kernel_schedule();
        if projected.steps() != kernel_witness.kernel_steps {
            return Err(
                RuntimeKernelRefinementWitnessError::KernelProjectionMismatch {
                    expected: kernel_witness.kernel_steps.clone(),
                    witnessed: projected.steps().to_vec(),
                },
            );
        }
        let loaded = self.shadow_load_object_schedule();
        let committed = self.commit_object_schedule();
        let cold_stored = self.cold_store_object_schedule();
        if loaded != committed || loaded != cold_stored {
            return Err(
                RuntimeKernelRefinementWitnessError::ObjectScheduleMismatch {
                    loaded,
                    committed,
                    cold_stored,
                },
            );
        }
        let canonical_loaded_objects = kernel_witness.canonical_loaded_object_schedule();
        if loaded != canonical_loaded_objects {
            return Err(
                RuntimeKernelRefinementWitnessError::CanonicalObjectScheduleMismatch {
                    expected: canonical_loaded_objects,
                    witnessed: loaded,
                },
            );
        }
        let pre_committed_cold = self.pre_committed_cold_object_schedule();
        if pre_committed_cold != kernel_witness.public_object_ids {
            return Err(
                RuntimeKernelRefinementWitnessError::PreCommittedColdObjectScheduleMismatch {
                    expected: kernel_witness.public_object_ids.clone(),
                    witnessed: pre_committed_cold,
                },
            );
        }
        let post_committed_cold = self.post_committed_cold_object_schedule();
        if post_committed_cold != kernel_witness.public_object_ids {
            return Err(
                RuntimeKernelRefinementWitnessError::PostCommittedColdObjectScheduleMismatch {
                    expected: kernel_witness.public_object_ids.clone(),
                    witnessed: post_committed_cold,
                },
            );
        }
        let kernel_objects = kernel_witness
            .kernel_steps
            .iter()
            .filter_map(|step| step.object_id)
            .collect::<Vec<_>>();
        let loaded_objects = self.shadow_load_object_schedule();
        let loaded_set = loaded_objects.iter().copied().collect::<BTreeSet<_>>();
        if kernel_objects
            .iter()
            .any(|object_id| !loaded_set.contains(object_id))
        {
            return Err(
                RuntimeKernelRefinementWitnessError::KernelObjectCoverageMismatch {
                    kernel_objects,
                    loaded_objects,
                },
            );
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("runtime kernel refinement witness is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("runtime kernel refinement witness is JSON serializable")
    }
}

impl RuntimeKernelWitness {
    pub fn emitted_public_object_schedule(&self) -> Vec<u32> {
        self.public_object_ids.clone()
    }

    pub fn canonical_loaded_object_schedule(&self) -> Vec<u32> {
        self.kernel_steps
            .iter()
            .filter_map(|step| step.object_id)
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect()
    }

    pub fn expected_public_object_schedule(&self) -> Option<Vec<u32>> {
        self.expected_public_object_ids.clone()
    }
}

pub fn canonical_runtime_public_object_ids(state: &[StateObject]) -> Vec<u32> {
    state
        .iter()
        .map(|object| object.id)
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn manifest_kernel_steps_as_witness(
    steps: &[RuntimeKernelStepManifest],
) -> Vec<RuntimeKernelStepWitness> {
    steps.iter().map(RuntimeKernelStepWitness::from).collect()
}

impl RuntimePathOramHiddenCertificate {
    pub fn trace(&self) -> &RefinementTrace {
        &self.trace
    }

    pub fn oram_objects(&self) -> &[RuntimeOramObjectWitness] {
        &self.oram_objects
    }

    pub fn oram_leaf_public_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.oram_leaf_public_scaffold
    }

    pub fn oram_leaf_schedule(&self) -> &[RuntimeOramLeafWitness] {
        &self.oram_leaf_schedule
    }

    pub fn oram_position_map_before(&self) -> &[RuntimePathOramPositionMapWitness] {
        &self.oram_position_map_before
    }

    pub fn oram_position_map_after(&self) -> &[RuntimePathOramPositionMapWitness] {
        &self.oram_position_map_after
    }

    pub fn oram_leaf_state_transitions(&self) -> &[RuntimePathOramTransitionWitness] {
        &self.oram_leaf_state_transitions
    }

    fn new(
        trace: RefinementTrace,
        oram_objects: Vec<RuntimeOramObjectWitness>,
        oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
        oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
        oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
        oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
    ) -> Result<Self, RefinementWitnessError> {
        let physical_writes = refinement_physical_writes_as_shape_events(&trace)?;
        let oram_leaf_public_scaffold = validate_path_oram_leaf_schedule(
            &oram_leaf_schedule,
            &trace.logical_accesses,
            &trace.physical_reads,
            &physical_writes,
            &oram_objects,
        )?;
        validate_path_oram_leaf_state(
            &oram_leaf_schedule,
            &oram_leaf_state_transitions,
            &oram_position_map_before,
            &oram_position_map_after,
            &oram_objects,
        )?;
        Ok(Self {
            trace,
            oram_objects,
            oram_leaf_public_scaffold,
            oram_leaf_schedule,
            oram_position_map_before,
            oram_position_map_after,
            oram_leaf_state_transitions,
        })
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .expect("runtime path-ORAM hidden certificate is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("runtime path-ORAM hidden certificate is JSON serializable")
    }

    pub fn validate(&self) -> Result<(), RefinementWitnessError> {
        let physical_writes = refinement_physical_writes_as_shape_events(&self.trace)?;
        let scaffold = validate_path_oram_leaf_schedule(
            &self.oram_leaf_schedule,
            &self.trace.logical_accesses,
            &self.trace.physical_reads,
            &physical_writes,
            &self.oram_objects,
        )?;
        if scaffold != self.oram_leaf_public_scaffold {
            return Err(RefinementWitnessError::OramLeafScheduleMismatch);
        }
        validate_path_oram_leaf_state(
            &self.oram_leaf_schedule,
            &self.oram_leaf_state_transitions,
            &self.oram_position_map_before,
            &self.oram_position_map_after,
            &self.oram_objects,
        )?;
        Ok(())
    }
}

fn refinement_physical_writes_as_shape_events(
    trace: &RefinementTrace,
) -> Result<Vec<PhysicalWriteEvent>, RefinementWitnessError> {
    trace
        .physical_writes
        .iter()
        .map(|event| {
            let class = match event.write_class.as_str() {
                "Set" => WriteClass::Set,
                "Clear" => WriteClass::Clear,
                "Same" => WriteClass::Same,
                "Update" => WriteClass::Update,
                _ => return Err(RefinementWitnessError::OramLeafScheduleMismatch),
            };
            Ok(PhysicalWriteEvent::from_shape(
                event.object.clone(),
                event.location.clone(),
                event.len,
                class,
            ))
        })
        .collect()
}

fn validate_seeded_runtime_witnesses(
    seed_count: usize,
    witnesses: &[RuntimeRefinementWitness],
) -> Result<(), SeededRuntimeWitnessFamilyError> {
    if seed_count != witnesses.len() {
        return Err(SeededRuntimeWitnessFamilyError::SeedCountMismatch {
            seed_count,
            witness_count: witnesses.len(),
        });
    }
    for (index, witness) in witnesses.iter().enumerate() {
        let expected_seed = u64::try_from(index)
            .map_err(|_| SeededRuntimeWitnessFamilyError::SeedIndexTooLarge { index })?;
        match witness.runtime_seed {
            Some(seed) if seed == expected_seed => {}
            Some(tagged_seed) => {
                return Err(SeededRuntimeWitnessFamilyError::SeedTagMismatch { index, tagged_seed })
            }
            None => return Err(SeededRuntimeWitnessFamilyError::MissingSeedTag { index }),
        }
    }
    Ok(())
}

impl SeededRuntimeWitnessFamily {
    pub fn seed_count(&self) -> usize {
        self.seed_count
    }

    pub fn witnesses(&self) -> &[RuntimeRefinementWitness] {
        &self.witnesses
    }

    pub fn new(
        witnesses: Vec<RuntimeRefinementWitness>,
    ) -> Result<Self, SeededRuntimeWitnessFamilyError> {
        let family = Self {
            seed_count: witnesses.len(),
            witnesses,
        };
        family.validate()?;
        Ok(family)
    }

    pub fn validate(&self) -> Result<(), SeededRuntimeWitnessFamilyError> {
        validate_seeded_runtime_witnesses(self.seed_count, &self.witnesses)
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("seeded runtime witness family is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("seeded runtime witness family is JSON serializable")
    }
}

impl SeededRuntimePathOramWitnessFamily {
    pub fn seed_count(&self) -> usize {
        self.seed_count
    }

    pub fn witnesses(&self) -> &[RuntimeRefinementWitness] {
        &self.witnesses
    }

    pub fn public_leaf_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.public_leaf_scaffold
    }

    pub fn new(
        witnesses: Vec<RuntimeRefinementWitness>,
    ) -> Result<Self, SeededRuntimeWitnessFamilyError> {
        let public_leaf_scaffold = witnesses
            .first()
            .map(|witness| witness.oram_leaf_public_scaffold.clone())
            .unwrap_or_default();
        let family = Self {
            seed_count: witnesses.len(),
            witnesses,
            public_leaf_scaffold,
        };
        family.validate()?;
        Ok(family)
    }

    pub fn validate(&self) -> Result<(), SeededRuntimeWitnessFamilyError> {
        validate_seeded_runtime_witnesses(self.seed_count, &self.witnesses)?;
        for (index, witness) in self.witnesses.iter().enumerate() {
            if witness.oram_leaf_public_scaffold != self.public_leaf_scaffold {
                return Err(SeededRuntimeWitnessFamilyError::PublicLeafScaffoldMismatch { index });
            }
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .expect("seeded path-ORAM runtime witness family is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("seeded path-ORAM runtime witness family is JSON serializable")
    }
}

impl SeededRuntimePaperMainFamilyBundle {
    pub fn family(&self) -> &SeededRuntimePathOramWitnessFamily {
        &self.family
    }

    pub fn public_outcome(&self) -> &PublicOutcomeTrace {
        &self.public_outcome
    }

    pub fn boundary_schedule(&self) -> &[BoundaryEvent] {
        &self.boundary_schedule
    }

    pub fn new(
        family: SeededRuntimePathOramWitnessFamily,
    ) -> Result<Self, SeededRuntimePaperMainFamilyBundleError> {
        let first_witness = family
            .witnesses()
            .first()
            .ok_or(SeededRuntimePaperMainFamilyBundleError::EmptyFamily)?;
        let public_outcome = first_witness.public_outcome().clone();
        let boundary_schedule = first_witness.boundary_schedule().to_vec();
        let bundle = Self {
            family,
            public_outcome,
            boundary_schedule,
        };
        bundle.validate()?;
        Ok(bundle)
    }

    pub fn validate(&self) -> Result<(), SeededRuntimePaperMainFamilyBundleError> {
        self.family
            .validate()
            .map_err(SeededRuntimePaperMainFamilyBundleError::Family)?;
        if self.family.witnesses().is_empty() {
            return Err(SeededRuntimePaperMainFamilyBundleError::EmptyFamily);
        }
        for (index, witness) in self.family.witnesses().iter().enumerate() {
            if witness.public_outcome() != &self.public_outcome {
                return Err(
                    SeededRuntimePaperMainFamilyBundleError::PublicOutcomeMismatch { index },
                );
            }
            if witness.boundary_schedule() != self.boundary_schedule.as_slice() {
                return Err(
                    SeededRuntimePaperMainFamilyBundleError::BoundaryScheduleMismatch { index },
                );
            }
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .expect("seeded runtime paper-main family bundle is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("seeded runtime paper-main family bundle is JSON serializable")
    }
}

impl SeededRuntimePaperMainSlotFamilyBundle {
    pub fn family(&self) -> &SeededRuntimePathOramWitnessFamily {
        &self.family
    }

    pub fn public_outcome(&self) -> &PublicOutcomeTrace {
        &self.public_outcome
    }

    pub fn boundary_schedule(&self) -> &[BoundaryEvent] {
        &self.boundary_schedule
    }

    pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {
        &self.confidential_slot_program
    }

    pub fn new(
        family: SeededRuntimePathOramWitnessFamily,
        confidential_slot_program: ConfidentialKernelSlotProgram,
    ) -> Result<Self, SeededRuntimePaperMainSlotFamilyBundleError> {
        let paper_main_bundle = SeededRuntimePaperMainFamilyBundle::new(family.clone())
            .map_err(SeededRuntimePaperMainSlotFamilyBundleError::Family)?;
        let bundle = Self {
            family,
            public_outcome: paper_main_bundle.public_outcome.clone(),
            boundary_schedule: paper_main_bundle.boundary_schedule.clone(),
            confidential_slot_program,
        };
        bundle.validate()?;
        Ok(bundle)
    }

    pub fn validate(&self) -> Result<(), SeededRuntimePaperMainSlotFamilyBundleError> {
        SeededRuntimePaperMainFamilyBundle::new(self.family.clone())
            .map_err(SeededRuntimePaperMainSlotFamilyBundleError::Family)?;
        let expected_entrypoint = &self.public_outcome.entrypoint_id;
        if &self.confidential_slot_program.entrypoint_id != expected_entrypoint {
            return Err(
                SeededRuntimePaperMainSlotFamilyBundleError::SlotProgramEntrypointMismatch {
                    expected_entrypoint: expected_entrypoint.clone(),
                    program_entrypoint: self.confidential_slot_program.entrypoint_id.clone(),
                },
            );
        }
        if !self.confidential_slot_program.is_runtime_normal_form() {
            return Err(
                SeededRuntimePaperMainSlotFamilyBundleError::SlotProgramNotRuntimeNormalForm {
                    entrypoint: expected_entrypoint.clone(),
                },
            );
        }
        let expected_kernel_steps = self
            .confidential_slot_program
            .expected_runtime_step_witnesses();
        for (index, witness) in self.family.witnesses().iter().enumerate() {
            let kernel_witness = witness.kernel_witness().ok_or(
                SeededRuntimePaperMainSlotFamilyBundleError::MissingKernelWitness { index },
            )?;
            if kernel_witness.expected_kernel_steps() != Some(expected_kernel_steps.as_slice()) {
                return Err(
                    SeededRuntimePaperMainSlotFamilyBundleError::ExpectedKernelStepsMismatch {
                        index,
                    },
                );
            }
            if kernel_witness.kernel_steps() != expected_kernel_steps.as_slice() {
                return Err(
                    SeededRuntimePaperMainSlotFamilyBundleError::EmittedKernelStepsMismatch {
                        index,
                    },
                );
            }
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .expect("seeded runtime paper-main slot family bundle is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("seeded runtime paper-main slot family bundle is JSON serializable")
    }
}

impl CanonicalFreshCoinRuntimePathOramWitnessFamily {
    pub fn seed_count(&self) -> usize {
        self.seed_count
    }

    pub fn witnesses(&self) -> &[RuntimeRefinementWitness] {
        &self.witnesses
    }

    pub fn public_leaf_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.public_leaf_scaffold
    }

    pub fn public_fresh_coin_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.public_fresh_coin_scaffold
    }

    pub fn new(
        witnesses: Vec<RuntimeRefinementWitness>,
    ) -> Result<Self, CanonicalFreshCoinWitnessFamilyError> {
        let public_leaf_scaffold = witnesses
            .first()
            .map(|witness| witness.oram_leaf_public_scaffold.clone())
            .unwrap_or_default();
        let public_fresh_coin_scaffold = witnesses
            .first()
            .and_then(RuntimeRefinementWitness::path_oram_fresh_coin_scaffold)
            .unwrap_or_default();
        let family = Self {
            seed_count: witnesses.len(),
            witnesses,
            public_leaf_scaffold,
            public_fresh_coin_scaffold,
        };
        family.validate()?;
        Ok(family)
    }

    pub fn from_unordered_witnesses(
        witnesses: Vec<RuntimeRefinementWitness>,
    ) -> Result<Self, CanonicalFreshCoinWitnessFamilyError> {
        let public_leaf_scaffold = witnesses
            .first()
            .map(|witness| witness.oram_leaf_public_scaffold.clone())
            .unwrap_or_default();
        let public_fresh_coin_scaffold = witnesses
            .first()
            .and_then(RuntimeRefinementWitness::path_oram_fresh_coin_scaffold)
            .unwrap_or_default();
        let canonical_seed_count =
            canonical_path_oram_leaf_seed_space_size(&public_fresh_coin_scaffold)
                .ok_or(CanonicalFreshCoinWitnessFamilyError::CanonicalSeedSpaceOverflow)?;
        let mut by_seed = vec![None; canonical_seed_count];

        for (index, witness) in witnesses.into_iter().enumerate() {
            if witness.oram_leaf_public_scaffold != public_leaf_scaffold {
                return Err(
                    CanonicalFreshCoinWitnessFamilyError::PublicLeafScaffoldMismatch { index },
                );
            }
            let extracted_scaffold = witness.path_oram_fresh_coin_scaffold().ok_or(
                CanonicalFreshCoinWitnessFamilyError::FreshCoinScaffoldExtractionMismatch { index },
            )?;
            if extracted_scaffold != public_fresh_coin_scaffold {
                return Err(
                    CanonicalFreshCoinWitnessFamilyError::FreshCoinScaffoldMismatch { index },
                );
            }
            let extracted_values = witness.path_oram_fresh_coin_values().ok_or(
                CanonicalFreshCoinWitnessFamilyError::FreshCoinValuesExtractionMismatch { index },
            )?;
            let seed = canonical_path_oram_seed_of_leaf_values(
                &public_fresh_coin_scaffold,
                &extracted_values,
            )
            .ok_or(
                CanonicalFreshCoinWitnessFamilyError::CanonicalFreshCoinValuesMismatch { index },
            )?;
            if seed >= canonical_seed_count {
                return Err(
                    CanonicalFreshCoinWitnessFamilyError::CanonicalFreshCoinValuesMismatch {
                        index,
                    },
                );
            }
            if by_seed[seed].is_some() {
                return Err(CanonicalFreshCoinWitnessFamilyError::DuplicateCanonicalSeed { seed });
            }
            by_seed[seed] = Some(witness);
        }

        let mut ordered = Vec::with_capacity(canonical_seed_count);
        for (seed, witness) in by_seed.into_iter().enumerate() {
            match witness {
                Some(witness) => ordered.push(witness),
                None => {
                    return Err(CanonicalFreshCoinWitnessFamilyError::MissingCanonicalSeed { seed })
                }
            }
        }
        Self::new(ordered)
    }

    pub fn validate(&self) -> Result<(), CanonicalFreshCoinWitnessFamilyError> {
        if self.seed_count != self.witnesses.len() {
            return Err(CanonicalFreshCoinWitnessFamilyError::SeedCountMismatch {
                seed_count: self.seed_count,
                witness_count: self.witnesses.len(),
            });
        }
        let canonical_seed_count =
            canonical_path_oram_leaf_seed_space_size(&self.public_fresh_coin_scaffold)
                .ok_or(CanonicalFreshCoinWitnessFamilyError::CanonicalSeedSpaceOverflow)?;
        if self.seed_count != canonical_seed_count {
            return Err(
                CanonicalFreshCoinWitnessFamilyError::CanonicalSeedCountMismatch {
                    seed_count: self.seed_count,
                    canonical_seed_count,
                },
            );
        }
        for (index, witness) in self.witnesses.iter().enumerate() {
            if witness.oram_leaf_public_scaffold != self.public_leaf_scaffold {
                return Err(
                    CanonicalFreshCoinWitnessFamilyError::PublicLeafScaffoldMismatch { index },
                );
            }
            let extracted_scaffold = witness.path_oram_fresh_coin_scaffold().ok_or(
                CanonicalFreshCoinWitnessFamilyError::FreshCoinScaffoldExtractionMismatch { index },
            )?;
            if extracted_scaffold != self.public_fresh_coin_scaffold {
                return Err(
                    CanonicalFreshCoinWitnessFamilyError::FreshCoinScaffoldMismatch { index },
                );
            }
            let extracted_values = witness.path_oram_fresh_coin_values().ok_or(
                CanonicalFreshCoinWitnessFamilyError::FreshCoinValuesExtractionMismatch { index },
            )?;
            if extracted_values
                != canonical_path_oram_leaf_values_of_seed(&self.public_fresh_coin_scaffold, index)
            {
                return Err(
                    CanonicalFreshCoinWitnessFamilyError::CanonicalFreshCoinValuesMismatch {
                        index,
                    },
                );
            }
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .expect("canonical fresh-coin path-ORAM runtime witness family is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("canonical fresh-coin path-ORAM runtime witness family is JSON serializable")
    }
}

impl CanonicalFreshCoinRuntimePathOramTheoremInput {
    pub fn seed_count(&self) -> usize {
        self.seed_count
    }

    pub fn representative_seed(&self) -> usize {
        self.representative_seed
    }

    pub fn representative_witness(&self) -> &RuntimeRefinementWitness {
        &self.representative_witness
    }

    pub fn public_leaf_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.public_leaf_scaffold
    }

    pub fn public_fresh_coin_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {
        &self.public_fresh_coin_scaffold
    }

    pub fn new(
        representative_seed: usize,
        representative_witness: RuntimeRefinementWitness,
    ) -> Result<Self, CanonicalFreshCoinTheoremInputError> {
        let public_leaf_scaffold = representative_witness.oram_leaf_public_scaffold.clone();
        let public_fresh_coin_scaffold = representative_witness
            .path_oram_fresh_coin_scaffold()
            .ok_or(CanonicalFreshCoinTheoremInputError::FreshCoinScaffoldExtractionMismatch)?;
        let seed_count = canonical_path_oram_leaf_seed_space_size(&public_fresh_coin_scaffold)
            .ok_or(CanonicalFreshCoinTheoremInputError::CanonicalSeedSpaceOverflow)?;
        let theorem_input = Self {
            seed_count,
            representative_seed,
            representative_witness,
            public_leaf_scaffold,
            public_fresh_coin_scaffold,
        };
        theorem_input.validate()?;
        Ok(theorem_input)
    }

    pub fn validate(&self) -> Result<(), CanonicalFreshCoinTheoremInputError> {
        let canonical_seed_count =
            canonical_path_oram_leaf_seed_space_size(&self.public_fresh_coin_scaffold)
                .ok_or(CanonicalFreshCoinTheoremInputError::CanonicalSeedSpaceOverflow)?;
        if self.seed_count != canonical_seed_count {
            return Err(
                CanonicalFreshCoinTheoremInputError::CanonicalSeedCountMismatch {
                    seed_count: self.seed_count,
                    canonical_seed_count,
                },
            );
        }
        if self.representative_seed >= self.seed_count {
            return Err(
                CanonicalFreshCoinTheoremInputError::RepresentativeSeedOutOfRange {
                    representative_seed: self.representative_seed,
                    seed_count: self.seed_count,
                },
            );
        }
        if self.representative_witness.oram_leaf_public_scaffold != self.public_leaf_scaffold {
            return Err(CanonicalFreshCoinTheoremInputError::PublicLeafScaffoldMismatch);
        }
        let extracted_scaffold = self
            .representative_witness
            .path_oram_fresh_coin_scaffold()
            .ok_or(CanonicalFreshCoinTheoremInputError::FreshCoinScaffoldExtractionMismatch)?;
        if extracted_scaffold != self.public_fresh_coin_scaffold {
            return Err(CanonicalFreshCoinTheoremInputError::FreshCoinScaffoldMismatch);
        }
        let extracted_values = self
            .representative_witness
            .path_oram_fresh_coin_values()
            .ok_or(CanonicalFreshCoinTheoremInputError::FreshCoinValuesExtractionMismatch)?;
        if extracted_values
            != canonical_path_oram_leaf_values_of_seed(
                &self.public_fresh_coin_scaffold,
                self.representative_seed,
            )
        {
            return Err(
                CanonicalFreshCoinTheoremInputError::CanonicalFreshCoinValuesMismatch {
                    representative_seed: self.representative_seed,
                },
            );
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .expect("canonical fresh-coin path-ORAM theorem input is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("canonical fresh-coin path-ORAM theorem input is JSON serializable")
    }
}

const METADATA_REGION: &str = "metadata";
const POSITION_MAP_REGION: &str = "position_map";
const PATH_REGION: &str = "path";
const STASH_REGION: &str = "stash";

impl RuntimeOramObjectWitness {
    pub fn access_witness(&self) -> RuntimeOramAccessWitness {
        RuntimeOramAccessWitness {
            object_id: self.object_id,
            scheme: self.scheme.clone(),
            metadata_pages_per_access: self.metadata_pages_per_access,
            buckets_per_access: self.buckets_per_access,
            recursion_depth: self.recursion_depth,
            stash_bound: self.stash_bound,
        }
    }

    fn metadata_event_kind(&self) -> Result<&'static str, RefinementWitnessError> {
        match self.scheme.as_str() {
            SURROGATE_ORAM_SCHEME => Ok("uooram_meta_scan"),
            PATH_ORAM_SCHEME => Ok("uooram_metadata_load"),
            other => Err(RefinementWitnessError::UnsupportedOramScheme {
                scheme: other.into(),
            }),
        }
    }

    fn bucket_event_kind(&self) -> Result<&'static str, RefinementWitnessError> {
        match self.scheme.as_str() {
            SURROGATE_ORAM_SCHEME => Ok("uooram_bucket_scan"),
            PATH_ORAM_SCHEME => Ok("uooram_path_read"),
            other => Err(RefinementWitnessError::UnsupportedOramScheme {
                scheme: other.into(),
            }),
        }
    }
}

impl RuntimeControllerCertificate {
    pub fn new(
        entry_input_len: usize,
        observed_oram_accesses: Vec<RuntimeOramAccessWitness>,
    ) -> Self {
        Self {
            entry_input_len,
            observed_oram_accesses,
        }
    }

    pub fn entry_input_len(&self) -> usize {
        self.entry_input_len
    }

    pub fn observed_oram_accesses(&self) -> &[RuntimeOramAccessWitness] {
        &self.observed_oram_accesses
    }

    pub fn boundary_schedule(&self, public_outcome: &PublicOutcomeTrace) -> Vec<BoundaryEvent> {
        let mut schedule = Vec::with_capacity(2 * self.observed_oram_accesses.len() + 2);
        schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Enter,
            api_id: public_outcome.entrypoint_id.clone(),
            input_len: self.entry_input_len,
            output_len: 0,
        });
        for _ in &self.observed_oram_accesses {
            schedule.push(BoundaryEvent {
                direction: BoundaryDirection::Exit,
                api_id: "oram_access".into(),
                input_len: 0,
                output_len: 0,
            });
            schedule.push(BoundaryEvent {
                direction: BoundaryDirection::Enter,
                api_id: "oram_access".into(),
                input_len: 0,
                output_len: 0,
            });
        }
        schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Exit,
            api_id: public_outcome.entrypoint_id.clone(),
            input_len: 0,
            output_len: public_outcome.output_shape.return_length,
        });
        schedule
    }

    pub fn controller_shape(&self) -> SgxControllerShapeTrace {
        let mut controller_phase_order = vec![ControllerPhase::EnclaveEnter];
        let mut metadata_budget = 0usize;
        let mut position_map_budget = 0usize;
        let mut path_budget = 0usize;
        let mut stash_budget = 0usize;
        let mut metadata_workset = 0usize;
        let mut position_map_workset = 0usize;
        let mut path_workset = 0usize;
        let mut stash_workset = 0usize;
        let mut recursive_position_map_depth = 0usize;
        let mut stash_bound = 0usize;

        for access in &self.observed_oram_accesses {
            controller_phase_order.push(ControllerPhase::StageRequest);
            controller_phase_order.extend(std::iter::repeat_n(
                ControllerPhase::DescendPositionMap,
                access.recursion_depth,
            ));
            controller_phase_order.extend([
                ControllerPhase::LoadMetadata,
                ControllerPhase::FetchPath,
                ControllerPhase::ScanStash,
                ControllerPhase::RewritePath,
            ]);
            controller_phase_order.extend(std::iter::repeat_n(
                ControllerPhase::AscendPositionMap,
                access.recursion_depth,
            ));

            metadata_budget += access.metadata_pages_per_access;
            position_map_budget += access.recursion_depth;
            path_budget += access.buckets_per_access;
            stash_budget += access.stash_bound;

            metadata_workset = metadata_workset.max(access.metadata_pages_per_access);
            position_map_workset = position_map_workset.max(access.recursion_depth);
            path_workset = path_workset.max(access.buckets_per_access);
            stash_workset = stash_workset.max(access.stash_bound);
            recursive_position_map_depth = recursive_position_map_depth.max(access.recursion_depth);
            stash_bound = stash_bound.max(access.stash_bound);
        }

        controller_phase_order.extend([
            ControllerPhase::SealPersistentState,
            ControllerPhase::EnclaveExit,
        ]);

        let page_trace_regions = vec![
            ControllerPageBudget {
                page_kind: METADATA_REGION.into(),
                event_budget: metadata_budget,
            },
            ControllerPageBudget {
                page_kind: POSITION_MAP_REGION.into(),
                event_budget: position_map_budget,
            },
            ControllerPageBudget {
                page_kind: PATH_REGION.into(),
                event_budget: path_budget,
            },
            ControllerPageBudget {
                page_kind: STASH_REGION.into(),
                event_budget: stash_budget,
            },
        ];
        let workset_regions = vec![
            ControllerPageBudget {
                page_kind: METADATA_REGION.into(),
                event_budget: metadata_workset,
            },
            ControllerPageBudget {
                page_kind: POSITION_MAP_REGION.into(),
                event_budget: position_map_workset,
            },
            ControllerPageBudget {
                page_kind: PATH_REGION.into(),
                event_budget: path_workset,
            },
            ControllerPageBudget {
                page_kind: STASH_REGION.into(),
                event_budget: stash_workset,
            },
        ];
        let total_oram_accesses = self.observed_oram_accesses.len();
        let page_trace_budget = page_trace_regions
            .iter()
            .map(|region| region.event_budget)
            .sum::<usize>();
        SgxControllerShapeTrace {
            boundary_event_budget: 2 * total_oram_accesses + 2,
            controller_phase_order: controller_phase_order.clone(),
            page_trace_regions,
            workset_regions,
            exit_trace_budget: controller_phase_order.len() + total_oram_accesses + 1,
            shared_resource_budget: 0, // overwritten below
            recursive_position_map_depth,
            stash_bound,
        }
        .with_shared_resource_budget(page_trace_budget)
    }

    pub fn theorem_trace(&self, public_outcome: PublicOutcomeTrace) -> TheoremTrace {
        let controller_shape = self.controller_shape();
        TheoremTrace {
            public_outcome: Some(public_outcome.clone()),
            boundary_schedule: self.boundary_schedule(&public_outcome),
            normalized_micro_trace: Some(controller_shape.normalized_micro_trace()),
            controller_shape: Some(controller_shape),
        }
    }
}

impl RuntimeControllerObserverCertificate {
    pub fn public_outcome(&self) -> &PublicOutcomeTrace {
        &self.public_outcome
    }

    pub fn boundary_schedule(&self) -> &[BoundaryEvent] {
        &self.boundary_schedule
    }

    pub fn controller_shape(&self) -> &SgxControllerShapeTrace {
        &self.controller_shape
    }

    pub fn normalized_micro_trace(&self) -> &NormalizedMicroTrace {
        &self.normalized_micro_trace
    }

    pub fn controller_certificate(&self) -> &RuntimeControllerCertificate {
        &self.controller_certificate
    }

    fn new(
        public_outcome: PublicOutcomeTrace,
        boundary_schedule: Vec<BoundaryEvent>,
        controller_shape: SgxControllerShapeTrace,
        normalized_micro_trace: NormalizedMicroTrace,
        controller_certificate: RuntimeControllerCertificate,
    ) -> Result<Self, RefinementWitnessError> {
        let certificate = Self {
            public_outcome,
            boundary_schedule,
            controller_shape,
            normalized_micro_trace,
            controller_certificate,
        };
        certificate.validate()?;
        Ok(certificate)
    }

    pub fn validate(&self) -> Result<(), RefinementWitnessError> {
        if self.boundary_schedule.len() != self.controller_shape.boundary_event_budget {
            return Err(RefinementWitnessError::BoundaryBudgetMismatch {
                boundary_events: self.boundary_schedule.len(),
                boundary_budget: self.controller_shape.boundary_event_budget,
            });
        }
        if self.boundary_schedule
            != self
                .controller_certificate
                .boundary_schedule(&self.public_outcome)
        {
            return Err(RefinementWitnessError::BoundaryScheduleMismatch);
        }
        if self.controller_shape != self.controller_certificate.controller_shape() {
            return Err(RefinementWitnessError::ControllerShapeMismatch);
        }
        if self.normalized_micro_trace != self.controller_shape.normalized_micro_trace() {
            return Err(RefinementWitnessError::NormalizedMicroTraceMismatch);
        }
        Ok(())
    }
}

fn is_oram_logical_kind(kind: &str) -> bool {
    matches!(
        kind,
        "uooram_counter"
            | "uooram_meta_scan"
            | "uooram_bucket_scan"
            | "uooram_metadata_load"
            | "uooram_path_read"
    )
}

fn runtime_oram_object_by_name<'a>(
    oram_objects: &'a [RuntimeOramObjectWitness],
    object: &str,
) -> Result<&'a RuntimeOramObjectWitness, RefinementWitnessError> {
    oram_objects
        .iter()
        .find(|candidate| candidate.object_name == object)
        .ok_or_else(|| RefinementWitnessError::UnknownOramLogicalObject {
            object: object.into(),
        })
}

fn consume_expected_oram_logical_events(
    logical_accesses: &[LogicalEvent],
    mut index: usize,
    object: &str,
    expected_kind: &str,
    expected_count: usize,
    detail_prefix: &str,
) -> Result<usize, RefinementWitnessError> {
    for _ in 0..expected_count {
        let Some(event) = logical_accesses.get(index) else {
            return Err(RefinementWitnessError::MalformedOramLogicalTrace {
                object: object.into(),
                expected_kind: expected_kind.into(),
                detail_prefix: detail_prefix.into(),
            });
        };
        if event.object != object
            || event.kind != expected_kind
            || !event.detail.starts_with(detail_prefix)
        {
            return Err(RefinementWitnessError::MalformedOramLogicalTrace {
                object: object.into(),
                expected_kind: expected_kind.into(),
                detail_prefix: detail_prefix.into(),
            });
        }
        index += 1;
    }
    Ok(index)
}

fn reconstruct_oram_accesses_from_logical_trace(
    logical_accesses: &[LogicalEvent],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<Vec<RuntimeOramAccessWitness>, RefinementWitnessError> {
    let mut accesses = Vec::new();
    let mut index = 0usize;
    while index < logical_accesses.len() {
        let event = &logical_accesses[index];
        if !is_oram_logical_kind(&event.kind) {
            index += 1;
            continue;
        }
        if event.kind != "uooram_counter" || event.detail != "counter" {
            return Err(RefinementWitnessError::MalformedOramLogicalTrace {
                object: event.object.clone(),
                expected_kind: "uooram_counter".into(),
                detail_prefix: "counter".into(),
            });
        }
        let object = runtime_oram_object_by_name(oram_objects, &event.object)?;
        index += 1;
        index = consume_expected_oram_logical_events(
            logical_accesses,
            index,
            &event.object,
            object.metadata_event_kind()?,
            object.metadata_pages,
            "page:",
        )?;
        index = consume_expected_oram_logical_events(
            logical_accesses,
            index,
            &event.object,
            object.bucket_event_kind()?,
            object.buckets_per_access,
            "bucket:",
        )?;
        accesses.push(object.access_witness());
    }
    Ok(accesses)
}

fn path_bucket_indices(leaf_count: usize, leaf: usize) -> Vec<usize> {
    let mut node = leaf_count.saturating_sub(1) + (leaf % leaf_count.max(1));
    let mut path = vec![node];
    while node != 0 {
        node = (node - 1) / 2;
        path.push(node);
    }
    path.reverse();
    path
}

fn runtime_oram_object_by_id(
    oram_objects: &[RuntimeOramObjectWitness],
    object_id: u32,
) -> Result<&RuntimeOramObjectWitness, RefinementWitnessError> {
    oram_objects
        .iter()
        .find(|candidate| candidate.object_id == object_id)
        .ok_or_else(|| RefinementWitnessError::UnknownOramLogicalObject {
            object: object_id.to_string(),
        })
}

fn reconstruct_path_oram_leaf_scaffold_from_logical_trace(
    logical_accesses: &[LogicalEvent],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<Vec<(u32, String, usize)>, RefinementWitnessError> {
    let mut scaffold = Vec::new();
    let mut index = 0usize;
    while index < logical_accesses.len() {
        let event = &logical_accesses[index];
        if !is_oram_logical_kind(&event.kind) {
            index += 1;
            continue;
        }
        if event.kind != "uooram_counter" || event.detail != "counter" {
            return Err(RefinementWitnessError::MalformedOramLogicalTrace {
                object: event.object.clone(),
                expected_kind: "uooram_counter".into(),
                detail_prefix: "counter".into(),
            });
        }
        let object = runtime_oram_object_by_name(oram_objects, &event.object)?;
        index += 1;
        index = consume_expected_oram_logical_events(
            logical_accesses,
            index,
            &event.object,
            object.metadata_event_kind()?,
            object.metadata_pages,
            "page:",
        )?;
        index = consume_expected_oram_logical_events(
            logical_accesses,
            index,
            &event.object,
            object.bucket_event_kind()?,
            object.buckets_per_access,
            "bucket:",
        )?;
        if object.scheme == PATH_ORAM_SCHEME {
            scaffold.push((
                object.object_id,
                object.object_name.clone(),
                object.bucket_count,
            ));
        }
    }
    Ok(scaffold)
}

fn runtime_path_oram_bucket_trace(
    physical_reads: &[PhysicalReadEvent],
    physical_writes: &[PhysicalWriteEvent],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<(Vec<(String, String)>, Vec<(String, String)>), RefinementWitnessError> {
    let path_objects = oram_objects
        .iter()
        .filter(|object| object.scheme == PATH_ORAM_SCHEME)
        .map(|object| object.object_name.as_str())
        .collect::<std::collections::BTreeSet<_>>();
    let read_buckets = physical_reads
        .iter()
        .filter(|event| {
            path_objects.contains(event.object.as_str())
                && event
                    .location
                    .starts_with(&format!("{}@bucket", event.object))
        })
        .map(|event| (event.object.clone(), event.location.clone()))
        .collect();
    let write_buckets = physical_writes
        .iter()
        .filter(|event| {
            path_objects.contains(event.object.as_str())
                && event
                    .location
                    .starts_with(&format!("{}@bucket", event.object))
        })
        .map(|event| (event.object.clone(), event.location.clone()))
        .collect();
    Ok((read_buckets, write_buckets))
}

fn runtime_path_oram_bucket_trace_of_leaf_schedule(
    leaf_schedule: &[RuntimeOramLeafWitness],
) -> (Vec<(String, String)>, Vec<(String, String)>) {
    let mut read_buckets = Vec::new();
    let mut write_buckets = Vec::new();
    for step in leaf_schedule {
        let leaf_count = ((step.bucket_count + 1) / 2).max(1);
        let path = path_bucket_indices(leaf_count, step.leaf);
        for index in &path {
            read_buckets.push((
                step.object_name.clone(),
                format!("{}@bucket{}", step.object_name, index),
            ));
        }
        for index in path.iter().rev() {
            write_buckets.push((
                step.object_name.clone(),
                format!("{}@bucket{}", step.object_name, index),
            ));
        }
    }
    (read_buckets, write_buckets)
}

fn path_oram_leaf_choice_count(bucket_count: usize) -> usize {
    ((bucket_count + 1) / 2).max(1)
}

fn runtime_path_oram_fresh_coin_scaffold_of_step(
    leaf: &RuntimeOramLeafWitness,
    transition: &RuntimePathOramTransitionWitness,
) -> Option<Vec<RuntimeOramLeafScaffoldWitness>> {
    if transition.object_id != leaf.object_id
        || transition.object_name != leaf.object_name
        || transition.bucket_count != leaf.bucket_count
    {
        return None;
    }
    let scaffold_step = RuntimeOramLeafScaffoldWitness {
        object_id: leaf.object_id,
        object_name: leaf.object_name.clone(),
        bucket_count: leaf.bucket_count,
    };
    match transition.kind {
        RuntimePathOramTransitionKind::ReadMiss => Some(vec![scaffold_step]),
        RuntimePathOramTransitionKind::ReadHit => transition.next_leaf.map(|_| vec![scaffold_step]),
        RuntimePathOramTransitionKind::WriteNoop => Some(if transition.slot_index.is_some() {
            vec![]
        } else {
            vec![scaffold_step]
        }),
        RuntimePathOramTransitionKind::WriteInsert => transition
            .next_leaf
            .map(|_| vec![scaffold_step.clone(), scaffold_step]),
        RuntimePathOramTransitionKind::WriteUpdate => {
            transition.next_leaf.map(|_| vec![scaffold_step])
        }
        RuntimePathOramTransitionKind::WriteDelete => Some(vec![]),
    }
}

fn runtime_path_oram_fresh_coin_values_of_step(
    leaf: &RuntimeOramLeafWitness,
    transition: &RuntimePathOramTransitionWitness,
) -> Option<Vec<usize>> {
    if transition.object_id != leaf.object_id
        || transition.object_name != leaf.object_name
        || transition.bucket_count != leaf.bucket_count
    {
        return None;
    }
    match transition.kind {
        RuntimePathOramTransitionKind::ReadMiss => Some(vec![leaf.leaf]),
        RuntimePathOramTransitionKind::ReadHit => {
            transition.next_leaf.map(|next_leaf| vec![next_leaf])
        }
        RuntimePathOramTransitionKind::WriteNoop => Some(if transition.slot_index.is_some() {
            vec![]
        } else {
            vec![leaf.leaf]
        }),
        RuntimePathOramTransitionKind::WriteInsert => transition
            .next_leaf
            .map(|next_leaf| vec![leaf.leaf, next_leaf]),
        RuntimePathOramTransitionKind::WriteUpdate => {
            transition.next_leaf.map(|next_leaf| vec![next_leaf])
        }
        RuntimePathOramTransitionKind::WriteDelete => Some(vec![]),
    }
}

pub fn extract_runtime_path_oram_fresh_coin_scaffold(
    leaf_schedule: &[RuntimeOramLeafWitness],
    transitions: &[RuntimePathOramTransitionWitness],
) -> Option<Vec<RuntimeOramLeafScaffoldWitness>> {
    if leaf_schedule.len() != transitions.len() {
        return None;
    }
    let mut scaffold = Vec::new();
    for (leaf, transition) in leaf_schedule.iter().zip(transitions.iter()) {
        scaffold.extend(runtime_path_oram_fresh_coin_scaffold_of_step(
            leaf, transition,
        )?);
    }
    Some(scaffold)
}

pub fn extract_runtime_path_oram_fresh_coin_values(
    leaf_schedule: &[RuntimeOramLeafWitness],
    transitions: &[RuntimePathOramTransitionWitness],
) -> Option<Vec<usize>> {
    if leaf_schedule.len() != transitions.len() {
        return None;
    }
    let mut values = Vec::new();
    for (leaf, transition) in leaf_schedule.iter().zip(transitions.iter()) {
        values.extend(runtime_path_oram_fresh_coin_values_of_step(
            leaf, transition,
        )?);
    }
    Some(values)
}

pub fn canonical_path_oram_leaf_seed_space_size(
    scaffold: &[RuntimeOramLeafScaffoldWitness],
) -> Option<usize> {
    scaffold.iter().try_fold(1usize, |acc, step| {
        acc.checked_mul(path_oram_leaf_choice_count(step.bucket_count))
    })
}

pub fn canonical_path_oram_leaf_values_of_seed(
    scaffold: &[RuntimeOramLeafScaffoldWitness],
    seed: usize,
) -> Vec<usize> {
    fn go(scaffold: &[RuntimeOramLeafScaffoldWitness], seed: usize, output: &mut Vec<usize>) {
        if let Some((head, tail)) = scaffold.split_first() {
            let tail_size = canonical_path_oram_leaf_seed_space_size(tail)
                .expect("tail seed space should fit in usize")
                .max(1);
            output.push(seed / tail_size);
            debug_assert!(path_oram_leaf_choice_count(head.bucket_count) > 0);
            go(tail, seed % tail_size, output);
        }
    }

    let mut values = Vec::with_capacity(scaffold.len());
    go(scaffold, seed, &mut values);
    values
}

pub fn canonical_path_oram_seed_of_leaf_values(
    scaffold: &[RuntimeOramLeafScaffoldWitness],
    values: &[usize],
) -> Option<usize> {
    match (scaffold.split_first(), values.split_first()) {
        (None, None) => Some(0),
        (Some(_), None) | (None, Some(_)) => None,
        (Some((head, tail)), Some((value, tail_values))) => {
            if *value >= path_oram_leaf_choice_count(head.bucket_count) {
                return None;
            }
            let tail_size = canonical_path_oram_leaf_seed_space_size(tail)?;
            let tail_seed = canonical_path_oram_seed_of_leaf_values(tail, tail_values)?;
            value.checked_mul(tail_size)?.checked_add(tail_seed)
        }
    }
}

fn validate_path_oram_leaf_schedule(
    leaf_schedule: &[RuntimeOramLeafWitness],
    logical_accesses: &[LogicalEvent],
    physical_reads: &[PhysicalReadEvent],
    physical_writes: &[PhysicalWriteEvent],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<Vec<RuntimeOramLeafScaffoldWitness>, RefinementWitnessError> {
    let scaffold =
        reconstruct_path_oram_leaf_scaffold_from_logical_trace(logical_accesses, oram_objects)?;
    if scaffold.len() != leaf_schedule.len() {
        return Err(RefinementWitnessError::OramLeafScheduleMismatch);
    }
    for ((object_id, object_name, bucket_count), step) in scaffold.iter().zip(leaf_schedule.iter())
    {
        let object = runtime_oram_object_by_id(oram_objects, step.object_id)?;
        if object.scheme != PATH_ORAM_SCHEME
            || step.object_id != *object_id
            || step.object_name != *object_name
            || step.bucket_count != *bucket_count
            || object.object_name != step.object_name
            || object.bucket_count != step.bucket_count
        {
            return Err(RefinementWitnessError::OramLeafScheduleMismatch);
        }
    }
    let expected = runtime_path_oram_bucket_trace_of_leaf_schedule(leaf_schedule);
    let observed = runtime_path_oram_bucket_trace(physical_reads, physical_writes, oram_objects)?;
    if observed != expected {
        return Err(RefinementWitnessError::OramLeafScheduleMismatch);
    }
    Ok(scaffold
        .into_iter()
        .map(
            |(object_id, object_name, bucket_count)| RuntimeOramLeafScaffoldWitness {
                object_id,
                object_name,
                bucket_count,
            },
        )
        .collect())
}

fn runtime_path_oram_state_by_object(
    states: &[RuntimePathOramPositionMapWitness],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<BTreeMap<u32, Vec<Option<usize>>>, RefinementWitnessError> {
    let mut by_object = BTreeMap::new();
    for object in oram_objects
        .iter()
        .filter(|object| object.scheme == PATH_ORAM_SCHEME)
    {
        let state = states
            .iter()
            .find(|state| state.object_id == object.object_id)
            .ok_or(RefinementWitnessError::OramLeafStateMismatch)?;
        if state.object_name != object.object_name || state.leaves.len() != object.capacity {
            return Err(RefinementWitnessError::OramLeafStateMismatch);
        }
        let leaf_count = path_oram_leaf_choice_count(object.bucket_count);
        if state
            .leaves
            .iter()
            .flatten()
            .any(|leaf| *leaf >= leaf_count)
        {
            return Err(RefinementWitnessError::OramLeafStateMismatch);
        }
        if by_object
            .insert(object.object_id, state.leaves.clone())
            .is_some()
        {
            return Err(RefinementWitnessError::OramLeafStateMismatch);
        }
    }
    if by_object.len() != states.len() {
        return Err(RefinementWitnessError::OramLeafStateMismatch);
    }
    Ok(by_object)
}

fn validate_path_oram_leaf_state(
    leaf_schedule: &[RuntimeOramLeafWitness],
    transitions: &[RuntimePathOramTransitionWitness],
    before: &[RuntimePathOramPositionMapWitness],
    after: &[RuntimePathOramPositionMapWitness],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<(), RefinementWitnessError> {
    if leaf_schedule.len() != transitions.len() {
        return Err(RefinementWitnessError::OramLeafStateMismatch);
    }
    let mut current = runtime_path_oram_state_by_object(before, oram_objects)?;
    let expected_after = runtime_path_oram_state_by_object(after, oram_objects)?;
    for (step, transition) in leaf_schedule.iter().zip(transitions.iter()) {
        let object = runtime_oram_object_by_id(oram_objects, step.object_id)?;
        if object.scheme != PATH_ORAM_SCHEME
            || transition.object_id != step.object_id
            || transition.object_name != step.object_name
            || transition.bucket_count != step.bucket_count
            || object.object_name != step.object_name
            || object.bucket_count != step.bucket_count
            || step.leaf >= path_oram_leaf_choice_count(step.bucket_count)
        {
            return Err(RefinementWitnessError::OramLeafStateMismatch);
        }
        let state = current
            .get_mut(&step.object_id)
            .ok_or(RefinementWitnessError::OramLeafStateMismatch)?;
        if transition.prior_leaf.is_some() && transition.slot_index.is_none() {
            return Err(RefinementWitnessError::OramLeafStateMismatch);
        }
        if let Some(slot_index) = transition.slot_index {
            if slot_index >= state.len() {
                return Err(RefinementWitnessError::OramLeafStateMismatch);
            }
            if let Some(prior_leaf) = transition.prior_leaf {
                if state[slot_index] != Some(prior_leaf) {
                    return Err(RefinementWitnessError::OramLeafStateMismatch);
                }
            }
        }
        match transition.kind {
            RuntimePathOramTransitionKind::ReadMiss => {
                if transition.slot_index.is_some()
                    || transition.prior_leaf.is_some()
                    || transition.next_leaf.is_some()
                {
                    return Err(RefinementWitnessError::OramLeafStateMismatch);
                }
            }
            RuntimePathOramTransitionKind::ReadHit => {
                let (slot_index, prior_leaf, next_leaf) = match (
                    transition.slot_index,
                    transition.prior_leaf,
                    transition.next_leaf,
                ) {
                    (Some(slot_index), Some(prior_leaf), Some(next_leaf)) => {
                        (slot_index, prior_leaf, next_leaf)
                    }
                    _ => return Err(RefinementWitnessError::OramLeafStateMismatch),
                };
                if step.leaf != prior_leaf
                    || next_leaf >= path_oram_leaf_choice_count(step.bucket_count)
                {
                    return Err(RefinementWitnessError::OramLeafStateMismatch);
                }
                state[slot_index] = Some(next_leaf);
            }
            RuntimePathOramTransitionKind::WriteNoop => match (
                transition.slot_index,
                transition.prior_leaf,
                transition.next_leaf,
            ) {
                (None, None, None) => {}
                (Some(_slot_index), Some(prior_leaf), Some(next_leaf)) => {
                    if step.leaf != prior_leaf || next_leaf != prior_leaf {
                        return Err(RefinementWitnessError::OramLeafStateMismatch);
                    }
                }
                _ => return Err(RefinementWitnessError::OramLeafStateMismatch),
            },
            RuntimePathOramTransitionKind::WriteInsert => {
                let (slot_index, next_leaf) = match (
                    transition.slot_index,
                    transition.prior_leaf,
                    transition.next_leaf,
                ) {
                    (Some(slot_index), None, Some(next_leaf)) => (slot_index, next_leaf),
                    _ => return Err(RefinementWitnessError::OramLeafStateMismatch),
                };
                if state[slot_index].is_some()
                    || next_leaf >= path_oram_leaf_choice_count(step.bucket_count)
                {
                    return Err(RefinementWitnessError::OramLeafStateMismatch);
                }
                state[slot_index] = Some(next_leaf);
            }
            RuntimePathOramTransitionKind::WriteUpdate => {
                let (slot_index, prior_leaf, next_leaf) = match (
                    transition.slot_index,
                    transition.prior_leaf,
                    transition.next_leaf,
                ) {
                    (Some(slot_index), Some(prior_leaf), Some(next_leaf)) => {
                        (slot_index, prior_leaf, next_leaf)
                    }
                    _ => return Err(RefinementWitnessError::OramLeafStateMismatch),
                };
                if step.leaf != prior_leaf
                    || next_leaf >= path_oram_leaf_choice_count(step.bucket_count)
                {
                    return Err(RefinementWitnessError::OramLeafStateMismatch);
                }
                state[slot_index] = Some(next_leaf);
            }
            RuntimePathOramTransitionKind::WriteDelete => {
                let (slot_index, prior_leaf) = match (
                    transition.slot_index,
                    transition.prior_leaf,
                    transition.next_leaf,
                ) {
                    (Some(slot_index), Some(prior_leaf), None) => (slot_index, prior_leaf),
                    _ => return Err(RefinementWitnessError::OramLeafStateMismatch),
                };
                if step.leaf != prior_leaf {
                    return Err(RefinementWitnessError::OramLeafStateMismatch);
                }
                state[slot_index] = None;
            }
        }
    }
    if current != expected_after {
        return Err(RefinementWitnessError::OramLeafStateMismatch);
    }
    Ok(())
}

impl SgxControllerShapeTrace {
    fn with_shared_resource_budget(mut self, page_trace_budget: usize) -> Self {
        self.shared_resource_budget = self.controller_phase_order.len() + page_trace_budget;
        self
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct TraceHashBundle {
    pub opcode_trace_hash: String,
    pub logical_access_trace_hash: String,
    pub logical_write_trace_hash: String,
    pub physical_read_trace_hash: String,
    pub physical_write_trace_hash: String,
    pub physical_access_trace_hash: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct ExecutionTrace {
    #[serde(default)]
    pub opcode_trace: Vec<String>,
    #[serde(default)]
    pub logical_accesses: Vec<LogicalEvent>,
    #[serde(default)]
    pub logical_writes: Vec<LogicalEvent>,
    #[serde(default)]
    pub physical_reads: Vec<PhysicalReadEvent>,
    #[serde(default)]
    pub physical_writes: Vec<PhysicalWriteEvent>,
    #[serde(default)]
    pub gas_used: u64,
    #[serde(default)]
    pub theorem_trace: TheoremTrace,
    #[serde(default)]
    runtime_seed: Option<u64>,
    #[serde(default)]
    runtime_kernel_witness: Option<RuntimeKernelWitness>,
    #[serde(default)]
    runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,
    #[serde(default)]
    runtime_trusted_kernel_bundle: Option<RuntimeTrustedKernelBundle>,
    #[serde(default)]
    runtime_controller_certificate: Option<RuntimeControllerCertificate>,
    #[serde(default)]
    runtime_oram_objects: Vec<RuntimeOramObjectWitness>,
    #[serde(default)]
    runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
    #[serde(default)]
    runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
    #[serde(default)]
    runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,
    #[serde(default)]
    runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
    #[serde(default)]
    runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
    #[serde(default)]
    runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RuntimeExecutionTraceParts {
    opcode_trace: Vec<String>,
    logical_accesses: Vec<LogicalEvent>,
    logical_writes: Vec<LogicalEvent>,
    physical_reads: Vec<PhysicalReadEvent>,
    physical_writes: Vec<PhysicalWriteEvent>,
    gas_used: u64,
    theorem_trace: TheoremTrace,
    runtime_seed: Option<u64>,
    runtime_kernel_witness: Option<RuntimeKernelWitness>,
    runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,
    runtime_controller_certificate: Option<RuntimeControllerCertificate>,
    runtime_oram_objects: Vec<RuntimeOramObjectWitness>,
    runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
    runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
    runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,
    runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
    runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
    runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
}

impl RuntimeExecutionTraceParts {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        opcode_trace: Vec<String>,
        logical_accesses: Vec<LogicalEvent>,
        logical_writes: Vec<LogicalEvent>,
        physical_reads: Vec<PhysicalReadEvent>,
        physical_writes: Vec<PhysicalWriteEvent>,
        gas_used: u64,
        theorem_trace: TheoremTrace,
        runtime_seed: Option<u64>,
        runtime_kernel_witness: Option<RuntimeKernelWitness>,
        runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,
        runtime_controller_certificate: Option<RuntimeControllerCertificate>,
        runtime_oram_objects: Vec<RuntimeOramObjectWitness>,
        runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
        runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
        runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,
        runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
        runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
        runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
    ) -> Self {
        Self {
            opcode_trace,
            logical_accesses,
            logical_writes,
            physical_reads,
            physical_writes,
            gas_used,
            theorem_trace,
            runtime_seed,
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            runtime_controller_certificate,
            runtime_oram_objects,
            runtime_oram_leaf_schedule,
            runtime_oram_access_counters_before,
            runtime_oram_access_counters_after,
            runtime_oram_position_map_before,
            runtime_oram_position_map_after,
            runtime_oram_leaf_state_transitions,
        }
    }
}

impl ExecutionTrace {
    pub fn runtime_seed(&self) -> Option<u64> {
        self.runtime_seed
    }

    pub fn runtime_kernel_witness(&self) -> Option<&RuntimeKernelWitness> {
        self.runtime_kernel_witness.as_ref()
    }

    pub fn runtime_kernel_refinement_witness(&self) -> Option<&RuntimeKernelRefinementWitness> {
        self.runtime_kernel_refinement_witness.as_ref()
    }

    pub fn stored_runtime_trusted_kernel_bundle(&self) -> Option<&RuntimeTrustedKernelBundle> {
        self.runtime_trusted_kernel_bundle.as_ref()
    }

    pub fn stored_runtime_controller_certificate(&self) -> Option<&RuntimeControllerCertificate> {
        self.runtime_controller_certificate.as_ref()
    }

    pub fn runtime_oram_objects(&self) -> &[RuntimeOramObjectWitness] {
        &self.runtime_oram_objects
    }

    pub fn runtime_oram_leaf_schedule(&self) -> &[RuntimeOramLeafWitness] {
        &self.runtime_oram_leaf_schedule
    }

    pub fn runtime_oram_access_counters_before(&self) -> &[RuntimeOramAccessCounterWitness] {
        &self.runtime_oram_access_counters_before
    }

    pub fn runtime_oram_access_counters_after(&self) -> &[RuntimeOramAccessCounterWitness] {
        &self.runtime_oram_access_counters_after
    }

    pub fn runtime_oram_position_map_before(&self) -> &[RuntimePathOramPositionMapWitness] {
        &self.runtime_oram_position_map_before
    }

    pub fn runtime_oram_position_map_after(&self) -> &[RuntimePathOramPositionMapWitness] {
        &self.runtime_oram_position_map_after
    }

    pub fn runtime_oram_leaf_state_transitions(&self) -> &[RuntimePathOramTransitionWitness] {
        &self.runtime_oram_leaf_state_transitions
    }

    pub fn from_runtime_trace_parts(parts: RuntimeExecutionTraceParts) -> Self {
        let RuntimeExecutionTraceParts {
            opcode_trace,
            logical_accesses,
            logical_writes,
            physical_reads,
            physical_writes,
            gas_used,
            theorem_trace,
            runtime_seed,
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            runtime_controller_certificate,
            runtime_oram_objects,
            runtime_oram_leaf_schedule,
            runtime_oram_access_counters_before,
            runtime_oram_access_counters_after,
            runtime_oram_position_map_before,
            runtime_oram_position_map_after,
            runtime_oram_leaf_state_transitions,
        } = parts;
        Self {
            opcode_trace,
            logical_accesses,
            logical_writes,
            physical_reads,
            physical_writes,
            gas_used,
            theorem_trace,
            runtime_seed,
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            runtime_trusted_kernel_bundle: None,
            runtime_controller_certificate,
            runtime_oram_objects,
            runtime_oram_leaf_schedule,
            runtime_oram_access_counters_before,
            runtime_oram_access_counters_after,
            runtime_oram_position_map_before,
            runtime_oram_position_map_after,
            runtime_oram_leaf_state_transitions,
        }
    }

    pub fn hashes(&self) -> TraceHashBundle {
        let normalized_physical = self
            .physical_writes
            .iter()
            .map(|event| {
                (
                    event.object.clone(),
                    event.location.clone(),
                    event.class,
                    event.len,
                )
            })
            .collect::<Vec<_>>();
        let normalized_reads = self
            .physical_reads
            .iter()
            .map(|event| (event.object.clone(), event.location.clone(), event.len))
            .collect::<Vec<_>>();
        TraceHashBundle {
            opcode_trace_hash: hash_json(&self.opcode_trace),
            logical_access_trace_hash: hash_json(&self.logical_accesses),
            logical_write_trace_hash: hash_json(&self.logical_writes),
            physical_read_trace_hash: hash_json(&normalized_reads),
            physical_write_trace_hash: hash_json(&normalized_physical),
            physical_access_trace_hash: hash_json(&(normalized_reads, normalized_physical)),
        }
    }

    pub fn refinement_trace(&self) -> RefinementTrace {
        RefinementTrace {
            opcode_trace: self.opcode_trace.clone(),
            logical_accesses: self.logical_accesses.clone(),
            logical_writes: self.logical_writes.clone(),
            physical_reads: self.physical_reads.clone(),
            physical_writes: self
                .physical_writes
                .iter()
                .map(|event| RefinementPhysicalWrite {
                    object: event.object.clone(),
                    location: event.location.clone(),
                    write_class: event.class.as_refinement_label().into(),
                    len: event.len,
                })
                .collect(),
            gas_used: self.gas_used,
        }
    }

    fn reconstructed_runtime_controller_observer_certificate(
        &self,
    ) -> Result<RuntimeControllerObserverCertificate, RefinementWitnessError> {
        RuntimeControllerObserverCertificate::new(
            self.theorem_trace
                .public_outcome
                .clone()
                .ok_or(RefinementWitnessError::MissingPublicOutcome)?,
            self.theorem_trace.boundary_schedule.clone(),
            self.theorem_trace
                .controller_shape
                .clone()
                .ok_or(RefinementWitnessError::MissingControllerShape)?,
            self.theorem_trace
                .normalized_micro_trace
                .clone()
                .ok_or(RefinementWitnessError::MissingNormalizedMicroTrace)?,
            self.runtime_controller_certificate
                .clone()
                .ok_or(RefinementWitnessError::MissingControllerCertificate)?,
        )
    }

    fn reconstructed_runtime_path_oram_hidden_certificate(
        &self,
    ) -> Result<RuntimePathOramHiddenCertificate, RefinementWitnessError> {
        RuntimePathOramHiddenCertificate::new(
            self.refinement_trace(),
            self.runtime_oram_objects.clone(),
            self.runtime_oram_leaf_schedule.clone(),
            self.runtime_oram_position_map_before.clone(),
            self.runtime_oram_position_map_after.clone(),
            self.runtime_oram_leaf_state_transitions.clone(),
        )
    }

    fn reconstructed_runtime_trusted_kernel_bundle(
        &self,
    ) -> Result<RuntimeTrustedKernelBundle, RefinementWitnessError> {
        RuntimeTrustedKernelBundle::new_with_kernel_witness(
            self.runtime_seed,
            self.reconstructed_runtime_controller_observer_certificate()?,
            self.runtime_kernel_witness.clone(),
            self.reconstructed_runtime_path_oram_hidden_certificate()?,
        )
    }

    pub fn runtime_controller_observer_certificate(
        &self,
    ) -> Result<RuntimeControllerObserverCertificate, RefinementWitnessError> {
        let reconstructed = self.reconstructed_runtime_controller_observer_certificate()?;
        if let Some(bundle) = &self.runtime_trusted_kernel_bundle {
            bundle.controller_observer.validate()?;
            if bundle.controller_observer != reconstructed {
                return Err(RefinementWitnessError::ControllerObserverTraceMismatch);
            }
            return Ok(bundle.controller_observer.clone());
        }
        Ok(reconstructed)
    }

    pub fn runtime_path_oram_hidden_certificate(
        &self,
    ) -> Result<RuntimePathOramHiddenCertificate, RefinementWitnessError> {
        let reconstructed = self.reconstructed_runtime_path_oram_hidden_certificate()?;
        if let Some(bundle) = &self.runtime_trusted_kernel_bundle {
            bundle.hidden_certificate.validate()?;
            if bundle.hidden_certificate != reconstructed {
                return Err(RefinementWitnessError::HiddenCertificateTraceMismatch);
            }
            return Ok(bundle.hidden_certificate.clone());
        }
        Ok(reconstructed)
    }

    fn store_runtime_trusted_kernel_bundle(
        &mut self,
        mut bundle: RuntimeTrustedKernelBundle,
    ) -> Result<(), RefinementWitnessError> {
        if let Some(trace_kernel_witness) = &self.runtime_kernel_witness {
            match &bundle.kernel_witness {
                Some(bundle_kernel_witness) if bundle_kernel_witness != trace_kernel_witness => {
                    return Err(RefinementWitnessError::KernelWitnessTraceMismatch);
                }
                None => {
                    bundle.kernel_witness = Some(trace_kernel_witness.clone());
                }
                Some(_) => {}
            }
        }
        let reconstructed = self.reconstructed_runtime_trusted_kernel_bundle()?;
        if bundle != reconstructed {
            return Err(RefinementWitnessError::TrustedKernelBundleTraceMismatch);
        }
        bundle.validate()?;
        self.runtime_trusted_kernel_bundle = Some(bundle);
        Ok(())
    }

    pub fn materialize_runtime_trusted_kernel_bundle(
        &mut self,
    ) -> Result<RuntimeTrustedKernelBundle, RefinementWitnessError> {
        let bundle = self.reconstructed_runtime_trusted_kernel_bundle()?;
        self.store_runtime_trusted_kernel_bundle(bundle.clone())?;
        Ok(bundle)
    }

    pub fn runtime_trusted_kernel_bundle(
        &self,
    ) -> Result<RuntimeTrustedKernelBundle, RefinementWitnessError> {
        if let Some(bundle) = &self.runtime_trusted_kernel_bundle {
            let mut bundle = bundle.clone();
            if let Some(trace_kernel_witness) = &self.runtime_kernel_witness {
                match &bundle.kernel_witness {
                    Some(bundle_kernel_witness)
                        if bundle_kernel_witness != trace_kernel_witness =>
                    {
                        return Err(RefinementWitnessError::KernelWitnessTraceMismatch);
                    }
                    None => {
                        bundle.kernel_witness = Some(trace_kernel_witness.clone());
                    }
                    Some(_) => {}
                }
            }
            let reconstructed = self.reconstructed_runtime_trusted_kernel_bundle()?;
            if bundle != reconstructed {
                return Err(RefinementWitnessError::TrustedKernelBundleTraceMismatch);
            }
            bundle.validate()?;
            return Ok(bundle);
        }
        self.reconstructed_runtime_trusted_kernel_bundle()
    }

    pub fn runtime_refinement_witness(
        &self,
    ) -> Result<RuntimeRefinementWitness, RefinementWitnessError> {
        let bundle = self.runtime_trusted_kernel_bundle()?;
        RuntimeRefinementWitness::from_certificates_with_runtime_witnesses(
            bundle.runtime_seed,
            bundle.controller_observer,
            bundle.kernel_witness,
            self.runtime_kernel_refinement_witness.clone(),
            bundle.hidden_certificate,
        )
    }

    pub fn runtime_paper_main_family_bundle(
        &self,
    ) -> Result<SeededRuntimePaperMainFamilyBundle, RuntimePaperMainFamilyBundleError> {
        let runtime_witness = self
            .runtime_refinement_witness()
            .map_err(RuntimePaperMainFamilyBundleError::RuntimeWitness)?
            .with_runtime_seed(0)
            .map_err(RuntimePaperMainFamilyBundleError::RuntimeWitness)?;
        let family = SeededRuntimePathOramWitnessFamily::new(vec![runtime_witness])
            .map_err(RuntimePaperMainFamilyBundleError::Family)?;
        SeededRuntimePaperMainFamilyBundle::new(family)
            .map_err(RuntimePaperMainFamilyBundleError::PaperMain)
    }

    pub fn runtime_paper_main_slot_family_bundle(
        &self,
        artifact: &crate::CompiledArtifact,
    ) -> Result<SeededRuntimePaperMainSlotFamilyBundle, RuntimePaperMainSlotFamilyBundleError> {
        let paper_main_bundle = self
            .runtime_paper_main_family_bundle()
            .map_err(RuntimePaperMainSlotFamilyBundleError::Family)?;
        let entrypoint = paper_main_bundle.public_outcome().entrypoint_id.clone();
        let confidential_slot_program = artifact
            .contract
            .manifest
            .entrypoints
            .get(&entrypoint)
            .ok_or_else(
                || RuntimePaperMainSlotFamilyBundleError::MissingEntrypoint {
                    entrypoint: entrypoint.clone(),
                },
            )?
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                RuntimePaperMainSlotFamilyBundleError::MissingConfidentialSlotProgram {
                    entrypoint: entrypoint.clone(),
                }
            })?;
        SeededRuntimePaperMainSlotFamilyBundle::new(
            paper_main_bundle.family().clone(),
            confidential_slot_program,
        )
        .map_err(RuntimePaperMainSlotFamilyBundleError::PaperMainSlot)
    }

    pub fn runtime_kernel_witness_for_confidential(
        &self,
        artifact: &crate::CompiledArtifact,
        entrypoint: &str,
    ) -> Result<RuntimeKernelWitness, KernelWitnessError> {
        let witness = self
            .runtime_kernel_witness
            .clone()
            .ok_or(KernelWitnessError::MissingKernelWitness)?;
        let function = artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .ok_or_else(|| KernelWitnessError::UnknownEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        if !function.confidential {
            return Err(KernelWitnessError::EntrypointNotConfidential {
                entrypoint: entrypoint.into(),
            });
        }
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| KernelWitnessError::MissingManifestEntrypoint {
                entrypoint: entrypoint.into(),
            })?;
        let public_object_ids = canonical_runtime_public_object_ids(&artifact.contract.state);
        witness.validate_for_confidential(entrypoint, manifest_entry, &public_object_ids)?;
        Ok(witness)
    }
}

#[cfg(test)]
fn collect_kernel_steps_from_expr(
    expr: &Expr,
    entrypoint: &str,
    steps: &mut Vec<RuntimeKernelStepWitness>,
) -> Result<(), KernelWitnessError> {
    steps.extend(
        lower_confidential_kernel_expr(expr, entrypoint)
            .map_err(KernelWitnessError::from)?
            .kernel_steps()
            .into_iter()
            .map(RuntimeKernelStepWitness::from),
    );
    Ok(())
}

impl SgxControllerShapeTrace {
    pub fn normalized_micro_trace(&self) -> NormalizedMicroTrace {
        let mut page_trace = Vec::new();
        for region in &self.page_trace_regions {
            for index in 0..region.event_budget {
                page_trace.push(NormalizedPageEvent {
                    page_kind: region.page_kind.clone(),
                    kind: if index % 2 == 0 {
                        PageEventKind::FaultIn
                    } else {
                        PageEventKind::EvictOut
                    },
                });
            }
        }
        let exit_pattern = (0..self.exit_trace_budget)
            .map(|index| {
                if index + 1 == self.exit_trace_budget {
                    ExitEvent::Terminate
                } else if index % 2 == 0 {
                    ExitEvent::Resume
                } else {
                    ExitEvent::InterruptExit
                }
            })
            .collect();
        let shared_resource_pattern =
            vec!["shared_resource_tick".into(); self.shared_resource_budget];
        NormalizedMicroTrace {
            page_trace,
            exit_pattern,
            shared_resource_pattern,
        }
    }
}

pub fn classify_write(old: &[u8], new: &[u8]) -> WriteClass {
    let old_zero = old.iter().all(|byte| *byte == 0);
    let new_zero = new.iter().all(|byte| *byte == 0);
    if old == new {
        WriteClass::Same
    } else if old_zero && !new_zero {
        WriteClass::Set
    } else if !old_zero && new_zero {
        WriteClass::Clear
    } else {
        WriteClass::Update
    }
}

fn hash_json<T: Serialize>(value: &T) -> String {
    let payload = serde_json::to_vec(value).expect("trace hashing requires serialization");
    let mut hasher = DefaultHasher::new();
    payload.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::{
        canonical_path_oram_leaf_seed_space_size, canonical_path_oram_seed_of_leaf_values,
        classify_write, collect_kernel_steps_from_expr,
        extract_runtime_path_oram_fresh_coin_scaffold, extract_runtime_path_oram_fresh_coin_values,
        max_runtime_kernel_refinement_event_count, CanonicalFreshCoinRuntimePathOramTheoremInput,
        CanonicalFreshCoinRuntimePathOramWitnessFamily, CanonicalFreshCoinTheoremInputError,
        CanonicalFreshCoinWitnessFamilyError, ExecutionTrace, ExitEvent, KernelWitnessError,
        LogicalEvent, NormalizedMicroTrace, NormalizedPageEvent, OutputShape, PageEventKind,
        PhysicalReadEvent, PhysicalWriteEvent, PublicOutcomeTrace, RefinementWitnessError,
        RuntimeControllerCertificate, RuntimeKernelExecutionTracker,
        RuntimeKernelRefinementEventWitness, RuntimeKernelRefinementTracker,
        RuntimeKernelRefinementTrackerError, RuntimeKernelRefinementWitness,
        RuntimeKernelRefinementWitnessError, RuntimeKernelStepWitness, RuntimeKernelWitness,
        RuntimeOramAccessWitness, RuntimeOramLeafScaffoldWitness, RuntimeOramLeafWitness,
        RuntimeOramObjectWitness, RuntimePaperMainSlotFamilyBundleError,
        RuntimePathOramPositionMapWitness, RuntimePathOramTransitionKind,
        RuntimePathOramTransitionWitness, RuntimeRefinementWitness,
        SeededRuntimePaperMainFamilyBundle, SeededRuntimePaperMainFamilyBundleError,
        SeededRuntimePaperMainSlotFamilyBundle, SeededRuntimePaperMainSlotFamilyBundleError,
        SeededRuntimePathOramWitnessFamily, SeededRuntimeWitnessFamilyError, TheoremTrace,
        WriteClass,
    };
    use crate::{
        CompiledArtifact, CompiledContract, CompiledFunction, ConfidentialKernelSlotExpr,
        ConfidentialKernelSlotProgram, ConfidentialKernelSlotStatement, EntrypointManifest, Expr,
        ProgramMode, RuntimeManifest, Value,
    };
    use std::collections::BTreeMap;
    use uo_precompiles::UoOpcode;

    #[test]
    fn write_classifier_matches_m_plus_partition() {
        assert_eq!(classify_write(&[0, 0], &[0, 0]), WriteClass::Same);
        assert_eq!(classify_write(&[0, 0], &[1, 2]), WriteClass::Set);
        assert_eq!(classify_write(&[1, 2], &[0, 0]), WriteClass::Clear);
        assert_eq!(classify_write(&[1, 2], &[2, 3]), WriteClass::Update);
    }

    #[test]
    fn runtime_kernel_refinement_event_bound_matches_public_objects_and_kernel_ops() {
        assert_eq!(max_runtime_kernel_refinement_event_count(0, 3).unwrap(), 3);
        assert_eq!(max_runtime_kernel_refinement_event_count(2, 4).unwrap(), 14);
    }

    #[test]
    fn runtime_kernel_refinement_tracker_rejects_push_past_bound() {
        let mut tracker =
            RuntimeKernelRefinementTracker::with_public_object_count_and_kernel_ops(0, 1).unwrap();
        tracker.push_kernel_step(UoOpcode::Begin, None).unwrap();
        let err = tracker
            .push_kernel_step(UoOpcode::Commit, None)
            .unwrap_err();
        assert_eq!(
            err,
            RuntimeKernelRefinementTrackerError::EventCapacityExceeded {
                attempted_events: 2,
                max_events: 1,
            }
        );
    }

    #[test]
    fn runtime_kernel_execution_tracker_rejects_push_past_bound() {
        let mut tracker = RuntimeKernelExecutionTracker::with_kernel_op_budget(1);
        tracker
            .record_step(RuntimeKernelStepWitness::new(UoOpcode::Begin, None).unwrap())
            .unwrap();
        let err = tracker
            .record_step(RuntimeKernelStepWitness::new(UoOpcode::Commit, None).unwrap())
            .unwrap_err();
        assert_eq!(
            err,
            KernelWitnessError::KernelStepBudgetExceeded {
                attempted_steps: 2,
                budget: 1,
            }
        );
    }

    #[test]
    fn kernel_witness_validation_rejects_select_arm_outside_branchless_fragment() {
        let expr = Expr::Select {
            cond: Box::new(Expr::Var("cond".into())),
            when_true: Box::new(Expr::ArrayIndex {
                base: Box::new(Expr::Literal(Value::Array(vec![Value::Uint(1)]))),
                index: Box::new(Expr::Literal(Value::Uint(0))),
            }),
            when_false: Box::new(Expr::Literal(Value::Uint(0))),
        };
        let err =
            collect_kernel_steps_from_expr(&expr, "auth(bytes32)", &mut Vec::new()).unwrap_err();
        assert_eq!(
            err,
            KernelWitnessError::SelectArmOutsideBranchlessFragment {
                entrypoint: "auth(bytes32)".into()
            }
        );
    }

    #[test]
    fn kernel_witness_validation_rejects_confidential_array_index() {
        let expr = Expr::ArrayIndex {
            base: Box::new(Expr::Literal(Value::Array(vec![Value::Uint(1)]))),
            index: Box::new(Expr::Literal(Value::Uint(0))),
        };
        let err =
            collect_kernel_steps_from_expr(&expr, "auth(bytes32)", &mut Vec::new()).unwrap_err();
        assert_eq!(
            err,
            KernelWitnessError::ConfidentialArrayIndex {
                entrypoint: "auth(bytes32)".into()
            }
        );
    }

    #[test]
    fn kernel_witness_validation_rejects_confidential_struct_field() {
        let expr = Expr::StructField {
            base: Box::new(Expr::Literal(Value::Struct(vec![(
                "flag".into(),
                Value::Bool(true),
            )]))),
            field: "flag".into(),
        };
        let err =
            collect_kernel_steps_from_expr(&expr, "auth(bytes32)", &mut Vec::new()).unwrap_err();
        assert_eq!(
            err,
            KernelWitnessError::ConfidentialStructField {
                entrypoint: "auth(bytes32)".into()
            }
        );
    }

    fn sample_public_outcome(gas_used: u64) -> PublicOutcomeTrace {
        PublicOutcomeTrace {
            entrypoint_id: "put(bytes32,uint256)".into(),
            public_args: vec![],
            termination_status: true,
            output_shape: OutputShape::default(),
            gas_used,
        }
    }

    fn sample_controller_certificate() -> RuntimeControllerCertificate {
        RuntimeControllerCertificate {
            entry_input_len: 64,
            observed_oram_accesses: vec![RuntimeOramAccessWitness {
                object_id: 7,
                scheme: "path_oram_local_posmap_v1".into(),
                metadata_pages_per_access: 2,
                buckets_per_access: 5,
                recursion_depth: 1,
                stash_bound: 4,
            }],
        }
    }

    fn sample_oram_object() -> RuntimeOramObjectWitness {
        RuntimeOramObjectWitness {
            object_id: 7,
            object_name: "records".into(),
            scheme: "path_oram_local_posmap_v1".into(),
            capacity: 16,
            block_size: 64,
            bucket_size: 384,
            bucket_count: 31,
            blocks_per_bucket: 5,
            tree_height: 4,
            stash_bound: 4,
            recursion_depth: 1,
            metadata_pages: 1,
            metadata_pages_per_access: 2,
            buckets_per_access: 5,
            accesses_per_call: 1,
        }
    }

    fn sample_oram_logical_accesses() -> Vec<LogicalEvent> {
        vec![
            LogicalEvent {
                kind: "uooram_counter".into(),
                object: "records".into(),
                detail: "counter".into(),
            },
            LogicalEvent {
                kind: "uooram_metadata_load".into(),
                object: "records".into(),
                detail: "page:0".into(),
            },
            LogicalEvent {
                kind: "uooram_path_read".into(),
                object: "records".into(),
                detail: "bucket:0".into(),
            },
            LogicalEvent {
                kind: "uooram_path_read".into(),
                object: "records".into(),
                detail: "bucket:1".into(),
            },
            LogicalEvent {
                kind: "uooram_path_read".into(),
                object: "records".into(),
                detail: "bucket:3".into(),
            },
            LogicalEvent {
                kind: "uooram_path_read".into(),
                object: "records".into(),
                detail: "bucket:7".into(),
            },
            LogicalEvent {
                kind: "uooram_path_read".into(),
                object: "records".into(),
                detail: "bucket:15".into(),
            },
        ]
    }

    fn sample_path_bucket_indices() -> Vec<usize> {
        vec![0, 1, 3, 7, 15]
    }

    fn sample_oram_leaf_schedule() -> Vec<RuntimeOramLeafWitness> {
        vec![RuntimeOramLeafWitness {
            object_id: 7,
            object_name: "records".into(),
            bucket_count: 31,
            leaf: 0,
        }]
    }

    fn sample_path_oram_position_map_before() -> Vec<RuntimePathOramPositionMapWitness> {
        let mut leaves = vec![None; 16];
        leaves[0] = Some(0);
        vec![RuntimePathOramPositionMapWitness {
            object_id: 7,
            object_name: "records".into(),
            leaves,
        }]
    }

    fn sample_path_oram_position_map_after() -> Vec<RuntimePathOramPositionMapWitness> {
        let mut leaves = vec![None; 16];
        leaves[0] = Some(3);
        vec![RuntimePathOramPositionMapWitness {
            object_id: 7,
            object_name: "records".into(),
            leaves,
        }]
    }

    fn sample_path_oram_leaf_state_transitions() -> Vec<RuntimePathOramTransitionWitness> {
        vec![RuntimePathOramTransitionWitness {
            object_id: 7,
            object_name: "records".into(),
            bucket_count: 31,
            kind: RuntimePathOramTransitionKind::ReadHit,
            slot_index: Some(0),
            prior_leaf: Some(0),
            next_leaf: Some(3),
        }]
    }

    fn sample_runtime_execution_trace_with_seed(seed: u64) -> ExecutionTrace {
        let controller_certificate = sample_controller_certificate();
        let public_outcome = sample_public_outcome(99);
        let controller_shape = controller_certificate.controller_shape();
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let path = sample_path_bucket_indices();
        ExecutionTrace {
            opcode_trace: vec!["declare".into()],
            logical_accesses: sample_oram_logical_accesses(),
            logical_writes: vec![],
            physical_reads: path
                .iter()
                .map(|index| PhysicalReadEvent {
                    object: "records".into(),
                    location: format!("records@bucket{index}"),
                    len: 64,
                })
                .collect(),
            physical_writes: path
                .iter()
                .rev()
                .map(|index| {
                    PhysicalWriteEvent::from_shape(
                        "records",
                        format!("records@bucket{index}"),
                        2,
                        WriteClass::Update,
                    )
                })
                .collect(),
            gas_used: 99,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(normalized_micro_trace.clone()),
            },
            runtime_seed: Some(seed),
            runtime_kernel_witness: None,
            runtime_kernel_refinement_witness: None,
            runtime_trusted_kernel_bundle: None,
            runtime_controller_certificate: Some(controller_certificate),
            runtime_oram_objects: vec![sample_oram_object()],
            runtime_oram_leaf_schedule: sample_oram_leaf_schedule(),
            runtime_oram_access_counters_before: vec![],
            runtime_oram_access_counters_after: vec![],
            runtime_oram_position_map_before: sample_path_oram_position_map_before(),
            runtime_oram_position_map_after: sample_path_oram_position_map_after(),
            runtime_oram_leaf_state_transitions: sample_path_oram_leaf_state_transitions(),
        }
    }

    fn sample_runtime_refinement_witness_with_seed(seed: u64) -> super::RuntimeRefinementWitness {
        sample_runtime_execution_trace_with_seed(seed)
            .runtime_refinement_witness()
            .unwrap()
    }

    fn sample_runtime_refinement_witness_with_seed_and_kernel(
        seed: u64,
    ) -> super::RuntimeRefinementWitness {
        let mut witness = sample_runtime_refinement_witness_with_seed(seed);
        witness.kernel_witness = Some(sample_runtime_kernel_witness());
        witness.runtime_kernel_refinement_witness =
            Some(sample_runtime_kernel_refinement_witness());
        witness
    }

    fn sample_runtime_kernel_witness() -> RuntimeKernelWitness {
        RuntimeKernelWitness {
            entrypoint_id: "put(bytes32,uint256)".into(),
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            peak_stack_words: 0,
            value_scratch_peak_bytes: 0,
            value_scratch_live_bytes_end: 0,
            value_scratch_wipe_count: 0,
            hash_scratch_peak_bytes: 0,
            hash_scratch_live_bytes_end: 0,
            hash_scratch_wipe_count: 0,
            io_scratch_peak_bytes: 0,
            io_scratch_live_bytes_end: 0,
            io_scratch_wipe_count: 0,
            resource_events: vec![],
            expected_kernel_steps: Some(vec![
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Begin,
                    object_id: None,
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::CellGet,
                    object_id: Some(7),
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Commit,
                    object_id: None,
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Wipe,
                    object_id: None,
                },
            ]),
            public_object_ids: vec![7],
            expected_public_object_ids: Some(vec![7]),
            kernel_steps: vec![
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Begin,
                    object_id: None,
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::CellGet,
                    object_id: Some(7),
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Commit,
                    object_id: None,
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Wipe,
                    object_id: None,
                },
            ],
        }
    }

    fn sample_runtime_paper_main_slot_program() -> ConfidentialKernelSlotProgram {
        ConfidentialKernelSlotProgram {
            entrypoint_id: "put(bytes32,uint256)".into(),
            param_count: 0,
            return_type: None,
            secret_args: vec![],
            slot_count: 1,
            body: vec![
                ConfidentialKernelSlotStatement::Declare {
                    slot: 0,
                    value: ConfidentialKernelSlotExpr::CellGet { object_id: 7 },
                },
                ConfidentialKernelSlotStatement::Return { value: None },
            ],
        }
    }

    fn sample_runtime_paper_main_artifact() -> CompiledArtifact {
        let confidential_slot_program = sample_runtime_paper_main_slot_program();
        let entrypoint = confidential_slot_program.entrypoint_id.clone();
        let mut entrypoints = BTreeMap::new();
        entrypoints.insert(
            entrypoint.clone(),
            EntrypointManifest {
                secret_args: vec![],
                param_names: vec![],
                entry_input_len: 0,
                public_gas_budget: 99,
                arena_bytes: 0,
                max_stack_words: 0,
                max_hash_part_bytes: 0,
                return_canonical_len: None,
                confidential_program: None,
                confidential_slot_program: Some(confidential_slot_program.clone()),
                kernel_steps: vec![],
                uocell_reads: 0,
                uocell_writes: 0,
                uoarray_reads: 0,
                uoarray_writes: 0,
                uomap_reads: 0,
                uomap_writes: 0,
                max_commit_ops: 0,
                oram_accesses: BTreeMap::new(),
            },
        );
        CompiledArtifact {
            compiler_version: "test".into(),
            contract: CompiledContract {
                contract: "PaperMainTest".into(),
                mode: ProgramMode::Uo,
                source_file: "paper_main_test.sol".into(),
                state: vec![],
                functions: vec![CompiledFunction {
                    signature: entrypoint,
                    params: vec![],
                    return_type: None,
                    body: vec![],
                    secret_args: vec![],
                    confidential: true,
                    confidential_program: None,
                    confidential_slot_program: Some(confidential_slot_program),
                }],
                manifest: RuntimeManifest {
                    contract: "PaperMainTest".into(),
                    compilation_mode: "uo".into(),
                    objects: vec![],
                    entrypoints,
                },
            },
            diagnostics: vec![],
            transformed_source: None,
            disassembly: vec![],
        }
    }

    fn sample_runtime_kernel_refinement_witness() -> RuntimeKernelRefinementWitness {
        RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
            RuntimeKernelRefinementEventWitness::shadow_load_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(7)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
            RuntimeKernelRefinementEventWitness::commit_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Wipe, None),
            RuntimeKernelRefinementEventWitness::cold_store_object(7),
            RuntimeKernelRefinementEventWitness::post_committed_cold_object(7),
        ])
        .expect("sample runtime kernel refinement witness should be well-formed")
    }

    fn sample_read_miss_oram_object() -> RuntimeOramObjectWitness {
        RuntimeOramObjectWitness {
            object_id: 9,
            object_name: "tiny_records".into(),
            scheme: "path_oram_local_posmap_v1".into(),
            capacity: 4,
            block_size: 64,
            bucket_size: 64,
            bucket_count: 1,
            blocks_per_bucket: 1,
            tree_height: 0,
            stash_bound: 4,
            recursion_depth: 1,
            metadata_pages: 1,
            metadata_pages_per_access: 1,
            buckets_per_access: 1,
            accesses_per_call: 1,
        }
    }

    fn sample_read_miss_logical_accesses() -> Vec<LogicalEvent> {
        vec![
            LogicalEvent {
                kind: "uooram_counter".into(),
                object: "tiny_records".into(),
                detail: "counter".into(),
            },
            LogicalEvent {
                kind: "uooram_metadata_load".into(),
                object: "tiny_records".into(),
                detail: "page:0".into(),
            },
            LogicalEvent {
                kind: "uooram_path_read".into(),
                object: "tiny_records".into(),
                detail: "bucket:0".into(),
            },
        ]
    }

    fn sample_read_miss_runtime_refinement_witness() -> super::RuntimeRefinementWitness {
        let controller_certificate = RuntimeControllerCertificate {
            entry_input_len: 64,
            observed_oram_accesses: vec![RuntimeOramAccessWitness {
                object_id: 9,
                scheme: "path_oram_local_posmap_v1".into(),
                metadata_pages_per_access: 1,
                buckets_per_access: 1,
                recursion_depth: 1,
                stash_bound: 4,
            }],
        };
        let public_outcome = sample_public_outcome(7);
        let controller_shape = controller_certificate.controller_shape();
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let trace = ExecutionTrace {
            opcode_trace: vec!["declare".into()],
            logical_accesses: sample_read_miss_logical_accesses(),
            logical_writes: vec![],
            physical_reads: vec![PhysicalReadEvent {
                object: "tiny_records".into(),
                location: "tiny_records@bucket0".into(),
                len: 64,
            }],
            physical_writes: vec![PhysicalWriteEvent::from_shape(
                "tiny_records",
                "tiny_records@bucket0",
                1,
                WriteClass::Update,
            )],
            gas_used: 7,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(normalized_micro_trace),
            },
            runtime_controller_certificate: Some(controller_certificate),
            runtime_oram_objects: vec![sample_read_miss_oram_object()],
            runtime_oram_leaf_schedule: vec![RuntimeOramLeafWitness {
                object_id: 9,
                object_name: "tiny_records".into(),
                bucket_count: 1,
                leaf: 0,
            }],
            runtime_oram_access_counters_before: vec![],
            runtime_oram_access_counters_after: vec![],
            runtime_oram_position_map_before: vec![RuntimePathOramPositionMapWitness {
                object_id: 9,
                object_name: "tiny_records".into(),
                leaves: vec![None; 4],
            }],
            runtime_oram_position_map_after: vec![RuntimePathOramPositionMapWitness {
                object_id: 9,
                object_name: "tiny_records".into(),
                leaves: vec![None; 4],
            }],
            runtime_oram_leaf_state_transitions: vec![RuntimePathOramTransitionWitness {
                object_id: 9,
                object_name: "tiny_records".into(),
                bucket_count: 1,
                kind: RuntimePathOramTransitionKind::ReadMiss,
                slot_index: None,
                prior_leaf: None,
                next_leaf: None,
            }],
            ..ExecutionTrace::default()
        };
        trace.runtime_refinement_witness().unwrap()
    }

    #[test]
    fn runtime_refinement_witness_normalizes_controller_shape() {
        let controller_certificate = sample_controller_certificate();
        let controller_shape = controller_certificate.controller_shape();
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let trace = sample_runtime_execution_trace_with_seed(0);
        let witness = trace.runtime_refinement_witness().unwrap();
        assert_eq!(witness.public_outcome.gas_used, 99);
        assert_eq!(witness.trace.physical_writes[0].write_class, "Update");
        assert_eq!(witness.trace.physical_writes[0].len, 2);
        assert_eq!(witness.controller_shape, controller_shape);
        assert_eq!(witness.normalized_micro_trace, normalized_micro_trace);
        assert_eq!(witness.controller_certificate, controller_certificate);
        assert_eq!(witness.oram_objects, vec![sample_oram_object()]);
    }

    #[test]
    fn runtime_refinement_witness_validate_accepts_sample() {
        let witness = sample_runtime_refinement_witness_with_seed(0);
        witness.validate().unwrap();
    }

    #[test]
    fn runtime_refinement_witness_with_runtime_seed_retains_validity() {
        let witness = sample_runtime_refinement_witness_with_seed(19)
            .with_runtime_seed(0)
            .unwrap();
        assert_eq!(witness.runtime_seed(), Some(0));
        witness.validate().unwrap();
    }

    #[test]
    fn runtime_kernel_refinement_witness_validate_accepts_matching_projection() {
        let kernel_witness = sample_runtime_kernel_witness();
        let refinement_witness = sample_runtime_kernel_refinement_witness();
        refinement_witness
            .validate_with_kernel_witness(&kernel_witness)
            .unwrap();
        assert_eq!(
            refinement_witness.projected_kernel_schedule(),
            kernel_witness.emitted_kernel_schedule()
        );
    }

    #[test]
    fn runtime_kernel_refinement_witness_append_commit_object_schedule_requires_commit_window() {
        let mut refinement_witness = RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
        ])
        .expect("commit-window precondition witness should be well-formed");
        assert_eq!(
            refinement_witness
                .append_commit_object_schedule(vec![7])
                .unwrap_err(),
            RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                witnessed: refinement_witness.events().to_vec(),
            }
        );
    }

    #[test]
    fn runtime_kernel_refinement_witness_append_cold_store_window_completes_tail() {
        let mut refinement_witness = RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
            RuntimeKernelRefinementEventWitness::shadow_load_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(7)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
            RuntimeKernelRefinementEventWitness::commit_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Wipe, None),
        ])
        .expect("cold-store completion witness should be well-formed");
        refinement_witness.append_cold_store_window(&[7]).unwrap();
        assert_eq!(
            refinement_witness,
            sample_runtime_kernel_refinement_witness()
        );
    }

    #[test]
    fn runtime_kernel_refinement_witness_append_cold_store_window_requires_after_wipe() {
        let mut refinement_witness = RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
            RuntimeKernelRefinementEventWitness::shadow_load_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(7)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
            RuntimeKernelRefinementEventWitness::commit_object(7),
        ])
        .expect("after-wipe precondition witness should be well-formed");
        assert_eq!(
            refinement_witness
                .append_cold_store_window(&[7])
                .unwrap_err(),
            RuntimeKernelRefinementWitnessError::MalformedRuntimePhaseTrace {
                witnessed: refinement_witness.events().to_vec(),
            }
        );
    }

    #[test]
    fn runtime_kernel_refinement_witness_rejects_missing_boundary_cold_schedules() {
        let kernel_witness = sample_runtime_kernel_witness();
        let refinement_witness = RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
            RuntimeKernelRefinementEventWitness::shadow_load_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(7)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
            RuntimeKernelRefinementEventWitness::commit_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Wipe, None),
            RuntimeKernelRefinementEventWitness::cold_store_object(7),
        ])
        .expect("boundary schedule mismatch witness should remain phase-valid");
        assert_eq!(
            refinement_witness
                .validate_with_kernel_witness(&kernel_witness)
                .unwrap_err(),
            RuntimeKernelRefinementWitnessError::PreCommittedColdObjectScheduleMismatch {
                expected: vec![7],
                witnessed: vec![],
            }
        );
    }

    #[test]
    fn runtime_refinement_witness_rejects_runtime_phase_witness_without_kernel() {
        let mut trace = sample_runtime_execution_trace_with_seed(0);
        trace.runtime_kernel_refinement_witness = Some(sample_runtime_kernel_refinement_witness());
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::RuntimeKernelRefinement(
                RuntimeKernelRefinementWitnessError::MissingKernelWitness
            )
        );
    }

    #[test]
    fn runtime_refinement_witness_rejects_runtime_phase_projection_drift() {
        let mut trace = sample_runtime_execution_trace_with_seed(0);
        trace.runtime_kernel_witness = Some(sample_runtime_kernel_witness());
        let mut refinement_events = sample_runtime_kernel_refinement_witness().events().to_vec();
        refinement_events[3] =
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellSet, Some(7));
        let refinement_witness = RuntimeKernelRefinementWitness::from_events(refinement_events)
            .expect("projection drift witness should remain phase-valid");
        trace.runtime_kernel_refinement_witness = Some(refinement_witness);
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::RuntimeKernelRefinement(
                RuntimeKernelRefinementWitnessError::KernelProjectionMismatch {
                    expected: sample_runtime_kernel_witness().kernel_steps,
                    witnessed: vec![
                        RuntimeKernelStepWitness {
                            opcode: UoOpcode::Begin,
                            object_id: None,
                        },
                        RuntimeKernelStepWitness {
                            opcode: UoOpcode::CellSet,
                            object_id: Some(7),
                        },
                        RuntimeKernelStepWitness {
                            opcode: UoOpcode::Commit,
                            object_id: None,
                        },
                        RuntimeKernelStepWitness {
                            opcode: UoOpcode::Wipe,
                            object_id: None,
                        },
                    ],
                }
            )
        );
    }

    #[test]
    fn runtime_kernel_refinement_witness_rejects_noncanonical_object_schedule() {
        let kernel_witness = RuntimeKernelWitness {
            entrypoint_id: "demo()".into(),
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            peak_stack_words: 0,
            value_scratch_peak_bytes: 0,
            value_scratch_live_bytes_end: 0,
            value_scratch_wipe_count: 0,
            hash_scratch_peak_bytes: 0,
            hash_scratch_live_bytes_end: 0,
            hash_scratch_wipe_count: 0,
            io_scratch_peak_bytes: 0,
            io_scratch_live_bytes_end: 0,
            io_scratch_wipe_count: 0,
            resource_events: vec![],
            expected_kernel_steps: None,
            public_object_ids: vec![7, 9],
            expected_public_object_ids: None,
            kernel_steps: vec![
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Begin,
                    object_id: None,
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::CellGet,
                    object_id: Some(9),
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(7),
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Commit,
                    object_id: None,
                },
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Wipe,
                    object_id: None,
                },
            ],
        };
        let refinement_witness = RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(9),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
            RuntimeKernelRefinementEventWitness::shadow_load_object(9),
            RuntimeKernelRefinementEventWitness::shadow_load_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(9)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::MapGet, Some(7)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
            RuntimeKernelRefinementEventWitness::commit_object(9),
            RuntimeKernelRefinementEventWitness::commit_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Wipe, None),
            RuntimeKernelRefinementEventWitness::cold_store_object(9),
            RuntimeKernelRefinementEventWitness::cold_store_object(7),
            RuntimeKernelRefinementEventWitness::post_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::post_committed_cold_object(9),
        ])
        .expect("noncanonical schedule witness should remain phase-valid");
        assert_eq!(
            refinement_witness
                .validate_with_kernel_witness(&kernel_witness)
                .unwrap_err(),
            RuntimeKernelRefinementWitnessError::CanonicalObjectScheduleMismatch {
                expected: vec![7, 9],
                witnessed: vec![9, 7],
            }
        );
    }

    #[test]
    fn runtime_kernel_refinement_witness_rejects_missing_cold_store_schedule() {
        let kernel_witness = sample_runtime_kernel_witness();
        let refinement_witness = RuntimeKernelRefinementWitness::from_events(vec![
            RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
            RuntimeKernelRefinementEventWitness::shadow_load_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(7)),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
            RuntimeKernelRefinementEventWitness::commit_object(7),
            RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Wipe, None),
            RuntimeKernelRefinementEventWitness::post_committed_cold_object(7),
        ])
        .expect("missing cold-store witness should remain phase-valid");
        assert_eq!(
            refinement_witness
                .validate_with_kernel_witness(&kernel_witness)
                .unwrap_err(),
            RuntimeKernelRefinementWitnessError::ObjectScheduleMismatch {
                loaded: vec![7],
                committed: vec![7],
                cold_stored: vec![],
            }
        );
    }

    #[test]
    fn runtime_refinement_witness_from_certificates_matches_trace_extraction() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let controller_observer = trace.runtime_controller_observer_certificate().unwrap();
        let hidden_certificate = trace.runtime_path_oram_hidden_certificate().unwrap();
        let direct = RuntimeRefinementWitness::from_certificates(
            trace.runtime_seed,
            controller_observer,
            hidden_certificate,
        )
        .unwrap();
        assert_eq!(direct, trace.runtime_refinement_witness().unwrap());
    }

    #[test]
    fn runtime_trusted_kernel_bundle_matches_trace_extraction() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        assert_eq!(bundle.runtime_seed, Some(0));
        assert_eq!(
            bundle.controller_observer,
            trace.runtime_controller_observer_certificate().unwrap()
        );
        assert_eq!(
            bundle.hidden_certificate,
            trace.runtime_path_oram_hidden_certificate().unwrap()
        );
        assert_eq!(
            bundle.to_witness().unwrap(),
            trace.runtime_refinement_witness().unwrap()
        );
    }

    #[test]
    fn runtime_trusted_kernel_bundle_uses_stored_kernel_on_matching_trace() {
        let mut trace = sample_runtime_execution_trace_with_seed(0);
        let bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        trace.runtime_trusted_kernel_bundle = Some(bundle.clone());
        assert_eq!(trace.runtime_trusted_kernel_bundle().unwrap(), bundle);
        assert_eq!(
            trace.runtime_refinement_witness().unwrap(),
            bundle.to_witness().unwrap()
        );
    }

    #[test]
    fn runtime_trusted_kernel_bundle_rejects_stored_controller_observer_drift_from_trace() {
        let mut trace = sample_runtime_execution_trace_with_seed(0);
        let bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        trace.runtime_trusted_kernel_bundle = Some(bundle);
        trace.theorem_trace = TheoremTrace::default();
        trace.runtime_controller_certificate = None;
        assert_eq!(
            trace.runtime_trusted_kernel_bundle().unwrap_err(),
            RefinementWitnessError::MissingPublicOutcome
        );
    }

    #[test]
    fn runtime_trusted_kernel_bundle_rejects_stored_hidden_certificate_drift_from_trace() {
        let mut trace = sample_runtime_execution_trace_with_seed(0);
        let bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        trace.runtime_trusted_kernel_bundle = Some(bundle);
        trace.runtime_oram_position_map_after = vec![];
        assert_eq!(
            trace.runtime_trusted_kernel_bundle().unwrap_err(),
            RefinementWitnessError::OramLeafStateMismatch
        );
    }

    #[test]
    fn runtime_trusted_kernel_bundle_rejects_invalid_stored_kernel() {
        let mut trace = sample_runtime_execution_trace_with_seed(0);
        let mut bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        bundle.hidden_certificate.oram_position_map_after[0].leaves[0] = Some(2);
        trace.runtime_trusted_kernel_bundle = Some(bundle);
        assert_eq!(
            trace.runtime_trusted_kernel_bundle().unwrap_err(),
            RefinementWitnessError::TrustedKernelBundleTraceMismatch
        );
    }

    #[test]
    fn runtime_trusted_kernel_bundle_validate_accepts_sample() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        bundle.validate().unwrap();
    }

    #[test]
    fn runtime_trusted_kernel_bundle_rejects_controller_certificate_drift() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let mut bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        bundle
            .controller_observer
            .controller_certificate
            .observed_oram_accesses[0]
            .recursion_depth = 0;
        assert_eq!(
            bundle.validate().unwrap_err(),
            RefinementWitnessError::ControllerShapeMismatch
        );
    }

    #[test]
    fn runtime_trusted_kernel_bundle_rejects_path_oram_state_drift() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let mut bundle = trace.runtime_trusted_kernel_bundle().unwrap();
        bundle.hidden_certificate.oram_position_map_after[0].leaves[0] = Some(2);
        assert_eq!(
            bundle.to_witness().unwrap_err(),
            RefinementWitnessError::OramLeafStateMismatch
        );
    }

    #[test]
    fn execution_trace_exports_controller_observer_certificate() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let certificate = trace.runtime_controller_observer_certificate().unwrap();
        assert_eq!(certificate.public_outcome.gas_used, 99);
        assert_eq!(
            certificate.boundary_schedule,
            certificate
                .controller_certificate
                .boundary_schedule(&certificate.public_outcome)
        );
        assert_eq!(
            certificate.controller_shape,
            certificate.controller_certificate.controller_shape()
        );
        assert_eq!(
            certificate.normalized_micro_trace,
            certificate.controller_shape.normalized_micro_trace()
        );
    }

    #[test]
    fn execution_trace_exports_path_oram_hidden_certificate() {
        let trace = sample_runtime_execution_trace_with_seed(0);
        let certificate = trace.runtime_path_oram_hidden_certificate().unwrap();
        assert_eq!(certificate.oram_objects, vec![sample_oram_object()]);
        assert_eq!(certificate.oram_leaf_schedule, sample_oram_leaf_schedule());
        assert_eq!(
            certificate.oram_leaf_public_scaffold,
            vec![RuntimeOramLeafScaffoldWitness {
                object_id: 7,
                object_name: "records".into(),
                bucket_count: 31,
            }]
        );
        certificate.validate().unwrap();
    }

    #[test]
    fn runtime_refinement_witness_rejects_inconsistent_micro_trace() {
        let controller_certificate = RuntimeControllerCertificate::default();
        let public_outcome = PublicOutcomeTrace {
            entrypoint_id: "f()".into(),
            public_args: vec![],
            termination_status: true,
            output_shape: OutputShape::default(),
            gas_used: 1,
        };
        let controller_shape = controller_certificate.controller_shape();
        let trace = ExecutionTrace {
            gas_used: 1,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape),
                normalized_micro_trace: Some(NormalizedMicroTrace {
                    page_trace: vec![NormalizedPageEvent {
                        page_kind: "metadata".into(),
                        kind: PageEventKind::EvictOut,
                    }],
                    exit_pattern: vec![ExitEvent::Terminate],
                    shared_resource_pattern: vec![],
                }),
            },
            runtime_controller_certificate: Some(controller_certificate),
            ..ExecutionTrace::default()
        };
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::NormalizedMicroTraceMismatch
        );
    }

    #[test]
    fn runtime_refinement_witness_rejects_controller_certificate_drift() {
        let public_outcome = sample_public_outcome(7);
        let controller_certificate = sample_controller_certificate();
        let mut drifted_certificate = controller_certificate.clone();
        drifted_certificate.observed_oram_accesses[0].recursion_depth = 0;
        let controller_shape = controller_certificate.controller_shape();
        let trace = ExecutionTrace {
            gas_used: 7,
            logical_accesses: sample_oram_logical_accesses(),
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape),
                normalized_micro_trace: Some(
                    controller_certificate
                        .controller_shape()
                        .normalized_micro_trace(),
                ),
            },
            runtime_controller_certificate: Some(drifted_certificate),
            runtime_oram_objects: vec![sample_oram_object()],
            ..ExecutionTrace::default()
        };
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::ControllerShapeMismatch
        );
    }

    #[test]
    fn runtime_refinement_witness_rejects_logical_trace_schedule_drift() {
        let public_outcome = sample_public_outcome(7);
        let controller_certificate = sample_controller_certificate();
        let controller_shape = controller_certificate.controller_shape();
        let mut logical_accesses = sample_oram_logical_accesses();
        logical_accesses.remove(1);
        let trace = ExecutionTrace {
            gas_used: 7,
            logical_accesses,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(controller_shape.normalized_micro_trace()),
            },
            runtime_controller_certificate: Some(controller_certificate),
            runtime_oram_objects: vec![sample_oram_object()],
            ..ExecutionTrace::default()
        };
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::MalformedOramLogicalTrace {
                object: "records".into(),
                expected_kind: "uooram_metadata_load".into(),
                detail_prefix: "page:".into(),
            }
        );
    }

    #[test]
    fn runtime_refinement_witness_rejects_path_oram_state_drift() {
        let controller_certificate = sample_controller_certificate();
        let public_outcome = sample_public_outcome(99);
        let controller_shape = controller_certificate.controller_shape();
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let path = sample_path_bucket_indices();
        let mut drifted_after = sample_path_oram_position_map_after();
        drifted_after[0].leaves[0] = Some(2);
        let trace = ExecutionTrace {
            opcode_trace: vec!["declare".into()],
            logical_accesses: sample_oram_logical_accesses(),
            logical_writes: vec![],
            physical_reads: path
                .iter()
                .map(|index| PhysicalReadEvent {
                    object: "records".into(),
                    location: format!("records@bucket{index}"),
                    len: 64,
                })
                .collect(),
            physical_writes: path
                .iter()
                .rev()
                .map(|index| {
                    PhysicalWriteEvent::from_shape(
                        "records",
                        format!("records@bucket{index}"),
                        2,
                        WriteClass::Update,
                    )
                })
                .collect(),
            gas_used: 99,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(normalized_micro_trace.clone()),
            },
            runtime_seed: None,
            runtime_kernel_witness: None,
            runtime_kernel_refinement_witness: None,
            runtime_trusted_kernel_bundle: None,
            runtime_controller_certificate: Some(controller_certificate),
            runtime_oram_objects: vec![sample_oram_object()],
            runtime_oram_leaf_schedule: sample_oram_leaf_schedule(),
            runtime_oram_access_counters_before: vec![],
            runtime_oram_access_counters_after: vec![],
            runtime_oram_position_map_before: sample_path_oram_position_map_before(),
            runtime_oram_position_map_after: drifted_after,
            runtime_oram_leaf_state_transitions: sample_path_oram_leaf_state_transitions(),
        };
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::OramLeafStateMismatch
        );
    }

    #[test]
    fn runtime_path_oram_hidden_certificate_rejects_path_oram_state_drift() {
        let controller_certificate = sample_controller_certificate();
        let public_outcome = sample_public_outcome(99);
        let controller_shape = controller_certificate.controller_shape();
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let path = sample_path_bucket_indices();
        let mut drifted_after = sample_path_oram_position_map_after();
        drifted_after[0].leaves[0] = Some(2);
        let trace = ExecutionTrace {
            opcode_trace: vec!["declare".into()],
            logical_accesses: sample_oram_logical_accesses(),
            logical_writes: vec![],
            physical_reads: path
                .iter()
                .map(|index| PhysicalReadEvent {
                    object: "records".into(),
                    location: format!("records@bucket{index}"),
                    len: 64,
                })
                .collect(),
            physical_writes: path
                .iter()
                .rev()
                .map(|index| {
                    PhysicalWriteEvent::from_shape(
                        "records",
                        format!("records@bucket{index}"),
                        2,
                        WriteClass::Update,
                    )
                })
                .collect(),
            gas_used: 99,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(normalized_micro_trace.clone()),
            },
            runtime_seed: None,
            runtime_kernel_witness: None,
            runtime_kernel_refinement_witness: None,
            runtime_trusted_kernel_bundle: None,
            runtime_controller_certificate: Some(controller_certificate),
            runtime_oram_objects: vec![sample_oram_object()],
            runtime_oram_leaf_schedule: sample_oram_leaf_schedule(),
            runtime_oram_access_counters_before: vec![],
            runtime_oram_access_counters_after: vec![],
            runtime_oram_position_map_before: sample_path_oram_position_map_before(),
            runtime_oram_position_map_after: drifted_after,
            runtime_oram_leaf_state_transitions: sample_path_oram_leaf_state_transitions(),
        };
        assert_eq!(
            trace.runtime_path_oram_hidden_certificate().unwrap_err(),
            RefinementWitnessError::OramLeafStateMismatch
        );
    }

    #[test]
    fn seeded_runtime_path_oram_witness_family_accepts_public_scaffold_consistency() {
        let family = SeededRuntimePathOramWitnessFamily::new(vec![
            sample_runtime_refinement_witness_with_seed(0),
            sample_runtime_refinement_witness_with_seed(1),
        ])
        .unwrap();
        assert_eq!(family.seed_count, 2);
        assert_eq!(
            family.public_leaf_scaffold,
            family.witnesses[0].oram_leaf_public_scaffold
        );
    }

    #[test]
    fn seeded_runtime_path_oram_witness_family_rejects_seed_tag_drift() {
        let mut second = sample_runtime_refinement_witness_with_seed(1);
        second.runtime_seed = Some(7);
        assert_eq!(
            SeededRuntimePathOramWitnessFamily::new(vec![
                sample_runtime_refinement_witness_with_seed(0),
                second,
            ])
            .unwrap_err(),
            SeededRuntimeWitnessFamilyError::SeedTagMismatch {
                index: 1,
                tagged_seed: 7,
            }
        );
    }

    #[test]
    fn seeded_runtime_paper_main_family_bundle_accepts_uniform_public_surface() {
        let bundle = SeededRuntimePaperMainFamilyBundle::new(
            SeededRuntimePathOramWitnessFamily::new(vec![
                sample_runtime_refinement_witness_with_seed(0),
                sample_runtime_refinement_witness_with_seed(1),
            ])
            .unwrap(),
        )
        .unwrap();
        assert_eq!(bundle.family().seed_count(), 2);
        assert_eq!(
            bundle.public_outcome(),
            bundle.family().witnesses()[0].public_outcome()
        );
        assert_eq!(
            bundle.boundary_schedule(),
            bundle.family().witnesses()[0].boundary_schedule()
        );
    }

    #[test]
    fn seeded_runtime_paper_main_family_bundle_rejects_empty_family() {
        assert_eq!(
            SeededRuntimePaperMainFamilyBundle::new(
                SeededRuntimePathOramWitnessFamily::new(vec![]).unwrap()
            )
            .unwrap_err(),
            SeededRuntimePaperMainFamilyBundleError::EmptyFamily
        );
    }

    #[test]
    fn seeded_runtime_paper_main_family_bundle_rejects_public_outcome_drift() {
        let mut second = sample_runtime_refinement_witness_with_seed(1);
        second.public_outcome.gas_used += 1;
        assert_eq!(
            SeededRuntimePaperMainFamilyBundle::new(
                SeededRuntimePathOramWitnessFamily::new(vec![
                    sample_runtime_refinement_witness_with_seed(0),
                    second,
                ])
                .unwrap(),
            )
            .unwrap_err(),
            SeededRuntimePaperMainFamilyBundleError::PublicOutcomeMismatch { index: 1 }
        );
    }

    #[test]
    fn seeded_runtime_paper_main_family_bundle_rejects_boundary_schedule_drift() {
        let mut second = sample_runtime_refinement_witness_with_seed(1);
        second.boundary_schedule[0].output_len += 1;
        assert_eq!(
            SeededRuntimePaperMainFamilyBundle::new(
                SeededRuntimePathOramWitnessFamily::new(vec![
                    sample_runtime_refinement_witness_with_seed(0),
                    second,
                ])
                .unwrap(),
            )
            .unwrap_err(),
            SeededRuntimePaperMainFamilyBundleError::BoundaryScheduleMismatch { index: 1 }
        );
    }

    #[test]
    fn seeded_runtime_paper_main_slot_family_bundle_accepts_uniform_shared_slot_program() {
        let bundle = SeededRuntimePaperMainSlotFamilyBundle::new(
            SeededRuntimePathOramWitnessFamily::new(vec![
                sample_runtime_refinement_witness_with_seed_and_kernel(0),
                sample_runtime_refinement_witness_with_seed_and_kernel(1),
            ])
            .unwrap(),
            sample_runtime_paper_main_slot_program(),
        )
        .unwrap();
        assert_eq!(bundle.family().seed_count(), 2);
        assert_eq!(
            bundle
                .confidential_slot_program()
                .expected_runtime_step_witnesses(),
            bundle.family().witnesses()[0]
                .kernel_witness()
                .unwrap()
                .kernel_steps()
                .to_vec()
        );
    }

    #[test]
    fn seeded_runtime_paper_main_slot_family_bundle_rejects_expected_kernel_step_drift() {
        let mut second = sample_runtime_refinement_witness_with_seed_and_kernel(1);
        second
            .kernel_witness
            .as_mut()
            .unwrap()
            .expected_kernel_steps
            .as_mut()
            .unwrap()[1]
            .object_id = Some(9);
        assert_eq!(
            SeededRuntimePaperMainSlotFamilyBundle::new(
                SeededRuntimePathOramWitnessFamily::new(vec![
                    sample_runtime_refinement_witness_with_seed_and_kernel(0),
                    second,
                ])
                .unwrap(),
                sample_runtime_paper_main_slot_program(),
            )
            .unwrap_err(),
            SeededRuntimePaperMainSlotFamilyBundleError::ExpectedKernelStepsMismatch { index: 1 }
        );
    }

    #[test]
    fn seeded_runtime_paper_main_slot_family_bundle_rejects_non_runtime_normal_form_program() {
        let mut slot_program = sample_runtime_paper_main_slot_program();
        slot_program
            .body
            .push(ConfidentialKernelSlotStatement::Require {
                cond: ConfidentialKernelSlotExpr::Literal {
                    value: Value::Bool(true),
                },
            });
        assert_eq!(
            SeededRuntimePaperMainSlotFamilyBundle::new(
                SeededRuntimePathOramWitnessFamily::new(vec![
                    sample_runtime_refinement_witness_with_seed_and_kernel(0),
                ])
                .unwrap(),
                slot_program,
            )
            .unwrap_err(),
            SeededRuntimePaperMainSlotFamilyBundleError::SlotProgramNotRuntimeNormalForm {
                entrypoint: "put(bytes32,uint256)".into(),
            }
        );
    }

    #[test]
    fn runtime_paper_main_family_bundle_retags_to_canonical_seed_zero() {
        let trace = sample_runtime_execution_trace_with_seed(19);
        let bundle = trace.runtime_paper_main_family_bundle().unwrap();
        assert_eq!(bundle.family().seed_count(), 1);
        assert_eq!(bundle.family().witnesses()[0].runtime_seed(), Some(0));
        assert_eq!(bundle.public_outcome(), &sample_public_outcome(99));
    }

    #[test]
    fn runtime_paper_main_slot_family_bundle_uses_manifest_slot_program() {
        let mut trace = sample_runtime_execution_trace_with_seed(19);
        trace.runtime_kernel_witness = Some(sample_runtime_kernel_witness());
        trace.runtime_kernel_refinement_witness = Some(sample_runtime_kernel_refinement_witness());
        let artifact = sample_runtime_paper_main_artifact();
        let bundle = trace
            .runtime_paper_main_slot_family_bundle(&artifact)
            .unwrap();
        assert_eq!(bundle.family().seed_count(), 1);
        assert_eq!(bundle.family().witnesses()[0].runtime_seed(), Some(0));
        assert_eq!(
            bundle.confidential_slot_program(),
            artifact
                .contract
                .manifest
                .entrypoints
                .get("put(bytes32,uint256)")
                .unwrap()
                .confidential_slot_program
                .as_ref()
                .unwrap()
        );
    }

    #[test]
    fn runtime_paper_main_slot_family_bundle_rejects_missing_manifest_slot_program() {
        let mut trace = sample_runtime_execution_trace_with_seed(19);
        trace.runtime_kernel_witness = Some(sample_runtime_kernel_witness());
        trace.runtime_kernel_refinement_witness = Some(sample_runtime_kernel_refinement_witness());
        let mut artifact = sample_runtime_paper_main_artifact();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("put(bytes32,uint256)")
            .unwrap()
            .confidential_slot_program = None;
        let err = trace
            .runtime_paper_main_slot_family_bundle(&artifact)
            .unwrap_err();
        assert_eq!(
            err,
            RuntimePaperMainSlotFamilyBundleError::MissingConfidentialSlotProgram {
                entrypoint: "put(bytes32,uint256)".into()
            }
        );
    }

    #[test]
    fn extract_runtime_path_oram_fresh_coins_matches_read_hit_transition() {
        let witness = sample_runtime_refinement_witness_with_seed(0);
        let scaffold = extract_runtime_path_oram_fresh_coin_scaffold(
            &witness.oram_leaf_schedule,
            &witness.oram_leaf_state_transitions,
        )
        .unwrap();
        let values = extract_runtime_path_oram_fresh_coin_values(
            &witness.oram_leaf_schedule,
            &witness.oram_leaf_state_transitions,
        )
        .unwrap();
        assert_eq!(
            scaffold,
            vec![RuntimeOramLeafScaffoldWitness {
                object_id: 7,
                object_name: "records".into(),
                bucket_count: 31,
            }]
        );
        assert_eq!(values, vec![3]);
    }

    #[test]
    fn canonical_fresh_coin_runtime_family_accepts_single_read_miss_seed_space() {
        let witness = sample_read_miss_runtime_refinement_witness();
        let family = CanonicalFreshCoinRuntimePathOramWitnessFamily::new(vec![witness]).unwrap();
        assert_eq!(family.seed_count, 1);
        assert_eq!(
            canonical_path_oram_leaf_seed_space_size(&family.public_fresh_coin_scaffold),
            Some(1)
        );
        assert_eq!(family.public_leaf_scaffold.len(), 1);
        assert_eq!(family.public_fresh_coin_scaffold.len(), 1);
    }

    #[test]
    fn canonical_fresh_coin_seed_inverse_matches_forward_enumeration() {
        let witness = sample_runtime_refinement_witness_with_seed(0);
        let scaffold = witness.path_oram_fresh_coin_scaffold().unwrap();
        assert_eq!(
            canonical_path_oram_seed_of_leaf_values(&scaffold, &[3]),
            Some(3)
        );
    }

    #[test]
    fn canonical_fresh_coin_runtime_family_rejects_noncanonical_fresh_coin_indexing() {
        let family = CanonicalFreshCoinRuntimePathOramWitnessFamily::new(vec![
            sample_runtime_refinement_witness_with_seed(0),
            sample_runtime_refinement_witness_with_seed(1),
        ]);
        assert_eq!(
            family.unwrap_err(),
            CanonicalFreshCoinWitnessFamilyError::CanonicalSeedCountMismatch {
                seed_count: 2,
                canonical_seed_count: 16,
            }
        );
    }

    #[test]
    fn canonical_fresh_coin_theorem_input_accepts_representative_seed() {
        let theorem_input = CanonicalFreshCoinRuntimePathOramTheoremInput::new(
            3,
            sample_runtime_refinement_witness_with_seed(0),
        )
        .unwrap();
        assert_eq!(theorem_input.seed_count, 16);
        assert_eq!(theorem_input.representative_seed, 3);
        assert_eq!(theorem_input.public_leaf_scaffold.len(), 1);
        assert_eq!(theorem_input.public_fresh_coin_scaffold.len(), 1);
    }

    #[test]
    fn canonical_fresh_coin_theorem_input_rejects_wrong_representative_seed() {
        let theorem_input = CanonicalFreshCoinRuntimePathOramTheoremInput::new(
            0,
            sample_runtime_refinement_witness_with_seed(0),
        );
        assert_eq!(
            theorem_input.unwrap_err(),
            CanonicalFreshCoinTheoremInputError::CanonicalFreshCoinValuesMismatch {
                representative_seed: 0,
            }
        );
    }
}
