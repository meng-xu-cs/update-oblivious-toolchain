# Supported Subset

Accepted Solidity features in this prototype:

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

Sidecar metadata requirements:

- every state object must declare `kind`, `backend`, and confidentiality
- every externally callable entrypoint must have an explicit sidecar stanza;
  public entrypoints must say `confidential: false`, and confidential
  entrypoints must say `confidential: true`
- every entrypoint must declare `returns` as `forbidden`, `public`,
  `declassified`, or `encrypted_to_client`; the current runtime rejects
  `encrypted_to_client` until an encrypted return channel is implemented
- every entrypoint must declare `status` as `public` or `declassified`
- `returns: declassified` requires `declassifies: [return]`, and
  `status: declassified` requires `declassifies: [success]`
- every map must declare a public `capacity`
- confidential entrypoints must declare `secret_args`
- `oram_scheme` must be set explicitly when a proof-grade ORAM path is
  intended; the theorem-facing route is `path_oram_local_posmap_v1`
- gas budgets may be supplied explicitly and are otherwise derived into the emitted manifest

Execution-model note:

- accepted `uint256` syntax is executed by the current prototype in a bounded
  `u128` domain; the Lean IR evaluator normalizes unsigned arithmetic,
  comparisons, negation, and div/mod-by-zero to match the Rust runtime's
  `u128` behavior rather than Solidity's full `uint256` arithmetic
- `keccak256(abi.encodePacked(...))` is supported by the runtime with real
  Keccak over canonical fixed-size bytes, but the current Lean source/IR/kernel
  preservation proofs use a deterministic mock hash. They prove preservation
  through the shared abstraction, not value-level equality with the real
  Keccak output.
- source-to-kernel correctness is stated for the post-resolution Sol AST / UO
  IR consumed by the Lean model. Parser-level preprocessing remains trusted
  until a raw-source-to-post-resolution witness relation is mechanized.
- confidential entrypoints may not target raw-backend objects at all; the
  direct Lean proof-grade checker, compiler lowering, and runtime admission
  all enforce this, and the proof path is exact backends plus
  `path_oram_local_posmap_v1`
