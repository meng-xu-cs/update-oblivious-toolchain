use anyhow::{bail, Result};
use serde::Serialize;
use std::collections::BTreeSet;

#[derive(Clone, Copy, Debug, Serialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum ObserverCoverageClassification {
    IncludedInLean,
    PublicInput,
    DeclaredRelease,
    CryptographicallyHidden,
    NormalizedAway,
    OutsideClaim,
}

#[derive(Clone, Copy, Debug, Serialize, PartialEq, Eq, Hash)]
pub struct ObserverSchemaCoverage {
    pub schema: &'static str,
    pub fields: &'static [&'static str],
    pub default_classification: ObserverCoverageClassification,
    pub lean_anchor: &'static str,
    pub rationale: &'static str,
}

#[derive(Clone, Copy, Debug, Serialize, PartialEq, Eq, Hash)]
pub struct ObserverFieldCoverageOverride {
    pub schema: &'static str,
    pub field: &'static str,
    pub classification: ObserverCoverageClassification,
    pub lean_anchor: &'static str,
    pub rationale: &'static str,
}

#[derive(Clone, Copy, Debug, Serialize, PartialEq, Eq, Hash)]
pub struct ObserverFieldCoverage {
    pub schema: &'static str,
    pub field: &'static str,
    pub classification: ObserverCoverageClassification,
    pub lean_anchor: &'static str,
    pub rationale: &'static str,
}

pub const RUNTIME_MANIFEST_FIELDS: &[&str] =
    &["contract", "compilation_mode", "objects", "entrypoints"];

pub const STATE_OBJECT_MANIFEST_FIELDS: &[&str] = &[
    "id",
    "name",
    "kind",
    "backend",
    "capacity",
    "value_type",
    "key_type",
    "oram",
];

pub const RUNTIME_KERNEL_STEP_MANIFEST_FIELDS: &[&str] = &["opcode", "object_id"];

pub const ENTRYPOINT_MANIFEST_FIELDS: &[&str] = &[
    "secret_args",
    "param_names",
    "public_env",
    "entry_input_len",
    "initializer",
    "requires_initialized",
    "public_gas_budget",
    "arena_bytes",
    "max_stack_words",
    "max_hash_part_bytes",
    "return_canonical_len",
    "returns",
    "status",
    "declassifies",
    "public_state_declassifies",
    "confidential_program",
    "confidential_slot_program",
    "kernel_steps",
    "uocell_reads",
    "uocell_writes",
    "uoarray_reads",
    "uoarray_writes",
    "uomap_reads",
    "uomap_writes",
    "max_commit_ops",
    "oram_accesses",
];

pub const ORAM_MANIFEST_FIELDS: &[&str] = &[
    "scheme",
    "block_size",
    "bucket_size",
    "bucket_count",
    "blocks_per_bucket",
    "tree_height",
    "stash_bound",
    "recursion_depth",
    "metadata_pages",
    "metadata_pages_per_access",
    "buckets_per_access",
    "accesses_per_call",
];

pub const OUTPUT_SHAPE_FIELDS: &[&str] = &["return_present", "return_length"];

pub const RETURN_CHANNEL_PUBLIC_BINDING_FIELDS: &[&str] = &[
    "scheme",
    "session_id",
    "client_public_key_hash",
    "attestation_transcript_hash",
];

pub const ENCRYPTED_RETURN_PAYLOAD_FIELDS: &[&str] = &[
    "binding",
    "aad_hash",
    "nonce",
    "ciphertext",
    "tag",
    "plaintext_canonical_len",
    "wire_len",
];

pub const RETURN_CHANNEL_AAD_FIELDS: &[&str] = &[
    "domain",
    "version",
    "package_sha256",
    "contract",
    "entrypoint",
    "return_policy",
    "return_canonical_len",
    "public_args",
    "binding",
];

pub const PUBLIC_OUTCOME_TRACE_FIELDS: &[&str] = &[
    "entrypoint_id",
    "public_args",
    "public_env",
    "termination_status",
    "status_policy",
    "output_shape",
    "return_policy",
    "return_payload",
    "encrypted_return_payload",
    "declassifies",
    "gas_used",
];

pub const RUNTIME_CONTROLLER_CERTIFICATE_FIELDS: &[&str] =
    &["entry_input_len", "observed_oram_accesses"];

pub const RUNTIME_CONTROLLER_OBSERVER_CERTIFICATE_FIELDS: &[&str] = &[
    "public_outcome",
    "boundary_schedule",
    "controller_shape",
    "normalized_micro_trace",
    "controller_certificate",
];

pub const RUNTIME_PATH_ORAM_HIDDEN_CERTIFICATE_FIELDS: &[&str] = &[
    "trace",
    "oram_objects",
    "oram_leaf_public_scaffold",
    "oram_leaf_schedule",
    "oram_position_map_before",
    "oram_position_map_after",
    "oram_leaf_state_transitions",
];

pub const THEOREM_TRACE_FIELDS: &[&str] = &[
    "public_outcome",
    "boundary_schedule",
    "controller_shape",
    "normalized_micro_trace",
];

pub const RUNTIME_TRUSTED_KERNEL_BUNDLE_FIELDS: &[&str] = &[
    "runtime_seed",
    "controller_observer",
    "kernel_witness",
    "hidden_certificate",
];

pub const TRACE_HASH_BUNDLE_FIELDS: &[&str] = &[
    "opcode_trace_hash",
    "logical_access_trace_hash",
    "logical_write_trace_hash",
    "physical_read_trace_hash",
    "physical_write_trace_hash",
    "physical_access_trace_hash",
    "public_environment_projection_hash",
    "primitive_event_transcript_hash",
    "runtime_proof_object_hash",
];

pub const RUNTIME_PRIMITIVE_EVENT_FIELDS: &[&str] = &["index", "kind", "payload_hash"];

pub const RUNTIME_PUBLIC_STATE_TRANSITION_FIELDS: &[&str] = &[
    "initial_public_state_hash",
    "candidate_public_state_hash",
    "committed_public_state_hash",
    "public_delta_hash",
    "aborted",
];

/// The fields of `ExecutionTrace`: a call's receipt and its private evidence.
/// In JSON the two are flattened into one object.
pub const EXECUTION_TRACE_FIELDS: &[&str] = &["receipt", "evidence"];

/// The fields of `PublicReceipt`: what the observer of a call sees.
pub const PUBLIC_RECEIPT_FIELDS: &[&str] = &[
    "opcode_trace",
    "logical_accesses",
    "logical_writes",
    "physical_reads",
    "physical_writes",
    "gas_used",
    "theorem_trace",
    "public_state_transition",
];

/// The fields of `PrivateEvidence`: what stays inside the runtime.
pub const PRIVATE_EVIDENCE_FIELDS: &[&str] = &[
    "runtime_seed",
    "runtime_kernel_witness",
    "runtime_kernel_refinement_witness",
    "runtime_kernel_finish_bundle",
    "runtime_kernel_machine_finish_witness",
    "runtime_trusted_kernel_bundle",
    "runtime_controller_certificate",
    "runtime_oram_objects",
    "runtime_oram_leaf_schedule",
    "runtime_oram_access_counters_before",
    "runtime_oram_access_counters_after",
    "runtime_oram_position_map_before",
    "runtime_oram_position_map_after",
    "runtime_oram_leaf_state_transitions",
];

pub const OBSERVER_SCHEMA_COVERAGE: &[ObserverSchemaCoverage] = &[
    ObserverSchemaCoverage {
        schema: "RuntimeManifest",
        fields: RUNTIME_MANIFEST_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ProofRelevantManifestView / TranslationValidationJson",
        rationale: "runtime manifest identity and shape are mirrored by the proof-relevant manifest view",
    },
    ObserverSchemaCoverage {
        schema: "StateObjectManifest",
        fields: STATE_OBJECT_MANIFEST_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ProofRelevantManifestObjectView",
        rationale: "state object identity, backend, type, capacity, and ORAM shape feed the Lean manifest view",
    },
    ObserverSchemaCoverage {
        schema: "RuntimeKernelStepManifest",
        fields: RUNTIME_KERNEL_STEP_MANIFEST_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ProofRelevantKernelStepView",
        rationale: "kernel step opcode and object binding are part of the proof-relevant runtime schedule",
    },
    ObserverSchemaCoverage {
        schema: "EntrypointManifest",
        fields: ENTRYPOINT_MANIFEST_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ProofRelevantEntrypointView",
        rationale: "entrypoint schedule, bounds, return/status policy, and release labels are mirrored by Lean validation",
    },
    ObserverSchemaCoverage {
        schema: "OramManifest",
        fields: ORAM_MANIFEST_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ProofRelevantOramView / OramConfig",
        rationale: "ORAM resource and shape fields select the admitted ORAM theorem instance",
    },
    ObserverSchemaCoverage {
        schema: "OutputShape",
        fields: OUTPUT_SHAPE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "OutputShape / SGXPublicOutcome.outputShape",
        rationale: "return-presence and return-length are public observer components in Lean",
    },
    ObserverSchemaCoverage {
        schema: "ReturnChannelPublicBinding",
        fields: RETURN_CHANNEL_PUBLIC_BINDING_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ReturnChannelPublicBinding / ImportedReturnChannelPublicBinding",
        rationale: "return-channel public binding is public evidence and is imported into Lean",
    },
    ObserverSchemaCoverage {
        schema: "EncryptedReturnPayload",
        fields: ENCRYPTED_RETURN_PAYLOAD_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "EncryptedReturnPayload / ImportedEncryptedReturnPayload",
        rationale: "encrypted return evidence is part of the public outcome imported by Lean",
    },
    ObserverSchemaCoverage {
        schema: "ReturnChannelAad",
        fields: RETURN_CHANNEL_AAD_FIELDS,
        default_classification: ObserverCoverageClassification::PublicInput,
        lean_anchor: "EncryptedReturnPolicyWellFormed",
        rationale: "AEAD associated data is built only from package identity, public call data, policy, and public binding",
    },
    ObserverSchemaCoverage {
        schema: "PublicOutcomeTrace",
        fields: PUBLIC_OUTCOME_TRACE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "SGXPublicOutcome / ImportedPublicOutcomeTrace",
        rationale: "public outcome fields are the Lean observer projection for entrypoint result visibility",
    },
    ObserverSchemaCoverage {
        schema: "RuntimeControllerCertificate",
        fields: RUNTIME_CONTROLLER_CERTIFICATE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "RuntimeControllerCertificate / ImportedRuntimeControllerCertificate",
        rationale: "controller certificate shape feeds the controller observer and boundary schedule proofs",
    },
    ObserverSchemaCoverage {
        schema: "RuntimeControllerObserverCertificate",
        fields: RUNTIME_CONTROLLER_OBSERVER_CERTIFICATE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "RuntimeControllerObserverCertificate / ImportedRuntimeControllerObserverCertificate",
        rationale: "the controller observer certificate is the Lean-facing public observer bundle",
    },
    ObserverSchemaCoverage {
        schema: "RuntimePathOramHiddenCertificate",
        fields: RUNTIME_PATH_ORAM_HIDDEN_CERTIFICATE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "RuntimePathOramHiddenCertificate / ImportedRuntimePathOramHiddenCertificate",
        rationale: "hidden ORAM witness fields are imported as proof evidence and discharged by ORAM refinement checks",
    },
    ObserverSchemaCoverage {
        schema: "TheoremTrace",
        fields: THEOREM_TRACE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "TheoremTrace / SGXView",
        rationale: "the theorem trace contains the public outcome, boundary schedule, and normalized micro trace used by Lean",
    },
    ObserverSchemaCoverage {
        schema: "RuntimeTrustedKernelBundle",
        fields: RUNTIME_TRUSTED_KERNEL_BUNDLE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "RuntimeTrustedKernelBundle / RuntimeTrustedKernelJson",
        rationale: "trusted-kernel bundle fields are imported proof evidence for the runtime kernel boundary",
    },
    ObserverSchemaCoverage {
        schema: "TraceHashBundle",
        fields: TRACE_HASH_BUNDLE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "TraceHashBundle / primitive event transcript",
        rationale: "trace hashes bind observer and proof payload transcripts by named digest fields",
    },
    ObserverSchemaCoverage {
        schema: "RuntimePrimitiveEvent",
        fields: RUNTIME_PRIMITIVE_EVENT_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "RuntimePrimitiveEvent / primitive_event_transcript",
        rationale: "primitive event transcript fields bind each runtime evidence payload to its ordered event kind",
    },
    ObserverSchemaCoverage {
        schema: "RuntimePublicStateTransition",
        fields: RUNTIME_PUBLIC_STATE_TRANSITION_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "PublicStateTransition / RuntimePublicStateTransition",
        rationale: "public-state commit and rollback hashes are mirrored by the abort rollback theorem surface",
    },
    ObserverSchemaCoverage {
        schema: "PublicReceipt",
        fields: PUBLIC_RECEIPT_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ExecutionTrace / RuntimeRefinementWitness / primitive_event_transcript",
        rationale: "receipt fields are what the observer of a call sees, and are projected into the Lean observer, the refinement witness or the primitive transcript",
    },
    ObserverSchemaCoverage {
        schema: "PrivateEvidence",
        fields: PRIVATE_EVIDENCE_FIELDS,
        default_classification: ObserverCoverageClassification::IncludedInLean,
        lean_anchor: "ExecutionTrace / RuntimeRefinementWitness / primitive_event_transcript",
        rationale: "evidence fields stay inside the runtime; a diagnostics build projects them into the Lean refinement witness, hidden certificate or primitive transcript",
    },
];

pub const OBSERVER_FIELD_COVERAGE_OVERRIDES: &[ObserverFieldCoverageOverride] = &[
    ObserverFieldCoverageOverride {
        schema: "EncryptedReturnPayload",
        field: "nonce",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "encryptedReturnPolicy_hasNonceSessionAndAttestationEvidence",
        rationale: "nonce is public freshness evidence for AEAD and gates ciphertext indistinguishability assumptions",
    },
    ObserverFieldCoverageOverride {
        schema: "EncryptedReturnPayload",
        field: "ciphertext",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "EncryptedReturnPolicyWellFormed",
        rationale: "ciphertext hides plaintext return bytes under the encrypted-return AEAD assumption",
    },
    ObserverFieldCoverageOverride {
        schema: "EncryptedReturnPayload",
        field: "tag",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "EncryptedReturnPolicyWellFormed",
        rationale: "tag exposes only AEAD integrity evidence under the return-channel assumption",
    },
    ObserverFieldCoverageOverride {
        schema: "PublicOutcomeTrace",
        field: "termination_status",
        classification: ObserverCoverageClassification::DeclaredRelease,
        lean_anchor: "SGXPublicOutcome.terminationStatus / exact status declassification",
        rationale: "status is public only when public by policy or exactly released by status declassification",
    },
    ObserverFieldCoverageOverride {
        schema: "PublicOutcomeTrace",
        field: "return_payload",
        classification: ObserverCoverageClassification::DeclaredRelease,
        lean_anchor: "SGXPublicOutcome.returnPayload / exact return declassification",
        rationale: "plaintext return payload is admitted only through the exact return declassification policy",
    },
    ObserverFieldCoverageOverride {
        schema: "PublicOutcomeTrace",
        field: "declassifies",
        classification: ObserverCoverageClassification::DeclaredRelease,
        lean_anchor: "ImportedPublicOutcomeTrace.toPublicOutcome / exact release labels",
        rationale: "release labels are proof-relevant and must exactly match the declared release channel",
    },
    ObserverFieldCoverageOverride {
        schema: "RuntimeTrustedKernelBundle",
        field: "runtime_seed",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "runtimeFreshnessDiscipline",
        rationale: "the replay tag of a seeded test or diagnostics deployment, absent from a production deployment; seeded witness families are proof evidence for fresh-coin assumptions, not host-observable data",
    },
    ObserverFieldCoverageOverride {
        schema: "PrivateEvidence",
        field: "runtime_seed",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "runtimeFreshnessDiscipline",
        rationale: "the replay tag of a seeded test or diagnostics deployment, absent from a production deployment, whose keys derive from a master secret that no trace carries; it feeds fresh-coin proof families and is covered by the freshness discipline",
    },
    ObserverFieldCoverageOverride {
        schema: "PrivateEvidence",
        field: "runtime_oram_access_counters_before",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "PathOramLocalPosmapV1StandardTheorem",
        rationale: "ORAM counters are hidden witness state covered by the ORAM refinement and freshness assumptions",
    },
    ObserverFieldCoverageOverride {
        schema: "PrivateEvidence",
        field: "runtime_oram_access_counters_after",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "PathOramLocalPosmapV1StandardTheorem",
        rationale: "ORAM counters are hidden witness state covered by the ORAM refinement and freshness assumptions",
    },
    ObserverFieldCoverageOverride {
        schema: "PrivateEvidence",
        field: "runtime_oram_position_map_before",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "PathOramLocalPosmapV1StandardTheorem",
        rationale: "position map contents are hidden ORAM witness state and not part of the public observer",
    },
    ObserverFieldCoverageOverride {
        schema: "PrivateEvidence",
        field: "runtime_oram_position_map_after",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "PathOramLocalPosmapV1StandardTheorem",
        rationale: "position map contents are hidden ORAM witness state and not part of the public observer",
    },
    ObserverFieldCoverageOverride {
        schema: "PrivateEvidence",
        field: "runtime_oram_leaf_state_transitions",
        classification: ObserverCoverageClassification::CryptographicallyHidden,
        lean_anchor: "PathOramLocalPosmapV1StandardTheorem",
        rationale: "a leaf transition names the slot an access touched and the leaf it moved to, which are hidden ORAM witness state",
    },
];

/// The schemas whose values a `PublicReceipt` holds, itself included.
pub const PUBLIC_RECEIPT_SCHEMAS: &[&str] = &[
    "PublicReceipt",
    "TheoremTrace",
    "PublicOutcomeTrace",
    "OutputShape",
    "EncryptedReturnPayload",
    "ReturnChannelPublicBinding",
    "RuntimePublicStateTransition",
];

/// The fields that a `PublicReceipt` holds and that are classified
/// `CryptographicallyHidden`: the bytes of an encrypted return, which the
/// caller is meant to receive and only the client can open. Every other
/// field so classified belongs to the private evidence or to a proof object
/// built from it.
pub fn public_receipt_hidden_fields() -> Vec<ObserverFieldCoverage> {
    observer_field_coverage_table()
        .into_iter()
        .filter(|entry| {
            PUBLIC_RECEIPT_SCHEMAS.contains(&entry.schema)
                && entry.classification == ObserverCoverageClassification::CryptographicallyHidden
        })
        .collect()
}

pub fn observer_schema_coverage(schema: &str) -> Option<&'static ObserverSchemaCoverage> {
    OBSERVER_SCHEMA_COVERAGE
        .iter()
        .find(|coverage| coverage.schema == schema)
}

pub fn observer_field_coverage(schema: &str, field: &str) -> Option<ObserverFieldCoverage> {
    let schema_coverage = observer_schema_coverage(schema)?;
    let canonical_field = schema_coverage
        .fields
        .iter()
        .copied()
        .find(|candidate| *candidate == field)?;
    if let Some(override_coverage) = OBSERVER_FIELD_COVERAGE_OVERRIDES
        .iter()
        .find(|coverage| coverage.schema == schema && coverage.field == field)
    {
        return Some(ObserverFieldCoverage {
            schema: override_coverage.schema,
            field: override_coverage.field,
            classification: override_coverage.classification,
            lean_anchor: override_coverage.lean_anchor,
            rationale: override_coverage.rationale,
        });
    }
    Some(ObserverFieldCoverage {
        schema: schema_coverage.schema,
        field: canonical_field,
        classification: schema_coverage.default_classification,
        lean_anchor: schema_coverage.lean_anchor,
        rationale: schema_coverage.rationale,
    })
}

pub fn observer_field_coverage_table() -> Vec<ObserverFieldCoverage> {
    OBSERVER_SCHEMA_COVERAGE
        .iter()
        .flat_map(|schema| {
            schema
                .fields
                .iter()
                .map(move |field| observer_field_coverage(schema.schema, field).unwrap())
        })
        .collect()
}

pub fn validate_observer_coverage_table() -> Result<()> {
    let mut schemas = BTreeSet::new();
    let mut fields = BTreeSet::new();
    for schema in OBSERVER_SCHEMA_COVERAGE {
        if !schemas.insert(schema.schema) {
            bail!("duplicate observer coverage schema {}", schema.schema);
        }
        if schema.fields.is_empty() {
            bail!("observer coverage schema {} has no fields", schema.schema);
        }
        if schema.lean_anchor.is_empty() || schema.rationale.is_empty() {
            bail!(
                "observer coverage schema {} lacks proof rationale",
                schema.schema
            );
        }
        let mut local_fields = BTreeSet::new();
        for field in schema.fields {
            if !local_fields.insert(*field) {
                bail!(
                    "duplicate observer coverage field {}.{}",
                    schema.schema,
                    field
                );
            }
            fields.insert((schema.schema, *field));
        }
    }

    let mut overrides = BTreeSet::new();
    for override_coverage in OBSERVER_FIELD_COVERAGE_OVERRIDES {
        let key = (override_coverage.schema, override_coverage.field);
        if !fields.contains(&key) {
            bail!(
                "observer coverage override references unknown field {}.{}",
                override_coverage.schema,
                override_coverage.field
            );
        }
        if !overrides.insert(key) {
            bail!(
                "duplicate observer coverage override {}.{}",
                override_coverage.schema,
                override_coverage.field
            );
        }
        if override_coverage.lean_anchor.is_empty() || override_coverage.rationale.is_empty() {
            bail!(
                "observer coverage override {}.{} lacks proof rationale",
                override_coverage.schema,
                override_coverage.field
            );
        }
    }

    for (schema, field) in fields {
        if observer_field_coverage(schema, field).is_none() {
            bail!("missing observer coverage field {}.{}", schema, field);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rust_struct_fields(source: &str, struct_name: &str) -> Vec<String> {
        let marker = format!("struct {struct_name}");
        let mut inside = false;
        let mut fields = Vec::new();
        for line in source.lines() {
            let trimmed = line.trim();
            if !inside {
                if trimmed.contains(&marker) && trimmed.contains('{') {
                    inside = true;
                }
                continue;
            }
            if trimmed.starts_with('}') {
                break;
            }
            if trimmed.is_empty() || trimmed.starts_with("#[") || trimmed.starts_with("//") {
                continue;
            }
            let Some((field_name, _ty)) = trimmed.split_once(':') else {
                continue;
            };
            let field_name = field_name.trim();
            let field_name = field_name
                .strip_prefix("pub(crate) ")
                .or_else(|| field_name.strip_prefix("pub "))
                .unwrap_or(field_name);
            if field_name
                .chars()
                .all(|ch| ch == '_' || ch.is_ascii_alphanumeric())
            {
                fields.push(field_name.to_owned());
            }
        }
        assert!(
            !fields.is_empty(),
            "no fields parsed for struct {struct_name}"
        );
        fields
    }

    fn assert_source_fields(source: &str, struct_name: &str, expected: &[&str]) {
        let actual = rust_struct_fields(source, struct_name);
        assert_eq!(
            actual,
            expected
                .iter()
                .map(|field| (*field).to_owned())
                .collect::<Vec<_>>(),
            "{struct_name} observer coverage fields drifted"
        );
    }

    #[test]
    fn observer_coverage_table_is_complete_and_unique() {
        validate_observer_coverage_table().unwrap();
        let table = observer_field_coverage_table();
        let expected_len = OBSERVER_SCHEMA_COVERAGE
            .iter()
            .map(|schema| schema.fields.len())
            .sum::<usize>();
        assert_eq!(table.len(), expected_len);
        assert!(table
            .iter()
            .any(|entry| entry.classification == ObserverCoverageClassification::DeclaredRelease));
        assert!(table
            .iter()
            .any(|entry| entry.classification
                == ObserverCoverageClassification::CryptographicallyHidden));
    }

    #[test]
    fn observer_coverage_tracks_runtime_struct_sources() {
        let manifest_source = include_str!("manifest.rs");
        assert_source_fields(manifest_source, "RuntimeManifest", RUNTIME_MANIFEST_FIELDS);
        assert_source_fields(
            manifest_source,
            "StateObjectManifest",
            STATE_OBJECT_MANIFEST_FIELDS,
        );
        assert_source_fields(
            manifest_source,
            "RuntimeKernelStepManifest",
            RUNTIME_KERNEL_STEP_MANIFEST_FIELDS,
        );
        assert_source_fields(
            manifest_source,
            "EntrypointManifest",
            ENTRYPOINT_MANIFEST_FIELDS,
        );
        assert_source_fields(manifest_source, "OramManifest", ORAM_MANIFEST_FIELDS);

        let trace_source = include_str!("trace.rs");
        assert_source_fields(trace_source, "OutputShape", OUTPUT_SHAPE_FIELDS);
        assert_source_fields(
            trace_source,
            "ReturnChannelPublicBinding",
            RETURN_CHANNEL_PUBLIC_BINDING_FIELDS,
        );
        assert_source_fields(
            trace_source,
            "EncryptedReturnPayload",
            ENCRYPTED_RETURN_PAYLOAD_FIELDS,
        );
        assert_source_fields(
            trace_source,
            "PublicOutcomeTrace",
            PUBLIC_OUTCOME_TRACE_FIELDS,
        );
        assert_source_fields(
            trace_source,
            "RuntimeControllerCertificate",
            RUNTIME_CONTROLLER_CERTIFICATE_FIELDS,
        );
        assert_source_fields(
            trace_source,
            "RuntimeControllerObserverCertificate",
            RUNTIME_CONTROLLER_OBSERVER_CERTIFICATE_FIELDS,
        );
        assert_source_fields(
            trace_source,
            "RuntimePathOramHiddenCertificate",
            RUNTIME_PATH_ORAM_HIDDEN_CERTIFICATE_FIELDS,
        );
        assert_source_fields(trace_source, "TheoremTrace", THEOREM_TRACE_FIELDS);
        assert_source_fields(
            trace_source,
            "RuntimeTrustedKernelBundle",
            RUNTIME_TRUSTED_KERNEL_BUNDLE_FIELDS,
        );
        assert_source_fields(trace_source, "TraceHashBundle", TRACE_HASH_BUNDLE_FIELDS);
        assert_source_fields(
            trace_source,
            "RuntimePrimitiveEvent",
            RUNTIME_PRIMITIVE_EVENT_FIELDS,
        );
        assert_source_fields(
            trace_source,
            "RuntimePublicStateTransition",
            RUNTIME_PUBLIC_STATE_TRANSITION_FIELDS,
        );
        assert_source_fields(trace_source, "ExecutionTrace", EXECUTION_TRACE_FIELDS);
        assert_source_fields(trace_source, "PublicReceipt", PUBLIC_RECEIPT_FIELDS);
        assert_source_fields(trace_source, "PrivateEvidence", PRIVATE_EVIDENCE_FIELDS);

        let return_channel_source = include_str!("../../../runtime/uo-evm/src/return_channel.rs");
        assert_source_fields(
            return_channel_source,
            "ReturnChannelAad",
            RETURN_CHANNEL_AAD_FIELDS,
        );
    }

    /// A field of a call's trace that the observer must not see is a field
    /// of the private evidence, never of the receipt.
    #[test]
    fn a_hidden_trace_field_is_private_evidence() {
        let table = observer_field_coverage_table();
        let hidden = |schema: &str| -> Vec<&str> {
            table
                .iter()
                .filter(|entry| {
                    entry.schema == schema
                        && entry.classification
                            == ObserverCoverageClassification::CryptographicallyHidden
                })
                .map(|entry| entry.field)
                .collect()
        };
        assert_eq!(hidden("PublicReceipt"), Vec::<&str>::new());
        assert_eq!(
            hidden("PrivateEvidence"),
            [
                "runtime_seed",
                "runtime_oram_access_counters_before",
                "runtime_oram_access_counters_after",
                "runtime_oram_position_map_before",
                "runtime_oram_position_map_after",
                "runtime_oram_leaf_state_transitions",
            ]
        );
        // The two types share no field, so the flattened JSON of a trace
        // names each field once.
        for field in PUBLIC_RECEIPT_FIELDS {
            assert!(!PRIVATE_EVIDENCE_FIELDS.contains(field));
        }
        // What a receipt holds besides its own fields hides only the bytes
        // of an encrypted return.
        let reachable: Vec<String> = public_receipt_hidden_fields()
            .iter()
            .map(|entry| format!("{}.{}", entry.schema, entry.field))
            .collect();
        assert_eq!(
            reachable,
            [
                "EncryptedReturnPayload.nonce",
                "EncryptedReturnPayload.ciphertext",
                "EncryptedReturnPayload.tag",
            ]
        );
        for schema in PUBLIC_RECEIPT_SCHEMAS {
            assert!(observer_schema_coverage(schema).is_some(), "{schema}");
        }
    }

    #[test]
    fn observer_coverage_has_lean_mirror_for_every_field() {
        let lean_source = include_str!("../../../proof/lean/UOToolchain/ObserverCoverage.lean");
        for entry in observer_field_coverage_table() {
            let key = format!("{}.{}", entry.schema, entry.field);
            assert!(
                lean_source.contains(&format!("\"{key}\"")),
                "Lean observer coverage mirror missing {key}"
            );
        }
        assert!(lean_source.contains("observerCoverage_exactKeys"));
        assert!(lean_source.contains("observerCoverage_allClosed"));
    }
}
