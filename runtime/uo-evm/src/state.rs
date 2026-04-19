use crate::controller::{CallRecorder, PublicCallSummary};
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::kernel::PublicRuntimeKernel;
use crate::runtime::objects::RuntimeObject;
use crate::runtime::RuntimeCallOutcome;
use anyhow::{anyhow, bail, Result};
use std::collections::BTreeMap;
use uo_allocator::{AllocatorPlan, AllocatorSession};
use uo_core::{
    ir::StateObject, manifest::EntrypointManifest, ConfidentialKernelSlotProgram,
    RuntimeKernelRefinementEventWitness, RuntimeKernelRefinementWitness, RuntimeKernelWitness,
    RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness, Value,
};

#[derive(Debug)]
pub(in crate::runtime) struct CommittedRuntimeState {
    objects: BTreeMap<u32, RuntimeObject>,
}

#[derive(Debug)]
pub(crate) struct ContractRuntime {
    committed: CommittedRuntimeState,
}

#[derive(Debug, Default)]
pub(in crate::runtime) struct RuntimeShadowState {
    objects: BTreeMap<u32, RuntimeObject>,
}

#[derive(Debug)]
pub(in crate::runtime) struct ConfidentialRuntimeShadowState {
    shadow: RuntimeShadowState,
}

#[derive(Debug)]
pub(in crate::runtime) struct PublicRuntimeShadowState {
    shadow: RuntimeShadowState,
}

#[derive(Clone, Debug)]
struct ConfidentialEntrypointPlan {
    allocator: AllocatorPlan,
    public_object_ids: Vec<u32>,
    max_commit_ops: usize,
    program: ConfidentialKernelSlotProgram,
    max_hash_part_bytes: usize,
}

#[derive(Debug)]
struct CommittedRuntimeWitnessSnapshot {
    runtime_oram_access_counters: Vec<RuntimeOramAccessCounterWitness>,
    runtime_oram_position_maps: Vec<RuntimePathOramPositionMapWitness>,
}

fn wipe_runtime_oram_access_counters(witnesses: &mut [RuntimeOramAccessCounterWitness]) {
    for witness in witnesses.iter_mut() {
        witness.access_counter = 0;
    }
}

fn wipe_runtime_oram_position_maps(witnesses: &mut [RuntimePathOramPositionMapWitness]) {
    for witness in witnesses.iter_mut() {
        for leaf in witness.leaves.iter_mut() {
            *leaf = None;
        }
    }
}

impl CommittedRuntimeWitnessSnapshot {
    fn into_hidden_oram_state(
        mut self,
    ) -> (
        Vec<RuntimeOramAccessCounterWitness>,
        Vec<RuntimePathOramPositionMapWitness>,
    ) {
        (
            std::mem::take(&mut self.runtime_oram_access_counters),
            std::mem::take(&mut self.runtime_oram_position_maps),
        )
    }
}

impl Drop for CommittedRuntimeWitnessSnapshot {
    fn drop(&mut self) {
        wipe_runtime_oram_access_counters(&mut self.runtime_oram_access_counters);
        wipe_runtime_oram_position_maps(&mut self.runtime_oram_position_maps);
    }
}

#[derive(Debug)]
pub(in crate::runtime) struct TracedRuntimeCallStart {
    runtime_state_before: CommittedRuntimeWitnessSnapshot,
}

#[derive(Debug)]
pub(in crate::runtime) struct TracedRuntimeCallWitnessState {
    runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
    runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,
    runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,
    runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,
}

impl TracedRuntimeCallWitnessState {
    pub(in crate::runtime) fn into_execution_trace_parts(
        mut self,
    ) -> (
        Vec<RuntimeOramAccessCounterWitness>,
        Vec<RuntimeOramAccessCounterWitness>,
        Vec<RuntimePathOramPositionMapWitness>,
        Vec<RuntimePathOramPositionMapWitness>,
    ) {
        (
            std::mem::take(&mut self.runtime_oram_access_counters_before),
            std::mem::take(&mut self.runtime_oram_access_counters_after),
            std::mem::take(&mut self.runtime_oram_position_map_before),
            std::mem::take(&mut self.runtime_oram_position_map_after),
        )
    }
}

impl Drop for TracedRuntimeCallWitnessState {
    fn drop(&mut self) {
        wipe_runtime_oram_access_counters(&mut self.runtime_oram_access_counters_before);
        wipe_runtime_oram_access_counters(&mut self.runtime_oram_access_counters_after);
        wipe_runtime_oram_position_maps(&mut self.runtime_oram_position_map_before);
        wipe_runtime_oram_position_maps(&mut self.runtime_oram_position_map_after);
    }
}

#[derive(Debug)]
pub(in crate::runtime) struct TracedRuntimeCallOutcome {
    call_outcome: RuntimeCallOutcome,
    runtime_state_after: CommittedRuntimeWitnessSnapshot,
}

impl TracedRuntimeCallOutcome {
    pub(in crate::runtime) fn into_finalized_call_trace_parts(
        self,
        call_start: TracedRuntimeCallStart,
    ) -> (
        RuntimeKernelWitness,
        RuntimeKernelRefinementWitness,
        bool,
        Option<Value>,
        Vec<String>,
        TracedRuntimeCallWitnessState,
    ) {
        let (runtime_oram_access_counters_before, runtime_oram_position_map_before) =
            call_start.runtime_state_before.into_hidden_oram_state();
        let (runtime_oram_access_counters_after, runtime_oram_position_map_after) =
            self.runtime_state_after.into_hidden_oram_state();
        let (
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted,
            return_value,
            opcode_trace,
        ) = self.call_outcome.into_theorem_trace_parts();
        (
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted,
            return_value,
            opcode_trace,
            TracedRuntimeCallWitnessState {
                runtime_oram_access_counters_before,
                runtime_oram_access_counters_after,
                runtime_oram_position_map_before,
                runtime_oram_position_map_after,
            },
        )
    }
}

impl Clone for CommittedRuntimeState {
    fn clone(&self) -> Self {
        Self {
            objects: self
                .objects
                .iter()
                .map(|(id, object)| (*id, object.clone_committed_cold()))
                .collect(),
        }
    }
}

impl Clone for ContractRuntime {
    fn clone(&self) -> Self {
        Self {
            committed: self.committed.clone(),
        }
    }
}

impl ContractRuntime {
    pub(in crate::runtime) fn deploy(
        contract_state: &[StateObject],
        deploy_seed: u64,
    ) -> Result<Self> {
        Ok(Self {
            committed: CommittedRuntimeState::deploy(contract_state, deploy_seed)?,
        })
    }

    pub(in crate::runtime) fn ensure_cold(
        &self,
        expected_object_ids: &[u32],
        context: &str,
    ) -> Result<()> {
        self.committed.ensure_cold(expected_object_ids, context)
    }

    pub(in crate::runtime) fn public_object_ids(&self) -> Vec<u32> {
        self.committed.public_object_ids()
    }

    pub(in crate::runtime) fn begin_traced_call(
        &self,
        entrypoint: &str,
        manifest_entry: &EntrypointManifest,
        args: &[Value],
    ) -> Result<(TracedRuntimeCallStart, PublicCallSummary, CallRecorder)> {
        self.ensure_ready_for_call("before executing the next call from committed storage")?;
        let public_call = PublicCallSummary::from_manifest_entry(manifest_entry, args)?;
        let recorder =
            CallRecorder::begin_with_input_len(entrypoint, public_call.entry_input_len());
        Ok((
            TracedRuntimeCallStart {
                runtime_state_before: self.witness_snapshot()?,
            },
            public_call,
            recorder,
        ))
    }

    fn ensure_ready_for_call(&self, context: &str) -> Result<()> {
        let public_object_ids = self.public_object_ids();
        self.ensure_cold(&public_object_ids, context)
    }

    pub(in crate::runtime) fn finish_traced_call(
        &self,
        call_outcome: RuntimeCallOutcome,
    ) -> Result<TracedRuntimeCallOutcome> {
        Ok(TracedRuntimeCallOutcome {
            call_outcome,
            runtime_state_after: self.witness_snapshot()?,
        })
    }

    fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {
        self.committed.witness_snapshot()
    }

    pub(in crate::runtime) fn prepare_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        self.committed
            .prepare_public_shadow(kernel, public_object_ids)
    }

    pub(in crate::runtime) fn commit_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        shadow: &mut PublicRuntimeShadowState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        self.committed
            .commit_public_shadow(kernel, shadow, aborted, recorder)
    }

    pub(in crate::runtime) fn run_confidential_entrypoint(
        &mut self,
        entrypoint: &str,
        manifest_entry: &EntrypointManifest,
        args: Vec<Value>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
    ) -> Result<RuntimeCallOutcome> {
        let public_object_ids = self.public_object_ids();
        let plan = ConfidentialEntrypointPlan::from_manifest_entry(
            entrypoint,
            manifest_entry,
            public_object_ids,
        )?;
        let ConfidentialEntrypointPlan {
            allocator,
            public_object_ids,
            max_commit_ops,
            program,
            max_hash_part_bytes,
        } = plan;
        let kernel = PublicRuntimeKernel::begin(allocator, public_object_ids.clone())?;
        let mut opcode_trace = Vec::with_capacity(program.body.len().max(1));
        let (runtime_kernel_witness, mut runtime_kernel_refinement_witness, aborted, return_value) =
            self.committed.run_confidential_call(
                kernel,
                &program,
                max_hash_part_bytes,
                args,
                fresh_coins,
                recorder,
                &mut opcode_trace,
            )?;
        if recorder.physical_write_count() > max_commit_ops {
            bail!(
                "entrypoint {} exceeded manifest commit budget: {} > {}",
                program.entrypoint_id,
                recorder.physical_write_count(),
                max_commit_ops
            );
        }
        self.finalize_runtime_kernel_refinement_witness(
            &mut runtime_kernel_refinement_witness,
            &public_object_ids,
            "after completing the call and returning to committed storage",
        )?;
        Ok(RuntimeCallOutcome::from_runtime_execution(
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted,
            return_value,
            opcode_trace,
        ))
    }

    pub(in crate::runtime) fn replace_with_cold_public_shadow(
        &mut self,
        shadow: PublicRuntimeShadowState,
    ) {
        self.committed.replace_with_cold_public_shadow(shadow);
    }

    pub(in crate::runtime) fn finalize_runtime_kernel_refinement_witness(
        &self,
        runtime_kernel_refinement_witness: &mut RuntimeKernelRefinementWitness,
        public_object_ids: &[u32],
        context: &str,
    ) -> Result<()> {
        self.committed.finalize_runtime_kernel_refinement_witness(
            runtime_kernel_refinement_witness,
            public_object_ids,
            context,
        )
    }

    #[cfg(test)]
    pub(crate) fn objects_for_test(&self) -> &BTreeMap<u32, RuntimeObject> {
        self.committed.objects_for_test()
    }

    #[cfg(test)]
    pub(crate) fn insert_object_for_test(&mut self, object_id: u32, object: RuntimeObject) {
        self.committed.insert_object_for_test(object_id, object);
    }

    #[cfg(test)]
    pub(crate) fn shadow_remove_object_for_test(&self, object_id: u32) -> Result<RuntimeObject> {
        let mut kernel = PublicRuntimeKernel::begin(
            AllocatorPlan {
                arena_bytes: 4096,
                max_stack_words: 64,
                scratch_bytes: 1024,
                max_kernel_ops: 16,
            },
            vec![],
        )?;
        let mut shadow = self
            .committed
            .shadow_load_for_test(&mut kernel, &[object_id])?;
        shadow
            .remove_object_for_test(object_id)
            .ok_or_else(|| anyhow!("shadow object {object_id} missing after test shadow load"))
    }
}

impl CommittedRuntimeState {
    fn deploy(contract_state: &[StateObject], deploy_seed: u64) -> Result<Self> {
        let mut objects = BTreeMap::new();
        let mut master_seed = deploy_seed;
        for spec in contract_state {
            objects.insert(
                spec.id,
                RuntimeObject::instantiate_with_seed(spec, master_seed)?,
            );
            master_seed = master_seed
                .wrapping_mul(0x9E37_79B9_7F4A_7C15)
                .wrapping_add(0xA5A5_A5A5_A5A5_A5A5);
        }
        Ok(Self { objects })
    }

    fn ensure_cold(&self, expected_object_ids: &[u32], context: &str) -> Result<()> {
        let witnessed_object_ids = self.objects.keys().copied().collect::<Vec<_>>();
        if witnessed_object_ids != expected_object_ids {
            bail!(
                "committed object universe {:?} did not match expected public object universe {:?} {}",
                witnessed_object_ids,
                expected_object_ids,
                context
            );
        }
        if let Some((object_id, _)) = self
            .objects
            .iter()
            .find(|(_, object)| !object.committed_cache_is_cold())
        {
            bail!("object {} was not cold {}", object_id, context);
        }
        Ok(())
    }

    fn public_object_ids(&self) -> Vec<u32> {
        self.objects.keys().copied().collect()
    }

    fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {
        let mut runtime_oram_position_maps = Vec::with_capacity(self.objects.len());
        for object in self.objects.values() {
            if let Some(state) = object.path_oram_position_map_witness()? {
                runtime_oram_position_maps.push(state);
            }
        }
        Ok(CommittedRuntimeWitnessSnapshot {
            runtime_oram_access_counters: self
                .objects
                .values()
                .filter_map(RuntimeObject::path_oram_access_counter_witness)
                .collect(),
            runtime_oram_position_maps,
        })
    }

    pub(in crate::runtime) fn prepare_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        kernel.shadow_load_public_objects(self, public_object_ids)
    }

    pub(in crate::runtime) fn commit_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        shadow: &mut PublicRuntimeShadowState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        kernel.commit_public_objects(shadow, self, aborted, recorder)
    }

    fn run_confidential_call(
        &mut self,
        kernel: PublicRuntimeKernel,
        program: &ConfidentialKernelSlotProgram,
        max_hash_part_bytes: usize,
        raw_args: Vec<Value>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<(
        RuntimeKernelWitness,
        RuntimeKernelRefinementWitness,
        bool,
        Option<Value>,
    )> {
        let outcome = kernel.run_confidential_call(
            program,
            self,
            max_hash_part_bytes,
            raw_args,
            fresh_coins,
            recorder,
            opcode_trace,
        )?;
        let (
            committed_shadow,
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted,
            return_value,
        ) = outcome.into_committed_outcome_parts();
        self.objects = committed_shadow.into_cold_committed_state().objects;
        Ok((
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted,
            return_value,
        ))
    }

    pub(in crate::runtime) fn replace_with_cold_public_shadow(
        &mut self,
        shadow: PublicRuntimeShadowState,
    ) {
        self.objects = shadow.into_cold_committed_state().objects;
    }

    pub(in crate::runtime) fn finalize_runtime_kernel_refinement_witness(
        &self,
        runtime_kernel_refinement_witness: &mut RuntimeKernelRefinementWitness,
        public_object_ids: &[u32],
        context: &str,
    ) -> Result<()> {
        self.ensure_cold(public_object_ids, context)?;
        let cold_stored_object_ids =
            runtime_kernel_refinement_witness.shadow_load_object_schedule();
        runtime_kernel_refinement_witness.events.extend(
            cold_stored_object_ids
                .into_iter()
                .map(RuntimeKernelRefinementEventWitness::cold_store_object),
        );
        runtime_kernel_refinement_witness.events.extend(
            public_object_ids
                .iter()
                .copied()
                .map(RuntimeKernelRefinementEventWitness::post_committed_cold_object),
        );
        Ok(())
    }

    pub(in crate::runtime) fn objects(&self) -> &BTreeMap<u32, RuntimeObject> {
        &self.objects
    }

    pub(in crate::runtime) fn shadow_load(
        &self,
        object_ids: &[u32],
        allocator: &mut AllocatorSession,
    ) -> Result<RuntimeShadowState> {
        let mut shadow = RuntimeShadowState::default();
        for object_id in object_ids {
            let object = self
                .objects
                .get(object_id)
                .ok_or_else(|| anyhow!("missing committed object {}", object_id))?;
            shadow
                .objects
                .insert(*object_id, object.clone_for_tx(allocator)?);
        }
        Ok(shadow)
    }

    #[cfg(test)]
    pub(crate) fn objects_for_test(&self) -> &BTreeMap<u32, RuntimeObject> {
        &self.objects
    }

    #[cfg(test)]
    pub(crate) fn insert_object_for_test(&mut self, object_id: u32, object: RuntimeObject) {
        self.objects.insert(object_id, object);
    }

    #[cfg(test)]
    pub(in crate::runtime) fn shadow_load_for_test(
        &self,
        kernel: &mut PublicRuntimeKernel,
        object_ids: &[u32],
    ) -> Result<ConfidentialRuntimeShadowState> {
        kernel.shadow_load_confidential_objects_for_test(self, object_ids)
    }
}

impl ConfidentialEntrypointPlan {
    fn from_manifest_entry(
        entrypoint: &str,
        manifest_entry: &EntrypointManifest,
        public_object_ids: Vec<u32>,
    ) -> Result<Self> {
        let mut allocator = AllocatorPlan::from_manifest(manifest_entry);
        let manifest_expected_kernel_steps = manifest_entry.stored_kernel_step_witnesses();
        let program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                anyhow!("manifest confidential_slot_program missing for {entrypoint}")
            })?;
        let program_expected_kernel_steps = program.expected_runtime_step_witnesses();
        if manifest_expected_kernel_steps != program_expected_kernel_steps {
            bail!(
                "manifest kernel step trace drifted from confidential slot program for {entrypoint}"
            );
        }
        allocator.max_kernel_ops = manifest_expected_kernel_steps.len();
        Ok(Self {
            allocator,
            public_object_ids,
            max_commit_ops: manifest_entry.max_commit_ops,
            program,
            max_hash_part_bytes: manifest_entry.max_hash_part_bytes,
        })
    }
}

impl RuntimeShadowState {
    pub(in crate::runtime) fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject> {
        self.objects
            .get_mut(&object_id)
            .ok_or_else(|| anyhow!("unknown object id {object_id}"))
    }

    pub(in crate::runtime) fn enable_injected_path_oram_leaf_coins(&mut self) {
        for object in self.objects.values_mut() {
            object.enable_injected_path_oram_leaf_coins();
        }
    }

    pub(in crate::runtime) fn install_path_oram_leaf_coins(
        &mut self,
        fresh_coins_by_object: BTreeMap<u32, Vec<usize>>,
    ) -> Result<()> {
        self.enable_injected_path_oram_leaf_coins();
        for (object_id, coins) in fresh_coins_by_object {
            self.object_mut(object_id)?
                .install_path_oram_leaf_coins(coins)?;
        }
        Ok(())
    }

    pub(in crate::runtime) fn ensure_path_oram_leaf_coins_consumed(&self) -> Result<()> {
        for object in self.objects.values() {
            object.ensure_path_oram_leaf_coins_consumed()?;
        }
        Ok(())
    }

    pub(in crate::runtime) fn commit_against(
        &mut self,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Vec<u32>> {
        let mut shadow = std::mem::take(&mut self.objects);
        let mut next_objects = BTreeMap::new();
        let mut committed_object_ids = Vec::with_capacity(committed.objects().len());
        for (id, old) in committed.objects() {
            if let Some(object) = shadow.remove(id) {
                let committed_object = object.commit(old, aborted, recorder, allocator)?;
                committed_object_ids.push(*id);
                next_objects.insert(*id, committed_object);
            } else {
                next_objects.insert(*id, old.clone_committed_cold());
            }
        }
        if let Some((unexpected_id, _)) = shadow.into_iter().next() {
            return Err(anyhow!(
                "shadow state contained unknown object {} during commit",
                unexpected_id
            ));
        }
        self.objects = next_objects;
        Ok(committed_object_ids)
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> CommittedRuntimeState {
        CommittedRuntimeState {
            objects: self
                .objects
                .into_iter()
                .map(|(id, object)| (id, object.into_cold_committed()))
                .collect(),
        }
    }

    #[cfg(test)]
    fn remove_object_for_test(&mut self, object_id: u32) -> Option<RuntimeObject> {
        self.objects.remove(&object_id)
    }
}

impl ConfidentialRuntimeShadowState {
    pub(in crate::runtime) fn from_shadow(shadow: RuntimeShadowState) -> Self {
        Self { shadow }
    }

    pub(in crate::runtime) fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject> {
        self.shadow.object_mut(object_id)
    }

    pub(in crate::runtime) fn install_path_oram_leaf_coins(
        &mut self,
        fresh_coins_by_object: BTreeMap<u32, Vec<usize>>,
    ) -> Result<()> {
        self.shadow
            .install_path_oram_leaf_coins(fresh_coins_by_object)
    }

    pub(in crate::runtime) fn ensure_path_oram_leaf_coins_consumed(&self) -> Result<()> {
        self.shadow.ensure_path_oram_leaf_coins_consumed()
    }

    pub(in crate::runtime) fn commit_against(
        &mut self,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Vec<u32>> {
        self.shadow
            .commit_against(committed, aborted, recorder, allocator)
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> CommittedRuntimeState {
        self.shadow.into_cold_committed_state()
    }

    #[cfg(test)]
    fn remove_object_for_test(&mut self, object_id: u32) -> Option<RuntimeObject> {
        self.shadow.remove_object_for_test(object_id)
    }
}

impl PublicRuntimeShadowState {
    pub(in crate::runtime) fn from_shadow(shadow: RuntimeShadowState) -> Self {
        Self { shadow }
    }

    pub(in crate::runtime) fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject> {
        self.shadow.object_mut(object_id)
    }

    pub(in crate::runtime) fn commit_against(
        &mut self,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Vec<u32>> {
        self.shadow
            .commit_against(committed, aborted, recorder, allocator)
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> CommittedRuntimeState {
        self.shadow.into_cold_committed_state()
    }
}
