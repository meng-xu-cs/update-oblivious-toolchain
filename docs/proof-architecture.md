# Proof Architecture

This document explains how the checked artifacts connect to the paper claim.

## Source And Compiler Layer

The proof-facing compiler story starts from the post-resolution Sol AST / UO IR
accepted by the Lean model. The important Lean modules are:

- `UOToolchain.Sol`
- `UOToolchain.IRSyntax`
- `UOToolchain.IRSemantics`
- `UOToolchain.CompilerInvariant`
- `UOToolchain.KernelDsl`
- `UOToolchain.TranslationValidationJson`

The direct checker `checkProofGradeTranslationArtifacts` is an executable proof
witness for concrete source/artifact pairs. It is not the trust root: compiler
correctness is represented by Lean theorems over the admitted post-resolution
language, while parser/preprocessing remains the explicit front-end trust
surface.

## Runtime Bridge

Runtime execution emits or supports these proof-facing objects:

- controller observer certificate
- hidden Path ORAM certificate
- runtime kernel witness
- runtime kernel refinement witness
- trusted-kernel and trusted-kernel slot bundles
- shell-boundary and shell-boundary lowering bundles
- confidential-core and slot/lowering bundles
- runtime witness families and canonical Path ORAM pair artifacts

The runtime boundary and trusted-kernel details are owned by
[`runtime/trusted-kernel.md`](./runtime/trusted-kernel.md) and
[`runtime/secret-state.md`](./runtime/secret-state.md).

## Lean Layers

The proof development is organized around these layers:

- Core semantics: `TraceModel`, `HistorySemantics`, `IRSemantics`,
  `ExactObjects`, `Composition`.
- Confidential fragment and shared DSL: `ConfidentialFragment`,
  `ConfidentialKernelDsl`, `KernelDsl`.
- Runtime boundary: `RuntimeTrustedKernel`, `RuntimeRefinement`,
  `RuntimeShellBoundary`, `RuntimeImplementationInterface`.
- Runtime generated/helper semantics: store codec/helper semantics, ORAM helper
  semantics, allocator/statement-trace/write-log/small-map/array/return-tail
  disciplines.
- ORAM theorem route: `OramGame`, `StandardOramReduction`,
  `PathOramSecurity`, `PathOramLocalPosmapV1`,
  `PathOramJACMTheorem`, `PaperPathOramTheoremRoute`.
- SGX/TEE observer: `SgxBoundary`, `SgxRelation`, `SgxController`,
  `SgxControllerTrace`, `SgxMicroModel`, `SgxObserverFreeze`,
  `TeeDeployment`.

The default `UOToolchain` umbrella imports `UOToolchain.ProofGradeRoot`.
Legacy axiom-backed demonstrations are isolated behind `UOToolchain.LegacyRoot`
and should not be used to support proof-grade claims.

## Validation Reports

The probe writes machine-readable evidence under `results/`. The most useful
entry points are:

- `bridge_validation.json`: focused translation/runtime bridge validation
- `static_checks.json`: proof-grade root and drift-surface checks
- `kernel_model_alignment_validation.json`: Rust/Lean vocabulary and observer
  alignment
- `tamper_validation.json`: negative tests proving drifted artifacts are
  rejected
- `reviewer_summary.md`: generated reviewer-facing summary
- `reproducibility_manifest.json`: output paths, sizes, toolchain pin, and
  SHA-256 digests

Generated result prose is not hand-maintained. Change the probe renderer if a
generated report needs different wording.

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

Common development slice:

```bash
cargo fmt --all
cd proof/lean
lake build UOToolchain.ProofGradeRoot
cd ../..
cargo check -p mplus-probe
cargo run -q -p mplus-probe -- --only static-checks --out-dir results
git diff --check
```

Use a narrower `lake build` target when changing one theorem family, but keep
the matching probe report in the validation slice.

## Update Rule

When a theorem or boundary changes:

1. Update the Lean theorem/checker route first.
2. Update the probe report bit and static-drift coverage.
3. Update the owning topic document only if the durable claim, TCB, assumption,
   observer, or validation surface changed.
4. Avoid adding a new roadmap/checklist unless the task genuinely cannot be
   completed in the current change; fold it back into the topic document when
   complete.
