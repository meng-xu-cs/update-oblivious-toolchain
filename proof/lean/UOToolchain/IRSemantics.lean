import UOToolchain.TraceModel
import UOToolchain.IRSyntax

/-!
# Semantics layer for the admitted Solidity subset

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
  publicState : List String
deriving Repr, DecidableEq

abbrev TraceSemantics := TraceConfig → Trace

def tracePublicProjection (cfg : TraceConfig) : TracePublicProjection :=
  { program := cfg.program
  , publicArgs := cfg.input.publicArgs
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
  publicState : ObjectStore
  deriving Inhabited

def operationalPublicProjection (cfg : OperationalConfig) : OperationalPublicProjection :=
  { contract := cfg.contract
  , entrypoint := cfg.entrypoint
  , publicArgs := cfg.publicArgs
  , publicState := cfg.publicState
  }

/-- Two operational configurations have the same public projection when
their contract, entrypoint, public arguments, and public store agree. -/
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
  deriving Repr, Inhabited

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

The W4.1 evaluator never panics; it always returns an outcome.
-/
structure Outcome where
  trace : Trace
  publicResult : Option Value
  oramAccessCounts : OramAccessCounts
  kernelSteps : List String
  status : EvalStatus

namespace Outcome

@[inline] def empty : Outcome :=
  { trace := Trace.empty
  , publicResult := none
  , oramAccessCounts := []
  , kernelSteps := []
  , status := EvalStatus.completed
  }

@[inline] def withGas (oc : Outcome) (gasUsed : Nat) : Outcome :=
  { oc with trace := { oc.trace with gasUsed := gasUsed } }

@[inline] def gasUsed (oc : Outcome) : Nat := oc.trace.gasUsed

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

def UnaryOp.eval (op : UnaryOp) (v : Value) : Option Value :=
  match op, v with
  | .not, .bool b => some (.bool (! b))
  | .neg, .uint _ => some v  -- the admitted subset only emits unsigned `neg`
                              -- for the boolean-mask compositional flow; the
                              -- runtime never observes Solidity-level
                              -- negation on `uint`, so we model `neg` as a
                              -- conservative no-op for now and tighten in
                              -- subsequent commits.
  | _, _ => none

def BinaryOp.eval (op : BinaryOp) (lhs rhs : Value) : Option Value :=
  match op, lhs, rhs with
  | .add, .uint a, .uint b => some (.uint (a + b))
  | .sub, .uint a, .uint b => some (.uint (a - b))
  | .mul, .uint a, .uint b => some (.uint (a * b))
  | .div, .uint a, .uint b => if b = 0 then none else some (.uint (a / b))
  | .mod, .uint a, .uint b => if b = 0 then none else some (.uint (a % b))
  | .bitAnd, .uint a, .uint b => some (.uint (a &&& b))
  | .bitOr, .uint a, .uint b => some (.uint (a ||| b))
  | .bitXor, .uint a, .uint b => some (.uint (a ^^^ b))
  | .lt, .uint a, .uint b => some (.bool (decide (a < b)))
  | .lte, .uint a, .uint b => some (.bool (decide (a ≤ b)))
  | .gt, .uint a, .uint b => some (.bool (decide (b < a)))
  | .gte, .uint a, .uint b => some (.bool (decide (b ≤ a)))
  | .eq, .uint a, .uint b => some (.bool (decide (a = b)))
  | .neq, .uint a, .uint b => some (.bool (decide (a ≠ b)))
  | .eq, .bool a, .bool b => some (.bool (decide (a = b)))
  | .neq, .bool a, .bool b => some (.bool (decide (a ≠ b)))
  | .logicAnd, .bool a, .bool b => some (.bool (a && b))
  | .logicOr, .bool a, .bool b => some (.bool (a || b))
  | _, _, _ => none

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
      match cfg.publicState.lookup objectId, cfg.secretState.lookup objectId with
      | some v, _ => .value v
      | none, some v => .value v
      | none, none => .status (.evalError s!"cellGet on unknown object {objectId}")
  | .arrayGet objectId indexExpr =>
      match evalExpr cfg env indexExpr with
      | .status s => .status s
      | .value indexVal =>
          match indexVal with
          | .uint idx =>
              -- Look up the object's array value in either the public or
              -- secret store, then index into the underlying `Value.array`.
              let arrayVal? : Option Value :=
                match cfg.publicState.lookup objectId with
                | some v => some v
                | none => cfg.secretState.lookup objectId
              match arrayVal? with
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
          -- Look up the object's `Value.map` in either store, then
          -- search its entries by key using `Value.beq`.
          let mapVal? : Option Value :=
            match cfg.publicState.lookup objectId with
            | some v => some v
            | none => cfg.secretState.lookup objectId
          match mapVal? with
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
      -- `evalExprList`; the W4.1 evaluator only uses the resulting list
      -- shape (every element evaluated to a value), not the actual hash
      -- bits. The W4.4 preservation theorem holds because both IR and
      -- kernel evaluators use the same `Value.keccak256Mock`.
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

/-! ## Store-update helpers

`cellSet` / `arraySet` / `mapPut` use these helpers to perform the
predicate-driven masked-store update. The masked semantics says: the
runtime always performs a write (so the access pattern is public); the
data written is `if pred then newValue else currentValue`. For the
W4.1 evaluator's value-flow tracking, this is equivalent to "write
when pred is true (or absent), leave unchanged otherwise."

The store choice (public vs secret) is determined by the object's
`StateObject.confidential` flag, looked up in `cfg.contract.state`. If
the object has no entry there (a malformed program), the evaluator
defaults to the public store, which the W4.3 admission would already
have rejected. -/

/-- True if the object is declared as `confidential` in the contract's
state list. Defaults to `false` (public) for unknown objects. -/
def OperationalConfig.objectIsConfidential
    (cfg : OperationalConfig) (objectId : Nat) : Bool :=
  match cfg.contract.state.find? (fun so => so.id = objectId) with
  | some so => so.confidential
  | none => false

/-- Update the object's value in the appropriate store (public or secret
based on confidentiality). -/
def OperationalConfig.writeObject
    (cfg : OperationalConfig) (objectId : Nat) (value : Value) :
    OperationalConfig :=
  if cfg.objectIsConfidential objectId then
    { cfg with secretState := cfg.secretState.insert objectId value }
  else
    { cfg with publicState := cfg.publicState.insert objectId value }

/-- Read the object's value from the appropriate store. Public store
takes precedence; if not found, fall back to the secret store. -/
def OperationalConfig.readObject
    (cfg : OperationalConfig) (objectId : Nat) : Option Value :=
  match cfg.publicState.lookup objectId with
  | some v => some v
  | none => cfg.secretState.lookup objectId

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
              (cfg.writeObject objectId newVal, env, oc')
          | some predExpr =>
              match evalExpr cfg env predExpr with
              | .status s => (cfg, env, { oc with status := s })
              | .value (.bool true) =>
                  (cfg.writeObject objectId newVal, env, oc')
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
                            (cfg.writeObject objectId updated, env, oc')
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
                      (cfg.writeObject objectId updated, env, oc')
                  | some _ =>
                      let msg := s!"mapPut on non-map object {objectId}"
                      (cfg, env, { oc with status := .evalError msg })
                  | none =>
                      -- New map: start a fresh entries list.
                      let updated := Value.map [(keyVal, newVal)]
                      (cfg.writeObject objectId updated, env, oc')
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
walks the body, and returns the resulting `Outcome`. The final
`OperationalConfig` (with all store updates applied) and `LocalEnv`
are discarded; downstream paper-facing theorems care only about the
outcome's public projection / kernel-step trace / public result. -/
def evalContract (cfg : OperationalConfig) : Outcome :=
  match cfg.entrypointFn? with
  | none =>
      { Outcome.empty with status := .evalError s!"unknown entrypoint {cfg.entrypoint}" }
  | some fn =>
      match cfg.initialEnv fn with
      | none =>
          { Outcome.empty with status := .evalError "argument arity mismatch" }
      | some env =>
          let (_cfg', _env', outcome) := evalBody cfg env Outcome.empty fn.body
          outcome

end IR

end UOToolchain
