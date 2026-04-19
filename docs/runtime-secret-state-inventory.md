# Runtime Secret-State Inventory

This note records the current secret-bearing runtime structures that still
exist in the Rust implementation and where they are supposed to live.

The goal is not to pretend the runtime is already fully verified. The goal is
to make the remaining confidential surface explicit, small, and auditable while
the refinement proof is still being completed.

## Inventory

| Structure | Location | Intended owner | Why it is confidential | Current boundary |
| --- | --- | --- | --- | --- |
| `ConfidentialCallInputs` | `runtime/uo-evm/src/state.rs` | shell projects public summary, then `crate::runtime` consumes the raw payload | confidential entrypoint arguments may contain secrets before the kernel slot file is initialized | `engine.rs` can read only the projected `PublicCallSummary`; raw args unwrap is restricted to `crate::runtime` |
| `PathOramFreshCoinPlan` | `runtime/uo-evm/src/fresh_coins.rs` | `crate::runtime` plus a diagnostics-gated opaque public API handle | injected fresh-leaf choices determine hidden ORAM randomness | `engine.rs` passes the handle through but does not touch the internal per-object coin map, and the public injection API is absent from the default surface |
| `ConfidentialExecState` | `runtime/uo-evm/src/kernel.rs` | `RuntimeKernel` | live confidential slot values, abort/return flags, and confidential return value | private to `kernel.rs`; wiped on drop |
| `RuntimeShadowState` | `runtime/uo-evm/src/state.rs` | `crate::runtime` | live reopened confidential object state for one call | hidden behind `CommittedRuntimeState` / `PublicRuntimeShadowState` wrappers |
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | `crate::runtime` | object-local confidential logical state and commit/restore paths | non-`Clone`; low-level helpers restricted to `crate::runtime` |
| `OramState` | `runtime/uo-evm/src/oram.rs` | `crate::runtime` | live ORAM entries, position map, stash, access counter, and leaf-coin source | helper use restricted through runtime state/kernel paths |
| `StoreCipher` key and plaintext staging buffers | `runtime/uo-store/src/codec.rs`, `runtime/uo-store/src/store.rs` | store/codec layer | sealing keys and temporary plaintext buffers | direct `seal` / `open` stay in codec; wipe-preserving helpers are the intended public surface |

## Required Invariants

These are the invariants this inventory is meant to support.

1. `engine.rs` should not define or inspect secret-bearing runtime maps or
   witnesses directly, and it should not keep duplicate secret-bearing call
   arguments once the public call summary has been projected from manifest
   metadata.
2. Confidential expression execution should live in `RuntimeKernel`.
3. Reopen / commit / cold-store / hidden-witness helpers should stay inside
   `crate::runtime`.
4. Direct cryptographic open/seal calls should stay inside the codec layer.
5. Secret-bearing transient buffers should either be wiped on drop or confined
   to an explicitly modeled kernel/state object.

## Enforcement

The source-level confinement checks in
`probe/mplus-probe/src/lib.rs` now report this inventory through
`runtime_boundary_validation.json` and reject regressions when the checked
ownership rules drift.

This document should be updated whenever a new secret-bearing structure is
introduced or an existing one is removed.
