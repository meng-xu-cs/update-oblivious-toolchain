# UO Toolchain Runbook

This runbook is an operator-oriented command reference. It is not a roadmap.
Current design and claim wording live under [`docs/`](docs/README.md).

## What Exists

- restricted Solidity-like DSL compiler and artifact emitter: `compiler/uo-solc`
- diagnostics checker: `checker/uo-check`
- in-process runtime and proof-object exporter: `runtime/uo-evm`
- Lean theorem/checker workspace: `proof/lean`
- benchmark sources and generated artifacts: `benches/raw`, `benches/uo`
- reproducible validation/report bundle: `results/`

## Accepted Surface

The accepted language and sidecar metadata surface is maintained in
[`docs/supported-subset.md`](docs/supported-subset.md). The short version:
fixed-size scalar/array/struct state, bounded `for` loops, explicit sidecar
capacities, explicit public/confidential entrypoints, manifest-bound public
environment inputs, and no external calls, dynamic storage, inheritance,
constructors/fallbacks, events, inline assembly, or early confidential returns.

## Main Commands

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

Reproducibility check:

```bash
./scripts/check_probe_reproducibility.sh --only static-checks
```

Instruction counts of a private-scheme tree node access before and after the
eviction networks of Issue 47 (needs valgrind, and lean and lake on PATH; not
part of `run_validation.sh`):

```bash
./scripts/measure_tree_eviction_instructions.sh
```

The matched baselines' full profile (Issue 49): three maps of different key
and value widths on every backend and capacity, filled to every occupancy
level (about 27 minutes on four cores; `run_validation.sh` runs the quick
profile):

```bash
cargo run -q --release -p mplus-probe -- --only matched-baselines-full --out-dir results
```

## Direct Entry Points

Compile a benchmark:

```bash
cargo run -q -p uo-solc -- --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --mode uo --out /tmp/fixedslot.json
```

Check an artifact:

```bash
cargo run -q -p uo-check -- --artifact /tmp/fixedslot.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml
```

Run the runtime. A default build prints the call's public receipt:

```bash
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()'
```

Inspect the whole trace and the proof-facing runtime outputs. They hold the
call's private evidence, so they need a build with the `diagnostics` feature:

```bash
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trace
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-witness
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-refinement-witness
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trusted-kernel
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format shell-boundary
cargo run -q -p uo-evm --features diagnostics -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format refinement-witness
```

## Artifact Modes

- `./scripts/run_validation.sh` uses the default compact artifact profile.
  Oversized canonical Path ORAM families and pair certificates remain validated
  through compact theorem-input certificates.
- `./scripts/run_heavy_artifact.sh` writes a separate heavy bundle with
  materialized large feasible canonical artifacts.
- Set `UO_CANONICAL_CERT_BUDGET_BYTES` and
  `UO_HEAVY_ARTIFACT_BUDGET_BYTES` to bound heavy-mode runs on smaller
  machines.

## Generated Results

The probe writes JSON and markdown under `results/`. Generated markdown should
not be hand-maintained; update `probe/mplus-probe` and regenerate if report
wording needs to change.
