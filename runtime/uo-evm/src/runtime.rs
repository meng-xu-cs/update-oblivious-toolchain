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
use crate::freshness::RuntimeCallFreshness;
use crate::return_channel::ReturnChannelSession;
use crate::secret::RuntimeMasterSecret;
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
    master: &RuntimeMasterSecret,
) -> Result<ContractRuntime> {
    state::ContractRuntime::deploy(contract_state, master)
}

#[cfg(test)]
pub(crate) fn ensure_contract_runtime_cold(
    runtime: &ContractRuntime,
    expected_object_ids: &[u32],
    context: &str,
) -> Result<()> {
    runtime.ensure_cold(expected_object_ids, context)
}

/// Deep cold clone of the committed runtime for staged (transactional)
/// execution. The returned runtime is mutated by `run_contract_call` and
/// committed back into the engine only on full success.
pub(crate) fn stage_contract_runtime(runtime: &ContractRuntime) -> Result<ContractRuntime> {
    // The committed state must be cold before it is cloned for staging; cloning
    // cold-ifies objects, so this gate runs on the original committed state.
    runtime.ensure_committed_cold_for_call()?;
    runtime.staged_clone()
}

pub(crate) fn run_contract_call(
    runtime: &mut ContractRuntime,
    artifact: &CompiledArtifact,
    function: &CompiledFunction,
    replay_seed: Option<u64>,
    call_freshness: RuntimeCallFreshness,
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
        replay_seed,
        call_freshness,
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
