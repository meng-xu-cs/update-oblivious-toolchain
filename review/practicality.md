# Practicality assessment and opportunities

## Bottom-line assessment

The toolchain is practical as a research artifact and proof-boundary demonstrator. It is not yet practical as a tool that ordinary Solidity developers can use to deploy privacy-preserving contracts.

The intended Solidity-subset restrictions are acceptable for a research prototype. The more damaging practical restrictions are unintended or only partially intended: missing output/declassification policy, fail-open metadata, no calldata-capable CLI, custom runtime instead of deployable bytecode, arithmetic/Keccak semantic mismatches, heavy proof artifacts, and no real TEE deployment story.

## What works well

- The project documents its claim boundary and TCB unusually explicitly (`README.md:28-101`).
- Proof-grade validation is integrated with actual emitted artifacts and many Lean checker executables.
- The result set includes correctness, trace-equivalence, leakage AUC/MI, tamper validation, source-backed runtime validation, and reproducibility artifacts.
- The tamper suite is large: `results/tamper_validation.json` reports 379 scenarios, all rejected.
- The subset rejects many hard Solidity features up front, which is a reasonable research strategy.

## Practical blockers beyond the intentionally small Solidity subset

### 1. No first-class policy for return values and declassification

A practical contract frequently needs to return balances, booleans, receipts, or encrypted data. The current observer records only return length/shape, while the runtime returns actual values. Without a policy, users cannot know whether a returned value is protected, public, encrypted, or declassified.

**Improvement.** Add `returns: public | encrypted | declassified | forbidden` to sidecar metadata and enforce it in compiler, runtime, and Lean.

### 2. Secret-dependent success/failure is common in smart contracts

`transfer`, `withdraw`, authorization checks, and bounds checks naturally branch on secret state. If the status bit is public, many practical contracts leak through success/failure.

**Improvement.** Provide design patterns: public preconditions, encrypted/private failure, explicit declassification of success, or commit-with-fixed-public-status semantics.

### 3. Sidecar metadata is manual and fail-open

The compiler treats missing metadata as public. That is dangerous for practical use and will produce silent security regressions.

**Improvement.** Fail closed. Require every external/public entrypoint and state object to have explicit policy. Provide a linter that prints a complete policy table.

### 4. CLI does not accept call arguments

`uo-evm` CLI exposes `--artifact`, `--entrypoint`, `--seed`, and `--format`, but no calldata/arguments. The `run_artifact` helpers call entrypoints with `Vec::new()`.

**Evidence.** `runtime/uo-evm/src/main.rs:31-40`; `runtime/uo-evm/src/engine.rs:119-130`.

**Improvement.** Add `--args-json`, `--calldata`, or ABI JSON input and print both proof trace and public/declassified output. Add multi-call scripts for histories.

### 5. Custom runtime, not deployable EVM bytecode

The README already says not to deploy raw EVM bytecode to a public chain (`README.md:3-7`). This is acceptable for research, but it means the toolchain is not a drop-in Solidity tool.

**Improvement.** Position it as a TEE/off-chain confidential execution engine for now. Provide a bridge/harness that can be called by an on-chain wrapper and emits verifiable receipts/proofs.

### 6. Arithmetic is not Solidity-compatible

The docs admit accepted `uint256` syntax executes in `u128` (`docs/supported-subset.md:43-46`), but the Lean semantics do not match runtime `u128` either. This makes practical developer expectations hazardous.

**Improvement.** Rename the type in the supported subset (`uo_uint128`) or implement/prove real `uint256`/Solidity 0.8 checked arithmetic semantics.

### 7. Keccak and map semantics are abstraction-heavy

Keccak is supported in the subset, but Lean uses a zero mock for value flow. Practical maps and ERC20 allowances depend on real hashing behavior.

**Improvement.** Add a Keccak abstraction theorem or actual hash spec/test-vector bridge, and clearly separate “trace proof” from “functional correctness over hashed keys.”

### 8. Fixed capacities and ORAM overhead

Every map has a public capacity. This is necessary for UO/ORAM, but it is burdensome and expensive. Existing results show a sample `ConfidentialMixer/deposit` raw path with 64 bytes written and 2 physical writes, versus ORAM-64 with 56,520 bytes written and 49 physical writes, and full-scan-64 with 12,284 bytes and 65 physical writes (`results/overheads.json`).

**Improvement.** Provide capacity-planning tools, amortized resizing protocols, sparse ORAM options, and benchmarks across capacities 16–4096.

### 9. Proof artifacts are large and validation is expensive

`results/reviewer_summary.md` reports total probe time around 1,484,894 ms, with some validation steps taking hundreds of seconds. It also reports materialized artifacts up to about 188 MB.

**Improvement.** Cache derived certificates, split heavyweight proof artifacts from developer feedback, add a fast “policy + local trace” mode, and reserve canonical/heavy ORAM certificates for CI/release.

### 10. Public getters can undermine confidentiality

Sidecars mark some getters public while state objects are confidential. That may be intentional declassification, but without a policy it is easy to accidentally expose confidential state.

**Improvement.** Require getter declarations to state exactly what they declassify, to whom, and in what form. Make public getters over confidential state fail by default.

### 11. No realistic TEE deployment harness

The theorem names SGX/TEE assumptions, but practical users need key management, attestation, rollback protection, crash recovery, sealing, versioning, and patch-level story.

**Improvement.** Add a minimal enclave/TEE demo, remote-attestation transcript, sealed-state rollback counter, and encrypted return-channel integration. Keep raw SGX page IDs and physical side channels as non-claims unless modeled.

### 12. Developer ecosystem gap

No Foundry/Hardhat integration, no ABI-level tests, no contract migration tools, and no user-facing policy diagnostics.

**Improvement.** Add a `uo-solc policy-report` command, Foundry-style differential tests, and examples that demonstrate safe patterns: confidential map update, encrypted query, public success declassification, and public-only setup.

## Recommended practicality roadmap

1. **Security-policy MVP.** Fail-closed metadata, explicit return/status/declassification policy, public getter restrictions.
2. **Usability MVP.** CLI calldata/args, multi-call histories, ABI JSON, policy report, clear public/declassified output.
3. **Semantic MVP.** Match Lean and runtime arithmetic, div-by-zero, and Keccak; add differential tests.
4. **Proof-audit MVP.** Axiom-free proof-grade root and final theorem `#print axioms` reports.
5. **Deployment MVP.** TEE wrapper with attestation, encrypted return path, sealed-state freshness/rollback story.
6. **Performance MVP.** Capacity planner, ORAM/full-scan tradeoff reports, artifact caching.
