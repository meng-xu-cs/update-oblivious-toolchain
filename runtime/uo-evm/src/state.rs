use crate::controller::CallRecorder;
use crate::runtime::kernel::PublicRuntimeKernel;
use crate::runtime::objects::RuntimeObject;
use anyhow::{anyhow, bail, Result};
use std::collections::BTreeMap;
use uo_allocator::AllocatorSession;
use uo_core::{
    ir::{CompiledFunction, StateObject},
    RuntimeKernelRefinementEventWitness, RuntimeKernelRefinementWitness,
    RuntimeOramAccessCounterWitness, RuntimePathOramPositionMapWitness, Value,
};

#[derive(Debug)]
pub(crate) struct CommittedRuntimeState {
    objects: BTreeMap<u32, RuntimeObject>,
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
        function: &CompiledFunction,
        shadow_load_object_ids: &[u32],
        args: Vec<Value>,
        fresh_coins_by_object: Option<&BTreeMap<u32, Vec<usize>>>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<ConfidentialCommittedCallOutcome> {
        let outcome = kernel.into_inner().run_confidential_call(
            function,
            self,
            shadow_load_object_ids,
            args,
            fresh_coins_by_object,
            recorder,
            opcode_trace,
        )?;
        self.objects = outcome.committed_shadow.into_cold_committed_state().objects;
        Ok(ConfidentialCommittedCallOutcome {
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

#[derive(Debug)]
pub(crate) struct ConfidentialCommittedCallOutcome {
    pub runtime_kernel_witness: uo_core::RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: uo_core::RuntimeKernelRefinementWitness,
    pub aborted: bool,
    pub return_value: Option<Value>,
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
