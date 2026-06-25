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
update-obliviousness theorem against the stated observer and the
artifact-declared return/status/public-state declassification policy.

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
  abstract/runtime model: `UOCell`, `UOArray`, and full-scan `UOMap`.
- The theorem-facing computational-UO path is only
  `path_oram_local_posmap_v1` for the bounded local-position-map route and
  `path_oram_private_posmap_v1` for scalable private position metadata.
- Legacy/surrogate ORAM paths remain available for benchmarking and historical
  comparison, not for the strengthened proof-grade claim.

## Observer

The paper-facing observer is:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

The components are interpreted as follows:

- `public_outcome` is exact: entrypoint id, public arguments, termination
  status, declared status policy, return shape, return policy, any public or
  declassified return payload, encrypted-return ciphertext evidence,
  declassification labels, public-state declassification labels, and modeled
  public gas.
- `boundary_schedule` is the exact enclave boundary sequence.
- `storage_trace` is exact for exact backends and related through the
  proof-grade Path ORAM route.
- `micro_trace` is SGX-specific and is normalized/simulated from
  `L_sgx_micro`; the theorem does not claim raw page-id or full micro-event
  equality.

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

## TCB

| Component | Current role |
| --- | --- |
| Lean kernel plus Lean theorem/checker development | trusted proof checker and theorem body |
| Explicit backend/crypto/deployment assumptions | trusted assumptions |
| Rust runtime kernel plus witness/certificate/bundle extraction and serialization | trusted implementation-side extraction surface; replay and reconstruction reduce but do not eliminate this trust |
| Source-backed runtime implementation boundaries | source-frozen/static-drift evidence, not full Rust semantic refinement |
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
