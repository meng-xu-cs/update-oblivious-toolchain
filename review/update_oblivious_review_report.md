# Review of the update-oblivious toolchain bundle

## Scope and method

I reviewed the repository as a proof/toolchain bundle: the main documentation, the Lean theorem surface, the Rust compiler/runtime bridge, and the committed validation outputs under `results/`. I did not execute the Rust or Lean build in this container because `rustc`, `cargo`, `lean`, and `lake` were not available here; the runtime/build conclusions below are therefore based on static inspection plus the committed result files. The file references use `path:line` from the unpacked archive.

The bundle is clear that it is a research prototype for a restricted Solidity-shaped DSL, not a raw-EVM public-chain target (`README.md:3-7`). Its explicit claim boundary is exact-UO for `UOCell`, `UOArray`, and full-scan `UOMap`, plus a theorem-facing computational route for Path ORAM (`README.md:30-42`, `docs/claim-boundary.md:52-60`). The known trust issues the project already documents—parser/preprocessing, sub-boundary Rust semantics, and citation-backed ORAM theorem import—are real and are not treated here as surprises.

## Executive assessment

The idea and the theorem architecture are meaningful, but the current bundle has several places where the proof boundary can accidentally prove a property of a model that is not the property implemented by the runtime. The most important issues are:

1. **The committed validation evidence is not green.** `kernel_model_alignment_validation.json` has `accepted=false`; `runtime_boundary_validation.json` has `accepted=false`; and `bridge_validation.json` embeds hundreds of false checks. This is a hard evidence gap because `README.md:85-96` presents `results/` as committed reproducibility outputs, while `results/reviewer_summary.md:182-185` says the acceptance gate requires every listed static-drift check to be true.
2. **There is a likely argument-layout mismatch.** Lean constructs initial environments as `publicArgs ++ secretArgs` (`proof/lean/UOToolchain/IRSemantics.lean:1154-1166`), while the runtime passes arguments in declared order and uses secret indices to filter public arguments (`runtime/uo-evm/src/engine.rs:233-251`, `crates/uo-core/src/trace.rs:241-260`, `runtime/uo-kernel-runtime/src/generated_slot_support.rs:85-111`). Unless the language secretly requires all public parameters before all secret parameters, the theorem can bind variables differently from the runtime.
3. **Large-map ORAM is over-framed in docs.** The README says the theorem-facing computational route is only `path_oram_local_posmap_v1` (`README.md:34-35`), but `docs/claim-boundary.md:56-58` and `docs/supported-subset.md:68-71` also describe `path_oram_private_posmap_v1` as theorem-facing for scalable maps. I found local-posmap paper-main theorems (`proof/lean/UOToolchain/PaperMainTheorem.lean:313-385`) and compact private-posmap certificate-size facts (`proof/lean/UOToolchain/ScalablePathOramEvidence.lean:25-52`), but not an end-to-end private-posmap noninterference theorem.
4. **Runtime edge semantics are not fully aligned with Lean/source semantics.** Lean returns errors for missing map keys and out-of-bounds arrays (`proof/lean/UOToolchain/IRSemantics.lean:850-884`, `proof/lean/UOToolchain/IRSemantics.lean:1010-1084`), while the UO runtime returns zero/no-op for missing map keys and UO array out-of-bounds (`runtime/uo-evm/src/objects.rs:914-987`, `runtime/uo-evm/src/generated_object_helpers.rs:748-774`). Map capacity overflow can set `aborted` in the runtime (`crates/uo-core/src/generated_confidential_kernel.rs:322-335`, `runtime/uo-evm/src/generated_object_helpers.rs:792-824`), but the Lean map model inserts unboundedly (`proof/lean/UOToolchain/IRSemantics.lean:925-934`).
5. **The practical supported subset is narrower than the prose subset.** Docs say `bytes32`, `address`, fixed-size arrays, and structs are accepted (`docs/supported-subset.md:8-27`), but Lean binary equality supports only uint/bool (`proof/lean/UOToolchain/IRSemantics.lean:473-497`) while runtime equality is structural for all `Value`s (`crates/uo-core/src/generated_confidential_kernel.rs:378-439` and `runtime/uo-evm/src/shell.rs:450-476`). Lean treats `structField` and local `arrayIndex` as unsupported (`proof/lean/UOToolchain/IRSemantics.lean:885-891`), and confidential kernel lowering rejects them (`crates/uo-core/src/confidential_kernel.rs:2037-2042`, `crates/uo-core/src/confidential_kernel.rs:2115-2119`).

The rest of this report gives a task-by-task inventory and concrete reduction paths.

---

# Task 1 — Unintended trust boundaries and assumptions

## T1.1 Committed evidence is not an accepted proof-grade bundle

**Finding.** Several committed result files fail their own acceptance conditions.

Evidence from the committed JSON outputs:

- `results/kernel_model_alignment_validation.json`: top-level `accepted=false`; false fields include `confidential_kernel_consumes_generated_interpreter`, runtime-normal-form flags, and `runtime_crypto_primitive_identity_pinned`.
- `results/runtime_boundary_validation.json`: top-level `accepted=false`; false fields include `engine_constructs_theorem_certificates_directly`, `engine_imports_raw_runtime_kernel`, `engine_owns_raw_runtime_object_map`, `engine_peeks_into_fresh_coin_map`, and `translation_validation_rejects_confidential_raw_kernel_targets`.
- `results/bridge_validation.json`: 602 false scalar checks in my traversal, including the two failed reports above plus Path-ORAM family checks such as `canonical_leaf_seed_space_matches=false`, `canonical_leaf_values_match_runtime_seed=false`, `physical_read_shape_uniform=false`, and `physical_write_shape_uniform=false` in representative scenarios.
- `results/static_checks.json`: top-level summary booleans are mostly true, but the detailed traversal contains many false `uses_legacy_umbrella` entries.

This conflicts with the project’s presentation of `results/` as committed reproducibility outputs (`README.md:85-96`) and with the reviewer summary statement that the acceptance gate requires every named static-drift check to be true (`results/reviewer_summary.md:182-185`).

**Why it matters.** A reader can mistakenly treat the committed bundle as proof-grade accepted evidence. That turns the validation probe into an implicit trust boundary: “trust that the failed checks are stale or unimportant.”

**Path to reduce/eliminate.** Make the evidence fail closed. The shipped artifact should contain a single top-level proof-grade acceptance bit that is true only if all required reports are true; CI should reject bundles with any false proof-grade check. If some checks are intentionally advisory, move them into a separately named non-gating report. The acceptance theorem statement should refer to a precise green report schema, not to a directory of mixed results.

## T1.2 Static-drift probes are a stronger trust boundary than the prose admits

**Finding.** The docs acknowledge source-frozen/static-drift evidence rather than Rust refinement (`README.md:41-42`, `docs/claim-boundary.md:112-115`). However, the current probes also appear stale or brittle. For example, `docs/claim-boundary.md:115` says `fixed_buffer` is safe and has no production `unsafe`, which matches `crates/uo-core/src/fixed_buffer.rs:1-43`. Yet `results/reviewer_summary.md:196` and `probe/mplus-probe/src/lib.rs:3015` still describe a check whose target is “the only production Rust unsafe … lives in fixed_buffer.rs.” A production-source search found no `unsafe`/`MaybeUninit` in `crates`, `runtime`, `compiler`, or `checker`; the remaining mentions are in probe/tamper strings and Lean drift fixtures.

**Why it matters.** If static probes check substrings or stale narratives, they can be both too weak and too noisy. They become an implicit trust boundary for module privacy, helper routing, trace construction, fresh-coin opacity, and proof-object extraction.

**Path to reduce/eliminate.** Replace source-text claims with typed interface obligations where possible. Useful next steps are: generate Rust/Lean boundary schemas from a single source of truth; make helper/private-surface checks rely on Rust visibility, module paths, and exported symbol sets rather than prose strings; and add small MIR/Kani/Creusot-style checks for the tiny confidential kernel and buffer/value codecs. Keep static-drift checks as regression tests, but do not let them be the only bridge for confidentiality-critical control/data-flow claims.

## T1.3 The `path_oram_private_posmap_v1` route is admitted in validators but not supported by an end-to-end theorem

**Finding.** The documentation says larger theorem-facing maps use `path_oram_private_posmap_v1` with compact symbolic evidence (`docs/supported-subset.md:68-71`, `docs/path-oram.md:55-64`), while the README narrows the theorem-facing computational path to `path_oram_local_posmap_v1` only (`README.md:34-35`). The Lean validator accepts private-posmap shapes (`proof/lean/UOToolchain/TranslationValidationJson.lean:876-893`, `proof/lean/UOToolchain/TranslationValidationJson.lean:1901`), and `ScalablePathOramEvidence.lean` proves certificate-size facts (`proof/lean/UOToolchain/ScalablePathOramEvidence.lean:25-52`). But the paper-main theorem I found is for `pathOramLocalPosmapV1SecurityInterface` only (`proof/lean/UOToolchain/PaperMainTheorem.lean:313-385`).

**Why it matters.** This is not just the known “ORAM theorem is cited, not imported” issue. It is an interface/claim mismatch: the compiler and docs let users select a scalable scheme, but the stated noninterference theorem seems to conclude only for the local-posmap scheme.

**Path to reduce/eliminate.** Either narrow all docs, validators, examples, and “proof-grade” language to local-posmap capacity ≤128, or add a `pathOramPrivatePosmapV1SecurityInterface`, prove/assume its local theorem at the same interface strength as the local-posmap route, and add a `paperMain_pathOramPrivatePosmapV1_noninterference` theorem. The compact symbolic certificate should prove a property that implies `ComputationalUOWith`, not only subenumerative certificate size.

## T1.4 Argument layout assumes a hidden parameter discipline

**Finding.** Lean’s IR and Sol initial environments build `allArgs := cfg.publicArgs ++ cfg.secretArgs` and zip that list with function parameters (`proof/lean/UOToolchain/IRSemantics.lean:1154-1166`, `proof/lean/UOToolchain/Sol.lean` has the same pattern). Runtime execution passes source arguments in declared order, appends public environment arguments, and then uses manifest `secret_args` indices to compute public call summaries (`runtime/uo-evm/src/engine.rs:233-251`, `crates/uo-core/src/trace.rs:241-260`). Confidential call inputs are stored slot-by-slot in raw argument order (`runtime/uo-kernel-runtime/src/generated_slot_support.rs:85-111`), and slot programs use the original parameter count/order (`crates/uo-core/src/confidential_kernel.rs:745-830`). The compiler validates that named secret args exist and are unique (`compiler/uo-solc/src/lib.rs:2987-3066`), but I did not find a requirement that all public args precede all secret args.

**Why it matters.** For a function such as `f(secret s, uint p)` or `f(uint a, secret b, uint c)`, Lean may bind variables differently from the runtime. That is a classic “prove the wrong program” problem.

**Path to reduce/eliminate.** Prefer the semantic fix: model arguments as a single declared-order list plus a public/secret index set, and define public projection by filtering that list. If a quick restriction is desired, enforce a suffix/prefix discipline in the compiler, the Lean translation checker, and the docs, and add a theorem that declared-order zipping equals `publicArgs ++ secretArgs` under that discipline.

## T1.5 Sidecar raw bytes are optional, so metadata parsing/canonicalization is a hidden trust boundary

**Finding.** The claim-boundary prose says the admitted-package hash binds source bytes and canonical sidecar metadata JSON (`docs/claim-boundary.md:25-31`). The Rust identity can bind raw metadata bytes, but `raw_metadata_sha256` is optional (`crates/uo-core/src/artifact.rs:42-54`, `crates/uo-core/src/artifact.rs:56-120`). The compiler’s default `compile` path calls `compile_impl(..., None, ...)` (`compiler/uo-solc/src/lib.rs:87-102`), and translation validation accepts admitted-package shapes with or without the raw metadata field (`crates/uo-core/src/translation_validation.rs:598-613`).

**Why it matters.** If only canonical parsed metadata is bound, then YAML/serde parsing details, duplicate keys, aliases, comments, and implicit type conversions are part of the trusted front-end. This is similar to the known parser/preprocessing trust, but it is narrower and more actionable: the sidecar is a security policy language.

**Path to reduce/eliminate.** Require raw sidecar hashing in all production/proof-grade paths, and make the Lean checker reject admitted packages without `raw_metadata_sha256` unless explicitly in a non-production mode. Also add sidecar parsing constraints for duplicate keys, aliases, and schema defaults; or generate a raw-sidecar-to-canonical-metadata witness.

## T1.6 Map and array edge semantics differ across Lean, source, and runtime

**Finding.** Lean’s map lookup returns `evalError` on a missing key (`proof/lean/UOToolchain/IRSemantics.lean:869-884`; same in `proof/lean/UOToolchain/Sol.lean:197-210`). Runtime maps return the zero value for a missing key: raw maps use `cold_zero_value`, UO small maps select from zero, and ORAM get returns zero for missing keys (`runtime/uo-evm/src/objects.rs:914-987`, `runtime/uo-evm/src/oram.rs:1184-1208`). Lean array get/set errors on out-of-bounds (`proof/lean/UOToolchain/IRSemantics.lean:850-868`, `proof/lean/UOToolchain/IRSemantics.lean:1010-1043`), while UO array get returns zero and UO array set is a no-op when out of bounds (`runtime/uo-evm/src/generated_object_helpers.rs:748-774`, `runtime/uo-evm/src/objects.rs:842-908`).

**Why it matters.** This is both a semantic mismatch and a potential public-status leak mismatch. It affects practical patterns such as sparse maps, optional entries, and secret indices.

**Path to reduce/eliminate.** Choose one edge semantics for proof-grade UO objects and make every layer share it. For Solidity-shaped maps, default-zero is the practical choice. Add Lean value-zero-by-type, map default-zero lookup, bounded-capacity maps, UO array out-of-range zero/no-op semantics, and preservation theorems showing compiler/runtime agree. If you want error semantics instead, make runtime UO paths abort uniformly and policy-check that status is declassified when secret-dependent.

## T1.7 Map capacity overflow can affect public termination but is not fully modeled

**Finding.** UO map insertion detects capacity overflow when inserting a nonzero value into a full map (`runtime/uo-evm/src/generated_object_helpers.rs:792-824`, `runtime/uo-evm/src/generated_oram_codecs.rs:1620-1653`). Confidential kernel execution records that overflow as `aborted` (`crates/uo-core/src/generated_confidential_kernel.rs:322-335`), and public outcomes expose `termination_status` (`runtime/uo-evm/src/controller.rs:296-304`, `crates/uo-core/src/trace.rs:166-183`). Lean’s `Value.mapInsert` is unbounded (`proof/lean/UOToolchain/IRSemantics.lean:925-934`), and compiler taint analysis treats `MapPut` as a sensitive public write only when the target object is public; it does not set `status_sensitive` for map capacity overflow (`compiler/uo-solc/src/lib.rs:2451-2485`).

**Why it matters.** A full-map overflow can depend on secret key/value/state and become observable through success/failure. That is exactly the kind of update-dependent signal update-obliviousness should police.

**Path to reduce/eliminate.** Model map capacity in Lean and make overflow a first-class outcome. Then prove either: capacity overflow is impossible under admitted programs; or overflow status is public-only; or overflow status is explicitly declassified and included in release functions. The compiler taint checker should conservatively set `status_sensitive` for confidential map insertions unless a precondition/proof discharges non-overflow.

## T1.8 Equality support differs for `bytes32`/`address`/composite values

**Finding.** Docs list `bool`, `uint256`, `bytes32`, and `address`, plus comparisons/boolean connectives, as accepted (`docs/supported-subset.md:8-12`). Lean’s `BinaryOp.eval` supports `eq`/`neq` only for uint and bool (`proof/lean/UOToolchain/IRSemantics.lean:473-497`). Runtime equality uses Rust structural `Value` equality for all values (`crates/uo-core/src/generated_confidential_kernel.rs:378-439`, `runtime/uo-evm/src/shell.rs:450-476`).

**Why it matters.** Address and hash equality are central to authorization, registries, token transfers, and mixers. This mismatch can make Lean reject/under-model programs the runtime executes, or prove a property for an error path rather than the real path.

**Path to reduce/eliminate.** Add Lean equality/inequality for all scalar values that the DSL admits, and specify whether composite equality is admitted or rejected. Add translation-validation checks that reject operators not supported by the Lean semantics.

## T1.9 Structs and local fixed arrays are advertised, but not proof-grade for confidential code

**Finding.** Docs list fixed-size arrays and structs as accepted features (`docs/supported-subset.md:13-14`). The compiler can emit `Expr::ArrayIndex` and `Expr::StructField` for non-state indexing/member access, but Lean treats both as unsupported (`proof/lean/UOToolchain/IRSemantics.lean:885-891`), and confidential kernel lowering rejects them (`crates/uo-core/src/confidential_kernel.rs:2037-2042`, `crates/uo-core/src/confidential_kernel.rs:2115-2119`). The fragment witness also rejects them for confidential entrypoints.

**Why it matters.** This is an unintended restriction beyond the stated Solidity subset. It removes common patterns such as local tuple/struct packaging, fixed arrays of constants, and field access in secret-dependent code.

**Path to reduce/eliminate.** Split the documentation into “parser-accepted” and “proof-grade confidential” subsets, or implement struct/local-array projection in the Lean evaluator and confidential kernel. The compiler should reject any source construct whose semantic path is unsupported by Lean before emitting an artifact.

## T1.10 Public outcome, final-public-state, and release safety are theorem hypotheses rather than fully derived conclusions

**Finding.** The main exact theorem assumes `PublicOutcomeSafe`, `PublicBoundarySafe`, `PublicControllerShapeSafe`, final-public-state safety, and release-function safety (`proof/lean/UOToolchain/PaperMainTheorem.lean:173-195`). The compiler has policy checks for secret-dependent return/status/public-state declassification (`compiler/uo-solc/src/lib.rs:2077-2200`), and Lean imports policy checks (`proof/lean/UOToolchain/TranslationValidationJson.lean:1722-1758`). However, the paper-main theorem itself is still framed as requiring those safety assumptions.

**Why it matters.** There is a gap between “the admitted package declares a declassification policy” and “every public outcome field is safe under that policy.” This can hide leaks in error messages, output shape, encrypted-return metadata, return-channel failures, or status.

**Path to reduce/eliminate.** Add an end-to-end theorem that accepted metadata and accepted runtime proof objects imply `PublicOutcomeSafe`, `PublicBoundarySafe`, `PublicControllerShapeSafe`, and the final/release safety hypotheses. The theorem statement in the paper should then quantify over accepted packages, not arbitrary safe observation functions.

## T1.11 Adaptive-history theorem under-models the hostile host’s full view

**Finding.** The adaptive-history model’s `HostCallObservation` includes public outcome, ordered object schedule, and final public state (`proof/lean/UOToolchain/HistorySemantics.lean:15-24`). The claim-boundary observer includes `public_outcome`, `boundary_schedule`, `storage_trace`, and `micro_trace` (`docs/claim-boundary.md:62-86`), and Lean `View_SGX` also includes final-public rollback and release functions (`proof/lean/UOToolchain/PaperMainTheorem.lean:30-40`). The history theorem assumes a single-call equality modulo releases and equal release histories (`proof/lean/UOToolchain/HistorySemantics.lean:263-269`, `proof/lean/UOToolchain/HistorySemantics.lean:420-465`).

**Why it matters.** A hostile host can adapt future calls based on boundary/storage/micro observations, not just public outcomes and object schedules. If those fields are omitted from the transcript model, the adaptive theorem proves a weaker attacker model than the paper observer.

**Path to reduce/eliminate.** Redefine `HostCallObservation` as the full normalized `View_SGX`, or prove that the omitted components are deterministic functions of the current history observation for all accepted executions. Make release frames generated by manifest-declared release functions, not exogenous equal inputs.

## T1.12 Public environment binding is not yet an EVM/deployment theorem

**Finding.** The DSL admits public environment reads (`msg.sender`, `tx.origin`, block number/timestamp/chain id) as manifest-bound public inputs (`docs/supported-subset.md:20-23`). Runtime calls can default to an internal `PublicEnvironment` when no environment is supplied (`runtime/uo-evm/src/engine.rs:246-251`, `crates/uo-core/src/ir.rs:84-113`). The README also says raw public-chain EVM bytecode is not the main execution model (`README.md:3-7`).

**Why it matters.** If an external host supplies environment values, then correctness of authorization logic depends on a binding between those public inputs and the real call/chain context. This is not an update-obliviousness leak by itself, but it is a hidden trust boundary for any real contract-like deployment.

**Path to reduce/eliminate.** Add a deployment theorem or runtime precondition that binds `PublicEnvironment` to attested call context. For in-process/off-chain deployment, document the host as responsible for truthful public environment injection. For on-chain-like deployment, add a verified shim or TEE attestation transcript field that commits to those public values.

## T1.13 Fresh randomness and nonce provenance need a production/no-diagnostics theorem

**Finding.** Runtime deployment uses `RuntimeFreshnessState::from_os_rng()` (`runtime/uo-evm/src/engine.rs:111-116`), while seeded deployment and diagnostics paths are conditionally enabled (`runtime/uo-evm/src/engine.rs:62-73`, `runtime/uo-evm/src/engine.rs:118-121`). The docs already mention freshness/rollback and return-channel/session assumptions (`docs/runtime/tee-observer.md:79-95`, `docs/runtime/README.md:34-39`).

**Why it matters.** ORAM remapping, encrypted buckets, encrypted metadata, and encrypted client returns all depend on fresh coins/nonces. A diagnostics feature accidentally enabled in production, RNG failure, or nonce reuse would break computational UO or confidentiality.

**Path to reduce/eliminate.** Add a proof/audit obligation that production builds cannot call diagnostics seed injection, and bind runtime binary hash/feature set into deployment acceptance. Also add explicit nonce-domain separation and monotonicity checks to the proof-root evidence.

## T1.14 Proof-object extraction and serialization are a large trusted surface

**Finding.** The TCB table explicitly includes “Rust runtime kernel plus witness/certificate/bundle extraction and serialization” (`docs/claim-boundary.md:108-118`), and `docs/runtime/README.md:26-32` says extraction is bound to transcript hashes but not fully verified. This is acknowledged, but it is more central than a normal implementation detail because the Lean checkers accept JSON/bundle representations rather than re-executing Rust.

**Why it matters.** A buggy extractor can omit, reorder, or mislabel proof-relevant events while still producing a Lean-accepted object, unless every omission/mutation is cryptographically and semantically bound.

**Path to reduce/eliminate.** Continue the transcript-hash approach, but make it end-to-end: append-only primitive transcript → canonical serialization → proof object → Lean importer theorem. Generate schemas from Lean or Rust in one direction only, reject all defaults in proof-grade JSON unless proved safe, and test mutation coverage against all observer fields.

---

# Task 2 — Correctness and completeness of theorem framing

## Theorem inventory

I collected theorem/lemma/axiom declarations with a syntax search over `proof/lean`. The full inventory is in `theorem_inventory.csv` in the bundle. The search found 3,290 declarations in `/mnt/data/theorem_lines.txt` before filtering. The most theorem-heavy modules are:

| Count | Module |
| ---: | --- |
| 812 | `proof/lean/UOToolchain/RuntimeImplementationInterface.lean` |
| 352 | `proof/lean/CheckProofGradeRuntimeImplementationKernelMachineConfinementBoundary.lean` |
| 293 | `proof/lean/CheckProofGradeRuntimeResidualHelperShellBoundary.lean` |
| 222 | `proof/lean/UOToolchain/RuntimeOramHelperSemantics.lean` |
| 131 | `proof/lean/UOToolchain/ProofGrade.lean` |
| 97 | `proof/lean/UOToolchain/RuntimeOramCodecSemantics.lean` |
| 89 | `proof/lean/UOToolchain/RuntimeRefinement.lean` |
| 68 | `proof/lean/UOToolchain/RuntimeKernelDslJson.lean` |
| 56 | `proof/lean/UOToolchain/RuntimeStoreCodecSemantics.lean` |
| 54 | `proof/lean/UOToolchain/RuntimeImplementationInterfaceJson.lean` |
| 44 | `proof/lean/UOToolchain/IRSemantics.lean` |
| 41 | `proof/lean/UOToolchain/RuntimeShellBoundary.lean` |
| 40 | `proof/lean/UOToolchain/SgxObserverFreeze.lean` |
| 37 | `proof/lean/UOToolchain/KernelDsl.lean` |
| 36 | `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean` |
| 34 | `proof/lean/UOToolchain/RuntimeOramWriteLogDiscipline.lean` |
| 33 | `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean` |

A search for `sorry`/`admit` did not reveal open proof holes. I found two explicit legacy axioms, `legacyOramLocalTheorem` and `legacySgxMicroLocalTheorem`, in legacy modules; the static checks report says legacy symbols are absent from proof-grade theorem checks. That isolation appears intentional, but the detailed false `uses_legacy_umbrella` entries in `results/static_checks.json` should be reconciled.

The theorem surface can be grouped into these families:

1. **Core source/IR/kernel semantics.** `IRSyntax`, `IRSemantics`, `Sol`, `KernelDsl`, and preservation/exactness modules define the admitted language and lowering semantics.
2. **Exact backend UO.** `ExactObjects`, `TraceModel`, `Composition`, and `PaperMainTheorem.paperMain_exact_backend_noninterference` express exact equality of traces/views under equal public projections.
3. **Translation validation and policy checks.** `TranslationValidationJson`, `CompilerExactness`, and `ProofGrade` check imported source/artifact views, manifest fields, loop admission, ORAM shape, and public-access/declassification policies.
4. **Confidential kernel/runtime boundary.** `ConfidentialFragment`, `RuntimeKernelDslJson`, `RuntimeRefinement`, `RuntimeShellBoundary`, `RuntimeTrustedKernel`, and many `RuntimeImplementationInterface*` modules pin the runtime-facing checker surface.
5. **Path ORAM route.** `OramModel`, `PathOramSecurity`, `PathOramLocalPosmapV1`, `PathOramJACMTheorem`, `StandardOramReduction`, and `PaperPathOramTheoremRoute` define the computational route, currently strongest for local posmap.
6. **SGX/TEE observer and deployment.** `SgxObserverFreeze`, `SgxController`, `SgxOramProjection`, `TeeDeployment`, and runtime-audit modules define normalized micro/boundary/storage observer components and deployment assumptions.
7. **Adaptive histories.** `HistorySemantics` and the adaptive paper-main theorem lift single-call equality to public strategies, subject to release-history assumptions.
8. **Executable JSON/checker importers.** The `CheckProofGrade*` modules validate imported bundles and expose check-theorem correspondences.

## Correctness of framing

The high-level theorem shape is conceptually right: compare two executions with the same admitted package, public inputs, public environment, and public initial state, and require indistinguishability/equality of the hostile-host observer modulo declared releases. For exact backends, the theorem concludes equality of `View_SGX` (`proof/lean/UOToolchain/PaperMainTheorem.lean:173-267`). For local-posmap ORAM, it concludes exact equality for public/boundary components and an ORAM security relation for storage/micro components (`proof/lean/UOToolchain/PaperMainTheorem.lean:278-385`).

The main framing weakness is that too many security-relevant components are still hypotheses: public outcome safety, boundary safety, controller-shape safety, final-public rollback safety, and release-function safety (`proof/lean/UOToolchain/PaperMainTheorem.lean:173-195`). Those are the right lemmas to need internally, but the public theorem should derive them from “accepted package + accepted proof objects + accepted deployment evidence.” Otherwise the theorem can be true for any observation function that is already assumed safe.

## Missing or weak theorem obligations

### O2.1 Accepted-package end-to-end theorem

Current claim-boundary prose states an end-to-end conditional over `(P,M,V)`, compiler output, admitted-package hash, Lean checker acceptance, runtime proof objects, and explicit assumptions (`docs/claim-boundary.md:7-18`). The Lean theorem surface is closer to a set of components plus assumptions. The missing capstone theorem should have a conclusion shaped like:

```text
If RawSourceSidecarPackage P M V is admitted,
compiled artifact A has matching admitted-package identity,
Lean translation checker accepts P/M/A,
runtime execution of A emits accepted proof objects,
deployment assumptions and backend assumptions hold,
then View_SGX distributions are equal/indistinguishable for same public inputs and policy-declared releases.
```

This theorem should not expose `PublicOutcomeSafe`/`PublicBoundarySafe` as external hypotheses; it should prove them from the artifact/checker evidence.

### O2.2 Full-view adaptive theorem

The adaptive theorem should range over the same normalized observer as the single-call theorem. Currently the history observation omits boundary/storage/micro fields (`proof/lean/UOToolchain/HistorySemantics.lean:15-24`), while the claimed observer includes them (`docs/claim-boundary.md:62-86`). Strengthen `HostTranscript` to carry `View_SGX`, or prove that all omitted fields are deterministic/public functions of the existing transcript under admitted executions.

### O2.3 Private-posmap computational theorem

Add the private-posmap theorem or stop admitting it as theorem-facing. Certificate-size/subenumeration facts (`proof/lean/UOToolchain/ScalablePathOramEvidence.lean:25-52`) are not the same as noninterference or ORAM security.

### O2.4 Argument-order theorem

Add either a theorem that declared-order runtime arguments equal Lean `publicArgs ++ secretArgs` under a checked ordering discipline, or change the model to use declared-order arguments and secret index sets. This obligation should be part of translation validation.

### O2.5 Runtime edge-semantics theorem for maps/arrays

Add source/IR/kernel/runtime agreement theorems for:

- default-zero map lookup;
- bounded map capacity and capacity overflow;
- UO array out-of-range zero/no-op semantics;
- `Uint256` to `usize` conversion/saturation behavior for indices; and
- public termination/status effects of runtime errors/overflow.

### O2.6 Scalar equality theorem

Prove that Lean equality and runtime equality agree for all admitted scalar types, especially `address` and `bytes32`. If composite equality is unsupported, make the parser/compiler/checker reject it before proof-grade admission.

### O2.7 Declassification policy soundness theorem

The compiler and Lean checkers have useful policy checks, but the theorem should explicitly say that every host-visible plaintext field is either public, encrypted-only evidence, or one of the declared release labels. This should cover success/failure status, output shape, return payload, encrypted-return metadata, public-state writes, and proof-checker/runtime error taxonomy.

### O2.8 Raw-source/sidecar package theorem

Known parser trust is documented, but the theorem should separate raw source parsing from sidecar policy parsing. A near-term theorem can bind raw sidecar bytes and canonical metadata; a stronger theorem can verify the raw-to-canonical relation.

### O2.9 Deployment/public-environment theorem

The deployment theorem should bind `msg.sender`, `tx.origin`, block number/timestamp, and chain id to the attested execution context, or explicitly leave them as trusted host-supplied public inputs.

### O2.10 Gas and failure taxonomy theorem

Confidential calls use manifest public gas budgets (`runtime/uo-evm/src/controller.rs:494-507`), and public outcome includes gas (`crates/uo-core/src/trace.rs:166-183`). Add a theorem that host-visible gas/status/error categories are independent of secrets except where declassified. This is especially important for capacity overflow and runtime proof-checker failures.

---

# Task 3 — Practicality and usefulness

## Practicality judgment

The toolchain is plausible for small enclave-hosted, contract-shaped workflows where:

- capacities are public and modest;
- confidential work is done through UO cells, UO arrays, full-scan maps, or local-posmap ORAM;
- public outcomes are tightly controlled by sidecar policies; and
- the deployment target is an instrumented runtime/TEE rather than raw EVM bytecode.

It is not yet practical as a general privacy-preserving Solidity toolchain. The intended Solidity subset restriction is acceptable for a research prototype, but several additional restrictions and mismatches make even common restricted-contract use cases hard.

## Practical blockers beyond the intentional Solidity subset

### P3.1 The proof-grade evidence is not currently green

Before practicality can be judged from benchmarks, the committed evidence needs to be accepted. A toolchain that ships with `accepted=false` in core validation reports is not deployable as a proof-grade artifact.

### P3.2 Scalable maps are not theorem-ready

Full-scan maps are exact but O(capacity). Local-posmap ORAM is capped at 128 in the docs and Lean/Rust route (`docs/supported-subset.md:68-71`, `docs/path-oram.md:55-64`). The private-posmap route is admitted and documented for larger maps, but I did not find the end-to-end noninterference theorem. Many real applications need maps over addresses, commitments, allowances, orders, nullifiers, or balances with capacities far above 128.

### P3.3 Artifact/proof sizes look heavy

`results/reviewer_summary.md:80-114` reports materialized artifacts such as an 8.6 MB canonical Path-ORAM pair certificate and a 4.3 MB fresh-coin witness family, plus estimated artifacts as large as `7,079,693,798,601,654,272` bytes for some canonical Path-ORAM pair scenarios. Even if some estimates are intentionally “naive enumeration” warnings, the bundle needs a proof-grade scalable route that avoids materializing or validating huge families.

### P3.4 Useful address/hash-heavy programs need equality to work

Authorization checks, registries, ERC20-like transfers, mixers, and allowlists all rely on `address == address` or `bytes32 == bytes32`. Runtime supports it, but Lean `BinaryOp.eval` currently does not. This is one of the highest-impact practicality fixes.

### P3.5 Sparse-map/default-zero behavior is essential

Real Solidity mappings return zero/default for missing keys. Runtime does that, but Lean currently errors on missing map keys. Any realistic token/registry/nullifier map will rely on default-zero reads.

### P3.6 Capacity overflow must be handled as a first-class application condition

Bounded public capacities are acceptable, but practical systems need a defined behavior when a confidential map fills. If overflow aborts and success/failure is public, then applications either need declassified status or a public precondition that capacity cannot be exceeded. Without this, map-heavy apps can leak through termination.

### P3.7 Structs/local arrays are weaker than advertised

Fixed structs and arrays are a practical way to package state and intermediate values. If they are not proof-grade in confidential code, many otherwise simple examples must be flattened manually. That is not merely a usability issue; it changes what programs can be expressed in the verified fragment.

### P3.8 Dynamic patterns and external calls remain out of scope

The intentional subset excludes dynamic arrays, events, custom errors, revert, external calls, inheritance, and unbounded mappings (`docs/supported-subset.md:29-42`). That is fine for a tractable prototype, but it means the realistic target is more like a verified confidential component runtime than a Solidity application framework. The docs should keep saying this plainly.

### P3.9 TEE side-channel assumptions are strong

The claim explicitly excludes raw page identities, cache behavior, scheduler effects, wall-clock time, etc. (`docs/claim-boundary.md:120-138`). This is acceptable for a first paper if framed as normalized-observer UO, but it limits the security claim for real SGX deployments. Practical deployment needs a clear story about what the host actually observes and what is normalized away by assumption.

## Opportunities to make the toolchain realistically useful

1. **Define a proof-grade “minimum useful apps” target.** I would choose three: an address allowlist/registry, a small mixer/nullifier set, and an ERC20-lite allowance/balance scenario. Make them pass the full green evidence route with address/bytes32 equality, default-zero maps, bounded overflow policy, and either full-scan or proven scalable ORAM.
2. **Auto-generate the supported proof-grade subset.** Generate docs from the compiler rejection predicates and Lean checker acceptance predicates so the prose cannot advertise features the proof path rejects.
3. **Promote private-posmap ORAM or remove it from proof-grade docs.** This is the difference between toy capacities and useful map capacities.
4. **Fix argument modeling early.** The argument-order mismatch is foundational; it affects almost every theorem that uses public/secret arguments.
5. **Treat all status changes as part of declassification.** This includes `require`, capacity overflow, runtime type errors, map/array edge cases, proof-check failures, cryptographic failures, and initialization errors.
6. **Make proof bundles small by construction.** The scalable route should validate symbolic/certificate claims whose size is logarithmic or otherwise public-polynomial in capacities, not enumerate leaf/fresh-coin families.
7. **Add a deployment-context contract.** For real use, public environment values and return-channel/session evidence need to be attested and bound to runtime acceptance, not just supplied as public parameters.

---

# Recommended priority order

1. **Fail-closed evidence:** regenerate/fix committed reports until all proof-grade gates are green, or explicitly mark the bundle as non-accepted.
2. **Argument layout:** either enforce parameter ordering or switch the model to declared-order arguments with secret-index filtering.
3. **Runtime edge semantics:** align Lean and runtime for maps, arrays, overflow, and scalar equality.
4. **Large-map theorem:** resolve the private-posmap claim mismatch.
5. **Public outcome/declassification capstone:** derive `PublicOutcomeSafe` and related assumptions from accepted metadata/proof objects.
6. **Full adaptive observer:** lift adaptive histories to full `View_SGX`.
7. **Sidecar raw binding:** require raw sidecar hash in proof-grade packages.
8. **Practical examples:** prove the three minimum useful apps end-to-end.

## Included companion files

- `theorem_inventory.csv`: line-level theorem/lemma/axiom declaration inventory.
- `validation_false_paths.txt`: full list of false scalar checks found in selected committed validation reports.
- `validation_false_paths.json`: machine-readable version of the same validation traversal.
