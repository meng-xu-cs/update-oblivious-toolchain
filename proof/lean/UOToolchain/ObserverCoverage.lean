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
  , "ExecutionTrace.runtime_seed"
  , "ExecutionTrace.runtime_oram_access_counters_before"
  , "ExecutionTrace.runtime_oram_access_counters_after"
  , "ExecutionTrace.runtime_oram_position_map_before"
  , "ExecutionTrace.runtime_oram_position_map_after"
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
  , "ExecutionTrace.opcode_trace"
  , "ExecutionTrace.logical_accesses"
  , "ExecutionTrace.logical_writes"
  , "ExecutionTrace.physical_reads"
  , "ExecutionTrace.physical_writes"
  , "ExecutionTrace.gas_used"
  , "ExecutionTrace.theorem_trace"
  , "ExecutionTrace.public_state_transition"
  , "ExecutionTrace.runtime_seed"
  , "ExecutionTrace.runtime_kernel_witness"
  , "ExecutionTrace.runtime_kernel_refinement_witness"
  , "ExecutionTrace.runtime_kernel_finish_bundle"
  , "ExecutionTrace.runtime_kernel_machine_finish_witness"
  , "ExecutionTrace.runtime_trusted_kernel_bundle"
  , "ExecutionTrace.runtime_controller_certificate"
  , "ExecutionTrace.runtime_oram_objects"
  , "ExecutionTrace.runtime_oram_leaf_schedule"
  , "ExecutionTrace.runtime_oram_access_counters_before"
  , "ExecutionTrace.runtime_oram_access_counters_after"
  , "ExecutionTrace.runtime_oram_position_map_before"
  , "ExecutionTrace.runtime_oram_position_map_after"
  , "ExecutionTrace.runtime_oram_leaf_state_transitions"
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
      , "ExecutionTrace.runtime_seed"
      , "ExecutionTrace.runtime_oram_access_counters_before"
      , "ExecutionTrace.runtime_oram_access_counters_after"
      , "ExecutionTrace.runtime_oram_position_map_before"
      , "ExecutionTrace.runtime_oram_position_map_after"
      ] := by
  rfl

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
