# Theorem Inventory and Gap Analysis

This file inventories the theorem/checker families I found and judges whether they support the stated paper theorem. File names are from the uploaded archive.

## Proof-grade root and axiom hygiene

| Area | Evidence | Assessment |
| --- | --- | --- |
| Proof-grade umbrella | `proof/lean/UOToolchain.lean` imports `UOToolchain.ProofGradeRoot`; `ProofGradeRoot.lean` imports proof-grade modules and excludes legacy roots. | Good. The default theorem surface avoids legacy demo axioms. |
| Legacy axiom isolation | `proof/lean/UOToolchain/OramGame.lean` and `SgxMicroGame.lean` contain legacy axioms; `results/static_checks.json` checks they are restricted. | Good. Keep this check in CI. |
| Named theorem axiom report | `proof/lean/CheckProofGradeAxiomReport.lean` pins `proofGrade_compiler_correctness_supersedes_artifact_checker`, `RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`, and `RuntimePaperNativeKernelAssumptions.paperEndToEndConfinementWithPublicOnlyHandwrittenShell` to standard Lean axioms only. | Strong practice. Add this checker to every release artifact. |

## Compiler/source/kernel theorem families

| Family | Representative modules | What it supports | Gap/concern |
| --- | --- | --- | --- |
| Source/IR syntax and semantics | `Sol.lean`, `IRSyntax.lean`, `IRSemantics.lean` | A post-resolution source/IR language and execution semantics. | The supported Solidity theorem starts after parser/preprocessing. Also, integer/type subset needs a stronger type-soundness theorem. |
| Compiler invariants | `CompilerInvariant.lean` | Secrecy preservation and public-gas independence in the model. | Must be extended to policy-aware public outcomes and all resource/failure paths. |
| Compiler exactness and translation | `CompilerExactness.lean`, `ProofGrade.lean`, `TranslationValidationJson.lean` | Lowering correctness, proof-grade translation bundle validation, demotion of artifact checker as trust root. | Proof-relevant views omit manifest return/status/declassification policy. This is a critical gap. |
| Kernel DSL lowering | `KernelDsl.lean`, `ConfidentialKernelDsl.lean`, `ConfidentialFragment.lean` | Expected runtime schedules and fragment validity. | Good for branchless/confidential kernel model; still needs typed source and policy exactness. |

## Exact-UO and composition theorem families

| Family | Representative modules | What it supports | Gap/concern |
| --- | --- | --- | --- |
| Exact object UO | `ExactObjects.lean` | Exact-UO for composed exact traces. | Exactness is about the model trace; it is not full Solidity/EVM or Rust semantics. |
| Composition | `Composition.lean` | Exact-UO with public gas; mixed artifact composition. | Needs policy-aware public outcome, finite history theorem, and explicit source+metadata package quantification. |
| History/adaptive surface | `HistorySemantics.lean` | Adaptive host strategies and public transcripts; ordered object schedule surface. | Useful definitions, but the headline theorem should quantify over finite adaptive histories with persistent state and fresh coins. |

## ORAM theorem families

| Family | Representative modules | What it supports | Gap/concern |
| --- | --- | --- | --- |
| ORAM model/security | `OramModel.lean`, `PathOramSecurity.lean`, `PathOramLocalPosmapV1.lean` | Computational-UO under public leakage and Path ORAM assumptions. | External JACM theorem is cited rather than imported; this is documented. Need concrete nonce/RNG/AEAD lifecycle binding. |
| Path ORAM route | `PaperPathOramTheoremRoute.lean`, `RuntimeCoins.lean`, `RuntimeCoinsJson.lean`, `RuntimeCanonicalPathOramPairJson.lean` | Seeded runtime witness families, fresh-coin/canonical pair validation, projection to paper route. | Very elaborate, but public outcome is currently the smaller `SGXPublicOutcome`; policy/payload fields are not part of that theorem surface. |
| Surrogate ORAM | Legacy/surrogate modules and manifests | Benchmarking/historical route. | Docs correctly exclude surrogate from strengthened proof-grade claim. Keep proof-grade checks ensuring surrogate is not used for paper claims. |

## Runtime theorem/checker families

| Family | Representative modules | What it supports | Gap/concern |
| --- | --- | --- | --- |
| Runtime trusted kernel | `RuntimeTrustedKernel.lean`, `RuntimeRefinement.lean` | Kernel witness/refinement, slot bundle schedule matching, final-state facts. | Runtime witness extraction and serialization are still trusted. Add transcript hash and independent replay routes. |
| Runtime implementation interface | `RuntimeImplementationInterface.lean` | Large source-backed/static boundary theorem surface; confinement and public-only handwritten shell facts. | Static-drift theorem statements should include source digests and version hashes as first-class proof inputs. |
| Shell/boundary lowering | `RuntimeShellBoundary.lean` and checkers | Public shell replay and boundary schedule checks. | Need stronger end-to-end host-visible error/resource closure. |
| Runtime audit surfaces | `RuntimeAuditSurfaces.lean` | Taxonomy of host-visible outcomes and assumptions. | Currently largely classificatory. Promote to a theorem that every concrete outcome belongs to the closed taxonomy and is public-determined/negligible/declassified as claimed. |

## SGX/TEE theorem families

| Family | Representative modules | What it supports | Gap/concern |
| --- | --- | --- | --- |
| SGX relation/projection | `SgxRelation.lean`, `SgxBoundary.lean`, `SgxObserverFreeze.lean`, exact/ORAM/joint projections | Paper-facing observer relation over public outcome, storage trace, micro trace. | The public outcome structure omits policy/payload/declassification fields listed in the claim boundary and Rust trace. This must be fixed or the claim weakened. |
| TEE deployment assumptions | `SgxDeploymentAssumptions`-related modules/docs | Explicit deployment assumptions. | Good as assumptions, but practical deployment artifacts/attestation/runtime hashes should bind to source+metadata+proof object hashes. |

## “Prove the wrong thing” risk register

1. **Observer mismatch.** Prose/Rust observer includes policy and payload; Lean `SGXPublicOutcome` does not. This is the top proof-framing issue.
2. **Policy translation omission.** Manifest policy fields are not in `ProofRelevantEntrypointView`, so proof-grade source/artifact equality is policy-insensitive.
3. **Program identity mismatch.** The theorem says source `P`, but the security-relevant program is `(P, metadata)`. The sidecar must be theorem-bound.
4. **Semantics mismatch.** The accepted source is described as Solidity `uint256`, but runtime/proof semantics are bounded `u128` and may accept other `uintN` syntactically.
5. **Capacity mismatch.** Array source length and metadata capacity can diverge.
6. **Single-call bias.** History definitions exist, but a user-facing contract claim should be history/adaptive/persistent-state by default.
7. **Resource/error channel omission.** Storage trace obliviousness does not imply host-visible error/resource outcome obliviousness unless all such paths are closed.
8. **Map correctness.** ORAM schedule security does not by itself prove that logical map behavior equals the source map semantics.

## Recommended theorem additions, in priority order

1. `PolicyAwarePublicOutcomeSafe`: equality/safety of entrypoint id, public args, termination status, status policy, output shape, return policy, return payload, declassification labels, and public gas.
2. `proofRelevantManifestPolicyExact`: proof-relevant translation view includes and exactly matches `returns`, `status`, and canonical `declassifies`.
3. `admittedPackageExact`: admitted program is `(source, metadata)` and artifact/runtime/proof object hashes bind to both.
4. `strictMetadataExplicit`: all security-critical metadata fields are present, no defaults in proof-grade mode.
5. `arrayCapacityMatchesSource`: fixed-array capacity equals source length.
6. `typedLoweringPreservesSemantics`: source typing/lowering preserves types and arithmetic semantics for the declared integer subset.
7. `hostVisibleErrorClosure`: every non-negligible host-visible failure/outcome is public-determined or explicitly declassified.
8. `adaptiveHistoryUO`: finite adaptive histories with persistent state satisfy exact/computational UO under backend assumptions.
9. `finiteMapRefinement`: raw/full-scan/ORAM maps refine a single finite-map spec.
10. `runtimeTranscriptAuthenticity`: accepted runtime proof objects are tied to a canonical event transcript produced by the actual runtime execution.
