# Archived Draft Note

This file previously held a long research-paper draft that ranged well beyond
the current repository: cross-stack empirical case studies, ecosystem-level
arguments, and proposed evaluation sections that are not represented in the
codebase today.

Those claims were not maintainable as repository documentation, so the stale
draft text has been removed. What remains relevant to the current workspace is
summarized here.

## Concepts That Survive In The Codebase

- the stronger `M+` observer, with marker-aware write classes
  `SET`, `CLEAR`, `SAME`, and `UPDATE`
- exact-UO for exact backends and theorem-facing computational-UO for the
  concrete `path_oram_local_posmap_v1` backend
- semantic write linearization into an explicit UO IR
- public gas equalization for confidential entrypoints
- update-only sealed storage for the exact backends
- controller-oriented theorem observers for the SGX-facing paper profile
- an explicit runtime bridge consisting of controller certificates, hidden
  Path-ORAM certificates, proof-grade kernel witnesses, trusted-kernel
  bundles, refinement witnesses, shell-boundary / confidential-core bundles,
  and Lean-backed validators

## What This Repository Does Not Currently Document Through Code

- the earlier cross-stack empirical claims about Oasis localnet,
  qcow2/LUKS/QEMU, or OpenSSL
- a general-purpose checker architecture for arbitrary LLVM, MIR, or other
  non-Solidity frontends
- a blanket malicious-host SGX theorem
- a theorem that every Rust implementation detail below the emitted trusted
  kernel is formally verified

## Current Sources Of Truth

For the maintained implementation and theorem boundary, use:

- `README.md`
- `docs/supported-subset.md`
- `docs/engineering-note.md`
- `docs/formal-proof-plan.md`
- `docs/implementation-roadmap.md`
- `docs/imported-theorem-bridge-checklist.md`
- `docs/paper-main-theorem-checklist.md`
- `docs/paper-theorem-profile.md`

## Why This File Still Exists

The old draft title and path are still useful as historical context for the
project, but the repository should not present speculative paper text as if it
were checked against the current implementation. This shorter archival note
keeps that distinction explicit.
