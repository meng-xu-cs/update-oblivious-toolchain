# Unintended or reducible trust boundaries and assumptions

This section excludes the issues already called out by the project as known: deeper Rust semantics below the checked boundary, parser/preprocessing trust, and citing/importing the ORAM theorem rather than machine-checking it in-repo. I still mention those boundaries when they hide a more specific reducible sub-boundary.

## 1. Host-visible return payload is outside the proof observer

**Observed boundary.** The frozen observer includes `public_outcome`, but the modeled public outcome carries output *shape* only. Rust and Lean have `OutputShape` with `return_present` and `return_length`, and no payload field. The runtime API, however, returns `Option<Value>`.

**Evidence.** `crates/uo-core/src/trace.rs:131-153`, `proof/lean/UOToolchain/TeeDeployment.lean:5-18`, `proof/lean/UOToolchain/SgxRelation.lean:25-31`, and `runtime/uo-evm/src/engine.rs:22-27,100-114`.

**Why this is unintended.** The claim says “real host-visible execution,” not “host-visible trace excluding return payload.” A confidential entrypoint such as `SingleAccessMap.read(bytes32)` has a secret key and returns a map value (`benches/raw/SingleAccessMap.sol:19-20`, `benches/raw/SingleAccessMap.pathoram.yaml:12-14`). Two executions can have equal trace shape but different returned values. The theorem can therefore hold while a host/user sees the secret.

**Risk.** Critical. This is the clearest “prove the wrong thing” risk.

**Path to eliminate/reduce.**

1. Add an explicit declassification policy to the sidecar/artifact: `return: public`, `return: encrypted_to_client`, `return: declassified`, or `return: forbidden`.
2. Add return payload to `public_outcome` for public/declassified returns, and prove equality/distribution there.
3. For encrypted returns, model only ciphertext length and require a concrete IND-CPA/nonce/freshness theorem for the return channel.
4. Reject confidential entrypoints returning plaintext secret-dependent values unless a proof-relevant declassification certificate is present.
5. Add a negative test: compile `SingleAccessMap.read`, run two states with same public projection and different hidden values, and assert the observer/policy catches the payload difference.

## 2. Termination/abort status is exact and can be secret-dependent

**Observed boundary.** `termination_status` is public and exact. The runtime maps `!aborted` into public outcome. Confidential `require` lowers to `abort_if`; aborted calls clear the return value, and commit behavior also depends on abort.

**Evidence.** `crates/uo-core/src/trace.rs:146-153`; `runtime/uo-evm/src/controller.rs:293-299`; `runtime/uo-kernel-runtime/src/lib.rs:410-418`; `proof/lean/UOToolchain/Sol.lean:261-271`; `compiler/uo-solc/src/lib.rs:1762-1765`. Benchmarks include secret-dependent conditions: `benches/raw/ConfidentialMixer.sol:13-18`, `benches/raw/ERC20Lite.oram.yaml:9-16`, and transformed `abort_if` in `benches/uo/ERC20Lite.oram.json`.

**Why this is unintended.** Many confidentiality claims allow public termination only if termination is public-determined or explicitly declassified. Here, balances, keys, and amounts are marked secret, but `oldBalance >= amount` controls host-visible success/failure.

**Risk.** Critical for real smart-contract use, where success/failure is always visible.

**Path to eliminate/reduce.** Add one of these theorem/policy routes:

- **Strict noninterference:** prove every confidential entrypoint’s termination status is determined by public inputs and public state only; reject secret-dependent `require`.
- **Explicit declassification:** allow abort status only if policy declares it, e.g. `declassifies: [success]`, and theorem states leakage includes that bit.
- **Private failure semantics:** make secret-dependent failures produce a fixed public status and encrypted/private error result, with state-update policy proven not to leak through commit/rollback.

## 3. Value semantics mismatch: `Nat`/mock Keccak versus runtime `u128`/real Keccak

**Observed boundary.** Lean `Value.uint` is a `Nat`, unsigned negation is currently a no-op, add/sub/mul are mathematical operations, and div/mod by zero fail. Generated Rust uses `u128` wrapping arithmetic and returns 0 for div/mod by zero. Lean Keccak is an all-zero deterministic mock, while the runtime uses `tiny_keccak::Keccak::v256()`.

**Evidence.** `proof/lean/UOToolchain/IRSyntax.lean:45-47,203-262`; `proof/lean/UOToolchain/IRSemantics.lean:337-368`; `crates/uo-core/src/generated_confidential_kernel.rs:362-408`; `runtime/uo-kernel-runtime/src/generated_machine.rs:100-101`; `runtime/uo-evm/src/shell.rs:412`.

**Why this is unintended.** The supported subset advertises `uint256` syntax executed in `u128` (`docs/supported-subset.md:43-46`), but the Lean semantics do not even match the `u128` runtime in overflow, underflow, unary negation, or div-by-zero. Keccak is supported on fixed-size arguments (`docs/supported-subset.md:15`), but the Lean mock collapses all hashes. If compiler-correctness or functional-correctness theorems are read literally, they are about a different language.

**Risk.** Critical for theorem framing and functional correctness. It may not break trace-shape proofs if hashes are abstracted away carefully, but it invalidates broad source/runtime semantic claims.

**Path to eliminate/reduce.**

- Replace `Nat` with a modeled `UInt128` or `UInt256` type and prove runtime operations implement it.
- Make div/mod-by-zero behavior consistent with Solidity or explicitly rejected at admission.
- Treat Keccak as an uninterpreted deterministic function with explicit equality/collision assumptions, or import/specify Keccak sufficiently to prove runtime agreement on canonical bytes. At minimum, do not claim value-level agreement through the mock.
- Add differential tests for overflow, underflow, unary negation, div-by-zero, and Keccak-derived map keys.

## 4. Front-end trust is broader than parser/preprocessing

**Observed boundary.** `Sol.lean` explicitly says state-name resolution, capacity literal lookup, `abi.encodePacked` unwrapping, helper-function inlining, and `AssignAdd` desugaring are outside the Lean model.

**Evidence.** `proof/lean/UOToolchain/Sol.lean:30-46`.

**Why this is unintended.** This is not just parser trust. These steps are semantic and security-relevant: they determine which state object is confidential, which capacity/backend applies, which keys are hashed, and which helper expressions are executed.

**Risk.** High. A bug in these stages can produce a proof-relevant post-resolution AST that no longer matches the Solidity source’s intended meaning.

**Path to eliminate/reduce.** Emit a proof-relevant front-end witness with both raw parsed AST and post-resolution AST, then mechanize a Lean relation for name resolution, helper inlining, `abi.encodePacked` lowering, and assignment desugaring. Alternatively, shift the accepted language from Solidity source to an explicitly documented UO source IR and avoid claiming full Solidity-source soundness until this relation is proven.

## 5. Manual sidecar policy and fail-open function classification

**Observed boundary.** Functions with missing metadata are treated as public entrypoints.

**Evidence.** `compiler/uo-solc/src/lib.rs:280-294`.

**Why this is unintended.** For a security toolchain, missing policy should fail closed. A typo or missing sidecar entry can silently make an entrypoint public and strip secret-argument handling.

**Risk.** High and practical.

**Path to eliminate/reduce.** Require explicit metadata for every external/public function. Add `public: true` / `confidential: true` / `declassifies` tags and reject omissions. Add a CI mutation that deletes one entrypoint stanza from each sidecar and expects compiler rejection.

## 6. Legacy axiom import surface remains available through the umbrella module

**Observed boundary.** The proof-grade static checks say checkers avoid legacy theorem symbols, but the root `UOToolchain.lean` imports modules containing the legacy ORAM and SGX micro axioms.

**Evidence.** `proof/lean/UOToolchain/OramGame.lean:7`; `proof/lean/UOToolchain/SgxMicroGame.lean:7`; `proof/lean/UOToolchain.lean:11,22`; `results/static_checks.json` says proof-grade checkers avoid the legacy symbols.

**Why this is unintended.** This can be managed, but a root environment that imports legacy axioms makes accidental dependence easier and makes reviewer trust rely on textual/static checks rather than theorem-level axiom reports.

**Risk.** High for proof audit clarity; probably not an active proof bug if the static checks are accurate.

**Path to eliminate/reduce.** Split `UOToolchain.ProofGradeRoot` from `UOToolchain.LegacyRoot`. Do not import legacy axiom modules in the proof-grade library or default target. Add a Lean executable that runs `#print axioms`/environment dependency checks for the named final theorems and fails unless the only remaining assumptions are explicitly whitelisted.

## 7. Source-backed runtime interface is a syntactic drift check

**Observed boundary.** `RuntimeImplementationInterface.lean` defines predicates such as `sourceContainsAll`, `sourceLacksAll`, and ordered line containment over Rust source strings.

**Evidence.** `proof/lean/UOToolchain/RuntimeImplementationInterface.lean:30-85`; source-field structure at `proof/lean/UOToolchain/RuntimeImplementationInterface.lean:144-180`; validation summary in `results/runtime_implementation_interface_validation.json`.

**Why this is unintended/reducible.** This is valuable as tamper/drift detection, but it is not semantic verification of the Rust code. It can miss equivalent-looking harmful changes and can accept source that contains required needles in dead code/comments unless the production-source stripping is exhaustive.

**Risk.** High if represented as implementation refinement; medium if clearly labeled as source-drift evidence.

**Path to eliminate/reduce.** Keep substring checks as a guardrail, but add stronger measures: generated code hashes tied to Lean generators; semantic unit tests generated from Lean; MIR-level/Kani/Prusti/Creusot proofs for hot paths; and independent execution witnesses where Lean recomputes as much as possible from minimal runtime events.

## 8. Runtime witness/certificate extraction remains a trusted producer

**Observed boundary.** The real runtime emits the proof objects that Lean accepts. The source-backed boundary pins the code that emits them, and tamper tests are extensive, but extraction and serialization remain a trusted implementation surface.

**Evidence.** TCB wording in `README.md:91-101`; runtime interface validation lists many source files and schemas in `results/runtime_implementation_interface_validation.json`; runtime returns traces/proof bundles through `runtime/uo-evm/src/main.rs:51-151`.

**Why this is unintended/reducible.** A proof object accepted by Lean only proves the object satisfies the predicate. It does not by itself prove the object faithfully describes the actual execution unless the extraction relation is independently verified.

**Risk.** Medium to high.

**Path to eliminate/reduce.** Minimize witness authority: make the runtime emit primitive events only; make Lean or a small checker reconstruct all derived proof bundles; hash-bind emitted events to a transcript; add cross-checks that run the same artifact through a second interpreter and compare minimal traces.

## 9. Rust `unsafe` appears in theorem-adjacent production code

**Observed boundary.** Several production modules use `unsafe` to construct boxed arrays or reinterpret initialized buffers.

**Evidence.** `crates/uo-core/src/types.rs:70,101,108`; `runtime/uo-kernel-runtime/src/lib.rs:50-61`; `crates/uo-core/src/confidential_kernel.rs:559-570`; `crates/uo-core/src/trace.rs:611-648,687,6620-6634`.

**Why this is unintended/reducible.** The project already excludes full Rust semantics, but memory-safety failures inside value/trace/kernel builders can invalidate the trace and witness story. Many of these can likely be replaced with safe `Vec`/`Box<[T]>` construction or isolated in a small audited module.

**Risk.** Medium.

**Path to eliminate/reduce.** Remove `unsafe` where possible; otherwise isolate it in one `unsafe_array_builder` module with invariants, Miri tests, fuzz tests, and a small formal/spec proof. Add CI `cargo miri test` for these builders.

## 10. Randomness, crypto, nonce, and fresh-coin implementation assumptions

**Observed boundary.** The formal assumptions include bucket/metadata IND-CPA and stash bounds. The runtime uses RNG seeds/fresh coins and concrete crypto crates, but a complete theorem connecting uniform/fresh runtime coins, nonce uniqueness, and encryption API discipline to the Lean assumptions is not visible.

**Evidence.** Explicit assumptions in `README.md:78-89`; `runtime/uo-evm/src/engine.rs:36-40`; fresh-coin validation files in `results/fresh_coin_validation.json`; crypto dependency pins in `Cargo.toml:23,28-29,37`.

**Why this is unintended/reducible.** “Crypto theorem assumption” is acceptable, but the implementation still must satisfy the theorem’s preconditions: fresh nonces/seeds, no reuse across writes, correct associated data, and no accidental plaintext metadata.

**Risk.** Medium.

**Path to eliminate/reduce.** Add a crypto/nonce audit theorem or executable checker: every encryption call derives a unique nonce from a modeled counter/seed; every ciphertext includes the expected domain-separated AD; every ORAM remap consumes fresh coins; repeated-seed diagnostics cannot be enabled in production.

## 11. Per-call observer rather than whole-history/adaptive observer

**Observed boundary.** Most artifacts and tests are single-entrypoint or pairwise traces. Update-obliviousness, especially for stateful contracts, needs histories: a host sees a sequence of calls, status bits, return values, and persistent-state effects.

**Evidence.** The frozen observer is per call in `README.md:59-76`; benchmark results such as `results/trace_equivalence.json` compare per-benchmark scenarios; runtime API executes one entrypoint per `run_artifact` call with no calldata history (`runtime/uo-evm/src/engine.rs:119-130`).

**Risk.** Medium to high for deployment claims.

**Path to eliminate/reduce.** Define interactive/history semantics with adaptive public inputs, secret-related states, declassification events, rollback/crash events, and leakage accumulation. Prove sequential composition for exact backends and a hybrid/computational composition for ORAM.

## 12. Reproducibility pinning: Lean toolchain is `stable`

**Observed boundary.** The Lean toolchain file uses `leanprover/lean4:stable`, not a specific version.

**Evidence.** `proof/lean/lean-toolchain` contains `leanprover/lean4:stable`; Cargo dependencies are pinned by exact versions in `Cargo.toml:20-37`.

**Risk.** Medium for reproducibility and proof auditing.

**Path to eliminate/reduce.** Pin an exact Lean release, commit `lake-manifest.json` if external dependencies are added, record `lake --version` in `results/reproducibility_manifest.json`, and make proof artifacts deterministic under the pinned toolchain.
