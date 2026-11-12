# External Review, November 2026

An external consultant reviewed the repository at commit `030ae9e`. This
directory holds the response.

| File | Content |
| --- | --- |
| [`validation.md`](./validation.md) | every factual claim of the review checked against the code, and a position on each recommendation |
| [`tasks.md`](./tasks.md) | Issues 22 to 52: description, fix and acceptance criteria |
| this file | the positions in brief, the order of work, and the tracker |

The review text is not in the repository; `validation.md` restates each
claim.

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

Issue 22 has the options and the reasoning.

| Decision | Status | Outcome |
| --- | --- | --- |
| D1, the unit the storage observer classifies | decided 2026-11-12 | the 32-byte word, as an EVM `SSTORE` classifies it; the unit size stays a parameter of the codec's Lean statement |
| D2, where private evidence may go | decided 2026-11-12 | position maps and leaf schedules do not leave the runtime: a production build exports no private evidence, and only the diagnostics build exports it, to the Lean checkers |
| D3, the lifetime budget of the stash bound | decided 2026-11-12 | a cap of 152: at most `2^-60` over `2^48` node accesses of a map |

## Order of Work

1. **Wave 0, decisions** (Issue 22). Done: the maintainer decided the
   observer unit, the evidence boundary and the stash budget.
2. **Wave 1, the confidentiality boundary** (Issues 23 to 26). A runtime
   that discloses its master secret undermines every other claim.
3. **Wave 2, measurement and claim wording** (Issues 27 to 29). Later
   savings need a fair baseline, and the wording fix costs nothing.
4. **Wave 3, structural savings and primitive hardening** (Issues 30 to
   35). Small changes whose savings follow from the schedule, each with a
   mechanical acceptance test.
5. **Wave 4, no work linear in the store** (Issues 36 to 38). Then rerun
   the sweep of Issue 27 and update the break-evens.
6. **Wave 5, theorem coverage** (Issues 39 and 40). Independent of Waves 3
   and 4; it can run beside them.
7. **Wave 6, evidence at a storage boundary** (Issues 41 and 42).

The research issues (43 to 46) start once the issues they depend on are
done. The backlog (47 to 52) is not scheduled.

This differs from the review's sequence in two ways. The measurement work
comes before the optimizations, not after. And incremental state is split:
its engineering part is Wave 4, its certified part is research.

## Tracker

| Issue | Title | Wave | Size | Depends on | Status | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 22 | Decide the observer unit, the evidence boundary and the stash budget | 0 | S | maintainer | done | `58bce68` |
| 23 | Stop returning the deployment seed to callers | 1 | S | | done | `72d3bfb` |
| 24 | Give the runtime an independent 256-bit master secret | 1 | M | 23 | done | `6b88d18` |
| 25 | Split a call's result into a public receipt and private evidence | 1 | M to L | 24 | done | |
| 26 | Have the runtime issue the proof binding | 1 | M | 25 | todo | |
| 27 | Measure occupancy, executed workloads and every cost | 2 | M | | todo | |
| 28 | Cover the private scheme in the leakage and abort reports | 2 | S | | todo | |
| 29 | State what the Path ORAM theorem's cryptographic assumptions mean | 2 | S | | todo | |
| 30 | Charge external reads in the modeled cost | 3 | S to M | | todo | |
| 31 | Do not rewrite statically read-only exact objects | 3 | M | 30 | todo | |
| 32 | Load each exact object once per call | 3 | M | 30 | todo | |
| 33 | Check each UO write's class against its bytes | 3 | S | | todo | |
| 34 | Make the confidential kernel's 256-bit arithmetic branch-free | 3 | M | | todo | |
| 35 | Match the record codec to the observer unit | 3 | M | | todo | |
| 36 | Remove the whole-store witness snapshots from a call | 4 | M | 25 | todo | |
| 37 | Stage a call without copying the store | 4 | M | | todo | |
| 38 | Compress scan schedules in traces and proof objects | 4 | M to L | 31, 32 | todo | |
| 39 | Admit encrypted returns in the kernel theorems | 5 | M | | todo | |
| 40 | Give the stash bound a lifetime budget and test deferred write-back | 5 | M | | todo | |
| 41 | Put storage behind an adapter that keeps its own I/O log | 6 | M to L | 24, 31, 32 | todo | |
| 42 | Widen the runtime-versus-model tests of the tree and the tape substitution | 6 | M | | todo | |
| 43 | Prove a store operation's post-state and its write class together | research | R | 33, 35 | todo | |
| 44 | Certify state transitions incrementally | research | R | 36, 37, 41 | todo | |
| 45 | State security over call histories with a quantified bound | research | R | 24, 39, 40 | todo | |
| 46 | Prove that the runtime's run on every tape is the substituted run | research | R | 42 | todo | |
| 47 | Try an oblivious routing network for tree eviction | backlog | M | 27 | todo | |
| 48 | Fuse scans and generalize the reuse analysis | backlog | M | 31, 32 | todo | |
| 49 | Write the related-work boundary and add matched baselines | backlog | M | 27 | todo | |
| 50 | Bridge a scoped subset to Solidity 0.8 semantics | backlog | L | | deferred | |
| 51 | Remove the generator that a seal no longer reads | backlog | S to M | 24 | todo | |
| 52 | Make the seal count of a dropped call a function of its entrypoint | backlog | M | 24 | todo | |

Sizes are relative, not a schedule: S a day or less, M several days, L one
to two weeks, R research with no fixed end.
