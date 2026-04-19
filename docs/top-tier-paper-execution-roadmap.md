# Top-Tier Paper Execution Roadmap

This roadmap treats every theorem-strengthening, assumption-reducing, and
trusted-surface-shrinking task as mandatory work for the final paper.

The target is not merely "Lean checks some emitted artifacts." The target is
one end-to-end theorem over the admitted Solidity subset, the concrete
`path_oram_local_posmap_v1` backend, the real confidential runtime kernel, and
an explicit hostile-host observer.

## Current Baseline

The repository has already closed several important proof-grade gaps.

- the proof-grade translation boundary is now the direct Lean checker
  `checkProofGradeTranslationArtifacts`, fed by separately materialized source
  and candidate artifacts
- `uo-check` is no longer part of that proof-grade acceptance path and is no
  longer in the proof-grade TCB
- confidential functions now carry the canonical named and slot DSL programs
  directly, and the direct Lean checker validates exact body-to-function-to-
  manifest agreement instead of relying on an ad hoc schedule-reconstruction
  path
- the theorem-facing backend path is frozen to `path_oram_local_posmap_v1`
- the runtime exports proof-grade kernel, refinement, and trusted-kernel proof
  objects, and Lean checks those objects with theorem-tight executable checkers
- the runtime already enforces the admitted public kernel schedule online for
  confidential entrypoints

The repository has not yet closed the scientifically strongest end-to-end
story. The remaining gaps are:

- there is not yet a machine-checked theorem that the real Rust kernel
  implementation refines the Lean kernel model
- there is not yet a machine-checked theorem that all secret-dependent runtime
  behavior is confined to that kernel
- there is not yet a source-to-kernel compiler correctness theorem for the
  admitted Solidity subset
- the concrete `PathOramLocalPosmapV1SecurityAssumptions` bundle is still only
  partially discharged
- the SGX/TEE deployment story is still weaker than a full malicious-host
  execution theorem

## Final Theorem Target

The paper should aim for exactly one flagship theorem:

> For every admitted Solidity source program `P`, if `uo-solc` compiles `P`
> to artifact `A`, the direct Lean source/artifact checker accepts that pair,
> the real runtime executes `A` and emits runtime proof objects accepted by
> Lean, and the explicit concrete backend / cryptographic / TEE assumptions
> hold, then the real host-visible execution satisfies the paper's update-
> obliviousness theorem against the stated hostile-host observer.

The exact claim surface should be frozen to:

- source language: the admitted Solidity subset only
- backend set: `path_oram_local_posmap_v1` only
- translation boundary: direct Lean checking of raw source/candidate artifacts
- runtime boundary: the tiny confidential kernel and its emitted proof objects
- deployment boundary: one explicit hostile-host observer
- trusted implementation surface: Lean kernel, explicit external assumptions,
  tiny runtime kernel, and nothing else

Everything else in this roadmap exists only to make that statement true.

## Non-Negotiable Design Decisions

These decisions make the paper scientifically stronger and more reviewer-proof.

- Keep exactly one proof-grade compiler boundary: direct source/candidate
  artifact checking in Lean.
- Keep exactly one proof-grade backend path: `path_oram_local_posmap_v1`.
- Keep exactly one runtime theorem boundary: a tiny confidential kernel with
  explicit proof objects.
- Keep exactly one hostile-host observer and state it explicitly in both docs
  and Lean.
- Prefer shared representations and shared interpreters over parallel
  implementations that merely agree by tests.
- Shrink the trusted Rust surface until no further meaningful shrinkage is
  possible; then prove the remaining kernel implementation refines the model.
- Do not broaden the theorem to fit the code. Reject unsupported behavior
  instead.

## Work Package 0: Freeze The Claim Surface

Objective: make the paper's theorem, observer, assumptions, and TCB precise
enough that every subsequent proof obligation is forced by them.

Primary files:

- [README.md](/home/m285xu/update-oblivious-toolchain/README.md)
- [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md)
- [docs/paper-theorem-profile.md](/home/m285xu/update-oblivious-toolchain/docs/paper-theorem-profile.md)
- [docs/paper-main-theorem-checklist.md](/home/m285xu/update-oblivious-toolchain/docs/paper-main-theorem-checklist.md)
- [docs/tee-runtime-hardening.md](/home/m285xu/update-oblivious-toolchain/docs/tee-runtime-hardening.md)
- [docs/trusted-kernel-verification.md](/home/m285xu/update-oblivious-toolchain/docs/trusted-kernel-verification.md)

Concrete tasks:

1. Write the flagship theorem in paper-ready and repo-ready form.
2. Freeze the hostile-host observer and make it the only deployment observer
   mentioned in top-level docs.
3. Freeze the backend, admitted Solidity subset, and proof-grade translation
   path.
4. Freeze the TCB statement and the explicit assumption table.
5. Remove any stale language that still sounds like "artifact validation near a
   theorem boundary" instead of "real implementation refinement to a model."

Deliverables:

- one theorem box
- one observer definition
- one assumption table
- one TCB table

Exit gate:

- every top-level security statement in the repository is traceable to either a
  theorem, an explicit assumption, or a trusted implementation component

## Work Package 1: Finish Shrinking To A Tiny Kernel

Objective: ensure every secret-dependent runtime effect is genuinely routed
through a tiny, auditable confidential kernel.

Primary files:

- [runtime/uo-evm/src/kernel.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/kernel.rs)
- [runtime/uo-evm/src/runtime.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/runtime.rs)
- [runtime/uo-evm/src/state.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/state.rs)
- [runtime/uo-evm/src/controller.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/controller.rs)
- [runtime/uo-evm/src/theorem.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/theorem.rs)
- [runtime/uo-allocator/src/lib.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-allocator/src/lib.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [crates/uo-core/src/kernel_dsl.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/kernel_dsl.rs)
- [crates/uo-core/src/trace.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/trace.rs)

Concrete tasks:

1. Audit every confidential runtime entrypoint and ensure it goes through
   `RuntimeKernel`.
2. Move allocator budget checks, scratch reservations, scratch wipes, and any
   runtime coin usage into explicit kernel-owned state transitions.
3. Remove or isolate any helper that can still perform secret-bearing work
   outside the kernel API.
4. Ensure witness generation is derived from real kernel execution rather than
   a parallel reconstruction path.
5. Keep the public shell outside the kernel limited to public-only logic.
6. Record a complete kernel-owned secret-state inventory and keep it current.

Deliverables:

- one closed kernel API for confidential work
- one explicit kernel state machine over objects, resources, and coins
- one auditable inventory of every remaining secret-bearing runtime structure

Exit gate:

- confidential work can be audited by reading the kernel boundary, not the
  entire runtime

## Work Package 2: Converge On A Shared DSL / Interpreter Route

Objective: have one canonical confidential-kernel program representation and
one semantics that both Rust and Lean use, rather than two parallel descriptions
that are only compared after the fact.

Primary files:

- [crates/uo-core/src/kernel_dsl.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/kernel_dsl.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [runtime/uo-evm/src/kernel.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/kernel.rs)
- [compiler/uo-solc/src/lib.rs](/home/m285xu/update-oblivious-toolchain/compiler/uo-solc/src/lib.rs)
- [crates/uo-core/src/manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs)
- [proof/lean/UOToolchain/ConfidentialKernelDsl.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ConfidentialKernelDsl.lean)
- [proof/lean/UOToolchain/RuntimeTrustedKernel.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeTrustedKernel.lean)
- [proof/lean/UOToolchain/RuntimeRefinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeRefinement.lean)

Concrete tasks:

1. Make the kernel DSL the canonical representation of admitted confidential
   work.
2. Make the runtime kernel execute that DSL directly or through a mechanically
   obvious interpreter boundary.
3. Make the Lean small-kernel semantics replay the same DSL, not a separately
   reconstructed schedule.
4. Make manifests and runtime witnesses point at that DSL-level program and its
   public schedule, not merely at duplicated opcode lists.
5. Eliminate any proof-grade path that relies on ad hoc schedule
   reconstruction when the DSL program is already available.

Deliverables:

- one shared DSL
- one shared public schedule notion
- one kernel interpreter story that exists in both Rust and Lean

Exit gate:

- the compiler, runtime, and Lean checker all talk about the same kernel
  program object

## Work Package 3: Prove Runtime-Kernel Refinement And Secret Confinement

Objective: upgrade from "the runtime emits accepted proof objects" to "the real
runtime kernel implementation refines the Lean model, and the rest of the
runtime is public-only."

Primary files:

- [runtime/uo-evm/src/kernel.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/kernel.rs)
- [runtime/uo-evm/src/engine.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/engine.rs)
- [runtime/uo-evm/src/state.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/state.rs)
- [runtime/uo-evm/src/runtime.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/runtime.rs)
- [probe/mplus-probe/src/lib.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/lib.rs)
- [proof/lean/UOToolchain/RuntimeRefinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeRefinement.lean)
- [proof/lean/UOToolchain/RuntimeTrustedKernel.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeTrustedKernel.lean)
- [proof/lean/UOToolchain/RuntimeShellBoundary.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeShellBoundary.lean)
- [proof/lean/UOToolchain/RuntimeCoins.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimeCoins.lean)

Concrete tasks:

1. Define the formal refinement relation between Rust kernel states and Lean
   kernel states.
2. Prove witness honesty by construction, not merely by post hoc checking.
3. Prove that trusted-kernel bundles and refinement witnesses are exact
   abstractions of real kernel execution.
4. Prove that shell-boundary logic outside the kernel is a public function of
   admitted public data.
5. Add static confinement checks where possible:
   visibility restrictions, type wrappers, and compile-time or probe-time
   assertions that secret-bearing structures are kernel-owned.
6. Either eliminate non-kernel secret buffers entirely or include them in the
   kernel model and wipe discipline.

Deliverables:

- one runtime-to-Lean refinement theorem
- one secret-confinement theorem or explicit confinement interface
- one small, auditable Rust kernel boundary that matches the Lean model

Exit gate:

- the paper can honestly say that the real runtime kernel refines the model and
  that secret-dependent work does not escape that kernel boundary

## Work Package 4: Prove Source-To-Kernel Compiler Correctness

Objective: connect the admitted Solidity subset to the kernel DSL and its
public schedule by proof, not only by artifact conformance checking.

Primary files:

- [compiler/uo-solc/src/lib.rs](/home/m285xu/update-oblivious-toolchain/compiler/uo-solc/src/lib.rs)
- [crates/uo-core/src/ir.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/ir.rs)
- [crates/uo-core/src/confidential_kernel.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/confidential_kernel.rs)
- [crates/uo-core/src/kernel_dsl.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/kernel_dsl.rs)
- [crates/uo-core/src/manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs)
- [crates/uo-core/src/translation_validation.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/translation_validation.rs)
- [proof/lean/UOToolchain/IRSemantics.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/IRSemantics.lean)
- [proof/lean/UOToolchain/CompilerInvariant.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/CompilerInvariant.lean)
- [proof/lean/UOToolchain/ConfidentialFragment.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ConfidentialFragment.lean)
- [proof/lean/UOToolchain/TranslationValidationJson.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/TranslationValidationJson.lean)

Concrete tasks:

1. Define the admitted Solidity subset semantics precisely enough for
   theorem-level compilation claims.
2. Prove correctness of lowering into the UO IR.
3. Prove correctness of confidential-fragment admission and rejection.
4. Prove correctness of lowering into the kernel DSL and its public schedule.
5. Prove that every manifest field used by the theorem is an exact semantic
   consequence of the source program.
6. Keep the direct Lean artifact checker, but demote it from "main trust
   argument" to "executable proof witness for the proven compiler story."

Deliverables:

- one source-to-IR correctness theorem
- one IR-to-kernel correctness theorem
- one exactness theorem for proof-grade manifest fields

Exit gate:

- the paper has a real source-to-kernel theorem for the admitted language

## Work Package 5: Discharge The Concrete Backend Assumptions

Objective: reduce the concrete backend assumption bundle until only genuinely
external cryptographic and deployment assumptions remain.

Primary files:

- [proof/lean/UOToolchain/PathOramLocalPosmapV1.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1.lean)
- [proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1Refinement.lean)
- [proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean)
- [proof/lean/UOToolchain/PathOramJACMTheorem.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramJACMTheorem.lean)
- [proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean)
- [proof/lean/UOToolchain/RuntimePaperInstantiation.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/RuntimePaperInstantiation.lean)
- [runtime/uo-evm/src/oram.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/oram.rs)
- [runtime/uo-store/src/store.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-store/src/store.rs)
- [runtime/uo-store/src/codec.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-store/src/codec.rs)
- [docs/path-oram-citation-import-plan.md](/home/m285xu/update-oblivious-toolchain/docs/path-oram-citation-import-plan.md)
- [docs/stronger-import-route-feasibility.md](/home/m285xu/update-oblivious-toolchain/docs/stronger-import-route-feasibility.md)

Concrete tasks:

1. Prefer a machine-checked theorem import at the frozen backend interface if a
   suitable external artifact can be imported cleanly.
2. Otherwise build the companion mechanization locally at that exact interface.
3. Discharge `stashOverflowBounded` for the deployed parameter regime.
4. Discharge `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` for the
   concrete cryptographic scheme boundary actually used by the runtime.
5. Prove that the store/codec/serialization layer matches the theorem-side
   storage abstraction.
6. Remove any assumption that survives only because of convenience engineering.

Deliverables:

- one minimized backend assumption bundle
- one explicit provenance route for every remaining backend assumption

Exit gate:

- every remaining backend assumption is concrete, justified, and unavoidable

## Work Package 6: Close The Hostile-Host TEE Theorem

Objective: move from an idealized TEE-storage theorem to a real malicious-host
execution theorem over an explicit observer.

Primary files:

- [proof/lean/UOToolchain/SgxBoundary.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxBoundary.lean)
- [proof/lean/UOToolchain/SgxRelation.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxRelation.lean)
- [proof/lean/UOToolchain/SgxController.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxController.lean)
- [proof/lean/UOToolchain/SgxControllerTrace.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxControllerTrace.lean)
- [proof/lean/UOToolchain/SgxExactProjection.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxExactProjection.lean)
- [proof/lean/UOToolchain/SgxOramProjection.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxOramProjection.lean)
- [proof/lean/UOToolchain/SgxJointProjection.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/SgxJointProjection.lean)
- [proof/lean/UOToolchain/TeeDeployment.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/TeeDeployment.lean)
- [docs/tee-runtime-hardening.md](/home/m285xu/update-oblivious-toolchain/docs/tee-runtime-hardening.md)

Concrete tasks:

1. Freeze the exact hostile-host observer and keep it aligned across docs and
   Lean.
2. Model enclave-boundary calls, persistent I/O, exits, and any admitted
   shared-resource or paging observations.
3. Prove that the real controller/runtime behavior refines that observer.
4. Prove that the sealing/storage path matches the theorem-side persistent
   model.
5. State attestation, rollback, crash, freshness, and patch-level assumptions
   explicitly and minimally.
6. Remove any remaining ambiguity between idealized TEE-storage security and
   malicious-host execution obliviousness.

Deliverables:

- one hostile-host deployment theorem
- one explicit deployment assumption bundle

Exit gate:

- the paper can claim malicious-host security without hiding the observer or
  the assumptions

## Work Package 7: Canonicalize The Proof Architecture And Artifact Story

Objective: make the final proof stack look minimal, inevitable, and easy to
review.

Primary files:

- [proof/lean/UOToolchain.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain.lean)
- [proof/lean/lakefile.lean](/home/m285xu/update-oblivious-toolchain/proof/lean/lakefile.lean)
- [probe/mplus-probe/src/lib.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/lib.rs)
- [probe/mplus-probe/src/main.rs](/home/m285xu/update-oblivious-toolchain/probe/mplus-probe/src/main.rs)
- [scripts/run_validation.sh](/home/m285xu/update-oblivious-toolchain/scripts/run_validation.sh)
- [scripts/run_bridge_validation.sh](/home/m285xu/update-oblivious-toolchain/scripts/run_bridge_validation.sh)

Concrete tasks:

1. Refactor the theorem stack so each layer has one abstraction function and
   one main theorem.
2. Make every proof-grade checker theorem-tight.
3. Remove compatibility shims from the main paper narrative.
4. Add tamper and negative tests for every theorem-facing artifact.
5. Make artifact generation deterministic and reproducible.
6. Report proof-checking cost, artifact size, runtime overhead, TCB size, and
   explicit assumptions.

Deliverables:

- one clean theorem stack
- one reproducible artifact pipeline
- one reviewer-facing proved/assumed/trusted table

Current artifact-side realization: the full probe bundle emits
`reviewer_summary.json` plus `reviewer_summary.md` as the machine-generated
reviewer-facing table over proof/report cost, artifact sizes, runtime
overheads, TCB surface, and explicit assumptions.

Exit gate:

- the paper and artifact tell the same minimal story with no hidden branches

## Critical Path

The shortest path to the strongest result is:

1. Work Package 0: freeze the exact theorem, observer, assumptions, and TCB.
2. Work Package 1: finish shrinking all secret-dependent behavior into the
   tiny kernel.
3. Work Package 2: finish the shared DSL / interpreter route so the compiler,
   runtime, and Lean semantics share one program object.
4. Work Package 3: prove runtime-kernel refinement and secret confinement.
5. Work Package 4: prove source-to-kernel compiler correctness.
6. Work Package 5: discharge or minimize the concrete backend assumptions.
7. Work Package 6: close the hostile-host TEE theorem.
8. Work Package 7: canonicalize the proof architecture and finalize the
   artifact story.

Work Packages 5 and 7 can progress in parallel once the interfaces from Work
Packages 0 through 4 are stable. Work Package 6 should not outrun Work Package
3, because the malicious-host theorem depends on a stable runtime/kernel
refinement story.

## Immediate Execution Queue

If implementation resumes immediately, the next concrete sequence should be:

1. Freeze the flagship theorem, observer, assumption table, and TCB table in
   the paper-facing docs.
2. Complete the confidential-kernel inventory and remove any remaining
   secret-bearing helpers outside the kernel boundary.
3. Make the kernel DSL the sole canonical representation of admitted
   confidential work across compiler, runtime, and Lean.
4. Eliminate any proof-grade schedule reconstruction path that duplicates an
   already available DSL program.
5. Add static confinement guardrails so only the kernel can own or manipulate
   secret-bearing runtime structures.
6. Prove runtime-kernel refinement for the shared DSL/interpreter route.
7. Prove that the non-kernel shell is public-only.
8. Prove source-to-kernel compiler correctness.
9. Minimize `PathOramLocalPosmapV1SecurityAssumptions`.
10. Close the hostile-host TEE theorem over the frozen observer.

## Validation Gates

Each milestone should keep the proof-grade path live. The minimum recurring
validation set is:

```bash
cargo test -p uo-solc
cargo test -p uo-check
cargo test -p uo-evm
cargo check -p mplus-probe
cd proof/lean && lake build \
  checkProofGradeTranslationArtifacts \
  checkProofGradeRuntimeKernelWitness \
  checkProofGradeRuntimeKernelRefinementWitness \
  checkProofGradeRuntimeWitness \
  checkProofGradeRuntimeShellBoundary \
  checkProofGradeRuntimeShellBoundaryLowering \
  checkProofGradeRuntimeConfidentialCore \
  checkProofGradeRuntimeConfidentialCoreSlot \
  checkProofGradeRuntimeConfidentialCoreLowering \
  checkProofGradeRuntimeConfidentialCoreShellBoundaryLowering \
  checkProofGradeRuntimeTrustedKernel
cargo run -q -p mplus-probe -- --only static-checks --out-dir /tmp/uo-static
cargo run -q -p mplus-probe -- --only shell-boundary-validation --out-dir /tmp/uo-shell-boundary
cargo run -q -p mplus-probe -- --only shell-boundary-lowering-validation --out-dir /tmp/uo-shell-boundary-lowering
cargo run -q -p mplus-probe -- --only confidential-core-validation --out-dir /tmp/uo-confidential-core
cargo run -q -p mplus-probe -- --only confidential-core-lowering-validation --out-dir /tmp/uo-confidential-core-lowering
cargo run -q -p mplus-probe -- --only confidential-core-shell-boundary-lowering-validation --out-dir /tmp/uo-confidential-core-shell-boundary-lowering
cargo run -q -p mplus-probe -- --only kernel-validation --out-dir /tmp/uo-kernel
cargo run -q -p mplus-probe -- --only trusted-kernel-validation --out-dir /tmp/uo-tk
cargo run -q -p mplus-probe -- --only tamper-validation --out-dir /tmp/uo-tamper
./scripts/check_probe_reproducibility.sh --only static-checks
```

Any phase that broadens the theorem, observer, or TCB must update the paper
docs and the Lean interface in the same change set.
