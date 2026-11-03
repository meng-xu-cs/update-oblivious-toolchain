# Claim Boundary

This document owns the current theorem claim, observer shape, assumptions, TCB,
and non-claims. It is the canonical place to look before changing claim
wording elsewhere.

## Paper Theorem

For every admitted program package `(P, M, V)`, where `P` is the restricted
Solidity-like UO DSL source, `M` is the strict sidecar metadata, and `V`
records the compiler/proof/runtime model versions, if `uo-solc` compiles the
package to artifact `A`, the artifact records the matching admitted-package
hash, the Lean source/artifact checker accepts the pair, the real runtime
executes `A` and emits proof objects accepted by Lean, and the explicit
backend, cryptographic, and TEE deployment assumptions hold, then the
execution's normalized hostile-host observer satisfies the paper
update-obliviousness theorem modulo the artifact-declared releases: two
executions with the same public projection (admitted package, public
arguments, public environment, and initial public state) have equal
observations once the declared releases are erased,

```text
View_SGX(c₁) ∖ rel = View_SGX(c₂) ∖ rel
```

exactly for the exact backends, and with the storage component related by the
Path ORAM storage relation on the proof-grade Path ORAM routes. The released
values themselves may differ between the two executions.

The compiler-side trust story starts at the post-resolution Sol AST / UO IR
consumed by Lean. The active source theorem is for `uo-solidity-like-dsl-v1`,
not full Solidity 0.8 semantics. Parser-level preprocessing remains trusted
until a raw-source-to-post-resolution witness relation is mechanized.

The artifact-level admitted-package hash is a canonical SHA-256 binding over
the source-language tag (`uo-solidity-like-dsl-v1`), the executable-semantics
profile tag (`uo-evm-modular256-v1`), source bytes, canonical sidecar metadata
JSON, compilation mode, compiler version, toolchain manifest digest, and package
schema tag. The semantics profile pins the executable divergences from Solidity
0.8 — wrapping arithmetic, division/modulo-by-zero returning zero, canonical
fixed-size ABI encoding, `require`/abort rollback, admitted-only context
variables, and the mock-hash preservation route paired with the real-Keccak
runtime primitive — and the proof-grade checker rejects an unknown or divergent
profile. It is checked for equality by the proof-grade translation bundle. It is
not by itself a deployment attestation hash; the production deployment theorem
binds it to the runtime binary hash, proof-root hash, SGX quote, return-channel
session transcript, and freshness counters.

### Declared Releases

`∖ rel` erases exactly what the entrypoint's sidecar policies release. The
policies are carried in every public outcome, and the erasure is
`PaperMainViewSGX.withoutReleases` in `UOToolchain/PaperMainReleases.lean`:

- `status: declassified` releases whether the call completed or aborted: the
  termination status and the fields the runtime derives from it alone, namely
  the abort/rollback flag of the final public-state record, the output shape,
  and whether a plaintext or encrypted return payload is present.
- `returns: declassified` releases the plaintext return payload.
- `returns: encrypted_to_client` releases only the AEAD output bytes, the
  ciphertext and its tag; the session binding, AAD hash, nonce, and lengths
  stay constrained.

Every other component must be equal: the storage trace, boundary schedule,
normalized micro trace, modeled gas, the declared policies and
declassification labels, the final public-state digests, and the declared
release functions. For example, `ConfidentialMixer.withdraw` declares
`status: declassified` and `returns: declassified`. A withdrawal that
completes and returns 5 and one that aborts on an insufficient secret balance
must have the same storage trace, schedule, and gas; only the released status
and return value may differ.

Which statuses are released is checked by the compiler, not left to the
sidecar author: an entrypoint whose success/abort status depends on secrets
must declare `status: declassified`. That includes every entrypoint that writes
a confidential map, because a full bounded map aborts a write of a new key and
whether a key is new depends on the map's confidential contents; for example,
`ConfidentialMixer.deposit` declares `status: declassified` for this reason
(see [`supported-subset.md`](./supported-subset.md)).

The theorems are `paperMain_exact_backend_noninterference_moduloReleases`,
`paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases`, and
`paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases`, with the
accepted-package capstones
`acceptedExactPackageCapstone_noninterference_moduloReleases`,
`acceptedPathOramPackageCapstone_noninterference_moduloReleases`, and
`acceptedPrivatePosmapPathOramPackageCapstone_noninterference_moduloReleases`.
Each capstone takes the per-component safety premises (outcome and final
public state modulo releases, boundary schedule, controller shape, release
functions) as fields of its accepted-package evidence. The earlier
full-`View_SGX` theorems (`paperMain_exact_backend_noninterference` and the
capstones without the `_moduloReleases` suffix) assume every component,
released or not, is determined by the public projection, so they cover only
entrypoints without releases. Their evidence converts to the release form
(`AcceptedExactPackageCapstoneEvidence.moduloReleases` and its Path ORAM
analogues), and without declared releases the erasure is the identity
(`PaperMainViewSGX.withoutReleases_eq_self`).

## Deployment Theorem

The deployment theorem is separate from the paper theorem over the
instrumented runtime observer. A production runtime result is accepted only
when the runtime has:

- a current admitted-package identity and matching toolchain manifest digest;
- a runtime confidential proof-bundle hash for the emitted trace;
- a deployment policy matching the measured runtime binary hash, proof-root
  hash, and accepted SGX quote hash;
- a return-channel session id and attestation transcript hash matching the
  supplied session; and
- freshness evidence matching the runtime epoch, rollback counter, and next
  call counter at call entry.

The Rust enforcement point is `ProductionContractInstance::call_authorized`.
The Lean theorem surface is `DeploymentAcceptance.lean`, which exposes the
field bindings required by `DeploymentCallAccepted`.

## Backend Scope

- Exact-UO is claimed for exact backends on the repository's instrumented
  abstract/runtime model: `UOCell`, `UOArray`, and full-scan `UOMap`. For
  admitted kernel programs it is a Lean theorem over the exact store's
  encoding (`UOToolchain/KernelExactTrace.lean`): every admitted run executes
  the whole kernel body, each storage access scans its whole object, and every
  touched object is rewritten at commit with `Update`-class writes, so all
  admitted runs of a program produce the same trace (`admittedKernel_exactUO`)
  and `paperMain_admittedKernel_exact_noninterference_moduloReleases`
  discharges the paper-main theorem's storage-trace premise. That the runtime
  store emits exactly this encoding is checked against runtime traces
  (`exact_encoding_matches` in `results/trace_equivalence.json`), not proved.
- The theorem-facing computational-UO path is only
  `path_oram_local_posmap_v1` for the bounded local-position-map route and
  `path_oram_private_posmap_v1` for scalable private position metadata.
- Legacy/surrogate ORAM paths remain available for benchmarking and historical
  comparison, not for the strengthened proof-grade claim.
- Executable insecure raw baselines (the `insecure-eval-raw` evaluation feature,
  reported as the `raw_insecure_eval`/`ct_gas_only` rows in `results/overheads.json`
  and the `positive_control` in `results/leakage_auc.json`) run confidential work
  on raw backends to measure overhead and leakage against the UO route. They
  bypass the confidential-object targeting restriction, are evaluation-only, and
  are never admitted by the proof-grade translation bundle or the production
  deployment path; their result labels are distinct from the proof-grade rows so
  they cannot be confused with proof-grade artifacts.

## Observer

The paper-facing observer is:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c),
    final_public_state_rollback(c),
    release_functions(c) )
```

The components are interpreted as follows:

- `public_outcome` is exact: entrypoint id, public arguments, public
  environment, termination status, declared status policy, return shape,
  return policy, any public or declassified return payload, encrypted-return
  ciphertext evidence, declassification labels, and modeled public gas (cost
  model `uo-modeled-resource-cost-v1`: a modeled resource cost, not stock EVM
  gas; there is no EVM gas schedule or bytecode backend).
- `boundary_schedule` is the exact enclave boundary sequence.
- `storage_trace` is exact for exact backends and related through the
  proof-grade Path ORAM route.
- `micro_trace` is SGX-specific and is normalized/simulated from
  `L_sgx_micro`; the theorem does not claim raw page-id or full micro-event
  equality.
- `final_public_state_rollback` holds the initial, candidate, and committed
  public-state digests, the public delta digest, and the abort/rollback flag.
- `release_functions` names the declared release functions of the admitted
  package.

The concrete SGX/TEE observer pins live in
[`runtime/tee-observer.md`](./runtime/tee-observer.md).

## Explicit Assumptions

| Assumption | Role | Current treatment |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides Path ORAM bucket/path ciphertext contents | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; provenance is the runtime `ChaCha20Poly1305` sealed-record boundary plus the cited AEAD analysis route |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages | explicit Lean assumption paired with the same concrete sealed-record crypto route |
| `stashOverflowBounded` | bounds Path ORAM stash failure for deployed parameters | explicit Lean assumption paired with the JACM Path ORAM stash theorem at `Z = 5` and pinned deployed parameters |
| TEE deployment assumptions | enclave memory confidentiality/integrity, attestation authenticity, rollback resistance, freshness, crash recovery discipline, patch-level trust | explicit Lean bundle `SgxDeploymentAssumptions`, paired with Intel SGX provenance and probe drift checks |
| Parser/preprocessing equivalence | connects raw Solidity-like source text to the post-resolution AST consumed by Lean | still trusted front-end surface |
| Real Keccak equivalence | connects runtime `tiny_keccak::Keccak::v256()` to the Lean mock-hash abstraction | not yet proved; Lean preservation uses the shared abstraction |

The fresh-leaf remapping bridge is not a separate backend assumption. The
canonical fresh-coin runtime-family and hidden-leaf coverage checkers discharge
that leaf-seed-space interface directly.

`scripts/lean_assumption_budget.sh` emits `results/lean_assumption_budget.json`,
which grounds each active assumption above in the Lean source, lists its
consumer, and pins the only two `axiom` declarations
(`legacyOramLocalTheorem`, `legacySgxMicroLocalTheorem`) to legacy demonstration
modules that `UOToolchain.ProofGradeRoot` excludes. There are no `sorry`s. The
budget fails closed (and CI rejects the change) if any new `axiom`/`sorry`
appears outside that allowlist or a documented assumption stops being grounded.

## TCB

| Component | Current role |
| --- | --- |
| Lean kernel plus Lean theorem/checker development | trusted proof checker and theorem body |
| Explicit backend/crypto/deployment assumptions | trusted assumptions |
| Rust runtime kernel plus witness/certificate/bundle extraction and serialization | trusted implementation-side extraction surface; replay and reconstruction reduce but do not eliminate this trust |
| Source-backed runtime implementation boundaries | source-frozen/static-drift evidence, not full Rust semantic refinement. The runtime-to-Lean boundary obligations are classified by evidence kind in `runtime_boundary_validation.json` (`runtime_boundary_obligation_classification`): proof-critical obligations carry a Lean-theorem, generated-schema, executable-semantic-refinement, or source-frozen Rust-visibility kind, while the source-drift regression inventory is regression-only and backs no proof-critical claim. `validate_runtime_boundary_schema` rejects any proof-critical obligation backed only by source regression, so no proof-critical claim rests solely on a Rust source substring outside this source-frozen surface |
| Rust code outside the tiny confidential kernel | not part of the confidential-work TCB when pinned to public-only or generated-helper routes |
| Fixed-capacity Rust buffer helpers | safe `Vec`-backed wrappers; no production `unsafe` or `MaybeUninit` surface remains in `fixed_buffer` |
| `uo-solc` | not trusted as a proof oracle for accepted artifacts; parser/preprocessing remains trusted |
| `uo-check` | diagnostics/debug wrapper, outside the proof-grade TCB |
| `mplus-probe` | orchestration and reporting, outside the proof-grade TCB |

## Non-Claims

This repository does not claim:

- downstream machine-code equivalence below the checked runtime boundary
- a complete semantics-of-Rust refinement for every residual implementation
  detail
- raw equality of SGX page identities or full micro-event sequences
- CPU-time, cache-behavior, page-fault, allocator, scheduler, power,
  electromagnetic, or wall-clock obliviousness
- value-level equality between the Lean mock hash and real runtime Keccak
  outputs
- Solidity 0.8 checked-arithmetic, division/modulo-by-zero, ABI, revert, or
  context-variable semantics beyond the admitted public environment fields
  (`msg.sender`, `tx.origin`, `block.number`, `block.timestamp`, and
  `block.chainid`); the Lean bridge target for regaining that claim is
  `VersionedSoliditySemanticsBridge` in `SolidityDialectBoundary.lean`

Those would require additional models and proofs, not only more prose.

## Generated Manifest

This document is the source of truth for a generated claim/evaluation artifact
manifest. `mplus-probe --only claim-status` emits `results/claim_status.json`
(per-claim id/text/status), `results/claim_status.md` (the rendered status
table), and `results/claim_artifact_manifest.json` (each claim, assumption,
non-claim, and TCB component mapped to its source, Lean, runtime/compiler, and
benchmark/result artifacts plus a validation command). The report fails closed
and CI rejects the change if any assumption-table row, TCB-table row, or
non-claim bullet here is missing from the manifest, or if a referenced artifact
does not exist. `scripts/run_validation.sh` regenerates it.
