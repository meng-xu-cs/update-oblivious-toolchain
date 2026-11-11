import UOToolchain.Composition
import UOToolchain.RuntimeCoins
import UOToolchain.RuntimeStoreCodecSemantics
import UOToolchain.SgxExactProjection
import UOToolchain.SgxJointProjection
import UOToolchain.TeeDeployment

namespace UOToolchain

/-- Explicit remaining security assumptions for the concrete
`path_oram_local_posmap_v1` backend candidate. The canonical leaf-value
realization is no longer an additional assumption here; it is discharged by the
runtime-family bundle interface, so the remaining backend assumptions are only
the encryption and stash components. -/
structure PathOramLocalPosmapV1SecurityAssumptions where
  bucketEncryptionINDCPA : Prop
  metadataEncryptionINDCPA : Prop
  stashOverflowBounded : Prop

/-! ### W5.4: Cryptographic-assumption provenance

The two encryption assumptions in the bundle
(`bucketEncryptionINDCPA` and `metadataEncryptionINDCPA`) are the
load-bearing IND-CPA confidentiality hypotheses for the concrete
sealed-record AEAD primitive used by the runtime. The runtime uses
RFC 8439 ChaCha20-Poly1305 over a 32-byte key with fresh 12-byte nonces
and 16-byte detached tags (see
`runtime/uo-store/src/generated_surface.rs`). The probe's
`runtime_crypto_primitive_identity_pinned` static-drift check pins the
Rust source still uses this primitive; the Lean codec semantics layer
(`RuntimeStoreCodecSemantics`) pins the corresponding shape obligations.

The provenance structure below pairs the encryption assumptions with
explicit citation markers for the primitive (RFC 8439) and the
published AEAD-security analysis used to instantiate them
(Procter ePrint 2014/613). The structure is metadata-only: it does not
discharge the assumptions, but it documents the exact provenance route
the WP5 paper-facing claim takes. The provenance stays paired with the
explicit `PathOramLocalPosmapV1SecurityAssumptions` bundle as a
**Cited / externally justified** provenance entry per the WP5 claim
taxonomy. -/

/-- Explicit cryptographic-provenance metadata for the
`path_oram_local_posmap_v1` runtime's confidentiality-assumption
primitives. This is the citation marker structure paired with the
explicit `bucketEncryptionINDCPA` and `metadataEncryptionINDCPA`
assumptions: it carries the primitive identifier, the IETF specification
reference, the published AEAD-security analysis citation, the static-
drift check name pinning the Rust source, and the constants pinned by
the codec semantics layer. -/
structure PathOramLocalPosmapV1CryptoProvenance where
  /-- Primitive identifier as it appears in the Rust source. -/
  primitive : String
  /-- IETF RFC defining the primitive. -/
  rfcCitation : String
  /-- BibTeX key for the RFC entry in
  `docs/path-oram-theorem-sources.bib`. -/
  rfcBibKey : String
  /-- Citation for the published AEAD-security analysis used to
  instantiate the IND-CPA assumption against the concrete primitive. -/
  aeadCompositionAnalysisCitation : String
  /-- BibTeX key for the AEAD composition-analysis entry in
  `docs/path-oram-theorem-sources.bib`. -/
  aeadCompositionAnalysisBibKey : String
  /-- Probe static-drift check that pins the Rust source still uses the
  cited primitive. -/
  staticDriftCheckName : String
  /-- Codec-key length in bytes pinned by the Lean
  `RuntimeStoreCodecSemantics.cipherKeyBytes` constant. -/
  cipherKeyBytes : Nat
  /-- AEAD nonce length in bytes pinned by the Lean
  `RuntimeStoreCodecSemantics.sealedNonceBytes` constant. -/
  nonceBytes : Nat
  /-- AEAD authentication-tag length in bytes pinned by the Lean
  `RuntimeStoreCodecSemantics.sealedTagBytes` constant. -/
  tagBytes : Nat
deriving Repr, DecidableEq

/-- The actual cryptographic provenance record for the
`path_oram_local_posmap_v1` runtime: ChaCha20-Poly1305 AEAD as specified
in RFC 8439 (Nir, Langley 2018), with composition security analyzed by
Procter (IACR ePrint 2014/613). The probe's
`runtime_crypto_primitive_identity_pinned` static-drift check pins the
Rust crypto surface still uses this primitive; the Lean codec semantic
constants pin the corresponding 32-byte key, 12-byte nonce, and
16-byte tag size obligations. -/
def pathOramLocalPosmapV1_cryptoProvenance :
    PathOramLocalPosmapV1CryptoProvenance :=
  { primitive := "chacha20poly1305::ChaCha20Poly1305"
  , rfcCitation :=
      "RFC 8439 (Nir, Langley 2018). ChaCha20 and Poly1305 for IETF Protocols."
  , rfcBibKey := "RFC8439"
  , aeadCompositionAnalysisCitation :=
      "Procter 2014. A Security Analysis of the Composition of ChaCha20 and Poly1305. IACR Cryptology ePrint 2014/613."
  , aeadCompositionAnalysisBibKey := "Procter2014ChaCha20Poly1305Analysis"
  , staticDriftCheckName := "runtime_crypto_primitive_identity_pinned"
  , cipherKeyBytes := RuntimeStoreCodecSemantics.cipherKeyBytes
  , nonceBytes := RuntimeStoreCodecSemantics.sealedNonceBytes
  , tagBytes := RuntimeStoreCodecSemantics.sealedTagBytes
  }

/-- Assumption-bundle method-style projection: every concrete instance of
`PathOramLocalPosmapV1SecurityAssumptions` is paired with the same
runtime-pinned cryptographic provenance record. The runtime crypto
primitive identity is fixed by the source; this projection makes the
provenance pairing accessible via dot notation on any bundle value. -/
def PathOramLocalPosmapV1SecurityAssumptions.cryptoProvenance
    (_ : PathOramLocalPosmapV1SecurityAssumptions) :
    PathOramLocalPosmapV1CryptoProvenance :=
  pathOramLocalPosmapV1_cryptoProvenance

/-- The provenance record's pinned cipher-key length matches the codec
semantic constant. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_cipherKeyBytes :
    pathOramLocalPosmapV1_cryptoProvenance.cipherKeyBytes =
      RuntimeStoreCodecSemantics.cipherKeyBytes := by
  rfl

/-- The provenance record's pinned nonce length matches the codec
semantic constant. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_nonceBytes :
    pathOramLocalPosmapV1_cryptoProvenance.nonceBytes =
      RuntimeStoreCodecSemantics.sealedNonceBytes := by
  rfl

/-- The provenance record's pinned tag length matches the codec
semantic constant. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_tagBytes :
    pathOramLocalPosmapV1_cryptoProvenance.tagBytes =
      RuntimeStoreCodecSemantics.sealedTagBytes := by
  rfl

/-- The provenance record's pinned cipher-key length is exactly 32 bytes,
matching RFC 8439 section 2.5 (256-bit ChaCha20-Poly1305 key) and the
Rust `key: [u8; 32]` buffer. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_cipherKeyBytes_value :
    pathOramLocalPosmapV1_cryptoProvenance.cipherKeyBytes = 32 := by
  rfl

/-- The provenance record's pinned nonce length is exactly 12 bytes,
matching the RFC 8439 ChaCha20-Poly1305 96-bit nonce and the Rust
`Nonce::from_slice` 12-byte requirement. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_nonceBytes_value :
    pathOramLocalPosmapV1_cryptoProvenance.nonceBytes = 12 := by
  rfl

/-- The provenance record's pinned tag length is exactly 16 bytes,
matching the RFC 8439 ChaCha20-Poly1305 128-bit authentication tag and
the Rust `Tag::from_slice(tag_bytes)` requirement. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_tagBytes_value :
    pathOramLocalPosmapV1_cryptoProvenance.tagBytes = 16 := by
  rfl

/-- The provenance record references the
`runtime_crypto_primitive_identity_pinned` probe static-drift check.
This is the named hook that rejects representative drift if the Rust
crypto surface stops using ChaCha20-Poly1305. -/
theorem pathOramLocalPosmapV1_cryptoProvenance_staticDriftCheckName :
    pathOramLocalPosmapV1_cryptoProvenance.staticDriftCheckName =
      "runtime_crypto_primitive_identity_pinned" := by
  rfl

/-- The provenance projection on the assumption bundle returns the
runtime-pinned provenance record, regardless of which bundle instance is
chosen. The Rust crypto primitive identity is fixed at the source level;
the bundle projection only exposes that fact at the type level. -/
theorem PathOramLocalPosmapV1SecurityAssumptions.cryptoProvenance_pinned
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
    assumptions.cryptoProvenance = pathOramLocalPosmapV1_cryptoProvenance := by
  rfl

/-! ### W5.3: Stash-overflow provenance for the deployed parameter regime

The `stashOverflowBounded` assumption captures the Path-ORAM stash-overflow
tail bound from Stefanov et al. JACM 2018 Theorem 5.1 (with CCS 2013 as the
fallback citation), specialized to the deployed parameter regime:

- bucket size `Z = 5` (matching `pathOramJACMBlocksPerBucket`,
  `pathOramBlocksPerBucket`, and the deployed `blocks_per_bucket = 5usize`
  in `crates/uo-core/src/manifest.rs`)
- stash bound formula `min(max(capacity, 1), 114)` (`pathOramStashBound`,
  matching the deployed `path_oram_stash_bound` in
  `crates/uo-core/src/manifest.rs`)
- working stash capacity `stash_bound + buckets_per_access *
  blocks_per_bucket` (the Rust `working_stash_capacity` formula in
  `runtime/uo-evm/src/generated_oram_codecs.rs`)
- for `path_oram_private_posmap_v1`, whose oblivious AVL tree holds each
  node an operation reads in the enclave until the operation ends and then
  returns it to the stash (the deferred write-back of Wang et al., Oblivious
  Data Structures, CCS 2014), the stash bound formula
  `min(max(capacity, 1), 114 + 3h + 1)` (`pathOramTreeStashBound`, matching
  `path_oram_tree_stash_bound`), where `h` is the largest height of an AVL
  tree of `capacity` nodes and `3h + 1` the node accesses of a put: room for
  the nodes an operation returns beside the 114 blocks of the Path ORAM bound

Under these parameters, JACM Theorem 5.1 gives an exponentially small
upper bound on stash-overflow probability: at bucket size `Z = 5` and
stash size `R` the failure probability is bounded by `14 * 0.6002^R`
after any polynomially-bounded access trace. The cap `R = 114` makes this
at most `2^-80` per access, and a map no larger than the cap cannot overflow
its stash. For the private scheme the assumption is that the stash holds at
most 114 blocks besides the nodes the last operation returned to it, with
the same tail; the theorem is stated for one access at a time, so this
transfer to operations that hold their nodes until they end is assumed, not
proved. The repository keeps
`stashOverflowBounded` as an explicit `Prop` taken on faith from this
literature theorem; the W5.3 work pairs the assumption with the
deployed-parameter substitution and the named static-drift check that
pins the parameter regime in the runtime source. -/

/-- Explicit stash-overflow-provenance metadata for the
`path_oram_local_posmap_v1` runtime's `stashOverflowBounded`
confidentiality-assumption. This is the citation marker structure
paired with the explicit `stashOverflowBounded` assumption: it carries
the JACM 2018 citation + theorem reference, the fallback CCS 2013
citation, the deployed parameter values, the deployed stash-bound
formula, the working-stash capacity formula, the JACM 5.1 tail-bound
expression at the deployed bucket size, and the static-drift check
name pinning the deployed parameters in the Rust source. -/
structure PathOramLocalPosmapV1StashOverflowProvenance where
  /-- BibTeX key for the primary JACM 2018 source. -/
  primaryCitationBibKey : String
  /-- Human-readable primary citation. -/
  primaryCitation : String
  /-- Specific theorem reference within the primary source. -/
  primaryTheoremReference : String
  /-- BibTeX key for the fallback CCS 2013 source. -/
  fallbackCitationBibKey : String
  /-- Human-readable fallback citation. -/
  fallbackCitation : String
  /-- Deployed Path-ORAM bucket size (`Z`), pinned by the manifest. -/
  deployedBlocksPerBucket : Nat
  /-- Description of the deployed stash-bound formula. -/
  deployedStashBoundFormula : String
  /-- Description of the working-stash capacity formula consumed by the
  Rust runtime. -/
  workingStashCapacityFormula : String
  /-- Tail-bound expression for the deployed parameter regime, restated
  from JACM Theorem 5.1 at `Z = 5`. -/
  deployedJACMTailBoundExpression : String
  /-- File path pinning the deployed parameters in the Rust source. -/
  deployedParametersFile : String
  /-- Probe static-drift check that pins the deployed parameter regime
  in the Rust source. -/
  staticDriftCheckName : String
deriving Repr, DecidableEq

/-- The actual stash-overflow provenance record for the
`path_oram_local_posmap_v1` runtime: JACM 2018 Theorem 5.1 (with CCS 2013
as the fallback), specialized to the deployed bucket size `Z = 5` and
stash bound `min(max(capacity, 1), 114)`. The probe's
`path_oram_deployed_stash_parameters_pinned` static-drift check pins the
Rust manifest still constructs Path-ORAM objects with these parameters;
the JACM tail bound `14 * 0.6002^R` then becomes the literature reference
for stash-overflow negligibility. -/
def pathOramLocalPosmapV1_stashOverflowProvenance :
    PathOramLocalPosmapV1StashOverflowProvenance :=
  { primaryCitationBibKey := "Stefanov2018PathORAM"
  , primaryCitation :=
      "Stefanov, van Dijk, Shi, Chan, Fletcher, Ren, Yu, Devadas (JACM 2018). Path ORAM: An Extremely Simple Oblivious RAM Protocol. Journal of the ACM 65(4), Article 18, April 2018."
  , primaryTheoremReference := "JACM 2018 Theorem 5.1 (stash overflow tail bound)"
  , fallbackCitationBibKey := "Stefanov2013PathORAM"
  , fallbackCitation :=
      "Stefanov, van Dijk, Shi, Fletcher, Ren, Yu, Devadas (CCS 2013). Path ORAM: An Extremely Simple Oblivious RAM Protocol. Proceedings of CCS 2013."
  , deployedBlocksPerBucket := pathOramBlocksPerBucket
  , deployedStashBoundFormula := "stash_bound = min(max(capacity, 1), 114)"
  , workingStashCapacityFormula :=
      "working_stash_capacity = stash_bound + buckets_per_access * blocks_per_bucket"
  , deployedJACMTailBoundExpression :=
      "P[stash size > R] <= 14 * 0.6002^R for Z = 5 (JACM 2018 Theorem 5.1); R = 114 gives <= 2^-80 per access"
  , deployedParametersFile := "crates/uo-core/src/manifest.rs"
  , staticDriftCheckName := "path_oram_deployed_stash_parameters_pinned"
  }

/-- Assumption-bundle method-style projection: every concrete instance of
`PathOramLocalPosmapV1SecurityAssumptions` is paired with the same
runtime-pinned stash-overflow provenance record. The deployed Path-ORAM
parameters are fixed at the manifest source; the bundle projection only
exposes that fact at the type level. -/
def PathOramLocalPosmapV1SecurityAssumptions.stashOverflowProvenance
    (_ : PathOramLocalPosmapV1SecurityAssumptions) :
    PathOramLocalPosmapV1StashOverflowProvenance :=
  pathOramLocalPosmapV1_stashOverflowProvenance

/-- The provenance record's pinned bucket size matches the
implementation-side constant `pathOramBlocksPerBucket = 5`. -/
theorem pathOramLocalPosmapV1_stashOverflowProvenance_deployedBlocksPerBucket :
    pathOramLocalPosmapV1_stashOverflowProvenance.deployedBlocksPerBucket =
      pathOramBlocksPerBucket := by
  rfl

/-- The provenance record's pinned bucket size is exactly 5, matching the
JACM Theorem 5.1 statement (which is stated for `Z = 5`). -/
theorem pathOramLocalPosmapV1_stashOverflowProvenance_deployedBlocksPerBucket_value :
    pathOramLocalPosmapV1_stashOverflowProvenance.deployedBlocksPerBucket = 5 := by
  rfl

/-- The provenance record references the
`path_oram_deployed_stash_parameters_pinned` probe static-drift check.
This is the named hook that rejects representative drift if the Rust
manifest stops constructing Path-ORAM objects with the deployed
`Z = 5` / `stash_bound = min(max(capacity, 1), 114)` parameter regime. -/
theorem pathOramLocalPosmapV1_stashOverflowProvenance_staticDriftCheckName :
    pathOramLocalPosmapV1_stashOverflowProvenance.staticDriftCheckName =
      "path_oram_deployed_stash_parameters_pinned" := by
  rfl

/-- The stash-overflow-provenance projection on the assumption bundle
returns the runtime-pinned provenance record, regardless of which bundle
instance is chosen. The deployed Path-ORAM parameter regime is fixed at
the manifest source; the bundle projection only exposes that fact at
the type level. -/
theorem PathOramLocalPosmapV1SecurityAssumptions.stashOverflowProvenance_pinned
    (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
    assumptions.stashOverflowProvenance =
      pathOramLocalPosmapV1_stashOverflowProvenance := by
  rfl

/-! ### W5.6: Bundle housekeeping audit

After W5.3 (stash-overflow provenance) and W5.4 (crypto-assumption
provenance) land, the explicit
`PathOramLocalPosmapV1SecurityAssumptions` bundle has exactly three
fields, each paired with an explicit provenance route:

- `bucketEncryptionINDCPA` — paired with
  `pathOramLocalPosmapV1_cryptoProvenance` (RFC 8439 + Procter 2014,
  drift-checked by `runtime_crypto_primitive_identity_pinned`)
- `metadataEncryptionINDCPA` — paired with the same
  `pathOramLocalPosmapV1_cryptoProvenance` record
- `stashOverflowBounded` — paired with
  `pathOramLocalPosmapV1_stashOverflowProvenance` (JACM 2018
  Theorem 5.1 at `Z = 5`, fallback CCS 2013, drift-checked by
  `path_oram_deployed_stash_parameters_pinned`)

The earlier "canonical leaf-value realization" assumption was
discharged by the runtime-family bundle interface and removed from this
structure, so each of the three surviving fields is concrete (specific
probabilistic / cryptographic claim), justified (explicit provenance
citation), and unavoidable (cannot be discharged by Lean proofs alone
in this repo without bringing in formal cryptography or formalizing the
JACM stash analysis).

The audit structure below records the W5.6 closure summary at the Lean
type level. It documents that no further bundle housekeeping is
available without either landing a fully formal cryptography proof or
landing the W5.1 / W5.2 import-vs-companion mechanization decision. -/

/-- Audit-record summary entry for one explicit assumption in the
`PathOramLocalPosmapV1SecurityAssumptions` bundle. Pairs the
assumption's role with the provenance route name and the named probe
static-drift check that pins the corresponding runtime source. -/
structure PathOramLocalPosmapV1AssumptionAuditEntry where
  /-- Assumption-bundle field name. -/
  fieldName : String
  /-- Plain-language description of the assumption's role. -/
  role : String
  /-- WP5 claim taxonomy classification ("Cited / externally
  justified"). -/
  classification : String
  /-- Lean provenance record name carrying the citation marker. -/
  provenanceRecordName : String
  /-- Probe static-drift check name pinning the runtime source. -/
  staticDriftCheckName : String
deriving Repr, DecidableEq

/-- W5.6 closure summary: the three surviving assumptions in the
`PathOramLocalPosmapV1SecurityAssumptions` bundle plus their
post-W5.3 / post-W5.4 provenance pairings. Every entry is **Cited /
externally justified**; no convenience-engineering fields remain. -/
def pathOramLocalPosmapV1_assumptionAudit :
    List PathOramLocalPosmapV1AssumptionAuditEntry :=
  [ { fieldName := "bucketEncryptionINDCPA"
    , role := "hides bucket/path ciphertext contents in the concrete path_oram_local_posmap_v1 backend"
    , classification := "Cited / externally justified"
    , provenanceRecordName := "pathOramLocalPosmapV1_cryptoProvenance"
    , staticDriftCheckName := "runtime_crypto_primitive_identity_pinned"
    }
  , { fieldName := "metadataEncryptionINDCPA"
    , role := "hides encrypted position-map metadata pages in the local-posmap wrapper"
    , classification := "Cited / externally justified"
    , provenanceRecordName := "pathOramLocalPosmapV1_cryptoProvenance"
    , staticDriftCheckName := "runtime_crypto_primitive_identity_pinned"
    }
  , { fieldName := "stashOverflowBounded"
    , role := "bounds stash-overflow failure for the deployed local-posmap parameters (JACM 2018 Theorem 5.1 at Z = 5)"
    , classification := "Cited / externally justified"
    , provenanceRecordName := "pathOramLocalPosmapV1_stashOverflowProvenance"
    , staticDriftCheckName := "path_oram_deployed_stash_parameters_pinned"
    }
  ]

/-- The W5.6 audit summary contains exactly three entries, matching the
three surviving fields of `PathOramLocalPosmapV1SecurityAssumptions`.
This pin makes the audit conclusion mechanically checkable: any future
addition to the bundle that does not also extend the audit list will
fail this length check. -/
theorem pathOramLocalPosmapV1_assumptionAudit_length :
    pathOramLocalPosmapV1_assumptionAudit.length = 3 := by
  rfl

/-- Every entry in the W5.6 audit summary is classified as
"Cited / externally justified". This pin documents the W5.6 closure
condition: no convenience-engineering fields, no
"trusted-without-citation" fields, and no Lean-discharged fields remain
in the bundle. -/
theorem pathOramLocalPosmapV1_assumptionAudit_allCited :
    ∀ entry, entry ∈ pathOramLocalPosmapV1_assumptionAudit →
      entry.classification = "Cited / externally justified" := by
  intro entry hMem
  unfold pathOramLocalPosmapV1_assumptionAudit at hMem
  simp at hMem
  rcases hMem with h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

def PathOramLocalPosmapV1SecurityAssumptions.toCanonicalLeafValueSecurityAssumptions
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramCanonicalLeafValueSecurityAssumptions :=
  { bucketEncryptionINDCPA := assumptions.bucketEncryptionINDCPA
  , metadataEncryptionINDCPA := assumptions.metadataEncryptionINDCPA
  , stashOverflowBounded := assumptions.stashOverflowBounded
  }

def PathOramLocalPosmapV1SecurityAssumptions.toPathOramSecurityAssumptions
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramSecurityAssumptions := by
  let leafValue :=
    assumptions.toCanonicalLeafValueSecurityAssumptions.toPathOramLeafValueSecurityAssumptions
  let leaf := leafValue.toPathOramLeafSecurityAssumptions
  let bucket := leaf.toPathOramBucketSecurityAssumptions
  exact bucket.toPathOramSecurityAssumptions

abbrev pathOramLocalPosmapV1SecurityInterface
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : OramSecurityInterface :=
  proofGradePathOramSecurityInterface
    assumptions.toPathOramSecurityAssumptions

abbrev pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : SGXProofRelation :=
  oramNormalizedObservedSGXProofRelationWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)

abbrev pathOramLocalPosmapV1JointObservedSGXProofRelation
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : SGXProofRelation :=
  { storageRel := oramSGXStorageRelationWith (pathOramLocalPosmapV1SecurityInterface assumptions)
  , microRel := normalizedObservedSGXMicroRelation
  }

def oramPublicTermination
  (publicOutcome : OramConfig → SGXPublicOutcome) : OramConfig → Bool :=
  fun cfg => (publicOutcome cfg).terminationStatus

def oramPublicOutputShape
  (publicOutcome : OramConfig → SGXPublicOutcome) : OramConfig → OutputShape :=
  fun cfg => (publicOutcome cfg).outputShape

def SeededRuntimePaperMainBundle.publicTermination
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramConfig → Bool :=
  oramPublicTermination bundle.publicOutcome

def SeededRuntimePaperMainBundle.publicOutputShape
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramConfig → OutputShape :=
  oramPublicOutputShape bundle.publicOutcome

def exactPublicTermination
  (publicOutcome : Config → SGXPublicOutcome) : Config → Bool :=
  fun cfg => (publicOutcome cfg).terminationStatus

def exactPublicOutputShape
  (publicOutcome : Config → SGXPublicOutcome) : Config → OutputShape :=
  fun cfg => (publicOutcome cfg).outputShape

/-- Explicit import boundary for a standard-ORAM theorem specialized to the
concrete `path_oram_local_posmap_v1` candidate. This is the remaining
theorem-discharge interface for the backend itself: once a standard Path ORAM
storage theorem is available at this boundary, the repo's concrete
computational-UO, SGX, and TEE consequences follow without adding any further
backend assumptions. -/
def PathOramLocalPosmapV1StandardStorageBoundary
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (run : OramStorageSemantics) : Prop :=
  (∀ cfg, PathOramConfigWellFormed cfg) ∧
    OramPublicViewSafe publicPart ∧
    ComputationalStandardOramWith
      (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
      run

def PathOramLocalPosmapV1StandardPaperMainBoundary
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (publicPart : OramConfig → OramViewPublicPart)
  (run : OramStorageSemantics)
  (publicOutcome : OramConfig → SGXPublicOutcome)
  (boundarySchedule : OramConfig → List BoundaryEvent) : Prop :=
  ComputationalUOWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (liftOramStorageSemantics publicPart run) ∧
    SGXExecutionSecurity
      sameOramPublicProjection
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics
        (liftOramStorageSemantics publicPart run)
        publicOutcome
        boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage publicOutcome modelTags) ∧
    ComputationalTEEStorageObliviousWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (liftOramStorageSemantics publicPart run)
      (oramPublicTermination publicOutcome)
      (oramPublicOutputShape publicOutcome)

def PathOramLocalPosmapV1PaperTheoremBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) : Prop :=
  ComputationalUOWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      bundle.toSeededRuntimePathOramProofBundle.run ∧
    SGXExecutionSecurity
      sameOramPublicProjection
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics
        bundle.toSeededRuntimePathOramProofBundle.run
        bundle.publicOutcome
        bundle.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage bundle.publicOutcome modelTags) ∧
    ComputationalTEEStorageObliviousWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicTermination
      bundle.publicOutputShape

def PathOramLocalPosmapV1ArtifactPaperMainBoundary
  {modelTags : SGXModelTags}
  (runs : List TraceSemantics)
  (manifest : ManifestWitness)
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (exactOutcome : Config → SGXPublicOutcome)
  (exactBoundarySchedule : Config → List BoundaryEvent)
  (exactControllerShape : Config → SGXControllerShape) : Prop :=
  ArtifactSecurityWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (exactEntrypointSemantics runs manifest)
      bundle.toSeededRuntimePathOramProofBundle.run ∧
    SGXExecutionSecurity
      samePublicProjection
      exactNormalizedObservedSGXProofRelation
      (exactToSGXSemantics
        (exactEntrypointSemantics runs manifest)
        exactOutcome
        exactBoundarySchedule
        (fun cfg => controllerMicroTraceOfShape (exactControllerShape cfg)))
      emptyStorageLeakage
      (exactMicroLeakage exactOutcome exactControllerShape modelTags) ∧
    SGXExecutionSecurity
      sameOramPublicProjection
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      (oramToSGXSemantics
        bundle.toSeededRuntimePathOramProofBundle.run
        bundle.publicOutcome
        bundle.boundarySchedule
        oramControllerMicroTrace)
      executionLeakage
      (oramMicroLeakage bundle.publicOutcome modelTags) ∧
    TEEStorageSecurityWith
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (exactEntrypointSemantics runs manifest)
      (exactPublicTermination exactOutcome)
      (exactPublicOutputShape exactOutcome)
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicTermination
      bundle.publicOutputShape

theorem SeededRuntimePaperMainBundle.publicTerminationSafe
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramPublicTerminationSafe bundle.publicTermination := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.terminationStatus (bundle.publicOutcomeSafe cfg₁ cfg₂ hPublic)

theorem SeededRuntimePaperMainBundle.publicOutputShapeSafe
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags) :
  OramPublicOutputShapeSafe bundle.publicOutputShape := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.outputShape (bundle.publicOutcomeSafe cfg₁ cfg₂ hPublic)

theorem oramPublicTerminationSafe
  {publicOutcome : OramConfig → SGXPublicOutcome}
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  OramPublicTerminationSafe (oramPublicTermination publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.terminationStatus (hOutcome cfg₁ cfg₂ hPublic)

theorem oramPublicOutputShapeSafe
  {publicOutcome : OramConfig → SGXPublicOutcome}
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  OramPublicOutputShapeSafe (oramPublicOutputShape publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.outputShape (hOutcome cfg₁ cfg₂ hPublic)

theorem exactPublicTerminationSafe
  {publicOutcome : Config → SGXPublicOutcome}
  (hOutcome : PublicOutcomeSafe publicOutcome) :
  PublicTerminationSafe (exactPublicTermination publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.terminationStatus (hOutcome cfg₁ cfg₂ hPublic)

theorem exactPublicOutputShapeSafe
  {publicOutcome : Config → SGXPublicOutcome}
  (hOutcome : PublicOutcomeSafe publicOutcome) :
  PublicOutputShapeSafe (exactPublicOutputShape publicOutcome) := by
  intro cfg₁ cfg₂ hPublic
  exact congrArg SGXPublicOutcome.outputShape (hOutcome cfg₁ cfg₂ hPublic)

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ComputationalUOWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    bundle.run := by
  unfold pathOramLocalPosmapV1SecurityInterface
  simp [PathOramLocalPosmapV1SecurityAssumptions.toPathOramSecurityAssumptions]
  simpa using
    bundle.computationalUOWith assumptions.toCanonicalLeafValueSecurityAssumptions

def SeededRuntimePathOramProofBundle.storageRun
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags) : OramStorageSemantics :=
  fun cfg => (bundle.run cfg).map oramStorageView

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageSecurity
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ComputationalStandardOramWith
    (pathOramStandardSecurityInterface assumptions.toPathOramSecurityAssumptions)
    bundle.storageRun := by
  intro cfg₁ cfg₂ hSame
  have hOram :=
    bundle.pathOramLocalPosmapV1_computationalUOWith assumptions cfg₁ cfg₂ hSame
  refine ⟨hOram.1, ?_⟩
  simpa [SeededRuntimePathOramProofBundle.storageRun] using hOram.2.2

theorem SeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1StandardStorageBoundary
    assumptions
    bundle.publicView
    bundle.storageRun := by
  exact
    ⟨ bundle.cfgWellFormed
    , bundle.publicViewSafe
    , bundle.pathOramLocalPosmapV1_standardStorageSecurity assumptions
    ⟩

theorem pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run) :
  ComputationalUOWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    (liftOramStorageSemantics publicPart run) := by
  rcases hStandard with ⟨hCfg, hPublic, hStorage⟩
  apply computationalPathOram_projects_to_computationalUOWith
    assumptions.toPathOramSecurityAssumptions
    hCfg
    hPublic
  intro cfg₁ cfg₂ hSame
  exact (hStorage cfg₁ cfg₂ hSame).2

theorem pathOramLocalPosmapV1_standardStorageBoundary_projects_to_paperMainSgxExecution
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      (liftOramStorageSemantics publicPart run)
      publicOutcome
      boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags) := by
  unfold pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
  simpa using
    paperMain_computationalUOWith_projects_to_sgxExecution
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      (pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
        assumptions
        hStandard)
      hOutcome
      hBoundary

theorem pathOramLocalPosmapV1_standardStorageBoundary_projects_to_teeStorage
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome) :
  ComputationalTEEStorageObliviousWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    (liftOramStorageSemantics publicPart run)
    (oramPublicTermination publicOutcome)
    (oramPublicOutputShape publicOutcome) := by
  apply
    computationalUOWith_projects_to_teeStorage
      (pathOramLocalPosmapV1SecurityInterface assumptions)
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
        assumptions
        hStandard
  · exact oramPublicTerminationSafe hOutcome
  · exact oramPublicOutputShapeSafe hOutcome

theorem pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
  {modelTags : SGXModelTags}
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  (hStandard : PathOramLocalPosmapV1StandardStorageBoundary assumptions publicPart run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    publicPart
    run
    publicOutcome
    boundarySchedule := by
  constructor
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_computationalUOWith
        assumptions
        hStandard
  constructor
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_paperMainSgxExecution
        assumptions
        hStandard
        hOutcome
        hBoundary
  · exact
      pathOramLocalPosmapV1_standardStorageBoundary_projects_to_teeStorage
        assumptions
        hStandard
        hOutcome

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperMainSgxExecution
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags) := by
  unfold pathOramLocalPosmapV1NormalizedObservedSGXProofRelation
  simp [pathOramLocalPosmapV1SecurityInterface,
    PathOramLocalPosmapV1SecurityAssumptions.toPathOramSecurityAssumptions]
  simpa using
    bundle.paperMainSgxExecution assumptions.toCanonicalLeafValueSecurityAssumptions

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_standardPaperMainBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1StandardPaperMainBoundary
    (modelTags := modelTags)
    assumptions
    bundle.publicView
    bundle.toSeededRuntimePathOramProofBundle.storageRun
    bundle.publicOutcome
    bundle.boundarySchedule := by
  exact
    pathOramLocalPosmapV1_standardStorageBoundary_paperTheoremBoundary
      (modelTags := modelTags)
      assumptions
      (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_standardStorageBoundary
        assumptions)
      bundle.publicOutcomeSafe
      bundle.boundarySafe

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_projects_to_teeStorage
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  ComputationalTEEStorageObliviousWith
    (pathOramLocalPosmapV1SecurityInterface assumptions)
    bundle.toSeededRuntimePathOramProofBundle.run
    bundle.publicTermination
    bundle.publicOutputShape := by
  apply
    computationalUOWith_projects_to_teeStorage
      (pathOramLocalPosmapV1SecurityInterface assumptions)
  · exact
      bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
        assumptions
  · exact bundle.publicTerminationSafe
  · exact bundle.publicOutputShapeSafe

theorem SeededRuntimePaperMainBundle.pathOramLocalPosmapV1_paperTheoremBoundary
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
  PathOramLocalPosmapV1PaperTheoremBoundary bundle assumptions := by
  constructor
  · exact
      bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
        assumptions
  constructor
  · exact bundle.pathOramLocalPosmapV1_paperMainSgxExecution assumptions
  · exact bundle.pathOramLocalPosmapV1_projects_to_teeStorage assumptions

theorem pathOramLocalPosmapV1_paperMain_jointSecurity_projects_to_sgxExecution
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  {run : SGXJointSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {microLeakage : OramConfig → SGXMicroLeakage}
  (hStorage :
    ∀ cfg₁ cfg₂,
      sameOramPublicProjection cfg₁ cfg₂ →
      (pathOramLocalPosmapV1SecurityInterface assumptions).localTheorem
        (jointStorageViews (run cfg₁))
        (jointStorageViews (run cfg₂))
        (executionLeakage cfg₁))
  (hMicro :
    ∀ cfg,
      NormalizedByLeakage
        (jointMicroViews (run cfg))
        (microLeakage cfg))
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hMicroLeakage : OramPublicMicroLeakageSafe microLeakage) :
  SGXExecutionSecurity
    sameOramPublicProjection
    (pathOramLocalPosmapV1JointObservedSGXProofRelation assumptions)
    (jointToSGXSemantics run publicOutcome boundarySchedule)
    executionLeakage
    (jointMicroLeakage microLeakage) := by
  exact
    paperMain_jointSecurityWith_projects_to_sgxExecution
      (pathOramLocalPosmapV1SecurityInterface assumptions)
      hStorage
      hMicro
      hOutcome
      hBoundary
      hMicroLeakage

theorem pathOramLocalPosmapV1_artifactPaperMainBoundary
  {modelTags : SGXModelTags}
  (runs : List TraceSemantics)
  (manifest : ManifestWitness)
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramLocalPosmapV1SecurityAssumptions)
  (exactOutcome : Config → SGXPublicOutcome)
  (exactBoundarySchedule : Config → List BoundaryEvent)
  (exactControllerShape : Config → SGXControllerShape)
  (hRuns : ExactUOFamily runs)
  (hExactOutcome : PublicOutcomeSafe exactOutcome)
  (hExactBoundary : PublicBoundarySafe exactBoundarySchedule)
  (hExactController : PublicControllerShapeSafe exactControllerShape) :
  PathOramLocalPosmapV1ArtifactPaperMainBoundary
    runs
    manifest
    bundle
    assumptions
    exactOutcome
    exactBoundarySchedule
    exactControllerShape := by
  have hArtifact :
      ArtifactSecurityWith
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        (exactEntrypointSemantics runs manifest)
        bundle.toSeededRuntimePathOramProofBundle.run := by
    exact
      mixedArtifactCompositionWith
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        runs
        manifest
        hRuns
        bundle.toSeededRuntimePathOramProofBundle.run
        (bundle.toSeededRuntimePathOramProofBundle.pathOramLocalPosmapV1_computationalUOWith
          assumptions)
  constructor
  · exact hArtifact
  constructor
  · exact
      paperMain_exactUO_projects_to_sgxExecution
        (compositionTheorem runs manifest hRuns)
        hExactOutcome
        hExactBoundary
        hExactController
  constructor
  · exact bundle.pathOramLocalPosmapV1_paperMainSgxExecution assumptions
  · exact
      artifactSecurityWith_projects_to_teeStorage
        (pathOramLocalPosmapV1SecurityInterface assumptions)
        hArtifact
        (exactPublicTerminationSafe hExactOutcome)
        (exactPublicOutputShapeSafe hExactOutcome)
        bundle.publicTerminationSafe
        bundle.publicOutputShapeSafe

end UOToolchain
