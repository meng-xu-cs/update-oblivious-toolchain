# Archived Pilot-Paper Note

This file used to contain an early "constant-gas programming" paper draft.
That framing predates the current repository state and is no longer an accurate
description of the codebase on its own.

The current implementation still includes constant public gas as one required
public observer component, but the repository has moved to a broader
update-oblivious toolchain with a richer observer and proof bridge:

- logical access schedules matter, not only gas
- marker-aware physical write classes matter, not only gas
- the paper-facing observer now includes `public_outcome`, exact
  `boundary_schedule`, backend `storage_trace`, and a normalized SGX
  `micro_trace`
- the runtime exports theorem-facing controller, hidden-state, trusted-kernel,
  and refinement-witness artifacts that the Lean side checks directly

## Current Repository Scope

The maintained codebase implements:

- a restricted Solidity compiler with sidecar metadata
- a checker that performs theorem-relevant source/artifact translation
  validation
- an in-process runtime with exact backends plus the concrete
  `path_oram_local_posmap_v1` path
- Lean-backed validation for controller certificates, hidden Path-ORAM
  certificates, trusted-kernel bundles, refinement witnesses, seeded witness
  families, and canonical Path-ORAM pair artifacts

## Current Documentation

For the maintained design and claim surface, use:

- `README.md`
- `docs/supported-subset.md`
- `docs/formal-proof-plan.md`
- `docs/implementation-roadmap.md`
- `docs/paper-theorem-profile.md`

## Historical Status

The old pilot draft mixed useful motivation with implementation assumptions
that no longer match the repository. It now remains only as a short archival
pointer so the path is not confused for current, verified documentation.
