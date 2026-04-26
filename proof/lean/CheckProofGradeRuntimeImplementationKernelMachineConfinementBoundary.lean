import UOToolchain.ProofGrade

open Lean
open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeImplementationKernelMachineConfinementBoundary <boundary.json>"

theorem importedBoundaryProjectsToRuntimeImplementationMachineConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeImplementationInterface.ConfinesSecretDependentWork
      runtimeBoundary.implementationInterface ∧
    RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  refine ⟨?_, ?_⟩
  · exact
      importedRuntimeImplementationKernelMachineConfinementBoundary_toRuntimeImplementationConfinement
        boundary hValid
  · exact
      importedRuntimeImplementationKernelMachineConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
        hValid

theorem importedBoundarySharedKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SharedConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_sharedKernelConfinement
      hValid

theorem importedBoundarySmallKernelConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SmallConfidentialKernelBoundary := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_smallKernelConfinement
      hValid

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_residualHelperShellConfinement
      hValid

theorem importedBoundarySlotAdapterConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.SlotAdapterBoundary := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_slotAdapterConfinement
      hValid

theorem importedBoundaryPublicBridgeConfinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_publicBridgeConfinement
      hValid

theorem importedBoundaryPublicShellCanonicalHashingGuardedByPublicEntry
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.shellCanonicalHashingGuardedByPublicEntry := by
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  exact
    RuntimeImplementationInterface.publicBridgeBoundary_shellCanonicalHashingGuardedByPublicEntry
      runtimeBoundary.implementationInterface
      (importedBoundaryPublicBridgeConfinement hValid)

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryPinsNativeMachineSemantics
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pinsNativeMachineSemantics
      hValid

theorem importedBoundaryPaperNativeKernelAssumptions
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_assumptions
      hValid

theorem importedBoundaryPaperNativeKernelLacksDirectSecretOps
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.handwrittenRuntimeLacksDirectSecretOps := by
  exact
    RuntimePaperNativeKernelAssumptions.handwrittenRuntimeLacksDirectSecretOps
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem importedBoundaryPaperNativeKernelHostCoordinationLacksSecretSerialization
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.handwrittenHostCoordinationLacksSecretSerialization := by
  exact
    RuntimePaperNativeKernelAssumptions.hostCoordinationLacksSecretSerialization
      (boundary.toRuntimePaperNativeKernelAssumptions hValid)

theorem importedBoundaryPaperNativeStoreTraceUsesExactBoxedBacking
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.runtimeStoreUsesGeneratedRawBoxedSlotHelpers := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeTraceUsesExactBoxedBacking
      hValid

theorem importedBoundaryPaperNativeGeneratedValueOpsMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.implementationInterface.generatedValueOpsMatchLeanGenerator := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_generatedValueOpsMatchLeanGenerator
      hValid

theorem importedBoundaryPaperNativeValueOpsScalarCanonicalLengthsPublic
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeValueOpsSemantics.boolCanonicalBytes = 1 ∧
    RuntimeValueOpsSemantics.uintCanonicalBytes = 32 ∧
    RuntimeValueOpsSemantics.bytes32CanonicalBytes = 32 ∧
    RuntimeValueOpsSemantics.addressCanonicalBytes = 20 ∧
    RuntimeValueOpsSemantics.canonicalLengthPrefixBytes = 8 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsScalarCanonicalLengthsPublic
      hValid

theorem importedBoundaryPaperNativeValueOpsU128CanonicalByteFieldLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : Nat) :
  (RuntimeValueOpsSemantics.u128CanonicalByteField value).length =
    RuntimeValueOpsSemantics.uintCanonicalBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsU128CanonicalByteFieldLength
      hValid value

theorem importedBoundaryPaperNativeValueOpsU128CanonicalByteFieldHighPrefixZero
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : Nat) :
  (RuntimeValueOpsSemantics.u128CanonicalByteField value).take
      RuntimeValueOpsSemantics.u128HighZeroBytes =
    List.replicate RuntimeValueOpsSemantics.u128HighZeroBytes 0 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsU128CanonicalByteFieldHighPrefixZero
      hValid value

theorem importedBoundaryPaperNativeValueOpsU128CanonicalByteFieldValidBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : Nat) :
  RuntimeValueOpsSemantics.ValidByteField
    (RuntimeValueOpsSemantics.u128CanonicalByteField value) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsU128CanonicalByteFieldValidBytes
      hValid value

theorem importedBoundaryPaperNativeValueOpsMaskedSelectBoolTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeValueOpsSemantics.maskedSelectBool true whenTrue whenFalse = whenTrue := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsMaskedSelectBoolTrue
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeValueOpsMaskedSelectBoolFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeValueOpsSemantics.maskedSelectBool false whenTrue whenFalse = whenFalse := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsMaskedSelectBoolFalse
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeValueOpsMaskedSelectBytesLengthOfEqual
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {cond : Bool}
  {whenTrue whenFalse : List Nat}
  (hLen : whenTrue.length = whenFalse.length) :
  (RuntimeValueOpsSemantics.maskedSelectBytes cond whenTrue whenFalse).length =
    whenTrue.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsMaskedSelectBytesLengthOfEqual
      hValid hLen

theorem importedBoundaryPaperNativeValueOpsFixedBufferExtendPreservesCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state next : RuntimeValueOpsSemantics.FixedByteBufferState}
  {chunk : List Nat}
  (hExtend : state.extend? chunk = some next) :
  next.capacity = state.capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferExtendPreservesCapacity
      hValid hExtend

theorem importedBoundaryPaperNativeValueOpsFixedBufferExtendIncrementsInitialized
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state next : RuntimeValueOpsSemantics.FixedByteBufferState}
  {chunk : List Nat}
  (hExtend : state.extend? chunk = some next) :
  next.initialized = state.initialized + chunk.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferExtendIncrementsInitialized
      hValid hExtend

theorem importedBoundaryPaperNativeValueOpsFixedBufferExtendRejectsOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state : RuntimeValueOpsSemantics.FixedByteBufferState}
  {chunk : List Nat}
  (hOverflow : state.capacity < state.initialized + chunk.length) :
  state.extend? chunk = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferExtendRejectsOverflow
      hValid hOverflow

theorem importedBoundaryPaperNativeValueOpsFixedBufferFinishExactlyFilled
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {state : RuntimeValueOpsSemantics.FixedByteBufferState}
  {capacity : Nat}
  (hFinish : state.finish? = some capacity) :
  state.initialized = state.capacity ∧ capacity = state.capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_valueOpsFixedBufferFinishExactlyFilled
      hValid hFinish

theorem importedBoundaryPaperNativeStoreSurfaceZeroedBytesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (len : Nat) :
  (RuntimeStoreCodecSemantics.zeroedBytes len).length = len := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceZeroedBytesLength
      hValid len

theorem importedBoundaryPaperNativeStoreSurfaceZeroedBytesValid
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (len : Nat) :
  ∀ byte,
    byte ∈ RuntimeStoreCodecSemantics.zeroedBytes len →
      RuntimeStoreCodecSemantics.ValidByte byte := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceZeroedBytesValid
      hValid len

theorem importedBoundaryPaperNativeStoreSurfaceReadExactRangeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes out : List Nat}
  {start len : Nat}
  (hRead :
    RuntimeStoreCodecSemantics.readExactRange? bytes start len =
      some out) :
  out.length = len := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceReadExactRangeLength
      hValid hRead

theorem importedBoundaryPaperNativeStoreSurfaceReadExactRangeRejectsOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {start len : Nat}
  (hRange : ¬ start + len ≤ bytes.length) :
  RuntimeStoreCodecSemantics.readExactRange? bytes start len = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceReadExactRangeRejectsOutOfRange
      hValid hRange

theorem importedBoundaryPaperNativeStoreSurfaceCopyExactIntoShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {out input copied : List Nat}
  (hCopy :
    RuntimeStoreCodecSemantics.copyExactInto? out input =
      some copied) :
  copied = input ∧ copied.length = out.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceCopyExactIntoShape
      hValid hCopy

theorem importedBoundaryPaperNativeStoreSurfaceCopyExactIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {out input : List Nat}
  (hLen : out.length ≠ input.length) :
  RuntimeStoreCodecSemantics.copyExactInto? out input = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceCopyExactIntoRejectsLengthMismatch
      hValid hLen

theorem importedBoundaryPaperNativeStoreSurfaceSealIntoAcceptsExactLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealAndWipeIntoSliceAccepted payloadLen
    (RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceSealIntoAcceptsExactLength
      hValid payloadLen

theorem importedBoundaryPaperNativeStoreSurfaceSealIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen outLen : Nat}
  (hLen :
    outLen ≠ RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  ¬ RuntimeStoreCodecSemantics.sealAndWipeIntoSliceAccepted
      payloadLen outLen := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceSealIntoRejectsLengthMismatch
      hValid hLen

theorem importedBoundaryPaperNativeStoreSurfaceOpenPayloadShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceOpenPayloadShape
      hValid hDecode

theorem importedBoundaryPaperNativeStoreSurfaceWipePreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bytes : List Nat) :
  (RuntimeStoreCodecSemantics.wipeBytes bytes).length = bytes.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceWipePreservesLength
      hValid bytes

theorem importedBoundaryPaperNativeStoreSurfaceWipeZeros
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {byte : Nat}
  (hMem : byte ∈ RuntimeStoreCodecSemantics.wipeBytes bytes) :
  byte = 0 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSurfaceWipeZeros
      hValid hMem

theorem importedBoundaryPaperNativeStoreHelperTakeRawValueCopiesInput
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).boxed = value := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueCopiesInput
      hValid value

theorem importedBoundaryPaperNativeStoreHelperTakeRawValueWipesInputLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).wiped.length =
    value.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueWipesInputLength
      hValid value

theorem importedBoundaryPaperNativeStoreHelperTakeRawValueWipesInputZeros
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {value : List Nat}
  {byte : Nat}
  (hMem :
    byte ∈
      (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).wiped) :
  byte = 0 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperTakeRawValueWipesInputZeros
      hValid hMem

theorem importedBoundaryPaperNativeStoreHelperZeroedRawSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (objects : List String)
  (slotLen : Nat) :
  (RuntimeStoreHelperSemantics.zeroedRawSlots objects slotLen).length =
    objects.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperZeroedRawSlotsLength
      hValid objects slotLen

theorem importedBoundaryPaperNativeStoreHelperLookupZeroedRawSlotsShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperLookupZeroedRawSlotsShape
      hValid hLookup

theorem importedBoundaryPaperNativeStoreHelperInsertOrReplaceLookupSelf
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (slots : List RuntimeStoreHelperSemantics.StoreSlot)
  (object : String)
  (value : List Nat) :
  RuntimeStoreHelperSemantics.lookupSlot object
      (RuntimeStoreHelperSemantics.insertOrReplaceSlot object value slots) =
    some value := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperInsertOrReplaceLookupSelf
      hValid slots object value

theorem importedBoundaryPaperNativeStoreHelperInsertOrReplaceLengthLeSucc
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (slots : List RuntimeStoreHelperSemantics.StoreSlot)
  (object : String)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.insertOrReplaceSlot object value slots).length ≤
    slots.length + 1 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperInsertOrReplaceLengthLeSucc
      hValid slots object value

theorem importedBoundaryPaperNativeStoreHelperAppendEventLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).length =
    events.length + 1 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventLength
      hValid events event

theorem importedBoundaryPaperNativeStoreHelperAppendEventPreservesPrefix
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).take
      events.length =
    events := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventPreservesPrefix
      hValid events event

theorem importedBoundaryPaperNativeStoreHelperAppendEventAppendsSingleton
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).drop
      events.length =
    [event] := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAppendEventAppendsSingleton
      hValid events event

theorem importedBoundaryPaperNativeStoreHelperAllUpdateAppendUoUpdate
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperAllUpdateAppendUoUpdate
      hValid hEvents object slotLen

theorem importedBoundaryPaperNativeStoreHelperBootstrappedUoSlotPublicLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (logicalLen : Nat) :
  (RuntimeStoreHelperSemantics.bootstrappedUoSlotShape object logicalLen).value.length =
    RuntimeStoreCodecSemantics.sealedEncodedLen logicalLen := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperBootstrappedUoSlotPublicLength
      hValid object logicalLen

theorem importedBoundaryPaperNativeStoreHelperBootstrappedUoSlotValidBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (logicalLen : Nat) :
  ∀ byte,
    byte ∈
        (RuntimeStoreHelperSemantics.bootstrappedUoSlotShape object logicalLen).value →
      RuntimeStoreCodecSemantics.ValidByte byte := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperBootstrappedUoSlotValidBytes
      hValid object logicalLen

theorem importedBoundaryPaperNativeStoreHelperResealTracePublicUpdateShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreHelperSemantics.allUpdate
      [RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen] ∧
    RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
      (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperResealTracePublicUpdateShape
      hValid object slotLen

theorem importedBoundaryPaperNativeStoreHelperRecordReadIncrementsReadCounts
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics) :
  (RuntimeStoreHelperSemantics.recordStoreRead metrics).logicalReads =
      metrics.logicalReads + 1 ∧
    (RuntimeStoreHelperSemantics.recordStoreRead metrics).physicalReads =
      metrics.physicalReads + 1 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordReadIncrementsReadCounts
      hValid metrics

theorem importedBoundaryPaperNativeStoreHelperRecordWriteIncrementsWriteCounts
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (zeroWrite : Bool) :
  (RuntimeStoreHelperSemantics.recordStoreWrite metrics zeroWrite).logicalWrites =
      metrics.logicalWrites + 1 ∧
    (RuntimeStoreHelperSemantics.recordStoreWrite metrics zeroWrite).physicalWrites =
      metrics.physicalWrites + 1 := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordWriteIncrementsWriteCounts
      hValid metrics zeroWrite

theorem importedBoundaryPaperNativeStoreHelperRecordUoWriteZeroWritesUnchanged
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (object : String)
  (slotLen : Nat) :
  (RuntimeStoreHelperSemantics.recordUoStoreWrite
      metrics object slotLen).metrics.zeroWrites =
    metrics.zeroWrites := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordUoWriteZeroWritesUnchanged
      hValid metrics object slotLen

theorem importedBoundaryPaperNativeStoreHelperRecordUoWriteEventAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
    (RuntimeStoreHelperSemantics.recordUoStoreWrite
      metrics object slotLen).event := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeHelperRecordUoWriteEventAccepted
      hValid metrics object slotLen

theorem importedBoundaryPaperNativeOramHelperMaskedSelectNatTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Nat) :
  RuntimeOramHelperSemantics.maskedSelectNat true whenTrue whenFalse =
    whenTrue := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectNatTrue
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectNatFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Nat) :
  RuntimeOramHelperSemantics.maskedSelectNat false whenTrue whenFalse =
    whenFalse := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectNatFalse
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectBoolTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeOramHelperSemantics.maskedSelectBool true whenTrue whenFalse =
    whenTrue := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectBoolTrue
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectBoolFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeOramHelperSemantics.maskedSelectBool false whenTrue whenFalse =
    whenFalse := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectBoolFalse
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectOptionTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.maskedSelectOption true whenTrue whenFalse =
    whenTrue := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectOptionTrue
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectOptionFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.maskedSelectOption false whenTrue whenFalse =
    whenFalse := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectOptionFalse
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectTransitionKindTrue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.PathTransitionKind) :
  RuntimeOramHelperSemantics.maskedSelectTransitionKind
      true whenTrue whenFalse = whenTrue := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectTransitionKindTrue
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperMaskedSelectTransitionKindFalse
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.PathTransitionKind) :
  RuntimeOramHelperSemantics.maskedSelectTransitionKind
      false whenTrue whenFalse = whenFalse := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperMaskedSelectTransitionKindFalse
      hValid whenTrue whenFalse

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionKindDelete
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (insertNew updateExisting : Bool) :
  RuntimeOramHelperSemantics.pathPutTransitionKind
      insertNew updateExisting true =
    RuntimeOramHelperSemantics.PathTransitionKind.writeDelete := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindDelete
      hValid insertNew updateExisting

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionKindUpdate
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (insertNew : Bool) :
  RuntimeOramHelperSemantics.pathPutTransitionKind insertNew true false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeUpdate := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindUpdate
      hValid insertNew

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionKindInsert
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathPutTransitionKind true false false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeInsert := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindInsert
      hValid

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionKindNoop
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathPutTransitionKind false false false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeNoop := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionKindNoop
      hValid

theorem importedBoundaryPaperNativeOramHelperPathGetTransitionKindHit
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathGetTransitionKind true =
    RuntimeOramHelperSemantics.PathTransitionKind.readHit := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionKindHit
      hValid

theorem importedBoundaryPaperNativeOramHelperPathGetTransitionKindMiss
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathGetTransitionKind false =
    RuntimeOramHelperSemantics.PathTransitionKind.readMiss := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionKindMiss
      hValid

theorem importedBoundaryPaperNativeOramHelperPathGetTransitionFieldsMiss
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionFieldsMiss
      hValid positionMap accessLeaf freshLeaf

theorem importedBoundaryPaperNativeOramHelperPathGetTransitionFieldsHit
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathGetTransitionFieldsHit
      hValid hLookup

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionFieldsDelete
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsDelete
      hValid slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionFieldsUpdate
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsUpdate
      hValid slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionFieldsInsert
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsInsert
      hValid insertSlot accessLeaf nextLeafValue

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionFieldsNoopAbsent
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsNoopAbsent
      hValid valueIsZero insertSlot accessLeaf nextLeafValue

theorem importedBoundaryPaperNativeOramHelperPathPutTransitionFieldsNoopPresentRetainsPrior
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutTransitionFieldsNoopPresentRetainsPrior
      hValid valueIsZero slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem importedBoundaryPaperNativeOramHelperLiveBlockValidationUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationUnoccupied
      hValid capacity leafCount positionMap liveSlots hOccupied

theorem importedBoundaryPaperNativeOramHelperLiveSlotsAfterUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block = liveSlots := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterUnoccupied
      hValid capacity leafCount positionMap liveSlots hOccupied

theorem importedBoundaryPaperNativeOramHelperLiveBlockValidationValidOccupied
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationValidOccupied
      hValid hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryPaperNativeOramHelperLiveSlotsAfterValidOccupied
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterValidOccupied
      hValid hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryPaperNativeOramHelperLiveBlockValidationSlotOutOfRange
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationSlotOutOfRange
      hValid hOccupied hSlot

theorem importedBoundaryPaperNativeOramHelperLiveBlockValidationDuplicateLiveSlot
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveBlockValidationDuplicateLiveSlot
      hValid hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryPaperNativeOramHelperLiveSlotsAfterValidOccupiedLookup
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterValidOccupiedLookup
      hValid hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryPaperNativeOramHelperLiveSlotCoverageEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed [] liveSlots = false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoverageEmpty
      hValid liveSlots

theorem importedBoundaryPaperNativeOramHelperLiveSlotCoverageMissingLiveSlot
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (leaf :: positionMap) [] = true := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoverageMissingLiveSlot
      hValid leaf positionMap

theorem importedBoundaryPaperNativeOramHelperLiveSlotCoverageAbsentHead
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (liveSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.noneOption :: positionMap)
      (liveSlot :: liveSlots) =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap liveSlots := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoverageAbsentHead
      hValid positionMap liveSlots liveSlot

theorem importedBoundaryPaperNativeOramHelperLiveSlotCoveragePresentLiveHead
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leaf liveLeaf : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.presentOption leaf :: positionMap)
      (RuntimeOramHelperSemantics.presentOption liveLeaf :: liveSlots) =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap liveSlots := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoveragePresentLiveHead
      hValid leaf liveLeaf positionMap liveSlots

theorem importedBoundaryPaperNativeOramHelperLiveSlotCoveragePresentMissingHead
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leaf : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.presentOption leaf :: positionMap)
      (RuntimeOramHelperSemantics.noneOption :: liveSlots) = true := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotCoveragePresentMissingHead
      hValid leaf positionMap liveSlots

theorem importedBoundaryPaperNativeOramHelperResetPathEntryCellsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.resetPathEntryCells capacity).length =
    capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperResetPathEntryCellsLength
      hValid capacity

theorem importedBoundaryPaperNativeOramHelperResetPathEntryCellsAllEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {capacity : Nat}
  {entry : RuntimeOramHelperSemantics.PathEntryCell}
  (hEntry :
    entry ∈ RuntimeOramHelperSemantics.resetPathEntryCells capacity) :
  entry = RuntimeOramHelperSemantics.emptyPathEntryCell := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperResetPathEntryCellsAllEmpty
      hValid hEntry

theorem importedBoundaryPaperNativeOramHelperInstallPathEntryFailedUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFailedUnoccupied
      hValid entries hOccupied

theorem importedBoundaryPaperNativeOramHelperInstallPathEntryFromBlockUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.installPathEntryFromBlock entries block =
    entries := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFromBlockUnoccupied
      hValid entries hOccupied

theorem importedBoundaryPaperNativeOramHelperInstallPathEntryFailedOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : entries.length ≤ block.slotIndex) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = true := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFailedOutOfRange
      hValid hOccupied hSlot

theorem importedBoundaryPaperNativeOramHelperInstallPathEntryFailedValidOccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < entries.length) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFailedValidOccupied
      hValid hOccupied hSlot

theorem importedBoundaryPaperNativeOramHelperInstallPathEntryFromBlockPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.installPathEntryFromBlock
    entries block).length = entries.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFromBlockPreservesLength
      hValid entries block

theorem importedBoundaryPaperNativeOramHelperInstallPathEntryFromBlockValidOccupiedLookup
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInstallPathEntryFromBlockValidOccupiedLookup
      hValid hOccupied hSlot

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepPriorFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepPriorFailure
      hValid capacity leafCount positionMap block hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepUnoccupied
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepUnoccupied
      hValid capacity leafCount positionMap hState hOccupied

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepValidationFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepValidationFailure
      hValid capacity leafCount positionMap hState hValidation

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepInstallFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepInstallFailure
      hValid capacity leafCount positionMap hState hValidation hInstall

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepValidOccupied
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepValidOccupied
      hValid hState hOccupied hSlot hLeaf hPosition hLive hEntrySlot

theorem importedBoundaryPaperNativeOramHelperReconstructPathFinishFailedPriorFailure
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathFinishFailed
      positionMap state = true := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathFinishFailedPriorFailure
      hValid positionMap hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathFinishFailedCoverageFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathFinishFailedCoverageFailure
      hValid positionMap hFailed hCoverage

theorem importedBoundaryPaperNativeOramHelperReconstructPathFinishFailedSuccess
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathFinishFailedSuccess
      hValid positionMap hFailed hCoverage

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlocksEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state [] = state := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksEmpty
      hValid capacity leafCount positionMap state

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlocksCons
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksCons
      hValid capacity leafCount positionMap state block blocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlocksPriorFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksPriorFailure
      hValid capacity leafCount positionMap blocks hFailed

theorem importedBoundaryPaperNativeOramHelperInitialReconstructionStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).liveSlots.length =
    capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInitialReconstructionStateLiveSlotsLength
      hValid capacity

theorem importedBoundaryPaperNativeOramHelperInitialReconstructionStateEntriesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).entries.length =
    capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInitialReconstructionStateEntriesLength
      hValid capacity

theorem importedBoundaryPaperNativeOramHelperInitialReconstructionStateFailed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).failed =
    false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperInitialReconstructionStateFailed
      hValid capacity

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksStateStashThenBuckets
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksStateStashThenBuckets
      hValid capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksStateNoBlocks
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.initialReconstructionState capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksStateNoBlocks
      hValid capacity leafCount positionMap

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksStateStashFailureAbsorbs
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksStateStashFailureAbsorbs
      hValid capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksFailedPriorFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedPriorFailure
      hValid capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksFailedSuccess
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedSuccess
      hValid capacity leafCount positionMap stashBlocks bucketBlocks hFailed hCoverage

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksFailedStashFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedStashFailure
      hValid capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBlocksFailedNoBlocks
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBlocksFailedNoBlocks
      hValid capacity leafCount positionMap

theorem importedBoundaryPaperNativeOramHelperBucketBlockAdmissionFailedUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (leafCount bucketIndex leaf : Nat) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      { bucketIndex
      , block := { occupied := false, slotIndex := 0, leaf }
      } = false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedUnoccupied
      hValid leafCount bucketIndex leaf

theorem importedBoundaryPaperNativeOramHelperBucketBlockAdmissionFailedOffPath
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedOffPath
      hValid hOccupied hPath

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlockStepOffPathFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepOffPathFailure
      hValid capacity leafCount positionMap hState hAdmission

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlockStepAdmitted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepAdmitted
      hValid capacity leafCount positionMap hState hAdmission

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksPriorFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksPriorFailure
      hValid capacity leafCount positionMap bucketBlocks hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateStashThenBuckets
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateStashThenBuckets
      hValid capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsFailedSuccess
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedSuccess
      hValid capacity leafCount positionMap stashBlocks bucketBlocks hFailed hCoverage

theorem importedBoundaryPaperNativeOramHelperBucketBlockOfCodecBlockBucketIndex
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (block : RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block).bucketIndex =
    bucketIndex := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockOfCodecBlockBucketIndex
      hValid bucketIndex block

theorem importedBoundaryPaperNativeOramHelperBucketBlockOfCodecBlockBlock
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (block : RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block).block =
    RuntimeOramHelperSemantics.stashBlockOfCodecBlock block := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockOfCodecBlockBlock
      hValid bucketIndex block

theorem importedBoundaryPaperNativeOramHelperStashBlocksOfCodecBlocksLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks blocks).length =
    blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperStashBlocksOfCodecBlocksLength
      hValid blocks

theorem importedBoundaryPaperNativeOramHelperBucketBlocksOfCodecBlocksLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks).length =
    blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksOfCodecBlocksLength
      hValid bucketIndex blocks

theorem importedBoundaryPaperNativeOramHelperBucketBlocksOfCodecBlocksMapBlock
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks).map
      RuntimeOramHelperSemantics.BucketBlock.block =
    RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks blocks := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksOfCodecBlocksMapBlock
      hValid bucketIndex blocks

theorem importedBoundaryPaperNativeOramHelperBucketBlockAdmissionFailedBridgeUnoccupied
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hUnoccupied : block.occupiedTag ≠ 1) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block) =
    false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedBridgeUnoccupied
      hValid hUnoccupied

theorem importedBoundaryPaperNativeOramHelperBucketBlockAdmissionFailedBridgeLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hLive : block.LiveOnBucketPath leafCount bucketIndex) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block) =
    false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlockAdmissionFailedBridgeLiveOnBucketPath
      hValid hLive

theorem importedBoundaryPaperNativeOramHelperBucketBlocksOfCodecBlocksAdmittedOfLiveOnBucketPath
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBucketBlocksOfCodecBlocksAdmittedOfLiveOnBucketPath
      hValid hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksEqReconstructPathBlocksOfAdmitted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksEqReconstructPathBlocksOfAdmitted
      hValid capacity leafCount positionMap state bucketBlocks hAdmit

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksBucketBlocksOfCodecBlocks
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksBucketBlocksOfCodecBlocks
      hValid positionMap state codecBlocks hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateBucketBlocksOfCodecBlocks
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateBucketBlocksOfCodecBlocks
      hValid positionMap stashBlocks codecBlocks hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsFailedBucketBlocksOfCodecBlocks
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedBucketBlocksOfCodecBlocks
      hValid positionMap stashBlocks codecBlocks hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPathBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPathBounded
      hValid hDecode positionMap stashBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPathBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPathBounded
      hValid hDecode positionMap stashBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPositionMapBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPositionMapBounded
      hValid hDecode positionMap stashBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPositionMapBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPositionMapBounded
      hValid hDecode positionMap stashBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateDecodedPathBucketUniquePositionMapBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketUniquePositionMapBounded
      hValid hDecode positionMap stashBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketUniquePositionMapBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketUniquePositionMapBounded
      hValid hDecode positionMap stashBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksAppend
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksAppend
      hValid capacity leafCount positionMap state xs ys

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlocksAppend
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksAppend
      hValid capacity leafCount positionMap state xs ys

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksBucketBlocksOfDecodedBuckets
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksBucketBlocksOfDecodedBuckets
      hValid capacity leafCount positionMap state decodedBuckets hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListStateLiveOnBucketPath
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateLiveOnBucketPath
      hValid capacity leafCount positionMap stashBlocks decodedBuckets hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListFailedLiveOnBucketPath
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedLiveOnBucketPath
      hValid capacity leafCount positionMap stashBlocks decodedBuckets hLive

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListFailedPriorFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedPriorFailure
      hValid capacity leafCount positionMap stashBlocks decodedBuckets hFailed

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListFailedSuccess
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedSuccess
      hValid capacity leafCount positionMap stashBlocks decodedBuckets hFailed hCoverage

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListStateNoBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.initialReconstructionState capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateNoBuckets
      hValid capacity leafCount positionMap

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListFailedNoBuckets
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (List.replicate capacity RuntimeOramHelperSemantics.noneOption) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListFailedNoBuckets
      hValid capacity leafCount positionMap

theorem importedBoundaryPaperNativeOramHelperDecodedBucketsLiveOnBucketPathCons
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketsLiveOnBucketPathCons
      hValid hHead hTail

theorem importedBoundaryPaperNativeOramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPathBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPathBounded
      hValid hDecode

theorem importedBoundaryPaperNativeOramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPositionMapBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPositionMapBounded
      hValid hDecode

theorem importedBoundaryPaperNativeOramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketUniquePositionMapBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketUniquePositionMapBounded
      hValid hDecode

theorem importedBoundaryPaperNativeOramHelperLiveSlotsAfterBlockValidationLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block).length =
    liveSlots.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperLiveSlotsAfterBlockValidationLength
      hValid capacity leafCount positionMap liveSlots block

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepLiveSlotsLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepLiveSlotsLength
      hValid capacity leafCount positionMap state block

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepEntriesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepEntriesLength
      hValid capacity leafCount positionMap state block

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlocksLiveSlotsLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksLiveSlotsLength
      hValid capacity leafCount positionMap state blocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlocksEntriesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlocksEntriesLength
      hValid capacity leafCount positionMap state blocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlockStepLiveSlotsLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepLiveSlotsLength
      hValid capacity leafCount positionMap state bucketBlock

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlockStepEntriesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepEntriesLength
      hValid capacity leafCount positionMap state bucketBlock

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksLiveSlotsLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksLiveSlotsLength
      hValid capacity leafCount positionMap state bucketBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlocksEntriesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlocksEntriesLength
      hValid capacity leafCount positionMap state bucketBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateLiveSlotsLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateLiveSlotsLength
      hValid capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsStateEntriesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsStateEntriesLength
      hValid capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListStateLiveSlotsLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateLiveSlotsLength
      hValid capacity leafCount positionMap stashBlocks decodedBuckets

theorem importedBoundaryPaperNativeOramHelperReconstructPathDecodedBucketsListStateEntriesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathDecodedBucketsListStateEntriesLength
      hValid capacity leafCount positionMap stashBlocks decodedBuckets

theorem importedBoundaryPaperNativeOramHelperReconstructPathBlockStepPreservesNonFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBlockStepPreservesNonFailure
      hValid hState hValidation hInstall

theorem importedBoundaryPaperNativeOramHelperReconstructPathBucketBlockStepPreservesNonFailureAdmitted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperReconstructPathBucketBlockStepPreservesNonFailureAdmitted
      hValid hState hAdmission hValidation hInstall

theorem importedBoundaryPaperNativeOramHelperWorkingStashCapacityFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.Parameters) :
  RuntimeOramHelperSemantics.workingStashCapacity parameters =
    parameters.stashBound +
      parameters.bucketsPerAccess * parameters.blocksPerBucket := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperWorkingStashCapacityFormula
      hValid parameters

theorem importedBoundaryPaperNativeOramHelperSlotForKeySomeWithinCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {keyMatches : List Bool}
  {slot : Nat}
  (hSlot : RuntimeOramHelperSemantics.slotForKey? keyMatches = some slot) :
  slot < keyMatches.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSlotForKeySomeWithinCapacity
      hValid hSlot

theorem importedBoundaryPaperNativeOramHelperAllocateSlotSomeWithinCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {occupied : List Bool}
  {slot : Nat}
  (hSlot : RuntimeOramHelperSemantics.allocateSlot? occupied = some slot) :
  slot < occupied.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperAllocateSlotSomeWithinCapacity
      hValid hSlot

theorem importedBoundaryPaperNativeOramHelperFirstVacantIndexSomeWithinCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {index : Nat}
  (hIndex :
    RuntimeOramHelperSemantics.firstVacantIndex blocks = some index) :
  index < blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperFirstVacantIndexSomeWithinCapacity
      hValid hIndex

theorem importedBoundaryPaperNativeOramHelperClearFixedStashLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.clearFixedStash blocks).length =
    blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperClearFixedStashLength
      hValid blocks

theorem importedBoundaryPaperNativeOramHelperClearFixedStashAllEmpty
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hMem : block ∈ RuntimeOramHelperSemantics.clearFixedStash blocks) :
  block = RuntimeOramHelperSemantics.emptyBlock := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperClearFixedStashAllEmpty
      hValid hMem

theorem importedBoundaryPaperNativeOramHelperPushFixedStashPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (overflowed : Bool)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.pushFixedStash
      blocks overflowed block).blocks.length =
    blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPushFixedStashPreservesLength
      hValid blocks overflowed block

theorem importedBoundaryPaperNativeOramHelperPushFixedStashVacantPreservesOverflow
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPushFixedStashVacantPreservesOverflow
      hValid hOccupied hVacant

theorem importedBoundaryPaperNativeOramHelperPushFixedStashNoVacantOverflows
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPushFixedStashNoVacantOverflows
      hValid hOccupied hVacant

theorem importedBoundaryPaperNativeOramHelperTakeSelectedBlockPreservesLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperTakeSelectedBlockPreservesLength
      hValid hTake

theorem importedBoundaryPaperNativeOramHelperTakeSelectedBlockPresentSelectedInBounds
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperTakeSelectedBlockPresentSelectedInBounds
      hValid hTake

theorem importedBoundaryPaperNativeOramHelperSelectPositionMapLeafAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.selectPositionMapLeaf positionMap slot =
    RuntimeOramHelperSemantics.noneOption := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectPositionMapLeafAbsent
      hValid positionMap slot hAbsent

theorem importedBoundaryPaperNativeOramHelperSelectPositionMapLeafPresentGet
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {slot leaf : RuntimeOramHelperSemantics.MaskedUsizeOption}
  (hPresent : slot.present = true)
  (hGet :
    RuntimeOramHelperSemantics.lookupAt? positionMap slot.value = some leaf) :
  RuntimeOramHelperSemantics.selectPositionMapLeaf positionMap slot = leaf := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectPositionMapLeafPresentGet
      hValid hPresent hGet

theorem importedBoundaryPaperNativeOramHelperSelectValueAtAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (values : List α)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (default : α)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.selectValueAt values slot default = default := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectValueAtAbsent
      hValid values slot default hAbsent

theorem importedBoundaryPaperNativeOramHelperSelectValueAtPresentGet
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {values : List α}
  {slot : RuntimeOramHelperSemantics.MaskedUsizeOption}
  {default value : α}
  (hPresent : slot.present = true)
  (hGet : RuntimeOramHelperSemantics.lookupAt? values slot.value = some value) :
  RuntimeOramHelperSemantics.selectValueAt values slot default = value := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperSelectValueAtPresentGet
      hValid hPresent hGet

theorem importedBoundaryPaperNativeOramHelperAccessLeafUsesFreshWhenNoPrior
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperAccessLeafUsesFreshWhenNoPrior
      hValid positionMap slot freshLeaf hNoPrior

theorem importedBoundaryPaperNativeOramHelperAccessLeafUsesPriorWhenPresent
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperAccessLeafUsesPriorWhenPresent
      hValid positionMap slot freshLeaf hPrior

theorem importedBoundaryPaperNativeOramHelperUpdatePositionMapLeafPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  (RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf).length = positionMap.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdatePositionMapLeafPreservesLength
      hValid positionMap slot nextLeaf

theorem importedBoundaryPaperNativeOramHelperUpdatePositionMapLeafAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf = positionMap := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdatePositionMapLeafAbsent
      hValid positionMap slot nextLeaf hAbsent

theorem importedBoundaryPaperNativeOramHelperUpdatePositionMapLeafNextAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : nextLeaf.present = false) :
  RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf = positionMap := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdatePositionMapLeafNextAbsent
      hValid positionMap slot nextLeaf hAbsent

theorem importedBoundaryPaperNativeOramHelperUpdateStashLeafForSlotPreservesLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  (RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf).length = blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdateStashLeafForSlotPreservesLength
      hValid blocks slot nextLeaf

theorem importedBoundaryPaperNativeOramHelperUpdateStashLeafForSlotAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf = blocks := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdateStashLeafForSlotAbsent
      hValid blocks slot nextLeaf hAbsent

theorem importedBoundaryPaperNativeOramHelperUpdateStashLeafForSlotNextAbsent
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : nextLeaf.present = false) :
  RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf = blocks := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperUpdateStashLeafForSlotNextAbsent
      hValid blocks slot nextLeaf hAbsent

theorem importedBoundaryPaperNativeOramHelperPathPutUpdateFailedNoApply
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (entryCapacity : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (valueIsZero : Bool)
  (slot insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.pathPutUpdateFailed
      entryCapacity blocks false valueIsZero slot insertSlot = false := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedNoApply
      hValid entryCapacity blocks valueIsZero slot insertSlot

theorem importedBoundaryPaperNativeOramHelperPathPutUpdateFailedUpdateMissing
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedUpdateMissing
      hValid entryCapacity blocks slot insertSlot hSlot hMissing

theorem importedBoundaryPaperNativeOramHelperPathPutUpdateFailedInsertNoVacancy
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedInsertNoVacancy
      hValid entryCapacity blocks slot insertSlot hSlotAbsent hInsert hVacant

theorem importedBoundaryPaperNativeOramHelperPathPutUpdateFailedInsertOutOfRange
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathPutUpdateFailedInsertOutOfRange
      hValid entryCapacity blocks slot insertSlot hSlotAbsent hInsert hOutOfRange

theorem importedBoundaryPaperNativeOramHelperBuildPathBucketBucketLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).bucket.length =
    blocksPerBucket := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBuildPathBucketBucketLength
      hValid blocksPerBucket leafCount bucketIndex blocks

theorem importedBoundaryPaperNativeOramHelperBuildPathBucketStashLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).stash.length =
    blocks.length := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBuildPathBucketStashLength
      hValid blocksPerBucket leafCount bucketIndex blocks

theorem importedBoundaryPaperNativeOramHelperBuildPathBucketLiveCountBound
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).liveCount ≤
    blocksPerBucket := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperBuildPathBucketLiveCountBound
      hValid blocksPerBucket leafCount bucketIndex blocks

theorem importedBoundaryPaperNativeOramHelperRewritePathWriteCountMatchesWriteLogCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters) :
  RuntimeOramHelperSemantics.rewritePathWriteCount parameters =
    RuntimeOramWriteLogDiscipline.writeLogCapacity
      (RuntimeOramHelperSemantics.rewriteWriteLogParameters parameters) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathWriteCountMatchesWriteLogCapacity
      hValid parameters

theorem importedBoundaryPaperNativeOramHelperPathAccessReadCountMatchesReadTranscriptCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters) :
  RuntimeOramHelperSemantics.pathAccessReadCount parameters =
    RuntimeOramWriteLogDiscipline.readTranscriptCapacity
      (RuntimeOramHelperSemantics.rewriteWriteLogParameters parameters) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperPathAccessReadCountMatchesReadTranscriptCapacity
      hValid parameters

theorem importedBoundaryPaperNativeOramHelperRewritePathSummaryNextCounter
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathSummaryNextCounter
      hValid parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen

theorem importedBoundaryPaperNativeOramHelperRewritePathSummaryPhysicalWriteCount
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathSummaryPhysicalWriteCount
      hValid parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen

theorem importedBoundaryPaperNativeOramHelperRewritePathUpdateFailedLoadOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters true effectFailed postUpdateStashLen postRebuildStashLen =
    true := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedLoadOverflow
      hValid parameters effectFailed postUpdateStashLen postRebuildStashLen

theorem importedBoundaryPaperNativeOramHelperRewritePathUpdateFailedEffectFailed
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (loadOverflowed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters loadOverflowed true postUpdateStashLen postRebuildStashLen =
    true := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedEffectFailed
      hValid parameters loadOverflowed postUpdateStashLen postRebuildStashLen

theorem importedBoundaryPaperNativeOramHelperRewritePathUpdateFailedPostUpdateOverflow
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedPostUpdateOverflow
      hValid parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen hOverflow

theorem importedBoundaryPaperNativeOramHelperRewritePathUpdateFailedPostRebuildOverflow
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedPostRebuildOverflow
      hValid parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen hOverflow

theorem importedBoundaryPaperNativeOramHelperRewritePathUpdateFailedNoFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathUpdateFailedNoFailure
      hValid parameters postUpdateStashLen postRebuildStashLen hPostUpdate
      hPostRebuild

theorem importedBoundaryPaperNativeOramHelperRewritePathSummaryNoFailure
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramHelperRewritePathSummaryNoFailure
      hValid parameters currentCounter postUpdateStashLen postRebuildStashLen
      hPostUpdate hPostRebuild

theorem importedBoundaryPaperNativeSlotSupportStageArgsAcceptsPrecondition
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (program : ConfidentialKernelSlotProgram)
  (args : List Json)
  (h : RuntimeKernelSlotSupport.Precondition program args) :
  RuntimeKernelSlotSupport.stageArgs? program args =
    some (RuntimeKernelSlotSupport.stageArgs program.slotCount args) := by
  exact
    RuntimePaperNativeKernelAssumptions.slotSupportStageArgsAcceptsPrecondition
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) program args h

theorem importedBoundaryPaperNativeSlotSupportStageArgsRejectsArgCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (program : ConfidentialKernelSlotProgram)
  (args : List Json)
  (h : args.length ≠ program.paramCount) :
  RuntimeKernelSlotSupport.stageArgs? program args = none := by
  exact
    RuntimePaperNativeKernelAssumptions.slotSupportStageArgsRejectsArgCountMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) program args h

theorem importedBoundaryPaperNativeSlotSupportStageArgsRejectsParamSlotOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (program : ConfidentialKernelSlotProgram)
  (args : List Json)
  (h : ¬ program.paramCount ≤ program.slotCount) :
  RuntimeKernelSlotSupport.stageArgs? program args = none := by
  exact
    RuntimePaperNativeKernelAssumptions.slotSupportStageArgsRejectsParamSlotOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) program args h

theorem importedBoundaryPaperNativeSlotSupportStageArgsSomeStagesCallInputs
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (program : ConfidentialKernelSlotProgram)
  (args : List Json)
  (slots : RuntimeKernelSlotSupport.SlotFile)
  (h : RuntimeKernelSlotSupport.stageArgs? program args = some slots) :
  RuntimeKernelSlotSupport.StagesCallInputs program args slots := by
  exact
    RuntimePaperNativeKernelAssumptions.slotSupportStageArgsSomeStagesCallInputs
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) program args slots h

theorem importedBoundaryPaperNativeStatementTraceNamesMatchBodyLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (program : ConfidentialKernelSlotProgram) :
  program.statementTraceNames.length =
    RuntimeStatementTraceDiscipline.capacityForProgram program := by
  exact
    RuntimePaperNativeKernelAssumptions.statementTraceNamesMatchBodyLength
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) program

theorem importedBoundaryPaperNativeStatementTraceRecordRejectsAtCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {trace : RuntimeStatementTraceDiscipline.Trace}
  (statement : ConfidentialKernelSlotStatement)
  (h : ¬ trace.len < trace.capacity) :
  RuntimeStatementTraceDiscipline.recordStatement trace statement = none := by
  exact
    RuntimePaperNativeKernelAssumptions.statementTraceRecordRejectsAtCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) statement h

theorem importedBoundaryPaperNativeStatementTraceRecordAppendsTraceName
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {trace next : RuntimeStatementTraceDiscipline.Trace}
  {statement : ConfidentialKernelSlotStatement}
  (h : RuntimeStatementTraceDiscipline.recordStatement trace statement = some next) :
  next.names = trace.names ++ [statement.traceName] := by
  exact
    RuntimePaperNativeKernelAssumptions.statementTraceRecordAppendsTraceName
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeStatementTraceAcceptedHasExactNames
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {program : ConfidentialKernelSlotProgram}
  {trace : RuntimeStatementTraceDiscipline.Trace}
  (h : RuntimeStatementTraceDiscipline.acceptedTraceForProgram program trace) :
  trace.names = program.statementTraceNames := by
  exact
    RuntimePaperNativeKernelAssumptions.statementTraceAcceptedHasExactNames
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeStatementTraceBoxedTraceExact
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {program : ConfidentialKernelSlotProgram}
  {trace : RuntimeStatementTraceDiscipline.Trace}
  (h : RuntimeStatementTraceDiscipline.acceptedTraceForProgram program trace) :
  RuntimeStatementTraceDiscipline.boxedTrace trace =
    program.statementTraceNames := by
  exact
    RuntimePaperNativeKernelAssumptions.statementTraceBoxedTraceExact
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeSmallMapLookupStepAccumulatesMatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {trace : RuntimeSmallMapLookupDiscipline.Trace}
  {keyMatch : Bool}
  (h : trace.index < trace.capacity) :
  (RuntimeSmallMapLookupDiscipline.step trace keyMatch).matched =
    (trace.matched || keyMatch) := by
  exact
    RuntimePaperNativeKernelAssumptions.smallMapLookupStepAccumulatesMatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeSmallMapLookupScanMatchesAcceptsExactPublicCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeSmallMapLookupDiscipline.Parameters)
  (keyMatches : List Bool)
  (h : RuntimeSmallMapLookupDiscipline.Precondition parameters keyMatches) :
  RuntimeSmallMapLookupDiscipline.scanMatches? parameters keyMatches =
    some
      { capacity := parameters.capacity
      , index := parameters.capacity
      , matched := RuntimeSmallMapLookupDiscipline.scanMatches keyMatches
      , overflowed := false
      } := by
  exact
    RuntimePaperNativeKernelAssumptions.smallMapLookupScanMatchesAcceptsExactPublicCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) parameters keyMatches h

theorem importedBoundaryPaperNativeSmallMapLookupScanMatchesRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeSmallMapLookupDiscipline.Parameters)
  (keyMatches : List Bool)
  (h : ¬ RuntimeSmallMapLookupDiscipline.Precondition parameters keyMatches) :
  RuntimeSmallMapLookupDiscipline.scanMatches? parameters keyMatches = none := by
  exact
    RuntimePaperNativeKernelAssumptions.smallMapLookupScanMatchesRejectsLengthMismatch
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) parameters keyMatches h

theorem importedBoundaryPaperNativeSmallMapLookupScanMatchesSomeAcceptedLookup
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeSmallMapLookupDiscipline.Parameters}
  {keyMatches : List Bool}
  {trace : RuntimeSmallMapLookupDiscipline.Trace}
  (h : RuntimeSmallMapLookupDiscipline.scanMatches? parameters keyMatches = some trace) :
  RuntimeSmallMapLookupDiscipline.acceptedLookup parameters trace := by
  exact
    RuntimePaperNativeKernelAssumptions.smallMapLookupScanMatchesSomeAcceptedLookup
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeSmallMapLookupScanMatchesSomeMatchedEqualsFold
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeSmallMapLookupDiscipline.Parameters}
  {keyMatches : List Bool}
  {trace : RuntimeSmallMapLookupDiscipline.Trace}
  (h : RuntimeSmallMapLookupDiscipline.scanMatches? parameters keyMatches = some trace) :
  trace.matched = RuntimeSmallMapLookupDiscipline.scanMatches keyMatches := by
  exact
    RuntimePaperNativeKernelAssumptions.smallMapLookupScanMatchesSomeMatchedEqualsFold
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeArrayAccessSelectedSlotAcceptsInBounds
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeArrayAccessDiscipline.Parameters}
  {logicalIndex : Nat}
  (h : logicalIndex < parameters.capacity) :
  RuntimeArrayAccessDiscipline.selectedSlot? parameters logicalIndex =
    some logicalIndex := by
  exact
    RuntimePaperNativeKernelAssumptions.arrayAccessSelectedSlotAcceptsInBounds
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeArrayAccessSelectedSlotRejectsOutOfRange
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeArrayAccessDiscipline.Parameters}
  {logicalIndex : Nat}
  (h : ¬ logicalIndex < parameters.capacity) :
  RuntimeArrayAccessDiscipline.selectedSlot? parameters logicalIndex = none := by
  exact
    RuntimePaperNativeKernelAssumptions.arrayAccessSelectedSlotRejectsOutOfRange
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeArrayAccessSelectedSlotSomeSelectsSlot
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeArrayAccessDiscipline.Parameters}
  {logicalIndex slot : Nat}
  (h : RuntimeArrayAccessDiscipline.selectedSlot? parameters logicalIndex = some slot) :
  RuntimeArrayAccessDiscipline.selectsSlot parameters logicalIndex slot := by
  exact
    RuntimePaperNativeKernelAssumptions.arrayAccessSelectedSlotSomeSelectsSlot
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeArrayAccessSelectsSlotUnique
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeArrayAccessDiscipline.Parameters}
  {logicalIndex slot₁ slot₂ : Nat}
  (h₁ : RuntimeArrayAccessDiscipline.selectsSlot parameters logicalIndex slot₁)
  (h₂ : RuntimeArrayAccessDiscipline.selectsSlot parameters logicalIndex slot₂) :
  slot₁ = slot₂ := by
  exact
    RuntimePaperNativeKernelAssumptions.arrayAccessSelectsSlotUnique
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h₁ h₂

theorem importedBoundaryPaperNativeOramWriteLogPushRejectsAtCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log : RuntimeOramWriteLogDiscipline.Log} {isZeroWrite : Bool}
  (h : log.capacity ≤ log.len) :
  RuntimeOramWriteLogDiscipline.pushWrite log isZeroWrite = none := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushRejectsAtCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushPreservesCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log next : RuntimeOramWriteLogDiscipline.Log} {isZeroWrite : Bool}
  (h : RuntimeOramWriteLogDiscipline.pushWrite log isZeroWrite = some next) :
  next.capacity = log.capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushPreservesCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushUpdatesZeroWrites
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log next : RuntimeOramWriteLogDiscipline.Log} {isZeroWrite : Bool}
  (h : RuntimeOramWriteLogDiscipline.pushWrite log isZeroWrite = some next) :
  next.zeroWrites =
    log.zeroWrites + if isZeroWrite then 1 else 0 := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushUpdatesZeroWrites
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushPreservesOverflowFlag
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log next : RuntimeOramWriteLogDiscipline.Log} {isZeroWrite : Bool}
  (h : RuntimeOramWriteLogDiscipline.pushWrite log isZeroWrite = some next) :
  next.overflowed = log.overflowed := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushPreservesOverflowFlag
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushUpdateRejectsAtCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log : RuntimeOramWriteLogDiscipline.Log}
  (h : log.capacity ≤ log.len) :
  RuntimeOramWriteLogDiscipline.pushUpdate log = none := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushUpdateRejectsAtCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushUpdatePreservesCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log next : RuntimeOramWriteLogDiscipline.Log}
  (h : RuntimeOramWriteLogDiscipline.pushUpdate log = some next) :
  next.capacity = log.capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushUpdatePreservesCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushUpdatePreservesZeroWrites
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log next : RuntimeOramWriteLogDiscipline.Log}
  (h : RuntimeOramWriteLogDiscipline.pushUpdate log = some next) :
  next.zeroWrites = log.zeroWrites := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushUpdatePreservesZeroWrites
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogPushUpdatePreservesOverflowFlag
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {log next : RuntimeOramWriteLogDiscipline.Log}
  (h : RuntimeOramWriteLogDiscipline.pushUpdate log = some next) :
  next.overflowed = log.overflowed := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogPushUpdatePreservesOverflowFlag
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogExactBatchNoOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeOramWriteLogDiscipline.Parameters}
  {log : RuntimeOramWriteLogDiscipline.Log}
  (h : RuntimeOramWriteLogDiscipline.exactBatchAccepted parameters log) :
  log.overflowed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogExactBatchNoOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramWriteLogExactUpdateBatchNoOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeOramWriteLogDiscipline.Parameters}
  {log : RuntimeOramWriteLogDiscipline.Log}
  (h : RuntimeOramWriteLogDiscipline.exactUpdateBatchAccepted parameters log) :
  log.overflowed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramWriteLogExactUpdateBatchNoOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramReadTranscriptPushRejectsAtLogicalCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {builder : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h : builder.capacity ≤ builder.logicalLen) :
  RuntimeOramWriteLogDiscipline.pushReadTranscriptPair builder = none := by
  exact
    RuntimePaperNativeKernelAssumptions.oramReadTranscriptPushRejectsAtLogicalCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramReadTranscriptPushRejectsAtPhysicalReadCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {builder : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h : builder.capacity ≤ builder.physicalReadLen) :
  RuntimeOramWriteLogDiscipline.pushReadTranscriptPair builder = none := by
  exact
    RuntimePaperNativeKernelAssumptions.oramReadTranscriptPushRejectsAtPhysicalReadCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramReadTranscriptPushPreservesCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {builder next : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h :
    RuntimeOramWriteLogDiscipline.pushReadTranscriptPair builder =
      some next) :
  next.capacity = builder.capacity := by
  exact
    RuntimePaperNativeKernelAssumptions.oramReadTranscriptPushPreservesCapacity
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramReadTranscriptPushPreservesOverflowFlag
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {builder next : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h :
    RuntimeOramWriteLogDiscipline.pushReadTranscriptPair builder =
      some next) :
  next.overflowed = builder.overflowed := by
  exact
    RuntimePaperNativeKernelAssumptions.oramReadTranscriptPushPreservesOverflowFlag
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeOramReadTranscriptExactTranscriptNoOverflow
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {parameters : RuntimeOramWriteLogDiscipline.Parameters}
  {builder : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h :
    RuntimeOramWriteLogDiscipline.exactReadTranscriptAccepted
      parameters builder) :
  builder.overflowed = false := by
  exact
    RuntimePaperNativeKernelAssumptions.oramReadTranscriptExactTranscriptNoOverflow
      (boundary.toRuntimePaperNativeKernelAssumptions hValid) h

theorem importedBoundaryPaperNativeKernelStateRefinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.runtimeKernelBoundary.kernelWitness := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_kernel_state_refinement
      hValid

theorem importedBoundaryPaperNativeShellTraceRefinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let assumptions := boundary.toRuntimePaperNativeKernelAssumptions hValid
  assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
    assumptions.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_native_shell_trace_refinement
      hValid

theorem importedBoundaryStoreCodecTransportShape
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes : ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  (RuntimeStoreCodecSemantics.encodeNonzero bytes).length = 2 * bytes.length ∧
    ∀ nibble,
      nibble ∈ RuntimeStoreCodecSemantics.encodeNonzero bytes →
        RuntimeStoreCodecSemantics.ValidEncodedNibble nibble := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecTransportShape
      hValid hBytes

theorem importedBoundaryStoreCodecDecodeSound
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeSound
      hValid hDecode

theorem importedBoundaryStoreCodecDecodeIntoRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes : ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeNonzeroInto?
      bytes.length (RuntimeStoreCodecSemantics.encodeNonzero bytes) =
    some bytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeIntoRoundtrip
      hValid hBytes

theorem importedBoundaryStoreCodecDecodeIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {byteLen : Nat}
  {encoded : List Nat}
  (hLen : encoded.length ≠ 2 * byteLen) :
  RuntimeStoreCodecSemantics.decodeNonzeroInto? byteLen encoded = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeIntoRejectsLengthMismatch
      hValid hLen

theorem importedBoundaryStoreCodecDecodeIntoSound
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeCodecDecodeIntoSound
      hValid hDecode

theorem importedBoundaryStoreSealedEncodedLen
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen =
    2 * (RuntimeStoreCodecSemantics.sealedMagicLen +
      RuntimeStoreCodecSemantics.sealedNonceBytes +
      payloadLen +
      RuntimeStoreCodecSemantics.sealedTagBytes) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedEncodedLen
      hValid payloadLen

theorem importedBoundaryStoreSealedPlainLen
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealedPlainLen payloadLen =
    RuntimeStoreCodecSemantics.sealedMagicLen +
      RuntimeStoreCodecSemantics.sealedNonceBytes +
      payloadLen +
      RuntimeStoreCodecSemantics.sealedTagBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedPlainLen
      hValid payloadLen

theorem importedBoundaryStoreSealedRecordDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordDecodeShape
      hValid hDecode hEncodedLen

theorem importedBoundaryStoreSealedRecordOpenShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenShape
      hValid hDecode

theorem importedBoundaryStoreSealedRecordRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  (hLen :
    encoded.length ≠ RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsLengthMismatch
      hValid hLen

theorem importedBoundaryStoreSealedRecordOpenTransportSound
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordOpenTransportSound
      hValid hDecode

theorem importedBoundaryStoreUoSlotCiphertextShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoSlotCiphertextShape
      hValid hDecode

theorem importedBoundaryStoreSealedRecordTransportRoundtrip
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordTransportRoundtrip
      hValid hOpenShape hBytes

theorem importedBoundaryStoreSealedRecordEncodedLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hShape : parts.ValidShape payloadLen) :
  (RuntimeStoreCodecSemantics.encodeNonzero parts.bytes).length =
      RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordEncodedLength
      hValid hShape

theorem importedBoundaryStoreEncodedUoSlotCiphertextShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeEncodedUoSlotCiphertextShape
      hValid hShape hBytes

theorem importedBoundaryStoreSealedRecordRejectsWrongMagic
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeSealedRecordRejectsWrongMagic
      hValid hShape hMagic hBytes

theorem importedBoundaryStoreUoUpdateWriteShapeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
    (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWriteShapeAccepted
      hValid object slotLen

theorem importedBoundaryStoreUoUpdateWritePublicShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_storeUoUpdateWritePublicShape
      hValid hAccepted

theorem importedBoundaryOramWriteLogExactBatchFillsPublicCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (_hValid : boundary.Valid)
  {parameters : RuntimeOramWriteLogDiscipline.Parameters}
  {log : RuntimeOramWriteLogDiscipline.Log}
  (h :
    RuntimeOramWriteLogDiscipline.exactBatchAccepted parameters log) :
  log.len = RuntimeOramWriteLogDiscipline.writeLogCapacity parameters :=
  RuntimeImplementationInterface.oramWriteLogModel_exactBatchFillsPublicCapacity h

theorem importedBoundaryOramReadTranscriptExactBuilderFillsPublicCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (_hValid : boundary.Valid)
  {parameters : RuntimeOramWriteLogDiscipline.Parameters}
  {builder : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h :
    RuntimeOramWriteLogDiscipline.exactReadTranscriptAccepted
      parameters builder) :
  builder.logicalLen =
      RuntimeOramWriteLogDiscipline.readTranscriptCapacity parameters ∧
    builder.physicalReadLen =
      RuntimeOramWriteLogDiscipline.readTranscriptCapacity parameters :=
  RuntimeImplementationInterface.oramReadTranscriptModel_exactTranscriptFillsPublicCapacity h

theorem importedBoundaryOramReadTranscriptBuilderPushBounded
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (_hValid : boundary.Valid)
  {builder next : RuntimeOramWriteLogDiscipline.ReadTranscriptBuilder}
  (h :
    RuntimeOramWriteLogDiscipline.pushReadTranscriptPair builder =
      some next) :
  builder.logicalLen < builder.capacity ∧
    builder.physicalReadLen < builder.capacity :=
  RuntimeImplementationInterface.oramReadTranscriptModel_pushAcceptsOnlyBelowCapacity h

theorem importedBoundaryOramCounterFieldBytesMatchSlotIndex
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramCodecSemantics.counterFieldBytes =
    RuntimeOramCodecSemantics.slotIndexBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterFieldBytesMatchSlotIndex
      hValid

theorem importedBoundaryOramSurrogateBlockBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.surrogateBlockBytes keyBytes valueBytes =
    RuntimeOramCodecSemantics.occupancyTagBytes + keyBytes + valueBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBlockBytesPublicFormula
      hValid keyBytes valueBytes

theorem importedBoundaryOramPathBlockBytesPublicFormula
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBlockBytesPublicFormula
      hValid keyBytes valueBytes

theorem importedBoundaryOramBucketBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket blockBytes : Nat) :
  RuntimeOramCodecSemantics.bucketBytes blocksPerBucket blockBytes =
    oramBucketHeaderBytes +
      blocksPerBucket * blockBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesPublicFormula
      hValid blocksPerBucket blockBytes

theorem importedBoundaryOramBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketBytesMatchCodec
      hValid hObject

theorem importedBoundaryOramSurrogateBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedSurrogateOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramSurrogateBucketBytesMatchCodec
      hValid hObject

theorem importedBoundaryOramPathBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedPathOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPathBucketBytesMatchCodec
      hValid hObject

theorem importedBoundaryOramDirectoryPageBytesPublicFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (blockBytes : Nat) :
  RuntimeOramCodecSemantics.directoryPageBytes blockBytes =
    RuntimeOramCodecSemantics.directoryPageEntries * blockBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDirectoryPageBytesPublicFormula
      hValid blockBytes

theorem importedBoundaryOramPublicCountGuardAcceptsExact
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (expected : Nat) :
  RuntimeOramCodecSemantics.publicCountGuard? expected expected = some () := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramPublicCountGuardAcceptsExact
      hValid expected

theorem importedBoundaryOramDirectoryPagesRejectCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDirectoryPagesRejectCountMismatch
      hValid hCount

theorem importedBoundaryOramBucketsRejectCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketsRejectCountMismatch
      hValid hCount

theorem importedBoundaryPathPositionMapBufferRejectsCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapBufferRejectsCountMismatch
      hValid hCount

theorem importedBoundaryPathLiveSlotsRejectCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathLiveSlotsRejectCountMismatch
      hValid hCount

theorem importedBoundaryOramCodecBucketHeaderBytesMatchesRuntimeHeader
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramCodecSemantics.codecBucketHeaderBytes =
    oramBucketHeaderBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketHeaderBytesMatchesRuntimeHeader
      hValid

theorem importedBoundaryOramCodecBlockBytesSurrogateMatchesFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBlockBytes false keyBytes valueBytes =
    RuntimeOramCodecSemantics.surrogateBlockBytes keyBytes valueBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesSurrogateMatchesFormula
      hValid keyBytes valueBytes

theorem importedBoundaryOramCodecBlockBytesPathMatchesFormula
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBlockBytes true keyBytes valueBytes =
    RuntimeOramCodecSemantics.pathBlockBytes keyBytes valueBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBlockBytesPathMatchesFormula
      hValid keyBytes valueBytes

theorem importedBoundaryOramCodecBucketBytesMatchesRuntimeBucketBytes
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCodecBucketBytesMatchesRuntimeBucketBytes
      hValid isPath blocksPerBucket keyBytes valueBytes

theorem importedBoundaryOramCounterEncodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.CounterDecodeAccepted
    (RuntimeOramCodecSemantics.encodeCounterField counter) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeAccepted
      hValid counter

theorem importedBoundaryOramCounterEncodeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  (RuntimeOramCodecSemantics.encodeCounterField counter).length =
    RuntimeOramCodecSemantics.counterFieldBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeLength
      hValid counter

theorem importedBoundaryOramCounterEncodeValidBytes
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.ValidByteField
    (RuntimeOramCodecSemantics.encodeCounterField counter) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterEncodeValidBytes
      hValid counter

theorem importedBoundaryOramCounterDecodeExactEncode
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.decodeCounterExact?
      (RuntimeOramCodecSemantics.encodeCounterField counter) =
    some
      (RuntimeOramCodecSemantics.decodeNatField
        (RuntimeOramCodecSemantics.encodeCounterField counter)) := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeExactEncode
      hValid counter

theorem importedBoundaryOramCounterDecodeAccepted
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter)
  (hBytes : RuntimeOramCodecSemantics.ValidByteField bytes) :
  RuntimeOramCodecSemantics.CounterDecodeAccepted bytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeAccepted
      hValid hDecode hBytes

theorem importedBoundaryOramCounterDecodeLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter) :
  bytes.length = RuntimeOramCodecSemantics.counterFieldBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeLength
      hValid hDecode

theorem importedBoundaryOramCounterDecodeValue
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter) :
  counter = RuntimeOramCodecSemantics.decodeNatField bytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramCounterDecodeValue
      hValid hDecode

theorem importedBoundaryOramBlockCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock : block.ValidShape isPath keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodeBlock?
      isPath keyBytes valueBytes
      (RuntimeOramCodecSemantics.encodeBlock isPath block) =
    some block := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBlockCodecRoundtrip
      hValid hBlock

theorem importedBoundaryOramExactBlockCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock : block.ValidShape isPath keyBytes valueBytes) :
  RuntimeOramCodecSemantics.decodeBlockExact?
      isPath keyBytes valueBytes
      (RuntimeOramCodecSemantics.encodeBlock isPath block) =
    some block := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockCodecRoundtrip
      hValid hBlock

theorem importedBoundaryOramExactBlockDecodeLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeLength
      hValid hDecode

theorem importedBoundaryOramExactBlockDecodeValidShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlockDecodeValidShape
      hValid hDecode

theorem importedBoundaryOramEncodeBlockLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock : block.ValidShape isPath keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBlock isPath block).length =
    RuntimeOramCodecSemantics.codecBlockBytes
      isPath keyBytes valueBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlockLength
      hValid hBlock

theorem importedBoundaryOramEncodeBlocksLength
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramEncodeBlocksLength
      hValid hBlocks

theorem importedBoundaryOramExactBlocksDecodeCount
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlocksDecodeCount
      hValid hDecode

theorem importedBoundaryOramExactBlocksCodecRoundtrip
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBlocksCodecRoundtrip
      hValid hBlocks

theorem importedBoundaryOramBucketCodecLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes : Nat}
  {bucket : RuntimeOramCodecSemantics.CodecBucket}
  (hBucket : bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBucket isPath bucket).length =
    RuntimeOramCodecSemantics.codecBucketBytes
      isPath blocksPerBucket keyBytes valueBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramBucketCodecLength
      hValid hBucket

theorem importedBoundaryOramExactBucketCodecRoundtrip
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes expectedBucketIndex : Nat}
  {bucket : RuntimeOramCodecSemantics.CodecBucket}
  (hBucket : bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes)
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketCodecRoundtrip
      hValid hBucket hBucketIndex hLiveCount

theorem importedBoundaryOramExactBucketDecodeAccepted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeAccepted
      hValid hDecode

theorem importedBoundaryOramExactBucketDecodeBlockValidShapes
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramExactBucketDecodeBlockValidShapes
      hValid hDecode

theorem importedBoundaryPathBucketBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPathBucketPathBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketPathBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPathBucketPositionMapBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketPositionMapBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPathBucketUniquePositionMapBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBucketUniquePositionMapBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPathPositionMapLiveSlotCoverage
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLiveSlotCoverage
      hValid hCheck

theorem importedBoundaryPathBlocksPositionMapAgreement
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBlocksPositionMapAgreement
      hValid hCheck

theorem importedBoundaryPathBlocksNoDuplicateLiveSlots
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPathBlocksNoDuplicateLiveSlots blocks =
      true) :
  RuntimeOramCodecSemantics.LiveSlotNoDuplicates blocks := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathBlocksNoDuplicateLiveSlots
      hValid hCheck

theorem importedBoundaryOramDecodedBucketPayloadAccepted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_oramDecodedBucketPayloadAccepted
      hValid hIndex hBlocks hLive

theorem importedBoundaryPathPositionMapPagesCoverCapacity
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  capacity ≤
    RuntimeOramCodecSemantics.pathPositionMapPages capacity *
      RuntimeOramCodecSemantics.directoryPageEntries := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCoverCapacity
      hValid capacity

theorem importedBoundaryPathPositionMapPagesPositive
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  0 < RuntimeOramCodecSemantics.pathPositionMapPages capacity := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesPositive
      hValid capacity

theorem importedBoundaryPathMetadataPageSplit
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathMetadataPageSplit
      hValid hPages

theorem importedBoundaryPositionMapDecodeAccepted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_positionMapDecodeAccepted
      hValid hCapacity hLeaves

theorem importedBoundaryPathPositionMapLeafDecodeBounded
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapLeafDecodeBounded
      hValid hDecode

theorem importedBoundaryPathPositionMapEntriesDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapEntriesDecodeShape
      hValid hDecode

theorem importedBoundaryPathPositionMapPageDecodeAccepted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageDecodeAccepted
      hValid hDecode

theorem importedBoundaryPathPositionMapPageRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes : Nat}
  {bytes : List Nat}
  (hLen : bytes.length ≠ directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathPositionMapPageExact?
      leafCount directoryPageBytes bytes = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageRejectsLengthMismatch
      hValid hLen

theorem importedBoundaryPathPositionMapPagesAllDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesAllDecodeShape
      hValid hDecode

theorem importedBoundaryPathPositionMapPagesDecodeAccepted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesDecodeAccepted
      hValid hDecode

theorem importedBoundaryPathPositionMapPagesRejectsPageCountMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes capacity : Nat}
  {pages : List (List Nat)}
  (hCount :
    pages.length ≠ RuntimeOramCodecSemantics.pathPositionMapPages capacity) :
  RuntimeOramCodecSemantics.decodePathPositionMapPagesExact?
      leafCount directoryPageBytes capacity pages = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesRejectsPageCountMismatch
      hValid hCount

theorem importedBoundaryPathPositionMapPageLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {directoryPageBytes : Nat}
  {positionMapPrefixBytes : List Nat}
  (hLen : positionMapPrefixBytes.length ≤ directoryPageBytes) :
  (RuntimeOramCodecSemantics.encodePathPositionMapPageBytes
      directoryPageBytes positionMapPrefixBytes).length =
    directoryPageBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageLength
      hValid hLen

theorem importedBoundaryPathPositionMapPageCodecRoundtrip
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPageCodecRoundtrip
      hValid hFields hEntryCount hDirectoryBytes

theorem importedBoundaryPathPositionMapPagesCodecRoundtrip
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathPositionMapPagesCodecRoundtrip
      hValid hPages hPageCount hDirectoryBytes

theorem importedBoundaryPathStashPageLength
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {directoryPageBytes : Nat}
  {stashBlockBytes : List Nat}
  (hLen : stashBlockBytes.length ≤ directoryPageBytes) :
  (RuntimeOramCodecSemantics.encodePathStashPageBytes
      directoryPageBytes stashBlockBytes).length =
    directoryPageBytes := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageLength
      hValid hLen

theorem importedBoundaryPathStashPageCodecRoundtrip
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageCodecRoundtrip
      hValid hBlockCount hBlocks hDirectoryBytes

theorem importedBoundaryPathStashPagesCodecRoundtrip
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesCodecRoundtrip
      hValid hPages hPageCount hDirectoryBytes

theorem importedBoundaryPathStashPageDecodeAccepted
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeAccepted
      hValid hDecode

theorem importedBoundaryPathStashPageRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes : Nat}
  {bytes : List Nat}
  (hLen : bytes.length ≠ directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathStashPageExact?
      isPath keyBytes valueBytes directoryPageBytes bytes = none := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageRejectsLengthMismatch
      hValid hLen

theorem importedBoundaryPathStashPageDecodeBlockValidShapes
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPageDecodeBlockValidShapes
      hValid hDecode

theorem importedBoundaryPathStashPagesDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesDecodeShape
      hValid hDecode

theorem importedBoundaryPathStashPagesRejectsPageCountMismatch
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesRejectsPageCountMismatch
      hValid hCount

theorem importedBoundaryPathStashPagesAllDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesAllDecodeShape
      hValid hDecode

theorem importedBoundaryPathStashPagesBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPathStashPagesPositionMapBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesPositionMapBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPathStashPagesUniquePositionMapBoundedDecodeShape
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_pathStashPagesUniquePositionMapBoundedDecodeShape
      hValid hDecode

theorem importedBoundaryPaperEndToEndMachineConfinement
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_end_to_end_confinement
      hValid

theorem importedBoundaryPaperEndToEndMachineConfinementWithPublicOnlyHandwrittenShell
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_end_to_end_confinement_with_public_only_handwritten_shell
      hValid

theorem importedBoundaryPaperPublicBridgeObserverRefinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.PublicBridgeBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_public_bridge_observer_refinement
      hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellRefinement
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paperPublicOnlyResidualHelperShellRefinement
      hValid

theorem importedBoundaryPaperPublicOnlyResidualHelperShellObserverRefinement
  {boundary : ImportedRuntimeImplementationKernelMachineConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationKernelMachineConfinementBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary ∧
    runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelMachineFinishBoundary.runtimeKernelFinishSlotBoundary.confinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paperPublicOnlyResidualHelperShellObserverRefinement
      hValid

theorem importedBoundaryPaperSlotAdapterMachineRefinement
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
    importedRuntimeImplementationKernelMachineConfinementBoundary_valid_paper_slot_adapter_machine_refinement
      hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationKernelMachineConfinementBoundary path
      IO.println
        s!"validated runtime implementation kernel machine confinement boundary for {boundary.confidential_slot_program.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
