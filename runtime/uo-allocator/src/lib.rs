use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use uo_core::{
    EntrypointManifest, RuntimeKernelResourceEventWitness, RuntimeKernelScratchRegionWitness,
    RuntimeKernelTelemetrySnapshot,
};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ScratchRegion {
    ValueScratch,
    HashScratch,
    IoScratch,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScratchUsage {
    pub live_bytes: usize,
    pub peak_bytes: usize,
    pub wipe_count: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AllocatorPlan {
    pub arena_bytes: usize,
    pub max_stack_words: usize,
    pub scratch_bytes: usize,
    pub max_kernel_ops: usize,
}

impl AllocatorPlan {
    pub fn for_entrypoint(arena_bytes: usize, max_stack_words: usize) -> Self {
        Self {
            arena_bytes,
            max_stack_words,
            scratch_bytes: arena_bytes / 4,
            max_kernel_ops: 0,
        }
    }

    pub fn from_manifest(entry: &EntrypointManifest) -> Self {
        let logical_kernel_ops = entry.uocell_reads
            + entry.uocell_writes
            + entry.uoarray_reads
            + entry.uoarray_writes
            + entry.uomap_reads
            + entry.uomap_writes;
        let canonical_kernel_steps = entry.canonical_kernel_step_manifest();
        let mut plan = Self::for_entrypoint(entry.arena_bytes, entry.max_stack_words);
        plan.max_kernel_ops = if canonical_kernel_steps.is_empty() {
            logical_kernel_ops + 3
        } else {
            canonical_kernel_steps.len()
        };
        plan
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AllocatorSession {
    plan: AllocatorPlan,
    kernel_op_count: usize,
    resource_events: Vec<RuntimeKernelResourceEventWitness>,
    peak_stack_words: usize,
    value_scratch: ScratchUsage,
    hash_scratch: ScratchUsage,
    io_scratch: ScratchUsage,
}

pub struct ScratchGuard<'a> {
    session: &'a mut AllocatorSession,
    region: ScratchRegion,
}

impl Drop for ScratchGuard<'_> {
    fn drop(&mut self) {
        self.session.wipe_region(self.region);
    }
}

impl AllocatorSession {
    pub fn new(plan: AllocatorPlan) -> Self {
        Self {
            plan,
            kernel_op_count: 0,
            resource_events: Vec::new(),
            peak_stack_words: 0,
            value_scratch: ScratchUsage::default(),
            hash_scratch: ScratchUsage::default(),
            io_scratch: ScratchUsage::default(),
        }
    }

    pub fn plan(&self) -> &AllocatorPlan {
        &self.plan
    }

    pub fn peak_stack_words(&self) -> usize {
        self.peak_stack_words
    }

    pub fn resource_events(&self) -> &[RuntimeKernelResourceEventWitness] {
        &self.resource_events
    }

    pub fn value_scratch_usage(&self) -> &ScratchUsage {
        &self.value_scratch
    }

    pub fn hash_scratch_usage(&self) -> &ScratchUsage {
        &self.hash_scratch
    }

    pub fn io_scratch_usage(&self) -> &ScratchUsage {
        &self.io_scratch
    }

    pub fn into_kernel_telemetry_snapshot(self) -> RuntimeKernelTelemetrySnapshot {
        RuntimeKernelTelemetrySnapshot::new(
            self.plan.arena_bytes,
            self.plan.max_stack_words,
            self.plan.scratch_bytes,
            self.peak_stack_words,
            self.value_scratch.peak_bytes,
            self.value_scratch.live_bytes,
            self.value_scratch.wipe_count,
            self.hash_scratch.peak_bytes,
            self.hash_scratch.live_bytes,
            self.hash_scratch.wipe_count,
            self.io_scratch.peak_bytes,
            self.io_scratch.live_bytes,
            self.io_scratch.wipe_count,
            self.resource_events,
        )
    }

    pub fn record_kernel_op(&mut self) -> Result<()> {
        if self.kernel_op_count >= self.plan.max_kernel_ops {
            bail!(
                "allocator kernel-op budget exceeded: {} >= {}",
                self.kernel_op_count,
                self.plan.max_kernel_ops
            );
        }
        self.kernel_op_count += 1;
        Ok(())
    }

    pub fn reserve_scratch(&mut self, region: ScratchRegion, bytes: usize) -> Result<()> {
        if bytes > self.plan.scratch_bytes {
            bail!(
                "{region:?} reservation {} exceeds scratch budget {}",
                bytes,
                self.plan.scratch_bytes
            );
        }
        let usage = self.usage_mut(region);
        usage.live_bytes = bytes;
        usage.peak_bytes = usage.peak_bytes.max(bytes);
        self.resource_events
            .push(RuntimeKernelResourceEventWitness::reserve_scratch(
                runtime_kernel_region(region),
                bytes,
            ));
        Ok(())
    }

    pub fn reserve_guard(
        &mut self,
        region: ScratchRegion,
        bytes: usize,
    ) -> Result<ScratchGuard<'_>> {
        self.reserve_scratch(region, bytes)?;
        Ok(ScratchGuard {
            session: self,
            region,
        })
    }

    pub fn wipe_region(&mut self, region: ScratchRegion) {
        let usage = self.usage_mut(region);
        usage.live_bytes = 0;
        usage.wipe_count += 1;
        self.resource_events
            .push(RuntimeKernelResourceEventWitness::wipe_scratch(
                runtime_kernel_region(region),
            ));
    }

    pub fn enforce_stack_words(&mut self, words: usize) -> Result<()> {
        if words > self.plan.max_stack_words {
            bail!(
                "allocator stack-word budget exceeded: {} > {}",
                words,
                self.plan.max_stack_words
            );
        }
        self.peak_stack_words = self.peak_stack_words.max(words);
        self.resource_events
            .push(RuntimeKernelResourceEventWitness::stack_check(words));
        Ok(())
    }

    pub fn finish(self) -> Result<Self> {
        self.ensure_region_wiped(ScratchRegion::ValueScratch, &self.value_scratch)?;
        self.ensure_region_wiped(ScratchRegion::HashScratch, &self.hash_scratch)?;
        self.ensure_region_wiped(ScratchRegion::IoScratch, &self.io_scratch)?;
        Ok(self)
    }

    fn usage_mut(&mut self, region: ScratchRegion) -> &mut ScratchUsage {
        match region {
            ScratchRegion::ValueScratch => &mut self.value_scratch,
            ScratchRegion::HashScratch => &mut self.hash_scratch,
            ScratchRegion::IoScratch => &mut self.io_scratch,
        }
    }

    fn ensure_region_wiped(&self, region: ScratchRegion, usage: &ScratchUsage) -> Result<()> {
        if usage.live_bytes != 0 {
            bail!(
                "{region:?} left live at end of call: {} bytes",
                usage.live_bytes
            );
        }
        if usage.peak_bytes != 0 && usage.wipe_count == 0 {
            bail!("{region:?} was used but never wiped");
        }
        Ok(())
    }
}

fn runtime_kernel_region(region: ScratchRegion) -> RuntimeKernelScratchRegionWitness {
    match region {
        ScratchRegion::ValueScratch => RuntimeKernelScratchRegionWitness::ValueScratch,
        ScratchRegion::HashScratch => RuntimeKernelScratchRegionWitness::HashScratch,
        ScratchRegion::IoScratch => RuntimeKernelScratchRegionWitness::IoScratch,
    }
}

#[cfg(test)]
mod tests {
    use super::{AllocatorPlan, AllocatorSession, ScratchRegion};
    use uo_core::{EntrypointManifest, RuntimeKernelStepManifest};
    use uo_precompiles::UoOpcode;

    fn sample_manifest() -> EntrypointManifest {
        EntrypointManifest {
            secret_args: vec![0],
            param_names: vec!["secret".into()],
            entry_input_len: 32,
            public_gas_budget: 4096,
            arena_bytes: 4096,
            max_stack_words: 65,
            max_hash_part_bytes: 0,
            return_canonical_len: None,
            confidential_program: None,
            confidential_slot_program: None,
            kernel_steps: vec![
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::Begin,
                    object_id: None,
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::CellGet,
                    object_id: Some(1),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::CellSet,
                    object_id: Some(1),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::CellSet,
                    object_id: Some(1),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::ArrayGet,
                    object_id: Some(2),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::ArrayGet,
                    object_id: Some(2),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::ArrayGet,
                    object_id: Some(2),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapGet,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::MapPut,
                    object_id: Some(3),
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::Commit,
                    object_id: None,
                },
                RuntimeKernelStepManifest {
                    opcode: UoOpcode::Wipe,
                    object_id: None,
                },
            ],
            uocell_reads: 1,
            uocell_writes: 2,
            uoarray_reads: 3,
            uoarray_writes: 0,
            uomap_reads: 4,
            uomap_writes: 5,
            max_commit_ops: 9,
            oram_accesses: Default::default(),
        }
    }

    #[test]
    fn manifest_plan_sets_exact_kernel_budget() {
        let plan = AllocatorPlan::from_manifest(&sample_manifest());
        assert_eq!(
            plan.max_kernel_ops,
            sample_manifest().canonical_kernel_step_manifest().len()
        );
    }

    #[test]
    fn manifest_plan_prefers_canonical_slot_program_budget() {
        let mut manifest = sample_manifest();
        manifest.kernel_steps.clear();
        manifest.confidential_slot_program = Some(uo_core::ConfidentialKernelSlotProgram {
            entrypoint_id: "touch(uint256)".into(),
            param_count: 1,
            return_type: None,
            secret_args: vec![0],
            slot_count: 1,
            body: Vec::new(),
        });

        let plan = AllocatorPlan::from_manifest(&manifest);

        assert_eq!(
            plan.max_kernel_ops,
            manifest.canonical_kernel_step_manifest().len()
        );
    }

    #[test]
    fn session_rejects_kernel_budget_overflow() {
        let mut session = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            max_kernel_ops: 1,
        });
        session.record_kernel_op().unwrap();
        assert!(session.record_kernel_op().is_err());
    }

    #[test]
    fn session_requires_wiped_scratch() {
        let mut session = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            max_kernel_ops: 4,
        });
        session
            .reserve_scratch(ScratchRegion::ValueScratch, 32)
            .unwrap();
        assert!(session.finish().is_err());
    }

    #[test]
    fn session_accepts_wiped_regions() {
        let mut session = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            max_kernel_ops: 4,
        });
        session.record_kernel_op().unwrap();
        session
            .reserve_scratch(ScratchRegion::ValueScratch, 32)
            .unwrap();
        session.wipe_region(ScratchRegion::ValueScratch);
        session.record_kernel_op().unwrap();
        session.record_kernel_op().unwrap();
        session.finish().unwrap();
    }

    #[test]
    fn reserve_guard_wipes_io_region_on_drop() {
        let mut session = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            max_kernel_ops: 4,
        });
        {
            let _guard = session.reserve_guard(ScratchRegion::IoScratch, 96).unwrap();
        }
        assert_eq!(session.io_scratch_usage().live_bytes, 0);
        assert_eq!(session.io_scratch_usage().peak_bytes, 96);
        assert_eq!(session.io_scratch_usage().wipe_count, 1);
    }
}
