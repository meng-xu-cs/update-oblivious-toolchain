# UO Toolchain Runbook Status

This file used to be a build-from-scratch handoff. The repository now already
implements that toolchain, so the old imperative "must build" plan has been
retired.

Use this file as a current operator-oriented status note. The authoritative
claim-boundary wording lives in:

- `README.md`
- `docs/formal-proof-plan.md`
- `docs/implementation-roadmap.md`
- `docs/paper-theorem-profile.md`
- `docs/tee-runtime-hardening.md`

## What Exists Today

- `compiler/uo-solc` parses a restricted Solidity subset, validates sidecar
  metadata, lowers contracts into explicit UO IR, emits runtime manifests
  including exact confidential kernel-op sequences, and writes compiled
  artifact JSON.
- `checker/uo-check` validates accepted source directly and also performs
  source-to-artifact translation validation for the proof-relevant
  function/object/manifest fields consumed by the theorem-facing bridge.
- `runtime/uo-evm` executes compiled artifacts in-process, supports exact
  backends plus the theorem-facing `path_oram_local_posmap_v1` backend, emits
  theorem traces, exports standalone controller and hidden Path-ORAM
  certificates, packages a `RuntimeTrustedKernelBundle`, and exposes checked
  refinement-witness extraction.
- `runtime/uo-store` now uses authenticated sealed records
  (`ChaCha20Poly1305` plus associated data) under the nonzero transport
  encoding instead of the older marker-hiding placeholder codec.
- `probe/mplus-probe` compiles the benchmark suite, runs correctness and
  leakage reports, validates runtime witnesses and certificates with Lean, and
  writes the reproducible `results/` bundle.
- `proof/lean` contains the mechanized observer models, runtime-refinement
  layer, trusted-kernel and witness validators, seeded/canonical Path-ORAM
  family and pair checkers, and the frozen standard-theorem import target for
  the concrete `path_oram_local_posmap_v1` backend.

## Accepted Surface

The current compiler/checker/runtime path accepts a narrow but concrete subset:

- scalar types `bool`, `uint256`, `bytes32`, and `address`
- fixed-size arrays with compile-time sizes
- fixed-field structs over supported scalar types
- `if/else`
- bounded `for` loops of the form `for (uint i = 0; i < N; i++)` with
  compile-time-constant bounds
- state cells, fixed arrays, and metadata-lowered mappings with explicit
  public capacities
- pure/view internal helper functions that consist of one returned expression
- `require(expr);`
- `keccak256(abi.encodePacked(...))` over supported fixed-width arguments

Rejected constructs include inheritance, constructors/fallbacks/modifiers,
events, custom errors, `revert`, `try/catch`, inline assembly, dynamic
arrays/bytes/string, `while`/`do while`, `break`/`continue`, external calls,
and early confidential returns.

## Current Claim Boundary

- exact-UO is claimed for exact backends on the instrumented abstract/runtime
  model: `UOCell`, `UOArray`, and full-scan `UOMap`
- theorem-facing computational-UO is routed only through
  `path_oram_local_posmap_v1`
- the runtime-to-Lean bridge is explicit and executable today:
  controller certificate, hidden Path-ORAM certificate, trusted-kernel
  bundle, runtime refinement witness, seeded witness family, paired
  certificates, and canonical fresh-coin artifacts all have Lean-backed
  validators
- the current paper route uses the citation-based JACM theorem source at the
  frozen interface, while the repository keeps the self-instantiated closure as
  appendix / executable-artifact support at exactly the same interface
- the repository does not currently claim a blanket theorem for all Rust code,
  all downstream machine code, or malicious-host SGX execution obliviousness

## Main Commands

Full validation:

```bash
./scripts/run_all.sh
```

Focused validation paths:

```bash
./scripts/run_bridge_validation.sh
./scripts/run_validation.sh
./scripts/run_heavy_artifact.sh
```

Direct compiler/checker/runtime entrypoints:

```bash
cargo run -q -p uo-solc -- --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --mode uo --out /tmp/fixedslot.json
cargo run -q -p uo-check -- --artifact /tmp/fixedslot.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trace
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-witness
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format kernel-refinement-witness
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format trusted-kernel
cargo run -q -p uo-evm -- --artifact /tmp/fixedslot.json --entrypoint 'peek()' --format refinement-witness
```

## Remaining Work

The main remaining work is no longer "build the toolchain." It is theorem and
provenance strengthening:

- keep the claim surface explicit that `path_oram_local_posmap_v1` is the only
  proof-grade backend path and the legacy surrogate ORAM stays benchmark-only
- keep the small trusted boundary at the emitted certificate / bundle /
  witness-producing kernel rather than claiming the whole runtime is verified
- justify or import the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle cleanly
- if desired, replace the current citation route with a genuinely external
  machine-checked theorem import at the same frozen interface
- do not upgrade the repository into a malicious-host SGX execution theorem
  until the enclave controller and SGX observer are connected to the real
  implementation by the same refinement discipline

## Stronger TEE Runtime Track

If the goal is stronger than the current certificate / witness bridge, the
relevant archived runbook sections have now been revived in
`docs/tee-runtime-hardening.md`.

That track is now grounded in current code rather than a bootstrap plan:

- `runtime/uo-evm/src/kernel.rs` is the internal small-kernel layer for
  confidential state operations
- `runtime/uo-precompiles` is no longer only a placeholder opcode enum; those
  opcodes now drive the kernel discipline used by `uo-evm`
- `runtime/uo-allocator` now derives a manifest-bounded allocator session that
  enforces per-entrypoint kernel-op budgets, stack-word limits, bounded
  scratch regions, and end-of-call wiping
- `uo-evm` now also emits a compact `RuntimeKernelWitness` and validates it
  against admitted confidential function bodies before returning the trace
- the runtime kernel now also executes against the admitted checked-manifest
  `{ opcode, object_id? }` schedule online and rejects step drift before the
  confidential call returns
- the artifact manifest now records both the exact kernel-op sequence and the
  exact public `{ opcode, object_id? }` kernel-step trace for confidential
  entrypoints, and `uo-check` / `uo-evm` reject drift against that schedule
- the repository now also exposes a direct proof-grade Lean checker for the
  standalone runtime kernel witness, in addition to the trusted-kernel bundle
  and full refinement witness validators
- those proof-grade validators now also require that the admitted public kernel
  schedule replay successfully under a modeled small-kernel machine, so the
  theorem boundary has moved from static schedule equality alone to exact
  schedule equality plus successful operational replay, with the replayed final
  state fixing the exact public object-id schedule seen by that kernel machine
- the kernel witness now also carries an explicit public resource-event trace
  over stack checks, scratch reservations, and scratch wipes; Lean replays that
  trace against the public budgets and fixes one exact replayed resource state
  for the kernel/refinement/trusted-kernel proof layers
- the runtime now also emits a lower-level `RuntimeKernelRefinementWitness`
  inside the refinement witness: it records the concrete runtime phase trace
  `pre-committed-cold objects* -> Begin -> shadow-load objects* -> kernel
  steps* -> Commit -> commit objects* -> Wipe -> cold-store objects* ->
  post-committed-cold objects*` without widening the public small-kernel ABI
- Rust and Lean both validate that this lower-level phase witness projects
  exactly to the emitted public kernel-step schedule, that shadow-load,
  commit-object, and cold-store schedules agree, and that the witness carries
  the exact pre/post committed-cold object schedules over the full public
  object universe
- the Lean side now packages that bridge as an explicit
  `RuntimeShellContract` / `RuntimeShellTrace` refinement statement: the real
  shell trace outside the confidential kernel is fixed by the public object
  universe plus the canonical touched-object set induced by the exported
  small-kernel schedule, so the strongest current bridge statement is no
  longer only "the runtime phase witness projects to the kernel schedule" but
  "the shell implementation refines the public shell/kernel contract"; that
  exported shell trace now also carries the ordered public runtime-phase event
  list itself, and Rust and Lean both check that its summary schedules are
  faithful projections and that the event sequence replays the public shell
  contract
- the post-call `cold_store_object` / `post_committed_cold_object` phase
  witness tail is now also finalized behind the runtime state boundary rather
  than being assembled in `engine.rs`, so the generic engine no longer
  constructs runtime phase-witness events directly
- the post-call proof-facing `ExecutionTrace` packaging now also lives in
  `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer constructs the
  controller-observer certificate, hidden Path-ORAM certificate, or
  trusted-kernel bundle directly
- the emitted physical-write witness is now also shape-only rather than
  ciphertext-bearing: `PhysicalWriteEvent` and the internal ORAM write trace
  retain only the public write location, length, and write class, while
  zero-write counts are carried only as aggregate metrics, and the
  runtime-boundary probe rejects regressions back to retained `old` / `new`
  ciphertext vectors
- the runtime now also stops emitting the other recomputable host-proxy
  analytics in theorem-facing `ExecutionTrace`; the theorem trace now omits
  runtime telemetry entirely, ordinary `ContractInstance::call` results do
  too, `mplus-probe` derives byte counts, backend counts, update fractions,
  and controller-shape counts from the raw trace, and the runtime keeps only
  the irreducible aggregate `zero_writes` count in an explicit
  feature-gated diagnostic channel that is absent from the default runtime
  surface
- the confidential-path `RuntimeKernel` entrypoints that shadow-load
  committed state, run confidential calls, and commit public shadows are now
  also visibility-restricted to `crate::runtime`, so the generic shell cannot
  call those kernel hooks directly
- `engine.rs` now also uses only the `PublicRuntimeKernel` facade instead of
  importing the raw `RuntimeKernel` type
- confidential `Expr::Select` now also evaluates both admitted pure arms and
  combines them with `Value::confidential_select` instead of branching on the
  secret condition in Rust, while `uo-check` and the proof-grade
  kernel-witness validator reject confidential select arms outside that
  branchless pure fragment
- confidential `Expr::StructField` and `Expr::ArrayIndex` are now both
  rejected from the admitted confidential fragment entirely
- `confidential_fragment_validation.json` now scans the admitted UO benchmark
  artifacts directly and confirms that their confidential entrypoints contain
  no non-branchless select arms, no confidential `StructField`, and no
  confidential `ArrayIndex`
- `kernel_dsl_validation.json` now serializes the exact lowered confidential
  kernel DSL object that the Rust runtime interprets, imports that same DSL
  bundle into Lean, and checks that the DSL-derived kernel schedule matches
  the proof-grade runtime kernel witness exactly
- `kernel_slot_dsl_validation.json` now checks the fixed-slot confidential
  program that `RuntimeKernel` actually executes against that same proof-grade
  kernel witness
- `kernel_lowering_validation.json` now checks the canonical lowering from the
  named confidential DSL to the slot DSL against that same exported witness
- `confidential_core_validation.json` now runs the combined Lean checker over
  each representative proof-grade runtime witness plus the exact lowered
  confidential program for the invoked entrypoint, so the shell-refinement
  guarantee is tied directly to the same Rust-executed DSL body rather than
  to the runtime witness alone; the artifact-derived confidential-fragment
  witness remains in the report as a separate diagnostic summary over the
  admitted fragment, and the combined checker now consumes one serialized
  confidential-core bundle
- the probe now also runs a source-level
  `kernel_model_alignment_validation.json` report that checks the Rust opcode
  vocabulary, the confidential-kernel DSL kind tags and struct field names,
  and the kernel resource/refinement witness event kinds against the explicit
  Lean vocabularies, so those alphabets are no longer coupled only by
  informal convention
- the imported lowering-bundle interfaces now also have a runtime-facing
  recomputation path: after Lean validates an imported confidential-core,
  shell-boundary, or combined lowering bundle, the `toRuntime...LoweringBundle?`
  helpers and the corresponding proof-grade checker binaries rebuild the
  runtime lowering bundle from the named DSL object and runtime witness rather
  than forwarding the imported slot artifact unchanged
- `runtime_boundary_validation.json` now also checks constructor authority for
  the exported witnesses and the shared-DSL execution surface: confidential
  entrypoints must be lowered to the shared confidential-kernel program only
  in `runtime/uo-evm/src/kernel.rs`, `runtime/uo-evm/src/state.rs` must
  delegate confidential calls through that kernel, production runtime
  phase-witness events may only be constructed in
  `runtime/uo-evm/src/kernel.rs` and `runtime/uo-evm/src/state.rs`, while
  production resource-event witnesses may only be constructed in
  `runtime/uo-allocator/src/lib.rs`; the same report now also checks finer
  helper authority inside `crate::runtime`: secret-bearing `RuntimeObject`
  reopen / commit / cold-store / witness-export / fresh-coin helpers must be
  used only from `runtime/uo-evm/src/state.rs`, the shadow-state helpers that
  reopen or reconcile committed state must be used only from
  `runtime/uo-evm/src/kernel.rs`, and the raw kernel hooks
  `shadow_load_objects`, `commit_public_objects`, and
  `run_confidential_call` must be invoked only from
  `runtime/uo-evm/src/state.rs`; the same report now also checks the
  low-level `uo-store` helper layer, requiring direct `StoreCipher::seal` /
  `StoreCipher::open` use to stay inside `runtime/uo-store/src/codec.rs`,
  the public helper surface to stay at `seal_and_wipe` /
  `seal_and_wipe_into` / `with_opened_payload`, the store write API to take
  mutable plaintext buffers, and `StoreCipher` to zeroize its key on drop; it
  also rejects
  regressions back to unbounded runtime witness buffers by requiring the
  production kernel to keep the emitted kernel-step and runtime-phase traces
  inside the local `BoundedJournal` wrapper with bounds derived from public
  kernel-op/object counts, and by requiring the remaining public shell-side
  commit / witness helper lists to start from explicit
  `Vec::with_capacity(...)` allocations rather than `Vec::new()`; the same
  report now also rejects regressions back to mid-call Path-ORAM stash growth
  by requiring the production ORAM path to derive one public
  `working_stash_capacity(...)` bound, rebuild stash buffers with that
  headroom up front, preserve it across cold commits with `.clear()`, and
  avoid the old late `reserve(...)` expansion path; it also rejects
  regressions back to capacity-dropping ORAM clone / refresh paths by
  requiring the manual capacity-preserving `Clone` implementation on
  `OramState` together with the in-place metadata decode / entry rebuild path,
  and by requiring touched Path-ORAM aborts to restore in place through
  `OramState::restore_from_old(...)` rather than replacing the whole shadow
  ORAM with `old.oram.clone_for_tx(...)`;
  it also rejects regressions back to full-scan replacement-buffer paths by
  requiring array and small-map object cold commits to clear and resize their
  existing logical buffers in place, requiring old-state restoration to use
  the in-place decode helpers, and forbidding the old untouched-commit
  ciphertext re-clone assignments in `objects.rs`;
  the
  production-source scan used by that report now strips `#[cfg(test)]` items
  without truncating later production code, so mid-file test helpers no
  longer hide later production functions
- confidential transaction-shadow creation and rollback / no-op recovery now
  rebuild UO object state from sealed storage instead of cloning old live
  logical caches, including cells, arrays, full-scan maps, path ORAM, and the
  surrogate ORAM backend used for benchmark-only artifact paths
- committed UO state is now also cold-stored after each call, so the
  long-lived contract instance keeps sealed storage plus public metadata while
  the hidden before/after Path-ORAM certificates are extracted from the opened
  shadow states before those decrypted caches are dropped again; Path-ORAM
  committed state is now also born cold at deployment, and the runtime audits
  the full committed object map on both sides of every call boundary
- proof-grade confidential calls now reopen only the admitted touched object
  set, in canonical object-id order, instead of eagerly shadow-loading every
  object in the contract; untouched committed objects stay sealed for the whole
  call and cold Path-ORAM position-map witnesses are reopened from ciphertext
  only when the hidden certificate needs them
- the path-ORAM access path no longer preclones the full
  `entries`/`position_map`/`stash` logical state before each rewrite, which
  further shrinks the hot-path plaintext working surface
- the generated kernel / refinement / trusted-kernel validation reports now
  also expose the emitted `resource_events` trace together with the emitted and
  expected public object universe directly, plus the kernel-step public object
  schedule, so the artifact layer shows the same object-order and
  resource-usage boundary that Lean proves
- confidential expression / statement interpretation for admitted entrypoints
  now also runs inside `RuntimeKernel`, so the generic engine interpreter is
  public-only and the secret-bearing env / return-value machine sits behind
  the smaller kernel boundary
- the runtime object transition helpers that reopen shadow state, commit
  objects, export hidden ORAM witnesses, and cold-store committed state are
  now compile-time restricted to the shared `crate::runtime` module, and
  `RuntimeObject` no longer implements `Clone`, so `engine.rs` cannot
  directly duplicate or invoke those low-level secret-bearing paths; the shell
  now also carries an opaque committed-state handle plus a public
  shadow-state wrapper instead of directly owning raw runtime object maps
- the exported trusted-kernel bundle and refinement witness now carry that
  kernel witness, and the Lean checkers now thread it through imported JSON
  plus theorem-side runtime/trusted-kernel validity, including exact opcode
  equality and exact public kernel-step equality on the proof-grade checker
  path, which now requires the artifact-side expected sequence plus expected
  `{ opcode, object_id? }` step trace to be embedded in the witness

This is still only the first hardening step. The repository still does not
claim that the whole runtime is already proved against a malicious-host SGX
observer, but there is now an active implementation track aimed at that
stronger story.

## Historical Note

The previous long runbook mixed accurate threat-model guidance with a large
amount of now-stale "required work" text. It was removed so the repository
does not continue to present completed implementation work as if it were still
only a plan.
