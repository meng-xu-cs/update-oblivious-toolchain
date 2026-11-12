# Validation of the November 2026 External Review

An external consultant reviewed this repository at commit `030ae9e` and
recommended seven directions. This document checks the review's factual claims
against the code, the Lean development and the committed results, and states a
position on each recommendation. The tasks that follow are in
[`tasks.md`](./tasks.md); their order and status are in
[`README.md`](./README.md).

The review text is not in this repository. Every claim is restated here, so
this document can be read without it. Numbers such as "§3" are the review's
section numbers.

## Method

All file and line references are to commit `030ae9e`. A path is given in
full where a file is first cited in a finding. After that, `engine.rs`,
`deployment.rs`, `theorem.rs`, `state.rs`, `objects.rs`, `oram.rs`,
`freshness.rs`, `generated_oram_codecs.rs` and `generated_object_helpers.rs`
are under `runtime/uo-evm/src/`; `trace.rs` and `types.rs` are under
`crates/uo-core/src/`; a bare `lib.rs` is `probe/mplus-probe/src/lib.rs`; and
Lean files are under `proof/lean/`, the `Check*` executables directly and
the rest in `UOToolchain/`.

What was run, with the pinned toolchains (Rust 1.82.0, Lean 4.30.0-rc2):

| Check | Result |
| --- | --- |
| `cargo build --workspace --all-targets` | builds |
| `cargo test --workspace` | 404 tests pass, none fail |
| `cargo test -p uo-evm --lib` (no `diagnostics` feature) | 114 tests pass, four of them absent from the workspace run (F1) |
| `lake build UOToolchain.ProofGradeRoot` | 108 jobs, no error |
| CI's probe steps: static checks, Lean assumption budget, correctness (4 trials), abort rollback, AVL map replay, acceptance, claim consistency, claim status | `results/` regenerates with no difference |
| Size and SHA-256 of the 88 files in `results/reproducibility_manifest.json` | all match |
| Default build, `uo-evm --format trace` on `FixedSlotClassifier.peek()` | the output contains `runtime_seed` (F1) |
| A throwaway integration test on `ProductionContractInstance::deploy` | the error of one rejected call contains the deployment seed (F1) |
| Diagnostics build, `--format confidential-proof-family` with two seeds | two different bundles for the same call (F1) |

Not run: `cargo test --workspace --all-features`, clippy, the full
`scripts/run_validation.sh`, and the capacity sweep. The review's latency
figures were compared with the committed `results/capacity_sweep.json`; they
were not measured again.

Each finding says how it was checked: **run** (executed here), **source**
(read at the cited lines), **results** (a committed result file), or **docs**
(the repository's documents already say so).

## Summary

| Finding | Review | Verdict | Position |
| --- | --- | --- | --- |
| F1. One 64-bit value is the root of every runtime secret and is also public | §3 | confirmed, and worse than stated | agree; do first |
| F2. The evaluation figures and their caveats | §2 | confirmed, every figure exact | agree |
| F3. Every call does work linear in the whole store | §4 | confirmed | agree; engineering first, certified state as research |
| F4. Read-only exact objects are rewritten; scan events are modeled | §5 | confirmed | agree; the cost model must change with it |
| F5. Runtime primitives: branching arithmetic, asserted write classes, tested-not-proved ORAM | §6 | confirmed | agree; cheap fixes now, proofs as research |
| F6. History, cryptographic and stash statements stop short of the runtime | §7 | confirmed | agree |
| F7. The record codec doubles every sealed byte | §8 | arithmetic confirmed; the proposed encoding is not the best choice | agree in part |
| F8. The evaluation covers little occupancy, few trials and no real storage | §9 | confirmed | agree; move the measurement work earlier |
| F9. Prior art limits the novelty claim | §10 | the cited works exist | agree; mostly work for the paper |

The review's account of what the repository already establishes (§1) is
accurate: the private scheme is an oblivious AVL map that admits several
accesses per entrypoint (`supports_multi_access_per_entrypoint`,
`crates/uo-core/src/manifest.rs:412`); the exact-backend theorem's premises are
discharged for admitted kernel programs
(`paperMain_admittedKernelRun_exact_noninterference_moduloReleases`); the leaf
schedule is proved uniform without seed enumeration
(`observedLeaves_canonical`); the AVL map is proved over inductive trees
(`get_spec`, `put_spec`); and the assumption budget reports two legacy axioms
outside the proof root and no `sorry` (regenerated here, identical). That the
Rust runtime follows these models is tested and source-frozen, not proved, as
`docs/claim-boundary.md` says.

## F1. The deployment seed is the root of every secret and is public

Review §3: the production deployment path seeds secret generation from the
64-bit freshness epoch that deployment evidence carries, and the returned
`ExecutionTrace` holds the seed and the hidden ORAM witnesses. The review adds
that it did not demonstrate an attack.

Confirmed (**run**, **source**), with more than the review found.

1. `ContractInstance::deploy` draws one `u64` from the OS and uses it as the
   freshness epoch and as the deployment seed
   (`runtime/uo-evm/src/engine.rs:170-196`).
   `ProductionContractInstance::deploy` calls it (`engine.rs:88-95`).
2. Every secret derives from that `u64`. Each object's seed is
   `derive_runtime_object_seed(deploy_seed, id, name)`
   (`runtime/uo-evm/src/state.rs:489`, `freshness.rs:127`). A
   `ChaCha20Rng::seed_from_u64` of it produces the object's 32-byte
   `ChaCha20Poly1305` key, its nonce stream and its initial ORAM placement
   (`objects.rs:466-473`, `StoreCipher::from_rng` in
   `runtime/uo-store/src/generated_surface.rs`), and the Path ORAM leaf-coin
   seed (`objects.rs:576`, `freshness.rs:136-169`). So a storage key has at
   most 64 bits of entropy, and one value fixes every key, nonce and leaf.
3. The same value reaches the caller three ways.
   - `ProductionCallEvidence.freshness_epoch` must equal it
     (`deployment.rs:35`, `:170`), so whoever prepares evidence knows it.
   - A mismatch prints it (`deployment.rs:171-175`). With a deployment made by
     `ProductionContractInstance::deploy` and evidence built from public
     values with epoch 0, `call_authorized` returned
     `production runtime freshness_epoch mismatch: evidence 0, runtime 12486089203819543119`.
     One rejected call gives the host the seed.
   - Every trace carries it as `runtime_seed` (`theorem.rs:165`,
     `crates/uo-core/src/trace.rs:6661`). `ExecutionTrace` derives
     `Serialize`, `CallResult.trace` is public (`engine.rs:35-40`), and the
     default CLI prints it.
4. The trace also carries the hidden Path ORAM witnesses: the position maps
   before and after the call, the leaf schedule, the access counters and the
   leaf transitions (`trace.rs:6675-6687`).
5. The repository's own field classification calls `runtime_seed`, the access
   counters and the position maps `CryptographicallyHidden`; the seed is
   "not host-observable data"
   (`crates/uo-core/src/observer_coverage.rs:409-450`). Items 3 and 4
   contradict it.
6. The production protocol needs the seed outside the runtime. The caller
   must supply `proof_bundle_sha256`, the hash of the bundle the call will
   produce (`validate_production_proof_bundle`), and that bundle embeds
   `runtime_seed`: two seeds give two hashes for the same `peek()` call. The
   test `production_runtime_requires_attested_proof_bundle_session_and_freshness`
   computes it from a second instance deployed with the same seed
   (`engine.rs:977-1005`). No public API returns the epoch of a deployment
   made with `ProductionContractInstance::deploy`, so such a deployment can
   accept a call only after the caller learns the seed.
7. Nonces can repeat after a dropped call (**source**). An object's nonces
   come from a `ChaCha20Rng` that is cloned with the object for staging
   (`objects.rs:61-70`, `:90-100`). A staged call that is dropped leaves the
   committed stream where it was, so the next call draws the same nonces for
   plaintexts that may differ. Staged ciphertexts do not leave the process
   today, so a host sees no reuse. It becomes a key and nonce reuse once
   staged writes reach real storage before the commit decision, or once
   state is restored from a snapshot. The nonces are also 96 pseudo-random
   bits (`seal_and_wipe_into_slice`,
   `runtime/uo-store/src/generated_surface.rs`), which collide under one key
   with probability about `q²/2^97` after `q` seals: `2^-33` at `2^32`
   seals, `2^-17` at `2^40`.
8. CI does not run the production call path (**run**). `mplus-probe` depends
   on `uo-evm` with the `diagnostics` feature, so `cargo test --workspace`
   builds `uo-evm` with it. The four tests of `call_authorized` are compiled
   only without that feature, so they drop out: the workspace run has 113
   `uo-evm` tests without them, and `cargo test -p uo-evm` has 114 with them.
   CI, `scripts/baseline.sh` and `scripts/run_validation.sh` all use the
   workspace form.

Position: agree, and this comes first. The fix is the review's three-way
split (secret runtime state, private verification evidence, public receipts)
with an independent 256-bit master secret. Items 6 to 8 add three requirements
the review does not state: the runtime must issue the proof-bundle binding
instead of receiving it, nonces must not be able to rewind, and CI must run
the production path.

## F2. The evaluation figures

Review §2. Confirmed (**results**, **source**); every figure matches
`results/capacity_sweep.json` to the digit.

| Claim | Evidence |
| --- | --- |
| At 16,384 entries a full-scan read traces 32,768 operations and 6,225,920 bytes; the tree 654 and 807,348 | rows `capacity == 16384` |
| Read latency medians: full scan 87.12 ms runtime, 0.002 ms witness, 329.74 ms proof objects, 416.86 ms in all; tree 49.39, 446.92, 43.75 and 540.91 ms | same rows |
| Write latency: tree 709.22 ms, full scan 414.07 ms | same rows |
| Three trials, no warmup | `trials`, `warmups`; `probe/mplus-probe/src/lib.rs:49279-49280` |
| At most two keys are stored at any capacity | `let stored = capacity.clamp(1, 2)`, `lib.rs:51344` |
| Read/write mixes are computed, not executed | `mixed_times_100`, `lib.rs:49249` |
| The timed call excludes Lean checking and JSON serialization | `run_sweep_call`, `lib.rs:51408-51440`; `validation_time_ms` is 0 |
| Call-start reads and witness scans are outside the counts | the counts are those of `trace.physical_reads` and `physical_writes`; `docs/path-oram.md` says the call-start reads are not traced |
| The eviction rewrite makes a node access take 2.23 times fewer instructions, the same in two runs | `results/tree_eviction_instructions.json` |
| "Gas" is a modeled cost, not EVM gas | `docs/claim-boundary.md`, cost model `uo-modeled-resource-cost-v1` |

Two additions. The trace of one full-scan call at 16,384 entries is 20.7 MB of
JSON (`trace_json_bytes`), and building its proof bundles takes 330 of the
417 ms: the full scan's time goes to instrumentation, not to storage work. And
the committed `results/correctness.json` holds 4 differential trials per
benchmark, the CI subset (`scripts/run_validation.sh` defaults
`UO_CORRECTNESS_TRIALS` to 4).

## F3. Every call does work linear in the whole store

Review §4. Confirmed (**source**).

| Per-call step | Cost | Where |
| --- | --- | --- |
| Staging clones every committed object | every ciphertext byte | `staged_clone`, `state.rs:280`; `clone_oram_storage`, `generated_oram_codecs.rs:365` |
| Witness snapshot at call start and again at call end | decrypts every bucket of every private-scheme map | `witness_snapshot`, `state.rs:582`; `tree_position_map_witness_leaves`, `generated_oram_codecs.rs:5735` ("It reads the whole map, outside any trace") |
| The snapshot covers every Path ORAM object | including maps the entrypoint does not touch | `state.rs:589-599` |
| Loading a touched object into the call | clones its storage again and decodes it | `clone_for_tx`, `oram.rs:495`, `objects.rs:319` |

The shadow load itself is already limited to the entrypoint's objects
(`expected_loaded_object_schedule`, `runtime/uo-kernel-runtime/src/lib.rs:388`).
At 16,384 entries the witness snapshots are 447 of the 541 ms of a tree read.

Position: agree with the diagnosis. The remedy has two parts of very
different size. Removing the snapshots and the clone is engineering: no new
theorem is needed, and the witnesses stay the same bytes. Replacing the
event-per-slot proof objects changes a proof-object format and no theorem
statement. An authenticated store with local transition certificates and a
frame theorem is new research. The plan does the first now and tracks the
second as a research issue, where the review treats them as one milestone.

## F4. Read-only exact objects are rewritten, and scan events are modeled

Review §5. Confirmed (**source**, **results**).

- `exactEncodeRun` rewrites every touched object, read or written
  (`proof/lean/UOToolchain/KernelExactTrace.lean:210-219`). The runtime does
  the same: commit reseals an object when it was accessed
  (`reconcile_cell_commit_value` and its array and map forms,
  `runtime/uo-evm/src/generated_object_helpers.rs:830`). A full-scan `read`
  at 16,384 entries makes 16,384 reads and 16,384 writes.
- Dropping the writes of a statically read-only object is sound under the
  current observer: the schedule stays a function of the program. The Lean
  side is small, because `admittedKernel_exactUO` already holds for any
  encoder of the executed statements (`KernelExactTrace.lean:294`) and
  `ExactAccess` already separates reads from writes (`:39`).
- A full-scan map is decrypted once, when the call loads it
  (`SmallMapObject::clone_for_tx`, `objects.rs:319`). Each access then scans
  the decrypted copy and still records one physical read per slot
  (`record_small_map_scan`, `objects.rs:1640`). The traced reads are a modeled
  schedule, not I/O. A call that reads a map twice traces `2N` reads and
  performs `N` decryptions.

One addition the review does not make: the modeled cost does not grow with
the slots a read scans. `build_manifest_entry` computes
`2000 + 11·statements + 7·expressions + 29·max_commit_ops`
(`compiler/uo-solc/src/lib.rs:1427-1454`). The 477,161 units of a full-scan
read at 16,384 entries are almost all the rewrite of a map the call only
read. With the rewrite gone and the formula unchanged, a scan of any size
would cost about 2,000 units, and every gas break-even in `docs/path-oram.md`
would lose its meaning. The cost model must charge reads before the rewrite
is removed.

Position: agree with both parts (no rewrite of read-only objects; one load
per object per call). Scan fusion and a general version-aware reuse analysis
are follow-ups. As the review says, the backend break-evens must be measured
again against the optimized full scan.

## F5. Runtime primitives

Review §6. Confirmed (**source**, **docs**).

- Arithmetic. The confidential kernel evaluates secret operands with
  `Uint256` operations that branch on them
  (`eval_confidential_kernel_binary_generated`,
  `crates/uo-core/src/generated_confidential_kernel.rs:414-475`):
  `wrapping_sub` branches on the borrow (`types.rs:140-155`); `div_rem`
  returns early on a zero divisor and branches on every bit (`:175-192`), and
  the kernel branches on `divisor.is_zero()` before it; `cmp` returns at the
  first differing limb (`:309-319`); `Eq` uses the derived `==`; `And` and
  `Or` short-circuit. These are source-level observations. The repository
  claims no machine-code or timing obliviousness, so no claim is broken. But
  the ORAM code already uses masked selects for the same reason, and an
  enclave host can observe branches.
- Write classes. Raw backends classify a write from its old and new bytes
  (`classify_write`, `trace.rs:8187`). The UO backends record `Update` without
  looking (`PhysicalWriteEvent::from_shape`,
  `generated_object_helpers.rs:435-440`, `generated_oram_codecs.rs:197`,
  `runtime/uo-store/src/generated_store_helpers.rs:307-311`). The label is
  right when no encoded byte is zero and the nonce is fresh; neither is
  checked where the event is made.
- ORAM. The AVL proof is over inductive trees, and the runtime's node ids,
  leaves, free list and stash are replayed against it (2,400 operations on
  maps of at most 31 nodes). That a runtime run on any tape is the substituted
  run is tested on four more runs per side. `docs/path-oram.md` says both.
- The source language differs from Solidity 0.8 by design
  (`docs/claim-boundary.md`, Non-Claims).

Position: agree. Branch-free arithmetic and checked write classes are small
changes with mechanical acceptance tests, and they come early. A proof that
the runtime's ORAM follows the model on every tape is research; broader
testing comes first. The Solidity bridge is deferred: it would help adoption
and does not affect any current claim.

## F6. History, cryptographic and stash statements

Review §7. Confirmed (**source**).

- The adaptive-history theorem is an induction over abstract observation
  functions, `List String → HostTranscript → HostReleaseFrame →
  HostCallRequest → HostCallObservation`
  (`proof/lean/UOToolchain/HistorySemantics.lean:337`, theorem at `:501`). No
  private store, ORAM state or randomness is carried from call to call, and a
  release frame is a list of declared function names (`:319`), not the
  released values. Its single-call premise asks the two sides' observations
  to be equal, so it does not cover an adversary who adapts to a released
  value that differs.
- `bucketEncryptionINDCPA`, `metadataEncryptionINDCPA` and
  `stashOverflowBounded` are `Prop` fields (`PathOramSecurity.lean:531-533`),
  and the checkers instantiate all three with `True`
  (`CheckCanonicalPathOramPaperInstantiation.lean:10-12`,
  `CheckCanonicalPathOramPairTheoremInput.lean:12-14`). No Lean theorem
  depends on what they say. What Lean proves is that the leaf schedule is
  uniform and that the two sides' storage has the same locations and shapes;
  the step to computational indistinguishability is an argument on paper. As
  the review says, this is a missing interpretation, not an inconsistency.
- The stash bound: `14 · 0.6002^114 = 2^-80.15` per access, and `2^-50.25`
  by a union bound over `10^9` accesses. The count is of primitive accesses:
  a private-scheme write at 16,384 entries makes 77 node accesses (a get of
  19 and a put of 58), so `10^9` of them is about 13 million writes. That the
  bound holds while an operation keeps up to `3h + 1` nodes out of the tree
  is assumed (`docs/path-oram.md`). An overflow is not only an aborted call:
  the block that finds no room is dropped (`TreeStash::compact`,
  `generated_oram_codecs.rs:4013`; `push_fixed_stash_with_limit`, `:2102`),
  and the map commits without it, because an aborted call keeps its ORAM
  accesses (`objects.rs:1406-1475`). And the stash is not the largest term
  of a lifetime bound today: the nonce term of F1, item 7, is.
- Encrypted returns are outside the strongest theorem:
  `PolicyAgreesWithFlow.notEncrypted` (`KernelPaperMain.lean:292`) and
  `policyAgreesWithFlowB` (`KernelAdmission.lean:28-31`). No benchmark sidecar
  uses `encrypted_to_client`, so "every confidential entrypoint is admitted"
  holds because none returns an encrypted value. Every benchmark that returns
  a secret-derived value declassifies it to the host.

Position: agree with all four. Covering encrypted returns in the admitted
theorem and stating a lifetime stash budget with an occupancy experiment are
contained. A history theorem over the stateful, randomized runtime with a
quantified bound is research.

## F7. The record codec

Review §8: each sealed byte becomes two nonzero nibble bytes, so a sealed
record of `L` bytes occupies `2L`; packing seven bits per output byte would
give `⌈8L/7⌉`, about 43% less.

The arithmetic is confirmed (**source**): `write_nonzero_encoded`,
`runtime/uo-store/src/generated_codec.rs:13-33`; `L` is 62 for a `uint256`
value and 95 for a map record.

The recommendation is confirmed only in part. The encoding exists so that no
write is classified `Set` or `Clear`. How much encoding that takes depends on
the unit the observer classifies, and the repository does not fix that unit:
the runtime classifies whole records (`classify_write`), while the nibble
encoding makes every byte nonzero.

| Observer unit | Needed | Value (`L` = 62) | Map record (`L` = 95) |
| --- | --- | --- | --- |
| Now: nibble pairs, every byte nonzero | | 124 bytes, 4 words | 190 bytes, 6 words |
| Byte | seven bits per byte (the review's proposal) | 71 bytes, 3 words | 109 bytes, 4 words |
| 32-byte word (an EVM slot) | one nonzero marker byte per word | 64 bytes, 2 words | 99 bytes, 4 words (3 without the magic prefix) |
| Whole record (what the classifier checks today) | nothing: the magic prefix `0xA5 0x5A` is already nonzero | 62 bytes | 95 bytes |

So seven-bit packing is the right encoding only if the unit is the byte. For
a word or a record there is a denser encoding with a simpler proof. No
encoding excludes `Same`: that needs every unit to change on every write,
which follows from nonce freshness with overwhelming probability, not
certainty. The review asks which unit is intended and calls it the question
that most affects the design. It has to be decided before the codec changes
(decision D1).

The review's second figure is also confirmed (**results**): after the
eviction rewrite, eviction and compaction are 86.4% of a node access's
instructions (3,956,919 + 2,321,657 of 7,267,396). A node access makes about
33,000 masked node assignments. A routing network is a reasonable experiment
and is tracked for later.

## F8. Evaluation coverage

Review §9. Confirmed (**results**, **source**).

- `results/abort_rollback.json` has full-scan and local-scheme cases and none
  on the private scheme. `leakage_auc.json` and `mutual_information.json` have
  no private-scheme row. `trace_equivalence.json` has one (ERC20Lite).
- The description in `abort_rollback.json` still says the Path ORAM route
  rejects a mid-call abort (`probe/mplus-probe/src/lib.rs:49771`). The cases
  in the same file run, as `docs/path-oram.md` says. The string is stale.
- Storage is process memory (`Box<[Box<[u8]>]>`). There is no storage
  boundary to observe, so the trace cannot be compared with I/O (see F4).

Position: agree. The measurement work (occupancy, executed mixes,
repetitions, a full cost breakdown) should come before the optimizations, not
after them as in the review's sequence, so that each gain is measured against
a fair baseline.

## F9. Prior art

Review §10. The cited works exist: Cipherfix (Wichelmann, Pätschke, Wilke and
Eisenbarth, USENIX Security 2023), CipherGuard (arXiv 2502.13401), Zebrafix
(Pätschke, Wichelmann and Eisenbarth, RAID 2025), Oblivious Data Structures
(Wang et al., CCS 2014, already cited in `docs/path-oram.md`), EnigMap
(Tinoco, Gao and Shi, USENIX Security 2023), and structured leakage (Barthe,
Grégoire, Laporte and Priya, CCS 2021). Their contents were not checked
against the paper's claims.

Position: agree that the novelty claim should rest on the combination
(explicit update-class observer, effect-checked compilation, releases and
transactions in one proof), not on any single mechanism. That is mostly work
for the paper repository. Here it becomes a short related-work note and, later,
matched baselines.

## Where this validation differs from the review

1. F1 is demonstrated, not only argued: one rejected production call returns
   the seed. The storage keys, not only the ORAM coins, derive from it.
2. The production protocol is circular (F1, item 6), nonces can rewind
   (item 7), and CI does not run the production path (item 8). All three
   belong in the fix.
3. The cost model has to charge reads before read-only rewrites are removed
   (F4).
4. Seven-bit packing is not the best codec for two of the three possible
   observer units (F7).
5. Incremental state is split into an engineering part to do now and a
   research part to track (F3).
6. The measurement work moves ahead of the optimizations (F8).
