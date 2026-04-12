use crate::oram::OramParameters;
use anyhow::{bail, Result};
use std::collections::BTreeMap;
use uo_core::ir::CompiledFunction;
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::trace::{LogicalEvent, PhysicalReadEvent, PhysicalWriteEvent};
use uo_core::{
    BoundaryDirection, BoundaryEvent, ControllerPageBudget, ControllerPhase, OutputShape,
    PublicOutcomeTrace, RuntimeControllerCertificate, RuntimeOramAccessWitness,
    SgxControllerShapeTrace, TheoremTrace, Value,
};
use uo_store::StoreExecutionMetrics;

const METADATA_REGION: &str = "metadata";
const POSITION_MAP_REGION: &str = "position_map";
const PATH_REGION: &str = "path";
const STASH_REGION: &str = "stash";

#[derive(Clone, Debug)]
pub(crate) struct CallTraceBundle {
    pub logical_accesses: Vec<LogicalEvent>,
    pub logical_writes: Vec<LogicalEvent>,
    pub physical_reads: Vec<PhysicalReadEvent>,
    pub physical_writes: Vec<PhysicalWriteEvent>,
    pub theorem_trace: TheoremTrace,
    pub controller_certificate: RuntimeControllerCertificate,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct ObservedOramAccess {
    object_id: u32,
    parameters: OramParameters,
}

#[derive(Clone, Debug, Default)]
pub(crate) struct CallRecorder {
    entrypoint: String,
    logical_accesses: Vec<LogicalEvent>,
    logical_writes: Vec<LogicalEvent>,
    physical_reads: Vec<PhysicalReadEvent>,
    physical_writes: Vec<PhysicalWriteEvent>,
    metrics: StoreExecutionMetrics,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_phase_order: Vec<ControllerPhase>,
    page_trace_regions: BTreeMap<&'static str, usize>,
    workset_regions: BTreeMap<&'static str, usize>,
    total_oram_accesses: usize,
    observed_oram_schedule: Vec<ObservedOramAccess>,
    observed_oram_accesses: BTreeMap<u32, usize>,
    recursive_position_map_depth: usize,
    stash_bound: usize,
}

impl CallRecorder {
    pub(crate) fn begin(entrypoint: &str, args: &[Value]) -> Self {
        let total_input_len = args.iter().map(|arg| arg.canonical_bytes().len()).sum();
        let mut recorder = Self {
            entrypoint: entrypoint.into(),
            ..Self::default()
        };
        recorder.page_trace_regions.insert(METADATA_REGION, 0);
        recorder.page_trace_regions.insert(POSITION_MAP_REGION, 0);
        recorder.page_trace_regions.insert(PATH_REGION, 0);
        recorder.page_trace_regions.insert(STASH_REGION, 0);
        recorder.workset_regions.insert(METADATA_REGION, 0);
        recorder.workset_regions.insert(POSITION_MAP_REGION, 0);
        recorder.workset_regions.insert(PATH_REGION, 0);
        recorder.workset_regions.insert(STASH_REGION, 0);
        recorder.boundary_schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Enter,
            api_id: entrypoint.into(),
            input_len: total_input_len,
            output_len: 0,
        });
        recorder
            .controller_phase_order
            .push(ControllerPhase::EnclaveEnter);
        recorder
    }

    pub(crate) fn logical_read(
        &mut self,
        kind: &str,
        object: &str,
        detail: impl Into<String>,
    ) {
        self.metrics.logical_reads += 1;
        self.logical_accesses.push(LogicalEvent {
            kind: kind.into(),
            object: object.into(),
            detail: detail.into(),
        });
    }

    pub(crate) fn logical_write(
        &mut self,
        kind: &str,
        object: &str,
        detail: impl Into<String>,
    ) {
        self.metrics.logical_writes += 1;
        self.logical_writes.push(LogicalEvent {
            kind: kind.into(),
            object: object.into(),
            detail: detail.into(),
        });
    }

    pub(crate) fn physical_read(
        &mut self,
        object: &str,
        location: impl Into<String>,
        len: usize,
    ) {
        self.metrics.physical_reads += 1;
        self.physical_reads.push(PhysicalReadEvent {
            object: object.into(),
            location: location.into(),
            len,
        });
    }

    pub(crate) fn physical_write(&mut self, event: PhysicalWriteEvent) {
        self.metrics.physical_writes += 1;
        if event.new.iter().all(|byte| *byte == 0) {
            self.metrics.zero_writes += 1;
        }
        self.physical_writes.push(event);
    }

    pub(crate) fn record_oram_access(
        &mut self,
        object_id: u32,
        parameters: &OramParameters,
    ) {
        self.total_oram_accesses += 1;
        self.observed_oram_schedule.push(ObservedOramAccess {
            object_id,
            parameters: parameters.clone(),
        });
        *self.observed_oram_accesses.entry(object_id).or_default() += 1;
        self.boundary_schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Exit,
            api_id: "oram_access".into(),
            input_len: 0,
            output_len: 0,
        });
        self.boundary_schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Enter,
            api_id: "oram_access".into(),
            input_len: 0,
            output_len: 0,
        });
        self.controller_phase_order.push(ControllerPhase::StageRequest);
        self.controller_phase_order.extend(std::iter::repeat_n(
            ControllerPhase::DescendPositionMap,
            parameters.recursion_depth,
        ));
        self.controller_phase_order.extend([
            ControllerPhase::LoadMetadata,
            ControllerPhase::FetchPath,
            ControllerPhase::ScanStash,
            ControllerPhase::RewritePath,
        ]);
        self.controller_phase_order.extend(std::iter::repeat_n(
            ControllerPhase::AscendPositionMap,
            parameters.recursion_depth,
        ));
        self.bump_region(METADATA_REGION, parameters.metadata_pages_per_access);
        self.bump_region(POSITION_MAP_REGION, parameters.recursion_depth);
        self.bump_region(PATH_REGION, parameters.buckets_per_access);
        self.bump_region(STASH_REGION, parameters.stash_bound);
        self.bump_workset(METADATA_REGION, parameters.metadata_pages_per_access);
        self.bump_workset(POSITION_MAP_REGION, parameters.recursion_depth);
        self.bump_workset(PATH_REGION, parameters.buckets_per_access);
        self.bump_workset(STASH_REGION, parameters.stash_bound);
        self.recursive_position_map_depth = self
            .recursive_position_map_depth
            .max(parameters.recursion_depth);
        self.stash_bound = self.stash_bound.max(parameters.stash_bound);
    }

    fn bump_region(&mut self, region: &'static str, delta: usize) {
        let budget = self.page_trace_regions.entry(region).or_default();
        *budget += delta;
    }

    fn bump_workset(&mut self, region: &'static str, budget: usize) {
        let current = self.workset_regions.entry(region).or_default();
        *current = (*current).max(budget);
    }

    pub(crate) fn finish(
        mut self,
        function: &CompiledFunction,
        manifest_entry: &EntrypointManifest,
        manifest_objects: &[StateObjectManifest],
        args: &[Value],
        return_value: &Option<Value>,
        aborted: bool,
        gas_used: u64,
    ) -> Result<CallTraceBundle> {
        self.assert_manifest_exactness(manifest_entry)?;
        self.assert_oram_parameter_exactness(manifest_objects)?;
        let entry_input_len = args.iter().map(|arg| arg.canonical_bytes().len()).sum();
        let output_shape = output_shape_of(return_value);
        self.controller_phase_order.extend([
            ControllerPhase::SealPersistentState,
            ControllerPhase::EnclaveExit,
        ]);
        self.boundary_schedule.push(BoundaryEvent {
            direction: BoundaryDirection::Exit,
            api_id: self.entrypoint.clone(),
            input_len: 0,
            output_len: output_shape.return_length,
        });
        let controller_shape = self.controller_shape();
        let public_outcome = PublicOutcomeTrace {
            entrypoint_id: function.signature.clone(),
            public_args: public_args_of(function, manifest_entry, args),
            termination_status: !aborted,
            output_shape,
            gas_used,
        };
        let controller_certificate =
            controller_certificate(entry_input_len, &self.observed_oram_schedule);
        let theorem_trace = TheoremTrace {
            public_outcome: Some(public_outcome.clone()),
            boundary_schedule: self.boundary_schedule,
            controller_shape: Some(controller_shape.clone()),
            normalized_micro_trace: Some(controller_shape.normalized_micro_trace()),
        };
        let expected_theorem_trace = controller_certificate.theorem_trace(public_outcome);
        if theorem_trace != expected_theorem_trace {
            bail!(
                "runtime theorem trace drifted from independent public observer reconstruction"
            );
        }
        Ok(CallTraceBundle {
            logical_accesses: self.logical_accesses,
            logical_writes: self.logical_writes,
            physical_reads: self.physical_reads,
            physical_writes: self.physical_writes,
            theorem_trace: expected_theorem_trace,
            controller_certificate,
        })
    }

    pub(crate) fn metrics(&self) -> &StoreExecutionMetrics {
        &self.metrics
    }

    pub(crate) fn physical_write_count(&self) -> usize {
        self.physical_writes.len()
    }

    fn assert_manifest_exactness(&self, manifest_entry: &EntrypointManifest) -> Result<()> {
        for (object_id, expected) in &manifest_entry.oram_accesses {
            let observed = self.observed_oram_accesses.get(object_id).copied().unwrap_or(0);
            if observed != *expected {
                bail!(
                    "runtime ORAM access count mismatch for object {}: observed {}, manifest {}",
                    object_id,
                    observed,
                    expected
                );
            }
        }
        for (object_id, observed) in &self.observed_oram_accesses {
            if !manifest_entry.oram_accesses.contains_key(object_id) && *observed != 0 {
                bail!(
                    "runtime observed unexpected ORAM accesses for object {}: {}",
                    object_id,
                    observed
                );
            }
        }
        Ok(())
    }

    fn assert_oram_parameter_exactness(
        &self,
        manifest_objects: &[StateObjectManifest],
    ) -> Result<()> {
        for access in &self.observed_oram_schedule {
            let manifest_object = manifest_objects
                .iter()
                .find(|object| object.id == access.object_id)
                .ok_or_else(|| anyhow::anyhow!(
                    "manifest object missing for observed ORAM access {}",
                    access.object_id
                ))?;
            let manifest_oram = manifest_object.oram.as_ref().ok_or_else(|| {
                anyhow::anyhow!(
                    "manifest object {} is missing ORAM parameters",
                    access.object_id
                )
            })?;
            assert_oram_field_eq(
                access.object_id,
                "scheme",
                access.parameters.scheme.as_str(),
                manifest_oram.scheme.as_str(),
            )?;
            assert_oram_field_eq(
                access.object_id,
                "block_size",
                access.parameters.block_size,
                manifest_oram.block_size,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "bucket_size",
                access.parameters.bucket_size,
                manifest_oram.bucket_size,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "bucket_count",
                access.parameters.bucket_count,
                manifest_oram.bucket_count,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "blocks_per_bucket",
                access.parameters.blocks_per_bucket,
                manifest_oram.blocks_per_bucket,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "tree_height",
                access.parameters.tree_height,
                manifest_oram.tree_height,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "stash_bound",
                access.parameters.stash_bound,
                manifest_oram.stash_bound,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "recursion_depth",
                access.parameters.recursion_depth,
                manifest_oram.recursion_depth,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "metadata_pages",
                access.parameters.metadata_pages,
                manifest_oram.metadata_pages,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "metadata_pages_per_access",
                access.parameters.metadata_pages_per_access,
                manifest_oram.metadata_pages_per_access,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "buckets_per_access",
                access.parameters.buckets_per_access,
                manifest_oram.buckets_per_access,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "accesses_per_call",
                access.parameters.accesses_per_call,
                manifest_oram.accesses_per_call,
            )?;
        }
        Ok(())
    }

    fn controller_shape(&self) -> SgxControllerShapeTrace {
        let page_trace_regions = controller_region_budgets(&self.page_trace_regions);
        let workset_regions = controller_region_budgets(&self.workset_regions);
        let page_trace_budget = page_trace_regions
            .iter()
            .map(|region| region.event_budget)
            .sum::<usize>();
        SgxControllerShapeTrace {
            boundary_event_budget: self.boundary_schedule.len(),
            controller_phase_order: self.controller_phase_order.clone(),
            page_trace_regions,
            workset_regions,
            exit_trace_budget: self.controller_phase_order.len() + self.total_oram_accesses + 1,
            shared_resource_budget: self.controller_phase_order.len() + page_trace_budget,
            recursive_position_map_depth: self.recursive_position_map_depth,
            stash_bound: self.stash_bound,
        }
    }
}

fn controller_certificate(
    entry_input_len: usize,
    observed_oram_schedule: &[ObservedOramAccess],
) -> RuntimeControllerCertificate {
    RuntimeControllerCertificate {
        entry_input_len,
        observed_oram_accesses: observed_oram_schedule
            .iter()
            .map(|access| RuntimeOramAccessWitness {
                object_id: access.object_id,
                scheme: access.parameters.scheme.clone(),
                metadata_pages_per_access: access.parameters.metadata_pages_per_access,
                buckets_per_access: access.parameters.buckets_per_access,
                recursion_depth: access.parameters.recursion_depth,
                stash_bound: access.parameters.stash_bound,
            })
            .collect(),
    }
}

fn assert_oram_field_eq<T>(
    object_id: u32,
    field: &str,
    observed: T,
    manifest: T,
) -> Result<()>
where
    T: PartialEq + std::fmt::Display,
{
    if observed != manifest {
        bail!(
            "runtime ORAM parameter mismatch for object {} field {}: observed {}, manifest {}",
            object_id,
            field,
            observed,
            manifest
        );
    }
    Ok(())
}

fn controller_region_budgets(regions: &BTreeMap<&'static str, usize>) -> Vec<ControllerPageBudget> {
    [
        METADATA_REGION,
        POSITION_MAP_REGION,
        PATH_REGION,
        STASH_REGION,
    ]
    .into_iter()
    .map(|region| ControllerPageBudget {
        page_kind: region.into(),
        event_budget: regions.get(region).copied().unwrap_or_default(),
    })
    .collect()
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
