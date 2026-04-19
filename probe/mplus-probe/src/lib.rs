#![recursion_limit = "1024"]

use anyhow::{anyhow, Context, Result};
use rayon::prelude::*;
use serde::Serialize;
use serde_json::{json, Value as JsonValue};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::{self, Command, Output};
use std::sync::{Mutex, OnceLock};
use std::time::{Instant, SystemTime, UNIX_EPOCH};
use uo_core::{
    canonical_path_oram_leaf_seed_space_size, canonical_path_oram_leaf_values_of_seed,
    BoundaryEvent, CanonicalFreshCoinRuntimePathOramTheoremInput,
    CanonicalFreshCoinRuntimePathOramWitnessFamily, CompiledArtifact, ContractMetadata,
    LogicalEvent, NormalizedMicroTrace, ProgramMode, PublicOutcomeTrace,
    RuntimeKernelRefinementWitness, RuntimeKernelWitness, RuntimeOramAccessCounterWitness,
    RuntimeOramLeafScaffoldWitness, RuntimeOramObjectWitness, RuntimeRefinementWitness,
    RuntimeShellContract, RuntimeShellTrace, SeededRuntimePathOramWitnessFamily,
    SgxControllerShapeTrace, Value, WriteClass,
};
use uo_evm::{CallResult, ContractInstance, DiagnosticCallResult, PathOramFreshCoinPlan};

#[derive(Clone)]
struct BenchArtifacts {
    raw: CompiledArtifact,
    uo: CompiledArtifact,
    oram: Option<CompiledArtifact>,
    fullscan64: Option<CompiledArtifact>,
}

#[derive(Clone)]
struct CallSpec {
    entrypoint: &'static str,
    args: Vec<Value>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedManifestWitness {
    public_gas_budget: u64,
    secret_args: Vec<usize>,
    oram_accesses: Vec<(u32, usize)>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedOramEntrypointWitness {
    #[serde(flatten)]
    manifest: ImportedManifestWitness,
    entrypoint_id: String,
    oram_objects: Vec<RuntimeOramObjectWitness>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedOramPublicData {
    witness: ImportedOramEntrypointWitness,
    public_args: Vec<String>,
    access_counters: Vec<(u32, u64)>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedOramConfig {
    pub_data: ImportedOramPublicData,
    secret_state: Vec<String>,
    secret_args: Vec<String>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedOramViewPublicPart {
    opcode_trace: Vec<String>,
    logical_accesses: Vec<LogicalEvent>,
    logical_writes: Vec<LogicalEvent>,
    gas_used: u64,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedPathOramPhysicalEventLabel {
    object: String,
    location: String,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedPathOramStorageLocationTrace {
    read_labels: Vec<ImportedPathOramPhysicalEventLabel>,
    write_labels: Vec<ImportedPathOramPhysicalEventLabel>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedPathOramStorageShape {
    read_lengths: Vec<usize>,
    write_classes: Vec<String>,
    write_lengths: Vec<usize>,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedSeededRuntimePathOramPairCertificate {
    cfg: ImportedOramConfig,
    lhs_family: SeededRuntimePathOramWitnessFamily,
    rhs_family: SeededRuntimePathOramWitnessFamily,
    public_view: ImportedOramViewPublicPart,
    public_location: ImportedPathOramStorageLocationTrace,
    storage_shape: ImportedPathOramStorageShape,
    public_outcome: PublicOutcomeTrace,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_shape: SgxControllerShapeTrace,
    normalized_micro_trace: NormalizedMicroTrace,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedCanonicalFreshCoinRuntimePathOramPairCertificate {
    cfg: ImportedOramConfig,
    lhs_family: CanonicalFreshCoinRuntimePathOramWitnessFamily,
    rhs_family: CanonicalFreshCoinRuntimePathOramWitnessFamily,
    public_view: ImportedOramViewPublicPart,
    public_location: ImportedPathOramStorageLocationTrace,
    storage_shape: ImportedPathOramStorageShape,
    public_outcome: PublicOutcomeTrace,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_shape: SgxControllerShapeTrace,
    normalized_micro_trace: NormalizedMicroTrace,
}

#[derive(Clone, Debug, Serialize)]
struct ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput {
    cfg: ImportedOramConfig,
    lhs_input: CanonicalFreshCoinRuntimePathOramTheoremInput,
    rhs_input: CanonicalFreshCoinRuntimePathOramTheoremInput,
    public_view: ImportedOramViewPublicPart,
    public_location: ImportedPathOramStorageLocationTrace,
    storage_shape: ImportedPathOramStorageShape,
    public_outcome: PublicOutcomeTrace,
    boundary_schedule: Vec<BoundaryEvent>,
    controller_shape: SgxControllerShapeTrace,
    normalized_micro_trace: NormalizedMicroTrace,
}

#[derive(Clone)]
struct CollectedSeededFamily {
    family: SeededRuntimePathOramWitnessFamily,
    access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
}

#[derive(Clone)]
struct CollectedCanonicalFreshCoinFamily {
    family: CanonicalFreshCoinRuntimePathOramWitnessFamily,
    first_witness: RuntimeRefinementWitness,
    access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
}

#[derive(Clone)]
struct CollectedCanonicalFreshCoinTheoremInput {
    input: CanonicalFreshCoinRuntimePathOramTheoremInput,
    access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
}

#[derive(Clone, Debug, Serialize)]
struct CanonicalFamilySizeEstimate {
    seed_count: usize,
    sampled_seed_count: usize,
    avg_witness_json_bytes: u64,
    max_witness_json_bytes: u64,
    estimated_family_json_bytes: u64,
    public_leaf_scaffold_steps: usize,
    public_fresh_coin_scaffold_steps: usize,
}

const DEFAULT_CANONICAL_CERT_BUDGET_BYTES: u64 = 10 * 1024 * 1024 * 1024;
const DEFAULT_HEAVY_ARTIFACT_BUDGET_BYTES: u64 = 20 * 1024 * 1024 * 1024;
const CANONICAL_SIZE_ESTIMATE_SAMPLE_SEEDS: usize = 8;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
pub enum ArtifactMaterializationMode {
    Compact,
    Heavy,
}

impl ArtifactMaterializationMode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Compact => "compact",
            Self::Heavy => "heavy",
        }
    }
}

#[derive(Clone, Debug)]
pub struct ProbeRunOptions {
    pub materialization_mode: ArtifactMaterializationMode,
    pub out_dir: Option<PathBuf>,
    pub compact_budget_bytes: u64,
    pub heavy_budget_bytes: u64,
}

#[derive(Serialize)]
struct ReproducibilityManifestEntry {
    path: String,
    bytes: u64,
    sha256: String,
}

#[derive(Serialize)]
struct ReproducibilityManifest {
    format_version: u32,
    file_count: usize,
    files: Vec<ReproducibilityManifestEntry>,
}

impl Default for ProbeRunOptions {
    fn default() -> Self {
        Self {
            materialization_mode: ArtifactMaterializationMode::Compact,
            out_dir: None,
            compact_budget_bytes: DEFAULT_CANONICAL_CERT_BUDGET_BYTES,
            heavy_budget_bytes: DEFAULT_HEAVY_ARTIFACT_BUDGET_BYTES,
        }
    }
}

impl ProbeRunOptions {
    fn artifact_configuration_json(&self) -> JsonValue {
        json!({
            "materialization_mode": self.materialization_mode.as_str(),
            "compact_budget_bytes": self.compact_budget_bytes,
            "heavy_budget_bytes": self.heavy_budget_bytes,
            "heavy_artifact_dir": self
                .heavy_artifact_dir()
                .map(|path| display_output_bundle_path(self, &path)),
        })
    }

    fn heavy_artifact_dir(&self) -> Option<PathBuf> {
        self.out_dir
            .as_ref()
            .map(|out_dir| out_dir.join("heavy_artifacts"))
    }

    fn should_try_heavy_materialization(&self, estimated_bytes: u64) -> bool {
        self.materialization_mode == ArtifactMaterializationMode::Heavy
            && estimated_bytes > self.compact_budget_bytes
            && estimated_bytes <= self.heavy_budget_bytes
    }
}

#[derive(Clone)]
struct PreparedCanonicalFreshCoinFamily {
    prepared: ContractInstance,
    first_witness: RuntimeRefinementWitness,
    access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
    public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,
    seed_count: usize,
}

#[derive(Clone)]
struct MaterializedCanonicalFreshCoinFamily {
    access_counters_before: Vec<RuntimeOramAccessCounterWitness>,
    seed_count: usize,
    gas_uniform: bool,
    boundary_uniform: bool,
    controller_phase_uniform: bool,
    oram_object_config_uniform: bool,
    public_leaf_scaffold_steps: usize,
    public_fresh_coin_scaffold_steps: usize,
}

pub fn run_probe() -> Result<JsonValue> {
    run_probe_with_options(&ProbeRunOptions::default())
}

fn timed_report<T, F>(run: F) -> Result<(T, u128)>
where
    F: FnOnce() -> Result<T>,
{
    let started = Instant::now();
    let report = run()?;
    Ok((report, started.elapsed().as_millis()))
}

pub fn run_probe_with_options(options: &ProbeRunOptions) -> Result<JsonValue> {
    let probe_started = Instant::now();
    let suite = compile_suite().context("compiling probe benchmark suite")?;
    let (correctness, correctness_ms) =
        timed_report(|| run_correctness(&suite).context("running correctness report"))?;
    let (static_checks, static_checks_ms) =
        timed_report(|| run_static_checks(&suite).context("running static_checks report"))?;
    let (trace_equivalence, trace_equivalence_ms) =
        timed_report(|| run_trace_equivalence(&suite).context("running trace_equivalence report"))?;
    let (leakage_auc, leakage_auc_ms) =
        timed_report(|| run_auc_reports(&suite).context("running leakage_auc report"))?;
    let (mutual_information, mutual_information_ms) = timed_report(|| {
        run_mutual_information_reports(&suite).context("running mutual_information report")
    })?;
    let (overheads, overheads_ms) =
        timed_report(|| run_overheads(&suite).context("running overheads report"))?;
    let (controller_observer_validation, controller_observer_validation_ms) = timed_report(|| {
        run_controller_observer_validation(&suite)
            .context("running controller_observer_validation report")
    })?;
    let (pathoram_hidden_validation, pathoram_hidden_validation_ms) = timed_report(|| {
        run_pathoram_hidden_validation().context("running pathoram_hidden_validation report")
    })?;
    let (runtime_boundary_validation, runtime_boundary_validation_ms) = timed_report(|| {
        run_runtime_boundary_validation().context("running runtime_boundary_validation report")
    })?;
    let (kernel_model_alignment_validation, kernel_model_alignment_validation_ms) =
        timed_report(|| {
            run_kernel_model_alignment_validation()
                .context("running kernel_model_alignment_validation report")
        })?;
    let (shell_boundary_validation, shell_boundary_validation_ms) = timed_report(|| {
        run_shell_boundary_validation(&suite).context("running shell_boundary_validation report")
    })?;
    let (shell_boundary_slot_validation, shell_boundary_slot_validation_ms) = timed_report(|| {
        run_shell_boundary_slot_validation(&suite)
            .context("running shell_boundary_slot_validation report")
    })?;
    let (shell_boundary_lowering_validation, shell_boundary_lowering_validation_ms) =
        timed_report(|| {
            run_shell_boundary_lowering_validation(&suite)
                .context("running shell_boundary_lowering_validation report")
        })?;
    let (confidential_fragment_validation, confidential_fragment_validation_ms) =
        timed_report(|| {
            run_confidential_fragment_validation(&suite)
                .context("running confidential_fragment_validation report")
        })?;
    let (kernel_dsl_validation, kernel_dsl_validation_ms) = timed_report(|| {
        run_kernel_dsl_validation(&suite).context("running kernel_dsl_validation report")
    })?;
    let (kernel_slot_dsl_validation, kernel_slot_dsl_validation_ms) = timed_report(|| {
        run_kernel_slot_dsl_validation(&suite).context("running kernel_slot_dsl_validation report")
    })?;
    let (kernel_lowering_validation, kernel_lowering_validation_ms) = timed_report(|| {
        run_kernel_lowering_validation(&suite).context("running kernel_lowering_validation report")
    })?;
    let (confidential_core_validation, confidential_core_validation_ms) = timed_report(|| {
        run_confidential_core_validation(&suite)
            .context("running confidential_core_validation report")
    })?;
    let (confidential_core_slot_validation, confidential_core_slot_validation_ms) =
        timed_report(|| {
            run_confidential_core_slot_validation(&suite)
                .context("running confidential_core_slot_validation report")
        })?;
    let (
        confidential_core_shell_boundary_slot_validation,
        confidential_core_shell_boundary_slot_validation_ms,
    ) = timed_report(|| {
        run_confidential_core_shell_boundary_slot_validation(&suite)
            .context("running confidential_core_shell_boundary_slot_validation report")
    })?;
    let (confidential_core_lowering_validation, confidential_core_lowering_validation_ms) =
        timed_report(|| {
            run_confidential_core_lowering_validation(&suite)
                .context("running confidential_core_lowering_validation report")
        })?;
    let (
        confidential_core_shell_boundary_lowering_validation,
        confidential_core_shell_boundary_lowering_validation_ms,
    ) = timed_report(|| {
        run_confidential_core_shell_boundary_lowering_validation(&suite)
            .context("running confidential_core_shell_boundary_lowering_validation report")
    })?;
    let (kernel_validation, kernel_validation_ms) =
        timed_report(|| run_kernel_validation(&suite).context("running kernel_validation report"))?;
    let (kernel_refinement_validation, kernel_refinement_validation_ms) = timed_report(|| {
        run_kernel_refinement_validation(&suite)
            .context("running kernel_refinement_validation report")
    })?;
    let (trusted_kernel_validation, trusted_kernel_validation_ms) = timed_report(|| {
        run_trusted_kernel_validation(&suite).context("running trusted_kernel_validation report")
    })?;
    let (tamper_validation, tamper_validation_ms) =
        timed_report(|| run_tamper_validation().context("running tamper_validation report"))?;
    let (witness_validation, witness_validation_ms) = timed_report(|| {
        run_witness_validation(&suite).context("running witness_validation report")
    })?;
    let (seeded_witness_validation, seeded_witness_validation_ms) = timed_report(|| {
        run_seeded_witness_validation().context("running seeded_witness_validation report")
    })?;
    let (fresh_coin_validation, fresh_coin_validation_ms) = timed_report(|| {
        run_fresh_coin_validation(options).context("running fresh_coin_validation report")
    })?;
    let (pathoram_pair_validation, pathoram_pair_validation_ms) = timed_report(|| {
        run_pathoram_pair_validation().context("running pathoram_pair_validation report")
    })?;
    let (canonical_pathoram_pair_validation, canonical_pathoram_pair_validation_ms) =
        timed_report(|| {
            run_canonical_pathoram_pair_validation(options)
                .context("running canonical_pathoram_pair_validation report")
        })?;
    let bridge_validation = json!({
        "static_checks": static_checks,
        "controller_observer_validation": controller_observer_validation,
        "pathoram_hidden_validation": pathoram_hidden_validation,
        "runtime_boundary_validation": runtime_boundary_validation,
        "kernel_model_alignment_validation": kernel_model_alignment_validation,
        "shell_boundary_validation": shell_boundary_validation,
        "shell_boundary_slot_validation": shell_boundary_slot_validation,
        "shell_boundary_lowering_validation": shell_boundary_lowering_validation,
        "confidential_fragment_validation": confidential_fragment_validation,
        "kernel_dsl_validation": kernel_dsl_validation,
        "kernel_slot_dsl_validation": kernel_slot_dsl_validation,
        "kernel_lowering_validation": kernel_lowering_validation,
        "confidential_core_validation": confidential_core_validation,
        "confidential_core_slot_validation": confidential_core_slot_validation,
        "confidential_core_shell_boundary_slot_validation":
            confidential_core_shell_boundary_slot_validation,
        "confidential_core_lowering_validation": confidential_core_lowering_validation,
        "confidential_core_shell_boundary_lowering_validation":
            confidential_core_shell_boundary_lowering_validation,
        "kernel_validation": kernel_validation,
        "kernel_refinement_validation": kernel_refinement_validation,
        "trusted_kernel_validation": trusted_kernel_validation,
        "tamper_validation": tamper_validation,
        "witness_validation": witness_validation,
        "seeded_witness_validation": seeded_witness_validation,
    });
    let reviewer_summary = build_reviewer_summary(
        &correctness,
        &static_checks,
        &trace_equivalence,
        &leakage_auc,
        &mutual_information,
        &overheads,
        &controller_observer_validation,
        &pathoram_hidden_validation,
        &runtime_boundary_validation,
        &kernel_model_alignment_validation,
        &shell_boundary_validation,
        &shell_boundary_slot_validation,
        &shell_boundary_lowering_validation,
        &confidential_fragment_validation,
        &kernel_dsl_validation,
        &kernel_slot_dsl_validation,
        &kernel_lowering_validation,
        &confidential_core_validation,
        &confidential_core_slot_validation,
        &confidential_core_shell_boundary_slot_validation,
        &confidential_core_lowering_validation,
        &confidential_core_shell_boundary_lowering_validation,
        &kernel_validation,
        &kernel_refinement_validation,
        &trusted_kernel_validation,
        &tamper_validation,
        &witness_validation,
        &seeded_witness_validation,
        &fresh_coin_validation,
        &pathoram_pair_validation,
        &canonical_pathoram_pair_validation,
        &json!({
            "correctness": correctness_ms,
            "static_checks": static_checks_ms,
            "trace_equivalence": trace_equivalence_ms,
            "leakage_auc": leakage_auc_ms,
            "mutual_information": mutual_information_ms,
            "overheads": overheads_ms,
            "controller_observer_validation": controller_observer_validation_ms,
            "pathoram_hidden_validation": pathoram_hidden_validation_ms,
            "runtime_boundary_validation": runtime_boundary_validation_ms,
            "kernel_model_alignment_validation": kernel_model_alignment_validation_ms,
            "shell_boundary_validation": shell_boundary_validation_ms,
            "shell_boundary_slot_validation": shell_boundary_slot_validation_ms,
            "shell_boundary_lowering_validation": shell_boundary_lowering_validation_ms,
            "confidential_fragment_validation": confidential_fragment_validation_ms,
            "kernel_dsl_validation": kernel_dsl_validation_ms,
            "kernel_slot_dsl_validation": kernel_slot_dsl_validation_ms,
            "kernel_lowering_validation": kernel_lowering_validation_ms,
            "confidential_core_validation": confidential_core_validation_ms,
            "confidential_core_slot_validation": confidential_core_slot_validation_ms,
            "confidential_core_shell_boundary_slot_validation":
                confidential_core_shell_boundary_slot_validation_ms,
            "confidential_core_lowering_validation": confidential_core_lowering_validation_ms,
            "confidential_core_shell_boundary_lowering_validation":
                confidential_core_shell_boundary_lowering_validation_ms,
            "kernel_validation": kernel_validation_ms,
            "kernel_refinement_validation": kernel_refinement_validation_ms,
            "trusted_kernel_validation": trusted_kernel_validation_ms,
            "tamper_validation": tamper_validation_ms,
            "witness_validation": witness_validation_ms,
            "seeded_witness_validation": seeded_witness_validation_ms,
            "fresh_coin_validation": fresh_coin_validation_ms,
            "pathoram_pair_validation": pathoram_pair_validation_ms,
            "canonical_pathoram_pair_validation": canonical_pathoram_pair_validation_ms,
            "total_probe_ms": probe_started.elapsed().as_millis(),
        }),
    )?;
    let artifact_readme = artifact_readme(options);
    Ok(json!({
        "artifact_configuration": options.artifact_configuration_json(),
        "correctness": correctness,
        "static_checks": static_checks,
        "bridge_validation": bridge_validation,
        "trace_equivalence": trace_equivalence,
        "leakage_auc": leakage_auc,
        "mutual_information": mutual_information,
        "overheads": overheads,
        "controller_observer_validation": controller_observer_validation,
        "pathoram_hidden_validation": pathoram_hidden_validation,
        "runtime_boundary_validation": runtime_boundary_validation,
        "kernel_model_alignment_validation": kernel_model_alignment_validation,
        "shell_boundary_validation": shell_boundary_validation,
        "shell_boundary_slot_validation": shell_boundary_slot_validation,
        "shell_boundary_lowering_validation": shell_boundary_lowering_validation,
        "confidential_fragment_validation": confidential_fragment_validation,
        "kernel_dsl_validation": kernel_dsl_validation,
        "kernel_slot_dsl_validation": kernel_slot_dsl_validation,
        "kernel_lowering_validation": kernel_lowering_validation,
        "confidential_core_validation": confidential_core_validation,
        "confidential_core_slot_validation": confidential_core_slot_validation,
        "confidential_core_shell_boundary_slot_validation":
            confidential_core_shell_boundary_slot_validation,
        "confidential_core_lowering_validation": confidential_core_lowering_validation,
        "confidential_core_shell_boundary_lowering_validation":
            confidential_core_shell_boundary_lowering_validation,
        "kernel_validation": kernel_validation,
        "kernel_refinement_validation": kernel_refinement_validation,
        "trusted_kernel_validation": trusted_kernel_validation,
        "tamper_validation": tamper_validation,
        "witness_validation": witness_validation,
        "seeded_witness_validation": seeded_witness_validation,
        "fresh_coin_validation": fresh_coin_validation,
        "pathoram_pair_validation": pathoram_pair_validation,
        "canonical_pathoram_pair_validation": canonical_pathoram_pair_validation,
        "reviewer_summary": reviewer_summary,
        "artifact_readme": artifact_readme,
    }))
}

pub fn run_fresh_coin_validation_report() -> Result<JsonValue> {
    run_fresh_coin_validation_with_options(&ProbeRunOptions::default())
}

pub fn run_fresh_coin_validation_with_options(options: &ProbeRunOptions) -> Result<JsonValue> {
    run_fresh_coin_validation(options)
}

pub fn run_static_checks_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_static_checks(&suite)
}

pub fn run_bridge_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    let static_checks = run_static_checks(&suite)?;
    let controller_observer_validation = run_controller_observer_validation(&suite)?;
    let pathoram_hidden_validation = run_pathoram_hidden_validation()?;
    let runtime_boundary_validation = run_runtime_boundary_validation()?;
    let kernel_model_alignment_validation = run_kernel_model_alignment_validation()?;
    let shell_boundary_validation = run_shell_boundary_validation(&suite)?;
    let shell_boundary_slot_validation = run_shell_boundary_slot_validation(&suite)?;
    let shell_boundary_lowering_validation = run_shell_boundary_lowering_validation(&suite)?;
    let confidential_fragment_validation = run_confidential_fragment_validation(&suite)?;
    let kernel_dsl_validation = run_kernel_dsl_validation(&suite)?;
    let kernel_slot_dsl_validation = run_kernel_slot_dsl_validation(&suite)?;
    let kernel_lowering_validation = run_kernel_lowering_validation(&suite)?;
    let confidential_core_validation = run_confidential_core_validation(&suite)?;
    let confidential_core_slot_validation = run_confidential_core_slot_validation(&suite)?;
    let confidential_core_shell_boundary_slot_validation =
        run_confidential_core_shell_boundary_slot_validation(&suite)?;
    let confidential_core_lowering_validation = run_confidential_core_lowering_validation(&suite)?;
    let confidential_core_shell_boundary_lowering_validation =
        run_confidential_core_shell_boundary_lowering_validation(&suite)?;
    let kernel_validation = run_kernel_validation(&suite)?;
    let kernel_refinement_validation = run_kernel_refinement_validation(&suite)?;
    let trusted_kernel_validation = run_trusted_kernel_validation(&suite)?;
    let tamper_validation = run_tamper_validation()?;
    let witness_validation = run_witness_validation(&suite)?;
    let seeded_witness_validation = run_seeded_witness_validation()?;
    Ok(json!({
        "static_checks": static_checks,
        "controller_observer_validation": controller_observer_validation,
        "pathoram_hidden_validation": pathoram_hidden_validation,
        "runtime_boundary_validation": runtime_boundary_validation,
        "kernel_model_alignment_validation": kernel_model_alignment_validation,
        "shell_boundary_validation": shell_boundary_validation,
        "shell_boundary_slot_validation": shell_boundary_slot_validation,
        "shell_boundary_lowering_validation": shell_boundary_lowering_validation,
        "confidential_fragment_validation": confidential_fragment_validation,
        "kernel_dsl_validation": kernel_dsl_validation,
        "kernel_slot_dsl_validation": kernel_slot_dsl_validation,
        "kernel_lowering_validation": kernel_lowering_validation,
        "confidential_core_validation": confidential_core_validation,
        "confidential_core_slot_validation": confidential_core_slot_validation,
        "confidential_core_shell_boundary_slot_validation":
            confidential_core_shell_boundary_slot_validation,
        "confidential_core_lowering_validation": confidential_core_lowering_validation,
        "confidential_core_shell_boundary_lowering_validation":
            confidential_core_shell_boundary_lowering_validation,
        "kernel_validation": kernel_validation,
        "kernel_refinement_validation": kernel_refinement_validation,
        "trusted_kernel_validation": trusted_kernel_validation,
        "tamper_validation": tamper_validation,
        "witness_validation": witness_validation,
        "seeded_witness_validation": seeded_witness_validation,
    }))
}

pub fn run_kernel_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_kernel_validation(&suite)
}

pub fn run_kernel_refinement_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_kernel_refinement_validation(&suite)
}

pub fn run_trusted_kernel_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_trusted_kernel_validation(&suite)
}

pub fn run_tamper_validation_report() -> Result<JsonValue> {
    run_tamper_validation()
}

pub fn run_witness_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_witness_validation(&suite)
}

pub fn run_seeded_witness_validation_report() -> Result<JsonValue> {
    run_seeded_witness_validation()
}

pub fn run_pathoram_pair_validation_report() -> Result<JsonValue> {
    run_pathoram_pair_validation()
}

pub fn run_controller_observer_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_controller_observer_validation(&suite)
}

pub fn run_pathoram_hidden_validation_report() -> Result<JsonValue> {
    run_pathoram_hidden_validation()
}

pub fn run_runtime_boundary_validation_report() -> Result<JsonValue> {
    run_runtime_boundary_validation()
}

pub fn run_kernel_model_alignment_validation_report() -> Result<JsonValue> {
    run_kernel_model_alignment_validation()
}

pub fn run_shell_boundary_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_shell_boundary_validation(&suite)
}

pub fn run_shell_boundary_slot_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_shell_boundary_slot_validation(&suite)
}

pub fn run_shell_boundary_lowering_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_shell_boundary_lowering_validation(&suite)
}

pub fn run_confidential_fragment_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_confidential_fragment_validation(&suite)
}

pub fn run_kernel_dsl_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_kernel_dsl_validation(&suite)
}

pub fn run_kernel_slot_dsl_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_kernel_slot_dsl_validation(&suite)
}

pub fn run_kernel_lowering_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_kernel_lowering_validation(&suite)
}

pub fn run_confidential_core_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_confidential_core_validation(&suite)
}

pub fn run_confidential_core_slot_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_confidential_core_slot_validation(&suite)
}

pub fn run_confidential_core_shell_boundary_slot_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_confidential_core_shell_boundary_slot_validation(&suite)
}

pub fn run_confidential_core_lowering_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_confidential_core_lowering_validation(&suite)
}

pub fn run_confidential_core_shell_boundary_lowering_validation_report() -> Result<JsonValue> {
    let suite = compile_suite()?;
    run_confidential_core_shell_boundary_lowering_validation(&suite)
}

pub fn run_reviewer_summary_report(options: &ProbeRunOptions) -> Result<JsonValue> {
    let report = run_probe_with_options(options)?;
    report
        .get("reviewer_summary")
        .cloned()
        .ok_or_else(|| anyhow!("reviewer_summary missing from probe bundle"))
}

pub fn run_canonical_pathoram_pair_validation_report() -> Result<JsonValue> {
    run_canonical_pathoram_pair_validation_with_options(&ProbeRunOptions::default())
}

pub fn run_canonical_pathoram_pair_validation_with_options(
    options: &ProbeRunOptions,
) -> Result<JsonValue> {
    run_canonical_pathoram_pair_validation(options)
}

pub fn write_results(out_dir: &str, results: &JsonValue) -> Result<()> {
    fs::create_dir_all(out_dir)?;
    if !results["artifact_configuration"].is_null() {
        let path = Path::new(out_dir).join("artifact_configuration.json");
        fs::write(
            path,
            serde_json::to_vec_pretty(&results["artifact_configuration"])?,
        )?;
    }
    for key in [
        "correctness",
        "static_checks",
        "bridge_validation",
        "trace_equivalence",
        "leakage_auc",
        "mutual_information",
        "overheads",
        "controller_observer_validation",
        "pathoram_hidden_validation",
        "runtime_boundary_validation",
        "kernel_model_alignment_validation",
        "shell_boundary_validation",
        "shell_boundary_slot_validation",
        "shell_boundary_lowering_validation",
        "confidential_fragment_validation",
        "kernel_dsl_validation",
        "kernel_slot_dsl_validation",
        "kernel_lowering_validation",
        "confidential_core_validation",
        "confidential_core_slot_validation",
        "confidential_core_shell_boundary_slot_validation",
        "confidential_core_lowering_validation",
        "confidential_core_shell_boundary_lowering_validation",
        "kernel_validation",
        "kernel_refinement_validation",
        "trusted_kernel_validation",
        "tamper_validation",
        "witness_validation",
        "seeded_witness_validation",
        "fresh_coin_validation",
        "pathoram_pair_validation",
        "canonical_pathoram_pair_validation",
        "reviewer_summary",
    ] {
        let path = Path::new(out_dir).join(format!("{key}.json"));
        fs::write(path, serde_json::to_vec_pretty(&results[key])?)?;
    }
    fs::write(
        Path::new(out_dir).join("artifact_readme.md"),
        results["artifact_readme"]
            .as_str()
            .ok_or_else(|| anyhow!("artifact_readme missing"))?,
    )?;
    if !results["reviewer_summary"].is_null() {
        write_reviewer_summary_markdown(out_dir, &results["reviewer_summary"])?;
    }
    write_reproducibility_manifest(out_dir)?;
    Ok(())
}

pub fn write_reproducibility_manifest(out_dir: &str) -> Result<()> {
    let root = Path::new(out_dir);
    fs::create_dir_all(root)?;
    let mut files = Vec::new();
    collect_bundle_files(root, root, &mut files)?;
    let entries = files
        .into_iter()
        .filter(|path| {
            path.file_name().and_then(|name| name.to_str()) != Some("reproducibility_manifest.json")
        })
        .map(|path| {
            let bytes = fs::read(&path)
                .with_context(|| format!("reading output file {}", path.display()))?;
            let relative = path
                .strip_prefix(root)
                .unwrap_or(&path)
                .display()
                .to_string();
            Ok(ReproducibilityManifestEntry {
                path: relative,
                bytes: bytes.len() as u64,
                sha256: hex::encode(Sha256::digest(&bytes)),
            })
        })
        .collect::<Result<Vec<_>>>()?;
    let manifest = ReproducibilityManifest {
        format_version: 1,
        file_count: entries.len(),
        files: entries,
    };
    fs::write(
        root.join("reproducibility_manifest.json"),
        serde_json::to_vec_pretty(&manifest)?,
    )?;
    Ok(())
}

fn collect_bundle_files(root: &Path, dir: &Path, files: &mut Vec<PathBuf>) -> Result<()> {
    let mut entries = fs::read_dir(dir)
        .with_context(|| format!("reading output directory {}", dir.display()))?
        .collect::<std::result::Result<Vec<_>, _>>()?;
    entries.sort_by(|lhs, rhs| lhs.path().cmp(&rhs.path()));
    for entry in entries {
        let path = entry.path();
        let file_type = entry
            .file_type()
            .with_context(|| format!("reading file type for {}", path.display()))?;
        if file_type.is_dir() {
            collect_bundle_files(root, &path, files)?;
        } else if file_type.is_file() {
            files.push(path);
        }
    }
    files.sort_by(|lhs, rhs| {
        lhs.strip_prefix(root)
            .unwrap_or(lhs)
            .cmp(rhs.strip_prefix(root).unwrap_or(rhs))
    });
    Ok(())
}

pub fn write_reviewer_summary_markdown(out_dir: &str, summary: &JsonValue) -> Result<()> {
    fs::write(
        Path::new(out_dir).join("reviewer_summary.md"),
        render_reviewer_summary_markdown(summary)?,
    )?;
    Ok(())
}

fn render_reviewer_summary_markdown(summary: &JsonValue) -> Result<String> {
    let mut out = String::from("# Reviewer Summary\n\n");

    out.push_str("## Proof And Report Cost\n\n");
    out.push_str("| Report | Milliseconds |\n");
    out.push_str("| --- | ---: |\n");
    if let Some(costs) = summary["proof_checking_cost_ms"].as_object() {
        let mut rows = costs
            .iter()
            .filter_map(|(name, value)| value.as_u64().map(|ms| (name.as_str(), ms)))
            .collect::<Vec<_>>();
        rows.sort_by(|lhs, rhs| rhs.1.cmp(&lhs.1).then_with(|| lhs.0.cmp(rhs.0)));
        for (name, ms) in rows {
            out.push_str(&format!("| `{}` | `{}` |\n", name, ms));
        }
    }
    out.push('\n');

    out.push_str("## Largest Materialized Artifacts\n\n");
    out.push_str("| Report Field | Bytes |\n");
    out.push_str("| --- | ---: |\n");
    if let Some(entries) =
        summary["artifact_size_bytes"]["top_materialized_report_fields"].as_array()
    {
        for entry in entries {
            let metric = entry["metric"].as_str().unwrap_or("unknown");
            let bytes = entry["bytes"].as_u64().unwrap_or_default();
            out.push_str(&format!("| `{}` | `{}` |\n", metric, bytes));
        }
    }
    out.push('\n');

    out.push_str("## Largest Estimated Artifacts\n\n");
    out.push_str("| Report Field | Estimated Bytes |\n");
    out.push_str("| --- | ---: |\n");
    if let Some(entries) = summary["artifact_size_bytes"]["top_estimated_report_fields"].as_array()
    {
        for entry in entries {
            let metric = entry["metric"].as_str().unwrap_or("unknown");
            let bytes = entry["bytes"].as_u64().unwrap_or_default();
            out.push_str(&format!("| `{}` | `{}` |\n", metric, bytes));
        }
    }
    out.push('\n');

    out.push_str("## Runtime Overheads\n\n");
    out.push_str(
        "| Benchmark | Raw Gas | Raw Writes | Raw Bytes | Full-Scan Gas | Full-Scan Writes | Full-Scan Bytes | ORAM Gas | ORAM Writes | ORAM Bytes |\n",
    );
    out.push_str("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n");
    if let Some(cases) = summary["runtime_overheads"]["cases"].as_array() {
        for case in cases {
            out.push_str(&format!(
                "| `{}` | `{}` | `{}` | `{}` | `{}` | `{}` | `{}` | `{}` | `{}` | `{}` |\n",
                case["benchmark"].as_str().unwrap_or("unknown"),
                case["raw"]["gas_used"].as_u64().unwrap_or_default(),
                case["raw"]["physical_writes"].as_u64().unwrap_or_default(),
                case["raw"]["bytes_written"].as_f64().unwrap_or_default(),
                case["full_scan_64"]["gas_used"]
                    .as_u64()
                    .unwrap_or_default(),
                case["full_scan_64"]["physical_writes"]
                    .as_u64()
                    .unwrap_or_default(),
                case["full_scan_64"]["bytes_written"]
                    .as_f64()
                    .unwrap_or_default(),
                case["oram_64"]["gas_used"].as_u64().unwrap_or_default(),
                case["oram_64"]["physical_writes"]
                    .as_u64()
                    .unwrap_or_default(),
                case["oram_64"]["bytes_written"]
                    .as_f64()
                    .unwrap_or_default(),
            ));
        }
    }
    out.push('\n');

    out.push_str("## TCB Surface\n\n");
    out.push_str("| Surface | Total Non-Empty LOC |\n");
    out.push_str("| --- | ---: |\n");
    out.push_str(&format!(
        "| Trusted Rust runtime surface | `{}` |\n",
        summary["tcb_size"]["trusted_runtime_surface"]["total_nonempty_loc"]
            .as_u64()
            .unwrap_or_default()
    ));
    out.push_str(&format!(
        "| Outer runtime risk surface | `{}` |\n",
        summary["tcb_size"]["outer_runtime_risk_surface"]["total_nonempty_loc"]
            .as_u64()
            .unwrap_or_default()
    ));
    out.push_str(&format!(
        "| Lean theorem/checker repo surface | `{}` |\n",
        summary["tcb_size"]["lean_theorem_checker_repo_surface"]["total_nonempty_loc"]
            .as_u64()
            .unwrap_or_default()
    ));
    out.push('\n');

    out.push_str("## Current TCB Table\n\n");
    out.push_str("| Component | In Current Proof-Grade TCB? | Role |\n");
    out.push_str("| --- | --- | --- |\n");
    if let Some(entries) = summary["current_tcb"].as_array() {
        for entry in entries {
            out.push_str(&format!(
                "| {} | `{}` | {} |\n",
                markdown_escape(entry["component"].as_str().unwrap_or("unknown")),
                entry["in_current_proofgrade_tcb"]
                    .as_bool()
                    .unwrap_or(false),
                markdown_escape(entry["role"].as_str().unwrap_or("unknown")),
            ));
        }
    }
    out.push('\n');

    out.push_str("## Explicit Assumptions\n\n");
    out.push_str("| Assumption | Meaning | Status |\n");
    out.push_str("| --- | --- | --- |\n");
    if let Some(entries) = summary["explicit_assumptions"].as_array() {
        for entry in entries {
            out.push_str(&format!(
                "| `{}` | {} | {} |\n",
                entry["assumption"].as_str().unwrap_or("unknown"),
                markdown_escape(entry["meaning"].as_str().unwrap_or("unknown")),
                markdown_escape(entry["status"].as_str().unwrap_or("unknown")),
            ));
        }
    }

    Ok(out)
}

fn markdown_escape(value: &str) -> String {
    value.replace('|', "\\|")
}

fn build_reviewer_summary(
    correctness: &JsonValue,
    static_checks: &JsonValue,
    trace_equivalence: &JsonValue,
    leakage_auc: &JsonValue,
    mutual_information: &JsonValue,
    overheads: &JsonValue,
    controller_observer_validation: &JsonValue,
    pathoram_hidden_validation: &JsonValue,
    runtime_boundary_validation: &JsonValue,
    kernel_model_alignment_validation: &JsonValue,
    shell_boundary_validation: &JsonValue,
    shell_boundary_slot_validation: &JsonValue,
    shell_boundary_lowering_validation: &JsonValue,
    confidential_fragment_validation: &JsonValue,
    kernel_dsl_validation: &JsonValue,
    kernel_slot_dsl_validation: &JsonValue,
    kernel_lowering_validation: &JsonValue,
    confidential_core_validation: &JsonValue,
    confidential_core_slot_validation: &JsonValue,
    confidential_core_shell_boundary_slot_validation: &JsonValue,
    confidential_core_lowering_validation: &JsonValue,
    confidential_core_shell_boundary_lowering_validation: &JsonValue,
    kernel_validation: &JsonValue,
    kernel_refinement_validation: &JsonValue,
    trusted_kernel_validation: &JsonValue,
    tamper_validation: &JsonValue,
    witness_validation: &JsonValue,
    seeded_witness_validation: &JsonValue,
    fresh_coin_validation: &JsonValue,
    pathoram_pair_validation: &JsonValue,
    canonical_pathoram_pair_validation: &JsonValue,
    report_timings_ms: &JsonValue,
) -> Result<JsonValue> {
    let mut artifact_size_metrics = Vec::new();
    for (report_name, report) in [
        ("correctness", correctness),
        ("static_checks", static_checks),
        ("trace_equivalence", trace_equivalence),
        ("leakage_auc", leakage_auc),
        ("mutual_information", mutual_information),
        ("overheads", overheads),
        (
            "controller_observer_validation",
            controller_observer_validation,
        ),
        ("pathoram_hidden_validation", pathoram_hidden_validation),
        ("runtime_boundary_validation", runtime_boundary_validation),
        (
            "kernel_model_alignment_validation",
            kernel_model_alignment_validation,
        ),
        ("shell_boundary_validation", shell_boundary_validation),
        (
            "shell_boundary_slot_validation",
            shell_boundary_slot_validation,
        ),
        (
            "shell_boundary_lowering_validation",
            shell_boundary_lowering_validation,
        ),
        (
            "confidential_fragment_validation",
            confidential_fragment_validation,
        ),
        ("kernel_dsl_validation", kernel_dsl_validation),
        ("kernel_slot_dsl_validation", kernel_slot_dsl_validation),
        ("kernel_lowering_validation", kernel_lowering_validation),
        ("confidential_core_validation", confidential_core_validation),
        (
            "confidential_core_slot_validation",
            confidential_core_slot_validation,
        ),
        (
            "confidential_core_shell_boundary_slot_validation",
            confidential_core_shell_boundary_slot_validation,
        ),
        (
            "confidential_core_lowering_validation",
            confidential_core_lowering_validation,
        ),
        (
            "confidential_core_shell_boundary_lowering_validation",
            confidential_core_shell_boundary_lowering_validation,
        ),
        ("kernel_validation", kernel_validation),
        ("kernel_refinement_validation", kernel_refinement_validation),
        ("trusted_kernel_validation", trusted_kernel_validation),
        ("tamper_validation", tamper_validation),
        ("witness_validation", witness_validation),
        ("seeded_witness_validation", seeded_witness_validation),
        ("fresh_coin_validation", fresh_coin_validation),
        ("pathoram_pair_validation", pathoram_pair_validation),
        (
            "canonical_pathoram_pair_validation",
            canonical_pathoram_pair_validation,
        ),
    ] {
        collect_json_byte_metrics(report_name, report, &mut artifact_size_metrics);
    }
    artifact_size_metrics.sort_by(|lhs, rhs| {
        rhs["bytes"]
            .as_u64()
            .cmp(&lhs["bytes"].as_u64())
            .then_with(|| lhs["metric"].as_str().cmp(&rhs["metric"].as_str()))
    });
    let (mut estimated_size_metrics, mut materialized_size_metrics): (Vec<_>, Vec<_>) =
        artifact_size_metrics
            .into_iter()
            .partition(|entry| entry["estimated"].as_bool().unwrap_or(false));
    estimated_size_metrics.sort_by(|lhs, rhs| {
        rhs["bytes"]
            .as_u64()
            .cmp(&lhs["bytes"].as_u64())
            .then_with(|| lhs["metric"].as_str().cmp(&rhs["metric"].as_str()))
    });
    materialized_size_metrics.sort_by(|lhs, rhs| {
        rhs["bytes"]
            .as_u64()
            .cmp(&lhs["bytes"].as_u64())
            .then_with(|| lhs["metric"].as_str().cmp(&rhs["metric"].as_str()))
    });
    estimated_size_metrics.truncate(10);
    materialized_size_metrics.truncate(20);

    Ok(json!({
        "proof_checking_cost_ms": report_timings_ms,
        "artifact_size_bytes": {
            "top_materialized_report_fields": materialized_size_metrics,
            "top_estimated_report_fields": estimated_size_metrics,
        },
        "runtime_overheads": overheads,
        "tcb_size": trusted_surface_loc_summary()?,
        "current_tcb": current_tcb_summary(),
        "explicit_assumptions": explicit_assumption_summary(),
    }))
}

fn collect_json_byte_metrics(report_name: &str, value: &JsonValue, out: &mut Vec<JsonValue>) {
    collect_json_byte_metrics_at(report_name, report_name, value, out);
}

fn collect_json_byte_metrics_at(
    report_name: &str,
    path: &str,
    value: &JsonValue,
    out: &mut Vec<JsonValue>,
) {
    match value {
        JsonValue::Object(map) => {
            for (key, nested) in map {
                let nested_path = format!("{path}.{key}");
                if key.ends_with("_json_bytes") {
                    if let Some(bytes) = nested.as_u64() {
                        out.push(json!({
                            "report": report_name,
                            "metric": nested_path,
                            "bytes": bytes,
                            "estimated": key.starts_with("estimated_")
                                || nested_path.contains(".estimated_"),
                        }));
                    }
                }
                collect_json_byte_metrics_at(report_name, &nested_path, nested, out);
            }
        }
        JsonValue::Array(items) => {
            for (idx, nested) in items.iter().enumerate() {
                let nested_path = format!("{path}[{idx}]");
                collect_json_byte_metrics_at(report_name, &nested_path, nested, out);
            }
        }
        _ => {}
    }
}

fn trusted_surface_loc_summary() -> Result<JsonValue> {
    const TRUSTED_RUNTIME_FILES: [&str; 4] = [
        "runtime/uo-evm/src/kernel.rs",
        "runtime/uo-evm/src/state.rs",
        "runtime/uo-evm/src/theorem.rs",
        "crates/uo-core/src/trace.rs",
    ];
    const OUTER_RUNTIME_RISK_FILES: [&str; 2] = [
        "runtime/uo-evm/src/engine.rs",
        "runtime/uo-evm/src/shell.rs",
    ];

    let trusted_runtime = loc_summary_for_files(&TRUSTED_RUNTIME_FILES)?;
    let outer_runtime = loc_summary_for_files(&OUTER_RUNTIME_RISK_FILES)?;
    let lean_root = repo_root().join("proof/lean");
    let lean_repo_surface =
        loc_summary_for_tree(&lean_root, "proof/lean", collect_lean_source_files)?;

    Ok(json!({
        "measurement": "non-empty source lines",
        "trusted_runtime_surface": trusted_runtime,
        "outer_runtime_risk_surface": outer_runtime,
        "lean_theorem_checker_repo_surface": lean_repo_surface,
    }))
}

fn loc_summary_for_files(files: &[&str]) -> Result<JsonValue> {
    let entries = files
        .iter()
        .map(|relative| {
            let path = repo_root().join(relative);
            Ok(json!({
                "file": relative,
                "nonempty_loc": count_nonempty_lines(&path)?,
            }))
        })
        .collect::<Result<Vec<_>>>()?;
    let total_nonempty_loc = entries
        .iter()
        .filter_map(|entry| entry["nonempty_loc"].as_u64())
        .sum::<u64>();
    Ok(json!({
        "file_count": entries.len(),
        "total_nonempty_loc": total_nonempty_loc,
        "files": entries,
    }))
}

fn loc_summary_for_tree(
    root: &Path,
    display_root: &str,
    collect: fn(&Path, &mut Vec<PathBuf>) -> Result<()>,
) -> Result<JsonValue> {
    let mut files = Vec::new();
    collect(root, &mut files)?;
    files.sort();
    let entries = files
        .into_iter()
        .map(|path| {
            Ok(json!({
                "file": path
                    .strip_prefix(repo_root())
                    .unwrap_or(&path)
                    .display()
                    .to_string(),
                "nonempty_loc": count_nonempty_lines(&path)?,
            }))
        })
        .collect::<Result<Vec<_>>>()?;
    let total_nonempty_loc = entries
        .iter()
        .filter_map(|entry| entry["nonempty_loc"].as_u64())
        .sum::<u64>();
    Ok(json!({
        "root": display_root,
        "file_count": entries.len(),
        "total_nonempty_loc": total_nonempty_loc,
        "files": entries,
    }))
}

fn count_nonempty_lines(path: &Path) -> Result<u64> {
    Ok(fs::read_to_string(path)
        .with_context(|| format!("reading {}", path.display()))?
        .lines()
        .filter(|line| !line.trim().is_empty())
        .count() as u64)
}

fn current_tcb_summary() -> JsonValue {
    json!([
        {
            "component": "Lean kernel plus Lean theorem/checker development",
            "role": "trusted proof checker and theorem body",
            "in_current_proofgrade_tcb": true,
        },
        {
            "component": "Explicit backend / cryptographic / deployment assumptions",
            "role": "trusted assumptions",
            "in_current_proofgrade_tcb": true,
        },
        {
            "component": "Rust runtime kernel plus witness / certificate / bundle extraction and serialization",
            "role": "currently trusted for implementation honesty",
            "in_current_proofgrade_tcb": true,
        },
        {
            "component": "Rust code outside the tiny kernel",
            "role": "still part of the implementation risk until confinement and refinement are proved",
            "in_current_proofgrade_tcb": true,
        },
        {
            "component": "uo-check",
            "role": "not in the proof-grade TCB",
            "in_current_proofgrade_tcb": false,
        },
        {
            "component": "mplus-probe",
            "role": "validation/reporting only",
            "in_current_proofgrade_tcb": false,
        },
        {
            "component": "uo-solc",
            "role": "not trusted for the current artifact-level acceptance claim; still unverified for the final source-level compiler theorem",
            "in_current_proofgrade_tcb": false,
        }
    ])
}

fn explicit_assumption_summary() -> JsonValue {
    json!([
        {
            "assumption": "bucketEncryptionINDCPA",
            "meaning": "hides bucket/path ciphertext contents for the concrete local-posmap backend",
            "status": "explicit Lean assumption in PathOramLocalPosmapV1SecurityAssumptions; not yet discharged in-repo",
        },
        {
            "assumption": "metadataEncryptionINDCPA",
            "meaning": "hides encrypted position-map metadata pages",
            "status": "explicit Lean assumption in PathOramLocalPosmapV1SecurityAssumptions; not yet discharged in-repo",
        },
        {
            "assumption": "stashOverflowBounded",
            "meaning": "bounds stash-overflow failure for the deployed parameters",
            "status": "explicit Lean assumption in PathOramLocalPosmapV1SecurityAssumptions; not yet fully discharged in-repo",
        },
        {
            "assumption": "TEE deployment assumptions",
            "meaning": "enclave memory confidentiality/integrity, attestation authenticity, rollback/freshness discipline, and the stated crash/patch model",
            "status": "required by the final malicious-host deployment theorem; not yet fully closed in Lean",
        }
    ])
}

fn compile_suite() -> Result<BTreeMap<&'static str, BenchArtifacts>> {
    let mut suite = BTreeMap::new();
    suite.insert(
        "FixedSlotClassifier",
        BenchArtifacts {
            raw: compile_artifact(
                "benches/raw/FixedSlotClassifier.sol",
                "benches/raw/FixedSlotClassifier.raw.yaml",
                ProgramMode::Raw,
            )?,
            uo: compile_artifact(
                "benches/raw/FixedSlotClassifier.sol",
                "benches/raw/FixedSlotClassifier.uo.yaml",
                ProgramMode::Uo,
            )?,
            oram: None,
            fullscan64: None,
        },
    );
    suite.insert(
        "AuthScan",
        BenchArtifacts {
            raw: compile_artifact(
                "benches/raw/AuthScan.sol",
                "benches/raw/AuthScan.raw.yaml",
                ProgramMode::Raw,
            )?,
            uo: compile_artifact(
                "benches/raw/AuthScan.sol",
                "benches/raw/AuthScan.uo.yaml",
                ProgramMode::Uo,
            )?,
            oram: None,
            fullscan64: None,
        },
    );
    suite.insert(
        "ConfidentialMixer",
        BenchArtifacts {
            raw: compile_artifact(
                "benches/raw/ConfidentialMixer.sol",
                "benches/raw/ConfidentialMixer.raw.yaml",
                ProgramMode::Raw,
            )?,
            uo: compile_artifact(
                "benches/raw/ConfidentialMixer.sol",
                "benches/raw/ConfidentialMixer.uo.yaml",
                ProgramMode::Uo,
            )?,
            oram: Some(compile_artifact(
                "benches/raw/ConfidentialMixer.sol",
                "benches/raw/ConfidentialMixer.oram.yaml",
                ProgramMode::Uo,
            )?),
            fullscan64: Some(compile_artifact(
                "benches/raw/ConfidentialMixer.sol",
                "benches/raw/ConfidentialMixer.fullscan64.yaml",
                ProgramMode::Uo,
            )?),
        },
    );
    suite.insert(
        "ERC20Lite",
        BenchArtifacts {
            raw: compile_artifact(
                "benches/raw/ERC20Lite.sol",
                "benches/raw/ERC20Lite.raw.yaml",
                ProgramMode::Raw,
            )?,
            uo: compile_artifact(
                "benches/raw/ERC20Lite.sol",
                "benches/raw/ERC20Lite.uo.yaml",
                ProgramMode::Uo,
            )?,
            oram: Some(compile_artifact(
                "benches/raw/ERC20Lite.sol",
                "benches/raw/ERC20Lite.oram.yaml",
                ProgramMode::Uo,
            )?),
            fullscan64: None,
        },
    );
    suite.insert(
        "RegistryCRUD",
        BenchArtifacts {
            raw: compile_artifact(
                "benches/raw/RegistryCRUD.sol",
                "benches/raw/RegistryCRUD.raw.yaml",
                ProgramMode::Raw,
            )?,
            uo: compile_artifact(
                "benches/raw/RegistryCRUD.sol",
                "benches/raw/RegistryCRUD.uo.yaml",
                ProgramMode::Uo,
            )?,
            oram: None,
            fullscan64: None,
        },
    );
    Ok(suite)
}

fn run_confidential_fragment_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let mut scenarios = Vec::new();
    let mut total_confidential_entrypoints = 0usize;
    let mut total_selects = 0usize;
    let mut total_struct_fields = 0usize;
    let mut total_array_indices = 0usize;
    let mut total_non_branchless_select_arms = 0usize;

    for (name, artifacts) in suite {
        for (variant, artifact) in artifact_variants(artifacts) {
            let witness = artifact.confidential_fragment_witness();
            for entrypoint in &witness.entrypoints {
                total_confidential_entrypoints += 1;
                total_selects += entrypoint.select_count;
                total_struct_fields += entrypoint.struct_field_count;
                total_array_indices += entrypoint.array_index_count;
                total_non_branchless_select_arms += entrypoint.non_branchless_select_arm_count;
                scenarios.push(json!({
                    "artifact": format!("{name}/{variant}"),
                    "contract": witness.contract.as_str(),
                    "entrypoint": entrypoint.entrypoint_id.as_str(),
                    "select_count": entrypoint.select_count,
                    "struct_field_count": entrypoint.struct_field_count,
                    "array_index_count": entrypoint.array_index_count,
                    "non_branchless_select_arm_count": entrypoint.non_branchless_select_arm_count,
                    "accepted": entrypoint.valid(),
                }));
            }
        }
    }

    Ok(json!({
        "scenario_count": scenarios.len(),
        "total_confidential_entrypoints": total_confidential_entrypoints,
        "total_selects": total_selects,
        "total_struct_fields": total_struct_fields,
        "total_array_indices": total_array_indices,
        "total_non_branchless_select_arms": total_non_branchless_select_arms,
        "scenarios": scenarios,
        "accepted": total_struct_fields == 0
            && total_array_indices == 0
            && total_non_branchless_select_arms == 0,
    }))
}

fn artifact_variants<'a>(
    artifacts: &'a BenchArtifacts,
) -> Vec<(&'static str, &'a CompiledArtifact)> {
    let mut variants = vec![("uo", &artifacts.uo)];
    if let Some(artifact) = &artifacts.oram {
        variants.push(("oram", artifact));
    }
    if let Some(artifact) = &artifacts.fullscan64 {
        variants.push(("fullscan64", artifact));
    }
    variants
}

fn compile_artifact(source: &str, metadata: &str, mode: ProgramMode) -> Result<CompiledArtifact> {
    let metadata_path = workspace_path(metadata);
    let source_path = workspace_path(source);
    let metadata: ContractMetadata = serde_yaml::from_slice(&fs::read(&metadata_path)?)?;
    uo_solc::compile(source_path.to_str().unwrap(), &metadata, mode)
}

fn load_metadata(metadata_path: &str) -> Result<ContractMetadata> {
    Ok(serde_yaml::from_slice(&fs::read(workspace_path(
        metadata_path,
    ))?)?)
}

fn workspace_path(path: &str) -> PathBuf {
    let path = Path::new(path);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(path)
    }
}

fn check_source_report(source_path: &str, metadata: &ContractMetadata) -> Result<Vec<String>> {
    let report = uo_solc::validate_source(source_path, metadata)?;
    let mut lines = Vec::new();
    lines.push(format!("validated contract {}", report.contract_name));
    lines.push(format!("entrypoints: {}", report.entrypoints.join(", ")));
    if report.diagnostics.is_empty() {
        lines.push("diagnostics: none".into());
    } else {
        lines.push(format!("diagnostics: {}", report.diagnostics.join(" | ")));
    }
    Ok(lines)
}

fn run_static_checks(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let checker = lean_proofgrade_translation_artifacts_checker_path()?;
    let proof_lean_root = workspace_path("proof/lean");
    let proof_lean_uotoolchain = proof_lean_root.join("UOToolchain");
    let legacy_axiom_definition_checks = [
        (
            "axiom legacySgxMicroLocalTheorem",
            vec![String::from("proof/lean/UOToolchain/SgxMicroGame.lean")],
        ),
        (
            "axiom legacyOramLocalTheorem",
            vec![String::from("proof/lean/UOToolchain/OramGame.lean")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_lean_pattern_hits(&proof_lean_uotoolchain, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let legacy_axiom_definition_surface_restricted =
        legacy_axiom_definition_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("legacy axiom restriction flag must be boolean")
        });
    let legacy_theorem_symbol_surface_checks = [
        (
            "legacySgxMicroLocalTheorem",
            vec![
                String::from("proof/lean/UOToolchain/LegacySgxJointProjection.lean"),
                String::from("proof/lean/UOToolchain/SgxMicroGame.lean"),
            ],
        ),
        (
            "legacyOramLocalTheorem",
            vec![
                String::from("proof/lean/UOToolchain/LegacySgxJointProjection.lean"),
                String::from("proof/lean/UOToolchain/LegacySgxOramProjection.lean"),
                String::from("proof/lean/UOToolchain/LegacyTeeDeployment.lean"),
                String::from("proof/lean/UOToolchain/OramGame.lean"),
            ],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_lean_pattern_hits(&proof_lean_uotoolchain, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let legacy_theorem_symbol_surface_restricted =
        legacy_theorem_symbol_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("legacy theorem symbol restriction flag must be boolean")
        });
    let proofgrade_checker_legacy_symbol_checks =
        ["legacySgxMicroLocalTheorem", "legacyOramLocalTheorem"]
            .into_iter()
            .map(|pattern| {
                let mut files = Vec::new();
                for entry in fs::read_dir(&proof_lean_root)
                    .with_context(|| format!("reading {}", proof_lean_root.display()))?
                {
                    let entry = entry?;
                    let path = entry.path();
                    let is_checker = path.extension().is_some_and(|ext| ext == "lean")
                        && path
                            .file_name()
                            .and_then(|name| name.to_str())
                            .is_some_and(|name| name.starts_with("Check"));
                    if !is_checker {
                        continue;
                    }
                    let source = fs::read_to_string(&path)
                        .with_context(|| format!("reading {}", path.display()))?;
                    if source.contains(pattern) {
                        files.push(display_report_path(&path));
                    }
                }
                files.sort();
                Ok(json!({
                    "pattern": pattern,
                    "files": files,
                    "absent": files.is_empty(),
                }))
            })
            .collect::<Result<Vec<_>>>()?;
    let proofgrade_checker_legacy_symbol_mentions_absent =
        proofgrade_checker_legacy_symbol_checks.iter().all(|entry| {
            entry["absent"]
                .as_bool()
                .expect("checker legacy-symbol absence flag must be boolean")
        });
    let proofgrade_checker_import_surface_checks = {
        let mut checks = Vec::new();
        for entry in fs::read_dir(&proof_lean_root)
            .with_context(|| format!("reading {}", proof_lean_root.display()))?
        {
            let entry = entry?;
            let path = entry.path();
            let is_checker = path.extension().is_some_and(|ext| ext == "lean")
                && path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .is_some_and(|name| name.starts_with("Check"));
            if !is_checker {
                continue;
            }
            let source =
                fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
            let uses_proofgrade_umbrella = source
                .lines()
                .any(|line| line.trim() == "import UOToolchain.ProofGrade");
            let uses_legacy_umbrella = source
                .lines()
                .any(|line| line.trim() == "import UOToolchain");
            checks.push(json!({
                "file": display_report_path(&path),
                "uses_proofgrade_umbrella": uses_proofgrade_umbrella,
                "uses_legacy_umbrella": uses_legacy_umbrella,
                "restricted": uses_proofgrade_umbrella && !uses_legacy_umbrella,
            }));
        }
        checks.sort_by(|lhs, rhs| {
            lhs["file"]
                .as_str()
                .expect("checker import-surface file must be string")
                .cmp(
                    rhs["file"]
                        .as_str()
                        .expect("checker import-surface file must be string"),
                )
        });
        checks
    };
    let proofgrade_checker_import_surface_restricted = proofgrade_checker_import_surface_checks
        .iter()
        .all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("checker import-surface restriction flag must be boolean")
        });
    let forbidden_legacy_imports = [
        "import UOToolchain",
        "import UOToolchain.OramGame",
        "import UOToolchain.SgxMicroGame",
        "import UOToolchain.LegacyComposition",
        "import UOToolchain.LegacyTeeDeployment",
        "import UOToolchain.LegacySgxOramProjection",
        "import UOToolchain.LegacySgxJointProjection",
    ];
    let proofgrade_core_module_import_surface_checks = [
        "proof/lean/UOToolchain/ProofGrade.lean",
        "proof/lean/UOToolchain/Composition.lean",
        "proof/lean/UOToolchain/TeeDeployment.lean",
        "proof/lean/UOToolchain/SgxOramProjection.lean",
        "proof/lean/UOToolchain/SgxJointProjection.lean",
        "proof/lean/UOToolchain/StandardOramReduction.lean",
        "proof/lean/UOToolchain/RuntimeRefinement.lean",
        "proof/lean/UOToolchain/RuntimeCoins.lean",
        "proof/lean/UOToolchain/PathOramLocalPosmapV1.lean",
    ]
    .into_iter()
    .map(|relative_path| {
        let path = workspace_path(relative_path);
        let source =
            fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        let forbidden_import_hits = forbidden_legacy_imports
            .iter()
            .filter(|pattern| source.lines().any(|line| line.trim() == **pattern))
            .map(|pattern| String::from(*pattern))
            .collect::<Vec<_>>();
        Ok(json!({
            "file": relative_path,
            "forbidden_import_hits": forbidden_import_hits,
            "restricted": forbidden_import_hits.is_empty(),
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let proofgrade_core_module_import_surface_restricted =
        proofgrade_core_module_import_surface_checks
            .iter()
            .all(|entry| {
                entry["restricted"]
                    .as_bool()
                    .expect("core module import-surface restriction flag must be boolean")
            });
    let mut reports = Vec::new();
    for (name, artifacts) in suite {
        let source = format!("benches/raw/{name}.sol");
        let source_path = workspace_path(&source);
        let raw_meta = format!("benches/raw/{name}.raw.yaml");
        let raw_metadata = load_metadata(&raw_meta)?;
        let uo_meta = format!("benches/raw/{name}.uo.yaml");
        let uo_metadata = load_metadata(&uo_meta)?;
        let oram_meta = format!("benches/raw/{name}.oram.yaml");
        let oram_metadata = workspace_path(&oram_meta)
            .exists()
            .then(|| load_metadata(&oram_meta))
            .transpose()?;
        let fullscan64_meta = format!("benches/raw/{name}.fullscan64.yaml");
        let fullscan64_metadata = workspace_path(&fullscan64_meta)
            .exists()
            .then(|| load_metadata(&fullscan64_meta))
            .transpose()?;
        reports.push(json!({
            "benchmark": name,
            "source_raw": check_source_report(source_path.to_str().unwrap(), &raw_metadata)?,
            "source_uo": check_source_report(source_path.to_str().unwrap(), &uo_metadata)?,
            "raw_artifact": validate_translation_artifacts_against_source(
                &format!("{name}-raw-artifact"),
                source_path.to_str().unwrap(),
                &raw_metadata,
                &artifacts.raw,
                &checker,
            )?,
            "uo_artifact": validate_translation_artifacts_against_source(
                &format!("{name}-uo-artifact"),
                source_path.to_str().unwrap(),
                &uo_metadata,
                &artifacts.uo,
                &checker,
            )?,
            "oram_artifact": artifacts
                .oram
                .as_ref()
                .zip(oram_metadata.as_ref())
                .map(|(artifact, metadata)| {
                    validate_translation_artifacts_against_source(
                        &format!("{name}-oram-artifact"),
                        source_path.to_str().unwrap(),
                        metadata,
                        artifact,
                        &checker,
                    )
                })
                .transpose()?,
            "fullscan64_artifact": artifacts
                .fullscan64
                .as_ref()
                .zip(fullscan64_metadata.as_ref())
                .map(|(artifact, metadata)| {
                    validate_translation_artifacts_against_source(
                        &format!("{name}-fullscan64-artifact"),
                        source_path.to_str().unwrap(),
                        metadata,
                        artifact,
                        &checker,
                    )
                })
                .transpose()?,
        }));
    }
    Ok(json!({
        "checker": display_report_path(&checker),
        "legacy_axiom_definition_checks": legacy_axiom_definition_checks,
        "legacy_axiom_definition_surface_restricted":
            legacy_axiom_definition_surface_restricted,
        "legacy_theorem_symbol_surface_checks":
            legacy_theorem_symbol_surface_checks,
        "legacy_theorem_symbol_surface_restricted":
            legacy_theorem_symbol_surface_restricted,
        "proofgrade_checker_legacy_symbol_checks":
            proofgrade_checker_legacy_symbol_checks,
        "proofgrade_checker_legacy_symbol_mentions_absent":
            proofgrade_checker_legacy_symbol_mentions_absent,
        "proofgrade_checker_import_surface_checks":
            proofgrade_checker_import_surface_checks,
        "proofgrade_checker_import_surface_restricted":
            proofgrade_checker_import_surface_restricted,
        "proofgrade_core_module_import_surface_checks":
            proofgrade_core_module_import_surface_checks,
        "proofgrade_core_module_import_surface_restricted":
            proofgrade_core_module_import_surface_restricted,
        "reports": reports,
    }))
}

fn validate_translation_artifacts_against_source(
    case_name: &str,
    source_path: &str,
    metadata: &ContractMetadata,
    artifact: &CompiledArtifact,
    checker: &Path,
) -> Result<JsonValue> {
    let expected = uo_solc::compile(source_path, metadata, artifact.contract.mode.clone())?;
    let source_artifact_case_name = format!("{case_name}-source-artifact");
    let artifact_case_name = format!("{case_name}-artifact");
    let (source_artifact_path, source_artifact_json_bytes) =
        write_temp_json(&source_artifact_case_name, &expected)?;
    let (artifact_path, artifact_json_bytes) = write_temp_json(&artifact_case_name, artifact)?;
    let output = Command::new(checker)
        .arg(&metadata.contract)
        .arg(&source_artifact_path)
        .arg(&artifact_path)
        .output()?;
    let _ = fs::remove_file(&source_artifact_path);
    let _ = fs::remove_file(&artifact_path);
    let lean_stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let lean_stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    let accepted = output.status.success();
    Ok(json!({
        "contract": artifact.contract.contract,
        "mode": match artifact.contract.mode {
            ProgramMode::Raw => "raw",
            ProgramMode::Uo => "uo",
        },
        "metadata_contract": metadata.contract,
        "state_object_count": artifact.contract.state.len(),
        "function_count": artifact.contract.functions.len(),
        "manifest_object_count": artifact.contract.manifest.objects.len(),
        "manifest_entrypoint_count": artifact.contract.manifest.entrypoints.len(),
        "source_artifact_json_bytes": source_artifact_json_bytes,
        "artifact_json_bytes": artifact_json_bytes,
        "lean_stdout": lean_stdout,
        "lean_stderr": lean_stderr,
        "accepted": accepted,
    }))
}

fn run_correctness(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let mut scenarios = Vec::new();
    scenarios.push(
        check_classifier_correctness(&suite["FixedSlotClassifier"])
            .context("correctness/FixedSlotClassifier")?,
    );
    scenarios.push(check_authscan_correctness(&suite["AuthScan"]).context("correctness/AuthScan")?);
    scenarios.push(
        check_mixer_correctness(&suite["ConfidentialMixer"])
            .context("correctness/ConfidentialMixer")?,
    );
    scenarios.push(check_erc20_correctness(&suite["ERC20Lite"]).context("correctness/ERC20Lite")?);
    scenarios.push(
        check_registry_correctness(&suite["RegistryCRUD"]).context("correctness/RegistryCRUD")?,
    );
    Ok(json!({ "scenarios": scenarios }))
}

fn run_controller_observer_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_controller_certificate_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let auth_setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    let erc20_setup = vec![CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![addr(0x11), Value::Uint(10)],
    }];
    let erc20_transfer_setup = vec![
        CallSpec {
            entrypoint: "mint(address,uint256)",
            args: vec![addr(0x11), Value::Uint(10)],
        },
        CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
    ];
    let excluded_scenarios = vec![
        json!({
            "scenario": "ConfidentialMixer/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ConfidentialMixer/pathoram/*; the theorem-facing controller certificate is reported only once under the explicit pathoram name"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ERC20Lite/pathoram/*; the theorem-facing controller certificate is reported only once under the explicit pathoram name"
        }),
    ];

    let mut scenarios = Vec::new();
    scenarios.push(validate_controller_certificate_case(
        "FixedSlotClassifier/uo/class0",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "FixedSlotClassifier/uo/class1",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "AuthScan/uo/class0",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(9)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "AuthScan/uo/class1",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "RegistryCRUD/uo/class0",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "RegistryCRUD/uo/class1",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "ConfidentialMixer/fullscan/class0",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "ConfidentialMixer/fullscan/class1",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "ERC20Lite/fullscan/class0",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "ERC20Lite/fullscan/class1",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "SingleAccessMap/pathoram/put-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "SingleAccessMap/pathoram/put-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "SingleAccessMap/pathoram/add-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "SingleAccessMap/pathoram/add-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "ConfidentialMixer/pathoram/deposit",
        &mixer_pathoram,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_controller_certificate_case(
        "ERC20Lite/pathoram/transferFrom",
        &erc20_pathoram,
        &erc20_transfer_setup,
        &CallSpec {
            entrypoint: "transferFrom(address,address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
        },
        &checker,
    )?);

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
        "accepted": true,
    }))
}

fn run_pathoram_hidden_validation() -> Result<JsonValue> {
    let checker = lean_pathoram_hidden_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let scenarios = vec![
        validate_pathoram_hidden_case(
            "SingleAccessMap/pathoram/put-class0",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &checker,
        )?,
        validate_pathoram_hidden_case(
            "SingleAccessMap/pathoram/put-class1",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(7)],
            },
            &checker,
        )?,
        validate_pathoram_hidden_case(
            "SingleAccessMap/pathoram/add-class0",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &checker,
        )?,
        validate_pathoram_hidden_case(
            "SingleAccessMap/pathoram/add-class1",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(7)],
            },
            &checker,
        )?,
        validate_pathoram_hidden_case(
            "ConfidentialMixer/pathoram/deposit",
            &mixer_pathoram,
            &[],
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(5), Value::Uint(1)],
            },
            &checker,
        )?,
        validate_pathoram_hidden_case(
            "ERC20Lite/pathoram/transferFrom",
            &erc20_pathoram,
            &[
                CallSpec {
                    entrypoint: "mint(address,uint256)",
                    args: vec![addr(0x11), Value::Uint(10)],
                },
                CallSpec {
                    entrypoint: "approve(address,address,uint256)",
                    args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
                },
            ],
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
            },
            &checker,
        )?,
    ];

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_tamper_validation() -> Result<JsonValue> {
    let source_path = "benches/raw/SingleAccessMap.sol";
    let metadata_path = "benches/raw/SingleAccessMap.pathoram.yaml";
    let metadata = load_metadata(metadata_path)?;
    let source_artifact = uo_solc::compile(
        workspace_path(source_path).to_str().unwrap(),
        &metadata,
        ProgramMode::Uo,
    )?;
    let artifact = compile_artifact(source_path, metadata_path, ProgramMode::Uo)?;
    let target = CallSpec {
        entrypoint: "put(bytes32,uint256)",
        args: vec![b32(1), Value::Uint(7)],
    };
    let pair_target = CallSpec {
        entrypoint: "put(bytes32,uint256)",
        args: vec![b32(9), Value::Uint(7)],
    };
    let trace = run_target_call(&artifact, &[], target.entrypoint, target.args.clone())?;
    let controller_certificate = trace.runtime_controller_observer_certificate()?;
    let hidden_certificate = trace.runtime_path_oram_hidden_certificate()?;
    let kernel_witness =
        exact_confidential_kernel_witness(&trace, &artifact, target.entrypoint)?
            .ok_or_else(|| anyhow!("tamper validation scenario is not confidential"))?;
    if trace.runtime_kernel_witness() != Some(&kernel_witness) {
        return Err(anyhow!(
            "tamper validation scenario did not preserve the exact runtime kernel witness"
        ));
    }
    let runtime_kernel_refinement_witness = trace
        .runtime_kernel_refinement_witness()
        .cloned()
        .ok_or_else(|| {
            anyhow!("tamper validation scenario is missing runtime kernel refinement witness")
        })?;
    runtime_kernel_refinement_witness.validate_with_kernel_witness(&kernel_witness)?;
    let runtime_witness = trace.runtime_refinement_witness()?;
    let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
    let kernel_dsl_bundle = artifact
        .runtime_kernel_dsl_bundle_for_entrypoint(kernel_witness.clone(), target.entrypoint)?;
    let kernel_slot_dsl_bundle = artifact
        .runtime_kernel_slot_dsl_bundle_for_entrypoint(kernel_witness.clone(), target.entrypoint)?;
    let kernel_lowering_bundle = artifact
        .runtime_kernel_lowering_bundle_for_entrypoint(kernel_witness.clone(), target.entrypoint)?;
    let shell_boundary_slot_bundle = trace.runtime_shell_boundary_slot_bundle(&artifact)?;
    let shell_boundary_lowering_bundle = trace.runtime_shell_boundary_lowering_bundle(&artifact)?;
    let confidential_core_bundle = trace.runtime_confidential_core_bundle(&artifact)?;
    let confidential_core_slot_bundle = trace.runtime_confidential_core_slot_bundle(&artifact)?;
    let confidential_core_lowering_bundle =
        trace.runtime_confidential_core_lowering_bundle(&artifact)?;
    let confidential_core_shell_boundary_slot_bundle =
        trace.runtime_confidential_core_shell_boundary_slot_bundle(&artifact)?;
    let confidential_core_shell_boundary_lowering_bundle =
        trace.runtime_confidential_core_shell_boundary_lowering_bundle(&artifact)?;
    let trusted_kernel_bundle = trace.runtime_trusted_kernel_slot_bundle(&artifact)?;

    let translation_checker = lean_proofgrade_translation_artifacts_checker_path()?;
    let controller_checker = lean_controller_certificate_checker_path()?;
    let hidden_checker = lean_pathoram_hidden_checker_path()?;
    let kernel_dsl_checker = lean_proofgrade_kernel_dsl_checker_path()?;
    let kernel_slot_dsl_checker = lean_proofgrade_kernel_slot_dsl_checker_path()?;
    let kernel_lowering_checker = lean_proofgrade_kernel_lowering_checker_path()?;
    let kernel_checker = lean_proofgrade_kernel_checker_path()?;
    let kernel_refinement_checker = lean_proofgrade_kernel_refinement_checker_path()?;
    let shell_boundary_checker = lean_proofgrade_shell_boundary_checker_path()?;
    let shell_boundary_slot_checker = lean_proofgrade_shell_boundary_slot_checker_path()?;
    let shell_boundary_lowering_checker = lean_proofgrade_shell_boundary_lowering_checker_path()?;
    let confidential_core_checker = lean_proofgrade_confidential_core_checker_path()?;
    let confidential_core_slot_checker = lean_proofgrade_confidential_core_slot_checker_path()?;
    let confidential_core_shell_boundary_slot_checker =
        lean_proofgrade_confidential_core_shell_boundary_slot_checker_path()?;
    let confidential_core_lowering_checker =
        lean_proofgrade_confidential_core_lowering_checker_path()?;
    let confidential_core_shell_boundary_lowering_checker =
        lean_proofgrade_confidential_core_shell_boundary_lowering_checker_path()?;
    let witness_checker = lean_proofgrade_witness_checker_path()?;
    let trusted_kernel_checker = lean_proofgrade_trusted_kernel_checker_path()?;
    let witness_family_checker = lean_witness_family_checker_path()?;
    let fresh_coin_family_checker = lean_fresh_coin_family_checker_path()?;
    let fresh_coin_theorem_input_checker = lean_fresh_coin_theorem_input_checker_path()?;
    let pathoram_pair_checker = lean_pathoram_pair_checker_path()?;
    let canonical_pathoram_pair_checker = lean_canonical_pathoram_pair_checker_path()?;
    let canonical_pathoram_paper_instantiation_checker =
        lean_canonical_pathoram_paper_instantiation_checker_path()?;
    let canonical_pathoram_pair_theorem_input_checker =
        lean_canonical_pathoram_pair_theorem_input_checker_path()?;

    let mut scenarios = Vec::new();

    let mut tampered_translation_artifact = artifact.clone();
    let manifest_entry = tampered_translation_artifact
        .contract
        .manifest
        .entrypoints
        .get_mut(target.entrypoint)
        .ok_or_else(|| anyhow!("translation tamper scenario missing manifest entrypoint"))?;
    manifest_entry.public_gas_budget = manifest_entry.public_gas_budget.saturating_add(1);
    scenarios.push(validate_tampered_json_pair_case(
        "translation/public_gas_budget_drift",
        "source_artifact",
        &source_artifact,
        "artifact",
        &tampered_translation_artifact,
        |source_artifact_path, artifact_path| {
            Ok(Command::new(&translation_checker)
                .arg(&metadata.contract)
                .arg(source_artifact_path)
                .arg(artifact_path)
                .output()?)
        },
        json!({
            "scenario": "translation/public_gas_budget_drift",
            "artifact_kind": "proofgrade_translation_artifacts",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "increment manifest public_gas_budget while keeping source artifact fixed",
        }),
    )?);

    let mut tampered_controller_certificate = serde_json::to_value(&controller_certificate)?;
    let observed_access = tampered_controller_certificate
        .get_mut("controller_certificate")
        .and_then(JsonValue::as_object_mut)
        .and_then(|certificate| certificate.get_mut("observed_oram_accesses"))
        .and_then(JsonValue::as_array_mut)
        .and_then(|accesses| accesses.first_mut())
        .and_then(JsonValue::as_object_mut)
        .ok_or_else(|| anyhow!("controller tamper scenario missing observed ORAM access"))?;
    let recursion_depth = observed_access
        .get("recursion_depth")
        .and_then(JsonValue::as_u64)
        .ok_or_else(|| anyhow!("controller tamper scenario missing recursion_depth"))?;
    observed_access.insert(
        "recursion_depth".into(),
        json!(recursion_depth.saturating_add(1)),
    );
    scenarios.push(validate_tampered_json_case(
        "controller/controller_shape_drift",
        &tampered_controller_certificate,
        |certificate_path| {
            Ok(Command::new(&controller_checker)
                .arg(certificate_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "controller/controller_shape_drift",
            "artifact_kind": "runtime_controller_observer_certificate",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "increment first observed ORAM access recursion_depth",
        }),
    )?);

    let mut tampered_hidden_certificate = serde_json::to_value(&hidden_certificate)?;
    let first_leaf = tampered_hidden_certificate
        .get_mut("oram_position_map_after")
        .and_then(JsonValue::as_array_mut)
        .and_then(|maps| maps.first_mut())
        .and_then(JsonValue::as_object_mut)
        .and_then(|position_map| position_map.get_mut("leaves"))
        .and_then(JsonValue::as_array_mut)
        .and_then(|leaves| leaves.first_mut())
        .ok_or_else(|| anyhow!("hidden-state tamper scenario missing position-map leaf"))?;
    let drifted_leaf = match first_leaf.as_u64() {
        Some(leaf) => json!(leaf.saturating_add(1)),
        None => json!(0),
    };
    *first_leaf = drifted_leaf;
    scenarios.push(validate_tampered_json_case(
        "hidden/path_oram_leaf_state_drift",
        &tampered_hidden_certificate,
        |certificate_path| {
            Ok(Command::new(&hidden_checker)
                .arg(certificate_path)
                .output()?)
        },
        json!({
            "scenario": "hidden/path_oram_leaf_state_drift",
            "artifact_kind": "runtime_path_oram_hidden_certificate",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "drift first hidden position-map leaf after the call",
        }),
    )?);

    let original_kernel_dsl_statement_count = kernel_dsl_bundle.confidential_program().body.len();
    let mut tampered_kernel_dsl_bundle = serde_json::to_value(&kernel_dsl_bundle)?;
    let kernel_dsl_body = tampered_kernel_dsl_bundle["confidential_program"]["body"]
        .as_array_mut()
        .ok_or_else(|| anyhow!("kernel DSL tamper scenario missing confidential program body"))?;
    if kernel_dsl_body.pop().is_none() {
        return Err(anyhow!(
            "kernel DSL tamper scenario missing confidential program body"
        ));
    }
    let tampered_kernel_dsl_statement_count = kernel_dsl_body.len();
    scenarios.push(validate_tampered_json_case(
        "kernel_dsl/program_body_drift",
        &tampered_kernel_dsl_bundle,
        |bundle_path| {
            Ok(Command::new(&kernel_dsl_checker)
                .arg(bundle_path)
                .output()?)
        },
        json!({
            "scenario": "kernel_dsl/program_body_drift",
            "artifact_kind": "proofgrade_runtime_kernel_dsl_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final named confidential-kernel statement",
            "statement_count_before": original_kernel_dsl_statement_count,
            "statement_count_after": tampered_kernel_dsl_statement_count,
        }),
    )?);

    let original_kernel_slot_statement_count = kernel_slot_dsl_bundle
        .confidential_slot_program()
        .body
        .len();
    let mut tampered_kernel_slot_dsl_bundle = serde_json::to_value(&kernel_slot_dsl_bundle)?;
    let kernel_slot_dsl_body = tampered_kernel_slot_dsl_bundle["confidential_slot_program"]["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!("kernel slot DSL tamper scenario missing confidential slot program body")
        })?;
    if kernel_slot_dsl_body.pop().is_none() {
        return Err(anyhow!(
            "kernel slot DSL tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_kernel_slot_statement_count = kernel_slot_dsl_body.len();
    scenarios.push(validate_tampered_json_case(
        "kernel_slot_dsl/program_body_drift",
        &tampered_kernel_slot_dsl_bundle,
        |bundle_path| {
            Ok(Command::new(&kernel_slot_dsl_checker)
                .arg(bundle_path)
                .output()?)
        },
        json!({
            "scenario": "kernel_slot_dsl/program_body_drift",
            "artifact_kind": "proofgrade_runtime_kernel_slot_dsl_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement",
            "statement_count_before": original_kernel_slot_statement_count,
            "statement_count_after": tampered_kernel_slot_statement_count,
        }),
    )?);

    let original_kernel_lowering_slot_statement_count = kernel_lowering_bundle
        .confidential_slot_program()
        .body
        .len();
    let mut tampered_kernel_lowering_bundle = serde_json::to_value(&kernel_lowering_bundle)?;
    let kernel_lowering_slot_body = tampered_kernel_lowering_bundle["confidential_slot_program"]
        ["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!("kernel lowering tamper scenario missing confidential slot program body")
        })?;
    if kernel_lowering_slot_body.pop().is_none() {
        return Err(anyhow!(
            "kernel lowering tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_kernel_lowering_slot_statement_count = kernel_lowering_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "kernel_lowering/slot_program_body_drift",
        &tampered_kernel_lowering_bundle,
        |bundle_path| Ok(Command::new(&kernel_lowering_checker).arg(bundle_path).output()?),
        json!({
            "scenario": "kernel_lowering/slot_program_body_drift",
            "artifact_kind": "proofgrade_runtime_kernel_lowering_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the named program fixed",
            "statement_count_before": original_kernel_lowering_slot_statement_count,
            "statement_count_after": tampered_kernel_lowering_slot_statement_count,
        }),
    )?);

    let mut tampered_kernel_witness = kernel_witness.clone();
    let object_step = tampered_kernel_witness
        .kernel_steps
        .iter_mut()
        .find(|step| step.object_id.is_some())
        .ok_or_else(|| anyhow!("kernel tamper scenario missing object-bearing kernel step"))?;
    object_step.object_id = object_step
        .object_id
        .map(|object_id| object_id.saturating_add(1));
    scenarios.push(validate_tampered_json_case(
        "kernel/kernel_step_object_drift",
        &tampered_kernel_witness,
        |kernel_path| {
            Ok(Command::new(&kernel_checker)
                .arg(kernel_path)
                .arg(target.entrypoint)
                .output()?)
        },
        json!({
            "scenario": "kernel/kernel_step_object_drift",
            "artifact_kind": "proofgrade_runtime_kernel_witness",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "drift the first object-bearing kernel step object_id",
        }),
    )?);

    let mut tampered_kernel_refinement_events = runtime_kernel_refinement_witness.events().to_vec();
    let object_event = tampered_kernel_refinement_events
        .iter_mut()
        .find(|event| event.object_id.is_some())
        .ok_or_else(|| anyhow!("kernel refinement tamper scenario missing object-bearing event"))?;
    object_event.object_id = object_event
        .object_id
        .map(|object_id| object_id.saturating_add(1));
    let tampered_kernel_refinement_witness =
        RuntimeKernelRefinementWitness::from_events(tampered_kernel_refinement_events);
    scenarios.push(validate_tampered_json_pair_case(
        "kernel_refinement/object_schedule_drift",
        "kernel_refinement_witness",
        &tampered_kernel_refinement_witness,
        "kernel_witness",
        &kernel_witness,
        |refinement_path, kernel_path| {
            Ok(Command::new(&kernel_refinement_checker)
                .arg(refinement_path)
                .arg(kernel_path)
                .arg(target.entrypoint)
                .output()?)
        },
        json!({
            "scenario": "kernel_refinement/object_schedule_drift",
            "artifact_kind": "proofgrade_runtime_kernel_refinement_witness",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "drift the first object-bearing runtime-phase event object_id",
        }),
    )?);

    let mut tampered_shell_boundary_bundle = serde_json::to_value(&shell_boundary_bundle)?;
    tampered_shell_boundary_bundle["shell_trace"]["commit_object_schedule"] = json!([]);
    scenarios.push(validate_tampered_json_case(
        "shell_boundary/trace_summary_drift",
        &tampered_shell_boundary_bundle,
        |bundle_path| Ok(Command::new(&shell_boundary_checker).arg(bundle_path).output()?),
        json!({
            "scenario": "shell_boundary/trace_summary_drift",
            "artifact_kind": "proofgrade_runtime_shell_boundary_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "erase shell-trace commit_object_schedule while leaving the event trace fixed",
        }),
    )?);

    let original_shell_boundary_lowering_slot_statement_count = shell_boundary_lowering_bundle
        .confidential_slot_program()
        .body
        .len();
    let mut tampered_shell_boundary_lowering_bundle =
        serde_json::to_value(&shell_boundary_lowering_bundle)?;
    let shell_boundary_lowering_slot_body = tampered_shell_boundary_lowering_bundle
        ["confidential_slot_program"]["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!(
                "shell-boundary lowering tamper scenario missing confidential slot program body"
            )
        })?;
    if shell_boundary_lowering_slot_body.pop().is_none() {
        return Err(anyhow!(
            "shell-boundary lowering tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_shell_boundary_lowering_slot_statement_count =
        shell_boundary_lowering_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "shell_boundary_lowering/slot_program_body_drift",
        &tampered_shell_boundary_lowering_bundle,
        |bundle_path| Ok(Command::new(&shell_boundary_lowering_checker).arg(bundle_path).output()?),
        json!({
            "scenario": "shell_boundary_lowering/slot_program_body_drift",
            "artifact_kind": "proofgrade_runtime_shell_boundary_lowering_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the shell-boundary witness fixed",
            "statement_count_before": original_shell_boundary_lowering_slot_statement_count,
            "statement_count_after": tampered_shell_boundary_lowering_slot_statement_count,
        }),
    )?);

    let original_shell_boundary_slot_statement_count = shell_boundary_slot_bundle
        .confidential_slot_program()
        .body
        .len();
    let mut tampered_shell_boundary_slot_bundle =
        serde_json::to_value(&shell_boundary_slot_bundle)?;
    let shell_boundary_slot_body = tampered_shell_boundary_slot_bundle["confidential_slot_program"]
        ["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!("shell-boundary slot tamper scenario missing confidential slot program body")
        })?;
    if shell_boundary_slot_body.pop().is_none() {
        return Err(anyhow!(
            "shell-boundary slot tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_shell_boundary_slot_statement_count = shell_boundary_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "shell_boundary_slot/slot_program_body_drift",
        &tampered_shell_boundary_slot_bundle,
        |bundle_path| Ok(Command::new(&shell_boundary_slot_checker).arg(bundle_path).output()?),
        json!({
            "scenario": "shell_boundary_slot/slot_program_body_drift",
            "artifact_kind": "proofgrade_runtime_shell_boundary_slot_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the shell-boundary witness fixed",
            "statement_count_before": original_shell_boundary_slot_statement_count,
            "statement_count_after": tampered_shell_boundary_slot_statement_count,
        }),
    )?);

    let original_confidential_core_statement_count =
        confidential_core_bundle.confidential_program().body.len();
    let mut tampered_confidential_core_bundle = serde_json::to_value(&confidential_core_bundle)?;
    let confidential_core_body = tampered_confidential_core_bundle["confidential_program"]["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!("confidential-core tamper scenario missing confidential program body")
        })?;
    if confidential_core_body.pop().is_none() {
        return Err(anyhow!(
            "confidential-core tamper scenario missing confidential program body"
        ));
    }
    let tampered_confidential_core_statement_count = confidential_core_body.len();
    scenarios.push(validate_tampered_json_case(
        "confidential_core/program_body_drift",
        &tampered_confidential_core_bundle,
        |bundle_path| {
            Ok(Command::new(&confidential_core_checker)
                .arg(bundle_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "confidential_core/program_body_drift",
            "artifact_kind": "proofgrade_runtime_confidential_core_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final named confidential-kernel statement while keeping the runtime witness fixed",
            "statement_count_before": original_confidential_core_statement_count,
            "statement_count_after": tampered_confidential_core_statement_count,
        }),
    )?);

    let original_confidential_core_slot_statement_count = confidential_core_slot_bundle
        .confidential_slot_program()
        .body
        .len();
    let mut tampered_confidential_core_slot_bundle =
        serde_json::to_value(&confidential_core_slot_bundle)?;
    let confidential_core_slot_body = tampered_confidential_core_slot_bundle
        ["confidential_slot_program"]["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!("confidential-core slot tamper scenario missing confidential slot program body")
        })?;
    if confidential_core_slot_body.pop().is_none() {
        return Err(anyhow!(
            "confidential-core slot tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_confidential_core_slot_statement_count = confidential_core_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "confidential_core_slot/program_body_drift",
        &tampered_confidential_core_slot_bundle,
        |bundle_path| {
            Ok(Command::new(&confidential_core_slot_checker)
                .arg(bundle_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "confidential_core_slot/program_body_drift",
            "artifact_kind": "proofgrade_runtime_confidential_core_slot_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the runtime witness fixed",
            "statement_count_before": original_confidential_core_slot_statement_count,
            "statement_count_after": tampered_confidential_core_slot_statement_count,
        }),
    )?);

    let original_confidential_core_lowering_slot_statement_count =
        confidential_core_lowering_bundle
            .confidential_slot_program()
            .body
            .len();
    let mut tampered_confidential_core_lowering_bundle =
        serde_json::to_value(&confidential_core_lowering_bundle)?;
    let confidential_core_lowering_slot_body = tampered_confidential_core_lowering_bundle
        ["confidential_slot_program"]["body"]
        .as_array_mut()
        .ok_or_else(|| {
            anyhow!(
                "confidential-core lowering tamper scenario missing confidential slot program body"
            )
        })?;
    if confidential_core_lowering_slot_body.pop().is_none() {
        return Err(anyhow!(
            "confidential-core lowering tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_confidential_core_lowering_slot_statement_count =
        confidential_core_lowering_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "confidential_core_lowering/slot_program_body_drift",
        &tampered_confidential_core_lowering_bundle,
        |bundle_path| {
            Ok(Command::new(&confidential_core_lowering_checker)
                .arg(bundle_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "confidential_core_lowering/slot_program_body_drift",
            "artifact_kind": "proofgrade_runtime_confidential_core_lowering_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the named program and runtime witness fixed",
            "statement_count_before": original_confidential_core_lowering_slot_statement_count,
            "statement_count_after": tampered_confidential_core_lowering_slot_statement_count,
        }),
    )?);

    let original_confidential_core_shell_boundary_lowering_slot_statement_count =
        confidential_core_shell_boundary_lowering_bundle
            .confidential_slot_program()
            .body
            .len();
    let mut tampered_confidential_core_shell_boundary_lowering_bundle =
        serde_json::to_value(&confidential_core_shell_boundary_lowering_bundle)?;
    let confidential_core_shell_boundary_lowering_slot_body =
        tampered_confidential_core_shell_boundary_lowering_bundle["confidential_slot_program"]
            ["body"]
            .as_array_mut()
            .ok_or_else(|| {
                anyhow!(
                    "confidential-core shell-boundary lowering tamper scenario missing confidential slot program body"
                )
            })?;
    if confidential_core_shell_boundary_lowering_slot_body
        .pop()
        .is_none()
    {
        return Err(anyhow!(
            "confidential-core shell-boundary lowering tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_confidential_core_shell_boundary_lowering_slot_statement_count =
        confidential_core_shell_boundary_lowering_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "confidential_core_shell_boundary_lowering/slot_program_body_drift",
        &tampered_confidential_core_shell_boundary_lowering_bundle,
        |bundle_path| {
            Ok(Command::new(&confidential_core_shell_boundary_lowering_checker)
                .arg(bundle_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "confidential_core_shell_boundary_lowering/slot_program_body_drift",
            "artifact_kind": "proofgrade_runtime_confidential_core_shell_boundary_lowering_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the runtime witness and shell-boundary bundle fixed",
            "statement_count_before": original_confidential_core_shell_boundary_lowering_slot_statement_count,
            "statement_count_after":
                tampered_confidential_core_shell_boundary_lowering_slot_statement_count,
        }),
    )?);

    let original_confidential_core_shell_boundary_slot_statement_count =
        confidential_core_shell_boundary_slot_bundle
            .confidential_slot_program()
            .body
            .len();
    let mut tampered_confidential_core_shell_boundary_slot_bundle =
        serde_json::to_value(&confidential_core_shell_boundary_slot_bundle)?;
    let confidential_core_shell_boundary_slot_body =
        tampered_confidential_core_shell_boundary_slot_bundle["confidential_slot_program"]["body"]
            .as_array_mut()
            .ok_or_else(|| {
                anyhow!(
                    "confidential-core shell-boundary slot tamper scenario missing confidential slot program body"
                )
            })?;
    if confidential_core_shell_boundary_slot_body.pop().is_none() {
        return Err(anyhow!(
            "confidential-core shell-boundary slot tamper scenario missing confidential slot program body"
        ));
    }
    let tampered_confidential_core_shell_boundary_slot_statement_count =
        confidential_core_shell_boundary_slot_body.len();
    scenarios.push(validate_tampered_json_case(
        "confidential_core_shell_boundary_slot/slot_program_body_drift",
        &tampered_confidential_core_shell_boundary_slot_bundle,
        |bundle_path| {
            Ok(Command::new(&confidential_core_shell_boundary_slot_checker)
                .arg(bundle_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "confidential_core_shell_boundary_slot/slot_program_body_drift",
            "artifact_kind": "proofgrade_runtime_confidential_core_shell_boundary_slot_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "remove the final slot confidential-kernel statement while keeping the runtime witness and shell-boundary bundle fixed",
            "statement_count_before": original_confidential_core_shell_boundary_slot_statement_count,
            "statement_count_after":
                tampered_confidential_core_shell_boundary_slot_statement_count,
        }),
    )?);

    let mut tampered_runtime_witness = serde_json::to_value(&runtime_witness)?;
    let witnessed_access = tampered_runtime_witness["controller_certificate"]
        ["observed_oram_accesses"]
        .get_mut(0)
        .ok_or_else(|| anyhow!("runtime witness tamper scenario missing observed ORAM access"))?;
    let old_depth = witnessed_access["recursion_depth"].as_u64().unwrap_or(0);
    witnessed_access["recursion_depth"] = json!(old_depth.saturating_add(1));
    scenarios.push(validate_tampered_json_case(
        "runtime_witness/controller_certificate_drift",
        &tampered_runtime_witness,
        |witness_path| {
            Ok(Command::new(&witness_checker)
                .arg(witness_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "runtime_witness/controller_certificate_drift",
            "artifact_kind": "proofgrade_runtime_refinement_witness",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "increment first observed ORAM access recursion_depth inside the embedded controller certificate",
        }),
    )?);

    let mut tampered_trusted_kernel_bundle = serde_json::to_value(&trusted_kernel_bundle)?;
    let trusted_leaf = tampered_trusted_kernel_bundle["trusted_kernel_bundle"]
        ["hidden_certificate"]["oram_position_map_after"]
        .get_mut(0)
        .and_then(|position_map| position_map["leaves"].get_mut(0))
        .ok_or_else(|| {
            anyhow!("trusted-kernel tamper scenario missing hidden position-map leaf")
        })?;
    let drifted_trusted_leaf = trusted_leaf
        .as_u64()
        .map(|leaf| leaf.saturating_add(1))
        .unwrap_or(0);
    *trusted_leaf = json!(drifted_trusted_leaf);
    scenarios.push(validate_tampered_json_case(
        "trusted_kernel/hidden_state_drift",
        &tampered_trusted_kernel_bundle,
        |bundle_path| {
            Ok(Command::new(&trusted_kernel_checker)
                .arg(bundle_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "trusted_kernel/hidden_state_drift",
            "artifact_kind": "proofgrade_runtime_trusted_kernel_bundle",
            "benchmark": "SingleAccessMap/pathoram/put",
            "entrypoint": target.entrypoint,
            "mutation": "drift first hidden position-map leaf inside the trusted-kernel slot bundle",
        }),
    )?);

    let mut tampered_seeded_family = serde_json::to_value(
        &collect_seeded_pathoram_family(&artifact, &[], target.entrypoint, target.args.clone(), 8)?
            .family,
    )?;
    let second_seeded_witness = tampered_seeded_family["witnesses"]
        .get_mut(1)
        .ok_or_else(|| anyhow!("seeded family tamper scenario needs at least two witnesses"))?;
    second_seeded_witness["runtime_seed"] = json!(99);
    scenarios.push(validate_tampered_json_case(
        "seeded_witness_family/seed_tag_drift",
        &tampered_seeded_family,
        |family_path| {
            Ok(Command::new(&witness_family_checker)
                .arg(family_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "seeded_witness_family/seed_tag_drift",
            "artifact_kind": "runtime_seeded_pathoram_witness_family",
            "benchmark": "SingleAccessMap/pathoram/put-seeded",
            "entrypoint": target.entrypoint,
            "mutation": "change the second witness runtime_seed tag without changing its witness contents",
        }),
    )?);

    let tampered_fresh_coin_family = collect_canonical_fresh_coin_family_case(
        "SingleAccessMap/pathoram/put-fresh-coins-tamper",
        &artifact,
        &[],
        &target,
    )?
    .family;
    if tampered_fresh_coin_family.seed_count() == 0 {
        return Err(anyhow!(
            "fresh-coin family tamper scenario has empty seed space"
        ));
    }
    let mut tampered_fresh_coin_family = serde_json::to_value(&tampered_fresh_coin_family)?;
    tampered_fresh_coin_family["seed_count"] = json!(
        tampered_fresh_coin_family["seed_count"]
            .as_u64()
            .unwrap_or_default()
            - 1
    );
    scenarios.push(validate_tampered_json_case(
        "fresh_coin_family/seed_count_drift",
        &tampered_fresh_coin_family,
        |family_path| {
            Ok(Command::new(&fresh_coin_family_checker)
                .arg(family_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "fresh_coin_family/seed_count_drift",
            "artifact_kind": "runtime_canonical_fresh_coin_witness_family",
            "benchmark": "SingleAccessMap/pathoram/put-fresh-coins",
            "entrypoint": target.entrypoint,
            "mutation": "decrement the canonical fresh-coin family seed_count while leaving the witness list fixed",
        }),
    )?);

    let tampered_fresh_coin_theorem_input = collect_canonical_fresh_coin_theorem_input_case(
        "SingleAccessMap/pathoram/put-fresh-coins-theorem-input-tamper",
        &artifact,
        &[],
        &target,
    )?
    .input;
    let mut tampered_fresh_coin_theorem_input =
        serde_json::to_value(&tampered_fresh_coin_theorem_input)?;
    tampered_fresh_coin_theorem_input["representative_seed"] =
        tampered_fresh_coin_theorem_input["seed_count"].clone();
    scenarios.push(validate_tampered_json_case(
        "fresh_coin_theorem_input/representative_seed_drift",
        &tampered_fresh_coin_theorem_input,
        |theorem_input_path| {
            Ok(Command::new(&fresh_coin_theorem_input_checker)
                .arg(theorem_input_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "fresh_coin_theorem_input/representative_seed_drift",
            "artifact_kind": "runtime_canonical_fresh_coin_theorem_input",
            "benchmark": "SingleAccessMap/pathoram/put-fresh-coins",
            "entrypoint": target.entrypoint,
            "mutation": "set representative_seed just outside the canonical seed space",
        }),
    )?);

    let mut tampered_pathoram_pair_certificate =
        serde_json::to_value(&build_seeded_pathoram_pair_certificate(
            "SingleAccessMap/pathoram/put-pair-tamper",
            &artifact,
            &[],
            &target,
            &pair_target,
            8,
        )?)?;
    let rhs_seeded_pair_witness = tampered_pathoram_pair_certificate["rhs_family"]["witnesses"]
        .get_mut(1)
        .ok_or_else(|| {
            anyhow!("path-ORAM pair tamper scenario needs at least two rhs witnesses")
        })?;
    rhs_seeded_pair_witness["runtime_seed"] = json!(99);
    scenarios.push(validate_tampered_json_case(
        "pathoram_pair/seed_tag_drift",
        &tampered_pathoram_pair_certificate,
        |certificate_path| {
            Ok(Command::new(&pathoram_pair_checker)
                .arg(certificate_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "pathoram_pair/seed_tag_drift",
            "artifact_kind": "runtime_seeded_pathoram_pair_certificate",
            "benchmark": "SingleAccessMap/pathoram/put-pair",
            "entrypoint": target.entrypoint,
            "mutation": "change the second rhs witness runtime_seed tag without changing the witness contents",
        }),
    )?);

    let tampered_canonical_pathoram_pair_certificate = build_canonical_pathoram_pair_certificate(
        "SingleAccessMap/pathoram/put-canonical-pair-tamper",
        &artifact,
        &[],
        &target,
        &pair_target,
    )?;
    if tampered_canonical_pathoram_pair_certificate
        .rhs_family
        .seed_count()
        == 0
    {
        return Err(anyhow!(
            "canonical path-ORAM pair tamper scenario has empty rhs canonical seed space"
        ));
    }
    let mut tampered_canonical_pathoram_pair_certificate =
        serde_json::to_value(&tampered_canonical_pathoram_pair_certificate)?;
    let rhs_seed_count = tampered_canonical_pathoram_pair_certificate["rhs_family"]["seed_count"]
        .as_u64()
        .unwrap_or_default();
    tampered_canonical_pathoram_pair_certificate["rhs_family"]["seed_count"] =
        json!(rhs_seed_count - 1);
    scenarios.push(validate_tampered_json_case(
        "canonical_pathoram_pair/seed_count_drift",
        &tampered_canonical_pathoram_pair_certificate,
        |certificate_path| {
            Ok(Command::new(&canonical_pathoram_pair_checker)
                .arg(certificate_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "canonical_pathoram_pair/seed_count_drift",
            "artifact_kind": "runtime_canonical_pathoram_pair_certificate",
            "benchmark": "SingleAccessMap/pathoram/put-canonical-pair",
            "entrypoint": target.entrypoint,
            "mutation": "decrement rhs canonical family seed_count while leaving the witness list fixed",
        }),
    )?);

    scenarios.push(validate_tampered_json_case(
        "canonical_pathoram_paper_instantiation/seed_count_drift",
        &tampered_canonical_pathoram_pair_certificate,
        |certificate_path| {
            Ok(Command::new(&canonical_pathoram_paper_instantiation_checker)
                .arg(certificate_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "canonical_pathoram_paper_instantiation/seed_count_drift",
            "artifact_kind": "runtime_canonical_pathoram_paper_pair_certificate",
            "benchmark": "SingleAccessMap/pathoram/put-canonical-pair",
            "entrypoint": target.entrypoint,
            "mutation": "decrement rhs canonical family seed_count before the paper-instantiation checker replays the certificate",
        }),
    )?);

    let tampered_canonical_pathoram_pair_theorem_input =
        build_canonical_pathoram_pair_theorem_input(
            "SingleAccessMap/pathoram/put-canonical-pair-theorem-input-tamper",
            &artifact,
            &[],
            &target,
            &pair_target,
        )?;
    let mut tampered_canonical_pathoram_pair_theorem_input =
        serde_json::to_value(&tampered_canonical_pathoram_pair_theorem_input)?;
    tampered_canonical_pathoram_pair_theorem_input["rhs_input"]["representative_seed"] =
        tampered_canonical_pathoram_pair_theorem_input["rhs_input"]["seed_count"].clone();
    scenarios.push(validate_tampered_json_case(
        "canonical_pathoram_pair_theorem_input/representative_seed_drift",
        &tampered_canonical_pathoram_pair_theorem_input,
        |theorem_input_path| {
            Ok(Command::new(&canonical_pathoram_pair_theorem_input_checker)
                .arg(theorem_input_path)
                .arg("page_v1")
                .arg("exit_v1")
                .arg("shared_v1")
                .output()?)
        },
        json!({
            "scenario": "canonical_pathoram_pair_theorem_input/representative_seed_drift",
            "artifact_kind": "runtime_canonical_pathoram_pair_theorem_input",
            "benchmark": "SingleAccessMap/pathoram/put-canonical-pair",
            "entrypoint": target.entrypoint,
            "mutation": "set rhs representative_seed just outside the canonical seed space",
        }),
    )?);

    Ok(json!({
        "benchmark": "SingleAccessMap/pathoram/put",
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "checkers": {
            "proofgrade_translation_artifacts": display_report_path(&translation_checker),
            "runtime_controller_observer_certificate": display_report_path(&controller_checker),
            "runtime_path_oram_hidden_certificate": display_report_path(&hidden_checker),
            "proofgrade_runtime_kernel_dsl_bundle": display_report_path(&kernel_dsl_checker),
            "proofgrade_runtime_kernel_slot_dsl_bundle": display_report_path(&kernel_slot_dsl_checker),
            "proofgrade_runtime_kernel_lowering_bundle": display_report_path(&kernel_lowering_checker),
            "proofgrade_runtime_kernel_witness": display_report_path(&kernel_checker),
            "proofgrade_runtime_kernel_refinement_witness": display_report_path(&kernel_refinement_checker),
            "proofgrade_runtime_shell_boundary_bundle": display_report_path(&shell_boundary_checker),
            "proofgrade_runtime_shell_boundary_slot_bundle": display_report_path(&shell_boundary_slot_checker),
            "proofgrade_runtime_shell_boundary_lowering_bundle": display_report_path(&shell_boundary_lowering_checker),
            "proofgrade_runtime_confidential_core_bundle": display_report_path(&confidential_core_checker),
            "proofgrade_runtime_confidential_core_slot_bundle": display_report_path(&confidential_core_slot_checker),
            "proofgrade_runtime_confidential_core_shell_boundary_slot_bundle":
                display_report_path(&confidential_core_shell_boundary_slot_checker),
            "proofgrade_runtime_confidential_core_lowering_bundle": display_report_path(&confidential_core_lowering_checker),
            "proofgrade_runtime_confidential_core_shell_boundary_lowering_bundle":
                display_report_path(&confidential_core_shell_boundary_lowering_checker),
            "proofgrade_runtime_refinement_witness": display_report_path(&witness_checker),
            "proofgrade_runtime_trusted_kernel_bundle": display_report_path(&trusted_kernel_checker),
            "runtime_seeded_pathoram_witness_family": display_report_path(&witness_family_checker),
            "runtime_canonical_fresh_coin_witness_family":
                display_report_path(&fresh_coin_family_checker),
            "runtime_canonical_fresh_coin_theorem_input":
                display_report_path(&fresh_coin_theorem_input_checker),
            "runtime_seeded_pathoram_pair_certificate": display_report_path(&pathoram_pair_checker),
            "runtime_canonical_pathoram_pair_certificate":
                display_report_path(&canonical_pathoram_pair_checker),
            "runtime_canonical_pathoram_paper_pair_certificate":
                display_report_path(&canonical_pathoram_paper_instantiation_checker),
            "runtime_canonical_pathoram_pair_theorem_input":
                display_report_path(&canonical_pathoram_pair_theorem_input_checker),
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_trusted_kernel_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_trusted_kernel_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let auth_setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    let erc20_setup = vec![CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![addr(0x11), Value::Uint(10)],
    }];
    let excluded_scenarios = vec![
        json!({
            "scenario": "ConfidentialMixer/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ConfidentialMixer/pathoram/*; the trusted-kernel validator reports only the explicit pathoram name"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ERC20Lite/pathoram/*; the trusted-kernel validator reports only the explicit pathoram name"
        }),
    ];

    let mut scenarios = Vec::new();
    scenarios.push(validate_trusted_kernel_case(
        "FixedSlotClassifier/uo/class0",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "FixedSlotClassifier/uo/class1",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "AuthScan/uo/class0",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(9)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "AuthScan/uo/class1",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "RegistryCRUD/uo/class0",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "RegistryCRUD/uo/class1",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "ConfidentialMixer/fullscan/class0",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "ConfidentialMixer/fullscan/class1",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "ERC20Lite/fullscan/class0",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "ERC20Lite/fullscan/class1",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "SingleAccessMap/pathoram/put-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "SingleAccessMap/pathoram/put-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "SingleAccessMap/pathoram/add-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "SingleAccessMap/pathoram/add-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "ConfidentialMixer/pathoram/deposit",
        &mixer_pathoram,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_trusted_kernel_case(
        "ERC20Lite/pathoram/transferFrom",
        &erc20_pathoram,
        &[
            CallSpec {
                entrypoint: "mint(address,uint256)",
                args: vec![addr(0x11), Value::Uint(10)],
            },
            CallSpec {
                entrypoint: "approve(address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
            },
        ],
        &CallSpec {
            entrypoint: "transferFrom(address,address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
        },
        &checker,
    )?);

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_kernel_validation(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let checker = lean_proofgrade_kernel_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let auth_setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    let erc20_setup = vec![CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![addr(0x11), Value::Uint(10)],
    }];
    let excluded_scenarios = vec![
        json!({
            "scenario": "ConfidentialMixer/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ConfidentialMixer/pathoram/*; the kernel validator reports only the explicit pathoram name"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ERC20Lite/pathoram/*; the kernel validator reports only the explicit pathoram name"
        }),
    ];

    let mut scenarios = Vec::new();
    scenarios.push(validate_kernel_case(
        "FixedSlotClassifier/uo/class0",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "FixedSlotClassifier/uo/class1",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "AuthScan/uo/class0",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(9)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "AuthScan/uo/class1",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "RegistryCRUD/uo/class0",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "RegistryCRUD/uo/class1",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "ConfidentialMixer/fullscan/class0",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "ConfidentialMixer/fullscan/class1",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "ERC20Lite/fullscan/class0",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "ERC20Lite/fullscan/class1",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "SingleAccessMap/pathoram/put-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "SingleAccessMap/pathoram/put-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "SingleAccessMap/pathoram/add-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "SingleAccessMap/pathoram/add-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "ConfidentialMixer/pathoram/deposit",
        &mixer_pathoram,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_case(
        "ERC20Lite/pathoram/transferFrom",
        &erc20_pathoram,
        &[
            CallSpec {
                entrypoint: "mint(address,uint256)",
                args: vec![addr(0x11), Value::Uint(10)],
            },
            CallSpec {
                entrypoint: "approve(address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
            },
        ],
        &CallSpec {
            entrypoint: "transferFrom(address,address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
        },
        &checker,
    )?);

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_kernel_refinement_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_kernel_refinement_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let auth_setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    let erc20_setup = vec![CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![addr(0x11), Value::Uint(10)],
    }];
    let excluded_scenarios = vec![
        json!({
            "scenario": "ConfidentialMixer/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ConfidentialMixer/pathoram/*; the direct runtime-phase witness validator reports only the explicit pathoram name"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ERC20Lite/pathoram/*; the direct runtime-phase witness validator reports only the explicit pathoram name"
        }),
    ];

    let mut scenarios = Vec::new();
    scenarios.push(validate_kernel_refinement_case(
        "FixedSlotClassifier/uo/class0",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "FixedSlotClassifier/uo/class1",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "AuthScan/uo/class0",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(9)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "AuthScan/uo/class1",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "RegistryCRUD/uo/class0",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "RegistryCRUD/uo/class1",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "ConfidentialMixer/fullscan/class0",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "ConfidentialMixer/fullscan/class1",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "ERC20Lite/fullscan/class0",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "ERC20Lite/fullscan/class1",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "SingleAccessMap/pathoram/put-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "SingleAccessMap/pathoram/put-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "SingleAccessMap/pathoram/add-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "SingleAccessMap/pathoram/add-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "ConfidentialMixer/pathoram/deposit",
        &mixer_pathoram,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_kernel_refinement_case(
        "ERC20Lite/pathoram/transferFrom",
        &erc20_pathoram,
        &[
            CallSpec {
                entrypoint: "mint(address,uint256)",
                args: vec![addr(0x11), Value::Uint(10)],
            },
            CallSpec {
                entrypoint: "approve(address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
            },
        ],
        &CallSpec {
            entrypoint: "transferFrom(address,address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
        },
        &checker,
    )?);

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_shell_boundary_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_shell_boundary_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_shell_boundary_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_shell_boundary_slot_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_shell_boundary_slot_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_shell_boundary_slot_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_shell_boundary_lowering_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_shell_boundary_lowering_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_shell_boundary_lowering_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_witness_validation(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let checker = lean_proofgrade_witness_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_witness_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_confidential_core_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_confidential_core_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_confidential_core_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_confidential_core_slot_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_confidential_core_slot_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_confidential_core_slot_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_confidential_core_shell_boundary_slot_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_confidential_core_shell_boundary_slot_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_confidential_core_shell_boundary_slot_case(
                name, artifact, setup, target, &checker,
            )
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_confidential_core_lowering_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_confidential_core_lowering_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_confidential_core_lowering_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_confidential_core_shell_boundary_lowering_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_confidential_core_shell_boundary_lowering_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_confidential_core_shell_boundary_lowering_case(
                name, artifact, setup, target, &checker,
            )
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn collect_proofgrade_runtime_validation_scenarios(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
    mut validate_case: impl FnMut(
        &'static str,
        &CompiledArtifact,
        &[CallSpec],
        &CallSpec,
    ) -> Result<JsonValue>,
) -> Result<(Vec<JsonValue>, Vec<JsonValue>)> {
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let auth_setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    let erc20_setup = vec![CallSpec {
        entrypoint: "mint(address,uint256)",
        args: vec![addr(0x11), Value::Uint(10)],
    }];
    let excluded_scenarios = vec![
        json!({
            "scenario": "ConfidentialMixer/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ConfidentialMixer/pathoram/*; the Lean runtime witness is reported only once under the explicit pathoram name"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "generic ORAM benchmark alias compiles the same path-ORAM backend as ERC20Lite/pathoram/*; the Lean runtime witness is reported only once under the explicit pathoram name"
        }),
    ];

    let mut scenarios = Vec::new();
    scenarios.push(validate_case(
        "FixedSlotClassifier/uo/class0",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(0)],
        },
    )?);
    scenarios.push(validate_case(
        "FixedSlotClassifier/uo/class1",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(1)],
        },
    )?);
    scenarios.push(validate_case(
        "AuthScan/uo/class0",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(9)],
        },
    )?);
    scenarios.push(validate_case(
        "AuthScan/uo/class1",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(1)],
        },
    )?);
    scenarios.push(validate_case(
        "RegistryCRUD/uo/class0",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(0)],
        },
    )?);
    scenarios.push(validate_case(
        "RegistryCRUD/uo/class1",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(7)],
        },
    )?);
    scenarios.push(validate_case(
        "ConfidentialMixer/fullscan/class0",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(0)],
        },
    )?);
    scenarios.push(validate_case(
        "ConfidentialMixer/fullscan/class1",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
    )?);
    scenarios.push(validate_case(
        "ERC20Lite/fullscan/class0",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(0)],
        },
    )?);
    scenarios.push(validate_case(
        "ERC20Lite/fullscan/class1",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
    )?);
    scenarios.push(validate_case(
        "SingleAccessMap/pathoram/put-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
    )?);
    scenarios.push(validate_case(
        "SingleAccessMap/pathoram/put-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
    )?);
    scenarios.push(validate_case(
        "SingleAccessMap/pathoram/add-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
    )?);
    scenarios.push(validate_case(
        "SingleAccessMap/pathoram/add-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
    )?);
    scenarios.push(validate_case(
        "ConfidentialMixer/pathoram/deposit",
        &mixer_pathoram,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
    )?);
    scenarios.push(validate_case(
        "ERC20Lite/pathoram/transferFrom",
        &erc20_pathoram,
        &[
            CallSpec {
                entrypoint: "mint(address,uint256)",
                args: vec![addr(0x11), Value::Uint(10)],
            },
            CallSpec {
                entrypoint: "approve(address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
            },
        ],
        &CallSpec {
            entrypoint: "transferFrom(address,address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
        },
    )?);

    Ok((scenarios, excluded_scenarios))
}

fn run_seeded_witness_validation() -> Result<JsonValue> {
    let checker = lean_witness_family_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let scenarios = vec![
        validate_seeded_witness_family_case(
            "SingleAccessMap/pathoram/put-seeded",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            8,
            &checker,
        )?,
        validate_seeded_witness_family_case(
            "SingleAccessMap/pathoram/add-seeded",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            8,
            &checker,
        )?,
        validate_seeded_witness_family_case(
            "ConfidentialMixer/pathoram/deposit-seeded",
            &mixer_pathoram,
            &[],
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(5), Value::Uint(1)],
            },
            4,
            &checker,
        )?,
        validate_seeded_witness_family_case(
            "ERC20Lite/pathoram/transferFrom-seeded",
            &erc20_pathoram,
            &[
                CallSpec {
                    entrypoint: "mint(address,uint256)",
                    args: vec![addr(0x11), Value::Uint(10)],
                },
                CallSpec {
                    entrypoint: "approve(address,address,uint256)",
                    args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
                },
            ],
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
            },
            4,
            &checker,
        )?,
    ];

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_fresh_coin_validation(options: &ProbeRunOptions) -> Result<JsonValue> {
    let family_checker = lean_fresh_coin_family_checker_path()?;
    let theorem_input_checker = lean_fresh_coin_theorem_input_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_transfer_setup = [
        CallSpec {
            entrypoint: "mint(address,uint256)",
            args: vec![addr(0x11), Value::Uint(10)],
        },
        CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
    ];

    let scenarios = vec![
        validate_fresh_coin_family_case(
            "SingleAccessMap/pathoram/put-fresh-coins",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &family_checker,
            &theorem_input_checker,
            options,
        )?,
        validate_fresh_coin_family_case(
            "SingleAccessMap/pathoram/add-fresh-coins",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &family_checker,
            &theorem_input_checker,
            options,
        )?,
        validate_fresh_coin_family_case(
            "ConfidentialMixer/pathoram/deposit-fresh-coins",
            &mixer_pathoram,
            &[],
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(5), Value::Uint(1)],
            },
            &family_checker,
            &theorem_input_checker,
            options,
        )?,
        validate_fresh_coin_family_case(
            "ERC20Lite/pathoram/transferFrom-fresh-coins",
            &erc20_pathoram,
            &erc20_transfer_setup,
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
            },
            &family_checker,
            &theorem_input_checker,
            options,
        )?,
    ];

    Ok(json!({
        "checker": display_report_path(&family_checker),
        "theorem_input_checker": display_report_path(&theorem_input_checker),
        "artifact_configuration": options.artifact_configuration_json(),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_pathoram_pair_validation() -> Result<JsonValue> {
    let checker = lean_pathoram_pair_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;

    let scenarios = vec![
        validate_pathoram_pair_case(
            "SingleAccessMap/pathoram/put-pair",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(7)],
            },
            8,
            &checker,
        )?,
        validate_pathoram_pair_case(
            "SingleAccessMap/pathoram/add-pair",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(7)],
            },
            8,
            &checker,
        )?,
        validate_pathoram_pair_case(
            "ConfidentialMixer/pathoram/deposit-pair",
            &mixer_pathoram,
            &[],
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(1)],
            },
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(1)],
            },
            4,
            &checker,
        )?,
        validate_pathoram_pair_case(
            "ERC20Lite/pathoram/transferFrom-pair",
            &erc20_pathoram,
            &[
                CallSpec {
                    entrypoint: "mint(address,uint256)",
                    args: vec![addr(0x11), Value::Uint(10)],
                },
                CallSpec {
                    entrypoint: "approve(address,address,uint256)",
                    args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
                },
            ],
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
            },
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x44), Value::Uint(3)],
            },
            4,
            &checker,
        )?,
    ];

    Ok(json!({
        "checker": display_report_path(&checker),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_canonical_pathoram_pair_validation(options: &ProbeRunOptions) -> Result<JsonValue> {
    let checker = lean_canonical_pathoram_pair_checker_path()?;
    let paper_instantiation_checker = lean_canonical_pathoram_paper_instantiation_checker_path()?;
    let theorem_input_checker = lean_canonical_pathoram_pair_theorem_input_checker_path()?;
    let single_access = compile_artifact(
        "benches/raw/SingleAccessMap.sol",
        "benches/raw/SingleAccessMap.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let mixer_pathoram = compile_artifact(
        "benches/raw/ConfidentialMixer.sol",
        "benches/raw/ConfidentialMixer.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_pathoram = compile_artifact(
        "benches/raw/ERC20Lite.sol",
        "benches/raw/ERC20Lite.pathoram.yaml",
        ProgramMode::Uo,
    )?;
    let erc20_transfer_setup = [
        CallSpec {
            entrypoint: "mint(address,uint256)",
            args: vec![addr(0x11), Value::Uint(10)],
        },
        CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
    ];

    let scenarios = vec![
        validate_canonical_pathoram_pair_case(
            "SingleAccessMap/pathoram/put-canonical-pair",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &CallSpec {
                entrypoint: "put(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(7)],
            },
            &checker,
            &paper_instantiation_checker,
            &theorem_input_checker,
            options,
        )?,
        validate_canonical_pathoram_pair_case(
            "SingleAccessMap/pathoram/add-canonical-pair",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(7)],
            },
            &checker,
            &paper_instantiation_checker,
            &theorem_input_checker,
            options,
        )?,
        validate_canonical_pathoram_pair_case(
            "ConfidentialMixer/pathoram/deposit-canonical-pair",
            &mixer_pathoram,
            &[],
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(1)],
            },
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(9), Value::Uint(1)],
            },
            &checker,
            &paper_instantiation_checker,
            &theorem_input_checker,
            options,
        )?,
        validate_canonical_pathoram_pair_case(
            "ERC20Lite/pathoram/transferFrom-canonical-pair",
            &erc20_pathoram,
            &erc20_transfer_setup,
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
            },
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x44), Value::Uint(3)],
            },
            &checker,
            &paper_instantiation_checker,
            &theorem_input_checker,
            options,
        )?,
    ];

    Ok(json!({
        "checker": display_report_path(&checker),
        "paper_instantiation_checker": display_report_path(&paper_instantiation_checker),
        "theorem_input_checker": display_report_path(&theorem_input_checker),
        "artifact_configuration": options.artifact_configuration_json(),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn validate_witness_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if witness.kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if witness.runtime_kernel_refinement_witness() != trace.runtime_kernel_refinement_witness() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }
    let (witness_path, witness_json_bytes) = write_temp_json(name, &witness)?;
    let output = Command::new(checker)
        .arg(&witness_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !output.status.success() {
        return Err(anyhow!(
            "Lean witness validation failed for {}: {} (witness preserved at {})",
            name,
            String::from_utf8_lossy(&output.stderr).trim(),
            witness_path.display()
        ));
    }
    let _ = fs::remove_file(&witness_path);
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "boundary_events": witness.boundary_schedule().len(),
        "controller_phase_count": witness.controller_shape().controller_phase_order.len(),
        "controller_accesses": witness.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": witness.normalized_micro_trace().page_trace.len(),
        "exit_events": witness.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events": witness.normalized_micro_trace().shared_resource_pattern.len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            witness.runtime_kernel_refinement_witness(),
            exact_kernel_witness.as_ref(),
        ),
        "witness_json_bytes": witness_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_confidential_core_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if witness.kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if witness.runtime_kernel_refinement_witness() != trace.runtime_kernel_refinement_witness() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let bundle = trace.runtime_confidential_core_bundle(artifact)?;
    let fragment_witness = artifact.confidential_fragment_witness();
    let fragment_entrypoint = fragment_witness
        .entrypoint(target.entrypoint)
        .ok_or_else(|| {
            anyhow!(
                "confidential-core bundle for {} dropped entrypoint {}",
                name,
                target.entrypoint
            )
        })?;
    let (bundle_path, confidential_core_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker)
        .arg(&bundle_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean confidential-core validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "boundary_events": witness.boundary_schedule().len(),
        "controller_phase_count": witness.controller_shape().controller_phase_order.len(),
        "controller_accesses": witness.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": witness.normalized_micro_trace().page_trace.len(),
        "exit_events": witness.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events": witness.normalized_micro_trace().shared_resource_pattern.len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            witness.runtime_kernel_refinement_witness(),
            exact_kernel_witness.as_ref(),
        ),
        "confidential_program": {
            "entrypoint_id": bundle.confidential_program().entrypoint_id.as_str(),
            "param_count": bundle.confidential_program().params.len(),
            "secret_arg_count": bundle.confidential_program().secret_args.len(),
            "statement_count": bundle.confidential_program().body.len(),
            "expected_runtime_step_count":
                bundle.confidential_program().expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_fragment_witness": {
            "contract": fragment_witness.contract.as_str(),
            "entrypoint_count": fragment_witness.entrypoints.len(),
            "entrypoint": {
                "entrypoint_id": fragment_entrypoint.entrypoint_id.as_str(),
                "select_count": fragment_entrypoint.select_count,
                "struct_field_count": fragment_entrypoint.struct_field_count,
                "array_index_count": fragment_entrypoint.array_index_count,
                "non_branchless_select_arm_count": fragment_entrypoint.non_branchless_select_arm_count,
                "accepted": fragment_entrypoint.valid(),
            },
            "accepted": fragment_witness.valid_for_entrypoint(target.entrypoint),
        },
        "confidential_core_bundle_json_bytes": confidential_core_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_confidential_core_slot_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if witness.kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if witness.runtime_kernel_refinement_witness() != trace.runtime_kernel_refinement_witness() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let bundle = trace.runtime_confidential_core_slot_bundle(artifact)?;
    let fragment_witness = artifact.confidential_fragment_witness();
    let fragment_entrypoint = fragment_witness
        .entrypoint(target.entrypoint)
        .ok_or_else(|| {
            anyhow!(
                "confidential-core slot bundle for {} dropped entrypoint {}",
                name,
                target.entrypoint
            )
        })?;
    let (bundle_path, confidential_core_slot_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker)
        .arg(&bundle_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean confidential-core slot validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "boundary_events": witness.boundary_schedule().len(),
        "controller_phase_count": witness.controller_shape().controller_phase_order.len(),
        "controller_accesses": witness.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": witness.normalized_micro_trace().page_trace.len(),
        "exit_events": witness.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events": witness.normalized_micro_trace().shared_resource_pattern.len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            witness.runtime_kernel_refinement_witness(),
            exact_kernel_witness.as_ref(),
        ),
        "confidential_slot_program": {
            "entrypoint_id": bundle.confidential_slot_program().entrypoint_id.as_str(),
            "param_count": bundle.confidential_slot_program().param_count,
            "secret_arg_count": bundle.confidential_slot_program().secret_args.len(),
            "slot_count": bundle.confidential_slot_program().slot_count,
            "statement_count": bundle.confidential_slot_program().body.len(),
            "expected_runtime_step_count":
                bundle.confidential_slot_program().expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_fragment_witness": {
            "contract": fragment_witness.contract.as_str(),
            "entrypoint_count": fragment_witness.entrypoints.len(),
            "entrypoint": {
                "entrypoint_id": fragment_entrypoint.entrypoint_id.as_str(),
                "select_count": fragment_entrypoint.select_count,
                "struct_field_count": fragment_entrypoint.struct_field_count,
                "array_index_count": fragment_entrypoint.array_index_count,
                "non_branchless_select_arm_count": fragment_entrypoint.non_branchless_select_arm_count,
                "accepted": fragment_entrypoint.valid(),
            },
            "accepted": fragment_witness.valid_for_entrypoint(target.entrypoint),
        },
        "confidential_core_slot_bundle_json_bytes": confidential_core_slot_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_confidential_core_shell_boundary_slot_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let runtime_witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if runtime_witness.kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if runtime_witness.runtime_kernel_refinement_witness()
        != trace.runtime_kernel_refinement_witness()
    {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
    let bundle = trace.runtime_confidential_core_shell_boundary_slot_bundle(artifact)?;
    if bundle.runtime_witness() != &runtime_witness {
        return Err(anyhow!(
            "confidential-core shell-boundary slot bundle for {} does not preserve the runtime witness",
            name
        ));
    }
    if bundle.shell_boundary_bundle() != &shell_boundary_bundle {
        return Err(anyhow!(
            "confidential-core shell-boundary slot bundle for {} does not preserve the shell-boundary bundle",
            name
        ));
    }
    let shell_boundary_bundle_ref = bundle.shell_boundary_bundle();
    let confidential_slot_program = bundle.confidential_slot_program();

    let fragment_witness = artifact.confidential_fragment_witness();
    let fragment_entrypoint = fragment_witness
        .entrypoint(target.entrypoint)
        .ok_or_else(|| {
            anyhow!(
                "confidential-core shell-boundary slot bundle for {} dropped entrypoint {}",
                name,
                target.entrypoint
            )
        })?;
    let (bundle_path, confidential_core_shell_boundary_slot_bundle_json_bytes) =
        write_temp_json(name, &bundle)?;
    let output = Command::new(checker)
        .arg(&bundle_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean confidential-core shell-boundary slot validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "boundary_events": runtime_witness.boundary_schedule().len(),
        "controller_phase_count": runtime_witness.controller_shape().controller_phase_order.len(),
        "controller_accesses": runtime_witness.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": runtime_witness.normalized_micro_trace().page_trace.len(),
        "exit_events": runtime_witness.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events":
            runtime_witness.normalized_micro_trace().shared_resource_pattern.len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            runtime_witness.runtime_kernel_refinement_witness(),
            exact_kernel_witness.as_ref(),
        ),
        "shell_contract": runtime_shell_contract_summary(
            shell_boundary_bundle_ref.shell_contract(),
        ),
        "shell_trace": runtime_shell_trace_summary(
            shell_boundary_bundle_ref.shell_trace(),
            Some(shell_boundary_bundle_ref.shell_contract()),
        ),
        "confidential_slot_program": {
            "entrypoint_id": confidential_slot_program.entrypoint_id.as_str(),
            "param_count": confidential_slot_program.param_count,
            "secret_arg_count": confidential_slot_program.secret_args.len(),
            "slot_count": confidential_slot_program.slot_count,
            "statement_count": confidential_slot_program.body.len(),
            "expected_runtime_step_count":
                confidential_slot_program.expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_fragment_witness": {
            "contract": fragment_witness.contract.as_str(),
            "entrypoint_count": fragment_witness.entrypoints.len(),
            "entrypoint": {
                "entrypoint_id": fragment_entrypoint.entrypoint_id.as_str(),
                "select_count": fragment_entrypoint.select_count,
                "struct_field_count": fragment_entrypoint.struct_field_count,
                "array_index_count": fragment_entrypoint.array_index_count,
                "non_branchless_select_arm_count": fragment_entrypoint.non_branchless_select_arm_count,
                "accepted": fragment_entrypoint.valid(),
            },
            "accepted": fragment_witness.valid_for_entrypoint(target.entrypoint),
        },
        "confidential_core_shell_boundary_slot_bundle_json_bytes":
            confidential_core_shell_boundary_slot_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_confidential_core_lowering_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if witness.kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if witness.runtime_kernel_refinement_witness() != trace.runtime_kernel_refinement_witness() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let bundle = trace.runtime_confidential_core_lowering_bundle(artifact)?;
    let fragment_witness = artifact.confidential_fragment_witness();
    let fragment_entrypoint = fragment_witness
        .entrypoint(target.entrypoint)
        .ok_or_else(|| {
            anyhow!(
                "confidential-core lowering bundle for {} dropped entrypoint {}",
                name,
                target.entrypoint
            )
        })?;
    let (bundle_path, confidential_core_lowering_bundle_json_bytes) =
        write_temp_json(name, &bundle)?;
    let output = Command::new(checker)
        .arg(&bundle_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean confidential-core lowering validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "boundary_events": witness.boundary_schedule().len(),
        "controller_phase_count": witness.controller_shape().controller_phase_order.len(),
        "controller_accesses": witness.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": witness.normalized_micro_trace().page_trace.len(),
        "exit_events": witness.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events": witness.normalized_micro_trace().shared_resource_pattern.len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            witness.runtime_kernel_refinement_witness(),
            exact_kernel_witness.as_ref(),
        ),
        "confidential_program": {
            "entrypoint_id": bundle.confidential_program().entrypoint_id.as_str(),
            "param_count": bundle.confidential_program().params.len(),
            "secret_arg_count": bundle.confidential_program().secret_args.len(),
            "statement_count": bundle.confidential_program().body.len(),
            "expected_runtime_step_count":
                bundle.confidential_program().expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_slot_program": {
            "entrypoint_id": bundle.confidential_slot_program().entrypoint_id.as_str(),
            "param_count": bundle.confidential_slot_program().param_count,
            "secret_arg_count": bundle.confidential_slot_program().secret_args.len(),
            "slot_count": bundle.confidential_slot_program().slot_count,
            "statement_count": bundle.confidential_slot_program().body.len(),
            "expected_runtime_step_count":
                bundle.confidential_slot_program().expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_fragment_witness": {
            "contract": fragment_witness.contract.as_str(),
            "entrypoint_count": fragment_witness.entrypoints.len(),
            "entrypoint": {
                "entrypoint_id": fragment_entrypoint.entrypoint_id.as_str(),
                "select_count": fragment_entrypoint.select_count,
                "struct_field_count": fragment_entrypoint.struct_field_count,
                "array_index_count": fragment_entrypoint.array_index_count,
                "non_branchless_select_arm_count": fragment_entrypoint.non_branchless_select_arm_count,
                "accepted": fragment_entrypoint.valid(),
            },
            "accepted": fragment_witness.valid_for_entrypoint(target.entrypoint),
        },
        "confidential_core_lowering_bundle_json_bytes":
            confidential_core_lowering_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_confidential_core_shell_boundary_lowering_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let runtime_witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if runtime_witness.kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if runtime_witness.runtime_kernel_refinement_witness()
        != trace.runtime_kernel_refinement_witness()
    {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
    let bundle = trace.runtime_confidential_core_shell_boundary_lowering_bundle(artifact)?;
    if bundle.runtime_witness() != &runtime_witness {
        return Err(anyhow!(
            "confidential-core shell-boundary lowering bundle for {} does not preserve the runtime witness",
            name
        ));
    }
    if bundle.shell_boundary_bundle() != &shell_boundary_bundle {
        return Err(anyhow!(
            "confidential-core shell-boundary lowering bundle for {} does not preserve the shell-boundary bundle",
            name
        ));
    }
    let shell_boundary_bundle_ref = bundle.shell_boundary_bundle();
    let confidential_program = bundle.confidential_program();
    let confidential_slot_program = bundle.confidential_slot_program();

    let fragment_witness = artifact.confidential_fragment_witness();
    let fragment_entrypoint = fragment_witness
        .entrypoint(target.entrypoint)
        .ok_or_else(|| {
            anyhow!(
                "confidential-core shell-boundary lowering bundle for {} dropped entrypoint {}",
                name,
                target.entrypoint
            )
        })?;
    let (bundle_path, confidential_core_shell_boundary_lowering_bundle_json_bytes) =
        write_temp_json(name, &bundle)?;
    let output = Command::new(checker)
        .arg(&bundle_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean confidential-core shell-boundary lowering validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "boundary_events": runtime_witness.boundary_schedule().len(),
        "controller_phase_count": runtime_witness.controller_shape().controller_phase_order.len(),
        "controller_accesses": runtime_witness.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": runtime_witness.normalized_micro_trace().page_trace.len(),
        "exit_events": runtime_witness.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events":
            runtime_witness.normalized_micro_trace().shared_resource_pattern.len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            runtime_witness.runtime_kernel_refinement_witness(),
            exact_kernel_witness.as_ref(),
        ),
        "shell_contract": runtime_shell_contract_summary(
            shell_boundary_bundle_ref.shell_contract(),
        ),
        "shell_trace": runtime_shell_trace_summary(
            shell_boundary_bundle_ref.shell_trace(),
            Some(shell_boundary_bundle_ref.shell_contract()),
        ),
        "confidential_program": {
            "entrypoint_id": confidential_program.entrypoint_id.as_str(),
            "param_count": confidential_program.params.len(),
            "secret_arg_count": confidential_program.secret_args.len(),
            "statement_count": confidential_program.body.len(),
            "expected_runtime_step_count":
                confidential_program.expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_slot_program": {
            "entrypoint_id": confidential_slot_program.entrypoint_id.as_str(),
            "param_count": confidential_slot_program.param_count,
            "secret_arg_count": confidential_slot_program.secret_args.len(),
            "slot_count": confidential_slot_program.slot_count,
            "statement_count": confidential_slot_program.body.len(),
            "expected_runtime_step_count":
                confidential_slot_program.expected_runtime_steps().len(),
            "matches_runtime_entrypoint": bundle.program_matches_runtime_entrypoint(),
        },
        "confidential_fragment_witness": {
            "contract": fragment_witness.contract.as_str(),
            "entrypoint_count": fragment_witness.entrypoints.len(),
            "entrypoint": {
                "entrypoint_id": fragment_entrypoint.entrypoint_id.as_str(),
                "select_count": fragment_entrypoint.select_count,
                "struct_field_count": fragment_entrypoint.struct_field_count,
                "array_index_count": fragment_entrypoint.array_index_count,
                "non_branchless_select_arm_count": fragment_entrypoint.non_branchless_select_arm_count,
                "accepted": fragment_entrypoint.valid(),
            },
            "accepted": fragment_witness.valid_for_entrypoint(target.entrypoint),
        },
        "confidential_core_shell_boundary_lowering_bundle_json_bytes":
            confidential_core_shell_boundary_lowering_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn run_kernel_dsl_validation(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let checker = lean_proofgrade_kernel_dsl_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_kernel_dsl_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_kernel_slot_dsl_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_kernel_slot_dsl_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_kernel_slot_dsl_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn run_kernel_lowering_validation(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let checker = lean_proofgrade_kernel_lowering_checker_path()?;
    let (scenarios, excluded_scenarios) =
        collect_proofgrade_runtime_validation_scenarios(suite, |name, artifact, setup, target| {
            validate_kernel_lowering_case(name, artifact, setup, target, &checker)
        })?;

    Ok(json!({
        "checker": display_report_path(&checker),
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
        "excluded_scenarios": excluded_scenarios,
    }))
}

fn validate_kernel_dsl_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let kernel_witness = exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?
        .ok_or_else(|| {
            anyhow!(
                "kernel DSL validation scenario {} is not confidential",
                name
            )
        })?;
    if trace.runtime_kernel_witness() != Some(&kernel_witness) {
        return Err(anyhow!(
            "execution trace for {} does not preserve the exact runtime kernel witness",
            name
        ));
    }

    let bundle = artifact
        .runtime_kernel_dsl_bundle_for_entrypoint(kernel_witness.clone(), target.entrypoint)?;
    let program = bundle.confidential_program();
    let (bundle_path, kernel_dsl_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker).arg(&bundle_path).output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean kernel DSL validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "kernel_witness": kernel_witness_summary(Some(&kernel_witness)),
        "confidential_program": {
            "entrypoint_id": program.entrypoint_id.as_str(),
            "param_count": program.params.len(),
            "secret_arg_count": program.secret_args.len(),
            "statement_count": program.body.len(),
            "expected_runtime_step_count": program.expected_runtime_steps().len(),
        },
        "kernel_dsl_bundle_json_bytes": kernel_dsl_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_kernel_slot_dsl_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let kernel_witness = exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?
        .ok_or_else(|| {
            anyhow!(
                "kernel slot DSL validation scenario {} is not confidential",
                name
            )
        })?;
    if trace.runtime_kernel_witness() != Some(&kernel_witness) {
        return Err(anyhow!(
            "execution trace for {} does not preserve the exact runtime kernel witness",
            name
        ));
    }

    let bundle = artifact
        .runtime_kernel_slot_dsl_bundle_for_entrypoint(kernel_witness.clone(), target.entrypoint)?;
    let program = bundle.confidential_slot_program();
    let (bundle_path, kernel_slot_dsl_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker).arg(&bundle_path).output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean kernel slot DSL validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "kernel_witness": kernel_witness_summary(Some(&kernel_witness)),
        "confidential_slot_program": {
            "entrypoint_id": program.entrypoint_id.as_str(),
            "param_count": program.param_count,
            "secret_arg_count": program.secret_args.len(),
            "slot_count": program.slot_count,
            "statement_count": program.body.len(),
            "expected_runtime_step_count": program.expected_runtime_steps().len(),
        },
        "kernel_slot_dsl_bundle_json_bytes": kernel_slot_dsl_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_kernel_lowering_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let kernel_witness = exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?
        .ok_or_else(|| {
            anyhow!(
                "kernel lowering validation scenario {} is not confidential",
                name
            )
        })?;
    if trace.runtime_kernel_witness() != Some(&kernel_witness) {
        return Err(anyhow!(
            "execution trace for {} does not preserve the exact runtime kernel witness",
            name
        ));
    }

    let bundle = artifact
        .runtime_kernel_lowering_bundle_for_entrypoint(kernel_witness.clone(), target.entrypoint)?;
    let (bundle_path, kernel_lowering_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker).arg(&bundle_path).output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean kernel lowering validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "kernel_witness": kernel_witness_summary(Some(&kernel_witness)),
        "confidential_program": {
            "entrypoint_id": bundle.confidential_program().entrypoint_id.as_str(),
            "param_count": bundle.confidential_program().params.len(),
            "secret_arg_count": bundle.confidential_program().secret_args.len(),
            "statement_count": bundle.confidential_program().body.len(),
            "expected_runtime_step_count":
                bundle.confidential_program().expected_runtime_steps().len(),
        },
        "confidential_slot_program": {
            "entrypoint_id": bundle.confidential_slot_program().entrypoint_id.as_str(),
            "param_count": bundle.confidential_slot_program().param_count,
            "secret_arg_count": bundle.confidential_slot_program().secret_args.len(),
            "slot_count": bundle.confidential_slot_program().slot_count,
            "statement_count": bundle.confidential_slot_program().body.len(),
            "expected_runtime_step_count":
                bundle.confidential_slot_program().expected_runtime_steps().len(),
        },
        "kernel_lowering_bundle_json_bytes": kernel_lowering_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_kernel_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let kernel_witness = exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?
        .ok_or_else(|| anyhow!("kernel validation scenario {} is not confidential", name))?;
    if trace.runtime_kernel_witness() != Some(&kernel_witness) {
        return Err(anyhow!(
            "execution trace for {} does not preserve the exact runtime kernel witness",
            name
        ));
    }
    let (kernel_path, kernel_json_bytes) = write_temp_json(name, &kernel_witness)?;
    let output = Command::new(checker)
        .arg(&kernel_path)
        .arg(target.entrypoint)
        .output()?;
    let _ = fs::remove_file(&kernel_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean kernel validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "kernel_op_count": kernel_witness.kernel_steps.len(),
        "kernel_step_count": kernel_witness.kernel_steps.len(),
        "object_step_count": kernel_witness.kernel_steps.iter().filter(|step| step.object_id.is_some()).count(),
        "kernel_witness": kernel_witness_summary(Some(&kernel_witness)),
        "kernel_json_bytes": kernel_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_kernel_refinement_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let kernel_witness = exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?
        .ok_or_else(|| {
            anyhow!(
                "kernel refinement validation scenario {} is not confidential",
                name
            )
        })?;
    let runtime_kernel_refinement_witness = trace
        .runtime_kernel_refinement_witness()
        .cloned()
        .ok_or_else(|| {
            anyhow!(
                "execution trace for {} is missing the runtime kernel refinement witness",
                name
            )
        })?;
    runtime_kernel_refinement_witness.validate_with_kernel_witness(&kernel_witness)?;
    let refinement_case_name = format!("{name}-kernel-refinement");
    let kernel_case_name = format!("{name}-kernel");
    let (refinement_path, refinement_json_bytes) =
        write_temp_json(&refinement_case_name, &runtime_kernel_refinement_witness)?;
    let (kernel_path, kernel_json_bytes) = write_temp_json(&kernel_case_name, &kernel_witness)?;
    let output = Command::new(checker)
        .arg(&refinement_path)
        .arg(&kernel_path)
        .arg(target.entrypoint)
        .output()?;
    let _ = fs::remove_file(&refinement_path);
    let _ = fs::remove_file(&kernel_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean kernel refinement validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "runtime_phase_event_count": runtime_kernel_refinement_witness.event_count(),
        "projected_kernel_step_count": runtime_kernel_refinement_witness.projected_kernel_schedule().steps.len(),
        "pre_committed_cold_object_count": runtime_kernel_refinement_witness
            .pre_committed_cold_object_schedule()
            .len(),
        "post_committed_cold_object_count": runtime_kernel_refinement_witness
            .post_committed_cold_object_schedule()
            .len(),
        "shadow_load_count": runtime_kernel_refinement_witness.shadow_load_object_schedule().len(),
        "commit_object_count": runtime_kernel_refinement_witness.commit_object_schedule().len(),
        "cold_store_object_count": runtime_kernel_refinement_witness.cold_store_object_schedule().len(),
        "kernel_witness": kernel_witness_summary(Some(&kernel_witness)),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            Some(&runtime_kernel_refinement_witness),
            Some(&kernel_witness),
        ),
        "kernel_refinement_json_bytes": refinement_json_bytes,
        "kernel_json_bytes": kernel_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_shell_boundary_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let runtime_witness = trace.runtime_refinement_witness()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?.ok_or_else(
            || {
                anyhow!(
                    "shell-boundary validation scenario {} is not confidential",
                    name
                )
            },
        )?;
    if runtime_witness.kernel_witness() != Some(&exact_kernel_witness) {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if runtime_witness.runtime_kernel_refinement_witness()
        != trace.runtime_kernel_refinement_witness()
    {
        return Err(anyhow!(
            "runtime refinement witness for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let bundle = trace.runtime_shell_boundary_bundle()?;
    if bundle.kernel_witness() != &exact_kernel_witness {
        return Err(anyhow!(
            "runtime shell-boundary bundle for {} does not preserve the exact kernel witness",
            name
        ));
    }
    if runtime_witness.runtime_kernel_refinement_witness()
        != Some(bundle.runtime_kernel_refinement_witness())
    {
        return Err(anyhow!(
            "runtime shell-boundary bundle for {} does not preserve the runtime phase witness",
            name
        ));
    }

    let (bundle_path, shell_boundary_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker).arg(&bundle_path).output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean shell-boundary validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": trace.gas_used,
        "kernel_witness": kernel_witness_summary(Some(bundle.kernel_witness())),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            Some(bundle.runtime_kernel_refinement_witness()),
            Some(bundle.kernel_witness()),
        ),
        "shell_contract": runtime_shell_contract_summary(bundle.shell_contract()),
        "shell_trace": runtime_shell_trace_summary(
            bundle.shell_trace(),
            Some(bundle.shell_contract()),
        ),
        "shell_contract_matches_kernel_witness":
            bundle.shell_contract() == &bundle.kernel_witness().shell_contract(),
        "shell_trace_matches_runtime_phase_witness":
            bundle.shell_trace()
                == &bundle.runtime_kernel_refinement_witness().shell_trace(),
        "shell_boundary_bundle_json_bytes": shell_boundary_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_shell_boundary_slot_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?.ok_or_else(
            || {
                anyhow!(
                    "shell-boundary slot validation scenario {} is not confidential",
                    name
                )
            },
        )?;
    if shell_boundary_bundle.kernel_witness() != &exact_kernel_witness {
        return Err(anyhow!(
            "runtime shell-boundary bundle for {} does not preserve the exact kernel witness",
            name
        ));
    }

    let bundle = trace.runtime_shell_boundary_slot_bundle(artifact)?;
    if bundle.shell_boundary_bundle() != &shell_boundary_bundle {
        return Err(anyhow!(
            "runtime shell-boundary slot bundle for {} does not preserve the exact shell-boundary bundle",
            name
        ));
    }
    let shell_boundary_bundle_ref = bundle.shell_boundary_bundle();
    let confidential_slot_program = bundle.confidential_slot_program();
    let (bundle_path, shell_boundary_slot_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker).arg(&bundle_path).output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean shell-boundary slot validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "kernel_witness": kernel_witness_summary(Some(
            shell_boundary_bundle_ref.kernel_witness(),
        )),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            Some(shell_boundary_bundle_ref.runtime_kernel_refinement_witness()),
            Some(shell_boundary_bundle_ref.kernel_witness()),
        ),
        "shell_contract": runtime_shell_contract_summary(
            shell_boundary_bundle_ref.shell_contract(),
        ),
        "shell_trace": runtime_shell_trace_summary(
            shell_boundary_bundle_ref.shell_trace(),
            Some(shell_boundary_bundle_ref.shell_contract()),
        ),
        "confidential_slot_program": {
            "entrypoint_id": confidential_slot_program.entrypoint_id.as_str(),
            "param_count": confidential_slot_program.param_count,
            "secret_arg_count": confidential_slot_program.secret_args.len(),
            "slot_count": confidential_slot_program.slot_count,
            "statement_count": confidential_slot_program.body.len(),
            "expected_runtime_step_count": confidential_slot_program.expected_runtime_steps().len(),
            "matches_shell_entrypoint": bundle.program_matches_shell_entrypoint(),
        },
        "shell_boundary_slot_bundle_json_bytes": shell_boundary_slot_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_shell_boundary_lowering_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let shell_boundary_bundle = trace.runtime_shell_boundary_bundle()?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?.ok_or_else(
            || {
                anyhow!(
                    "shell-boundary lowering validation scenario {} is not confidential",
                    name
                )
            },
        )?;
    if shell_boundary_bundle.kernel_witness() != &exact_kernel_witness {
        return Err(anyhow!(
            "runtime shell-boundary bundle for {} does not preserve the exact kernel witness",
            name
        ));
    }

    let bundle = trace.runtime_shell_boundary_lowering_bundle(artifact)?;
    if bundle.shell_boundary_bundle() != &shell_boundary_bundle {
        return Err(anyhow!(
            "runtime shell-boundary lowering bundle for {} does not preserve the exact shell-boundary bundle",
            name
        ));
    }
    let shell_boundary_bundle_ref = bundle.shell_boundary_bundle();
    let confidential_program = bundle.confidential_program();
    let confidential_slot_program = bundle.confidential_slot_program();
    let (bundle_path, shell_boundary_lowering_bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker).arg(&bundle_path).output()?;
    let _ = fs::remove_file(&bundle_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean shell-boundary lowering validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "kernel_witness": kernel_witness_summary(Some(
            shell_boundary_bundle_ref.kernel_witness(),
        )),
        "runtime_kernel_refinement_witness": runtime_kernel_refinement_witness_summary(
            Some(shell_boundary_bundle_ref.runtime_kernel_refinement_witness()),
            Some(shell_boundary_bundle_ref.kernel_witness()),
        ),
        "shell_contract": runtime_shell_contract_summary(
            shell_boundary_bundle_ref.shell_contract(),
        ),
        "shell_trace": runtime_shell_trace_summary(
            shell_boundary_bundle_ref.shell_trace(),
            Some(shell_boundary_bundle_ref.shell_contract()),
        ),
        "confidential_program": {
            "entrypoint_id": confidential_program.entrypoint_id.as_str(),
            "param_count": confidential_program.params.len(),
            "secret_arg_count": confidential_program.secret_args.len(),
            "statement_count": confidential_program.body.len(),
            "expected_runtime_step_count": confidential_program.expected_runtime_steps().len(),
            "matches_shell_entrypoint": bundle.program_matches_shell_entrypoint(),
        },
        "confidential_slot_program": {
            "entrypoint_id": confidential_slot_program.entrypoint_id.as_str(),
            "param_count": confidential_slot_program.param_count,
            "secret_arg_count": confidential_slot_program.secret_args.len(),
            "slot_count": confidential_slot_program.slot_count,
            "statement_count": confidential_slot_program.body.len(),
            "expected_runtime_step_count": confidential_slot_program.expected_runtime_steps().len(),
            "matches_shell_entrypoint": bundle.program_matches_shell_entrypoint(),
        },
        "shell_boundary_lowering_bundle_json_bytes": shell_boundary_lowering_bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_trusted_kernel_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let bundle = trace.runtime_trusted_kernel_slot_bundle(artifact)?;
    let exact_kernel_witness =
        exact_confidential_kernel_witness(&trace, artifact, target.entrypoint)?;
    if bundle.trusted_kernel_bundle().kernel_witness() != exact_kernel_witness.as_ref() {
        return Err(anyhow!(
            "runtime trusted-kernel bundle for {} does not preserve the exact kernel witness",
            name
        ));
    }
    let trusted_kernel_bundle = bundle.trusted_kernel_bundle();
    let controller_observer = trusted_kernel_bundle.controller_observer();
    let hidden_certificate = trusted_kernel_bundle.hidden_certificate();
    let confidential_slot_program = bundle.confidential_slot_program();
    let (bundle_path, bundle_json_bytes) = write_temp_json(name, &bundle)?;
    let output = Command::new(checker)
        .arg(&bundle_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !output.status.success() {
        return Err(anyhow!(
            "Lean trusted-kernel validation failed for {}: {} (bundle preserved at {})",
            name,
            String::from_utf8_lossy(&output.stderr).trim(),
            bundle_path.display()
        ));
    }
    let _ = fs::remove_file(&bundle_path);
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": controller_observer.public_outcome().gas_used,
        "boundary_events": controller_observer.boundary_schedule().len(),
        "controller_phase_count":
            controller_observer.controller_shape().controller_phase_order.len(),
        "controller_accesses":
            controller_observer.controller_certificate().observed_oram_accesses().len(),
        "leaf_steps": hidden_certificate.oram_leaf_schedule().len(),
        "position_map_objects":
            hidden_certificate.oram_position_map_before().len(),
        "kernel_witness": kernel_witness_summary(exact_kernel_witness.as_ref()),
        "confidential_slot_program": {
            "entrypoint_id": confidential_slot_program.entrypoint_id.as_str(),
            "param_count": confidential_slot_program.param_count,
            "secret_arg_count": confidential_slot_program.secret_args.len(),
            "slot_count": confidential_slot_program.slot_count,
            "statement_count": confidential_slot_program.body.len(),
            "expected_runtime_step_count":
                confidential_slot_program.expected_runtime_steps().len(),
            "matches_trusted_kernel_entrypoint":
                bundle.program_matches_trusted_kernel_entrypoint(),
        },
        "bundle_json_bytes": bundle_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_controller_certificate_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let certificate = trace.runtime_controller_observer_certificate()?;
    let (certificate_path, certificate_json_bytes) = write_temp_json(name, &certificate)?;
    let output = Command::new(checker)
        .arg(&certificate_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&certificate_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean controller-observer validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "gas_used": certificate.public_outcome().gas_used,
        "boundary_events": certificate.boundary_schedule().len(),
        "controller_phase_count": certificate.controller_shape().controller_phase_order.len(),
        "controller_accesses": certificate.controller_certificate().observed_oram_accesses().len(),
        "page_trace_events": certificate.normalized_micro_trace().page_trace.len(),
        "exit_events": certificate.normalized_micro_trace().exit_pattern.len(),
        "shared_resource_events": certificate.normalized_micro_trace().shared_resource_pattern.len(),
        "certificate_json_bytes": certificate_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_pathoram_hidden_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
) -> Result<JsonValue> {
    let trace = run_target_call(artifact, setup, target.entrypoint, target.args.clone())?;
    let certificate = trace.runtime_path_oram_hidden_certificate()?;
    let (certificate_path, certificate_json_bytes) = write_temp_json(name, &certificate)?;
    let output = Command::new(checker).arg(&certificate_path).output()?;
    let _ = fs::remove_file(&certificate_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean path-ORAM hidden validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "leaf_steps": certificate.oram_leaf_schedule().len(),
        "public_leaf_scaffold_steps": certificate.oram_leaf_public_scaffold().len(),
        "position_map_objects": certificate.oram_position_map_before().len(),
        "certificate_json_bytes": certificate_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_seeded_witness_family_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    seed_count: usize,
    checker: &Path,
) -> Result<JsonValue> {
    let mut witnesses = Vec::with_capacity(seed_count);
    let mut gas_used = BTreeSet::new();
    let mut boundary_events = BTreeSet::new();
    let mut controller_phase_counts = BTreeSet::new();
    let mut public_leaf_scaffold_steps = BTreeSet::new();
    let mut oram_object_configs = BTreeSet::new();
    let mut physical_read_shapes = BTreeSet::new();
    let mut physical_write_shapes = BTreeSet::new();
    for seed in 0..seed_count {
        let trace = run_target_call_with_seed(
            artifact,
            setup,
            target.entrypoint,
            target.args.clone(),
            seed as u64,
        )?;
        let witness = trace.runtime_refinement_witness()?;
        gas_used.insert(witness.trace().gas_used);
        boundary_events.insert(witness.boundary_schedule().len());
        controller_phase_counts.insert(witness.controller_shape().controller_phase_order.len());
        public_leaf_scaffold_steps.insert(witness.oram_leaf_public_scaffold().len());
        oram_object_configs.insert(serde_json::to_string(witness.oram_objects())?);
        physical_read_shapes.insert(serde_json::to_string(&witness.trace().physical_reads)?);
        physical_write_shapes.insert(serde_json::to_string(&witness.trace().physical_writes)?);
        witnesses.push(witness);
    }
    let family = SeededRuntimePathOramWitnessFamily::new(witnesses)?;
    let canonical_leaf_seed_space_size =
        canonical_path_oram_leaf_seed_space_size(family.public_leaf_scaffold());
    let canonical_leaf_values_match =
        family
            .witnesses()
            .iter()
            .enumerate()
            .all(|(seed, witness)| {
                witness
                    .oram_leaf_schedule()
                    .iter()
                    .map(|step| step.leaf)
                    .collect::<Vec<_>>()
                    == canonical_path_oram_leaf_values_of_seed(family.public_leaf_scaffold(), seed)
            });
    let (family_path, family_json_bytes) = write_temp_json(name, &family)?;
    let output = Command::new(checker)
        .arg(&family_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&family_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean seeded witness family validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "setup_calls": setup.len(),
        "seed_count": seed_count,
        "gas_uniform": gas_used.len() == 1,
        "boundary_uniform": boundary_events.len() == 1,
        "controller_phase_uniform": controller_phase_counts.len() == 1,
        "public_leaf_scaffold_uniform": public_leaf_scaffold_steps.len() == 1,
        "oram_object_config_uniform": oram_object_configs.len() == 1,
        "physical_read_shape_uniform": physical_read_shapes.len() == 1,
        "physical_write_shape_uniform": physical_write_shapes.len() == 1,
        "public_leaf_scaffold_steps": family.public_leaf_scaffold().len(),
        "canonical_leaf_seed_space_size": canonical_leaf_seed_space_size,
        "canonical_leaf_seed_space_matches":
            canonical_leaf_seed_space_size == Some(family.seed_count()),
        "canonical_leaf_values_match_runtime_seed": canonical_leaf_values_match,
        "witness_family_json_bytes": family_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_fresh_coin_family_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    family_checker: &Path,
    theorem_input_checker: &Path,
    options: &ProbeRunOptions,
) -> Result<JsonValue> {
    let estimate = estimate_canonical_fresh_coin_family_size(
        name,
        artifact,
        setup,
        target,
        CANONICAL_SIZE_ESTIMATE_SAMPLE_SEEDS,
    )?;
    if options.should_try_heavy_materialization(estimate.estimated_family_json_bytes) {
        return validate_fresh_coin_heavy_case(
            name,
            artifact,
            setup,
            target,
            family_checker,
            options,
            estimate,
        );
    }
    if estimate.estimated_family_json_bytes > options.compact_budget_bytes {
        return validate_fresh_coin_theorem_input_case(
            name,
            artifact,
            setup,
            target,
            theorem_input_checker,
            options.compact_budget_bytes,
            estimate,
        );
    }

    let collected = collect_canonical_fresh_coin_family_case(name, artifact, setup, target)?;
    let family = collected.family;
    let first_witness = collected.first_witness;
    let public_leaf_scaffold_step_count = first_witness.oram_leaf_public_scaffold().len();
    let public_fresh_coin_scaffold_step_count = family.public_fresh_coin_scaffold().len();
    let gas_uniform = family
        .witnesses()
        .iter()
        .map(|w| w.trace().gas_used)
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let boundary_uniform = family
        .witnesses()
        .iter()
        .map(|w| w.boundary_schedule().len())
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let controller_phase_uniform = family
        .witnesses()
        .iter()
        .map(|w| w.controller_shape().controller_phase_order.len())
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let public_leaf_scaffold_uniform = family
        .witnesses()
        .iter()
        .map(|w| w.oram_leaf_public_scaffold().len())
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let public_fresh_coin_scaffold_uniform = family
        .witnesses()
        .iter()
        .map(|w| {
            w.path_oram_fresh_coin_scaffold()
                .map(|s| s.len())
                .unwrap_or(usize::MAX)
        })
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let oram_object_config_uniform = family
        .witnesses()
        .iter()
        .map(|w| serde_json::to_string(w.oram_objects()))
        .collect::<Result<BTreeSet<_>, _>>()?
        .len()
        == 1;
    let canonical_fresh_coin_values_match_index =
        family
            .witnesses()
            .iter()
            .enumerate()
            .all(|(seed, witness)| {
                witness.path_oram_fresh_coin_values().unwrap_or_default()
                    == canonical_path_oram_leaf_values_of_seed(
                        family.public_fresh_coin_scaffold(),
                        seed,
                    )
            });
    let (family_path, family_json_bytes) = write_temp_json(name, &family)?;
    let output = Command::new(family_checker)
        .arg(&family_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&family_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean canonical fresh-coin family validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    let persisted_artifact =
        persist_heavy_artifact_json(options, name, "canonical_fresh_coin_family.json", &family)?;

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "validation_status": "accepted",
        "setup_calls": setup.len(),
        "mode": "injected_canonical_tape",
        "deploy_seed": 0,
        "seed_count": family.seed_count(),
        "distinct_canonical_seeds_found": family.seed_count(),
        "coverage_fraction": 1.0,
        "coverage_complete": true,
        "gas_uniform": gas_uniform,
        "boundary_uniform": boundary_uniform,
        "controller_phase_uniform": controller_phase_uniform,
        "public_leaf_scaffold_uniform": public_leaf_scaffold_uniform,
        "public_fresh_coin_scaffold_uniform": public_fresh_coin_scaffold_uniform,
        "oram_object_config_uniform": oram_object_config_uniform,
        "public_leaf_scaffold_steps": public_leaf_scaffold_step_count,
        "public_fresh_coin_scaffold_steps": public_fresh_coin_scaffold_step_count,
        "canonical_fresh_coin_seed_space_size": Some(family.seed_count()),
        "canonical_fresh_coin_values_match_index": canonical_fresh_coin_values_match_index,
        "witness_family_json_bytes": family_json_bytes,
        "heavy_artifact_path": persisted_artifact.as_ref().map(|(path, _)| path.clone()),
        "heavy_artifact_json_bytes": persisted_artifact.as_ref().map(|(_, bytes)| *bytes),
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "lean_validated": true,
        "accepted": true,
    }))
}

fn validate_fresh_coin_theorem_input_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
    budget_bytes: u64,
    estimate: CanonicalFamilySizeEstimate,
) -> Result<JsonValue> {
    let collected = collect_canonical_fresh_coin_theorem_input_case(name, artifact, setup, target)?;
    let theorem_input = collected.input;
    let representative_values = theorem_input
        .representative_witness()
        .path_oram_fresh_coin_values()
        .ok_or_else(|| {
            anyhow!(
                "fresh-coin value extraction failed for {} representative seed {}",
                name,
                theorem_input.representative_seed()
            )
        })?;
    let canonical_values = canonical_path_oram_leaf_values_of_seed(
        theorem_input.public_fresh_coin_scaffold(),
        theorem_input.representative_seed(),
    );
    let (theorem_input_path, theorem_input_json_bytes) = write_temp_json(name, &theorem_input)?;
    let output = Command::new(checker)
        .arg(&theorem_input_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&theorem_input_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean canonical fresh-coin theorem-input validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "validation_status": "accepted_compact_theorem_input",
        "reason": format!(
            "estimated explicit canonical fresh-coin family exceeds safe budget {}; compact theorem input used instead",
            budget_bytes
        ),
        "budget_bytes": budget_bytes,
        "size_estimate": estimate,
        "setup_calls": setup.len(),
        "mode": "compact_canonical_seed_space",
        "deploy_seed": 0,
        "representative_seed": theorem_input.representative_seed(),
        "representative_witness_count": 1,
        "seed_count": theorem_input.seed_count(),
        "symbolic_seed_space_instantiated": true,
        "coverage_complete": false,
        "public_leaf_scaffold_steps": theorem_input.public_leaf_scaffold().len(),
        "public_fresh_coin_scaffold_steps": theorem_input.public_fresh_coin_scaffold().len(),
        "canonical_fresh_coin_seed_space_size": Some(theorem_input.seed_count()),
        "canonical_fresh_coin_values_match_representative_seed": representative_values == canonical_values,
        "theorem_input_json_bytes": theorem_input_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "lean_validated": true,
        "accepted": true,
    }))
}

fn collect_canonical_fresh_coin_family_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
) -> Result<CollectedCanonicalFreshCoinFamily> {
    let deploy_seed = 0u64;
    let prepared = prepare_instance_with_seed(artifact, setup, deploy_seed)?;
    let mut first_instance = prepared.clone();
    let first_trace = first_instance
        .call(target.entrypoint, target.args.clone())?
        .trace;
    let first_witness = first_trace.runtime_refinement_witness()?;
    let fresh_coin_scaffold = first_witness
        .path_oram_fresh_coin_scaffold()
        .ok_or_else(|| anyhow!("fresh-coin scaffold extraction failed for {}", name))?;
    let seed_count = canonical_path_oram_leaf_seed_space_size(&fresh_coin_scaffold)
        .ok_or_else(|| anyhow!("fresh-coin seed space overflow for {}", name))?;

    let witnesses = (0..seed_count)
        .into_par_iter()
        .map(|seed| -> Result<RuntimeRefinementWitness> {
            let fresh_coin_values =
                canonical_path_oram_leaf_values_of_seed(&fresh_coin_scaffold, seed);
            let fresh_coin_plan = PathOramFreshCoinPlan::from_scaffold_and_values(
                &fresh_coin_scaffold,
                &fresh_coin_values,
            )?;
            let mut instance = prepared.clone();
            let trace = instance
                .call_with_path_oram_fresh_coins(
                    target.entrypoint,
                    target.args.clone(),
                    fresh_coin_plan,
                )?
                .trace;
            let witness = trace.runtime_refinement_witness()?;
            let extracted_scaffold = witness.path_oram_fresh_coin_scaffold().ok_or_else(|| {
                anyhow!(
                    "fresh-coin scaffold extraction failed for {} seed {}",
                    name,
                    seed
                )
            })?;
            let extracted_values = witness.path_oram_fresh_coin_values().ok_or_else(|| {
                anyhow!(
                    "fresh-coin value extraction failed for {} seed {}",
                    name,
                    seed
                )
            })?;
            if extracted_scaffold != fresh_coin_scaffold || extracted_values != fresh_coin_values {
                return Err(anyhow!(
                    "canonical fresh-coin extraction mismatch for {} seed {}",
                    name,
                    seed
                ));
            }
            Ok(witness)
        })
        .collect::<Result<Vec<_>>>()?;
    Ok(CollectedCanonicalFreshCoinFamily {
        family: CanonicalFreshCoinRuntimePathOramWitnessFamily::new(witnesses)?,
        first_witness,
        access_counters_before: first_trace.runtime_oram_access_counters_before().to_vec(),
    })
}

fn collect_canonical_fresh_coin_theorem_input_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
) -> Result<CollectedCanonicalFreshCoinTheoremInput> {
    let deploy_seed = 0u64;
    let prepared = prepare_instance_with_seed(artifact, setup, deploy_seed)?;
    let mut first_instance = prepared.clone();
    let first_trace = first_instance
        .call(target.entrypoint, target.args.clone())?
        .trace;
    let first_witness = first_trace.runtime_refinement_witness()?;
    let fresh_coin_scaffold = first_witness
        .path_oram_fresh_coin_scaffold()
        .ok_or_else(|| anyhow!("fresh-coin scaffold extraction failed for {}", name))?;
    let representative_seed = 0usize;
    let fresh_coin_values =
        canonical_path_oram_leaf_values_of_seed(&fresh_coin_scaffold, representative_seed);
    let fresh_coin_plan =
        PathOramFreshCoinPlan::from_scaffold_and_values(&fresh_coin_scaffold, &fresh_coin_values)?;
    let mut representative_instance = prepared.clone();
    let representative_trace = representative_instance
        .call_with_path_oram_fresh_coins(target.entrypoint, target.args.clone(), fresh_coin_plan)?
        .trace;
    let representative_witness = representative_trace.runtime_refinement_witness()?;
    let extracted_scaffold = representative_witness
        .path_oram_fresh_coin_scaffold()
        .ok_or_else(|| {
            anyhow!(
                "fresh-coin scaffold extraction failed for {} representative seed {}",
                name,
                representative_seed
            )
        })?;
    let extracted_values = representative_witness
        .path_oram_fresh_coin_values()
        .ok_or_else(|| {
            anyhow!(
                "fresh-coin value extraction failed for {} representative seed {}",
                name,
                representative_seed
            )
        })?;
    if extracted_scaffold != fresh_coin_scaffold || extracted_values != fresh_coin_values {
        return Err(anyhow!(
            "canonical fresh-coin extraction mismatch for {} representative seed {}",
            name,
            representative_seed
        ));
    }
    let input = CanonicalFreshCoinRuntimePathOramTheoremInput::new(
        representative_seed,
        representative_witness,
    )
    .map_err(|err| {
        anyhow!(
            "canonical fresh-coin theorem input invalid for {}: {}",
            name,
            err
        )
    })?;
    Ok(CollectedCanonicalFreshCoinTheoremInput {
        input,
        access_counters_before: first_trace.runtime_oram_access_counters_before().to_vec(),
    })
}

fn estimate_canonical_fresh_coin_family_size(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    sample_seed_count: usize,
) -> Result<CanonicalFamilySizeEstimate> {
    let deploy_seed = 0u64;
    let prepared = prepare_instance_with_seed(artifact, setup, deploy_seed)?;
    let mut first_instance = prepared.clone();
    let first_trace = first_instance
        .call(target.entrypoint, target.args.clone())?
        .trace;
    let first_witness = first_trace.runtime_refinement_witness()?;
    let fresh_coin_scaffold = first_witness
        .path_oram_fresh_coin_scaffold()
        .ok_or_else(|| anyhow!("fresh-coin scaffold extraction failed for {}", name))?;
    let seed_count = canonical_path_oram_leaf_seed_space_size(&fresh_coin_scaffold)
        .ok_or_else(|| anyhow!("fresh-coin seed space overflow for {}", name))?;
    let sampled_seed_count = seed_count.min(sample_seed_count);
    let mut total_bytes = 0u64;
    let mut max_bytes = 0u64;

    for seed in 0..sampled_seed_count {
        let fresh_coin_values = canonical_path_oram_leaf_values_of_seed(&fresh_coin_scaffold, seed);
        let fresh_coin_plan = PathOramFreshCoinPlan::from_scaffold_and_values(
            &fresh_coin_scaffold,
            &fresh_coin_values,
        )?;
        let mut instance = prepared.clone();
        let trace = instance
            .call_with_path_oram_fresh_coins(
                target.entrypoint,
                target.args.clone(),
                fresh_coin_plan,
            )?
            .trace;
        let witness = trace.runtime_refinement_witness()?;
        let extracted_scaffold = witness.path_oram_fresh_coin_scaffold().ok_or_else(|| {
            anyhow!(
                "fresh-coin scaffold extraction failed for {} seed {}",
                name,
                seed
            )
        })?;
        let extracted_values = witness.path_oram_fresh_coin_values().ok_or_else(|| {
            anyhow!(
                "fresh-coin value extraction failed for {} seed {}",
                name,
                seed
            )
        })?;
        if extracted_scaffold != fresh_coin_scaffold || extracted_values != fresh_coin_values {
            return Err(anyhow!(
                "canonical fresh-coin extraction mismatch for {} seed {}",
                name,
                seed
            ));
        }
        let witness_bytes = serde_json::to_vec(&witness)?.len() as u64;
        total_bytes = total_bytes.saturating_add(witness_bytes);
        max_bytes = max_bytes.max(witness_bytes);
    }

    let avg_bytes = if sampled_seed_count == 0 {
        0
    } else {
        total_bytes / sampled_seed_count as u64
    };
    let estimated_family_json_bytes = max_bytes
        .saturating_mul(seed_count as u64)
        .saturating_add(1 << 20);

    Ok(CanonicalFamilySizeEstimate {
        seed_count,
        sampled_seed_count,
        avg_witness_json_bytes: avg_bytes,
        max_witness_json_bytes: max_bytes,
        estimated_family_json_bytes,
        public_leaf_scaffold_steps: first_witness.oram_leaf_public_scaffold().len(),
        public_fresh_coin_scaffold_steps: fresh_coin_scaffold.len(),
    })
}

fn prepare_canonical_fresh_coin_family(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
) -> Result<PreparedCanonicalFreshCoinFamily> {
    let deploy_seed = 0u64;
    let prepared = prepare_instance_with_seed(artifact, setup, deploy_seed)?;
    let mut first_instance = prepared.clone();
    let first_trace = first_instance
        .call(target.entrypoint, target.args.clone())?
        .trace;
    let first_witness = first_trace.runtime_refinement_witness()?;
    let public_leaf_scaffold = first_witness.oram_leaf_public_scaffold().to_vec();
    let public_fresh_coin_scaffold = first_witness
        .path_oram_fresh_coin_scaffold()
        .ok_or_else(|| anyhow!("fresh-coin scaffold extraction failed for {}", name))?;
    let seed_count = canonical_path_oram_leaf_seed_space_size(&public_fresh_coin_scaffold)
        .ok_or_else(|| anyhow!("fresh-coin seed space overflow for {}", name))?;
    Ok(PreparedCanonicalFreshCoinFamily {
        prepared,
        first_witness,
        access_counters_before: first_trace.runtime_oram_access_counters_before().to_vec(),
        public_leaf_scaffold,
        public_fresh_coin_scaffold,
        seed_count,
    })
}

fn update_uniform<T: Eq>(slot: &mut Option<T>, uniform: &mut bool, value: T) {
    match slot {
        Some(expected) => {
            if expected != &value {
                *uniform = false;
            }
        }
        None => *slot = Some(value),
    }
}

fn write_json_key<W: Write>(writer: &mut W, key: &str) -> Result<()> {
    serde_json::to_writer(&mut *writer, key)?;
    writer.write_all(b":")?;
    Ok(())
}

fn materialize_canonical_fresh_coin_family_object<W: Write>(
    writer: &mut W,
    name: &'static str,
    target: &CallSpec,
    context: &PreparedCanonicalFreshCoinFamily,
) -> Result<MaterializedCanonicalFreshCoinFamily> {
    writer.write_all(b"{")?;
    write_json_key(writer, "seed_count")?;
    serde_json::to_writer(&mut *writer, &context.seed_count)?;
    writer.write_all(b",")?;
    write_json_key(writer, "witnesses")?;
    writer.write_all(b"[")?;

    let mut gas_seen: Option<u64> = None;
    let mut boundary_seen: Option<usize> = None;
    let mut controller_phase_seen: Option<usize> = None;
    let mut oram_object_cfg_seen: Option<String> = None;
    let mut gas_uniform = true;
    let mut boundary_uniform = true;
    let mut controller_phase_uniform = true;
    let mut oram_object_config_uniform = true;

    for seed in 0..context.seed_count {
        let fresh_coin_values =
            canonical_path_oram_leaf_values_of_seed(&context.public_fresh_coin_scaffold, seed);
        let fresh_coin_plan = PathOramFreshCoinPlan::from_scaffold_and_values(
            &context.public_fresh_coin_scaffold,
            &fresh_coin_values,
        )?;
        let mut instance = context.prepared.clone();
        let trace = instance
            .call_with_path_oram_fresh_coins(
                target.entrypoint,
                target.args.clone(),
                fresh_coin_plan,
            )?
            .trace;
        let witness = trace.runtime_refinement_witness()?;
        let extracted_scaffold = witness.path_oram_fresh_coin_scaffold().ok_or_else(|| {
            anyhow!(
                "fresh-coin scaffold extraction failed for {} seed {}",
                name,
                seed
            )
        })?;
        let extracted_values = witness.path_oram_fresh_coin_values().ok_or_else(|| {
            anyhow!(
                "fresh-coin value extraction failed for {} seed {}",
                name,
                seed
            )
        })?;
        if witness.oram_leaf_public_scaffold() != context.public_leaf_scaffold.as_slice()
            || extracted_scaffold != context.public_fresh_coin_scaffold
            || extracted_values != fresh_coin_values
        {
            return Err(anyhow!(
                "canonical fresh-coin extraction mismatch for {} seed {}",
                name,
                seed
            ));
        }
        update_uniform(&mut gas_seen, &mut gas_uniform, witness.trace().gas_used);
        update_uniform(
            &mut boundary_seen,
            &mut boundary_uniform,
            witness.boundary_schedule().len(),
        );
        update_uniform(
            &mut controller_phase_seen,
            &mut controller_phase_uniform,
            witness.controller_shape().controller_phase_order.len(),
        );
        update_uniform(
            &mut oram_object_cfg_seen,
            &mut oram_object_config_uniform,
            serde_json::to_string(witness.oram_objects())?,
        );
        if seed > 0 {
            writer.write_all(b",")?;
        }
        serde_json::to_writer(&mut *writer, &witness)?;
    }

    writer.write_all(b"],")?;
    write_json_key(writer, "public_leaf_scaffold")?;
    serde_json::to_writer(&mut *writer, &context.public_leaf_scaffold)?;
    writer.write_all(b",")?;
    write_json_key(writer, "public_fresh_coin_scaffold")?;
    serde_json::to_writer(&mut *writer, &context.public_fresh_coin_scaffold)?;
    writer.write_all(b"}")?;

    Ok(MaterializedCanonicalFreshCoinFamily {
        access_counters_before: context.access_counters_before.clone(),
        seed_count: context.seed_count,
        gas_uniform,
        boundary_uniform,
        controller_phase_uniform,
        oram_object_config_uniform,
        public_leaf_scaffold_steps: context.public_leaf_scaffold.len(),
        public_fresh_coin_scaffold_steps: context.public_fresh_coin_scaffold.len(),
    })
}

fn sanitize_case_name(case_name: &str) -> String {
    case_name
        .chars()
        .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { '_' })
        .collect::<String>()
}

fn heavy_artifact_materialization_path(
    options: &ProbeRunOptions,
    scenario: &str,
    suffix: &str,
) -> Result<(PathBuf, bool)> {
    if let Some(dir) = options.heavy_artifact_dir() {
        fs::create_dir_all(&dir)?;
        Ok((
            dir.join(format!("{}.{}", sanitize_case_name(scenario), suffix)),
            true,
        ))
    } else {
        Ok((
            temporary_witness_path(&format!("{scenario}-{suffix}")),
            false,
        ))
    }
}

fn cleanup_materialized_file(path: &Path, preserve: bool) {
    if !preserve {
        let _ = fs::remove_file(path);
    }
}

fn persist_heavy_artifact_json<T: Serialize>(
    options: &ProbeRunOptions,
    scenario: &str,
    suffix: &str,
    value: &T,
) -> Result<Option<(String, u64)>> {
    if options.materialization_mode != ArtifactMaterializationMode::Heavy {
        return Ok(None);
    }
    let Some(dir) = options.heavy_artifact_dir() else {
        return Ok(None);
    };
    fs::create_dir_all(&dir)?;
    let path = dir.join(format!("{}.{}", sanitize_case_name(scenario), suffix));
    let file = fs::File::create(&path)?;
    let mut writer = BufWriter::new(file);
    serde_json::to_writer(&mut writer, value)?;
    writer.flush()?;
    let bytes = fs::metadata(&path)?.len();
    Ok(Some((display_output_bundle_path(options, &path), bytes)))
}

fn validate_fresh_coin_heavy_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    checker: &Path,
    options: &ProbeRunOptions,
    estimate: CanonicalFamilySizeEstimate,
) -> Result<JsonValue> {
    let context = prepare_canonical_fresh_coin_family(name, artifact, setup, target)?;
    let (artifact_path, preserve_path) =
        heavy_artifact_materialization_path(options, name, "canonical_fresh_coin_family.json")?;
    let file = fs::File::create(&artifact_path)?;
    let mut writer = BufWriter::new(file);
    let summary =
        materialize_canonical_fresh_coin_family_object(&mut writer, name, target, &context)?;
    writer.flush()?;
    let artifact_json_bytes = fs::metadata(&artifact_path)?.len();
    let output = Command::new(checker)
        .arg(&artifact_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !output.status.success() {
        return Err(anyhow!(
            "Lean heavy canonical fresh-coin family validation failed for {}: {} (artifact preserved at {})",
            name,
            String::from_utf8_lossy(&output.stderr).trim(),
            artifact_path.display()
        ));
    }
    cleanup_materialized_file(&artifact_path, preserve_path);

    Ok(json!({
        "scenario": name,
        "entrypoint": target.entrypoint,
        "validation_status": "accepted_heavy_artifact",
        "reason": format!(
            "estimated explicit canonical fresh-coin family exceeded compact budget {} but fit within heavy-artifact budget {}",
            options.compact_budget_bytes,
            options.heavy_budget_bytes
        ),
        "compact_budget_bytes": options.compact_budget_bytes,
        "heavy_budget_bytes": options.heavy_budget_bytes,
        "size_estimate": estimate,
        "setup_calls": setup.len(),
        "mode": "heavy_explicit_canonical_seed_space",
        "deploy_seed": 0,
        "seed_count": summary.seed_count,
        "distinct_canonical_seeds_found": summary.seed_count,
        "coverage_fraction": 1.0,
        "coverage_complete": true,
        "gas_uniform": summary.gas_uniform,
        "boundary_uniform": summary.boundary_uniform,
        "controller_phase_uniform": summary.controller_phase_uniform,
        "public_leaf_scaffold_uniform": true,
        "public_fresh_coin_scaffold_uniform": true,
        "oram_object_config_uniform": summary.oram_object_config_uniform,
        "public_leaf_scaffold_steps": summary.public_leaf_scaffold_steps,
        "public_fresh_coin_scaffold_steps": summary.public_fresh_coin_scaffold_steps,
        "canonical_fresh_coin_seed_space_size": Some(summary.seed_count),
        "canonical_fresh_coin_values_match_index": true,
        "witness_family_json_bytes": artifact_json_bytes,
        "heavy_artifact_path": preserve_path
            .then(|| display_output_bundle_path(options, &artifact_path)),
        "heavy_artifact_json_bytes": preserve_path.then_some(artifact_json_bytes),
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "lean_validated": true,
        "accepted": true,
    }))
}

fn validate_canonical_pathoram_pair_heavy_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
    checker: &Path,
    paper_instantiation_checker: &Path,
    options: &ProbeRunOptions,
    estimated_certificate_json_bytes: u64,
    lhs_estimate: CanonicalFamilySizeEstimate,
    rhs_estimate: CanonicalFamilySizeEstimate,
) -> Result<JsonValue> {
    let lhs_context = prepare_canonical_fresh_coin_family(name, artifact, setup, lhs)?;
    let rhs_context = prepare_canonical_fresh_coin_family(name, artifact, setup, rhs)?;
    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        &lhs_context.first_witness,
        &lhs_context.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        &rhs_context.first_witness,
        &rhs_context.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "canonical path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let public_view = imported_oram_public_view(&lhs_context.first_witness);
    let public_location = imported_path_oram_public_location(&lhs_context.first_witness);
    let storage_shape = imported_path_oram_storage_shape(&lhs_context.first_witness);
    let public_outcome = lhs_context.first_witness.public_outcome().clone();
    let boundary_schedule = lhs_context.first_witness.boundary_schedule().to_vec();
    let controller_shape = lhs_context.first_witness.controller_shape().clone();
    let normalized_micro_trace = lhs_context.first_witness.normalized_micro_trace().clone();
    let public_outcome_equal =
        lhs_context.first_witness.public_outcome() == rhs_context.first_witness.public_outcome();
    let boundary_schedule_equal = lhs_context.first_witness.boundary_schedule()
        == rhs_context.first_witness.boundary_schedule();
    let controller_shape_equal = lhs_context.first_witness.controller_shape()
        == rhs_context.first_witness.controller_shape();
    let normalized_micro_trace_equal = lhs_context.first_witness.normalized_micro_trace()
        == rhs_context.first_witness.normalized_micro_trace();

    let (artifact_path, preserve_path) = heavy_artifact_materialization_path(
        options,
        name,
        "canonical_pathoram_pair_certificate.json",
    )?;
    let file = fs::File::create(&artifact_path)?;
    let mut writer = BufWriter::new(file);
    writer.write_all(b"{")?;
    write_json_key(&mut writer, "cfg")?;
    serde_json::to_writer(&mut writer, &cfg)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "lhs_family")?;
    let lhs_summary =
        materialize_canonical_fresh_coin_family_object(&mut writer, name, lhs, &lhs_context)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "rhs_family")?;
    let rhs_summary =
        materialize_canonical_fresh_coin_family_object(&mut writer, name, rhs, &rhs_context)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "public_view")?;
    serde_json::to_writer(&mut writer, &public_view)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "public_location")?;
    serde_json::to_writer(&mut writer, &public_location)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "storage_shape")?;
    serde_json::to_writer(&mut writer, &storage_shape)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "public_outcome")?;
    serde_json::to_writer(&mut writer, &public_outcome)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "boundary_schedule")?;
    serde_json::to_writer(&mut writer, &boundary_schedule)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "controller_shape")?;
    serde_json::to_writer(&mut writer, &controller_shape)?;
    writer.write_all(b",")?;
    write_json_key(&mut writer, "normalized_micro_trace")?;
    serde_json::to_writer(&mut writer, &normalized_micro_trace)?;
    writer.write_all(b"}")?;
    writer.flush()?;
    let artifact_json_bytes = fs::metadata(&artifact_path)?.len();
    let output = Command::new(checker)
        .arg(&artifact_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !output.status.success() {
        return Err(anyhow!(
            "Lean heavy canonical path-ORAM pair validation failed for {}: {} (artifact preserved at {})",
            name,
            String::from_utf8_lossy(&output.stderr).trim(),
            artifact_path.display()
        ));
    }
    let paper_instantiation_output = Command::new(paper_instantiation_checker)
        .arg(&artifact_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !paper_instantiation_output.status.success() {
        return Err(anyhow!(
            "Lean heavy canonical path-ORAM paper instantiation failed for {}: {} (artifact preserved at {})",
            name,
            String::from_utf8_lossy(&paper_instantiation_output.stderr).trim(),
            artifact_path.display()
        ));
    }
    cleanup_materialized_file(&artifact_path, preserve_path);

    Ok(json!({
        "scenario": name,
        "entrypoint": lhs.entrypoint,
        "validation_status": "accepted_heavy_artifact",
        "reason": format!(
            "estimated explicit canonical pair certificate exceeded compact budget {} but fit within heavy-artifact budget {}",
            options.compact_budget_bytes,
            options.heavy_budget_bytes
        ),
        "compact_budget_bytes": options.compact_budget_bytes,
        "heavy_budget_bytes": options.heavy_budget_bytes,
        "estimated_certificate_json_bytes": estimated_certificate_json_bytes,
        "lhs_estimate": lhs_estimate,
        "rhs_estimate": rhs_estimate,
        "lhs_seed_count": lhs_summary.seed_count,
        "rhs_seed_count": rhs_summary.seed_count,
        "access_counters_equal": lhs_summary.access_counters_before == rhs_summary.access_counters_before,
        "public_outcome_equal": public_outcome_equal,
        "boundary_schedule_equal": boundary_schedule_equal,
        "controller_shape_equal": controller_shape_equal,
        "normalized_micro_trace_equal": normalized_micro_trace_equal,
        "certificate_json_bytes": artifact_json_bytes,
        "heavy_artifact_path": preserve_path
            .then(|| display_output_bundle_path(options, &artifact_path)),
        "heavy_artifact_json_bytes": preserve_path.then_some(artifact_json_bytes),
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "paper_instantiation_status": "validated",
        "paper_instantiation_stdout": String::from_utf8_lossy(&paper_instantiation_output.stdout).trim(),
        "accepted": true,
    }))
}

fn validate_pathoram_pair_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
    seed_count: usize,
    checker: &Path,
) -> Result<JsonValue> {
    let lhs_collected = collect_seeded_pathoram_family(
        artifact,
        setup,
        lhs.entrypoint,
        lhs.args.clone(),
        seed_count,
    )?;
    let rhs_collected = collect_seeded_pathoram_family(
        artifact,
        setup,
        rhs.entrypoint,
        rhs.args.clone(),
        seed_count,
    )?;

    let lhs_first = lhs_collected
        .family
        .witnesses()
        .first()
        .ok_or_else(|| anyhow!("left seeded family is empty for {}", name))?;
    let rhs_first = rhs_collected
        .family
        .witnesses()
        .first()
        .ok_or_else(|| anyhow!("right seeded family is empty for {}", name))?;

    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        lhs_first,
        &lhs_collected.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        rhs_first,
        &rhs_collected.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let certificate = ImportedSeededRuntimePathOramPairCertificate {
        cfg,
        lhs_family: lhs_collected.family.clone(),
        rhs_family: rhs_collected.family.clone(),
        public_view: imported_oram_public_view(lhs_first),
        public_location: imported_path_oram_public_location(lhs_first),
        storage_shape: imported_path_oram_storage_shape(lhs_first),
        public_outcome: lhs_first.public_outcome().clone(),
        boundary_schedule: lhs_first.boundary_schedule().to_vec(),
        controller_shape: lhs_first.controller_shape().clone(),
        normalized_micro_trace: lhs_first.normalized_micro_trace().clone(),
    };

    let (certificate_path, certificate_json_bytes) = write_temp_json(name, &certificate)?;
    let output = Command::new(checker)
        .arg(&certificate_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !output.status.success() {
        return Err(anyhow!(
            "Lean path-ORAM pair validation failed for {}: {} (certificate preserved at {})",
            name,
            String::from_utf8_lossy(&output.stderr).trim(),
            certificate_path.display()
        ));
    }
    let _ = fs::remove_file(&certificate_path);

    Ok(json!({
        "scenario": name,
        "entrypoint": lhs.entrypoint,
        "lhs_seed_count": lhs_collected.family.seed_count(),
        "rhs_seed_count": rhs_collected.family.seed_count(),
        "access_counters_equal": lhs_collected.access_counters_before == rhs_collected.access_counters_before,
        "public_outcome_equal": lhs_first.public_outcome() == rhs_first.public_outcome(),
        "boundary_schedule_equal": lhs_first.boundary_schedule() == rhs_first.boundary_schedule(),
        "controller_shape_equal": lhs_first.controller_shape() == rhs_first.controller_shape(),
        "normalized_micro_trace_equal":
            lhs_first.normalized_micro_trace() == rhs_first.normalized_micro_trace(),
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "certificate_json_bytes": certificate_json_bytes,
        "accepted": true,
    }))
}

fn validate_canonical_pathoram_pair_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
    checker: &Path,
    paper_instantiation_checker: &Path,
    theorem_input_checker: &Path,
    options: &ProbeRunOptions,
) -> Result<JsonValue> {
    let lhs_estimate = estimate_canonical_fresh_coin_family_size(
        name,
        artifact,
        setup,
        lhs,
        CANONICAL_SIZE_ESTIMATE_SAMPLE_SEEDS,
    )?;
    let rhs_estimate = estimate_canonical_fresh_coin_family_size(
        name,
        artifact,
        setup,
        rhs,
        CANONICAL_SIZE_ESTIMATE_SAMPLE_SEEDS,
    )?;
    let estimated_certificate_json_bytes = lhs_estimate
        .estimated_family_json_bytes
        .saturating_add(rhs_estimate.estimated_family_json_bytes)
        .saturating_add(1 << 20);
    if options.should_try_heavy_materialization(estimated_certificate_json_bytes) {
        return validate_canonical_pathoram_pair_heavy_case(
            name,
            artifact,
            setup,
            lhs,
            rhs,
            checker,
            paper_instantiation_checker,
            options,
            estimated_certificate_json_bytes,
            lhs_estimate,
            rhs_estimate,
        );
    }
    if estimated_certificate_json_bytes > options.compact_budget_bytes {
        return validate_canonical_pathoram_pair_theorem_input_case(
            name,
            artifact,
            setup,
            lhs,
            rhs,
            theorem_input_checker,
            options.compact_budget_bytes,
            estimated_certificate_json_bytes,
            lhs_estimate,
            rhs_estimate,
        );
    }

    let lhs_collected = collect_canonical_fresh_coin_family_case(name, artifact, setup, lhs)?;
    let rhs_collected = collect_canonical_fresh_coin_family_case(name, artifact, setup, rhs)?;

    let lhs_first = &lhs_collected.first_witness;
    let rhs_first = &rhs_collected.first_witness;
    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        lhs_first,
        &lhs_collected.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        rhs_first,
        &rhs_collected.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "canonical path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let certificate = ImportedCanonicalFreshCoinRuntimePathOramPairCertificate {
        cfg,
        lhs_family: lhs_collected.family.clone(),
        rhs_family: rhs_collected.family.clone(),
        public_view: imported_oram_public_view(lhs_first),
        public_location: imported_path_oram_public_location(lhs_first),
        storage_shape: imported_path_oram_storage_shape(lhs_first),
        public_outcome: lhs_first.public_outcome().clone(),
        boundary_schedule: lhs_first.boundary_schedule().to_vec(),
        controller_shape: lhs_first.controller_shape().clone(),
        normalized_micro_trace: lhs_first.normalized_micro_trace().clone(),
    };

    let (certificate_path, certificate_json_bytes) = write_temp_json(name, &certificate)?;
    let output = Command::new(checker)
        .arg(&certificate_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    if !output.status.success() {
        let _ = fs::remove_file(&certificate_path);
        return Err(anyhow!(
            "Lean canonical path-ORAM pair validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    let paper_instantiation_output = Command::new(paper_instantiation_checker)
        .arg(&certificate_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&certificate_path);
    if !paper_instantiation_output.status.success() {
        return Err(anyhow!(
            "Lean canonical path-ORAM paper instantiation failed for {}: {}",
            name,
            String::from_utf8_lossy(&paper_instantiation_output.stderr).trim()
        ));
    }
    let persisted_artifact = persist_heavy_artifact_json(
        options,
        name,
        "canonical_pathoram_pair_certificate.json",
        &certificate,
    )?;

    Ok(json!({
        "scenario": name,
        "entrypoint": lhs.entrypoint,
        "validation_status": "accepted",
        "lhs_seed_count": lhs_collected.family.seed_count(),
        "rhs_seed_count": rhs_collected.family.seed_count(),
        "access_counters_equal": lhs_collected.access_counters_before == rhs_collected.access_counters_before,
        "public_outcome_equal": lhs_first.public_outcome() == rhs_first.public_outcome(),
        "boundary_schedule_equal": lhs_first.boundary_schedule() == rhs_first.boundary_schedule(),
        "controller_shape_equal": lhs_first.controller_shape() == rhs_first.controller_shape(),
        "normalized_micro_trace_equal":
            lhs_first.normalized_micro_trace() == rhs_first.normalized_micro_trace(),
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "paper_instantiation_status": "validated",
        "paper_instantiation_stdout": String::from_utf8_lossy(&paper_instantiation_output.stdout).trim(),
        "certificate_json_bytes": certificate_json_bytes,
        "heavy_artifact_path": persisted_artifact.as_ref().map(|(path, _)| path.clone()),
        "heavy_artifact_json_bytes": persisted_artifact.as_ref().map(|(_, bytes)| *bytes),
        "accepted": true,
    }))
}

fn validate_canonical_pathoram_pair_theorem_input_case(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
    checker: &Path,
    budget_bytes: u64,
    estimated_certificate_json_bytes: u64,
    lhs_estimate: CanonicalFamilySizeEstimate,
    rhs_estimate: CanonicalFamilySizeEstimate,
) -> Result<JsonValue> {
    let lhs_collected =
        collect_canonical_fresh_coin_theorem_input_case(name, artifact, setup, lhs)?;
    let rhs_collected =
        collect_canonical_fresh_coin_theorem_input_case(name, artifact, setup, rhs)?;

    let lhs_witness = lhs_collected.input.representative_witness();
    let rhs_witness = rhs_collected.input.representative_witness();
    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        lhs_witness,
        &lhs_collected.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        rhs_witness,
        &rhs_collected.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "canonical path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let public_view = imported_oram_public_view(lhs_witness);
    let public_location = imported_path_oram_public_location(lhs_witness);
    let storage_shape = imported_path_oram_storage_shape(lhs_witness);
    let public_outcome = lhs_witness.public_outcome().clone();
    let boundary_schedule = lhs_witness.boundary_schedule().to_vec();
    let controller_shape = lhs_witness.controller_shape().clone();
    let normalized_micro_trace = lhs_witness.normalized_micro_trace().clone();
    let public_outcome_equal = lhs_witness.public_outcome() == rhs_witness.public_outcome();
    let boundary_schedule_equal =
        lhs_witness.boundary_schedule() == rhs_witness.boundary_schedule();
    let controller_shape_equal = lhs_witness.controller_shape() == rhs_witness.controller_shape();
    let normalized_micro_trace_equal =
        lhs_witness.normalized_micro_trace() == rhs_witness.normalized_micro_trace();

    let theorem_input = ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput {
        cfg,
        lhs_input: lhs_collected.input,
        rhs_input: rhs_collected.input,
        public_view,
        public_location,
        storage_shape,
        public_outcome,
        boundary_schedule,
        controller_shape,
        normalized_micro_trace,
    };

    let (theorem_input_path, theorem_input_json_bytes) = write_temp_json(name, &theorem_input)?;
    let output = Command::new(checker)
        .arg(&theorem_input_path)
        .arg("page_v1")
        .arg("exit_v1")
        .arg("shared_v1")
        .output()?;
    let _ = fs::remove_file(&theorem_input_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean canonical path-ORAM pair theorem-input validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    Ok(json!({
        "scenario": name,
        "entrypoint": lhs.entrypoint,
        "validation_status": "accepted_compact_theorem_input",
        "reason": format!(
            "estimated explicit canonical pair certificate exceeds safe budget {}; compact theorem input used instead",
            budget_bytes
        ),
        "budget_bytes": budget_bytes,
        "estimated_certificate_json_bytes": estimated_certificate_json_bytes,
        "lhs_estimate": lhs_estimate,
        "rhs_estimate": rhs_estimate,
        "lhs_seed_count": theorem_input.lhs_input.seed_count(),
        "rhs_seed_count": theorem_input.rhs_input.seed_count(),
        "lhs_representative_seed": theorem_input.lhs_input.representative_seed(),
        "rhs_representative_seed": theorem_input.rhs_input.representative_seed(),
        "public_outcome_equal": public_outcome_equal,
        "boundary_schedule_equal": boundary_schedule_equal,
        "controller_shape_equal": controller_shape_equal,
        "normalized_micro_trace_equal": normalized_micro_trace_equal,
        "theorem_input_json_bytes": theorem_input_json_bytes,
        "lean_stdout": String::from_utf8_lossy(&output.stdout).trim(),
        "paper_instantiation_status": "not_materialized",
        "lean_validated": true,
        "accepted": true,
    }))
}

fn build_seeded_pathoram_pair_certificate(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
    seed_count: usize,
) -> Result<ImportedSeededRuntimePathOramPairCertificate> {
    let lhs_collected = collect_seeded_pathoram_family(
        artifact,
        setup,
        lhs.entrypoint,
        lhs.args.clone(),
        seed_count,
    )?;
    let rhs_collected = collect_seeded_pathoram_family(
        artifact,
        setup,
        rhs.entrypoint,
        rhs.args.clone(),
        seed_count,
    )?;

    let lhs_first = lhs_collected
        .family
        .witnesses()
        .first()
        .ok_or_else(|| anyhow!("left seeded family is empty for {}", name))?;
    let rhs_first = rhs_collected
        .family
        .witnesses()
        .first()
        .ok_or_else(|| anyhow!("right seeded family is empty for {}", name))?;

    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        lhs_first,
        &lhs_collected.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        rhs_first,
        &rhs_collected.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let public_view = imported_oram_public_view(lhs_first);
    let public_location = imported_path_oram_public_location(lhs_first);
    let storage_shape = imported_path_oram_storage_shape(lhs_first);
    let public_outcome = lhs_first.public_outcome().clone();
    let boundary_schedule = lhs_first.boundary_schedule().to_vec();
    let controller_shape = lhs_first.controller_shape().clone();
    let normalized_micro_trace = lhs_first.normalized_micro_trace().clone();

    Ok(ImportedSeededRuntimePathOramPairCertificate {
        cfg,
        lhs_family: lhs_collected.family,
        rhs_family: rhs_collected.family,
        public_view,
        public_location,
        storage_shape,
        public_outcome,
        boundary_schedule,
        controller_shape,
        normalized_micro_trace,
    })
}

fn build_canonical_pathoram_pair_certificate(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
) -> Result<ImportedCanonicalFreshCoinRuntimePathOramPairCertificate> {
    let lhs_collected = collect_canonical_fresh_coin_family_case(name, artifact, setup, lhs)?;
    let rhs_collected = collect_canonical_fresh_coin_family_case(name, artifact, setup, rhs)?;

    let lhs_first = &lhs_collected.first_witness;
    let rhs_first = &rhs_collected.first_witness;
    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        lhs_first,
        &lhs_collected.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        rhs_first,
        &rhs_collected.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "canonical path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let public_view = imported_oram_public_view(lhs_first);
    let public_location = imported_path_oram_public_location(lhs_first);
    let storage_shape = imported_path_oram_storage_shape(lhs_first);
    let public_outcome = lhs_first.public_outcome().clone();
    let boundary_schedule = lhs_first.boundary_schedule().to_vec();
    let controller_shape = lhs_first.controller_shape().clone();
    let normalized_micro_trace = lhs_first.normalized_micro_trace().clone();

    Ok(ImportedCanonicalFreshCoinRuntimePathOramPairCertificate {
        cfg,
        lhs_family: lhs_collected.family,
        rhs_family: rhs_collected.family,
        public_view,
        public_location,
        storage_shape,
        public_outcome,
        boundary_schedule,
        controller_shape,
        normalized_micro_trace,
    })
}

fn build_canonical_pathoram_pair_theorem_input(
    name: &'static str,
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    lhs: &CallSpec,
    rhs: &CallSpec,
) -> Result<ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput> {
    let lhs_collected =
        collect_canonical_fresh_coin_theorem_input_case(name, artifact, setup, lhs)?;
    let rhs_collected =
        collect_canonical_fresh_coin_theorem_input_case(name, artifact, setup, rhs)?;

    let lhs_witness = lhs_collected.input.representative_witness();
    let rhs_witness = rhs_collected.input.representative_witness();
    let cfg = imported_oram_config(
        artifact,
        lhs.entrypoint,
        lhs_witness,
        &lhs_collected.access_counters_before,
    )?;
    let rhs_cfg = imported_oram_config(
        artifact,
        rhs.entrypoint,
        rhs_witness,
        &rhs_collected.access_counters_before,
    )?;
    if serde_json::to_string(&cfg)? != serde_json::to_string(&rhs_cfg)? {
        return Err(anyhow!(
            "canonical path-ORAM pair {} does not share a common public configuration",
            name
        ));
    }

    let public_view = imported_oram_public_view(lhs_witness);
    let public_location = imported_path_oram_public_location(lhs_witness);
    let storage_shape = imported_path_oram_storage_shape(lhs_witness);
    let public_outcome = lhs_witness.public_outcome().clone();
    let boundary_schedule = lhs_witness.boundary_schedule().to_vec();
    let controller_shape = lhs_witness.controller_shape().clone();
    let normalized_micro_trace = lhs_witness.normalized_micro_trace().clone();

    Ok(ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput {
        cfg,
        lhs_input: lhs_collected.input,
        rhs_input: rhs_collected.input,
        public_view,
        public_location,
        storage_shape,
        public_outcome,
        boundary_schedule,
        controller_shape,
        normalized_micro_trace,
    })
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .expect("workspace root should exist")
}

fn extract_rust_enum_variants(source: &str, enum_name: &str) -> Result<Vec<String>> {
    let marker = format!("pub enum {enum_name} {{");
    let start = source
        .find(&marker)
        .ok_or_else(|| anyhow!("Rust enum `{enum_name}` not found"))?
        + marker.len();
    let mut brace_depth = 1usize;
    let mut paren_depth = 0usize;
    let mut bracket_depth = 0usize;
    let mut current_variant = String::new();
    let mut variants = Vec::new();
    for ch in source[start..].chars() {
        match ch {
            '{' => {
                brace_depth += 1;
                current_variant.push(ch);
            }
            '}' => {
                brace_depth = brace_depth
                    .checked_sub(1)
                    .ok_or_else(|| anyhow!("Rust enum `{enum_name}` has unbalanced braces"))?;
                if brace_depth == 0 {
                    let trimmed = current_variant.trim();
                    if !trimmed.is_empty() {
                        variants.push(trimmed.to_string());
                    }
                    break;
                }
                current_variant.push(ch);
            }
            '(' => {
                paren_depth += 1;
                current_variant.push(ch);
            }
            ')' => {
                paren_depth = paren_depth
                    .checked_sub(1)
                    .ok_or_else(|| anyhow!("Rust enum `{enum_name}` has unbalanced parentheses"))?;
                current_variant.push(ch);
            }
            '[' => {
                bracket_depth += 1;
                current_variant.push(ch);
            }
            ']' => {
                bracket_depth = bracket_depth
                    .checked_sub(1)
                    .ok_or_else(|| anyhow!("Rust enum `{enum_name}` has unbalanced brackets"))?;
                current_variant.push(ch);
            }
            ',' if brace_depth == 1 && paren_depth == 0 && bracket_depth == 0 => {
                let trimmed = current_variant.trim();
                if !trimmed.is_empty() {
                    variants.push(trimmed.to_string());
                }
                current_variant.clear();
            }
            _ => current_variant.push(ch),
        }
    }
    let variants = variants
        .into_iter()
        .filter_map(|variant| {
            let trimmed = variant.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("//") {
                None
            } else {
                trimmed
                    .split(|ch: char| ch.is_whitespace() || ch == '{' || ch == '(')
                    .next()
                    .map(str::to_string)
            }
        })
        .collect::<Vec<_>>();
    if variants.is_empty() {
        Err(anyhow!("Rust enum `{enum_name}` has no parsed variants"))
    } else {
        Ok(variants)
    }
}

fn extract_rust_struct_fields(source: &str, struct_name: &str) -> Result<Vec<String>> {
    let marker = format!("pub struct {struct_name} {{");
    let start = source
        .find(&marker)
        .ok_or_else(|| anyhow!("Rust struct `{struct_name}` not found"))?
        + marker.len();
    let remainder = &source[start..];
    let end = remainder
        .find('}')
        .ok_or_else(|| anyhow!("Rust struct `{struct_name}` missing closing brace"))?;
    let body = &remainder[..end];
    let fields = body
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("//") {
                None
            } else {
                trimmed
                    .strip_prefix("pub ")
                    .and_then(|field| field.split(':').next())
                    .map(str::trim)
                    .map(str::to_string)
            }
        })
        .collect::<Vec<_>>();
    if fields.is_empty() {
        Err(anyhow!("Rust struct `{struct_name}` has no parsed fields"))
    } else {
        Ok(fields)
    }
}

fn rust_enum_has_serde_snake_case(source: &str, enum_name: &str) -> bool {
    let marker = format!("pub enum {enum_name} {{");
    source.find(&marker).is_some_and(|start| {
        source[start.saturating_sub(256)..start].contains("rename_all = \"snake_case\"")
    })
}

fn extract_lean_string_list(source: &str, def_name: &str) -> Result<Vec<String>> {
    let marker = format!("def {def_name} : List String :=");
    let start = source
        .find(&marker)
        .ok_or_else(|| anyhow!("Lean string list `{def_name}` not found"))?
        + marker.len();
    let remainder = &source[start..];
    let end = remainder
        .find(']')
        .ok_or_else(|| anyhow!("Lean string list `{def_name}` missing closing bracket"))?;
    let body = &remainder[..=end];
    let mut strings = Vec::new();
    let mut current = String::new();
    let mut in_string = false;
    let mut escape = false;
    for ch in body.chars() {
        if in_string {
            if escape {
                current.push(ch);
                escape = false;
            } else if ch == '\\' {
                escape = true;
            } else if ch == '"' {
                strings.push(current.clone());
                current.clear();
                in_string = false;
            } else {
                current.push(ch);
            }
        } else if ch == '"' {
            in_string = true;
        }
    }
    if strings.is_empty() {
        Err(anyhow!(
            "Lean string list `{def_name}` has no parsed entries"
        ))
    } else {
        Ok(strings)
    }
}

fn to_snake_case(name: &str) -> String {
    let mut out = String::new();
    for (idx, ch) in name.chars().enumerate() {
        if ch.is_ascii_uppercase() {
            if idx != 0 {
                out.push('_');
            }
            out.push(ch.to_ascii_lowercase());
        } else {
            out.push(ch);
        }
    }
    out
}

fn collect_rust_source_files(root: &Path, files: &mut Vec<PathBuf>) -> Result<()> {
    for entry in fs::read_dir(root).with_context(|| format!("reading {}", root.display()))? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            collect_rust_source_files(&path, files)?;
        } else if path.extension().is_some_and(|ext| ext == "rs") {
            files.push(path);
        }
    }
    Ok(())
}

fn collect_lean_source_files(root: &Path, files: &mut Vec<PathBuf>) -> Result<()> {
    for entry in fs::read_dir(root).with_context(|| format!("reading {}", root.display()))? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            collect_lean_source_files(&path, files)?;
        } else if path.extension().is_some_and(|ext| ext == "lean") {
            files.push(path);
        }
    }
    Ok(())
}

fn production_source_slice(source: &str) -> String {
    const CFG_TEST_ATTR: &str = "#[cfg(test)]";

    let bytes = source.as_bytes();
    let mut out = String::with_capacity(source.len());
    let mut cursor = 0;

    while let Some(relative) = source[cursor..].find(CFG_TEST_ATTR) {
        let start = cursor + relative;
        out.push_str(&source[cursor..start]);

        let mut i = start + CFG_TEST_ATTR.len();
        while i < bytes.len() && bytes[i].is_ascii_whitespace() {
            i += 1;
        }

        while i + 1 < bytes.len() && bytes[i] == b'#' && bytes[i + 1] == b'[' {
            i += 2;
            while i < bytes.len() && bytes[i] != b']' {
                i += 1;
            }
            if i < bytes.len() {
                i += 1;
            }
            while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                i += 1;
            }
        }

        let mut item_start = i;
        while item_start < bytes.len() && bytes[item_start].is_ascii_whitespace() {
            item_start += 1;
        }

        let mut item_end = item_start;
        while item_end < bytes.len() && bytes[item_end] != b'{' && bytes[item_end] != b';' {
            item_end += 1;
        }
        if item_end == bytes.len() {
            cursor = item_end;
            break;
        }
        if bytes[item_end] == b';' {
            cursor = item_end + 1;
            continue;
        }

        let mut depth = 1usize;
        item_end += 1;
        while item_end < bytes.len() && depth > 0 {
            match bytes[item_end] {
                b'{' => depth += 1,
                b'}' => depth -= 1,
                _ => {}
            }
            item_end += 1;
        }
        cursor = item_end;
    }

    out.push_str(&source[cursor..]);
    out
}

fn collect_production_pattern_hits(root: &Path, pattern: &str) -> Result<Vec<String>> {
    let mut files = Vec::new();
    collect_rust_source_files(root, &mut files)?;
    let mut hits = Vec::new();
    for path in files {
        let source =
            fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        if production_source_slice(&source).contains(pattern) {
            hits.push(display_report_path(&path));
        }
    }
    hits.sort();
    Ok(hits)
}

fn collect_lean_pattern_hits(root: &Path, pattern: &str) -> Result<Vec<String>> {
    let mut files = Vec::new();
    collect_lean_source_files(root, &mut files)?;
    let mut hits = Vec::new();
    for path in files {
        let source =
            fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        if source.contains(pattern) {
            hits.push(display_report_path(&path));
        }
    }
    hits.sort();
    Ok(hits)
}

fn run_kernel_model_alignment_validation() -> Result<JsonValue> {
    let core_src = repo_root().join("crates/uo-core/src");
    let runtime_evm_src = repo_root().join("runtime/uo-evm/src");
    let precompiles_path = repo_root().join("runtime/uo-precompiles/src/lib.rs");
    let core_trace_path = repo_root().join("crates/uo-core/src/trace.rs");
    let confidential_kernel_path = repo_root().join("crates/uo-core/src/confidential_kernel.rs");
    let kernel_dsl_path = repo_root().join("crates/uo-core/src/kernel_dsl.rs");
    let confidential_core_path = repo_root().join("crates/uo-core/src/confidential_core.rs");
    let trusted_kernel_path = repo_root().join("crates/uo-core/src/trusted_kernel.rs");
    let shell_boundary_path = repo_root().join("crates/uo-core/src/shell_boundary.rs");
    let lean_runtime_refinement_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeRefinement.lean");
    let lean_runtime_refinement_json_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeRefinementJson.lean");
    let lean_runtime_trusted_kernel_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean");
    let lean_runtime_shell_boundary_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeShellBoundaryJson.lean");
    let lean_runtime_shell_boundary_slot_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeShellBoundarySlotJson.lean");
    let lean_runtime_shell_boundary_lowering_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeShellBoundaryLoweringJson.lean");
    let lean_runtime_kernel_dsl_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeKernelDslJson.lean");
    let lean_runtime_confidential_core_path =
        repo_root().join("proof/lean/UOToolchain/RuntimeConfidentialCoreAssuranceJson.lean");
    let lean_runtime_confidential_core_shell_boundary_slot_path = repo_root()
        .join("proof/lean/UOToolchain/RuntimeConfidentialCoreShellBoundarySlotJson.lean");
    let lean_runtime_confidential_core_shell_boundary_lowering_path = repo_root()
        .join("proof/lean/UOToolchain/RuntimeConfidentialCoreShellBoundaryLoweringJson.lean");

    let precompiles_source = fs::read_to_string(&precompiles_path)
        .with_context(|| format!("reading {}", display_report_path(&precompiles_path)))?;
    let core_trace_source = fs::read_to_string(&core_trace_path)
        .with_context(|| format!("reading {}", display_report_path(&core_trace_path)))?;
    let confidential_kernel_source = fs::read_to_string(&confidential_kernel_path)
        .with_context(|| format!("reading {}", display_report_path(&confidential_kernel_path)))?;
    let kernel_dsl_source = fs::read_to_string(&kernel_dsl_path)
        .with_context(|| format!("reading {}", display_report_path(&kernel_dsl_path)))?;
    let confidential_core_source = fs::read_to_string(&confidential_core_path)
        .with_context(|| format!("reading {}", display_report_path(&confidential_core_path)))?;
    let trusted_kernel_source = fs::read_to_string(&trusted_kernel_path)
        .with_context(|| format!("reading {}", display_report_path(&trusted_kernel_path)))?;
    let shell_boundary_source = fs::read_to_string(&shell_boundary_path)
        .with_context(|| format!("reading {}", display_report_path(&shell_boundary_path)))?;
    let lean_runtime_refinement_source = fs::read_to_string(&lean_runtime_refinement_path)
        .with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_refinement_path)
            )
        })?;
    let lean_runtime_refinement_json_source =
        fs::read_to_string(&lean_runtime_refinement_json_path).with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_refinement_json_path)
            )
        })?;
    let lean_runtime_trusted_kernel_source = fs::read_to_string(&lean_runtime_trusted_kernel_path)
        .with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_trusted_kernel_path)
            )
        })?;
    let lean_runtime_shell_boundary_source = fs::read_to_string(&lean_runtime_shell_boundary_path)
        .with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_shell_boundary_path)
            )
        })?;
    let lean_runtime_shell_boundary_slot_source =
        fs::read_to_string(&lean_runtime_shell_boundary_slot_path).with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_shell_boundary_slot_path)
            )
        })?;
    let lean_runtime_shell_boundary_lowering_source =
        fs::read_to_string(&lean_runtime_shell_boundary_lowering_path).with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_shell_boundary_lowering_path)
            )
        })?;
    let lean_runtime_kernel_dsl_source = fs::read_to_string(&lean_runtime_kernel_dsl_path)
        .with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_kernel_dsl_path)
            )
        })?;
    let lean_runtime_confidential_core_source =
        fs::read_to_string(&lean_runtime_confidential_core_path).with_context(|| {
            format!(
                "reading {}",
                display_report_path(&lean_runtime_confidential_core_path)
            )
        })?;
    let lean_runtime_confidential_core_shell_boundary_slot_source = fs::read_to_string(
        &lean_runtime_confidential_core_shell_boundary_slot_path,
    )
    .with_context(|| {
        format!(
            "reading {}",
            display_report_path(&lean_runtime_confidential_core_shell_boundary_slot_path)
        )
    })?;
    let lean_runtime_confidential_core_shell_boundary_lowering_source =
        fs::read_to_string(&lean_runtime_confidential_core_shell_boundary_lowering_path)
            .with_context(|| {
                format!(
                    "reading {}",
                    display_report_path(
                        &lean_runtime_confidential_core_shell_boundary_lowering_path
                    )
                )
            })?;

    let rust_opcode_names = extract_rust_enum_variants(&precompiles_source, "UoOpcode")?;
    let lean_opcode_names =
        extract_lean_string_list(&lean_runtime_refinement_source, "runtimeKernelOpcodeNames")?;
    let opcode_names_match = rust_opcode_names == lean_opcode_names;

    let rust_resource_event_kind_variants =
        extract_rust_enum_variants(&core_trace_source, "RuntimeKernelResourceEventKindWitness")?;
    let rust_resource_event_kind_names = rust_resource_event_kind_variants
        .iter()
        .map(|name| to_snake_case(name))
        .collect::<Vec<_>>();
    let lean_resource_event_kind_names = extract_lean_string_list(
        &lean_runtime_refinement_source,
        "runtimeKernelResourceEventKindNames",
    )?;
    let resource_event_kind_names_match =
        rust_resource_event_kind_names == lean_resource_event_kind_names;

    let rust_scratch_region_variants =
        extract_rust_enum_variants(&core_trace_source, "RuntimeKernelScratchRegionWitness")?;
    let rust_scratch_region_names = rust_scratch_region_variants
        .iter()
        .map(|name| to_snake_case(name))
        .collect::<Vec<_>>();
    let lean_scratch_region_names = extract_lean_string_list(
        &lean_runtime_refinement_source,
        "runtimeKernelScratchRegionNames",
    )?;
    let scratch_region_names_match = rust_scratch_region_names == lean_scratch_region_names;

    let rust_refinement_event_kind_variants = extract_rust_enum_variants(
        &core_trace_source,
        "RuntimeKernelRefinementEventKindWitness",
    )?;
    let rust_refinement_event_kind_names = rust_refinement_event_kind_variants
        .iter()
        .map(|name| to_snake_case(name))
        .collect::<Vec<_>>();
    let lean_refinement_event_kind_names = extract_lean_string_list(
        &lean_runtime_refinement_source,
        "runtimeKernelRefinementEventKindNames",
    )?;
    let refinement_event_kind_names_match =
        rust_refinement_event_kind_names == lean_refinement_event_kind_names;

    let rust_confidential_kernel_statement_kind_names =
        extract_rust_enum_variants(&confidential_kernel_source, "ConfidentialKernelStatement")?
            .iter()
            .map(|name| to_snake_case(name))
            .collect::<Vec<_>>();
    let lean_confidential_kernel_statement_kind_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelStatementKindNames",
    )?;
    let confidential_kernel_statement_kind_names_match =
        rust_confidential_kernel_statement_kind_names
            == lean_confidential_kernel_statement_kind_names;

    let rust_confidential_kernel_expr_kind_names =
        extract_rust_enum_variants(&confidential_kernel_source, "ConfidentialKernelExpr")?
            .iter()
            .map(|name| to_snake_case(name))
            .collect::<Vec<_>>();
    let lean_confidential_kernel_expr_kind_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelExprKindNames",
    )?;
    let confidential_kernel_expr_kind_names_match =
        rust_confidential_kernel_expr_kind_names == lean_confidential_kernel_expr_kind_names;

    let rust_confidential_kernel_pure_expr_kind_names =
        extract_rust_enum_variants(&confidential_kernel_source, "ConfidentialKernelPureExpr")?
            .iter()
            .map(|name| to_snake_case(name))
            .collect::<Vec<_>>();
    let lean_confidential_kernel_pure_expr_kind_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelPureExprKindNames",
    )?;
    let confidential_kernel_pure_expr_kind_names_match =
        rust_confidential_kernel_pure_expr_kind_names
            == lean_confidential_kernel_pure_expr_kind_names;

    let rust_confidential_kernel_slot_statement_kind_names = extract_rust_enum_variants(
        &confidential_kernel_source,
        "ConfidentialKernelSlotStatement",
    )?
    .iter()
    .map(|name| to_snake_case(name))
    .collect::<Vec<_>>();
    let lean_confidential_kernel_slot_statement_kind_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelSlotStatementKindNames",
    )?;
    let confidential_kernel_slot_statement_kind_names_match =
        rust_confidential_kernel_slot_statement_kind_names
            == lean_confidential_kernel_slot_statement_kind_names;

    let rust_confidential_kernel_slot_expr_kind_names =
        extract_rust_enum_variants(&confidential_kernel_source, "ConfidentialKernelSlotExpr")?
            .iter()
            .map(|name| to_snake_case(name))
            .collect::<Vec<_>>();
    let lean_confidential_kernel_slot_expr_kind_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelSlotExprKindNames",
    )?;
    let confidential_kernel_slot_expr_kind_names_match =
        rust_confidential_kernel_slot_expr_kind_names
            == lean_confidential_kernel_slot_expr_kind_names;

    let rust_confidential_kernel_slot_pure_expr_kind_names = extract_rust_enum_variants(
        &confidential_kernel_source,
        "ConfidentialKernelSlotPureExpr",
    )?
    .iter()
    .map(|name| to_snake_case(name))
    .collect::<Vec<_>>();
    let lean_confidential_kernel_slot_pure_expr_kind_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelSlotPureExprKindNames",
    )?;
    let confidential_kernel_slot_pure_expr_kind_names_match =
        rust_confidential_kernel_slot_pure_expr_kind_names
            == lean_confidential_kernel_slot_pure_expr_kind_names;

    let rust_confidential_kernel_param_field_names =
        extract_rust_struct_fields(&confidential_kernel_source, "ConfidentialKernelParam")?;
    let lean_confidential_kernel_param_field_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelParamFieldNames",
    )?;
    let confidential_kernel_param_field_names_match =
        rust_confidential_kernel_param_field_names == lean_confidential_kernel_param_field_names;

    let rust_confidential_kernel_program_field_names =
        extract_rust_struct_fields(&confidential_kernel_source, "ConfidentialKernelProgram")?;
    let lean_confidential_kernel_program_field_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelProgramFieldNames",
    )?;
    let confidential_kernel_program_field_names_match = rust_confidential_kernel_program_field_names
        == lean_confidential_kernel_program_field_names;

    let rust_confidential_kernel_slot_program_field_names =
        extract_rust_struct_fields(&confidential_kernel_source, "ConfidentialKernelSlotProgram")?;
    let lean_confidential_kernel_slot_program_field_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedConfidentialKernelSlotProgramFieldNames",
    )?;
    let confidential_kernel_slot_program_field_names_match =
        rust_confidential_kernel_slot_program_field_names
            == lean_confidential_kernel_slot_program_field_names;

    let rust_runtime_kernel_lowering_bundle_field_names =
        extract_rust_struct_fields(&kernel_dsl_source, "RuntimeKernelLoweringBundle")?;
    let lean_runtime_kernel_lowering_bundle_field_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedRuntimeKernelLoweringBundleFieldNames",
    )?;
    let runtime_kernel_lowering_bundle_field_names_match =
        rust_runtime_kernel_lowering_bundle_field_names
            == lean_runtime_kernel_lowering_bundle_field_names;
    let rust_runtime_kernel_slot_dsl_bundle_field_names =
        extract_rust_struct_fields(&kernel_dsl_source, "RuntimeKernelSlotDslBundle")?;
    let lean_runtime_kernel_slot_dsl_bundle_field_names = extract_lean_string_list(
        &lean_runtime_kernel_dsl_source,
        "importedRuntimeKernelSlotDslBundleFieldNames",
    )?;
    let runtime_kernel_slot_dsl_bundle_field_names_match =
        rust_runtime_kernel_slot_dsl_bundle_field_names
            == lean_runtime_kernel_slot_dsl_bundle_field_names;

    let rust_runtime_confidential_core_lowering_bundle_field_names = extract_rust_struct_fields(
        &confidential_core_source,
        "RuntimeConfidentialCoreLoweringBundle",
    )?;
    let lean_runtime_confidential_core_lowering_bundle_field_names = extract_lean_string_list(
        &lean_runtime_confidential_core_source,
        "importedRuntimeConfidentialCoreLoweringBundleFieldNames",
    )?;
    let runtime_confidential_core_lowering_bundle_field_names_match =
        rust_runtime_confidential_core_lowering_bundle_field_names
            == lean_runtime_confidential_core_lowering_bundle_field_names;
    let rust_runtime_confidential_core_slot_bundle_field_names = extract_rust_struct_fields(
        &confidential_core_source,
        "RuntimeConfidentialCoreSlotBundle",
    )?;
    let lean_runtime_confidential_core_slot_bundle_field_names = extract_lean_string_list(
        &lean_runtime_confidential_core_source,
        "importedRuntimeConfidentialCoreSlotBundleFieldNames",
    )?;
    let runtime_confidential_core_slot_bundle_field_names_match =
        rust_runtime_confidential_core_slot_bundle_field_names
            == lean_runtime_confidential_core_slot_bundle_field_names;
    let rust_runtime_confidential_core_shell_boundary_slot_bundle_field_names =
        extract_rust_struct_fields(
            &confidential_core_source,
            "RuntimeConfidentialCoreShellBoundarySlotBundle",
        )?;
    let lean_runtime_confidential_core_shell_boundary_slot_bundle_field_names =
        extract_lean_string_list(
            &lean_runtime_confidential_core_shell_boundary_slot_source,
            "importedRuntimeConfidentialCoreShellBoundarySlotBundleFieldNames",
        )?;
    let runtime_confidential_core_shell_boundary_slot_bundle_field_names_match =
        rust_runtime_confidential_core_shell_boundary_slot_bundle_field_names
            == lean_runtime_confidential_core_shell_boundary_slot_bundle_field_names;

    let rust_runtime_confidential_core_shell_boundary_lowering_bundle_field_names =
        extract_rust_struct_fields(
            &confidential_core_source,
            "RuntimeConfidentialCoreShellBoundaryLoweringBundle",
        )?;
    let lean_runtime_confidential_core_shell_boundary_lowering_bundle_field_names =
        extract_lean_string_list(
            &lean_runtime_confidential_core_shell_boundary_lowering_source,
            "importedRuntimeConfidentialCoreShellBoundaryLoweringBundleFieldNames",
        )?;
    let runtime_confidential_core_shell_boundary_lowering_bundle_field_names_match =
        rust_runtime_confidential_core_shell_boundary_lowering_bundle_field_names
            == lean_runtime_confidential_core_shell_boundary_lowering_bundle_field_names;
    let rust_runtime_trusted_kernel_slot_bundle_field_names =
        extract_rust_struct_fields(&trusted_kernel_source, "RuntimeTrustedKernelSlotBundle")?;
    let lean_runtime_trusted_kernel_slot_bundle_field_names = extract_lean_string_list(
        &lean_runtime_trusted_kernel_source,
        "importedRuntimeTrustedKernelSlotBundleFieldNames",
    )?;
    let runtime_trusted_kernel_slot_bundle_field_names_match =
        rust_runtime_trusted_kernel_slot_bundle_field_names
            == lean_runtime_trusted_kernel_slot_bundle_field_names;

    let rust_runtime_shell_contract_field_names =
        extract_rust_struct_fields(&shell_boundary_source, "RuntimeShellContract")?;
    let lean_runtime_shell_contract_field_names = extract_lean_string_list(
        &lean_runtime_shell_boundary_source,
        "importedRuntimeShellContractFieldNames",
    )?;
    let runtime_shell_contract_field_names_match =
        rust_runtime_shell_contract_field_names == lean_runtime_shell_contract_field_names;

    let rust_runtime_shell_trace_field_names =
        extract_rust_struct_fields(&shell_boundary_source, "RuntimeShellTrace")?;
    let lean_runtime_shell_trace_field_names = extract_lean_string_list(
        &lean_runtime_shell_boundary_source,
        "importedRuntimeShellTraceFieldNames",
    )?;
    let runtime_shell_trace_field_names_match =
        rust_runtime_shell_trace_field_names == lean_runtime_shell_trace_field_names;

    let rust_runtime_shell_boundary_bundle_field_names =
        extract_rust_struct_fields(&shell_boundary_source, "RuntimeShellBoundaryBundle")?;
    let lean_runtime_shell_boundary_bundle_field_names = extract_lean_string_list(
        &lean_runtime_shell_boundary_source,
        "importedRuntimeShellBoundaryBundleFieldNames",
    )?;
    let runtime_shell_boundary_bundle_field_names_match =
        rust_runtime_shell_boundary_bundle_field_names
            == lean_runtime_shell_boundary_bundle_field_names;
    let rust_runtime_shell_boundary_slot_bundle_field_names =
        extract_rust_struct_fields(&kernel_dsl_source, "RuntimeShellBoundarySlotBundle")?;
    let lean_runtime_shell_boundary_slot_bundle_field_names = extract_lean_string_list(
        &lean_runtime_shell_boundary_slot_source,
        "importedRuntimeShellBoundarySlotBundleFieldNames",
    )?;
    let runtime_shell_boundary_slot_bundle_field_names_match =
        rust_runtime_shell_boundary_slot_bundle_field_names
            == lean_runtime_shell_boundary_slot_bundle_field_names;

    let rust_runtime_shell_boundary_lowering_bundle_field_names =
        extract_rust_struct_fields(&kernel_dsl_source, "RuntimeShellBoundaryLoweringBundle")?;
    let lean_runtime_shell_boundary_lowering_bundle_field_names = extract_lean_string_list(
        &lean_runtime_shell_boundary_lowering_source,
        "importedRuntimeShellBoundaryLoweringBundleFieldNames",
    )?;
    let runtime_shell_boundary_lowering_bundle_field_names_match =
        rust_runtime_shell_boundary_lowering_bundle_field_names
            == lean_runtime_shell_boundary_lowering_bundle_field_names;
    let shell_boundary_exact_bridge_checks = [
        (
            "pub fn shell_contract(&self) -> RuntimeShellContract {",
            vec![String::from("crates/uo-core/src/shell_boundary.rs")],
        ),
        (
            "pub fn shell_trace(&self) -> RuntimeShellTrace {",
            vec![String::from("crates/uo-core/src/shell_boundary.rs")],
        ),
        (
            "let shell_contract = kernel_witness.shell_contract();",
            vec![String::from("crates/uo-core/src/shell_boundary.rs")],
        ),
        (
            "let shell_trace = runtime_kernel_refinement_witness.shell_trace();",
            vec![String::from("crates/uo-core/src/shell_boundary.rs")],
        ),
        (
            "pub fn runtime_shell_boundary_bundle(",
            vec![String::from("crates/uo-core/src/shell_boundary.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let shell_boundary_exact_bridge_surface_restricted =
        shell_boundary_exact_bridge_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("shell-boundary exact bridge restriction flag must be boolean")
        });
    let shell_boundary_bundle_refinement_guard_present =
        shell_boundary_source.contains("if !shell_trace.refines_contract(&shell_contract) {");
    let runtime_shell_trace_fields_private = shell_boundary_source
        .contains("pub struct RuntimeShellTrace {")
        && shell_boundary_source.contains("events: Vec<RuntimeKernelRefinementEventWitness>,")
        && shell_boundary_source
            .contains("projected_kernel_schedule: RuntimeKernelScheduleWitness,")
        && shell_boundary_source.contains("pre_committed_cold_object_schedule: Vec<u32>,")
        && shell_boundary_source.contains("shadow_load_object_schedule: Vec<u32>,")
        && shell_boundary_source.contains("commit_object_schedule: Vec<u32>,")
        && shell_boundary_source.contains("cold_store_object_schedule: Vec<u32>,")
        && shell_boundary_source.contains("post_committed_cold_object_schedule: Vec<u32>,")
        && !shell_boundary_source.contains("pub events: Vec<RuntimeKernelRefinementEventWitness>,")
        && !shell_boundary_source
            .contains("pub projected_kernel_schedule: RuntimeKernelScheduleWitness,")
        && !shell_boundary_source.contains("pub pre_committed_cold_object_schedule: Vec<u32>,")
        && !shell_boundary_source.contains("pub shadow_load_object_schedule: Vec<u32>,")
        && !shell_boundary_source.contains("pub commit_object_schedule: Vec<u32>,")
        && !shell_boundary_source.contains("pub cold_store_object_schedule: Vec<u32>,")
        && !shell_boundary_source.contains("pub post_committed_cold_object_schedule: Vec<u32>,");
    let runtime_shell_trace_api_is_explicit = shell_boundary_source
        .contains("pub fn from_components(")
        && shell_boundary_source
            .contains("pub fn events(&self) -> &[RuntimeKernelRefinementEventWitness] {")
        && shell_boundary_source.contains("pub fn event_count(&self) -> usize {")
        && shell_boundary_source
            .contains("pub fn projected_kernel_schedule(&self) -> &RuntimeKernelScheduleWitness {")
        && shell_boundary_source
            .contains("pub fn pre_committed_cold_object_schedule(&self) -> &[u32] {")
        && shell_boundary_source.contains("pub fn shadow_load_object_schedule(&self) -> &[u32] {")
        && shell_boundary_source.contains("pub fn commit_object_schedule(&self) -> &[u32] {")
        && shell_boundary_source.contains("pub fn cold_store_object_schedule(&self) -> &[u32] {")
        && shell_boundary_source
            .contains("pub fn post_committed_cold_object_schedule(&self) -> &[u32] {");
    let runtime_shell_boundary_bundle_fields_private = shell_boundary_source
        .contains("pub struct RuntimeShellBoundaryBundle {")
        && shell_boundary_source.contains("kernel_witness: RuntimeKernelWitness,")
        && shell_boundary_source
            .contains("runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,")
        && shell_boundary_source.contains("shell_contract: RuntimeShellContract,")
        && shell_boundary_source.contains("shell_trace: RuntimeShellTrace,")
        && !shell_boundary_source.contains("pub kernel_witness: RuntimeKernelWitness,")
        && !shell_boundary_source
            .contains("pub runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness,")
        && !shell_boundary_source.contains("pub shell_contract: RuntimeShellContract,")
        && !shell_boundary_source.contains("pub shell_trace: RuntimeShellTrace,");
    let runtime_shell_boundary_bundle_api_is_explicit = shell_boundary_source
        .contains("pub fn kernel_witness(&self) -> &RuntimeKernelWitness {")
        && shell_boundary_source.contains(
            "pub fn runtime_kernel_refinement_witness(&self) -> &RuntimeKernelRefinementWitness {",
        )
        && shell_boundary_source
            .contains("pub fn shell_contract(&self) -> &RuntimeShellContract {")
        && shell_boundary_source.contains("pub fn shell_trace(&self) -> &RuntimeShellTrace {");
    let confidential_core_bundle_bridge_checks = [
        (
            "pub fn runtime_confidential_core_bundle(",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "pub fn runtime_confidential_core_slot_bundle(",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "pub fn runtime_confidential_core_lowering_bundle(",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "pub fn runtime_confidential_core_shell_boundary_lowering_bundle(",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "pub fn runtime_confidential_core_shell_boundary_slot_bundle(",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let confidential_core_bundle_bridge_surface_restricted =
        confidential_core_bundle_bridge_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("confidential-core bridge restriction flag must be boolean")
        });
    let runtime_confidential_core_bundle_fields_private = confidential_core_source
        .contains("pub struct RuntimeConfidentialCoreBundle {")
        && confidential_core_source.contains("runtime_witness: RuntimeRefinementWitness,")
        && confidential_core_source.contains("confidential_program: ConfidentialKernelProgram,")
        && !confidential_core_source.contains("pub runtime_witness: RuntimeRefinementWitness,")
        && !confidential_core_source
            .contains("pub confidential_program: ConfidentialKernelProgram,");
    let runtime_confidential_core_bundle_api_is_explicit = confidential_core_source
        .contains("pub fn runtime_witness(&self) -> &RuntimeRefinementWitness {")
        && confidential_core_source
            .contains("pub fn confidential_program(&self) -> &ConfidentialKernelProgram {");
    let runtime_confidential_core_slot_bundle_fields_private = confidential_core_source
        .contains("pub struct RuntimeConfidentialCoreSlotBundle {")
        && confidential_core_source.contains("runtime_witness: RuntimeRefinementWitness,")
        && confidential_core_source
            .contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !confidential_core_source.contains("pub runtime_witness: RuntimeRefinementWitness,")
        && !confidential_core_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_confidential_core_slot_bundle_api_is_explicit = confidential_core_source
        .contains("pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {");
    let runtime_confidential_core_lowering_bundle_fields_private = confidential_core_source
        .contains("pub struct RuntimeConfidentialCoreLoweringBundle {")
        && confidential_core_source.contains("runtime_witness: RuntimeRefinementWitness,")
        && confidential_core_source.contains("confidential_program: ConfidentialKernelProgram,")
        && confidential_core_source
            .contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !confidential_core_source.contains("pub runtime_witness: RuntimeRefinementWitness,")
        && !confidential_core_source
            .contains("pub confidential_program: ConfidentialKernelProgram,")
        && !confidential_core_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_confidential_core_lowering_bundle_api_is_explicit = confidential_core_source
        .contains("pub fn confidential_program(&self) -> &ConfidentialKernelProgram {")
        && confidential_core_source.contains(
            "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
        );
    let runtime_confidential_core_shell_boundary_lowering_bundle_fields_private =
        confidential_core_source
            .contains("pub struct RuntimeConfidentialCoreShellBoundaryLoweringBundle {")
            && confidential_core_source.contains("runtime_witness: RuntimeRefinementWitness,")
            && confidential_core_source
                .contains("shell_boundary_bundle: RuntimeShellBoundaryBundle,")
            && confidential_core_source
                .contains("confidential_program: ConfidentialKernelProgram,")
            && confidential_core_source
                .contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
            && !confidential_core_source.contains("pub runtime_witness: RuntimeRefinementWitness,")
            && !confidential_core_source
                .contains("pub shell_boundary_bundle: RuntimeShellBoundaryBundle,")
            && !confidential_core_source
                .contains("pub confidential_program: ConfidentialKernelProgram,")
            && !confidential_core_source
                .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_confidential_core_shell_boundary_lowering_bundle_api_is_explicit =
        confidential_core_source
            .contains("pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {")
            && confidential_core_source
                .contains("pub fn confidential_program(&self) -> &ConfidentialKernelProgram {")
            && confidential_core_source.contains(
                "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
            );
    let runtime_confidential_core_shell_boundary_slot_bundle_fields_private =
        confidential_core_source
            .contains("pub struct RuntimeConfidentialCoreShellBoundarySlotBundle {")
            && confidential_core_source.contains("runtime_witness: RuntimeRefinementWitness,")
            && confidential_core_source
                .contains("shell_boundary_bundle: RuntimeShellBoundaryBundle,")
            && confidential_core_source
                .contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
            && !confidential_core_source.contains("pub runtime_witness: RuntimeRefinementWitness,")
            && !confidential_core_source
                .contains("pub shell_boundary_bundle: RuntimeShellBoundaryBundle,")
            && !confidential_core_source
                .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_confidential_core_shell_boundary_slot_bundle_api_is_explicit =
        confidential_core_source
            .contains("pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {")
            && confidential_core_source.contains(
                "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
            );
    let confidential_core_runtime_witness_constructors_private = confidential_core_source
        .contains("fn from_runtime_witness(")
        && !confidential_core_source.contains("pub fn from_runtime_witness(");
    let confidential_core_reuses_shell_boundary_bundle_only = confidential_core_source
        .contains("RuntimeShellBoundaryBundle::from_runtime_witness(runtime_witness.clone())?;")
        && !confidential_core_source.contains(".shell_contract()")
        && !confidential_core_source.contains(".shell_trace()");
    let lean_shell_boundary_bundle_checks_exact_runtime_views = lean_runtime_shell_boundary_source
        .contains("bundle.shell_contract = bundle.kernel_witness.importedShellContract")
        && lean_runtime_shell_boundary_source.contains(
            "bundle.shell_trace = bundle.runtime_kernel_refinement_witness.importedShellTrace",
        )
        && lean_runtime_shell_boundary_source
            .contains("bundle.shell_trace.Refines bundle.shell_contract");
    let lean_imported_shell_boundary_kernel_boundary_facts_present =
        lean_runtime_shell_boundary_source.contains("ImportedRuntimeProofGradeKernelBoundaryFacts")
            && lean_runtime_shell_boundary_source
                .contains("theorem importedWitness_proofGradeKernelBoundaryFacts");
    let lean_confidential_core_proof_grade_assurance_present = lean_runtime_confidential_core_source
        .contains("theorem importedRuntimeConfidentialCoreBundle_proofGradeAssurance")
        && lean_runtime_confidential_core_source.contains("kernelWitness.expected_kernel_steps =")
        && lean_runtime_confidential_core_source.contains(
            "kernelWitness.kernel_steps = bundle.confidential_program.expectedRuntimeKernelSteps",
        )
        && lean_runtime_confidential_core_source
            .contains("runtimeKernelRefinementWitness.shellTrace.ProofGradeRefines");
    let lean_confidential_core_reuses_kernel_boundary_facts = lean_runtime_confidential_core_source
        .contains("importedWitness_proofGradeKernelBoundaryFacts");
    let lean_confidential_core_shell_boundary_slot_exactness_present =
        lean_runtime_confidential_core_shell_boundary_slot_source.contains(
            "theorem importedRuntimeConfidentialCoreShellBoundarySlotBundle_proofGradeAssurance",
        ) && lean_runtime_confidential_core_shell_boundary_slot_source.contains(
            "bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness",
        ) && lean_runtime_confidential_core_shell_boundary_slot_source.contains(
            "bundle.runtime_witness.runtime_kernel_refinement_witness =",
        ) && lean_runtime_confidential_core_shell_boundary_slot_source.contains(
            "some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness",
        ) && lean_runtime_confidential_core_shell_boundary_slot_source.contains(
            "bundle.shell_boundary_bundle.runtime_kernel_refinement_witness.shellTrace.ProofGradeRefines",
        );
    let lean_confidential_core_shell_boundary_lowering_exactness_present =
        lean_runtime_confidential_core_shell_boundary_lowering_source.contains(
            "theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_kernelWitness_exact",
        ) && lean_runtime_confidential_core_shell_boundary_lowering_source.contains(
            "theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_runtimeKernelRefinementWitness_exact",
        ) && lean_runtime_confidential_core_shell_boundary_lowering_source.contains(
            "theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_namedSchedule_exact",
        ) && lean_runtime_confidential_core_shell_boundary_lowering_source.contains(
            "theorem importedRuntimeConfidentialCoreShellBoundaryLoweringBundle_recomputedSlotSchedule_exact",
        );
    let trusted_kernel_slot_bundle_bridge_checks = [
        (
            "pub fn program_matches_trusted_kernel_entrypoint(&self) -> bool {",
            vec![String::from("crates/uo-core/src/trusted_kernel.rs")],
        ),
        (
            "pub fn runtime_trusted_kernel_slot_bundle(",
            vec![String::from("crates/uo-core/src/trusted_kernel.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let trusted_kernel_slot_bundle_bridge_surface_restricted =
        trusted_kernel_slot_bundle_bridge_checks
            .iter()
            .all(|entry| {
                entry["restricted"]
                    .as_bool()
                    .expect("trusted-kernel slot bridge restriction flag must be boolean")
            });
    let runtime_trusted_kernel_bundle_fields_private = core_trace_source
        .contains("pub struct RuntimeTrustedKernelBundle {")
        && core_trace_source.contains("runtime_seed: Option<u64>,")
        && core_trace_source.contains("controller_observer: RuntimeControllerObserverCertificate,")
        && core_trace_source.contains("kernel_witness: Option<RuntimeKernelWitness>,")
        && core_trace_source.contains("hidden_certificate: RuntimePathOramHiddenCertificate,")
        && !core_trace_source.contains("pub runtime_seed: Option<u64>,")
        && !core_trace_source
            .contains("pub controller_observer: RuntimeControllerObserverCertificate,")
        && !core_trace_source.contains("pub kernel_witness: Option<RuntimeKernelWitness>,")
        && !core_trace_source.contains("pub hidden_certificate: RuntimePathOramHiddenCertificate,");
    let runtime_trusted_kernel_bundle_api_is_explicit = core_trace_source
        .contains("pub fn runtime_seed(&self) -> Option<u64> {")
        && core_trace_source.contains(
            "pub fn controller_observer(&self) -> &RuntimeControllerObserverCertificate {",
        )
        && core_trace_source
            .contains("pub fn kernel_witness(&self) -> Option<&RuntimeKernelWitness> {")
        && core_trace_source
            .contains("pub fn hidden_certificate(&self) -> &RuntimePathOramHiddenCertificate {");
    let execution_trace_runtime_fields_private = core_trace_source
        .contains("pub struct ExecutionTrace {")
        && core_trace_source.contains("runtime_seed: Option<u64>,")
        && core_trace_source.contains("runtime_kernel_witness: Option<RuntimeKernelWitness>,")
        && core_trace_source
            .contains("runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,")
        && core_trace_source
            .contains("runtime_trusted_kernel_bundle: Option<RuntimeTrustedKernelBundle>,")
        && core_trace_source
            .contains("runtime_controller_certificate: Option<RuntimeControllerCertificate>,")
        && core_trace_source.contains("runtime_oram_objects: Vec<RuntimeOramObjectWitness>,")
        && core_trace_source.contains("runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,")
        && core_trace_source
            .contains("runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,")
        && core_trace_source
            .contains("runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,")
        && core_trace_source
            .contains("runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,")
        && core_trace_source
            .contains("runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,")
        && core_trace_source.contains(
            "runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,",
        )
        && !core_trace_source.contains("pub runtime_seed: Option<u64>,")
        && !core_trace_source.contains("pub runtime_kernel_witness: Option<RuntimeKernelWitness>,")
        && !core_trace_source.contains(
            "pub runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,",
        )
        && !core_trace_source
            .contains("pub runtime_trusted_kernel_bundle: Option<RuntimeTrustedKernelBundle>,")
        && !core_trace_source
            .contains("pub runtime_controller_certificate: Option<RuntimeControllerCertificate>,")
        && !core_trace_source.contains("pub runtime_oram_objects: Vec<RuntimeOramObjectWitness>,")
        && !core_trace_source
            .contains("pub runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,")
        && !core_trace_source.contains(
            "pub runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,",
        );
    let execution_trace_runtime_api_is_explicit = core_trace_source
        .contains("pub fn runtime_seed(&self) -> Option<u64> {")
        && core_trace_source
            .contains("pub fn runtime_kernel_witness(&self) -> Option<&RuntimeKernelWitness> {")
        && core_trace_source.contains(
            "pub fn runtime_kernel_refinement_witness(&self) -> Option<&RuntimeKernelRefinementWitness> {",
        )
        && core_trace_source.contains(
            "pub fn stored_runtime_trusted_kernel_bundle(&self) -> Option<&RuntimeTrustedKernelBundle> {",
        )
        && core_trace_source.contains(
            "pub fn stored_runtime_controller_certificate(&self) -> Option<&RuntimeControllerCertificate> {",
        )
        && core_trace_source
            .contains("pub fn runtime_oram_objects(&self) -> &[RuntimeOramObjectWitness] {")
        && core_trace_source
            .contains("pub fn runtime_oram_leaf_schedule(&self) -> &[RuntimeOramLeafWitness] {")
        && core_trace_source.contains(
            "pub fn runtime_oram_access_counters_before(&self) -> &[RuntimeOramAccessCounterWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_access_counters_after(&self) -> &[RuntimeOramAccessCounterWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_position_map_before(&self) -> &[RuntimePathOramPositionMapWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_position_map_after(&self) -> &[RuntimePathOramPositionMapWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_leaf_state_transitions(&self) -> &[RuntimePathOramTransitionWitness] {",
        );
    let trusted_kernel_slot_bundle_constructor_private = trusted_kernel_source
        .contains("fn from_trusted_kernel_bundle(")
        && !trusted_kernel_source.contains("pub fn from_trusted_kernel_bundle(");
    let runtime_trusted_kernel_slot_bundle_fields_private = trusted_kernel_source
        .contains("pub struct RuntimeTrustedKernelSlotBundle {")
        && trusted_kernel_source.contains("trusted_kernel_bundle: RuntimeTrustedKernelBundle,")
        && trusted_kernel_source
            .contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !trusted_kernel_source
            .contains("pub trusted_kernel_bundle: RuntimeTrustedKernelBundle,")
        && !trusted_kernel_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_trusted_kernel_slot_bundle_api_is_explicit = trusted_kernel_source
        .contains("pub fn trusted_kernel_bundle(&self) -> &RuntimeTrustedKernelBundle {")
        && trusted_kernel_source.contains(
            "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
        );
    let trusted_kernel_slot_bundle_uses_manifest_slot_program = trusted_kernel_source
        .contains("manifest_entry")
        && trusted_kernel_source.contains(".confidential_slot_program")
        && !trusted_kernel_source.contains(".confidential_program");
    let lean_trusted_kernel_slot_bundle_proof_grade_exactness_present =
        lean_runtime_trusted_kernel_source
            .contains("theorem importedRuntimeTrustedKernelBundle_proofGradeKernelSchedule_exact")
            && lean_runtime_trusted_kernel_source
                .contains("bundle.trusted_kernel_bundle.ProofGradeValid modelTags")
            && lean_runtime_trusted_kernel_source
                .contains("def ImportedRuntimeTrustedKernelSlotBundle.Valid")
            && lean_runtime_trusted_kernel_source
                .contains("bundle.trusted_kernel_bundle.checkProofGrade modelTags")
            && lean_runtime_trusted_kernel_source
                .contains("theorem importedRuntimeTrustedKernelSlotBundle_toRuntimeValid");
    let shell_boundary_slot_lowering_bridge_checks = [
        (
            "RuntimeShellBoundaryLoweringBundle::from_manifest_entry(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeShellBoundarySlotBundle::from_manifest_entry(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "pub fn runtime_shell_boundary_lowering_bundle(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "pub fn runtime_shell_boundary_slot_bundle(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let shell_boundary_slot_lowering_bridge_surface_restricted =
        shell_boundary_slot_lowering_bridge_checks
            .iter()
            .all(|entry| {
                entry["restricted"]
                    .as_bool()
                    .expect("shell-boundary slot/lowering bridge restriction flag must be boolean")
            });
    let runtime_shell_boundary_lowering_bundle_fields_private = kernel_dsl_source
        .contains("pub struct RuntimeShellBoundaryLoweringBundle {")
        && kernel_dsl_source.contains("shell_boundary_bundle: RuntimeShellBoundaryBundle,")
        && kernel_dsl_source.contains("confidential_program: ConfidentialKernelProgram,")
        && kernel_dsl_source.contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !kernel_dsl_source.contains("pub shell_boundary_bundle: RuntimeShellBoundaryBundle,")
        && !kernel_dsl_source.contains("pub confidential_program: ConfidentialKernelProgram,")
        && !kernel_dsl_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_shell_boundary_lowering_bundle_api_is_explicit = kernel_dsl_source
        .contains("pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {")
        && kernel_dsl_source
            .contains("pub fn confidential_program(&self) -> &ConfidentialKernelProgram {")
        && kernel_dsl_source.contains(
            "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
        );
    let runtime_shell_boundary_slot_bundle_fields_private = kernel_dsl_source
        .contains("pub struct RuntimeShellBoundarySlotBundle {")
        && kernel_dsl_source.contains("shell_boundary_bundle: RuntimeShellBoundaryBundle,")
        && kernel_dsl_source.contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !kernel_dsl_source.contains("pub shell_boundary_bundle: RuntimeShellBoundaryBundle,")
        && !kernel_dsl_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_shell_boundary_slot_bundle_api_is_explicit = kernel_dsl_source
        .contains("pub fn shell_boundary_bundle(&self) -> &RuntimeShellBoundaryBundle {")
        && kernel_dsl_source.contains(
            "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
        );
    let shell_boundary_slot_lowering_uses_manifest_programs = kernel_dsl_source
        .contains("entry.confidential_program")
        && kernel_dsl_source.contains("entry.confidential_slot_program")
        && kernel_dsl_source.contains("let manifest_entry = self");
    let kernel_dsl_manifest_entry_constructors_private = kernel_dsl_source
        .contains("fn from_manifest_entry(")
        && !kernel_dsl_source.contains("pub(crate) fn from_manifest_entry(")
        && !kernel_dsl_source.contains("pub fn from_manifest_entry(");
    let lean_shell_boundary_slot_bundle_exactness_present = lean_runtime_shell_boundary_slot_source
        .contains("theorem importedRuntimeShellBoundarySlotBundle_shellRefines")
        && lean_runtime_shell_boundary_slot_source
            .contains("theorem importedRuntimeShellBoundarySlotBundle_slotSchedule_exact")
        && lean_runtime_shell_boundary_slot_source
            .contains("theorem importedRuntimeShellBoundarySlotBundle_toRuntimeValid");
    let lean_shell_boundary_lowering_bundle_exactness_present =
        lean_runtime_shell_boundary_lowering_source
            .contains("theorem importedRuntimeShellBoundaryLoweringBundle_shellRefines")
            && lean_runtime_shell_boundary_lowering_source
                .contains("theorem importedRuntimeShellBoundaryLoweringBundle_lowering_exact")
            && lean_runtime_shell_boundary_lowering_source
                .contains("theorem importedRuntimeShellBoundaryLoweringBundle_namedSchedule_exact")
            && lean_runtime_shell_boundary_lowering_source.contains(
                "theorem importedRuntimeShellBoundaryLoweringBundle_recomputedSlotSchedule_exact",
            )
            && lean_runtime_shell_boundary_lowering_source
                .contains("theorem importedRuntimeShellBoundaryLoweringBundle_toRuntimeValid");
    let runtime_kernel_bundle_bridge_checks = [
        (
            "RuntimeKernelDslBundle::from_manifest_entry(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeKernelSlotDslBundle::from_manifest_entry(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeKernelLoweringBundle::from_manifest_entry(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "pub fn runtime_kernel_dsl_bundle_for_entrypoint(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "pub fn runtime_kernel_slot_dsl_bundle_for_entrypoint(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "pub fn runtime_kernel_lowering_bundle_for_entrypoint(",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let runtime_kernel_bundle_bridge_surface_restricted =
        runtime_kernel_bundle_bridge_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("runtime-kernel bundle bridge restriction flag must be boolean")
        });
    let runtime_kernel_dsl_bundle_fields_private = kernel_dsl_source
        .contains("pub struct RuntimeKernelDslBundle {")
        && kernel_dsl_source.contains("kernel_witness: RuntimeKernelWitness,")
        && kernel_dsl_source.contains("confidential_program: ConfidentialKernelProgram,")
        && !kernel_dsl_source.contains("pub kernel_witness: RuntimeKernelWitness,")
        && !kernel_dsl_source.contains("pub confidential_program: ConfidentialKernelProgram,");
    let runtime_kernel_dsl_bundle_api_is_explicit = kernel_dsl_source
        .contains("pub fn kernel_witness(&self) -> &RuntimeKernelWitness {")
        && kernel_dsl_source
            .contains("pub fn confidential_program(&self) -> &ConfidentialKernelProgram {");
    let runtime_kernel_slot_dsl_bundle_fields_private = kernel_dsl_source
        .contains("pub struct RuntimeKernelSlotDslBundle {")
        && kernel_dsl_source.contains("kernel_witness: RuntimeKernelWitness,")
        && kernel_dsl_source.contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !kernel_dsl_source.contains("pub kernel_witness: RuntimeKernelWitness,")
        && !kernel_dsl_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_kernel_slot_dsl_bundle_api_is_explicit = kernel_dsl_source
        .contains("pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {");
    let runtime_kernel_lowering_bundle_fields_private = kernel_dsl_source
        .contains("pub struct RuntimeKernelLoweringBundle {")
        && kernel_dsl_source.contains("kernel_witness: RuntimeKernelWitness,")
        && kernel_dsl_source.contains("confidential_program: ConfidentialKernelProgram,")
        && kernel_dsl_source.contains("confidential_slot_program: ConfidentialKernelSlotProgram,")
        && !kernel_dsl_source.contains("pub kernel_witness: RuntimeKernelWitness,")
        && !kernel_dsl_source.contains("pub confidential_program: ConfidentialKernelProgram,")
        && !kernel_dsl_source
            .contains("pub confidential_slot_program: ConfidentialKernelSlotProgram,");
    let runtime_kernel_lowering_bundle_api_is_explicit = kernel_dsl_source
        .contains("pub fn confidential_program(&self) -> &ConfidentialKernelProgram {")
        && kernel_dsl_source.contains(
            "pub fn confidential_slot_program(&self) -> &ConfidentialKernelSlotProgram {",
        );
    let runtime_kernel_bundle_uses_manifest_programs = kernel_dsl_source
        .contains("entry.confidential_program")
        && kernel_dsl_source.contains("entry.confidential_slot_program")
        && kernel_dsl_source.contains("let manifest_entry = self");
    let lean_runtime_kernel_dsl_bundle_exactness_present = lean_runtime_kernel_dsl_source
        .contains("theorem importedRuntimeKernelDslBundle_schedule_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelDslBundle_toRuntimeSchedule_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelDslBundle_entrypoint_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelDslBundle_toRuntimeEntrypoint_exact");
    let lean_runtime_kernel_slot_dsl_bundle_exactness_present = lean_runtime_kernel_dsl_source
        .contains("theorem importedRuntimeKernelSlotDslBundle_schedule_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelSlotDslBundle_toRuntimeSchedule_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelSlotDslBundle_entrypoint_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelSlotDslBundle_toRuntimeEntrypoint_exact");
    let lean_runtime_kernel_lowering_bundle_exactness_present = lean_runtime_kernel_dsl_source
        .contains("theorem importedRuntimeKernelLoweringBundle_lowering_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelLoweringBundle_namedSchedule_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_exact")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelLoweringBundle_toRuntimeValid")
        && lean_runtime_kernel_dsl_source
            .contains("theorem importedRuntimeKernelLoweringBundle_toRuntimeBundle_sound");
    let runtime_trace_bridge_checks = [
        (
            "fn new_with_kernel_witness(",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
        (
            "pub fn from_runtime_trace_parts(",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
        (
            "pub fn materialize_runtime_trusted_kernel_bundle(",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
        (
            "pub fn runtime_trusted_kernel_bundle(",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
        (
            "pub fn runtime_refinement_witness(",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
        (
            "RuntimeRefinementWitness::from_certificates_with_runtime_witnesses(",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let runtime_trace_bridge_surface_restricted = runtime_trace_bridge_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("runtime trace bridge restriction flag must be boolean")
    });
    let runtime_trusted_kernel_bundle_storage_surface_files = collect_production_pattern_hits(
        &runtime_evm_src,
        "materialize_runtime_trusted_kernel_bundle(",
    )?;
    let expected_runtime_trusted_kernel_bundle_storage_surface_files =
        vec![String::from("runtime/uo-evm/src/theorem.rs")];
    let runtime_trusted_kernel_bundle_storage_surface_restricted =
        runtime_trusted_kernel_bundle_storage_surface_files
            == expected_runtime_trusted_kernel_bundle_storage_surface_files;
    let runtime_trusted_kernel_bundle_field_assignment_files =
        collect_production_pattern_hits(&core_src, "runtime_trusted_kernel_bundle = Some(")?;
    let expected_runtime_trusted_kernel_bundle_field_assignment_files =
        vec![String::from("crates/uo-core/src/trace.rs")];
    let runtime_trusted_kernel_bundle_field_assignment_restricted =
        runtime_trusted_kernel_bundle_field_assignment_files
            == expected_runtime_trusted_kernel_bundle_field_assignment_files;
    let runtime_refinement_witness_reuses_trusted_kernel_bundle = core_trace_source
        .contains("let bundle = self.runtime_trusted_kernel_bundle()?;")
        && core_trace_source
            .contains("RuntimeRefinementWitness::from_certificates_with_runtime_witnesses(");
    let runtime_refinement_witness_constructors_private = core_trace_source
        .contains("fn from_certificates(")
        && core_trace_source.contains("fn from_certificates_with_kernel_witness(")
        && core_trace_source.contains("fn from_certificates_with_runtime_witnesses(")
        && !core_trace_source.contains("pub fn from_certificates(")
        && !core_trace_source.contains("pub fn from_certificates_with_kernel_witness(")
        && !core_trace_source.contains("pub fn from_certificates_with_runtime_witnesses(");
    let runtime_trusted_kernel_bundle_enforces_trace_exactness = core_trace_source
        .contains("fn store_runtime_trusted_kernel_bundle(")
        && core_trace_source
            .contains("let reconstructed = self.reconstructed_runtime_trusted_kernel_bundle()?;")
        && core_trace_source.contains("if bundle != reconstructed {")
        && core_trace_source
            .contains("return Err(RefinementWitnessError::TrustedKernelBundleTraceMismatch);");
    let runtime_kernel_witness_export_uses_explicit_field_only = core_trace_source
        .contains("pub fn runtime_kernel_witness_for_confidential(")
        && core_trace_source.contains(".runtime_kernel_witness\n            .clone()")
        && core_trace_source.contains(".ok_or(KernelWitnessError::MissingKernelWitness)?;")
        && !core_trace_source.contains(".and_then(|bundle| bundle.kernel_witness.clone())");
    let proof_interface_bundle_literal_checks = [
        (
            "RuntimeShellBoundaryBundle {",
            vec![String::from("crates/uo-core/src/shell_boundary.rs")],
        ),
        (
            "RuntimeTrustedKernelBundle {",
            vec![String::from("crates/uo-core/src/trace.rs")],
        ),
        (
            "RuntimeTrustedKernelSlotBundle {",
            vec![String::from("crates/uo-core/src/trusted_kernel.rs")],
        ),
        (
            "RuntimeKernelDslBundle {",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeKernelSlotDslBundle {",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeKernelLoweringBundle {",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeShellBoundaryLoweringBundle {",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeShellBoundarySlotBundle {",
            vec![String::from("crates/uo-core/src/kernel_dsl.rs")],
        ),
        (
            "RuntimeConfidentialCoreBundle {",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "RuntimeConfidentialCoreSlotBundle {",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "RuntimeConfidentialCoreLoweringBundle {",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "RuntimeConfidentialCoreShellBoundaryLoweringBundle {",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
        (
            "RuntimeConfidentialCoreShellBoundarySlotBundle {",
            vec![String::from("crates/uo-core/src/confidential_core.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&core_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let proof_interface_bundle_literal_surface_restricted =
        proof_interface_bundle_literal_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("proof-interface bundle literal restriction flag must be boolean")
        });
    let lean_runtime_refinement_proof_grade_exactness_present = lean_runtime_refinement_json_source
        .contains("def ImportedRuntimeRefinementWitness.ProofGradeValid")
        && lean_runtime_refinement_json_source
            .contains("theorem importedRuntimeRefinementWitness_toRuntimeWitness_proofGradeValid")
        && lean_runtime_refinement_json_source
            .contains("theorem importedWitness_proofGradeKernelSchedule_exact")
        && lean_runtime_refinement_json_source
            .contains("theorem importedWitness_projects_to_paper_observer");
    let lean_runtime_trusted_kernel_proof_grade_exactness_present =
        lean_runtime_trusted_kernel_source
            .contains("def ImportedRuntimeTrustedKernelBundle.ProofGradeValid")
            && lean_runtime_trusted_kernel_source.contains(
                "theorem importedRuntimeTrustedKernelBundle_proofGradeKernelSchedule_exact",
            )
            && lean_runtime_trusted_kernel_source
                .contains("theorem importedRuntimeTrustedKernelBundle_projects_to_paper_observer");

    let resource_event_kind_serde_snake_case =
        rust_enum_has_serde_snake_case(&core_trace_source, "RuntimeKernelResourceEventKindWitness");
    let scratch_region_serde_snake_case =
        rust_enum_has_serde_snake_case(&core_trace_source, "RuntimeKernelScratchRegionWitness");
    let refinement_event_kind_serde_snake_case = rust_enum_has_serde_snake_case(
        &core_trace_source,
        "RuntimeKernelRefinementEventKindWitness",
    );
    let confidential_kernel_statement_serde_snake_case =
        rust_enum_has_serde_snake_case(&confidential_kernel_source, "ConfidentialKernelStatement");
    let confidential_kernel_expr_serde_snake_case =
        rust_enum_has_serde_snake_case(&confidential_kernel_source, "ConfidentialKernelExpr");
    let confidential_kernel_pure_expr_serde_snake_case =
        rust_enum_has_serde_snake_case(&confidential_kernel_source, "ConfidentialKernelPureExpr");
    let confidential_kernel_slot_statement_serde_snake_case = rust_enum_has_serde_snake_case(
        &confidential_kernel_source,
        "ConfidentialKernelSlotStatement",
    );
    let confidential_kernel_slot_expr_serde_snake_case =
        rust_enum_has_serde_snake_case(&confidential_kernel_source, "ConfidentialKernelSlotExpr");
    let confidential_kernel_slot_pure_expr_serde_snake_case = rust_enum_has_serde_snake_case(
        &confidential_kernel_source,
        "ConfidentialKernelSlotPureExpr",
    );

    let accepted = opcode_names_match
        && resource_event_kind_names_match
        && scratch_region_names_match
        && refinement_event_kind_names_match
        && confidential_kernel_statement_kind_names_match
        && confidential_kernel_expr_kind_names_match
        && confidential_kernel_pure_expr_kind_names_match
        && confidential_kernel_slot_statement_kind_names_match
        && confidential_kernel_slot_expr_kind_names_match
        && confidential_kernel_slot_pure_expr_kind_names_match
        && confidential_kernel_param_field_names_match
        && confidential_kernel_program_field_names_match
        && confidential_kernel_slot_program_field_names_match
        && runtime_kernel_lowering_bundle_field_names_match
        && runtime_kernel_slot_dsl_bundle_field_names_match
        && runtime_confidential_core_lowering_bundle_field_names_match
        && runtime_confidential_core_slot_bundle_field_names_match
        && runtime_confidential_core_shell_boundary_slot_bundle_field_names_match
        && runtime_confidential_core_shell_boundary_lowering_bundle_field_names_match
        && runtime_trusted_kernel_slot_bundle_field_names_match
        && runtime_shell_contract_field_names_match
        && runtime_shell_trace_field_names_match
        && runtime_shell_boundary_bundle_field_names_match
        && runtime_shell_boundary_slot_bundle_field_names_match
        && runtime_shell_boundary_lowering_bundle_field_names_match
        && shell_boundary_exact_bridge_surface_restricted
        && shell_boundary_bundle_refinement_guard_present
        && runtime_shell_trace_fields_private
        && runtime_shell_trace_api_is_explicit
        && runtime_shell_boundary_bundle_fields_private
        && runtime_shell_boundary_bundle_api_is_explicit
        && confidential_core_bundle_bridge_surface_restricted
        && runtime_confidential_core_bundle_fields_private
        && runtime_confidential_core_bundle_api_is_explicit
        && runtime_confidential_core_slot_bundle_fields_private
        && runtime_confidential_core_slot_bundle_api_is_explicit
        && runtime_confidential_core_lowering_bundle_fields_private
        && runtime_confidential_core_lowering_bundle_api_is_explicit
        && runtime_confidential_core_shell_boundary_lowering_bundle_fields_private
        && runtime_confidential_core_shell_boundary_lowering_bundle_api_is_explicit
        && runtime_confidential_core_shell_boundary_slot_bundle_fields_private
        && runtime_confidential_core_shell_boundary_slot_bundle_api_is_explicit
        && confidential_core_runtime_witness_constructors_private
        && confidential_core_reuses_shell_boundary_bundle_only
        && lean_shell_boundary_bundle_checks_exact_runtime_views
        && lean_imported_shell_boundary_kernel_boundary_facts_present
        && lean_confidential_core_proof_grade_assurance_present
        && lean_confidential_core_reuses_kernel_boundary_facts
        && lean_confidential_core_shell_boundary_slot_exactness_present
        && lean_confidential_core_shell_boundary_lowering_exactness_present
        && trusted_kernel_slot_bundle_bridge_surface_restricted
        && runtime_trusted_kernel_bundle_fields_private
        && runtime_trusted_kernel_bundle_api_is_explicit
        && execution_trace_runtime_fields_private
        && execution_trace_runtime_api_is_explicit
        && runtime_refinement_witness_constructors_private
        && trusted_kernel_slot_bundle_constructor_private
        && runtime_trusted_kernel_slot_bundle_fields_private
        && runtime_trusted_kernel_slot_bundle_api_is_explicit
        && trusted_kernel_slot_bundle_uses_manifest_slot_program
        && lean_trusted_kernel_slot_bundle_proof_grade_exactness_present
        && shell_boundary_slot_lowering_bridge_surface_restricted
        && runtime_shell_boundary_lowering_bundle_fields_private
        && runtime_shell_boundary_lowering_bundle_api_is_explicit
        && runtime_shell_boundary_slot_bundle_fields_private
        && runtime_shell_boundary_slot_bundle_api_is_explicit
        && shell_boundary_slot_lowering_uses_manifest_programs
        && kernel_dsl_manifest_entry_constructors_private
        && lean_shell_boundary_slot_bundle_exactness_present
        && lean_shell_boundary_lowering_bundle_exactness_present
        && runtime_kernel_bundle_bridge_surface_restricted
        && runtime_kernel_dsl_bundle_fields_private
        && runtime_kernel_dsl_bundle_api_is_explicit
        && runtime_kernel_slot_dsl_bundle_fields_private
        && runtime_kernel_slot_dsl_bundle_api_is_explicit
        && runtime_kernel_lowering_bundle_fields_private
        && runtime_kernel_lowering_bundle_api_is_explicit
        && runtime_kernel_bundle_uses_manifest_programs
        && lean_runtime_kernel_dsl_bundle_exactness_present
        && lean_runtime_kernel_slot_dsl_bundle_exactness_present
        && lean_runtime_kernel_lowering_bundle_exactness_present
        && runtime_trace_bridge_surface_restricted
        && runtime_trusted_kernel_bundle_storage_surface_restricted
        && runtime_trusted_kernel_bundle_field_assignment_restricted
        && runtime_refinement_witness_reuses_trusted_kernel_bundle
        && runtime_trusted_kernel_bundle_enforces_trace_exactness
        && runtime_kernel_witness_export_uses_explicit_field_only
        && proof_interface_bundle_literal_surface_restricted
        && lean_runtime_refinement_proof_grade_exactness_present
        && lean_runtime_trusted_kernel_proof_grade_exactness_present
        && resource_event_kind_serde_snake_case
        && scratch_region_serde_snake_case
        && refinement_event_kind_serde_snake_case
        && confidential_kernel_statement_serde_snake_case
        && confidential_kernel_expr_serde_snake_case
        && confidential_kernel_pure_expr_serde_snake_case
        && confidential_kernel_slot_statement_serde_snake_case
        && confidential_kernel_slot_expr_serde_snake_case
        && confidential_kernel_slot_pure_expr_serde_snake_case;

    Ok(json!({
        "accepted": accepted,
        "sources": {
            "rust_precompiles": display_report_path(&precompiles_path),
            "rust_core_trace": display_report_path(&core_trace_path),
            "rust_confidential_kernel": display_report_path(&confidential_kernel_path),
            "rust_kernel_dsl": display_report_path(&kernel_dsl_path),
            "rust_confidential_core": display_report_path(&confidential_core_path),
            "rust_trusted_kernel": display_report_path(&trusted_kernel_path),
            "rust_shell_boundary": display_report_path(&shell_boundary_path),
            "lean_runtime_refinement": display_report_path(&lean_runtime_refinement_path),
            "lean_runtime_refinement_json":
                display_report_path(&lean_runtime_refinement_json_path),
            "lean_runtime_trusted_kernel":
                display_report_path(&lean_runtime_trusted_kernel_path),
            "lean_runtime_shell_boundary":
                display_report_path(&lean_runtime_shell_boundary_path),
            "lean_runtime_shell_boundary_slot":
                display_report_path(&lean_runtime_shell_boundary_slot_path),
            "lean_runtime_shell_boundary_lowering":
                display_report_path(&lean_runtime_shell_boundary_lowering_path),
            "lean_runtime_kernel_dsl": display_report_path(&lean_runtime_kernel_dsl_path),
            "lean_runtime_confidential_core":
                display_report_path(&lean_runtime_confidential_core_path),
            "lean_runtime_confidential_core_shell_boundary_slot": display_report_path(
                &lean_runtime_confidential_core_shell_boundary_slot_path
            ),
            "lean_runtime_confidential_core_shell_boundary_lowering": display_report_path(
                &lean_runtime_confidential_core_shell_boundary_lowering_path
            ),
        },
        "rust_opcode_names": rust_opcode_names,
        "lean_opcode_names": lean_opcode_names,
        "opcode_names_match": opcode_names_match,
        "rust_resource_event_kind_names": rust_resource_event_kind_names,
        "lean_resource_event_kind_names": lean_resource_event_kind_names,
        "resource_event_kind_names_match": resource_event_kind_names_match,
        "rust_scratch_region_names": rust_scratch_region_names,
        "lean_scratch_region_names": lean_scratch_region_names,
        "scratch_region_names_match": scratch_region_names_match,
        "rust_refinement_event_kind_names": rust_refinement_event_kind_names,
        "lean_refinement_event_kind_names": lean_refinement_event_kind_names,
        "refinement_event_kind_names_match": refinement_event_kind_names_match,
        "rust_confidential_kernel_statement_kind_names":
            rust_confidential_kernel_statement_kind_names,
        "lean_confidential_kernel_statement_kind_names":
            lean_confidential_kernel_statement_kind_names,
        "confidential_kernel_statement_kind_names_match":
            confidential_kernel_statement_kind_names_match,
        "rust_confidential_kernel_expr_kind_names":
            rust_confidential_kernel_expr_kind_names,
        "lean_confidential_kernel_expr_kind_names":
            lean_confidential_kernel_expr_kind_names,
        "confidential_kernel_expr_kind_names_match":
            confidential_kernel_expr_kind_names_match,
        "rust_confidential_kernel_pure_expr_kind_names":
            rust_confidential_kernel_pure_expr_kind_names,
        "lean_confidential_kernel_pure_expr_kind_names":
            lean_confidential_kernel_pure_expr_kind_names,
        "confidential_kernel_pure_expr_kind_names_match":
            confidential_kernel_pure_expr_kind_names_match,
        "rust_confidential_kernel_slot_statement_kind_names":
            rust_confidential_kernel_slot_statement_kind_names,
        "lean_confidential_kernel_slot_statement_kind_names":
            lean_confidential_kernel_slot_statement_kind_names,
        "confidential_kernel_slot_statement_kind_names_match":
            confidential_kernel_slot_statement_kind_names_match,
        "rust_confidential_kernel_slot_expr_kind_names":
            rust_confidential_kernel_slot_expr_kind_names,
        "lean_confidential_kernel_slot_expr_kind_names":
            lean_confidential_kernel_slot_expr_kind_names,
        "confidential_kernel_slot_expr_kind_names_match":
            confidential_kernel_slot_expr_kind_names_match,
        "rust_confidential_kernel_slot_pure_expr_kind_names":
            rust_confidential_kernel_slot_pure_expr_kind_names,
        "lean_confidential_kernel_slot_pure_expr_kind_names":
            lean_confidential_kernel_slot_pure_expr_kind_names,
        "confidential_kernel_slot_pure_expr_kind_names_match":
            confidential_kernel_slot_pure_expr_kind_names_match,
        "rust_confidential_kernel_param_field_names":
            rust_confidential_kernel_param_field_names,
        "lean_confidential_kernel_param_field_names":
            lean_confidential_kernel_param_field_names,
        "confidential_kernel_param_field_names_match":
            confidential_kernel_param_field_names_match,
        "rust_confidential_kernel_program_field_names":
            rust_confidential_kernel_program_field_names,
        "lean_confidential_kernel_program_field_names":
            lean_confidential_kernel_program_field_names,
        "confidential_kernel_program_field_names_match":
            confidential_kernel_program_field_names_match,
        "rust_confidential_kernel_slot_program_field_names":
            rust_confidential_kernel_slot_program_field_names,
        "lean_confidential_kernel_slot_program_field_names":
            lean_confidential_kernel_slot_program_field_names,
        "confidential_kernel_slot_program_field_names_match":
            confidential_kernel_slot_program_field_names_match,
        "rust_runtime_kernel_lowering_bundle_field_names":
            rust_runtime_kernel_lowering_bundle_field_names,
        "lean_runtime_kernel_lowering_bundle_field_names":
            lean_runtime_kernel_lowering_bundle_field_names,
        "runtime_kernel_lowering_bundle_field_names_match":
            runtime_kernel_lowering_bundle_field_names_match,
        "rust_runtime_kernel_slot_dsl_bundle_field_names":
            rust_runtime_kernel_slot_dsl_bundle_field_names,
        "lean_runtime_kernel_slot_dsl_bundle_field_names":
            lean_runtime_kernel_slot_dsl_bundle_field_names,
        "runtime_kernel_slot_dsl_bundle_field_names_match":
            runtime_kernel_slot_dsl_bundle_field_names_match,
        "rust_runtime_confidential_core_lowering_bundle_field_names":
            rust_runtime_confidential_core_lowering_bundle_field_names,
        "lean_runtime_confidential_core_lowering_bundle_field_names":
            lean_runtime_confidential_core_lowering_bundle_field_names,
        "runtime_confidential_core_lowering_bundle_field_names_match":
            runtime_confidential_core_lowering_bundle_field_names_match,
        "rust_runtime_confidential_core_slot_bundle_field_names":
            rust_runtime_confidential_core_slot_bundle_field_names,
        "lean_runtime_confidential_core_slot_bundle_field_names":
            lean_runtime_confidential_core_slot_bundle_field_names,
        "runtime_confidential_core_slot_bundle_field_names_match":
            runtime_confidential_core_slot_bundle_field_names_match,
        "rust_runtime_confidential_core_shell_boundary_slot_bundle_field_names":
            rust_runtime_confidential_core_shell_boundary_slot_bundle_field_names,
        "lean_runtime_confidential_core_shell_boundary_slot_bundle_field_names":
            lean_runtime_confidential_core_shell_boundary_slot_bundle_field_names,
        "runtime_confidential_core_shell_boundary_slot_bundle_field_names_match":
            runtime_confidential_core_shell_boundary_slot_bundle_field_names_match,
        "rust_runtime_confidential_core_shell_boundary_lowering_bundle_field_names":
            rust_runtime_confidential_core_shell_boundary_lowering_bundle_field_names,
        "lean_runtime_confidential_core_shell_boundary_lowering_bundle_field_names":
            lean_runtime_confidential_core_shell_boundary_lowering_bundle_field_names,
        "runtime_confidential_core_shell_boundary_lowering_bundle_field_names_match":
            runtime_confidential_core_shell_boundary_lowering_bundle_field_names_match,
        "rust_runtime_trusted_kernel_slot_bundle_field_names":
            rust_runtime_trusted_kernel_slot_bundle_field_names,
        "lean_runtime_trusted_kernel_slot_bundle_field_names":
            lean_runtime_trusted_kernel_slot_bundle_field_names,
        "runtime_trusted_kernel_slot_bundle_field_names_match":
            runtime_trusted_kernel_slot_bundle_field_names_match,
        "rust_runtime_shell_contract_field_names":
            rust_runtime_shell_contract_field_names,
        "lean_runtime_shell_contract_field_names":
            lean_runtime_shell_contract_field_names,
        "runtime_shell_contract_field_names_match":
            runtime_shell_contract_field_names_match,
        "rust_runtime_shell_trace_field_names":
            rust_runtime_shell_trace_field_names,
        "lean_runtime_shell_trace_field_names":
            lean_runtime_shell_trace_field_names,
        "runtime_shell_trace_field_names_match":
            runtime_shell_trace_field_names_match,
        "rust_runtime_shell_boundary_bundle_field_names":
            rust_runtime_shell_boundary_bundle_field_names,
        "lean_runtime_shell_boundary_bundle_field_names":
            lean_runtime_shell_boundary_bundle_field_names,
        "runtime_shell_boundary_bundle_field_names_match":
            runtime_shell_boundary_bundle_field_names_match,
        "rust_runtime_shell_boundary_slot_bundle_field_names":
            rust_runtime_shell_boundary_slot_bundle_field_names,
        "lean_runtime_shell_boundary_slot_bundle_field_names":
            lean_runtime_shell_boundary_slot_bundle_field_names,
        "runtime_shell_boundary_slot_bundle_field_names_match":
            runtime_shell_boundary_slot_bundle_field_names_match,
        "rust_runtime_shell_boundary_lowering_bundle_field_names":
            rust_runtime_shell_boundary_lowering_bundle_field_names,
        "lean_runtime_shell_boundary_lowering_bundle_field_names":
            lean_runtime_shell_boundary_lowering_bundle_field_names,
        "runtime_shell_boundary_lowering_bundle_field_names_match":
            runtime_shell_boundary_lowering_bundle_field_names_match,
        "shell_boundary_exact_bridge_checks": shell_boundary_exact_bridge_checks,
        "shell_boundary_exact_bridge_surface_restricted":
            shell_boundary_exact_bridge_surface_restricted,
        "shell_boundary_bundle_refinement_guard_present":
            shell_boundary_bundle_refinement_guard_present,
        "runtime_shell_trace_fields_private": runtime_shell_trace_fields_private,
        "runtime_shell_trace_api_is_explicit": runtime_shell_trace_api_is_explicit,
        "runtime_shell_boundary_bundle_fields_private":
            runtime_shell_boundary_bundle_fields_private,
        "runtime_shell_boundary_bundle_api_is_explicit":
            runtime_shell_boundary_bundle_api_is_explicit,
        "confidential_core_bundle_bridge_checks":
            confidential_core_bundle_bridge_checks,
        "confidential_core_bundle_bridge_surface_restricted":
            confidential_core_bundle_bridge_surface_restricted,
        "runtime_confidential_core_bundle_fields_private":
            runtime_confidential_core_bundle_fields_private,
        "runtime_confidential_core_bundle_api_is_explicit":
            runtime_confidential_core_bundle_api_is_explicit,
        "runtime_confidential_core_slot_bundle_fields_private":
            runtime_confidential_core_slot_bundle_fields_private,
        "runtime_confidential_core_slot_bundle_api_is_explicit":
            runtime_confidential_core_slot_bundle_api_is_explicit,
        "runtime_confidential_core_lowering_bundle_fields_private":
            runtime_confidential_core_lowering_bundle_fields_private,
        "runtime_confidential_core_lowering_bundle_api_is_explicit":
            runtime_confidential_core_lowering_bundle_api_is_explicit,
        "runtime_confidential_core_shell_boundary_lowering_bundle_fields_private":
            runtime_confidential_core_shell_boundary_lowering_bundle_fields_private,
        "runtime_confidential_core_shell_boundary_lowering_bundle_api_is_explicit":
            runtime_confidential_core_shell_boundary_lowering_bundle_api_is_explicit,
        "runtime_confidential_core_shell_boundary_slot_bundle_fields_private":
            runtime_confidential_core_shell_boundary_slot_bundle_fields_private,
        "runtime_confidential_core_shell_boundary_slot_bundle_api_is_explicit":
            runtime_confidential_core_shell_boundary_slot_bundle_api_is_explicit,
        "confidential_core_runtime_witness_constructors_private":
            confidential_core_runtime_witness_constructors_private,
        "confidential_core_reuses_shell_boundary_bundle_only":
            confidential_core_reuses_shell_boundary_bundle_only,
        "lean_shell_boundary_bundle_checks_exact_runtime_views":
            lean_shell_boundary_bundle_checks_exact_runtime_views,
        "lean_imported_shell_boundary_kernel_boundary_facts_present":
            lean_imported_shell_boundary_kernel_boundary_facts_present,
        "lean_confidential_core_proof_grade_assurance_present":
            lean_confidential_core_proof_grade_assurance_present,
        "lean_confidential_core_reuses_kernel_boundary_facts":
            lean_confidential_core_reuses_kernel_boundary_facts,
        "lean_confidential_core_shell_boundary_slot_exactness_present":
            lean_confidential_core_shell_boundary_slot_exactness_present,
        "lean_confidential_core_shell_boundary_lowering_exactness_present":
            lean_confidential_core_shell_boundary_lowering_exactness_present,
        "trusted_kernel_slot_bundle_bridge_checks":
            trusted_kernel_slot_bundle_bridge_checks,
        "trusted_kernel_slot_bundle_bridge_surface_restricted":
            trusted_kernel_slot_bundle_bridge_surface_restricted,
        "runtime_trusted_kernel_bundle_fields_private":
            runtime_trusted_kernel_bundle_fields_private,
        "runtime_trusted_kernel_bundle_api_is_explicit":
            runtime_trusted_kernel_bundle_api_is_explicit,
        "execution_trace_runtime_fields_private":
            execution_trace_runtime_fields_private,
        "execution_trace_runtime_api_is_explicit":
            execution_trace_runtime_api_is_explicit,
        "runtime_refinement_witness_constructors_private":
            runtime_refinement_witness_constructors_private,
        "trusted_kernel_slot_bundle_constructor_private":
            trusted_kernel_slot_bundle_constructor_private,
        "runtime_trusted_kernel_slot_bundle_fields_private":
            runtime_trusted_kernel_slot_bundle_fields_private,
        "runtime_trusted_kernel_slot_bundle_api_is_explicit":
            runtime_trusted_kernel_slot_bundle_api_is_explicit,
        "trusted_kernel_slot_bundle_uses_manifest_slot_program":
            trusted_kernel_slot_bundle_uses_manifest_slot_program,
        "lean_trusted_kernel_slot_bundle_proof_grade_exactness_present":
            lean_trusted_kernel_slot_bundle_proof_grade_exactness_present,
        "shell_boundary_slot_lowering_bridge_checks":
            shell_boundary_slot_lowering_bridge_checks,
        "shell_boundary_slot_lowering_bridge_surface_restricted":
            shell_boundary_slot_lowering_bridge_surface_restricted,
        "runtime_shell_boundary_lowering_bundle_fields_private":
            runtime_shell_boundary_lowering_bundle_fields_private,
        "runtime_shell_boundary_lowering_bundle_api_is_explicit":
            runtime_shell_boundary_lowering_bundle_api_is_explicit,
        "runtime_shell_boundary_slot_bundle_fields_private":
            runtime_shell_boundary_slot_bundle_fields_private,
        "runtime_shell_boundary_slot_bundle_api_is_explicit":
            runtime_shell_boundary_slot_bundle_api_is_explicit,
        "shell_boundary_slot_lowering_uses_manifest_programs":
            shell_boundary_slot_lowering_uses_manifest_programs,
        "kernel_dsl_manifest_entry_constructors_private":
            kernel_dsl_manifest_entry_constructors_private,
        "lean_shell_boundary_slot_bundle_exactness_present":
            lean_shell_boundary_slot_bundle_exactness_present,
        "lean_shell_boundary_lowering_bundle_exactness_present":
            lean_shell_boundary_lowering_bundle_exactness_present,
        "runtime_kernel_bundle_bridge_checks":
            runtime_kernel_bundle_bridge_checks,
        "runtime_kernel_bundle_bridge_surface_restricted":
            runtime_kernel_bundle_bridge_surface_restricted,
        "runtime_kernel_dsl_bundle_fields_private":
            runtime_kernel_dsl_bundle_fields_private,
        "runtime_kernel_dsl_bundle_api_is_explicit":
            runtime_kernel_dsl_bundle_api_is_explicit,
        "runtime_kernel_slot_dsl_bundle_fields_private":
            runtime_kernel_slot_dsl_bundle_fields_private,
        "runtime_kernel_slot_dsl_bundle_api_is_explicit":
            runtime_kernel_slot_dsl_bundle_api_is_explicit,
        "runtime_kernel_lowering_bundle_fields_private":
            runtime_kernel_lowering_bundle_fields_private,
        "runtime_kernel_lowering_bundle_api_is_explicit":
            runtime_kernel_lowering_bundle_api_is_explicit,
        "runtime_kernel_bundle_uses_manifest_programs":
            runtime_kernel_bundle_uses_manifest_programs,
        "lean_runtime_kernel_dsl_bundle_exactness_present":
            lean_runtime_kernel_dsl_bundle_exactness_present,
        "lean_runtime_kernel_slot_dsl_bundle_exactness_present":
            lean_runtime_kernel_slot_dsl_bundle_exactness_present,
        "lean_runtime_kernel_lowering_bundle_exactness_present":
            lean_runtime_kernel_lowering_bundle_exactness_present,
        "runtime_trace_bridge_checks": runtime_trace_bridge_checks,
        "runtime_trace_bridge_surface_restricted":
            runtime_trace_bridge_surface_restricted,
        "runtime_trusted_kernel_bundle_storage_surface_files":
            runtime_trusted_kernel_bundle_storage_surface_files,
        "expected_runtime_trusted_kernel_bundle_storage_surface_files":
            expected_runtime_trusted_kernel_bundle_storage_surface_files,
        "runtime_trusted_kernel_bundle_storage_surface_restricted":
            runtime_trusted_kernel_bundle_storage_surface_restricted,
        "runtime_trusted_kernel_bundle_field_assignment_files":
            runtime_trusted_kernel_bundle_field_assignment_files,
        "expected_runtime_trusted_kernel_bundle_field_assignment_files":
            expected_runtime_trusted_kernel_bundle_field_assignment_files,
        "runtime_trusted_kernel_bundle_field_assignment_restricted":
            runtime_trusted_kernel_bundle_field_assignment_restricted,
        "runtime_refinement_witness_reuses_trusted_kernel_bundle":
            runtime_refinement_witness_reuses_trusted_kernel_bundle,
        "runtime_trusted_kernel_bundle_enforces_trace_exactness":
            runtime_trusted_kernel_bundle_enforces_trace_exactness,
        "runtime_kernel_witness_export_uses_explicit_field_only":
            runtime_kernel_witness_export_uses_explicit_field_only,
        "proof_interface_bundle_literal_checks":
            proof_interface_bundle_literal_checks,
        "proof_interface_bundle_literal_surface_restricted":
            proof_interface_bundle_literal_surface_restricted,
        "lean_runtime_refinement_proof_grade_exactness_present":
            lean_runtime_refinement_proof_grade_exactness_present,
        "lean_runtime_trusted_kernel_proof_grade_exactness_present":
            lean_runtime_trusted_kernel_proof_grade_exactness_present,
        "resource_event_kind_serde_snake_case": resource_event_kind_serde_snake_case,
        "scratch_region_serde_snake_case": scratch_region_serde_snake_case,
        "refinement_event_kind_serde_snake_case": refinement_event_kind_serde_snake_case,
        "confidential_kernel_statement_serde_snake_case":
            confidential_kernel_statement_serde_snake_case,
        "confidential_kernel_expr_serde_snake_case": confidential_kernel_expr_serde_snake_case,
        "confidential_kernel_pure_expr_serde_snake_case":
            confidential_kernel_pure_expr_serde_snake_case,
        "confidential_kernel_slot_statement_serde_snake_case":
            confidential_kernel_slot_statement_serde_snake_case,
        "confidential_kernel_slot_expr_serde_snake_case":
            confidential_kernel_slot_expr_serde_snake_case,
        "confidential_kernel_slot_pure_expr_serde_snake_case":
            confidential_kernel_slot_pure_expr_serde_snake_case,
    }))
}

fn run_runtime_boundary_validation() -> Result<JsonValue> {
    let root = repo_root();
    let engine_path = root.join("runtime/uo-evm/src/engine.rs");
    let shell_path = root.join("runtime/uo-evm/src/shell.rs");
    let fresh_coins_path = root.join("runtime/uo-evm/src/fresh_coins.rs");
    let kernel_path = root.join("runtime/uo-evm/src/kernel.rs");
    let objects_path = root.join("runtime/uo-evm/src/objects.rs");
    let oram_path = root.join("runtime/uo-evm/src/oram.rs");
    let state_path = root.join("runtime/uo-evm/src/state.rs");
    let controller_path = root.join("runtime/uo-evm/src/controller.rs");
    let theorem_path = root.join("runtime/uo-evm/src/theorem.rs");
    let main_path = root.join("runtime/uo-evm/src/main.rs");
    let probe_path = root.join("probe/mplus-probe/src/lib.rs");
    let allocator_path = root.join("runtime/uo-allocator/src/lib.rs");
    let store_codec_path = root.join("runtime/uo-store/src/codec.rs");
    let store_store_path = root.join("runtime/uo-store/src/store.rs");
    let checker_path = root.join("checker/uo-check/src/lib.rs");
    let core_trace_path = root.join("crates/uo-core/src/trace.rs");
    let translation_validation_path = root.join("crates/uo-core/src/translation_validation.rs");
    let core_trusted_kernel_path = root.join("crates/uo-core/src/trusted_kernel.rs");
    let runtime_module_path = root.join("runtime/uo-evm/src/runtime.rs");
    let runtime_evm_lib_path = root.join("runtime/uo-evm/src/lib.rs");
    let runtime_evm_cargo_path = root.join("runtime/uo-evm/Cargo.toml");
    let probe_cargo_path = root.join("probe/mplus-probe/Cargo.toml");
    let trusted_kernel_checker_path =
        root.join("proof/lean/CheckProofGradeRuntimeTrustedKernel.lean");
    let runtime_evm_src = root.join("runtime/uo-evm/src");
    let allocator_src = root.join("runtime/uo-allocator/src");
    let store_src = root.join("runtime/uo-store/src");

    let kernel_source = fs::read_to_string(&kernel_path)
        .with_context(|| format!("reading {}", display_report_path(&kernel_path)))?;
    let engine_source = fs::read_to_string(&engine_path)
        .with_context(|| format!("reading {}", display_report_path(&engine_path)))?;
    let shell_source = fs::read_to_string(&shell_path)
        .with_context(|| format!("reading {}", display_report_path(&shell_path)))?;
    let fresh_coins_source = fs::read_to_string(&fresh_coins_path)
        .with_context(|| format!("reading {}", display_report_path(&fresh_coins_path)))?;
    let objects_source = fs::read_to_string(&objects_path)
        .with_context(|| format!("reading {}", display_report_path(&objects_path)))?;
    let oram_source = fs::read_to_string(&oram_path)
        .with_context(|| format!("reading {}", display_report_path(&oram_path)))?;
    let state_source = fs::read_to_string(&state_path)
        .with_context(|| format!("reading {}", display_report_path(&state_path)))?;
    let controller_source = fs::read_to_string(&controller_path)
        .with_context(|| format!("reading {}", display_report_path(&controller_path)))?;
    let theorem_source = fs::read_to_string(&theorem_path)
        .with_context(|| format!("reading {}", display_report_path(&theorem_path)))?;
    let main_source = fs::read_to_string(&main_path)
        .with_context(|| format!("reading {}", display_report_path(&main_path)))?;
    let probe_source = fs::read_to_string(&probe_path)
        .with_context(|| format!("reading {}", display_report_path(&probe_path)))?;
    let allocator_source = fs::read_to_string(&allocator_path)
        .with_context(|| format!("reading {}", display_report_path(&allocator_path)))?;
    let core_trusted_kernel_source = fs::read_to_string(&core_trusted_kernel_path)
        .with_context(|| format!("reading {}", display_report_path(&core_trusted_kernel_path)))?;
    let trusted_kernel_checker_source = fs::read_to_string(&trusted_kernel_checker_path)
        .with_context(|| {
            format!(
                "reading {}",
                display_report_path(&trusted_kernel_checker_path)
            )
        })?;
    let extract_metrics_start = probe_source
        .rfind("\nfn extract_metrics(")
        .ok_or_else(|| anyhow!("failed to locate extract_metrics in mplus-probe"))?
        + 1;
    let extract_metrics_suffix = &probe_source[extract_metrics_start..];
    let extract_metrics_end = extract_metrics_suffix
        .find("\nfn auc_report(")
        .ok_or_else(|| anyhow!("failed to locate auc_report after extract_metrics"))?;
    let extract_metrics_source = &extract_metrics_suffix[..extract_metrics_end];
    let scenario_overhead_start = probe_source
        .rfind("\nfn scenario_overhead(")
        .ok_or_else(|| anyhow!("failed to locate scenario_overhead in mplus-probe"))?
        + 1;
    let scenario_overhead_suffix = &probe_source[scenario_overhead_start..];
    let scenario_overhead_end = scenario_overhead_suffix
        .find("\nfn format_value(")
        .ok_or_else(|| anyhow!("failed to locate format_value after scenario_overhead"))?;
    let scenario_overhead_source = &scenario_overhead_suffix[..scenario_overhead_end];
    let call_result_struct_start = engine_source
        .find("pub struct CallResult {")
        .ok_or_else(|| anyhow!("failed to locate CallResult in engine"))?;
    let call_result_struct_suffix = &engine_source[call_result_struct_start..];
    let call_result_struct_end = call_result_struct_suffix
        .find("pub struct DiagnosticCallResult {")
        .ok_or_else(|| anyhow!("failed to locate DiagnosticCallResult after CallResult"))?;
    let call_result_struct_source = &call_result_struct_suffix[..call_result_struct_end];
    let store_codec_source = fs::read_to_string(&store_codec_path)
        .with_context(|| format!("reading {}", display_report_path(&store_codec_path)))?;
    let store_store_source = fs::read_to_string(&store_store_path)
        .with_context(|| format!("reading {}", display_report_path(&store_store_path)))?;
    let checker_source = fs::read_to_string(&checker_path)
        .with_context(|| format!("reading {}", display_report_path(&checker_path)))?;
    let core_trace_source = fs::read_to_string(&core_trace_path)
        .with_context(|| format!("reading {}", display_report_path(&core_trace_path)))?;
    let translation_validation_source = fs::read_to_string(&translation_validation_path)
        .with_context(|| {
            format!(
                "reading {}",
                display_report_path(&translation_validation_path)
            )
        })?;
    let runtime_evm_lib_source = fs::read_to_string(&runtime_evm_lib_path)
        .with_context(|| format!("reading {}", display_report_path(&runtime_evm_lib_path)))?;
    let runtime_evm_cargo_source = fs::read_to_string(&runtime_evm_cargo_path)
        .with_context(|| format!("reading {}", display_report_path(&runtime_evm_cargo_path)))?;
    let probe_cargo_source = fs::read_to_string(&probe_cargo_path)
        .with_context(|| format!("reading {}", display_report_path(&probe_cargo_path)))?;
    let runtime_module_source = fs::read_to_string(&runtime_module_path)
        .with_context(|| format!("reading {}", display_report_path(&runtime_module_path)))?;

    let engine_impl_source = production_source_slice(&engine_source);
    let shell_impl_source = production_source_slice(&shell_source);
    let forbidden_engine_helpers = [
        "prepare_public_shadow(",
        "commit_public_shadow(",
        "replace_with_cold_public_shadow(",
        "finalize_runtime_kernel_refinement_witness(",
        "build_theorem_trace(",
        "finalize_execution_trace(",
        "output_shape_of(",
        "clone_for_tx(",
        "commit(",
        "shadow_load_objects(",
        "shadow_load_public_objects(",
        "shadow_load_confidential_objects(",
        "enable_injected_path_oram_leaf_coins(",
        "install_path_oram_leaf_coins(",
        "ensure_path_oram_leaf_coins_consumed(",
        "path_oram_position_map_witness(",
        "path_oram_access_counter_witness(",
        "into_cold_committed(",
        "committed_cache_is_cold(",
        "cold_store_object(",
        "post_committed_cold_object(",
    ];
    let forbidden_engine_helper_checks = forbidden_engine_helpers
        .into_iter()
        .map(|helper| {
            json!({
                "helper": helper,
                "present_in_engine_impl": engine_impl_source.contains(helper),
            })
        })
        .collect::<Vec<_>>();
    let engine_forbidden_helpers_absent = forbidden_engine_helper_checks.iter().all(|entry| {
        !entry["present_in_engine_impl"]
            .as_bool()
            .expect("helper presence must be boolean")
    });
    let engine_uses_opaque_committed_state = engine_impl_source.contains("state: ContractRuntime")
        && !engine_impl_source.contains("state: CommittedRuntimeState");
    let engine_uses_runtime_public_object_universe = !engine_impl_source
        .contains(".ensure_ready_for_call(")
        && !engine_impl_source.contains("let public_object_ids = self.state.public_object_ids();")
        && !engine_impl_source.contains("canonical_runtime_public_object_ids(")
        && theorem_source.contains("runtime.begin_traced_call(")
        && state_source.contains("fn public_object_ids(&self) -> Vec<u32>")
        && state_source.contains(
            "pub(in crate::runtime) fn begin_traced_call(\n        &self,\n        entrypoint: &str,\n        manifest_entry: &EntrypointManifest,\n        args: &[Value],\n    ) -> Result<(",
        )
        && state_source.contains("fn ensure_ready_for_call(&self, context: &str) -> Result<()>")
        && !state_source
            .contains("pub(crate) fn ensure_ready_for_call(&self, context: &str) -> Result<()>");
    let engine_delegates_public_execution_to_runtime_theorem_bridge = engine_impl_source
        .contains("run_contract_call(")
        && engine_impl_source.contains("use crate::runtime::{")
        && !engine_impl_source.contains("use crate::runtime::theorem::run_traced_call;")
        && !engine_impl_source.contains("run_traced_call(")
        && !engine_impl_source.contains("use crate::runtime::shell::run_public_entrypoint;")
        && !engine_impl_source.contains("run_public_entrypoint(")
        && !engine_impl_source.contains("AllocatorPlan::from_manifest(")
        && runtime_module_source.contains("pub(crate) fn run_contract_call(")
        && runtime_module_source.contains("theorem::run_traced_call(")
        && shell_source.contains("AllocatorPlan::from_manifest(manifest_entry)")
        && !engine_impl_source.contains("fn exec_block(")
        && !engine_impl_source.contains("fn exec_statement(")
        && !engine_impl_source.contains("fn eval_expr(")
        && !engine_impl_source.contains("fn eval_binary(")
        && !engine_impl_source.contains("fn store_env_value(");
    let engine_delegates_confidential_execution_to_runtime_theorem_bridge = engine_impl_source
        .contains("run_contract_call(")
        && !engine_impl_source.contains("run_traced_call(")
        && !engine_impl_source.contains("run_confidential_entrypoint(")
        && !engine_impl_source.contains("prepare_confidential_entrypoint(")
        && theorem_source.contains("runtime.run_confidential_entrypoint(")
        && runtime_module_source.contains("theorem::run_traced_call(")
        && !engine_impl_source.contains("PublicRuntimeKernel::begin(");
    let engine_confidential_manifest_surface_absent = !engine_impl_source
        .contains(".confidential_slot_program")
        && !engine_impl_source.contains("RuntimeKernelStepWitness")
        && !engine_impl_source.contains("expected_runtime_steps()")
        && !engine_impl_source.contains("max_hash_part_bytes")
        && !engine_impl_source.contains("kernel_steps")
        && !engine_impl_source.contains("max_commit_ops");
    let engine_does_not_import_public_runtime_kernel = !engine_impl_source
        .contains("use crate::runtime::kernel::PublicRuntimeKernel;")
        && !engine_impl_source.contains("PublicRuntimeKernel::begin(");
    let shell_uses_shadow_wrapper =
        shell_impl_source.contains("objects: &mut PublicRuntimeShadowState");
    let shell_uses_public_runtime_kernel =
        shell_source.contains("use crate::runtime::kernel::PublicRuntimeKernel;");
    let public_shell_is_runtime_owned = runtime_evm_lib_source.contains("mod runtime;")
        && !runtime_evm_lib_source.contains("mod shell;")
        && theorem_source.contains("use crate::runtime::shell::run_public_entrypoint;");
    let theorem_bridge_is_runtime_owned = runtime_evm_lib_source.contains("mod runtime;")
        && !runtime_evm_lib_source.contains("mod theorem;")
        && runtime_module_source.contains("mod theorem;")
        && runtime_module_source.contains("pub(crate) fn run_contract_call(")
        && !runtime_module_source.contains("pub(crate) mod theorem;");
    let state_uses_public_runtime_kernel = state_source
        .contains("use crate::runtime::kernel::PublicRuntimeKernel;")
        && state_source.contains("PublicRuntimeKernel::begin(");
    let shell_confidential_surface_absent = !shell_impl_source.contains("ConfidentialCallInputs")
        && !shell_impl_source.contains("use crate::runtime::kernel::RuntimeKernel;")
        && !shell_impl_source.contains("use crate::runtime::objects::RuntimeObject;")
        && !shell_impl_source.contains("RuntimeKernelRefinementEventWitness")
        && !shell_impl_source.contains("RuntimeTrustedKernelBundle")
        && !shell_impl_source.contains("ConfidentialKernelSlotProgram");
    let engine_defines_fresh_coin_plan_directly = engine_source
        .contains("pub struct PathOramFreshCoinPlan")
        || engine_source.contains("struct PathOramFreshCoinPlan");
    let engine_uses_manifest_public_call_summary = !engine_impl_source
        .contains("PublicCallSummary::from_manifest_entry")
        && !theorem_source.contains("PublicCallSummary::from_manifest_entry")
        && state_source.contains("PublicCallSummary::from_manifest_entry");
    let engine_keeps_confidential_call_inputs_inside_runtime = !engine_impl_source
        .contains("ConfidentialCallInputs::from_manifest_entry")
        && theorem_source.contains("runtime.run_confidential_entrypoint(")
        && !state_source.contains("ConfidentialCallInputs")
        && kernel_source
            .contains("let call_inputs = ConfidentialCallInputs::from_raw_args(raw_args);")
        && kernel_source.contains("call_inputs.into_raw_args().into_iter()");
    let engine_clones_call_args_directly = engine_impl_source
        .contains("let mut call_args = args.clone();")
        || engine_impl_source.contains("let call_args = args.clone();");
    let engine_fresh_coin_api_consumes_plan = engine_source
        .contains("fresh_coins: PathOramFreshCoinPlan")
        && !engine_source.contains("fresh_coins: &PathOramFreshCoinPlan");
    let engine_peeks_into_fresh_coin_map = engine_impl_source.contains(".by_object")
        || engine_impl_source.contains("fresh_coins_by_object");
    let engine_imports_raw_runtime_kernel =
        engine_impl_source.contains("use crate::runtime::kernel::RuntimeKernel;");
    let engine_imports_runtime_object_directly =
        engine_impl_source.contains("use crate::runtime::objects::RuntimeObject;");
    let engine_constructs_runtime_phase_events_directly =
        engine_impl_source.contains("RuntimeKernelRefinementEventWitness");
    let engine_constructs_theorem_certificates_directly = [
        "RuntimeControllerObserverCertificate",
        "RuntimePathOramHiddenCertificate",
        "RuntimeTrustedKernelBundle",
    ]
    .into_iter()
    .any(|needle| engine_impl_source.contains(needle));
    let engine_assembles_execution_trace_directly = engine_impl_source.contains("ExecutionTrace {");
    let engine_owns_raw_runtime_object_map =
        engine_impl_source.contains("BTreeMap<u32, RuntimeObject>");
    let collect_runtime_store_pattern_hits = |pattern: &str| -> Result<Vec<String>> {
        let mut files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        files.extend(collect_production_pattern_hits(&store_src, pattern)?);
        files.sort();
        files.dedup();
        Ok(files)
    };

    let runtime_restricted_signatures = [
        "pub(in crate::runtime) fn clone_for_tx",
        "pub(in crate::runtime) fn clone_committed_cold",
        "pub(in crate::runtime) fn path_oram_position_map_witness",
        "pub(in crate::runtime) fn path_oram_access_counter_witness",
        "pub(in crate::runtime) fn get_cell",
        "pub(in crate::runtime) fn set_cell",
        "pub(in crate::runtime) fn get_array",
        "pub(in crate::runtime) fn set_array",
        "pub(in crate::runtime) fn get_map",
        "pub(in crate::runtime) fn put_map",
        "pub(in crate::runtime) fn commit",
        "pub(in crate::runtime) fn into_cold_committed",
        "pub(in crate::runtime) fn committed_cache_is_cold",
        "pub(in crate::runtime) fn enable_injected_path_oram_leaf_coins",
        "pub(in crate::runtime) fn install_path_oram_leaf_coins",
        "pub(in crate::runtime) fn ensure_path_oram_leaf_coins_consumed",
    ];
    let restricted_signature_checks = runtime_restricted_signatures
        .into_iter()
        .map(|signature| {
            json!({
                "signature": signature,
                "present": objects_source.contains(signature),
            })
        })
        .collect::<Vec<_>>();
    let all_restricted_signatures_present = restricted_signature_checks.iter().all(|entry| {
        entry["present"]
            .as_bool()
            .expect("signature presence must be boolean")
    });

    let runtime_object_decl = "pub(crate) enum RuntimeObject";
    let runtime_object_derive_line = objects_source
        .split(runtime_object_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate RuntimeObject declaration in objects.rs"))?;
    let runtime_object_nonclone = !runtime_object_derive_line.contains("Clone");
    let oram_state_decl = "pub(crate) struct OramState";
    let oram_state_derive_line = oram_source
        .split(oram_state_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate OramState declaration in oram.rs"))?;
    let oram_state_nonderive_clone = !oram_state_derive_line.contains("Clone");
    let fresh_coin_plan_decl = "pub struct PathOramFreshCoinPlan";
    let fresh_coin_plan_derive_line = fresh_coins_source
        .split(fresh_coin_plan_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate PathOramFreshCoinPlan declaration"))?;
    let fresh_coin_plan_nonclone = !fresh_coin_plan_derive_line.contains("Clone");
    let contract_instance_clone_uses_cold_runtime_clone =
        engine_source.contains("state: self.state.clone()");
    let fresh_coin_plan_surface_checks = [
        (
            "pub struct PathOramFreshCoinPlan",
            vec![String::from("runtime/uo-evm/src/fresh_coins.rs")],
        ),
        (
            "impl Drop for PathOramFreshCoinPlan",
            vec![String::from("runtime/uo-evm/src/fresh_coins.rs")],
        ),
        (
            "pub fn from_scaffold_and_values(",
            vec![String::from("runtime/uo-evm/src/fresh_coins.rs")],
        ),
        (
            "pub(in crate::runtime) fn into_by_object(mut self)",
            vec![String::from("runtime/uo-evm/src/fresh_coins.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let fresh_coin_plan_surface_restricted = fresh_coin_plan_surface_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("fresh-coin surface restriction flag must be boolean")
    });
    let fresh_coin_plan_zeroizes_on_drop = fresh_coins_source
        .contains("impl Drop for PathOramFreshCoinPlan")
        && fresh_coins_source.contains("*coin = 0;");
    let state_wrapper_present = state_source.contains("pub(crate) struct ContractRuntime")
        && state_source.contains("pub(in crate::runtime) struct CommittedRuntimeState")
        && state_source.contains("pub(in crate::runtime) struct RuntimeShadowState")
        && state_source.contains("pub(in crate::runtime) struct ConfidentialRuntimeShadowState")
        && state_source.contains("pub(in crate::runtime) struct PublicRuntimeShadowState");
    let kernel_restricted_signatures = [
        "pub(in crate::runtime) fn begin(",
        "pub(in crate::runtime) fn note_hash_bytes",
        "pub(in crate::runtime) fn enforce_stack_words",
        "pub(in crate::runtime) fn wipe_hash_scratch",
        "pub(in crate::runtime) fn cell_get(",
        "pub(in crate::runtime) fn cell_set(",
        "pub(in crate::runtime) fn array_get(",
        "pub(in crate::runtime) fn array_set(",
        "pub(in crate::runtime) fn map_get(",
        "pub(in crate::runtime) fn map_put(",
        "pub(in crate::runtime) fn finish(",
        "pub(in crate::runtime) fn shadow_load_public_objects",
        "pub(in crate::runtime) fn commit_public_objects",
        "pub(in crate::runtime) fn run_confidential_call",
    ];
    let kernel_restricted_signature_checks = kernel_restricted_signatures
        .into_iter()
        .map(|signature| {
            json!({
                "signature": signature,
                "present": kernel_source.contains(signature),
            })
        })
        .collect::<Vec<_>>();
    let all_kernel_restricted_signatures_present =
        kernel_restricted_signature_checks.iter().all(|entry| {
            entry["present"]
                .as_bool()
                .expect("kernel signature presence must be boolean")
        });
    let kernel_avoids_raw_escape_hatches = !kernel_source
        .contains("pub(in crate::runtime) fn inner_mut")
        && !kernel_source.contains("pub(in crate::runtime) fn into_inner");
    let public_kernel_facade_restricted_to_runtime = kernel_source
        .contains("pub(in crate::runtime) struct PublicRuntimeKernel {")
        && !kernel_source.contains("pub(crate) struct PublicRuntimeKernel {")
        && !kernel_source.contains("pub(crate) fn begin(plan: AllocatorPlan")
        && !kernel_source.contains("pub(crate) fn note_hash_bytes(")
        && !kernel_source.contains("pub(crate) fn enforce_stack_words(")
        && !kernel_source.contains("pub(crate) fn wipe_hash_scratch(")
        && !kernel_source.contains("pub(crate) fn cell_get(")
        && !kernel_source.contains("pub(crate) fn cell_set(")
        && !kernel_source.contains("pub(crate) fn array_get(")
        && !kernel_source.contains("pub(crate) fn array_set(")
        && !kernel_source.contains("pub(crate) fn map_get(")
        && !kernel_source.contains("pub(crate) fn map_put(")
        && !kernel_source.contains("pub(crate) fn finish(");
    let kernel_confidential_shadow_load_private = kernel_source
        .contains("fn shadow_load_confidential_objects(")
        && !kernel_source.contains("pub(in crate::runtime) fn shadow_load_confidential_objects(")
        && !kernel_source.contains("pub(crate) fn shadow_load_confidential_objects(");
    let raw_kernel_private_surface_checks = [
        (
            "struct RuntimeKernel {",
            "pub(crate) struct RuntimeKernel {",
        ),
        (
            "struct ConfidentialExecutionOutcome {",
            "pub(crate) struct ConfidentialExecutionOutcome {",
        ),
        (
            "fn record_shadow_load_object(",
            "pub(crate) fn record_shadow_load_object(",
        ),
        ("fn cell_get_public(", "pub(crate) fn cell_get_public("),
        ("fn cell_set_public(", "pub(crate) fn cell_set_public("),
        ("fn array_get_public(", "pub(crate) fn array_get_public("),
        ("fn array_set_public(", "pub(crate) fn array_set_public("),
        ("fn map_get_public(", "pub(crate) fn map_get_public("),
        ("fn map_put_public(", "pub(crate) fn map_put_public("),
        ("fn commit_objects(", "pub(crate) fn commit_objects("),
        (
            "fn execute_confidential_call(",
            "pub(crate) fn execute_confidential_call(",
        ),
    ]
    .into_iter()
    .map(|(required_private, forbidden_pubcrate)| {
        let private_present = kernel_source.contains(required_private);
        let forbidden_present = kernel_source.contains(forbidden_pubcrate);
        json!({
            "required_private": required_private,
            "forbidden_pubcrate": forbidden_pubcrate,
            "private_present": private_present,
            "forbidden_present": forbidden_present,
            "restricted": private_present && !forbidden_present,
        })
    })
    .collect::<Vec<_>>();
    let raw_kernel_private_surface_restricted =
        raw_kernel_private_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("raw-kernel private surface restriction flag must be boolean")
        });
    let state_restricted_signatures = [
        "pub(in crate::runtime) fn objects",
        "pub(in crate::runtime) fn shadow_load",
        "pub(in crate::runtime) fn from_shadow(shadow: RuntimeShadowState) -> Self",
        "pub(in crate::runtime) fn object_mut",
        "pub(in crate::runtime) fn enable_injected_path_oram_leaf_coins",
        "pub(in crate::runtime) fn install_path_oram_leaf_coins",
        "pub(in crate::runtime) fn ensure_path_oram_leaf_coins_consumed",
        "pub(in crate::runtime) fn commit_against",
        "pub(in crate::runtime) fn into_cold_committed_state",
        "pub(in crate::runtime) fn prepare_public_shadow(",
        "pub(in crate::runtime) fn commit_public_shadow(",
        "pub(in crate::runtime) fn replace_with_cold_public_shadow(",
        "pub(in crate::runtime) fn finalize_runtime_kernel_refinement_witness(",
    ];
    let state_restricted_signature_checks = state_restricted_signatures
        .into_iter()
        .map(|signature| {
            json!({
                "signature": signature,
                "present": state_source.contains(signature),
            })
        })
        .collect::<Vec<_>>();
    let all_state_restricted_signatures_present =
        state_restricted_signature_checks.iter().all(|entry| {
            entry["present"]
                .as_bool()
                .expect("state signature presence must be boolean")
        });
    let state_finalizes_runtime_phase_witness = state_source
        .contains("fn finalize_runtime_kernel_refinement_witness")
        && state_source.contains(
            "runtime_kernel_refinement_witness.append_cold_store_window(public_object_ids)?;",
        )
        && !state_source.contains("RuntimeKernelRefinementEventWitness::cold_store_object")
        && !state_source
            .contains("RuntimeKernelRefinementEventWitness::post_committed_cold_object");
    let state_committed_runtime_witness_snapshot_is_opaque = state_source
        .contains("struct CommittedRuntimeWitnessSnapshot")
        && !state_source.contains("pub(crate) struct CommittedRuntimeWitnessSnapshot")
        && !state_source.contains("pub runtime_oram_access_counters:")
        && !state_source.contains("pub runtime_oram_position_maps:")
        && state_source.contains("fn into_hidden_oram_state(")
        && !state_source.contains("pub(crate) fn into_hidden_oram_state(")
        && !theorem_source.contains(".into_hidden_oram_state()");
    let theorem_only_runtime_helper_visibility_restricted = state_source
        .contains(
            "pub(in crate::runtime) fn begin_traced_call(\n        &self,\n        entrypoint: &str,\n        manifest_entry: &EntrypointManifest,\n        args: &[Value],\n    ) -> Result<(TracedRuntimeCallStart, PublicCallSummary, CallRecorder)>",
        )
        && state_source.contains(
            "pub(in crate::runtime) fn finish_traced_call(\n        &self,\n        call_outcome: RuntimeCallOutcome,\n    ) -> Result<TracedRuntimeCallOutcome>",
        )
        && state_source.contains("pub(in crate::runtime) struct TracedRuntimeCallStart {")
        && state_source.contains("pub(in crate::runtime) struct TracedRuntimeCallWitnessState {")
        && state_source.contains("pub(in crate::runtime) fn into_finalized_call_trace_parts(")
        && state_source.contains("pub(in crate::runtime) fn into_execution_trace_parts(")
        && state_source.contains("fn ensure_ready_for_call(&self, context: &str) -> Result<()>")
        && state_source.contains(
            "fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {\n        self.committed.witness_snapshot()\n    }",
        )
        && state_source.contains("fn into_hidden_oram_state(")
        && state_source.contains(
            "fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {\n        let mut runtime_oram_position_maps = Vec::with_capacity(self.objects.len());",
        )
        && !state_source
            .contains("pub fn ensure_ready_for_call(&self, context: &str) -> Result<()>")
        && !state_source
            .contains("pub(crate) fn ensure_ready_for_call(&self, context: &str) -> Result<()>")
        && !state_source
            .contains("pub fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot>")
        && !state_source
            .contains("pub(crate) fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot>")
        && !state_source
            .contains("pub fn finish_traced_call(\n        &self,\n        call_outcome: RuntimeCallOutcome,\n    ) -> Result<TracedRuntimeCallOutcome>")
        && !state_source.contains("pub fn into_hidden_oram_state(")
        && !state_source.contains("pub(crate) fn into_hidden_oram_state(")
        && !state_source.contains(
            "pub(crate) fn witness_snapshot(&self) -> Result<CommittedRuntimeWitnessSnapshot> {\n        let mut runtime_oram_position_maps = Vec::with_capacity(self.objects.len());",
        );
    let committed_runtime_witness_snapshot_decl = "struct CommittedRuntimeWitnessSnapshot";
    let committed_runtime_witness_snapshot_derive_line = state_source
        .split(committed_runtime_witness_snapshot_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate CommittedRuntimeWitnessSnapshot declaration"))?;
    let committed_runtime_witness_snapshot_nonclone =
        !committed_runtime_witness_snapshot_derive_line.contains("Clone");
    let committed_runtime_witness_snapshot_wipes_on_drop = state_source
        .contains("impl Drop for CommittedRuntimeWitnessSnapshot")
        && state_source
            .contains("wipe_runtime_oram_access_counters(&mut self.runtime_oram_access_counters);")
        && state_source
            .contains("wipe_runtime_oram_position_maps(&mut self.runtime_oram_position_maps);");
    let committed_runtime_witness_snapshot_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "CommittedRuntimeWitnessSnapshot")?;
    let expected_committed_runtime_witness_snapshot_surface_files =
        vec![String::from("runtime/uo-evm/src/state.rs")];
    let committed_runtime_witness_snapshot_surface_restricted =
        committed_runtime_witness_snapshot_surface_files
            == expected_committed_runtime_witness_snapshot_surface_files;
    let engine_leaves_runtime_phase_tail_inside_runtime = !engine_impl_source
        .contains("finalize_runtime_kernel_refinement_witness(")
        && shell_source.contains("runtime.finalize_runtime_kernel_refinement_witness(")
        && state_source.contains("self.finalize_runtime_kernel_refinement_witness(");
    let kernel_confidential_call_inputs_wrapper_restricted = kernel_source
        .contains("struct ConfidentialCallInputs")
        && kernel_source.contains("raw_args: Vec<Value>")
        && kernel_source.contains("fn from_raw_args(args: Vec<Value>) -> Self")
        && kernel_source.contains("fn into_raw_args(mut self) -> Vec<Value>")
        && kernel_source.contains("std::mem::take(&mut self.raw_args)")
        && !kernel_source.contains("pub(crate) struct ConfidentialCallInputs")
        && !kernel_source.contains("pub(in crate::runtime) struct ConfidentialCallInputs")
        && !kernel_source.contains("pub(crate) fn into_raw_args(self) -> Vec<Value>")
        && !kernel_source.contains("pub(crate) fn into_raw_args(mut self) -> Vec<Value>")
        && !kernel_source.contains("pub(crate) fn from_manifest_entry(");
    let confidential_call_inputs_wipe_on_drop = kernel_source
        .contains("impl Drop for ConfidentialCallInputs")
        && kernel_source.contains("for value in self.raw_args.iter_mut() {")
        && kernel_source.contains("value.wipe_secrets();");
    let theorem_finalizes_execution_trace = theorem_source.contains("fn finalize_call_trace(")
        && theorem_source.contains("fn begin_call_trace(")
        && theorem_source.contains("pub(in crate::runtime) fn run_traced_call(")
        && theorem_source.contains("let mut context = begin_call_trace(")
        && theorem_source.contains("runtime.run_confidential_entrypoint(")
        && theorem_source.contains("run_public_entrypoint(")
        && theorem_source.contains("runtime.begin_traced_call(")
        && theorem_source.contains("runtime.finish_traced_call(call_outcome)?;")
        && !theorem_source.contains("runtime.witness_snapshot()?;")
        && !theorem_source.contains("CallRecorder::begin_with_input_len(")
        && theorem_source.contains("fn finalize_execution_trace")
        && theorem_source.contains("ExecutionTrace::from_runtime_trace_parts(")
        && theorem_source.contains("trace.materialize_runtime_trusted_kernel_bundle()?;")
        && !theorem_source.contains("ExecutionTrace {")
        && !theorem_source.contains("RuntimeControllerObserverCertificate::new(")
        && !theorem_source.contains("RuntimePathOramHiddenCertificate::new(")
        && !theorem_source.contains("RuntimeTrustedKernelBundle::new_with_kernel_witness(")
        && theorem_source
            .contains("traced_outcome.into_finalized_call_trace_parts(runtime_call_start)")
        && theorem_source.contains("runtime_witness_state.into_execution_trace_parts()")
        && !theorem_source.contains("call_outcome.into_theorem_trace_parts()")
        && !theorem_source.contains(".into_hidden_oram_state()")
        && !theorem_source.contains("let RuntimeCallOutcome {")
        && theorem_source
            .contains("let output_shape = output_shape_of(manifest_entry, &return_value)?;");
    let theorem_private_surface_checks = [
        (
            "struct CallTraceContext {",
            "pub(crate) struct CallTraceContext {",
        ),
        (
            "struct FinalizeExecutionTraceInput<'a> {",
            "pub(crate) struct FinalizeExecutionTraceInput<'a> {",
        ),
        (
            "struct FinalizeCallTraceInput<'a> {",
            "pub(crate) struct FinalizeCallTraceInput<'a> {",
        ),
        ("fn begin_call_trace(", "pub(crate) fn begin_call_trace("),
        (
            "fn finalize_call_trace(",
            "pub(crate) fn finalize_call_trace(",
        ),
        (
            "fn recorder_mut(&mut self)",
            "pub(crate) fn recorder_mut(&mut self)",
        ),
    ]
    .into_iter()
    .map(|(required_private, forbidden_pubcrate)| {
        let private_present = theorem_source.contains(required_private);
        let forbidden_present = theorem_source.contains(forbidden_pubcrate);
        json!({
            "required_private": required_private,
            "forbidden_pubcrate": forbidden_pubcrate,
            "private_present": private_present,
            "forbidden_present": forbidden_present,
            "restricted": private_present && !forbidden_present,
        })
    })
    .collect::<Vec<_>>();
    let theorem_private_surface_restricted = theorem_private_surface_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("theorem private-surface restriction flag must be boolean")
    });
    let theorem_finalize_input_fields_private = theorem_source
        .contains("artifact: &'a CompiledArtifact")
        && theorem_source.contains("entrypoint: &'a str")
        && theorem_source.contains("confidential: bool")
        && theorem_source.contains("deploy_seed: u64")
        && theorem_source.contains("opcode_trace: Vec<String>")
        && theorem_source.contains("gas_used: u64")
        && theorem_source.contains("trace_bundle: crate::controller::CallTraceBundle")
        && theorem_source.contains("runtime_kernel_witness: RuntimeKernelWitness")
        && theorem_source
            .contains("runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness")
        && theorem_source.contains("runtime_witness_state: TracedRuntimeCallWitnessState")
        && theorem_source.contains("context: CallTraceContext")
        && theorem_source.contains("manifest_entry: &'a EntrypointManifest")
        && theorem_source.contains("manifest_objects: &'a [StateObjectManifest]")
        && theorem_source.contains("traced_outcome: TracedRuntimeCallOutcome")
        && !theorem_source.contains("pub artifact: &'a CompiledArtifact")
        && !theorem_source.contains("pub entrypoint: &'a str")
        && !theorem_source.contains("pub confidential: bool")
        && !theorem_source.contains("pub deploy_seed: u64")
        && !theorem_source.contains("pub opcode_trace: Vec<String>")
        && !theorem_source.contains("pub gas_used: u64")
        && !theorem_source.contains("pub trace_bundle: crate::controller::CallTraceBundle")
        && !theorem_source.contains("pub runtime_kernel_witness: RuntimeKernelWitness")
        && !theorem_source
            .contains("pub runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness")
        && !theorem_source.contains("pub runtime_witness_state: TracedRuntimeCallWitnessState")
        && !theorem_source.contains("pub context: CallTraceContext")
        && !theorem_source.contains("pub manifest_entry: &'a EntrypointManifest")
        && !theorem_source.contains("pub manifest_objects: &'a [StateObjectManifest]")
        && !theorem_source.contains("pub traced_outcome: TracedRuntimeCallOutcome");
    let theorem_certificate_constructor_checks = [
        (
            "RuntimeControllerObserverCertificate::new(",
            Vec::<String>::new(),
        ),
        (
            "RuntimePathOramHiddenCertificate::new(",
            Vec::<String>::new(),
        ),
        (
            "RuntimeTrustedKernelBundle::new_with_kernel_witness(",
            Vec::<String>::new(),
        ),
        (
            "ExecutionTrace::from_runtime_trace_parts(",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
        (
            "ExecutionTrace::materialize_runtime_trusted_kernel_bundle(",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let theorem_certificate_constructor_surface_restricted =
        theorem_certificate_constructor_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("theorem certificate constructor restriction flag must be boolean")
        });
    let call_trace_bundle_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "CallTraceBundle")?;
    let expected_call_trace_bundle_surface_files = vec![
        String::from("runtime/uo-evm/src/controller.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let call_trace_bundle_surface_restricted =
        call_trace_bundle_surface_files == expected_call_trace_bundle_surface_files;
    let call_trace_bundle_fields_private = controller_source
        .contains("logical_accesses: Vec<LogicalEvent>")
        && controller_source.contains("logical_writes: Vec<LogicalEvent>")
        && controller_source.contains("physical_reads: Vec<PhysicalReadEvent>")
        && controller_source.contains("physical_writes: Vec<PhysicalWriteEvent>")
        && controller_source.contains("metrics: StoreExecutionMetrics")
        && controller_source.contains("theorem_trace: TheoremTrace")
        && controller_source.contains("controller_certificate: RuntimeControllerCertificate")
        && controller_source.contains("oram_leaf_schedule: Vec<RuntimeOramLeafWitness>")
        && controller_source
            .contains("oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>")
        && !controller_source.contains("pub logical_accesses: Vec<LogicalEvent>")
        && !controller_source.contains("pub logical_writes: Vec<LogicalEvent>")
        && !controller_source.contains("pub physical_reads: Vec<PhysicalReadEvent>")
        && !controller_source.contains("pub physical_writes: Vec<PhysicalWriteEvent>")
        && !controller_source.contains("pub metrics: StoreExecutionMetrics")
        && !controller_source.contains("pub theorem_trace: TheoremTrace")
        && !controller_source.contains("pub controller_certificate: RuntimeControllerCertificate")
        && !controller_source.contains("pub oram_leaf_schedule: Vec<RuntimeOramLeafWitness>")
        && !controller_source
            .contains("pub oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>");
    let call_trace_bundle_api_is_explicit = controller_source
        .contains("pub(crate) fn zero_writes(&self)")
        && controller_source.contains("pub(crate) fn into_execution_trace_parts(")
        && theorem_source.contains("let zero_writes = trace_bundle.zero_writes();")
        && theorem_source.contains(") = trace_bundle.into_execution_trace_parts();");
    let controller_theorem_trace_constructor_files =
        collect_production_pattern_hits(&runtime_evm_src, "TheoremTrace {")?;
    let expected_controller_theorem_trace_constructor_files =
        vec![String::from("runtime/uo-evm/src/controller.rs")];
    let controller_theorem_trace_constructor_surface_restricted =
        controller_theorem_trace_constructor_files
            == expected_controller_theorem_trace_constructor_files;
    let public_trace_helper_surface_checks = [
        (
            "PublicCallSummary::from_manifest_entry(",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "CallRecorder::begin_with_input_len(",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "output_shape_of(",
            vec![
                String::from("runtime/uo-evm/src/controller.rs"),
                String::from("runtime/uo-evm/src/theorem.rs"),
            ],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let public_trace_helper_surface_restricted =
        public_trace_helper_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("public trace helper restriction flag must be boolean")
        });
    let controller_public_call_summary_uses_manifest_only = controller_source
        .contains("fn from_manifest_entry")
        && controller_source.contains("manifest_entry.param_names")
        && controller_source.contains("entry_input_len: manifest_entry.entry_input_len")
        && !controller_source
            .contains("entry_input_len: args.iter().map(Value::canonical_len).sum(),")
        && !controller_source.contains("CompiledFunction");
    let public_call_summary_fields_private = controller_source.contains("entry_input_len: usize")
        && controller_source.contains("public_args: Vec<String>")
        && !controller_source.contains("pub entry_input_len: usize")
        && !controller_source.contains("pub public_args: Vec<String>");
    let public_call_summary_api_is_explicit = controller_source
        .contains("pub(crate) fn entry_input_len(&self)")
        && controller_source.contains("pub(crate) fn into_public_args(self)")
        && state_source.contains("public_call.entry_input_len()")
        && controller_source.contains("let entry_input_len = public_call.entry_input_len();")
        && controller_source.contains("public_args: public_call.into_public_args(),");
    let controller_public_trace_uses_output_shape_only = controller_source
        .contains("public_call: PublicCallSummary,\n        output_shape: OutputShape,")
        && !controller_source
            .contains("public_call: PublicCallSummary,\n        return_value: &Option<Value>,");
    let controller_output_shape_uses_manifest_return_len = controller_source
        .contains("return_length: manifest_entry.return_canonical_len")
        && !controller_source.contains("return_length: value.canonical_len(),");
    let theorem_public_trace_path_avoids_compiled_function =
        !theorem_source.contains("CompiledFunction");
    let theorem_trace_bridge_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "run_traced_call")?;
    let expected_theorem_trace_bridge_surface_files = vec![
        String::from("runtime/uo-evm/src/runtime.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let theorem_trace_bridge_surface_restricted =
        theorem_trace_bridge_surface_files == expected_theorem_trace_bridge_surface_files;
    let theorem_trace_bridge_api_is_compact = !engine_impl_source.contains("RunContractCallInput")
        && !runtime_module_source.contains("struct RunContractCallInput")
        && !theorem_source.contains("struct RunTracedCallInput");
    let finalized_call_trace_fields_private = !theorem_source.contains("struct FinalizedCallTrace")
        && !theorem_source.contains("pub(crate) struct FinalizedCallTrace")
        && !theorem_source.contains("pub(in crate::runtime) struct FinalizedCallTrace");
    let finalized_call_trace_api_is_explicit = runtime_module_source
        .contains("pub(crate) fn run_contract_call(")
        && runtime_module_source
            .contains("-> Result<(Option<Value>, bool, ExecutionTrace, usize)> {")
        && engine_impl_source
            .contains("let (return_value, aborted, trace, zero_writes) = run_contract_call(")
        && !engine_impl_source.contains("finalized.into_engine_result_parts()")
        && !theorem_source.contains("into_engine_result_parts(");
    let finalized_call_trace_consumption_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "into_engine_result_parts(")?;
    let expected_finalized_call_trace_consumption_surface_files = Vec::<String>::new();
    let finalized_call_trace_consumption_surface_restricted =
        finalized_call_trace_consumption_surface_files
            == expected_finalized_call_trace_consumption_surface_files;
    let engine_public_trace_uses_output_shape_only = engine_impl_source
        .contains("let (return_value, aborted, trace, zero_writes) = run_contract_call(")
        && theorem_trace_bridge_api_is_compact
        && theorem_private_surface_restricted
        && finalized_call_trace_fields_private
        && finalized_call_trace_api_is_explicit
        && finalized_call_trace_consumption_surface_restricted
        && !engine_impl_source.contains("let mut call_trace_context =")
        && !engine_impl_source.contains("begin_call_trace(")
        && !engine_impl_source.contains("finalize_call_trace(")
        && !engine_impl_source.contains("FinalizeCallTraceInput")
        && !engine_impl_source.contains("CallTraceContext")
        && !engine_impl_source.contains("recorder_mut()")
        && !engine_impl_source.contains("output_shape_of(")
        && !engine_impl_source.contains("build_theorem_trace(")
        && !engine_impl_source.contains("finalize_execution_trace(")
        && !engine_impl_source.contains("witness_snapshot()")
        && !engine_impl_source.contains("CallRecorder::begin_with_input_len(")
        && !engine_impl_source.contains("runtime_kernel_witness,")
        && !engine_impl_source.contains("runtime_kernel_refinement_witness,")
        && !engine_impl_source.contains("opcode_trace,");
    let state_prepares_confidential_manifest_plan = state_source
        .contains("struct ConfidentialEntrypointPlan")
        && state_source.contains("ConfidentialEntrypointPlan::from_manifest_entry(")
        && !state_source.contains("pub(crate) fn prepare_confidential_entrypoint(")
        && state_source.contains("AllocatorPlan::from_manifest(manifest_entry)")
        && state_source.contains(".confidential_slot_program")
        && state_source.contains(".kernel_step_witnesses()")
        && state_source.contains(".expected_runtime_step_witnesses()")
        && !state_source.contains("RuntimeKernelStepWitness {")
        && state_source.contains("max_commit_ops: manifest_entry.max_commit_ops")
        && state_source.contains("max_hash_part_bytes: manifest_entry.max_hash_part_bytes");
    let confidential_entrypoint_plan_surface_restricted =
        collect_production_pattern_hits(&runtime_evm_src, "ConfidentialEntrypointPlan")?
            == vec![String::from("runtime/uo-evm/src/state.rs")];
    let kernel_executes_program_body_via_shared_dsl =
        kernel_source.contains("self.exec_confidential_block(&program.body");
    let kernel_confidential_call_inputs_stay_inside_runtime = kernel_source
        .contains("raw_args: Vec<Value>")
        && kernel_source
            .contains("let call_inputs = ConfidentialCallInputs::from_raw_args(raw_args);")
        && kernel_source.contains("call_inputs: ConfidentialCallInputs")
        && kernel_source.contains("call_inputs.into_raw_args().into_iter()");
    let kernel_exec_block_uses_confidential_slot_statements = kernel_source
        .contains("statements: &[ConfidentialKernelSlotStatement]")
        && kernel_source.contains("statement: &ConfidentialKernelSlotStatement");
    let kernel_eval_uses_confidential_slot_exprs = kernel_source
        .contains("expr: &ConfidentialKernelSlotExpr")
        && kernel_source.contains("expr: &ConfidentialKernelSlotPureExpr");
    let kernel_exec_state_uses_slot_vector = kernel_source.contains("slots: Vec<Option<Value>>")
        && kernel_source.contains("initialized_slots: usize");
    let kernel_exec_state_avoids_name_keyed_env =
        !kernel_source.contains("env: BTreeMap<String, Value>");
    let kernel_scratch_accounting_uses_object_type_lengths = kernel_source
        .contains("value_canonical_len()")
        && kernel_source.contains("key_canonical_len()")
        && !kernel_source.contains("touch_value_scratch(value.canonical_len())?")
        && !kernel_source.contains("touch_value_scratch(key.canonical_len())?")
        && !kernel_source
            .contains("touch_value_scratch(key.canonical_len().max(value.canonical_len()))?");
    let object_commit_io_scratch_uses_type_lengths = objects_source
        .contains("next.spec.value_type.canonical_len()")
        && objects_source.contains("map_record_len(&next.spec)?")
        && !objects_source
            .contains("reserve_guard(ScratchRegion::IoScratch, committed_value.canonical_len())")
        && !objects_source
            .contains("reserve_guard(ScratchRegion::IoScratch, value.canonical_len())");
    let kernel_hash_scratch_uses_public_program_bound = kernel_source
        .contains("max_hash_part_bytes: usize")
        && kernel_source.contains("self.note_hash_bytes(self.max_hash_part_bytes)?;")
        && !kernel_source.contains("self.note_hash_bytes(value.canonical_len())?");
    let kernel_bounded_journal_checks = [
        (
            "struct BoundedJournal<T>",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "kernel_steps: BoundedJournal<RuntimeKernelStepWitness>",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "struct RuntimePhaseJournal",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "runtime_phase_events: RuntimePhaseJournal",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "entries: Vec::with_capacity(max_len.max(1))",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "fn max_runtime_phase_event_count(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "max_runtime_phase_event_count(public_object_ids.len(), plan.max_kernel_ops)?;",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let kernel_bounded_journal_restricted = kernel_bounded_journal_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("kernel bounded-journal restriction flag must be boolean")
    });
    let kernel_runtime_phase_helper_path_restricted = kernel_source
        .contains("self.runtime_phase_events.push_pre_committed_cold_object(object_id)?;")
        && kernel_source.contains("self.runtime_phase_events.push_shadow_load_object(object_id)")
        && kernel_source
            .contains("self.runtime_phase_events.push_kernel_step(opcode, object_id)?;")
        && kernel_source.contains(
            "self.runtime_phase_events.append_commit_object_schedule(committed_object_ids)?;",
        )
        && kernel_source.contains("witness.append_commit_object_schedule(object_ids.clone())?;");
    let state_routes_confidential_calls_through_runtime_kernel =
        state_source.contains("kernel.run_confidential_call(");
    let state_confidential_outcome_layering_is_explicit = state_source
        .contains("self.committed.run_confidential_call(")
        && !state_source.contains("struct ConfidentialCommittedKernelOutcome")
        && !state_source.contains("struct ConfidentialCommittedCallOutcome")
        && !state_source.contains("ConfidentialKernelRunOutcome")
        && runtime_module_source.contains("struct RuntimeCallOutcome")
        && shell_source.contains("RuntimeCallOutcome")
        && state_source.contains("let (\n            committed_shadow,")
        && !state_source.contains("into_runtime_execution_parts(")
        && !state_source.contains("into_committed_outcome_parts();")
        && !state_source.contains("opcode_trace: Vec::new()");
    let runtime_call_outcome_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "RuntimeCallOutcome")?;
    let expected_runtime_call_outcome_surface_files = vec![
        String::from("runtime/uo-evm/src/runtime.rs"),
        String::from("runtime/uo-evm/src/shell.rs"),
        String::from("runtime/uo-evm/src/state.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let runtime_call_outcome_surface_restricted =
        runtime_call_outcome_surface_files == expected_runtime_call_outcome_surface_files;
    let runtime_call_outcome_runtime_private = runtime_module_source
        .contains("pub(in crate::runtime) struct RuntimeCallOutcome")
        && !runtime_module_source.contains("pub(crate) struct RuntimeCallOutcome")
        && !runtime_module_source.contains("pub struct RuntimeCallOutcome");
    let runtime_call_outcome_decl = "pub(in crate::runtime) struct RuntimeCallOutcome";
    let runtime_call_outcome_derive_line = runtime_module_source
        .split(runtime_call_outcome_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate RuntimeCallOutcome declaration"))?;
    let runtime_call_outcome_nonclone = !runtime_call_outcome_derive_line.contains("Clone");
    let runtime_call_outcome_fields_private = runtime_module_source
        .contains("runtime_kernel_witness: RuntimeKernelWitness")
        && runtime_module_source
            .contains("runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness")
        && runtime_module_source.contains("aborted: bool")
        && runtime_module_source.contains("return_value: Option<Value>")
        && runtime_module_source.contains("opcode_trace: Vec<String>")
        && !runtime_module_source.contains("pub runtime_kernel_witness:")
        && !runtime_module_source.contains("pub runtime_kernel_refinement_witness:")
        && !runtime_module_source.contains("pub aborted:")
        && !runtime_module_source.contains("pub return_value:")
        && !runtime_module_source.contains("pub opcode_trace:");
    let runtime_call_outcome_api_is_explicit = runtime_module_source
        .contains("pub(in crate::runtime) fn from_runtime_execution(")
        && runtime_module_source.contains("pub(in crate::runtime) fn into_theorem_trace_parts(")
        && !runtime_module_source.contains("pub fn from_runtime_execution(");
    let runtime_call_outcome_constructor_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "from_runtime_execution(")?;
    let expected_runtime_call_outcome_constructor_surface_files = vec![
        String::from("runtime/uo-evm/src/runtime.rs"),
        String::from("runtime/uo-evm/src/shell.rs"),
        String::from("runtime/uo-evm/src/state.rs"),
    ];
    let runtime_call_outcome_constructor_surface_restricted =
        runtime_call_outcome_constructor_surface_files
            == expected_runtime_call_outcome_constructor_surface_files;
    let runtime_call_outcome_theorem_consumer_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "into_theorem_trace_parts(")?;
    let expected_runtime_call_outcome_theorem_consumer_surface_files = vec![
        String::from("runtime/uo-evm/src/runtime.rs"),
        String::from("runtime/uo-evm/src/state.rs"),
    ];
    let runtime_call_outcome_theorem_consumer_surface_restricted =
        runtime_call_outcome_theorem_consumer_surface_files
            == expected_runtime_call_outcome_theorem_consumer_surface_files;
    let traced_runtime_call_outcome_decl = "pub(in crate::runtime) struct TracedRuntimeCallOutcome";
    let traced_runtime_call_outcome_derive_line = state_source
        .split(traced_runtime_call_outcome_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate TracedRuntimeCallOutcome declaration"))?;
    let traced_runtime_call_outcome_nonclone =
        !traced_runtime_call_outcome_derive_line.contains("Clone");
    let traced_runtime_call_outcome_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "TracedRuntimeCallOutcome")?;
    let expected_traced_runtime_call_outcome_surface_files = vec![
        String::from("runtime/uo-evm/src/state.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let traced_runtime_call_outcome_surface_restricted = traced_runtime_call_outcome_surface_files
        == expected_traced_runtime_call_outcome_surface_files;
    let traced_runtime_call_start_decl = "pub(in crate::runtime) struct TracedRuntimeCallStart";
    let traced_runtime_call_start_derive_line = state_source
        .split(traced_runtime_call_start_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate TracedRuntimeCallStart declaration"))?;
    let traced_runtime_call_start_nonclone =
        !traced_runtime_call_start_derive_line.contains("Clone");
    let traced_runtime_call_start_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "TracedRuntimeCallStart")?;
    let expected_traced_runtime_call_start_surface_files = vec![
        String::from("runtime/uo-evm/src/state.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let traced_runtime_call_start_surface_restricted =
        traced_runtime_call_start_surface_files == expected_traced_runtime_call_start_surface_files;
    let traced_runtime_call_witness_state_decl =
        "pub(in crate::runtime) struct TracedRuntimeCallWitnessState";
    let traced_runtime_call_witness_state_derive_line = state_source
        .split(traced_runtime_call_witness_state_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate TracedRuntimeCallWitnessState declaration"))?;
    let traced_runtime_call_witness_state_nonclone =
        !traced_runtime_call_witness_state_derive_line.contains("Clone");
    let traced_runtime_call_witness_state_wipes_on_drop = state_source
        .contains("impl Drop for TracedRuntimeCallWitnessState")
        && state_source.contains(
            "wipe_runtime_oram_access_counters(&mut self.runtime_oram_access_counters_before);",
        )
        && state_source.contains(
            "wipe_runtime_oram_access_counters(&mut self.runtime_oram_access_counters_after);",
        )
        && state_source.contains(
            "wipe_runtime_oram_position_maps(&mut self.runtime_oram_position_map_before);",
        )
        && state_source.contains(
            "wipe_runtime_oram_position_maps(&mut self.runtime_oram_position_map_after);",
        );
    let traced_runtime_call_witness_state_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "TracedRuntimeCallWitnessState")?;
    let expected_traced_runtime_call_witness_state_surface_files = vec![
        String::from("runtime/uo-evm/src/state.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let traced_runtime_call_witness_state_surface_restricted =
        traced_runtime_call_witness_state_surface_files
            == expected_traced_runtime_call_witness_state_surface_files;
    let traced_runtime_call_witness_state_api_is_explicit = state_source
        .contains("pub(in crate::runtime) fn into_execution_trace_parts(")
        && theorem_source.contains("runtime_witness_state.into_execution_trace_parts()");
    let traced_runtime_call_outcome_api_is_explicit = state_source
        .contains("pub(in crate::runtime) fn finish_traced_call(")
        && state_source.contains("pub(in crate::runtime) fn into_finalized_call_trace_parts(")
        && theorem_source.contains("runtime.finish_traced_call(call_outcome)?;")
        && theorem_source
            .contains("traced_outcome.into_finalized_call_trace_parts(runtime_call_start)");
    let traced_runtime_call_outcome_constructor_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "TracedRuntimeCallOutcome {")?;
    let expected_traced_runtime_call_outcome_constructor_surface_files =
        vec![String::from("runtime/uo-evm/src/state.rs")];
    let traced_runtime_call_outcome_constructor_surface_restricted =
        traced_runtime_call_outcome_constructor_surface_files
            == expected_traced_runtime_call_outcome_constructor_surface_files;
    let traced_runtime_call_outcome_consumer_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "into_finalized_call_trace_parts(")?;
    let expected_traced_runtime_call_outcome_consumer_surface_files = vec![
        String::from("runtime/uo-evm/src/state.rs"),
        String::from("runtime/uo-evm/src/theorem.rs"),
    ];
    let traced_runtime_call_outcome_consumer_surface_restricted =
        traced_runtime_call_outcome_consumer_surface_files
            == expected_traced_runtime_call_outcome_consumer_surface_files;
    let traced_runtime_call_witness_state_consumer_surface_files = collect_production_pattern_hits(
        &runtime_evm_src,
        "runtime_witness_state.into_execution_trace_parts()",
    )?;
    let expected_traced_runtime_call_witness_state_consumer_surface_files =
        vec![String::from("runtime/uo-evm/src/theorem.rs")];
    let traced_runtime_call_witness_state_consumer_surface_restricted =
        traced_runtime_call_witness_state_consumer_surface_files
            == expected_traced_runtime_call_witness_state_consumer_surface_files;
    let confidential_exec_state_decl = "struct ConfidentialExecState";
    let confidential_exec_state_derive_line = kernel_source
        .split(confidential_exec_state_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate ConfidentialExecState declaration"))?;
    let confidential_exec_state_nonclone = !confidential_exec_state_derive_line.contains("Clone");
    let confidential_exec_state_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "ConfidentialExecState")?;
    let expected_confidential_exec_state_surface_files =
        vec![String::from("runtime/uo-evm/src/kernel.rs")];
    let confidential_exec_state_surface_restricted =
        confidential_exec_state_surface_files == expected_confidential_exec_state_surface_files;
    let confidential_kernel_run_outcome_decl = "ConfidentialKernelRunOutcome";
    let confidential_kernel_run_outcome_derive_line = String::new();
    let confidential_kernel_run_outcome_nonclone =
        !kernel_source.contains(confidential_kernel_run_outcome_decl);
    let confidential_kernel_run_outcome_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "ConfidentialKernelRunOutcome")?;
    let expected_confidential_kernel_run_outcome_surface_files = Vec::<String>::new();
    let confidential_kernel_run_outcome_surface_restricted =
        confidential_kernel_run_outcome_surface_files
            == expected_confidential_kernel_run_outcome_surface_files;
    let confidential_kernel_run_outcome_fields_private = !kernel_source
        .contains("committed_shadow: ConfidentialRuntimeShadowState")
        && !kernel_source.contains("runtime_kernel_witness: RuntimeKernelWitness")
        && !kernel_source
            .contains("runtime_kernel_refinement_witness: RuntimeKernelRefinementWitness")
        && !kernel_source.contains("return_value: Option<Value>");
    let confidential_kernel_run_outcome_api_is_explicit =
        !kernel_source.contains("into_committed_outcome_parts(");
    let confidential_execution_outcome_decl = "struct ConfidentialExecutionOutcome";
    let confidential_execution_outcome_derive_line = kernel_source
        .split(confidential_execution_outcome_decl)
        .next()
        .and_then(|prefix| prefix.lines().rev().find(|line| !line.trim().is_empty()))
        .map(str::trim)
        .ok_or_else(|| anyhow!("failed to locate ConfidentialExecutionOutcome declaration"))?;
    let confidential_execution_outcome_nonclone =
        !confidential_execution_outcome_derive_line.contains("Clone");
    let confidential_execution_outcome_fields_private = kernel_source
        .contains("struct ConfidentialExecutionOutcome")
        && kernel_source.contains("aborted: bool")
        && kernel_source.contains("return_value: Option<Value>")
        && !kernel_source.contains("pub aborted: bool")
        && !kernel_source.contains("pub return_value: Option<Value>");
    let confidential_exec_state_wipes_on_drop = kernel_source
        .contains("impl Drop for ConfidentialExecState")
        && kernel_source.contains("for slot in &mut self.slots {")
        && kernel_source.contains("value.wipe_secrets();")
        && kernel_source.contains("*slot = None;")
        && kernel_source.contains("self.return_value = None;");
    let state_enforces_confidential_commit_budget = state_source
        .contains("recorder.physical_write_count() > max_commit_ops")
        && state_source.contains("exceeded manifest commit budget");
    let oram_working_stash_capacity_checks = [
        (
            "fn working_stash_capacity(parameters: &OramParameters) -> Result<usize>",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "stash: Vec::with_capacity(working_stash_capacity(&self.parameters)?)",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "let stash = Vec::with_capacity(working_stash_capacity(&parameters)?);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "let mut stash = Vec::with_capacity(working_stash_capacity(parameters)?);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "self.stash.clear();",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "if working_stash.capacity() < required_stash_capacity {",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let oram_working_stash_capacity_restricted =
        oram_working_stash_capacity_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("ORAM working-stash restriction flag must be boolean")
        });
    let oram_working_stash_avoids_midcall_reserve = !production_source_slice(&oram_source)
        .contains(
            ".reserve(self.parameters.buckets_per_access * self.parameters.blocks_per_bucket)",
        );
    let oram_buffer_reuse_checks = [
        (
            "impl Clone for OramState",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "clone_vec_with_min_capacity(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "entries: Vec::with_capacity(self.parameters.capacity)",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "position_map: Vec::with_capacity(self.parameters.capacity)",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "decode_path_metadata_pages_into(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "decode_path_position_map_pages_into(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            ".resize(self.parameters.capacity, empty_map_entry(spec)?);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "position_map.clear();",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "fn restore_from_old(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            ".directory_pages\n            .clone_from(&old.storage.directory_pages);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "self.storage.buckets.clone_from(&old.storage.buckets);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            ".access_counter_slot\n            .clone_from(&old.storage.access_counter_slot);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "fn decode_surrogate_entries_from_storage_into(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "Self::decode_surrogate_entries_from_storage_into(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "next.restore_from_old(spec, old, allocator)?;",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "rewrite_path_metadata_pages_in_place(",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        (
            "let mut payload = Vec::with_capacity(parameters.directory_page_bytes);",
            vec![String::from("runtime/uo-evm/src/oram.rs")],
        ),
        ("old.clone_for_tx(spec, allocator)?", vec![]),
        (
            "let new_directory_pages = encode_path_metadata_pages(",
            vec![],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let oram_buffer_reuse_restricted = oram_buffer_reuse_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("ORAM buffer-reuse restriction flag must be boolean")
    });
    let path_oram_restore_reuses_in_place_buffers = objects_source
        .contains(".restore_from_old(&old.spec, &old.oram, allocator)?;")
        && !objects_source.contains("next.oram = old.oram.clone_for_tx(&old.spec, allocator)?;");
    let state_owns_shadow_loading =
        state_source.contains("fn shadow_load(") && !kernel_source.contains("clone_for_tx(");
    let state_owns_committed_reconciliation = state_source.contains("fn commit_against(")
        && !kernel_source.contains(".commit(")
        && !state_source.contains("fn take_objects(")
        && !state_source.contains("fn replace_objects(");
    let state_owns_path_oram_fresh_coin_routing = state_source
        .contains("fn install_path_oram_leaf_coins(")
        && state_source.contains("fn ensure_path_oram_leaf_coins_consumed(")
        && !kernel_source.contains("values_mut()")
        && !kernel_source.contains("values()");
    let engine_does_not_lower_confidential_program_directly = !engine_impl_source
        .contains("confidential_kernel_program(")
        && !engine_impl_source.contains("confidential_kernel_slot_program(");
    let kernel_confidential_select_uses_branchless_value_select =
        kernel_source.contains("Value::confidential_select(cond, when_true, when_false)");
    let checker_uses_shared_confidential_kernel_lowering =
        checker_source.contains("lower_confidential_kernel_statements(statements, signature)?;");
    let checker_uses_manifest_slot_schedule_directly = checker_source
        .contains("witnessed_slot_program.expected_runtime_step_manifest()")
        && !checker_source
            .contains("expected_slot_program\n                .expected_runtime_steps()");
    let kernel_witness_validation_uses_manifest_confidential_slot_program = core_trace_source
        .contains(".confidential_slot_program")
        && core_trace_source.contains(".expected_runtime_step_manifest()")
        && core_trace_source.contains(".kernel_step_witnesses()");
    let kernel_witness_validation_tracks_confidential_kernel_lowering_errors = core_trace_source
        .contains("ConfidentialKernelLoweringError::SelectArmOutsideBranchlessFragment")
        && core_trace_source.contains("ConfidentialKernelLoweringError::ConfidentialStructField")
        && core_trace_source.contains("ConfidentialKernelLoweringError::ConfidentialArrayIndex");
    let allocator_uses_manifest_kernel_step_budget = allocator_source
        .contains("let canonical_kernel_steps = entry.canonical_kernel_step_manifest();")
        && allocator_source.contains("plan.max_kernel_ops = if canonical_kernel_steps.is_empty()")
        && allocator_source.contains("canonical_kernel_steps.len()")
        && !allocator_source.contains("entry.kernel_steps.is_empty()")
        && !allocator_source.contains("entry.kernel_steps.len()")
        && !allocator_source.contains("program.expected_runtime_steps().len()");
    let translation_validation_uses_canonical_kernel_step_manifest = translation_validation_source
        .contains("entrypoint.canonical_kernel_step_manifest()")
        && !translation_validation_source.contains("entrypoint\n                .kernel_steps");
    let state_uses_checked_manifest_kernel_schedule = state_source
        .contains("let program_expected_kernel_steps = program.expected_runtime_step_witnesses();")
        && state_source
            .contains("if manifest_expected_kernel_steps != program_expected_kernel_steps {")
        && state_source
            .contains("allocator.max_kernel_ops = manifest_expected_kernel_steps.len();")
        && state_source
            .contains("PublicRuntimeKernel::begin(allocator, public_object_ids.clone())?")
        && !state_source.contains("let expected_kernel_steps =")
        && !state_source.contains("expected_kernel_steps: Vec<RuntimeKernelStepWitness>,")
        && !state_source.contains("shadow_load_object_ids")
        && !kernel_source.contains(
            "pub(crate) fn begin(\n        plan: AllocatorPlan,\n        expected_kernel_steps:",
        )
        && kernel_source.contains("self.bind_expected_kernel_program(program)?;")
        && kernel_source.contains("fn bind_expected_kernel_program(")
        && kernel_source
            .contains("let shadow_load_object_ids = self.expected_shadow_load_object_ids()?;")
        && kernel_source.contains("fn expected_shadow_load_object_ids(&self) -> Result<Vec<u32>>");
    let trusted_kernel_slot_bundle_uses_manifest_confidential_slot_program =
        core_trusted_kernel_source.contains("pub fn runtime_trusted_kernel_slot_bundle(")
            && core_trusted_kernel_source.contains("manifest_entry")
            && core_trusted_kernel_source.contains(".confidential_slot_program");
    let trusted_kernel_cli_uses_slot_bundle =
        main_source.contains("trace.runtime_trusted_kernel_slot_bundle(&artifact)?");
    let trusted_kernel_probe_uses_slot_bundle = probe_source.contains(
        "let trusted_kernel_bundle = trace.runtime_trusted_kernel_slot_bundle(&artifact)?;",
    ) && probe_source
        .contains("let bundle = trace.runtime_trusted_kernel_slot_bundle(artifact)?;");
    let trusted_kernel_checker_uses_slot_bundle = trusted_kernel_checker_source
        .contains("loadAndCheckImportedProofGradeRuntimeTrustedKernelSlotBundle");
    let runtime_phase_event_constructor_files =
        collect_production_pattern_hits(&runtime_evm_src, "RuntimeKernelRefinementEventWitness::")?;
    let expected_runtime_phase_event_constructor_files =
        vec![String::from("runtime/uo-evm/src/kernel.rs")];
    let runtime_phase_event_constructor_surface_restricted =
        runtime_phase_event_constructor_files == expected_runtime_phase_event_constructor_files;
    let runtime_kernel_refinement_witness_fields_private = core_trace_source
        .contains("pub struct RuntimeKernelRefinementWitness {")
        && core_trace_source.contains("events: Vec<RuntimeKernelRefinementEventWitness>,")
        && !core_trace_source.contains("pub events: Vec<RuntimeKernelRefinementEventWitness>,");
    let runtime_kernel_refinement_witness_api_is_explicit = core_trace_source
        .contains("pub fn from_events(events: Vec<RuntimeKernelRefinementEventWitness>) -> Self {")
        && core_trace_source
            .contains("pub fn events(&self) -> &[RuntimeKernelRefinementEventWitness] {")
        && core_trace_source.contains("pub fn event_count(&self) -> usize {")
        && core_trace_source.contains(
            "pub fn first_event(&self) -> Option<&RuntimeKernelRefinementEventWitness> {",
        )
        && core_trace_source
            .contains("pub fn last_event(&self) -> Option<&RuntimeKernelRefinementEventWitness> {");
    let runtime_kernel_refinement_witness_builder_path_restricted = kernel_source
        .contains("RuntimeKernelRefinementWitness::from_events(self.inner.entries.clone())")
        && kernel_source
            .contains("RuntimeKernelRefinementWitness::from_events(self.inner.into_vec())")
        && runtime_evm_lib_source.contains("phase_witness.first_event().map(|event| event.kind)")
        && runtime_evm_lib_source.contains("phase_witness.last_event().map(|event| event.kind)")
        && probe_source.contains("runtime_kernel_refinement_witness.events().to_vec()")
        && probe_source.contains("runtime_kernel_refinement_witness.event_count()");
    let resource_event_constructor_files =
        collect_production_pattern_hits(&allocator_src, "RuntimeKernelResourceEventWitness::")?;
    let expected_resource_event_constructor_files =
        vec![String::from("runtime/uo-allocator/src/lib.rs")];
    let resource_event_constructor_surface_restricted =
        resource_event_constructor_files == expected_resource_event_constructor_files;
    let state_only_runtime_helper_surface_checks = [
        (
            ".insert(*object_id, object.clone_for_tx(allocator)?);",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "clone_committed_cold()",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "path_oram_position_map_witness()?",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "RuntimeObject::path_oram_access_counter_witness",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "let committed_object = object.commit(old, aborted, recorder, allocator)?;",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            ".map(|(id, object)| (id, object.into_cold_committed()))",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "object.enable_injected_path_oram_leaf_coins();",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            ".install_path_oram_leaf_coins(coins)?;",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "object.ensure_path_oram_leaf_coins_consumed()?;",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let state_only_runtime_helper_surface_restricted = state_only_runtime_helper_surface_checks
        .iter()
        .all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("state-only helper restriction flag must be boolean")
        });
    let kernel_only_state_helper_surface_checks = [
        (
            "committed.shadow_load(shadow_load_object_ids, &mut self.allocator)?",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            ".object_mut(object_id)?",
            vec![
                String::from("runtime/uo-evm/src/kernel.rs"),
                String::from("runtime/uo-evm/src/state.rs"),
            ],
        ),
        (
            "objects.install_path_oram_leaf_coins(fresh_coins.into_by_object())",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "objects.ensure_path_oram_leaf_coins_consumed()",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "objects.commit_against(committed, aborted, recorder, &mut self.allocator)?",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let kernel_only_state_helper_surface_restricted =
        kernel_only_state_helper_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("kernel-only state helper restriction flag must be boolean")
        });
    let theorem_only_runtime_helper_surface_checks = [
        (
            "runtime.begin_traced_call(",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
        (
            "runtime.finish_traced_call(",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
        (
            ".into_finalized_call_trace_parts(",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
        (
            ".into_execution_trace_parts()",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let theorem_only_runtime_helper_surface_restricted = theorem_only_runtime_helper_surface_checks
        .iter()
        .all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("theorem-only runtime helper restriction flag must be boolean")
        });
    let fullscan_buffer_reuse_checks = [
        (
            "self.values.clear();\n        self.values.resize(\n            self.physical_slots.len(),",
            vec![String::from("runtime/uo-evm/src/objects.rs")],
        ),
        (
            "self.entries.clear();\n        self.entries.resize(\n            self.physical_slots.len(),\n            MapEntry::new(",
            vec![String::from("runtime/uo-evm/src/objects.rs")],
        ),
        (
            "fn decode_values_from_storage_into(",
            vec![String::from("runtime/uo-evm/src/objects.rs")],
        ),
        (
            "fn decode_entries_from_storage_into(",
            vec![String::from("runtime/uo-evm/src/objects.rs")],
        ),
        (
            "old.decode_values_from_storage_into(allocator, &mut next.values)?;",
            vec![String::from("runtime/uo-evm/src/objects.rs")],
        ),
        (
            "old.decode_entries_from_storage_into(allocator, &mut next.entries)?;",
            vec![String::from("runtime/uo-evm/src/objects.rs")],
        ),
        ("next.physical = old.physical.clone();", vec![]),
        ("next.physical_slots = old.physical_slots.clone();", vec![]),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let fullscan_buffer_reuse_restricted = fullscan_buffer_reuse_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("full-scan buffer-reuse restriction flag must be boolean")
    });
    let state_only_kernel_helper_surface_checks = [
        (
            ".shadow_load_public_objects(self, public_object_ids)",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            ".commit_public_objects(shadow, self, aborted, recorder)",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "kernel.run_confidential_call(",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let state_only_kernel_helper_surface_restricted =
        state_only_kernel_helper_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("state-only kernel helper restriction flag must be boolean")
        });
    let contract_runtime_entrypoint_surface_checks = [
        (
            "runtime.prepare_public_shadow(",
            vec![String::from("runtime/uo-evm/src/shell.rs")],
        ),
        (
            "runtime.commit_public_shadow(",
            vec![String::from("runtime/uo-evm/src/shell.rs")],
        ),
        (
            "runtime.replace_with_cold_public_shadow(",
            vec![String::from("runtime/uo-evm/src/shell.rs")],
        ),
        (
            "runtime.run_confidential_entrypoint(",
            vec![String::from("runtime/uo-evm/src/theorem.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let contract_runtime_entrypoint_surface_restricted = contract_runtime_entrypoint_surface_checks
        .iter()
        .all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("contract-runtime entrypoint restriction flag must be boolean")
        });
    let confidential_object_api_surface_checks = [
        (
            ".get_cell(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            ".set_cell(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            ".get_array(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            ".set_array(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            ".get_map(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            ".put_map(",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let confidential_object_api_surface_restricted =
        confidential_object_api_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("confidential object API restriction flag must be boolean")
        });
    let runtime_state_surface_checks = [
        (
            "pub(in crate::runtime) fn object_mut",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "ContractRuntime",
            vec![
                String::from("runtime/uo-evm/src/engine.rs"),
                String::from("runtime/uo-evm/src/shell.rs"),
                String::from("runtime/uo-evm/src/state.rs"),
                String::from("runtime/uo-evm/src/theorem.rs"),
            ],
        ),
        (
            "CommittedRuntimeState",
            vec![
                String::from("runtime/uo-evm/src/kernel.rs"),
                String::from("runtime/uo-evm/src/state.rs"),
            ],
        ),
        (
            "pub(in crate::runtime) struct RuntimeShadowState",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "ConfidentialRuntimeShadowState",
            vec![
                String::from("runtime/uo-evm/src/kernel.rs"),
                String::from("runtime/uo-evm/src/state.rs"),
            ],
        ),
        (
            "slots: Vec<Option<Value>>",
            vec![String::from("runtime/uo-evm/src/kernel.rs")],
        ),
        (
            "let mut runtime_oram_position_maps = Vec::with_capacity(self.objects.len());",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
        (
            "let mut committed_object_ids = Vec::with_capacity(committed.objects().len());",
            vec![String::from("runtime/uo-evm/src/state.rs")],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_production_pattern_hits(&runtime_evm_src, pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let runtime_state_surface_restricted = runtime_state_surface_checks.iter().all(|entry| {
        entry["restricted"]
            .as_bool()
            .expect("runtime state restriction flag must be boolean")
    });
    let runtime_module_layout_present = runtime_module_source
        .contains("#[path = \"fresh_coins.rs\"]")
        && runtime_module_source.contains("#[path = \"kernel.rs\"]")
        && runtime_module_source.contains("#[path = \"objects.rs\"]")
        && runtime_module_source.contains("#[path = \"state.rs\"]");
    let store_cipher_key_zeroizes_on_drop = store_codec_source
        .contains("impl Drop for StoreCipher")
        && store_codec_source.contains("self.key.zeroize();");
    let store_cipher_exposes_wipe_helpers = store_codec_source.contains("pub fn seal_and_wipe(")
        && store_codec_source.contains("pub fn seal_and_wipe_into(")
        && store_codec_source.contains("pub fn with_opened_payload<");
    let execution_trace_omits_runtime_telemetry = core_trace_source
        .contains("pub struct ExecutionTrace {")
        && !core_trace_source.contains("pub host_proxy_metrics:");
    let execution_trace_runtime_fields_private = core_trace_source
        .contains("pub struct ExecutionTrace {")
        && core_trace_source.contains("runtime_seed: Option<u64>,")
        && core_trace_source.contains("runtime_kernel_witness: Option<RuntimeKernelWitness>,")
        && core_trace_source
            .contains("runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,")
        && core_trace_source
            .contains("runtime_trusted_kernel_bundle: Option<RuntimeTrustedKernelBundle>,")
        && core_trace_source
            .contains("runtime_controller_certificate: Option<RuntimeControllerCertificate>,")
        && core_trace_source.contains("runtime_oram_objects: Vec<RuntimeOramObjectWitness>,")
        && core_trace_source.contains("runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,")
        && core_trace_source
            .contains("runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,")
        && core_trace_source
            .contains("runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,")
        && core_trace_source
            .contains("runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,")
        && core_trace_source
            .contains("runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,")
        && core_trace_source.contains(
            "runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,",
        )
        && !core_trace_source.contains("pub runtime_seed: Option<u64>,")
        && !core_trace_source.contains("pub runtime_kernel_witness: Option<RuntimeKernelWitness>,")
        && !core_trace_source.contains(
            "pub runtime_kernel_refinement_witness: Option<RuntimeKernelRefinementWitness>,",
        )
        && !core_trace_source
            .contains("pub runtime_trusted_kernel_bundle: Option<RuntimeTrustedKernelBundle>,")
        && !core_trace_source
            .contains("pub runtime_controller_certificate: Option<RuntimeControllerCertificate>,")
        && !core_trace_source.contains("pub runtime_oram_objects: Vec<RuntimeOramObjectWitness>,")
        && !core_trace_source
            .contains("pub runtime_oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,")
        && !core_trace_source.contains(
            "pub runtime_oram_access_counters_before: Vec<RuntimeOramAccessCounterWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_access_counters_after: Vec<RuntimeOramAccessCounterWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,",
        )
        && !core_trace_source.contains(
            "pub runtime_oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,",
        );
    let execution_trace_runtime_api_is_explicit = core_trace_source
        .contains("pub fn runtime_seed(&self) -> Option<u64> {")
        && core_trace_source
            .contains("pub fn runtime_kernel_witness(&self) -> Option<&RuntimeKernelWitness> {")
        && core_trace_source.contains(
            "pub fn runtime_kernel_refinement_witness(&self) -> Option<&RuntimeKernelRefinementWitness> {",
        )
        && core_trace_source.contains(
            "pub fn stored_runtime_trusted_kernel_bundle(&self) -> Option<&RuntimeTrustedKernelBundle> {",
        )
        && core_trace_source.contains(
            "pub fn stored_runtime_controller_certificate(&self) -> Option<&RuntimeControllerCertificate> {",
        )
        && core_trace_source
            .contains("pub fn runtime_oram_objects(&self) -> &[RuntimeOramObjectWitness] {")
        && core_trace_source
            .contains("pub fn runtime_oram_leaf_schedule(&self) -> &[RuntimeOramLeafWitness] {")
        && core_trace_source.contains(
            "pub fn runtime_oram_access_counters_before(&self) -> &[RuntimeOramAccessCounterWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_access_counters_after(&self) -> &[RuntimeOramAccessCounterWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_position_map_before(&self) -> &[RuntimePathOramPositionMapWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_position_map_after(&self) -> &[RuntimePathOramPositionMapWitness] {",
        )
        && core_trace_source.contains(
            "pub fn runtime_oram_leaf_state_transitions(&self) -> &[RuntimePathOramTransitionWitness] {",
        );
    let runtime_execution_trace_parts_fields_private = core_trace_source
        .contains("pub struct RuntimeExecutionTraceParts {")
        && core_trace_source.contains("opcode_trace: Vec<String>,")
        && core_trace_source.contains("runtime_seed: Option<u64>,")
        && core_trace_source.contains("runtime_kernel_witness: Option<RuntimeKernelWitness>,")
        && !core_trace_source.contains("pub opcode_trace: Vec<String>,")
        && !core_trace_source.contains("pub runtime_seed: Option<u64>,")
        && !core_trace_source.contains("pub runtime_kernel_witness: Option<RuntimeKernelWitness>,");
    let runtime_execution_trace_parts_constructor_is_explicit = core_trace_source
        .contains("impl RuntimeExecutionTraceParts {")
        && core_trace_source.contains("pub fn new(")
        && !core_trace_source.contains("#[derive(Clone, Debug, PartialEq, Default)]");
    let runtime_controller_certificate_fields_private = core_trace_source
        .contains("pub struct RuntimeControllerCertificate {")
        && core_trace_source.contains("entry_input_len: usize,")
        && core_trace_source.contains("observed_oram_accesses: Vec<RuntimeOramAccessWitness>,")
        && !core_trace_source.contains("pub entry_input_len: usize,")
        && !core_trace_source
            .contains("pub observed_oram_accesses: Vec<RuntimeOramAccessWitness>,");
    let runtime_controller_certificate_api_is_explicit = core_trace_source
        .contains("impl RuntimeControllerCertificate {")
        && core_trace_source.contains("pub fn new(")
        && core_trace_source.contains("pub fn entry_input_len(&self) -> usize {")
        && core_trace_source
            .contains("pub fn observed_oram_accesses(&self) -> &[RuntimeOramAccessWitness] {");
    let runtime_controller_observer_certificate_fields_private = core_trace_source
        .contains("pub struct RuntimeControllerObserverCertificate {")
        && core_trace_source.contains("public_outcome: PublicOutcomeTrace,")
        && core_trace_source.contains("boundary_schedule: Vec<BoundaryEvent>,")
        && core_trace_source.contains("controller_shape: SgxControllerShapeTrace,")
        && core_trace_source.contains("normalized_micro_trace: NormalizedMicroTrace,")
        && core_trace_source.contains("controller_certificate: RuntimeControllerCertificate,")
        && !core_trace_source.contains("pub public_outcome: PublicOutcomeTrace,")
        && !core_trace_source.contains("pub boundary_schedule: Vec<BoundaryEvent>,")
        && !core_trace_source.contains("pub controller_shape: SgxControllerShapeTrace,")
        && !core_trace_source.contains("pub normalized_micro_trace: NormalizedMicroTrace,")
        && !core_trace_source.contains("pub controller_certificate: RuntimeControllerCertificate,");
    let runtime_controller_observer_certificate_api_is_explicit = core_trace_source
        .contains("pub fn public_outcome(&self) -> &PublicOutcomeTrace {")
        && core_trace_source.contains("pub fn boundary_schedule(&self) -> &[BoundaryEvent] {")
        && core_trace_source
            .contains("pub fn controller_shape(&self) -> &SgxControllerShapeTrace {")
        && core_trace_source
            .contains("pub fn normalized_micro_trace(&self) -> &NormalizedMicroTrace {")
        && core_trace_source
            .contains("pub fn controller_certificate(&self) -> &RuntimeControllerCertificate {");
    let runtime_path_oram_hidden_certificate_fields_private = core_trace_source
        .contains("pub struct RuntimePathOramHiddenCertificate {")
        && core_trace_source.contains("trace: RefinementTrace,")
        && core_trace_source.contains("oram_objects: Vec<RuntimeOramObjectWitness>,")
        && core_trace_source
            .contains("oram_leaf_public_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && core_trace_source.contains("oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,")
        && core_trace_source
            .contains("oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,")
        && core_trace_source
            .contains("oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,")
        && core_trace_source
            .contains("oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,")
        && !core_trace_source.contains("pub trace: RefinementTrace,")
        && !core_trace_source.contains("pub oram_objects: Vec<RuntimeOramObjectWitness>,")
        && !core_trace_source
            .contains("pub oram_leaf_public_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && !core_trace_source.contains("pub oram_leaf_schedule: Vec<RuntimeOramLeafWitness>,")
        && !core_trace_source
            .contains("pub oram_position_map_before: Vec<RuntimePathOramPositionMapWitness>,")
        && !core_trace_source
            .contains("pub oram_position_map_after: Vec<RuntimePathOramPositionMapWitness>,")
        && !core_trace_source
            .contains("pub oram_leaf_state_transitions: Vec<RuntimePathOramTransitionWitness>,");
    let runtime_path_oram_hidden_certificate_api_is_explicit = core_trace_source
        .contains("pub fn trace(&self) -> &RefinementTrace {")
        && core_trace_source
            .contains("pub fn oram_objects(&self) -> &[RuntimeOramObjectWitness] {")
        && core_trace_source.contains(
            "pub fn oram_leaf_public_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {",
        )
        && core_trace_source
            .contains("pub fn oram_leaf_schedule(&self) -> &[RuntimeOramLeafWitness] {")
        && core_trace_source.contains(
            "pub fn oram_position_map_before(&self) -> &[RuntimePathOramPositionMapWitness] {",
        )
        && core_trace_source.contains(
            "pub fn oram_position_map_after(&self) -> &[RuntimePathOramPositionMapWitness] {",
        )
        && core_trace_source.contains(
            "pub fn oram_leaf_state_transitions(&self) -> &[RuntimePathOramTransitionWitness] {",
        );
    let seeded_runtime_pathoram_witness_family_fields_private = core_trace_source
        .contains("pub struct SeededRuntimePathOramWitnessFamily {")
        && core_trace_source.contains("seed_count: usize,")
        && core_trace_source.contains("witnesses: Vec<RuntimeRefinementWitness>,")
        && core_trace_source.contains("public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && !core_trace_source.contains("pub seed_count: usize,")
        && !core_trace_source.contains("pub witnesses: Vec<RuntimeRefinementWitness>,")
        && !core_trace_source
            .contains("pub public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,");
    let seeded_runtime_pathoram_witness_family_api_is_explicit = core_trace_source
        .contains("pub fn seed_count(&self) -> usize {")
        && core_trace_source.contains("pub fn witnesses(&self) -> &[RuntimeRefinementWitness] {")
        && core_trace_source
            .contains("pub fn public_leaf_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {");
    let canonical_fresh_coin_witness_family_fields_private = core_trace_source
        .contains("pub struct CanonicalFreshCoinRuntimePathOramWitnessFamily {")
        && core_trace_source.contains("seed_count: usize,")
        && core_trace_source.contains("witnesses: Vec<RuntimeRefinementWitness>,")
        && core_trace_source.contains("public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && core_trace_source
            .contains("public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && !core_trace_source.contains("pub seed_count: usize,")
        && !core_trace_source.contains("pub witnesses: Vec<RuntimeRefinementWitness>,")
        && !core_trace_source
            .contains("pub public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && !core_trace_source
            .contains("pub public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,");
    let canonical_fresh_coin_witness_family_api_is_explicit = core_trace_source
        .contains("pub fn seed_count(&self) -> usize {")
        && core_trace_source.contains("pub fn witnesses(&self) -> &[RuntimeRefinementWitness] {")
        && core_trace_source
            .contains("pub fn public_leaf_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {")
        && core_trace_source.contains(
            "pub fn public_fresh_coin_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {",
        );
    let canonical_fresh_coin_theorem_input_fields_private = core_trace_source
        .contains("pub struct CanonicalFreshCoinRuntimePathOramTheoremInput {")
        && core_trace_source.contains("seed_count: usize,")
        && core_trace_source.contains("representative_seed: usize,")
        && core_trace_source.contains("representative_witness: RuntimeRefinementWitness,")
        && core_trace_source.contains("public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && core_trace_source
            .contains("public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && !core_trace_source.contains("pub seed_count: usize,")
        && !core_trace_source.contains("pub representative_seed: usize,")
        && !core_trace_source.contains("pub representative_witness: RuntimeRefinementWitness,")
        && !core_trace_source
            .contains("pub public_leaf_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,")
        && !core_trace_source
            .contains("pub public_fresh_coin_scaffold: Vec<RuntimeOramLeafScaffoldWitness>,");
    let canonical_fresh_coin_theorem_input_api_is_explicit = core_trace_source
        .contains("pub fn seed_count(&self) -> usize {")
        && core_trace_source.contains("pub fn representative_seed(&self) -> usize {")
        && core_trace_source
            .contains("pub fn representative_witness(&self) -> &RuntimeRefinementWitness {")
        && core_trace_source
            .contains("pub fn public_leaf_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {")
        && core_trace_source.contains(
            "pub fn public_fresh_coin_scaffold(&self) -> &[RuntimeOramLeafScaffoldWitness] {",
        );
    let execution_trace_runtime_consumers_use_accessors = main_source
        .contains("trace.runtime_kernel_witness().cloned().ok_or_else(")
        && main_source.contains("trace.runtime_kernel_refinement_witness()")
        && runtime_evm_lib_source.contains("result.trace.runtime_kernel_witness()")
        && runtime_evm_lib_source.contains("result.trace.runtime_seed()")
        && runtime_evm_lib_source
            .contains("result.trace.stored_runtime_trusted_kernel_bundle().is_some()")
        && probe_source.contains("trace.runtime_kernel_witness() != Some(&kernel_witness)")
        && probe_source.contains("trace.runtime_oram_access_counters_before().to_vec()");
    let execution_trace_builder_surface_files = collect_production_pattern_hits(
        &runtime_evm_src,
        "ExecutionTrace::from_runtime_trace_parts(",
    )?;
    let expected_execution_trace_builder_surface_files =
        vec![String::from("runtime/uo-evm/src/theorem.rs")];
    let execution_trace_builder_surface_restricted =
        execution_trace_builder_surface_files == expected_execution_trace_builder_surface_files;
    let runtime_execution_trace_parts_constructor_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "RuntimeExecutionTraceParts::new(")?;
    let expected_runtime_execution_trace_parts_constructor_surface_files =
        vec![String::from("runtime/uo-evm/src/theorem.rs")];
    let runtime_execution_trace_parts_constructor_surface_restricted =
        runtime_execution_trace_parts_constructor_surface_files
            == expected_runtime_execution_trace_parts_constructor_surface_files;
    let runtime_controller_certificate_constructor_surface_files =
        collect_production_pattern_hits(&runtime_evm_src, "RuntimeControllerCertificate::new(")?;
    let expected_runtime_controller_certificate_constructor_surface_files =
        vec![String::from("runtime/uo-evm/src/controller.rs")];
    let runtime_controller_certificate_constructor_surface_restricted =
        runtime_controller_certificate_constructor_surface_files
            == expected_runtime_controller_certificate_constructor_surface_files;
    let execution_trace_struct_literal_files =
        collect_production_pattern_hits(&runtime_evm_src, "ExecutionTrace {")?;
    let execution_trace_struct_literal_surface_restricted =
        execution_trace_struct_literal_files.is_empty();
    let runtime_diagnostics_feature_declared = runtime_evm_cargo_source.contains("[features]")
        && runtime_evm_cargo_source.contains("diagnostics = []");
    let probe_enables_runtime_diagnostics_feature = probe_cargo_source
        .contains("uo-evm = { path = \"../../runtime/uo-evm\", features = [\"diagnostics\"] }");
    let default_call_result_omits_runtime_telemetry = engine_source
        .contains("pub struct CallResult {")
        && call_result_struct_source.contains("pub trace: ExecutionTrace,")
        && !call_result_struct_source.contains("telemetry")
        && engine_source.contains("pub fn call(")
        && engine_source.contains("-> Result<CallResult> {")
        && engine_source.contains("self.call_impl(entrypoint, args, None)?.0");
    let diagnostic_call_api_exposes_runtime_telemetry = engine_source
        .contains("pub struct CallTelemetry {")
        && engine_source.contains("pub struct DiagnosticCallResult {")
        && engine_source.contains("pub telemetry: CallTelemetry,")
        && engine_source.contains("pub fn call_with_diagnostics(")
        && engine_source
            .contains("let (call, zero_writes) = self.call_impl(entrypoint, args, None)?;")
        && engine_source.contains("telemetry: CallTelemetry { zero_writes },");
    let fresh_coin_api_gated_behind_feature = engine_source
        .contains("#[cfg(feature = \"diagnostics\")]")
        && engine_source.contains("pub fn call_with_path_oram_fresh_coins(")
        && runtime_evm_lib_source.contains("#[cfg(feature = \"diagnostics\")]")
        && runtime_evm_lib_source.contains("pub use runtime::PathOramFreshCoinPlan;");
    let diagnostic_api_gated_behind_feature = engine_source
        .contains("#[cfg(feature = \"diagnostics\")]")
        && engine_source.contains("pub fn call_with_diagnostics(")
        && runtime_evm_lib_source.contains("mod engine;")
        && !runtime_evm_lib_source.contains("pub mod engine;")
        && runtime_evm_lib_source.contains("#[cfg(feature = \"diagnostics\")]")
        && runtime_evm_lib_source
            .contains("pub use engine::{CallTelemetry, DiagnosticCallResult};");
    let theorem_finalizer_omits_runtime_telemetry = theorem_source
        .contains("let mut trace = ExecutionTrace::from_runtime_trace_parts(")
        && theorem_source.contains("let zero_writes = trace_bundle.zero_writes();")
        && theorem_source.contains("Ok(FinalizedCallTrace {")
        && theorem_source.contains("zero_writes,")
        && !theorem_source.contains("host_proxy_metrics");
    let probe_reads_runtime_telemetry_from_diagnostic_channel = extract_metrics_source
        .contains("fn extract_metrics(result: &DiagnosticCallResult)")
        && extract_metrics_source.contains("let trace = &result.call.trace;")
        && extract_metrics_source.contains("result.telemetry.zero_writes as f64")
        && !extract_metrics_source.contains("host_proxy_metrics")
        && !scenario_overhead_source.contains("host_proxy_metrics");
    let physical_write_event_is_shape_only = core_trace_source
        .contains("pub struct PhysicalWriteEvent {")
        && core_trace_source.contains("pub len: usize,")
        && core_trace_source.contains("pub class: WriteClass,")
        && !core_trace_source.contains("pub old: Vec<u8>")
        && !core_trace_source.contains("pub new: Vec<u8>")
        && !core_trace_source.contains("pub new_zero: bool,");
    let physical_write_event_builders_are_shape_only = core_trace_source
        .contains("pub fn from_buffers(")
        && core_trace_source.contains("pub fn from_shape(")
        && core_trace_source.contains("len: new.len(),")
        && core_trace_source.contains("class: classify_write(old, new),");
    let oram_write_trace_is_shape_only = oram_source.contains("pub(crate) struct OramWrite {")
        && oram_source.contains("len: usize,")
        && oram_source.contains("class: WriteClass,")
        && !oram_source.contains("pub old: Vec<u8>")
        && !oram_source.contains("pub new: Vec<u8>")
        && !oram_source.contains("pub new_zero: bool,");
    let oram_write_fields_private = oram_source.contains("location: String,")
        && oram_source.contains("len: usize,")
        && oram_source.contains("class: WriteClass,")
        && !oram_source.contains("pub location: String,")
        && !oram_source.contains("pub len: usize,")
        && !oram_source.contains("pub class: WriteClass,");
    let oram_write_trace_projects_to_public_shape = oram_source.contains(
        "pub(crate) fn from_buffers(location: impl Into<String>, old: &[u8], new: &[u8]) -> Self",
    ) && oram_source
        .contains("pub(crate) fn with_object(self, object: &str) -> PhysicalWriteEvent {")
        && oram_source.contains(
            "PhysicalWriteEvent::from_shape(object, self.location, self.len, self.class)",
        );
    let map_entry_fields_private = oram_source.contains(
        "pub(crate) struct MapEntry {\n    occupied: bool,\n    key: Value,\n    value: Value,\n}",
    );
    let map_entry_api_is_explicit = oram_source.contains("pub(crate) fn new(")
        && oram_source.contains("pub(crate) fn is_occupied(&self) -> bool {")
        && oram_source.contains("pub(crate) fn key(&self) -> &Value {")
        && oram_source.contains("pub(crate) fn value(&self) -> &Value {")
        && oram_source.contains("pub(crate) fn matches_key(&self, key: &Value) -> bool {")
        && oram_source.contains("pub(crate) fn set_value(&mut self, value: Value) {")
        && oram_source.contains("pub(crate) fn set_vacant(&mut self, zero_value: Value) {")
        && oram_source.contains("pub(crate) fn occupy(&mut self, key: Value, value: Value) {")
        && objects_source.contains("entry.matches_key(key)")
        && objects_source.contains("!entry.is_occupied()")
        && objects_source.contains("entry.value().clone()")
        && objects_source.contains("entry.set_vacant(")
        && objects_source.contains("entry.set_value(")
        && objects_source.contains("entry.occupy(")
        && oram_source.contains("entry.matches_key(key)")
        && oram_source.contains("entry.value().clone()")
        && oram_source.contains("entry.set_value(")
        && oram_source.contains("entry.occupy(");
    let runtime_public_field_lines = [
        ("runtime/uo-evm/src/kernel.rs", kernel_source.as_str()),
        (
            "runtime/uo-evm/src/runtime.rs",
            runtime_module_source.as_str(),
        ),
        ("runtime/uo-evm/src/state.rs", state_source.as_str()),
        (
            "runtime/uo-evm/src/controller.rs",
            controller_source.as_str(),
        ),
        ("runtime/uo-evm/src/theorem.rs", theorem_source.as_str()),
        ("runtime/uo-evm/src/oram.rs", oram_source.as_str()),
        ("runtime/uo-evm/src/objects.rs", objects_source.as_str()),
    ]
    .into_iter()
    .flat_map(|(path, source)| {
        source.lines().filter_map(move |line| {
            let trimmed = line.trim();
            if trimmed.starts_with("pub ") && trimmed.ends_with(',') && !trimmed.contains(" fn ") {
                Some(format!("{path}:{trimmed}"))
            } else {
                None
            }
        })
    })
    .collect::<Vec<_>>();
    let expected_runtime_public_field_lines = vec![
        String::from("runtime/uo-evm/src/oram.rs:pub scheme: String,"),
        String::from("runtime/uo-evm/src/oram.rs:pub capacity: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub block_size: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub bucket_size: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub bucket_count: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub blocks_per_bucket: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub tree_height: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub stash_bound: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub recursion_depth: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub metadata_pages: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub metadata_pages_per_access: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub accesses_per_call: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub buckets_per_access: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub directory_page_entries: usize,"),
        String::from("runtime/uo-evm/src/oram.rs:pub directory_page_bytes: usize,"),
    ];
    let runtime_public_field_surface_is_public_shape_only =
        runtime_public_field_lines == expected_runtime_public_field_lines;
    let oram_storage_fields_private = oram_source.contains("directory_pages: Vec<Vec<u8>>,")
        && oram_source.contains("buckets: Vec<Vec<u8>>,")
        && oram_source.contains("access_counter_slot: Vec<u8>,")
        && !oram_source.contains("pub directory_pages: Vec<Vec<u8>>,")
        && !oram_source.contains("pub buckets: Vec<Vec<u8>>,")
        && !oram_source.contains("pub access_counter_slot: Vec<u8>,");
    let oram_state_fields_private = oram_source.contains(
        "pub(crate) struct OramState {\n    parameters: OramParameters,\n    entries: Vec<MapEntry>,\n    position_map: Vec<Option<usize>>,\n    stash: Vec<OramBlock>,\n    storage: OramStorage,\n    access_counter: u64,\n    cipher: StoreCipher,\n}",
    );
    let oram_state_api_is_explicit = oram_source
        .contains("pub(crate) fn parameters(&self) -> &OramParameters {")
        && oram_source.contains("pub(crate) fn path_bucket_count(&self) -> usize {")
        && oram_source.contains("pub(crate) fn is_cold(&self) -> bool {")
        && oram_source.contains("pub(crate) fn path_position_map_witness(")
        && oram_source.contains("pub(crate) fn access_counter_witness(")
        && objects_source.contains("object.oram.is_cold()")
        && objects_source.contains("object.oram.parameters()")
        && objects_source.contains("object.oram.path_bucket_count()")
        && objects_source.contains("object.oram.path_position_map_witness(&object.spec)?")
        && objects_source.contains("object.oram.access_counter_witness(&object.spec)");
    let oram_transcript_fields_private = oram_source
        .contains("logical_accesses: Vec<LogicalEvent>,")
        && oram_source.contains("physical_reads: Vec<PhysicalReadEvent>,")
        && oram_source.contains("physical_writes: Vec<OramWrite>,")
        && oram_source.contains("zero_writes: usize,")
        && oram_source.contains("path_leaf: Option<usize>,")
        && oram_source.contains("path_transition: Option<RuntimePathOramTransitionWitness>,")
        && !oram_source.contains("pub logical_accesses: Vec<LogicalEvent>,")
        && !oram_source.contains("pub physical_reads: Vec<PhysicalReadEvent>,")
        && !oram_source.contains("pub physical_writes: Vec<OramWrite>,")
        && !oram_source.contains("pub zero_writes: usize,")
        && !oram_source.contains("pub path_leaf: Option<usize>,")
        && !oram_source.contains("pub path_transition: Option<RuntimePathOramTransitionWitness>,");
    let oram_transcript_api_is_explicit = oram_source
        .contains("pub(crate) fn into_runtime_trace_parts(")
        && objects_source.contains("transcript.into_runtime_trace_parts();");
    let oram_commit_fields_private = oram_source.contains("next: OramState,")
        && oram_source.contains("writes: Vec<OramWrite>,")
        && oram_source.contains("zero_writes: usize,")
        && !oram_source.contains("pub next: OramState,")
        && !oram_source.contains("pub writes: Vec<OramWrite>,")
        && !oram_source.contains("pub zero_writes: usize,");
    let oram_commit_api_is_explicit = oram_source
        .contains("pub(crate) fn into_object_commit_parts(self)")
        && objects_source.contains("commit.into_object_commit_parts();");
    let oram_block_fields_private = oram_source.contains(
        "pub(crate) struct OramBlock {\n    occupied: bool,\n    slot_index: usize,\n    leaf: usize,\n    key: Value,\n    value: Value,\n}",
    );
    let oram_bucket_fields_private = oram_source.contains(
        "pub(crate) struct OramBucket {\n    access_counter: u64,\n    bucket_index: usize,\n    live_entry_count: usize,\n    blocks: Vec<OramBlock>,\n}",
    );
    let store_write_api_uses_mutable_plaintext = store_store_source
        .contains("fn write_cell(&mut self, object: &str, value: &mut [u8]) -> Result<()>")
        && store_store_source
            .contains(".seal_and_wipe_into(aad.as_bytes(), value, &mut self.rng, slot)");
    let direct_store_seal_surface_files = collect_runtime_store_pattern_hits(".seal(")?;
    let expected_direct_store_seal_surface_files =
        vec![String::from("runtime/uo-store/src/codec.rs")];
    let direct_store_seal_surface_restricted =
        direct_store_seal_surface_files == expected_direct_store_seal_surface_files;
    let direct_store_open_surface_files = collect_runtime_store_pattern_hits(".open(")?;
    let expected_direct_store_open_surface_files =
        vec![String::from("runtime/uo-store/src/codec.rs")];
    let direct_store_open_surface_restricted =
        direct_store_open_surface_files == expected_direct_store_open_surface_files;
    let store_wipe_helper_surface_checks = [
        (
            "seal_and_wipe(",
            vec![
                String::from("runtime/uo-evm/src/objects.rs"),
                String::from("runtime/uo-evm/src/oram.rs"),
                String::from("runtime/uo-store/src/codec.rs"),
            ],
        ),
        (
            "seal_and_wipe_into(",
            vec![
                String::from("runtime/uo-evm/src/objects.rs"),
                String::from("runtime/uo-evm/src/oram.rs"),
                String::from("runtime/uo-store/src/codec.rs"),
                String::from("runtime/uo-store/src/store.rs"),
            ],
        ),
        (
            ".with_opened_payload(",
            vec![
                String::from("runtime/uo-evm/src/objects.rs"),
                String::from("runtime/uo-evm/src/oram.rs"),
            ],
        ),
    ]
    .into_iter()
    .map(|(pattern, expected_files)| {
        let files = collect_runtime_store_pattern_hits(pattern)?;
        Ok(json!({
            "pattern": pattern,
            "files": files,
            "expected_files": expected_files,
            "restricted": files == expected_files,
        }))
    })
    .collect::<Result<Vec<_>>>()?;
    let store_wipe_helper_surface_restricted =
        store_wipe_helper_surface_checks.iter().all(|entry| {
            entry["restricted"]
                .as_bool()
                .expect("store wipe helper restriction flag must be boolean")
        });
    let runtime_secret_state_inventory = vec![
        json!({
            "name": "ConfidentialCallInputs",
            "owner": "runtime/uo-evm/src/kernel.rs",
            "boundary": "shell projects only PublicCallSummary; ContractRuntime passes the raw confidential args straight into RuntimeKernel, which internalizes them into a private ConfidentialCallInputs buffer whose unwrap stays local to kernel.rs and whose buffered values wipe on drop",
            "checked": engine_keeps_confidential_call_inputs_inside_runtime
                && kernel_confidential_call_inputs_wrapper_restricted
                && confidential_call_inputs_wipe_on_drop
                && kernel_confidential_call_inputs_stay_inside_runtime,
        }),
        json!({
            "name": "PathOramFreshCoinPlan",
            "owner": "runtime/uo-evm/src/fresh_coins.rs",
            "boundary": "opaque public handle; raw per-object fresh-coin map stays inside crate::runtime, the handle is non-Clone and consumed by value, and the per-object tapes move into live shadow state without cloning",
            "checked": fresh_coin_plan_surface_restricted
                && fresh_coin_plan_zeroizes_on_drop
                && fresh_coin_plan_nonclone
                && engine_fresh_coin_api_consumes_plan
                && !engine_defines_fresh_coin_plan_directly
                && !engine_peeks_into_fresh_coin_map,
        }),
        json!({
            "name": "ConfidentialExecState",
            "owner": "runtime/uo-evm/src/kernel.rs",
            "boundary": "private slot-file state owned by RuntimeKernel",
            "checked": kernel_source.contains("struct ConfidentialExecState")
                && kernel_source.contains("slots: Vec<Option<Value>>")
                && confidential_exec_state_nonclone
                && confidential_exec_state_surface_restricted
                && confidential_execution_outcome_nonclone
                && confidential_execution_outcome_fields_private
                && confidential_exec_state_wipes_on_drop,
        }),
        json!({
            "name": "RuntimeCallOutcome",
            "owner": "runtime/uo-evm/src/runtime.rs",
            "boundary": "runtime-only per-call outcome bundle; construction is pinned to runtime.rs, state.rs, and shell.rs through an explicit constructor, state.rs is the only theorem-packaging consumer of its explicit handoff API, and engine.rs does not unpack it directly",
            "checked": runtime_call_outcome_runtime_private
                && runtime_call_outcome_nonclone
                && runtime_call_outcome_fields_private
                && runtime_call_outcome_api_is_explicit
                && runtime_call_outcome_surface_restricted
                && runtime_call_outcome_constructor_surface_restricted
                && runtime_call_outcome_theorem_consumer_surface_restricted
                && state_confidential_outcome_layering_is_explicit
                && theorem_finalizes_execution_trace
                && engine_public_trace_uses_output_shape_only,
        }),
        json!({
            "name": "TracedRuntimeCallOutcome",
            "owner": "runtime/uo-evm/src/state.rs",
            "boundary": "runtime/theorem post-call handoff bundle capturing the after-call hidden witness snapshot plus RuntimeCallOutcome before final execution-trace packaging",
            "checked": traced_runtime_call_outcome_nonclone
                && traced_runtime_call_outcome_surface_restricted
                && traced_runtime_call_outcome_api_is_explicit
                && traced_runtime_call_outcome_constructor_surface_restricted
                && traced_runtime_call_outcome_consumer_surface_restricted
                && theorem_finalizes_execution_trace
                && theorem_only_runtime_helper_visibility_restricted,
        }),
        json!({
            "name": "TracedRuntimeCallStart",
            "owner": "runtime/uo-evm/src/state.rs",
            "boundary": "runtime/theorem pre-call handoff token carrying the hidden committed-state snapshot without exposing the raw snapshot type outside state.rs",
            "checked": traced_runtime_call_start_nonclone
                && traced_runtime_call_start_surface_restricted
                && theorem_finalizes_execution_trace
                && theorem_only_runtime_helper_visibility_restricted,
        }),
        json!({
            "name": "TracedRuntimeCallWitnessState",
            "owner": "runtime/uo-evm/src/state.rs",
            "boundary": "runtime/theorem finalized hidden-witness bundle projecting before/after ORAM witness state without exposing raw snapshot helpers, and wiping those hidden witness vectors on drop",
            "checked": traced_runtime_call_witness_state_nonclone
                && traced_runtime_call_witness_state_surface_restricted
                && traced_runtime_call_witness_state_api_is_explicit
                && traced_runtime_call_witness_state_consumer_surface_restricted
                && traced_runtime_call_witness_state_wipes_on_drop
                && theorem_finalizes_execution_trace,
        }),
        json!({
            "name": "RuntimeShadowState / ConfidentialRuntimeShadowState / PublicRuntimeShadowState / CommittedRuntimeState",
            "owner": "runtime/uo-evm/src/state.rs",
            "boundary": "secret-bearing committed/shadow object maps stay inside crate::runtime, with distinct public and confidential shadow wrappers delimiting the shell boundary",
            "checked": state_wrapper_present
                && state_only_runtime_helper_surface_restricted
                && state_only_kernel_helper_surface_restricted,
        }),
        json!({
            "name": "CommittedRuntimeWitnessSnapshot",
            "owner": "runtime/uo-evm/src/state.rs",
            "boundary": "opaque hidden ORAM witness snapshot kept entirely inside state.rs, used only to assemble traced-call start/outcome/witness handoff bundles, and wiping its hidden vectors on drop",
            "checked": state_committed_runtime_witness_snapshot_is_opaque
                && committed_runtime_witness_snapshot_nonclone
                && committed_runtime_witness_snapshot_wipes_on_drop
                && committed_runtime_witness_snapshot_surface_restricted
                && theorem_only_runtime_helper_visibility_restricted
                && theorem_finalizes_execution_trace,
        }),
        json!({
            "name": "RuntimeObject graph",
            "owner": "runtime/uo-evm/src/objects.rs",
            "boundary": "object-level confidential state is non-Clone and helper-restricted",
            "checked": runtime_object_nonclone
                && confidential_object_api_surface_restricted,
        }),
        json!({
            "name": "OramState",
            "owner": "runtime/uo-evm/src/oram.rs",
            "boundary": "live ORAM logical state remains inside runtime with restricted helper use",
            "checked": oram_state_nonderive_clone
                && oram_buffer_reuse_restricted
                && oram_working_stash_capacity_restricted,
        }),
        json!({
            "name": "StoreCipher and plaintext staging",
            "owner": "runtime/uo-store/src/codec.rs and runtime/uo-store/src/store.rs",
            "boundary": "direct seal/open stays in codec; wipe-preserving helper surface is fixed",
            "checked": store_cipher_key_zeroizes_on_drop
                && store_cipher_exposes_wipe_helpers
                && direct_store_seal_surface_restricted
                && direct_store_open_surface_restricted
                && store_wipe_helper_surface_restricted,
        }),
    ];
    let runtime_secret_state_inventory_complete =
        runtime_secret_state_inventory.iter().all(|entry| {
            entry["checked"]
                .as_bool()
                .expect("runtime secret-state inventory check flag must be boolean")
        });

    Ok(json!({
        "engine_path": display_report_path(&engine_path),
        "shell_path": display_report_path(&shell_path),
        "fresh_coins_path": display_report_path(&fresh_coins_path),
        "kernel_path": display_report_path(&kernel_path),
        "objects_path": display_report_path(&objects_path),
        "oram_path": display_report_path(&oram_path),
        "state_path": display_report_path(&state_path),
        "controller_path": display_report_path(&controller_path),
        "theorem_path": display_report_path(&theorem_path),
        "probe_path": display_report_path(&probe_path),
        "store_codec_path": display_report_path(&store_codec_path),
        "store_store_path": display_report_path(&store_store_path),
        "checker_path": display_report_path(&checker_path),
        "core_trace_path": display_report_path(&core_trace_path),
        "runtime_module_path": display_report_path(&runtime_module_path),
        "engine_forbidden_helpers_absent": engine_forbidden_helpers_absent,
        "forbidden_engine_helper_checks": forbidden_engine_helper_checks,
        "engine_uses_opaque_committed_state": engine_uses_opaque_committed_state,
        "engine_uses_runtime_public_object_universe":
            engine_uses_runtime_public_object_universe,
        "engine_delegates_public_execution_to_runtime_theorem_bridge":
            engine_delegates_public_execution_to_runtime_theorem_bridge,
        "engine_delegates_confidential_execution_to_runtime_theorem_bridge":
            engine_delegates_confidential_execution_to_runtime_theorem_bridge,
        "engine_confidential_manifest_surface_absent":
            engine_confidential_manifest_surface_absent,
        "engine_does_not_import_public_runtime_kernel":
            engine_does_not_import_public_runtime_kernel,
        "shell_uses_shadow_wrapper": shell_uses_shadow_wrapper,
        "shell_uses_public_runtime_kernel": shell_uses_public_runtime_kernel,
        "public_shell_is_runtime_owned": public_shell_is_runtime_owned,
        "theorem_bridge_is_runtime_owned": theorem_bridge_is_runtime_owned,
        "state_uses_public_runtime_kernel": state_uses_public_runtime_kernel,
        "shell_confidential_surface_absent": shell_confidential_surface_absent,
        "engine_defines_fresh_coin_plan_directly": engine_defines_fresh_coin_plan_directly,
        "engine_uses_manifest_public_call_summary": engine_uses_manifest_public_call_summary,
        "engine_clones_call_args_directly": engine_clones_call_args_directly,
        "engine_fresh_coin_api_consumes_plan": engine_fresh_coin_api_consumes_plan,
        "engine_peeks_into_fresh_coin_map": engine_peeks_into_fresh_coin_map,
        "engine_imports_raw_runtime_kernel": engine_imports_raw_runtime_kernel,
        "engine_imports_runtime_object_directly": engine_imports_runtime_object_directly,
        "engine_constructs_runtime_phase_events_directly": engine_constructs_runtime_phase_events_directly,
        "engine_constructs_theorem_certificates_directly":
            engine_constructs_theorem_certificates_directly,
        "engine_assembles_execution_trace_directly": engine_assembles_execution_trace_directly,
        "engine_owns_raw_runtime_object_map": engine_owns_raw_runtime_object_map,
        "all_restricted_signatures_present": all_restricted_signatures_present,
        "restricted_signature_checks": restricted_signature_checks,
        "all_kernel_restricted_signatures_present": all_kernel_restricted_signatures_present,
        "kernel_restricted_signature_checks": kernel_restricted_signature_checks,
        "kernel_avoids_raw_escape_hatches": kernel_avoids_raw_escape_hatches,
        "public_kernel_facade_restricted_to_runtime":
            public_kernel_facade_restricted_to_runtime,
        "kernel_confidential_shadow_load_private":
            kernel_confidential_shadow_load_private,
        "raw_kernel_private_surface_checks": raw_kernel_private_surface_checks,
        "raw_kernel_private_surface_restricted": raw_kernel_private_surface_restricted,
        "all_state_restricted_signatures_present": all_state_restricted_signatures_present,
        "state_restricted_signature_checks": state_restricted_signature_checks,
        "runtime_object_derive_line": runtime_object_derive_line,
        "runtime_object_nonclone": runtime_object_nonclone,
        "oram_state_derive_line": oram_state_derive_line,
        "oram_state_nonderive_clone": oram_state_nonderive_clone,
        "fresh_coin_plan_derive_line": fresh_coin_plan_derive_line,
        "fresh_coin_plan_nonclone": fresh_coin_plan_nonclone,
        "contract_instance_clone_uses_cold_runtime_clone":
            contract_instance_clone_uses_cold_runtime_clone,
        "fresh_coin_plan_surface_checks": fresh_coin_plan_surface_checks,
        "fresh_coin_plan_surface_restricted": fresh_coin_plan_surface_restricted,
        "fresh_coin_plan_zeroizes_on_drop": fresh_coin_plan_zeroizes_on_drop,
        "state_wrapper_present": state_wrapper_present,
        "state_finalizes_runtime_phase_witness": state_finalizes_runtime_phase_witness,
        "state_committed_runtime_witness_snapshot_is_opaque":
            state_committed_runtime_witness_snapshot_is_opaque,
        "committed_runtime_witness_snapshot_derive_line":
            committed_runtime_witness_snapshot_derive_line,
        "committed_runtime_witness_snapshot_nonclone":
            committed_runtime_witness_snapshot_nonclone,
        "committed_runtime_witness_snapshot_wipes_on_drop":
            committed_runtime_witness_snapshot_wipes_on_drop,
        "committed_runtime_witness_snapshot_surface_files":
            committed_runtime_witness_snapshot_surface_files,
        "expected_committed_runtime_witness_snapshot_surface_files":
            expected_committed_runtime_witness_snapshot_surface_files,
        "committed_runtime_witness_snapshot_surface_restricted":
            committed_runtime_witness_snapshot_surface_restricted,
        "theorem_only_runtime_helper_visibility_restricted":
            theorem_only_runtime_helper_visibility_restricted,
        "engine_leaves_runtime_phase_tail_inside_runtime":
            engine_leaves_runtime_phase_tail_inside_runtime,
        "kernel_confidential_call_inputs_wrapper_restricted":
            kernel_confidential_call_inputs_wrapper_restricted,
        "confidential_call_inputs_wipe_on_drop":
            confidential_call_inputs_wipe_on_drop,
        "theorem_finalizes_execution_trace": theorem_finalizes_execution_trace,
        "theorem_private_surface_checks": theorem_private_surface_checks,
        "theorem_private_surface_restricted":
            theorem_private_surface_restricted,
        "theorem_finalize_input_fields_private":
            theorem_finalize_input_fields_private,
        "theorem_certificate_constructor_checks":
            theorem_certificate_constructor_checks,
        "theorem_certificate_constructor_surface_restricted":
            theorem_certificate_constructor_surface_restricted,
        "call_trace_bundle_surface_files":
            call_trace_bundle_surface_files,
        "expected_call_trace_bundle_surface_files":
            expected_call_trace_bundle_surface_files,
        "call_trace_bundle_surface_restricted":
            call_trace_bundle_surface_restricted,
        "call_trace_bundle_fields_private":
            call_trace_bundle_fields_private,
        "call_trace_bundle_api_is_explicit":
            call_trace_bundle_api_is_explicit,
        "controller_theorem_trace_constructor_files":
            controller_theorem_trace_constructor_files,
        "expected_controller_theorem_trace_constructor_files":
            expected_controller_theorem_trace_constructor_files,
        "controller_theorem_trace_constructor_surface_restricted":
            controller_theorem_trace_constructor_surface_restricted,
        "public_trace_helper_surface_checks":
            public_trace_helper_surface_checks,
        "public_trace_helper_surface_restricted":
            public_trace_helper_surface_restricted,
        "controller_public_call_summary_uses_manifest_only":
            controller_public_call_summary_uses_manifest_only,
        "public_call_summary_fields_private":
            public_call_summary_fields_private,
        "public_call_summary_api_is_explicit":
            public_call_summary_api_is_explicit,
        "controller_public_trace_uses_output_shape_only":
            controller_public_trace_uses_output_shape_only,
        "controller_output_shape_uses_manifest_return_len":
            controller_output_shape_uses_manifest_return_len,
        "theorem_public_trace_path_avoids_compiled_function":
            theorem_public_trace_path_avoids_compiled_function,
        "theorem_trace_bridge_surface_files":
            theorem_trace_bridge_surface_files,
        "expected_theorem_trace_bridge_surface_files":
            expected_theorem_trace_bridge_surface_files,
        "theorem_trace_bridge_surface_restricted":
            theorem_trace_bridge_surface_restricted,
        "theorem_trace_bridge_api_is_compact":
            theorem_trace_bridge_api_is_compact,
        "finalized_call_trace_fields_private":
            finalized_call_trace_fields_private,
        "finalized_call_trace_api_is_explicit":
            finalized_call_trace_api_is_explicit,
        "finalized_call_trace_consumption_surface_files":
            finalized_call_trace_consumption_surface_files,
        "expected_finalized_call_trace_consumption_surface_files":
            expected_finalized_call_trace_consumption_surface_files,
        "finalized_call_trace_consumption_surface_restricted":
            finalized_call_trace_consumption_surface_restricted,
        "engine_public_trace_uses_output_shape_only":
            engine_public_trace_uses_output_shape_only,
        "engine_keeps_confidential_call_inputs_inside_runtime":
            engine_keeps_confidential_call_inputs_inside_runtime,
        "state_prepares_confidential_manifest_plan":
            state_prepares_confidential_manifest_plan,
        "confidential_entrypoint_plan_surface_restricted":
            confidential_entrypoint_plan_surface_restricted,
        "kernel_executes_program_body_via_shared_dsl":
            kernel_executes_program_body_via_shared_dsl,
        "kernel_confidential_call_inputs_stay_inside_runtime":
            kernel_confidential_call_inputs_stay_inside_runtime,
        "kernel_exec_block_uses_confidential_slot_statements":
            kernel_exec_block_uses_confidential_slot_statements,
        "kernel_eval_uses_confidential_slot_exprs":
            kernel_eval_uses_confidential_slot_exprs,
        "kernel_exec_state_uses_slot_vector":
            kernel_exec_state_uses_slot_vector,
        "kernel_exec_state_avoids_name_keyed_env":
            kernel_exec_state_avoids_name_keyed_env,
        "kernel_scratch_accounting_uses_object_type_lengths":
            kernel_scratch_accounting_uses_object_type_lengths,
        "object_commit_io_scratch_uses_type_lengths":
            object_commit_io_scratch_uses_type_lengths,
        "kernel_hash_scratch_uses_public_program_bound":
            kernel_hash_scratch_uses_public_program_bound,
        "kernel_bounded_journal_checks": kernel_bounded_journal_checks,
        "kernel_bounded_journal_restricted": kernel_bounded_journal_restricted,
        "kernel_runtime_phase_helper_path_restricted":
            kernel_runtime_phase_helper_path_restricted,
        "state_routes_confidential_calls_through_runtime_kernel":
            state_routes_confidential_calls_through_runtime_kernel,
        "state_confidential_outcome_layering_is_explicit":
            state_confidential_outcome_layering_is_explicit,
        "runtime_call_outcome_surface_files": runtime_call_outcome_surface_files,
        "expected_runtime_call_outcome_surface_files":
            expected_runtime_call_outcome_surface_files,
        "runtime_call_outcome_surface_restricted":
            runtime_call_outcome_surface_restricted,
        "runtime_call_outcome_runtime_private":
            runtime_call_outcome_runtime_private,
        "runtime_call_outcome_derive_line": runtime_call_outcome_derive_line,
        "runtime_call_outcome_nonclone": runtime_call_outcome_nonclone,
        "runtime_call_outcome_fields_private":
            runtime_call_outcome_fields_private,
        "runtime_call_outcome_api_is_explicit":
            runtime_call_outcome_api_is_explicit,
        "runtime_call_outcome_constructor_surface_files":
            runtime_call_outcome_constructor_surface_files,
        "expected_runtime_call_outcome_constructor_surface_files":
            expected_runtime_call_outcome_constructor_surface_files,
        "runtime_call_outcome_constructor_surface_restricted":
            runtime_call_outcome_constructor_surface_restricted,
        "runtime_call_outcome_theorem_consumer_surface_files":
            runtime_call_outcome_theorem_consumer_surface_files,
        "expected_runtime_call_outcome_theorem_consumer_surface_files":
            expected_runtime_call_outcome_theorem_consumer_surface_files,
        "runtime_call_outcome_theorem_consumer_surface_restricted":
            runtime_call_outcome_theorem_consumer_surface_restricted,
        "traced_runtime_call_outcome_derive_line":
            traced_runtime_call_outcome_derive_line,
        "traced_runtime_call_outcome_nonclone":
            traced_runtime_call_outcome_nonclone,
        "traced_runtime_call_outcome_surface_files":
            traced_runtime_call_outcome_surface_files,
        "expected_traced_runtime_call_outcome_surface_files":
            expected_traced_runtime_call_outcome_surface_files,
        "traced_runtime_call_outcome_surface_restricted":
            traced_runtime_call_outcome_surface_restricted,
        "traced_runtime_call_outcome_api_is_explicit":
            traced_runtime_call_outcome_api_is_explicit,
        "traced_runtime_call_outcome_constructor_surface_files":
            traced_runtime_call_outcome_constructor_surface_files,
        "expected_traced_runtime_call_outcome_constructor_surface_files":
            expected_traced_runtime_call_outcome_constructor_surface_files,
        "traced_runtime_call_outcome_constructor_surface_restricted":
            traced_runtime_call_outcome_constructor_surface_restricted,
        "traced_runtime_call_outcome_consumer_surface_files":
            traced_runtime_call_outcome_consumer_surface_files,
        "expected_traced_runtime_call_outcome_consumer_surface_files":
            expected_traced_runtime_call_outcome_consumer_surface_files,
        "traced_runtime_call_outcome_consumer_surface_restricted":
            traced_runtime_call_outcome_consumer_surface_restricted,
        "traced_runtime_call_start_derive_line":
            traced_runtime_call_start_derive_line,
        "traced_runtime_call_start_nonclone":
            traced_runtime_call_start_nonclone,
        "traced_runtime_call_start_surface_files":
            traced_runtime_call_start_surface_files,
        "expected_traced_runtime_call_start_surface_files":
            expected_traced_runtime_call_start_surface_files,
        "traced_runtime_call_start_surface_restricted":
            traced_runtime_call_start_surface_restricted,
        "traced_runtime_call_witness_state_derive_line":
            traced_runtime_call_witness_state_derive_line,
        "traced_runtime_call_witness_state_nonclone":
            traced_runtime_call_witness_state_nonclone,
        "traced_runtime_call_witness_state_wipes_on_drop":
            traced_runtime_call_witness_state_wipes_on_drop,
        "traced_runtime_call_witness_state_surface_files":
            traced_runtime_call_witness_state_surface_files,
        "expected_traced_runtime_call_witness_state_surface_files":
            expected_traced_runtime_call_witness_state_surface_files,
        "traced_runtime_call_witness_state_surface_restricted":
            traced_runtime_call_witness_state_surface_restricted,
        "traced_runtime_call_witness_state_api_is_explicit":
            traced_runtime_call_witness_state_api_is_explicit,
        "traced_runtime_call_witness_state_consumer_surface_files":
            traced_runtime_call_witness_state_consumer_surface_files,
        "expected_traced_runtime_call_witness_state_consumer_surface_files":
            expected_traced_runtime_call_witness_state_consumer_surface_files,
        "traced_runtime_call_witness_state_consumer_surface_restricted":
            traced_runtime_call_witness_state_consumer_surface_restricted,
        "confidential_exec_state_surface_files": confidential_exec_state_surface_files,
        "expected_confidential_exec_state_surface_files":
            expected_confidential_exec_state_surface_files,
        "confidential_exec_state_surface_restricted":
            confidential_exec_state_surface_restricted,
        "confidential_exec_state_derive_line": confidential_exec_state_derive_line,
        "confidential_exec_state_nonclone": confidential_exec_state_nonclone,
        "confidential_kernel_run_outcome_derive_line":
            confidential_kernel_run_outcome_derive_line,
        "confidential_kernel_run_outcome_nonclone":
            confidential_kernel_run_outcome_nonclone,
        "confidential_kernel_run_outcome_surface_files":
            confidential_kernel_run_outcome_surface_files,
        "expected_confidential_kernel_run_outcome_surface_files":
            expected_confidential_kernel_run_outcome_surface_files,
        "confidential_kernel_run_outcome_surface_restricted":
            confidential_kernel_run_outcome_surface_restricted,
        "confidential_kernel_run_outcome_fields_private":
            confidential_kernel_run_outcome_fields_private,
        "confidential_kernel_run_outcome_api_is_explicit":
            confidential_kernel_run_outcome_api_is_explicit,
        "confidential_execution_outcome_derive_line":
            confidential_execution_outcome_derive_line,
        "confidential_execution_outcome_nonclone":
            confidential_execution_outcome_nonclone,
        "confidential_execution_outcome_fields_private":
            confidential_execution_outcome_fields_private,
        "confidential_exec_state_wipes_on_drop":
            confidential_exec_state_wipes_on_drop,
        "state_enforces_confidential_commit_budget":
            state_enforces_confidential_commit_budget,
        "oram_working_stash_capacity_checks": oram_working_stash_capacity_checks,
        "oram_working_stash_capacity_restricted":
            oram_working_stash_capacity_restricted,
        "oram_working_stash_avoids_midcall_reserve":
            oram_working_stash_avoids_midcall_reserve,
        "oram_buffer_reuse_checks": oram_buffer_reuse_checks,
        "oram_buffer_reuse_restricted": oram_buffer_reuse_restricted,
        "path_oram_restore_reuses_in_place_buffers":
            path_oram_restore_reuses_in_place_buffers,
        "state_owns_shadow_loading": state_owns_shadow_loading,
        "state_owns_committed_reconciliation":
            state_owns_committed_reconciliation,
        "state_owns_path_oram_fresh_coin_routing":
            state_owns_path_oram_fresh_coin_routing,
        "engine_does_not_lower_confidential_program_directly":
            engine_does_not_lower_confidential_program_directly,
        "kernel_confidential_select_uses_branchless_value_select":
            kernel_confidential_select_uses_branchless_value_select,
        "checker_uses_shared_confidential_kernel_lowering":
            checker_uses_shared_confidential_kernel_lowering,
        "checker_uses_manifest_slot_schedule_directly":
            checker_uses_manifest_slot_schedule_directly,
        "kernel_witness_validation_uses_manifest_confidential_slot_program":
            kernel_witness_validation_uses_manifest_confidential_slot_program,
        "kernel_witness_validation_tracks_confidential_kernel_lowering_errors":
            kernel_witness_validation_tracks_confidential_kernel_lowering_errors,
        "allocator_uses_manifest_kernel_step_budget":
            allocator_uses_manifest_kernel_step_budget,
        "translation_validation_uses_canonical_kernel_step_manifest":
            translation_validation_uses_canonical_kernel_step_manifest,
        "state_uses_checked_manifest_kernel_schedule":
            state_uses_checked_manifest_kernel_schedule,
        "trusted_kernel_slot_bundle_uses_manifest_confidential_slot_program":
            trusted_kernel_slot_bundle_uses_manifest_confidential_slot_program,
        "trusted_kernel_cli_uses_slot_bundle":
            trusted_kernel_cli_uses_slot_bundle,
        "trusted_kernel_probe_uses_slot_bundle":
            trusted_kernel_probe_uses_slot_bundle,
        "trusted_kernel_checker_uses_slot_bundle":
            trusted_kernel_checker_uses_slot_bundle,
        "runtime_phase_event_constructor_files": runtime_phase_event_constructor_files,
        "runtime_phase_event_constructor_surface_restricted":
            runtime_phase_event_constructor_surface_restricted,
        "runtime_kernel_refinement_witness_fields_private":
            runtime_kernel_refinement_witness_fields_private,
        "runtime_kernel_refinement_witness_api_is_explicit":
            runtime_kernel_refinement_witness_api_is_explicit,
        "runtime_kernel_refinement_witness_builder_path_restricted":
            runtime_kernel_refinement_witness_builder_path_restricted,
        "resource_event_constructor_files": resource_event_constructor_files,
        "resource_event_constructor_surface_restricted":
            resource_event_constructor_surface_restricted,
        "state_only_runtime_helper_surface_checks":
            state_only_runtime_helper_surface_checks,
        "state_only_runtime_helper_surface_restricted":
            state_only_runtime_helper_surface_restricted,
        "kernel_only_state_helper_surface_checks":
            kernel_only_state_helper_surface_checks,
        "kernel_only_state_helper_surface_restricted":
            kernel_only_state_helper_surface_restricted,
        "theorem_only_runtime_helper_surface_checks":
            theorem_only_runtime_helper_surface_checks,
        "theorem_only_runtime_helper_surface_restricted":
            theorem_only_runtime_helper_surface_restricted,
        "fullscan_buffer_reuse_checks": fullscan_buffer_reuse_checks,
        "fullscan_buffer_reuse_restricted": fullscan_buffer_reuse_restricted,
        "state_only_kernel_helper_surface_checks":
            state_only_kernel_helper_surface_checks,
        "state_only_kernel_helper_surface_restricted":
            state_only_kernel_helper_surface_restricted,
        "contract_runtime_entrypoint_surface_checks":
            contract_runtime_entrypoint_surface_checks,
        "contract_runtime_entrypoint_surface_restricted":
            contract_runtime_entrypoint_surface_restricted,
        "confidential_object_api_surface_checks":
            confidential_object_api_surface_checks,
        "confidential_object_api_surface_restricted":
            confidential_object_api_surface_restricted,
        "runtime_state_surface_checks": runtime_state_surface_checks,
        "runtime_state_surface_restricted": runtime_state_surface_restricted,
        "runtime_module_layout_present": runtime_module_layout_present,
        "store_cipher_key_zeroizes_on_drop": store_cipher_key_zeroizes_on_drop,
        "store_cipher_exposes_wipe_helpers": store_cipher_exposes_wipe_helpers,
        "execution_trace_omits_runtime_telemetry":
            execution_trace_omits_runtime_telemetry,
        "execution_trace_runtime_fields_private":
            execution_trace_runtime_fields_private,
        "execution_trace_runtime_api_is_explicit":
            execution_trace_runtime_api_is_explicit,
        "runtime_execution_trace_parts_fields_private":
            runtime_execution_trace_parts_fields_private,
        "runtime_execution_trace_parts_constructor_is_explicit":
            runtime_execution_trace_parts_constructor_is_explicit,
        "runtime_controller_certificate_fields_private":
            runtime_controller_certificate_fields_private,
        "runtime_controller_certificate_api_is_explicit":
            runtime_controller_certificate_api_is_explicit,
        "runtime_controller_observer_certificate_fields_private":
            runtime_controller_observer_certificate_fields_private,
        "runtime_controller_observer_certificate_api_is_explicit":
            runtime_controller_observer_certificate_api_is_explicit,
        "runtime_path_oram_hidden_certificate_fields_private":
            runtime_path_oram_hidden_certificate_fields_private,
        "runtime_path_oram_hidden_certificate_api_is_explicit":
            runtime_path_oram_hidden_certificate_api_is_explicit,
        "seeded_runtime_pathoram_witness_family_fields_private":
            seeded_runtime_pathoram_witness_family_fields_private,
        "seeded_runtime_pathoram_witness_family_api_is_explicit":
            seeded_runtime_pathoram_witness_family_api_is_explicit,
        "canonical_fresh_coin_witness_family_fields_private":
            canonical_fresh_coin_witness_family_fields_private,
        "canonical_fresh_coin_witness_family_api_is_explicit":
            canonical_fresh_coin_witness_family_api_is_explicit,
        "canonical_fresh_coin_theorem_input_fields_private":
            canonical_fresh_coin_theorem_input_fields_private,
        "canonical_fresh_coin_theorem_input_api_is_explicit":
            canonical_fresh_coin_theorem_input_api_is_explicit,
        "execution_trace_runtime_consumers_use_accessors":
            execution_trace_runtime_consumers_use_accessors,
        "execution_trace_builder_surface_files":
            execution_trace_builder_surface_files,
        "expected_execution_trace_builder_surface_files":
            expected_execution_trace_builder_surface_files,
        "execution_trace_builder_surface_restricted":
            execution_trace_builder_surface_restricted,
        "runtime_execution_trace_parts_constructor_surface_files":
            runtime_execution_trace_parts_constructor_surface_files,
        "expected_runtime_execution_trace_parts_constructor_surface_files":
            expected_runtime_execution_trace_parts_constructor_surface_files,
        "runtime_execution_trace_parts_constructor_surface_restricted":
            runtime_execution_trace_parts_constructor_surface_restricted,
        "runtime_controller_certificate_constructor_surface_files":
            runtime_controller_certificate_constructor_surface_files,
        "expected_runtime_controller_certificate_constructor_surface_files":
            expected_runtime_controller_certificate_constructor_surface_files,
        "runtime_controller_certificate_constructor_surface_restricted":
            runtime_controller_certificate_constructor_surface_restricted,
        "execution_trace_struct_literal_files":
            execution_trace_struct_literal_files,
        "execution_trace_struct_literal_surface_restricted":
            execution_trace_struct_literal_surface_restricted,
        "runtime_diagnostics_feature_declared":
            runtime_diagnostics_feature_declared,
        "probe_enables_runtime_diagnostics_feature":
            probe_enables_runtime_diagnostics_feature,
        "default_call_result_omits_runtime_telemetry":
            default_call_result_omits_runtime_telemetry,
        "diagnostic_call_api_exposes_runtime_telemetry":
            diagnostic_call_api_exposes_runtime_telemetry,
        "fresh_coin_api_gated_behind_feature":
            fresh_coin_api_gated_behind_feature,
        "diagnostic_api_gated_behind_feature":
            diagnostic_api_gated_behind_feature,
        "theorem_finalizer_omits_runtime_telemetry":
            theorem_finalizer_omits_runtime_telemetry,
        "probe_reads_runtime_telemetry_from_diagnostic_channel":
            probe_reads_runtime_telemetry_from_diagnostic_channel,
        "physical_write_event_is_shape_only": physical_write_event_is_shape_only,
        "physical_write_event_builders_are_shape_only":
            physical_write_event_builders_are_shape_only,
        "oram_write_trace_is_shape_only": oram_write_trace_is_shape_only,
        "oram_write_fields_private": oram_write_fields_private,
        "oram_write_trace_projects_to_public_shape":
            oram_write_trace_projects_to_public_shape,
        "map_entry_fields_private": map_entry_fields_private,
        "map_entry_api_is_explicit": map_entry_api_is_explicit,
        "runtime_public_field_lines": runtime_public_field_lines,
        "expected_runtime_public_field_lines": expected_runtime_public_field_lines,
        "runtime_public_field_surface_is_public_shape_only":
            runtime_public_field_surface_is_public_shape_only,
        "oram_storage_fields_private": oram_storage_fields_private,
        "oram_state_fields_private": oram_state_fields_private,
        "oram_state_api_is_explicit": oram_state_api_is_explicit,
        "oram_transcript_fields_private": oram_transcript_fields_private,
        "oram_transcript_api_is_explicit": oram_transcript_api_is_explicit,
        "oram_commit_fields_private": oram_commit_fields_private,
        "oram_commit_api_is_explicit": oram_commit_api_is_explicit,
        "oram_block_fields_private": oram_block_fields_private,
        "oram_bucket_fields_private": oram_bucket_fields_private,
        "store_write_api_uses_mutable_plaintext": store_write_api_uses_mutable_plaintext,
        "direct_store_seal_surface_files": direct_store_seal_surface_files,
        "direct_store_seal_surface_restricted": direct_store_seal_surface_restricted,
        "direct_store_open_surface_files": direct_store_open_surface_files,
        "direct_store_open_surface_restricted": direct_store_open_surface_restricted,
        "store_wipe_helper_surface_checks": store_wipe_helper_surface_checks,
        "store_wipe_helper_surface_restricted": store_wipe_helper_surface_restricted,
        "runtime_secret_state_inventory": runtime_secret_state_inventory,
        "runtime_secret_state_inventory_complete":
            runtime_secret_state_inventory_complete,
        "accepted": engine_forbidden_helpers_absent
            && engine_uses_opaque_committed_state
            && engine_uses_runtime_public_object_universe
            && engine_delegates_public_execution_to_runtime_theorem_bridge
            && engine_delegates_confidential_execution_to_runtime_theorem_bridge
            && engine_confidential_manifest_surface_absent
            && engine_does_not_import_public_runtime_kernel
            && shell_uses_shadow_wrapper
            && shell_uses_public_runtime_kernel
            && public_shell_is_runtime_owned
            && state_uses_public_runtime_kernel
            && shell_confidential_surface_absent
            && !engine_defines_fresh_coin_plan_directly
            && engine_uses_manifest_public_call_summary
            && !engine_clones_call_args_directly
            && engine_fresh_coin_api_consumes_plan
            && !engine_peeks_into_fresh_coin_map
            && !engine_imports_raw_runtime_kernel
            && !engine_imports_runtime_object_directly
            && !engine_constructs_runtime_phase_events_directly
            && !engine_constructs_theorem_certificates_directly
            && !engine_assembles_execution_trace_directly
            && !engine_owns_raw_runtime_object_map
            && all_restricted_signatures_present
            && all_kernel_restricted_signatures_present
            && kernel_avoids_raw_escape_hatches
            && public_kernel_facade_restricted_to_runtime
            && kernel_confidential_shadow_load_private
            && raw_kernel_private_surface_restricted
            && all_state_restricted_signatures_present
            && runtime_object_nonclone
            && oram_state_nonderive_clone
            && fresh_coin_plan_nonclone
            && contract_instance_clone_uses_cold_runtime_clone
            && state_wrapper_present
            && state_finalizes_runtime_phase_witness
            && state_committed_runtime_witness_snapshot_is_opaque
            && engine_leaves_runtime_phase_tail_inside_runtime
            && kernel_confidential_call_inputs_wrapper_restricted
            && theorem_bridge_is_runtime_owned
            && theorem_finalizes_execution_trace
            && theorem_private_surface_restricted
            && theorem_finalize_input_fields_private
            && theorem_certificate_constructor_surface_restricted
            && call_trace_bundle_surface_restricted
            && call_trace_bundle_fields_private
            && call_trace_bundle_api_is_explicit
            && controller_theorem_trace_constructor_surface_restricted
            && public_trace_helper_surface_restricted
            && controller_public_call_summary_uses_manifest_only
            && public_call_summary_fields_private
            && public_call_summary_api_is_explicit
            && controller_public_trace_uses_output_shape_only
            && controller_output_shape_uses_manifest_return_len
            && theorem_public_trace_path_avoids_compiled_function
            && engine_public_trace_uses_output_shape_only
            && engine_keeps_confidential_call_inputs_inside_runtime
            && state_prepares_confidential_manifest_plan
            && confidential_entrypoint_plan_surface_restricted
            && kernel_executes_program_body_via_shared_dsl
            && kernel_confidential_call_inputs_stay_inside_runtime
            && kernel_exec_block_uses_confidential_slot_statements
            && kernel_eval_uses_confidential_slot_exprs
            && kernel_exec_state_uses_slot_vector
            && kernel_exec_state_avoids_name_keyed_env
            && kernel_scratch_accounting_uses_object_type_lengths
            && object_commit_io_scratch_uses_type_lengths
            && kernel_hash_scratch_uses_public_program_bound
            && kernel_bounded_journal_restricted
            && kernel_runtime_phase_helper_path_restricted
            && state_routes_confidential_calls_through_runtime_kernel
            && state_confidential_outcome_layering_is_explicit
            && confidential_kernel_run_outcome_fields_private
            && confidential_kernel_run_outcome_api_is_explicit
            && state_enforces_confidential_commit_budget
            && oram_working_stash_capacity_restricted
            && oram_working_stash_avoids_midcall_reserve
            && oram_buffer_reuse_restricted
            && path_oram_restore_reuses_in_place_buffers
            && state_owns_shadow_loading
            && state_owns_committed_reconciliation
            && state_owns_path_oram_fresh_coin_routing
            && engine_does_not_lower_confidential_program_directly
            && kernel_confidential_select_uses_branchless_value_select
            && checker_uses_shared_confidential_kernel_lowering
            && checker_uses_manifest_slot_schedule_directly
            && kernel_witness_validation_uses_manifest_confidential_slot_program
            && kernel_witness_validation_tracks_confidential_kernel_lowering_errors
            && allocator_uses_manifest_kernel_step_budget
            && translation_validation_uses_canonical_kernel_step_manifest
            && state_uses_checked_manifest_kernel_schedule
            && trusted_kernel_slot_bundle_uses_manifest_confidential_slot_program
            && trusted_kernel_cli_uses_slot_bundle
            && trusted_kernel_probe_uses_slot_bundle
            && trusted_kernel_checker_uses_slot_bundle
            && runtime_phase_event_constructor_surface_restricted
            && runtime_kernel_refinement_witness_fields_private
            && runtime_kernel_refinement_witness_api_is_explicit
            && runtime_kernel_refinement_witness_builder_path_restricted
            && resource_event_constructor_surface_restricted
            && state_only_runtime_helper_surface_restricted
            && kernel_only_state_helper_surface_restricted
            && theorem_only_runtime_helper_surface_restricted
            && traced_runtime_call_outcome_surface_restricted
            && traced_runtime_call_outcome_api_is_explicit
            && traced_runtime_call_outcome_constructor_surface_restricted
            && traced_runtime_call_outcome_consumer_surface_restricted
            && traced_runtime_call_start_surface_restricted
            && traced_runtime_call_witness_state_surface_restricted
            && traced_runtime_call_witness_state_api_is_explicit
            && traced_runtime_call_witness_state_consumer_surface_restricted
            && fullscan_buffer_reuse_restricted
            && state_only_kernel_helper_surface_restricted
            && contract_runtime_entrypoint_surface_restricted
            && confidential_object_api_surface_restricted
            && runtime_state_surface_restricted
            && fresh_coin_plan_surface_restricted
            && fresh_coin_plan_zeroizes_on_drop
            && store_cipher_key_zeroizes_on_drop
            && store_cipher_exposes_wipe_helpers
            && execution_trace_omits_runtime_telemetry
            && execution_trace_runtime_fields_private
            && execution_trace_runtime_api_is_explicit
            && runtime_execution_trace_parts_fields_private
            && runtime_execution_trace_parts_constructor_is_explicit
            && runtime_controller_certificate_fields_private
            && runtime_controller_certificate_api_is_explicit
            && runtime_controller_observer_certificate_fields_private
            && runtime_controller_observer_certificate_api_is_explicit
            && runtime_path_oram_hidden_certificate_fields_private
            && runtime_path_oram_hidden_certificate_api_is_explicit
            && seeded_runtime_pathoram_witness_family_fields_private
            && seeded_runtime_pathoram_witness_family_api_is_explicit
            && canonical_fresh_coin_witness_family_fields_private
            && canonical_fresh_coin_witness_family_api_is_explicit
            && canonical_fresh_coin_theorem_input_fields_private
            && canonical_fresh_coin_theorem_input_api_is_explicit
            && execution_trace_runtime_consumers_use_accessors
            && execution_trace_builder_surface_restricted
            && runtime_execution_trace_parts_constructor_surface_restricted
            && runtime_controller_certificate_constructor_surface_restricted
            && execution_trace_struct_literal_surface_restricted
            && runtime_diagnostics_feature_declared
            && probe_enables_runtime_diagnostics_feature
            && default_call_result_omits_runtime_telemetry
            && diagnostic_call_api_exposes_runtime_telemetry
            && fresh_coin_api_gated_behind_feature
            && diagnostic_api_gated_behind_feature
            && theorem_finalizer_omits_runtime_telemetry
            && probe_reads_runtime_telemetry_from_diagnostic_channel
            && physical_write_event_is_shape_only
            && physical_write_event_builders_are_shape_only
            && oram_write_trace_is_shape_only
            && oram_write_fields_private
            && oram_write_trace_projects_to_public_shape
            && map_entry_fields_private
            && map_entry_api_is_explicit
            && runtime_public_field_surface_is_public_shape_only
            && oram_storage_fields_private
            && oram_state_fields_private
            && oram_state_api_is_explicit
            && oram_transcript_fields_private
            && oram_transcript_api_is_explicit
            && oram_commit_fields_private
            && oram_commit_api_is_explicit
            && oram_block_fields_private
            && oram_bucket_fields_private
            && store_write_api_uses_mutable_plaintext
            && direct_store_seal_surface_restricted
            && direct_store_open_surface_restricted
            && store_wipe_helper_surface_restricted
            && runtime_secret_state_inventory_complete
            && runtime_module_layout_present,
    }))
}

fn display_report_path(path: &Path) -> String {
    let root = repo_root();
    let report_path = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
    match report_path.strip_prefix(&root) {
        Ok(relative) => relative.display().to_string(),
        Err(_) => report_path.display().to_string(),
    }
}

fn display_output_bundle_path(options: &ProbeRunOptions, path: &Path) -> String {
    if let Some(out_dir) = &options.out_dir {
        let output_path = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
        let output_root = out_dir
            .canonicalize()
            .unwrap_or_else(|_| out_dir.to_path_buf());
        if let Ok(relative) = output_path.strip_prefix(&output_root) {
            return relative.display().to_string();
        }
        if let Ok(relative) = path.strip_prefix(out_dir) {
            return relative.display().to_string();
        }
    }
    display_report_path(path)
}

static BUILT_LEAN_CHECKERS: OnceLock<Mutex<BTreeSet<String>>> = OnceLock::new();

fn ensure_lean_checker(target: &'static str, description: &'static str) -> Result<PathBuf> {
    let built = BUILT_LEAN_CHECKERS.get_or_init(|| Mutex::new(BTreeSet::new()));
    let mut built = built
        .lock()
        .map_err(|_| anyhow!("failed to lock Lean checker build cache"))?;
    if !built.contains(target) {
        let lean_dir = repo_root().join("proof/lean");
        let output = Command::new("lake")
            .arg("build")
            .arg(target)
            .current_dir(&lean_dir)
            .output()
            .with_context(|| format!("building Lean {description} checker `{target}`"))?;
        if !output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!(
                "Lean {description} checker build failed for `{target}` with status {}\nstdout:\n{}\nstderr:\n{}",
                output.status,
                stdout,
                stderr,
            ));
        }
        built.insert(target.to_owned());
    }
    drop(built);
    let path = repo_root().join(format!("proof/lean/.lake/build/bin/{target}"));
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean {description} checker not found at {} after `lake build {target}`",
            path.display()
        ))
    }
}

fn lean_proofgrade_witness_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkProofGradeRuntimeWitness", "proof-grade witness")
}

fn lean_proofgrade_confidential_core_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeConfidentialCore",
        "proof-grade confidential-core",
    )
}

fn lean_proofgrade_confidential_core_slot_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeConfidentialCoreSlot",
        "proof-grade confidential-core slot",
    )
}

fn lean_proofgrade_confidential_core_shell_boundary_slot_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeConfidentialCoreShellBoundarySlot",
        "proof-grade confidential-core shell-boundary slot",
    )
}

fn lean_proofgrade_confidential_core_lowering_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeConfidentialCoreLowering",
        "proof-grade confidential-core lowering",
    )
}

fn lean_proofgrade_confidential_core_shell_boundary_lowering_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeConfidentialCoreShellBoundaryLowering",
        "proof-grade confidential-core shell-boundary lowering",
    )
}

fn lean_proofgrade_kernel_dsl_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkProofGradeRuntimeKernelDsl", "proof-grade kernel DSL")
}

fn lean_proofgrade_kernel_slot_dsl_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeKernelSlotDsl",
        "proof-grade kernel slot DSL",
    )
}

fn lean_proofgrade_kernel_lowering_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeKernelLowering",
        "proof-grade kernel lowering",
    )
}

fn lean_proofgrade_kernel_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkProofGradeRuntimeKernelWitness", "proof-grade kernel")
}

fn lean_proofgrade_kernel_refinement_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeKernelRefinementWitness",
        "proof-grade kernel refinement",
    )
}

fn lean_proofgrade_shell_boundary_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeShellBoundary",
        "proof-grade shell-boundary",
    )
}

fn lean_proofgrade_shell_boundary_slot_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeShellBoundarySlot",
        "proof-grade shell-boundary slot",
    )
}

fn lean_proofgrade_shell_boundary_lowering_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeShellBoundaryLowering",
        "proof-grade shell-boundary lowering",
    )
}

fn lean_proofgrade_trusted_kernel_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeRuntimeTrustedKernel",
        "proof-grade trusted-kernel",
    )
}

fn lean_proofgrade_translation_artifacts_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkProofGradeTranslationArtifacts",
        "proof-grade translation artifacts",
    )
}

fn lean_controller_certificate_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkRuntimeControllerCertificate",
        "controller certificate",
    )
}

fn lean_pathoram_hidden_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkRuntimePathOramHiddenCertificate", "path-ORAM hidden")
}

fn lean_witness_family_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkRuntimeWitnessFamily", "witness family")
}

fn lean_fresh_coin_family_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkRuntimeFreshCoinFamily", "fresh-coin family")
}

fn lean_fresh_coin_theorem_input_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkRuntimeFreshCoinTheoremInput",
        "fresh-coin theorem-input",
    )
}

fn lean_pathoram_pair_checker_path() -> Result<PathBuf> {
    ensure_lean_checker("checkPathOramPairCertificate", "path-ORAM pair")
}

fn lean_canonical_pathoram_pair_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkCanonicalPathOramPairCertificate",
        "canonical path-ORAM pair",
    )
}

fn lean_canonical_pathoram_paper_instantiation_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkCanonicalPathOramPaperInstantiation",
        "canonical path-ORAM paper instantiation",
    )
}

fn lean_canonical_pathoram_pair_theorem_input_checker_path() -> Result<PathBuf> {
    ensure_lean_checker(
        "checkCanonicalPathOramPairTheoremInput",
        "canonical path-ORAM pair theorem-input",
    )
}

fn temporary_witness_path(case_name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("clock should be after unix epoch")
        .as_nanos();
    let sanitized = sanitize_case_name(case_name);
    std::env::temp_dir().join(format!(
        "uo-runtime-witness-{}-{}-{}.json",
        process::id(),
        sanitized,
        nanos
    ))
}

fn write_temp_json<T: Serialize>(case_name: &str, value: &T) -> Result<(PathBuf, u64)> {
    let path = temporary_witness_path(case_name);
    let file = fs::File::create(&path)?;
    let mut writer = BufWriter::new(file);
    serde_json::to_writer(&mut writer, value)?;
    writer.flush()?;
    let bytes = fs::metadata(&path)?.len();
    Ok((path, bytes))
}

fn validate_tampered_json_case<T, F>(
    case_name: &str,
    artifact: &T,
    run_checker: F,
    mut summary: JsonValue,
) -> Result<JsonValue>
where
    T: Serialize,
    F: FnOnce(&Path) -> Result<Output>,
{
    let (artifact_path, artifact_json_bytes) = write_temp_json(case_name, artifact)?;
    let output = run_checker(&artifact_path)?;
    let lean_stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let lean_stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if output.status.success() {
        return Err(anyhow!(
            "Lean tamper validation unexpectedly accepted {} (artifact preserved at {})",
            case_name,
            artifact_path.display()
        ));
    }
    let _ = fs::remove_file(&artifact_path);
    let summary_object = summary
        .as_object_mut()
        .ok_or_else(|| anyhow!("tamper summary for {} is not a JSON object", case_name))?;
    summary_object.insert("artifact_json_bytes".into(), json!(artifact_json_bytes));
    summary_object.insert("lean_stdout".into(), json!(lean_stdout));
    summary_object.insert("lean_stderr".into(), json!(lean_stderr));
    summary_object.insert("accepted".into(), json!(false));
    summary_object.insert("rejected".into(), json!(true));
    Ok(summary)
}

fn validate_tampered_json_pair_case<L, R, F>(
    case_name: &str,
    left_label: &str,
    left: &L,
    right_label: &str,
    right: &R,
    run_checker: F,
    mut summary: JsonValue,
) -> Result<JsonValue>
where
    L: Serialize,
    R: Serialize,
    F: FnOnce(&Path, &Path) -> Result<Output>,
{
    let left_case_name = format!("{case_name}-{left_label}");
    let right_case_name = format!("{case_name}-{right_label}");
    let (left_path, left_json_bytes) = write_temp_json(&left_case_name, left)?;
    let (right_path, right_json_bytes) = write_temp_json(&right_case_name, right)?;
    let output = run_checker(&left_path, &right_path)?;
    let lean_stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let lean_stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if output.status.success() {
        return Err(anyhow!(
            "Lean tamper validation unexpectedly accepted {} (artifacts preserved at {} and {})",
            case_name,
            left_path.display(),
            right_path.display()
        ));
    }
    let _ = fs::remove_file(&left_path);
    let _ = fs::remove_file(&right_path);
    let summary_object = summary
        .as_object_mut()
        .ok_or_else(|| anyhow!("tamper summary for {} is not a JSON object", case_name))?;
    summary_object.insert(format!("{left_label}_json_bytes"), json!(left_json_bytes));
    summary_object.insert(format!("{right_label}_json_bytes"), json!(right_json_bytes));
    summary_object.insert("lean_stdout".into(), json!(lean_stdout));
    summary_object.insert("lean_stderr".into(), json!(lean_stderr));
    summary_object.insert("accepted".into(), json!(false));
    summary_object.insert("rejected".into(), json!(true));
    Ok(summary)
}

fn check_classifier_correctness(artifacts: &BenchArtifacts) -> Result<JsonValue> {
    let target = CallSpec {
        entrypoint: "classify(uint256)",
        args: vec![Value::Uint(1)],
    };
    let getters = vec![CallSpec {
        entrypoint: "peek()",
        args: vec![],
    }];
    let raw = run_scenario(&artifacts.raw, &[], &target, &getters)?;
    let uo = run_scenario(&artifacts.uo, &[], &target, &getters)?;
    Ok(json!({
        "benchmark": "FixedSlotClassifier",
        "raw": scenario_summary(&raw),
        "uo": scenario_summary(&uo),
        "equivalent": raw.getters == uo.getters && raw.target.return_value == uo.target.return_value,
    }))
}

fn check_authscan_correctness(artifacts: &BenchArtifacts) -> Result<JsonValue> {
    let setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    let target = CallSpec {
        entrypoint: "auth(bytes32)",
        args: vec![b32(2)],
    };
    let getters = vec![CallSpec {
        entrypoint: "readLast()",
        args: vec![],
    }];
    let raw = run_scenario(&artifacts.raw, &setup, &target, &getters)
        .context("correctness/AuthScan/raw scenario")?;
    let uo = run_scenario(&artifacts.uo, &setup, &target, &getters)
        .context("correctness/AuthScan/uo scenario")?;
    Ok(json!({
        "benchmark": "AuthScan",
        "raw": scenario_summary(&raw),
        "uo": scenario_summary(&uo),
        "equivalent": raw.getters == uo.getters && raw.target.return_value == uo.target.return_value,
    }))
}

fn check_mixer_correctness(artifacts: &BenchArtifacts) -> Result<JsonValue> {
    let key = b32(9);
    let setup = vec![CallSpec {
        entrypoint: "deposit(bytes32,uint256)",
        args: vec![key.clone(), Value::Uint(5)],
    }];
    let target = CallSpec {
        entrypoint: "withdraw(bytes32,uint256)",
        args: vec![key.clone(), Value::Uint(2)],
    };
    let getters = vec![
        CallSpec {
            entrypoint: "balanceOf(bytes32)",
            args: vec![key.clone()],
        },
        CallSpec {
            entrypoint: "totalValue()",
            args: vec![],
        },
    ];
    let raw = run_scenario(&artifacts.raw, &setup, &target, &getters)?;
    let uo = run_scenario(&artifacts.uo, &setup, &target, &getters)?;
    let oram = run_scenario(
        artifacts
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing mixer oram"))?,
        &setup,
        &target,
        &getters,
    )?;
    Ok(json!({
        "benchmark": "ConfidentialMixer",
        "raw": scenario_summary(&raw),
        "uo": scenario_summary(&uo),
        "oram": scenario_summary(&oram),
        "equivalent": raw.getters == uo.getters && raw.getters == oram.getters,
    }))
}

fn check_erc20_correctness(artifacts: &BenchArtifacts) -> Result<JsonValue> {
    let alice = addr(0x11);
    let bob = addr(0x22);
    let carol = addr(0x33);
    let setup = vec![
        CallSpec {
            entrypoint: "mint(address,uint256)",
            args: vec![alice.clone(), Value::Uint(10)],
        },
        CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![alice.clone(), bob.clone(), Value::Uint(4)],
        },
    ];
    let target = CallSpec {
        entrypoint: "transferFrom(address,address,address,uint256)",
        args: vec![alice.clone(), bob.clone(), carol.clone(), Value::Uint(3)],
    };
    let getters = vec![
        CallSpec {
            entrypoint: "balanceOf(address)",
            args: vec![alice.clone()],
        },
        CallSpec {
            entrypoint: "balanceOf(address)",
            args: vec![carol.clone()],
        },
        CallSpec {
            entrypoint: "allowanceOf(address,address)",
            args: vec![alice.clone(), bob.clone()],
        },
    ];
    let raw = run_scenario(&artifacts.raw, &setup, &target, &getters)?;
    let uo = run_scenario(&artifacts.uo, &setup, &target, &getters)?;
    let oram = run_scenario(
        artifacts
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing erc20 oram"))?,
        &setup,
        &target,
        &getters,
    )?;
    Ok(json!({
        "benchmark": "ERC20Lite",
        "raw": scenario_summary(&raw),
        "uo": scenario_summary(&uo),
        "oram": scenario_summary(&oram),
        "equivalent": raw.getters == uo.getters && raw.getters == oram.getters,
    }))
}

fn check_registry_correctness(artifacts: &BenchArtifacts) -> Result<JsonValue> {
    let key = b32(4);
    let setup = vec![CallSpec {
        entrypoint: "upsert(bytes32,uint256)",
        args: vec![key.clone(), Value::Uint(9)],
    }];
    let target = CallSpec {
        entrypoint: "clearIfMatch(bytes32,uint256)",
        args: vec![key.clone(), Value::Uint(9)],
    };
    let getters = vec![CallSpec {
        entrypoint: "read(bytes32)",
        args: vec![key.clone()],
    }];
    let raw = run_scenario(&artifacts.raw, &setup, &target, &getters)?;
    let uo = run_scenario(&artifacts.uo, &setup, &target, &getters)?;
    Ok(json!({
        "benchmark": "RegistryCRUD",
        "raw": scenario_summary(&raw),
        "uo": scenario_summary(&uo),
        "equivalent": raw.getters == uo.getters && raw.target.return_value == uo.target.return_value,
    }))
}

fn run_trace_equivalence(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let classifier_raw = run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)
        .context("trace_equivalence/FixedSlotClassifier/raw")?;
    let classifier_uo = run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)
        .context("trace_equivalence/FixedSlotClassifier/uo")?;
    let classifier_same_same = run_classifier_same_same(&suite["FixedSlotClassifier"].raw)
        .context("trace_equivalence/FixedSlotClassifier/raw-sameSame")?;
    let auth_uo =
        run_authscan_experiment(&suite["AuthScan"].uo).context("trace_equivalence/AuthScan/uo")?;
    let mixer_uo = run_mixer_key_experiment(&suite["ConfidentialMixer"].uo)
        .context("trace_equivalence/ConfidentialMixer/uo")?;
    let mixer_oram = run_mixer_key_experiment(
        suite["ConfidentialMixer"]
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing mixer oram"))?,
    )
    .context("trace_equivalence/ConfidentialMixer/oram")?;
    let erc20_uo = run_erc20_allowance_key_experiment(&suite["ERC20Lite"].uo)
        .context("trace_equivalence/ERC20Lite/uo")?;
    let erc20_oram = run_erc20_allowance_key_experiment(
        suite["ERC20Lite"]
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing erc20 oram"))?,
    )
    .context("trace_equivalence/ERC20Lite/oram")?;
    let registry_uo = run_registry_key_experiment(&suite["RegistryCRUD"].uo)
        .context("trace_equivalence/RegistryCRUD/uo")?;
    Ok(json!({
        "positive_control": {
            "benchmark": "FixedSlotClassifier",
            "raw_opcode_equal": classifier_raw.opcode_equal,
            "raw_logical_access_equal": classifier_raw.logical_equal,
            "raw_logical_write_equal": classifier_raw.logical_write_equal,
            "raw_physical_read_equal": classifier_raw.physical_read_equal,
            "raw_physical_equal": classifier_raw.physical_equal,
            "same_same_control_equal": classifier_same_same.physical_equal,
        },
        "exact_uo": [
            trace_summary("FixedSlotClassifier", "uo", &classifier_uo),
            trace_summary("AuthScan", "uo", &auth_uo),
            trace_summary("ConfidentialMixer", "uo", &mixer_uo),
            trace_summary("ERC20Lite", "uo", &erc20_uo),
            trace_summary("RegistryCRUD", "uo", &registry_uo),
        ],
        "computational_uo": [
            trace_summary("ConfidentialMixer", "oram", &mixer_oram),
            trace_summary("ERC20Lite", "oram", &erc20_oram),
        ],
    }))
}

fn run_auc_reports(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let experiments = vec![
        (
            "FixedSlotClassifier",
            "raw",
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)
                .context("leakage_auc/FixedSlotClassifier/raw")?,
        ),
        (
            "FixedSlotClassifier",
            "uo",
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)
                .context("leakage_auc/FixedSlotClassifier/uo")?,
        ),
        (
            "AuthScan",
            "raw",
            run_authscan_experiment(&suite["AuthScan"].raw).context("leakage_auc/AuthScan/raw")?,
        ),
        (
            "AuthScan",
            "uo",
            run_authscan_experiment(&suite["AuthScan"].uo).context("leakage_auc/AuthScan/uo")?,
        ),
        (
            "RegistryCRUD",
            "raw",
            run_registry_experiment(&suite["RegistryCRUD"].raw)
                .context("leakage_auc/RegistryCRUD/raw")?,
        ),
        (
            "RegistryCRUD",
            "uo",
            run_registry_experiment(&suite["RegistryCRUD"].uo)
                .context("leakage_auc/RegistryCRUD/uo")?,
        ),
        (
            "ConfidentialMixer",
            "raw",
            run_mixer_experiment(&suite["ConfidentialMixer"].raw)
                .context("leakage_auc/ConfidentialMixer/raw")?,
        ),
        (
            "ConfidentialMixer",
            "uo",
            run_mixer_experiment(&suite["ConfidentialMixer"].uo)
                .context("leakage_auc/ConfidentialMixer/uo")?,
        ),
        (
            "ConfidentialMixer",
            "oram",
            run_mixer_experiment(
                suite["ConfidentialMixer"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing mixer oram"))?,
            )
            .context("leakage_auc/ConfidentialMixer/oram")?,
        ),
        (
            "ERC20Lite",
            "raw",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].raw)
                .context("leakage_auc/ERC20Lite/raw")?,
        ),
        (
            "ERC20Lite",
            "uo",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].uo)
                .context("leakage_auc/ERC20Lite/uo")?,
        ),
        (
            "ERC20Lite",
            "oram",
            run_erc20_allowance_value_experiment(
                suite["ERC20Lite"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing erc20 oram"))?,
            )
            .context("leakage_auc/ERC20Lite/oram")?,
        ),
    ];
    let reports = experiments
        .into_iter()
        .map(|(benchmark, mode, experiment)| {
            json!({
                "benchmark": benchmark,
                "mode": mode,
                "metric_auc": auc_report(&experiment.class0_metrics, &experiment.class1_metrics),
            })
        })
        .collect::<Vec<_>>();
    Ok(json!({ "reports": reports }))
}

fn run_mutual_information_reports(
    suite: &BTreeMap<&'static str, BenchArtifacts>,
) -> Result<JsonValue> {
    let experiments = vec![
        (
            "FixedSlotClassifier",
            "raw",
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)
                .context("mutual_information/FixedSlotClassifier/raw")?,
        ),
        (
            "FixedSlotClassifier",
            "uo",
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)
                .context("mutual_information/FixedSlotClassifier/uo")?,
        ),
        (
            "AuthScan",
            "raw",
            run_authscan_experiment(&suite["AuthScan"].raw)
                .context("mutual_information/AuthScan/raw")?,
        ),
        (
            "AuthScan",
            "uo",
            run_authscan_experiment(&suite["AuthScan"].uo)
                .context("mutual_information/AuthScan/uo")?,
        ),
        (
            "RegistryCRUD",
            "raw",
            run_registry_experiment(&suite["RegistryCRUD"].raw)
                .context("mutual_information/RegistryCRUD/raw")?,
        ),
        (
            "RegistryCRUD",
            "uo",
            run_registry_experiment(&suite["RegistryCRUD"].uo)
                .context("mutual_information/RegistryCRUD/uo")?,
        ),
        (
            "ConfidentialMixer",
            "raw",
            run_mixer_experiment(&suite["ConfidentialMixer"].raw)
                .context("mutual_information/ConfidentialMixer/raw")?,
        ),
        (
            "ConfidentialMixer",
            "uo",
            run_mixer_experiment(&suite["ConfidentialMixer"].uo)
                .context("mutual_information/ConfidentialMixer/uo")?,
        ),
        (
            "ConfidentialMixer",
            "oram",
            run_mixer_experiment(
                suite["ConfidentialMixer"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing mixer oram"))?,
            )
            .context("mutual_information/ConfidentialMixer/oram")?,
        ),
        (
            "ERC20Lite",
            "raw",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].raw)
                .context("mutual_information/ERC20Lite/raw")?,
        ),
        (
            "ERC20Lite",
            "uo",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].uo)
                .context("mutual_information/ERC20Lite/uo")?,
        ),
        (
            "ERC20Lite",
            "oram",
            run_erc20_allowance_value_experiment(
                suite["ERC20Lite"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing erc20 oram"))?,
            )
            .context("mutual_information/ERC20Lite/oram")?,
        ),
    ];
    let reports = experiments
        .into_iter()
        .map(|(benchmark, mode, experiment)| {
            json!({
                "benchmark": benchmark,
                "mode": mode,
                "metric_mi_bits": mi_report(&experiment.class0_metrics, &experiment.class1_metrics),
            })
        })
        .collect::<Vec<_>>();
    Ok(json!({ "reports": reports }))
}

fn run_overheads(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let mixer_key = b32(7);
    let raw = run_scenario(
        &suite["ConfidentialMixer"].raw,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![mixer_key.clone(), Value::Uint(3)],
        },
        &[],
    )
    .context("overheads/ConfidentialMixer/raw")?;
    let fullscan64 = run_scenario(
        suite["ConfidentialMixer"]
            .fullscan64
            .as_ref()
            .ok_or_else(|| anyhow!("missing fullscan64"))?,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![mixer_key.clone(), Value::Uint(3)],
        },
        &[],
    )
    .context("overheads/ConfidentialMixer/fullscan64")?;
    let oram = run_scenario(
        suite["ConfidentialMixer"]
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing mixer oram"))?,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![mixer_key, Value::Uint(3)],
        },
        &[],
    )
    .context("overheads/ConfidentialMixer/oram")?;
    Ok(json!({
        "cases": [
            {
                "benchmark": "ConfidentialMixer/deposit",
                "raw": scenario_overhead(&raw),
                "full_scan_64": scenario_overhead(&fullscan64),
                "oram_64": scenario_overhead(&oram),
                "oram_improves_physical_writes": oram.target.trace.physical_writes.len() < fullscan64.target.trace.physical_writes.len(),
            }
        ]
    }))
}

#[derive(Clone)]
struct ScenarioResult {
    target: CallResult,
    getters: Vec<Option<Value>>,
}

fn run_scenario(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    target: &CallSpec,
    getters: &[CallSpec],
) -> Result<ScenarioResult> {
    let mut instance = ContractInstance::deploy(artifact.clone())?;
    for call in setup {
        instance.call(call.entrypoint, call.args.clone())?;
    }
    let target = instance.call(target.entrypoint, target.args.clone())?;
    let getters = getters
        .iter()
        .map(|call| {
            instance
                .call(call.entrypoint, call.args.clone())
                .map(|result| result.return_value)
        })
        .collect::<Result<Vec<_>>>()?;
    Ok(ScenarioResult { target, getters })
}

#[derive(Clone)]
struct ExperimentOutcome {
    class0_metrics: Vec<BTreeMap<String, f64>>,
    class1_metrics: Vec<BTreeMap<String, f64>>,
    opcode_equal: bool,
    logical_equal: bool,
    logical_write_equal: bool,
    physical_read_equal: bool,
    physical_equal: bool,
}

fn run_fixed_classifier_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "classify(uint256)",
        vec![
            vec![Value::Uint(0)],
            vec![Value::Uint(2)],
            vec![Value::Uint(4)],
            vec![Value::Uint(6)],
        ],
        vec![
            vec![Value::Uint(1)],
            vec![Value::Uint(3)],
            vec![Value::Uint(5)],
            vec![Value::Uint(7)],
        ],
    )
}

fn run_classifier_same_same(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "sameSame(uint256)",
        vec![vec![Value::Uint(1)], vec![Value::Uint(3)]],
        vec![vec![Value::Uint(5)], vec![Value::Uint(7)]],
    )
}

fn run_authscan_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    let setup = vec![
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(0), b32(1)],
        },
        CallSpec {
            entrypoint: "seed(uint256,bytes32)",
            args: vec![Value::Uint(1), b32(2)],
        },
    ];
    run_binary_experiment(
        artifact,
        &setup,
        "auth(bytes32)",
        vec![vec![b32(9)], vec![b32(10)], vec![b32(11)], vec![b32(12)]],
        vec![vec![b32(1)], vec![b32(2)], vec![b32(1)], vec![b32(2)]],
    )
}

fn run_registry_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "upsert(bytes32,uint256)",
        vec![
            vec![b32(7), Value::Uint(0)],
            vec![b32(7), Value::Uint(0)],
            vec![b32(7), Value::Uint(0)],
            vec![b32(7), Value::Uint(0)],
        ],
        vec![
            vec![b32(7), Value::Uint(1)],
            vec![b32(7), Value::Uint(2)],
            vec![b32(7), Value::Uint(3)],
            vec![b32(7), Value::Uint(4)],
        ],
    )
}

fn run_mixer_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "deposit(bytes32,uint256)",
        vec![
            vec![b32(5), Value::Uint(0)],
            vec![b32(5), Value::Uint(0)],
            vec![b32(5), Value::Uint(0)],
            vec![b32(5), Value::Uint(0)],
        ],
        vec![
            vec![b32(5), Value::Uint(1)],
            vec![b32(5), Value::Uint(2)],
            vec![b32(5), Value::Uint(3)],
            vec![b32(5), Value::Uint(4)],
        ],
    )
}

fn run_mixer_key_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "deposit(bytes32,uint256)",
        vec![
            vec![b32(1), Value::Uint(3)],
            vec![b32(2), Value::Uint(3)],
            vec![b32(3), Value::Uint(3)],
            vec![b32(4), Value::Uint(3)],
        ],
        vec![
            vec![b32(9), Value::Uint(3)],
            vec![b32(10), Value::Uint(3)],
            vec![b32(11), Value::Uint(3)],
            vec![b32(12), Value::Uint(3)],
        ],
    )
}

fn run_registry_key_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "upsert(bytes32,uint256)",
        vec![
            vec![b32(1), Value::Uint(7)],
            vec![b32(2), Value::Uint(7)],
            vec![b32(3), Value::Uint(7)],
            vec![b32(4), Value::Uint(7)],
        ],
        vec![
            vec![b32(9), Value::Uint(7)],
            vec![b32(10), Value::Uint(7)],
            vec![b32(11), Value::Uint(7)],
            vec![b32(12), Value::Uint(7)],
        ],
    )
}

fn run_erc20_allowance_value_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    let owner = addr(0x11);
    let spender = addr(0x22);
    run_binary_experiment(
        artifact,
        &[],
        "approve(address,address,uint256)",
        vec![
            vec![owner.clone(), spender.clone(), Value::Uint(0)],
            vec![owner.clone(), spender.clone(), Value::Uint(0)],
            vec![owner.clone(), spender.clone(), Value::Uint(0)],
            vec![owner.clone(), spender.clone(), Value::Uint(0)],
        ],
        vec![
            vec![owner.clone(), spender.clone(), Value::Uint(1)],
            vec![owner.clone(), spender.clone(), Value::Uint(2)],
            vec![owner.clone(), spender.clone(), Value::Uint(3)],
            vec![owner, spender, Value::Uint(4)],
        ],
    )
}

fn run_erc20_allowance_key_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "approve(address,address,uint256)",
        vec![
            vec![addr(0x11), addr(0x21), Value::Uint(3)],
            vec![addr(0x12), addr(0x22), Value::Uint(3)],
            vec![addr(0x13), addr(0x23), Value::Uint(3)],
            vec![addr(0x14), addr(0x24), Value::Uint(3)],
        ],
        vec![
            vec![addr(0x31), addr(0x41), Value::Uint(3)],
            vec![addr(0x32), addr(0x42), Value::Uint(3)],
            vec![addr(0x33), addr(0x43), Value::Uint(3)],
            vec![addr(0x34), addr(0x44), Value::Uint(3)],
        ],
    )
}

fn run_binary_experiment(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    entrypoint: &'static str,
    class0: Vec<Vec<Value>>,
    class1: Vec<Vec<Value>>,
) -> Result<ExperimentOutcome> {
    let mut class0_metrics = Vec::new();
    let mut class1_metrics = Vec::new();
    let mut class0_hashes = Vec::new();
    let mut class1_hashes = Vec::new();
    for args in class0 {
        let result = run_target_call_with_diagnostics(artifact, setup, entrypoint, args)?;
        class0_hashes.push(result.call.trace.hashes());
        class0_metrics.push(extract_metrics(&result));
    }
    for args in class1 {
        let result = run_target_call_with_diagnostics(artifact, setup, entrypoint, args)?;
        class1_hashes.push(result.call.trace.hashes());
        class1_metrics.push(extract_metrics(&result));
    }
    Ok(ExperimentOutcome {
        opcode_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| {
            &hash.opcode_trace_hash
        }),
        logical_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| {
            &hash.logical_access_trace_hash
        }),
        logical_write_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| {
            &hash.logical_write_trace_hash
        }),
        physical_read_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| {
            &hash.physical_read_trace_hash
        }),
        physical_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| {
            &hash.physical_access_trace_hash
        }),
        class0_metrics,
        class1_metrics,
    })
}

fn run_target_call_with_diagnostics(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    entrypoint: &str,
    args: Vec<Value>,
) -> Result<DiagnosticCallResult> {
    let mut instance = ContractInstance::deploy(artifact.clone())?;
    for call in setup {
        instance.call(call.entrypoint, call.args.clone())?;
    }
    instance.call_with_diagnostics(entrypoint, args)
}

fn run_target_call(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    entrypoint: &str,
    args: Vec<Value>,
) -> Result<uo_core::ExecutionTrace> {
    Ok(
        run_target_call_with_diagnostics(artifact, setup, entrypoint, args)?
            .call
            .trace,
    )
}

fn exact_confidential_kernel_witness(
    trace: &uo_core::ExecutionTrace,
    artifact: &CompiledArtifact,
    entrypoint: &str,
) -> Result<Option<RuntimeKernelWitness>> {
    let function = artifact
        .contract
        .functions
        .iter()
        .find(|function| function.signature == entrypoint)
        .ok_or_else(|| anyhow!("artifact is missing entrypoint {}", entrypoint))?;
    if !function.confidential {
        return Ok(None);
    }
    Ok(Some(trace.runtime_kernel_witness_for_confidential(
        artifact, entrypoint,
    )?))
}

fn kernel_witness_summary(kernel_witness: Option<&RuntimeKernelWitness>) -> JsonValue {
    match kernel_witness {
        Some(kernel_witness) => json!({
            "present": true,
            "entrypoint": kernel_witness.entrypoint_id,
            "kernel_op_count": kernel_witness.kernel_steps.len(),
            "public_object_universe": kernel_witness.emitted_public_object_schedule(),
            "expected_public_object_universe": kernel_witness.expected_public_object_schedule(),
            "canonical_loaded_object_schedule": kernel_witness.canonical_loaded_object_schedule(),
            "kernel_step_public_object_schedule": kernel_witness.emitted_kernel_schedule().public_object_schedule(),
            "expected_kernel_step_public_object_schedule": kernel_witness.expected_kernel_schedule().map(|schedule| schedule.public_object_schedule()),
            "shell_contract": {
                "public_object_universe": kernel_witness.emitted_public_object_schedule(),
                "canonical_loaded_object_schedule": kernel_witness.canonical_loaded_object_schedule(),
                "kernel_step_public_object_schedule": kernel_witness.emitted_kernel_schedule().public_object_schedule(),
            },
            "resource_event_count": kernel_witness.resource_events.len(),
            "resource_events": kernel_witness.resource_events,
            "claimed_resource_state": {
                "peak_stack_words": kernel_witness.peak_stack_words,
                "value_scratch": {
                    "live_bytes": kernel_witness.value_scratch_live_bytes_end,
                    "peak_bytes": kernel_witness.value_scratch_peak_bytes,
                    "wipe_count": kernel_witness.value_scratch_wipe_count,
                },
                "hash_scratch": {
                    "live_bytes": kernel_witness.hash_scratch_live_bytes_end,
                    "peak_bytes": kernel_witness.hash_scratch_peak_bytes,
                    "wipe_count": kernel_witness.hash_scratch_wipe_count,
                },
                "io_scratch": {
                    "live_bytes": kernel_witness.io_scratch_live_bytes_end,
                    "peak_bytes": kernel_witness.io_scratch_peak_bytes,
                    "wipe_count": kernel_witness.io_scratch_wipe_count,
                },
            },
            "peak_stack_words": kernel_witness.peak_stack_words,
            "value_scratch_peak_bytes": kernel_witness.value_scratch_peak_bytes,
            "value_scratch_wipe_count": kernel_witness.value_scratch_wipe_count,
            "hash_scratch_peak_bytes": kernel_witness.hash_scratch_peak_bytes,
            "hash_scratch_wipe_count": kernel_witness.hash_scratch_wipe_count,
            "io_scratch_peak_bytes": kernel_witness.io_scratch_peak_bytes,
            "io_scratch_wipe_count": kernel_witness.io_scratch_wipe_count,
        }),
        None => json!({
            "present": false,
        }),
    }
}

fn runtime_kernel_refinement_witness_summary(
    runtime_kernel_refinement_witness: Option<&RuntimeKernelRefinementWitness>,
    kernel_witness: Option<&RuntimeKernelWitness>,
) -> JsonValue {
    match runtime_kernel_refinement_witness {
        Some(runtime_kernel_refinement_witness) => {
            let projected_kernel_schedule =
                runtime_kernel_refinement_witness.projected_kernel_schedule();
            let shadow_load_object_schedule =
                runtime_kernel_refinement_witness.shadow_load_object_schedule();
            let commit_object_schedule = runtime_kernel_refinement_witness.commit_object_schedule();
            let cold_store_object_schedule =
                runtime_kernel_refinement_witness.cold_store_object_schedule();
            let pre_committed_cold_object_schedule =
                runtime_kernel_refinement_witness.pre_committed_cold_object_schedule();
            let post_committed_cold_object_schedule =
                runtime_kernel_refinement_witness.post_committed_cold_object_schedule();
            let refines_shell_contract = kernel_witness.map(|kernel_witness| {
                projected_kernel_schedule == kernel_witness.emitted_kernel_schedule()
                    && pre_committed_cold_object_schedule
                        == kernel_witness.emitted_public_object_schedule()
                    && post_committed_cold_object_schedule
                        == kernel_witness.emitted_public_object_schedule()
                    && shadow_load_object_schedule
                        == kernel_witness.canonical_loaded_object_schedule()
                    && commit_object_schedule == kernel_witness.canonical_loaded_object_schedule()
                    && cold_store_object_schedule
                        == kernel_witness.canonical_loaded_object_schedule()
            });
            json!({
                "present": true,
                "event_count": runtime_kernel_refinement_witness.event_count(),
                "projected_kernel_step_count": projected_kernel_schedule.steps.len(),
                "projected_kernel_step_public_object_schedule": projected_kernel_schedule.public_object_schedule(),
                "pre_committed_cold_object_schedule": pre_committed_cold_object_schedule,
                "post_committed_cold_object_schedule": post_committed_cold_object_schedule,
                "shadow_load_object_schedule": shadow_load_object_schedule,
                "commit_object_schedule": commit_object_schedule,
                "cold_store_object_schedule": cold_store_object_schedule,
                "public_object_universe": kernel_witness
                    .map(RuntimeKernelWitness::emitted_public_object_schedule),
                "canonical_loaded_object_schedule": kernel_witness
                    .map(RuntimeKernelWitness::canonical_loaded_object_schedule),
                "shell_contract": kernel_witness.map(|kernel_witness| json!({
                    "public_object_universe": kernel_witness.emitted_public_object_schedule(),
                    "canonical_loaded_object_schedule": kernel_witness.canonical_loaded_object_schedule(),
                    "kernel_step_public_object_schedule": kernel_witness.emitted_kernel_schedule().public_object_schedule(),
                })),
                "projection_matches_kernel_witness": kernel_witness
                    .map(|kernel_witness| projected_kernel_schedule == kernel_witness.emitted_kernel_schedule()),
                "matches_canonical_kernel_object_schedule": kernel_witness.map(|kernel_witness| {
                    shadow_load_object_schedule == kernel_witness.canonical_loaded_object_schedule()
                }),
                "matches_public_object_universe_pre_boundary": kernel_witness.map(|kernel_witness| {
                    pre_committed_cold_object_schedule == kernel_witness.emitted_public_object_schedule()
                }),
                "matches_public_object_universe_post_boundary": kernel_witness.map(|kernel_witness| {
                    post_committed_cold_object_schedule == kernel_witness.emitted_public_object_schedule()
                }),
                "loaded_equals_committed": shadow_load_object_schedule == commit_object_schedule,
                "loaded_equals_cold_stored": shadow_load_object_schedule == cold_store_object_schedule,
                "committed_equals_cold_stored": commit_object_schedule == cold_store_object_schedule,
                "boundary_cold_object_schedules_complete": kernel_witness.map(|kernel_witness| {
                    pre_committed_cold_object_schedule == kernel_witness.emitted_public_object_schedule()
                        && post_committed_cold_object_schedule == kernel_witness.emitted_public_object_schedule()
                }),
                "refines_shell_contract": refines_shell_contract,
            })
        }
        None => json!({
            "present": false,
        }),
    }
}

fn runtime_shell_contract_summary(shell_contract: &RuntimeShellContract) -> JsonValue {
    json!({
        "public_object_count": shell_contract.public_object_universe.len(),
        "public_object_universe": shell_contract.public_object_universe,
        "canonical_loaded_object_count": shell_contract.canonical_loaded_object_schedule.len(),
        "canonical_loaded_object_schedule": shell_contract.canonical_loaded_object_schedule,
        "kernel_step_count": shell_contract.kernel_schedule.steps.len(),
        "kernel_opcode_count": shell_contract.kernel_schedule.opcodes.len(),
        "kernel_step_public_object_schedule": shell_contract.kernel_schedule.public_object_schedule(),
    })
}

fn runtime_shell_trace_summary(
    shell_trace: &RuntimeShellTrace,
    shell_contract: Option<&RuntimeShellContract>,
) -> JsonValue {
    let projected_from_events = shell_trace.projected_kernel_schedule_from_events();
    json!({
        "event_count": shell_trace.event_count(),
        "projected_kernel_step_count": shell_trace.projected_kernel_schedule().steps.len(),
        "projected_kernel_opcode_count": shell_trace.projected_kernel_schedule().opcodes.len(),
        "projected_kernel_step_public_object_schedule":
            shell_trace.projected_kernel_schedule().public_object_schedule(),
        "projected_kernel_step_count_from_events": projected_from_events.steps.len(),
        "projected_kernel_step_public_object_schedule_from_events":
            projected_from_events.public_object_schedule(),
        "pre_committed_cold_object_schedule": shell_trace.pre_committed_cold_object_schedule(),
        "shadow_load_object_schedule": shell_trace.shadow_load_object_schedule(),
        "commit_object_schedule": shell_trace.commit_object_schedule(),
        "cold_store_object_schedule": shell_trace.cold_store_object_schedule(),
        "post_committed_cold_object_schedule": shell_trace.post_committed_cold_object_schedule(),
        "summaries_match_events": shell_trace.summaries_match_events(),
        "loaded_equals_committed":
            shell_trace.shadow_load_object_schedule() == shell_trace.commit_object_schedule(),
        "loaded_equals_cold_stored":
            shell_trace.shadow_load_object_schedule() == shell_trace.cold_store_object_schedule(),
        "committed_equals_cold_stored":
            shell_trace.commit_object_schedule() == shell_trace.cold_store_object_schedule(),
        "replays_shell_contract":
            shell_contract.map(|shell_contract| shell_trace.replays_contract(shell_contract)),
        "refines_shell_contract":
            shell_contract.map(|shell_contract| shell_trace.refines_contract(shell_contract)),
    })
}

fn run_target_call_with_seed(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    entrypoint: &str,
    args: Vec<Value>,
    deploy_seed: u64,
) -> Result<uo_core::ExecutionTrace> {
    let mut instance = prepare_instance_with_seed(artifact, setup, deploy_seed)?;
    Ok(instance.call(entrypoint, args)?.trace)
}

fn prepare_instance_with_seed(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    deploy_seed: u64,
) -> Result<ContractInstance> {
    let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), deploy_seed)?;
    for call in setup {
        instance.call(call.entrypoint, call.args.clone())?;
    }
    Ok(instance)
}

fn collect_seeded_pathoram_family(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    entrypoint: &str,
    args: Vec<Value>,
    seed_count: usize,
) -> Result<CollectedSeededFamily> {
    let mut access_counters_before: Option<Vec<RuntimeOramAccessCounterWitness>> = None;
    let mut witnesses = Vec::with_capacity(seed_count);
    for seed in 0..seed_count {
        let trace =
            run_target_call_with_seed(artifact, setup, entrypoint, args.clone(), seed as u64)?;
        if let Some(expected) = &access_counters_before {
            if expected.as_slice() != trace.runtime_oram_access_counters_before() {
                return Err(anyhow!(
                    "seeded path-ORAM family for {} does not keep pre-call access counters public and stable across seeds",
                    entrypoint
                ));
            }
        } else {
            access_counters_before = Some(trace.runtime_oram_access_counters_before().to_vec());
        }
        witnesses.push(trace.runtime_refinement_witness()?);
    }
    Ok(CollectedSeededFamily {
        family: SeededRuntimePathOramWitnessFamily::new(witnesses)?,
        access_counters_before: access_counters_before.unwrap_or_default(),
    })
}

fn imported_oram_config(
    artifact: &CompiledArtifact,
    entrypoint: &str,
    witness: &RuntimeRefinementWitness,
    access_counters_before: &[RuntimeOramAccessCounterWitness],
) -> Result<ImportedOramConfig> {
    let manifest_entry = artifact
        .contract
        .manifest
        .entrypoints
        .get(entrypoint)
        .ok_or_else(|| anyhow!("manifest entry missing for {}", entrypoint))?;
    Ok(ImportedOramConfig {
        pub_data: ImportedOramPublicData {
            witness: ImportedOramEntrypointWitness {
                manifest: ImportedManifestWitness {
                    public_gas_budget: manifest_entry.public_gas_budget,
                    secret_args: manifest_entry.secret_args.clone(),
                    oram_accesses: manifest_entry
                        .oram_accesses
                        .iter()
                        .map(|(object_id, count)| (*object_id, *count))
                        .collect(),
                },
                entrypoint_id: witness.public_outcome().entrypoint_id.clone(),
                oram_objects: witness.oram_objects().to_vec(),
            },
            public_args: witness.public_outcome().public_args.clone(),
            access_counters: access_counters_before
                .iter()
                .map(|counter| (counter.object_id, counter.access_counter))
                .collect(),
        },
        secret_state: Vec::new(),
        secret_args: Vec::new(),
    })
}

fn normalize_path_oram_logical_event(event: &LogicalEvent) -> LogicalEvent {
    let detail = match event.kind.as_str() {
        "uooram_counter" => "counter".to_string(),
        "uooram_metadata_load" => "page:*".to_string(),
        "uooram_path_read" => "bucket:*".to_string(),
        _ => event.detail.clone(),
    };
    LogicalEvent {
        kind: event.kind.clone(),
        object: event.object.clone(),
        detail,
    }
}

fn imported_oram_public_view(witness: &RuntimeRefinementWitness) -> ImportedOramViewPublicPart {
    ImportedOramViewPublicPart {
        opcode_trace: witness.trace().opcode_trace.clone(),
        logical_accesses: witness
            .trace()
            .logical_accesses
            .iter()
            .map(normalize_path_oram_logical_event)
            .collect(),
        logical_writes: witness.trace().logical_writes.clone(),
        gas_used: witness.trace().gas_used,
    }
}

fn imported_path_oram_public_location(
    witness: &RuntimeRefinementWitness,
) -> ImportedPathOramStorageLocationTrace {
    ImportedPathOramStorageLocationTrace {
        read_labels: witness
            .trace()
            .physical_reads
            .iter()
            .map(|event| ImportedPathOramPhysicalEventLabel {
                object: event.object.clone(),
                location: normalize_path_oram_location(&event.object, &event.location),
            })
            .collect(),
        write_labels: witness
            .trace()
            .physical_writes
            .iter()
            .map(|event| ImportedPathOramPhysicalEventLabel {
                object: event.object.clone(),
                location: normalize_path_oram_location(&event.object, &event.location),
            })
            .collect(),
    }
}

fn normalize_path_oram_location(object: &str, location: &str) -> String {
    if location.starts_with(&format!("{object}@bucket")) {
        format!("{object}@bucket*")
    } else {
        location.to_string()
    }
}

fn imported_path_oram_storage_shape(
    witness: &RuntimeRefinementWitness,
) -> ImportedPathOramStorageShape {
    ImportedPathOramStorageShape {
        read_lengths: witness
            .trace()
            .physical_reads
            .iter()
            .map(|event| event.len)
            .collect(),
        write_classes: witness
            .trace()
            .physical_writes
            .iter()
            .map(|event| event.write_class.clone())
            .collect(),
        write_lengths: witness
            .trace()
            .physical_writes
            .iter()
            .map(|event| event.len)
            .collect(),
    }
}

fn hashes_equal<F>(
    class0: &[uo_core::TraceHashBundle],
    class1: &[uo_core::TraceHashBundle],
    project: F,
) -> bool
where
    F: Fn(&uo_core::TraceHashBundle) -> &String,
{
    class0
        .iter()
        .all(|lhs| class1.iter().all(|rhs| project(lhs) == project(rhs)))
}

fn trace_summary(benchmark: &str, mode: &str, outcome: &ExperimentOutcome) -> JsonValue {
    json!({
        "benchmark": benchmark,
        "mode": mode,
        "opcode_equal": outcome.opcode_equal,
        "logical_access_equal": outcome.logical_equal,
        "logical_write_equal": outcome.logical_write_equal,
        "physical_read_equal": outcome.physical_read_equal,
        "physical_trace_equal": outcome.physical_equal,
    })
}

fn extract_metrics(result: &DiagnosticCallResult) -> BTreeMap<String, f64> {
    let trace = &result.call.trace;
    let mut metrics = BTreeMap::new();
    metrics.insert(
        "bytes_read".into(),
        trace
            .physical_reads
            .iter()
            .map(|event| event.len)
            .sum::<usize>() as f64,
    );
    metrics.insert("backend_reads".into(), trace.physical_reads.len() as f64);
    metrics.insert(
        "bytes_written".into(),
        trace
            .physical_writes
            .iter()
            .map(|event| event.len)
            .sum::<usize>() as f64,
    );
    metrics.insert("backend_writes".into(), trace.physical_writes.len() as f64);
    metrics.insert("zero_writes".into(), result.telemetry.zero_writes as f64);
    metrics.insert(
        "update_only_fraction".into(),
        if trace.physical_writes.is_empty() {
            1.0
        } else {
            trace
                .physical_writes
                .iter()
                .filter(|event| event.class == WriteClass::Update)
                .count() as f64
                / trace.physical_writes.len() as f64
        },
    );
    metrics.insert(
        "boundary_events".into(),
        trace.theorem_trace.boundary_schedule.len() as f64,
    );
    if let Some(shape) = &trace.theorem_trace.controller_shape {
        metrics.insert(
            "controller_phase_count".into(),
            shape.controller_phase_order.len() as f64,
        );
        metrics.insert(
            "normalized_page_events".into(),
            shape
                .page_trace_regions
                .iter()
                .map(|region| region.event_budget)
                .sum::<usize>() as f64,
        );
    }
    metrics.insert(
        "same_writes".into(),
        trace
            .physical_writes
            .iter()
            .filter(|event| event.class == WriteClass::Same)
            .count() as f64,
    );
    metrics.insert(
        "set_writes".into(),
        trace
            .physical_writes
            .iter()
            .filter(|event| event.class == WriteClass::Set)
            .count() as f64,
    );
    metrics.insert(
        "clear_writes".into(),
        trace
            .physical_writes
            .iter()
            .filter(|event| event.class == WriteClass::Clear)
            .count() as f64,
    );
    metrics.insert(
        "update_writes".into(),
        trace
            .physical_writes
            .iter()
            .filter(|event| event.class == WriteClass::Update)
            .count() as f64,
    );
    metrics.insert("gas_used".into(), trace.gas_used as f64);
    metrics
}

fn auc_report(class0: &[BTreeMap<String, f64>], class1: &[BTreeMap<String, f64>]) -> JsonValue {
    let metric_names = metric_names(class0, class1);
    let mut report = serde_json::Map::new();
    for metric in metric_names {
        let negatives = class0
            .iter()
            .map(|metrics| *metrics.get(&metric).unwrap_or(&0.0))
            .collect::<Vec<_>>();
        let positives = class1
            .iter()
            .map(|metrics| *metrics.get(&metric).unwrap_or(&0.0))
            .collect::<Vec<_>>();
        report.insert(metric, json!(auc(&negatives, &positives)));
    }
    JsonValue::Object(report)
}

fn mi_report(class0: &[BTreeMap<String, f64>], class1: &[BTreeMap<String, f64>]) -> JsonValue {
    let metric_names = metric_names(class0, class1);
    let mut report = serde_json::Map::new();
    for metric in metric_names {
        let negatives = class0
            .iter()
            .map(|metrics| *metrics.get(&metric).unwrap_or(&0.0))
            .collect::<Vec<_>>();
        let positives = class1
            .iter()
            .map(|metrics| *metrics.get(&metric).unwrap_or(&0.0))
            .collect::<Vec<_>>();
        report.insert(
            metric,
            json!(mutual_information_bits(&negatives, &positives)),
        );
    }
    JsonValue::Object(report)
}

fn metric_names(
    class0: &[BTreeMap<String, f64>],
    class1: &[BTreeMap<String, f64>],
) -> BTreeSet<String> {
    class0
        .iter()
        .chain(class1.iter())
        .flat_map(|metrics| metrics.keys().cloned())
        .collect()
}

fn auc(negatives: &[f64], positives: &[f64]) -> f64 {
    if negatives.is_empty() || positives.is_empty() {
        return 0.5;
    }
    let mut wins = 0.0;
    for negative in negatives {
        for positive in positives {
            if positive > negative {
                wins += 1.0;
            } else if (*positive - *negative).abs() < f64::EPSILON {
                wins += 0.5;
            }
        }
    }
    wins / ((negatives.len() * positives.len()) as f64)
}

fn mutual_information_bits(negatives: &[f64], positives: &[f64]) -> f64 {
    let total = negatives.len() + positives.len();
    if total == 0 {
        return 0.0;
    }
    let mut counts: BTreeMap<(String, usize), usize> = BTreeMap::new();
    let mut value_counts: BTreeMap<String, usize> = BTreeMap::new();
    for value in negatives {
        let key = format!("{value:.6}");
        *counts.entry((key.clone(), 0)).or_insert(0) += 1;
        *value_counts.entry(key).or_insert(0) += 1;
    }
    for value in positives {
        let key = format!("{value:.6}");
        *counts.entry((key.clone(), 1)).or_insert(0) += 1;
        *value_counts.entry(key).or_insert(0) += 1;
    }
    let label_counts = [negatives.len(), positives.len()];
    let mut mi = 0.0;
    for ((value, label), joint_count) in counts {
        let p_xy = joint_count as f64 / total as f64;
        let p_x = *value_counts.get(&value).unwrap() as f64 / total as f64;
        let p_y = label_counts[label] as f64 / total as f64;
        mi += p_xy * (p_xy / (p_x * p_y)).log2();
    }
    mi
}

fn scenario_summary(result: &ScenarioResult) -> JsonValue {
    json!({
        "aborted": result.target.aborted,
        "return": format_value(result.target.return_value.as_ref()),
        "getters": result.getters.iter().map(|value| format_value(value.as_ref())).collect::<Vec<_>>(),
        "gas_used": result.target.trace.gas_used,
        "physical_writes": result.target.trace.physical_writes.len(),
    })
}

fn scenario_overhead(result: &ScenarioResult) -> JsonValue {
    json!({
        "gas_used": result.target.trace.gas_used,
        "physical_writes": result.target.trace.physical_writes.len(),
        "bytes_written": result.target.trace.physical_writes.iter().map(|event| event.len).sum::<usize>() as f64,
    })
}

fn format_value(value: Option<&Value>) -> JsonValue {
    match value {
        Some(Value::Bool(v)) => json!(v),
        Some(Value::Uint(v)) => json!(v),
        Some(Value::Bytes32(bytes)) => json!(format!("0x{}", hex::encode(bytes))),
        Some(Value::Address(bytes)) => json!(format!("0x{}", hex::encode(bytes))),
        Some(other) => json!(other.to_string()),
        None => JsonValue::Null,
    }
}

fn b32(byte: u8) -> Value {
    Value::Bytes32([byte; 32])
}

fn addr(byte: u8) -> Value {
    Value::Address([byte; 20])
}

fn artifact_readme(options: &ProbeRunOptions) -> String {
    let mut readme = String::from(
        r#"# UO Toolchain Artifact Results

This results bundle was generated from the local Rust workspace using the benchmark suite under `benches/raw/`.

The generated reports now also include `witness_validation.json`, which checks
representative theorem-backed runtime refinement witnesses against the
proof-grade Lean-side validator that now requires an exact embedded
artifact-derived confidential kernel-op trace plus an exact embedded public
kernel-step trace over `{ opcode, object_id? }`, and now also requires that
this admitted public schedule replay successfully to a finished state under the
modeled small-kernel semantics while fixing the exact final public object-id
schedule reconstructed from that replay. The proof-grade kernel witness now
also carries an explicit public resource-event trace over stack checks,
scratch reservations, and scratch wipes; Lean replays that trace against the
budget fields and the report summaries expose the emitted resource-event trace
directly alongside the exact claimed replayed resource state plus the emitted
and expected public object universe. The same witness report now also exposes
the lower-level runtime phase witness that bridges the concrete runtime back to
the small kernel ABI, including its exact pre/post committed-cold object
schedules over that public object universe, its shadow-load schedule,
commit-object schedule, cold-store schedule, the canonical loaded object
schedule reconstructed from the exported kernel witness, and the facts that
its projected kernel schedule matches that public kernel witness, that the
boundary schedules both match the full public object universe, and that the
loaded, committed, and cold-stored object sets all match the canonical
touched-object set. The Lean development now also packages that bridge as an
explicit `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem: the
real shell trace outside the confidential kernel is fixed by the public object
universe plus the canonical touched-object set induced by the public kernel
schedule. The exported shell trace now also carries the ordered public
runtime-phase event sequence itself, and the Rust/Lean checkers validate that
its summary schedules are honest projections and that the event trace replays
that public shell contract; the witness summaries now expose that
theorem-facing object
directly as a shell-contract summary plus a `refines_shell_contract` flag, with
direct exactness lemmas still available for the kernel witness's public object
universe and for the runtime phase witness's pre/post boundary schedules.
That post-call `cold_store_object` / `post_committed_cold_object` phase tail is
now also finalized behind the runtime state boundary instead of being assembled
in `engine.rs`, and the post-call proof-facing `ExecutionTrace` packaging now
also lives in `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer
constructs the controller-observer certificate, hidden Path-ORAM certificate,
or trusted-kernel bundle directly. Confidential expression and
statement interpretation for admitted entrypoints now also runs inside
`RuntimeKernel`, while the non-confidential interpreter now lives in the
explicit `runtime/uo-evm/src/shell.rs` module, so `engine.rs` is reduced to
public orchestration and the secret-bearing execution state sits behind the
smaller kernel boundary. That
confidential interpreter now also executes a slot-lowered kernel DSL rather
than a string-keyed env: admitted entrypoints are lowered to fixed slots in
`uo-core`, and `RuntimeKernel` stores live confidential values in a bounded
`Vec<Option<Value>>` slot file rather than a `BTreeMap<String, Value>`. The
low-level runtime object transition helpers that reopen shadow
state, commit objects, export hidden ORAM witnesses, and cold-store committed
state are now also compile-time restricted to the shared `crate::runtime`
module, and `RuntimeObject` no longer implements `Clone`, so those
secret-bearing paths are not directly callable from `engine.rs`. The
confidential-path `RuntimeKernel` entrypoints that shadow-load committed
state, run confidential calls, and commit public shadows are now likewise
visibility-restricted to `crate::runtime`, so the generic shell cannot call
those kernel hooks directly. `engine.rs` now delegates the full traced-call
execution path to `runtime/uo-evm/src/theorem.rs`, and that theorem bridge in
turn dispatches public execution to `shell.rs` and confidential execution to
`state.rs`; confidential
manifest-to-kernel planning is now fully internal to `ContractRuntime`, so
`engine.rs` no longer stages a `ConfidentialEntrypointPlan`, imports either
the raw `RuntimeKernel` or the public kernel facade directly, or threads the
manifest hash-scratch bound or confidential commit budget itself, and it now
derives the canonical public object universe from `ContractRuntime` rather
than the artifact-side state list while the same `ContractRuntime` boundary
now owns the ready-for-call coldness preflight over that universe as well,
and `shell.rs` now derives the public allocator plan from the manifest rather
than having the engine thread that setup detail in; the theorem-side
`begin_call_trace` path now triggers that runtime preflight rather than
`engine.rs` calling it directly, and the theorem finalizer now consumes the
whole `RuntimeCallOutcome` directly so the engine no longer unpacks kernel
witnesses, opcode traces, or return values only to feed them back into the
same theorem-path finalizer. The same report now also pins that authority
boundary directly: the runtime preflight and committed-state snapshot helpers
must appear only in `runtime/uo-evm/src/theorem.rs` in production code.
Confidential `Expr::Select` now also evaluates both admitted pure arms and
combines them with `Value::confidential_select` instead of branching on the
secret condition in Rust, while `uo-check` and the proof-grade
kernel-witness validator reject confidential select arms outside that
branchless pure fragment. Confidential `Expr::StructField` and
`Expr::ArrayIndex` are now both rejected from the admitted confidential
fragment entirely.
`runtime_boundary_validation.json` now checks that Rust-side boundary
directly by reading the runtime sources: it verifies that `engine.rs` does not
call the low-level runtime object helpers, that those helpers remain
restricted to `crate::runtime`, that `RuntimeObject` itself is not `Clone`,
that `ContractInstance::clone` goes through the cold committed-state clone
path, that `engine.rs` now holds only an opaque `ContractRuntime` wrapper and
delegates the entire traced-call lifecycle through the
`runtime/uo-evm/src/runtime.rs` bridge, that the runtime-owned theorem bridge
inside `runtime/uo-evm/src/theorem.rs` then dispatches public execution to
`shell.rs` and confidential execution to `state.rs`, that `shell.rs` itself
stays on the `PublicRuntimeKernel` plus
`PublicRuntimeShadowState` side of the boundary while the confidential path uses its own
`ConfidentialRuntimeShadowState` wrapper instead of reusing the public shadow
handle, and that `engine.rs` no longer constructs runtime phase-witness
events directly because the post-call phase tail is finalized
behind the runtime state boundary, no longer constructs theorem-side
certificates directly, no longer assembles `ExecutionTrace` directly
beyond `runtime/uo-evm/src/theorem.rs`, and no longer performs the
public output-shape computation or theorem-trace assembly piecemeal; instead
it delegates the whole theorem-finalization path through
`run_contract_call(...)` in `runtime/uo-evm/src/runtime.rs`, whose only
non-theorem call into that bridge is `run_traced_call(...)`. The same
boundary check also rejects engine-side calls to `output_shape_of`,
`build_theorem_trace`, and `finalize_execution_trace`, while requiring the
theorem module to keep deriving the public `OutputShape` from the checked
manifest's `return_canonical_len`. `engine.rs` also no longer clones the full
call argument vector just to recover public theorem-trace fields; instead the
controller path must derive a `PublicCallSummary` from the checked manifest's
`param_names`, `secret_args`, and manifest-stored `entry_input_len`, and
`ContractRuntime` must pass the remaining raw confidential argument vector
straight into `RuntimeKernel`, which internalizes it into a private
`ConfidentialCallInputs` buffer whose unwrap surface stays local to
`kernel.rs` and whose buffered `Value` payload now wipes on drop; the
theorem-finalization path must avoid depending on
`CompiledFunction` entirely while the public trace path sees only the
exported `OutputShape` rather than the full return payload, and the committed
before/after ORAM witness snapshot consumed by `theorem.rs` is now captured
through the theorem-side `run_traced_call(...)` bridge rather than by
`engine.rs`, and remains opaque outside the dedicated `state.rs` /
`theorem.rs` handoff; the same theorem-side context now also owns the public
`PublicCallSummary` and `CallRecorder`, and `shell.rs` resolves public
entrypoints from `(CompiledContract, signature)` so `theorem.rs` no longer
needs the raw `CompiledFunction`; `engine.rs` therefore no longer constructs
those theorem-path objects directly. The same report now also pins the
proof-artifact export path: `translation_validation.rs` must project
kernel-step views through `EntrypointManifest::canonical_kernel_step_manifest()`
instead of reading the duplicated raw manifest field directly. The same report now also pins the
theorem-facing constructor surface itself:
`ExecutionTrace::from_runtime_trace_parts(...)` and
`ExecutionTrace::materialize_runtime_trusted_kernel_bundle(...)` must stay
confined to `runtime/uo-evm/src/theorem.rs`, while the lower-level
`RuntimeControllerObserverCertificate::new`,
`RuntimePathOramHiddenCertificate::new`, and
`RuntimeTrustedKernelBundle::new_with_kernel_witness(...)` constructors stay
internal to `crates/uo-core/src/trace.rs`; direct `TheoremTrace { ... }`
construction must stay confined to `runtime/uo-evm/src/controller.rs`. The
same boundary report now also pins the public-trace helper surface:
`PublicCallSummary::from_manifest_entry(...)` and
`CallRecorder::begin_with_input_len(...)` must stay confined to
`runtime/uo-evm/src/state.rs`, while `output_shape_of(...)` must stay confined
to `runtime/uo-evm/src/controller.rs` and `runtime/uo-evm/src/theorem.rs`.
The same report also checks that the
proof-grade trusted-kernel path itself stays on the stronger slot-wrapped
artifact: `crates/uo-core/src/trusted_kernel.rs` must source the admitted
`confidential_slot_program` from the checked manifest, `uo-evm --format
trusted-kernel` must emit `runtime_trusted_kernel_slot_bundle`, the probe's
trusted-kernel validator must validate that same slot-wrapped artifact, and
`CheckProofGradeRuntimeTrustedKernel.lean` must load the corresponding slot
bundle checker path rather than the older bare trusted-kernel bundle loader.
The same boundary report also requires the hidden traced-call witness staging
buffers in `state.rs` to wipe on drop: both the internal committed-state ORAM
snapshot and the finalized traced-call witness bundle must clear their hidden
access-counter and position-map leaves unless they are explicitly consumed by
the theorem finalizer.
The same report also checks that the
confidential-path `RuntimeKernel` entrypoints for public shadow-loading,
public commit, and confidential execution are visibility-restricted to
`crate::runtime`, that the confidential shadow-load helper itself stays
private to `runtime/uo-evm/src/kernel.rs`, that `shell.rs` owns the
public-kernel facade while `state.rs` owns confidential execution setup
through explicit wrapper operations rather than raw `inner_mut` /
`into_inner` escape hatches, that `ConfidentialEntrypointPlan` is confined to
`runtime/uo-evm/src/state.rs`, that `RuntimeShadowState` and
`ConfidentialRuntimeShadowState` remain runtime-only while the shell-visible
handle stays `PublicRuntimeShadowState`, that only `shell.rs` may drive the
top-level `ContractRuntime` public-shadow entrypoints while only
`runtime/uo-evm/src/theorem.rs` may call
`runtime.run_confidential_entrypoint(...)`, and that confidential entrypoints
are sourced from the checked manifest's `confidential_slot_program` in
`runtime/uo-evm/src/state.rs` while that module delegates confidential
execution through `runtime/uo-evm/src/kernel.rs`, enforces the
manifest-derived confidential commit budget there as well, validates the slot
program against the manifest `kernel_steps` exactly once, and then carries
that checked manifest schedule forward as the canonical public budget /
witness schedule in both the runtime and `uo-check`, and
that the production kernel executes that shared slot DSL with a slot-vector
confidential state rather than a string-keyed map, and that the kernel-step
witness journal plus the lower-level
runtime phase witness journal are both explicit bounded-capacity journals
derived from public kernel-op/object bounds rather than plain growable
`Vec::new()` traces, that the kernel-side runtime phase journal routes
pre-boundary, kernel-step, and commit-object appends through explicit helper
methods instead of raw witness-vector mutation, and that the remaining public
shell-side commit /
witness lists now also start from explicit `Vec::with_capacity(...)` bounds,
and that live Path-ORAM stash state is rebuilt with public
`working_stash_capacity(...)` headroom up front, preserved across cold commits
with `.clear()`, and no longer grows mid-call through a late `reserve(...)`,
and that path-ORAM clones plus storage refresh now preserve and reuse those
public entry / position-map / stash capacities in place rather than silently
falling back to fresh zero-capacity vectors, and that touched Path-ORAM aborts
restore old state in place through `OramState::restore_from_old(...)` so
neither untouched nor aborted `UoOramMap` commits replace the whole shadow
ORAM object anymore, and that
full-scan array and
small-map cold commits clear and resize their existing logical buffers in
place, that array/small-map old-state restoration decodes back into those
same buffers rather than allocating replacement secret-bearing vectors, and
that written UO cell/array/small-map commits reuse their existing ciphertext
slot buffers in place while untouched commits keep their already-cloned
buffers instead of re-cloning old physical slots,
and that the remaining shadow-load, shadow-commit, and injected Path-ORAM
fresh-coin routing steps now live in `state.rs` rather than being assembled by
`kernel.rs`, and that confidential
`Expr::Select` routes through `Value::confidential_select` while the checker
and proof-grade kernel-witness validator both enforce the admitted
branchless-pure-arm fragment, and that checker, proof-grade validation, and
the runtime all reject confidential `Expr::StructField` and
confidential `Expr::ArrayIndex`, and that all direct confidential object API
call sites (`.get_cell`, `.set_cell`, `.get_array`, `.set_array`, `.get_map`,
`.put_map`) remain confined to `runtime/uo-evm/src/kernel.rs`. The same
report now also checks constructor authority for exported witnesses:
production runtime phase-witness events may only be constructed in
`runtime/uo-evm/src/kernel.rs`, while `runtime/uo-evm/src/state.rs` may only
finish the cold-store/post-committed tail through the shared
`append_cold_store_window(...)` helper, and production resource-event
witnesses may only be constructed in
`runtime/uo-allocator/src/lib.rs`. Inside the shared `crate::runtime` module,
the same report now also checks finer helper authority: secret-bearing
`RuntimeObject` reopen / commit / cold-store / witness-export / fresh-coin
helpers must be used only from `runtime/uo-evm/src/state.rs`, the
shadow-state helpers that reopen committed state or reconcile committed
shadows must be used only from `runtime/uo-evm/src/kernel.rs`, and the raw
kernel hooks `shadow_load_public_objects`, `commit_public_objects`, and
`run_confidential_call` must be invoked only from
`runtime/uo-evm/src/state.rs`. The probe-side production-source scan now also
strips `#[cfg(test)]` items without truncating later production code, so
those confinement checks continue to cover files that place test-only helpers
before additional production functions. The same report now also checks the
low-level `uo-store` helper layer: direct `StoreCipher::seal` /
`StoreCipher::open` use must stay inside `runtime/uo-store/src/codec.rs`, the
public wipe-preserving helper surface must stay at `seal_and_wipe` /
`seal_and_wipe_into` / `with_opened_payload`, the store write API must take
mutable plaintext buffers, and `StoreCipher` must zeroize its key on drop.
The runtime now also uses `seal_and_wipe_into` on written UO cell/array/
small-map commit paths plus ORAM bucket/counter rewrites, so those write
paths reuse existing sealed buffers in place where the public ciphertext shape
is already fixed. The same source-level check now also rejects regressions
back to ciphertext-snapshot write witnesses by requiring both
`PhysicalWriteEvent` and the internal ORAM write trace to retain only public
write shape (`location`, `len`, `class`) rather than `old`/`new` byte
vectors, with zero-write counts carried only as aggregate metrics instead of
per-write witness fields. `ExecutionTrace` now omits runtime telemetry
entirely, and ordinary `ContractInstance::call` results do too; the runtime
exposes the irreducible aggregate `zero_writes` count only through an
explicit feature-gated diagnostic result channel that is absent from the
default `uo-evm` surface, while `mplus-probe` derives bytes/read-write
counts, update fractions, and controller-shape counts from the raw trace
itself.
`confidential_fragment_validation.json` complements those source-level checks
with an artifact-level scan over the admitted UO benchmark suite: it counts
confidential `Select` nodes per entrypoint and confirms that the compiled
confidential bodies contain no non-branchless select arms, no confidential
`StructField`, and no confidential `ArrayIndex` forms.
`kernel_dsl_validation.json` adds the shared-DSL bridge itself to the artifact
story: for each representative confidential execution, the probe serializes
the exact lowered confidential-kernel program that Rust executes, Lean
re-derives its expected small-kernel step schedule from that DSL, and the
proof-grade runtime kernel witness must match the imported schedule exactly.
`kernel_slot_dsl_validation.json` now checks the slot-lowered half of that
same bridge directly: the probe serializes the manifest-carried fixed-slot
confidential program that `RuntimeKernel` actually executes, Lean re-derives
the same small-kernel schedule from the slot DSL, and the proof-grade runtime
kernel witness must match that slot-derived schedule exactly as well.
`kernel_lowering_validation.json` now upgrades that bridge to the runtime
kernel theorem surface: for each representative confidential execution, the
probe serializes both the manifest-carried source-named confidential program
and the manifest-carried slot confidential program, Lean validates the
imported lowering bundle, re-runs the canonical lowering algorithm over the
named DSL, and reconstructs the corresponding runtime
`RuntimeKernelLoweringBundle` whose named and slot schedules are both tied to
the same proof-grade kernel witness.
`confidential_core_validation.json` now closes that loop with a theorem-backed
joint check: for the same representative proof-grade runtime witnesses, Lean
checks both the runtime witness and the exact manifest-carried named
confidential program for the invoked entrypoint, so the shell-contract
refinement theorem is reported only for executions whose embedded kernel
witness matches the same DSL body that Rust executes. The artifact-derived
confidential-fragment witness remains in the report as a separate diagnostic
summary over the admitted fragment.
That combined checker now consumes one serialized confidential-core bundle
rather than coordinating separate witness files.
`confidential_core_slot_validation.json` now performs that same joint check
against the fixed-slot confidential program that `RuntimeKernel` executes,
so the runtime/refinement witness is tied not only to the source-named DSL
object but also to the slot-lowered kernel body that the concrete runtime
actually evaluates.
`confidential_core_shell_boundary_slot_validation.json` then lifts that
slot-only path across the shell boundary: it serializes the full runtime
witness together with the explicit shell-boundary bundle and the exact slot
confidential program for the same entrypoint, and Lean checks that the runtime
witness, shell-boundary bundle, and slot schedule all share one exact
proof-grade kernel witness and runtime phase witness without relying on the
named-to-slot lowering bundle.
`confidential_core_lowering_validation.json` then joins those two artifacts
back together: it serializes one runtime witness together with both the named
and slot confidential programs for the invoked entrypoint, requires the named
and slot bundles to pass their proof-grade Lean validators, and separately
requires Lean to recompute exactly the same slot program from the named DSL so
the exported shell/refinement witness is connected to the concrete slot
interpreter through a checker-visible canonical lowering step rather than
through Rust tests alone.
`confidential_core_shell_boundary_lowering_validation.json` lifts that
composition one layer higher: it serializes the full runtime witness together
with the explicit shell-boundary bundle and the named/slot confidential
programs for the same entrypoint, and Lean checks that the runtime witness,
shell-boundary bundle, and DSL lowering bridge all share one exact
proof-grade kernel witness and runtime phase witness rather than being
validated only as separate artifacts; the final checker therefore ties the
exported shell-refinement claim plus both the named and slot kernel schedules
to that same shared witness pair in one accepted bundle.
`kernel_model_alignment_validation.json` adds a source-level Rust/Lean
anti-drift check for the small-kernel ABI itself: it reads the Rust opcode
enum, the Rust confidential-kernel DSL enums, the Rust slot-DSL enums, and
the Rust kernel resource/refinement witness enums and checks that their
serialized vocabularies and DSL/proof-interface struct field names match the
explicit Lean opcode, confidential-DSL, slot-DSL, runtime-kernel-lowering,
runtime-confidential-core-lowering, runtime-confidential-core-shell-boundary-slot,
runtime-confidential-core-shell-boundary-lowering, runtime-trusted-kernel-slot,
runtime-shell-contract, runtime-shell-trace, runtime-shell-boundary,
runtime-shell-boundary-slot, runtime-shell-boundary-lowering, resource-event,
scratch-region, and refinement-event vocabularies exactly.
`kernel_refinement_validation.json` checks that lower-level runtime phase
witness directly against Lean together with the exact exported public kernel
witness, and
`shell_boundary_validation.json` checks the next proof-interface layer above
that witness pair: it serializes the exact exported `RuntimeShellContract`
and `RuntimeShellTrace` alongside the same proof-grade kernel witness and
runtime phase witness, and Lean checks both that those two explicit views are
exactly the contract/trace reconstructed from the witnesses, that the
shell-event trace replays the public shell contract, and that the
exported shell trace refines the exported shell contract, and
`shell_boundary_slot_validation.json` then ties that same shell-boundary
bundle directly to the exact fixed-slot confidential program that
`RuntimeKernel` executes, so Lean checks the shell-boundary refinement claim
and the slot schedule against one shared proof-grade kernel witness without
passing through the named DSL bundle, and
`shell_boundary_lowering_validation.json` then composes that shell interface
with the shared DSL/interpreter bridge: it serializes the exact shell-boundary
bundle together with the named and slot confidential programs for the same
entrypoint, and Lean checks both the shell-boundary refinement claim and the
named-to-slot lowering claim against one shared proof-grade kernel witness, and
`kernel_validation.json`, which checks the smaller standalone proof-grade
runtime kernel witness against Lean at that direct small-kernel boundary, and
`seeded_witness_validation.json`, which checks seeded path-ORAM witness
families against the Lean-side runtime-coins family validator.
`trusted_kernel_validation.json` adds the smaller theorem-facing bridge object:
it checks the proof-grade runtime trusted-kernel slot bundle against the
Lean-side validator, requiring the emitted trusted-kernel bundle to be
packaged together with the admitted fixed-slot confidential program for the
same entrypoint. Lean then checks the same exact embedded confidential
kernel-op trace plus exact public kernel-step trace, together with the same
successful modeled small-kernel replay condition and exact final public
object-id schedule, while packaging the public controller observer
certificate plus the hidden Path-ORAM certificate from which the full runtime
witness is reconstructed.
The direct kernel validator covers the same proof-grade benchmark family as the
trusted-kernel and refinement-witness validators, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
The direct runtime-phase validator covers that same proof-grade benchmark
family, so the lower-level concrete-to-kernel projection is checked on the
same multi-access and multi-object workloads.
The witness validator now also covers proof-grade path-ORAM executions beyond
`SingleAccessMap`, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
`controller_observer_validation.json` checks the direct public SGX/controller
observer certificate emitted from `ExecutionTrace` without going through the
hidden witness extractor.
That controller-observer validation now covers the same path-ORAM
multi-access and multi-object runs as well.
`pathoram_hidden_validation.json` checks the direct Path-ORAM hidden-state
certificate emitted from `ExecutionTrace` for the theorem-backed path-ORAM
benchmark vehicle, again without going through the full witness extractor.
The hidden-state validator now keys position-map certificates by `object_id`
rather than list position, which removes an accidental single-order assumption
and allows the multi-object `ERC20Lite/pathoram/transferFrom` witness to check
cleanly.
`fresh_coin_validation.json` now exercises the runtime's injected canonical
Path-ORAM fresh-coin tape interface, enumerates the full theorem-facing
fresh-coin seed space directly from the public scaffold, and invokes the Lean
fresh-coin family checker on the resulting complete family, now including the
multi-access `ConfidentialMixer/pathoram/deposit` family with its full
`262144`-seed canonical fresh-coin space. The same report now also preflights
oversized canonical fresh-coin families and, instead of stopping at
`skipped_by_budget`, falls back to a compact theorem-facing seed-space
certificate that checks one representative canonical seed together with the
full public fresh-coin scaffold and seed count.
`seeded_witness_validation.json` now also covers finite seeded path-ORAM
families beyond `SingleAccessMap`, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
`bridge_validation.json` is the focused imported-theorem engineering-bridge
report: it bundles the source-to-artifact translation checks together with the
direct controller certificate, direct hidden-state certificate, direct kernel
witness, direct runtime-phase refinement witness, explicit trusted-kernel
bundle, runtime refinement witness, and seeded witness-family
validators so the bridge status can be checked without inferring it from the
full artifact bundle.
`tamper_validation.json` complements those positive checks with end-to-end
negative evidence: it mutates representative direct controller/hidden
certificates, every proof-grade translation/runtime bridge artifact, and the
theorem-facing seeded/canonical witness-family, theorem-input, and
pair-certificate artifacts, then checks that the shipped Lean executables
reject those semantically drifted but still parseable artifacts.
`pathoram_pair_validation.json` now also checks paired seeded path-ORAM proof
input certificates beyond `SingleAccessMap`, including
`ConfidentialMixer/pathoram/deposit-pair` and
`ERC20Lite/pathoram/transferFrom-pair`. The broader `*/oram/*` benchmark
aliases now compile the same concrete `path_oram_local_posmap_v1` backend as
the explicit theorem-facing `*/pathoram/*` cases, so the witness validators
report only the `pathoram` names and do not duplicate those certificates under
the generic alias.
`canonical_pathoram_pair_validation.json` adds the canonical fresh-coin pair
certificate layer: it checks that the theorem-backed `SingleAccessMap`
Path-ORAM workloads share one common public observer across the full
canonical fresh-coin families, including the complete `256`-seed `put` family
and complete `4096`-seed `add` family. The remaining coverage gap is now
narrower: the small canonical pairs are still checked by full family
materialization, while very large canonical-pair workloads now fall back to a
compact theorem-facing pair certificate instead of being skipped. Under the
default `10 GiB` budget, the current report accepts the two `SingleAccessMap`
canonical pairs directly, and validates both
`ConfidentialMixer/pathoram/deposit-canonical-pair` and
`ERC20Lite/pathoram/transferFrom-canonical-pair` through the compact
theorem-input path with their concrete explicit-size estimates attached.
`reviewer_summary.json` plus `reviewer_summary.md` condense the current
paper-facing metrics into one machine-generated table: they record per-report
wall-clock cost, the largest materialized and estimated artifact-size fields,
the runtime overhead report, the current TCB table, explicit assumptions, and
non-empty source-line counts for the trusted Rust runtime surface plus the
repo-side Lean theorem/checker surface.

Security tiers:

- Exact-UO: `FixedSlotClassifier`, `AuthScan`, `ConfidentialMixer` full-scan, `ERC20Lite` full-scan, and `RegistryCRUD` use fixed-shape commits and normalized `M+` traces that are identical across secret variations in this instrumented abstract machine.
- Computational-UO: `ConfidentialMixer` ORAM and `ERC20Lite` ORAM use the concrete `path_oram_local_posmap_v1` backend, with fixed public controller shape, rerandomized bucket/block rewrites, and theorem-facing witness extraction on the same benchmark family.

Unsupported / rejected:

- inline assembly / Yul
- dynamic strings and dynamic bytes
- unbounded mappings and dynamic arrays without fixed public capacity
- recursion, `try/catch`, events, custom errors, `while` / `do while`, external calls, and early confidential returns

Prototype assumptions:

- `uint256` syntax is accepted, but the current executable prototype evaluates arithmetic in a bounded `u128` domain for the benchmark suite.
- The ORAM backend is an instrumented Path-ORAM-style runtime prototype with fixed public controller shape and rerandomized bucket/block rewrites; it is reported as computational-UO only.
- The guarantees are with respect to the abstract/runtime traces emitted by this artifact, including the normalized physical read/write schedules captured by the runtime, not every downstream machine-code or microarchitectural observer.
"#,
    );

    readme.push_str("\n\nArtifact packaging mode:\n\n");
    match options.materialization_mode {
        ArtifactMaterializationMode::Compact => {
            readme.push_str(
                "- This bundle uses compact artifact mode. Canonical Path-ORAM families and pair certificates larger than the configured compact budget remain validated through theorem-input certificates instead of full explicit materialization.\n",
            );
        }
        ArtifactMaterializationMode::Heavy => {
            readme.push_str(
                "- This bundle uses heavy artifact mode. Feasible canonical Path-ORAM families and pair certificates above the compact budget are materialized explicitly under `heavy_artifacts/`; only astronomically large seed spaces still fall back to compact theorem-input certificates.\n",
            );
        }
    }
    readme.push_str(&format!(
        "- Compact budget: `{}` bytes. Heavy-artifact budget: `{}` bytes.\n",
        options.compact_budget_bytes, options.heavy_budget_bytes
    ));
    if let Some(dir) = options.heavy_artifact_dir() {
        readme.push_str(&format!(
            "- Heavy artifacts are written under bundle-relative `{}` when heavy mode is selected.\n",
            display_output_bundle_path(options, &dir)
        ));
    }
    readme.push_str(
        "- `reproducibility_manifest.json` records every emitted file with its bundle-relative path, byte size, and SHA-256 digest.\n",
    );
    readme.push_str(
        "- `reviewer_summary.md` renders the same machine-generated reviewer table as `reviewer_summary.json` in Markdown form for paper/artifact writeups.\n",
    );
    readme.push_str(
        "- `./scripts/check_probe_reproducibility.sh` reruns `mplus-probe` twice and checks that the two output directories are byte-for-byte identical.\n",
    );
    readme
}

#[cfg(test)]
mod tests {
    use super::{
        check_authscan_correctness, compile_artifact, production_source_slice, BenchArtifacts,
    };
    use uo_core::ProgramMode;

    #[test]
    fn authscan_correctness_covers_raw_bounded_loop_budget() {
        let artifacts = BenchArtifacts {
            raw: compile_artifact(
                "benches/raw/AuthScan.sol",
                "benches/raw/AuthScan.raw.yaml",
                ProgramMode::Raw,
            )
            .unwrap(),
            uo: compile_artifact(
                "benches/raw/AuthScan.sol",
                "benches/raw/AuthScan.uo.yaml",
                ProgramMode::Uo,
            )
            .unwrap(),
            oram: None,
            fullscan64: None,
        };
        let report = check_authscan_correctness(&artifacts).unwrap();
        assert_eq!(report["equivalent"].as_bool(), Some(true));
        assert_eq!(report["raw"]["return"].as_u64(), Some(1));
        assert_eq!(report["raw"]["getters"][0].as_u64(), Some(1));
    }

    #[test]
    fn production_source_slice_keeps_later_production_after_cfg_test_function() {
        let source = r#"
fn before() {}

#[cfg(test)]
fn helper() {
    hidden();
}

fn after() {
    visible();
}
"#;

        let stripped = production_source_slice(source);
        assert!(stripped.contains("fn before() {}"));
        assert!(stripped.contains("fn after() {"));
        assert!(!stripped.contains("fn helper()"));
        assert!(!stripped.contains("hidden();"));
    }

    #[test]
    fn production_source_slice_skips_cfg_test_attribute_stack_and_mod_block() {
        let source = r#"
fn before() {}

#[cfg(test)]
#[test]
fn helper_test() {
    hidden_test();
}

fn middle() {}

#[cfg(test)]
mod tests {
    fn nested() {
        hidden_mod();
    }
}

fn after() {
    visible();
}
"#;

        let stripped = production_source_slice(source);
        assert!(stripped.contains("fn before() {}"));
        assert!(stripped.contains("fn middle() {}"));
        assert!(stripped.contains("fn after() {"));
        assert!(!stripped.contains("helper_test"));
        assert!(!stripped.contains("hidden_test();"));
        assert!(!stripped.contains("mod tests"));
        assert!(!stripped.contains("hidden_mod();"));
    }
}
