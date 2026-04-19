# Implementation Roadmap To Proof-Grade SGX/TEE Conformance

This note no longer describes a speculative implementation plan. It records the
current milestone status of the repository and the remaining work needed for
stronger theorem provenance claims.

## Goal

The implementation target remains:

- confidential entrypoints emit an explicit public observer consisting of
  `public_outcome`, exact `boundary_schedule`, protected `storage_trace`, and a
  normalized SGX controller `micro_trace`
- persistent state leaving the enclave boundary is confidential and integral
- unsupported programs are rejected rather than accepted under an inexact
  public witness
- the Rust implementation is connected to the Lean theorem boundary by an
  explicit certificate / witness bridge rather than by documentation alone

The theorem-facing backend path is
`path_oram_local_posmap_v1`. The legacy surrogate backend remains in the
repository only as a non-proof-grade benchmark surface; it is outside the
paper-facing and proof-grade claim set.

## Theorem-Preserving Principles

- Do not relax the theorem to fit the implementation.
- Reject unsupported programs instead of widening the public leakage witness.
- Keep every public observer field explicit in the runtime trace.
- Keep the trusted Rust surface small and explicit.

## Milestones

### M1. Runtime theorem observer

Status: implemented.

The runtime now emits:

- `public_outcome`
- exact `boundary_schedule`
- public controller shape
- normalized SGX micro trace derived from that controller shape

That observer is assembled from the runtime controller/recorder path itself,
and the controller certificate independently reconstructs the same public
observer before a trace is returned.

### M2. Sealed persistent storage

Status: implemented.

Confidential storage records now use authenticated encryption with associated
data before nonzero transport encoding. The old marker-hiding placeholder codec
is no longer the only storage story:

- exact backends keep post-initialization writes on the update-only path
- decode/open rejects tampering
- sealed-storage facts are now part of the explicit assumption provenance
  surface

### M3. Exact public leakage witnesses

Status: implemented on the current admitted subset.

The compiler/checker path now enforces compile-time-exact loop structure for
admitted confidential code and validates the manifest fields that the theorem
bridge consumes:

- confidential state objects do not use raw backends on the proof-grade path
- secret-argument positions
- exact confidential kernel lowering acceptance and kernel step/opcode replay
- arena and stack budgets
- exact object manifests
- exact logical read/write counters
- exact ORAM access counts
- exact `max_commit_ops`

The strongest proof-grade path now feeds a source-side compiled artifact and
the candidate artifact directly to the Lean checker
`checkProofGradeTranslationArtifacts`, which re-projects the proof-relevant
source/artifact views from raw contract JSON extracted from those artifacts.
The current trust point is therefore no longer a Rust-side proof-relevant
projection decision. The probe now builds and checks that direct artifacts
path from `uo-solc` plus `uo-core`, `uo-check` is no longer on the
proof-grade library or CLI path, and the static-check report records
confidential raw artifacts as explicit proof-grade rejections.

### M4. Proof-grade ORAM backend path

Status: implemented for the theorem-facing path.

The repository now contains a concrete standard-style backend candidate,
`path_oram_local_posmap_v1`, with:

- a real tree and real path rewrites
- persisted access counters
- persisted position-map state
- persisted stash state
- immediate access execution on transaction shadow state rather than a
  one-shot staged commit surrogate
- multi-access-per-entrypoint support on the theorem-facing path
- manifest/runtime parameter sharing through `OramManifest::for_object`

The stronger backend is already exercised beyond `SingleAccessMap` in the probe
and witness reports, including multi-access `ConfidentialMixer` and multi-map
`ERC20Lite` paths.

### M5. Explicit SGX/controller runtime path

Status: implemented.

The runtime now has a call-scoped controller recorder that emits:

- ordered logical accesses and logical writes
- ordered physical reads and writes
- exact enclave-boundary events
- controller-phase observations
- public region page budgets and workset budgets

The emitted theorem trace is controller-derived and then cross-checked against
an independent pure reconstruction over the recorded public ORAM schedule.

### M6. Runtime refinement and trusted kernel

Status: largely implemented; remaining work is theorem strengthening rather
than missing bridge engineering.

The runtime/proof bridge now includes:

- standalone controller-observer certificates
- standalone hidden Path-ORAM certificates
- an explicit `RuntimeTrustedKernelBundle`
- a proof-grade `RuntimeTrustedKernelSlotBundle` that ties that bundle to the
  admitted fixed-slot confidential program
- runtime-enforced refinement-witness extraction
- Lean JSON import and executable validation for the bundle and witness
- seeded witness-family and paired-certificate validation
- canonical fresh-coin family and pair validation, with compact and heavy
  artifact modes

What remains is not "build the bridge." It is:

- keep the trusted boundary explicitly at that small emitted kernel
- justify or import the explicit backend/cryptographic assumptions cleanly
- avoid overclaiming the rest of the Rust stack as verified

### M7. Paper-main standard-theorem route

Status: implemented at the frozen interface; stronger external import remains
future work.

The repository now has:

- a frozen standard-theorem target:
  `PathOramLocalPosmapV1StandardTheoremTarget`
- an explicit literature-facing JACM theorem object and mapping
- a self-instantiated artifact-side closure at exactly the same interface
- a separate paper-main provenance route documented for the citation-based
  presentation

That means the theorem boundary is fixed and the engineering bridge is closed.
What remains open is only the provenance choice:

- citation route now
- stronger external machine-checked theorem import later, if available

## Immediate Next Steps

The remaining work should be treated as theorem-strengthening:

1. keep `path_oram_local_posmap_v1` as the only proof-grade backend path in
   docs and claim language
2. keep the trusted boundary at emitted certificates, the trusted-kernel
   bundle, and witnesses reconstructed from that bundle
3. keep the compiler bridge on the explicit direct-artifact-plus-Lean-check
   path, and keep any remaining Rust-side bundle emission isolated as
   convenience/debug tooling rather than part of proof-grade acceptance
4. present the current paper route as the JACM citation route at the frozen
   interface
5. separately justify or import the explicit
   `PathOramLocalPosmapV1SecurityAssumptions` bundle if a stronger provenance
   story is needed
6. do not upgrade the repo into a malicious-host SGX execution theorem until
   the SGX observer and enclave controller are connected to the real runtime by
   the same refinement discipline

## Active Runtime-Hardening Track

There is now a separate active strengthening track for the case where `uo-evm`
itself, even inside a TEE, must be pushed toward the hostile-host adversary
model rather than treated as an opaque enclave interior.

Status: started, but far from closed.

The first implementation step is now present in the codebase:

- `uo-evm` routes confidential cell/array/map operations through an internal
  small-kernel layer
- that layer uses `uo-precompiles::UoOpcode` as its auditable operation
  vocabulary
- `uo-allocator` now enforces manifest-derived kernel-op budgets, stack-word
  budgets, bounded scratch regions, and end-of-call wipe checks
- each confidential compiled function and emitted manifest entry now records
  the same canonical confidential named DSL object, canonical confidential
  slot DSL object, and exact public kernel-step trace `{ opcode, object_id? }`
  so checker-side source/artifact validation and `uo-evm` can reject drift
  across the exact function body lowering, the stored function metadata, the
  stored manifest metadata, and the runtime confidential-kernel boundary
- the runtime kernel now also enforces that admitted public schedule online
  while the confidential call is executing, which narrows the remaining gap to
  proving the kernel/runtime refines the modeled observer rather than merely
  spotting schedule drift after the fact
- the runtime now emits a compact `RuntimeKernelWitness` and validates it
  against the checked manifest's stored confidential slot program and derived
  public step trace before returning the trace
- that kernel witness now also carries an explicit public kernel-step trace
  over `{ opcode, object_id? }`, so the proof-grade interface fixes the
  kernel-visible persistent-object schedule rather than only a flat opcode
  journal
- that kernel witness now also carries an explicit public resource-event trace
  over stack checks plus scratch reservations and wipes, so the proof-grade
  interface fixes not only the admitted public object schedule but also the
  exact public evidence used to justify the exported stack/scratch summary
- the repo now also validates that smaller proof object directly through a
  standalone proof-grade kernel-witness checker before lifting it into the
  trusted-kernel and full refinement bundles
- the theorem-facing kernel schedule is now an explicit object with a modeled
  replay semantics, and the proof-grade kernel / trusted-kernel / refinement
  validators now require that the admitted public schedule actually reaches a
  finished small-kernel state rather than only matching by static shape
- that modeled final state now also exposes the exact public object-id schedule
  induced by the admitted `{ opcode, object_id? }` trace, so the proof-grade
  boundary fixes both successful replay and the resulting public object-order
- the runtime now also emits a lower-level
  `RuntimeKernelRefinementWitness` under the public kernel witness: it records
  the concrete runtime phase order `pre-committed-cold objects* -> Begin ->
  shadow-load objects* -> kernel steps* -> Commit -> commit objects* -> Wipe
  -> cold-store objects* -> post-committed-cold objects*` while keeping the
  theorem-facing public kernel ABI unchanged
- that lower-level phase witness lives in the runtime refinement witness, not
  the smaller trusted-kernel bundle, and Rust plus Lean both validate that it
  projects exactly to the emitted public kernel-step schedule and reaches the
  modeled final phase
- confidential expression / statement interpretation for admitted entrypoints
  now also runs inside `RuntimeKernel`, while the non-confidential interpreter
  has been split into the explicit `runtime/uo-evm/src/shell.rs` public-shell
  module, so the engine is public orchestration only and the remaining
  secret-bearing execution state sits behind the smaller kernel boundary
- that confidential execution state is now also slot-lowered and fixed-width:
  `uo-core` lowers admitted confidential entrypoints to a slot program, and
  `RuntimeKernel` executes that form with a bounded `Vec<Option<Value>>`
  slot file rather than a `BTreeMap<String, Value>` name environment
- the emitted kernel-step witness and lower-level runtime phase witness now
  also live inside explicit bounded-capacity journals derived from public
  kernel-op/object bounds, and the remaining public shell-side commit /
  witness helper lists start from explicit `Vec::with_capacity(...)` bounds
  rather than plain `Vec::new()`
- live Path-ORAM stash state now also carries one public
  `working_stash_capacity(...)` bound, is rebuilt with that headroom up front,
  preserved across cold commits with `.clear()`, and checked before use so the
  runtime no longer depends on a late mid-call stash `reserve(...)`
- Path-ORAM clones and refresh now also preserve and reuse the public
  entry / position-map / stash capacities in place rather than replacing them
  with fresh zero-capacity vectors
- touched Path-ORAM aborts now also restore old state in place via
  `OramState::restore_from_old(...)`, so neither untouched nor aborted
  `UoOramMap` commits replace the whole shadow ORAM object anymore
- the full-scan array/small-map paths now also reuse their logical buffers in
  place across both cold commit and old-state restoration: cold commits clear
  and resize `values` / `entries`, while abort and untouched restore paths
  decode old sealed state back into those same vectors rather than replacing
  them; written UO cell/array/small-map commits now also reuse their existing
  ciphertext slot buffers in place, while untouched commits keep their
  already-cloned ciphertext buffers instead of re-cloning old physical slots
- the low-level runtime object transition helpers that reopen shadow state,
  commit objects, export hidden ORAM witnesses, and cold-store committed
  state are now compile-time restricted to the shared `crate::runtime`
  module, and `RuntimeObject` no longer implements `Clone`, so those
  secret-bearing paths are no longer callable or duplicable from `engine.rs`;
  the runtime boundary now also distinguishes the public-shell
  `PublicRuntimeShadowState` handle from the confidential-kernel
  `ConfidentialRuntimeShadowState` handle instead of exposing one generic
  shadow wrapper across both sides
- the remaining shadow-load, shadow-commit reconciliation, and injected
  Path-ORAM fresh-coin routing steps now also live in `runtime/uo-evm/src/state.rs`
  rather than being assembled directly in `runtime/uo-evm/src/kernel.rs`, so
  the kernel body no longer clones committed objects or rewrites shadow maps
  itself
- the theorem side now exposes a proof-grade exactness lemma for that
  lower-level phase witness, and now packages it as an explicit
  `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem: the shell's
  pre/post committed-cold boundary schedules are fixed to the full public
  object universe, and its shadow-load / commit / cold-store schedules are
  fixed to the canonical public touched-object set induced by the admitted
  kernel schedule. The strongest current bridge story is therefore "the real
  shell implementation refines the modeled shell/kernel contract" rather than
  only "public kernel schedule was emitted and checked"; the exported shell
  trace now also carries the ordered public runtime-phase event list, and
  Rust/Lean both check that the summary schedules are honest projections of
  those events and that the event trace replays the public shell contract
- `uo-core` now also exports that shell/kernel boundary directly as a
  `RuntimeShellBoundaryBundle` carrying the proof-grade kernel witness, the
  runtime phase witness, and the explicit `RuntimeShellContract` /
  `RuntimeShellTrace` JSON views; Lean now validates that those exported shell
  objects are exactly the ones reconstructed from the witnesses, that the
  shell-event trace replays the shell contract, and that the shell trace
  refines the shell contract, and the probe reports that checker separately as
  `shell_boundary_validation.json`
- the shared DSL/interpreter route now also composes directly through that
  shell interface: `uo-core` exports a
  `RuntimeShellBoundaryLoweringBundle` carrying the shell-boundary bundle plus
  the named and slot confidential programs for the same entrypoint, and Lean
  checks both the shell-boundary refinement claim and the named-to-slot
  lowering claim against one shared proof-grade kernel witness; the probe
  reports that composition step separately as
  `shell_boundary_lowering_validation.json`
- that shell interface now also has a direct slot-only proof path:
  `uo-core` exports a `RuntimeShellBoundarySlotBundle` carrying the
  shell-boundary bundle plus the exact fixed-slot confidential program that
  `RuntimeKernel` actually executes, and Lean checks that the shell-boundary
  refinement claim and the slot-derived kernel schedule share one exact
  proof-grade kernel witness; the probe reports that slot-only path
  separately as `shell_boundary_slot_validation.json`
- the confidential-kernel lowering definitions that underlie that bridge are
  now total structurally recursive Lean definitions on both the runtime and
  imported sides rather than opaque `partial def`s, which removes the old
  definitional-opacity blocker; the imported/runtime commutation layer is now
  restored through whole-program lowering, and the runtime-facing kernel-only,
  confidential-core, shell-boundary, and combined lowering bundles now source
  the canonical named and slot confidential programs directly from the checked
  manifest entry rather than reconstructing them ad hoc from the IR body
- the post-call `cold_store_object` / `post_committed_cold_object` tail of
  that phase witness now also gets finalized behind the runtime state
  boundary, so `engine.rs` no longer constructs runtime phase-witness events
  directly
- the post-call proof-facing `ExecutionTrace` packaging now also lives in
  `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer constructs the
  controller-observer certificate, hidden Path-ORAM certificate, or
  trusted-kernel bundle directly
- the confidential-path `RuntimeKernel` entrypoints that shadow-load
  committed state, run confidential calls, and commit public shadows are now
  also visibility-restricted to `crate::runtime`, so the generic shell cannot
  call those kernel hooks directly
- `engine.rs` now delegates public execution to `runtime/uo-evm/src/shell.rs`
  and both confidential manifest-to-kernel planning plus confidential-kernel
  setup to `runtime/uo-evm/src/state.rs`, so the engine no longer imports
  either the raw `RuntimeKernel` or the public kernel facade directly, and it
  no longer loads the manifest-carried confidential slot program, derives the
  admitted runtime kernel-step trace, or threads the manifest hash-scratch
  bound or confidential commit budget itself; the runtime now validates the
  slot program against `manifest.kernel_steps` once and then carries the
  checked manifest schedule itself forward as the canonical public budget /
  witness schedule
- confidential `Expr::Select` now also evaluates both admitted pure arms and
  combines them with `Value::confidential_select` instead of branching on the
  secret condition in Rust, while checker-side compiler validation and the
  proof-grade kernel-witness validator reject confidential select arms outside
  that branchless pure fragment
- confidential `Expr::StructField` and `Expr::ArrayIndex` are now both
  rejected from the admitted confidential fragment entirely
- `confidential_fragment_validation.json` now scans the admitted UO benchmark
  artifacts directly and confirms that their confidential entrypoints contain
  no non-branchless select arms, no confidential `StructField`, and no
  confidential `ArrayIndex`
- `kernel_dsl_validation.json` now bridges the shared confidential-kernel DSL
  across Rust and Lean: it serializes the exact manifest-carried named
  confidential program and checks that the DSL-derived kernel schedule matches
  the proof-grade runtime kernel witness exactly
- `kernel_slot_dsl_validation.json` now checks the fixed-slot confidential
  program that `RuntimeKernel` actually executes against that same
  proof-grade runtime kernel witness, and
  `kernel_lowering_validation.json` checks the canonical lowering from the
  named DSL to the slot DSL against that same exported witness
- `confidential_core_validation.json` now runs the combined Lean checker over
  each representative proof-grade runtime witness plus the exact lowered
  confidential program for the invoked entrypoint, so the shell-refinement
  guarantee is discharged only for executions whose embedded kernel witness
  matches the same DSL body that Rust executes; the artifact-derived
  confidential-fragment witness remains in the report as a separate
  diagnostic summary over the admitted fragment, and the checker now consumes
  one serialized confidential-core bundle
- `confidential_core_slot_validation.json` ties that same proof-grade
  runtime/refinement claim directly to the manifest-carried fixed-slot
  confidential program that `RuntimeKernel` actually executes, while
  `confidential_core_shell_boundary_slot_validation.json` lifts that slot-only
  path across the explicit shell-boundary bundle so the runtime witness,
  shell-boundary bundle, and exact slot schedule are checked together against
  one shared proof-grade kernel witness and runtime phase witness, while
  `confidential_core_lowering_validation.json` composes the named and slot
  DSL objects and checks canonical lowering against the same exported witness
- `confidential_core_shell_boundary_lowering_validation.json` now lifts the
  proof interface one layer higher still: the runtime witness, explicit
  shell-boundary bundle, named DSL, and slot DSL travel together in one
  exported object, and Lean proves that those artifacts share one exact
  proof-grade kernel witness and one exact runtime phase witness rather than
  only validating each layer independently
- the theorem-facing Lean side now also exposes matching runtime bundle
  objects, not only imported JSON checkers:
  `RuntimeShellBoundaryBundle`, `RuntimeShellBoundarySlotBundle`,
  `RuntimeShellBoundaryLoweringBundle`,
  `RuntimeConfidentialCoreBundle`, `RuntimeConfidentialCoreSlotBundle`,
  `RuntimeConfidentialCoreShellBoundarySlotBundle`,
  `RuntimeConfidentialCoreLoweringBundle`, and
  `RuntimeConfidentialCoreShellBoundaryLoweringBundle` all now exist as direct
  theorem objects with corresponding `Valid` predicates, so the imported
  artifact bridge lands on a first-class runtime proof interface rather than
  stopping at importer-local acceptance lemmas; those bundle interfaces now
  also preserve the manifest-carried named and slot confidential programs all
  the way through the runtime proof boundary, so the imported slot artifact is
  no longer silently rederived before crossing that proof/runtime boundary
- the probe now also runs a source-level anti-drift report,
  `kernel_model_alignment_validation.json`, that checks the Rust kernel
  opcode vocabulary, the confidential-kernel DSL kind tags and struct field
  names, and the Rust witness event alphabets against the explicit Lean
  vocabularies for opcodes, DSL variants and fields, runtime shell-contract /
  shell-trace / shell-boundary / shell-boundary-lowering field names,
  resource-event kinds, scratch regions, and refinement-event kinds
- the boundary report now also checks constructor authority for those witness
  alphabets: production runtime phase-witness events are restricted to
  `runtime/uo-evm/src/kernel.rs` plus `runtime/uo-evm/src/state.rs`, and
  production resource-event witnesses are restricted to
  `runtime/uo-allocator/src/lib.rs`
- that same boundary report now also checks finer helper authority inside the
  shared runtime module: the secret-bearing `RuntimeObject` reopen / commit /
  cold-store / witness-export / fresh-coin helpers must be used only from
  `runtime/uo-evm/src/state.rs`, the shadow-state helpers that reopen
  committed state or reconcile committed shadows must be used only from
  `runtime/uo-evm/src/kernel.rs`, the raw public-kernel hooks
  `shadow_load_public_objects`, `commit_public_objects`, and
  `run_confidential_call` must be used only from `runtime/uo-evm/src/state.rs`,
  without exposing raw `inner_mut` / `into_inner` escape hatches on the
  public kernel facade,
  and the confidential shadow-load helper itself stays private to
  `runtime/uo-evm/src/kernel.rs`
- the same report now also checks the low-level store helper layer:
  direct `StoreCipher::seal` / `StoreCipher::open` use must stay inside
  `runtime/uo-store/src/codec.rs`, the public wipe-preserving helper surface
  stays at `seal_and_wipe` / `with_opened_payload`, the store write API takes
  mutable plaintext buffers, and `StoreCipher` zeroizes its key on drop
- the probe-side production-source scan now strips `#[cfg(test)]` items
  without truncating later production code, so those confinement checks cover
  files that place test-only utilities before additional production helpers
- Lean now also replays the emitted public resource-event trace against the
  kernel's public budgets and fixes one exact replayed resource state, and the
  theorem surface exposes that exact replayed state through the standalone
  kernel witness as well as the lifted refinement-witness and trusted-kernel
  bundle proof-grade lemmas
- the exported trusted-kernel bundle and refinement witness now embed that
  kernel witness, and Lean now threads it through both imported validation and
  theorem-side runtime / trusted-kernel validity checks for its envelope /
  budget / wipe invariants, with the proof-grade checker path now requiring
  the artifact-side exact expected public kernel-step trace and checking exact
  equality against it
- the kernel witness now also carries an explicit `io` scratch region for
  confidential storage payload staging, and the runtime accounts ORAM
  refresh/decode plus confidential commit/rewrite payload buffers under that
  region before exporting the witness
- confidential `keccak256` evaluation now streams canonical bytes into the
  hasher instead of allocating per-part plaintext buffers first
- confidential object commits and ORAM rewrites now use a wipe-on-seal path
  for owned plaintext buffers, and ORAM serialization no longer allocates
  extra per-block/per-record plaintext vectors just to append them into larger
  payloads
- committed UO state is now cold-stored after each call: the long-lived
  contract instance keeps sealed storage plus public metadata, and the hidden
  Path-ORAM before/after certificates are extracted from the opened shadow
  states before those decrypted caches are dropped again; Path-ORAM committed
  state is now also born cold at deployment, and the runtime rejects any
  call boundary where a committed object cache is still live
- proof-grade confidential calls now reopen only the admitted touched object
  set instead of eagerly shadow-loading every object in the contract, while
  untouched committed objects remain sealed and cold Path-ORAM position-map
  witnesses are reopened from ciphertext only when the hidden certificate
  needs them
- per-object store keys now zeroize on `StoreCipher` drop, which tightens the
  secret-key lifetime story for transaction-shadow and old-state clones
- the generic `uo-store` cell-write path now takes mutable plaintext buffers
  and wipes caller-owned bytes after raw copy / confidential seal, which
  removes one remaining borrowed-slice crypto path from the helper surface
- dropped logical `Value` trees, hidden ORAM state, injected fresh-coin queues,
  and per-object runtime RNG state now scrub themselves more aggressively, and
  `engine.rs` now keeps only a public `PublicCallSummary` derived from the
  checked manifest's `param_names`, `secret_args`, and manifest-stored
  `entry_input_len` during theorem-trace construction instead of cloning the
  full secret-bearing call-argument vector or recomputing input length from
  those values; `engine.rs` now holds an opaque `ContractRuntime` wrapper
  rather than the raw committed confidential state, and that wrapper
  internalizes the remaining raw confidential argument vector into
  `ConfidentialCallInputs`, whose unwrap surface is restricted to
  `crate::runtime` and whose buffered `Value`s now wipe on drop; diagnostic
  fresh-coin plans are now also consumed by
  value and moved into the live shadow state without cloning the per-object
  secret leaf tapes first; the hidden traced-call ORAM witness snapshots in
  `state.rs` now also wipe on drop unless the theorem finalizer explicitly
  consumes them; the controller/theorem path now also derives output
  length from manifest-stored `return_canonical_len` and consumes only the
  public `OutputShape` summary rather than the full return payload
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
- ORAM refresh/metadata decode now wipes decrypted payload buffers after parse
  rather than dropping them as ordinary plaintext heap allocations, and it now
  streams decoded position-map / stash pages directly into bounded live ORAM
  state while rejecting decoded stash contents that exceed the manifest public
  `stash_bound`
- confidential transaction-shadow creation and rollback / no-op recovery now
  rebuild all UO object classes from sealed storage instead of cloning old
  live logical caches, so cells, arrays, full-scan maps, path ORAM, and
  surrogate ORAM all tie those recovery paths back to the sealed-state
  boundary
- path-ORAM access no longer preclones the full committed
  `entries`/`position_map`/`stash` logical state before each rewrite; it now
  moves those working vectors into the access routine and rebuilds them there
- path-ORAM stash delete / eviction paths now treat the stash as an unordered
  multiset and avoid shift-heavy order-preserving removals, with a regression
  test that checks witness-visible delete behavior stays invariant under stash
  permutation
- path-ORAM refresh/decode now rejects more malformed hidden states up front:
  out-of-range position-map or stash leaves, out-of-range stash slots,
  duplicate live blocks, leaf/position-map disagreement, bucket-header index
  mismatch, bucket live-count underreporting, and bucket-resident blocks that
  do not lie on their declared leaf path

That strengthens the runtime discipline, but it does not by itself prove the
runtime against the full SGX observer. The remaining steps are documented in
`docs/tee-runtime-hardening.md`:

1. move the remaining secret-bearing helpers and larger decrypted runtime data
   structures outside those hash/commit/ORAM payload paths under the same
   bounded discipline
2. prove the small kernel or prove that the real runtime refines the modeled
   observer
3. only then upgrade the malicious-host TEE claim boundary

## Practical Readout

The implementation roadmap is no longer blocked on missing runtime/controller
plumbing, missing witness extraction, or missing theorem-interface alignment.
The remaining work is about provenance, backend assumption discharge, and
careful claim discipline.
