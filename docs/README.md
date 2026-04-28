# Documentation Inventory

This directory is the index for repository documentation. It keeps durable
design facts in topic-owned references. Use it first when deciding where a fact
belongs.

## Reading Order

| Need | Source of truth |
| --- | --- |
| Project overview and quick commands | [`README.md`](../README.md) |
| Operator commands and artifact modes | [`runbook.md`](../runbook.md) |
| Paper theorem, observer, assumptions, TCB, and non-claims | [`claim-boundary.md`](./claim-boundary.md) |
| Accepted Solidity/metadata subset | [`supported-subset.md`](./supported-subset.md) |
| Lean/proof architecture and validation reports | [`proof-architecture.md`](./proof-architecture.md) |
| Path ORAM theorem route, provenance, and bibliography | [`path-oram.md`](./path-oram.md), [`path-oram-theorem-sources.bib`](./path-oram-theorem-sources.bib) |
| Runtime boundary, TEE observer, and secret-state ownership | [`runtime/README.md`](./runtime/README.md) |
| Coding-agent process and validation discipline | [`coding-agent-conventions.md`](./coding-agent-conventions.md) |
| Lean workspace map | [`proof/README.md`](../proof/README.md) |
| Generated reviewer-facing result summary | [`results/reviewer_summary.md`](../results/reviewer_summary.md) |

## Topic Map

- Claim boundary: theorem statement, `View_SGX`, exact-vs-ORAM backend scope,
  explicit assumptions, TCB, and non-claims live in
  [`claim-boundary.md`](./claim-boundary.md).
- Proof architecture: source/artifact checking, runtime witnesses, imported
  JSON checkers, legacy isolation, and validation reports live in
  [`proof-architecture.md`](./proof-architecture.md).
- Path ORAM: citation route, theorem objects, assumption provenance, local
  position-map wrapper, and stronger-import status live in
  [`path-oram.md`](./path-oram.md).
- Runtime: trusted-kernel boundary, SGX/TEE observer pins, and secret-bearing
  Rust structures live under [`runtime/`](./runtime/).
- Generated reports: files under `results/` are reproducibility artifacts. Do
  not hand-maintain their prose; update the probe renderer if generated text
  needs to change.

## Inventory Status

| Document | Status | Notes |
| --- | --- | --- |
| [`README.md`](../README.md) | maintained | high-level project map and commands |
| [`runbook.md`](../runbook.md) | maintained | operator command reference |
| [`docs/README.md`](./README.md) | maintained | documentation inventory and topic index |
| [`docs/claim-boundary.md`](./claim-boundary.md) | maintained | theorem, observer, TCB, assumptions, and non-claims |
| [`docs/proof-architecture.md`](./proof-architecture.md) | maintained | proof/checker layers and validation reports |
| [`docs/path-oram.md`](./path-oram.md) | maintained | Path ORAM theorem route and provenance |
| [`docs/runtime/README.md`](./runtime/README.md) | maintained | runtime documentation index |
| [`docs/runtime/trusted-kernel.md`](./runtime/trusted-kernel.md) | maintained | trusted runtime boundary and validators |
| [`docs/runtime/tee-observer.md`](./runtime/tee-observer.md) | maintained | SGX/TEE observer and deployment-assumption surface |
| [`docs/runtime/secret-state.md`](./runtime/secret-state.md) | maintained | secret-bearing runtime structures and ownership invariants |
| [`docs/supported-subset.md`](./supported-subset.md) | maintained | accepted/rejected language and sidecar surface |
| [`docs/engineering-note.md`](./engineering-note.md) | maintained | compact engineering caveats and cross-references |
| [`docs/coding-agent-conventions.md`](./coding-agent-conventions.md) | maintained | process rules for future changes |
| [`proof/README.md`](../proof/README.md) | maintained | Lean workspace map |
| [`benches/harnesses/README.md`](../benches/harnesses/README.md) | maintained | benchmark harness note |
| [`results/artifact_readme.md`](../results/artifact_readme.md) | generated | probe output; source is `probe/mplus-probe` |
| [`results/reviewer_summary.md`](../results/reviewer_summary.md) | generated | probe output; source is `probe/mplus-probe` |
| archived root paper drafts | removed | durable claims moved into maintained docs |
| completed planning notes | removed | durable design decisions moved into topic references above |

## Maintenance Rules

- Add new durable design facts to the topic document that owns them.
- Prefer a cross-reference over copying the same status paragraph into several
  files.
- Do not resurrect completed work-package roadmaps as progress trackers. If a
  future task needs tracking, keep it short, topic-owned, and delete or fold it
  into the relevant topic doc when it is complete.
- When deleting a document, update references from markdown, code comments, and
  Lean provenance strings in the same change.
