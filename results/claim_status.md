# Claim Status

Generated from `docs/claim-boundary.md` by `mplus-probe --only claim-status`. Do not edit by hand.

## Claims

| id | status | claim |
| --- | --- | --- |
| `paper-update-obliviousness-theorem` | Lean-proved | For every admitted package, two executions with the same public projection have equal normalized hostile-host observations outside the artifact-declared releases (status, plaintext return, encrypted-return ciphertext): exactly for the exact backends, and up to the Path ORAM storage relation on the proof-grade Path ORAM routes. |
| `deployment-acceptance-theorem` | Lean-proved | A production runtime result is accepted only under a current admitted-package identity, runtime proof-bundle hash, deployment policy hash match, return-channel session match, and freshness evidence. |
| `exact-uo-backends` | Lean-proved | Exact-UO is claimed for the exact backends on the instrumented abstract/runtime model: UOCell, UOArray, and full-scan UOMap. |
| `computational-uo-path-oram-local` | generated-and-checked | The bounded local-position-map Path ORAM route path_oram_local_posmap_v1 (capacity 128) executes; its Lean paper-main theorem holds over admitted configurations given bundle evidence, whose leaf obligation follows from the leaf model without seed enumeration, and the bundle is derived for a concrete single-access instance (SingleAccessMap.put) and, for the multi-access entrypoints, from one runtime run per side whose leaves are substituted for every other tape, with runtime runs on sampled tapes checked against the substitution. |
| `computational-uo-path-oram-private` | experimental | The scalable private-position-map Path ORAM route path_oram_private_posmap_v1 executes, including several accesses to one map per call, but is not yet covered by a theorem: its Lean theorems take the empty seeded proof bundle. |
| `admitted-package-identity-hash` | generated-and-checked | The artifact-level admitted-package hash is a canonical SHA-256 binding over source-language tag, semantics-profile tag, source bytes, sidecar metadata, compilation mode, compiler version, toolchain digest, and package schema tag. |
| `executable-semantics-profile` | generated-and-checked | Every artifact declares the executable-semantics profile tag uo-evm-modular256-v1, bound into the admitted-package hash, pinning the executable divergences from Solidity 0.8; the proof-grade checker rejects an unknown or divergent profile. |
| `source-backed-runtime-boundaries` | source-frozen | The source-backed runtime implementation boundaries are source-frozen/static-drift evidence, not a full semantics-of-Rust refinement; proof-critical obligations may not rest solely on a source regression. |
| `dsl-admission-subset` | empirically-tested | uo-solc admits the uo-solidity-like-dsl-v1 subset and rejects every unsupported feature with a diagnostic that names it; admission is empirically exercised, not a semantic proof. |
| `insecure-evaluation-baselines` | experimental | Executable insecure raw baselines (insecure-eval-raw) run confidential work on raw backends to measure overhead and leakage; they are evaluation-only and never admitted by the proof-grade or deployment paths. |

## Trusted Assumptions

| id | status | claim |
| --- | --- | --- |
| `assumption-bucket-encryption-indcpa` | trusted | bucketEncryptionINDCPA: hides Path ORAM bucket/path ciphertext contents; explicit Lean assumption grounded in the runtime ChaCha20Poly1305 sealed-record boundary. |
| `assumption-metadata-encryption-indcpa` | trusted | metadataEncryptionINDCPA: hides encrypted position-map metadata pages; explicit Lean assumption paired with the same sealed-record crypto route. |
| `assumption-stash-overflow-bounded` | trusted | stashOverflowBounded: bounds Path ORAM stash failure for deployed parameters; explicit Lean assumption paired with the JACM stash theorem at Z = 5 and pinned parameters. |
| `assumption-tee-deployment` | trusted | TEE deployment assumptions: enclave memory confidentiality/integrity, attestation authenticity, rollback resistance, freshness, crash recovery, and patch-level trust; explicit Lean bundle SgxDeploymentAssumptions. |
| `assumption-parser-preprocessing-equivalence` | trusted | Parser/preprocessing equivalence: connects raw Solidity-like source text to the post-resolution AST consumed by Lean; still a trusted front-end surface. |
| `assumption-real-keccak-equivalence` | trusted | Real Keccak equivalence: connects runtime tiny_keccak Keccak::v256() to the Lean mock-hash abstraction; not yet proved, Lean preservation uses the shared abstraction. |

## Non-Claims

| id | status | claim |
| --- | --- | --- |
| `nonclaim-machine-code-equivalence` | non-claim | Not claimed: downstream machine-code equivalence below the checked runtime boundary. Would require additional models and proofs. |
| `nonclaim-rust-semantics-refinement` | non-claim | Not claimed: a complete semantics-of-Rust refinement for every residual implementation detail. |
| `nonclaim-sgx-page-identities` | non-claim | Not claimed: raw equality of SGX page identities or full micro-event sequences. |
| `nonclaim-physical-side-channels` | non-claim | Not claimed: CPU-time, cache-behavior, page-fault, allocator, scheduler, power, electromagnetic, or wall-clock obliviousness. |
| `nonclaim-mock-hash-keccak-value-equality` | non-claim | Not claimed: value-level equality between the Lean mock hash and real runtime Keccak outputs. |
| `nonclaim-solidity-08-semantics` | non-claim | Not claimed: Solidity 0.8 checked-arithmetic, division/modulo-by-zero, ABI, revert, or context-variable semantics beyond the admitted public-environment fields. |

## TCB Components

| id | status | claim |
| --- | --- | --- |
| `tcb-lean-kernel` | trusted | Lean kernel plus Lean theorem/checker development: trusted proof checker and theorem body. |
| `tcb-rust-runtime-kernel` | trusted | Rust runtime kernel plus witness/certificate/bundle extraction and serialization: trusted implementation-side extraction surface. |
| `tcb-source-backed-boundaries` | trusted | Source-backed runtime implementation boundaries: source-frozen/static-drift evidence classified by evidence kind in runtime_boundary_validation.json. |
| `tcb-fixed-capacity-buffers` | trusted | Fixed-capacity Rust buffer helpers: safe Vec-backed wrappers; no production unsafe or MaybeUninit surface remains in fixed_buffer. |
| `tcb-trusted-assumptions` | trusted | Explicit backend/crypto/deployment assumptions: trusted assumptions enumerated above and grounded by the Lean assumption budget. |
| `tcb-rust-outside-kernel` | trusted | Rust code outside the tiny confidential kernel: not part of the confidential-work TCB when pinned to public-only or generated-helper routes. |
| `tcb-uo-solc-front-end` | trusted | uo-solc: not trusted as a proof oracle for accepted artifacts, but its parser/preprocessing front end remains trusted. |
| `tcb-uo-check` | trusted | uo-check: diagnostics/debug wrapper, outside the proof-grade TCB. |
| `tcb-mplus-probe` | trusted | mplus-probe: orchestration and reporting, outside the proof-grade TCB. |

