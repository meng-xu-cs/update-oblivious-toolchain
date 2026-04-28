import UOToolchain.RuntimeImplementationInterface
import UOToolchain.RuntimeCoins
import UOToolchain.SgxObserverFreeze

namespace UOToolchain

/-!
Proof-grade audit surfaces for residual host-visible channels and deployment
assumption plumbing.

These records are intentionally small, explicit taxonomies. They do not claim a
deep Rust semantic refinement. Instead, they give the paper theorem and the
probe one named place to pin:

* every host-visible outcome/failure class left after the runtime boundary cuts;
* every runtime nonce / fresh-coin / diagnostic-randomness surface that feeds a
  formal cryptographic or ORAM freshness assumption; and
* every SGX deployment assumption's mapped mechanism or deployment-only status.
-/

inductive HostVisibleOutcomeKind where
  | success
  | abort
  | runtimePublicError
  | proofCheckerFailure
  | commitRollback
  | cryptographicIntegrityFailure
deriving Repr, DecidableEq

inductive HostVisibleOutcomeClassification where
  | publicDetermined
  | negligibleUnderAssumption
  | explicitlyDeclassified
  | normalizedInternalAbort
deriving Repr, DecidableEq

def HostVisibleOutcomeClassification.isClosed :
    HostVisibleOutcomeClassification -> Bool
  | .publicDetermined => true
  | .negligibleUnderAssumption => true
  | .explicitlyDeclassified => true
  | .normalizedInternalAbort => true

structure HostVisibleOutcomeTaxonomyEntry where
  kind : HostVisibleOutcomeKind
  classification : HostVisibleOutcomeClassification
  hostPayloadRule : String
  normalizationRule : String
  theoremAnchor : String
  probeAnchor : String
deriving Repr, DecidableEq

def HostVisibleOutcomeTaxonomyEntry.closed
    (entry : HostVisibleOutcomeTaxonomyEntry) : Bool :=
  entry.classification.isClosed

def runtimeHostVisibleOutcomeTaxonomy :
    List HostVisibleOutcomeTaxonomyEntry :=
  [ { kind := .success
    , classification := .explicitlyDeclassified
    , hostPayloadRule :=
        "success/status and plaintext return payloads are host-visible only through explicit status/return declassification policy"
    , normalizationRule :=
        "PublicOutcomeTrace carries status_policy, return_policy, return_payload, and declassifies"
    , theoremAnchor :=
        "importedRuntimeImplementationInterface_valid_hostVisibleErrorTaxonomy"
    , probeAnchor :=
        "runtime_host_visible_error_taxonomy_theorem_checked"
    }
  , { kind := .abort
    , classification := .explicitlyDeclassified
    , hostPayloadRule :=
        "abort status is host-visible only through explicit status declassification policy"
    , normalizationRule :=
        "aborted calls clear plaintext returns and record the public/declassified status policy"
    , theoremAnchor :=
        "importedRuntimeImplementationInterface_valid_hostVisibleErrorTaxonomy"
    , probeAnchor :=
        "runtime_host_visible_error_taxonomy_theorem_checked"
    }
  , { kind := .runtimePublicError
    , classification := .publicDetermined
    , hostPayloadRule :=
        "remaining runtime Result errors are public shape, capacity, canonical encoding, or authenticated decode/integrity failures"
    , normalizationRule :=
        "secret-dependent map/stash miss paths are rejected from the host-visible Result surface or absorbed into fixed in-band abort effects"
    , theoremAnchor :=
        "RuntimeImplementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy"
    , probeAnchor :=
        "runtime_implementation_interface_host_visible_error_taxonomy_theorem_present"
    }
  , { kind := .proofCheckerFailure
    , classification := .publicDetermined
    , hostPayloadRule :=
        "checker failures reject public artifacts, witnesses, or source cuts rather than reporting secret runtime data"
    , normalizationRule :=
        "checker routes consume JSON artifacts and named source strings; they do not inspect live secret state"
    , theoremAnchor :=
        "importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_assumptions"
    , probeAnchor :=
        "kernel_model_alignment_validation"
    }
  , { kind := .commitRollback
    , classification := .normalizedInternalAbort
    , hostPayloadRule :=
        "commit, rollback, and no-op commit paths expose only the declared public outcome/status"
    , normalizationRule :=
        "rollback restores old sealed state in band; commit helper failures are public exact-shape failures or fixed abort effects"
    , theoremAnchor :=
        "RuntimeImplementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy"
    , probeAnchor :=
        "runtime_residual_helper_shell_boundary_host_visible_error_taxonomy_theorem_present"
    }
  , { kind := .cryptographicIntegrityFailure
    , classification := .negligibleUnderAssumption
    , hostPayloadRule :=
        "AEAD/open failures are integrity failures under the stated crypto assumptions and never release plaintext failure payloads"
    , normalizationRule :=
        "sealed-record open paths split magic, nonce, ciphertext, and tag by public lengths before authenticated open"
    , theoremAnchor :=
        "pathOramLocalPosmapV1_cryptoProvenance"
    , probeAnchor :=
        "runtime_crypto_primitive_identity_pinned"
    }
  ]

theorem runtimeHostVisibleOutcomeTaxonomy_coversRequiredKinds :
    runtimeHostVisibleOutcomeTaxonomy.map (fun entry => entry.kind) =
      [ HostVisibleOutcomeKind.success
      , HostVisibleOutcomeKind.abort
      , HostVisibleOutcomeKind.runtimePublicError
      , HostVisibleOutcomeKind.proofCheckerFailure
      , HostVisibleOutcomeKind.commitRollback
      , HostVisibleOutcomeKind.cryptographicIntegrityFailure
      ] := by
  rfl

theorem runtimeHostVisibleOutcomeTaxonomy_allClosed :
    forall entry, entry ∈ runtimeHostVisibleOutcomeTaxonomy ->
      entry.closed = true := by
  intro entry hMem
  unfold runtimeHostVisibleOutcomeTaxonomy at hMem
  simp at hMem
  rcases hMem with h | h | h | h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

inductive RuntimeFreshnessSurface where
  | storeEncryptionNonce
  | metadataEncryptionNonce
  | pathOramLeafRemapCoin
  | canonicalFreshCoinProofFamily
  | diagnosticFreshCoinInjection
deriving Repr, DecidableEq

structure RuntimeFreshnessDisciplineEntry where
  surface : RuntimeFreshnessSurface
  domainSeparatedAssociatedData : Bool
  freshPerCallOrSeed : Bool
  productionTheoremModeSafe : Bool
  runtimeAnchor : String
  theoremAnchor : String
  probeAnchor : String
deriving Repr, DecidableEq

def RuntimeFreshnessDisciplineEntry.accepted
    (entry : RuntimeFreshnessDisciplineEntry) : Bool :=
  entry.domainSeparatedAssociatedData &&
    entry.freshPerCallOrSeed &&
    entry.productionTheoremModeSafe

def runtimeFreshnessDiscipline :
    List RuntimeFreshnessDisciplineEntry :=
  [ { surface := .storeEncryptionNonce
    , domainSeparatedAssociatedData := true
    , freshPerCallOrSeed := true
    , productionTheoremModeSafe := true
    , runtimeAnchor :=
        "runtime/uo-store/src/generated_surface.rs seal_and_wipe_into_slice fills SEALED_NONCE_BYTES and authenticates caller AAD"
    , theoremAnchor :=
        "store sealed-record shape/transport theorems"
    , probeAnchor :=
        "store_cipher_uses_exact_size_nonzero_buffers"
    }
  , { surface := .metadataEncryptionNonce
    , domainSeparatedAssociatedData := true
    , freshPerCallOrSeed := true
    , productionTheoremModeSafe := true
    , runtimeAnchor :=
        "runtime/uo-evm/src/oram.rs and generated ORAM codecs use oram metadata/bucket AAD plus StoreCipher nonce generation"
    , theoremAnchor :=
        "pathOramLocalPosmapV1_cryptoProvenance"
    , probeAnchor :=
        "runtime_crypto_primitive_identity_pinned"
    }
  , { surface := .pathOramLeafRemapCoin
    , domainSeparatedAssociatedData := true
    , freshPerCallOrSeed := true
    , productionTheoremModeSafe := true
    , runtimeAnchor :=
        "PathOramLeafCoinSource random/injected tape consumed by object id and step schedule"
    , theoremAnchor :=
        "CanonicalFreshCoinRuntimePathOramWitnessFamily.freshCoinValueDistribution_eq_canonical"
    , probeAnchor :=
        "fresh_coin_validation"
    }
  , { surface := .canonicalFreshCoinProofFamily
    , domainSeparatedAssociatedData := true
    , freshPerCallOrSeed := true
    , productionTheoremModeSafe := true
    , runtimeAnchor :=
        "runtime canonical fresh-coin witness family enumerates one representative seed at a time"
    , theoremAnchor :=
        "CanonicalFreshCoinRuntimePathOramWitnessFamily.freshCoinSeedSpaceExact"
    , probeAnchor :=
        "canonical_fresh_coin_theorem_input_api_is_explicit"
    }
  , { surface := .diagnosticFreshCoinInjection
    , domainSeparatedAssociatedData := true
    , freshPerCallOrSeed := true
    , productionTheoremModeSafe := true
    , runtimeAnchor :=
        "call_with_path_oram_fresh_coins is cfg(feature = diagnostics) and absent from default theorem-facing call"
    , theoremAnchor :=
        "productionSource strips cfg(test) while the proof-grade root imports RuntimeCoins without diagnostics"
    , probeAnchor :=
        "fresh_coin_api_gated_behind_feature"
    }
  ]

theorem runtimeFreshnessDiscipline_coversRuntimeSurfaces :
    runtimeFreshnessDiscipline.map (fun entry => entry.surface) =
      [ RuntimeFreshnessSurface.storeEncryptionNonce
      , RuntimeFreshnessSurface.metadataEncryptionNonce
      , RuntimeFreshnessSurface.pathOramLeafRemapCoin
      , RuntimeFreshnessSurface.canonicalFreshCoinProofFamily
      , RuntimeFreshnessSurface.diagnosticFreshCoinInjection
      ] := by
  rfl

theorem runtimeFreshnessDiscipline_allAccepted :
    forall entry, entry ∈ runtimeFreshnessDiscipline ->
      entry.accepted = true := by
  intro entry hMem
  unfold runtimeFreshnessDiscipline at hMem
  simp at hMem
  rcases hMem with h | h | h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

theorem runtimeFreshnessDiscipline_noDiagnosticsInProductionTheoremMode :
    forall entry, entry ∈ runtimeFreshnessDiscipline ->
      entry.surface = RuntimeFreshnessSurface.diagnosticFreshCoinInjection ->
        entry.productionTheoremModeSafe = true := by
  intro entry hMem hSurface
  have hAccepted := runtimeFreshnessDiscipline_allAccepted entry hMem
  unfold RuntimeFreshnessDisciplineEntry.accepted at hAccepted
  cases hDomain : entry.domainSeparatedAssociatedData <;>
    simp [hDomain] at hAccepted
  cases hFresh : entry.freshPerCallOrSeed <;>
    simp [hFresh] at hAccepted
  exact hAccepted

inductive SgxDeploymentMechanismStatus where
  | implementationEvidence
  | externalDeploymentOnly
  | removedFromImplementedClaim
deriving Repr, DecidableEq

def SgxDeploymentMechanismStatus.isExplicitlyMapped :
    SgxDeploymentMechanismStatus -> Bool
  | .implementationEvidence => true
  | .externalDeploymentOnly => true
  | .removedFromImplementedClaim => true

structure SgxDeploymentAssumptionMechanismEntry where
  assumptionField : String
  mechanism : String
  status : SgxDeploymentMechanismStatus
  evidenceAnchor : String
  deploymentArtifact : String
  driftCheckName : String
deriving Repr, DecidableEq

def SgxDeploymentAssumptionMechanismEntry.mapped
    (entry : SgxDeploymentAssumptionMechanismEntry) : Bool :=
  entry.status.isExplicitlyMapped

def sgxDeploymentAssumptionMechanismMatrix :
    List SgxDeploymentAssumptionMechanismEntry :=
  [ { assumptionField := "attestationAuthenticity"
    , mechanism :=
        "deployment attestation transcript binds enclave measurement, configuration, and return-channel public key"
    , status := .externalDeploymentOnly
    , evidenceAnchor := "SgxDeploymentAssumptions.attestationAuthenticity"
    , deploymentArtifact := "attestation transcript"
    , driftCheckName := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { assumptionField := "enclaveMemoryIsolation"
    , mechanism :=
        "SGX EPC/MEE isolation protects enclave memory from the hostile host"
    , status := .externalDeploymentOnly
    , evidenceAnchor := "SgxDeploymentAssumptions.enclaveMemoryIsolation"
    , deploymentArtifact := "enclave boundary and platform TCB evidence"
    , driftCheckName := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { assumptionField := "rollbackResistance"
    , mechanism :=
        "sealed-state epoch is checked against a monotonic rollback counter before state is accepted"
    , status := .externalDeploymentOnly
    , evidenceAnchor := "SgxDeploymentAssumptions.rollbackResistance"
    , deploymentArtifact := "rollback counter transcript"
    , driftCheckName := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { assumptionField := "freshnessGuarantee"
    , mechanism :=
        "sealed-state freshness token or trusted-time evidence is validated before unsealed state is used"
    , status := .externalDeploymentOnly
    , evidenceAnchor := "SgxDeploymentAssumptions.freshnessGuarantee"
    , deploymentArtifact := "sealed-state freshness evidence"
    , driftCheckName := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { assumptionField := "crashRecoveryDiscipline"
    , mechanism :=
        "runtime commit/wipe and sealed-state recovery preserve the public commit-or-rollback boundary across crashes"
    , status := .implementationEvidence
    , evidenceAnchor := "sgxStorageRefinementProvenance"
    , deploymentArtifact := "sealed storage recovery discipline"
    , driftCheckName := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { assumptionField := "patchLevelTrust"
    , mechanism :=
        "deployment records the SGX TCB/microcode level and rejects platforms below the required patch floor"
    , status := .externalDeploymentOnly
    , evidenceAnchor := "SgxDeploymentAssumptions.patchLevelTrust"
    , deploymentArtifact := "platform TCB / patch-level attestation evidence"
    , driftCheckName := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  ]

theorem sgxDeploymentAssumptionMechanismMatrix_coversBundleFields :
    sgxDeploymentAssumptionMechanismMatrix.map
        (fun entry => entry.assumptionField) =
      [ "attestationAuthenticity"
      , "enclaveMemoryIsolation"
      , "rollbackResistance"
      , "freshnessGuarantee"
      , "crashRecoveryDiscipline"
      , "patchLevelTrust"
      ] := by
  rfl

theorem sgxDeploymentAssumptionMechanismMatrix_allMapped :
    forall entry, entry ∈ sgxDeploymentAssumptionMechanismMatrix ->
      entry.mapped = true := by
  intro entry hMem
  unfold sgxDeploymentAssumptionMechanismMatrix at hMem
  simp at hMem
  rcases hMem with h | h | h | h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

inductive SgxDeploymentMilestoneArtifact where
  | enclaveBoundary
  | attestationTranscript
  | sealedStorage
  | sealedStateFreshness
  | rollbackCounter
  | encryptedReturnChannel
deriving Repr, DecidableEq

structure SgxDeploymentMilestoneEntry where
  artifact : SgxDeploymentMilestoneArtifact
  status : SgxDeploymentMechanismStatus
  requiredEvidence : String
  currentClaimRule : String
  probeAnchor : String
deriving Repr, DecidableEq

def SgxDeploymentMilestoneEntry.mapped
    (entry : SgxDeploymentMilestoneEntry) : Bool :=
  entry.status.isExplicitlyMapped

def sgxDeploymentFirstMilestoneChecklist :
    List SgxDeploymentMilestoneEntry :=
  [ { artifact := .enclaveBoundary
    , status := .implementationEvidence
    , requiredEvidence := "boundary_schedule and SGX controller observer certificate"
    , currentClaimRule := "covered by W6.1/W6.2 observer and boundary-call freezes"
    , probeAnchor := "sgx_boundary_call_model_pinned"
    }
  , { artifact := .attestationTranscript
    , status := .externalDeploymentOnly
    , requiredEvidence := "quote, measurement, configuration hash, and return-channel public key"
    , currentClaimRule := "deployment must supply and verify this transcript"
    , probeAnchor := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { artifact := .sealedStorage
    , status := .implementationEvidence
    , requiredEvidence := "sealed-record shape, authenticated open, and storage refinement evidence"
    , currentClaimRule := "covered by generated sealed-record/store-helper checks and W6.4 storage refinement"
    , probeAnchor := "sgx_storage_refinement_pinned"
    }
  , { artifact := .sealedStateFreshness
    , status := .externalDeploymentOnly
    , requiredEvidence := "trusted-time or freshness token bound to sealed state"
    , currentClaimRule := "deployment must supply freshness evidence before accepting unsealed state"
    , probeAnchor := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { artifact := .rollbackCounter
    , status := .externalDeploymentOnly
    , requiredEvidence := "monotonic rollback counter transcript tied to sealed-state epoch"
    , currentClaimRule := "deployment must reject stale epochs"
    , probeAnchor := "sgx_deployment_assumption_mechanism_matrix_pinned"
    }
  , { artifact := .encryptedReturnChannel
    , status := .removedFromImplementedClaim
    , requiredEvidence := "client public key, enclave-bound session key, return ciphertext, and nonce transcript"
    , currentClaimRule :=
        "current runtime rejects ReturnPolicy.encrypted_to_client until this channel exists"
    , probeAnchor := "return_channel_crypto_gate_pinned"
    }
  ]

theorem sgxDeploymentFirstMilestoneChecklist_coversRequiredArtifacts :
    sgxDeploymentFirstMilestoneChecklist.map (fun entry => entry.artifact) =
      [ SgxDeploymentMilestoneArtifact.enclaveBoundary
      , SgxDeploymentMilestoneArtifact.attestationTranscript
      , SgxDeploymentMilestoneArtifact.sealedStorage
      , SgxDeploymentMilestoneArtifact.sealedStateFreshness
      , SgxDeploymentMilestoneArtifact.rollbackCounter
      , SgxDeploymentMilestoneArtifact.encryptedReturnChannel
      ] := by
  rfl

theorem sgxDeploymentFirstMilestoneChecklist_allMapped :
    forall entry, entry ∈ sgxDeploymentFirstMilestoneChecklist ->
      entry.mapped = true := by
  intro entry hMem
  unfold sgxDeploymentFirstMilestoneChecklist at hMem
  simp at hMem
  rcases hMem with h | h | h | h | h | h
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl
  · subst h; rfl

end UOToolchain
