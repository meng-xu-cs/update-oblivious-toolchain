use crate::controller::{output_shape_of, CallRecorder, PublicCallSummary};
use crate::runtime::state::{
    ContractRuntime, TracedRuntimeCallOutcome, TracedRuntimeCallStart,
    TracedRuntimeCallWitnessState,
};
use crate::runtime::RuntimeCallOutcome;
use anyhow::Result;
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::{
    CompiledArtifact, ExecutionTrace, OutputShape, RuntimeControllerObserverCertificate,
    RuntimeKernelRefinementWitness, RuntimeKernelWitness, RuntimeOramObjectWitness,
    RuntimePathOramHiddenCertificate, RuntimeTrustedKernelBundle, Value,
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

struct FinalizeExecutionTraceInput<'a> {
    pub artifact: &'a CompiledArtifact,
    pub entrypoint: &'a str,
    pub confidential: bool,
    pub deploy_seed: u64,
    pub opcode_trace: Vec<String>,
    pub gas_used: u64,
    pub trace_bundle: crate::controller::CallTraceBundle,
    pub runtime_kernel_witness: RuntimeKernelWitness,
    pub runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,
    pub runtime_witness_state: TracedRuntimeCallWitnessState,
}

struct FinalizeCallTraceInput<'a> {
    pub context: CallTraceContext,
    pub artifact: &'a CompiledArtifact,
    pub entrypoint: &'a str,
    pub confidential: bool,
    pub deploy_seed: u64,
    pub manifest_entry: &'a EntrypointManifest,
    pub manifest_objects: &'a [StateObjectManifest],
    pub traced_outcome: TracedRuntimeCallOutcome,
}

pub(crate) struct FinalizedCallTrace {
    trace: ExecutionTrace,
    zero_writes: usize,
    return_value: Option<uo_core::Value>,
    aborted: bool,
}

impl FinalizedCallTrace {
    pub(crate) fn into_engine_result_parts(self) -> (Option<Value>, bool, ExecutionTrace, usize) {
        (
            self.return_value,
            self.aborted,
            self.trace,
            self.zero_writes,
        )
    }
}

pub(crate) fn run_traced_call<F>(
    runtime: &mut ContractRuntime,
    artifact: &CompiledArtifact,
    entrypoint: &str,
    confidential: bool,
    deploy_seed: u64,
    manifest_entry: &EntrypointManifest,
    manifest_objects: &[StateObjectManifest],
    args: Vec<Value>,
    execute: F,
) -> Result<FinalizedCallTrace>
where
    F: FnOnce(&mut ContractRuntime, Vec<Value>, &mut CallRecorder) -> Result<RuntimeCallOutcome>,
{
    let mut context = begin_call_trace(&*runtime, entrypoint, manifest_entry, &args)?;
    let call_outcome = execute(runtime, args, context.recorder_mut())?;
    let traced_outcome = runtime.finish_traced_call(call_outcome)?;
    finalize_call_trace(FinalizeCallTraceInput {
        context,
        artifact,
        entrypoint,
        confidential,
        deploy_seed,
        manifest_entry,
        manifest_objects,
        traced_outcome,
    })
}

fn build_theorem_trace(
    recorder: CallRecorder,
    manifest_entry: &EntrypointManifest,
    manifest_objects: &[StateObjectManifest],
    public_call: PublicCallSummary,
    output_shape: OutputShape,
    aborted: bool,
    gas_used: u64,
) -> Result<crate::controller::CallTraceBundle> {
    recorder.finish(
        manifest_entry,
        manifest_objects,
        public_call,
        output_shape,
        aborted,
        gas_used,
    )
}

fn finalize_execution_trace(input: FinalizeExecutionTraceInput<'_>) -> Result<ExecutionTrace> {
    let FinalizeExecutionTraceInput {
        artifact,
        entrypoint,
        confidential,
        deploy_seed,
        opcode_trace,
        gas_used,
        trace_bundle,
        runtime_kernel_witness,
        runtime_kernel_refinement_witness,
        runtime_witness_state,
    } = input;
    let (
        runtime_oram_access_counters_before,
        runtime_oram_access_counters_after,
        runtime_oram_position_map_before,
        runtime_oram_position_map_after,
    ) = runtime_witness_state.into_execution_trace_parts();

    let mut trace = ExecutionTrace {
        opcode_trace,
        logical_accesses: trace_bundle.logical_accesses,
        logical_writes: trace_bundle.logical_writes,
        physical_reads: trace_bundle.physical_reads,
        physical_writes: trace_bundle.physical_writes,
        gas_used,
        theorem_trace: trace_bundle.theorem_trace,
        runtime_seed: Some(deploy_seed),
        runtime_kernel_witness: Some(runtime_kernel_witness.clone()),
        runtime_kernel_refinement_witness: Some(runtime_kernel_refinement_witness),
        runtime_trusted_kernel_bundle: None,
        runtime_controller_certificate: Some(trace_bundle.controller_certificate),
        runtime_oram_objects: runtime_oram_objects(artifact),
        runtime_oram_leaf_schedule: trace_bundle.oram_leaf_schedule,
        runtime_oram_access_counters_before,
        runtime_oram_access_counters_after,
        runtime_oram_position_map_before,
        runtime_oram_position_map_after,
        runtime_oram_leaf_state_transitions: trace_bundle.oram_leaf_state_transitions,
    };
    if confidential {
        trace
            .runtime_kernel_witness_for_confidential(artifact, entrypoint)
            .map_err(|err| {
                anyhow::anyhow!("runtime kernel witness drifted from admitted artifact: {err}")
            })?;
    }

    let direct_controller_observer = RuntimeControllerObserverCertificate::new(
        trace
            .theorem_trace
            .public_outcome
            .clone()
            .ok_or_else(|| anyhow::anyhow!("runtime theorem trace missing public_outcome"))?,
        trace.theorem_trace.boundary_schedule.clone(),
        trace
            .theorem_trace
            .controller_shape
            .clone()
            .ok_or_else(|| anyhow::anyhow!("runtime theorem trace missing controller_shape"))?,
        trace
            .theorem_trace
            .normalized_micro_trace
            .clone()
            .ok_or_else(|| {
                anyhow::anyhow!("runtime theorem trace missing normalized_micro_trace")
            })?,
        trace
            .runtime_controller_certificate
            .clone()
            .ok_or_else(|| {
                anyhow::anyhow!("execution trace missing runtime controller certificate")
            })?,
    )?;
    let direct_hidden_certificate = RuntimePathOramHiddenCertificate::new(
        trace.refinement_trace(),
        trace.runtime_oram_objects.clone(),
        trace.runtime_oram_leaf_schedule.clone(),
        trace.runtime_oram_position_map_before.clone(),
        trace.runtime_oram_position_map_after.clone(),
        trace.runtime_oram_leaf_state_transitions.clone(),
    )?;
    let direct_bundle = RuntimeTrustedKernelBundle::new_with_kernel_witness(
        trace.runtime_seed,
        direct_controller_observer,
        Some(runtime_kernel_witness),
        direct_hidden_certificate,
    )?;
    let reconstructed_bundle = trace.runtime_trusted_kernel_bundle()?;
    if reconstructed_bundle != direct_bundle {
        anyhow::bail!("runtime trusted kernel drifted from direct certificate reconstruction");
    }
    trace.runtime_trusted_kernel_bundle = Some(direct_bundle);
    Ok(trace)
}

fn gas_used_of(
    recorder: &CallRecorder,
    manifest_entry: &EntrypointManifest,
    confidential: bool,
) -> u64 {
    if confidential {
        return manifest_entry.public_gas_budget;
    }
    let mut gas_used = 0u64;
    gas_used += recorder.metrics().logical_reads as u64 * 3;
    gas_used += recorder.metrics().logical_writes as u64 * 5;
    gas_used += recorder.metrics().physical_writes as u64 * 17;
    gas_used
}

fn finalize_call_trace(input: FinalizeCallTraceInput<'_>) -> Result<FinalizedCallTrace> {
    let FinalizeCallTraceInput {
        context,
        artifact,
        entrypoint,
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
        runtime_kernel_witness,
        runtime_kernel_refinement_witness,
        aborted,
        return_value,
        opcode_trace,
        runtime_witness_state,
    ) = traced_outcome.into_finalized_call_trace_parts(runtime_call_start);
    let gas_used = gas_used_of(&recorder, manifest_entry, confidential);
    let output_shape = output_shape_of(manifest_entry, &return_value)?;
    let trace_bundle = build_theorem_trace(
        recorder,
        manifest_entry,
        manifest_objects,
        public_call,
        output_shape,
        aborted,
        gas_used,
    )?;
    let zero_writes = trace_bundle.metrics.zero_writes;
    let trace = finalize_execution_trace(FinalizeExecutionTraceInput {
        artifact,
        entrypoint,
        confidential,
        deploy_seed,
        opcode_trace,
        gas_used,
        trace_bundle,
        runtime_kernel_witness,
        runtime_kernel_refinement_witness,
        runtime_witness_state,
    })?;
    Ok(FinalizedCallTrace {
        trace,
        zero_writes,
        return_value,
        aborted,
    })
}

fn runtime_oram_objects(artifact: &CompiledArtifact) -> Vec<RuntimeOramObjectWitness> {
    artifact
        .contract
        .manifest
        .objects
        .iter()
        .filter_map(|object| {
            let oram = object.oram.as_ref()?;
            Some(RuntimeOramObjectWitness {
                object_id: object.id,
                object_name: object.name.clone(),
                scheme: oram.scheme.clone(),
                capacity: object.capacity.unwrap_or_default(),
                block_size: oram.block_size,
                bucket_size: oram.bucket_size,
                bucket_count: oram.bucket_count,
                blocks_per_bucket: oram.blocks_per_bucket,
                tree_height: oram.tree_height,
                stash_bound: oram.stash_bound,
                recursion_depth: oram.recursion_depth,
                metadata_pages: oram.metadata_pages,
                metadata_pages_per_access: oram.metadata_pages_per_access,
                buckets_per_access: oram.buckets_per_access,
                accesses_per_call: oram.accesses_per_call,
            })
        })
        .collect()
}
