import UOToolchain.TraceModel
import UOToolchain.IRSyntax

/-!
# Semantics layer for the admitted Solidity-like UO DSL

This module sits at the boundary between the abstract trace-producer
abstraction used by the existing `ExactObjects` / `Composition` /
`TeeDeployment` story and the *real* operational evaluator the WP4 source-
to-kernel compiler-correctness theorems must refine against.

Two things live here:

* `TraceConfig`, `TraceProgram`, `TraceInput`, and `TraceSemantics`
  preserve the older abstract trace-producer interface used by
  `ExactObjects` / `Composition`. They keep the abstract composition
  theorems intact while WP4 is still landing.
* `IR.OperationalConfig`, `IR.Outcome`, and `Semantics` introduce the new
  *real* operational evaluator surface. `Semantics` is now the operational
  evaluator type, replacing the older placeholder
  `abbrev Semantics := Config → Trace`.

The new `Semantics` returns a richer `IR.Outcome` carrying the public
result, the per-object ORAM-access counts, the manifest-relevant kernel
step list, and the existing `Trace`. The W4.1 evaluator skeleton handles
the Declare/Assign/Require/AbortIf/Return/CellSet/CellGet subset of
statements/expressions exactly; cases that have not yet been admitted to
the evaluator return an explicit `IR.EvalStatus.unsupported` outcome so
that downstream theorems are *honest* about the evaluator's coverage.
-/

namespace UOToolchain

/-! ## Abstract trace-producer interface (`Trace*`) -/

/-- Abstract trace-side `ObjectShape`: opaque object metadata used by the
older trace-producer abstractions. Preserved for backwards compatibility
with the abstract composition / `ExactUO` theorems. The structured WP4
mirror lives at `IR.StateObject` (in `IRSyntax.lean`). -/
structure TraceObjectShape where
  objectId : Nat
  backend : String
  capacity : Nat
deriving Repr, DecidableEq

structure TraceProgram where
  contract : String
  entrypoint : String
  objects : List TraceObjectShape
deriving Repr, DecidableEq

structure TraceInput where
  publicArgs : List String
  publicEnv : List String := []
  secretArgs : List String
deriving Repr, DecidableEq

structure TraceConfig where
  program : TraceProgram
  input : TraceInput
  publicState : List String
  secretState : List String
deriving Repr, DecidableEq

structure TracePublicProjection where
  program : TraceProgram
  publicArgs : List String
  publicEnv : List String
  publicState : List String
deriving Repr, DecidableEq

abbrev TraceSemantics := TraceConfig → Trace

def tracePublicProjection (cfg : TraceConfig) : TracePublicProjection :=
  { program := cfg.program
  , publicArgs := cfg.input.publicArgs
  , publicEnv := cfg.input.publicEnv
  , publicState := cfg.publicState
  }

def sameTracePublicProjection (lhs rhs : TraceConfig) : Prop :=
  tracePublicProjection lhs = tracePublicProjection rhs

theorem sameTracePublicProjection_refl (cfg : TraceConfig) :
    sameTracePublicProjection cfg cfg := rfl

theorem sameTracePublicProjection_symm {lhs rhs : TraceConfig} :
    sameTracePublicProjection lhs rhs → sameTracePublicProjection rhs lhs := by
  intro h
  exact h.symm

theorem sameTracePublicProjection_trans {a b c : TraceConfig} :
    sameTracePublicProjection a b → sameTracePublicProjection b c →
      sameTracePublicProjection a c := by
  intro hab hbc
  exact hab.trans hbc

theorem sameTracePublicProjection_program_eq {lhs rhs : TraceConfig} :
    sameTracePublicProjection lhs rhs → lhs.program = rhs.program := by
  intro h
  exact congrArg TracePublicProjection.program h

theorem sameTracePublicProjection_publicArgs_eq {lhs rhs : TraceConfig} :
    sameTracePublicProjection lhs rhs → lhs.input.publicArgs = rhs.input.publicArgs := by
  intro h
  exact congrArg TracePublicProjection.publicArgs h

theorem sameTracePublicProjection_publicEnv_eq {lhs rhs : TraceConfig} :
    sameTracePublicProjection lhs rhs → lhs.input.publicEnv = rhs.input.publicEnv := by
  intro h
  exact congrArg TracePublicProjection.publicEnv h

theorem sameTracePublicProjection_publicState_eq {lhs rhs : TraceConfig} :
    sameTracePublicProjection lhs rhs → lhs.publicState = rhs.publicState := by
  intro h
  exact congrArg TracePublicProjection.publicState h

/-! ## Backwards-compatible aliases for the older `Config` / `Program` /
`Input` / `PublicProjection` names used by the abstract trace-producer
theorems. These keep `ExactObjects`, `Composition`, `TeeDeployment`, and
the legacy modules compiling without renaming every callsite. -/

abbrev Config := TraceConfig
abbrev Program := TraceProgram
abbrev Input := TraceInput
abbrev PublicProjection := TracePublicProjection
abbrev ObjectShape := TraceObjectShape

@[inline] def publicProjection (cfg : Config) : PublicProjection :=
  tracePublicProjection cfg

@[inline] def samePublicProjection (lhs rhs : Config) : Prop :=
  sameTracePublicProjection lhs rhs

theorem samePublicProjection_refl (cfg : Config) : samePublicProjection cfg cfg :=
  sameTracePublicProjection_refl cfg

theorem samePublicProjection_symm {lhs rhs : Config} :
    samePublicProjection lhs rhs → samePublicProjection rhs lhs :=
  sameTracePublicProjection_symm

theorem samePublicProjection_trans {a b c : Config} :
    samePublicProjection a b → samePublicProjection b c → samePublicProjection a c :=
  sameTracePublicProjection_trans

theorem samePublicProjection_program_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.program = rhs.program :=
  sameTracePublicProjection_program_eq

theorem samePublicProjection_publicArgs_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.input.publicArgs = rhs.input.publicArgs :=
  sameTracePublicProjection_publicArgs_eq

theorem samePublicProjection_publicEnv_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.input.publicEnv = rhs.input.publicEnv :=
  sameTracePublicProjection_publicEnv_eq

theorem samePublicProjection_publicState_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.publicState = rhs.publicState :=
  sameTracePublicProjection_publicState_eq

/-! ## Operational evaluator interface (real WP4 surface)

Everything below this comment is the new *real* operational evaluator
type. The `Semantics` abbreviation is now `IR.OperationalConfig →
IR.Outcome` instead of the older placeholder `Config → Trace`.
-/

namespace IR

/-- A local environment binding `name → Value`, used for evaluating
`Statement.declare` / `Statement.assign` / `Expr.var`. -/
abbrev LocalEnv := List (String × Value)

namespace LocalEnv

def lookup (env : LocalEnv) (name : String) : Option Value :=
  match env.find? (fun entry => entry.fst = name) with
  | some (_, value) => some value
  | none => none

def insert (env : LocalEnv) (name : String) (value : Value) : LocalEnv :=
  (name, value) :: env.filter (fun entry => entry.fst ≠ name)

end LocalEnv

/-- Operational configuration for the WP4 evaluator.

Mirrors what the runtime/probe sees: a concrete contract, a chosen
entrypoint, the typed public/secret arguments and the public/secret
object stores at entry. Public/secret separation pins which inputs the
adversary may observe and which the theorem must hide. -/
structure OperationalConfig where
  contract : CompiledContract
  entrypoint : String
  publicArgs : List Value
  publicEnv : List (String × Value) := []
  secretArgs : List Value
  publicState : ObjectStore
  secretState : ObjectStore
  deriving Inhabited

/-- Public projection of an operational configuration: the public-only
data the adversary may condition on. -/
structure OperationalPublicProjection where
  contract : CompiledContract
  entrypoint : String
  publicArgs : List Value
  publicEnv : List (String × Value)
  publicState : ObjectStore
  deriving Inhabited

def operationalPublicProjection (cfg : OperationalConfig) : OperationalPublicProjection :=
  { contract := cfg.contract
  , entrypoint := cfg.entrypoint
  , publicArgs := cfg.publicArgs
  , publicEnv := cfg.publicEnv
  , publicState := cfg.publicState
  }

/-- Two operational configurations have the same public projection when
their contract, entrypoint, public arguments, public environment, and public
store agree. -/
def sameOperationalPublicProjection (lhs rhs : OperationalConfig) : Prop :=
  operationalPublicProjection lhs = operationalPublicProjection rhs

theorem sameOperationalPublicProjection_refl (cfg : OperationalConfig) :
    sameOperationalPublicProjection cfg cfg := rfl

theorem sameOperationalPublicProjection_symm {lhs rhs : OperationalConfig} :
    sameOperationalPublicProjection lhs rhs →
      sameOperationalPublicProjection rhs lhs := by
  intro h
  exact h.symm

theorem sameOperationalPublicProjection_trans {a b c : OperationalConfig} :
    sameOperationalPublicProjection a b →
      sameOperationalPublicProjection b c →
      sameOperationalPublicProjection a c := by
  intro hab hbc
  exact hab.trans hbc

theorem sameOperationalPublicProjection_contract_eq
  {lhs rhs : OperationalConfig} :
    sameOperationalPublicProjection lhs rhs → lhs.contract = rhs.contract := by
  intro h
  exact congrArg OperationalPublicProjection.contract h

theorem sameOperationalPublicProjection_entrypoint_eq
  {lhs rhs : OperationalConfig} :
    sameOperationalPublicProjection lhs rhs → lhs.entrypoint = rhs.entrypoint := by
  intro h
  exact congrArg OperationalPublicProjection.entrypoint h

theorem sameOperationalPublicProjection_publicArgs_eq
  {lhs rhs : OperationalConfig} :
    sameOperationalPublicProjection lhs rhs → lhs.publicArgs = rhs.publicArgs := by
  intro h
  exact congrArg OperationalPublicProjection.publicArgs h

theorem sameOperationalPublicProjection_publicEnv_eq
  {lhs rhs : OperationalConfig} :
    sameOperationalPublicProjection lhs rhs → lhs.publicEnv = rhs.publicEnv := by
  intro h
  exact congrArg OperationalPublicProjection.publicEnv h

theorem sameOperationalPublicProjection_publicState_eq
  {lhs rhs : OperationalConfig} :
    sameOperationalPublicProjection lhs rhs → lhs.publicState = rhs.publicState := by
  intro h
  exact congrArg OperationalPublicProjection.publicState h

/-- Termination status of a single evaluator run. -/
inductive EvalStatus where
  | completed
  | requireFailed
  | abortedByUser
  | unsupported (kind : String)
  | evalError (msg : String)
  deriving Repr, DecidableEq, Inhabited

def EvalStatus.commitsCandidate : EvalStatus → Bool
  | .completed => true
  | _ => false

/-- Per-object ORAM access count: pair `(objectId, accesses)` matching the
manifest-facing `oramAccesses` view. -/
abbrev OramAccessCounts := List (Nat × Nat)

namespace OramAccessCounts

def get (counts : OramAccessCounts) (objectId : Nat) : Nat :=
  match counts.find? (fun entry => entry.fst = objectId) with
  | some (_, n) => n
  | none => 0

def bump (counts : OramAccessCounts) (objectId : Nat) : OramAccessCounts :=
  let current := get counts objectId
  (objectId, current + 1) :: counts.filter (fun entry => entry.fst ≠ objectId)

end OramAccessCounts

private def natListContains (needle : Nat) : List Nat → Bool
  | [] => false
  | value :: rest => value == needle || natListContains needle rest

private def uniqueNatList : List Nat → List Nat
  | [] => []
  | value :: rest =>
      let tail := uniqueNatList rest
      if natListContains value tail then tail else value :: tail

private def ObjectStore.objectIds (store : ObjectStore) : List Nat :=
  store.map Prod.fst

private def optionalValueEquivalent : Option Value → Option Value → Bool
  | none, none => true
  | some lhs, some rhs => Value.beq lhs rhs
  | _, _ => false

def publicStateDelta (initial committed : ObjectStore) : List Nat :=
  uniqueNatList (initial.objectIds ++ committed.objectIds) |>.filter
    (fun objectId =>
      !optionalValueEquivalent
        (initial.lookup objectId)
        (committed.lookup objectId))

structure PublicStateTransition where
  initialPublicState : ObjectStore
  candidatePublicState : ObjectStore
  committedPublicState : ObjectStore
  publicDelta : List Nat
  abortStatus : Bool
  deriving Inhabited

/-- The richer outcome the operational evaluator emits.

* `trace` matches the existing `TraceModel.Trace` surface so all downstream
  trace-shaped reasoning continues to project through `outcome.trace`.
* `publicResult` carries the entrypoint's public return value when the run
  completes normally. `none` when the run did not produce a return value.
* `oramAccessCounts` records per-object ORAM access counts the manifest
  exactness theorem will project against.
* `kernelSteps` records the names of the kernel-DSL operations issued by
  the evaluator. The exactness theorem ties this to the manifest's
  `kernel_steps` view.
* `status` records normal completion, explicit `Require`/`AbortIf`
  rejection, an `unsupported` IR construct (the evaluator is partial),
  or an internal `evalError`.
* `finalPublicState` records the public store after the call. It is populated
  by `evalContract`; intermediate statement/body outcomes leave it as `none`.
* `publicStateTransition` records the initial, candidate, and committed public
  stores. On any non-completed status, the committed store is the initial
  store, pinning rollback-on-abort at the evaluator boundary.

The W4.1 evaluator never panics; it always returns an outcome.
-/
structure Outcome where
  trace : Trace
  publicResult : Option Value
  oramAccessCounts : OramAccessCounts
  kernelSteps : List String
  status : EvalStatus
  finalPublicState : Option ObjectStore
  publicStateTransition : Option PublicStateTransition

namespace Outcome

@[inline] def empty : Outcome :=
  { trace := Trace.empty
  , publicResult := none
  , oramAccessCounts := []
  , kernelSteps := []
  , status := EvalStatus.completed
  , finalPublicState := none
  , publicStateTransition := none
  }

@[inline] def withGas (oc : Outcome) (gasUsed : Nat) : Outcome :=
  { oc with trace := { oc.trace with gasUsed := gasUsed } }

@[inline] def gasUsed (oc : Outcome) : Nat := oc.trace.gasUsed

@[inline] def withFinalPublicState
  (oc : Outcome) (publicState : ObjectStore) : Outcome :=
  { oc with finalPublicState := some publicState }

@[inline] def abortedForCommit (oc : Outcome) : Bool :=
  !oc.status.commitsCandidate

@[inline] def committedPublicState
  (oc : Outcome) (initialPublicState candidatePublicState : ObjectStore) :
  ObjectStore :=
  if oc.status.commitsCandidate then candidatePublicState else initialPublicState

@[inline] def toPublicStateTransition
  (oc : Outcome) (initialPublicState candidatePublicState : ObjectStore) :
  PublicStateTransition :=
  let committedPublicState := oc.committedPublicState initialPublicState candidatePublicState
  { initialPublicState
  , candidatePublicState
  , committedPublicState
  , publicDelta := publicStateDelta initialPublicState committedPublicState
  , abortStatus := oc.abortedForCommit
  }

@[inline] def withPublicStateTransition
  (oc : Outcome) (transition : PublicStateTransition) : Outcome :=
  { oc with
    finalPublicState := some transition.committedPublicState
    publicStateTransition := some transition
  }

theorem committedPublicState_abortedByUser
  (oc : Outcome) (initialPublicState candidatePublicState : ObjectStore)
  (hStatus : oc.status = EvalStatus.abortedByUser) :
  oc.committedPublicState initialPublicState candidatePublicState = initialPublicState := by
  unfold committedPublicState
  simp [hStatus, EvalStatus.commitsCandidate]

theorem committedPublicState_requireFailed
  (oc : Outcome) (initialPublicState candidatePublicState : ObjectStore)
  (hStatus : oc.status = EvalStatus.requireFailed) :
  oc.committedPublicState initialPublicState candidatePublicState = initialPublicState := by
  unfold committedPublicState
  simp [hStatus, EvalStatus.commitsCandidate]

end Outcome

end IR

/-- Real operational evaluator type. WP4-relevant theorems live against
this surface. The older abstract trace-producer surface is preserved as
`TraceSemantics`. -/
abbrev Semantics := IR.OperationalConfig → IR.Outcome

namespace IR

/-- Numeric coercion: an operational `Value` to its representational `Nat`.
Used by the evaluator's binary/unary operators. -/
def Value.asNat? : Value → Option Nat
  | .uint n => some n
  | _ => none

def Value.asBool? : Value → Option Bool
  | .bool b => some b
  | _ => none

/-- The admitted runtime integer domain. The Rust public shell and generated
confidential kernel both store `Value::Uint` as a full-width `uint256`; the Lean
evaluator keeps the payload as `Nat` but normalizes all uint operations modulo
this bound. -/
def uint256Modulus : Nat := 2 ^ 256

/-- Normalize a Lean natural into the runtime `uint256` range. -/
def uint256 (n : Nat) : Nat := n % uint256Modulus

/-- Runtime-compatible unsigned negation: `0u256.wrapping_sub(a)`. -/
def uint256Neg (a : Nat) : Nat :=
  uint256 (uint256Modulus - uint256 a)

/-- Runtime-compatible subtraction: `a.wrapping_sub(b)`. The addition by the
modulus avoids Lean's saturating `Nat` subtraction before normalization. -/
def uint256Sub (a b : Nat) : Nat :=
  uint256 (uint256 a + uint256Modulus - uint256 b)

/- Runtime structural equality for Lean values. Uint payloads are compared in
the runtime `uint256` domain; composite payloads recurse structurally in the
same field/order-sensitive shape as Rust `Value` equality. -/
mutual

partial def Value.runtimeEq : Value → Value → Bool
  | .bool a, .bool b => a == b
  | .uint a, .uint b => decide (uint256 a = uint256 b)
  | .bytes32 a, .bytes32 b => a == b
  | .address a, .address b => a == b
  | .structValue a, .structValue b => Value.runtimeEqStructFields a b
  | .array a, .array b => Value.runtimeEqList a b
  | .map a, .map b => Value.runtimeEqMapEntries a b
  | _, _ => false

partial def Value.runtimeEqList : List Value → List Value → Bool
  | [], [] => true
  | [], _ :: _ => false
  | _ :: _, [] => false
  | x :: xs, y :: ys => Value.runtimeEq x y && Value.runtimeEqList xs ys

partial def Value.runtimeEqStructFields :
    List (String × Value) → List (String × Value) → Bool
  | [], [] => true
  | [], _ :: _ => false
  | _ :: _, [] => false
  | (n1, v1) :: rest1, (n2, v2) :: rest2 =>
      n1 == n2 && Value.runtimeEq v1 v2 && Value.runtimeEqStructFields rest1 rest2

partial def Value.runtimeEqMapEntries :
    List (Value × Value) → List (Value × Value) → Bool
  | [], [] => true
  | [], _ :: _ => false
  | _ :: _, [] => false
  | (k1, v1) :: rest1, (k2, v2) :: rest2 =>
      Value.runtimeEq k1 k2 && Value.runtimeEq v1 v2 && Value.runtimeEqMapEntries rest1 rest2

end

def UnaryOp.eval (op : UnaryOp) (v : Value) : Option Value :=
  match op, v with
  | .not, .bool b => some (.bool (! b))
  | .neg, .uint a => some (.uint (uint256Neg a))
  | _, _ => none

def BinaryOp.eval (op : BinaryOp) (lhs rhs : Value) : Option Value :=
  match op, lhs, rhs with
  | .add, .uint a, .uint b => some (.uint (uint256 (a + b)))
  | .sub, .uint a, .uint b => some (.uint (uint256Sub a b))
  | .mul, .uint a, .uint b => some (.uint (uint256 (a * b)))
  | .div, .uint a, .uint b =>
      let divisor := uint256 b
      if divisor = 0 then some (.uint 0) else some (.uint (uint256 a / divisor))
  | .mod, .uint a, .uint b =>
      let divisor := uint256 b
      if divisor = 0 then some (.uint 0) else some (.uint (uint256 a % divisor))
  | .bitAnd, .uint a, .uint b => some (.uint (uint256 (uint256 a &&& uint256 b)))
  | .bitOr, .uint a, .uint b => some (.uint (uint256 (uint256 a ||| uint256 b)))
  | .bitXor, .uint a, .uint b => some (.uint (uint256 (uint256 a ^^^ uint256 b)))
  | .eq, lhs, rhs => some (.bool (Value.runtimeEq lhs rhs))
  | .neq, lhs, rhs => some (.bool (! Value.runtimeEq lhs rhs))
  | .lt, .uint a, .uint b => some (.bool (decide (uint256 a < uint256 b)))
  | .lte, .uint a, .uint b => some (.bool (decide (uint256 a ≤ uint256 b)))
  | .gt, .uint a, .uint b => some (.bool (decide (uint256 b < uint256 a)))
  | .gte, .uint a, .uint b => some (.bool (decide (uint256 b ≤ uint256 a)))
  | .logicAnd, .bool a, .bool b => some (.bool (a && b))
  | .logicOr, .bool a, .bool b => some (.bool (a || b))
  | _, _, _ => none

theorem uint256_wraps_at_modulus : uint256 (2 ^ 256) = 0 := by
  native_decide

theorem unaryNeg_matches_uint256_wrapping :
    UnaryOp.eval .neg (.uint 1) = some (.uint ((2 ^ 256) - 1)) := by
  rfl

theorem binaryAdd_matches_uint256_wrapping :
    BinaryOp.eval .add (.uint ((2 ^ 256) - 1)) (.uint 1) = some (.uint 0) := by
  rfl

theorem binarySub_matches_uint256_wrapping :
    BinaryOp.eval .sub (.uint 0) (.uint 1) = some (.uint ((2 ^ 256) - 1)) := by
  rfl

theorem binaryMul_matches_uint256_wrapping :
    BinaryOp.eval .mul (.uint (2 ^ 255)) (.uint 2) = some (.uint 0) := by
  rfl

theorem binaryDivByZero_matches_runtime :
    BinaryOp.eval .div (.uint 7) (.uint 0) = some (.uint 0) := by
  rfl

theorem binaryModByZero_matches_runtime :
    BinaryOp.eval .mod (.uint 7) (.uint 0) = some (.uint 0) := by
  rfl

theorem binaryEq_matches_runtimeStructuralValueEquality
    (lhs rhs : Value) :
    BinaryOp.eval .eq lhs rhs = some (.bool (Value.runtimeEq lhs rhs)) := by
  rfl

theorem binaryNeq_matches_runtimeStructuralValueEquality
    (lhs rhs : Value) :
    BinaryOp.eval .neq lhs rhs = some (.bool (! Value.runtimeEq lhs rhs)) := by
  rfl

theorem binaryEq_uint256_normalizes_operands :
    BinaryOp.eval .eq (.uint (2 ^ 256)) (.uint 0) = some (.bool true) := by
  rw [binaryEq_matches_runtimeStructuralValueEquality]
  congr
  native_decide

theorem binaryEq_bytes32_supported :
    BinaryOp.eval .eq
        (.bytes32 (List.replicate 32 0))
        (.bytes32 (List.replicate 32 0)) =
      some (.bool true) := by
  rw [binaryEq_matches_runtimeStructuralValueEquality]
  congr
  native_decide

theorem binaryEq_address_supported :
    BinaryOp.eval .eq
        (.address (List.replicate 20 0))
        (.address (List.replicate 20 0)) =
      some (.bool true) := by
  rw [binaryEq_matches_runtimeStructuralValueEquality]
  congr
  native_decide

theorem binaryEq_fixedArray_supported :
    BinaryOp.eval .eq
        (.array [.uint 1, .bool true])
        (.array [.uint 1, .bool true]) =
      some (.bool true) := by
  rw [binaryEq_matches_runtimeStructuralValueEquality]
  congr
  native_decide

theorem binaryEq_fixedStruct_supported :
    BinaryOp.eval .eq
        (.structValue [("flag", .bool true), ("owner", .address (List.replicate 20 0))])
        (.structValue [("flag", .bool true), ("owner", .address (List.replicate 20 0))]) =
      some (.bool true) := by
  rw [binaryEq_matches_runtimeStructuralValueEquality]
  congr
  native_decide

theorem binaryEq_mismatchedConstructors_runtimeStructuralFalse :
    BinaryOp.eval .eq
        (.bytes32 (List.replicate 32 0))
        (.address (List.replicate 20 0)) =
      some (.bool false) := by
  rw [binaryEq_matches_runtimeStructuralValueEquality]
  congr
  native_decide

/-! ## Store ownership helpers

Storage reads and writes are resolved through the declared object map. Unknown
object ids fail closed instead of defaulting to public state. -/

/-- Look up an object declaration by id in the contract state map. -/
def OperationalConfig.stateObjectById?
    (cfg : OperationalConfig) (objectId : Nat) : Option StateObject :=
  cfg.contract.state.find? (fun so => so.id = objectId)

/-- Confidentiality of a known object. Unknown object ids produce `none`
instead of defaulting to public. -/
def OperationalConfig.objectConfidential?
    (cfg : OperationalConfig) (objectId : Nat) : Option Bool :=
  match cfg.stateObjectById? objectId with
  | some so => some so.confidential
  | none => none

def ObjectStore.remove (store : ObjectStore) (objectId : Nat) : ObjectStore :=
  store.filter (fun entry => entry.fst ≠ objectId)

theorem ObjectStore.lookup_filter_removed_ne
    (store : ObjectStore) (removedId queryId : Nat)
    (hNe : queryId ≠ removedId) :
    ObjectStore.lookup (store.filter (fun entry => entry.fst ≠ removedId)) queryId =
      ObjectStore.lookup store queryId := by
  induction store with
  | nil =>
      simp [ObjectStore.lookup]
  | cons entry rest ih =>
      rcases entry with ⟨entryId, entryValue⟩
      by_cases hRemoved : entryId = removedId
      · have hNotQuery : ¬ entryId = queryId := by
          intro hQuery
          exact hNe (hQuery.symm.trans hRemoved)
        have hRemovedNotQuery : ¬ removedId = queryId := by
          intro hQuery
          exact hNe hQuery.symm
        simpa [ObjectStore.lookup, hRemoved, hNotQuery, hRemovedNotQuery] using ih
      · by_cases hQuery : entryId = queryId
        · simp [ObjectStore.lookup, hQuery, hNe]
        · simpa [ObjectStore.lookup, hRemoved, hQuery] using ih

theorem ObjectStore.lookup_remove_eq
    (store : ObjectStore) (objectId : Nat) :
    ObjectStore.lookup (store.remove objectId) objectId = none := by
  induction store with
  | nil =>
      simp [ObjectStore.remove, ObjectStore.lookup]
  | cons entry rest ih =>
      rcases entry with ⟨entryId, entryValue⟩
      by_cases hRemoved : entryId = objectId
      · simpa [ObjectStore.remove, ObjectStore.lookup, hRemoved] using ih
      · simpa [ObjectStore.remove, ObjectStore.lookup, hRemoved] using ih

theorem ObjectStore.lookup_remove_ne
    (store : ObjectStore) (removedId queryId : Nat)
    (hNe : queryId ≠ removedId) :
    ObjectStore.lookup (store.remove removedId) queryId =
      ObjectStore.lookup store queryId := by
  simpa [ObjectStore.remove] using
    ObjectStore.lookup_filter_removed_ne store removedId queryId hNe

theorem ObjectStore.lookup_insert_eq
    (store : ObjectStore) (objectId : Nat) (value : Value) :
    ObjectStore.lookup (store.insert objectId value) objectId = some value := by
  simp [ObjectStore.insert, ObjectStore.lookup]

theorem ObjectStore.lookup_insert_ne
    (store : ObjectStore) (writeId queryId : Nat) (value : Value)
    (hNe : queryId ≠ writeId) :
    ObjectStore.lookup (store.insert writeId value) queryId =
      ObjectStore.lookup store queryId := by
  have hHead : ¬ writeId = queryId := by
    intro h
    exact hNe h.symm
  simpa [ObjectStore.insert, ObjectStore.lookup, hHead] using
    ObjectStore.lookup_filter_removed_ne store writeId queryId hNe

/-- Object ids in a store are owned by public state exactly when the contract
declares them public. -/
def OperationalConfig.publicStoreAgreesWithObjectMap
    (cfg : OperationalConfig) : Prop :=
  ∀ objectId value,
    cfg.publicState.lookup objectId = some value →
      cfg.objectConfidential? objectId = some false

/-- Object ids in a store are owned by secret state exactly when the contract
declares them confidential. -/
def OperationalConfig.secretStoreAgreesWithObjectMap
    (cfg : OperationalConfig) : Prop :=
  ∀ objectId value,
    cfg.secretState.lookup objectId = some value →
      cfg.objectConfidential? objectId = some true

/-- Public and secret stores must not both own the same logical object. -/
def OperationalConfig.storeOwnershipDisjoint
    (cfg : OperationalConfig) : Prop :=
  ∀ objectId publicValue secretValue,
    cfg.publicState.lookup objectId = some publicValue →
      cfg.secretState.lookup objectId = some secretValue →
        False

/-- The operational state invariant required by evaluator theorems. It records
the object-map ownership discipline that the Rust deployment checks enforce
before execution: declared object ids are unique, every store entry is owned by
the matching public/secret store, and no object is present in both stores. -/
def OperationalConfig.WellFormed
    (cfg : OperationalConfig) : Prop :=
  (cfg.contract.state.map StateObject.id).Nodup ∧
    cfg.publicStoreAgreesWithObjectMap ∧
    cfg.secretStoreAgreesWithObjectMap ∧
    cfg.storeOwnershipDisjoint

/-- Update the object's value in the appropriate store (public or secret
based on confidentiality). Unknown objects return `none`. The opposite store
is scrubbed for the same id to preserve the public/secret ownership split even
when the input configuration was malformed. -/
def OperationalConfig.writeObject?
    (cfg : OperationalConfig) (objectId : Nat) (value : Value) :
    Option OperationalConfig :=
  match cfg.objectConfidential? objectId with
  | some true =>
      some
        { cfg with
          secretState := cfg.secretState.insert objectId value
          publicState := cfg.publicState.remove objectId }
  | some false =>
      some
        { cfg with
          publicState := cfg.publicState.insert objectId value
          secretState := cfg.secretState.remove objectId }
  | none => none

theorem OperationalConfig.writeObject?_wellFormed
    {cfg cfg' : OperationalConfig} {objectId : Nat} {value : Value}
    (hWF : cfg.WellFormed)
    (hWrite : cfg.writeObject? objectId value = some cfg') :
    cfg'.WellFormed := by
  rcases hWF with ⟨hNodup, hPublic, hSecret, hDisjoint⟩
  unfold OperationalConfig.writeObject? at hWrite
  cases hConf : cfg.objectConfidential? objectId with
  | none =>
      simp [hConf] at hWrite
  | some confidential =>
      cases confidential
      · simp [hConf] at hWrite
        cases hWrite
        refine ⟨hNodup, ?_, ?_, ?_⟩
        · intro queryId storedValue hLookup
          by_cases hSame : queryId = objectId
          · subst queryId
            simpa [OperationalConfig.objectConfidential?,
              OperationalConfig.stateObjectById?] using hConf
          · have hOriginal :
                cfg.publicState.lookup queryId = some storedValue := by
              simpa [ObjectStore.lookup_insert_ne, hSame] using hLookup
            simpa [OperationalConfig.objectConfidential?,
              OperationalConfig.stateObjectById?] using
                hPublic queryId storedValue hOriginal
        · intro queryId storedValue hLookup
          by_cases hSame : queryId = objectId
          · subst queryId
            have hNone :
                (cfg.secretState.remove objectId).lookup objectId = none :=
              ObjectStore.lookup_remove_eq cfg.secretState objectId
            simp [hNone] at hLookup
          · have hOriginal :
                cfg.secretState.lookup queryId = some storedValue := by
              simpa [ObjectStore.lookup_remove_ne, hSame] using hLookup
            simpa [OperationalConfig.objectConfidential?,
              OperationalConfig.stateObjectById?] using
                hSecret queryId storedValue hOriginal
        · intro queryId publicValue secretValue hPublicLookup hSecretLookup
          by_cases hSame : queryId = objectId
          · subst queryId
            have hNone :
                (cfg.secretState.remove objectId).lookup objectId = none :=
              ObjectStore.lookup_remove_eq cfg.secretState objectId
            simp [hNone] at hSecretLookup
          · have hPublicOriginal :
                cfg.publicState.lookup queryId = some publicValue := by
              simpa [ObjectStore.lookup_insert_ne, hSame] using hPublicLookup
            have hSecretOriginal :
                cfg.secretState.lookup queryId = some secretValue := by
              simpa [ObjectStore.lookup_remove_ne, hSame] using hSecretLookup
            exact hDisjoint queryId publicValue secretValue
              hPublicOriginal hSecretOriginal
      · simp [hConf] at hWrite
        cases hWrite
        refine ⟨hNodup, ?_, ?_, ?_⟩
        · intro queryId storedValue hLookup
          by_cases hSame : queryId = objectId
          · subst queryId
            have hNone :
                (cfg.publicState.remove objectId).lookup objectId = none :=
              ObjectStore.lookup_remove_eq cfg.publicState objectId
            simp [hNone] at hLookup
          · have hOriginal :
                cfg.publicState.lookup queryId = some storedValue := by
              simpa [ObjectStore.lookup_remove_ne, hSame] using hLookup
            simpa [OperationalConfig.objectConfidential?,
              OperationalConfig.stateObjectById?] using
                hPublic queryId storedValue hOriginal
        · intro queryId storedValue hLookup
          by_cases hSame : queryId = objectId
          · subst queryId
            simpa [OperationalConfig.objectConfidential?,
              OperationalConfig.stateObjectById?] using hConf
          · have hOriginal :
                cfg.secretState.lookup queryId = some storedValue := by
              simpa [ObjectStore.lookup_insert_ne, hSame] using hLookup
            simpa [OperationalConfig.objectConfidential?,
              OperationalConfig.stateObjectById?] using
                hSecret queryId storedValue hOriginal
        · intro queryId publicValue secretValue hPublicLookup hSecretLookup
          by_cases hSame : queryId = objectId
          · subst queryId
            have hNone :
                (cfg.publicState.remove objectId).lookup objectId = none :=
              ObjectStore.lookup_remove_eq cfg.publicState objectId
            simp [hNone] at hPublicLookup
          · have hPublicOriginal :
                cfg.publicState.lookup queryId = some publicValue := by
              simpa [ObjectStore.lookup_remove_ne, hSame] using hPublicLookup
            have hSecretOriginal :
                cfg.secretState.lookup queryId = some secretValue := by
              simpa [ObjectStore.lookup_insert_ne, hSame] using hSecretLookup
            exact hDisjoint queryId publicValue secretValue
              hPublicOriginal hSecretOriginal

/-- Total wrapper for legacy proof statements that already prove object
existence through `readObject`. New evaluator branches use `writeObject?` so an
unknown object produces an explicit `evalError`. -/
def OperationalConfig.writeObject
    (cfg : OperationalConfig) (objectId : Nat) (value : Value) :
    OperationalConfig :=
  match cfg.writeObject? objectId value with
  | some cfg' => cfg'
  | none => cfg

/-- Read the object's value from the store declared by the object map. Unknown
objects fail closed with `none`; public store entries never shadow secret
objects and secret entries never shadow public objects. -/
def OperationalConfig.readObject
    (cfg : OperationalConfig) (objectId : Nat) : Option Value :=
  match cfg.objectConfidential? objectId with
  | some true => cfg.secretState.lookup objectId
  | some false => cfg.publicState.lookup objectId
  | none => none

theorem OperationalConfig.readObject_unknown_none
    (cfg : OperationalConfig) (objectId : Nat)
    (hUnknown : cfg.stateObjectById? objectId = none) :
    cfg.readObject objectId = none := by
  simp [OperationalConfig.readObject, OperationalConfig.objectConfidential?,
    hUnknown]

theorem OperationalConfig.readObject_confidential_uses_secret
    (cfg : OperationalConfig) (objectId : Nat) (object : StateObject)
    (hLookup : cfg.stateObjectById? objectId = some object)
    (hConf : object.confidential = true) :
    cfg.readObject objectId = cfg.secretState.lookup objectId := by
  simp [OperationalConfig.readObject, OperationalConfig.objectConfidential?,
    hLookup, hConf]

theorem OperationalConfig.readObject_public_uses_public
    (cfg : OperationalConfig) (objectId : Nat) (object : StateObject)
    (hLookup : cfg.stateObjectById? objectId = some object)
    (hConf : object.confidential = false) :
    cfg.readObject objectId = cfg.publicState.lookup objectId := by
  simp [OperationalConfig.readObject, OperationalConfig.objectConfidential?,
    hLookup, hConf]

/-- Evaluator outcome for a single expression: either a value, or an
explicit `EvalStatus` indicating why it could not be produced. -/
inductive ExprResult where
  | value (v : Value)
  | status (s : EvalStatus)
  deriving Inhabited

mutual

/-- Big-step expression evaluator over the structured IR.

Defined as `def` (not `partial def`) so the equations can be reduced
by `rfl` / `simp`, which downstream WP4 preservation proofs require.
The mutual companion `evalExprList` walks the parts of `keccak256`
without the `partial`-only `let rec` form. Termination is proved
structurally on `sizeOf` of the input. -/
def evalExpr (cfg : OperationalConfig) (env : LocalEnv) :
    Expr → ExprResult
  | .literal v => .value v
  | .var name =>
      match env.lookup name with
      | some v => .value v
      | none => .status (.evalError s!"undefined variable {name}")
  | .unary op e =>
      match evalExpr cfg env e with
      | .value v =>
          match op.eval v with
          | some v' => .value v'
          | none => .status (.evalError "unary type mismatch")
      | r => r
  | .binary op lhs rhs =>
      match evalExpr cfg env lhs with
      | .status s => .status s
      | .value lv =>
          match evalExpr cfg env rhs with
          | .status s => .status s
          | .value rv =>
              match op.eval lv rv with
              | some v => .value v
              | none => .status (.evalError "binary type mismatch")
  | .select cond whenTrue whenFalse =>
      match evalExpr cfg env cond with
      | .status s => .status s
      | .value (.bool true) => evalExpr cfg env whenTrue
      | .value (.bool false) => evalExpr cfg env whenFalse
      | .value _ => .status (.evalError "select condition not boolean")
  | .cellGet objectId =>
      match cfg.readObject objectId with
      | some v => .value v
      | none => .status (.evalError s!"cellGet on unknown object {objectId}")
  | .arrayGet objectId indexExpr =>
      match evalExpr cfg env indexExpr with
      | .status s => .status s
      | .value indexVal =>
          match indexVal with
          | .uint idx =>
              -- Look up the object's array value through the declared object
              -- map, then index into the underlying `Value.array`.
              match cfg.readObject objectId with
              | some (.array values) =>
                  match values[idx]? with
                  | some v => .value v
                  | none =>
                      .status (.evalError s!"arrayGet index {idx} out of bounds")
              | some _ =>
                  .status (.evalError s!"arrayGet on non-array object {objectId}")
              | none =>
                  .status (.evalError s!"arrayGet on unknown object {objectId}")
          | _ => .status (.evalError "arrayGet index not uint")
  | .mapGet objectId keyExpr =>
      match evalExpr cfg env keyExpr with
      | .status s => .status s
      | .value keyVal =>
          -- Look up the object's `Value.map` through the declared object map,
          -- then search its entries by key using `Value.beq`.
          match cfg.readObject objectId with
          | some (.map entries) =>
              match Value.mapLookup entries keyVal with
              | some v => .value v
              | none =>
                  .status (.evalError s!"mapGet missing key in object {objectId}")
          | some _ =>
              .status (.evalError s!"mapGet on non-map object {objectId}")
          | none =>
              .status (.evalError s!"mapGet on unknown object {objectId}")
  | .structField _ _ =>
      -- `Expr.structField` is forbidden by `Expr.fragmentValid`; keeping it
      -- `unsupported` matches the W4.3 admission.
      .status (.unsupported "Expr.structField")
  | .arrayIndex _ _ =>
      -- `Expr.arrayIndex` is forbidden by `Expr.fragmentValid`.
      .status (.unsupported "Expr.arrayIndex")
  | .keccak256 parts =>
      -- Each sub-expression is evaluated in order via the mutual companion
      -- `evalExprList`; the Lean source/IR/kernel preservation chain uses the
      -- shared `Value.keccak256Mock` abstraction, not the runtime's real
      -- Keccak bits.
      match evalExprList cfg env parts with
      | .error s => .status s
      | .ok vs => .value (Value.keccak256Mock vs)

/-- List companion for `evalExpr`, used for the `keccak256` case. -/
def evalExprList (cfg : OperationalConfig) (env : LocalEnv) :
    List Expr → Except EvalStatus (List Value)
  | [] => .ok []
  | p :: rest =>
      match evalExpr cfg env p with
      | .status s => .error s
      | .value v =>
          match evalExprList cfg env rest with
          | .ok vs => .ok (v :: vs)
          | .error s => .error s

end

/-! ## Store-update helpers -/

/-- Replace the element at `index` in a `Value.array`'s underlying list.
Returns the original list if `index` is out of bounds. The W4.1
evaluator's caller turns out-of-bounds into an explicit
`EvalStatus.evalError`. -/
def Value.arraySetAt (values : List Value) (index : Nat) (newVal : Value) :
    List Value :=
  values.mapIdx (fun i v => if i = index then newVal else v)

/-- Insert or update a `(key, value)` entry in a map's entry list. If a
matching key exists (by `Value.beq`), replace its value; otherwise
prepend a new entry. -/
def Value.mapInsert (entries : List (Value × Value)) (key value : Value) :
    List (Value × Value) :=
  if entries.any (fun entry => Value.beq entry.fst key) then
    entries.map (fun entry =>
      if Value.beq entry.fst key then (entry.fst, value) else entry)
  else
    (key, value) :: entries

mutual

/-- Big-step statement evaluator step. Threads an updated
`OperationalConfig` through so `cellSet` / `arraySet` / `mapPut` can
perform predicate-driven masked-store updates and so subsequent
statements observe the new store.

`evalStatement` and `evalBody` are mutually recursive so that
`Statement.ifStmt` and `Statement.forLoop` can recurse into nested
statement bodies via `evalBody`. -/
def evalStatement
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    Statement → OperationalConfig × LocalEnv × Outcome
  | .declare name _ value =>
      match evalExpr cfg env value with
      | .value v => (cfg, env.insert name v, oc)
      | .status s => (cfg, env, { oc with status := s })
  | .assign name value =>
      match evalExpr cfg env value with
      | .value v => (cfg, env.insert name v, oc)
      | .status s => (cfg, env, { oc with status := s })
  | .require cond =>
      match evalExpr cfg env cond with
      | .value (.bool true) => (cfg, env, oc)
      | .value (.bool false) => (cfg, env, { oc with status := .requireFailed })
      | .value _ => (cfg, env, { oc with status := .evalError "require not boolean" })
      | .status s => (cfg, env, { oc with status := s })
  | .abortIf cond =>
      match evalExpr cfg env cond with
      | .value (.bool true) => (cfg, env, { oc with status := .abortedByUser })
      | .value (.bool false) => (cfg, env, oc)
      | .value _ => (cfg, env, { oc with status := .evalError "abortIf not boolean" })
      | .status s => (cfg, env, { oc with status := s })
  | .cellSet objectId value predicate =>
      -- Masked-store semantics: write the new value when the predicate
      -- is true (or absent); leave the cell unchanged otherwise. The
      -- kernel step is recorded unconditionally to mirror the runtime's
      -- always-write access pattern.
      match evalExpr cfg env value with
      | .status s => (cfg, env, { oc with status := s })
      | .value newVal =>
          let oc' := { oc with kernelSteps := oc.kernelSteps ++ ["CellSet"] }
          match predicate with
          | none =>
              match cfg.writeObject? objectId newVal with
              | some cfg' => (cfg', env, oc')
              | none =>
                  let msg := s!"cellSet on unknown object {objectId}"
                  (cfg, env, { oc with status := .evalError msg })
          | some predExpr =>
              match evalExpr cfg env predExpr with
              | .status s => (cfg, env, { oc with status := s })
              | .value (.bool true) =>
                  match cfg.writeObject? objectId newVal with
                  | some cfg' => (cfg', env, oc')
                  | none =>
                      let msg := s!"cellSet on unknown object {objectId}"
                      (cfg, env, { oc with status := .evalError msg })
              | .value (.bool false) => (cfg, env, oc')
              | .value _ =>
                  (cfg, env, { oc with status := .evalError "cellSet predicate not boolean" })
  | .arraySet objectId index value predicate =>
      match evalExpr cfg env index with
      | .status s => (cfg, env, { oc with status := s })
      | .value indexVal =>
          match evalExpr cfg env value with
          | .status s => (cfg, env, { oc with status := s })
          | .value newVal =>
              let oc' := { oc with kernelSteps := oc.kernelSteps ++ ["ArraySet"] }
              -- Resolve "should we write?" based on the predicate, then
              -- if writing, replace `array[index]` in the stored
              -- `Value.array`.
              let shouldWrite : Except EvalStatus Bool :=
                match predicate with
                | none => .ok true
                | some predExpr =>
                    match evalExpr cfg env predExpr with
                    | .status s => .error s
                    | .value (.bool true) => .ok true
                    | .value (.bool false) => .ok false
                    | .value _ =>
                        .error (.evalError "arraySet predicate not boolean")
              match shouldWrite with
              | .error s => (cfg, env, { oc with status := s })
              | .ok false => (cfg, env, oc')
              | .ok true =>
                  match indexVal with
                  | .uint idx =>
                      match cfg.readObject objectId with
                      | some (.array values) =>
                          if idx ≥ values.length then
                            let msg := s!"arraySet index {idx} out of bounds"
                            (cfg, env, { oc with status := .evalError msg })
                          else
                            let updated := Value.array (Value.arraySetAt values idx newVal)
                            match cfg.writeObject? objectId updated with
                            | some cfg' => (cfg', env, oc')
                            | none =>
                                let msg := s!"arraySet on unknown object {objectId}"
                                (cfg, env, { oc with status := .evalError msg })
                      | some _ =>
                          let msg := s!"arraySet on non-array object {objectId}"
                          (cfg, env, { oc with status := .evalError msg })
                      | none =>
                          let msg := s!"arraySet on unknown object {objectId}"
                          (cfg, env, { oc with status := .evalError msg })
                  | _ =>
                      (cfg, env, { oc with status := .evalError "arraySet index not uint" })
  | .mapPut objectId key value predicate =>
      match evalExpr cfg env key with
      | .status s => (cfg, env, { oc with status := s })
      | .value keyVal =>
          match evalExpr cfg env value with
          | .status s => (cfg, env, { oc with status := s })
          | .value newVal =>
              let oc' := { oc with kernelSteps := oc.kernelSteps ++ ["MapPut"] }
              let shouldWrite : Except EvalStatus Bool :=
                match predicate with
                | none => .ok true
                | some predExpr =>
                    match evalExpr cfg env predExpr with
                    | .status s => .error s
                    | .value (.bool true) => .ok true
                    | .value (.bool false) => .ok false
                    | .value _ =>
                        .error (.evalError "mapPut predicate not boolean")
              match shouldWrite with
              | .error s => (cfg, env, { oc with status := s })
              | .ok false => (cfg, env, oc')
              | .ok true =>
                  match cfg.readObject objectId with
                  | some (.map entries) =>
                      let updated := Value.map (Value.mapInsert entries keyVal newVal)
                      match cfg.writeObject? objectId updated with
                      | some cfg' => (cfg', env, oc')
                      | none =>
                          let msg := s!"mapPut on unknown object {objectId}"
                          (cfg, env, { oc with status := .evalError msg })
                  | some _ =>
                      let msg := s!"mapPut on non-map object {objectId}"
                      (cfg, env, { oc with status := .evalError msg })
                  | none =>
                      -- New map: start a fresh entries list.
                      let updated := Value.map [(keyVal, newVal)]
                      match cfg.writeObject? objectId updated with
                      | some cfg' => (cfg', env, oc')
                      | none =>
                          let msg := s!"mapPut on unknown object {objectId}"
                          (cfg, env, { oc with status := .evalError msg })
  | .ifStmt cond thenBody elseBody =>
      -- Public-conditional control flow: evaluate the condition, then
      -- recurse into the chosen branch via `evalBody`.
      match evalExpr cfg env cond with
      | .status s => (cfg, env, { oc with status := s })
      | .value (.bool true) => evalBody cfg env oc thenBody
      | .value (.bool false) => evalBody cfg env oc elseBody
      | .value _ => (cfg, env, { oc with status := .evalError "if condition not boolean" })
  | .forLoop _loopId indexVar startExpr endExpr body =>
      -- Bounded loop: the admitted fragment requires `start` and `end`
      -- to be public, so the iteration count is fixed by the public
      -- projection.
      match evalExpr cfg env startExpr with
      | .status s => (cfg, env, { oc with status := s })
      | .value startVal =>
          match evalExpr cfg env endExpr with
          | .status s => (cfg, env, { oc with status := s })
          | .value endVal =>
              match startVal, endVal with
              | .uint startN, .uint endN =>
                  evalForLoop cfg env oc indexVar startN endN body
              | _, _ =>
                  (cfg, env, { oc with status := .evalError "for-loop bounds not uint" })
  | .retStmt none => (cfg, env, oc)
  | .retStmt (some value) =>
      match evalExpr cfg env value with
      | .value v => (cfg, env, { oc with publicResult := some v })
      | .status s => (cfg, env, { oc with status := s })
termination_by s => (sizeOf s, 0)

def evalBody
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    List Statement → OperationalConfig × LocalEnv × Outcome
  | [] => (cfg, env, oc)
  | stmt :: rest =>
      let (cfg', env', oc') := evalStatement cfg env oc stmt
      match oc'.status with
      | .completed =>
          if oc'.publicResult.isSome then (cfg', env', oc')
          else evalBody cfg' env' oc' rest
      | _ => (cfg', env', oc')
termination_by stmts => (sizeOf stmts, 0)

/-- Bounded for-loop helper. The loop runs from `i` (inclusive) to `endN`
(exclusive). Each iteration binds `indexVar` to `Value.uint i` and
walks `body` via `evalBody`, threading the updated config through. The
loop exits early on a `retStmt` or any non-`completed` status. -/
def evalForLoop
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome)
    (indexVar : String) (i endN : Nat) (body : List Statement) :
    OperationalConfig × LocalEnv × Outcome :=
  if i ≥ endN then (cfg, env, oc)
  else
    let env' := env.insert indexVar (.uint i)
    let (cfg', env'', oc') := evalBody cfg env' oc body
    match oc'.status with
    | .completed =>
        if oc'.publicResult.isSome then (cfg', env'', oc')
        else evalForLoop cfg' env'' oc' indexVar (i + 1) endN body
    | _ => (cfg', env'', oc')
termination_by (sizeOf body, endN - i)

end

/-- Lookup the entrypoint function inside the contract. -/
def OperationalConfig.entrypointFn? (cfg : OperationalConfig) :
    Option CompiledFunction :=
  cfg.contract.functions.find? (fun fn => fn.signature = cfg.entrypoint)

/-- Construct the initial environment from the entrypoint parameters and
the supplied public/secret arguments. The current cut concatenates the
public arguments first, then the secret arguments, in their declared
order; this matches `uo-solc`'s parameter encoding for confidential
entrypoints. -/
def OperationalConfig.initialEnv (cfg : OperationalConfig)
    (fn : CompiledFunction) : Option LocalEnv :=
  let allArgs := cfg.publicArgs ++ cfg.secretArgs
  if allArgs.length = fn.params.length then
    some <| (fn.params.zip allArgs).foldl
      (fun env entry => env.insert entry.fst.name entry.snd) []
  else
    none

/-- Big-step contract evaluator. Looks up the entrypoint, binds arguments,
walks the body, and returns the resulting `Outcome`, including the final
public store. The final secret store and `LocalEnv` remain internal to the
evaluator surface. -/
def evalContract (cfg : OperationalConfig) : Outcome :=
  match cfg.entrypointFn? with
  | none =>
      let outcome :=
        { Outcome.empty with
          status := .evalError s!"unknown entrypoint {cfg.entrypoint}" }
      outcome.withPublicStateTransition
        (outcome.toPublicStateTransition cfg.publicState cfg.publicState)
  | some fn =>
      match cfg.initialEnv fn with
      | none =>
          let outcome :=
            { Outcome.empty with
              status := .evalError "argument arity mismatch" }
          outcome.withPublicStateTransition
            (outcome.toPublicStateTransition cfg.publicState cfg.publicState)
      | some env =>
          let (cfg', _env', outcome) := evalBody cfg env Outcome.empty fn.body
          outcome.withPublicStateTransition
            (outcome.toPublicStateTransition cfg.publicState cfg'.publicState)

theorem evalContract_commits_initial_publicState_on_aborted_body
  (cfg cfg' : OperationalConfig)
  (fn : CompiledFunction)
  (env env' : LocalEnv)
  (outcome : Outcome)
  (hEntry : cfg.entrypointFn? = some fn)
  (hEnv : cfg.initialEnv fn = some env)
  (hEval : evalBody cfg env Outcome.empty fn.body = (cfg', env', outcome))
  (hStatus : outcome.status = EvalStatus.abortedByUser) :
  (evalContract cfg).finalPublicState = some cfg.publicState := by
  unfold evalContract
  simp [hEntry, hEnv, hEval, Outcome.withPublicStateTransition,
    Outcome.toPublicStateTransition, Outcome.committedPublicState,
    hStatus, EvalStatus.commitsCandidate]

theorem evalContract_commits_initial_publicState_on_requireFailed_body
  (cfg cfg' : OperationalConfig)
  (fn : CompiledFunction)
  (env env' : LocalEnv)
  (outcome : Outcome)
  (hEntry : cfg.entrypointFn? = some fn)
  (hEnv : cfg.initialEnv fn = some env)
  (hEval : evalBody cfg env Outcome.empty fn.body = (cfg', env', outcome))
  (hStatus : outcome.status = EvalStatus.requireFailed) :
  (evalContract cfg).finalPublicState = some cfg.publicState := by
  unfold evalContract
  simp [hEntry, hEnv, hEval, Outcome.withPublicStateTransition,
    Outcome.toPublicStateTransition, Outcome.committedPublicState,
    hStatus, EvalStatus.commitsCandidate]

theorem publicStateTransition_requireFailed_commits_initial
  (initialPublicState candidatePublicState : ObjectStore) :
  (Outcome.toPublicStateTransition
      ({ Outcome.empty with status := EvalStatus.requireFailed } : Outcome)
      initialPublicState
      candidatePublicState).committedPublicState =
    initialPublicState := by
  rfl

theorem publicStateTransition_abortIf_commits_initial
  (initialPublicState candidatePublicState : ObjectStore) :
  (Outcome.toPublicStateTransition
      ({ Outcome.empty with status := EvalStatus.abortedByUser } : Outcome)
      initialPublicState
      candidatePublicState).committedPublicState =
    initialPublicState := by
  rfl

end IR

end UOToolchain
