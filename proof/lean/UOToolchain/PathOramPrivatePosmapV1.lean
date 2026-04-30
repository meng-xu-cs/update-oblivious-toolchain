import UOToolchain.PaperMainTheorem
import UOToolchain.ScalablePathOramEvidence
import UOToolchain.TranslationValidationJson

/-!
# Private-position-map Path ORAM theorem route

This module closes the theorem-facing route for
`path_oram_private_posmap_v1`.  The private position-map variant uses the same
standard Path ORAM security assumptions as the local-position-map route, but
adds a compact symbolic certificate for the recursive private metadata shape.
The certificate is proof-relevant: accepted-package theorems below require the
certificate validator and the manifest-matching obligations before exposing the
paper-main noninterference conclusion.
-/

namespace UOToolchain

structure PathOramPrivatePosmapV1SecurityAssumptions where
  localPosmapAssumptions : PathOramLocalPosmapV1SecurityAssumptions

def PathOramPrivatePosmapV1SecurityAssumptions.toPathOramSecurityAssumptions
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions) :
  PathOramSecurityAssumptions :=
  assumptions.localPosmapAssumptions.toPathOramSecurityAssumptions

abbrev pathOramPrivatePosmapV1SecurityInterface
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions) :
  OramSecurityInterface :=
  proofGradePathOramSecurityInterface
    assumptions.toPathOramSecurityAssumptions

abbrev pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions) :
  SGXProofRelation :=
  oramNormalizedObservedSGXProofRelationWith
    (pathOramPrivatePosmapV1SecurityInterface assumptions)

def ScalablePathOramCertificate.PrivatePosmapV1Valid
  (cert : ScalablePathOramCertificate) : Prop :=
  cert.scheme = privatePosmapScheme ∧
    0 < cert.capacity ∧
    cert.capacity ≤ cert.leafCount ∧
    cert.recursionDepth = 1 ∧
    cert.certificateWords =
      6 + Nat.log2 cert.capacity + Nat.log2 cert.leafCount ∧
    cert.validationSteps =
      2 + Nat.log2 cert.capacity + Nat.log2 cert.leafCount

instance (cert : ScalablePathOramCertificate) :
    Decidable cert.PrivatePosmapV1Valid := by
  unfold ScalablePathOramCertificate.PrivatePosmapV1Valid
  infer_instance

def ScalablePathOramCertificate.checkPrivatePosmapV1Valid
  (cert : ScalablePathOramCertificate) : Bool :=
  decide cert.PrivatePosmapV1Valid

@[simp] theorem scalablePathOramCertificate_checkPrivatePosmapV1Valid_eq_true_iff
  (cert : ScalablePathOramCertificate) :
  cert.checkPrivatePosmapV1Valid = true ↔ cert.PrivatePosmapV1Valid := by
  simp [ScalablePathOramCertificate.checkPrivatePosmapV1Valid]

theorem symbolicPrivatePosmapCertificate_valid
  {capacity leafCount : Nat}
  (hCapacity : 0 < capacity)
  (hLeaf : capacity ≤ leafCount) :
  (symbolicPrivatePosmapCertificate capacity leafCount).PrivatePosmapV1Valid := by
  simp [ScalablePathOramCertificate.PrivatePosmapV1Valid,
    symbolicPrivatePosmapCertificate, privatePosmapScheme, hCapacity, hLeaf]

structure PrivatePosmapLevel where
  level : Nat
  capacity : Nat
  leafCount : Nat
  metadataPages : Nat
deriving Repr, DecidableEq

def PrivatePosmapLevel.WellFormed (level : PrivatePosmapLevel) : Prop :=
  0 < level.capacity ∧ level.capacity ≤ level.leafCount

def privatePosmapLevels
  (cert : ScalablePathOramCertificate) : List PrivatePosmapLevel :=
  [ { level := 0
    , capacity := cert.capacity
    , leafCount := cert.leafCount
    , metadataPages := cert.validationSteps }
  , { level := 1
    , capacity := cert.leafCount
    , leafCount := cert.leafCount
    , metadataPages := cert.recursionDepth }
  ]

structure PrivatePosmapRecursiveSemantics where
  certificate : ScalablePathOramCertificate
  levels : List PrivatePosmapLevel
  levelsAreCertificateShape : levels = privatePosmapLevels certificate
deriving Repr, DecidableEq

def PrivatePosmapRecursiveSemantics.WellFormed
  (semantics : PrivatePosmapRecursiveSemantics) : Prop :=
  semantics.certificate.PrivatePosmapV1Valid ∧
    ∀ level, level ∈ semantics.levels → level.WellFormed

def recursivePrivatePosmapSemantics
  (cert : ScalablePathOramCertificate) : PrivatePosmapRecursiveSemantics :=
  { certificate := cert
  , levels := privatePosmapLevels cert
  , levelsAreCertificateShape := rfl
  }

theorem recursivePrivatePosmapSemantics_wellFormed
  {cert : ScalablePathOramCertificate}
  (hCert : cert.PrivatePosmapV1Valid) :
  (recursivePrivatePosmapSemantics cert).WellFormed := by
  rcases hCert with
    ⟨hScheme, hCapacity, hCapacityLeaf, hDepth, hWords, hSteps⟩
  refine ⟨⟨hScheme, hCapacity, hCapacityLeaf, hDepth, hWords, hSteps⟩, ?_⟩
  intro level hMem
  simp [recursivePrivatePosmapSemantics, privatePosmapLevels,
    PrivatePosmapLevel.WellFormed] at hMem ⊢
  rcases hMem with hLevel | hLevel
  · cases hLevel
    exact ⟨hCapacity, hCapacityLeaf⟩
  · cases hLevel
    exact ⟨Nat.lt_of_lt_of_le hCapacity hCapacityLeaf, Nat.le_refl cert.leafCount⟩

def privatePosmapLeakage (cfg : OramConfig) : List OramAccessLeakage :=
  (executionLeakage cfg).filter fun leakage =>
    leakage.scheme == privatePathOramScheme

theorem privatePosmapLeakage_public
  {cfg₁ cfg₂ : OramConfig}
  (hPublic : sameOramPublicProjection cfg₁ cfg₂) :
  privatePosmapLeakage cfg₁ = privatePosmapLeakage cfg₂ := by
  rcases cfg₁ with ⟨pub₁, secretState₁, secretArgs₁⟩
  rcases cfg₂ with ⟨pub₂, secretState₂, secretArgs₂⟩
  simp [sameOramPublicProjection] at hPublic
  subst pub₂
  rfl

def ScalablePathOramCertificate.MatchesObject
  (cert : ScalablePathOramCertificate)
  (object : OramObjectManifest) : Prop :=
  object.scheme = privatePathOramScheme ∧
    cert.scheme = privatePosmapScheme ∧
    cert.capacity = object.capacity ∧
    cert.leafCount = (object.bucketCount + 1) / 2 ∧
    cert.recursionDepth = object.recursionDepth

def ScalablePathOramCertificate.MatchesConfig
  (cert : ScalablePathOramCertificate)
  (cfg : OramConfig) : Prop :=
  ∀ object, object ∈ cfg.pubData.witness.oramObjects →
    object.scheme = privatePathOramScheme →
      cert.MatchesObject object

def ScalablePathOramCertificate.MatchesImportedManifestObject
  (cert : ScalablePathOramCertificate)
  (object : ImportedProofRelevantManifestObjectView) : Prop :=
  ∃ capacity oram,
    object.kind = "map" ∧
      object.backend = "oram" ∧
      object.capacity = some capacity ∧
      object.oram = some oram ∧
      oram.scheme = translationPathOramPrivatePosmapScheme ∧
      cert.scheme = privatePosmapScheme ∧
      cert.capacity = capacity ∧
      cert.leafCount = (oram.bucket_count + 1) / 2 ∧
      cert.recursionDepth = oram.recursion_depth

def privatePosmapCertificateForImportedManifestObject?
  (object : ImportedProofRelevantManifestObjectView) :
  Option ScalablePathOramCertificate :=
  match object.capacity, object.oram with
  | some capacity, some oram =>
      if object.kind == "map" &&
          object.backend == "oram" &&
          oram.scheme == translationPathOramPrivatePosmapScheme then
        some
          { scheme := privatePosmapScheme
          , capacity
          , leafCount := (oram.bucket_count + 1) / 2
          , recursionDepth := oram.recursion_depth
          , certificateWords :=
              6 + Nat.log2 capacity + Nat.log2 ((oram.bucket_count + 1) / 2)
          , validationSteps :=
              2 + Nat.log2 capacity + Nat.log2 ((oram.bucket_count + 1) / 2)
          }
      else
        none
  | _, _ => none

def ImportedProofRelevantTranslationBundle.PrivatePosmapCertificatesValidated
  (bundle : ImportedProofRelevantTranslationBundle) : Prop :=
  ∀ object, object ∈ bundle.artifact_view.manifest.objects →
    ∀ cert,
      privatePosmapCertificateForImportedManifestObject? object = some cert →
        cert.PrivatePosmapV1Valid ∧
          cert.MatchesImportedManifestObject object

structure PathOramPrivatePosmapV1CertificateEvidence
  (cert : ScalablePathOramCertificate) where
  valid : cert.PrivatePosmapV1Valid
  subenumerative : cert.Subenumerative
  recursiveSemanticsWellFormed :
    (recursivePrivatePosmapSemantics cert).WellFormed

structure PathOramPrivatePosmapV1BundleCertificate
  {modelTags : SGXModelTags}
  (cert : ScalablePathOramCertificate)
  (_bundle : SeededRuntimePathOramProofBundle modelTags) where
  evidence : PathOramPrivatePosmapV1CertificateEvidence cert
  matchesPublicConfig :
    ∀ cfg, cert.MatchesConfig cfg

theorem SeededRuntimePathOramProofBundle.pathOramPrivatePosmapV1_computationalUOWith
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePathOramProofBundle modelTags)
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  {cert : ScalablePathOramCertificate}
  (_certificate : PathOramPrivatePosmapV1BundleCertificate cert bundle) :
  ComputationalUOWith
    (pathOramPrivatePosmapV1SecurityInterface assumptions)
    bundle.run := by
  unfold pathOramPrivatePosmapV1SecurityInterface
  simp [PathOramPrivatePosmapV1SecurityAssumptions.toPathOramSecurityAssumptions]
  simpa using
    bundle.computationalUOWith
      assumptions.localPosmapAssumptions.toCanonicalLeafValueSecurityAssumptions

abbrev PathOramPrivatePosmapV1StorageComponentIndistinguishable
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  (storage₁ storage₂ : Distribution SGXStorageTrace)
  (leakage : List OramAccessLeakage) : Prop :=
  (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions).storageRel
    storage₁
    storage₂
    leakage

structure PaperMainPathOramPrivatePosmapV1NoninterferenceConclusion
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  (run : SGXSemantics OramConfig)
  (storageLeakage : OramConfig → List OramAccessLeakage)
  (microLeakage : OramConfig → SGXMicroLeakage)
  (finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback)
  (releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions)
  (cfg₁ cfg₂ : OramConfig) : Prop where
  publicOutcome :
    ExactProjectionRelation sgxPublicOutcome (run cfg₁) (run cfg₂)
  boundarySchedule :
    ExactProjectionRelation (fun view : SGXView => view.boundarySchedule)
      (run cfg₁)
      (run cfg₂)
  storageTrace :
    PathOramPrivatePosmapV1StorageComponentIndistinguishable
      assumptions
      (sgxStorageDistribution (run cfg₁))
      (sgxStorageDistribution (run cfg₂))
      (storageLeakage cfg₁)
  microTrace :
    (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions).microRel
      (sgxMicroDistribution (run cfg₁))
      (sgxMicroDistribution (run cfg₂))
      (microLeakage cfg₁)
  finalPublicStateRollback :
    finalPublicStateRollback cfg₁ = finalPublicStateRollback cfg₂
  releaseFunctions :
    releaseFunctions cfg₁ = releaseFunctions cfg₂

theorem paperMain_pathOramPrivatePosmapV1_noninterference
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  {run : OramSemantics}
  {publicOutcome : OramConfig → SGXPublicOutcome}
  {boundarySchedule : OramConfig → List BoundaryEvent}
  {modelTags : SGXModelTags}
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hOram :
    ComputationalUOWith
      (pathOramPrivatePosmapV1SecurityInterface assumptions)
      run)
  (hOutcome : OramPublicOutcomeSafe publicOutcome)
  (hBoundary : OramPublicBoundarySafe boundarySchedule)
  (hFinal :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramPrivatePosmapV1NoninterferenceConclusion
    assumptions
    (oramToSGXSemantics
      run
      publicOutcome
      boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage publicOutcome modelTags)
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  have hSGX :
      SGXViewRelation
        (pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation assumptions)
        ((oramToSGXSemantics
          run
          publicOutcome
          boundarySchedule
          oramControllerMicroTrace) cfg₁)
        ((oramToSGXSemantics
          run
          publicOutcome
          boundarySchedule
          oramControllerMicroTrace) cfg₂)
        (executionLeakage cfg₁)
        ((oramMicroLeakage publicOutcome modelTags) cfg₁) := by
    unfold pathOramPrivatePosmapV1NormalizedObservedSGXProofRelation
    exact
      paperMain_computationalUOWith_projects_to_sgxExecution
        (pathOramPrivatePosmapV1SecurityInterface assumptions)
        hOram
        hOutcome
        hBoundary
        cfg₁
        cfg₂
        hPublic
  exact
    { publicOutcome := hSGX.1
    , boundarySchedule := hSGX.2.1
    , storageTrace := hSGX.2.2.1
    , microTrace := hSGX.2.2.2
    , finalPublicStateRollback := hFinal cfg₁ cfg₂ hPublic
    , releaseFunctions := hRelease cfg₁ cfg₂ hPublic
    }

theorem SeededRuntimePaperMainBundle.pathOramPrivatePosmapV1_paperMain_noninterference
  {modelTags : SGXModelTags}
  (bundle : SeededRuntimePaperMainBundle modelTags)
  (assumptions : PathOramPrivatePosmapV1SecurityAssumptions)
  {cert : ScalablePathOramCertificate}
  (certificate :
    PathOramPrivatePosmapV1BundleCertificate
      cert
      bundle.toSeededRuntimePathOramProofBundle)
  {finalPublicStateRollback :
    OramConfig → PaperMainFinalPublicStateRollback}
  {releaseFunctions :
    OramConfig → PaperMainDeclaredReleaseFunctions}
  (hFinal :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      finalPublicStateRollback)
  (hRelease :
    PaperMainPublicFieldSafe
      sameOramPublicProjection
      releaseFunctions)
  {cfg₁ cfg₂ : OramConfig}
  (hPublic :
    PaperMainPathOramSameAdmittedPackagePublicInputsAndState cfg₁ cfg₂) :
  PaperMainPathOramPrivatePosmapV1NoninterferenceConclusion
    assumptions
    (oramToSGXSemantics
      bundle.toSeededRuntimePathOramProofBundle.run
      bundle.publicOutcome
      bundle.boundarySchedule
      oramControllerMicroTrace)
    executionLeakage
    (oramMicroLeakage bundle.publicOutcome modelTags)
    finalPublicStateRollback
    releaseFunctions
    cfg₁
    cfg₂ := by
  exact
    paperMain_pathOramPrivatePosmapV1_noninterference
      assumptions
      (bundle.toSeededRuntimePathOramProofBundle
        |>.pathOramPrivatePosmapV1_computationalUOWith
          assumptions
          certificate)
      bundle.publicOutcomeSafe
      bundle.boundarySafe
      hFinal
      hRelease
      hPublic

end UOToolchain
