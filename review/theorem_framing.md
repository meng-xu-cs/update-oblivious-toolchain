# Theorem framing and completeness review

## Inventory overview

The generated theorem inventory found **2371** top-level theorem-like declarations under `proof/lean/UOToolchain/*.lean`: **2369** theorems and **2** axioms across **75** files. The full list is in `theorem_inventory.tsv`; a generated summary is in `theorem_inventory.md`.

The two axioms are legacy demonstration axioms:

- `legacyOramLocalTheorem` at `proof/lean/UOToolchain/OramGame.lean:7`.
- `legacySgxMicroLocalTheorem` at `proof/lean/UOToolchain/SgxMicroGame.lean:7`.

The proof-grade reports in `results/static_checks.json` state that proof-grade checkers avoid these legacy symbols. That is good, but the umbrella module still imports the legacy axiom modules (`proof/lean/UOToolchain.lean:11,22`), so a final proof audit should use theorem-level axiom reports rather than only grep/static-surface checks.

## Main theorem families observed

1. **Source / IR / kernel semantics.** `Sol.lean`, `IRSemantics.lean`, `KernelDsl.lean`, `CompilerExactness.lean`, and translation-validation modules define the admitted source/IR/kernel relation. This is the right place for source-to-artifact correctness, but it currently abstracts semantic front-end steps and uses a value model that diverges from runtime arithmetic/Keccak.

2. **Artifact validity / proof-grade predicates.** `ProofGrade.lean`, JSON checker modules, and `ConfidentialFragment*.lean` validate proof-relevant artifact/witness/certificate structures. This is a substantial checker surface, but it proves properties of accepted artifacts and emitted witnesses, not necessarily that the Rust runtime generated those witnesses faithfully unless extraction refinement is independently established.

3. **Exact-UO, gas, and composition.** `ExactObjects.lean`, `CompilerInvariant.lean`, and `Composition.lean` provide exact-backend/composition/public-gas abstractions. Some statements are abstract wrappers: e.g., if a run is already public-gas-safe, then gas is public. They should not be oversold as proving the compiler/runtime always enforce public gas unless tied to concrete evaluators.

4. **ORAM theorem route.** `StandardOramReduction.lean`, `PathOramSecurity.lean`, `PathOramLocalPosmapV1*.lean`, `PathOramJACMTheorem.lean`, and `PaperPathOramTheoremRoute.lean` build the proof-grade path from runtime certificates to the cited standard Path ORAM theorem assumption. The formal shape is coherent, but it depends on explicit assumptions for encryption, metadata, stash overflow, and the imported ORAM theorem.

5. **TEE / hostile-host observer.** `TeeDeployment.lean`, `SgxRelation.lean`, `SgxController*.lean`, `SgxObserverFreeze.lean`, and `Sgx*Projection.lean` model the frozen observer and microtrace normalization. This is strong relative to many prototypes, but the observer intentionally excludes raw physical side channels and, more importantly, the return payload.

6. **Runtime implementation boundaries.** `RuntimeImplementationInterface.lean` and the many runtime-boundary modules prove source-backed invariants and schema/certificate properties. This is useful, but it should be described as a checked source-interface/drift boundary unless or until paired with deeper Rust semantics.

## Correctness of current theorem framing

The theorem framing is internally consistent if interpreted narrowly: for proof-grade accepted artifacts, the modeled observer records public outcome shape/status/gas, boundary schedule, storage trace, and normalized microtrace; exact backends get exact equality and `path_oram_local_posmap_v1` gets a computational relation under explicit assumptions.

The risky part is the phrase “real host-visible execution.” A host-visible execution includes at least: return values, success/failure, error channels, total elapsed time at some granularity, persistent-state commit/rollback, and the ability to adapt future calls. The current theorem surface handles some of these explicitly, excludes some as non-claims, and unintentionally omits or policy-defers others.

## Missing or weak theorems

### 1. Public output/value theorem

**Missing theorem.** For any two related secret states/inputs with equal public projection, the host-visible return payloads are equal, computationally indistinguishable, encrypted under an approved channel, or explicitly declassified.

**Why needed.** The model has `OutputShape`, not payload. Without this theorem, a confidential `read` can leak directly through its return.

### 2. Secret-independent termination or explicit abort-declassification theorem

**Missing theorem.** Termination/abort status must be public-determined or explicitly included in leakage/declassification.

**Why needed.** `termination_status` is exact in the observer, and benchmark confidential conditions are secret-dependent.

### 3. Sequential/adaptive history theorem

**Missing theorem.** A theorem over an interactive sequence of calls, where the adversarial host chooses public inputs adaptively based on prior observations, and the relation is preserved over persistent state updates.

**Why needed.** Update-obliviousness is a stateful history property, not only a single-call trace property.

### 4. Real source/runtime semantic preservation theorem

**Weak theorem.** The source-to-kernel Lean preservation theorems are over the Lean source model with mock Keccak and `Nat` arithmetic. They do not prove real Solidity `uint256` semantics or current Rust `u128` wrapping semantics unless those are formalized.

**Needed statement.** For every admitted Solidity source and sidecar, the real compiler/lowering/runtime computes the same public/declassified functional result and state transition as the specified source semantics, modulo explicitly modeled abstraction (e.g., encrypted returns or ORAM physical representation).

### 5. Admission/policy completeness theorem

**Missing theorem.** Every externally callable function has an explicit policy, every state object access is classified, every secret argument is declared or inferred, and omissions fail closed.

**Why needed.** Current code treats absent metadata as public; the theorem should prove no unclassified entrypoint slips into public mode.

### 6. Axiom-free proof-grade route theorem

**Missing theorem/check.** A machine-checkable report for the named final paper theorem(s): `#print axioms` shows only whitelisted explicit assumptions and no legacy axioms.

**Why needed.** The repository has legacy axiom modules and a root import surface that includes them.

### 7. Runtime extraction faithfulness theorem

**Weak theorem.** Source-backed checks pin runtime code shape, but the system still trusts that emitted witnesses/certificates faithfully describe the actual runtime execution.

**Needed statement.** From a minimal logged execution transcript, an independent checker reconstructs the accepted witness/certificate, or the runtime extraction code is semantically verified.

### 8. Mixed-backend, ordered multi-object leakage theorem

**Potentially weak theorem.** The theorem should cover programs mixing exact cells/arrays/maps and ORAM maps, with an ordered public object-access schedule. Counts alone are insufficient if object interleaving can depend on secrets.

**Needed statement.** For an artifact with mixed backends, the ordered logical object schedule is public-determined or included in leakage, and each object’s exact/ORAM theorem composes to the whole storage trace.

### 9. Randomness/freshness/nonce theorem

**Missing theorem.** Runtime random/fresh coins and crypto nonces satisfy the independence/uniqueness assumptions required by the Path ORAM encryption and remapping theorem.

**Needed statement.** Every access consumes fresh leaf/remap randomness; every encryption call uses a unique nonce/domain; diagnostics cannot force repeated coins in production theorem mode.

### 10. Failure/capacity/stash theorem

**Missing or assumption-only theorem.** Map capacity overflow, ORAM stash overflow, allocator failure, and decode/serialization errors must either be public-determined, negligible under stated parameters, or explicit declassification.

**Why needed.** Failure status and commit behavior are host-visible.

### 11. Public gas versus real cost theorem

**Weak theorem.** Public gas is modeled, but wall-clock/runtime resource usage is outside the claim. If the paper says “gas” only, this is fine; if readers infer timing/CPU obliviousness, it is too broad.

**Needed statement.** Either explicitly restrict “gas” to the modeled public gas metric, or prove stronger real-cost bounds for the runtime path under a declared platform model.

### 12. Error-channel theorem

**Potential missing theorem.** Runtime `anyhow`/error strings, panics, deserialization failures, and checker errors should not contain secret-dependent information in host-visible execution.

**Needed statement.** All host-visible errors before/after confidential execution are public-determined or occur only before secret ingestion; secret-dependent internal errors are normalized.

## Suggested theorem reframing

A safer final theorem shape would be:

> For every source/artifact pair accepted by the proof-grade source/artifact checker and every runtime execution whose minimal transcript is accepted by the runtime witness checker, if all explicit backend/crypto/TEE assumptions hold and every host-visible output/status/error is either public-determined, encrypted under the modeled return channel, or declared in the declassification policy, then the full host-visible transcript over any public/adaptive call history is related by the update-oblivious observer relation, with exact equality for exact backends and the stated computational relation for `path_oram_local_posmap_v1`.

This wording forces return values, abort status, errors, histories, and declassification into the theorem instead of leaving them as implied context.
