use uo_core::manifest::{EntrypointManifest, OramManifest, StateObjectManifest};
use uo_core::{
    BoundaryDirection, BoundaryEvent, ControllerPageBudget, ControllerPhase, ExitEvent,
    NormalizedMicroTrace, NormalizedPageEvent, PageEventKind, SgxControllerShapeTrace, Value,
};

struct OramLeakageView<'a> {
    oram: &'a OramManifest,
    accesses_per_entrypoint: usize,
}

#[derive(Clone, Debug)]
pub struct ControllerObserver {
    pub boundary_schedule: Vec<BoundaryEvent>,
    pub controller_shape: SgxControllerShapeTrace,
    pub normalized_micro_trace: NormalizedMicroTrace,
}

pub fn controller_observer_for_call(
    entrypoint: &str,
    manifest_entry: &EntrypointManifest,
    objects: &[StateObjectManifest],
    args: &[Value],
    output_len: usize,
) -> ControllerObserver {
    let oram_views = oram_leakage_views(objects, manifest_entry);
    let controller_shape = controller_shape_of(&oram_views);
    let total_accesses = total_oram_accesses(&oram_views);
    ControllerObserver {
        boundary_schedule: boundary_schedule_of(entrypoint, args, output_len, total_accesses),
        normalized_micro_trace: normalized_micro_trace_of(&controller_shape),
        controller_shape,
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
