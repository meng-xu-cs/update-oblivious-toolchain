# End-to-End Evaluation Plan and Local Agent Runbook

This runbook is designed for a local coding agent or CI runner. It assumes a fresh checkout of the uploaded repository and a machine with Rust, Lean/Lake, Python, `jq`, and standard Unix tools.

## 0. Evaluation goals

The evaluation should answer four questions:

1. **Does the proof-grade theorem surface build cleanly and remain axiom-clean?**
2. **Does the compiler/checker accept exactly the intended source+metadata subset?**
3. **Do runtime proof objects, witness families, and Path ORAM certificates validate and reject meaningful tampering?**
4. **Is the toolchain usable and performant enough for the claimed research applications?**

A successful evaluation produces a signed or hashed evidence bundle containing tool versions, source hashes, proof/build logs, validation JSON, tamper results, benchmark results, and a gap list.

## 1. Environment and reproducibility capture

1. Start from a clean clone/unpacked archive.
2. Record:
   - OS/kernel/CPU/RAM.
   - `git rev-parse HEAD` if a git checkout exists.
   - SHA-256 of the uploaded archive and every generated artifact.
   - Rust version, Cargo version, Lean/Lake version.
   - `proof/lean/lean-toolchain` contents.
   - `Cargo.lock` hash.
3. Prefer a clean container. If none exists, create a Dockerfile or Nix flake as the first evaluation output.

Recommended initial commands:

```bash
pwd
find . -maxdepth 2 -type f | sort > eval_out/file_inventory.txt
sha256sum Cargo.lock proof/lean/lean-toolchain > eval_out/toolchain_hashes.txt
rustc --version --verbose > eval_out/rust_version.txt
cargo --version >> eval_out/rust_version.txt
(cd proof/lean && lake --version > ../../eval_out/lake_version.txt && lean --version >> ../../eval_out/lake_version.txt)
```

## 2. Static trust-surface audit

Run before any build, so failures are easy to diagnose.

```bash
mkdir -p eval_out
rg -n "\baxiom\b|\bsorry\b|admit|unsafe|unwrap\(|panic!|todo!|unimplemented!" proof compiler crates runtime checker benches scripts > eval_out/static_red_flags.txt || true
rg -n "legacyOramLocalTheorem|legacySgxMicroLocalTheorem" proof/lean > eval_out/legacy_symbol_surface.txt || true
rg -n "returns|status|declassifies|PublicOutcomeTrace|SGXPublicOutcome|ProofRelevantEntrypointView" proof crates compiler runtime checker > eval_out/policy_surface.txt || true
```

Acceptance criteria:

- All `axiom` occurrences are expected and isolated to legacy or explicit assumption modules.
- No unexpected `sorry`, `admit`, `todo!`, or `unimplemented!` in proof-grade routes.
- Policy-bearing fields appear in proof-relevant theorem/checker routes after the proposed fixes.

## 3. Rust build/test/lint pass

```bash
cargo fmt --all --check | tee eval_out/cargo_fmt.log
cargo check --workspace --all-targets | tee eval_out/cargo_check.log
cargo test --workspace --all-targets --no-fail-fast | tee eval_out/cargo_test.log
cargo clippy --workspace --all-targets -- -D warnings | tee eval_out/cargo_clippy.log
```

If `clippy -D warnings` is too strict for the current repository, record the warnings and downgrade only with justification. Do not silently skip.

Acceptance criteria:

- Formatting passes.
- All tests pass.
- Any lints in security-critical files are triaged.

## 4. Lean build and axiom hygiene

```bash
(
  cd proof/lean
  lake build UOToolchain.ProofGradeRoot | tee ../../eval_out/lake_build_proofgrade.log
  lake build | tee ../../eval_out/lake_build_all.log
  lake env lean CheckProofGradeAxiomReport.lean | tee ../../eval_out/axiom_report.log
)
```

Acceptance criteria:

- `UOToolchain.ProofGradeRoot` builds.
- `CheckProofGradeAxiomReport.lean` prints only the expected standard Lean axioms.
- Legacy roots do not enter proof-grade checkers.

## 5. Repository scripts and committed validation artifacts

Run repository-provided scripts:

```bash
./scripts/run_validation.sh | tee eval_out/run_validation.log
./scripts/run_bridge_validation.sh | tee eval_out/run_bridge_validation.log
./scripts/check_probe_reproducibility.sh | tee eval_out/check_probe_reproducibility.log
./scripts/run_heavy_artifact.sh | tee eval_out/run_heavy_artifact.log
./scripts/run_all.sh | tee eval_out/run_all.log
```

Use `jq` to summarize generated/committed results:

```bash
jq '.scenario_count // empty' results/tamper_validation.json > eval_out/tamper_scenario_count.txt || true
jq '[.. | objects | select(has("accepted")) | .accepted] | {accepted: map(select(.==true))|length, rejected: map(select(.==false))|length}' results/tamper_validation.json > eval_out/tamper_accept_reject_summary.json || true
jq '.legacy_axiom_definition_surface_restricted, .proofgrade_axiom_report_legacy_symbols_absent' results/static_checks.json > eval_out/static_check_summary.txt || true
```

Acceptance criteria:

- Positive examples accept under proof-grade checkers.
- Negative/tampered examples reject for the intended reasons.
- Heavy-artifact generation either completes or reports a documented capacity/size limitation.

## 6. Compiler/subset negative corpus

Create a `tests/subset_rejection/` corpus. Each test should assert a clear reject reason and source span where possible.

Required negative cases:

- Top-level import ignored by current frontend.
- Multiple contracts/libraries with selected contract referencing external declarations.
- Pragma/import/source-unit parts not explicitly permitted.
- Inheritance, modifiers, constructor/fallback/receive.
- Events, custom errors, revert, try/catch.
- External calls and arbitrary internal calls.
- Dynamic arrays, `string`, dynamic `bytes`.
- `uint8`, `uint64`, `uint256` overflow literal, and mixed integer widths.
- Metadata missing `backend`, missing `confidential`, missing entrypoint policies.
- Metadata array capacity different from source fixed-array length.
- Metadata map key/value type different from source mapping type.
- Confidential entrypoint targeting a non-confidential full-scan/ORAM object.
- Secret-dependent status without status declassification.
- Public/declassified return without required declassification label.
- Extra declassification labels not used by policies, if exact-label discipline is adopted.

Acceptance criteria:

- Every unsupported construct is rejected before proof-grade artifact generation.
- Every security-critical metadata omission is rejected in strict/proof-grade mode.
- Error messages identify the field/construct and recommended rewrite.

## 7. Policy and manifest tamper suite

This is the highest-priority new test suite. See `05_policy_and_manifest_tamper_tests.md` for details.

Minimum mutations:

- `returns: forbidden -> declassified`.
- `returns: declassified -> forbidden` while preserving return payload logic.
- `status: public -> declassified` and `status: declassified -> public`.
- Add/remove/reorder `declassifies` labels.
- Add a `return_payload` to an aborted call.
- Remove `return_canonical_len` or alter output shape.
- Change `secret_args`, `param_names`, `entry_input_len`, gas/resource budgets.
- Change object `confidential`, `backend`, `capacity`, `oram_scheme`.

Acceptance criteria before fixes:

- Document exactly which mutations are rejected by CLI-only checks vs Lean proof-grade checks.

Acceptance criteria after fixes:

- Policy mutations that affect the observer are rejected by proof-grade Lean checks or are reflected in a policy-aware theorem premise/conclusion.
- No policy-observer mutation can leave the proof-relevant Lean object unchanged unless the public theorem explicitly projects the field away and the claim-boundary prose says so.

## 8. Runtime proof-object validation and replay

For every benchmark and every accepted entrypoint:

1. Compile source+metadata into artifact.
2. Run the runtime with multiple public-equivalent secret inputs.
3. Emit:
   - controller observer certificate;
   - hidden ORAM certificate;
   - runtime kernel witness;
   - shell-boundary/refinement witness;
   - trusted-kernel slot bundle;
   - fresh-coin witness family where applicable;
   - Path ORAM pair/canonical certificate where applicable.
4. Validate each emitted object with its Lean checker.
5. Mutate every scalar/list field once and ensure required rejections.
6. Replay the event transcript independently and compare canonical hashes.

Acceptance criteria:

- Every emitted object validates.
- Field-coverage mutation tests prove the checker either rejects the field change or documents it as projection-irrelevant.
- Runtime execution and proof-object extraction are hash-bound to the same source+metadata+artifact package.

## 9. Semantic differential tests

Construct a simple reference interpreter for the intended finite, typed source subset. For each accepted program:

- Generate random public inputs and secret inputs within capacity bounds.
- Run raw/reference semantics and UO semantics.
- Compare public outputs, declassified returns, status, and final logical state for public-readable objects.
- Include abort/rollback cases.
- Include repeated multi-call histories.

Acceptance criteria:

- UO runtime semantics match the reference semantics for all generated tests.
- Any deliberate semantic divergence, such as `u128` instead of `uint256`, is reflected in source admission and theorem wording.

## 10. Leakage and side-channel proxy evaluation

For each benchmark:

1. Generate two or more secret distributions with identical public inputs.
2. Record host-visible public outcome, boundary schedule, storage trace shape, normalized micro trace, gas/resource usage, proof-object sizes, and runtime errors.
3. Compute exact equality checks for deterministic traces.
4. Compute empirical leakage metrics only as supporting evidence: mutual information, classifier AUC, distinguishability tests.

Acceptance criteria:

- Exact/model traces are equal where exact-UO is claimed.
- ORAM traces differ only according to the computational theorem’s public leakage model.
- Empirical classifiers do not exceed noise baselines on modeled traces.
- Any unmodeled physical timing/page/cache behavior is labeled non-claim.

## 11. Performance and practicality evaluation

Collect at least:

- Compile time per program.
- Lean checker time per proof object.
- Runtime execution time per call.
- Gas/model-cost estimates.
- Storage writes/read counts and bytes.
- Proof-object sizes.
- Scaling curves over capacity: 8, 16, 32, 64, 128, 256 if feasible.
- Full-scan vs Path ORAM comparisons.
- User-facing failure rates from the rejection corpus.

Acceptance criteria:

- The report identifies the largest practical capacity that can be checked locally.
- Path ORAM artifact blowups are quantified and bounded by configuration guidance.
- The toolchain’s realistic use cases are documented honestly.

## 12. Final evidence bundle

The local agent should produce:

```text
eval_out/
  environment.json
  source_hashes.txt
  build_logs/
  lean_logs/
  validation_json/
  tamper_json/
  mutation_matrix.csv
  benchmark_summary.md
  theorem_gap_report.md
  unresolved_assumptions.md
  recommended_patches.md
```

Each file should be SHA-256 hashed. The final evaluation report should include a table mapping every theorem claim to its evidence artifact and remaining assumptions.
