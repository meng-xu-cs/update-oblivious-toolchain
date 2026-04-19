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
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | yes | implementation honesty is not yet derived by a full refinement proof |
| Rust shell/object code outside the tiny kernel | partially | the confidential surface is narrower now, but this code still matters until confinement and refinement are proved end to end |
| `uo-check` | no | removed from the proof-grade acceptance path |
| `mplus-probe` | no | validation/reporting only |

The final paper target is stricter than the current runtime-side TCB:

- keep shrinking the non-kernel Rust surface; currently `engine.rs` no longer
  stages confidential entrypoint plans and raw/confidential shadow wrappers are
  runtime-only, and the theorem-facing committed ORAM snapshot is now captured
  through the `state.rs` / `theorem.rs` call-trace handoff rather than by the
  engine, while the same theorem-side context now also owns the public call
  summary and recorder setup, but this still needs a theorem-level
  confinement argument
- shrink the confidential Rust surface to a tiny kernel
- prove the real kernel implementation refines the Lean kernel model
- keep the proved non-kernel shell public-only interface aligned with the
  admitted observer while connecting it to the remaining end-to-end
  confinement argument
- keep `uo-check`, `mplus-probe`, and any Rust-side translation convenience
  wrappers outside the TCB

## What Lean Proves

The Lean development now contains:

- `proof/lean/UOToolchain/RuntimeTrustedKernel.lean`
- `proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean`
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
executable-only predicate.

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
- `RuntimeTrustedKernelBundle::to_witness`
- `uo-evm --format trusted-kernel`

The runtime engine now materializes the trusted-kernel bundle directly during
execution, stores it on the emitted `ExecutionTrace`, and only then uses the
older trace-field reconstruction path as an internal audit check before
returning a call result. The public accessor on a runtime-emitted trace is
therefore no longer a reconstruction routine. For the proof-grade
trusted-kernel path, `ExecutionTrace::runtime_trusted_kernel_slot_bundle` then
packages that stored bundle together with the admitted slot program from the
artifact manifest, and `uo-evm --format trusted-kernel` emits that stronger
slot-wrapped artifact.

For confidential entrypoints, the checked manifest now carries the canonical
named confidential program, the canonical slot confidential program, and the
exact expected public kernel-step schedule derived from that slot program. The
runtime loads that stored slot program before execution starts, rejects any
manifest drift between program and schedule, and then rejects any missing,
extra, or mismatched step online. The runtime is no longer only "emit then
compare later" at that kernel boundary.

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
drift. The standalone confidential kernel witness is likewise exported only
through the dedicated `runtime_kernel_witness` field rather than being
recovered from the stored bundle. The reconstruction path now exists only for
traces that genuinely still carry the matching theorem/controller/hidden trace
state needed to rebuild the bundle exactly.

## Validation Path

The repository now validates real emitted trusted-kernel bridge artifacts with
Lean via:

- `cargo run -q -p mplus-probe -- --only kernel-validation --out-dir results`
- `results/kernel_validation.json`
- `cargo run -q -p mplus-probe -- --only kernel-refinement-validation --out-dir results`
- `results/kernel_refinement_validation.json`
- `cargo run -q -p mplus-probe -- --only trusted-kernel-validation --out-dir results`
- `results/trusted_kernel_validation.json`
- `cargo run -q -p mplus-probe -- --only tamper-validation --out-dir results`
- `results/tamper_validation.json`
- `results/bridge_validation.json`

The proof-grade report path uses `checkProofGradeRuntimeTrustedKernel` over
the slot-wrapped trusted-kernel artifact, not just the bare certificate
bundle. The new tamper report complements the positive validation reports by
mutating representative direct controller/hidden certificates, the
proof-grade translation, kernel, refinement, shell-boundary,
confidential-core, runtime-witness, and trusted-kernel-slot artifacts, and
the seeded/canonical witness-family, theorem-input, and pair-certificate
artifacts, then checking that the corresponding Lean executables reject those
drifted artifacts.

## Precise Claim

What is now formally verified is the theorem-side meaning of the small runtime
kernel bundle and the acceptance criterion used by the Lean checker.

What is still not claimed is that every line of the Rust runtime is proved
correct in Lean. The trusted Rust surface is instead narrowed to the small
bundle extractor plus serialization path, and the repo validates the emitted
artifacts against the mechanized Lean predicate end to end. The strongest
current kernel-side statement is therefore: the runtime enforces the admitted
public kernel schedule online and emits a proof-grade kernel witness that is
checked directly, emits a lower-level runtime phase witness whose projection to
that kernel schedule is checked directly, and also packages the same kernel
boundary through the trusted-kernel and refinement-bundle paths, with Lean now
checking exact schedule equality plus successful modeled small-kernel replay,
not that the whole Rust runtime has already been reduced to that model by a
machine-checked refinement proof.
