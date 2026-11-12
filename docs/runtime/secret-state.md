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
| `CommittedRuntimeWitnessSnapshot` | `crates/uo-core/src/trace.rs` | hidden witness snapshot wrapper built from `state.rs` |
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

   A trace still carries what a call did with those coins: the position
   maps and the leaf schedule of its Path ORAM accesses. Issue 25 of
   [`review/2026-11-external-review`](../../review/2026-11-external-review/README.md)
   takes them out of what a production call returns.
10. The freshness epoch is public and is drawn from the OS independently of
    the master secret. Production call evidence carries it, so whoever
    prepares that evidence knows it, and it says nothing about a key.
11. No two records are sealed under one key with the same nonce. A record's
    nonce is the count of the seals made under its key before it. Every copy
    of a cipher shares the count, the count only grows, and a seal fails once
    it is exhausted. A call that is staged and then dropped therefore keeps
    the nonces it used: the next call seals with later ones.

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

Invariants 9 to 11 have five bits in `runtime_boundary_validation.json`:
`deployment_seed_stays_out_of_call_traces`,
`production_errors_carry_no_runtime_freshness_value`,
`contract_instance_debug_is_opaque`,
`runtime_secrets_derive_from_the_master_secret` and
`seal_nonces_come_from_the_seal_count`. Each is a check of source text, and a
probe unit test shows that it rejects the drifts it guards against.
`cargo test -p uo-evm` runs the tests behind the first three in the build a
production runtime uses (`runtime/uo-evm/tests/production_boundary.rs`); a
workspace build turns on the `diagnostics` feature and compiles those tests
out.

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
