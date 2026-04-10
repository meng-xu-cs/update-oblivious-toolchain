use anyhow::{anyhow, Result};
use serde_json::{json, Value as JsonValue};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use uo_core::{CompiledArtifact, ContractMetadata, ProgramMode, Value, WriteClass};
use uo_evm::{CallResult, ContractInstance};

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

pub fn run_probe() -> Result<JsonValue> {
    let suite = compile_suite()?;
    let correctness = run_correctness(&suite)?;
    let static_checks = run_static_checks(&suite)?;
    let trace_equivalence = run_trace_equivalence(&suite)?;
    let leakage_auc = run_auc_reports(&suite)?;
    let mutual_information = run_mutual_information_reports(&suite)?;
    let overheads = run_overheads(&suite)?;
    let artifact_readme = artifact_readme();
    Ok(json!({
        "correctness": correctness,
        "static_checks": static_checks,
        "trace_equivalence": trace_equivalence,
        "leakage_auc": leakage_auc,
        "mutual_information": mutual_information,
        "overheads": overheads,
        "artifact_readme": artifact_readme,
    }))
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
            raw: compile_artifact("benches/raw/AuthScan.sol", "benches/raw/AuthScan.raw.yaml", ProgramMode::Raw)?,
            uo: compile_artifact("benches/raw/AuthScan.sol", "benches/raw/AuthScan.uo.yaml", ProgramMode::Uo)?,
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
            raw: compile_artifact("benches/raw/ERC20Lite.sol", "benches/raw/ERC20Lite.raw.yaml", ProgramMode::Raw)?,
            uo: compile_artifact("benches/raw/ERC20Lite.sol", "benches/raw/ERC20Lite.uo.yaml", ProgramMode::Uo)?,
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
        artifacts.oram.as_ref().ok_or_else(|| anyhow!("missing mixer oram"))?,
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
        artifacts.oram.as_ref().ok_or_else(|| anyhow!("missing erc20 oram"))?,
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
    let mixer_uo = run_mixer_experiment(&suite["ConfidentialMixer"].uo)?;
    let mixer_oram = run_mixer_experiment(
        suite["ConfidentialMixer"]
            .oram
            .as_ref()
            .ok_or_else(|| anyhow!("missing mixer oram"))?,
    )?;
    Ok(json!({
        "positive_control": {
            "benchmark": "FixedSlotClassifier",
            "raw_opcode_equal": classifier_raw.opcode_equal,
            "raw_logical_access_equal": classifier_raw.logical_equal,
            "raw_physical_equal": classifier_raw.physical_equal,
            "same_same_control_equal": classifier_same_same.physical_equal,
        },
        "exact_uo": [
            trace_summary("FixedSlotClassifier", "uo", &classifier_uo),
            trace_summary("AuthScan", "uo", &auth_uo),
            trace_summary("ConfidentialMixer", "uo", &mixer_uo),
        ],
        "computational_uo": [
            trace_summary("ConfidentialMixer", "oram", &mixer_oram),
        ],
    }))
}

fn run_auc_reports(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let experiments = vec![
        ("FixedSlotClassifier", "raw", run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)?),
        ("FixedSlotClassifier", "uo", run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)?),
        ("AuthScan", "raw", run_authscan_experiment(&suite["AuthScan"].raw)?),
        ("AuthScan", "uo", run_authscan_experiment(&suite["AuthScan"].uo)?),
        ("RegistryCRUD", "raw", run_registry_experiment(&suite["RegistryCRUD"].raw)?),
        ("RegistryCRUD", "uo", run_registry_experiment(&suite["RegistryCRUD"].uo)?),
        ("ConfidentialMixer", "raw", run_mixer_experiment(&suite["ConfidentialMixer"].raw)?),
        ("ConfidentialMixer", "uo", run_mixer_experiment(&suite["ConfidentialMixer"].uo)?),
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

fn run_mutual_information_reports(suite: &BTreeMap<&'static str, BenchArtifacts>) -> Result<JsonValue> {
    let experiments = vec![
        ("FixedSlotClassifier", "raw", run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].raw)?),
        ("FixedSlotClassifier", "uo", run_fixed_classifier_experiment(&suite["FixedSlotClassifier"].uo)?),
        ("AuthScan", "raw", run_authscan_experiment(&suite["AuthScan"].raw)?),
        ("AuthScan", "uo", run_authscan_experiment(&suite["AuthScan"].uo)?),
        ("RegistryCRUD", "raw", run_registry_experiment(&suite["RegistryCRUD"].raw)?),
        ("RegistryCRUD", "uo", run_registry_experiment(&suite["RegistryCRUD"].uo)?),
        ("ConfidentialMixer", "raw", run_mixer_experiment(&suite["ConfidentialMixer"].raw)?),
        ("ConfidentialMixer", "uo", run_mixer_experiment(&suite["ConfidentialMixer"].uo)?),
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
        .map(|call| instance.call(call.entrypoint, call.args.clone()).map(|result| result.return_value))
        .collect::<Result<Vec<_>>>()?;
    Ok(ScenarioResult { target, getters })
}

#[derive(Clone)]
struct ExperimentOutcome {
    class0_metrics: Vec<BTreeMap<String, f64>>,
    class1_metrics: Vec<BTreeMap<String, f64>>,
    opcode_equal: bool,
    logical_equal: bool,
    physical_equal: bool,
}

fn run_fixed_classifier_experiment(artifact: &CompiledArtifact) -> Result<ExperimentOutcome> {
    run_binary_experiment(
        artifact,
        &[],
        "classify(uint256)",
        vec![vec![Value::Uint(0)], vec![Value::Uint(2)], vec![Value::Uint(4)], vec![Value::Uint(6)]],
        vec![vec![Value::Uint(1)], vec![Value::Uint(3)], vec![Value::Uint(5)], vec![Value::Uint(7)]],
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
        opcode_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| &hash.opcode_trace_hash),
        logical_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| &hash.logical_access_trace_hash),
        physical_equal: hashes_equal(&class0_hashes, &class1_hashes, |hash| &hash.physical_write_trace_hash),
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
        "physical_trace_equal": outcome.physical_equal,
    })
}

fn extract_metrics(trace: &uo_core::ExecutionTrace) -> BTreeMap<String, f64> {
    let mut metrics = trace.host_proxy_metrics.clone();
    metrics.insert(
        "same_writes".into(),
        trace.physical_writes.iter().filter(|event| event.class == WriteClass::Same).count() as f64,
    );
    metrics.insert(
        "set_writes".into(),
        trace.physical_writes.iter().filter(|event| event.class == WriteClass::Set).count() as f64,
    );
    metrics.insert(
        "clear_writes".into(),
        trace.physical_writes.iter().filter(|event| event.class == WriteClass::Clear).count() as f64,
    );
    metrics.insert(
        "update_writes".into(),
        trace.physical_writes.iter().filter(|event| event.class == WriteClass::Update).count() as f64,
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
        report.insert(metric, json!(mutual_information_bits(&negatives, &positives)));
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

Security tiers:

- Exact-UO: `FixedSlotClassifier`, `AuthScan`, `ConfidentialMixer` full-scan, and `RegistryCRUD` use fixed-shape commits and normalized `M+` traces that are identical across secret variations in this instrumented abstract machine.
- Computational-UO: `ConfidentialMixer` ORAM and `ERC20Lite` ORAM use a public-schedule append-style ORAM surrogate that rewrites a logarithmic bucket batch while keeping `M+` update classes secret-independent.

Unsupported / rejected:

- inline assembly / Yul
- dynamic strings and dynamic bytes
- unbounded mappings and dynamic arrays without fixed public capacity
- recursion, `try/catch`, events, custom errors, `while` / `do while`, external calls, and early confidential returns

Prototype assumptions:

- `uint256` syntax is accepted, but the current executable prototype evaluates arithmetic in a bounded `u128` domain for the benchmark suite.
- The ORAM backend is an instrumented runtime prototype with a trusted in-memory logical index and public-schedule bucket rewrites; it is reported as computational-UO only.
- The guarantees are with respect to the abstract/runtime traces emitted by this artifact, not every downstream machine-code or microarchitectural observer.
"#
}
