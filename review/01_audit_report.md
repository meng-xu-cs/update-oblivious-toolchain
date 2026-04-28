# Static Audit Report: Update-Oblivious Toolchain

Date: 2026-04-28

## Scope and caveats

I reviewed the uploaded archive statically: documentation, Rust compiler/runtime/checker code, Lean theorem/checker modules, committed validation outputs, scripts, and benchmark metadata. The environment used for this review did not contain `cargo`, `rustc`, `lake`, or `lean`, so I could not execute the Rust test suite or Lean builds here. The evaluation runbook in this bundle is meant for a local agent or CI machine with the required toolchains installed.

The review intentionally focuses on issues beyond the already documented boundaries: parser/preprocessing equivalence, deep Rust semantics below the checked boundary, external ORAM theorem citation instead of imported machine-checked proof, Lean foundations, real Keccak vs Lean mock hash, and TEE deployment assumptions. Some findings below touch those boundaries only when there is an eliminable bridge or framing improvement.

## Executive judgment

The project has an unusually explicit claim-boundary story. The strongest pieces are the clean separation between proof-grade and legacy roots, the proof-grade axiom report, the large family of Lean checkers for runtime objects, and the committed validation/tamper artifacts. The current artifacts make a credible case for an instrumented, restricted update-oblivious DSL executed through a checked runtime/proof-object interface.

The biggest risk is not the Path ORAM citation or parser trust; those are visible and documented. The biggest risk is that the formal public-outcome surface used by the paper-facing Lean theorem appears narrower than the public-outcome surface described in the documentation and emitted by the Rust runtime. In particular, return/status policy, declassification labels, and return payload are present in Rust `PublicOutcomeTrace` and in prose claim wording, but the Lean `SGXPublicOutcome` structure used by the SGX/paper theorem contains only entrypoint id, public args, termination status, output shape, and gas. Separately, the proof-relevant translation view omits manifest `returns`, `status`, and `declassifies`. This creates a plausible “prove the wrong public outcome” gap unless another policy-bearing theorem route exists and is connected to the paper theorem; I did not find such a connected route in the archive.

The second most important issue is theorem framing: the paper theorem says “for every admitted Solidity source program `P`,” but the semantics and security policy are not determined by `P` alone. They are determined by the source plus sidecar metadata: backend choice, confidentiality, capacities, secret arguments, gas budgets, return policy, status policy, and declassification policy. The theorem should quantify over an admitted `(source, metadata)` pair, and the artifact/runtime proof objects should bind to a canonical hash of both.

## Task 1 — Unintended trust boundaries and assumptions

### F-01 — Critical: Formal public outcome omits policy/payload fields that the claim says are public

**Evidence.** `docs/claim-boundary.md` defines the paper-facing observer’s `public_outcome` as including entrypoint id, public arguments, termination status, declared status policy, return shape, return policy, public/declassified return payload, declassification labels, and modeled public gas. Rust agrees with that richer shape: `crates/uo-core/src/trace.rs` defines `PublicOutcomeTrace` with `status_policy`, `return_policy`, `return_payload`, and `declassifies`, and `with_host_visibility()` copies those from `EntrypointManifest`. But the Lean structure used by the SGX relation, `proof/lean/UOToolchain/SgxRelation.lean`, defines:

```lean
structure SGXPublicOutcome where
  entrypointId : String
  publicArgs : List String
  terminationStatus : Bool
  outputShape : OutputShape
  gasUsed : Nat
```

No policy labels or payload are present in that structure. Searches for policy fields in Lean found only audit-surface strings, not a connected policy-bearing public outcome.

**Impact.** The paper-facing theorem can prove equality/safety for a smaller public outcome than the one described in the claim boundary and emitted by the runtime. This is exactly the sort of “prove the wrong thing” failure you called out. A host may observe return payloads and declassification labels through the real runtime; if the paper theorem does not model them, the theorem is not yet the theorem stated in prose.

**Path to reduce/eliminate.** Introduce a Lean `PolicyAwareSGXPublicOutcome` or extend `SGXPublicOutcome` with:

- `statusPolicy`
- `returnPolicy`
- `returnPayload?`
- canonical `declassifies`
- possibly an explicit `returnPayloadIsAllowedByPolicy` predicate

Then update `PublicOutcomeSafe`, `OramPublicOutcomeSafe`, `sgxViewOf...`, runtime JSON importers, and all paper theorem routes to use the policy-aware outcome. Add a theorem that the runtime-emitted `PublicOutcomeTrace` projects exactly to the Lean policy-aware outcome. Add tamper tests that mutate only `returns`, `status`, `declassifies`, or `return_payload` and require the proof-grade Lean route to reject or account for the mutation.

### F-02 — Critical: Proof-relevant translation view omits return/status/declassification policies

**Evidence.** `crates/uo-core/src/manifest.rs` defines `EntrypointManifest` with:

```rust
pub returns: ReturnPolicy,
pub status: StatusPolicy,
pub declassifies: Vec<DeclassificationKind>,
```

But `crates/uo-core/src/translation_validation.rs` defines `ProofRelevantEntrypointView` without those fields. The view includes signature, secret args, params, input length, gas/resource fields, programs, kernel steps, counts, commit ops, and ORAM accesses, but not return/status/declassification policy. `from_manifest_entrypoint()` similarly does not copy those policy fields.

`checker/uo-check` appears to compare the full manifest when checking an artifact against source, which is good for CLI diagnostics. However, `docs/claim-boundary.md` states that `uo-check` is outside the proof-grade TCB; the proof-grade Lean route should therefore not rely on the CLI’s full-manifest comparison to protect policy exactness.

**Impact.** An artifact could have the same proof-relevant source/artifact view under the current schema while differing in policy fields, unless another checker rejects it before the proof-grade theorem consumes it. The theorem would then be insensitive to fields that bound the public leakage policy.

**Path to reduce/eliminate.** Add `returns`, `status`, and canonical `declassifies` to `ProofRelevantEntrypointView`, the Lean imported view, the validity predicate, and the source/artifact equality theorem. Add source-side policy soundness theorems:

- return payload present only when return policy is `declassified` or equivalent;
- status is host-visible only under `public`/`declassified` status policy as intended;
- `declassifies` exactly matches policy uses, not merely a superset;
- aborts clear plaintext returns and expose only the permitted status.

### F-03 — High: The theorem should quantify over `(source, sidecar metadata)`, not source alone

**Evidence.** The sidecar metadata determines confidential entrypoints, secret args, state confidentiality, backend choice, map/array capacity, gas budgets, return/status policy, and declassification labels. The docs currently phrase the paper theorem as applying to an admitted Solidity source program `P` compiled to artifact `A`. But the same Solidity source can yield materially different claims under different metadata.

**Impact.** Treating `P` alone as the program spec under-specifies the security theorem. A public claim like “the source program is update-oblivious” is false without the policy/capacity/backend/declassification sidecar.

**Path to reduce/eliminate.** Restate every end-to-end theorem and artifact claim over an admitted program package `(P, M)` where `M` is a strict sidecar metadata document. Bind the artifact, runtime witnesses, SGX attestation quote, and all proof-grade JSON objects to a canonical hash of `(P, M, compiler version, runtime version, checker version, model tags)`. Add a theorem/validation lemma: `artifactPackageHashExact`.

### F-04 — High: Sidecar metadata defaults weaken the “explicit policy” story

**Evidence.** `crates/uo-core/src/metadata.rs` gives `StateMetadata.backend` a default of `full_scan`, `oram_scheme` a default of `surrogate_public_schedule_v1`, and `confidential` a default of `false`. The docs say state metadata should explicitly declare kind, backend, and confidentiality.

**Impact.** Missing metadata is not always rejected. This is a practical and theorem-framing problem: security-critical intent can be silently inferred. Defaulting `confidential` to false is especially dangerous from a user-experience perspective; defaulting backend to full-scan can also obscure when a source/metadata package moved from raw to UO mode.

**Path to reduce/eliminate.** Use `Option` for all security-critical metadata fields, reject absence in strict/proof-grade mode, and make non-strict defaults available only behind an explicit `--legacy-defaults` or `--dev-defaults` flag. Add proof-grade validation that every object/entrypoint has an explicit policy declaration.

### F-05 — High: Array capacity can differ from Solidity fixed size

**Evidence.** In `compiler/uo-solc/src/lib.rs`, `lower_state_object()` extracts a fixed Solidity array length, but for arrays it sets:

```rust
capacity: Some(state_meta.capacity.unwrap_or(capacity))
```

So if the sidecar provides a `capacity`, it overrides the source array length.

**Impact.** The runtime/proof universe can disagree with the Solidity source’s actual array length. This can change `.length`, bounds behavior, iteration counts, and storage schedule. That is an eliminable source-to-model mismatch.

**Path to reduce/eliminate.** For fixed arrays, require `state_meta.capacity` to be absent or exactly equal to the source length. Better: forbid `capacity` for arrays and derive it from source. Add a proof-relevant field and theorem `arrayCapacityMatchesSource`. Add negative tests where metadata capacity differs from source length.

### F-06 — High: Solidity type subset and integer semantics are not enforced tightly enough

**Evidence.** The docs say accepted integers are `uint256`, while runtime values use `Value::Uint(u128)` and docs acknowledge bounded `u128` execution. The compiler accepts `pt::Type::Uint(bits)` for any bit width and `Type::canonical_len()` uses 32 bytes for all uint widths. There is no obvious type-soundness theorem linking Solidity’s type system to the IR; the lowerer appears more syntax-directed than type-checked.

**Impact.** The accepted language may include `uint8`, `uint64`, etc., but execute them under `u128`/32-byte canonical semantics. That is not Solidity semantics and could create accidental proof/source divergence. Even for `uint256`, overflow and literal handling are `u128`-bounded, not Solidity `uint256`-bounded.

**Path to reduce/eliminate.** Pick one of two options:

1. Rename and enforce the subset as `uint128`/bounded-`u128` source language, rejecting every other `uintN` including `uint256`; or
2. Implement full `uint256` arithmetic and prove canonical ABI/runtime agreement.

Either path needs a typed IR, a source type-checker or parser type-resolution certificate, and theorems that lowering preserves types and arithmetic semantics.

### F-07 — High: JSON/imported-object parsing is a large proof-grade bridge

**Evidence.** The proof-grade route consumes many JSON objects: translation bundles, runtime controller certificates, hidden ORAM certificates, kernel DSL bundles, shell/refinement witnesses, fresh-coin witness families, and Path ORAM certificates. The docs correctly say runtime extraction/serialization remains trusted, but the amount of trusted JSON schema/serialization behavior is large and often separate from the semantic theorem statements.

**Impact.** If a field is omitted from a proof-relevant schema, defaulted unexpectedly, parsed under a different interpretation, or canonicalized differently by Rust and Lean, the proof can accept the wrong object. F-01/F-02 are concrete examples.

**Path to reduce/eliminate.** Generate JSON schemas from one source of truth, preferably from Lean or from a shared declarative schema. Use canonical JSON with mandatory fields for proof-grade objects. Hash every canonical proof object and include those hashes in parent objects. Add “field coverage” tests that mutate/delete every field and assert whether the change must be accepted, rejected, or ignored by documented projection.

### F-08 — High: Resource/failure channels need a stronger closure theorem

**Evidence.** The runtime audit surface enumerates host-visible outcomes: success, abort, public runtime error, proof checker failure, commit/rollback, cryptographic integrity failure. Resource fields such as arena bytes, stack words, max hash-part bytes, max commit ops, and gas budgets are proof-relevant. The validation artifacts include many runtime boundary checks, but I did not find a single theorem tying every real host-visible error/status/payload path to public inputs and declared policies.

**Impact.** Update-obliviousness can fail through a secret-dependent error, budget exhaustion, malformed witness path, stash failure, allocation failure, encoding failure, or rollback/commit failure even if storage traces are oblivious. The docs intend to normalize these, but the theorem should make the closure explicit.

**Path to reduce/eliminate.** Add an end-to-end theorem of the form: for all admitted `(P,M)`, all host-visible outcomes belong to the closed taxonomy, and any non-negligible non-integrity failure is a function only of public inputs, public state shape, public manifest/config, and declared declassification policy. Include resource budget exhaustion and all Rust `Result`/panic-like boundaries in the proof object or source-generated runtime.

### F-09 — Potential high: Confidential entrypoints are blocked from raw backends, but not obviously from non-confidential UO objects

**Evidence.** `ensure_confidential_slot_program_uses_uo_backends()` rejects only `BackendKind::Raw`. It does not also require `object.confidential == true`. The Lean/translation checker also has checks for “confidential state objects use raw backends,” but the issue here is different: a confidential entrypoint could target a full-scan or ORAM object whose metadata says `confidential: false`.

**Impact.** This may be harmless if all UO backends are treated as sealed/secret regardless of the `confidential` flag. But if `confidential: false` affects public storage exposure, initialization, tracing, or host-readable state, then a secret flow into a non-confidential UO object is a leak. I did not confirm the runtime semantics enough to mark this as definitely exploitable.

**Path to reduce/eliminate.** Either prove that backend choice, not `confidential`, determines secrecy of stored values, or strengthen the compiler/checker rule: confidential entrypoints may only read/write state objects marked confidential, except for explicitly modeled public-declassified writes. Add a value-flow theorem for public state writes.

### F-10 — Medium/high: Top-level Solidity constructs are silently ignored outside the selected contract

**Evidence.** `parse_frontend()` finds the first contract definition matching `metadata.contract` and ignores all other `SourceUnitPart`s. It rejects unsupported constructs inside that contract, but top-level imports/pragmas/libraries/other contracts are not obviously rejected.

**Impact.** Since parser/preprocessing equivalence is already trusted, this is not the main proof root. Still, silent ignoring of top-level source content widens the front-end trust boundary and makes the admitted source language less crisp.

**Path to reduce/eliminate.** In proof-grade mode, reject any top-level source-unit part other than an allowed pragma and the single selected contract. Alternatively, include all top-level constructs in a raw-source admission witness.

### F-11 — Medium: Sidecar `key`/`value` declarations appear not fully checked against Solidity declarations

**Evidence.** `StateMetadata` includes `key` and `value`, and example YAML uses them. But `lower_state_object()` derives key/value types from the Solidity declaration and does not appear to validate that metadata `key`/`value` match the source declaration.

**Impact.** This may not directly affect proof semantics if the source declaration is authoritative, but it can mislead users and reviewers. It also undermines the idea that the sidecar is a precise spec package.

**Path to reduce/eliminate.** Reject mismatches between sidecar `key`/`value` and source types, or remove those fields from metadata if they are only documentation. Include type metadata in the proof-relevant package hash.

### F-12 — Medium: Map logical semantics need explicit finite-map refinement theorems

**Evidence.** The docs explain state-map lowering through sidecars and finite capacities. Path ORAM proofs focus on schedule/storage leakage; exact/full-scan proofs focus on update-oblivious access patterns.

**Impact.** A UO map must also refine the intended finite map semantics: default-zero behavior, equality of keys, duplicate key behavior, deletion/clear semantics, capacity full behavior, and hash/key encoding. Without this theorem, the toolchain can prove an oblivious program that computes the wrong map.

**Path to reduce/eliminate.** Add a theorem family: raw map semantics, full-scan map semantics, and Path ORAM logical map semantics all refine the same finite-map specification for the supported key/value types and capacity discipline. Add differential tests against a simple reference map.

### F-13 — Medium: Adaptive history exists, but persistent-state/history theorem should be elevated

**Evidence.** `HistorySemantics.lean` defines adaptive host strategies and public transcripts, and several runtime/ORAM modules use witness-family public-outcome equivalences. The strongest paper-facing theorem I found is still largely single-call or bundle-based, with history support expressed separately.

**Impact.** The practical claim for contracts is usually multi-call, with persistent sealed state, abort/rollback behavior, fresh ORAM remappings, nonces, and adaptive public inputs chosen from prior observations.

**Path to reduce/eliminate.** State a paper-level theorem for arbitrary finite adaptive histories: if two initial secret states are public-equivalent and the adversary chooses calls from the public transcript, then the full host transcript distribution is identical/exact or computationally indistinguishable under the backend assumptions. Include persistent state, rollback, fresh coins, and nonce uniqueness.

### F-14 — Medium: Randomness, nonces, and AEAD lifecycle need concrete runtime binding

**Evidence.** The Lean fresh-coin and Path ORAM witness-family checks are substantial. The claim boundary also lists AEAD assumptions. What remains is the concrete source of entropy/nonces and how uniqueness/freshness is guaranteed across runtime calls, crashes, rollback, and replays.

**Impact.** IND-CPA and ORAM freshness assumptions are only useful if concrete nonce/seed discipline satisfies their preconditions.

**Path to reduce/eliminate.** Add a runtime RNG/nonce/seed discipline document and proof object: per-call seed source, domain separation, counter persistence, crash recovery, replay resistance, and AEAD nonce uniqueness. Bind it to SGX monotonic/freshness assumptions where needed.

### F-15 — Medium: Static-drift checks are useful but should be converted to hash-bound proof inputs where possible

**Evidence.** The docs classify many runtime implementation boundaries as source-frozen/static-drift checked, not semantic Rust refinement. The committed results show large validation surfaces and static checks.

**Impact.** Static-drift checks reduce but do not eliminate trust in the source snapshot and checker/probe. They are especially fragile when generated helper code and handwritten shell code interact.

**Path to reduce/eliminate.** For each static boundary, either make the runtime code generated from a Lean/imported spec, or import a canonical source digest into the Lean proof object and theorem statement. Treat drift checks as proof inputs with auditable hashes, not only as CI reports.

### F-16 — Medium: Build/dependency reproducibility is not tight enough for a proof-grade artifact

**Evidence.** `proof/lean/lean-toolchain` pins Lean to `leanprover/lean4:v4.30.0-rc2`. I did not find an equivalent top-level Rust toolchain pin. Runtime trust includes Rust crates, generated source, crypto crates, parser crates, and checker binaries.

**Impact.** A reviewer or CI runner could rebuild with different Rust versions or dependency resolution, changing behavior below the proof boundary.

**Path to reduce/eliminate.** Add `rust-toolchain.toml`, vendored or audited dependencies, `Cargo.lock` enforcement, SBOM, reproducible Docker/Nix/devcontainer, and a signed release manifest containing source/proof/result hashes.

## Task 2 — Theorem framing: correctness and completeness

### What is strong

- The proof-grade root is separated from legacy axioms. `CheckProofGradeAxiomReport.lean` pins the axiom dependency closure for named paper-facing theorems to Lean’s standard logical axioms (`propext`, `Classical.choice`, `Quot.sound`) and excludes the legacy ORAM/SGX demonstration axioms.
- The repository has a broad proof/checker matrix: compiler exactness, source/IR/kernel lowering, exact UO composition, Path ORAM witness/certificate routes, runtime trusted-kernel bundles, shell/refinement boundaries, fresh-coin families, canonical Path ORAM pair checks, and static audit surfaces.
- The docs honestly distinguish Lean-proved, generated-and-checked, source-frozen/static-drift, empirical, and trusted claims.

### The main theorem-framing corrections

1. **Restate the theorem over a package, not a source program.** The theorem should say: for every admitted package `(Solidity source P, sidecar metadata M, compiler/runtime/checker/model versions V)` that compiles to artifact `A` and whose proof objects validate, the claimed observer relation holds. A source-only theorem is under-specified.

2. **Use a policy-aware observer in Lean.** The public outcome in the theorem should include the same fields as `docs/claim-boundary.md` and Rust `PublicOutcomeTrace`, or the prose claim must be weakened to match Lean’s current `SGXPublicOutcome`.

3. **Separate “accepted artifact is well-formed” from “real host-visible execution is UO.”** Many theorem/checker routes prove imported objects are internally consistent. That is valuable, but the paper theorem should clearly identify which facts are model theorems, which are imported-object validation theorems, and which are trusted extraction/static-drift assumptions.

4. **Promote history-level UO.** Contract users care about sequences of calls, not isolated calls. The repository has history definitions, but the headline theorem should quantify over adaptive finite histories and persistent state.

### Missing or weak theorem families

- Policy exactness and declassification soundness theorem.
- Source+metadata package hash binding theorem.
- Strict admission theorem for the raw source/sidecar subset, including no ignored top-level constructs.
- Type soundness and integer-width theorem.
- Array capacity/source length consistency theorem.
- Logical map refinement theorem across raw/full-scan/ORAM backends.
- Abort/rollback/status theorem, including no plaintext return on abort.
- Host-visible error/resource closure theorem.
- Adaptive multi-call theorem with persistent state, rollback, fresh coins, and nonce freshness.
- Runtime witness extraction/transcript authenticity theorem.
- Concrete Keccak/ABI encoding theorem if source-level Solidity semantics are retained.
- Path ORAM external theorem import or a clearly stated machine-checkable assumption interface.

## Task 3 — Practicality judgment

### Overall practicality

As currently framed, the toolchain is best understood as a research-grade, proof-aware confidential-contract DSL using Solidity syntax and sidecar metadata, executed by an in-process/TEE-oriented runtime. It is not yet a practical “compile arbitrary Solidity contract to public-chain EVM bytecode” system. The docs mostly acknowledge this, but the README/paper wording should avoid allowing readers to infer ordinary Solidity deployment compatibility.

The restrictions intentionally chosen for tractability are reasonable for a research artifact. The unintended restrictions and usability hazards are more concerning: sidecar verbosity/defaults, limited integer semantics, lack of dynamic data, literal loop bounds for confidential loops, no external calls/events/errors/constructors/modifiers/inheritance, no encrypted return channel, and heavy proof-object/runtime overhead.

### Practical blockers and opportunities

1. **Source semantics mismatch.** The `uint256` vs `u128` gap and possible `uintN` acceptance need to be fixed or renamed. This is both a theorem and usability issue.

2. **Sidecar ergonomics.** Users must hand-write capacities, confidentiality, policies, secret args, and budgets. Build a sidecar linter/inference tool that proposes metadata, explains every public leak, and refuses silent defaults in proof-grade mode.

3. **Deployment model clarity.** Document a concrete deployment path: local runtime, SGX enclave, attestation flow, sealed-state storage, client API, return decryption/declassification, crash recovery. If not implemented, explicitly label it as modeled.

4. **Performance transparency.** `results/reviewer_summary.md` shows large materialized artifacts and enormous estimated artifacts for some Path ORAM certificates. Add a capacity planner and show practical maximums for maps, calls, proof-object sizes, and runtime cost.

5. **Benchmark diversity.** Current benchmarks include useful examples such as `ConfidentialMixer`, `ERC20Lite`, `RegistryCRUD`, `AuthScan`, and Path ORAM variants. Add negative and realistic workloads: failed transfers, full maps, repeated deletes/updates, mixed public/confidential entrypoints, abort-heavy cases, and larger histories.

6. **Error messages and UX.** The compiler rejects many unsupported constructs. Make this user-friendly with a machine-readable rejection reason, source span, and suggested rewrite. Consider SARIF/JSON diagnostics.

7. **Containerized reproducibility.** A single Docker/Nix/devcontainer should run Rust tests, Lean builds, probes, benchmarks, and report generation. This is essential for outside reviewers.

8. **Claim label.** Consider branding as “UO-Solidity subset / verified UO contract DSL” rather than a general Solidity toolchain until raw-source semantics, ABI, deployment, and public-chain/EVM compatibility are much stronger.

## Task 4 — Evaluation plan overview

The detailed runbook is in `03_evaluation_plan_runbook.md` and the executable shell outline is in `04_local_agent_runbook.sh`. The plan has six layers:

1. Reproducibility and environment capture.
2. Proof-grade build/axiom/import-surface verification.
3. Compiler and checker positive/negative suites.
4. Targeted mutation tests, especially policy/manifest tampering.
5. Runtime/proof-object validation, replay, and witness-family checks.
6. Practicality benchmarking: throughput, proof-object size, overhead, capacity scaling, and UX rejection corpus.

The highest-priority new evaluation is a policy tamper suite: mutate `returns`, `status`, `declassifies`, and return payload fields while holding proof-relevant schedules constant. Today, those mutations should be expected to reveal whether the proof-grade Lean route is policy-aware. After the proposed fixes, every such mutation must either be rejected by Lean or be accepted only when the theorem explicitly projects the field away and the prose claim excludes it from the observer.
