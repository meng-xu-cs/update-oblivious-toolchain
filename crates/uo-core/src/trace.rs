use crate::manifest::{PATH_ORAM_SCHEME, SURROGATE_ORAM_SCHEME};
use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::collections::BTreeMap;
use std::fmt;
use std::hash::{Hash, Hasher};

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
    pub old: Vec<u8>,
    pub new: Vec<u8>,
    pub class: WriteClass,
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct RuntimeControllerCertificate {
    pub entry_input_len: usize,
    pub observed_oram_accesses: Vec<RuntimeOramAccessWitness>,
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
    pub trace: RefinementTrace,
    pub runtime_seed: Option<u64>,
    pub public_outcome: PublicOutcomeTrace,
    pub boundary_schedule: Vec<BoundaryEvent>,
    pub controller_shape: SgxControllerShapeTrace,
    pub normalized_micro_trace: NormalizedMicroTrace,
    pub controller_certificate: RuntimeControllerCertificate,
    pub oram_objects: Vec<RuntimeOramObjectWitness>,
    #[serde(default)]
    pub oram_leaf_public_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    #[serde(default)]
    pub oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RefinementWitnessError {
    MissingPublicOutcome,
    MissingControllerShape,
    MissingNormalizedMicroTrace,
    MissingControllerCertificate,
    UnknownOramLogicalObject { object: String },
    UnsupportedOramScheme { scheme: String },
    MalformedOramLogicalTrace {
        object: String,
        expected_kind: String,
        detail_prefix: String,
    },
    OramAccessScheduleMismatch,
    GasMismatch { trace_gas: u64, public_outcome_gas: u64 },
    BoundaryBudgetMismatch { boundary_events: usize, boundary_budget: usize },
    BoundaryScheduleMismatch,
    ControllerShapeMismatch,
    NormalizedMicroTraceMismatch,
    OramLeafScheduleMismatch,
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
        }
    }
}

impl std::error::Error for RefinementWitnessError {}

impl RuntimeRefinementWitness {
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).expect("runtime refinement witness is JSON serializable")
    }

    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self)
            .expect("runtime refinement witness is JSON serializable")
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
    pub fn boundary_schedule(
        &self,
        public_outcome: &PublicOutcomeTrace,
    ) -> Vec<BoundaryEvent> {
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
            recursive_position_map_depth =
                recursive_position_map_depth.max(access.recursion_depth);
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
            scaffold.push((object.object_id, object.object_name.clone(), object.bucket_count));
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
                && event.location.starts_with(&format!("{}@bucket", event.object))
        })
        .map(|event| (event.object.clone(), event.location.clone()))
        .collect();
    let write_buckets = physical_writes
        .iter()
        .filter(|event| {
            path_objects.contains(event.object.as_str())
                && event.location.starts_with(&format!("{}@bucket", event.object))
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

fn validate_path_oram_leaf_schedule(
    leaf_schedule: &[RuntimeOramLeafWitness],
    logical_accesses: &[LogicalEvent],
    physical_reads: &[PhysicalReadEvent],
    physical_writes: &[PhysicalWriteEvent],
    oram_objects: &[RuntimeOramObjectWitness],
) -> Result<Vec<RuntimeOramLeafScaffoldWitness>, RefinementWitnessError> {
    let scaffold = reconstruct_path_oram_leaf_scaffold_from_logical_trace(logical_accesses, oram_objects)?;
    if scaffold.len() != leaf_schedule.len() {
        return Err(RefinementWitnessError::OramLeafScheduleMismatch);
    }
    for ((object_id, object_name, bucket_count), step) in scaffold.iter().zip(leaf_schedule.iter()) {
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
        .map(|(object_id, object_name, bucket_count)| RuntimeOramLeafScaffoldWitness {
            object_id,
            object_name,
            bucket_count,
        })
        .collect())
}

impl SgxControllerShapeTrace {
    fn with_shared_resource_budget(mut self, page_trace_budget: usize) -> Self {
        self.shared_resource_budget =
            self.controller_phase_order.len() + page_trace_budget;
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
    pub host_proxy_metrics: BTreeMap<String, f64>,
    #[serde(default)]
    pub gas_used: u64,
    #[serde(default)]
    pub theorem_trace: TheoremTrace,
    #[serde(default)]
    pub runtime_seed: Option<u64>,
    #[serde(default)]
    pub runtime_controller_certificate: Option<RuntimeControllerCertificate>,
    #[serde(default)]
    pub runtime_oram_objects: Vec<RuntimeOramObjectWitness>,
    #[serde(default)]
    pub runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
}

impl ExecutionTrace {
    pub fn hashes(&self) -> TraceHashBundle {
        let normalized_physical = self
            .physical_writes
            .iter()
            .map(|event| {
                (
                    event.object.clone(),
                    event.location.clone(),
                    event.class,
                    event.new.len(),
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
                    len: event.new.len(),
                })
                .collect(),
            gas_used: self.gas_used,
        }
    }

    pub fn runtime_refinement_witness(
        &self,
    ) -> Result<RuntimeRefinementWitness, RefinementWitnessError> {
        let public_outcome = self
            .theorem_trace
            .public_outcome
            .clone()
            .ok_or(RefinementWitnessError::MissingPublicOutcome)?;
        let controller_shape = self
            .theorem_trace
            .controller_shape
            .clone()
            .ok_or(RefinementWitnessError::MissingControllerShape)?;
        let normalized_micro_trace = self
            .theorem_trace
            .normalized_micro_trace
            .clone()
            .ok_or(RefinementWitnessError::MissingNormalizedMicroTrace)?;
        let controller_certificate = self
            .runtime_controller_certificate
            .clone()
            .ok_or(RefinementWitnessError::MissingControllerCertificate)?;
        let reconstructed_accesses = reconstruct_oram_accesses_from_logical_trace(
            &self.logical_accesses,
            &self.runtime_oram_objects,
        )?;
        if self.gas_used != public_outcome.gas_used {
            return Err(RefinementWitnessError::GasMismatch {
                trace_gas: self.gas_used,
                public_outcome_gas: public_outcome.gas_used,
            });
        }
        if self.theorem_trace.boundary_schedule.len() != controller_shape.boundary_event_budget {
            return Err(RefinementWitnessError::BoundaryBudgetMismatch {
                boundary_events: self.theorem_trace.boundary_schedule.len(),
                boundary_budget: controller_shape.boundary_event_budget,
            });
        }
        if self.theorem_trace.boundary_schedule
            != controller_certificate.boundary_schedule(&public_outcome)
        {
            return Err(RefinementWitnessError::BoundaryScheduleMismatch);
        }
        if controller_shape != controller_certificate.controller_shape() {
            return Err(RefinementWitnessError::ControllerShapeMismatch);
        }
        if controller_certificate.observed_oram_accesses != reconstructed_accesses {
            return Err(RefinementWitnessError::OramAccessScheduleMismatch);
        }
        if normalized_micro_trace != controller_shape.normalized_micro_trace() {
            return Err(RefinementWitnessError::NormalizedMicroTraceMismatch);
        }
        let oram_leaf_public_scaffold = validate_path_oram_leaf_schedule(
            &self.runtime_oram_leaf_schedule,
            &self.logical_accesses,
            &self.physical_reads,
            &self.physical_writes,
            &self.runtime_oram_objects,
        )?;
        Ok(RuntimeRefinementWitness {
            trace: self.refinement_trace(),
            runtime_seed: self.runtime_seed,
            public_outcome,
            boundary_schedule: self.theorem_trace.boundary_schedule.clone(),
            controller_shape,
            normalized_micro_trace,
            controller_certificate,
            oram_objects: self.runtime_oram_objects.clone(),
            oram_leaf_public_scaffold,
            oram_leaf_schedule: self.runtime_oram_leaf_schedule.clone(),
        })
    }
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
        classify_write, ExecutionTrace, ExitEvent, LogicalEvent, NormalizedMicroTrace,
        NormalizedPageEvent, OutputShape, PageEventKind, PhysicalReadEvent, PhysicalWriteEvent,
        PublicOutcomeTrace, RefinementWitnessError, RuntimeControllerCertificate,
        RuntimeOramAccessWitness, RuntimeOramLeafWitness, RuntimeOramObjectWitness, TheoremTrace,
        WriteClass,
    };
    use std::collections::BTreeMap;

    #[test]
    fn write_classifier_matches_m_plus_partition() {
        assert_eq!(classify_write(&[0, 0], &[0, 0]), WriteClass::Same);
        assert_eq!(classify_write(&[0, 0], &[1, 2]), WriteClass::Set);
        assert_eq!(classify_write(&[1, 2], &[0, 0]), WriteClass::Clear);
        assert_eq!(classify_write(&[1, 2], &[2, 3]), WriteClass::Update);
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
            bucket_size: 320,
            bucket_count: 31,
            blocks_per_bucket: 4,
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

    #[test]
    fn runtime_refinement_witness_normalizes_controller_shape() {
        let controller_certificate = sample_controller_certificate();
        let public_outcome = sample_public_outcome(99);
        let controller_shape = controller_certificate.controller_shape();
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let path = sample_path_bucket_indices();
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
                .map(|index| PhysicalWriteEvent {
                    object: "records".into(),
                    location: format!("records@bucket{index}"),
                    old: vec![1, 2],
                    new: vec![3, 4],
                    class: WriteClass::Update,
                })
                .collect(),
            host_proxy_metrics: BTreeMap::new(),
            gas_used: 99,
            theorem_trace: TheoremTrace {
                public_outcome: Some(public_outcome.clone()),
                boundary_schedule: controller_certificate.boundary_schedule(&public_outcome),
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(normalized_micro_trace.clone()),
            },
            runtime_seed: None,
            runtime_controller_certificate: Some(controller_certificate.clone()),
            runtime_oram_objects: vec![sample_oram_object()],
            runtime_oram_leaf_schedule: sample_oram_leaf_schedule(),
        };
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
}
