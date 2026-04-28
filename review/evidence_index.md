# Evidence index

This index lists the most important repository references used in the review.

## Claim and TCB

- `README.md:28-48` — current exact/computational claim boundary and non-claim for downstream machine code/full Rust refinement.
- `README.md:50-57` — frozen paper claim surface.
- `README.md:59-76` — frozen `View_SGX` observer and exact/normalized components.
- `README.md:78-89` — explicit backend/crypto/TEE assumptions.
- `README.md:91-101` — proof-grade TCB.

## Supported subset and practical limits

- `docs/supported-subset.md:3-20` — accepted Solidity features.
- `docs/supported-subset.md:21-32` — rejected features.
- `docs/supported-subset.md:34-41` — sidecar metadata requirements.
- `docs/supported-subset.md:43-50` — `uint256` syntax executed in `u128`; confidential entrypoints may not target raw backends.
- `runtime/uo-evm/src/main.rs:31-40` — CLI args have artifact/entrypoint/seed/format but no call args.
- `runtime/uo-evm/src/engine.rs:119-130` — `run_artifact` invokes entrypoints with empty argument vectors.

## Return payload and public outcome

- `crates/uo-core/src/trace.rs:131-153` — `OutputShape` and `PublicOutcomeTrace`, no return payload.
- `proof/lean/UOToolchain/TeeDeployment.lean:5-18` — Lean TEE view has output shape only.
- `proof/lean/UOToolchain/SgxRelation.lean:25-31` — SGX public outcome has output shape only.
- `runtime/uo-evm/src/engine.rs:22-27` — runtime `CallResult` contains `return_value: Option<Value>`.
- `runtime/uo-evm/src/engine.rs:100-114` — runtime call returns the value and trace.
- `runtime/uo-evm/src/controller.rs:504-518` — runtime converts return value to output shape.
- `benches/raw/SingleAccessMap.sol:19-20` and `benches/raw/SingleAccessMap.pathoram.yaml:12-14` — confidential read returns a map value.

## Abort/termination status

- `runtime/uo-evm/src/controller.rs:293-299` — public outcome uses `!aborted` as termination status.
- `runtime/uo-kernel-runtime/src/lib.rs:410-418` — abort clears return value.
- `proof/lean/UOToolchain/Sol.lean:261-271` — `require_` / `abortIf` status changes.
- `compiler/uo-solc/src/lib.rs:1762-1765` — `require` lowers to `abort_if`.
- `benches/raw/ConfidentialMixer.sol:13-18` and `benches/raw/ConfidentialMixer.oram.yaml:7-10` — confidential secret-dependent withdraw check.
- `benches/raw/ERC20Lite.oram.yaml:9-16` and `benches/uo/ERC20Lite.oram.json` transformed source — confidential transfer checks.

## Value semantics / Keccak

- `proof/lean/UOToolchain/IRSyntax.lean:45-47` — `uint` as `Nat` note.
- `proof/lean/UOToolchain/IRSemantics.lean:337-368` — Lean unary/binary arithmetic.
- `crates/uo-core/src/generated_confidential_kernel.rs:362-408` — generated runtime wrapping arithmetic and div/mod-by-zero behavior.
- `proof/lean/UOToolchain/IRSyntax.lean:203-262` — Keccak mock returns all-zero bytes.
- `runtime/uo-kernel-runtime/src/generated_machine.rs:100-101` — real `Keccak::v256`.
- `runtime/uo-evm/src/shell.rs:412` — real `Keccak::v256` in shell.

## Front-end and policy

- `proof/lean/UOToolchain/Sol.lean:30-46` — semantic preprocessing steps outside Lean model.
- `compiler/uo-solc/src/lib.rs:280-294` — missing metadata treated as public.
- `compiler/uo-solc/src/lib.rs:1720-1734` — confidential return-shape check enforces final/single return, not return secrecy.

## Legacy axioms / proof-grade import surface

- `proof/lean/UOToolchain/OramGame.lean:7` — `legacyOramLocalTheorem` axiom.
- `proof/lean/UOToolchain/SgxMicroGame.lean:7` — `legacySgxMicroLocalTheorem` axiom.
- `proof/lean/UOToolchain.lean:11,22` — umbrella imports legacy modules.
- `results/static_checks.json` — proof-grade checker import/symbol restrictions.

## Runtime source-backed interface

- `proof/lean/UOToolchain/RuntimeImplementationInterface.lean:30-85` — source-string containment/lack predicates.
- `proof/lean/UOToolchain/RuntimeImplementationInterface.lean:144-180` — Rust source fields in the interface.
- `results/runtime_implementation_interface_validation.json` — accepted source-backed runtime implementation interface and source-file list.

## Unsafe Rust

- `crates/uo-core/src/types.rs:70,101,108` — boxed builder unsafe.
- `runtime/uo-kernel-runtime/src/lib.rs:50-61` — slot-program boxing unsafe.
- `crates/uo-core/src/confidential_kernel.rs:559-570` — kernel-step boxing unsafe.
- `crates/uo-core/src/trace.rs:611-648,687,6620-6634` — trace/buffer unsafe.

## Existing evaluation artifacts

- `results/tamper_validation.json` — 379 tamper scenarios, all rejected in the provided archive.
- `results/trace_equivalence.json` — exact UO trace equality reports and ORAM computational-UO physical-trace non-equality.
- `results/leakage_auc.json` and `results/mutual_information.json` — empirical leakage metrics.
- `results/overheads.json` — sample raw/full-scan/ORAM overhead data.
- `results/reviewer_summary.md:3-79` — proof/report cost summary.
- `results/reviewer_summary.md:80-99` — largest materialized artifacts.
