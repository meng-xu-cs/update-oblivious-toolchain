# UO Toolchain Artifact Results

This results bundle was generated from the local Rust workspace using the benchmark suite under `benches/raw/`.

Security tiers:

- Exact-UO: `FixedSlotClassifier`, `AuthScan`, `ConfidentialMixer` full-scan, `ERC20Lite` full-scan, and `RegistryCRUD` use fixed-shape commits and normalized `M+` traces that are identical across secret variations in this instrumented abstract machine.
- Computational-UO: `ConfidentialMixer` ORAM and `ERC20Lite` ORAM use a public-schedule ORAM surrogate that rewrites fixed-shape control metadata and a logarithmic bucket batch while keeping `M+` update classes secret-independent.

Unsupported / rejected:

- inline assembly / Yul
- dynamic strings and dynamic bytes
- unbounded mappings and dynamic arrays without fixed public capacity
- recursion, `try/catch`, events, custom errors, `while` / `do while`, external calls, and early confidential returns

Prototype assumptions:

- `uint256` syntax is accepted, but the current executable prototype evaluates arithmetic in a bounded `u128` domain for the benchmark suite.
- The ORAM backend is an instrumented runtime prototype with fixed-shape committed control metadata and public-schedule bucket rewrites; it is reported as computational-UO only.
- The guarantees are with respect to the abstract/runtime traces emitted by this artifact, not every downstream machine-code or microarchitectural observer.
