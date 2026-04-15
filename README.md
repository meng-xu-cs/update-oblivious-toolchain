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
./scripts/run_heavy_artifact.sh
```

Artifact modes:

- `./scripts/run_validation.sh` keeps the default compact artifact profile. Oversized canonical Path-ORAM families and pair certificates stay validated through compact theorem-input certificates.
- `./scripts/run_heavy_artifact.sh` switches the probe into explicit heavy-artifact mode and writes a separate `results-heavy/` bundle with `heavy_artifacts/` materializations for the large feasible canonical families/pairs that exceed the default compact budget.

If you want to keep heavy-mode runs bounded on a smaller machine, set
`UO_CANONICAL_CERT_BUDGET_BYTES` and `UO_HEAVY_ARTIFACT_BUDGET_BYTES`
explicitly before invoking the scripts. That lets you materialize only the
small feasible canonical cases while still leaving the larger ones on the
compact theorem-input path.

The current prototype is intentionally narrow. The exact supported subset,
rejected features, remaining assumptions, and the formal proof roadmap are
documented in [docs/supported-subset.md](docs/supported-subset.md),
[docs/engineering-note.md](docs/engineering-note.md), and
[docs/formal-proof-plan.md](docs/formal-proof-plan.md).
