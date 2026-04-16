use anyhow::{anyhow, Result};
use rayon::prelude::*;
use serde::Serialize;
use serde_json::{json, Value as JsonValue};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::{self, Command};
use std::time::{SystemTime, UNIX_EPOCH};
use uo_core::{
    canonical_path_oram_leaf_seed_space_size, canonical_path_oram_leaf_values_of_seed,
    BoundaryEvent, CanonicalFreshCoinRuntimePathOramTheoremInput,
    CanonicalFreshCoinRuntimePathOramWitnessFamily, CompiledArtifact, ContractMetadata,
    LogicalEvent, NormalizedMicroTrace, ProgramMode, PublicOutcomeTrace,
    RuntimeOramAccessCounterWitness, RuntimeOramLeafScaffoldWitness, RuntimeOramObjectWitness,
    RuntimeRefinementWitness, SeededRuntimePathOramWitnessFamily, SgxControllerShapeTrace, Value,
    WriteClass,
};
use uo_evm::{CallResult, ContractInstance, PathOramFreshCoinPlan};

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
                .map(|path| display_report_path(&path)),
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

pub fn run_probe_with_options(options: &ProbeRunOptions) -> Result<JsonValue> {
    let suite = compile_suite()?;
    let correctness = run_correctness(&suite)?;
    let static_checks = run_static_checks(&suite)?;
    let trace_equivalence = run_trace_equivalence(&suite)?;
    let leakage_auc = run_auc_reports(&suite)?;
    let mutual_information = run_mutual_information_reports(&suite)?;
    let overheads = run_overheads(&suite)?;
    let controller_observer_validation = run_controller_observer_validation(&suite)?;
    let pathoram_hidden_validation = run_pathoram_hidden_validation()?;
    let witness_validation = run_witness_validation(&suite)?;
    let seeded_witness_validation = run_seeded_witness_validation()?;
    let fresh_coin_validation = run_fresh_coin_validation(options)?;
    let pathoram_pair_validation = run_pathoram_pair_validation()?;
    let canonical_pathoram_pair_validation = run_canonical_pathoram_pair_validation(options)?;
    let artifact_readme = artifact_readme(options);
    Ok(json!({
        "artifact_configuration": options.artifact_configuration_json(),
        "correctness": correctness,
        "static_checks": static_checks,
        "trace_equivalence": trace_equivalence,
        "leakage_auc": leakage_auc,
        "mutual_information": mutual_information,
        "overheads": overheads,
        "controller_observer_validation": controller_observer_validation,
        "pathoram_hidden_validation": pathoram_hidden_validation,
        "witness_validation": witness_validation,
        "seeded_witness_validation": seeded_witness_validation,
        "fresh_coin_validation": fresh_coin_validation,
        "pathoram_pair_validation": pathoram_pair_validation,
        "canonical_pathoram_pair_validation": canonical_pathoram_pair_validation,
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
    let witness_validation = run_witness_validation(&suite)?;
    let seeded_witness_validation = run_seeded_witness_validation()?;
    Ok(json!({
        "static_checks": static_checks,
        "controller_observer_validation": controller_observer_validation,
        "pathoram_hidden_validation": pathoram_hidden_validation,
        "witness_validation": witness_validation,
        "seeded_witness_validation": seeded_witness_validation,
    }))
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
        "trace_equivalence",
        "leakage_auc",
        "mutual_information",
        "overheads",
        "controller_observer_validation",
        "pathoram_hidden_validation",
        "witness_validation",
        "seeded_witness_validation",
        "fresh_coin_validation",
        "pathoram_pair_validation",
        "canonical_pathoram_pair_validation",
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
    Ok(())
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

fn compile_artifact(source: &str, metadata: &str, mode: ProgramMode) -> Result<CompiledArtifact> {
    let metadata: ContractMetadata = serde_yaml::from_slice(&fs::read(metadata)?)?;
    uo_solc::compile(source, &metadata, mode)
}

fn load_metadata(metadata_path: &str) -> Result<ContractMetadata> {
    Ok(serde_yaml::from_slice(&fs::read(metadata_path)?)?)
}

fn run_static_checks(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let mut reports = Vec::new();
    for (name, artifacts) in suite {
        let source = format!("benches/raw/{name}.sol");
        let raw_meta = format!("benches/raw/{name}.raw.yaml");
        let raw_metadata = load_metadata(&raw_meta)?;
        let uo_meta = format!("benches/raw/{name}.uo.yaml");
        let uo_metadata = load_metadata(&uo_meta)?;
        let oram_meta = format!("benches/raw/{name}.oram.yaml");
        let oram_metadata = Path::new(&oram_meta)
            .exists()
            .then(|| load_metadata(&oram_meta))
            .transpose()?;
        let fullscan64_meta = format!("benches/raw/{name}.fullscan64.yaml");
        let fullscan64_metadata = Path::new(&fullscan64_meta)
            .exists()
            .then(|| load_metadata(&fullscan64_meta))
            .transpose()?;
        reports.push(json!({
            "benchmark": name,
            "source_raw": uo_check::check_source(&source, &raw_metadata)?,
            "source_uo": uo_check::check_source(&source, &uo_metadata)?,
            "raw_artifact": uo_check::check_artifact_against_source(&source, &raw_metadata, &artifacts.raw)?,
            "uo_artifact": uo_check::check_artifact_against_source(&source, &uo_metadata, &artifacts.uo)?,
            "oram_artifact": artifacts
                .oram
                .as_ref()
                .zip(oram_metadata.as_ref())
                .map(|(artifact, metadata)| uo_check::check_artifact_against_source(&source, metadata, artifact))
                .transpose()?,
            "fullscan64_artifact": artifacts
                .fullscan64
                .as_ref()
                .zip(fullscan64_metadata.as_ref())
                .map(|(artifact, metadata)| uo_check::check_artifact_against_source(&source, metadata, artifact))
                .transpose()?,
        }));
    }
    Ok(json!({ "reports": reports }))
}

fn run_correctness(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let mut scenarios = Vec::new();
    scenarios.push(check_classifier_correctness(&suite["FixedSlotClassifier"])?);
    scenarios.push(check_authscan_correctness(&suite["AuthScan"])?);
    scenarios.push(check_mixer_correctness(&suite["ConfidentialMixer"])?);
    scenarios.push(check_erc20_correctness(&suite["ERC20Lite"])?);
    scenarios.push(check_registry_correctness(&suite["RegistryCRUD"])?);
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

fn run_witness_validation(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let checker = lean_witness_checker_path()?;
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
    scenarios.push(validate_witness_case(
        "FixedSlotClassifier/uo/class0",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "FixedSlotClassifier/uo/class1",
        &suite["FixedSlotClassifier"].uo,
        &[],
        &CallSpec {
            entrypoint: "classify(uint256)",
            args: vec![Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "AuthScan/uo/class0",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(9)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "AuthScan/uo/class1",
        &suite["AuthScan"].uo,
        &auth_setup,
        &CallSpec {
            entrypoint: "auth(bytes32)",
            args: vec![b32(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "RegistryCRUD/uo/class0",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "RegistryCRUD/uo/class1",
        &suite["RegistryCRUD"].uo,
        &[],
        &CallSpec {
            entrypoint: "upsert(bytes32,uint256)",
            args: vec![b32(7), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "ConfidentialMixer/fullscan/class0",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "ConfidentialMixer/fullscan/class1",
        &suite["ConfidentialMixer"].uo,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "ERC20Lite/fullscan/class0",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(0)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "ERC20Lite/fullscan/class1",
        &suite["ERC20Lite"].uo,
        &erc20_setup,
        &CallSpec {
            entrypoint: "approve(address,address,uint256)",
            args: vec![addr(0x11), addr(0x22), Value::Uint(4)],
        },
        &checker,
    )?);

    scenarios.push(validate_witness_case(
        "SingleAccessMap/pathoram/put-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "SingleAccessMap/pathoram/put-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "put(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "SingleAccessMap/pathoram/add-class0",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(1), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "SingleAccessMap/pathoram/add-class1",
        &single_access,
        &[],
        &CallSpec {
            entrypoint: "add(bytes32,uint256)",
            args: vec![b32(9), Value::Uint(7)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
        "ConfidentialMixer/pathoram/deposit",
        &mixer_pathoram,
        &[],
        &CallSpec {
            entrypoint: "deposit(bytes32,uint256)",
            args: vec![b32(5), Value::Uint(1)],
        },
        &checker,
    )?);
    scenarios.push(validate_witness_case(
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
        "boundary_events": witness.boundary_schedule.len(),
        "controller_phase_count": witness.controller_shape.controller_phase_order.len(),
        "controller_accesses": witness.controller_certificate.observed_oram_accesses.len(),
        "page_trace_events": witness.normalized_micro_trace.page_trace.len(),
        "exit_events": witness.normalized_micro_trace.exit_pattern.len(),
        "shared_resource_events": witness.normalized_micro_trace.shared_resource_pattern.len(),
        "witness_json_bytes": witness_json_bytes,
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
        "gas_used": certificate.public_outcome.gas_used,
        "boundary_events": certificate.boundary_schedule.len(),
        "controller_phase_count": certificate.controller_shape.controller_phase_order.len(),
        "controller_accesses": certificate.controller_certificate.observed_oram_accesses.len(),
        "page_trace_events": certificate.normalized_micro_trace.page_trace.len(),
        "exit_events": certificate.normalized_micro_trace.exit_pattern.len(),
        "shared_resource_events": certificate.normalized_micro_trace.shared_resource_pattern.len(),
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
        "leaf_steps": certificate.oram_leaf_schedule.len(),
        "public_leaf_scaffold_steps": certificate.oram_leaf_public_scaffold.len(),
        "position_map_objects": certificate.oram_position_map_before.len(),
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
        gas_used.insert(witness.trace.gas_used);
        boundary_events.insert(witness.boundary_schedule.len());
        controller_phase_counts.insert(witness.controller_shape.controller_phase_order.len());
        public_leaf_scaffold_steps.insert(witness.oram_leaf_public_scaffold.len());
        oram_object_configs.insert(serde_json::to_string(&witness.oram_objects)?);
        physical_read_shapes.insert(serde_json::to_string(&witness.trace.physical_reads)?);
        physical_write_shapes.insert(serde_json::to_string(&witness.trace.physical_writes)?);
        witnesses.push(witness);
    }
    let family = SeededRuntimePathOramWitnessFamily::new(witnesses)?;
    let canonical_leaf_seed_space_size =
        canonical_path_oram_leaf_seed_space_size(&family.public_leaf_scaffold);
    let canonical_leaf_values_match = family.witnesses.iter().enumerate().all(|(seed, witness)| {
        witness
            .oram_leaf_schedule
            .iter()
            .map(|step| step.leaf)
            .collect::<Vec<_>>()
            == canonical_path_oram_leaf_values_of_seed(&family.public_leaf_scaffold, seed)
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
        "public_leaf_scaffold_steps": family.public_leaf_scaffold.len(),
        "canonical_leaf_seed_space_size": canonical_leaf_seed_space_size,
        "canonical_leaf_seed_space_matches": canonical_leaf_seed_space_size == Some(family.seed_count),
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
    let public_leaf_scaffold_step_count = first_witness.oram_leaf_public_scaffold.len();
    let public_fresh_coin_scaffold_step_count = family.public_fresh_coin_scaffold.len();
    let gas_uniform = family
        .witnesses
        .iter()
        .map(|w| w.trace.gas_used)
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let boundary_uniform = family
        .witnesses
        .iter()
        .map(|w| w.boundary_schedule.len())
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let controller_phase_uniform = family
        .witnesses
        .iter()
        .map(|w| w.controller_shape.controller_phase_order.len())
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let public_leaf_scaffold_uniform = family
        .witnesses
        .iter()
        .map(|w| w.oram_leaf_public_scaffold.len())
        .collect::<BTreeSet<_>>()
        .len()
        == 1;
    let public_fresh_coin_scaffold_uniform = family
        .witnesses
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
        .witnesses
        .iter()
        .map(|w| serde_json::to_string(&w.oram_objects))
        .collect::<Result<BTreeSet<_>, _>>()?
        .len()
        == 1;
    let canonical_fresh_coin_values_match_index =
        family.witnesses.iter().enumerate().all(|(seed, witness)| {
            witness.path_oram_fresh_coin_values().unwrap_or_default()
                == canonical_path_oram_leaf_values_of_seed(&family.public_fresh_coin_scaffold, seed)
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
        "seed_count": family.seed_count,
        "distinct_canonical_seeds_found": family.seed_count,
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
        "canonical_fresh_coin_seed_space_size": Some(family.seed_count),
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
        .representative_witness
        .path_oram_fresh_coin_values()
        .ok_or_else(|| {
            anyhow!(
                "fresh-coin value extraction failed for {} representative seed {}",
                name,
                theorem_input.representative_seed
            )
        })?;
    let canonical_values = canonical_path_oram_leaf_values_of_seed(
        &theorem_input.public_fresh_coin_scaffold,
        theorem_input.representative_seed,
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
        "representative_seed": theorem_input.representative_seed,
        "representative_witness_count": 1,
        "seed_count": theorem_input.seed_count,
        "symbolic_seed_space_instantiated": true,
        "coverage_complete": false,
        "public_leaf_scaffold_steps": theorem_input.public_leaf_scaffold.len(),
        "public_fresh_coin_scaffold_steps": theorem_input.public_fresh_coin_scaffold.len(),
        "canonical_fresh_coin_seed_space_size": Some(theorem_input.seed_count),
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
                    &fresh_coin_plan,
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
        access_counters_before: first_trace.runtime_oram_access_counters_before.clone(),
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
        .call_with_path_oram_fresh_coins(target.entrypoint, target.args.clone(), &fresh_coin_plan)?
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
        access_counters_before: first_trace.runtime_oram_access_counters_before.clone(),
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
                &fresh_coin_plan,
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
        public_leaf_scaffold_steps: first_witness.oram_leaf_public_scaffold.len(),
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
    let public_leaf_scaffold = first_witness.oram_leaf_public_scaffold.clone();
    let public_fresh_coin_scaffold = first_witness
        .path_oram_fresh_coin_scaffold()
        .ok_or_else(|| anyhow!("fresh-coin scaffold extraction failed for {}", name))?;
    let seed_count = canonical_path_oram_leaf_seed_space_size(&public_fresh_coin_scaffold)
        .ok_or_else(|| anyhow!("fresh-coin seed space overflow for {}", name))?;
    Ok(PreparedCanonicalFreshCoinFamily {
        prepared,
        first_witness,
        access_counters_before: first_trace.runtime_oram_access_counters_before.clone(),
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
                &fresh_coin_plan,
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
        if witness.oram_leaf_public_scaffold != context.public_leaf_scaffold
            || extracted_scaffold != context.public_fresh_coin_scaffold
            || extracted_values != fresh_coin_values
        {
            return Err(anyhow!(
                "canonical fresh-coin extraction mismatch for {} seed {}",
                name,
                seed
            ));
        }
        update_uniform(&mut gas_seen, &mut gas_uniform, witness.trace.gas_used);
        update_uniform(
            &mut boundary_seen,
            &mut boundary_uniform,
            witness.boundary_schedule.len(),
        );
        update_uniform(
            &mut controller_phase_seen,
            &mut controller_phase_uniform,
            witness.controller_shape.controller_phase_order.len(),
        );
        update_uniform(
            &mut oram_object_cfg_seen,
            &mut oram_object_config_uniform,
            serde_json::to_string(&witness.oram_objects)?,
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
    Ok(Some((display_report_path(&path), bytes)))
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
        "heavy_artifact_path": preserve_path.then(|| display_report_path(&artifact_path)),
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
    let public_outcome = lhs_context.first_witness.public_outcome.clone();
    let boundary_schedule = lhs_context.first_witness.boundary_schedule.clone();
    let controller_shape = lhs_context.first_witness.controller_shape.clone();
    let normalized_micro_trace = lhs_context.first_witness.normalized_micro_trace.clone();
    let public_outcome_equal =
        lhs_context.first_witness.public_outcome == rhs_context.first_witness.public_outcome;
    let boundary_schedule_equal =
        lhs_context.first_witness.boundary_schedule == rhs_context.first_witness.boundary_schedule;
    let controller_shape_equal =
        lhs_context.first_witness.controller_shape == rhs_context.first_witness.controller_shape;
    let normalized_micro_trace_equal = lhs_context.first_witness.normalized_micro_trace
        == rhs_context.first_witness.normalized_micro_trace;

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
        "heavy_artifact_path": preserve_path.then(|| display_report_path(&artifact_path)),
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
        .witnesses
        .first()
        .ok_or_else(|| anyhow!("left seeded family is empty for {}", name))?;
    let rhs_first = rhs_collected
        .family
        .witnesses
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
        public_outcome: lhs_first.public_outcome.clone(),
        boundary_schedule: lhs_first.boundary_schedule.clone(),
        controller_shape: lhs_first.controller_shape.clone(),
        normalized_micro_trace: lhs_first.normalized_micro_trace.clone(),
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
        "lhs_seed_count": lhs_collected.family.seed_count,
        "rhs_seed_count": rhs_collected.family.seed_count,
        "access_counters_equal": lhs_collected.access_counters_before == rhs_collected.access_counters_before,
        "public_outcome_equal": lhs_first.public_outcome == rhs_first.public_outcome,
        "boundary_schedule_equal": lhs_first.boundary_schedule == rhs_first.boundary_schedule,
        "controller_shape_equal": lhs_first.controller_shape == rhs_first.controller_shape,
        "normalized_micro_trace_equal": lhs_first.normalized_micro_trace == rhs_first.normalized_micro_trace,
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
        public_outcome: lhs_first.public_outcome.clone(),
        boundary_schedule: lhs_first.boundary_schedule.clone(),
        controller_shape: lhs_first.controller_shape.clone(),
        normalized_micro_trace: lhs_first.normalized_micro_trace.clone(),
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
        "lhs_seed_count": lhs_collected.family.seed_count,
        "rhs_seed_count": rhs_collected.family.seed_count,
        "access_counters_equal": lhs_collected.access_counters_before == rhs_collected.access_counters_before,
        "public_outcome_equal": lhs_first.public_outcome == rhs_first.public_outcome,
        "boundary_schedule_equal": lhs_first.boundary_schedule == rhs_first.boundary_schedule,
        "controller_shape_equal": lhs_first.controller_shape == rhs_first.controller_shape,
        "normalized_micro_trace_equal": lhs_first.normalized_micro_trace == rhs_first.normalized_micro_trace,
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

    let lhs_witness = &lhs_collected.input.representative_witness;
    let rhs_witness = &rhs_collected.input.representative_witness;
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
    let public_outcome = lhs_witness.public_outcome.clone();
    let boundary_schedule = lhs_witness.boundary_schedule.clone();
    let controller_shape = lhs_witness.controller_shape.clone();
    let normalized_micro_trace = lhs_witness.normalized_micro_trace.clone();
    let public_outcome_equal = lhs_witness.public_outcome == rhs_witness.public_outcome;
    let boundary_schedule_equal = lhs_witness.boundary_schedule == rhs_witness.boundary_schedule;
    let controller_shape_equal = lhs_witness.controller_shape == rhs_witness.controller_shape;
    let normalized_micro_trace_equal =
        lhs_witness.normalized_micro_trace == rhs_witness.normalized_micro_trace;

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
        "lhs_seed_count": theorem_input.lhs_input.seed_count,
        "rhs_seed_count": theorem_input.rhs_input.seed_count,
        "lhs_representative_seed": theorem_input.lhs_input.representative_seed,
        "rhs_representative_seed": theorem_input.rhs_input.representative_seed,
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

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .expect("workspace root should exist")
}

fn display_report_path(path: &Path) -> String {
    let root = repo_root();
    match path.strip_prefix(&root) {
        Ok(relative) => relative.display().to_string(),
        Err(_) => path.display().to_string(),
    }
}

fn lean_witness_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkRuntimeWitness");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean witness checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_controller_certificate_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkRuntimeControllerCertificate");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean controller certificate checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_pathoram_hidden_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkRuntimePathOramHiddenCertificate");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean path-ORAM hidden checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_witness_family_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkRuntimeWitnessFamily");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean witness family checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_fresh_coin_family_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkRuntimeFreshCoinFamily");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean fresh-coin family checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_fresh_coin_theorem_input_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkRuntimeFreshCoinTheoremInput");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean fresh-coin theorem-input checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_pathoram_pair_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkPathOramPairCertificate");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean path-ORAM pair checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_canonical_pathoram_pair_checker_path() -> Result<PathBuf> {
    let path = repo_root().join("proof/lean/.lake/build/bin/checkCanonicalPathOramPairCertificate");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean canonical path-ORAM pair checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_canonical_pathoram_paper_instantiation_checker_path() -> Result<PathBuf> {
    let path =
        repo_root().join("proof/lean/.lake/build/bin/checkCanonicalPathOramPaperInstantiation");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean canonical path-ORAM paper instantiation checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
}

fn lean_canonical_pathoram_pair_theorem_input_checker_path() -> Result<PathBuf> {
    let path =
        repo_root().join("proof/lean/.lake/build/bin/checkCanonicalPathOramPairTheoremInput");
    if path.is_file() {
        Ok(path)
    } else {
        Err(anyhow!(
            "Lean canonical path-ORAM pair theorem-input checker not found at {}; build it with `cd proof/lean && lake build`",
            path.display()
        ))
    }
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
    let raw = run_scenario(&artifacts.raw, &setup, &target, &getters)?;
    let uo = run_scenario(&artifacts.uo, &setup, &target, &getters)?;
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
    let classifier_raw = run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)?;
    let classifier_uo = run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)?;
    let classifier_same_same = run_classifier_same_same(&suite["FixedSlotClassifier"].raw)?;
    let auth_uo = run_authscan_experiment(&suite["AuthScan"].uo)?;
    let mixer_uo = run_mixer_key_experiment(&suite["ConfidentialMixer"].uo)?;
    let mixer_oram = run_mixer_key_experiment(
        suite["ConfidentialMixer"]
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing mixer oram"))?,
    )?;
    let erc20_uo = run_erc20_allowance_key_experiment(&suite["ERC20Lite"].uo)?;
    let erc20_oram = run_erc20_allowance_key_experiment(
        suite["ERC20Lite"]
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing erc20 oram"))?,
    )?;
    let registry_uo = run_registry_key_experiment(&suite["RegistryCRUD"].uo)?;
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
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)?,
        ),
        (
            "FixedSlotClassifier",
            "uo",
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)?,
        ),
        (
            "AuthScan",
            "raw",
            run_authscan_experiment(&suite["AuthScan"].raw)?,
        ),
        (
            "AuthScan",
            "uo",
            run_authscan_experiment(&suite["AuthScan"].uo)?,
        ),
        (
            "RegistryCRUD",
            "raw",
            run_registry_experiment(&suite["RegistryCRUD"].raw)?,
        ),
        (
            "RegistryCRUD",
            "uo",
            run_registry_experiment(&suite["RegistryCRUD"].uo)?,
        ),
        (
            "ConfidentialMixer",
            "raw",
            run_mixer_experiment(&suite["ConfidentialMixer"].raw)?,
        ),
        (
            "ConfidentialMixer",
            "uo",
            run_mixer_experiment(&suite["ConfidentialMixer"].uo)?,
        ),
        (
            "ConfidentialMixer",
            "oram",
            run_mixer_experiment(
                suite["ConfidentialMixer"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing mixer oram"))?,
            )?,
        ),
        (
            "ERC20Lite",
            "raw",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].raw)?,
        ),
        (
            "ERC20Lite",
            "uo",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].uo)?,
        ),
        (
            "ERC20Lite",
            "oram",
            run_erc20_allowance_value_experiment(
                suite["ERC20Lite"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing erc20 oram"))?,
            )?,
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
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)?,
        ),
        (
            "FixedSlotClassifier",
            "uo",
            run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)?,
        ),
        (
            "AuthScan",
            "raw",
            run_authscan_experiment(&suite["AuthScan"].raw)?,
        ),
        (
            "AuthScan",
            "uo",
            run_authscan_experiment(&suite["AuthScan"].uo)?,
        ),
        (
            "RegistryCRUD",
            "raw",
            run_registry_experiment(&suite["RegistryCRUD"].raw)?,
        ),
        (
            "RegistryCRUD",
            "uo",
            run_registry_experiment(&suite["RegistryCRUD"].uo)?,
        ),
        (
            "ConfidentialMixer",
            "raw",
            run_mixer_experiment(&suite["ConfidentialMixer"].raw)?,
        ),
        (
            "ConfidentialMixer",
            "uo",
            run_mixer_experiment(&suite["ConfidentialMixer"].uo)?,
        ),
        (
            "ConfidentialMixer",
            "oram",
            run_mixer_experiment(
                suite["ConfidentialMixer"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing mixer oram"))?,
            )?,
        ),
        (
            "ERC20Lite",
            "raw",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].raw)?,
        ),
        (
            "ERC20Lite",
            "uo",
            run_erc20_allowance_value_experiment(&suite["ERC20Lite"].uo)?,
        ),
        (
            "ERC20Lite",
            "oram",
            run_erc20_allowance_value_experiment(
                suite["ERC20Lite"]
                    .oram
                    .as_ref()
                    .ok_or_else(|| anyhow!("missing erc20 oram"))?,
            )?,
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
    )?;
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
    )?;
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
    )?;
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
        let trace = run_target_call(artifact, setup, entrypoint, args)?;
        class0_hashes.push(trace.hashes());
        class0_metrics.push(extract_metrics(&trace));
    }
    for args in class1 {
        let trace = run_target_call(artifact, setup, entrypoint, args)?;
        class1_hashes.push(trace.hashes());
        class1_metrics.push(extract_metrics(&trace));
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

fn run_target_call(
    artifact: &CompiledArtifact,
    setup: &[CallSpec],
    entrypoint: &str,
    args: Vec<Value>,
) -> Result<uo_core::ExecutionTrace> {
    let mut instance = ContractInstance::deploy(artifact.clone())?;
    for call in setup {
        instance.call(call.entrypoint, call.args.clone())?;
    }
    Ok(instance.call(entrypoint, args)?.trace)
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
            if *expected != trace.runtime_oram_access_counters_before {
                return Err(anyhow!(
                    "seeded path-ORAM family for {} does not keep pre-call access counters public and stable across seeds",
                    entrypoint
                ));
            }
        } else {
            access_counters_before = Some(trace.runtime_oram_access_counters_before.clone());
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
                entrypoint_id: witness.public_outcome.entrypoint_id.clone(),
                oram_objects: witness.oram_objects.clone(),
            },
            public_args: witness.public_outcome.public_args.clone(),
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
        opcode_trace: witness.trace.opcode_trace.clone(),
        logical_accesses: witness
            .trace
            .logical_accesses
            .iter()
            .map(normalize_path_oram_logical_event)
            .collect(),
        logical_writes: witness.trace.logical_writes.clone(),
        gas_used: witness.trace.gas_used,
    }
}

fn imported_path_oram_public_location(
    witness: &RuntimeRefinementWitness,
) -> ImportedPathOramStorageLocationTrace {
    ImportedPathOramStorageLocationTrace {
        read_labels: witness
            .trace
            .physical_reads
            .iter()
            .map(|event| ImportedPathOramPhysicalEventLabel {
                object: event.object.clone(),
                location: normalize_path_oram_location(&event.object, &event.location),
            })
            .collect(),
        write_labels: witness
            .trace
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
            .trace
            .physical_reads
            .iter()
            .map(|event| event.len)
            .collect(),
        write_classes: witness
            .trace
            .physical_writes
            .iter()
            .map(|event| event.write_class.clone())
            .collect(),
        write_lengths: witness
            .trace
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

fn extract_metrics(trace: &uo_core::ExecutionTrace) -> BTreeMap<String, f64> {
    let mut metrics = trace.host_proxy_metrics.clone();
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
        "bytes_written": result.target.trace.host_proxy_metrics.get("bytes_written").copied().unwrap_or_default(),
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
representative theorem-backed runtime refinement witnesses against the Lean-side
validator, and `seeded_witness_validation.json`, which checks seeded path-ORAM
witness families against the Lean-side runtime-coins family validator.
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
            "- Heavy artifacts are written under `{}` when heavy mode is selected.\n",
            dir.display()
        ));
    }
    readme
}
