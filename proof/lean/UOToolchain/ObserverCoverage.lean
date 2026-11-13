import UOToolchain.RuntimeAuditSurfaces

namespace UOToolchain

/-!
# Proof-relevant observer coverage

This module mirrors the Rust observer coverage table. Its keys are intentionally
the Rust schema name paired with the Rust field name. The companion Rust tests
parse the source structs and require every observer-affecting field to appear
here, so adding a field to the runtime observer surface must also update the
proof-side mirror.
-/

inductive ObserverCoverageClassification where
  | includedInLean
  | publicInput
  | declaredRelease
  | cryptographicallyHidden
  | normalizedAway
  | outsideClaim
deriving Repr, DecidableEq

def ObserverCoverageClassification.closed :
    ObserverCoverageClassification -> Bool
  | .includedInLean => true
  | .publicInput => true
  | .declaredRelease => true
  | .cryptographicallyHidden => true
  | .normalizedAway => true
  | .outsideClaim => true

structure ObserverFieldCoverage where
  key : String
  classification : ObserverCoverageClassification
  leanAnchor : String
  rationale : String
deriving Repr, DecidableEq

def ObserverFieldCoverage.closed (entry : ObserverFieldCoverage) : Bool :=
  entry.classification.closed

def containsString (needle : String) : List String -> Bool
  | [] => false
  | item :: rest => if item == needle then true else containsString needle rest

def observerCoverageDeclaredReleaseKeys : List String :=
  [ "PublicOutcomeTrace.termination_status"
  , "PublicOutcomeTrace.return_payload"
  , "PublicOutcomeTrace.declassifies"
  ]

def observerCoverageCryptographicallyHiddenKeys : List String :=
  [ "EncryptedReturnPayload.nonce"
  , "EncryptedReturnPayload.ciphertext"
  , "EncryptedReturnPayload.tag"
  , "RuntimeTrustedKernelBundle.runtime_seed"
  , "PrivateEvidence.runtime_seed"
  , "PrivateEvidence.runtime_oram_access_counters_before"
  , "PrivateEvidence.runtime_oram_access_counters_after"
  , "PrivateEvidence.runtime_oram_position_map_before"
  , "PrivateEvidence.runtime_oram_position_map_after"
  , "PrivateEvidence.runtime_oram_leaf_state_transitions"
  ]

def observerCoveragePublicInputKeys : List String :=
  [ "ReturnChannelAad.domain"
  , "ReturnChannelAad.version"
  , "ReturnChannelAad.package_sha256"
  , "ReturnChannelAad.contract"
  , "ReturnChannelAad.entrypoint"
  , "ReturnChannelAad.return_policy"
  , "ReturnChannelAad.return_canonical_len"
  , "ReturnChannelAad.public_args"
  , "ReturnChannelAad.binding"
  , "PublicOutcomeTrace.public_env"
  ]

def observerCoverageClassificationFor
    (key : String) : ObserverCoverageClassification :=
  if containsString key observerCoverageDeclaredReleaseKeys then
    .declaredRelease
  else if containsString key observerCoverageCryptographicallyHiddenKeys then
    .cryptographicallyHidden
  else if containsString key observerCoveragePublicInputKeys then
    .publicInput
  else
    .includedInLean

def observerCoverageKeys : List String :=
  [ "RuntimeManifest.contract"
  , "RuntimeManifest.compilation_mode"
  , "RuntimeManifest.objects"
  , "RuntimeManifest.entrypoints"
  , "StateObjectManifest.id"
  , "StateObjectManifest.name"
  , "StateObjectManifest.kind"
  , "StateObjectManifest.backend"
  , "StateObjectManifest.capacity"
  , "StateObjectManifest.value_type"
  , "StateObjectManifest.key_type"
  , "StateObjectManifest.oram"
  , "RuntimeKernelStepManifest.opcode"
  , "RuntimeKernelStepManifest.object_id"
  , "EntrypointManifest.secret_args"
  , "EntrypointManifest.param_names"
  , "EntrypointManifest.public_env"
  , "EntrypointManifest.entry_input_len"
  , "EntrypointManifest.initializer"
  , "EntrypointManifest.requires_initialized"
  , "EntrypointManifest.public_gas_budget"
  , "EntrypointManifest.arena_bytes"
  , "EntrypointManifest.max_stack_words"
  , "EntrypointManifest.max_hash_part_bytes"
  , "EntrypointManifest.return_canonical_len"
  , "EntrypointManifest.returns"
  , "EntrypointManifest.status"
  , "EntrypointManifest.declassifies"
  , "EntrypointManifest.public_state_declassifies"
  , "EntrypointManifest.confidential_program"
  , "EntrypointManifest.confidential_slot_program"
  , "EntrypointManifest.kernel_steps"
  , "EntrypointManifest.uocell_reads"
  , "EntrypointManifest.uocell_writes"
  , "EntrypointManifest.uoarray_reads"
  , "EntrypointManifest.uoarray_writes"
  , "EntrypointManifest.uomap_reads"
  , "EntrypointManifest.uomap_writes"
  , "EntrypointManifest.max_commit_ops"
  , "EntrypointManifest.max_load_ops"
  , "EntrypointManifest.may_write_objects"
  , "EntrypointManifest.oram_accesses"
  , "OramManifest.scheme"
  , "OramManifest.block_size"
  , "OramManifest.bucket_size"
  , "OramManifest.bucket_count"
  , "OramManifest.blocks_per_bucket"
  , "OramManifest.tree_height"
  , "OramManifest.stash_bound"
  , "OramManifest.recursion_depth"
  , "OramManifest.metadata_pages"
  , "OramManifest.metadata_pages_per_access"
  , "OramManifest.buckets_per_access"
  , "OramManifest.accesses_per_call"
  , "OutputShape.return_present"
  , "OutputShape.return_length"
  , "ReturnChannelPublicBinding.scheme"
  , "ReturnChannelPublicBinding.session_id"
  , "ReturnChannelPublicBinding.client_public_key_hash"
  , "ReturnChannelPublicBinding.attestation_transcript_hash"
  , "EncryptedReturnPayload.binding"
  , "EncryptedReturnPayload.aad_hash"
  , "EncryptedReturnPayload.nonce"
  , "EncryptedReturnPayload.ciphertext"
  , "EncryptedReturnPayload.tag"
  , "EncryptedReturnPayload.plaintext_canonical_len"
  , "EncryptedReturnPayload.wire_len"
  , "ReturnChannelAad.domain"
  , "ReturnChannelAad.version"
  , "ReturnChannelAad.package_sha256"
  , "ReturnChannelAad.contract"
  , "ReturnChannelAad.entrypoint"
  , "ReturnChannelAad.return_policy"
  , "ReturnChannelAad.return_canonical_len"
  , "ReturnChannelAad.public_args"
  , "ReturnChannelAad.binding"
  , "PublicOutcomeTrace.entrypoint_id"
  , "PublicOutcomeTrace.public_args"
  , "PublicOutcomeTrace.public_env"
  , "PublicOutcomeTrace.termination_status"
  , "PublicOutcomeTrace.status_policy"
  , "PublicOutcomeTrace.output_shape"
  , "PublicOutcomeTrace.return_policy"
  , "PublicOutcomeTrace.return_payload"
  , "PublicOutcomeTrace.encrypted_return_payload"
  , "PublicOutcomeTrace.declassifies"
  , "PublicOutcomeTrace.gas_used"
  , "RuntimeControllerCertificate.entry_input_len"
  , "RuntimeControllerCertificate.observed_oram_accesses"
  , "RuntimeControllerObserverCertificate.public_outcome"
  , "RuntimeControllerObserverCertificate.boundary_schedule"
  , "RuntimeControllerObserverCertificate.controller_shape"
  , "RuntimeControllerObserverCertificate.normalized_micro_trace"
  , "RuntimeControllerObserverCertificate.controller_certificate"
  , "RuntimePathOramHiddenCertificate.trace"
  , "RuntimePathOramHiddenCertificate.oram_objects"
  , "RuntimePathOramHiddenCertificate.oram_leaf_public_scaffold"
  , "RuntimePathOramHiddenCertificate.oram_leaf_schedule"
  , "RuntimePathOramHiddenCertificate.oram_position_map_before"
  , "RuntimePathOramHiddenCertificate.oram_position_map_after"
  , "RuntimePathOramHiddenCertificate.oram_leaf_state_transitions"
  , "TheoremTrace.public_outcome"
  , "TheoremTrace.boundary_schedule"
  , "TheoremTrace.controller_shape"
  , "TheoremTrace.normalized_micro_trace"
  , "RuntimeTrustedKernelBundle.runtime_seed"
  , "RuntimeTrustedKernelBundle.controller_observer"
  , "RuntimeTrustedKernelBundle.kernel_witness"
  , "RuntimeTrustedKernelBundle.hidden_certificate"
  , "TraceHashBundle.opcode_trace_hash"
  , "TraceHashBundle.logical_access_trace_hash"
  , "TraceHashBundle.logical_write_trace_hash"
  , "TraceHashBundle.physical_read_trace_hash"
  , "TraceHashBundle.physical_write_trace_hash"
  , "TraceHashBundle.physical_access_trace_hash"
  , "TraceHashBundle.public_environment_projection_hash"
  , "TraceHashBundle.primitive_event_transcript_hash"
  , "TraceHashBundle.runtime_proof_object_hash"
  , "RuntimePrimitiveEvent.index"
  , "RuntimePrimitiveEvent.kind"
  , "RuntimePrimitiveEvent.payload_hash"
  , "RuntimePublicStateTransition.initial_public_state_hash"
  , "RuntimePublicStateTransition.candidate_public_state_hash"
  , "RuntimePublicStateTransition.committed_public_state_hash"
  , "RuntimePublicStateTransition.public_delta_hash"
  , "RuntimePublicStateTransition.aborted"
  , "PublicReceipt.opcode_trace"
  , "PublicReceipt.logical_accesses"
  , "PublicReceipt.logical_writes"
  , "PublicReceipt.physical_reads"
  , "PublicReceipt.physical_writes"
  , "PublicReceipt.gas_used"
  , "PublicReceipt.theorem_trace"
  , "PublicReceipt.public_state_transition"
  , "PrivateEvidence.runtime_seed"
  , "PrivateEvidence.runtime_kernel_witness"
  , "PrivateEvidence.runtime_kernel_refinement_witness"
  , "PrivateEvidence.runtime_kernel_finish_bundle"
  , "PrivateEvidence.runtime_kernel_machine_finish_witness"
  , "PrivateEvidence.runtime_trusted_kernel_bundle"
  , "PrivateEvidence.runtime_controller_certificate"
  , "PrivateEvidence.runtime_oram_objects"
  , "PrivateEvidence.runtime_oram_leaf_schedule"
  , "PrivateEvidence.runtime_oram_access_counters_before"
  , "PrivateEvidence.runtime_oram_access_counters_after"
  , "PrivateEvidence.runtime_oram_position_map_before"
  , "PrivateEvidence.runtime_oram_position_map_after"
  , "PrivateEvidence.runtime_oram_leaf_state_transitions"
  ]

def observerFieldCoverage : List ObserverFieldCoverage :=
  observerCoverageKeys.map
    (fun key =>
      { key := key
      , classification := observerCoverageClassificationFor key
      , leanAnchor := "Rust observer coverage schema mirror"
      , rationale := "field is classified by the F-06 observer coverage table"
      })

theorem observerCoverage_exactKeys :
    observerFieldCoverage.map (fun entry => entry.key) = observerCoverageKeys := by
  unfold observerFieldCoverage
  generalize observerCoverageKeys = keys
  induction keys with
  | nil => rfl
  | cons _key rest ih =>
      simp [ih]

theorem observerCoverage_allClosed :
    forall entry, entry ∈ observerFieldCoverage ->
      entry.closed = true := by
  intro entry _hMem
  unfold ObserverFieldCoverage.closed
  cases entry.classification <;> rfl

theorem observerCoverage_declaredReleaseKeysPinned :
    observerCoverageDeclaredReleaseKeys =
      [ "PublicOutcomeTrace.termination_status"
      , "PublicOutcomeTrace.return_payload"
      , "PublicOutcomeTrace.declassifies"
      ] := by
  rfl

theorem observerCoverage_cryptographicallyHiddenKeysPinned :
    observerCoverageCryptographicallyHiddenKeys =
      [ "EncryptedReturnPayload.nonce"
      , "EncryptedReturnPayload.ciphertext"
      , "EncryptedReturnPayload.tag"
      , "RuntimeTrustedKernelBundle.runtime_seed"
      , "PrivateEvidence.runtime_seed"
      , "PrivateEvidence.runtime_oram_access_counters_before"
      , "PrivateEvidence.runtime_oram_access_counters_after"
      , "PrivateEvidence.runtime_oram_position_map_before"
      , "PrivateEvidence.runtime_oram_position_map_after"
      , "PrivateEvidence.runtime_oram_leaf_state_transitions"
      ] := by
  rfl

/-- The keys of a call's public receipt: what a production runtime returns of
a call's trace. -/
def observerCoveragePublicReceiptKeys : List String :=
  [ "PublicReceipt.opcode_trace"
  , "PublicReceipt.logical_accesses"
  , "PublicReceipt.logical_writes"
  , "PublicReceipt.physical_reads"
  , "PublicReceipt.physical_writes"
  , "PublicReceipt.gas_used"
  , "PublicReceipt.theorem_trace"
  , "PublicReceipt.public_state_transition"
  ]

/-- The keys of a call's private evidence, which stays inside the runtime. -/
def observerCoveragePrivateEvidenceKeys : List String :=
  [ "PrivateEvidence.runtime_seed"
  , "PrivateEvidence.runtime_kernel_witness"
  , "PrivateEvidence.runtime_kernel_refinement_witness"
  , "PrivateEvidence.runtime_kernel_finish_bundle"
  , "PrivateEvidence.runtime_kernel_machine_finish_witness"
  , "PrivateEvidence.runtime_trusted_kernel_bundle"
  , "PrivateEvidence.runtime_controller_certificate"
  , "PrivateEvidence.runtime_oram_objects"
  , "PrivateEvidence.runtime_oram_leaf_schedule"
  , "PrivateEvidence.runtime_oram_access_counters_before"
  , "PrivateEvidence.runtime_oram_access_counters_after"
  , "PrivateEvidence.runtime_oram_position_map_before"
  , "PrivateEvidence.runtime_oram_position_map_after"
  , "PrivateEvidence.runtime_oram_leaf_state_transitions"
  ]

/-- Whether every key of the first list is in the second. -/
def allContained (keys : List String) (within : List String) : Bool :=
  keys.all (fun key => containsString key within)

/-- The receipt's and the evidence's keys are covered keys. -/
theorem observerCoverage_receiptAndEvidenceKeysCovered :
    allContained observerCoveragePublicReceiptKeys observerCoverageKeys = true ∧
      allContained observerCoveragePrivateEvidenceKeys observerCoverageKeys = true := by
  decide

/-- No field of the public receipt is classified as cryptographically hidden:
a field of a call's trace that the observer must not see is a field of the
private evidence. -/
theorem observerCoverage_publicReceipt_hasNoHiddenField :
    observerCoveragePublicReceiptKeys.all
        (fun key => !containsString key observerCoverageCryptographicallyHiddenKeys) =
      true := by
  decide

/-- Besides the bytes of an encrypted return and the replay tag inside a
trusted-kernel bundle, every cryptographically hidden key is a key of the
private evidence. -/
theorem observerCoverage_hiddenTraceKeys_arePrivateEvidence :
    (observerCoverageCryptographicallyHiddenKeys.filter
        (fun key => !containsString key observerCoveragePrivateEvidenceKeys)) =
      [ "EncryptedReturnPayload.nonce"
      , "EncryptedReturnPayload.ciphertext"
      , "EncryptedReturnPayload.tag"
      , "RuntimeTrustedKernelBundle.runtime_seed"
      ] := by
  decide

theorem observerCoverage_publicInputKeysPinned :
    observerCoveragePublicInputKeys =
      [ "ReturnChannelAad.domain"
      , "ReturnChannelAad.version"
      , "ReturnChannelAad.package_sha256"
      , "ReturnChannelAad.contract"
      , "ReturnChannelAad.entrypoint"
      , "ReturnChannelAad.return_policy"
      , "ReturnChannelAad.return_canonical_len"
      , "ReturnChannelAad.public_args"
      , "ReturnChannelAad.binding"
      , "PublicOutcomeTrace.public_env"
      ] := by
  rfl

end UOToolchain
