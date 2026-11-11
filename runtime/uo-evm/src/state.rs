use crate::controller::{CallRecorder, PublicCallSummary};
use crate::freshness::derive_runtime_object_seed;
use crate::runtime::fresh_coins::{PathOramFreshCoinEntry, PathOramFreshCoinPlan};
use crate::runtime::objects::RuntimeObject;
use anyhow::{anyhow, bail, Result};
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use uo_allocator::{AllocatorPlan, AllocatorSession};
use uo_core::{
    ir::StateObject, manifest::EntrypointManifest, CommittedRuntimeWitnessSnapshot,
    CommittedRuntimeWitnessSnapshotBuilder, ConfidentialKernelSlotProgram, FixedBoxBuilder,
    RuntimeCallOutcome, RuntimeKernelFinishBundle, RuntimePublicStateTransition,
    TracedRuntimeCallOutcome, TracedRuntimeCallStart, Value,
};
use uo_kernel_runtime::{
    RuntimeKernelConfidentialStore, RuntimeKernelMachine as PublicRuntimeKernel,
    RuntimeKernelObjectStore, RuntimeKernelStatementTrace,
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

#[derive(Serialize)]
struct RuntimePublicObjectStateSnapshot {
    object_id: u32,
    payload: serde_json::Value,
}

/// The public objects of a state, each with its snapshot payload, in object-id
/// order, and their digest.
pub(in crate::runtime) struct PublicStateSnapshot {
    objects: Vec<RuntimePublicObjectStateSnapshot>,
    digest: String,
}

impl PublicStateSnapshot {
    fn from_objects(objects: Vec<RuntimePublicObjectStateSnapshot>) -> Result<Self> {
        let digest = hash_json(&objects)?;
        Ok(Self { objects, digest })
    }

    /// The ids of the public objects whose payload differs between this
    /// snapshot and `committed`, ascending: a transition's public delta
    /// (`publicStateDelta` in `UOToolchain/IRSemantics.lean`).
    fn delta(&self, committed: &Self) -> Vec<u32> {
        let initial: BTreeMap<u32, &serde_json::Value> = self
            .objects
            .iter()
            .map(|object| (object.object_id, &object.payload))
            .collect();
        let committed: BTreeMap<u32, &serde_json::Value> = committed
            .objects
            .iter()
            .map(|object| (object.object_id, &object.payload))
            .collect();
        let object_ids: BTreeSet<u32> = initial.keys().chain(committed.keys()).copied().collect();
        object_ids
            .into_iter()
            .filter(|object_id| initial.get(object_id) != committed.get(object_id))
            .collect()
    }
}

#[derive(Debug, Default)]
struct RuntimeObjectTable {
    entries: Box<[RuntimeObjectEntry]>,
}

#[derive(Debug)]
pub(in crate::runtime) struct ConfidentialRuntimeShadowState {
    shadow: RuntimeShadowState,
    // The public-state digest of the call's candidate state, taken when the
    // call commits.
    candidate_public_state_hash: Option<String>,
}

#[derive(Debug)]
pub(in crate::runtime) struct PublicRuntimeShadowState {
    shadow: RuntimeShadowState,
}

impl RuntimeObjectEntry {
    fn into_cold_committed(self) -> Result<Self> {
        Ok(Self {
            object_id: self.object_id,
            object: self.object.into_cold_committed()?,
        })
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

    fn object_ids(&self) -> Result<Box<[u32]>> {
        let mut object_ids = FixedBoxBuilder::new(self.entries.len());
        for entry in &self.entries {
            object_ids.push(entry.object_id)?;
        }
        object_ids.finish()
    }

    fn public_state_snapshot(&self) -> Result<PublicStateSnapshot> {
        let mut allocator = public_state_snapshot_allocator()?;
        let mut snapshots = Vec::new();
        for entry in &self.entries {
            if let Some(payload) = entry.object.public_state_snapshot_value(&mut allocator)? {
                snapshots.push(RuntimePublicObjectStateSnapshot {
                    object_id: entry.object_id,
                    payload,
                });
            }
        }
        PublicStateSnapshot::from_objects(snapshots)
    }

    fn public_state_digest(&self) -> Result<String> {
        Ok(self.public_state_snapshot()?.digest)
    }

    /// The public-state digest of this staged table over `committed`: each
    /// object as staged here, or as committed when the call did not load it.
    fn staged_public_state_digest(&self, committed: &Self) -> Result<String> {
        let mut allocator = public_state_snapshot_allocator()?;
        let mut snapshots = Vec::new();
        for (object_id, committed_object) in committed.iter() {
            let object = self.get(object_id).unwrap_or(committed_object);
            if let Some(payload) = object.public_state_snapshot_value(&mut allocator)? {
                snapshots.push(RuntimePublicObjectStateSnapshot { object_id, payload });
            }
        }
        hash_json(&snapshots)
    }

    fn get(&self, object_id: u32) -> Option<&RuntimeObject> {
        let mut found_index = None;
        for (index, entry) in self.entries.iter().enumerate() {
            if entry.object_id == object_id {
                found_index = Some(index);
            }
        }
        found_index.and_then(|index| self.entries.get(index).map(|entry| &entry.object))
    }

    fn get_mut(&mut self, object_id: u32) -> Option<&mut RuntimeObject> {
        let mut found_index = None;
        for (index, entry) in self.entries.iter().enumerate() {
            if entry.object_id == object_id {
                found_index = Some(index);
            }
        }
        found_index.and_then(|index| self.entries.get_mut(index).map(|entry| &mut entry.object))
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
            })?;
        }
        Ok(Self::new(entries.finish()?))
    }

    fn into_cold_committed(self) -> Result<Self> {
        let len = self.entries.len();
        let mut entries = FixedBoxBuilder::new(len);
        for entry in std::iter::IntoIterator::into_iter(self.entries) {
            entries.push(entry.into_cold_committed()?)?;
        }
        Ok(Self::new(entries.finish()?))
    }

    fn clone_cold(&self) -> Result<Self> {
        let mut entries = FixedBoxBuilder::new(self.entries.len());
        for entry in self.entries.iter() {
            entries.push(RuntimeObjectEntry {
                object_id: entry.object_id,
                object: entry.object.clone_committed_cold()?,
            })?;
        }
        Ok(Self::new(entries.finish()?))
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

impl ContractRuntime {
    pub(in crate::runtime) fn deploy(
        contract_state: &[StateObject],
        deploy_seed: u64,
    ) -> Result<Self> {
        Ok(Self {
            committed: CommittedRuntimeState::deploy(contract_state, deploy_seed)?,
        })
    }

    /// Deep cold clone of the committed state for staged (transactional)
    /// execution. The returned runtime can be mutated by a call and committed
    /// back only on full success; on any failure it is dropped, leaving the
    /// original committed state untouched.
    pub(in crate::runtime) fn staged_clone(&self) -> Result<Self> {
        Ok(Self {
            committed: self.committed.clone_cold()?,
        })
    }

    pub(in crate::runtime) fn ensure_cold(
        &self,
        expected_object_ids: &[u32],
        context: &str,
    ) -> Result<()> {
        self.committed.ensure_cold(expected_object_ids, context)
    }

    pub(in crate::runtime) fn public_object_ids(&self) -> Result<Box<[u32]>> {
        self.committed.public_object_ids()
    }

    #[cfg(any(test, feature = "diagnostics"))]
    pub(crate) fn public_state_digest(&self) -> Result<String> {
        Ok(self.public_state_snapshot()?.digest)
    }

    pub(in crate::runtime) fn public_state_snapshot(&self) -> Result<PublicStateSnapshot> {
        self.committed.objects.public_state_snapshot()
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
        let public_object_ids = self.public_object_ids()?;
        self.ensure_cold(public_object_ids.as_ref(), context)
    }

    /// Verify the *committed* state is cold before it is cloned for a staged
    /// call. Staging clones objects cold, so this check must run on the original
    /// committed state rather than the cold clone, otherwise a hot residual
    /// would be silently masked.
    pub(in crate::runtime) fn ensure_committed_cold_for_call(&self) -> Result<()> {
        self.ensure_ready_for_call("before executing the next call from committed storage")
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
        let public_object_ids = self.public_object_ids()?;
        let initial_public_state = self.public_state_snapshot()?;
        let plan =
            manifest_entry.runtime_confidential_entrypoint_plan(entrypoint, public_object_ids)?;
        self.committed
            .ensure_confidential_program_targets_uo_backends(plan.confidential_slot_program())?;
        let mut allocator = AllocatorPlan::from_manifest(manifest_entry);
        allocator.max_kernel_ops = plan.max_kernel_ops();
        let kernel = PublicRuntimeKernel::begin(allocator, plan.public_object_ids())?;
        let mut opcode_trace =
            RuntimeKernelStatementTrace::new(plan.confidential_slot_program().body.len());
        let (
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            aborted,
            return_value,
            candidate_public_state_hash,
        ) = self.committed.run_confidential_call(
            kernel,
            plan.confidential_slot_program(),
            plan.max_hash_part_bytes(),
            raw_args,
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
        let public_state_transition = public_state_transition(
            &initial_public_state,
            candidate_public_state_hash,
            &self.public_state_snapshot()?,
            aborted,
        )?;
        Ok(RuntimeCallOutcome::from_runtime_execution(
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            aborted,
            return_value,
            opcode_trace.into_boxed_trace(),
        )
        .with_public_state_transition(public_state_transition))
    }

    pub(in crate::runtime) fn replace_with_cold_public_shadow(
        &mut self,
        shadow: PublicRuntimeShadowState,
    ) -> Result<()> {
        self.committed.replace_with_cold_public_shadow(shadow)
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
                max_commit_ops: 0,
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
        for spec in contract_state {
            let object_seed = derive_runtime_object_seed(deploy_seed, spec.id, &spec.name);
            objects.push(RuntimeObjectEntry {
                object_id: spec.id,
                object: RuntimeObject::instantiate_with_seed(spec, object_seed)?,
            })?;
        }
        let mut objects = objects.finish()?;
        objects.sort_by_key(|entry| entry.object_id);
        for pair in objects.windows(2) {
            if let [left, right] = pair {
                if left.object_id == right.object_id {
                    bail!("duplicate committed object id {}", left.object_id);
                }
            }
        }
        Ok(Self {
            objects: RuntimeObjectTable::new(objects),
        })
    }

    fn clone_cold(&self) -> Result<Self> {
        Ok(Self {
            objects: self.objects.clone_cold()?,
        })
    }

    fn ensure_cold(&self, expected_object_ids: &[u32], context: &str) -> Result<()> {
        let witnessed_object_ids = self.objects.object_ids()?;
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

    fn public_object_ids(&self) -> Result<Box<[u32]>> {
        self.objects.object_ids()
    }

    fn ensure_confidential_program_targets_uo_backends(
        &self,
        program: &ConfidentialKernelSlotProgram,
    ) -> Result<()> {
        #[cfg(feature = "insecure-eval-raw")]
        {
            let _ = program;
            Ok(())
        }
        #[cfg(not(feature = "insecure-eval-raw"))]
        {
            for step in program.expected_runtime_steps().iter() {
                let Some(object_id) = step.object_id else {
                    continue;
                };
                let object = self.objects.get(object_id).ok_or_else(|| {
                    anyhow!(
                        "confidential kernel program {} references missing object {}",
                        program.entrypoint_id,
                        object_id
                    )
                })?;
                if !object.is_update_oblivious_backend() {
                    bail!(
                        "confidential kernel program {} targets raw backend object {} ({})",
                        program.entrypoint_id,
                        object.name(),
                        object_id
                    );
                }
                if !object.is_confidential() {
                    bail!(
                        "confidential kernel program {} targets non-confidential object {} ({})",
                        program.entrypoint_id,
                        object.name(),
                        object_id
                    );
                }
            }
            Ok(())
        }
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
                let access_counter =
                    object.path_oram_access_counter_witness().ok_or_else(|| {
                        anyhow!("Path-ORAM object must expose an access-counter witness")
                    })?;
                let position_map = object.path_oram_position_map_witness()?.ok_or_else(|| {
                    anyhow!("Path-ORAM object must expose a position-map witness")
                })?;
                snapshot.push(access_counter, position_map)?;
            }
        }
        snapshot.finish().map_err(anyhow::Error::from)
    }

    pub(in crate::runtime) fn prepare_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        let shadow = kernel.shadow_load_with(public_object_ids, |allocator| {
            self.shadow_load(public_object_ids, allocator)
        })?;
        Ok(PublicRuntimeShadowState::from_shadow(shadow))
    }

    pub(in crate::runtime) fn commit_public_shadow(
        &self,
        kernel: &mut PublicRuntimeKernel,
        shadow: &mut PublicRuntimeShadowState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        kernel.commit_objects(shadow, self, aborted, recorder)
    }

    fn run_confidential_call(
        &mut self,
        kernel: PublicRuntimeKernel,
        program: &ConfidentialKernelSlotProgram,
        max_hash_part_bytes: usize,
        raw_args: Box<[Value]>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut RuntimeKernelStatementTrace,
    ) -> Result<(
        uo_core::RuntimeKernelMachineFinishWitness,
        RuntimeKernelFinishBundle,
        bool,
        Option<Value>,
        String,
    )> {
        let (
            committed_shadow,
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            aborted,
            return_value,
        ) = kernel
            .run_confidential_call::<ConfidentialRuntimeShadowState>(
                program,
                self,
                max_hash_part_bytes,
                raw_args,
                fresh_coins,
                recorder,
                opcode_trace,
            )
            .map_err(|err| {
                anyhow!(
                    "confidential kernel program {}: {err}",
                    program.entrypoint_id
                )
            })?;
        let candidate_public_state_hash = committed_shadow.candidate_public_state_hash()?;
        self.objects = committed_shadow.into_cold_committed_state()?.objects;
        Ok((
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            aborted,
            return_value,
            candidate_public_state_hash,
        ))
    }

    pub(in crate::runtime) fn replace_with_cold_public_shadow(
        &mut self,
        shadow: PublicRuntimeShadowState,
    ) -> Result<()> {
        self.objects = shadow.into_cold_committed_state()?.objects;
        Ok(())
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
        kernel.shadow_load_with(object_ids, |allocator| {
            ConfidentialRuntimeShadowState::shadow_load(self, object_ids, allocator)
        })
    }
}

impl RuntimeShadowState {
    fn public_state_digest(&self) -> Result<String> {
        self.objects.public_state_digest()
    }

    fn public_state_snapshot(&self) -> Result<PublicStateSnapshot> {
        self.objects.public_state_snapshot()
    }

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
                    let Some(entry) = shadow.next() else {
                        return Err(anyhow!("peeked shadow entry vanished during commit"));
                    };
                    let unexpected_id = entry.object_id;
                    return Err(anyhow!(
                        "shadow state contained unknown object {} during commit",
                        unexpected_id
                    ));
                }
                Some(Ordering::Equal) => {
                    let Some(entry) = shadow.next() else {
                        return Err(anyhow!("peeked shadow entry vanished during commit"));
                    };
                    let committed_object =
                        entry.object.commit(old, aborted, recorder, allocator)?;
                    committed_object_ids.push(id)?;
                    next_objects.push(RuntimeObjectEntry {
                        object_id: id,
                        object: committed_object,
                    })?;
                }
                Some(Ordering::Greater) | None => {
                    next_objects.push(RuntimeObjectEntry {
                        object_id: id,
                        object: old.clone_committed_cold()?,
                    })?;
                }
            }
        }
        if let Some(unexpected) = shadow.next() {
            return Err(anyhow!(
                "shadow state contained unknown object {} during commit",
                unexpected.object_id
            ));
        }
        self.objects = RuntimeObjectTable::new(next_objects.finish()?);
        committed_object_ids.finish()
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> Result<CommittedRuntimeState> {
        Ok(CommittedRuntimeState {
            objects: self.objects.into_cold_committed()?,
        })
    }

    #[cfg(test)]
    fn remove_object_for_test(&mut self, object_id: u32) -> Option<RuntimeObject> {
        self.objects.remove_for_test(object_id)
    }
}

impl ConfidentialRuntimeShadowState {
    pub(in crate::runtime) fn from_shadow(shadow: RuntimeShadowState) -> Self {
        Self {
            shadow,
            candidate_public_state_hash: None,
        }
    }

    fn candidate_public_state_hash(&self) -> Result<String> {
        self.candidate_public_state_hash
            .clone()
            .ok_or_else(|| anyhow!("confidential call has no candidate public state"))
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
        // The candidate public state is the committed one with the call's
        // staged objects in place, before the commit keeps or rolls them back.
        self.candidate_public_state_hash = Some(
            self.shadow
                .objects
                .staged_public_state_digest(&committed.objects)?,
        );
        self.shadow
            .commit_against(committed, aborted, recorder, allocator)
    }

    pub(in crate::runtime) fn into_cold_committed_state(self) -> Result<CommittedRuntimeState> {
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

    pub(in crate::runtime) fn public_state_digest(&self) -> Result<String> {
        self.shadow.public_state_digest()
    }

    pub(in crate::runtime) fn public_state_snapshot(&self) -> Result<PublicStateSnapshot> {
        self.shadow.public_state_snapshot()
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

    pub(in crate::runtime) fn into_cold_committed_state(self) -> Result<CommittedRuntimeState> {
        self.shadow.into_cold_committed_state()
    }
}

/// A call's public-state transition record, from the public state before the
/// call, the digest of its candidate state, and the committed public state.
pub(in crate::runtime) fn public_state_transition(
    initial: &PublicStateSnapshot,
    candidate_public_state_hash: String,
    committed: &PublicStateSnapshot,
    aborted: bool,
) -> Result<RuntimePublicStateTransition> {
    RuntimePublicStateTransition::from_digests(
        initial.digest.as_str(),
        candidate_public_state_hash,
        committed.digest.as_str(),
        &initial.delta(committed),
        aborted,
    )
    .map_err(anyhow::Error::from)
}

/// Allocator for hashing the committed public state.
///
/// Snapshotting only decodes public objects through scratch reservations: it
/// never records kernel ops or stack checks, and the session is dropped without
/// `finish()`, so its resource-event log is never consumed. The kernel-op and
/// stack budgets are therefore zero. They only size the eagerly materialized
/// event log (`(max_kernel_ops + max_stack_words) * 128 + 128` slots), and the
/// previous `1 << 20` kernel-op budget materialized ~135M slots (~5 GB) on every
/// digest, three digests per call.
fn public_state_snapshot_allocator() -> Result<AllocatorSession> {
    AllocatorSession::new(AllocatorPlan {
        arena_bytes: 1 << 20,
        max_stack_words: 0,
        scratch_bytes: 1 << 20,
        max_kernel_ops: 0,
        max_commit_ops: 0,
    })
}

fn hash_json<T: Serialize + ?Sized>(value: &T) -> Result<String> {
    let payload = serde_json::to_vec(value)?;
    Ok(hex::encode(Sha256::digest(payload)))
}

impl RuntimeKernelObjectStore for ConfidentialRuntimeShadowState {
    type CommittedState = CommittedRuntimeState;
    type Recorder = CallRecorder;

    fn value_canonical_len(&mut self, object_id: u32) -> Result<usize> {
        Ok(self.object_mut(object_id)?.value_canonical_len())
    }

    fn key_canonical_len(&mut self, object_id: u32) -> Result<usize> {
        self.object_mut(object_id)?.key_canonical_len()
    }

    fn cell_get(&mut self, recorder: &mut Self::Recorder, object_id: u32) -> Result<Value> {
        self.object_mut(object_id)?.get_cell(recorder)
    }

    fn cell_set(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.object_mut(object_id)?
            .set_cell(value, predicate, recorder)
    }

    fn array_get(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.object_mut(object_id)?.get_array(index, recorder)
    }

    fn array_set(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.object_mut(object_id)?
            .set_array(index, value, predicate, recorder)
    }

    fn map_get(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        key: &Value,
        allocator: &mut AllocatorSession,
    ) -> Result<(Value, bool)> {
        self.object_mut(object_id)?
            .get_map(key, recorder, allocator)
    }

    fn map_put(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
        allocator: &mut AllocatorSession,
    ) -> Result<bool> {
        self.object_mut(object_id)?
            .put_map(key, value, predicate, recorder, allocator)
    }

    fn commit_against(
        &mut self,
        committed: &Self::CommittedState,
        aborted: bool,
        recorder: &mut Self::Recorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[u32]>> {
        Self::commit_against(self, committed, aborted, recorder, allocator)
    }
}

impl RuntimeKernelConfidentialStore for ConfidentialRuntimeShadowState {
    type FreshCoins = PathOramFreshCoinPlan;

    fn shadow_load(
        committed: &Self::CommittedState,
        shadow_load_object_ids: &[u32],
        allocator: &mut AllocatorSession,
    ) -> Result<Self> {
        let shadow = committed.shadow_load(shadow_load_object_ids, allocator)?;
        Ok(Self::from_shadow(shadow))
    }

    fn install_fresh_coins(&mut self, fresh_coins: Option<Self::FreshCoins>) -> Result<()> {
        let Some(fresh_coins) = fresh_coins else {
            return Ok(());
        };
        self.install_path_oram_leaf_coins(fresh_coins.into_entries())
    }

    fn ensure_fresh_coins_consumed(&self) -> Result<()> {
        self.ensure_path_oram_leaf_coins_consumed()
    }
}

impl RuntimeKernelObjectStore for PublicRuntimeShadowState {
    type CommittedState = CommittedRuntimeState;
    type Recorder = CallRecorder;

    fn value_canonical_len(&mut self, object_id: u32) -> Result<usize> {
        Ok(self.object_mut(object_id)?.value_canonical_len())
    }

    fn key_canonical_len(&mut self, object_id: u32) -> Result<usize> {
        self.object_mut(object_id)?.key_canonical_len()
    }

    fn cell_get(&mut self, recorder: &mut Self::Recorder, object_id: u32) -> Result<Value> {
        self.object_mut(object_id)?.get_cell(recorder)
    }

    fn cell_set(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.object_mut(object_id)?
            .set_cell(value, predicate, recorder)
    }

    fn array_get(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.object_mut(object_id)?.get_array(index, recorder)
    }

    fn array_set(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.object_mut(object_id)?
            .set_array(index, value, predicate, recorder)
    }

    fn map_get(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        key: &Value,
        allocator: &mut AllocatorSession,
    ) -> Result<(Value, bool)> {
        self.object_mut(object_id)?
            .get_map(key, recorder, allocator)
    }

    fn map_put(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
        allocator: &mut AllocatorSession,
    ) -> Result<bool> {
        self.object_mut(object_id)?
            .put_map(key, value, predicate, recorder, allocator)
    }

    fn commit_against(
        &mut self,
        committed: &Self::CommittedState,
        aborted: bool,
        recorder: &mut Self::Recorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[u32]>> {
        Self::commit_against(self, committed, aborted, recorder, allocator)
    }
}
