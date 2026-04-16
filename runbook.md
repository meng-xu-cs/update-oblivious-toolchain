# UO Toolchain Runbook Status

This file used to be a build-from-scratch handoff. The repository now already
implements that toolchain, so the old imperative "must build" plan has been
retired.

Use this file as a current operator-oriented status note. The authoritative
claim-boundary wording lives in:

- `README.md`
- `docs/formal-proof-plan.md`
- `docs/implementation-roadmap.md`
- `docs/paper-theorem-profile.md`

## What Exists Today

- `compiler/uo-solc` parses a restricted Solidity subset, validates sidecar
  metadata, lowers contracts into explicit UO IR, emits runtime manifests, and
  writes compiled artifact JSON.
- `checker/uo-check` validates accepted source directly and also performs
  source-to-artifact translation validation for the proof-relevant
  function/object/manifest fields consumed by the theorem-facing bridge.
- `runtime/uo-evm` executes compiled artifacts in-process, supports exact
  backends plus the theorem-facing `path_oram_local_posmap_v1` backend, emits
  theorem traces, exports standalone controller and hidden Path-ORAM
  certificates, packages a `RuntimeTrustedKernelBundle`, and exposes checked
  refinement-witness extraction.
- `runtime/uo-store` now uses authenticated sealed records
  (`ChaCha20Poly1305` plus associated data) under the nonzero transport
  encoding instead of the older marker-hiding placeholder codec.
- `probe/mplus-probe` compiles the benchmark suite, runs correctness and
  leakage reports, validates runtime witnesses and certificates with Lean, and
  writes the reproducible `results/` bundle.
- `proof/lean` contains the mechanized observer models, runtime-refinement
  layer, trusted-kernel and witness validators, seeded/canonical Path-ORAM
  family and pair checkers, and the frozen standard-theorem import target for
  the concrete `path_oram_local_posmap_v1` backend.

## Accepted Surface

The current compiler/checker/runtime path accepts a narrow but concrete subset:

- scalar types `bool`, `uint256`, `bytes32`, and `address`
- fixed-size arrays with compile-time sizes
- fixed-field structs over supported scalar types
- `if/else`
- bounded `for` loops of the form `for (uint i = 0; i < N; i++)` with
  compile-time-constant bounds
- state cells, fixed arrays, and metadata-lowered mappings with explicit
  public capacities
- pure/view internal helper functions that consist of one returned expression
- `require(expr);`
- `keccak256(abi.encodePacked(...))` over supported fixed-width arguments

Rejected constructs include inheritance, constructors/fallbacks/modifiers,
events, custom errors, `revert`, `try/catch`, inline assembly, dynamic
arrays/bytes/string, `while`/`do while`, `break`/`continue`, external calls,
and early confidential returns.

## Current Claim Boundary

- exact-UO is claimed for exact backends on the instrumented abstract/runtime
  model: `UOCell`, `UOArray`, and full-scan `UOMap`
- theorem-facing computational-UO is routed only through
  `path_oram_local_posmap_v1`
- the runtime-to-Lean bridge is explicit and executable today:
  controller certificate, hidden Path-ORAM certificate, trusted-kernel
  bundle, runtime refinement witness, seeded witness family, paired
  certificates, and canonical fresh-coin artifacts all have Lean-backed
  validators
- the current paper route uses the citation-based JACM theorem source at the
  frozen interface, while the repository keeps the self-instantiated closure as
  appendix / executable-artifact support at exactly the same interface
- the repository does not currently claim a blanket theorem for all Rust code,
  all downstream machine code, or malicious-host SGX execution obliviousness

## Main Commands

Full validation:

```bash
./scripts/run_all.sh
```

Focused validation paths:

```bash
./scripts/run_bridge_validation.sh
./scripts/run_validation.sh
./scripts/run_heavy_artifact.sh
```

Direct compiler/checker/runtime entrypoints:

```bash
cargo run -q -p uo-solc -- --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --mode uo --out /tmp/fixedslot.json
cargo run -q -p uo-check -- --artifact /tmp/fixedslot.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint classify(uint256) --format trace
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint classify(uint256) --format trusted-kernel
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint classify(uint256) --format refinement-witness
```

## Remaining Work

The main remaining work is no longer "build the toolchain." It is theorem and
provenance strengthening:

- keep the claim surface explicit that `path_oram_local_posmap_v1` is the only
  proof-grade backend path and the legacy surrogate ORAM stays benchmark-only
- keep the small trusted boundary at the emitted certificate / bundle /
  witness-producing kernel rather than claiming the whole runtime is verified
- justify or import the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle cleanly
- if desired, replace the current citation route with a genuinely external
  machine-checked theorem import at the same frozen interface
- do not upgrade the repository into a malicious-host SGX execution theorem
  until the enclave controller and SGX observer are connected to the real
  implementation by the same refinement discipline

## Historical Note

The previous long runbook mixed accurate threat-model guidance with a large
amount of now-stale "required work" text. It was removed so the repository
does not continue to present completed implementation work as if it were still
only a plan.
