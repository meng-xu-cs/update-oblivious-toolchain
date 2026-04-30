use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

pub const RUNTIME_BOUNDARY_SCHEMA_VERSION: &str = "runtime-boundary-schema-v1";

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimeBoundaryEvidenceKind {
    RustVisibility,
    GeneratedSchema,
    LeanTheorem,
    ExecutableSemanticRefinement,
    SourceRegression,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct RuntimeBoundaryObligation {
    pub id: &'static str,
    pub surface: &'static str,
    pub evidence_kind: RuntimeBoundaryEvidenceKind,
    pub rust_anchor: &'static str,
    pub lean_anchor: &'static str,
    pub executable_check: &'static str,
    pub proof_critical: bool,
}

pub const RUNTIME_BOUNDARY_OBLIGATIONS: &[RuntimeBoundaryObligation] = &[
    RuntimeBoundaryObligation {
        id: "runtime_public_bridge_export_surface",
        surface: "uo-evm public bridge entrypoints",
        evidence_kind: RuntimeBoundaryEvidenceKind::RustVisibility,
        rust_anchor: "runtime/uo-evm/src/lib.rs",
        lean_anchor: "RuntimeImplementationInterface.PublicBridgeBoundary",
        executable_check: "cargo test -p uo-evm",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "runtime_kernel_refinement_witness_export_surface",
        surface: "uo-core runtime refinement witness API",
        evidence_kind: RuntimeBoundaryEvidenceKind::RustVisibility,
        rust_anchor: "crates/uo-core/src/trace.rs::RuntimeKernelRefinementWitness",
        lean_anchor: "RuntimeShellBoundary.RuntimeKernelRefinementWitness.Valid",
        executable_check: "cargo test -p uo-core runtime_refinement_witness_validate_accepts_sample",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "generated_value_ops_semantics",
        surface: "canonical Value byte encoding and equality operations",
        evidence_kind: RuntimeBoundaryEvidenceKind::ExecutableSemanticRefinement,
        rust_anchor: "crates/uo-core/src/generated_value_ops.rs",
        lean_anchor: "RuntimeValueOpsSemantics",
        executable_check: "cargo test -p uo-core generated_value_ops",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "fixed_buffer_capacity_semantics",
        surface: "fixed-capacity boxed buffer construction",
        evidence_kind: RuntimeBoundaryEvidenceKind::ExecutableSemanticRefinement,
        rust_anchor: "crates/uo-core/src/fixed_buffer.rs",
        lean_anchor: "RuntimeValueOpsSemantics.FixedByteBufferState",
        executable_check: "cargo test -p uo-core fixed_prefix_buffer_rejects_overflow_and_moves_prefix",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "generated_object_helper_semantics",
        surface: "UO object helper scans, commits, and reset/open helpers",
        evidence_kind: RuntimeBoundaryEvidenceKind::GeneratedSchema,
        rust_anchor: "runtime/uo-evm/src/generated_object_helpers.rs",
        lean_anchor: "RuntimeObjectHelpersGeneratedRust + RuntimeArrayAccessDiscipline + RuntimeSmallMapLookupDiscipline",
        executable_check: "cargo test -p uo-evm runtime::objects",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "generated_oram_codec_semantics",
        surface: "Path ORAM block/bucket codec and write-log helpers",
        evidence_kind: RuntimeBoundaryEvidenceKind::GeneratedSchema,
        rust_anchor: "runtime/uo-evm/src/generated_oram_codecs.rs",
        lean_anchor: "RuntimeOramCodecsGeneratedRust + RuntimeOramCodecSemantics + RuntimeOramWriteLogDiscipline",
        executable_check: "cargo test -p uo-evm oram::tests",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "confidential_kernel_slot_semantics",
        surface: "confidential kernel interpreter and slot lowering",
        evidence_kind: RuntimeBoundaryEvidenceKind::ExecutableSemanticRefinement,
        rust_anchor: "crates/uo-core/src/confidential_kernel.rs",
        lean_anchor: "ConfidentialKernelDsl + ConfidentialKernelGeneratedRust + RuntimeKernelSlotSupport",
        executable_check: "cargo test -p uo-core confidential_kernel",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "store_codec_semantics",
        surface: "sealed store transport codec and zeroization helpers",
        evidence_kind: RuntimeBoundaryEvidenceKind::GeneratedSchema,
        rust_anchor: "runtime/uo-store/src/generated_codec.rs",
        lean_anchor: "RuntimeStoreCodecGeneratedRust + RuntimeStoreCodecSemantics",
        executable_check: "cargo test -p uo-store",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "primitive_transcript_semantics",
        surface: "append-only primitive runtime transcript",
        evidence_kind: RuntimeBoundaryEvidenceKind::LeanTheorem,
        rust_anchor: "crates/uo-core/src/trace.rs::RuntimePrimitiveEvent",
        lean_anchor: "RuntimeRefinementJson + RuntimeShellBoundaryJson",
        executable_check: "cargo test -p uo-core trace::tests",
        proof_critical: true,
    },
    RuntimeBoundaryObligation {
        id: "static_drift_regression_inventory",
        surface: "legacy source-drift regression probes",
        evidence_kind: RuntimeBoundaryEvidenceKind::SourceRegression,
        rust_anchor: "probe/mplus-probe/src/lib.rs::static_drift_check_inventory",
        lean_anchor: "RuntimeImplementationInterface source predicates",
        executable_check: "cargo run -q -p mplus-probe -- --only static-checks",
        proof_critical: false,
    },
];

pub fn runtime_boundary_obligation_ids() -> Vec<&'static str> {
    RUNTIME_BOUNDARY_OBLIGATIONS
        .iter()
        .map(|obligation| obligation.id)
        .collect()
}

pub fn runtime_boundary_schema_is_mechanized_for_claim() -> bool {
    RUNTIME_BOUNDARY_OBLIGATIONS.iter().all(|obligation| {
        !obligation.proof_critical
            || obligation.evidence_kind != RuntimeBoundaryEvidenceKind::SourceRegression
    })
}

pub fn validate_runtime_boundary_schema() -> Result<()> {
    let mut ids = BTreeSet::new();
    for obligation in RUNTIME_BOUNDARY_OBLIGATIONS {
        if obligation.id.is_empty() {
            bail!("runtime boundary obligation has empty id");
        }
        if !ids.insert(obligation.id) {
            bail!("duplicate runtime boundary obligation id {}", obligation.id);
        }
        if obligation.surface.is_empty()
            || obligation.rust_anchor.is_empty()
            || obligation.lean_anchor.is_empty()
            || obligation.executable_check.is_empty()
        {
            bail!(
                "runtime boundary obligation {} lacks a required anchor",
                obligation.id
            );
        }
        if obligation.proof_critical
            && obligation.evidence_kind == RuntimeBoundaryEvidenceKind::SourceRegression
        {
            bail!(
                "runtime boundary obligation {} is proof-critical but only source-regression backed",
                obligation.id
            );
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runtime_boundary_schema_is_valid_and_mechanized_for_claim() {
        validate_runtime_boundary_schema().unwrap();
        assert!(runtime_boundary_schema_is_mechanized_for_claim());
    }

    #[test]
    fn runtime_boundary_schema_has_stable_id_order() {
        assert_eq!(
            runtime_boundary_obligation_ids(),
            vec![
                "runtime_public_bridge_export_surface",
                "runtime_kernel_refinement_witness_export_surface",
                "generated_value_ops_semantics",
                "fixed_buffer_capacity_semantics",
                "generated_object_helper_semantics",
                "generated_oram_codec_semantics",
                "confidential_kernel_slot_semantics",
                "store_codec_semantics",
                "primitive_transcript_semantics",
                "static_drift_regression_inventory",
            ]
        );
    }
}
