# Path ORAM Core Theorem Import Map

This note records the exact theorem-import target for the current
`path_oram_local_posmap_v1` route after the refactor in
`proof/lean/UOToolchain/PathOramLocalPosmapV1StandardTheorem.lean`.

It does not weaken the theorem boundary. It identifies the remaining imported
theorem obligation in the smallest form currently exposed by the repository.

## Target Objects

- `PathOramJACMLiteratureTheorem`
  The literature-facing theorem object aligned to the Path ORAM JACM paper.
  This is now implemented in
  `proof/lean/UOToolchain/PathOramJACMTheorem.lean`.

- `PathOramJACMLiteratureTheoremAt`
  The strengthened literature-facing object fixed at a chosen theorem-side
  `leafRun`. This is the preferred lowest-assumption import route when the
  imported theorem is stated directly on the runtime’s theorem-facing schedule.

- `StandardPathOramCoreTheorem`
  The theorem-side ORAM claim. This is the part that should come from a
  standard Path ORAM proof.

- `PathOramStorageEnvelope`
  The runtime-side public envelope. This is already mechanized from the seeded
  runtime witness bundle and covers:
  public scaffold extraction,
  bucket projection,
  public metadata/counter location constancy,
  and storage-shape exactness.

- `ImportedPathOramStorageTheorem`
  The combined theorem-source object consumed by the repo.

- `PathOramLocalPosmapV1StandardTheoremRealization`
  The final concrete bridge from the imported theorem source to the seeded
  runtime witness family.

## Literature Mapping

For the standard nonrecursive Path ORAM theorem:

- the JACM-style import object is `PathOramJACMLiteratureTheorem`
- the server-observed path labels `x_j` map to `pathOramLeafValues`
- the public sequence length and object/bucket-count scaffold map to
  `PathOramLeafScheduleScaffold`
- the theorem statement that accessed paths are independent fresh random leaves
  maps to `PathOramLeafValueCanonicalOnPublicPart`
- the stash-failure bound maps to the explicit assumption field
  `stashOverflowBounded`
- randomized bucket/path re-encryption maps to
  `bucketEncryptionINDCPA`
- encrypted metadata-page protection in the local-posmap wrapper maps to
  `metadataEncryptionINDCPA`
- fresh remapping after each access maps to `freshLeafResampling`

The formal mapping from the literature-facing object to the repo core theorem
is now:

- `PathOramJACMLiteratureTheorem.toStandardPathOramCoreTheorem`
- `PathOramJACMLiteratureTheoremAt.toStandardPathOramCoreTheorem`
- `PathOramJACMLiteratureTheorem.standardPathOramStorageTheoremAt`
- `PathOramJACMLiteratureTheoremAt.standardPathOramStorageTheoremAt`

## Current Compatibility Status

The repo now records the bucket-size compatibility explicitly in Lean:

- `pathOramJACMBlocksPerBucket = 5`
- `pathOramBlocksPerBucket = 5`
- `WellFormedPathOramObject.jacmCompatibleObject`
- `PathOramConfigWellFormed.jacmCompatibleObject`

So the concrete backend is now shape-compatible with a verbatim JACM bucket-size
assumption.

## Local Posmap Wrapper

The current runtime is not a verbatim copy of the vanilla Path ORAM paper
presentation:

- it stores an encrypted position map in public metadata pages
- it reads and rewrites those metadata pages in a public full scan each access
- it exports one theorem-facing `leafRun` extracted from the runtime witness
  family

These differences are handled by the runtime-side `PathOramStorageEnvelope`.
They should not be folded back into the imported core theorem.

## Current Closure

The concrete repo theorem is now closed inside Lean under the explicit bundle
`PathOramLocalPosmapV1SecurityAssumptions`.

The direct concrete discharge path is:

- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardPathOramStorageTheoremAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheorem`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealization`

The preferred literature-faithful closure path is also now explicit:

1. Construct the theorem-side object at the runtime-facing schedule:
   `paper : PathOramJACMLiteratureTheoremAt assumptions bundle.publicView bundle.leafRun`

2. Lift it through the already mechanized runtime envelope:

- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardPathOramStorageTheoremAtOfJACMAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACMAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACMAt`

For the concrete seeded runtime bundle, the repo now self-instantiates that
preferred route directly from the checked runtime family plus the explicit
stash assumption:

- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_jacmLiteratureTheoremAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardPathOramStorageTheoremAtOfSelfJACMAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfSelfJACMAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfSelfJACMAt`

The more general route remains available if an external imported theorem arrives
with its own theorem-side `leafRun`:

- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACM`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACM`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfCore`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfCore`

## Paper Mainline

The repo now deliberately uses one paper-main route and one appendix / artifact
route at the same theorem boundary.

- Paper-main route:
  import or cite an external theorem object at
  `PathOramLocalPosmapV1StandardTheoremTarget`, preferably through
  `PaperMainPathOramTheoremSourceAt` fixed at the runtime-facing
  `publicView` / `leafRun`.
- Appendix / artifact route:
  keep the current self-instantiated route
  `pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization` so the
  checked artifacts, certificates, and runtime witness bundle close end to end
  inside the repo today.

These are not different theorem boundaries. They use the same storage envelope,
the same projection lemmas, and the same explicit backend-assumption bundle.
The only difference is where the standard Path ORAM core theorem object comes
from.

## Practical Interpretation

The completed engineering bridge is no longer blocked on:

- theorem plumbing
- runtime observer extraction
- public/storage interface mismatch
- SGX/TEE theorem composition

What remains open for the paper-main route is narrower:

- supply or cite the external literature-proof object at the same frozen
  interface
- or separately justify the explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle with cryptographic/backend
  arguments outside this repo

The concrete recommended literature source, fallback source, and theorem-field
mapping are collected in `docs/path-oram-citation-import-plan.md`.
