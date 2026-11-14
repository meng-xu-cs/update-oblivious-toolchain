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
use uo_store::SharedStorage;

pub(crate) fn deploy_contract_runtime(
    contract_state: &[StateObject],
    master: &RuntimeMasterSecret,
    storage: &SharedStorage,
    restore: bool,
) -> Result<ContractRuntime> {
    state::ContractRuntime::deploy(contract_state, master, storage, restore)
}

#[cfg(test)]
pub(crate) fn ensure_contract_runtime_cold(
    runtime: &ContractRuntime,
    expected_object_ids: &[u32],
    context: &str,
) -> Result<()> {
    runtime.ensure_cold(expected_object_ids, context)
}

/// The committed runtime for staged (transactional) execution: a runtime
/// that holds the committed objects themselves, shared and not copied.
/// `run_contract_call` replaces in it the objects the call loaded, and it is
/// committed back into the engine only on full success.
pub(crate) fn stage_contract_runtime(runtime: &ContractRuntime) -> Result<ContractRuntime> {
    // The committed state must be cold before a call is staged on it: the
    // staged runtime shares its objects.
    runtime.ensure_committed_cold_for_call()?;
    crate::instrumentation::time_staging(|| runtime.staged_clone())
}

/// Store `entries` in one map of a deployed runtime with no call. Only a test
/// or diagnostics build has it: it changes committed state without a trace,
/// a receipt or a freshness step.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn bulk_load_contract_map_for_diagnostics(
    runtime: &mut ContractRuntime,
    object_name: &str,
    entries: Vec<(Value, Value)>,
) -> Result<()> {
    runtime.bulk_load_map_for_diagnostics(object_name, entries)
}

/// Compare the witness a deployed runtime keeps for its calls with the
/// decode of its whole store. Only a test or diagnostics build keeps one.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn audit_contract_kept_witness(runtime: &ContractRuntime) -> Result<bool> {
    runtime.audit_kept_witness("when asked")
}

/// Decode the witness of a deployed runtime's calls from its whole store and
/// keep it. Only a test or diagnostics build keeps one.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn keep_decoded_contract_witness(runtime: &mut ContractRuntime) -> Result<()> {
    runtime.keep_decoded_witness()
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
