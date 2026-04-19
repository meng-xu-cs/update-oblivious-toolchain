# Formal Proof Plan

This document defines the next proof-oriented milestone for the UO Toolchain.
It now also freezes the final theorem target and distinguishes that target
from the current mechanized boundary.

The goal is not to overclaim. The current repository can realistically target a
mechanized proof for the instrumented abstract machine used by this workspace,
plus a narrowly stated TEE deployment theorem that reuses the same normalized
storage trace under explicit enclave assumptions. It cannot honestly target a
universal theorem over all downstream Rust machine code, host runtime effects,
or microarchitectural observers without additional refinement work.

## 0. Frozen Final Theorem Target

The final paper target is:

> For every admitted Solidity source program `P`, if `uo-solc` compiles `P`
> to artifact `A`, the direct Lean source/artifact checker accepts that pair,
> the real runtime executes `A` and emits runtime proof objects accepted by
> Lean, and the explicit concrete backend / cryptographic / TEE assumptions
> hold, then the real host-visible execution satisfies the paper's
> update-obliviousness theorem against the stated hostile-host observer.

The repository has already frozen:

- the observer shape
- the concrete backend path: `path_oram_local_posmap_v1`
- the proof-grade translation boundary: direct Lean checking of separately
  materialized source/candidate artifacts
- the runtime proof boundary: the emitted kernel / refinement /
  trusted-kernel proof objects

The repository has not yet closed:

- source-to-kernel compiler correctness
- runtime-kernel refinement for the real Rust implementation
- secret confinement outside the kernel
- full discharge of the concrete backend assumption bundle
- the final malicious-host deployment theorem for the real runtime

## 1. Claim Boundary

The proof target should be split into three claims.

### 1.1 Artifact-level exact-UO claim

For accepted contracts whose confidential state is implemented using
`UOCell`, `UOArray`, or full-scan `UOMap`, prove exact equality of the
normalized `M+`-visible trace across secret variations.

### 1.2 Artifact-level computational-UO claim

For accepted contracts whose confidential state includes ORAM-backed maps,
prove that the normalized `M+`-visible trace distribution is computationally
indistinguishable across secret variations, up to an explicitly declared
leakage function.

### 1.3 TEE-backed storage-oblivious deployment claim

For deployments where the confidential EVM runs inside a trusted TEE that keeps
plaintext enclave memory confidential and integral, and where persistent state
leaving the enclave is cryptographically protected, the repository may target a
deployment-facing theorem only about the host-visible storage boundary.

More precisely, if the host observer is restricted to:

- public call identity and public arguments
- public output shape
- normalized reads from encrypted/sealed persistent state
- normalized writes to encrypted/sealed persistent state
- public gas and public termination status

then the induced host-visible trace should be exact-UO or computational-UO
according to the backend theorem already proved at the artifact level.

This is a theorem about an idealized TEE storage observer. It is not yet a
theorem about a malicious SGX host observing enclave execution itself.

### 1.4 SGX execution-oblivious theorem boundary

The stronger target statement discussed for SGX should be written down
separately:

> for any two executions with the same public inputs and public initial state,
> SGX execution is oblivious against a malicious host

This stronger claim is outside the current repository theorem boundary.

To make that claim meaningful, the host-visible SGX observer would need to be
modeled explicitly, including at least:

- the enclave call and return interface
- public output shape
- any OCALL, syscall, or host-service schedule
- normalized persistent-state read and write schedules
- enclave exit, interrupt, or fault-visible behavior
- any page-granularity or EPC-paging behavior admitted by the model
- any shared-resource trace admitted by the model, such as cache- or
  branch-predictor-visible behavior

Physical side channels such as power or electromagnetic leakage remain outside
the claim boundary, following the same exclusion style used by ZeroTrace.

The current repository now fixes that observer shape in the paper-facing docs
and Lean-facing interfaces, but it does not yet prove the final malicious-host
theorem against it.

### 1.5 Explicit non-claims

The proof should not claim:

- security for unsupported Solidity features
- security for raw backends on confidential state
- security against observers below the modeled abstract/runtime interface
- security of the current ad hoc nonzero codec as a cryptographic primitive
- SGX execution obliviousness against a malicious host
- security against page-fault, cache, branch-predictor, interrupt, or other
  microarchitectural observers

## 2. Formal Objects

The mechanized proof should define the following objects directly from the
current repository structure.

### 2.1 Programs

A program is a compiled artifact:

- contract state objects from [ir.rs](../crates/uo-core/src/ir.rs)
- runtime manifest entries from [manifest.rs](../crates/uo-core/src/manifest.rs)
- lowered function bodies over the UO IR

### 2.2 Inputs

For a confidential entrypoint `f`, split arguments into:

- `pub_in`: public arguments
- `sec_in`: secret arguments declared in the manifest

The initial contract state is similarly split into:

- `pub_state`: public state and public capacities
- `sec_state`: confidential logical contents

### 2.3 Runtime traces

The proof should use the normalized trace model in
[trace.rs](../crates/uo-core/src/trace.rs):

- opcode trace
- logical access trace
- logical write trace
- normalized physical read schedule
- normalized physical write schedule
- public gas

The current normalized physical view is intentionally shape-based:

- physical reads: `(object, location, len)`
- physical writes: `(object, location, write_class, len)`

This is the right proof target for the current artifact because it matches the
results bundle and the runtime instrumentation.

### 2.4 Adversary view

Define the artifact-level `M+` view as:

```text
View_M+(trace) =
  ( opcode_trace,
    logical_accesses,
    logical_writes,
    physical_reads_norm,
    physical_writes_norm,
    gas_used )
```

For exact-UO objects, equality is literal equality of `View_M+`.

For ORAM-backed objects, the theorem should instead quantify over the
distribution of `View_M+` induced by the runtime coins.

### 2.5 Idealized TEE storage observer

For the deployment-facing TEE claim in Section 1.3, define the idealized
host-visible view as:

```text
View_TEE-Store(trace) =
  ( entrypoint_id,
    public_args,
    termination_status,
    public_output_shape,
    physical_reads_norm,
    physical_writes_norm,
    gas_used )
```

This observer is intentionally stronger than the sealed-storage backend alone,
because it also includes public API shape and public gas, but it is weaker than
an actual malicious SGX host because it does not include enclave-internal page,
cache, interrupt, or OCALL side channels.

### 2.6 Future SGX host observer

If the project later targets the stronger SGX claim in Section 1.4, the proof
must define a different observer. Following the channel split made explicit in
ZeroTrace, the current recommended boundary is:

```text
View_SGX(call) =
  ( entrypoint_id,
    public_args,
    boundary_schedule,
    persistent_reads_norm,
    persistent_writes_norm,
    page_trace,
    exit_trace,
    shared_resource_trace,
    termination_status,
    public_output_shape,
    gas_used )
```

Where:

- `boundary_schedule` is the public sequence of enclave-boundary events such as
  ECALL and OCALL interactions, including public payload sizes
- `persistent_reads_norm` and `persistent_writes_norm` are the normalized
  untrusted-memory or persistent-storage traces already used by the artifact
  semantics
- `page_trace` is the admitted page-fault or EPC-paging trace
- `exit_trace` is the admitted interrupt, resume, or termination trace
- `shared_resource_trace` is an abstract trace for admitted cache or
  branch-predictor style observations
- `public_output_shape` is the public result shape, such as return presence and
  return length
- raw wall-clock timing is intentionally not a component of `View_SGX`; the
  only timing-like public quantity currently modeled is `gas_used`

This document now fixes `View_SGX` concretely enough for future mechanization.
What remains open is not the observer shape, but the theorem and simulator that
must justify it.

## 3. Leakage Functions

The proof must state leakage explicitly.

### 3.1 Exact-UO leakage

For exact-UO backends, the permitted leakage is:

- contract identity
- entrypoint identity
- public argument values
- public capacities and object shapes
- manifest-declared gas budget

No additional dependence on secrets is allowed.

### 3.2 Computational-UO ORAM leakage

For ORAM-backed objects, the permitted leakage should be an explicit function
`L_oram` containing only public configuration data and public schedule data.

Recommended shape:

```text
L_oram(A, f, pub_state, pub_in) =
  ( entrypoint_id,
    public_gas_budget,
    object_id,
    capacity,
    recursion_depth,
    bucket_fanout,
    buckets_per_level,
    path_length_per_access,
    metadata_pages_per_access,
    blocks_per_bucket,
    block_size,
    accesses_per_entrypoint )
```

If the implementation leaks anything else, it is outside the theorem.

### 3.3 Idealized TEE deployment leakage

For the TEE-backed storage-oblivious deployment claim, the permitted leakage is:

- everything already permitted by the artifact-level theorem for the relevant
  backend
- public entrypoint identity and public arguments
- public output shape
- public termination status

No further dependence on plaintext enclave memory is permitted, because that is
hidden by the TEE assumption in Section 1.3.

### 3.4 Future SGX execution leakage

For the stronger SGX claim in Section 1.4, the permitted leakage must be stated
separately and cannot be imported from the artifact-level theorem unchanged.

At minimum it would need to specify whether the proof allows leakage through:

- enclave-boundary event identity and payload sizes
- public output shape
- page-fault or EPC-paging traces
- interrupt, resume, or termination traces
- cache-set, branch, or other shared-resource effects admitted by
  `shared_resource_trace`

Until this leakage function is fixed, there is no honest SGX execution theorem
to prove.

### 3.5 Recommended proof relation for `View_SGX`

The recommended future proof relation should not treat `View_SGX` as a single
opaque object. It should factor the observer into four parts:

```text
View_SGX =
  ( public_outcome,
    boundary_schedule,
    storage_trace,
    micro_trace )
```

Where:

- `public_outcome = (entrypoint_id, public_args, termination_status,
  public_output_shape, gas_used)`
- `boundary_schedule` is the enclave-boundary event sequence
- `storage_trace = (persistent_reads_norm, persistent_writes_norm)`
- `micro_trace = (page_trace, exit_trace, shared_resource_trace)`

The recommended proof relation is:

1. exact equality of `public_outcome`
2. exact equality of `boundary_schedule`
3. a backend-specific storage relation `R_store` over `storage_trace`
4. an SGX-controller relation `R_micro` over `micro_trace`

For distribution-valued semantics, items 1 and 2 should be read as:

- each sampled execution in both distributions carries the same
  public-determined `public_outcome`
- each sampled execution in both distributions carries the same
  public-determined `boundary_schedule`

The proof should not require positional equality of sampled lists. What matters
is exact public constancy across both distributions.

Paper-facing choice for this repository:

- keep `boundary_schedule` as an exact public projection in the main theorem
- normalize only the SGX-specific micro observer
- treat any normalized-boundary variant as optional future work rather than the
  headline claim

The polished paper-facing statement for this profile is collected in
[paper-theorem-profile.md](paper-theorem-profile.md).

This split matches the engineering intent:

- public API shape, public outputs, and public gas should be literally equal
- enclave-boundary behavior should be normalized strongly enough to be literally
  equal
- persistent I/O should inherit either exact-UO equality or ORAM-style
  computational security from the storage backend
- page, exit, and shared-resource traces require a separate SGX-controller
  theorem because they are not covered by standard ORAM security alone

Recommended instantiations:

- for exact backends, `R_store` is literal equality
- for ORAM-backed maps, `R_store` is computational indistinguishability under
  the storage leakage function
- `R_micro` should be defined against an explicit SGX-controller leakage
  function `L_sgx_micro` containing only public outcome data, public model
  tags, and public controller-shape data for the admitted micro observers

Recommended shape:

```text
L_sgx_micro =
  ( public_outcome,
    model_tags,
    boundary_event_budget,
    controller_phase_count,
    controller_phase_order,
    page_trace_budget,
    page_trace_regions,
    exit_trace_budget,
    normalized_exit_pattern,
    shared_resource_budget,
    shared_resource_pattern,
    controller_workset_pages,
    workset_regions,
    recursive_position_map_depth,
    stash_bound )
```

This is intentionally a controller-side leakage function. It is separate from
the storage leakage function inherited from the ORAM backend.

The current Lean scaffold instantiates this with a public controller-shape
object derived from ORAM manifest leakage. Its phase skeleton is:

```text
[ enclave_enter,
  stage_request,
  descend_position_map * recursion_depth,
  load_metadata,
  fetch_path,
  scan_stash,
  rewrite_path,
  ascend_position_map * recursion_depth,
  seal_persistent_state,
  enclave_exit ]
```

repeated according to the public `accesses_per_entrypoint` counters. Page
budgets are grouped into public regions:

- `metadata`
- `position_map`
- `path`
- `stash`

with total page-trace budgets aggregated over the public access schedule and
workset-page budgets taken as public maxima over the same regions. The current
Lean model also exposes:

- the exact public controller phase order
- the ordered per-region page-event counts
- the normalized exit pattern
- the normalized shared-resource event-class schedule

This is still far from leaking the full raw SGX trace: concrete page IDs and
any secret-dependent micro-event identities remain out of scope.

## 4. Target Theorems

The proof plan should target the following theorem stack.

### Theorem A: Translation-boundary soundness

If the direct translation-boundary checker accepts the source-side compiled
artifact and the candidate artifact for a given metadata contract, then:

- the accepted proof-grade artifact can be reduced to metadata plus raw
  source/artifact contract JSON, with proof-relevant views reconstructed in
  Lean rather than trusted from Rust
- all confidential state objects use approved backends
- all public capacities/bounds required by the runtime exist
- confidential IR contains no forbidden control flow
- the proof-relevant manifest/function/object fields consumed by the theorem
  are exact images of the accepted source/IR for the admitted compiler path
- artifact metadata and theorem-facing backend parameters are structurally
  consistent

### Theorem B: Compiler secrecy preservation

If a source contract is accepted and compiled in UO mode, then each
confidential entrypoint is transformed so that:

- opcode/control-flow shape depends only on public inputs
- loop trip counts depend only on public bounds
- abort behavior is normalized into the compiled IR model
- emitted manifest gas is public-determined

### Theorem C: Exact-UO object theorem

For `UOCell`, `UOArray`, and full-scan `UOMap`, if two executions start from
states with equal public projections and differ only in secrets, then the
object-local `View_M+` traces are equal.

### Theorem D: ORAM local theorem

For the proof-grade ORAM backend, if two executions start from states with
equal public projections and differ only in secrets, then the induced
distribution of object-local `View_M+` is computationally indistinguishable
given only `L_oram`.

This theorem must be reduced to the underlying ORAM construction plus the
chosen cryptographic assumptions.

The current Lean scaffold now contains an explicit reduction layer for this:

- `StandardOramReduction.lean` factors `View_M+` into an exact public part plus
  a backend storage trace and proves that any standard-ORAM-style storage
  theorem lifts to `ComputationalUOWith`
- `PathOramSecurity.lean` fixes the current proof-grade backend target to the
  concrete `path_oram_local_posmap_v1` scheme and narrows the remaining axiom
  boundary to a path-ORAM storage theorem with an explicit security-assumption
  bundle rather than a whole-view ORAM theorem
- `PathOramLocalPosmapV1.lean` now packages that concrete backend target into
  an explicit repo-facing assumption bundle and theorem boundary, so the
  standard-theorem discharge obligation is stated directly against the
  `path_oram_local_posmap_v1` candidate instead of being left only as a
  generic path-ORAM reduction
- `PathOramLocalPosmapV1.lean` now also exposes an explicit standard-theorem
  import boundary,
  `PathOramLocalPosmapV1StandardStorageBoundary`, together with named
  projection lemmas into the concrete computational-UO, paper-main SGX, and
  TEE-storage theorem endpoints
- `PathOramLocalPosmapV1Refinement.lean` now fixes the imported-theorem route
  one level further by defining a theorem-facing standard Path ORAM
  implementation package, proving that package yields the repo’s standard
  storage boundary, and instantiating it from the seeded runtime bundle, so the
  runtime/theorem interface gap is closed inside Lean rather than left as an
  informal “the runtime should match the theorem” claim
- `PathOramLocalPosmapV1StandardTheorem.lean` now freezes the exact imported
  theorem target into one named object,
  `PathOramLocalPosmapV1StandardTheoremTarget`, exposes the exact abstract
  theorem proposition `StandardPathOramStorageTheoremAt` that an imported Path
  ORAM proof must discharge, and packages the remaining concrete-implementation
  bridge as
  `PathOramLocalPosmapV1StandardTheoremRealization`, so the remaining work is
  phrased as one explicit discharge object rather than a loose set of
  cross-file obligations
- that same module now splits the imported-theorem path into a theorem-side
  `StandardPathOramCoreTheorem` and a runtime-side `PathOramStorageEnvelope`,
  making explicit that public metadata-page behavior, bucket projection, and
  storage-shape exactness are concrete implementation facts layered on top of
  the imported ORAM theorem rather than hidden inside it
- `PathOramLocalPosmapV1StandardTheorem.lean` now also discharges
  `StandardPathOramStorageTheoremAt` directly from the seeded runtime bundle
  and packages the result as
  `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealization`
- `PathOramJACMTheorem.lean` now exposes a literature-facing theorem object,
  `PathOramJACMLiteratureTheorem`, and a named mapping into
  `StandardPathOramCoreTheorem`, so the import route can be presented in the
  paper as “JACM theorem plus formal interface mapping” rather than only as a
  repo-native restatement
- that module also now provides the strengthened
  `PathOramJACMLiteratureTheoremAt` formulation, which fixes the literature
  theorem directly at the runtime’s theorem-facing `leafRun` and removes the
  separate alignment obligation on the preferred mainline import route
- that same preferred route is now closed for the concrete bundle by the named
  exports
  `pathOramLocalPosmapV1_standardPathOramStorageTheoremAtOfSelfJACMAt` and
  `pathOramLocalPosmapV1_standardTheoremRealizationOfSelfJACMAt`
- that path-ORAM theorem now consumes a projected leakage type that drops the
  legacy surrogate-style `schedule` field and keeps only the standard public
  ORAM parameters
- the path-ORAM storage theorem is now decomposed inside Lean into:
  a canonical finite-distribution sampler for hidden leaf values indexed by
  the public leaf scaffold, deterministic projection from leaf values to bucket
  traces, a location-schedule security relation on projected storage
  locations, and exact public constancy of storage-shape data such as read
  lengths and write classes
- the old placeholder whole-view ORAM and SGX-micro local-theorem interfaces
  are now quarantined under `legacy*` names in the Lean development; they are
  compatibility shims only and are not on the dependency path of the
  proof-grade paper theorem

### Theorem E: Public gas theorem

For accepted confidential entrypoints, `gas_used` equals the manifest-declared
public gas budget and is therefore independent of secrets.

### Theorem F: Composition theorem

If each confidential object backend satisfies its local theorem and the
compiler emits only approved object operations, then the whole-entrypoint
execution satisfies the top-level exact-UO or computational-UO theorem.

### Theorem G: TEE-backed storage theorem

Assume:

- the artifact satisfies Theorem F
- plaintext enclave memory is confidential and integral
- the host sees only `View_TEE-Store`
- persistent state leaving the enclave is cryptographically protected

Then two executions with the same public projection induce equal or
computationally indistinguishable `View_TEE-Store` distributions, according to
the backend theorem used by the artifact.

This theorem is a boundary statement for a deployment theorem. It is not a
theorem about SGX page faults, caches, interrupts, or host scheduling.

### Theorem H: Future SGX execution-oblivious theorem

If the project later implements a standard ORAM backend, an oblivious enclave
controller, a fixed enclave boundary, and an explicit SGX leakage model, then a
separate theorem should target the mixed relation from Section 3.5 on
`View_SGX`.

Concretely, the theorem should prove:

- exact equality of `public_outcome`
- exact equality of `boundary_schedule`
- the chosen `R_store` relation on `storage_trace`
- the chosen `R_micro` relation on `micro_trace`

The current repository does not satisfy the prerequisites for this theorem.

### Theorem I: SGX envelope lifting theorem

Once `View_SGX` and the mixed relation from Section 3.5 are fixed, the proof
stack should also include a lifting theorem of the following form:

- if the storage backend satisfies its artifact-level exact or computational
  theorem
- and `public_outcome`, `boundary_schedule`, and the admitted micro-trace
  envelope are public-safe functions of the public projection

then the induced SGX execution satisfies the mixed `View_SGX` relation with:

- exact public constancy on `public_outcome`
- exact public constancy on `boundary_schedule`
- storage relation inherited from the backend theorem
- micro relation inherited from the SGX-controller theorem or, in degenerate
  envelope models, from exact public constancy of the admitted micro trace

### Theorem J: SGX-controller local theorem

For a future proof-grade SGX controller, if two controller executions start
from states with the same public micro data and differ only in secrets, then
the induced distribution of:

```text
micro_trace = (page_trace, exit_trace, shared_resource_trace)
```

is related by `R_micro` given only `L_sgx_micro`.

This theorem is separate from ORAM storage security. Standard ORAM theorems do
not imply it.

The current Lean scaffold now contains one exact, proof-carrying instance of a
public SGX controller envelope: the controller trace is generated
deterministically from the public controller shape, and the resulting page,
exit, and shared-resource trace lengths are proved to match the corresponding
budgets in `L_sgx_micro`. This is a concrete witness for a public controller
envelope, not yet the general computational theorem above.

The current mechanization also contains an explicit normalized simulator: from
`L_sgx_micro` alone it reconstructs a normalized micro trace consisting of:

- page-kind plus fault/evict classes
- the normalized exit pattern
- the normalized shared-resource event schedule

The proved relation at this stage is that the real controller trace normalizes
exactly to that simulator output. This is stronger than the previous
budget-only canonicalization theorem while still avoiding claims about full raw
page identities.

For the main theorem profile, `boundary_schedule` remains exact throughout.
Only the SGX-specific micro observer is normalized.

### Theorem K: Joint SGX composition theorem

If:

- the storage projection satisfies the artifact-level exact or computational
  theorem
- the SGX-controller micro projection satisfies Theorem J
- `public_outcome` and `boundary_schedule` are public-safe functions of the
  public projection

then the full SGX execution satisfies the mixed `View_SGX` relation from
Section 3.5.

## 5. Recommended Mechanization Strategy

The Lean workspace now exists and already contains the artifact semantics,
projection layers, certificate checkers, the runtime/controller witness bridge,
the checker-side translation-validation path, and the frozen imported-theorem
target for the concrete Path ORAM candidate. The closure strategy from here now
has a recommended paper-main route plus a completed executable bridge:

1. keep `path_oram_local_posmap_v1` as the only theorem-facing ORAM backend
2. keep the runtime-to-Lean bridge at the small emitted
   witness/certificate-producing kernel rather than at the whole runtime
3. keep the compiler bridge on the explicit direct-artifact-plus-Lean-check
   path rather than trying to verify the whole Rust compiler at once, and keep
   residual Rust-side debug emission off the proof-grade acceptance path
4. for the current paper theorem, use the citation route for the standard Path
   ORAM theorem at `PathOramLocalPosmapV1StandardTheoremTarget`
5. reuse the existing projection lemmas to recover the repo's
   computational-UO, TEE-storage, and paper-facing SGX claims

## 6. Remaining Gaps Before The Strengthened Claim Is Closed

The current repository is no longer at the "blank proof plan" stage. The
remaining gaps are narrower and should be addressed directly.

### 6.1 Discharge the real Path ORAM backend theorem

Current status:

- the exact imported theorem target is frozen in Lean
- the theorem-facing backend path is the concrete
  `path_oram_local_posmap_v1` candidate
- the runtime-facing projection lemmas are already packaged at that boundary

Remaining change:

- for the current paper route, keep using the JACM citation route at the fixed
  storage-semantics boundary rather than implying a stronger external theorem
  import than the repo actually has
- independently of that provenance choice, any stronger claim still needs a
  cryptographic/backend justification for the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle

### 6.2 Close the runtime-to-theorem refinement gap

Current status:

- the runtime emits a checked refinement witness bundle
- Lean can parse and validate that witness bundle against the theorem-side
  predicate
- the runtime now also exports standalone public-controller and hidden Path
  ORAM certificates
- the runtime now also packages those certificates into an explicit
  `RuntimeTrustedKernelBundle`, and Lean now has a corresponding
  `RuntimeTrustedKernelBundle.Valid` predicate plus an executable
  proof-grade `checkProofGradeRuntimeTrustedKernel` checker
- the full runtime witness is now reconstructed from that explicit trusted
  kernel bundle rather than treated as the primitive bridge object, and
  runtime-emitted traces now store that direct bundle so witness extraction on
  emitted artifacts no longer depends on theorem-trace-side reconstruction

Remaining change:

- keep the trusted boundary explicitly at that small certificate-producing
  kernel rather than at the whole trace bundle
- if the paper later wants a source-level theorem about the Rust extractor
  itself, add a theorem or separately audited refinement argument for that
  smaller extractor rather than for the whole runtime

### 6.3 Close the compiler/output conformance gap with translation validation

Current status:

- the compiler emits proof-relevant manifest fields and backend parameters
- the strongest proof-grade path now feeds a source-side compiled artifact and
  the candidate artifact directly to a Lean checker, which extracts the raw
  contract JSON itself, reconstructs the proof-relevant source/artifact views
  internally, and accepts only when those reconstructed views match and
  satisfy proof-grade replay checks for:
  manifest contract/mode exactness, state-object / manifest exactness,
  object-id coverage, entrypoint coverage, secret-arg agreement, confidential
  raw-backend rejection, arena/stack budgets, logical read/write counters,
  ORAM access counts and theorem-facing ORAM shape, `max_commit_ops`, and the
  confidential kernel lowering / runtime-step schedule
- `uo-check` no longer sits on the proof-grade CLI path and no longer sends
  Rust-computed proof-relevant views to the proof-grade checker; the richer
  view bundle is now debug-only and outside proof-grade acceptance
- the probe now exercises that translation-validation path directly in both the
  focused static-check report and the bridge-validation report; insecure raw
  confidential artifacts are now reported there as explicit proof-grade
  rejections rather than being treated as accepted cases

Remaining change:

- the Rust-side debug-bundle emitter is no longer trusted to choose the
  proof-relevant projection, and the strongest automated path no longer
  depends on that emitter at all: Lean recomputes the projection from the raw
  contract JSON extracted directly from separately materialized artifacts and
  exposes theorem-level exactness lemmas for both imported views. Remaining
  translation-side work is therefore limited to debug-surface hygiene rather
  than a substantive proof-boundary trust gap

### 6.4 Keep the surrogate backend off the strengthened claim path

Current status:

- the legacy surrogate backend still exists in the repo

Remaining change:

- treat the surrogate as benchmarking/compatibility-only
- do not route paper-facing or proof-grade claims through it

### 6.5 Preserve deployment-claim discipline

Current status:

- the repo has an idealized TEE storage theorem boundary and a paper-facing SGX
  observer profile

Remaining change:

- do not upgrade those into a malicious-host SGX execution claim until the
  enclave-side controller, host boundary, and admitted SGX micro observer are
  all connected to the real implementation by the same refinement discipline

## 7. Proof-Oriented Refactor Plan

The recommended implementation path is now:

1. keep `path_oram_local_posmap_v1` as the only theorem-facing backend target
2. narrow the runtime ORAM/controller path around an explicit transcript- and
   certificate-emitting trusted kernel
3. prove or validate conformance of that kernel to the Lean witness interface
4. keep source-to-artifact translation validation on the explicit
   direct artifact-checker plus Lean path, and continue isolating residual
   Rust-side debug logic from that imported interface
5. keep the stronger external-theorem import presentation separate from the
   already completed engineering bridge and treat it as future work
6. reuse the already-mechanized projection lemmas for the repo-facing claims

## 8. Immediate Next Engineering Tasks

The next repo-level work should be treated as theorem-strengthening rather than
missing bridge engineering:

1. keep the surrogate backend explicitly marked as legacy/benchmark-only in the
   proof-facing docs and claim surface
2. preserve the small trusted kernel boundary around emitted certificates,
   the trusted-kernel bundle, witnesses reconstructed from that bundle, and
   the direct Lean-checked translation boundary; the proof-grade path now
   already accepts separately materialized artifacts directly, so the remaining
   work is to keep any residual Rust-side convenience/debug emission fully out
   of that proof-facing path
3. cite the external Path ORAM theorem source at
   `PathOramLocalPosmapV1StandardTheoremTarget`
4. keep the stronger theorem-provenance swap isolated from the theorem
   boundary and from the executable bridge, and treat it as future work
5. separately justify or import the cryptographic/backend assumptions gathered
   in `PathOramLocalPosmapV1SecurityAssumptions`

## 9. Definition Of Done For A Proof-Grade ORAM Milestone

The current repository now meets the repo-internal bridge criteria for a
proof-grade Path-ORAM theorem boundary under explicit assumptions:

- the theorem-facing backend path is the concrete standard-style Path ORAM
  candidate rather than the legacy surrogate
- cryptographic and backend assumptions are stated explicitly
- the leakage function is stated explicitly
- a simulator-based theorem stack is written down and mechanized
- the runtime/proof bridge is carried by emitted certificates, the
  trusted-kernel bundle, and checked refinement witnesses
- the compiler boundary is closed at the current bridge layer by the direct
  Lean `checkProofGradeTranslationArtifacts` validator over separately
  materialized source and candidate artifacts; the Lean checker reconstructs
  the proof-relevant fields itself and then checks exact replay of
  state-object manifests, resource budgets, ORAM access/budget metadata, and
  confidential kernel schedule metadata
- the results bundle is regenerated against that transcript model

What still should not be claimed without further work is stronger provenance or
deployment scope than the repository actually supports.

Do not claim SGX execution obliviousness against a malicious host until all of
the following are also true:

- the host-visible SGX observer is defined explicitly
- the ORAM backend is a standard construction rather than the current surrogate
- the enclave-side controller is data-oblivious
- enclave boundary behavior such as host calls and persistent I/O is normalized
- the deployment assumptions for freshness, rollback resistance, and platform
  patch level are stated explicitly

The correct current description of the repository is:

- exact-UO for the exact backends on the instrumented abstract/runtime model
- a theorem-facing computational-UO path for
  `path_oram_local_posmap_v1` under the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle and the frozen standard
  Path-ORAM theorem interface
- an idealized TEE-backed storage theorem boundary under enclave assumptions
- no current SGX execution-oblivious theorem against a malicious host
