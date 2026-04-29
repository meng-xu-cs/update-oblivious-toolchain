# UO Toolchain

This repository contains a research-grade prototype of an update-oblivious
toolchain for a restricted Solidity-like UO DSL. It centers on compiled artifacts,
an instrumented confidential runtime, Lean-checked proof objects, and
reproducible validation reports. It does not target "deploy raw EVM bytecode to
a public chain" as its main execution model.

## Components

- `compiler/uo-solc`: parses sidecar-annotated Solidity-like source text,
  validates the supported DSL, lowers to UO IR, and emits theorem-facing
  manifests.
- `checker/uo-check`: CLI diagnostics and compatibility tooling; it is not in
  the proof-grade TCB.
- `runtime/uo-evm`: executes raw and UO artifacts in-process and emits traces,
  kernel witnesses, trusted-kernel bundles, shell-boundary bundles, and runtime
  refinement objects.
- `runtime/uo-kernel-runtime`, `runtime/uo-store`, `runtime/uo-allocator`, and
  `runtime/uo-precompiles`: shared runtime support for the small confidential
  kernel, sealed storage, bounded resource accounting, and opcode vocabulary.
- `crates/uo-core`: shared artifact, trace, manifest, confidential-kernel, and
  proof-object data structures.
- `probe/mplus-probe`: runs correctness/leakage/proof validation and writes
  reproducible `results/` bundles.
- `proof/lean`: Lean theorem models and executable proof-grade checkers.
- `benches/raw` and `benches/uo`: benchmark sources/metadata and generated UO
  artifacts.

## Current Claim Boundary

- Exact-UO is claimed for exact backends on the repository's instrumented
  abstract/runtime model: `UOCell`, `UOArray`, and full-scan `UOMap`.
- The theorem-facing computational-UO path is only
  `path_oram_local_posmap_v1`.
- The runtime-to-Lean bridge is explicit and executable: controller
  certificate, hidden Path ORAM certificate, trusted-kernel slot bundle,
  runtime kernel witness, shell-boundary bundles, refinement witnesses, seeded
  witness families, and canonical Path ORAM pair artifacts are validated by
  Lean-backed checkers.
- The source-backed runtime boundaries are source-frozen/static-drift evidence,
  not a full semantics-of-Rust refinement.

The canonical theorem statement, observer, TCB, assumptions, and non-claims are
in [`docs/claim-boundary.md`](docs/claim-boundary.md). The complete
documentation index is [`docs/README.md`](docs/README.md).

## Commands

Full validation:

```bash
./scripts/run_all.sh
```

Focused validation:

```bash
./scripts/run_bridge_validation.sh
./scripts/run_validation.sh
./scripts/run_heavy_artifact.sh
```

Direct compiler/checker/runtime examples:

```bash
cargo run -q -p uo-solc -- --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --mode uo --out /tmp/fixedslot.json
cargo run -q -p uo-check -- --artifact /tmp/fixedslot.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trace
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-witness
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trusted-kernel
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format refinement-witness
```

Useful probe entry points:

```bash
cargo run -q -p mplus-probe -- --only bridge-validation --out-dir results
cargo run -q -p mplus-probe -- --only tamper-validation --out-dir results
cargo run -q -p mplus-probe -- --only reviewer-summary --out-dir results
```

## Artifacts

`results/` contains committed reproducibility outputs. The most useful files
are:

- `bridge_validation.json`
- `tamper_validation.json`
- `static_checks.json`
- `kernel_model_alignment_validation.json`
- `reviewer_summary.json` and `reviewer_summary.md`
- `reproducibility_manifest.json`

`results/artifact_readme.md` and `results/reviewer_summary.md` are generated
probe outputs. Change the probe renderer, not those files directly, when their
wording needs to change.

## Documentation

Start with [`docs/README.md`](docs/README.md). The main topic documents are:

- [`docs/claim-boundary.md`](docs/claim-boundary.md)
- [`docs/supported-subset.md`](docs/supported-subset.md)
- [`docs/proof-architecture.md`](docs/proof-architecture.md)
- [`docs/path-oram.md`](docs/path-oram.md)
- [`docs/runtime/README.md`](docs/runtime/README.md)
- [`docs/coding-agent-conventions.md`](docs/coding-agent-conventions.md)
