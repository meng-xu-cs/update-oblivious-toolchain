import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreKernelFinishSlotJson
import UOToolchain.RuntimeImplementationInterface
import UOToolchain.RuntimeKernelMachineFinishBoundaryJson
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

def importedRuntimeImplementationInterfaceFieldNames : List String :=
  [ "runtime_evm_lib_source"
  , "engine_source"
  , "runtime_module_source"
  , "fresh_coins_source"
  , "controller_source"
  , "shell_source"
  , "state_source"
  , "kernel_runtime_source"
  , "kernel_slot_support_source"
  , "generated_kernel_machine_source"
  , "generated_object_helpers_source"
  , "generated_oram_codecs_source"
  , "objects_source"
  , "oram_source"
  , "theorem_source"
  , "confidential_kernel_source"
  , "generated_confidential_kernel_source"
  , "trace_source"
  , "confidential_core_source"
  , "trusted_kernel_source"
  , "core_lib_source"
  , "precompiles_source"
  , "allocator_source"
  , "store_lib_source"
  , "store_codec_source"
  , "generated_store_codec_source"
  , "generated_store_surface_source"
  , "generated_store_helpers_source"
  , "store_store_source"
  , "generated_value_ops_source"
  , "types_source"
  ]

def importedRuntimeImplementationSharedConfidentialKernelBoundaryFieldNames : List String :=
  [ "implementation_interface" ]

def importedRuntimeImplementationSmallConfidentialKernelBoundaryFieldNames : List String :=
  [ "implementation_interface" ]

def importedRuntimeImplementationPublicBridgeBoundaryFieldNames : List String :=
  [ "implementation_interface" ]

def importedRuntimeImplementationSlotAdapterBoundaryFieldNames : List String :=
  [ "implementation_interface" ]

def importedRuntimeImplementationSlotAdapterMachineRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

def importedRuntimeImplementationResidualHelperShellBoundaryFieldNames : List String :=
  [ "implementation_interface" ]

def importedRuntimeImplementationPublicBridgeObserverRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

def importedRuntimeImplementationConfidentialStatementTraceBridgeBoundaryFieldNames : List String :=
  [ "implementation_interface" ]

def importedRuntimeImplementationResidualHelperShellMachineRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

def importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

def importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_confidential_core_kernel_finish_slot_bundle"
  ]

def importedRuntimeImplementationKernelMeetingBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "runtime_confidential_core_kernel_finish_slot_bundle"
  ]

def importedRuntimeImplementationKernelMeetingConfinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "runtime_confidential_core_kernel_finish_slot_bundle"
  ]

def importedRuntimeImplementationKernelMachineConfinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

def importedRuntimeImplementationSharedKernelMachineRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_kernel_machine_finish_witness"
  , "confidential_slot_program"
  , "opcode_trace"
  ]

def importedRuntimeImplementationSharedKernelRefinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "runtime_confidential_core_kernel_finish_slot_bundle"
  ]

def importedRuntimeImplementationConfinementBoundaryFieldNames : List String :=
  [ "implementation_interface"
  , "kernel_interface_bundle"
  ]

structure ImportedRuntimeImplementationInterface where
  runtime_evm_lib_source : String
  engine_source : String
  runtime_module_source : String
  fresh_coins_source : String
  controller_source : String
  shell_source : String
  state_source : String
  kernel_runtime_source : String
  kernel_slot_support_source : String
  generated_kernel_machine_source : String
  generated_object_helpers_source : String
  generated_oram_codecs_source : String
  objects_source : String
  oram_source : String
  theorem_source : String
  confidential_kernel_source : String
  generated_confidential_kernel_source : String
  trace_source : String
  confidential_core_source : String
  trusted_kernel_source : String
  core_lib_source : String
  precompiles_source : String
  allocator_source : String
  store_lib_source : String
  store_codec_source : String
  generated_store_codec_source : String
  generated_store_surface_source : String
  generated_store_helpers_source : String
  store_store_source : String
  generated_value_ops_source : String
  types_source : String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationInterface.toRuntimeImplementationInterface
  (iface : ImportedRuntimeImplementationInterface) : RuntimeImplementationInterface :=
  { runtimeEvmLibSource := iface.runtime_evm_lib_source
  , engineSource := iface.engine_source
  , runtimeModuleSource := iface.runtime_module_source
  , freshCoinsSource := iface.fresh_coins_source
  , controllerSource := iface.controller_source
  , shellSource := iface.shell_source
  , stateSource := iface.state_source
  , kernelRuntimeSource := iface.kernel_runtime_source
  , kernelSlotSupportSource := iface.kernel_slot_support_source
  , generatedKernelMachineSource := iface.generated_kernel_machine_source
  , generatedObjectHelpersSource := iface.generated_object_helpers_source
  , generatedOramCodecsSource := iface.generated_oram_codecs_source
  , objectsSource := iface.objects_source
  , oramSource := iface.oram_source
  , theoremSource := iface.theorem_source
  , confidentialKernelSource := iface.confidential_kernel_source
  , generatedConfidentialKernelSource := iface.generated_confidential_kernel_source
  , traceSource := iface.trace_source
  , confidentialCoreSource := iface.confidential_core_source
  , trustedKernelSource := iface.trusted_kernel_source
  , coreLibSource := iface.core_lib_source
  , precompilesSource := iface.precompiles_source
  , allocatorSource := iface.allocator_source
  , storeLibSource := iface.store_lib_source
  , storeCodecSource := iface.store_codec_source
  , generatedStoreCodecSource := iface.generated_store_codec_source
  , generatedStoreSurfaceSource := iface.generated_store_surface_source
  , generatedStoreHelpersSource := iface.generated_store_helpers_source
  , storeStoreSource := iface.store_store_source
  , generatedValueOpsSource := iface.generated_value_ops_source
  , typesSource := iface.types_source
  }

def ImportedRuntimeImplementationInterface.Valid
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.Valid

def ImportedRuntimeImplementationInterface.SharedConfidentialKernelBoundary
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.SharedConfidentialKernelBoundary

def ImportedRuntimeImplementationInterface.SmallConfidentialKernelBoundary
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.SmallConfidentialKernelBoundary

def ImportedRuntimeImplementationInterface.PublicBridgeBoundary
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.PublicBridgeBoundary

def ImportedRuntimeImplementationInterface.SlotAdapterBoundary
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.SlotAdapterBoundary

def ImportedRuntimeImplementationInterface.ResidualHelperShellBoundary
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.ResidualHelperShellBoundary

def ImportedRuntimeImplementationInterface.ConfidentialStatementTraceBridgeBoundary
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.ConfidentialStatementTraceBridgeBoundary

def ImportedRuntimeImplementationInterface.checkValid
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkValid

def ImportedRuntimeImplementationInterface.checkSharedConfidentialKernelBoundary
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkSharedConfidentialKernelBoundary

def ImportedRuntimeImplementationInterface.checkSmallConfidentialKernelBoundary
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkSmallConfidentialKernelBoundary

def ImportedRuntimeImplementationInterface.checkPublicBridgeBoundary
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkPublicBridgeBoundary

def ImportedRuntimeImplementationInterface.checkSlotAdapterBoundary
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkSlotAdapterBoundary

def ImportedRuntimeImplementationInterface.checkResidualHelperShellBoundary
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkResidualHelperShellBoundary

def ImportedRuntimeImplementationInterface.checkConfidentialStatementTraceBridgeBoundary
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkConfidentialStatementTraceBridgeBoundary

@[simp] theorem importedRuntimeImplementationInterface_checkValid_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkValid = true ↔ iface.Valid := by
  unfold ImportedRuntimeImplementationInterface.checkValid
    ImportedRuntimeImplementationInterface.Valid
  simp [runtimeImplementationInterface_checkValid_eq_true_iff]

@[simp] theorem importedRuntimeImplementationInterface_checkSharedConfidentialKernelBoundary_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkSharedConfidentialKernelBoundary = true ↔
    iface.SharedConfidentialKernelBoundary := by
  unfold ImportedRuntimeImplementationInterface.checkSharedConfidentialKernelBoundary
    ImportedRuntimeImplementationInterface.SharedConfidentialKernelBoundary
  simp [runtimeImplementationInterface_checkSharedConfidentialKernelBoundary_eq_true_iff]

@[simp] theorem importedRuntimeImplementationInterface_checkSmallConfidentialKernelBoundary_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkSmallConfidentialKernelBoundary = true ↔
    iface.SmallConfidentialKernelBoundary := by
  unfold ImportedRuntimeImplementationInterface.checkSmallConfidentialKernelBoundary
    ImportedRuntimeImplementationInterface.SmallConfidentialKernelBoundary
  simp [runtimeImplementationInterface_checkSmallConfidentialKernelBoundary_eq_true_iff]

@[simp] theorem importedRuntimeImplementationInterface_checkPublicBridgeBoundary_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkPublicBridgeBoundary = true ↔
    iface.PublicBridgeBoundary := by
  unfold ImportedRuntimeImplementationInterface.checkPublicBridgeBoundary
    ImportedRuntimeImplementationInterface.PublicBridgeBoundary
  simp [runtimeImplementationInterface_checkPublicBridgeBoundary_eq_true_iff]

@[simp] theorem importedRuntimeImplementationInterface_checkSlotAdapterBoundary_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkSlotAdapterBoundary = true ↔
    iface.SlotAdapterBoundary := by
  unfold ImportedRuntimeImplementationInterface.checkSlotAdapterBoundary
    ImportedRuntimeImplementationInterface.SlotAdapterBoundary
  simp [runtimeImplementationInterface_checkSlotAdapterBoundary_eq_true_iff]

@[simp] theorem importedRuntimeImplementationInterface_checkResidualHelperShellBoundary_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkResidualHelperShellBoundary = true ↔
    iface.ResidualHelperShellBoundary := by
  unfold ImportedRuntimeImplementationInterface.checkResidualHelperShellBoundary
    ImportedRuntimeImplementationInterface.ResidualHelperShellBoundary
  simp [runtimeImplementationInterface_checkResidualHelperShellBoundary_eq_true_iff]

@[simp] theorem
  importedRuntimeImplementationInterface_checkConfidentialStatementTraceBridgeBoundary_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkConfidentialStatementTraceBridgeBoundary = true ↔
    iface.ConfidentialStatementTraceBridgeBoundary := by
  unfold ImportedRuntimeImplementationInterface.checkConfidentialStatementTraceBridgeBoundary
    ImportedRuntimeImplementationInterface.ConfidentialStatementTraceBridgeBoundary
  simp [runtimeImplementationInterface_checkConfidentialStatementTraceBridgeBoundary_eq_true_iff]

theorem importedRuntimeImplementationInterface_toRuntimeValid
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.Valid := hValid

theorem importedRuntimeImplementationInterface_toRuntimeSharedConfidentialKernelBoundary
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.SharedConfidentialKernelBoundary) :
  iface.toRuntimeImplementationInterface.SharedConfidentialKernelBoundary := hValid

theorem importedRuntimeImplementationInterface_toRuntimeSmallConfidentialKernelBoundary
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.SmallConfidentialKernelBoundary) :
  iface.toRuntimeImplementationInterface.SmallConfidentialKernelBoundary := hValid

theorem importedRuntimeImplementationInterface_toRuntimePublicBridgeBoundary
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.PublicBridgeBoundary) :
  iface.toRuntimeImplementationInterface.PublicBridgeBoundary := hValid

theorem importedRuntimeImplementationInterface_toRuntimeSlotAdapterBoundary
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.SlotAdapterBoundary) :
  iface.toRuntimeImplementationInterface.SlotAdapterBoundary := hValid

theorem importedRuntimeImplementationInterface_toRuntimeResidualHelperShellBoundary
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.ResidualHelperShellBoundary) :
  iface.toRuntimeImplementationInterface.ResidualHelperShellBoundary := hValid

theorem importedRuntimeImplementationInterface_toRuntimeConfidentialStatementTraceBridgeBoundary
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.ConfidentialStatementTraceBridgeBoundary) :
  iface.toRuntimeImplementationInterface.ConfidentialStatementTraceBridgeBoundary := hValid

theorem importedRuntimeImplementationInterface_valid_handwrittenRuntimePublicOnly
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  let runtimeIface := iface.toRuntimeImplementationInterface
  let hRuntimeValid :
      runtimeIface.Valid :=
    importedRuntimeImplementationInterface_toRuntimeValid iface hValid
  let hShared :
      runtimeIface.SharedConfidentialKernelBoundary :=
    RuntimeImplementationInterface.confinesSecretDependentWork_sharedConfidentialKernelBoundary
      runtimeIface hRuntimeValid
  let hSmall :
      runtimeIface.SmallConfidentialKernelBoundary :=
    RuntimeImplementationInterface.sharedConfidentialKernelBoundary_smallConfidentialKernelBoundary
      runtimeIface hShared
  let hResidual :
      runtimeIface.ResidualHelperShellBoundary :=
    RuntimeImplementationInterface.smallConfidentialKernelBoundary_residualHelperShellBoundary
      runtimeIface hSmall
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_handwrittenRuntimePublicOnly
      runtimeIface hResidual

theorem importedRuntimeImplementationInterface_valid_shellRejectsConfidentialExpressionEvaluation
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.shellRejectsConfidentialExpressionEvaluation := by
  let runtimeIface := iface.toRuntimeImplementationInterface
  let hRuntimeValid :
      runtimeIface.Valid :=
    importedRuntimeImplementationInterface_toRuntimeValid iface hValid
  let hPublic :
      runtimeIface.PublicBridgeBoundary :=
    RuntimeImplementationInterface.confinesSecretDependentWork_publicBridgeBoundary
      runtimeIface hRuntimeValid
  exact
    RuntimeImplementationInterface.publicBridgeBoundary_shellRejectsConfidentialExpressionEvaluation
      runtimeIface hPublic

theorem importedRuntimeImplementationInterface_valid_shellCanonicalHashingGuardedByPublicEntry
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.shellCanonicalHashingGuardedByPublicEntry := by
  let runtimeIface := iface.toRuntimeImplementationInterface
  let hRuntimeValid :
      runtimeIface.Valid :=
    importedRuntimeImplementationInterface_toRuntimeValid iface hValid
  let hPublic :
      runtimeIface.PublicBridgeBoundary :=
    RuntimeImplementationInterface.confinesSecretDependentWork_publicBridgeBoundary
      runtimeIface hRuntimeValid
  exact
    RuntimeImplementationInterface.publicBridgeBoundary_shellCanonicalHashingGuardedByPublicEntry
      runtimeIface hPublic

theorem importedRuntimeImplementationInterface_valid_handwrittenRuntimeLacksDirectSecretOps
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.handwrittenRuntimeLacksDirectSecretOps :=
  RuntimeImplementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers_lacksDirectSecretOps
    iface.toRuntimeImplementationInterface
    (importedRuntimeImplementationInterface_valid_handwrittenRuntimePublicOnly hValid)

theorem importedRuntimeImplementationInterface_valid_hostCoordinationLacksSecretSerialization
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.handwrittenHostCoordinationLacksSecretSerialization :=
  RuntimeImplementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers_hostCoordinationLacksSecretSerialization
    iface.toRuntimeImplementationInterface
    (importedRuntimeImplementationInterface_valid_handwrittenRuntimePublicOnly hValid)

theorem importedRuntimeImplementationInterface_valid_hostVisibleErrorTaxonomy
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  let runtimeIface := iface.toRuntimeImplementationInterface
  let hRuntimeValid :
      runtimeIface.Valid :=
    importedRuntimeImplementationInterface_toRuntimeValid iface hValid
  let hShared :
      runtimeIface.SharedConfidentialKernelBoundary :=
    RuntimeImplementationInterface.confinesSecretDependentWork_sharedConfidentialKernelBoundary
      runtimeIface hRuntimeValid
  let hSmall :
      runtimeIface.SmallConfidentialKernelBoundary :=
    RuntimeImplementationInterface.sharedConfidentialKernelBoundary_smallConfidentialKernelBoundary
      runtimeIface hShared
  let hResidual :
      runtimeIface.ResidualHelperShellBoundary :=
    RuntimeImplementationInterface.smallConfidentialKernelBoundary_residualHelperShellBoundary
      runtimeIface hSmall
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_hostVisibleErrorTaxonomy
      runtimeIface hResidual

structure ImportedRuntimeImplementationSmallConfidentialKernelBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationSmallConfidentialKernelBoundary.Valid
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary) : Prop :=
  boundary.implementation_interface.SmallConfidentialKernelBoundary

def ImportedRuntimeImplementationSmallConfidentialKernelBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary) : Bool :=
  boundary.implementation_interface.checkSmallConfidentialKernelBoundary

def ImportedRuntimeImplementationSmallConfidentialKernelBoundary.toRuntimeImplementationSmallConfidentialKernelBoundary
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSmallConfidentialKernelBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , smallBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSmallConfidentialKernelBoundary
        boundary.implementation_interface hValid
  }

@[simp] theorem importedRuntimeImplementationSmallConfidentialKernelBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSmallConfidentialKernelBoundary.checkValid
    ImportedRuntimeImplementationSmallConfidentialKernelBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkSmallConfidentialKernelBoundary_eq_true_iff]

theorem importedRuntimeImplementationSmallConfidentialKernelBoundary_toRuntimeSmallKernelConfinement
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SmallConfidentialKernelBoundary
    (boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationSmallConfidentialKernelBoundary.smallKernelConfinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationSmallConfidentialKernelBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationSmallConfidentialKernelBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationSmallConfidentialKernelBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSmallConfidentialKernelBoundary_valid_hostVisibleErrorTaxonomy
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    RuntimeImplementationSmallConfidentialKernelBoundary.hostVisibleErrorTaxonomy
      (boundary.toRuntimeImplementationSmallConfidentialKernelBoundary hValid)

structure ImportedRuntimeImplementationPublicBridgeBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationPublicBridgeBoundary.Valid
  (boundary : ImportedRuntimeImplementationPublicBridgeBoundary) : Prop :=
  boundary.implementation_interface.PublicBridgeBoundary

def ImportedRuntimeImplementationPublicBridgeBoundary.checkValid
  (boundary : ImportedRuntimeImplementationPublicBridgeBoundary) : Bool :=
  boundary.implementation_interface.checkPublicBridgeBoundary

def ImportedRuntimeImplementationPublicBridgeBoundary.toRuntimeImplementationPublicBridgeBoundary
  (boundary : ImportedRuntimeImplementationPublicBridgeBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationPublicBridgeBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , publicBridgeValid := by
      exact importedRuntimeImplementationInterface_toRuntimePublicBridgeBoundary
        boundary.implementation_interface hValid
  }

@[simp] theorem importedRuntimeImplementationPublicBridgeBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationPublicBridgeBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationPublicBridgeBoundary.checkValid
    ImportedRuntimeImplementationPublicBridgeBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkPublicBridgeBoundary_eq_true_iff]

theorem importedRuntimeImplementationPublicBridgeBoundary_toRuntimePublicBridgeConfinement
  (boundary : ImportedRuntimeImplementationPublicBridgeBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.PublicBridgeBoundary
    (boundary.toRuntimeImplementationPublicBridgeBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationPublicBridgeBoundary.publicBridgeConfinement
      (boundary.toRuntimeImplementationPublicBridgeBoundary hValid)

theorem importedRuntimeImplementationPublicBridgeBoundary_valid_publicBridgeConfinement
  {boundary : ImportedRuntimeImplementationPublicBridgeBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary := by
  exact
    importedRuntimeImplementationPublicBridgeBoundary_toRuntimePublicBridgeConfinement
      boundary hValid

structure ImportedRuntimeImplementationSlotAdapterBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationSlotAdapterBoundary.Valid
  (boundary : ImportedRuntimeImplementationSlotAdapterBoundary) : Prop :=
  boundary.implementation_interface.SlotAdapterBoundary

def ImportedRuntimeImplementationSlotAdapterBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSlotAdapterBoundary) : Bool :=
  boundary.implementation_interface.checkSlotAdapterBoundary

def ImportedRuntimeImplementationSlotAdapterBoundary.toRuntimeImplementationSlotAdapterBoundary
  (boundary : ImportedRuntimeImplementationSlotAdapterBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSlotAdapterBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , slotAdapterValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSlotAdapterBoundary
        boundary.implementation_interface hValid
  }

@[simp] theorem importedRuntimeImplementationSlotAdapterBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSlotAdapterBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSlotAdapterBoundary.checkValid
    ImportedRuntimeImplementationSlotAdapterBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkSlotAdapterBoundary_eq_true_iff]

theorem importedRuntimeImplementationSlotAdapterBoundary_toRuntimeSlotAdapterConfinement
  (boundary : ImportedRuntimeImplementationSlotAdapterBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SlotAdapterBoundary
    (boundary.toRuntimeImplementationSlotAdapterBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationSlotAdapterBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSlotAdapterBoundary hValid)

structure ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness :=
      boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary) :
  Prop :=
  boundary.implementation_interface.PublicBridgeBoundary ∧
    boundary.implementation_interface.ResidualHelperShellBoundary ∧
    boundary.projectedKernelMachineFinishBoundary.Valid

def ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary) :
  Bool :=
  boundary.implementation_interface.checkPublicBridgeBoundary &&
    boundary.implementation_interface.checkResidualHelperShellBoundary &&
    boundary.projectedKernelMachineFinishBoundary.checkValid

@[simp] theorem
  importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.checkValid
    ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.Valid
    ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkPublicBridgeBoundary_eq_true_iff,
    importedRuntimeImplementationInterface_checkResidualHelperShellBoundary_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff, and_assoc]

noncomputable def
  ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary
  (boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationPublicBridgeObserverRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelMachineFinishBoundary :=
      boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2.2
  , publicBridgeValid := by
      exact importedRuntimeImplementationInterface_toRuntimePublicBridgeBoundary
        boundary.implementation_interface hValid.1
  , residualBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeResidualHelperShellBoundary
        boundary.implementation_interface hValid.2.1
  }

theorem
  importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_publicBridgeConfinement
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary := by
  exact
    RuntimeImplementationPublicBridgeObserverRefinementBoundary.publicBridgeConfinement
      (boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid)

theorem
  importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationPublicBridgeObserverRefinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid)

theorem
  importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationPublicBridgeObserverRefinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid)

theorem
  importedRuntimeImplementationPublicBridgeObserverRefinementBoundary_valid_paper_public_bridge_observer_refinement
  {boundary : ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationPublicBridgeObserverRefinementBoundary.paperPublicBridgeObserverRefinement
      (boundary.toRuntimeImplementationPublicBridgeObserverRefinementBoundary hValid)

structure ImportedRuntimeImplementationResidualHelperShellBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationResidualHelperShellBoundary.Valid
  (boundary : ImportedRuntimeImplementationResidualHelperShellBoundary) : Prop :=
  boundary.implementation_interface.ResidualHelperShellBoundary

def ImportedRuntimeImplementationResidualHelperShellBoundary.checkValid
  (boundary : ImportedRuntimeImplementationResidualHelperShellBoundary) : Bool :=
  boundary.implementation_interface.checkResidualHelperShellBoundary

def ImportedRuntimeImplementationResidualHelperShellBoundary.toRuntimeImplementationResidualHelperShellBoundary
  (boundary : ImportedRuntimeImplementationResidualHelperShellBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationResidualHelperShellBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , residualBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeResidualHelperShellBoundary
        boundary.implementation_interface hValid
  }

@[simp] theorem importedRuntimeImplementationResidualHelperShellBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationResidualHelperShellBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationResidualHelperShellBoundary.checkValid
    ImportedRuntimeImplementationResidualHelperShellBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkResidualHelperShellBoundary_eq_true_iff]

theorem importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
  (boundary : ImportedRuntimeImplementationResidualHelperShellBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ResidualHelperShellBoundary
    (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_hostVisibleErrorTaxonomy
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.hostVisibleErrorTaxonomy
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedObjectHelpersMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedObjectHelpersMatchLeanGenerator := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.generatedObjectHelpersMatchLeanGenerator
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedOramCodecsMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedOramCodecsMatchLeanGenerator := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.generatedOramCodecsMatchLeanGenerator
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedStoreCodecMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedStoreCodecMatchLeanGenerator := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.generatedStoreCodecMatchLeanGenerator
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedStoreSurfaceMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedStoreSurfaceMatchLeanGenerator := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.generatedStoreSurfaceMatchLeanGenerator
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

theorem importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedStoreHelpersMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedStoreHelpersMatchLeanGenerator := by
  exact
    RuntimeImplementationResidualHelperShellBoundary.generatedStoreHelpersMatchLeanGenerator
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid)

structure ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness :=
      boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary) :
  Prop :=
  boundary.implementation_interface.ResidualHelperShellBoundary ∧
    boundary.projectedKernelMachineFinishBoundary.Valid

def ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary) :
  Bool :=
  boundary.implementation_interface.checkResidualHelperShellBoundary &&
    boundary.projectedKernelMachineFinishBoundary.checkValid

@[simp] theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.checkValid
    ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.Valid
    ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkResidualHelperShellBoundary_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary
  (boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationResidualHelperShellMachineRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelMachineFinishBoundary :=
      boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2
  , residualBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeResidualHelperShellBoundary
        boundary.implementation_interface hValid.1
  }

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_toRuntimeResidualHelperShellConfinement
  (boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ResidualHelperShellBoundary
    (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary
      hValid).implementationInterface := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_machine_finish_schedule_consumed
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.machineFinishScheduleConsumed
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.machineFinishKernelStepBudgetRespected
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.machineFinishRuntimePhaseBudgetRespected
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_slot_semantics_exact
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.slotSemanticsExact
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_native_machine_refinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.nativeMachineRefinement
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationResidualHelperShellMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationResidualHelperShellMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement
      (boundary.toRuntimeImplementationResidualHelperShellMachineRefinementBoundary hValid)

structure ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary.Valid
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary) : Prop :=
  boundary.implementation_interface.ConfidentialStatementTraceBridgeBoundary

def ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary.checkValid
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary) : Bool :=
  boundary.implementation_interface.checkConfidentialStatementTraceBridgeBoundary

def ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary.toRuntimeImplementationConfidentialStatementTraceBridgeBoundary
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationConfidentialStatementTraceBridgeBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , bridgeBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeConfidentialStatementTraceBridgeBoundary
        boundary.implementation_interface hValid
  }

@[simp] theorem
  importedRuntimeImplementationConfidentialStatementTraceBridgeBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary.checkValid
    ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkConfidentialStatementTraceBridgeBoundary_eq_true_iff]

theorem importedRuntimeImplementationConfidentialStatementTraceBridgeBoundary_toRuntimeBridgeConfinement
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ConfidentialStatementTraceBridgeBoundary
    (boundary.toRuntimeImplementationConfidentialStatementTraceBridgeBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationConfidentialStatementTraceBridgeBoundary.bridgeConfinement
      (boundary.toRuntimeImplementationConfidentialStatementTraceBridgeBoundary hValid)

theorem importedRuntimeImplementationConfidentialStatementTraceBridgeBoundary_valid_bridgeConfinement
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeBoundary hValid
  runtimeBoundary.implementationInterface.ConfidentialStatementTraceBridgeBoundary := by
  exact
    importedRuntimeImplementationConfidentialStatementTraceBridgeBoundary_toRuntimeBridgeConfinement
      boundary hValid

structure ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness :=
      boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary) :
  Prop :=
  boundary.implementation_interface.SmallConfidentialKernelBoundary ∧
    boundary.projectedKernelMachineFinishBoundary.Valid

def ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary) :
  Bool :=
  boundary.implementation_interface.checkSmallConfidentialKernelBoundary &&
    boundary.projectedKernelMachineFinishBoundary.checkValid

@[simp] theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.checkValid
    ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.Valid
    ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkSmallConfidentialKernelBoundary_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelMachineFinishBoundary :=
      boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2
  , smallBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSmallConfidentialKernelBoundary
        boundary.implementation_interface hValid.1
  }

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_toRuntimeSmallKernelConfinement
  (boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SmallConfidentialKernelBoundary
    (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
      hValid).implementationInterface := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.smallKernelConfinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_machine_finish_schedule_consumed
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.machineFinishScheduleConsumed
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.machineFinishKernelStepBudgetRespected
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.machineFinishRuntimePhaseBudgetRespected
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_slot_semantics_exact
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.slotSemanticsExact
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_native_machine_refinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.nativeMachineRefinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paper_slot_adapter_machine_refinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSlotAdapterMachineRefinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineRefinementWithPublicOnlyHandwrittenShell
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary_valid_paperSmallKernelMachineObserverRefinement
  {boundary : ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary.paperSmallKernelMachineObserverRefinement
      (boundary.toRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary hValid)

structure ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness :=
      boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary) :
  Prop :=
  boundary.implementation_interface.SlotAdapterBoundary ∧
    boundary.projectedKernelMachineFinishBoundary.Valid

def ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary) :
  Bool :=
  boundary.implementation_interface.checkSlotAdapterBoundary &&
    boundary.projectedKernelMachineFinishBoundary.checkValid

@[simp] theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.checkValid
    ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.Valid
    ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkSlotAdapterBoundary_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary
  (boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSlotAdapterMachineRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelMachineFinishBoundary :=
      boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2
  , slotAdapterValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSlotAdapterBoundary
        boundary.implementation_interface hValid.1
  }

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_toRuntimeSlotAdapterConfinement
  (boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SlotAdapterBoundary
    (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary
      hValid).implementationInterface := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_machine_finish_schedule_consumed
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.machineFinishScheduleConsumed
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.machineFinishKernelStepBudgetRespected
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.machineFinishRuntimePhaseBudgetRespected
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_slot_semantics_exact
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.slotSemanticsExact
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_native_machine_refinement
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.nativeMachineRefinement
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSlotAdapterMachineRefinementBoundary_valid_paper_slot_adapter_machine_refinement
  {boundary : ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSlotAdapterMachineRefinementBoundary.paperSlotAdapterMachineRefinement
      (boundary.toRuntimeImplementationSlotAdapterMachineRefinementBoundary hValid)

structure ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_confidential_core_kernel_finish_slot_bundle :
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle
deriving FromJson

def ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary) :
  Prop :=
  boundary.implementation_interface.ConfidentialStatementTraceBridgeBoundary ∧
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.Valid

def ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary) :
  Bool :=
  boundary.implementation_interface.checkConfidentialStatementTraceBridgeBoundary &&
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.checkValid

@[simp] theorem
  importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.checkValid
    ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkConfidentialStatementTraceBridgeBoundary_eq_true_iff,
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelFinishSlotBoundary :=
      boundary.runtime_confidential_core_kernel_finish_slot_bundle.toRuntimeKernelFinishSlotBoundary
        hValid.2
  , bridgeBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeConfidentialStatementTraceBridgeBoundary
        boundary.implementation_interface hValid.1
  }

theorem
  importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_toRuntimeBridgeConfinement
  (boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ConfidentialStatementTraceBridgeBoundary
    (boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
      hValid).implementationInterface := by
  exact
    RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.bridgeConfinement
      (boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid)

theorem
  importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid)

theorem
  importedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid
  let confinementBoundary := runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary hValid)

structure ImportedRuntimeImplementationKernelMeetingBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  runtime_confidential_core_kernel_finish_slot_bundle :
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle
deriving FromJson

def ImportedRuntimeImplementationKernelMeetingBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationKernelMeetingBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness := boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program :=
      boundary.runtime_confidential_core_kernel_finish_slot_bundle.confidential_slot_program
  , opcode_trace := boundary.runtime_confidential_core_kernel_finish_slot_bundle.opcode_trace
  }

def ImportedRuntimeImplementationKernelMeetingBoundary.Valid
  (boundary : ImportedRuntimeImplementationKernelMeetingBoundary) : Prop :=
  boundary.implementation_interface.SmallConfidentialKernelBoundary ∧
    boundary.implementation_interface.ConfidentialStatementTraceBridgeBoundary ∧
    boundary.projectedKernelMachineFinishBoundary.Valid ∧
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.Valid ∧
    boundary.runtime_kernel_machine_finish_witness.projectedFinishBundle =
      boundary.runtime_confidential_core_kernel_finish_slot_bundle.runtime_kernel_finish_bundle

def ImportedRuntimeImplementationKernelMeetingBoundary.checkValid
  (boundary : ImportedRuntimeImplementationKernelMeetingBoundary) : Bool :=
  boundary.implementation_interface.checkSmallConfidentialKernelBoundary &&
    boundary.implementation_interface.checkConfidentialStatementTraceBridgeBoundary &&
    boundary.projectedKernelMachineFinishBoundary.checkValid &&
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.checkValid &&
    decide
      (boundary.runtime_kernel_machine_finish_witness.projectedFinishBundle =
        boundary.runtime_confidential_core_kernel_finish_slot_bundle.runtime_kernel_finish_bundle)

@[simp] theorem
  importedRuntimeImplementationKernelMeetingBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationKernelMeetingBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationKernelMeetingBoundary.checkValid
    ImportedRuntimeImplementationKernelMeetingBoundary.Valid
    ImportedRuntimeImplementationKernelMeetingBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkSmallConfidentialKernelBoundary_eq_true_iff,
    importedRuntimeImplementationInterface_checkConfidentialStatementTraceBridgeBoundary_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff,
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff,
    decide_eq_true_eq, and_assoc]

noncomputable def ImportedRuntimeImplementationKernelMeetingBoundary.toRuntimeImplementationKernelMeetingBoundary
  (boundary : ImportedRuntimeImplementationKernelMeetingBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationKernelMeetingBoundary := by
  let runtimeKernelMachineFinishBoundary :=
    boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2.2.1
  let runtimeKernelFinishSlotBoundary :=
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.toRuntimeKernelFinishSlotBoundary
      hValid.2.2.2.1
  let projectedKernelFinishSlotBundle :=
    boundary.projectedKernelMachineFinishBoundary.projectedKernelFinishSlotBundle
  have hFinishBundleEq :
      boundary.runtime_kernel_machine_finish_witness.projectedFinishBundle =
        boundary.runtime_confidential_core_kernel_finish_slot_bundle.runtime_kernel_finish_bundle :=
    hValid.2.2.2.2
  have hProjectedBundles :
      projectedKernelFinishSlotBundle =
        boundary.runtime_confidential_core_kernel_finish_slot_bundle := by
    apply importedRuntimeConfidentialCoreKernelFinishSlotBundle_eq_of_fields_eq
    · simpa [projectedKernelFinishSlotBundle,
        ImportedRuntimeImplementationKernelMeetingBoundary.projectedKernelMachineFinishBoundary,
        ImportedRuntimeKernelMachineFinishBoundary.projectedKernelFinishSlotBundle] using hFinishBundleEq
    · rfl
    · rfl
  have hFinishSlotBoundaryEq :
      runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary =
        runtimeKernelFinishSlotBoundary := by
    have hMachineFinishSlotBoundaryExact :
        runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary =
          projectedKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary hValid.2.2.1.2 := by
      simpa [runtimeKernelMachineFinishBoundary] using
        importedRuntimeKernelMachineFinishBoundary_toRuntimeKernelMachineFinishBoundary_runtimeKernelFinishSlotBoundary_exact
          (boundary := boundary.projectedKernelMachineFinishBoundary)
          (hValid := hValid.2.2.1)
    have hProjectedFinishSlotBoundaryEq :
        projectedKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary hValid.2.2.1.2 =
          boundary.runtime_confidential_core_kernel_finish_slot_bundle.toRuntimeKernelFinishSlotBoundary
            hValid.2.2.2.1 := by
      exact
        importedRuntimeConfidentialCoreKernelFinishSlotBundle_toRuntimeKernelFinishSlotBoundary_congr
          hProjectedBundles
    calc
      runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary
          = projectedKernelFinishSlotBundle.toRuntimeKernelFinishSlotBoundary hValid.2.2.1.2 :=
        hMachineFinishSlotBoundaryExact
      _ =
            boundary.runtime_confidential_core_kernel_finish_slot_bundle.toRuntimeKernelFinishSlotBoundary
              hValid.2.2.2.1 :=
        hProjectedFinishSlotBoundaryEq
  exact
    { implementationInterface := boundary.implementation_interface.toRuntimeImplementationInterface
    , runtimeKernelMachineFinishBoundary := runtimeKernelMachineFinishBoundary
    , runtimeKernelFinishSlotBoundary := runtimeKernelFinishSlotBoundary
    , smallBoundaryValid := by
        exact importedRuntimeImplementationInterface_toRuntimeSmallConfidentialKernelBoundary
          boundary.implementation_interface hValid.1
    , bridgeBoundaryValid := by
        exact importedRuntimeImplementationInterface_toRuntimeConfidentialStatementTraceBridgeBoundary
          boundary.implementation_interface hValid.2.1
    , machineBoundaryMatchesFinishSlotBoundary := hFinishSlotBoundaryEq
    }

theorem importedRuntimeImplementationKernelMeetingBoundary_toRuntimeSharedKernelConfinement
  (boundary : ImportedRuntimeImplementationKernelMeetingBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SharedConfidentialKernelBoundary
    (boundary.toRuntimeImplementationKernelMeetingBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationKernelMeetingBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_smallKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    RuntimeImplementationKernelMeetingBoundary.smallKernelConfinement
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_bridgeConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.ConfidentialStatementTraceBridgeBoundary := by
  exact
    RuntimeImplementationKernelMeetingBoundary.bridgeConfinement
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationKernelMeetingBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationKernelMeetingBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationKernelMeetingBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationKernelMeetingBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

theorem importedRuntimeImplementationKernelMeetingBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationKernelMeetingBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMeetingBoundary hValid
  let confinementBoundary := runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationKernelMeetingBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationKernelMeetingBoundary hValid)

structure ImportedRuntimeImplementationKernelMeetingConfinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  runtime_confidential_core_kernel_finish_slot_bundle :
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle
deriving FromJson

def ImportedRuntimeImplementationKernelMeetingConfinementBoundary.projectedKernelMeetingBoundary
  (boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary) :
  ImportedRuntimeImplementationKernelMeetingBoundary :=
  { implementation_interface := boundary.implementation_interface
  , runtime_kernel_machine_finish_witness := boundary.runtime_kernel_machine_finish_witness
  , runtime_confidential_core_kernel_finish_slot_bundle :=
      boundary.runtime_confidential_core_kernel_finish_slot_bundle
  }

def ImportedRuntimeImplementationKernelMeetingConfinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary) : Prop :=
  boundary.implementation_interface.Valid ∧
    boundary.projectedKernelMeetingBoundary.Valid

def ImportedRuntimeImplementationKernelMeetingConfinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary) : Bool :=
  boundary.implementation_interface.checkValid &&
    boundary.projectedKernelMeetingBoundary.checkValid

@[simp] theorem importedRuntimeImplementationKernelMeetingConfinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationKernelMeetingConfinementBoundary.checkValid
    ImportedRuntimeImplementationKernelMeetingConfinementBoundary.Valid
    ImportedRuntimeImplementationKernelMeetingConfinementBoundary.projectedKernelMeetingBoundary
  simp [importedRuntimeImplementationInterface_checkValid_eq_true_iff,
    importedRuntimeImplementationKernelMeetingBoundary_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationKernelMeetingConfinementBoundary.toRuntimeImplementationConfinementBoundary
  (boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationConfinementBoundary := by
  let runtimeMeetingBoundary :=
    boundary.projectedKernelMeetingBoundary.toRuntimeImplementationKernelMeetingBoundary hValid.2
  exact
    runtimeMeetingBoundary.runtimeImplementationConfinementBoundary
      (importedRuntimeImplementationInterface_toRuntimeValid
        boundary.implementation_interface hValid.1).1

theorem importedRuntimeImplementationKernelMeetingConfinementBoundary_toRuntimeImplementationConfinement
  (boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ConfinesSecretDependentWork
    (boundary.toRuntimeImplementationConfinementBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationConfinementBoundary.implementationConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_sharedKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_smallKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.smallKernelConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationConfinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_paperEndToEndConfinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  let runtimeMeetingBoundary :=
    boundary.projectedKernelMeetingBoundary.toRuntimeImplementationKernelMeetingBoundary hValid.2
  let hPublicBridge :
      runtimeMeetingBoundary.implementationInterface.PublicBridgeBoundary := by
    exact
      RuntimeImplementationInterface.confinesSecretDependentWork_publicBridgeBoundary
        runtimeMeetingBoundary.implementationInterface
        (importedRuntimeImplementationInterface_toRuntimeValid
          boundary.implementation_interface hValid.1)
  exact
    RuntimeImplementationKernelMeetingBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell
      runtimeMeetingBoundary hPublicBridge

theorem
  importedRuntimeImplementationKernelMeetingConfinementBoundary_valid_paperPublicBridgeObserverRefinement
  {boundary : ImportedRuntimeImplementationKernelMeetingConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  let runtimeMeetingBoundary :=
    boundary.projectedKernelMeetingBoundary.toRuntimeImplementationKernelMeetingBoundary hValid.2
  let hPublicBridge :
      runtimeMeetingBoundary.implementationInterface.PublicBridgeBoundary := by
    exact
      RuntimeImplementationInterface.confinesSecretDependentWork_publicBridgeBoundary
        runtimeMeetingBoundary.implementationInterface
        (importedRuntimeImplementationInterface_toRuntimeValid
          boundary.implementation_interface hValid.1)
  exact
    RuntimeImplementationKernelMeetingBoundary.paperPublicBridgeObserverRefinement
      runtimeMeetingBoundary hPublicBridge

structure ImportedRuntimeImplementationKernelMachineConfinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeImplementationKernelMachineConfinementBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness :=
      boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeImplementationKernelMachineConfinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary) : Prop :=
  boundary.implementation_interface.Valid ∧
    boundary.projectedKernelMachineFinishBoundary.Valid

def ImportedRuntimeImplementationKernelMachineConfinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary) : Bool :=
  boundary.implementation_interface.checkValid &&
    boundary.projectedKernelMachineFinishBoundary.checkValid

@[simp] theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationKernelMachineConfinementBoundary.checkValid
    ImportedRuntimeImplementationKernelMachineConfinementBoundary.Valid
    ImportedRuntimeImplementationKernelMachineConfinementBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkValid_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationKernelMachineConfinementBoundary.toRuntimeImplementationKernelMachineConfinementBoundary
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationKernelMachineConfinementBoundary :=
  { implementationInterface := boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelMachineFinishBoundary :=
      boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2
  , implementationValid := by
      exact importedRuntimeImplementationInterface_toRuntimeValid
        boundary.implementation_interface hValid.1
  }

noncomputable def
  ImportedRuntimeImplementationKernelMachineConfinementBoundary.toRuntimeImplementationConfinementBoundary
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationConfinementBoundary :=
  (boundary.toRuntimeImplementationKernelMachineConfinementBoundary
    hValid).runtimeImplementationConfinementBoundary

noncomputable def
  ImportedRuntimeImplementationKernelMachineConfinementBoundary.toRuntimePaperNativeKernelAssumptions
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimePaperNativeKernelAssumptions :=
  (boundary.toRuntimeImplementationKernelMachineConfinementBoundary
    hValid).toRuntimePaperNativeKernelAssumptions

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_toRuntimeImplementationConfinement
  (boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ConfinesSecretDependentWork
    (boundary.toRuntimeImplementationConfinementBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationConfinementBoundary.implementationConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_sharedKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_smallKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.smallKernelConfinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_publicBridgeConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.publicBridgeConfinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_machine_finish_schedule_consumed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.machineFinishScheduleConsumed
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_machine_finish_kernel_step_budget_respected
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.machineFinishKernelStepBudgetRespected
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_machine_finish_runtime_phase_budget_respected
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.machineFinishRuntimePhaseBudgetRespected
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_slot_semantics_exact
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.slotSemanticsExact
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pinsNativeMachineSemantics
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
    | some steps =>
        runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
    | none =>
        runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.pinsNativeMachineSemantics
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_assumptions
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.ConfinesSecretDependentWork ∧
    assumptions.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => assumptions.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => assumptions.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      assumptions.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      assumptions.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimePaperNativeKernelAssumptions.paperEndToEndConfinementWithPublicOnlyHandwrittenShell
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_state_refinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimePaperNativeKernelAssumptions.kernelStateRefinesLeanKernel
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_shell_trace_refinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimePaperNativeKernelAssumptions.shellTraceRefinesShellContract
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeTraceUsesExactBoxedBacking
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.runtimeStoreUsesGeneratedRawBoxedSlotHelpers := by
  exact
    RuntimePaperNativeKernelAssumptions.storeTraceUsesExactBoxedBacking
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_generatedValueOpsMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.generatedValueOpsMatchLeanGenerator := by
  exact
    RuntimePaperNativeKernelAssumptions.generatedValueOpsMatchLeanGenerator
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsScalarCanonicalLengthsPublic
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeValueOpsSemantics.boolCanonicalBytes = 1 ∧
    RuntimeValueOpsSemantics.uintCanonicalBytes = 32 ∧
    RuntimeValueOpsSemantics.bytes32CanonicalBytes = 32 ∧
    RuntimeValueOpsSemantics.addressCanonicalBytes = 20 ∧
    RuntimeValueOpsSemantics.canonicalLengthPrefixBytes = 8 := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsScalarCanonicalLengthsPublic
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsU128CanonicalByteFieldLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : Nat) :
  (RuntimeValueOpsSemantics.u128CanonicalByteField value).length =
    RuntimeValueOpsSemantics.uintCanonicalBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsU128CanonicalByteFieldLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsU128CanonicalByteFieldHighPrefixZero
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : Nat) :
  (RuntimeValueOpsSemantics.u128CanonicalByteField value).take
      RuntimeValueOpsSemantics.u128HighZeroBytes =
    List.replicate RuntimeValueOpsSemantics.u128HighZeroBytes 0 := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsU128CanonicalByteFieldHighPrefixZero
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsU128CanonicalByteFieldValidBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : Nat) :
  RuntimeValueOpsSemantics.ValidByteField
    (RuntimeValueOpsSemantics.u128CanonicalByteField value) := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsU128CanonicalByteFieldValidBytes
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsMaskedSelectBoolTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeValueOpsSemantics.maskedSelectBool true whenTrue whenFalse = whenTrue := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsMaskedSelectBoolTrue
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsMaskedSelectBoolFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeValueOpsSemantics.maskedSelectBool false whenTrue whenFalse = whenFalse := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsMaskedSelectBoolFalse
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsMaskedSelectBytesLengthOfEqual
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {cond : Bool}
  {whenTrue whenFalse : List Nat}
  (hLen : whenTrue.length = whenFalse.length) :
  (RuntimeValueOpsSemantics.maskedSelectBytes cond whenTrue whenFalse).length =
    whenTrue.length := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsMaskedSelectBytesLengthOfEqual
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferExtendPreservesCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state next : RuntimeValueOpsSemantics.FixedByteBufferState}
  {chunk : List Nat}
  (hExtend : state.extend? chunk = some next) :
  next.capacity = state.capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsFixedBufferExtendPreservesCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hExtend

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferExtendIncrementsInitialized
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state next : RuntimeValueOpsSemantics.FixedByteBufferState}
  {chunk : List Nat}
  (hExtend : state.extend? chunk = some next) :
  next.initialized = state.initialized + chunk.length := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsFixedBufferExtendIncrementsInitialized
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hExtend

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferExtendRejectsOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state : RuntimeValueOpsSemantics.FixedByteBufferState}
  {chunk : List Nat}
  (hOverflow : state.capacity < state.initialized + chunk.length) :
  state.extend? chunk = none := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsFixedBufferExtendRejectsOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOverflow

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferFinishExactlyFilled
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state : RuntimeValueOpsSemantics.FixedByteBufferState}
  {capacity : Nat}
  (hFinish : state.finish? = some capacity) :
  state.initialized = state.capacity ∧ capacity = state.capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.valueOpsFixedBufferFinishExactlyFilled
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hFinish

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceZeroedBytesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (len : Nat) :
  (RuntimeStoreCodecSemantics.zeroedBytes len).length = len := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceZeroedBytesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) len

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceZeroedBytesValid
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (len : Nat) :
  ∀ byte,
    byte ∈ RuntimeStoreCodecSemantics.zeroedBytes len →
      RuntimeStoreCodecSemantics.ValidByte byte := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceZeroedBytesValid
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) len

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceReadExactRangeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes out : List Nat}
  {start len : Nat}
  (hRead :
    RuntimeStoreCodecSemantics.readExactRange? bytes start len =
      some out) :
  out.length = len := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceReadExactRangeLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hRead

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceReadExactRangeRejectsOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {start len : Nat}
  (hRange : ¬ start + len ≤ bytes.length) :
  RuntimeStoreCodecSemantics.readExactRange? bytes start len = none := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceReadExactRangeRejectsOutOfRange
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hRange

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceCopyExactIntoShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {out input copied : List Nat}
  (hCopy :
    RuntimeStoreCodecSemantics.copyExactInto? out input =
      some copied) :
  copied = input ∧ copied.length = out.length := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceCopyExactIntoShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hCopy

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceCopyExactIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {out input : List Nat}
  (hLen : out.length ≠ input.length) :
  RuntimeStoreCodecSemantics.copyExactInto? out input = none := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceCopyExactIntoRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceSealIntoAcceptsExactLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealAndWipeIntoSliceAccepted payloadLen
    (RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceSealIntoAcceptsExactLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) payloadLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceSealIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen outLen : Nat}
  (hLen :
    outLen ≠ RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  ¬ RuntimeStoreCodecSemantics.sealAndWipeIntoSliceAccepted
      payloadLen outLen := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceSealIntoRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceOpenPayloadShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded =
      some parts) :
  RuntimeStoreCodecSemantics.openBoxedPayloadShape? payloadLen encoded =
    some payloadLen := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceOpenPayloadShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceWipePreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bytes : List Nat) :
  (RuntimeStoreCodecSemantics.wipeBytes bytes).length = bytes.length := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceWipePreservesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) bytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceWipeZeros
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {byte : Nat}
  (hMem : byte ∈ RuntimeStoreCodecSemantics.wipeBytes bytes) :
  byte = 0 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSurfaceWipeZeros
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) hMem

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes : ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeNonzero
      (RuntimeStoreCodecSemantics.encodeNonzero bytes) = some bytes := by
  exact
    RuntimePaperNativeKernelAssumptions.storeCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecTransportShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes : ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  (RuntimeStoreCodecSemantics.encodeNonzero bytes).length = 2 * bytes.length ∧
    ∀ nibble,
      nibble ∈ RuntimeStoreCodecSemantics.encodeNonzero bytes →
        RuntimeStoreCodecSemantics.ValidEncodedNibble nibble := by
  exact
    RuntimePaperNativeKernelAssumptions.storeCodecTransportShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeSound
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {encoded bytes : List Nat}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeNonzero encoded = some bytes) :
  encoded.length = 2 * bytes.length ∧
    (∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) ∧
    (∀ nibble,
      nibble ∈ encoded →
        RuntimeStoreCodecSemantics.ValidEncodedNibble nibble) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeCodecDecodeSound
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeIntoRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes : ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeNonzeroInto?
      bytes.length (RuntimeStoreCodecSemantics.encodeNonzero bytes) =
    some bytes := by
  exact
    RuntimePaperNativeKernelAssumptions.storeCodecDecodeIntoRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {byteLen : Nat}
  {encoded : List Nat}
  (hLen : encoded.length ≠ 2 * byteLen) :
  RuntimeStoreCodecSemantics.decodeNonzeroInto? byteLen encoded = none := by
  exact
    RuntimePaperNativeKernelAssumptions.storeCodecDecodeIntoRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeIntoSound
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {byteLen : Nat}
  {encoded bytes : List Nat}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeNonzeroInto? byteLen encoded =
      some bytes) :
  encoded.length = 2 * byteLen ∧
    bytes.length = byteLen ∧
    (∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) ∧
    (∀ nibble,
      nibble ∈ encoded →
        RuntimeStoreCodecSemantics.ValidEncodedNibble nibble) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeCodecDecodeIntoSound
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedEncodedLen
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen =
    2 * (RuntimeStoreCodecSemantics.sealedMagicLen +
      RuntimeStoreCodecSemantics.sealedNonceBytes +
      payloadLen +
      RuntimeStoreCodecSemantics.sealedTagBytes) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedEncodedLen
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      payloadLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedPlainLen
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealedPlainLen payloadLen =
    RuntimeStoreCodecSemantics.sealedMagicLen +
      RuntimeStoreCodecSemantics.sealedNonceBytes +
      payloadLen +
      RuntimeStoreCodecSemantics.sealedTagBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedPlainLen
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      payloadLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded sealed : List Nat}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeNonzero encoded = some sealed)
  (hEncodedLen :
    encoded.length = RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  sealed.length = RuntimeStoreCodecSemantics.sealedPlainLen payloadLen ∧
    ∃ parts,
      RuntimeStoreCodecSemantics.splitSealedRecord? payloadLen sealed =
          some parts ∧
        parts.ValidShape payloadLen := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode hEncodedLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded =
      some parts) :
  encoded.length = RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen ∧
    parts.ValidOpenShape payloadLen := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordOpenShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  (hLen :
    encoded.length ≠ RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded = none := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenTransportSound
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded =
      some parts) :
  encoded.length = RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen ∧
    parts.ValidOpenShape payloadLen ∧
    (∀ nibble,
      nibble ∈ encoded →
        RuntimeStoreCodecSemantics.ValidEncodedNibble nibble) ∧
    ∃ sealed,
      RuntimeStoreCodecSemantics.decodeNonzero encoded = some sealed ∧
        RuntimeStoreCodecSemantics.splitSealedRecord? payloadLen sealed =
            some parts ∧
          parts.bytes = sealed ∧
          sealed.length = RuntimeStoreCodecSemantics.sealedPlainLen payloadLen ∧
          (∀ byte, byte ∈ sealed →
            RuntimeStoreCodecSemantics.ValidByte byte) ∧
          (∀ byte, byte ∈ parts.bytes →
            RuntimeStoreCodecSemantics.ValidByte byte) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordOpenTransportSound
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoSlotCiphertextShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hDecode :
    RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded =
      some parts) :
  RuntimeStoreCodecSemantics.UoStoreSlotCiphertextShape
    payloadLen encoded := by
  exact
    RuntimePaperNativeKernelAssumptions.storeUoSlotCiphertextShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordTransportRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hOpenShape : parts.ValidOpenShape payloadLen)
  (hBytes :
    ∀ byte, byte ∈ parts.bytes →
      RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen
      (RuntimeStoreCodecSemantics.encodeNonzero parts.bytes) =
    some parts := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordTransportRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOpenShape hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordEncodedLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hShape : parts.ValidShape payloadLen) :
  (RuntimeStoreCodecSemantics.encodeNonzero parts.bytes).length =
      RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordEncodedLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hShape

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeEncodedUoSlotCiphertextShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hShape : parts.ValidShape payloadLen)
  (hBytes :
    ∀ byte, byte ∈ parts.bytes →
      RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.UoStoreSlotCiphertextShape
    payloadLen (RuntimeStoreCodecSemantics.encodeNonzero parts.bytes) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeEncodedUoSlotCiphertextShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hShape hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsWrongMagic
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hShape : parts.ValidShape payloadLen)
  (hMagic : parts.magic ≠ RuntimeStoreCodecSemantics.sealedMagic)
  (hBytes :
    ∀ byte, byte ∈ parts.bytes →
      RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen
      (RuntimeStoreCodecSemantics.encodeNonzero parts.bytes) = none := by
  exact
    RuntimePaperNativeKernelAssumptions.storeSealedRecordRejectsWrongMagic
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hShape hMagic hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWriteShapeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
    (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeUoUpdateWriteShapeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      object slotLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWritePublicShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : String}
  {slotLen : Nat}
  {write : RuntimeStoreCodecSemantics.StoreWriteShape}
  (hAccepted :
    RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted
      object slotLen write) :
  write.object = object ∧
    write.location = object ∧
    write.len = slotLen ∧
    write.writeClass = RuntimeStoreCodecSemantics.StoreWriteClass.update := by
  exact
    RuntimePaperNativeKernelAssumptions.storeUoUpdateWritePublicShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hAccepted

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueCopiesInput
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).boxed = value := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperTakeRawValueCopiesInput
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueWipesInputLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).wiped.length =
    value.length := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperTakeRawValueWipesInputLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueWipesInputZeros
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {value : List Nat}
  {byte : Nat}
  (hMem :
    byte ∈
      (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).wiped) :
  byte = 0 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperTakeRawValueWipesInputZeros
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hMem

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperZeroedRawSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (objects : List String)
  (slotLen : Nat) :
  (RuntimeStoreHelperSemantics.zeroedRawSlots objects slotLen).length =
    objects.length := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperZeroedRawSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      objects slotLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperLookupZeroedRawSlotsShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {objects : List String}
  {object : String}
  {slotLen : Nat}
  {value : List Nat}
  (hLookup :
    RuntimeStoreHelperSemantics.lookupSlot object
        (RuntimeStoreHelperSemantics.zeroedRawSlots objects slotLen) =
      some value) :
  value.length = slotLen ∧
    ∀ byte,
      byte ∈ value →
        RuntimeStoreCodecSemantics.ValidByte byte ∧ byte = 0 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperLookupZeroedRawSlotsShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLookup

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperInsertOrReplaceLookupSelf
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (slots : List RuntimeStoreHelperSemantics.StoreSlot)
  (object : String)
  (value : List Nat) :
  RuntimeStoreHelperSemantics.lookupSlot object
      (RuntimeStoreHelperSemantics.insertOrReplaceSlot object value slots) =
    some value := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperInsertOrReplaceLookupSelf
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      slots object value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperInsertOrReplaceLengthLeSucc
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (slots : List RuntimeStoreHelperSemantics.StoreSlot)
  (object : String)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.insertOrReplaceSlot object value slots).length ≤
    slots.length + 1 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperInsertOrReplaceLengthLeSucc
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      slots object value

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).length =
    events.length + 1 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperAppendEventLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      events event

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventPreservesPrefix
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).take
      events.length =
    events := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperAppendEventPreservesPrefix
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      events event

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventAppendsSingleton
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).drop
      events.length =
    [event] := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperAppendEventAppendsSingleton
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      events event

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAllUpdateAppendUoUpdate
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {events : List RuntimeStoreHelperSemantics.StoreWriteShape}
  (hEvents : RuntimeStoreHelperSemantics.allUpdate events)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreHelperSemantics.allUpdate
    (RuntimeStoreHelperSemantics.appendBoxedEvent events
      (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen)) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperAllUpdateAppendUoUpdate
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hEvents object slotLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperBootstrappedUoSlotPublicLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (logicalLen : Nat) :
  (RuntimeStoreHelperSemantics.bootstrappedUoSlotShape object logicalLen).value.length =
    RuntimeStoreCodecSemantics.sealedEncodedLen logicalLen := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperBootstrappedUoSlotPublicLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      object logicalLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperBootstrappedUoSlotValidBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (logicalLen : Nat) :
  ∀ byte,
    byte ∈
        (RuntimeStoreHelperSemantics.bootstrappedUoSlotShape object logicalLen).value →
      RuntimeStoreCodecSemantics.ValidByte byte := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperBootstrappedUoSlotValidBytes
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      object logicalLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperResealTracePublicUpdateShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreHelperSemantics.allUpdate
      [RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen] ∧
    RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
      (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperResealTracePublicUpdateShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      object slotLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordReadIncrementsReadCounts
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics) :
  (RuntimeStoreHelperSemantics.recordStoreRead metrics).logicalReads =
      metrics.logicalReads + 1 ∧
    (RuntimeStoreHelperSemantics.recordStoreRead metrics).physicalReads =
      metrics.physicalReads + 1 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperRecordReadIncrementsReadCounts
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      metrics

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordWriteIncrementsWriteCounts
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (zeroWrite : Bool) :
  (RuntimeStoreHelperSemantics.recordStoreWrite metrics zeroWrite).logicalWrites =
      metrics.logicalWrites + 1 ∧
    (RuntimeStoreHelperSemantics.recordStoreWrite metrics zeroWrite).physicalWrites =
      metrics.physicalWrites + 1 := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperRecordWriteIncrementsWriteCounts
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      metrics zeroWrite

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordUoWriteZeroWritesUnchanged
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (object : String)
  (slotLen : Nat) :
  (RuntimeStoreHelperSemantics.recordUoStoreWrite
      metrics object slotLen).metrics.zeroWrites =
    metrics.zeroWrites := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperRecordUoWriteZeroWritesUnchanged
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      metrics object slotLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordUoWriteEventAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
    (RuntimeStoreHelperSemantics.recordUoStoreWrite
      metrics object slotLen).event := by
  exact
    RuntimePaperNativeKernelAssumptions.storeHelperRecordUoWriteEventAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      metrics object slotLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectNatTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Nat) :
  RuntimeOramHelperSemantics.maskedSelectNat true whenTrue whenFalse =
    whenTrue := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectNatTrue
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectNatFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Nat) :
  RuntimeOramHelperSemantics.maskedSelectNat false whenTrue whenFalse =
    whenFalse := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectNatFalse
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectBoolTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeOramHelperSemantics.maskedSelectBool true whenTrue whenFalse =
    whenTrue := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectBoolTrue
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectBoolFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeOramHelperSemantics.maskedSelectBool false whenTrue whenFalse =
    whenFalse := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectBoolFalse
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectOptionTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.maskedSelectOption true whenTrue whenFalse =
    whenTrue := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectOptionTrue
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectOptionFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.maskedSelectOption false whenTrue whenFalse =
    whenFalse := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectOptionFalse
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectTransitionKindTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.PathTransitionKind) :
  RuntimeOramHelperSemantics.maskedSelectTransitionKind
      true whenTrue whenFalse = whenTrue := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectTransitionKindTrue
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectTransitionKindFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.PathTransitionKind) :
  RuntimeOramHelperSemantics.maskedSelectTransitionKind
      false whenTrue whenFalse = whenFalse := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperMaskedSelectTransitionKindFalse
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      whenTrue whenFalse

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindDelete
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (insertNew updateExisting : Bool) :
  RuntimeOramHelperSemantics.pathPutTransitionKind
      insertNew updateExisting true =
    RuntimeOramHelperSemantics.PathTransitionKind.writeDelete := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionKindDelete
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      insertNew updateExisting

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindUpdate
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (insertNew : Bool) :
  RuntimeOramHelperSemantics.pathPutTransitionKind insertNew true false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeUpdate := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionKindUpdate
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      insertNew

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindInsert
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathPutTransitionKind true false false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeInsert := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionKindInsert
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindNoop
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathPutTransitionKind false false false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeNoop := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionKindNoop
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionKindHit
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathGetTransitionKind true =
    RuntimeOramHelperSemantics.PathTransitionKind.readHit := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathGetTransitionKindHit
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionKindMiss
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathGetTransitionKind false =
    RuntimeOramHelperSemantics.PathTransitionKind.readMiss := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathGetTransitionKindMiss
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionFieldsMiss
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (accessLeaf freshLeaf : Nat) :
  RuntimeOramHelperSemantics.pathGetTransitionFields
      positionMap RuntimeOramHelperSemantics.noneOption
      accessLeaf freshLeaf =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.readMiss
    , freshLeaf := accessLeaf
    , slotIndex := RuntimeOramHelperSemantics.noneOption
    , priorLeaf := RuntimeOramHelperSemantics.noneOption
    , nextLeaf := RuntimeOramHelperSemantics.noneOption
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathGetTransitionFieldsMiss
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap accessLeaf freshLeaf

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionFieldsHit
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {slotIndex accessLeaf freshLeaf : Nat}
  {priorLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption}
  (hLookup :
    RuntimeOramHelperSemantics.lookupAt? positionMap slotIndex =
      some priorLeaf) :
  RuntimeOramHelperSemantics.pathGetTransitionFields
      positionMap (RuntimeOramHelperSemantics.presentOption slotIndex)
      accessLeaf freshLeaf =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.readHit
    , freshLeaf
    , slotIndex := RuntimeOramHelperSemantics.presentOption slotIndex
    , priorLeaf
    , nextLeaf := RuntimeOramHelperSemantics.presentOption freshLeaf
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathGetTransitionFieldsHit
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLookup

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsDelete
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (slotIndex priorLeaf accessLeaf nextLeafValue : Nat)
  (insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.pathPutTransitionFields
      true true (RuntimeOramHelperSemantics.presentOption slotIndex)
      insertSlot (RuntimeOramHelperSemantics.presentOption priorLeaf)
      accessLeaf nextLeafValue =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.writeDelete
    , freshLeaf := accessLeaf
    , slotIndex := RuntimeOramHelperSemantics.presentOption slotIndex
    , priorLeaf := RuntimeOramHelperSemantics.presentOption priorLeaf
    , nextLeaf := RuntimeOramHelperSemantics.noneOption
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionFieldsDelete
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsUpdate
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (slotIndex priorLeaf accessLeaf nextLeafValue : Nat)
  (insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.pathPutTransitionFields
      true false (RuntimeOramHelperSemantics.presentOption slotIndex)
      insertSlot (RuntimeOramHelperSemantics.presentOption priorLeaf)
      accessLeaf nextLeafValue =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.writeUpdate
    , freshLeaf := nextLeafValue
    , slotIndex := RuntimeOramHelperSemantics.presentOption slotIndex
    , priorLeaf := RuntimeOramHelperSemantics.presentOption priorLeaf
    , nextLeaf := RuntimeOramHelperSemantics.presentOption nextLeafValue
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionFieldsUpdate
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsInsert
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (insertSlot accessLeaf nextLeafValue : Nat) :
  RuntimeOramHelperSemantics.pathPutTransitionFields
      true false RuntimeOramHelperSemantics.noneOption
      (RuntimeOramHelperSemantics.presentOption insertSlot)
      RuntimeOramHelperSemantics.noneOption accessLeaf nextLeafValue =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.writeInsert
    , freshLeaf := nextLeafValue
    , slotIndex := RuntimeOramHelperSemantics.presentOption insertSlot
    , priorLeaf := RuntimeOramHelperSemantics.noneOption
    , nextLeaf := RuntimeOramHelperSemantics.presentOption nextLeafValue
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionFieldsInsert
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      insertSlot accessLeaf nextLeafValue

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsNoopAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (valueIsZero : Bool)
  (insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (accessLeaf nextLeafValue : Nat) :
  RuntimeOramHelperSemantics.pathPutTransitionFields
      false valueIsZero RuntimeOramHelperSemantics.noneOption
      insertSlot RuntimeOramHelperSemantics.noneOption
      accessLeaf nextLeafValue =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.writeNoop
    , freshLeaf := accessLeaf
    , slotIndex := RuntimeOramHelperSemantics.noneOption
    , priorLeaf := RuntimeOramHelperSemantics.noneOption
    , nextLeaf := RuntimeOramHelperSemantics.noneOption
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionFieldsNoopAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      valueIsZero insertSlot accessLeaf nextLeafValue

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsNoopPresentRetainsPrior
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (valueIsZero : Bool)
  (slotIndex priorLeaf accessLeaf nextLeafValue : Nat)
  (insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.pathPutTransitionFields
      false valueIsZero (RuntimeOramHelperSemantics.presentOption slotIndex)
      insertSlot (RuntimeOramHelperSemantics.presentOption priorLeaf)
      accessLeaf nextLeafValue =
    { kind := RuntimeOramHelperSemantics.PathTransitionKind.writeNoop
    , freshLeaf := priorLeaf
    , slotIndex := RuntimeOramHelperSemantics.presentOption slotIndex
    , priorLeaf := RuntimeOramHelperSemantics.presentOption priorLeaf
    , nextLeaf := RuntimeOramHelperSemantics.presentOption priorLeaf
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutTransitionFieldsNoopPresentRetainsPrior
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      valueIsZero slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveBlockValidationUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap liveSlots hOccupied

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block = liveSlots := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotsAfterUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap liveSlots hOccupied

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationValidOccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < capacity)
  (hLeaf : block.leaf < leafCount)
  (hPosition :
    RuntimeOramHelperSemantics.lookupAt? positionMap block.slotIndex =
      some (RuntimeOramHelperSemantics.presentOption block.leaf))
  (hLive :
    RuntimeOramHelperSemantics.lookupAt? liveSlots block.slotIndex =
      some RuntimeOramHelperSemantics.noneOption) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveBlockValidationValidOccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterValidOccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < capacity)
  (hLeaf : block.leaf < leafCount)
  (hPosition :
    RuntimeOramHelperSemantics.lookupAt? positionMap block.slotIndex =
      some (RuntimeOramHelperSemantics.presentOption block.leaf))
  (hLive :
    RuntimeOramHelperSemantics.lookupAt? liveSlots block.slotIndex =
      some RuntimeOramHelperSemantics.noneOption) :
  RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block =
    RuntimeOramHelperSemantics.replaceAt liveSlots block.slotIndex
      (RuntimeOramHelperSemantics.presentOption block.leaf) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotsAfterValidOccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationSlotOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : capacity ≤ block.slotIndex) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveBlockValidationSlotOutOfRange
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationDuplicateLiveSlot
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount liveLeaf : Nat}
  {positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < capacity)
  (hLeaf : block.leaf < leafCount)
  (hPosition :
    RuntimeOramHelperSemantics.lookupAt? positionMap block.slotIndex =
      some (RuntimeOramHelperSemantics.presentOption block.leaf))
  (hLive :
    RuntimeOramHelperSemantics.lookupAt? liveSlots block.slotIndex =
      some (RuntimeOramHelperSemantics.presentOption liveLeaf)) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveBlockValidationDuplicateLiveSlot
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterValidOccupiedLookup
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < capacity)
  (hLeaf : block.leaf < leafCount)
  (hPosition :
    RuntimeOramHelperSemantics.lookupAt? positionMap block.slotIndex =
      some (RuntimeOramHelperSemantics.presentOption block.leaf))
  (hLive :
    RuntimeOramHelperSemantics.lookupAt? liveSlots block.slotIndex =
      some RuntimeOramHelperSemantics.noneOption) :
  RuntimeOramHelperSemantics.lookupAt?
      (RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
        capacity leafCount positionMap liveSlots block)
      block.slotIndex =
    some (RuntimeOramHelperSemantics.presentOption block.leaf) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotsAfterValidOccupiedLookup
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoverageEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed [] liveSlots = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotCoverageEmpty
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      liveSlots

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoverageMissingLiveSlot
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (leaf :: positionMap) [] = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotCoverageMissingLiveSlot
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      leaf positionMap

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoverageAbsentHead
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (liveSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.noneOption :: positionMap)
      (liveSlot :: liveSlots) =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap liveSlots := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotCoverageAbsentHead
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap liveSlots liveSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoveragePresentLiveHead
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leaf liveLeaf : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.presentOption leaf :: positionMap)
      (RuntimeOramHelperSemantics.presentOption liveLeaf :: liveSlots) =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap liveSlots := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotCoveragePresentLiveHead
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      leaf liveLeaf positionMap liveSlots

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoveragePresentMissingHead
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leaf : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.presentOption leaf :: positionMap)
      (RuntimeOramHelperSemantics.noneOption :: liveSlots) = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotCoveragePresentMissingHead
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      leaf positionMap liveSlots

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperResetPathEntryCellsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.resetPathEntryCells capacity).length =
    capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperResetPathEntryCellsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperResetPathEntryCellsAllEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity : Nat}
  {entry : RuntimeOramHelperSemantics.PathEntryCell}
  (hEntry :
    entry ∈ RuntimeOramHelperSemantics.resetPathEntryCells capacity) :
  entry = RuntimeOramHelperSemantics.emptyPathEntryCell := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperResetPathEntryCellsAllEmpty
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hEntry

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFailedUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInstallPathEntryFailedUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entries hOccupied

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFromBlockUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.installPathEntryFromBlock entries block =
    entries := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInstallPathEntryFromBlockUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entries hOccupied

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFailedOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : entries.length ≤ block.slotIndex) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInstallPathEntryFailedOutOfRange
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFailedValidOccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < entries.length) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInstallPathEntryFailedValidOccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFromBlockPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.installPathEntryFromBlock
    entries block).length = entries.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInstallPathEntryFromBlockPreservesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entries block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFromBlockValidOccupiedLookup
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < entries.length) :
  RuntimeOramHelperSemantics.lookupAt?
      (RuntimeOramHelperSemantics.installPathEntryFromBlock entries block)
      block.slotIndex =
    some (RuntimeOramHelperSemantics.pathEntryCellFromBlock block) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInstallPathEntryFromBlockValidOccupiedLookup
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (block : RuntimeOramHelperSemantics.StashBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap block hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hState : state.failed = false)
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap hState hOccupied

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepValidationFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hState : state.failed = false)
  (hValidation :
    RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap state.liveSlots block = true) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
    capacity leafCount positionMap state block).failed = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepValidationFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap hState hValidation

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepInstallFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hState : state.failed = false)
  (hValidation :
    RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap state.liveSlots block = false)
  (hInstall :
    RuntimeOramHelperSemantics.installPathEntryFailed
      state.entries block = true) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
    capacity leafCount positionMap state block).failed = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepInstallFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap hState hValidation hInstall

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepValidOccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hState : state.failed = false)
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < capacity)
  (hLeaf : block.leaf < leafCount)
  (hPosition :
    RuntimeOramHelperSemantics.lookupAt? positionMap block.slotIndex =
      some (RuntimeOramHelperSemantics.presentOption block.leaf))
  (hLive :
    RuntimeOramHelperSemantics.lookupAt? state.liveSlots block.slotIndex =
      some RuntimeOramHelperSemantics.noneOption)
  (hEntrySlot : block.slotIndex < state.entries.length) :
  RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block =
    { liveSlots :=
        RuntimeOramHelperSemantics.replaceAt
          state.liveSlots block.slotIndex
          (RuntimeOramHelperSemantics.presentOption block.leaf)
    , entries :=
        RuntimeOramHelperSemantics.replaceAt
          state.entries block.slotIndex
          (RuntimeOramHelperSemantics.pathEntryCellFromBlock block)
    , failed := false
    } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepValidOccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hState hOccupied hSlot hLeaf hPosition hLive hEntrySlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathFinishFailedPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathFinishFailed
      positionMap state = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathFinishFailedPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathFinishFailedCoverageFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (hFailed : state.failed = false)
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed
      positionMap state.liveSlots = true) :
  RuntimeOramHelperSemantics.reconstructPathFinishFailed
      positionMap state = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathFinishFailedCoverageFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap hFailed hCoverage

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathFinishFailedSuccess
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (hFailed : state.failed = false)
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed
      positionMap state.liveSlots = false) :
  RuntimeOramHelperSemantics.reconstructPathFinishFailed
      positionMap state = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathFinishFailedSuccess
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap hFailed hCoverage

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state [] = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksEmpty
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksCons
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (block : RuntimeOramHelperSemantics.StashBlock)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state (block :: blocks) =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBlockStep
        capacity leafCount positionMap state block)
      blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksCons
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state block blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap blocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInitialReconstructionStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).liveSlots.length =
    capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInitialReconstructionStateLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInitialReconstructionStateEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).entries.length =
    capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInitialReconstructionStateEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInitialReconstructionStateFailed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).failed =
    false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperInitialReconstructionStateFailed
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksStateStashThenBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks bucketBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks bucketBlocks =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBlocks
        capacity leafCount positionMap
        (RuntimeOramHelperSemantics.initialReconstructionState capacity)
        stashBlocks)
      bucketBlocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksStateStashThenBuckets
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksStateNoBlocks
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.initialReconstructionState capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksStateNoBlocks
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksStateStashFailureAbsorbs
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks bucketBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks).failed = true) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks bucketBlocks =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksStateStashFailureAbsorbs
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks bucketBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks bucketBlocks).failed =
        true) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksFailedPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedSuccess
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks bucketBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks bucketBlocks).failed =
        false)
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
        capacity leafCount positionMap stashBlocks bucketBlocks).liveSlots =
        false) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks bucketBlocks = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksFailedSuccess
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed hCoverage

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedStashFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks bucketBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks).failed = true) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksFailedStashFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedNoBlocks
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed
      positionMap
      (List.replicate capacity RuntimeOramHelperSemantics.noneOption) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBlocksFailedNoBlocks
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leafCount bucketIndex leaf : Nat) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      { bucketIndex
      , block := { occupied := false, slotIndex := 0, leaf }
      } = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockAdmissionFailedUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      leafCount bucketIndex leaf

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedOnPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hPath :
    RuntimeOramCodecSemantics.bucketOnLeafPath
      leafCount bucketIndex block.leaf = true) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      { bucketIndex, block } = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockAdmissionFailedOnPath
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hPath

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedOffPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hPath :
    RuntimeOramCodecSemantics.bucketOnLeafPath
      leafCount bucketIndex block.leaf = false) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      { bucketIndex, block } = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockAdmissionFailedOffPath
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hPath

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (bucketBlock : RuntimeOramHelperSemantics.BucketBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlockStepPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap bucketBlock hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepOffPathFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {bucketBlock : RuntimeOramHelperSemantics.BucketBlock}
  (hState : state.failed = false)
  (hAdmission :
    RuntimeOramHelperSemantics.bucketBlockAdmissionFailed
      leafCount bucketBlock = true) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock =
    { state with failed := true } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlockStepOffPathFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap hState hAdmission

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepAdmitted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {bucketBlock : RuntimeOramHelperSemantics.BucketBlock}
  (hState : state.failed = false)
  (hAdmission :
    RuntimeOramHelperSemantics.bucketBlockAdmissionFailed
      leafCount bucketBlock = false) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock =
    RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state bucketBlock.block := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlockStepAdmitted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap hState hAdmission

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state [] = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksEmpty
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks = state := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap bucketBlocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateStashThenBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks bucketBlocks =
    RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBlocks
        capacity leafCount positionMap
        (RuntimeOramHelperSemantics.initialReconstructionState capacity)
        stashBlocks)
      bucketBlocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateStashThenBuckets
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateStashFailureAbsorbs
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks).failed = true) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks bucketBlocks =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateStashFailureAbsorbs
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedStashFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks).failed = true) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks bucketBlocks = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsFailedStashFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedSuccess
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks bucketBlocks).failed =
        false)
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks bucketBlocks).liveSlots =
        false) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks bucketBlocks = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsFailedSuccess
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed hCoverage

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockOfCodecBlockBucketIndex
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (block : RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block).bucketIndex =
    bucketIndex := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockOfCodecBlockBucketIndex
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      bucketIndex block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockOfCodecBlockBlock
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (block : RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block).block =
    RuntimeOramHelperSemantics.stashBlockOfCodecBlock block := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockOfCodecBlockBlock
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      bucketIndex block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperStashBlocksOfCodecBlocksLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks blocks).length =
    blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperStashBlocksOfCodecBlocksLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksOfCodecBlocksLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks).length =
    blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlocksOfCodecBlocksLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      bucketIndex blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksOfCodecBlocksMapBlock
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks).map
      RuntimeOramHelperSemantics.BucketBlock.block =
    RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlocksOfCodecBlocksMapBlock
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      bucketIndex blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedBridgeUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hUnoccupied : block.occupiedTag ≠ 1) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block) =
    false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockAdmissionFailedBridgeUnoccupied
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hUnoccupied

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedBridgeLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hLive : block.LiveOnBucketPath leafCount bucketIndex) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block) =
    false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlockAdmissionFailedBridgeLiveOnBucketPath
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksOfCodecBlocksAdmittedOfLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hLive :
    ∀ block, block ∈ blocks →
      block.LiveOnBucketPath leafCount bucketIndex) :
  ∀ bucketBlock,
    bucketBlock ∈
        RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks →
      RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount bucketBlock =
        false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlocksOfCodecBlocksAdmittedOfLiveOnBucketPath
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksEqReconstructPathBlocksOfAdmitted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hAdmit :
    ∀ bb, bb ∈ bucketBlocks →
      RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount bb = false) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state
      (bucketBlocks.map RuntimeOramHelperSemantics.BucketBlock.block) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksEqReconstructPathBlocksOfAdmitted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state bucketBlocks hAdmit

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksBucketBlocksOfCodecBlocks
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount bucketIndex : Nat}
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (codecBlocks : List RuntimeOramCodecSemantics.CodecBlock)
  (hLive :
    ∀ block, block ∈ codecBlocks →
      block.LiveOnBucketPath leafCount bucketIndex) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex
        codecBlocks) =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks codecBlocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksBucketBlocksOfCodecBlocks
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap state codecBlocks hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateBucketBlocksOfCodecBlocks
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount bucketIndex : Nat}
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (codecBlocks : List RuntimeOramCodecSemantics.CodecBlock)
  (hLive :
    ∀ block, block ∈ codecBlocks →
      block.LiveOnBucketPath leafCount bucketIndex) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex
        codecBlocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks codecBlocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateBucketBlocksOfCodecBlocks
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap stashBlocks codecBlocks hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedBucketBlocksOfCodecBlocks
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount bucketIndex : Nat}
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (codecBlocks : List RuntimeOramCodecSemantics.CodecBlock)
  (hLive :
    ∀ block, block ∈ codecBlocks →
      block.LiveOnBucketPath leafCount bucketIndex) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex
        codecBlocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks codecBlocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsFailedBucketBlocksOfCodecBlocks
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap stashBlocks codecBlocks hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPathBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount blocksPerBucket keyBytes valueBytes
    expectedBucketIndex : Nat}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPathBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes = some payload)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks
        expectedBucketIndex payload.blocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks payload.blocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPathBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode positionMap stashBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPathBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount blocksPerBucket keyBytes valueBytes
    expectedBucketIndex : Nat}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPathBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes = some payload)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks
        expectedBucketIndex payload.blocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks payload.blocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPathBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode positionMap stashBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPositionMapBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount blocksPerBucket keyBytes valueBytes
    expectedBucketIndex : Nat}
  {positionMapEntries : List (Option Nat)}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMapEntries bytes = some payload)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks
        expectedBucketIndex payload.blocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks payload.blocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPositionMapBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode positionMap stashBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPositionMapBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount blocksPerBucket keyBytes valueBytes
    expectedBucketIndex : Nat}
  {positionMapEntries : List (Option Nat)}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMapEntries bytes = some payload)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks
        expectedBucketIndex payload.blocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks payload.blocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPositionMapBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode positionMap stashBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketUniquePositionMapBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount blocksPerBucket keyBytes valueBytes
    expectedBucketIndex : Nat}
  {positionMapEntries : List (Option Nat)}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketUniquePositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMapEntries bytes = some payload)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks
        expectedBucketIndex payload.blocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks payload.blocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketUniquePositionMapBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode positionMap stashBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketUniquePositionMapBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount blocksPerBucket keyBytes valueBytes
    expectedBucketIndex : Nat}
  {positionMapEntries : List (Option Nat)}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketUniquePositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMapEntries bytes = some payload)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks
        expectedBucketIndex payload.blocks) =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks payload.blocks) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketUniquePositionMapBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode positionMap stashBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksAppend
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (xs ys : List RuntimeOramHelperSemantics.BucketBlock) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state (xs ++ ys) =
    RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBucketBlocks
        capacity leafCount positionMap state xs)
      ys := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksAppend
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state xs ys

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksAppend
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (xs ys : List RuntimeOramHelperSemantics.StashBlock) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state (xs ++ ys) =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBlocks
        capacity leafCount positionMap state xs)
      ys := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksAppend
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state xs ys

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksBucketBlocksOfDecodedBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket)
  (hLive :
    RuntimeOramHelperSemantics.DecodedBuckets.LiveOnBucketPath
      leafCount decodedBuckets) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state
      (RuntimeOramHelperSemantics.bucketBlocksOfDecodedBuckets
        decodedBuckets) =
    RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state
      (RuntimeOramHelperSemantics.stashBlocksOfDecodedBuckets
        decodedBuckets) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksBucketBlocksOfDecodedBuckets
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state decodedBuckets hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket)
  (hLive :
    RuntimeOramHelperSemantics.DecodedBuckets.LiveOnBucketPath
      leafCount decodedBuckets) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks decodedBuckets =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfDecodedBuckets
        decodedBuckets) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListStateLiveOnBucketPath
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket)
  (hLive :
    RuntimeOramHelperSemantics.DecodedBuckets.LiveOnBucketPath
      leafCount decodedBuckets) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap stashBlocks decodedBuckets =
    RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap stashBlocks
      (RuntimeOramHelperSemantics.stashBlocksOfDecodedBuckets
        decodedBuckets) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListFailedLiveOnBucketPath
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks decodedBuckets).failed =
        true) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap stashBlocks decodedBuckets = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListFailedPriorFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hFailed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedSuccess
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket)
  (hFailed :
    (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks decodedBuckets).failed =
        false)
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
        capacity leafCount positionMap stashBlocks decodedBuckets).liveSlots =
        false) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap stashBlocks decodedBuckets = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListFailedSuccess
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hFailed hCoverage

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateNoBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.initialReconstructionState capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListStateNoBuckets
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedNoBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (List.replicate capacity RuntimeOramHelperSemantics.noneOption) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListFailedNoBuckets
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketsLiveOnBucketPathCons
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount : Nat}
  {b : RuntimeOramHelperSemantics.DecodedBucket}
  {bs : List RuntimeOramHelperSemantics.DecodedBucket}
  (hHead : b.LiveOnBucketPath leafCount)
  (hTail :
    RuntimeOramHelperSemantics.DecodedBuckets.LiveOnBucketPath
      leafCount bs) :
  RuntimeOramHelperSemantics.DecodedBuckets.LiveOnBucketPath
      leafCount (b :: bs) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperDecodedBucketsLiveOnBucketPathCons
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hHead hTail

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPathBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes capacity leafCount : Nat}
  {bytes : List Nat}
  {b : RuntimeOramHelperSemantics.DecodedBucket}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPathBoundedExact?
      blocksPerBucket keyBytes valueBytes b.bucketIndex
      capacity leafCount bytes = some b.payload) :
  b.LiveOnBucketPath leafCount := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPathBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPositionMapBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes capacity leafCount : Nat}
  {positionMapEntries : List (Option Nat)}
  {bytes : List Nat}
  {b : RuntimeOramHelperSemantics.DecodedBucket}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPositionMapBoundedExact?
      blocksPerBucket keyBytes valueBytes b.bucketIndex
      capacity leafCount positionMapEntries bytes = some b.payload) :
  b.LiveOnBucketPath leafCount := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPositionMapBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketUniquePositionMapBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes capacity leafCount : Nat}
  {positionMapEntries : List (Option Nat)}
  {bytes : List Nat}
  {b : RuntimeOramHelperSemantics.DecodedBucket}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketUniquePositionMapBoundedExact?
      blocksPerBucket keyBytes valueBytes b.bucketIndex
      capacity leafCount positionMapEntries bytes = some b.payload) :
  b.LiveOnBucketPath leafCount := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketUniquePositionMapBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterBlockValidationLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block).length =
    liveSlots.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperLiveSlotsAfterBlockValidationLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap liveSlots block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block).entries.length =
    state.entries.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks).entries.length =
    state.entries.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlock : RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlockStepLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state bucketBlock

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlock : RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock).entries.length =
    state.entries.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlockStepEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state bucketBlock

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state bucketBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks).entries.length =
    state.entries.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state bucketBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      bucketBlocks).liveSlots.length = capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      bucketBlocks).entries.length = capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStateEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks
      decodedBuckets).liveSlots.length = capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListStateLiveSlotsLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks
      decodedBuckets).entries.length = capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListStateEntriesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepPreservesNonFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hState : state.failed = false)
  (hValidation :
    RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap state.liveSlots block = false)
  (hInstall :
    RuntimeOramHelperSemantics.installPathEntryFailed
      state.entries block = false) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block).failed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlockStepPreservesNonFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hState hValidation hInstall

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepPreservesNonFailureAdmitted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  {bucketBlock : RuntimeOramHelperSemantics.BucketBlock}
  (hState : state.failed = false)
  (hAdmission :
    RuntimeOramHelperSemantics.bucketBlockAdmissionFailed
      leafCount bucketBlock = false)
  (hValidation :
    RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap state.liveSlots
      bucketBlock.block = false)
  (hInstall :
    RuntimeOramHelperSemantics.installPathEntryFailed
      state.entries bucketBlock.block = false) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock).failed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlockStepPreservesNonFailureAdmitted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hState hAdmission hValidation hInstall

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperStashWellFormedFromNil
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.StashWellFormedFrom
    capacity leafCount positionMap state [] := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperStashWellFormedFromNil
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksWellFormedFromNil
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.BucketBlocksWellFormedFrom
    capacity leafCount positionMap state [] := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBucketBlocksWellFormedFromNil
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksPreservesNonFailureOfWellFormed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (hState : state.failed = false)
  (hWellFormed :
    RuntimeOramHelperSemantics.StashWellFormedFrom
      capacity leafCount positionMap state blocks) :
  (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks).failed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBlocksPreservesNonFailureOfWellFormed
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state blocks hState hWellFormed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksPreservesNonFailureOfWellFormed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hState : state.failed = false)
  (hWellFormed :
    RuntimeOramHelperSemantics.BucketBlocksWellFormedFrom
      capacity leafCount positionMap state bucketBlocks) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks).failed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathBucketBlocksPreservesNonFailureOfWellFormed
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap state bucketBlocks hState hWellFormed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStatePreservesNonFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hStashWellFormed :
    RuntimeOramHelperSemantics.StashWellFormedFrom
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks)
  (hBucketWellFormed :
    RuntimeOramHelperSemantics.BucketBlocksWellFormedFrom
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBlocks
        capacity leafCount positionMap
        (RuntimeOramHelperSemantics.initialReconstructionState capacity)
        stashBlocks)
      bucketBlocks) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      bucketBlocks).failed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsStatePreservesNonFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks
      hStashWellFormed hBucketWellFormed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStatePreservesNonFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket)
  (hStashWellFormed :
    RuntimeOramHelperSemantics.StashWellFormedFrom
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.initialReconstructionState capacity)
      stashBlocks)
  (hBucketWellFormed :
    RuntimeOramHelperSemantics.BucketBlocksWellFormedFrom
      capacity leafCount positionMap
      (RuntimeOramHelperSemantics.reconstructPathBlocks
        capacity leafCount positionMap
        (RuntimeOramHelperSemantics.initialReconstructionState capacity)
        stashBlocks)
      (RuntimeOramHelperSemantics.bucketBlocksOfDecodedBuckets
        decodedBuckets)) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks
      decodedBuckets).failed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperReconstructPathDecodedBucketsListStatePreservesNonFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets
      hStashWellFormed hBucketWellFormed

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperWorkingStashCapacityFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.Parameters) :
  RuntimeOramHelperSemantics.workingStashCapacity parameters =
    parameters.stashBound +
      parameters.bucketsPerAccess * parameters.blocksPerBucket := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperWorkingStashCapacityFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSlotForKeySomeWithinCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyMatches : List Bool}
  {slot : Nat}
  (hSlot : RuntimeOramHelperSemantics.slotForKey? keyMatches = some slot) :
  slot < keyMatches.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperSlotForKeySomeWithinCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperAllocateSlotSomeWithinCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {occupied : List Bool}
  {slot : Nat}
  (hSlot : RuntimeOramHelperSemantics.allocateSlot? occupied = some slot) :
  slot < occupied.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperAllocateSlotSomeWithinCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperFirstVacantIndexSomeWithinCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {index : Nat}
  (hIndex :
    RuntimeOramHelperSemantics.firstVacantIndex blocks = some index) :
  index < blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperFirstVacantIndexSomeWithinCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hIndex

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperClearFixedStashLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.clearFixedStash blocks).length =
    blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperClearFixedStashLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperClearFixedStashAllEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hMem : block ∈ RuntimeOramHelperSemantics.clearFixedStash blocks) :
  block = RuntimeOramHelperSemantics.emptyBlock := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperClearFixedStashAllEmpty
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hMem

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPushFixedStashPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (overflowed : Bool)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.pushFixedStash
      blocks overflowed block).blocks.length =
    blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPushFixedStashPreservesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocks overflowed block

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPushFixedStashVacantPreservesOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {overflowed : Bool}
  {block : RuntimeOramHelperSemantics.StashBlock}
  {index : Nat}
  (hOccupied : block.occupied = true)
  (hVacant :
    RuntimeOramHelperSemantics.firstVacantIndex blocks = some index) :
  (RuntimeOramHelperSemantics.pushFixedStash
      blocks overflowed block).overflowed = overflowed := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPushFixedStashVacantPreservesOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hVacant

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPushFixedStashNoVacantOverflows
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {overflowed : Bool}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hVacant :
    RuntimeOramHelperSemantics.firstVacantIndex blocks = none) :
  (RuntimeOramHelperSemantics.pushFixedStash
      blocks overflowed block).overflowed = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPushFixedStashNoVacantOverflows
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hOccupied hVacant

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperTakeSelectedBlockPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {selectedIndex : Nat}
  {present : Bool}
  {result : RuntimeOramHelperSemantics.TakeResult}
  (hTake :
    RuntimeOramHelperSemantics.takeSelectedBlock
        blocks selectedIndex present = some result) :
  result.blocks.length = blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperTakeSelectedBlockPreservesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hTake

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperTakeSelectedBlockPresentSelectedInBounds
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {selectedIndex : Nat}
  {result : RuntimeOramHelperSemantics.TakeResult}
  (hTake :
    RuntimeOramHelperSemantics.takeSelectedBlock
        blocks selectedIndex true = some result) :
  selectedIndex < blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperTakeSelectedBlockPresentSelectedInBounds
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hTake

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectPositionMapLeafAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.selectPositionMapLeaf positionMap slot =
    RuntimeOramHelperSemantics.noneOption := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperSelectPositionMapLeafAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap slot hAbsent

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectPositionMapLeafPresentGet
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {slot leaf : RuntimeOramHelperSemantics.MaskedUsizeOption}
  (hPresent : slot.present = true)
  (hGet :
    RuntimeOramHelperSemantics.lookupAt? positionMap slot.value = some leaf) :
  RuntimeOramHelperSemantics.selectPositionMapLeaf positionMap slot = leaf := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperSelectPositionMapLeafPresentGet
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hPresent hGet

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectValueAtAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (values : List α)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (default : α)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.selectValueAt values slot default = default := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperSelectValueAtAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      values slot default hAbsent

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectValueAtPresentGet
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {values : List α}
  {slot : RuntimeOramHelperSemantics.MaskedUsizeOption}
  {default value : α}
  (hPresent : slot.present = true)
  (hGet : RuntimeOramHelperSemantics.lookupAt? values slot.value = some value) :
  RuntimeOramHelperSemantics.selectValueAt values slot default = value := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperSelectValueAtPresentGet
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hPresent hGet

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperAccessLeafUsesFreshWhenNoPrior
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (freshLeaf : Nat)
  (hNoPrior :
    (RuntimeOramHelperSemantics.selectPositionMapLeaf
      positionMap slot).present = false) :
  RuntimeOramHelperSemantics.accessLeafForSlot
      positionMap slot freshLeaf = freshLeaf := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperAccessLeafUsesFreshWhenNoPrior
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap slot freshLeaf hNoPrior

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperAccessLeafUsesPriorWhenPresent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (freshLeaf : Nat)
  (hPrior :
    (RuntimeOramHelperSemantics.selectPositionMapLeaf
      positionMap slot).present = true) :
  RuntimeOramHelperSemantics.accessLeafForSlot
      positionMap slot freshLeaf =
    (RuntimeOramHelperSemantics.selectPositionMapLeaf
      positionMap slot).value := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperAccessLeafUsesPriorWhenPresent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap slot freshLeaf hPrior

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdatePositionMapLeafPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  (RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf).length = positionMap.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperUpdatePositionMapLeafPreservesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap slot nextLeaf

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdatePositionMapLeafAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf = positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperUpdatePositionMapLeafAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap slot nextLeaf hAbsent

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdatePositionMapLeafNextAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : nextLeaf.present = false) :
  RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf = positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperUpdatePositionMapLeafNextAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      positionMap slot nextLeaf hAbsent

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdateStashLeafForSlotPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  (RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf).length = blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperUpdateStashLeafForSlotPreservesLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocks slot nextLeaf

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdateStashLeafForSlotAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf = blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperUpdateStashLeafForSlotAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocks slot nextLeaf hAbsent

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdateStashLeafForSlotNextAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : nextLeaf.present = false) :
  RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf = blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperUpdateStashLeafForSlotNextAbsent
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocks slot nextLeaf hAbsent

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedNoApply
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entryCapacity : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (valueIsZero : Bool)
  (slot insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.pathPutUpdateFailed
      entryCapacity blocks false valueIsZero slot insertSlot = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutUpdateFailedNoApply
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entryCapacity blocks valueIsZero slot insertSlot

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedUpdateMissing
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entryCapacity : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hSlot : slot.present = true)
  (hMissing :
    RuntimeOramHelperSemantics.stashContainsSlot
      blocks slot.value = false) :
  RuntimeOramHelperSemantics.pathPutUpdateFailed
      entryCapacity blocks true false slot insertSlot = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutUpdateFailedUpdateMissing
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entryCapacity blocks slot insertSlot hSlot hMissing

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedInsertNoVacancy
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entryCapacity : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hSlotAbsent : slot.present = false)
  (hInsert : insertSlot.present = true)
  (hVacant : RuntimeOramHelperSemantics.stashHasVacant blocks = false) :
  RuntimeOramHelperSemantics.pathPutUpdateFailed
      entryCapacity blocks true false slot insertSlot = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutUpdateFailedInsertNoVacancy
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entryCapacity blocks slot insertSlot hSlotAbsent hInsert hVacant

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedInsertOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entryCapacity : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hSlotAbsent : slot.present = false)
  (hInsert : insertSlot.present = true)
  (hOutOfRange : entryCapacity ≤ insertSlot.value) :
  RuntimeOramHelperSemantics.pathPutUpdateFailed
      entryCapacity blocks true false slot insertSlot = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathPutUpdateFailedInsertOutOfRange
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      entryCapacity blocks slot insertSlot hSlotAbsent hInsert hOutOfRange

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBuildPathBucketBucketLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).bucket.length =
    blocksPerBucket := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBuildPathBucketBucketLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocksPerBucket leafCount bucketIndex blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBuildPathBucketStashLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).stash.length =
    blocks.length := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBuildPathBucketStashLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocksPerBucket leafCount bucketIndex blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBuildPathBucketLiveCountBound
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).liveCount ≤
    blocksPerBucket := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperBuildPathBucketLiveCountBound
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocksPerBucket leafCount bucketIndex blocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathWriteCountMatchesWriteLogCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters) :
  RuntimeOramHelperSemantics.rewritePathWriteCount parameters =
    RuntimeOramWriteLogDiscipline.writeLogCapacity
      (RuntimeOramHelperSemantics.rewriteWriteLogParameters parameters) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathWriteCountMatchesWriteLogCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathAccessReadCountMatchesReadTranscriptCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters) :
  RuntimeOramHelperSemantics.pathAccessReadCount parameters =
    RuntimeOramWriteLogDiscipline.readTranscriptCapacity
      (RuntimeOramHelperSemantics.rewriteWriteLogParameters parameters) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperPathAccessReadCountMatchesReadTranscriptCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathSummaryNextCounter
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (currentCounter : Nat)
  (loadOverflowed effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  (RuntimeOramHelperSemantics.rewritePathSummary
      parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen).nextCounter =
    currentCounter + 1 := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathSummaryNextCounter
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathSummaryPhysicalWriteCount
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (currentCounter : Nat)
  (loadOverflowed effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  (RuntimeOramHelperSemantics.rewritePathSummary
      parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen).physicalWriteCount =
    RuntimeOramHelperSemantics.rewritePathWriteCount parameters := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathSummaryPhysicalWriteCount
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedLoadOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters true effectFailed postUpdateStashLen postRebuildStashLen =
    true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathUpdateFailedLoadOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters effectFailed postUpdateStashLen postRebuildStashLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedEffectFailed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (loadOverflowed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters loadOverflowed true postUpdateStashLen postRebuildStashLen =
    true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathUpdateFailedEffectFailed
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters loadOverflowed postUpdateStashLen postRebuildStashLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedPostUpdateOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (loadOverflowed effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat)
  (hOverflow :
    RuntimeOramHelperSemantics.rewriteWorkingStashBound parameters <
      postUpdateStashLen) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathUpdateFailedPostUpdateOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen hOverflow

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedPostRebuildOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (loadOverflowed effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat)
  (hOverflow : parameters.stashBound < postRebuildStashLen) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen = true := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathUpdateFailedPostRebuildOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen hOverflow

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedNoFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (postUpdateStashLen postRebuildStashLen : Nat)
  (hPostUpdate :
    postUpdateStashLen ≤
      RuntimeOramHelperSemantics.rewriteWorkingStashBound parameters)
  (hPostRebuild : postRebuildStashLen ≤ parameters.stashBound) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters false false postUpdateStashLen postRebuildStashLen =
    false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathUpdateFailedNoFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters postUpdateStashLen postRebuildStashLen hPostUpdate
      hPostRebuild

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathSummaryNoFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (currentCounter postUpdateStashLen postRebuildStashLen : Nat)
  (hPostUpdate :
    postUpdateStashLen ≤
      RuntimeOramHelperSemantics.rewriteWorkingStashBound parameters)
  (hPostRebuild : postRebuildStashLen ≤ parameters.stashBound) :
  (RuntimeOramHelperSemantics.rewritePathSummary
      parameters currentCounter false false postUpdateStashLen
      postRebuildStashLen).updateFailed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramHelperRewritePathSummaryNoFailure
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      parameters currentCounter postUpdateStashLen postRebuildStashLen
      hPostUpdate hPostRebuild

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    RuntimePaperNativeKernelAssumptions.oramBucketBytesMatchCodec
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hObject

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedSurrogateOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    RuntimePaperNativeKernelAssumptions.oramSurrogateBucketBytesMatchCodec
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hObject

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedPathOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    RuntimePaperNativeKernelAssumptions.oramPathBucketBytesMatchCodec
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hObject

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBlockBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.surrogateBlockBytes keyBytes valueBytes =
    RuntimeOramCodecSemantics.occupancyTagBytes + keyBytes + valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramSurrogateBlockBytesPublicFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      keyBytes valueBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBlockBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.pathBlockBytes keyBytes valueBytes =
    RuntimeOramCodecSemantics.occupancyTagBytes +
      RuntimeOramCodecSemantics.slotIndexBytes +
      RuntimeOramCodecSemantics.leafLabelBytes +
      keyBytes +
      valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramPathBlockBytesPublicFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      keyBytes valueBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket blockBytes : Nat) :
  RuntimeOramCodecSemantics.bucketBytes blocksPerBucket blockBytes =
    oramBucketHeaderBytes +
      blocksPerBucket * blockBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramBucketBytesPublicFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blocksPerBucket blockBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDirectoryPageBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blockBytes : Nat) :
  RuntimeOramCodecSemantics.directoryPageBytes blockBytes =
    RuntimeOramCodecSemantics.directoryPageEntries * blockBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramDirectoryPageBytesPublicFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      blockBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPublicCountGuardAcceptsExact
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (expected : Nat) :
  RuntimeOramCodecSemantics.publicCountGuard? expected expected = some () := by
  exact
    RuntimePaperNativeKernelAssumptions.oramPublicCountGuardAcceptsExact
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      expected

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDirectoryPagesRejectCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimePaperNativeKernelAssumptions.oramDirectoryPagesRejectCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketsRejectCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimePaperNativeKernelAssumptions.oramBucketsRejectCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapBufferRejectsCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapBufferRejectsCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathLiveSlotsRejectCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimePaperNativeKernelAssumptions.pathLiveSlotsRejectCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterFieldBytesMatchSlotIndex
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramCodecSemantics.counterFieldBytes =
    RuntimeOramCodecSemantics.slotIndexBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterFieldBytesMatchSlotIndex
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketHeaderBytesMatchesRuntimeHeader
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramCodecSemantics.codecBucketHeaderBytes =
    oramBucketHeaderBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCodecBucketHeaderBytesMatchesRuntimeHeader
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesSurrogateMatchesFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBlockBytes false keyBytes valueBytes =
    RuntimeOramCodecSemantics.surrogateBlockBytes keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCodecBlockBytesSurrogateMatchesFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      keyBytes valueBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesPathMatchesFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBlockBytes true keyBytes valueBytes =
    RuntimeOramCodecSemantics.pathBlockBytes keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCodecBlockBytesPathMatchesFormula
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      keyBytes valueBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketBytesMatchesRuntimeBucketBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (isPath : Bool)
  (blocksPerBucket keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBucketBytes
      isPath blocksPerBucket keyBytes valueBytes =
    RuntimeOramCodecSemantics.bucketBytes blocksPerBucket
      (RuntimeOramCodecSemantics.codecBlockBytes
        isPath keyBytes valueBytes) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCodecBucketBytesMatchesRuntimeBucketBytes
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      isPath blocksPerBucket keyBytes valueBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.CounterDecodeAccepted
    (RuntimeOramCodecSemantics.encodeCounterField counter) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterEncodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      counter

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  (RuntimeOramCodecSemantics.encodeCounterField counter).length =
    RuntimeOramCodecSemantics.counterFieldBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterEncodeLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      counter

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeValidBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.ValidByteField
    (RuntimeOramCodecSemantics.encodeCounterField counter) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterEncodeValidBytes
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      counter

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeExactEncode
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.decodeCounterExact?
      (RuntimeOramCodecSemantics.encodeCounterField counter) =
    some
      (RuntimeOramCodecSemantics.decodeNatField
        (RuntimeOramCodecSemantics.encodeCounterField counter)) := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterDecodeExactEncode
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      counter

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter)
  (hBytes : RuntimeOramCodecSemantics.ValidByteField bytes) :
  RuntimeOramCodecSemantics.CounterDecodeAccepted bytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterDecodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode hBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter) :
  bytes.length = RuntimeOramCodecSemantics.counterFieldBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterDecodeLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeValue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter) :
  counter = RuntimeOramCodecSemantics.decodeNatField bytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramCounterDecodeValue
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBlockCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock :
    block.ValidShape isPath keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodeBlock?
      isPath keyBytes valueBytes
      (RuntimeOramCodecSemantics.encodeBlock isPath block) =
    some block := by
  exact
    RuntimePaperNativeKernelAssumptions.oramBlockCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBlock

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock :
    block.ValidShape isPath keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodeBlockExact?
      isPath keyBytes valueBytes
      (RuntimeOramCodecSemantics.encodeBlock isPath block) =
    some block := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBlockCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBlock

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {bytes : List Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodeBlockExact?
        isPath keyBytes valueBytes bytes = some block) :
  bytes.length =
    RuntimeOramCodecSemantics.codecBlockBytes
      isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBlockDecodeLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeValidShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {bytes : List Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodeBlockExact?
        isPath keyBytes valueBytes bytes = some block) :
  block.ValidShape isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBlockDecodeValidShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlockLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock :
    block.ValidShape isPath keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBlock isPath block).length =
    RuntimeOramCodecSemantics.codecBlockBytes
      isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramEncodeBlockLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBlock

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlocksLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hBlocks :
    ∀ block, block ∈ blocks →
      block.ValidShape isPath keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBlocks isPath blocks).length =
    blocks.length *
      RuntimeOramCodecSemantics.codecBlockBytes
        isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramEncodeBlocksLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlocksDecodeCount
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes count : Nat}
  {bytes : List Nat}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodeExactBlocks?
        isPath keyBytes valueBytes count bytes = some blocks) :
  blocks.length = count := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBlocksDecodeCount
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlocksCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hBlocks :
    ∀ block, block ∈ blocks →
      block.ValidShape isPath keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodeExactBlocks?
      isPath keyBytes valueBytes blocks.length
      (RuntimeOramCodecSemantics.encodeBlocks isPath blocks) =
    some blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBlocksCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBlocks

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketCodecLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes : Nat}
  {bucket : RuntimeOramCodecSemantics.CodecBucket}
  (hBucket :
    bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBucket isPath bucket).length =
    RuntimeOramCodecSemantics.codecBucketBytes
      isPath blocksPerBucket keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramBucketCodecLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBucket

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
  {bucket : RuntimeOramCodecSemantics.CodecBucket}
  (hBucket :
    bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes)
  (hBucketIndex :
    RuntimeOramCodecSemantics.decodeNatField bucket.bucketIndexField =
      expectedBucketIndex)
  (hLiveCount :
    RuntimeOramCodecSemantics.decodeNatField bucket.liveEntryCountField =
      RuntimeOramCodecSemantics.liveBlockCount bucket.blocks) :
  RuntimeOramCodecSemantics.decodeBucketExact?
      isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
      (RuntimeOramCodecSemantics.encodeBucket isPath bucket) =
    some
      { bucketIndex := expectedBucketIndex
      , liveEntryCount := RuntimeOramCodecSemantics.liveBlockCount bucket.blocks
      , blocks := bucket.blocks
      } := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBucketCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBucket hBucketIndex hLiveCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodeBucketExact?
        isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
        bytes = some payload) :
  bytes.length =
      RuntimeOramCodecSemantics.codecBucketBytes
        isPath blocksPerBucket keyBytes valueBytes ∧
    payload.Accepted expectedBucketIndex blocksPerBucket := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBucketDecodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeBlockValidShapes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodeBucketExact?
        isPath blocksPerBucket keyBytes valueBytes expectedBucketIndex
        bytes = some payload) :
  ∀ block, block ∈ payload.blocks →
    block.ValidShape isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.oramExactBucketDecodeBlockValidShapes
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex
    capacity leafCount : Nat}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes = some payload) :
  bytes.length =
      RuntimeOramCodecSemantics.codecBucketBytes
        true blocksPerBucket keyBytes valueBytes ∧
    payload.Accepted expectedBucketIndex blocksPerBucket ∧
    ∀ block, block ∈ payload.blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount := by
  exact
    RuntimePaperNativeKernelAssumptions.pathBucketBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketPathBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex
    capacity leafCount : Nat}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPathBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount bytes = some payload) :
  bytes.length =
      RuntimeOramCodecSemantics.codecBucketBytes
        true blocksPerBucket keyBytes valueBytes ∧
    payload.Accepted expectedBucketIndex blocksPerBucket ∧
    ∀ block, block ∈ payload.blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount ∧
        block.LiveOnBucketPath leafCount expectedBucketIndex := by
  exact
    RuntimePaperNativeKernelAssumptions.pathBucketPathBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketPositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex
    capacity leafCount : Nat}
  {positionMap : List (Option Nat)}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketPositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMap bytes = some payload) :
  bytes.length =
      RuntimeOramCodecSemantics.codecBucketBytes
        true blocksPerBucket keyBytes valueBytes ∧
    payload.Accepted expectedBucketIndex blocksPerBucket ∧
    ∀ block, block ∈ payload.blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount ∧
        block.LiveOnBucketPath leafCount expectedBucketIndex ∧
        block.AgreesWithPositionMap positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.pathBucketPositionMapBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketUniquePositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex
    capacity leafCount : Nat}
  {positionMap : List (Option Nat)}
  {bytes : List Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathBucketUniquePositionMapBoundedExact?
        blocksPerBucket keyBytes valueBytes expectedBucketIndex
        capacity leafCount positionMap bytes = some payload) :
  bytes.length =
      RuntimeOramCodecSemantics.codecBucketBytes
        true blocksPerBucket keyBytes valueBytes ∧
    payload.Accepted expectedBucketIndex blocksPerBucket ∧
    RuntimeOramCodecSemantics.LiveSlotNoDuplicates payload.blocks ∧
    ∀ block, block ∈ payload.blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount ∧
        block.LiveOnBucketPath leafCount expectedBucketIndex ∧
        block.AgreesWithPositionMap positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.pathBucketUniquePositionMapBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLiveSlotCoverage
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {positionMap : List (Option Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPositionMapCoveredByLiveBlocks
        positionMap blocks = true) :
  RuntimeOramCodecSemantics.PositionMapCoveredByLiveBlocks
    positionMap blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapLiveSlotCoverage
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCheck

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBlocksPositionMapAgreement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {positionMap : List (Option Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPathBlocksPositionMapAgreement
        positionMap blocks = true) :
  ∀ block, block ∈ blocks →
    block.AgreesWithPositionMap positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.pathBlocksPositionMapAgreement
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCheck

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBlocksNoDuplicateLiveSlots
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPathBlocksNoDuplicateLiveSlots blocks =
      true) :
  RuntimeOramCodecSemantics.LiveSlotNoDuplicates blocks := by
  exact
    RuntimePaperNativeKernelAssumptions.pathBlocksNoDuplicateLiveSlots
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCheck

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDecodedBucketPayloadAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expectedBucketIndex blocksPerBucket : Nat}
  {payload : RuntimeOramCodecSemantics.DecodedBucketPayload}
  (hIndex : payload.bucketIndex = expectedBucketIndex)
  (hBlocks : payload.blocks.length = blocksPerBucket)
  (hLive :
    RuntimeOramCodecSemantics.liveBlockCount payload.blocks =
      payload.liveEntryCount) :
  payload.Accepted expectedBucketIndex blocksPerBucket := by
  exact
    RuntimePaperNativeKernelAssumptions.oramDecodedBucketPayloadAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hIndex hBlocks hLive

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCoverCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  capacity ≤
    RuntimeOramCodecSemantics.pathPositionMapPages capacity *
      RuntimeOramCodecSemantics.directoryPageEntries := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPagesCoverCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesPositive
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  0 < RuntimeOramCodecSemantics.pathPositionMapPages capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPagesPositive
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      capacity

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathMetadataPageSplit
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {metadataPages capacity : Nat}
  (hPages :
    RuntimeOramCodecSemantics.pathPositionMapPages capacity ≤
      metadataPages) :
  RuntimeOramCodecSemantics.pathPositionMapPages capacity +
      RuntimeOramCodecSemantics.pathStashPages metadataPages capacity =
    metadataPages := by
  exact
    RuntimePaperNativeKernelAssumptions.pathMetadataPageSplit
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hPages

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_positionMapDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap : List (Option Nat)}
  (hCapacity : positionMap.length = capacity)
  (hLeaves :
    RuntimeOramCodecSemantics.PositionMapLeafBounded leafCount positionMap) :
  RuntimeOramCodecSemantics.PositionMapDecodeAccepted
      capacity leafCount positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.positionMapDecodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCapacity hLeaves

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLeafDecodeBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount : Nat}
  {field : List Nat}
  {entry : Option Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodePositionMapLeaf? leafCount field =
      some entry) :
  RuntimeOramCodecSemantics.PositionMapEntryLeafBounded leafCount entry := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapLeafDecodeBounded
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapEntriesDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount count : Nat}
  {bytes : List Nat}
  {entries : List (Option Nat)}
  (hDecode :
    RuntimeOramCodecSemantics.decodePositionMapEntriesExact?
        leafCount count bytes = some entries) :
  entries.length = count ∧
    RuntimeOramCodecSemantics.PositionMapLeafBounded leafCount entries := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapEntriesDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes : Nat}
  {bytes : List Nat}
  {page : RuntimeOramCodecSemantics.DecodedPathPositionMapPage}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathPositionMapPageExact?
        leafCount directoryPageBytes bytes = some page) :
  bytes.length = directoryPageBytes ∧
    page.Accepted leafCount directoryPageBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPageDecodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes : Nat}
  {bytes : List Nat}
  (hLen : bytes.length ≠ directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathPositionMapPageExact?
      leafCount directoryPageBytes bytes = none := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPageRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesAllDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes : Nat}
  {pages : List (List Nat)}
  {entries : List (Option Nat)}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathPositionMapPagesAll?
        leafCount directoryPageBytes pages = some entries) :
  entries.length =
      pages.length * RuntimeOramCodecSemantics.directoryPageEntries ∧
    RuntimeOramCodecSemantics.PositionMapLeafBounded leafCount entries := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPagesAllDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes capacity : Nat}
  {pages : List (List Nat)}
  {positionMap : List (Option Nat)}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathPositionMapPagesExact?
        leafCount directoryPageBytes capacity pages = some positionMap) :
  pages.length = RuntimeOramCodecSemantics.pathPositionMapPages capacity ∧
    RuntimeOramCodecSemantics.PositionMapDecodeAccepted
      capacity leafCount positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPagesDecodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesRejectsPageCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes capacity : Nat}
  {pages : List (List Nat)}
  (hCount :
    pages.length ≠ RuntimeOramCodecSemantics.pathPositionMapPages capacity) :
  RuntimeOramCodecSemantics.decodePathPositionMapPagesExact?
      leafCount directoryPageBytes capacity pages = none := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPagesRejectsPageCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {directoryPageBytes : Nat}
  {positionMapPrefixBytes : List Nat}
  (hLen : positionMapPrefixBytes.length ≤ directoryPageBytes) :
  (RuntimeOramCodecSemantics.encodePathPositionMapPageBytes
      directoryPageBytes positionMapPrefixBytes).length =
    directoryPageBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPageLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes : Nat}
  {fields : List (List Nat)}
  {entries : List (Option Nat)}
  (hFields :
    RuntimeOramCodecSemantics.PositionMapEntryFieldsEncode
      leafCount fields entries)
  (hEntryCount :
    entries.length = RuntimeOramCodecSemantics.directoryPageEntries)
  (hDirectoryBytes :
    RuntimeOramCodecSemantics.pathPositionMapEntryBytes ≤
      directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathPositionMapPageExact?
      leafCount directoryPageBytes
      (RuntimeOramCodecSemantics.encodePathPositionMapPageBytes
        directoryPageBytes
        (RuntimeOramCodecSemantics.encodePositionMapEntryFields fields)) =
    some
      { entries := entries
      , padding :=
          List.replicate
            (directoryPageBytes -
              RuntimeOramCodecSemantics.pathPositionMapEntryBytes) 0
      } := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPageCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hFields hEntryCount hDirectoryBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes capacity : Nat}
  {fieldPages : List (List (List Nat))}
  {entryPages : List (List (Option Nat))}
  (hPages :
    RuntimeOramCodecSemantics.PositionMapPageEntryFieldsEncode
      leafCount fieldPages entryPages)
  (hPageCount :
    entryPages.length =
      RuntimeOramCodecSemantics.pathPositionMapPages capacity)
  (hDirectoryBytes :
    RuntimeOramCodecSemantics.pathPositionMapEntryBytes ≤
      directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathPositionMapPagesExact?
      leafCount directoryPageBytes capacity
      (RuntimeOramCodecSemantics.encodePathPositionMapPagesBytes
        directoryPageBytes fieldPages) =
    some
      ((RuntimeOramCodecSemantics.flattenPositionMapPages entryPages).take
        capacity) := by
  exact
    RuntimePaperNativeKernelAssumptions.pathPositionMapPagesCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hPages hPageCount hDirectoryBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {directoryPageBytes : Nat}
  {stashBlockBytes : List Nat}
  (hLen : stashBlockBytes.length ≤ directoryPageBytes) :
  (RuntimeOramCodecSemantics.encodePathStashPageBytes
      directoryPageBytes stashBlockBytes).length =
    directoryPageBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPageLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyBytes valueBytes directoryPageBytes : Nat}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hBlockCount :
    blocks.length = RuntimeOramCodecSemantics.directoryPageEntries)
  (hBlocks :
    ∀ block, block ∈ blocks →
      block.ValidShape true keyBytes valueBytes)
  (hDirectoryBytes :
    directoryPageBytes =
      RuntimeOramCodecSemantics.directoryPageEntries *
        RuntimeOramCodecSemantics.codecBlockBytes
          true keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodePathStashPageExact?
      true keyBytes valueBytes directoryPageBytes
      (RuntimeOramCodecSemantics.encodePathStashPageBytes
        directoryPageBytes
        (RuntimeOramCodecSemantics.encodeBlocks true blocks)) =
    some { blocks := blocks } := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPageCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hBlockCount hBlocks hDirectoryBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
  {blockPages : List (List RuntimeOramCodecSemantics.CodecBlock)}
  (hPages :
    RuntimeOramCodecSemantics.PathStashPageBlocksValid
      keyBytes valueBytes blockPages)
  (hPageCount : blockPages.length = stashPageCount)
  (hDirectoryBytes :
    directoryPageBytes =
      RuntimeOramCodecSemantics.directoryPageEntries *
        RuntimeOramCodecSemantics.codecBlockBytes true keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodePathStashPagesExact?
      true keyBytes valueBytes directoryPageBytes stashPageCount
      (RuntimeOramCodecSemantics.encodePathStashPagesBytes
        directoryPageBytes blockPages) =
    some (RuntimeOramCodecSemantics.flattenStashPages blockPages) := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesCodecRoundtrip
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hPages hPageCount hDirectoryBytes

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes : Nat}
  {bytes : List Nat}
  {page : RuntimeOramCodecSemantics.DecodedPathStashPage}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPageExact?
        isPath keyBytes valueBytes directoryPageBytes bytes = some page) :
  bytes.length = directoryPageBytes ∧
    page.Accepted RuntimeOramCodecSemantics.directoryPageEntries := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPageDecodeAccepted
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes : Nat}
  {bytes : List Nat}
  (hLen : bytes.length ≠ directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathStashPageExact?
      isPath keyBytes valueBytes directoryPageBytes bytes = none := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPageRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hLen

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeBlockValidShapes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes : Nat}
  {bytes : List Nat}
  {page : RuntimeOramCodecSemantics.DecodedPathStashPage}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPageExact?
        isPath keyBytes valueBytes directoryPageBytes bytes = some page) :
  ∀ block, block ∈ page.blocks →
    block.ValidShape isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPageDecodeBlockValidShapes
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
  {pages : List (List Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPagesExact?
        isPath keyBytes valueBytes directoryPageBytes stashPageCount pages =
      some blocks) :
  pages.length = stashPageCount ∧
    blocks.length =
      stashPageCount * RuntimeOramCodecSemantics.directoryPageEntries ∧
    RuntimeOramCodecSemantics.liveBlockCount blocks ≤
      stashPageCount * RuntimeOramCodecSemantics.directoryPageEntries ∧
    ∀ block, block ∈ blocks →
      block.ValidShape isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesRejectsPageCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
  {pages : List (List Nat)}
  (hCount : pages.length ≠ stashPageCount) :
  RuntimeOramCodecSemantics.decodePathStashPagesExact?
      isPath keyBytes valueBytes directoryPageBytes stashPageCount pages =
    none := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesRejectsPageCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hCount

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesAllDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes : Nat}
  {pages : List (List Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPagesAll?
        isPath keyBytes valueBytes directoryPageBytes pages = some blocks) :
  blocks.length =
      pages.length * RuntimeOramCodecSemantics.directoryPageEntries ∧
    RuntimeOramCodecSemantics.liveBlockCount blocks ≤
      pages.length * RuntimeOramCodecSemantics.directoryPageEntries ∧
    ∀ block, block ∈ blocks →
      block.ValidShape isPath keyBytes valueBytes := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesAllDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyBytes valueBytes directoryPageBytes stashPageCount
    capacity leafCount stashBound : Nat}
  {pages : List (List Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPagesBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound pages = some blocks) :
  pages.length = stashPageCount ∧
    blocks.length =
      stashPageCount * RuntimeOramCodecSemantics.directoryPageEntries ∧
    RuntimeOramCodecSemantics.liveBlockCount blocks ≤ stashBound ∧
    ∀ block, block ∈ blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesPositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyBytes valueBytes directoryPageBytes stashPageCount
    capacity leafCount stashBound : Nat}
  {positionMap : List (Option Nat)}
  {pages : List (List Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPagesPositionMapBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound positionMap pages = some blocks) :
  pages.length = stashPageCount ∧
    blocks.length =
      stashPageCount * RuntimeOramCodecSemantics.directoryPageEntries ∧
    RuntimeOramCodecSemantics.liveBlockCount blocks ≤ stashBound ∧
    ∀ block, block ∈ blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount ∧
        block.AgreesWithPositionMap positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesPositionMapBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesUniquePositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyBytes valueBytes directoryPageBytes stashPageCount
    capacity leafCount stashBound : Nat}
  {positionMap : List (Option Nat)}
  {pages : List (List Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hDecode :
    RuntimeOramCodecSemantics.decodePathStashPagesUniquePositionMapBoundedExact?
        keyBytes valueBytes directoryPageBytes stashPageCount
        capacity leafCount stashBound positionMap pages = some blocks) :
  pages.length = stashPageCount ∧
    blocks.length =
      stashPageCount * RuntimeOramCodecSemantics.directoryPageEntries ∧
    RuntimeOramCodecSemantics.liveBlockCount blocks ≤ stashBound ∧
    RuntimeOramCodecSemantics.LiveSlotNoDuplicates blocks ∧
    ∀ block, block ∈ blocks →
      block.ValidShape true keyBytes valueBytes ∧
        block.LivePathWithinBounds capacity leafCount ∧
        block.AgreesWithPositionMap positionMap := by
  exact
    RuntimePaperNativeKernelAssumptions.pathStashPagesUniquePositionMapBoundedDecodeShape
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)
      hDecode

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_end_to_end_confinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let machineBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  let runtimeBoundary := machineBoundary.runtimeImplementationConfinementBoundary
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => machineBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => machineBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      machineBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      machineBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_end_to_end_confinement_with_public_only_handwritten_shell
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let machineBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  let runtimeBoundary := machineBoundary.runtimeImplementationConfinementBoundary
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => machineBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => machineBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      machineBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      machineBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        machineBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_public_bridge_observer_refinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.paperPublicBridgeObserverRefinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.paperPublicOnlyResidualHelperShellRefinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

theorem
  importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_slot_adapter_machine_refinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationKernelMachineConfinementBoundary.paperSlotAdapterMachineRefinement
      (boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid)

structure ImportedRuntimeImplementationSharedConfidentialKernelBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationSharedConfidentialKernelBoundary.Valid
  (boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary) : Prop :=
  boundary.implementation_interface.SharedConfidentialKernelBoundary

def ImportedRuntimeImplementationSharedConfidentialKernelBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary) : Bool :=
  boundary.implementation_interface.checkSharedConfidentialKernelBoundary

def ImportedRuntimeImplementationSharedConfidentialKernelBoundary.toRuntimeImplementationSharedConfidentialKernelBoundary
  (boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSharedConfidentialKernelBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , sharedBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSharedConfidentialKernelBoundary
        boundary.implementation_interface hValid
  }

@[simp] theorem importedRuntimeImplementationSharedConfidentialKernelBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSharedConfidentialKernelBoundary.checkValid
    ImportedRuntimeImplementationSharedConfidentialKernelBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkSharedConfidentialKernelBoundary_eq_true_iff]

theorem importedRuntimeImplementationSharedConfidentialKernelBoundary_toRuntimeSharedKernelConfinement
  (boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SharedConfidentialKernelBoundary
    (boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationSharedConfidentialKernelBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationSharedConfidentialKernelBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationSharedConfidentialKernelBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationSharedConfidentialKernelBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid)

theorem importedRuntimeImplementationSharedConfidentialKernelBoundary_valid_hostVisibleErrorTaxonomy
  {boundary : ImportedRuntimeImplementationSharedConfidentialKernelBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    RuntimeImplementationSharedConfidentialKernelBoundary.hostVisibleErrorTaxonomy
      (boundary.toRuntimeImplementationSharedConfidentialKernelBoundary hValid)

structure ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_kernel_machine_finish_witness : ImportedRuntimeKernelMachineFinishWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
  opcode_trace : List String
deriving FromJson

def ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  (boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary) :
  ImportedRuntimeKernelMachineFinishBoundary :=
  { runtime_kernel_machine_finish_witness :=
      boundary.runtime_kernel_machine_finish_witness
  , confidential_slot_program := boundary.confidential_slot_program
  , opcode_trace := boundary.opcode_trace
  }

def ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary) : Prop :=
  boundary.implementation_interface.SharedConfidentialKernelBoundary ∧
    boundary.projectedKernelMachineFinishBoundary.Valid

def ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary) : Bool :=
  boundary.implementation_interface.checkSharedConfidentialKernelBoundary &&
    boundary.projectedKernelMachineFinishBoundary.checkValid

@[simp] theorem importedRuntimeImplementationSharedKernelMachineRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.checkValid
    ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.Valid
    ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.projectedKernelMachineFinishBoundary
  simp [importedRuntimeImplementationInterface_checkSharedConfidentialKernelBoundary_eq_true_iff,
    importedRuntimeKernelMachineFinishBoundary_checkValid_eq_true_iff]

noncomputable def
  ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary
  (boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSharedKernelMachineRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelMachineFinishBoundary :=
      boundary.projectedKernelMachineFinishBoundary.toRuntimeKernelMachineFinishBoundary hValid.2
  , sharedBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSharedConfidentialKernelBoundary
        boundary.implementation_interface hValid.1
  }

theorem importedRuntimeImplementationSharedKernelMachineRefinementBoundary_toRuntimeSharedKernelConfinement
  (boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SharedConfidentialKernelBoundary
    (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_machine_finish_schedule_consumed
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
  | some steps =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
  | none =>
      runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0 := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.machineFinishScheduleConsumed
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_machine_finish_kernel_step_budget_respected
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.machineFinishKernelStepBudgetRespected
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_machine_finish_runtime_phase_budget_respected
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
    runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.machineFinishRuntimePhaseBudgetRespected
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_slot_semantics_exact
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
      some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.slotSemanticsExact
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_native_machine_refinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.nativeMachineRefinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paper_slot_adapter_machine_refinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSlotAdapterMachineRefinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.paperPublicOnlyResidualHelperShellRefinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.paperPublicOnlyResidualHelperShellObserverRefinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract ∧
    (match runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps with
      | some steps => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = steps.length
      | none => runtimeBoundary.runtimeKernelMachineFinishBoundary.expectedKernelStepIndex = 0) ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxKernelOps ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.events.length ≤
      runtimeBoundary.runtimeKernelMachineFinishBoundary.maxRuntimePhaseEventCount ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.expectedKernelSteps =
        some runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness.kernelSteps =
        runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confidentialSlotProgram.expectedRuntimeKernelSteps := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSharedKernelMachineRefinementWithPublicOnlyHandwrittenShell
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelMachineRefinementBoundary_valid_paperSharedKernelMachineObserverRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSharedKernelMachineRefinementBoundary.paperSharedKernelMachineObserverRefinement
      (boundary.toRuntimeImplementationSharedKernelMachineRefinementBoundary hValid)

structure ImportedRuntimeImplementationSharedKernelRefinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  runtime_confidential_core_kernel_finish_slot_bundle :
    ImportedRuntimeConfidentialCoreKernelFinishSlotBundle
deriving FromJson

def ImportedRuntimeImplementationSharedKernelRefinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary) : Prop :=
  boundary.implementation_interface.SharedConfidentialKernelBoundary ∧
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.Valid

def ImportedRuntimeImplementationSharedKernelRefinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary) : Bool :=
  boundary.implementation_interface.checkSharedConfidentialKernelBoundary &&
    boundary.runtime_confidential_core_kernel_finish_slot_bundle.checkValid

noncomputable def
  ImportedRuntimeImplementationSharedKernelRefinementBoundary.toRuntimeImplementationSharedKernelRefinementBoundary
  (boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationSharedKernelRefinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , runtimeKernelFinishSlotBoundary :=
      boundary.runtime_confidential_core_kernel_finish_slot_bundle.toRuntimeKernelFinishSlotBoundary
        hValid.2
  , sharedBoundaryValid := by
      exact importedRuntimeImplementationInterface_toRuntimeSharedConfidentialKernelBoundary
        boundary.implementation_interface hValid.1
  }

@[simp] theorem importedRuntimeImplementationSharedKernelRefinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationSharedKernelRefinementBoundary.checkValid
    ImportedRuntimeImplementationSharedKernelRefinementBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkSharedConfidentialKernelBoundary_eq_true_iff,
    importedRuntimeConfidentialCoreKernelFinishSlotBundle_checkValid_eq_true_iff]

theorem importedRuntimeImplementationSharedKernelRefinementBoundary_toRuntimeSharedKernelConfinement
  (boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.SharedConfidentialKernelBoundary
    (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationSharedKernelRefinementBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationSharedKernelRefinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationSharedKernelRefinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationSharedKernelRefinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_projects_to_refinesLeanKernelState
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    RuntimeImplementationSharedKernelRefinementBoundary.projects_to_refinesLeanKernelState
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  let confinementBoundary :=
    runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary
  confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      confinementBoundary.refinementBoundary.kernelWitness ∧
    confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationSharedKernelRefinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_paperSharedKernelRefinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    _root_.UOToolchain.RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelRefinementWithPublicOnlyHandwrittenShell
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

theorem
  importedRuntimeImplementationSharedKernelRefinementBoundary_valid_paperSharedKernelObserverRefinement
  {boundary : ImportedRuntimeImplementationSharedKernelRefinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    _root_.UOToolchain.RuntimeImplementationSharedKernelRefinementBoundary.paperSharedKernelObserverRefinement
      (boundary.toRuntimeImplementationSharedKernelRefinementBoundary hValid)

structure ImportedRuntimeImplementationConfinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  kernel_interface_bundle : ImportedRuntimeKernelInterfaceBundle
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationConfinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationConfinementBoundary) : Prop :=
  boundary.implementation_interface.Valid ∧
    boundary.kernel_interface_bundle.Valid

def ImportedRuntimeImplementationConfinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationConfinementBoundary) : Bool :=
  boundary.implementation_interface.checkValid &&
    boundary.kernel_interface_bundle.checkValid

def ImportedRuntimeImplementationConfinementBoundary.toRuntimeImplementationConfinementBoundary
  (boundary : ImportedRuntimeImplementationConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationConfinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , kernelInterfaceBundle :=
      boundary.kernel_interface_bundle.toRuntimeKernelInterfaceBundle
  , implementationValid := by
      exact importedRuntimeImplementationInterface_toRuntimeValid
        boundary.implementation_interface hValid.1
  , kernelInterfaceValid := by
      exact importedRuntimeKernelInterfaceBundle_toRuntimeValid
        boundary.kernel_interface_bundle hValid.2
  }

@[simp] theorem importedRuntimeImplementationConfinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationConfinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationConfinementBoundary.checkValid
    ImportedRuntimeImplementationConfinementBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkValid_eq_true_iff,
    importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff]

theorem importedRuntimeImplementationConfinementBoundary_toRuntimeImplementationConfinement
  (boundary : ImportedRuntimeImplementationConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ConfinesSecretDependentWork
    (boundary.toRuntimeImplementationConfinementBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationConfinementBoundary.implementationConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_sharedKernelConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.sharedKernelConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_smallKernelConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.smallKernelConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_residualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.residualHelperShellConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_slotAdapterConfinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    RuntimeImplementationConfinementBoundary.slotAdapterConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_handwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    RuntimeImplementationConfinementBoundary.handwrittenRuntimePublicOnly
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationConfinementBoundary_valid_paperEndToEndConfinementWithPublicOnlyHandwrittenShell
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem
  importedRuntimeImplementationConfinementBoundary_valid_paperPublicBridgeObserverRefinement
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfinementBoundary.paperPublicBridgeObserverRefinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

def parseImportedRuntimeImplementationInterface
  (input : String) : Except String ImportedRuntimeImplementationInterface := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationInterface
  (input : String) : Except String ImportedRuntimeImplementationInterface := do
  let iface ← parseImportedRuntimeImplementationInterface input
  if iface.checkValid then
    pure iface
  else
    throw "imported runtime implementation interface does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationInterface
  (path : System.FilePath) : IO ImportedRuntimeImplementationInterface := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationInterface input with
  | .ok iface => pure iface
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation interface: {err}"

def loadAndCheckImportedRuntimeImplementationInterface
  (path : System.FilePath) : IO ImportedRuntimeImplementationInterface := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationInterface input with
  | .ok iface => pure iface
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation interface: {err}"

def parseImportedRuntimeImplementationSmallConfidentialKernelBoundary
  (input : String) : Except String ImportedRuntimeImplementationSmallConfidentialKernelBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationSmallConfidentialKernelBoundary
  (input : String) : Except String ImportedRuntimeImplementationSmallConfidentialKernelBoundary := do
  let boundary ← parseImportedRuntimeImplementationSmallConfidentialKernelBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime small confidential-kernel boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationSmallConfidentialKernelBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSmallConfidentialKernelBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSmallConfidentialKernelBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime small confidential-kernel boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSmallConfidentialKernelBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSmallConfidentialKernelBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSmallConfidentialKernelBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime small confidential-kernel boundary: {err}"

def parseImportedRuntimeImplementationPublicBridgeBoundary
  (input : String) : Except String ImportedRuntimeImplementationPublicBridgeBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseImportedRuntimeImplementationSlotAdapterBoundary
  (input : String) : Except String ImportedRuntimeImplementationSlotAdapterBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationPublicBridgeBoundary
  (input : String) : Except String ImportedRuntimeImplementationPublicBridgeBoundary := do
  let boundary ← parseImportedRuntimeImplementationPublicBridgeBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime public bridge boundary does not satisfy Lean validity checks"

def parseAndCheckImportedRuntimeImplementationSlotAdapterBoundary
  (input : String) : Except String ImportedRuntimeImplementationSlotAdapterBoundary := do
  let boundary ← parseImportedRuntimeImplementationSlotAdapterBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime slot-adapter boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationPublicBridgeBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationPublicBridgeBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationPublicBridgeBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime public bridge boundary: {err}"

def loadAndCheckImportedRuntimeImplementationPublicBridgeBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationPublicBridgeBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationPublicBridgeBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime public bridge boundary: {err}"

def loadImportedRuntimeImplementationSlotAdapterBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSlotAdapterBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSlotAdapterBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime slot-adapter boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSlotAdapterBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSlotAdapterBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSlotAdapterBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime slot-adapter boundary: {err}"

def parseImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime implementation public bridge observer-refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation public bridge observer-refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationPublicBridgeObserverRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation public bridge observer-refinement boundary: {err}"

def parseImportedRuntimeImplementationResidualHelperShellBoundary
  (input : String) : Except String ImportedRuntimeImplementationResidualHelperShellBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationResidualHelperShellBoundary
  (input : String) : Except String ImportedRuntimeImplementationResidualHelperShellBoundary := do
  let boundary ← parseImportedRuntimeImplementationResidualHelperShellBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime residual helper-shell boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationResidualHelperShellBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationResidualHelperShellBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationResidualHelperShellBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime residual helper-shell boundary: {err}"

def loadAndCheckImportedRuntimeImplementationResidualHelperShellBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationResidualHelperShellBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationResidualHelperShellBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime residual helper-shell boundary: {err}"

def parseImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary := do
  let boundary ←
    parseImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation residual helper-shell machine refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation residual helper-shell machine refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationResidualHelperShellMachineRefinementBoundary
      input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation residual helper-shell machine refinement boundary: {err}"

def parseImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary
  (input : String) : Except String ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary := do
  let boundary ← parseImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime confidential statement-trace bridge boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential statement-trace bridge boundary: {err}"

def loadAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime confidential statement-trace bridge boundary: {err}"

def parseImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary := do
  let boundary ←
    parseImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation small confidential-kernel machine refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation small confidential-kernel machine refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSmallConfidentialKernelMachineRefinementBoundary
      input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation small confidential-kernel machine refinement boundary: {err}"

def parseImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary := do
  let boundary ←
    parseImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation slot-adapter machine refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation slot-adapter machine refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSlotAdapterMachineRefinementBoundary
      input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation slot-adapter machine refinement boundary: {err}"

def parseImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary := do
  let boundary ←
    parseImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation confidential statement-trace bridge refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation confidential statement-trace bridge refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationConfidentialStatementTraceBridgeRefinementBoundary
      input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation confidential statement-trace bridge refinement boundary: {err}"

def parseImportedRuntimeImplementationKernelMeetingBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationKernelMeetingBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationKernelMeetingBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationKernelMeetingBoundary := do
  let boundary ← parseImportedRuntimeImplementationKernelMeetingBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime implementation kernel meeting boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationKernelMeetingBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationKernelMeetingBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationKernelMeetingBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation kernel meeting boundary: {err}"

def loadAndCheckImportedRuntimeImplementationKernelMeetingBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationKernelMeetingBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationKernelMeetingBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation kernel meeting boundary: {err}"

def parseImportedRuntimeImplementationKernelMeetingConfinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationKernelMeetingConfinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationKernelMeetingConfinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationKernelMeetingConfinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationKernelMeetingConfinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation kernel meeting confinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationKernelMeetingConfinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationKernelMeetingConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationKernelMeetingConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation kernel meeting confinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationKernelMeetingConfinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationKernelMeetingConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationKernelMeetingConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation kernel meeting confinement boundary: {err}"

def parseImportedRuntimeImplementationKernelMachineConfinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationKernelMachineConfinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationKernelMachineConfinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationKernelMachineConfinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationKernelMachineConfinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation kernel machine confinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationKernelMachineConfinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationKernelMachineConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationKernelMachineConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation kernel machine confinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationKernelMachineConfinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationKernelMachineConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationKernelMachineConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation kernel machine confinement boundary: {err}"

def parseImportedRuntimeImplementationSharedConfidentialKernelBoundary
  (input : String) : Except String ImportedRuntimeImplementationSharedConfidentialKernelBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationSharedConfidentialKernelBoundary
  (input : String) : Except String ImportedRuntimeImplementationSharedConfidentialKernelBoundary := do
  let boundary ← parseImportedRuntimeImplementationSharedConfidentialKernelBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime shared confidential-kernel boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationSharedConfidentialKernelBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSharedConfidentialKernelBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSharedConfidentialKernelBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime shared confidential-kernel boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSharedConfidentialKernelBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSharedConfidentialKernelBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSharedConfidentialKernelBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime shared confidential-kernel boundary: {err}"

def parseImportedRuntimeImplementationSharedKernelMachineRefinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationSharedKernelMachineRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationSharedKernelMachineRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw
      "imported runtime implementation shared-kernel machine refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationSharedKernelMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSharedKernelMachineRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation shared-kernel machine refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSharedKernelMachineRefinementBoundary
  (path : System.FilePath) :
  IO ImportedRuntimeImplementationSharedKernelMachineRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSharedKernelMachineRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation shared-kernel machine refinement boundary: {err}"

def parseImportedRuntimeImplementationSharedKernelRefinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationSharedKernelRefinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationSharedKernelRefinementBoundary
  (input : String) :
  Except String ImportedRuntimeImplementationSharedKernelRefinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationSharedKernelRefinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime implementation shared-kernel refinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationSharedKernelRefinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSharedKernelRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationSharedKernelRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation shared-kernel refinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationSharedKernelRefinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationSharedKernelRefinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationSharedKernelRefinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation shared-kernel refinement boundary: {err}"

def parseImportedRuntimeImplementationConfinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationConfinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationConfinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationConfinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationConfinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime implementation confinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationConfinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation confinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationConfinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation confinement boundary: {err}"

end UOToolchain
