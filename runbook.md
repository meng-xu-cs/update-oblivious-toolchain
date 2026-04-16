# One-shot handoff runbook for Codex: build the UO Toolchain

This runbook is for a local coding agent (`codex`, GPT-5.4, xhigh reasoning) that must build a research-grade but real **Update-Oblivious toolchain** for Solidity and a corresponding **UO-EVM** runtime.

It is written to be **self-contained**. You may consult these reference documents for context, but do not rely on them for requirements that are not restated here:

- `pilot-paper.md`
- `draft-v1.md`

## Status note

This file started as a build-plan handoff. The repository has since
implemented much of that plan, so parts of this runbook are now historical.
The current repository should be read with these adjustments:

- the runtime executes compiled artifact JSON in-process today; "deployment" is
  a future confidential-runtime/TEE target, not direct public-chain bytecode
  deployment
- `path_oram_local_posmap_v1` is the only theorem-facing ORAM path; the legacy
  surrogate backend should be treated as benchmarking/compatibility-only
- the strengthened assurance path is not "formally verify every Rust module"
  up front; it is: checker-side translation validation, runtime-to-Lean
  refinement, and discharge of the frozen imported standard Path ORAM theorem
- the two theorem routes are equivalent at the frozen interface; the
  current paper choice is to use the citation route at that interface, while
  keeping the self-instantiated theorem object only as appendix /
  executable-artifact validation and keeping the stronger external-theorem
  import route only as future work
- the repo now also has a dedicated bridge-validation path,
  `./scripts/run_bridge_validation.sh`, for the imported-theorem engineering
  bridge without the full artifact bundle
- the current claim boundary is documented more precisely in
  `docs/formal-proof-plan.md` and `docs/implementation-roadmap.md`; those two
  documents take precedence for proof-grade wording

The final outcome must be an end-to-end toolchain that compiles a restricted but meaningful subset of Solidity into contracts that execute safely on a confidential EVM under the stronger **marker-aware write adversary** `M+`.

---

## 0. Paste-this mission block to Codex

Build a research prototype called **The UO Toolchain** with the following components:

1. **`uo-solc`**: a Solidity compiler/rewriter for a restricted subset of Solidity.
2. **`uo-evm`**: a confidential EVM runtime that executes the compiled contracts with update-oblivious state handling.
3. **`uo-check`**: a static checker/linter that rejects unsupported or unsafe code and validates the compiler output.
4. **`mplus-probe`**: a differential leakage-testing harness for the `M+` adversary model.
5. **`benches/`**: a representative Solidity benchmark suite with both raw and UO-transformed versions.
6. **`results/`**: reproducible correctness, security, and overhead reports.

Non-negotiable security goal:

For any two executions that have the same public inputs and differ only in secrets, the adversary must not learn secrets from:

- control-flow shape,
- logical address access pattern,
- persistent-state update class at a fixed location,
- public gas usage,
- cleanup/allocator behavior,
- or backend-visible zero/non-zero / same-vs-changed effects.

Use the following engineering target wherever possible:

> **After public initialization, every confidential-path physical write emitted by the runtime should be a rerandomized nonzero→nonzero write, i.e. physical class `UPDATE`, never `SET`, `CLEAR`, or `SAME`.**

Do not chase broad language coverage. Prefer a **restricted but sound** subset that covers the benchmark suite and can make a credible end-to-end UO claim.

If a feature cannot be shown safe under this model, reject it with a clear diagnostic.

---

## 1. What “Update-Oblivious” means here

### 1.1 The adversary

Assume a stronger observer `M+` that, at a fixed observable location, can distinguish four update classes:

- `SET`: `0 -> nonzero`
- `CLEAR`: `nonzero -> 0`
- `SAME`: `old == new` including `0 -> 0`
- `UPDATE`: `nonzero X -> nonzero Y`, `X != Y`

The adversary may also observe:

- public control-flow shape,
- logical storage/page/object addresses,
- public gas usage,
- backend metadata such as zero/unmapped state,
- write counts,
- allocator/free behavior,
- and same-location ciphertext equality or change.

### 1.2 Security target

For a compiled UO contract running on UO-EVM, and for any two runs with the same public inputs and same public initial state but different secrets, the adversary-visible behavior must be independent of secrets.

In this project, that means all of the following must hold:

1. **No secret-dependent control flow** after transformation.
2. **No secret-dependent logical address schedule**. Secret-indexed state must use either full scan over a public capacity or an ORAM backend.
3. **No secret-dependent update class at the backend**. Marker-aware write classes must be equalized.
4. **No secret-dependent public gas usage**. Gas must be padded/equalized per entrypoint.
5. **No secret-dependent allocator or scrub behavior**. Never zero/free in a way that leaks marker transitions.

### 1.3 Exact vs computational UO

Use two security tiers and be explicit about which one each backend achieves.

- **Exact UO**: for cells, fixed arrays, and full-scan bounded maps, the relevant normalized trace must be exactly identical across secret variations.
- **Computational UO**: for ORAM-backed large maps, the physical access pattern may be randomized, but it must not leak anything beyond the intended ORAM transcript. In addition, the `M+` update-class shape of each physical write must still be secret-independent.

Do not claim exact trace equality for an ORAM backend unless you actually achieve it.

### 1.4 Operational target

For the prototype, aim for the following stronger invariant:

- all confidential-path physical state regions are **preinitialized with nonzero filler**,
- all logical values are encoded as **marker-free nonzero physical records**,
- every physical write is **rerandomized** so it does not become `SAME`,
- and every confidential operation emits a **public-determined physical write budget**.

If this invariant is achieved, the physical backend should only see public-determined sequences of `UPDATE` writes.

---

## 2. What you are allowed to claim

Aim for a strong claim, but do not overclaim.

You may claim that the toolchain provides update-oblivious execution for the supported language subset with respect to:

- the instrumented abstract machine,
- the UO runtime’s storage/memory/allocator interfaces,
- and the measured end-to-end runtime traces on the benchmark suite.

Do **not** claim a universal proof about every layer of Rust-generated machine code or every microarchitectural observer unless you actually build that proof.

The goal is a **credible security systems artifact**, not an unverifiable blanket statement.

---

## 3. North-star deliverables

The project is complete only when all of the following exist and work together.

### 3.1 `uo-solc`

A compiler/rewriter that:

- accepts a restricted Solidity subset,
- requires explicit secrecy and capacity metadata,
- performs **semantic write linearization (SWL)**,
- rewrites persistent-state operations into UO runtime calls,
- normalizes abort/revert behavior,
- outputs a compiled artifact plus a machine-readable manifest.

### 3.2 `uo-evm`

A confidential EVM runtime, preferably based on an embeddable interpreter, that:

- executes the compiled contracts,
- routes all confidential persistent state through `UO-Store`,
- exposes a small UO precompile/system-call ABI,
- equalizes public gas per entrypoint,
- uses a non-leaky allocator/scrub strategy,
- can emit instrumented traces for proof/testing,
- and uses fixed-size preallocated work buffers for supported entrypoints.

### 3.3 `uo-check`

A checker that:

- rejects unsupported constructs,
- verifies public bounds/capacities,
- ensures no raw confidential stores escape the UO substrate,
- checks that compiler output obeys required invariants,
- and emits a certificate/report per compiled contract.

### 3.4 `mplus-probe`

A leakage harness that:

- runs paired experiments differing only in secrets,
- collects exact abstract traces and host-proxy metrics,
- computes trace diffs, AUC, and mutual information,
- confirms that raw contracts leak and UO contracts do not.

### 3.5 Benchmark suite

A small but representative benchmark suite with both raw and UO variants, plus scripts that produce a paper-ready results bundle.

---

## 4. Recommended architecture

### 4.1 Preferred stack

Use this unless there is a compelling reason not to.

- **Language/runtime:** Rust
- **EVM base:** `revm`-style embeddable interpreter or equivalent Rust EVM
- **Compiler strategy:** source-to-source or AST-to-UO-IR transform over a restricted Solidity subset
- **Runtime interface:** reserved **UO precompiles** or equivalent system-call ABI
- **State runtime:** `UO-Store` plus full-scan and ORAM-backed container implementations
- **Analysis:** Rust checker plus small helper scripts in Python only where necessary

### 4.2 Why this architecture is preferred

It gives you:

- a single implementation language for runtime and tooling,
- a tractable way to make state access explicit,
- clean separation between source transformation and runtime policy,
- and easy instrumentation for exact trace checking.

### 4.3 Architecture options and priorities

#### Compiler lowering target

Priority order:

1. **P0:** Solidity AST / restricted source-to-source transform.
2. **P1:** Yul / Solidity IR transform if source rewriting becomes too brittle.
3. **P2:** bytecode-to-bytecode transform only as a last resort.

Do **not** start with bytecode rewriting.

#### Runtime integration

Priority order:

1. **P0:** UO precompiles or system calls, with compiled contracts using those explicitly.
2. **P1:** special opcodes.
3. **P2:** implicit interception of raw `SLOAD`/`SSTORE` based on storage-layout guessing.

Do **not** start with implicit interception.

#### Large-map backend

Priority order:

1. **P0:** exact-UO full-scan map for small public capacities.
2. **P1:** generic ORAM backend for larger capacities.
3. **P2:** write-only ORAM optimization once correctness is established.

#### Annotation format

Priority order:

1. **P0:** sidecar JSON/YAML manifest checked into the repo.
2. **P1:** NatSpec-style source annotations once the system is stable.

A sidecar manifest is acceptable for the first complete version.

---

## 5. Supported language subset

You are not building all of Solidity. You are building a **sound, benchmark-covering subset**.

### 5.1 Must-support features

Support these first:

- `bool`, `uint{8,16,32,64,128,256}`, `bytes32`, `address`
- fixed-size structs of supported scalar fields
- fixed-size arrays with public length known at compile time
- `if/else`
- bounded `for` loops with public max bound
- internal function calls
- pure/view helper functions
- arithmetic and comparisons on fixed-size scalars
- `keccak256` on fixed-size buffers if needed by benchmarks
- explicit confidential entrypoints with fixed-size calldata

### 5.2 State forms to support

Support these storage abstractions:

- `UOCell<T>` for scalars and fixed-size records
- `UOArray<T, N>` for fixed public-size arrays
- `UOMap<K, V, CAP>` full-scan backend
- `UOMap<K, V, CAP, ORAM>` large-map backend

### 5.3 Must-reject features

Reject with clear diagnostics:

- inline assembly / raw Yul in user contracts
- dynamic arrays without a public hard bound known to the compiler
- dynamic `bytes`/`string`
- unbounded `mapping` without declared public capacity and backend
- recursion without a public hard bound
- `delegatecall`, `callcode`, `create`, `create2`, `selfdestruct`
- external calls except to explicitly whitelisted UO/runtime precompiles
- logging/events in confidential paths
- secret-dependent revert strings or custom errors
- raw storage ops that bypass the UO runtime
- secret-dependent memory allocation sizes

### 5.4 Default policy

When uncertain, **reject rather than guess**.

---

## 6. Core design rules that must hold

These are the core UO invariants. The checker and runtime must enforce them.

### Rule 1. Marker-free physical encoding

Never physically materialize logical zero as all-zero backend data on a confidential path.

Logical zero must be encoded as a nonzero physical record, for example by:

- a nonzero sentinel plus status bit, or
- an encrypted/tagged record format whose entire physical block is nonzero.

### Rule 2. Preinitialize confidential regions with nonzero filler

All confidential state regions must be preallocated or initialized with nonzero filler before confidential execution begins.

Target property:

- after initialization, confidential execution should never emit backend `SET` or `CLEAR`.

### Rule 3. Fresh or rerandomized writes only

Do not allow same-location same-payload rewrites that would become physical `SAME`.

Every physical write must be rerandomized or redirected to a fresh logical version so the backend sees `UPDATE`, not `SAME`.

### Rule 4. Constant write budgets

Every entrypoint must have a public write/read budget. Fewer logical operations must be padded with dummy operations or semantically safe rerandomized rewrites.

### Rule 5. Address obliviousness

If a lookup key is secret, the access pattern must be hidden using either:

- a full deterministic scan over a public capacity, or
- an ORAM backend.

### Rule 6. Metadata is data

Metadata must obey the same UO invariants as values. Do not let version counters, occupancy bits, allocator freelists, tombstones, or GC metadata leak `SET/CLEAR/SAME/UPDATE`.

### Rule 7. Semantic scrubbing only

Never implement secret cleanup as raw zeroization or secret-dependent free.

Use a semantic wipe operation that writes fresh nonzero scrub data, retires metadata, and reclaims on a public schedule.

### Rule 8. Abort normalization

Secret-dependent reverts are forbidden as an observable control channel.

Compile them into an `aborted` flag plus a constant commit schedule:

- if logically aborted, commit dummy or semantically null writes only,
- if logically successful, commit the staged writes,
- but in both cases the public schedule and gas must match.

### Rule 9. Fixed work buffers

For supported entrypoints, the runtime must preallocate fixed-size work buffers for:

- EVM stack representation,
- transient memory arena,
- journaling buffers,
- scratch buffers for hashing/ABI,
- and UO operation tapes.

No dynamic reallocation during a confidential entrypoint.

---

## 7. Concrete repository layout

Use a layout close to this.

```text
uo-toolchain/
  compiler/
    uo-solc/
  runtime/
    uo-evm/
    uo-store/
    uo-precompiles/
    uo-allocator/
  checker/
    uo-check/
  probe/
    mplus-probe/
  benches/
    raw/
    uo/
    harnesses/
  results/
  docs/
  scripts/
```

If you prefer a monorepo workspace, use it.

---

## 8. Required compiler behavior

### 8.1 Semantic write linearization (SWL)

The compiler must transform secret-tainted control flow into predicated straight-line or bounded-loop code.

Use the standard pattern:

- derive block predicates,
- keep executing blocks in a public-determined order,
- replace assignments and writes with predicated assignments.

For this project, it is acceptable to linearize **all** control flow in confidential entrypoints if that simplifies correctness.

### 8.2 Required transformation rules

#### Conditional assignment

Source:

```text
if (secret) x = a; else x = b;
```

Target shape:

```text
p = secret_predicate;
x = uo_select(p, a, b);
```

#### Predicated store

Source:

```text
if (secret) m[k] = v;
```

Target shape:

```text
p = secret_predicate;
uo_map_put(map_id, k, uo_select(p, v, old_value));
```

or an equivalent staged form that preserves constant schedule.

#### Loops

Source loops must have public upper bounds.

Target shape:

- execute the full public upper bound,
- maintain an `active` predicate if the source loop had an early exit,
- predicate the body effects instead of breaking early.

#### `require` / `assert`

Source:

```text
require(c);
```

Target shape:

```text
aborted |= !c;
```

Any operator that would trap or revert must be rewritten into a safe total form before SWL if necessary.

#### Function calls

Use one of:

- function inlining, or
- function cloning with a synthetic predicate argument.

Priority: **predicate-argument cloning**.

### 8.3 Storage lowering

All confidential persistent state must be lowered into explicit UO objects. The resulting contract bytecode should not directly manipulate raw EVM storage for confidential data.

Practical hard gate:

- compiled confidential contracts should contain **no raw `SSTORE` / `SLOAD` for confidential state**, and preferably none at all.

### 8.4 Runtime manifest

Each compiled contract must emit a manifest like:

```json
{
  "contract": "MixerUO",
  "objects": [
    {"id": 1, "name": "balances", "kind": "map", "backend": "full_scan", "capacity": 32}
  ],
  "entrypoints": {
    "deposit(bytes32,uint256)": {
      "secret_args": [0,1],
      "public_gas_budget": 250000,
      "arena_bytes": 16384,
      "max_stack_words": 128,
      "uocell_reads": 0,
      "uocell_writes": 0,
      "uomap_reads": 1,
      "uomap_writes": 1,
      "max_commit_ops": 4
    }
  }
}
```

Exact schema is up to you, but it must include enough information to preallocate buffers and equalize gas.

### 8.5 Gas budgeting strategy

Use this priority order:

1. **P0:** empirical calibration on transformed code plus exhaustive/random verification that observed cost never exceeds budget.
2. **P1:** static exact budget derivation.

P0 is acceptable for the first complete artifact, as long as the budget is locked into the manifest and then enforced exactly by the runtime.

---

## 9. Required runtime behavior

### 9.1 Two-phase execution model

Implement confidential entrypoints using two phases:

1. **Compute phase**
   - execute transformed code against a transaction-local shadow state and fixed work buffers,
   - accumulate a bounded operation tape or journal,
   - never expose secret-dependent early exit.
2. **Commit phase**
   - execute a public-determined schedule of physical operations,
   - pad with dummy/semantically null operations if needed,
   - consume exactly the public gas budget for the entrypoint.

### 9.2 UO runtime ABI

The runtime ABI must be small and auditable. You need enough operations to support the benchmark suite, at least:

- `uo_begin(entrypoint_id)`
- `uo_cell_get(object_id)`
- `uo_cell_set(object_id, value)`
- `uo_map_get(object_id, key)`
- `uo_map_put(object_id, key, value)`
- `uo_commit(entrypoint_id, aborted)`
- `uo_wipe(region_id)` or allocator equivalent if needed

It is okay if these are implemented as precompiles, a system contract, or host calls.

### 9.3 Runtime internal memory discipline

The runtime itself must avoid obvious `M+` leakage in its own work buffers.

Required policy:

- fixed-size preallocated work buffers per entrypoint,
- nonzero initialization of confidential buffers,
- no secret-dependent buffer growth,
- no zeroization on free,
- public-schedule reclaim only.

### 9.4 Gas equalization

For each confidential entrypoint, `gasUsed` visible to the outside must be exactly the manifest budget.

It is acceptable for the runtime to burn dummy cycles or dummy UO operations to reach the budget.

### 9.5 Deployment model

For P0, keep deployment simple.

Recommended policy:

- public deployment only,
- public constructor parameters only,
- secret initialization handled by an explicit confidential `init` entrypoint if needed.

Do not let deployment-time confidentiality block completion.

---

## 10. UO-Store and UO-Allocator design requirements

This is the substrate that actually kills the `M+` channel.

## Step 1 — Make the threat model executable

### Goal

Create an **instrumented baseline** that can explicitly show the difference between:

- control/address obliviousness, and
- full update-obliviousness under `M+`.

### Work

1. Instrument the chosen EVM base or a minimal reference runtime to emit:
   - opcode trace hash,
   - logical storage access trace hash,
   - exact logical write trace,
   - exact physical write trace with class labels in `{SET, CLEAR, SAME, UPDATE}`.
2. Build a minimal raw leaking benchmark:
   - fixed-slot classifier that writes either logical `0` or `1` to the same slot(s), with fixed control flow and fixed logical addresses.
3. Add a same-same control:
   - two different secrets that both map to the same logical result.

### Explore only if needed

- Option A: instrument the full chosen EVM now.
- Option B: build a small reference interpreter/storage model first, then port the instrumentation.

Priority: **A if straightforward, B if A slows the project down.**

### Success gates

1. The raw fixed-slot classifier shows:
   - identical opcode-trace hash across secret pairs,
   - identical logical-address-trace hash across secret pairs,
   - but different `M+` write trace across `0 -> 0` vs `0 -> 1`.
2. The same-same control has identical `M+` trace.
3. The instrumentation produces machine-readable JSON traces.

---

## Step 2 — Freeze the supported subset and input metadata format

### Goal

Define exactly what source programs are allowed and how secrecy/public-bounds metadata are provided.

### Work

1. Define the accepted Solidity subset from Section 5.
2. Choose annotation format:
   - P0: sidecar JSON/YAML manifest.
3. Support at least these metadata fields:
   - secret/public arguments per entrypoint,
   - secret/public state objects,
   - public loop bounds,
   - map capacities,
   - backend choice (`full_scan` or `oram`),
   - public gas budget per entrypoint, if manually supplied.
4. Implement a validator that rejects unsupported constructs before transformation.

### Recommended metadata schema

A sidecar file like this is enough for P0:

```yaml
contract: ConfidentialMixer
entrypoints:
  deposit(bytes32,uint256):
    secret_args: [commit, amount]
  withdraw(bytes32,uint256):
    secret_args: [secret, amount]
state:
  balances:
    kind: map
    key: bytes32
    value: uint256
    capacity: 32
    backend: full_scan
bounds:
  loops: {}
```

### Success gates

1. All benchmark contracts parse with metadata.
2. At least 20 negative tests exist for unsupported features.
3. Unsupported features fail fast with useful diagnostics.
4. The checker can identify all secret/public inputs used by the benchmark suite.

---

## Step 3 — Define the UO ABI, manifest, and commit model

### Goal

Make all confidential persistent state access explicit and auditable.

### Work

1. Define a small reserved ABI for UO runtime calls.
2. Define the runtime manifest format.
3. Implement the two-phase `begin -> compute/journal -> commit` model.
4. Make the commit phase consume a fixed, manifest-driven schedule.

### Design guidance

Use one of these commit policies:

- **Preferred:** stage logical effects in a shadow state, then commit them under a constant public schedule.
- **Acceptable:** eagerly update a shadow copy of each UO object and still run a fixed commit schedule at the end.

Do **not** mutate backend persistent state directly from raw transformed code.

### Success gates

1. Every confidential entrypoint has a manifest entry.
2. The runtime can reject calls whose observed operation count would exceed the manifest.
3. A dummy benchmark can execute with identical public gas on success and logical abort.
4. The emitted trace contains both abstract operation-tape events and physical write events.

---

## Step 4 — Implement `UO-Store` and `UO-Allocator`

### Goal

Build a storage/memory substrate that enforces the marker-elimination and rerandomized-write discipline.

### Work

1. Define a nonzero physical record format for cells and blocks.
2. Preinitialize confidential regions with nonzero filler.
3. Ensure same logical value written twice still causes a physical `UPDATE`, not `SAME`.
4. Ensure logical zero never causes a physical all-zero backend write.
5. Implement allocator/scrub routines that never emit zero/unmap on confidential paths.
6. Implement at least one reclamation strategy:
   - P0 acceptable: generous overprovisioning plus public-schedule epoch compaction.

### Design options

#### Cells

Priority order:

1. **P0:** rewrite the same fixed physical slot with fresh randomized nonzero encoding.
2. **P1:** append-only logical versions plus public-schedule GC.

The first option is simpler and adequate if rerandomization is correct.

#### Reclamation

Priority order:

1. **P0:** epoch compaction every public `N` operations or every public epoch.
2. **P1:** background-style compaction triggered by public fill thresholds.

Compaction must itself obey the UO invariants.

### Success gates

1. Unit tests show that writing logical zero, nonzero, same value, and different value all produce only physical `UPDATE` after initialization.
2. No confidential-path operation emits an all-zero block.
3. No confidential-path operation emits discard/unmap.
4. Reclamation/GC tests pass without violating the above.
5. The probe can verify that all confidential-path backend writes are classified as `UPDATE`.

---

## Step 5 — Implement UO containers

### Goal

Provide the state abstractions that the compiler lowers to.

### Required containers

1. `UOCell<T>`
2. `UOArray<T, N>`
3. `UOSmallMap<K, V, CAP>` using deterministic full scan
4. `UOOramMap<K, V, CAP>` for larger capacities

### Full-scan map policy

For `UOSmallMap`:

- scan all `CAP` entries on every get/put,
- rerandomize all rewritten entry records,
- encode emptiness/tombstones without physical zeros,
- never reveal whether an insert/update/delete actually happened.

### ORAM map policy

For `UOOramMap`, the backend must hide secret-dependent logical keys.

Priority order:

1. **P0/P1 preferred:** generic ORAM with clear get/put semantics and simpler implementation.
2. **P2:** write-only ORAM optimization once the exact/full-scan path is correct.

Regardless of ORAM design, ensure:

- the `M+` class of bucket/block writes is secret-independent,
- metadata is hidden or equalized,
- maintenance/rebuild schedule is public.

### Success gates

1. `UOCell` and `UOArray` pass property tests against plain reference implementations.
2. `UOSmallMap` passes exhaustive equivalence tests on small capacities.
3. For `UOSmallMap`, normalized `M+` traces are exactly identical across secret keys for fixed public inputs.
4. `UOOramMap` passes functional tests and exposes no non-ORAM extra `M+` signal.
5. For capacities `>= 64`, the ORAM backend shows fewer physical rewrites than the full-scan backend on at least one mixed get/put workload, or you document why not.

---

## Step 6 — Implement `uo-solc`

### Goal

Compile supported Solidity contracts into UO-safe deployables.

### Work

1. Parse Solidity source plus sidecar metadata.
2. Identify confidential entrypoints.
3. Perform SWL / predication.
4. Rewrite state declarations into UO object references.
5. Lower reads/writes to the UO ABI.
6. Rewrite loops, conditionals, and function calls.
7. Normalize reverts and error conditions.
8. Emit transformed source/IR, compiled bytecode, and manifest.

### Strong recommendation

Do not try to preserve pretty source formatting perfectly. Correctness and auditable output matter more.

### Success gates

1. All mandatory benchmark contracts compile through `uo-solc` without manual source edits beyond the declared annotations.
2. The resulting UO bytecode executes on the chosen runtime.
3. Disassembly shows no forbidden opcodes/calls for confidential paths.
4. The compiler emits a manifest for every compiled contract.
5. Negative tests confirm rejection of unsupported features.

---

## Step 7 — Integrate `uo-evm`

### Goal

Run the compiled UO contracts end to end on a confidential EVM runtime.

### Work

1. Load manifests and preallocate per-entrypoint work buffers.
2. Register UO precompiles or equivalent host interface.
3. Route confidential persistent state through `UO-Store`.
4. Route confidential cleanup/allocator actions through `UO-Allocator`.
5. Equalize gas per manifest budget.
6. Emit optional traces for probe mode.

### Additional runtime discipline

- avoid secret-dependent host allocations,
- avoid secret-dependent logging,
- avoid secret-dependent exceptions escaping to the host,
- keep entrypoint dispatch public and explicit.

### Success gates

1. Every mandatory benchmark deploys and runs on `uo-evm`.
2. Public `gasUsed` is exactly constant per entrypoint.
3. Success vs logical abort runs have the same public schedule length and gas.
4. Trace mode can be enabled without changing semantics.

---

## Step 8 — Build `uo-check` and translation validation

### Goal

Prove that transformed programs stay within the supported subset and do not silently reintroduce leakage.

### Work

1. Implement a source checker that enforces supported-subset rules and metadata completeness.
2. Implement an artifact checker that verifies:
   - no raw confidential backend escapes,
   - manifest/object/resource consistency,
   - exact proof-relevant manifest fields such as access counts, stack/arena
     budgets, and backend parameters.
3. Implement source-to-artifact translation validation:
   - re-derive the admitted compiled artifact from source plus metadata,
   - compare proof-relevant functions, objects, and manifest fields exactly,
   - use bounded differential testing only as a secondary semantic check where
     it is helpful.

### Benchmark harness policy

For each benchmark, create a small-domain harness variant so exhaustive checking is tractable.

Examples:

- secrets reduced to `uint8` or small enumerated domains,
- account universe reduced to 4, 8, or 16 addresses,
- map capacities reduced to 8 or 16 for exhaustive exact-UO checks.

### Success gates

1. `uo-check` rejects seeded leaks such as raw `SSTORE`, events, unbounded mappings, or secret-dependent `revert`.
2. Every benchmark has at least one bounded harness variant.
3. Source-to-artifact validation succeeds for the admitted proof-relevant
   compiler outputs.
4. Bounded harnesses pass exhaustive or near-exhaustive semantic equivalence
   checks.
5. The checker emits a human-readable certificate/report per contract.

---

## Step 9 — Build `mplus-probe`

### Goal

Produce objective evidence that raw contracts leak and UO contracts do not.

### Work

1. Implement paired-run execution with same public inputs and varied secrets.
2. Collect:
   - abstract trace hash,
   - logical access trace hash,
   - physical `M+` trace,
   - bytes written,
   - number of backend writes,
   - number of zero writes,
   - number of unmaps/discards,
   - public gas used.
3. Compute:
   - exact trace equality checks,
   - classifier AUC,
   - mutual information,
   - baseline-vs-UO comparison tables.

### Metric policy

For exact-UO backends, require exact equality of normalized traces.

For ORAM backends, require:

- exact equality of the abstract trace shape and write-class shape,
- no detectable extra signal in host-proxy metrics,
- and only the intended ORAM transcript variability remains.

### Success gates

1. At least three raw baseline benchmarks show a strong leak on at least one channel, with **AUC >= 0.90**.
2. For exact-UO benchmarks, normalized traces are identical across all tested secret pairs.
3. For UO benchmarks, host-proxy classifiers stay near chance, with target **AUC <= 0.55**.
4. Mutual information target for UO runs: **< 0.01 bits** on the measured proxy channels.
5. All confidential-path physical writes after initialization are reported as `UPDATE` only.

---

## Step 10 — Assemble the benchmark suite

### Goal

Demonstrate representative, not exhaustive, coverage.

### Mandatory benchmarks

#### 1. `FixedSlotClassifier`

Purpose:

- minimal proof that fixed control flow + fixed logical address still leaks through update class.

Features exercised:

- scalar state,
- same-location writes,
- logical `0` vs `1` classification.

Backends:

- raw EVM storage baseline,
- UO cell.

#### 2. `AuthScan`

Purpose:

- bounded loop + fixed array + secret comparison + state update.

Features exercised:

- SWL over loops,
- fixed public iteration bound,
- predicated assignment,
- scalar state update.

Backends:

- UO array + UO cell.

#### 3. `ConfidentialMixer`

Purpose:

- representative confidential contract with deposits, withdraws, and commit lookup.

Features exercised:

- map lookup/update,
- logical insert/update/delete semantics,
- `require` normalization,
- two-entrypoint stateful behavior.

Backends:

- `MixerFullScan` with small capacity,
- `MixerOram` with larger capacity.

#### 4. `ERC20Lite`

Purpose:

- multiple state maps and multi-step updates in one call.

Features exercised:

- balances,
- allowances,
- `transfer`, `approve`, `transferFrom`,
- multiple map reads/writes,
- same-value writes and insufficient-balance abort handling.

Backends:

- full-scan for tiny harness,
- ORAM for larger evaluation variant.

#### 5. `RegistryCRUD`

Purpose:

- explicitly exercise logical insert, update, delete, and no-op paths.

Features exercised:

- map CRUD,
- tombstone/delete semantics,
- full coverage of source-level `SET/CLEAR/SAME/UPDATE` possibilities.

Backends:

- full-scan mandatory,
- ORAM optional.

### Optional stretch benchmark

#### 6. `SealedBidAuctionLite` or `PrivateVoteLite`

Only do this after the mandatory suite is stable.

### Required benchmark variants

For each mandatory benchmark, provide:

1. **raw baseline** contract,
2. **UO-transformed** contract,
3. **small-domain harness** for exhaustive checking,
4. **evaluation harness** for overhead and statistical leakage tests.

### Success gates

1. All five mandatory benchmarks compile and run in both raw and UO forms.
2. Each benchmark has a small-domain harness.
3. Results are reproducible from a single documented command.

---

## Step 11 — Hardening and reproducibility

### Goal

Make the artifact credible and runnable by others.

### Work

1. Add a top-level README with exact build/run instructions.
2. Add scripts that:
   - compile benchmarks,
   - run correctness checks,
   - run `mplus-probe`,
   - generate results tables.
3. Add CI or a one-command local validation flow.
4. Document exactly what subset is supported and what is rejected.

### Success gates

1. A clean checkout can reproduce the benchmark results.
2. One command can run the full validation pipeline.
3. The artifact emits machine-readable result files in `results/`.

---

## 11. Detailed backend requirements

### 11.1 `UOCell`

A `UOCell<T>` must satisfy:

- logical `get` returns the last committed value,
- logical `set` of any value, including zero and the same value, results in physical `UPDATE` only after initialization,
- public constant cost per `get` and per `set`,
- no all-zero backend representation of logical zero.

### 11.2 `UOSmallMap`

A full-scan map must satisfy:

- public fixed capacity,
- deterministic full scan on every get/put,
- no leakage of occupancy, hit/miss, insert/update/delete status,
- no physical zeroization for delete,
- rerandomized rewritten records.

### 11.3 `UOOramMap`

An ORAM map must satisfy:

- secret-independent leakage beyond the intended ORAM transcript,
- no `SET/CLEAR/SAME` leakage in bucket/block writes,
- public rebuild/eviction schedule,
- metadata protected under the same rules.

### 11.4 `UOAllocator`

The allocator must satisfy:

- fixed-size region provisioning from manifest,
- no secret-dependent allocate/free count,
- no zeroization on free,
- public-schedule reclaim only,
- scrub uses fresh nonzero data.

---

## 12. Detailed acceptance criteria

The toolchain is not done until all hard gates below are met.

### 12.1 Functional correctness

1. Every mandatory benchmark compiles in raw and UO form.
2. UO execution matches raw benchmark semantics on randomized tests.
3. Each small-domain harness passes exhaustive or near-exhaustive differential testing.
4. Success and abort semantics match the intended high-level contract behavior.

### 12.2 Static safety

1. `uo-check` rejects unsupported features and seeded leaks.
2. Compiled UO contracts contain no forbidden opcodes or calls.
3. Confidential state accesses are explicit through the UO ABI.
4. Every confidential entrypoint has a valid manifest.

### 12.3 Dynamic security

1. Exact-UO benchmarks show exact normalized trace equality across secret variations.
2. ORAM benchmarks show no measurable extra leakage beyond intended ORAM variability.
3. `gasUsed` is exactly constant per confidential entrypoint.
4. After initialization, all confidential-path physical writes are `UPDATE` only.
5. No confidential-path all-zero writes occur.
6. No confidential-path discard/unmap occurs.

### 12.4 Runtime discipline

1. No dynamic buffer growth during confidential entrypoints.
2. Work buffers are manifest-sized and preallocated.
3. Scrub/reclaim tests pass.

### 12.5 Performance evidence

There is no hard slowdown cap, but you must report:

- runtime/gas overhead,
- backend write counts,
- memory footprint,
- and full-scan vs ORAM tradeoff.

The artifact should show at least one workload where the ORAM backend improves over full scan at moderate capacity, or explicitly explain why the current prototype does not.

---

## 13. Common failure modes to avoid

Do not ship the artifact with any of these mistakes.

1. **Only equalizing gas** while leaving update classes exposed.
2. **Hiding only logical addresses** while leaving zero/nonzero or same-vs-changed visible.
3. **Deleting by writing zero**.
4. **Rewriting same payload without rerandomization**, causing `SAME`.
5. **Leaky metadata**, especially occupancy bits, allocator state, or GC counters.
6. **Secret-dependent revert**, panic, or host exception.
7. **Dynamic memory growth** tied to secrets.
8. **Events/logs** in confidential code paths.
9. **Calling external contracts** not controlled by the UO runtime.
10. **Claiming full-system proof** when only the abstract/runtime layers were tested.

---

## 14. Suggested implementation order inside the repo

Use this order unless blocked.

1. Threat-model instrumentation and raw leak baseline.
2. Sidecar metadata format and subset validator.
3. `UOCell` and `UO-Store` scalar backend.
4. `UOSmallMap` full-scan backend.
5. `uo-solc` for scalar + full-scan map benchmarks.
6. `uo-evm` integration and exact-UO benchmark passes.
7. `uo-check` static/bytecode checks.
8. `mplus-probe` report generation.
9. ORAM backend.
10. ORAM benchmark passes.
11. Docs, scripts, and artifact packaging.

Do not start with ORAM before the scalar/full-scan path is fully correct and instrumented.

---

## 15. What the final `results/` directory should contain

At minimum:

- `correctness.json`
- `static_checks.json`
- `trace_equivalence.json`
- `leakage_auc.json`
- `mutual_information.json`
- `overheads.json`
- `artifact_readme.md`

It should also contain generated tables/plots suitable for a paper appendix.

---

## 16. Minimal paper-ready result set

The artifact should be able to generate these claims with evidence:

1. **Positive control:** raw contracts leak under `M+` even when control flow and logical access schedule are fixed.
2. **Compiler result:** `uo-solc` compiles representative Solidity contracts into a UO-safe form for the supported subset.
3. **Runtime result:** `uo-evm` executes those contracts with constant public gas and UO backend behavior.
4. **Security result:** exact-UO benchmarks have exact trace equality; ORAM benchmarks show no extra measured leakage.
5. **Systems result:** the toolchain is end to end, not just a source transform or just a storage library.

---

## 17. Final deliverables expected from Codex

By the end, Codex should have produced:

1. working source code for `uo-solc`, `uo-evm`, `uo-check`, and `mplus-probe`,
2. the full benchmark suite,
3. automated scripts for build/test/report,
4. a clear supported-subset specification,
5. a reproducible `results/` bundle,
6. and a concise engineering note summarizing:
   - what is exact-UO,
   - what is ORAM/computational-UO,
   - what remains unsupported,
   - and what assumptions the prototype still relies on.

That is the bar for “The UO Toolchain” being genuinely implemented.
