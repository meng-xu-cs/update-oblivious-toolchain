use crate::controller::CallRecorder;
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::objects::RuntimeObject;
use crate::runtime::state::{
    CommittedRuntimeState, ConfidentialRuntimeShadowState, PublicRuntimeShadowState,
    RuntimeShadowState,
};
use anyhow::{anyhow, Result};
use tiny_keccak::{Hasher, Keccak};
use uo_allocator::{AllocatorPlan, AllocatorSession, ScratchRegion};
use uo_core::{
    execute_confidential_kernel_slot_call, ConfidentialCallInputs, ConfidentialKernelEffectRuntime,
    ConfidentialKernelSlotProgram, ConfidentialKernelSlotStatement, RuntimeKernelBoundaryTracker,
    RuntimeKernelFinishBundle, Value,
};
use uo_precompiles::UoOpcode;

#[cfg(test)]
use uo_core::RuntimeKernelStepWitness;

struct RuntimeKernel {
    allocator: AllocatorSession,
    max_hash_part_bytes: usize,
    boundary: RuntimeKernelBoundaryTracker,
}

pub(in crate::runtime) struct PublicRuntimeKernel {
    inner: RuntimeKernel,
}

struct RuntimeKernelSlotEffects<'a> {
    kernel: &'a mut RuntimeKernel,
    objects: &'a mut ConfidentialRuntimeShadowState,
    recorder: &'a mut CallRecorder,
    opcode_trace: &'a mut Vec<String>,
}

trait RuntimeShadowObjectStore {
    fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject>;

    fn commit_against(
        &mut self,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[u32]>>;
}

impl RuntimeShadowObjectStore for ConfidentialRuntimeShadowState {
    fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject> {
        ConfidentialRuntimeShadowState::object_mut(self, object_id)
    }

    fn commit_against(
        &mut self,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[u32]>> {
        ConfidentialRuntimeShadowState::commit_against(
            self, committed, aborted, recorder, allocator,
        )
    }
}

impl RuntimeShadowObjectStore for PublicRuntimeShadowState {
    fn object_mut(&mut self, object_id: u32) -> Result<&mut RuntimeObject> {
        PublicRuntimeShadowState::object_mut(self, object_id)
    }

    fn commit_against(
        &mut self,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[u32]>> {
        PublicRuntimeShadowState::commit_against(self, committed, aborted, recorder, allocator)
    }
}

impl ConfidentialKernelEffectRuntime for RuntimeKernelSlotEffects<'_> {
    fn note_statement(&mut self, statement: &ConfidentialKernelSlotStatement) -> Result<()> {
        self.opcode_trace.push(statement.trace_name().into());
        Ok(())
    }

    fn note_live_slot_words(&mut self, words: usize) -> Result<()> {
        self.kernel.enforce_stack_words(words)
    }

    fn cell_get(&mut self, object_id: u32) -> Result<Value> {
        self.kernel.cell_get(self.objects, self.recorder, object_id)
    }

    fn cell_set(&mut self, object_id: u32, value: Value, predicate: Option<bool>) -> Result<()> {
        self.kernel
            .cell_set(self.objects, self.recorder, object_id, value, predicate)
    }

    fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value> {
        self.kernel
            .array_get(self.objects, self.recorder, object_id, index)
    }

    fn array_set(
        &mut self,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.kernel.array_set(
            self.objects,
            self.recorder,
            object_id,
            index,
            value,
            predicate,
        )
    }

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<Value> {
        self.kernel
            .map_get(self.objects, self.recorder, object_id, key)
    }

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.kernel.map_put(
            self.objects,
            self.recorder,
            object_id,
            key,
            value,
            predicate,
        )
    }

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value> {
        self.kernel.keccak256_values(parts)
    }
}

impl PublicRuntimeKernel {
    pub(in crate::runtime) fn begin(
        plan: AllocatorPlan,
        public_object_ids: &[u32],
    ) -> Result<Self> {
        Ok(Self {
            inner: RuntimeKernel::begin(plan, public_object_ids)?,
        })
    }

    pub(in crate::runtime) fn note_hash_bytes(&mut self, bytes: usize) -> Result<()> {
        self.inner.note_hash_bytes(bytes)
    }

    pub(in crate::runtime) fn enforce_stack_words(&mut self, words: usize) -> Result<()> {
        self.inner.enforce_stack_words(words)
    }

    pub(in crate::runtime) fn wipe_hash_scratch(&mut self) {
        self.inner.wipe_hash_scratch();
    }

    pub(in crate::runtime) fn cell_get(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
    ) -> Result<Value> {
        self.inner.cell_get(objects, recorder, object_id)
    }

    pub(in crate::runtime) fn cell_set(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.inner
            .cell_set(objects, recorder, object_id, value, predicate)
    }

    pub(in crate::runtime) fn array_get(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.inner.array_get(objects, recorder, object_id, index)
    }

    pub(in crate::runtime) fn array_set(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.inner
            .array_set(objects, recorder, object_id, index, value, predicate)
    }

    pub(in crate::runtime) fn map_get(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: &Value,
    ) -> Result<Value> {
        self.inner.map_get(objects, recorder, object_id, key)
    }

    pub(in crate::runtime) fn map_put(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.inner
            .map_put(objects, recorder, object_id, key, value, predicate)
    }

    pub(in crate::runtime) fn finish(
        self,
        entrypoint_id: &str,
    ) -> Result<RuntimeKernelFinishBundle> {
        self.inner.finish(entrypoint_id)
    }

    pub(in crate::runtime) fn shadow_load_public_objects(
        &mut self,
        committed: &CommittedRuntimeState,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        self.inner
            .shadow_load_public_objects(committed, public_object_ids)
    }

    pub(in crate::runtime) fn commit_public_objects(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        self.inner
            .commit_objects(objects, committed, aborted, recorder)
    }

    pub(in crate::runtime) fn run_confidential_call(
        self,
        program: &ConfidentialKernelSlotProgram,
        committed: &CommittedRuntimeState,
        max_hash_part_bytes: usize,
        raw_args: ConfidentialCallInputs,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<(
        ConfidentialRuntimeShadowState,
        RuntimeKernelFinishBundle,
        bool,
        Option<Value>,
    )> {
        self.inner.run_confidential_call(
            program,
            committed,
            max_hash_part_bytes,
            raw_args,
            fresh_coins,
            recorder,
            opcode_trace,
        )
    }

    #[cfg(test)]
    pub(in crate::runtime) fn shadow_load_confidential_objects_for_test(
        &mut self,
        committed: &CommittedRuntimeState,
        shadow_load_object_ids: &[u32],
    ) -> Result<ConfidentialRuntimeShadowState> {
        self.inner
            .shadow_load_confidential_objects_for_test(committed, shadow_load_object_ids)
    }
}

impl RuntimeKernel {
    fn begin(plan: AllocatorPlan, public_object_ids: &[u32]) -> Result<Self> {
        let kernel_step_capacity = plan.max_kernel_ops;
        Ok(Self {
            allocator: AllocatorSession::new(plan),
            max_hash_part_bytes: 0,
            boundary: RuntimeKernelBoundaryTracker::begin(public_object_ids, kernel_step_capacity)?,
        })
    }

    #[cfg(test)]
    fn begin_with_expected_kernel_steps(
        plan: AllocatorPlan,
        expected_kernel_steps: Vec<RuntimeKernelStepWitness>,
        public_object_ids: &[u32],
    ) -> Result<Self> {
        let mut kernel = Self::begin(plan, public_object_ids)?;
        kernel
            .boundary
            .bind_expected_kernel_steps(expected_kernel_steps.into_boxed_slice())
            .map_err(|err| anyhow!("test runtime schedule: {err}"))?;
        Ok(kernel)
    }

    fn enforce_stack_words(&mut self, words: usize) -> Result<()> {
        self.allocator.enforce_stack_words(words)
    }

    fn note_hash_bytes(&mut self, bytes: usize) -> Result<()> {
        self.allocator
            .reserve_scratch(ScratchRegion::HashScratch, bytes)
    }

    fn wipe_hash_scratch(&mut self) {
        self.allocator.wipe_region(ScratchRegion::HashScratch);
    }

    fn cell_get<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        recorder: &mut CallRecorder,
        object_id: u32,
    ) -> Result<Value> {
        self.record_kernel_step(UoOpcode::CellGet, Some(object_id))?;
        objects.object_mut(object_id)?.get_cell(recorder)
    }

    fn cell_set<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        recorder: &mut CallRecorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::CellSet, Some(object_id))?;
        let value_len = objects.object_mut(object_id)?.value_canonical_len();
        self.touch_value_scratch(value_len)?;
        objects
            .object_mut(object_id)?
            .set_cell(value, predicate, recorder)
    }

    fn array_get<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.record_kernel_step(UoOpcode::ArrayGet, Some(object_id))?;
        self.touch_value_scratch(32)?;
        objects.object_mut(object_id)?.get_array(index, recorder)
    }

    fn array_set<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::ArraySet, Some(object_id))?;
        let value_len = objects.object_mut(object_id)?.value_canonical_len();
        self.touch_value_scratch(value_len.max(32))?;
        objects
            .object_mut(object_id)?
            .set_array(index, value, predicate, recorder)
    }

    fn map_get<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: &Value,
    ) -> Result<Value> {
        self.record_kernel_step(UoOpcode::MapGet, Some(object_id))?;
        let key_len = objects.object_mut(object_id)?.key_canonical_len()?;
        self.touch_value_scratch(key_len)?;
        objects
            .object_mut(object_id)?
            .get_map(key, recorder, &mut self.allocator)
    }

    fn map_put<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::MapPut, Some(object_id))?;
        let (key_len, value_len) = {
            let object = objects.object_mut(object_id)?;
            (object.key_canonical_len()?, object.value_canonical_len())
        };
        self.touch_value_scratch(key_len.max(value_len))?;
        objects
            .object_mut(object_id)?
            .put_map(key, value, predicate, recorder, &mut self.allocator)
    }

    fn commit_objects<S: RuntimeShadowObjectStore>(
        &mut self,
        objects: &mut S,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::Commit, None)?;
        let committed_object_ids =
            objects.commit_against(committed, aborted, recorder, &mut self.allocator)?;
        self.boundary
            .append_commit_object_schedule(committed_object_ids)?;
        Ok(())
    }

    fn run_confidential_call(
        mut self,
        program: &ConfidentialKernelSlotProgram,
        committed: &CommittedRuntimeState,
        max_hash_part_bytes: usize,
        call_inputs: ConfidentialCallInputs,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<(
        ConfidentialRuntimeShadowState,
        RuntimeKernelFinishBundle,
        bool,
        Option<Value>,
    )> {
        self.max_hash_part_bytes = max_hash_part_bytes;
        self.boundary
            .bind_expected_kernel_program(program)
            .map_err(|err| {
                anyhow!(
                    "confidential kernel program {}: {err}",
                    program.entrypoint_id
                )
            })?;
        let shadow_load_object_ids = self.boundary.expected_loaded_object_schedule_required()?;
        let mut shadow =
            self.shadow_load_confidential_objects(committed, shadow_load_object_ids.as_ref())?;
        let had_injected_fresh_coins = fresh_coins.is_some();
        self.install_path_oram_fresh_coins(&mut shadow, fresh_coins)?;
        let (aborted, return_value) = {
            let mut runtime_effects = RuntimeKernelSlotEffects {
                kernel: &mut self,
                objects: &mut shadow,
                recorder,
                opcode_trace,
            };
            let outcome =
                execute_confidential_kernel_slot_call(&mut runtime_effects, program, call_inputs)?;
            let (aborted, return_value) = outcome.into_parts();
            (aborted, if aborted { None } else { return_value })
        };
        if had_injected_fresh_coins {
            self.ensure_path_oram_fresh_coins_consumed(&shadow)?;
        }
        self.commit_objects(&mut shadow, committed, aborted, recorder)?;
        let runtime_kernel_finish_bundle = self.finish(&program.entrypoint_id)?;
        Ok((shadow, runtime_kernel_finish_bundle, aborted, return_value))
    }

    fn finish(mut self, entrypoint_id: &str) -> Result<RuntimeKernelFinishBundle> {
        self.record_kernel_step(UoOpcode::Wipe, None)?;
        self.allocator.wipe_region(ScratchRegion::ValueScratch);
        self.allocator.wipe_region(ScratchRegion::HashScratch);
        self.allocator.wipe_region(ScratchRegion::IoScratch);
        let finish_snapshot = self
            .boundary
            .into_finish_snapshot(entrypoint_id.into(), self.allocator.finish()?);
        finish_snapshot
            .into_finish_bundle()
            .map_err(anyhow::Error::from)
    }

    fn touch_value_scratch(&mut self, bytes: usize) -> Result<()> {
        let _guard = self
            .allocator
            .reserve_guard(ScratchRegion::ValueScratch, bytes)?;
        Ok(())
    }

    fn keccak256_values(&mut self, parts: Box<[Value]>) -> Result<Value> {
        let mut hasher = Keccak::v256();
        let mut parts = parts;
        for part in parts.iter_mut() {
            self.note_hash_bytes(self.max_hash_part_bytes)?;
            part.visit_canonical_chunks(&mut |chunk| hasher.update(chunk));
            part.wipe_secrets();
            self.wipe_hash_scratch();
        }
        let mut out = [0u8; 32];
        hasher.finalize(&mut out);
        Ok(Value::Bytes32(out))
    }

    fn record_kernel_step(&mut self, opcode: UoOpcode, object_id: Option<u32>) -> Result<()> {
        self.boundary.record_opcode(opcode, object_id)?;
        self.allocator.record_kernel_op()?;
        Ok(())
    }

    fn shadow_load_raw_objects(
        &mut self,
        committed: &CommittedRuntimeState,
        shadow_load_object_ids: &[u32],
    ) -> Result<RuntimeShadowState> {
        let shadow = committed.shadow_load(shadow_load_object_ids, &mut self.allocator)?;
        for object_id in shadow_load_object_ids {
            self.boundary.record_shadow_load_object(*object_id)?;
        }
        Ok(shadow)
    }

    fn shadow_load_public_objects(
        &mut self,
        committed: &CommittedRuntimeState,
        public_object_ids: &[u32],
    ) -> Result<PublicRuntimeShadowState> {
        let shadow = self.shadow_load_raw_objects(committed, public_object_ids)?;
        Ok(PublicRuntimeShadowState::from_shadow(shadow))
    }

    fn shadow_load_confidential_objects(
        &mut self,
        committed: &CommittedRuntimeState,
        shadow_load_object_ids: &[u32],
    ) -> Result<ConfidentialRuntimeShadowState> {
        let shadow = self.shadow_load_raw_objects(committed, shadow_load_object_ids)?;
        Ok(ConfidentialRuntimeShadowState::from_shadow(shadow))
    }

    #[cfg(test)]
    fn shadow_load_confidential_objects_for_test(
        &mut self,
        committed: &CommittedRuntimeState,
        shadow_load_object_ids: &[u32],
    ) -> Result<ConfidentialRuntimeShadowState> {
        self.shadow_load_confidential_objects(committed, shadow_load_object_ids)
    }

    fn install_path_oram_fresh_coins(
        &mut self,
        objects: &mut ConfidentialRuntimeShadowState,
        fresh_coins: Option<PathOramFreshCoinPlan>,
    ) -> Result<()> {
        let Some(fresh_coins) = fresh_coins else {
            return Ok(());
        };
        objects.install_path_oram_leaf_coins(fresh_coins.into_entries())
    }

    fn ensure_path_oram_fresh_coins_consumed(
        &self,
        objects: &ConfidentialRuntimeShadowState,
    ) -> Result<()> {
        objects.ensure_path_oram_leaf_coins_consumed()
    }
}

#[cfg(test)]
mod tests {
    use super::RuntimeKernel;
    use uo_allocator::AllocatorPlan;
    use uo_core::{max_runtime_kernel_refinement_event_count, RuntimeKernelStepWitness};
    use uo_precompiles::UoOpcode;

    #[test]
    fn runtime_phase_event_bound_matches_public_objects_and_kernel_ops() {
        assert_eq!(max_runtime_kernel_refinement_event_count(0, 3).unwrap(), 3);
        assert_eq!(max_runtime_kernel_refinement_event_count(2, 4).unwrap(), 14);
    }

    #[test]
    fn kernel_rejects_kernel_op_budget_overflow() {
        let kernel = RuntimeKernel::begin(
            AllocatorPlan {
                arena_bytes: 4096,
                max_stack_words: 64,
                scratch_bytes: 1024,
                max_kernel_ops: 1,
            },
            &[],
        )
        .unwrap();
        assert!(kernel.finish("demo()").is_err());
    }

    #[test]
    fn kernel_rejects_runtime_step_schedule_mismatch_online() {
        let mut kernel = RuntimeKernel::begin_with_expected_kernel_steps(
            AllocatorPlan {
                arena_bytes: 4096,
                max_stack_words: 64,
                scratch_bytes: 1024,
                max_kernel_ops: 4,
            },
            vec![
                RuntimeKernelStepWitness::new(UoOpcode::Begin, None).unwrap(),
                RuntimeKernelStepWitness::new(UoOpcode::CellGet, Some(7)).unwrap(),
                RuntimeKernelStepWitness::new(UoOpcode::Commit, None).unwrap(),
                RuntimeKernelStepWitness::new(UoOpcode::Wipe, None).unwrap(),
            ],
            &[7],
        )
        .unwrap();

        let err = kernel
            .record_kernel_step(UoOpcode::CellGet, Some(8))
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("runtime kernel step schedule mismatch"));
    }
}
