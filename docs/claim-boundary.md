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
policies that agree with the flow analysis: a status that depends on secrets
is declared `declassified`, and a return that depends on secrets is declared
`declassified` or `encrypted_to_client`. The view is built from Lean models
of the runtime's public observables: the exact store's trace, the public
outcome, the boundary schedule, and the final public-state record. These four
conditions are decided per entrypoint on the compiled artifacts by
`checkKernelAdmission` (`UOToolchain/KernelAdmission.lean`). Every confidential
entrypoint of the benchmark artifacts is admitted
(`kernel_admission_*` in `results/static_checks.json`).

Under `returns: encrypted_to_client` the returned value may be secret. The
outcome model holds it as the payload of the call's return channel and not in
the clear (`kernelPublicOutcome`,
`kernelPublicOutcome_returnPayload_encrypted`), and the call exits with the
payload's wire length: the value's canonical length and 28 bytes of nonce and
tag. The channel is a parameter of the theorems (`ReturnChannelModel`): any
function from the call's public arguments and the returned value to a payload
which, without its ciphertext and tag, does not depend on the value. That is
the model's statement of what the runtime computes. The session binding is the
caller's. The associated data are the admitted package, the contract, the
entrypoint, the return length, the public arguments and the binding. The nonce
is a hash of the runtime's public freshness counters, the binding and the
hash of the associated data. The lengths are the entrypoint's. That the
runtime's payloads have this form is checked on runs, not proved of the Rust
code. `ConfidentialMixer.sealedBalanceOf` returns a secret balance this way,
on the exact route and on both Path ORAM schemes. In
`results/trace_equivalence.json`, runs of it on commitments with different
balances match the outcome model, show one binding, one hash of associated
data, one nonce and the same lengths, and return payloads that open under the
caller's session to the balances stored and under no other key
(`encrypted_return` in the entries whose mode ends in `encrypted_return`). A
tamper scenario declares that return `public` and the admission checker
rejects it. What the released ciphertext and tag show of the value is for the
AEAD to bound: see the row "Return-channel AEAD" under Explicit Assumptions.
Entrypoints that access
an ORAM map are reported on the `path_oram` route, which this exact theorem does
not cover. On that route the same models discharge the Path ORAM theorems'
outcome, boundary, final-state, and release premises
(`paperMain_admittedKernelRun_pathOramLocalPosmapV1_noninterference_moduloReleases`
and its private-scheme counterpart, `UOToolchain/PathOramKernelPaperMain.lean`).
Their boundary schedule leaves and re-enters the enclave around each of the
call's ORAM accesses (`kernelOramBoundarySchedule`), whose number the program
and its maps' schemes fix: a private-scheme ERC20Lite `transfer` at 256
entries makes 90, its two writes reusing the presence their reads found.
Which lookups reuse what an earlier lookup of their key found is a function
of the program alone (`UOToolchain/FactReuse.lean`: `run_plan`, and
`run_reuse_sound` for the key a reused fact was found under). Those theorems keep the ORAM premise, which bundle evidence
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

The runtime gives each receipt a tag under the session of the caller it
answers: an HMAC-SHA256 over the receipt's hash, under a key that HKDF
derives from the session's key and id for receipts alone. A call returns
its receipt's tag, and the runtime tags its last receipt, the deployment's
included, for any session that asks. A caller holding the session checks
the tag of a receipt it holds with `verify_production_receipt`, and makes
no call to do it: a receipt changed in any field, the digest of the
ciphertext store after its call among them, is rejected, as is a tag made
under another session. What a verifier of a tag may conclude is in
`UOToolchain/DeploymentAcceptance.lean`. A receipt and its tag reach their
verifier from outside the enclave, so an adversary of the session may have
made both, and the module states two assumptions about what such an
adversary can output, as hypotheses:

- a receipt and a tag it outputs whose tag verifies under the session's
  key have the hash of a receipt the runtime issued
  (`UnforgeableAgainst`);
- a receipt it outputs with the hash of an issued receipt is an issued
  receipt (`HashBindsIssued`).

Under them, a receipt the adversary output with a tag that verifies is one
the runtime issued, with every field as issued
(`deployment_receipt_tag_verifies_issued`; the row "Production receipt MAC"
under Explicit Assumptions). The assumptions are not vacuous
(`deployment_receipt_tag_assumptions_not_vacuous`). Take a model in which
the runtime issued one receipt and not a second, the first with another
digest of the ciphertext store after its call. There both assumptions hold,
the issued receipt's tag verifies, and no tag the adversary can output with
the second receipt does. Until Issue 64 of the review of 16 November 2026 the
module assumed instead that every hash whose tag is the one computed from it
is an issued receipt's hash, and that no two receipts share a hash. Together
those made every receipt an issued one, so the premises of the rejection
theorem (`deployment_receipt_not_issued_tag_rejected`) could not hold
together. Both old statements are false in the model, so the theorem above
would not build with either. The maintainer chose this route over removing
the two theorems and arguing the MAC outside Lean. A tag convinces its
session's holder alone: a MAC is no signature, and a third party who is shown
a receipt and its tag learns nothing from the tag.

No proof object and no private evidence leaves a production runtime, and
nothing in a receipt derives from either. What a production result rests on
is therefore: the attested binary and policy that the evidence names; the
theorems about the model; and the validation of that binary's source, which
the Lean checkers perform on diagnostics builds, where the same code returns
its traces. A production build is not checked call by call.

The two builds run a call differently in one place. A diagnostics build
records the hidden ORAM state of each call, the access counters and
position maps of the contract's Path ORAM objects before and after it, and
builds the proof objects that carry them. A production build records no
such state and builds no proof object: it has no function that decodes a
position map for a witness. It runs the checks of the rest of the call's
evidence that the proof objects' constructors run (invariant 15 of
[`runtime/secret-state.md`](./runtime/secret-state.md)). A test runs the
same calls from one seed both ways and sees the same return values, public
receipts and ciphertext (`a_call_without_a_witness_is_the_same_call` in
`runtime/uo-evm/src/engine.rs`); that the two builds agree on every call is
tested, not proved.

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
  The check is Lean's (`exactTraceMatches` in
  `UOToolchain/KernelExactTraceCheck.lean`, run by `checkExactTrace`): from
  the call's artifact it decodes the entrypoint's kernel program and the
  layout of each object the program touches (its slot count, the naming of
  its slots, and the length of a sealed record of its type), and the
  trace's reads and writes must be those of `exactEncodeRun` of the program
  over that layout, one for one and in order. So every record has the
  sealed length of its object's type and every write is an `Update`
  (`exactTraceMatches_sound`, `exactTraceMatches_writes_update`).
  A runtime trace holds the scan and the rewrite of an exact object as one
  item each: a run, with the object, the naming of its slots, their count
  and their one length. The trace is the events of its items in order.
  `uo-core` names the events of a run as the encoding names them
  (`ExactObjectLayout.scanReads` and `updateWrites` in
  `UOToolchain/ExactObjectLayout.lean`, with which the Lean importers
  expand a run), computes the hashes of a trace over its events, and
  rejects a run that names a Path ORAM object. A rewrite stands for
  `Update` writes because the recorder builds it from the writes it is
  handed, each classified from its bytes as below, and takes a write into
  the rewrite only if it is the `Update` of the rewrite's next slot. A
  source check binds this (`trace_runs_stand_for_recorded_events` in
  `runtime_boundary_validation.json`), and ten tamper scenarios are
  rejected: three change the sources, and seven change the trace of a
  call (`exact_trace/*`: the slot count of a scan and of a rewrite, the
  record length, the naming of the slots, the class of a write, a read
  left out, an object scanned twice), which the Lean checker rejects.
  The class `Update` of a sealed write is not a label the runtime asserts,
  and it does not rest on the ciphertext. A sealed record is a whole number
  of 32-byte units, the unit the storage observer classifies. Each unit is
  one marker byte and 31 bytes of the record's nonce, ciphertext and tag,
  with zeros after the tag in the last unit. Every unit of a record carries
  the same marker, one of two nonzero values, and a record sealed over
  another carries the marker its predecessor does not. So no unit of a
  record is zero and no unit equals the unit it replaces, whatever the rest
  of the two records holds: the write is an `Update` in every unit
  (`isUpdateWrite_of_markers` and `encodeSealedRecord_reseal_isUpdate` in
  `UOToolchain/RuntimeStoreCodecSemantics.lean`; the same file proves the
  codec's round trip and its fixed public length, and that a record with a
  zero unit does not decode, with the unit length a parameter of the
  statements). A record's marker is the parity of the number of times it
  has been written, which the storage trace fixes. Those theorems are about
  a model of the codec. That the generated Rust
  (`runtime/uo-store/src/generated_codec.rs`) computes the model is tested
  and its text is pinned, not proved, so the runtime also checks each write:
  where it seals a record in place it keeps the record the write replaces
  and fails the call unless every 32-byte unit of the new record is an
  `Update` of the unit it replaces (`is_update_write`; its Lean statement is
  `isUpdateWrite`). A source check keeps every sealed write behind that
  check (`sealed_writes_are_classified_from_their_bytes` in
  `runtime_boundary_validation.json`), and four tamper scenarios are
  rejected: two remove the check, one takes a record's marker from its first
  unit alone, so that a record with a zero unit would decode, and one seals
  a record under the marker of the record it replaces.
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
  their substituted runs, and `results/tape_substitution_full.json` makes
  the comparison over 1,344 tapes: on maps of both schemes at three
  capacities each, calls of seven kinds (reads, inserts, overwrites,
  deletes and a write that aborts), each after a setup with deletes and
  aborts and each run on 16 other deployment seeds (see
  [`path-oram.md`](./path-oram.md)). The older theorems that take a
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
  part of `stashOverflowBounded`, assumed and not proved, and measured over
  ten million node accesses (`results/stash_occupancy_full.json`). A stash
  that overflows is an error that drops the call, so no block is lost (see
  [`path-oram.md`](./path-oram.md)). The admitted route
  covers it. The AVL map's algorithm is proved in Lean over inductive trees
  (`UOToolchain/PathOramAvlMap.lean`): with the runtime's walk, successor
  delete, rotation rule and node-access counts, and the walk bounded by the
  capacity's largest AVL height, a get returns the key's value and a put
  writes, updates or deletes it, keeps the tree sorted, balanced and within
  the capacity, and overflows exactly when it would insert into a full map
  (`get_spec`, `put_spec`). That the runtime's `tree_get` and `tree_put`
  follow the model is tested, not proved: `checkPathOramAvlMapReplay`
  replays 2,400 runtime operations on maps of 1 to 31 nodes against it
  (`results/path_oram_avl_map_replay.json`) and 7,398 on maps of 127 to
  2,048 nodes, 3,559 of which leave a tree of at least 1,024 nodes
  (`results/path_oram_avl_map_replay_full.json`). It compares every result,
  every node access's kind, every size and the recorded trees with their
  stored heights, and the replay checks after every operation that each
  node is stored once on its leaf's path, that each pointer carries its
  node's current leaf, and that the tree and the free list are acyclic and
  hold every node.
  For configurations whose Path ORAM maps use either scheme, the same bundle
  gives the private scheme's theorems (`computationalUOWithOnAny`,
  `paperMain_privatePosmapV1_noninterference_moduloReleases`), and the probe
  derives the theorem between the two sides of an ERC20Lite `transferFrom`
  pair whose capacity-256 `balances` map uses the private scheme and whose
  `allowances` map uses the local one (2^734 coin seeds). See
  [`path-oram.md`](./path-oram.md).
- On both Path ORAM schemes, a call reads only the paths it accesses. It
  reads the map's counter and metadata pages once, when it loads the map,
  and rebuilds each slot's leaf and key and the stash in the enclave; a read
  takes the key's value from the key's block once its path is read. The
  trace names each of those reads where the call makes it, and no access
  names them again: the call holds the records (see The Storage Boundary
  below). Every access rewrites every metadata page, so its cost is linear
  in the map's capacity.
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
  model `uo-modeled-resource-cost-v3`: a modeled resource cost, not stock EVM
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

### The Storage Boundary

`storage_trace` is written by the runtime's call recorder, which the code
that performs an access calls. A second account of a call's storage comes
from the other side. A deployed contract keeps its sealed records in a
storage adapter (`StorageAdapter` in `runtime/uo-store/src/storage.rs`, in
memory or in files). The runtime names to it every record it opens and
hands it every record it seals, and the adapter logs the read with the
record it keeps and the write with the class it computes from the record it
kept and the one it is handed (invariant 18 of
[`runtime/secret-state.md`](./runtime/secret-state.md)).

`results/storage_boundary.json` runs every benchmark on every sealed
backend, 14 pairs and 47 calls, and compares the adapter's log of each call
with the call's trace:

- The adapter's writes are the trace's writes of sealed objects, one for
  one and in order (4,395), and the adapter classifies each as an `Update`.
- The adapter's reads of each sealed object are the trace's reads of it,
  one for one and in order (3,862 over the 47 calls): every slot of an
  exact object (a cell, an array, a full-scan map), where the call loads
  it; and the counter and the metadata pages of a Path ORAM map, where the
  call loads the map, then the buckets of each access. The runtime holds
  the counter and the pages through the call, and no access reads them
  again.

So the adapter sees every read the trace names and no other: what crosses
the boundary is the trace's physical reads and writes, and the leakage
claim, which is about the trace, covers it. The modeled cost charges the
reads that cross. Until Issue 57 of the external review the trace named a
map's counter and metadata pages again at every access of the local scheme
(and on the tree the counter at every node access and the pages at every
operation), 4,517 reads over the 47 calls, and the cost charged a call that
makes several accesses to a map of the local scheme up to twice the bytes
it reads (103,680 against 51,712 for ERC20Lite `transferFrom`). This
comparison is empirical, over the benchmarks; the places where a record
crosses are source-frozen (`sealed_records_cross_the_storage_boundary` in
`runtime_boundary_validation.json`, and three scenarios of
`tamper_validation.json`), and so are the places where the trace names a
Path ORAM map's reads and the read bound that counts them
(`oram_reads_are_traced_where_the_call_reads_them`). No Lean statement is
about the adapter.

A call's records are pending in the adapter until the call is committed there,
with the commit metadata: the commit's generation, the freshness counters,
whether the contract is initialized, the digest of the public state and the
reservation of each key, under a tag whose key derives from the master
secret. A key's reservation is the count below which its seals may have been
used. Every commit reserves what a call from the state it leaves can seal
(`reservations_ahead` in `runtime/uo-evm/src/store_meta.rs`), and the adapter
makes the reservations durable with the commit. A call writes no
reservation: it starts only if the last commit's cover it, and in a call the
adapter takes a sealed record only below the last commit's reservation of
its key. A call that is dropped leaves the adapter's records as they were,
and each key's seal count at a value that its count before the call fixes,
so that the next nonce shows nothing of how far the dropped call got
(invariant 19 of [`runtime/secret-state.md`](./runtime/secret-state.md),
`dropped_calls_leave_fixed_seal_counts`). The last commit reserved that
value before the call began, so a restart after a crash in the middle of a
call resumes there too. A call from it needs a reservation that the last
commit did not make: the instance commits it, with no record, before the
dropped call's error returns. No entrypoint can seal 2^32 records under one
key in a call, which the compiler, `uo-check`, and every deployment and
restart check from its commit and load operations.

A restart resumes each key at the reservation that the commit metadata it
verified names, and refuses a store whose files name another. The restarted
instance takes no call until it resumes (`resume`): with the platform's
counter at the generation of the store it restarted from, it commits, with no
record, the reservations its first call needs. So every count a call seals is
below a reservation that a commit made before the call began, and the counter
attests that commit before the call (below): a restart, which takes no store
behind the counter, resumes every key above every count a call used, and
repeats no nonce. Until Issue 68 of the review of 16 November 2026 a
reservation was an untagged journal entry that a call made as it began, so
neither the tag nor the counter covered it, and files with a lowered or
older reservation were taken (`restarts_resume_at_the_reservations_of_their_commit`
in `runtime_boundary_validation.json` freezes the scheme). Tagging the
reservation a call makes as it begins would not do: the counter advances only
between operations, so it cannot attest such a reservation before the call
hands over records sealed under it, and a host that stopped the enclave in
that call and restarted it from the files before the reservation, which the
counter still attests, would get a runtime that seals under counts the host
has seen. So the maintainer chose to reserve ahead. The maintainer also chose
authenticated reservations over fresh keys at every restart, which would
reseal the whole store at each restart and, since that changes the digest of
the ciphertext store that a receipt names, need a restart receipt in the
runtime and in `DeploymentAcceptance.lean`. The report restarts each
benchmark from files and checks that every key resumes at the reservation of
the last commit, that its reads answer as before and that no nonce repeats.

The generation counts the commits the store holds: the deployment's, each
committed call's, aborted or not, each bulk load's of a diagnostics build,
and each commit of reservations alone. A restart compares it with the
generation that the platform's monotonic counter attests, before it restores
anything. It takes files at that generation or one past it, says which
(`StoreGeneration::Attested` or `StoreGeneration::OnePast`), and refuses all
others. The counter follows the generation: after every operation of an
instance (its deployment, a call, whether it returned a result, which
carries its commit's generation (`ProductionCallResult::generation`), or an
error, a restart and a resume), the deployment advances the counter to the
instance's generation before it releases anything the instance returned or
makes another call (the TEE deployment assumptions). So files behind the
counter are older than a commit whose result was released or whose
reservations a call used, and the counter is never more than one commit
behind the files. Files one past it hold a commit whose result was not
released: a commit whose outcome was unknown (below), or a stop between a
commit and the counter's advance. Until Issue 67 of the review
of 16 November 2026 a restart compared the rollback counter, which a
committed abort leaves where it was, so the files from before an abort
passed for the files after it. The report keeps ERC20Lite's files before a
`transfer` of more than the owner holds, on each sealed backend
(`committed_aborts`): the transfer aborts and is committed, the kept files
are refused with the generation after it, and the files after it are taken
with their own generation and as one past the one before. Every
benchmark's restart is refused with a generation two below the files' or one
above them, and its files from before its last call are refused with the
generation after it (`restarts_check_the_commit_generation` in
`runtime_boundary_validation.json` freezes the check).

The generation counts commits; it does not name them. If the files that
hold a commit whose result was not released are set aside, and the
deployment restarts from the files before it at the attested generation,
its next commit has the same generation; so have the commits of two
instances restarted from the same files. A host that kept two such stores
can restart from either once the counter holds their generation, and so roll
back a call whose result was released, or resume a key below a count that
calls on the other store used, which repeats a nonce. The receipt chain shows
it to a caller who holds a receipt the restarted store does not: the two
stores' last receipts follow the same receipt. A sealed record is
authenticated with its location, not its version, so a record replaced by
an older record of its location is not detected (a digest tree over the
records is Issue 44).

A production deployment restarts from its files in the build a production
runtime uses. It seals its master secret to its platform when it deploys
(`ProductionContractInstance::deploy_with_storage`): ChaCha20Poly1305 under a
key that derives from the platform's sealing key, with the deployment's
request as associated data, so that the secret opens only on that platform
and only for that deployment (the TEE deployment assumption
`platformSealing`). Every commit leaves the receipt the deployment issued
last in the tagged commit metadata. A restart
(`ProductionContractInstance::restart`) takes the sealed secret and the
attested generation. It is refused unless the secret opens, the metadata
carries the secret's tag, its generation is the attested one or one past it,
each key resumes at the reservation the metadata names, and the receipt it
finds ends in the state the store holds: the public state and the digest of
every sealed record. Once it resumed, its next receipt follows that one
(`production_deployments_restart_from_a_sealed_secret`). A seeded deployment,
which exists in test and diagnostics builds, restarts from its seed.

A store in files fails closed. An append to its journal can fail because its
write stopped part way or because its sync failed after a whole write. Either
way the files hold the entry whole or not at all, and only opening them again
shows which. The adapter's error then says that the outcome is unknown
(`StorageFailure::OutcomeUnknown` in `runtime/uo-store/src/storage.rs`), and
the adapter refuses every operation, naming why, until its directory is
opened again. Nothing lands behind the failed entry, and the runtime refuses
every call, and a production runtime refuses to tag its last receipt. A call
whose commit met that error returns it and no receipt. A checkpoint that
fails at any step (the snapshot's write, its rename, or the journal's
truncation) leaves every commit in the files, because the snapshot replaces
the one in place before the journal is emptied. The call whose commit ran the
checkpoint has committed and returns its receipt, and the adapter then
refuses every operation as well. Opening the files cuts off a last entry that
an append left cut short, and reports how many bytes it cut. It refuses a
journal in which a whole entry follows a damaged one, which only an append
after a failed one leaves. The maintainer chose this contract over one in
which the adapter, after a failed append, cuts the journal back to its last
entry or appends an entry that cancels the commit, syncs, and goes on. That
contract has more states, and its certainty that the call failed rests on a
sync after a failed sync, which not every file system honors; a storage
error is rare enough that a restart is a fair price for it.

A restart from the files resolves a call whose outcome is unknown. Its last
receipt is either the call's, which follows the receipt the caller held and
names the evidence it sent, or the receipt the caller held
(`resolve_production_call_outcome`). The platform's counter holds the
generation of the last result the runtime returned. The files hold that
generation when the call's commit is not in them, and the restart says
`Attested`; they hold the next one when it is, and the restart says
`OnePast`, and the deployment advances the counter to it before it releases
the call's resolution or anything else the instance returns, and before the
instance resumes. In Issue 67 the maintainer chose this catch-up over a
restart that takes the attested generation alone, which would refuse the
files of a call that committed and returned no result.

Both runtimes are made to meet every failure a file store can meet: each way
the append of a commit fails, and each step of a checkpoint
(`StorageFault::ALL`, 7 failures), at each of the two commits a call can
make: its own, and the commit of no record that a call dropped after it ran
makes before its error returns. `fault_matrix` in `storage_boundary.json`
runs them on each sealed backend of ERC20Lite, 42 cases. The call is a
`mint`, and the dropped call an `approve` with no commit budget. The
production build runs them through the production runtime, which resolves
each call by its receipts
(`every_storage_failure_fails_closed_and_a_restart_resolves_the_call` in
`runtime/uo-evm/tests/production_boundary.rs`). In every case:

- no call returns after a failed append;
- every commit that returned is in the files;
- the commit that met the failure is in them whole or not at all;
- a restart with the generation of the instance's last commit that returned
  finds the files at it, or one past it when they hold the commit whose
  append failed, and says which; of the generations around it, it accepts
  the files' own and the one below; and, resumed, it answers reads as the
  state the files hold says.

For example, a `mint` on the local Path ORAM scheme whose commit's write
stops in its payload returns an error whose outcome is unknown. The next open
cuts off the 7,861 bytes it wrote. The generation of the last commit that
returned is 2: the restart with it finds the files at it, and a restart
with 3 is refused. When the sync fails after a whole write instead, the
files hold the `mint` at generation 3, and the restart with 2 takes them as
one past it. On that backend the commit of no record after a dropped
`approve` is 431 bytes. Only a test or a diagnostics build can make
the store fail (`store_failures_are_injected_only_in_test_and_diagnostics_builds`
in `runtime_boundary_validation.json`).

### The Kernel's Operators

The observer has no timing component, and CPU-time obliviousness is a
non-claim (see Non-Claims). Below that boundary the confidential kernel's
operators are still written not to branch on an operand. A 256-bit
subtraction is a borrow chain, less-than is the borrow of a subtraction,
equality and the zero test fold the limbs or the bytes, division makes its
256 rounds with a masked subtraction and masks a zero divisor, the boolean
operators do not short-circuit, and an array index is converted by a mask
(`crates/uo-core/src/types.rs`, and `eval_confidential_kernel_binary_generated`
in the Lean-generated kernel). A differential test keeps the operators'
values: it runs the implementations they replaced beside them on random and
edge operands.

The evidence is of two kinds, and neither is a claim about machine code:

- Source text. `kernel_operators_do_not_branch_on_operands` in
  `runtime_boundary_validation.json` holds when none of those operations
  has a token of a branch, an early return or a short-circuit, and the
  kernel's evaluator uses them and no operator that has one. The Lean
  implementation interface pins the same text, and two tamper scenarios, a
  short-circuit `and` and a remainder that returns early for a zero divisor,
  are rejected.
- Instruction counts of one build. `results/kernel_operator_instructions.json`
  (`scripts/measure_kernel_operator_instructions.sh`) counts, under
  callgrind and in a release build, the instructions the slot interpreter
  executes for one evaluation of each operator: 14 operators on 256-bit
  operands in 13 classes (zero or not, equal or not, the limb in which the
  operands first differ and which is larger, a borrow through every limb), 4
  on booleans, and the index conversion. Every operator has one count
  whatever the class, and the counts repeat. Before the change 8 of the 19
  had more than one: division and remainder took from 462 to 16,136
  instructions, since a zero divisor returned early, where they now take
  16,646 and 16,654; the four comparisons had two counts each; and so had
  `and` and `or`, which short-circuited.

A compiler may still emit a branch for a comparison or a select. The count
shows that this build's code runs the same number of instructions for those
operands; it shows nothing about cache or branch-predictor state, about
another compiler or target, or about the rest of a call. One operation of
the kernel still depends on an operand: indexing an array value, such as a
struct field that is an array, reads the element at the index and fails on
an index out of range (`eval_confidential_kernel_array_index_generated`).

### The Modeled Cost

The public gas of a confidential entrypoint is a function of its schedule,
fixed when it is compiled (cost model `uo-modeled-resource-cost-v3`):

```text
2000 + 11·statements + 7·expressions + 29·max_load_ops + 29·max_commit_ops
```

`max_commit_ops` bounds the sealed records a call writes: each slot of each
exact object the entrypoint may write (`may_write_objects`), and the
counter, the metadata pages and the path of each access of an ORAM map.
`max_load_ops` bounds those it reads: each slot of each exact object it
loads, once; and for each ORAM map it loads, the counter and the metadata
pages, once, and the path of each access. The count is what a call does:
it opens each slot of an exact object it accesses once, when it loads the
object, and a map's counter and metadata pages once, when it loads the
map; the trace records each read there, and neither an access nor the
commit opens one again. An access opens its path. A call that aborts keeps
what it loaded and reseals that. A confidential call loads the objects its
kernel program schedules, and a public one the objects its body accesses.
On the private scheme the commit bound counts the metadata pages once per
node access, where a call writes them once per operation, so there it is a
bound and not a count. Model v1 charged the writes alone, so a call that
only read would have cost about 2,000 units whatever it read. Model v2
counted a Path ORAM map's counter and metadata pages again at each access,
where the trace named them and no access read them, so it charged a call
that makes several accesses to a map of the local scheme up to twice the
bytes the call reads; model v3 counts each read once (Issue 57 of the
external review).

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

### The Backend Planner

A confidential map may leave its backend to the compiler. Its metadata says
`backend: auto` and may declare the share of its operations that read and
the enclave memory a call may hold for it:

```yaml
records:
  kind: map
  key: bytes32
  value: uint256
  capacity: 4096
  backend: auto
  confidential: true
  plan:
    read_percent: 90                     # 50 if absent
    enclave_memory_budget_bytes: 1048576 # no limit if absent
```

The planner (`uo_core::backend_plan`, model `uo-backend-plan-v1`) reads
these, the capacity and the widths of the map's keys and values, all of
them public. For each backend that can hold the map (the full scan, the
local Path ORAM scheme up to 128 entries, and the private scheme; a Path
ORAM map takes scalar keys and values) it models the bytes of the sealed
records that a call moves when it reads the map once and when it writes it
once, and the enclave memory a call holds for the map. It takes the backend
that moves the fewest bytes per call at the declared share of reads, among
those that fit the budget. Ties go to the full scan, then to the local
scheme, and a map that no backend fits does not compile. With the metadata
above, a read of the full scan moves 393,216 bytes and a write 786,432; a
read of the private scheme moves 334,208 and a write 1,220,256. At nine
reads in ten the full scan moves 432,537.6 bytes per call and the private
scheme 422,812.8, so the map goes on the private scheme. At the default of
half reads the full scan moves 589,824 and the private scheme 777,232, and
the map stays on the full scan. Both fit the budget: the model gives the
full scan 925,696 bytes of enclave memory and the private scheme 66,174, so
a budget of 512 KiB would put the map on the private scheme at any share of
reads.

The manifest records the plan in the map's entry (`plan`: the inputs, each
backend weighed with its bytes and memory, and the choice). `uo-check`
plans the map again from the recorded inputs and rejects a manifest whose
plan differs and a map that is not on the backend its plan chose. The Lean
checkers read a planned map as any other. The plan decides the map's route,
and the route's claims are those of Backend Scope: a map the planner puts
on Path ORAM has the Path ORAM route's claim, not exact UO.

The model is tested, not proved (`results/matched_baselines.json`). Three
maps, with 32-byte keys and values, with 20-byte keys, and with 1-byte
values, are compiled on each backend at seven capacities from 16 to 16,384
entries. Which backends can hold a map follows from the grid: a Path ORAM
scheme holds scalar keys and values, and the local scheme at most 128
entries. Every cell that can must compile and run, and every other one
must be rejected with the compiler's diagnostic for its rule; the planner
must exclude exactly those. A measured cell is filled to two keys and, up
to 1,024 entries, to half and all of its capacity, and called: a read of a
stored key and of an absent one, an overwrite and an insert. Every call
moves the bytes the model gives its backend, whatever the occupancy and
whether its key is stored. At six shares of reads the planner chooses the
backend whose measured calls moved the fewest bytes, and every backend
that can hold the map is measured before they are compared, so a
competitor that went missing fails the report even if it would have lost.
Each map compiled with `backend: auto` records the plan the planner makes,
is on the backend it chose, moves the bytes of its model and reads back
what it wrote: at the default share, at nine reads in ten, and within a
budget halfway between the full scan's modeled memory and the private
scheme's, which excludes the larger of the two. That is both Path ORAM
schemes up to 128 entries and the full scan from 1,024, so from 1,024 to
4,096 entries, where the planner puts a map on the full scan at the default
share, the budget puts it on the private scheme. With a budget that no
backend fits, the map does not compile. The report's counts of cells,
calls, planner checks and planned maps are the grid's. Two tests check the
report itself: on a small grid it meets every verdict, and when a backend
that can hold the map is made to fail to compile, the report fails. The
model also gives the bytes of each of the 1,141 calls the capacity sweep's
full profile measured for SweepMap, on every backend and at every capacity
from 1 to 16,384 entries and every occupancy, deletes and aborted writes
among them
(`the_model_gives_every_call_the_full_sweep_measured`), and the planner
chooses there what the sweep measured to move the fewest
(`the_planner_chooses_what_the_full_sweep_measured_least`).

What the planner does not do: it minimizes bytes, a model of the traffic
between the enclave and its storage, and not time, which the capacity
sweep measures. Its enclave memory is modeled from the sealed records and
the plaintext a call holds for the map, at their canonical widths, and not
measured; it leaves out the runtime's other buffers, so a budget bounds
that model and not the enclave's heap. Its model call reads the map once
or writes it once, so for an entrypoint that accesses a map several times
it makes no claim of which backend moves the fewest bytes. And the share
of reads is the one the metadata declares: the planner does not derive it
from the program, whose entrypoints say what a call may do and not how
often it is made.

## Explicit Assumptions

| Assumption | Role | Current treatment |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides Path ORAM bucket/path ciphertext contents | trusted; named in Lean and not formalized (see below): a `Prop` field of `PathOramLocalPosmapV1SecurityAssumptions`. Its provenance is the runtime `ChaCha20Poly1305` sealed-record boundary plus the cited AEAD analysis route. That route needs a nonce to seal once under a key: a record's nonce is the count of the seals under its key (`sealNonceRun_nodup` in `UOToolchain/RuntimeStoreCodecSemantics.lean` for a model of the counter; `seal_nonces_come_from_the_seal_count` in `runtime_boundary_validation.json` for the source) |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages | trusted; named in Lean and not formalized, as the row above, and paired with the same concrete sealed-record crypto route |
| `stashOverflowBounded` | bounds Path ORAM stash failure for deployed parameters | trusted; named in Lean and not formalized, as the first row, and paired with the JACM Path ORAM stash theorem at `Z = 5` and pinned deployed parameters: a cap of 152 blocks, for at most `2^-60` over `2^48` node accesses of a map. For the private scheme it also assumes that operations which hold their nodes until they end keep the theorem's tail, which a simulation of ten million node accesses measures and does not prove |
| Runtime key derivation | gives each object a storage key, an initial placement and Path ORAM leaf coins that are pseudo-random and independent of the other objects', which the two encryption assumptions and the leaf-coin model take as given | trusted, not modeled in Lean: a 256-bit master secret from the OS, HKDF-SHA256 (RFC 5869) with one label per use, and the ChaCha20 generator. `runtime_secrets_derive_from_the_master_secret` in `runtime_boundary_validation.json` pins the derivation's call sites, and `runtime/uo-evm/src/secret.rs` tests the RFC's first test vector |
| Return-channel AEAD | hides a value returned under `encrypted_to_client` from the host. The theorems erase the payload's ciphertext and tag as a declared release, so what those bytes show of the value is in no Lean statement | trusted, not named in Lean: `ChaCha20Poly1305` under the session key, with the associated data and the nonce that `runtime/uo-evm/src/return_channel.rs` builds. The nonce is the first 96 bits of a hash of the runtime's freshness epoch, rollback counter and call counter, the session binding and the hash of the associated data, so two calls of a deployment seal under different nonces unless those 96 bits collide. That the session key is fresh and known to the client alone comes from the attested key exchange of the deployment, which the repository does not implement (the TEE deployment row) |
| Production receipt MAC | lets the holder of a session conclude from a receipt's tag that the runtime issued the receipt as it is | trusted, stated in Lean as the two hypotheses of `deployment_receipt_tag_verifies_issued` in `UOToolchain/DeploymentAcceptance.lean` and not proved, both about what an adversary of the session can output: HMAC-SHA256, under a key that HKDF-SHA256 derives from the session key and id, is unforgeable against it, so a receipt and a tag it outputs whose tag verifies have the hash of an issued receipt (`UnforgeableAgainst`); and it outputs no receipt but an issued one with the SHA-256 hash of an issued receipt (`HashBindsIssued`). Both hold in a model in which the runtime did not issue a receipt the adversary outputs (`deployment_receipt_tag_assumptions_not_vacuous`). The session key comes from the attested key exchange, as in the row above |
| TEE deployment assumptions | enclave memory confidentiality/integrity, attestation authenticity, rollback resistance (a monotonic counter that follows the store's commit generation: after each operation of an instance, a call that returned or failed, its deployment, a restart or a resume, the deployment advances it to the instance's generation before it releases anything the instance returned or makes another call, and a restart takes it as the attested generation), freshness, crash recovery discipline, patch-level trust, platform sealing (the sealing key a production deployment seals its master secret under derives only in the same enclave on the same platform) | explicit Lean bundle `SgxDeploymentAssumptions`, paired with Intel SGX provenance and probe drift checks |
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
  `stashOverflowBounded` names: at most `14 · 0.6002^152 < 2^-108` at the
  deployed parameters, by the cited theorem, so `Q · ε_stash` is at most
  `2^-60` for the `2^48` accesses the cap budgets for a map. `Q` counts
  primitive accesses, not calls: a private-scheme write at 16,384 entries
  makes 77 node accesses. An overflow is an error that drops the call: the
  host learns that it happened, and the map loses nothing.

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
| Rust runtime kernel plus witness/certificate/bundle extraction and serialization | trusted implementation-side extraction surface; replay and reconstruction reduce but do not eliminate this trust. The position maps of a call's witness are not decoded from the store for each call: the runtime keeps them from call to call and moves them by each call's leaf transitions. Every call of a validation run compares the kept maps with the decode of the whole store, before it runs and after, and fails if they differ; only the calls a measurement times skip that comparison |
| Source-backed runtime implementation boundaries | source-frozen/static-drift evidence, not full Rust semantic refinement. The runtime-to-Lean boundary obligations are classified by evidence kind in `runtime_boundary_validation.json` (`runtime_boundary_obligation_classification`): proof-critical obligations carry a Lean-theorem, generated-schema, executable-semantic-refinement, or source-frozen Rust-visibility kind, while the source-drift regression inventory is regression-only and backs no proof-critical claim. `validate_runtime_boundary_schema` rejects any proof-critical obligation backed only by source regression, so no proof-critical claim rests solely on a Rust source substring outside this source-frozen surface |
| Rust code outside the tiny confidential kernel | not part of the confidential-work TCB when pinned to public-only or generated-helper routes |
| Fixed-capacity Rust buffer helpers | safe `Vec`-backed wrappers; no production `unsafe` or `MaybeUninit` surface remains in `fixed_buffer` |
| `uo-solc` | not trusted as a proof oracle for accepted artifacts; parser/preprocessing remains trusted |
| `uo-check` | diagnostics/debug wrapper, outside the proof-grade TCB |
| `mplus-probe` | orchestration and reporting, outside the proof-grade TCB |

## Related Work

The techniques below are not claimed as new here. This repository combines
them for a contract runtime's storage and checks the combination as the
sections above state.

- Ciphertext side channels. A host that sees a TEE's encrypted memory can
  tell when the ciphertext at a location changes, and so when its value
  does (CipherLeaks, on AMD SEV: Li, Zhang, Wang, Li and Cheng, USENIX
  Security 2021). The known defense makes every store of a secret fresh: by
  binary instrumentation that masks secrets before they are stored
  (Cipherfix: Wichelmann, Pätschke, Wilke and Eisenbarth, USENIX Security
  2023), or in the compiler, by probabilistic encryption with decoy
  accesses (CipherGuard: Jiang, Deng, Li, Wang, Zhang and Zhang, arXiv
  2502.13401) or by interleaving secrets with fresh values, which also
  defeats silent stores (Zebrafix: Pätschke, Wichelmann and Eisenbarth,
  RAID 2025). Here every sealed record is written under a fresh nonce and a
  call rewrites a fixed set of records whatever it changes (The Storage
  Boundary); the idea is theirs.
- Oblivious RAM and oblivious data structures. The local scheme is Path
  ORAM (Stefanov, van Dijk, Shi, Fletcher, Ren, Yu and Devadas, CCS 2013)
  with a flat position map. The private scheme keeps a map as an AVL tree
  whose nodes hold their children's leaves, so that the position map
  recurses through the tree: the oblivious data structures of Wang, Nayak,
  Liu, Chan, Shi, Stefanov and Huang (CCS 2014).
- Oblivious maps in enclaves. An ORAM client in the enclave whose own
  accesses are oblivious is ZeroTrace's design (Sasy, Gorbunov and
  Fletcher, NDSS 2018), and a doubly oblivious AVL tree in an enclave is
  Oblix's (Mishra, Poddar, Chen, Chiesa and Popa, IEEE S&P 2018). EnigMap
  (Tinoco, Gao and Shi, USENIX Security 2023) is an oblivious map for
  enclaves built for maps larger than enclave memory, whose cost is the
  pages it moves in and out. The maps here are smaller, and their baselines
  are this repository's own backends, compared at the same key and value
  widths, capacities and occupancy, with the enclave memory the planner's
  model gives each, which is not measured (The Backend Planner); no external
  system was run.
- Leakage as a structured trace. Stating what a run may leak as a trace,
  and proving that compilation keeps it, is the approach of structured
  leakage (Barthe, Grégoire, Laporte and Priya, CCS 2021). The observer, its
  declared releases and the translation validation here are instances of
  it, not a new notion.

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
- the detection, at a restart, of a store that was rolled back together
  with the attested generation, of two stores that a generation names (a
  commit whose result was not released, set aside by a restart from the
  files before it, or two instances restarted from the same files), between
  which a restart can roll back a released result or resume a key below a
  count the other store's calls used, or of a store that holds an older
  record of a location (see The Storage Boundary)
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
does not exist: a source, Lean or runtime file, or a result file that a claim
cites. `scripts/run_validation.sh` regenerates it.
