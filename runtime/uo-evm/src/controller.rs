use crate::oram::OramParameters;
use anyhow::{bail, Result};
use uo_core::manifest::{EntrypointManifest, StateObjectManifest};
use uo_core::trace::{LogicalEvent, PhysicalReadEvent, PhysicalWriteEvent, WriteClass};
pub(crate) use uo_core::PublicCallSummary;
use uo_core::{
    BoundaryEvent, ControllerPageBudget, ControllerPhase, FixedBoxBuilder, OutputShape,
    PublicOutcomeTrace, ReturnPolicy, RuntimeControllerObserverCertificate,
    RuntimeObservedOramAccessWitness, RuntimeOramAccessWitness, RuntimeOramLeafWitness,
    RuntimePathOramTransitionWitness, RuntimePublicCallTraceBundle, Value,
};
use uo_store::StoreExecutionMetrics;

const METADATA_REGION: &str = "metadata";
const POSITION_MAP_REGION: &str = "position_map";
const PATH_REGION: &str = "path";
const STASH_REGION: &str = "stash";

#[derive(Clone, Copy, Debug)]
enum ControllerRegion {
    Metadata,
    PositionMap,
    Path,
    Stash,
}

impl ControllerRegion {
    fn name(self) -> &'static str {
        match self {
            Self::Metadata => METADATA_REGION,
            Self::PositionMap => POSITION_MAP_REGION,
            Self::Path => PATH_REGION,
            Self::Stash => STASH_REGION,
        }
    }
}

const CONTROLLER_REGIONS: [ControllerRegion; 4] = [
    ControllerRegion::Metadata,
    ControllerRegion::PositionMap,
    ControllerRegion::Path,
    ControllerRegion::Stash,
];

#[derive(Debug, Default)]
struct ControllerRegionCounters {
    metadata: usize,
    position_map: usize,
    path: usize,
    stash: usize,
}

impl ControllerRegionCounters {
    fn get(&self, region: ControllerRegion) -> usize {
        match region {
            ControllerRegion::Metadata => self.metadata,
            ControllerRegion::PositionMap => self.position_map,
            ControllerRegion::Path => self.path,
            ControllerRegion::Stash => self.stash,
        }
    }

    fn get_mut(&mut self, region: ControllerRegion) -> &mut usize {
        match region {
            ControllerRegion::Metadata => &mut self.metadata,
            ControllerRegion::PositionMap => &mut self.position_map,
            ControllerRegion::Path => &mut self.path,
            ControllerRegion::Stash => &mut self.stash,
        }
    }

    fn bump(&mut self, region: ControllerRegion, delta: usize) {
        *self.get_mut(region) += delta;
    }

    fn max_with(&mut self, region: ControllerRegion, budget: usize) {
        let current = self.get_mut(region);
        *current = (*current).max(budget);
    }

    fn budgets(&self) -> Result<Box<[ControllerPageBudget]>> {
        let mut budgets = FixedBoxBuilder::new(CONTROLLER_REGIONS.len());
        for region in CONTROLLER_REGIONS {
            budgets.push(ControllerPageBudget {
                page_kind: region.name().into(),
                event_budget: self.get(region),
            })?;
        }
        budgets.finish()
    }
}

#[derive(Debug, Default)]
pub(crate) struct CallRecorder {
    entrypoint: String,
    logical_accesses: Vec<LogicalEvent>,
    logical_writes: Vec<LogicalEvent>,
    physical_reads: Vec<PhysicalReadEvent>,
    physical_writes: Vec<PhysicalWriteEvent>,
    metrics: StoreExecutionMetrics,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_phase_order: Vec<ControllerPhase>,
    page_trace_regions: ControllerRegionCounters,
    workset_regions: ControllerRegionCounters,
    total_oram_accesses: usize,
    observed_oram_schedule: Vec<RuntimeObservedOramAccessWitness>,
    path_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,
    path_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,
    recursive_position_map_depth: usize,
    stash_bound: usize,
}

impl CallRecorder {
    #[cfg(test)]
    pub(crate) fn begin(entrypoint: &str, args: &[Value]) -> Self {
        let total_input_len = args.iter().map(Value::canonical_len).sum();
        Self::begin_with_input_len(entrypoint, total_input_len)
    }

    pub(crate) fn begin_with_input_len(entrypoint: &str, total_input_len: usize) -> Self {
        let mut recorder = Self {
            entrypoint: entrypoint.into(),
            ..Self::default()
        };
        recorder
            .boundary_schedule
            .push(BoundaryEvent::enter(entrypoint, total_input_len));
        recorder
            .controller_phase_order
            .push(ControllerPhase::EnclaveEnter);
        recorder
    }

    pub(crate) fn logical_read(&mut self, kind: &str, object: &str, detail: impl Into<String>) {
        self.metrics.logical_reads += 1;
        self.logical_accesses.push(LogicalEvent {
            kind: kind.into(),
            object: object.into(),
            detail: detail.into(),
        });
    }

    pub(crate) fn logical_write(&mut self, kind: &str, object: &str, detail: impl Into<String>) {
        self.metrics.logical_writes += 1;
        self.logical_writes.push(LogicalEvent {
            kind: kind.into(),
            object: object.into(),
            detail: detail.into(),
        });
    }

    pub(crate) fn physical_read(&mut self, object: &str, location: impl Into<String>, len: usize) {
        self.metrics.physical_reads += 1;
        self.physical_reads.push(PhysicalReadEvent {
            object: object.into(),
            location: location.into(),
            len,
        });
    }

    pub(crate) fn physical_write(&mut self, event: PhysicalWriteEvent) {
        self.metrics.physical_writes += 1;
        self.physical_writes.push(event);
    }

    pub(crate) fn raw_physical_write_from_buffers(
        &mut self,
        object: &str,
        location: impl Into<String>,
        old: &[u8],
        new: &[u8],
    ) {
        self.metrics.physical_writes += 1;
        let event = PhysicalWriteEvent::from_buffers(object, location, old, new);
        if matches!(event.class, WriteClass::Same | WriteClass::Clear) {
            self.metrics.zero_writes += 1;
        }
        self.physical_writes.push(event);
    }

    pub(crate) fn add_zero_writes(&mut self, count: usize) {
        self.metrics.zero_writes += count;
    }

    pub(crate) fn record_oram_access(&mut self, object_id: u32, parameters: &OramParameters) {
        self.total_oram_accesses += 1;
        self.observed_oram_schedule
            .push(RuntimeObservedOramAccessWitness::new(
                object_id,
                parameters.scheme.clone(),
                parameters.block_size,
                parameters.bucket_size,
                parameters.bucket_count,
                parameters.blocks_per_bucket,
                parameters.tree_height,
                parameters.stash_bound,
                parameters.recursion_depth,
                parameters.metadata_pages,
                parameters.metadata_pages_per_access,
                parameters.buckets_per_access,
                parameters.accesses_per_call,
            ));
        self.boundary_schedule
            .push(BoundaryEvent::exit("oram_access", 0));
        self.boundary_schedule
            .push(BoundaryEvent::enter("oram_access", 0));
        self.controller_phase_order
            .push(ControllerPhase::StageRequest);
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
        self.bump_region(
            ControllerRegion::Metadata,
            parameters.metadata_pages_per_access,
        );
        self.bump_region(ControllerRegion::PositionMap, parameters.recursion_depth);
        self.bump_region(ControllerRegion::Path, parameters.buckets_per_access);
        self.bump_region(ControllerRegion::Stash, parameters.stash_bound);
        self.bump_workset(
            ControllerRegion::Metadata,
            parameters.metadata_pages_per_access,
        );
        self.bump_workset(ControllerRegion::PositionMap, parameters.recursion_depth);
        self.bump_workset(ControllerRegion::Path, parameters.buckets_per_access);
        self.bump_workset(ControllerRegion::Stash, parameters.stash_bound);
        self.recursive_position_map_depth = self
            .recursive_position_map_depth
            .max(parameters.recursion_depth);
        self.stash_bound = self.stash_bound.max(parameters.stash_bound);
    }

    pub(crate) fn record_path_oram_leaf_access(
        &mut self,
        object_id: u32,
        object_name: &str,
        bucket_count: usize,
        leaf: usize,
    ) {
        self.path_oram_leaf_schedule.push(RuntimeOramLeafWitness {
            object_id,
            object_name: object_name.into(),
            bucket_count,
            leaf,
        });
    }

    pub(crate) fn record_path_oram_leaf_state_transition(
        &mut self,
        transition: RuntimePathOramTransitionWitness,
    ) {
        self.path_oram_leaf_state_transitions.push(transition);
    }

    fn bump_region(&mut self, region: ControllerRegion, delta: usize) {
        self.page_trace_regions.bump(region, delta);
    }

    fn bump_workset(&mut self, region: ControllerRegion, budget: usize) {
        self.workset_regions.max_with(region, budget);
    }

    pub(crate) fn finish(
        mut self,
        manifest_entry: &EntrypointManifest,
        manifest_objects: &[StateObjectManifest],
        public_call: PublicCallSummary,
        output_shape: OutputShape,
        return_payload: Option<String>,
        aborted: bool,
        gas_used: u64,
    ) -> Result<(usize, RuntimePublicCallTraceBundle)> {
        self.assert_manifest_exactness(manifest_entry)?;
        self.assert_oram_parameter_exactness(manifest_objects)?;
        self.controller_phase_order.extend([
            ControllerPhase::SealPersistentState,
            ControllerPhase::EnclaveExit,
        ]);
        self.boundary_schedule.push(BoundaryEvent::exit(
            self.entrypoint.clone(),
            output_shape.return_length,
        ));
        let entry_input_len = public_call.entry_input_len();
        let public_outcome = PublicOutcomeTrace::new(
            self.entrypoint.clone(),
            public_call.into_public_args(),
            !aborted,
            output_shape,
            gas_used,
        )
        .with_host_visibility(manifest_entry, return_payload);
        let controller_observer =
            RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(
                public_outcome,
                self.boundary_schedule.into_boxed_slice(),
                self.controller_phase_order.into_boxed_slice(),
                self.page_trace_regions.budgets()?,
                self.workset_regions.budgets()?,
                self.total_oram_accesses,
                self.recursive_position_map_depth,
                self.stash_bound,
                entry_input_len,
                observed_oram_access_witnesses(&self.observed_oram_schedule),
            )?;
        let zero_writes = self.metrics.zero_writes;
        Ok((
            zero_writes,
            RuntimePublicCallTraceBundle::new(
                self.logical_accesses.into_boxed_slice(),
                self.logical_writes.into_boxed_slice(),
                self.physical_reads.into_boxed_slice(),
                self.physical_writes.into_boxed_slice(),
                controller_observer.theorem_trace(),
                controller_observer.controller_certificate().clone(),
                self.path_oram_leaf_schedule.into_boxed_slice(),
                self.path_oram_leaf_state_transitions.into_boxed_slice(),
            ),
        ))
    }

    pub(crate) fn metrics(&self) -> &StoreExecutionMetrics {
        &self.metrics
    }

    pub(crate) fn physical_write_count(&self) -> usize {
        self.physical_writes.len()
    }

    fn assert_manifest_exactness(&self, manifest_entry: &EntrypointManifest) -> Result<()> {
        for (object_id, expected) in &manifest_entry.oram_accesses {
            let observed = self.observed_oram_access_count(*object_id);
            if observed != *expected {
                bail!(
                    "runtime ORAM access count mismatch for object {}: observed {}, manifest {}",
                    object_id,
                    observed,
                    expected
                );
            }
        }
        for access in &self.observed_oram_schedule {
            if !manifest_entry.oram_accesses.contains_key(&access.object_id) {
                bail!(
                    "runtime observed unexpected ORAM accesses for object {}: {}",
                    access.object_id,
                    self.observed_oram_access_count(access.object_id)
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
                .ok_or_else(|| {
                    anyhow::anyhow!(
                        "manifest object missing for observed ORAM access {}",
                        access.object_id
                    )
                })?;
            let manifest_oram = manifest_object.oram.as_ref().ok_or_else(|| {
                anyhow::anyhow!(
                    "manifest object {} is missing ORAM parameters",
                    access.object_id
                )
            })?;
            assert_oram_field_eq(
                access.object_id,
                "scheme",
                access.scheme.as_str(),
                manifest_oram.scheme.as_str(),
            )?;
            assert_oram_field_eq(
                access.object_id,
                "block_size",
                access.block_size,
                manifest_oram.block_size,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "bucket_size",
                access.bucket_size,
                manifest_oram.bucket_size,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "bucket_count",
                access.bucket_count,
                manifest_oram.bucket_count,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "blocks_per_bucket",
                access.blocks_per_bucket,
                manifest_oram.blocks_per_bucket,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "tree_height",
                access.tree_height,
                manifest_oram.tree_height,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "stash_bound",
                access.stash_bound,
                manifest_oram.stash_bound,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "recursion_depth",
                access.recursion_depth,
                manifest_oram.recursion_depth,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "metadata_pages",
                access.metadata_pages,
                manifest_oram.metadata_pages,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "metadata_pages_per_access",
                access.metadata_pages_per_access,
                manifest_oram.metadata_pages_per_access,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "buckets_per_access",
                access.buckets_per_access,
                manifest_oram.buckets_per_access,
            )?;
            assert_oram_field_eq(
                access.object_id,
                "accesses_per_call",
                access.accesses_per_call,
                manifest_oram.accesses_per_call,
            )?;
        }
        Ok(())
    }

    fn observed_oram_access_count(&self, object_id: u32) -> usize {
        self.observed_oram_schedule
            .iter()
            .filter(|access| access.object_id == object_id)
            .count()
    }
}

fn observed_oram_access_witnesses(
    observed_oram_schedule: &[RuntimeObservedOramAccessWitness],
) -> impl Iterator<Item = RuntimeOramAccessWitness> + '_ {
    observed_oram_schedule
        .iter()
        .map(RuntimeObservedOramAccessWitness::controller_access_witness)
}

fn assert_oram_field_eq<T>(object_id: u32, field: &str, observed: T, manifest: T) -> Result<()>
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

pub(crate) fn output_shape_of(
    manifest_entry: &EntrypointManifest,
    return_value: &Option<Value>,
) -> Result<OutputShape> {
    match return_value {
        Some(_) => Ok(OutputShape::returned(
            manifest_entry.return_canonical_len.ok_or_else(|| {
                anyhow::anyhow!(
                    "manifest return_canonical_len missing for entrypoint with return value"
                )
            })?,
        )),
        None => Ok(OutputShape::default()),
    }
}

pub(crate) fn return_payload_of(
    manifest_entry: &EntrypointManifest,
    return_value: &Option<Value>,
) -> Result<Option<String>> {
    match (return_value, manifest_entry.returns) {
        (Some(_), ReturnPolicy::Forbidden) => {
            bail!("entrypoint returned a value despite returns: forbidden")
        }
        (Some(_), ReturnPolicy::EncryptedToClient) => {
            bail!("encrypted_to_client returns are not implemented")
        }
        (Some(value), ReturnPolicy::Public | ReturnPolicy::Declassified) => {
            Ok(Some(value.to_string()))
        }
        (None, _) => Ok(None),
    }
}

pub(crate) fn finalize_public_call_trace(
    recorder: CallRecorder,
    manifest_entry: &EntrypointManifest,
    manifest_objects: &[StateObjectManifest],
    public_call: PublicCallSummary,
    return_value: &Option<Value>,
    aborted: bool,
    confidential: bool,
) -> Result<(u64, usize, RuntimePublicCallTraceBundle)> {
    let gas_used = gas_used_of(&recorder, manifest_entry, confidential);
    let output_shape = output_shape_of(manifest_entry, return_value)?;
    let return_payload = return_payload_of(manifest_entry, return_value)?;
    let (zero_writes, trace_bundle) = recorder.finish(
        manifest_entry,
        manifest_objects,
        public_call,
        output_shape,
        return_payload,
        aborted,
        gas_used,
    )?;
    Ok((gas_used, zero_writes, trace_bundle))
}
