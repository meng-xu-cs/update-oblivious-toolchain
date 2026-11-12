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

Runtime proof-object extraction is bound to an append-only primitive event
transcript. `ExecutionTrace::primitive_event_transcript` records typed hashes
for opcode, logical, physical, theorem, controller, ORAM, and kernel proof
payloads, and `TraceHashBundle` exposes both the transcript hash and the
runtime proof-object hash. A fully verified extractor would still reduce the
TCB, but omitted or mutated proof payloads are no longer outside the checked
hash surface.

A call returns its `PublicReceipt`. The proof objects are built from the
call's whole `ExecutionTrace`, which also holds its `PrivateEvidence` and
which a call returns only in a test or diagnostics build (see
[`trusted-kernel.md`](./trusted-kernel.md)).

Production acceptance uses `ProductionContractInstance::call_authorized`.
That path refuses calls without a current admitted-package identity, matching
toolchain manifest digest, runtime confidential proof-bundle hash, runtime
binary hash, proof-root hash, accepted SGX quote hash, attested
return-channel session transcript, and freshness/rollback counters matching
the runtime state at call entry.
