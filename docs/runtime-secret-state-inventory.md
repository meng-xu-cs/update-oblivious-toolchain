# Runtime Secret-State Inventory

This note records the current secret-bearing runtime structures that still
exist in the Rust implementation and where they are supposed to live.

The goal is not to pretend the runtime is already fully verified. The goal is
to make the remaining confidential surface explicit, small, and auditable while
the remaining semantics-of-Rust refinement step below the checked
source-plus-finish-slot shared-kernel boundary is still being completed.
The checked source interface now also pins the shared `uo-core` crate-root
export shell in `crates/uo-core/src/lib.rs`, so theorem-carrying public wrappers
stay visible there while the generated confidential-kernel module itself stays
non-exported. The direct machine-finish proof-grade route also now surfaces the
remaining below-interface target explicitly through
`RuntimePaperNativeKernelAssumptions` and marks that projection in emitted
validation output as `paper_native_kernel_assumptions_theorem_checked`. That
paper-native bundle now stores only the source-side confinement fact plus the
native machine-finish boundary object; Lean derives the kernel-state and
shell-trace refinement facts from that boundary and emits
`paper_native_kernel_state_refinement_theorem_checked` and
`paper_native_shell_trace_refinement_theorem_checked` for those projections. The
same direct machine report now also marks the derived store/ORAM codec-layout
facts as checked: `store_codec_transport_shape_theorem_checked`,
`store_codec_decode_sound_theorem_checked`,
`store_codec_decode_into_roundtrip_theorem_checked`,
`store_codec_decode_into_rejects_length_mismatch_theorem_checked`,
`store_codec_decode_into_sound_theorem_checked`,
`store_sealed_encoded_len_theorem_checked`,
`store_sealed_record_decode_shape_theorem_checked`,
`store_sealed_record_open_shape_theorem_checked`,
`store_sealed_record_open_transport_sound_theorem_checked`,
`store_sealed_record_transport_roundtrip_theorem_checked`,
`oram_block_codec_roundtrip_theorem_checked`,
`oram_exact_block_codec_roundtrip_theorem_checked`,
`oram_exact_block_decode_length_theorem_checked`,
`oram_exact_block_decode_valid_shape_theorem_checked`,
`oram_bucket_codec_length_theorem_checked`,
`oram_directory_pages_reject_count_mismatch_theorem_checked`,
`oram_buckets_reject_count_mismatch_theorem_checked`,
`path_position_map_buffer_rejects_count_mismatch_theorem_checked`,
`path_live_slots_reject_count_mismatch_theorem_checked`,
`oram_exact_bucket_decode_acceptance_theorem_checked`,
`oram_exact_bucket_decode_block_valid_shapes_theorem_checked`,
`path_bucket_bounded_decode_shape_theorem_checked`,
`path_bucket_path_bounded_decode_shape_theorem_checked`,
`path_bucket_position_map_bounded_decode_shape_theorem_checked`,
`path_bucket_unique_position_map_bounded_decode_shape_theorem_checked`,
`path_position_map_live_slot_coverage_theorem_checked`,
`path_blocks_position_map_agreement_theorem_checked`,
`path_blocks_no_duplicate_live_slots_theorem_checked`,
`oram_decoded_bucket_payload_acceptance_theorem_checked`,
`path_position_map_pages_cover_capacity_theorem_checked`,
`path_metadata_page_split_theorem_checked`,
`path_position_map_decode_acceptance_theorem_checked`,
`path_position_map_page_decode_acceptance_theorem_checked`,
`path_position_map_pages_decode_acceptance_theorem_checked`,
`path_position_map_page_length_theorem_checked`,
`path_position_map_page_rejects_length_mismatch_theorem_checked`,
`path_position_map_pages_rejects_page_count_mismatch_theorem_checked`,
`path_stash_page_decode_acceptance_theorem_checked`,
`path_stash_page_decode_block_valid_shapes_theorem_checked`,
`path_stash_pages_decode_shape_theorem_checked`,
`path_stash_pages_bounded_decode_shape_theorem_checked`,
`path_stash_pages_position_map_bounded_decode_shape_theorem_checked`,
`path_stash_pages_unique_position_map_bounded_decode_shape_theorem_checked`, and
`path_stash_page_length_theorem_checked`,
`path_stash_page_rejects_length_mismatch_theorem_checked`, and
`path_stash_pages_rejects_page_count_mismatch_theorem_checked`. These are
theorem-surface facts
derived from the residual helper-shell boundary, not additional runtime
assumptions. The same focused machine-confinement report now also exposes
source-side runtime hardening bits:
`oram_write_batch_iteration_is_checked` for the checked ORAM write-batch
consumer path. That bit now pins fallible public-prefix access on both sides:
generated write-log pushes use `log.writes.get_mut(log.len)`, generated
exact-batch finishing checks prefix slots with `log.writes.get(index)`, and
handwritten `OramWriteBatch::for_each_write(...)` uses
`self.writes.get(index)` rather than direct indexing before exposing a write to
the trace visitor. The report also records
`handwritten_runtime_production_avoids_panic_style_control_flow` for the
production `engine.rs` / `shell.rs` / `state.rs` / `objects.rs` / `oram.rs`
surface after `#[cfg(test)]` stripping. The stronger
`runtime_interface_production_avoids_panic_style_control_flow` bit now extends
that no-`expect`/no-`unwrap`/no-`panic!` condition to the whole production
`RuntimeImplementationInterface`, including `uo-allocator`, `uo-store`,
generated helpers, and shared `uo-core` trace/types support. The direct
runtime implementation checker now also exposes
`handwritten_host_coordination_lacks_secret_serialization_theorem_checked`:
the handwritten host-coordination slice and non-generated shared core
proof/evidence/type carriers, excluding the public shell and Lean-generated
helpers, are checked to contain no Keccak/canonical serialization, direct
confidential value operations, hidden option materialization,
`Value::zero_for_type(...)`, or `MapEntry::new(...)`. The public shell remains
governed by the separate
public-only/confidential-call rejection theorem, and the interface report now
emits
`public_shell_canonical_hashing_guarded_by_public_entry_theorem_checked` to
pin the shell's remaining `Expr::Keccak256` canonical hashing path behind the
ordered `eval_expr` confidential-function rejection; the direct
kernel-machine scenarios emit the same bit next to the public-bridge theorem
bit. The live controller recorder now keeps page/workset region budgets in a
fixed public `ControllerRegionCounters` table and derives per-object ORAM
access counts from the observed public schedule, so it no longer carries the
old generic `BTreeMap` budget/counting state on the controller observer path.
Generated helpers remain the intentional small confidential kernel surface. The
umbrella `runtime-boundary-validation` report now also marks the matching
source-side minimization bit
`runtime_implementation_kernel_machine_confinement_paper_native_kernel_assumption_bundle_minimized`
and again accepts the current runtime secret-state inventory as complete.

As of the current WP3 state, the remaining handwritten
`uo-kernel-runtime` slot/effect adapter is not treated as free-form
confidential logic: the Lean source-backed boundary checks it as a
forwarding-only shell over generated slot support, object-store effects, and
the generated interpreter, and rejects raw confidential-argument observations
there. The same boundary pins the runtime machine's public opcode / bounded
scratch / object-store delegation / commit-schedule / finish-wipe order. Those
checks are backed by an explicit Lean `RuntimeKernelMachineSchedule` model for
the public-opcode prefix, object-store-call, bounded-scratch, commit-append,
and finish-wipe shape. The allocator transition shape is now modeled in
`RuntimeAllocatorDiscipline`; the live allocator uses a bounded
public-capacity `ResourceEventLog`, and finish telemetry carries resource
events as boxed slices. That resource-event log now also validates its public
length/capacity and populated public prefix explicitly on `finish()` rather
than relying on a prefix-populated `expect`. The live confidential statement
recorder is now the exact-capacity `RuntimeKernelStatementTrace` modeled by
`RuntimeStatementTraceDiscipline`, not a growable `Vec<String>`; the model now
tracks the recorded public trace-name list, proves capacity rejection,
per-record public trace-name append, and exact boxed-trace equality with the
slot program statement trace. The live recorder records through checked
`get_mut(...)` slots and finishes/drops initialized entries through
iterator-limited fixed buffers rather than direct `trace[index]` /
`self.statements[index]` access or initialized-prefix slicing. The shared
confidential-kernel DSL carriers have also been tightened: named/slot program
bodies and Keccak part lists are boxed fixed-shape slices, and named-to-slot
lowering fills them through `FixedBoxBuilder` rather than temporary growable
`Vec` collection. The shared kernel-step buffer uses checked-slot push,
iterator finish moves, and iterator-limited drop cleanup rather than direct
uninit-slot indexing or initialized-prefix slicing, and slot-program statement
traces are materialized by body iteration rather than direct `self.body[index]`
reads. The shared `uo-core` value layer now uses 64-bit canonical
length prefixes for aggregate value encoding/decoding, and proof-object JSON /
trace-hash helpers return fallible results instead of panicking on serialization
or integer-width assumptions. The
object-store side now also has source-pinned/model-backed cuts for
fixed-public-batch Path-ORAM write evidence (`RuntimeOramWriteLogDiscipline`),
masked full-scan UO small-map lookup (`RuntimeSmallMapLookupDiscipline`) with
exact matched-fold semantics and public-capacity length rejection, and
masked full-scan UO array reads/writes with executable selected-slot
acceptance/rejection/uniqueness plus out-of-range no-match/no-op behavior
(`RuntimeArrayAccessDiscipline`). The Path-ORAM write-evidence model
now also distinguishes the generated update-only push from generic write
classification: update pushes preserve `zeroWrites = 0`, and the source
boundary rejects generated ORAM write evidence that inspects ciphertext bytes
with `PhysicalWriteEvent::from_buffers` or `classify_write`. The same model
now proves write/update/read-transcript pushes reject at public capacity,
preserve capacity/overflow state on accepted pushes, and update only their
public length and zero-write counters before exact public-capacity finish.
Generated
confidential-kernel slots
also reject non-final source returns before lowering and use a modeled public
return-tail schedule (`RuntimeReturnScheduleDiscipline`) rather than a generated
post-return `state.returned` / `break` path. The current map read/write path
also keeps deterministic small-map/ORAM insert-capacity, selected-slot update,
and Path-ORAM working-stash failure inside the modeled confidential-kernel
result: generated object/ORAM helpers return overflow/update-failed bits and
the generated interpreter folds them through the generated
`note_abort_generated(...)` masked-abort helper, while the source boundary
rejects the old secret-conditioned generated `bail!` branches and direct
handwritten confidential value operations. The
residual helper-shell boundary now also carries an explicit host-visible error
taxonomy: remaining generated `Result` errors must be public-shape,
public-capacity, authenticated-decode/integrity, cold-restore, fresh-coin tape,
or write-log discipline failures, not deterministic hidden-state capacity or
update misses. These checks reduce the residual
unproved runtime surface to the remaining native object-store implementation
semantics plus the modeled/source-pinned machine, allocator, statement-trace,
ORAM-write-log, small-map-lookup, array-access, and return-tail schedules until
a native semantics-of-Rust refinement theorem replaces the source check.

## Inventory

| Structure | Location | Intended owner | Why it is confidential | Current boundary |
| --- | --- | --- | --- | --- |
| `ConfidentialCallInputs` | `runtime/uo-kernel-runtime/src/generated_slot_support.rs` | Lean-generated private shared `uo-kernel-runtime` slot-support module, consumed by `RuntimeKernelSlotCall` | confidential entrypoint arguments may contain secrets before the kernel slot file is initialized | `engine.rs` can read only the projected `PublicCallSummary`; it boxes call args once into a fixed-size slice for the traced-call/runtime path, `state.rs` passes that boxed payload directly into `RuntimeKernelMachine::run_confidential_call(...)`, and the shared kernel runtime wraps it as generated `ConfidentialCallInputs` before staging slots for the generated `uo-core` interpreter; the wrapper is private, non-`Clone`, exact-source checked against `GenerateRuntimeKernelSlotSupportRust`, buffered `Value`s wipe on drop, and Lean now models the executable staging result, including rejection of argument-count mismatch and public slot-capacity overflow |
| `PathOramFreshCoinPlan` | `runtime/uo-evm/src/fresh_coins.rs` | `crate::runtime` plus a diagnostics-gated opaque public API handle | injected fresh-leaf choices determine hidden ORAM randomness | `engine.rs` passes the opaque handle through but does not touch the internal per-object fresh-coin entry table; the handle is non-`Clone`, consumed by value, and moved into the live shadow state without cloning the per-object tapes first; the plan now stores those tapes in boxed per-object entries rather than a generic map, the public injection API is absent from the default surface, and the checked `RuntimeImplementationInterface` / `SmallConfidentialKernelBoundary` now import `fresh_coins.rs` directly and reject `path_oram_fresh_coin_plan_surface_drift` |
| `ConfidentialKernelSlotState` | `runtime/uo-kernel-runtime/src/generated_slot_support.rs` | Lean-generated private shared `uo-kernel-runtime` slot-file state, owned by `RuntimeKernelSlotCall` | live confidential slot values during confidential-kernel execution | the generated slot-support module owns the boxed fixed-size slot buffer, wipe-on-drop semantics, and confidential-argument staging before delegating into `uo_core::execute_confidential_kernel_slot_program(...)`; `RuntimeKernelSlotCall` keeps only the private runtime adapter/live slot-word accounting, `uo-evm` no longer keeps any runtime-local slot-state wrapper, and `uo-core` no longer exposes a public call wrapper or slot-state type; successful staging is now proved to satisfy the Lean `StagesCallInputs` relation |
| `Value` aggregate payloads | `crates/uo-core/src/types.rs` | shared `uo-core` runtime value layer | recursive struct fields and array elements may carry confidential logical state while values are staged through the kernel/object/runtime layers | both struct fields and array elements now use boxed fixed-size buffers rather than growable `Vec` carriers, canonical payload extraction now goes through an exact-size boxed helper, and the generated `canonical_bytes()` `Vec` convenience method is test-only rather than part of the production runtime value surface, so recursive aggregate values do not reopen a generic growable container while they cross the confidential runtime/object boundary; the generated `generated_value_ops.rs` layer now also routes struct-field zero materialization, canonical byte-buffer writes, scalar canonical decoding, length-word parsing, `u128` tail writes, and masked byte-array select/equality through checked-range and iterator helpers, with the source boundary rejecting stale direct `fields[index]`, `copy_from_slice(...)`, fixed-slice, and per-byte index loops; the shared handwritten `FixedBoxBuilder<T>` under boxed value construction uses iterator initialization, checked `get_mut(...)` push, and iterator-limited drop cleanup rather than direct uninit-slot indexing or initialized-prefix slicing |
| `RuntimeCallOutcome` | `crates/uo-core/src/trace.rs` | shared `uo-core` theorem-handoff wrapper | per-call runtime finish-bundle state plus the live return value remain bundled until the traced-call theorem handoff is assembled | shared explicit API; non-`Clone`; constructed only from `shell.rs` and `state.rs` through `RuntimeCallOutcome::from_runtime_execution(...)`, consumed only through shared `uo-core` finalization helpers, and absent from `engine.rs` |
| `TracedRuntimeCallStart` | `crates/uo-core/src/trace.rs` | shared `uo-core` theorem-handoff wrapper | theorem-facing pre-call token that carries the hidden committed-state snapshot without exposing the raw snapshot type | shared explicit API; non-`Clone`; produced only by `ContractRuntime::begin_traced_call(...)`, stored only in theorem-local call-trace context, and absent from `engine.rs` |
| `TracedRuntimeCallOutcome` | `crates/uo-core/src/trace.rs` | shared `uo-core` theorem-handoff wrapper | post-call hidden witness snapshot plus the bundled runtime outcome remain secret-bearing until final execution-trace packaging | shared explicit API; non-`Clone`; constructed only by `ContractRuntime::finish_traced_call(...)`, consumed in `theorem.rs` only through `into_finalized_call_trace_parts(...)`, and absent from `engine.rs` |
| `FinalizedRuntimeCallTraceParts` | `crates/uo-core/src/trace.rs` | shared `uo-core` theorem-handoff wrapper | bundles the runtime outcome together with the finalized hidden before/after ORAM witness state for one traced call | shared explicit API; non-`Clone`; constructed only by `TracedRuntimeCallOutcome::into_finalized_call_trace_parts(...)`, consumed in `theorem.rs` only through `into_execution_trace_inputs()`, and absent from `engine.rs` |
| `TracedRuntimeCallWitnessState` | `crates/uo-core/src/trace.rs` | shared `uo-core` theorem-handoff wrapper | finalized before/after hidden ORAM witness bundle for execution-trace packaging | shared explicit API; non-`Clone`; produced only inside `FinalizedRuntimeCallTraceParts`, consumed only through the shared `uo-core` `RuntimePublicCallTraceBundle::into_runtime_finalization_input(...)` path rather than directly in `theorem.rs`, absent from `engine.rs`, stored in boxed fixed-size buffers for the public-bounded witness set, and its hidden witnesses wipe on drop |
| `RuntimeShadowState`, `ConfidentialRuntimeShadowState`, `PublicRuntimeShadowState` | `runtime/uo-evm/src/state.rs` | `crate::runtime` | live reopened confidential object state for one call, with separate wrappers for the confidential kernel path and the public shell path | raw shadow state and the confidential shadow wrapper are now visibility-restricted to `crate::runtime`; the shell sees only `PublicRuntimeShadowState`, while confidential execution uses `ConfidentialRuntimeShadowState` only behind `ContractRuntime`; the underlying loaded-object carrier is no longer a generic map but a fixed-order boxed table keyed by the public object universe, object-operation / commit / confidential shadow-load hooks now route through the shared `uo-kernel-runtime` store interfaces implemented in `state.rs`, and the live public-object bootstrap / admitted-schedule / runtime-phase bookkeeping around those shadows now routes through the shared `uo-core` `RuntimeKernelBoundaryTracker` rather than a runtime-local tracker split; the tracker-owned kernel-step and runtime-phase journals now use fixed-capacity boxed `BoundedJournal<T>` storage instead of growable `Vec` fields |
| `CommittedRuntimeWitnessSnapshot` | `crates/uo-core/src/trace.rs` | shared `uo-core` hidden-witness snapshot wrapper, built only by `state.rs` | hidden ORAM access-counter and position-map witness state from committed storage before and after a call | shared explicit API; non-`Clone`; `state.rs` is the only production builder through `CommittedRuntimeState::witness_snapshot(...)`, theorem-facing code sees only the traced-call handoff bundles rather than the raw snapshot type, the hidden witness carriers are boxed fixed-size buffers for the public-bounded ORAM witness set, and those hidden witness buffers wipe on drop |
| `RuntimeObject` graph | `runtime/uo-evm/src/objects.rs` | `crate::runtime` | object-local confidential logical state and commit/restore paths | non-`Clone`; low-level helpers restricted to `crate::runtime`; secret-bearing ciphertext slots in the object graph now use boxed fixed buffers, including the raw-backend `RawMapEntry` slot; confidential entrypoints are admitted only if every object id in the kernel-step schedule resolves to a UO backend, and the direct Lean proof-grade translation checker exports the matching non-raw target theorem, so raw objects cannot sit on the confidential execution path even when they are public state objects; UO array public write bookkeeping uses fixed-size boxed flags rather than a growable `BTreeSet` of written indices; UO small-map lookup and UO array read/write use masked full-capacity scans rather than early exit or direct indexing, and UO array out-of-range logical indices become masked no-match/no-op cases on the UO path rather than public errors; the remaining handwritten raw array get/set and commit shell now guards public value/physical/written-flag slots with `get(...)` / `get_mut(...)`, UO array and small-map commit callbacks touch physical slots only after checked public schedule lookups, UO small-map scan tracing uses fallible physical-slot lookup, and the source-backed interface rejects stale `values[index]`, `physical_slots[index]`, and `written_slots[index]` forms in `objects.rs` |
| `OramState` | `runtime/uo-evm/src/oram.rs` | `crate::runtime` | live ORAM entries, position map, stash, access counter, leaf-coin source, and public-shape read/write evidence | `OramState` now keeps its own fields private and exposes only explicit runtime-facing queries (`is_cold()`, `parameters()`, `path_bucket_count()`, `path_position_map_witness(...)`) plus the mutation/commit APIs already owned by `oram.rs`; the shared `MapEntry` record now also keeps private fields and crosses the small-map / ORAM code paths only through explicit entry methods (`new`, `is_occupied`, `matches_key`, `value`, `set_value`, `set_vacant`, `occupy`); `OramTranscript` / `OramCommit` / `OramWrite` likewise keep private fields and cross into `objects.rs` only through `into_runtime_trace_parts(...)`, `into_object_commit_parts(...)`, and `with_object(...)`; `OramTranscript` stores logical/physical-read evidence as boxed arrays materialized by the generated codec layer through fallible fixed builders sized by the public `public_access_count`, while handwritten `oram.rs` never owns growable transcript buffers; the internal `OramStorage` / `OramBlock` / `OramBucket` plaintext carriers likewise stay private to `oram.rs` rather than exposing raw storage buffers or decoded bucket/block records across module boundaries; the exact-size map-record, directory-page, scalar metadata, block, bucket, stash-page, and Path-ORAM metadata codec plus masked Path-ORAM selector/update/rebuild logic now live in the generated helper layer rather than handwritten `oram.rs`, generated metadata decode checks public position-map/stash page counts before indexing and uses fallible `pages.get(...)` access, generated metadata encode fills sealed page slots through fallible `pages.get_mut(next_page)` access, generated map-record/directory, block, bucket, counter, stash-page, and position-map byte codecs route fixed-offset reads and writes through checked `read_exact_range` / `write_exact_range`, `read_u64_be_at` / `write_u64_be_at`, and `get_mut(...)` helper paths with checked bucket-payload and directory-record windows instead of direct byte indexing, local copy staging, fixed-offset slicing, or decoded-slot assignment, generated transcript/open/reseal helpers check public directory-page and bucket counts before storage access through `get(...)` / `get_mut(...)`, surrogate directory decode takes its remaining public tail through `entries.get_mut(next_entry_index..)`, generated bucket/position-map decode and live-bucket construction write decoded public slots through `fixed_blocks.get_mut(slot)` / `position_map.get_mut(next_slot)`, live Path-ORAM bucket validation checks public position-map/live-slot buffer lengths before decoded-slot access through `position_map.get(...)`, `live_slots.get(...)`, and `live_slots.get_mut(...)`, and generated ORAM write-log production uses fallible public-prefix `log.writes.get_mut(log.len)` / `log.writes.get(index)` access before handing an exact batch to handwritten consumers; the position-map `MaskedUsizeOption` entries are non-`Clone`/non-`Copy` with clone/assign/select/repeat routed through typed generated borrowed helpers instead of a generic `repeat_boxed<T: Clone>` surface; Lean now exposes exact-bucket decode acceptance tying bucket byte length, expected header index, exact block decoding, live-count agreement, and aggregate decoded bucket-block valid shapes together, bounded Path bucket decode for occupied block slot/leaf bounds, public bucket-on-leaf-path membership, decoded position-map agreement, duplicate live-slot rejection, position-map live-slot coverage, and generic whole-block-list position-map agreement/no-duplicate hooks, plus the public Path-ORAM metadata page split, position-map/stash page byte-length mismatch rejection, aggregate position-map/stash page-count mismatch rejection, public directory-page, bucket, position-map-buffer, and live-slot-buffer count mismatch rejection, exact stash-page decode acceptance, aggregate stash-pages decode shape/block validity, bounded aggregate stash decode for public stash/slot/leaf bounds, stash position-map agreement, stash duplicate live-slot rejection, and both per-page and aggregate position-map capacity/leaf bounds; the handwritten `oram.rs` shell is reduced to public geometry, witness/export plumbing, and generated-helper dispatch; ORAM commit write evidence is emitted through fixed-public-batch `OramWriteBatch` / `OramWriteLog` values filled by the generated `reseal_oram_payload_and_record_write` helper, and each write now carries only the public location, length, and `WriteClass::Update` rather than prior/new ciphertext snapshots or a growable write vector; handwritten consumers enumerate those batches only with `OramWriteBatch::for_each_write(...)`, which checks public length/capacity, uses fallible `self.writes.get(index)` public-prefix access, and requires populated public-prefix entries before recording physical writes, while the source-backed boundary rejects the old direct-index, direct fixed-offset ORAM byte indexing/slicing, local ORAM byte-copy staging, direct map-record slicing/slot assignment, and lossy `filter_map(Option::as_ref)` iterator paths |
| `StoreCipher` key and plaintext staging buffers | `runtime/uo-store/src/codec.rs`, `runtime/uo-store/src/generated_codec.rs`, `runtime/uo-store/src/generated_surface.rs`, `runtime/uo-store/src/generated_store_helpers.rs`, `runtime/uo-store/src/store.rs` | store/codec layer | sealing keys and temporary plaintext buffers | the exact-size seal/open/filler surface now lives in the Lean-generated `generated_surface.rs` module, the boxed-filler / seal-into helper shell lives in the Lean-generated `generated_store_helpers.rs` module, handwritten `codec.rs` / `store.rs` are reduced to public-only shells that route through those generated helpers rather than carrying handwritten confidential seal/open/reseal logic, and raw/UO slot storage now uses the generated boxed `StoreSlotTable` with public linear lookup rather than handwritten `BTreeMap<String, Box<[u8]>>` storage in `store.rs`; the public store evidence buffers in `store.rs` are now opaque generated `StorePhysicalWriteTrace` / `StoreLogicalEventTrace` wrappers, so handwritten store definitions no longer expose raw `Vec<PhysicalWriteEvent>` or `Vec<LogicalEvent>` trace fields, and those generated wrappers now use exact boxed-slice backing with fallible fixed-builder appends rather than `Vec` storage; the generated store surface is now checked to avoid `expect`, `unwrap`, and `panic!`; the generated store-surface reopen path uses checked cursor/range helpers for magic/nonce/ciphertext/tag parsing and a checked exact-copy helper for boxed plaintext staging rather than direct `split_at(...)` and `payload.copy_from_slice(...)`; the generated nonzero transport codec now uses checked public output windows, chunk-local `get_mut(...)`, and `zip(out.iter_mut())` instead of direct `out[index * 2]` / `out[index]` writes, and Lean exposes fixed-public-length nonzero decode-into roundtrip, encoded-length-mismatch rejection, decoded-byte/nonzero-nibble soundness, sealed-record split/open transport soundness, and sealed-record transport roundtrip as theorem-surface facts |

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
3. Confidential expression execution should live on the shared
   `RuntimeKernelMachine` / `uo-core` confidential-kernel path.
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
reductions: the old runtime-local `ConfidentialEntrypointPlan` is gone, and
`state.rs` now consumes one shared `uo-core`
`RuntimeConfidentialEntrypointPlan` produced by
`EntrypointManifest::runtime_confidential_entrypoint_plan(...)`, so the
checked confidential slot program, public object universe, kernel-op budget,
commit budget, and hash-scratch bound now come from one shared admission
object rather than local manifest-to-kernel repacking in `state.rs`, and
`RuntimeShadowState` / `ConfidentialRuntimeShadowState` remain runtime-only
types while the shell-visible handle stays `PublicRuntimeShadowState`, and
the hidden witness snapshot collection loop stays internal to `state.rs`, but
the exact-size snapshot builder plus the snapshot wrapper itself now live in
shared `uo-core`, and the dedicated
state/theorem call-trace handoff is carried by shared `uo-core`
`CommittedRuntimeWitnessSnapshot`, `TracedRuntimeCallStart`,
`TracedRuntimeCallOutcome`, `RuntimeCallOutcome`,
`FinalizedRuntimeCallTraceParts`, and `TracedRuntimeCallWitnessState`. The same report now also pins the committed
and shadow object carriers themselves to the reduced representation:
`CommittedRuntimeState` and `RuntimeShadowState` now own a runtime-local
`RuntimeObjectTable` backed by a boxed fixed-order entry array over public
object ids rather than a generic `BTreeMap<u32, RuntimeObject>`, and
`RuntimeObjectTable` resolves public object ids through fallible
`entries.get(...)` / `entries.get_mut(...)` after the public scan instead of
direct `entries[index]` indexing. The same
report now also pins
the authority boundary on that handoff by requiring the theorem pre/post-call
bridges (`ContractRuntime::begin_traced_call(...)` and
`ContractRuntime::finish_traced_call(...)`) to be called only from
`runtime/uo-evm/src/theorem.rs` in production code, that theorem bridge now
 also lives under `crate::runtime` rather than as a top-level crate module, and
 the runtime-owned readiness checks plus the raw witness-extraction loop stay
internal to `state.rs`, while the smaller shared `uo-core` traced-call snapshot/start/
outcome/witness/finalization carriers expose only explicit constructor/
consumer APIs. It
also pins `RuntimeCallOutcome` to the runtime/theorem
handoff by requiring `state.rs` and `shell.rs` to construct the shared
`uo-core` wrapper, the shared finalization path in `uo-core` to be the only
production consumer of its theorem-packaging API, and
`engine.rs` to avoid unpacking it directly. The same report now also pins the
new traced-call handoff bundles:
`ContractRuntime::begin_traced_call(...)` constructs shared `uo-core`
`TracedRuntimeCallStart`, `ContractRuntime::finish_traced_call(...)`
constructs shared `uo-core` `TracedRuntimeCallOutcome`,
`TracedRuntimeCallOutcome::into_finalized_call_trace_parts(...)` upgrades that
shared traced-call state into the shared `uo-core`
`FinalizedRuntimeCallTraceParts`, and `theorem.rs` consumes the finalized
hidden witness bundle only through
`FinalizedRuntimeCallTraceParts::into_execution_trace_inputs()`, while the
final shared `uo-core`
`RuntimePublicCallTraceBundle::into_runtime_finalization_input(...)` step
consumes the hidden witness carrier together with the public trace bundle to
materialize `RuntimeExecutionTraceFinalizationInput`. Both the
shared committed-state snapshot wrapper and the finalized traced-call witness bundle
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
`SeededRuntimePaperMainSlotFamilyBundle` before returning the trace. The
stronger slot-family bundle now also carries the exact emitted confidential
`opcode_trace` and rechecks it against the admitted slot-program statement
trace names, so the production runtime path now rechecks both paper-route
theorem objects instead of leaving them solely to offline probe validation.
The same report now also pins the residual raw public-field surface in the
runtime hot path: after the `MapEntry` / `OramState` / `OramTranscript` /
`OramCommit` / `OramWrite` / `OramStorage` / `OramBlock` / `OramBucket`
closures, the only remaining direct `pub` struct fields in those runtime
modules are the public-shape `OramParameters` fields, and any reintroduction of
raw secret-bearing public fields is treated as a regression.
The same report now also checks one concrete artifact consequence of that
boundary discipline: confidential `ExecutionTrace` serialization must omit the
redundant raw `runtime_kernel_witness` and
`runtime_kernel_refinement_witness` keys when a checked
`RuntimeKernelFinishBundle` is present, so exported traces keep only the
smaller finish-boundary artifact and reconstruct exact witnesses on demand.
The same API shrink has now removed the old raw stored trusted-kernel /
controller accessors and the raw ORAM object / leaf / position-map /
after-counter accessors plus the raw `ExecutionTrace::refinement_trace()`
getter from the public trace surface as well; the only direct ORAM fact still
exported on `ExecutionTrace` is the theorem-facing public pre-call
access-counter map used by the canonical fresh-coin / pair route. That route's
own fixed-shape theorem artifacts are now boxed too: seeded/canonical witness
families keep their witness lists and public scaffolds boxed, paper-main
family bundles keep the explicit boundary schedule boxed, and
`RuntimeRefinementWitness` fresh-coin scaffold/value extraction now returns
boxed slices rather than reopening hidden-seed structure as `Vec`. The
exported `RuntimeShellContract`, `RuntimeShellTrace`, and
`RuntimeKernelInterfaceBundle` now follow that same fixed-shape discipline for
their public schedules, shell-event summaries, and expected-step lists, and
the shared exported `RuntimeKernelScheduleWitness` now keeps its opcode trace
and step list boxed too. The exported `RuntimeKernelWitness` now likewise
keeps its resource trace, emitted/expected kernel-step lists, and
emitted/expected public-object schedules boxed. The same anti-drift report now
also pins the public controller-observer boundary itself: production
`uo-evm` must route controller/theorem observer reconstruction through the
shared `uo-core`
`RuntimeControllerObserverCertificate::from_runtime_observer_with_oram_accesses(...)`
interface, which now also rebuilds the controller certificate from the
recorded public ORAM access witness sequence inside `uo-core`, and the
production runtime path must not reintroduce local `RuntimeControllerCertificate`,
`SgxControllerShapeTrace`, `PublicOutcomeTrace`, `BoundaryEvent`,
`OutputShape`, or `TheoremTrace` theorem-facing assembly logic for that
observer path.

This document should be updated whenever a new secret-bearing structure is
introduced or an existing one is removed.
