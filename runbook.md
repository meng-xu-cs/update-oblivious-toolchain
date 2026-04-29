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

## Direct Entry Points

Compile a benchmark:

```bash
cargo run -q -p uo-solc -- --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --mode uo --out /tmp/fixedslot.json
```

Check an artifact:

```bash
cargo run -q -p uo-check -- --artifact /tmp/fixedslot.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml
```

Run the runtime:

```bash
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trace
```

Inspect proof-facing runtime outputs:

```bash
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-witness
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-refinement-witness
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trusted-kernel
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format shell-boundary
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format refinement-witness
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
