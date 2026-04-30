import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeConfidentialCoreKernelFinishSlotJson
import UOToolchain.RuntimeConfidentialCoreKernelInterfaceSlotJson
import UOToolchain.RuntimeConfidentialCoreShellBoundaryLoweringJson
import UOToolchain.RuntimeConfidentialCoreShellBoundarySlotJson
import UOToolchain.RuntimeConfidentialProofBundleFamilyJson
import UOToolchain.RuntimeImplementationInterfaceJson
import UOToolchain.RuntimeKernelFinishBundleJson
import UOToolchain.RuntimeKernelMachineFinishBoundaryJson
import UOToolchain.RuntimeKernelMachineFinishWitnessJson
import UOToolchain.RuntimeRefinementJson
import UOToolchain.RuntimeShellBoundaryJson
import UOToolchain.RuntimeShellBoundaryLoweringJson
import UOToolchain.RuntimeShellBoundarySlotJson
import UOToolchain.RuntimeTrustedKernelJson
import UOToolchain.RuntimeCoinsJson

namespace UOToolchain

/-!
Proof-grade JSON objects are admitted only through explicit schema entries.
`defaultedMissingFields = []` records the fail-closed policy: every field listed
by an importer must be present in serialized evidence. Optional values must be
serialized as explicit `null`, not omitted.
-/

structure RuntimeProofObjectJsonSchema where
  schemaName : String
  fieldNames : List String
  checker : String
  defaultedMissingFields : List String
  canonicalSerialization : Bool
deriving Repr, DecidableEq

def RuntimeProofObjectJsonSchema.requiresExplicitFields
  (schema : RuntimeProofObjectJsonSchema) : Bool :=
  schema.defaultedMissingFields.isEmpty && schema.canonicalSerialization

def runtimeProofObjectJsonSchemas : List RuntimeProofObjectJsonSchema :=
  [ { schemaName := "public_outcome_trace"
    , fieldNames := importedPublicOutcomeTraceFieldNames
    , checker := "ImportedPublicOutcomeTrace"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_controller_observer_certificate"
    , fieldNames := importedRuntimeControllerObserverCertificateFieldNames
    , checker := "loadAndCheckImportedRuntimeControllerObserverCertificate"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_path_oram_hidden_certificate"
    , fieldNames := importedRuntimePathOramHiddenCertificateFieldNames
    , checker := "loadAndCheckImportedRuntimePathOramHiddenCertificate"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_step"
    , fieldNames := importedRuntimeKernelStepFieldNames
    , checker := "ImportedRuntimeKernelStep"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_schedule"
    , fieldNames := importedRuntimeKernelScheduleFieldNames
    , checker := "ImportedRuntimeKernelSchedule"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_witness"
    , fieldNames := importedRuntimeKernelWitnessFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeKernelWitness"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_refinement_witness"
    , fieldNames := importedRuntimeKernelRefinementWitnessFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeKernelRefinementWitness"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_refinement_witness"
    , fieldNames := importedRuntimeRefinementWitnessFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeRefinementWitness"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_trusted_kernel_slot_bundle"
    , fieldNames := importedRuntimeTrustedKernelSlotBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeTrustedKernelSlotBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_shell_contract"
    , fieldNames := importedRuntimeShellContractFieldNames
    , checker := "ImportedRuntimeShellContract"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_shell_trace"
    , fieldNames := importedRuntimeShellTraceFieldNames
    , checker := "ImportedRuntimeShellTrace"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_shell_boundary_bundle"
    , fieldNames := importedRuntimeShellBoundaryBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeShellBoundaryBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_interface_bundle"
    , fieldNames := importedRuntimeKernelInterfaceBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeKernelInterfaceBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_finish_bundle"
    , fieldNames := importedRuntimeKernelFinishBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeKernelFinishBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_machine_finish_witness"
    , fieldNames := importedRuntimeKernelMachineFinishWitnessFieldNames
    , checker := "loadAndCheckImportedRuntimeKernelMachineFinishWitness"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_kernel_machine_finish_boundary"
    , fieldNames := importedRuntimeKernelMachineFinishBoundaryFieldNames
    , checker := "loadAndCheckImportedRuntimeKernelMachineFinishBoundary"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_confidential_core_slot_bundle"
    , fieldNames := importedRuntimeConfidentialCoreSlotBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeConfidentialCoreSlotBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_confidential_core_lowering_bundle"
    , fieldNames := importedRuntimeConfidentialCoreLoweringBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeConfidentialCoreLoweringBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_confidential_core_kernel_finish_slot_bundle"
    , fieldNames := importedRuntimeConfidentialCoreKernelFinishSlotBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelFinishSlotBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_confidential_core_kernel_interface_slot_bundle"
    , fieldNames := importedRuntimeConfidentialCoreKernelInterfaceSlotBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeRuntimeConfidentialCoreKernelInterfaceSlotBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_seeded_paper_main_family_bundle"
    , fieldNames := importedSeededRuntimePaperMainFamilyBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeSeededRuntimePaperMainFamilyBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_seeded_paper_main_slot_family_bundle"
    , fieldNames := importedSeededRuntimePaperMainSlotFamilyBundleFieldNames
    , checker := "loadAndCheckImportedProofGradeSeededRuntimePaperMainSlotFamilyBundle"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  , { schemaName := "runtime_implementation_interface"
    , fieldNames := importedRuntimeImplementationInterfaceFieldNames
    , checker := "loadAndCheckImportedRuntimeImplementationInterface"
    , defaultedMissingFields := []
    , canonicalSerialization := true
    }
  ]

def runtimeProofObjectJsonSchemaNames : List String :=
  runtimeProofObjectJsonSchemas.map RuntimeProofObjectJsonSchema.schemaName

def runtimeProofObjectJsonSchemaRequireExplicitFields : Bool :=
  runtimeProofObjectJsonSchemas.all
    RuntimeProofObjectJsonSchema.requiresExplicitFields

def runtimeProofObjectSchemaPublicOutcomeIncludesPublicEnv : Bool :=
  importedPublicOutcomeTraceFieldNames.contains "public_env"

theorem runtimeProofObjectJsonSchema_names_nodup :
    runtimeProofObjectJsonSchemaNames.Nodup := by
  native_decide

theorem runtimeProofObjectJsonSchema_no_defaulted_missing_fields :
    runtimeProofObjectJsonSchemaRequireExplicitFields = true := by
  native_decide

theorem runtimeProofObjectSchema_publicOutcome_includes_publicEnv :
    runtimeProofObjectSchemaPublicOutcomeIncludesPublicEnv = true := by
  native_decide

end UOToolchain
