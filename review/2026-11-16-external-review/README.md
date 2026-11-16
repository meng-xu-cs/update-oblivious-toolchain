# External Review, 16 November 2026

An external consultant reviewed the repository at commit `ac8f507`, the
response to the review of November 2026
([`review/2026-11-external-review/`](../2026-11-external-review/README.md)).
The review's verdict was to keep most of that response but not to close it
as a whole: five groups of repairs should come before `ac8f507` serves as
the baseline of the research issues 43 to 46. This directory holds the
response.

| File | Content |
| --- | --- |
| [`validation.md`](./validation.md) | every claim of the review checked against the code, and a position on each recommendation |
| [`tasks.md`](./tasks.md) | Issues 60 to 69: description, fix and acceptance criteria |
| this file | the positions in brief, the decisions, the order of work, and the tracker |

The review text is not in the repository; `validation.md` restates each
claim.

## Using the Tracker

- Work an issue as `tasks.md` describes it, to the definition of done of
  [`review/runbook.md`](../runbook.md).
- Title the commit `Issue NN: …`. In the same commit, set the issue's row
  below to `done`. A commit cannot name itself, so the next commit that
  touches the tracker fills in its hash.
- Statuses: `todo`, `blocked` (on a decision of Issue 60), `in progress`,
  `done`, `deferred`.
- A finished issue's durable facts go to the topic document that owns them.
  When every scheduled issue is done, fold what remains into the topic
  documents and delete this directory, as
  [`docs/README.md`](../../docs/README.md) asks of trackers.

## Baseline

At `ac8f507`, with Rust 1.82.0 and Lean 4.30.0-rc2: CI passes (run 225),
and on `c5422f9`, whose tree differs from it in one line of the previous
tracker, `scripts/run_validation.sh`, CI's probe steps, clippy and
`cargo test --workspace --all-features` pass. The acceptance gate accepts
the bundle, the 428 tamper scenarios are rejected, and the 99 files of
`results/reproducibility_manifest.json` match their sizes and digests. What
the gate does not check is R5 of the validation.

## Positions

| The review recommends | Position | Issues |
| --- | --- | --- |
| Make storage failures preserve a coherent transaction history (§2) | Agree. A failed append leaves the store serving calls, behind a torn frame or beside a commit the live runtime dropped. How an error ends a call is D8 | 65, 66 |
| Bind the committed history and the nonce reservations into recovery (§3) | Agree. A committed abort does not advance the checked counter, and a lowered reservation can repeat a nonce. The generation is to be built in any case; how reservations are protected is D9 | 67, 68 |
| Replace the vacuous receipt-authentication assumption (§4) | Agree. A Lean proof here shows that the assumptions make every receipt issued. The route is D10 | 64 |
| Make the matched baselines' coverage fail closed (§5) | Agree | 63 |
| Fix the false-path inspection and give the acceptance gate an evidence contract (§6) | Agree, and first. The second gap is wider than the review says: no result file a claim cites is checked to exist | 61, 62 |
| Qualify Issue 36, the planner's memory and optimality and the production receipt's cost; keep the observer explicit (§8) | Agree. Issue 36 is qualified in this response | 63, 69 |
| Close the rest, and start Issues 43 to 46 from a repaired baseline (§1, §7) | Agree | 69 |

## Decisions

Issue 60 has the options and the reasoning.

| Decision | Status | Outcome |
| --- | --- | --- |
| D8, what a storage error means for a call | decided 2026-11-16 | outcome unknown: a failed journal append poisons the store until the deployment restarts from its files, and the restarted deployment's last receipt says whether the call committed |
| D9, what a restart checks of the store's freshness | decided 2026-11-16 | authenticated reservations: each key's reserved count is in the tagged commit metadata, and every commit and every reservation advances a generation that the restart compares with the attested one |
| D10, the route of the receipt proof | decided 2026-11-16 | over an adversary's outputs: the MAC assumption speaks of the hash and tag pairs an adversary of the session can produce, with a non-vacuity model |

## Order of Work

1. **Wave 9, Issue 60: the decisions.** Done: the maintainer took the
   recommended option of each of D8 to D10 on 2026-11-16, which unblocks
   Issues 64 to 68.
2. **Wave 10, the gates that check the evidence: Issues 61, 62 and 63.**
   The review rates them below the guarantees, but every later repair is
   validated through them. A repair that a gate cannot fail proves less, so
   the gates come first. Issue 61 makes the false-path inspection see false
   leaves, Issue 62 gives the acceptance gate the inventory it lacks, and
   Issue 63 closes the hole in the matched baselines, with the planner
   tested under a budget.
3. **Wave 11, the guarantees: Issues 64 to 68.**
   - Issue 64, the receipt proof, is Lean and documents alone and can come
     first.
   - Issue 65 makes storage errors fail closed, and Issue 66 then moves the
     dropped call's reservation before the call and checks the seal bound.
   - Issue 67 adds the commit generation, and Issue 68 protects the
     reservations as D9 says.
   - Persistence comes before recovery, because the restart's checks rest
     on what a storage error leaves in the files.
4. **Wave 12, Issue 69: the repaired baseline.** The full capacity sweep
   and matched baselines are measured on the final commit of Wave 11, with
   what the repairs cost a call.

The research issues of the previous review (43 to 46) start from the
baseline of Issue 69. Issue 50 stays deferred.

## Tracker

| Issue | Title | Wave | Size | Depends on | Status | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 60 | Decide the storage-error contract, the recovery mechanism and the receipt proof's route | 9 | S | maintainer | done | `8f30524` |
| 61 | Make the false-path snapshot see false leaves, and classify them as the acceptance gate does | 10 | S | | done | `710a58d` |
| 62 | Give the acceptance gate an evidence contract | 10 | M | 61 | done | |
| 63 | Make the matched baselines' coverage fail closed, and test the planner under a budget | 10 | S | | todo | |
| 64 | State the receipt MAC assumption over what an adversary can produce, with a non-vacuity model | 11 | S to M | 60 (D10) | todo | |
| 65 | Fail closed on storage errors, and test every failure | 11 | M to L | 60 (D8) | todo | |
| 66 | Make a dropped call's restart point durable before the call runs, and bound a call's seals | 11 | M | 65 | todo | |
| 67 | Advance a commit generation with every committed call, and check it at restart | 11 | M | 60 (D9), 65 | todo | |
| 68 | Keep a restart from resuming a key below a count it has used | 11 | M | 66, 67 | todo | |
| 69 | Measure the repaired baseline | 12 | M | 61 to 68 | todo | |
