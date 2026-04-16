# Implementation Roadmap To Proof-Grade SGX/TEE Conformance

This note no longer describes a speculative implementation plan. It records the
current milestone status of the repository and the remaining work needed for
stronger theorem provenance claims.

## Goal

The implementation target remains:

- confidential entrypoints emit an explicit public observer consisting of
  `public_outcome`, exact `boundary_schedule`, protected `storage_trace`, and a
  normalized SGX controller `micro_trace`
- persistent state leaving the enclave boundary is confidential and integral
- unsupported programs are rejected rather than accepted under an inexact
  public witness
- the Rust implementation is connected to the Lean theorem boundary by an
  explicit certificate / witness bridge rather than by documentation alone

The theorem-facing backend path is
`path_oram_local_posmap_v1`. The legacy surrogate backend remains in the
repository only for compatibility and benchmark continuity.

## Theorem-Preserving Principles

- Do not relax the theorem to fit the implementation.
- Reject unsupported programs instead of widening the public leakage witness.
- Keep every public observer field explicit in the runtime trace.
- Keep the trusted Rust surface small and explicit.

## Milestones

### M1. Runtime theorem observer

Status: implemented.

The runtime now emits:

- `public_outcome`
- exact `boundary_schedule`
- public controller shape
- normalized SGX micro trace derived from that controller shape

That observer is assembled from the runtime controller/recorder path itself,
and the controller certificate independently reconstructs the same public
observer before a trace is returned.

### M2. Sealed persistent storage

Status: implemented.

Confidential storage records now use authenticated encryption with associated
data before nonzero transport encoding. The old marker-hiding placeholder codec
is no longer the only storage story:

- exact backends keep post-initialization writes on the update-only path
- decode/open rejects tampering
- sealed-storage facts are now part of the explicit assumption provenance
  surface

### M3. Exact public leakage witnesses

Status: implemented on the current admitted subset.

The compiler/checker path now enforces compile-time-exact loop structure for
admitted confidential code and validates the manifest fields that the theorem
bridge consumes:

- secret-argument positions
- arena and stack budgets
- exact object manifests
- exact logical read/write counters
- exact ORAM access counts
- exact `max_commit_ops`

`uo-check` also supports explicit source-to-artifact translation validation, so
the proof-relevant artifact surface is re-derived rather than merely trusted
after compilation.

### M4. Proof-grade ORAM backend path

Status: implemented for the theorem-facing path.

The repository now contains a concrete standard-style backend candidate,
`path_oram_local_posmap_v1`, with:

- a real tree and real path rewrites
- persisted access counters
- persisted position-map state
- persisted stash state
- immediate access execution on transaction shadow state rather than a
  one-shot staged commit surrogate
- multi-access-per-entrypoint support on the theorem-facing path
- manifest/runtime parameter sharing through `OramManifest::for_object`

The stronger backend is already exercised beyond `SingleAccessMap` in the probe
and witness reports, including multi-access `ConfidentialMixer` and multi-map
`ERC20Lite` paths.

### M5. Explicit SGX/controller runtime path

Status: implemented.

The runtime now has a call-scoped controller recorder that emits:

- ordered logical accesses and logical writes
- ordered physical reads and writes
- exact enclave-boundary events
- controller-phase observations
- public region page budgets and workset budgets

The emitted theorem trace is controller-derived and then cross-checked against
an independent pure reconstruction over the recorded public ORAM schedule.

### M6. Runtime refinement and trusted kernel

Status: largely implemented; remaining work is theorem strengthening rather
than missing bridge engineering.

The runtime/proof bridge now includes:

- standalone controller-observer certificates
- standalone hidden Path-ORAM certificates
- an explicit `RuntimeTrustedKernelBundle`
- runtime-enforced refinement-witness extraction
- Lean JSON import and executable validation for the bundle and witness
- seeded witness-family and paired-certificate validation
- canonical fresh-coin family and pair validation, with compact and heavy
  artifact modes

What remains is not "build the bridge." It is:

- keep the trusted boundary explicitly at that small emitted kernel
- justify or import the explicit backend/cryptographic assumptions cleanly
- avoid overclaiming the rest of the Rust stack as verified

### M7. Paper-main standard-theorem route

Status: implemented at the frozen interface; stronger external import remains
future work.

The repository now has:

- a frozen standard-theorem target:
  `PathOramLocalPosmapV1StandardTheoremTarget`
- an explicit literature-facing JACM theorem object and mapping
- a self-instantiated artifact-side closure at exactly the same interface
- a separate paper-main provenance route documented for the citation-based
  presentation

That means the theorem boundary is fixed and the engineering bridge is closed.
What remains open is only the provenance choice:

- citation route now
- stronger external machine-checked theorem import later, if available

## Immediate Next Steps

The remaining work should be treated as theorem-strengthening:

1. keep `path_oram_local_posmap_v1` as the only proof-grade backend path in
   docs and claim language
2. keep the trusted boundary at emitted certificates, the trusted-kernel
   bundle, and witnesses reconstructed from that bundle
3. keep `uo-check` as the translation validator for proof-relevant compiler
   output
4. present the current paper route as the JACM citation route at the frozen
   interface
5. separately justify or import the explicit
   `PathOramLocalPosmapV1SecurityAssumptions` bundle if a stronger provenance
   story is needed
6. do not upgrade the repo into a malicious-host SGX execution theorem until
   the SGX observer and enclave controller are connected to the real runtime by
   the same refinement discipline

## Practical Readout

The implementation roadmap is no longer blocked on missing runtime/controller
plumbing, missing witness extraction, or missing theorem-interface alignment.
The remaining work is about provenance, backend assumption discharge, and
careful claim discipline.
