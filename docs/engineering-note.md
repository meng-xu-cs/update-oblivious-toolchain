# Engineering Note

This note is a compact caveat list. Use the topic documents for authoritative
details:

- theorem/TCB/assumptions: [`claim-boundary.md`](./claim-boundary.md)
- proof layers and reports: [`proof-architecture.md`](./proof-architecture.md)
- Path ORAM route: [`path-oram.md`](./path-oram.md)
- runtime boundary: [`runtime/README.md`](./runtime/README.md)

## Exact-UO

`UOCell`, `UOArray`, and full-scan `UOMap` preinitialize confidential regions
with nonzero filler, encode logical zeros as marker-free records, and
rerandomize physical rewrites. Normalized `M+` traces therefore collapse to
public-determined update schedules after initialization.

## Computational-UO

The proof-grade computational path is the concrete
`path_oram_local_posmap_v1` backend. It uses public-schedule path rewrites,
persisted position-map/stash state, canonical fresh-coin families, and Lean
checkers that connect runtime witnesses to the theorem-facing hidden leaf
interface.

The Path ORAM theorem/provenance route is summarized in
[`path-oram.md`](./path-oram.md).

## Remaining Caveats

- Accepted `uint256` syntax is executed in the prototype's bounded `u128`
  domain.
- Parser-level preprocessing remains trusted until a raw-source witness
  relation is added.
- Runtime Keccak uses `tiny_keccak::Keccak::v256()` over canonical bytes; Lean
  source/IR/kernel preservation currently uses a deterministic mock hash.
- Source-backed runtime implementation checks are static-drift evidence, not
  full Rust semantic refinement.
- The runtime witness/certificate extractor remains trusted on the
  implementation side, although replay and reconstruction checks reduce what it
  can assert unchecked.
- Physical side channels and real-time cost behavior are outside the theorem
  boundary.
