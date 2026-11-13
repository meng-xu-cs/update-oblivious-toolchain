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
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | runtime-owned object state and commit/restore paths |
| `OramState` and ORAM transcript/write evidence | `runtime/uo-evm/src/oram.rs` | runtime-owned ORAM state; generated helpers own codec/rebuild/write-log internals |
| Store cipher key and plaintext staging buffers | `runtime/uo-store/src/*` | store/codec layer; generated helpers own exact-size seal/open/filler surface. The cipher also holds the count of the seals under its key, which is public |

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

### What a nonce shows

A record's nonce shows how many records were sealed under its object's key
before it. An object seals a fixed number of records when it is deployed, and
after that each seal is one recorded storage write
(`reseal_payload_and_record_write`), so on an error-free run the count
follows from the storage trace and shows nothing more. A call that stops on
an evaluation error is dropped with its trace, but its seals stay counted:
the next record's nonce then shows how many records the dropped call had
sealed under that key. Evaluation errors are outside the trace claims (see
[`proof-architecture.md`](../proof-architecture.md)).

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

Invariants 9 to 15 have ten bits in `runtime_boundary_validation.json`:
`deployment_seed_stays_out_of_call_traces`,
`production_errors_carry_no_runtime_freshness_value`,
`contract_instance_debug_is_opaque`,
`runtime_secrets_derive_from_the_master_secret`,
`seal_nonces_come_from_the_seal_count`,
`private_evidence_stays_inside_the_runtime`,
`production_calls_issue_chained_receipts`,
`sealed_writes_are_classified_from_their_bytes`,
`production_calls_record_no_position_map_witness` and
`evidence_builds_audit_the_kept_position_map_witness`. Each is a check of
source text, and a probe unit test shows that it rejects the drifts it
guards against.
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
