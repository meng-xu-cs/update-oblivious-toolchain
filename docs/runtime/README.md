# Runtime Documentation

This directory owns the runtime-side claim boundary. Start here for questions
about which Rust structures can carry secrets, which runtime proof objects are
trusted, and how the SGX/TEE observer is pinned.

| Need | Document |
| --- | --- |
| Trusted kernel bundle, validators, and runtime-side TCB | [`trusted-kernel.md`](./trusted-kernel.md) |
| SGX/TEE observer, boundary-call/storage pins, deployment assumptions | [`tee-observer.md`](./tee-observer.md) |
| Secret-bearing Rust structures and ownership invariants | [`secret-state.md`](./secret-state.md) |

## Runtime Design Principles

- Keep confidential execution inside the shared small kernel and generated
  helper stack.
- Keep handwritten shell/engine coordination public-only.
- Use fixed public capacities for kernel steps, runtime phases, resource
  events, object universes, ORAM read/write evidence, and theorem-facing
  witness buffers.
- Treat source-backed runtime boundaries as source-frozen/static-drift
  evidence, not as a full semantics-of-Rust refinement.
- Keep emitted proof objects checkable by Lean and covered by probe drift and
  tamper reports.

The current remaining trusted runtime surface is the implementation-side
extraction path for witnesses, certificates, bundles, and serialization below
the checked boundary. Replacing that with a verified extractor or a primitive
event-transcript hash is future strengthening.
