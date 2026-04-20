# Paper Theorem Profile

This note freezes the paper-facing theorem target, the exact observer shape,
the explicit assumption profile, and the current trusted-surface statement.
It also records what the current repository already proves at that frozen
interface and what still remains open.

## Frozen Theorem Box

The final paper should aim at exactly one theorem:

> For every admitted Solidity source program `P`, if `uo-solc` compiles `P`
> to artifact `A`, the direct Lean source/artifact checker accepts that pair,
> the real runtime executes `A` and emits runtime proof objects accepted by
> Lean, and the explicit concrete backend / cryptographic / TEE assumptions
> hold, then the real host-visible execution satisfies the paper's
> update-obliviousness theorem against the stated hostile-host observer.

This theorem is now frozen as the paper target. The current repository fixes
its interface, observer, and assumption surface, but does not yet prove the
full end-to-end statement.

## Current Status

What is already established at the frozen interface:

- exact-UO for exact backends on the repository's instrumented abstract
  machine
- theorem-facing computational-UO only on
  `path_oram_local_posmap_v1`
- a direct Lean proof-grade source/artifact checker,
  `checkProofGradeTranslationArtifacts`
- Lean-side proof-grade predicates and executable checkers for the runtime
  kernel witness, runtime refinement witness, and runtime trusted-kernel
  bundle
- an explicit paper-facing runtime assumption bundle and end-to-end boundary in
  Lean, `PaperMainRuntimeKernelAssumptions`,
  `PaperMainRuntimeKernelBoundary`, `PaperMainPathOramAssumptions`, and
  `PaperMainPathOramEndToEndBoundary`, plus the stronger shared-slot route
  `PaperMainRuntimeKernelSlotAssumptions`,
  `PaperMainRuntimeKernelSlotBoundary`,
  `PaperMainPathOramSlotAssumptions`, and
  `PaperMainPathOramSlotEndToEndBoundary`, so the remaining runtime/kernel
  trust point is no longer carried only in prose and is now phrased over the
  explicit theorem-facing runtime kernel-interface bundle
- a strengthened Lean wrapper,
  `ProofGradeSeededRuntimePaperMainBundle`, from which
  `PaperMainRuntimeKernelAssumptions` can now be discharged mechanically when a
  seeded paper-main bundle already carries proof-grade witness acceptance, with
  the seeded-family artifact route now also rechecking exact public-outcome,
  exact boundary-schedule, and shared slot-program uniformity in Lean
- a machine-generated reviewer summary emitted by the full probe bundle as
  `reviewer_summary.json` plus `reviewer_summary.md`, covering proof/report
  cost, artifact sizes, runtime overheads, TCB surface, and explicit
  assumptions
- proof-grade checker entrypoints go through the frozen
  `UOToolchain.ProofGrade` umbrella
- runtime enforcement of the admitted public kernel schedule for accepted
  confidential entrypoints

What is still open:

- a machine-checked source-to-kernel compiler correctness theorem
- a machine-checked refinement proof from the real Rust kernel to the Lean
  kernel model
- a machine-checked proof that secret-dependent runtime behavior is confined to
  that kernel
- discharge of the explicit paper-route runtime bundle
  `PaperMainRuntimeKernelAssumptions`, which is now the named Lean boundary for
  the remaining implementation-honesty gap
- full discharge of the concrete
  `PathOramLocalPosmapV1SecurityAssumptions` bundle
- the final malicious-host SGX / TEE deployment theorem for the real runtime

## Main Choice

The main theorem keeps the enclave boundary exact and public:

- `public_outcome` is exact
- `boundary_schedule` is exact
- `storage_trace` is handled by the backend theorem
- only the SGX-specific `micro_trace` is normalized and simulated from
  `L_sgx_micro`

This is the intended headline claim for the repository. A boundary-normalized
variant is future work, not the main theorem profile.

## Explicit Assumption Profile

The paper should state the assumptions explicitly rather than leave them
implicit in prose.

| Assumption | Role | Current status |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides bucket/path ciphertext contents in the concrete `path_oram_local_posmap_v1` backend | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; not yet discharged in-repo |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages in the local-posmap wrapper | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; not yet discharged in-repo |
| `stashOverflowBounded` | bounds stash-overflow failure for the deployed local-posmap parameters | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; not yet fully discharged in-repo |
| `PaperMainRuntimeKernelAssumptions` | says every emitted runtime witness on the frozen paper route is Lean-proof-grade accepted, and therefore satisfies the checked explicit kernel-interface-bundle boundary `PaperMainRuntimeKernelBoundary` | explicit Lean assumption bundle in `PaperPathOramTheoremRoute.lean`; mechanically discharged for `ProofGradeSeededRuntimePaperMainBundle`, with the seeded witness-family artifact path now also rechecked by dedicated family-level kernel-interface and paper-main validators, but not yet for the real runtime by a machine-checked refinement plus confinement theorem |
| TEE deployment assumptions | enclave memory confidentiality/integrity, attestation authenticity, rollback/freshness discipline, and the stated crash/patch model | required by the final malicious-host theorem; not yet fully closed in Lean |

The exact fresh-leaf remapping bridge is no longer a separate theorem-side
assumption field. It is discharged by the canonical fresh-coin runtime-family
interface and the hidden-leaf coverage proof/checker path.

## Current And Target TCB

| Component | Current status | Final target |
| --- | --- | --- |
| Lean kernel plus Lean theorem/checker development | trusted | trusted |
| Explicit backend / cryptographic / deployment assumptions | trusted assumptions | keep explicit and minimize |
| `uo-check` | not in the proof-grade TCB | not in the TCB |
| `mplus-probe` | not in the proof-grade TCB | not in the TCB |
| `uo-solc` | not trusted for current artifact-level acceptance, but source-level compiler correctness is still unproved | remove from TCB by proving compiler correctness |
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | currently trusted for implementation honesty; the remaining trust point is now frozen explicitly as `PaperMainRuntimeKernelAssumptions` and `PaperMainRuntimeKernelBoundary` | shrink to the smallest kernel and prove it refines the Lean model |
| Rust code outside the tiny kernel | still part of the implementation risk until confinement and refinement are proved | prove public-only or remove from the confidential path |

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
away the schedule field before the admitted storage theorem is used.
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
`CheckCanonicalPathOramPaperInstantiation.lean`,
`CheckCanonicalPathOramPairTheoremInput.lean`, and the probe’s explicit and
compact canonical-pair validation paths. It closes the
runtime/theorem instantiation gap without weakening the theorem boundary or
adding new backend assumptions.

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
named projection lemmas without changing the theorem boundary. The current
seeded runtime proof bundle now also instantiates that standard-theorem import boundary
directly, including the preferred `PathOramJACMLiteratureTheoremAt` route at
the runtime-facing `leafRun`, so there is no longer an open backend-theorem
gap at the concrete repo boundary. The paper route and the artifact route now
share that frozen theorem boundary, but they are not symmetric as provenance
claims: the current paper choice is to use the citation route as the main
narrative, the repo keeps the self-instantiated closure only for executable
validation, and the stronger external-theorem import route remains future work.

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

For the current paper, the theorem narrative is:

- present the ORAM core through the citation route, using the JACM theorem
  source at `PathOramLocalPosmapV1StandardTheoremTarget`
- use `PaperMainPathOramTheoremSourceAt` and
  `pathOramLocalPosmapV1_paperMainStandardTheoremRealization` as the named Lean
  route for that presentation
- state the explicit `PathOramLocalPosmapV1SecurityAssumptions` provenance
  profile from `docs/path-oram-citation-import-plan.md` rather than implying
  those backend facts are already independently mechanized
- present the repo contribution as the bridge proving that the concrete
  compiler/runtime artifacts conform to that frozen interface
- then derive the computational-UO, TEE-storage, and paper-facing SGX
  consequences through the already mechanized projection lemmas

The stronger external-theorem import route remains documented as future
strengthening rather than as the current paper plan.

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
- `uo-evm --format shell-boundary`,
  `shell-boundary-lowering`, and
  `confidential-core-kernel-interface-slot`,
  `confidential-core-shell-boundary-lowering`,
  `paper-main-family`, and
  `paper-main-slot-family` in
  `runtime/uo-evm/src/main.rs`
- `RuntimeRefinementWitness` and its projection lemmas in
  `proof/lean/UOToolchain/RuntimeRefinement.lean`
- `RuntimeRefinementJson.lean` for JSON import, Lean-side witness checking, and
  conversion into the theorem objects, including logical-trace reconstruction
  of the ordered ORAM access schedule and certificate-based observer
  reconstruction
- `checkProofGradeRuntimeWitness` in
  `proof/lean/CheckProofGradeRuntimeWitness.lean` for end-to-end
  proof-grade witness validation from the Lean side
- `checkProofGradeRuntimeKernelInterface` in
  `proof/lean/CheckProofGradeRuntimeKernelInterface.lean` for the paper-facing
  runtime/kernel interface theorem surface extracted from the same accepted
  runtime witness
- `checkProofGradeRuntimeKernelInterfaceBundle` in
  `proof/lean/CheckProofGradeRuntimeKernelInterfaceBundle.lean` for the
  explicit theorem-facing `RuntimeKernelInterfaceBundle` emitted by the Rust
  runtime/kernel interface bridge
- `checkProofGradeRuntimePaperMainFamilyBundle` in
  `proof/lean/CheckProofGradeRuntimePaperMainFamilyBundle.lean` for the
  explicit theorem-facing `SeededRuntimePaperMainFamilyBundle` emitted by the
  seeded paper-route bridge; the imported bridge also proves
  `importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_family_assurance`
  so accepted family artifacts project to a reusable theorem-side family
  assurance object
- `checkProofGradeRuntimePaperMainSlotFamilyBundle` in
  `proof/lean/CheckProofGradeRuntimePaperMainSlotFamilyBundle.lean` for the
  stronger shared-slot theorem-facing
  `SeededRuntimePaperMainSlotFamilyBundle`; the imported bridge also now
  proves
  `importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_family_slot_assurance`,
  so an accepted slot-family artifact can be reused as an explicit theorem-side
  family-slot assurance object rather than only as a checker success bit
- `checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot` in
  `proof/lean/CheckProofGradeRuntimeConfidentialCoreKernelInterfaceSlot.lean`
  for the exported
  `RuntimeConfidentialCoreKernelInterfaceSlotBundle`, which pairs one accepted
  runtime witness with one explicit runtime kernel-interface bundle and one
  exact confidential slot program
- `results/kernel_refinement_validation.json` for benchmark-backed validation
  that the lower-level runtime phase witness is accepted directly against the
  exported kernel witness on representative supported paths
- `results/kernel_interface_validation.json` for benchmark-backed validation
  that the explicit exported `RuntimeKernelInterfaceBundle` artifacts are
  accepted by the dedicated paper-facing runtime/kernel interface bundle
  checker on representative supported paths
- `results/confidential_core_kernel_interface_slot_validation.json` for
  benchmark-backed validation that the stronger confidential-core/kernel-
  interface/slot composite artifacts are accepted on representative supported
  paths
- `results/seeded_witness_validation.json` for benchmark-backed validation
  that the explicit exported `SeededRuntimePaperMainFamilyBundle` and
  `SeededRuntimePaperMainSlotFamilyBundle` artifacts are accepted by the
  dedicated paper-facing seeded runtime bundle checkers on representative
  supported paths, alongside the lower seeded-family validators
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
