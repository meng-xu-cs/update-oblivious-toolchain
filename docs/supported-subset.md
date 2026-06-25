# Supported Source DSL

The accepted source language is `uo-solidity-like-dsl-v1`: a restricted,
Solidity-shaped DSL parsed through `solang_parser` and lowered to the
post-resolution Sol AST consumed by Lean. It is not currently a theorem claim
over full Solidity 0.8 semantics.

Accepted source features in this prototype:

- `bool`, `uint256`, `bytes32`, `address`
- arithmetic, bitwise operators, comparisons, and boolean connectives over the
  supported scalar types
- fixed-size arrays with compile-time public length
- fixed-size structs of supported scalar fields
- `if/else`
- bounded `for` loops of the form `for (uint i = 0; i < N; i++)`
- state cells, fixed arrays, and mappings with explicit public capacities in sidecar metadata
- pure/view internal helpers that consist of a single return expression
- `require(expr);`
- `keccak256(abi.encodePacked(...))` on fixed-size arguments
- public environment reads for `msg.sender`, `tx.origin`, `block.number`,
  `block.timestamp`, and `block.chainid`; these are manifest-bound public
  inputs, not secrets
- explicit public getter/setup entrypoints and explicit confidential entrypoints
- single return values on admitted functions
- state-map lowering through sidecar metadata rather than unconstrained native
  Solidity mapping semantics

Rejected:

- inline assembly / Yul
- events, custom errors, `revert`, `try/catch`
- `while`, `do while`, `break`, `continue`
- dynamic arrays, `string`, dynamic `bytes`
- unbounded `mapping`
- inheritance, modifiers, constructors/fallbacks/receive
- early confidential returns
- external calls and unsupported function-call shapes
- multi-expression internal functions beyond single-expression pure/view helpers
- multiple return values
- integer widths other than `uint256`

Sidecar metadata requirements:

- every state object must declare `kind`, `backend`, and confidentiality
- every externally callable entrypoint must have an explicit sidecar stanza;
  public entrypoints must say `confidential: false`, and confidential
  entrypoints must say `confidential: true`
- every entrypoint must declare `returns` as `forbidden`, `public`,
  `declassified`, or `encrypted_to_client`; encrypted client returns are
  supported only on confidential entrypoints and require callers to use the
  runtime return-channel session API
- every entrypoint must declare `status` as `public` or `declassified`
- `returns: declassified` requires `declassifies: [return]`, and
  `status: declassified` requires `declassifies: [success]`
- `returns: encrypted_to_client` must not declare `declassifies: [return]`;
  the host-visible outcome contains ciphertext, nonce, AAD hash, and session
  binding evidence, not the plaintext return
- an entrypoint may set `initializer: true` to mark the one-time public setup
  phase; when a contract has an initializer, other entrypoints default to
  `requires_initialized: true` unless explicitly set otherwise
- entrypoints that write data or predicates derived from confidential state or
  secret arguments into public state must name those public objects in
  `public_state_declassifies`
- every map must declare a public `capacity`
- map and array capacities must be positive
- confidential entrypoints must declare `secret_args`
- `oram_scheme` must be set explicitly when a proof-grade ORAM path is
  intended; `path_oram_local_posmap_v1` remains capped at capacity `128`,
  while larger theorem-facing maps use `path_oram_private_posmap_v1` with
  compact symbolic position-map evidence. Multi-access entrypoints (the same
  map touched more than once per call) are supported only by the bounded
  `path_oram_local_posmap_v1` route (capacity `128`); `path_oram_private_posmap_v1`
  admits only one logical access per map per entrypoint, and a multi-access
  private-posmap entrypoint is rejected at compile time with a diagnostic
  naming the limitation
- gas budgets may be supplied explicitly and are otherwise derived into the emitted manifest
- generated artifacts carry an admitted-package hash over the source-language
  tag, source bytes, canonical sidecar metadata JSON, compilation mode,
  compiler version, toolchain manifest digest, and package schema tag; the
  proof-grade translation bundle requires the source and artifact package
  identities to match

Execution-model notes:

- accepted `uint256` syntax is executed in the EVM unsigned 256-bit domain;
  Rust runtime values, canonical fixed-size encodings, compiler literals, and
  the Lean IR evaluator all normalize arithmetic modulo `2^256`, with division
  or modulo by zero returning zero. This deliberately differs from Solidity
  0.8 checked arithmetic and division/modulo-by-zero revert behavior until a
  versioned Solidity semantics bridge is proved.
- `keccak256(abi.encodePacked(...))` is supported by the runtime with real
  Keccak over canonical fixed-size bytes, but the current Lean source/IR/kernel
  preservation proofs use a deterministic mock hash. They prove preservation
  through the shared abstraction, not value-level equality with the real
  Keccak output.
- The Lean bridge target for regaining a Solidity 0.8 theorem claim is
  `VersionedSoliditySemanticsBridge` in
  `proof/lean/UOToolchain/SolidityDialectBoundary.lean`. It names the required
  obligations for checked arithmetic, division/modulo-by-zero, ABI encoding,
  revert/rollback, and any Solidity context variables beyond the admitted
  public environment fields listed above.
- source-to-kernel correctness is stated for the post-resolution Sol AST / UO
  IR consumed by the Lean model. Parser-level preprocessing remains trusted
  until a raw-source-to-post-resolution witness relation is mechanized.
- confidential entrypoints may target only state objects marked
  `confidential: true`, and those objects may not use raw backends. The direct
  Lean proof-grade checker, compiler lowering, and runtime admission enforce
  the raw-backend restriction; compiler lowering and the proof-grade
  translation checker also enforce the confidential-object restriction.
