# Executive findings

## Overall judgment

The bundle is impressive as a proof-boundary engineering artifact: it has a frozen observer, a proof-grade Path ORAM route, explicit result artifacts, and a large set of Lean validators. The strongest risk is not that the repository lacks effort; it is that some theorem boundaries are still too narrow or policy-free, so the project can accidentally prove a property of an instrumented trace while host-visible behavior still leaks through return values, aborts, or front-end policy mistakes.

I would treat the current claim as credible for: “accepted proof-grade artifacts emit checked trace/certificate objects whose modeled storage and controller traces satisfy the stated exact/ORAM observer relation, under explicit crypto/TEE/ORAM assumptions and the source-backed runtime boundary.”

I would not yet state without qualification: “real host-visible execution of arbitrary admitted confidential Solidity functions is update-oblivious,” because host-visible outputs, termination, source-level semantics, and admission/declassification policy need tightening.

## Highest-priority issues

| Priority | Finding | Why it matters | First remediation |
| --- | --- | --- | --- |
| P0 | Return values are host-visible but omitted from the observer. | `PublicOutcomeTrace` / SGX public outcome record output shape only, while the runtime returns `Option<Value>`. A confidential `read(key)` can leak the secret value even if the proof view is unchanged. | Add a declassification policy and include return payloads in `public_outcome`, or require encrypted returns, or reject confidential return values not proven public/declassified. |
| P0 | Secret-dependent abort/termination is public. | `termination_status` is exact in public outcome. Benchmarks include `require(oldBalance >= amount)` / `abort_if` over confidential balances and secret amounts. This is either a deliberate declassification or a leak. | Add a theorem/admission rule for secret-independent termination, or classify abort as explicit declassification and model it. |
| P0 | Lean value semantics do not match runtime/Solidity arithmetic or real Keccak. | Lean models `uint` as `Nat`, unsigned negation as no-op, division by zero as `none`, and Keccak as all-zero bytes; generated Rust uses `u128` wrapping arithmetic, div/mod-by-zero return 0, and real `tiny_keccak`. | Formalize the actual value domain (`u128` or `uint256`) and Keccak abstraction/refinement, or narrow the theorem to trace-only and stop claiming value/functional correctness across that boundary. |
| P1 | Front-end trust is broader than “trust parser/syn.” | `Sol.lean` explicitly leaves state-name resolution, capacity literal lookup, `abi.encodePacked` unwrapping, helper inlining, and `AssignAdd` desugaring outside the Lean model. | Emit a proof-relevant post-resolution AST/witness, mechanize the preprocessing relation, and fail closed on unresolved/implicit metadata. |
| P1 | Entrypoint metadata omission is fail-open. | `uo-solc` treats functions without metadata as public entrypoints. A missing sidecar stanza can silently remove confidentiality. | Require explicit metadata for every externally callable function: `confidential`, `public`, `declassifies`, and `secret_args`. |
| P1 | Legacy axiom modules are still imported by the umbrella module. | `UOToolchain.lean` imports `OramGame` and `SgxMicroGame`, each containing a legacy axiom. Static checks say proof-grade checkers avoid them, but the umbrella environment contains them. | Split a strict proof-grade root with no legacy imports; add `#print axioms`/environment-axiom CI for named paper theorems. |
| P1 | Source-backed runtime interface is syntactic, not semantic. | `RuntimeImplementationInterface.lean` proves substring/order/lack-of-substring predicates over Rust source strings. This is useful drift detection, but it is not a semantics-of-Rust refinement. | Keep it as drift detection, but label it that way; gradually replace hot paths with Lean-generated code, verified Rust MIR/Creusot/Kani/Prusti proofs, or executable differential witnesses. |
| P1 | Public/declassification policy is not first-class. | Public getters can return confidential state; confidential entrypoints can return secret-dependent values; public outcome omits values. | Add a policy language and prove every host-visible value/status/error is either public-determined or declared declassified. |
| P2 | The current theorem framing appears per-call rather than history/adaptive. | Update-obliviousness is naturally a property of transaction/update histories. Single-call trace equivalence is insufficient for adaptive hosts observing a sequence of updates and returns. | Define an interactive/history semantics and prove sequential/adaptive composition with accumulated leakage. |
| P2 | Practical interface is prototype-only. | `uo-evm` CLI accepts artifact, entrypoint, seed, and format, but no calldata/arguments; artifacts are interpreted by a custom runtime, not deployable EVM bytecode. | Add ABI/calldata JSON input, a Foundry/Hardhat-compatible harness, and a TEE/runtime demo with explicit remote-attestation and encrypted-return paths. |

## Evidence highlights

- Claim boundary and TCB are explicit in `README.md:28-101`; the frozen observer is `View_SGX = (public_outcome, boundary_schedule, storage_trace, micro_trace)`.
- Output shape only: Rust `OutputShape` and `PublicOutcomeTrace` at `crates/uo-core/src/trace.rs:131-153`; Lean TEE/SGX public outcome at `proof/lean/UOToolchain/TeeDeployment.lean:5-18` and `proof/lean/UOToolchain/SgxRelation.lean:25-31`; runtime return payload at `runtime/uo-evm/src/engine.rs:22-27` and `runtime/uo-evm/src/engine.rs:100-114`.
- Termination status exact: `runtime/uo-evm/src/controller.rs:293-299`; aborted return clearing at `runtime/uo-kernel-runtime/src/lib.rs:410-418`; secret-dependent `require` examples in `benches/raw/ConfidentialMixer.sol:13-18` and metadata at `benches/raw/ConfidentialMixer.oram.yaml:7-10`.
- Value semantics mismatch: Lean `Nat` note at `proof/lean/UOToolchain/IRSyntax.lean:45-47`; Lean arithmetic at `proof/lean/UOToolchain/IRSemantics.lean:337-368`; generated Rust wrapping arithmetic at `crates/uo-core/src/generated_confidential_kernel.rs:362-408`; Keccak mock at `proof/lean/UOToolchain/IRSyntax.lean:203-262`; real Keccak in `runtime/uo-kernel-runtime/src/generated_machine.rs:100-101`.
- Front-end trust: `proof/lean/UOToolchain/Sol.lean:30-46`.
- Metadata fail-open: `compiler/uo-solc/src/lib.rs:280-294`.
- Legacy axioms: `proof/lean/UOToolchain/OramGame.lean:7`, `proof/lean/UOToolchain/SgxMicroGame.lean:7`, root imports in `proof/lean/UOToolchain.lean:11,22`.
- Practical limits: subset in `docs/supported-subset.md:3-50`; no CLI args in `runtime/uo-evm/src/main.rs:31-40` and `runtime/uo-evm/src/engine.rs:119-130`.
