# Formal Proof Plan

This document defines the next proof-oriented milestone for the UO Toolchain.

The goal is not to overclaim. The current repository can realistically target a
mechanized proof for the instrumented abstract machine used by this workspace.
It cannot honestly target a universal theorem over all downstream Rust machine
code, host runtime effects, or microarchitectural observers.

## 1. Claim Boundary

The proof target should be split into two claims.

### 1.1 Artifact-level exact-UO claim

For accepted contracts whose confidential state is implemented using
`UOCell`, `UOArray`, or full-scan `UOMap`, prove exact equality of the
normalized `M+`-visible trace across secret variations.

### 1.2 Artifact-level computational-UO claim

For accepted contracts whose confidential state includes ORAM-backed maps,
prove that the normalized `M+`-visible trace distribution is computationally
indistinguishable across secret variations, up to an explicitly declared
leakage function.

### 1.3 Explicit non-claims

The proof should not claim:

- security for unsupported Solidity features
- security for raw backends on confidential state
- security against observers below the modeled abstract/runtime interface
- security of the current ad hoc nonzero codec as a cryptographic primitive

## 2. Formal Objects

The mechanized proof should define the following objects directly from the
current repository structure.

### 2.1 Programs

A program is a compiled artifact:

- contract state objects from [ir.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/ir.rs)
- runtime manifest entries from [manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs)
- lowered function bodies over the UO IR

### 2.2 Inputs

For a confidential entrypoint `f`, split arguments into:

- `pub_in`: public arguments
- `sec_in`: secret arguments declared in the manifest

The initial contract state is similarly split into:

- `pub_state`: public state and public capacities
- `sec_state`: confidential logical contents

### 2.3 Runtime traces

The proof should use the normalized trace model in
[trace.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/trace.rs):

- opcode trace
- logical access trace
- logical write trace
- normalized physical read schedule
- normalized physical write schedule
- public gas

The current normalized physical view is intentionally shape-based:

- physical reads: `(object, location, len)`
- physical writes: `(object, location, write_class, len)`

This is the right proof target for the current artifact because it matches the
results bundle and the runtime instrumentation.

### 2.4 Adversary view

Define the artifact-level `M+` view as:

```text
View_M+(trace) =
  ( opcode_trace,
    logical_accesses,
    logical_writes,
    physical_reads_norm,
    physical_writes_norm,
    gas_used )
```

For exact-UO objects, equality is literal equality of `View_M+`.

For ORAM-backed objects, the theorem should instead quantify over the
distribution of `View_M+` induced by the runtime coins.

## 3. Leakage Functions

The proof must state leakage explicitly.

### 3.1 Exact-UO leakage

For exact-UO backends, the permitted leakage is:

- contract identity
- entrypoint identity
- public argument values
- public capacities and object shapes
- manifest-declared gas budget

No additional dependence on secrets is allowed.

### 3.2 Computational-UO ORAM leakage

For ORAM-backed objects, the permitted leakage should be an explicit function
`L_oram` containing only public configuration data and public schedule data.

Recommended shape:

```text
L_oram(A, f, pub_state, pub_in) =
  ( entrypoint_id,
    public_gas_budget,
    object_id,
    capacity,
    recursion_depth,
    bucket_fanout,
    buckets_per_level,
    path_length_per_access,
    metadata_pages_per_access,
    blocks_per_bucket,
    block_size,
    accesses_per_entrypoint )
```

If the implementation leaks anything else, it is outside the theorem.

## 4. Target Theorems

The proof plan should target the following theorem stack.

### Theorem A: Checker soundness

If `uo-check` accepts a source contract and its compiled artifact, then:

- all confidential state objects use approved backends
- all public capacities/bounds required by the runtime exist
- confidential IR contains no forbidden control flow
- manifest/object metadata is structurally consistent

### Theorem B: Compiler secrecy preservation

If a source contract is accepted and compiled in UO mode, then each
confidential entrypoint is transformed so that:

- opcode/control-flow shape depends only on public inputs
- loop trip counts depend only on public bounds
- abort behavior is normalized into the compiled IR model
- emitted manifest gas is public-determined

### Theorem C: Exact-UO object theorem

For `UOCell`, `UOArray`, and full-scan `UOMap`, if two executions start from
states with equal public projections and differ only in secrets, then the
object-local `View_M+` traces are equal.

### Theorem D: ORAM local theorem

For the proof-grade ORAM backend, if two executions start from states with
equal public projections and differ only in secrets, then the induced
distribution of object-local `View_M+` is computationally indistinguishable
given only `L_oram`.

This theorem must be reduced to the underlying ORAM construction plus the
chosen cryptographic assumptions.

### Theorem E: Public gas theorem

For accepted confidential entrypoints, `gas_used` equals the manifest-declared
public gas budget and is therefore independent of secrets.

### Theorem F: Composition theorem

If each confidential object backend satisfies its local theorem and the
compiler emits only approved object operations, then the whole-entrypoint
execution satisfies the top-level exact-UO or computational-UO theorem.

## 5. Recommended Mechanization Strategy

Recommended first target: mechanize the artifact-level semantics in Lean 4.

Reasons:

- the runtime model is already small and algebraic
- theorem statements are about normalized traces rather than bit-level EVM
- Lean is a good fit for executable inductive semantics and proof layering

Suggested proof tree:

- `proof/lean/TraceModel.lean`
- `proof/lean/IRSemantics.lean`
- `proof/lean/ExactObjects.lean`
- `proof/lean/CompilerInvariant.lean`
- `proof/lean/Composition.lean`
- `proof/lean/OramGame.lean`

This repository does not yet include the Lean workspace. Adding the plan first
is intentional: the theorem boundary must be frozen before mechanization starts.

## 6. What Must Change Before The ORAM Is Actually Proofable

The current ORAM path is stronger than the original prototype, but it is still
not in a proof-grade state. The following changes are required.

### 6.1 Replace the surrogate payload format with a typed ORAM block format

Current issue:

- `oram_bucket_bytes` in [objects.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/objects.rs) is an artifact-specific fixed-size serialization.

Required change:

- define an explicit ORAM block type
- define bucket layout and padding as typed data
- make block serialization/deserialization total and proof-friendly

### 6.2 Replace ad hoc nonzero rerandomization with real cryptography

Current issue:

- [codec.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-store/src/codec.rs) provides marker-free encoding and rerandomization, but not a cryptographic confidentiality notion.

Required change:

- separate marker-hiding record encoding from cryptographic protection
- introduce an AEAD or IND-CPA encryption layer for buckets and metadata
- model keys, nonces, and rerandomization explicitly

### 6.3 Introduce a standard ORAM construction

Current issue:

- the current backend is a public-schedule surrogate with fixed-shape metadata rewrites.

Required change:

- implement a standard construction such as Path ORAM or Ring ORAM
- define bucket capacity `Z`, block size `B`, tree height `H`, stash bound `S`
- store the position map recursively or prove a bounded public-resident layer

### 6.4 Make randomness explicit in the runtime interface

Current issue:

- randomness is consumed internally through local RNG state in
  [objects.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/objects.rs).

Required change:

- thread an explicit coin source through ORAM operations
- distinguish public-determined schedule from secret-independent randomization
- make the security game and simulator interface exact

### 6.5 Separate logical state from physical storage in a proof-friendly API

Current issue:

- the ORAM logic is interleaved with the general object runtime.

Required change:

- move ORAM code into a dedicated module with a narrow interface:
  `access(read/write, key, value, state, coins) -> (result, state', transcript)`
- keep transcript generation explicit and side-effect free

### 6.6 Add explicit stash and failure semantics

Current issue:

- the current surrogate has no real stash discipline and no overflow theorem.

Required change:

- implement stash state
- define overflow behavior
- either prove negligible overflow or compile with public parameters that make
  overflow impossible within supported capacities

### 6.7 Enrich the manifest with proof-relevant ORAM parameters

Current issue:

- the manifest exposes gas and commit budgets, but not the full ORAM security
  parameters.

Required change:

- add proof-relevant fields such as:
  `oram_scheme`, `block_size`, `bucket_size`, `tree_height`,
  `stash_bound`, `recursion_depth`, `metadata_pages`, `accesses_per_call`

This should live near
[manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs)
and the manifest builder in
[lib.rs](/home/m285xu/update-oblivious-toolchain/compiler/uo-solc/src/lib.rs).

## 7. Proof-Oriented Refactor Plan

The most efficient implementation path is:

1. Freeze the artifact theorem boundary in this document.
2. Extract ORAM logic from
   [objects.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/objects.rs)
   into a dedicated module with explicit transcript outputs.
3. Introduce typed bucket/block/state structs and explicit serialization.
4. Split marker-hiding encoding from cryptographic encryption.
5. Upgrade the surrogate to a standard ORAM construction.
6. Add manifest fields for ORAM security parameters.
7. Only then start mechanized proofs.

## 8. Immediate Next Engineering Tasks

The next code changes that would make this plan executable are:

1. Create a dedicated ORAM runtime module, for example
   `/runtime/uo-evm/src/oram.rs`, and move the current ORAM state machine there.
2. Replace `oram_bucket_bytes` with typed `OramBlock` and `OramBucket`
   serialization.
3. Introduce a `Transcript` type for ORAM access operations rather than
   constructing trace events inline.
4. Extend the manifest and checker with explicit ORAM parameter fields.
5. Add a `proof/` workspace scaffold for Lean files once the runtime interface
   is stable.

## 9. Definition Of Done For A Proof-Grade ORAM Milestone

Do not claim a proof-grade computational-UO ORAM until all of the following are
true:

- a standard ORAM construction replaces the current surrogate
- cryptographic assumptions are stated explicitly
- the leakage function is stated explicitly
- a simulator-based theorem is written down and mechanized
- the implemented runtime matches the proved model
- the results bundle is regenerated against the proved transcript model

Until then, the correct description of the repository is:

- exact-UO for the exact backends on the instrumented abstract machine
- computational-UO artifact evidence for the current ORAM path on the same
  abstract machine
