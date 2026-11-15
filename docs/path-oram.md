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
  by reading the map's counter and metadata pages from the store, and
  rebuilds the directory and the stash in the enclave
  (`refresh_path_state_from_storage`); it reads no bucket. It holds those
  records through the call, and no access opens them again. An access reads its
  path into the stash and takes the key's value from the key's block there
  (`select_stash_value_for_slot`): the enclave keeps no copy of the map's
  values, and a write held until commit is read back from the call's pending
  writes. Each block a path read loads is checked (slot and leaf in range,
  its bucket on the path to its leaf), and the accessed slot must have exactly
  one block, on its prior leaf and with its key. The trace names each read
  where the call makes it: the counter and the metadata pages once, where
  the call loads the map (`OramStorage::read_counter_and_pages`, which
  `OramState::refresh_from_storage` calls with the call's recorder), and the
  buckets of each access. Those reads
  follow a fixed pattern set by the public parameters, so they reveal
  nothing, and the store that keeps a map's records sees them one for one
  (`results/storage_boundary.json`; see The Storage Boundary in
  [`claim-boundary.md`](./claim-boundary.md)). ERC20Lite `transferFrom` on
  the local route reads 94 records of 51,712 bytes: 50 when it starts (a
  capacity-64 map: the counter and 16 pages; a capacity-128 map: the counter
  and 32 pages) and 44 buckets. Until Issue 57 of the external review its
  trace named the counter and the pages again at every access, 178 reads of
  103,680 bytes, and the modeled cost charged those. Reading every bucket at
  call start, as calls once did, added the 382 buckets of the two maps. Each
  access still names the counter and the pages it uses in the logical trace,
  which is the controller's: the enclave consults them at every access. On
  the local scheme every access still rewrites every metadata page (the flat
  position map with its keys, linear in the capacity, and the stash, at most
  16 pages), so an access's cost grows linearly with the capacity; the
  scheme is capped at 128. The private scheme's accesses are those of its
  AVL map (below).
- The stash bound is the capacity capped at 152 (`pathOramStashBound`). By
  the Path ORAM stash theorem (Stefanov et al., JACM 2018, Theorem 5.1, at 5
  blocks per bucket) the stash holds more than `R` blocks after an access
  with probability at most `14 · 0.6002^R`, which is below `2^-108` at
  `R = 152`. The cap is set for the lifetime of a map and not for one
  access: over `Q` node accesses the union bound gives `Q · 14 · 0.6002^152`,
  at most `2^-60` for the `2^48` node accesses the cap budgets and `2^-68`
  for `2^40`. An ERC20Lite `transfer` at 16,384 entries makes 154 node
  accesses, so `2^48` of them are about 1.8 trillion transfers. The runtime
  does not stop a map at `2^48` accesses; past it the bound grows with `Q`.
  `stashOverflowBounded` assumes the per-access bound. A map of capacity at
  most 152 keeps a stash as large as itself and cannot overflow, so the
  local scheme, capped at 128 entries, needs no stash assumption.
  The private scheme's AVL map holds the nodes an operation reads in the
  enclave until the operation ends and then returns them to the stash (the
  deferred write-back of Wang et al., Oblivious Data Structures, CCS 2014),
  so its stash bound adds a put's `3h + 1` node accesses to the limit:
  `min(max(capacity, 1), 152 + 3h + 1)` (`pathOramTreeStashBound`; 186 at
  capacity 256, 210 at 16384). That the stash then holds at most 152 blocks
  besides those nodes, with the same tail, is part of what
  `stashOverflowBounded` assumes: the stash theorem is stated for one access
  at a time, not for operations that hold their nodes until they end. It is
  measured, not proved. `results/stash_occupancy_full.json`
  (`scripts/run_stash_occupancy_full.sh`) runs the runtime's own tree
  operations, with their eviction and compaction, over buckets in memory and
  without the cryptography: 10.8 million node accesses on maps of 256,
  1,024, 4,096 and 16,384 entries, under random, repeated-key and
  insert-and-delete workloads, with the stash counted after each. While an
  operation holds its nodes the stash held at most 9 blocks, and fewer than
  one on average; once an operation had returned them it held at most 18,
  the nodes that operation read. The stashes are 186 to 210 blocks, so the
  least headroom seen is 175 blocks. The report checks every count against
  the assumed tail, more than `3h + 1 + R` blocks with probability at most
  `14 · 0.6002^R`, and fails on a count the tail does not allow. Ten million
  accesses say nothing about an event of probability `2^-108`: the
  simulation would show a stash that grows with deferred write-back, and it
  shows none.
- A stash overflow is an error, not an abort. The access that finds no room
  for a block stops (`stash_overflow_error` in `generated_oram_codecs.rs`),
  so the call that made it is dropped before anything of it is committed and
  the committed map keeps every block. The caller sees an internal error
  and so learns that the stash overflowed, an event the bound counts
  (`Q · ε_stash`, under Assumption Provenance). The dropped call does not
  remap the keys it read, as an aborted call does (next item); that too
  happens only when the stash overflows. A map whose stash is full refuses
  the calls that would overflow it and takes the others: it can be read,
  and it is not corrupted. Before, the block that found no room was dropped,
  the access reported a failure, and the call aborted with its ORAM
  accesses kept; on the private scheme the lost block was a tree node, and
  its subtree was no longer reachable. `results/stash_occupancy.json`
  forces an overflow on the runtime: every node access of every put on a
  map of 256 entries draws the same leaf, so the nodes the puts read pile
  up on one path of 45 blocks and in the stash of 186. The 232nd put fails
  with the error, the committed ciphertext is what it was before that call,
  the 231 keys stored before it read back, and the map takes a write again.
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
  and two puts of 34, each write reusing the presence its read found), and
  the call reads 885 sealed records (545 KB): each map's counter and
  metadata pages once, and the path of each access. At capacity 4096 it
  reads 1,767 (1.08 MB), and at capacity 16384
  (`oram_private_posmap_16384`) 2,388 (1.46 MB), where a flat position map
  is 2,048 pages rewritten on every access. When the private scheme kept a
  flat position map, its trace named 308 reads (347 KB) at capacity 256 and
  2,244 (2.6 MB) at 4096, in records of the size they had then, and the
  counter and the pages at every access. Without the reuse each write would
  add a get: 112, 162 and 192 node accesses. The tree's cost grows with the
  square of the logarithm of the capacity and the flat map's linearly; the
  tree costs more than the flat map at 256 entries and less from 4,096.
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
  (`canonical_pathoram_pair_tape_samples/bucket_drift`).
- That the runtime's run on every tape is the substituted run is tested, not
  proved of the Rust runtime. The samples of the pairs test it, and the
  tape-substitution report tests it over many seeds
  (`--only tape-substitution`, `results/tape_substitution.json`; its full
  profile is `--only tape-substitution-full`,
  `results/tape_substitution_full.json`, which the validation script runs
  from a release build). For a SweepMap of
  each scheme at three capacities (8, 32 and 128 on the local scheme, 16, 64
  and 256 on the private one) the full profile draws two workloads from a
  seed. A workload is a setup of 13 calls (puts, deletes, reads, and writes
  behind a guard that fails) and then one call of each of seven kinds: a read
  that hits, a read that misses, an insert, an overwrite, a delete, a delete
  of an absent key, and a write that aborts. Each of the 84 calls runs once as
  the representative and then on 16 other deployment seeds, and
  `checkPathOramTapeSamples` finds each of the 1,344 runs equal to the
  representative run with its own tape substituted (`sampleCheck`). So the
  substitution is tested over 1,344 tapes, each with other leaves before the
  call than the representative's. The quick profile, which CI regenerates,
  runs 14 calls on 3 other seeds each: 42 tapes, 41 of them other than the
  representative's. The checker rejects a sample with one bucket read moved, a
  sample that is a run of another call, and a sample with a read dropped. A
  run that differs makes the report's `accepted` false, which fails the
  acceptance gate.

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
operation the trace shape's node-access count. The runtime is tested
against the model by replay, not proved to follow it. A replay runs random
gets, writes, deletes and masked puts on the runtime's `tree_get` and
`tree_put` over buckets in memory, and `checkPathOramAvlMapReplay` reruns
them on the model and compares every result, every node access's kind,
every size, and every recorded tree with its stored heights. The quick
profile (`--only path-oram-avl-map-replay`,
`results/path_oram_avl_map_replay.json`), which CI regenerates, makes 2,400
operations on maps of 1 to 31 nodes and compares the tree after each. The
full profile (`--only path-oram-avl-map-replay-full`,
`results/path_oram_avl_map_replay_full.json`), which the validation script
runs from a release build, makes 7,398 operations and 287,861 node accesses
on maps of 127, 500, 1,024 and 2,048 nodes: each map is filled by writes of
distinct random keys and then takes as many mixed operations as it holds.
3,559 of its operations leave a tree of at least 1,024 nodes, 408 are puts
that overflow a full map, and the tree is compared after every 64th
operation and after the last (116 trees, the largest of 2,048 nodes). After
every operation of either profile the replay also checks the pointer level
the model leaves out: every node block lies on its leaf's path and is stored
once, every tree and free-list pointer carries its node's current leaf, the
tree and the free list are acyclic and together hold every node, and the
stash is within its bound. The checker rejects a replay with a node access's
kind, a stored height, a get's value or a put's overflow changed, and one
with no tree after its last operation.

The capacity sweep (`--only capacity-sweep`, `results/capacity_sweep.json`,
schema `uo-capacity-sweep-v4`) measures one map of 1 to 16,384 entries on the
full scan and on both schemes (the local one up to its cap of 128, with its
rejection at 256). Its contract is SweepMap (`benches/raw/SweepMap.sol`):
SingleAccessMap's `read`, one map get, and `put`, one map write, with a
`clear` and a `putBelow`, a write behind a `require` guard. Each map is
filled to 2 keys and then to 25%, 50%, 90% and 100% of its capacity, with
keys drawn from a fixed seed, through a bulk loader that only a diagnostics
build has (`ContractInstance::bulk_load_map_for_diagnostics`): it makes the
writes of committed calls with no trace, witness or proof object, since an
instrumented call per key takes a quarter of a second on the tree at 16,384
entries. At each level the
sweep measures seven kinds of call in rounds: a read of a stored key and of
an absent one, an insert, an overwrite, a write of the value a key already
has, a delete, and a write whose guard fails, which aborts. It then
executes, for each read fraction, a seeded sequence of reads and of writes
of every kind, and reports what the sequence cost next to the mix computed
from one read and one write.

The counts are a function of the seed. `counts_sha256`, the digest of the
report without its timings, repeats from run to run, and a probe test runs a
small sweep twice and compares it. The report checks (`count_checks`) that
each kind of call costs the same in every trial, at every occupancy level,
and as every other kind its entrypoint serves: an insert, an overwrite and a
write that changes nothing are one `put` to the observer, and how full the
map is does not show. A write that aborts traces what a committed one does,
on every backend. On the local scheme a read costs what a write does. A
sealed map record is 96 bytes, three 32-byte units, and a sealed 256-bit
value 64: each unit is one marker byte and 31 bytes of nonce, ciphertext and
tag (the nibble encoding these records had before took 190 and 124 bytes).
On the full scan a write moves 192 bytes per entry, the scan and the rewrite
of every slot, and a read moves 96: it scans the map and rewrites nothing,
since its program has no write statement for the map. On the tree a write, a
get and then a put of `3h + 1` node accesses, costs three and a half to four
times a read: 260 against 931 physical operations at 256 entries, 646
against 2,472 at 16,384. The tree moves fewer bytes than the full scan from
4,096 entries for reads alone and from 8,192 for an even mix and for writes
alone; it makes fewer physical operations from 512 entries for reads alone
and for an even mix and from 1,024 for writes alone; and it costs less
modeled gas from 1,024 for reads alone and from 2,048 for an even mix and
for writes alone. The stash cap of 152 costs a tree access 10 of these
operations, the five stash pages it added, read once per call and written
once per operation: 2.3% of a read's bytes at 16,384 entries and 5.7% at
256; under cost model v2 it moved the gas break-even for reads alone from
1,024 entries to 2,048. The gas is that of cost model v3, which charges the
sealed records a call reads as it charges those it writes, and counts a
map's counter and metadata pages once, where the call reads them (see The
Modeled Cost in [`claim-boundary.md`](./claim-boundary.md)); v2 counted
them again at every access, and on the tree at 16,384 entries charged a
read 51,354 units where v3 charges 35,375. The local scheme makes fewer
operations than the full scan from 32 entries for reads alone, 16 for an
even mix and 8 for writes alone, and costs less gas from the same
capacities (from 128, 32 and 16 under v2), but moves more bytes at every
capacity it admits, and up to its 128 entries it costs less than the tree on
every metric.

A call on a Path ORAM map reads the map's counter and metadata pages when it
starts, 29 reads of 27,840 bytes on the tree at 16,384 entries, holds them
through the call, and its trace names them there: a read on that tree
traces 314 reads, the ones its store sees, where its trace named 332 before
Issue 57, the counter again at every node access. Beside the traced counts
the report gives the work that no trace records. An
instrumented call exports the position maps before and after it as a
witness. It once decoded them from storage, every bucket and metadata page
of the tree twice: 65,590 sealed records at 16,384 entries, where a read
traces 646 operations. The runtime now keeps the witness from call to call
and a call moves it by its own leaf transitions, so a measured call opens no
record for it (`witness_scan_records` is 0 in every row). The decode
happens once after each bulk load (`witness_decode_records` of a fill:
32,795 records at 16,384 entries) and in the audit, which compares the kept
witness with that decode. The sweep audits after every occupancy level and
not in the calls it times; every other instrumented call audits before it
runs and after. A production call records no witness at all. The report also gives
the size of what a call exports: at 16,384 entries the trace of a full-scan
read is 9.2 KB of JSON, where that of a map of two entries is 9.1 KB, and
that of a tree read 2.8 MB, 2.4 MB of it private evidence. A trace holds
the scan of an exact object, its rewrite and the logical scan of a map as
one item each, with the slot count and the length of a sealed slot, so the
trace of a call on a full-scan map does not grow with the map.

The latencies are wall-clock times of a release build on one machine. The
validation script runs a quick profile of the sweep, whose latencies are a
smoke test: one warmup round and two measured rounds, workloads of five
calls, maps above 256 entries left at 2 keys, and the maps' records kept in
memory. The figures below come from the full profile
(`scripts/run_capacity_sweep_full.sh`, `results/capacity_sweep_full.json`):
30 measured rounds of every kind of call after 5 warmup rounds, at every
occupancy level of every map, and a workload of 20 calls at each read
fraction, with the maps' sealed records kept in files and every commit
synced. Each figure is a median with its 95% bootstrap interval. A call's
time splits into staging the call on the committed state, loading the
call's objects, the rest of the runtime's own work, the position-map
witness, the proof bundles of the trace, and the store's commit of the
records the call wrote; the report also times the JSON serialization of the
trace and Lean's check of one call of each kind, and gives the peak
resident memory. The profile was run when Issues 30 to 41 of the external
review were in, so with the stash cap of 152 and with every sealed record
crossing to a storage adapter (see The Storage Boundary in
[`claim-boundary.md`](./claim-boundary.md)).
`review/2026-11-external-review/capacity_sweep_baseline.json` is the same
profile as it was measured before them, and
`scripts/compare_capacity_sweep.py` compares two reports.

Two profiles compare only if one machine in one state measured both, and the
machine's speed changed when it restarted. The baseline and the profile
after it, which was run when Issues 30 to 35 were in, were measured in one
state. The three profiles since, those run when Issues 36 to 38, Issues 39
and 40 and Issue 41 were in, were measured on a machine about a fifth
slower: the code of the profile of Issues 30 to 35, measured again beside
the first of them, takes 47.1 ms for a full-scan read at 16,384 entries, for
which its own profile has 39.9 ms. The full scan, which no issue changed
between them, takes 41.8 ms for that read in the control beside the first
of them, 41.5 ms in the one beside the second and 42.6 ms in the first run
of the one beside this profile. So what an issue saved or cost since is
read off a control and not off two profiles. A control is the full
profile's rounds on the three largest maps at 2 keys, run on the code
before the change and then on the code after it, one run after the other.
The review directory has three: `capacity_sweep_control_before_wave4.json`
and `capacity_sweep_control_after_wave4.json` for Issues 36 to 38,
`capacity_sweep_control_before_cap152.json` and
`capacity_sweep_control_after_cap152.json` for the stash cap of Issue 40,
and `capacity_sweep_control_before_store.json` with three runs after it for
the storage adapter of Issue 41
(`capacity_sweep_control_after_store_memory.json`,
`capacity_sweep_control_after_store_files.json` and
`capacity_sweep_control_after_store_files_synced.json`).

On its own work, the call without the witness, the proof bundles and the
store's commit, the full scan is the faster backend up to 4,096 entries, and
the tree is the faster one for reads from 8,192 entries and for writes at
16,384. A read takes 12.6 ms [11.7, 13.6] on the full scan and 14.4 ms
[14.1, 15.1] on the tree at 4,096 entries, 25.5 ms [24.4, 26.7] and 18.0 ms
[17.6, 18.5] at 8,192, and 49.4 ms [48.5, 51.8] and 22.2 ms [21.9, 23.0] at
16,384. A write on the tree takes 1.3 times as long as one on the full scan
at 8,192 entries (67.5 ms [67.0, 68.6] against 52.9 ms [50.0, 55.0] for an
overwrite) and four fifths as long at 16,384 (79.6 ms [78.7, 80.9] against
100.0 ms [97.7, 102.1]). The medians have this order at every occupancy
level. The intervals of a read and of an overwrite separate at every level
from 8,192 entries on; at 4,096 entries those of a read overlap on maps half
full and nine tenths full. The executed workloads cost what the computed
mixes say, to the byte and the physical operation in every workload, and 39
units of modeled gas more for each write behind the guard, an entrypoint the
mixes do not have. Their mean latencies give the same order where the two
backends separate. At 16,384 entries the tree is the faster backend in 26 of
the 30 combinations of a read fraction and an occupancy level, and in the
other four the intervals overlap: an even mix at 2 keys and at nine tenths
full, and one read in four on maps half full and nine tenths full. On full
maps reads alone take 22.0 ms a call [21.3, 22.7] on the tree against 52.4
ms [50.0, 55.5], an even mix 50.7 ms [38.8, 62.0] against 79.0 ms [66.1,
90.7], and writes alone 82.4 ms [78.7, 86.9] against 107.9 ms [103.6,
112.4]; a mix's calls are of two kinds, so its intervals are wide. At 8,192
entries reads alone are faster on the tree at every level and writes alone
on the full scan, and most mixes between them do not separate. Occupancy
does not move the counts and moves the latencies little: from 4,096 entries
on, a kind's median spreads by 24% at most over the five levels (a full-scan
read that misses at 4,096 entries, 11.0 ms to 13.6 ms), and a tree read at
16,384 entries takes 22.2 ms with 2 keys stored and 21.4 ms on a full map. A
write that aborts does the work of one that commits: 101.1 ms [100.0, 105.8]
on the full scan at 16,384 entries, where an insert takes 101.6 ms [100.5,
103.3].

Whole calls on the tree are slower at every capacity and for every mix
(104.4 ms [101.4, 108.2] against 50.4 ms [49.8, 53.0] for a read at 16,384
entries, and 286.9 ms [281.8, 296.4] against 111.2 ms [109.9, 113.1] for an
insert). What a measured call adds to its own work is the proof bundles of
its trace and the store's commit. The bundles take 78.8 ms of that tree
read, whose trace has 664 storage events, and 201.5 ms of the insert, whose
trace has 2,576. On the full scan they take 0.4 ms, since the trace holds
the scan of the map as one item. The commit appends the records the call
wrote to the store's journal, with the commit metadata, and syncs it. It
takes 0.9 ms of the full-scan read, which wrote no record (309 bytes), and
9.2 ms of the full-scan insert, which wrote every slot (2.1 MB). On the tree
it takes 2.2 ms of the read, which wrote its paths back (174 KB), and 3.1 ms
of the insert (512 KB). Of the full scan's own 49.4 ms, 44.9 ms load the
map, which decrypts every slot; of the tree's 22.2 ms, 0.8 ms load the map,
and the rest is its node accesses. Staging the call takes a microsecond on
either backend, and the tree's witness 0.1 ms to 1.1 ms. Serializing the
trace takes another 0.06 ms for the full-scan read and 4.4 ms for the
tree's, and Lean checks the witness of the call in 117 ms and 130 ms. The
probe's resident memory at 16,384 entries is 122 MB on the full scan and 153
MB on the tree, and a call does not raise it. That run predates Issue 59 of
the review, after which the store alone keeps the sealed records and a
committed map holds none: in the quick profile at 16,384 entries the
resident memory during a tree call fell from 117.9 MB to 92.9 MB, about the
22.0 MB of the map's ciphertext and the allocations that held it. These are
calls of the diagnostics build, which the sweep runs. A production call
builds no proof bundle and keeps no witness. It issues a receipt, and the
receipt's digest of the ciphertext reads every sealed record of a Path ORAM
map that the call wrote, which every call on the map does: the sweep does
not measure that.

The storage adapter costs a call some of its own work, and persistence a
commit. In the adapter's control, the first run is the code before Issue 41
and the others the code after it, with the records in memory, in files, and
in files with every commit synced. With the records in memory a full-scan
read's own work rose from 20.6 ms to 22.0 ms at 8,192 entries and from 42.6
ms to 45.0 ms at 16,384, and an overwrite's from 41.2 ms to 44.7 ms and from
84.8 ms to 92.7 ms: 6% to 9%, for the store's comparison of each record the
call opens and its copy of each record the call seals. A tree overwrite's
rose from 60.6 ms to 65.6 ms and from 71.1 ms to 77.8 ms, and a tree read's
from 16.2 ms to 17.4 ms and from 19.3 ms to 23.1 ms; in the two runs in
files the tree read at 16,384 entries took 20.4 ms and 21.0 ms. The runs
after the change have wider intervals than the run before it, and at 4,096
entries they are too wide to say more than that the medians keep their
order there. At 16,384 entries a commit to files without a sync
takes 0.03 ms for a full-scan read and 5.2 ms for a full-scan overwrite, 0.5
ms for a tree read and 1.0 ms for a tree overwrite; with the sync it takes
0.8 ms, 8.2 ms, 1.5 ms and 2.5 ms. The profile's own work is above the
control's in memory (49.4 ms against 45.0 ms for the full-scan read at
16,384 entries). A call that follows a synced commit may start with colder
caches; the control does not separate that from the profile's larger
state. Where the records are kept changes no count: the control's four runs
have one digest of their counts, and this profile has that of the profile
before it.

The stash cap of 152 costs a tree access about a seventh of its own work.
In its control, with the cap of 114, a tree read took 11.2 ms at 4,096
entries, 14.1 ms at 8,192 and 16.8 ms at 16,384, and with the cap of 152 it
takes 12.7 ms, 16.3 ms and 19.6 ms; an overwrite took 42.7 ms, 52.9 ms and
61.6 ms and takes 48.2 ms, 61.7 ms and 70.8 ms. That is 13% to 17% more,
where the call traces 2% more storage operations at most. A node access
scans its stash for the node it wants, for each bucket of the path it
writes back and for each block of the path it read, and the stash of a map
of 16,384 entries has 210 slots where it had 172. The proof bundles of the
trace grew as much (44.2 ms to 52.3 ms for the read at 16,384 entries, 153.0
ms to 179.8 ms for the overwrite), so a whole measured call did too: 61.3 ms
to 72.0 ms and 214.6 ms to 253.9 ms. The full scan has no stash, and its
calls moved by 3% at most between the two runs. Neither the cap nor the
storage adapter moved a break-even past a capacity that the sweep measures:
by the median of a kind of call, the two backends have one order at every
capacity and occupancy level in the three profiles since Issue 38, with the
cap of 114, with the cap of 152, and with the records in files.

Issues 36 to 38 of the review took out of a call three costs that grew with
the store: the witness snapshots, the copy of the store, and a trace event
for every slot of an exact object. Their control has the stash cap of 114.
In it, at 16,384 entries, a tree read took 551.4 ms as a whole call and
takes 65.4 ms. The witness snapshots, which decoded every bucket and
metadata page of the tree twice, took 469.7 ms of it. The runtime now keeps
the witness, and a measured call copies it into its evidence in 0.3 ms; the
copy grows with the capacity as that evidence does (2.4 MB of JSON for a
tree read at 16,384 entries), and a production call makes none. Staging the
call on a copy of the store took 5.3 ms and loading the map 6.0 ms. They
take a microsecond and 0.7 ms: the call is staged on the committed objects
themselves, takes a reference to each sealed record of the map and copies
the records it writes. Nor does a call wipe and free a copy of the store
when it ends, and the tree read's own work fell from 35.8 ms to 17.4 ms and
a tree write's from 83.5 ms to 62.7 ms. A full-scan read took 220.4 ms as a
whole call and takes 42.0 ms, and a full-scan write 425.7 ms and takes 85.4
ms: the proof bundles of the read's 16,384-event trace took 170.2 ms and
take 0.2 ms, and serializing the trace took 15.4 ms and takes 0.05 ms. The
full scan's own work is the decryption and the sealing of its slots, as it
was (47.1 ms and 41.8 ms for the read, 84.2 ms and 85.1 ms for the write).
The probe's resident memory in the tree's calls fell from 357 MB to 81 MB.

The baseline and the profile between were run on one machine, and they
compare. At 16,384 entries a full-scan read took 72.2 ms of its own work
and 354.8 ms as a whole call in the baseline, and 39.9 ms and 182.8 ms when
Issues 30 to 35 were in: it no longer rewrote the map, and a call opened
each slot of an exact object once, when it loads the object. A full-scan
write that aborts took 106.3 ms, since it decoded every slot again to
restore the map, and then took what a committed one does, which had not
moved (72.5 ms, then 73.7 ms). A tree read took 48.7 ms and a tree write
84.4 ms, and then 33.0 ms and 71.8 ms: a sealed record has half the bytes
it had, so copying the state fell from 10.6 ms to 4.7 ms and loading the
map from 12.5 ms to 6.0 ms. The shorter record did not make the full scan
faster: its load is the decryption of 16,384 records, 32.5 ms and then 33.5
ms. In the baseline a tree read was the faster one from 4,096 entries and a
tree write the slower one at every capacity. The full scan's saving on
reads moved the first break-even up to 16,384 entries, and the tree's
saving brought its write level with the full scan's there. Issues 36 and 37
then took the copy of the state and most of the load of the map off the
tree, and the break-evens are where this profile has them: between 4,096
and 8,192 entries for reads, and between 8,192 and 16,384 for writes. The
tree's advantage in bytes and physical operations is as it was; in gas, the
stash cap of 152 moved its break-even for reads alone from 1,024 entries to
2,048 under cost model v2, and cost model v3, which counts each read once
(Issue 57), puts it at 1,024 again.

The sweep also found a defect, which is fixed. An aborting call opened every
slot of an exact map again to restore it, and the allocator's budget of
resource events did not count that: above about 4,600 entries such a call
failed where it should have aborted. The budget now counts a call's load
operations beside its commit operations, two events for each
(`RESOURCE_EVENTS_PER_LOAD_OP` and `RESOURCE_EVENTS_PER_COMMIT_OP` in
`runtime/uo-allocator/src/lib.rs`, `resourceEventCapacity` in
`UOToolchain/RuntimeAllocatorDiscipline.lean`), and a call opens each slot
once: an aborting call restores the map from the copy it loaded.

A node access evicts the stash
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
their nodes until they end is assumed (`stashOverflowBounded`) and measured
over ten million node accesses, not proved. A write
whose key the program does not show equal to a preceding get's (another key
expression, a key read from storage, or a key variable bound again in
between) still makes its own presence get, and the tree costs more than a
flat position map below a few thousand entries.
The instrumented runtime keeps the position-map witnesses its checks
consume and compares them with a decode of every bucket of a tree before
and after each call, so an audited call takes time linear in the capacity
even where the ORAM's own work is logarithmic; a measured call and a
production call do not pay for the audit, and a production call exports no
witness.

A call no longer copies the store either (Issue 37 of the review). It is
staged on the committed objects themselves, which are held by reference.
The copy of a Path ORAM map that it loads holds none of the map's sealed
records, which the store alone keeps (Issue 59): it reads the counter and
the metadata pages from the store when it loads the map, and the buckets of
a path when it accesses it, and holds those until it seals their next
versions over them. A call that is dropped leaves the store as it was. An
object keeps the digest of its sealed records, which it reads from the
store, so the ciphertext digest of a production receipt reads the objects
the call wrote and no other. The digest of a map the call wrote reads the
whole map; a tree of digests over its buckets is future work (Issue 44).

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
| `stashOverflowBounded` | JACM Path ORAM stash theorem specialized to deployed `Z = 5` / `stash_bound = min(max(capacity, 1), 152)` parameters: a stash overflows after an access with probability at most `14 · 0.6002^152 < 2^-108`, so with probability at most `2^-60` over the `2^48` node accesses budgeted for a map's lifetime, and a map of capacity at most 152 cannot overflow. That the private scheme's operations, which hold their nodes until they end, keep this tail above the `3h + 1` nodes they return is assumed and measured (`results/stash_occupancy_full.json`), not proved |
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
