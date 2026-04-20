use crate::{
    ExecutionTrace, KernelWitnessError, RefinementWitnessError,
    RuntimeKernelRefinementEventKindWitness, RuntimeKernelRefinementEventWitness,
    RuntimeKernelRefinementWitness, RuntimeKernelRefinementWitnessError,
    RuntimeKernelScheduleWitness, RuntimeKernelStepWitness, RuntimeKernelWitness,
    RuntimeRefinementWitness,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use uo_precompiles::UoOpcode;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellContract {
    public_object_universe: Vec<u32>,
    canonical_loaded_object_schedule: Vec<u32>,
    kernel_schedule: RuntimeKernelScheduleWitness,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellTrace {
    events: Vec<RuntimeKernelRefinementEventWitness>,
    projected_kernel_schedule: RuntimeKernelScheduleWitness,
    pre_committed_cold_object_schedule: Vec<u32>,
    shadow_load_object_schedule: Vec<u32>,
    commit_object_schedule: Vec<u32>,
    cold_store_object_schedule: Vec<u32>,
    post_committed_cold_object_schedule: Vec<u32>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeShellBoundaryBundle {
    kernel_witness: RuntimeKernelWitness,
    runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    shell_contract: RuntimeShellContract,
    shell_trace: RuntimeShellTrace,
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum RuntimeShellBoundaryBundleError {
    #[error("runtime shell-boundary bundle requires a valid runtime refinement witness: {0}")]
    RuntimeWitness(#[from] RefinementWitnessError),
    #[error("runtime shell-boundary bundle requires a runtime kernel witness")]
    MissingKernelWitness,
    #[error("runtime shell-boundary bundle requires a runtime kernel refinement witness")]
    MissingRuntimeKernelRefinementWitness,
    #[error("runtime shell-boundary bundle requires a valid runtime kernel witness: {0}")]
    KernelWitness(#[from] KernelWitnessError),
    #[error(
        "runtime shell-boundary bundle requires a valid runtime kernel refinement witness: {0}"
    )]
    RuntimeKernelRefinementWitness(#[from] RuntimeKernelRefinementWitnessError),
    #[error("runtime shell trace does not refine the runtime shell contract")]
    ShellRefinementMismatch,
}

impl RuntimeKernelWitness {
    pub(crate) fn shell_contract(&self) -> RuntimeShellContract {
        RuntimeShellContract {
            public_object_universe: self.emitted_public_object_schedule(),
            canonical_loaded_object_schedule: self.canonical_loaded_object_schedule(),
            kernel_schedule: self.emitted_kernel_schedule(),
        }
    }
}

impl RuntimeKernelRefinementWitness {
    pub(crate) fn shell_trace(&self) -> RuntimeShellTrace {
        RuntimeShellTrace::from_components(
            self.events().to_vec(),
            self.projected_kernel_schedule(),
            self.pre_committed_cold_object_schedule(),
            self.shadow_load_object_schedule(),
            self.commit_object_schedule(),
            self.cold_store_object_schedule(),
            self.post_committed_cold_object_schedule(),
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum RuntimeShellReplayPhase {
    BeforeBegin,
    PreCommittedColdWindow,
    ShadowLoadWindow,
    ActiveKernel,
    CommitObjectWindow,
    AfterWipe,
    ColdStoreWindow,
    PostCommittedColdWindow,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
struct RuntimeShellReplayProgress {
    pre_committed_cold_index: usize,
    kernel_step_index: usize,
    shadow_load_index: usize,
    commit_index: usize,
    cold_store_index: usize,
    post_committed_cold_index: usize,
}

impl RuntimeShellTrace {
    fn from_components(
        events: Vec<RuntimeKernelRefinementEventWitness>,
        projected_kernel_schedule: RuntimeKernelScheduleWitness,
        pre_committed_cold_object_schedule: Vec<u32>,
        shadow_load_object_schedule: Vec<u32>,
        commit_object_schedule: Vec<u32>,
        cold_store_object_schedule: Vec<u32>,
        post_committed_cold_object_schedule: Vec<u32>,
    ) -> Self {
        Self {
            events,
            projected_kernel_schedule,
            pre_committed_cold_object_schedule,
            shadow_load_object_schedule,
            commit_object_schedule,
            cold_store_object_schedule,
            post_committed_cold_object_schedule,
        }
    }

    pub fn events(&self) -> &[RuntimeKernelRefinementEventWitness] {
        &self.events
    }

    pub fn event_count(&self) -> usize {
        self.events.len()
    }

    pub fn projected_kernel_schedule(&self) -> &RuntimeKernelScheduleWitness {
        &self.projected_kernel_schedule
    }

    pub fn pre_committed_cold_object_schedule(&self) -> &[u32] {
        &self.pre_committed_cold_object_schedule
    }

    pub fn shadow_load_object_schedule(&self) -> &[u32] {
        &self.shadow_load_object_schedule
    }

    pub fn commit_object_schedule(&self) -> &[u32] {
        &self.commit_object_schedule
    }

    pub fn cold_store_object_schedule(&self) -> &[u32] {
        &self.cold_store_object_schedule
    }

    pub fn post_committed_cold_object_schedule(&self) -> &[u32] {
        &self.post_committed_cold_object_schedule
    }

    pub fn projected_kernel_schedule_from_events(&self) -> RuntimeKernelScheduleWitness {
        let steps = self
            .events()
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
            "projected shell-boundary schedule derived from events must satisfy shape invariants",
        )
    }

    fn object_schedule_from_events(
        &self,
        kind: RuntimeKernelRefinementEventKindWitness,
    ) -> Vec<u32> {
        self.events()
            .iter()
            .filter(|event| event.kind() == kind)
            .filter_map(RuntimeKernelRefinementEventWitness::object_id)
            .collect()
    }

    pub fn pre_committed_cold_object_schedule_from_events(&self) -> Vec<u32> {
        self.object_schedule_from_events(
            RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject,
        )
    }

    pub fn shadow_load_object_schedule_from_events(&self) -> Vec<u32> {
        self.object_schedule_from_events(RuntimeKernelRefinementEventKindWitness::ShadowLoadObject)
    }

    pub fn commit_object_schedule_from_events(&self) -> Vec<u32> {
        self.object_schedule_from_events(RuntimeKernelRefinementEventKindWitness::CommitObject)
    }

    pub fn cold_store_object_schedule_from_events(&self) -> Vec<u32> {
        self.object_schedule_from_events(RuntimeKernelRefinementEventKindWitness::ColdStoreObject)
    }

    pub fn post_committed_cold_object_schedule_from_events(&self) -> Vec<u32> {
        self.object_schedule_from_events(
            RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject,
        )
    }

    pub fn summaries_match_events(&self) -> bool {
        self.projected_kernel_schedule() == &self.projected_kernel_schedule_from_events()
            && self.pre_committed_cold_object_schedule()
                == self.pre_committed_cold_object_schedule_from_events()
            && self.shadow_load_object_schedule() == self.shadow_load_object_schedule_from_events()
            && self.commit_object_schedule() == self.commit_object_schedule_from_events()
            && self.cold_store_object_schedule() == self.cold_store_object_schedule_from_events()
            && self.post_committed_cold_object_schedule()
                == self.post_committed_cold_object_schedule_from_events()
    }

    pub fn replays_contract(&self, contract: &RuntimeShellContract) -> bool {
        if !self.summaries_match_events() {
            return false;
        }
        let mut phase = RuntimeShellReplayPhase::BeforeBegin;
        let mut progress = RuntimeShellReplayProgress::default();
        for event in self.events() {
            if event.validate_shape().is_err() {
                return false;
            }
            match event.kind() {
                RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject => {
                    let Some(object_id) = event.object_id() else {
                        return false;
                    };
                    let Some(expected_object_id) = contract
                        .public_object_universe
                        .get(progress.pre_committed_cold_index)
                    else {
                        return false;
                    };
                    if object_id != *expected_object_id {
                        return false;
                    }
                    phase = match phase {
                        RuntimeShellReplayPhase::BeforeBegin
                        | RuntimeShellReplayPhase::PreCommittedColdWindow => {
                            RuntimeShellReplayPhase::PreCommittedColdWindow
                        }
                        _ => return false,
                    };
                    progress.pre_committed_cold_index += 1;
                }
                RuntimeKernelRefinementEventKindWitness::ShadowLoadObject => {
                    let Some(object_id) = event.object_id() else {
                        return false;
                    };
                    let Some(expected_object_id) = contract
                        .canonical_loaded_object_schedule
                        .get(progress.shadow_load_index)
                    else {
                        return false;
                    };
                    if phase != RuntimeShellReplayPhase::ShadowLoadWindow
                        || object_id != *expected_object_id
                    {
                        return false;
                    }
                    progress.shadow_load_index += 1;
                }
                RuntimeKernelRefinementEventKindWitness::CommitObject => {
                    let Some(object_id) = event.object_id() else {
                        return false;
                    };
                    let Some(expected_object_id) = contract
                        .canonical_loaded_object_schedule
                        .get(progress.commit_index)
                    else {
                        return false;
                    };
                    if phase != RuntimeShellReplayPhase::CommitObjectWindow
                        || object_id != *expected_object_id
                    {
                        return false;
                    }
                    progress.commit_index += 1;
                }
                RuntimeKernelRefinementEventKindWitness::ColdStoreObject => {
                    let Some(object_id) = event.object_id() else {
                        return false;
                    };
                    let Some(expected_object_id) = contract
                        .canonical_loaded_object_schedule
                        .get(progress.cold_store_index)
                    else {
                        return false;
                    };
                    phase = match phase {
                        RuntimeShellReplayPhase::AfterWipe
                        | RuntimeShellReplayPhase::ColdStoreWindow => {
                            RuntimeShellReplayPhase::ColdStoreWindow
                        }
                        _ => return false,
                    };
                    if object_id != *expected_object_id {
                        return false;
                    }
                    progress.cold_store_index += 1;
                }
                RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject => {
                    let Some(object_id) = event.object_id() else {
                        return false;
                    };
                    let Some(expected_object_id) = contract
                        .public_object_universe
                        .get(progress.post_committed_cold_index)
                    else {
                        return false;
                    };
                    phase = match phase {
                        RuntimeShellReplayPhase::AfterWipe
                        | RuntimeShellReplayPhase::ColdStoreWindow
                        | RuntimeShellReplayPhase::PostCommittedColdWindow => {
                            RuntimeShellReplayPhase::PostCommittedColdWindow
                        }
                        _ => return false,
                    };
                    if object_id != *expected_object_id {
                        return false;
                    }
                    progress.post_committed_cold_index += 1;
                }
                RuntimeKernelRefinementEventKindWitness::KernelStep => {
                    let Some(step) = event.projected_kernel_step() else {
                        return false;
                    };
                    let Some(expected_step) = contract
                        .kernel_schedule
                        .steps()
                        .get(progress.kernel_step_index)
                    else {
                        return false;
                    };
                    if step != *expected_step {
                        return false;
                    }
                    phase = match (phase, step.projected_opcode()) {
                        (RuntimeShellReplayPhase::BeforeBegin, UoOpcode::Begin)
                        | (RuntimeShellReplayPhase::PreCommittedColdWindow, UoOpcode::Begin) => {
                            RuntimeShellReplayPhase::ShadowLoadWindow
                        }
                        (RuntimeShellReplayPhase::ShadowLoadWindow, UoOpcode::Commit) => {
                            RuntimeShellReplayPhase::CommitObjectWindow
                        }
                        (RuntimeShellReplayPhase::ShadowLoadWindow, UoOpcode::Wipe) => {
                            return false;
                        }
                        (RuntimeShellReplayPhase::ShadowLoadWindow, _) => {
                            RuntimeShellReplayPhase::ActiveKernel
                        }
                        (RuntimeShellReplayPhase::ActiveKernel, UoOpcode::Commit) => {
                            RuntimeShellReplayPhase::CommitObjectWindow
                        }
                        (RuntimeShellReplayPhase::ActiveKernel, UoOpcode::Wipe) => {
                            return false;
                        }
                        (RuntimeShellReplayPhase::ActiveKernel, UoOpcode::Begin) => {
                            return false;
                        }
                        (RuntimeShellReplayPhase::ActiveKernel, _) => {
                            RuntimeShellReplayPhase::ActiveKernel
                        }
                        (RuntimeShellReplayPhase::CommitObjectWindow, UoOpcode::Wipe) => {
                            RuntimeShellReplayPhase::AfterWipe
                        }
                        _ => return false,
                    };
                    progress.kernel_step_index += 1;
                }
            }
        }
        matches!(
            phase,
            RuntimeShellReplayPhase::AfterWipe
                | RuntimeShellReplayPhase::ColdStoreWindow
                | RuntimeShellReplayPhase::PostCommittedColdWindow
        ) && progress.pre_committed_cold_index == contract.public_object_universe.len()
            && progress.kernel_step_index == contract.kernel_schedule.steps().len()
            && progress.shadow_load_index == contract.canonical_loaded_object_schedule.len()
            && progress.commit_index == contract.canonical_loaded_object_schedule.len()
            && progress.cold_store_index == contract.canonical_loaded_object_schedule.len()
            && progress.post_committed_cold_index == contract.public_object_universe.len()
    }

    pub fn refines_contract(&self, contract: &RuntimeShellContract) -> bool {
        self.projected_kernel_schedule == contract.kernel_schedule
            && self.pre_committed_cold_object_schedule == contract.public_object_universe
            && self.post_committed_cold_object_schedule == contract.public_object_universe
            && self.shadow_load_object_schedule == contract.canonical_loaded_object_schedule
            && self.commit_object_schedule == contract.canonical_loaded_object_schedule
            && self.cold_store_object_schedule == contract.canonical_loaded_object_schedule
            && self.replays_contract(contract)
    }
}

impl RuntimeShellBoundaryBundle {
    pub fn entrypoint_id(&self) -> &str {
        self.kernel_witness.entrypoint_id()
    }

    pub fn kernel_witness(&self) -> &RuntimeKernelWitness {
        &self.kernel_witness
    }

    pub fn runtime_kernel_refinement_witness(&self) -> &RuntimeKernelRefinementWitness {
        &self.runtime_kernel_refinement_witness
    }

    pub fn shell_contract(&self) -> &RuntimeShellContract {
        &self.shell_contract
    }

    pub fn shell_trace(&self) -> &RuntimeShellTrace {
        &self.shell_trace
    }

    fn from_witnesses(
        kernel_witness: RuntimeKernelWitness,
        runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    ) -> Result<Self, RuntimeShellBoundaryBundleError> {
        kernel_witness.validate_for_entrypoint(kernel_witness.entrypoint_id())?;
        runtime_kernel_refinement_witness.validate_with_kernel_witness(&kernel_witness)?;
        let shell_contract = kernel_witness.shell_contract();
        let shell_trace = runtime_kernel_refinement_witness.shell_trace();
        if !shell_trace.refines_contract(&shell_contract) {
            return Err(RuntimeShellBoundaryBundleError::ShellRefinementMismatch);
        }
        Ok(Self {
            kernel_witness,
            runtime_kernel_refinement_witness,
            shell_contract,
            shell_trace,
        })
    }

    pub(crate) fn from_runtime_witness(
        runtime_witness: RuntimeRefinementWitness,
    ) -> Result<Self, RuntimeShellBoundaryBundleError> {
        runtime_witness.validate()?;
        let kernel_witness = runtime_witness
            .kernel_witness()
            .cloned()
            .ok_or(RuntimeShellBoundaryBundleError::MissingKernelWitness)?;
        let runtime_kernel_refinement_witness = runtime_witness
            .runtime_kernel_refinement_witness()
            .cloned()
            .ok_or(RuntimeShellBoundaryBundleError::MissingRuntimeKernelRefinementWitness)?;
        Self::from_witnesses(kernel_witness, runtime_kernel_refinement_witness)
    }
}

impl RuntimeShellContract {
    pub fn public_object_universe(&self) -> &[u32] {
        &self.public_object_universe
    }

    pub fn canonical_loaded_object_schedule(&self) -> &[u32] {
        &self.canonical_loaded_object_schedule
    }

    pub fn kernel_schedule(&self) -> &RuntimeKernelScheduleWitness {
        &self.kernel_schedule
    }
}

impl ExecutionTrace {
    pub fn runtime_shell_boundary_bundle(
        &self,
    ) -> Result<RuntimeShellBoundaryBundle, RuntimeShellBoundaryBundleError> {
        let runtime_witness = self.runtime_refinement_witness()?;
        RuntimeShellBoundaryBundle::from_runtime_witness(runtime_witness)
    }
}

#[cfg(test)]
mod tests {
    use super::{RuntimeShellContract, RuntimeShellTrace};
    use crate::{
        RuntimeKernelRefinementEventWitness, RuntimeKernelScheduleWitness, RuntimeKernelStepWitness,
    };
    use uo_precompiles::UoOpcode;

    fn sample_contract() -> RuntimeShellContract {
        RuntimeShellContract {
            public_object_universe: vec![7],
            canonical_loaded_object_schedule: vec![7],
            kernel_schedule: RuntimeKernelScheduleWitness::new(
                vec![
                    UoOpcode::Begin,
                    UoOpcode::CellGet,
                    UoOpcode::Commit,
                    UoOpcode::Wipe,
                ],
                vec![
                    RuntimeKernelStepWitness::new(UoOpcode::Begin, None).unwrap(),
                    RuntimeKernelStepWitness::new(UoOpcode::CellGet, Some(7)).unwrap(),
                    RuntimeKernelStepWitness::new(UoOpcode::Commit, None).unwrap(),
                    RuntimeKernelStepWitness::new(UoOpcode::Wipe, None).unwrap(),
                ],
            )
            .unwrap(),
        }
    }

    fn sample_shell_trace() -> RuntimeShellTrace {
        RuntimeShellTrace {
            events: vec![
                RuntimeKernelRefinementEventWitness::pre_committed_cold_object(7),
                RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Begin, None),
                RuntimeKernelRefinementEventWitness::shadow_load_object(7),
                RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::CellGet, Some(7)),
                RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Commit, None),
                RuntimeKernelRefinementEventWitness::commit_object(7),
                RuntimeKernelRefinementEventWitness::kernel_step(UoOpcode::Wipe, None),
                RuntimeKernelRefinementEventWitness::cold_store_object(7),
                RuntimeKernelRefinementEventWitness::post_committed_cold_object(7),
            ],
            projected_kernel_schedule: RuntimeKernelScheduleWitness::new(
                vec![
                    UoOpcode::Begin,
                    UoOpcode::CellGet,
                    UoOpcode::Commit,
                    UoOpcode::Wipe,
                ],
                vec![
                    RuntimeKernelStepWitness::new(UoOpcode::Begin, None).unwrap(),
                    RuntimeKernelStepWitness::new(UoOpcode::CellGet, Some(7)).unwrap(),
                    RuntimeKernelStepWitness::new(UoOpcode::Commit, None).unwrap(),
                    RuntimeKernelStepWitness::new(UoOpcode::Wipe, None).unwrap(),
                ],
            )
            .unwrap(),
            pre_committed_cold_object_schedule: vec![7],
            shadow_load_object_schedule: vec![7],
            commit_object_schedule: vec![7],
            cold_store_object_schedule: vec![7],
            post_committed_cold_object_schedule: vec![7],
        }
    }

    #[test]
    fn shell_trace_refines_contract_via_event_replay() {
        let contract = sample_contract();
        let trace = sample_shell_trace();
        assert!(trace.summaries_match_events());
        assert!(trace.replays_contract(&contract));
        assert!(trace.refines_contract(&contract));
    }

    #[test]
    fn shell_trace_rejects_tampered_summary_projection() {
        let contract = sample_contract();
        let mut trace = sample_shell_trace();
        trace.commit_object_schedule = vec![];
        assert!(!trace.summaries_match_events());
        assert!(!trace.replays_contract(&contract));
        assert!(!trace.refines_contract(&contract));
    }

    #[test]
    fn shell_trace_rejects_misordered_public_events() {
        let contract = sample_contract();
        let mut trace = sample_shell_trace();
        trace.events.swap(2, 3);
        assert!(trace.summaries_match_events());
        assert!(!trace.replays_contract(&contract));
        assert!(!trace.refines_contract(&contract));
    }
}
