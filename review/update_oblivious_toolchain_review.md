# Review of the Update-Oblivious Toolchain Bundle

Date of review: 2026-04-29  
Reviewed archive: `update-oblivious-toolchain-main.zip`

## Scope and caveats

I reviewed the repository documents, Rust sources, Lean sources, benchmark artifacts, validation scripts, and committed validation results. I did not re-run the validation suite inside this environment because Rust/Cargo and Lean/Lake are not installed here. The repository itself pins Rust in `rust-toolchain.toml` and Lean in `proof/lean/lean-toolchain`; `scripts/run_validation.sh` requires both. The conclusions below are therefore based on source/document inspection and the checked-in `results/` bundle, not on an independently reproduced local proof run.

I treated the following as already-known documented boundaries rather than new findings: parser/preprocessing trust, lack of deeper Rust semantic refinement below checked source-backed boundaries, citation of the external Path ORAM theorem rather than importing a machine-checked external theorem, the Lean kernel/foundation, and the mock-hash vs real-Keccak gap. I still mention them when they interact with a new gap.

Quick proof-inventory facts from the checked-in Lean tree:

- Lean files inspected: 175.
- Parsed Lean declarations in `proof/lean`: 6,353.
- Parsed theorem/lemma declarations: 3,682.
- `sorry` / `admit`: none found.
- Declared `axiom`s: two legacy demonstration axioms, `legacyOramLocalTheorem` and `legacySgxMicroLocalTheorem`, in `UOToolchain/OramGame.lean` and `UOToolchain/SgxMicroGame.lean`. `UOToolchain/ProofGradeRoot.lean` explicitly excludes these legacy modules from the proof-grade root.
- The largest theorem/lemma concentrations are in `RuntimeImplementationInterface.lean` (851), `RuntimeImplementationInterfaceJson.lean` (453), proof-grade runtime implementation boundary checkers, `RuntimeOramHelperSemantics.lean`, and `ProofGrade.lean`.

The accompanying CSV files in this bundle provide a declaration inventory and summary.

## Executive judgment

The project is unusually explicit about its claim boundary and has a large, serious proof/checker surface. The intended idea of update-oblivious programming is well framed: the observable update schedule, storage trace, and normalized TEE trace should not vary with hidden updates except through declared public/declassified channels.

The main concern is that the current theorem framing appears too narrow for the full confidentiality story: the compiler checks return/status declassification, but persistent public-state writes are not treated as a declassification channel, and the central operational evaluator discards the final updated configuration. This creates a path to “proving the wrong thing”: a call can have identical observed trace/return/status while storing secret-derived data into public state, which is then observed later.

The second major concern is practicality. The theorem-facing Path ORAM backend has a local position-map wrapper that scans encrypted metadata pages in a fixed shape. In the implementation, `metadata_pages_per_access = metadata_pages + 1` and `metadata_pages = ceil(capacity/8) + ceil(stash_bound/8)`, with `stash_bound = max(capacity, 1)`. That makes metadata I/O approximately linear in capacity, even before the logarithmic bucket path. The committed validation bundle also reports very large proof artifacts: a 196 MB materialized canonical Path ORAM pair certificate, a 98 MB fresh-coin witness family, and estimated certificate sizes up to about `7.08e18` bytes.

My recommendation is to keep the proof architecture, but prioritize three changes before positioning the toolchain as adoptable beyond research prototypes: add public-state/declassification history theorems, fail-closed admission for proof-grade control-flow shape, and replace large enumerated proof families / local-posmap scans with compact or recursive mechanisms.

---

# 1. Unintended trust boundaries and assumptions

## T1. Persistent public-state writes are not modeled as declassification

**Severity: Critical**

The documentation states that the theorem is against a hostile-host observer and declared return/status declassification policy (`docs/claim-boundary.md:7-18`). The compiler policy pass checks return values and success/abort status (`compiler/uo-solc/src/lib.rs:1870-1927`). It taints locals derived from secret arguments or confidential state, then rejects sensitive public returns/status. However, `collect_policy_sensitivity` ignores all state writes:

- `Statement::CellSet { .. } | Statement::ArraySet { .. } | Statement::MapPut { .. } => {}` at `compiler/uo-solc/src/lib.rs:2031-2034`.

In Lean, the operational evaluator threads store updates during execution, but `evalContract` discards the final updated `OperationalConfig` and returns only `Outcome` (`proof/lean/UOToolchain/IRSemantics.lean:810-825`). `Outcome` includes trace, public result, ORAM counts, kernel steps, and status, but no final public state (`IRSemantics.lean:277-299`). The abstract public projection includes the *initial* public state (`IRSemantics.lean:64-76`), not post-state history.

This is an unintended trust assumption: it assumes public persistent state is either not observable, not confidentiality-relevant, or already covered by return/status declassification. In a smart-contract-like setting, public state is normally observable, and the repository also supports public getter/setup entrypoints (`docs/supported-subset.md:16`). A public entrypoint can read confidential state through `lower_expr` (`compiler/uo-solc/src/lib.rs:632-636`, `699-711`) and, if it does not return it or branch status on it, can write secret-derived data into a public object without the current return/status policy catching it.

**Why this matters:** A pair of runs can have equal current theorem observations while leaving different public persistent states. A later public getter can reveal the secret. That is a classic history noninterference gap.

**Path to reduce/eliminate the assumption:**

1. Extend metadata with public-state declassification, for example `declassifies: [return, success, public_state:<object>]` or a per-state `write_policy`.
2. Extend the compiler taint pass:
   - For `CellSet`, `ArraySet`, and `MapPut`, compute whether the target object is public.
   - If the target is public and the value, key/index, or write predicate is policy-sensitive, reject unless the entrypoint explicitly declassifies that public state effect.
   - Treat a secret-dependent predicate controlling a public write as a public-state declassification even when the value is public.
3. Extend Lean `Outcome` or introduce `HistoryOutcome` with `finalPublicState` or `publicStateDelta`.
4. State and prove an end-to-end theorem over histories:

   ```text
   samePublicProjection c1 c2
   ∧ sameDeclaredDeclassifications c1 c2
   ⇒ View(c1) = View(c2)
      ∧ finalPublicProjection(c1) = finalPublicProjection(c2)
      modulo explicitly declassified public-state effects
   ```

5. Add negative tests that compile contracts attempting `publicCell = confidentialCell` with no declassification and expect rejection.

## T2. Loop-bound admission is weaker than the documented proof-grade subset

**Severity: High**

The supported subset documents bounded loops of the form `for (uint i = 0; i < N; i++)` (`docs/supported-subset.md:11`). The compiler requires the syntactic shape `i < <expr>` but does not require `<expr>` to be a literal or a compile-time public constant in `lower_for_bound` (`compiler/uo-solc/src/lib.rs:950-963`). The ORAM access counter rejects dynamic loop counts only if the body contains ORAM accesses (`compiler/uo-solc/src/lib.rs:1530-1558`). Confidential linearization later requires constant bounds (`compiler/uo-solc/src/lib.rs:2176-2191`), but public/non-ORAM loops can remain dynamic.

This leaves a gap between the documented admitted language, theorem assumptions about fixed public schedules, and actual compiler admission. A state-dependent or secret-derived loop bound in a public path can affect gas, execution time, public trace length, or resource behavior. Even if not in the confidential kernel, the paper claim talks about real host-visible execution and modeled public gas.

**Path to reduce/eliminate the assumption:**

- In proof-grade mode, fail closed unless every loop start/end evaluates under `eval_loop_bound` with an empty public compile-time environment.
- Alternatively, add a `loop_bounds` sidecar section that declares public loop bounds and prove that the IR bound expression is extensionally equal to the declared public bound.
- Make `count_body` and manifest gas/schedule accounting reject unknown loop trip counts for all statements, not just ORAM-accessing loops.
- Add a Lean admission theorem: every admitted confidential/public proof-grade function has control-flow shape determined by the public projection.

## T3. Sidecar confidentiality policy is not a single fail-closed authority

**Severity: High**

The docs say public entrypoints must say `confidential: false`, confidential entrypoints must say `confidential: true`, and confidential entrypoints must declare `secret_args` (`docs/supported-subset.md:37-50`). In implementation, however, an entrypoint becomes confidential in UO mode if either the sidecar says it is confidential or `secret_args` is non-empty:

```rust
let confidential = matches!(mode, ProgramMode::Uo)
    && (entrypoint_confidential || !entry_meta.secret_args.is_empty());
```

at `compiler/uo-solc/src/lib.rs:385-386`.

That is a reasonable convenience during development, but it is not fail-closed: a sidecar can say `confidential: false` and still create a confidential compiled function because `secret_args` is present. Also, public entrypoints can reference confidential state; the return/status taint pass may reject direct returns/status leaks, but, as noted in T1, does not reject public-state writes.

**Path to reduce/eliminate the assumption:**

- Add `MetadataWellFormed` and enforce it before lowering:
  - `secret_args.is_empty()` iff `confidential == false`.
  - `secret_args.nonempty()` implies `confidential == true`.
  - A public entrypoint may not read or write confidential state unless it declares an explicit declassification policy for the exact channel.
  - In UO mode, any `confidential:true` state object must use a theorem-backed non-raw backend globally, not only when reached by a confidential slot program.
- Mirror this metadata well-formedness predicate in Lean and include it in the paper theorem hypotheses.
- Add sidecar inconsistency tests that must fail compilation.

## T4. Proof-relevant view completeness is not itself proved

**Severity: High**

`ProofRelevantContractView` is substantial and includes state, functions, manifest objects, entrypoints, kernel steps, ORAM accesses, policies, and confidential programs (`crates/uo-core/src/translation_validation.rs:76-390`). The source/artifact equality check requires `source_view == artifact_view` and matching admitted package identity (`translation_validation.rs:69-73`).

The gap is not that the view is small; it is that I did not find a theorem or generated check proving that every runtime-consumed field is included in this view, or that the runtime consumes only this view. If a runtime-relevant artifact field is omitted from `ProofRelevantContractView`, Lean may prove equality of the serialized proof-relevant views while the actual runtime behavior depends on an unchecked field.

**Path to reduce/eliminate the assumption:**

- Make the proof-relevant view the canonical runtime manifest, or generate the runtime manifest from the proof-relevant view.
- Add a field-completeness checker that enumerates every field of `CompiledArtifact`, `CompiledContract`, `RuntimeManifest`, and `EntrypointManifest` and classifies it as proof-relevant, public-only, debug-only, or rejected.
- Add mutation tests that flip/delete every serialized artifact/manifest field and assert either checker rejection or a documented proof-irrelevant classification.
- State a Lean theorem along the lines of: if two artifacts have equal proof-relevant views and satisfy `ArtifactWellFormed`, then the runtime-facing observer is equal for all admitted executions.

## T5. Runtime proof-object extraction completeness is a concrete remaining trust boundary

**Severity: High**

The docs already identify the Rust runtime kernel plus witness/certificate/bundle extraction and serialization as trusted (`docs/claim-boundary.md:81-92`). The subtle version worth isolating is transcript completeness: Lean validates proof objects and certificates, but the proof object producer is the implementation that executed the code. Static-drift checks reduce source drift, but they do not by themselves prove that every real storage/boundary/micro event was captured in the emitted proof object.

**Path to reduce/eliminate the assumption:**

- Introduce a typed, append-only kernel transcript at the lowest checked operation boundary.
- Maintain a public transcript hash accumulator. Every storage write/read, boundary event, ORAM path access, and public outcome update appends a typed event.
- Derive proof objects from this transcript only; Lean replays or checks certificates against the transcript hash and event list.
- Keep witness extraction as a parser of an already-bound transcript rather than as an independent source of truth.
- Add tamper tests that insert, omit, reorder, or rewrite transcript events and require Lean rejection.

This would not prove Rust semantics, but it would reduce the extraction trust from “the runtime reported what happened” to “the runtime maintained a checked event log at the trusted operation boundary.”

## T6. Operational-state well-formedness should be explicit

**Severity: Medium**

The Lean operational semantics chooses the write store from the object confidentiality flag (`IRSemantics.lean:553-569`), but `readObject` gives public-store entries precedence and then falls back to secret store (`IRSemantics.lean:571-577`). Unknown objects default to non-confidential/public (`IRSemantics.lean:553-560`). Comments say malformed programs would already be rejected (`IRSemantics.lean:547-551`), and runtime deployment checks duplicate committed object IDs (`runtime/uo-evm/src/state.rs:357-381`), but the theorem framing should carry this explicitly.

**Path to reduce/eliminate the assumption:**

- Define `WellFormedConfig` in Lean: unique state object IDs, every referenced object exists, public and secret stores are disjoint according to the object map, every store entry has the declared type/container shape, and no duplicate public/secret ownership exists.
- Prove deployment creates `WellFormedConfig` and every statement preserves it.
- Make all evaluator exactness/declassification theorems require or derive `WellFormedConfig`.
- Change `readObject` to consult the object confidentiality map first, not public-store precedence, under a well-formedness proof.

## T7. Randomness, nonce uniqueness, and diagnostic seeding need a harder production boundary

**Severity: Medium**

The runtime uses `ChaCha20Poly1305` for sealed records and draws a 96-bit nonce from a `ChaCha20Rng` in `seal_and_wipe_into_slice` (`runtime/uo-store/src/generated_surface.rs:155-176`). Deployment uses `OsRng.next_u64()` as a deploy seed and has `deploy_with_seed` for deterministic replay (`runtime/uo-evm/src/engine.rs:36-48`). Object states clone RNG state across transaction clones (`runtime/uo-evm/src/objects.rs:85-94`, `164-173`), and diagnostic fresh-coin injection exists behind diagnostics features.

The docs and static drift inventory include a freshness discipline, but the cryptographic assumptions ultimately require nonce/freshness conditions. I did not find a machine-checked theorem that production nonce streams are unique/domain-separated and that diagnostic seed/fresh-coin injection cannot enter production builds.

**Path to reduce/eliminate the assumption:**

- Replace random AEAD nonces with per-object/per-slot/per-commit domain-separated monotonic nonces where possible, or prove a concrete probabilistic collision bound for the current RNG design.
- Include object ID, storage slot, epoch/call counter, and write counter in nonce derivation or AAD.
- Separate diagnostic seeded execution and production execution at the type/API level.
- Add CI gates that production feature sets cannot call `deploy_with_seed` or diagnostic fresh-coin injection.
- State the nonce/freshness discipline as a theorem or explicit assumption with a concrete bound.

## T8. “Real host-visible execution” should be narrowed or refined

**Severity: Medium**

`docs/claim-boundary.md:7-18` uses “real host-visible execution,” while the observer section later defines a normalized/simulated SGX micro trace and explicitly excludes raw page identities and full micro-event equality (`docs/claim-boundary.md:39-61`). Non-claims also exclude page-fault, timing, cache, allocator, scheduler, power, EM, and wall-clock obliviousness (`docs/claim-boundary.md:94-105`).

The documentation is transparent, but the headline theorem wording could still be overread. For an SGX adopter, raw page faults and timing are host-visible.

**Path to reduce/eliminate the assumption:**

- Rename the theorem target to “normalized hostile-host observer” rather than “real host-visible execution,” unless raw-host refinement is added.
- If the stronger claim is desired, add a raw-to-normalized observer refinement: raw page/event/timing traces must either be proven independent of secrets or explicitly excluded from the adoption claim.

## T9. Abort/rollback and final persistent state need a history theorem

**Severity: Medium**

The docs and result summaries discuss success/abort, commit/rollback, and host-visible outcome taxonomies. The central evaluator, however, returns `Outcome` and discards final state (`IRSemantics.lean:810-825`). Without a theorem that aborted executions leave no secret-dependent persistent public effects, rollback behavior remains partly outside the theorem statement.

**Path to reduce/eliminate the assumption:**

- Define single-call and multi-call history semantics with pre-state, post-state, commit/rollback outcome, and public-state deltas.
- Prove that completed and aborted calls have identical public persistent effects under same public inputs, modulo declared declassification.
- Include this history theorem in the paper-facing theorem chain.

## T10. Capacity edge cases should be rejected or proved

**Severity: Low/Medium**

ORAM manifests use `capacity.max(1)` or `capacity.max(2)` in several places (`crates/uo-core/src/manifest.rs:213-235`). This makes zero-capacity maps silently become nonzero-sized storage/theorem shapes. That may be safe, but it should either be intentional and proved, or rejected as invalid sidecar metadata.

**Path to reduce/eliminate the assumption:** reject `capacity == 0` for map/array state unless a dedicated empty-container theorem is added.

---

# 2. Correctness and completeness of theorem framing

## What is strong and well framed

The proof organization is not superficial. The following theorem families are meaningful and directionally aligned with the update-oblivious idea:

1. **Abstract exact-UO and composition.** `ExactUO` is trace equality under the same public projection (`ExactObjects.lean:8-9`). `exactUO_append` and `exactUO_compose` compose exact-UO trace producers (`ExactObjects.lean:32-48`). `compositionTheorem` adds a public gas budget over composed exact runs (`Composition.lean:33-38`).
2. **Operational IR and preservation.** The Lean IR has an evaluator with explicit status, trace, public result, kernel steps, and ORAM counts. Arithmetic is modeled in the `uint256` domain, including division/modulo by zero returning zero (`IRSemantics.lean:337-385`).
3. **Compiler/runtime bridge.** The proof-relevant translation bundle and JSON checkers are extensive, and the source/artifact equality route is explicit.
4. **Runtime implementation boundaries.** The runtime boundary theorem/checker files are large and numerous. They cover kernel/interface/refinement/confinement, generated helper semantics, slot adapter boundaries, shared kernel routes, and public-bridge observer refinement.
5. **Path ORAM theorem route.** The docs clearly distinguish the paper citation route from the artifact/executable route (`docs/path-oram.md:6-22`) and bind the theorem-facing backend to `path_oram_local_posmap_v1`.
6. **SGX/TEE observer boundary.** The observer is explicit and the non-claims are well documented.

## Theorem inventory summary

A full CSV inventory is included in this bundle. Coarsely, theorem families include:

- `TraceModel`, `IRSyntax`, `IRSemantics`: public projections, evaluator definitions, arithmetic/value semantics.
- `ExactObjects`, `Composition`, `CompilerInvariant`, `CompilerExactness`, `TranslationValidationJson`: exact-UO, gas safety, compiler/source/artifact views.
- `PathOram*`, `RuntimeCoins*`, `RuntimePaperInstantiation`, `PaperPathOramTheoremRoute`: computational-UO and Path ORAM bridge.
- `RuntimeRefinement*`, `RuntimeTrustedKernel*`, `RuntimeShellBoundary*`, `RuntimeImplementation*`: runtime witness, trusted kernel, implementation boundary/refinement/confinement.
- `RuntimeStore*`, `RuntimeOram*`, `RuntimeArray*`, `RuntimeValue*`, `RuntimeAllocator*`: generated/runtime helper semantics and discipline proofs.
- `Sgx*`, `TeeDeployment`, `SgxJointProjection`, `SgxExactProjection`, `SgxOramProjection`: TEE/SGX observer closure.
- `CheckProofGrade*`: executable checker entrypoints that import validation JSON/certificates and prove imported-bundle properties.

## Missing or weak theorem statements

### M1. End-to-end history noninterference with final public state

The main paper theorem should quantify over *call histories*, not only a single call’s current trace/outcome. It should include final public state or public-state deltas. Without this, T1 can leak through public storage and a later getter.

Suggested theorem shape:

```text
For any two well-formed initial histories H1,H2 with equal public projection,
for any admitted sequence of calls with equal public call projection,
if all declared declassification functions agree,
then the full normalized observer histories are equal and the final public states are equal,
modulo declared public-state/return/status declassifications.
```

### M2. Functional correctness including post-state

The toolchain should prove not only that traces are UO, but that UO execution implements the intended source semantics for state updates. The existing evaluator threads store updates internally but the main `Outcome` drops post-state. A functional theorem should relate source/IR/runtime final states modulo representation.

### M3. Declassification soundness theorem

Current policy checks are syntactic/taint-oriented. The paper theorem should state that every public/declassified output is a function only of public inputs and explicitly declared declassification expressions. Return/status labels are not enough; public-state effects and possibly event outputs should be included.

### M4. Admission theorem for the supported subset

The docs specify a subset, but code admission and theorem assumptions do not fully line up for loops and public-state references. A theorem/check should say that every accepted artifact satisfies the fragment predicates needed by the proof: fixed public control-flow shape, no early confidential returns, known object universe, well-formed metadata, theorem-backed backends for confidential state, and valid capacities.

### M5. Artifact/view completeness theorem

Equality of `ProofRelevantContractView` is useful, but the key theorem should show that all runtime-observable behavior is determined by the proof-relevant view under well-formedness assumptions. Otherwise omitted fields can become a hidden trust boundary.

### M6. Deployment identity theorem

The admitted-package hash binds source bytes, canonical metadata, mode, compiler version, and schema (`docs/claim-boundary.md:24-28`). It is explicitly not a runtime binary/SGX quote hash. For deployment, add a theorem/check that the artifact accepted by Lean is the artifact loaded into the attested runtime and that the runtime binary matches the checked implementation boundary.

### M7. Runtime event-transcript completeness theorem

A theorem should state that the public witness/proof object is a faithful projection of the actual runtime event transcript. Without a transcript hash and replay theorem, the proof-object extractor remains too central.

### M8. ORAM failure/overflow observation theorem

`stashOverflowBounded` is an explicit assumption. The theorem should also state what happens on overflow/failure: whether failure is impossible under the assumption, whether it is a public abort, and whether it can leak secret-dependent information through timing/status/storage effects.

### M9. Production randomness/freshness theorem

The proof route includes fresh leaf remapping and IND-CPA assumptions. Add a concrete runtime theorem or explicit bounded assumption about nonce uniqueness, fresh leaf generation, and absence of diagnostic injected coins in production mode.

### M10. Raw-host observer refinement or narrowed statement

The theorem should either remain explicitly normalized or include a refinement from real raw host observations to the normalized observer. The current docs have the right non-claims, but the headline theorem wording should avoid accidental overclaiming.

### M11. Quantitative resource-bound theorem

`compositionGasTheorem` overwrites modeled gas with a public budget, but adoption requires stronger concrete bounds: runtime latency, memory, storage bytes, proof-object size, and checker time as public functions of capacities and manifest parameters. At minimum, add theorem-facing/public formulas for expected cost and a CI check that measured/probe costs match them within documented tolerance.

---

# 3. Practicality assessment

## Bottom line

The toolchain is practical as a research prototype and as a way to study update-oblivious kernels on small to moderate fixed-capacity workloads. It is not yet practical as a general confidential Solidity toolchain or as a scalable large-map private state system.

This is not mainly because the Solidity subset is restricted; the project intentionally restricts the language. The more serious practical blockers are proof/certificate growth, local-position-map metadata scans, lack of encrypted private returns, and missing public-state/history policy.

## Practicality blockers

### P1. Path ORAM local-posmap cost is effectively linear in capacity

For `path_oram_local_posmap_v1`, `OramManifest::for_object` computes:

- `stash_bound = capacity.max(1)`
- `position_map_pages = capacity.max(1).div_ceil(8)`
- `stash_pages = stash_bound.div_ceil(8)`
- `metadata_pages = position_map_pages + stash_pages`
- `metadata_pages_per_access = metadata_pages + 1`
- `buckets_per_access = tree_height + 1`

at `crates/uo-core/src/manifest.rs:213-235`.

Thus the metadata scan is about `capacity/4 + 1` pages per access for positive capacities, plus `O(log capacity)` buckets. This fixed-shape scan helps theorem/observer simplicity, but it undermines the usual asymptotic benefit of Path ORAM for large maps. For large private maps, this will likely dominate runtime and storage I/O.

### P2. Proof evidence growth is already large

The committed `results/reviewer_summary.md` reports:

- Total probe time: `2,138,372 ms` (about 35.6 minutes).
- `tamper_validation`: `862,645 ms`.
- `canonical_pathoram_pair_validation`: `206,627 ms`.
- `fresh_coin_validation`: `88,631 ms`.
- Largest materialized canonical pair certificate: `196,364,667` bytes.
- Largest materialized fresh-coin witness family: `98,177,403` bytes.
- Largest estimated certificate field: `7,079,693,798,601,654,272` bytes.

This is the strongest adoption warning in the current results. Even if runtime overhead is acceptable for some capacities, proof evidence and validation artifacts may not be.

### P3. Current performance evidence is too narrow

`results/overheads.json` contains one explicit overhead case: `ConfidentialMixer/deposit`, comparing full-scan capacity 64 and ORAM capacity 64. It reports full-scan gas `32768`, physical writes `65`, bytes written `12284`, and ORAM gas `12288`, physical writes `49`, bytes written `56520`. This is useful but insufficient to decide adoption.

The correctness and leakage reports cover more toy benchmarks, but a decision maker needs scaling curves over capacity, occupancy, call histories, abort rates, and backend choices.

### P4. No encrypted private return channel

The runtime rejects `encrypted_to_client` returns (`compiler/uo-solc/src/lib.rs:1881-1885`; docs also say this is gated). That means confidential calls cannot return secret payloads privately to an authorized client. They can return public/declassified values or no secret value. Many compelling confidential applications need private query results.

### P5. Not deployable as normal Solidity/EVM bytecode

The repository is an in-process runtime and theorem/proof-object toolchain, not a tool that emits deployable raw EVM bytecode with the same semantics. This may be acceptable for a TEE-hosted confidential service, but it changes the adoption target. Decision makers should evaluate it as a confidential runtime/toolchain, not as a drop-in Solidity compiler.

### P6. Common smart-contract patterns remain outside scope

Even if the restricted subset is intentional, many real scenarios need constructors/initialization, events, external calls, modifiers, dynamic arrays, multiple returns, and ABI integration. Some of these could be added safely with public-only or fixed-shape policies, but until then realistic use cases are limited to isolated kernels.

### P7. Capacity planning is a real cost

All private containers require public capacities. Overprovisioning hides occupancy but increases full-scan/metadata costs; underprovisioning causes functional limits and possible overflow/error behavior. This cost should be quantified per application.

### P8. TCB and operations cost are nontrivial

The committed reviewer summary reports:

- Trusted Rust runtime surface: 11,403 non-empty LOC.
- Outer runtime risk surface: 898 non-empty LOC.
- Lean theorem/checker repo surface: 103,091 non-empty LOC.

Additionally, production deployment depends on TEE attestation, rollback resistance, freshness, crash recovery, patch-level trust, and evidence retention. Those are operational costs, not just proof assumptions.

## Practicality opportunities

1. **Recursive or private position map.** Replace the local fixed metadata scan with recursive ORAM, private enclave-resident position maps, or compact metadata with a separately proved update-oblivious access pattern.
2. **Compact proof certificates.** Replace enumerated fresh-coin/canonical-pair families with symbolic parameterized certificates, proof-carrying seeds, streaming checks, or a small certificate plus a mechanized theorem.
3. **Encrypted return channel.** Implement attested session-key setup, nonce discipline, and a theorem that encrypted outputs are not plaintext declassifications.
4. **Public-state declassification policy.** Add a policy language for public state, event outputs, and persistent history.
5. **Batching and amortization.** Add fixed-public-batch map operations, batched ORAM paths, and amortized proof objects.
6. **Production/proof separation.** Separate deterministic replay/diagnostic seeded execution from production execution at the type/API and CI levels.
7. **Real workload kernels.** Add benchmarks that represent realistic private registries, private balances/allowances, membership, escrow, and map-heavy update patterns.
8. **Public-only external interaction.** A controlled subset of external/public calls and events could make the toolchain far more useful while preserving theorem-facing fixed shapes.

---

# 4. Evaluation plan and local coding-agent runbook

A standalone runbook is included as `evaluation_runbook.md`. The plan below summarizes the decision-oriented evaluation.

## Evaluation goals

The evaluation should answer:

1. Does the toolchain preserve update-obliviousness on the intended observer for realistic workloads?
2. What are the runtime costs versus raw/public, full-scan, and Path ORAM alternatives?
3. What are the proof/checking/artifact costs, and how do they scale with capacity?
4. What operational and developer costs does adoption impose?
5. Where is the practical capacity ceiling for each backend?

## Metrics to collect

### Security sanity metrics

- Trace equivalence pass/fail over paired same-public/different-secret runs.
- Mutual information for observable metrics; expected near 0 for UO modes.
- Leakage AUC for observable metrics; expected near 0.5 for UO modes.
- Negative tests: rejected secret-dependent public return/status/public-state writes unless declared declassified.
- Tamper tests: proof/artifact/certificate mutations rejected.

### Runtime metrics

- p50/p95/p99 wall-clock latency per call.
- CPU time and max RSS.
- Modeled gas.
- Physical reads/writes and bytes read/written.
- Normalized page events and boundary events.
- Controller phase count.
- Persistent storage footprint after deployment and after calls.
- Abort vs success cost.

### Proof/checker metrics

- Compilation time.
- Lean build time.
- Per-checker validation time.
- Artifact JSON size.
- Runtime witness size.
- Trusted-kernel/shell/refinement bundle size.
- Path ORAM certificate size, fresh-coin family size, and estimated size.
- Peak RSS for heavy proof/certificate modes.

### Adoption/operational cost metrics

- TCB LOC by category.
- Number of explicit assumptions required for an adoption claim.
- TEE setup/attestation time and quote size, once integrated.
- Rollback/freshness storage overhead.
- Evidence retention size per call and per day at target call volume.
- Sidecar metadata size relative to source LOC.
- Rejection rate over candidate real-world kernels.
- Capacity headroom ratio: public capacity / observed max occupancy.

## Benchmark matrix

Use current benchmarks as seeds:

- `FixedSlotClassifier`
- `AuthScan`
- `RegistryCRUD`
- `ConfidentialMixer`
- `ERC20Lite`
- `SingleAccessMap`

Add at least these new kernels:

- Private balance transfer with hidden balances and public/declassified success.
- Private allowance update/check.
- Private registry lookup/update with private keys.
- Membership/authentication scan.
- Mixer deposit/withdraw with hidden recipient state.
- Map-heavy update workload with multiple ORAM accesses per call.
- Abort-heavy workload where the abort condition is public vs declassified.

Run each over capacities:

```text
8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096
```

Use backends where applicable:

```text
raw-public baseline, full_scan, path_oram_local_posmap_v1
```

Use workload dimensions:

- Occupancy: 0%, 25%, 50%, 90%.
- Key distribution: uniform random, hot-key, sequential.
- Update type: insert, update existing, same-value update, no-op update.
- Call history length: 1, 10, 100, 1,000 calls.
- Abort rate: 0%, 10%, 50%.
- Secret pairs: same public inputs, different secret keys/values.

## Analysis to compute

For each benchmark/backend/capacity:

```text
latency_ratio = latency_uo / latency_raw_or_public_baseline
write_ratio   = physical_writes_uo / physical_writes_baseline
byte_ratio    = bytes_written_uo / bytes_written_baseline
proof_ratio   = proof_artifact_bytes / runtime_artifact_bytes
```

Fit scaling curves:

- Full-scan expected: roughly linear in capacity.
- Current Path ORAM local-posmap expected: roughly linear metadata scan plus logarithmic bucket path.
- Proof family/certificate sizes: detect exponential or superlinear growth.

Decision makers should see both absolute costs and ratios.

## Adoption gates

A decision maker can set concrete thresholds, for example:

- Security sanity: no UO metric has mutual information above `0.01` bits or AUC outside `[0.49, 0.51]` on paired tests.
- Runtime: p95 latency under the target service SLO at target capacity.
- Storage: bytes written per call and persistent footprint under the target infrastructure budget.
- Proof: validation completes inside CI/release budget; artifact/evidence retention fits storage budget.
- Practicality: capacity headroom ratio under a chosen maximum, e.g., `<= 4x`.
- Trust: no unresolved critical findings T1/T2/T3/T4/T5 for production use.

## Minimal local runbook

1. Install prerequisites:

   ```bash
   rustup toolchain install 1.82.0
   # install elan, then let proof/lean/lean-toolchain select leanprover/lean4:v4.30.0-rc2
   elan toolchain install leanprover/lean4:v4.30.0-rc2
   sudo apt-get install -y jq time hyperfine python3 python3-venv
   ```

2. Verify pinned toolchains:

   ```bash
   rustc --version
   cargo --version
   cd proof/lean && lake --version && lean --version && cd ../..
   cat rust-toolchain.toml
   cat proof/lean/lean-toolchain
   ```

3. Run baseline validation:

   ```bash
   ./scripts/run_validation.sh
   ./scripts/check_probe_reproducibility.sh --only static-checks
   ```

4. Archive baseline results:

   ```bash
   export RUN_ID="baseline-$(date -u +%Y%m%dT%H%M%SZ)"
   mkdir -p "eval/$RUN_ID"
   cp -a results "eval/$RUN_ID/results"
   jq '.proof_checking_cost_ms' results/reviewer_summary.json > "eval/$RUN_ID/proof_checking_cost_ms.json"
   jq '.artifact_size_bytes' results/reviewer_summary.json > "eval/$RUN_ID/artifact_size_bytes.json"
   jq '.runtime_overheads' results/reviewer_summary.json > "eval/$RUN_ID/runtime_overheads.json"
   ```

5. Generate capacity variants and compile them. A local coding agent should create `scripts/eval/generate_capacity_matrix.py` that copies existing YAML sidecars, patches each map/array `capacity`, and writes a manifest CSV. Then run `uo-solc` for each generated case.

6. Run runtime measurements. For each artifact/entrypoint/argument vector, run at least 30 repetitions after warmup:

   ```bash
   /usr/bin/time -v cargo run -q -p uo-evm -- \
     --artifact path/to/artifact.json \
     --entrypoint 'entry(uint256,bytes32)' \
     --format trace \
     > eval/$RUN_ID/traces/case-001.json 2> eval/$RUN_ID/time/case-001.txt
   ```

   If the CLI does not expose the needed argument vectors, add a small Rust or Python-driven harness around the `uo_evm` crate API rather than manually invoking one-off examples.

7. Run leakage/security sanity checks through `mplus-probe` for each matrix slice. Use the existing `mutual_information`, `leakage_auc`, and `trace_equivalence` result formats as the target schema.

8. Run proof-cost measurements:

   ```bash
   UO_RESULTS_DIR="eval/$RUN_ID/results-compact" ./scripts/run_validation.sh
   UO_RESULTS_DIR="eval/$RUN_ID/results-heavy" ./scripts/run_heavy_artifact.sh
   ```

   Use `UO_HEAVY_ARTIFACT_BUDGET_BYTES` to cap large runs on limited machines.

9. Summarize results with a script that emits:

   - `eval_summary.md`
   - `runtime_metrics.csv`
   - `proof_metrics.csv`
   - `artifact_sizes.csv`
   - `leakage_metrics.csv`
   - capacity-scaling plots

10. Produce an adoption scorecard:

   ```text
   Target app:
   Target capacity:
   p95 latency:
   bytes written/call:
   proof validation time:
   evidence size/call:
   leakage sanity:
   unresolved trust findings:
   recommendation: adopt / pilot / research only / reject
   ```

## Local coding-agent task list

A local coding agent can execute the full evaluation by implementing these concrete artifacts:

1. `scripts/eval/generate_capacity_matrix.py`: generate sidecars/artifacts for benchmark × backend × capacity.
2. `scripts/eval/run_runtime_matrix.py`: run each artifact with harness args, repetitions, and `/usr/bin/time -v`; write normalized JSON.
3. `scripts/eval/collect_probe_results.py`: parse `reviewer_summary.json`, `overheads.json`, `correctness.json`, `leakage_auc.json`, `mutual_information.json`, and trace-equivalence reports into CSV.
4. `scripts/eval/check_negative_policies.py`: compile negative examples for return/status/public-state leaks and assert rejection.
5. `scripts/eval/summarize_adoption.py`: compute ratios, scaling slopes, budget pass/fail, and an adoption scorecard.
6. `benches/eval/`: add generated and hand-written benchmark kernels for the matrix above.

---

# Prioritized action plan

## Immediate correctness fixes

1. Add public-state declassification and history/final-state theorem (T1/M1).
2. Fail closed on dynamic loop bounds in proof-grade mode (T2/M4).
3. Enforce sidecar metadata consistency as a first-class well-formedness predicate (T3).
4. Add artifact/view completeness checks and mutation tests (T4/M5).
5. Add runtime transcript binding for proof-object extraction (T5/M7).

## Immediate evaluation fixes

1. Expand overhead evaluation from one case to a backend/capacity matrix.
2. Report latency/RSS, not only modeled gas/writes/bytes.
3. Report proof/certificate size and validation-time scaling by capacity.
4. Add negative-policy tests for persistent public-state leaks.
5. Add an adoption scorecard per target workload.

## Medium-term practicality work

1. Replace local position-map full metadata scans with recursive/private position-map design.
2. Replace enumerated proof families with compact parameterized certificates.
3. Implement encrypted return channels.
4. Add public-only events/external interactions with proof-backed output policies.
5. Separate diagnostic deterministic execution from production execution at the type/API level.
