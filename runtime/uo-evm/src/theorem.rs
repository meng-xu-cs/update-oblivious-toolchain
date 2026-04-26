use crate::controller::{finalize_public_call_trace, CallRecorder, PublicCallSummary};
use crate::runtime::fresh_coins::PathOramFreshCoinPlan;
use crate::runtime::state::ContractRuntime;
use anyhow::{anyhow, Result};
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::{
    CompiledArtifact, ExecutionTrace, TracedRuntimeCallOutcome, TracedRuntimeCallStart, Value,
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
    confidential: bool,
    deploy_seed: u64,
    manifest_entry: &'a EntrypointManifest,
    manifest_objects: &'a [StateObjectManifest],
    traced_outcome: TracedRuntimeCallOutcome,
}

pub(in crate::runtime) fn run_traced_call(
    runtime: &mut ContractRuntime,
    artifact: &CompiledArtifact,
    entrypoint: &str,
    confidential: bool,
    deploy_seed: u64,
    args: Box<[Value]>,
    fresh_coins: Option<PathOramFreshCoinPlan>,
) -> Result<(Option<Value>, bool, ExecutionTrace, usize)> {
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
        confidential,
        deploy_seed,
        manifest_entry,
        manifest_objects: &artifact.contract.manifest.objects,
        traced_outcome,
    })
}

fn finalize_call_trace(
    input: FinalizeCallTraceInput<'_>,
) -> Result<(Option<Value>, bool, ExecutionTrace, usize)> {
    let FinalizeCallTraceInput {
        context,
        artifact,
        confidential,
        deploy_seed,
        manifest_entry,
        manifest_objects,
        traced_outcome,
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
        runtime_witness_state,
    ) = traced_outcome
        .into_finalized_call_trace_parts(runtime_call_start)
        .into_execution_trace_inputs();
    let (gas_used, zero_writes, trace_bundle) = finalize_public_call_trace(
        recorder,
        manifest_entry,
        manifest_objects,
        public_call,
        &return_value,
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
            runtime_kernel_machine_finish_witness,
            runtime_kernel_finish_bundle,
            runtime_witness_state,
        ),
    )
    .map_err(anyhow::Error::from)?;
    Ok((return_value, aborted, trace, zero_writes))
}
