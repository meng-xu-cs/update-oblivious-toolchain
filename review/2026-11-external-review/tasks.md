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
access's instructions; it was not measured then. Issue 40 measured it: 15% to
17% of a tree call's own work at 16,384 entries (see Wave 5). A stash page
holds 8 blocks and is read and written once per operation, so a read moves
about 2% more bytes at 152. A cap of 128 or more gives every local-scheme map
a stash as large as itself, so the local scheme needs no stash assumption. The
decision takes 152, stated as at most `2^-60` over `2^48` node accesses of a
map, with the overflow handling of Issue 40.

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
4. Make nonces unique by construction. A record's nonce is the count of
   the seals made under its key before it, as bytes: not random bits, and
   not a hash of a counter, which would collide like random bits. The count
   is kept with the key, and every copy of the cipher shares it, so a staged
   call counts in the committed state's sequence and dropping the call
   cannot rewind it. The invariant: no two records sealed under one key
   share a nonce. After deployment every seal is one recorded storage write,
   so on an error-free run the count is a function of the storage trace and
   reveals nothing more.

   The first draft of this item kept the counter in committed state. A
   dropped call would then have used its nonces again, which the second
   acceptance criterion rules out. What the count shows after a call is
   dropped on an error is Issue 52.
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
2. Take the split from `observer_coverage.rs`: a field of the trace
   classified `CryptographicallyHidden` appears only in `PrivateEvidence`. A
   unit test enforces it. The receipt still holds the bytes of an encrypted
   return, which carry that class and which the caller is meant to receive;
   the test names them as the only such fields a receipt holds.
3. `PrivateEvidence` implements `Serialize` only in a test or diagnostics
   build. `CallResult` carries the receipt and, in such a build, the whole
   trace.
4. The probe and the CLI's proof-object formats build their bundles from
   the whole trace, `ExecutionTrace`, which holds both. Its JSON is the
   receipt's fields and then the evidence's, so the Lean JSON importers keep
   their formats. The CLI prints the receipt in a default build and has the
   trace and proof-object formats only in a diagnostics build.

#### Acceptance criteria

- In a default build, no type that can reach a caller has a field of the
  trace classified `CryptographicallyHidden`. A probe static check covers
  it, with a tamper scenario that moves a position map into the receipt.
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
   certificate. Remove `proof_bundle_sha256`. In its place the evidence
   names the receipt the call follows, by hash.
2. `call_authorized` returns a `ProductionReceipt`: the hash of the request
   evidence, the hash of the previous receipt, state commitments before and
   after the call (the public-state digest and a digest of the ciphertext
   store), the hash of the public receipt, and the counters after the call.
   A deployment issues the first receipt of its chain, which gives a caller
   the epoch and the counters for its first call.
3. By D2, a production build keeps the private evidence inside the runtime
   and drops it when the call ends. The receipt carries nothing derived from
   it. The Lean checkers run on diagnostics builds, as they do now.
4. `DeploymentCallAccepted` in `DeploymentAcceptance.lean` binds the receipt
   the evidence names, and `DeploymentReceiptFollows` states the chain. Add
   a tamper case for each receipt field. The cases are tests in the
   production build, not scenarios of `tamper_validation.json`: the probe is
   a diagnostics build, which the production policy rejects, so it cannot
   make a production call.
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
- The atomicity and rollback tests of Issue 06 pass on the new path. The
  production path has no check left that can fail after the call ran, so
  its test is that a rejected call leaves the state, the counters and the
  last receipt untouched; the tests of a failure after the run are those of
  the shared staging path.

Two limits remain and are tracked. The digest of the ciphertext store reads
every sealed record once per accepted call (Issue 44 makes state commitments
incremental). And a receipt is not signed (Issue 53).

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

The sweep of Issue 27 found the opposite case too. A call that aborts, or
that loads an exact object and does not access it, decrypts every slot a
second time to restore the object (`decode_entries_from_storage` in
`RuntimeObject::commit`) and traces one read per slot: at 16,384 entries an
aborting write takes 106 ms of the runtime's own work where a committed one
takes 72 ms. Restore from the plaintext the call loaded.

#### How to fix

In `exactEncodeRun`, read each touched object once, in object-id order. In
the runtime, record the physical scan when the call loads the object
(`clone_for_tx`), not in `record_small_map_scan`; keep the logical event of
each access. `max_load_ops` counts each object once.

An object keeps a copy of what the call loaded at the call's first write of
it, and an aborted call reseals that copy: commit reads no storage. A
public call loads the objects its body accesses, as a confidential call
loads those its kernel program schedules, so that neither opens a record
its load bound does not count.

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

The check classifies each 32-byte unit, the unit D1 chose, and not the
record as a whole (`is_update_write`): a record can change as a whole while
one word of it stays as it was. It sits where a record is sealed in place:
one function for the objects and the ORAM write log, one for the store.

Since Issue 35 a repeated nonce no longer fails the check, because a record
carries the marker its predecessor does not. The tests that force a repeated
nonce now see an `Update`. What the check rejects is covered by the tests of
`is_update_write` and by the tamper scenarios that remove it.

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

The conversion of an array index (`to_usize_saturating`) is made branch-free
with the rest, since the kernel applies it to an operand. What stays is not
arithmetic: indexing an array value by an operand
(`eval_confidential_kernel_array_index_generated`) reads the element at the
index and fails on an index out of range. `docs/claim-boundary.md` names it.

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

As built. A record is a whole number of 32-byte units
(`SEALED_UNIT_BYTES` in `runtime/uo-store/src/generated_codec.rs`). A unit
is one marker byte and 31 bytes of content: the nonce, the ciphertext and
the tag, with zeros after the tag in the last unit. The marker is one per
record, not one per unit: every unit of a record carries it. A record that
replaces none carries the first of two values, `0xA5`, and a record sealed
in place over another carries the other one, so the marker is the parity of
the record's write count. The in-place seal reads the marker of the record
it replaces (`record_marker`) and refuses a slot that holds no record: a
slot with a zero unit, a foreign marker, two markers or another length. A
256-bit value takes 64 bytes and a map record 96.

The Lean file states the codec with the unit length a parameter of every
statement (`encodeUnits`, `decodeUnitsInto?`, `recordMarker?`,
`nextMarker?`): the round trip; that a record which decodes is the encoding
of what it decodes to, so the markers and the padding are checked; the
public length; that every unit begins with the marker; that a record with a
zero unit has no marker and does not decode; and
`isUpdateWrite_of_markers`, that a record written over a record of the same
length with the other marker is an `Update` in every unit, whatever else the
two hold. The sealed record is the codec at 32 bytes
(`encodeSealedRecord_reseal_isUpdate`). Nineteen facts go through the five
boundary layers, where there were seventeen: `storeSealedRecordRejectsZeroUnit`
and `storeSealedRecordResealIsUpdate` are new, and four are renamed
(`storeCodecResealIsUpdate`, `storeCodecDecodeRejectsZeroUnit`,
`storeSealedContentLen`, `storeSealedRecordRejectsWrongMarker`).

The ORAM bucket and page records are sealed by the same two functions and
take their lengths from the sealed slots, so their codecs needed no change
of their own. The manifests and the resource bounds count records, not
bytes, and hold no size that depends on the encoding; the probe's static
storage summary computes sealed lengths and has the new formula. The
modeled cost charges a record, not a unit, as before.

Issue 33's tests forced a repeated nonce and saw the write fail. They now
see it pass as an `Update`, with records that differ in their markers
alone. The in-place seal's error says that the buffer does not hold a
sealed record of the required public size, since that is what it can now
find.

#### Acceptance criteria

- The Lean codec theorems hold for the chosen unit, and decoding rejects a
  record with a zero unit (a tamper scenario).
- The check of Issue 33 classifies every unit of every UO write as `Update`.
- `exact_encoding_matches` holds; results regenerate; the byte figures in
  `docs/path-oram.md` are updated.

---

## Wave 4: no work linear in the store

After this wave, and after Wave 3, rerun the sweep of Issue 27
(`scripts/run_capacity_sweep_full.sh`), compare it with
[`capacity_sweep_baseline.json`](./capacity_sweep_baseline.json)
(`scripts/compare_capacity_sweep.py`), and update the break-evens and the
latencies in `docs/path-oram.md`.

Done after this wave. The full profile took 59 minutes where the one after
Wave 3 took 84, on a machine that was about a fifth slower: the code of the
Wave 3 profile, measured again, takes 47.1 ms for a full-scan read at
16,384 entries where that profile has 39.9 ms. Profiles of different days
therefore do not compare, and the wave's savings are read off a control:
[`capacity_sweep_control_before_wave4.json`](./capacity_sweep_control_before_wave4.json)
is the full profile's rounds on the maps of 4,096, 8,192 and 16,384 entries
at 2 keys on the code before the wave (`cb92f8c`), and
[`capacity_sweep_control_after_wave4.json`](./capacity_sweep_control_after_wave4.json)
the same on the code after it (`9d93471`), run one after the other. To
repeat it, run `--only capacity-sweep-full` at each commit with
`UO_SWEEP_CAPACITIES=4096,8192,16384`, `UO_SWEEP_OCCUPANCY_MAX_CAPACITY=0`,
`UO_SWEEP_WORKLOAD_CALLS=0` and `UO_SWEEP_LEAN_CAPACITIES=0`.

In the control, at 16,384 entries, medians of 30 rounds:

| Call | Whole call before | after | Own work before | after |
| --- | --- | --- | --- | --- |
| tree read | 551.4 ms | 65.4 ms | 35.8 ms | 17.4 ms |
| tree overwrite | 729.7 ms | 233.8 ms | 83.5 ms | 62.7 ms |
| full-scan read | 220.4 ms | 42.0 ms | 47.1 ms | 41.8 ms |
| full-scan overwrite | 425.7 ms | 85.4 ms | 84.2 ms | 85.1 ms |

The witness snapshots were 469.7 ms of the tree read (Issue 36), staging
and loading 11.2 ms of it and now 0.7 ms (Issue 37), and the proof bundles
170.2 ms of the full-scan read and now 0.2 ms (Issue 38). What a measured
call on the tree still adds to its own work is the proof bundles of its
trace, 47 ms for a read and 168 ms for a write: its trace has an event for
each bucket of each path it reads and writes.

Two costs in the size of the store are left, and neither is in these
figures. A call on an exact object decrypts every slot of it, which is
what a full scan is. And a production receipt's digest of the ciphertext
reads every sealed record of a Path ORAM map that the call wrote (Issue
37), which every call on the map does; the sweep runs the diagnostics
build and issues no production receipt. A tree of digests over the buckets
is part of Issue 44.

In the new profile, on a call's own work, the full scan is the faster
backend up to 4,096 entries in every kind of call at every occupancy level.
At 8,192 entries the tree is faster in every read and the full scan in
every write, and at 16,384 the tree is faster in every kind of call at
every level (17.5 ms against 45.0 ms for a read, 67.4 ms against 86.9 ms
for an overwrite). After Wave 3 the first break-even was at 16,384 entries
for reads and the writes were level there. Whole measured calls are still
slower on the tree at every capacity. The break-evens in bytes, physical
operations and gas have not moved, since the counts have not.

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

As built. A production call records no witness (step 1).
`ContractRuntime::begin_traced_call` and `finish_traced_call` hand `uo-core`
no snapshot in a production build, one that is neither a test build nor
built with the `diagnostics` feature, and the functions that decode a
position map or read an access counter for a witness are items of test and
diagnostics builds alone. The proof bundles carry the position
maps, so a call without them builds none.
`ExecutionTrace::from_runtime_finalization_input` runs instead what those
constructors check of the rest of the evidence
(`check_evidence_without_position_maps`): the controller's certificate, the
leaf schedule against the storage events, one leaf transition for each leaf
access, the kernel witness, the outcome and, for a confidential call, the
kernel witness against the artifact's kernel programs.

With evidence (steps 2 and 3) the runtime keeps the witness
(`ContractRuntime::kept_witness`). The snapshot before a call is a copy of
the kept one. The snapshot after it is that copy moved by the call's leaf
transitions (`CommittedRuntimeWitnessSnapshot::advance`, which applies them
as the hidden-state check does), with the access counters the objects have
then. This is done for both Path ORAM schemes, not for the tree alone. The
first call of a deployment, and the first after a bulk load, decodes the
witness from the store. A staged call that is dropped leaves the kept
witness as it was.

The audit is new. The witness after a call is now computed from the one
before it, so the check that the transitions carry one to the other no
longer compares the runtime's record with the store. Every call of a build
that exports evidence therefore compares the kept witness with the full
decode, before it runs and after, and fails if they differ
(`audit_kept_witness`; `tree_position_map_witness_leaves` and the local
scheme's decoder are the reference). The audit is on for every thread until
a measurement turns it off (`set_position_map_witness_audit`). The capacity
sweep times its calls without it and audits after every occupancy level
(`kept_witness_matches_store_after_every_level`), and the probe's latency
report times without it. The validation run audits every other call, so a
call of that run decodes what it decoded before; a measured call and a
production call do not pay for the audit.

Step 4 is not done as written. The evidence still lists every Path ORAM
object of the contract: the Rust and the Lean checkers index the position
maps by the contract's objects, and the witnesses are the same bytes as
before. An object a call did not touch costs a copy of its map and no
decode.

Measured in the validation run's quick profile (two rounds of each call,
`results/capacity_sweep.json`), before and after: the witness of a tree read
takes 0.3 ms at 16,384 entries where it took 393 ms, 0.05 ms at 4,096 where
it took 99 ms, and 0.02 ms at 256 where it took 5.4 ms. A measured call
opens no sealed record for its witness (`witness_scan_records` is 0 in every
row, where a tree call at 16,384 entries opened 65,580); a fill decodes the
witness once (`witness_decode_records`, 32,790 there). The first criterion
is met in substance and not to the letter: the witness time still grows
with the capacity, since a call copies the two position maps into its
evidence, at about a thousandth of the cost it had. Taking that copy away
means evidence that holds the changed leaves and not the maps, a change of
the witness format that this issue does not make. The proof objects of the
validation run are the bytes they were: no report that checks one changed.

Three tamper scenarios are new (408 in all): a production call that starts
with a decoded witness, a witness decoder that every build has, and a kept
witness that is not compared with the store after a call.

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

A production receipt's digest of the ciphertext store (Issue 26) is linear
in the store too: it reads every sealed record once per accepted call. Keep
the digest of each object, which the store's digest is built from, and
compute again only those of the objects a call wrote. A tree of digests
over the buckets of a Path ORAM map, which a path write updates in
logarithmic time, is part of Issue 44.

As built. A committed object is held by reference
(`RuntimeObjectEntry` holds an `Arc`). The state a call is staged on is a
table of the committed objects themselves (`RuntimeObjectTable::share`), so
staging copies no object. A commit puts new objects in the place of those
the call loaded and keeps the others as they are: it used to copy every
object the call did not load a second time. A committed object is never
changed, and only the one holder of an object is handed it for change, so a
call that fails leaves the committed objects as they were. No sealed object
has a cold clone any more (`clone_committed_cold` is gone from the object
graph).

The sealed records of a Path ORAM map are held by reference too
(`SealedPage` in `runtime/uo-evm/src/oram.rs`, in the storage types the
generated codecs take). The copy of a map that a call loads shares the
committed map's records. A write to a shared record changes a copy of it,
so a call copies the records it writes and no other, and a record is zeroed
when its last holder is dropped.

An object keeps the digest of its sealed records (`TableObject`), and
forgets it when it is handed out for change. The digest of the ciphertext
store is built from the objects' digests as before, so a production receipt
reads the records of the objects its call wrote and of no other. The digest
of a Path ORAM map that a call wrote still reads the whole map: a tree of
digests over its buckets is Issue 44.

Not done: an exact object (a cell, an array or a full-scan map) is still
copied when a call loads it. The call opens every slot of it then, which
costs far more than the copy, and a call that writes it replaces every
slot. So a call on an exact object still holds two copies of that object's
ciphertext, and the second criterion is met for Path ORAM maps and for the
objects a call does not load.

Measured in the validation run's quick profile (two rounds of each call,
`results/capacity_sweep.json`), before and after on one machine: staging a
call takes a microsecond at every capacity, where it took 6.5 ms on the tree
and 1.7 ms on the full scan at 16,384 entries; loading the tree takes 1.4 ms
there where it took 6.2 ms. The traces and the counts of the sweep are the
ones they were (`counts_sha256` has not moved). The sweep's resident-memory
figures do not show the saving: at these sizes they are those of the probe
process, its traces and its proof objects. That a call holds no second copy
is tested by address instead: a staged runtime's records are the committed
runtime's, an object a call did not load stays where it was through calls
that commit, abort and fail, and of a map it loaded a call replaces some
records and keeps the others. A test counts the objects whose records a
ciphertext digest reads: those the call loaded.

Two tamper scenarios are new (410 in all): an object handed out for change
with its digest kept, and a call staged on copies of the committed objects.

Found on the way, and not changed: every call takes the public-state
snapshot three times, and a snapshot decodes every public (non-confidential)
sealed object from storage, the ones the call did not load included. The
benchmarks' large objects are confidential, so the sweep does not show it.
Its digest is one hash over all the public objects, so keeping a snapshot
per object would need a digest built from per-object digests, which changes
the public-state digest of every trace. This is Issue 55.

#### Acceptance criteria

- The staging time of Issue 27's breakdown does not grow with the capacity
  of untouched objects, and a call's peak memory is no longer twice the
  store.
- The time to issue a production receipt does not grow with the capacity of
  objects the call did not write.
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

As built. A list of a trace is a list of items, and an item is an event,
as before, or a run of events (`TraceItems` in
`crates/uo-core/src/trace.rs`):

- in `physical_reads`, `{"scan": {"object", "kind", "slots", "len"}}` is
  the scan of an exact object: one read of each of its `slots` sealed
  records of `len` bytes, in slot order;
- in `physical_writes`, `{"rewrite": {...}}` with the same fields is one
  `Update` write of each slot;
- in `logical_accesses`, `{"scan": {"kind", "object", "slots"}}` is the
  logical scan of a map: one event of that kind for each slot;
- in a kernel witness's `resource_events`, `{"repeat": n, "events": [...]}`
  is a block of one or two events that occurs `n` times in a row, which is
  what opening or sealing the slots of an object logs.

`kind` is `cell`, `array` or `map` and fixes the names of the slots (`name`,
`name[i]`, `name#i`). A list stands for its events in order, and nothing
depends on how they are grouped. The hashes and the event transcript of a
trace are computed over its events, so they are the ones they were
(`results/trace_equivalence.json` has not changed), and the Rust checks
count the events and the bytes of a run without naming them. A run of one
event is recorded as the event, so the trace of a call on cells alone is
the bytes it was. A run cannot hide a Path ORAM access: a run that names a
Path ORAM object, and a logical run of an ORAM kind, are rejected.

The recorder (`CallRecorder` in `runtime/uo-evm/src/controller.rs`) keeps a
scan when a call loads an object, from the slot count and the one length
its slots have; slots of more than one length are recorded one by one. It
does not label a rewrite. A commit opens the rewrite of an object, each
seal hands the recorder its write as before, after the write was classified
from its bytes (Issue 33), and the rewrite takes a write only if it is the
`Update` of its next slot, of the length of the slots before it
(`ExactObjectSlots::takes_write` in `uo-core`). Any other write ends the
rewrite. So a rewrite item stands for exactly the writes the recorder was
handed.

The Lean importers expand an item into the events of the models
(`jsonExpandTraceItems` in `UOToolchain/RuntimeRefinementJson.lean`): a
scan with `ExactObjectLayout.scanReads`, a rewrite with `updateWrites`.
`ExactObjectLayout` moved to a module of its own
(`UOToolchain/ExactObjectLayout.lean`) so that the importers can use it.
The checkers and their theorems see the lists they saw before.

A source check binds the recorder and the definitions of a run
(`trace_runs_stand_for_recorded_events` in
`results/runtime_boundary_validation.json`), and the Lean implementation
interface pins the same text. Seven tamper scenarios are new (417 in all).
Three change the sources: a rewrite that takes a write of any class, a
recorder that counts a write into a rewrite without that check, and a trace
hash over items instead of events. Four change the trace of a
ConfidentialMixer `deposit` (`exact_trace/*`): the slot count of a scan and
of a rewrite, the record length of a scan, and the naming of its slots. The
probe's comparison with the exact encoding rejects those four
(`trace_matches_exact_encoding`); it now also compares the length of every
record with the sealed length of its object's type.

Found on the way: Lean does not reject those four. Its witness checker
reads the storage events of Path ORAM objects and no others, and nothing in
Lean compares the storage events of an exact object with `exactEncodeRun`.
That comparison is the probe's, by a Rust mirror of the Lean definition, as
it was before this issue. Issue 54 is to move it into Lean.

Measured in the validation run's quick profile (two rounds of each call,
`results/capacity_sweep.json`), before and after on one machine, at 16,384
entries. The trace of a full-scan read is 9.2 KB of JSON where it was 11.0
MB, and that of a write 10.2 KB where it was 20.7 MB; at 64 entries they
are about 40 and 50 bytes smaller, the digits of the slot counts and of
the gas. Building the proof bundles takes 0.3 ms for the read and 0.4 ms
for the write, where it took 184 ms and 460 ms, and 0.2 ms at 64 entries.
The whole read takes 53 ms where it took 229 ms and the whole
write 99 ms where it took 562 ms; what is left is the decryption and the
sealing of the slots. The traces of the tree are smaller by the folded log
of resource events (2.70 MB for a read where it was 2.96 MB). The counts of
the sweep have not moved; `counts_sha256` has, since it covers the sizes of
the traces.

One report changed its route. The witnesses of the fresh-coin families are
smaller, so the family of SingleAccessMap `add`, 4,096 seeds, is 64.3 MB
and fits the probe's budget of 67.1 MB: `fresh_coin_validation.json` now
has Lean check the whole family, where it checked the compact theorem input
because the family was estimated at 80.9 MB. Both routes were accepted
before and are now.

#### Acceptance criteria

- The trace of an exact-backend call grows with the number of objects, not
  slots.
- `p50_proof_objects_ns` of the full scan no longer grows with the capacity.
- A tamper scenario that changes a slot count or a length is rejected.

---

## Wave 5: theorem coverage

Done. The full profile of the sweep was run again after this wave, since
the stash cap of Issue 40 costs the tree time
(`results/capacity_sweep_full.json`, 62 minutes; `docs/path-oram.md` has
its figures). What the cap costs is read off a control, like the savings of
Wave 4:
[`capacity_sweep_control_before_cap152.json`](./capacity_sweep_control_before_cap152.json)
is the full profile's rounds on the maps of 4,096, 8,192 and 16,384 entries
at 2 keys on the code before Issue 40 (`ece1167`, a cap of 114), and
[`capacity_sweep_control_after_cap152.json`](./capacity_sweep_control_after_cap152.json)
the same on the code after it (`305c1a2`, a cap of 152), run one after the
other. Medians of 30 rounds, a call's own work:

| Call | 4,096 entries | 8,192 | 16,384 |
| --- | --- | --- | --- |
| tree read | 11.2 ms to 12.7 ms | 14.1 ms to 16.3 ms | 16.8 ms to 19.6 ms |
| tree overwrite | 42.7 ms to 48.2 ms | 52.9 ms to 61.7 ms | 61.6 ms to 70.8 ms |
| full-scan read | 9.9 ms to 9.8 ms | 20.1 ms to 20.0 ms | 41.0 ms to 41.5 ms |
| full-scan overwrite | 19.8 ms to 19.8 ms | 40.0 ms to 40.1 ms | 81.4 ms to 83.2 ms |

A tree call's own work is 13% to 17% slower, and 15% to 17% at 16,384 entries,
where Issue 22 estimated about 15%. The full scan moved by 3% at most. The
proof bundles of a tree call's trace grew as much, so a whole measured call
did too: 61.3 ms to 72.0 ms for a read at 16,384 entries and 214.6 ms to 253.9
ms for an overwrite.

In the new profile the two backends have, by the median of a kind of call,
the order they had after Wave 4 in every one of the 525 cells of a
capacity, a kind and an occupancy level: on a call's own work the full scan
is the faster backend up to 4,096 entries, the tree is faster in every read
at 8,192 and in every kind of call at 16,384 (19.8 ms against 43.7 ms for a
read, 74.2 ms against 85.5 ms for an overwrite). Whole measured calls are
slower on the tree at every capacity.

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

As built. `PolicyAgreesWithFlow` has no `notEncrypted` field: a return that
the flow analysis finds secret must be `declassified` or
`encrypted_to_client`, and `policyAgreesWithFlowB`, which the admission
checker runs, decides that.

The outcome model takes a return channel (`ReturnChannelModel` in
`UOToolchain/KernelPaperMain.lean`): a function from the call's rendered
public arguments and the returned value to an `EncryptedReturnPayload`, with
a proof that the payload without its ciphertext and tag does not depend on
the value. Under `encrypted_to_client`, `kernelPublicOutcome` holds a
returned value as that payload and holds no plaintext return, and the
output shape and the exit event have the wire length, the canonical length
plus 28 bytes (`EntrypointPublicPolicy.outputLength`). The release erasure
already erased the ciphertext and the tag of such a payload
(`SGXPublicOutcome.withoutReleases`), so `kernelPublicOutcome_safe` needs
only that the two runs return a value or both return none, which the public
status gives, and the channel's property. The channel is a new argument of
the three paper-main theorems for admitted kernel runs and of their
checked-kernel forms; nothing else in their statements changed.

The model does not derive the frame of a payload from the session or the
freshness counters: it assumes that the frame is fixed by the public
arguments, for one call. That the runtime's payloads are so is checked on
runs. `ConfidentialMixer` has a new entrypoint, `sealedBalanceOf(bytes32)`,
with a secret commitment, `returns: encrypted_to_client` and
`status: public`, in every variant. `checkKernelAdmission` admits it (47
entrypoints in `results/static_checks.json`, 27 on the exact route and 20
on the Path ORAM route), and a new tamper scenario that declares its return
`public` is rejected (`kernel_admission/encrypted_return_policy_relabel`).
`results/trace_equivalence.json` has three new entries, for the exact
variant and for the two Path ORAM variants. In each, eight runs read
commitments that hold 5, 9 and nothing. Their outcomes match the model, the
exact variant's traces are equal and are the exact encoding, and
`encrypted_return` reports that every payload opens under the caller's
session to a stored balance, that none opens under another key, that the
binding, the hash of the associated data, the nonce and the lengths are the
same in all runs, that no outcome holds a plaintext return, and that runs
which return different balances return different ciphertexts and tags.

The runtime gained the caller's side of the channel:
`uo_evm::open_encrypted_return` builds the associated data from the public
facts of the call, checks the binding, the lengths and the hash, and opens
the ciphertext under the session. The runtime's tests had their own copy of
that; they use the function now, with cases for another key, another
session, other public arguments and each field changed.

Not done: nothing in Lean says what the ciphertext and the tag show of the
value. The theorem is modulo that release, and the AEAD assumption is a row
of the assumption table, trusted and not named in Lean, as the issue asked.
The session key's secrecy and freshness come from the attested key
exchange, which the repository does not implement.

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

As built. The cap is 152 (`PATH_ORAM_STASH_BOUND_LIMIT`,
`pathOramStashBoundLimit` and `translationPathOramStashBoundLimit`): at
most `14 · 0.6002^152 < 2^-108` per access and `2^-60` over `2^48` node
accesses of a map. A map of at most 152 entries has a stash as large as
itself, so the local scheme, capped at 128 entries, needs no stash
assumption. The private scheme's stash is `152 + 3h + 1` blocks: 186 at
256 entries and 210 at 16,384, where it was 148 and 172.

An overflow is an error. The node access that finds no room for a block
stops (`TreeStash::compact`, `tree_finish` and, on the local scheme,
`rewrite_path_for_access` return `stash_overflow_error`), so the staged
call is dropped and the committed map keeps every block. Before, the block
was dropped, the access reported a failure in band, the call aborted, and
an aborted call keeps its ORAM accesses. The Lean generator emits the
changed codecs byte for byte, the implementation interface pins the new
text, and a tamper scenario that lets an access go on after an overflow is
rejected (`runtime_implementation_interface/stash_overflow_goes_on_drift`,
419 scenarios in all).

The test that forces an overflow runs on the runtime with its real
parameters, not with a small stash: the stash bound is a function of the
capacity everywhere, from the manifest to the Lean checkers, and a map can
overflow only above 186 entries. The probe deploys the sweep contract on
the private scheme at 256 entries and gives every node access of every put
the same leaf (`call_with_path_oram_fresh_coins`). The nodes the puts read
pile up on one path of 45 blocks and in the stash, and the 232nd put fails
with the stash error. The committed ciphertext is then what it was before
that call, the 231 keys stored before it read back with honest coins, the
key of the dropped call is absent, and the map takes a write again
(`forced_overflow` in `results/stash_occupancy.json`). It makes 232 puts
and 232 reads of that map, which take minutes in a debug build, so it is a
probe report that the validation script runs from a release build and not
a unit test. The unit tests cover the error itself, on both schemes, with
a stash too small for the tree (`tree_map_fails_on_a_stash_overflow`,
`path_oram_get_fails_on_a_stash_overflow`).

`--only stash-occupancy` has two profiles, like the capacity sweep. The
simulator (`runtime/uo-evm/src/stash_occupancy.rs`, a diagnostics module)
runs `tree_get` and `tree_put` over buckets in memory, with the runtime's
eviction and compaction and no cryptography, and counts the stash after
each node access of an operation but its last, when the operation holds
the nodes it read, and after each operation, when it has returned them.
The full profile (`scripts/run_stash_occupancy_full.sh`,
`results/stash_occupancy_full.json`, 40 to 50 minutes on four cores) makes
10,800,300 node accesses: maps of 256, 1,024, 4,096 and 16,384 entries,
each under a random workload, one key read and written over and over, and
inserts and deletes between half full and nine tenths full. The largest
stash while an operation held its nodes was 9 blocks, with a mean below
0.07, and the largest after an operation 18, about the nodes one operation
reads. Against stashes of 186 to 210 blocks the least headroom is 175
blocks. No run overflowed.

What the report compares the counts with: the stash holds more than
`3h + 1 + R` blocks after a node access with probability at most
`14 · 0.6002^R`. It fails if the samples above `3h + 1 + R` blocks
outnumber that bound for some `R`, or if there is a sample where the bound
is below one sample. The observed stash is far below it.

What remains assumed, exactly:

- the stash theorem itself, cited and not proved in Lean, for 5 blocks per
  bucket;
- that it carries over to operations that hold up to `3h + 1` nodes out of
  the tree until they end, with the same tail above those nodes. Ten
  million accesses cannot show a tail of `2^-108`; they would show a stash
  that grows with deferred write-back, and show none;
- that the leaf coins are uniform, which is the key-derivation assumption;
- the budget: the bound is `2^-60` for `2^48` node accesses of a map. The
  runtime does not count a map's accesses against it, and beyond it the
  bound grows with the number of accesses.

A dropped call does not remap the keys it read, where an aborted call
does. That is so for every call that is dropped on an error; for a stash
overflow it happens with the overflow's probability, which the bound of
Issue 29 counts.

The cost of the cap, in the counts of the capacity sweep
(`results/capacity_sweep.json`): the private scheme's stash has five more
pages, read and written once per operation, so a tree read traces 270
physical operations at 256 entries where it traced 260, and 664 at 16,384
where it traced 654. That is 5.7% and 2.3% more bytes. The gas break-even
of the tree against the full scan for reads alone moved from 1,024 entries
to 2,048; the break-evens in bytes and physical operations did not move.
On the local scheme only the map of 128 entries changed: its stash is now
as large as itself. In latency a tree access's own work is 13% to 17%
slower and the full scan is as it was: the control and the full profile
that was run again with the cap are under Wave 5 above.

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

Issues 41 and 42 are done.

### Issue 41 — Put storage behind an adapter that keeps its own I/O log

Source: F4, F8 (§5, §9). Size: M to L. Depends on: Issues 24, 31 and 32.

#### Issue description

Storage is process memory, and the trace is written by the code that
performs the access. Nothing independent says what crosses a storage
boundary.

After Issue 32 the traced reads of a call on exact objects are the records
it opens. Two kinds of read stay outside the trace and should show up as
untraced I/O at the adapter: the counter and metadata pages a Path ORAM map
reads when a call starts, and the public-state digest of an object that is
not confidential but sits on a sealed backend, which opens the object three
times a call (no benchmark declares such an object).

#### How to fix

Add a `StorageAdapter` trait to `uo-store` with an in-memory and a
file-backed implementation. The adapter logs each read and write (location,
length, and the class of each write from its old and new bytes). The runtime
loads and commits through it. A probe report compares the adapter's log with
the trace and counts untraced I/O separately. Measure persistence and a cold
restart from files with a freshness snapshot.

As built. `runtime/uo-store/src/storage.rs` has the `StorageAdapter` trait
with `MemoryStorage` and `FileStorage`. A deployed contract has one (in
memory unless it is deployed with another), which keeps a copy of every
sealed record under the location name a trace gives it. The runtime's
objects keep their own copies as they did, and every record crosses to the
adapter at the two functions that all opens and all seals in place already
went through (`with_opened_payload` and `reseal_payload_and_record_write`
in the generated object helpers), by way of the object's cipher, which
holds its object's part of the store. An open names the record to the
adapter, which compares the runtime's copy with its own, fails the call on
a difference and logs the read. A seal hands the adapter the new record,
and the adapter classifies the write from the record it kept, logs it, and
the call fails unless the class is `Update`. The runtime's copies are thus
a cache that every open checks, and the log is the adapter's own. The
exact objects' opens now carry the location names of the trace
(`name[i]`, `name#i`), which they did not need before.

The adapter is transactional as a call is: `begin`, then the call's reads
and writes, then `commit` with the commit metadata or `abandon`, which puts
back what the call replaced. The engine commits in the adapter before it
takes the call's state (`commit_staged` can now fail), and a staged call
that is dropped abandons (`StagedStore` in `runtime/uo-evm/src/store_meta.rs`).
`FileStorage` keeps a snapshot and a journal: a commit is one journal entry
with a SHA-256, appended and synced as its policy says, an entry cut short
is dropped when the directory is opened, and a journal past a set length
is replaced by a snapshot.

What the comparison found, which the issue did not expect. The issue took
the counter and metadata pages a Path ORAM map reads at a call's start for
I/O beside the traced reads. They are not beside them. The runtime opens a
map's counter and metadata pages once, when the call loads the map, and
holds them; the trace names the counter at every access, and the metadata
pages at every access of the local scheme and every operation of the tree.
So the adapter sees every bucket read the trace names and sees the counter
and each page once: fewer reads than the trace names, and none the trace
does not name. Writes agree one for one, and exact objects agree in reads
too. `results/storage_boundary.json` (`--only storage-boundary`, in the
validation script and in CI) runs every benchmark on every sealed backend,
14 pairs and 47 calls: 4,395 writes on both sides, each classified
`Update` by the adapter; 4,517 traced reads against 3,862 at the adapter,
the other 655 naming a counter or a page again. ERC20Lite `transferFrom`
on the local scheme traces 178 reads of 103,680 bytes where 94 reads of
51,712 bytes cross. The first acceptance criterion is therefore met for
writes and for exact objects, and for Path ORAM reads in this weaker form,
which the report checks exactly: per object, the adapter's reads are the
trace's with each counter and page at its first read only. The modeled
cost charges the reads the trace names. Making the trace name what crosses
is Issue 57. The second kind of untraced read the issue names, the
public-state digest of a public object on a sealed backend, would show at
the adapter as reads the trace does not name and fail the report; no
benchmark declares such an object.

Nonces. A sealed record carries its seal count in the clear. The adapter
takes a record only if that count is below the count it has reserved for
the record's object; the cipher reserves the counts made so far, and a step
of `2^20` beyond, before it hands a record over; a reservation is never
undone, and `FileStorage` journals it before it takes effect. A restart
resumes each key's count at its reservation. So no ciphertext reaches the
adapter before the state that fixes its nonce is durable, and a restart
repeats no nonce, also not one of a call that was dropped or cut off.

Restart. `ContractInstance::restart_with_seed` (test and diagnostics
builds) rebuilds an instance from a store in files: it opens the commit
metadata, which carries a tag under a key derived from the master secret
(`StoreMetaKey`), compares its rollback counter with an attested one
(`RuntimeFreshnessState::recover`, which existed and had no caller),
instantiates each object from the secret and gives it the store's records,
and compares the digest of the restored public state with the metadata's.
Public (raw) objects are not sealed and not logged; a commit leaves their
changed values with the adapter so that a restart finds them. The report
restarts every benchmark on every sealed backend after its workload's
writes: the reads answer and trace as they did on a runtime that never
restarted, a stale attested counter and another deployment's secret are
refused, and no record sealed after the restart carries a nonce from
before. What a restart does not do: it does not detect a store rolled back
together with the attested counter (the rollback resistance of the
deployment assumptions), nor a record replaced by an older record of its
location (a digest tree, Issue 44); a deployment from OS randomness has
its master secret in memory alone and cannot restart (Issue 58); and it
instantiates each object, sealing its initial records, before it takes the
store's, which a restart need not do (Issue 59).

Cost. The capacity sweep can keep its maps' records in files
(`UO_SWEEP_STORAGE`), and its full profile does, with every commit synced:
each row has the commit's time and bytes (`p50_persistence_ns`,
`p50_persisted_bytes`), and a call's own work leaves the commit out, as it
leaves out the witness and the proof bundles. The full profile was run
again (68 minutes; its counts are those of the profile before it), and
`docs/path-oram.md` has its figures. At 16,384 entries a synced commit
takes 0.9 ms of a full-scan read, which writes no record, 9.2 ms of a
full-scan insert (2.1 MB), 2.2 ms of a tree read (174 KB) and 3.1 ms of a
tree insert (512 KB). The control
([`capacity_sweep_control_before_store.json`](./capacity_sweep_control_before_store.json),
the code before this issue, and three runs after it with the records in
[memory](./capacity_sweep_control_after_store_memory.json), in
[files](./capacity_sweep_control_after_store_files.json) and in
[files with every commit synced](./capacity_sweep_control_after_store_files_synced.json))
gives the adapter's cost inside a call: 6% to 9% of a full-scan call's own
work from 8,192 entries (42.6 ms to 45.0 ms for a read at 16,384 entries,
84.8 ms to 92.7 ms for an overwrite), and 2% to 9% of a tree write's; a
tree read at 16,384 entries rose from 19.3 ms to between 20.4 ms and 23.1
ms over the three runs. The backends keep their order by the median of a
kind of call in all 525 cells of the profile. The probe's resident memory
at 16,384 entries rose from 84 MB to 122 MB on the full scan and from 101
MB to 153 MB on the tree. The store keeps a copy of every record beside
the runtime's (Issue 59).

Checks. Invariant 18 of `docs/runtime/secret-state.md`; the boundary bit
`sealed_records_cross_the_storage_boundary`, whose unit test applies
twelve drifts; pins in three definitions of the Lean implementation
interface; three tamper scenarios the Lean checker rejects (422 in all);
a claim and a non-claim in the claim manifest; tests of the store, of the
engine and of the report's comparison.

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

As built. Both tests have a quick profile, which CI regenerates from the
debug build, and a full one, which the validation script runs from the
release build: the runtime is about twenty times slower in a debug build,
and CI builds none other. Each report states its counts, compares them with
what the Lean checker says it checked, and has `accepted` false on a
difference.

The tape substitution has a report of its own, `--only tape-substitution`
and `--only tape-substitution-full`
(`probe/mplus-probe/src/tape_substitution.rs`, schema
`uo-tape-substitution-v1`), with a new Lean checker,
`checkPathOramTapeSamples`: it requires the tape-family checks of a
representative run (`tapeWitnessCheck`) and that each sampled run is the
representative run with the sample's own tape substituted (`sampleCheck`),
whole witnesses but for their seed tag, and prints how many samples ran on
another tape and with other leaves before the call. The contract is SweepMap
on both schemes. A workload is drawn from a seed: a setup of 13 calls (puts,
deletes, reads, and writes behind a guard that fails), then one call of each
of seven kinds: a read that hits, a read that misses, an insert, an
overwrite, a delete, a delete of an absent key and a write that aborts. Each
call runs once as the representative and then on other deployment seeds, the
setup replayed on each. The full profile has maps of 8, 32 and 128 entries
on the local scheme and of 16, 64 and 256 on the private one, two workloads
a map and 16 other seeds a call: 84 calls and 1,344 runs, every one on a
tape other than its representative's and with other leaves before the call,
and every one equal to the substituted run (eight minutes). The quick
profile has one map a scheme (8 and 16 entries), one workload and 3 seeds a
call: 42 runs, 41 on another tape. The checker rejects a sample with one
bucket read moved, a sample of another call and a sample with a read
dropped. The checker runs once a call: the 17 witnesses of one call on the
map of 256 entries are 11 MB of JSON.

The AVL replay (`runtime/uo-evm/src/avl_map_replay.rs`, schema
`uo-path-oram-avl-map-replay-v2`) takes a plan for each capacity: writes of
distinct random keys that fill the map, then mixed operations, and how often
the tree is recorded. A tree of 2,048 nodes is nearly 40 KB of JSON, so a
large replay records it after every 64th operation and after the last; the
model still replays every operation and compares its result, its node
accesses' kinds and the map's size, and the checker requires a tree after
the last operation. The pointer level was already checked after every
operation and still is, on every map: each node block lies on its leaf's
path and is stored once, each tree and free-list pointer carries its node's
current leaf, the tree and the free list are acyclic and together hold every
node, and the stash is within its bound. The quick profile is the replay as
it was (2,400 operations on maps of 1 to 31 nodes, a tree after each). The
full profile (`--only path-oram-avl-map-replay-full`) fills maps of 127,
500, 1,024 and 2,048 nodes and makes as many mixed operations on each as it
holds: 7,398 operations and 287,861 node accesses, 3,559 operations that
leave a tree of at least 1,024 nodes, 408 puts that overflow a full map, and
116 trees compared, the largest of 2,048 nodes (four minutes). The checker
now prints the trees it compared and the nodes of the largest, and the
report requires them to be what the replay recorded.

No divergence was found: every run on another tape was the substituted
run, and every operation agreed with the model. Nothing is promoted: the
claim manifest has the tape substitution as an empirically tested claim
(`path-oram-tape-substitution-tested`), the documents say "tested over
1,344 tapes", and a proof that the runtime follows the models stays
research (Issues 43 and 46).

A rejected sample makes the tape report's `accepted` false, and a count
that the checker does not confirm makes either report's; the acceptance
gate fails on both (`a_runtime_against_model_divergence_fails_closed`). A
replay the model rejects stops the probe. The issue changes no code that a
call runs (the replay is diagnostics code), so the full profiles of the
capacity sweep and of the stash occupancy were not run again; their
`provenance` names the builds that measured them.

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

The maintainer scheduled Issues 51 to 59 as Wave 7 on 2026-11-14; the
order is in [`README.md`](./README.md). Issues 47 to 50 are not scheduled.

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

### Issue 51 — Remove the generator that a seal no longer reads

Source: Issue 24. Size: S to M. Depends on: Issue 24.

Every seal still takes a `ChaCha20Rng`, from when it drew the nonce:
`seal_and_wipe_into_slice`, `seal_and_wipe_boxed`, `filler_boxed` and the
helpers above them. Nothing reads it now. `seal_and_wipe_into_slice`
discards it, and `UoObjectStore::preinitialized` still seeds one from a
constant only to pass it down
(`runtime/uo-store/src/generated_store_helpers.rs`). Each runtime object
also keeps its generator after deployment for the same reason.

Remove the parameter from the generated store surface, the store and object
helpers and the ORAM codecs, with their Lean generators and source pins. An
object then holds a generator only while it is deployed.

Acceptance: no seal takes a generator, no object keeps one after
deployment, and the reports regenerate with only their source identities
changed.

As built. `StoreCipher::seal_and_wipe_boxed`, `seal_and_wipe_into_slice`
and `filler_boxed` take no generator, nor do the helpers above them: the
store's slot helpers, the object helpers' seals and reseals, and the ORAM
codecs' seals, rewrites and accesses, with the ORAM state's `get`, `put`
and `commit`, the tree store and `take_leaf`, which also discarded the one
it was given. Their four Lean generators emit the changed files byte for
byte. `UoObjectStore` neither keeps a generator nor seeds one from a
constant. A runtime object no longer holds a generator: deployment draws
the object's storage key, and a Path ORAM map's initial placement, from a
generator seeded from the object's secret, and drops it. The generator is
now read only there: by `StoreCipher::from_rng` and, for the private
scheme, by `bootstrap_tree_storage`, which draws its nodes' first leaves.
The pins that named the generator, 62 in the probe and in the Lean
implementation interface, name the calls as they are; three that required
a generator to be seeded or discarded are gone. The tests that sealed with
a generator, so as to show that the nonce does not depend on it, seal
without one.

### Issue 52 — Make the seal count of a dropped call a function of its entrypoint

Source: Issue 24. Size: M. Depends on: Issue 24.

A call that stops on an evaluation error is dropped, but the records it
sealed stay counted. The next record's nonce then shows how many records the
dropped call had sealed under each key, which is how far it got. A call that
is dropped after it ran to its end, on a failed production check for
example, sealed its whole schedule, which is public.

In an admitted program an evaluation error comes from tampered storage, an
exhausted budget or counter, or a bug. That none of these depends on a
secret is an observation about the present runtime, not a checked property,
and evaluation errors are outside the trace claims.

Either advance each key's count, when a staged call is dropped, to what the
call's static schedule would have reached, so that the gap depends on the
entrypoint alone; or show that no evaluation error of an admitted program
depends on a secret.

Acceptance: a test drops a call at two different points and reads the same
nonces out of the next call's records.

As built. The first way, with a count that depends on less than the
entrypoint: the count before the call. A staged call takes the count of
every key of the deployment before it runs (`DroppedCallSeals` in
`runtime/uo-evm/src/store_meta.rs`, made in `stage_call` before the store
begins the call), and only `commit_staged`, once the store has made the
call durable, disarms it. Any other end of the call drops it, which moves
each key's count to the second multiple of 2^32 above its count before the
call (`seal_count_after_dropped_call`) and has the store reserve that
count, so that a restart does not resume at a reservation that the dropped
call's seals made. The count before a call is a function of the calls
before it, committed ones by their entrypoints and dropped ones by this
rule, so the count after a drop shows that a call was dropped, which the
caller sees, and nothing of where it stopped. This is simpler than the
static schedule: it needs no model of the seals a call makes, only that no
call makes 2^32 of them under one key, and it costs at most 2^33 counts of
a 64-bit count per dropped call.

`a_dropped_call_leaves_the_same_nonces_wherever_it_stopped` in
`engine.rs` deploys the same ConfidentialMixer twice behind a store that
fails a write it is told to, drops a deposit at its first write in one and
at its fourth in the other, and reads the nonces of the records the next
deposit writes: they are the same, and with the guard disarmed the test
fails. The boundary bit `dropped_calls_leave_fixed_seal_counts` pins the
guard, the rule and where the engine makes and disarms it, and its unit
test rejects eight drifts; invariant 19 of `docs/runtime/secret-state.md`
states the rule.

### Issue 53 — Authenticate production receipts under an attested key

Source: Issue 26. Size: M. Depends on: Issue 26.

A `ProductionReceipt` is bound by its chain and by the runtime's check at
the next call, but it carries no signature. A caller cannot tell from the
receipt alone that the runtime issued it: someone between the two could
change the last receipt of a chain, and the change would show only when the
next call is rejected. The digest of the ciphertext store after a call is
the one field that neither the call's evidence nor its public receipt
binds.

Sign each receipt with a key that the attestation transcript binds, or
authenticate it under the return-channel session, and state in the
deployment theorem what a verifier of the signature may conclude.

Acceptance: a changed last receipt is rejected by a check the caller can
run, without another call.

As built. The receipts are authenticated under the session, with no new
key. A signature would convince a third party too, but it needs a signing
key that the attestation transcript binds, and the runtime has none: the
transcript enters the repository as a hash that the session's binding
carries. `ReturnChannelSession::production_receipt_mac`
(`runtime/uo-evm/src/return_channel.rs`) derives a key for receipts alone
from the session's key, with HKDF-SHA256, the salt
`uo-production-receipt-tag/v1` and the session's id, and a receipt's tag is
HMAC-SHA256 under that key of the salt and the receipt's hash. A production
call computes its receipt's tag before it commits and returns it
(`ProductionCallResult::receipt_tag`), and
`ProductionContractInstance::authenticated_last_receipt` tags the last
receipt for any session that asks, the deployment's receipt before any
call included. The caller's check is `verify_production_receipt(session,
receipt, tag)` in `runtime/uo-evm/src/deployment.rs`: it computes the tag
of the receipt's hash again and compares the two with `Mac::verify_slice`,
in constant time, and makes no call.

`a_changed_last_receipt_is_rejected_by_its_tag` in
`runtime/uo-evm/tests/production_boundary.rs` changes each of the receipt's
ten fields in turn, the digest of the ciphertext store after the call among
them, and the check rejects every one. It rejects a changed tag, a tag that
is not hex and a tag made under another session too, and accepts the tags
of the deployment's receipt and of a call's.

What a verifier may conclude is a new section of
`UOToolchain/DeploymentAcceptance.lean`, in which tags and hashes are
opaque. The two assumptions are stated as hypotheses
(`DeploymentReceiptTags.HashInjective` and `Unforgeable`): two receipts with
one hash are one receipt, and a tag that verifies under a session's key is
the tag of the hash of a receipt the runtime issued. Under them, a receipt
whose tag verifies is one the runtime issued, with every field as issued
(`deployment_receipt_tag_verifies_issued`); a receipt it did not issue has
no tag that verifies (`deployment_receipt_not_issued_tag_rejected`); and,
with the receipts of calls as the runtime issues them
(`DeploymentReceiptIssued`), a receipt whose tag verifies is the receipt of
a call in a state the runtime was in
(`deployment_receipt_tag_verifies_issued_in_a_state`). The claim boundary
lists the two as the trusted assumption "Production receipt MAC", with an
entry in the claim manifest. A tag convinces the holder of its session
alone: a MAC is not a signature.

`production_receipts_carry_session_tags` in
`runtime_boundary_validation.json` pins the key's derivation, the MAC, the
constant-time check, the tag computed before the commit and the tagged last
receipt, with a unit test of five drifts, and
`production_calls_issue_chained_receipts` pins the call as it now ends.

### Issue 54 — Compare a runtime trace with the exact encoding in Lean

Source: Issue 38. Size: M. Depends on: Issue 38.

That the runtime's storage events on exact objects are the ones the exact
store's encoding gives (`exactEncodeRun`) is checked by the probe, with a
Rust mirror of the Lean definition (`exact_encoding_prediction` and
`trace_matches_exact_encoding` in `probe/mplus-probe/src/lib.rs`). No Lean
checker reads those events: the refinement-witness checker accepts a
witness in which the slot count, the record length or the kind of an exact
object's scan was changed. The theorem (`admittedKernel_exactUO`) and the
runtime's trace therefore meet in Rust code that restates the encoding.

Have a Lean checker take the trace of a call with its artifact and compare
the storage events with `exactEncodeRun` of the entrypoint's kernel
program. The admission checker already decodes the program, the manifest
gives the layout of each object, and with runs (Issue 38) the comparison is
one item for each object.

Acceptance: the Lean checker rejects the four `exact_trace/*` tamper
scenarios, and the probe's mirror of the encoding is deleted.

As built. `exactTraceMatches` in
`proof/lean/UOToolchain/KernelExactTraceCheck.lean` holds of a contract's
state objects, a kernel program and a trace when every object the program
touches is on an exact backend and the trace's physical reads and writes
are those of `exactEncodeRun` of the program over the objects' layouts, one
for one and in order. `exactTraceMatches_sound` states that, and
`exactTraceMatches_writes_update` that every write of such a trace is an
`Update`. An object's layout comes from its declaration in the artifact: its
kind, its slot count (one for a cell, its capacity for an array or a map),
and the length of a sealed record of its value, or for a map of a present
flag, a key and a value (`Ty.canonicalLen`, as `Type::canonical_len`
computes it). The `checkExactTrace` executable reads an artifact and the
calls to check, each an entrypoint with its refinement trace, the form the
witness checkers read, whose importer expands a run with
`ExactObjectLayout.scanReads` and `updateWrites`. It decodes each
entrypoint's kernel program from the manifest and prints a verdict for
each call. The probe asks it about every run of an exact-route experiment
(`exact_encoding_matches` in `trace_equivalence.json`, which regenerates
unchanged) and about the tamper scenarios. The Rust mirror
(`exact_encoding_prediction`, `trace_matches_exact_encoding` and their unit
test) is gone. The four `exact_trace/*` scenarios now change the refinement
trace, and the Lean checker rejects them, with three more: a write of
another class, a read left out, and the map scanned a second time (425
scenarios in all).

Writing the record lengths showed that the translation validator's own
canonical lengths (`typeCanonicalLenFromJson` and
`valueCanonicalLenFromJson` in `UOToolchain/TranslationValidationJson.lean`)
put a 4-byte prefix before each part of a struct or an array, where the
runtime puts 8 (`CANONICAL_LENGTH_PREFIX_BYTES`). Proof-grade translation
validation compares the input length of every entrypoint with the
manifest's, so it rejected every artifact with a struct or a fixed-size
array parameter: for the admission matrix's `f(uint256[4])` it computed
4 × (4 + 32) = 144 bytes against the manifest's 160. It failed closed, and
no benchmark has such a parameter, so no report changes. Both now use
`canonicalLengthPrefixBytes`; the public `f(uint256[4])` validates, and two
`#guard`s pin a `uint256[4]` at 160 bytes and a two-field struct at 68.

### Issue 55 — Take the public-state snapshot once for each object a call changes

Source: Issue 37. Size: M. Depends on: Issue 37.

Every call takes the public-state snapshot three times, four in a
production call, and a snapshot decodes every public (non-confidential)
sealed object from storage, those the call did not load included. This is
work in the size of the public state for every call. The benchmarks' large
objects are confidential, so the capacity sweep does not show it.

The snapshot's digest is one hash over all the public objects. Build it
from a digest for each object, as the ciphertext digest is built (Issue
37), keep the decoded snapshot of an object with the object, and decode
again only the objects a call loaded. The public-state digest of every
trace changes, and the Lean statements about the public-state record read
the new digest.

Acceptance: a call's time does not grow with the size of public objects it
does not load, measured on a contract with a large public array; the
public-state checks and their tamper scenarios pass.

As built. A table entry keeps the digest of its object's public state
(`PublicObjectDigest` in `runtime/uo-evm/src/state.rs`) beside the digest of
its sealed records: the SHA-256, under its own domain and with the object's
id, of the JSON the snapshot decodes from storage, and nothing for a
confidential object. It is computed the first time a snapshot asks for it
and forgotten when the object is handed out for change. A snapshot's digest
is the SHA-256, under `uo-runtime/public-state/v1`, of the ids and digests
of the public objects in object-id order, and the public delta compares the
objects' digests. So the snapshots a call takes before it runs, at its
commit and after decode the public objects the call loaded and no other.
That needed one more change: a public call took its committed snapshot from
its shadow, before the shadow's objects were made cold, and making an object
cold builds a new table entry, so the next call decoded the objects again.
It now takes the snapshot from the committed state, as a confidential call
does. The public-state digest of every trace changes. The benchmarks have no
public object, so theirs is the digest of the empty state, which no
committed report names. The Lean statements about the public-state record
read its digests as opaque strings, and none of them changes.

Measured on a new report (`results/public_state.json`, `--only
public-state`). PublicLedger holds a public sealed array of 16 to 16,384
slots, a public cell and a confidential cell; `bump` adds to the cell,
`hide` to the confidential cell, and `record` writes the array. Before
(the report run on the parent commit) and after (the committed report), on
one machine, the median of nine calls of each kind after two:

| Slots | `bump` | `hide` | `record` |
| --- | --- | --- | --- |
| 16 | 0.20 → 0.05 ms | 0.31 → 0.19 ms | 0.25 → 0.19 ms |
| 16,384 | 141 → 0.08 ms | 156 → 0.29 ms | 201 → 169 ms |

Before, every call decoded every public object three times: 6 objects and
639,267 bytes of JSON at 16,384 slots. Now `bump` decodes its cell twice
(106 bytes at every size), `hide` nothing, and `record` the array twice.
The report checks that the calls that do not load the array decode the same
objects and bytes at every size, and that the confidential call decodes no
public object.

Found on the way, and changed: to see that an exact array is cold, the
checks of a call's boundaries read the written flag of every slot, at every
call, of the arrays the call did not load too (about 0.1 ms at 16,384
slots). A table entry now also keeps that its object was found cold, and
forgets it when the object is handed out for change. Callgrind counts the
same work at 16 and at 16,384 slots, over 32 calls after the deployment:
17.7 and 17.8 million instructions for `bump`, 63.9 and 64.0 million for
`hide`. The report's times for the two at 16,384 slots, 0.03 and 0.1 ms
above those at 16, are those of the same instructions on the memory a
larger state leaves. A `bump` timed right after a `record` takes about
0.1 ms more again at 16,384 slots, the time of the caches and the allocator
after a call that moved the array, so the report runs the rounds of each
call together.

`public_state_digests_are_kept_per_object` in
`runtime_boundary_validation.json` pins the digests, with a unit test of six
drifts, and `a_call_copies_no_committed_object` pins the kept coldness. One
tamper scenario is new (426 in all): an object handed out for change with the
digest of its public state kept. The engine test
`a_call_decodes_the_public_state_of_the_objects_it_loaded` runs the three
calls at 16 and 4,096 slots and checks which objects the snapshots of each
call decode, that a digest after the call decodes nothing, that every
digest is the one that decodes every object again, and each call's delta.

### Issue 56 — Slice production sources with a lexer

Source: Issues 36 and 38. Size: S to M. Depends on: nothing.

The source checks read the production part of a Rust file: the file
without its `#[cfg(test)]` items (`production_source_slice` in the probe,
`productionSource` in `UOToolchain/RuntimeImplementationInterface.lean`).
Both find the end of an item by counting braces, and they count the braces
inside string literals and comments too. Two things follow. A file whose
test module holds unbalanced braces in strings, as the probe's own does,
keeps most of its tests in the slice, so a check that counts a text in
that file has to split its own needles (`concat!`). And a `#[cfg(test)]`
attribute on a field or inside a struct literal cuts production text out of
the slice, where a check that a text is absent can no longer see it: Issue
36 met this and moved the attribute.

The checks guard against drift, not against an author who hides text, so
no claim rests on a wrong slice today. Slice with a lexer that knows
strings, characters and comments, in the probe and in Lean, or move every
test module into a file of its own so that a production file has no test
item, and reject a `#[cfg(test)]` that is not on a module or a function.

Acceptance: the slice of every pinned file is the file without its test
items, tested on files with braces in strings; no check splits its needles
to avoid its own text.

As built. One lexer, in the probe (`probe/mplus-probe/src/rust_source.rs`)
and in Lean (`UOToolchain/RustSourceSlice.lean`, which
`RuntimeImplementationInterface.lean` imports for `productionSource`),
classifies every character as code, literal (string, byte string, raw string
with any number of `#`, character, byte character) or comment (line and
nested block), and tells a character literal from a lifetime or a label. A
`#[cfg(test)]` counts only in code. It marks a test item when the item after
it, past further attributes, comments, `pub(…)` and a function's qualifiers,
is a `mod` or a `fn`; the item ends at its `;` or at the `}` that closes its
body, counting code braces only, and a `;` inside the brackets of a
signature (`[u8; 32]`) is not its end. A slice cuts each test item from its
attribute to its end, whole lines where the item fills them. Any other
`#[cfg(test)]` is left in place, so that no production text is cut, and
named. The new Lean executable `checkRustSourceSlices` prints Lean's slices;
`runtime_implementation_interface_validation.json` compares them with the
probe's on the 31 pinned files (`lean_and_probe_slices_agree`, byte for
byte; they also agreed on all 72 tracked Rust files when this was written),
and rejects a misplaced attribute in any of the workspace's 73 Rust files
(`cfg_test_marks_only_modules_and_functions`).

The old slicers disagreed with the new one in two ways. The probe's kept
1,368 non-blank lines of its own test module in the slice of `lib.rs`,
because a string there holds an unbalanced brace, and it cut text after a
`#[cfg(test)]` in two string literals and a comment. And nine `#[cfg(test)]`
attributes marked something else than a module or a function: five `use`
declarations (`checker/uo-check`, `uo-core`'s `trace.rs`, `oram.rs`,
`uo-kernel-runtime`), two constants (`secret.rs`), a `thread_local!` and a
block inside a function (`instrumentation.rs`). Each moved into the test
module or the function that uses it, or, for the counter of the
instrumentation, into a test module with a `#[cfg(not(test))]` function that
does nothing in other builds.

A check that counts code counts in `rust_code_text`, the source with its
literals and comments blanked. The ten needles that were split with
`concat!` to keep a check's own text out of its count are whole. Writing
them whole showed a gap:
`evidence_builds_audit_the_kept_position_map_witness` counted the places
that turn the audit of the kept witness off in `lib.rs` and
`capacity_sweep.rs` only, and Issues 40 to 42 had added five more in other
files of the probe (one in the stash occupancy, three in the storage
boundary, one in the tape substitution), against invariant 15, which said
the audit is off only where calls are timed. The check now counts in every
file of the probe and lists where the guard may be made: the latency report,
the capacity sweep, and the storage boundary, whose comparison of the
store's log with the trace the audit's decode would join. The stash
occupancy and the tape substitution audit again, and invariant 15 says where
the audit is off and why.

### Issue 57 — Trace the reads of a Path ORAM map that cross the storage boundary

Source: Issue 41. Size: L. Depends on: Issue 41.

A call opens the counter and the metadata pages of a Path ORAM map once,
when it loads the map, and holds them. Its trace names the counter at
every access, and the metadata pages at every access of the local scheme
and every operation of the tree. `results/storage_boundary.json` counts
the difference: 655 of the 4,517 traced reads of the benchmarks' calls
cross no boundary. The leakage claim is about the trace and covers what
crosses, since the reads named again are at public positions. The modeled
cost is not what crosses: it charges up to twice the bytes read for a call
that makes several accesses to a map of the local scheme.

Trace what the runtime reads: the counter and the metadata pages of a map
once per call, where the call loads the map, and the buckets at each
access. The schedule of a call changes, and with it the manifest's read
bounds and the cost model in the compiler, the per-access trace shape and
the controller's page budgets in `uo-core` and in the Lean ORAM models,
the checkers that match a leaf schedule against storage events, and every
count in the Path ORAM reports. The other way round, opening the counter
and the pages again at every access, would make the trace true by doing
work that serves nothing.

Acceptance: the storage-boundary report compares reads one for one, with
no held unit; `call_start_reads` and the `*_with_call_start` sums leave the
overhead report; the Path ORAM theorems and checkers hold on the new
schedule; `docs/path-oram.md` has the new counts and break-evens.

### Issue 58 — Seal the master secret so that a production deployment can restart

Source: Issue 41. Size: M. Depends on: Issues 41 and 53.

Only a seeded deployment can restart from its store, and a seeded
deployment exists in test and diagnostics builds. A deployment from OS
randomness keeps its master secret in memory alone, so its store in files
outlives it and nothing can read it. A production restart needs the master
secret sealed to the platform (an SGX sealing key or its like), a restart
entry point on `ProductionContractInstance` that takes the sealed secret
and the attested rollback counter, the receipt chain carried over the
restart (the last receipt is in memory too), and a place in the deployment
assumptions for the sealing. None of it changes a call.

Acceptance: a production instance restarts from files in the build a
production runtime uses, its first receipt after the restart follows the
last before it, and the restart is refused with a stale counter, another
platform's sealed secret or a changed store.

As built. A production deployment with its records in files
(`ProductionContractInstance::deploy_with_storage`) seals its master secret
to its platform and returns the sealed secret, which the host keeps beside
the store. The platform's key is `PlatformSealingKey`, which the platform
hands the enclave (on SGX, the sealing key `EGETKEY` derives for the
enclave's measurement). The seal (`RuntimeMasterSecret::seal_to_platform` in
`runtime/uo-evm/src/secret.rs`) is ChaCha20Poly1305 under a key that
HKDF-SHA256 derives from it, under a nonce from the operating system, with
the deployment's request hash, what was deployed under which policy, as
associated data: the secret opens on that platform and for that deployment
alone. Every commit of a production deployment, the deployment's own
included, leaves the receipt it issued last in the commit metadata
(`StoreMeta::last_receipt`, absent for the others, so their metadata is as
it was), which carries the tag of a key that derives from the master secret.
`ProductionContractInstance::restart` takes the sealed secret and the
attested rollback counter. It opens the secret, reads the metadata under its
tag, compares the rollback counter, restores the objects without a seal
(Issue 59), and goes on only if the receipt it found ends in the state the
store holds (`ProductionReceipt::ends_in`): the public state, the digest of
every sealed record, and the epoch and counters. Its next receipt follows
that one. The restart and the seeded one share their code
(`restart_internal`), and the production restart is in the production build;
none of it changes a call.

`a_production_deployment_restarts_from_its_files_on_its_platform` in
`runtime/uo-evm/tests/production_boundary.rs`, which runs in the production
build, makes two calls on a deployment in files, restarts it, reads a value
written before the restart, and checks that the call's receipt follows the
last one before it. The restart is refused with a rollback counter one
ahead, with another platform's key, with a sealed secret changed in a byte,
and from a copy of the files in which a byte of a bucket was changed after
the last receipt. A unit test of the seal opens it on its platform alone and
for its deployment alone. The deployment assumptions name the sealing:
`platformSealing` is a seventh field of `SgxDeploymentAssumptions`, with a
provenance record citing `EGETKEY` and the SDK's sealing interfaces, an entry
of the mechanism matrix, and a facade of its citation key; the claim
boundary's TEE row and the claim manifest name it. The non-claim of a
restart from OS randomness is gone; what is left of it is a store rolled
back together with the attested counter, or holding an older record.
`production_deployments_restart_from_a_sealed_secret` in
`runtime_boundary_validation.json` pins the seal and its binding, the
restart in the production build, the receipt in the metadata and its check
against the store, with a unit test of six drifts.

### Issue 59 — Keep sealed records in the store alone

Source: Issue 41. Size: L. Depends on: Issue 41.

The store keeps a copy of every sealed record, and the runtime's objects
keep theirs, which every open compares with the store's. The comparison
makes the second copy harmless, and the memory of a deployment is twice
its ciphertext. A restart also instantiates each object, sealing its
initial records, before it replaces them with the store's.

Let an object hold no sealed record: load reads the records it opens from
the store, commit hands over the ones it seals, and the copy-on-write
sharing of Path ORAM pages (Issue 37) moves into the store's pending
state. A restart then builds objects without sealing anything. The digest
of the ciphertext that a production receipt names becomes the store's.

Acceptance: a deployment holds each sealed record once; the capacity
sweep's resident memory at 16,384 entries falls by about the size of the
map's ciphertext; a restart seals no record; the storage-boundary report
is unchanged.

As built. The store alone keeps the sealed records. A committed object
holds none: making an object cold drops the records it holds, and an object
is taken for cold only if it holds none (`holds_no_sealed_record` in
`RuntimeObject::committed_cache_is_cold`), so the check at every call
boundary enforces it. A call reads each record it opens from the store
(`StoreCipher::read_stored_record`, which replaces `check_stored_record`):
the store copies the record out, of the public length the runtime expects,
and logs the read, where it compared a copy the runtime held. The call
holds what it read until it seals the next record over it: an exact
object's slots from its load to its commit (`read_exact_slots` in
`runtime/uo-evm/src/objects.rs`), a Path ORAM map's counter and metadata
pages from its load to its commit (`OramStorage::read_counter_and_pages`),
and the buckets of a path from the access that reads them to the next
(`BucketTable`, in place of the map's array of every bucket). Every record
a call seals is one it read in the call. The surrogate scheme's commit
sealed a window of buckets it never read; it now reads them, as its
transcript already said it did, and no surrogate map is in the
storage-boundary report. The copy-on-write sharing of Path ORAM pages
(Issue 37) went with the shared records (`SealedPage` holds a `Box`): the
store's pending state keeps the committed records that a dropped call
replaced, as it did before. A deployment hands its first records to the
store and keeps none, and a restart builds each object with its key and no
record (`RuntimeObject::instantiate_for_restart`), so it seals nothing. The
digest of the ciphertext reads the store's records, with the same formula,
so every digest is the same.

Measured. The storage-boundary report is unchanged but for its provenance.
At 16,384 entries the store keeps 22.0 MB of the tree's ciphertext, in
32,796 records, and 1.6 MB of the full scan's, in 16,384. The quick profile
of the capacity sweep at that capacity alone, run before and after on one
machine, gives:

| Resident memory | Before | After |
| --- | --- | --- |
| Tree, during a call | 117.9 MB | 92.9 MB |
| Full scan, during a call | 29.9 MB | 29.1 MB |
| Full scan, after the fill | 21.5 MB | 19.7 MB |

A full-scan call holds what it read for its whole length, so its peak falls
by less than a copy of the map. Callgrind counts 3.5% more instructions for
four writes and four reads of a full-scan map of 4,096 slots (720.5 million
to 746.0 million), where each slot's location is now named once more and
its record copied out of the store rather than compared, and 0.7% more for
the same calls on a tree of 1,024 entries (11.38 billion to 11.47 billion).

`sealed_records_are_kept_in_the_store_alone` in
`runtime_boundary_validation.json` pins the reads, the drops and the
restart, with a unit test of nine drifts;
`sealed_records_cross_the_storage_boundary` pins the store's read, and
`a_call_copies_no_committed_object` that a map's records are not shared.
The Lean implementation interface pins the store's reads of an exact
object's slots and of a map's counter, pages and buckets. The tamper
scenario that skipped the store's comparison now loads an exact object's
slots from somewhere other than the store (426 in all). The tests
`an_object_built_for_a_restart_seals_nothing` and
`a_committed_map_holds_no_record_and_a_call_reads_the_ones_it_opens` are
new, and the engine's test of staging checks that no committed object
holds a record and which of the store's records a call replaces.
