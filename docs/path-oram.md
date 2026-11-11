# Path ORAM Route

This document owns the Path ORAM theorem/provenance story for the current
paper claim.

## Current Status

The Lean development states more than it currently proves for Path ORAM:

- The general theorems for both schemes that take a
  `SeededRuntimePathOramProofBundle`, or a `SeededRuntimePaperMainBundle`,
  which extends it, hold vacuously. The bundle's `cfgWellFormed` field
  requires every `OramConfig` to hold only local-scheme objects, and
  `OramConfig` constrains nothing, so no bundle exists
  (`seededRuntimePathOramProofBundle_empty` and
  `seededRuntimePaperMainBundle_empty` in `UOToolchain/RuntimeCoins.lean`).
- `UOToolchain/PathOramAdmitted.lean` states the route over the
  configurations an admission predicate selects.
  `SeededRuntimePathOramProofBundleOn` and `SeededRuntimePaperMainBundleOn`
  guard every field by admission. They give the local theorem for every pair
  of admitted configurations with the same public projection
  (`ComputationalUOWithOn`), the SGX execution theorem over those pairs, and
  the paper-main theorem modulo releases
  (`paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on`). With
  every configuration admitted, `ComputationalUOWithOn` is
  `ComputationalUOWith`. The bundle asks only that every admitted
  configuration's Path ORAM maps use one of the two schemes
  (`PathOramAnyConfigWellFormed`). Where they all use the local scheme, the
  theorems above hold; in general, the same bundle gives the private
  scheme's theorems (`computationalUOWithOnAny`, `paperMainSgxExecutionAny`,
  `paperMain_privatePosmapV1_noninterference_moduloReleases`), whose
  interface (`pathOramAnySchemeSecurityInterface`) admits the leakage of
  either scheme, since a configuration may mix the two.
- This bundle exists. A runtime pair slice is a bundle that admits the pair's
  two sides (`ConcreteRuntimePathOramPairSlice.toPaperMainBundleOn`), which
  agree on the public projection and differ in their secret inputs
  (`toPaperMainBundleOn_admits_distinct_pair`). For example, the pair of
  `SingleAccessMap.put` runs that `checkCanonicalPathOramPaperInstantiation`
  accepts gives a bundle, and the checker derives the general SGX execution
  theorem at the pair's two sides (`sgxViewRelation_sides`), which relates
  the left and right runtime families. That pair makes one ORAM access; the
  multi-access pairs get the theorem from tape families (below).
- Every call that touches a Path ORAM map first reads the whole map: the
  runtime opens the map's counter, every metadata page, and every bucket and
  rebuilds the map's contents inside the enclave
  (`refresh_path_state_from_storage`), and keys and values come from that
  copy. The per-access path reads and rewrites keep the stored tree in Path
  ORAM form and are what the trace records; the call-start reads are not in
  the trace. They follow a fixed pattern set by the public parameters, so
  they reveal nothing, but a call's cost is linear in the map's capacity:
  ERC20Lite `transferFrom` on the local route makes 178 traced reads and 432
  call-start reads (a capacity-64 map: the counter, 16 pages, 127 buckets; a
  capacity-128 map: the counter, 32 pages, 255 buckets). `results/overheads.json`
  reports these next to the traced counts of every ORAM row
  (`call_start_reads`, `call_start_bytes`, `physical_reads_with_call_start`,
  `bytes_read_with_call_start`). A recursive position map would not change
  this cost, so it waits on reading only the accessed paths.
- Calls that abort run on both schemes (`results/abort_rollback.json`). A
  map write makes no ORAM access during the call: it updates an in-enclave
  pending view of the map, which later reads in the call return and which
  decides whether the write overflows the map (a write of a new key to a full
  map aborts the call, as on the full-scan route). At commit each write makes
  one ORAM access, with the write masked off if the call aborted, so an
  aborted call makes the same accesses as a committed one and nothing is
  rolled back; its reads only remapped keys. Restoring the pre-call storage
  instead would leave the touched keys on the leaves the host just saw.
- `path_oram_private_posmap_v1` executes, including several accesses to one
  map per call, and the admitted route covers it (below). The runtime has no
  recursive position map; both schemes share one data path, a flat position
  map in encrypted metadata pages that every access scans in full, so an
  access to a capacity-256 map reads 64 metadata pages and 9 buckets. The
  private scheme differs from the local one in its tag, its recursion-depth
  field (1) and the capacity it admits, not in what an access does or what
  the trace shows. Every access remaps the key it touches to a fresh leaf,
  including a masked write that leaves the key unchanged (a write under a
  false predicate), so the next access to the key reads an independent path.
  The Lean runtime-witness checkers accept the private scheme's events.
- `UOToolchain/PathOramFreshLeaves.lean` proves, without enumerating seeds,
  that one map's leaf schedule does not depend on the accesses. Take any `n`
  accesses (hits, misses, inserts, updates, deletes, masked writes, on any
  keys) and any `p` keys present before the call. If those keys' leaves and
  the call's `2n` coins (two per access: a random path and a next leaf) are
  uniform, every schedule of `n` leaves is equally likely: the schedule is
  distributed as the canonical leaf-value distribution of `n` steps, each
  schedule `L ^ (p + n)` times among the `L ^ (p + 2n)` tapes
  (`observedLeaves_canonical`). The leaves the keys hold after the call are
  uniform and independent of the schedule
  (`observedLeaves_finalLeaves_uniform`), which is the premise for the next
  call, so the statement covers keys written by earlier calls. Every
  transition the Lean replay accepts is a step of this model
  (`replay_runLeaves` for one map, `replay_runLeaves_interleaved` for a
  replay that interleaves several), on either scheme, since both share one
  data path. The
  model is generic in the slot type, so it also covers a call on several maps
  in any interleaving, each map's leaves and coins below its own leaf count:
  the schedule is distributed as the canonical leaf-value distribution of the
  call's scaffold (`multiObservedLeaves_canonical`). The runtime draws two
  coins for a write and one for a read, which it uses as the path when the key
  is absent and as the next leaf when it is present. A read uses one of its
  two model coins either way, so every runtime tape stands for the same number
  of model tapes, and uniform model tapes give uniform runtime coins.
- The bundle's leaf obligation follows from this model, without seed
  enumeration. A `TapeRuntimePathOramWitnessFamily` has a run of the call for
  every tape (the leaves of the keys present before the call, then two coins
  per access), and each run's leaf values are those the model reads from its
  tape. Over its tapes, the runs' leaf values are the canonical distribution,
  each schedule equally often (`leafValues_perm_canonical`). One tape per
  canonical schedule gives a seeded family that realizes the canonical seed
  space (`toSeeded_realizesCanonicalLeafValueSeedSpace`), which is the
  bundle's `canonicalSeedSpace` field. So `TapePathOramPaperMainEvidenceOn`,
  which asks only for facts that hold on every tape (the public view,
  location, shape, outcome and boundary schedule), builds the bundle
  (`toBundle`) and gives the paper-main theorem for every admitted pair.
- One runtime run gives the tape family, without seed enumeration
  (`UOToolchain/PathOramTapeWitness.lean`). Which keys a call touches, and
  whether each access hits, misses, inserts or deletes, depend on the program
  and its data; the coins and the leaves of the keys present before the call
  decide only where the accesses go. So the run on any other tape is the run
  with that tape's leaves substituted: the leaves the model reads and draws on
  the tape go into the leaf schedule, the transitions and the position maps
  before and after, and the bucket locations of the trace move to the new
  paths (`substituteWitness`). Every substituted run passes the Lean
  runtime-witness checks (`substituteWitness_valid`): the replay accepts the
  model's leaves through the run's transitions (`replay_substSteps`), and the
  logical-trace checks read only that a path read's detail is a bucket. The
  substitution keeps the public view, the public locations and the storage
  shape, so a pair of valid runs with the same public values gives
  `TapePathOramPaperMainEvidenceOn` over the pair's two sides
  (`TapePair.toEvidence`) and the theorem between them: the local scheme's
  for a configuration of local-scheme maps
  (`TapePair.sgxViewRelation_sides`), the private scheme's for one with maps
  of either scheme (`TapePair.sgxViewRelation_sides_private`).
- The probe derives this for every multi-access pair from the compact
  theorem input it already checks: SingleAccessMap `add` (4,096 coin seeds),
  ConfidentialMixer `deposit` (262,144) and ERC20Lite `transferFrom`
  (2^44) on the local scheme, and ERC20Lite `transferFrom` with its
  capacity-256 `balances` map on the private scheme and its `allowances` map
  on the local one (2^54). The checker validates every map of the
  configuration against the shape of one of the two schemes
  (`checkAnySchemeProofGrade`) and derives the local scheme's theorem when
  all of them use the local scheme, the private scheme's otherwise; the
  tamper suite gives the private map the local scheme's recursion depth to
  see it rejected
  (`canonical_pathoram_pair_theorem_input/private_recursion_depth_drift`).
  `checkCanonicalPathOramPairTheoremInput` also checks four more
  runtime runs per side, deployed with other seeds and given other coins,
  and finds each equal to its side's run with that run's own tape
  substituted (`sampleCheck`). For both `transferFrom` pairs every such run
  has other leaves for the two keys present before the call;
  `results/canonical_pathoram_pair_validation.json` reports the counts. The
  check compares whole witnesses, all but their seed tag, and the tamper
  suite moves one bucket read
  of a sample to see it rejected
  (`canonical_pathoram_pair_tape_samples/bucket_drift`). That the runtime's
  run on every tape is the substituted run is what these samples test; it is
  not proved of the Rust runtime.

Open work: read only the accessed paths at call time instead of the whole
map, which needs an oblivious key-to-slot index and values served from the
path and stash; then replace the flat position map by a recursive one.

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
checker). Larger maps use `path_oram_private_posmap_v1`, which shares this
data path and gets its theorem from the same admitted route (see Current
Status). Its compact symbolic certificate
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
time. Multi-access calls on either scheme get the theorem from tape families
(see Current Status).

## Assumption Provenance

| Assumption | Provenance |
| --- | --- |
| `stashOverflowBounded` | JACM Path ORAM stash theorem specialized to deployed `Z = 5` / `stash_bound = max(capacity, 1)` parameters |
| `bucketEncryptionINDCPA` | concrete sealed bucket/path records implemented with `ChaCha20Poly1305` and paired with RFC 8439 plus AEAD composition analysis |
| `metadataEncryptionINDCPA` | same sealed-record crypto route for encrypted position-map metadata pages |

Fresh leaf remapping is checked by the canonical fresh-coin runtime-family
interface and hidden-leaf coverage checkers for the single-access
`SingleAccessMap.put` instance, and follows for any call from the leaf model
on tape families (`TapeRuntimePathOramWitnessFamily`), which the probe builds
for the multi-access pairs. It is not part of the explicit backend-assumption
bundle.

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
