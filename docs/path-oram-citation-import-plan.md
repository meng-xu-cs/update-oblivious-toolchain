# Path ORAM Citation And Import Plan

This note turns the paper-main theorem route into a concrete source-selection
and mapping plan.

It does not claim that the external theorem has already been imported. It fixes
the recommended literature source, the fallback source, and the exact mapping
from those sources into the repo’s theorem interface.

This is now the current paper-main provenance route for the repository. The
stronger external-theorem import story remains future work and is tracked
separately in `docs/stronger-import-route-feasibility.md`.

A ready-to-use bibliography file for these sources now lives at
`docs/path-oram-theorem-sources.bib`.

## Recommended Primary Source

Use the Journal of the ACM version as the main cited theorem source:

- Emil Stefanov, Marten van Dijk, Elaine Shi, T.-H. Hubert Chan, Christopher
  Fletcher, Ling Ren, Xiangyao Yu, and Srinivas Devadas.
  "Path ORAM: An Extremely Simple Oblivious RAM Protocol."
  *Journal of the ACM* 65(4), Article 18, April 2018.
- DOI: <https://doi.org/10.1145/3177872>
- Open author-hosted PDF:
  <https://elaineshi.com/docs/pathoram.pdf>

Why this is the recommended mainline source:

- it is the final archival version of the theorem source already modeled in
  `PathOramJACMTheorem.lean`
- it states the nonrecursive access-pattern theorem and the stash bound in one
  stable place
- it matches the repo’s `Z = 5` bucket-size choice, which is already recorded
  in Lean
- it is easier to cite cleanly in a paper than a repo-internal theorem object

## Fallback Source

If the paper prefers the original conference presentation, use the CCS version
as the fallback source:

- Emil Stefanov, Marten van Dijk, Elaine Shi, Christopher Fletcher, Ling Ren,
  Xiangyao Yu, and Srinivas Devadas.
  "Path ORAM: An Extremely Simple Oblivious RAM Protocol."
  *Proceedings of CCS 2013*, Berlin, Germany.
- DOI: <https://doi.org/10.1145/2508859.2516660>
- Open author-hosted PDF:
  <https://people.csail.mit.edu/devadas/pubs/PathORam.pdf>

Why this is the fallback rather than the default:

- it is shorter and earlier than the JACM version
- it is still suitable for the access-pattern theorem narrative
- but the JACM version is the cleaner single citation for the final paper
  theorem, especially around the stash analysis and the mature presentation of
  the protocol

## Mechanization Candidates

If the paper wants a stronger "import" story than a literature citation alone,
the current visible candidates are:

- Pengbo Yan, Toby Murray, Olga Ohrimenko, Van-Thuan Pham, and Robert Sison.
  "Combining Classical and Probabilistic Independence Reasoning to Verify the
  Security of Oblivious Algorithms."
  FM 2024 / extended version on arXiv.
  <https://arxiv.org/abs/2407.00514>
  The paper states that the logic is mechanized in Isabelle/HOL and that Path
  ORAM is one of the case studies, but it also states that the case-study
  proofs are manual rather than exposing a published machine-checked external
  theorem object at the repo’s exact interface. This is therefore the strongest
  visible external formal-methods candidate, but not yet a drop-in theorem
  source for `PaperMainPathOramTheoremSourceAt`.

- Hannah Leung, Talia Ringer, and Christopher W. Fletcher.
  "Towards Formally Verified Path ORAM in Coq."
  CoqPL 2023 extended abstract.
  <https://dependenttyp.es/pdf/oramproposal.pdf>
  This is highly relevant to the repo’s long-term direction, but it is a plan
  document / extended abstract rather than an already consumable theorem object.

These are worth citing in related work or future-work positioning, but they do
not yet displace the current citation-route choice or make the stronger import
route complete:

- a citation-based paper-main theorem route using the JACM paper directly
- or a dedicated appendix / companion mechanization that exports a theorem
  object matching `PaperMainPathOramTheoremSourceAt`

## Theorem-Object Menu

The docs now recommend the theorem objects in this order:

1. `PaperMainPathOramTheoremSourceAt assumptions publicView leafRun`
2. `PathOramJACMLiteratureTheorem assumptions publicView`
3. `StandardPathOramCoreTheorem assumptions publicView`
4. `PathOramLocalPosmapV1StandardTheoremTarget assumptions`

The first option is preferred because it imports the literature theorem already
fixed at the runtime-facing `leafRun`, so no extra leaf-run alignment lemma is
needed.

## Source-To-Interface Mapping

The recommended paper-main import should be described as a mapping from the
JACM theorem source into:

`paper : PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun`

The intended field-by-field mapping is:

- `cfgWellFormed`:
  the literature theorem is instantiated only at well-formed Path ORAM
  configurations with the repo’s concrete public tree shape and bucket size.

- `publicViewSafe`:
  the imported theorem is parameterized only by the public execution scaffold
  already exposed in the repo as `bundle.publicView`.

- `accessPatternTheorem`:
  this is the literature statement that the server-observed accessed paths are
  distributed like fresh random leaf labels subject only to the public access
  scaffold. In the repo this becomes the canonical-leaf theorem for
  `bundle.leafRun`.

- `stashOverflowTheorem`:
  this is the stash-failure tail bound specialized to the repo’s concrete
  bucket size and stash parameters.

At the repo boundary, the theorem-source mapping is then:

- JACM access-pattern theorem
  -> `PathOramJACMLiteratureTheoremAt.accessPatternTheorem`
  -> `StandardPathOramCoreTheorem.leafValueCanonicalOnPublicPart`
  -> `PaperMainPathOramTheoremSourceAt`

- JACM stash theorem
  -> `PathOramJACMLiteratureTheoremAt.stashOverflowTheorem`
  -> `PathOramLocalPosmapV1SecurityAssumptions.stashOverflowBounded`

- runtime-side public metadata / bucket projection / storage-shape facts
  are not imported from the paper theorem
  -> they are provided by the repo’s `PathOramStorageEnvelope`

That split keeps the imported theorem clean: the literature theorem supplies
the ORAM core, and the repo supplies the wrapper-specific storage envelope.

## Current Paper Route

The current paper choice is:

1. Cite the JACM paper as the primary Path ORAM theorem source.
2. State that the imported theorem object is modeled as
   `PaperMainPathOramTheoremSourceAt`.
3. Explain that the concrete runtime contributes the
   `PathOramStorageEnvelope` bridge from that theorem source to the repo’s
   storage observer.
4. Use
   `pathOramLocalPosmapV1_paperMainStandardTheoremRealization`
   as the named bridge object connecting the external theorem source to the
   checked runtime witness family.
5. Keep
   `pathOramLocalPosmapV1_artifactAppendixStandardTheoremRealization`
   only as appendix / artifact-side cross-check material.

The stronger external-theorem import route stays documented as future work in
`docs/stronger-import-route-feasibility.md`.

## Assumption Provenance Plan

The explicit assumption bundle is:

- `bucketEncryptionINDCPA`
- `metadataEncryptionINDCPA`
- `stashOverflowBounded`

The recommended provenance split is:

- `stashOverflowBounded`:
  cite the Path ORAM stash theorem from the JACM paper, using the already
  documented repo compatibility fact that `blocks_per_bucket = 5`.

- `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA`:
  discharge these from the concrete sealed-record layer actually used by the
  runtime. The implementation uses `ChaCha20Poly1305` with fresh random nonces
  and associated data in
  [runtime/uo-store/src/codec.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-store/src/codec.rs).
  The theorem only needs confidentiality-style hiding at these fields, while
  the runtime primitive is stronger and also provides integrity. A conservative
  paper route is therefore:
  cite the Path ORAM theorem for access-pattern / stash behavior,
  and separately state or import the confidentiality guarantee required of the
  `ChaCha20-Poly1305` sealed bucket and metadata records.

Fresh leaf remapping is no longer part of that explicit assumption bundle.
The repo now discharges it at the runtime-family boundary: the manifest fixes
`leaf_count = capacity.max(2).next_power_of_two()` in
[manifest.rs](/home/m285xu/update-oblivious-toolchain/crates/uo-core/src/manifest.rs),
the runtime samples fresh leaves with `next_u64() % leaf_count` in
[oram.rs](/home/m285xu/update-oblivious-toolchain/runtime/uo-evm/src/oram.rs),
and the canonical fresh-coin / hidden-leaf coverage checkers prove that the
runtime witness family realizes the exact theorem-side leaf seed space.

This closes the current paper-facing assumption-provenance task by fixing one
explicit assumption statement and one exact source split. It does not pretend
that those cryptographic/backend assumptions are already discharged by a new
mechanized proof inside this repo.

## Crypto Source For The Concrete Runtime Primitive

For the concrete runtime primitive, the stable implementation reference is:

- Yaron Nir and Adam Langley.
  "ChaCha20 and Poly1305 for IETF Protocols."
  RFC 8439, June 2018.
- <https://www.rfc-editor.org/rfc/rfc8439>

This is not itself the theorem proving the repo’s confidentiality assumptions.
It is the correct specification reference for the primitive actually used by
the runtime.

For the AEAD-security analysis pairing the IND-CPA assumptions
(`bucketEncryptionINDCPA`, `metadataEncryptionINDCPA`) with the concrete
ChaCha20-Poly1305 composition, the cited analysis is:

- Gordon Procter.
  "A Security Analysis of the Composition of ChaCha20 and Poly1305."
  IACR Cryptology ePrint Archive, Report 2014/613, 2014.
- <https://eprint.iacr.org/2014/613>

This is the reference confirming the AEAD-style composition used by the
runtime primitive provides confidentiality (IND-CPA) and integrity
(INT-CTXT) under the standard security model. The repo's
`bucketEncryptionINDCPA` and `metadataEncryptionINDCPA` assumptions are
the IND-CPA half; integrity is a stronger property that is not
load-bearing for the paper-main theorem but is also delivered by the
primitive.

## W5.3 Stash-Overflow Provenance Pairing

The Lean side now also pairs the `stashOverflowBounded` assumption with
explicit provenance metadata. The structure
[`PathOramLocalPosmapV1StashOverflowProvenance`](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1.lean)
carries:

- `primaryCitationBibKey`: `Stefanov2018PathORAM` (JACM 2018)
- `primaryTheoremReference`: JACM 2018 Theorem 5.1 (stash overflow tail
  bound)
- `fallbackCitationBibKey`: `Stefanov2013PathORAM` (CCS 2013)
- `deployedBlocksPerBucket`: 5 (matching `pathOramBlocksPerBucket`)
- `deployedStashBoundFormula`: `stash_bound = max(capacity, 1)` (the
  Path-ORAM construction in
  `crates/uo-core/src/manifest.rs`)
- `workingStashCapacityFormula`: `stash_bound + buckets_per_access *
  blocks_per_bucket` (the Rust `working_stash_capacity` formula in
  `runtime/uo-evm/src/generated_oram_codecs.rs`)
- `deployedJACMTailBoundExpression`:
  `P[stash size > R] <= 14 * 0.6002^R` (the JACM Theorem 5.1
  exponential tail bound at `Z = 5`)
- `deployedParametersFile`: `crates/uo-core/src/manifest.rs`
- `staticDriftCheckName`:
  `path_oram_deployed_stash_parameters_pinned`

The bundle method-style projection
`PathOramLocalPosmapV1SecurityAssumptions.stashOverflowProvenance`
returns `pathOramLocalPosmapV1_stashOverflowProvenance` for any bundle
instance: the deployed Path-ORAM parameter regime is fixed at the
manifest source. The named
`proofGrade_path_oram_local_posmap_v1_stash_overflow_provenance_*`
facades in `ProofGrade.lean` expose the bucket-size pinning, the
repo-equality fact, and the named static-drift check.

The probe-side `path_oram_deployed_stash_parameters_pinned` static-drift
check (in `run_kernel_model_alignment_validation`) rejects representative
drift in `crates/uo-core/src/manifest.rs`: it pins both the construction
sites (`let blocks_per_bucket = 5usize;`,
`let stash_bound = capacity.max(1);`) and the validation sites
(`if self.blocks_per_bucket != 5`, `if self.stash_bound != capacity.max(1)`).

After W5.3, the WP5 claim taxonomy classifies `stashOverflowBounded`
as **Cited / externally justified**: the assumption remains explicit in
`PathOramLocalPosmapV1SecurityAssumptions`, but it is paired with the
explicit JACM 2018 Theorem 5.1 + CCS 2013 fallback citations, the
deployed parameter substitution, and the named probe drift check.

## W5.4 Crypto Provenance Pairing

The Lean side now pairs the encryption assumptions with explicit
provenance metadata. The structure
[`PathOramLocalPosmapV1CryptoProvenance`](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1.lean)
carries:

- `primitive`: `chacha20poly1305::ChaCha20Poly1305`
- `rfcCitation`: RFC 8439 (Nir, Langley 2018)
- `aeadCompositionAnalysisCitation`: Procter 2014 (IACR ePrint
  2014/613)
- `staticDriftCheckName`: `runtime_crypto_primitive_identity_pinned`
- `cipherKeyBytes`: 32 (matching
  `RuntimeStoreCodecSemantics.cipherKeyBytes`)
- `nonceBytes`: 12 (matching `sealedNonceBytes`)
- `tagBytes`: 16 (matching `sealedTagBytes`)

The bundle method-style projection
`PathOramLocalPosmapV1SecurityAssumptions.cryptoProvenance` returns
`pathOramLocalPosmapV1_cryptoProvenance` for any bundle instance: the
Rust crypto primitive identity is fixed at the source level, so the
provenance pairing is the same regardless of which logical assumption
bundle is plugged in. The named
`proofGrade_path_oram_local_posmap_v1_crypto_provenance_*` facades in
`ProofGrade.lean` expose the constant-value pinning facts (32-byte key,
12-byte nonce, 16-byte tag, named static-drift check) on the
paper-facing surface.

After W5.4, the WP5 claim taxonomy classifies the encryption
assumptions as **Cited / externally justified**: the assumptions remain
explicit in `PathOramLocalPosmapV1SecurityAssumptions`, but they are
paired with the explicit RFC 8439 + Procter 2014 citations and the
named probe drift check.

## W5.6 Bundle-Closure Audit

After W5.3 + W5.4 land, the explicit
`PathOramLocalPosmapV1SecurityAssumptions` bundle has exactly three
fields, each paired with an explicit provenance route:

| Field | Provenance record | Static-drift check | Classification |
| --- | --- | --- | --- |
| `bucketEncryptionINDCPA` | `pathOramLocalPosmapV1_cryptoProvenance` | `runtime_crypto_primitive_identity_pinned` | Cited / externally justified |
| `metadataEncryptionINDCPA` | `pathOramLocalPosmapV1_cryptoProvenance` | `runtime_crypto_primitive_identity_pinned` | Cited / externally justified |
| `stashOverflowBounded` | `pathOramLocalPosmapV1_stashOverflowProvenance` | `path_oram_deployed_stash_parameters_pinned` | Cited / externally justified |

The Lean structure
[`PathOramLocalPosmapV1AssumptionAuditEntry`](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/PathOramLocalPosmapV1.lean)
records this audit summary as a checked list:

- `pathOramLocalPosmapV1_assumptionAudit` is a 3-element list of
  audit entries.
- `pathOramLocalPosmapV1_assumptionAudit_length : ... .length = 3`
  pins the entry count to match the bundle field count.
- `pathOramLocalPosmapV1_assumptionAudit_allCited` proves every entry
  is **Cited / externally justified** — no convenience-engineering
  fields, no source-frozen-only fields, and no Lean-discharged fields
  remain.

The audit is exposed on the paper-facing surface through
[`proofGrade_path_oram_local_posmap_v1_assumption_audit_length`](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ProofGrade.lean)
and
[`proofGrade_path_oram_local_posmap_v1_assumption_audit_all_cited`](/home/m285xu/update-oblivious-toolchain/proof/lean/UOToolchain/ProofGrade.lean).

After W5.6, the W5.1 / W5.2 import-vs-companion mechanization fork was
resolved in favor of the citation route on 2026-04-27. The user
selected the **Cited / externally justified** route as the paper-main
provenance, closing WP5 in the practical sense. W5.1 and W5.2 remain
documented as future strengthening in
`docs/stronger-import-route-feasibility.md` but are no longer open
in-scope tasks. Subsequent agents should not re-open them without an
explicit user redirect.

## Next Non-Doc Step

The next non-documentation step for the current paper is no longer figuring out
what to cite. It is just executing the citation-route writeup cleanly. The
stronger import route remains future work.

For a more explicit go / no-go evaluation of the stronger import route, see
`docs/stronger-import-route-feasibility.md`.
