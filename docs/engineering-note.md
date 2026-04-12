# Engineering Note

Exact-UO in this artifact:

- `UOCell`, `UOArray`, and full-scan `UOMap` preinitialize confidential regions with nonzero filler, encode logical zeros as marker-free records, and rerandomize every physical rewrite.
- Normalized `M+` traces therefore collapse to public-determined `UPDATE` schedules after initialization.

Computational-UO in this artifact:

- The ORAM backend uses a public-schedule, fixed-size bucket rewrite discipline plus fixed-shape committed control-metadata rewrites.
- It is reported as computational-UO only; the implementation is an instrumented prototype rather than a full production ORAM proof.

Stronger ORAM candidate in this artifact:

- A second ORAM scheme, `path_oram_local_posmap_v1`, now exists as a standard-ORAM-style candidate with a persisted position map, persisted stash, and real path rewrites.
- That candidate now executes each ORAM access immediately on the transaction shadow state, supports multiple accesses to the same ORAM object within one entrypoint, and emits the corresponding fixed-shape path rewrite trace through the runtime controller recorder.

Remaining assumptions:

- arithmetic is executed in a bounded `u128` domain even when the accepted Solidity syntax spells `uint256`
- guarantees are over the instrumented abstract/runtime traces emitted by this workspace, including the normalized physical read/write schedules captured by the current runtime
- the prototype does not claim a proof for every downstream machine-code or microarchitectural observer
- in a TEE deployment, persistent state now satisfies a concrete sealed-storage assumption rather than the previous marker-hiding placeholder encoding
- the runtime now emits an explicit theorem-facing observer containing public outcome, exact boundary schedule, public controller shape, and normalized SGX micro trace, and those controller fields now come from a call-scoped runtime recorder rather than a manifest-only reconstruction
- the trace layer now also exposes a checked refinement witness for Lean consumption; witness extraction fails if the emitted theorem fields are not internally consistent with the controller-shape simulation
- the prototype still does not claim that SGX execution itself is oblivious against a malicious host, because the end-to-end Lean refinement from the Rust controller/runtime to the `View_SGX` theorem boundary is not yet completed and the legacy surrogate ORAM mode remains in scope for non-proof-grade benchmarking
- physical side channels such as power or electromagnetic leakage are outside the intended theorem boundary
