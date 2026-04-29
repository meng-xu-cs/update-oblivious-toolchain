#[path = "fresh_coins.rs"]
mod fresh_coins;

#[path = "objects.rs"]
pub(crate) mod objects;

#[path = "shell.rs"]
mod shell;

#[path = "state.rs"]
mod state;

#[path = "theorem.rs"]
mod theorem;

use crate::controller::CallRecorder;
use crate::return_channel::ReturnChannelSession;
use anyhow::Result;
pub use fresh_coins::PathOramFreshCoinPlan;
pub(crate) use state::ContractRuntime;
use uo_core::ir::StateObject;
use uo_core::manifest::EntrypointManifest;
use uo_core::{
    CompiledArtifact, CompiledContract, CompiledFunction, EncryptedReturnPayload, ExecutionTrace,
};
use uo_core::{RuntimeCallOutcome, Value};

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
    args: Box<[Value]>,
    fresh_coins: Option<PathOramFreshCoinPlan>,
    return_channel: Option<&ReturnChannelSession>,
) -> Result<(
    Option<Value>,
    Option<EncryptedReturnPayload>,
    bool,
    ExecutionTrace,
    usize,
)> {
    theorem::run_traced_call(
        runtime,
        artifact,
        &function.signature,
        function.confidential,
        deploy_seed,
        args,
        fresh_coins,
        return_channel,
    )
}

pub(in crate::runtime) fn run_runtime_entrypoint(
    runtime: &mut ContractRuntime,
    contract: &CompiledContract,
    entrypoint: &str,
    manifest_entry: &EntrypointManifest,
    confidential: bool,
    args: Box<[Value]>,
    fresh_coins: Option<PathOramFreshCoinPlan>,
    recorder: &mut CallRecorder,
) -> Result<RuntimeCallOutcome> {
    if confidential {
        runtime.run_confidential_entrypoint(entrypoint, manifest_entry, args, fresh_coins, recorder)
    } else {
        shell::run_public_entrypoint(
            runtime,
            contract,
            entrypoint,
            manifest_entry,
            args,
            recorder,
        )
    }
}
