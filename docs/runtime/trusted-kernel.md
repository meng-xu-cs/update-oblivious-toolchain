# Trusted Kernel Boundary

This document fixes the current meaning of the repository's small trusted
runtime boundary.

## Boundary Object

The base runtime boundary is the `RuntimeTrustedKernelBundle` exported from
`ExecutionTrace` in `crates/uo-core/src/trace.rs`.

The proof-grade checker validates the stronger
`RuntimeTrustedKernelSlotBundle` from `crates/uo-core/src/trusted_kernel.rs`.
That bundle packages:

- the public SGX/controller observer certificate
- the hidden Path ORAM certificate
- the optional runtime kernel witness
- the optional runtime replay seed
- the admitted `ConfidentialKernelSlotProgram` for the same entrypoint

The full runtime refinement witness is reconstructed from this bundle and
checked against the surrounding trace. It is not treated as a primitive trusted
object.

## Runtime-Side TCB

| Component | Status |
| --- | --- |
| Lean kernel and theorem/checker development | trusted |
| Explicit backend/crypto/deployment assumptions | trusted assumptions |
| Bundle acceptance predicates and imported JSON checkers | trusted theorem boundary |
| Rust witness/certificate/bundle extraction and serialization | trusted producer, reduced by replay/reconstruction checks |
| Source-backed implementation boundaries | static-drift evidence, not semantic Rust verification |
| Rust shell/object code outside the tiny kernel | outside the confidential-work TCB when pinned to public-only or generated-helper routes |
| `uo-check` and `mplus-probe` | outside the proof-grade TCB |

## Main Validators

The runtime bridge is checked by Lean executables including:

- `checkProofGradeRuntimeKernelWitness`
- `checkProofGradeRuntimeKernelRefinementWitness`
- `checkProofGradeRuntimeTrustedKernel`
- `checkProofGradeRuntimeWitness`
- `checkProofGradeRuntimeShellBoundary`
- `checkProofGradeRuntimeShellBoundaryLowering`
- `checkProofGradeRuntimeConfidentialCore`
- `checkProofGradeRuntimeConfidentialCoreSlot`
- `checkProofGradeRuntimeConfidentialCoreLowering`
- `checkProofGradeRuntimeConfidentialProofBundleFamily`
- `checkRuntimeControllerCertificate`
- `checkRuntimePathOramHiddenCertificate`

Probe reports under `results/` expose the corresponding acceptance bits. The
negative companion is `tamper_validation.json`, which mutates representative
translation/runtime/proof artifacts and requires Lean rejection.

## Current Guarantee

The checked runtime route states that:

- the emitted public controller certificate is valid
- the hidden Path ORAM certificate is valid
- the trusted-kernel slot bundle matches the admitted confidential slot program
- the kernel witness respects opcode vocabulary, public schedule, resource
  budgets, and wipe obligations
- shell-boundary artifacts replay the public shell contract and project to the
  same kernel witness
- source-backed implementation cuts keep handwritten runtime confidential work
  in generated/helper routes or public-only shell code

It does not prove every residual Rust implementation detail or downstream
machine code.
