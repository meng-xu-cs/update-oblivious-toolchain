# Tasks from the External Review of 16 November 2026

These are the tasks that follow from [`validation.md`](./validation.md).
Their order, dependencies and status are in [`README.md`](./README.md).

Issue numbers continue those of the previous review
([`review/2026-11-external-review/`](../2026-11-external-review/README.md),
Issues 22 to 59). The definition of done of
[`review/runbook.md`](../runbook.md) applies: implementation, focused Rust
tests or Lean theorems, regenerated artifacts, a probe report bit where a
claim or the evaluation is affected, documents changed only to match the
code, and a passing validation slice. A change to the runtime, `uo-core` or
the Lean sources changes every artifact identity, so regenerate with
`scripts/run_validation.sh` in the same change, and before pushing replay
CI's probe steps and run clippy and `cargo test --workspace
--all-features`.

Each issue names its source (a finding `R1` to `R5` or `Q1` to `Q4` of the
validation, and the review's section), a size, and what it depends on.
Sizes are relative, not a schedule: **S** a day or less, **M** several
days, **L** one to two weeks.

---

## Wave 9: decisions

### Issue 60 — Decide the storage-error contract, the recovery mechanism and the receipt proof's route

Source: R1, R2, R3 (§2, §3, §4). Size: S. Depends on: the maintainer.

#### Issue description

Five later issues cannot be designed without a decision that the code does
not determine. The Decisions table of [`README.md`](./README.md) holds their
status.

**D8, what a storage error means for a call.** Blocks Issues 65 and 66.

| | (a) Outcome unknown | (b) Durable rollback first |
| --- | --- | --- |
| After a failed journal append | the adapter is poisoned: every later operation fails until the deployment restarts from its files | the adapter cuts the journal back to its last entry, or appends an entry that cancels the commit, and syncs; if that succeeds the call failed for certain and the adapter goes on; otherwise as (a) |
| What the caller learns | an error that says the outcome is unknown; the restarted deployment's last receipt says whether the call committed | a definite failure in the usual case, outcome unknown otherwise |
| Cost | a restart after every storage error | more states to test; and the certainty rests on a sync after a failed sync, which some file systems do not honor |

Recommended: (a). It is the smaller contract, and storage errors are rare
enough that a restart is a fair price.

**D9, what a restart checks of the store's freshness.** Blocks Issues 67
and 68. Whatever is chosen, the commit generation of Issue 67 should
advance with every committed call; the options differ for the
reservations.

| | (a) Authenticated reservations | (b) Fresh keys at each restart | (c) A narrower claim |
| --- | --- | --- | --- |
| Mechanism | each key's reserved count is in the tagged commit metadata, a reservation is a metadata commit, and every commit advances the generation that the restart compares with the attested one | a restart draws a new key epoch, reseals every record under keys derived for it, and records the epoch in the tagged metadata; no count of an old key is used again | keep the precondition that a restart's files are the ones the runtime wrote last, and say that it covers aborted calls' generations and the reservations |
| What it protects without that precondition | a rollback across a call or a reservation, and a changed reservation | nonce safety under any rollback of the files; a restart shows nothing of a dropped call |
| Cost | the attested counter advances at every commit and reservation; reservations are rare after Issue 66 | a restart rewrites the store, and since that changes the ciphertext digest the receipt chain needs a restart receipt, in Rust and in `DeploymentAcceptance.lean` |
| Size | M | L | S |

Recommended: (a). (b) is the stronger design if a restart that rewrites
the store is acceptable; (c) leaves nonce safety resting on the host's
honesty about the files.

**D10, the route of the receipt proof.** Blocks Issue 64.

- (a) Over an adversary's outputs. State the MAC assumption over the pairs
  of hash and tag that an adversary of the session can produce, of which
  the issued receipts' pairs are a part, and prove a non-vacuity model: a
  deployment with an issued and an unissued receipt in which the
  assumptions hold, the issued receipt's tag verifies, and no produced tag
  of the unissued receipt does.
- (b) Remove. Drop the two authentication theorems from the assurance
  claim, keep the receipt-chain theorems, and argue the MAC's authenticity
  outside Lean, in the assumption row.

Recommended: (a). It keeps a theorem that says what a verifier may
conclude, and the non-vacuity model makes a later vacuity a build error.

#### How to fix

Record each decision in the Decisions table of `README.md` when it is
made. A decision reaches the topic documents with the issue that implements
it.

#### Acceptance criteria

- The three decisions are in the Decisions table.
- The tracker no longer shows Issues 64 to 68 as blocked.

---

## Wave 10: the gates that check the evidence

### Issue 61 — Make the false-path snapshot see false leaves, and classify them as the acceptance gate does

Source: R5 (§6). Size: S. Depends on: nothing.

#### Issue description

`scripts/rebuild_review_validation_false_paths.sh` lists the false leaves
of four gated reports in `review/validation_false_paths.json` and `.txt`,
and the validation and CI check the list. Its traversal,
`paths(scalars)`, drops every false leaf, so the list has been empty since
the script was written. The four reports hold 875 false leaves (752 in
`bridge_validation.json`, 6 in `kernel_model_alignment_validation.json`,
35 in `runtime_boundary_validation.json`, 82 in `static_checks.json`),
expected negatives and non-claims among them. A list that requires zero
would reject legitimate content.

#### How to fix

1. Traverse the booleans (`paths(type == "boolean")`).
2. Classify each false leaf with the acceptance gate's classifier
   (`classify` in `probe/mplus-probe/src/acceptance.rs`), not with rules in
   `jq`: the probe writes the snapshot (a report of its own, or a section of
   `acceptance.json` that the script extracts), so the rules stay in one
   place.
3. The check fails when a gated report has a false leaf classed
   `required_failure` or `unclassified`, and when the snapshot differs from
   the committed one.
4. Controls: a fixture with an expected negative (a tamper scenario's
   `accepted: false` beside `rejected: true`) that the check passes, and
   one with a required false leaf (a top-level `accepted: false`) that it
   fails. Run both where CI runs the check.

#### Acceptance criteria

- The regenerated snapshot lists the 875 false leaves, each with its
  class, and none is `required_failure` or `unclassified`.
- The positive control passes and the negative control fails.
- `run_validation.sh` and CI run the new check.

### Issue 62 — Give the acceptance gate an evidence contract

Source: R5 (§6). Size: M. Depends on: Issue 61.

#### Issue description

`run_acceptance_check_report` classifies the false leaves of whatever
reports are in `results/`. A missing report, an empty one, or one that lost
a check field produces no false leaf, so the gate accepts it. The claim
manifest checks that the source, Lean and runtime files a claim cites
exist, not its result files.

#### How to fix

1. A contract of the committed bundle in the probe
   (`probe/mplus-probe/src/evidence_contract.rs` or in `acceptance.rs`): for
   each required report, its file, its schema string, its required
   top-level checks with their types (a boolean check must be `true`), and
   its populations, each with a bound: for instance 428 tamper scenarios,
   47 storage-boundary calls, 63 matched-baseline cells, and 14 admitted and
   25 rejected admission features.
2. The gate fails closed on a missing report, an unknown schema, a missing
   or mistyped field, or a population outside its bound, and names which.
3. The claim manifest checks that every `benchmark_result_files` entry
   exists (a `result-exists` check beside `file-exists`).
4. Negative controls: tests that remove a report, empty one, delete a check
   field and shrink a population, and see the gate fail with the reason;
   the committed bundle is the positive control.
5. A change that moves a population edits the contract in the same commit,
   as the expected-negative counts are edited now.

#### Acceptance criteria

- The committed bundle passes the contract.
- Each negative control fails, naming its reason.
- CI's acceptance step enforces the contract.

### Issue 63 — Make the matched baselines' coverage fail closed, and test the planner under a budget

Source: R4, Q2 (§5, §8). Size: S. Depends on: nothing; Issue 62 holds its
populations once it is done.

#### Issue description

`run_matched_baselines` records every compilation error as a rejected cell,
and its planner check compares whatever was measured. A supported backend
that stopped compiling would vanish from the comparison without a false
verdict. No matched-baseline map declares an enclave memory budget, so the
planner's choice under one is tested only by unit tests, and the documents
do not say that the planner's model call reads or writes the map once.

#### How to fix

1. Derive each cell's admissibility from the grid, as the planner does: a
   Path ORAM scheme holds scalar keys and values, and the local scheme at
   most 128 entries. An admissible cell must compile and run; an
   inadmissible one must be rejected with the diagnostic its exclusion
   predicts. Anything else makes the report's verdict false
   (`every_admissible_cell_measured`, `only_inadmissible_cells_rejected`).
2. The planner check requires every admissible backend at a capacity to be
   measured before it compares, so a missing competitor fails the report
   whether or not it would have won.
3. The report states and checks its expected counts: cells, calls, planner
   checks and planned maps.
4. Budgeted planned maps: at 4,096 entries and above, a map compiled with
   `enclave_memory_budget_bytes` between the full scan's modeled memory and
   the private scheme's, checked as the other planned maps are; and one
   with a budget that no backend fits, which must not compile.
5. A negative control: a test that makes an admissible cell fail to compile
   and sees the verdict turn false.
6. Documents: the claim boundary's Backend Planner says that the model's
   call reads or writes the map once, so it claims nothing of optimality
   for an entrypoint that accesses a map several times, and keeps "modeled"
   in every statement of the planner's memory.

#### Acceptance criteria

- The regenerated quick and full reports measure 48 cells and reject 15, by
  rule, and the budgeted maps are on the backends their plans chose.
- The negative control fails the verdict.
- The documents state the planner's two model limits.

---

## Wave 11: the guarantees

### Issue 64 — State the receipt MAC assumption over what an adversary can produce, with a non-vacuity model

Source: R3 (§4). Size: S to M. Depends on: Issue 60 (D10).

#### Issue description

`DeploymentReceiptTags.Unforgeable` quantifies over every hash and the tag
computed from it, so with `HashInjective` it gives that every receipt was
issued (proved in the validation), and the premises of
`deployment_receipt_not_issued_tag_rejected` are inconsistent. The claim
boundary and the claim manifest cite both theorems as the formal statement
of the receipt MAC's assumption.

#### How to fix

With D10 (a):

1. In `proof/lean/UOToolchain/DeploymentAcceptance.lean`, replace
   `Unforgeable` by an assumption over a relation `Produced` of the hash and
   tag pairs an adversary of the session can output: a produced pair whose
   tag verifies is an issued receipt's. The verifier's theorems speak of a
   produced candidate.
2. Weaken `HashInjective` to what the verifier needs: no receipt but an
   issued one has an issued receipt's hash. This also makes the model of
   step 3 easy to build.
3. Prove a non-vacuity theorem in the proof root: an explicit model (a hash
   that tells two chosen receipts apart, `Produced` the issued receipt's
   pair and pairs with a wrong tag) with one issued and one unissued
   receipt, in which both assumptions hold, the issued receipt's tag
   verifies, and no produced tag of the unissued receipt does.
4. Restate `deployment_receipt_tag_verifies_issued_in_a_state` in the new
   form.
5. Update `docs/claim-boundary.md` (the theorem's paragraph and the
   assumption row), the claim manifest's `assumption-production-receipt-mac`,
   and the static checks that name the theorems.

With D10 (b): remove the two theorems and their citations, keep the
receipt-chain theorems, and rewrite the assumption row as an argument
outside Lean.

#### Acceptance criteria

- `Unforgeable` in its current form is gone.
- With (a), the new statements and the non-vacuity theorem build in
  `UOToolchain.ProofGradeRoot`.
- The documents and the claim manifest name what replaced it.

### Issue 65 — Fail closed on storage errors, and test every failure

Source: R1 (§2). Size: M to L. Depends on: Issue 60 (D8).

#### Issue description

A failed journal append leaves the file adapter serving calls. After a
write that stops part way, later entries land behind the torn frame, are
acknowledged, and are dropped by the next `open`. After a whole write whose
sync failed, the live runtime drops a call that a restart then replays. A
failed checkpoint is ignored and untested. The production call path
promises that a failure leaves the committed state, the freshness and the
last receipt untouched, which the files may contradict.

#### How to fix

With D8 (a):

1. `FileStorage` gets a poisoned state. A failed append (write or sync), a
   failed truncation and a failed checkpoint set it, and every later
   operation fails, naming it, until the directory is opened again.
2. The adapter's errors say whether anything reached the files: definite,
   for a failure before the append, or outcome unknown.
   `StagedStore::make_durable` passes that on, and the production call path
   returns an outcome-unknown error, after which the instance refuses
   calls.
3. A restart resolves the outcome. `ProductionContractInstance::restart`
   returns the last receipt it found, and a helper compares it with the
   receipt the caller held and the request it sent: the call committed or
   it did not.
4. `open` keeps cutting a torn last frame, reports how many bytes it cut,
   and refuses a journal in which a whole frame follows a bad one.
5. Fault injection: a hook in `FileStorage`, in test and diagnostics builds
   alone, that makes the n-th write stop part way, the n-th sync fail after
   a whole write, a reservation's append fail, and each step of a
   checkpoint fail (the snapshot's write, its rename, the journal's
   truncation). For each fault: the call's result, the poisoned adapter,
   and what a reopen finds. Every acknowledged commit is present, and a
   commit of unknown outcome is either wholly present or wholly absent,
   with the restarted deployment's last receipt saying which.
6. Run the matrix through `ProductionContractInstance` in the production
   build, and add its outcomes to the storage-boundary report so that the
   claim boundary can cite them.
7. Documents: the storage contract in the claim boundary's The Storage
   Boundary and in `docs/runtime/secret-state.md`, and the comment at
   `runtime/uo-evm/src/engine.rs:363-366`.

With D8 (b), steps 1 and 2 first try to restore the last entry boundary,
and the matrix tests both outcomes.

#### Acceptance criteria

- The fault matrix passes, in the production build too.
- No call returns success after a failed append.
- Every acknowledged commit survives every injected fault.
- A commit of unknown outcome resolves at the restart to exactly one of its
  two states, and the restarted receipt identifies it.

### Issue 66 — Make a dropped call's restart point durable before the call runs, and bound a call's seals

Source: R1 (§2). Size: M. Depends on: Issue 65.

#### Issue description

Issue 52 makes the count each key resumes at after a dropped call a
function of its count before the call. The reservation that carries this
over a restart is made in `DroppedCallSeals::drop`, after the call, and its
error is discarded; after a crash nothing makes it. A restart then resumes
at the last durable reservation, which may have been made part way through
the call and so show its progress. The quantum of 2^32 assumes that a call
seals fewer records than that under one key, and nothing checks it.

#### How to fix

1. Before a call seals anything (`DroppedCallSeals::begin`), make durable,
   in one journal entry, a reservation at `seal_count_after_dropped_call`
   of each key's count, skipping keys already reserved that far. A failed
   reservation fails the call before it seals. Reservations only grow, so a
   key needs a new one only after a dropped call, or once in 2^32 seals.
2. `DroppedCallSeals::drop` then moves the counts in memory and does no
   I/O.
3. Check the bound. The compiler, `uo-check` and the deployment refuse an
   entrypoint that could seal 2^32 records under one key in a call (bounded
   by its load and commit operation counts, since an aborting call reseals
   what it loaded).
4. Tests: a call whose `DroppedCallSeals` is forgotten without its `Drop`,
   and a store reopened in the middle of a call, both resume every key at
   the fixed point; a failed reservation fails the call before it seals;
   an artifact past the bound is refused.
5. Update the static check `dropped_calls_leave_fixed_seal_counts`,
   invariant 19 of `docs/runtime/secret-state.md`, and the claim boundary.

With D9 (b) a restart uses new keys and the restart cases of steps 1 and 4
go; the in-memory move and the bound stay.

#### Acceptance criteria

- After a dropped or crashed call, a restart resumes every key at a count
  that depends on the call's start counts alone, with no I/O after the call
  began.
- The bound is checked, and the tests pass.

### Issue 67 — Advance a commit generation with every committed call, and check it at restart

Source: R2 (§3). Size: M. Depends on: Issues 60 (D9) and 65.

#### Issue description

A committed call that aborts leaves the rollback counter where it was, and
a restart compares that counter alone. The stores before and after such a
call pass the same check, so a restart can resume from the older one, and
the non-claim names only a rollback together with the attested counter.

#### How to fix

1. The tagged commit metadata carries a generation that advances at every
   commit: the deployment's, each committed call's, aborted or not, and with
   D9 (a) each reservation's (Issue 68). The rollback counter keeps its
   meaning for receipts and return nonces, and in the Lean deployment
   model.
2. A restart takes the attested generation in place of the attested
   rollback counter, and refuses metadata with another.
3. The call result carries the generation after the commit, so that the
   platform's monotonic counter can follow it, and the TEE deployment row
   says that the counter advances with it.
4. Tests in the production build: a call, then an aborting call, then a
   restart from a copy of the files taken before the aborting call, with
   the generation after it, is refused; the right pair is accepted; and the
   converse.
5. Documents: the claim boundary's restart paragraph and its non-claim,
   `docs/runtime/tee-observer.md`, and Issue 58's as-built text, which says
   what the restart refused.

With D9 (c) the generation is still recommended. If it is not built, the
claim boundary and the non-claim say that a store rolled back across
committed aborts passes the check.

#### Acceptance criteria

- A restart refuses a store whose generation is not the attested one,
  across aborted calls too.
- The tests pass, and the documents and the non-claim say what is checked.

### Issue 68 — Keep a restart from resuming a key below a count it has used

Source: R2 (§3). Size: M with D9 (a), L with (b), S with (c). Depends on:
Issues 66 and 67.

#### Issue description

A restart resumes each key at the reservation it reads from the files,
which neither the tagged metadata nor the sealed-record digest nor the
receipt covers. A lowered or rolled-back reservation makes the restarted
runtime seal under counts that records the host has seen carry, which
repeats a ChaCha20-Poly1305 nonce. Only the precondition that the files are
the ones the runtime wrote last excludes it.

#### How to fix

With D9 (a):

1. `StoreMeta` carries each key's reserved count. A reservation is a
   metadata commit, a journal entry with the tagged metadata and no
   records, that advances the generation (Issue 67). The journal's
   reservation entries go, and `open` takes the reservations from the last
   metadata.
2. A restart resumes each key at the reservation in the metadata it
   verified, and the generation check makes that metadata the latest.
3. Tests: a reservation lowered in the files fails the tag check; files
   rolled back across a reservation that a dropped call made after the last
   receipt are refused with the later generation; a restart from the right
   files repeats no nonce.
4. Documents: the claim boundary's The Storage Boundary and its
   non-claims.

With D9 (b): derive the keys of a restart's epoch, reseal the store at the
restart, issue a restart receipt in Rust and in `DeploymentAcceptance.lean`,
retire the reservation machinery, and test that a restart from any earlier
set of files seals under keys never used before.

With D9 (c): the claim boundary and the non-claims say that the
reservations, and with them nonce safety across a restart, rest on the
precondition; Issue 58's as-built text is corrected.

#### Acceptance criteria

- With (a) or (b), no restart resumes a key below a count used in a state
  the attested generation has passed, and the tests show it.
- With (c), every document that describes the restart states the
  precondition and what rests on it.

---

## Wave 12: the repaired baseline

### Issue 69 — Measure the repaired baseline

Source: E3, Q3 (§7, §8). Size: M, mostly machine time. Depends on: Issues
61 to 68.

#### Issue description

The repairs change what a call does at the storage boundary: a reservation
before the call, metadata commits, and the checks of a poisoned store. The
committed full capacity sweep was measured at `990b054`, before Issues 47 to
49. The research issues 43 to 46 should start from a baseline measured on
the code they change.

#### How to fix

1. Run the capacity sweep's full profile with synced files, and the matched
   baselines' full profile, on the final commit of Wave 11.
2. Compare the sweep with the committed one
   (`scripts/compare_capacity_sweep.py`) and report what the repairs cost a
   call: journal entries, bytes and syncs.
3. Update `docs/evaluation.md` and `docs/path-oram.md`, and this
   directory's README. Its baseline names the commit and what the baseline
   does not measure: the production receipt's digest of every sealed record
   of a changed ORAM object (Issue 44), and memory beyond the planner's
   model.

#### Acceptance criteria

- Both full reports are regenerated on the final commit of Wave 11.
- The tracker's baseline names that commit, and Issues 43 to 46 start
  from it.
