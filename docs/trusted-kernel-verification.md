# Trusted-Kernel Verification

This note fixes the current meaning of the repository's "small Rust trusted
kernel" claim.

## Boundary

The trusted runtime boundary is now the explicit
`RuntimeTrustedKernelBundle` exported from `ExecutionTrace` in
`crates/uo-core/src/trace.rs`.

That bundle contains exactly:

- the public SGX/controller observer certificate
- the hidden Path-ORAM certificate
- the optional runtime replay seed

The full theorem-facing runtime witness is reconstructed from that bundle; it
is no longer the primitive trusted object.

## What Lean Proves

The Lean development now contains:

- `proof/lean/UOToolchain/RuntimeTrustedKernel.lean`
- `proof/lean/UOToolchain/RuntimeTrustedKernelJson.lean`
- `proof/lean/CheckRuntimeTrustedKernel.lean`

The main mechanized statement is:

- `RuntimeTrustedKernelBundle.Valid`

This says that the trusted-kernel bundle is sufficient to reconstruct a valid
`RuntimeRefinementWitness`. Concretely, the theorem-facing obligations are:

- the hidden trace gas matches the public outcome gas
- the public logical trace reconstructs the ordered observed ORAM accesses
  recorded in the controller certificate
- the public controller observer certificate is valid
- the hidden Path-ORAM certificate is valid

Lean also proves `checkValid = true ↔ Valid` for the imported JSON form of the
bundle, so the command-line checker is theorem-tight rather than an
executable-only predicate.

## What The Runtime Implements

The Rust side now exposes:

- `ExecutionTrace::runtime_trusted_kernel_bundle`
- `RuntimeTrustedKernelBundle::to_witness`
- `uo-evm --format trusted-kernel`

The runtime engine now materializes the trusted-kernel bundle directly during
execution, stores it on the emitted `ExecutionTrace`, and only then uses the
older trace-field reconstruction path as an internal audit check before
returning a call result. The public accessor on a runtime-emitted trace is
therefore no longer a reconstruction routine.

That direct bundle is also serialized with the trace. After a
serialize/deserialize round trip, `ExecutionTrace::runtime_trusted_kernel_bundle`
and `ExecutionTrace::runtime_refinement_witness` still use the stored bundle
rather than falling back to theorem-trace sidecars. The reconstruction path now
exists only for backward compatibility with traces that do not yet carry the
explicit bundle.

## Validation Path

The repository now validates real emitted trusted-kernel bundles with Lean via:

- `cargo run -q -p mplus-probe -- --only trusted-kernel-validation --out-dir results`
- `results/trusted_kernel_validation.json`
- `results/bridge_validation.json`

## Precise Claim

What is now formally verified is the theorem-side meaning of the small runtime
kernel bundle and the acceptance criterion used by the Lean checker.

What is still not claimed is that every line of the Rust runtime is proved
correct in Lean. The trusted Rust surface is instead narrowed to the small
bundle extractor plus serialization path, and the repo validates the emitted
artifacts against the mechanized Lean predicate end to end.
