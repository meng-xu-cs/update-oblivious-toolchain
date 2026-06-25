# Update-Oblivious Solidity Toolchain Runbook for a Local Coding Agent

This runbook is self-contained. It assumes the local agent has only the repository checkout and no paper draft or review text.

The repository is a research prototype for a restricted Solidity-like update-oblivious DSL, an instrumented runtime, Lean proof/checker routes, and generated evaluation reports. The local agent should not make a claim true by editing prose alone. A claim is acceptable only when the compiler, runtime, proof/checker route, validation probe, and evaluation artifacts all support it.

## Repository map

Start here:

- `README.md`: top-level claim summary and commands.
- `docs/claim-boundary.md`: theorem, observer, assumptions, TCB, and non-claims.
- `docs/supported-subset.md`: accepted DSL and sidecar metadata surface.
- `docs/path-oram.md`: Path ORAM route and proof/evaluation status.
- `docs/coding-agent-conventions.md`: editing and validation conventions.
- `compiler/uo-solc/src/lib.rs`: source parsing, sidecar validation, lowering, confidential linearization.
- `runtime/uo-evm/src/engine.rs`: local and production call entrypoints.
- `runtime/uo-evm/src/deployment.rs`: production evidence checks.
- `runtime/uo-evm/src/state.rs`: committed runtime state and call execution.
- `runtime/uo-evm/src/objects.rs`: raw, full-scan, and ORAM storage object semantics.
- `crates/uo-core/src/artifact.rs`: artifact identity and toolchain manifest hashes.
- `crates/uo-core/src/manifest.rs`: manifest, ORAM policy, and resource bounds.
- `crates/uo-core/src/translation_validation.rs`: proof-relevant source/artifact views.
- `proof/lean/UOToolchain/ProofGradeRoot.lean`: proof-grade Lean root.
- `probe/mplus-probe/src/lib.rs`: validation, leakage, overhead, and summary reports.
- `benches/raw`, `benches/uo`, `benches/harnesses`: benchmark sources, generated artifacts, and harness configs.
- `results/`: generated validation outputs. Do not hand-edit generated result files.

## Baseline gate before editing

Run this from the repository root and save logs before making changes:

```bash
cargo fmt --all --check
cargo test --workspace
cargo test --workspace --all-features
cargo check -p mplus-probe
(
  cd proof/lean
  lake build UOToolchain.ProofGradeRoot
)
./scripts/run_validation.sh
./scripts/rebuild_review_validation_false_paths.sh --check
git diff --check
```

If the baseline is not green, first create `BASELINE_STATUS.md` with the failing command, failure excerpt, and whether the issue is environmental or repository-local.

## Definition of done

Every issue below needs:

1. implementation changes;
2. focused Rust tests and/or Lean theorems;
3. regenerated generated artifacts, if affected;
4. a probe/report bit when the issue affects claims or evaluation;
5. README/docs updated only to match the actual code/proof status;
6. the validation slice listed in the issue passing locally.

---

## Issue 01 — Establish a reproducible local baseline and CI target

### Issue description

The repo pins Rust in `rust-toolchain.toml`, but a local agent still needs a one-command environment and CI path that can run Rust, Lean/Lake, probes, and benchmark regeneration. Without this, scientific claims depend on the maintainer’s local setup.

### How to fix

1. Add one reproducible environment path: `.devcontainer`, `Dockerfile.validation`, or `flake.nix`.
2. Pin Rust, Lean/Lake/Elan, and all system dependencies.
3. Add `scripts/baseline.sh` that runs the baseline gate above and writes `results/local-baseline/manifest.json` with tool versions and hashes.
4. Add CI jobs for formatting, Rust tests, Lean proof root, focused probe validation, and full validation as a manual/nightly job.

### Acceptance criteria

- A clean machine can run one documented command to execute the baseline.
- CI runs the focused baseline on every PR.
- Full validation is available as a manual or scheduled job.
- README documents the environment path.

---

## Issue 02 — Add a fail-closed proof-grade acceptance report

### Issue description

Committed reports mix required checks, advisory checks, expected-negative tamper cases, and expected computational-ORAM differences. Some reports have top-level `accepted: true` while nested booleans can be false; other reports have no top-level acceptance bit. This makes it hard to answer: “Is the proof-grade toolchain accepted?”

### How to fix

1. Define a common report schema with fields such as:
   - `schema`;
   - `report`;
   - `mode: proof_grade | advisory | expected_negative | evaluation`;
   - `accepted`;
   - `required`;
   - `false_paths`;
   - `expected_false_paths`;
   - `advisory_false_paths`.
2. Add an aggregate `results/acceptance.json` emitted by `mplus-probe`.
3. Add a checker such as `scripts/check_results_acceptance.py` or `cargo run -p mplus-probe -- --only acceptance-check`.
4. Call this checker from `scripts/run_validation.sh` and `scripts/run_all.sh`.

### Acceptance criteria

- `results/acceptance.json` has a final top-level `accepted` bit.
- A required report changed to `accepted: false` makes validation fail.
- Expected tamper rejections count as success only via explicit expected-negative metadata.
- No proof-grade required report contains unclassified false booleans.

---

## Issue 03 — Classify the false-path inventory

### Issue description

Validation JSON files contain many booleans. Some false values are expected, such as rejected tamper cases or computational ORAM physical-trace differences. Others may be real proof-boundary gaps. The toolchain needs a machine-checked false-path inventory.

### How to fix

1. Generate a complete false-path inventory from all `results/*.json`.
2. Assign every false path exactly one class:
   - `required_failure`;
   - `expected_negative`;
   - `expected_computational_difference`;
   - `advisory_nonclaim`;
   - `deprecated_report`.
3. Required failures must be fixed or the related claim must be demoted.
4. Rename misleading generic fields such as `coverage_complete: false` when the intended meaning is narrower.

### Acceptance criteria

- `results/acceptance.json` has zero `unclassified_false_paths`.
- `tamper_validation.json` expected rejections are expected-negative successes.
- `trace_equivalence.json` distinguishes exact equality obligations from computational ORAM checks.
- `bridge_validation.json` has a clear proof-grade verdict.

---

## Issue 04 — Reconcile the Path ORAM claim boundary

### Issue description

The docs are not fully synchronized about whether `path_oram_private_posmap_v1` is theorem-facing or experimental. `README.md` narrows the computational route to `path_oram_local_posmap_v1`, while `docs/claim-boundary.md` and `docs/supported-subset.md` describe private-posmap as theorem-facing for scalable maps.

### How to fix

Pick one route and make all code/docs/probes agree.

Conservative route:

1. Mark `path_oram_private_posmap_v1` as experimental/evaluation-only.
2. Make proof-grade compilation/admission reject private-posmap artifacts.
3. Keep private-posmap benchmarks under an explicit non-proof-grade mode.

Full theorem-facing route:

1. Ensure `PathOramPrivatePosmapV1.lean`, `AcceptedPackageCapstone.lean`, runtime ORAM implementation, compiler admission, and probe validation all expose the private-posmap route.
2. Add a claim-consistency probe that fails when README/docs/probes disagree.
3. Add large-map private-posmap benchmarks with proof-grade acceptance bits.

### Acceptance criteria

- Grepping for `path_oram_private_posmap_v1` shows consistent claim language.
- `cargo run -q -p mplus-probe -- --only claim-consistency --out-dir results` exists and passes.
- Proof-grade artifacts either accept private-posmap with theorem evidence or reject it with a clear diagnostic.
- `results/reviewer_summary.md` is generated with the same status.

---

## Issue 05 — Implement or demote private-posmap multi-access semantics

### Issue description

`crates/uo-core/src/manifest.rs` restricts multi-access-per-entrypoint support to the local-posmap scheme. Large private-posmap maps may therefore be claim-facing in prose but unusable for realistic smart-contract entrypoints that touch the same map multiple times.

### How to fix

If multi-access private-posmap is intended:

1. Implement multi-access private-posmap scheduling in runtime.
2. Prove composition for fresh coins, metadata pages, recursive/private position-map traces, and stash bounds.
3. Update `supports_multi_access_per_entrypoint()` only after proof and runtime tests exist.

If not intended:

1. Keep rejection.
2. Update docs and benchmarks to state that private-posmap supports only one logical access per map per entrypoint.
3. Ensure ERC20-like examples do not imply unsupported large-map multi-access.

### Acceptance criteria

- A private-posmap two-access entrypoint either compiles/proves or rejects with documented diagnostics.
- Docs and results label the selected behavior consistently.
- `results/overheads.json` includes rejected cases as explicit data, not omissions.

---

## Issue 06 — Make calls transactionally atomic on post-execution errors

### Issue description

`ContractInstance::call_impl` can mutate runtime state and freshness before all host-visible validation completes. Examples include missing encrypted return-channel session discovered during trace finalization, resource-budget failure after committed-state update, and production proof-bundle hash failure after execution.

Relevant paths:

- `runtime/uo-evm/src/engine.rs::call_impl`
- `runtime/uo-evm/src/theorem.rs::finalize_call_trace`
- `runtime/uo-evm/src/state.rs::run_confidential_entrypoint`
- `runtime/uo-evm/src/deployment.rs::validate_production_proof_bundle`

### How to fix

1. Add a transactional execution wrapper.
2. Run calls on staged state/freshness.
3. Commit staged state only after trace finalization, return-channel handling, budget checks, production evidence checks, and proof-bundle validation all succeed.
4. Roll back staged state/freshness on preflight, internal, proof, serialization, and production-evidence failures.
5. Keep modeled in-band contract abort behavior separate from internal host errors.

### Acceptance criteria

Add tests proving that these errors do not change committed state, initialized flag, `next_call_counter`, or rollback counter:

- missing `encrypted_to_client` return channel;
- wrong production `proof_bundle_sha256`;
- exceeded `max_commit_ops`;
- post-finalization serialization/proof-object failure.

A successful retry after a failed attempt should match a fresh instance’s trace hash.

---

## Issue 07 — Preflight return-channel and session requirements

### Issue description

Return-channel policy errors are currently detected during or after trace finalization. They should be preflight checks before `begin_call()` and before mutable runtime execution.

### How to fix

For the selected entrypoint, inspect `manifest_entry.returns` and enforce before execution:

- `EncryptedToClient` requires a session.
- Non-encrypted returns reject a supplied session.
- Production calls require evidence/session binding to match.
- Local calls may omit a session only for non-encrypted returns.

Keep finalization checks as defensive assertions.

### Acceptance criteria

- Return-channel preflight errors leave freshness and state unchanged.
- Production preflight errors happen before any trace is created.
- `cargo test -p uo-evm return_channel` covers both valid and invalid policy/session pairs.

---

## Issue 08 — Enforce confidential-object targeting at runtime

### Issue description

Compiler lowering rejects confidential programs that target non-confidential state, but runtime admission checks only whether the backend is UO, not whether the object is marked confidential.

Relevant paths:

- compiler check: `compiler/uo-solc/src/lib.rs::ensure_confidential_slot_program_uses_uo_backends`
- runtime check: `runtime/uo-evm/src/state.rs::ensure_confidential_program_targets_uo_backends`
- object helper: `runtime/uo-evm/src/objects.rs::is_update_oblivious_backend`

### How to fix

1. Add a runtime method that exposes `StateObject.spec.confidential` for each runtime object.
2. In runtime confidential-program admission, require both UO backend and `confidential == true`.
3. Add the invariant at deployment/admission as well as call time.
4. Add a tamper scenario that flips a target object from confidential to public while leaving a UO backend.

### Acceptance criteria

- A tampered artifact with a confidential kernel targeting a UO-but-public object is rejected before execution.
- Compiler-side rejection still passes.
- `tamper_validation.json` includes the new scenario and rejects it.

---

## Issue 09 — Bind production artifact identity to artifact contents or a checked certificate

### Issue description

`validate_production_artifact` validates the embedded admitted-package identity, but production runtime does not recompute the package identity from raw source/metadata or verify a translation-validation certificate before execution. Since `CompiledArtifact` does not carry raw source and sidecar bytes, artifact-content tampering needs a separate certificate binding.

Relevant paths:

- `runtime/uo-evm/src/deployment.rs::validate_production_artifact`
- `crates/uo-core/src/artifact.rs::AdmittedPackageIdentity`
- `compiler/uo-solc/src/lib.rs::translation_validation_bundle_against_artifact_with_metadata_bytes`
- `crates/uo-core/src/translation_validation.rs`

### How to fix

Preferred certificate route:

1. Add `translation_validation_certificate_sha256` to deployment policy or production call evidence.
2. Define a certificate containing admitted package identity, proof-relevant artifact view hash, Lean checker/root hash, and accepted checker result hash.
3. Validate certificate/artifact identity before execution.
4. Include the certificate hash in trace/proof-bundle binding.

Alternative packaging route:

1. Include raw source and raw metadata in production artifact package.
2. Recompute admitted-package identity at runtime before deployment.

### Acceptance criteria

- Tampering `contract.state`, `contract.functions`, `manifest.objects`, or `confidential_slot_program` after compilation is rejected in production mode.
- Missing, wrong, and mismatched certificate hashes are tested.
- Lean deployment acceptance exposes the certificate binding if the certificate route is selected.

---

## Issue 10 — Resolve the public-state declassification mismatch

### Issue description

`docs/supported-subset.md` advertises `public_state_declassifies`, and the compiler policy checker tracks sensitive writes to public state. But confidential entrypoints are later rejected if they target non-confidential state objects. This makes the advertised feature effectively unusable.

Relevant paths:

- `compiler/uo-solc/src/lib.rs::validate_entrypoint_policy`
- `compiler/uo-solc/src/lib.rs::ensure_confidential_slot_program_uses_uo_backends`
- `docs/supported-subset.md`

### How to fix

Choose one coherent design.

Conservative route:

1. Remove `public_state_declassifies` from accepted confidential-entrypoint metadata.
2. Reject sidecars that specify it.
3. Document that confidential releases must use return/status/encrypted-return channels.

Full feature route:

1. Add an explicit public-release sink separate from normal public state writes.
2. Lower confidential-to-public writes into fixed-schedule release events with labels.
3. Prove release safety in Lean and include it in the observer.
4. Make commit/rollback semantics atomic and composable.

### Acceptance criteria

- Conservative route: sidecars using `public_state_declassifies` are rejected and docs no longer claim support.
- Full route: a minimal confidential entrypoint writes a released public cell, trace records the label, tamper tests reject missing labels, and Lean proves final public state modulo declared release.

---

## Issue 11 — Normalize compile-time loop-bound handling

### Issue description

Static loop-bound validation and confidential linearization do not accept the same expression language. `validate_static_loop_bounds` uses `eval_loop_bound`, while `linearize_statement` uses `const_expr_usize`, which accepts only literal uints.

Relevant paths:

- `compiler/uo-solc/src/lib.rs::validate_static_loop_bounds`
- `compiler/uo-solc/src/lib.rs::eval_loop_bound`
- `compiler/uo-solc/src/lib.rs::linearize_statement`
- `compiler/uo-solc/src/lib.rs::const_expr_usize`

### How to fix

1. Create one source-of-truth helper, for example `compile_time_loop_bound(expr, loop_env)`.
2. Use it in validation, statement counting, and linearization.
3. Thread `loop_env` through linearization.
4. Emit normalized iteration counts in diagnostics/manifests.

### Acceptance criteria

Compiler tests cover:

- `for (uint i = 0; i < 2 + 2; i++)` compiles and unrolls four iterations;
- nested loop bounds depending on outer indices either compile deterministically or reject consistently;
- state/secret-dependent bounds reject before linearization;
- validation/counting/linearization agree on iteration counts.

---

## Issue 12 — Make the Solidity-like semantics boundary executable

### Issue description

The active theorem is for `uo-solidity-like-dsl-v1`, not full Solidity 0.8. Parser preprocessing, arithmetic semantics, division/modulo by zero, ABI encoding, `require`/abort behavior, context variables, and Keccak must be either modeled, bridged, or explicitly outside the claim.

### How to fix

1. Add a manifest field `semantics_profile` and include it in artifact identity.
2. Add tests for overflow, division by zero, signedness, ABI encoding, fixed-size `keccak256`, `require`, abort status, storage layout, and rejected Solidity features.
3. Emit a source-resolution witness for state-name resolution, helper inlining, loop normalization, ABI unwrapping, and public-environment lowering.
4. Either prove or explicitly assume Keccak/ABI equivalence. If assumed, expose a checker-visible assumption ID.

### Acceptance criteria

- Every artifact declares `semantics_profile`.
- Proof-grade checker rejects unknown profiles.
- Keccak-using examples have explicit trusted-primitive/ABI obligations or are excluded from semantic-preservation claims.
- Docs and generated claim-status agree with compiler/checker behavior.

---

## Issue 13 — Calibrate modeled gas/resource accounting

### Issue description

Manifest `gas_budget` is currently a modeled resource cost derived from statement/expression counts and commit operations. It is not stock EVM gas unless a versioned EVM gas schedule and bytecode backend are added.

### How to fix

1. Rename fields/docs to `modeled_gas`, `resource_units`, or another model-tagged name unless EVM calibration is implemented.
2. Add a `cost_model` identifier to manifests and results.
3. If EVM-style gas is desired, add a versioned gas schedule file and derive costs from it.
4. Add a checker that validates `trace.cost == manifest cost formula` for every entrypoint.

### Acceptance criteria

- Results do not use ambiguous “gas” wording without a model tag.
- `results/overheads.json` records the cost model.
- A probe report checks formula exactness for all benchmarks.
- Docs distinguish modeled cost from stock EVM gas.

---

## Issue 14 — Tighten the runtime-to-Lean transcript boundary

### Issue description

The claim boundary still lists source-frozen/static-drift evidence and trusted proof-object extraction/serialization as part of the TCB. This is honest but fragile. Proof objects should be generated from a small canonical transcript wherever possible.

### How to fix

1. Inventory proof-critical source-drift checks.
2. Classify each as generated-from-Lean, typed schema checked against Lean, executable semantic refinement, or trusted boundary.
3. Define a canonical primitive transcript format for runtime execution.
4. Make proof-object extraction consume the transcript, not arbitrary engine internals.
5. Hash-bind transcript/extractor output to artifact identity, public environment, session, freshness, and runtime/proof-root identity.

### Acceptance criteria

- `runtime_boundary_validation.json` separates proof-critical checks from regression-only checks.
- No proof-critical claim depends only on a Rust source substring unless listed in the TCB.
- Tampering with observer-relevant events is rejected.
- Docs update the TCB table accordingly.

---

## Issue 15 — Maintain a Lean assumption and axiom budget

### Issue description

The proof tree contains legacy modules and explicit assumptions. The proof-grade route needs a generated budget showing which assumptions are active, which are legacy-only, and which theorem claims depend on them.

### How to fix

1. Add a script/probe that scans Lean files for `axiom`, `opaque`, `unsafe`, `sorry`, legacy theorem names, and assumption bundles.
2. Emit `results/lean_assumption_budget.json`.
3. Separate active proof-grade assumptions from legacy/demo modules.
4. Fail CI if new proof-grade axioms appear without explicit allowlist entries and documentation.

### Acceptance criteria

- `results/lean_assumption_budget.json` lists active assumptions and consumers.
- Proof-grade root excludes legacy axiom-backed modules unless explicitly documented.
- CI fails on unexpected new assumptions.

---

## Issue 16 — Add executable insecure baselines for evaluation

### Issue description

Raw baselines are often rejected because confidential objects use raw backends. That is correct for proof-grade execution, but scientific evaluation needs executable insecure baselines to measure leakage and overhead.

### How to fix

1. Add an evaluation-only mode such as `ProgramMode::InsecureRawEval`.
2. Stamp artifacts/traces/results with `insecure_baseline: true`.
3. Ensure production deployment and proof-grade translation validation reject these artifacts.
4. Generate insecure baselines for every benchmark.

### Acceptance criteria

- `results/overheads.json` has executable insecure baseline rows for every benchmark.
- `results/leakage_auc.json` includes positive-control leakage above threshold for insecure raw cases designed to leak.
- Production runtime rejects insecure-baseline artifacts.
- Result labels cannot be confused with proof-grade artifacts.

---

## Issue 17 — Add differential correctness testing

### Issue description

Evaluation should systematically compare insecure/raw logical behavior with UO behavior on public outputs and allowed releases.

### How to fix

1. Build a property-test harness in `mplus-probe` or a new crate.
2. Define generators for public inputs, secret inputs, and initial state for each benchmark.
3. Execute insecure baseline and UO artifact over the same logical inputs.
4. Assert equality of public return, abort/status policy, declassified outputs, and final public state modulo declared releases.
5. Record seeds in `results/reproducibility_manifest.json`.

### Acceptance criteria

- `results/correctness.json` includes per-benchmark trial counts and seeds.
- Full validation runs at least 1,000 small-domain trials per benchmark where feasible.
- CI runs a fast subset.
- Introducing an incorrect UO update causes the harness to fail.

---

## Issue 18 — Add statistically meaningful leakage experiments

### Issue description

Trace equivalence and AUC outputs need stronger scientific scaffolding: positive controls, negative controls, confidence intervals, and explicit mapping to the theorem observer.

### How to fix

1. Define a `LeakageScenario` schema in `benches/harnesses`.
2. For each scenario, record benchmark, entrypoint, secret distributions, fixed public state, metrics, and expected leak/no-leak result.
3. Extract observer metrics for logical schedule, physical reads/writes, write classes, modeled cost, boundary events, and trace size.
4. Compute AUC, mutual information estimates, and confidence intervals.
5. Fail the probe if a positive control does not leak or a negative control leaks.

### Acceptance criteria

- `results/leakage_auc.json` contains positive and negative controls.
- Insecure raw positive controls leak above threshold.
- Exact UO backends do not leak above threshold on exact observer metrics.
- ORAM results are labeled computational, not exact.

---

## Issue 19 — Expand end-to-end benchmarks and edge-case case studies

### Issue description

The evaluation should include coherent smart-contract workloads, not just microbenchmarks. It should also cover capacity overflow and abort/rollback behavior.

### How to fix

Add benchmark families:

1. `SimpleWallet`: cells/arrays only, low-overhead feasibility.
2. `SealedBidAuction`: secret bids and public winner/status release.
3. `PrivateERC20Lite`: balances/allowances, multiple map accesses, full-scan and ORAM variants.
4. `RegistryCRUD`: map insert/update/delete and capacity behavior.
5. `AuthScan`: fixed-array scan.
6. `CapacityOverflow`: intentionally full bounded map.
7. `AbortRollback`: write then abort/revert-like behavior.

For each benchmark, provide raw source, proof-grade metadata, insecure-baseline metadata, harness config, expected public behavior, and capacity sweep where applicable.

### Acceptance criteria

- Every benchmark has correctness, leakage, and overhead rows.
- Capacity sweeps include at least three capacities for map-heavy workloads.
- Compile failures are explicit rows with reasons, not missing data.
- `results/reviewer_summary.md` includes generated overhead/rejection tables.

---

## Issue 20 — Add a compiler admission matrix and golden diagnostics

### Issue description

The DSL is intentionally restricted. The toolchain needs executable admission tests and stable diagnostics for every accepted and rejected feature.

### How to fix

Create compiler/checker tests covering:

- scalar operations;
- fixed arrays;
- structs;
- helpers;
- public environment reads;
- bounded loops;
- secret-dependent branches;
- early returns;
- external calls;
- constructors/fallbacks;
- dynamic arrays/strings/bytes;
- unbounded mappings;
- inheritance/modifiers;
- events/errors/revert/try-catch;
- multiple returns;
- unsupported integer widths;
- unsupported lvalues.

### Acceptance criteria

- `results/admission_matrix.json` is generated.
- Every rejected feature in `docs/supported-subset.md` has a test.
- Every accepted feature has a compile-and-run test.
- Diagnostics name the unsupported feature clearly.

---

## Issue 21 — Generate claim/evaluation artifact manifests

### Issue description

Reviewers and maintainers need a generated mapping from each claim to the code, theorem, runtime, benchmark, and result artifacts that support it.

### How to fix

Extend `mplus-probe` to emit:

- `results/claim_status.json`;
- `results/claim_status.md`;
- `results/claim_artifact_manifest.json`.

For each claim, record:

- claim id;
- claim text;
- status: Lean-proved, generated-and-checked, source-frozen, empirically tested, trusted, experimental, or non-claim;
- source files;
- Lean modules;
- runtime/compiler files;
- benchmark/result files;
- validation command.

### Acceptance criteria

- Every claim in `docs/claim-boundary.md` appears in the manifest.
- Every trusted assumption and non-claim appears with rationale.
- CI fails if docs mention a claim id missing from the manifest.
- README/docs either include generated snippets or are checked against generated status.

---

## Recommended fix order

1. Issue 01 — reproducible baseline and CI.
2. Issue 02 — fail-closed acceptance report.
3. Issue 03 — false-path inventory.
4. Issue 04 — Path ORAM claim boundary.
5. Issue 05 — private-posmap multi-access or demotion.
6. Issue 06 — transactional call atomicity.
7. Issue 07 — return-channel preflight.
8. Issue 08 — runtime confidential-object targeting.
9. Issue 09 — production artifact/certificate binding.
10. Issue 10 — public-state declassification mismatch.
11. Issue 11 — loop-bound normalization.
12. Issue 12 — executable semantics boundary.
13. Issue 13 — modeled gas/resource accounting.
14. Issue 14 — runtime-to-Lean transcript boundary.
15. Issue 15 — Lean assumption budget.
16. Issue 16 — insecure evaluation baselines.
17. Issue 17 — differential correctness.
18. Issue 18 — leakage experiments.
19. Issue 19 — end-to-end benchmarks and edge cases.
20. Issue 20 — admission matrix.
21. Issue 21 — claim/evaluation artifact manifests.

## Final release gate

After the selected fixes are complete, run:

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace
cargo test --workspace --all-features
(
  cd proof/lean
  lake build
  lake build UOToolchain.ProofGradeRoot
)
./scripts/run_validation.sh
./scripts/run_heavy_artifact.sh
cargo run -q -p mplus-probe -- --only claim-consistency --out-dir results
cargo run -q -p mplus-probe -- --only tamper-validation --out-dir results
cargo run -q -p mplus-probe -- --only reviewer-summary --out-dir results
./scripts/rebuild_review_validation_false_paths.sh --check
git diff --check
```

Regenerate committed results only through probe/scripts. Do not hand-edit generated files under `results/`.
