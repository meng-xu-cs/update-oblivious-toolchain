namespace UOToolchain

inductive RuntimeBoundaryEvidenceKind where
  | rustVisibility
  | generatedSchema
  | leanTheorem
  | executableSemanticRefinement
  | sourceRegression
  deriving Repr, DecidableEq

structure RuntimeBoundaryObligation where
  id : String
  surface : String
  evidenceKind : RuntimeBoundaryEvidenceKind
  rustAnchor : String
  leanAnchor : String
  executableCheck : String
  proofCritical : Bool
  deriving Repr, DecidableEq

def runtimeBoundarySchemaVersion : String :=
  "runtime-boundary-schema-v1"

def runtimeBoundaryObligations : List RuntimeBoundaryObligation :=
  [ { id := "runtime_public_bridge_export_surface"
    , surface := "uo-evm public bridge entrypoints"
    , evidenceKind := .rustVisibility
    , rustAnchor := "runtime/uo-evm/src/lib.rs"
    , leanAnchor := "RuntimeImplementationInterface.PublicBridgeBoundary"
    , executableCheck := "cargo test -p uo-evm"
    , proofCritical := true
    }
  , { id := "runtime_kernel_refinement_witness_export_surface"
    , surface := "uo-core runtime refinement witness API"
    , evidenceKind := .rustVisibility
    , rustAnchor := "crates/uo-core/src/trace.rs::RuntimeKernelRefinementWitness"
    , leanAnchor := "RuntimeShellBoundary.RuntimeKernelRefinementWitness.Valid"
    , executableCheck := "cargo test -p uo-core runtime_refinement_witness_validate_accepts_sample"
    , proofCritical := true
    }
  , { id := "generated_value_ops_semantics"
    , surface := "canonical Value byte encoding and equality operations"
    , evidenceKind := .executableSemanticRefinement
    , rustAnchor := "crates/uo-core/src/generated_value_ops.rs"
    , leanAnchor := "RuntimeValueOpsSemantics"
    , executableCheck := "cargo test -p uo-core generated_value_ops"
    , proofCritical := true
    }
  , { id := "fixed_buffer_capacity_semantics"
    , surface := "fixed-capacity boxed buffer construction"
    , evidenceKind := .executableSemanticRefinement
    , rustAnchor := "crates/uo-core/src/fixed_buffer.rs"
    , leanAnchor := "RuntimeValueOpsSemantics.FixedByteBufferState"
    , executableCheck := "cargo test -p uo-core fixed_prefix_buffer_rejects_overflow_and_moves_prefix"
    , proofCritical := true
    }
  , { id := "generated_object_helper_semantics"
    , surface := "UO object helper scans, commits, and reset/open helpers"
    , evidenceKind := .generatedSchema
    , rustAnchor := "runtime/uo-evm/src/generated_object_helpers.rs"
    , leanAnchor := "RuntimeObjectHelpersGeneratedRust + RuntimeArrayAccessDiscipline + RuntimeSmallMapLookupDiscipline"
    , executableCheck := "cargo test -p uo-evm runtime::objects"
    , proofCritical := true
    }
  , { id := "generated_oram_codec_semantics"
    , surface := "Path ORAM block/bucket codec and write-log helpers"
    , evidenceKind := .generatedSchema
    , rustAnchor := "runtime/uo-evm/src/generated_oram_codecs.rs"
    , leanAnchor := "RuntimeOramCodecsGeneratedRust + RuntimeOramCodecSemantics + RuntimeOramWriteLogDiscipline"
    , executableCheck := "cargo test -p uo-evm oram::tests"
    , proofCritical := true
    }
  , { id := "confidential_kernel_slot_semantics"
    , surface := "confidential kernel interpreter and slot lowering"
    , evidenceKind := .executableSemanticRefinement
    , rustAnchor := "crates/uo-core/src/confidential_kernel.rs"
    , leanAnchor := "ConfidentialKernelDsl + ConfidentialKernelGeneratedRust + RuntimeKernelSlotSupport"
    , executableCheck := "cargo test -p uo-core confidential_kernel"
    , proofCritical := true
    }
  , { id := "store_codec_semantics"
    , surface := "sealed store transport codec and zeroization helpers"
    , evidenceKind := .generatedSchema
    , rustAnchor := "runtime/uo-store/src/generated_codec.rs"
    , leanAnchor := "RuntimeStoreCodecGeneratedRust + RuntimeStoreCodecSemantics"
    , executableCheck := "cargo test -p uo-store"
    , proofCritical := true
    }
  , { id := "primitive_transcript_semantics"
    , surface := "append-only primitive runtime transcript"
    , evidenceKind := .leanTheorem
    , rustAnchor := "crates/uo-core/src/trace.rs::RuntimePrimitiveEvent"
    , leanAnchor := "RuntimeRefinementJson + RuntimeShellBoundaryJson"
    , executableCheck := "cargo test -p uo-core trace::tests"
    , proofCritical := true
    }
  , { id := "static_drift_regression_inventory"
    , surface := "legacy source-drift regression probes"
    , evidenceKind := .sourceRegression
    , rustAnchor := "probe/mplus-probe/src/lib.rs::static_drift_check_inventory"
    , leanAnchor := "RuntimeImplementationInterface source predicates"
    , executableCheck := "cargo run -q -p mplus-probe -- --only static-checks"
    , proofCritical := false
    }
  ]

def runtimeBoundaryObligationIds : List String :=
  [ "runtime_public_bridge_export_surface"
  , "runtime_kernel_refinement_witness_export_surface"
  , "generated_value_ops_semantics"
  , "fixed_buffer_capacity_semantics"
  , "generated_object_helper_semantics"
  , "generated_oram_codec_semantics"
  , "confidential_kernel_slot_semantics"
  , "store_codec_semantics"
  , "primitive_transcript_semantics"
  , "static_drift_regression_inventory"
  ]

def RuntimeBoundaryEvidenceKind.mechanizedForClaim :
    RuntimeBoundaryEvidenceKind → Bool
  | .sourceRegression => false
  | _ => true

def RuntimeBoundaryObligation.mechanizedForClaim
    (obligation : RuntimeBoundaryObligation) : Bool :=
  !obligation.proofCritical || obligation.evidenceKind.mechanizedForClaim

def runtimeBoundarySchemaAllProofCriticalMechanized : Bool :=
  runtimeBoundaryObligations.all RuntimeBoundaryObligation.mechanizedForClaim

theorem runtimeBoundaryObligations_ids_match :
    runtimeBoundaryObligations.map (fun obligation => obligation.id) =
      runtimeBoundaryObligationIds := by
  rfl

theorem runtimeBoundaryObligationIds_nodup :
    runtimeBoundaryObligationIds.Nodup := by
  native_decide

theorem runtimeBoundarySchema_allProofCriticalMechanized :
    runtimeBoundarySchemaAllProofCriticalMechanized = true := by
  native_decide

end UOToolchain
