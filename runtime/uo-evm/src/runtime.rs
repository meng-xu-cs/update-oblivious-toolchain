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
    pub runtime_kernel_witness: RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    pub aborted: bool,
    pub return_value: Option<Value>,
    pub opcode_trace: Vec<String>,
}
