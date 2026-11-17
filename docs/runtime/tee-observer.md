# TEE Observer

This document owns the hostile-host SGX/TEE observer surface and the associated
deployment-assumption bundle.

## Observer

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c) )
```

- `public_outcome` and `boundary_schedule` are exact.
- `storage_trace` is exact for exact backends and ORAM-related for
  proof-grade Path ORAM routes.
- `micro_trace` is normalized and simulated from `L_sgx_micro`; raw
  micro-event equality is not claimed.

## Observer Surface

Pinned components:

| Component | Canonical surface | Drift check |
| --- | --- | --- |
| Page-region vocabulary | `metadata`, `position_map`, `path`, `stash` | `sgx_observer_surface_pinned` |
| Controller phases | enclave enter, request staging, position-map descent/ascent, metadata load, path fetch, stash scan, path rewrite, seal, exit | `sgx_observer_surface_pinned` |
| Page events | `faultIn`, `evictOut` | `sgx_observer_surface_pinned` |
| Exit events | `interruptExit`, `resume`, `terminate` | `sgx_observer_surface_pinned` |
| Shared-resource pattern | `shared_resource_tick` | `sgx_observer_surface_pinned` |

Lean anchors are in `proof/lean/UOToolchain/SgxObserverFreeze.lean`,
`SgxBoundary.lean`, `SgxRelation.lean`, `SgxController.lean`, and
`SgxControllerTrace.lean`. Rust anchors are `crates/uo-core/src/trace.rs` and
`runtime/uo-evm/src/controller.rs`.

## Boundary-Call Model

The boundary-call model pins:

- the inner ORAM access API literal: `oram_access`
- `Enter` / `Exit` direction vocabulary
- boundary-event budget: `2 * total_oram_accesses + 2`
- schedule shape: outer enter, repeated ORAM exit/enter pairs, outer exit

The matching drift check is `sgx_boundary_call_model_pinned`.

## Persistent-I/O Model

The persistent-I/O model pins:

- `PhysicalReadEvent` fields: `object`, `location`, `len`
- `PhysicalWriteEvent` fields: `object`, `location`, `len`, `class`
- `WriteClass` vocabulary: `Set`, `Clear`, `Same`, `Update`

The matching drift check is `sgx_persistent_io_model_pinned`.

## Controller Refinement

The canonical Lean controller-shape constructor refines the observer surface in
page-region names, workset-region names, boundary-event budget, and
shared-resource pattern. The runtime controller recorder is pinned to the same
surface by `sgx_controller_refinement_pinned`.

## Storage Refinement

The `viewTEEStore` projection forwards storage-relevant fields
deterministically from the trace/config:

- `physicalReads`
- `physicalWrites`
- `gasUsed`
- `entrypointId`

The matching runtime drift check is `sgx_storage_refinement_pinned`.

## Deployment-Assumption Bundle

The TEE deployment assumptions are explicit Lean `Prop` fields:

- attestation authenticity
- enclave memory isolation
- rollback resistance
- freshness guarantee
- crash recovery discipline
- patch-level trust
- platform sealing: the sealing key a production deployment seals its master
  secret under derives only in the same enclave on the same platform

Each field has provenance citing Intel SGX references. Runtime audit surfaces
also map assumptions to implementation evidence, external/deployment-only
evidence, or removal from the implemented claim. The encrypted return-channel
case is mapped to implementation evidence for ciphertext-only runtime returns
plus external deployment evidence for establishing the attested client session
key.

The matching drift checks include:

- `sgx_deployment_assumption_bundle_pinned`
- `sgx_deployment_assumption_mechanism_matrix_pinned`
- `return_channel_crypto_evidence_pinned`

## Production Acceptance

The operational production gate is separate from the observer definition.
`ProductionContractInstance::call_authorized` requires a deployment policy and
per-call evidence binding the admitted package, toolchain manifest, runtime
binary hash, proof-root hash, accepted SGX quote hash, return-channel session
id, attestation transcript hash, freshness/rollback counters, and the hash
of the receipt the runtime issued last. An accepted call is answered with
the next receipt of the deployment's chain, which carries nothing derived
from the call's private evidence, and with the receipt's tag under the
call's session, an HMAC that the session's holder checks.

A deployment with its records in files seals its master secret to its
platform (`ProductionContractInstance::deploy_with_storage`), and restarts
from the files and the sealed secret with the attested generation
(`ProductionContractInstance::restart`); its next receipt follows the last
one it issued before the restart. The generation counts the commits the
store holds, a committed abort's among them. Each accepted call returns its
commit's generation, and the deployment advances the platform's monotonic
counter to it before it releases the call's result or makes another call. A
restart takes files at the attested generation or one past it and says
which; one past, the deployment advances the counter to the restarted
instance's generation before it releases anything the instance returns. The
counter's rollback resistance is a deployment assumption, and a generation
does not name the store it counts (Non-Claims of
[`../claim-boundary.md`](../claim-boundary.md)).

## Non-Claim

This observer closure does not prove every Rust implementation detail,
downstream machine-code behavior, or raw microarchitectural trace. It fixes the
observer and deployment assumption surface used by the paper claim.
