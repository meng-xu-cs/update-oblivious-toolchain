# Tasks from the November 2026 External Review

These are the tasks that follow from
[`validation.md`](./validation.md). Their order, dependencies and status are in
[`README.md`](./README.md).

Issue numbers continue [`review/runbook.md`](../runbook.md), which holds
Issues 01 to 21. That runbook's definition of done applies: implementation,
focused Rust tests or Lean theorems, regenerated artifacts, a probe report bit
where a claim or the evaluation is affected, documents changed only to match
the code, and a passing validation slice. Follow
[`docs/coding-agent-conventions.md`](../../docs/coding-agent-conventions.md):
a change to the runtime, `uo-core` or the Lean sources changes every artifact
identity, so regenerate with `scripts/run_validation.sh` in the same change.

Each issue names its source (a finding `F1` to `F9` of the validation and the
review section), a size, and what it depends on. Sizes are relative, not a
schedule: **S** a day or less, **M** several days, **L** one to two weeks,
**R** research with no fixed end.

---

## Wave 0: decisions

### Issue 22 — Decide the observer unit, the evidence boundary and the stash budget

Source: F1, F6, F7 (§3, §7, §8). Size: S. Depends on: the maintainer.

#### Issue description

Three later issues cannot be designed without a decision that the code does
not determine. The Decisions table of [`README.md`](./README.md) holds their
status.

**D1, the unit the storage observer classifies.** Blocked Issue 35. Decided
on 2026-11-12: the 32-byte word. A write is `Update` when the unit was
nonzero, is nonzero, and changed. A guarantee for a small unit implies it for
every larger one, and costs more bytes.

| | Record | 32-byte word | Byte |
| --- | --- | --- | --- |
| The host it models | stores and prices whole sealed records | stores and prices 32-byte slots, as an EVM `SSTORE` does | inspects stored bytes one by one |
| It also covers | | the record | the word and the record |
| Encoding | none | one marker byte per word | seven bits per byte |
| `uint256` value (124 bytes, 4 words today) | 62 bytes | 64 bytes, 2 words | 71 bytes, 3 words |
| Map record (190 bytes, 6 words today) | 95 bytes | 96 bytes, 3 words | 109 bytes, 4 words |
| Proof | smallest | small, with the unit size a parameter | bit packing, the largest |

The word figures let the marker replace the magic prefix. In each column the
encoding can make `Update` certain instead of overwhelmingly likely: a tag or
marker that is nonzero and differs from the one it replaces, or for the byte
two disjoint alphabets used in turn. Today's nibble encoding makes every byte
nonzero, but a byte repeats with probability 1/16 and the four bytes of the
encoded magic prefix never change. So what it delivers is the word level (no
word is zero, and a word repeats with negligible probability), at twice the
bytes a marker needs. The decision takes the 32-byte word and keeps the unit
size a parameter of the codec's Lean statement.

**D2, where private evidence may go.** Blocked Issue 26. Decided on
2026-11-12: position maps and leaf schedules do not leave the runtime. A
production build exports no private evidence. The diagnostics build, which
the production policy rejects, still exports it to the Lean checkers.

**D3, the lifetime budget of the stash bound.** Blocked Issue 40. Decided on
2026-11-12: a cap of 152. With `R` the stash cap, an access overflows with
probability at most `14 · 0.6002^R`. For a total of `2^-λ` over `Q` node
accesses of one map, `R ≥ (λ + log2 Q + 3.81) / 0.7365`. An ERC20Lite
`transfer` at 16,384 entries makes 154 node accesses, so `2^40` of them is
about 7 billion transfers.

| Cap | Per access | Over `2^40` | Over `2^48` | Extra work per node access |
| --- | --- | --- | --- | --- |
| 114 (today) | `2^-80` | `2^-40` | `2^-32` | |
| 147 | `2^-104` | `2^-64` | `2^-56` | about 13% |
| 152 | `2^-108` | `2^-68` | `2^-60` | about 15% |
| 179 | `2^-128` | `2^-88` | `2^-80` | about 26% |

The extra work is at 16,384 entries, estimated from the loop bounds of
eviction and compaction, which are linear in the stash and are 86% of a node
access's instructions; it is not measured. A stash page holds 8 blocks and is
read and written once per operation, so a read moves about 2% more bytes at
152. A cap of 128 or more gives every local-scheme map a stash as large as
itself, so the local scheme needs no stash assumption. The decision takes
152, stated as at most `2^-60` over `2^48` node accesses of a map, with the
overflow handling of Issue 40.

#### How to fix

Record each decision in the Decisions table of `README.md` when it is made.
The topic documents describe what the code does, so a decision reaches them
with the issue that implements it: D1 with Issue 35
(`docs/claim-boundary.md`, Observer; `docs/runtime/tee-observer.md`,
Persistent-I/O Model), D2 with Issues 25 and 26
(`docs/runtime/secret-state.md`), D3 with Issue 40 (`docs/path-oram.md`,
Assumption Provenance).

#### Acceptance criteria

- The three decisions are in the Decisions table.
- The tracker no longer shows Issues 26, 35 and 40 as blocked.

---

## Wave 1: the confidentiality boundary

### Issue 23 — Stop returning the deployment seed to callers

Source: F1 items 3 and 8 (§3). Size: S. Depends on: nothing.

#### Issue description

One rejected production call returns the deployment seed in its error text.
Every serialized trace carries it as `runtime_seed`. The tests of the
production call path do not run in CI. This issue is a stopgap: the seed
stays the root of every key until Issue 24.

#### How to fix

1. `validate_production_call_preflight` (`runtime/uo-evm/src/deployment.rs`)
   reports a freshness mismatch without the runtime's values. The rule for
   every error of the production path: name the field, never print a
   runtime-side value.
2. A build without `diagnostics` puts no seed in its results:
   `finalize_call_trace` (`runtime/uo-evm/src/theorem.rs`) passes the seed
   only under `cfg(any(test, feature = "diagnostics"))`. There
   `ExecutionTrace.runtime_seed` and `RuntimeTrustedKernelBundle.runtime_seed`
   remain the replay tag that the seeded-family checkers read
   (`RuntimeCoinsJson.lean`).
3. Run the production-path tests: add `cargo test -p uo-evm` to
   `.github/workflows/ci.yml`, `scripts/baseline.sh` and
   `scripts/run_validation.sh`.
4. Add two tests on default features. A deployment made by
   `ProductionContractInstance::deploy` rejects evidence with a wrong epoch,
   and the error contains no number except the evidence's own. The JSON of a
   trace has no `runtime_seed`.

#### Acceptance criteria

- Both tests pass, and CI runs them.
- A static-drift check rejects an error message that formats a field of
  `RuntimeFreshnessSnapshot`.
- The seeded-family reports of the diagnostics build are unchanged; results
  regenerate.
- `docs/runtime/secret-state.md` lists the deployment seed as secret state.

### Issue 24 — Give the runtime an independent 256-bit master secret

Source: F1 items 1, 2 and 7 (§3). Size: M. Depends on: Issue 23.

#### Issue description

One `u64` is the freshness epoch and the root of every storage key, nonce
stream and ORAM coin. Keys have at most 64 bits of entropy. A dropped staged
call rewinds the nonce stream. And the nonces are 96 pseudo-random bits, so
under one key they collide with probability about `q²/2^97` after `q` seals:
`2^-33` at `2^32` seals, which a private-scheme map of 16,384 entries reaches
after about 1.7 million ERC20Lite transfers (2,556 seals each), and `2^-17`
at `2^40`. In a lifetime bound this term is far larger than the stash's.

#### How to fix

1. Add `RuntimeMasterSecret`: 32 bytes from the OS, zeroized on drop, with no
   `Clone`, no `Serialize` and no `Debug` of its contents. A constructor from
   a `u64` exists only under `cfg(any(test, feature = "diagnostics"))`, for
   replay.
2. Derive from it, with a keyed derivation function and one label per use:
   each object's AEAD key, the initial ORAM placement, and each ORAM map's
   leaf-coin key (in place of `leaf_coin_seed: u64`). No production path
   uses `seed_from_u64` for key material.
3. Draw the freshness epoch independently. It is public.
4. Make nonces unique by construction. A record's nonce is an injective
   encoding of its location and of a write counter in committed state: not
   random bits, and not a hash of the two, which would collide like random
   bits. It then cannot repeat and cannot rewind. The invariant: of the
   ciphertexts that leave the runtime, no two under one key share a nonce.
   The counter is a function of the public write schedule, so it reveals
   nothing more.
5. Update `crates/uo-core/src/observer_coverage.rs`, the lists in
   `proof/lean/UOToolchain/ObserverCoverage.lean`, and
   `docs/runtime/secret-state.md`. Add the derivation function's assumption
   to the assumption table of `docs/claim-boundary.md`, and so to the claim
   manifest.

#### Acceptance criteria

- Two deployments differ in their epoch and in every derived key, and no
  derived value equals a field of `ProductionCallEvidence`, of a result, or
  of an error.
- After a staged call is dropped, the next committed call's nonces differ
  from the dropped call's. Today they are equal.
- No two records sealed under one key carry the same nonce, by a test that
  checks the encoding is injective and a Lean statement of the invariant.
- Seeded diagnostics runs stay deterministic: `fresh_coin_validation`,
  `seeded_witness_validation` and the canonical pair reports regenerate and
  pass, and the tamper suite passes.

### Issue 25 — Split a call's result into a public receipt and private evidence

Source: F1 items 3 to 5 (§3). Size: M to L. Depends on: Issue 24.

#### Issue description

`ExecutionTrace` holds what the observer sees and what must stay hidden, in
one serializable type that every call returns.

#### How to fix

1. In `crates/uo-core/src/trace.rs`, split it into `PublicReceipt` (opcode
   trace, logical and physical events, modeled gas, theorem trace,
   public-state transition, trace hashes) and `PrivateEvidence` (the replay
   tag, ORAM objects, leaf schedule, access counters, position maps, leaf
   transitions, and any kernel-witness field that holds hidden state).
2. Take the split from `observer_coverage.rs`: a field classified
   `CryptographicallyHidden` appears only in `PrivateEvidence`. A unit test
   enforces it.
3. `PrivateEvidence` implements `Serialize` only in a diagnostics build.
   `CallResult` carries the receipt and, in a diagnostics build, the
   evidence.
4. The probe and the CLI's proof-object formats build their bundles from
   both. The Lean JSON importers keep their formats.

#### Acceptance criteria

- In a default build, no type that can reach a caller has a
  `CryptographicallyHidden` field. A probe static check covers it, with a
  tamper scenario that moves a position map into the receipt.
- Every Lean-backed validator accepts the diagnostics-build bundles; results
  regenerate.
- `docs/runtime/secret-state.md` and `docs/runtime/trusted-kernel.md`
  describe the two types.

### Issue 26 — Have the runtime issue the proof binding

Source: F1 item 6 (§3). Size: M. Depends on: Issue 25.

#### Issue description

A production call is accepted only if the caller supplies
`proof_bundle_sha256`, the hash of the bundle the call will produce. Computing
it takes the deployment seed and the secret arguments. A deployment made with
`ProductionContractInstance::deploy` therefore cannot accept a call.

#### How to fix

1. `ProductionCallEvidence` keeps what a caller can know: package identity,
   toolchain digest, binary, proof-root and quote hashes, build profile,
   public environment, session binding, counters and the translation
   certificate. Remove `proof_bundle_sha256`.
2. `call_authorized` returns a `ProductionReceipt`: the hash of the request
   evidence, the hash of the previous receipt, state commitments before and
   after the call (the public-state digest and a digest of the ciphertext
   store), the hash of the public receipt, and the counters after the call.
3. By D2, a production build keeps the private evidence inside the runtime
   and drops it when the call ends. The receipt carries nothing derived from
   it. The Lean checkers run on diagnostics builds, as they do now.
4. `DeploymentCallAccepted` in `DeploymentAcceptance.lean` binds the receipt
   fields. Add a tamper scenario for each.
5. Say in `docs/claim-boundary.md` (Deployment Theorem) what a production
   result then rests on: the attested binary, the theorems about the model,
   and the diagnostics-build validation of that binary's source. No
   per-call proof object leaves a production runtime.

#### Acceptance criteria

- A deployment made with `ProductionContractInstance::deploy` accepts a call
  from public evidence alone, with no second instance and no seed, in a test
  that CI runs.
- Receipts chain: a replayed or reordered receipt, or a changed bound field,
  is rejected.
- The atomicity and rollback tests of Issue 06 pass on the new path.

---

## Wave 2: measurement and claim wording

### Issue 27 — Measure occupancy, executed workloads and every cost

Source: F2, F8 (§2, §9). Size: M. Depends on: nothing.

#### Issue description

The capacity sweep stores at most two keys, runs three trials without warmup,
computes its read/write mixes, and times a call without Lean checking or
serialization. Later issues claim savings, and those need a fair baseline.

#### How to fix

In `run_capacity_sweep` and `measure_sweep_operations`
(`probe/mplus-probe/src/lib.rs`), as schema v4:

1. Occupancy: fill each map to 2 keys and to 25%, 50%, 90% and 100% of its
   capacity, with keys from a fixed seed. Fill through a diagnostics-only
   bulk loader: a put through an instrumented call takes about 0.7 s at
   16,384 entries today.
2. Workloads: execute sequences of reads, inserts, overwrites, deletes,
   no-op writes and aborts at each read fraction, and report their measured
   latency. Keep the computed mixes for the counts, which the schedule fixes.
3. Repetition: by default at least 5 warmups and 30 trials; report the
   median, the 95th percentile and a 95% bootstrap interval.
4. Per call, split out the staging clone, the witness snapshots, the
   runtime's own work, the proof objects, JSON serialization, Lean checking
   of a sampled call, peak resident memory and evidence bytes.
5. Report the untraced work beside the traced counts: call-start reads and
   witness-scan decryptions.

#### Acceptance criteria

- `results/capacity_sweep.json` has occupancy and executed-mix rows with
  intervals, and its counts repeat exactly between runs.
- `docs/path-oram.md` and `docs/evaluation.md` state the occupancy and trial
  counts.
- The figures from before any optimization are committed as the baseline for
  Issues 30 to 38.

### Issue 28 — Cover the private scheme in the leakage and abort reports

Source: F8 (§9). Size: S. Depends on: nothing.

#### Issue description

`leakage_auc.json`, `mutual_information.json` and `abort_rollback.json` have
no private-scheme row. The description in `abort_rollback.json` says the Path
ORAM route rejects a mid-call abort; it runs them.

#### How to fix

Add private-scheme variants (ERC20Lite's `private-posmap` sidecar and a
ConfidentialMixer one) to the leakage and abort scenario lists in the probe,
and correct the description string (`probe/mplus-probe/src/lib.rs:49771`).

#### Acceptance criteria

- The three reports have private-scheme rows, classified as computational in
  the acceptance aggregate.
- The description matches what the cases do.

### Issue 29 — State what the Path ORAM theorem's cryptographic assumptions mean

Source: F6 (§7). Size: S. Depends on: nothing.

#### Issue description

`bucketEncryptionINDCPA`, `metadataEncryptionINDCPA` and
`stashOverflowBounded` are `Prop` fields that the checkers instantiate with
`True`. The documents call them explicit Lean assumptions without saying that
no Lean theorem depends on their content.

#### How to fix

In `docs/claim-boundary.md` (Explicit Assumptions) and `docs/path-oram.md`,
say what Lean proves (the leaf schedule is uniform; the two sides' storage
has equal locations and shapes), that the three assumptions are named and
not formalized, and that the step to indistinguishability is an argument on
paper with the bound
`ε(Q) ≤ ε_PRF + ε_AEAD + ε_nonce + Q · ε_stash`, each term defined and `Q`
counting primitive accesses. Update the matching rows of the claim manifest
(`probe/mplus-probe/src/claim_manifest.rs`).

#### Acceptance criteria

- `--only claim-status` and `--only claim-consistency` pass.
- The wording uses the claim-discipline terms of
  `docs/coding-agent-conventions.md`.

---

## Wave 3: structural savings and primitive hardening

### Issue 30 — Charge external reads in the modeled cost

Source: F4 (§5). Size: S to M. Depends on: nothing.

#### Issue description

The modeled cost is
`2000 + 11·statements + 7·expressions + 29·max_commit_ops`. Reads are free.
Once Issue 31 removes the rewrite of read-only objects, a scan of any size
would cost about 2,000 units.

#### How to fix

Add `max_load_ops` to `EntrypointManifest`: the external record reads of a
call (the slots of each exact object it loads; the path, metadata and
call-start reads of each ORAM access). The cost becomes
`2000 + 11·statements + 7·expressions + r·max_load_ops + 29·max_commit_ops`,
with `r` chosen and justified in `docs/claim-boundary.md`. Name the model
`uo-modeled-resource-cost-v2`. Mirror it in `uo-check` and in the Lean
translation checker.

#### Acceptance criteria

- The cost-formula exactness report passes for every benchmark.
- `overheads.json` and `capacity_sweep.json` record model v2, and the gas
  break-evens in `docs/path-oram.md` are recomputed.

### Issue 31 — Do not rewrite statically read-only exact objects

Source: F4 (§5). Size: M. Depends on: Issue 30.

#### Issue description

Commit rewrites every exact object a call touched, including those it only
read. A full-scan read of `N` entries makes `N` reads and `N` writes.

#### How to fix

1. Lean (`KernelExactTrace.lean`): `exactEncodeRun` writes only the objects
   with a write access. `admittedKernel_exactUO` holds for any encoder, so it
   stands. Keep `exactEncodeRun_writes_update` and add that a program without
   a write access to an object produces no write of it.
2. Compiler: each entrypoint's manifest lists `may_write_objects`, every
   object with a write statement in the linearized body, predicated or not.
   `max_commit_ops` sums over them. `uo-check` and the Lean translation
   checker recompute the list.
3. Runtime: the generated commit helpers
   (`GenerateRuntimeObjectHelpersRust.lean`) reseal an object only if the
   slot program may write it, and otherwise restore it without a write event.
   The decision comes from the program, not from the `written` and `dirty`
   flags.
4. An aborted call still rewrites its may-write objects.
5. Probe: `exact_encoding_matches` uses the new encoder. Two tamper
   scenarios: a manifest that omits a written object from the list, and one
   that lists a read-only object.

#### Acceptance criteria

- A full-scan `read(bytes32)` of `N` entries traces `N` reads and no write.
- Exact trace equality holds for every benchmark pair; kernel admission is
  unchanged; both tamper scenarios are rejected.
- `docs/claim-boundary.md` (Backend Scope) and `docs/engineering-note.md`
  describe the new rule. Results regenerate.

### Issue 32 — Load each exact object once per call

Source: F4 (§5). Size: M. Depends on: Issue 30.

#### Issue description

A full-scan map is decrypted once per call, and each access records another
`N` physical reads against the decrypted copy. The trace is a modeled
schedule that overstates the reads of a multi-access call.

#### How to fix

In `exactEncodeRun`, read each touched object once, in object-id order. In
the runtime, record the physical scan when the call loads the object
(`clone_for_tx`), not in `record_small_map_scan`; keep the logical event of
each access. `max_load_ops` counts each object once.

#### Acceptance criteria

- ERC20Lite `transfer` on the full scan reads `balances` once, not once per
  access.
- The traced reads of an exact-backend call equal the decryptions it
  performs, which Issue 41 will check at a storage boundary.
- Exact trace equality holds; results regenerate.

### Issue 33 — Check each UO write's class against its bytes

Source: F5 (§6). Size: S. Depends on: nothing.

#### Issue description

A UO write event is labeled `Update` by assertion
(`PhysicalWriteEvent::from_shape`). The label holds when no encoded unit is
zero and the nonce is fresh, and neither is checked where the event is made.

#### How to fix

In the generated helpers that record UO writes
(`reseal_payload_and_trace_write`, the ORAM write log, the store helpers),
classify the old and the new encoded bytes with `classify_write` and fail the
call with an internal error unless the class is `Update`. Change the Lean
generators, not the generated files.

#### Acceptance criteria

- A test that forces a repeated nonce sees the failure.
- A static-drift check rejects a production path that builds a UO write
  event without the check; a report bit records it.
- No trace changes.

### Issue 34 — Make the confidential kernel's 256-bit arithmetic branch-free

Source: F5 (§6). Size: M. Depends on: nothing.

#### Issue description

`wrapping_sub`, `div_rem`, the comparisons, equality and the boolean
operators branch on secret operands in the confidential kernel.

#### How to fix

1. In `crates/uo-core/src/types.rs`: subtraction by a borrow chain;
   less-than from the borrow of a subtraction; equality by folding the XOR
   of the limbs; `is_zero` by folding their OR; division as 256 rounds of
   restoring division with a masked subtraction, a zero divisor handled by a
   mask. Keep the present implementations under `cfg(test)` as the reference
   of a differential test.
2. In the Lean generator of `eval_confidential_kernel_binary_generated`, use
   those operations for `Eq`, `Neq`, the four comparisons, `Div` and `Mod`,
   and `&` and `|` for `And` and `Or`.
3. Evidence, by a script like
   `scripts/measure_tree_eviction_instructions.sh`: under callgrind, the
   instruction count of each operation is the same for every operand class
   (zero and nonzero divisor, borrow and no borrow, equal and unequal high
   limbs).

#### Acceptance criteria

- A committed report shows equal instruction counts per operation in a
  release build, and repeats.
- The differential test agrees on random and edge operands;
  `correctness.json` is unchanged.
- A static-drift check rejects a branch or an early return on operand data
  in those operations.
- `docs/claim-boundary.md` records this as instruction-count evidence at the
  source and callgrind level, not a machine-code claim.

### Issue 35 — Match the record codec to the observer unit

Source: F7 (§8). Size: M. Depends on: nothing (D1 chose the 32-byte word).

#### Issue description

Every sealed byte is stored as two nonzero nibble bytes. How much encoding
the claim needs depends on the observer unit.

#### How to fix

D1 chose the 32-byte word (Issue 22 has the comparison):

| Unit | Encoding | Value | Map record |
| --- | --- | --- | --- |
| record | the sealed bytes with a tag | 62 bytes | 95 bytes |
| 32-byte word | one marker byte per word, in place of the magic prefix | 64 bytes, 2 words | 96 bytes, 3 words |
| byte | seven bits per byte | 71 bytes | 109 bytes |

Today a value takes 124 bytes (4 words) and a map record 190 (6 words).

Make `Update` certain, not only overwhelmingly likely: the tag or marker of
a unit is nonzero and differs from the one it replaces (two values used in
turn; every UO write path holds the old record). A unit is then never zero
and never unchanged, whatever its ciphertext bytes are. The marker is the
parity of the unit's write count, which the public schedule fixes.

Change `RuntimeStoreCodecSemantics.lean` (round trip, fixed public length,
every unit nonzero, every unit different from its predecessor), its
generator, the ORAM bucket and page codecs, and the sizes in the manifests
and resource bounds. Keep the unit size a parameter of the Lean statement.

#### Acceptance criteria

- The Lean codec theorems hold for the chosen unit, and decoding rejects a
  record with a zero unit (a tamper scenario).
- The check of Issue 33 classifies every unit of every UO write as `Update`.
- `exact_encoding_matches` holds; results regenerate; the byte figures in
  `docs/path-oram.md` are updated.

---

## Wave 4: no work linear in the store

After this wave, and after Wave 3, rerun the sweep of Issue 27 and update the
break-evens in `docs/path-oram.md`.

### Issue 36 — Remove the whole-store witness snapshots from a call

Source: F3 (§4). Size: M. Depends on: Issue 25.

#### Issue description

A call decrypts every bucket of every private-scheme map twice to export
position-map witnesses: 447 of the 541 ms of a tree read at 16,384 entries.

#### How to fix

1. A call that exports no evidence builds no witness.
2. With evidence, the snapshot before a call is the snapshot after the
   previous one, kept with the committed runtime.
3. Maintain a tree's position-map witness from the call's access
   transcripts: only the nodes it read change leaf. Keep
   `tree_position_map_witness_leaves` as the reference of a test.
4. Snapshot only the ORAM objects of the entrypoint.

#### Acceptance criteria

- `p50_witness_ns` at 16,384 entries no longer grows with the capacity.
- In tests the maintained witness equals the full decode after every call.
- The Lean witness checkers accept the bundles; results regenerate.

### Issue 37 — Stage a call without copying the store

Source: F3 (§4). Size: M. Depends on: nothing.

#### Issue description

Staging deep-copies every committed object, ciphertext included, and loading
a touched ORAM map copies its storage again.

#### How to fix

Share ciphertext pages between the committed and the staged state
(reference-counted pages, or a persistent vector). A write replaces a page
pointer. Decrypted shadows stay owned and wiped on drop. Keep the cold-state
checks.

#### Acceptance criteria

- The staging time of Issue 27's breakdown does not grow with the capacity
  of untouched objects, and a call's peak memory is no longer twice the
  store.
- The atomicity and rollback tests pass.

### Issue 38 — Compress scan schedules in traces and proof objects

Source: F2, F3 (§2, §4). Size: M to L. Depends on: Issues 31 and 32.

#### Issue description

A full-scan call at 16,384 entries emits 32,768 events, 20.7 MB of JSON, and
spends 330 of 417 ms building proof bundles from them.

#### How to fix

Record a scan or a rewrite of an exact object as one schedule event (object,
slot count, record length). Lean expands it with
`ExactObjectLayout.scanReads` and `updateWrites`. Hash-bind the expanded
form. The Lean importers accept the compressed form.

#### Acceptance criteria

- The trace of an exact-backend call grows with the number of objects, not
  slots.
- `p50_proof_objects_ns` of the full scan no longer grows with the capacity.
- A tamper scenario that changes a slot count or a length is rejected.

---

## Wave 5: theorem coverage

### Issue 39 — Admit encrypted returns in the kernel theorems

Source: F6 (§7). Size: M. Depends on: nothing.

#### Issue description

`PolicyAgreesWithFlow.notEncrypted` keeps `encrypted_to_client` entrypoints
out of the admitted-kernel theorems, and no benchmark uses one. Every
benchmark that returns a secret-derived value releases it to the host.

#### How to fix

1. In `KernelPaperMain.lean`, drop `notEncrypted`: a secret return needs
   `declassified` or `encrypted_to_client`. Model the encrypted outcome: the
   ciphertext and tag are released; the lengths, nonce, AAD hash and session
   binding are equal on both sides. Do the same in
   `PathOramKernelPaperMain.lean` and `KernelAdmission.lean`.
2. Add a benchmark entrypoint with `returns: encrypted_to_client`.
3. Add the return channel's AEAD assumption to the assumption table of
   `docs/claim-boundary.md`.

#### Acceptance criteria

- The new entrypoint is admitted (`kernel_admission_*` in
  `results/static_checks.json`) and covered by
  `paperMain_admittedKernelRun_exact_noninterference_moduloReleases`.
- `outcome_model_matches` holds for its runs.

### Issue 40 — Give the stash bound a lifetime budget and test deferred write-back

Source: F6 (§7). Size: M. Depends on: nothing (D3 chose a cap of 152).

#### Issue description

The stash bound is stated per access, with no lifetime. That it holds while
a tree operation keeps up to `3h + 1` nodes out of the tree is assumed.

An overflow also loses data. A block that finds no room in the stash is
dropped (`TreeStash::compact` and `push_fixed_stash_with_limit` in
`runtime/uo-evm/src/generated_oram_codecs.rs`), the access reports a failure,
the call aborts, and the map commits as the call left it, because an aborted
call keeps its ORAM accesses (`RuntimeObject::commit`,
`runtime/uo-evm/src/objects.rs`). On the private scheme the lost block is a
tree node, and its subtree is no longer reachable.

#### How to fix

1. In `docs/path-oram.md`, state the per-access bound, the union bound over
   `Q` node accesses of a map, and the budget of D3. Set
   `PATH_ORAM_STASH_BOUND_LIMIT` and its Lean counterpart from it, and state
   that a map no larger than the cap needs no stash assumption.
2. Make an overflow lose nothing. The access fails with an internal error
   before its state can commit, so the staged call is dropped and the
   committed map stays whole. A map whose stash is full then refuses calls
   and can be rebuilt; it is not corrupted. A dropped call does not remap
   the keys it read, which `docs/path-oram.md` rules out for ordinary
   aborts; here it happens only with the overflow's probability, and the
   bound of Issue 29 already counts that event.
3. Add `--only stash-occupancy`: at least `10^7` node accesses of the
   private scheme at several capacities, under random, repeated-key and
   insert-and-delete workloads, with a simulator that shares the eviction
   code and skips the cryptography. Record the largest stash and the tail of
   its distribution, during an operation and between operations.
4. Say exactly what remains assumed.

#### Acceptance criteria

- A test forces an overflow with a small stash: the call fails, the
  committed map is unchanged, and every key is still readable.
- `results/stash_occupancy.json` is committed and indexed in
  `docs/evaluation.md`.
- The largest stash observed is compared with the cap plus `3h + 1`. An
  occupancy that the bound does not predict blocks the claim.
- The capacity sweep of Issue 27 reports the cost of the new cap.

---

## Wave 6: evidence at a storage boundary

### Issue 41 — Put storage behind an adapter that keeps its own I/O log

Source: F4, F8 (§5, §9). Size: M to L. Depends on: Issues 24, 31 and 32.

#### Issue description

Storage is process memory, and the trace is written by the code that
performs the access. Nothing independent says what crosses a storage
boundary.

#### How to fix

Add a `StorageAdapter` trait to `uo-store` with an in-memory and a
file-backed implementation. The adapter logs each read and write (location,
length, and the class of each write from its old and new bytes). The runtime
loads and commits through it. A probe report compares the adapter's log with
the trace and counts untraced I/O separately. Measure persistence and a cold
restart from files with a freshness snapshot.

#### Acceptance criteria

- `results/storage_boundary.json`: for every benchmark the adapter's log
  equals the traced schedule, and every write the adapter classifies is
  `Update`.
- No ciphertext reaches the adapter before the state that fixes its nonce is
  durable (Issue 24).
- A restart test passes; the latencies of Issue 27 include persistence.

### Issue 42 — Widen the runtime-versus-model tests of the tree and the tape substitution

Source: F5 (§6). Size: M. Depends on: nothing.

#### Issue description

Four extra runs per side test that a runtime run on any tape is the
substituted run. The AVL replay covers 2,400 operations on maps of at most
31 nodes.

#### How to fix

Sweep hundreds of seeds, several capacities and random workloads with
deletes and aborts in the full validation, and a subset in CI. Replay the
AVL map on trees of at least 1,024 nodes, and check after every operation
that the free list is acyclic, each node is stored once and every stored
leaf is the one its parent holds.

#### Acceptance criteria

- The reports state their counts, and a divergence fails closed.
- The documents say "tested over N tapes"; nothing is promoted to "proved".

---

## Research issues

These are tracked, not scheduled. Each needs a design note before work
starts.

### Issue 43 — Prove a store operation's post-state and its write class together

Source: F5 (§6). Size: R. Depends on: Issues 33 and 35.

A Lean model of a sealed-slot write that establishes the logical post-state
and the class of the physical write, with the nonzero-unit and freshness
obligations explicit, and a generator-level correspondence to the Rust
helper. Done when the exact store's `Update` claim cites a theorem and not a
runtime check.

### Issue 44 — Certify state transitions incrementally

Source: F3 (§4). Size: R. Depends on: Issues 36, 37 and 41.

An authenticated ciphertext store (a commitment over pages, never over
plaintext), an initial state certificate, per-call certificates over the
accessed paths with a public size and schedule, a Lean frame theorem for
untouched objects, and the chained receipts of Issue 26. Done when a call's
certificate construction and checking grow with its accessed paths, with
verification inside the measured latency.

### Issue 45 — State security over call histories with a quantified bound

Source: F6 (§7). Size: R. Depends on: Issues 24, 39 and 40.

A history theorem whose model carries the private store, ORAM state, keys
and freshness through randomized transitions; whose transcript holds the
released values; and whose conclusion is a simulator with a bound in the
terms of Issue 29. Done when the single-call theorems are instances of it.

### Issue 46 — Prove that the runtime's run on every tape is the substituted run

Source: F5 (§6). Size: R. Depends on: Issue 42.

The statement that `PathOramTapeWitness` assumes of the Rust runtime. Done
when the tape-family theorem needs no sampled runs.

---

## Backlog

### Issue 47 — Try an oblivious routing network for tree eviction

Source: F7 (§8). Size: M. Depends on: Issue 27.

Eviction and compaction are 86% of a node access's instructions, in about
33,000 masked node assignments. Compute the placement on small tags and move
each payload once. Accept only with unchanged block placement and a measured
gain.

### Issue 48 — Fuse scans and generalize the reuse analysis

Source: F4 (§5). Size: M. Depends on: Issues 31 and 32.

After Issue 32 a call loads an exact object once. What remains of the
review's optimizer: one checked operation for a read followed by an update of
the same key, and a version-aware analysis that generalizes
`uo_core::presence_reuse` to any fact that survives the writes between two
accesses. Each transformation is accepted only with a Lean statement that
the optimized schedule is still a function of the program.

### Issue 49 — Write the related-work boundary and add matched baselines

Source: F9 (§9, §10). Size: M. Depends on: Issue 27.

A short section in `docs/claim-boundary.md` on what is not claimed as new
(ciphertext side-channel defenses, oblivious data structures, enclave
oblivious maps), then baselines matched in key and value sizes, occupancy and
enclave memory. A backend and schedule planner that reads only public
parameters follows from the baselines.

### Issue 50 — Bridge a scoped subset to Solidity 0.8 semantics

Source: F5 (§6). Size: L. Deferred.

The Lean target is `VersionedSoliditySemanticsBridge`. It helps adoption and
changes no current claim.
