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
    pub public_outcome: PublicOutcomeTrace,
    pub boundary_schedule: Vec<BoundaryEvent>,
    pub controller_shape: SgxControllerShapeTrace,
    pub normalized_micro_trace: NormalizedMicroTrace,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RefinementWitnessError {
    MissingPublicOutcome,
    MissingControllerShape,
    MissingNormalizedMicroTrace,
    GasMismatch { trace_gas: u64, public_outcome_gas: u64 },
    BoundaryBudgetMismatch { boundary_events: usize, boundary_budget: usize },
    NormalizedMicroTraceMismatch,
}

impl fmt::Display for RefinementWitnessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingPublicOutcome => write!(f, "theorem trace is missing public_outcome"),
            Self::MissingControllerShape => write!(f, "theorem trace is missing controller_shape"),
            Self::MissingNormalizedMicroTrace => {
                write!(f, "theorem trace is missing normalized_micro_trace")
            }
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
            Self::NormalizedMicroTraceMismatch => write!(
                f,
                "normalized micro trace does not match the controller-shape simulation"
            ),
        }
    }
}

impl std::error::Error for RefinementWitnessError {}

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
        if normalized_micro_trace != controller_shape.normalized_micro_trace() {
            return Err(RefinementWitnessError::NormalizedMicroTraceMismatch);
        }
        Ok(RuntimeRefinementWitness {
            trace: self.refinement_trace(),
            public_outcome,
            boundary_schedule: self.theorem_trace.boundary_schedule.clone(),
            controller_shape,
            normalized_micro_trace,
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
        classify_write, BoundaryDirection, BoundaryEvent, ControllerPageBudget, ControllerPhase,
        ExecutionTrace, ExitEvent, NormalizedMicroTrace, NormalizedPageEvent, OutputShape,
        PageEventKind, PhysicalReadEvent, PhysicalWriteEvent, PublicOutcomeTrace,
        RefinementWitnessError, SgxControllerShapeTrace, TheoremTrace, WriteClass,
    };
    use std::collections::BTreeMap;

    #[test]
    fn write_classifier_matches_m_plus_partition() {
        assert_eq!(classify_write(&[0, 0], &[0, 0]), WriteClass::Same);
        assert_eq!(classify_write(&[0, 0], &[1, 2]), WriteClass::Set);
        assert_eq!(classify_write(&[1, 2], &[0, 0]), WriteClass::Clear);
        assert_eq!(classify_write(&[1, 2], &[2, 3]), WriteClass::Update);
    }

    #[test]
    fn runtime_refinement_witness_normalizes_controller_shape() {
        let controller_shape = SgxControllerShapeTrace {
            boundary_event_budget: 4,
            controller_phase_order: vec![
                ControllerPhase::EnclaveEnter,
                ControllerPhase::StageRequest,
                ControllerPhase::RewritePath,
                ControllerPhase::EnclaveExit,
            ],
            page_trace_regions: vec![ControllerPageBudget {
                page_kind: "metadata".into(),
                event_budget: 2,
            }],
            workset_regions: vec![ControllerPageBudget {
                page_kind: "metadata".into(),
                event_budget: 1,
            }],
            exit_trace_budget: 5,
            shared_resource_budget: 6,
            recursive_position_map_depth: 0,
            stash_bound: 0,
        };
        let normalized_micro_trace = controller_shape.normalized_micro_trace();
        let trace = ExecutionTrace {
            opcode_trace: vec!["declare".into()],
            logical_accesses: vec![],
            logical_writes: vec![],
            physical_reads: vec![PhysicalReadEvent {
                object: "records".into(),
                location: "records@bucket0".into(),
                len: 64,
            }],
            physical_writes: vec![PhysicalWriteEvent {
                object: "records".into(),
                location: "records@bucket0".into(),
                old: vec![1, 2],
                new: vec![3, 4],
                class: WriteClass::Update,
            }],
            host_proxy_metrics: BTreeMap::new(),
            gas_used: 99,
            theorem_trace: TheoremTrace {
                public_outcome: Some(PublicOutcomeTrace {
                    entrypoint_id: "put(bytes32,uint256)".into(),
                    public_args: vec![],
                    termination_status: true,
                    output_shape: OutputShape::default(),
                    gas_used: 99,
                }),
                boundary_schedule: vec![
                    BoundaryEvent {
                        direction: BoundaryDirection::Enter,
                        api_id: "put(bytes32,uint256)".into(),
                        input_len: 64,
                        output_len: 0,
                    },
                    BoundaryEvent {
                        direction: BoundaryDirection::Exit,
                        api_id: "oram_access".into(),
                        input_len: 0,
                        output_len: 0,
                    },
                    BoundaryEvent {
                        direction: BoundaryDirection::Enter,
                        api_id: "oram_access".into(),
                        input_len: 0,
                        output_len: 0,
                    },
                    BoundaryEvent {
                        direction: BoundaryDirection::Exit,
                        api_id: "put(bytes32,uint256)".into(),
                        input_len: 0,
                        output_len: 0,
                    },
                ],
                controller_shape: Some(controller_shape.clone()),
                normalized_micro_trace: Some(normalized_micro_trace.clone()),
            },
        };
        let witness = trace.runtime_refinement_witness().unwrap();
        assert_eq!(witness.public_outcome.gas_used, 99);
        assert_eq!(witness.trace.physical_writes[0].write_class, "Update");
        assert_eq!(witness.trace.physical_writes[0].len, 2);
        assert_eq!(witness.controller_shape, controller_shape);
        assert_eq!(witness.normalized_micro_trace, normalized_micro_trace);
    }

    #[test]
    fn runtime_refinement_witness_rejects_inconsistent_micro_trace() {
        let controller_shape = SgxControllerShapeTrace {
            boundary_event_budget: 2,
            controller_phase_order: vec![
                ControllerPhase::EnclaveEnter,
                ControllerPhase::EnclaveExit,
            ],
            page_trace_regions: vec![ControllerPageBudget {
                page_kind: "metadata".into(),
                event_budget: 1,
            }],
            workset_regions: vec![],
            exit_trace_budget: 2,
            shared_resource_budget: 2,
            recursive_position_map_depth: 0,
            stash_bound: 0,
        };
        let trace = ExecutionTrace {
            gas_used: 1,
            theorem_trace: TheoremTrace {
                public_outcome: Some(PublicOutcomeTrace {
                    entrypoint_id: "f()".into(),
                    public_args: vec![],
                    termination_status: true,
                    output_shape: OutputShape::default(),
                    gas_used: 1,
                }),
                boundary_schedule: vec![
                    BoundaryEvent {
                        direction: BoundaryDirection::Enter,
                        api_id: "f()".into(),
                        input_len: 0,
                        output_len: 0,
                    },
                    BoundaryEvent {
                        direction: BoundaryDirection::Exit,
                        api_id: "f()".into(),
                        input_len: 0,
                        output_len: 0,
                    },
                ],
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
            ..ExecutionTrace::default()
        };
        assert_eq!(
            trace.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::NormalizedMicroTraceMismatch
        );
    }
}
