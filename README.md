# UO Toolchain

This repository contains a research-grade prototype of an update-oblivious
toolchain for a restricted Solidity subset. The repository centers on a
compiled artifact plus an instrumented confidential runtime; today it does not
target "deploy raw EVM bytecode to a public chain" as its main execution
model.

Components:

- `compiler/uo-solc`: parses sidecar-annotated Solidity, validates the
  supported subset, lowers to explicit UO IR, and emits theorem-facing
  manifests.
- `runtime/uo-evm`: executes raw and UO artifacts in-process, emits
  instrumented `M+` traces, and exports checked refinement witnesses for the
  Lean model.
- `checker/uo-check`: rejects unsupported source programs, validates compiled
  artifacts, and is the main translation-validation/security-gate path for
  proof-relevant compiler output.
- `probe/mplus-probe`: runs paired leakage experiments, correctness checks,
  witness/certificate validation, and writes the reproducible `results/`
  bundle.
- `benches/raw`: the benchmark suite plus raw/UO metadata.
- `benches/uo`: generated UO artifacts.

Current claim boundary:

- exact-UO for exact backends (`UOCell`, `UOArray`, full-scan `UOMap`) on the
  repository's instrumented abstract machine
- theorem-facing computational-UO only on the `path_oram_local_posmap_v1`
  backend path; the legacy surrogate backend remains for benchmarking and
  compatibility, not for strengthened proof claims
- Lean-checked observer models, reduction layers, runtime witness/certificate
  validators, and a frozen imported standard Path ORAM theorem target
- the implementation bridge from source/artifact/runtime output into that
  theorem boundary is now explicit and executable under the current
  `PathOramLocalPosmapV1SecurityAssumptions` bundle
- no current blanket claim that the full Rust compiler/runtime stack or a
  malicious-host SGX deployment already satisfies the final paper theorem

Paper-main theorem strategy:

- theorem-boundary fact: the paper route and the appendix / artifact route use
  the same frozen theorem interface
- current paper choice: use the citation route, with the JACM Path ORAM theorem
  as the external theorem source at the frozen
  `PathOramLocalPosmapV1StandardTheoremTarget` interface, modeled by
  `PaperMainPathOramTheoremSourceAt`
- appendix / artifact route: keep the self-instantiated theorem object at the
  same interface so the current artifacts can be checked end to end today
- future work: keep the stronger external-theorem import route alive, but only
  as a future strengthening until an actual external theorem artifact can be
  aligned to that interface
- the theorem boundary does not change between those two routes; only the
  provenance of the ORAM core theorem object changes

Strengthened closure plan:

1. keep `path_oram_local_posmap_v1` as the only proof-grade backend target
2. tighten `uo-check` into source-to-artifact translation validation for
   proof-relevant fields
3. prove that the runtime witness/certificate bundle emitted by `uo-evm`
   satisfies the Lean refinement interface for the supported backend path
4. use the citation route as the current paper theorem source, keep the current
   self-instantiated closure as appendix / executable artifact support at the
   same frozen interface, and treat the stronger import route as future work
5. reuse the existing projection lemmas for computational-UO, TEE-storage, and
   paper-facing SGX consequences

Build and validate:

```bash
./scripts/run_all.sh
```

Useful individual commands:

```bash
./scripts/compile_benches.sh
cargo test
./scripts/run_bridge_validation.sh
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
[docs/engineering-note.md](docs/engineering-note.md),
[docs/imported-theorem-bridge-checklist.md](docs/imported-theorem-bridge-checklist.md),
[docs/paper-main-theorem-checklist.md](docs/paper-main-theorem-checklist.md),
[docs/path-oram-citation-import-plan.md](docs/path-oram-citation-import-plan.md),
[docs/stronger-import-route-feasibility.md](docs/stronger-import-route-feasibility.md),
[docs/implementation-roadmap.md](docs/implementation-roadmap.md), and
[docs/formal-proof-plan.md](docs/formal-proof-plan.md).
