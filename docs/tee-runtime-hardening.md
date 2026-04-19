# TEE Runtime Hardening Track

This note revives the runtime-hardening parts of the archived runbook, but
rewrites them against the current repository rather than the bootstrap-era
"build everything from scratch" plan.

The goal of this track is stronger than the repository's current bridge claim:

- not only that emitted certificates / bundles / witnesses satisfy the Lean
  predicates
- but also that `uo-evm` itself is pushed toward the same hostile-host TEE
  adversary model instead of being treated as an opaque enclave interior

## Why This Track Exists

The current repository already has:

- an explicit runtime controller observer and theorem trace
- runtime-enforced controller / hidden / trusted-kernel / refinement-witness
  extraction
- Lean validation for those emitted artifacts

What it still does not claim is:

- that every line of the Rust runtime is formally verified
- that the entire enclave implementation already satisfies a malicious-host SGX
  execution-oblivious theorem

That gap matters if the deployment story is "run `uo-evm` inside a TEE and
claim the runtime itself is aligned with the admitted observer."

## Frozen Observer For This Track

This hardening track now works against one fixed observer rather than an
informal "TEE leakage" story:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

with:

- exact `public_outcome`
- exact `boundary_schedule`
- backend-handled `storage_trace`
- SGX-specific `micro_trace` normalized and simulated from `L_sgx_micro`

This means the runtime-hardening task is not "emit some witness that looks
reasonable." It is:

1. reduce the real secret-dependent runtime to a tiny confidential kernel
2. prove the real kernel implementation refines the Lean kernel model
3. prove the rest of the runtime is public-only with respect to this observer
4. then close the hostile-host deployment theorem at exactly this observer

## Revived Runtime-Kernel Requirements

The archived runbook was directionally right about what the runtime needed:

- a small auditable UO kernel ABI for confidential persistent-state operations
- bounded per-entrypoint working state instead of ad hoc growth
- explicit wipe / scrub discipline for confidential scratch regions
- constant public gas per confidential entrypoint
- no secret-dependent host-visible logging or exceptions
- eventual proof of the kernel itself, or a proof that the real runtime
  refines the same observer

Those requirements remain the right target. The difference now is that the
repository already has the theorem-facing observer and proof bridge, so this
track can attach directly to the current runtime instead of starting from a
blank design.

## Current Implementation Status

### Implemented now

The current runtime has a first hardening layer:

- `runtime/uo-evm/src/kernel.rs` is now the internal small-kernel surface used
  by the interpreter for confidential state access
- `runtime/uo-precompiles/src/lib.rs` provides the kernel opcode vocabulary:
  `Begin`, `CellGet`, `CellSet`, `ArrayGet`, `ArraySet`, `MapGet`, `MapPut`,
  `Commit`, `Wipe`
- `runtime/uo-allocator/src/lib.rs` now derives a manifest-facing
  `AllocatorPlan::from_manifest` and enforces a bounded `AllocatorSession`
  during each call
- the emitted manifest now records the canonical confidential named DSL
  object, the canonical confidential slot DSL object, and the exact public
  kernel-step trace `{ opcode, object_id? }` for each confidential entrypoint,
  and checker-side source/artifact validation plus `uo-evm` reject drift
  against that artifact-side kernel program/schedule package when it is present
- that allocator session enforces:
  - exact confidential-entrypoint kernel-op budgets derived from the checked
    manifest's stored slot program and step trace, plus `Begin` / `Commit` /
    `Wipe`
  - stack-word bounds using the manifest `max_stack_words`
  - bounded value/hash scratch regions
  - wipe completion before the call finishes
- `runtime/uo-evm/src/engine.rs` now routes confidential cell/array/map
  operations through that kernel instead of calling the runtime objects
  directly
- the low-level runtime object transition helpers that shadow-load sealed
  state, install or validate fresh-coin tapes, export hidden ORAM witnesses,
  and cold-store committed state are now compile-time restricted to the
  shared `crate::runtime` module, and `RuntimeObject` no longer implements
  `Clone`, so `engine.rs` cannot duplicate or directly invoke those
  secret-bearing paths; `engine.rs` now also carries only the opaque
  `ContractRuntime` wrapper, while the runtime boundary itself splits live
  reopened object state into a public `PublicRuntimeShadowState` shell handle
  and a distinct `ConfidentialRuntimeShadowState` kernel handle instead of
  exposing one generic shadow wrapper, and the raw `RuntimeShadowState` plus
  confidential shadow wrapper are now visibility-restricted to
  `crate::runtime`
- confidential `keccak256` evaluation now streams canonical bytes directly into
  the hasher under the existing scratch-budget accounting instead of
  materializing per-part heap buffers first
- confidential object commits and ORAM page/bucket rewrites now route
  caller-owned plaintext buffers through `StoreCipher::seal_and_wipe`, so the
  post-encryption plaintext staging buffers are scrubbed before they are
  dropped
- written UO cell/array/small-map commit paths, surrogate ORAM page/bucket/
  counter rewrites, theorem-facing ORAM bucket/counter rewrites, and the
  generic `uo-store` cell-write path now also reuse their existing sealed
  buffers in place through `StoreCipher::seal_and_wipe_into`, so those write
  paths no longer replace the sealed `Vec<u8>` buffers on each confidential
  write
- the generic `uo-store` cell-write API now also takes mutable plaintext
  buffers and wipes caller-owned bytes after raw copy / confidential seal, so
  that helper path no longer routes borrowed plaintext slices straight into
  `StoreCipher::seal`
- the runtime's exported physical-write witness is now also shape-only rather
  than ciphertext-bearing: `PhysicalWriteEvent` and the internal ORAM
  write trace retain only the public write location, length, and write class,
  while zero-write counts are carried only as aggregate metrics; the
  runtime-boundary report now rejects regressions back to stored `old` /
  `new` ciphertext vectors
- the runtime now also stops emitting recomputable host-proxy analytics in
  theorem-facing `ExecutionTrace`; the theorem trace now omits runtime
  telemetry entirely, ordinary `ContractInstance::call` results do too,
  `mplus-probe` derives byte counts, backend counts, update fractions, and
  controller-shape counts from the raw trace, and the runtime keeps only the
  irreducible aggregate `zero_writes` count in an explicit feature-gated
  diagnostic channel that is absent from the default runtime surface
- `StoreCipher` itself now zeroizes its sealing key on drop, so transient
  runtime clones do not leave old per-object store keys behind in ordinary
  drop paths
- logical `Value` trees now scrub themselves on drop, so transient runtime
  copies of decoded contract values do not rely only on allocator release for
  cleanup
- hidden ORAM logical state now also scrubs itself on drop: map entries,
  stash/path blocks, position maps, and injected fresh-leaf coin queues are
  zeroed before ordinary drop completes
- per-object runtime RNG state now gets reset on drop for cell/array/map
  objects, reducing the lifetime of old nonce/leaf-generation state in
  transaction-shadow and replaced-object paths
- `engine.rs` no longer keeps a duplicate secret-bearing call-argument vector
  just to build the public theorem trace: it now retains only a
  `PublicCallSummary` derived from the checked manifest's `param_names`,
  `secret_args`, and manifest-stored `entry_input_len`, containing the
  already-public argument projection plus a type-derived total input length;
  the shell now holds an opaque `ContractRuntime` wrapper rather than the raw
  committed confidential state, and that wrapper internalizes the remaining
  raw confidential argument vector into `ConfidentialCallInputs`, whose unwrap
  surface is restricted to `crate::runtime`,
  and the controller/theorem path now derives public return length from
  manifest-stored `return_canonical_len` and receives only the public
  `OutputShape` summary rather than the full return payload; injected
  fresh-coin plans now zero their stored leaf choices on drop, are consumed
  by value at the diagnostic runtime entrypoint, and move those per-object
  secret leaf tapes into the live shadow state without cloning them first
- kernel object-operation scratch reservations and UO object commit `io`
  scratch reservations now derive from admitted object/type metadata instead
  of live confidential value lengths wherever the runtime already knows the
  canonical shape statically, which removes another residual secret-to-budget
  dependency from cell/array/map mutation and commit paths
- confidential `keccak256` hash-scratch reservations now also use the checked
  manifest's explicit `max_hash_part_bytes` field, which `uo-solc`,
  `uo-check`, and the Lean translation validator all derive from the stored
  confidential DSL plus admitted object metadata, instead of sizing the hash
  scratch region from each live hashed value as the kernel evaluates the
  expression
- ORAM refresh/metadata decode now uses `StoreCipher::with_opened_payload`, so
  decrypted position-map / stash / bucket payload buffers are scrubbed after
  parse instead of lingering as dropped plaintext heap allocations
- confidential transaction-shadow creation for all UO object classes now
  rebuilds logical state from sealed storage instead of cloning live logical
  caches: `UoCell`, `UoArray`, `UoSmallMap`, and `UoOramMap` all reconstruct
  their shadow state from sealed ciphertexts before execution starts
- the corresponding rollback / no-op commit paths now also restore old state
  from sealed storage instead of trusting the old in-memory logical caches, so
  abort recovery and untouched-object commit recovery are tied to the same
  sealed-state boundary for cells, arrays, full-scan maps, path ORAM, and
  surrogate ORAM
- committed UO runtime state is now also re-colded after each call: the
  long-lived contract instance keeps sealed storage plus public metadata, while
  the hidden before/after access-counter and position-map certificates are
  extracted from the opened shadow states before they are dropped back to that
  sealed boundary
- confidential calls no longer shadow-load every object in the contract: for
  proof-grade confidential entrypoints the runtime now reopens only the
  admitted touched object-id set, in canonical object-id order, while untouched
  committed objects remain sealed for the whole call and cold Path-ORAM
  position-map witnesses are reconstructed from ciphertext only when the
  hidden certificate needs them
- that decode path now also streams decrypted position-map / stash pages
  directly into the bounded live ORAM state instead of materializing
  per-page decoded temporary vectors first, and it rejects decoded path-ORAM
  stash contents that exceed the manifest public `stash_bound`
- path-ORAM stash handling now treats the stash as an unordered multiset at
  the runtime level: delete / bucket-fill paths use order-insensitive removal
  instead of shift-heavy `Vec::remove`, and the runtime test suite now checks
  that the witness-visible behavior of a delete access is invariant under a
  permutation of the same logical stash contents
- path-ORAM refresh now rejects malformed hidden state more aggressively:
  out-of-range position-map / stash leaves, out-of-range stash slots,
  duplicate live blocks for one logical slot, and live blocks whose leaf label
  disagrees with the decoded position map are all rejected before execution,
  and bucket-resident live blocks must actually lie on the declared leaf path
- path-ORAM bucket decode now also validates that the bucket header matches the
  storage location being opened and that the header’s live-entry count exactly
  matches the number of occupied blocks in the payload
- those seal/decrypt payload buffers are now also accounted under an explicit
  allocator/kernel `io` scratch region, so the exported runtime kernel witness
  carries public peak/wipe facts for confidential storage I/O staging rather
  than only for value/hash helpers
- `uo-allocator` now also emits the public resource-event trace that justifies
  those stack/scratch facts: stack checks, scratch reservations, and scratch
  wipes are recorded explicitly on the runtime kernel witness rather than only
  summarized as final counters
- the call-scoped kernel now begins before transaction shadow-state cloning, so
  the pre-call ORAM refresh/decode path is also covered by that `io` scratch
  accounting instead of happening entirely outside the witness boundary
- ORAM block/directory serialization now appends directly into the enclosing
  page/bucket payloads instead of allocating extra per-block or per-record
  temporary plaintext vectors along the way
- the path-ORAM access path no longer clones the full committed
  `entries`/`position_map`/`stash` logical state before each rewrite; it now
  moves the working vectors into the access routine and rebuilds them in place
- the runtime now emits a compact `RuntimeKernelWitness` containing the kernel
  public kernel-step trace, derived schedule facts, peak stack usage, public
  allocator bounds, scratch peaks, wipe counts, and the public object universe
- for accepted confidential entrypoints, `uo-evm` now validates that witness
  against the checked manifest's stored confidential slot program before
  returning the trace
- for accepted confidential entrypoints, the runtime kernel now also executes
  against the checked manifest's exact admitted public `{ opcode, object_id? }`
  step schedule and rejects missing, extra, or mismatched steps online rather
  than only by post-hoc witness comparison
- the exported `trusted-kernel` bundle and `refinement-witness` JSON now carry
  that kernel witness directly
- the proof-facing boundary now also includes a standalone proof-grade kernel
  witness checker, so the small-kernel object can be validated directly rather
  than only through the larger trusted-kernel / refinement bundles
- the Lean imported trusted-kernel / refinement-witness validators now consume
  that exported kernel witness and check entrypoint alignment, opcode-envelope
  shape, scratch-budget consistency, wipe discipline, kernel-step shape, and
  exact kernel-step equality, while the
  proof-grade `checkProofGradeRuntimeWitness` and
  `checkProofGradeRuntimeTrustedKernel` validators now require the exact
  expected public kernel-step trace from the checked manifest to be embedded in
  confidential witnesses
- the core Lean trusted-kernel / refinement-witness structures now also expose
  theorem-side `ProofGradeValid` predicates, so the "kernel witness is present
  and exact" condition is available above the JSON importer layer as well
- the Lean side now also exposes proof-grade schedule-exactness lemmas for the
  kernel witness, refinement witness, and trusted-kernel bundle, so a
  proof-grade accepted artifact carries one exact public kernel schedule rather
  than only a validator acceptance bit
- the Lean side now also packages that admitted schedule explicitly as a
  `RuntimeKernelSchedule` / `ImportedRuntimeKernelSchedule` object derived from
  the witness, so later refinement statements can target the schedule object
  directly instead of unpacking duplicated opcode-list and step-trace fields
- the Lean side now also gives that schedule an explicit small-kernel replay
  semantics, so accepted proof-grade kernel witnesses must not only carry the
  exact admitted public schedule but also replay it successfully from
  `ready` to `finished` under the modeled `Begin -> object ops* -> Commit ->
  Wipe` machine
- that modeled replay now also determines the exact final public object-id
  schedule seen by the kernel state, so the proof boundary fixes not only the
  admitted step trace but also the resulting public object-order
- the Lean side now also replays the emitted public resource-event trace
  against the kernel's public stack/scratch budgets and fixes one exact
  replayed resource state; the theorem surface now exposes that exact replayed
  resource state not only for the standalone kernel witness but also through
  the refinement-witness and trusted-kernel-bundle proof-grade lemmas
- the runtime now also emits a lower-level `RuntimeKernelRefinementWitness`
  under that public kernel witness: it records the concrete runtime phase trace
  `pre-committed-cold objects* -> Begin -> shadow-load objects* -> kernel
  steps* -> Commit -> commit objects* -> Wipe -> cold-store objects* ->
  post-committed-cold objects*` while keeping the theorem-facing public kernel
  ABI unchanged
- that lower-level phase witness is carried by the runtime refinement witness
  but not by the smaller trusted-kernel bundle, so the public theorem boundary
  remains the small kernel ABI while the runtime-to-kernel bridge gains a more
  concrete internal certificate
- confidential expression / statement interpretation for admitted entrypoints
  now also runs inside `RuntimeKernel`, while the non-confidential interpreter
  has been split into the explicit `runtime/uo-evm/src/shell.rs` public-shell
  module, so the engine is public orchestration only and the secret-bearing
  env / return-value machine is kernel-owned
- that confidential interpreter now executes a slot-lowered kernel DSL rather
  than the earlier name-keyed environment form: `uo-core` lowers admitted
  confidential entrypoints to a fixed-slot program, `RuntimeKernel` stores
  those values in a bounded `Vec<Option<Value>>` slot file instead of a
  `BTreeMap<String, Value>`, and the slot state wipes those values on drop
- the kernel-step witness journal and the lower-level runtime phase witness
  journal are now both explicit bounded-capacity journals derived from the
  public kernel-op/object bounds rather than plain growable `Vec::new()`
  traces, and the remaining public shell-side commit / witness lists now
  start from explicit `Vec::with_capacity(...)` bounds under those same public
  object-count limits
- live Path-ORAM stash state is now also rebuilt with public
  `working_stash_capacity(...)` headroom up front, preserved across cold
  commits with `.clear()`, and checked before use so the runtime no longer
  depends on a late mid-call `reserve(...)` on that secret-bearing stash
- Path-ORAM clones and storage refresh now also preserve and reuse the public
  entry / position-map / stash capacities in place rather than silently
  collapsing back to fresh zero-capacity vectors during clone or refresh
- touched Path-ORAM aborts now also restore old state in place via
  `OramState::restore_from_old(...)`, so neither untouched nor aborted
  `UoOramMap` commits replace the whole shadow ORAM object anymore
- the full-scan object array/small-map paths now also reuse their logical
  buffers in place across both cold commit and old-state restoration: cold
  commits clear and resize their `values` / `entries` vectors, and abort or
  untouched restore paths decode old sealed state back into those same
  vectors instead of allocating replacement secret-bearing buffers; written
  UO cell/array/small-map commits now also reuse their existing ciphertext
  slot buffers in place, while untouched commits keep those already-cloned
  buffers instead of re-cloning old physical slots
- the remaining secret-bearing runtime object transitions are now kept behind
  the same `crate::runtime` module boundary at compile time, so the engine
  cannot directly reopen, commit, duplicate, or hidden-state-export runtime
  objects outside that boundary; the shell's long-lived state is now an opaque
  committed-state handle rather than a directly owned object map
- the shadow-load path, committed-shadow reconciliation path, and injected
  Path-ORAM fresh-coin routing path now also live in
  `runtime/uo-evm/src/state.rs` rather than being assembled directly in
  `runtime/uo-evm/src/kernel.rs`, which further shrinks the amount of
  object-level state surgery left inside the kernel body
- Rust and Lean now both validate that the lower-level phase witness projects
  exactly to the emitted public kernel-step schedule, that shadow-load,
  commit-object, and cold-store schedules agree, that the witness includes the
  exact pre/post committed-cold object schedules over the full public object
  universe, and that every kernel-visible object id is covered by the
  shadow-load schedule
- the Lean side now also exposes an explicit
  `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem for that
  lower-level phase witness, so the refinement witness fixes not only the
  admitted public kernel schedule and resource replay state but also one exact
  modeled shell/kernel contract: the shell's pre/post committed-cold boundary
  schedules are fixed to the full public object universe, and its
  shadow-load / commit / cold-store schedules are fixed to the canonical
  touched-object set induced by the exported kernel schedule. The theorem
  surface still exposes the underlying exactness lemmas for the kernel
  witness's public object universe and for the runtime phase witness's
  pre/post committed-cold boundary schedules, and the exported shell trace now
  also includes the ordered public runtime-phase event sequence itself so Rust
  and Lean can both check that the summary schedules are honest projections
  and that the event trace replays the public shell contract
- `uo-core` now also exports that theorem-facing shell/kernel interface as a
  direct `RuntimeShellBoundaryBundle`: the proof-grade kernel witness, the
  runtime phase witness, and the explicit exported `RuntimeShellContract` /
  `RuntimeShellTrace` JSON all travel together, Lean checks that those shell
  objects exactly match the witnesses they claim to summarize, checks the
  shell-event trace replay, and the probe validates that interface separately
  as `shell_boundary_validation.json`
- the shared DSL/interpreter bridge now also composes directly through that
  shell object: `uo-core` exports a `RuntimeShellBoundaryLoweringBundle`
  carrying the shell-boundary bundle plus the named and slot confidential
  programs for the same entrypoint, and Lean checks both the shell-boundary
  refinement claim and the named-to-slot lowering claim against the same
  proof-grade kernel witness; the probe validates that composed bridge
  separately as `shell_boundary_lowering_validation.json`
- that same shell interface now also has a direct slot-only proof path:
  `uo-core` exports a `RuntimeShellBoundarySlotBundle` carrying the
  shell-boundary bundle plus the exact fixed-slot confidential program that
  `RuntimeKernel` executes, and Lean checks that the shell-boundary
  refinement claim and the slot-derived kernel schedule share the same
  proof-grade kernel witness; the probe validates that path separately as
  `shell_boundary_slot_validation.json`
- the confidential-kernel lowering functions on both the runtime and imported
  Lean sides are now structurally recursive total definitions rather than
  opaque `partial def`s, and the imported/runtime lowering bridge is restored
  all the way through program lowering: Lean now proves exact commutation for
  imported expression, statement-list, and whole-program lowering, so an
  imported named confidential program that lowers successfully must match the
  stored manifest slot program through `SlotLoweringMatches`
- the imported lowering bundles now also expose runtime-facing theorems and
  executable `toRuntime...LoweringBundle?` helpers over that stored manifest
  pair: after Lean validates an imported kernel-only, confidential-core,
  shell-boundary, or combined lowering bundle, the runtime-facing interface
  preserves the manifest-carried named/slot program pair rather than silently
  re-lowering from the named DSL object
- the post-call `cold_store_object` / `post_committed_cold_object` tail for
  that runtime phase witness is now also finalized behind the runtime state
  boundary rather than being assembled in `engine.rs`, which further shrinks
  the amount of concrete runtime-phase witness construction left in the shell
- the post-call proof-facing `ExecutionTrace` packaging now also lives in
  `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer constructs the
  controller-observer certificate, hidden Path-ORAM certificate, or
  trusted-kernel bundle directly, and the committed ORAM before/after snapshot
  used by that theorem packaging path is now captured through the theorem-side
  `CallTraceContext`; that same theorem-side context now also owns the public
  `PublicCallSummary` and `CallRecorder`, so `engine.rs` no longer calls
  `witness_snapshot()`, `PublicCallSummary::from_manifest_entry`, or
  `CallRecorder::begin_with_input_len` for the theorem path, and the theorem
  finalizer now consumes the whole `RuntimeCallOutcome` directly rather than
  having the engine unpack kernel witnesses, opcode traces, and return values
  just to pass them straight back in
- the confidential-path `RuntimeKernel` entrypoints that shadow-load
  committed state, run confidential calls, and commit public shadows are now
  also visibility-restricted to `crate::runtime`, so the generic shell cannot
  call those kernel hooks directly
- `engine.rs` now delegates public execution to `runtime/uo-evm/src/shell.rs`
  and confidential execution to `runtime/uo-evm/src/state.rs`; confidential
  manifest-to-kernel planning is now fully internal to `ContractRuntime`, so
  the engine no longer stages a `ConfidentialEntrypointPlan`, imports either
  the raw `RuntimeKernel` or the public kernel facade directly, loads the
  manifest-carried confidential slot program, recomputes the admitted runtime
  kernel-step schedule, derives the canonical public object universe from the
  artifact state directly, performs the ready-for-call coldness check over that
  universe itself, threads the public-shell allocator plan, or threads the
  manifest hash-scratch bound or confidential commit budget itself; the
  theorem-side `begin_call_trace` path now triggers that runtime preflight
  instead, and the runtime now validates the slot program against
  `manifest.kernel_steps` once but then carries the checked manifest schedule
  itself forward as the canonical public budget / witness schedule
- confidential `Expr::Select` now also evaluates both admitted pure arms and
  combines them with `Value::confidential_select` instead of branching on the
  secret condition in Rust, while the proof-grade translation checker, the
  confidential-fragment validation report, and the proof-grade
  kernel-witness validator reject confidential select arms outside that
  branchless pure fragment
- confidential `Expr::StructField` and `Expr::ArrayIndex` are now both
  rejected from the admitted confidential fragment entirely
- `confidential_fragment_validation.json` now scans the admitted UO benchmark
  artifacts directly and confirms that their confidential entrypoints contain
  no non-branchless select arms, no confidential `StructField`, and no
  confidential `ArrayIndex`
- `kernel_dsl_validation.json` now checks the shared DSL/interpreter bridge
  directly: the probe serializes the exact lowered confidential-kernel program
  that the runtime executes, Lean re-derives its small-kernel schedule, and
  the proof-grade runtime kernel witness must match that schedule exactly
- `kernel_slot_dsl_validation.json` now checks the fixed-slot confidential
  program that the concrete runtime executes against that same proof-grade
  kernel witness, and `kernel_lowering_validation.json` checks the canonical
  lowering from the named DSL to the slot DSL against that same exported
  witness
- `confidential_core_validation.json` now runs the combined Lean checker over
  each representative proof-grade runtime witness together with the exact
  manifest-carried named confidential program for the invoked entrypoint, so the
  shell-refinement theorem is tied to the same DSL body that the runtime
  actually executes; the artifact-derived confidential-fragment witness
  remains in the report as a separate diagnostic summary over the admitted
  fragment, and the checker now consumes one serialized confidential-core
  bundle
- `confidential_core_slot_validation.json` ties that same proof-grade
  runtime/refinement guarantee directly to the fixed-slot confidential
  program that the concrete runtime executes, while
  `confidential_core_shell_boundary_slot_validation.json` lifts that slot-only
  path across the explicit shell-boundary bundle so the runtime witness,
  shell-boundary bundle, and exact slot schedule are checked together against
  one shared proof-grade kernel witness and runtime phase witness, while
  `confidential_core_lowering_validation.json` composes the named and slot
  DSL objects and checks their canonical lowering against the same exported
  witness
- `confidential_core_shell_boundary_lowering_validation.json` then closes the
  full shared-DSL/shell-boundary loop: the runtime witness, the explicit
  shell-boundary bundle, and the named/slot confidential programs are checked
  together, and Lean proves that they all share one exact proof-grade kernel
  witness and one exact runtime phase witness rather than being accepted only
  as separate artifacts
- the theorem side now also mirrors those exported artifacts directly:
  `RuntimeShellBoundaryBundle`, `RuntimeShellBoundarySlotBundle`,
  `RuntimeShellBoundaryLoweringBundle`,
  `RuntimeConfidentialCoreBundle`, `RuntimeConfidentialCoreSlotBundle`,
  `RuntimeConfidentialCoreShellBoundarySlotBundle`,
  `RuntimeConfidentialCoreLoweringBundle`, and
  `RuntimeConfidentialCoreShellBoundaryLoweringBundle` are now first-class
  runtime theorem objects with `Valid` predicates, so the imported JSON
  bridge lands on an explicit runtime proof interface rather than stopping at
  importer-local checker statements
- the probe now also checks the Rust/Lean kernel ABI vocabulary directly:
  `kernel_model_alignment_validation.json` reads the Rust opcode/witness enum
  definitions, the Rust confidential-kernel DSL enums, and the Lean
  runtime-refinement / runtime-kernel-DSL vocabulary lists and rejects drift
  in opcode names, confidential DSL kind tags and struct field names,
  runtime shell-contract / shell-trace / shell-boundary /
  shell-boundary-lowering field names, resource-event kinds,
  scratch-region names, or refinement-event kinds
- the boundary report now also checks constructor authority for those runtime
  witnesses directly: production `RuntimeKernelRefinementEventWitness`
  construction is restricted to `runtime/uo-evm/src/kernel.rs` and
  `runtime/uo-evm/src/state.rs`, while production
  `RuntimeKernelResourceEventWitness` construction is restricted to
  `runtime/uo-allocator/src/lib.rs`
- that same boundary report now also checks finer internal helper authority
  inside the shared `crate::runtime` module: the secret-bearing
  `RuntimeObject` reopen / commit / cold-store / witness-export / fresh-coin
  helper calls must stay in `runtime/uo-evm/src/state.rs`, the shadow-state
  helpers that reopen committed state, install fresh coins, and reconcile
  committed shadows must be called only from `runtime/uo-evm/src/kernel.rs`,
  the public shadow-load / public-commit / confidential-execution kernel
  hooks `shadow_load_public_objects`, `commit_public_objects`, and
  `run_confidential_call` must be invoked only from `runtime/uo-evm/src/state.rs`,
  without exposing raw `inner_mut` / `into_inner` escape hatches on the
  public kernel facade,
  and the confidential shadow-load helper itself stays private to
  `runtime/uo-evm/src/kernel.rs`; the same source-level report now also pins
  the top-level `ContractRuntime` authority split, so only `shell.rs` may
  drive `prepare_public_shadow`, `commit_public_shadow`, and
  `replace_with_cold_public_shadow`, while only `engine.rs` may call
  `self.state.run_confidential_entrypoint(...)`
- the boundary report now also checks the low-level store helper layer:
  direct `StoreCipher::seal` / `StoreCipher::open` use must stay inside
  `runtime/uo-store/src/codec.rs`, the public wipe-preserving helper surface
  must stay at `seal_and_wipe` / `seal_and_wipe_into` /
  `with_opened_payload`, the store write API must take mutable plaintext
  buffers, and `StoreCipher` must zeroize its key on drop
- the probe-side production-source scan now strips `#[cfg(test)]` items
  without truncating the rest of the file, so those confinement checks cover
  production helpers that appear after mid-file test-only utilities rather
  than silently stopping at the first test block
- the same boundary report now also rejects regressions back to unbounded
  runtime witness buffers: the production kernel must keep its emitted
  kernel-step witness and lower-level runtime phase witness inside the local
  `BoundedJournal` wrapper with bounds derived from public kernel-op/object
  counts, and the remaining public shell-side commit / witness helper lists
  must start from explicit `Vec::with_capacity(...)` allocations rather than
  `Vec::new()`
- that same boundary report now also rejects regressions back to mid-call
  Path-ORAM stash growth: the production ORAM path must derive one public
  `working_stash_capacity(...)` bound, rebuild stash buffers with that headroom
  up front, preserve it across cold commits with `.clear()`, and avoid the
  old late `reserve(...)` expansion path
- the same report now also rejects regressions back to capacity-dropping ORAM
  clone / refresh paths: `OramState` must use the manual capacity-preserving
  `Clone` implementation, and the storage-refresh path must decode metadata and
  rebuild entries into the existing public-capacity buffers rather than
  replacing them with fresh vectors
- that same boundary report now also requires touched Path-ORAM aborts to go
  through the in-place `restore_from_old(...)` helper and forbids regressions
  back to replacing the whole `OramState` with
  `old.oram.clone_for_tx(...)`
- the same report now also rejects regressions back to fresh-vector full-scan
  cold commits: array and small-map object cold commits must clear and resize
  their existing logical buffers in place rather than allocating replacement
  secret-bearing vectors
- that same boundary report now also rejects regressions back to replacement
  full-scan restore buffers and redundant untouched-commit ciphertext clones:
  production `objects.rs` must keep the in-place decode helpers for old-state
  restoration, route array/small-map restore through those helpers, and avoid
  the old `next.physical = old.physical.clone()` /
  `next.physical_slots = old.physical_slots.clone()` assignments
- that same boundary report now also rejects regressions back to a
  string-keyed confidential runtime environment: the production shell must
  load the checked manifest's `confidential_slot_program`, the production
  kernel must execute slot-based statements / expressions, and the confidential
  execution state must stay as a fixed slot vector rather than
  `BTreeMap<String, Value>`
- the proof-grade translation checker now also requires every confidential
  function to carry the same canonical named and slot DSL that the manifest
  carries, and it rejects any mismatch between the exact function-body
  lowering, the stored function-level DSL, and the stored manifest-level DSL,
  so the proof-grade path no longer depends on reconstructing only a public
  schedule when the full DSL program is already available
- the runtime-boundary report now also checks that the production confidential
  object API surface is routed only through `runtime/uo-evm/src/kernel.rs`:
  all direct `.get_cell`, `.set_cell`, `.get_array`, `.set_array`, `.get_map`,
  and `.put_map` call sites must stay inside the kernel module, while the
  remaining runtime state surface is constrained to the committed-state
  wrapper and the fixed-slot kernel execution state
- the probe-side kernel witness summaries now expose the emitted
  `resource_events` trace together with the emitted and expected public object
  universe plus the kernel-step public object schedule, so the artifact
  evidence mirrors that theorem boundary rather than
  hiding it behind counts only
- the proof-grade translation checker now also rejects confidential `Select`
  arms that either contain storage-visible accesses or fall outside the
  admitted branchless pure fragment, because the confidential runtime now
  evaluates both arms and then performs a branchless data-level selection
- the proof-grade translation checker now also rejects confidential
  `StructField` and confidential `ArrayIndex` outright, because the current
  malicious-host hardening story does not carry a proof-grade runtime account
  for those projection forms in the admitted confidential fragment

This is the first point at which `uo-allocator` and `uo-precompiles` are real
enforcement surfaces rather than dead stubs, and the first point at which the
kernel discipline is exported as an explicit runtime artifact.

### Still open

This does **not** yet upgrade the claim boundary to a malicious-host TEE
theorem. Remaining gaps include:

- the Lean side now threads the kernel witness through the theorem-side
  runtime refinement witness and trusted-kernel bundle, and it also checks
  exact kernel-op equality plus exact public kernel-step equality when the
  runtime exports the artifact-side expected kernel witness; what remains open
  is proving the real runtime kernel implementation or the full
  runtime-to-observer refinement rather than only validating emitted witnesses
- the new lower-level runtime phase witness is still a schedule-level
  certificate, not yet a full small-kernel operational semantics for every
  live plaintext buffer and helper-state transition inside the runtime; it
  closes the gap substantially, but it is not yet the final
  "all confidential runtime state refines one tiny machine" theorem
- the rest of the runtime still uses ordinary Rust data structures whose host
  allocation behavior has not been proved irrelevant to the admitted observer
- some helper APIs outside the confidential `uo-evm` hot path may still keep
  plaintext in ordinary Rust-owned buffers without a globally enforced wipe
  discipline, so the buffer-scrubbing story is stronger than before but not
  yet global
- the runtime no longer keeps long-lived committed UO logical caches between
  calls, and the confidential env has now been reduced to a fixed slot file,
  but the runtime still keeps ordinary decrypted logical object state in
  standard Rust `Value`/`Vec` containers while a call-scoped shadow execution
  is live; transaction-shadow creation, rollback / no-op recovery, and the
  new post-call cold-store path all rebuild from sealed storage, and Path-ORAM
  committed state now also starts cold at deployment; the runtime audits the
  full committed object map on both sides of every call boundary, but the live
  in-call object state is still not reduced to the small-kernel witness model
  while it is being used
- enclave-boundary behavior, OCALL/syscall schedule, page-fault behavior, and
  other SGX-visible effects are still only partially captured by the current
  observer path
- there is still no theorem that the full `uo-evm` implementation refines the
  modeled SGX observer
- there is still no Lean proof of the kernel implementation itself

## Active Instructions

These are the revived and still-valid instructions for the stronger story.

### 1. Keep the kernel ABI small and auditable

Status: started.

The confidential operation vocabulary should stay limited to:

- `Begin`
- `CellGet` / `CellSet`
- `ArrayGet` / `ArraySet`
- `MapGet` / `MapPut`
- `Commit`
- `Wipe`

Adding more host-visible power to the kernel should require an explicit
observer argument.

### 2. Keep per-entrypoint working state bounded

Status: started.

The runtime should continue moving secret-bearing helpers under manifest-bounded
discipline:

- fixed-capacity kernel op journal
- bounded scratch regions for key/value/hash staging
- explicit bounded `io` scratch for confidential storage payload staging
- manifest-derived stack/work budgets
- streamed canonical hashing for confidential `keccak256`
- wipe-on-seal handling for confidential object/ORAM plaintext payload buffers
- wipe-after-parse handling for ORAM metadata and bucket plaintext payloads

Future steps should avoid reintroducing secret-dependent growth through helper
paths outside the kernel.

### 3. Export a checkable kernel-discipline witness

Status: started.

The runtime now emits a compact witness stating:

- which kernel ABI was used
- the canonical confidential named and slot kernel programs for the admitted
  entrypoint
- the exact public kernel-step trace `{ opcode, object_id? }` derived from the
  stored slot program
- the exact public resource-event trace used to justify stack/scratch usage
- that scratch regions stayed within the admitted public bounds
- that wipe obligations were discharged

That witness is now in the proof-facing boundary:

- `uo-evm --format kernel-witness` exposes it directly
- `checkProofGradeRuntimeKernelWitness` validates it directly in Lean
- `uo-evm --format kernel-refinement-witness` now also exposes the lower-level
  runtime phase witness directly, and
  `checkProofGradeRuntimeKernelRefinementWitness` validates that artifact
  against the exported proof-grade kernel witness
- `uo-evm --format shell-boundary` and
  `uo-evm --format shell-boundary-lowering` now expose the public-only shell
  contract/trace witness and its shared-DSL lowering bridge directly, instead
  of leaving those proof objects probe-only
- `uo-evm --format confidential-core-shell-boundary-lowering` now also exposes
  the combined runtime-witness plus shell-boundary plus named/slot DSL bundle
  that closes the shared-DSL/shell-refinement loop at one exported artifact
- `results/kernel_refinement_validation.json` now validates that same
  lower-level runtime phase witness directly on the benchmark-backed proof
  scenarios rather than only through the larger refinement-witness report
- the exported trusted-kernel bundle and refinement witness both carry it
- the Lean imported validators check that it matches the observed entrypoint,
  stays within public scratch/stack bounds, uses the admitted opcode
  vocabulary, has the expected `Begin` / `Commit` / `Wipe` envelope, and
  carries the exact admitted public kernel-step skeleton for proof-grade
  confidential calls, and now also that this public schedule replays to a
  finished small-kernel state under the modeled semantics while the emitted
  public resource-event trace replays to the exact claimed stack/scratch
  summary

What remains open is to strengthen that bridge further:

- prove the kernel implementation itself, or
- prove that the real runtime/refinement path always emits the admitted
  proof-grade witness and online schedule object, rather than only validating
  the emitted artifact after the fact

### 4. Connect the real runtime to the SGX observer by refinement

Status: future work.

The end goal is not "the kernel exists." It is one of:

- formally verify the small kernel, then prove that `uo-evm` reduces to it, or
- prove directly that the real runtime refines the SGX/controller observer now
  modeled in Lean

Until that happens, the stronger hostile-host TEE story remains incomplete.

### 5. Upgrade the claim boundary only after the runtime path is closed

Status: future work.

Do not claim malicious-host SGX execution obliviousness merely because the
runtime runs inside a TEE. Upgrade the public claim only once:

- the runtime kernel discipline is explicit and checkable
- the enclave controller / boundary / admitted micro observer are tied to the
  real implementation by the same refinement discipline
- the remaining trusted Rust surface is small enough to defend explicitly

## Relationship To Existing Proof Artifacts

This track is additive. It does not replace the existing controller /
trusted-kernel / refinement-witness path.

Instead, it aims to move more of `uo-evm` itself into the same assurance
pipeline:

1. keep the current Lean-checked theorem boundary
2. shrink the trusted runtime interior by routing more behavior through the
   small kernel
3. export evidence for that kernel discipline
4. then prove or validate the refinement from the real runtime to the same
   modeled observer
