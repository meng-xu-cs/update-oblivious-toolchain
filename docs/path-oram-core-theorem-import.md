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

## Remaining Proof Obligation

The preferred lowest-assumption closure route is now:

1. A proof object
   `paper : PathOramJACMLiteratureTheoremAt assumptions bundle.publicView bundle.leafRun`
   for the concrete public observer and the runtime’s theorem-facing leaf
   schedule.

2. Then use the already-mechanized composition step:

- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACMAt`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACMAt`

The more general route remains available if the imported theorem arrives with
its own theorem-side `leafRun`:

1. A proof object
   `core : StandardPathOramCoreTheorem assumptions bundle.publicView`
   for the concrete public observer used by the runtime witness bundle.

2. A proof that the theorem's hidden leaf schedule matches the runtime one:
   `core.leafRun = bundle.leafRun`

Once those are available, the repo already has the composition step:

- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfJACM`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfJACM`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_importedStorageTheoremOfCore`
- `SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardTheoremRealizationOfCore`

## Practical Interpretation

The remaining gap is no longer about:

- theorem plumbing
- runtime observer extraction
- public/storage interface mismatch
- SGX/TEE theorem composition

The remaining gap is only the imported Path ORAM core proof; the separate
`leafRun` alignment disappears on the preferred `PathOramJACMLiteratureTheoremAt`
route and survives only on the more general fallback route.
