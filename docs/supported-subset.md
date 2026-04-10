# Supported Subset

Accepted Solidity features in this prototype:

- `bool`, `uint256`, `bytes32`, `address`
- fixed-size arrays with compile-time public length
- fixed-size structs of supported scalar fields
- `if/else`
- bounded `for` loops of the form `for (uint i = 0; i < N; i++)`
- state cells, fixed arrays, and mappings with explicit public capacities in sidecar metadata
- pure/view internal helpers that consist of a single return expression
- `require(expr);`
- `keccak256(abi.encodePacked(...))` on fixed-size arguments
- explicit public getter/setup entrypoints and explicit confidential entrypoints

Rejected:

- inline assembly / Yul
- events, custom errors, `revert`, `try/catch`
- `while`, `do while`, `break`, `continue`
- dynamic arrays, `string`, dynamic `bytes`
- unbounded `mapping`
- inheritance, modifiers, constructors/fallbacks/receive
- early confidential returns
- external calls and unsupported function-call shapes

Sidecar metadata requirements:

- every state object must declare `kind`, `backend`, and confidentiality
- every map must declare a public `capacity`
- confidential entrypoints must declare `secret_args`
- gas budgets may be supplied explicitly and are otherwise derived into the emitted manifest
