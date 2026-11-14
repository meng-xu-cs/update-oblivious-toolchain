# Runtime Secret-State Inventory

This document records the secret-bearing runtime structures that still exist
and the ownership boundaries that keep them auditable.

## Inventory

| Structure | Location | Owner / boundary |
| --- | --- | --- |
| Master secret (`RuntimeMasterSecret`) | `runtime/uo-evm/src/secret.rs` | 256 bits from the OS and the root of every object's secret; it exists only while a contract is deployed, is wiped on drop, and has no `Clone`, no serialization and an opaque `Debug` form |
| Object secrets and Path ORAM leaf seeds (`ObjectSecret`, `PathOramLeafSeed`) | `runtime/uo-evm/src/secret.rs`, `runtime/uo-evm/src/objects.rs` | HKDF-SHA256 expansions of the master secret, one label per use; an object keeps the generator that drew its storage key and initial placement and, for a Path ORAM map, the seed of its leaf coins |
| Replay seed of a seeded deployment | `runtime/uo-evm/src/engine.rs` | test and diagnostics builds only; it is the epoch, the root of the master secret and the tag of the instance's traces, and it protects nothing |
| `ConfidentialCallInputs` | `runtime/uo-kernel-runtime/src/generated_slot_support.rs` | generated slot-support module; staged only through `RuntimeKernelSlotCall` |
| `ConfidentialKernelSlotState` | `runtime/uo-kernel-runtime/src/generated_slot_support.rs` | generated fixed-size slot buffer with wipe-on-drop semantics |
| `PathOramFreshCoinPlan` | `runtime/uo-evm/src/fresh_coins.rs` | runtime-owned opaque fresh-coin handle; diagnostics injection is not default API |
| `Value` aggregate payloads | `crates/uo-core/src/types.rs` | shared value layer; boxed fixed-size aggregate buffers |
| `RuntimeCallOutcome` and traced-call wrappers | `crates/uo-core/src/trace.rs` | theorem-handoff wrappers, non-`Clone`, consumed by finalization helpers |
| `PrivateEvidence`, and the `ExecutionTrace` that holds it | `crates/uo-core/src/trace.rs` | a call's replay tag, kernel witnesses and Path ORAM leaf schedule, counters, position maps and leaf transitions; fields private to `uo-core`, wiped on drop, serializable only in a test or diagnostics build; a call returns it only in such a build |
| `CommittedRuntimeWitnessSnapshot` | `crates/uo-core/src/trace.rs` | hidden witness snapshot wrapper built from `state.rs`: the access counters and position maps of the contract's Path ORAM objects. A test or diagnostics runtime keeps one from call to call (`ContractRuntime::kept_witness`) and copies it only through `duplicate`; a production runtime builds and keeps none (invariant 15) |
| `RuntimeShadowState` / `ConfidentialRuntimeShadowState` / `PublicRuntimeShadowState` | `runtime/uo-evm/src/state.rs` | runtime-only reopened state; public shell receives only public wrapper |
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | runtime-owned object state and commit/restore paths. A committed object is cold and is never changed: the committed state and the states staged from it hold the same object (invariant 16) |
| `OramState` and ORAM transcript/write evidence | `runtime/uo-evm/src/oram.rs` | runtime-owned ORAM state; generated helpers own codec/rebuild/write-log internals. The sealed records of a map's storage (`SealedPage`) are held by reference by the committed map and by the copy a call loads |
| Store cipher key and plaintext staging buffers | `runtime/uo-store/src/*` | store/codec layer; generated helpers own exact-size seal/open/filler surface. The cipher also holds the count of the seals under its key, which is public, and its object's part of the contract's store |
| Commit-metadata key (`StoreMetaKey`) | `runtime/uo-evm/src/secret.rs` | an HKDF-SHA256 expansion of the master secret, kept by the contract instance. It tags the public metadata of every commit, so a restart takes only metadata that a runtime with the same secret wrote. It is wiped on drop and has no `Clone`, no serialization and an opaque `Debug` form |
| Storage adapter (`StorageAdapter`: `MemoryStorage`, `FileStorage`) | `runtime/uo-store/src/storage.rs` | holds no secret: the sealed records as a host keeps them, the values of the public objects, the seal-count reservations and the tagged commit metadata |

## Invariants

1. `engine.rs` must not inspect secret-bearing runtime maps, witnesses, fresh
   coins, hidden ORAM snapshots, or confidential manifest-to-kernel plans.
2. Diagnostic fresh-coin plans must remain opaque to `engine.rs`, non-`Clone`,
   and consumed by value.
3. Confidential expression execution must stay on the shared
   `RuntimeKernelMachine` / `uo-core` confidential-kernel path.
4. Per-call outcome bundles that still carry witnesses, live shadow state, or
   hidden before/after snapshots must remain runtime-only or theorem-handoff
   only.
5. Reopen, commit, cold-store, and hidden-witness helpers must stay inside
   `crate::runtime`.
6. Direct cryptographic open/seal calls must stay inside the codec layer.
7. Secret-bearing transient buffers must either be wiped on drop or confined to
   an explicitly modeled kernel/state object.
8. Buffer sizes and budgets that are fixed by manifest metadata must use that
   public shape instead of deriving capacity from live secret values.
9. The runtime's keys reach no caller. Every storage key, initial placement
   and Path ORAM leaf coin derives from the master secret, which a
   production deployment draws from the OS. No trace, proof object, error or
   `Debug` form carries the master secret, an object's secret, a storage key
   or a leaf seed: a production error names the field that differs and
   prints no runtime value, and a contract instance's `Debug` form shows
   none of its state. Only a seeded deployment, which exists in test and
   diagnostics builds, is a function of its seed, and it tags its traces
   with the seed so that a run can be replayed.

   What a call did with those coins, the position maps and the leaf
   schedule of its Path ORAM accesses, is in the call's private evidence
   (invariant 12).
10. The freshness epoch is public and is drawn from the OS independently of
    the master secret. Production call evidence carries it, so whoever
    prepares that evidence knows it, and it says nothing about a key.
11. No two records are sealed under one key with the same nonce. A record's
    nonce is the count of the seals made under its key before it. Every copy
    of a cipher shares the count, the count only grows, and a seal fails once
    it is exhausted. A call that is staged and then dropped therefore keeps
    the nonces it used: the next call seals with later ones.

12. A call returns its public receipt. Its private evidence stays inside
    the runtime and is dropped, and wiped, when the call ends. Only a test
    or diagnostics build returns the whole trace, writes it out or prints a
    proof object, and the production policy rejects such a build. No field
    of the trace that is classified `CryptographicallyHidden` is a field of
    the receipt (`a_hidden_trace_field_is_private_evidence` in
    `crates/uo-core/src/observer_coverage.rs`, and
    `observerCoverage_publicReceipt_hasNoHiddenField` in
    `UOToolchain/ObserverCoverage.lean`).

13. A production call is accepted on evidence the caller can know, and is
    answered with a `ProductionReceipt`. Nothing in a receipt derives from
    the call's private evidence: the module that builds receipts
    (`runtime/uo-evm/src/deployment.rs`) is handed the call's public
    receipt, the freshness counters and two state digests, and never a
    trace. The digest of the ciphertext store covers the sealed records a
    host holds, and nothing else.

14. The class of a sealed write is read off its bytes. The two functions
    that seal a record in place, one for the runtime's objects and ORAM
    maps and one for the store, keep the record the write replaces and fail
    the call unless every 32-byte unit of the new record is an `Update` of
    the unit it replaces: not zero, not zero before, and changed
    (`uo_core::is_update_write`). The write's event is recorded after that
    check and nowhere else. The record codec makes the check pass whatever
    the ciphertexts are: every 32-byte unit of a sealed record begins with
    one of two nonzero marker bytes, and a record sealed over another
    carries the marker its predecessor does not. A slot that holds no such
    record is not sealed over, and a write that fails the check never
    reaches a trace as an `Update`.

15. A production call records no witness of its hidden ORAM state. The
    witness of a call is the access counters and position maps of the
    contract's Path ORAM objects before the call and after it. The proof
    objects carry it, and only a test or diagnostics build can export
    those. In a production build the functions that decode a position map
    or read an access counter for a witness do not exist, the runtime keeps
    no witness, and a call builds no proof object. `uo-core` still checks
    the rest of the call's evidence as the proof objects' constructors
    check it: the controller's certificate, the leaf schedule against the
    storage events, one leaf transition for each leaf access, the kernel
    witness, the outcome and, for a confidential call, the kernel witness
    against the artifact's kernel programs. A call that fails a check
    returns an error.

    A build that exports evidence keeps the witness from one call to the
    next. The snapshot before a call is the snapshot after the call before
    it, and a call moves it by its own leaf transitions, so only the first
    call, and the first after a bulk load, decodes a map. The witness after
    a call is then computed from the witness before it, and the check that
    the transitions carry one to the other no longer says anything about
    the store. The audit does: every call compares the kept witness with
    the decode of the whole store, before it runs and after, and fails if
    they differ. A measurement turns the audit off for the calls it times
    (`set_position_map_witness_audit`) and audits where it does not time.

16. A call copies no committed object, and a committed object never
    changes. The state a call is staged on is a table of the committed
    objects themselves. A call loads its own copy of the objects it runs
    on, with what it decrypts, and its commit puts new objects in the place
    of those and keeps the others: the runtime takes the staged table only
    when the call has passed every check, and drops it otherwise, so a call
    that fails leaves the committed objects as they were. An object that
    more than one table holds cannot be changed, since only the one holder
    of an object is handed it for change.

    The sealed records of a Path ORAM map are held by reference in the same
    way. The copy of a map that a call loads shares the committed map's
    records, a write to a shared record changes a copy of it, and a record
    is zeroed only when its last holder is dropped: the copy a failed call
    wrote is zeroed, and the committed record it would have replaced is
    not. An exact object (a cell, an array or a full-scan map) is opened
    whole when a call loads it, and its sealed slots are copied then.

    An object keeps the digest of its sealed records once it was asked
    for, and forgets it when it is handed out for change. So the digest of
    the ciphertext store (invariant 13) reads the records of the objects
    written since the last digest and of no other.

17. A run in a trace stands for the events the runtime recorded. The scan
    and the rewrite of an exact object are one item of a trace each, with
    the object's slot count and the length of a sealed slot, and so is the
    logical scan of a map. A trace is the events of its items in order.
    `uo-core` names the events of a run and computes the hashes of a trace
    over its events, so a hash does not depend on how the events are
    grouped. The recorder keeps a scan as one item only when every slot of
    the object has one length. It does not label a rewrite: a rewrite takes
    the writes the recorder is handed one at a time, each after the check
    of invariant 14, and takes a write only if it is the `Update` of its
    next slot, of the length of the slots before it
    (`ExactObjectSlots::takes_write`). Any other write ends the rewrite
    and is recorded by itself. A run that names a Path ORAM object is
    rejected, so no run holds an event of a Path ORAM access.

18. Every sealed record crosses to the contract's store where it is opened
    and where it is sealed. A deployed contract has a store
    (`StorageAdapter` in `runtime/uo-store/src/storage.rs`), in memory
    unless it is deployed with one in files. The store keeps a copy of
    every sealed record under the name a trace gives the record's location.
    The one function that opens a record first names it to the store
    (`check_stored_record`): the store compares the runtime's copy with the
    record it keeps, fails the call if they differ, and logs the read. The
    one function that seals a record in place hands the store the new
    record (`store_sealed_record`), after the check of invariant 14 and
    before the write's event is recorded: the store classifies the write
    from the record it kept and logs it, and the call fails unless that
    class is `Update` too. So the store writes its log of a call from its
    own records, and the runtime's copies of the records are a cache that
    every open compares with the store.

    A call's records are pending in the store until the call is committed.
    The engine commits them there, with the commit metadata, before it
    takes the call's state. A call that fails, or is dropped after it was
    staged, abandons them: the store puts back what they replaced.

    The store takes a sealed record only if the seal count in the record's
    nonce is below the count it has reserved for the record's object, and
    the cipher reserves the counts of the seals made so far before it hands
    a record over. A reservation is never undone, and a store in files has
    it in its journal before it takes effect. A runtime that restarts from
    the files resumes each key's count at its reservation
    (`resume_seal_count`, which can only raise a count). So it seals no
    record under a nonce that a record handed to the store carries, whether
    the call that sealed that record was committed, abandoned or cut off.

    A restart (`ContractInstance::restart_with_seed`, in test and
    diagnostics builds) takes the commit metadata only with the tag of the
    deployment's secret, compares its rollback counter with an attested
    one, takes each object's records from the store, and compares the
    digest of the public state it restored with the one the metadata
    names. It does not detect a store that was rolled back together with
    the attested counter, nor a record replaced by an older record of its
    location: a record carries its location and not its version. The first
    is the rollback resistance of the deployment assumptions; a digest tree
    over the records is Issue 44 of the external review. A deployment from
    OS randomness cannot restart, since its master secret is in memory
    alone.

### What a nonce shows

A record's nonce shows how many records were sealed under its object's key
before it. An object seals a fixed number of records when it is deployed, and
after that each seal is one recorded storage write
(`reseal_payload_and_record_write`), so on an error-free run the count
follows from the storage trace and shows nothing more. A call that stops on
an evaluation error is dropped with its trace, but its seals stay counted:
the next record's nonce then shows how many records the dropped call had
sealed under that key. Evaluation errors are outside the trace claims (see
[`proof-architecture.md`](../proof-architecture.md)). After a restart a
key's count resumes at the count its store had reserved, so the next
record's nonce also shows that the runtime restarted and how many counts
it skipped.

### What a marker shows

A record's marker shows the parity of the number of times the record has
been written since its object was deployed. Each of those writes is one
recorded storage write, so the marker follows from the storage trace and
shows nothing more. A call that is dropped leaves the committed records and
their markers as they were.

## Enforcement

`probe/mplus-probe/src/lib.rs` emits source-boundary checks through reports
such as:

- `runtime_boundary_validation.json`
- `runtime_implementation_interface_validation.json`
- `runtime_implementation_kernel_machine_confinement_boundary_validation.json`
- `kernel_model_alignment_validation.json`
- `tamper_validation.json`

Those reports reject representative drift including direct secret operations in
handwritten shell code, raw confidential-argument observation in adapters,
growable runtime witness buffers, ORAM early-exit scans, growable ORAM
write/read evidence, direct store cipher calls outside the codec layer, and
reintroduction of host-visible hidden-state errors that should be modeled
confidential aborts.

Invariants 9 to 18 have thirteen bits in `runtime_boundary_validation.json`:
`deployment_seed_stays_out_of_call_traces`,
`production_errors_carry_no_runtime_freshness_value`,
`contract_instance_debug_is_opaque`,
`runtime_secrets_derive_from_the_master_secret`,
`seal_nonces_come_from_the_seal_count`,
`private_evidence_stays_inside_the_runtime`,
`production_calls_issue_chained_receipts`,
`sealed_writes_are_classified_from_their_bytes`,
`production_calls_record_no_position_map_witness`,
`evidence_builds_audit_the_kept_position_map_witness`,
`a_call_copies_no_committed_object`,
`trace_runs_stand_for_recorded_events` and
`sealed_records_cross_the_storage_boundary`. Each is a check of source text,
and a probe unit test shows that it rejects the drifts it guards against.
`cargo test -p uo-evm` runs the tests behind all but the two about secrets
and nonces in the build a production runtime uses
(`runtime/uo-evm/tests/production_boundary.rs`, and the production tests
of `engine.rs`); a workspace build turns on the `diagnostics` feature and
compiles those tests out.

Invariant 12 is also pinned in the Lean implementation interface
(`engineDelegatesToRuntimeBridge`), and `tamper_validation.json` has two
scenarios for it that the Lean checker must reject: a position map moved
from the evidence into the receipt
(`runtime_implementation_interface/receipt_position_map_drift`), and a call
result that carries the trace in every build
(`runtime_implementation_interface/call_result_trace_drift`).

Invariant 14 is pinned there too (`runtimeObjectCommitUsesPublicSealAndWriteShell`
and `runtimeStoreUoWritesEmitPublicUpdateShape`), with two scenarios that the
Lean checker must reject: the check removed from the objects' and ORAM maps'
seal (`runtime_implementation_interface/sealed_write_update_check_drift`) and
from the store's
(`runtime_implementation_interface/store_sealed_write_update_check_drift`).
The record codec is pinned in `storeCipherUsesExactSizeNonzeroBuffers`, with
two more scenarios: a marker taken from a record's first unit alone, so that
a record with a zero unit would be read and sealed over
(`runtime_implementation_interface/store_codec_zero_unit_accept_drift`), and
a record sealed under the marker of the record it replaces
(`runtime_implementation_interface/store_reseal_marker_reuse_drift`). The
Lean model of the codec proves that a record sealed over a record is an
`Update` in every unit (`encodeSealedRecord_reseal_isUpdate` in
`UOToolchain/RuntimeStoreCodecSemantics.lean`). Tests of
`runtime/uo-evm/src/objects.rs`, `runtime/uo-store/src/store.rs` and
`runtime/uo-store/src/codec.rs` set a seal count back, so that a write
repeats the nonce of the record it replaces and, for the same value, its
ciphertext, and see that the write is still an `Update`: the two records
differ in the marker of every unit. The codec's tests also show that a
record with a zero unit, a unit with the other marker or a byte after its
content is not read, and that a buffer that holds no record is not sealed
over.

Invariant 15 is pinned in the Lean implementation interface
(`stateStagesConfidentialCallsInsideRuntime`,
`theoremFinalizerUsesSharedTraceBridge`,
`runtimeOramUsesLeanGeneratedBlockBucketCodecs` and
`engineDelegatesToRuntimeBridge`), with three scenarios that the Lean
checker must reject: a production call that starts with a witness decoded
from the store
(`runtime_implementation_interface/production_call_witness_snapshot_drift`),
a witness decoder that every build has
(`runtime_implementation_interface/position_map_witness_decoder_ungated_drift`),
and a kept witness that is not compared with the store after a call
(`runtime_implementation_interface/kept_witness_audit_skip_drift`). Its
tests are in three places. `runtime/uo-evm/src/engine.rs` runs calls that
touch a map of each Path ORAM scheme, and both, with an abort, reads that
hit and miss, a refused call and a bulk load, and sees after each that the
kept witness equals the decode of the store and that the witness before a
call is the witness after the one before it; it sees a call fail when the
kept witness is another runtime's; and it runs the same calls from one seed
with and without a witness and sees the same return values, receipts and
ciphertext. A test build audits every call, so every call of the runtime's
test suite is such a comparison.
`production_calls_run_without_a_position_map_witness` in
`runtime/uo-evm/tests/production_boundary.rs` runs those calls in the
build a production runtime uses. `crates/uo-core/src/trace.rs` tests the
checks that a call without position maps still runs, one rejected drift
for each, and that a snapshot moved by a call's transitions is the snapshot
the hidden-state check accepts after it.
`pathoram_hidden_validation.json` counts the audits behind each
certificate it checks (`kept_witness_audits`), and the capacity sweep,
which times its calls with the audit off, audits after every occupancy
level (`kept_witness_matches_store_after_every_level`).

Invariant 16 is pinned in the Lean implementation interface
(`runtimeShadowStateUsesFixedSortedCommitTable` and
`runtimeOramUsesLeanGeneratedBlockBucketCodecs`), with two scenarios that
the Lean checker must reject: an object handed out for change with its
digest kept
(`runtime_implementation_interface/committed_object_digest_stale_drift`),
and a call staged on copies of the committed objects
(`runtime_implementation_interface/staged_call_copies_committed_objects_drift`).
Its tests are in `runtime/uo-evm/src/engine.rs` and
`runtime/uo-evm/src/oram.rs`. One reads where each sealed record of each
object is in memory: a staged runtime's records are the committed
runtime's, an object a call did not load stays where it was through calls
that commit, abort and fail, and of a map it loaded a call replaces some
records and keeps the others. One counts the objects whose records a
digest reads: those the call loaded, and none after a failed call, with
the digest equal to the one that reads every record again. One writes to a
shared record and sees the other holder's record unchanged, and sees that
wiping zeroes a record only for its last holder. The atomicity and rollback
tests of the runtime run on the shared objects as they ran on copies.

Invariant 17 is pinned in the Lean implementation interface
(`runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers`), with
three scenarios that the Lean checker must reject: a rewrite that takes a
write of any class
(`runtime_implementation_interface/rewrite_run_takes_unclassified_write_drift`),
a recorder that counts a write into its open rewrite without that check
(`runtime_implementation_interface/recorder_rewrite_run_skips_fold_drift`),
and a trace hash over the items of a trace instead of its events
(`runtime_implementation_interface/trace_hash_over_run_items_drift`). Four
more scenarios change a run in the trace of a call (`exact_trace/*`: the
slot count of a scan and of a rewrite, the record length of a scan, the
naming of its slots), and the probe's comparison of the trace with the
exact store's encoding rejects them. That comparison is Rust code; no Lean
checker reads the storage events of an exact object. Its tests are in
`crates/uo-core/src/trace.rs`, which shows that a trace with runs has the
hashes, the transcript and the Path ORAM checks of the trace of their
events, that a rewrite takes the `Update` of its next slot and no other
write, and that a log of resource events folded into blocks replays as its
events do; and in `runtime/uo-evm/src/engine.rs`, where the trace of a
call on a full-scan map has as many items at 64 entries as at 1,024.

Invariant 18 is pinned in the Lean implementation interface
(`runtimeObjectOpenUsesSharedDecodeShell`,
`runtimeObjectCommitUsesPublicSealAndWriteShell` and
`storeCipherUsesExactSizeNonzeroBuffers`), with three scenarios that the
Lean checker must reject: a record opened without naming it to the store
(`runtime_implementation_interface/sealed_open_store_check_skip_drift`), a
sealed write recorded without handing the record to the store
(`runtime_implementation_interface/sealed_write_store_skip_drift`), and a
record handed over before its seal count is reserved
(`runtime_implementation_interface/store_write_unreserved_nonce_drift`).
The store's own side is handwritten Rust, which the boundary bit pins and
`runtime/uo-store/src/storage.rs` tests: the log and the classes it
computes, a read of a record the runtime does not hold, a record refused
before its nonce is reserved, what an abandoned call leaves, a store in
files that reopens as its last commit left it, and a commit cut short at
several lengths, which is dropped whole. `runtime/uo-evm/src/engine.rs`
compares the store's log with the trace of calls on exact objects and on
both Path ORAM schemes, drops a call after it handed records over, and
restarts from files beside a twin that never restarted: the two return the
same values and receipts, and no record sealed after the restart carries a
nonce from before it. `results/storage_boundary.json` makes the comparison
and the restart on every benchmark and sealed backend (see The Storage
Boundary in [`claim-boundary.md`](../claim-boundary.md)).

Invariant 11 also has a Lean statement and tests. `sealNonceRun_nodup` and
`sealNonceRun_disjoint_of_le` in `UOToolchain/RuntimeStoreCodecSemantics.lean`
prove that a model of the counter hands out no nonce twice. That the Rust
`seal_nonce` computes the model's bytes is tested, not proved
(`seal_nonce_is_the_big_endian_counter` in `runtime/uo-store/src/codec.rs`).
`a_dropped_staged_call_does_not_give_its_nonces_back` in
`runtime/uo-evm/src/engine.rs` reads the nonces out of storage for every kind
of sealed object.

The checks are source-backed/static-drift evidence. They deliberately do not
claim full Rust semantic verification.
