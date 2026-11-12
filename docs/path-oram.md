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
- Those theorems also take the public outcome, boundary schedule, final
  public-state record, and release functions as premises. For an entrypoint
  whose kernel program is admitted, the kernel models discharge them
  (`UOToolchain/PathOramKernelPaperMain.lean`), as on the exact route: the
  outcome and the final record are the models of the run a configuration
  denotes (`KernelDenotation`), and the boundary schedule leaves and
  re-enters the enclave around each of the call's ORAM accesses
  (`kernelOramBoundarySchedule`). For example, a private-scheme ERC20Lite
  `transfer` at 256 entries (`h = 11`) reads `balances` twice (11 node
  accesses each) and writes it twice, each write a put of 34 that reuses the
  presence its key's read found, so it crosses the boundary 2 × 90 + 2 = 182
  times whether it completes or aborts; only the last exit's length, 32 or
  0, differs, and the status release erases it. With a bundle,
  `SeededRuntimePathOramProofBundleOn.paperMain_admittedKernelRun_localPosmapV1_noninterference_moduloReleases`
  and its private-scheme form leave only the security assumptions and the
  denotation. The probe checks the runtime's outcomes, boundary schedules,
  and final records against the models on every Path ORAM experiment run
  (`outcome_model_matches`, `final_public_state_model_matches` in
  `results/trace_equivalence.json`).
- This bundle exists. A runtime pair slice is a bundle that admits the pair's
  two sides (`ConcreteRuntimePathOramPairSlice.toPaperMainBundleOn`), which
  agree on the public projection and differ in their secret inputs
  (`toPaperMainBundleOn_admits_distinct_pair`). For example, the pair of
  `SingleAccessMap.put` runs that `checkCanonicalPathOramPaperInstantiation`
  accepts gives a bundle, and the checker derives the general SGX execution
  theorem at the pair's two sides (`sgxViewRelation_sides`), which relates
  the left and right runtime families. That pair makes one ORAM access; the
  multi-access pairs get the theorem from tape families (below).
- A call reads only the paths it accesses. Each position-map page holds,
  after its slots' leaves, each slot's key: the directory in which an access
  finds its key's slot (`encode_path_position_map_page_into`). A call starts
  from the map's counter and metadata pages, the units its first access
  reads, and rebuilds the directory and the stash in the enclave
  (`refresh_path_state_from_storage`); it reads no bucket. An access reads its
  path into the stash and takes the key's value from the key's block there
  (`select_stash_value_for_slot`): the enclave keeps no copy of the map's
  values, and a write held until commit is read back from the call's pending
  writes. Each block a path read loads is checked (slot and leaf in range,
  its bucket on the path to its leaf), and the accessed slot must have exactly
  one block, on its prior leaf and with its key. The call-start reads are not
  in the trace; they follow a fixed pattern set by the public parameters, so
  they reveal nothing. ERC20Lite `transferFrom` on the local route makes 176
  traced reads and 49 call-start reads (a capacity-64 map: the counter and 16
  pages; a capacity-128 map: the counter and 31 pages), and decrypts 93
  payloads in all; reading every bucket at call start, as calls did before,
  added the 382 buckets of the two maps.
  `results/overheads.json` reports the call-start reads next to the traced
  counts of every ORAM row (`call_start_reads`, `call_start_bytes`,
  `physical_reads_with_call_start`, `bytes_read_with_call_start`). On the
  local scheme every access still rewrites every metadata page (the flat
  position map with its keys, linear in the capacity, and the stash, at most
  15 pages), and its trace reads them all, so an access's cost grows linearly
  with the capacity; the scheme is capped at 128. The private scheme's
  accesses are those of its AVL map (below).
- The stash bound is the capacity capped at 114 (`pathOramStashBound`). By
  the Path ORAM stash theorem the stash then overflows after an access with
  probability at most `14 · 0.6002^114 < 2^-80`, which `stashOverflowBounded`
  assumes; an overflow fails the access in band and aborts the call. A map of
  capacity at most 114 keeps a stash as large as itself and cannot overflow.
  The private scheme's AVL map holds the nodes an operation reads in the
  enclave until the operation ends and then returns them to the stash (the
  deferred write-back of Wang et al., Oblivious Data Structures, CCS 2014),
  so its stash bound adds a put's `3h + 1` node accesses to the limit:
  `min(max(capacity, 1), 114 + 3h + 1)` (`pathOramTreeStashBound`; 148 at
  capacity 256, 172 at 16384). That the stash then holds at most 114 blocks
  besides those nodes, with the same tail, is part of what
  `stashOverflowBounded` assumes: the stash theorem is stated for one access
  at a time, not for operations that hold their nodes until they end.
- Calls that abort run on both schemes (`results/abort_rollback.json`). A
  map write makes no ORAM access during the call: it is held in the enclave
  with the call's other writes, and it updates a pending view of the map's
  directory, which decides whether the write overflows the map (a write of a
  new key to a full map aborts the call, as on the full-scan route); on the
  private scheme a write instead makes a get, which finds whether the key is
  present, and the map's size with the call's pending writes applied
  decides. A later
  read in the call returns the value of the call's last write to its key, if
  there is one, and otherwise the value its access read. At commit each write makes
  one ORAM access, with the write masked off if the call aborted, so an
  aborted call makes the same accesses as a committed one and nothing is
  rolled back; its reads only remapped keys. Restoring the pre-call storage
  instead would leave the touched keys on the leaves the host just saw.
- `path_oram_private_posmap_v1` keeps a map as an oblivious AVL tree in one
  Path ORAM tree (the tree section of `generated_oram_codecs.rs`): `n`
  preallocated nodes, the free ones on a list, each node one block that holds
  its key and value and its children's ids, leaves and subtree heights. The
  position map recurses through the tree: the first metadata page holds the
  root's leaf, the free list's head and the size, and every other node's leaf
  is in its parent (a free node's in the previous free node). A get makes `h`
  node accesses and a put `3h + 1`, `h` the largest height of an AVL tree of
  `n` nodes (11 for 256 nodes, 16 for 4096, 19 for 16384), whether the put
  inserts, updates, deletes or does nothing; every choice is masked. Each
  node access is one ORAM access: it reads and rewrites the access counter and
  one path, a node's under its leaf or a fresh leaf's, and evicts the path
  before writing it back; an operation's first access also reads the
  metadata pages (the header and the stash pages) and its last writes them.
  When an operation ends, each node it read takes the coin of the access that
  read it as its new leaf, every pointer to it is fixed, and the nodes return
  to the stash. A map read makes a get, and a map write a get that finds
  whether the key is present and a put at commit. The tree is written only
  when the call commits, so every get of a key during the call finds the
  same presence, and a write reuses it when the program shows that the most
  recent access to its map is a get of the same key: a key expression equal
  to the write's, built only from variables, literals and pure operators,
  none of whose variables is bound again in between (`uo_core::presence_reuse`).
  Such a write makes only the put. The rule reads only the program, so which
  writes reuse a presence is public; the compiler, `uo-check` and the Lean
  translation checker count the accesses with it, the runtime follows it
  from the slot program it runs and checks that the two keys are equal, and
  the tamper suite rejects a manifest that ignores it
  (`translation/presence_reuse_drift`). For example, in ERC20Lite's
  `transfer`, `balances[from] = fromBalance - amount` reuses the presence the
  declaration `fromBalance = balances[from]` found, and
  `balances[to] = balances[to] + amount` the presence of the get in its own
  value. The manifest counts these
  node accesses as the entrypoint's ORAM accesses, and the logical-trace
  checks accept a private-scheme access with all the metadata pages or none
  (`consumeOramAccessMetadataEvents`). Every access remaps what it touches
  to a fresh leaf: on the local scheme the key, including under a masked write
  that leaves it unchanged (a write under a false predicate), on the private
  scheme every node the operation reads.
- What the tree costs: ERC20Lite `transferFrom` with its `balances` map on
  the private scheme makes 90 node accesses at capacity 256 (two gets of 11
  and two puts of 34, each write reusing the presence its read found), 1,060
  traced reads (1.16 MB) in all where the flat position map it replaces made
  308 (347 KB); at capacity 4096, 1,988 reads (2.18 MB) against the flat
  map's 2,244 (2.6 MB); at capacity 16384 (`oram_private_posmap_16384`), 2,636
  reads (2.90 MB), where a flat position map is 2,048 pages read and
  rewritten on every access. Without the reuse each write would add a get:
  112, 162 and 192 node accesses. The tree's cost grows with the square of
  the logarithm of the capacity and the flat map's linearly; the tree costs
  more than the flat map at 256 entries and less from 4,096.
  The per-call allocator event log grows with the call's ORAM commit
  operations (`max_commit_ops`), so these large maps fit it.
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
  replay that interleaves several), on either scheme: a private-scheme node
  access is a read hit (a node read under its leaf, whose coin becomes its
  next leaf) or a read miss (a dummy access, whose coin is the path read),
  with the tree's nodes as the slots. The
  model is generic in the slot type, so it also covers a call on several maps
  in any interleaving, each map's leaves and coins below its own leaf count:
  the schedule is distributed as the canonical leaf-value distribution of the
  call's scaffold (`multiObservedLeaves_canonical`). On the local scheme the
  runtime draws two coins for a write and one for a read, which it uses as the
  path when the key is absent and as the next leaf when it is present; on the
  private scheme it draws one coin per node access. A read uses one of its
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
  on the local one (2^734: 90 node accesses of 256 leaves each, and two
  coins of 128 leaves; the theorem input carries the seed count as an exact
  integer). The checker validates every map of the
  configuration against the shape of one of the two schemes
  (`checkAnySchemeProofGrade`) and derives the local scheme's theorem when
  all of them use the local scheme, the private scheme's otherwise; the
  tamper suite gives the private map the local scheme's recursion depth to
  see it rejected
  (`canonical_pathoram_pair_theorem_input/private_recursion_depth_drift`).
  `checkCanonicalPathOramPairTheoremInput` also checks four more
  runtime runs per side, deployed with other seeds and given other coins,
  and finds each equal to its side's run with that run's own tape
  substituted (`sampleCheck`). For the local `transferFrom` pair every such
  run has other leaves for the two keys present before the call, and for the
  private one other leaves for every node of the tree, which a deployment
  places under fresh leaves;
  `results/canonical_pathoram_pair_validation.json` reports the counts. The
  check compares whole witnesses, all but their seed tag, and the tamper
  suite moves one bucket read
  of a sample to see it rejected
  (`canonical_pathoram_pair_tape_samples/bucket_drift`). That the runtime's
  run on every tape is the substituted run is what these samples test; it is
  not proved of the Rust runtime.

The AVL map's algorithm is proved in Lean over inductive trees
(`UOToolchain/PathOramAvlMap.lean`). The model takes the runtime's steps: a
get walks the key's path for `h` levels; a put walks it too, going on to the
successor for a delete of a node with two children, changes the tree at the
bottom of the walk, and rebalances up to the root, rotating a node whose
children differ in height by two, double when the taller child leans the
other way. For a map that is sorted, balanced, free of zero values and within
its capacity, with `h` the capacity's largest AVL height, `get_spec` and
`put_spec` prove that a get returns the key's value and a put writes,
updates or deletes it, keeps all of that, and overflows exactly when it would
insert into a full map; `height_le_avlHeight` is why `h` levels suffice, and
`getAccesses_length_shape` and `putAccesses_length_shape` give each
operation the trace shape's node-access count. The runtime is checked
against the model by replay: `checkPathOramAvlMapReplay` reruns 2,400
runtime operations on maps of 1 to 31 nodes (`--only path-oram-avl-map-replay`,
`results/path_oram_avl_map_replay.json`) and compares every result, every
node access's kind, every size and every tree with its stored heights; the
replay also checks the pointer level the model leaves out, and the checker
rejects a replay with one of those facts changed.

The capacity sweep (`--only capacity-sweep`, `results/capacity_sweep.json`)
measures SingleAccessMap's `read`, one map get, and `put`, one map write, on
a map of 1 to 16,384 entries on the full scan and on both schemes (the local
one up to its cap of 128, with its rejection at 256), each on one deployment
over several keys, and checks that every operation costs the same in every
trial. On the full scan and the local scheme a read costs what a write does;
on the tree a write, a get and then a put of `3h + 1` node accesses, costs
about four times a read: 260 against 980 physical operations at 256 entries,
654 against 2,556 at 16,384. The full scan moves 380 bytes per entry per
operation. The tree moves fewer bytes than the full scan from 2,048 entries
for reads alone, 4,096 for an even mix and 8,192 for writes alone; it makes
fewer physical operations from 128, 512 and 1,024 entries, and costs less
modeled gas from 512, 2,048 and 4,096. The local scheme makes fewer
operations and costs less gas than the full scan from 8 entries but moves
more bytes at every capacity it admits, and up to its 128 entries it costs
less than the tree on every metric.

The sweep runs from a release build and splits each call's wall-clock
latency (the median of three trials) into the time the instrumented runtime
spends on the proof objects it exports, the position-map witnesses and the
execution trace's proof bundles, and the rest, its own work
(`p50_witness_ns`, `p50_proof_objects_ns`, `p50_runtime_ns`;
`latency_break_even` compares both). These are medians of three trials
without warmup, so they move from run to run; the ranges below are those of
the last five bundles, all run on one machine, and
`results/capacity_sweep.json` holds the last run. On its own work the tree is
faster than the full scan for reads from 8,192 entries in every run (25 to
31 ms against 33 to 36 at 8,192, 42 to 57 against 69 to 72 at 16,384) and
for an even mix from 16,384, while a write alone stays slower (78 to 88 ms
against 69 to 76 at 16,384). At 4,096 entries a read on the tree and one on
the full scan are within the noise: the tree was the faster in four runs of
the five. Whole calls on the tree are slower at every capacity measured (463
to 545 ms against 324 to 380 for a read at 16,384): to export the
position-map witnesses, the runtime decodes every bucket of the tree at the
start and the end of each call, 387 to 453 ms of that read, where the full
scan's time goes to the proof bundles of its 32,768-event trace (252 to 305
ms). Issue 27 of
[`review/2026-11-external-review`](../review/2026-11-external-review/README.md)
replaces these with warmed-up, larger samples. A node access evicts the stash
bucket by bucket, placing a block in the
bucket at a given depth exactly when its leaf and the read leaf agree above
that depth (the leaf count is a power of two), and moves blocks with in-place
masked selects; at 4,096 entries this takes 2.2 times fewer instructions per
node access than walking each block's path and cloning its key and value (2.4
times fewer in the bucket eviction itself), with every block placed where it
was before. The counts are callgrind's, from release builds before and after
the change, and repeat exactly from run to run
(`results/tree_eviction_instructions.json`, written by
`scripts/measure_tree_eviction_instructions.sh`).

What remains open on the private scheme: the runtime's pointer-level
implementation of the AVL map (node ids, leaves, the free list, the stash)
is replayed against the model and run against a reference map in the
runtime's tests, not proved; and the stash bound for operations that hold
their nodes until they end is assumed (`stashOverflowBounded`). A write
whose key the program does not show equal to a preceding get's (another key
expression, a key read from storage, or a key variable bound again in
between) still makes its own presence get, and the tree costs more than a
flat position map below a few thousand entries.
The instrumented runtime decodes every bucket of a tree twice per call to
export the position-map witnesses its checks consume, so its calls take time
linear in the capacity even where the ORAM's own work is logarithmic.

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
checker). Larger maps use `path_oram_private_posmap_v1`, which keeps them
as an oblivious AVL tree and gets its theorem from the same admitted route
(see Current Status). Its compact symbolic certificate
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

The three assumptions below are named in Lean and not formalized: each is a
`Prop` field that no proof uses and that the checkers fill with `True`. What
Lean proves about a Path ORAM call is that its leaf schedule is uniform and
that the two sides of a pair write storage at the same locations with the
same shapes. The step to computational indistinguishability is an argument
on paper, with the bound `ε(Q) ≤ ε_PRF + ε_AEAD + ε_nonce + Q · ε_stash`
over `Q` primitive accesses; the Explicit Assumptions section of
[`claim-boundary.md`](./claim-boundary.md) defines each term.

| Assumption | Provenance |
| --- | --- |
| `stashOverflowBounded` | JACM Path ORAM stash theorem specialized to deployed `Z = 5` / `stash_bound = min(max(capacity, 1), 114)` parameters: a stash overflows after an access with probability at most `14 · 0.6002^114 < 2^-80`, and a map of capacity at most 114 cannot overflow |
| `bucketEncryptionINDCPA` | concrete sealed bucket/path records implemented with `ChaCha20Poly1305` and paired with RFC 8439 plus AEAD composition analysis. A record's key derives from the runtime's master secret and its nonce is the count of the seals under the key, so no key seals twice with one nonce (see [`claim-boundary.md`](./claim-boundary.md)) |
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
