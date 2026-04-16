# Proof Workspace

This directory is reserved for the mechanized proof artifacts referenced in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).

The repository now includes the first Lean scaffold under `proof/lean/`:

- `proof/lean/lakefile.lean`
- `proof/lean/lean-toolchain`
- `proof/lean/UOToolchain.lean`
- `proof/lean/UOToolchain/TraceModel.lean`
- `proof/lean/UOToolchain/IRSemantics.lean`
- `proof/lean/UOToolchain/ExactObjects.lean`
- `proof/lean/UOToolchain/CompilerInvariant.lean`
- `proof/lean/UOToolchain/Composition.lean`
- `proof/lean/UOToolchain/OramGame.lean`
- `proof/lean/UOToolchain/TeeDeployment.lean`
- `proof/lean/UOToolchain/SgxBoundary.lean`
- `proof/lean/UOToolchain/SgxRelation.lean`
- `proof/lean/UOToolchain/SgxController.lean`
- `proof/lean/UOToolchain/SgxControllerTrace.lean`
- `proof/lean/UOToolchain/SgxMicroGame.lean`
- `proof/lean/UOToolchain/SgxOramProjection.lean`
- `proof/lean/UOToolchain/SgxExactProjection.lean`
- `proof/lean/UOToolchain/SgxJointProjection.lean`
- `proof/lean/UOToolchain/RuntimeTrustedKernel.lean`
- `proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean`
- `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`

These files no longer only freeze the module split. They now contain executable
definitions, proved lemmas, certificate checkers, and concrete theorem-facing
boundaries. The engineering bridge from checked artifacts and emitted runtime
certificates into those theorem-facing objects is now implemented under the
explicit `PathOramLocalPosmapV1SecurityAssumptions` bundle. They still do not
justify a blanket claim that every layer of the Rust stack, or a malicious-host
SGX deployment, already satisfies the final paper theorem without additional
theorem discharge beyond the now-explicit trusted-kernel boundary.

Current status:

- `TraceModel.lean`, `IRSemantics.lean`, `ExactObjects.lean`, `CompilerInvariant.lean`, and
  `Composition.lean` now contain executable definitions and proved lemmas for
  normalized trace composition, public-projection equality, exact-UO closure
  under composition, and public-gas equalization.
- `OramGame.lean` now contains the concrete ORAM public-manifest model,
  public schedule extraction, secret-independence lemmas for leakage
  extraction, and manifest-budget lemmas for the current access schedule.
- `TeeDeployment.lean` now defines the idealized `View_TEE-Store` observer,
  proves that exact-UO artifact semantics transport to the TEE storage view,
  and packages the TEE deployment theorem boundary for the ORAM side.
- `SgxBoundary.lean` now fixes a concrete future `View_SGX` shape in Lean,
  including enclave-boundary events, paging, exits, shared-resource traces, and
  public output shape, while leaving raw timing and physical side channels out
  of scope.
- `SgxRelation.lean` now defines the recommended mixed proof relation for
  `View_SGX`: exact public constancy on public outcome and boundary schedule,
  plus abstract storage and micro-trace subrelations, together with a generic
  predicate expressing that a micro trace is budget-consistent with
  `L_sgx_micro`. The leakage object now also carries normalized controller
  phase order, ordered per-region page budgets, normalized exit pattern, and
  normalized shared-resource schedule.
- The paper-facing theorem profile is now explicit: `boundary_schedule` stays
  exact, while only the SGX micro observer is normalized and simulated from
  `L_sgx_micro`.
- `SgxRelation.lean` also proves that the current exact TEE-storage theorem
  embeds into a degenerate SGX semantics with empty boundary, paging, exit, and
  shared-resource traces.
- `SgxOramProjection.lean` now lifts the existing ORAM computational boundary
  into the mixed SGX relation, assuming the SGX public outcome, boundary
  schedule, and micro-trace envelope are public-safe functions of the public
  projection.
- `SgxExactProjection.lean` now lifts the exact artifact theorem into the same
  SGX relation under an arbitrary public-safe SGX envelope, not just the
  degenerate empty-trace case, and now also includes a normalized-controller
  lifting theorem matching the richer `L_sgx_micro` observer.
- `SgxMicroGame.lean` now introduces an explicit SGX-controller leakage object
  `L_sgx_micro` and a separate computational SGX micro-trace theorem boundary.
- `SgxController.lean` now models a nontrivial SGX controller shape with public
  phase plans, page-budget regions, workset bounds, and a derivation of
  `L_sgx_micro` from ORAM execution leakage.
- `SgxControllerTrace.lean` now turns that public controller shape into
  concrete page, exit, and shared-resource traces, and proves that the concrete
  trace lengths match the budgets recorded in `L_sgx_micro`.
- `SgxMicroGame.lean` now also contains an exact theorem for the deterministic
  public-controller instance, where the generated controller trace depends only
  on the public controller shape, and proves that every trace in that singleton
  distribution is consistent with the derived `L_sgx_micro`. It also defines a
  normalized simulator that reconstructs a normalized micro trace from
  `L_sgx_micro` alone and proves the real controller trace normalizes to that
  simulator output.
- `SgxJointProjection.lean` now models joint SGX samples carrying both storage
  and controller traces, and proves joint lifting theorems into the mixed
  `View_SGX` relation from separate storage and controller assumptions,
  including the richer normalized-controller observer.
- `SgxOramProjection.lean` now includes a concrete ORAM-to-SGX lifting theorem
  that instantiates the SGX micro trace with the public controller semantics
  rather than an arbitrary public-safe placeholder, plus a stronger theorem
  showing those traces normalize to the leakage-only simulator output under the
  richer `L_sgx_micro`.
- the SGX observer boundary in
  [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md)
  now includes explicit public output shape plus a ZeroTrace-derived split into
  boundary, paging, exit, and shared-resource traces
- the theorem-facing ORAM backend path is now the concrete
  `path_oram_local_posmap_v1` candidate; the legacy surrogate path is kept only
  as a compatibility/benchmark specialization and is not the strengthened claim
  path
- the theorem routes are now separated explicitly but remain equivalent at the
  frozen interface as theorem targets, but not as provenance claims:
  the current paper choice is the citation route at that interface, while the
  self-instantiated theorem object stays only as an appendix /
  executable-artifact cross-check at the same interface and the stronger
  external-theorem import route is kept only as future work
- the repo now also contains a concrete imported-theorem bridge checklist in
  [docs/imported-theorem-bridge-checklist.md](/home/m285xu/update-oblivious-toolchain/docs/imported-theorem-bridge-checklist.md),
  which records the completed engineering bridge under the current explicit
  assumption bundle independently of theorem-source provenance
- the paper-main theorem route itself is now tracked separately in
  [docs/paper-main-theorem-checklist.md](/home/m285xu/update-oblivious-toolchain/docs/paper-main-theorem-checklist.md),
  including the Lean naming split between the paper-main theorem source and the
  appendix / executable-artifact closure
- the recommended literature source, fallback source, and source-to-interface
  mapping are now collected in
  [docs/path-oram-citation-import-plan.md](/home/m285xu/update-oblivious-toolchain/docs/path-oram-citation-import-plan.md)
- the explicit bibliography entries for that citation route now live in
  [docs/path-oram-theorem-sources.bib](/home/m285xu/update-oblivious-toolchain/docs/path-oram-theorem-sources.bib)
- the feasibility boundary for a genuinely stronger external-theorem import
  route is now recorded in
  [docs/stronger-import-route-feasibility.md](/home/m285xu/update-oblivious-toolchain/docs/stronger-import-route-feasibility.md)
- [docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md)
  now also fixes a separate TEE/SGX deployment boundary:
  an idealized TEE storage theorem is in scope as a future deployment theorem,
  while SGX execution obliviousness against a malicious host is explicitly out
  of scope for the current repository state.

The theorem boundary and the required runtime/compiler changes are defined in
[docs/formal-proof-plan.md](/home/m285xu/update-oblivious-toolchain/docs/formal-proof-plan.md).

The paper-facing theorem statement corresponding to the current mechanization is
summarized in
[docs/paper-theorem-profile.md](/home/m285xu/update-oblivious-toolchain/docs/paper-theorem-profile.md).
