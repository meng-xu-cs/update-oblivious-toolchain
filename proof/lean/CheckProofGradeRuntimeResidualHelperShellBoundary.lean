import UOToolchain.ProofGrade
import UOToolchain.RuntimeImplementationInterfaceJson

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeResidualHelperShellBoundary <boundary.json>"

theorem importedBoundaryResidualHelperShellConfinement
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
      boundary hValid

theorem importedBoundaryHandwrittenRuntimePublicOnly
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHandwrittenConfidentialWorkLivesOnlyInGeneratedHelpers := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_handwrittenRuntimePublicOnly
      hValid

theorem importedBoundaryHostVisibleErrorTaxonomy
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.runtimeHostVisibleErrorsUsePublicIntegrityTaxonomy := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_hostVisibleErrorTaxonomy
      hValid

theorem importedBoundaryGeneratedObjectHelpersMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedObjectHelpersMatchLeanGenerator := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedObjectHelpersMatchLeanGenerator
      hValid

theorem importedBoundaryGeneratedOramCodecsMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedOramCodecsMatchLeanGenerator := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedOramCodecsMatchLeanGenerator
      hValid

theorem importedBoundaryGeneratedStoreCodecMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedStoreCodecMatchLeanGenerator := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedStoreCodecMatchLeanGenerator
      hValid

theorem importedBoundaryGeneratedStoreSurfaceMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedStoreSurfaceMatchLeanGenerator := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedStoreSurfaceMatchLeanGenerator
      hValid

theorem importedBoundaryGeneratedStoreHelpersMatchLeanGenerator
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary :=
    boundary.toRuntimeImplementationResidualHelperShellBoundary hValid
  runtimeBoundary.implementationInterface.generatedStoreHelpersMatchLeanGenerator := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_valid_generatedStoreHelpersMatchLeanGenerator
      hValid

theorem importedBoundaryStoreCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes :
    ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeNonzero
      (RuntimeStoreCodecSemantics.encodeNonzero bytes) =
    some bytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeCodecRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hBytes

theorem importedBoundaryStoreCodecTransportShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes :
    ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  (RuntimeStoreCodecSemantics.encodeNonzero bytes).length = 2 * bytes.length ∧
    ∀ nibble,
      nibble ∈ RuntimeStoreCodecSemantics.encodeNonzero bytes →
        RuntimeStoreCodecSemantics.ValidEncodedNibble nibble := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeCodecTransportShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hBytes

theorem importedBoundaryStoreCodecDecodeSound
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeCodecDecodeSound
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode

theorem importedBoundaryStoreCodecDecodeIntoRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  (hBytes :
    ∀ byte, byte ∈ bytes → RuntimeStoreCodecSemantics.ValidByte byte) :
  RuntimeStoreCodecSemantics.decodeNonzeroInto?
      bytes.length (RuntimeStoreCodecSemantics.encodeNonzero bytes) =
    some bytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeCodecDecodeIntoRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hBytes

theorem importedBoundaryStoreCodecDecodeIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {byteLen : Nat}
  {encoded : List Nat}
  (hLen : encoded.length ≠ 2 * byteLen) :
  RuntimeStoreCodecSemantics.decodeNonzeroInto? byteLen encoded = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeCodecDecodeIntoRejectsLengthMismatch
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hLen

theorem importedBoundaryStoreCodecDecodeIntoSound
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeCodecDecodeIntoSound
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode

theorem importedBoundaryStoreSealedEncodedLen
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen =
    2 * (RuntimeStoreCodecSemantics.sealedMagicLen +
      RuntimeStoreCodecSemantics.sealedNonceBytes +
      payloadLen +
      RuntimeStoreCodecSemantics.sealedTagBytes) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedEncodedLen
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      payloadLen

theorem importedBoundaryStoreSealedPlainLen
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealedPlainLen payloadLen =
    RuntimeStoreCodecSemantics.sealedMagicLen +
      RuntimeStoreCodecSemantics.sealedNonceBytes +
      payloadLen +
      RuntimeStoreCodecSemantics.sealedTagBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedPlainLen
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      payloadLen

theorem importedBoundaryStoreSealedRecordDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordDecodeShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode hEncodedLen

theorem importedBoundaryStoreSealedRecordOpenShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordOpenShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode

theorem importedBoundaryStoreSealedRecordRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {encoded : List Nat}
  (hLen :
    encoded.length ≠ RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  RuntimeStoreCodecSemantics.decodeSealedRecord? payloadLen encoded = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordRejectsLengthMismatch
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hLen

theorem importedBoundaryStoreSealedRecordOpenTransportSound
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordOpenTransportSound
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode

theorem importedBoundaryStoreUoSlotCiphertextShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeUoSlotCiphertextShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode

theorem importedBoundaryStoreSealedRecordTransportRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordTransportRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hOpenShape hBytes

theorem importedBoundaryStoreSealedRecordEncodedLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {payloadLen : Nat}
  {parts : RuntimeStoreCodecSemantics.SealedRecordParts}
  (hShape : parts.ValidShape payloadLen) :
  (RuntimeStoreCodecSemantics.encodeNonzero parts.bytes).length =
      RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordEncodedLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hShape

theorem importedBoundaryStoreEncodedUoSlotCiphertextShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeEncodedUoSlotCiphertextShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hShape hBytes

theorem importedBoundaryStoreSealedRecordRejectsWrongMagic
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSealedRecordRejectsWrongMagic
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hShape hMagic hBytes

theorem importedBoundaryStoreSurfaceZeroedBytesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (len : Nat) :
  (RuntimeStoreCodecSemantics.zeroedBytes len).length = len := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceZeroedBytesLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      len

theorem importedBoundaryStoreSurfaceZeroedBytesValid
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (len : Nat) :
  ∀ byte,
    byte ∈ RuntimeStoreCodecSemantics.zeroedBytes len →
      RuntimeStoreCodecSemantics.ValidByte byte := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceZeroedBytesValid
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      len

theorem importedBoundaryStoreSurfaceReadExactRangeLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes out : List Nat}
  {start len : Nat}
  (hRead :
    RuntimeStoreCodecSemantics.readExactRange? bytes start len =
      some out) :
  out.length = len := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceReadExactRangeLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hRead

theorem importedBoundaryStoreSurfaceReadExactRangeRejectsOutOfRange
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {start len : Nat}
  (hRange : ¬ start + len ≤ bytes.length) :
  RuntimeStoreCodecSemantics.readExactRange? bytes start len = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceReadExactRangeRejectsOutOfRange
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hRange

theorem importedBoundaryStoreSurfaceCopyExactIntoShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {out input copied : List Nat}
  (hCopy :
    RuntimeStoreCodecSemantics.copyExactInto? out input =
      some copied) :
  copied = input ∧ copied.length = out.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceCopyExactIntoShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hCopy

theorem importedBoundaryStoreSurfaceCopyExactIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {out input : List Nat}
  (hLen : out.length ≠ input.length) :
  RuntimeStoreCodecSemantics.copyExactInto? out input = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceCopyExactIntoRejectsLengthMismatch
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hLen

theorem importedBoundaryStoreSurfaceSealIntoAcceptsExactLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (payloadLen : Nat) :
  RuntimeStoreCodecSemantics.sealAndWipeIntoSliceAccepted payloadLen
    (RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceSealIntoAcceptsExactLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      payloadLen

theorem importedBoundaryStoreSurfaceSealIntoRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {payloadLen outLen : Nat}
  (hLen :
    outLen ≠ RuntimeStoreCodecSemantics.sealedEncodedLen payloadLen) :
  ¬ RuntimeStoreCodecSemantics.sealAndWipeIntoSliceAccepted
      payloadLen outLen := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceSealIntoRejectsLengthMismatch
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hLen

theorem importedBoundaryStoreSurfaceOpenPayloadShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceOpenPayloadShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hDecode

theorem importedBoundaryStoreSurfaceWipePreservesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (bytes : List Nat) :
  (RuntimeStoreCodecSemantics.wipeBytes bytes).length = bytes.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceWipePreservesLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      bytes

theorem importedBoundaryStoreSurfaceWipeZeros
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {byte : Nat}
  (hMem : byte ∈ RuntimeStoreCodecSemantics.wipeBytes bytes) :
  byte = 0 := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeSurfaceWipeZeros
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hMem

theorem importedBoundaryStoreHelperTakeRawValueCopiesInput
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).boxed = value := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperTakeRawValueCopiesInput
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      value

theorem importedBoundaryStoreHelperTakeRawValueWipesInputLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).wiped.length =
    value.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperTakeRawValueWipesInputLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      value

theorem importedBoundaryStoreHelperTakeRawValueWipesInputZeros
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {value : List Nat}
  {byte : Nat}
  (hMem :
    byte ∈
      (RuntimeStoreHelperSemantics.takeBoxedRawStoreValue value).wiped) :
  byte = 0 := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperTakeRawValueWipesInputZeros
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hMem

theorem importedBoundaryStoreHelperZeroedRawSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (objects : List String)
  (slotLen : Nat) :
  (RuntimeStoreHelperSemantics.zeroedRawSlots objects slotLen).length =
    objects.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperZeroedRawSlotsLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      objects slotLen

theorem importedBoundaryStoreHelperLookupZeroedRawSlotsShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperLookupZeroedRawSlotsShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hLookup

theorem importedBoundaryStoreHelperInsertOrReplaceLookupSelf
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (slots : List RuntimeStoreHelperSemantics.StoreSlot)
  (object : String)
  (value : List Nat) :
  RuntimeStoreHelperSemantics.lookupSlot object
      (RuntimeStoreHelperSemantics.insertOrReplaceSlot object value slots) =
    some value := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperInsertOrReplaceLookupSelf
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      slots object value

theorem importedBoundaryStoreHelperInsertOrReplaceLengthLeSucc
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (slots : List RuntimeStoreHelperSemantics.StoreSlot)
  (object : String)
  (value : List Nat) :
  (RuntimeStoreHelperSemantics.insertOrReplaceSlot object value slots).length ≤
    slots.length + 1 := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperInsertOrReplaceLengthLeSucc
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      slots object value

theorem importedBoundaryStoreHelperAppendEventLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).length =
    events.length + 1 := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperAppendEventLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      events event

theorem importedBoundaryStoreHelperAppendEventPreservesPrefix
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).take
      events.length =
    events := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperAppendEventPreservesPrefix
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      events event

theorem importedBoundaryStoreHelperAppendEventAppendsSingleton
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (events : List α)
  (event : α) :
  (RuntimeStoreHelperSemantics.appendBoxedEvent events event).drop
      events.length =
    [event] := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperAppendEventAppendsSingleton
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      events event

theorem importedBoundaryStoreHelperAllUpdateAppendUoUpdate
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {events : List RuntimeStoreHelperSemantics.StoreWriteShape}
  (hEvents : RuntimeStoreHelperSemantics.allUpdate events)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreHelperSemantics.allUpdate
    (RuntimeStoreHelperSemantics.appendBoxedEvent events
      (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen)) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperAllUpdateAppendUoUpdate
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hEvents object slotLen

theorem importedBoundaryStoreHelperBootstrappedUoSlotPublicLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (logicalLen : Nat) :
  (RuntimeStoreHelperSemantics.bootstrappedUoSlotShape object logicalLen).value.length =
    RuntimeStoreCodecSemantics.sealedEncodedLen logicalLen := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperBootstrappedUoSlotPublicLength
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      object logicalLen

theorem importedBoundaryStoreHelperBootstrappedUoSlotValidBytes
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (logicalLen : Nat) :
  ∀ byte,
    byte ∈
        (RuntimeStoreHelperSemantics.bootstrappedUoSlotShape object logicalLen).value →
      RuntimeStoreCodecSemantics.ValidByte byte := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperBootstrappedUoSlotValidBytes
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      object logicalLen

theorem importedBoundaryStoreHelperResealTracePublicUpdateShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreHelperSemantics.allUpdate
      [RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen] ∧
    RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
      (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperResealTracePublicUpdateShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      object slotLen

theorem importedBoundaryStoreHelperRecordReadIncrementsReadCounts
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics) :
  (RuntimeStoreHelperSemantics.recordStoreRead metrics).logicalReads =
      metrics.logicalReads + 1 ∧
    (RuntimeStoreHelperSemantics.recordStoreRead metrics).physicalReads =
      metrics.physicalReads + 1 := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperRecordReadIncrementsReadCounts
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      metrics

theorem importedBoundaryStoreHelperRecordWriteIncrementsWriteCounts
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (zeroWrite : Bool) :
  (RuntimeStoreHelperSemantics.recordStoreWrite metrics zeroWrite).logicalWrites =
      metrics.logicalWrites + 1 ∧
    (RuntimeStoreHelperSemantics.recordStoreWrite metrics zeroWrite).physicalWrites =
      metrics.physicalWrites + 1 := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperRecordWriteIncrementsWriteCounts
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      metrics zeroWrite

theorem importedBoundaryStoreHelperRecordUoWriteZeroWritesUnchanged
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (object : String)
  (slotLen : Nat) :
  (RuntimeStoreHelperSemantics.recordUoStoreWrite
      metrics object slotLen).metrics.zeroWrites =
    metrics.zeroWrites := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperRecordUoWriteZeroWritesUnchanged
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      metrics object slotLen

theorem importedBoundaryStoreHelperRecordUoWriteEventAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (metrics : RuntimeStoreHelperSemantics.StoreMetrics)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
    (RuntimeStoreHelperSemantics.recordUoStoreWrite
      metrics object slotLen).event := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeHelperRecordUoWriteEventAccepted
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      metrics object slotLen

theorem importedBoundaryStoreUoUpdateWriteShapeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (object : String)
  (slotLen : Nat) :
  RuntimeStoreCodecSemantics.UoStoreUpdateWriteAccepted object slotLen
    (RuntimeStoreCodecSemantics.uoStoreUpdateWriteShape object slotLen) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_storeUoUpdateWriteShapeAccepted
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      object slotLen

theorem importedBoundaryStoreUoUpdateWritePublicShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_storeUoUpdateWritePublicShape
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hAccepted

private abbrev importedBoundaryResidualIface
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) : RuntimeImplementationInterface :=
  (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface

private theorem importedBoundaryResidualShellBoundary
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  (importedBoundaryResidualIface hValid).ResidualHelperShellBoundary := by
  exact
    importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
      boundary hValid

theorem importedBoundaryOramHelperMaskedSelectNatTrue
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Nat) :
  RuntimeOramHelperSemantics.maskedSelectNat true whenTrue whenFalse =
    whenTrue := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectNatTrue
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectNatFalse
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Nat) :
  RuntimeOramHelperSemantics.maskedSelectNat false whenTrue whenFalse =
    whenFalse := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectNatFalse
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectBoolTrue
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeOramHelperSemantics.maskedSelectBool true whenTrue whenFalse =
    whenTrue := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectBoolTrue
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectBoolFalse
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : Bool) :
  RuntimeOramHelperSemantics.maskedSelectBool false whenTrue whenFalse =
    whenFalse := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectBoolFalse
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectOptionTrue
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.maskedSelectOption true whenTrue whenFalse =
    whenTrue := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectOptionTrue
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectOptionFalse
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.maskedSelectOption false whenTrue whenFalse =
    whenFalse := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectOptionFalse
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectTransitionKindTrue
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.PathTransitionKind) :
  RuntimeOramHelperSemantics.maskedSelectTransitionKind
      true whenTrue whenFalse = whenTrue := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectTransitionKindTrue
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperMaskedSelectTransitionKindFalse
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (whenTrue whenFalse : RuntimeOramHelperSemantics.PathTransitionKind) :
  RuntimeOramHelperSemantics.maskedSelectTransitionKind
      false whenTrue whenFalse = whenFalse := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperMaskedSelectTransitionKindFalse
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      whenTrue whenFalse

theorem importedBoundaryOramHelperPathPutTransitionKindDelete
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (insertNew updateExisting : Bool) :
  RuntimeOramHelperSemantics.pathPutTransitionKind
      insertNew updateExisting true =
    RuntimeOramHelperSemantics.PathTransitionKind.writeDelete := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionKindDelete
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      insertNew updateExisting

theorem importedBoundaryOramHelperPathPutTransitionKindUpdate
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (insertNew : Bool) :
  RuntimeOramHelperSemantics.pathPutTransitionKind insertNew true false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeUpdate := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionKindUpdate
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      insertNew

theorem importedBoundaryOramHelperPathPutTransitionKindInsert
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathPutTransitionKind true false false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeInsert := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionKindInsert
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)

theorem importedBoundaryOramHelperPathPutTransitionKindNoop
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathPutTransitionKind false false false =
    RuntimeOramHelperSemantics.PathTransitionKind.writeNoop := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionKindNoop
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)

theorem importedBoundaryOramHelperPathGetTransitionKindHit
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathGetTransitionKind true =
    RuntimeOramHelperSemantics.PathTransitionKind.readHit := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathGetTransitionKindHit
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)

theorem importedBoundaryOramHelperPathGetTransitionKindMiss
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramHelperSemantics.pathGetTransitionKind false =
    RuntimeOramHelperSemantics.PathTransitionKind.readMiss := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathGetTransitionKindMiss
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)

theorem importedBoundaryOramHelperPathGetTransitionFieldsMiss
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathGetTransitionFieldsMiss
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap accessLeaf freshLeaf

theorem importedBoundaryOramHelperPathGetTransitionFieldsHit
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathGetTransitionFieldsHit
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLookup

theorem importedBoundaryOramHelperPathPutTransitionFieldsDelete
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionFieldsDelete
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem importedBoundaryOramHelperPathPutTransitionFieldsUpdate
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionFieldsUpdate
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem importedBoundaryOramHelperPathPutTransitionFieldsInsert
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionFieldsInsert
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      insertSlot accessLeaf nextLeafValue

theorem importedBoundaryOramHelperPathPutTransitionFieldsNoopAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionFieldsNoopAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      valueIsZero insertSlot accessLeaf nextLeafValue

theorem importedBoundaryOramHelperPathPutTransitionFieldsNoopPresentRetainsPrior
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutTransitionFieldsNoopPresentRetainsPrior
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      valueIsZero slotIndex priorLeaf accessLeaf nextLeafValue insertSlot

theorem importedBoundaryOramHelperLiveBlockValidationUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveBlockValidationUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap liveSlots hOccupied

theorem importedBoundaryOramHelperLiveSlotsAfterUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block = liveSlots := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotsAfterUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap liveSlots hOccupied

theorem importedBoundaryOramHelperLiveBlockValidationValidOccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveBlockValidationValidOccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryOramHelperLiveSlotsAfterValidOccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotsAfterValidOccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryOramHelperLiveBlockValidationSlotOutOfRange
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : capacity ≤ block.slotIndex) :
  RuntimeOramHelperSemantics.livePathBlockValidationFailed
      capacity leafCount positionMap liveSlots block = true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveBlockValidationSlotOutOfRange
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot

theorem importedBoundaryOramHelperLiveBlockValidationDuplicateLiveSlot
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveBlockValidationDuplicateLiveSlot
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryOramHelperLiveSlotsAfterValidOccupiedLookup
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotsAfterValidOccupiedLookup
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot hLeaf hPosition hLive

theorem importedBoundaryOramHelperLiveSlotCoverageEmpty
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed [] liveSlots = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotCoverageEmpty
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      liveSlots

theorem importedBoundaryOramHelperLiveSlotCoverageMissingLiveSlot
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (leaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (leaf :: positionMap) [] = true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotCoverageMissingLiveSlot
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      leaf positionMap

theorem importedBoundaryOramHelperLiveSlotCoverageAbsentHead
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (liveSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.noneOption :: positionMap)
      (liveSlot :: liveSlots) =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap liveSlots := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotCoverageAbsentHead
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap liveSlots liveSlot

theorem importedBoundaryOramHelperLiveSlotCoveragePresentLiveHead
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (leaf liveLeaf : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.presentOption leaf :: positionMap)
      (RuntimeOramHelperSemantics.presentOption liveLeaf :: liveSlots) =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap liveSlots := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotCoveragePresentLiveHead
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      leaf liveLeaf positionMap liveSlots

theorem importedBoundaryOramHelperLiveSlotCoveragePresentMissingHead
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (leaf : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.liveSlotCoverageFailed
      (RuntimeOramHelperSemantics.presentOption leaf :: positionMap)
      (RuntimeOramHelperSemantics.noneOption :: liveSlots) = true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotCoveragePresentMissingHead
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      leaf positionMap liveSlots

theorem importedBoundaryOramHelperResetPathEntryCellsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.resetPathEntryCells capacity).length =
    capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperResetPathEntryCellsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity

theorem importedBoundaryOramHelperResetPathEntryCellsAllEmpty
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {capacity : Nat}
  {entry : RuntimeOramHelperSemantics.PathEntryCell}
  (hEntry :
    entry ∈ RuntimeOramHelperSemantics.resetPathEntryCells capacity) :
  entry = RuntimeOramHelperSemantics.emptyPathEntryCell := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperResetPathEntryCellsAllEmpty
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hEntry

theorem importedBoundaryOramHelperInstallPathEntryFailedUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInstallPathEntryFailedUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entries hOccupied

theorem importedBoundaryOramHelperInstallPathEntryFromBlockUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = false) :
  RuntimeOramHelperSemantics.installPathEntryFromBlock entries block =
    entries := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInstallPathEntryFromBlockUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entries hOccupied

theorem importedBoundaryOramHelperInstallPathEntryFailedOutOfRange
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : entries.length ≤ block.slotIndex) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInstallPathEntryFailedOutOfRange
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot

theorem importedBoundaryOramHelperInstallPathEntryFailedValidOccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {entries : List RuntimeOramHelperSemantics.PathEntryCell}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hOccupied : block.occupied = true)
  (hSlot : block.slotIndex < entries.length) :
  RuntimeOramHelperSemantics.installPathEntryFailed entries block = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInstallPathEntryFailedValidOccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot

theorem importedBoundaryOramHelperInstallPathEntryFromBlockPreservesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (entries : List RuntimeOramHelperSemantics.PathEntryCell)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.installPathEntryFromBlock
    entries block).length = entries.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInstallPathEntryFromBlockPreservesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entries block

theorem importedBoundaryOramHelperInstallPathEntryFromBlockValidOccupiedLookup
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInstallPathEntryFromBlockValidOccupiedLookup
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hSlot

theorem importedBoundaryOramHelperReconstructPathBlockStepPriorFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (block : RuntimeOramHelperSemantics.StashBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block = state := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepPriorFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap block hFailed

theorem importedBoundaryOramHelperReconstructPathBlockStepUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap hState hOccupied

theorem importedBoundaryOramHelperReconstructPathBlockStepValidationFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepValidationFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap hState hValidation

theorem importedBoundaryOramHelperReconstructPathBlockStepInstallFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepInstallFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap hState hValidation hInstall

theorem importedBoundaryOramHelperReconstructPathBlockStepValidOccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepValidOccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hState hOccupied hSlot hLeaf hPosition hLive hEntrySlot

theorem importedBoundaryOramHelperReconstructPathFinishFailedPriorFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathFinishFailed
      positionMap state = true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathFinishFailedPriorFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap hFailed

theorem importedBoundaryOramHelperReconstructPathFinishFailedCoverageFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathFinishFailedCoverageFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap hFailed hCoverage

theorem importedBoundaryOramHelperReconstructPathFinishFailedSuccess
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathFinishFailedSuccess
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap hFailed hCoverage

theorem importedBoundaryOramHelperReconstructPathBlocksEmpty
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state [] = state := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksEmpty
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state

theorem importedBoundaryOramHelperReconstructPathBlocksCons
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksCons
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state block blocks

theorem importedBoundaryOramHelperReconstructPathBlocksPriorFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks = state := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksPriorFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap blocks hFailed

theorem importedBoundaryOramHelperInitialReconstructionStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).liveSlots.length =
    capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInitialReconstructionStateLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity

theorem importedBoundaryOramHelperInitialReconstructionStateEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).entries.length =
    capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInitialReconstructionStateEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity

theorem importedBoundaryOramHelperInitialReconstructionStateFailed
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  (RuntimeOramHelperSemantics.initialReconstructionState capacity).failed =
    false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperInitialReconstructionStateFailed
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksStateStashThenBuckets
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksStateStashThenBuckets
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksStateNoBlocks
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksState
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.initialReconstructionState capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksStateNoBlocks
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksStateStashFailureAbsorbs
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksStateStashFailureAbsorbs
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksFailedPriorFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksFailedPriorFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksFailedSuccess
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksFailedSuccess
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed hCoverage

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksFailedStashFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksFailedStashFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed

theorem importedBoundaryOramHelperReconstructPathDecodedBlocksFailedNoBlocks
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBlocksFailed
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed
      positionMap
      (List.replicate capacity RuntimeOramHelperSemantics.noneOption) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBlocksFailedNoBlocks
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap

theorem importedBoundaryOramHelperBucketBlockAdmissionFailedUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (leafCount bucketIndex leaf : Nat) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      { bucketIndex
      , block := { occupied := false, slotIndex := 0, leaf }
      } = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlockAdmissionFailedUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      leafCount bucketIndex leaf

theorem importedBoundaryOramHelperBucketBlockAdmissionFailedOffPath
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlockAdmissionFailedOffPath
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hPath

theorem importedBoundaryOramHelperReconstructPathBucketBlockStepOffPathFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlockStepOffPathFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap hState hAdmission

theorem importedBoundaryOramHelperReconstructPathBucketBlockStepAdmitted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlockStepAdmitted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap hState hAdmission

theorem importedBoundaryOramHelperReconstructPathBucketBlocksPriorFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  {state : RuntimeOramHelperSemantics.ReconstructionState}
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock)
  (hFailed : state.failed = true) :
  RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks = state := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksPriorFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap bucketBlocks hFailed

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateStashThenBuckets
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateStashThenBuckets
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsFailedSuccess
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsFailedSuccess
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks hFailed hCoverage

theorem importedBoundaryOramHelperBucketBlockOfCodecBlockBucketIndex
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (block : RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block).bucketIndex =
    bucketIndex := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlockOfCodecBlockBucketIndex
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      bucketIndex block

theorem importedBoundaryOramHelperBucketBlockOfCodecBlockBlock
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (block : RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block).block =
    RuntimeOramHelperSemantics.stashBlockOfCodecBlock block := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlockOfCodecBlockBlock
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      bucketIndex block

theorem importedBoundaryOramHelperStashBlocksOfCodecBlocksLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks blocks).length =
    blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperStashBlocksOfCodecBlocksLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocks

theorem importedBoundaryOramHelperBucketBlocksOfCodecBlocksLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks).length =
    blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlocksOfCodecBlocksLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      bucketIndex blocks

theorem importedBoundaryOramHelperBucketBlocksOfCodecBlocksMapBlock
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (bucketIndex : Nat)
  (blocks : List RuntimeOramCodecSemantics.CodecBlock) :
  (RuntimeOramHelperSemantics.bucketBlocksOfCodecBlocks bucketIndex blocks).map
      RuntimeOramHelperSemantics.BucketBlock.block =
    RuntimeOramHelperSemantics.stashBlocksOfCodecBlocks blocks := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlocksOfCodecBlocksMapBlock
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      bucketIndex blocks

theorem importedBoundaryOramHelperBucketBlockAdmissionFailedBridgeUnoccupied
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hUnoccupied : block.occupiedTag ≠ 1) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block) =
    false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlockAdmissionFailedBridgeUnoccupied
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hUnoccupied

theorem importedBoundaryOramHelperBucketBlockAdmissionFailedBridgeLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {leafCount bucketIndex : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hLive : block.LiveOnBucketPath leafCount bucketIndex) :
  RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
      (RuntimeOramHelperSemantics.bucketBlockOfCodecBlock bucketIndex block) =
    false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlockAdmissionFailedBridgeLiveOnBucketPath
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLive

theorem importedBoundaryOramHelperBucketBlocksOfCodecBlocksAdmittedOfLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlocksOfCodecBlocksAdmittedOfLiveOnBucketPath
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLive

theorem importedBoundaryOramHelperReconstructPathBucketBlocksEqReconstructPathBlocksOfAdmitted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksEqReconstructPathBlocksOfAdmitted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state bucketBlocks hAdmit

theorem importedBoundaryOramHelperReconstructPathBucketBlocksBucketBlocksOfCodecBlocks
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksBucketBlocksOfCodecBlocks
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap state codecBlocks hLive

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateBucketBlocksOfCodecBlocks
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateBucketBlocksOfCodecBlocks
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap stashBlocks codecBlocks hLive

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsFailedBucketBlocksOfCodecBlocks
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsFailedBucketBlocksOfCodecBlocks
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap stashBlocks codecBlocks hLive

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPathBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPathBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode positionMap stashBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPathBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPathBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode positionMap stashBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPositionMapBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketPositionMapBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode positionMap stashBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPositionMapBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketPositionMapBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode positionMap stashBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateDecodedPathBucketUniquePositionMapBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateDecodedPathBucketUniquePositionMapBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode positionMap stashBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketUniquePositionMapBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsFailedDecodedPathBucketUniquePositionMapBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode positionMap stashBlocks

theorem importedBoundaryOramHelperReconstructPathBucketBlocksAppend
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksAppend
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state xs ys

theorem importedBoundaryOramHelperReconstructPathBlocksAppend
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksAppend
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state xs ys

theorem importedBoundaryOramHelperReconstructPathBucketBlocksBucketBlocksOfDecodedBuckets
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksBucketBlocksOfDecodedBuckets
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state decodedBuckets hLive

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListStateLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListStateLiveOnBucketPath
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hLive

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListFailedLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListFailedLiveOnBucketPath
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hLive

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListFailedPriorFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListFailedPriorFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hFailed

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListFailedSuccess
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListFailedSuccess
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets hFailed hCoverage

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListStateNoBuckets
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.initialReconstructionState capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListStateNoBuckets
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListFailedNoBuckets
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap [] [] =
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (List.replicate capacity RuntimeOramHelperSemantics.noneOption) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListFailedNoBuckets
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap

theorem importedBoundaryOramHelperDecodedBucketsLiveOnBucketPathCons
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperDecodedBucketsLiveOnBucketPathCons
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hHead hTail

theorem importedBoundaryOramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPathBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPathBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPositionMapBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketPositionMapBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketUniquePositionMapBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperDecodedBucketLiveOnBucketPathOfDecodedPathBucketUniquePositionMapBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramHelperLiveSlotsAfterBlockValidationLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap liveSlots : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.liveSlotsAfterBlockValidation
      capacity leafCount positionMap liveSlots block).length =
    liveSlots.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperLiveSlotsAfterBlockValidationLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap liveSlots block

theorem importedBoundaryOramHelperReconstructPathBlockStepLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state block

theorem importedBoundaryOramHelperReconstructPathBlockStepEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlockStep
      capacity leafCount positionMap state block).entries.length =
    state.entries.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state block

theorem importedBoundaryOramHelperReconstructPathBlocksLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state blocks

theorem importedBoundaryOramHelperReconstructPathBlocksEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBlocks
      capacity leafCount positionMap state blocks).entries.length =
    state.entries.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state blocks

theorem importedBoundaryOramHelperReconstructPathBucketBlockStepLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlock : RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlockStepLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state bucketBlock

theorem importedBoundaryOramHelperReconstructPathBucketBlockStepEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlock : RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlockStep
      capacity leafCount positionMap state bucketBlock).entries.length =
    state.entries.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlockStepEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state bucketBlock

theorem importedBoundaryOramHelperReconstructPathBucketBlocksLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks).liveSlots.length =
    state.liveSlots.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state bucketBlocks

theorem importedBoundaryOramHelperReconstructPathBucketBlocksEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathBucketBlocks
      capacity leafCount positionMap state bucketBlocks).entries.length =
    state.entries.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state bucketBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      bucketBlocks).liveSlots.length = capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStateEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (bucketBlocks : List RuntimeOramHelperSemantics.BucketBlock) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
      capacity leafCount positionMap stashBlocks
      bucketBlocks).entries.length = capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStateEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListStateLiveSlotsLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks
      decodedBuckets).liveSlots.length = capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListStateLiveSlotsLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListStateEntriesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (stashBlocks : List RuntimeOramHelperSemantics.StashBlock)
  (decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket) :
  (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
      capacity leafCount positionMap stashBlocks
      decodedBuckets).entries.length = capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListStateEntriesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets

theorem importedBoundaryOramHelperReconstructPathBlockStepPreservesNonFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlockStepPreservesNonFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hState hValidation hInstall

theorem importedBoundaryOramHelperReconstructPathBucketBlockStepPreservesNonFailureAdmitted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlockStepPreservesNonFailureAdmitted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hState hAdmission hValidation hInstall

theorem importedBoundaryOramHelperStashWellFormedFromNil
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.StashWellFormedFrom
    capacity leafCount positionMap state [] := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperStashWellFormedFromNil
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state

theorem importedBoundaryOramHelperBucketBlocksWellFormedFromNil
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity leafCount : Nat)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (state : RuntimeOramHelperSemantics.ReconstructionState) :
  RuntimeOramHelperSemantics.BucketBlocksWellFormedFrom
    capacity leafCount positionMap state [] := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlocksWellFormedFromNil
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state

theorem importedBoundaryOramHelperReconstructPathBlocksPreservesNonFailureOfWellFormed
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBlocksPreservesNonFailureOfWellFormed
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state blocks hState hWellFormed

theorem importedBoundaryOramHelperReconstructPathBucketBlocksPreservesNonFailureOfWellFormed
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathBucketBlocksPreservesNonFailureOfWellFormed
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap state bucketBlocks hState hWellFormed

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsStatePreservesNonFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsStatePreservesNonFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks
      hStashWellFormed hBucketWellFormed

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListStatePreservesNonFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListStatePreservesNonFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets
      hStashWellFormed hBucketWellFormed

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsFailedSuccessOfWellFormed
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
      bucketBlocks)
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsState
        capacity leafCount positionMap stashBlocks
        bucketBlocks).liveSlots = false) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsFailed
      capacity leafCount positionMap stashBlocks bucketBlocks = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsFailedSuccessOfWellFormed
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks bucketBlocks
      hStashWellFormed hBucketWellFormed hCoverage

theorem importedBoundaryOramHelperReconstructPathDecodedBucketsListFailedSuccessOfWellFormed
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
        decodedBuckets))
  (hCoverage :
    RuntimeOramHelperSemantics.liveSlotCoverageFailed positionMap
      (RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListState
        capacity leafCount positionMap stashBlocks
        decodedBuckets).liveSlots = false) :
  RuntimeOramHelperSemantics.reconstructPathDecodedBucketsListFailed
      capacity leafCount positionMap stashBlocks decodedBuckets = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperReconstructPathDecodedBucketsListFailedSuccessOfWellFormed
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity leafCount positionMap stashBlocks decodedBuckets
      hStashWellFormed hBucketWellFormed hCoverage

theorem importedBoundaryOramHelperBucketBlocksOfDecodedBucketsAdmittedOfLiveOnBucketPath
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {leafCount : Nat}
  {decodedBuckets : List RuntimeOramHelperSemantics.DecodedBucket}
  (hLive :
    RuntimeOramHelperSemantics.DecodedBuckets.LiveOnBucketPath
      leafCount decodedBuckets) :
  ∀ bucketBlock,
    bucketBlock ∈
        RuntimeOramHelperSemantics.bucketBlocksOfDecodedBuckets
          decodedBuckets →
      RuntimeOramHelperSemantics.bucketBlockAdmissionFailed leafCount
          bucketBlock = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBucketBlocksOfDecodedBucketsAdmittedOfLiveOnBucketPath
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLive

theorem importedBoundaryOramHelperWorkingStashCapacityFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.Parameters) :
  RuntimeOramHelperSemantics.workingStashCapacity parameters =
    parameters.stashBound +
      parameters.bucketsPerAccess * parameters.blocksPerBucket := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperWorkingStashCapacityFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters

theorem importedBoundaryOramHelperSlotForKeySomeWithinCapacity
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {keyMatches : List Bool}
  {slot : Nat}
  (hSlot : RuntimeOramHelperSemantics.slotForKey? keyMatches = some slot) :
  slot < keyMatches.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperSlotForKeySomeWithinCapacity
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hSlot

theorem importedBoundaryOramHelperAllocateSlotSomeWithinCapacity
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {occupied : List Bool}
  {slot : Nat}
  (hSlot : RuntimeOramHelperSemantics.allocateSlot? occupied = some slot) :
  slot < occupied.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperAllocateSlotSomeWithinCapacity
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hSlot

theorem importedBoundaryOramHelperFirstVacantIndexSomeWithinCapacity
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {index : Nat}
  (hIndex :
    RuntimeOramHelperSemantics.firstVacantIndex blocks = some index) :
  index < blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperFirstVacantIndexSomeWithinCapacity
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hIndex

theorem importedBoundaryOramHelperClearFixedStashLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.clearFixedStash blocks).length =
    blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperClearFixedStashLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocks

theorem importedBoundaryOramHelperClearFixedStashAllEmpty
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {block : RuntimeOramHelperSemantics.StashBlock}
  (hMem : block ∈ RuntimeOramHelperSemantics.clearFixedStash blocks) :
  block = RuntimeOramHelperSemantics.emptyBlock := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperClearFixedStashAllEmpty
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hMem

theorem importedBoundaryOramHelperPushFixedStashPreservesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (overflowed : Bool)
  (block : RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.pushFixedStash
      blocks overflowed block).blocks.length =
    blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPushFixedStashPreservesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocks overflowed block

theorem importedBoundaryOramHelperPushFixedStashVacantPreservesOverflow
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPushFixedStashVacantPreservesOverflow
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hVacant

theorem importedBoundaryOramHelperPushFixedStashNoVacantOverflows
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPushFixedStashNoVacantOverflows
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hOccupied hVacant

theorem importedBoundaryOramHelperTakeSelectedBlockPreservesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperTakeSelectedBlockPreservesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hTake

theorem importedBoundaryOramHelperTakeSelectedBlockPresentSelectedInBounds
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramHelperSemantics.StashBlock}
  {selectedIndex : Nat}
  {result : RuntimeOramHelperSemantics.TakeResult}
  (hTake :
    RuntimeOramHelperSemantics.takeSelectedBlock
        blocks selectedIndex true = some result) :
  selectedIndex < blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperTakeSelectedBlockPresentSelectedInBounds
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hTake

theorem importedBoundaryOramHelperSelectPositionMapLeafAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.selectPositionMapLeaf positionMap slot =
    RuntimeOramHelperSemantics.noneOption := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperSelectPositionMapLeafAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap slot hAbsent

theorem importedBoundaryOramHelperSelectPositionMapLeafPresentGet
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption}
  {slot leaf : RuntimeOramHelperSemantics.MaskedUsizeOption}
  (hPresent : slot.present = true)
  (hGet :
    RuntimeOramHelperSemantics.lookupAt? positionMap slot.value = some leaf) :
  RuntimeOramHelperSemantics.selectPositionMapLeaf positionMap slot = leaf := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperSelectPositionMapLeafPresentGet
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hPresent hGet

theorem importedBoundaryOramHelperSelectValueAtAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (values : List α)
  (slot : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (default : α)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.selectValueAt values slot default = default := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperSelectValueAtAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      values slot default hAbsent

theorem importedBoundaryOramHelperSelectValueAtPresentGet
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {values : List α}
  {slot : RuntimeOramHelperSemantics.MaskedUsizeOption}
  {default value : α}
  (hPresent : slot.present = true)
  (hGet : RuntimeOramHelperSemantics.lookupAt? values slot.value = some value) :
  RuntimeOramHelperSemantics.selectValueAt values slot default = value := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperSelectValueAtPresentGet
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hPresent hGet

theorem importedBoundaryOramHelperAccessLeafUsesFreshWhenNoPrior
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperAccessLeafUsesFreshWhenNoPrior
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap slot freshLeaf hNoPrior

theorem importedBoundaryOramHelperAccessLeafUsesPriorWhenPresent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperAccessLeafUsesPriorWhenPresent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap slot freshLeaf hPrior

theorem importedBoundaryOramHelperUpdatePositionMapLeafPreservesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  (RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf).length = positionMap.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperUpdatePositionMapLeafPreservesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap slot nextLeaf

theorem importedBoundaryOramHelperUpdatePositionMapLeafAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf = positionMap := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperUpdatePositionMapLeafAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap slot nextLeaf hAbsent

theorem importedBoundaryOramHelperUpdatePositionMapLeafNextAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (positionMap : List RuntimeOramHelperSemantics.MaskedUsizeOption)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : nextLeaf.present = false) :
  RuntimeOramHelperSemantics.updatePositionMapLeaf
      positionMap slot nextLeaf = positionMap := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperUpdatePositionMapLeafNextAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      positionMap slot nextLeaf hAbsent

theorem importedBoundaryOramHelperUpdateStashLeafForSlotPreservesLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  (RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf).length = blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperUpdateStashLeafForSlotPreservesLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocks slot nextLeaf

theorem importedBoundaryOramHelperUpdateStashLeafForSlotAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : slot.present = false) :
  RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf = blocks := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperUpdateStashLeafForSlotAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocks slot nextLeaf hAbsent

theorem importedBoundaryOramHelperUpdateStashLeafForSlotNextAbsent
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (slot nextLeaf : RuntimeOramHelperSemantics.MaskedUsizeOption)
  (hAbsent : nextLeaf.present = false) :
  RuntimeOramHelperSemantics.updateStashLeafForSlot
      blocks slot nextLeaf = blocks := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperUpdateStashLeafForSlotNextAbsent
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocks slot nextLeaf hAbsent

theorem importedBoundaryOramHelperPathPutUpdateFailedNoApply
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (entryCapacity : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock)
  (valueIsZero : Bool)
  (slot insertSlot : RuntimeOramHelperSemantics.MaskedUsizeOption) :
  RuntimeOramHelperSemantics.pathPutUpdateFailed
      entryCapacity blocks false valueIsZero slot insertSlot = false := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutUpdateFailedNoApply
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entryCapacity blocks valueIsZero slot insertSlot

theorem importedBoundaryOramHelperPathPutUpdateFailedUpdateMissing
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutUpdateFailedUpdateMissing
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entryCapacity blocks slot insertSlot hSlot hMissing

theorem importedBoundaryOramHelperPathPutUpdateFailedInsertNoVacancy
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutUpdateFailedInsertNoVacancy
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entryCapacity blocks slot insertSlot hSlotAbsent hInsert hVacant

theorem importedBoundaryOramHelperPathPutUpdateFailedInsertOutOfRange
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathPutUpdateFailedInsertOutOfRange
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      entryCapacity blocks slot insertSlot hSlotAbsent hInsert hOutOfRange

theorem importedBoundaryOramHelperBuildPathBucketBucketLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).bucket.length =
    blocksPerBucket := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBuildPathBucketBucketLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocksPerBucket leafCount bucketIndex blocks

theorem importedBoundaryOramHelperBuildPathBucketStashLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).stash.length =
    blocks.length := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBuildPathBucketStashLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocksPerBucket leafCount bucketIndex blocks

theorem importedBoundaryOramHelperBuildPathBucketLiveCountBound
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket leafCount bucketIndex : Nat)
  (blocks : List RuntimeOramHelperSemantics.StashBlock) :
  (RuntimeOramHelperSemantics.buildPathBucket
      blocksPerBucket leafCount bucketIndex blocks).liveCount ≤
    blocksPerBucket := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperBuildPathBucketLiveCountBound
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocksPerBucket leafCount bucketIndex blocks

theorem importedBoundaryOramHelperRewritePathWriteCountMatchesWriteLogCapacity
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters) :
  RuntimeOramHelperSemantics.rewritePathWriteCount parameters =
    RuntimeOramWriteLogDiscipline.writeLogCapacity
      (RuntimeOramHelperSemantics.rewriteWriteLogParameters parameters) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathWriteCountMatchesWriteLogCapacity
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters

theorem importedBoundaryOramHelperPathAccessReadCountMatchesReadTranscriptCapacity
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters) :
  RuntimeOramHelperSemantics.pathAccessReadCount parameters =
    RuntimeOramWriteLogDiscipline.readTranscriptCapacity
      (RuntimeOramHelperSemantics.rewriteWriteLogParameters parameters) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperPathAccessReadCountMatchesReadTranscriptCapacity
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters

theorem importedBoundaryOramHelperRewritePathSummaryNextCounter
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathSummaryNextCounter
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen

theorem importedBoundaryOramHelperRewritePathSummaryPhysicalWriteCount
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathSummaryPhysicalWriteCount
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters currentCounter loadOverflowed effectFailed
      postUpdateStashLen postRebuildStashLen

theorem importedBoundaryOramHelperRewritePathUpdateFailedLoadOverflow
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters true effectFailed postUpdateStashLen postRebuildStashLen =
    true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathUpdateFailedLoadOverflow
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters effectFailed postUpdateStashLen postRebuildStashLen

theorem importedBoundaryOramHelperRewritePathUpdateFailedEffectFailed
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (loadOverflowed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters loadOverflowed true postUpdateStashLen postRebuildStashLen =
    true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathUpdateFailedEffectFailed
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters loadOverflowed postUpdateStashLen postRebuildStashLen

theorem importedBoundaryOramHelperRewritePathUpdateFailedPostUpdateOverflow
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathUpdateFailedPostUpdateOverflow
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen hOverflow

theorem importedBoundaryOramHelperRewritePathUpdateFailedPostRebuildOverflow
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (parameters : RuntimeOramHelperSemantics.RewriteParameters)
  (loadOverflowed effectFailed : Bool)
  (postUpdateStashLen postRebuildStashLen : Nat)
  (hOverflow : parameters.stashBound < postRebuildStashLen) :
  RuntimeOramHelperSemantics.rewritePathUpdateFailed
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen = true := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathUpdateFailedPostRebuildOverflow
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters loadOverflowed effectFailed postUpdateStashLen
      postRebuildStashLen hOverflow

theorem importedBoundaryOramHelperRewritePathUpdateFailedNoFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathUpdateFailedNoFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters postUpdateStashLen postRebuildStashLen hPostUpdate
      hPostRebuild

theorem importedBoundaryOramHelperRewritePathSummaryNoFailure
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramHelperRewritePathSummaryNoFailure
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      parameters currentCounter postUpdateStashLen postRebuildStashLen
      hPostUpdate hPostRebuild

theorem importedBoundaryOramCounterFieldBytesMatchSlotIndex
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramCodecSemantics.counterFieldBytes =
    RuntimeOramCodecSemantics.slotIndexBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterFieldBytesMatchSlotIndex
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)

theorem importedBoundaryOramSurrogateBlockBytesPublicFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.surrogateBlockBytes keyBytes valueBytes =
    RuntimeOramCodecSemantics.occupancyTagBytes + keyBytes + valueBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramSurrogateBlockBytesPublicFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      keyBytes valueBytes

theorem importedBoundaryOramPathBlockBytesPublicFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.pathBlockBytes keyBytes valueBytes =
    RuntimeOramCodecSemantics.occupancyTagBytes +
      RuntimeOramCodecSemantics.slotIndexBytes +
      RuntimeOramCodecSemantics.leafLabelBytes +
      keyBytes +
      valueBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramPathBlockBytesPublicFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      keyBytes valueBytes

theorem importedBoundaryOramBucketBytesPublicFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blocksPerBucket blockBytes : Nat) :
  RuntimeOramCodecSemantics.bucketBytes blocksPerBucket blockBytes =
    oramBucketHeaderBytes +
      blocksPerBucket * blockBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramBucketBytesPublicFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blocksPerBucket blockBytes

theorem importedBoundaryOramBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramBucketBytesMatchCodec
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hObject

theorem importedBoundaryOramSurrogateBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedSurrogateOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramSurrogateBucketBytesMatchCodec
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hObject

theorem importedBoundaryOramPathBucketBytesMatchCodec
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {object : OramObjectManifest}
  (hObject : WellFormedPathOramObject object) :
  object.bucketSize =
    RuntimeOramCodecSemantics.bucketBytes object.blocksPerBucket object.blockSize := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramPathBucketBytesMatchCodec
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hObject

theorem importedBoundaryOramDirectoryPageBytesPublicFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (blockBytes : Nat) :
  RuntimeOramCodecSemantics.directoryPageBytes blockBytes =
    RuntimeOramCodecSemantics.directoryPageEntries * blockBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramDirectoryPageBytesPublicFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      blockBytes

theorem importedBoundaryOramPublicCountGuardAcceptsExact
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (expected : Nat) :
  RuntimeOramCodecSemantics.publicCountGuard? expected expected = some () := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramPublicCountGuardAcceptsExact
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      expected

theorem importedBoundaryOramDirectoryPagesRejectCountMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramDirectoryPagesRejectCountMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCount

theorem importedBoundaryOramBucketsRejectCountMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramBucketsRejectCountMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCount

theorem importedBoundaryPathPositionMapBufferRejectsCountMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapBufferRejectsCountMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCount

theorem importedBoundaryPathLiveSlotsRejectCountMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {expected actual : Nat}
  (hCount : actual ≠ expected) :
  RuntimeOramCodecSemantics.publicCountGuard? expected actual = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathLiveSlotsRejectCountMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCount

theorem importedBoundaryOramCodecBucketHeaderBytesMatchesRuntimeHeader
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid) :
  RuntimeOramCodecSemantics.codecBucketHeaderBytes =
    oramBucketHeaderBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCodecBucketHeaderBytesMatchesRuntimeHeader
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)

theorem importedBoundaryOramCodecBlockBytesSurrogateMatchesFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBlockBytes false keyBytes valueBytes =
    RuntimeOramCodecSemantics.surrogateBlockBytes keyBytes valueBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCodecBlockBytesSurrogateMatchesFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      keyBytes valueBytes

theorem importedBoundaryOramCodecBlockBytesPathMatchesFormula
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBlockBytes true keyBytes valueBytes =
    RuntimeOramCodecSemantics.pathBlockBytes keyBytes valueBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCodecBlockBytesPathMatchesFormula
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      keyBytes valueBytes

theorem importedBoundaryOramCodecBucketBytesMatchesRuntimeBucketBytes
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (isPath : Bool)
  (blocksPerBucket keyBytes valueBytes : Nat) :
  RuntimeOramCodecSemantics.codecBucketBytes
      isPath blocksPerBucket keyBytes valueBytes =
    RuntimeOramCodecSemantics.bucketBytes blocksPerBucket
      (RuntimeOramCodecSemantics.codecBlockBytes
        isPath keyBytes valueBytes) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCodecBucketBytesMatchesRuntimeBucketBytes
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      isPath blocksPerBucket keyBytes valueBytes

theorem importedBoundaryOramCounterEncodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.CounterDecodeAccepted
    (RuntimeOramCodecSemantics.encodeCounterField counter) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterEncodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      counter

theorem importedBoundaryOramCounterEncodeLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  (RuntimeOramCodecSemantics.encodeCounterField counter).length =
    RuntimeOramCodecSemantics.counterFieldBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterEncodeLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      counter

theorem importedBoundaryOramCounterEncodeValidBytes
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.ValidByteField
    (RuntimeOramCodecSemantics.encodeCounterField counter) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterEncodeValidBytes
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      counter

theorem importedBoundaryOramCounterDecodeExactEncode
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (counter : Nat) :
  RuntimeOramCodecSemantics.decodeCounterExact?
      (RuntimeOramCodecSemantics.encodeCounterField counter) =
    some
      (RuntimeOramCodecSemantics.decodeNatField
        (RuntimeOramCodecSemantics.encodeCounterField counter)) := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterDecodeExactEncode
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      counter

theorem importedBoundaryOramCounterDecodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter)
  (hBytes : RuntimeOramCodecSemantics.ValidByteField bytes) :
  RuntimeOramCodecSemantics.CounterDecodeAccepted bytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterDecodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode hBytes

theorem importedBoundaryOramCounterDecodeLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter) :
  bytes.length = RuntimeOramCodecSemantics.counterFieldBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterDecodeLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramCounterDecodeValue
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {bytes : List Nat}
  {counter : Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodeCounterExact? bytes = some counter) :
  counter = RuntimeOramCodecSemantics.decodeNatField bytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramCounterDecodeValue
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramBlockCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramBlockCodecRoundtrip
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBlock

theorem importedBoundaryOramExactBlockCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBlockCodecRoundtrip
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBlock

theorem importedBoundaryOramExactBlockDecodeLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBlockDecodeLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramExactBlockDecodeValidShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBlockDecodeValidShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramEncodeBlockLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes : Nat}
  {block : RuntimeOramCodecSemantics.CodecBlock}
  (hBlock : block.ValidShape isPath keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBlock isPath block).length =
    RuntimeOramCodecSemantics.codecBlockBytes
      isPath keyBytes valueBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramEncodeBlockLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBlock

theorem importedBoundaryOramEncodeBlocksLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramEncodeBlocksLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBlocks

theorem importedBoundaryOramExactBlocksDecodeCount
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBlocksDecodeCount
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramExactBlocksCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBlocksCodecRoundtrip
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBlocks

theorem importedBoundaryOramBucketCodecLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {blocksPerBucket keyBytes valueBytes : Nat}
  {bucket : RuntimeOramCodecSemantics.CodecBucket}
  (hBucket : bucket.ValidShape isPath blocksPerBucket keyBytes valueBytes) :
  (RuntimeOramCodecSemantics.encodeBucket isPath bucket).length =
    RuntimeOramCodecSemantics.codecBucketBytes
      isPath blocksPerBucket keyBytes valueBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_oramBucketCodecLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBucket

theorem importedBoundaryOramExactBucketCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBucketCodecRoundtrip
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hBucket hBucketIndex hLiveCount

theorem importedBoundaryOramExactBucketDecodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBucketDecodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryOramExactBucketDecodeBlockValidShapes
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramExactBucketDecodeBlockValidShapes
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathBucketBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathBucketBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathBucketPathBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathBucketPathBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathBucketPositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathBucketPositionMapBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathBucketUniquePositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathBucketUniquePositionMapBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathPositionMapLiveSlotCoverage
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {positionMap : List (Option Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPositionMapCoveredByLiveBlocks
        positionMap blocks = true) :
  RuntimeOramCodecSemantics.PositionMapCoveredByLiveBlocks
    positionMap blocks := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapLiveSlotCoverage
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCheck

theorem importedBoundaryPathBlocksPositionMapAgreement
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {positionMap : List (Option Nat)}
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPathBlocksPositionMapAgreement
        positionMap blocks = true) :
  ∀ block, block ∈ blocks →
    block.AgreesWithPositionMap positionMap := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathBlocksPositionMapAgreement
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCheck

theorem importedBoundaryPathBlocksNoDuplicateLiveSlots
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {blocks : List RuntimeOramCodecSemantics.CodecBlock}
  (hCheck :
    RuntimeOramCodecSemantics.checkPathBlocksNoDuplicateLiveSlots blocks =
      true) :
  RuntimeOramCodecSemantics.LiveSlotNoDuplicates blocks := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathBlocksNoDuplicateLiveSlots
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCheck

theorem importedBoundaryOramDecodedBucketPayloadAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_oramDecodedBucketPayloadAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hIndex hBlocks hLive

theorem importedBoundaryPathPositionMapPagesCoverCapacity
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  capacity ≤
    RuntimeOramCodecSemantics.pathPositionMapPages capacity *
      RuntimeOramCodecSemantics.directoryPageEntries := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPagesCoverCapacity
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity

theorem importedBoundaryPathPositionMapPagesPositive
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  (capacity : Nat) :
  0 < RuntimeOramCodecSemantics.pathPositionMapPages capacity := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPagesPositive
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      capacity

theorem importedBoundaryPathMetadataPageSplit
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {metadataPages capacity : Nat}
  (hPages :
    RuntimeOramCodecSemantics.pathPositionMapPages capacity ≤
      metadataPages) :
  RuntimeOramCodecSemantics.pathPositionMapPages capacity +
      RuntimeOramCodecSemantics.pathStashPages metadataPages capacity =
    metadataPages := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathMetadataPageSplit
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hPages

theorem importedBoundaryPositionMapDecodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {capacity leafCount : Nat}
  {positionMap : List (Option Nat)}
  (hCapacity : positionMap.length = capacity)
  (hLeaves :
    RuntimeOramCodecSemantics.PositionMapLeafBounded leafCount positionMap) :
  RuntimeOramCodecSemantics.PositionMapDecodeAccepted
      capacity leafCount positionMap := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_positionMapDecodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCapacity hLeaves

theorem importedBoundaryPathPositionMapLeafDecodeBounded
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {leafCount : Nat}
  {field : List Nat}
  {entry : Option Nat}
  (hDecode :
    RuntimeOramCodecSemantics.decodePositionMapLeaf? leafCount field =
      some entry) :
  RuntimeOramCodecSemantics.PositionMapEntryLeafBounded leafCount entry := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapLeafDecodeBounded
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathPositionMapEntriesDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapEntriesDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathPositionMapPageDecodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPageDecodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathPositionMapPageRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes : Nat}
  {bytes : List Nat}
  (hLen : bytes.length ≠ directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathPositionMapPageExact?
      leafCount directoryPageBytes bytes = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPageRejectsLengthMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLen

theorem importedBoundaryPathPositionMapPagesAllDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPagesAllDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathPositionMapPagesDecodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPagesDecodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathPositionMapPagesRejectsPageCountMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {leafCount directoryPageBytes capacity : Nat}
  {pages : List (List Nat)}
  (hCount :
    pages.length ≠ RuntimeOramCodecSemantics.pathPositionMapPages capacity) :
  RuntimeOramCodecSemantics.decodePathPositionMapPagesExact?
      leafCount directoryPageBytes capacity pages = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPagesRejectsPageCountMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCount

theorem importedBoundaryPathPositionMapPageLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {directoryPageBytes : Nat}
  {positionMapPrefixBytes : List Nat}
  (hLen : positionMapPrefixBytes.length ≤ directoryPageBytes) :
  (RuntimeOramCodecSemantics.encodePathPositionMapPageBytes
      directoryPageBytes positionMapPrefixBytes).length =
    directoryPageBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPageLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLen

theorem importedBoundaryPathPositionMapPageCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPageCodecRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hFields hEntryCount hDirectoryBytes

theorem importedBoundaryPathPositionMapPagesCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathPositionMapPagesCodecRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hPages hPageCount hDirectoryBytes

theorem importedBoundaryPathStashPageLength
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {directoryPageBytes : Nat}
  {stashBlockBytes : List Nat}
  (hLen : stashBlockBytes.length ≤ directoryPageBytes) :
  (RuntimeOramCodecSemantics.encodePathStashPageBytes
      directoryPageBytes stashBlockBytes).length =
    directoryPageBytes := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPageLength
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLen

theorem importedBoundaryPathStashPageCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPageCodecRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hBlockCount hBlocks hDirectoryBytes

theorem importedBoundaryPathStashPagesCodecRoundtrip
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesCodecRoundtrip
      (boundary.toRuntimeImplementationResidualHelperShellBoundary hValid).implementationInterface
      (importedRuntimeImplementationResidualHelperShellBoundary_toRuntimeResidualHelperShellConfinement
        boundary hValid)
      hPages hPageCount hDirectoryBytes

theorem importedBoundaryPathStashPageDecodeAccepted
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPageDecodeAccepted
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathStashPageRejectsLengthMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes : Nat}
  {bytes : List Nat}
  (hLen : bytes.length ≠ directoryPageBytes) :
  RuntimeOramCodecSemantics.decodePathStashPageExact?
      isPath keyBytes valueBytes directoryPageBytes bytes = none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPageRejectsLengthMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hLen

theorem importedBoundaryPathStashPageDecodeBlockValidShapes
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPageDecodeBlockValidShapes
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathStashPagesDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathStashPagesRejectsPageCountMismatch
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
  (hValid : boundary.Valid)
  {isPath : Bool}
  {keyBytes valueBytes directoryPageBytes stashPageCount : Nat}
  {pages : List (List Nat)}
  (hCount : pages.length ≠ stashPageCount) :
  RuntimeOramCodecSemantics.decodePathStashPagesExact?
      isPath keyBytes valueBytes directoryPageBytes stashPageCount pages =
    none := by
  exact
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesRejectsPageCountMismatch
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hCount

theorem importedBoundaryPathStashPagesAllDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesAllDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathStashPagesBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathStashPagesPositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesPositionMapBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

theorem importedBoundaryPathStashPagesUniquePositionMapBoundedDecodeShape
  {boundary : ImportedRuntimeImplementationResidualHelperShellBoundary}
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
    RuntimeImplementationInterface.residualHelperShellBoundary_pathStashPagesUniquePositionMapBoundedDecodeShape
      (importedBoundaryResidualIface hValid)
      (importedBoundaryResidualShellBoundary hValid)
      hDecode

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let boundary ← loadAndCheckImportedRuntimeImplementationResidualHelperShellBoundary path
      IO.println
        s!"validated runtime residual helper-shell boundary for source-backed uo-evm helper shell ({boundary.implementation_interface.objects_source.length + boundary.implementation_interface.oram_source.length + boundary.implementation_interface.store_codec_source.length + boundary.implementation_interface.generated_store_codec_source.length + boundary.implementation_interface.generated_store_helpers_source.length + boundary.implementation_interface.store_store_source.length} helper bytes)"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
