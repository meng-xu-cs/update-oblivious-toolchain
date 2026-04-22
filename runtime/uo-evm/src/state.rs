use crate::controller::{CallRecorder, PublicCallSummary};
use crate::runtime::fresh_coins::{PathOramFreshCoinEntry, PathOramFreshCoinPlan};
use crate::runtime::kernel::PublicRuntimeKernel;
use crate::runtime::objects::RuntimeObject;
use anyhow::{anyhow, bail, Result};
use std::cmp::Ordering;
use std::mem::MaybeUninit;
use uo_allocator::{AllocatorPlan, AllocatorSession};
use uo_core::{
    ir::StateObject, manifest::EntrypointManifest, CommittedRuntimeWitnessSnapshot,
    CommittedRuntimeWitnessSnapshotBuilder, ConfidentialCallInputs, ConfidentialKernelSlotProgram,
    RuntimeCallOutcome, RuntimeKernelFinishBundle, TracedRuntimeCallOutcome,
    TracedRuntimeCallStart, Value,
};

#[derive(Debug)]
pub(in crate::runtime) struct CommittedRuntimeState {
    objects: RuntimeObjectTable,
}

#[derive(Debug)]
pub(crate) struct ContractRuntime {
    committed: CommittedRuntimeState,
}

#[derive(Debug, Default)]
pub(in crate::runtime) struct RuntimeShadowState {
    objects: RuntimeObjectTable,
}

#[derive(Debug)]
struct RuntimeObjectEntry {
    object_id: u32,
    object: RuntimeObject,
}

#[derive(Debug, Default)]
struct RuntimeObjectTable {
    entries: Box<[RuntimeObjectEntry]>,
}

#[derive(Debug)]
struct FixedBoxBuilder<T> {
    entries: Box<[MaybeUninit<T>]>,
    initialized: usize,
}

#[derive(Debug)]
pub(in crate::runtime) struct ConfidentialRuntimeShadowState {
    shadow: RuntimeShadowState,
}

#[derive(Debug)]
pub(in crate::runtime) struct PublicRuntimeShadowState {
    shadow: RuntimeShadowState,
}

impl RuntimeObjectEntry {
    fn clone_committed_cold(&self) -> Self {
        Self {
            object_id: self.object_id,
            object: self.object.clone_committed_cold(),
        }
    }

    fn into_cold_committed(self) -> Self {
        Self {
            object_id: self.object_id,
            object: self.object.into_cold_committed(),
        }
    }
}

impl<T> FixedBoxBuilder<T> {
    fn new(len: usize) -> Self {
        Self {
            entries: Box::<[T]>::new_uninit_slice(len),
            initialized: 0,
        }
    }

    fn push(&mut self, value: T) {
        assert!(
            self.initialized < self.entries.len(),
            "fixed-size boxed builder overflow"
        );
        self.entries[self.initialized].write(value);
        self.initialized += 1;
    }

    fn finish(mut self) -> Box<[T]> {
        assert_eq!(
            self.initialized,
            self.entries.len(),
            "fixed-size boxed builder underfilled"
        );
        let entries = std::mem::take(&mut self.entries);
        self.initialized = 0;
        let raw = Box::into_raw(entries) as *mut [T];
        unsafe { Box::from_raw(raw) }
    }
}

impl<T> Drop for FixedBoxBuilder<T> {
    fn drop(&mut self) {
        for entry in &mut self.entries[..self.initialized] {
            unsafe { entry.assume_init_drop() };
        }
    }
}

impl RuntimeObjectTable {
    fn new(entries: Box<[RuntimeObjectEntry]>) -> Self {
        Self { entries }
    }

    fn len(&self) -> usize {
        self.entries.len()
    }

    fn iter(&self) -> impl Iterator<Item = (u32, &RuntimeObject)> {
        self.entries
            .iter()
            .map(|entry| (entry.object_id, &entry.object))
    }

    fn values(&self) -> impl Iterator<Item = &RuntimeObject> {
        self.entries.iter().map(|entry| &entry.object)
    }

    fn values_mut(&mut self) -> impl Iterator<Item = &mut RuntimeObject> {
        self.entries.iter_mut().map(|entry| &mut entry.object)
    }

    fn object_ids(&self) -> Box<[u32]> {
        self.entries
            .iter()
            .map(|entry| entry.object_id)
            .collect::<Vec<_>>()
            .into_boxed_slice()
    }

    fn get(&self, object_id: u32) -> Option<&RuntimeObject> {
        self.entries
            .iter()
            .find(|entry| entry.object_id == object_id)
            .map(|entry| &entry.object)
    }

    fn get_mut(&mut self, object_id: u32) -> Option<&mut RuntimeObject> {
        self.entries
            .iter_mut()
            .find(|entry| entry.object_id == object_id)
            .map(|entry| &mut entry.object)
    }

    fn clone_committed_cold(&self) -> Self {
        let mut entries = FixedBoxBuilder::new(self.entries.len());
        for entry in self.entries.iter() {
            entries.push(entry.clone_committed_cold());
        }
        Self::new(entries.finish())
    }

    fn clone_for_shadow(
        &self,
        object_ids: &[u32],
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let mut entries = FixedBoxBuilder::new(object_ids.len());
        for object_id in object_ids {
            let object = self
                .get(*object_id)
                .ok_or_else(|| anyhow!("missing committed object {}", object_id))?;
            entries.push(RuntimeObjectEntry {
                object_id: *object_id,
                object: object.clone_for_tx(allocator)?,
            });
        }
        Ok(Self::new(entries.finish()))
    }

    fn into_cold_committed(self) -> Self {
        let len = self.entries.len();
        let mut entries = FixedBoxBuilder::new(len);
        for entry in std::iter::IntoIterator::into_iter(self.entries) {
            entries.push(entry.into_cold_committed());
        }
        Self::new(entries.finish())
    }

    fn into_entries(self) -> Box<[RuntimeObjectEntry]> {
        self.entries
    }

    #[cfg(test)]
    fn insert_for_test(&mut self, object_id: u32, object: RuntimeObject) {
        if let Some(entry) = self
            .entries
            .iter_mut()
            .find(|entry| entry.object_id == object_id)
        {
            entry.object = object;
            return;
        }
        let mut entries = std::mem::take(&mut self.entries).into_vec();
        let insert_at = match entries.binary_search_by_key(&object_id, |entry| entry.object_id) {
            Ok(index) | Err(index) => index,
        };
        entries.insert(insert_at, RuntimeObjectEntry { object_id, object });
        self.entries = entries.into_boxed_slice();
    }

    #[cfg(test)]
    fn remove_for_test(&mut self, object_id: u32) -> Option<RuntimeObject> {
        let mut entries = std::mem::take(&mut self.entries).into_vec();
        let index = entries
            .binary_search_by_key(&object_id, |entry| entry.object_id)
            .ok()?;
        let removed = entries.remove(index).object;
        self.entries = entries.into_boxed_slice();
        Some(removed)
    }
}

impl Clone for CommittedRuntimeState {
    fn clone(&self) -> Self {
        Self {
            objects: self.objects.clone_committed_cold(),
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

    pub(in crate::runtime) fn public_object_ids(&self) -> Box<[u32]> {
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
            TracedRuntimeCallStart::new(self.witness_snapshot()?),
            public_call,
            recorder,
        ))
    }

    fn ensure_ready_for_call(&self, context: &str) -> Result<()> {
        let public_object_ids = self.public_object_ids();
        self.ensure_cold(public_object_ids.as_ref(), context)
    }

    pub(in crate::runtime) fn finish_traced_call(
        &self,
        call_outcome: RuntimeCallOutcome,
    ) -> Result<TracedRuntimeCallOutcome> {
        Ok(TracedRuntimeCallOutcome::new(
            call_outcome,
            self.witness_snapshot()?,
        ))
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
        raw_args: Box<[Value]>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
    ) -> Result<RuntimeCallOutcome> {
        let public_object_ids = self.public_object_ids();
        let plan =
            manifest_entry.runtime_confidential_entrypoint_plan(entrypoint, public_object_ids)?;
        let mut allocator = AllocatorPlan::from_manifest(manifest_entry);
        allocator.max_kernel_ops = plan.max_kernel_ops();
        let kernel = PublicRuntimeKernel::begin(allocator, plan.public_object_ids())?;
        let mut opcode_trace =
            Vec::with_capacity(plan.confidential_slot_program().body.len().max(1));
        let args = ConfidentialCallInputs::from_raw_args(raw_args);
        let (runtime_kernel_finish_bundle, aborted, return_value) =
            self.committed.run_confidential_call(
                kernel,
                plan.confidential_slot_program(),
                plan.max_hash_part_bytes(),
                args,
                fresh_coins,
                recorder,
                &mut opcode_trace,
            )?;
        if recorder.physical_write_count() > plan.max_commit_ops() {
            bail!(
                "entrypoint {} exceeded manifest commit budget: {} > {}",
                plan.confidential_slot_program().entrypoint_id,
                recorder.physical_write_count(),
                plan.max_commit_ops()
            );
        }
        self.ensure_cold_call_boundary(
            plan.public_object_ids(),
            "after completing the call and returning to committed storage",
        )?;
        Ok(RuntimeCallOutcome::from_runtime_execution(
            runtime_kernel_finish_bundle,
            aborted,
            return_value,
            opcode_trace.into_boxed_slice(),
        ))
    }

    pub(in crate::runtime) fn replace_with_cold_public_shadow(
        &mut self,
        shadow: PublicRuntimeShadowState,
    ) {
        self.committed.replace_with_cold_public_shadow(shadow);
    }

    pub(in crate::runtime) fn ensure_cold_call_boundary(
        &self,
        public_object_ids: &[u32],
        context: &str,
    ) -> Result<()> {
        self.committed
            .ensure_cold_call_boundary(public_object_ids, context)
    }

    #[cfg(test)]
    pub(crate) fn object_entries_for_test(&self) -> impl Iterator<Item = (u32, &RuntimeObject)> {
        self.committed.object_entries_for_test()
    }

    #[cfg(test)]
    pub(crate) fn object_values_for_test(&self) -> impl Iterator<Item = &RuntimeObject> {
        self.committed.object_values_for_test()
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
            &[],
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
        let mut objects = FixedBoxBuilder::new(contract_state.len());
        let mut master_seed = deploy_seed;
        for spec in contract_state {
            objects.push(RuntimeObjectEntry {
                object_id: spec.id,
                object: RuntimeObject::instantiate_with_seed(spec, master_seed)?,
            });
            master_seed = master_seed
                .wrapping_mul(0x9E37_79B9_7F4A_7C15)
                .wrapping_add(0xA5A5_A5A5_A5A5_A5A5);
        }
        let mut objects = objects.finish();
        objects.sort_by_key(|entry| entry.object_id);
        for pair in objects.windows(2) {
            if pair[0].object_id == pair[1].object_id {
                bail!("duplicate committed object id {}", pair[0].object_id);
            }
        }
        Ok(Self {
            objects: RuntimeObjectTable::new(objects),
        })
    }

    fn ensure_cold(&self, expected_object_ids: &[u32], context: &str) -> Result<()> {
        let witnessed_object_ids = self.objects.object_ids();
        if witnessed_object_ids.as_ref() != expected_object_ids {
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

    fn public_object_ids(&self) -> Box<[u32]> {
        self.objects.object_ids()
    }

    fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {
        let path_oram_object_count = self
            .objects
            .values()
            .filter(|object| object.exposes_path_oram_witnesses())
            .count();
        let mut snapshot = CommittedRuntimeWitnessSnapshotBuilder::new(path_oram_object_count);
        for object in self.objects.values() {
            if object.exposes_path_oram_witnesses() {
                snapshot.push(
                    object
                        .path_oram_access_counter_witness()
                        .expect("Path-ORAM object must expose an access-counter witness"),
                    object
                        .path_oram_position_map_witness()?
                        .expect("Path-ORAM object must expose a position-map witness"),
                )?;
            }
        }
        snapshot.finish().map_err(anyhow::Error::from)
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
        raw_args: ConfidentialCallInputs,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<(RuntimeKernelFinishBundle, bool, Option<Value>)> {
        let (committed_shadow, runtime_kernel_finish_bundle, aborted, return_value) = kernel
            .run_confidential_call(
                program,
                self,
                max_hash_part_bytes,
                raw_args,
                fresh_coins,
                recorder,
                opcode_trace,
            )?;
        self.objects = committed_shadow.into_cold_committed_state().objects;
        Ok((runtime_kernel_finish_bundle, aborted, return_value))
    }

    pub(in crate::runtime) fn replace_with_cold_public_shadow(
        &mut self,
        shadow: PublicRuntimeShadowState,
    ) {
        self.objects = shadow.into_cold_committed_state().objects;
    }

    pub(in crate::runtime) fn ensure_cold_call_boundary(
        &self,
        public_object_ids: &[u32],
        context: &str,
    ) -> Result<()> {
        self.ensure_cold(public_object_ids, context)
    }

    pub(in crate::runtime) fn shadow_load(
        &self,
        object_ids: &[u32],
        allocator: &mut AllocatorSession,
    ) -> Result<RuntimeShadowState> {
        Ok(RuntimeShadowState {
            objects: self.objects.clone_for_shadow(object_ids, allocator)?,
        })
    }

    #[cfg(test)]
    pub(crate) fn object_entries_for_test(&self) -> impl Iterator<Item = (u32, &RuntimeObject)> {
        self.objects.iter()
    }

    #[cfg(test)]
    pub(crate) fn object_values_for_test(&self) -> impl Iterator<Item = &RuntimeObject> {
        self.objects.values()
    }

    #[cfg(test)]
    pub(crate) fn insert_object_for_test(&mut self, object_id: u32, object: RuntimeObject) {
        self.objects.insert_for_test(object_id, object);
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

impl RuntimeShadowState {
    pub(in crate::runtime) fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject> {
        self.objects
            .get_mut(object_id)
            .ok_or_else(|| anyhow!("unknown object id {object_id}"))
    }

    pub(in crate::runtime) fn enable_injected_path_oram_leaf_coins(&mut self) {
        for object in self.objects.values_mut() {
            object.enable_injected_path_oram_leaf_coins();
        }
    }

    pub(in crate::runtime) fn install_path_oram_leaf_coins(
        &mut self,
        fresh_coins_by_object: Box<[PathOramFreshCoinEntry]>,
    ) -> Result<()> {
        self.enable_injected_path_oram_leaf_coins();
        for entry in std::iter::IntoIterator::into_iter(fresh_coins_by_object) {
            let (object_id, coins) = entry.into_parts();
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
    ) -> Result<Box<[u32]>> {
        let shadow_len = self.objects.len();
        let mut shadow =
            std::iter::IntoIterator::into_iter(std::mem::take(&mut self.objects).into_entries())
                .peekable();
        let mut next_objects = FixedBoxBuilder::new(committed.objects.len());
        let mut committed_object_ids = FixedBoxBuilder::new(shadow_len);
        for (id, old) in committed.objects.iter() {
            match shadow.peek().map(|entry| entry.object_id.cmp(&id)) {
                Some(Ordering::Less) => {
                    let unexpected_id = shadow
                        .next()
                        .expect("peeked shadow entry must exist")
                        .object_id;
                    return Err(anyhow!(
                        "shadow state contained unknown object {} during commit",
                        unexpected_id
                    ));
                }
                Some(Ordering::Equal) => {
                    let entry = shadow.next().expect("peeked shadow entry must exist");
                    let committed_object =
                        entry.object.commit(old, aborted, recorder, allocator)?;
                    committed_object_ids.push(id);
                    next_objects.push(RuntimeObjectEntry {
                        object_id: id,
                        object: committed_object,
                    });
                }
                Some(Ordering::Greater) | None => {
                    next_objects.push(RuntimeObjectEntry {
                        object_id: id,
                        object: old.clone_committed_cold(),
                    });
                }
            }
        }
        if let Some(unexpected) = shadow.next() {
            return Err(anyhow!(
                "shadow state contained unknown object {} during commit",
                unexpected.object_id
            ));
        }
        self.objects = RuntimeObjectTable::new(next_objects.finish());
        Ok(committed_object_ids.finish())
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> CommittedRuntimeState {
        CommittedRuntimeState {
            objects: self.objects.into_cold_committed(),
        }
    }

    #[cfg(test)]
    fn remove_object_for_test(&mut self, object_id: u32) -> Option<RuntimeObject> {
        self.objects.remove_for_test(object_id)
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
        fresh_coins_by_object: Box<[PathOramFreshCoinEntry]>,
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
    ) -> Result<Box<[u32]>> {
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
    ) -> Result<Box<[u32]>> {
        self.shadow
            .commit_against(committed, aborted, recorder, allocator)
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> CommittedRuntimeState {
        self.shadow.into_cold_committed_state()
    }
}
