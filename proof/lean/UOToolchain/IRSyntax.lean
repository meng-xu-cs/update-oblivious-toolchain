/-!
# UO IR syntax (Lean mirror of `crates/uo-core/src/ir.rs`)

This module pins the admitted Solidity-like UO DSL's IR surface as Lean inductives,
mirroring the Rust IR data types one-for-one. Operational semantics is
defined separately in `IRSemantics.lean`.

The mirror covers the data types that `uo-solc` actually emits:

- the value/type universe of `crates/uo-core/src/types.rs`
- the IR program shape of `crates/uo-core/src/ir.rs` (`ProgramMode`,
  `ContainerKind`, `BackendKind`, `StateObject`, `UnaryOp`, `BinaryOp`,
  `Expr`, `Statement`, `CompiledFunction`, `CompiledContract`)

The inductives intentionally stop at `confidential_program` /
`confidential_slot_program` — those carry the kernel-DSL representation,
which has its own Lean mirror in `RuntimeKernelDslJson.lean`. WP4 keeps the
IR-level mirror separate so that the kernel-side mirror remains the
authoritative source for the lowered confidential surface.
-/

namespace UOToolchain.IR

/-- Mirror of `crates/uo-core/src/types.rs`'s `ScalarType`. -/
inductive ScalarType where
  | bool
  | uint (width : Nat)
  | bytes32
  | address
  deriving Repr, DecidableEq, Inhabited

/-- Mirror of `crates/uo-core/src/types.rs`'s `Type`. Renamed to `Ty` because
`Type` is a Lean reserved identifier.

The inner `struct` and `array` constructors mirror the Rust enum exactly;
operational support for composite values is admitted incrementally inside
the evaluator.
-/
inductive Ty where
  | scalar (s : ScalarType)
  | structTy (fields : List (String × Ty))
  | array (elem : Ty) (size : Nat)
  deriving Inhabited

/-- Mirror of `crates/uo-core/src/types.rs`'s `Value`. The `uint` payload is
modeled as `Nat` instead of Rust's full-width `Uint256`; the operational
evaluator normalizes uint operations into the runtime `uint256` domain.

The `map` variant is the Lean-side representation of a confidential
`UOMap` instance: a list of `(key, value)` entries the evaluator can
search by key. The Rust runtime uses Path-ORAM with `Keccak(key)` as the
lookup key, but the W4.1 evaluator operates one level higher (over
plaintext entries) so that the W4.4 IR-to-kernel preservation theorem
can compare evaluator outcomes directly. The map's *physical*
representation is part of the storage backend's responsibility, not the
W4.1 evaluator's. -/
inductive Value where
  | bool (b : Bool)
  | uint (n : Nat)
  | bytes32 (bytes : List UInt8)
  | address (bytes : List UInt8)
  | structValue (fields : List (String × Value))
  | array (values : List Value)
  | map (entries : List (Value × Value))
  deriving Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `ProgramMode`. -/
inductive ProgramMode where
  | raw
  | uo
  deriving Repr, DecidableEq, Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `ContainerKind`. -/
inductive ContainerKind where
  | cell
  | arrayKind
  | mapKind
  deriving Repr, DecidableEq, Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `BackendKind`. -/
inductive BackendKind where
  | raw
  | fullScan
  | oram
  deriving Repr, DecidableEq, Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `StateObject`. -/
structure StateObject where
  id : Nat
  name : String
  kind : ContainerKind
  backend : BackendKind
  oramScheme : String
  valueType : Ty
  keyType : Option Ty
  capacity : Option Nat
  confidential : Bool
  deriving Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `UnaryOp`. -/
inductive UnaryOp where
  | not
  | neg
  deriving Repr, DecidableEq, Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `BinaryOp`. -/
inductive BinaryOp where
  | add | sub | mul | div | mod
  | bitAnd | bitOr | bitXor
  | eq | neq | lt | lte | gt | gte
  | logicAnd | logicOr
  deriving Repr, DecidableEq, Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `Expr`. -/
inductive Expr where
  | literal (v : Value)
  | var (name : String)
  | unary (op : UnaryOp) (e : Expr)
  | binary (op : BinaryOp) (lhs : Expr) (rhs : Expr)
  | select (cond : Expr) (whenTrue : Expr) (whenFalse : Expr)
  | cellGet (objectId : Nat)
  | arrayGet (objectId : Nat) (index : Expr)
  | mapGet (objectId : Nat) (key : Expr)
  | structField (base : Expr) (field : String)
  | arrayIndex (base : Expr) (index : Expr)
  | keccak256 (parts : List Expr)
  deriving Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `Statement`. -/
inductive Statement where
  | declare (name : String) (ty : Ty) (value : Expr)
  | assign (name : String) (value : Expr)
  | require (cond : Expr)
  | abortIf (cond : Expr)
  | ifStmt (cond : Expr) (thenBody : List Statement) (elseBody : List Statement)
  | forLoop
      (loopId : String) (indexVar : String)
      (start_ : Expr) (end_ : Expr) (body : List Statement)
  | cellSet (objectId : Nat) (value : Expr) (predicate : Option Expr)
  | arraySet
      (objectId : Nat) (index : Expr) (value : Expr) (predicate : Option Expr)
  | mapPut
      (objectId : Nat) (key : Expr) (value : Expr) (predicate : Option Expr)
  | retStmt (value : Option Expr)
  deriving Inhabited

/-- Mirror of the `(name, ty)` payload of `CompiledFunction.params`. -/
structure Param where
  name : String
  ty : Ty
  deriving Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `CompiledFunction`.

The `confidentialProgram` / `confidentialSlotProgram` payload is omitted
here on purpose; that surface lives under `RuntimeKernelDslJson.lean` and
the WP4 IR mirror keeps the IR/kernel split visible.
-/
structure CompiledFunction where
  signature : String
  params : List Param
  returnType : Option Ty
  body : List Statement
  secretArgs : List Nat
  confidential : Bool
  deriving Inhabited

/-- Mirror of `crates/uo-core/src/ir.rs`'s `CompiledContract`. The
`manifest` field is intentionally elided here; the WP4 manifest-exactness
theorem will project against the existing manifest mirror. -/
structure CompiledContract where
  contract : String
  mode : ProgramMode
  sourceFile : String
  state : List StateObject
  functions : List CompiledFunction
  deriving Inhabited

/-- An object-store fragment used by the operational evaluator: a finite
mapping from object id to the object's current value. -/
abbrev ObjectStore := List (Nat × Value)

namespace ObjectStore

def lookup (store : ObjectStore) (objectId : Nat) : Option Value :=
  match store.find? (fun entry => entry.fst = objectId) with
  | some (_, value) => some value
  | none => none

def insert (store : ObjectStore) (objectId : Nat) (value : Value) : ObjectStore :=
  (objectId, value) :: store.filter (fun entry => entry.fst ≠ objectId)

end ObjectStore

/-! ## Value equality and hash placeholder

`Value.beq` is a structural Boolean equality used by the evaluator's
`mapGet` lookup. It is defined manually (rather than `deriving BEq`)
because `Value` is a nested-inductive over `List` and `String × Value`
pairs, and Lean 4.30's `deriving` for nested inductives sometimes
fails on this shape.

`Value.keccak256Mock` is a deterministic hash abstraction used only by
the Lean source/IR/kernel evaluators. It is deliberately not a model of
the Rust runtime's `tiny_keccak::Keccak::v256()` output. The W4.4
preservation theorem is therefore a preservation theorem for the shared
Lean abstraction; value-level agreement with the real runtime hash is a
separate refinement obligation. -/

mutual

partial def Value.beq : Value → Value → Bool
  | .bool a, .bool b => a == b
  | .uint a, .uint b => a == b
  | .bytes32 a, .bytes32 b => a == b
  | .address a, .address b => a == b
  | .structValue a, .structValue b => Value.beqStructFields a b
  | .array a, .array b => Value.beqList a b
  | .map a, .map b => Value.beqMapEntries a b
  | _, _ => false

partial def Value.beqList : List Value → List Value → Bool
  | [], [] => true
  | [], _ :: _ => false
  | _ :: _, [] => false
  | x :: xs, y :: ys => Value.beq x y && Value.beqList xs ys

partial def Value.beqStructFields :
    List (String × Value) → List (String × Value) → Bool
  | [], [] => true
  | [], _ :: _ => false
  | _ :: _, [] => false
  | (n1, v1) :: rest1, (n2, v2) :: rest2 =>
      n1 == n2 && Value.beq v1 v2 && Value.beqStructFields rest1 rest2

partial def Value.beqMapEntries :
    List (Value × Value) → List (Value × Value) → Bool
  | [], [] => true
  | [], _ :: _ => false
  | _ :: _, [] => false
  | (k1, v1) :: rest1, (k2, v2) :: rest2 =>
      Value.beq k1 k2 && Value.beq v1 v2 && Value.beqMapEntries rest1 rest2

end

instance : BEq Value where
  beq := Value.beq

/-- Look up a key in a `Value.map`'s entry list using `Value.beq`. -/
def Value.mapLookup (entries : List (Value × Value)) (key : Value) : Option Value :=
  match entries.find? (fun entry => Value.beq entry.fst key) with
  | some (_, value) => some value
  | none => none

/-- A deterministic Lean-side hash abstraction. The mock returns a 32-byte
zero vector regardless of input. This is *not* a cryptographic hash and is
not a value-level refinement of the runtime's real Keccak implementation. -/
def Value.keccak256Mock (_parts : List Value) : Value :=
  Value.bytes32 (List.replicate 32 0)

theorem Value.keccak256Mock_returns_zero_bytes (parts : List Value) :
    Value.keccak256Mock parts = Value.bytes32 (List.replicate 32 0) := rfl

end UOToolchain.IR
