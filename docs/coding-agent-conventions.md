# Coding-Agent Conventions

This document describes how to change the repository without weakening the
paper claim or losing validation coverage. It owns process, not theorem facts.

## Canonical Docs

Use [`README.md`](../README.md) for the project overview and
[`docs/README.md`](./README.md) for the documentation inventory.

Topic-owned sources of truth:

- theorem, observer, TCB, assumptions, and non-claims:
  [`claim-boundary.md`](./claim-boundary.md)
- proof/checker structure and validation reports:
  [`proof-architecture.md`](./proof-architecture.md)
- accepted Solidity/metadata subset:
  [`supported-subset.md`](./supported-subset.md)
- Path ORAM theorem/provenance route:
  [`path-oram.md`](./path-oram.md)
- runtime trusted boundary, TEE observer, and secret-state ownership:
  [`runtime/README.md`](./runtime/README.md)

Do not add a parallel roadmap or checklist when a durable topic document is the
right home.

## Claim Discipline

Use precise claim language:

- **Lean-proved**: a theorem exists and is projected through the checker route
  used by the paper story.
- **Generated-and-checked**: Rust is generated from Lean or exact-source
  checked against a generator/source cut.
- **Source-frozen/static-drift checked**: probe checks reject representative
  source drift; this is not semantic Rust verification.
- **Empirically tested**: cargo/probe tests exercise behavior but do not
  discharge the TCB.
- **Trusted**: the component remains in the TCB and must be listed as such.

Do not use "verified" or "proved" for facts that are only source-frozen,
statically checked, or empirically tested.

## Projection Pattern

When adding a new helper/kernel theorem that supports the paper route, project
it through the established layers:

1. State/prove the base theorem in the appropriate Lean semantics file.
2. Forward it through `RuntimeImplementationInterface` or the relevant
   boundary module.
3. Forward it through the paper-native assumption/boundary layer.
4. Expose the imported JSON projection.
5. Expose checker-side aliases on every route that the paper claim uses.
6. Emit a probe report bit ending in `_theorem_checked`.
7. Add static-drift coverage for the theorem name, report bit, and projection
   aliases.

For residual-helper-shell facts, keep the residual-helper route and the direct
kernel-machine confinement route in sync. A theorem exposed on only one route
weakens the story and usually leaves a drift gap.

## Validation Slice

Use the narrowest validation slice that covers the changed boundary, then run
the generic checks:

```bash
cargo fmt --all
cd proof/lean
lake build UOToolchain.ProofGradeRoot
cd ../..
cargo check -p mplus-probe
cargo run -q -p mplus-probe -- --only static-checks --out-dir results
git diff --check
```

For runtime/proof-boundary changes, also run the affected focused probe report
and the matching tamper/static-drift scenario. For broad changes, run:

```bash
./scripts/run_all.sh
```

Before declaring success:

- probe commands exit with status `0`
- positive reports contain top-level `"accepted": true`
- `tamper_validation.json` scenarios are rejected as expected
- `git diff --check` is clean

## Generated Artifacts

Generated Rust/Lean artifacts should usually be changed at their generator or
Lean source of truth and then regenerated. Direct edits are acceptable only
when the file is intentionally the current source cut and the source-freeze
checks are updated in the same change.

Generated markdown under `results/` is probe output. Do not hand-maintain it;
update `probe/mplus-probe` and regenerate.

## Working Practices

- Prefer small, reviewable patches.
- Do not revert unrelated dirty files.
- `cargo fmt --all` runs from the repo root.
- `lake build` runs from `proof/lean`.
- Run `cargo check -p mplus-probe` after probe edits.
- The probe's source-cut list lives in
  `runtime_implementation_interface_artifact()`; new runtime/source files must
  be added there and to the corresponding Lean boundary if they are part of the
  proof-facing implementation surface.
- `uo-check` and `mplus-probe` are not in the proof-grade TCB.
- Treat Lean linter warnings in older modules as background unless they
  accompany build failures or missing report bits.

## Common Pitfalls

- Cargo crate names and Rust `use` names can differ, e.g. `tiny-keccak` versus
  `tiny_keccak`.
- `sha2` in the workspace is used by the probe, not by the runtime crypto
  surface.
- In tamper output, `accepted: false` is expected; the important check is that
  each scenario has `rejected: true`.
- Forgetting one projection alias or report-bit list entry can allow silent
  drift.
- Running `lake build` from the repo root gives misleading target errors.

## Onboarding

Read in this order:

1. [`docs/README.md`](./README.md)
2. [`claim-boundary.md`](./claim-boundary.md)
3. [`proof-architecture.md`](./proof-architecture.md)
4. [`runtime/README.md`](./runtime/README.md)
5. the relevant Lean modules
6. `probe/mplus-probe/src/lib.rs`

Before editing a proof or runtime boundary, run a focused validation slice so
you know whether the starting point is already green.
