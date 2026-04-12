use uo_core::ir::CompiledFunction;
use uo_core::manifest::{EntrypointManifest, OramManifest, StateObjectManifest};
use uo_core::{
    BoundaryDirection, BoundaryEvent, ControllerPageBudget, ControllerPhase, ExecutionTrace,
    ExitEvent, NormalizedMicroTrace, NormalizedPageEvent, OutputShape, PageEventKind,
    PublicOutcomeTrace, SgxControllerShapeTrace, TheoremTrace, Value,
};

struct OramLeakageView<'a> {
    oram: &'a OramManifest,
    accesses_per_entrypoint: usize,
}

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
    let public_outcome = PublicOutcomeTrace {
        entrypoint_id: function.signature.clone(),
        public_args: public_args_of(function, manifest_entry, args),
        termination_status: !aborted,
        output_shape: output_shape.clone(),
        gas_used,
    };
    let oram_views = oram_leakage_views(objects, manifest_entry);
    let controller_shape = controller_shape_of(&oram_views);
    let boundary_schedule = boundary_schedule_of(
        &function.signature,
        args,
        output_shape.return_length,
        total_oram_accesses(&oram_views),
    );
    let normalized_micro_trace = normalized_micro_trace_of(&controller_shape);
    TheoremTrace {
        public_outcome: Some(public_outcome),
        boundary_schedule,
        controller_shape: Some(controller_shape),
        normalized_micro_trace: Some(normalized_micro_trace),
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

fn oram_leakage_views<'a>(
    objects: &'a [StateObjectManifest],
    manifest_entry: &'a EntrypointManifest,
) -> Vec<OramLeakageView<'a>> {
    objects
        .iter()
        .filter_map(|object| {
            let oram = object.oram.as_ref()?;
            Some(OramLeakageView {
                oram,
                accesses_per_entrypoint: manifest_entry.oram_accesses.get(&object.id).copied().unwrap_or(0),
            })
        })
        .collect()
}

fn total_oram_accesses(oram_views: &[OramLeakageView<'_>]) -> usize {
    oram_views
        .iter()
        .map(|view| view.accesses_per_entrypoint)
        .sum()
}

fn controller_access_phase_plan(oram: &OramManifest) -> Vec<ControllerPhase> {
    let mut phases = Vec::new();
    phases.push(ControllerPhase::StageRequest);
    phases.extend(std::iter::repeat_n(
        ControllerPhase::DescendPositionMap,
        oram.recursion_depth,
    ));
    phases.extend([
        ControllerPhase::LoadMetadata,
        ControllerPhase::FetchPath,
        ControllerPhase::ScanStash,
        ControllerPhase::RewritePath,
    ]);
    phases.extend(std::iter::repeat_n(
        ControllerPhase::AscendPositionMap,
        oram.recursion_depth,
    ));
    phases
}

fn controller_phase_order(oram_views: &[OramLeakageView<'_>]) -> Vec<ControllerPhase> {
    let mut phases = vec![ControllerPhase::EnclaveEnter];
    for view in oram_views {
        let access_plan = controller_access_phase_plan(view.oram);
        for _ in 0..view.accesses_per_entrypoint {
            phases.extend(access_plan.iter().copied());
        }
    }
    phases.extend([
        ControllerPhase::SealPersistentState,
        ControllerPhase::EnclaveExit,
    ]);
    phases
}

fn page_trace_regions(oram_views: &[OramLeakageView<'_>]) -> Vec<ControllerPageBudget> {
    let metadata = oram_views
        .iter()
        .map(|view| view.accesses_per_entrypoint * view.oram.metadata_pages_per_access)
        .sum();
    let position_map = oram_views
        .iter()
        .map(|view| view.accesses_per_entrypoint * view.oram.recursion_depth)
        .sum();
    let path = oram_views
        .iter()
        .map(|view| view.accesses_per_entrypoint * view.oram.buckets_per_access)
        .sum();
    let stash = oram_views
        .iter()
        .map(|view| view.accesses_per_entrypoint * view.oram.stash_bound)
        .sum();
    vec![
        ControllerPageBudget {
            page_kind: "metadata".into(),
            event_budget: metadata,
        },
        ControllerPageBudget {
            page_kind: "position_map".into(),
            event_budget: position_map,
        },
        ControllerPageBudget {
            page_kind: "path".into(),
            event_budget: path,
        },
        ControllerPageBudget {
            page_kind: "stash".into(),
            event_budget: stash,
        },
    ]
}

fn workset_regions(oram_views: &[OramLeakageView<'_>]) -> Vec<ControllerPageBudget> {
    let metadata = oram_views
        .iter()
        .map(|view| view.oram.metadata_pages_per_access)
        .max()
        .unwrap_or_default();
    let position_map = oram_views
        .iter()
        .map(|view| view.oram.recursion_depth)
        .max()
        .unwrap_or_default();
    let path = oram_views
        .iter()
        .map(|view| view.oram.buckets_per_access)
        .max()
        .unwrap_or_default();
    let stash = oram_views
        .iter()
        .map(|view| view.oram.stash_bound)
        .max()
        .unwrap_or_default();
    vec![
        ControllerPageBudget {
            page_kind: "metadata".into(),
            event_budget: metadata,
        },
        ControllerPageBudget {
            page_kind: "position_map".into(),
            event_budget: position_map,
        },
        ControllerPageBudget {
            page_kind: "path".into(),
            event_budget: path,
        },
        ControllerPageBudget {
            page_kind: "stash".into(),
            event_budget: stash,
        },
    ]
}

fn controller_shape_of(oram_views: &[OramLeakageView<'_>]) -> SgxControllerShapeTrace {
    let total_accesses = total_oram_accesses(oram_views);
    let page_trace_regions = page_trace_regions(oram_views);
    let workset_regions = workset_regions(oram_views);
    let controller_phase_order = controller_phase_order(oram_views);
    let page_trace_budget = page_trace_regions
        .iter()
        .map(|region| region.event_budget)
        .sum::<usize>();
    SgxControllerShapeTrace {
        boundary_event_budget: 2 * (total_accesses + 1),
        controller_phase_order: controller_phase_order.clone(),
        page_trace_regions,
        workset_regions,
        exit_trace_budget: controller_phase_order.len() + total_accesses + 1,
        shared_resource_budget: controller_phase_order.len() + page_trace_budget,
        recursive_position_map_depth: oram_views
            .iter()
            .map(|view| view.oram.recursion_depth)
            .max()
            .unwrap_or_default(),
        stash_bound: oram_views
            .iter()
            .map(|view| view.oram.stash_bound)
            .max()
            .unwrap_or_default(),
    }
}

fn boundary_schedule_of(
    entrypoint: &str,
    args: &[Value],
    output_len: usize,
    total_accesses: usize,
) -> Vec<BoundaryEvent> {
    let total_input_len = args.iter().map(|arg| arg.canonical_bytes().len()).sum();
    let mut schedule = Vec::with_capacity(2 * (total_accesses + 1));
    schedule.push(BoundaryEvent {
        direction: BoundaryDirection::Enter,
        api_id: entrypoint.into(),
        input_len: total_input_len,
        output_len: 0,
    });
    for _ in 0..total_accesses {
        schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Exit,
            api_id: "oram_access".into(),
            input_len: 0,
            output_len: 0,
        });
        schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Enter,
            api_id: "oram_access".into(),
            input_len: 0,
            output_len: 0,
        });
    }
    schedule.push(BoundaryEvent {
        direction: BoundaryDirection::Exit,
        api_id: entrypoint.into(),
        input_len: 0,
        output_len,
    });
    schedule
}

fn normalized_micro_trace_of(shape: &SgxControllerShapeTrace) -> NormalizedMicroTrace {
    let mut page_trace = Vec::new();
    for region in &shape.page_trace_regions {
        for index in 0..region.event_budget {
            page_trace.push(NormalizedPageEvent {
                page_kind: region.page_kind.clone(),
                kind: if index % 2 == 0 {
                    PageEventKind::FaultIn
                } else {
                    PageEventKind::EvictOut
                },
            });
        }
    }
    let exit_pattern = (0..shape.exit_trace_budget)
        .map(|index| {
            if index + 1 == shape.exit_trace_budget {
                ExitEvent::Terminate
            } else if index % 2 == 0 {
                ExitEvent::Resume
            } else {
                ExitEvent::InterruptExit
            }
        })
        .collect();
    let shared_resource_pattern = vec!["shared_resource_tick".into(); shape.shared_resource_budget];
    NormalizedMicroTrace {
        page_trace,
        exit_pattern,
        shared_resource_pattern,
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
