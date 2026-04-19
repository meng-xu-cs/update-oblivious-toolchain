# UO Toolchain

This repository contains a research-grade prototype of an update-oblivious
toolchain for a restricted Solidity subset. The repository centers on a
compiled artifact plus an instrumented confidential runtime; today it does not
target "deploy raw EVM bytecode to a public chain" as its main execution
model.

Components:

- `compiler/uo-solc`: parses sidecar-annotated Solidity, validates the
  supported subset, lowers to explicit UO IR, and emits theorem-facing
  manifests.
- `runtime/uo-evm`: executes raw and UO artifacts in-process, emits
  instrumented `M+` traces, explicit runtime kernel witnesses, and checked
  trusted-kernel bundles, certificates, and refinement witnesses for the Lean
  model.
- `checker/uo-check`: rejects unsupported source programs, validates compiled
  artifacts for CLI/reporting purposes, and exposes debug/compatibility
  translation-bundle tooling outside the proof-grade acceptance path.
- `probe/mplus-probe`: runs paired leakage experiments, correctness checks,
  witness/certificate validation, and writes the reproducible `results/`
  bundle.
- `benches/raw`: the benchmark suite plus raw/UO metadata.
- `benches/uo`: generated UO artifacts.

Current claim boundary:

- exact-UO for exact backends (`UOCell`, `UOArray`, full-scan `UOMap`) on the
  repository's instrumented abstract machine
- theorem-facing computational-UO only on the `path_oram_local_posmap_v1`
  backend path; the legacy surrogate backend remains for benchmarking and
  compatibility, not for strengthened proof claims
- Lean-checked observer models, reduction layers, runtime trusted-kernel /
  witness / certificate validators, and a frozen imported standard Path ORAM
  theorem target
- the implementation bridge from source/artifact/runtime output into that
  theorem boundary is now explicit and executable under the current
  `PathOramLocalPosmapV1SecurityAssumptions` bundle, with emitted runtime
  traces carrying the direct trusted-kernel bundle that the Lean checker
  validates
- no current blanket claim that the full Rust compiler/runtime stack or a
  malicious-host SGX deployment already satisfies the final paper theorem

Frozen paper claim surface:

> For every admitted Solidity source program `P`, if `uo-solc` compiles `P`
> to artifact `A`, the direct Lean source/artifact checker accepts that pair,
> the real runtime executes `A` and emits runtime proof objects accepted by
> Lean, and the explicit concrete backend / cryptographic / TEE assumptions
> hold, then the real host-visible execution satisfies the paper's
> update-obliviousness theorem against the stated hostile-host observer.

The exact frozen observer is:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

where:

- `public_outcome` is exact
- `boundary_schedule` is exact
- `storage_trace` is exact for exact backends and ORAM-related for
  `path_oram_local_posmap_v1`
- only the SGX-specific `micro_trace` is normalized and simulated from
  `L_sgx_micro`

Explicit assumption profile:

| Assumption | Role | Current status |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides bucket/path ciphertext contents for the concrete local-posmap backend | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; not yet discharged in-repo |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; not yet discharged in-repo |
| `freshLeafResampling` | connects the runtime leaf-remapping coins to the theorem-side fresh-leaf distribution | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; runtime bridge fixed, full proof still open |
| `stashOverflowBounded` | bounds stash-overflow failure for the deployed parameters | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; not yet fully discharged in-repo |
| TEE deployment assumptions | enclave memory confidentiality/integrity, attestation authenticity, rollback/freshness discipline, and the stated crash/patch model | required by the final malicious-host deployment theorem; not yet fully closed in Lean |

Current proof-grade TCB:

| Component | Current role |
| --- | --- |
| Lean kernel plus the Lean theorem/checker development | trusted proof checker and theorem body |
| Explicit backend / cryptographic / deployment assumptions | trusted assumptions |
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | currently trusted for implementation honesty |
| Rust code outside the tiny kernel | still part of the implementation risk until confinement and refinement are proved |
| `uo-check` | not in the proof-grade TCB |
| `mplus-probe` | not in the proof-grade TCB |
| `uo-solc` | not trusted for the current artifact-level acceptance claim, but still unverified for the final source-level compiler theorem |

Paper-main theorem strategy:

- theorem-boundary fact: the paper route and the appendix / artifact route use
  the same frozen theorem interface, but they are not symmetric as provenance
  claims
- current paper choice: use the citation route, with the JACM Path ORAM theorem
  as the external theorem source at the frozen
  `PathOramLocalPosmapV1StandardTheoremTarget` interface, modeled by
  `PaperMainPathOramTheoremSourceAt`; the concrete citation/writeup lives in
  `docs/path-oram-citation-import-plan.md` and
  `docs/path-oram-theorem-sources.bib`
- appendix / artifact route: keep the self-instantiated theorem object at the
  same interface so the current artifacts can be checked end to end today
- future work: keep the stronger external-theorem import route alive, but only
  as a future strengthening until an actual external theorem artifact can be
  aligned to that interface
- the theorem boundary does not change between those two routes; only the
  provenance of the ORAM core theorem object changes

Current closure status:

1. keep `path_oram_local_posmap_v1` as the only proof-grade backend target
2. source-to-artifact conformance for proof-relevant fields now goes through
   a direct Lean artifact check: the strongest proof-grade path now feeds a
   source-side compiled artifact plus the candidate artifact directly to
   `checkProofGradeTranslationArtifacts`, and Lean extracts the raw contract
   JSON itself. `uo-check` may still emit the richer proof-relevant view
   bundle as a tooling/debug wrapper outside the proof-grade acceptance path.
   The Lean checker accepts only when the proof-relevant views match and are
   exactly the views that Lean re-projects from raw contract JSON extracted
   from those artifacts,
   while independently replaying the theorem-facing fields consumed by the
   bridge:
   state-object / manifest exactness, secret-arg agreement, arena / stack
   budgets, logical access counts, ORAM access counts and theorem-facing ORAM
   shape, `max_commit_ops`, confidential-fragment lowering acceptance, and the
   exact confidential kernel opcode / step schedule; proof-grade static checks
   now also report confidential raw artifacts as rejected rather than silently
   accepting them. In the theorem-facing interface, imported proof-grade
   validity now yields not only `source_view = artifact_view`, but also that
   each imported view is exactly the one Lean reconstructed from the raw
   contract JSON extracted from the artifacts
3. the runtime trusted-kernel bundle and refinement witness emitted by
   `uo-evm` are checked against the Lean refinement interface for the
   supported backend path, and both now carry the kernel witness that Lean
   threads through imported JSON plus theorem-side runtime/trusted-kernel
   validity for envelope / budget / wipe shape, with the proof-grade checker
   path now also requiring the embedded artifact-side expected opcode
   sequence and expected public kernel-step schedule; the runtime kernel now
   also enforces that admitted public schedule online during confidential
   execution, and the repo exposes a direct proof-grade kernel-witness checker
   alongside the larger trusted-kernel / refinement validators; Lean now also
   requires that this exact admitted public schedule replay to a finished
   small-kernel state under the modeled `Begin -> object ops* -> Commit ->
   Wipe` machine, and that replay determines the exact final public object-id
   schedule seen by the modeled kernel state; the runtime now also exports the
   lower-level runtime phase witness that projects back to that small kernel
   schedule, and Lean now packages that bridge as an explicit
   `RuntimeShellContract` / `RuntimeShellTrace` refinement theorem: the
   concrete shell trace outside the confidential kernel is fixed by the
   kernel's public object universe plus the canonical touched-object set
   derived from the public kernel schedule. That shell trace now carries the
   ordered public runtime-phase event list itself, and Rust and Lean both
   check that the exported summary schedules are honest projections of those
   events and that the event trace replays the public shell contract. The
   probe reports now surface those emitted / expected public object schedules
   plus the phase-witness projection facts directly, and the post-call
   `cold_store_object` / `post_committed_cold_object` tail is now finalized
   behind the runtime state boundary instead of being assembled in
   `engine.rs`; the post-call proof-facing `ExecutionTrace` packaging now also lives in
   `runtime/uo-evm/src/theorem.rs`, so `engine.rs` no longer constructs the
   controller-observer certificate, hidden Path-ORAM certificate, or
   trusted-kernel bundle directly; the
   confidential interpreter itself now runs inside `RuntimeKernel`, so the
   generic engine interpreter is public-only and the secret-bearing object
   transition / hidden-witness helpers are compile-time restricted to the
   shared `crate::runtime` module rather than being callable from `engine.rs`;
   the confidential-path `RuntimeKernel` entrypoints that shadow-load
   committed state, run confidential calls, and commit public shadows are now
   also visibility-restricted to `crate::runtime`, so the shell cannot call
   those kernel hooks directly; `engine.rs` now also uses only the
   `PublicRuntimeKernel` facade instead of importing the raw `RuntimeKernel`
   type;
   confidential `Expr::Select` now also evaluates both admitted pure arms and
   combines them with `Value::confidential_select` instead of branching on the
   secret condition in Rust, while checker-side compiler validation and the
   proof-grade kernel-witness validator reject confidential select arms
   outside that branchless pure fragment; confidential `Expr::StructField` and
   `Expr::ArrayIndex` are now both rejected from the admitted confidential
   fragment entirely;
   `engine.rs` now also holds an opaque committed-state handle
   (`CommittedRuntimeState`) plus a public shadow-state wrapper
   (`PublicRuntimeShadowState`) instead of directly owning raw
   `BTreeMap<u32, RuntimeObject>` storage; the probe now also includes a
   source-level `kernel_model_alignment_validation` report that checks the
   Rust kernel opcode vocabulary, the confidential-kernel DSL kind tags and
   struct field names, and the kernel resource/refinement witness event kinds
   against the explicit Lean vocabularies, while
   `confidential_fragment_validation` now scans the admitted UO benchmark
   artifacts directly and confirms that their confidential entrypoints contain
   no non-branchless select arms, no confidential `StructField`, and no
   confidential `ArrayIndex`; `kernel_dsl_validation` now serializes the same
   lowered confidential-kernel DSL object that `uo-evm` interprets, imports it
   into Lean, and checks that its derived kernel schedule matches the exact
   proof-grade runtime kernel witness; `kernel_slot_dsl_validation` checks the
   fixed-slot program that `RuntimeKernel` actually executes against that same
   witness; `kernel_lowering_validation` then checks the canonical lowering
   from the named DSL to the slot DSL against that same exported kernel
   witness; `shell_boundary_validation` now checks
   the explicit exported `RuntimeShellContract` / `RuntimeShellTrace` views
   against that same proof-grade kernel witness and lower-level runtime phase
   witness, including the ordered public shell-event trace and its replay
   against the public shell contract; `shell_boundary_lowering_validation`
   then composes that explicit shell interface with the named and slot
   confidential programs for the same entrypoint; `confidential_core_validation` now jointly checks each
   representative proof-grade runtime witness together with that same lowered
   confidential program, so the shell-refinement theorem is only reported for
   executions whose embedded kernel witness matches the exact Rust-executed
   confidential body; `confidential_core_slot_validation` ties the same claim
   to the fixed-slot program that `RuntimeKernel` actually executes;
   `confidential_core_lowering_validation` joins the named and slot DSL views
   into one exported bundle with checker-visible canonical lowering; and
   `confidential_core_shell_boundary_lowering_validation` lifts the whole
   composition one layer higher, so Lean checks that the runtime witness,
   explicit shell-boundary bundle, named DSL, and slot DSL all share one
   exact proof-grade kernel witness and one exact runtime phase witness rather
   than being validated only as separate artifacts; the artifact-derived
   confidential-fragment witness is still reported separately as a diagnostic
   summary over the admitted fragment, and those combined checkers now consume
   serialized confidential-core bundles rather than coordinating separate
   witness files;
   `runtime_boundary_validation` now also checks that confidential entrypoints
   are lowered to the shared confidential-kernel DSL only inside
   `runtime/uo-evm/src/kernel.rs`, that `runtime/uo-evm/src/state.rs`
   delegates confidential execution through that kernel, that production
   runtime phase-witness events are constructed only in
   `runtime/uo-evm/src/kernel.rs` and `runtime/uo-evm/src/state.rs`, and
   that production resource-event witnesses are constructed only in
   `runtime/uo-allocator/src/lib.rs`; the same report now also fixes the
   public write-evidence surface by rejecting regressions from shape-only
   `PhysicalWriteEvent` / ORAM-write traces back to retained `old` / `new`
   ciphertext snapshots, and it now checks that theorem-facing
   `ExecutionTrace` and the default `ContractInstance::call` result both omit
   runtime telemetry entirely while `uo-evm` keeps only the irreducible
   aggregate `zero_writes` count in an explicit feature-gated diagnostic
   channel that is absent from the default runtime surface, and `mplus-probe`
   recomputes the other
   byte/count/fraction analytics from the raw trace
4. the citation route is the current paper theorem source, the
   self-instantiated closure stays as appendix / executable artifact support at
   the same frozen interface, and the stronger import route remains future
   work
5. the existing projection lemmas already recover the repo's
   computational-UO, TEE-storage, and paper-facing SGX consequences at that
   theorem boundary

Build and validate:

```bash
./scripts/run_all.sh
```

Useful individual commands:

```bash
./scripts/compile_benches.sh
cargo test
./scripts/run_bridge_validation.sh
./scripts/run_validation.sh
./scripts/run_heavy_artifact.sh
```

Direct inspection helpers:

```bash
cargo run -q -p uo-check -- --artifact benches/uo/FixedSlotClassifier.uo.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml
cargo run -q -p uo-solc -- --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --mode uo --out /tmp/fixedslot.expected.json
proof/lean/.lake/build/bin/checkProofGradeTranslationArtifacts FixedSlotClassifier /tmp/fixedslot.expected.json benches/uo/FixedSlotClassifier.uo.json
cargo run -q -p uo-check -- --artifact benches/uo/FixedSlotClassifier.uo.json --source benches/raw/FixedSlotClassifier.sol --metadata benches/raw/FixedSlotClassifier.uo.yaml --debug-translation-bundle-out /tmp/fixedslot.debug.translation.json
cargo run -q -p uo-evm -- --artifact benches/uo/FixedSlotClassifier.uo.json --entrypoint 'peek()' --format trace
cargo run -q -p uo-evm -- --artifact benches/uo/FixedSlotClassifier.uo.json --entrypoint 'peek()' --format kernel-witness
cargo run -q -p uo-evm -- --artifact benches/uo/FixedSlotClassifier.uo.json --entrypoint 'peek()' --format kernel-refinement-witness
cargo run -q -p uo-evm -- --artifact benches/uo/FixedSlotClassifier.uo.json --entrypoint 'peek()' --format trusted-kernel
cargo run -q -p uo-evm -- --artifact benches/uo/FixedSlotClassifier.uo.json --entrypoint 'peek()' --format refinement-witness
cargo run -q -p mplus-probe -- --only bridge-validation --out-dir results
```

Artifact modes:

- `./scripts/run_validation.sh` keeps the default compact artifact profile. Oversized canonical Path-ORAM families and pair certificates stay validated through compact theorem-input certificates.
- `./scripts/run_heavy_artifact.sh` switches the probe into explicit heavy-artifact mode and writes a separate `results-heavy/` bundle with `heavy_artifacts/` materializations for the large feasible canonical families/pairs that exceed the default compact budget.

If you want to keep heavy-mode runs bounded on a smaller machine, set
`UO_CANONICAL_CERT_BUDGET_BYTES` and `UO_HEAVY_ARTIFACT_BUDGET_BYTES`
explicitly before invoking the scripts. That lets you materialize only the
small feasible canonical cases while still leaving the larger ones on the
compact theorem-input path.

The current prototype is intentionally narrow. The exact supported subset,
rejected features, remaining assumptions, and the formal proof roadmap are
documented in [docs/supported-subset.md](docs/supported-subset.md),
[docs/engineering-note.md](docs/engineering-note.md),
[docs/trusted-kernel-verification.md](docs/trusted-kernel-verification.md),
[docs/imported-theorem-bridge-checklist.md](docs/imported-theorem-bridge-checklist.md),
[docs/paper-main-theorem-checklist.md](docs/paper-main-theorem-checklist.md),
[docs/path-oram-citation-import-plan.md](docs/path-oram-citation-import-plan.md),
[docs/stronger-import-route-feasibility.md](docs/stronger-import-route-feasibility.md),
[docs/tee-runtime-hardening.md](docs/tee-runtime-hardening.md),
[docs/implementation-roadmap.md](docs/implementation-roadmap.md), and
[docs/formal-proof-plan.md](docs/formal-proof-plan.md).
