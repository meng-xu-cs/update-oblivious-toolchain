# Targeted Policy and Manifest Tamper Tests

These tests are designed to expose whether the proof-grade theorem/checker surface is sensitive to the same public-observer fields described in `docs/claim-boundary.md` and emitted by Rust `PublicOutcomeTrace`.

## Why these tests matter

The Rust manifest stores `returns`, `status`, and `declassifies`. The Rust runtime public trace stores `status_policy`, `return_policy`, `return_payload`, and `declassifies`. The claim boundary says these are part of `public_outcome`.

However, the current proof-relevant translation view inspected in `crates/uo-core/src/translation_validation.rs` does not include `returns`, `status`, or `declassifies`, and the Lean `SGXPublicOutcome` inspected in `proof/lean/UOToolchain/SgxRelation.lean` does not include policy labels or return payload.

Therefore, a high-priority evaluation is to distinguish:

- mutations rejected by the CLI/full-manifest checker only;
- mutations rejected by proof-grade Lean checkers;
- mutations silently projected away by the current formal theorem.

## Test setup

Pick at least these benchmarks:

- `FixedSlotClassifier.uo.yaml` — simple confidential cell, public getter.
- `RegistryCRUD.uo.yaml` — map CRUD, declassified read.
- `ConfidentialMixer.pathoram.yaml` — Path ORAM, declassified return/status in `withdraw`.
- `ERC20Lite.pathoram.yaml` — larger multi-entrypoint Path ORAM example.

For each benchmark:

1. Compile source+metadata to a normal artifact.
2. Generate the proof-grade translation artifacts consumed by Lean.
3. Run the proof-grade checker and confirm acceptance.
4. Apply one mutation at a time.
5. Re-run:
   - the CLI source/artifact checker;
   - the proof-grade translation checker;
   - runtime proof-object checkers if the mutation affects runtime traces.
6. Record whether each route accepts/rejects and the exact error message.

## Minimal mutation matrix

| ID | Mutation | Expected after fix | Why |
| --- | --- | --- | --- |
| P01 | Change `manifest.entrypoints[F].returns` from `forbidden` to `declassified`. | Lean proof-grade translation rejects or theorem public outcome changes. | Return policy is part of public observer. |
| P02 | Change `returns` from `declassified` to `forbidden` for a function that returns a public/declassified payload. | Lean rejects. | Runtime payload no longer allowed by policy. |
| P03 | Change `status` from `public` to `declassified`. | Lean rejects or theorem outcome changes. | Status policy label is observable and claimed. |
| P04 | Change `status` from `declassified` to `public` for a secret-dependent status function. | Lean rejects. | Secret-dependent status requires declassification discipline. |
| P05 | Remove `return` from `declassifies` while keeping `returns: declassified`. | Lean rejects. | Declared declassification labels must match payload exposure. |
| P06 | Add extra unused `declassifies` label. | Decide policy: reject exact mismatch or formally allow documented superset. | Avoid confusing/overbroad public labels. |
| P07 | Reorder `declassifies`. | Lean should accept only if canonicalized sorting is explicit. | Prevent accidental order-sensitive hashes. |
| P08 | Add `return_payload` to an aborted call outcome. | Runtime/Lean rejects. | Aborts should clear plaintext returns. |
| P09 | Alter `return_canonical_len` without changing source return type. | Lean rejects. | Output shape is public/proof-relevant. |
| P10 | Change `secret_args` by removing one secret argument. | Lean rejects. | Public/secret projection changes. |
| P11 | Change `param_names` but not positions. | Decide policy: reject if names are part of source package; otherwise document projection. | Names can be metadata/documentation but should be deterministic. |
| P12 | Increment `public_gas_budget`. | Lean rejects. | Existing tamper results already exercise this; keep as baseline. |
| P13 | Change object `capacity`. | Lean rejects. | Capacity controls schedule and semantics. |
| P14 | Change object `backend` full_scan/oram/raw. | Lean rejects. | Backend controls theorem route. |
| P15 | Change object `confidential`. | Lean rejects or theorem changes. | Confidentiality is security policy. |
| P16 | Change fixed-array sidecar `capacity` to differ from source length. | Compiler rejects before artifact. | Source/model length consistency. |
| P17 | Change map sidecar `key`/`value` type to disagree with source. | Compiler rejects before artifact. | Sidecar/source consistency. |
| P18 | Change `oram_scheme` from `path_oram_local_posmap_v1` to surrogate in a paper-claimed artifact. | Lean rejects. | Surrogate not proof-grade ORAM. |

## Suggested implementation approach

Add a Rust or Python mutation harness under `tests/tamper_policy/` that:

1. Loads JSON artifacts as canonical JSON.
2. Applies a mutation using a JSON pointer.
3. Writes the mutated artifact.
4. Runs the relevant binary/checker.
5. Records `{mutation_id, field, route, accepted, stderr, stdout, artifact_hash}`.

Pseudo-code:

```python
for case in cases:
    original = load_json(case.artifact)
    mutated = deepcopy(original)
    apply_mutation(mutated, case.pointer, case.new_value)
    write_json(mutated, out_path)
    run_cli_checker(case.source, out_path)
    run_lean_checker(case.proofgrade_bundle_or_mutated_object)
    record_result()
```

## Acceptance criteria

A proof-grade release should satisfy the following:

1. Every observer-relevant policy mutation is caught by a Lean proof-grade checker or appears explicitly in a changed Lean public outcome object.
2. CLI-only rejection is not enough for paper-theorem-critical fields, because `uo-check` is documented as outside the proof-grade TCB.
3. Every ignored field is documented as projection-irrelevant in the claim boundary, and the observer definition excludes it.
4. The test suite includes a field-coverage report showing every manifest/public-outcome field and whether it is proof-relevant, projection-irrelevant, or trusted.

## Example field-coverage report format

| Object | Field | Current route | Required route |
| --- | --- | --- | --- |
| `EntrypointManifest` | `returns` | Rust manifest / CLI check; not in inspected proof-relevant view | Lean proof-relevant translation + policy-aware public outcome |
| `EntrypointManifest` | `status` | Rust manifest / CLI check; not in inspected proof-relevant view | Lean proof-relevant translation + policy-aware public outcome |
| `EntrypointManifest` | `declassifies` | Rust manifest / CLI check; not in inspected proof-relevant view | Lean proof-relevant translation + policy-aware public outcome |
| `PublicOutcomeTrace` | `return_payload` | Runtime trace; not in inspected `SGXPublicOutcome` | Lean policy-aware public outcome or explicit non-claim |
| `PublicOutcomeTrace` | `gas_used` | Rust trace and Lean `SGXPublicOutcome.gasUsed` | Already modeled; keep tamper tests |
