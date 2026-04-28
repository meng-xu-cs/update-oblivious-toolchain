# End-to-end evaluation plan and local coding-agent runbook

This runbook assumes a clean checkout of the uploaded repository. It is designed for a local coding agent that can run commands, preserve logs, and create issues/PRs from failures.

## Phase 0 — Preflight and reproducibility capture

Record the environment before doing anything else:

```bash
set -euo pipefail
ROOT="$PWD"
mkdir -p eval-logs
{
  date -u
  uname -a
  rustc --version
  cargo --version
  command -v lake || true
  lake --version || true
  command -v elan || true
  elan --version || true
  cat proof/lean/lean-toolchain
  git rev-parse HEAD 2>/dev/null || true
  git status --short 2>/dev/null || true
} | tee eval-logs/00-environment.txt
```

Expected observation: Cargo dependencies are exact-pinned in `Cargo.toml`, but the Lean toolchain says `leanprover/lean4:stable`. File an issue to pin an exact Lean version.

## Phase 1 — Baseline build and validation

Run the same high-level scripts the repository exposes:

```bash
./scripts/compile_benches.sh 2>&1 | tee eval-logs/01-compile-benches.log
(
  cd proof/lean
  lake build
) 2>&1 | tee eval-logs/02-lake-build.log
cargo test --workspace 2>&1 | tee eval-logs/03-cargo-test.log
./scripts/run_validation.sh 2>&1 | tee eval-logs/04-run-validation.log
```

Then run reproducibility:

```bash
UO_REPRO_KEEP=1 ./scripts/check_probe_reproducibility.sh 2>&1 | tee eval-logs/05-reproducibility.log
```

Run the heavy artifact path separately because it can consume large space/time:

```bash
UO_RESULTS_DIR=results-heavy UO_HEAVY_ARTIFACT_BUDGET_BYTES=21474836480 ./scripts/run_heavy_artifact.sh 2>&1 | tee eval-logs/06-heavy-artifact.log
```

## Phase 2 — Machine-check result invariants

Create `eval-check-results.py` and run it after `run_validation.sh`:

```python
#!/usr/bin/env python3
import json
from pathlib import Path

R = Path('results')
failures = []

def load(name):
    return json.load(open(R / name))

# Tamper suite
try:
    d = load('tamper_validation.json')
    scenarios = d.get('scenarios', [])
    if d.get('scenario_count') != len(scenarios):
        failures.append('tamper scenario_count mismatch')
    bad = [s.get('scenario') for s in scenarios if not s.get('rejected', False)]
    if bad:
        failures.append(f'tamper scenarios not rejected: {bad[:10]}')
except Exception as e:
    failures.append(f'tamper_validation unreadable: {e}')

# Functional correctness summaries
try:
    d = load('correctness.json')
    bad = [s.get('benchmark') for s in d.get('scenarios', []) if not s.get('equivalent')]
    if bad:
        failures.append(f'correctness non-equivalent: {bad}')
except Exception as e:
    failures.append(f'correctness unreadable: {e}')

# Exact trace equivalence
try:
    d = load('trace_equivalence.json')
    for s in d.get('exact_uo', []):
        for k in ['logical_access_equal','logical_write_equal','opcode_equal','physical_read_equal','physical_trace_equal']:
            if not s.get(k):
                failures.append(f'exact_uo {s.get("benchmark")} {k} false')
except Exception as e:
    failures.append(f'trace_equivalence unreadable: {e}')

# Static proof-grade import checks
try:
    d = load('static_checks.json')
    for k in [
        'legacy_axiom_definition_surface_restricted',
        'legacy_theorem_symbol_surface_restricted',
        'proofgrade_checker_import_surface_restricted',
        'proofgrade_checker_legacy_symbol_mentions_absent',
        'proofgrade_core_module_import_surface_restricted',
    ]:
        if d.get(k) is not True:
            failures.append(f'static check {k} not true')
except Exception as e:
    failures.append(f'static_checks unreadable: {e}')

# Generic accepted/scenario checks for validation files.
for p in R.glob('*validation.json'):
    d = json.load(open(p))
    if isinstance(d, dict) and 'accepted' in d and d['accepted'] is not True:
        # Some nested reports deliberately include rejected raw artifacts; top-level validation reports should be accepted.
        failures.append(f'{p.name}: top-level accepted is not true')
    if isinstance(d, dict) and 'scenario_count' in d and 'scenarios' in d:
        if d['scenario_count'] != len(d['scenarios']):
            failures.append(f'{p.name}: scenario_count mismatch')

if failures:
    print('
'.join(failures))
    raise SystemExit(1)
print('all baseline result invariants passed')
```

Run:

```bash
python3 eval-check-results.py 2>&1 | tee eval-logs/07-check-results.log
```

## Phase 3 — Proof-audit checks

The local agent should add or run checks for theorem dependencies, not just textual import restrictions.

1. Generate theorem inventory:

```bash
python3 - <<'PY' > eval-logs/theorem-inventory.tsv
from pathlib import Path
import re
pat = re.compile(r'^(?:private\s+)?(theorem|lemma|axiom)\s+([^\s:]+)')
print('kind\tname\tfile\tline')
for p in sorted(Path('proof/lean/UOToolchain').glob('*.lean')):
    depth = 0
    for i, line in enumerate(p.read_text().splitlines(), 1):
        out = []
        j = 0
        while j < len(line):
            if depth == 0 and line.startswith('--', j):
                break
            if line.startswith('/-', j):
                depth += 1; j += 2; continue
            if depth > 0:
                if line.startswith('-/', j):
                    depth -= 1; j += 2; continue
                j += 1; continue
            out.append(line[j]); j += 1
        m = pat.match(''.join(out).strip())
        if m:
            print(f'{m.group(1)}\t{m.group(2)}\t{p}\t{i}')
PY
```

2. Add a strict proof-grade root, e.g. `proof/lean/UOToolchain/ProofGradeRoot.lean`, that imports only proof-grade modules and no legacy axiom modules.

3. Add a Lean executable or CI step that prints/checks axioms for named paper theorems. The check should fail if `legacyOramLocalTheorem` or `legacySgxMicroLocalTheorem` appears.

4. Grep as a weaker sanity check:

```bash
rg -n "axiom|legacyOramLocalTheorem|legacySgxMicroLocalTheorem" proof/lean | tee eval-logs/08-axiom-grep.txt
rg -n "^import UOToolchain\.OramGame|^import UOToolchain\.SgxMicroGame" proof/lean | tee eval-logs/09-legacy-import-grep.txt
```

## Phase 4 — New red-team tests for theorem gaps

Add these tests as expected failures until the model/policy is fixed.

### Test A: return payload leak

Goal: prove the current theorem observer is too weak unless return values are modeled or forbidden.

1. Use `SingleAccessMap.read(bytes32)`, marked confidential with secret key.
2. Run two states with same public projection and same public schedule but different hidden value at the secret key.
3. Compare `PublicOutcomeTrace`: it should have same output shape/length.
4. Compare actual `CallResult.return_value`: it differs.
5. Expected current result: the trace theorem can still pass; the test should flag this as an unmodeled host-visible leak.

### Test B: secret-dependent abort/status

1. Use `ConfidentialMixer.withdraw(commitment, amount)` or `ERC20Lite.transfer`.
2. Create two secret states: one with enough balance and one without, same public projection.
3. Run the confidential entrypoint.
4. Assert `termination_status` / `aborted` differs.
5. Expected current result: status differs and is public. The compiler/checker should reject or policy should declare success declassification.

### Test C: arithmetic semantic mismatch

Create tiny admitted programs for:

- `uint256 x = 2^128 - 1; return x + 1;`
- `return 0 - 1;`
- unary negation over `uint` if parser emits it;
- division/mod by zero.

Compare Lean model expectations and runtime results. Expected current result: mismatch unless admission rejects these cases.

### Test D: Keccak semantic mismatch

Create a program where two different fixed-size inputs are hashed and then used as map keys or compared. Lean mock returns all-zero bytes, while runtime uses real Keccak. Expected current result: value-level semantics diverge.

### Test E: missing sidecar metadata fail-open

Delete an entrypoint stanza from a sidecar for a known confidential function. Expected secure behavior: compiler rejects. Expected current behavior: compiler treats it as public; file a bug and fix to fail closed.

### Test F: object-order schedule leakage

Create a program with multiple confidential objects where the order of object accesses can vary with a secret predicate. Expected secure behavior: compiler linearizes both paths to the same ordered schedule or rejects. Verify the theorem leakage includes ordered object schedule, not just counts.

### Test G: crypto/freshness/nonce discipline

Instrument encryption/fresh-coin calls to collect nonce/seed identifiers over a multi-call history. Assert no reuse under production mode and no diagnostics injection path is available in proof-grade mode.

## Phase 5 — Practical usability evaluation

For each benchmark and for new examples, collect:

- compile time;
- artifact JSON size;
- proof-bundle size;
- validation time;
- runtime time per call;
- bytes read/written;
- physical reads/writes;
- gas used;
- number of ORAM accesses;
- peak memory if available.

Run capacities `{16, 32, 64, 128, 256, 512, 1024, 4096}` for maps where possible. Produce a table comparing raw, full-scan, and `path_oram_local_posmap_v1`.

Acceptance criteria:

- exact backends: normalized physical/logical traces equal for secret variants;
- ORAM: logical write/update class is hidden; physical traces are not equal but accepted by ORAM theorem route; leakage classifiers do not exceed chance for modeled features;
- raw positive controls leak as expected;
- performance and artifact size are reported honestly.

## Phase 6 — Deployment/TEE evaluation

A local agent cannot prove SGX deployment assumptions by running code, but it can check whether implementation artifacts exist:

1. Identify actual enclave boundary, attestation, sealed storage, rollback counter, and encrypted return-channel code.
2. For each SGX assumption in `SgxDeploymentAssumptions`, map it to a concrete implementation mechanism or mark it as external/deployment-only.
3. Run a crash/rollback scenario if sealed storage exists.
4. Verify no theorem claim uses raw page IDs or physical side channels unless modeled.

## Phase 7 — Reporting template

The coding agent should produce:

- `eval-logs/` command logs;
- `eval-results-summary.md` with pass/fail table;
- `new-red-team-tests.md` describing Tests A–G and current outcomes;
- issues/PRs for every P0/P1 failure;
- updated theorem inventory and axiom report.

## Suggested acceptance gate for the next paper submission

Before the final theorem is advertised as “real host-visible execution,” require all of the following:

1. Return values/status/errors are either in the observer or explicitly policy-encrypted/declassified.
2. Secret-dependent aborts are rejected or modeled as declassification.
3. Lean value semantics match runtime arithmetic/Keccak or the claim is narrowed to trace-only.
4. Metadata is fail-closed.
5. The proof-grade root has no legacy axiom imports and final theorem axiom reports are whitelisted.
6. Runtime witness extraction is minimized or independently reconstructed.
7. A sequential/adaptive history theorem is stated, even if initially limited to exact backends.
