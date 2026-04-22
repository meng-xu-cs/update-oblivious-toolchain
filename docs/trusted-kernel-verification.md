# Trusted-Kernel Verification

This note fixes the current meaning of the repository's "small Rust trusted
kernel" claim.

## Boundary

The trusted runtime boundary is now the explicit
`RuntimeTrustedKernelBundle` exported from `ExecutionTrace` in
`crates/uo-core/src/trace.rs`.

The proof-grade trusted-kernel checker is now slightly stronger than that base
runtime object: it validates a `RuntimeTrustedKernelSlotBundle` from
`crates/uo-core/src/trusted_kernel.rs`, which packages the emitted
`RuntimeTrustedKernelBundle` together with the admitted
`ConfidentialKernelSlotProgram` for the same entrypoint.

That bundle contains exactly:

- the public SGX/controller observer certificate
- the optional runtime kernel witness
- the hidden Path-ORAM certificate
- the optional runtime replay seed

The full theorem-facing runtime witness is reconstructed from that bundle; it
is no longer the primitive trusted object.

## Current TCB Statement

The current runtime-side TCB should be read explicitly rather than inferred.

| Component | In current runtime-side TCB? | Reason |
| --- | --- | --- |
| Lean kernel plus Lean theorem/checker development | yes | proof checker and theorem body |
| Explicit backend / cryptographic assumptions | yes | they are the named remaining assumptions |
| `RuntimeTrustedKernelBundle` / `RuntimeTrustedKernelSlotBundle` acceptance predicates and imported JSON checker | yes | theorem-facing validation boundary |
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | yes | this remains part of the implementation TCB; the repo now packages and checks the theorem-facing runtime boundary through explicit `RuntimeKernelRefinementBoundary`, `RuntimeKernelInterfaceSlotBoundary`, and `RuntimeKernelConfinementBoundary` objects, plus direct paper-main family / slot boundary reports, but implementation honesty is still not derived by a machine-checked refinement proof |
| Rust shell/object code outside the tiny kernel | partially | the confidential surface is narrower and the public shell is now pinned to the explicit `RuntimeKernelConfinementBoundary`; remaining work is source-to-kernel and deployment lifting rather than reopening the runtime boundary interface |
| `uo-check` | no | removed from the proof-grade acceptance path |
| `mplus-probe` | no | validation/reporting only |

The final paper target is now downstream of that runtime boundary:

- keep shrinking the non-kernel Rust surface where that still reduces the
  implementation TCB
- keep the proved non-kernel shell public-only interface aligned with the
  admitted observer while lifting the result into the source theorem
- prove source-to-kernel compiler correctness
- discharge or minimize the remaining backend / cryptographic assumptions
- close the final hostile-host deployment theorem
- keep `uo-check`, `mplus-probe`, and any Rust-side translation convenience
  wrappers outside the TCB

## What Lean Proves

The Lean development now contains:

- `proof/lean/UOToolchain/RuntimeTrustedKernel.lean`
- `proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean`
- `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`
- `proof/lean/CheckProofGradeRuntimeKernelWitness.lean`
- `proof/lean/CheckProofGradeRuntimeTrustedKernel.lean`

The main mechanized statements are:

- `RuntimeTrustedKernelBundle.Valid`
- `RuntimeTrustedKernelSlotBundle.Valid`

The base statement says that the trusted-kernel bundle is sufficient to
reconstruct a valid `RuntimeRefinementWitness`. Concretely, the theorem-facing
obligations are:

- the hidden trace gas matches the public outcome gas
- the public logical trace reconstructs the ordered observed ORAM accesses
  recorded in the controller certificate
- the public controller observer certificate is valid
- the hidden Path-ORAM certificate is valid

Lean also proves `checkValid = true ↔ Valid` for the imported JSON form of the
bundle, so the command-line checker is theorem-tight rather than an
executable-only predicate. The shell-boundary development now also proves, on
both the native and imported sides, that one valid explicit
`RuntimeKernelInterfaceBundle` is enough to recover the older proof-grade
runtime/kernel boundary-facts package directly, so the exported bundle is now
the canonical theorem interface rather than only a serialization convenience.

At the paper theorem route, the runtime-side boundary is now named explicitly
in Lean and discharged mechanically for the emitted runtime artifact routes,
but not yet for the real Rust implementation.
The frozen paper route now carries the checked
`PaperMainRuntimeKernelBoundary` directly, phrased over the explicit
`RuntimeKernelInterfaceBundle` exported by the runtime/kernel interface, and
the stronger shared-DSL variant carries
`PaperMainRuntimeKernelSlotBoundary`, which pairs one fixed confidential slot
program per public ORAM configuration with a valid explicit runtime
kernel-interface bundle instead of only an existential shell-refinement fact.
Lean still keeps the stronger witness-acceptance bundles
`PaperMainRuntimeKernelAssumptions` and
`PaperMainRuntimeKernelSlotAssumptions`, but they now sit below the paper
route as projection lemmas that can mechanically discharge those checked
boundaries when proof-grade seeded runtime bundles are already available.
The paper-route end-to-end layer now carries that stronger route as well via
`PaperMainPathOramSlotAssumptions`,
`PaperMainPathOramSlotAssurance`, and
`PaperMainPathOramSlotEndToEndBoundary`.
The emitted seeded-family artifact path now also has dedicated family-level
Lean validators for both the runtime kernel-interface boundary and exact
public-outcome / boundary-schedule uniformity at the paper-main runtime
bundle surface, plus the stronger paper-main slot-family checker that pairs
that shared seeded family with one exact confidential slot program.
The same exported runtime kernel-interface bundle now also has a dedicated
exact-boundary checker,
`checkProofGradeRuntimeKernelRefinementBoundary`, and the probe backs that
route with `kernel_refinement_boundary_validation.json`, so the imported
artifact path is exercised both at the explicit bundle surface and at the
exact `RuntimeKernelRefinementBoundary` it projects to.
The smaller raw `RuntimeKernelFinishBundle` and the smaller
`RuntimeConfidentialCoreKernelFinishSlotBundle` now also project back to valid
native `RuntimeKernelInterfaceBundle` and `RuntimeShellBoundaryBundle`
objects, so the finish-boundary artifact path reaches the same shell/kernel
interface surfaces even before the larger runtime witness is reintroduced.
The direct proof-grade runtime kernel-interface witness route now also
projects from one accepted runtime witness to the exact singleton
`PaperMainRuntimeKernelBoundaryAt` paper boundary, so the frozen paper
runtime/kernel interface is not only a family-level wrapper around later
seeded artifacts.
The stronger exported
`RuntimeConfidentialCoreKernelInterfaceSlotBundle` now likewise has a
dedicated exact-boundary checker,
`checkProofGradeRuntimeKernelSlotBoundary`, and the probe backs that route
with `kernel_slot_boundary_validation.json`, so the imported artifact path is
exercised both at the larger confidential-core/kernel-interface composite
surface and at the exact singleton
`PaperMainRuntimeKernelSlotBoundaryAt` it projects to.
The fully shared `RuntimeConfidentialProofBundleFamily` now also has a
dedicated exact-boundary checker,
`checkProofGradeRuntimeConfidentialProofBundleFamilySlotBoundary`, and the
probe backs that route with
`confidential_proof_family_slot_boundary_validation.json`, so the imported
family artifact path is exercised both as one shared proof-family object and
at the exact singleton `PaperMainRuntimeKernelSlotBoundaryAt` theorem surface
it projects to.
That same shared family now also has a dedicated exact-boundary refinement
checker,
`checkProofGradeRuntimeConfidentialProofBundleFamilyRefinementBoundary`, and
the probe backs that route with
`confidential_proof_family_refinement_boundary_validation.json`, so the
imported family artifact path is also exercised directly at the exact
`RuntimeKernelRefinementBoundary` theorem surface it projects to.
The runtime-side artifact interface now exposes the canonical single-seed
paper-main family and slot-family objects directly from `ExecutionTrace` and
`uo-evm`, so that exported paper-route objects no longer depend on probe-local
reassembly code.
The Rust/probe path now exercises both the positive acceptance route and
explicit tamper-rejection cases for that slot-family checker, covering both
shared slot-program entrypoint drift and slot-program body drift while the
seeded family stays fixed. The probe now also exposes the paper-main family and
slot boundary routes as direct first-class reports, so the runtime refinement /
confinement boundary is no longer hidden inside the seeded-family report.

The proof-grade trusted-kernel statement then adds the admitted slot DSL
object: once a `RuntimeTrustedKernelSlotBundle` is accepted, the embedded
trusted-kernel bundle is proof-grade valid and its exact kernel-step schedule
must match the `expectedRuntimeKernelSteps` derived from that frozen slot
program.

The core Lean development now also exposes theorem-side proof-grade predicates
for the kernel witness, refinement witness, and trusted-kernel bundle, so the
"kernel witness is present and exact" condition is no longer only a JSON-layer
importer notion. For the kernel witness specifically, the proof-grade path now
requires:

- the exact expected public kernel-step trace, where each step is just
  `{ opcode, object_id? }`

Lean derives the public kernel schedule object, including its projected opcode
list, from that step trace. The step trace is stronger than the old flat opcode
list because it fixes the kernel-visible persistent object schedule without
exposing secret keys, indices, or values.

Lean now also exposes proof-grade schedule-exactness lemmas for the kernel
witness, runtime refinement witness, and trusted-kernel bundle: once a
proof-grade witness is accepted, there is one exact expected public kernel
schedule and the emitted kernel steps are provably equal to it.
The shell-boundary layer now packages those exact schedule facts together with
the exact public object universe, resource-state replay, runtime-phase
projection, and shell-refinement claim into one theorem-facing
runtime/kernel-boundary interface on both the runtime and imported JSON sides,
so downstream confidential-core theorems no longer have to reassemble those
facts ad hoc.

That schedule is now also packaged explicitly on the Lean side as a
`RuntimeKernelSchedule` / `ImportedRuntimeKernelSchedule` object derived from
the witness, so the proof interface can talk directly about "the admitted
public kernel schedule" rather than about duplicated opcode-list sidecars.
Lean now also gives that schedule an explicit small-kernel execution semantics:
the accepted public schedule must replay from `ready` to `finished` under the
modeled `Begin -> object ops* -> Commit -> Wipe` machine, not merely satisfy a
flat shape predicate. The replayed final state also exposes the exact public
object-id schedule induced by that admitted step trace.
The runtime refinement witness now also has an explicit theorem-facing
relation to that finished Lean kernel state, so accepted proof-grade runtime
phase witnesses no longer stop at "shape-consistent trace" and instead certify
one exact admitted small-kernel execution object with exact boundary and
resource projections.
On the Rust side, the runtime kernel now also emits the complete
`cold_store_object` / `post_committed_cold_object` tail itself rather than
asking `state.rs` to append it after the fact, and the old
tail-appending witness helpers are no longer public production APIs in
`uo-core`. The live kernel journal and the proof-side witness validator now
also share the same runtime-phase transition function rather than maintaining
separate phase machines. That does not prove full implementation honesty yet,
but it removes one more post hoc witness-rewriting surface and one more source
of duplicated witness-shape logic from the trusted path.
The kernel witness now also carries an explicit public resource-event trace
covering stack checks plus scratch reservations and wipes. Lean replays that
trace against the public stack/scratch budgets and fixes one exact replayed
resource state, and the proof development now exposes direct exactness lemmas
for that replayed resource state at the kernel-witness, runtime-refinement,
and trusted-kernel-bundle layers. The generated kernel / refinement /
trusted-kernel validation reports now also surface the emitted resource-event
trace together with the emitted and expected public object universe in the
kernel witness summary, plus the kernel-step public object schedule.

## What The Runtime Implements

The Rust side now exposes:

- `ExecutionTrace::runtime_trusted_kernel_bundle`
- `ExecutionTrace::runtime_trusted_kernel_slot_bundle`
- `ExecutionTrace::runtime_kernel_interface_bundle`
- `RuntimeTrustedKernelBundle::to_witness`
- `uo-evm --format kernel-interface`
- `uo-evm --format trusted-kernel`

The runtime engine now asks `ExecutionTrace` to materialize the
trusted-kernel bundle from its own reconstructed controller/hidden/kernel
state during execution, stores that result on the emitted `ExecutionTrace`,
and only then uses the older trace-field reconstruction path as an internal
audit check before returning a call result. `uo-evm` no longer hand-assembles
the controller observer certificate, hidden certificate, or trusted-kernel
bundle directly. The public accessor on a runtime-emitted trace is therefore
no longer a reconstruction routine. For the proof-grade
trusted-kernel path, `ExecutionTrace::runtime_trusted_kernel_slot_bundle` then
packages that stored bundle together with the admitted slot program from the
artifact manifest, and `uo-evm --format trusted-kernel` emits that stronger
slot-wrapped artifact. That slot bridge now rejects manifest slot-program
entrypoint drift by construction, and the production runtime finalizer also
re-derives that slot bundle online together with the direct kernel DSL / slot /
lowering bundles and the confidential-core direct / slot /
kernel-interface-slot / lowering / shell-boundary slot /
shell-boundary lowering family before returning a confidential trace. At the
lower kernel boundary, the final emitted `RuntimeKernelWitness` plus
`RuntimeKernelRefinementWitness` pair now also comes from one shared
`uo-core` `RuntimeKernelFinishSnapshot`, so `kernel.rs` no longer separately
assembles the theorem-facing witness pair after execution. The smaller
artifact-checked confidential-core kernel-finish slot bundle now likewise
re-exposes only a checked shell-boundary bundle rather than a raw public
witness-pair helper.

For confidential entrypoints, the checked manifest now carries the canonical
named confidential program, the canonical slot confidential program, and the
exact expected public kernel-step schedule derived from that slot program. The
runtime loads that stored slot program before execution starts, rejects any
manifest drift between program and schedule, and then rejects any missing,
extra, or mismatched step online. The runtime is no longer only "emit then
compare later" at that kernel boundary.

The paper-facing runtime/kernel boundary is now also explicit on the Rust side
as `ExecutionTrace::runtime_kernel_interface_bundle`, which packages the
checked shell-boundary bundle together with the admitted expected kernel steps,
expected public object universe, and expected kernel schedule from the
artifact. The post-call proof-facing runtime payloads now keep their
public-bounded witness buffers boxed all the way through the theorem bridge,
and the public `ExecutionTrace` surface now routes the finish-boundary export
only through `exact_runtime_kernel_finish_bundle()` plus the exact
trusted-kernel / controller / refinement APIs rather than exposing raw stored
trusted-kernel, controller, or deeper ORAM witness accessors:
not only the hidden ORAM witness slices stored on `ExecutionTrace`, but also
the runtime kernel-refinement event buffer, the controller certificate's
observed ORAM-access buffer, the controller-observer certificate's boundary
schedule, the hidden Path-ORAM certificate buffers, `TheoremTrace`'s boundary
schedule, `RuntimeRefinementWitness`'s boundary/hidden buffers, and each
emitted Path-ORAM position-map witness leaf array. The runtime theorem path
therefore no longer widens those proof-facing arrays back into growable
vectors before export, and `runtime_boundary_validation.json` now pins that
deeper representation discipline explicitly.

The emitted runtime kernel witness now contains:

- the public allocator and scratch-budget facts
- the public kernel-step trace over `{ opcode, object_id? }`
- the public resource-event trace over stack checks, scratch reservations, and
  scratch wipes
- the checked-manifest expected step trace for confidential entrypoints,
  aligned to the same stored slot program that the translation checker and the
  runtime both consume
- the emitted and expected public object universes used by the kernel witness

The repository now also exposes that smaller object directly via
`uo-evm --format kernel-witness`, and the proof-grade checker accepts that
standalone kernel witness without requiring the larger trusted-kernel or full
runtime-refinement bundles. The runtime now also exposes the lower-level
runtime phase witness directly via
`uo-evm --format kernel-refinement-witness`; that witness is not the public
theorem boundary, but it is the concrete runtime-to-kernel refinement
certificate carried inside the larger runtime refinement witness.

For proof-grade validation, Lean checks that the step trace is well-formed and
that the runtime-emitted step trace exactly matches the expected admitted step
trace.
The proof-grade kernel, refinement, and trusted-kernel checkers now also
require that this admitted public schedule actually reaches a finished
small-kernel state under the modeled execution semantics, and the resulting
modeled final state recovers the exact public object-id schedule. In parallel,
the kernel witness's public resource-event trace must replay to the exact
stack/scratch summary claimed by the witness. The lower-level runtime phase
witness is now checked not only for projection exactness and
load/commit/cold-store agreement, but also for exact pre/post
committed-cold object schedules over the full public object universe and for
equality with the canonical touched-object set reconstructed from the admitted
kernel schedule. The Lean development now also exposes direct exactness lemmas
for the kernel witness's embedded public object universe and for the runtime
phase witness's pre/post boundary schedules.

That direct bundle is also serialized with the trace. After a
serialize/deserialize round trip, `ExecutionTrace::runtime_trusted_kernel_bundle`
and `ExecutionTrace::runtime_refinement_witness` still accept the stored bundle
only if it revalidates against the surrounding execution-trace fields; a stored
bundle is no longer authoritative by itself after those fields are scrubbed or
drift. The standalone confidential kernel witness and runtime-phase witness now
follow the same rule: when a stored finish bundle is present, the exact
exported witness accessors reconstruct from that bundle first, reject any raw
stored-field drift, and only fall back to the raw trace fields when no finish
bundle exists. The reconstruction path now exists only for traces that
genuinely still carry the matching theorem/controller/hidden trace state
needed to rebuild the bundle exactly. On the production confidential path,
`RuntimeExecutionTraceParts::new(...)` no longer repopulates the raw witness
pair from the finish bundle, and serialized `ExecutionTrace` values now omit
the redundant `runtime_kernel_witness` /
`runtime_kernel_refinement_witness` keys entirely while the exact accessors
reconstruct on demand. Lean now also proves that the raw finish bundle and the
smaller confidential-core finish-slot bundle recover valid native
`RuntimeKernelInterfaceBundle` and `RuntimeShellBoundaryBundle` objects, so the
finish-boundary theorem story does not have to wait for the larger witness
wrapper just to regain the public shell/kernel interface. On the Rust side,
that smaller confidential-core finish-slot composite no longer re-exposes the
raw stored finish bundle either, and the larger shell-boundary/kernel-interface
confidential-core composites likewise no longer hand the raw
`RuntimeRefinementWitness` back out once the checked boundary object is in
hand.

## Validation Path

The repository now validates real emitted trusted-kernel bridge artifacts with
Lean via:

- `cargo run -q -p mplus-probe -- --only kernel-validation --out-dir results`
- `results/kernel_validation.json`
- `cargo run -q -p mplus-probe -- --only kernel-refinement-validation --out-dir results`
- `results/kernel_refinement_validation.json`
- `cargo run -q -p mplus-probe -- --only trusted-kernel-validation --out-dir results`
- `results/trusted_kernel_validation.json`
- `cargo run -q -p mplus-probe -- --only confidential-core-kernel-interface-slot-validation --out-dir results`
- `results/confidential_core_kernel_interface_slot_validation.json`
- `cargo run -q -p mplus-probe -- --only kernel-slot-boundary-validation --out-dir results`
- `results/kernel_slot_boundary_validation.json`
- `cargo run -q -p mplus-probe -- --only confidential-proof-family-slot-boundary-validation --out-dir results`
- `results/confidential_proof_family_slot_boundary_validation.json`
- `cargo run -q -p mplus-probe -- --only confidential-proof-family-refinement-boundary-validation --out-dir results`
- `results/confidential_proof_family_refinement_boundary_validation.json`
- `cargo run -q -p mplus-probe -- --only tamper-validation --out-dir results`
- `results/tamper_validation.json`
- `results/bridge_validation.json`

The proof-grade report path uses `checkProofGradeRuntimeTrustedKernel` over
the slot-wrapped trusted-kernel artifact, not just the bare certificate
bundle. The new tamper report complements the positive validation reports by
mutating representative direct controller/hidden certificates, the
proof-grade translation, kernel, refinement, shell-boundary,
confidential-core, the stronger confidential-core/kernel-interface/slot
composite, runtime-witness, runtime kernel-interface bundle,
trusted-kernel-slot, and seeded paper-main family and slot-family bundle
artifacts, and the seeded/canonical witness-family, theorem-input, and
pair-certificate artifacts, then checking that the corresponding Lean
executables reject those drifted artifacts. On the Rust side, the
production confidential theorem export path now re-derives that whole
proof-bearing runtime bundle family through one shared `uo-core`
`RuntimeConfidentialProofBundleFamily`, rather than having
`runtime/uo-evm/src/theorem.rs` call each proof-bearing constructor
individually. On the imported Lean side, that shared family now also projects
directly to the exact `RuntimeKernelRefinementBoundary`, to the paper-main
family runtime assurance, and to the stronger paper-main slot-family
assurance, and the probe now exercises the full shared-family artifact
through `confidential_proof_family_validation.json` plus
`checkProofGradeRuntimeConfidentialProofBundleFamily` rather than leaving that
shared bundle only as a latent checker path.

## Precise Claim

What is now formally verified is the theorem-side meaning of the small runtime
kernel bundle and the acceptance criterion used by the Lean checker.

What is still not claimed is that every line of the Rust runtime is proved
correct in Lean. The trusted Rust surface is instead narrowed to the small
bundle extractor plus serialization path, and the repo validates the emitted
artifacts against the mechanized Lean predicate end to end. The strongest
current kernel-side statement is therefore: the runtime enforces the admitted
public kernel schedule online through shared `uo-core` schedule and execution
trackers, routes runtime-phase witness construction through the same shared
`uo-core` refinement tracker used by the witness validator, and emits a
proof-grade kernel witness whose final assembly now also goes through a shared
core telemetry/execution helper fed directly by `uo-allocator`'s consumed
`finish()` handoff, with allocator-side kernel-op tracking reduced to a public
count budget rather than a redundant opcode log, emits a
lower-level runtime phase witness whose projection to that kernel schedule is
checked directly, and also
packages the same kernel boundary through the trusted-kernel and
refinement-bundle paths, with Lean now checking exact schedule equality plus
successful modeled small-kernel replay,
and with the stronger confidential-core composite route now also checking that
the accepted runtime witness, explicit runtime kernel-interface bundle, and
fixed confidential slot program agree on one exact kernel interface,
not that the whole Rust runtime has already been reduced to that model by a
machine-checked refinement proof.
