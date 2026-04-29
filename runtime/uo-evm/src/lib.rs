#![allow(
    clippy::duplicate_mod,
    clippy::manual_unwrap_or_default,
    clippy::only_used_in_recursion,
    clippy::too_many_arguments,
    clippy::type_complexity
)]

mod controller;
mod engine;
mod oram;
mod runtime;

pub use engine::{run_artifact, run_artifact_with_seed, CallResult, ContractInstance};
#[cfg(feature = "diagnostics")]
pub use engine::{CallTelemetry, DiagnosticCallResult};
#[cfg(feature = "diagnostics")]
pub use runtime::PathOramFreshCoinPlan;

#[cfg(test)]
mod tests {
    use super::ContractInstance;
    #[cfg(feature = "diagnostics")]
    use super::PathOramFreshCoinPlan;
    use uo_core::ir::BackendKind;
    #[cfg(feature = "diagnostics")]
    use uo_core::{
        canonical_path_oram_leaf_seed_space_size, canonical_path_oram_leaf_values_of_seed,
    };
    use uo_core::{
        ContractMetadata, ExecutionTrace, KernelWitnessError, ProgramMode, RefinementWitnessError,
        RuntimeConfidentialCoreKernelInterfaceSlotBundleError,
        RuntimeConfidentialCoreShellBoundaryLoweringBundleError,
        RuntimeConfidentialCoreShellBoundarySlotBundleError,
        RuntimeConfidentialProofBundleFamilyError, RuntimeKernelInterfaceBundleError,
        RuntimeKernelRefinementEventKindWitness, RuntimeKernelRefinementEventWitness,
        RuntimeKernelStepWitness, RuntimeShellBoundaryLoweringBundleError,
        RuntimeShellBoundarySlotBundleError, RuntimeTrustedKernelSlotBundleError,
        SeededRuntimePaperMainFamilyBundle, SeededRuntimePaperMainSlotFamilyBundle, TheoremTrace,
        Value, WriteClass,
    };
    use uo_precompiles::UoOpcode;

    fn compile_bench(source: &str, metadata: &str, mode: ProgramMode) -> uo_core::CompiledArtifact {
        let metadata: ContractMetadata = serde_yaml::from_str(metadata).unwrap();
        uo_solc::compile(source, &metadata, mode).unwrap()
    }

    #[test]
    fn confidential_raw_classifier_is_rejected() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.raw.yaml"
            ),
            ProgramMode::Raw,
        );
        let err = ContractInstance::deploy(artifact).unwrap_err();
        assert!(
            err.to_string()
                .contains("confidential object last uses raw backend"),
            "unexpected error: {err:?}"
        );
    }

    #[test]
    fn confidential_entrypoint_rejects_public_raw_kernel_target_after_artifact_tamper() {
        let mut artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        artifact.contract.state[0].backend = BackendKind::Raw;
        artifact.contract.state[0].confidential = false;
        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let err = instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap_err();
        assert!(
            err.to_string().contains("targets raw backend object last"),
            "unexpected error: {err:?}"
        );
    }

    #[test]
    fn uo_classifier_rewrites_to_update_only() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut zero_instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let zero = zero_instance
            .call("classify(uint256)", vec![Value::uint(0)])
            .unwrap();
        let mut one_instance = ContractInstance::deploy(artifact).unwrap();
        let one = one_instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap();
        assert!(zero
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert!(one
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert_eq!(
            zero.trace.hashes().unwrap().physical_access_trace_hash,
            one.trace.hashes().unwrap().physical_access_trace_hash
        );
        assert_eq!(zero.trace.gas_used, 4096);
        assert_eq!(one.trace.gas_used, 4096);
    }

    #[test]
    fn authscan_exact_trace_is_secret_independent() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.uo.yaml"),
            ProgramMode::Uo,
        );
        let token0 = Value::Bytes32([1u8; 32]);
        let token1 = Value::Bytes32([2u8; 32]);
        let token_absent = Value::Bytes32([3u8; 32]);

        let mut inst0 = ContractInstance::deploy(artifact.clone()).unwrap();
        inst0
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), token0.clone()],
            )
            .unwrap();
        inst0
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), token1.clone()],
            )
            .unwrap();
        let hit = inst0.call("auth(bytes32)", vec![token0]).unwrap();

        let mut inst1 = ContractInstance::deploy(artifact).unwrap();
        inst1
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), Value::Bytes32([1u8; 32])],
            )
            .unwrap();
        inst1
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), Value::Bytes32([2u8; 32])],
            )
            .unwrap();
        let miss = inst1.call("auth(bytes32)", vec![token_absent]).unwrap();

        assert_eq!(
            hit.trace.hashes().unwrap().opcode_trace_hash,
            miss.trace.hashes().unwrap().opcode_trace_hash
        );
        assert_eq!(
            hit.trace.hashes().unwrap().logical_access_trace_hash,
            miss.trace.hashes().unwrap().logical_access_trace_hash
        );
        assert_eq!(
            hit.trace.hashes().unwrap().physical_access_trace_hash,
            miss.trace.hashes().unwrap().physical_access_trace_hash
        );
        assert_eq!(hit.trace.gas_used, 8192);
        assert_eq!(miss.trace.gas_used, 8192);
    }

    #[test]
    fn same_same_entrypoint_runs_with_exact_kernel_budget() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut inst = ContractInstance::deploy(artifact).unwrap();
        let result = inst
            .call("sameSame(uint256)", vec![Value::uint(5)])
            .unwrap();
        let peek = inst.call("peek()", vec![]).unwrap();

        assert_eq!(result.trace.gas_used, 4096);
        assert!(result
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert_eq!(peek.return_value, Some(Value::uint(1)));
    }

    #[test]
    fn mixer_abort_is_normalized_but_state_is_preserved() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        let key = Value::Bytes32([9u8; 32]);

        let mut ok_inst = ContractInstance::deploy(artifact.clone()).unwrap();
        ok_inst
            .call(
                "deposit(bytes32,uint256)",
                vec![key.clone(), Value::uint(5)],
            )
            .unwrap();
        let ok = ok_inst
            .call(
                "withdraw(bytes32,uint256)",
                vec![key.clone(), Value::uint(2)],
            )
            .unwrap();
        let ok_balance = ok_inst
            .call("balanceOf(bytes32)", vec![key.clone()])
            .unwrap();

        let mut abort_inst = ContractInstance::deploy(artifact).unwrap();
        abort_inst
            .call(
                "deposit(bytes32,uint256)",
                vec![key.clone(), Value::uint(5)],
            )
            .unwrap();
        let abort = abort_inst
            .call(
                "withdraw(bytes32,uint256)",
                vec![key.clone(), Value::uint(9)],
            )
            .unwrap();
        let abort_balance = abort_inst.call("balanceOf(bytes32)", vec![key]).unwrap();

        assert_eq!(ok.trace.gas_used, 16384);
        assert_eq!(abort.trace.gas_used, 16384);
        assert_eq!(
            ok.trace.hashes().unwrap().physical_access_trace_hash,
            abort.trace.hashes().unwrap().physical_access_trace_hash
        );
        assert_eq!(ok.return_value, Some(Value::uint(2)));
        assert_eq!(abort.return_value, None);
        let ok_outcome = ok.trace.theorem_trace.public_outcome.as_ref().unwrap();
        let abort_outcome = abort.trace.theorem_trace.public_outcome.as_ref().unwrap();
        assert_eq!(
            ok_outcome.return_policy,
            uo_core::ReturnPolicy::Declassified
        );
        assert_eq!(
            ok_outcome.status_policy,
            uo_core::StatusPolicy::Declassified
        );
        assert_eq!(ok_outcome.return_payload.as_deref(), Some("2"));
        assert_eq!(
            abort_outcome.return_policy,
            uo_core::ReturnPolicy::Declassified
        );
        assert_eq!(
            abort_outcome.status_policy,
            uo_core::StatusPolicy::Declassified
        );
        assert_eq!(abort_outcome.return_payload, None);
        assert_eq!(ok_balance.return_value, Some(Value::uint(3)));
        assert_eq!(abort_balance.return_value, Some(Value::uint(5)));
    }

    #[test]
    fn registry_clear_if_match_roundtrips() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/RegistryCRUD.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/RegistryCRUD.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        let key = Value::Bytes32([4u8; 32]);

        let mut inst = ContractInstance::deploy(artifact).unwrap();
        inst.call("upsert(bytes32,uint256)", vec![key.clone(), Value::uint(9)])
            .unwrap();
        let clear = inst
            .call(
                "clearIfMatch(bytes32,uint256)",
                vec![key.clone(), Value::uint(9)],
            )
            .unwrap();
        let read = inst.call("read(bytes32)", vec![key]).unwrap();

        assert_eq!(clear.trace.gas_used, 12288);
        assert_eq!(clear.return_value, Some(Value::uint(1)));
        assert_eq!(read.return_value, Some(Value::uint(0)));
    }

    #[test]
    fn erc20_keccak_helper_and_maps_roundtrip() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.uo.yaml"),
            ProgramMode::Uo,
        );
        let alice = Value::Address([0x11; 20]);
        let bob = Value::Address([0x22; 20]);
        let carol = Value::Address([0x33; 20]);

        let mut inst = ContractInstance::deploy(artifact).unwrap();
        inst.call(
            "mint(address,uint256)",
            vec![alice.clone(), Value::uint(10)],
        )
        .unwrap();
        inst.call(
            "approve(address,address,uint256)",
            vec![alice.clone(), bob.clone(), Value::uint(4)],
        )
        .unwrap();
        inst.call(
            "transferFrom(address,address,address,uint256)",
            vec![alice.clone(), bob.clone(), carol.clone(), Value::uint(3)],
        )
        .unwrap();

        let alice_balance = inst.call("balanceOf(address)", vec![alice]).unwrap();
        let carol_balance = inst.call("balanceOf(address)", vec![carol]).unwrap();
        let allowance = inst
            .call(
                "allowanceOf(address,address)",
                vec![Value::Address([0x11; 20]), bob],
            )
            .unwrap();
        assert_eq!(alice_balance.return_value, Some(Value::uint(7)));
        assert_eq!(carol_balance.return_value, Some(Value::uint(3)));
        assert_eq!(allowance.return_value, Some(Value::uint(1)));
    }

    #[test]
    fn mixer_oram_hides_secret_commitment_schedule() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call(
                "deposit(bytes32,uint256)",
                vec![Value::Bytes32([1u8; 32]), Value::uint(3)],
            )
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call(
                "deposit(bytes32,uint256)",
                vec![Value::Bytes32([9u8; 32]), Value::uint(3)],
            )
            .unwrap();
        assert_eq!(
            first_trace.trace.theorem_trace,
            second_trace.trace.theorem_trace
        );
        assert!(first_trace
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert!(second_trace
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert_eq!(first_trace.trace.gas_used, 12288);
        assert_eq!(second_trace.trace.gas_used, 12288);
    }

    #[test]
    fn mixer_path_oram_trace_builds_shared_paper_main_bundles() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let call = instance
            .call(
                "deposit(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(3)],
            )
            .unwrap();

        let family = call.trace.runtime_paper_main_family_bundle().unwrap();
        let slot_family = call
            .trace
            .runtime_paper_main_slot_family_bundle(&artifact)
            .unwrap();

        assert_eq!(
            family.public_outcome().entrypoint_id,
            "deposit(bytes32,uint256)"
        );
        assert_eq!(
            slot_family.confidential_slot_program().entrypoint_id,
            "deposit(bytes32,uint256)"
        );
        assert!(!family.boundary_schedule().is_empty());
        assert_eq!(slot_family.family(), family.family());

        let decoded_family: SeededRuntimePaperMainFamilyBundle =
            serde_json::from_str(&family.to_json().unwrap()).unwrap();
        let decoded_slot_family: SeededRuntimePaperMainSlotFamilyBundle =
            serde_json::from_str(&slot_family.to_json().unwrap()).unwrap();
        assert_eq!(decoded_family, family);
        assert_eq!(decoded_slot_family, slot_family);
    }

    #[test]
    fn erc20_oram_hides_secret_allowance_keys() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call(
                "approve(address,address,uint256)",
                vec![
                    Value::Address([0x11; 20]),
                    Value::Address([0x21; 20]),
                    Value::uint(3),
                ],
            )
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call(
                "approve(address,address,uint256)",
                vec![
                    Value::Address([0x31; 20]),
                    Value::Address([0x41; 20]),
                    Value::uint(3),
                ],
            )
            .unwrap();
        assert_eq!(
            first_trace.trace.theorem_trace,
            second_trace.trace.theorem_trace
        );
        assert_eq!(first_trace.trace.gas_used, 14336);
        assert_eq!(second_trace.trace.gas_used, 14336);
    }

    #[test]
    fn oram_theorem_trace_is_public_determined() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call(
                "deposit(bytes32,uint256)",
                vec![Value::Bytes32([1u8; 32]), Value::uint(3)],
            )
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call(
                "deposit(bytes32,uint256)",
                vec![Value::Bytes32([9u8; 32]), Value::uint(3)],
            )
            .unwrap();
        assert_eq!(
            first_trace.trace.theorem_trace,
            second_trace.trace.theorem_trace
        );
        let controller = first_trace
            .trace
            .theorem_trace
            .controller_shape
            .as_ref()
            .unwrap();
        assert_eq!(
            first_trace.trace.theorem_trace.boundary_schedule.len(),
            controller.boundary_event_budget
        );
        assert_eq!(
            first_trace
                .trace
                .theorem_trace
                .normalized_micro_trace
                .as_ref()
                .unwrap()
                .page_trace
                .len(),
            controller
                .page_trace_regions
                .iter()
                .map(|region| region.event_budget)
                .sum::<usize>()
        );
    }

    #[test]
    fn path_oram_candidate_hides_single_access_keys() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call(
                "put(bytes32,uint256)",
                vec![Value::Bytes32([1u8; 32]), Value::uint(7)],
            )
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call(
                "put(bytes32,uint256)",
                vec![Value::Bytes32([9u8; 32]), Value::uint(7)],
            )
            .unwrap();
        let first_witness = first_trace.trace.runtime_refinement_witness().unwrap();
        let second_witness = second_trace.trace.runtime_refinement_witness().unwrap();

        assert_eq!(
            first_trace.trace.theorem_trace,
            second_trace.trace.theorem_trace
        );
        assert_eq!(
            first_witness
                .oram_leaf_schedule()
                .iter()
                .map(|step| (&step.object_name, step.bucket_count))
                .collect::<Vec<_>>(),
            second_witness
                .oram_leaf_schedule()
                .iter()
                .map(|step| (&step.object_name, step.bucket_count))
                .collect::<Vec<_>>()
        );
        assert!(first_trace
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert!(second_trace
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
    }

    #[test]
    fn path_oram_candidate_supports_multi_access_entrypoints() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([1u8; 32]), Value::uint(7)],
            )
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([9u8; 32]), Value::uint(7)],
            )
            .unwrap();
        let first_witness = first_trace.trace.runtime_refinement_witness().unwrap();
        let second_witness = second_trace.trace.runtime_refinement_witness().unwrap();

        assert_eq!(
            first_trace.trace.theorem_trace,
            second_trace.trace.theorem_trace
        );
        assert_eq!(
            first_witness
                .oram_leaf_schedule()
                .iter()
                .map(|step| (&step.object_name, step.bucket_count))
                .collect::<Vec<_>>(),
            second_witness
                .oram_leaf_schedule()
                .iter()
                .map(|step| (&step.object_name, step.bucket_count))
                .collect::<Vec<_>>()
        );
        assert_eq!(first_trace.trace.theorem_trace.boundary_schedule.len(), 6);
        assert_eq!(
            first_trace
                .trace
                .theorem_trace
                .controller_shape
                .as_ref()
                .unwrap()
                .boundary_event_budget,
            6
        );
        assert!(first_trace
            .trace
            .physical_writes
            .iter()
            .all(|event| event.class == WriteClass::Update));
        assert_eq!(
            first_trace
                .trace
                .logical_accesses
                .iter()
                .filter(|event| event.kind == "uooram_counter")
                .count(),
            2
        );
    }

    #[test]
    fn execution_trace_exports_refinement_witness() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let witness = result.trace.runtime_refinement_witness().unwrap();
        let kernel_witness = result.trace.exact_runtime_kernel_witness().unwrap();
        assert_eq!(witness.public_outcome().gas_used, result.trace.gas_used);
        assert_eq!(witness.trace().gas_used, result.trace.gas_used);
        assert_eq!(witness.kernel_witness(), Some(&kernel_witness));
        assert_eq!(
            witness.boundary_schedule().len(),
            witness.controller_shape().boundary_event_budget
        );
        assert_eq!(
            witness.normalized_micro_trace(),
            &witness.controller_shape().normalized_micro_trace()
        );
    }

    #[test]
    fn execution_trace_exports_confidential_kernel_witness() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.uo.yaml"),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), Value::Bytes32([1u8; 32])],
            )
            .unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), Value::Bytes32([2u8; 32])],
            )
            .unwrap();
        let result = instance
            .call("auth(bytes32)", vec![Value::Bytes32([1u8; 32])])
            .unwrap();
        let witness = result
            .trace
            .runtime_kernel_witness_for_confidential(&artifact, "auth(bytes32)")
            .unwrap();
        let bundle = result.trace.runtime_trusted_kernel_bundle().unwrap();
        assert_eq!(bundle.kernel_witness(), Some(&witness));
        assert_eq!(
            result
                .trace
                .runtime_refinement_witness()
                .unwrap()
                .kernel_witness(),
            Some(witness.clone()).as_ref()
        );
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get("auth(bytes32)")
            .unwrap();
        let manifest_expected_kernel_steps = manifest_entry.kernel_step_witnesses();
        assert_eq!(
            witness.expected_kernel_steps(),
            Some(manifest_expected_kernel_steps.as_ref())
        );
        assert_eq!(
            witness.kernel_steps(),
            manifest_expected_kernel_steps.as_ref()
        );
        let emitted_kernel_schedule = witness.emitted_kernel_schedule();
        assert_eq!(
            emitted_kernel_schedule.opcodes().first().copied(),
            Some(uo_precompiles::UoOpcode::Begin)
        );
        assert_eq!(
            emitted_kernel_schedule.opcodes().last().copied(),
            Some(uo_precompiles::UoOpcode::Wipe)
        );
        assert_eq!(
            witness
                .kernel_steps()
                .first()
                .and_then(RuntimeKernelStepWitness::object_id),
            None
        );
        assert_eq!(
            witness
                .kernel_steps()
                .last()
                .and_then(RuntimeKernelStepWitness::object_id),
            None
        );
    }

    #[test]
    fn execution_trace_exports_trusted_kernel_slot_bundle() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.uo.yaml"),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), Value::Bytes32([1u8; 32])],
            )
            .unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), Value::Bytes32([2u8; 32])],
            )
            .unwrap();
        let result = instance
            .call("auth(bytes32)", vec![Value::Bytes32([1u8; 32])])
            .unwrap();
        let bundle = result
            .trace
            .runtime_trusted_kernel_slot_bundle(&artifact)
            .unwrap();
        let kernel_witness = result.trace.exact_runtime_kernel_witness().unwrap();

        assert_eq!(bundle.entrypoint_id(), "auth(bytes32)");
        assert!(bundle.program_matches_trusted_kernel_entrypoint());
        assert_eq!(
            bundle.confidential_slot_program().entrypoint_id,
            bundle.entrypoint_id()
        );
        assert_eq!(
            bundle.trusted_kernel_bundle().kernel_witness(),
            Some(&kernel_witness)
        );
        assert_eq!(
            bundle
                .confidential_slot_program()
                .expected_runtime_step_witnesses()
                .as_ref(),
            bundle
                .trusted_kernel_bundle()
                .kernel_witness()
                .cloned()
                .unwrap()
                .kernel_steps()
        );
    }

    #[test]
    fn execution_trace_exports_runtime_kernel_interface_bundle() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.uo.yaml"),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), Value::Bytes32([1u8; 32])],
            )
            .unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), Value::Bytes32([2u8; 32])],
            )
            .unwrap();
        let result = instance
            .call("auth(bytes32)", vec![Value::Bytes32([1u8; 32])])
            .unwrap();
        let bundle = result
            .trace
            .runtime_kernel_interface_bundle(&artifact)
            .unwrap();

        assert_eq!(
            bundle.shell_boundary_bundle().entrypoint_id(),
            "auth(bytes32)"
        );
        assert_eq!(
            bundle.expected_kernel_steps(),
            bundle.kernel_witness().kernel_steps()
        );
        assert_eq!(
            bundle.expected_public_object_ids(),
            bundle
                .kernel_witness()
                .expected_public_object_schedule()
                .unwrap()
        );
        assert_eq!(
            bundle.expected_kernel_schedule(),
            &bundle.kernel_witness().emitted_kernel_schedule()
        );
    }

    #[test]
    fn trusted_kernel_slot_bundle_rejects_slot_program_entrypoint_drift() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.uo.yaml"),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), Value::Bytes32([1u8; 32])],
            )
            .unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), Value::Bytes32([2u8; 32])],
            )
            .unwrap();
        let result = instance
            .call("auth(bytes32)", vec![Value::Bytes32([1u8; 32])])
            .unwrap();

        let mut tampered_artifact = artifact.clone();
        tampered_artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("auth(bytes32)")
            .unwrap()
            .confidential_slot_program
            .as_mut()
            .unwrap()
            .entrypoint_id = "deposit(bytes32,uint256)".into();

        assert_eq!(
            result
                .trace
                .runtime_trusted_kernel_slot_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeTrustedKernelSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                expected_entrypoint: "auth(bytes32)".into(),
                program_entrypoint: "deposit(bytes32,uint256)".into(),
            }
        );
    }

    #[test]
    fn runtime_kernel_interface_bundle_rejects_manifest_kernel_step_drift() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/AuthScan.uo.yaml"),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(0), Value::Bytes32([1u8; 32])],
            )
            .unwrap();
        instance
            .call(
                "seed(uint256,bytes32)",
                vec![Value::uint(1), Value::Bytes32([2u8; 32])],
            )
            .unwrap();
        let result = instance
            .call("auth(bytes32)", vec![Value::Bytes32([1u8; 32])])
            .unwrap();

        let mut tampered_artifact = artifact.clone();
        tampered_artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("auth(bytes32)")
            .unwrap()
            .kernel_steps
            .pop();

        assert!(matches!(
            result
                .trace
                .runtime_kernel_interface_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeKernelInterfaceBundleError::KernelWitness(
                KernelWitnessError::KernelStepTraceMismatch { .. }
            )
        ));
    }

    #[test]
    fn execution_trace_exports_runtime_phase_refinement_witness() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let kernel_witness = result.trace.exact_runtime_kernel_witness().unwrap();
        let phase_witness = result
            .trace
            .exact_runtime_kernel_refinement_witness()
            .unwrap();
        assert_eq!(
            phase_witness.projected_kernel_schedule(),
            kernel_witness.emitted_kernel_schedule()
        );
        assert_eq!(phase_witness.shadow_load_object_schedule().as_ref(), &[1]);
        assert_eq!(phase_witness.commit_object_schedule().as_ref(), &[1]);
        assert_eq!(phase_witness.cold_store_object_schedule().as_ref(), &[1]);
        assert_eq!(
            phase_witness
                .first_event()
                .map(RuntimeKernelRefinementEventWitness::kind),
            Some(RuntimeKernelRefinementEventKindWitness::PreCommittedColdObject)
        );
        assert_eq!(
            phase_witness
                .last_event()
                .map(RuntimeKernelRefinementEventWitness::kind),
            Some(RuntimeKernelRefinementEventKindWitness::PostCommittedColdObject)
        );
        phase_witness
            .validate_with_kernel_witness(&kernel_witness)
            .unwrap();
    }

    #[test]
    fn execution_trace_exports_confidential_core_shell_boundary_slot_bundle() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let bundle = result
            .trace
            .runtime_confidential_core_shell_boundary_slot_bundle(&artifact)
            .unwrap();
        assert_eq!(bundle.entrypoint_id(), "add(bytes32,uint256)");
        assert!(bundle.program_matches_runtime_entrypoint());
        assert_eq!(
            bundle.shell_boundary_bundle().entrypoint_id(),
            bundle.entrypoint_id()
        );
        assert_eq!(
            bundle.confidential_slot_program().entrypoint_id,
            bundle.entrypoint_id()
        );
    }

    #[test]
    fn execution_trace_exports_confidential_core_kernel_interface_slot_bundle() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let bundle = result
            .trace
            .runtime_confidential_core_kernel_interface_slot_bundle(&artifact)
            .unwrap();
        assert_eq!(bundle.entrypoint_id(), "add(bytes32,uint256)");
        assert!(bundle.program_matches_runtime_entrypoint());
        assert_eq!(
            bundle.kernel_interface_bundle().entrypoint_id(),
            bundle.entrypoint_id()
        );
        assert_eq!(
            bundle.confidential_slot_program().entrypoint_id,
            bundle.entrypoint_id()
        );
        assert_eq!(
            bundle
                .kernel_interface_bundle()
                .kernel_witness()
                .expected_kernel_steps()
                .unwrap(),
            bundle
                .confidential_slot_program()
                .expected_runtime_step_witnesses()
                .as_ref()
        );
    }

    #[test]
    fn execution_trace_exports_runtime_confidential_proof_bundle_family() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let bundle_family = result
            .trace
            .runtime_confidential_proof_bundle_family(&artifact)
            .unwrap();

        assert_eq!(bundle_family.entrypoint_id(), "add(bytes32,uint256)");
        assert_eq!(
            bundle_family
                .runtime_kernel_interface_bundle()
                .entrypoint_id(),
            bundle_family.entrypoint_id()
        );
        assert_eq!(
            bundle_family
                .runtime_confidential_core_kernel_interface_slot_bundle()
                .entrypoint_id(),
            bundle_family.entrypoint_id()
        );
        assert_eq!(
            bundle_family
                .runtime_paper_main_family_bundle()
                .public_outcome()
                .entrypoint_id,
            bundle_family.entrypoint_id()
        );
        assert_eq!(
            bundle_family
                .runtime_paper_main_slot_family_bundle()
                .confidential_slot_program()
                .entrypoint_id,
            bundle_family.entrypoint_id()
        );
    }

    #[test]
    fn confidential_core_shell_boundary_slot_bundle_rejects_slot_program_entrypoint_drift() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();

        let mut tampered_artifact = artifact.clone();
        tampered_artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("add(bytes32,uint256)")
            .unwrap()
            .confidential_slot_program
            .as_mut()
            .unwrap()
            .entrypoint_id = "put(bytes32,uint256)".into();

        assert_eq!(
            result
                .trace
                .runtime_shell_boundary_slot_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeShellBoundarySlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                expected_entrypoint: "add(bytes32,uint256)".into(),
                program_entrypoint: "put(bytes32,uint256)".into(),
            }
        );
        assert_eq!(
            result
                .trace
                .runtime_confidential_core_shell_boundary_slot_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeConfidentialCoreShellBoundarySlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                expected_entrypoint: "add(bytes32,uint256)".into(),
                program_entrypoint: "put(bytes32,uint256)".into(),
            }
        );
        assert_eq!(
            result
                .trace
                .runtime_confidential_core_kernel_interface_slot_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeConfidentialCoreKernelInterfaceSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                expected_entrypoint: "add(bytes32,uint256)".into(),
                program_entrypoint: "put(bytes32,uint256)".into(),
            }
        );
        assert_eq!(
            result
                .trace
                .runtime_confidential_proof_bundle_family(&tampered_artifact)
                .unwrap_err(),
            RuntimeConfidentialProofBundleFamilyError::KernelInterfaceSlot(
                RuntimeConfidentialCoreKernelInterfaceSlotBundleError::ConfidentialSlotProgramEntrypointMismatch {
                    expected_entrypoint: "add(bytes32,uint256)".into(),
                    program_entrypoint: "put(bytes32,uint256)".into(),
                }
            )
        );
    }

    #[test]
    fn confidential_core_shell_boundary_lowering_bundle_rejects_named_program_drift() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();

        let mut tampered_artifact = artifact.clone();
        let confidential_program = tampered_artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("add(bytes32,uint256)")
            .unwrap()
            .confidential_program
            .as_mut()
            .unwrap();
        let mut tampered_body = confidential_program.body.clone().into_vec();
        tampered_body.pop();
        confidential_program.body = tampered_body.into_boxed_slice();

        assert_eq!(
            result
                .trace
                .runtime_shell_boundary_lowering_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeShellBoundaryLoweringBundleError::ConfidentialProgramLoweringMismatch {
                entrypoint: "add(bytes32,uint256)".into(),
            }
        );
        assert_eq!(
            result
                .trace
                .runtime_confidential_core_shell_boundary_lowering_bundle(&tampered_artifact)
                .unwrap_err(),
            RuntimeConfidentialCoreShellBoundaryLoweringBundleError::ConfidentialProgramLoweringMismatch {
                entrypoint: "add(bytes32,uint256)".into(),
            }
        );
    }

    #[test]
    fn call_rejects_confidential_core_kernel_interface_slot_drift() {
        let mut artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("add(bytes32,uint256)")
            .unwrap()
            .confidential_slot_program
            .as_mut()
            .unwrap()
            .entrypoint_id = "put(bytes32,uint256)".into();

        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let err = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap_err();
        let err = err.to_string();
        assert!(
            err.contains("drifted from admitted artifact")
                || err.contains("entrypoint mismatch")
                || err.contains("manifest confidential slot program expected entrypoint"),
            "unexpected error: {err}"
        );
    }

    #[test]
    fn serialized_execution_trace_preserves_trusted_kernel_bundle_only_on_matching_trace() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let bundle = result.trace.runtime_trusted_kernel_bundle().unwrap();
        let kernel_witness = result
            .trace
            .runtime_kernel_witness_for_confidential(&artifact, "add(bytes32,uint256)")
            .unwrap();
        assert_eq!(
            result.trace.runtime_trusted_kernel_bundle().unwrap(),
            bundle
        );
        assert!(result.trace.exact_runtime_kernel_witness().is_ok());
        assert_eq!(bundle.kernel_witness(), Some(&kernel_witness));

        let encoded = serde_json::to_vec(&result.trace).unwrap();
        let encoded_json: serde_json::Value = serde_json::from_slice(&encoded).unwrap();
        let encoded_object = encoded_json.as_object().unwrap();
        assert!(
            !encoded_object.contains_key("runtime_kernel_witness"),
            "production execution traces should not serialize a redundant raw kernel witness when the finish bundle is present"
        );
        assert!(
            !encoded_object.contains_key("runtime_kernel_refinement_witness"),
            "production execution traces should not serialize a redundant raw runtime-phase witness when the finish bundle is present"
        );
        let decoded: ExecutionTrace = serde_json::from_slice(&encoded).unwrap();
        let decoded_kernel_witness = decoded.exact_runtime_kernel_witness().unwrap();
        let decoded_phase_witness = decoded.exact_runtime_kernel_refinement_witness().unwrap();
        assert_eq!(decoded.runtime_trusted_kernel_bundle().unwrap(), bundle);
        assert_eq!(decoded_kernel_witness, kernel_witness);
        assert_eq!(
            decoded_phase_witness,
            result
                .trace
                .exact_runtime_kernel_refinement_witness()
                .unwrap()
        );
        assert_eq!(decoded.runtime_trusted_kernel_bundle().unwrap(), bundle);
        assert_eq!(
            decoded
                .runtime_kernel_witness_for_confidential(&artifact, "add(bytes32,uint256)")
                .unwrap(),
            kernel_witness.clone()
        );
        assert_eq!(
            decoded.runtime_refinement_witness().unwrap(),
            result.trace.runtime_refinement_witness().unwrap()
        );

        let mut decoded_json: serde_json::Value = serde_json::from_slice(&encoded).unwrap();
        decoded_json["theorem_trace"] = serde_json::to_value(TheoremTrace::default()).unwrap();
        decoded_json
            .as_object_mut()
            .unwrap()
            .remove("runtime_controller_certificate");
        decoded_json["runtime_oram_position_map_after"] = serde_json::json!([]);
        decoded_json
            .as_object_mut()
            .unwrap()
            .remove("runtime_kernel_witness");
        let decoded: ExecutionTrace = serde_json::from_value(decoded_json).unwrap();

        assert_eq!(
            decoded.runtime_trusted_kernel_bundle().unwrap_err(),
            RefinementWitnessError::MissingPublicOutcome
        );
        assert_eq!(
            decoded
                .runtime_kernel_witness_for_confidential(&artifact, "add(bytes32,uint256)")
                .unwrap(),
            kernel_witness
        );
        assert_eq!(
            decoded.runtime_refinement_witness().unwrap_err(),
            RefinementWitnessError::MissingPublicOutcome
        );
    }

    #[test]
    fn deploy_with_seed_makes_path_oram_trace_replayable() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy_with_seed(artifact.clone(), 17).unwrap();
        let first_result = first
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let mut second = ContractInstance::deploy_with_seed(artifact, 17).unwrap();
        let second_result = second
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();

        assert_eq!(first_result.trace.runtime_seed(), Some(17));
        assert_eq!(second_result.trace.runtime_seed(), Some(17));
        assert_eq!(
            first_result.trace.hashes().unwrap(),
            second_result.trace.hashes().unwrap()
        );
        assert_eq!(
            first_result.trace.runtime_refinement_witness().unwrap(),
            second_result.trace.runtime_refinement_witness().unwrap()
        );
    }

    #[cfg(feature = "diagnostics")]
    #[test]
    fn injected_path_oram_fresh_coin_tape_realizes_canonical_values() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut baseline = ContractInstance::deploy_with_seed(artifact.clone(), 17).unwrap();
        let baseline_result = baseline
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let baseline_witness = baseline_result.trace.runtime_refinement_witness().unwrap();
        let fresh_coin_scaffold = baseline_witness.path_oram_fresh_coin_scaffold().unwrap();
        let seed_count = canonical_path_oram_leaf_seed_space_size(&fresh_coin_scaffold).unwrap();
        let canonical_values =
            canonical_path_oram_leaf_values_of_seed(&fresh_coin_scaffold, 1234 % seed_count)
                .unwrap();
        let fresh_coin_plan = PathOramFreshCoinPlan::from_scaffold_and_values(
            &fresh_coin_scaffold,
            &canonical_values,
        )
        .unwrap();

        let mut injected = ContractInstance::deploy_with_seed(artifact, 17).unwrap();
        let injected_result = injected
            .call_with_path_oram_fresh_coins(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
                fresh_coin_plan,
            )
            .unwrap();
        let injected_witness = injected_result.trace.runtime_refinement_witness().unwrap();

        assert_eq!(
            injected_witness.path_oram_fresh_coin_scaffold().unwrap(),
            fresh_coin_scaffold
        );
        assert_eq!(
            injected_witness.path_oram_fresh_coin_values().unwrap(),
            canonical_values
        );
    }

    #[cfg(feature = "diagnostics")]
    #[test]
    fn injected_path_oram_fresh_coin_tape_rejects_short_tape() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let mut baseline = ContractInstance::deploy_with_seed(artifact.clone(), 17).unwrap();
        let baseline_result = baseline
            .call(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
            )
            .unwrap();
        let baseline_witness = baseline_result.trace.runtime_refinement_witness().unwrap();
        let fresh_coin_scaffold = baseline_witness.path_oram_fresh_coin_scaffold().unwrap();
        let mut short_plan = PathOramFreshCoinPlan::new();
        short_plan
            .insert_object_coins(
                fresh_coin_scaffold[0].object_id,
                vec![0; fresh_coin_scaffold.len().saturating_sub(1)].into_boxed_slice(),
            )
            .unwrap();

        let mut injected = ContractInstance::deploy_with_seed(artifact, 17).unwrap();
        let err = injected
            .call_with_path_oram_fresh_coins(
                "add(bytes32,uint256)",
                vec![Value::Bytes32([7u8; 32]), Value::uint(5)],
                short_plan,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("requires injected fresh-leaf coins, but the tape is exhausted"));
    }

    #[test]
    fn transfer_from_witness_records_multi_object_oram_order() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        let balances_id = artifact
            .contract
            .state
            .iter()
            .find(|object| object.name == "balances")
            .unwrap()
            .id;
        let allowances_id = artifact
            .contract
            .state
            .iter()
            .find(|object| object.name == "allowances")
            .unwrap()
            .id;
        let owner = Value::Address([0x11; 20]);
        let spender = Value::Address([0x22; 20]);
        let recipient = Value::Address([0x33; 20]);

        let mut instance = ContractInstance::deploy(artifact).unwrap();
        instance
            .call(
                "mint(address,uint256)",
                vec![owner.clone(), Value::uint(10)],
            )
            .unwrap();
        instance
            .call(
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(6)],
            )
            .unwrap();
        let result = instance
            .call(
                "transferFrom(address,address,address,uint256)",
                vec![owner.clone(), spender.clone(), recipient, Value::uint(3)],
            )
            .unwrap();
        let witness = result.trace.runtime_refinement_witness().unwrap();
        let observed_ids = witness
            .controller_certificate()
            .observed_oram_accesses()
            .iter()
            .map(|access| access.object_id)
            .collect::<Vec<_>>();
        assert_eq!(
            observed_ids,
            vec![
                allowances_id,
                balances_id,
                allowances_id,
                balances_id,
                balances_id,
                balances_id,
            ]
        );
        let phase_witness = witness
            .runtime_kernel_refinement_witness()
            .cloned()
            .expect("runtime refinement witness should carry the lower-level phase witness");
        let expected_object_schedule = [
            allowances_id.min(balances_id),
            allowances_id.max(balances_id),
        ];
        assert_eq!(
            phase_witness.shadow_load_object_schedule().as_ref(),
            &expected_object_schedule
        );
        assert_eq!(
            phase_witness.commit_object_schedule().as_ref(),
            &expected_object_schedule
        );
        assert_eq!(
            phase_witness.cold_store_object_schedule().as_ref(),
            &expected_object_schedule
        );
    }

    #[test]
    fn call_rejects_manifest_oram_parameter_drift() {
        let mut artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/SingleAccessMap.pathoram.yaml"
            ),
            ProgramMode::Uo,
        );
        artifact
            .contract
            .manifest
            .objects
            .iter_mut()
            .find(|object| object.name == "records")
            .unwrap()
            .oram
            .as_mut()
            .unwrap()
            .buckets_per_access += 1;

        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let err = instance
            .call(
                "put(bytes32,uint256)",
                vec![Value::Bytes32([1u8; 32]), Value::uint(7)],
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("runtime ORAM parameter mismatch for object"));
    }

    #[test]
    fn call_rejects_manifest_kernel_step_drift_by_append() {
        let mut artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("classify(uint256)")
            .unwrap()
            .kernel_steps
            .push(uo_core::RuntimeKernelStepManifest {
                opcode: UoOpcode::Commit,
                object_id: None,
            });

        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let err = instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest kernel step trace drifted"));
    }

    #[test]
    fn call_rejects_missing_manifest_kernel_step_trace() {
        let mut artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("classify(uint256)")
            .unwrap()
            .kernel_steps
            .clear();

        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let err = instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest kernel step trace drifted"));
    }

    #[test]
    fn call_rejects_manifest_kernel_step_drift() {
        let mut artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!(
                "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"
            ),
            ProgramMode::Uo,
        );
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("classify(uint256)")
            .unwrap()
            .kernel_steps
            .clear();

        let mut instance = ContractInstance::deploy(artifact).unwrap();
        let err = instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest kernel step trace drifted"));
    }
}
