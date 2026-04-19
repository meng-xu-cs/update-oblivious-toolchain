#[path = "fresh_coins.rs"]
mod fresh_coins;

#[path = "kernel.rs"]
mod kernel;

#[path = "objects.rs"]
pub(crate) mod objects;

#[path = "shell.rs"]
mod shell;

#[path = "state.rs"]
mod state;

#[path = "theorem.rs"]
mod theorem;

use anyhow::Result;
pub use fresh_coins::PathOramFreshCoinPlan;
pub(crate) use state::ContractRuntime;
use uo_core::ir::StateObject;
use uo_core::{CompiledArtifact, CompiledFunction, ExecutionTrace};
use uo_core::{RuntimeKernelRefinementWitness, RuntimeKernelWitness, Value};

pub(crate) fn deploy_contract_runtime(
    contract_state: &[StateObject],
    deploy_seed: u64,
) -> Result<ContractRuntime> {
    state::ContractRuntime::deploy(contract_state, deploy_seed)
}

#[cfg(test)]
pub(crate) fn ensure_contract_runtime_cold(
    runtime: &ContractRuntime,
    expected_object_ids: &[u32],
    context: &str,
) -> Result<()> {
    runtime.ensure_cold(expected_object_ids, context)
}

pub(crate) fn run_contract_call(
    runtime: &mut ContractRuntime,
    artifact: &CompiledArtifact,
    function: &CompiledFunction,
    deploy_seed: u64,
    args: Vec<Value>,
    fresh_coins: Option<PathOramFreshCoinPlan>,
) -> Result<(Option<Value>, bool, ExecutionTrace, usize)> {
    theorem::run_traced_call(
        runtime,
        artifact,
        &function.signature,
        function.confidential,
        deploy_seed,
        args,
        fresh_coins,
    )
}

#[derive(Debug)]
pub(in crate::runtime) struct RuntimeCallOutcome {
    runtime_kernel_witness: RuntimeKernelWitness,
    runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    aborted: bool,
    return_value: Option<Value>,
    opcode_trace: Vec<String>,
}

impl RuntimeCallOutcome {
    pub(in crate::runtime) fn from_runtime_execution(
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

    pub(in crate::runtime) fn into_theorem_trace_parts(
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
