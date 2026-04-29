use anyhow::Result;
use uo_allocator::{AllocatorPlan, AllocatorSession, ScratchRegion};
#[cfg(test)]
use uo_core::RuntimeKernelStepWitness;
use uo_core::{
    execute_confidential_kernel_slot_program, fixed_buffer, ConfidentialKernelEffectRuntime,
    ConfidentialKernelSlotProgram, ConfidentialKernelSlotRuntime, RuntimeKernelBoundaryTracker,
    RuntimeKernelFinishBundle, RuntimeKernelMachineFinishWitness, Value,
};
use uo_precompiles::UoOpcode;

#[path = "generated_machine.rs"]
mod generated_machine;
#[path = "generated_slot_support.rs"]
mod generated_slot_support;

use generated_slot_support::{
    store_confidential_call_inputs, ConfidentialCallInputs, ConfidentialKernelSlotState,
};

pub struct RuntimeKernelStatementTrace {
    statements: fixed_buffer::FixedPrefixBuffer<String>,
}

impl RuntimeKernelStatementTrace {
    pub fn new(capacity: usize) -> Self {
        Self {
            statements: fixed_buffer::FixedPrefixBuffer::with_capacity(capacity),
        }
    }

    fn record(&mut self, statement: &uo_core::ConfidentialKernelSlotStatement) -> Result<()> {
        if self.statements.push(statement.trace_name().into()).is_err() {
            anyhow::bail!("runtime kernel statement-trace capacity exceeded");
        }
        Ok(())
    }

    pub fn into_boxed_trace(self) -> Box<[String]> {
        self.statements.into_boxed_slice()
    }
}

pub trait RuntimeKernelObjectStore {
    type CommittedState;
    type Recorder;

    fn value_canonical_len(&mut self, object_id: u32) -> Result<usize>;

    fn key_canonical_len(&mut self, object_id: u32) -> Result<usize>;

    fn cell_get(&mut self, recorder: &mut Self::Recorder, object_id: u32) -> Result<Value>;

    fn cell_set(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()>;

    fn array_get(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        index: usize,
    ) -> Result<Value>;

    fn array_set(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()>;

    fn map_get(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        key: &Value,
        allocator: &mut AllocatorSession,
    ) -> Result<(Value, bool)>;

    fn map_put(
        &mut self,
        recorder: &mut Self::Recorder,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
        allocator: &mut AllocatorSession,
    ) -> Result<bool>;

    fn commit_against(
        &mut self,
        committed: &Self::CommittedState,
        aborted: bool,
        recorder: &mut Self::Recorder,
        allocator: &mut AllocatorSession,
    ) -> Result<Box<[u32]>>;
}

pub trait RuntimeKernelConfidentialStore: RuntimeKernelObjectStore + Sized {
    type FreshCoins;

    fn shadow_load(
        committed: &Self::CommittedState,
        shadow_load_object_ids: &[u32],
        allocator: &mut AllocatorSession,
    ) -> Result<Self>;

    fn install_fresh_coins(&mut self, fresh_coins: Option<Self::FreshCoins>) -> Result<()>;

    fn ensure_fresh_coins_consumed(&self) -> Result<()>;
}

pub struct RuntimeKernelMachine {
    allocator: AllocatorSession,
    max_hash_part_bytes: usize,
    boundary: RuntimeKernelBoundaryTracker,
}

pub struct RuntimeKernelEffectAdapter<'a, S: RuntimeKernelObjectStore> {
    machine: &'a mut RuntimeKernelMachine,
    store: &'a mut S,
    recorder: &'a mut S::Recorder,
    opcode_trace: &'a mut RuntimeKernelStatementTrace,
}

impl<'a, S: RuntimeKernelObjectStore> RuntimeKernelEffectAdapter<'a, S> {
    pub fn new(
        machine: &'a mut RuntimeKernelMachine,
        store: &'a mut S,
        recorder: &'a mut S::Recorder,
        opcode_trace: &'a mut RuntimeKernelStatementTrace,
    ) -> Self {
        Self {
            machine,
            store,
            recorder,
            opcode_trace,
        }
    }
}

struct RuntimeKernelSlotCall<'a, S: RuntimeKernelObjectStore> {
    effects: RuntimeKernelEffectAdapter<'a, S>,
    state: ConfidentialKernelSlotState,
}

impl<'a, S: RuntimeKernelObjectStore> RuntimeKernelSlotCall<'a, S> {
    fn new(effects: RuntimeKernelEffectAdapter<'a, S>, slot_count: usize) -> Result<Self> {
        Ok(Self {
            effects,
            state: ConfidentialKernelSlotState::new(slot_count)?,
        })
    }

    fn store_call_inputs(
        &mut self,
        program: &ConfidentialKernelSlotProgram,
        call_inputs: ConfidentialCallInputs,
    ) -> Result<()> {
        store_confidential_call_inputs(&mut self.state, program, call_inputs)
    }
}

impl<S: RuntimeKernelObjectStore> ConfidentialKernelSlotRuntime for RuntimeKernelSlotCall<'_, S> {
    fn note_statement(
        &mut self,
        statement: &uo_core::ConfidentialKernelSlotStatement,
    ) -> Result<()> {
        self.effects.note_statement(statement)
    }

    fn load_slot(&self, slot: usize) -> Result<Value> {
        self.state.load_slot(slot)
    }

    fn store_slot(&mut self, slot: usize, value: Value) -> Result<()> {
        self.state.store_slot(slot, value)?;
        self.effects
            .note_live_slot_words(self.state.live_slot_words())?;
        Ok(())
    }

    fn cell_get(&mut self, object_id: u32) -> Result<Value> {
        self.effects.cell_get(object_id)
    }

    fn cell_set(&mut self, object_id: u32, value: Value, predicate: Option<bool>) -> Result<()> {
        self.effects.cell_set(object_id, value, predicate)
    }

    fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value> {
        self.effects.array_get(object_id, index)
    }

    fn array_set(
        &mut self,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.effects.array_set(object_id, index, value, predicate)
    }

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<(Value, bool)> {
        self.effects.map_get(object_id, key)
    }

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<bool> {
        self.effects.map_put(object_id, key, value, predicate)
    }

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value> {
        self.effects.keccak256(parts)
    }
}

impl<S: RuntimeKernelObjectStore> ConfidentialKernelEffectRuntime
    for RuntimeKernelEffectAdapter<'_, S>
{
    fn note_statement(
        &mut self,
        statement: &uo_core::ConfidentialKernelSlotStatement,
    ) -> Result<()> {
        self.opcode_trace.record(statement)
    }

    fn note_live_slot_words(&mut self, words: usize) -> Result<()> {
        self.machine.enforce_stack_words(words)
    }

    fn cell_get(&mut self, object_id: u32) -> Result<Value> {
        self.machine.cell_get(self.store, self.recorder, object_id)
    }

    fn cell_set(&mut self, object_id: u32, value: Value, predicate: Option<bool>) -> Result<()> {
        self.machine
            .cell_set(self.store, self.recorder, object_id, value, predicate)
    }

    fn array_get(&mut self, object_id: u32, index: usize) -> Result<Value> {
        self.machine
            .array_get(self.store, self.recorder, object_id, index)
    }

    fn array_set(
        &mut self,
        object_id: u32,
        index: usize,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<()> {
        self.machine.array_set(
            self.store,
            self.recorder,
            object_id,
            index,
            value,
            predicate,
        )
    }

    fn map_get(&mut self, object_id: u32, key: &Value) -> Result<(Value, bool)> {
        self.machine
            .map_get(self.store, self.recorder, object_id, key)
    }

    fn map_put(
        &mut self,
        object_id: u32,
        key: Value,
        value: Value,
        predicate: Option<bool>,
    ) -> Result<bool> {
        self.machine
            .map_put(self.store, self.recorder, object_id, key, value, predicate)
    }

    fn keccak256(&mut self, parts: Box<[Value]>) -> Result<Value> {
        self.machine.keccak256_values(parts)
    }
}

impl RuntimeKernelMachine {
    pub fn begin(plan: AllocatorPlan, public_object_ids: &[u32]) -> Result<Self> {
        let kernel_step_capacity = plan.max_kernel_ops;
        Ok(Self {
            allocator: AllocatorSession::new(plan)?,
            max_hash_part_bytes: 0,
            boundary: RuntimeKernelBoundaryTracker::begin(public_object_ids, kernel_step_capacity)?,
        })
    }

    #[cfg(test)]
    pub fn begin_with_expected_kernel_steps(
        plan: AllocatorPlan,
        expected_kernel_steps: Vec<RuntimeKernelStepWitness>,
        public_object_ids: &[u32],
    ) -> Result<Self> {
        let mut machine = Self::begin(plan, public_object_ids)?;
        machine
            .boundary
            .bind_expected_kernel_steps(expected_kernel_steps.into_boxed_slice())?;
        Ok(machine)
    }

    pub fn enforce_stack_words(&mut self, words: usize) -> Result<()> {
        self.allocator.enforce_stack_words(words)
    }

    pub fn note_hash_bytes(&mut self, bytes: usize) -> Result<()> {
        self.allocator
            .reserve_scratch(ScratchRegion::HashScratch, bytes)
    }

    pub fn wipe_hash_scratch(&mut self) {
        self.allocator.wipe_region(ScratchRegion::HashScratch);
    }

    pub fn bind_expected_kernel_program(
        &mut self,
        program: &ConfidentialKernelSlotProgram,
    ) -> Result<()> {
        self.boundary.bind_expected_kernel_program(program)?;
        Ok(())
    }

    pub fn expected_loaded_object_schedule_required(&self) -> Result<Box<[u32]>> {
        self.boundary
            .expected_loaded_object_schedule_required()
            .map_err(Into::into)
    }

    pub fn record_shadow_load_object(&mut self, object_id: u32) -> Result<()> {
        self.boundary.record_shadow_load_object(object_id)?;
        Ok(())
    }

    pub fn shadow_load_with<T>(
        &mut self,
        shadow_load_object_ids: &[u32],
        load: impl FnOnce(&mut AllocatorSession) -> Result<T>,
    ) -> Result<T> {
        let value = load(&mut self.allocator)?;
        for object_id in shadow_load_object_ids {
            self.record_shadow_load_object(*object_id)?;
        }
        Ok(value)
    }

    #[allow(clippy::too_many_arguments)]
    pub fn run_confidential_call<S: RuntimeKernelConfidentialStore>(
        mut self,
        program: &ConfidentialKernelSlotProgram,
        committed: &S::CommittedState,
        max_hash_part_bytes: usize,
        raw_args: Box<[Value]>,
        fresh_coins: Option<S::FreshCoins>,
        recorder: &mut S::Recorder,
        opcode_trace: &mut RuntimeKernelStatementTrace,
    ) -> Result<(
        S,
        RuntimeKernelMachineFinishWitness,
        RuntimeKernelFinishBundle,
        bool,
        Option<Value>,
    )> {
        self.set_max_hash_part_bytes(max_hash_part_bytes);
        self.bind_expected_kernel_program(program)?;
        let shadow_load_object_ids = self.expected_loaded_object_schedule_required()?;
        let mut shadow = self.shadow_load_with(shadow_load_object_ids.as_ref(), |allocator| {
            S::shadow_load(committed, shadow_load_object_ids.as_ref(), allocator)
        })?;
        let had_injected_fresh_coins = fresh_coins.is_some();
        shadow.install_fresh_coins(fresh_coins)?;
        let call_inputs = ConfidentialCallInputs::from_raw_args(raw_args);
        let (aborted, return_value) = {
            let runtime_effects =
                RuntimeKernelEffectAdapter::new(&mut self, &mut shadow, recorder, opcode_trace);
            let mut runtime = RuntimeKernelSlotCall::new(runtime_effects, program.slot_count)?;
            runtime.store_call_inputs(program, call_inputs)?;
            let outcome = execute_confidential_kernel_slot_program(&mut runtime, program)?;
            let (aborted, return_value) = outcome.into_parts();
            (aborted, if aborted { None } else { return_value })
        };
        if had_injected_fresh_coins {
            shadow.ensure_fresh_coins_consumed()?;
        }
        self.commit_objects(&mut shadow, committed, aborted, recorder)?;
        let (runtime_kernel_machine_finish_witness, runtime_kernel_finish_bundle) =
            self.finish_with_machine_witness(&program.entrypoint_id)?;
        Ok((
            shadow,
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            aborted,
            return_value,
        ))
    }

    pub fn finish(self, entrypoint_id: &str) -> Result<RuntimeKernelFinishBundle> {
        let (_runtime_kernel_machine_finish_witness, runtime_kernel_finish_bundle) =
            self.finish_with_machine_witness(entrypoint_id)?;
        Ok(runtime_kernel_finish_bundle)
    }

    fn touch_value_scratch(&mut self, bytes: usize) -> Result<()> {
        let _guard = self
            .allocator
            .reserve_guard(ScratchRegion::ValueScratch, bytes)?;
        Ok(())
    }

    pub fn set_max_hash_part_bytes(&mut self, bytes: usize) {
        self.max_hash_part_bytes = bytes;
    }

    #[cfg(test)]
    pub fn record_kernel_step_for_test(
        &mut self,
        opcode: UoOpcode,
        object_id: Option<u32>,
    ) -> Result<()> {
        self.record_kernel_step(opcode, object_id)
    }

    fn record_kernel_step(&mut self, opcode: UoOpcode, object_id: Option<u32>) -> Result<()> {
        self.boundary.record_opcode(opcode, object_id)?;
        self.allocator.record_kernel_op()?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{
        RuntimeKernelConfidentialStore, RuntimeKernelMachine, RuntimeKernelObjectStore,
        RuntimeKernelStatementTrace,
    };
    use anyhow::Result;
    use tiny_keccak::{Hasher, Keccak};
    use uo_allocator::{AllocatorPlan, AllocatorSession};
    use uo_core::{
        max_runtime_kernel_refinement_event_count, BinaryOp, ConfidentialKernelSlotExpr,
        ConfidentialKernelSlotProgram, ConfidentialKernelSlotStatement, RuntimeKernelStepWitness,
        ScalarType, Type, Value,
    };
    use uo_precompiles::UoOpcode;

    #[derive(Debug, Default)]
    struct DummyStore;

    impl RuntimeKernelObjectStore for DummyStore {
        type CommittedState = ();
        type Recorder = ();

        fn value_canonical_len(&mut self, object_id: u32) -> Result<usize> {
            unreachable!("dummy store has no value length for object {object_id}")
        }

        fn key_canonical_len(&mut self, object_id: u32) -> Result<usize> {
            unreachable!("dummy store has no key length for object {object_id}")
        }

        fn cell_get(&mut self, _recorder: &mut Self::Recorder, object_id: u32) -> Result<Value> {
            unreachable!("dummy store has no cell_get for object {object_id}")
        }

        fn cell_set(
            &mut self,
            _recorder: &mut Self::Recorder,
            object_id: u32,
            _value: Value,
            _predicate: Option<bool>,
        ) -> Result<()> {
            unreachable!("dummy store has no cell_set for object {object_id}")
        }

        fn array_get(
            &mut self,
            _recorder: &mut Self::Recorder,
            object_id: u32,
            index: usize,
        ) -> Result<Value> {
            unreachable!("dummy store has no array_get for object {object_id} index {index}")
        }

        fn array_set(
            &mut self,
            _recorder: &mut Self::Recorder,
            object_id: u32,
            index: usize,
            _value: Value,
            _predicate: Option<bool>,
        ) -> Result<()> {
            unreachable!("dummy store has no array_set for object {object_id} index {index}")
        }

        fn map_get(
            &mut self,
            _recorder: &mut Self::Recorder,
            object_id: u32,
            _key: &Value,
            _allocator: &mut AllocatorSession,
        ) -> Result<(Value, bool)> {
            unreachable!("dummy store has no map_get for object {object_id}")
        }

        fn map_put(
            &mut self,
            _recorder: &mut Self::Recorder,
            object_id: u32,
            _key: Value,
            _value: Value,
            _predicate: Option<bool>,
            _allocator: &mut AllocatorSession,
        ) -> Result<bool> {
            unreachable!("dummy store has no map_put for object {object_id}")
        }

        fn commit_against(
            &mut self,
            _committed: &Self::CommittedState,
            _aborted: bool,
            _recorder: &mut Self::Recorder,
            _allocator: &mut AllocatorSession,
        ) -> Result<Box<[u32]>> {
            Ok(Vec::new().into_boxed_slice())
        }
    }

    impl RuntimeKernelConfidentialStore for DummyStore {
        type FreshCoins = ();

        fn shadow_load(
            _committed: &Self::CommittedState,
            shadow_load_object_ids: &[u32],
            _allocator: &mut AllocatorSession,
        ) -> Result<Self> {
            assert!(shadow_load_object_ids.is_empty());
            Ok(Self)
        }

        fn install_fresh_coins(&mut self, fresh_coins: Option<Self::FreshCoins>) -> Result<()> {
            assert!(fresh_coins.is_none());
            Ok(())
        }

        fn ensure_fresh_coins_consumed(&self) -> Result<()> {
            Ok(())
        }
    }

    fn kernel_plan() -> AllocatorPlan {
        AllocatorPlan {
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            max_kernel_ops: 8,
        }
    }

    fn slot_add_program() -> ConfidentialKernelSlotProgram {
        ConfidentialKernelSlotProgram {
            entrypoint_id: "demo(uint256)".into(),
            param_count: 1,
            return_type: Some(Type::Scalar(ScalarType::Uint(256))),
            secret_args: vec![0],
            slot_count: 2,
            body: vec![
                ConfidentialKernelSlotStatement::Declare {
                    slot: 1,
                    value: ConfidentialKernelSlotExpr::Binary {
                        op: BinaryOp::Add,
                        lhs: Box::new(ConfidentialKernelSlotExpr::Slot { slot: 0 }),
                        rhs: Box::new(ConfidentialKernelSlotExpr::Literal {
                            value: Value::uint(2),
                        }),
                    },
                },
                ConfidentialKernelSlotStatement::Return {
                    value: Some(ConfidentialKernelSlotExpr::Slot { slot: 1 }),
                },
            ]
            .into_boxed_slice(),
        }
    }

    #[test]
    fn runtime_phase_event_bound_matches_public_objects_and_kernel_ops() {
        assert_eq!(max_runtime_kernel_refinement_event_count(0, 3).unwrap(), 3);
        assert_eq!(max_runtime_kernel_refinement_event_count(2, 4).unwrap(), 14);
    }

    #[test]
    fn kernel_rejects_kernel_op_budget_overflow() {
        let kernel = RuntimeKernelMachine::begin(
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
        let mut kernel = RuntimeKernelMachine::begin_with_expected_kernel_steps(
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
            .record_kernel_step_for_test(UoOpcode::CellGet, Some(8))
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("runtime kernel step schedule mismatch"));
    }

    #[test]
    fn kernel_runtime_stages_confidential_args_into_slot_state() {
        let kernel = RuntimeKernelMachine::begin(kernel_plan(), &[]).unwrap();
        let mut recorder = ();
        let program = slot_add_program();
        let mut opcode_trace = RuntimeKernelStatementTrace::new(program.body.len());

        let (_shadow, _machine_witness, _finish_bundle, aborted, return_value) = kernel
            .run_confidential_call::<DummyStore>(
                &program,
                &(),
                32,
                vec![Value::uint(5)].into_boxed_slice(),
                None,
                &mut recorder,
                &mut opcode_trace,
            )
            .unwrap();

        assert!(!aborted);
        assert_eq!(return_value, Some(Value::uint(7)));
        assert_eq!(
            opcode_trace.into_boxed_trace().as_ref(),
            [String::from("declare"), String::from("return")]
        );
    }

    #[test]
    fn kernel_machine_keccak_uses_real_runtime_hash_not_lean_mock() {
        let mut kernel = RuntimeKernelMachine::begin(kernel_plan(), &[]).unwrap();
        let value = Value::uint(7);
        let mut expected = [0u8; 32];
        let mut hasher = Keccak::v256();
        value.visit_canonical_chunks(&mut |chunk| hasher.update(chunk));
        hasher.finalize(&mut expected);

        let digest = kernel
            .keccak256_values(vec![value].into_boxed_slice())
            .unwrap();

        assert_ne!(expected, [0u8; 32]);
        assert_eq!(digest, Value::Bytes32(expected));
    }

    #[test]
    fn kernel_runtime_rejects_confidential_arg_count_mismatch() {
        let mut recorder = ();
        let program = slot_add_program();
        let mut opcode_trace = RuntimeKernelStatementTrace::new(program.body.len());
        let err = RuntimeKernelMachine::begin(kernel_plan(), &[])
            .unwrap()
            .run_confidential_call::<DummyStore>(
                &program,
                &(),
                32,
                Vec::new().into_boxed_slice(),
                None,
                &mut recorder,
                &mut opcode_trace,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("expected 1 confidential arguments but runtime supplied 0"));

        let mut recorder = ();
        let mut opcode_trace = RuntimeKernelStatementTrace::new(program.body.len());
        let err = RuntimeKernelMachine::begin(kernel_plan(), &[])
            .unwrap()
            .run_confidential_call::<DummyStore>(
                &program,
                &(),
                32,
                vec![Value::uint(1), Value::uint(2)].into_boxed_slice(),
                None,
                &mut recorder,
                &mut opcode_trace,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("expected 1 confidential arguments but runtime supplied 2"));
    }
}
