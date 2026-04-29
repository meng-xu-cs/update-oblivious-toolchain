import UOToolchain.Sol

/-!
# Solidity dialect boundary

The proof-grade source theorem is for the admitted post-resolution
`uo-solidity-like-dsl-v1` language.  This file records the versioned bridge
surface that would be needed to restate the claim as Solidity 0.8 semantics,
and pins the semantic divergences that currently keep the theorem scoped to the
DSL.
-/

namespace UOToolchain

inductive UintArithmeticMode where
  | wrappingModulo256
  | checkedRevertOnOverflow
deriving Repr, DecidableEq

inductive ZeroDivisionMode where
  | returnsZero
  | reverts
deriving Repr, DecidableEq

inductive AbiEncodingMode where
  | canonicalFixedSizeBytes
  | solidityAbiEncodePackedV08
deriving Repr, DecidableEq

inductive RevertRollbackMode where
  | requireAbortStatusWithRollback
  | solidityRevertExceptionWithRollback
deriving Repr, DecidableEq

inductive ContextVariableMode where
  | absent
  | publicEnvironmentInputs
deriving Repr, DecidableEq

structure SourceSemanticProfile where
  languageTag : String
  uintArithmetic : UintArithmeticMode
  divisionByZero : ZeroDivisionMode
  moduloByZero : ZeroDivisionMode
  abiEncoding : AbiEncodingMode
  revertRollback : RevertRollbackMode
  contextVariables : ContextVariableMode
deriving Repr, DecidableEq

def uoSolidityLikeDslV1Profile : SourceSemanticProfile :=
  { languageTag := "uo-solidity-like-dsl-v1"
  , uintArithmetic := .wrappingModulo256
  , divisionByZero := .returnsZero
  , moduloByZero := .returnsZero
  , abiEncoding := .canonicalFixedSizeBytes
  , revertRollback := .requireAbortStatusWithRollback
  , contextVariables := .absent
  }

def solidity08Profile : SourceSemanticProfile :=
  { languageTag := "solidity-0.8.x"
  , uintArithmetic := .checkedRevertOnOverflow
  , divisionByZero := .reverts
  , moduloByZero := .reverts
  , abiEncoding := .solidityAbiEncodePackedV08
  , revertRollback := .solidityRevertExceptionWithRollback
  , contextVariables := .publicEnvironmentInputs
  }

/-- Versioned relation required before the theorem can be restated as a
Solidity 0.8 subset theorem.  It names every semantic feature from the review:
checked arithmetic, division/modulo-by-zero, ABI encoding, revert/rollback, and
context variables. -/
structure VersionedSoliditySemanticsBridge
  (source target : SourceSemanticProfile) : Prop where
  languageVersion : source.languageTag = "uo-solidity-like-dsl-v1" ∧
    target.languageTag = "solidity-0.8.x"
  checkedArithmetic : source.uintArithmetic = target.uintArithmetic
  divisionByZero : source.divisionByZero = target.divisionByZero
  moduloByZero : source.moduloByZero = target.moduloByZero
  abiEncoding : source.abiEncoding = target.abiEncoding
  revertRollback : source.revertRollback = target.revertRollback
  contextVariables : source.contextVariables = target.contextVariables

/-- Open bridge target.  No theorem in this repository currently constructs
this value; the active claim is therefore the DSL claim, not a Solidity 0.8
claim. -/
def Solidity08BridgeRequiredForSubsetClaim : Prop :=
  Nonempty
    (VersionedSoliditySemanticsBridge
      uoSolidityLikeDslV1Profile
      solidity08Profile)

theorem uoSolidityLikeDslV1_is_current_source_language :
    uoSolidityLikeDslV1Profile.languageTag = "uo-solidity-like-dsl-v1" := by
  rfl

theorem uoSolidityLikeDslV1_wraps_uint256_addition :
    IR.BinaryOp.eval
      .add
      (.uint ((2 ^ 256) - 1))
      (.uint 1) =
    some (.uint 0) := by
  exact IR.binaryAdd_matches_uint256_wrapping

theorem uoSolidityLikeDslV1_wraps_uint256_subtraction :
    IR.BinaryOp.eval .sub (.uint 0) (.uint 1) =
      some (.uint ((2 ^ 256) - 1)) := by
  exact IR.binarySub_matches_uint256_wrapping

theorem uoSolidityLikeDslV1_division_by_zero_returns_zero :
    IR.BinaryOp.eval .div (.uint 7) (.uint 0) = some (.uint 0) := by
  exact IR.binaryDivByZero_matches_runtime

theorem uoSolidityLikeDslV1_modulo_by_zero_returns_zero :
    IR.BinaryOp.eval .mod (.uint 7) (.uint 0) = some (.uint 0) := by
  exact IR.binaryModByZero_matches_runtime

theorem uoSolidityLikeDslV1_semantic_profile_differs_from_solidity08 :
    uoSolidityLikeDslV1Profile.uintArithmetic ≠ solidity08Profile.uintArithmetic ∧
      uoSolidityLikeDslV1Profile.divisionByZero ≠ solidity08Profile.divisionByZero ∧
      uoSolidityLikeDslV1Profile.moduloByZero ≠ solidity08Profile.moduloByZero ∧
      uoSolidityLikeDslV1Profile.abiEncoding ≠ solidity08Profile.abiEncoding ∧
      uoSolidityLikeDslV1Profile.revertRollback ≠ solidity08Profile.revertRollback ∧
      uoSolidityLikeDslV1Profile.contextVariables ≠ solidity08Profile.contextVariables := by
  decide

theorem no_current_bridge_to_solidity08 :
    ¬ Solidity08BridgeRequiredForSubsetClaim := by
  intro hBridge
  rcases hBridge with ⟨bridge⟩
  cases bridge.checkedArithmetic

end UOToolchain
