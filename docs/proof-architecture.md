# Proof Architecture

This document explains how the checked artifacts connect to the paper claim.

## Source And Compiler Layer

The proof-facing compiler story starts from the post-resolution Sol AST / UO IR
accepted by the Lean model for `uo-solidity-like-dsl-v1`. The important Lean
modules are:

- `UOToolchain.Sol`
- `UOToolchain.SolidityDialectBoundary`
- `UOToolchain.EnvironmentAuthModel`
- `UOToolchain.ScalablePathOramEvidence`
- `UOToolchain.IRSyntax`
- `UOToolchain.IRSemantics`
- `UOToolchain.CompilerInvariant`
- `UOToolchain.KernelDsl`
- `UOToolchain.TranslationValidationJson`

The direct checker `checkProofGradeTranslationArtifacts` is an executable proof
witness for concrete source/artifact pairs. It is not the trust root: compiler
correctness is represented by Lean theorems over the admitted post-resolution
DSL, while parser/preprocessing remains the explicit front-end trust
surface.

The Sol, IR, and kernel evaluators share one abort rule
(`EvalStatus.continuesBody`). Confidential entrypoints run their whole
linearized schedule: `require`, `abortIf`, and bounded-map capacity overflow
record the abort, and the commit boundary rolls the candidate state back,
exactly as the generated runtime kernel does. Public entrypoints stop at the
first abort, as the runtime shell does, and evaluation errors always stop.
Consequently the kernel-step schedule of every error-free confidential run,
aborted or not, is the program's static expected schedule
(`evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_continues`), and
`proofGrade_sol_kernel_steps_eq_of_continues` states that two such runs emit
the same kernel steps whatever their secret inputs.

`UOToolchain.KernelTyping` discharges the error-freedom premise.
`KernelProgram.wellTyped` type-checks a kernel program against the contract's
state layout: operators receive operands of their types, `select` arms agree,
struct fields exist, every index into a local or parameter array is a
compile-time constant below the array's length (the rule `uo-solc` enforces for
confidential entrypoints), and every write stores a value of the object's
declared type. `evalKernelProgram_continues_of_wellTyped` proves that a
well-typed program, run on arguments of its parameter types over a store that
holds every declared object with values of its type (`StoreConforms`), never
reports an evaluation error. With the schedule lemma above this gives
`evalKernelProgram_kernelSteps_eq_of_wellTyped`: two such runs emit the same
kernel steps, including programs whose only return is their last statement.
Through the Sol-to-kernel preservation theorem, the same holds for the source
function (`proofGrade_sol_kernel_steps_eq_of_wellTyped`). Running the type
checker on the kernel programs of concrete admitted artifacts is not yet part
of the proof-grade checker.

`UOToolchain.KernelExactTrace` turns the schedule result into exact
update-obliviousness of the storage trace. `evalKernelBodyExecuted` lists the
statements a run executes, following `evalKernelBody`'s control flow, and every
conforming run of an admitted program executes the whole body
(`evalKernelProgramExecuted_eq_body`). The exact store's encoding
(`exactEncodeRun`) maps the executed statements to a physical trace: a full
scan of the object for every storage access, in evaluation order, and at commit
an `Update`-class rewrite of every touched object, in object-id order. The
trace of a run is therefore the same for all admitted runs
(`admittedKernel_exactUO`), and
`paperMain_admittedKernel_exact_noninterference_moduloReleases` states the
paper-main theorem modulo releases over admitted runs with the storage-trace
premise discharged; its remaining premises are the public outcome, boundary
schedule, controller shape, final public state, and release functions. The
probe checks that the runtime's traces are exactly the encoding's prediction
(`exact_encoding_matches` in `trace_equivalence.json`).

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

- Core semantics: `TraceModel`, `HistorySemantics`, `EnvironmentAuthModel`,
  `IRSemantics`,
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
  `ScalablePathOramEvidence`, `PathOramJACMTheorem`,
  `PaperPathOramTheoremRoute`.
- SGX/TEE observer: `SgxBoundary`, `SgxRelation`, `SgxController`,
  `SgxControllerTrace`, `SgxMicroModel`, `SgxObserverFreeze`,
  `TeeDeployment`, `DeploymentAcceptance`.
- Paper-main theorem: `PaperMainTheorem`, `AcceptedPackageCapstone`, and
  `PaperMainReleases`. `PaperMainReleases` states the paper-main theorem and
  the accepted-package capstones modulo the declared releases
  (`View_SGX ∖ rel`) for the exact backend and both proof-grade Path ORAM
  routes; the release semantics is documented in
  [`claim-boundary.md`](./claim-boundary.md#declared-releases).

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
