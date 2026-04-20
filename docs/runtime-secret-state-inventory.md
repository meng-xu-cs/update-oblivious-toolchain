# Runtime Secret-State Inventory

This note records the current secret-bearing runtime structures that still
exist in the Rust implementation and where they are supposed to live.

The goal is not to pretend the runtime is already fully verified. The goal is
to make the remaining confidential surface explicit, small, and auditable while
the refinement proof is still being completed.

## Inventory

| Structure | Location | Intended owner | Why it is confidential | Current boundary |
| --- | --- | --- | --- | --- |
| `ConfidentialCallInputs` | `runtime/uo-evm/src/kernel.rs` | `crate::runtime`, with unwrapping owned by `RuntimeKernel` | confidential entrypoint arguments may contain secrets before the kernel slot file is initialized | `engine.rs` can read only the projected `PublicCallSummary`; the theorem/runtime confidential branch boxes the raw confidential args into a fixed-size `ConfidentialCallInputs` buffer before handing them to `ContractRuntime`, and only `kernel.rs` may unwrap that buffer into the slot interpreter; buffered `Value`s wipe on drop |
| `PathOramFreshCoinPlan` | `runtime/uo-evm/src/fresh_coins.rs` | `crate::runtime` plus a diagnostics-gated opaque public API handle | injected fresh-leaf choices determine hidden ORAM randomness | `engine.rs` passes the opaque handle through but does not touch the internal per-object fresh-coin entry table; the handle is non-`Clone`, consumed by value, and moved into the live shadow state without cloning the per-object tapes first; the plan now stores those tapes in boxed per-object entries rather than a generic map, and the public injection API is absent from the default surface |
| `ConfidentialExecState` | `runtime/uo-evm/src/kernel.rs` | `RuntimeKernel` | live confidential slot values, abort/return flags, and confidential return value | private to `kernel.rs`; non-`Clone`; wiped on drop |
| `RuntimeCallOutcome` | `runtime/uo-evm/src/runtime.rs` | `crate::runtime` | per-call runtime witnesses plus the live return value remain bundled until the state-owned theorem handoff is assembled | runtime-only type; non-`Clone`; construction is pinned to `runtime.rs`, `state.rs`, and `shell.rs` through the explicit `from_runtime_execution` boundary, `state.rs` is the only consumer of `into_theorem_trace_parts()`, and `engine.rs` does not unpack or own it directly |
| `TracedRuntimeCallStart` | `runtime/uo-evm/src/state.rs` | `state.rs` / `theorem.rs` | theorem-facing pre-call token that carries the hidden committed-state snapshot without exposing the raw snapshot type | runtime/theorem handoff type; non-`Clone`; produced only by `ContractRuntime::begin_traced_call(...)`, stored only in theorem-local call-trace context, and absent from `engine.rs` |
| `TracedRuntimeCallOutcome` | `runtime/uo-evm/src/state.rs` | `state.rs` / `theorem.rs` | post-call hidden witness snapshot plus the bundled runtime outcome remain secret-bearing until final execution-trace packaging | runtime/theorem handoff type; non-`Clone`; constructed only by `ContractRuntime::finish_traced_call(...)`, consumed in `theorem.rs` only through `into_finalized_call_trace_parts(...)`, and absent from `engine.rs` |
| `TracedRuntimeCallWitnessState` | `runtime/uo-evm/src/state.rs` | `state.rs` / `theorem.rs` | finalized before/after hidden ORAM witness bundle for execution-trace packaging | runtime/theorem handoff type; non-`Clone`; produced only by `TracedRuntimeCallOutcome::into_finalized_call_trace_parts(...)`, consumed in `theorem.rs` only through `into_execution_trace_parts()`, absent from `engine.rs`, stored in boxed fixed-size buffers for the public-bounded witness set, and its hidden witnesses wipe on drop |
| `RuntimeShadowState`, `ConfidentialRuntimeShadowState`, `PublicRuntimeShadowState` | `runtime/uo-evm/src/state.rs` | `crate::runtime` | live reopened confidential object state for one call, with separate wrappers for the confidential kernel path and the public shell path | raw shadow state and the confidential shadow wrapper are now visibility-restricted to `crate::runtime`; the shell sees only `PublicRuntimeShadowState`, while confidential execution uses `ConfidentialRuntimeShadowState` only behind `ContractRuntime`; the underlying loaded-object carrier is no longer a generic map but a fixed-order boxed table keyed by the public object universe |
| `CommittedRuntimeWitnessSnapshot` | `runtime/uo-evm/src/state.rs` | `state.rs` | hidden ORAM access-counter and position-map witness state from committed storage before and after a call | the snapshot fields are private; the type is non-`Clone`; the type and its projection helper are now fully internal to `state.rs`, both `CommittedRuntimeState::witness_snapshot` and `ContractRuntime::witness_snapshot` are internal, theorem-facing code now sees only the traced-call handoff bundles rather than the raw snapshot type, the hidden witness carriers are boxed fixed-size buffers for the public-bounded ORAM witness set, and those hidden witness buffers wipe on drop |
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | `crate::runtime` | object-local confidential logical state and commit/restore paths | non-`Clone`; low-level helpers restricted to `crate::runtime`; secret-bearing ciphertext slots in the object graph now use boxed fixed buffers, including the raw-backend `RawMapEntry` slot |
| `OramState` | `runtime/uo-evm/src/oram.rs` | `crate::runtime` | live ORAM entries, position map, stash, access counter, and leaf-coin source | `OramState` now keeps its own fields private and exposes only explicit runtime-facing queries (`is_cold()`, `parameters()`, `path_bucket_count()`, `path_position_map_witness(...)`, `access_counter_witness(...)`) plus the mutation/commit APIs already owned by `oram.rs`; the shared `MapEntry` record now also keeps private fields and crosses the small-map / ORAM code paths only through explicit entry methods (`new`, `is_occupied`, `matches_key`, `value`, `set_value`, `set_vacant`, `occupy`); `OramTranscript` / `OramCommit` / `OramWrite` likewise keep private fields and cross into `objects.rs` only through `into_runtime_trace_parts(...)`, `into_object_commit_parts(...)`, and `with_object(...)`; the internal `OramStorage` / `OramBlock` / `OramBucket` plaintext carriers likewise stay private to `oram.rs` rather than exposing raw storage buffers or decoded bucket/block records across module boundaries |
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
   live shadow state, hidden before/after witness snapshots, or a live return
   value should stay runtime-only or theorem-handoff-only across the
   kernel-to-state, state-to-runtime, and runtime-to-theorem boundaries.
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
reductions: `ConfidentialEntrypointPlan` is confined to `state.rs` and now
threads only the canonical confidential slot program rather than caching a
duplicate expected-kernel-step vector or a second schedule-derived
shadow-load object list, and
`RuntimeShadowState` / `ConfidentialRuntimeShadowState` remain runtime-only
types while the shell-visible handle stays `PublicRuntimeShadowState`, and
`CommittedRuntimeWitnessSnapshot` is now fully internal to `state.rs`, and the
dedicated state/theorem call-trace handoff is carried instead by
`TracedRuntimeCallStart`, `TracedRuntimeCallOutcome`, and
`TracedRuntimeCallWitnessState`. The same report now also pins the committed
and shadow object carriers themselves to the reduced representation:
`CommittedRuntimeState` and `RuntimeShadowState` now own a runtime-local
`RuntimeObjectTable` backed by a boxed fixed-order entry array over public
object ids rather than a generic `BTreeMap<u32, RuntimeObject>`. The same
report now also pins
the authority boundary on that handoff by requiring the theorem pre/post-call
bridges (`ContractRuntime::begin_traced_call(...)` and
`ContractRuntime::finish_traced_call(...)`) to be called only from
`runtime/uo-evm/src/theorem.rs` in production code, that theorem bridge now
also lives under `crate::runtime` rather than as a top-level crate module, and
the traced-call handoff types and helper methods are correspondingly restricted
to `pub(in crate::runtime)`, while the lower-level
readiness and raw snapshot helpers stay internal to `state.rs`. It
also pins `RuntimeCallOutcome` to the runtime/theorem
handoff by requiring `state.rs` and `shell.rs` to construct it, `state.rs`
to be the only production consumer of its explicit theorem-packaging API, and
`engine.rs` to avoid unpacking it directly. The same report now also pins the
new traced-call handoff bundles:
`ContractRuntime::begin_traced_call(...)` constructs
`TracedRuntimeCallStart`, `ContractRuntime::finish_traced_call(...)`
constructs `TracedRuntimeCallOutcome`, and `theorem.rs` consumes the finalized
hidden witness bundle only through
`TracedRuntimeCallOutcome::into_finalized_call_trace_parts(...)` followed by
`TracedRuntimeCallWitnessState::into_execution_trace_parts()`. Both the
internal committed-state snapshot and the finalized traced-call witness bundle
now also wipe their hidden ORAM witness vectors on drop. The old
direct snapshot-type handling path is gone. The
same report now also pins the call-trace bridge itself: `engine.rs` calls
only `run_contract_call(...)` from `runtime/uo-evm/src/runtime.rs` and no
longer imports `begin_call_trace`, `FinalizeCallTraceInput`, or
`CallTraceContext` directly; `runtime.rs` is now the only non-theorem caller
of `run_traced_call(...)`, those helper types/functions stay private to
`runtime/uo-evm/src/theorem.rs`, and the old `FinalizedCallTrace` wrapper is
gone in favor of one explicit `(return_value, aborted, trace, zero_writes)`
handoff tuple. The same report also
pins the top-level `ContractRuntime` entrypoints themselves: only
`runtime/uo-evm/src/shell.rs` may prepare, commit, or replace the public
shadow wrapper, that shell module now lives under `crate::runtime` rather than
as a top-level crate module, the `PublicRuntimeKernel` facade is likewise now
restricted to `pub(in crate::runtime)`, and only
`runtime/uo-evm/src/theorem.rs` may invoke
`runtime.run_confidential_entrypoint(...)` inside the traced-call bridge.
For confidential calls, that same theorem finalizer now also re-derives the
runtime refinement witness, canonically retags it for the single-seed paper
route, and rebuilds the explicit `SeededRuntimePaperMainFamilyBundle` and
`SeededRuntimePaperMainSlotFamilyBundle` before returning the trace, so the
production runtime path now rechecks both paper-route theorem objects instead
of leaving them solely to offline probe validation.
The same report now also pins the residual raw public-field surface in the
runtime hot path: after the `MapEntry` / `OramState` / `OramTranscript` /
`OramCommit` / `OramWrite` / `OramStorage` / `OramBlock` / `OramBucket`
closures, the only remaining direct `pub` struct fields in those runtime
modules are the public-shape `OramParameters` fields, and any reintroduction of
raw secret-bearing public fields is treated as a regression.

This document should be updated whenever a new secret-bearing structure is
introduced or an existing one is removed.
