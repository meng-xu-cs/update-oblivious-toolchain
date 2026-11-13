# Claim Boundary

This document owns the current theorem claim, observer shape, assumptions, TCB,
and non-claims. It is the canonical place to look before changing claim
wording elsewhere.

## Paper Theorem

For every admitted program package `(P, M, V)`, where `P` is the restricted
Solidity-like UO DSL source, `M` is the strict sidecar metadata, and `V`
records the compiler/proof/runtime model versions, if `uo-solc` compiles the
package to artifact `A`, the artifact records the matching admitted-package
hash, the Lean source/artifact checker accepts the pair, the real runtime
executes `A` and emits proof objects accepted by Lean, and the explicit
backend, cryptographic, and TEE deployment assumptions hold, then the
execution's normalized hostile-host observer satisfies the paper
update-obliviousness theorem modulo the artifact-declared releases: two
executions with the same public projection (admitted package, public
arguments, public environment, and initial public state) have equal
observations once the declared releases are erased,

```text
View_SGX(c₁) ∖ rel = View_SGX(c₂) ∖ rel
```

exactly for the exact backends, and with the storage component related by the
Path ORAM storage relation on the proof-grade Path ORAM routes. The released
values themselves may differ between the two executions. On the Path ORAM
routes the Lean development currently proves much less than this statement;
see Backend Scope.

The compiler-side trust story starts at the post-resolution Sol AST / UO IR
consumed by Lean. The active source theorem is for `uo-solidity-like-dsl-v1`,
not full Solidity 0.8 semantics. Parser-level preprocessing remains trusted
until a raw-source-to-post-resolution witness relation is mechanized.

The artifact-level admitted-package hash is a canonical SHA-256 binding over
the source-language tag (`uo-solidity-like-dsl-v1`), the executable-semantics
profile tag (`uo-evm-modular256-v1`), source bytes, canonical sidecar metadata
JSON, compilation mode, compiler version, toolchain manifest digest, and package
schema tag. The semantics profile pins the executable divergences from Solidity
0.8 — wrapping arithmetic, division/modulo-by-zero returning zero, canonical
fixed-size ABI encoding, `require`/abort rollback, admitted-only context
variables, and the mock-hash preservation route paired with the real-Keccak
runtime primitive — and the proof-grade checker rejects an unknown or divergent
profile. It is checked for equality by the proof-grade translation bundle. It is
not by itself a deployment attestation hash; the production deployment theorem
binds it to the runtime binary hash, proof-root hash, SGX quote, return-channel
session transcript, and freshness counters.

### Declared Releases

`∖ rel` erases exactly what the entrypoint's sidecar policies release. The
policies are carried in every public outcome, and the erasure is
`PaperMainViewSGX.withoutReleases` in `UOToolchain/PaperMainReleases.lean`:

- `status: declassified` releases whether the call completed or aborted: the
  termination status and the fields the runtime derives from it alone, namely
  the abort/rollback flag of the final public-state record, the output shape,
  the output length of the enclave exit event (the return length, zero for an
  aborted call), and whether a plaintext or encrypted return payload is
  present.
- `returns: declassified` releases the plaintext return payload.
- `returns: encrypted_to_client` releases only the AEAD output bytes, the
  ciphertext and its tag; the session binding, AAD hash, nonce, and lengths
  stay constrained.

Every other component must be equal: the storage trace, boundary schedule,
normalized micro trace, modeled gas, the declared policies and
declassification labels, the final public-state digests, and the declared
release functions. For example, `ConfidentialMixer.withdraw` declares
`status: declassified` and `returns: declassified`. A withdrawal that
completes and returns 5 and one that aborts on an insufficient secret balance
must have the same storage trace, schedule, and gas; only the released status
and return value may differ.

Which statuses are released is checked by the compiler, not left to the
sidecar author: an entrypoint whose success/abort status depends on secrets
must declare `status: declassified`. That includes every entrypoint that writes
a confidential map, because a full bounded map aborts a write of a new key and
whether a key is new depends on the map's confidential contents; for example,
`ConfidentialMixer.deposit` declares `status: declassified` for this reason
(see [`supported-subset.md`](./supported-subset.md)). The Lean counterpart of
this analysis over kernel programs (`KernelProgram.flowSummary` in
`UOToolchain/KernelFlow.lean`) is proved sound: when it reports a public status
or return, runs that agree on public inputs end with the same status or return
value (`evalKernelProgram_flow_ni`).

For exact-backend entrypoints the per-component premises are discharged, not
assumed. `paperMain_admittedKernelRun_exact_noninterference_moduloReleases`
(`UOToolchain/KernelPaperMain.lean`) proves the theorem for every run of an
entrypoint whose kernel program is well typed over the state layout, returns
only as its last statement, writes only confidential objects, and declares
policies that agree with the flow analysis. The view is built from Lean models
of the runtime's public observables: the exact store's trace, the public
outcome, the boundary schedule, and the final public-state record. These four
conditions are decided per entrypoint on the compiled artifacts by
`checkKernelAdmission` (`UOToolchain/KernelAdmission.lean`). Every confidential
entrypoint of the benchmark artifacts is admitted
(`kernel_admission_*` in `results/static_checks.json`). Entrypoints that access
an ORAM map are reported on the `path_oram` route, which this exact theorem does
not cover. On that route the same models discharge the Path ORAM theorems'
outcome, boundary, final-state, and release premises
(`paperMain_admittedKernelRun_pathOramLocalPosmapV1_noninterference_moduloReleases`
and its private-scheme counterpart, `UOToolchain/PathOramKernelPaperMain.lean`).
Their boundary schedule leaves and re-enters the enclave around each of the
call's ORAM accesses (`kernelOramBoundarySchedule`), whose number the program
and its maps' schemes fix: a private-scheme ERC20Lite `transfer` at 256
entries makes 90, its two writes reusing the presence their reads found. Those theorems keep the ORAM premise, which bundle evidence
discharges (see Backend Scope), and link the ORAM model's configurations to
kernel runs through a `KernelDenotation`: every admitted configuration denotes
an admitted run, and configurations with the same public projection denote
runs that agree on contract, entrypoint, public arguments, public environment,
and public store. That the runtime emits the modeled observables is a
refinement obligation, not proved. The probe checks all four against the
models on every exact-route experiment run, and the outcome, boundary
schedule, and final public-state record on every Path ORAM experiment run
(`exact_encoding_matches`, `outcome_model_matches`, and
`final_public_state_model_matches` in `results/trace_equivalence.json`).
The record's digests are the runtime's own: its initial, candidate, and
committed digests must each be the digest of the public state just before the
call, which must also be the state just after it; its delta digest must be that
of an empty public delta; and its abort flag must be the negated termination
status.

The theorems are `paperMain_exact_backend_noninterference_moduloReleases`,
`paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases`, and
`paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases`, with the
accepted-package capstones
`acceptedExactPackageCapstone_noninterference_moduloReleases`,
`acceptedPathOramPackageCapstone_noninterference_moduloReleases`, and
`acceptedPrivatePosmapPathOramPackageCapstone_noninterference_moduloReleases`.
Each capstone takes the per-component safety premises (outcome and final
public state modulo releases, boundary schedule, controller shape, release
functions) as fields of its accepted-package evidence. The earlier
full-`View_SGX` theorems (`paperMain_exact_backend_noninterference` and the
capstones without the `_moduloReleases` suffix) assume every component,
released or not, is determined by the public projection, so they cover only
entrypoints without releases. Their evidence converts to the release form
(`AcceptedExactPackageCapstoneEvidence.moduloReleases` and its Path ORAM
analogues), and without declared releases the erasure is the identity
(`PaperMainViewSGX.withoutReleases_eq_self`).

## Deployment Theorem

The deployment theorem is separate from the paper theorem over the
instrumented runtime observer. A production runtime accepts a call only on
evidence that shows:

- a current admitted-package identity and matching toolchain manifest digest;
- a deployment policy matching the measured runtime binary hash, proof-root
  hash, and accepted SGX quote hash;
- a return-channel session id and attestation transcript hash matching the
  supplied session;
- freshness evidence matching the runtime epoch, rollback counter, and next
  call counter at call entry; and
- the hash of the receipt the runtime issued last.

Every item is something a caller can know before the call runs. The runtime
issues a receipt when it is deployed and one for each call it accepts
(`ProductionReceipt`). A receipt names the request it answers, the receipt
before it, the public-state digest and a digest of the sealed records in
storage before and after, the hash of the call's public receipt, and the
freshness counters after the call. The receipts of a deployment form a
chain: a call that names any receipt but the last is rejected, and a holder
of two receipts can check that one follows the other.

No proof object and no private evidence leaves a production runtime, and
nothing in a receipt derives from either. What a production result rests on
is therefore: the attested binary and policy that the evidence names; the
theorems about the model; and the validation of that binary's source, which
the Lean checkers perform on diagnostics builds, where the same code returns
its traces. A production build is not checked call by call.

A receipt is not signed. Its fields are bound by the chain and by the
runtime's check at the next call; how a caller authenticates the receipt it
holds last belongs to the attested channel, which this repository models
only through the session's hashes.

The Rust enforcement point is `ProductionContractInstance::call_authorized`.
The Lean theorem surface is `DeploymentAcceptance.lean`:
`DeploymentCallAccepted` exposes the field bindings of the evidence,
including the receipt it names, and `DeploymentReceiptFollows` is the chain
relation, with theorems that a replayed, reordered or skipped receipt does
not follow. That the Rust receipt checks implement those relations is tested
in the production build (`runtime/uo-evm/tests/production_boundary.rs`), not
proved.

## Backend Scope

- Exact-UO is claimed for exact backends on the repository's instrumented
  abstract/runtime model: `UOCell`, `UOArray`, and full-scan `UOMap`. For
  admitted kernel programs it is a Lean theorem over the exact store's
  encoding (`UOToolchain/KernelExactTrace.lean`): every admitted run executes
  the whole kernel body; the run reads each object the body accesses once,
  every slot of it, when the call loads the object, in object-id order and
  however many statements access it (`exactEncodeRun_reads_each_touched_once`);
  and every object the program has a write statement for is rewritten at
  commit with `Update`-class writes, whether or not the write's predicate
  holds. An object the program only reads is read and not written
  (`exactEncodeRun_rewrites_only_written`). Which objects are read and which
  are rewritten is fixed by the program, so all admitted runs of a program
  produce the same
  trace (`admittedKernel_exactUO`) and
  `paperMain_admittedKernel_exact_noninterference_moduloReleases` discharges
  the paper-main theorem's storage-trace premise. That the runtime store
  emits exactly this encoding is checked against runtime traces
  (`exact_encoding_matches` in `results/trace_equivalence.json`), not proved.
  The class `Update` of a sealed write is not a label the runtime asserts:
  where it seals a record in place it keeps the record the write replaces
  and fails the call unless every 32-byte unit of the new record is an
  `Update` of the unit it replaces (`is_update_write`; the Lean statement of
  the check, with the unit length as a parameter, is `isUpdateWrite` in
  `UOToolchain/RuntimeStoreCodecSemantics.lean`). That a fresh nonce makes
  every unit differ holds except with negligible probability and is not
  proved; the check turns the exception into a failed call, a source check
  keeps every sealed write behind it
  (`sealed_writes_are_classified_from_their_bytes` in
  `runtime_boundary_validation.json`), and two tamper scenarios remove it
  and are rejected.
  The manifest lists the objects an entrypoint may write
  (`may_write_objects`). The compiler derives the list; `uo-check` and the
  Lean translation checker recompute it from the function's body
  (`manifest_may_write_objects_exact_of_lookup`); and the runtime takes it
  from the slot program it runs, refuses a manifest that says otherwise, and
  reseals those objects, also when the call aborts, and no other. Two tamper
  scenarios change the list, one to omit a written object and one to add an
  object that is only read, and the checker rejects both.
- Computational UO on `path_oram_local_posmap_v1` is a theorem over admitted
  configurations, given bundle evidence for them
  (`UOToolchain/PathOramAdmitted.lean`): every pair of admitted
  configurations with the same public projection satisfies the local Path
  ORAM theorem, the SGX execution theorem and the paper-main theorem modulo
  releases. The bundle exists: a runtime pair slice is one, admitting the
  pair's two sides, and `checkCanonicalPathOramPaperInstantiation` derives it
  for one concrete pair of `SingleAccessMap.put` runs (one ORAM access). The
  bundle's leaf obligation follows from `UOToolchain/PathOramFreshLeaves.lean`
  without seed enumeration, for a runtime family that runs every coin tape of
  a call: that file proves that a call's leaf schedule, on one map or
  several, is uniform for any accesses and any keys present before the call,
  given uniform coins and leaves, and that the leaves left behind stay
  uniform and independent of it. One valid runtime run gives such a family:
  the run on any other tape is the run with that tape's leaves substituted,
  and every substituted run passes the Lean runtime-witness checks
  (`UOToolchain/PathOramTapeWitness.lean`). So the multi-access local
  entrypoints (SingleAccessMap `add`, ConfidentialMixer `deposit`, ERC20Lite
  `transferFrom`) get the theorem between their pair's two sides from the
  compact theorem inputs the probe checks. That the runtime's run on every
  tape is the substituted run is tested, not proved: the checker compares
  four more runtime runs per side, on other deployment seeds and coins, with
  their substituted runs. The older theorems that take a
  `SeededRuntimePathOramProofBundle`, whose `cfgWellFormed` field quantifies
  over every `OramConfig`, hold vacuously
  (`seededRuntimePathOramProofBundle_empty` in
  `UOToolchain/RuntimeCoins.lean`). Calls that abort run on both schemes: map
  writes reach the ORAM at commit, masked off on abort, so an aborted call
  makes the same accesses as a committed one.
  `path_oram_private_posmap_v1` lifts the local scheme's capacity cap and
  keeps a map as an oblivious AVL tree whose nodes hold their children's
  leaves, so its position map recurses through the tree: a get makes `h`
  node accesses and a put `3h + 1`, `h` the largest AVL height for the
  capacity, each one Path ORAM access that reads and writes one path, and an
  operation reads and writes its header and stash pages once. Its stash
  bound adds the `3h + 1` nodes an operation returns to the stash to the
  Path ORAM bound; that the stash stays within it with the Path ORAM tail is
  part of `stashOverflowBounded`, assumed and not proved. The admitted route
  covers it. The AVL map's algorithm is proved in Lean over inductive trees
  (`UOToolchain/PathOramAvlMap.lean`): with the runtime's walk, successor
  delete, rotation rule and node-access counts, and the walk bounded by the
  capacity's largest AVL height, a get returns the key's value and a put
  writes, updates or deletes it, keeps the tree sorted, balanced and within
  the capacity, and overflows exactly when it would insert into a full map
  (`get_spec`, `put_spec`). That the runtime's `tree_get` and `tree_put`
  follow the model is tested, not proved: `checkPathOramAvlMapReplay`
  replays 2,400 runtime operations on maps of 1 to 31 nodes against it,
  comparing every result, every node access's kind, every size and every
  tree with its stored heights (`results/path_oram_avl_map_replay.json`).
  For configurations whose Path ORAM maps use either scheme, the same bundle
  gives the private scheme's theorems (`computationalUOWithOnAny`,
  `paperMain_privatePosmapV1_noninterference_moduloReleases`), and the probe
  derives the theorem between the two sides of an ERC20Lite `transferFrom`
  pair whose capacity-256 `balances` map uses the private scheme and whose
  `allowances` map uses the local one (2^734 coin seeds). See
  [`path-oram.md`](./path-oram.md).
- On both Path ORAM schemes, a call reads only the paths it accesses. It
  starts from the map's counter and metadata pages, which its first access
  also reads, and rebuilds each slot's leaf and key and the stash in the
  enclave; a read takes the key's value from the key's block once its path is
  read. The call-start reads follow a public pattern and are not in the
  trace, so the leakage claim is unaffected; `results/overheads.json` lists
  them beside the traced counts (`call_start_reads`). Every access rewrites
  every metadata page, and its trace reads them all, so its cost is linear in
  the map's capacity.
- Legacy/surrogate ORAM paths remain available for benchmarking and historical
  comparison, not for the strengthened proof-grade claim.
- Executable insecure raw baselines (the `insecure-eval-raw` evaluation feature,
  reported as the `raw_insecure_eval`/`ct_gas_only` rows in `results/overheads.json`
  and the `positive_control` in `results/leakage_auc.json`) run confidential work
  on raw backends to measure overhead and leakage against the UO route. They
  bypass the confidential-object targeting restriction, are evaluation-only, and
  are never admitted by the proof-grade translation bundle or the production
  deployment path; their result labels are distinct from the proof-grade rows so
  they cannot be confused with proof-grade artifacts.

## Observer

The paper-facing observer is:

```text
View_SGX(c) =
  ( public_outcome(c),
    boundary_schedule(c),
    storage_trace(c),
    micro_trace(c),
    final_public_state_rollback(c),
    release_functions(c) )
```

The components are interpreted as follows:

- `public_outcome` is exact: entrypoint id, public arguments, public
  environment, termination status, declared status policy, return shape,
  return policy, any public or declassified return payload, encrypted-return
  ciphertext evidence, declassification labels, and modeled public gas (cost
  model `uo-modeled-resource-cost-v2`: a modeled resource cost, not stock EVM
  gas; there is no EVM gas schedule or bytecode backend; see The Modeled
  Cost below).
- `boundary_schedule` is the exact enclave boundary sequence.
- `storage_trace` is exact for exact backends and related through the Path
  ORAM routes over admitted configurations (instances derived for runtime
  pairs: one single-access pair and the multi-access pairs on both schemes;
  see Backend Scope).
- `micro_trace` is SGX-specific and is normalized/simulated from
  `L_sgx_micro`; the theorem does not claim raw page-id or full micro-event
  equality.
- `final_public_state_rollback` holds the initial, candidate, and committed
  public-state digests, the public delta digest, and the abort/rollback flag.
- `release_functions` names the declared release functions of the admitted
  package.

The concrete SGX/TEE observer pins live in
[`runtime/tee-observer.md`](./runtime/tee-observer.md).

### The Modeled Cost

The public gas of a confidential entrypoint is a function of its schedule,
fixed when it is compiled (cost model `uo-modeled-resource-cost-v2`):

```text
2000 + 11·statements + 7·expressions + 29·max_load_ops + 29·max_commit_ops
```

`max_commit_ops` bounds the sealed records a call writes: each slot of each
exact object the entrypoint may write (`may_write_objects`), and the path
and metadata pages of each access of an ORAM map. `max_load_ops` bounds
those it reads: each slot of each exact object it loads, once; for each
access of an ORAM map the buckets of the path and the metadata pages; and,
for a Path ORAM map, the counter and the metadata pages the call reads when
it starts, which no trace records. On the exact backends the count is what
a call does: it opens each slot of an object it accesses once, when it
loads the object, the trace records that read there, and neither an access
nor the commit opens a slot again. A call that aborts keeps what it loaded
and reseals that. A confidential call loads the objects its kernel program
schedules, and a public one the objects its body accesses. On the private
scheme both count the
metadata pages once per node access, where a call reads and writes them
fewer times, so there they are bounds and not counts. Model v1 charged the
writes alone, so a call that only read would have cost about 2,000 units
whatever it read.

A read is charged what a write is. Each moves one sealed record across the
enclave boundary and costs the runtime one authenticated decryption or
encryption of it, and the two take the same time: in the capacity sweep's
baseline, loading a full-scan map of 16,384 slots, which opens every slot,
takes 32.5 ms, and the rest of the call's own work, which scans the
plaintext and seals every slot, 38.5 ms. The model does not price the
host's storage, where a write may cost more than a read.

The compiler computes both bounds. `uo-check` and the Lean translation
checker recompute them from the function's body and reject a manifest that
states another (`expectedLoadOpsForFunction` and
`manifest_load_ops_exact_of_lookup` in
`UOToolchain/TranslationValidationJson.lean`), and a tamper scenario raises
the load bound in the source artifact and the artifact alike
(`translation/max_load_ops_drift`). The statement and expression terms are
checked by recompiling the source.

## Explicit Assumptions

| Assumption | Role | Current treatment |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides Path ORAM bucket/path ciphertext contents | trusted; named in Lean and not formalized (see below): a `Prop` field of `PathOramLocalPosmapV1SecurityAssumptions`. Its provenance is the runtime `ChaCha20Poly1305` sealed-record boundary plus the cited AEAD analysis route. That route needs a nonce to seal once under a key: a record's nonce is the count of the seals under its key (`sealNonceRun_nodup` in `UOToolchain/RuntimeStoreCodecSemantics.lean` for a model of the counter; `seal_nonces_come_from_the_seal_count` in `runtime_boundary_validation.json` for the source) |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages | trusted; named in Lean and not formalized, as the row above, and paired with the same concrete sealed-record crypto route |
| `stashOverflowBounded` | bounds Path ORAM stash failure for deployed parameters | trusted; named in Lean and not formalized, as the first row, and paired with the JACM Path ORAM stash theorem at `Z = 5` and pinned deployed parameters |
| Runtime key derivation | gives each object a storage key, an initial placement and Path ORAM leaf coins that are pseudo-random and independent of the other objects', which the two encryption assumptions and the leaf-coin model take as given | trusted, not modeled in Lean: a 256-bit master secret from the OS, HKDF-SHA256 (RFC 5869) with one label per use, and the ChaCha20 generator. `runtime_secrets_derive_from_the_master_secret` in `runtime_boundary_validation.json` pins the derivation's call sites, and `runtime/uo-evm/src/secret.rs` tests the RFC's first test vector |
| TEE deployment assumptions | enclave memory confidentiality/integrity, attestation authenticity, rollback resistance, freshness, crash recovery discipline, patch-level trust | explicit Lean bundle `SgxDeploymentAssumptions`, paired with Intel SGX provenance and probe drift checks |
| Parser/preprocessing equivalence | connects raw Solidity-like source text to the post-resolution AST consumed by Lean | still trusted front-end surface |
| Real Keccak equivalence | connects runtime `tiny_keccak::Keccak::v256()` to the Lean mock-hash abstraction | not yet proved; Lean preservation uses the shared abstraction |

### What the Path ORAM Theorem Proves and What It Assumes

The three Path ORAM assumptions are named in Lean and not formalized. Each
is a `Prop` field of the assumption record. The theorems carry the record,
no proof uses what its fields say, and the checkers fill the fields with
`True` (`CheckCanonicalPathOramPaperInstantiation.lean`,
`CheckCanonicalPathOramPairTheoremInput.lean`). "Computational UO" in the
name of a theorem therefore refers to these names, not to a proved bound.

What is Lean-proved about a Path ORAM call is combinatorial:

- the leaf schedule of a call is uniform, given uniform coins and leaves,
  and the leaves it leaves behind stay uniform and independent of it
  (`UOToolchain/PathOramFreshLeaves.lean`); and
- the two sides of an admitted pair write storage at the same locations,
  with the same shapes.

The step from these two facts to "the two sides' storage is computationally
indistinguishable" is an argument on paper, not in Lean. Over a deployment
that makes `Q` primitive ORAM accesses, it bounds a distinguisher's
advantage by

```text
ε(Q) ≤ ε_PRF + ε_AEAD + ε_nonce + Q · ε_stash
```

- `ε_PRF` is the advantage in telling the runtime's storage keys and leaf
  coins from uniform ones. They derive from a 256-bit master secret by
  HKDF-SHA256 and the ChaCha20 generator (the row "Runtime key derivation").
  This term takes the Lean statement, which is about uniform coins, to the
  coins the runtime draws.
- `ε_AEAD` is the advantage against ChaCha20-Poly1305 as the encryption of
  the records sealed under the deployment's keys. It is what
  `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` name.
- `ε_nonce` is the probability that one key seals twice with one nonce. It
  is zero: a nonce is the count of the seals under its key, and a key
  refuses to seal once the count is exhausted (`sealNonceRun_nodup` for a
  model of the counter; tested for the Rust code).
- `ε_stash` is the probability that one access overflows the stash, which
  `stashOverflowBounded` names: at most `14 · 0.6002^114 < 2^-80` at the
  deployed parameters, by the cited theorem. `Q` counts primitive accesses,
  not calls: a private-scheme write at 16,384 entries makes 77 node
  accesses.

None of the four terms is Lean-proved. The first two are trusted
cryptographic assumptions, the third follows from the nonce's construction,
and the fourth is a cited theorem applied to pinned parameters.

The fresh-leaf remapping bridge is not a separate backend assumption. The
canonical fresh-coin runtime-family and hidden-leaf coverage checkers discharge
that leaf-seed-space interface directly.

`scripts/lean_assumption_budget.sh` emits `results/lean_assumption_budget.json`,
which grounds each active assumption above in the Lean source, lists its
consumer, and pins the only two `axiom` declarations
(`legacyOramLocalTheorem`, `legacySgxMicroLocalTheorem`) to legacy demonstration
modules that `UOToolchain.ProofGradeRoot` excludes. There are no `sorry`s. The
budget fails closed (and CI rejects the change) if any new `axiom`/`sorry`
appears outside that allowlist or a documented assumption stops being grounded.

## TCB

| Component | Current role |
| --- | --- |
| Lean kernel plus Lean theorem/checker development | trusted proof checker and theorem body |
| Explicit backend/crypto/deployment assumptions | trusted assumptions |
| Rust runtime kernel plus witness/certificate/bundle extraction and serialization | trusted implementation-side extraction surface; replay and reconstruction reduce but do not eliminate this trust |
| Source-backed runtime implementation boundaries | source-frozen/static-drift evidence, not full Rust semantic refinement. The runtime-to-Lean boundary obligations are classified by evidence kind in `runtime_boundary_validation.json` (`runtime_boundary_obligation_classification`): proof-critical obligations carry a Lean-theorem, generated-schema, executable-semantic-refinement, or source-frozen Rust-visibility kind, while the source-drift regression inventory is regression-only and backs no proof-critical claim. `validate_runtime_boundary_schema` rejects any proof-critical obligation backed only by source regression, so no proof-critical claim rests solely on a Rust source substring outside this source-frozen surface |
| Rust code outside the tiny confidential kernel | not part of the confidential-work TCB when pinned to public-only or generated-helper routes |
| Fixed-capacity Rust buffer helpers | safe `Vec`-backed wrappers; no production `unsafe` or `MaybeUninit` surface remains in `fixed_buffer` |
| `uo-solc` | not trusted as a proof oracle for accepted artifacts; parser/preprocessing remains trusted |
| `uo-check` | diagnostics/debug wrapper, outside the proof-grade TCB |
| `mplus-probe` | orchestration and reporting, outside the proof-grade TCB |

## Non-Claims

This repository does not claim:

- downstream machine-code equivalence below the checked runtime boundary
- a complete semantics-of-Rust refinement for every residual implementation
  detail
- raw equality of SGX page identities or full micro-event sequences
- CPU-time, cache-behavior, page-fault, allocator, scheduler, power,
  electromagnetic, or wall-clock obliviousness
- value-level equality between the Lean mock hash and real runtime Keccak
  outputs
- Solidity 0.8 checked-arithmetic, division/modulo-by-zero, ABI, revert, or
  context-variable semantics beyond the admitted public environment fields
  (`msg.sender`, `tx.origin`, `block.number`, `block.timestamp`, and
  `block.chainid`); the Lean bridge target for regaining that claim is
  `VersionedSoliditySemanticsBridge` in `SolidityDialectBoundary.lean`

Those would require additional models and proofs, not only more prose.

## Generated Manifest

This document is the source of truth for a generated claim/evaluation artifact
manifest. `mplus-probe --only claim-status` emits `results/claim_status.json`
(per-claim id/text/status), `results/claim_status.md` (the rendered status
table), and `results/claim_artifact_manifest.json` (each claim, assumption,
non-claim, and TCB component mapped to its source, Lean, runtime/compiler, and
benchmark/result artifacts plus a validation command). The report fails closed
and CI rejects the change if any assumption-table row, TCB-table row, or
non-claim bullet here is missing from the manifest, or if a referenced artifact
does not exist. `scripts/run_validation.sh` regenerates it.
