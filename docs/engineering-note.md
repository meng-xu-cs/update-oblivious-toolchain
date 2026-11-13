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

A call scans every exact object it accesses and, when it commits, rewrites
slot by slot exactly the exact objects its program has a write statement
for: whether or not the write's predicate held, and also when the call
aborted, with what the object held. An object the program only reads is not
rewritten. The rule is static: it is read off the program, which is public,
and not off what a run did, so it shows nothing about a run. The manifest
names the objects (`may_write_objects`), and the commit bound and the
modeled cost count the slots of those objects only.

## Computational-UO

The proof-grade computational path is the concrete
`path_oram_local_posmap_v1` backend. It uses public-schedule path rewrites,
persisted position-map/stash state, canonical fresh-coin families, and Lean
checkers that connect runtime witnesses to the theorem-facing hidden leaf
interface.

The Path ORAM theorem/provenance route is summarized in
[`path-oram.md`](./path-oram.md).

## Remaining Caveats

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
