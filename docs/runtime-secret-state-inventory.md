# Runtime Secret-State Inventory

This note records the current secret-bearing runtime structures that still
exist in the Rust implementation and where they are supposed to live.

The goal is not to pretend the runtime is already fully verified. The goal is
to make the remaining confidential surface explicit, small, and auditable while
the refinement proof is still being completed.

## Inventory

| Structure | Location | Intended owner | Why it is confidential | Current boundary |
| --- | --- | --- | --- | --- |
| `ConfidentialCallInputs` | `runtime/uo-evm/src/state.rs` | shell projects public summary, then `ContractRuntime` internalizes the raw payload for `crate::runtime` | confidential entrypoint arguments may contain secrets before the kernel slot file is initialized | `engine.rs` can read only the projected `PublicCallSummary`; raw args are wrapped by `ContractRuntime`, and unwrap is restricted to `crate::runtime` |
| `PathOramFreshCoinPlan` | `runtime/uo-evm/src/fresh_coins.rs` | `crate::runtime` plus a diagnostics-gated opaque public API handle | injected fresh-leaf choices determine hidden ORAM randomness | `engine.rs` passes the opaque handle through but does not touch the internal per-object coin map; the handle is non-`Clone`, consumed by value, and moved into the live shadow state without cloning the per-object tapes first; the public injection API is absent from the default surface |
| `ConfidentialExecState` | `runtime/uo-evm/src/kernel.rs` | `RuntimeKernel` | live confidential slot values, abort/return flags, and confidential return value | private to `kernel.rs`; non-`Clone`; wiped on drop |
| `ConfidentialKernelRunOutcome` | `runtime/uo-evm/src/kernel.rs` | `RuntimeKernel` / `crate::runtime` | kernel-owned confidential shadow state, runtime witnesses, abort bit, and live return value at the kernel-to-state handoff | runtime-only type; non-`Clone`; confined to `kernel.rs` |
| `ConfidentialCommittedKernelOutcome` | `runtime/uo-evm/src/state.rs` | `crate::runtime` | committed-state confidential outcome bundle after shadow commit and before packaging into the runtime/theorem handoff | runtime-only type; non-`Clone`; confined to `state.rs` |
| `RuntimeCallOutcome` | `runtime/uo-evm/src/runtime.rs` | `crate::runtime` / theorem finalizer | per-call runtime witnesses plus the live return value remain bundled until theorem packaging finishes | runtime-only type; non-`Clone`; construction is pinned to `runtime.rs`, `state.rs`, and `shell.rs` through the explicit `from_runtime_execution` boundary, `theorem.rs` consumes it through `into_theorem_trace_parts()`, and `engine.rs` does not unpack or own it directly |
| `RuntimeShadowState`, `ConfidentialRuntimeShadowState`, `PublicRuntimeShadowState` | `runtime/uo-evm/src/state.rs` | `crate::runtime` | live reopened confidential object state for one call, with separate wrappers for the confidential kernel path and the public shell path | raw shadow state and the confidential shadow wrapper are now visibility-restricted to `crate::runtime`; the shell sees only `PublicRuntimeShadowState`, while confidential execution uses `ConfidentialRuntimeShadowState` only behind `ContractRuntime` |
| `CommittedRuntimeWitnessSnapshot` | `runtime/uo-evm/src/state.rs` | `state.rs` / `theorem.rs` | theorem-facing hidden ORAM access-counter and position-map witness state from committed storage before and after a call | the snapshot fields are private; the type is non-`Clone`; the helper surface remains crate-private, `CommittedRuntimeState::witness_snapshot` is now fully internal to `state.rs`, and the production calls to `ContractRuntime::ensure_ready_for_call`, `ContractRuntime::witness_snapshot`, and `into_hidden_oram_state()` are pinned to `theorem.rs`, so `engine.rs` no longer calls `witness_snapshot()` or sees the hidden snapshot type directly |
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | `crate::runtime` | object-local confidential logical state and commit/restore paths | non-`Clone`; low-level helpers restricted to `crate::runtime` |
| `OramState` | `runtime/uo-evm/src/oram.rs` | `crate::runtime` | live ORAM entries, position map, stash, access counter, and leaf-coin source | helper use restricted through runtime state/kernel paths |
| `StoreCipher` key and plaintext staging buffers | `runtime/uo-store/src/codec.rs`, `runtime/uo-store/src/store.rs` | store/codec layer | sealing keys and temporary plaintext buffers | direct `seal` / `open` stay in codec; wipe-preserving helpers are the intended public surface |

## Required Invariants

These are the invariants this inventory is meant to support.

1. `engine.rs` should not define or inspect secret-bearing runtime maps or
   witnesses directly, and it should not keep duplicate secret-bearing call
   arguments once the public call summary has been projected from manifest
   metadata; it also should not stage confidential manifest-to-kernel plans or
   confidential shadow wrappers outside `ContractRuntime`, or inspect the
   hidden ORAM snapshot fields used only for theorem packaging.
2. Diagnostic fresh-coin plans should stay opaque to `engine.rs`, be
   non-`Clone`, and move their per-object secret tapes into runtime-owned
   state without cloning them first.
3. Confidential expression execution should live in `RuntimeKernel`.
4. Intermediate per-call outcome bundles that still carry runtime witnesses,
   live shadow state, or a live return value should stay runtime-only across
   the kernel-to-state, state-to-runtime, and runtime-to-theorem handoffs.
5. The final runtime/theorem outcome bundle should be consumed as a whole
   object by the theorem finalizer rather than unpacked in `engine.rs`.
6. Reopen / commit / cold-store / hidden-witness helpers should stay inside
   `crate::runtime`.
7. Direct cryptographic open/seal calls should stay inside the codec layer.
8. Secret-bearing transient buffers should either be wiped on drop or confined
   to an explicitly modeled kernel/state object.
9. Where object/type/program metadata already fixes a confidential buffer
   shape, kernel and commit scratch accounting should use that public shape
   rather than deriving sizes from live secret values; in particular,
   confidential hash scratch should come from the checked manifest's
   `max_hash_part_bytes` field instead of runtime recomputation over live
   values.

## Enforcement

The source-level confinement checks in
`probe/mplus-probe/src/lib.rs` now report this inventory through
`runtime_boundary_validation.json` and reject regressions when the checked
ownership rules drift. Those checks now also pin the newer boundary
reductions: `ConfidentialEntrypointPlan` is confined to `state.rs`, and
`RuntimeShadowState` / `ConfidentialRuntimeShadowState` remain runtime-only
types while the shell-visible handle stays `PublicRuntimeShadowState`, and
`CommittedRuntimeWitnessSnapshot` is opaque and captured only through the
dedicated state/theorem call-trace handoff. The same report now also pins
the authority boundary on that handoff by requiring the runtime preflight and
snapshot helpers to be called only from `runtime/uo-evm/src/theorem.rs` in
production code. It also pins `RuntimeCallOutcome` to the runtime/theorem
handoff by requiring `state.rs` and `shell.rs` to construct it, `theorem.rs`
to consume it whole, and `engine.rs` to avoid unpacking it directly. The
same report now also pins the call-trace bridge itself: `engine.rs` calls
only `run_traced_call(...)` and no longer imports `begin_call_trace`,
`FinalizeCallTraceInput`, or `CallTraceContext` directly, and those helper
types/functions stay private to `runtime/uo-evm/src/theorem.rs`. The same report also
pins the top-level `ContractRuntime` entrypoints themselves: only
`runtime/uo-evm/src/shell.rs` may prepare, commit, or replace the public
shadow wrapper, while only `runtime/uo-evm/src/engine.rs` may invoke
`runtime.run_confidential_entrypoint(...)` inside the traced-call bridge.

This document should be updated whenever a new secret-bearing structure is
introduced or an existing one is removed.
