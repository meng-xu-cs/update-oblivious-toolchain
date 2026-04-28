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
- source-to-kernel correctness starts at the post-resolution Sol AST / UO IR;
  parser-level preprocessing (`solang_parser`, state resolution, capacity
  lookup, helper inlining, `abi.encodePacked` unwrapping, and assignment
  desugaring) remains a trusted front-end step until a proof-relevant
  preprocessing witness is added
- the runtime uses real `tiny_keccak::Keccak::v256()` over canonical bytes, but
  the current Lean source/IR/kernel preservation proofs use a deterministic
  mock hash and therefore do not claim value-level functional correctness for
  real Keccak-derived results
- source-backed runtime implementation checks are classified as
  source-frozen/static-drift evidence, not Rust semantic refinement; the
  runtime witness/certificate extractor remains in the implementation-side TCB
  even though trace replay and certificate reconstruction reduce what an
  unchecked producer can assert
- guarantees are over the instrumented abstract/runtime traces emitted by this workspace, including the normalized physical read/write schedules captured by the current runtime
- the prototype does not claim a proof for every downstream machine-code or microarchitectural observer
- in a TEE deployment, persistent state now satisfies a concrete sealed-storage assumption rather than the previous marker-hiding placeholder encoding
- the runtime now emits an explicit theorem-facing observer containing public outcome, exact boundary schedule, public controller shape, and normalized SGX micro trace, and those controller fields now come from a call-scoped runtime recorder rather than a manifest-only reconstruction
- the controller now also rebuilds that observer from an independent pure reduction over the recorded public ORAM schedule and rejects any drift between the incremental recorder state and the reconstructed observer
- the runtime also rejects any observed ORAM access whose public parameters drift from the compiled manifest, so the emitted controller certificate is tied to the admitted artifact metadata rather than only to the live runtime object
- the trace layer now also exposes a checked refinement witness for Lean consumption; that witness carries an ordered public controller certificate plus public ORAM object metadata, witness extraction fails if the emitted theorem fields drift from the certificate reconstruction or if the controller certificate does not match the ORAM access schedule independently reconstructed from the public logical trace, the runtime now enforces that check before returning an emitted trace, and Lean independently rebuilds the same access schedule and boundary/controller observer during witness validation
- the runtime refinement witness now also carries both a hidden per-access path-ORAM leaf schedule and an explicit public leaf scaffold for proof purposes; both Rust and Lean validate that the public scaffold matches the path accesses reconstructed from the logical trace, that the hidden schedule agrees with that scaffold exactly, and that projecting those hidden leaves back to bucket paths reproduces the observed path-ORAM bucket trace exactly
- the witness now also exposes hidden path-ORAM position-map state before and after the call together with an exact per-access hidden transition certificate; witness validation no longer treats the leaf schedule as an unstructured hidden trace, but replays the certified position-map transitions and checks that they land on the exported final hidden state
- the Lean runtime-refinement layer now also factors a path-ORAM call into hidden initial position-map state, hidden transition shape, and a minimal fresh-leaf coin sequence; together with the canonical fresh-coin family and hidden-leaf coverage checkers, that now discharges the exact leaf-seed-space bridge rather than leaving fresh-leaf resampling as a separate backend assumption
- the runtime seed path is now materially meaningful: seeded deployment drives object-local RNG state, ORAM leaf sampling, and store-cipher key generation through the same deterministic coin path, and the runtime exports that seed in the witness, although the Lean proof still stops short of a full distribution theorem over those runtime coins
- the artifact validation path now checks representative full-scan, ORAM, and path-ORAM benchmark scenarios, including a multi-object `transferFrom` ORAM path, by feeding real Rust-emitted witnesses into the Lean checker
- the Lean theorem stack now contains an explicit standard-ORAM lifting layer plus a path-ORAM-specific storage theorem boundary with a named assumption bundle; that path boundary now projects away the legacy surrogate-style `schedule`, normalizes raw path logical reads to a public skeleton, reconstructs the ordered leaf scaffold from the public logical trace plus public ORAM metadata, and decomposes storage security into a hidden per-access leaf-value relation plus exact public leaf-scaffold, non-bucket location-scaffold, and storage-shape constancy, with bucket traces obtained by an explicit deterministic projection from leaves, so the remaining ORAM assumption is smaller than a whole-view storage theorem for the concrete `path_oram_local_posmap_v1` candidate, and the theorem layer now also exposes direct scaffold-indexed variants so checked runtime witnesses can feed that boundary without going back through the older public-alignment adapter
- the Lean proof stack now also contains `RuntimeCoins.lean`, which packages seeded runtime witnesses into a finite-distribution interface and proves the exact public leaf-scaffold facts directly; canonical leaf-value realization is now an explicit theorem hypothesis at the lemmas that need it, rather than an implicit field bundled into the seeded witness-family structure
- the prototype still does not claim that SGX execution itself is oblivious against a malicious host, because the remaining gap is now the end-to-end semantics-of-Rust refinement proof from the real Rust confidential runtime/kernel path to the Lean runtime / controller / hostile-host observer model; the shell boundary is now formalized and packaged as one proof-grade interface, the checked inner shared-kernel source boundary now also meets both the live emitted `RuntimeKernelMachineFinishWitness` and the smaller emitted finish-slot artifact directly on the native runtime-kernel finish/slot boundary route, the concrete storage theorem for the admitted path-ORAM backend is discharged at the frozen backend interface, and the legacy surrogate ORAM mode remains in scope only for non-proof-grade benchmarking
- physical side channels such as power or electromagnetic leakage are outside the intended theorem boundary
