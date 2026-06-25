import UOToolchain.RuntimeAuditSurfaces

namespace UOToolchain

/-!
# Deployment acceptance boundary

This module records the production-deployment theorem surface used by F-16.
The paper theorem remains about the instrumented runtime observer. The
deployment theorem adds the operational evidence that must be present before a
runtime result can be accepted in production.
-/

structure DeploymentRuntimePolicy where
  runtimeBinaryHash : String
  proofRootHash : String
  acceptedSgxQuoteHash : String
  buildProfileHash : String
deriving Repr, DecidableEq

structure DeploymentBuildProfileEvidence where
  buildProfileHash : String
  runtimeBinaryHash : String
  proofRootHash : String
  diagnosticsSeedInjectionDisabled : Bool
  deterministicReplayEntrypointsDisabled : Bool
deriving Repr, DecidableEq

structure DeploymentCallEvidence where
  admittedPackageHash : String
  toolchainManifestHash : String
  runtimeBinaryHash : String
  proofRootHash : String
  sgxQuoteHash : String
  buildProfileHash : String
  publicEnvironmentHash : String
  publicEnvironmentTranscript : List String
  publicEnvironmentProjection : List String
  sessionId : String
  attestationTranscriptHash : String
  freshnessEpoch : Nat
  rollbackCounter : Nat
  nextCallCounter : Nat
  proofBundleHash : Option String
  translationValidationCertificateHash : String
deriving Repr, DecidableEq

structure DeploymentRuntimeState where
  admittedPackageHash : String
  toolchainManifestHash : String
  publicEnvironmentHash : String
  publicEnvironmentTranscript : List String
  publicEnvironmentProjection : List String
  sessionId : String
  attestationTranscriptHash : String
  freshnessEpoch : Nat
  rollbackCounter : Nat
  nextCallCounter : Nat
  translationValidationCertificateHash : String
deriving Repr, DecidableEq

def DeploymentPublicEnvironmentBound
    (transcript projection : List String) : Prop :=
  forall binding, binding ∈ projection -> binding ∈ transcript

def DeploymentCallAccepted
  (policy : DeploymentRuntimePolicy)
  (profile : DeploymentBuildProfileEvidence)
  (state : DeploymentRuntimeState)
  (evidence : DeploymentCallEvidence) : Prop :=
  evidence.admittedPackageHash = state.admittedPackageHash ∧
  evidence.toolchainManifestHash = state.toolchainManifestHash ∧
  evidence.runtimeBinaryHash = policy.runtimeBinaryHash ∧
  evidence.proofRootHash = policy.proofRootHash ∧
  evidence.sgxQuoteHash = policy.acceptedSgxQuoteHash ∧
  evidence.buildProfileHash = policy.buildProfileHash ∧
  profile.buildProfileHash = policy.buildProfileHash ∧
  profile.runtimeBinaryHash = policy.runtimeBinaryHash ∧
  profile.proofRootHash = policy.proofRootHash ∧
  profile.diagnosticsSeedInjectionDisabled = true ∧
  profile.deterministicReplayEntrypointsDisabled = true ∧
  evidence.publicEnvironmentHash = state.publicEnvironmentHash ∧
  evidence.publicEnvironmentTranscript = state.publicEnvironmentTranscript ∧
  evidence.publicEnvironmentProjection = state.publicEnvironmentProjection ∧
  DeploymentPublicEnvironmentBound evidence.publicEnvironmentTranscript
    evidence.publicEnvironmentProjection ∧
  evidence.sessionId = state.sessionId ∧
  evidence.attestationTranscriptHash = state.attestationTranscriptHash ∧
  evidence.freshnessEpoch = state.freshnessEpoch ∧
  evidence.rollbackCounter = state.rollbackCounter ∧
  evidence.nextCallCounter = state.nextCallCounter ∧
  evidence.proofBundleHash.isSome ∧
  evidence.translationValidationCertificateHash = state.translationValidationCertificateHash

theorem deployment_call_acceptance_requires_validated_proof_bundle
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.proofBundleHash.isSome := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hProofBundle, _⟩
  exact hProofBundle

theorem deployment_call_acceptance_binds_runtime_binary
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.runtimeBinaryHash = policy.runtimeBinaryHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, hRuntimeBinary, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _⟩
  exact hRuntimeBinary

theorem deployment_call_acceptance_binds_proof_root
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.proofRootHash = policy.proofRootHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, hProofRoot, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _⟩
  exact hProofRoot

theorem deployment_call_acceptance_binds_build_profile_and_excludes_diagnostics
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.buildProfileHash = policy.buildProfileHash ∧
    profile.buildProfileHash = policy.buildProfileHash ∧
    profile.runtimeBinaryHash = policy.runtimeBinaryHash ∧
    profile.proofRootHash = policy.proofRootHash ∧
    profile.diagnosticsSeedInjectionDisabled = true ∧
    profile.deterministicReplayEntrypointsDisabled = true := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, hEvidenceBuildProfile, hProfileBuildProfile, hProfileRuntime,
      hProfileProof, hDiagnostics, hReplay, _, _, _, _, _, _, _, _, _, _, _⟩
  exact ⟨hEvidenceBuildProfile, hProfileBuildProfile, hProfileRuntime, hProfileProof,
    hDiagnostics, hReplay⟩

theorem deployment_call_acceptance_binds_public_environment
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.publicEnvironmentHash = state.publicEnvironmentHash ∧
    evidence.publicEnvironmentTranscript = state.publicEnvironmentTranscript ∧
    evidence.publicEnvironmentProjection = state.publicEnvironmentProjection ∧
    DeploymentPublicEnvironmentBound evidence.publicEnvironmentTranscript
      evidence.publicEnvironmentProjection := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, _, _, _, _, hEnvironmentHash, hEnvironmentTranscript,
      hEnvironmentProjection, hProjectionBound, _, _, _, _, _, _, _⟩
  exact ⟨hEnvironmentHash, hEnvironmentTranscript, hEnvironmentProjection, hProjectionBound⟩

theorem deployment_call_acceptance_uses_closed_freshness_surfaces
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    profile.diagnosticsSeedInjectionDisabled = true ∧
    profile.deterministicReplayEntrypointsDisabled = true ∧
    (forall entry, entry ∈ runtimeFreshnessDiscipline ->
      entry.uniqueWithinDomain = true) ∧
    (forall entry, entry ∈ runtimeFreshnessDiscipline ->
      entry.surface = RuntimeFreshnessSurface.diagnosticFreshCoinInjection ->
        entry.productionTheoremModeSafe = true) ∧
    (forall entry, entry ∈ runtimeFreshnessDiscipline ->
      entry.surface = RuntimeFreshnessSurface.deterministicDeploySeed ->
        entry.productionTheoremModeSafe = true) := by
  intro hAccepted
  rcases deployment_call_acceptance_binds_build_profile_and_excludes_diagnostics hAccepted with
    ⟨_, _, _, _, hDiagnostics, hReplay⟩
  exact ⟨hDiagnostics, hReplay, runtimeFreshnessDiscipline_uniqueWithinDomain,
    runtimeFreshnessDiscipline_noDiagnosticsInProductionTheoremMode,
    runtimeFreshnessDiscipline_seededReplayAbsentFromDefaultProductionApi⟩

theorem deployment_call_acceptance_binds_sgx_quote_and_session
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.sgxQuoteHash = policy.acceptedSgxQuoteHash ∧
    evidence.sessionId = state.sessionId ∧
    evidence.attestationTranscriptHash = state.attestationTranscriptHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, hQuote, _, _, _, _, _, _, _, _, _, _, hSession, hTranscript, _, _, _, _, _⟩
  exact ⟨hQuote, hSession, hTranscript⟩

theorem deployment_call_acceptance_binds_freshness
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.freshnessEpoch = state.freshnessEpoch ∧
    evidence.rollbackCounter = state.rollbackCounter ∧
    evidence.nextCallCounter = state.nextCallCounter := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hEpoch, hRollback, hNextCall, _, _⟩
  exact ⟨hEpoch, hRollback, hNextCall⟩

theorem deployment_call_acceptance_binds_translation_validation_certificate
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.translationValidationCertificateHash =
      state.translationValidationCertificateHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hCertificate⟩
  exact hCertificate

theorem deployment_call_rejects_missing_proof_bundle
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence}
  (hMissing : evidence.proofBundleHash = none) :
  ¬ DeploymentCallAccepted policy profile state evidence := by
  intro hAccepted
  have hSome := deployment_call_acceptance_requires_validated_proof_bundle hAccepted
  simp [hMissing] at hSome

end UOToolchain
