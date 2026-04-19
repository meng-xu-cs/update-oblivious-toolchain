use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use uo_core::{
    EntrypointManifest, RuntimeKernelResourceEventWitness, RuntimeKernelScratchRegionWitness,
};
use uo_precompiles::UoOpcode;

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
        let mut plan = Self::for_entrypoint(entry.arena_bytes, entry.max_stack_words);
        plan.max_kernel_ops = if let Some(program) = &entry.confidential_slot_program {
            program.expected_runtime_steps().len()
        } else if entry.kernel_steps.is_empty() {
            logical_kernel_ops + 3
        } else {
            entry.kernel_steps.len()
        };
        plan
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AllocatorSession {
    plan: AllocatorPlan,
    kernel_ops: Vec<UoOpcode>,
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
        let kernel_ops = Vec::with_capacity(plan.max_kernel_ops.max(1));
        Self {
            plan,
            kernel_ops,
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

    pub fn kernel_ops(&self) -> &[UoOpcode] {
        &self.kernel_ops
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

    pub fn record_kernel_op(&mut self, opcode: UoOpcode) -> Result<()> {
        if self.kernel_ops.len() >= self.plan.max_kernel_ops {
            bail!(
                "allocator kernel-op budget exceeded: {} >= {}",
                self.kernel_ops.len(),
                self.plan.max_kernel_ops
            );
        }
        self.kernel_ops.push(opcode);
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
            public_gas_budget: 4096,
            arena_bytes: 4096,
            max_stack_words: 65,
            confidential_program: None,
            confidential_slot_program: None,
            kernel_steps: vec![
                RuntimeKernelStepManifest { opcode: UoOpcode::Begin, object_id: None },
                RuntimeKernelStepManifest { opcode: UoOpcode::CellGet, object_id: Some(1) },
                RuntimeKernelStepManifest { opcode: UoOpcode::CellSet, object_id: Some(1) },
                RuntimeKernelStepManifest { opcode: UoOpcode::CellSet, object_id: Some(1) },
                RuntimeKernelStepManifest { opcode: UoOpcode::ArrayGet, object_id: Some(2) },
                RuntimeKernelStepManifest { opcode: UoOpcode::ArrayGet, object_id: Some(2) },
                RuntimeKernelStepManifest { opcode: UoOpcode::ArrayGet, object_id: Some(2) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapGet, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapGet, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapGet, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapGet, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapPut, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapPut, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapPut, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapPut, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::MapPut, object_id: Some(3) },
                RuntimeKernelStepManifest { opcode: UoOpcode::Commit, object_id: None },
                RuntimeKernelStepManifest { opcode: UoOpcode::Wipe, object_id: None },
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
        assert_eq!(plan.max_kernel_ops, sample_manifest().kernel_steps.len());
    }

    #[test]
    fn session_rejects_kernel_budget_overflow() {
        let mut session = AllocatorSession::new(AllocatorPlan {
            arena_bytes: 4096,
            max_stack_words: 64,
            scratch_bytes: 1024,
            max_kernel_ops: 1,
        });
        session.record_kernel_op(UoOpcode::Begin).unwrap();
        assert!(session.record_kernel_op(UoOpcode::Commit).is_err());
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
        session.record_kernel_op(UoOpcode::Begin).unwrap();
        session
            .reserve_scratch(ScratchRegion::ValueScratch, 32)
            .unwrap();
        session.wipe_region(ScratchRegion::ValueScratch);
        session.record_kernel_op(UoOpcode::Commit).unwrap();
        session.record_kernel_op(UoOpcode::Wipe).unwrap();
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
