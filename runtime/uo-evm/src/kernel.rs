use crate::controller::CallRecorder;
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::state::{
    CommittedRuntimeState, ConfidentialCallInputs, PublicRuntimeShadowState, RuntimeShadowState,
};
use anyhow::{anyhow, Result};
use tiny_keccak::{Hasher, Keccak};
use uo_allocator::{AllocatorPlan, AllocatorSession, ScratchRegion};
use uo_core::{
    BinaryOp, ConfidentialKernelSlotExpr, ConfidentialKernelSlotProgram,
    ConfidentialKernelSlotPureExpr, ConfidentialKernelSlotStatement, RuntimeKernelRefinementEventWitness,
    RuntimeKernelRefinementWitness, RuntimeKernelStepWitness, RuntimeKernelWitness, UnaryOp, Value,
};
use uo_precompiles::UoOpcode;

pub(crate) struct RuntimeKernel {
    allocator: AllocatorSession,
    expected_kernel_steps: Option<Vec<RuntimeKernelStepWitness>>,
    public_object_ids: Vec<u32>,
    expected_public_object_ids: Option<Vec<u32>>,
    expected_kernel_step_index: usize,
    kernel_steps: BoundedJournal<RuntimeKernelStepWitness>,
    runtime_phase_events: BoundedJournal<RuntimeKernelRefinementEventWitness>,
}

pub(crate) struct PublicRuntimeKernel {
    inner: RuntimeKernel,
}

#[derive(Clone, Debug)]
struct BoundedJournal<T> {
    entries: Vec<T>,
    max_len: usize,
    label: &'static str,
}

impl<T> BoundedJournal<T> {
    fn with_capacity(label: &'static str, max_len: usize) -> Self {
        Self {
            entries: Vec::with_capacity(max_len.max(1)),
            max_len,
            label,
        }
    }

    fn push(&mut self, entry: T) -> Result<()> {
        if self.entries.len() >= self.max_len {
            return Err(anyhow!(
                "{} journal exceeded bound: {} >= {}",
                self.label,
                self.entries.len(),
                self.max_len
            ));
        }
        self.entries.push(entry);
        Ok(())
    }

    fn extend<I>(&mut self, entries: I) -> Result<()>
    where
        I: IntoIterator<Item = T>,
    {
        for entry in entries {
            self.push(entry)?;
        }
        Ok(())
    }

    fn into_vec(self) -> Vec<T> {
        self.entries
    }
}

#[derive(Clone, Debug)]
struct ConfidentialExecState {
    slots: Vec<Option<Value>>,
    initialized_slots: usize,
    aborted: bool,
    returned: bool,
    return_value: Option<Value>,
}

#[derive(Clone, Debug)]
struct ConfidentialExecutionOutcome {
    pub aborted: bool,
    pub return_value: Option<Value>,
}

impl ConfidentialExecState {
    fn new(slot_count: usize) -> Self {
        Self {
            slots: vec![None; slot_count],
            initialized_slots: 0,
            aborted: false,
            returned: false,
            return_value: None,
        }
    }

    fn load_slot(&self, slot: usize) -> Result<Value> {
        self.slots
            .get(slot)
            .and_then(Option::as_ref)
            .cloned()
            .ok_or_else(|| anyhow!("unknown slot {slot}"))
    }

    fn store_slot(&mut self, slot: usize, value: Value) -> Result<()> {
        let cell = self
            .slots
            .get_mut(slot)
            .ok_or_else(|| anyhow!("unknown slot {slot}"))?;
        if cell.is_none() {
            self.initialized_slots += 1;
        }
        *cell = Some(value);
        Ok(())
    }

    fn live_slot_words(&self) -> usize {
        self.initialized_slots
    }
}

fn max_runtime_phase_event_count(
    public_object_count: usize,
    max_kernel_ops: usize,
) -> Result<usize> {
    public_object_count
        .checked_mul(5)
        .and_then(|count| count.checked_add(max_kernel_ops))
        .ok_or_else(|| {
            anyhow!(
                "runtime phase-event bound overflowed for {} public objects and {} kernel ops",
                public_object_count,
                max_kernel_ops
            )
        })
}

impl Drop for ConfidentialExecState {
    fn drop(&mut self) {
        for slot in &mut self.slots {
            if let Some(value) = slot.as_mut() {
                value.wipe_secrets();
            }
            *slot = None;
        }
        if let Some(value) = self.return_value.as_mut() {
            value.wipe_secrets();
        }
        self.return_value = None;
        self.initialized_slots = 0;
        self.aborted = false;
        self.returned = false;
    }
}

#[derive(Debug)]
pub(in crate::runtime) struct ConfidentialKernelRunOutcome {
    pub committed_shadow: RuntimeShadowState,
    pub runtime_kernel_witness: RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    pub aborted: bool,
    pub return_value: Option<Value>,
}

impl PublicRuntimeKernel {
    pub(crate) fn begin(
        plan: AllocatorPlan,
        expected_kernel_steps: Option<Vec<RuntimeKernelStepWitness>>,
        public_object_ids: Vec<u32>,
        expected_public_object_ids: Option<Vec<u32>>,
    ) -> Result<Self> {
        Ok(Self {
            inner: RuntimeKernel::begin(
                plan,
                expected_kernel_steps,
                public_object_ids,
                expected_public_object_ids,
            )?,
        })
    }

    pub(crate) fn note_hash_bytes(&mut self, bytes: usize) -> Result<()> {
        self.inner.note_hash_bytes(bytes)
    }

    pub(crate) fn enforce_stack_words(&mut self, words: usize) -> Result<()> {
        self.inner.enforce_stack_words(words)
    }

    pub(crate) fn wipe_hash_scratch(&mut self) {
        self.inner.wipe_hash_scratch();
    }

    pub(crate) fn cell_get(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
    ) -> Result<Value> {
        self.inner.cell_get_public(objects, recorder, object_id)
    }

    pub(crate) fn cell_set(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.inner
            .cell_set_public(objects, recorder, object_id, value, predicate)
    }

    pub(crate) fn array_get(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.inner
            .array_get_public(objects, recorder, object_id, index)
    }

    pub(crate) fn array_set(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.inner
            .array_set_public(objects, recorder, object_id, index, value, predicate)
    }

    pub(crate) fn map_get(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: &Value,
    ) -> Result<Value> {
        self.inner.map_get_public(objects, recorder, object_id, key)
    }

    pub(crate) fn map_put(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.inner
            .map_put_public(objects, recorder, object_id, key, value, predicate)
    }

    pub(crate) fn finish(
        self,
        entrypoint_id: &str,
    ) -> Result<(RuntimeKernelWitness, RuntimeKernelRefinementWitness)> {
        self.inner.finish(entrypoint_id)
    }

    pub(in crate::runtime) fn inner_mut(&mut self) -> &mut RuntimeKernel {
        &mut self.inner
    }

    pub(in crate::runtime) fn into_inner(self) -> RuntimeKernel {
        self.inner
    }
}

impl RuntimeKernel {
    fn begin(
        plan: AllocatorPlan,
        expected_kernel_steps: Option<Vec<RuntimeKernelStepWitness>>,
        public_object_ids: Vec<u32>,
        expected_public_object_ids: Option<Vec<u32>>,
    ) -> Result<Self> {
        let kernel_step_capacity = plan.max_kernel_ops;
        let runtime_phase_event_capacity =
            max_runtime_phase_event_count(public_object_ids.len(), plan.max_kernel_ops)?;
        let mut kernel = Self {
            allocator: AllocatorSession::new(plan),
            expected_kernel_steps,
            public_object_ids,
            expected_public_object_ids,
            expected_kernel_step_index: 0,
            kernel_steps: BoundedJournal::with_capacity(
                "runtime-kernel-step",
                kernel_step_capacity,
            ),
            runtime_phase_events: BoundedJournal::with_capacity(
                "runtime-phase-event",
                runtime_phase_event_capacity,
            ),
        };
        for object_id in kernel.public_object_ids.clone() {
            kernel
                .runtime_phase_events
                .push(RuntimeKernelRefinementEventWitness::pre_committed_cold_object(object_id))?;
        }
        kernel.record_kernel_step(UoOpcode::Begin, None)?;
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

    fn record_shadow_load_object(&mut self, object_id: u32) -> Result<()> {
        self.runtime_phase_events
            .push(RuntimeKernelRefinementEventWitness::shadow_load_object(
                object_id,
            ))
    }

    fn cell_get(
        &mut self,
        objects: &mut RuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
    ) -> Result<Value> {
        self.record_kernel_step(UoOpcode::CellGet, Some(object_id))?;
        objects.object_mut(object_id)?.get_cell(recorder)
    }

    fn cell_get_public(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
    ) -> Result<Value> {
        self.cell_get(objects.inner_mut(), recorder, object_id)
    }

    fn cell_set(
        &mut self,
        objects: &mut RuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::CellSet, Some(object_id))?;
        self.touch_value_scratch(value.canonical_len())?;
        objects
            .object_mut(object_id)?
            .set_cell(value, predicate, recorder)
    }

    fn cell_set_public(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.cell_set(objects.inner_mut(), recorder, object_id, value, predicate)
    }

    fn array_get(
        &mut self,
        objects: &mut RuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.record_kernel_step(UoOpcode::ArrayGet, Some(object_id))?;
        self.touch_value_scratch(32)?;
        objects.object_mut(object_id)?.get_array(index, recorder)
    }

    fn array_get_public(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value> {
        self.array_get(objects.inner_mut(), recorder, object_id, index)
    }

    fn array_set(
        &mut self,
        objects: &mut RuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::ArraySet, Some(object_id))?;
        self.touch_value_scratch(value.canonical_len().max(32))?;
        objects
            .object_mut(object_id)?
            .set_array(index, value, predicate, recorder)
    }

    fn array_set_public(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.array_set(
            objects.inner_mut(),
            recorder,
            object_id,
            index,
            value,
            predicate,
        )
    }

    fn map_get(
        &mut self,
        objects: &mut RuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: &Value,
    ) -> Result<Value> {
        self.record_kernel_step(UoOpcode::MapGet, Some(object_id))?;
        self.touch_value_scratch(key.canonical_len())?;
        objects
            .object_mut(object_id)?
            .get_map(key, recorder, &mut self.allocator)
    }

    fn map_get_public(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: &Value,
    ) -> Result<Value> {
        self.map_get(objects.inner_mut(), recorder, object_id, key)
    }

    fn map_put(
        &mut self,
        objects: &mut RuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::MapPut, Some(object_id))?;
        self.touch_value_scratch(key.canonical_len().max(value.canonical_len()))?;
        objects
            .object_mut(object_id)?
            .put_map(key, value, predicate, recorder, &mut self.allocator)
    }

    fn map_put_public(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        recorder: &mut CallRecorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.map_put(
            objects.inner_mut(),
            recorder,
            object_id,
            key,
            value,
            predicate,
        )
    }

    fn commit_objects(
        &mut self,
        objects: &mut RuntimeShadowState,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        self.record_kernel_step(UoOpcode::Commit, None)?;
        let committed_object_ids =
            objects.commit_against(committed, aborted, recorder, &mut self.allocator)?;
        self.runtime_phase_events.extend(
            committed_object_ids
                .into_iter()
                .map(RuntimeKernelRefinementEventWitness::commit_object),
        )?;
        Ok(())
    }

    pub(in crate::runtime) fn commit_public_objects(
        &mut self,
        objects: &mut PublicRuntimeShadowState,
        committed: &CommittedRuntimeState,
        aborted: bool,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        self.commit_objects(objects.inner_mut(), committed, aborted, recorder)
    }

    pub(in crate::runtime) fn run_confidential_call(
        mut self,
        program: &ConfidentialKernelSlotProgram,
        committed: &CommittedRuntimeState,
        shadow_load_object_ids: &[u32],
        call_inputs: ConfidentialCallInputs,
        fresh_coins: Option<&PathOramFreshCoinPlan>,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<ConfidentialKernelRunOutcome> {
        let mut shadow = self.shadow_load_objects(committed, shadow_load_object_ids)?;
        self.install_path_oram_fresh_coins(&mut shadow, fresh_coins)?;
        let outcome = self.execute_confidential_call(
            program,
            &mut shadow,
            call_inputs,
            recorder,
            opcode_trace,
        )?;
        if fresh_coins.is_some() {
            self.ensure_path_oram_fresh_coins_consumed(&shadow)?;
        }
        self.commit_objects(&mut shadow, committed, outcome.aborted, recorder)?;
        let (runtime_kernel_witness, runtime_kernel_refinement_witness) =
            self.finish(&program.entrypoint_id)?;
        Ok(ConfidentialKernelRunOutcome {
            committed_shadow: shadow,
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted: outcome.aborted,
            return_value: outcome.return_value,
        })
    }

    fn execute_confidential_call(
        &mut self,
        program: &ConfidentialKernelSlotProgram,
        objects: &mut RuntimeShadowState,
        call_inputs: ConfidentialCallInputs,
        recorder: &mut CallRecorder,
        opcode_trace: &mut Vec<String>,
    ) -> Result<ConfidentialExecutionOutcome> {
        let mut state = ConfidentialExecState::new(program.slot_count);
        for (slot, arg) in call_inputs.into_raw_args().into_iter().enumerate() {
            self.store_confidential_slot_value(&mut state, slot, arg)?;
        }
        self.exec_confidential_block(&program.body, objects, &mut state, opcode_trace, recorder)?;
        let return_value = if state.aborted {
            None
        } else {
            state.return_value.take()
        };
        Ok(ConfidentialExecutionOutcome {
            aborted: state.aborted,
            return_value,
        })
    }

    fn finish(
        mut self,
        entrypoint_id: &str,
    ) -> Result<(RuntimeKernelWitness, RuntimeKernelRefinementWitness)> {
        self.record_kernel_step(UoOpcode::Wipe, None)?;
        self.ensure_expected_kernel_schedule_consumed()?;
        self.allocator.wipe_region(ScratchRegion::ValueScratch);
        self.allocator.wipe_region(ScratchRegion::HashScratch);
        self.allocator.wipe_region(ScratchRegion::IoScratch);
        let allocator = self.allocator.finish()?;
        let expected_kernel_steps = self.expected_kernel_steps;
        let kernel_witness = RuntimeKernelWitness {
            entrypoint_id: entrypoint_id.into(),
            arena_bytes: allocator.plan().arena_bytes,
            max_stack_words: allocator.plan().max_stack_words,
            scratch_bytes: allocator.plan().scratch_bytes,
            peak_stack_words: allocator.peak_stack_words(),
            value_scratch_peak_bytes: allocator.value_scratch_usage().peak_bytes,
            value_scratch_live_bytes_end: allocator.value_scratch_usage().live_bytes,
            value_scratch_wipe_count: allocator.value_scratch_usage().wipe_count,
            hash_scratch_peak_bytes: allocator.hash_scratch_usage().peak_bytes,
            hash_scratch_live_bytes_end: allocator.hash_scratch_usage().live_bytes,
            hash_scratch_wipe_count: allocator.hash_scratch_usage().wipe_count,
            io_scratch_peak_bytes: allocator.io_scratch_usage().peak_bytes,
            io_scratch_live_bytes_end: allocator.io_scratch_usage().live_bytes,
            io_scratch_wipe_count: allocator.io_scratch_usage().wipe_count,
            resource_events: allocator.resource_events().to_vec(),
            expected_kernel_steps,
            public_object_ids: self.public_object_ids,
            expected_public_object_ids: self.expected_public_object_ids,
            kernel_steps: self.kernel_steps.into_vec(),
        };
        Ok((
            kernel_witness,
            RuntimeKernelRefinementWitness {
                events: self.runtime_phase_events.into_vec(),
            },
        ))
    }

    fn touch_value_scratch(&mut self, bytes: usize) -> Result<()> {
        let _guard = self
            .allocator
            .reserve_guard(ScratchRegion::ValueScratch, bytes)?;
        Ok(())
    }

    fn store_confidential_slot_value(
        &mut self,
        state: &mut ConfidentialExecState,
        slot: usize,
        value: Value,
    ) -> Result<()> {
        state.store_slot(slot, value)?;
        self.enforce_stack_words(state.live_slot_words())
    }

    fn exec_confidential_block(
        &mut self,
        statements: &[ConfidentialKernelSlotStatement],
        objects: &mut RuntimeShadowState,
        state: &mut ConfidentialExecState,
        opcode_trace: &mut Vec<String>,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        for statement in statements {
            if state.returned {
                break;
            }
            self.exec_confidential_statement(statement, objects, state, opcode_trace, recorder)?;
        }
        Ok(())
    }

    fn exec_confidential_statement(
        &mut self,
        statement: &ConfidentialKernelSlotStatement,
        objects: &mut RuntimeShadowState,
        state: &mut ConfidentialExecState,
        opcode_trace: &mut Vec<String>,
        recorder: &mut CallRecorder,
    ) -> Result<()> {
        opcode_trace.push(statement.trace_name().into());
        match statement {
            ConfidentialKernelSlotStatement::Declare { slot, value }
            | ConfidentialKernelSlotStatement::Assign { slot, value } => {
                let value = self.eval_confidential_expr(value, objects, state, recorder)?;
                self.store_confidential_slot_value(state, *slot, value)?;
            }
            ConfidentialKernelSlotStatement::Require { cond } => {
                let cond = self
                    .eval_confidential_expr(cond, objects, state, recorder)?
                    .as_bool()
                    .ok_or_else(|| anyhow!("require condition must be boolean"))?;
                if !cond {
                    state.aborted = true;
                    state.returned = true;
                }
            }
            ConfidentialKernelSlotStatement::AbortIf { cond } => {
                let cond = self
                    .eval_confidential_expr(cond, objects, state, recorder)?
                    .as_bool()
                    .ok_or_else(|| anyhow!("abort condition must be boolean"))?;
                if cond {
                    state.aborted = true;
                }
            }
            ConfidentialKernelSlotStatement::CellSet {
                object_id,
                value,
                predicate,
            } => {
                let value = self.eval_confidential_expr(value, objects, state, recorder)?;
                let predicate = predicate
                    .as_ref()
                    .map(|expr| self.eval_confidential_expr(expr, objects, state, recorder))
                    .transpose()?
                    .map(|value| {
                        value
                            .as_bool()
                            .ok_or_else(|| anyhow!("cell predicate must be boolean"))
                    })
                    .transpose()?;
                self.cell_set(objects, recorder, *object_id, value, predicate)?;
            }
            ConfidentialKernelSlotStatement::ArraySet {
                object_id,
                index,
                value,
                predicate,
            } => {
                let index = self
                    .eval_confidential_expr(index, objects, state, recorder)?
                    .as_uint()
                    .ok_or_else(|| anyhow!("array index must be uint"))?
                    as usize;
                let value = self.eval_confidential_expr(value, objects, state, recorder)?;
                let predicate = predicate
                    .as_ref()
                    .map(|expr| self.eval_confidential_expr(expr, objects, state, recorder))
                    .transpose()?
                    .map(|value| {
                        value
                            .as_bool()
                            .ok_or_else(|| anyhow!("array predicate must be boolean"))
                    })
                    .transpose()?;
                self.array_set(objects, recorder, *object_id, index, value, predicate)?;
            }
            ConfidentialKernelSlotStatement::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                let key = self.eval_confidential_expr(key, objects, state, recorder)?;
                let value = self.eval_confidential_expr(value, objects, state, recorder)?;
                let predicate = predicate
                    .as_ref()
                    .map(|expr| self.eval_confidential_expr(expr, objects, state, recorder))
                    .transpose()?
                    .map(|value| {
                        value
                            .as_bool()
                            .ok_or_else(|| anyhow!("map predicate must be boolean"))
                    })
                    .transpose()?;
                self.map_put(objects, recorder, *object_id, key, value, predicate)?;
            }
            ConfidentialKernelSlotStatement::Return { value } => {
                state.return_value = value
                    .as_ref()
                    .map(|expr| self.eval_confidential_expr(expr, objects, state, recorder))
                    .transpose()?;
                state.returned = true;
            }
        }
        Ok(())
    }

    fn eval_confidential_expr(
        &mut self,
        expr: &ConfidentialKernelSlotExpr,
        objects: &mut RuntimeShadowState,
        state: &mut ConfidentialExecState,
        recorder: &mut CallRecorder,
    ) -> Result<Value> {
        match expr {
            ConfidentialKernelSlotExpr::Literal { value } => Ok(value.clone()),
            ConfidentialKernelSlotExpr::Slot { slot } => state.load_slot(*slot),
            ConfidentialKernelSlotExpr::Unary { op, expr } => {
                let value = self.eval_confidential_expr(expr, objects, state, recorder)?;
                match op {
                    UnaryOp::Not => Ok(Value::Bool(
                        !value
                            .as_bool()
                            .ok_or_else(|| anyhow!("logical not expects bool"))?,
                    )),
                    UnaryOp::Neg => Ok(Value::Uint(
                        0u128.wrapping_sub(
                            value
                                .as_uint()
                                .ok_or_else(|| anyhow!("negation expects uint"))?,
                        ),
                    )),
                }
            }
            ConfidentialKernelSlotExpr::Binary { op, lhs, rhs } => {
                let lhs = self.eval_confidential_expr(lhs, objects, state, recorder)?;
                let rhs = self.eval_confidential_expr(rhs, objects, state, recorder)?;
                eval_binary(op, lhs, rhs)
            }
            ConfidentialKernelSlotExpr::Select {
                cond,
                when_true,
                when_false,
            } => {
                let cond = self
                    .eval_confidential_expr(cond, objects, state, recorder)?
                    .as_bool()
                    .ok_or_else(|| anyhow!("select condition must be boolean"))?;
                let when_true = self.eval_confidential_pure_expr(when_true, state)?;
                let when_false = self.eval_confidential_pure_expr(when_false, state)?;
                Value::confidential_select(cond, when_true, when_false)
            }
            ConfidentialKernelSlotExpr::CellGet { object_id } => {
                self.cell_get(objects, recorder, *object_id)
            }
            ConfidentialKernelSlotExpr::ArrayGet { object_id, index } => {
                let index = self
                    .eval_confidential_expr(index, objects, state, recorder)?
                    .as_uint()
                    .ok_or_else(|| anyhow!("array index must be uint"))?
                    as usize;
                self.array_get(objects, recorder, *object_id, index)
            }
            ConfidentialKernelSlotExpr::MapGet { object_id, key } => {
                let key = self.eval_confidential_expr(key, objects, state, recorder)?;
                self.map_get(objects, recorder, *object_id, &key)
            }
            ConfidentialKernelSlotExpr::Keccak256 { parts } => {
                let mut hasher = Keccak::v256();
                for part in parts {
                    let value = self.eval_confidential_expr(part, objects, state, recorder)?;
                    self.note_hash_bytes(value.canonical_len())?;
                    value.visit_canonical_chunks(&mut |chunk| hasher.update(chunk));
                    self.wipe_hash_scratch();
                }
                let mut out = [0u8; 32];
                hasher.finalize(&mut out);
                Ok(Value::Bytes32(out))
            }
        }
    }

    fn eval_confidential_pure_expr(
        &mut self,
        expr: &ConfidentialKernelSlotPureExpr,
        state: &mut ConfidentialExecState,
    ) -> Result<Value> {
        match expr {
            ConfidentialKernelSlotPureExpr::Literal { value } => Ok(value.clone()),
            ConfidentialKernelSlotPureExpr::Slot { slot } => state.load_slot(*slot),
            ConfidentialKernelSlotPureExpr::Unary { op, expr } => {
                let value = self.eval_confidential_pure_expr(expr, state)?;
                match op {
                    UnaryOp::Not => Ok(Value::Bool(
                        !value
                            .as_bool()
                            .ok_or_else(|| anyhow!("logical not expects bool"))?,
                    )),
                    UnaryOp::Neg => Ok(Value::Uint(
                        0u128.wrapping_sub(
                            value
                                .as_uint()
                                .ok_or_else(|| anyhow!("negation expects uint"))?,
                        ),
                    )),
                }
            }
            ConfidentialKernelSlotPureExpr::Binary { op, lhs, rhs } => {
                let lhs = self.eval_confidential_pure_expr(lhs, state)?;
                let rhs = self.eval_confidential_pure_expr(rhs, state)?;
                eval_binary(op, lhs, rhs)
            }
            ConfidentialKernelSlotPureExpr::Select {
                cond,
                when_true,
                when_false,
            } => {
                let cond = self
                    .eval_confidential_pure_expr(cond, state)?
                    .as_bool()
                    .ok_or_else(|| anyhow!("select condition must be boolean"))?;
                let when_true = self.eval_confidential_pure_expr(when_true, state)?;
                let when_false = self.eval_confidential_pure_expr(when_false, state)?;
                Value::confidential_select(cond, when_true, when_false)
            }
            ConfidentialKernelSlotPureExpr::Keccak256 { parts } => {
                let mut hasher = Keccak::v256();
                for part in parts {
                    let value = self.eval_confidential_pure_expr(part, state)?;
                    self.note_hash_bytes(value.canonical_len())?;
                    value.visit_canonical_chunks(&mut |chunk| hasher.update(chunk));
                    self.wipe_hash_scratch();
                }
                let mut out = [0u8; 32];
                hasher.finalize(&mut out);
                Ok(Value::Bytes32(out))
            }
        }
    }

    fn record_kernel_step(&mut self, opcode: UoOpcode, object_id: Option<u32>) -> Result<()> {
        self.enforce_expected_kernel_step(opcode, object_id)?;
        self.allocator.record_kernel_op(opcode)?;
        self.kernel_steps
            .push(RuntimeKernelStepWitness { opcode, object_id })?;
        self.runtime_phase_events
            .push(RuntimeKernelRefinementEventWitness::kernel_step(
                opcode, object_id,
            ))?;
        Ok(())
    }

    fn enforce_expected_kernel_step(
        &mut self,
        opcode: UoOpcode,
        object_id: Option<u32>,
    ) -> Result<()> {
        let Some(expected_kernel_steps) = &self.expected_kernel_steps else {
            return Ok(());
        };
        let observed = RuntimeKernelStepWitness { opcode, object_id };
        let Some(expected) = expected_kernel_steps.get(self.expected_kernel_step_index) else {
            return Err(anyhow!(
                "runtime kernel emitted unexpected extra step {:?} after exhausting admitted schedule",
                observed
            ));
        };
        if expected != &observed {
            return Err(anyhow!(
                "runtime kernel step schedule mismatch at index {}: expected {:?}, got {:?}",
                self.expected_kernel_step_index,
                expected,
                observed
            ));
        }
        self.expected_kernel_step_index += 1;
        Ok(())
    }

    fn ensure_expected_kernel_schedule_consumed(&self) -> Result<()> {
        let Some(expected_kernel_steps) = &self.expected_kernel_steps else {
            return Ok(());
        };
        if self.expected_kernel_step_index != expected_kernel_steps.len() {
            return Err(anyhow!(
                "runtime kernel stopped after {} admitted steps but {} were required",
                self.expected_kernel_step_index,
                expected_kernel_steps.len()
            ));
        }
        Ok(())
    }

    pub(in crate::runtime) fn shadow_load_objects(
        &mut self,
        committed: &CommittedRuntimeState,
        shadow_load_object_ids: &[u32],
    ) -> Result<RuntimeShadowState> {
        let shadow = committed.shadow_load(shadow_load_object_ids, &mut self.allocator)?;
        for object_id in shadow_load_object_ids {
            self.record_shadow_load_object(*object_id)?;
        }
        Ok(shadow)
    }

    fn install_path_oram_fresh_coins(
        &mut self,
        objects: &mut RuntimeShadowState,
        fresh_coins: Option<&PathOramFreshCoinPlan>,
    ) -> Result<()> {
        let Some(fresh_coins) = fresh_coins else {
            return Ok(());
        };
        objects.install_path_oram_leaf_coins(fresh_coins.by_object())
    }

    fn ensure_path_oram_fresh_coins_consumed(&self, objects: &RuntimeShadowState) -> Result<()> {
        objects.ensure_path_oram_leaf_coins_consumed()
    }
}

fn eval_binary(op: &BinaryOp, lhs: Value, rhs: Value) -> Result<Value> {
    match op {
        BinaryOp::Add => Ok(Value::Uint(lhs_uint(&lhs)?.wrapping_add(lhs_uint(&rhs)?))),
        BinaryOp::Sub => Ok(Value::Uint(lhs_uint(&lhs)?.wrapping_sub(lhs_uint(&rhs)?))),
        BinaryOp::Mul => Ok(Value::Uint(lhs_uint(&lhs)?.wrapping_mul(lhs_uint(&rhs)?))),
        BinaryOp::Div => {
            let divisor = lhs_uint(&rhs)?;
            Ok(Value::Uint(if divisor == 0 {
                0
            } else {
                lhs_uint(&lhs)? / divisor
            }))
        }
        BinaryOp::Mod => {
            let divisor = lhs_uint(&rhs)?;
            Ok(Value::Uint(if divisor == 0 {
                0
            } else {
                lhs_uint(&lhs)? % divisor
            }))
        }
        BinaryOp::BitAnd => Ok(Value::Uint(lhs_uint(&lhs)? & lhs_uint(&rhs)?)),
        BinaryOp::BitOr => Ok(Value::Uint(lhs_uint(&lhs)? | lhs_uint(&rhs)?)),
        BinaryOp::BitXor => Ok(Value::Uint(lhs_uint(&lhs)? ^ lhs_uint(&rhs)?)),
        BinaryOp::Eq => Ok(Value::Bool(lhs == rhs)),
        BinaryOp::Neq => Ok(Value::Bool(lhs != rhs)),
        BinaryOp::Lt => Ok(Value::Bool(lhs_uint(&lhs)? < lhs_uint(&rhs)?)),
        BinaryOp::Lte => Ok(Value::Bool(lhs_uint(&lhs)? <= lhs_uint(&rhs)?)),
        BinaryOp::Gt => Ok(Value::Bool(lhs_uint(&lhs)? > lhs_uint(&rhs)?)),
        BinaryOp::Gte => Ok(Value::Bool(lhs_uint(&lhs)? >= lhs_uint(&rhs)?)),
        BinaryOp::And => Ok(Value::Bool(lhs_bool(&lhs)? && lhs_bool(&rhs)?)),
        BinaryOp::Or => Ok(Value::Bool(lhs_bool(&lhs)? || lhs_bool(&rhs)?)),
    }
}

fn lhs_uint(value: &Value) -> Result<u128> {
    value
        .as_uint()
        .ok_or_else(|| anyhow!("expected uint-compatible value"))
}

fn lhs_bool(value: &Value) -> Result<bool> {
    value
        .as_bool()
        .ok_or_else(|| anyhow!("expected bool-compatible value"))
}

#[cfg(test)]
mod tests {
    use super::{max_runtime_phase_event_count, BoundedJournal, RuntimeKernel};
    use uo_allocator::AllocatorPlan;
    use uo_core::RuntimeKernelStepWitness;
    use uo_precompiles::UoOpcode;

    #[test]
    fn bounded_journal_rejects_push_past_bound() {
        let mut journal = BoundedJournal::with_capacity("demo", 1);
        journal.push(1usize).unwrap();
        let err = journal.push(2usize).unwrap_err();
        assert!(err.to_string().contains("demo journal exceeded bound"));
    }

    #[test]
    fn runtime_phase_event_bound_matches_public_objects_and_kernel_ops() {
        assert_eq!(max_runtime_phase_event_count(0, 3).unwrap(), 3);
        assert_eq!(max_runtime_phase_event_count(2, 4).unwrap(), 14);
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
            None,
            vec![],
            Some(vec![]),
        )
        .unwrap();
        assert!(kernel.finish("demo()").is_err());
    }

    #[test]
    fn kernel_rejects_runtime_step_schedule_mismatch_online() {
        let mut kernel = RuntimeKernel::begin(
            AllocatorPlan {
                arena_bytes: 4096,
                max_stack_words: 64,
                scratch_bytes: 1024,
                max_kernel_ops: 4,
            },
            Some(vec![
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
            vec![7],
            Some(vec![7]),
        )
        .unwrap();

        let err = kernel
            .record_kernel_step(UoOpcode::CellGet, Some(8))
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("runtime kernel step schedule mismatch"));
    }

    #[test]
    fn kernel_exports_matching_expected_schedule_when_enforced_online() {
        let mut kernel = RuntimeKernel::begin(
            AllocatorPlan {
                arena_bytes: 4096,
                max_stack_words: 64,
                scratch_bytes: 1024,
                max_kernel_ops: 3,
            },
            Some(vec![
                RuntimeKernelStepWitness {
                    opcode: UoOpcode::Begin,
                    object_id: None,
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
            vec![],
            Some(vec![]),
        )
        .unwrap();

        kernel.record_kernel_step(UoOpcode::Commit, None).unwrap();
        let (witness, refinement_witness) = kernel.finish("demo()").unwrap();
        assert_eq!(
            witness.expected_kernel_steps,
            Some(witness.kernel_steps.clone())
        );
        assert_eq!(
            refinement_witness.projected_kernel_schedule(),
            witness.emitted_kernel_schedule()
        );
    }
}
