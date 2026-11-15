import UOToolchain.RuntimeAuditSurfaces

namespace UOToolchain

/-!
# Deployment acceptance boundary

This module records the production-deployment theorem surface used by F-16.
The paper theorem remains about the instrumented runtime observer. The
deployment theorem adds the operational evidence that must be present before a
runtime result can be accepted in production.

A production call is accepted on evidence that a caller can know before the
call runs. In place of a per-call proof object, the evidence names the receipt
the runtime issued last, and the runtime answers with the next receipt of the
deployment's chain. No proof object and no private evidence leaves a production
runtime; the Lean checkers run on diagnostics builds of the same source.
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
  /-- The hash of the receipt the call follows: the deployment's receipt for
  the first call, and then the receipt of the call before. -/
  previousReceiptHash : String
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
  /-- The hash of the receipt the runtime issued last. -/
  lastReceiptHash : String
  /-- The digest of the committed public state. -/
  publicStateHash : String
  /-- The digest of the sealed records in storage. -/
  ciphertextStoreHash : String
  translationValidationCertificateHash : String
deriving Repr, DecidableEq

/-- What the runtime issues for a deployment and for every call it accepts.
It names its request and the receipt before it, the state before and after,
the call's public receipt, and the freshness counters after the call. Hashes
are opaque strings here: the statements below are about how the fields of
successive receipts must agree, not about a hash function. -/
structure DeploymentCallReceipt where
  requestHash : String
  previousReceiptHash : String
  publicStateBeforeHash : String
  publicStateAfterHash : String
  ciphertextStoreBeforeHash : String
  ciphertextStoreAfterHash : String
  publicReceiptHash : String
  freshnessEpoch : Nat
  rollbackCounter : Nat
  nextCallCounter : Nat
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
  evidence.previousReceiptHash = state.lastReceiptHash ∧
  evidence.translationValidationCertificateHash = state.translationValidationCertificateHash

/-- An accepted call follows the receipt the runtime issued last. -/
theorem deployment_call_acceptance_binds_previous_receipt
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence} :
  DeploymentCallAccepted policy profile state evidence →
    evidence.previousReceiptHash = state.lastReceiptHash := by
  intro hAccepted
  rcases hAccepted with
    ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hReceipt, _⟩
  exact hReceipt

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

/-- A call that names any receipt but the one the runtime issued last is
rejected: an older receipt, a receipt that was changed on its way to the
caller, or none. -/
theorem deployment_call_rejects_other_receipt
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {evidence : DeploymentCallEvidence}
  (hOther : evidence.previousReceiptHash ≠ state.lastReceiptHash) :
  ¬ DeploymentCallAccepted policy profile state evidence := by
  intro hAccepted
  exact hOther (deployment_call_acceptance_binds_previous_receipt hAccepted)

/-! ## Receipts

The runtime issues a receipt for each accepted call. `DeploymentReceiptIssued`
says what the receipt of a call accepted in a state must hold, and
`DeploymentRuntimeState.afterReceipt` is the state the runtime is in once it
has issued it. `DeploymentReceiptFollows` is the relation a holder of two
receipts checks. The Rust `ProductionReceipt::for_call` and
`ProductionReceipt::follows` implement the two; that they do is tested in
`runtime/uo-evm/tests/production_boundary.rs`, not proved. -/

/-- The receipt of a call accepted in `state` on evidence whose hash is
`evidenceHash`. It names the request and the receipt before it, starts from
the state's commitments, keeps the epoch, and its counters are the state's,
moved on by one call. A call that aborts leaves the rollback counter where it
was. -/
def DeploymentReceiptIssued
  (state : DeploymentRuntimeState)
  (evidenceHash : String)
  (receipt : DeploymentCallReceipt) : Prop :=
  receipt.requestHash = evidenceHash ∧
  receipt.previousReceiptHash = state.lastReceiptHash ∧
  receipt.publicStateBeforeHash = state.publicStateHash ∧
  receipt.ciphertextStoreBeforeHash = state.ciphertextStoreHash ∧
  receipt.freshnessEpoch = state.freshnessEpoch ∧
  receipt.nextCallCounter = state.nextCallCounter + 1 ∧
  (receipt.rollbackCounter = state.rollbackCounter ∨
    receipt.rollbackCounter = state.rollbackCounter + 1)

/-- The runtime's state once it has issued `receipt`, whose hash is
`receiptHash`. -/
def DeploymentRuntimeState.afterReceipt
  (state : DeploymentRuntimeState)
  (receipt : DeploymentCallReceipt)
  (receiptHash : String) : DeploymentRuntimeState :=
  { state with
    lastReceiptHash := receiptHash
    publicStateHash := receipt.publicStateAfterHash
    ciphertextStoreHash := receipt.ciphertextStoreAfterHash
    rollbackCounter := receipt.rollbackCounter
    nextCallCounter := receipt.nextCallCounter }

/-- `next` comes after `previous`, whose hash is `previousHash`, in a
deployment's chain of receipts. -/
def DeploymentReceiptFollows
  (previous : DeploymentCallReceipt)
  (previousHash : String)
  (next : DeploymentCallReceipt) : Prop :=
  next.previousReceiptHash = previousHash ∧
  next.publicStateBeforeHash = previous.publicStateAfterHash ∧
  next.ciphertextStoreBeforeHash = previous.ciphertextStoreAfterHash ∧
  next.freshnessEpoch = previous.freshnessEpoch ∧
  next.nextCallCounter = previous.nextCallCounter + 1 ∧
  (next.rollbackCounter = previous.rollbackCounter ∨
    next.rollbackCounter = previous.rollbackCounter + 1)

/-- The receipts of two calls accepted one after the other follow one
another. -/
theorem deployment_receipts_issued_in_turn_follow
  {state : DeploymentRuntimeState}
  {firstEvidenceHash secondEvidenceHash firstHash : String}
  {first second : DeploymentCallReceipt}
  (hFirst : DeploymentReceiptIssued state firstEvidenceHash first)
  (hSecond :
    DeploymentReceiptIssued (state.afterReceipt first firstHash) secondEvidenceHash second) :
  DeploymentReceiptFollows first firstHash second := by
  rcases hFirst with ⟨_, _, _, _, hEpoch, _, _⟩
  rcases hSecond with ⟨_, hPrevious, hPublic, hStore, hEpoch', hNext, hRollback⟩
  refine ⟨hPrevious, hPublic, hStore, ?_, hNext, hRollback⟩
  rw [hEpoch', hEpoch]
  rfl

/-- The call the runtime accepts next must name the receipt it just issued. -/
theorem deployment_call_after_receipt_names_it
  {policy : DeploymentRuntimePolicy}
  {profile : DeploymentBuildProfileEvidence}
  {state : DeploymentRuntimeState}
  {receipt : DeploymentCallReceipt}
  {receiptHash : String}
  {evidence : DeploymentCallEvidence}
  (hAccepted :
    DeploymentCallAccepted policy profile (state.afterReceipt receipt receiptHash) evidence) :
  evidence.previousReceiptHash = receiptHash ∧
    evidence.rollbackCounter = receipt.rollbackCounter ∧
    evidence.nextCallCounter = receipt.nextCallCounter := by
  have hReceipt := deployment_call_acceptance_binds_previous_receipt hAccepted
  have hFreshness := deployment_call_acceptance_binds_freshness hAccepted
  exact ⟨hReceipt, hFreshness.2.1, hFreshness.2.2⟩

/-- A receipt's call counter is one more than that of the receipt it
follows. -/
theorem deployment_receipt_follows_counter
  {previous next : DeploymentCallReceipt}
  {previousHash : String}
  (hFollows : DeploymentReceiptFollows previous previousHash next) :
  next.nextCallCounter = previous.nextCallCounter + 1 :=
  hFollows.2.2.2.2.1

/-- A replayed receipt is rejected: no receipt follows itself. -/
theorem deployment_receipt_not_follows_itself
  (receipt : DeploymentCallReceipt)
  (receiptHash : String) :
  ¬ DeploymentReceiptFollows receipt receiptHash receipt := by
  intro hFollows
  have hCounter := deployment_receipt_follows_counter hFollows
  omega

/-- Reordered receipts are rejected: if one receipt follows another, the
other does not follow it. -/
theorem deployment_receipt_follows_asymmetric
  {first second : DeploymentCallReceipt}
  {firstHash secondHash : String}
  (hFollows : DeploymentReceiptFollows first firstHash second) :
  ¬ DeploymentReceiptFollows second secondHash first := by
  intro hBack
  have hForward := deployment_receipt_follows_counter hFollows
  have hBackward := deployment_receipt_follows_counter hBack
  omega

/-- A skipped receipt is rejected: a receipt that follows the successor of
another does not follow that other one. -/
theorem deployment_receipt_follows_not_skipping
  {first second third : DeploymentCallReceipt}
  {firstHash secondHash : String}
  (hSecond : DeploymentReceiptFollows first firstHash second)
  (hThird : DeploymentReceiptFollows second secondHash third) :
  ¬ DeploymentReceiptFollows first firstHash third := by
  intro hSkip
  have hOne := deployment_receipt_follows_counter hSecond
  have hTwo := deployment_receipt_follows_counter hThird
  have hDirect := deployment_receipt_follows_counter hSkip
  omega

/-- A receipt follows another only from the state the other ended in, in the
same epoch. -/
theorem deployment_receipt_follows_binds_state
  {previous next : DeploymentCallReceipt}
  {previousHash : String}
  (hFollows : DeploymentReceiptFollows previous previousHash next) :
  next.previousReceiptHash = previousHash ∧
    next.publicStateBeforeHash = previous.publicStateAfterHash ∧
    next.ciphertextStoreBeforeHash = previous.ciphertextStoreAfterHash ∧
    next.freshnessEpoch = previous.freshnessEpoch :=
  ⟨hFollows.1, hFollows.2.1, hFollows.2.2.1, hFollows.2.2.2.1⟩

/-! ## Authenticated receipts

The runtime gives each receipt a tag under the session of the caller it
answers: a MAC over the receipt's hash, under a key derived from the
session's key (`verify_production_receipt` in
`runtime/uo-evm/src/deployment.rs`). A caller holding the session checks the
tag of a receipt it holds, the last one included, and makes no call. Tags
and hashes are opaque here. What a verifier may conclude rests on two
assumptions, which this module states as hypotheses and does not prove: two
receipts with one hash are one receipt, and a tag that verifies under a
session's key is one the runtime made, which it does only for the receipts
it issues. -/

/-- A deployment's hash of a receipt, and the tag of a receipt's hash under
a session key. -/
structure DeploymentReceiptTags where
  receiptHash : DeploymentCallReceipt → String
  tag : String → String → String

/-- `tag` is the tag of `receipt` under `sessionKey`: the verifier's check. -/
def DeploymentReceiptTags.Verifies
    (tags : DeploymentReceiptTags) (sessionKey : String)
    (receipt : DeploymentCallReceipt) (tag : String) : Prop :=
  tag = tags.tag sessionKey (tags.receiptHash receipt)

/-- The hash's assumption: two receipts with one hash are one receipt. -/
def DeploymentReceiptTags.HashInjective (tags : DeploymentReceiptTags) : Prop :=
  ∀ lhs rhs, tags.receiptHash lhs = tags.receiptHash rhs → lhs = rhs

/-- The MAC's assumption for one session: a tag that verifies under its key
is the tag of the hash of a receipt the runtime issued, `issued` being the
receipts the runtime issued in the deployment. -/
def DeploymentReceiptTags.Unforgeable
    (tags : DeploymentReceiptTags) (sessionKey : String)
    (issued : DeploymentCallReceipt → Prop) : Prop :=
  ∀ receiptHash tag, tag = tags.tag sessionKey receiptHash →
    ∃ receipt, issued receipt ∧ tags.receiptHash receipt = receiptHash

/-- **What a verifier of a receipt's tag may conclude.** Under the two
assumptions, a receipt whose tag verifies under a session's key is a receipt
the runtime issued, with every field as it was issued. A receipt changed in
any field after it was issued, the digest of the ciphertext store after its
call among them, is rejected by its holder's own check, and the holder needs
no call to run it. -/
theorem deployment_receipt_tag_verifies_issued
    {tags : DeploymentReceiptTags} {sessionKey tag : String}
    {issued : DeploymentCallReceipt → Prop} {receipt : DeploymentCallReceipt}
    (hHash : tags.HashInjective)
    (hUnforgeable : tags.Unforgeable sessionKey issued)
    (hVerifies : tags.Verifies sessionKey receipt tag) :
    issued receipt := by
  obtain ⟨issuedReceipt, hIssued, hSameHash⟩ := hUnforgeable _ tag hVerifies
  exact hHash _ _ hSameHash ▸ hIssued

/-- A receipt the runtime did not issue has no tag that verifies. -/
theorem deployment_receipt_not_issued_tag_rejected
    {tags : DeploymentReceiptTags} {sessionKey tag : String}
    {issued : DeploymentCallReceipt → Prop} {receipt : DeploymentCallReceipt}
    (hHash : tags.HashInjective)
    (hUnforgeable : tags.Unforgeable sessionKey issued)
    (hNotIssued : ¬ issued receipt) :
    ¬ tags.Verifies sessionKey receipt tag :=
  fun hVerifies =>
    hNotIssued (deployment_receipt_tag_verifies_issued hHash hUnforgeable hVerifies)

/-- With the receipts of calls as the runtime issues them
(`DeploymentReceiptIssued`), a receipt whose tag verifies names its request
and the receipt before it, starts from the commitments of a state the
runtime was in, keeps that state's epoch, and moves its counters on by one
call. -/
theorem deployment_receipt_tag_verifies_issued_in_a_state
    {tags : DeploymentReceiptTags} {sessionKey tag : String}
    {receipt : DeploymentCallReceipt}
    (hHash : tags.HashInjective)
    (hUnforgeable : tags.Unforgeable sessionKey
      (fun issued => ∃ state evidenceHash, DeploymentReceiptIssued state evidenceHash issued))
    (hVerifies : tags.Verifies sessionKey receipt tag) :
    ∃ state evidenceHash, DeploymentReceiptIssued state evidenceHash receipt :=
  deployment_receipt_tag_verifies_issued hHash hUnforgeable hVerifies

end UOToolchain
