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

A call loads the objects it runs on before its first statement: a
confidential call the objects its kernel program schedules, a public call
the objects its body accesses. Loading a sealed exact object (a cell, an
array or a full-scan map) opens every slot of it and is the call's one read
of the object; the call recorder takes the read there
(`RuntimeObject::clone_for_tx`), and an access records its logical event
only. Commit opens nothing: it reseals the objects the program may write,
with the copy the object kept at its first write if the call aborted
(`keep_loaded_*` and `reconcile_*_commit_*` in the generated object
helpers). A Path ORAM map reads its counter and metadata pages when it is
loaded, outside the trace, and its paths as it is accessed.

Committed state changes only through a call, with one exception that a
production build does not have: `ContractInstance::bulk_load_map_for_diagnostics`
stores entries in one map with no trace, receipt or freshness step, so that
the capacity sweep can measure filled maps (see
[`../path-oram.md`](../path-oram.md)). It loads and commits the map as a call
does and makes the writes a committed call would; a test compares it with
those calls on every map backend, and a test of the engine's source keeps it
behind `cfg(any(test, feature = "diagnostics"))`.

Production acceptance uses `ProductionContractInstance::call_authorized`.
That path refuses calls without a current admitted-package identity, matching
toolchain manifest digest, runtime binary hash, proof-root hash, accepted SGX
quote hash, attested return-channel session transcript, freshness/rollback
counters matching the runtime state at call entry, and the hash of the
receipt the runtime issued last. It answers an accepted call with the next
`ProductionReceipt` of the deployment's chain; see the Deployment Theorem in
[`../claim-boundary.md`](../claim-boundary.md).
