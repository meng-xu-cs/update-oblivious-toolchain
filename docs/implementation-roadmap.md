# Implementation Roadmap To Proof-Grade SGX/TEE Conformance

This note turns the current proof boundary into an implementation plan. The
goal is to reach an end-to-end artifact whose runtime and checker match the
proof-grade SGX/TEE theorem boundary without weakening the theorem.

## Goal

The target implementation claim is:

- confidential entrypoints emit an explicit public observer consisting of
  `public_outcome`, exact `boundary_schedule`, protected `storage_trace`, and a
  normalized SGX controller `micro_trace`
- persistent state leaving the enclave boundary is confidential and integral
- unsupported programs are rejected rather than accepted under an inexact public
  leakage witness
- the Rust implementation is connected to the Lean theorem by a concrete
  refinement argument, not just by engineering intent

## Theorem-Preserving Principles

- Do not relax the theorem to fit the current code.
- When the implementation cannot yet realize a theorem hypothesis, reject the
  program or mark the backend as out of scope.
- Make every public observer field explicit in the runtime trace.
- Keep the public leakage witness exact for supported programs.

## Milestones

### M1. Runtime theorem observer

Status: implemented in this repo.

The runtime now emits a theorem-facing trace object containing:

- `public_outcome`
- exact `boundary_schedule`
- public controller-shape data
- normalized SGX micro trace derived from that controller shape

Acceptance criteria:

- every `ExecutionTrace` carries `theorem_trace`
- boundary length matches the public controller budget
- normalized page-trace length matches the sum of public region budgets

This is a public controller envelope. It is the right observer shape for the
theorem, but it is not yet a proof that the runtime is a proof-grade SGX
controller.

### M2. Sealed persistent storage

Status: implemented in this repo.

Confidential storage records now use authenticated encryption with per-record
associated data before nonzero transport encoding.

Acceptance criteria:

- confidentiality and integrity of persistent records are cryptographic, not
  cosmetic
- post-initialization confidential writes remain nonzero-to-nonzero updates
- decode/open rejects tampering

This closes the previous gap where the storage codec only hid zero markers.

### M3. Exact public leakage witnesses

Status: partially implemented in this repo.

The compiler and checker now reject loops whose ORAM access multiplicity is not
compile-time exact.

Acceptance criteria:

- `oram_accesses` in the manifest is exact for every supported confidential
  entrypoint
- checker and compiler reject any construct that would make the witness
  inexact

Still remaining:

- extend the same exactness discipline to any other manifest fields that are
  intended to be used in refinement proofs, especially where loop structure
  affects public budgets

### M4. Replace the surrogate ORAM with a proof-grade ORAM

Status: partially implemented in this repo.

The repo now contains a second ORAM scheme candidate,
`path_oram_local_posmap_v1`, alongside the legacy surrogate backend.

What is implemented:

- scheme selection is explicit in metadata and the compiled artifact
- the manifest/runtime parameters for the path candidate are no longer the
  surrogate placeholders
- the path candidate uses a real tree, real path reads/writes, a persisted
  position map, and a persisted stash
- the path candidate now executes immediately at each ORAM access on the
  transaction shadow state rather than replaying a single staged access at
  commit time
- multiple accesses to the same path-ORAM object within one entrypoint are now
  supported and covered by the runtime/controller trace
- manifest commit budgets now scale with the admitted per-entrypoint path-ORAM
  access multiplicity
- the proof/evaluation path now includes theorem-tight seeded family artifacts
  and class0/class1 paired certificates for concrete `SingleAccessMap`
  path-ORAM workloads, including the public access-counter state required by
  the theorem boundary

What is still missing before this milestone is complete:

- a broader benchmark suite using the stronger backend
- the proof reduction from the implementation candidate to the ORAM theorem

Required work:

- implement a standard ORAM backend such as Path ORAM or Ring ORAM
- make `stash_bound`, `recursion_depth`, and position-map handling real runtime
  state rather than placeholder zeros
- preserve the update-only physical write invariant under the sealed encoding
- expose the resulting public ORAM parameters through the manifest

Acceptance criteria:

- the runtime no longer reports the surrogate scheme for proof-grade ORAM mode
- the manifest parameters correspond to actual runtime behavior
- the backend is suitable for reduction to a standard ORAM theorem

### M5. Make the SGX controller explicit in the runtime

Status: partially implemented in this repo.

The current runtime now has an explicit controller-envelope module that builds:

- exact `boundary_schedule`
- public controller shape
- normalized SGX micro trace

from the runtime controller path itself.

What is implemented:

- a call-scoped runtime recorder now emits ordered logical accesses, ordered
  physical reads/writes, exact enclave-boundary events, and controller-phase
  observations in execution order
- ORAM accesses route through that recorder at the moment they execute
- the emitted theorem trace is now assembled from the recorder rather than from
  a manifest-only reconstruction

What is still missing before this milestone is complete:

- a stronger refinement argument connecting the Rust recorder/controller state
  machine to the Lean `View_SGX` observer
- broader backend coverage beyond the current standard-ORAM-style path
  candidate and the legacy surrogate mode

Required work:

- preserve exact public `boundary_schedule`
- keep extending controller-backed execution to every admitted confidential
  backend mode
- prove that the recorder/controller trace is the direct image of the supported
  runtime execution path

Acceptance criteria:

- controller phases exist as runtime states, not just theorem-side labels
- runtime-emitted boundary and normalized micro traces are produced by the
  controller path itself
- controller traces are stable under secret variation for the admitted observer

### M6. Proof integration and refinement

Status: partially implemented.

Once M4 and M5 exist, the remaining step is to connect the Rust runtime to the
Lean theorem by a concrete refinement layer.

What is implemented:

- the Rust trace layer now exposes an explicit refinement witness extraction via
  `ExecutionTrace::runtime_refinement_witness`
- the runtime engine now treats witness extraction as a postcondition of trace
  emission: a call fails instead of returning an `ExecutionTrace` whose theorem
  fields do not admit a refinement witness
- the controller now cross-checks its incremental theorem observer against an
  independent pure reconstruction over the recorded public ORAM schedule before
  returning the trace bundle
- the runtime also rejects observed ORAM accesses whose public parameters drift
  from the compiled manifest objects, so the ordered controller certificate is
  anchored to artifact metadata as well as live execution
- the runtime CLI can now emit either the full execution trace or the checked
  refinement witness directly via `uo-evm --format refinement-witness`
- that witness keeps only the Lean-relevant normalized trace fields together
  with `public_outcome`, `boundary_schedule`, `controller_shape`,
  `normalized_micro_trace`, an ordered public controller certificate, and the
  public ORAM object metadata needed to reconstruct that certificate from the
  logical trace
- extraction is checked, not assumed: witness construction fails if gas,
  boundary/controller reconstruction, logical-trace-derived ORAM access
  reconstruction, or controller-derived normalized micro trace drift apart
- the Lean scaffold now contains
  `proof/lean/UOToolchain/RuntimeRefinement.lean`, which fixes the witness
  record and proves how it projects into the existing `Trace`/`SGXView`
  theorem objects while reconstructing the boundary/controller observer from
  the imported controller certificate and reconstructing the ordered ORAM
  access schedule from the public logical trace
- that runtime witness now also carries a hidden path-ORAM leaf schedule, and
  both the Rust witness extractor and the Lean checker validate that its public
  scaffold matches the path accesses reconstructed from the logical trace and
  that its deterministic bucket-path projection reproduces the observed
  path-ORAM bucket trace exactly
- that same witness now also carries hidden path-ORAM position-map state both
  before and after the call, together with an exact hidden per-access
  transition certificate; witness validity now replays those certified
  transitions and checks that they produce the exported final hidden state,
  rather than treating the hidden leaf schedule as an opaque sidecar
- the Lean runtime witness layer now also exposes a deterministic
  decomposition of each path-ORAM call into hidden initial position-map state,
  hidden transition shape, and a minimal fresh-leaf coin sequence, which
  sharpens the remaining runtime-coins theorem to a statement about fresh
  resampling rather than about the entire hidden access-leaf schedule
- that same witness now also exports the certified public leaf scaffold
  explicitly, so the theorem side can consume equality of that public scaffold
  directly when instantiating the path-ORAM storage boundary instead of
  rebuilding the same relation only through the older public-alignment lemma
- seeded runtime execution is now deterministic end to end for the proof-grade
  path candidate: the exported `runtime_seed` controls object-local RNG state,
  store-cipher key generation, and ORAM leaf sampling, and the regression suite
  checks replayability of seeded path-ORAM traces
- the Lean package now also contains `RuntimeCoins.lean`, which lifts a
  finite seeded witness family into leaf-schedule and leaf-value distributions,
  proves the direct public scaffold lemmas needed by the newer
  scaffold-indexed path-ORAM theorem variants, and now keeps canonical
  leaf-value realization as an explicit theorem hypothesis at the exact lemmas
  that need it instead of bundling that claim into the witness-family record
- the Lean scaffold now also contains
  `proof/lean/UOToolchain/RuntimeRefinementJson.lean`, which parses the Rust
  witness JSON, converts it into the theorem-side witness, and provides a
  Lean-side executable validity checker equivalent to the `Valid` proposition
- the Lean package now includes `checkRuntimeWitness`, a small executable that
  loads a serialized Rust witness and validates it against the theorem-side
  predicate from the command line
- the validation pipeline now runs representative benchmark scenarios through
  the real Rust runtime, extracts refinement witnesses from the resulting
  traces, and checks those witnesses with the Lean executable; the report is
  emitted as `results/witness_validation.json`, now including a multi-object
  ORAM `transferFrom` path
- the Lean scaffold now contains an explicit standard-ORAM reduction layer in
  `StandardOramReduction.lean`, which factors `View_M+` into an exact public
  part plus a backend storage trace and lifts storage theorems into
  `ComputationalUOWith`
- the Lean scaffold now also contains `PathOramSecurity.lean`, which narrows
  the remaining ORAM axiom boundary to a storage theorem for the concrete
  `path_oram_local_posmap_v1` backend candidate under an explicit security
  assumption bundle rather than a whole-view ORAM theorem, and projects away
  the legacy surrogate-style `schedule` field before that theorem is invoked
- the Lean scaffold now also contains `PathOramLocalPosmapV1.lean`, which
  specializes that generic path-ORAM theorem boundary to the repo’s concrete
  backend-facing assumption bundle and packages the resulting
  computational-UO, paper-main SGX, and TEE-storage statements into one named
  theorem boundary for seeded runtime proof bundles
- the proof-grade path interface now also normalizes raw logical path reads to
  a public skeleton instead of treating concrete `bucket:{i}` details as exact
  public trace data
- that path-ORAM theorem boundary is now internally decomposed into a
  public reconstruction of the ordered leaf scaffold from normalized logical
  accesses plus public ORAM metadata, a canonical finite-distribution sampler
  for hidden per-access leaf values, deterministic projection from leaves to
  bucket traces, exact public constancy of the non-bucket location scaffold,
  and exact public storage-shape constancy, so the remaining assumption
  surface is smaller than a single monolithic storage theorem
- the Lean import layer now also proves `checkValid = true ↔ Valid` for both
  the seeded runtime witness family checker and the paired path-ORAM
  certificate checker, so the proof-facing SGX/path-ORAM validation boundary
  is theorem-tight rather than executable-only

What is still missing before this milestone is complete:

- a theorem tying the Rust public logical-trace/controller-witness constructor
  to the Lean witness assumptions, rather than only re-checking imported
  concrete witnesses against the same predicate inside Lean
- a theorem that lifts the now-explicit `runtime_seed` interface from a
  deterministic replay handle into a distribution-valued runtime-coins object
  that discharges the canonical hidden-leaf theorem without adding a larger
  trusted surrogate
- discharge of the remaining runtime-coins obligation for the actual
  implementation: prove that the seeded family of emitted path-ORAM witnesses
  realizes the canonical leaf-value sampler on the certified public scaffold
- discharge of the ORAM theorem against the chosen standard construction
  under the now-explicit `PathOramLocalPosmapV1SecurityAssumptions` boundary
  through that witness layer

Required work:

- prove that `ExecutionTrace::runtime_refinement_witness` always emits
  witnesses accepted by the Lean validity checker for each supported backend,
  not just for the current benchmark-backed scenario family and runtime
  postcondition
- connect the Rust-emitted public logical ORAM trace and ordered controller
  witness to the Lean observer by a backend-wise refinement argument, not just
  by a checked serialized witness
- discharge the ORAM theorem against the chosen standard construction instead of
  relying on the current axiom boundary

Acceptance criteria:

- the paper-facing theorem is backed by an implementation refinement argument
- no gap remains where the theorem only describes a modeled controller/backend
  that the Rust runtime does not actually instantiate

### M7. Imported standard Path ORAM route

Status: theorem-facing boundary implemented.

This is now the preferred route for closing the remaining ORAM gap without
weakening the theorem:

1. fix an imported standard Path ORAM theorem at the storage-semantics
   boundary already used by the repo
2. prove that the concrete `path_oram_local_posmap_v1` runtime witness bundle
   conforms to that imported theorem interface
3. reuse the existing projection lemmas to obtain the repo’s computational-UO,
   SGX, and TEE consequences

What is now implemented:

- `PathOramLocalPosmapV1.lean` exposes the exact standard-theorem import
  boundary via `PathOramLocalPosmapV1StandardStorageBoundary`
- `PathOramLocalPosmapV1Refinement.lean` now defines:
  `ImportedStandardPathOramImplementation`,
  `ImportedStandardPathOramTheorem`,
  `ImportedPathOramHiddenWitness`,
  `ImportedStandardPathOramSample`, and
  `PathOramLocalPosmapV1ImportedImplementationConformance`
- the imported theorem object is no longer just a named boundary wrapper: it now
  carries a theorem-facing implementation witness whose fields match the actual
  internal Path ORAM theorem hypotheses consumed by `PathOramSecurity.lean`
- the current seeded runtime proof bundle now factors through that interface by
  a named theorem:
  `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedImplementationConformance`
- that conformance now holds directly at
  `bundle.publicView` / `bundle.storageRun`, with the equality plumbing removed

Remaining work:

- if we want to cite a literature theorem verbatim, map that external theorem’s
  hypotheses onto `ImportedStandardPathOramImplementation`
- if we want a paper appendix with a clean abstract simulator, layer that
  simulator on top of the already-instantiated implementation package rather
  than reopening the runtime/theorem interface

Acceptance criteria:

- the imported theorem is a named Lean object rather than an informal paper-only
  placeholder
- the concrete runtime witness bundle is connected to that imported theorem by
  a named conformance theorem
- the theorem-facing implementation package matches the actual standard Path
  ORAM proof ingredients and is instantiated by the concrete runtime bundle

## Immediate next steps

The next practical path is:

1. tighten manifest exactness beyond ORAM loop counts where needed
2. replace the surrogate ORAM with a standard construction in a new backend mode
3. factor the current public controller envelope into an explicit runtime
   controller module
4. connect that runtime controller/backend pair to the Lean observer

That sequence preserves the theorem boundary throughout. It improves the
implementation until the strong theorem becomes true, rather than redefining the
theorem around the implementation.
