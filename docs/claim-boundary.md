# Claim Boundary

This document owns the current theorem claim, observer shape, assumptions, TCB,
and non-claims. It is the canonical place to look before changing claim
wording elsewhere.

## Paper Theorem

For every admitted program package `(P, M, V)`, where `P` is the restricted
Solidity source, `M` is the strict sidecar metadata, and `V` records the
compiler/proof/runtime model versions, if `uo-solc` compiles the package to
artifact `A`, the artifact records the matching admitted-package hash, the Lean
source/artifact checker accepts the pair, the real runtime executes `A` and
emits proof objects accepted by Lean, and the explicit backend, cryptographic,
and TEE deployment assumptions hold, then the execution's normalized
hostile-host observer satisfies the paper update-obliviousness theorem against
the stated observer and the artifact-declared return/status/public-state
declassification policy.

The compiler-side trust story starts at the post-resolution Sol AST / UO IR
consumed by Lean. Parser-level preprocessing remains trusted until a
raw-source-to-post-resolution witness relation is mechanized.

The artifact-level admitted-package hash is a canonical SHA-256 binding over
the source bytes, canonical sidecar metadata JSON, compilation mode, compiler
version, and package schema tag. It is checked for equality by the proof-grade
translation bundle. It is not yet a deployment attestation hash for the runtime
binary or SGX quote.

## Backend Scope

- Exact-UO is claimed for exact backends on the repository's instrumented
  abstract/runtime model: `UOCell`, `UOArray`, and full-scan `UOMap`.
- The theorem-facing computational-UO path is only
  `path_oram_local_posmap_v1`.
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
- `storage_trace` is exact for exact backends and related through the Path ORAM
  theorem for `path_oram_local_posmap_v1`.
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
| Parser/preprocessing equivalence | connects raw Solidity text to the post-resolution AST consumed by Lean | still trusted front-end surface |
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

Those would require additional models and proofs, not only more prose.
