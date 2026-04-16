# Paper Theorem Profile

This note records the paper-facing theorem profile currently implemented by the
Lean scaffold.

## Main Choice

The main theorem keeps the enclave boundary exact and public:

- `public_outcome` is exact
- `boundary_schedule` is exact
- `storage_trace` is handled by the backend theorem
- only the SGX-specific `micro_trace` is normalized and simulated from
  `L_sgx_micro`

This is the intended headline claim for the repository. A boundary-normalized
variant is future work, not the main theorem profile.

## Observer Shape

We write:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

where:

- `public_outcome` contains entrypoint id, public args, termination status,
  public output shape, and public gas
- `boundary_schedule` is the exact host-visible enclave boundary sequence
- `storage_trace` is the normalized persistent read/write trace
- `micro_trace` is the SGX-specific tuple
  `(page_trace, exit_trace, shared_resource_trace)`

## Normalized Micro Observer

The paper theorem does not claim raw equality of SGX micro traces. Instead it
claims equality after a fixed normalization and simulation step derived from
`L_sgx_micro`.

Define `Norm_micro` to map:

- each page event to its public `(page_kind, fault_or_evict)` class
- the exit trace to its normalized exit pattern
- the shared-resource trace to its normalized public event-class schedule

Define `Sim_micro(L_sgx_micro)` to reconstruct that normalized micro trace from
the explicit leakage object:

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

The paper-facing micro claim is then:

```text
Norm_micro(micro_trace(c1)) = Sim_micro(L_sgx_micro(c1))
Norm_micro(micro_trace(c2)) = Sim_micro(L_sgx_micro(c1))
```

whenever `c1` and `c2` have the same public projection.

## Exact Backend Theorem

For exact backends, if two configurations `c1` and `c2` have the same public
projection, then:

```text
public_outcome(c1) = public_outcome(c2)
boundary_schedule(c1) = boundary_schedule(c2)
storage_trace(c1) = storage_trace(c2)
Norm_micro(micro_trace(c1)) = Sim_micro(L_sgx_micro(c1))
Norm_micro(micro_trace(c2)) = Sim_micro(L_sgx_micro(c1))
```

This is the exact-UO SGX theorem under the paper-facing observer.

## ORAM-Backed Theorem

For ORAM-backed storage, if two configurations `c1` and `c2` have the same
public projection, then:

```text
public_outcome(c1) = public_outcome(c2)
boundary_schedule(c1) = boundary_schedule(c2)
R_store(storage_trace(c1), storage_trace(c2); L_oram(c1))
Norm_micro(micro_trace(c1)) = Sim_micro(L_sgx_micro(c1))
Norm_micro(micro_trace(c2)) = Sim_micro(L_sgx_micro(c1))
```

where `R_store` is the storage relation inherited from the ORAM theorem.

## Joint Composition Theorem

If:

- the storage projection satisfies the backend storage theorem
- the SGX controller micro projection satisfies the normalized micro theorem
- `public_outcome`, `boundary_schedule`, and `L_sgx_micro` are public-safe

then the full SGX execution satisfies the mixed theorem above with exact public
boundary behavior and normalized SGX micro simulation.

## Lean Mapping

The abstract ORAM theorem boundary is now surfaced explicitly as:

- `OramSecurityInterface` and `ComputationalUOWith` in
  `proof/lean/UOToolchain/OramGame.lean`
- `StandardOramSecurityInterface` and
  `computationalStandardOram_projects_to_computationalUOWith` in
  `proof/lean/UOToolchain/StandardOramReduction.lean`
- `PathOramSecurityAssumptions`, `proofGradePathOramSecurityInterface`, and
  `computationalPathOram_fromPublicViewLeafValuesBucketLocationAndShape_projects_to_computationalUOWith` in
  `proof/lean/UOToolchain/PathOramSecurity.lean`

For the proof-grade path candidate, the remaining storage theorem boundary is
already narrower than `OramAccessLeakage`: `PathOramSecurity.lean` projects
away the legacy `schedule` field before the admitted storage theorem is used.
It also no longer treats raw path bucket indices in `logicalAccesses` as exact
public data: the proof-grade path interface normalizes those logical events to
a public skeleton before comparing views. On the storage side it now exposes a
leaf-value hidden witness interface: the ordered per-access leaf scaffold is
reconstructed from the public logical trace plus public ORAM metadata, and
bucket-trace secrecy is derived from hidden leaf values together with a
deterministic public projection from those values to root-to-leaf bucket
paths. The clean-path proof stack now goes one step further and instantiates
that hidden leaf-value layer with a canonical finite-distribution sampler
indexed by the public scaffold. The decomposition is now:

- exact public reconstruction of the ordered leaf scaffold
- a canonical finite-distribution sampler for per-access leaf values
- exact public canonicalization of sampled leaf values from the public part
- exact public constancy of the leaf-schedule scaffold
- deterministic projection from leaf schedules and leaf values to bucket traces
- exact public constancy of the non-bucket location scaffold
- exact public constancy of storage-shape projections

The canonical leaf-value layer is exposed through:

- `FiniteDistribution.lean`
- `PathOramLeafValueCanonicalOnPublicPart`
- `PathOramCanonicalLeafValueSecurityAssumptions`
- `computationalPathOram_fromPublicViewCanonicalLeafValuesBucketLocationAndShape_projects_to_computationalUOWith`

At the runtime-artifact boundary, the explicit canonical fresh-coin family is
now related to that hidden accessed-leaf theorem interface by coverage, not by
literal equality of seed spaces. Concretely:

- the public leaf scaffold determines the hidden accessed-leaf seed space
- the explicit runtime artifact enumerates the larger canonical fresh-coin seed
  space, which may also include non-leaf coins such as leaf-resampling coins
- `RuntimePaperInstantiation.lean` proves that if the explicit fresh-coin
  family covers every hidden accessed-leaf seed, Lean can select one
  representative explicit witness per hidden seed and quotient the runtime
  family into the theorem-facing hidden leaf-value family

This is the exact bridge used by
`CheckCanonicalPathOramPaperInstantiation.lean` and the probe’s explicit
canonical-pair validation path. It closes the runtime/theorem instantiation gap
without weakening the theorem boundary or adding new backend assumptions.

The concrete backend specialization is now surfaced explicitly in:

- `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`
- `PathOramLocalPosmapV1SecurityAssumptions`
- `pathOramLocalPosmapV1SecurityInterface`
- `PathOramLocalPosmapV1StandardStorageBoundary`
- `PathOramLocalPosmapV1StandardPaperMainBoundary`
- `pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith`
- `pathOramLocalPosmapV1_standardStorageBoundary_projects_to_paperMainSgxExecution`
- `pathOramLocalPosmapV1_standardStorageBoundary_projects_to_teeStorage`
- `pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageBoundary`
- `SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_standardPaperMainBoundary`
- `PathOramLocalPosmapV1PaperTheoremBoundary`
- `SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperTheoremBoundary`
- `pathOramLocalPosmapV1_paperMain_jointSecurity_projects_to_sgxExecution`
- `PathOramLocalPosmapV1ArtifactPaperMainBoundary`
- `pathOramLocalPosmapV1_artifactPaperMainBoundary`

That module does not discharge the remaining ORAM assumptions by itself. What
it does is fix the exact theorem-facing boundary for the repo’s concrete
`path_oram_local_posmap_v1` candidate and package the current computational-UO,
paper-main SGX, joint-SGX, artifact-composition, and TEE-storage projections
into named endpoints. It now also exposes the explicit import point for an
external or separately mechanized standard Path ORAM theorem: once that theorem
is proved at `PathOramLocalPosmapV1StandardStorageBoundary`, the repo’s
concrete computational-UO, paper-main SGX, and TEE-storage claims follow by
named projection lemmas without changing the theorem boundary. The legacy
surrogate theorem remains available as a compatibility specialization, so the
generic paper-facing aliases below are unchanged. The current seeded runtime
proof bundle now also instantiates that standard-theorem import boundary
directly, including the preferred `PathOramJACMLiteratureTheoremAt` route at
the runtime-facing `leafRun`, so there is no longer an open backend-theorem
gap at the concrete repo boundary. The two routes remain equivalent at that
theorem boundary; the recommended paper mainline is to present an external
imported theorem as the main narrative, while the repo keeps the
self-instantiated closure for executable validation.

The current paper-facing aliases are:

- Exact backend main theorem:
  `paperMain_exactUO_projects_to_sgxExecution` in
  `proof/lean/UOToolchain/SgxExactProjection.lean`
- ORAM-backed main theorem:
  `paperMain_computationalUO_projects_to_sgxExecution` in
  `proof/lean/UOToolchain/SgxOramProjection.lean`
- Joint composition main theorem:
  `paperMain_jointSecurity_projects_to_sgxExecution` in
  `proof/lean/UOToolchain/SgxJointProjection.lean`

The normalized SGX micro relation itself is:

- `normalizedObservedSGXMicroRelation` in
  `proof/lean/UOToolchain/SgxMicroGame.lean`

The leakage-to-simulator normalization lemma for the concrete public controller
instance is:

- `normalizeMicroTrace_controllerMicroTraceOfShape` in
  `proof/lean/UOToolchain/SgxControllerTrace.lean`

## Presentation Strategy

For a paper, the preferred theorem narrative is:

- present the ORAM core as an external or literature-faithful imported theorem
  at `PathOramLocalPosmapV1StandardTheoremTarget`
- use `PaperMainPathOramTheoremSourceAt` and
  `pathOramLocalPosmapV1_paperMainStandardTheoremRealization` as the named Lean
  route for that presentation
- present the repo contribution as the bridge proving that the concrete
  compiler/runtime artifacts conform to that frozen interface
- then derive the computational-UO, TEE-storage, and paper-facing SGX
  consequences through the already mechanized projection lemmas

For the executable artifact story, the repo also keeps a self-instantiated
closure at exactly the same interface through
`pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization`. That is not
a weaker theorem boundary; it is a stronger artifact-completeness move so the
current build can validate the entire bridge end to end without waiting on an
external imported theorem object.

## Runtime Witness Interface

The runtime-to-Lean witness interface is now fixed in:

- `ExecutionTrace::runtime_refinement_witness` in
  `crates/uo-core/src/trace.rs`
- runtime enforcement of that witness postcondition in
  `runtime/uo-evm/src/engine.rs`
- independent public-observer reconstruction and drift check in
  `runtime/uo-evm/src/controller.rs`
- ordered controller-certificate reconstruction in
  `crates/uo-core/src/trace.rs`
- `uo-evm --format refinement-witness` in `runtime/uo-evm/src/main.rs`
- `RuntimeRefinementWitness` and its projection lemmas in
  `proof/lean/UOToolchain/RuntimeRefinement.lean`
- `RuntimeRefinementJson.lean` for JSON import, Lean-side witness checking, and
  conversion into the theorem objects, including logical-trace reconstruction
  of the ordered ORAM access schedule and certificate-based observer
  reconstruction
- `checkRuntimeWitness` in `proof/lean/CheckRuntimeWitness.lean` for
  end-to-end witness validation from the Lean side
- `results/witness_validation.json` for benchmark-backed validation that the
  emitted runtime witnesses are accepted by the Lean checker on representative
  supported paths, including a multi-object ORAM `transferFrom` witness

## Non-Claim

This profile does not currently claim:

- raw equality of SGX page identities
- raw equality of full micro-event sequences
- a normalized boundary theorem

Those would require a different observer choice and possibly a wider leakage
model.
