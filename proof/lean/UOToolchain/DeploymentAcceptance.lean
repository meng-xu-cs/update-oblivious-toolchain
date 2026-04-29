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
deriving Repr, DecidableEq

structure DeploymentCallEvidence where
  admittedPackageHash : String
  toolchainManifestHash : String
  runtimeBinaryHash : String
  proofRootHash : String
  sgxQuoteHash : String
  sessionId : String
  attestationTranscriptHash : String
  freshnessEpoch : Nat
  rollbackCounter : Nat
  nextCallCounter : Nat
  proofBundleHash : Option String
deriving Repr, DecidableEq

structure DeploymentRuntimeState where
  admittedPackageHash : String
  toolchainManifestHash : String
  sessionId : String
  attestationTranscriptHash : String
  freshnessEpoch : Nat
  rollbackCounter : Nat
  nextCallCounter : Nat
deriving Repr, DecidableEq

def DeploymentCallAccepted
  (policy : DeploymentRuntimePolicy)
  (state : DeploymentRuntimeState)
  (evidence : DeploymentCallEvidence) : Prop :=
  evidence.admittedPackageHash = state.admittedPackageHash ∧
  evidence.toolchainManifestHash = state.toolchainManifestHash ∧
  evidence.runtimeBinaryHash = policy.runtimeBinaryHash ∧
  evidence.proofRootHash = policy.proofRootHash ∧
  evidence.sgxQuoteHash = policy.acceptedSgxQuoteHash ∧
  evidence.sessionId = state.sessionId ∧
  evidence.attestationTranscriptHash = state.attestationTranscriptHash ∧
  evidence.freshnessEpoch = state.freshnessEpoch ∧
  evidence.rollbackCounter = state.rollbackCounter ∧
  evidence.nextCallCounter = state.nextCallCounter ∧
  evidence.proofBundleHash.isSome

theorem deployment_call_acceptance_requires_validated_proof_bundle
  {policy : DeploymentRuntimePolicy}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy state evidence →
    evidence.proofBundleHash.isSome := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, _, _, _, hProofBundle⟩
  exact hProofBundle

theorem deployment_call_acceptance_binds_runtime_binary
  {policy : DeploymentRuntimePolicy}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy state evidence →
    evidence.runtimeBinaryHash = policy.runtimeBinaryHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, hRuntimeBinary, _, _, _, _, _, _, _, _⟩
  exact hRuntimeBinary

theorem deployment_call_acceptance_binds_proof_root
  {policy : DeploymentRuntimePolicy}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy state evidence →
    evidence.proofRootHash = policy.proofRootHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, hProofRoot, _, _, _, _, _, _, _⟩
  exact hProofRoot

theorem deployment_call_acceptance_binds_sgx_quote_and_session
  {policy : DeploymentRuntimePolicy}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy state evidence →
    evidence.sgxQuoteHash = policy.acceptedSgxQuoteHash ∧
    evidence.sessionId = state.sessionId ∧
    evidence.attestationTranscriptHash = state.attestationTranscriptHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, hQuote, hSession, hTranscript, _, _, _, _⟩
  exact ⟨hQuote, hSession, hTranscript⟩

theorem deployment_call_acceptance_binds_freshness
  {policy : DeploymentRuntimePolicy}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy state evidence →
    evidence.freshnessEpoch = state.freshnessEpoch ∧
    evidence.rollbackCounter = state.rollbackCounter ∧
    evidence.nextCallCounter = state.nextCallCounter := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, hEpoch, hRollback, hNextCall, _⟩
  exact ⟨hEpoch, hRollback, hNextCall⟩

theorem deployment_call_rejects_missing_proof_bundle
  {policy : DeploymentRuntimePolicy}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence}
  (hMissing : evidence.proofBundleHash = none) :
  ¬ DeploymentCallAccepted policy state evidence := by
  intro hAccepted
  have hSome := deployment_call_acceptance_requires_validated_proof_bundle hAccepted
  simp [hMissing] at hSome

end UOToolchain
