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
surface. The static checks run it on every benchmark artifact, compiled with
its raw sidecar bytes as the `uo-solc` CLI does, and the acceptance gate fails
if it rejects a UO artifact (`uo_artifact`, `oram_artifact`, ... in
`static_checks.json`); raw-mode artifacts are rejected by design. The `uo-check`
test `artifact_checker_accepts_every_uo_benchmark` applies the Rust artifact
checker to every UO benchmark sidecar, so a policy rule the compiler enforces
but a checker does not mirror fails the build.

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
function (`proofGrade_sol_kernel_steps_eq_of_wellTyped`). The admission
checker below runs the type checker on the kernel programs of the compiled
artifacts.

`UOToolchain.KernelExactTrace` turns the schedule result into exact
update-obliviousness of the storage trace. `evalKernelBodyExecuted` lists the
statements a run executes, following `evalKernelBody`'s control flow, and every
conforming run of an admitted program executes the whole body
(`evalKernelProgramExecuted_eq_body`). The exact store's encoding
(`exactEncodeRun`) maps the executed statements to a physical trace: one full
scan of every object a statement accesses, in object-id order, which the call
makes when it loads the object, however many statements access it
(`exactEncodeRun_reads_each_touched_once`, `exactEncodeRun_read_count`), and
at commit an `Update`-class rewrite of every object a statement writes, in
object-id order; an object the statements only read is not written
(`exactEncodeRun_rewrites_only_written`). The
trace of a run is therefore the same for all admitted runs
(`admittedKernel_exactUO`), and
`paperMain_admittedKernel_exact_noninterference_moduloReleases` states the
paper-main theorem modulo releases over admitted runs with the storage-trace
premise discharged; its remaining premises are the public outcome, boundary
schedule, controller shape, final public state, and release functions.
`UOToolchain.KernelExactTraceCheck` checks that the runtime's traces are
exactly the encoding (`exact_encoding_matches` in `trace_equivalence.json`,
by the `checkExactTrace` executable): from a call's artifact it decodes the
entrypoint's kernel program and the layout of each object the program
touches, and the trace's reads and writes must be those of `exactEncodeRun`
over that layout (`exactTraceMatches_sound`). A runtime trace holds the scan
and the rewrite of an object as one item each; the Lean importers expand an
item with the encoding's own `ExactObjectLayout.scanReads` and
`updateWrites` (`UOToolchain/ExactObjectLayout.lean`).

`UOToolchain.KernelFlow` is the Lean counterpart of the compiler's policy
analysis. Variables carry a public or secret label (parameters by
`secretArgs`; every storage read is secret, since a confidential kernel
targets only confidential objects), and `KernelProgram.flowSummary` reports
whether the status or the return value may depend on secrets: a `require` or
`abortIf` on a secret condition, or any map write (capacity overflow), makes
the status secret. `evalKernelProgram_flow_ni` proves the analysis sound: two
conforming runs of a well-typed program over the same contract, with arguments
that agree at public parameter positions, end with the same status when the
analysis reports a public status, and return the same value when it reports a
public return. `publicArgsAgree_of_layout` derives the argument agreement from
equal public arguments and the declared argument layout.

`UOToolchain.KernelPaperMain` discharges the remaining premises for
exact-backend entrypoints. It models the runtime's public observables of a
run: the public outcome (`kernelPublicOutcome`; an aborted call returns
nothing, so its output shape is erased), the final public-state record
(`kernelFinalPublicState`), and the enclave boundary schedule
(`kernelBoundarySchedule`: enter with the entry input, exit with the output
shape's return length). An `AdmittedKernelRun` is an admitted configuration
whose arguments have the declared layout, whose public store holds only public
objects, and whose program writes only confidential objects; such a program
leaves the public store unchanged (`evalKernelProgram_publicStateTransition`).
When the entrypoint's declared policies agree with the flow analysis
(`PolicyAgreesWithFlow`: a status that is not declassified is public, and a
return that is neither declassified nor encrypted to the client is public),
each modeled observable is public-determined outside its releases, and
`paperMain_admittedKernelRun_exact_noninterference_moduloReleases` proves the
paper-main theorem modulo releases with every premise discharged. The exit
event's output length is the return length, so it reveals whether the call
completed; the release erasure therefore clears it when the status is
released (`boundaryWithoutStatusRelease`). A value returned under
`encrypted_to_client` is in the modeled outcome as the payload of the call's
return channel and not in the clear, and the call exits with the payload's
wire length. The channel is a parameter of the theorems
(`ReturnChannelModel`): a function from the call's public arguments and the
returned value to a payload which, without its ciphertext and tag, does not
depend on the value. The release erases the ciphertext and the tag, so the
returned value may be secret. The probe checks the runtime's public outcomes,
boundary schedules, and final public-state records against these models on
every exact-route and Path ORAM experiment run, completed or aborted
(`outcome_model_matches` and `final_public_state_model_matches` in
`trace_equivalence.json`). Confidential
calls report the same record as public ones: the digests of the public state
before the call, as the call left it, and as committed, the digest of the
public delta (the ids of the public objects whose committed value changed), and
the abort flag.

`UOToolchain.KernelAdmission` makes the program-side premises checkable.
`KernelProgram.admissionCheck` decides well-typedness, return placement,
confidential-only writes, and policy agreement with the definitions the
theorem uses (`admissionCheck_sound`), so
`paperMain_checkedKernel_exact_noninterference_moduloReleases` needs only a
passing check, and `AdmittedKernelRun.ofAdmission` makes every run the runtime
sets up over the checked layout an admitted run. `checkKernelAdmission`
decodes a `uo-solc` artifact (the state layout, and each manifest entrypoint's
confidential program and policies) and reports the check per entrypoint. The
static checks run it on every compiled benchmark artifact and fail unless
every confidential entrypoint is admitted, and the tamper validation confirms
that it rejects a status or return relabelled public and a write to a public
object. An entrypoint that accesses an ORAM map is reported on the `path_oram`
route: the exact theorem covers neither its storage trace nor its boundary
schedule, which include the Path ORAM accesses. An entrypoint that accesses a
raw object is on no supported route and is not admitted.

`UOToolchain.PathOramKernelPaperMain` discharges the same premises on the
`path_oram` route. The public outcome and the final public-state record are
the kernel models of the run an ORAM configuration denotes; their safety rests
on the flow analysis and on the program writing only confidential objects, not
on how a map is stored. The boundary schedule is the runtime controller
certificate's for a call with the entrypoint's number of ORAM accesses
(`kernelOramBoundarySchedule`, equal to
`RuntimeControllerCertificate.boundarySchedule` and, with no accesses, to
`kernelBoundarySchedule`): enter, an exit and a re-entry around each access,
and exit with the return length, so only the last event depends on the run.
A `KernelDenotation` links the ORAM model's configurations to kernel runs:
admitted configurations denote admitted runs, and configurations with the same
public projection denote runs with the same public projection. With it,
`paperMain_admittedKernelRun_pathOramLocalPosmapV1_noninterference_moduloReleases`
and `paperMain_admittedKernelRun_pathOramPrivatePosmapV1_noninterference_moduloReleases`
instantiate the Path ORAM theorems over admitted configurations, keeping only
their ORAM premise (`ComputationalUOWithOn`); the `checkedKernel` forms take a
passing admission check instead of the policy agreement, and the
`SeededRuntimePathOramProofBundleOn` forms take the ORAM premise from a
bundle, leaving the Path ORAM security assumptions and the denotation.

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
  `PaperPathOramTheoremRoute`, `CoinTapes` with `PathOramFreshLeaves`, the
  enumeration-free leaf-schedule theorem for one map or several,
  `PathOramAdmitted`, the route over admitted configurations,
  `PathOramTapeWitness`, the tape family of one runtime run, and
  `PathOramAvlMap`, the private scheme's AVL map algorithm and its map
  semantics (see [`path-oram.md`](./path-oram.md#current-status)).
- SGX/TEE observer: `SgxBoundary`, `SgxRelation`, `SgxController`,
  `SgxControllerTrace`, `SgxMicroModel`, `SgxObserverFreeze`,
  `TeeDeployment`, `DeploymentAcceptance`.
- Paper-main theorem: `PaperMainTheorem`, `AcceptedPackageCapstone`, and
  `PaperMainReleases`. `PaperMainReleases` states the paper-main theorem and
  the accepted-package capstones modulo the declared releases
  (`View_SGX ∖ rel`) for the exact backend and both proof-grade Path ORAM
  routes; the release semantics is documented in
  [`claim-boundary.md`](./claim-boundary.md#declared-releases). The Path ORAM
  versions take a seeded proof bundle that cannot exist, so they hold
  vacuously; `PathOramAdmitted` restates both schemes' versions over admitted
  configurations, where the bundle exists; see
  [`path-oram.md`](./path-oram.md#current-status).

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
- `path_oram_avl_map_replay.json`: runtime AVL map operations replayed
  against the Lean model by `checkPathOramAvlMapReplay`, on maps of up to 31
  nodes; `path_oram_avl_map_replay_full.json` is the replay on maps of up to
  2,048 nodes, from a release build
- `tape_substitution.json` and `tape_substitution_full.json`: runtime runs
  of a call on other deployment seeds, each compared by
  `checkPathOramTapeSamples` with the representative run under its own tape.
  Both replays are tests of the runtime against a model, not proofs
- `capacity_sweep.json`: what seven kinds of map call cost on the full scan
  and both Path ORAM schemes from 1 to 16,384 entries and at five occupancy
  levels, their read/write mixes, computed and executed, and the capacities
  from which each scheme is cheaper than the full scan; its release-build
  latencies split into staging, loading, the runtime's own work, witnesses
  and exported proof objects. This is the sweep's quick profile;
  `capacity_sweep_full.json` is the full one, which a script outside the
  validation run writes
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
