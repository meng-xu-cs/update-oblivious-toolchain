# External Review, November 2026

An external consultant reviewed the repository at commit `030ae9e`. This
directory holds the response.

| File | Content |
| --- | --- |
| [`validation.md`](./validation.md) | every factual claim of the review checked against the code, and a position on each recommendation |
| [`tasks.md`](./tasks.md) | Issues 22 to 59: description, fix and acceptance criteria |
| [`capacity_sweep_baseline.json`](./capacity_sweep_baseline.json) | the capacity sweep's full profile as Issue 27 measured it, before any optimization: what Issues 30 to 38 compare their savings with |
| [`capacity_sweep_control_before_wave4.json`](./capacity_sweep_control_before_wave4.json), [`capacity_sweep_control_after_wave4.json`](./capacity_sweep_control_after_wave4.json) | a control for Issues 36 to 38: the full profile's rounds on the maps of 4,096, 8,192 and 16,384 entries at 2 keys, on the code before those issues (`cb92f8c`) and on the code after them (`9d93471`), one run after the other on one machine |
| [`capacity_sweep_control_before_cap152.json`](./capacity_sweep_control_before_cap152.json), [`capacity_sweep_control_after_cap152.json`](./capacity_sweep_control_after_cap152.json) | the same control for the stash cap of Issue 40: on the code before it (`ece1167`, a cap of 114) and on the code after it (`305c1a2`, a cap of 152) |
| [`capacity_sweep_control_before_store.json`](./capacity_sweep_control_before_store.json), [`capacity_sweep_control_after_store_memory.json`](./capacity_sweep_control_after_store_memory.json), [`capacity_sweep_control_after_store_files.json`](./capacity_sweep_control_after_store_files.json), [`capacity_sweep_control_after_store_files_synced.json`](./capacity_sweep_control_after_store_files_synced.json) | the same control for the storage adapter of Issue 41: on the code before it (`b6b9fce`), and on the code after it with the maps' records in memory, in files, and in files with every commit synced |
| [`capacity_sweep_control_before_eviction_networks.json`](./capacity_sweep_control_before_eviction_networks.json), [`capacity_sweep_control_after_eviction_networks.json`](./capacity_sweep_control_after_eviction_networks.json) | the same control for the eviction networks of Issue 47: on the code before them (`990b054`) and on the code after them (`ba0b958`, before rustfmt changed the layout of three of its statements) |
| this file | the positions in brief, the order of work, and the tracker |

The review text is not in the repository; `validation.md` restates each
claim.

A later review, of 16 November 2026, kept most of this response. It
reopened guarantees of Issues 41, 49, 52, 53 and 58 and qualified Issue 36.
Issues 60 to 69 (`8f30524` to `185e205`) repaired them, and the topic
documents hold what they built. A note at the end of each issue in
`tasks.md` says what was reopened and which commit repaired it. The rows
below keep `done` for the work those issues built. A review of 18 November
2026 closed those repairs within their stated scope and asked for two more,
with no tracker: Issue 70 (`bb4fa10`) publishes a file store before it is
served and syncs a new one, and Issue 71 states zero nonce reuse over one
history of the store.

## Using the Tracker

- Work an issue as `tasks.md` describes it, to the definition of done of
  [`review/runbook.md`](../runbook.md).
- Title the commit `Issue NN: …`. In the same commit, set the issue's row
  below to `done`. A commit cannot name itself, so the next commit that
  touches the tracker fills in its hash.
- Statuses: `todo`, `blocked` (on a decision of Issue 22), `in progress`,
  `done`, `deferred`.
- A finished issue's durable facts go to the topic document that owns them.
  When every scheduled issue is done, fold what remains into the topic
  documents and delete this directory, as
  [`docs/README.md`](../../docs/README.md) asks of trackers.

## Baseline

At `030ae9e`, with Rust 1.82.0 and Lean 4.30.0-rc2: the workspace builds,
`cargo test --workspace` passes 404 tests, `lake build
UOToolchain.ProofGradeRoot` builds, and CI's probe steps regenerate
`results/` unchanged. Not run: the all-features tests, clippy, the full
validation and the capacity sweep.

The research issues (43 to 46) start from Issue 71's commit, the last
repair of the review of 18 November 2026. The measured baseline is still
`88d3338`, the last repair of the review of 16 November 2026: on its
runtime, Issue 69 of that review measured the capacity sweep's full profile,
with every commit synced, and the matched baselines' full profile
(`results/capacity_sweep_full.json` and `results/matched_baselines_full.json`;
see [`docs/evaluation.md`](../../docs/evaluation.md) and
[`docs/path-oram.md`](../../docs/path-oram.md)). Issues 70 and 71 change no
count and no measured call: Issue 70 changes how a store is opened and
created, and in a diagnostics build a sync also asks whether a crash model
watches the files; Issue 71 changes claims and adds a Lean theorem. The
baseline does not measure what a production call adds, the receipt's digest of every sealed
record of a Path ORAM map the call wrote (Issue 44 would make the transition
certified incrementally), nor an enclave's memory: the backend planner
charges each backend the memory its model gives, and the sweep reports the
probe process's resident memory in the diagnostics build.

## Positions

| The review recommends | Position | Issues |
| --- | --- | --- |
| Separate secret randomness and private witnesses from public evidence (§3) | Agree; first. The flaw is demonstrated: one rejected production call returns the seed, and every storage key derives from it | 23 to 26 |
| Incremental transaction state (§4) | Agree; engineering, needs no new theorem | 36 to 38 |
| Incremental verification with certified transitions (§4) | Agree, as research after the engineering | 44 |
| A checked optimizer for storage effects and schedules (§5) | Agree for read-only objects and one load per call; the cost model must charge reads first. Scan fusion later | 30 to 32, 48 |
| Conformance of the runtime primitives (§6) | Agree. Branch-free arithmetic, checked write classes and wider tests now; proofs as research | 33, 34, 42; 43, 46 |
| A Solidity 0.8 semantics bridge (§6) | Deferred: it changes no current claim | 50 |
| Stateful, quantitative security (§7) | Agree. Assumption wording, encrypted returns and a stash budget now; the history theorem as research | 29, 39, 40; 45 |
| A denser record codec by seven-bit packing (§8) | Agree in part. The codec is wasteful, but the best encoding depends on the observer unit, and seven-bit packing is best only for the byte | 22, 35 |
| An oblivious routing network for eviction (§8) | Agree as an experiment, later | 47 |
| Evaluate at a storage boundary with every cost counted (§9) | Agree. The measurement work moves ahead of the optimizations | 27, 28, 41 |
| Matched baselines and a backend planner (§9); the novelty boundary (§10) | Agree; mostly work for the paper | 49 |

## Decisions

Issue 22 has the options and the reasoning for D1 to D3, Issue 48 for D4,
and Issue 49 for D5 to D7.

| Decision | Status | Outcome |
| --- | --- | --- |
| D1, the unit the storage observer classifies | decided 2026-11-12 | the 32-byte word, as an EVM `SSTORE` classifies it; the unit size stays a parameter of the codec's Lean statement |
| D2, where private evidence may go | decided 2026-11-12 | position maps and leaf schedules do not leave the runtime: a production build exports no private evidence, and only the diagnostics build exports it, to the Lean checkers |
| D3, the lifetime budget of the stash bound | decided 2026-11-12 | a cap of 152: at most `2^-60` over `2^48` node accesses of a map |
| D4, what Issue 48 builds | decided 2026-11-15 | fact reuse alone: a lookup reuses what an earlier lookup of its key found; a read and an update of one key are not fused into one access |
| D5, the baselines of Issue 49 | decided 2026-11-15 | the repository's own backends, the full scan and both Path ORAM schemes, compared at the same key and value widths, capacities and occupancy, with the enclave memory each holds; no external system is run |
| D6, where the backend planner runs | decided 2026-11-15 | in the compiler: a confidential map whose metadata says `backend: auto` gets the backend the planner chooses from public parameters, and the manifest records the plan, which `uo-check` makes again |
| D7, what the planner minimizes | decided 2026-11-15 | the bytes of sealed records a call moves, at the share of reads the map declares (half if it declares none), among the backends whose enclave memory fits the map's budget |

## Order of Work

1. **Wave 0, decisions** (Issue 22). Done: the maintainer decided the
   observer unit, the evidence boundary and the stash budget.
2. **Wave 1, the confidentiality boundary** (Issues 23 to 26). A runtime
   that discloses its master secret undermines every other claim.
3. **Wave 2, measurement and claim wording** (Issues 27 to 29). Later
   savings need a fair baseline, and the wording fix costs nothing.
4. **Wave 3, structural savings and primitive hardening** (Issues 30 to
   35). Small changes whose savings follow from the schedule, each with a
   mechanical acceptance test. Done; the full profile of the sweep was run
   again after it (`results/capacity_sweep_full.json`), and
   `docs/path-oram.md` has its figures beside the baseline's.
5. **Wave 4, no work linear in the store** (Issues 36 to 38). Done; the
   full profile was run again after it, and `docs/path-oram.md` has its
   figures and break-evens. The machine was slower than for the earlier
   profiles, so what the wave saved is measured by a control, the code
   before the wave and the code after it run one after the other.
6. **Wave 5, theorem coverage** (Issues 39 and 40). Done; the full profile
   was run again with the stash cap of 152, and a control measures what the
   cap costs a tree access: 13% to 17% of its own work.
7. **Wave 6, evidence at a storage boundary** (Issues 41 and 42). Done:
   the storage adapter's log agrees with the traces' writes and with their
   reads of exact objects, and shows that a trace names a Path ORAM map's
   counter and metadata pages more often than they are read (Issue 57);
   the tape substitution is tested over 1,344 tapes and the AVL map on
   trees of up to 2,048 nodes, with no divergence.

8. **Wave 7, the backlog of Issues 51 to 59**, which the maintainer
   scheduled on 2026-11-14, in this order: 56, 51, 52, 54, 55, 53, 59, 58,
   57. Issue 56 comes first because the others change pinned sources, and
   the lexer lets a check write its needles whole. Issues 51 and 52 change
   how a seal is made and counted, before Issue 59 moves the records into
   the store. Issue 53 comes before Issue 58, which needs it, and Issue 59
   before Issue 58, so that a restart seals nothing. Issue 57 comes last:
   it changes every Path ORAM count, so the full profile of the capacity
   sweep runs once after it, and measures Issue 59's memory too.
   Done; the full profile was run after Issue 57, with the quick profile's
   counts: at 16,384 entries the probe's resident memory in the tree's
   calls is 115 MB to 118 MB, where it was 153 MB to 172 MB. No control was
   run, so the wave's latencies are not set against the profile before it.
9. **Wave 8, the backlog of Issues 47 to 49**, which the maintainer
   scheduled on 2026-11-15, in this order: 47, 48, 49. Issue 49's baselines
   and planner rest on what the sweep measures, so they come after the two
   issues that change it. Issue 47 is done: a node access evicts through
   fixed networks, with every block where it was, and in a control a tree
   call's own work is 2.1 to 2.4 times faster. Issue 48 is done: a lookup
   of a Path ORAM map reuses what an earlier lookup of its key found, and
   Lean proves that which lookups do is a function of the program; no
   benchmark's counts move. Issue 49 is done: the claim boundary names the
   related work, a map may leave its backend to a planner in the compiler,
   which takes the one that moves the fewest bytes, and the matched
   baselines check the planner's model against every call they make.

The research issues (43 to 46) start from the repaired baseline (see
Baseline). Issue 50 is deferred, and the folding of this directory into the
topic documents (see Using the Tracker) waits for the maintainer.

This differs from the review's sequence in two ways. The measurement work
comes before the optimizations, not after. And incremental state is split:
its engineering part is Wave 4, its certified part is research.

## Tracker

| Issue | Title | Wave | Size | Depends on | Status | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 22 | Decide the observer unit, the evidence boundary and the stash budget | 0 | S | maintainer | done | `58bce68` |
| 23 | Stop returning the deployment seed to callers | 1 | S | | done | `72d3bfb` |
| 24 | Give the runtime an independent 256-bit master secret | 1 | M | 23 | done | `6b88d18` |
| 25 | Split a call's result into a public receipt and private evidence | 1 | M to L | 24 | done | `5a5e3b4` |
| 26 | Have the runtime issue the proof binding | 1 | M | 25 | done | `e232687` |
| 27 | Measure occupancy, executed workloads and every cost | 2 | M | | done | `35f4c4e` |
| 28 | Cover the private scheme in the leakage and abort reports | 2 | S | | done | `348da16` |
| 29 | State what the Path ORAM theorem's cryptographic assumptions mean | 2 | S | | done | `9631ed0` |
| 30 | Charge external reads in the modeled cost | 3 | S to M | | done | `3d8b5f6` |
| 31 | Do not rewrite statically read-only exact objects | 3 | M | 30 | done | `1afbb01` |
| 32 | Load each exact object once per call | 3 | M | 30 | done | `551a528` |
| 33 | Check each UO write's class against its bytes | 3 | S | | done | `a3eb01a` |
| 34 | Make the confidential kernel's 256-bit arithmetic branch-free | 3 | M | | done | `35e4bb8` |
| 35 | Match the record codec to the observer unit | 3 | M | | done | `d848180` |
| 36 | Remove the whole-store witness snapshots from a call | 4 | M | 25 | done | `af5cf09` |
| 37 | Stage a call without copying the store | 4 | M | | done | `02087ca` |
| 38 | Compress scan schedules in traces and proof objects | 4 | M to L | 31, 32 | done | `9d93471` |
| 39 | Admit encrypted returns in the kernel theorems | 5 | M | | done | `ece1167` |
| 40 | Give the stash bound a lifetime budget and test deferred write-back | 5 | M | | done | `305c1a2` |
| 41 | Put storage behind an adapter that keeps its own I/O log | 6 | M to L | 24, 31, 32 | done | `6aecff2` |
| 42 | Widen the runtime-versus-model tests of the tree and the tape substitution | 6 | M | | done | `36d474d` |
| 43 | Prove a store operation's post-state and its write class together | research | R | 33, 35 | todo | |
| 44 | Certify state transitions incrementally | research | R | 36, 37, 41 | todo | |
| 45 | State security over call histories with a quantified bound | research | R | 24, 39, 40 | todo | |
| 46 | Prove that the runtime's run on every tape is the substituted run | research | R | 42 | todo | |
| 47 | Try an oblivious routing network for tree eviction | 8 | M | 27 | done | `ba0b958` |
| 48 | Fuse scans and generalize the reuse analysis | 8 | M | 31, 32 | done | `5dc9380` |
| 49 | Write the related-work boundary and add matched baselines | 8 | M | 27 | done | `c5422f9` |
| 50 | Bridge a scoped subset to Solidity 0.8 semantics | backlog | L | | deferred | |
| 51 | Remove the generator that a seal no longer reads | 7 | S to M | 24 | done | `48915bb` |
| 52 | Make the seal count of a dropped call a function of its entrypoint | 7 | M | 24 | done | `b68dfbc` |
| 53 | Authenticate production receipts under an attested key | 7 | M | 26 | done | `83508d7` |
| 54 | Compare a runtime trace with the exact encoding in Lean | 7 | M | 38 | done | `08834f2` |
| 55 | Take the public-state snapshot once for each object a call changes | 7 | M | 37 | done | `c787993` |
| 56 | Slice production sources with a lexer | 7 | S to M | | done | `325184f` |
| 57 | Trace the reads of a Path ORAM map that cross the storage boundary | 7 | L | 41 | done | `266d9ce` |
| 58 | Seal the master secret so that a production deployment can restart | 7 | M | 41, 53 | done | `8838bc8` |
| 59 | Keep sealed records in the store alone | 7 | L | 41 | done | `26fe8af` |

Sizes are relative, not a schedule: S a day or less, M several days, L one
to two weeks, R research with no fixed end.
