# UO Toolchain

This repository contains a research-grade prototype of an update-oblivious toolchain for a restricted Solidity subset.

Components:

- `compiler/uo-solc`: parses sidecar-annotated Solidity, validates the supported subset, lowers to explicit UO IR, and emits a manifest.
- `runtime/uo-evm`: executes raw and UO artifacts with an instrumented `M+` trace model and fixed-shape UO commits.
- `checker/uo-check`: validates source contracts and compiled artifacts.
- `probe/mplus-probe`: runs paired leakage experiments, correctness checks, and writes the reproducible `results/` bundle.
- `benches/raw`: the mandatory Solidity benchmark suite plus raw/UO metadata.
- `benches/uo`: generated UO artifacts.

Build and validate:

```bash
./scripts/run_all.sh
```

Useful individual commands:

```bash
./scripts/compile_benches.sh
cargo test
./scripts/run_validation.sh
```

The current prototype is intentionally narrow. The exact supported subset, rejected features, remaining assumptions, and the formal proof roadmap are documented in [docs/supported-subset.md](/home/m285xu/update-oblivious-toolchain/docs/supported-subset.md), [docs/engineering-note.md](/home/m285xu/update-oblivious-toolchain/docs/engineering-note.md), and [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).
