import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationInterface <interface.json>"

theorem importedInterfaceHandwrittenRuntimePublicOnly
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationInterface_valid_handwrittenRuntimePublicOnly hValid

theorem importedInterfaceShellRejectsConfidentialExpressionEvaluation
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.shellRejectsConfidentialExpressionEvaluation := by
  exact
    importedRuntimeImplementationInterface_valid_shellRejectsConfidentialExpressionEvaluation
      hValid

theorem importedInterfaceShellCanonicalHashingGuardedByPublicEntry
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.shellCanonicalHashingGuardedByPublicEntry := by
  exact
    importedRuntimeImplementationInterface_valid_shellCanonicalHashingGuardedByPublicEntry
      hValid

theorem importedInterfaceHandwrittenRuntimeLacksDirectSecretOps
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.handwrittenRuntimeLacksDirectSecretOps := by
  exact
    importedRuntimeImplementationInterface_valid_handwrittenRuntimeLacksDirectSecretOps hValid

theorem importedInterfaceHostCoordinationLacksSecretSerialization
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.handwrittenHostCoordinationLacksSecretSerialization := by
  exact
    importedRuntimeImplementationInterface_valid_hostCoordinationLacksSecretSerialization
      hValid

theorem importedInterfaceHostVisibleErrorTaxonomy
  {iface : ImportedRuntimeImplementationInterface}
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    importedRuntimeImplementationInterface_valid_hostVisibleErrorTaxonomy hValid

def printCheck (name : String) (value : Bool) : IO Unit :=
  IO.eprintln s!"{name}={value}"

def printFailureSummary (iface : ImportedRuntimeImplementationInterface) : IO Unit := do
  let rt := iface.toRuntimeImplementationInterface
  printCheck "checkPublicBridgeBoundary" rt.checkPublicBridgeBoundary
  printCheck "checkRuntimeOwnsBridgeModules" rt.checkRuntimeOwnsBridgeModules
  printCheck "checkEngineDelegatesToRuntimeBridge" rt.checkEngineDelegatesToRuntimeBridge
  printCheck "checkShellStaysPublicOnly" rt.checkShellStaysPublicOnly
  printCheck "checkShellRejectsConfidentialExpressionEvaluation"
    rt.checkShellRejectsConfidentialExpressionEvaluation
  printCheck "checkShellCanonicalHashingGuardedByPublicEntry"
    rt.checkShellCanonicalHashingGuardedByPublicEntry
  printCheck "checkStateStagesConfidentialCallsInsideRuntime"
    rt.checkStateStagesConfidentialCallsInsideRuntime
  printCheck "checkTheoremFinalizerUsesSharedTraceBridge"
    rt.checkTheoremFinalizerUsesSharedTraceBridge
  printCheck "checkResidualHelperShellBoundary" rt.checkResidualHelperShellBoundary
  printCheck "checkGeneratedObjectHelpersMatchLeanGenerator"
    rt.checkGeneratedObjectHelpersMatchLeanGenerator
  printCheck "checkGeneratedOramCodecsMatchLeanGenerator"
    rt.checkGeneratedOramCodecsMatchLeanGenerator
  printCheck "checkGeneratedStoreCodecMatchLeanGenerator"
    rt.checkGeneratedStoreCodecMatchLeanGenerator
  printCheck "checkGeneratedStoreSurfaceMatchLeanGenerator"
    rt.checkGeneratedStoreSurfaceMatchLeanGenerator
  printCheck "checkGeneratedStoreHelpersMatchLeanGenerator"
    rt.checkGeneratedStoreHelpersMatchLeanGenerator
  printCheck "checkRuntimeHostVisibleErrorsUsePublicIntegrityTaxonomy"
    rt.checkRuntimeHostVisibleErrorsUsePublicIntegrityTaxonomy
  printCheck "checkRuntimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers"
    rt.checkRuntimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers
  printCheck "checkHandwrittenRuntimeLacksDirectSecretOps"
    rt.checkHandwrittenRuntimeLacksDirectSecretOps
  printCheck "checkHandwrittenHostCoordinationLacksSecretSerialization"
    rt.checkHandwrittenHostCoordinationLacksSecretSerialization
  printCheck "checkRuntimeObjectResetUsesLeanGeneratedHelpers"
    rt.checkRuntimeObjectResetUsesLeanGeneratedHelpers
  printCheck "checkRuntimeObjectCommitUsesLeanGeneratedHelpers"
    rt.checkRuntimeObjectCommitUsesLeanGeneratedHelpers
  printCheck "checkRuntimeObjectCommitUsesPublicSealAndWriteShell"
    rt.checkRuntimeObjectCommitUsesPublicSealAndWriteShell
  printCheck "checkRuntimeObjectOpenUsesSharedDecodeShell"
    rt.checkRuntimeObjectOpenUsesSharedDecodeShell
  printCheck "checkRuntimeObjectBootstrapUsesSharedBoxedSealHelper"
    rt.checkRuntimeObjectBootstrapUsesSharedBoxedSealHelper
  printCheck "checkRuntimeOramUsesLeanGeneratedBlockBucketCodecs"
    rt.checkRuntimeOramUsesLeanGeneratedBlockBucketCodecs
  printCheck "checkRuntimeOramCommitKeepsRestoreAndExactWriteBatchSplit"
    rt.checkRuntimeOramCommitKeepsRestoreAndExactWriteBatchSplit
  printCheck "checkRuntimeOramOpenUsesSharedDecodeShell"
    rt.checkRuntimeOramOpenUsesSharedDecodeShell
  printCheck "checkRuntimeOramBootstrapUsesSharedBoxedSealHelper"
    rt.checkRuntimeOramBootstrapUsesSharedBoxedSealHelper
  printCheck "checkRuntimeOramBootstrapUsesSharedBoxedFillerHelper"
    rt.checkRuntimeOramBootstrapUsesSharedBoxedFillerHelper
  printCheck "checkStoreCipherKeyZeroizesOnDrop"
    rt.checkStoreCipherKeyZeroizesOnDrop
  printCheck "checkStoreCipherUsesExactSizeNonzeroBuffers"
    rt.checkStoreCipherUsesExactSizeNonzeroBuffers
  printCheck "checkStoreWriteApiUsesMutablePlaintext"
    rt.checkStoreWriteApiUsesMutablePlaintext
  printCheck "checkStoreCipherSurfaceStaysInCodec"
    rt.checkStoreCipherSurfaceStaysInCodec
  printCheck "checkRuntimeStoreUsesSharedBoxedFillerHelper"
    rt.checkRuntimeStoreUsesSharedBoxedFillerHelper
  printCheck "checkRuntimeStoreUsesSharedSealIntoHelper"
    rt.checkRuntimeStoreUsesSharedSealIntoHelper
  printCheck "checkRuntimeStoreUsesGeneratedRawBoxedSlotHelpers"
    rt.checkRuntimeStoreUsesGeneratedRawBoxedSlotHelpers
  printCheck "checkRuntimeStoreUoWritesEmitPublicUpdateShape"
    rt.checkRuntimeStoreUoWritesEmitPublicUpdateShape
  printCheck "checkStoreLibrarySurfaceKeepsGeneratedHelpersPrivate"
    rt.checkStoreLibrarySurfaceKeepsGeneratedHelpersPrivate
  printCheck "checkHandwrittenRuntimeProductionAvoidsPanicStyleControlFlow"
    rt.checkHandwrittenRuntimeProductionAvoidsPanicStyleControlFlow
  printCheck "checkRuntimeInterfaceProductionAvoidsPanicStyleControlFlow"
    rt.checkRuntimeInterfaceProductionAvoidsPanicStyleControlFlow
  printCheck "checkSmallConfidentialKernelBoundary" rt.checkSmallConfidentialKernelBoundary
  printCheck "checkKernelDelegatesToSharedBoundaryObjects"
    rt.checkKernelDelegatesToSharedBoundaryObjects
  printCheck "checkKernelDelegatesToSharedConfidentialInterpreter"
    rt.checkKernelDelegatesToSharedConfidentialInterpreter
  printCheck "checkSharedRuntimeKernelUsesBoundedScratchAndFinishDiscipline"
    rt.checkSharedRuntimeKernelUsesBoundedScratchAndFinishDiscipline
  printCheck "checkPrecompilesDefineLeanUoOpcodeVocabulary"
    rt.checkPrecompilesDefineLeanUoOpcodeVocabulary
  printCheck "checkAllocatorSessionEnforcesScratchAndWipeDiscipline"
    rt.checkAllocatorSessionEnforcesScratchAndWipeDiscipline
  printCheck "checkRuntimeAllocatorTelemetryUsesModeledBoxedResourceEvents"
    rt.checkRuntimeAllocatorTelemetryUsesModeledBoxedResourceEvents
  printCheck "checkRuntimeKernelMachineEffectsFollowPublicOpcodeAndScratchSchedule"
    rt.checkRuntimeKernelMachineEffectsFollowPublicOpcodeAndScratchSchedule
  printCheck "checkSharedConfidentialInterpreterUsesFixedBuffers"
    rt.checkSharedConfidentialInterpreterUsesFixedBuffers
  printCheck "checkSharedConfidentialInterpreterUsesMaskedSelectionAndAbort"
    rt.checkSharedConfidentialInterpreterUsesMaskedSelectionAndAbort
  printCheck "checkSharedConfidentialObjectsUseMaskedCellAndArrayUpdates"
    rt.checkSharedConfidentialObjectsUseMaskedCellAndArrayUpdates
  printCheck "checkSharedConfidentialArrayAccessUsesMaskedFullScans"
    rt.checkSharedConfidentialArrayAccessUsesMaskedFullScans
  printCheck "checkSharedConfidentialSmallMapUsesMaskedFullScanUpdates"
    rt.checkSharedConfidentialSmallMapUsesMaskedFullScanUpdates
  printCheck "checkSharedConfidentialSmallMapUsesMaskedFullScanLookup"
    rt.checkSharedConfidentialSmallMapUsesMaskedFullScanLookup
  printCheck "checkSurrogateOramPutUsesMaskedFullScanStateUpdates"
    rt.checkSurrogateOramPutUsesMaskedFullScanStateUpdates
  printCheck "checkPathOramSelectionUsesMaskedFullScans"
    rt.checkPathOramSelectionUsesMaskedFullScans
  printCheck "checkPathOramGetUsesMaskedLookupAndTransitionSelection"
    rt.checkPathOramGetUsesMaskedLookupAndTransitionSelection
  printCheck "checkPathOramPutUsesMaskedFullScanStateUpdates"
    rt.checkPathOramPutUsesMaskedFullScanStateUpdates
  printCheck "checkPathOramStashRebuildUsesFixedCapacitySelection"
    rt.checkPathOramStashRebuildUsesFixedCapacitySelection
  printCheck "checkPathOramFreshCoinPlanKeepsOpaqueBoxedEntryTapes"
    rt.checkPathOramFreshCoinPlanKeepsOpaqueBoxedEntryTapes
  printCheck "checkPathOramUsesTransitionShapedFreshLeafSchedule"
    rt.checkPathOramUsesTransitionShapedFreshLeafSchedule
  printCheck "checkPathOramWriteLogsUsePublicExactBatches"
    rt.checkPathOramWriteLogsUsePublicExactBatches
  printCheck "checkSharedConfidentialKernelConsumesLeanGeneratedProfiles"
    rt.checkSharedConfidentialKernelConsumesLeanGeneratedProfiles
  printCheck "checkSharedConfidentialKernelConsumesLeanGeneratedInterpreter"
    rt.checkSharedConfidentialKernelConsumesLeanGeneratedInterpreter
  printCheck "checkSharedConfidentialInterpreterCentralizesStatementProfiles"
    rt.checkSharedConfidentialInterpreterCentralizesStatementProfiles
  printCheck "checkSharedConfidentialInterpreterCentralizesExprProfiles"
    rt.checkSharedConfidentialInterpreterCentralizesExprProfiles
  printCheck "checkSharedConfidentialInterpreterCentralizesPureExprProfiles"
    rt.checkSharedConfidentialInterpreterCentralizesPureExprProfiles
  printCheck "checkSharedConfidentialInterpreterCentralizesSlotExprProfiles"
    rt.checkSharedConfidentialInterpreterCentralizesSlotExprProfiles
  printCheck "checkSharedConfidentialInterpreterCentralizesSlotPureExprProfiles"
    rt.checkSharedConfidentialInterpreterCentralizesSlotPureExprProfiles
  printCheck "checkSharedConfidentialKernelKeepsNamedToSlotLoweringExplicit"
    rt.checkSharedConfidentialKernelKeepsNamedToSlotLoweringExplicit
  printCheck "checkSharedConfidentialInterpreterKeepsSlotEvaluationOrderExplicit"
    rt.checkSharedConfidentialInterpreterKeepsSlotEvaluationOrderExplicit
  printCheck "checkSharedConfidentialInterpreterKeepsSlotStatementEvaluationOrderExplicit"
    rt.checkSharedConfidentialInterpreterKeepsSlotStatementEvaluationOrderExplicit
  printCheck "checkRuntimeShadowStateUsesFixedSortedCommitTable"
    rt.checkRuntimeShadowStateUsesFixedSortedCommitTable
  printCheck "checkRuntimeKernelSlotSupportRefinesLeanStagingModel"
    rt.checkRuntimeKernelSlotSupportRefinesLeanStagingModel
  printCheck "checkRuntimeKernelAdapterOnlyForwardsGeneratedSlotsAndEffects"
    rt.checkRuntimeKernelAdapterOnlyForwardsGeneratedSlotsAndEffects
  printCheck "checkConfidentialStatementTraceBridgeBoundary"
    rt.checkConfidentialStatementTraceBridgeBoundary
  printCheck "checkStatementTraceBridgeIsExact" rt.checkStatementTraceBridgeIsExact
  printCheck "checkSharedConfidentialKernelBoundary"
    rt.checkSharedConfidentialKernelBoundary
  printCheck "checkValid" rt.checkValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let input ← IO.FS.readFile path
      match parseImportedRuntimeImplementationInterface input with
      | .error err =>
          IO.eprintln s!"failed to parse runtime implementation interface: {err}"
          pure 1
      | .ok iface =>
          if iface.checkValid then
            IO.println
              s!"validated runtime implementation interface for source-backed uo-evm boundary ({iface.engine_source.length} engine bytes)"
            pure 0
          else
            IO.eprintln
              "failed to validate runtime implementation interface: imported runtime implementation interface does not satisfy Lean validity checks"
            printFailureSummary iface
            pure 1
  | _ =>
      IO.eprintln usage
      pure 1
