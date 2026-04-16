# Paper-Main Theorem Checklist

This checklist fixes the theorem-source strategy for a paper after the current
repo decision:

- the paper route and the appendix / artifact route share the same frozen
  theorem interface, but they are not symmetric as provenance claims
- the current paper choice is to use the citation route for the standard Path
  ORAM result at that interface
- the repo should keep the current self-instantiated closure only as appendix /
  executable-artifact support at exactly the same theorem interface
- the stronger import route should stay documented only as future work until a
  real external theorem artifact exists

This does not change the theorem boundary. It changes only the provenance and
presentation of the ORAM core theorem object.

For the concrete recommended literature sources and the detailed
source-to-interface mapping, see
`docs/path-oram-citation-import-plan.md`.

Status labels:

- `cleared`: fixed for the current citation-route paper profile
- `future-work`: only needed for a stronger external-theorem import story

## Checklist

- `cleared` Freeze the exact paper-main theorem target.
  Evidence:
  `proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`.
  The paper and artifact routes share the same target,
  `PathOramLocalPosmapV1StandardTheoremTarget`.

- `cleared` Freeze the preferred paper-main theorem source at the cleanest
  literature-facing interface.
  Evidence:
  `proof/lean/UOToolchain/PathOramJACMTheorem.lean`,
  `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`.
  The preferred theorem source is now named explicitly as
  `PaperMainPathOramTheoremSourceAt`, which is
  `PathOramJACMLiteratureTheoremAt assumptions publicView leafRun`.

- `cleared` Separate the paper-main route from the appendix / artifact route in
  Lean naming.
  Evidence:
  `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`.
  The repo now names:
  `pathOramLocalPosmapV1_paperMainStandardTheoremRealization` and
  `pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization`.

- `cleared` Keep the executable artifact closure at exactly the same theorem
  interface.
  Evidence:
  `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`,
  `docs/path-oram-core-theorem-import.md`.
  The appendix route now explicitly self-instantiates the same
  `PaperMainPathOramTheoremSourceAt` interface instead of introducing a
  different theorem boundary.

- `cleared` Keep the implementation bridge independent of theorem provenance.
  Evidence:
  `docs/imported-theorem-bridge-checklist.md`,
  `results/bridge_validation.json`.
  Translation validation, runtime certificates, runtime witnesses, and Lean
  checkers are already established independently of whether the core theorem is
  externally imported or self-instantiated.

- `cleared` Fix the current paper-main theorem provenance to the JACM citation
  route at the frozen paper-main interface.
  Evidence:
  `docs/path-oram-citation-import-plan.md`,
  `docs/path-oram-theorem-sources.bib`,
  `proof/lean/UOToolchain/PaperPathOramTheoremRoute.lean`.
  The current paper route now cites the JACM theorem as the external theorem
  source modeled by
  `PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun`.
  This is a citation-based provenance claim, not a claim that an external
  machine-imported theorem artifact is already packaged in the repo.

- `cleared` Fix the current paper-facing provenance statement for the explicit
  backend assumption bundle used by the concrete local-posmap wrapper.
  Evidence:
  `docs/path-oram-citation-import-plan.md`,
  `crates/uo-core/src/manifest.rs`,
  `runtime/uo-evm/src/oram.rs`,
  `runtime/uo-store/src/codec.rs`.
  The paper route now states one explicit provenance split for
  `bucketEncryptionINDCPA`, `metadataEncryptionINDCPA`,
  `freshLeafResampling`, and `stashOverflowBounded`: the JACM theorem is cited
  for the ORAM access-pattern / stash component, while the runtime documents
  the concrete leaf-sampling and sealed-record implementation facts required by
  the remaining assumptions. This is an explicit assumption profile, not a new
  mechanized cryptographic proof.

- `future-work` Upgrade the citation route to a genuinely external
  machine-checked theorem import at the same frozen interface.
  Evidence:
  `docs/stronger-import-route-feasibility.md`.
  The stronger import route remains worth pursuing, but it is not the current
  paper claim.

## Candidate Theorem Objects

The docs already suggest a small ordered menu of candidate theorem objects.

- Preferred candidate:
  `PaperMainPathOramTheoremSourceAt assumptions publicView leafRun`, which is
  exactly `PathOramJACMLiteratureTheoremAt assumptions publicView leafRun`.
  This is the cleanest paper route because it matches the runtime-facing
  `leafRun` directly and avoids a separate alignment proof.

- Second-best candidate:
  `PathOramJACMLiteratureTheorem assumptions publicView`.
  This is still literature-faithful, but it carries its own `leafRun`, so the
  bridge also needs a proof that the imported theorem’s `leafRun` matches the
  runtime-facing `bundle.leafRun`.

- Lower-level candidate:
  `StandardPathOramCoreTheorem assumptions publicView`.
  This is acceptable if the external theorem is stated at the repo’s theorem
  core rather than in JACM-facing language. The runtime `PathOramStorageEnvelope`
  can still lift it to the full storage theorem.

- Exact discharge target rather than theorem source:
  `PathOramLocalPosmapV1StandardTheoremTarget assumptions`.
  This is the frozen boundary all of the above candidates eventually discharge.

## Candidate Assumption-Justification Route

The docs also imply one natural provenance split for the explicit
`PathOramLocalPosmapV1SecurityAssumptions` bundle:

- `stashOverflowBounded`:
  cite or import the standard Path ORAM stash bound at the concrete repo
  parameters, using the already documented `Z = 5` compatibility.

- `freshLeafResampling`:
  justify that the implementation’s leaf remapping coins realize the uniform
  fresh-leaf distribution required by the theorem-side `leafRun`.

- `bucketEncryptionINDCPA`:
  cite or import the confidentiality theorem for bucket/path ciphertext
  rerandomization at the concrete encryption boundary used by the runtime.

- `metadataEncryptionINDCPA`:
  cite or import the corresponding confidentiality theorem for the encrypted
  position-map metadata pages in the local-posmap wrapper.

## Exit Condition

This checklist is complete for the current paper when the repo fixes the JACM
citation route at `PaperMainPathOramTheoremSourceAt`, keeps the appendix route
as an artifact-side cross-check at the same interface, and states the explicit
`PathOramLocalPosmapV1SecurityAssumptions` profile without changing the theorem
boundary. A genuinely external theorem import remains future work.
