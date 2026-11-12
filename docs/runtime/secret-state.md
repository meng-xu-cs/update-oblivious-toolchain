# Runtime Secret-State Inventory

This document records the secret-bearing runtime structures that still exist
and the ownership boundaries that keep them auditable.

## Inventory

| Structure | Location | Owner / boundary |
| --- | --- | --- |
| Deployment seed, which is also the freshness epoch | `runtime/uo-evm/src/engine.rs`, `runtime/uo-evm/src/freshness.rs` | root of every object key, nonce stream and Path ORAM coin; kept by the runtime, and by `ContractInstance` only as the replay tag of a seeded deployment |
| `ConfidentialCallInputs` | `runtime/uo-kernel-runtime/src/generated_slot_support.rs` | generated slot-support module; staged only through `RuntimeKernelSlotCall` |
| `ConfidentialKernelSlotState` | `runtime/uo-kernel-runtime/src/generated_slot_support.rs` | generated fixed-size slot buffer with wipe-on-drop semantics |
| `PathOramFreshCoinPlan` | `runtime/uo-evm/src/fresh_coins.rs` | runtime-owned opaque fresh-coin handle; diagnostics injection is not default API |
| `Value` aggregate payloads | `crates/uo-core/src/types.rs` | shared value layer; boxed fixed-size aggregate buffers |
| `RuntimeCallOutcome` and traced-call wrappers | `crates/uo-core/src/trace.rs` | theorem-handoff wrappers, non-`Clone`, consumed by finalization helpers |
| `CommittedRuntimeWitnessSnapshot` | `crates/uo-core/src/trace.rs` | hidden witness snapshot wrapper built from `state.rs` |
| `RuntimeShadowState` / `ConfidentialRuntimeShadowState` / `PublicRuntimeShadowState` | `runtime/uo-evm/src/state.rs` | runtime-only reopened state; public shell receives only public wrapper |
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | runtime-owned object state and commit/restore paths |
| `OramState` and ORAM transcript/write evidence | `runtime/uo-evm/src/oram.rs` | runtime-owned ORAM state; generated helpers own codec/rebuild/write-log internals |
| Store cipher key and plaintext staging buffers | `runtime/uo-store/src/*` | store/codec layer; generated helpers own exact-size seal/open/filler surface |

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
9. The deployment seed reaches no caller. A deployment from OS randomness
   tags no trace or proof object with it, a production error names the field
   that differs and prints no runtime value, and a contract instance's
   `Debug` form shows none of its state. Only a seeded deployment, which
   exists in test and diagnostics builds, tags its traces with its seed, so
   that a run can be replayed.

Invariant 9 does not yet make the seed secret. The freshness epoch that
production call evidence must carry is the seed itself, so whoever prepares
that evidence knows it, and every key derives from its 64 bits. Issue 24 of
[`review/2026-11-external-review`](../../review/2026-11-external-review/README.md)
gives the runtime a master secret that is independent of the epoch.

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

Invariant 9 has three bits in `runtime_boundary_validation.json`:
`deployment_seed_stays_out_of_call_traces`,
`production_errors_carry_no_runtime_freshness_value` and
`contract_instance_debug_is_opaque`. `cargo test -p uo-evm` runs the tests
behind them in the build a production runtime uses
(`runtime/uo-evm/tests/production_boundary.rs`). A workspace build turns on
the `diagnostics` feature and compiles those tests out.

The checks are source-backed/static-drift evidence. They deliberately do not
claim full Rust semantic verification.
