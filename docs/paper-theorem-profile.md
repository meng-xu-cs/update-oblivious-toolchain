# Paper Theorem Profile

This note freezes the paper-facing theorem target, the exact observer shape,
the explicit assumption profile, and the current trusted-surface statement.
It also records what the current repository already proves at that frozen
interface and what still remains open.

For the engineering process behind landing new theorems and runtime cuts
into this profile, see
[`coding-agent-conventions.md`](./coding-agent-conventions.md).

## Frozen Theorem Box

The final paper should aim at exactly one theorem:

> For every Solidity source program `P` in the admitted fragment (the
> Lean predicate `CompiledFunction.kernelLowerable` decides admission;
> the W4.4 forward + reverse iff guarantees that admission coincides
> with successful lowering), the W4.2 + W4.4 + W4.5 Lean theorems
> establish that the source-side `Sol.evalFunction` and the kernel-
> side `IR.evalKernelProgram` produce identical outcomes on the
> compiled artifact `A`. If the real runtime executes `A` and emits
> runtime proof objects accepted by Lean, and the explicit concrete
> backend / cryptographic / TEE assumptions hold, and every host-visible
> return/status release is declared by the artifact policy, then the real
> host-visible execution satisfies the paper's update-obliviousness
> theorem against the stated hostile-host observer.

This theorem is now frozen as the paper target. The current repository
fixes its interface, observer, and assumption surface, with the
compiler-side claims (admission, source-to-IR, IR-to-kernel, manifest-
exactness) all Lean-proved end-to-end. The direct Lean artifact
checker (`checkProofGradeTranslationArtifacts`) remains as an
executable proof witness — useful for checking concrete (source,
artifact) pairs in CI — but is no longer the trust root: the W4.2 +
W4.4 + W4.5 theorems supply the same content directly.

## Current Status

What is already established at the frozen interface:

- exact-UO for exact backends on the repository's instrumented abstract
  machine
- theorem-facing computational-UO only on
  `path_oram_local_posmap_v1`
- a direct Lean proof-grade source/artifact checker,
  `checkProofGradeTranslationArtifacts`
- Lean-side proof-grade predicates and executable checkers for the runtime
  kernel witness, runtime refinement witness, and runtime trusted-kernel
  bundle
- a source-backed runtime implementation interface,
  `RuntimeImplementationInterface`, and a combined checked runtime
  implementation confinement boundary,
  `RuntimeImplementationConfinementBoundary`, over the real
  `runtime/uo-evm/src/{lib,engine,runtime,shell,state,objects,oram,theorem}.rs`
  modules together with the shared-kernel support files
  `runtime/uo-kernel-runtime/src/{lib,generated_slot_support,generated_machine}.rs`,
  the generated object-helper module
  `runtime/uo-evm/src/generated_object_helpers.rs`, the lower-level store
  files `runtime/uo-store/src/{codec,generated_store_helpers,store}.rs`, the allocator file
  `runtime/uo-allocator/src/lib.rs`, and the shared-kernel/core files
  `crates/uo-core/src/{confidential_kernel,generated_confidential_kernel,trace,confidential_core,trusted_kernel,types}.rs`;
  that checked interface now also includes centralized confidential
  statement-profile, named-expression-profile, named-pure-expression-profile,
  slot-expression-profile, and slot-pure-expression-profile routes in the
  shared kernel, and it source-checks the explicit named-to-slot lowering
  bridge plus the live slot-statement / slot-expression /
  slot-pure-expression evaluator order against that shared structure, so
  Rust/Lean agreement is pinned not only for statement names but also for
  runtime-normal-form flags, effect kinds, operand-evaluation order,
  storage-tail opcodes, and named/slot pure-expression select/keccak operand
  structure; `tamper_validation.json` now also rejects representative
  named-expression profile-table drift, named-pure-expression profile-table
  drift, and named-to-slot lowering drift at the implementation-interface,
  standalone shared-confidential-kernel-boundary, and
  implementation-confinement-boundary checkers, and Lean now factors that
  checked source route into an explicit outer `PublicBridgeBoundary`, an
  explicit `SmallConfidentialKernelBoundary` for the actual tiny kernel
  files, an explicit
  `ConfidentialStatementTraceBridgeBoundary` for the exact
  statement-trace/proof-bundle bridge, and a
  `SharedConfidentialKernelBoundary` that conjoins those two confidential
  cuts, with dedicated emitted
  `runtime_small_confidential_kernel_boundary_validation.json`,
  `runtime_confidential_statement_trace_bridge_boundary_validation.json`,
  and `runtime_shared_confidential_kernel_boundary_validation.json`
  artifacts for those standalone and combined inner cuts;
  `tamper_validation.json` now also rejects representative secret-branch
  drift, centralized profile-table drift, named-to-slot lowering drift, and
  Path ORAM early-exit scan drift at the standalone
  small-confidential-kernel boundary and the combined
  small-confidential-kernel machine-refinement route, plus statement-trace
  recording / bridge drift at the standalone confidential-statement-trace
  bridge boundary and the combined confidential-statement-trace bridge
  refinement route; that checked inner cut now also meets the closer-to-
  implementation emitted `RuntimeKernelMachineFinishWitness` directly through
  the checked `RuntimeKernelMachineFinishBoundary`,
  `RuntimeImplementationSlotAdapterMachineRefinementBoundary`,
  `RuntimeImplementationResidualHelperShellMachineRefinementBoundary`,
  `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary`,
  and `RuntimeImplementationSharedKernelMachineRefinementBoundary`,
  with dedicated emitted
  `runtime_kernel_machine_finish_witness_validation.json` and
  `runtime_kernel_machine_finish_boundary_validation.json` and
  `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`
  and
  `runtime_implementation_residual_helper_shell_machine_refinement_boundary_validation.json`
  and
  `runtime_implementation_small_confidential_kernel_machine_refinement_boundary_validation.json`
  and
  `runtime_implementation_shared_kernel_machine_refinement_boundary_validation.json`
  artifacts that validate the live machine-finish state itself, validate the
  standalone native machine-finish boundary over that state plus the fixed
  slot program/opcode trace, and pair it first with the dedicated checked
  slot-adapter source cut, then with the dedicated checked residual-helper-
  shell source cut, then with the dedicated checked small-confidential-kernel
  source cut, and then with the larger checked shared-confidential-kernel
  source cut before projecting through that same native runtime-kernel
  finish/slot boundary, while the smaller flattened finish-slot route now
  also remains available through the checked
  `RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary`
  and the new checked `RuntimeImplementationKernelMeetingBoundary` before the
  older wider `RuntimeImplementationSharedKernelRefinementBoundary`, with a
  dedicated emitted
  `runtime_implementation_confidential_statement_trace_bridge_refinement_boundary_validation.json`,
  `runtime_implementation_kernel_meeting_boundary_validation.json`,
  `runtime_implementation_kernel_meeting_confinement_boundary_validation.json`,
  `runtime_implementation_kernel_machine_confinement_boundary_validation.json`,
  and
  `runtime_implementation_shared_kernel_refinement_boundary_validation.json`
  artifacts that project the paired source/artifact objects directly to
  `RuntimeKernelFinishSlotBoundary` and exact `RefinesLeanKernelState`; the
  confidential-statement-trace bridge refinement, kernel-meeting, and
  shared-kernel refinement reports now also mark
  `refines_lean_kernel_state_theorem_checked` plus
  `runtime_kernel_confinement_projection_theorem_checked`; the
  confidential-statement-trace bridge refinement report now also marks
  `confidential_statement_trace_bridge_boundary_theorem_checked`, the
  kernel-meeting report now also marks
  `shared_confidential_kernel_boundary_theorem_checked`,
  `small_confidential_kernel_boundary_theorem_checked`,
  `confidential_statement_trace_bridge_boundary_theorem_checked`, and
  `slot_adapter_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `handwritten_runtime_public_only_theorem_checked`, and the shared-kernel
  refinement report now also marks
  `shared_confidential_kernel_boundary_theorem_checked`,
  `slot_adapter_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `handwritten_runtime_public_only_theorem_checked`, plus
  `paper_shared_kernel_refinement_with_public_only_handwritten_shell_theorem_checked`
  and `paper_shared_kernel_observer_refinement_theorem_checked` for the
  direct `RuntimeImplementationSharedKernelRefinementBoundary` paper
  conjunctions, while the new
  meeting-boundary artifact also checks that the live
  machine-projected finish bundle and the emitted finish-slot bundle agree at
  the native boundary before either wider route is used, and the new
  meeting-confinement artifact then requires the full source-backed
  implementation interface and reconstructs the outer
  `RuntimeImplementationConfinementBoundary` mechanically from that same
  meeting object; the direct machine-confinement artifact reconstructs that
  same outer boundary from the full source-backed implementation interface
  plus the live machine-finish witness and fixed slot program/opcode trace,
  without requiring the separate emitted finish-slot meeting artifact. The
  outer implementation-confinement report now also marks
  `runtime_kernel_confinement_projection_theorem_checked` together with
  `shared_confidential_kernel_boundary_theorem_checked`,
  `small_confidential_kernel_boundary_theorem_checked`,
  `residual_helper_shell_boundary_theorem_checked`, and
  `slot_adapter_boundary_theorem_checked`; the meeting-confinement report
  marks `runtime_implementation_confinement_projection_theorem_checked`
  together with those same four named-cut checks; and the direct
  machine-confinement report marks both
  `runtime_implementation_machine_confinement_projection_theorem_checked`
  and `native_machine_semantics_theorem_checked` together with those same
  four named-cut checks and `public_bridge_boundary_theorem_checked`; that
  same focused report now also exposes source-side hardening checks for the
  remaining runtime shell:
  `oram_write_batch_iteration_is_checked` confirms that handwritten
  object/commit consumers use the checked public-prefix
  `OramWriteBatch::for_each_write(...)` path instead of the older lossy
  iterator, and
  `handwritten_runtime_production_avoids_panic_style_control_flow` confirms
  the production `engine.rs` / `shell.rs` / `state.rs` / `objects.rs` /
  `oram.rs` surface avoids `expect(`, `unwrap(`, and `panic!`; the stronger
  `runtime_interface_production_avoids_panic_style_control_flow` bit extends
  that condition to the whole production `RuntimeImplementationInterface`,
  including `uo-allocator`, `uo-store`, generated helper files, and shared
  `uo-core` trace/types support; the same write-batch bit now also pins
  fallible public-prefix access on both sides of the ORAM write evidence
  boundary: generated `push_oram_write_update(...)` uses
  `log.writes.get_mut(log.len)`, generated exact-batch finishing validates
  prefix slots with `log.writes.get(index)`, and handwritten
  `OramWriteBatch::for_each_write(...)` uses `self.writes.get(index)` rather
  than direct indexing before tracing writes; the same boundary now also exposes
  `handwritten_runtime_lacks_direct_secret_ops`, which checks that production
  handwritten runtime sources contain no direct confidential value operations,
  masked-select abort updates, canonical secret serialization, hidden option
  declassification, `Value::zero_for_type(...)`, or `MapEntry::new(...)`; the
  dedicated checker/report bit
  `handwritten_runtime_lacks_direct_secret_ops_theorem_checked` records the
  corresponding Lean theorem rather than only the raw source scan. The
  stronger host-coordination theorem/report bit
  `handwritten_host_coordination_lacks_secret_serialization_theorem_checked`
  slices out handwritten coordination modules and non-generated shared core
  proof/evidence/type carriers, excluding the public shell and Lean-generated
  helpers, and proves that this slice contains no Keccak/canonical
  serialization, direct confidential value operations, hidden option materialization,
  `Value::zero_for_type(...)`, or `MapEntry::new(...)`. The public shell
  exception is now theorem-facing too:
  `public_shell_canonical_hashing_guarded_by_public_entry_theorem_checked`
  uses an ordered source check to pin the confidential-function rejection in
  `eval_expr` before the public-shell `Expr::Keccak256` canonical hashing path,
  and the direct kernel-machine scenarios emit the same bit alongside the
  public-bridge theorem bit
- an explicit paper-facing runtime boundary and end-to-end route in Lean,
  `PaperMainRuntimeKernelBoundary`,
  `PaperMainPathOramAssumptions`, and
  `PaperMainPathOramEndToEndBoundary`, plus the stronger shared-slot route
  `PaperMainRuntimeKernelSlotBoundary`,
  `PaperMainPathOramSlotAssumptions`, and
  `PaperMainPathOramSlotEndToEndBoundary`, so the remaining runtime/kernel
  trust point is no longer carried only in prose and is now phrased over the
  explicit theorem-facing runtime kernel-interface bundle; the stronger
  projection bundles `PaperMainRuntimeKernelAssumptions` and
  `PaperMainRuntimeKernelSlotAssumptions` remain available below that route to
  discharge those boundaries mechanically from proof-grade witness acceptance
- a strengthened Lean wrapper,
  `ProofGradeSeededRuntimePaperMainBundle`, from which
  the paper-route runtime boundary can now be discharged mechanically when a
  seeded paper-main bundle already carries proof-grade witness acceptance, with
  the seeded-family artifact route now also rechecking exact public-outcome,
  exact boundary-schedule, and shared slot-program uniformity in Lean
- a machine-generated reviewer summary emitted by the full probe bundle as
  `reviewer_summary.json` plus `reviewer_summary.md`, covering proof/report
  cost, artifact sizes, runtime overheads, TCB surface, and explicit
  assumptions
- proof-grade checker entrypoints go through the frozen
  `UOToolchain.ProofGrade` umbrella
- runtime enforcement of the admitted public kernel schedule for accepted
  confidential entrypoints
- dedicated positive reports and dedicated tamper rejections for the
  source-backed implementation-interface, standalone
  small-confidential-kernel / confidential-statement-trace bridge /
  shared-confidential-kernel boundary routes, combined small-confidential-
  kernel machine-refinement / confidential-statement-trace bridge
  refinement / shared-kernel machine-refinement / shared-kernel refinement
  routes, and combined implementation-confinement route

Closed work-package status:

- WP4 (source-to-kernel compiler correctness): a machine-checked
  source-to-kernel compiler correctness theorem beyond the now-landed
  `ProofGradeCompilerFacts` exactness/export layer for manifest fields,
  confidential-kernel lowering, runtime-step schedules, hash bounds,
  confidential kernel-step non-raw target facts, and the compiler-to-ORAM
  witness bridge for source-derived manifest / expected-access objects.
  Subtasks W4.1 / W4.1b have landed: the placeholder
  `abbrev Semantics := Config → Trace` is replaced by a real operational
  evaluator `abbrev Semantics := IR.OperationalConfig → IR.Outcome` over a
  structured Lean mirror of `crates/uo-core/src/{ir,types}.rs`, and
  `compilerSecrecyPreservation` / `publicGasSecretIndependent` are
  re-stated as `evaluatorCompilerSecrecyPreservation` /
  `evaluatorPublicGasSecretIndependent` against that evaluator surface.
  The W4.1 evaluator covers `Expr.{literal,var,unary,binary,select,
  cellGet}` and `Statement.{declare,assign,require,abortIf,cellSet,
  retStmt}`; remaining IR constructs return an explicit
  `EvalStatus.unsupported` and will be admitted incrementally as W4.2-W4.4
  prove their lowering correctness. W4.3 has now also landed in
  full: `IR.branchlessPureExpr` /
  `IR.Expr.fragmentValid` / `IR.Statement.fragmentValid` /
  `IR.CompiledFunction.fragmentValid` decide structural validity,
  `IR.confidentialFragmentEntrypointWitnessOf` mirrors the Rust
  count-based classifier in `crates/uo-core/src/fragment.rs`, and the
  characterization theorem
  `(IR.confidentialFragmentEntrypointWitnessOf fn).Valid ↔
  fn.fragmentValid = true` is Lean-proved through three mutual
  `theorem` blocks plus the function-level corollary, with a paper-
  facing facade
  `proofGrade_confidential_fragment_valid_iff_structurally_valid`
  in `ProofGrade.lean`. W4.2 (source-to-IR) and W4.4 (IR-to-kernel)
  are now Lean-proved end-to-end at the program level for the full
  admitted post-resolution Sol AST (see below); W4.5 (manifest-
  exactness semantics-preserving lift) and W4.6 (artifact-checker
  demotion) have also landed end-to-end (see below). `uo-solc` is
  no longer in the trusted surface for the semantic Sol → IR step;
  the parser-level syntactic preprocessing (`solang_parser` plus
  state-name resolution, capacity lookup, `abi.encodePacked`
  unwrapping, helper-function inlining, `AssignAdd`-style
  desugaring) remains trusted as the front-end that produces the
  post-resolution Sol AST consumed by the W4.2 theorem. W4.1 / W4.3 add Lean-side
  operational and structural-classifier surfaces the WP4 lowering
  theorems refine against.
  Rust / Lean classifier agreement is a source-freeze obligation,
  handled by the existing static-drift checks.
  W4.1+ (evaluator coverage extension), W4.1++ (`Value.map`
  variant + `Value.beq` instance + `Value.mapLookup` +
  `Value.keccak256Mock` placeholder + `Expr.mapGet` /
  `Expr.keccak256` handling), and W4.1+++ (store-update threading
  for `cellSet` / `arraySet` / `mapPut` with the masked-store
  semantics) have also landed: `evalContract` is now total over the
  structural admitted fragment, and store updates persist through
  the statement evaluator. W4.4 Session A landed in
  `proof/lean/UOToolchain/KernelDsl.lean` with the typed kernel-DSL
  inductives, operational semantics (sharing `IR.Outcome`), lowering
  definitions, and lowering preconditions. W4.4 Session B-1 then
  landed the forward-direction lowering iff theorems
  (`branchlessPureExpr → lowerPureExpr ok`, `Expr.fragmentValid →
  lowerExpr ok`, `Statement.kernelLowerable → lowerStatement ok`,
  `Statement.kernelLowerableSchedule → lowerStatements ok`, and the
  program-level corollary
  `CompiledFunction.kernelLowerable → lowerCompiledFunction ok`).
  **W4.4 charter task 4 (IR-to-kernel correctness) is now Lean-
  proved end-to-end at the program level.** The per-Expr / per-
  Statement / list-level / program-level preservation theorems
  (`IR.lowerExpr_preserves_semantics`,
  `IR.lowerStatement_preserves_semantics`,
  `IR.lowerStatementsAux_preserves_semantics`,
  `IR.lowerCompiledFunction_preserves_semantics`) are all proved
  by structural mutual recursion mirroring the W4.4 Session B-1
  forward iff structure. Paper-facing facades
  `proofGrade_ir_to_kernel_expr_preservation`,
  `_pure_expr_preservation`, `_statement_preservation`,
  `_body_preservation`, and `_program_preservation` in
  `ProofGrade.lean` cover the deliverable. Combined with the W4.4
  Session B-1 forward iff
  (`kernelLowerable_implies_lowerCompiledFunction_ok`), this gives:
  every kernel-lowerable program admitted by the W4.3 fragment
  classifier evaluates the same way under the IR semantics and
  the kernel-DSL semantics. The iff reverse direction (lowering
  succeeds → precondition holds) is now closed by the later W4.4
  reverse-iff landing. The only `unsupported`
  evaluator cases are `Expr.{structField,arrayIndex}`, which
  `fragmentValid` rejects, so they cannot appear in an accepted
  IR program.
  **W4.2 charter task 2 (source-to-IR correctness) is now Lean-
  proved end-to-end at the program level for the full admitted
  post-resolution Sol AST.** A typed Lean mirror of the post-
  resolution Sol AST lives in `proof/lean/UOToolchain/Sol.lean`,
  covering both the source-syntax constructors (literals,
  variables, unary/binary/conditional, keccak256, declare,
  assign-to-local, require, abortIf, if/else, for, return) and
  the resolved-state constructors (cellGet, arrayGet, mapGet,
  structField, arrayIndex, cellSet, arraySet, mapPut) carrying
  the object id / predicate that the parser's name-resolution
  pass has filled in. The operational semantics
  (`Sol.evalExpr` / `evalStatement` / `evalBody` / `evalForLoop` /
  `evalFunction`) defined as `def` + `termination_by` reduces by
  `rfl` / `unfold + rw` and matches the IR evaluator branches
  exactly. The AST → IR lowering (`Sol.lowerExpr` /
  `lowerStatement` / `lowerStatementList` / `lowerFunction`)
  maps each Sol constructor to its same-named IR counterpart
  constructor-for-constructor. The per-Expr / per-Statement /
  Body / Function preservation theorems
  (`Sol.lowerExpr_preserves_semantics`,
  `Sol.lowerStatement_preserves_semantics`,
  `Sol.lowerStatementList_preserves_semantics`,
  `Sol.lowerFunction_preserves_semantics`) are Lean-proved by
  structural mutual recursion in the W4.4 Session B-2 style.
  Paper-facing facades `proofGrade_sol_to_ir_expr_preservation`,
  `_statement_preservation`, `_body_preservation`, and
  `_program_preservation` re-export through `ProofGrade.lean`.
  Combined with the W4.4 program-level theorem, this completes
  the source-to-kernel correctness chain. The parser-level
  syntactic preprocessing (state-name resolution, capacity
  literal lookup, `abi.encodePacked` unwrapping, helper-function
  inlining, `AssignAdd`-style desugaring) is the trusted
  front-end that produces the post-resolution Sol AST consumed
  here; the entire semantic Sol → IR step is Lean-proved.
  **W4.4 reverse iff direction landed**: the per-Expr / per-
  PureExpr / list-companion / per-Statement / list-level /
  program-level reverse iff theorems
  (`lowerExpr_ok_implies_fragmentValid` and friends in
  `KernelDsl.lean`) plus the paper-facing iff facades in
  `ProofGrade.lean` close the W4.4 lowering iff at every level.
  Combined with the existing forward iff theorems, this gives the
  full biconditional: a program is in the admitted fragment iff
  its lowering succeeds. This is the prerequisite for W4.6: the
  existing direct artifact checker can verify "the lowering
  succeeded," and the iff lifts to "the program is in the
  admitted fragment, so all W4.2 + W4.4 + W4.5 theorems apply."
  **W4.6 (direct artifact-checker demotion) landed**: the
  paper-facing demotion corollary
  `proofGrade_compiler_correctness_supersedes_artifact_checker` in
  `ProofGrade.lean` bundles the W4.2 + W4.4 + W4.5 chain into a
  single named statement that supersedes the direct artifact
  checker as the trust root. The corollary asserts: (a) source-
  to-kernel outcome preservation (W4.2 + W4.4); (b) admission iff
  (W4.4 reverse iff); and (c) runtime-vs-static `kernelSteps`
  equality on the happy path (W4.5). The
  `checkProofGradeTranslationArtifacts` direct artifact checker
  remains as an executable proof witness — useful for checking
  concrete (source, artifact) pairs in CI — but is no longer
  load-bearing for the trust narrative. **All six WP4 charter
  tasks are now Lean-proved end-to-end.**
  **W4.5 enabling theorem landed**: the paper-facing
  `proofGrade_sol_to_kernel_outcome_preservation` in
  `ProofGrade.lean` composes W4.2 + W4.4 to give a single
  source-to-kernel runtime handle (`Sol.evalFunction fn cfg =
  IR.evalKernelProgram kp cfg` whenever the IR-side lowering
  succeeds and the entrypoint resolves to the lowered function).
  Every manifest field that is a function of the runtime outcome
  (`kernelSteps`, `publicResult`, `oramAccessCounts`, `status`)
  can now be talked about equivalently on the source, IR, and
  kernel sides; the per-field W4.5 manifest-exactness lifts
  proceed by relating each manifest field to the appropriate
  projection of this shared outcome.
  **W4.5 main body landed**: static projections on
  `IR.KernelProgram` (`expectedKernelSteps`,
  `expectedKernelStepCount`, `expectedObjectWriteIds`) give each
  runtime-meaningful manifest field a Lean-side semantic
  referent; paper-facing facades expose each as a single named
  handle and pin the kernel-side projections back to the source
  via `Sol.lowerFunction` and `IR.lowerCompiledFunction`. Narrow
  per-statement runtime-vs-static lifts certify that the runtime
  `kernelSteps` bookkeeping equals the static expected schedule
  for each masked-store statement (`cellSet`/`arraySet`/`mapPut`
  with `predicate = none`) under structural "value sub-expression
  returns `.value _`" preconditions.
  **W4.5 body-level / program-level runtime-vs-static lift
  landed**: the supporting invariant
  `evalKernelExpr_status_ne_completed` (proving the kernel-DSL
  expression evaluator never returns `.status .completed`) plus
  the per-statement
  `evalKernelStatement_kernelSteps_eq_expected_of_completed`,
  body-level
  `evalKernelBody_kernelSteps_eq_expected_of_completed`, and
  program-level
  `evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_completed`
  theorems are all Lean-proved end-to-end. Paper-facing facades
  `proofGrade_kernel_program_runtime_kernel_steps_eq_expected`
  and
  `proofGrade_sol_to_kernel_runtime_kernel_steps_eq_expected`
  expose the program-level fact and its source-side composition
  with the W4.5 enabling theorem. The full chain is now Lean-
  proved end-to-end on the happy path: source → IR → kernel
  runtime → static kernel-program schedule → manifest
  `kernel_steps` field.
- WP5 (concrete backend assumptions): closed at the Cited /
  externally justified level. WP5 charter tasks 3-6 pair each
  `PathOramLocalPosmapV1SecurityAssumptions` field
  (`bucketEncryptionINDCPA`, `metadataEncryptionINDCPA`,
  `stashOverflowBounded`) with a provenance record and a probe
  static-drift check. A deeper Lean-side discharge would be a
  future-strengthening step beyond the published charter.
- WP6 (hostile-host TEE theorem): closed at the six-checkpoint level via
  the W6.1–W6.4 Lean-proved freeze / refinement layer plus the W6.5
  Cited / externally justified `SgxDeploymentAssumptions` bundle plus
  the W6.6 closure audit. The remaining future-strengthening step (not
  a WP6 blocker) is a deeper semantics-of-Rust refinement of the real
  `uo-evm` runtime against the W6.1 / W6.2 frozen observer.
- Future strengthening below WP3 (not a WP3 blocker, retained as the next
  scientific step): a deeper semantics-of-Rust refinement below the now
  source-pinned/public-only handwritten runtime shell cuts, the
  Lean-generated/source-checked confidential-kernel interpreter and helper
  layer, the source-pinned machine/effect schedule
  (`RuntimeKernelMachineSchedule`), allocator discipline
  (`RuntimeAllocatorDiscipline`), statement-trace discipline
  (`RuntimeStatementTraceDiscipline`), Path-ORAM write-log discipline
  (`RuntimeOramWriteLogDiscipline`), small-map lookup discipline
  (`RuntimeSmallMapLookupDiscipline`), array-access discipline
  (`RuntimeArrayAccessDiscipline`), return-tail discipline
  (`RuntimeReturnScheduleDiscipline`), auditable opcode vocabulary
  (`uo-precompiles::UoOpcode`), fresh-leaf tape carrier
  (`PathOramFreshCoinPlan`), and the now end-to-end Lean-modeled Path-ORAM
  reconstruction surface (`RuntimeOramHelperSemantics`,
  `RuntimeOramCodecSemantics`, `RuntimeStoreCodecSemantics`,
  `RuntimeStoreHelperSemantics`). The current WP3 closure ships a checked
  source-backed boundary at this cut plus the helper-layer end-to-end
  reconstruction success theorem; the open future-strengthening step is to
  upgrade this from a "checked source interface plus modeled helper
  semantics" boundary to a full semantics-of-Rust refinement of the actual
  Rust binary against that Lean model.

## Main Choice

The main theorem keeps the enclave boundary exact and public:

- `public_outcome` is exact
- `boundary_schedule` is exact
- `storage_trace` is handled by the backend theorem
- only the SGX-specific `micro_trace` is normalized and simulated from
  `L_sgx_micro`

This is the intended headline claim for the repository. A boundary-normalized
variant is outside the main theorem profile.

## Explicit Assumption Profile

The paper should state the assumptions explicitly rather than leave them
implicit in prose.

| Assumption | Role | Current status |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides bucket/path ciphertext contents in the concrete `path_oram_local_posmap_v1` backend | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; W5.4 lands the **Cited / externally justified** pairing — `pathOramLocalPosmapV1_cryptoProvenance` carries the RFC 8439 + Procter 2014 IACR ePrint citations, the runtime crypto surface stays pinned by the probe's `runtime_crypto_primitive_identity_pinned` static-drift check, and the codec semantics layer pins the corresponding shape constants (`cipherKeyBytes = 32`, `sealedNonceBytes = 12`, `sealedTagBytes = 16`) |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages in the local-posmap wrapper | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; W5.4 lands the **Cited / externally justified** pairing through the same `pathOramLocalPosmapV1_cryptoProvenance` route used for `bucketEncryptionINDCPA` |
| `stashOverflowBounded` | bounds stash-overflow failure for the deployed local-posmap parameters | explicit Lean assumption in `PathOramLocalPosmapV1SecurityAssumptions`; W5.3 lands the **Cited / externally justified** pairing — `pathOramLocalPosmapV1_stashOverflowProvenance` carries the Stefanov et al. JACM 2018 Theorem 5.1 citation (CCS 2013 fallback), the deployed Path-ORAM parameter substitution (`Z = 5`, `stash_bound = max(capacity, 1)`), the JACM tail-bound expression at the deployed bucket size, and the named probe drift check `path_oram_deployed_stash_parameters_pinned` pinning the deployed parameters in `crates/uo-core/src/manifest.rs` |
| `PaperMainRuntimeKernelBoundary` / `PaperMainRuntimeKernelSlotBoundary` | the exact runtime-side boundary facts required by the frozen paper route: one valid explicit runtime kernel-interface bundle per witness, and in the stronger slot route one fixed confidential slot program whose expected kernel steps match that bundle exactly | explicit Lean boundaries in `PaperPathOramTheoremRoute.lean`; they now project mechanically to the native `RuntimeProofGradeKernelInterface` theorem, to the explicit native `RuntimeKernelConfinementBoundary`, and to valid native shell-boundary bundles, the top-level paper assumption bundles now carry these boundary facts directly, proof-grade seeded paper-main bundles can discharge them mechanically, and the checked source-backed `RuntimeImplementationInterface` / `RuntimeImplementationConfinementBoundary` route now ties those same boundaries to the real `uo-evm` bridge/interface split |
| `RuntimeKernelInterfaceSlotBoundary` | the witness-free shared middle interface for the stronger slot route: one valid explicit runtime kernel-interface bundle together with one fixed slot program whose expected/emitted kernel steps match exactly | explicit Lean boundary in `RuntimeConfidentialCoreAssurance.lean`; the smaller finish-slot theorem object, the runtime witness-facing kernel-interface-slot bundle, the paper-route slot boundary, and the imported shared proof-family slot route now all project to this same object before projecting onward to `RuntimeKernelConfinementBoundary` |
| TEE deployment assumptions | enclave memory confidentiality/integrity, attestation authenticity, rollback/freshness discipline, and the stated crash/patch model | WP6 is now closed at exactly six explicit checkpoints. W6.1–W6.4 land the **Lean-proved, semantics-preserving** observer-surface, boundary-call, persistent-I/O, controller-refinement, and storage-refinement freezes (six probe drift checks: `sgx_observer_surface_pinned`, `sgx_boundary_call_model_pinned`, `sgx_persistent_io_model_pinned`, `sgx_controller_refinement_pinned`, `sgx_storage_refinement_pinned`, plus the W5 `runtime_crypto_primitive_identity_pinned` / `path_oram_deployed_stash_parameters_pinned`). W6.5 lands the **Cited / externally justified** explicit deployment-assumption bundle: `SgxDeploymentAssumptions` in `proof/lean/UOToolchain/SgxObserverFreeze.lean` carries six `Prop` fields covering every WP6 charter task 5 enumeration (attestation, rollback, freshness, crash, patch-level) plus the underlying enclave-memory isolation: `attestationAuthenticity`, `enclaveMemoryIsolation`, `rollbackResistance`, `freshnessGuarantee`, `crashRecoveryDiscipline`, `patchLevelTrust`. Each is paired with a `SgxDeploymentAssumptionProvenance` record citing the relevant Intel SGX specification (`IntelSGXAttestationReference`, `IntelSGXSDM3D`, `IntelSGXSDKDeveloperReference` for rollback / freshness / crash, `IntelSGXSecurityCenter` for patch level). The `sgx_deployment_assumption_bundle_pinned` static-drift check rejects regressions that delete the bundle, drop a field, or remove a citation BibTeX key. W6.6 lands the closure audit `sgxHostileHostClosureAudit` (six entries, each classified Lean-proved or Cited; closure theorems `sgxHostileHostClosureAudit_length`, `sgxHostileHostClosureAudit_leanProvedEntries`, `sgxHostileHostClosureAudit_allClassified`, `sgxHostileHostClosureAudit_driftCheckNames`). The bundle stays explicit at the Lean type level; it does not Lean-discharge any of the five assumptions, and no surviving WP6 surface field is in the "trusted-without-citation" or "source-frozen-only" bucket. |

The exact fresh-leaf remapping bridge is no longer a separate theorem-side
assumption field. It is discharged by the canonical fresh-coin runtime-family
interface and the hidden-leaf coverage proof/checker path.

The below-interface WP3 route has taken the first Lean-first/generated-kernel
steps: `proof/lean/GenerateConfidentialKernelRust.lean` emits the live
`crates/uo-core/src/generated_confidential_kernel.rs` evaluator/profile-table
artifact, and `proof/lean/GenerateRuntimeKernelSlotSupportRust.lean` emits
`runtime/uo-kernel-runtime/src/generated_slot_support.rs` for confidential
argument staging and fixed slot-file state. `uo-core` delegates
slot-program/block/statement execution and unary/binary operator semantics
into the generated interpreter, while `RuntimeKernelSlotCall` delegates
argument-count checked slot staging into the generated slot-support module.
The Lean `RuntimeKernelSlotSupport` model now makes that staging executable:
it accepts exactly the public preconditioned argument count, rejects
argument-count mismatch and public slot-capacity overflow, and proves that any
successful staged slot file satisfies the modeled staging relation.
The checked implementation route now pulls exact source equality for the
generated runtime-kernel machine, generated slot-support module, generated
confidential-kernel interpreter/profile tables, generated object helpers, and
generated store helpers directly into the Lean-backed
`RuntimeImplementationInterface` boundary family: the helper-generated
artifacts are exact obligations of `ResidualHelperShellBoundary`, and the
generated kernel/machine/staging artifacts are exact obligations of
`SmallConfidentialKernelBoundary`. That same small-kernel route now also pins
the auditable `uo-precompiles::UoOpcode` vocabulary by importing and
rechecking `runtime/uo-precompiles/src/lib.rs` as `precompiles_source`, so the
public opcode alphabet consumed by the confidential kernel is part of the same
source-backed interface object. The same interface object now also imports
`runtime/uo-evm/src/fresh_coins.rs` as `fresh_coins_source`, so the opaque
fresh-leaf tape carrier used by the exact transition-shaped Path-ORAM
fresh-leaf schedule is pinned as a boxed, non-`Clone`, move-only per-object
entry table rather than being left outside the checked source cut.
`kernel_model_alignment_validation.json` still rechecks those exact
equalities as a separate Rust/Lean audit while also checking that the live
runtime consumes the generated artifacts on the expected paths, and
`tamper_validation.json` rejects representative generated-interpreter,
generated-slot-support, generated machine-schedule, generated object-helper,
generated store-helper, `path_oram_fresh_coin_plan_surface_drift`, and
`precompiles_opcode_surface_drift` at the source-backed
implementation-interface, small-kernel, shared-kernel, and combined
confinement cuts. The checked implementation boundary also now
requires the residual `uo-kernel-runtime` slot/effect adapter to be only a
forwarding shell and rejects raw confidential-argument observation in that
handwritten layer. Lean now packages that narrower source cut explicitly as
`RuntimeImplementationSlotAdapterBoundary`, the probe emits
`runtime_slot_adapter_boundary_validation.json`, and the drift suite rejects
generated slot-support argument-count drift, generated confidential-interpreter
drift, shared-kernel interpreter-bypass drift, and handwritten raw-argument
observation drift already at that dedicated slot-adapter cut. Lean now also
packages the direct meeting between that same source cut and the emitted live
machine-finish witness as
`RuntimeImplementationSlotAdapterMachineRefinementBoundary`, benchmark-backed
by `runtime_implementation_slot_adapter_machine_refinement_boundary_validation.json`;
Lean now packages the paper-facing conjunction at that cut as
`RuntimeImplementationSlotAdapterMachineRefinementBoundary.paperSlotAdapterMachineRefinement`;
that machine-backed slot-adapter route already rejects representative expected-
schedule-index drift, kernel-op/runtime-phase capacity drift, slot-program
body drift, opcode-trace drift, generated confidential-interpreter drift,
shared-kernel interpreter-bypass drift, generated post-return-break drift,
generated slot-support argument-count drift, and handwritten raw-argument
observation drift before the wider residual-helper-shell or small-kernel
machine routes are used. The wider
`RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary`,
`RuntimeImplementationSharedKernelMachineRefinementBoundary`, and
`RuntimeImplementationKernelMachineConfinementBoundary` routes now also expose
that same paper-facing conjunction as
`paperSlotAdapterMachineRefinement`, and their emitted reports mark
`paper_slot_adapter_machine_refinement_theorem_checked` so the outer routes are
checked as explicit projections through the smaller slot-adapter machine cut
rather than only inheriting it informally. The slot-adapter, residual-helper-
shell, small-confidential-kernel-machine, and shared-kernel-machine reports
now also mark `native_machine_refinement_theorem_checked` for their own
lower-level machine theorems. The small-confidential-kernel-machine route now
also exposes `paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell`
and `paperSmallKernelMachineObserverRefinement`, and its emitted reports mark
`paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
plus `paper_small_kernel_machine_observer_refinement_theorem_checked`.
The shared-kernel-machine route now also exposes
`paperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell` and
`paperSharedKernelMachineObserverRefinement`, and its emitted reports mark
`paper_shared_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
plus `paper_shared_kernel_machine_observer_refinement_theorem_checked`.
It also pins the runtime machine's public-opcode,
bounded-scratch, object-store delegation, commit-schedule, and finish-wipe
schedule; Lean now exposes this as the explicit
`RuntimeKernelMachineSchedule` model with proofs for the public-opcode prefix
and finish-time scratch wiping. It also imports `runtime/uo-allocator/src/lib.rs`
and checks allocator-session kernel-op budget, scratch budget, stack budget,
guard-drop wipe, finish-time wipe validation, and absence of unsafe/forget
escape hatches; `RuntimeAllocatorDiscipline` now models those accepted
allocator transitions and the live allocator uses a bounded `ResourceEventLog`
whose finish output is boxed in `RuntimeKernelTelemetrySnapshot`. The live
statement recorder is now exact-capacity and modeled by
`RuntimeStatementTraceDiscipline`; the model proves not only length/capacity
but also exact public statement-trace content and boxed-trace equality. The
checked source interface also now pins
named/slot confidential-kernel program bodies and Keccak part lists to boxed
fixed-shape slices, with named-to-slot lowering performed through
`FixedBoxBuilder` rather than growable collection. The shared kernel-step
buffer now also uses checked-slot push, iterator finish moves, and
iterator-limited drop cleanup instead of direct uninit-slot indexing or
initialized-prefix slicing, and slot-program statement traces are materialized
by iterating over the body rather than reading `self.body[index]`.
The generated `uo-core` value-operation layer now keeps canonical byte-buffer
writes, struct-field zero materialization, scalar canonical decoding,
length-word parsing, `u128` tail writes, and masked byte-array select/equality
on checked-range and iterator helpers, and the source-backed interface rejects
the old direct `fields[index]`, `copy_from_slice(...)`, fixed-slice, and
per-byte index loops in `generated_value_ops.rs`. Its shared
handwritten `FixedBoxBuilder<T>` backing buffer now uses iterator
initialization, checked `get_mut(...)` push, and iterator-limited drop cleanup
instead of direct uninit-slot indexing or initialized-prefix slicing. The
same layer is now backed by `RuntimeValueOpsSemantics`, which proves the
public scalar canonical lengths, the exact `u128` canonical byte-field shape,
masked bool/byte-array selection facts, and fixed-capacity byte-buffer
extend/finish behavior consumed by the direct machine-confinement boundary.
The same state-side object
table cut now requires fixed-order boxed object entries and fallible
`entries.get(...)` / `entries.get_mut(...)` lookup after the public object-id
scan, rejecting the old direct `entries[index]` table access. Tamper cases cover adapter observation,
machine-effect schedule drift, allocator scratch-budget guard drift,
allocator resource-event-log drift, and statement-trace recorder drift
including the direct machine-confinement theorem route. The
  remaining runtime-kernel TCB is now the non-generated object/ORAM
coordination shell and thinner handwritten store wrapper layer rather
than the older ad hoc object/ORAM open-seal-reseal surface. On the object
side, the exact secret-bearing reopen/bootstrap/commit reseal shell now lives
in the exact-source-checked generated object-helper module
(`with_opened_object_payload`, `seal_boxed_object_payload`, and
`reseal_payload_and_trace_write` together with the typed value/map
open/bootstrap/commit wrappers that used to live in `objects.rs`). The same
source-backed cut now also pins the remaining handwritten object shell to
guarded public-slot access: raw array value/physical/written-flag operations
use `get(...)` / `get_mut(...)`, generated UO array and small-map commit
callbacks receive only checked public schedule indices before touching physical
slots, and the stale `values[index]`, `physical_slots[index]`, and
`written_slots[index]` forms are rejected from `objects.rs`. The same
runtime cut now routes the deeper exact-size ORAM codec stack through the
dedicated Lean-generated `runtime/uo-evm/src/generated_oram_codecs.rs`
module, which owns the map-record, directory-page, scalar-metadata, block,
bucket, stash-page, Path-ORAM metadata-page encode/rewrite/open,
bucket-payload validation logic, the public ORAM geometry/addressing helpers,
and the masked Path-ORAM selector / fixed-capacity stash-rebuild helpers that
used to live in `oram.rs`. The current generated ORAM surface also removes the
older broad clone convenience points: `MaskedUsizeOption` no longer derives
`Clone`/`Copy`, metadata clone/assign/select/repeat operations are explicit
generated borrowed helpers, and the old generic `repeat_boxed<T: Clone>` path
has been replaced by typed generated builders for masked position-map entries
and empty metadata pages. The source-backed interface and probe reject
reintroducing the old metadata copy/select/repeat shape. On the ORAM side, the
corresponding reopen/bootstrap/commit reseal shell now still lives in the
generated helper module (`with_opened_oram_payload`,
`seal_boxed_oram_payload`, `filler_boxed_oram_payload`, and
`reseal_oram_payload_and_record_write`), and the generated reseal helper now
records only public update-shape writes via `OramWriteLog::push_update`
rather than threading prior/new ciphertext snapshots. `RuntimeOramWriteLogDiscipline`
now proves the public write/update/read-transcript push transitions reject at
capacity, preserve public capacity/overflow state on accepted pushes, update
only the intended public counters, and preserve zero writes for the
update-only path before exact public-capacity finish. Lean now also has an
explicit byte-layout semantics layer for the generated ORAM block, bucket, and
Path-ORAM metadata page codecs, including block roundtrip and exact encoded
length theorems, exact-length block decode facts, plus exact-bucket decode
acceptance tying byte length, expected bucket index, exact block decoding, and
live-count agreement together, bounded Path bucket decode for occupied block
slot/leaf bounds, public bucket-on-leaf-path membership, and decoded
position-map agreement plus duplicate live-slot rejection and position-map
live-slot coverage plus generic whole-block-list agreement/no-duplicate hooks,
and Path-ORAM
position-map capacity/leaf bounds. On the lower-level
store side,
`RuntimeImplementationInterface` now imports
`runtime/uo-store/src/codec.rs`,
`runtime/uo-store/src/generated_surface.rs`,
`runtime/uo-store/src/generated_store_helpers.rs`, and
`runtime/uo-store/src/store.rs` directly and pins both the exact-size
seal/open/filler surface and the store helper layer via
`storeWriteApiUsesMutablePlaintext`,
`storeCipherSurfaceStaysInCodec`,
`runtimeStoreUsesSharedBoxedFillerHelper`, and
`runtimeStoreUsesSharedSealIntoHelper`, with `tamper_validation.json`
rejecting representative codec-surface, boxed-filler, and seal-into helper drift at the
implementation-interface, standalone small-kernel, standalone shared-kernel,
combined confinement, and direct machine-confinement routes. The generated
store-codec artifact beneath that layer is now also reduced to the exact-size
transport primitives (`sealed_encoded_len`, `write_nonzero_encoded`, and
`decode_nonzero_into`) instead of older `Vec` convenience helpers, while the
generated nonzero transport encoder/decoder uses checked public windows,
chunk-local `get_mut(...)`, and `zip(out.iter_mut())` instead of direct
`out[index * 2]` / `out[index]` writes, and the
live reopen path in `StoreCipher` stays on boxed exact-size decode buffers and
in-place AEAD without `expect`, `unwrap`, or `panic!` in the generated store
surface. That generated reopen path now also uses checked cursor/range helpers
for magic/nonce/ciphertext/tag parsing and a checked exact-copy helper for boxed
plaintext staging, so source-backed validation rejects direct `split_at(...)`
and `payload.copy_from_slice(...)` reopen paths. Lean now models that reopen edge as a fixed-public-length
`decodeNonzeroInto?` surface with roundtrip, encoded-length-mismatch rejection,
and decoded-byte/nonzero-nibble soundness facts exposed through both residual
and direct machine-confinement checkers. The generated store-helper layer now
owns the raw/UO `StoreSlotTable`: slot storage is a boxed fixed table with
public linear lookup rather than a handwritten
`BTreeMap<String, Box<[u8]>>` in `store.rs`, and the public store evidence
buffers are exposed to handwritten `store.rs` only as generated
`StorePhysicalWriteTrace` / `StoreLogicalEventTrace` wrappers rather than raw
`Vec<PhysicalWriteEvent>` / `Vec<LogicalEvent>` fields, and those generated
wrappers now use exact boxed-slice backing with fallible fixed-builder appends
rather than `Vec` storage. Lean now models this helper layer explicitly in
`RuntimeStoreHelperSemantics`: taking a raw value copies exactly the input and
wipes the source shape, zeroed raw-slot tables preserve the public object count
and produce fixed-length zero slots, `insert_or_replace` preserves lookup for
the written object while growing by at most one slot, boxed event append
preserves the existing prefix and adds exactly one event, bootstrapped UO slots
have the public sealed length, and UO reseal traces stay `Update`-only.
Confidential UO-store writes now emit only public update-shape evidence rather
than cloning ciphertext snapshots. The
source-backed `RuntimeImplementationInterface` now also
names that remaining handwritten object/ORAM coordination plus store
surface as its own
`ResidualHelperShellBoundary`, benchmark-backed through
`runtime_residual_helper_shell_boundary_validation.json`, and both
`RuntimeImplementationConfinementBoundary` and
`RuntimeImplementationKernelMachineConfinementBoundary` project that named
helper-shell cut explicitly. Lean now also packages the direct meeting between
that source cut and the emitted native machine witness as
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary`,
benchmark-backed through
`runtime_implementation_residual_helper_shell_machine_refinement_boundary_validation.json`;
that smaller theorem route now exposes consumed expected-kernel schedule,
kernel-op budget respect, runtime-phase-event budget respect, and exact
slot-program/kernel-step agreement directly at the residual helper-shell cut,
rather than leaving those facts only to the wider machine-confinement route.
The standalone
`SmallConfidentialKernelBoundary` / `SharedConfidentialKernelBoundary`,
the Rust/Lean `kernel_model_alignment_validation.json` route, and the tamper
suite now all pin those shared helper routes explicitly, with the small-kernel
boundary now also exact-matching the generated kernel machine, slot-support,
and confidential-kernel Rust artifacts against their Lean generators rather
than leaving those equalities only to the separate alignment report.
Together with the
modeled/source-pinned machine/effect, allocator, statement-trace, boxed
generated fixed public-capacity ORAM read transcript, fixed-public-batch ORAM write-log, exact ORAM commit
restore-vs-write-batch split, masked UO small-map lookup with exact
matched-fold semantics and public-capacity length rejection, masked UO
array-access with executable selected-slot acceptance/rejection/uniqueness,
generated-kernel public return-tail schedules, and the now-
imported lower-level store codec plus generated-store-helper shell, the
source-backed residual-helper-shell boundary now also states the stronger
public-only shell claim explicitly: handwritten `objects.rs`, `oram.rs`,
`codec.rs`, and `store.rs` are confined to the public bridge side, while the
confidential object selectors, ORAM lookup/update/rebuild logic, and store
seal/open/reseal helpers live only in Lean-generated helper modules. Lean now
exports that fact directly through
`RuntimeImplementationResidualHelperShellBoundary.handwrittenRuntimePublicOnly`,
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary.handwrittenRuntimePublicOnly`,
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement`,
`RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement`,
`RuntimeImplementationPublicBridgeObserverRefinementBoundary.paperPublicBridgeObserverRefinement`,
`RuntimeImplementationConfinementBoundary.handwrittenRuntimePublicOnly`,
`RuntimeImplementationConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`,
`RuntimeImplementationConfinementBoundary.paperPublicBridgeObserverRefinement`,
`RuntimeImplementationKernelMeetingConfinementBoundary` projected through
`RuntimeImplementationConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`
and `RuntimeImplementationConfinementBoundary.paperPublicBridgeObserverRefinement`,
`RuntimeImplementationKernelMachineConfinementBoundary.handwrittenRuntimePublicOnly`, and
`RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`,
plus the direct outer public observer theorem
`RuntimeImplementationKernelMachineConfinementBoundary.paperPublicBridgeObserverRefinement`.
The wider small-confidential-kernel-machine, shared-kernel-machine, and direct
kernel-machine-confinement routes now also expose explicit
`paperPublicOnlyResidualHelperShellRefinement` and
`paperPublicOnlyResidualHelperShellObserverRefinement` projections, and their
reports mark
`paper_public_only_residual_helper_shell_refinement_theorem_checked` and
`paper_public_only_residual_helper_shell_observer_refinement_theorem_checked`.
The small-confidential-kernel-machine report now also marks
`paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
and `paper_small_kernel_machine_observer_refinement_theorem_checked`.
The shared-kernel-machine report now also marks
`paper_shared_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
and `paper_shared_kernel_machine_observer_refinement_theorem_checked`.
The dedicated residual-helper-shell boundary, dedicated public-bridge observer
boundary, the top-level source-backed implementation-interface route, the
direct kernel-meeting route, the direct shared-kernel refinement route,
dedicated residual-helper-shell machine boundary, the
small-confidential-kernel-machine and shared-kernel-machine routes, and the
kernel-meeting-confinement, implementation-confinement, and direct
kernel-machine-confinement routes now also mark
`handwritten_runtime_public_only_theorem_checked` for the explicit
`handwrittenRuntimePublicOnly` corollary. The dedicated residual-helper-shell
machine report also marks the two larger public-only shell paper theorems
directly, alongside `native_machine_refinement_theorem_checked`.
The dedicated source-backed small-confidential-kernel and shared-confidential-
kernel reports now mark
`small_confidential_kernel_boundary_theorem_checked` /
`shared_confidential_kernel_boundary_theorem_checked` together with
`slot_adapter_boundary_theorem_checked`, and now also
`residual_helper_shell_boundary_theorem_checked` plus
`handwritten_runtime_public_only_theorem_checked`. The direct shared-kernel
refinement report now also marks
`paper_shared_kernel_refinement_with_public_only_handwritten_shell_theorem_checked`
and `paper_shared_kernel_observer_refinement_theorem_checked` for
`RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelRefinementWithPublicOnlyHandwrittenShell`
and `RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelObserverRefinement`.
The dedicated source-backed public-
bridge report now also marks `public_bridge_boundary_theorem_checked`. The
dedicated source-backed slot-adapter report now also marks
`slot_adapter_boundary_theorem_checked`. The dedicated slot-adapter machine
report now also marks `slot_adapter_boundary_theorem_checked`, the dedicated
residual-helper-shell machine report now also marks
`residual_helper_shell_boundary_theorem_checked`, and the dedicated public-
bridge observer report now also marks
`public_bridge_boundary_theorem_checked`. The shared-kernel-machine,
small-confidential-kernel-machine, kernel-meeting-confinement,
implementation-confinement, and direct kernel-machine-confinement reports now
also project `residual_helper_shell_boundary_theorem_checked` and
`slot_adapter_boundary_theorem_checked`, with the applicable
`shared_confidential_kernel_boundary_theorem_checked` and
`small_confidential_kernel_boundary_theorem_checked` fields alongside them.
The small-confidential-kernel-machine report also carries its direct paper-side
pair
`paper_small_kernel_machine_refinement_with_public_only_handwritten_shell_theorem_checked`
and `paper_small_kernel_machine_observer_refinement_theorem_checked`.
The direct kernel-meeting and direct shared-kernel refinement reports now also
re-emit `residual_helper_shell_boundary_theorem_checked`.
The kernel-meeting report now also marks
`confidential_statement_trace_bridge_boundary_theorem_checked` directly, and
the direct machine-confinement route now also marks
`public_bridge_boundary_theorem_checked`.
The dedicated source-backed confidential-statement-trace bridge report now also
marks `confidential_statement_trace_bridge_boundary_theorem_checked`.
The kernel-meeting-confinement report now also marks
`paper_end_to_end_confinement_with_public_only_handwritten_shell_theorem_checked`
and `paper_public_bridge_observer_refinement_theorem_checked`.
The remaining open item is therefore a native semantics-of-Rust refinement
theorem below the now-public-only residual helper implementation shell rather
than a wider ad hoc runtime surface. That target is smaller than before because
the generated store helper semantics for raw-slot copy/wipe, slot-table lookup
and replacement, event appends, bootstrapped UO-slot lengths, and update-only
UO reseal traces are now modeled in Lean and projected through the direct
machine-confinement route. Lean now names the exact remaining below-interface
target as `RuntimePaperNativeKernelAssumptions`, which packages
only the source-side confinement fact plus the native machine-finish boundary
object. The kernel-state and shell-trace refinement claims are no longer
separate fields in that paper-native bundle: Lean derives them from the
already checked `RuntimeKernelMachineFinishBoundary` /
`RuntimeKernelConfinementBoundary` route through
`RuntimePaperNativeKernelAssumptions.kernelStateRefinesLeanKernel` and
`RuntimePaperNativeKernelAssumptions.shellTraceRefinesShellContract`. Schedule
consumption, kernel-step budget respect, runtime-phase budget respect, and
slot-program/kernel-step exactness are likewise derived from the already
checked machine-finish boundary itself. The direct machine-confinement proof-grade
route now surfaces that path explicitly through
`ImportedRuntimeImplementationKernelMachineConfinementBoundary.toRuntimePaperNativeKernelAssumptions`,
the theorem
`importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_assumptions`,
the derived projection theorems
`importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_state_refinement`
and
`importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_shell_trace_refinement`,
the checker corollaries `importedBoundaryPaperNativeKernelAssumptions`,
`importedBoundaryPaperNativeKernelStateRefinement`, and
`importedBoundaryPaperNativeShellTraceRefinement`, and the emitted report bits
`paper_native_kernel_assumptions_theorem_checked`,
`paper_native_kernel_state_refinement_theorem_checked`, and
`paper_native_shell_trace_refinement_theorem_checked`. The
same paper-native route now also exposes
`RuntimePaperNativeKernelAssumptions.handwrittenRuntimeLacksDirectSecretOps`
and the checker corollary `importedBoundaryPaperNativeKernelLacksDirectSecretOps`,
with each direct kernel-machine scenario marking
`handwritten_runtime_lacks_direct_secret_ops_theorem_checked`. It now also
exposes
`RuntimePaperNativeKernelAssumptions.hostCoordinationLacksSecretSerialization`
and the checker corollary
`importedBoundaryPaperNativeKernelHostCoordinationLacksSecretSerialization`,
with each direct kernel-machine scenario marking
`handwritten_host_coordination_lacks_secret_serialization_theorem_checked`. The
same route now also exposes the theorem-facing store/ORAM codec-layout facts
through checker corollaries for nonzero transport shape, sealed-record length,
successful nonzero decode soundness, fixed-public-length decode-into
roundtrip/rejection/soundness, sealed-record decode split shape,
sealed-record open magic-header shape plus transport soundness for the
encoded nonzero nibbles, decoded sealed byte stream, and the
magic/nonce/ciphertext/tag split components, plus transport roundtrip for a
valid opened sealed-record split,
ORAM block encode/decode roundtrip, exact-length ORAM block decode/roundtrip
and decoded-block valid-shape facts, aggregate decoded bucket/stash block
valid-shape facts, ORAM bucket encoded length, exact-bucket decode acceptance,
bounded Path bucket decode for occupied block slot/leaf bounds and public
bucket-on-leaf-path membership plus decoded position-map agreement and
duplicate live-slot rejection plus position-map live-slot coverage,
generic whole-block-list position-map agreement/no-duplicate hooks,
Path-ORAM position-map page coverage, public metadata page split, exact
position-map page and aggregate position-map-pages decode acceptance,
position-map page byte-length mismatch rejection, position-map page-list public
page-count mismatch rejection, exact stash page decode acceptance, exact
stash-page byte-length mismatch rejection, stash page-list public page-count
mismatch rejection, aggregate stash-pages decode shape/block
validity, bounded aggregate stash decode for public stash/slot/leaf bounds,
stash position-map agreement, stash duplicate live-slot rejection,
and Path-ORAM position-map/stash page lengths. The generated ORAM metadata
decoder now guards the public position-map/stash page counts before indexing
and uses fallible `pages.get(...)` access, while the matching metadata encoder
fills the sealed page array through fallible `pages.get_mut(next_page)` access.
The generated ORAM block, bucket, counter, stash-page, and position-map byte
codecs now route fixed-offset reads/writes through checked `read_exact_range` /
`write_exact_range` and `read_u64_be_at` / `write_u64_be_at` helpers, including
checked bucket-payload windows, instead of direct byte indexing, local copy
staging, or fixed-offset slicing.
The generated object-helper map-record and surrogate-directory codecs follow
the same exact-range discipline for tag/key/value windows and decoded directory
slots, so the checked source boundary now rejects the old `out[0]`, fixed
byte-slice, and `out[slot]` decode paths there as well.
The generated store-surface reopen parser follows the same checked-helper
discipline through checked cursor/range helpers for magic, nonce, ciphertext,
tag, and boxed plaintext staging, so
the checked source boundary now rejects stale direct `split_at(...)` and
`payload.copy_from_slice(...)` paths there as well.
`RuntimeStoreCodecSemantics` now also gives that generated store surface
theorem-facing content: exact zeroed-buffer shape, exact-range reads,
exact-copy staging, seal-into-slice exact-length acceptance/rejection,
opened-payload shape, and wipe length/zeroing facts are exposed through both
the standalone residual-helper boundary and the direct machine-confinement
route.
`RuntimeStoreHelperSemantics` now also models the store helper's public
read/write metric shell and UO write evidence shape: reads and writes increment
only the public metric counters, UO writes keep the zero-write counter
unchanged, and the emitted UO physical write remains the public UPDATE shape.
`RuntimeOramHelperSemantics` now gives the generated ORAM helper layer
theorem-facing content below the byte codecs: masked Nat/Bool/option
selection, first-match slot lookup, vacant-slot allocation, fixed-stash clear,
push, overflow, and take shape, position-map leaf/value selection,
fresh/prior access-leaf selection, position-map/stash leaf updates,
public failed-put cases, path-bucket rebuild length/live-count bounds, fixed
path-access physical-read count, and the `rewrite_path_for_access` public
shell shape for fixed physical-write count, counter increment, and
load/effect/post-update/post-rebuild failure propagation are all modeled in
Lean. The transition-witness kind is also modeled as masked selection with
read-hit/read-miss cases and write-delete/update/insert/noop precedence rather
than only source-frozen Rust, and the witness payload shape now covers
slot/prior-leaf/next-leaf/fresh-leaf fields for read miss/hit and
delete/update/insert/noop write cases.
These facts are projected through both the standalone
residual-helper boundary and the direct machine-confinement route.
The generated value-operation layer applies that checked iterator/exact-range
discipline to struct-field zero materialization, canonical byte-buffer writes,
scalar canonical decoding, length words, `u128` tail writes, and masked
byte-array select/equality loops, so direct `fields[index]`,
`copy_from_slice(...)`, fixed-slice, and byte-index forms are rejected from
`generated_value_ops.rs` too. The shared `FixedBoxBuilder<T>` under that layer
now avoids direct slot indexing and prefix slicing as well.
The generated transcript/open/reseal paths also guard public directory-page and
bucket counts before using `get(...)` / `get_mut(...)`; surrogate directory
decoding takes its remaining public entry tail through
`entries.get_mut(next_entry_index..)`, and bucket / position-map decode plus
live-bucket construction write decoded public slots through fallible
`fixed_blocks.get_mut(slot)` / `position_map.get_mut(next_slot)` access. Live
Path-ORAM bucket validation guards the
public position-map and live-slot buffer lengths before using a decoded slot
index through fallible `position_map.get(...)`, `live_slots.get(...)`, and
`live_slots.get_mut(...)`. Its Lean helper semantics now also pin the
validation/update effect itself: unoccupied blocks leave the live-slot buffer
unchanged, valid occupied blocks replace exactly the decoded live slot with the
decoded leaf, and occupied blocks with out-of-range slot indexes or duplicate
live-slot occupancy are rejected. The final reconstruction coverage check is
now modeled too: empty position maps accept, missing live-slot buffer entries
reject, absent position-map heads are ignored, present heads with live slots
continue, and present heads with empty live slots reject. The Path-entry
reconstruction side is also modeled at the public shape level: reset produces
exactly `capacity` empty cells, unoccupied decoded blocks leave the entry
buffer unchanged, occupied out-of-range slots reject, and valid occupied blocks
preserve length while making exactly the decoded public slot point to the
decoded block cell. Lean also exposes the combined reconstruction loop-body
step: prior failures stay failed, unoccupied blocks leave the state unchanged,
validation or install failures set the failed flag, and valid occupied blocks
update both the live-slot buffer and entry buffer at the same decoded public
slot. The final reconstruction result predicate is modeled as the disjunction
of the step-failure flag and live-slot coverage failure, with the corresponding
success theorem requiring both to be false. Lean also models the block-list
fold around that step: an empty decoded block list leaves the reconstruction
state unchanged, a cons list is exactly one loop-body step followed by the tail
fold, and any prior failure is absorbing across the remaining public block
list. The whole decoded reconstruction shell is now modeled too: the initial
state contains exactly `capacity` empty live slots and entry cells with no
failure flag set, reconstruction is exactly the stash fold followed by the
decoded bucket-block fold, a stash-side failure absorbs the bucket phase, and
the final Boolean failure predicate is exposed for both prior-failure and
success cases. That shell now has a bucket-indexed variant as well, matching
the runtime gate that rejects any occupied decoded bucket block whose leaf is
not on that public bucket path before the block enters reconstruction; admitted
bucket blocks then reduce to the ordinary block-step semantics. The bridge
between codec-level decoded path bucket payloads and that bucket-indexed
helper reconstruction is now also explicit in Lean: each
`RuntimeOramCodecSemantics.CodecBlock` lifts to a `RuntimeOramHelperSemantics.StashBlock`
through `stashBlockOfCodecBlock` (canonicalising occupancy and decoding
slot/leaf fields), each codec block paired with a public bucket index lifts to
a helper `BucketBlock` through `bucketBlockOfCodecBlock`, and the
`bucketBlocksOfCodecBlocks` map preserves that public bucket index across the
full block list while the corresponding `stashBlocksOfCodecBlocks` list keeps
the same length and composes with `BucketBlock.block` projection. The bridge
discharges admission directly: codec blocks proven to satisfy
`CodecBlock.LiveOnBucketPath` admit into the helper bucket-block reconstruction
without short-circuit, and all-`LiveOnBucketPath` lifted bucket-block lists
admit pointwise. Once admitted, the bucket-indexed reconstruction reduces
mechanically to the flat decoded-block reconstruction over the bridged stash
block list, so the bucket-indexed reconstruction state and final failure
predicate over a decoded path bucket payload coincide with the flat
reconstruction state and predicate over the bridged blocks. These bridge
theorems are projected through both the standalone residual-helper-shell
boundary and the direct machine-confinement route, exposed in the imported
JSON checker, and emitted as
`oram_helper_bucket_block_of_codec_block_bucket_index_theorem_checked`,
`oram_helper_bucket_block_of_codec_block_block_theorem_checked`,
`oram_helper_stash_blocks_of_codec_blocks_length_theorem_checked`,
`oram_helper_bucket_blocks_of_codec_blocks_length_theorem_checked`,
`oram_helper_bucket_blocks_of_codec_blocks_map_block_theorem_checked`,
`oram_helper_bucket_block_admission_failed_bridge_unoccupied_theorem_checked`,
`oram_helper_bucket_block_admission_failed_bridge_live_on_bucket_path_theorem_checked`,
`oram_helper_bucket_blocks_of_codec_blocks_admitted_of_live_on_bucket_path_theorem_checked`,
`oram_helper_reconstruct_path_bucket_blocks_eq_reconstruct_path_blocks_of_admitted_theorem_checked`,
`oram_helper_reconstruct_path_bucket_blocks_bucket_blocks_of_codec_blocks_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_state_bucket_blocks_of_codec_blocks_theorem_checked`,
and
`oram_helper_reconstruct_path_decoded_buckets_failed_bucket_blocks_of_codec_blocks_theorem_checked`.
The bridge now also has higher-level composed forms that consume codec
acceptance directly, so call sites do not need to restate `LiveOnBucketPath`:
whenever path-bucket bytes decode through `decodePathBucketPathBoundedExact?`,
`decodePathBucketPositionMapBoundedExact?`, or
`decodePathBucketUniquePositionMapBoundedExact?`, the bucket-indexed
reconstruction state and final failure predicate over the bridged bucket
blocks coincide with the flat-list reconstruction over the bridged stash
blocks. Those composed theorems are projected through the same layers and
emitted as
`oram_helper_reconstruct_path_decoded_buckets_state_decoded_path_bucket_path_bounded_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_failed_decoded_path_bucket_path_bounded_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_state_decoded_path_bucket_position_map_bounded_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_failed_decoded_path_bucket_position_map_bounded_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_state_decoded_path_bucket_unique_position_map_bounded_theorem_checked`,
and
`oram_helper_reconstruct_path_decoded_buckets_failed_decoded_path_bucket_unique_position_map_bounded_theorem_checked`.
Lean now also models the runtime callback fold itself:
`reconstructPathDecodedBucketsListState` and `reconstructPathDecodedBucketsListFailed`
take a `List DecodedBucket` (each carrying a public bucket index plus a
decoded codec payload), flatten through `bucketBlocksOfDecodedBuckets` /
`stashBlocksOfDecodedBuckets`, and feed into the existing decoded-block
reconstruction. The fold-level `LiveOnBucketPath` predicate
`DecodedBuckets.LiveOnBucketPath leafCount decodedBuckets` requires every
block of every decoded bucket to satisfy `CodecBlock.LiveOnBucketPath
leafCount b.bucketIndex`, and under that hypothesis the list-level
reconstruction state and final failure predicate collapse exactly to the
flat-list state and failure over the bridged stash blocks. Companion theorems
expose `reconstructPathBucketBlocks_append`,
`reconstructPathBlocks_append`, prior-failure absorption, success
acceptance, and the no-buckets initial-state shape. These facts are
projected through both checker boundaries and emitted as
`oram_helper_reconstruct_path_bucket_blocks_append_theorem_checked`,
`oram_helper_reconstruct_path_blocks_append_theorem_checked`,
`oram_helper_reconstruct_path_bucket_blocks_bucket_blocks_of_decoded_buckets_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_list_state_live_on_bucket_path_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_list_failed_live_on_bucket_path_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_list_failed_prior_failure_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_list_failed_success_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_list_state_no_buckets_theorem_checked`,
and
`oram_helper_reconstruct_path_decoded_buckets_list_failed_no_buckets_theorem_checked`.
For runtime call sites the helper layer also exposes the smallest possible
chain step from "decoded codec bytes" to
`DecodedBuckets.LiveOnBucketPath`: `decodedBuckets_liveOnBucketPath_cons`
extends a tail proof with one head per-bucket fact, and each of the three
`decodedBucket_liveOnBucketPath_of_decodedPathBucket{Path,PositionMap,UniquePositionMap}Bounded`
lemmas converts a single `decodePathBucket{...}BoundedExact?` decode into the
matching head fact. These chain primitives land at every layer and are
emitted as
`oram_helper_decoded_buckets_live_on_bucket_path_cons_theorem_checked`,
`oram_helper_decoded_bucket_live_on_bucket_path_of_decoded_path_bucket_path_bounded_theorem_checked`,
`oram_helper_decoded_bucket_live_on_bucket_path_of_decoded_path_bucket_position_map_bounded_theorem_checked`,
and
`oram_helper_decoded_bucket_live_on_bucket_path_of_decoded_path_bucket_unique_position_map_bounded_theorem_checked`.
The reconstruction shell now also carries an absolute-capacity invariant on
both the live-slots buffer and the path-entry buffer: every
per-block-validation/install step preserves `liveSlots.length` and
`entries.length`, every per-bucket admission step preserves them, the
list-folds preserve them, and starting from `initialReconstructionState
capacity` both buffers stay at exactly `capacity` throughout the stash
phase, the bucket phase, and the runtime callback fold. These invariants
are exposed at every layer and emitted as
`oram_helper_live_slots_after_block_validation_length_theorem_checked`,
`oram_helper_reconstruct_path_block_step_live_slots_length_theorem_checked`,
`oram_helper_reconstruct_path_block_step_entries_length_theorem_checked`,
`oram_helper_reconstruct_path_blocks_live_slots_length_theorem_checked`,
`oram_helper_reconstruct_path_blocks_entries_length_theorem_checked`,
`oram_helper_reconstruct_path_bucket_block_step_live_slots_length_theorem_checked`,
`oram_helper_reconstruct_path_bucket_block_step_entries_length_theorem_checked`,
`oram_helper_reconstruct_path_bucket_blocks_live_slots_length_theorem_checked`,
`oram_helper_reconstruct_path_bucket_blocks_entries_length_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_state_live_slots_length_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_state_entries_length_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_list_state_live_slots_length_theorem_checked`,
and
`oram_helper_reconstruct_path_decoded_buckets_list_state_entries_length_theorem_checked`.
Per-step non-failure is also preserved: starting from a non-failed state,
when validation and install both succeed for the running buffers, the
post-step state remains non-failed. This holds for the basic block step
and, under bucket-on-leaf-path admission, for the bucket-block step. These
facts are emitted as
`oram_helper_reconstruct_path_block_step_preserves_non_failure_theorem_checked`
and
`oram_helper_reconstruct_path_bucket_block_step_preserves_non_failure_admitted_theorem_checked`.
The non-failure preservation is also lifted to the fold level via the
recursive well-formedness predicates `StashWellFormedFrom` and
`BucketBlocksWellFormedFrom`, each of which carries per-block validation,
install (and admission) hypotheses against the running reconstruction state
through the list. From these the helper layer derives:
`reconstructPathBlocks_preservesNonFailure_of_wellFormed`,
`reconstructPathBucketBlocks_preservesNonFailure_of_wellFormed`,
`reconstructPathDecodedBucketsState_preservesNonFailure`, and
`reconstructPathDecodedBucketsListState_preservesNonFailure`. These give
the runtime a clean "well-formed input → reconstruction does not fail"
shell theorem at every fold level. The bits land at every layer as
`oram_helper_stash_well_formed_from_nil_theorem_checked`,
`oram_helper_bucket_blocks_well_formed_from_nil_theorem_checked`,
`oram_helper_reconstruct_path_blocks_preserves_non_failure_of_well_formed_theorem_checked`,
`oram_helper_reconstruct_path_bucket_blocks_preserves_non_failure_of_well_formed_theorem_checked`,
`oram_helper_reconstruct_path_decoded_buckets_state_preserves_non_failure_theorem_checked`,
and
`oram_helper_reconstruct_path_decoded_buckets_list_state_preserves_non_failure_theorem_checked`.
Combining well-formed input with the position-map coverage hypothesis gives
the end-to-end "successful reconstruction" theorem at the helper layer:
`reconstructPathDecodedBucketsFailed_success_of_wellFormed` and
`reconstructPathDecodedBucketsListFailed_success_of_wellFormed` show that
when the stash is well-formed against the initial reconstruction state, the
bucket-block list is well-formed against the post-stash state, and the live
slots cover the position map at the final state, the runtime's coverage
predicate `reconstructPathDecodedBucketsFailed = false` (resp.
`...ListFailed = false`). These are emitted as
`oram_helper_reconstruct_path_decoded_buckets_failed_success_of_well_formed_theorem_checked`
and
`oram_helper_reconstruct_path_decoded_buckets_list_failed_success_of_well_formed_theorem_checked`.
The flatten-level admission lemma is also exposed:
`bucketBlocksOfDecodedBuckets_admitted_of_liveOnBucketPath` shows that under
`DecodedBuckets.LiveOnBucketPath leafCount decodedBuckets`, every entry in
the flattened bucket-block list satisfies admission, emitted as
`oram_helper_bucket_blocks_of_decoded_buckets_admitted_of_live_on_bucket_path_theorem_checked`.
The checked helper shell therefore rejects metadata,
bucket-count, entry-tail, position-map-buffer, fixed-block-slot, or
live-slot-buffer drift before page, slice, or decoded-slot access, and it
rejects reintroducing direct fixed-offset ORAM byte indexing/slicing in the
generated codec stack. Those same
ORAM/store
codec-layout facts now also surface at the standalone residual-helper-shell
checker/report, so the smaller public-only helper-shell cut carries the
block, bucket, exact public count-guard acceptance/rejection, Path bucket,
position-map page-list, and stash page-list
obligations directly rather than inheriting them only from the larger machine
confinement route. The emitted machine-confinement and residual-helper-shell
reports mark
those as `store_codec_transport_shape_theorem_checked`,
`store_codec_decode_sound_theorem_checked`,
`store_codec_decode_into_roundtrip_theorem_checked`,
`store_codec_decode_into_rejects_length_mismatch_theorem_checked`,
`store_codec_decode_into_sound_theorem_checked`,
`store_sealed_encoded_len_theorem_checked`,
`store_sealed_record_decode_shape_theorem_checked`,
`store_sealed_record_open_shape_theorem_checked`,
`store_sealed_record_open_transport_sound_theorem_checked`,
`store_sealed_record_transport_roundtrip_theorem_checked`,
`store_surface_read_exact_range_length_theorem_checked`,
`store_surface_copy_exact_into_shape_theorem_checked`,
`store_surface_seal_into_accepts_exact_length_theorem_checked`,
`store_surface_open_payload_shape_theorem_checked`,
`store_surface_wipe_zeros_theorem_checked`,
`oram_block_codec_roundtrip_theorem_checked`,
`oram_exact_block_codec_roundtrip_theorem_checked`,
`oram_exact_block_decode_length_theorem_checked`,
`oram_exact_block_decode_valid_shape_theorem_checked`,
`oram_bucket_codec_length_theorem_checked`,
`oram_public_count_guard_accepts_exact_theorem_checked`,
`oram_directory_pages_reject_count_mismatch_theorem_checked`,
`oram_buckets_reject_count_mismatch_theorem_checked`,
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
`path_stash_pages_rejects_page_count_mismatch_theorem_checked`; the
kernel-model alignment artifact
also records
`runtime_residual_helper_shell_boundary_oram_codec_semantics_theorems_present`.
The same reports now also mark the ORAM helper operational facts as
`oram_helper_masked_select_*_theorem_checked`,
`oram_helper_slot_for_key_within_capacity_theorem_checked`,
`oram_helper_allocate_slot_within_capacity_theorem_checked`,
`oram_helper_first_vacant_index_within_capacity_theorem_checked`,
`oram_helper_clear_fixed_stash_*_theorem_checked`,
`oram_helper_push_fixed_stash_*_theorem_checked`,
`oram_helper_take_selected_block_*_theorem_checked`,
`oram_helper_select_position_map_leaf_*_theorem_checked`,
`oram_helper_select_value_at_*_theorem_checked`, and
`oram_helper_access_leaf_uses_*_theorem_checked`, and static checks require
both
`runtime_residual_helper_shell_boundary_oram_helper_semantics_theorems_present`
and
`runtime_implementation_kernel_machine_confinement_oram_helper_semantics_theorems_present`.
The
umbrella `runtime-boundary-validation` report now also marks the matching
source-side minimization bit
`runtime_implementation_kernel_machine_confinement_paper_native_kernel_assumption_bundle_minimized`
and is accepted again with the current public-only handwritten shell /
generated-helper split. UO array
out-of-range logical indices are now modeled and implemented
as masked no-match / no-op cases on the UO path rather than public pre-scan
errors, and generated confidential-kernel slots reject non-final source returns
before lowering instead of truncating execution through a runtime
`state.returned` / `break` branch.

## Current And Target TCB

| Component | Current status | Final target |
| --- | --- | --- |
| Lean kernel plus Lean theorem/checker development | trusted | trusted |
| Explicit backend / cryptographic / deployment assumptions | trusted assumptions | keep explicit and minimize |
| `uo-check` | not in the proof-grade TCB | not in the TCB |
| `checkProofGradeTranslationArtifacts` (direct Lean artifact checker) | demoted from the trust root by W4.6 (commit `7e0483d`); the W4.2 + W4.4 + W4.5 chain (`proofGrade_compiler_correctness_supersedes_artifact_checker` in `ProofGrade.lean`) supplies the same content directly. The artifact checker remains as an executable proof witness — useful for checking concrete (source, artifact) pairs in CI — but is no longer load-bearing for the trust narrative | keep as an executable proof witness; trust flows via the W4.2 + W4.4 + W4.5 theorems |
| `mplus-probe` | not in the proof-grade TCB | not in the TCB |
| `uo-solc` | not trusted for current artifact-level acceptance; semantic compiler correctness now Lean-proved end-to-end at the source-to-IR level (W4.2, full admitted post-resolution Sol AST), the IR-to-kernel level (W4.4, with both forward and reverse iff between admission and lowering success), and the manifest-exactness lift for the `kernel_steps` field on the happy path (W4.5 enabling theorem + main-body static projections + body/program-level runtime-vs-static lift). The W4.6 demotion corollary `proofGrade_compiler_correctness_supersedes_artifact_checker` bundles W4.2 + W4.4 + W4.5 into a single named statement that supersedes the direct artifact checker as the trust root. The only remaining trusted surface inside `uo-solc` is the parser-level syntactic preprocessing (`solang_parser` plus state-name resolution, capacity literal lookup, `abi.encodePacked` unwrapping, helper-function inlining, `AssignAdd`-style desugaring) that produces the post-resolution Sol AST | the parser preprocessing remains a trusted front-end equivalent to `solang_parser` |
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | currently trusted for the implementation side of the checked runtime proof/interface route, now frozen explicitly through `PaperMainRuntimeKernelBoundary`, `PaperMainRuntimeKernelSlotBoundary`, `RuntimeImplementationInterface`, `RuntimeImplementationPublicBridgeBoundary`, `RuntimeImplementationSlotAdapterBoundary`, `RuntimeImplementationResidualHelperShellBoundary`, `RuntimeImplementationSmallConfidentialKernelBoundary`, `RuntimeImplementationConfidentialStatementTraceBridgeBoundary`, `RuntimeImplementationSharedConfidentialKernelBoundary`, `RuntimeImplementationPublicBridgeObserverRefinementBoundary`, `RuntimeImplementationSlotAdapterMachineRefinementBoundary`, `RuntimeImplementationResidualHelperShellMachineRefinementBoundary`, `RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary`, `RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary`, `RuntimeImplementationKernelMeetingBoundary`, `RuntimeImplementationKernelMeetingConfinementBoundary`, `RuntimeImplementationKernelMachineConfinementBoundary`, `RuntimeImplementationSharedKernelMachineRefinementBoundary`, `RuntimeImplementationSharedKernelRefinementBoundary`, and `RuntimeImplementationConfinementBoundary`; that checked interface now reaches the shared `uo-core` confidential-kernel interpreter and masked-selection/value layer used by the live runtime, plus the live Path ORAM masked full-scan lookup/update/stash-rebuild layer, boxed generated public-capacity ORAM read transcripts, fixed-public-batch ORAM write evidence, masked UO small-map lookup, masked UO array read/write access with UO-path out-of-range no-match behavior, the public generated-kernel return-tail schedule backed by `RuntimeReturnScheduleDiscipline`, the exact transition-shaped fresh-leaf schedule used by the modeled witness extractor, and the shared `uo-core` crate-root export shell in `crates/uo-core/src/lib.rs`, where the theorem-carrying public API for controller certificates, shell traces/contracts, runtime outcomes, and trusted-kernel bundles is frozen while the generated confidential-kernel module remains non-exported; the Rust/Lean kernel-model alignment route now also pins centralized confidential statement, named-expression, named-pure-expression, slot-expression, and slot-pure-expression profile tables together with the `RuntimeKernelMachineFinishWitness` field schema and the source-backed runtime implementation, public-bridge, slot-adapter, residual-helper-shell, public-bridge observer-refinement, slot-adapter-machine-refinement, small-confidential-kernel, confidential-statement-trace-bridge, shared-confidential-kernel, residual-helper-shell-machine-refinement, small-confidential-kernel-machine-refinement, confidential-statement-trace-bridge-refinement, kernel-meeting, kernel-meeting-confinement, and kernel-machine-confinement JSON schemas, while the source-backed implementation interface also pins the explicit named-to-slot lowering bridge and the concrete slot-statement / slot-expression / slot-pure-expression evaluator order used by the live interpreter; the closer-to-implementation emitted `RuntimeKernelMachineFinishWitness` now meets that checked inner source cut directly first at the standalone public-bridge boundary, where the abstract engine/runtime/shell/state/theorem split is checked on its own and the tamper suite rejects representative bridge-module ownership, engine-bridge bypass, shell confidentiality bleed, state staging bypass, theorem-side manual trace materialization drift, and shared `uo-core` crate-root generated-kernel export drift, then at the dedicated slot-adapter boundary, where the handwritten `uo-kernel-runtime` forwarding shell is isolated explicitly and the drift suite rejects representative generated slot-support argument-count drift, generated confidential-interpreter drift, shared-kernel interpreter-bypass drift, and raw confidential-argument observation in the handwritten adapter, then at the dedicated machine-backed slot-adapter boundary, where the same smaller source cut is paired directly with the live machine-finish witness and fixed slot program/opcode trace and the drift suite rejects expected-schedule-index drift, kernel-op/runtime-phase capacity drift, slot-program body drift, opcode-trace drift, generated confidential-interpreter drift, shared-kernel interpreter-bypass drift, generated post-return-break drift, generated slot-support argument-count drift, and raw confidential-argument observation in the handwritten adapter, and whose paper-facing conjunction is now projected explicitly through the wider small-confidential-kernel-machine, shared-kernel-machine, kernel-meeting-confinement, implementation-confinement, and direct kernel-machine-confinement routes, with each emitted report marking `paper_slot_adapter_machine_refinement_theorem_checked`, then at the residual-helper-shell boundary, where Lean packages the machine-backed public-only shell claim as `RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement` and the narrower observer-side slice as `RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement`, and also through the dedicated machine-backed public-bridge observer route `RuntimeImplementationPublicBridgeObserverRefinementBoundary.paperPublicBridgeObserverRefinement`, which now stands as its own checked boundary instead of only appearing as an outer corollary. The direct machine-confinement boundary then projects through that dedicated public-observer cut and reconstructs the same outer theorem from the full source-backed implementation interface plus the live machine-finish witness and fixed slot program/opcode trace without depending on the separate emitted finish-slot meeting artifact; Lean now packages that direct route as `RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell`, while the matching direct outer public-observer slice remains exposed separately as `RuntimeImplementationKernelMachineConfinementBoundary.paperPublicBridgeObserverRefinement`; together those theorems state source confinement, that handwritten runtime confidential work lives only in generated helpers, Lean-kernel refinement, shell-trace refinement, schedule consumption, kernel-op and runtime-phase capacity bounds, and slot-program/kernel-step exactness together; the tamper suite rejects representative named-expression profile-table drift, named-pure-expression profile-table drift, named-to-slot lowering drift, statement-trace drift on both the standalone confidential-statement-trace bridge and smaller finish-slot artifact sides, machine-finish schedule/capacity drift on the standalone machine-witness and on the combined machine-backed public-bridge observer, slot-adapter, residual-helper-shell, small-kernel, shared-kernel, meeting-confinement, implementation-confinement, and direct machine-confinement routes, direct tiny-kernel secret-branch / ORAM early-exit scan drift at both the standalone and machine-backed small-confidential-kernel cuts, slot-adapter source-side drift on the generated slot-support / generated confidential-interpreter / shared-kernel bridge / handwritten adapter surfaces, UO array direct-index/OOB-branch drift, UO small-map lookup early-exit drift, ORAM write-log growable-vector drift, generated-interpreter post-return-break drift on the machine-backed slot-adapter route and on the direct machine-confinement route, finish-slot slot-program/opcode/public-schedule drift on the combined confidential-statement-trace bridge refinement route and the kernel-meeting / kernel-meeting-confinement routes, direct machine-confinement schedule/capacity/slot-program/opcode/public-schedule/source-side/statement-trace drift, standalone public-bridge boundary source-side drift on its own bridge-module / engine / shell / state / theorem cut, standalone and machine-backed shared `uo-core` crate-root generated-kernel export drift, dedicated public-bridge observer route slot-program/opcode drift plus source-side/object/ORAM/store/statement-trace drift, meeting-route source-side drift on both the small-kernel and statement-trace sides, and reintroduction of the older single-fresh-leaf approximation across the standalone implementation-interface, standalone public-bridge-boundary, standalone slot-adapter-boundary, standalone residual-helper-shell-boundary, standalone small-confidential-kernel-boundary, standalone confidential-statement-trace-bridge-boundary, standalone shared-confidential-kernel-boundary, public-bridge observer-refinement-boundary, slot-adapter machine-refinement-boundary, residual-helper-shell machine-refinement-boundary, small-confidential-kernel machine-refinement-boundary, confidential-statement-trace bridge refinement-boundary, kernel-meeting-boundary, kernel-meeting-confinement-boundary, direct kernel-machine-confinement-boundary, shared-kernel machine-refinement-boundary, shared-kernel-refinement-boundary, and combined implementation-confinement-boundary routes | keep the kernel tiny and push to a deeper semantics-of-Rust refinement below the strengthened runtime/shared-kernel source interface |
| Rust code outside the tiny kernel | no longer part of the current confidential-work claim; the checked source-backed implementation interface pins it to the public bridge side and tamper validation rejects representative drift | keep it public-only or remove it from the runtime path entirely |

The current source-backed interface also pins the live kernel-step and
runtime-phase tracker journals to fixed-capacity boxed `BoundedJournal<T>`
storage in `uo-core` and rejects the older tracker-side `Vec` fields. This is
part of the implementation-side route toward the eventual native
semantics-of-Rust refinement theorem, not a new external assumption.

## Observer Shape

We write:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

where:

- `public_outcome` contains entrypoint id, public args, termination status,
  declared status policy, public output shape, declared return policy, any
  plaintext public/declassified return payload, declassification labels, and
  public gas
- `boundary_schedule` is the exact host-visible enclave boundary sequence
- `storage_trace` is the normalized persistent read/write trace
- `micro_trace` is the SGX-specific tuple
  `(page_trace, exit_trace, shared_resource_trace)`

## Normalized Micro Observer

The paper theorem does not claim raw equality of SGX micro traces. Instead it
claims equality after a fixed normalization and simulation step derived from
`L_sgx_micro`.

Define `Norm_micro` to map:

- each page event to its public `(page_kind, fault_or_evict)` class
- the exit trace to its normalized exit pattern
- the shared-resource trace to its normalized public event-class schedule

Define `Sim_micro(L_sgx_micro)` to reconstruct that normalized micro trace from
the explicit leakage object:

```text
L_sgx_micro =
  ( public_outcome,
    model_tags,
    boundary_event_budget,
    controller_phase_count,
    controller_phase_order,
    page_trace_budget,
    page_trace_regions,
    exit_trace_budget,
    normalized_exit_pattern,
    shared_resource_budget,
    shared_resource_pattern,
    controller_workset_pages,
    workset_regions,
    recursive_position_map_depth,
    stash_bound )
```

The paper-facing micro claim is then:

```text
Norm_micro(micro_trace(c1)) = Sim_micro(L_sgx_micro(c1))
Norm_micro(micro_trace(c2)) = Sim_micro(L_sgx_micro(c1))
```

whenever `c1` and `c2` have the same public projection.

## Exact Backend Theorem

For exact backends, if two configurations `c1` and `c2` have the same public
projection, then:

```text
public_outcome(c1) = public_outcome(c2)
boundary_schedule(c1) = boundary_schedule(c2)
storage_trace(c1) = storage_trace(c2)
Norm_micro(micro_trace(c1)) = Sim_micro(L_sgx_micro(c1))
Norm_micro(micro_trace(c2)) = Sim_micro(L_sgx_micro(c1))
```

This is the exact-UO SGX theorem under the paper-facing observer.

## ORAM-Backed Theorem

For ORAM-backed storage, if two configurations `c1` and `c2` have the same
public projection, then:

```text
public_outcome(c1) = public_outcome(c2)
boundary_schedule(c1) = boundary_schedule(c2)
R_store(storage_trace(c1), storage_trace(c2); L_oram(c1))
Norm_micro(micro_trace(c1)) = Sim_micro(L_sgx_micro(c1))
Norm_micro(micro_trace(c2)) = Sim_micro(L_sgx_micro(c1))
```

where `R_store` is the storage relation inherited from the ORAM theorem.

## Joint Composition Theorem

If:

- the storage projection satisfies the backend storage theorem
- the SGX controller micro projection satisfies the normalized micro theorem
- `public_outcome`, `boundary_schedule`, and `L_sgx_micro` are public-safe

then the full SGX execution satisfies the mixed theorem above with exact public
boundary behavior and normalized SGX micro simulation.

## Lean Mapping

The abstract ORAM theorem boundary is now surfaced explicitly as:

- `OramSecurityInterface` and `ComputationalUOWith` in
  `proof/lean/UOToolchain/OramGame.lean`
- `StandardOramSecurityInterface` and
  `computationalStandardOram_projects_to_computationalUOWith` in
  `proof/lean/UOToolchain/StandardOramReduction.lean`
- `PathOramSecurityAssumptions`, `proofGradePathOramSecurityInterface`, and
  `computationalPathOram_fromPublicViewLeafValuesBucketLocationAndShape_projects_to_computationalUOWith` in
  `proof/lean/UOToolchain/PathOramSecurity.lean`

For the proof-grade path candidate, the remaining storage theorem boundary is
already narrower than `OramAccessLeakage`: `PathOramSecurity.lean` projects
away the schedule field before the admitted storage theorem is used.
It also no longer treats raw path bucket indices in `logicalAccesses` as exact
public data: the proof-grade path interface normalizes those logical events to
a public skeleton before comparing views. On the storage side it now exposes a
leaf-value hidden witness interface: the ordered per-access leaf scaffold is
reconstructed from the public logical trace plus public ORAM metadata, and
bucket-trace secrecy is derived from hidden leaf values together with a
deterministic public projection from those values to root-to-leaf bucket
paths. The clean-path proof stack now goes one step further and instantiates
that hidden leaf-value layer with a canonical finite-distribution sampler
indexed by the public scaffold. The decomposition is now:

- exact public reconstruction of the ordered leaf scaffold
- a canonical finite-distribution sampler for per-access leaf values
- exact public canonicalization of sampled leaf values from the public part
- exact public constancy of the leaf-schedule scaffold
- deterministic projection from leaf schedules and leaf values to bucket traces
- exact public constancy of the non-bucket location scaffold
- exact public constancy of storage-shape projections

The canonical leaf-value layer is exposed through:

- `FiniteDistribution.lean`
- `PathOramLeafValueCanonicalOnPublicPart`
- `PathOramCanonicalLeafValueSecurityAssumptions`
- `computationalPathOram_fromPublicViewCanonicalLeafValuesBucketLocationAndShape_projects_to_computationalUOWith`

At the runtime-artifact boundary, the explicit canonical fresh-coin family is
now related to that hidden accessed-leaf theorem interface by coverage, not by
literal equality of seed spaces. Concretely:

- the public leaf scaffold determines the hidden accessed-leaf seed space
- the explicit runtime artifact enumerates the larger canonical fresh-coin seed
  space, which may also include non-leaf coins such as leaf-resampling coins
- `RuntimePaperInstantiation.lean` proves that if the explicit fresh-coin
  family covers every hidden accessed-leaf seed, Lean can select one
  representative explicit witness per hidden seed and quotient the runtime
  family into the theorem-facing hidden leaf-value family

This is the exact bridge used by
`CheckCanonicalPathOramPaperInstantiation.lean`,
`CheckCanonicalPathOramPairTheoremInput.lean`, and the probe’s explicit and
compact canonical-pair validation paths. It closes the
runtime/theorem instantiation gap without weakening the theorem boundary or
adding new backend assumptions.

That instantiation route is now also proof-grade aware: the same hidden-seed
quotient step preserves the runtime-kernel boundary through
`ProofGradeConcreteRuntimePathOramConfigSlice`,
`ProofGradeConcreteRuntimePathOramPairSlice`, and
`ConcreteRuntimePathOramProofGradePairBoundary`, so the concrete pair theorem
path now carries per-side `RuntimeProofGradeKernelBoundaryFacts`, the direct
`RuntimeProofGradeKernelInterface` theorem, and the local
`PaperMainRuntimeKernelBoundaryAt` interface instead of forgetting the runtime
boundary at the public-view quotient. The stronger native slot route now keeps
that same concrete quotient path aligned with the shared slot-DSL story via
`ProofGradeConcreteRuntimePathOramConfigSlotSlice`,
`ProofGradeConcreteRuntimePathOramPairSlotSlice`, and
`ConcreteRuntimePathOramProofGradeSlotPairBoundary`, so the concrete route now
also carries per-side native slot-boundary and confinement-boundary objects
instead of dropping back to the weaker non-slot boundary.
The paper theorem route now exposes the matching per-configuration interfaces
`PaperMainRuntimeKernelBoundaryAt` and `PaperMainRuntimeKernelSlotBoundaryAt`,
and those interfaces now project directly both to the native runtime/kernel
interface theorem and to valid native shell-boundary bundles, so these
concrete proof-grade artifacts and the final bundle-level
`PaperMainRuntimeKernelBoundary` story now literally share the same boundary
vocabulary.
The imported artifact route now reaches that same local interface directly:
the imported kernel-interface family projects to
`PaperMainRuntimeKernelBoundaryAt`, the imported paper-main family bundle also
projects directly to `PaperMainRuntimeKernelBoundaryAt`, and the stronger
imported slot-family bundle projects directly to both
`PaperMainRuntimeKernelSlotBoundaryAt` and
`PaperMainRuntimeKernelBoundaryAt`.

The concrete backend specialization is now surfaced explicitly in:

- `proof/lean/UOToolchain/PathOramLocalPosmapV1.lean`
- `PathOramLocalPosmapV1SecurityAssumptions`
- `pathOramLocalPosmapV1SecurityInterface`
- `PathOramLocalPosmapV1StandardStorageBoundary`
- `PathOramLocalPosmapV1StandardPaperMainBoundary`
- `pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith`
- `pathOramLocalPosmapV1_standardStorageBoundary_projects_to_paperMainSgxExecution`
- `pathOramLocalPosmapV1_standardStorageBoundary_projects_to_teeStorage`
- `pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageBoundary`
- `SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_standardPaperMainBoundary`
- `PathOramLocalPosmapV1PaperTheoremBoundary`
- `SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperTheoremBoundary`
- `pathOramLocalPosmapV1_paperMain_jointSecurity_projects_to_sgxExecution`
- `PathOramLocalPosmapV1ArtifactPaperMainBoundary`
- `pathOramLocalPosmapV1_artifactPaperMainBoundary`

That module does not discharge the remaining ORAM assumptions by itself. What
it does is fix the exact theorem-facing boundary for the repo’s concrete
`path_oram_local_posmap_v1` candidate and package the current computational-UO,
paper-main SGX, joint-SGX, artifact-composition, and TEE-storage projections
into named endpoints. It now also exposes the explicit import point for an
external or separately mechanized standard Path ORAM theorem: once that theorem
is proved at `PathOramLocalPosmapV1StandardStorageBoundary`, the repo’s
concrete computational-UO, paper-main SGX, and TEE-storage claims follow by
named projection lemmas without changing the theorem boundary. The current
seeded runtime proof bundle now also instantiates that standard-theorem import boundary
directly, including the preferred `PathOramJACMLiteratureTheoremAt` route at
the runtime-facing `leafRun`, so there is no longer an open backend-theorem
gap at the concrete repo boundary. The paper route and the artifact route now
share that frozen theorem boundary, but they are not symmetric as provenance
claims: the current paper choice is to use the citation route as the main
narrative, the repo keeps the self-instantiated closure only for executable
validation, and the stronger external-theorem import route remains future work.

The current paper-facing aliases are:

- Exact backend main theorem:
  `paperMain_exactUO_projects_to_sgxExecution` in
  `proof/lean/UOToolchain/SgxExactProjection.lean`
- ORAM-backed main theorem:
  `paperMain_computationalUO_projects_to_sgxExecution` in
  `proof/lean/UOToolchain/SgxOramProjection.lean`
- Joint composition main theorem:
  `paperMain_jointSecurity_projects_to_sgxExecution` in
  `proof/lean/UOToolchain/SgxJointProjection.lean`

The normalized SGX micro relation itself is:

- `normalizedObservedSGXMicroRelation` in
  `proof/lean/UOToolchain/SgxMicroGame.lean`

The leakage-to-simulator normalization lemma for the concrete public controller
instance is:

- `normalizeMicroTrace_controllerMicroTraceOfShape` in
  `proof/lean/UOToolchain/SgxControllerTrace.lean`

## Presentation Strategy

For the current paper, the theorem narrative is:

- present the ORAM core through the citation route, using the JACM theorem
  source at `PathOramLocalPosmapV1StandardTheoremTarget`
- use `PaperMainPathOramTheoremSourceAt` and
  `pathOramLocalPosmapV1_paperMainStandardTheoremRealization` as the named Lean
  route for that presentation
- state the explicit `PathOramLocalPosmapV1SecurityAssumptions` provenance
  profile from `docs/path-oram-citation-import-plan.md` rather than implying
  those backend facts are already independently mechanized
- present the repo contribution as the bridge proving that the concrete
  compiler/runtime artifacts conform to that frozen interface
- then derive the computational-UO, TEE-storage, and paper-facing SGX
  consequences through the already mechanized projection lemmas

The stronger external-theorem import route remains documented as future
strengthening rather than as the current paper plan.

For the executable artifact story, the repo also keeps a self-instantiated
closure at exactly the same interface through
`pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization`. That is not
a weaker theorem boundary; it is a stronger artifact-completeness move so the
current build can validate the entire bridge end to end without waiting on an
external imported theorem object.

## Runtime Witness Interface

The runtime-to-Lean witness interface is now fixed in:

- `ExecutionTrace::runtime_refinement_witness` in
  `crates/uo-core/src/trace.rs`
- runtime enforcement of that witness postcondition in
  `runtime/uo-evm/src/engine.rs`
- independent public-observer reconstruction and drift check in
  `runtime/uo-evm/src/controller.rs`
- ordered controller-certificate reconstruction in
  `crates/uo-core/src/trace.rs`
- `uo-evm --format refinement-witness` in `runtime/uo-evm/src/main.rs`
- `uo-evm --format shell-boundary`,
  `shell-boundary-lowering`, and
  `confidential-core-kernel-interface-slot`,
  `confidential-core-shell-boundary-lowering`,
  `paper-main-family`, and
  `paper-main-slot-family` in
  `runtime/uo-evm/src/main.rs`
- `RuntimeRefinementWitness` and its projection lemmas in
  `proof/lean/UOToolchain/RuntimeRefinement.lean`
- `RuntimeRefinementJson.lean` for JSON import, Lean-side witness checking, and
  conversion into the theorem objects, including logical-trace reconstruction
  of the ordered ORAM access schedule and certificate-based observer
  reconstruction
- `checkProofGradeRuntimeWitness` in
  `proof/lean/CheckProofGradeRuntimeWitness.lean` for end-to-end
  proof-grade witness validation from the Lean side
- `checkProofGradeRuntimeKernelInterface` in
  `proof/lean/CheckProofGradeRuntimeKernelInterface.lean` for the paper-facing
  runtime/kernel interface theorem surface extracted from the same accepted
  runtime witness
- `checkProofGradeRuntimeKernelInterfaceBundle` in
  `proof/lean/CheckProofGradeRuntimeKernelInterfaceBundle.lean` for the
  explicit theorem-facing `RuntimeKernelInterfaceBundle` emitted by the Rust
  runtime/kernel interface bridge; the native and imported shell-boundary
  files now also prove that this explicit bundle surface projects directly to
  the native `RuntimeProofGradeKernelInterface` theorem, to valid native
  shell-boundary bundles, and to the older proof-grade kernel-boundary facts,
  so downstream paper routes can standardize on the bundle object rather than
  unpacking raw witness fields
- `checkProofGradeRuntimeKernelRefinementBoundary` in
  `proof/lean/CheckProofGradeRuntimeKernelRefinementBoundary.lean` for the
  exact imported `RuntimeKernelRefinementBoundary` route derived from that
  same exported `RuntimeKernelInterfaceBundle`; the imported shell-boundary
  bridge now also proves
  `importedRuntimeKernelInterfaceBundle_valid_projects_to_runtimeKernelRefinementBoundary`,
  so accepted bundle artifacts project to the exact theorem-facing runtime
  refinement boundary rather than only to bundle-level acceptance facts
- `checkProofGradeRuntimeKernelFinishBoundary` in
  `proof/lean/CheckProofGradeRuntimeKernelFinishBoundary.lean` for the smaller
  raw `RuntimeKernelFinishBundle`; that imported finish route now also proves
  direct recovery of a valid native `RuntimeKernelInterfaceBundle` and a valid
  native `RuntimeShellBoundaryBundle`, so the finish-boundary path reaches the
  same public shell/kernel interface surfaces without first rebuilding the
  larger runtime witness
- `checkProofGradeRuntimePaperMainFamilyBundle` in
  `proof/lean/CheckProofGradeRuntimePaperMainFamilyBundle.lean` for the
  explicit theorem-facing `SeededRuntimePaperMainFamilyBundle` emitted by the
  seeded paper-route bridge; the imported bridge also proves
  `importedSeededRuntimePaperMainFamilyBundle_valid_projects_to_family_assurance`
  so accepted family artifacts project to a reusable theorem-side family
  assurance object, and the imported kernel-interface family route now also
  projects accepted families directly to the native
  `RuntimeProofGradeKernelInterface` theorem and to per-witness
  `ImportedRuntimeProofGradeKernelBoundaryFacts`
- `checkProofGradeRuntimePaperMainSlotFamilyBundle` in
  `proof/lean/CheckProofGradeRuntimePaperMainSlotFamilyBundle.lean` for the
  stronger shared-slot theorem-facing
  `SeededRuntimePaperMainSlotFamilyBundle`, which now carries an explicit
  `opcode_trace` and rechecks it against the admitted slot-program statement
  trace names; the imported bridge also now proves
  `importedSeededRuntimePaperMainSlotFamilyBundle_valid_projects_to_family_slot_assurance`,
  so an accepted slot-family artifact can be reused as an explicit theorem-side
  family-slot assurance object rather than only as a checker success bit
- `checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot` in
  `proof/lean/CheckProofGradeRuntimeConfidentialCoreKernelInterfaceSlot.lean`
  for the exported
  `RuntimeConfidentialCoreKernelInterfaceSlotBundle`, which pairs one accepted
  runtime witness with one explicit runtime kernel-interface bundle and one
  exact confidential slot program
- `results/kernel_refinement_validation.json` for benchmark-backed validation
  that the lower-level runtime phase witness is accepted directly against the
  exported kernel witness on representative supported paths
- `results/kernel_interface_validation.json` for benchmark-backed validation
  that the explicit exported `RuntimeKernelInterfaceBundle` artifacts are
  accepted by the dedicated paper-facing runtime/kernel interface bundle
  checker on representative supported paths
- `results/kernel_interface_singleton_boundary_validation.json` for
  benchmark-backed validation that the direct
  `checkProofGradeRuntimeKernelInterface` witness checker now also projects one
  accepted runtime witness to the exact singleton
  `PaperMainRuntimeKernelBoundaryAt` paper boundary, and the paper theorem
  route also proves that both `PaperMainRuntimeKernelBoundary` and the stronger
  `PaperMainRuntimeKernelSlotBoundary` mechanically recover the native
  runtime/kernel interface theorem, the explicit native
  `RuntimeKernelConfinementBoundary`, valid native shell-boundary bundles, and
  the older `RuntimeProofGradeKernelBoundaryFacts` surface from those accepted
  bundle assumptions
- `results/kernel_interface_confinement_boundary_validation.json` for
  benchmark-backed validation that the direct
  `checkProofGradeRuntimeKernelInterfaceConfinementBoundary` witness checker
  also projects one accepted runtime witness directly to the exact native
  `RuntimeKernelConfinementBoundary`, so the witness-fed confinement route is
  benchmark-backed separately from both the exported-bundle confinement
  checker and the paper-boundary singleton checker, with tamper rejection for
  witness-level controller-certificate drift at that direct confinement route
- `results/kernel_refinement_boundary_validation.json` for benchmark-backed
  validation that those same exported `RuntimeKernelInterfaceBundle`
  artifacts are also accepted through the exact
  `RuntimeKernelRefinementBoundary` checker, with tamper rejection for public
  object-schedule drift at that exact boundary route
- `results/kernel_confinement_boundary_validation.json` for benchmark-backed
  validation that those same exported `RuntimeKernelInterfaceBundle`
  artifacts are also accepted through the exact
  `RuntimeKernelConfinementBoundary` checker, so the shell-confinement route
  is benchmark-backed separately from bundle acceptance and separately from
  the refinement-boundary checker
- `results/confidential_core_kernel_interface_slot_validation.json` for
  benchmark-backed validation that the stronger confidential-core/kernel-
  interface/slot composite artifacts are accepted on representative supported
  paths
- `results/kernel_slot_boundary_validation.json` for benchmark-backed
  validation that those same exported
  `RuntimeConfidentialCoreKernelInterfaceSlotBundle` artifacts are also
  accepted through the exact singleton
  `PaperMainRuntimeKernelSlotBoundaryAt` checker, with tamper rejection for
  public object-schedule drift at that exact slot-boundary route
- `results/confidential_proof_family_validation.json` for benchmark-backed
  validation that the full shared `RuntimeConfidentialProofBundleFamily`
  artifact is accepted as one theorem-facing object and preserves one shared
  runtime witness, kernel-interface bundle, exact kernel witness, exact slot
  schedule, and singleton paper-main family / slot-family boundary
- `results/confidential_proof_family_slot_boundary_validation.json` for
  benchmark-backed validation that that same shared
  `RuntimeConfidentialProofBundleFamily` artifact is also accepted through
  the exact singleton `PaperMainRuntimeKernelSlotBoundaryAt` checker, with
  tamper rejection for family-level slot-program drift at that exact boundary,
  and with the imported slot-family route also compiled through to the
  explicit `RuntimeKernelConfinementBoundary`
- `results/confidential_proof_family_refinement_boundary_validation.json` for
  benchmark-backed validation that that same shared
  `RuntimeConfidentialProofBundleFamily` artifact is also accepted through
  the exact `RuntimeKernelRefinementBoundary` checker, with tamper rejection
  for family-level public object-schedule drift at that exact boundary
- `results/confidential_core_kernel_finish_slot_validation.json` and
  `results/confidential_core_kernel_interface_slot_finish_boundary_validation.json`
  for benchmark-backed validation that the smaller pre-witness finish bundle
  and the stronger runtime-witness/kernel-interface/slot bundle both project
  not only to the exact finish-slot and refinement-boundary objects but also
  to the explicit `RuntimeKernelConfinementBoundary`
- `results/seeded_witness_validation.json`,
  `results/paper_main_family_boundary_validation.json`, and
  `results/paper_main_slot_boundary_validation.json` for benchmark-backed
  validation that the explicit exported
  `SeededRuntimePaperMainFamilyBundle` and
  `SeededRuntimePaperMainSlotFamilyBundle` artifacts are accepted by the
  dedicated paper-facing seeded runtime bundle and exact boundary checkers on
  representative supported paths, alongside the lower seeded-family validators
- `results/witness_validation.json` for benchmark-backed validation that the
  emitted runtime witnesses are accepted by the Lean checker on representative
  supported paths, including a multi-object ORAM `transferFrom` witness

## Reproducibility Manifest

Every probe run writes `results/reproducibility_manifest.json`,
recording the SHA-256 of every other file in the output directory.
The manifest itself excludes `reproducibility_manifest.json` so the
manifest's own SHA-256 is well-defined relative to the prior outputs.
The manifest is generated by walking the output directory in
deterministic file-path order (`collect_bundle_files()` sorts both
`fs::read_dir` traversal order and the final entries list against
the path strip-prefixed under the output root) and emitting a
`ReproducibilityManifest` record with one
`ReproducibilityManifestEntry` per output file.

`format_version` is currently `1` and the `file_count` is the number
of non-manifest files in the output directory. The schema is:

```json
{
  "format_version": 1,
  "file_count": 77,
  "files": [
    { "path": "...", "bytes": 158, "sha256": "..." },
    ...
  ]
}
```

The manifest is what the reproducibility audit downstream consumers
should diff: a stable run on the same inputs produces a manifest with
identical `bytes` and `sha256` per entry. The probe binary itself is
treated as out-of-scope for the manifest (its hash is not pinned by
the manifest); use Cargo's `Cargo.lock` and the workspace root to
pin the probe build inputs.

## Tamper Coverage Audit

The probe's `tamper-validation` scenario runs **379 distinct tamper
scenarios** (each with a unique mutation description), all of which
must produce `"accepted": false, "rejected": true` on the Lean
checker side. The acceptance gate in `scripts/run_validation.sh`
asserts `rejected_count == scenario_count == 379`; the
reviewer-facing summary surfaces the same number.

The 379-scenario suite is split across the following theorem-facing
artifacts (numbers approximate, see `results/tamper_validation.json`
for the exact distribution):

- **JSON-bundle tampers** for every paper-grade
  `loadAndCheckImported<…>` checker family — kernel DSL, kernel slot
  DSL, kernel lowering, kernel witness, kernel refinement witness,
  kernel-interface bundle, kernel finish boundary, runtime witness,
  runtime refinement witness, shell boundary, shell boundary slot,
  shell boundary lowering, confidential core (and its slot / lowering
  / shell-boundary-slot / shell-boundary-lowering / kernel-finish-slot
  / kernel-interface-slot / kernel-interface-slot-finish-boundary
  variants), confidential proof-bundle family (assurance / boundary /
  finish-slot-boundary / kernel-interface / refinement-boundary /
  slot-assurance / slot-boundary), trusted-kernel slot, runtime
  machine-finish witness, runtime machine-finish boundary,
  runtime-implementation interface and its full chain (public-bridge,
  slot-adapter, residual-helper-shell, small-confidential-kernel,
  shared-confidential-kernel, confidential-statement-trace bridge,
  kernel-meeting / kernel-meeting-confinement / kernel-machine-confinement,
  shared-kernel and shared-kernel-machine refinements, full
  implementation-confinement), public-bridge observer-refinement,
  residual-helper-shell machine-refinement, slot-adapter machine-refinement,
  small-confidential-kernel machine-refinement,
  confidential-statement-trace bridge refinement.
- **Source-mutation tampers** that append handwritten markers
  (e.g., direct `run_confidential_entrypoint(...)`,
  `Value::confidential_select`, secret-indexed `entries[slot_index]`,
  growable `Vec<OramWrite>`, `position(...)` early-exit scans, raw
  `entries[slot_index]` writes) so the source-backed
  `RuntimeImplementationInterface` rejects representative
  confidential-bypass drift; each source-side scenario is replayed
  against every downstream theorem route (standalone small-kernel,
  standalone shared-kernel, machine-backed routes, kernel-interface
  combined boundary, full implementation-confinement, dedicated
  public-observer route) so a single source mutation triggers
  rejection at every layer the paper claim depends on.
- **Translation-side tampers** for `checkProofGradeTranslationArtifacts`
  (mutated manifest entrypoints, mutated kernel-step `object_id`,
  mutated raw-target objects in the confidential admission path).
- **Path-ORAM hidden-state tampers** (mutated position-map leaves,
  mutated absent-leaf shape).
- **Controller-certificate tampers** (mutated observed ORAM access,
  mutated recursion depth) for the controller observer family.

The W6 freeze surface — observer / boundary-call / persistent-I/O /
controller-refinement / storage-refinement / deployment-assumption
bundle — does not need its own benchmark-backed tamper-validation
scenario because the targets are static-drift checks (literal-string
matches against frozen Lean / Rust source). Source drift in any of
these surfaces flips the corresponding `*_pinned` flag in
`results/static_checks.json` and the matching field in
`results/kernel_model_alignment_validation.json`, both of which the
acceptance gate requires to be `true`. The closure-audit theorem
`sgxHostileHostClosureAudit_driftCheckNames` in `ProofGrade.lean`
pins the six W6 drift-check names at the Lean type level so that the
static-drift surface itself is theorem-stable.

The 379-scenario suite therefore provides negative-test coverage for
every theorem-facing JSON artifact emitted by the runtime, every
source-backed boundary, and every translation-side artifact, while
the static-drift surface provides the equivalent of negative-test
coverage for every freeze layer.

## Non-Claim

This profile does not claim:

- raw equality of SGX page identities
- raw equality of full micro-event sequences
- downstream machine-code equivalence below the checked runtime boundary
- a complete semantics-of-Rust refinement for every residual implementation
  detail beneath the source-backed runtime interface

Those would require a different observer choice and possibly a wider leakage
model.
