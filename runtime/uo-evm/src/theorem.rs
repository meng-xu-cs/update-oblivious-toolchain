use crate::controller::CallRecorder;
use anyhow::Result;
use uo_core::ir::CompiledFunction;
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::{ExecutionTrace, Value};

pub fn build_theorem_trace(
    recorder: CallRecorder,
    function: &CompiledFunction,
    manifest_entry: &EntrypointManifest,
    manifest_objects: &[StateObjectManifest],
    args: &[Value],
    return_value: &Option<Value>,
    aborted: bool,
    gas_used: u64,
) -> Result<crate::controller::CallTraceBundle> {
    recorder.finish(
        function,
        manifest_entry,
        manifest_objects,
        args,
        return_value,
        aborted,
        gas_used,
    )
}

pub fn attach_theorem_metrics(trace: &mut ExecutionTrace) {
    if let Some(shape) = &trace.theorem_trace.controller_shape {
        trace.host_proxy_metrics.insert(
            "boundary_events".into(),
            trace.theorem_trace.boundary_schedule.len() as f64,
        );
        trace.host_proxy_metrics.insert(
            "controller_phase_count".into(),
            shape.controller_phase_order.len() as f64,
        );
        trace.host_proxy_metrics.insert(
            "normalized_page_events".into(),
            shape
                .page_trace_regions
                .iter()
                .map(|region| region.event_budget)
                .sum::<usize>() as f64,
        );
    }
}
