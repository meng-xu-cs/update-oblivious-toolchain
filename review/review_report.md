# Independent Review: Update-Oblivious Toolchain Bundle

**Review date:** 2026-04-29  
**Archive reviewed:** `/mnt/data/update-oblivious-toolchain-main.zip`  
**Repository extracted to:** `/mnt/data/uo_review_work/update-oblivious-toolchain-main`

## Scope and method

I reviewed the documentation, compiler front end/lowering code, runtime shell/controller/object commit code, proof-grade Lean root, translation-validation code, result summaries, and the bundled historical review report. This was a static review only: this environment does not have `rustc`, `cargo`, `lean`, or `lake`, so I could not re-run the Rust test suite, probe validations, or Lean builds. I therefore treat the repository's own `results/` outputs as claimed evidence rather than revalidated evidence.

The current claim boundary is unusually explicit and helpful. In particular, `docs/claim-boundary.md` already calls out the parser/preprocessing boundary, below-Rust-semantics boundary, external/cited ORAM theorem boundary, crypto/TEE assumptions, mock-Keccak boundary, and non-claims around raw microarchitectural leakage. I do not repeat those as “new” issues except where I found a more specific subcase that could be eliminated.

## Executive judgment

The proof architecture is stronger than the bundled `review/` report suggests. In the current source, proof-grade Lean imports are separated from legacy axiom-backed demos, public-state declassification has been added, and loop bounds are checked in proof-grade mode. A static grep found no `sorry`/`admit` in `proof/lean/UOToolchain`; the only top-level Lean axioms I found are the two legacy demonstration axioms in `OramGame.lean` and `SgxMicroGame.lean`, neither imported by `ProofGradeRoot.lean`.

The most important remaining risk is not the known parser/Rust/ORAM trust boundary. It is that the admission policy seems to allow **public entrypoints to read confidential state and then take secret-dependent public-observer actions** that are not classified as return/status/public-state declassification. This can leak through modeled public gas, object/storage schedule, or runtime/proof traces. The theorem should be reframed, or the compiler should fail closed, so this path is impossible.

The second class of risks is strictness and provenance: unknown sidecar fields are ignored by serde, the package hash is over parsed canonical metadata rather than raw sidecar bytes, and the current admitted identity does not bind the full `(P, M, V)` tuple promised by the docs.

The third class is theorem framing: many local/interface theorems are present, but the paper-facing theorem should be stated as a direct relational noninterference theorem over the complete normalized hostile-host observer, including adaptive histories and final public state/rollback semantics.

## Understanding of the intended property

My reading is that update-oblivious programming generalizes constant-time programming from “secret-dependent branches or timing” to “secret-dependent state-update and storage-observer behavior.” The observer in the claim boundary is:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

with exact public outcome/boundary schedule, exact or ORAM-related storage trace depending on backend, and normalized/simulated SGX micro trace. The intended theorem is: for admitted programs, two executions that differ only in secret inputs/state and agree on declared declassifications should have equal or computationally indistinguishable hostile-host views.

That is the right framing. The current implementation/proof inventory has the ingredients, but I would tighten admission and theorem surfaces before presenting the toolchain as proving that statement end-to-end.

## Task 1 — Unintended trust boundaries and assumptions

### TB-01 — Public entrypoints can leak through observer-relevant work

**Severity: critical.**

The compiler's policy analysis in `compiler/uo-solc/src/lib.rs:1942-2025` checks sensitive return values, secret-dependent status, and sensitive writes to public state. The sensitivity collector in `:2078-2210` taints confidential reads and secret args, but it records only return/status/public-write consequences. It does not reject secret-dependent public reads, object schedules, opcode traces, or gas.

The runtime public shell appears to make this observable:

- `runtime/uo-evm/src/state.rs:404-406` returns all object ids from `public_object_ids`.
- `runtime/uo-evm/src/shell.rs:174-204` executes only the selected branch of an `if`.
- `runtime/uo-evm/src/shell.rs:372-382` can read state objects from public-shell expression evaluation.
- `runtime/uo-evm/src/controller.rs:492-505` computes non-confidential gas from logical reads/writes and physical writes.
- `crates/uo-core/src/trace.rs:166-183` includes modeled gas in `PublicOutcomeTrace`.

A sketch of the kind of admitted program that should become a negative test:

```solidity
contract SecretBranchLeak {
    uint256 secret;       // sidecar: confidential: true, backend: full_scan
    uint256 publicDummy;  // sidecar: confidential: false, backend: raw

    function leakSchedule() public {
        if (secret != 0) {
            uint256 x = publicDummy;
        }
    }
}
```

This has no return, no status leak, and no public write. But if it is admitted as `confidential: false`, the branch can change modeled gas and storage/object trace. Even if the exact syntax needs adapting to the restricted subset, the code path suggests the admission theorem needs to cover this class.

**Path to eliminate:** choose one of two fail-closed designs.

1. **Strict separation:** public entrypoints may not read confidential objects at all. Public functions that need secret state must be marked confidential and use explicit return/status/public-state declassification.
2. **Trace-sensitive admission:** allow public secret reads only if a Lean-mirrored analysis proves every observer component is public-determined. This analysis must include public reads, object schedule, opcode/kernel step trace, modeled gas, storage trace, and branch/loop structure.

I recommend option 1 first because it is simpler and aligns with the current confidential-kernel architecture.

### TB-02 — Sidecar metadata is not strict at parse/hash boundary

**Severity: high.**

`crates/uo-core/src/metadata.rs:4-75` derives `Deserialize` without `#[serde(deny_unknown_fields)]`. A repository-wide search found no `deny_unknown_fields`. `AdmittedPackageIdentity::new` in `crates/uo-core/src/artifact.rs:39-65` hashes `canonical_json_bytes(metadata)`, i.e., the parsed metadata object, not the raw sidecar bytes.

That means a sidecar can contain unknown fields that are silently ignored and not reflected in `metadata_sha256`. This contradicts the docs' “strict sidecar metadata” wording and can hide a stale or misspelled policy.

**Path to eliminate:** add `deny_unknown_fields` to all sidecar structs, add duplicate/extraneous-field checks, and include `raw_metadata_sha256` in an identity v2. Add tamper tests for unknown top-level, state, entrypoint, and bounds keys.

### TB-03 — The package hash does not bind full `(P, M, V)`

**Severity: high.**

`docs/claim-boundary.md:9-18` defines admitted packages as `(P, M, V)`, where `V` records compiler/proof/runtime model versions. But `crates/uo-core/src/artifact.rs:48-55` hashes only schema, source hash, metadata hash, compilation mode, and compiler version. The docs correctly say this is not a deployment attestation hash, but the theorem claim itself should bind the proof/runtime model versions it quantifies over.

**Path to eliminate:** add an admitted-package v2 with a `toolchain_manifest_sha256` covering at least Rust toolchain, Cargo.lock, parser crate version, uo-core/runtime versions, generated code hashes, Lean toolchain, ProofGradeRoot/import-set hash, proof checker schema, and runtime model tags. Bind this digest into SGX attestation and return-channel session setup for deployment.

### TB-04 — Abort/rollback semantics need a pinned theorem

**Severity: high.**

Lean `IR.Outcome` includes `finalPublicState` (`proof/lean/UOToolchain/IRSemantics.lean:296-302`) and `evalContract` returns `cfg'.publicState` after `evalBody` (`:1068-1082`). Runtime public execution commits with an `aborted` flag (`runtime/uo-evm/src/shell.rs:52`), and object commit code skips or restores writes on abort (`runtime/uo-evm/src/objects.rs:1017-1029`, `:1231-1261`).

I did not find a theorem stating that source/IR and runtime agree on rollback behavior. If Lean currently records prefix-updated state on abort while runtime rolls back, the final-public-state/declassification theorem is misframed. If Lean does roll back elsewhere, the theorem should expose that explicitly.

**Path to eliminate:** define transaction semantics with `initialPublicState`, `publicDelta`, `finalPublicState`, and `aborted`; prove runtime/source agreement; add tests where a public write is followed by `require(false)`.

### TB-05 — Declassification is too coarse for least-release claims

**Severity: medium-high.**

The current policy is label- and object-based: return, success, and whole public-state objects. `validate_entrypoint_policy` requires labels, but `validate_entrypoint_metadata_well_formed` does not reject duplicate `secret_args`/`declassifies` or extraneous declassification labels. `TranslationValidationJson.lean:1449-1453` similarly checks required label presence/incompatibility rather than exact/minimal release.

**Path to eliminate:** define declassification as explicit release functions, e.g., return expression, success bit, public-state object/key/delta. Prove relational noninterference modulo exactly those release functions. Reject duplicate/extraneous labels by default.

### TB-06 — Proof-relevant view completeness is manually curated

**Severity: medium-high.**

This has improved substantially. `crates/uo-core/src/translation_validation.rs:436-533` enumerates proof-relevant fields, and `:535-559` rejects missing/extra fields in that view. But this proves completeness of the curated view, not that every runtime field affecting the observer is included or classified.

**Path to eliminate:** generate the proof-relevant view from the runtime manifest/trace schema, or add a generated proof-relevance inventory. Mutation tests should add a new observer-affecting field and require failure until it is classified and mirrored in Lean.

### TB-07 — Freshness remains an assumption-heavy runtime discipline

**Severity: medium.**

Freshness is documented and audited, but production nonce/coin uniqueness and crash/rollback interactions are not obviously mechanized end-to-end. For example, `runtime/uo-evm/src/objects.rs:1260` resets the Path ORAM leaf coin source with `PathOramLeafCoinSource::random()`.

**Path to eliminate:** derive nonces/coins from domain-separated attested counters and model those counters in Lean, including crash recovery and rollback resistance. Ensure diagnostic seed injection cannot be compiled into production.

### TB-08 — Unsafe Rust is narrow but still theorem-adjacent

**Severity: medium.**

A grep found production `unsafe` only in `crates/uo-core/src/fixed_buffer.rs` (`slice::from_raw_parts`, `assume_init_read`, `Box::from_raw`, `assume_init_drop`). This is a narrow instance of the documented Rust-refinement boundary. The invariant is small enough to reduce with safe containers, Miri, Kani, Prusti/Creusot, or a small proof.

### TB-09 — Path ORAM cap is Rust-enforced, not mirrored in the Lean imported shape I inspected

**Severity: medium.**

`crates/uo-core/src/manifest.rs:11-12` sets `PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY = 128`, and `:235-243` rejects larger capacities. `TranslationValidationJson.lean:1556-1595` checks the imported path ORAM shape formulas but not the capacity cap. If the cap is part of the proof-grade theorem route, mirror it in Lean; if it is only practical, document it that way.

### TB-10 — Smaller strictness gaps

**Severity: medium.**

I would also fail closed on:

- non-ORAM state carrying `oram_scheme` (`compiler/uo-solc/src/lib.rs:1052-1059`);
- array sidecar capacity being optional despite docs saying map/array capacities are positive (`:1092-1101`, `docs/supported-subset.md:54-55`);
- duplicate `secret_args` and duplicate/extraneous `declassifies` (`:2683-2703`).

These are not immediately UO-breaking, but they reduce metadata ambiguity and audit burden.

## Task 2 — Theorem framing, correctness, and completeness

### Static theorem inventory

The static declaration inventory found **5232** top-level declarations in `proof/lean/UOToolchain`, including **2414** `theorem`/`lemma` declarations. `ProofGradeRoot.lean` imports **65** modules. The only axioms found are legacy demonstration axioms outside the proof-grade root.

Top modules by declaration count:

| Module | Total declarations | Theorems | Defs | In ProofGradeRoot imports |
| --- | ---: | ---: | ---: | --- |
| UOToolchain.RuntimeImplementationInterface | 1055 | 812 | 225 | false |
| UOToolchain.RuntimeOramHelperSemantics | 322 | 222 | 86 | true |
| UOToolchain.RuntimeRefinement | 265 | 89 | 152 | true |
| UOToolchain.TranslationValidationJson | 252 | 28 | 208 | true |
| UOToolchain.RuntimeImplementationInterfaceJson | 227 | 54 | 155 | false |
| UOToolchain.RuntimeKernelDslJson | 207 | 74 | 114 | true |
| UOToolchain.RuntimeRefinementJson | 202 | 30 | 124 | true |
| UOToolchain.RuntimeOramCodecSemantics | 192 | 96 | 90 | true |
| UOToolchain.ProofGrade | 131 | 131 | 0 | true |
| UOToolchain.RuntimeCoinsJson | 120 | 16 | 98 | true |
| UOToolchain.PathOramSecurity | 99 | 26 | 53 | true |
| UOToolchain.IRSemantics | 90 | 35 | 36 | true |

The full inventory is in `theorem_inventory.csv`, with a summary in `theorem_inventory_summary.csv`.

### Strong theorem-framing choices

The current framing has several strong points:

- The proof-grade root intentionally excludes legacy axiom modules.
- The claim boundary explicitly distinguishes exact UO backends from the computational Path ORAM route.
- `PaperPathOramTheoremRoute.lean` cleanly separates external/literature theorem source, backend realization, and runtime-kernel boundary.
- `RuntimePaperInstantiation.lean` and the JSON validation modules expose many runtime-facing bridge surfaces explicitly.
- Public outcome now includes status/return policy, public-state declassification labels, modeled gas, and final-public-state surfaces in the docs/semantics.

### Main theorem risks

#### TH-01 — Missing or false public-entrypoint observer theorem

The toolchain needs a theorem that every admitted public entrypoint has host-visible behavior determined only by public data. TB-01 suggests the theorem is currently false unless the compiler rejects public secret reads or the observer analysis is expanded.

#### TH-02 — Main theorem should be a direct relational noninterference statement

The paper theorem should be stated in the form:

```text
For all admitted package identities I and artifacts A,
for all two executions e1,e2 with equal public inputs/public initial state
and equal declared release functions,
View_SGX(e1) == View_SGX(e2)               for exact backends
or View_SGX(e1) ≈_c View_SGX(e2)           for Path ORAM storage components.
```

Then prove that the current bridge/interface theorem route implies this statement. This avoids proving only internal bridge equalities whose relation to the final security theorem must be reconstructed by the reader.

#### TH-03 — Adaptive history theorem is conditional

`HistorySemantics.lean` is a useful surface: it names transcripts, ordered object schedules, final public states, and adaptive strategies. But the current theorems prove projections equal **given** `HistoryStepsPublicEq`. I did not find the stronger inductive theorem deriving `HistoryStepsPublicEq` from the single-call theorem and a public adaptive strategy.

Needed theorem shape:

```text
If strategy observes only HostTranscript,
and every next call is admitted and satisfies single-call UO modulo release,
then two runs with equal initial public state and equal release history
produce equal public transcripts and equal ordered public schedules.
```

#### TH-04 — Abort and rollback must be part of theorem statement

Final public state is now in the model, which is good. The theorem should explicitly include commit/rollback behavior and public-state deltas, especially for calls that abort after writing public state.

#### TH-05 — Declassification theorem should be release-function based

Labels are useful metadata, but the theorem should not merely say “labels are present.” It should say the observer is a deterministic function of public inputs plus the exact release functions. Public-state declassification should be delta/key/expression scoped if you want least-release claims.

#### TH-06 — View-completeness theorem needed

A theorem or generated checker should state that every runtime field influencing `View_SGX` is either in the proof view, public-only, explicitly declassified, cryptographically hidden under a stated assumption, or outside the claim. The current exact-field checks are necessary but not sufficient for this stronger coverage statement.

#### TH-07 — Source dialect theorem is needed if using the word Solidity

The docs say the accepted language uses modulo `uint256` arithmetic and division/modulo-by-zero returning zero. That diverges from Solidity 0.8 default checked arithmetic and division-by-zero panic behavior. Therefore, the source theorem should either call the language “Solidity-like UO DSL” or prove a relation from a specific Solidity semantics/pragma subset to the IR.

## Task 3 — Practicality

My judgment: the toolchain is practical as a **research prototype for small fixed-capacity confidential workflows**, not yet practical for broad real-world Solidity contracts or on-chain EVM deployment.

### What it can realistically support today

It can support examples like fixed-slot classifiers, small authentication scans, small confidential mixers, or bounded ERC20-like sketches where:

- all secret-touching entrypoints are confidential;
- capacities are known and small;
- maps are bounded;
- no external calls/events/constructors/inheritance/dynamic data are needed;
- the execution target is the instrumented confidential runtime rather than raw deployed EVM bytecode.

### Practical blockers beyond the intentional Solidity subset

1. **Public secret-read ambiguity.** Even if the source subset is intentionally narrow, useful systems often need public setup/getter/admin functions around secret state. The current boundary should make it impossible for those functions to inspect confidential state unless they are confidential and declassification-checked.

2. **Capacity and evidence growth.** `results/reviewer_summary.md` reports total probe cost of 2,138,372 ms, canonical Path ORAM pair validation of 206,627 ms, and materialized/estimated artifacts ranging from megabytes to astronomically large estimates. The current `path_oram_local_posmap_v1` cap of 128 and local position map make real account maps, order books, large mixers, and many voting/crowdfunding scenarios unrealistic without recursive/private position maps and symbolic certificates.

3. **Not chain-compatible gas or deployment.** Confidential gas is a modeled manifest budget, and the runtime target is not raw EVM bytecode on a public chain. That is fine for the current claim, but it means the toolchain is not directly a Solidity compiler replacement.

4. **No environment/auth model.** I did not find support for transaction/context variables such as `msg.sender`, `block.*`, or `tx.*`; external calls, constructors, modifiers, and events are rejected. That makes practical authorization and integration hard unless all context is modeled as explicit public arguments with a separate trusted caller/session layer.

5. **Solidity dialect mismatch.** The accepted arithmetic/division semantics are intentionally simplified. This should be treated as a DSL unless a Solidity-version-specific translation proof is added.

6. **Runtime attestation and proof acceptance are not unified.** The docs say admitted-package hash is not deployment attestation. For production, users need a single digest binding source, sidecar, proof root, runtime binary, SGX quote, and return-channel session.

### Practicality roadmap

**P0: Safety before expansion.** Patch TB-01, TB-02, TB-03, and TB-04 first. These affect whether the theorem claim is true.

**P1: Make admitted examples less toy-like.** Add a small, explicit environment/auth model: caller identity as a public argument or attested session principal, plus a theorem that it is public. Add constructors/init as a single setup phase with proof-checked public/secret initialization policy.

**P2: Replace local position map and enumerated proof families.** Move to recursive/private position maps and compact/symbolic certificates. The current proof artifact sizes will not scale.

**P3: Deployment binding.** Add reproducibility manifest, proof-root hash, runtime binary hash, and SGX quote binding to artifact identity. Make the runtime refuse to execute unchecked/unattested proof-grade artifacts in production mode.

**P4: Solidity interoperability.** Either document the language as a DSL or add a versioned Solidity semantics bridge, especially for checked arithmetic, division-by-zero, revert/rollback, ABI encoding, and context variables.

## Task 4 — Additional improvements and how I would do them

### 1. Add an “observer-sensitivity” admission pass

Inputs: lowered IR, state confidentiality map, entrypoint policy, and backend manifest. Outputs: a proof-relevant certificate classifying every expression/statement effect on public outcome, gas, storage/object schedule, boundary schedule, kernel/opcode trace, and final public state.

Fail closed for public entrypoints if any observer-relevant effect is secret-tainted. For confidential entrypoints, require the existing linearized kernel path and prove the fixed observer shape.

### 2. Normalize and hash policies

Before hashing, normalize sidecar metadata into a canonical policy object:

- no unknown fields;
- no duplicate labels/secret args;
- no irrelevant fields for the chosen backend/kind;
- explicit defaults materialized;
- exact release functions named.

Hash both raw sidecar and normalized policy. This catches stale sidecars while keeping canonical comparison stable.

### 3. State the main theorem in one file

Create `PaperMainTheorem.lean` that imports the current route and exposes one direct theorem with the user-facing observer relation. Keep bridge theorems internal or appendix-level. This will make it much harder to “prove the wrong thing.”

### 4. Add a proof-relevance coverage table generated from Rust types

For every field in public outcome, execution trace, runtime manifest, object manifest, and return-channel evidence, classify it as:

- included in Lean view;
- public input;
- declared release;
- cryptographically hidden under named assumption;
- normalized away;
- outside non-claim.

Have CI fail if a runtime observer type changes without updating this table and Lean mirror.

### 5. Add adversarial negative tests

Add compiler/checker tests for:

- public entrypoint reads confidential state and conditionally reads/writes public state;
- public entrypoint secret-dependent branch with no return/status/write but different gas;
- write then abort rollback cases;
- unknown sidecar fields;
- duplicate secret args/declass labels;
- non-ORAM `oram_scheme`;
- array sidecar capacity omitted when docs require it;
- path ORAM capacity above 128 in imported proof view.

### 6. Split “research theorem” and “deployment theorem”

The research theorem can remain about instrumented runtime traces and normalized SGX observer. The deployment theorem should additionally require attestation, binary hash, rollback counter/freshness, session binding, and proof acceptance before execution. Keeping these separate will make the current non-claims clearer and avoid overclaiming.

## Files in this review bundle

- `review_report.md` — this report.
- `issue_register.csv` — machine-readable trust-boundary and assumption issues.
- `theorem_gap_register.csv` — theorem framing gaps.
- `theorem_inventory.csv` — static inventory of Lean declarations.
- `theorem_inventory_summary.csv` — declaration counts by module/kind.
- `negative_test_sketches.md` — concrete tests I would add first.
- `action_plan.md` — phased remediation plan.
