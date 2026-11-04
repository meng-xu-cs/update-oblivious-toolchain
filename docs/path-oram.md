# Path ORAM Route

This document owns the Path ORAM theorem/provenance story for the current
paper claim.

## Current Status

The Lean development states more than it currently proves for Path ORAM:

- The general theorems for both schemes take a
  `SeededRuntimePathOramProofBundle`, or a `SeededRuntimePaperMainBundle`,
  which extends it. Its `cfgWellFormed` field requires every `OramConfig` to
  hold only local-scheme objects, and `OramConfig` constrains nothing, so no
  bundle exists (`seededRuntimePathOramProofBundle_empty` and
  `seededRuntimePaperMainBundle_empty` in `UOToolchain/RuntimeCoins.lean`) and
  these theorems hold vacuously.
- The non-vacuous result is the per-configuration paper-main pair boundary
  for `path_oram_local_posmap_v1` (`ConcreteRuntimePathOramPaperPairBoundary`),
  which `checkCanonicalPathOramPaperInstantiation` derives for one concrete pair
  of `SingleAccessMap.put` runs (one ORAM access). Multi-access entrypoints are
  validated through compact theorem inputs, which check a representative
  witness and derive no theorem.
- A call that aborts on the local route is rejected by the runtime
  (`rejected_by_proof_grade_route` in `results/abort_rollback.json`).
- `path_oram_private_posmap_v1` executes, including several accesses to one
  map per call, but it is not yet covered by a theorem. The runtime has no
  recursive position map; both schemes share one data path, a flat position
  map in encrypted metadata pages that every access scans in full, so an
  access to a capacity-256 map reads 64 metadata pages and 9 buckets. Every
  access remaps the key it touches to a fresh leaf, including a masked write
  that leaves the key unchanged (a write under a false predicate), so the next
  access to the key reads an independent path. The Lean
  runtime-witness checkers accept the private scheme's events, but the
  per-configuration paper-main boundary is stated for the local scheme only.

Open work: restate the bundle over admitted configurations; prove without seed
enumeration that fresh coins give independent uniform leaves for several
accesses, including keys written by earlier calls; support aborts on the ORAM
route; and replace the flat position map by a recursive one.

## Current Route

The paper route uses the JACM Path ORAM theorem as the cited theorem source at
the frozen repo interface. The executable artifact route keeps a
self-instantiated closure at the same interface so the repository can validate
the bridge end to end today.

These are different provenance stories, not different theorem boundaries:

- Paper route: cite the JACM theorem source at
  `PaperMainPathOramTheoremSourceAt`.
- Artifact route: keep
  `pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization` as an
  executable cross-check.
- Stronger import route: an external machine-checked theorem object matching
  the repo interface would be future strengthening, not a current in-scope
  task.

## Theorem Objects

The theorem-object order is:

1. `PaperMainPathOramTheoremSourceAt assumptions publicView leafRun`
2. `PathOramJACMLiteratureTheoremAt assumptions publicView leafRun`
3. `PathOramJACMLiteratureTheorem assumptions publicView`
4. `StandardPathOramCoreTheorem assumptions publicView`
5. `PathOramLocalPosmapV1StandardTheoremTarget assumptions`

The first two are preferred because they are fixed at the runtime-facing
`leafRun`, avoiding an extra leaf-run alignment proof.

## Concrete Backend Interface

The concrete backend is `path_oram_local_posmap_v1`. Its Lean interface is
centered on:

- `PathOramLocalPosmapV1SecurityAssumptions`
- `PathOramLocalPosmapV1StandardStorageBoundary`
- `PathOramLocalPosmapV1StandardPaperMainBoundary`
- `PathOramLocalPosmapV1PaperTheoremBoundary`
- `PaperMainRuntimeKernelBoundaryAt`
- `PaperMainRuntimeKernelSlotBoundaryAt`

The local position-map wrapper is not a verbatim copy of vanilla Path ORAM:
it stores encrypted metadata pages, scans those pages in a public fixed shape,
and exposes one theorem-facing `leafRun` from the runtime witness family. The
repo's `PathOramStorageEnvelope` supplies those wrapper-specific public-shape
and storage-projection facts.

The legacy local-position-map route is intentionally capped at capacity `128`
(`PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY` in Rust and
`translationPathOramLocalPosmapMaxCapacity` in the Lean imported-shape
checker). Larger maps use `path_oram_private_posmap_v1`, which executes but is
not yet covered by a theorem (see Current Status). Its compact symbolic certificate
(`ScalablePathOramCertificate`) records six shape numbers instead of
enumerating large seed/family spaces, and `ScalablePathOramCertificate.Subenumerative`
bounds its size and validation steps below the represented capacity. The
private-scheme theorems do not use the certificate, and the Rust
`ScalablePathOramEvidence` mirror is exercised only by unit tests.

Both Path ORAM schemes admit several logical accesses to one map per
entrypoint (`supports_multi_access_per_entrypoint()`): every access draws fresh
leaves and rewrites its path and the metadata pages, and the per-entrypoint
resource bounds scale with the access count. The surrogate scheme is
single-access, and a multi-access surrogate entrypoint is rejected at compile
time. No theorem yet covers multi-access calls on either scheme (see Current
Status).

## Assumption Provenance

| Assumption | Provenance |
| --- | --- |
| `stashOverflowBounded` | JACM Path ORAM stash theorem specialized to deployed `Z = 5` / `stash_bound = max(capacity, 1)` parameters |
| `bucketEncryptionINDCPA` | concrete sealed bucket/path records implemented with `ChaCha20Poly1305` and paired with RFC 8439 plus AEAD composition analysis |
| `metadataEncryptionINDCPA` | same sealed-record crypto route for encrypted position-map metadata pages |

Fresh leaf remapping is checked by the canonical fresh-coin runtime-family
interface and hidden-leaf coverage checkers, which today cover the
single-access `SingleAccessMap.put` instance only. It is not part of the
explicit backend-assumption bundle.

## Sources

Primary citation:

- Emil Stefanov, Marten van Dijk, Elaine Shi, T.-H. Hubert Chan, Christopher
  Fletcher, Ling Ren, Xiangyao Yu, and Srinivas Devadas. "Path ORAM: An
  Extremely Simple Oblivious RAM Protocol." *Journal of the ACM* 65(4),
  Article 18, 2018. DOI: `10.1145/3177872`.

Fallback citation:

- Stefanov et al. "Path ORAM: An Extremely Simple Oblivious RAM Protocol."
  *CCS 2013*. DOI: `10.1145/2508859.2516660`.

Related formal-methods candidates are tracked in
[`path-oram-theorem-sources.bib`](./path-oram-theorem-sources.bib), but none is
currently a drop-in external theorem object for the repo interface.

## Non-Claims

The current paper route does not claim that an external machine-checked Path
ORAM proof has been imported into this repo. It claims a citation-backed
provenance route at a frozen interface plus an executable artifact route at the
same interface.
