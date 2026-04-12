# Paper Theorem Profile

This note records the paper-facing theorem profile currently implemented by the
Lean scaffold.

## Main Choice

The main theorem keeps the enclave boundary exact and public:

- `public_outcome` is exact
- `boundary_schedule` is exact
- `storage_trace` is handled by the backend theorem
- only the SGX-specific `micro_trace` is normalized and simulated from
  `L_sgx_micro`

This is the intended headline claim for the repository. A boundary-normalized
variant is future work, not the main theorem profile.

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
  public output shape, and public gas
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
  `proof/lean/UOToolchain/SgxMicroGame.lean`

The runtime-to-Lean witness interface is now fixed in:

- `ExecutionTrace::runtime_refinement_witness` in
  `crates/uo-core/src/trace.rs`
- `uo-evm --format refinement-witness` in `runtime/uo-evm/src/main.rs`
- `RuntimeRefinementWitness` and its projection lemmas in
  `proof/lean/UOToolchain/RuntimeRefinement.lean`
- `RuntimeRefinementJson.lean` for JSON import, Lean-side witness checking, and
  conversion into the theorem objects
- `checkRuntimeWitness` in `proof/lean/CheckRuntimeWitness.lean` for
  end-to-end witness validation from the Lean side
- `results/witness_validation.json` for benchmark-backed validation that the
  emitted runtime witnesses are accepted by the Lean checker on representative
  supported paths

## Non-Claim

This profile does not currently claim:

- raw equality of SGX page identities
- raw equality of full micro-event sequences
- a normalized boundary theorem

Those would require a different observer choice and possibly a wider leakage
model.
