# Finding Implementation Tracker

Scope: all non-usability findings from `review/findings.csv` and
`review/update_oblivious_toolchain_review.md`.

Status legend:

- `landed`: implemented and covered by validation.
- `partial`: some enforcement or documentation exists, but the review finding is
  not fully closed.
- `open`: no substantive implementation yet.
- `policy`: requires an explicit scope/product decision before implementation.

| ID | Grouped finding | Status | Landing evidence / remaining work |
| --- | --- | --- | --- |
| T1/M1/M2/M3 | Public persistent state and history/final-state declassification theorem | landed | Compiler public-write policy and metadata are landed. Lean outcomes now carry final public state, and history semantics exposes final-public-state equality. |
| T2/M4 | Proof-grade loop/control-flow admission | landed | UO compiler and Lean proof-grade metadata admission reject non-exact loop bounds. |
| T3/M4 | Fail-closed metadata policy | landed | Compiler sidecar consistency, declassification-aware taint checks for return/status/public-state channels, implicit control-flow taint, UO raw-confidential-state rejection, and the matching Lean `functionMetadataWellFormed` checker are landed. |
| T4/M5 | Artifact/proof-relevant view completeness | landed | Proof-relevant serialization now emits explicit nulls, validates required field completeness recursively, and has mutation coverage. |
| T5/M7 | Runtime proof-object extraction transcript completeness | landed | Execution traces now carry SHA-256 hashes for a typed primitive-event transcript and runtime proof-object payload; probe boundary evidence marks the transcript binding. |
| T6 | Lean operational-state well-formedness | landed | `OperationalConfig.WellFormed`, object-map-based reads, fail-closed writes, and `writeObject?_wellFormed` preservation are landed; ProofGrade lemmas now require admitted writes. |
| T7/M9 | Nonce/freshness and diagnostic/production separation | landed | Seeded deployment/fresh-coin injection are cfg-gated from production, and Lean freshness audit entries require uniqueness/domain separation and production-safe mode. |
| T8/M10 | Normalized-host observer wording | landed | `docs/claim-boundary.md` now names the normalized hostile-host observer. |
| T9 | Abort/rollback/final persistent state theorem | landed | Covered by T1/M1 post-state work and final-public-state history projection. |
| T10 | Zero capacity | landed | Compiler rejects zero map/array capacity. |
| P1 | Path ORAM local-position-map linear metadata scan | landed | `path_oram_local_posmap_v1` is now explicitly capped at capacity 128 until a recursive/private position map is implemented; docs and resource matrix expose the linear metadata cost. |
| P2 | Large proof evidence growth | landed | Default compact proof-evidence budget is now 64 MiB; large fresh-coin families and canonical pair certificates fall back to compact theorem-input reports by default. |
| P3 | Encrypted private return channel | landed | Compiler admits `encrypted_to_client` only for confidential entrypoints without plaintext return declassification; runtime exposes a per-call return-channel session API that produces ciphertext-only public outcomes with nonce/AAD/session evidence; Lean audit surfaces include the no-plaintext-declassification and nonce/session/attestation evidence policy theorems. |
| P4 | Evaluation evidence too narrow | landed | `results/overheads.json` now contains a 6-workload/17-row backend-capacity matrix with gas, read/write counts, byte counts, trace sizes, artifact sizes, and resource bounds. |
| P5 | Not deployable as normal Solidity/EVM bytecode | excluded | Product/deployment-scope item, not a non-usability correctness finding for the in-process runtime/toolchain. |
| P6 | Common smart-contract patterns outside scope | excluded | Language-product scope item for the intentionally restricted subset, not a non-usability correctness finding. |
| P7/M11 | Capacity planning and quantitative resource bounds | landed | Manifest-level `entrypoint_resource_bounds` exposes public ORAM cost formulas, and the overhead matrix records those bounds per workload/backend row. |
| P8 | TCB and operations cost | landed | Reviewer summary now exposes TCB surface, proof/checking cost, artifact-size estimates, and explicit assumption/operations tables as adoption-gate evidence. |
