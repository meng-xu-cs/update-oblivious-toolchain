# Engineering Note

This note is a compact caveat list. Use the topic documents for authoritative
details:

- theorem/TCB/assumptions: [`claim-boundary.md`](./claim-boundary.md)
- proof layers and reports: [`proof-architecture.md`](./proof-architecture.md)
- Path ORAM route: [`path-oram.md`](./path-oram.md)
- runtime boundary: [`runtime/README.md`](./runtime/README.md)

## Exact-UO

`UOCell`, `UOArray`, and full-scan `UOMap` preinitialize confidential regions
with sealed filler records, seal a logical zero as they seal any other
value, and seal again on every physical rewrite. A sealed record is a whole
number of 32-byte units; each unit begins with one of two nonzero marker
bytes, and a rewrite carries the marker that the record it replaces does
not. No unit is zero and none repeats, so normalized `M+` traces collapse to
public-determined update schedules after initialization.

A call reads every exact object it accesses once: it opens every slot when
it loads the object, in object-id order, and its accesses, however many,
work on the opened copy. The trace records the read at the load. When the
call commits, it rewrites slot by slot exactly the exact objects its program
has a write statement for: whether or not the write's predicate held, and
also when the call aborted, with what the object held. An object the
program only reads is not rewritten. Both rules are static: they are read
off the program, which is public, and not off what a run did, so they show
nothing about a run. The manifest names the written objects
(`may_write_objects`); the load bound counts the slots of the accessed
objects, and the commit bound and the modeled cost the slots of the written
ones.

Commit opens no sealed record. At its first write of an object a call keeps
a copy of what it loaded, and an aborted call reseals that copy, so an
abort does the cryptographic work of a commit: one opening of each slot at
the load and one seal of each slot at the commit.

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
