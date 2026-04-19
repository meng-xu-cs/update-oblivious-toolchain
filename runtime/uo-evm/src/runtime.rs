#[path = "fresh_coins.rs"]
pub(crate) mod fresh_coins;

#[path = "kernel.rs"]
pub(crate) mod kernel;

#[path = "objects.rs"]
pub(crate) mod objects;

#[path = "state.rs"]
pub(crate) mod state;

use uo_core::{RuntimeKernelRefinementWitness, RuntimeKernelWitness, Value};

#[derive(Debug)]
pub(crate) struct RuntimeCallOutcome {
    runtime_kernel_witness: RuntimeKernelWitness,
    runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    aborted: bool,
    return_value: Option<Value>,
    opcode_trace: Vec<String>,
}

impl RuntimeCallOutcome {
    pub(crate) fn from_runtime_execution(
        runtime_kernel_witness: RuntimeKernelWitness,
        runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
        aborted: bool,
        return_value: Option<Value>,
        opcode_trace: Vec<String>,
    ) -> Self {
        Self {
            runtime_kernel_witness,
            runtime_kernel_refinement_witness,
            aborted,
            return_value,
            opcode_trace,
        }
    }

    pub(crate) fn into_theorem_trace_parts(
        self,
    ) -> (
        RuntimeKernelWitness,
        RuntimeKernelRefinementWitness,
        bool,
        Option<Value>,
        Vec<String>,
    ) {
        (
            self.runtime_kernel_witness,
            self.runtime_kernel_refinement_witness,
            self.aborted,
            self.return_value,
            self.opcode_trace,
        )
    }
}
