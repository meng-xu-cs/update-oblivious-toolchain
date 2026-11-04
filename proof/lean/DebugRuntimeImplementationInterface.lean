import Lean.Data.Json
import UOToolchain.RuntimeImplementationInterfaceJson

open Lean
open UOToolchain

def printCheck (name : String) (value : Bool) : IO Unit :=
  IO.println s!"{name}={value}"

def usage : String :=
  "usage: lake env lean --run DebugRuntimeImplementationInterface.lean <interface.json>"

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let contents <- IO.FS.readFile path
      let json <- match Json.parse contents with
        | Except.ok value => pure value
        | Except.error err =>
            IO.eprintln s!"failed to parse JSON: {err}"
            return (1 : UInt32)
      let imported : ImportedRuntimeImplementationInterface ← match fromJson? json with
        | Except.ok iface => pure iface
        | Except.error err =>
            IO.eprintln s!"failed to decode interface JSON: {err}"
            return (1 : UInt32)
      let iface := ImportedRuntimeImplementationInterface.toRuntimeImplementationInterface imported
      printCheck "checkValid"
        (RuntimeImplementationInterface.checkValid iface)
      printCheck "checkPublicBridgeBoundary"
        (RuntimeImplementationInterface.checkPublicBridgeBoundary iface)
      printCheck "checkSharedConfidentialKernelBoundary"
        (RuntimeImplementationInterface.checkSharedConfidentialKernelBoundary iface)
      printCheck "checkConfidentialStatementTraceBridgeBoundary"
        (RuntimeImplementationInterface.checkConfidentialStatementTraceBridgeBoundary iface)
      printCheck "checkResidualHelperShellBoundary"
        (RuntimeImplementationInterface.checkResidualHelperShellBoundary iface)
      printCheck "checkGeneratedKernelMachineMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedKernelMachineMatchLeanGenerator iface)
      printCheck "checkGeneratedKernelSlotSupportMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedKernelSlotSupportMatchLeanGenerator iface)
      printCheck "checkGeneratedConfidentialKernelMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedConfidentialKernelMatchLeanGenerator iface)
      printCheck "checkGeneratedObjectHelpersMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedObjectHelpersMatchLeanGenerator iface)
      printCheck "checkGeneratedOramCodecsMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedOramCodecsMatchLeanGenerator iface)
      printCheck "checkGeneratedStoreCodecMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedStoreCodecMatchLeanGenerator iface)
      printCheck "checkGeneratedStoreSurfaceMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedStoreSurfaceMatchLeanGenerator iface)
      printCheck "checkGeneratedStoreHelpersMatchLeanGenerator"
        (RuntimeImplementationInterface.checkGeneratedStoreHelpersMatchLeanGenerator iface)
      printCheck "checkRuntimeObjectCommitUsesLeanGeneratedHelpers"
        (RuntimeImplementationInterface.checkRuntimeObjectCommitUsesLeanGeneratedHelpers iface)
      printCheck "checkRuntimeObjectCommitUsesPublicSealAndWriteShell"
        (RuntimeImplementationInterface.checkRuntimeObjectCommitUsesPublicSealAndWriteShell iface)
      printCheck "checkRuntimeObjectOpenUsesSharedDecodeShell"
        (RuntimeImplementationInterface.checkRuntimeObjectOpenUsesSharedDecodeShell iface)
      printCheck "checkRuntimeObjectBootstrapUsesSharedBoxedSealHelper"
        (RuntimeImplementationInterface.checkRuntimeObjectBootstrapUsesSharedBoxedSealHelper iface)
      printCheck "checkRuntimeOramUsesLeanGeneratedBlockBucketCodecs"
        (RuntimeImplementationInterface.checkRuntimeOramUsesLeanGeneratedBlockBucketCodecs iface)
      printCheck "checkRuntimeOramCommitAppliesPendingWritesAndExactWriteBatchSplit"
        (RuntimeImplementationInterface.checkRuntimeOramCommitAppliesPendingWritesAndExactWriteBatchSplit iface)
      printCheck "checkRuntimeOramOpenUsesSharedDecodeShell"
        (RuntimeImplementationInterface.checkRuntimeOramOpenUsesSharedDecodeShell iface)
      printCheck "checkRuntimeOramBootstrapUsesSharedBoxedSealHelper"
        (RuntimeImplementationInterface.checkRuntimeOramBootstrapUsesSharedBoxedSealHelper iface)
      printCheck "checkRuntimeOramBootstrapUsesSharedBoxedFillerHelper"
        (RuntimeImplementationInterface.checkRuntimeOramBootstrapUsesSharedBoxedFillerHelper iface)
      printCheck "checkStoreCipherKeyZeroizesOnDrop"
        (RuntimeImplementationInterface.checkStoreCipherKeyZeroizesOnDrop iface)
      printCheck "checkStoreCipherUsesExactSizeNonzeroBuffers"
        (RuntimeImplementationInterface.checkStoreCipherUsesExactSizeNonzeroBuffers iface)
      printCheck "checkStoreWriteApiUsesMutablePlaintext"
        (RuntimeImplementationInterface.checkStoreWriteApiUsesMutablePlaintext iface)
      printCheck "checkStoreCipherSurfaceStaysInCodec"
        (RuntimeImplementationInterface.checkStoreCipherSurfaceStaysInCodec iface)
      printCheck "checkRuntimeStoreUsesSharedBoxedFillerHelper"
        (RuntimeImplementationInterface.checkRuntimeStoreUsesSharedBoxedFillerHelper iface)
      printCheck "checkRuntimeStoreUsesSharedSealIntoHelper"
        (RuntimeImplementationInterface.checkRuntimeStoreUsesSharedSealIntoHelper iface)
      printCheck "checkRuntimeStoreUsesGeneratedRawBoxedSlotHelpers"
        (RuntimeImplementationInterface.checkRuntimeStoreUsesGeneratedRawBoxedSlotHelpers iface)
      printCheck "checkRuntimeStoreUoWritesEmitPublicUpdateShape"
        (RuntimeImplementationInterface.checkRuntimeStoreUoWritesEmitPublicUpdateShape iface)
      printCheck "checkRuntimeShadowStateUsesFixedSortedCommitTable"
        (RuntimeImplementationInterface.checkRuntimeShadowStateUsesFixedSortedCommitTable iface)
      printCheck "checkKernelDelegatesToSharedBoundaryObjects"
        (RuntimeImplementationInterface.checkKernelDelegatesToSharedBoundaryObjects iface)
      printCheck "checkKernelDelegatesToSharedConfidentialInterpreter"
        (RuntimeImplementationInterface.checkKernelDelegatesToSharedConfidentialInterpreter iface)
      printCheck "checkSharedRuntimeKernelUsesBoundedScratchAndFinishDiscipline"
        (RuntimeImplementationInterface.checkSharedRuntimeKernelUsesBoundedScratchAndFinishDiscipline iface)
      printCheck "checkPrecompilesDefineLeanUoOpcodeVocabulary"
        (RuntimeImplementationInterface.checkPrecompilesDefineLeanUoOpcodeVocabulary iface)
      printCheck "checkAllocatorSessionEnforcesScratchAndWipeDiscipline"
        (RuntimeImplementationInterface.checkAllocatorSessionEnforcesScratchAndWipeDiscipline iface)
      printCheck "checkRuntimeAllocatorTelemetryUsesModeledBoxedResourceEvents"
        (RuntimeImplementationInterface.checkRuntimeAllocatorTelemetryUsesModeledBoxedResourceEvents iface)
      printCheck "checkRuntimeKernelMachineEffectsFollowPublicOpcodeAndScratchSchedule"
        (RuntimeImplementationInterface.checkRuntimeKernelMachineEffectsFollowPublicOpcodeAndScratchSchedule iface)
      printCheck "checkSharedConfidentialInterpreterUsesFixedBuffers"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterUsesFixedBuffers iface)
      printCheck "checkSharedConfidentialInterpreterUsesMaskedSelectionAndAbort"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterUsesMaskedSelectionAndAbort iface)
      printCheck "checkSharedConfidentialObjectsUseMaskedCellAndArrayUpdates"
        (RuntimeImplementationInterface.checkSharedConfidentialObjectsUseMaskedCellAndArrayUpdates iface)
      printCheck "checkSharedConfidentialArrayAccessUsesMaskedFullScans"
        (RuntimeImplementationInterface.checkSharedConfidentialArrayAccessUsesMaskedFullScans iface)
      printCheck "checkSharedConfidentialSmallMapUsesMaskedFullScanUpdates"
        (RuntimeImplementationInterface.checkSharedConfidentialSmallMapUsesMaskedFullScanUpdates iface)
      printCheck "checkSharedConfidentialSmallMapUsesMaskedFullScanLookup"
        (RuntimeImplementationInterface.checkSharedConfidentialSmallMapUsesMaskedFullScanLookup iface)
      printCheck "checkSurrogateOramPutUsesMaskedFullScanStateUpdates"
        (RuntimeImplementationInterface.checkSurrogateOramPutUsesMaskedFullScanStateUpdates iface)
      printCheck "checkPathOramSelectionUsesMaskedFullScans"
        (RuntimeImplementationInterface.checkPathOramSelectionUsesMaskedFullScans iface)
      printCheck "checkPathOramGetUsesMaskedLookupAndTransitionSelection"
        (RuntimeImplementationInterface.checkPathOramGetUsesMaskedLookupAndTransitionSelection iface)
      printCheck "checkPathOramPutUsesMaskedFullScanStateUpdates"
        (RuntimeImplementationInterface.checkPathOramPutUsesMaskedFullScanStateUpdates iface)
      printCheck "checkPathOramStashRebuildUsesFixedCapacitySelection"
        (RuntimeImplementationInterface.checkPathOramStashRebuildUsesFixedCapacitySelection iface)
      printCheck "checkPathOramFreshCoinPlanKeepsOpaqueBoxedEntryTapes"
        (RuntimeImplementationInterface.checkPathOramFreshCoinPlanKeepsOpaqueBoxedEntryTapes iface)
      printCheck "checkPathOramUsesTransitionShapedFreshLeafSchedule"
        (RuntimeImplementationInterface.checkPathOramUsesTransitionShapedFreshLeafSchedule iface)
      printCheck "checkPathOramWriteLogsUsePublicExactBatches"
        (RuntimeImplementationInterface.checkPathOramWriteLogsUsePublicExactBatches iface)
      printCheck "checkSharedConfidentialKernelConsumesLeanGeneratedProfiles"
        (RuntimeImplementationInterface.checkSharedConfidentialKernelConsumesLeanGeneratedProfiles iface)
      printCheck "checkSharedConfidentialKernelConsumesLeanGeneratedInterpreter"
        (RuntimeImplementationInterface.checkSharedConfidentialKernelConsumesLeanGeneratedInterpreter iface)
      printCheck "checkSharedConfidentialInterpreterCentralizesStatementProfiles"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterCentralizesStatementProfiles iface)
      printCheck "checkSharedConfidentialInterpreterCentralizesExprProfiles"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterCentralizesExprProfiles iface)
      printCheck "checkSharedConfidentialInterpreterCentralizesPureExprProfiles"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterCentralizesPureExprProfiles iface)
      printCheck "checkSharedConfidentialInterpreterCentralizesSlotExprProfiles"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterCentralizesSlotExprProfiles iface)
      printCheck "checkSharedConfidentialInterpreterCentralizesSlotPureExprProfiles"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterCentralizesSlotPureExprProfiles iface)
      printCheck "checkSharedConfidentialKernelKeepsNamedToSlotLoweringExplicit"
        (RuntimeImplementationInterface.checkSharedConfidentialKernelKeepsNamedToSlotLoweringExplicit iface)
      printCheck "checkSharedConfidentialInterpreterKeepsSlotEvaluationOrderExplicit"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterKeepsSlotEvaluationOrderExplicit iface)
      printCheck "checkSharedConfidentialInterpreterKeepsSlotStatementEvaluationOrderExplicit"
        (RuntimeImplementationInterface.checkSharedConfidentialInterpreterKeepsSlotStatementEvaluationOrderExplicit iface)
      printCheck "checkRuntimeKernelSlotSupportRefinesLeanStagingModel"
        (RuntimeImplementationInterface.checkRuntimeKernelSlotSupportRefinesLeanStagingModel iface)
      printCheck "checkRuntimeKernelAdapterOnlyForwardsGeneratedSlotsAndEffects"
        (RuntimeImplementationInterface.checkRuntimeKernelAdapterOnlyForwardsGeneratedSlotsAndEffects iface)
      printCheck "checkSmallConfidentialKernelBoundary"
        (RuntimeImplementationInterface.checkSmallConfidentialKernelBoundary iface)
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
