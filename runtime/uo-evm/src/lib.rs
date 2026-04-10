mod engine;
mod objects;

pub use engine::{run_artifact, CallResult, ContractInstance};

#[cfg(test)]
mod tests {
    use super::ContractInstance;
    use uo_core::{ContractMetadata, ProgramMode, Value, WriteClass};

    fn compile_bench(source: &str, metadata: &str, mode: ProgramMode) -> uo_core::CompiledArtifact {
        let metadata: ContractMetadata = serde_yaml::from_str(metadata).unwrap();
        uo_solc::compile(source, &metadata, mode).unwrap()
    }

    #[test]
    fn raw_classifier_leaks_update_class() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.raw.yaml"),
            ProgramMode::Raw,
        );
        let mut raw_zero = ContractInstance::deploy(artifact.clone()).unwrap();
        let zero = raw_zero
            .call("classify(uint256)", vec![Value::Uint(0)])
            .unwrap();
        let mut raw_one = ContractInstance::deploy(artifact).unwrap();
        let one = raw_one
            .call("classify(uint256)", vec![Value::Uint(1)])
            .unwrap();
        assert_eq!(zero.trace.hashes().opcode_trace_hash, one.trace.hashes().opcode_trace_hash);
        assert_eq!(
            zero.trace.hashes().logical_access_trace_hash,
            one.trace.hashes().logical_access_trace_hash
        );
        assert_eq!(zero.trace.physical_writes[0].class, WriteClass::Same);
        assert_eq!(one.trace.physical_writes[0].class, WriteClass::Set);
    }

    #[test]
    fn uo_classifier_rewrites_to_update_only() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/FixedSlotClassifier.uo.yaml"),
            ProgramMode::Uo,
        );
        let mut zero_instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let zero = zero_instance
            .call("classify(uint256)", vec![Value::Uint(0)])
            .unwrap();
        let mut one_instance = ContractInstance::deploy(artifact).unwrap();
        let one = one_instance
            .call("classify(uint256)", vec![Value::Uint(1)])
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
            zero.trace.hashes().physical_write_trace_hash,
            one.trace.hashes().physical_write_trace_hash
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
        inst0.call("seed(uint256,bytes32)", vec![Value::Uint(0), token0.clone()])
            .unwrap();
        inst0.call("seed(uint256,bytes32)", vec![Value::Uint(1), token1.clone()])
            .unwrap();
        let hit = inst0.call("auth(bytes32)", vec![token0]).unwrap();

        let mut inst1 = ContractInstance::deploy(artifact).unwrap();
        inst1.call("seed(uint256,bytes32)", vec![Value::Uint(0), Value::Bytes32([1u8; 32])])
            .unwrap();
        inst1.call("seed(uint256,bytes32)", vec![Value::Uint(1), Value::Bytes32([2u8; 32])])
            .unwrap();
        let miss = inst1.call("auth(bytes32)", vec![token_absent]).unwrap();

        assert_eq!(
            hit.trace.hashes().opcode_trace_hash,
            miss.trace.hashes().opcode_trace_hash
        );
        assert_eq!(
            hit.trace.hashes().logical_access_trace_hash,
            miss.trace.hashes().logical_access_trace_hash
        );
        assert_eq!(
            hit.trace.hashes().physical_write_trace_hash,
            miss.trace.hashes().physical_write_trace_hash
        );
        assert_eq!(hit.trace.gas_used, 8192);
        assert_eq!(miss.trace.gas_used, 8192);
    }

    #[test]
    fn mixer_abort_is_normalized_but_state_is_preserved() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.uo.yaml"),
            ProgramMode::Uo,
        );
        let key = Value::Bytes32([9u8; 32]);

        let mut ok_inst = ContractInstance::deploy(artifact.clone()).unwrap();
        ok_inst
            .call("deposit(bytes32,uint256)", vec![key.clone(), Value::Uint(5)])
            .unwrap();
        let ok = ok_inst
            .call("withdraw(bytes32,uint256)", vec![key.clone(), Value::Uint(2)])
            .unwrap();
        let ok_balance = ok_inst.call("balanceOf(bytes32)", vec![key.clone()]).unwrap();

        let mut abort_inst = ContractInstance::deploy(artifact).unwrap();
        abort_inst
            .call("deposit(bytes32,uint256)", vec![key.clone(), Value::Uint(5)])
            .unwrap();
        let abort = abort_inst
            .call("withdraw(bytes32,uint256)", vec![key.clone(), Value::Uint(9)])
            .unwrap();
        let abort_balance = abort_inst.call("balanceOf(bytes32)", vec![key]).unwrap();

        assert_eq!(ok.trace.gas_used, 16384);
        assert_eq!(abort.trace.gas_used, 16384);
        assert_eq!(
            ok.trace.hashes().physical_write_trace_hash,
            abort.trace.hashes().physical_write_trace_hash
        );
        assert_eq!(ok.return_value, Some(Value::Uint(2)));
        assert_eq!(abort.return_value, None);
        assert_eq!(ok_balance.return_value, Some(Value::Uint(3)));
        assert_eq!(abort_balance.return_value, Some(Value::Uint(5)));
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
        inst.call("mint(address,uint256)", vec![alice.clone(), Value::Uint(10)])
            .unwrap();
        inst.call(
            "approve(address,address,uint256)",
            vec![alice.clone(), bob.clone(), Value::Uint(4)],
        )
        .unwrap();
        inst.call(
            "transferFrom(address,address,address,uint256)",
            vec![alice.clone(), bob.clone(), carol.clone(), Value::Uint(3)],
        )
        .unwrap();

        let alice_balance = inst.call("balanceOf(address)", vec![alice]).unwrap();
        let carol_balance = inst.call("balanceOf(address)", vec![carol]).unwrap();
        let allowance = inst
            .call("allowanceOf(address,address)", vec![Value::Address([0x11; 20]), bob])
            .unwrap();
        assert_eq!(alice_balance.return_value, Some(Value::Uint(7)));
        assert_eq!(carol_balance.return_value, Some(Value::Uint(3)));
        assert_eq!(allowance.return_value, Some(Value::Uint(1)));
    }

    #[test]
    fn mixer_oram_hides_secret_commitment_schedule() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/ConfidentialMixer.oram.yaml"),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call("deposit(bytes32,uint256)", vec![Value::Bytes32([1u8; 32]), Value::Uint(3)])
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call("deposit(bytes32,uint256)", vec![Value::Bytes32([9u8; 32]), Value::Uint(3)])
            .unwrap();
        assert_eq!(
            first_trace.trace.hashes().logical_access_trace_hash,
            second_trace.trace.hashes().logical_access_trace_hash
        );
        assert_eq!(
            first_trace.trace.hashes().logical_write_trace_hash,
            second_trace.trace.hashes().logical_write_trace_hash
        );
        assert_eq!(
            first_trace.trace.hashes().physical_write_trace_hash,
            second_trace.trace.hashes().physical_write_trace_hash
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
    fn erc20_oram_hides_secret_allowance_keys() {
        let artifact = compile_bench(
            "/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.sol",
            include_str!("/home/m285xu/update-oblivious-toolchain/benches/raw/ERC20Lite.oram.yaml"),
            ProgramMode::Uo,
        );
        let mut first = ContractInstance::deploy(artifact.clone()).unwrap();
        let first_trace = first
            .call(
                "approve(address,address,uint256)",
                vec![Value::Address([0x11; 20]), Value::Address([0x21; 20]), Value::Uint(3)],
            )
            .unwrap();
        let mut second = ContractInstance::deploy(artifact).unwrap();
        let second_trace = second
            .call(
                "approve(address,address,uint256)",
                vec![Value::Address([0x31; 20]), Value::Address([0x41; 20]), Value::Uint(3)],
            )
            .unwrap();
        assert_eq!(
            first_trace.trace.hashes().logical_access_trace_hash,
            second_trace.trace.hashes().logical_access_trace_hash
        );
        assert_eq!(
            first_trace.trace.hashes().logical_write_trace_hash,
            second_trace.trace.hashes().logical_write_trace_hash
        );
        assert_eq!(
            first_trace.trace.hashes().physical_write_trace_hash,
            second_trace.trace.hashes().physical_write_trace_hash
        );
        assert_eq!(first_trace.trace.gas_used, 14336);
        assert_eq!(second_trace.trace.gas_used, 14336);
    }
}
