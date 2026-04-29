use crate::controller::{finalize_public_call_trace, CallRecorder, PublicCallSummary};
use crate::return_channel::{encrypt_return_value, ReturnChannelSession};
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::state::ContractRuntime;
use anyhow::{anyhow, bail, Result};
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::{
    CompiledArtifact, EncryptedReturnPayload, ExecutionTrace, ReturnPolicy,
    TracedRuntimeCallOutcome, TracedRuntimeCallStart, Value,
};

struct CallTraceContext {
    runtime_call_start: TracedRuntimeCallStart,
    public_call: PublicCallSummary,
    recorder: CallRecorder,
}

fn begin_call_trace(
    runtime: &ContractRuntime,
    entrypoint: &str,
    manifest_entry: &EntrypointManifest,
    args: &[Value],
) -> Result<CallTraceContext> {
    let (runtime_call_start, public_call, recorder) =
        runtime.begin_traced_call(entrypoint, manifest_entry, args)?;
    Ok(CallTraceContext {
        runtime_call_start,
        public_call,
        recorder,
    })
}

impl CallTraceContext {
    fn recorder_mut(&mut self) -> &mut CallRecorder {
        &mut self.recorder
    }
}

struct FinalizeCallTraceInput<'a> {
    context: CallTraceContext,
    artifact: &'a CompiledArtifact,
    entrypoint: &'a str,
    confidential: bool,
    deploy_seed: u64,
    manifest_entry: &'a EntrypointManifest,
    manifest_objects: &'a [StateObjectManifest],
    traced_outcome: TracedRuntimeCallOutcome,
    return_channel: Option<&'a ReturnChannelSession>,
}

pub(in crate::runtime) fn run_traced_call(
    runtime: &mut ContractRuntime,
    artifact: &CompiledArtifact,
    entrypoint: &str,
    confidential: bool,
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
    let manifest_entry = artifact
        .contract
        .manifest
        .entrypoints
        .get(entrypoint)
        .ok_or_else(|| anyhow!("manifest entry missing for {entrypoint}"))?;
    let mut context = begin_call_trace(&*runtime, entrypoint, manifest_entry, &args)?;
    let call_outcome = super::run_runtime_entrypoint(
        runtime,
        &artifact.contract,
        entrypoint,
        manifest_entry,
        confidential,
        args,
        fresh_coins,
        context.recorder_mut(),
    )?;
    let traced_outcome = runtime.finish_traced_call(call_outcome)?;
    finalize_call_trace(FinalizeCallTraceInput {
        context,
        artifact,
        entrypoint,
        confidential,
        deploy_seed,
        manifest_entry,
        manifest_objects: &artifact.contract.manifest.objects,
        traced_outcome,
        return_channel,
    })
}

fn finalize_call_trace(
    input: FinalizeCallTraceInput<'_>,
) -> Result<(
    Option<Value>,
    Option<EncryptedReturnPayload>,
    bool,
    ExecutionTrace,
    usize,
)> {
    let FinalizeCallTraceInput {
        context,
        artifact,
        entrypoint,
        confidential,
        deploy_seed,
        manifest_entry,
        manifest_objects,
        traced_outcome,
        return_channel,
    } = input;
    let CallTraceContext {
        runtime_call_start,
        public_call,
        recorder,
    } = context;
    let (
        runtime_kernel_machine_finish_witness,
        runtime_kernel_finish_bundle,
        aborted,
        return_value,
        opcode_trace,
        public_state_transition,
        runtime_witness_state,
    ) = traced_outcome
        .into_finalized_call_trace_parts(runtime_call_start)
        .into_execution_trace_inputs();
    let encrypted_return = encrypted_return_payload_of(
        artifact,
        manifest_entry,
        entrypoint,
        public_call.public_args(),
        &return_value,
        return_channel,
    )?;
    let (gas_used, zero_writes, trace_bundle) = finalize_public_call_trace(
        recorder,
        manifest_entry,
        manifest_objects,
        public_call,
        &return_value,
        encrypted_return.clone(),
        aborted,
        confidential,
    )?;
    let trace = ExecutionTrace::from_runtime_finalization_input(
        artifact,
        confidential,
        trace_bundle.into_runtime_finalization_input(
            opcode_trace,
            gas_used,
            Some(deploy_seed),
            public_state_transition,
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            runtime_witness_state,
        ),
    )
    .map_err(anyhow::Error::from)?;
    let host_return_value = if encrypted_return.is_some() {
        None
    } else {
        return_value
    };
    Ok((
        host_return_value,
        encrypted_return,
        aborted,
        trace,
        zero_writes,
    ))
}

fn encrypted_return_payload_of(
    artifact: &CompiledArtifact,
    manifest_entry: &EntrypointManifest,
    entrypoint: &str,
    public_args: &[String],
    return_value: &Option<Value>,
    return_channel: Option<&ReturnChannelSession>,
) -> Result<Option<EncryptedReturnPayload>> {
    match (return_value, manifest_entry.returns, return_channel) {
        (Some(value), ReturnPolicy::EncryptedToClient, Some(session)) => Ok(Some(
            encrypt_return_value(artifact, entrypoint, public_args, value, session)?,
        )),
        (Some(_), ReturnPolicy::EncryptedToClient, None) => {
            bail!("encrypted_to_client return requires a return channel session")
        }
        (Some(_), _, Some(_)) => bail!("return channel supplied for non-encrypted return policy"),
        (None, policy, Some(_)) if policy != ReturnPolicy::EncryptedToClient => {
            bail!("return channel supplied for non-encrypted return policy")
        }
        _ => Ok(None),
    }
}
