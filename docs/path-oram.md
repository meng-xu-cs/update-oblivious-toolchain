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
get and then a put of `3h + 1` node accesses, costs about four times a read:
260 against 980 physical operations at 256 entries, 654 against 2,556 at
16,384. The tree moves fewer bytes than the full scan from 4,096 entries for
reads alone and from 8,192 for an even mix and for writes alone; it makes
fewer physical operations from 512 entries for reads alone and for an even
mix and from 1,024 for writes alone; and it costs less modeled gas from
1,024, 2,048 and 4,096. The gas is that of cost model v2, which charges the
sealed records a call reads, those at its start included, as it charges
those it writes (see The Modeled Cost in
[`claim-boundary.md`](./claim-boundary.md)). The local scheme makes fewer
operations than the full scan from 32 entries for reads alone, 16 for an
even mix and 8 for writes alone, and costs less gas from 128, 32 and 16, but
moves more bytes at every capacity it admits, and up to its 128 entries it
costs less than the tree on every metric.

Beside the traced counts the report gives the work that no trace records. A
call on a Path ORAM map reads the map's counter and metadata pages when it
starts: 24 reads of 22,880 bytes on the tree at 16,384 entries. An
instrumented call exports the position maps before and after it as a
witness. It once decoded them from storage, every bucket and metadata page
of the tree twice: 65,580 sealed records at 16,384 entries, where a read
traces 654 operations. The runtime now keeps the witness from call to call
and a call moves it by its own leaf transitions, so a measured call opens no
record for it (`witness_scan_records` is 0 in every row). The decode
happens once after each bulk load (`witness_decode_records` of a fill:
32,790 records at 16,384 entries) and in the audit, which compares the kept
witness with that decode. The sweep audits after every occupancy level and
not in the calls it times; every other instrumented call audits before it
runs and after. A production call records no witness at all. The report also gives
the size of what a call exports: at 16,384 entries the trace of a full-scan
read is 9.2 KB of JSON, where that of a map of two entries is 9.1 KB, and
that of a tree read 2.7 MB, 2.4 MB of it private evidence. A trace holds
the scan of an exact object, its rewrite and the logical scan of a map as
one item each, with the slot count and the length of a sealed slot, so the
trace of a call on a full-scan map does not grow with the map.

The latencies are wall-clock times of a release build on one machine. The
validation script runs a quick profile of the sweep, whose latencies are a
smoke test: one warmup round and two measured rounds, workloads of five
calls, and maps above 256 entries left at 2 keys. The figures below come
from the full profile (`scripts/run_capacity_sweep_full.sh`,
`results/capacity_sweep_full.json`): 30 measured rounds of every kind of
call after 5 warmup rounds, at every occupancy level of every map, and a
workload of 20 calls at each read fraction. Each figure is a median with its
95% bootstrap interval. A call's time splits into staging the call on the
committed state, loading the call's objects, the rest of the runtime's own
work, the position-map witness, and the proof bundles of the trace; the
report also times the JSON serialization of the trace and Lean's check of
one call of each kind, and gives the peak resident memory. The profile was
run when Issues 30 to 38 of the external review were in.
`review/2026-11-external-review/capacity_sweep_baseline.json` is the same
profile as it was measured before them, and
`scripts/compare_capacity_sweep.py` compares two reports.

Two profiles compare only if the machine was the same, and it was not. When
this profile was run the machine was about a fifth slower than it was for
the baseline and for the profile between the two, which was run when Issues
30 to 35 were in: the code of that profile, measured again beside this one,
takes 47.1 ms for a full-scan read at 16,384 entries, for which its own
profile has 39.9 ms. So what Issues 36 to 38 saved is read off a control
and not off the earlier profile. The control is the full profile's rounds
on the three largest maps at 2 keys, run on the code before those issues
and then on the code after them, one run after the other
(`capacity_sweep_control_before_wave4.json` and
`capacity_sweep_control_after_wave4.json` in the review directory).

On its own work, the call without the witness and the proof bundles, the
full scan is the faster backend up to 4,096 entries, and the tree is the
faster one for reads from 8,192 entries and for writes at 16,384. A read
takes 10.7 ms [10.3, 11.0] on the full scan and 12.1 ms [11.2, 13.3] on the
tree at 4,096 entries, 20.8 ms [20.5, 24.7] and 15.1 ms [14.5, 17.0] at
8,192, and 45.0 ms [43.5, 47.9] and 17.5 ms [17.2, 18.6] at 16,384. A write
on the tree takes 1.4 times as long as one on the full scan at 8,192
entries (58.5 ms [55.9, 59.5] against 41.5 ms [40.5, 44.2] for an
overwrite) and four fifths as long at 16,384 (67.4 ms [66.2, 75.5] against
86.9 ms [85.0, 92.4]). The medians have this order at every occupancy
level. The executed workloads cost what the computed mixes say, to the byte
and the physical operation in every workload, and 39 units of modeled gas
more for each write behind the guard, an entrypoint the mixes do not have.
Their mean latencies give the same order where the two backends separate.
At 16,384 entries the tree is the faster backend in 24 of the 30
combinations of a read fraction and an occupancy level, and in the other
six the intervals overlap: writes alone and one read in four on maps a
quarter full and half full, and an even mix and three reads in four on
half-full maps. On full maps reads alone take 18.6 ms a call [17.7, 19.6]
on the tree against 40.8 ms [39.6, 42.1], an even mix 44.5 ms [32.7, 57.1]
against 75.4 ms [64.5, 86.0], and writes alone 74.2 ms [69.8, 78.7] against
84.3 ms [81.3, 87.1]; a mix's calls are of two kinds, so its intervals are
wide. On half-full maps writes alone take 87.9 ms [82.6, 93.0] against 86.2
ms [85.7, 86.9]. At 8,192 entries reads alone are faster on the tree at
every level and writes alone on the full scan, and most mixes between them
do not separate. Occupancy does not move the counts and moves the latencies
little: from 4,096 entries on, a kind's median spreads by 25% at most over
the five levels, and a tree read at 16,384 entries takes 17.5 ms with 2
keys stored and 19.6 ms on a full map. A write that aborts does the work of
one that commits: 87.9 ms [86.3, 97.4] on the full scan at 16,384 entries.

Whole calls on the tree are slower at every capacity and for every mix
(82.3 ms [78.5, 85.5] against 45.4 ms [43.9, 48.3] for a read at 16,384
entries, and 259.9 ms [243.9, 276.9] against 88.2 ms [87.0, 99.4] for an
insert). What a measured call adds to its own work is the proof bundles of
its trace. They take 63.3 ms of that tree read, whose trace has 654 storage
events, and 184.6 ms of the insert, whose trace has 2,556. On the full scan
they take 0.4 ms, since the trace holds the scan of the map as one item. Of
the full scan's own 45.0 ms, 40.8 ms load the map, which decrypts every
slot; of the tree's 17.5 ms, 0.8 ms load the map, and the rest is its node
accesses. Staging the call takes a microsecond on either backend, and the
tree's witness 0.1 ms. Serializing the trace takes another 0.1 ms for the
full-scan read and 3.5 ms for the tree's, and Lean checks the witness of
the call in 69 ms and 89 ms. The probe's resident memory at 16,384 entries
is 78 MB on the full scan and 99 MB on the tree, and a call does not raise
it. These are calls of the diagnostics build, which the sweep runs. A
production call builds no proof bundle and keeps no witness. It issues a
receipt, and the receipt's digest of the ciphertext reads every sealed
record of a Path ORAM map that the call wrote, which every call on the map
does: the sweep does not measure that.

Issues 36 to 38 of the review took out of a call three costs that grew
with the store: the witness snapshots, the copy of the store, and a trace
event for every slot of an exact object. In the control, at 16,384 entries,
a tree read took 551.4 ms as a whole call and takes 65.4 ms. The witness
snapshots, which decoded every bucket and metadata page of the tree twice,
took 469.7 ms of it. The runtime now keeps the witness, and a measured call
copies it into its evidence in 0.3 ms; the copy grows with the capacity as
that evidence does (2.4 MB of JSON for a tree read at 16,384 entries), and
a production call makes none. Staging the call on a copy of the store took
5.3 ms and loading the map 6.0 ms. They take a microsecond and 0.7 ms: the
call is staged on the committed objects themselves, takes a reference to
each sealed record of the map and copies the records it writes. Nor does a
call wipe and free a copy of the store when it ends, and the tree read's
own work fell from 35.8 ms to 17.4 ms and a tree write's from 83.5 ms to
62.7 ms. A full-scan read took 220.4 ms as a whole call and takes 42.0 ms,
and a full-scan write 425.7 ms and takes 85.4 ms: the proof
bundles of the read's 16,384-event trace took 170.2 ms and take 0.2 ms, and
serializing the trace took 15.4 ms and takes 0.05 ms. The full scan's own
work is the decryption and the sealing of its slots, as it was (47.1 ms and
41.8 ms for the read, 84.2 ms and 85.1 ms for the write). The probe's
resident memory in the tree's calls fell from 357 MB to 81 MB.

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
tree's advantage in bytes, physical operations and gas is as it was.

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
their nodes until they end is assumed (`stashOverflowBounded`). A write
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
staged on the committed objects themselves, which are held by reference,
and the copy of a Path ORAM map that it loads shares the map's sealed
records: a write copies the record it replaces, and the others stay the
committed map's. An object keeps the digest of its sealed records, so the
ciphertext digest of a production receipt reads the objects the call wrote
and no other. What a call on the tree still does in the size of the map is
small: it takes a reference to each record when it loads the map and drops
one when it commits. The digest of a map the call wrote reads the whole
map; a tree of digests over its buckets is future work (Issue 44).

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
