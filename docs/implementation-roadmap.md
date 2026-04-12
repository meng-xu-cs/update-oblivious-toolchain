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

Status: not started.

Once M4 and M5 exist, the remaining step is to connect the Rust runtime to the
Lean theorem by a concrete refinement layer.

Required work:

- define a serialization or extraction path from manifest/runtime traces into
  the Lean-level observer structures
- prove that the Rust-emitted theorem trace matches the Lean observer for each
  supported backend
- discharge the ORAM theorem against the chosen standard construction instead of
  relying on the current axiom boundary

Acceptance criteria:

- the paper-facing theorem is backed by an implementation refinement argument
- no gap remains where the theorem only describes a modeled controller/backend
  that the Rust runtime does not actually instantiate

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
