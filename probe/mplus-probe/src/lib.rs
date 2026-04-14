use anyhow::{anyhow, Result};
use rayon::prelude::*;
use serde::Serialize;
use serde_json::{json, Value as JsonValue};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{self, Command};
use std::time::{SystemTime, UNIX_EPOCH};
use uo_core::{
    canonical_path_oram_leaf_seed_space_size, canonical_path_oram_leaf_values_of_seed,
    BoundaryEvent, CanonicalFreshCoinRuntimePathOramWitnessFamily, CompiledArtifact,
    ContractMetadata, LogicalEvent, NormalizedMicroTrace, ProgramMode, PublicOutcomeTrace,
    RuntimeOramAccessCounterWitness, RuntimeOramObjectWitness, RuntimeRefinementWitness,
    SeededRuntimePathOramWitnessFamily, SgxControllerShapeTrace, Value, WriteClass,
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
const CANONICAL_SIZE_ESTIMATE_SAMPLE_SEEDS: usize = 8;

pub fn run_probe() -> Result<JsonValue> {
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
    let fresh_coin_validation = run_fresh_coin_validation()?;
    let pathoram_pair_validation = run_pathoram_pair_validation()?;
    let canonical_pathoram_pair_validation = run_canonical_pathoram_pair_validation()?;
    let artifact_readme = artifact_readme();
    Ok(json!({
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
    run_fresh_coin_validation()
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
    run_canonical_pathoram_pair_validation()
}

pub fn write_results(out_dir: &str, results: &JsonValue) -> Result<()> {
    fs::create_dir_all(out_dir)?;
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

fn run_static_checks(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let mut reports = Vec::new();
    for (name, artifacts) in suite {
        let source = format!("benches/raw/{name}.sol");
        let raw_meta = format!("benches/raw/{name}.raw.yaml");
        let source_meta: ContractMetadata = serde_yaml::from_slice(&fs::read(&raw_meta)?)?;
        reports.push(json!({
            "benchmark": name,
            "source": uo_check::check_source(&source, &source_meta)?,
            "raw_artifact": uo_check::check_artifact(&artifacts.raw)?,
            "uo_artifact": uo_check::check_artifact(&artifacts.uo)?,
            "oram_artifact": artifacts.oram.as_ref().map(uo_check::check_artifact).transpose()?,
            "fullscan64_artifact": artifacts.fullscan64.as_ref().map(uo_check::check_artifact).transpose()?,
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
            "reason": "legacy surrogate ORAM backend is outside the current controller-observer theorem boundary"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "legacy surrogate ORAM backend is outside the current controller-observer theorem boundary"
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
        "checker": checker.display().to_string(),
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
        "checker": checker.display().to_string(),
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
            "reason": "legacy surrogate ORAM backend is outside the current Lean runtime witness boundary"
        }),
        json!({
            "scenario": "ERC20Lite/oram/*",
            "reason": "legacy surrogate ORAM backend is outside the current Lean runtime witness boundary"
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
        "checker": checker.display().to_string(),
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
        "checker": checker.display().to_string(),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_fresh_coin_validation() -> Result<JsonValue> {
    let checker = lean_fresh_coin_family_checker_path()?;
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
            &checker,
        )?,
        validate_fresh_coin_family_case(
            "SingleAccessMap/pathoram/add-fresh-coins",
            &single_access,
            &[],
            &CallSpec {
                entrypoint: "add(bytes32,uint256)",
                args: vec![b32(1), Value::Uint(7)],
            },
            &checker,
        )?,
        validate_fresh_coin_family_case(
            "ConfidentialMixer/pathoram/deposit-fresh-coins",
            &mixer_pathoram,
            &[],
            &CallSpec {
                entrypoint: "deposit(bytes32,uint256)",
                args: vec![b32(5), Value::Uint(1)],
            },
            &checker,
        )?,
        validate_fresh_coin_family_case(
            "ERC20Lite/pathoram/transferFrom-fresh-coins",
            &erc20_pathoram,
            &erc20_transfer_setup,
            &CallSpec {
                entrypoint: "transferFrom(address,address,address,uint256)",
                args: vec![addr(0x11), addr(0x22), addr(0x33), Value::Uint(3)],
            },
            &checker,
        )?,
    ];

    Ok(json!({
        "checker": checker.display().to_string(),
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
        "checker": checker.display().to_string(),
        "model_tags": {
            "page_model": "page_v1",
            "exit_model": "exit_v1",
            "shared_resource_model": "shared_v1"
        },
        "scenario_count": scenarios.len(),
        "scenarios": scenarios,
    }))
}

fn run_canonical_pathoram_pair_validation() -> Result<JsonValue> {
    let checker = lean_canonical_pathoram_pair_checker_path()?;
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
        )?,
    ];

    Ok(json!({
        "checker": checker.display().to_string(),
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
    checker: &Path,
) -> Result<JsonValue> {
    let budget_bytes = canonical_cert_budget_bytes();
    let estimate = estimate_canonical_fresh_coin_family_size(
        name,
        artifact,
        setup,
        target,
        CANONICAL_SIZE_ESTIMATE_SAMPLE_SEEDS,
    )?;
    if estimate.estimated_family_json_bytes > budget_bytes {
        return Ok(json!({
            "scenario": name,
            "entrypoint": target.entrypoint,
            "validation_status": "skipped_by_budget",
            "reason": format!(
                "estimated compact canonical fresh-coin family exceeds safe budget {}; set UO_CANONICAL_CERT_BUDGET_BYTES to override",
                budget_bytes
            ),
            "budget_bytes": budget_bytes,
            "size_estimate": estimate,
            "lean_validated": false,
            "accepted": false,
        }));
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
    let output = Command::new(checker)
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
    let _ = fs::remove_file(&certificate_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean path-ORAM pair validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

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
) -> Result<JsonValue> {
    let budget_bytes = canonical_cert_budget_bytes();
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
    if estimated_certificate_json_bytes > budget_bytes {
        return Ok(json!({
            "scenario": name,
            "entrypoint": lhs.entrypoint,
            "validation_status": "skipped_by_budget",
            "reason": format!(
                "estimated compact canonical pair certificate exceeds safe budget {}; set UO_CANONICAL_CERT_BUDGET_BYTES to override",
                budget_bytes
            ),
            "budget_bytes": budget_bytes,
            "estimated_certificate_json_bytes": estimated_certificate_json_bytes,
            "lhs_estimate": lhs_estimate,
            "rhs_estimate": rhs_estimate,
            "lean_validated": false,
            "accepted": false,
        }));
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
    let _ = fs::remove_file(&certificate_path);
    if !output.status.success() {
        return Err(anyhow!(
            "Lean canonical path-ORAM pair validation failed for {}: {}",
            name,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

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
        "certificate_json_bytes": certificate_json_bytes,
        "accepted": true,
    }))
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .expect("workspace root should exist")
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

fn temporary_witness_path(case_name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("clock should be after unix epoch")
        .as_nanos();
    let sanitized = case_name
        .chars()
        .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { '_' })
        .collect::<String>();
    std::env::temp_dir().join(format!(
        "uo-runtime-witness-{}-{}-{}.json",
        process::id(),
        sanitized,
        nanos
    ))
}

fn canonical_cert_budget_bytes() -> u64 {
    std::env::var("UO_CANONICAL_CERT_BUDGET_BYTES")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(DEFAULT_CANONICAL_CERT_BUDGET_BYTES)
}

fn write_temp_json<T: Serialize>(case_name: &str, value: &T) -> Result<(PathBuf, u64)> {
    let path = temporary_witness_path(case_name);
    let file = fs::File::create(&path)?;
    let mut writer = std::io::BufWriter::new(file);
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

fn artifact_readme() -> &'static str {
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
oversized canonical fresh-coin families and records
`ERC20Lite/pathoram/transferFrom-fresh-coins` as `skipped_by_budget` rather
than trying to materialize an infeasible theorem input.
`seeded_witness_validation.json` now also covers finite seeded path-ORAM
families beyond `SingleAccessMap`, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
`pathoram_pair_validation.json` now also checks paired seeded path-ORAM proof
input certificates beyond `SingleAccessMap`, including
`ConfidentialMixer/pathoram/deposit-pair` and
`ERC20Lite/pathoram/transferFrom-pair`. Legacy surrogate ORAM scenarios remain
reported in the broader benchmark results but are explicitly excluded from the
theorem-facing witness validators.
`canonical_pathoram_pair_validation.json` adds the canonical fresh-coin pair
certificate layer: it checks that the theorem-backed `SingleAccessMap`
Path-ORAM workloads share one common public observer across the full
canonical fresh-coin families, including the complete `256`-seed `put` family
and complete `4096`-seed `add` family. The remaining coverage gap is now
narrower: the larger canonical-pair layer is still not materialized, and the
very large canonical-family / canonical-pair workloads such as
`ERC20Lite/pathoram/transferFrom` are still not enumerated end to end. To keep
the artifact from exhausting host memory, the canonical-pair probe now
preflights compact certificate size from sampled witnesses and skips cases that
exceed a safe budget. Under the default `10 GiB` budget, the current report
accepts the two `SingleAccessMap` canonical pairs and records
`ConfidentialMixer/pathoram/deposit-canonical-pair` as `skipped_by_budget`
with an estimated compact certificate size of about `13.66 GiB`, while
`ERC20Lite/pathoram/transferFrom-canonical-pair` is also recorded as
`skipped_by_budget` with an estimated compact certificate far beyond any
practical artifact budget.

Security tiers:

- Exact-UO: `FixedSlotClassifier`, `AuthScan`, `ConfidentialMixer` full-scan, `ERC20Lite` full-scan, and `RegistryCRUD` use fixed-shape commits and normalized `M+` traces that are identical across secret variations in this instrumented abstract machine.
- Computational-UO: `ConfidentialMixer` ORAM and `ERC20Lite` ORAM use a public-schedule ORAM surrogate that rewrites fixed-shape control metadata and a logarithmic bucket batch while keeping `M+` update classes secret-independent.

Unsupported / rejected:

- inline assembly / Yul
- dynamic strings and dynamic bytes
- unbounded mappings and dynamic arrays without fixed public capacity
- recursion, `try/catch`, events, custom errors, `while` / `do while`, external calls, and early confidential returns

Prototype assumptions:

- `uint256` syntax is accepted, but the current executable prototype evaluates arithmetic in a bounded `u128` domain for the benchmark suite.
- The ORAM backend is an instrumented runtime prototype with fixed-shape committed control metadata and public-schedule bucket rewrites; it is reported as computational-UO only.
- The guarantees are with respect to the abstract/runtime traces emitted by this artifact, including the normalized physical read/write schedules captured by the runtime, not every downstream machine-code or microarchitectural observer.
"#
}
