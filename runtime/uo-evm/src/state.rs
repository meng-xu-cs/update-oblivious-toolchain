use crate::controller::CallRecorder;
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::kernel::PublicRuntimeKernel;
use crate::runtime::objects::RuntimeObject;
use anyhow::{anyhow, bail, Result};
use std::collections::{BTreeMap, BTreeSet};
use uo_allocator::{AllocatorPlan, AllocatorSession};
use uo_core::{
    ir::StateObject, manifest::EntrypointManifest, ConfidentialKernelSlotProgram,
    RuntimeKernelRefinementEventWitness, RuntimeKernelRefinementWitness, RuntimeKernelStepWitness,
    RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness, Value,
};

#[derive(Debug)]
pub(in crate::runtime) struct ConfidentialCallInputs {
    raw_args: Vec<Value>,
}

impl ConfidentialCallInputs {
    pub(crate) fn from_raw_args(args: Vec<Value>) -> Self {
        Self { raw_args: args }
    }

    pub(in crate::runtime) fn into_raw_args(self) -> Vec<Value> {
        self.raw_args
    }
}

#[derive(Debug)]
pub(in crate::runtime) struct CommittedRuntimeState {
    objects: BTreeMap<u32, RuntimeObject>,
}

#[derive(Debug)]
pub(crate) struct ContractRuntime {
    committed: CommittedRuntimeState,
}

#[derive(Debug, Default)]
pub(crate) struct RuntimeShadowState {
    objects: BTreeMap<u32, RuntimeObject>,
}

#[derive(Debug)]
pub(crate) struct PublicRuntimeShadowState {
    shadow: RuntimeShadowState,
}

#[derive(Clone, Debug)]
pub(crate) struct ConfidentialEntrypointPlan {
    allocator: AllocatorPlan,
    expected_kernel_steps: Vec<RuntimeKernelStepWitness>,
    public_object_ids: Vec<u32>,
    shadow_load_object_ids: Vec<u32>,
    max_commit_ops: usize,
    program: ConfidentialKernelSlotProgram,
    max_hash_part_bytes: usize,
}

#[derive(Clone, Debug)]
pub(crate) struct CommittedRuntimeWitnessSnapshot {
    pub runtime_oram_access_counters: Vec<RuntimeOramAccessCounterWitness>,
    pub runtime_oram_position_maps: Vec<RuntimePathOramPositionMapWitness>,
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
    pub(crate) fn deploy(contract_state: &[StateObject], deploy_seed: u64) -> Result<Self> {
        Ok(Self {
            committed: CommittedRuntimeState::deploy(contract_state, deploy_seed)?,
        })
    }

    pub(crate) fn ensure_cold(&self, expected_object_ids: &[u32], context: &str) -> Result<()> {
        self.committed.ensure_cold(expected_object_ids, context)
    }

    pub(crate) fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {
        self.committed.witness_snapshot()
    }

    pub(crate) fn prepare_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        self.committed
            .prepare_public_shadow(kernel, public_object_ids)
    }

    pub(crate) fn commit_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        shadow: &mut PublicRuntimeShadowState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        self.committed
            .commit_public_shadow(kernel, shadow, aborted, recorder)
    }

    pub(crate) fn prepare_confidential_entrypoint(
        &self,
        entrypoint: &str,
        manifest_entry: &EntrypointManifest,
        public_object_ids: Vec<u32>,
    ) -> Result<ConfidentialEntrypointPlan> {
        ConfidentialEntrypointPlan::from_manifest_entry(
            entrypoint,
            manifest_entry,
            public_object_ids,
        )
    }

    pub(crate) fn run_confidential_entrypoint(
        &mut self,
        plan: ConfidentialEntrypointPlan,
        args: Vec<Value>,
        fresh_coins: Option<&PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
    ) -> Result<ConfidentialCommittedCallOutcome> {
        let ConfidentialEntrypointPlan {
            allocator,
            expected_kernel_steps,
            public_object_ids,
            shadow_load_object_ids,
            max_commit_ops,
            program,
            max_hash_part_bytes,
        } = plan;
        let call_inputs = ConfidentialCallInputs::from_raw_args(args);
        let kernel = PublicRuntimeKernel::begin(
            allocator,
            Some(expected_kernel_steps),
            public_object_ids.clone(),
            Some(public_object_ids),
        )?;
        let mut opcode_trace = Vec::with_capacity(program.body.len().max(1));
        let outcome = self.committed.run_confidential_call(
            kernel,
            &program,
            &shadow_load_object_ids,
            max_hash_part_bytes,
            call_inputs,
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
        Ok(ConfidentialCommittedCallOutcome {
            runtime_kernel_witness: outcome.runtime_kernel_witness,
            runtime_kernel_refinement_witness: outcome.runtime_kernel_refinement_witness,
            aborted: outcome.aborted,
            return_value: outcome.return_value,
            opcode_trace,
        })
    }

    pub(crate) fn replace_with_cold_public_shadow(&mut self, shadow: PublicRuntimeShadowState) {
        self.committed.replace_with_cold_public_shadow(shadow);
    }

    pub(crate) fn finalize_runtime_kernel_refinement_witness(
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
    pub(crate) fn shadow_load_for_test(
        &self,
        kernel: &mut PublicRuntimeKernel,
        object_ids: &[u32],
    ) -> Result<RuntimeShadowState> {
        self.committed.shadow_load_for_test(kernel, object_ids)
    }
}

impl CommittedRuntimeState {
    pub(crate) fn deploy(contract_state: &[StateObject], deploy_seed: u64) -> Result<Self> {
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

    pub(crate) fn ensure_cold(&self, expected_object_ids: &[u32], context: &str) -> Result<()> {
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

    pub(crate) fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {
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

    pub(crate) fn prepare_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        Ok(PublicRuntimeShadowState {
            shadow: kernel
                .inner_mut()
                .shadow_load_objects(self, public_object_ids)?,
        })
    }

    pub(crate) fn commit_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        shadow: &mut PublicRuntimeShadowState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        kernel
            .inner_mut()
            .commit_public_objects(shadow, self, aborted, recorder)
    }

    pub(crate) fn run_confidential_call(
        &mut self,
        kernel: PublicRuntimeKernel,
        program: &ConfidentialKernelSlotProgram,
        shadow_load_object_ids: &[u32],
        max_hash_part_bytes: usize,
        call_inputs: ConfidentialCallInputs,
        fresh_coins: Option<&PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<ConfidentialCommittedKernelOutcome> {
        let outcome = kernel.into_inner().run_confidential_call(
            program,
            self,
            shadow_load_object_ids,
            max_hash_part_bytes,
            call_inputs,
            fresh_coins,
            recorder,
            opcode_trace,
        )?;
        self.objects = outcome.committed_shadow.into_cold_committed_state().objects;
        Ok(ConfidentialCommittedKernelOutcome {
            runtime_kernel_witness: outcome.runtime_kernel_witness,
            runtime_kernel_refinement_witness: outcome.runtime_kernel_refinement_witness,
            aborted: outcome.aborted,
            return_value: outcome.return_value,
        })
    }

    pub(crate) fn replace_with_cold_public_shadow(&mut self, shadow: PublicRuntimeShadowState) {
        self.objects = shadow.into_cold_committed_state().objects;
    }

    pub(crate) fn finalize_runtime_kernel_refinement_witness(
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
    pub(crate) fn shadow_load_for_test(
        &self,
        kernel: &mut PublicRuntimeKernel,
        object_ids: &[u32],
    ) -> Result<RuntimeShadowState> {
        kernel.inner_mut().shadow_load_objects(self, object_ids)
    }
}

impl ConfidentialEntrypointPlan {
    fn from_manifest_entry(
        entrypoint: &str,
        manifest_entry: &EntrypointManifest,
        public_object_ids: Vec<u32>,
    ) -> Result<Self> {
        let mut allocator = AllocatorPlan::from_manifest(manifest_entry);
        let manifest_expected_kernel_steps = manifest_entry
            .kernel_steps
            .iter()
            .map(|step| RuntimeKernelStepWitness {
                opcode: step.opcode,
                object_id: step.object_id,
            })
            .collect::<Vec<_>>();
        let program = manifest_entry
            .confidential_slot_program
            .clone()
            .ok_or_else(|| {
                anyhow!("manifest confidential_slot_program missing for {entrypoint}")
            })?;
        let expected_kernel_steps = program
            .expected_runtime_steps()
            .into_iter()
            .map(RuntimeKernelStepWitness::from)
            .collect::<Vec<_>>();
        if manifest_expected_kernel_steps != expected_kernel_steps {
            bail!(
                "manifest kernel step trace drifted from confidential slot program for {entrypoint}"
            );
        }
        allocator.max_kernel_ops = expected_kernel_steps.len();
        let shadow_load_object_ids = expected_kernel_steps
            .iter()
            .filter_map(|step| step.object_id)
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>();
        Ok(Self {
            allocator,
            expected_kernel_steps,
            public_object_ids,
            shadow_load_object_ids,
            max_commit_ops: manifest_entry.max_commit_ops,
            program,
            max_hash_part_bytes: manifest_entry.max_hash_part_bytes,
        })
    }
}

#[derive(Debug)]
pub(in crate::runtime) struct ConfidentialCommittedKernelOutcome {
    pub runtime_kernel_witness: uo_core::RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: uo_core::RuntimeKernelRefinementWitness,
    pub aborted: bool,
    pub return_value: Option<Value>,
}

#[derive(Debug)]
pub(crate) struct ConfidentialCommittedCallOutcome {
    pub runtime_kernel_witness: uo_core::RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: uo_core::RuntimeKernelRefinementWitness,
    pub aborted: bool,
    pub return_value: Option<Value>,
    pub opcode_trace: Vec<String>,
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
        fresh_coins_by_object: &BTreeMap<u32, Vec<usize>>,
    ) -> Result<()> {
        self.enable_injected_path_oram_leaf_coins();
        for (object_id, coins) in fresh_coins_by_object {
            self.object_mut(*object_id)?
                .install_path_oram_leaf_coins(coins.clone())?;
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
    pub(crate) fn remove_object_for_test(&mut self, object_id: u32) -> Option<RuntimeObject> {
        self.objects.remove(&object_id)
    }
}

impl PublicRuntimeShadowState {
    pub(in crate::runtime) fn inner_mut(&mut self) -> &mut RuntimeShadowState {
        &mut self.shadow
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> CommittedRuntimeState {
        self.shadow.into_cold_committed_state()
    }
}
