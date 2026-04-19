# UO Toolchain Artifact Results

This results bundle was generated from the local Rust workspace using the benchmark suite under `benches/raw/`.

The generated reports now also include `witness_validation.json`, which checks
representative theorem-backed runtime refinement witnesses against the
proof-grade Lean-side validator that now requires an exact embedded
artifact-derived confidential kernel-op trace plus an exact embedded public
kernel-step trace over `{ opcode, object_id? }`, and now also requires that
this admitted public schedule replay successfully to a finished state under the
modeled small-kernel semantics while fixing the exact final public object-id
schedule reconstructed from that replay. The proof-grade kernel witness now
also carries an explicit public resource-event trace over stack checks,
scratch reservations, and scratch wipes; Lean replays that trace against the
budget fields and the report summaries expose the emitted resource-event trace
directly alongside the exact claimed replayed resource state plus the emitted
and expected public object universe. The same witness report now also exposes
the lower-level runtime phase witness that bridges the concrete runtime back to
the small kernel ABI, including its exact pre/post committed-cold object
schedules over that public object universe, its shadow-load schedule,
commit-object schedule, cold-store schedule, the canonical loaded object
schedule reconstructed from the exported kernel witness, and the facts that
its projected kernel schedule matches that public kernel witness, that the
boundary schedules both match the full public object universe, and that the
loaded, committed, and cold-stored object sets all match the canonical
touched-object set. The Lean development now also packages that bridge as an
explicit `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem: the
real shell trace outside the confidential kernel is fixed by the public object
universe plus the canonical touched-object set induced by the public kernel
schedule. The exported shell trace now also carries the ordered public
runtime-phase event sequence itself, and the Rust/Lean checkers validate that
its summary schedules are honest projections and that the event trace replays
that public shell contract; the witness summaries now expose that
theorem-facing object
directly as a shell-contract summary plus a `refines_shell_contract` flag, with
direct exactness lemmas still available for the kernel witness's public object
universe and for the runtime phase witness's pre/post boundary schedules.
That post-call `cold_store_object` / `post_committed_cold_object` phase tail is
now also finalized behind the runtime state boundary instead of being assembled
in `engine.rs`, and the post-call proof-facing `ExecutionTrace` packaging now
also lives in `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer
constructs the controller-observer certificate, hidden Path-ORAM certificate,
or trusted-kernel bundle directly. Confidential expression and
statement interpretation for admitted entrypoints now also runs inside
`RuntimeKernel`, while the non-confidential interpreter now lives in the
explicit `runtime/uo-evm/src/shell.rs` module, so `engine.rs` is reduced to
public orchestration and the secret-bearing execution state sits behind the
smaller kernel boundary. That
confidential interpreter now also executes a slot-lowered kernel DSL rather
than a string-keyed env: admitted entrypoints are lowered to fixed slots in
`uo-core`, and `RuntimeKernel` stores live confidential values in a bounded
`Vec<Option<Value>>` slot file rather than a `BTreeMap<String, Value>`. The
low-level runtime object transition helpers that reopen shadow
state, commit objects, export hidden ORAM witnesses, and cold-store committed
state are now also compile-time restricted to the shared `crate::runtime`
module, and `RuntimeObject` no longer implements `Clone`, so those
secret-bearing paths are not directly callable from `engine.rs`. The
confidential-path `RuntimeKernel` entrypoints that shadow-load committed
state, run confidential calls, and commit public shadows are now likewise
visibility-restricted to `crate::runtime`, so the generic shell cannot call
those kernel hooks directly. `engine.rs` now delegates public execution to
`shell.rs` and confidential execution to `state.rs`; confidential
manifest-to-kernel planning is now fully internal to `ContractRuntime`, so
`engine.rs` no longer stages a `ConfidentialEntrypointPlan`, imports either
the raw `RuntimeKernel` or the public kernel facade directly, or threads the
manifest hash-scratch bound or confidential commit budget itself, and it now
derives the canonical public object universe from `ContractRuntime` rather
than the artifact-side state list while the same `ContractRuntime` boundary
now owns the ready-for-call coldness preflight over that universe as well,
and `shell.rs` now derives the public allocator plan from the manifest rather
than having the engine thread that setup detail in; the theorem-side
`begin_call_trace` path now triggers that runtime preflight rather than
`engine.rs` calling it directly, and the theorem finalizer now consumes the
whole `RuntimeCallOutcome` directly so the engine no longer unpacks kernel
witnesses, opcode traces, or return values only to feed them back into the
same theorem-path finalizer. The same report now also pins that authority
boundary directly: the runtime preflight and committed-state snapshot helpers
must appear only in `runtime/uo-evm/src/theorem.rs` in production code.
Confidential `Expr::Select` now also evaluates both admitted pure arms and
combines them with `Value::confidential_select` instead of branching on the
secret condition in Rust, while `uo-check` and the proof-grade
kernel-witness validator reject confidential select arms outside that
branchless pure fragment. Confidential `Expr::StructField` and
`Expr::ArrayIndex` are now both rejected from the admitted confidential
fragment entirely.
`runtime_boundary_validation.json` now checks that Rust-side boundary
directly by reading the runtime sources: it verifies that `engine.rs` does not
call the low-level runtime object helpers, that those helpers remain
restricted to `crate::runtime`, that `RuntimeObject` itself is not `Clone`,
that `ContractInstance::clone` goes through the cold committed-state clone
path, that `engine.rs` now holds only an opaque `ContractRuntime` wrapper and
delegates the entire public-call lifecycle to `shell.rs`, that `shell.rs`
itself stays on the `PublicRuntimeKernel` plus `PublicRuntimeShadowState`
side of the boundary while the confidential path uses its own
`ConfidentialRuntimeShadowState` wrapper instead of reusing the public shadow
handle, and that `engine.rs` no longer constructs runtime phase-witness
events directly because the post-call phase tail is finalized
behind the runtime state boundary, no longer constructs theorem-side
certificates directly, no longer assembles `ExecutionTrace` directly
beyond `runtime/uo-evm/src/theorem.rs`, and no longer performs the
public output-shape computation or theorem-trace assembly piecemeal; instead
it delegates the whole theorem-finalization path through
`run_traced_call(...)` in `runtime/uo-evm/src/theorem.rs`. The same boundary
check also rejects engine-side calls to `output_shape_of`,
`build_theorem_trace`, and `finalize_execution_trace`, while requiring the
theorem module to keep deriving the public `OutputShape` from the checked
manifest's `return_canonical_len`. `engine.rs` also no longer clones the full
call argument vector just to recover public theorem-trace fields; instead the
controller path must derive a `PublicCallSummary` from the checked manifest's
`param_names`, `secret_args`, and manifest-stored `entry_input_len`, and
`ContractRuntime` must internalize the remaining raw confidential argument
vector into `ConfidentialCallInputs`, whose unwrap surface stays restricted to
`crate::runtime` and whose buffered `Value` payload now wipes on drop; the
theorem-finalization path must avoid depending on
`CompiledFunction` entirely while the public trace path sees only the
exported `OutputShape` rather than the full return payload, and the committed
before/after ORAM witness snapshot consumed by `theorem.rs` is now captured
through the theorem-side `run_traced_call(...)` bridge rather than by
`engine.rs`, and remains opaque outside the dedicated `state.rs` /
`theorem.rs` handoff; the same theorem-side context now also owns the public
`PublicCallSummary` and `CallRecorder`, so `engine.rs` no longer constructs
those theorem-path objects directly. The same report also checks that the
proof-grade trusted-kernel path itself stays on the stronger slot-wrapped
artifact: `crates/uo-core/src/trusted_kernel.rs` must source the admitted
`confidential_slot_program` from the checked manifest, `uo-evm --format
trusted-kernel` must emit `runtime_trusted_kernel_slot_bundle`, the probe's
trusted-kernel validator must validate that same slot-wrapped artifact, and
`CheckProofGradeRuntimeTrustedKernel.lean` must load the corresponding slot
bundle checker path rather than the older bare trusted-kernel bundle loader.
The same boundary report also requires the hidden traced-call witness staging
buffers in `state.rs` to wipe on drop: both the internal committed-state ORAM
snapshot and the finalized traced-call witness bundle must clear their hidden
access-counter and position-map leaves unless they are explicitly consumed by
the theorem finalizer.
The same report also checks that the
confidential-path `RuntimeKernel` entrypoints for public shadow-loading,
public commit, and confidential execution are visibility-restricted to
`crate::runtime`, that the confidential shadow-load helper itself stays
private to `runtime/uo-evm/src/kernel.rs`, that `shell.rs` owns the
public-kernel facade while `state.rs` owns confidential execution setup
through explicit wrapper operations rather than raw `inner_mut` /
`into_inner` escape hatches, that `ConfidentialEntrypointPlan` is confined to
`runtime/uo-evm/src/state.rs`, that `RuntimeShadowState` and
`ConfidentialRuntimeShadowState` remain runtime-only while the shell-visible
handle stays `PublicRuntimeShadowState`, that only `shell.rs` may drive the
top-level `ContractRuntime` public-shadow entrypoints while only `engine.rs`
may call `runtime.run_confidential_entrypoint(...)`, and that confidential
entrypoints
are sourced from the checked manifest's `confidential_slot_program` in
`runtime/uo-evm/src/state.rs` while that module delegates confidential
execution through `runtime/uo-evm/src/kernel.rs`, enforces the
manifest-derived confidential commit budget there as well, validates the slot
program against the manifest `kernel_steps` exactly once, and then carries
that checked manifest schedule forward as the canonical public budget /
witness schedule in both the runtime and `uo-check`, and
that the production kernel executes that shared slot DSL with a slot-vector
confidential state rather than a string-keyed map, and that the kernel-step
witness journal plus the lower-level
runtime phase witness journal are both explicit bounded-capacity journals
derived from public kernel-op/object bounds rather than plain growable
`Vec::new()` traces, and that the remaining public shell-side commit /
witness lists now also start from explicit `Vec::with_capacity(...)` bounds,
and that live Path-ORAM stash state is rebuilt with public
`working_stash_capacity(...)` headroom up front, preserved across cold commits
with `.clear()`, and no longer grows mid-call through a late `reserve(...)`,
and that path-ORAM clones plus storage refresh now preserve and reuse those
public entry / position-map / stash capacities in place rather than silently
falling back to fresh zero-capacity vectors, and that touched Path-ORAM aborts
restore old state in place through `OramState::restore_from_old(...)` so
neither untouched nor aborted `UoOramMap` commits replace the whole shadow
ORAM object anymore, and that
full-scan array and
small-map cold commits clear and resize their existing logical buffers in
place, that array/small-map old-state restoration decodes back into those
same buffers rather than allocating replacement secret-bearing vectors, and
that written UO cell/array/small-map commits reuse their existing ciphertext
slot buffers in place while untouched commits keep their already-cloned
buffers instead of re-cloning old physical slots,
and that the remaining shadow-load, shadow-commit, and injected Path-ORAM
fresh-coin routing steps now live in `state.rs` rather than being assembled by
`kernel.rs`, and that confidential
`Expr::Select` routes through `Value::confidential_select` while the checker
and proof-grade kernel-witness validator both enforce the admitted
branchless-pure-arm fragment, and that checker, proof-grade validation, and
the runtime all reject confidential `Expr::StructField` and
confidential `Expr::ArrayIndex`, and that all direct confidential object API
call sites (`.get_cell`, `.set_cell`, `.get_array`, `.set_array`, `.get_map`,
`.put_map`) remain confined to `runtime/uo-evm/src/kernel.rs`. The same
report now also checks constructor authority for exported witnesses:
production runtime phase-witness events may only be constructed in
`runtime/uo-evm/src/kernel.rs` and `runtime/uo-evm/src/state.rs`, while
production resource-event witnesses may only be constructed in
`runtime/uo-allocator/src/lib.rs`. Inside the shared `crate::runtime` module,
the same report now also checks finer helper authority: secret-bearing
`RuntimeObject` reopen / commit / cold-store / witness-export / fresh-coin
helpers must be used only from `runtime/uo-evm/src/state.rs`, the
shadow-state helpers that reopen committed state or reconcile committed
shadows must be used only from `runtime/uo-evm/src/kernel.rs`, and the raw
kernel hooks `shadow_load_public_objects`, `commit_public_objects`, and
`run_confidential_call` must be invoked only from
`runtime/uo-evm/src/state.rs`. The probe-side production-source scan now also
strips `#[cfg(test)]` items without truncating later production code, so
those confinement checks continue to cover files that place test-only helpers
before additional production functions. The same report now also checks the
low-level `uo-store` helper layer: direct `StoreCipher::seal` /
`StoreCipher::open` use must stay inside `runtime/uo-store/src/codec.rs`, the
public wipe-preserving helper surface must stay at `seal_and_wipe` /
`seal_and_wipe_into` / `with_opened_payload`, the store write API must take
mutable plaintext buffers, and `StoreCipher` must zeroize its key on drop.
The runtime now also uses `seal_and_wipe_into` on written UO cell/array/
small-map commit paths plus ORAM bucket/counter rewrites, so those write
paths reuse existing sealed buffers in place where the public ciphertext shape
is already fixed. The same source-level check now also rejects regressions
back to ciphertext-snapshot write witnesses by requiring both
`PhysicalWriteEvent` and the internal ORAM write trace to retain only public
write shape (`location`, `len`, `class`) rather than `old`/`new` byte
vectors, with zero-write counts carried only as aggregate metrics instead of
per-write witness fields. `ExecutionTrace` now omits runtime telemetry
entirely, and ordinary `ContractInstance::call` results do too; the runtime
exposes the irreducible aggregate `zero_writes` count only through an
explicit feature-gated diagnostic result channel that is absent from the
default `uo-evm` surface, while `mplus-probe` derives bytes/read-write
counts, update fractions, and controller-shape counts from the raw trace
itself.
`confidential_fragment_validation.json` complements those source-level checks
with an artifact-level scan over the admitted UO benchmark suite: it counts
confidential `Select` nodes per entrypoint and confirms that the compiled
confidential bodies contain no non-branchless select arms, no confidential
`StructField`, and no confidential `ArrayIndex` forms.
`kernel_dsl_validation.json` adds the shared-DSL bridge itself to the artifact
story: for each representative confidential execution, the probe serializes
the exact lowered confidential-kernel program that Rust executes, Lean
re-derives its expected small-kernel step schedule from that DSL, and the
proof-grade runtime kernel witness must match the imported schedule exactly.
`kernel_slot_dsl_validation.json` now checks the slot-lowered half of that
same bridge directly: the probe serializes the manifest-carried fixed-slot
confidential program that `RuntimeKernel` actually executes, Lean re-derives
the same small-kernel schedule from the slot DSL, and the proof-grade runtime
kernel witness must match that slot-derived schedule exactly as well.
`kernel_lowering_validation.json` now upgrades that bridge to the runtime
kernel theorem surface: for each representative confidential execution, the
probe serializes both the manifest-carried source-named confidential program
and the manifest-carried slot confidential program, Lean validates the
imported lowering bundle, re-runs the canonical lowering algorithm over the
named DSL, and reconstructs the corresponding runtime
`RuntimeKernelLoweringBundle` whose named and slot schedules are both tied to
the same proof-grade kernel witness.
`confidential_core_validation.json` now closes that loop with a theorem-backed
joint check: for the same representative proof-grade runtime witnesses, Lean
checks both the runtime witness and the exact manifest-carried named
confidential program for the invoked entrypoint, so the shell-contract
refinement theorem is reported only for executions whose embedded kernel
witness matches the same DSL body that Rust executes. The artifact-derived
confidential-fragment witness remains in the report as a separate diagnostic
summary over the admitted fragment.
That combined checker now consumes one serialized confidential-core bundle
rather than coordinating separate witness files.
`confidential_core_slot_validation.json` now performs that same joint check
against the fixed-slot confidential program that `RuntimeKernel` executes,
so the runtime/refinement witness is tied not only to the source-named DSL
object but also to the slot-lowered kernel body that the concrete runtime
actually evaluates.
`confidential_core_shell_boundary_slot_validation.json` then lifts that
slot-only path across the shell boundary: it serializes the full runtime
witness together with the explicit shell-boundary bundle and the exact slot
confidential program for the same entrypoint, and Lean checks that the runtime
witness, shell-boundary bundle, and slot schedule all share one exact
proof-grade kernel witness and runtime phase witness without relying on the
named-to-slot lowering bundle.
`confidential_core_lowering_validation.json` then joins those two artifacts
back together: it serializes one runtime witness together with both the named
and slot confidential programs for the invoked entrypoint, requires the named
and slot bundles to pass their proof-grade Lean validators, and separately
requires Lean to recompute exactly the same slot program from the named DSL so
the exported shell/refinement witness is connected to the concrete slot
interpreter through a checker-visible canonical lowering step rather than
through Rust tests alone.
`confidential_core_shell_boundary_lowering_validation.json` lifts that
composition one layer higher: it serializes the full runtime witness together
with the explicit shell-boundary bundle and the named/slot confidential
programs for the same entrypoint, and Lean checks that the runtime witness,
shell-boundary bundle, and DSL lowering bridge all share one exact
proof-grade kernel witness and runtime phase witness rather than being
validated only as separate artifacts; the final checker therefore ties the
exported shell-refinement claim plus both the named and slot kernel schedules
to that same shared witness pair in one accepted bundle.
`kernel_model_alignment_validation.json` adds a source-level Rust/Lean
anti-drift check for the small-kernel ABI itself: it reads the Rust opcode
enum, the Rust confidential-kernel DSL enums, the Rust slot-DSL enums, and
the Rust kernel resource/refinement witness enums and checks that their
serialized vocabularies and DSL/proof-interface struct field names match the
explicit Lean opcode, confidential-DSL, slot-DSL, runtime-kernel-lowering,
runtime-confidential-core-lowering, runtime-confidential-core-shell-boundary-slot,
runtime-confidential-core-shell-boundary-lowering, runtime-trusted-kernel-slot,
runtime-shell-contract, runtime-shell-trace, runtime-shell-boundary,
runtime-shell-boundary-slot, runtime-shell-boundary-lowering, resource-event,
scratch-region, and refinement-event vocabularies exactly.
`kernel_refinement_validation.json` checks that lower-level runtime phase
witness directly against Lean together with the exact exported public kernel
witness, and
`shell_boundary_validation.json` checks the next proof-interface layer above
that witness pair: it serializes the exact exported `RuntimeShellContract`
and `RuntimeShellTrace` alongside the same proof-grade kernel witness and
runtime phase witness, and Lean checks both that those two explicit views are
exactly the contract/trace reconstructed from the witnesses, that the
shell-event trace replays the public shell contract, and that the
exported shell trace refines the exported shell contract, and
`shell_boundary_slot_validation.json` then ties that same shell-boundary
bundle directly to the exact fixed-slot confidential program that
`RuntimeKernel` executes, so Lean checks the shell-boundary refinement claim
and the slot schedule against one shared proof-grade kernel witness without
passing through the named DSL bundle, and
`shell_boundary_lowering_validation.json` then composes that shell interface
with the shared DSL/interpreter bridge: it serializes the exact shell-boundary
bundle together with the named and slot confidential programs for the same
entrypoint, and Lean checks both the shell-boundary refinement claim and the
named-to-slot lowering claim against one shared proof-grade kernel witness, and
`kernel_validation.json`, which checks the smaller standalone proof-grade
runtime kernel witness against Lean at that direct small-kernel boundary, and
`seeded_witness_validation.json`, which checks seeded path-ORAM witness
families against the Lean-side runtime-coins family validator.
`trusted_kernel_validation.json` adds the smaller theorem-facing bridge object:
it checks the proof-grade runtime trusted-kernel slot bundle against the
Lean-side validator, requiring the emitted trusted-kernel bundle to be
packaged together with the admitted fixed-slot confidential program for the
same entrypoint. Lean then checks the same exact embedded confidential
kernel-op trace plus exact public kernel-step trace, together with the same
successful modeled small-kernel replay condition and exact final public
object-id schedule, while packaging the public controller observer
certificate plus the hidden Path-ORAM certificate from which the full runtime
witness is reconstructed.
The direct kernel validator covers the same proof-grade benchmark family as the
trusted-kernel and refinement-witness validators, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
The direct runtime-phase validator covers that same proof-grade benchmark
family, so the lower-level concrete-to-kernel projection is checked on the
same multi-access and multi-object workloads.
The witness validator now also covers proof-grade path-ORAM executions beyond
`SingleAccessMap`, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
`controller_observer_validation.json` checks the direct public SGX/controller
observer certificate emitted from `ExecutionTrace` without going through the
hidden witness extractor.
That controller-observer validation now covers the same path-ORAM
multi-access and multi-object runs as well.
`pathoram_hidden_validation.json` checks the direct Path-ORAM hidden-state
certificate emitted from `ExecutionTrace` for the theorem-backed path-ORAM
benchmark vehicle, again without going through the full witness extractor.
The hidden-state validator now keys position-map certificates by `object_id`
rather than list position, which removes an accidental single-order assumption
and allows the multi-object `ERC20Lite/pathoram/transferFrom` witness to check
cleanly.
`fresh_coin_validation.json` now exercises the runtime's injected canonical
Path-ORAM fresh-coin tape interface, enumerates the full theorem-facing
fresh-coin seed space directly from the public scaffold, and invokes the Lean
fresh-coin family checker on the resulting complete family, now including the
multi-access `ConfidentialMixer/pathoram/deposit` family with its full
`262144`-seed canonical fresh-coin space. The same report now also preflights
oversized canonical fresh-coin families and, instead of stopping at
`skipped_by_budget`, falls back to a compact theorem-facing seed-space
certificate that checks one representative canonical seed together with the
full public fresh-coin scaffold and seed count.
`seeded_witness_validation.json` now also covers finite seeded path-ORAM
families beyond `SingleAccessMap`, including the multi-access
`ConfidentialMixer/pathoram/deposit` run and the multi-object
`ERC20Lite/pathoram/transferFrom` run.
`bridge_validation.json` is the focused imported-theorem engineering-bridge
report: it bundles the source-to-artifact translation checks together with the
direct controller certificate, direct hidden-state certificate, direct kernel
witness, direct runtime-phase refinement witness, explicit trusted-kernel
bundle, runtime refinement witness, and seeded witness-family
validators so the bridge status can be checked without inferring it from the
full artifact bundle.
`tamper_validation.json` complements those positive checks with end-to-end
negative evidence: it mutates representative direct controller/hidden
certificates, every proof-grade translation/runtime bridge artifact, and the
theorem-facing seeded/canonical witness-family, theorem-input, and
pair-certificate artifacts, then checks that the shipped Lean executables
reject those semantically drifted but still parseable artifacts.
`pathoram_pair_validation.json` now also checks paired seeded path-ORAM proof
input certificates beyond `SingleAccessMap`, including
`ConfidentialMixer/pathoram/deposit-pair` and
`ERC20Lite/pathoram/transferFrom-pair`. The broader `*/oram/*` benchmark
aliases now compile the same concrete `path_oram_local_posmap_v1` backend as
the explicit theorem-facing `*/pathoram/*` cases, so the witness validators
report only the `pathoram` names and do not duplicate those certificates under
the generic alias.
`canonical_pathoram_pair_validation.json` adds the canonical fresh-coin pair
certificate layer: it checks that the theorem-backed `SingleAccessMap`
Path-ORAM workloads share one common public observer across the full
canonical fresh-coin families, including the complete `256`-seed `put` family
and complete `4096`-seed `add` family. The remaining coverage gap is now
narrower: the small canonical pairs are still checked by full family
materialization, while very large canonical-pair workloads now fall back to a
compact theorem-facing pair certificate instead of being skipped. Under the
default `10 GiB` budget, the current report accepts the two `SingleAccessMap`
canonical pairs directly, and validates both
`ConfidentialMixer/pathoram/deposit-canonical-pair` and
`ERC20Lite/pathoram/transferFrom-canonical-pair` through the compact
theorem-input path with their concrete explicit-size estimates attached.
`reviewer_summary.json` plus `reviewer_summary.md` condense the current
paper-facing metrics into one machine-generated table: they record per-report
wall-clock cost, the largest materialized and estimated artifact-size fields,
the runtime overhead report, the current TCB table, explicit assumptions, and
non-empty source-line counts for the trusted Rust runtime surface plus the
repo-side Lean theorem/checker surface.

Security tiers:

- Exact-UO: `FixedSlotClassifier`, `AuthScan`, `ConfidentialMixer` full-scan, `ERC20Lite` full-scan, and `RegistryCRUD` use fixed-shape commits and normalized `M+` traces that are identical across secret variations in this instrumented abstract machine.
- Computational-UO: `ConfidentialMixer` ORAM and `ERC20Lite` ORAM use the concrete `path_oram_local_posmap_v1` backend, with fixed public controller shape, rerandomized bucket/block rewrites, and theorem-facing witness extraction on the same benchmark family.

Unsupported / rejected:

- inline assembly / Yul
- dynamic strings and dynamic bytes
- unbounded mappings and dynamic arrays without fixed public capacity
- recursion, `try/catch`, events, custom errors, `while` / `do while`, external calls, and early confidential returns

Prototype assumptions:

- `uint256` syntax is accepted, but the current executable prototype evaluates arithmetic in a bounded `u128` domain for the benchmark suite.
- The ORAM backend is an instrumented Path-ORAM-style runtime prototype with fixed public controller shape and rerandomized bucket/block rewrites; it is reported as computational-UO only.
- The guarantees are with respect to the abstract/runtime traces emitted by this artifact, including the normalized physical read/write schedules captured by the runtime, not every downstream machine-code or microarchitectural observer.


Artifact packaging mode:

- This bundle uses compact artifact mode. Canonical Path-ORAM families and pair certificates larger than the configured compact budget remain validated through theorem-input certificates instead of full explicit materialization.
- Compact budget: `10737418240` bytes. Heavy-artifact budget: `21474836480` bytes.
- Heavy artifacts are written under bundle-relative `heavy_artifacts` when heavy mode is selected.
- `reproducibility_manifest.json` records every emitted file with its bundle-relative path, byte size, and SHA-256 digest.
- `reviewer_summary.md` renders the same machine-generated reviewer table as `reviewer_summary.json` in Markdown form for paper/artifact writeups.
- `./scripts/check_probe_reproducibility.sh` reruns `mplus-probe` twice and checks that the two output directories are byte-for-byte identical.
