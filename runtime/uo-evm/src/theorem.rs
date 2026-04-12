use crate::controller::controller_observer_for_call;
use uo_core::ir::CompiledFunction;
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::{ExecutionTrace, OutputShape, PublicOutcomeTrace, TheoremTrace, Value};

pub fn build_theorem_trace(
    function: &CompiledFunction,
    manifest_entry: &EntrypointManifest,
    objects: &[StateObjectManifest],
    args: &[Value],
    return_value: &Option<Value>,
    aborted: bool,
    gas_used: u64,
) -> TheoremTrace {
    let output_shape = output_shape_of(return_value);
    let observer = controller_observer_for_call(
        &function.signature,
        manifest_entry,
        objects,
        args,
        output_shape.return_length,
    );
    let public_outcome = PublicOutcomeTrace {
        entrypoint_id: function.signature.clone(),
        public_args: public_args_of(function, manifest_entry, args),
        termination_status: !aborted,
        output_shape,
        gas_used,
    };
    TheoremTrace {
        public_outcome: Some(public_outcome),
        boundary_schedule: observer.boundary_schedule,
        controller_shape: Some(observer.controller_shape),
        normalized_micro_trace: Some(observer.normalized_micro_trace),
    }
}

fn public_args_of(
    function: &CompiledFunction,
    manifest_entry: &EntrypointManifest,
    args: &[Value],
) -> Vec<String> {
    function
        .params
        .iter()
        .zip(args)
        .enumerate()
        .filter(|(index, _)| !manifest_entry.secret_args.contains(index))
        .map(|(_, ((name, _), value))| format!("{name}={value}"))
        .collect()
}

fn output_shape_of(return_value: &Option<Value>) -> OutputShape {
    match return_value {
        Some(value) => OutputShape {
            return_present: true,
            return_length: value.canonical_bytes().len(),
        },
        None => OutputShape::default(),
    }
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
            shape.page_trace_regions
                .iter()
                .map(|region| region.event_budget)
                .sum::<usize>() as f64,
        );
    }
}
