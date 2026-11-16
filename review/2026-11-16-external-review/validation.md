# Validation of the External Review of 16 November 2026

An external consultant reviewed this repository at commit `ac8f507`, the 45
commits after `030ae9e` that answered the review of November 2026 (Issues 22
to 59). The verdict was not to close that review as a whole yet: five groups
of repairs should come before `ac8f507` serves as the baseline of the
research issues 43 to 46. This document checks the review's claims against
the code, the Lean development and the committed results, and states a
position on each recommendation. The tasks that follow are in
[`tasks.md`](./tasks.md); their order and status are in
[`README.md`](./README.md).

The review text is not in this repository. Every claim is restated here, so
this document can be read without it. Numbers such as "§2" are the review's
section numbers.

## Method

All file and line references are to commit `ac8f507`. A path is given in
full where a file is first cited. After that, `storage.rs` is
`runtime/uo-store/src/storage.rs`; `store_meta.rs`, `engine.rs`,
`freshness.rs`, `objects.rs` and `oram.rs` are under `runtime/uo-evm/src/`;
`acceptance.rs`, `claim_manifest.rs` and `matched_baselines.rs` are under
`probe/mplus-probe/src/`; and `DeploymentAcceptance.lean` is under
`proof/lean/UOToolchain/`.

What was run, with the pinned toolchains (Rust 1.82.0, Lean 4.30.0-rc2):

| Check | Result |
| --- | --- |
| CI on `ac8f507` (run 225) and on `c5422f9` (run 224), whose trees differ in one line of the tracker | both pass |
| `scripts/run_validation.sh` on `c5422f9`, then CI's probe steps, clippy and `cargo test --workspace --all-features` | all pass; the acceptance gate accepts; the 428 tamper scenarios are rejected |
| Size and SHA-256 of the 99 files in `results/reproducibility_manifest.json` | all match |
| A Lean file that imports `UOToolchain.DeploymentAcceptance` and proves `HashInjective → Unforgeable → ∀ receipt, issued receipt` | checks (R3) |
| `jq` on the false-path script's traversal, and a count of the boolean false leaves of its four reports | `paths(scalars)` drops every false leaf; the reports hold 752, 6, 35 and 82 where the snapshot records 0 (R5) |
| The review's figures against the committed results | all exact (E1 to E3) |

Not run: a fault injection into the file store and a restart from a
rolled-back store. R1 and R2 are established from the control flow cited
below; Issues 65 to 68 add those tests.

Each finding says how it was checked: **run** (executed here), **source**
(read at the cited lines), **results** (a committed result file), or
**docs** (the repository's documents already say so).

## Summary

| Finding | Review | Verdict | Position | Issues |
| --- | --- | --- | --- | --- |
| R1. A storage error leaves the journal and the live runtime disagreeing about which calls committed | §2 | confirmed | agree | 65, 66 |
| R2. A restart checks too little to know that the store is the latest | §3 | confirmed, both gaps | agree; the mechanism is D9 | 67, 68 |
| R3. The receipt MAC assumption makes its rejection theorem vacuous | §4 | confirmed, and proved in Lean | agree; the route is D10 | 64 |
| R4. The matched baselines accept a missing competitor | §5 | confirmed | agree | 63 |
| R5. The false-path snapshot sees no false leaf, and the acceptance gate has no inventory | §6 | confirmed; the second gap is wider than stated | agree | 61, 62 |
| E1 to E3. What the evidence substantiates | §7 | every figure exact | agree | |
| Q1 to Q4. Qualifications | §8 | confirmed | agree | 63, 69, and this response |
| Which issues to close, qualify or reopen | §1 | agreed | agree | |

The review's account of what the response established (§1, §7) is
accurate, and so is its list of what stays research (Issues 43 to 46) or
deferred (Issue 50). It follows the decisions the tracker records (D4's
fact reuse alone, D5's in-repository baselines) and adds no prerequisite
against them.

## R1. Storage errors and the transaction history

Review §2: `FileStorage::append` writes a journal entry and, under
`SyncPolicy::Always`, syncs it, and either error propagates; the adapter has
no poisoned state and does not restore the journal to an entry boundary.
`FileStorage::open` stops at the first incomplete or invalid frame and
truncates what follows. `abandon` restores the image in memory, a later
`begin` is still allowed, and `StagedStore` abandons a call whose durable
commit failed. So (a) an append that stops part way can make later,
acknowledged entries unrecoverable, and (b) a whole entry whose sync failed
is a call the live runtime dropped and a restart replays, though the
production call path says that a failure leaves the committed state, the
freshness and the last receipt untouched. And `DroppedCallSeals::drop`
moves the seal counts in memory and discards the error of making the
reservation durable; a crash before it runs is the same concern. The review
asks for a persistence state machine (no further calls after a partial or
ambiguous append; a durable rollback or an explicit outcome-unknown result;
the recovery-critical reservation before the call's observable work; the
per-call seal bound enforced) and for fault tests.

**Confirmed (source).**

- `append` (`storage.rs:867-880`) runs `write_all` and then `sync_data`,
  each with `?`. It advances `journal_bytes` only after both, and nothing
  cuts the file back. The journal is opened for appending
  (`journal_file`, `storage.rs:760-764`), so the next entry lands after
  whatever a failed one left.
- `open` (`storage.rs:799-835`) reads frames until the first that is not
  whole with its SHA-256, and truncates the file there (`storage.rs:822`),
  with every frame after it.
- `commit` (`storage.rs:1025-1056`) appends and then completes the image's
  commit; `reserve_seals` (`storage.rs:1004-1015`) appends and then updates
  the image; `begin` (`storage.rs:1021`) has no state that a failed append
  sets.
- `StagedStore::make_durable` (`runtime/uo-evm/src/store_meta.rs:124-128`)
  leaves the call's records pending on an error, and its `Drop`
  (`store_meta.rs:131-137`) abandons them.
  `commit_staged_with_receipt` makes the commit durable before it changes
  the live state (`engine.rs:731`), as the comment at `engine.rs:363-366`
  promises.

So both consequences follow. (a) After a write that stops part way, the
instance keeps serving calls; their reservations and commits are appended
after the torn bytes and acknowledged, and a later `open` truncates them
with the torn frame. (b) A frame that is whole in the file but whose sync
failed is dropped by the live runtime and replayed by `open`: a restart
finds a call that its caller was told had failed.

`DroppedCallSeals::drop` (`store_meta.rs:189-204`) moves each key's count
and then calls `let _ = storage.reserve_seals(resume)`
(`store_meta.rs:200`). One precision: a lost reservation does not repeat a
nonce. A record reaches the store only under a count that is already
durably reserved (`store_sealed_record` reserves before it writes,
`runtime/uo-store/src/generated_surface.rs:170-174`), and counts only grow
(`resume_seal_count` takes the maximum, and so does the adapter,
`storage.rs:366`). What it breaks is Issue 52's property across a restart.
A restart resumes at the last durable reservation, which may have been made
part way through the dropped call (a step of 2^20 beyond the count it had
reached, `storage.rs:1179-1186`), so the count after the restart can show
how far the call got. A crash during the call, when no destructor runs,
does the same. `DROPPED_CALL_SEAL_QUANTUM` (`store_meta.rs:139-143`) assumes
that a call seals fewer than 2^32 records under one key, and nothing checks
it. Exceeding it would not repeat a nonce either, for the same reason, but
the count after a dropped call would again depend on how far it got.

One more path belongs in the fault tests. `commit` ignores a checkpoint
that fails after the commit's append (`storage.rs:1052`). The snapshot is
written to a temporary file and renamed, which is atomic, but no test fails
any of its steps.

**Position: agree.** How a storage error ends a call is decision D8 (Issue
60). Issue 65 makes the adapter fail closed and adds the fault matrix, and
Issue 66 makes the dropped call's restart point durable before the call
runs and checks the bound.

## R2. What a restart checks

Review §3: (A) `begin_call` advances the call counter, but
`finish_call(aborted)` does not advance the rollback counter. A semantic
abort still completes a call, with a receipt and committed freshness and
storage state. A restart compares only the rollback counter with the
attested one and takes the call counter from the stored metadata. So the
committed states before and after a committed aborted call have one
externally checked generation. (B) The reservation high-water marks set the
counts a restored key resumes at, yet the tagged metadata does not carry
them, the digest of the sealed records does not cover them, the receipt's
`ends_in` check does not bind them, and the journal frames them with an
ordinary checksum. Binding them in the next commit alone would not do,
since failed calls consume reservations after the last receipt. The claim
boundary does assume that a restart's files are the ones the runtime wrote
last, but Issue 58's acceptance and its as-built text describe refusing a
changed or stale store, and name as the remaining exclusion a store rolled
back together with the attested counter. The review asks to implement the
bindings or to state the stronger precondition and narrow the claim, and
recommends implementing.

**Confirmed (source, docs).**

- `finish_call` (`freshness.rs:87-97`) returns before advancing the
  rollback counter when the call aborted. `begin_call` advanced
  `next_call_counter` on the staged freshness, which a committed abort
  keeps. `recover` (`freshness.rs:48-64`) compares the rollback counter
  alone and takes the call counter from the metadata. The Lean deployment
  model has the same rule (`DeploymentAcceptance.lean:290`).
- A semantic abort commits. The production path builds a receipt for every
  staged call that passes its checks, aborted or not, and commits it with
  the call (`engine.rs:367-388`), and an aborting call reseals what it
  loaded.
- So the store before a committed abort and the store after it carry one
  rollback counter, and each holds a last receipt that ends in its own
  state. `ProductionContractInstance::restart` (`engine.rs:219`, through
  `restart_internal`, `engine.rs:467-478`) accepts either with that counter.
- (B) `StoreMeta` (`store_meta.rs:24-37`) holds the epoch, the two
  counters, the initialized flag, the public-state digest and the last
  receipt, and no reservation. Reservations are in the snapshot
  (`storage.rs:907-911`) and in journal entries (`storage.rs:1004-1015`),
  framed with an unkeyed SHA-256 (`storage.rs:729-753`). A restart resumes
  each key at `reserved_seals()` (`objects.rs:804-812`, `oram.rs:695`). The
  sealed-record digest covers locations and records alone.

The consequence of (B) is worse than a stale state. A host that lowers a
reservation in the files, or rolls the files back across a reservation
that a later, dropped call consumed, makes the restarted runtime seal under
counts that records the host has already seen carry: a repeated nonce under
ChaCha20-Poly1305.

Under the documented precondition (`docs/claim-boundary.md`, The Storage
Boundary: "a restart assumes the files are the ones the runtime wrote
last") neither attack is in scope. But the non-claim
(`docs/claim-boundary.md:847-849`) and Issue 58's as-built text name as
the only undetected case a store rolled back together with the attested
counter. That is wrong: a rollback across committed aborts needs no change
of the counter, and a lowered reservation needs neither.

**Position: agree.** The generation should advance with every committed
call whatever the mechanism. For the reservations, the review's
implementation route is sound but has a cost and two designs; decision D9
(Issue 60) chooses between authenticated reservations anchored to the
attested generation, fresh keys at every restart, and the narrowed claim.
Issues 67 and 68.

## R3. The receipt-authentication assumption

Review §4: in `DeploymentAcceptance.lean` the tag is a total function, and
`Unforgeable` says that for every hash `h` and tag `t`, if `t` is the tag
of `h` under the session key then some issued receipt has hash `h`.
Instantiated at a receipt's own hash and the tag computed from it, the
premise holds by construction, and with `HashInjective` the receipt is
issued. So the assumptions imply that every receipt was issued, and the
rejection theorem's premise that a receipt was not issued makes its
premises inconsistent. The review offers two routes: remove the
authentication theorems from the assurance claim, keeping the receipt-chain
theorems and arguing the MAC externally; or state the assumption over the
candidates an adversary can produce, with a non-vacuity obligation.

**Confirmed (run).** `Unforgeable` (`DeploymentAcceptance.lean:453-457`)
quantifies over every hash and every tag equal to that hash's tag. A Lean
file that imports the module proves in a few lines that `HashInjective`
and `Unforgeable` give `issued receipt` for every receipt: it instantiates
`Unforgeable` at `receiptHash receipt` and that hash's tag, with `rfl` as
the premise. It follows that the premises of
`deployment_receipt_not_issued_tag_rejected`
(`DeploymentAcceptance.lean:476`) cannot hold together.
`deployment_receipt_tag_verifies_issued` concludes nothing that the
assumptions do not give for every receipt. The claim boundary cites both
(`docs/claim-boundary.md:212` and the assumption row at `:713`), and so
does the claim manifest's `assumption-production-receipt-mac`.

Not affected: the receipt-chain theorems
(`deployment_receipts_issued_in_turn_follow` and the theorems before it) do
not use the MAC assumption, and the runtime's HMAC-SHA256 tag is as it was.

**Position: agree.** The route is decision D10 (Issue 60); Issue 64.

## R4. The matched baselines' coverage

Review §5: `run_matched_baselines` records every compilation error as a
rejected cell and goes on. The planner is compared with the competitors
that were measured, and the report's acceptance asks that what was measured
agree, not that every supported cell was measured. A supported backend can
vanish from the comparison while every remaining check agrees. The
committed reports are complete: 48 measured cells and 15 rejections of the
local scheme above its capacity limit.

**Confirmed (source, results).** `matched_baselines.rs:356` turns any error
of `compile_artifact_from_metadata` into a `"status": "rejected"` cell and
continues. A cell enters `measured` only when its calls of a kind agree.
The planner check takes the minimum over `measured` and skips a capacity
with nothing measured (`matched_baselines.rs:481`). `accepted`
(`matched_baselines.rs:515`) is the conjunction of the three verdicts. In
both committed reports, 63 cells: 48 measured, and 15 rejected, all the
local scheme at 1,024 to 16,384 entries with its capacity diagnostic. The
planner's choice under a memory budget is tested in the unit tests of
`uo-core` and `uo-solc`, but no matched-baseline map declares a budget (Q2).

**Position: agree.** Issue 63.

## R5. The evidence gates

Review §6 (A): the false-path snapshot
(`scripts/rebuild_review_validation_false_paths.sh`) traverses with
`paths(scalars)`, which keeps only paths whose value is truthy, so false
leaves never enter it and its false-path set is always empty. The four
gated reports hold 752, 6, 35 and 82 false leaves. Those include expected
negatives and explicit non-claims, so they are not failures, but the
inspection inspects none of them. Repair the traversal, reuse the
acceptance gate's classification rather than require zero false leaves, and
add a required-false negative control and an expected-false positive
control.

**Confirmed (run).** The traversal is at line 53 of the script. On
`{"a":false,"b":true,"c":{"d":false,"e":1}}`, `jq '[paths(scalars)]'` gives
`[["b"],["c","e"]]`, and the script's expression gives `[]`. The committed
`review/validation_false_paths.json` records `false_count: 0` for each
report. Counting their boolean false leaves directly gives 752
(`bridge_validation.json`), 6 (`kernel_model_alignment_validation.json`),
35 (`runtime_boundary_validation.json`) and 82 (`static_checks.json`). The
script is in this repository's first commit, `cdd1091` (Issue 09); the
commit the review names for it, `28d8d8b6`, is not an object here, and
neither is `7d387dc5` below. Both predate this history.

Review §6 (B): `run_acceptance_check_report` classifies the false leaves of
whatever JSON files it finds. It enforces no inventory of required reports,
no schema or check fields, and no populations, so a missing check or an
empty report produces no failure. The claim manifest's check that
referenced artifacts exist mitigates missing files in the full pipeline,
but not missing checks. The review asks for a contract per profile:
required reports and schemas, required check fields, expected populations,
allowed negatives, and negative controls.

**Confirmed, and wider than stated (source, results).**
`acceptance.rs:351-419` reads the results directory and classifies every
`.json` file it finds. `accepted` means no unclassified or required-failure
leaf and no proof-grade report whose own `accepted` is false; a missing or
empty report adds no false leaf. The mitigation is smaller than the review
says. The claim manifest checks that the source, Lean and runtime files a
claim cites exist (`claim_manifest.rs:818-835`, the 126 `file-exists`
checks of `results/claim_status.json`), not its `benchmark_result_files`,
so a missing result file is not caught there either.

**Position: agree with both.** Issues 61 and 62. They come first in the
order of work, because every later repair is validated through these
gates.

## E. What the evidence substantiates (§7)

All checked (results):

- E1. The storage-boundary report covers 14 benchmark and backend pairs and
  47 calls, and its adapter and trace counts agree on 3,862 reads and 4,395
  writes (`results/storage_boundary.json`, `coverage` and `totals`).
- E2. Issue 47's control at 16,384 entries: a private-tree read's own work
  18.186 ms and 8.349 ms, an overwrite's 70.484 ms and 29.682 ms, the whole
  measured read 68.985 ms and 57.712 ms, the whole overwrite 244.851 ms and
  203.243 ms (`capacity_sweep_control_before_eviction_networks.json` and
  `capacity_sweep_control_after_eviction_networks.json` in
  `review/2026-11-external-review/`, `p50_runtime_ns` and `p50_latency_ns`).
- E3. `results/capacity_sweep_full.json` was measured at `990b054`, after
  Issues 51 to 59 and before Issues 47 to 49, with five warmups, 30
  measured rounds and the full occupancy grid; the quick sweep has one
  warmup and two rounds and keeps its records in memory;
  `docs/evaluation.md` says so.

The review credits Issues 54, 48 and 39 with useful proof results and reads
them at their stated scope. Agreed.

## Q. Qualifications to keep (§8)

- Q1, Issue 36 (docs). Its as-built text already says that the first
  criterion is met "in substance and not to the letter": a measured or
  production call opens no sealed record for its witness, but the witness
  still copies both position maps, so its time grows with the capacity. The
  tracker row says `done` without that. Agreed: this response qualifies the
  issue in `review/2026-11-external-review/tasks.md` and links the
  remaining work, witnesses of the changed leaves alone, to Issue 44.
- Q2, the planner (source, docs). Its enclave memory is a model of the
  records and plaintext a call holds, and leaves out the runtime's other
  buffers; no matched-baseline map declares a budget; and its model call
  reads or writes the map once, so it says nothing of optimality for an
  entrypoint that accesses a map several times. The claim boundary states
  the first; the rest is new. Agreed: Issue 63.
- Q3, the production receipt (docs). A production receipt hashes every
  sealed record of a changed ORAM object, which the sweep's measured call
  does not include (`docs/path-oram.md`; Issue 44). Agreed: Issue 69 keeps
  it in the baseline statement.
- Q4, the observer (docs). The codec's guarantee concerns aligned 32-byte
  words (D1), and source freezing constrains the implementation text
  without proving its compilation. The claim boundary says both. Agreed;
  no task.

## §1. Which issues to close, qualify or reopen

Agreed throughout. The repairs reopen guarantees of Issues 41, 52, 53 and
58 and the coverage part of Issue 49. They are tracked as new issues (60 to
69) and not by setting those rows back to `todo`, since what those issues
built stands and each new issue names the guarantee it repairs.
`review/2026-11-external-review/README.md` points here.
