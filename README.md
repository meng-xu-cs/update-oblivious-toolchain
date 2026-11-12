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
- The computational-UO routes with a Lean instance are
  `path_oram_local_posmap_v1` and `path_oram_private_posmap_v1`. The local
  route is capped at capacity `128` and keeps a flat position map in
  encrypted metadata pages that every access scans in full. The private
  route lifts the cap and keeps a map as an oblivious AVL tree in one Path
  ORAM tree, whose nodes hold their children's leaves, so its position map
  recurses through the tree: a get or a put makes a fixed number of node
  accesses, logarithmic in the capacity, each reading and writing one path.
  The tree's algorithm is proved in Lean to implement a finite map and keep
  the tree balanced (`PathOramAvlMap`), and the runtime's operations are
  replayed against that model.
  Their paper-main theorems hold over admitted
  configurations given bundle evidence (`PathOramAdmitted`), with the public
  outcome, boundary schedule, and final-state premises discharged from the
  kernel models for admitted programs (`PathOramKernelPaperMain`). The
  bundle's leaf obligation follows from the leaf model without seed
  enumeration; the private route's configurations may mix maps of both
  schemes. The bundle is
  derived for a concrete single-access instance, and for the multi-access
  entrypoints from one runtime run per side, whose leaves are substituted for
  every other tape (`PathOramTapeWitness`; runtime runs on sampled tapes are
  checked against it), including an ERC20Lite `transferFrom` pair whose
  `balances` map uses the private route. See
  [`docs/path-oram.md`](docs/path-oram.md).
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

## Reproducible Environment

A scientific claim should not depend on an unrecorded local setup. The pinned
environment is defined by `rust-toolchain.toml` (Rust channel/components) and
`proof/lean/lean-toolchain` (Lean/Lake/Elan release). Two reproducible paths
materialize them:

- One-command local baseline:

  ```bash
  scripts/baseline.sh --focused   # fmt + probe check + Lean proof root + workspace tests
  scripts/baseline.sh             # full gate: also all-features tests + full validation
  ```

  Either invocation records the exact tool versions and content hashes used into
  `results/local-baseline/manifest.json` (git-ignored; it is machine-specific).

- Containerized environment that pins Rust, Lean/Lake/Elan, and system deps:

  ```bash
  docker build -f Dockerfile.validation -t uo-validation .
  docker run --rm -it uo-validation scripts/baseline.sh --focused
  ```

CI (`.github/workflows/ci.yml`) runs the focused baseline (formatting, Rust
tests, Lean proof root, focused probe validation) on every push/PR, and the full
validation as a manual (`workflow_dispatch`) or nightly (scheduled) job.

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
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()'
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trace
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-witness
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trusted-kernel
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format refinement-witness
```

The first `uo-evm` command prints the call's public receipt, which is all a
default build prints. The whole trace and the proof objects hold the call's
private evidence, so those formats exist only in a build with the
`diagnostics` feature.

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

[`docs/evaluation.md`](docs/evaluation.md) indexes every result file by the
evaluation question it answers and the command that produces it.

`results/artifact_readme.md` and `results/reviewer_summary.md` are generated
probe outputs. Change the probe renderer, not those files directly, when their
wording needs to change.

## Documentation

Start with [`docs/README.md`](docs/README.md). The main topic documents are:

- [`docs/claim-boundary.md`](docs/claim-boundary.md)
- [`docs/supported-subset.md`](docs/supported-subset.md)
- [`docs/proof-architecture.md`](docs/proof-architecture.md)
- [`docs/path-oram.md`](docs/path-oram.md)
- [`docs/evaluation.md`](docs/evaluation.md)
- [`docs/runtime/README.md`](docs/runtime/README.md)
- [`docs/coding-agent-conventions.md`](docs/coding-agent-conventions.md)
