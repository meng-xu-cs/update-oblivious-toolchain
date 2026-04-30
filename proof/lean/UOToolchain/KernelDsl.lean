import UOToolchain.IRSyntax
import UOToolchain.IRSemantics
import UOToolchain.ConfidentialFragment

/-!
# Kernel DSL: typed mirror, operational semantics, and IR-to-kernel lowering

This module is the WP4 W4.4 (Session A) deliverable: a typed Lean
mirror of the kernel-DSL types in `crates/uo-core/src/confidential_kernel.rs`,
their operational semantics (sharing `IR.Outcome` with the W4.1
evaluator so the W4.4 preservation theorem can be a literal `Outcome`
equality), the IR→kernel lowering function, and the lowering-
succeeds-iff-precondition theorem.

The W4.4 *semantics-preservation* theorem (Session B) — that for any
`OperationalConfig`, `evalContract cfg = evalKernelProgram (lowerToKernel
fn) cfg` whenever the lowering succeeds — is left to a follow-up
commit. The lowerability iff theorem here is the foundation that
preservation will build on.

## Why a separate typed mirror?

The existing `RuntimeKernelDslJson.lean` mirror of the kernel DSL types
uses `Json` for the `op : Json` and `ty : Json` fields because it is
the JSON projection layer (parsing artifacts from Rust). Operational
semantics needs a typed surface, so this module re-mirrors the kernel
DSL types using `IR.UnaryOp` / `IR.BinaryOp` / `IR.Ty` from
`IRSyntax.lean`. A future commit can either unify the two mirrors via
a generator or via a structural equivalence theorem; for W4.4 the
typed mirror is the surface the semantics-preservation theorem will
refine against.

## Lowering

The Lean lowering function `lowerExpr` mirrors the Rust
`lower_confidential_kernel_expr` constructor-for-constructor. The
expression-level lowering succeeds *exactly* when the source
expression is `Expr.fragmentValid` (the W4.3 structural admission
predicate). The statement-level lowering adds the "no `ifStmt`, no
`forLoop`" condition captured by `Statement.kernelLowerable`.
-/

namespace UOToolchain.IR

/-! ## Typed kernel-DSL inductives

Mirror of `crates/uo-core/src/confidential_kernel.rs`'s
`ConfidentialKernelExpr` / `ConfidentialKernelPureExpr` /
`ConfidentialKernelStatement` / `ConfidentialKernelProgram`. -/

mutual

/-- Mirror of `ConfidentialKernelExpr`. The `select` constructor's arms
must be `KernelPureExpr`, matching the Rust constraint that select
arms inside the kernel DSL contain no storage access. -/
inductive KernelExpr where
  | literal (v : Value)
  | var (name : String)
  | unary (op : UnaryOp) (e : KernelExpr)
  | binary (op : BinaryOp) (lhs : KernelExpr) (rhs : KernelExpr)
  | select
      (cond : KernelExpr)
      (whenTrue : KernelPureExpr)
      (whenFalse : KernelPureExpr)
  | cellGet (objectId : Nat)
  | arrayGet (objectId : Nat) (index : KernelExpr)
  | mapGet (objectId : Nat) (key : KernelExpr)
  | structField (base : KernelExpr) (field : String)
  | arrayIndex (base : KernelExpr) (index : KernelExpr)
  | keccak256 (parts : List KernelExpr)

/-- Mirror of `ConfidentialKernelPureExpr`. Strict subset of `KernelExpr`
without storage access (`cellGet`, `arrayGet`, `mapGet`). -/
inductive KernelPureExpr where
  | literal (v : Value)
  | var (name : String)
  | unary (op : UnaryOp) (e : KernelPureExpr)
  | binary (op : BinaryOp) (lhs : KernelPureExpr) (rhs : KernelPureExpr)
  | select
      (cond : KernelPureExpr)
      (whenTrue : KernelPureExpr)
      (whenFalse : KernelPureExpr)
  | structField (base : KernelPureExpr) (field : String)
  | arrayIndex (base : KernelPureExpr) (index : KernelPureExpr)
  | keccak256 (parts : List KernelPureExpr)

end

/-- Mirror of `ConfidentialKernelStatement`. The kernel DSL is straight-
line: there is no `ifStmt` or `forLoop` constructor. -/
inductive KernelStatement where
  | declare (name : String) (ty : Ty) (value : KernelExpr)
  | assign (name : String) (value : KernelExpr)
  | require (cond : KernelExpr)
  | abortIf (cond : KernelExpr)
  | cellSet
      (objectId : Nat)
      (value : KernelExpr)
      (predicate : Option KernelExpr)
  | arraySet
      (objectId : Nat)
      (index : KernelExpr)
      (value : KernelExpr)
      (predicate : Option KernelExpr)
  | mapPut
      (objectId : Nat)
      (key : KernelExpr)
      (value : KernelExpr)
      (predicate : Option KernelExpr)
  | retStmt (value : Option KernelExpr)

/-- Mirror of `ConfidentialKernelProgram`. -/
structure KernelProgram where
  entrypointId : String
  params : List Param
  returnType : Option Ty
  secretArgs : List Nat
  body : List KernelStatement
  deriving Inhabited

/-! ## Operational semantics for the kernel DSL

The kernel-DSL evaluator returns the same `Outcome` type as the IR
evaluator and threads the same `OperationalConfig`, so that the W4.4
semantics-preservation theorem (Session B) can be stated as a literal
`(OperationalConfig × LocalEnv × Outcome)` equality. The evaluation
rules mirror the W4.1 `evalExpr` / `evalStatement` rules constructor-
for-constructor.
-/

mutual

/-- Big-step evaluator for `KernelExpr`. Mirrors `evalExpr` from
`IRSemantics.lean` constructor-for-constructor. Defined as `def`
(not `partial def`) so its equations reduce by `rfl`/`simp` for
the W4.4 preservation theorem. -/
def evalKernelExpr (cfg : OperationalConfig) (env : LocalEnv) :
    KernelExpr → ExprResult
  | .literal v => .value v
  | .var name =>
      match env.lookup name with
      | some v => .value v
      | none => .status (.evalError s!"undefined variable {name}")
  | .unary op e =>
      match evalKernelExpr cfg env e with
      | .value v =>
          match op.eval v with
          | some v' => .value v'
          | none => .status (.evalError "unary type mismatch")
      | r => r
  | .binary op lhs rhs =>
      match evalKernelExpr cfg env lhs with
      | .status s => .status s
      | .value lv =>
          match evalKernelExpr cfg env rhs with
          | .status s => .status s
          | .value rv =>
              match op.eval lv rv with
              | some v => .value v
              | none => .status (.evalError "binary type mismatch")
  | .select cond wt wf =>
      match evalKernelExpr cfg env cond with
      | .status s => .status s
      | .value (.bool true) => evalKernelPureExpr cfg env wt
      | .value (.bool false) => evalKernelPureExpr cfg env wf
      | .value _ => .status (.evalError "select condition not boolean")
  | .cellGet objectId =>
      match cfg.readObject objectId with
      | some v => .value v
      | none => .status (.evalError s!"cellGet on unknown object {objectId}")
  | .arrayGet objectId indexExpr =>
      match evalKernelExpr cfg env indexExpr with
      | .status s => .status s
      | .value indexVal =>
          match indexVal with
          | .uint idx =>
              match cfg.stateObjectById? objectId with
              | some object =>
                  match cfg.readObject objectId with
                  | some (.array values) =>
                      .value (Value.arrayGetD values idx object.valueType)
                  | some _ =>
                      .status (.evalError s!"arrayGet on non-array object {objectId}")
                  | none =>
                      if object.kind = .arrayKind then
                        .value (Value.zeroForType object.valueType)
                      else
                        .status (.evalError s!"arrayGet on non-array object {objectId}")
              | none =>
                  .status (.evalError s!"arrayGet on unknown object {objectId}")
          | _ => .status (.evalError "arrayGet index not uint")
  | .mapGet objectId keyExpr =>
      match evalKernelExpr cfg env keyExpr with
      | .status s => .status s
      | .value keyVal =>
          match cfg.stateObjectById? objectId with
          | some object =>
              match cfg.readObject objectId with
              | some (.map entries) =>
                  .value (Value.mapLookupD entries keyVal object.valueType)
              | some _ =>
                  .status (.evalError s!"mapGet on non-map object {objectId}")
              | none =>
                  if object.kind = .mapKind then
                    .value (Value.zeroForType object.valueType)
                  else
                    .status (.evalError s!"mapGet on non-map object {objectId}")
          | none =>
              .status (.evalError s!"mapGet on unknown object {objectId}")
  | .structField base field =>
      match evalKernelExpr cfg env base with
      | .status s => .status s
      | .value (.structValue fields) =>
          match Value.structField? fields field with
          | some value => .value value
          | none => .status (.evalError s!"unknown struct field {field}")
      | .value _ => .status (.evalError "structField base not struct")
  | .arrayIndex base indexExpr =>
      match evalKernelExpr cfg env base with
      | .status s => .status s
      | .value (.array values) =>
          match evalKernelExpr cfg env indexExpr with
          | .status s => .status s
          | .value (.uint idx) =>
              match Value.arrayIndex? values idx with
              | some value => .value value
              | none => .status (.evalError "arrayIndex out of bounds")
          | .value _ => .status (.evalError "arrayIndex index not uint")
      | .value _ => .status (.evalError "arrayIndex base not array")
  | .keccak256 parts =>
      match evalKernelExprList cfg env parts with
      | .error s => .status s
      | .ok vs => .value (Value.keccak256Mock vs)

/-- List companion for `evalKernelExpr` (`keccak256` case). -/
def evalKernelExprList (cfg : OperationalConfig) (env : LocalEnv) :
    List KernelExpr → Except EvalStatus (List Value)
  | [] => .ok []
  | p :: rest =>
      match evalKernelExpr cfg env p with
      | .status s => .error s
      | .value v =>
          match evalKernelExprList cfg env rest with
          | .ok vs => .ok (v :: vs)
          | .error s => .error s

/-- Big-step evaluator for `KernelPureExpr`. Pure expressions never
read storage. -/
def evalKernelPureExpr (cfg : OperationalConfig) (env : LocalEnv) :
    KernelPureExpr → ExprResult
  | .literal v => .value v
  | .var name =>
      match env.lookup name with
      | some v => .value v
      | none => .status (.evalError s!"undefined variable {name}")
  | .unary op e =>
      match evalKernelPureExpr cfg env e with
      | .value v =>
          match op.eval v with
          | some v' => .value v'
          | none => .status (.evalError "unary type mismatch")
      | r => r
  | .binary op lhs rhs =>
      match evalKernelPureExpr cfg env lhs with
      | .status s => .status s
      | .value lv =>
          match evalKernelPureExpr cfg env rhs with
          | .status s => .status s
          | .value rv =>
              match op.eval lv rv with
              | some v => .value v
              | none => .status (.evalError "binary type mismatch")
  | .select cond wt wf =>
      match evalKernelPureExpr cfg env cond with
      | .status s => .status s
      | .value (.bool true) => evalKernelPureExpr cfg env wt
      | .value (.bool false) => evalKernelPureExpr cfg env wf
      | .value _ => .status (.evalError "select condition not boolean")
  | .structField base field =>
      match evalKernelPureExpr cfg env base with
      | .status s => .status s
      | .value (.structValue fields) =>
          match Value.structField? fields field with
          | some value => .value value
          | none => .status (.evalError s!"unknown struct field {field}")
      | .value _ => .status (.evalError "structField base not struct")
  | .arrayIndex base indexExpr =>
      match evalKernelPureExpr cfg env base with
      | .status s => .status s
      | .value (.array values) =>
          match evalKernelPureExpr cfg env indexExpr with
          | .status s => .status s
          | .value (.uint idx) =>
              match Value.arrayIndex? values idx with
              | some value => .value value
              | none => .status (.evalError "arrayIndex out of bounds")
          | .value _ => .status (.evalError "arrayIndex index not uint")
      | .value _ => .status (.evalError "arrayIndex base not array")
  | .keccak256 parts =>
      match evalKernelPureExprList cfg env parts with
      | .error s => .status s
      | .ok vs => .value (Value.keccak256Mock vs)

/-- List companion for `evalKernelPureExpr` (`keccak256` case). -/
def evalKernelPureExprList (cfg : OperationalConfig) (env : LocalEnv) :
    List KernelPureExpr → Except EvalStatus (List Value)
  | [] => .ok []
  | p :: rest =>
      match evalKernelPureExpr cfg env p with
      | .status s => .error s
      | .value v =>
          match evalKernelPureExprList cfg env rest with
          | .ok vs => .ok (v :: vs)
          | .error s => .error s

end

mutual

/-- Big-step statement evaluator for the kernel DSL. Threads the
`OperationalConfig` so masked-store updates persist into subsequent
statements, mirroring the W4.1+++ IR statement evaluator. -/
def evalKernelStatement
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    KernelStatement → OperationalConfig × LocalEnv × Outcome
  | .declare name _ value =>
      match evalKernelExpr cfg env value with
      | .value v => (cfg, env.insert name v, oc)
      | .status s => (cfg, env, { oc with status := s })
  | .assign name value =>
      match evalKernelExpr cfg env value with
      | .value v => (cfg, env.insert name v, oc)
      | .status s => (cfg, env, { oc with status := s })
  | .require cond =>
      match evalKernelExpr cfg env cond with
      | .value (.bool true) => (cfg, env, oc)
      | .value (.bool false) => (cfg, env, { oc with status := .requireFailed })
      | .value _ => (cfg, env, { oc with status := .evalError "require not boolean" })
      | .status s => (cfg, env, { oc with status := s })
  | .abortIf cond =>
      match evalKernelExpr cfg env cond with
      | .value (.bool true) => (cfg, env, { oc with status := .abortedByUser })
      | .value (.bool false) => (cfg, env, oc)
      | .value _ => (cfg, env, { oc with status := .evalError "abortIf not boolean" })
      | .status s => (cfg, env, { oc with status := s })
  | .cellSet objectId value predicate =>
      match evalKernelExpr cfg env value with
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
              match evalKernelExpr cfg env predExpr with
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
      match evalKernelExpr cfg env index with
      | .status s => (cfg, env, { oc with status := s })
      | .value indexVal =>
          match evalKernelExpr cfg env value with
          | .status s => (cfg, env, { oc with status := s })
          | .value newVal =>
              let oc' := { oc with kernelSteps := oc.kernelSteps ++ ["ArraySet"] }
              let shouldWrite : Except EvalStatus Bool :=
                match predicate with
                | none => .ok true
                | some predExpr =>
                    match evalKernelExpr cfg env predExpr with
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
                          if values[idx]? = none then
                            (cfg, env, oc')
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
      match evalKernelExpr cfg env key with
      | .status s => (cfg, env, { oc with status := s })
      | .value keyVal =>
          match evalKernelExpr cfg env value with
          | .status s => (cfg, env, { oc with status := s })
          | .value newVal =>
              let oc' := { oc with kernelSteps := oc.kernelSteps ++ ["MapPut"] }
              let shouldWrite : Except EvalStatus Bool :=
                match predicate with
                | none => .ok true
                | some predExpr =>
                    match evalKernelExpr cfg env predExpr with
                    | .status s => .error s
                    | .value (.bool true) => .ok true
                    | .value (.bool false) => .ok false
                    | .value _ =>
                        .error (.evalError "mapPut predicate not boolean")
              match shouldWrite with
              | .error s => (cfg, env, { oc with status := s })
              | .ok false => (cfg, env, oc')
              | .ok true =>
                  match cfg.stateObjectById? objectId with
                  | some object =>
                      match cfg.readObject objectId with
                      | some (.map entries) =>
                          let result :=
                            Value.mapInsertBounded entries keyVal newVal object.capacity
                          if result.overflowed then
                            (cfg, env, { oc' with status := .capacityOverflow })
                          else
                            let updated := Value.map result.entries
                            match cfg.writeObject? objectId updated with
                            | some cfg' => (cfg', env, oc')
                            | none =>
                                let msg := s!"mapPut on unknown object {objectId}"
                                (cfg, env, { oc with status := .evalError msg })
                      | some _ =>
                          let msg := s!"mapPut on non-map object {objectId}"
                          (cfg, env, { oc with status := .evalError msg })
                      | none =>
                          if object.kind = .mapKind then
                            let result :=
                              Value.mapInsertBounded [] keyVal newVal object.capacity
                            if result.overflowed then
                              (cfg, env, { oc' with status := .capacityOverflow })
                            else
                              let updated := Value.map result.entries
                              match cfg.writeObject? objectId updated with
                              | some cfg' => (cfg', env, oc')
                              | none =>
                                  let msg := s!"mapPut on unknown object {objectId}"
                                  (cfg, env, { oc with status := .evalError msg })
                          else
                            let msg := s!"mapPut on non-map object {objectId}"
                            (cfg, env, { oc with status := .evalError msg })
                  | none =>
                      let msg := s!"mapPut on unknown object {objectId}"
                      (cfg, env, { oc with status := .evalError msg })
  | .retStmt none => (cfg, env, oc)
  | .retStmt (some value) =>
      match evalKernelExpr cfg env value with
      | .value v => (cfg, env, { oc with publicResult := some v })
      | .status s => (cfg, env, { oc with status := s })

def evalKernelBody
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    List KernelStatement → OperationalConfig × LocalEnv × Outcome
  | [] => (cfg, env, oc)
  | stmt :: rest =>
      let (cfg', env', oc') := evalKernelStatement cfg env oc stmt
      match oc'.status with
      | .completed =>
          if oc'.publicResult.isSome then (cfg', env', oc')
          else evalKernelBody cfg' env' oc' rest
      | _ => (cfg', env', oc')

end

/-- Build the initial environment for a `KernelProgram` exactly the way
`OperationalConfig.initialEnv` does for `CompiledFunction`. -/
def KernelProgram.initialEnv (kp : KernelProgram)
    (declaredArgs : List Value) : Option LocalEnv :=
  if declaredArgs.length = kp.params.length then
    some <| (kp.params.zip declaredArgs).foldl
      (fun env entry => LocalEnv.insert env entry.fst.name entry.snd) ([] : LocalEnv)
  else
    none

/-- Big-step program evaluator: bind the entrypoint arguments and walk
the body using `evalKernelBody`, recording the final public store in the
returned outcome. -/
def evalKernelProgram (kp : KernelProgram) (cfg : OperationalConfig) : Outcome :=
  match kp.initialEnv cfg.declaredArgs with
  | none =>
      let outcome :=
        { Outcome.empty with
          status := .evalError "argument arity mismatch" }
      outcome.withPublicStateTransition
        (outcome.toPublicStateTransition cfg.publicState cfg.publicState)
  | some env =>
      let (cfg', _env', outcome) := evalKernelBody cfg env Outcome.empty kp.body
      outcome.withPublicStateTransition
        (outcome.toPublicStateTransition cfg.publicState cfg'.publicState)

/-! ### W4.5: Static expected kernel-step schedule

`KernelStatement.expectedStep` returns the kernel-step tag a statement
would emit on successful execution: `"CellSet"` / `"ArraySet"` /
`"MapPut"` for the three masked-store statements, empty otherwise.

`KernelProgram.expectedKernelSteps` flattens this over the program's
body, giving the static-expected kernel-step schedule that every
fully-completed run must produce. The runtime-vs-static equivalence
theorem (`evalKernelProgram_kernelSteps_eq_expected_on_full_completion`)
proves the two coincide whenever the program runs to completion without
early `retStmt (some _)` or any error. -/

/-- Step tag a kernel statement emits on successful execution. -/
def KernelStatement.expectedStep : KernelStatement → List String
  | .cellSet _ _ _ => ["CellSet"]
  | .arraySet _ _ _ _ => ["ArraySet"]
  | .mapPut _ _ _ _ => ["MapPut"]
  | _ => []

/-- Static expected kernel-step schedule: the body's tags concatenated
in order. -/
def KernelProgram.expectedKernelSteps (kp : KernelProgram) : List String :=
  kp.body.flatMap KernelStatement.expectedStep

/-- Total number of static-expected kernel steps (`length` of the
schedule). The manifest's `kernel_steps` field has the same length. -/
def KernelProgram.expectedKernelStepCount (kp : KernelProgram) : Nat :=
  kp.expectedKernelSteps.length

/-- Static expected per-object kernel-step write count. Walks the body
counting `cellSet` / `arraySet` / `mapPut` statements per object id;
the result is the static upper-bound on per-object write activity. -/
def KernelStatement.objectWriteId : KernelStatement → Option Nat
  | .cellSet objectId _ _ => some objectId
  | .arraySet objectId _ _ _ => some objectId
  | .mapPut objectId _ _ _ => some objectId
  | _ => none

def KernelProgram.expectedObjectWriteIds (kp : KernelProgram) : List Nat :=
  kp.body.filterMap KernelStatement.objectWriteId

/-! ## IR-to-kernel lowering

Mirror of `lower_confidential_kernel_expr` /
`lower_confidential_kernel_pure_expr` /
`lower_confidential_kernel_statement` /
`lower_confidential_kernel_statements` from
`crates/uo-core/src/confidential_kernel.rs`. The lowering is total on
its precondition: it succeeds exactly on inputs in the kernel-
lowerable subset. The precondition theorems below pin this iff. -/

/-- Lowering errors. Mirror of `ConfidentialKernelLoweringError`'s
expression / statement variants. -/
inductive KernelLoweringError where
  | confidentialControlFlow (statement : String)
  | selectArmOutsideBranchlessFragment
  | confidentialStructField
  | confidentialArrayIndex
  | nonFinalReturn (index : Nat)
  deriving Repr, DecidableEq, Inhabited

mutual

/-- Lower a general expression to `KernelExpr`. Mirrors the Rust
`lower_confidential_kernel_expr` constructor-for-constructor. -/
def lowerExpr : Expr → Except KernelLoweringError KernelExpr
  | .literal v => .ok (.literal v)
  | .var name => .ok (.var name)
  | .unary op e => do
      let ke ← lowerExpr e
      .ok (.unary op ke)
  | .binary op lhs rhs => do
      let kl ← lowerExpr lhs
      let kr ← lowerExpr rhs
      .ok (.binary op kl kr)
  | .select cond wt wf => do
      let kc ← lowerExpr cond
      let kt ← lowerPureExpr wt
      let kf ← lowerPureExpr wf
      .ok (.select kc kt kf)
  | .cellGet id => .ok (.cellGet id)
  | .arrayGet id index => do
      let ki ← lowerExpr index
      .ok (.arrayGet id ki)
  | .mapGet id key => do
      let kk ← lowerExpr key
      .ok (.mapGet id kk)
  | .structField base field => do
      let kb ← lowerExpr base
      .ok (.structField kb field)
  | .arrayIndex base index => do
      let kb ← lowerExpr base
      let ki ← lowerExpr index
      .ok (.arrayIndex kb ki)
  | .keccak256 parts => do
      let kparts ← lowerExprList parts
      .ok (.keccak256 kparts)

/-- List companion for `lowerExpr`: lower every element of an
expression list. Used for the `keccak256` constructor. -/
def lowerExprList :
    List Expr → Except KernelLoweringError (List KernelExpr)
  | [] => .ok []
  | e :: rest => do
      let ke ← lowerExpr e
      let krest ← lowerExprList rest
      .ok (ke :: krest)

/-- Lower a pure expression to `KernelPureExpr`. Mirrors the Rust
`lower_confidential_kernel_pure_expr`. -/
def lowerPureExpr : Expr → Except KernelLoweringError KernelPureExpr
  | .literal v => .ok (.literal v)
  | .var name => .ok (.var name)
  | .unary op e => do
      let ke ← lowerPureExpr e
      .ok (.unary op ke)
  | .binary op lhs rhs => do
      let kl ← lowerPureExpr lhs
      let kr ← lowerPureExpr rhs
      .ok (.binary op kl kr)
  | .select cond wt wf => do
      let kc ← lowerPureExpr cond
      let kt ← lowerPureExpr wt
      let kf ← lowerPureExpr wf
      .ok (.select kc kt kf)
  | .cellGet _ => .error .selectArmOutsideBranchlessFragment
  | .arrayGet _ _ => .error .selectArmOutsideBranchlessFragment
  | .mapGet _ _ => .error .selectArmOutsideBranchlessFragment
  | .structField base field => do
      let kb ← lowerPureExpr base
      .ok (.structField kb field)
  | .arrayIndex base index => do
      let kb ← lowerPureExpr base
      let ki ← lowerPureExpr index
      .ok (.arrayIndex kb ki)
  | .keccak256 parts => do
      let kparts ← lowerPureExprList parts
      .ok (.keccak256 kparts)

/-- List companion for `lowerPureExpr`. -/
def lowerPureExprList :
    List Expr → Except KernelLoweringError (List KernelPureExpr)
  | [] => .ok []
  | e :: rest => do
      let ke ← lowerPureExpr e
      let krest ← lowerPureExprList rest
      .ok (ke :: krest)

end

/-- Lower a statement to `KernelStatement`. Mirrors the Rust
`lower_confidential_kernel_statement`. The kernel DSL is straight-
line, so `ifStmt` / `forLoop` are rejected. -/
def lowerStatement : Statement → Except KernelLoweringError KernelStatement
  | .declare name ty value => do
      let kv ← lowerExpr value
      .ok (.declare name ty kv)
  | .assign name value => do
      let kv ← lowerExpr value
      .ok (.assign name kv)
  | .require cond => do
      let kc ← lowerExpr cond
      .ok (.require kc)
  | .abortIf cond => do
      let kc ← lowerExpr cond
      .ok (.abortIf kc)
  | .ifStmt _ _ _ => .error (.confidentialControlFlow "if")
  | .forLoop _ _ _ _ _ => .error (.confidentialControlFlow "for")
  | .cellSet id value pred => do
      let kv ← lowerExpr value
      let kp ←
        match pred with
        | none => .ok none
        | some p => do
            let kp ← lowerExpr p
            .ok (some kp)
      .ok (.cellSet id kv kp)
  | .arraySet id index value pred => do
      let ki ← lowerExpr index
      let kv ← lowerExpr value
      let kp ←
        match pred with
        | none => .ok none
        | some p => do
            let kp ← lowerExpr p
            .ok (some kp)
      .ok (.arraySet id ki kv kp)
  | .mapPut id key value pred => do
      let kk ← lowerExpr key
      let kv ← lowerExpr value
      let kp ←
        match pred with
        | none => .ok none
        | some p => do
            let kp ← lowerExpr p
            .ok (some kp)
      .ok (.mapPut id kk kv kp)
  | .retStmt none => .ok (.retStmt none)
  | .retStmt (some value) => do
      let kv ← lowerExpr value
      .ok (.retStmt (some kv))

/-- Decide whether a statement is a `retStmt`. Used by both
`lowerStatementsAux` and `kernelLowerableScheduleAux` to enforce the
"no statement after `Return`" public-schedule rule. Pulled out as a
top-level helper so that subsequent rewrites can reduce it
syntactically without `let`-binding obstacles. -/
def Statement.isReturn : Statement → Bool
  | .retStmt _ => true
  | _ => false

/-- Lower a list of statements to a list of `KernelStatement`s,
enforcing the "no statement after `Return`" public-schedule rule from
the Rust `lower_confidential_kernel_statements`. -/
def lowerStatementsAux :
    List Statement → Nat → Bool → Except KernelLoweringError (List KernelStatement)
  | [], _, _ => .ok []
  | stmt :: rest, index, sawReturn =>
      if sawReturn then
        .error (.nonFinalReturn index)
      else do
        let ks ← lowerStatement stmt
        let krest ← lowerStatementsAux rest (index + 1) stmt.isReturn
        .ok (ks :: krest)

def lowerStatements
    (stmts : List Statement) :
    Except KernelLoweringError (List KernelStatement) :=
  lowerStatementsAux stmts 0 false

/-- Lower a `CompiledFunction` to a `KernelProgram`. Mirrors
`CompiledFunction::confidential_kernel_program` in the Rust impl. -/
def lowerCompiledFunction
    (fn : CompiledFunction) : Except KernelLoweringError KernelProgram := do
  let body ← lowerStatements fn.body
  .ok
    { entrypointId := fn.signature
    , params := fn.params
    , returnType := fn.returnType
    , secretArgs := fn.secretArgs
    , body := body
    }

/-! ## Lowering succeeds-iff-precondition

`Expr.fragmentValid` from W4.3 is exactly the precondition for
`lowerExpr` to succeed. For statements the lowering precondition is
captured by `Statement.kernelLowerable` (which adds the "no `ifStmt`,
no `forLoop`" condition on top of `Statement.fragmentValid`).

The function-level lowering also adds the "no statement after
`Return`" rule, captured by `kernelLowerableSchedule`.
-/

/-- A statement is *kernel-lowerable* when all its sub-expressions are
fragment-valid and it is not `ifStmt` / `forLoop`. -/
def Statement.kernelLowerable : Statement → Bool
  | .declare _ _ value => Expr.fragmentValid value
  | .assign _ value => Expr.fragmentValid value
  | .require cond => Expr.fragmentValid cond
  | .abortIf cond => Expr.fragmentValid cond
  | .ifStmt _ _ _ => false
  | .forLoop _ _ _ _ _ => false
  | .cellSet _ value pred =>
      Expr.fragmentValid value
        && (match pred with | none => true | some p => Expr.fragmentValid p)
  | .arraySet _ index value pred =>
      Expr.fragmentValid index && Expr.fragmentValid value
        && (match pred with | none => true | some p => Expr.fragmentValid p)
  | .mapPut _ key value pred =>
      Expr.fragmentValid key && Expr.fragmentValid value
        && (match pred with | none => true | some p => Expr.fragmentValid p)
  | .retStmt none => true
  | .retStmt (some value) => Expr.fragmentValid value

/-- A statement list is *kernel-lowerable as a schedule* when every
element is `kernelLowerable` and no element appears after a
`retStmt`. Mirrors the Rust `lower_confidential_kernel_statements`
loop's "no statement after return" rule. -/
def Statement.kernelLowerableScheduleAux : List Statement → Bool → Bool
  | [], _ => true
  | stmt :: rest, sawReturn =>
      if sawReturn then false
      else
        Statement.kernelLowerable stmt
          && Statement.kernelLowerableScheduleAux rest stmt.isReturn

def Statement.kernelLowerableSchedule (stmts : List Statement) : Bool :=
  Statement.kernelLowerableScheduleAux stmts false

/-- A function is *kernel-lowerable* when its body is. -/
def CompiledFunction.kernelLowerable (fn : CompiledFunction) : Bool :=
  Statement.kernelLowerableSchedule fn.body

/-! ### Lowering succeeds-when-precondition theorems (forward direction)

`branchlessPureExpr e = true → lowerPureExpr e` succeeds; analogously
for `Expr.fragmentValid` ↔ `lowerExpr`, `Statement.kernelLowerable` ↔
`lowerStatement`, and `Statement.kernelLowerableSchedule` ↔
`lowerStatements`. These are the *forward* directions of the iff
characterization. They are what the W4.4 semantics-preservation
theorem (Session B-2) needs as preconditions. The reverse directions
("the lowering succeeds → the precondition predicate is true") are a
useful corollary for W4.6 (artifact-checker demotion) but are not
strictly required by W4.4; they are deferred. -/

mutual

/-- `branchlessPureExpr` implies `lowerPureExpr` succeeds. Forward
direction of the lowering iff. Mutually recursive with the list
companion. -/
theorem branchlessPureExpr_implies_lowerPureExpr_ok :
    ∀ e : Expr, branchlessPureExpr e = true →
      ∃ ke, lowerPureExpr e = .ok ke
  | .literal v, _ => ⟨.literal v, rfl⟩
  | .var name, _ => ⟨.var name, rfl⟩
  | .unary op e, h => by
      simp only [branchlessPureExpr] at h
      rcases branchlessPureExpr_implies_lowerPureExpr_ok e h with ⟨ke, hke⟩
      exact ⟨.unary op ke, by unfold lowerPureExpr; rw [hke]; rfl⟩
  | .binary op lhs rhs, h => by
      simp only [branchlessPureExpr, Bool.and_eq_true] at h
      rcases branchlessPureExpr_implies_lowerPureExpr_ok lhs h.1 with ⟨kl, hkl⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok rhs h.2 with ⟨kr, hkr⟩
      exact ⟨.binary op kl kr, by unfold lowerPureExpr; rw [hkl, hkr]; rfl⟩
  | .select cond wt wf, h => by
      simp only [branchlessPureExpr, Bool.and_eq_true] at h
      rcases h with ⟨⟨hC, hT⟩, hF⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok cond hC with ⟨kc, hkc⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok wt hT with ⟨kt, hkt⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok wf hF with ⟨kf, hkf⟩
      exact ⟨.select kc kt kf, by unfold lowerPureExpr; rw [hkc, hkt, hkf]; rfl⟩
  | .cellGet _, h => by simp [branchlessPureExpr] at h
  | .arrayGet _ _, h => by simp [branchlessPureExpr] at h
  | .mapGet _ _, h => by simp [branchlessPureExpr] at h
  | .structField base field, h => by
      simp only [branchlessPureExpr] at h
      rcases branchlessPureExpr_implies_lowerPureExpr_ok base h with ⟨kb, hkb⟩
      exact ⟨.structField kb field, by unfold lowerPureExpr; rw [hkb]; rfl⟩
  | .arrayIndex base index, h => by
      simp only [branchlessPureExpr, Bool.and_eq_true] at h
      rcases branchlessPureExpr_implies_lowerPureExpr_ok base h.1 with ⟨kb, hkb⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok index h.2 with ⟨ki, hki⟩
      exact ⟨.arrayIndex kb ki, by unfold lowerPureExpr; rw [hkb, hki]; rfl⟩
  | .keccak256 parts, h => by
      simp only [branchlessPureExpr] at h
      rcases branchlessPureExprList_implies_lowerPureExprList_ok parts h
        with ⟨kparts, hkparts⟩
      exact ⟨.keccak256 kparts, by unfold lowerPureExpr; rw [hkparts]; rfl⟩

theorem branchlessPureExprList_implies_lowerPureExprList_ok :
    ∀ es : List Expr, branchlessPureExprList es = true →
      ∃ kes, lowerPureExprList es = .ok kes
  | [], _ => ⟨[], rfl⟩
  | e :: rest, h => by
      simp only [branchlessPureExprList, Bool.and_eq_true] at h
      rcases branchlessPureExpr_implies_lowerPureExpr_ok e h.1 with ⟨ke, hke⟩
      rcases branchlessPureExprList_implies_lowerPureExprList_ok rest h.2
        with ⟨krest, hkrest⟩
      exact ⟨ke :: krest, by unfold lowerPureExprList; rw [hke, hkrest]; rfl⟩

end

mutual

/-- `Expr.fragmentValid` implies `lowerExpr` succeeds. Forward
direction of the lowering iff. Mutually recursive with the list
companion. The `Expr.select` case uses
`branchlessPureExpr_implies_lowerPureExpr_ok` for its arms. -/
theorem fragmentValid_implies_lowerExpr_ok :
    ∀ e : Expr, Expr.fragmentValid e = true →
      ∃ ke, lowerExpr e = .ok ke
  | .literal v, _ => ⟨.literal v, rfl⟩
  | .var name, _ => ⟨.var name, rfl⟩
  | .unary op e, h => by
      simp only [Expr.fragmentValid] at h
      rcases fragmentValid_implies_lowerExpr_ok e h with ⟨ke, hke⟩
      exact ⟨.unary op ke, by unfold lowerExpr; rw [hke]; rfl⟩
  | .binary op lhs rhs, h => by
      simp only [Expr.fragmentValid, Bool.and_eq_true] at h
      rcases fragmentValid_implies_lowerExpr_ok lhs h.1 with ⟨kl, hkl⟩
      rcases fragmentValid_implies_lowerExpr_ok rhs h.2 with ⟨kr, hkr⟩
      exact ⟨.binary op kl kr, by unfold lowerExpr; rw [hkl, hkr]; rfl⟩
  | .select cond wt wf, h => by
      simp only [Expr.fragmentValid, Bool.and_eq_true] at h
      rcases h with ⟨⟨⟨⟨hC, _⟩, _⟩, hBPwt⟩, hBPwf⟩
      rcases fragmentValid_implies_lowerExpr_ok cond hC with ⟨kc, hkc⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok wt hBPwt with ⟨kt, hkt⟩
      rcases branchlessPureExpr_implies_lowerPureExpr_ok wf hBPwf with ⟨kf, hkf⟩
      exact ⟨.select kc kt kf, by unfold lowerExpr; rw [hkc, hkt, hkf]; rfl⟩
  | .cellGet id, _ => ⟨.cellGet id, rfl⟩
  | .arrayGet id index, h => by
      simp only [Expr.fragmentValid] at h
      rcases fragmentValid_implies_lowerExpr_ok index h with ⟨ki, hki⟩
      exact ⟨.arrayGet id ki, by unfold lowerExpr; rw [hki]; rfl⟩
  | .mapGet id key, h => by
      simp only [Expr.fragmentValid] at h
      rcases fragmentValid_implies_lowerExpr_ok key h with ⟨kk, hkk⟩
      exact ⟨.mapGet id kk, by unfold lowerExpr; rw [hkk]; rfl⟩
  | .structField base field, h => by
      simp only [Expr.fragmentValid] at h
      rcases fragmentValid_implies_lowerExpr_ok base h with ⟨kb, hkb⟩
      exact ⟨.structField kb field, by unfold lowerExpr; rw [hkb]; rfl⟩
  | .arrayIndex base index, h => by
      simp only [Expr.fragmentValid, Bool.and_eq_true] at h
      rcases fragmentValid_implies_lowerExpr_ok base h.1 with ⟨kb, hkb⟩
      rcases fragmentValid_implies_lowerExpr_ok index h.2 with ⟨ki, hki⟩
      exact ⟨.arrayIndex kb ki, by unfold lowerExpr; rw [hkb, hki]; rfl⟩
  | .keccak256 parts, h => by
      simp only [Expr.fragmentValid] at h
      rcases fragmentValidList_implies_lowerExprList_ok parts h
        with ⟨kparts, hkparts⟩
      exact ⟨.keccak256 kparts, by unfold lowerExpr; rw [hkparts]; rfl⟩

theorem fragmentValidList_implies_lowerExprList_ok :
    ∀ es : List Expr, Expr.fragmentValidList es = true →
      ∃ kes, lowerExprList es = .ok kes
  | [], _ => ⟨[], rfl⟩
  | e :: rest, h => by
      simp only [Expr.fragmentValidList, Bool.and_eq_true] at h
      rcases fragmentValid_implies_lowerExpr_ok e h.1 with ⟨ke, hke⟩
      rcases fragmentValidList_implies_lowerExprList_ok rest h.2 with ⟨krest, hkrest⟩
      exact ⟨ke :: krest, by unfold lowerExprList; rw [hke, hkrest]; rfl⟩

end

/-- `Statement.kernelLowerable` implies `lowerStatement` succeeds.
Forward direction of the statement-level lowering iff. -/
theorem kernelLowerable_implies_lowerStatement_ok :
    ∀ s : Statement, Statement.kernelLowerable s = true →
      ∃ ks, lowerStatement s = .ok ks
  | .declare name ty value, h => by
      simp only [Statement.kernelLowerable] at h
      rcases fragmentValid_implies_lowerExpr_ok value h with ⟨kv, hkv⟩
      exact ⟨.declare name ty kv, by unfold lowerStatement; simp [hkv]; rfl⟩
  | .assign name value, h => by
      simp only [Statement.kernelLowerable] at h
      rcases fragmentValid_implies_lowerExpr_ok value h with ⟨kv, hkv⟩
      exact ⟨.assign name kv, by unfold lowerStatement; simp [hkv]; rfl⟩
  | .require cond, h => by
      simp only [Statement.kernelLowerable] at h
      rcases fragmentValid_implies_lowerExpr_ok cond h with ⟨kc, hkc⟩
      exact ⟨.require kc, by unfold lowerStatement; simp [hkc]; rfl⟩
  | .abortIf cond, h => by
      simp only [Statement.kernelLowerable] at h
      rcases fragmentValid_implies_lowerExpr_ok cond h with ⟨kc, hkc⟩
      exact ⟨.abortIf kc, by unfold lowerStatement; simp [hkc]; rfl⟩
  | .ifStmt _ _ _, h => by simp [Statement.kernelLowerable] at h
  | .forLoop _ _ _ _ _, h => by simp [Statement.kernelLowerable] at h
  | .cellSet id value pred, h => by
      simp only [Statement.kernelLowerable, Bool.and_eq_true] at h
      rcases fragmentValid_implies_lowerExpr_ok value h.1 with ⟨kv, hkv⟩
      cases pred with
      | none =>
          exact ⟨.cellSet id kv none, by unfold lowerStatement; simp [hkv]; rfl⟩
      | some p =>
          have hp : Expr.fragmentValid p = true := by
            have := h.2
            simp at this; exact this
          rcases fragmentValid_implies_lowerExpr_ok p hp with ⟨kp, hkp⟩
          exact ⟨.cellSet id kv (some kp), by unfold lowerStatement; simp [hkv, hkp]; rfl⟩
  | .arraySet id index value pred, h => by
      simp only [Statement.kernelLowerable, Bool.and_eq_true] at h
      rcases fragmentValid_implies_lowerExpr_ok index h.1.1 with ⟨ki, hki⟩
      rcases fragmentValid_implies_lowerExpr_ok value h.1.2 with ⟨kv, hkv⟩
      cases pred with
      | none =>
          exact ⟨.arraySet id ki kv none, by unfold lowerStatement; simp [hki, hkv]; rfl⟩
      | some p =>
          have hp : Expr.fragmentValid p = true := by
            have := h.2
            simp at this; exact this
          rcases fragmentValid_implies_lowerExpr_ok p hp with ⟨kp, hkp⟩
          exact ⟨.arraySet id ki kv (some kp),
            by unfold lowerStatement; simp [hki, hkv, hkp]; rfl⟩
  | .mapPut id key value pred, h => by
      simp only [Statement.kernelLowerable, Bool.and_eq_true] at h
      rcases fragmentValid_implies_lowerExpr_ok key h.1.1 with ⟨kk, hkk⟩
      rcases fragmentValid_implies_lowerExpr_ok value h.1.2 with ⟨kv, hkv⟩
      cases pred with
      | none =>
          exact ⟨.mapPut id kk kv none, by unfold lowerStatement; simp [hkk, hkv]; rfl⟩
      | some p =>
          have hp : Expr.fragmentValid p = true := by
            have := h.2
            simp at this; exact this
          rcases fragmentValid_implies_lowerExpr_ok p hp with ⟨kp, hkp⟩
          exact ⟨.mapPut id kk kv (some kp),
            by unfold lowerStatement; simp [hkk, hkv, hkp]; rfl⟩
  | .retStmt none, _ => ⟨.retStmt none, rfl⟩
  | .retStmt (some value), h => by
      simp only [Statement.kernelLowerable] at h
      rcases fragmentValid_implies_lowerExpr_ok value h with ⟨kv, hkv⟩
      exact ⟨.retStmt (some kv), by unfold lowerStatement; simp [hkv]; rfl⟩

/-- Schedule-level forward theorem. Two cases for the cons:
either `stmt` is not a return (then `rest` is schedule-lowerable
with `sawReturn=false`), or `stmt` is a return (then `rest` must be
empty for the schedule predicate to hold). -/
theorem kernelLowerableScheduleAux_implies_lowerStatementsAux_ok :
    ∀ (stmts : List Statement) (index : Nat),
      Statement.kernelLowerableScheduleAux stmts false = true →
      ∃ ks, lowerStatementsAux stmts index false = .ok ks
  | [], _, _ => ⟨[], rfl⟩
  | stmt :: rest, index, h => by
      have hSplit : Statement.kernelLowerable stmt = true ∧
          Statement.kernelLowerableScheduleAux rest stmt.isReturn = true := by
        have := h
        simp [Statement.kernelLowerableScheduleAux] at this
        exact this
      obtain ⟨hStmt, hRest⟩ := hSplit
      rcases kernelLowerable_implies_lowerStatement_ok stmt hStmt with ⟨ks, hks⟩
      cases hIR : stmt.isReturn with
      | false =>
          rw [hIR] at hRest
          rcases kernelLowerableScheduleAux_implies_lowerStatementsAux_ok
              rest (index + 1) hRest with ⟨krest, hkrest⟩
          refine ⟨ks :: krest, ?_⟩
          show lowerStatementsAux (stmt :: rest) index false = .ok (ks :: krest)
          unfold lowerStatementsAux
          simp only [hks, hIR, hkrest]
          rfl
      | true =>
          rw [hIR] at hRest
          -- `kernelLowerableScheduleAux rest true` is true only when rest = [].
          cases rest with
          | nil =>
              refine ⟨[ks], ?_⟩
              show lowerStatementsAux [stmt] index false = .ok [ks]
              unfold lowerStatementsAux
              simp only [hks, hIR]
              rfl
          | cons s' rest' =>
              -- Contradiction: cons-with-sawReturn=true reduces to false.
              simp [Statement.kernelLowerableScheduleAux] at hRest

/-- `Statement.kernelLowerableSchedule` implies `lowerStatements`
succeeds. -/
theorem kernelLowerableSchedule_implies_lowerStatements_ok
    (stmts : List Statement)
    (h : Statement.kernelLowerableSchedule stmts = true) :
    ∃ ks, lowerStatements stmts = .ok ks :=
  kernelLowerableScheduleAux_implies_lowerStatementsAux_ok stmts 0 h

/-- `CompiledFunction.kernelLowerable` implies
`lowerCompiledFunction` succeeds. -/
theorem kernelLowerable_implies_lowerCompiledFunction_ok
    (fn : CompiledFunction)
    (h : CompiledFunction.kernelLowerable fn = true) :
    ∃ kp, lowerCompiledFunction fn = .ok kp := by
  unfold CompiledFunction.kernelLowerable at h
  rcases kernelLowerableSchedule_implies_lowerStatements_ok fn.body h
    with ⟨ks, hks⟩
  refine ⟨{ entrypointId := fn.signature
          , params := fn.params
          , returnType := fn.returnType
          , secretArgs := fn.secretArgs
          , body := ks }, ?_⟩
  unfold lowerCompiledFunction
  rw [hks]
  rfl


/-! ### W4.4 Session B-2: semantics-preservation (per-Expr)

After the `partial def → def` evaluator refactor (commit `de979bb`),
the W4.1 `evalExpr` / `evalKernelExpr` definitions reduce by `rfl`
on closed-constructor cases and unfold via `unfold + rfl` /
`simp [evalExpr]` for their inductive cases. This unblocks the
W4.4 semantics-preservation theorem.

Per-Expr preservation:
`lowerExpr e = .ok ke → evalExpr cfg env e = evalKernelExpr cfg env ke`,
and analogously for `lowerPureExpr` / `evalKernelPureExpr`.
Proved by mutual recursion on the lowering structure.

The `evalExpr.cellGet` / `evalKernelExpr.cellGet` equivalence:
- IR side does `match cfg.publicState.lookup, cfg.secretState.lookup with
  | some v, _ => .value v | none, some v => .value v | none, none => .status _`.
- Kernel side uses `cfg.readObject objectId` which is
  `match cfg.publicState.lookup with | some v => some v | none => cfg.secretState.lookup`.
- Wrapped with `match ... with | some v => .value v | none => .status _`.
The two compute the same `Option Value` (public-first lookup) and
then the same `ExprResult`. They agree by case-split.
-/

/-- Trivial-case semantics preservation for `lowerExpr`. The literal,
var, and cellGet cases reduce to direct equalities of evaluator
outputs once the lowering is normalized; they require no induction.
Inductive cases (`unary` / `binary` / `select` / `arrayGet` /
`mapGet` / `keccak256`) are deferred — the proof shape is mutual
recursion analogous to W4.3 / W4.4 Session B-1, but each case needs
careful do-bind reduction. -/
theorem lowerExpr_preserves_semantics_literal
    (cfg : OperationalConfig) (env : LocalEnv) (v : Value)
    (ke : KernelExpr) (h : lowerExpr (.literal v) = .ok ke) :
    evalExpr cfg env (.literal v) = evalKernelExpr cfg env ke := by
  simp only [lowerExpr] at h
  cases h
  rfl

theorem lowerExpr_preserves_semantics_var
    (cfg : OperationalConfig) (env : LocalEnv) (name : String)
    (ke : KernelExpr) (h : lowerExpr (.var name) = .ok ke) :
    evalExpr cfg env (.var name) = evalKernelExpr cfg env ke := by
  simp only [lowerExpr] at h
  cases h
  rfl

theorem lowerExpr_preserves_semantics_cellGet
    (cfg : OperationalConfig) (env : LocalEnv) (objectId : Nat)
    (ke : KernelExpr) (h : lowerExpr (.cellGet objectId) = .ok ke) :
    evalExpr cfg env (.cellGet objectId) = evalKernelExpr cfg env ke := by
  simp only [lowerExpr] at h
  cases h
  show evalExpr cfg env (.cellGet objectId) = evalKernelExpr cfg env (.cellGet objectId)
  unfold evalExpr evalKernelExpr OperationalConfig.readObject
  cases cfg.publicState.lookup objectId with
  | none =>
      cases cfg.secretState.lookup objectId with
      | none => rfl
      | some _ => rfl
  | some _ => rfl

mutual

/-- Per-Expr semantics preservation: `lowerExpr e = .ok ke →
evalExpr cfg env e = evalKernelExpr cfg env ke`. Mutually recursive
with `lowerPureExpr_preserves_semantics`,
`lowerExprList_preserves_semantics`, and
`lowerPureExprList_preserves_semantics` so that the `select` and
`keccak256` cases can use the appropriate sub-evaluator agreement.

The proof for each inductive case follows a fixed shape: case-split
on each sub-lowering's success/error, extract the kernel-side
witness via `Except.ok.inj`, substitute, then unfold both
evaluators and apply the IH. -/
theorem lowerExpr_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (e : Expr) (ke : KernelExpr),
      lowerExpr e = .ok ke → evalExpr cfg env e = evalKernelExpr cfg env ke
  | .literal _, _, h => by
      simp only [lowerExpr] at h; cases h; rfl
  | .var _, _, h => by
      simp only [lowerExpr] at h; cases h; rfl
  | .unary op e, ke, h => by
      cases hL : lowerExpr e with
      | error err =>
          have : lowerExpr (.unary op e) = .error err := by
            unfold lowerExpr; rw [hL]; rfl
          rw [this] at h; cases h
      | ok kp =>
          have hUn : lowerExpr (.unary op e) = .ok (.unary op kp) := by
            unfold lowerExpr; rw [hL]; rfl
          rw [hUn] at h
          have : ke = .unary op kp := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env e kp hL
          unfold evalExpr evalKernelExpr; rw [ih]; rfl
  | .binary op lhs rhs, ke, h => by
      cases hL : lowerExpr lhs with
      | error err =>
          have : lowerExpr (.binary op lhs rhs) = .error err := by
            unfold lowerExpr; rw [hL]; rfl
          rw [this] at h; cases h
      | ok kl =>
          cases hR : lowerExpr rhs with
          | error err =>
              have : lowerExpr (.binary op lhs rhs) = .error err := by
                unfold lowerExpr; rw [hL, hR]; rfl
              rw [this] at h; cases h
          | ok kr =>
              have hBin : lowerExpr (.binary op lhs rhs) = .ok (.binary op kl kr) := by
                unfold lowerExpr; rw [hL, hR]; rfl
              rw [hBin] at h
              have : ke = .binary op kl kr := (Except.ok.inj h).symm
              subst this
              have ihL := lowerExpr_preserves_semantics cfg env lhs kl hL
              have ihR := lowerExpr_preserves_semantics cfg env rhs kr hR
              unfold evalExpr evalKernelExpr; rw [ihL, ihR]; rfl
  | .select cond wt wf, ke, h => by
      cases hC : lowerExpr cond with
      | error err =>
          have : lowerExpr (.select cond wt wf) = .error err := by
            unfold lowerExpr; rw [hC]; rfl
          rw [this] at h; cases h
      | ok kc =>
          cases hT : lowerPureExpr wt with
          | error err =>
              have : lowerExpr (.select cond wt wf) = .error err := by
                unfold lowerExpr; rw [hC, hT]; rfl
              rw [this] at h; cases h
          | ok kt =>
              cases hF : lowerPureExpr wf with
              | error err =>
                  have : lowerExpr (.select cond wt wf) = .error err := by
                    unfold lowerExpr; rw [hC, hT, hF]; rfl
                  rw [this] at h; cases h
              | ok kf =>
                  have hSel : lowerExpr (.select cond wt wf) = .ok (.select kc kt kf) := by
                    unfold lowerExpr; rw [hC, hT, hF]; rfl
                  rw [hSel] at h
                  have : ke = .select kc kt kf := (Except.ok.inj h).symm
                  subst this
                  have ihC := lowerExpr_preserves_semantics cfg env cond kc hC
                  have ihT := lowerPureExpr_preserves_semantics cfg env wt kt hT
                  have ihF := lowerPureExpr_preserves_semantics cfg env wf kf hF
                  unfold evalExpr evalKernelExpr
                  rw [ihC]
                  cases evalKernelExpr cfg env kc with
                  | status _ => rfl
                  | value v =>
                      cases v with
                      | bool b => cases b <;> simp [ihT, ihF]
                      | uint _ => rfl
                      | bytes32 _ => rfl
                      | address _ => rfl
                      | structValue _ => rfl
                      | array _ => rfl
                      | map _ => rfl
  | .cellGet objectId, _, h => by
      simp only [lowerExpr] at h
      cases h
      unfold evalExpr evalKernelExpr OperationalConfig.readObject
      cases cfg.publicState.lookup objectId with
      | none =>
          cases cfg.secretState.lookup objectId with
          | none => rfl
          | some _ => rfl
      | some _ => rfl
  | .arrayGet objectId index, ke, h => by
      cases hI : lowerExpr index with
      | error err =>
          have : lowerExpr (.arrayGet objectId index) = .error err := by
            unfold lowerExpr; rw [hI]; rfl
          rw [this] at h; cases h
      | ok ki =>
          have hAG : lowerExpr (.arrayGet objectId index) = .ok (.arrayGet objectId ki) := by
            unfold lowerExpr; rw [hI]; rfl
          rw [hAG] at h
          have : ke = .arrayGet objectId ki := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env index ki hI
          unfold evalExpr evalKernelExpr
          rw [ih]
          cases evalKernelExpr cfg env ki with
          | status _ => rfl
          | value v =>
              cases v with
              | uint _ =>
                  unfold OperationalConfig.readObject
                  cases cfg.publicState.lookup objectId with
                  | none =>
                      cases cfg.secretState.lookup objectId with
                      | none => rfl
                      | some v' => cases v' <;> rfl
                  | some v' => cases v' <;> rfl
              | bool _ => rfl
              | bytes32 _ => rfl
              | address _ => rfl
              | structValue _ => rfl
              | array _ => rfl
              | map _ => rfl
  | .mapGet objectId key, ke, h => by
      cases hK : lowerExpr key with
      | error err =>
          have : lowerExpr (.mapGet objectId key) = .error err := by
            unfold lowerExpr; rw [hK]; rfl
          rw [this] at h; cases h
      | ok kk =>
          have hMG : lowerExpr (.mapGet objectId key) = .ok (.mapGet objectId kk) := by
            unfold lowerExpr; rw [hK]; rfl
          rw [hMG] at h
          have : ke = .mapGet objectId kk := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env key kk hK
          unfold evalExpr evalKernelExpr
          rw [ih]
          cases evalKernelExpr cfg env kk with
          | status _ => rfl
          | value _ =>
              unfold OperationalConfig.readObject
              cases cfg.publicState.lookup objectId with
              | none =>
                  cases cfg.secretState.lookup objectId with
                  | none => rfl
                  | some v' => cases v' <;> rfl
              | some v' => cases v' <;> rfl
  | .structField base field, ke, h => by
      cases hB : lowerExpr base with
      | error err =>
          have : lowerExpr (.structField base field) = .error err := by
            unfold lowerExpr; rw [hB]; rfl
          rw [this] at h; cases h
      | ok kb =>
          have hSF : lowerExpr (.structField base field) = .ok (.structField kb field) := by
            unfold lowerExpr; rw [hB]; rfl
          rw [hSF] at h
          have : ke = .structField kb field := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env base kb hB
          unfold evalExpr evalKernelExpr
          rw [ih]
          rfl
  | .arrayIndex base index, ke, h => by
      cases hB : lowerExpr base with
      | error err =>
          have : lowerExpr (.arrayIndex base index) = .error err := by
            unfold lowerExpr; rw [hB]; rfl
          rw [this] at h; cases h
      | ok kb =>
          cases hI : lowerExpr index with
          | error err =>
              have : lowerExpr (.arrayIndex base index) = .error err := by
                unfold lowerExpr; rw [hB, hI]; rfl
              rw [this] at h; cases h
          | ok ki =>
              have hAI : lowerExpr (.arrayIndex base index) = .ok (.arrayIndex kb ki) := by
                unfold lowerExpr; rw [hB, hI]; rfl
              rw [hAI] at h
              have : ke = .arrayIndex kb ki := (Except.ok.inj h).symm
              subst this
              have ihB := lowerExpr_preserves_semantics cfg env base kb hB
              have ihI := lowerExpr_preserves_semantics cfg env index ki hI
              unfold evalExpr evalKernelExpr
              rw [ihB]
              cases evalKernelExpr cfg env kb with
              | status _ => rfl
              | value v =>
                  cases v with
                  | array _ =>
                      rw [ihI]
                      rfl
                  | bool _ => rfl
                  | uint _ => rfl
                  | bytes32 _ => rfl
                  | address _ => rfl
                  | structValue _ => rfl
                  | map _ => rfl
  | .keccak256 parts, ke, h => by
      cases hP : lowerExprList parts with
      | error err =>
          have : lowerExpr (.keccak256 parts) = .error err := by
            unfold lowerExpr; rw [hP]; rfl
          rw [this] at h; cases h
      | ok kparts =>
          have hK : lowerExpr (.keccak256 parts) = .ok (.keccak256 kparts) := by
            unfold lowerExpr; rw [hP]; rfl
          rw [hK] at h
          have : ke = .keccak256 kparts := (Except.ok.inj h).symm
          subst this
          have ih := lowerExprList_preserves_semantics cfg env parts kparts hP
          unfold evalExpr evalKernelExpr
          rw [ih]; rfl

/-- List-companion preservation for `evalExpr` / `evalKernelExpr`. -/
theorem lowerExprList_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (es : List Expr) (kes : List KernelExpr),
      lowerExprList es = .ok kes →
        evalExprList cfg env es = evalKernelExprList cfg env kes
  | [], _, h => by
      simp only [lowerExprList] at h; cases h; rfl
  | e :: rest, kes, h => by
      cases hH : lowerExpr e with
      | error err =>
          have : lowerExprList (e :: rest) = .error err := by
            unfold lowerExprList; rw [hH]; rfl
          rw [this] at h; cases h
      | ok ke =>
          cases hT : lowerExprList rest with
          | error err =>
              have : lowerExprList (e :: rest) = .error err := by
                unfold lowerExprList; rw [hH, hT]; rfl
              rw [this] at h; cases h
          | ok krest =>
              have hCons : lowerExprList (e :: rest) = .ok (ke :: krest) := by
                unfold lowerExprList; rw [hH, hT]; rfl
              rw [hCons] at h
              have : kes = ke :: krest := (Except.ok.inj h).symm
              subst this
              have ihH := lowerExpr_preserves_semantics cfg env e ke hH
              have ihT := lowerExprList_preserves_semantics cfg env rest krest hT
              unfold evalExprList evalKernelExprList
              rw [ihH, ihT]
              rfl

/-- Per-pure-Expr semantics preservation. -/
theorem lowerPureExpr_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (e : Expr) (ke : KernelPureExpr),
      lowerPureExpr e = .ok ke →
        evalExpr cfg env e = evalKernelPureExpr cfg env ke
  | .literal _, _, h => by
      simp only [lowerPureExpr] at h; cases h; rfl
  | .var _, _, h => by
      simp only [lowerPureExpr] at h; cases h; rfl
  | .unary op e, ke, h => by
      cases hL : lowerPureExpr e with
      | error err =>
          have : lowerPureExpr (.unary op e) = .error err := by
            unfold lowerPureExpr; rw [hL]; rfl
          rw [this] at h; cases h
      | ok kp =>
          have hUn : lowerPureExpr (.unary op e) = .ok (.unary op kp) := by
            unfold lowerPureExpr; rw [hL]; rfl
          rw [hUn] at h
          have : ke = .unary op kp := (Except.ok.inj h).symm
          subst this
          have ih := lowerPureExpr_preserves_semantics cfg env e kp hL
          unfold evalExpr evalKernelPureExpr; rw [ih]; rfl
  | .binary op lhs rhs, ke, h => by
      cases hL : lowerPureExpr lhs with
      | error err =>
          have : lowerPureExpr (.binary op lhs rhs) = .error err := by
            unfold lowerPureExpr; rw [hL]; rfl
          rw [this] at h; cases h
      | ok kl =>
          cases hR : lowerPureExpr rhs with
          | error err =>
              have : lowerPureExpr (.binary op lhs rhs) = .error err := by
                unfold lowerPureExpr; rw [hL, hR]; rfl
              rw [this] at h; cases h
          | ok kr =>
              have hBin : lowerPureExpr (.binary op lhs rhs) = .ok (.binary op kl kr) := by
                unfold lowerPureExpr; rw [hL, hR]; rfl
              rw [hBin] at h
              have : ke = .binary op kl kr := (Except.ok.inj h).symm
              subst this
              have ihL := lowerPureExpr_preserves_semantics cfg env lhs kl hL
              have ihR := lowerPureExpr_preserves_semantics cfg env rhs kr hR
              unfold evalExpr evalKernelPureExpr; rw [ihL, ihR]; rfl
  | .select cond wt wf, ke, h => by
      cases hC : lowerPureExpr cond with
      | error err =>
          have : lowerPureExpr (.select cond wt wf) = .error err := by
            unfold lowerPureExpr; rw [hC]; rfl
          rw [this] at h; cases h
      | ok kc =>
          cases hT : lowerPureExpr wt with
          | error err =>
              have : lowerPureExpr (.select cond wt wf) = .error err := by
                unfold lowerPureExpr; rw [hC, hT]; rfl
              rw [this] at h; cases h
          | ok kt =>
              cases hF : lowerPureExpr wf with
              | error err =>
                  have : lowerPureExpr (.select cond wt wf) = .error err := by
                    unfold lowerPureExpr; rw [hC, hT, hF]; rfl
                  rw [this] at h; cases h
              | ok kf =>
                  have hSel : lowerPureExpr (.select cond wt wf) = .ok (.select kc kt kf) := by
                    unfold lowerPureExpr; rw [hC, hT, hF]; rfl
                  rw [hSel] at h
                  have : ke = .select kc kt kf := (Except.ok.inj h).symm
                  subst this
                  have ihC := lowerPureExpr_preserves_semantics cfg env cond kc hC
                  have ihT := lowerPureExpr_preserves_semantics cfg env wt kt hT
                  have ihF := lowerPureExpr_preserves_semantics cfg env wf kf hF
                  unfold evalExpr evalKernelPureExpr
                  rw [ihC]
                  cases evalKernelPureExpr cfg env kc with
                  | status _ => rfl
                  | value v =>
                      cases v with
                      | bool b => cases b <;> simp [ihT, ihF]
                      | uint _ => rfl
                      | bytes32 _ => rfl
                      | address _ => rfl
                      | structValue _ => rfl
                      | array _ => rfl
                      | map _ => rfl
  | .cellGet _, _, h => by simp [lowerPureExpr] at h
  | .arrayGet _ _, _, h => by simp [lowerPureExpr] at h
  | .mapGet _ _, _, h => by simp [lowerPureExpr] at h
  | .structField base field, ke, h => by
      cases hB : lowerPureExpr base with
      | error err =>
          have : lowerPureExpr (.structField base field) = .error err := by
            unfold lowerPureExpr; rw [hB]; rfl
          rw [this] at h; cases h
      | ok kb =>
          have hSF : lowerPureExpr (.structField base field) = .ok (.structField kb field) := by
            unfold lowerPureExpr; rw [hB]; rfl
          rw [hSF] at h
          have : ke = .structField kb field := (Except.ok.inj h).symm
          subst this
          have ih := lowerPureExpr_preserves_semantics cfg env base kb hB
          unfold evalExpr evalKernelPureExpr
          rw [ih]
          rfl
  | .arrayIndex base index, ke, h => by
      cases hB : lowerPureExpr base with
      | error err =>
          have : lowerPureExpr (.arrayIndex base index) = .error err := by
            unfold lowerPureExpr; rw [hB]; rfl
          rw [this] at h; cases h
      | ok kb =>
          cases hI : lowerPureExpr index with
          | error err =>
              have : lowerPureExpr (.arrayIndex base index) = .error err := by
                unfold lowerPureExpr; rw [hB, hI]; rfl
              rw [this] at h; cases h
          | ok ki =>
              have hAI : lowerPureExpr (.arrayIndex base index) = .ok (.arrayIndex kb ki) := by
                unfold lowerPureExpr; rw [hB, hI]; rfl
              rw [hAI] at h
              have : ke = .arrayIndex kb ki := (Except.ok.inj h).symm
              subst this
              have ihB := lowerPureExpr_preserves_semantics cfg env base kb hB
              have ihI := lowerPureExpr_preserves_semantics cfg env index ki hI
              unfold evalExpr evalKernelPureExpr
              rw [ihB]
              cases evalKernelPureExpr cfg env kb with
              | status _ => rfl
              | value v =>
                  cases v with
                  | array _ =>
                      rw [ihI]
                      rfl
                  | bool _ => rfl
                  | uint _ => rfl
                  | bytes32 _ => rfl
                  | address _ => rfl
                  | structValue _ => rfl
                  | map _ => rfl
  | .keccak256 parts, ke, h => by
      cases hP : lowerPureExprList parts with
      | error err =>
          have : lowerPureExpr (.keccak256 parts) = .error err := by
            unfold lowerPureExpr; rw [hP]; rfl
          rw [this] at h; cases h
      | ok kparts =>
          have hK : lowerPureExpr (.keccak256 parts) = .ok (.keccak256 kparts) := by
            unfold lowerPureExpr; rw [hP]; rfl
          rw [hK] at h
          have : ke = .keccak256 kparts := (Except.ok.inj h).symm
          subst this
          have ih := lowerPureExprList_preserves_semantics cfg env parts kparts hP
          unfold evalExpr evalKernelPureExpr
          rw [ih]; rfl

/-- List-companion preservation for pure expressions. -/
theorem lowerPureExprList_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (es : List Expr) (kes : List KernelPureExpr),
      lowerPureExprList es = .ok kes →
        evalExprList cfg env es = evalKernelPureExprList cfg env kes
  | [], _, h => by
      simp only [lowerPureExprList] at h; cases h; rfl
  | e :: rest, kes, h => by
      cases hH : lowerPureExpr e with
      | error err =>
          have : lowerPureExprList (e :: rest) = .error err := by
            unfold lowerPureExprList; rw [hH]; rfl
          rw [this] at h; cases h
      | ok ke =>
          cases hT : lowerPureExprList rest with
          | error err =>
              have : lowerPureExprList (e :: rest) = .error err := by
                unfold lowerPureExprList; rw [hH, hT]; rfl
              rw [this] at h; cases h
          | ok krest =>
              have hCons : lowerPureExprList (e :: rest) = .ok (ke :: krest) := by
                unfold lowerPureExprList; rw [hH, hT]; rfl
              rw [hCons] at h
              have : kes = ke :: krest := (Except.ok.inj h).symm
              subst this
              have ihH := lowerPureExpr_preserves_semantics cfg env e ke hH
              have ihT := lowerPureExprList_preserves_semantics cfg env rest krest hT
              unfold evalExprList evalKernelPureExprList
              rw [ihH, ihT]; rfl

end

/-! ### W4.4 Session B-2: per-Statement semantics-preservation

`lowerStatement_preserves_semantics` lifts the per-Expr preservation
through statement evaluation. Each statement constructor case
follows the same `unfold + Except.ok.inj + subst + rw [ih*] + rfl`
pattern, with the per-Expr preservation theorem providing the IH
for sub-expressions.

The forbidden constructors `ifStmt` / `forLoop` close trivially
because `lowerStatement` returns `.error` for them, making the
hypothesis `lowerStatement s = .ok ks` contradictory.

The `cellSet` / `arraySet` / `mapPut` cases additionally case-split
on the predicate option (`none` vs `some p`) and on the evaluated
predicate boolean (`true` vs `false`) to align both evaluators'
masked-store semantics. -/

theorem lowerStatement_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    ∀ (s : Statement) (ks : KernelStatement),
      lowerStatement s = .ok ks →
        evalStatement cfg env oc s = evalKernelStatement cfg env oc ks
  | .declare name ty value, ks, h => by
      cases hV : lowerExpr value with
      | error err =>
          have : lowerStatement (.declare name ty value) = .error err := by
            simp only [lowerStatement, hV]; rfl
          rw [this] at h; cases h
      | ok kv =>
          have hOk : lowerStatement (.declare name ty value) = .ok (.declare name ty kv) := by
            simp only [lowerStatement, hV]; rfl
          rw [hOk] at h
          have : ks = .declare name ty kv := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env value kv hV
          simp only [evalStatement, evalKernelStatement]
          rw [ih]; rfl
  | .assign name value, ks, h => by
      cases hV : lowerExpr value with
      | error err =>
          have : lowerStatement (.assign name value) = .error err := by
            simp only [lowerStatement, hV]; rfl
          rw [this] at h; cases h
      | ok kv =>
          have hOk : lowerStatement (.assign name value) = .ok (.assign name kv) := by
            simp only [lowerStatement, hV]; rfl
          rw [hOk] at h
          have : ks = .assign name kv := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env value kv hV
          simp only [evalStatement, evalKernelStatement]
          rw [ih]; rfl
  | .require cond, ks, h => by
      cases hC : lowerExpr cond with
      | error err =>
          have : lowerStatement (.require cond) = .error err := by
            simp only [lowerStatement, hC]; rfl
          rw [this] at h; cases h
      | ok kc =>
          have hOk : lowerStatement (.require cond) = .ok (.require kc) := by
            simp only [lowerStatement, hC]; rfl
          rw [hOk] at h
          have : ks = .require kc := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env cond kc hC
          simp only [evalStatement, evalKernelStatement]
          rw [ih]; rfl
  | .abortIf cond, ks, h => by
      cases hC : lowerExpr cond with
      | error err =>
          have : lowerStatement (.abortIf cond) = .error err := by
            simp only [lowerStatement, hC]; rfl
          rw [this] at h; cases h
      | ok kc =>
          have hOk : lowerStatement (.abortIf cond) = .ok (.abortIf kc) := by
            simp only [lowerStatement, hC]; rfl
          rw [hOk] at h
          have : ks = .abortIf kc := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env cond kc hC
          simp only [evalStatement, evalKernelStatement]
          rw [ih]; rfl
  | .ifStmt _ _ _, _, h => by simp [lowerStatement] at h
  | .forLoop _ _ _ _ _, _, h => by simp [lowerStatement] at h
  | .cellSet id value pred, ks, h => by
      cases hV : lowerExpr value with
      | error err =>
          have : lowerStatement (.cellSet id value pred) = .error err := by
            simp only [lowerStatement, hV]; rfl
          rw [this] at h; cases h
      | ok kv =>
          cases pred with
          | none =>
              have hOk : lowerStatement (.cellSet id value none) =
                  .ok (.cellSet id kv none) := by
                simp only [lowerStatement, hV]; rfl
              rw [hOk] at h
              have : ks = .cellSet id kv none := (Except.ok.inj h).symm
              subst this
              have ihV := lowerExpr_preserves_semantics cfg env value kv hV
              simp only [evalStatement, evalKernelStatement]
              rw [ihV]; rfl
          | some p =>
              cases hP : lowerExpr p with
              | error err =>
                  have : lowerStatement (.cellSet id value (some p)) = .error err := by
                    simp only [lowerStatement, hV, hP]; rfl
                  rw [this] at h; cases h
              | ok kp =>
                  have hOk : lowerStatement (.cellSet id value (some p)) =
                      .ok (.cellSet id kv (some kp)) := by
                    simp only [lowerStatement, hV, hP]; rfl
                  rw [hOk] at h
                  have : ks = .cellSet id kv (some kp) := (Except.ok.inj h).symm
                  subst this
                  have ihV := lowerExpr_preserves_semantics cfg env value kv hV
                  have ihP := lowerExpr_preserves_semantics cfg env p kp hP
                  simp only [evalStatement, evalKernelStatement]
                  rw [ihV, ihP]; rfl
  | .arraySet id index value pred, ks, h => by
      cases hI : lowerExpr index with
      | error err =>
          have : lowerStatement (.arraySet id index value pred) = .error err := by
            simp only [lowerStatement, hI]; rfl
          rw [this] at h; cases h
      | ok ki =>
          cases hV : lowerExpr value with
          | error err =>
              have : lowerStatement (.arraySet id index value pred) = .error err := by
                simp only [lowerStatement, hI, hV]; rfl
              rw [this] at h; cases h
          | ok kv =>
              cases pred with
              | none =>
                  have hOk : lowerStatement (.arraySet id index value none) =
                      .ok (.arraySet id ki kv none) := by
                    simp only [lowerStatement, hI, hV]; rfl
                  rw [hOk] at h
                  have : ks = .arraySet id ki kv none := (Except.ok.inj h).symm
                  subst this
                  have ihI := lowerExpr_preserves_semantics cfg env index ki hI
                  have ihV := lowerExpr_preserves_semantics cfg env value kv hV
                  simp only [evalStatement, evalKernelStatement]
                  rw [ihI, ihV]; rfl
              | some p =>
                  cases hP : lowerExpr p with
                  | error err =>
                      have : lowerStatement (.arraySet id index value (some p)) =
                          .error err := by
                        simp only [lowerStatement, hI, hV, hP]; rfl
                      rw [this] at h; cases h
                  | ok kp =>
                      have hOk : lowerStatement (.arraySet id index value (some p)) =
                          .ok (.arraySet id ki kv (some kp)) := by
                        simp only [lowerStatement, hI, hV, hP]; rfl
                      rw [hOk] at h
                      have : ks = .arraySet id ki kv (some kp) :=
                        (Except.ok.inj h).symm
                      subst this
                      have ihI := lowerExpr_preserves_semantics cfg env index ki hI
                      have ihV := lowerExpr_preserves_semantics cfg env value kv hV
                      have ihP := lowerExpr_preserves_semantics cfg env p kp hP
                      simp only [evalStatement, evalKernelStatement]
                      rw [ihI, ihV, ihP]; rfl
  | .mapPut id key value pred, ks, h => by
      cases hK : lowerExpr key with
      | error err =>
          have : lowerStatement (.mapPut id key value pred) = .error err := by
            simp only [lowerStatement, hK]; rfl
          rw [this] at h; cases h
      | ok kk =>
          cases hV : lowerExpr value with
          | error err =>
              have : lowerStatement (.mapPut id key value pred) = .error err := by
                simp only [lowerStatement, hK, hV]; rfl
              rw [this] at h; cases h
          | ok kv =>
              cases pred with
              | none =>
                  have hOk : lowerStatement (.mapPut id key value none) =
                      .ok (.mapPut id kk kv none) := by
                    simp only [lowerStatement, hK, hV]; rfl
                  rw [hOk] at h
                  have : ks = .mapPut id kk kv none := (Except.ok.inj h).symm
                  subst this
                  have ihK := lowerExpr_preserves_semantics cfg env key kk hK
                  have ihV := lowerExpr_preserves_semantics cfg env value kv hV
                  simp only [evalStatement, evalKernelStatement]
                  rw [ihK, ihV]; rfl
              | some p =>
                  cases hP : lowerExpr p with
                  | error err =>
                      have : lowerStatement (.mapPut id key value (some p)) =
                          .error err := by
                        simp only [lowerStatement, hK, hV, hP]; rfl
                      rw [this] at h; cases h
                  | ok kp =>
                      have hOk : lowerStatement (.mapPut id key value (some p)) =
                          .ok (.mapPut id kk kv (some kp)) := by
                        simp only [lowerStatement, hK, hV, hP]; rfl
                      rw [hOk] at h
                      have : ks = .mapPut id kk kv (some kp) :=
                        (Except.ok.inj h).symm
                      subst this
                      have ihK := lowerExpr_preserves_semantics cfg env key kk hK
                      have ihV := lowerExpr_preserves_semantics cfg env value kv hV
                      have ihP := lowerExpr_preserves_semantics cfg env p kp hP
                      simp only [evalStatement, evalKernelStatement]
                      rw [ihK, ihV, ihP]; rfl
  | .retStmt none, ks, h => by
      simp only [lowerStatement] at h
      cases h
      simp only [evalStatement, evalKernelStatement]
  | .retStmt (some value), ks, h => by
      cases hV : lowerExpr value with
      | error err =>
          have : lowerStatement (.retStmt (some value)) = .error err := by
            simp only [lowerStatement, hV]; rfl
          rw [this] at h; cases h
      | ok kv =>
          have hOk : lowerStatement (.retStmt (some value)) = .ok (.retStmt (some kv)) := by
            simp only [lowerStatement, hV]; rfl
          rw [hOk] at h
          have : ks = .retStmt (some kv) := (Except.ok.inj h).symm
          subst this
          have ih := lowerExpr_preserves_semantics cfg env value kv hV
          simp only [evalStatement, evalKernelStatement]
          rw [ih]; rfl

/-! ### W4.4 Session B-2: list-level (`evalBody`) preservation -/

/-- The lift is universally quantified over `cfg env oc` so the
recursive call's state threading works seamlessly. The `sawReturn`
parameter is also universally quantified so the recursive call (which
uses `stmt.isReturn` for the next iteration) can apply the IH. The
`sawReturn = true ∧ rest ≠ []` case is contradictory because
`lowerStatementsAux` returns `.error NonFinalReturn` then. -/
theorem lowerStatementsAux_preserves_semantics :
    ∀ (stmts : List Statement) (kstmts : List KernelStatement)
      (index : Nat) (sawReturn : Bool)
      (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome),
      lowerStatementsAux stmts index sawReturn = .ok kstmts →
        evalBody cfg env oc stmts = evalKernelBody cfg env oc kstmts
  | [], _, _, _, _, _, _, h => by
      simp only [lowerStatementsAux] at h
      cases h
      simp only [evalBody, evalKernelBody]
  | stmt :: rest, kstmts, index, sawReturn, cfg, env, oc, h => by
      cases sawReturn with
      | true =>
          -- Lowering returns .error NonFinalReturn; contradiction.
          simp only [lowerStatementsAux, if_true] at h
          cases h
      | false =>
          cases hS : lowerStatement stmt with
          | error err =>
              have : lowerStatementsAux (stmt :: rest) index false = .error err := by
                simp only [lowerStatementsAux, hS]; rfl
              rw [this] at h; cases h
          | ok ks =>
              cases hRest : lowerStatementsAux rest (index + 1) stmt.isReturn with
              | error err =>
                  have : lowerStatementsAux (stmt :: rest) index false = .error err := by
                    simp only [lowerStatementsAux, hS, hRest]; rfl
                  rw [this] at h; cases h
              | ok krest =>
                  have hOk : lowerStatementsAux (stmt :: rest) index false =
                      .ok (ks :: krest) := by
                    simp only [lowerStatementsAux, hS, hRest]; rfl
                  rw [hOk] at h
                  have hkstmts : kstmts = ks :: krest := (Except.ok.inj h).symm
                  subst hkstmts
                  have ihStmt :=
                    lowerStatement_preserves_semantics cfg env oc stmt ks hS
                  simp only [evalBody, evalKernelBody]
                  rw [ihStmt]
                  generalize hStep : evalKernelStatement cfg env oc ks = step
                  cases step with
                  | mk cfg' rest' =>
                      cases rest' with
                      | mk env' oc' =>
                          simp only []
                          cases hStatus : oc'.status with
                          | completed =>
                              by_cases hRet : oc'.publicResult.isSome
                              · simp [hRet]
                              · simp [hRet]
                                exact lowerStatementsAux_preserves_semantics
                                  rest krest (index + 1) stmt.isReturn cfg' env' oc' hRest
                          | _ => simp

/-- Wrapper: `lowerStatements` (which is `lowerStatementsAux _ 0
false`) preserves semantics. -/
theorem lowerStatements_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome)
    (stmts : List Statement) (kstmts : List KernelStatement)
    (h : lowerStatements stmts = .ok kstmts) :
    evalBody cfg env oc stmts = evalKernelBody cfg env oc kstmts :=
  lowerStatementsAux_preserves_semantics stmts kstmts 0 false cfg env oc h

/-! ### W4.4 Session B-2: program-level (`evalContract`) preservation -/

/-- The kernel-side `KernelProgram.initialEnv` agrees with the IR-side
`OperationalConfig.initialEnv` whenever the kernel program's
parameters match the function's parameters. The lowering produces a
kernel program with `kp.params = fn.params`, so this is the
agreement lemma the program-level theorem uses. -/
theorem KernelProgram.initialEnv_eq_of_params_eq
    (cfg : OperationalConfig) (fn : CompiledFunction) (kp : KernelProgram)
    (hParams : kp.params = fn.params) :
    kp.initialEnv cfg.declaredArgs = cfg.initialEnv fn := by
  unfold KernelProgram.initialEnv OperationalConfig.initialEnv
  rw [hParams]

/-- Program-level preservation: when the lowering succeeds and the IR
configuration's entrypoint resolves to the function being lowered,
the IR contract evaluator and the kernel program evaluator agree on
the outcome. -/
theorem lowerCompiledFunction_preserves_semantics
    (cfg : OperationalConfig) (fn : CompiledFunction) (kp : KernelProgram)
    (hLow : lowerCompiledFunction fn = .ok kp)
    (hEntry : cfg.entrypointFn? = some fn) :
    evalContract cfg = evalKernelProgram kp cfg := by
  -- Extract kp's structure from the lowering hypothesis.
  cases hBody : lowerStatements fn.body with
  | error err =>
      have : lowerCompiledFunction fn = .error err := by
        unfold lowerCompiledFunction; rw [hBody]; rfl
      rw [this] at hLow; cases hLow
  | ok ks =>
      have hLowOk : lowerCompiledFunction fn = .ok
        { entrypointId := fn.signature, params := fn.params,
          returnType := fn.returnType, secretArgs := fn.secretArgs, body := ks } := by
        unfold lowerCompiledFunction; rw [hBody]; rfl
      rw [hLowOk] at hLow
      have hkp : kp = ⟨fn.signature, fn.params, fn.returnType, fn.secretArgs, ks⟩ :=
        (Except.ok.inj hLow).symm
      subst hkp
      -- Both evaluators now have the same parameters and lowered body.
      have hParams :
          (KernelProgram.mk fn.signature fn.params fn.returnType fn.secretArgs ks).params
            = fn.params := rfl
      have hInitEnv :=
        KernelProgram.initialEnv_eq_of_params_eq cfg fn _ hParams
      unfold evalContract evalKernelProgram
      simp only [hEntry, hInitEnv]
      cases hEnv : cfg.initialEnv fn with
      | none => simp
      | some env =>
          simp
          -- Use the list-level preservation theorem.
          have ihBody := lowerStatements_preserves_semantics
            cfg env Outcome.empty fn.body ks hBody
          rw [ihBody]

mutual

/-- Branchless-pure expressions are fragment-valid: the structural
admission predicate from W4.3 is *weaker* than the branchless-pure
restriction, so any branchless-pure expression also satisfies
`Expr.fragmentValid`. The mutual list companion handles the
`Expr.keccak256` recursion. -/
theorem branchlessPureExpr_implies_fragmentValid :
    ∀ e : Expr, branchlessPureExpr e = true → Expr.fragmentValid e = true
  | .literal _, _ => rfl
  | .var _, _ => rfl
  | .unary _ inner, h => by
      simp only [branchlessPureExpr] at h
      simp only [Expr.fragmentValid]
      exact branchlessPureExpr_implies_fragmentValid inner h
  | .binary _ lhs rhs, h => by
      simp only [branchlessPureExpr, Bool.and_eq_true] at h
      simp only [Expr.fragmentValid, Bool.and_eq_true]
      exact ⟨branchlessPureExpr_implies_fragmentValid lhs h.1,
             branchlessPureExpr_implies_fragmentValid rhs h.2⟩
  | .select cond wt wf, h => by
      simp only [branchlessPureExpr, Bool.and_eq_true] at h
      simp only [Expr.fragmentValid, Bool.and_eq_true]
      rcases h with ⟨⟨hC, hT⟩, hF⟩
      refine ⟨⟨⟨⟨?_, ?_⟩, ?_⟩, hT⟩, hF⟩
      · exact branchlessPureExpr_implies_fragmentValid cond hC
      · exact branchlessPureExpr_implies_fragmentValid wt hT
      · exact branchlessPureExpr_implies_fragmentValid wf hF
  | .cellGet _, h => by simp [branchlessPureExpr] at h
  | .arrayGet _ _, h => by simp [branchlessPureExpr] at h
  | .mapGet _ _, h => by simp [branchlessPureExpr] at h
  | .structField base _, h => by
      simp only [branchlessPureExpr] at h
      simp only [Expr.fragmentValid]
      exact branchlessPureExpr_implies_fragmentValid base h
  | .arrayIndex base index, h => by
      simp only [branchlessPureExpr, Bool.and_eq_true] at h
      simp only [Expr.fragmentValid, Bool.and_eq_true]
      exact ⟨branchlessPureExpr_implies_fragmentValid base h.1,
        branchlessPureExpr_implies_fragmentValid index h.2⟩
  | .keccak256 parts, h => by
      simp only [branchlessPureExpr] at h
      simp only [Expr.fragmentValid]
      exact branchlessPureExprList_implies_fragmentValidList parts h

theorem branchlessPureExprList_implies_fragmentValidList :
    ∀ es : List Expr,
      branchlessPureExprList es = true → Expr.fragmentValidList es = true
  | [], _ => rfl
  | e :: rest, h => by
      simp only [branchlessPureExprList, Bool.and_eq_true] at h
      simp only [Expr.fragmentValidList, Bool.and_eq_true]
      refine ⟨?_, ?_⟩
      · exact branchlessPureExpr_implies_fragmentValid e h.1
      · exact branchlessPureExprList_implies_fragmentValidList rest h.2

end
/-! ### W4.4 reverse iff: lowering succeeds → precondition holds

The reverse direction of the W4.4 lowering iff: if `lowerExpr` /
`lowerPureExpr` / `lowerStatement` / `lowerStatements` /
`lowerCompiledFunction` succeed, then the corresponding precondition
(`Expr.fragmentValid` / `branchlessPureExpr` /
`Statement.kernelLowerable` / `Statement.kernelLowerableSchedule` /
`CompiledFunction.kernelLowerable`) holds.

Combined with the forward iff theorems (above), this gives the full
biconditional: "lowering succeeds iff the program is in the admitted
fragment." This is the prerequisite for W4.6 (artifact-checker
demotion): the existing direct artifact checker can verify that
lowering succeeded, and the reverse iff lifts that to "the program
is in the admitted fragment, so all the W4.2 + W4.4 + W4.5 theorems
apply." -/

mutual

theorem lowerPureExpr_ok_implies_branchlessPureExpr :
    ∀ (e : Expr) (ke : KernelPureExpr),
      lowerPureExpr e = .ok ke → branchlessPureExpr e = true
  | .literal _, _, _ => rfl
  | .var _, _, _ => rfl
  | .unary op e, _, h => by
      unfold lowerPureExpr at h
      cases hRec : lowerPureExpr e with
      | error _ => simp [hRec, bind, Except.bind] at h
      | ok ke =>
          simp [hRec, bind, Except.bind] at h
          simp [branchlessPureExpr]
          exact lowerPureExpr_ok_implies_branchlessPureExpr e ke hRec
  | .binary op lhs rhs, _, h => by
      unfold lowerPureExpr at h
      cases hL : lowerPureExpr lhs with
      | error _ => simp [hL, bind, Except.bind] at h
      | ok kl =>
          cases hR : lowerPureExpr rhs with
          | error _ => simp [hL, hR, bind, Except.bind] at h
          | ok kr =>
              simp [hL, hR, bind, Except.bind] at h
              simp [branchlessPureExpr]
              exact ⟨lowerPureExpr_ok_implies_branchlessPureExpr lhs kl hL,
                lowerPureExpr_ok_implies_branchlessPureExpr rhs kr hR⟩
  | .select cond wt wf, _, h => by
      unfold lowerPureExpr at h
      cases hC : lowerPureExpr cond with
      | error _ => simp [hC, bind, Except.bind] at h
      | ok kc =>
          cases hT : lowerPureExpr wt with
          | error _ => simp [hC, hT, bind, Except.bind] at h
          | ok kt =>
              cases hF : lowerPureExpr wf with
              | error _ => simp [hC, hT, hF, bind, Except.bind] at h
              | ok kf =>
                  simp [hC, hT, hF, bind, Except.bind] at h
                  simp [branchlessPureExpr]
                  exact ⟨⟨lowerPureExpr_ok_implies_branchlessPureExpr cond kc hC,
                          lowerPureExpr_ok_implies_branchlessPureExpr wt kt hT⟩,
                          lowerPureExpr_ok_implies_branchlessPureExpr wf kf hF⟩
  | .cellGet _, _, h => by simp [lowerPureExpr] at h
  | .arrayGet _ _, _, h => by simp [lowerPureExpr] at h
  | .mapGet _ _, _, h => by simp [lowerPureExpr] at h
  | .structField base field, _, h => by
      unfold lowerPureExpr at h
      cases hB : lowerPureExpr base with
      | error _ => simp [hB, bind, Except.bind] at h
      | ok kb =>
          simp [hB, bind, Except.bind] at h
          simp [branchlessPureExpr]
          exact lowerPureExpr_ok_implies_branchlessPureExpr base kb hB
  | .arrayIndex base index, _, h => by
      unfold lowerPureExpr at h
      cases hB : lowerPureExpr base with
      | error _ => simp [hB, bind, Except.bind] at h
      | ok kb =>
          cases hI : lowerPureExpr index with
          | error _ => simp [hB, hI, bind, Except.bind] at h
          | ok ki =>
              simp [hB, hI, bind, Except.bind] at h
              simp [branchlessPureExpr]
              exact ⟨lowerPureExpr_ok_implies_branchlessPureExpr base kb hB,
                lowerPureExpr_ok_implies_branchlessPureExpr index ki hI⟩
  | .keccak256 parts, _, h => by
      unfold lowerPureExpr at h
      cases hParts : lowerPureExprList parts with
      | error _ => simp [hParts, bind, Except.bind] at h
      | ok kparts =>
          simp [hParts, bind, Except.bind] at h
          simp [branchlessPureExpr]
          exact lowerPureExprList_ok_implies_branchlessPureExprList parts kparts hParts

theorem lowerPureExprList_ok_implies_branchlessPureExprList :
    ∀ (es : List Expr) (kes : List KernelPureExpr),
      lowerPureExprList es = .ok kes → branchlessPureExprList es = true
  | [], _, _ => rfl
  | e :: rest, _, h => by
      unfold lowerPureExprList at h
      cases hHead : lowerPureExpr e with
      | error _ => simp [hHead, bind, Except.bind] at h
      | ok ke =>
          cases hTail : lowerPureExprList rest with
          | error _ => simp [hHead, hTail, bind, Except.bind] at h
          | ok krest =>
              simp [hHead, hTail, bind, Except.bind] at h
              simp [branchlessPureExprList]
              exact ⟨lowerPureExpr_ok_implies_branchlessPureExpr e ke hHead,
                lowerPureExprList_ok_implies_branchlessPureExprList rest krest hTail⟩

end

mutual

theorem lowerExpr_ok_implies_fragmentValid :
    ∀ (e : Expr) (ke : KernelExpr),
      lowerExpr e = .ok ke → Expr.fragmentValid e = true
  | .literal _, _, _ => rfl
  | .var _, _, _ => rfl
  | .unary op e, _, h => by
      unfold lowerExpr at h
      cases hRec : lowerExpr e with
      | error _ => simp [hRec, bind, Except.bind] at h
      | ok ke =>
          simp [hRec, bind, Except.bind] at h
          simp [Expr.fragmentValid]
          exact lowerExpr_ok_implies_fragmentValid e ke hRec
  | .binary op lhs rhs, _, h => by
      unfold lowerExpr at h
      cases hL : lowerExpr lhs with
      | error _ => simp [hL, bind, Except.bind] at h
      | ok kl =>
          cases hR : lowerExpr rhs with
          | error _ => simp [hL, hR, bind, Except.bind] at h
          | ok kr =>
              simp [hL, hR, bind, Except.bind] at h
              simp [Expr.fragmentValid]
              exact ⟨lowerExpr_ok_implies_fragmentValid lhs kl hL,
                lowerExpr_ok_implies_fragmentValid rhs kr hR⟩
  | .select cond wt wf, _, h => by
      unfold lowerExpr at h
      cases hC : lowerExpr cond with
      | error _ => simp [hC, bind, Except.bind] at h
      | ok kc =>
          cases hT : lowerPureExpr wt with
          | error _ => simp [hC, hT, bind, Except.bind] at h
          | ok kt =>
              cases hF : lowerPureExpr wf with
              | error _ => simp [hC, hT, hF, bind, Except.bind] at h
              | ok kf =>
                  simp [hC, hT, hF, bind, Except.bind] at h
                  -- Need: fragmentValid for cond + wt + wf, plus branchlessPureExpr wt + wf.
                  -- The select arms wt/wf were lowered via lowerPureExpr (succeeded by hT, hF),
                  -- which by lowerPureExpr_ok_implies_branchlessPureExpr gives branchlessness.
                  -- branchless implies fragment-valid (existing W4.4 fact).
                  have hBT := lowerPureExpr_ok_implies_branchlessPureExpr wt kt hT
                  have hBF := lowerPureExpr_ok_implies_branchlessPureExpr wf kf hF
                  simp [Expr.fragmentValid]
                  refine ⟨⟨⟨⟨?_, ?_⟩, ?_⟩, hBT⟩, hBF⟩
                  · exact lowerExpr_ok_implies_fragmentValid cond kc hC
                  · exact branchlessPureExpr_implies_fragmentValid wt hBT
                  · exact branchlessPureExpr_implies_fragmentValid wf hBF
  | .cellGet _, _, _ => rfl
  | .arrayGet id index, _, h => by
      unfold lowerExpr at h
      cases hI : lowerExpr index with
      | error _ => simp [hI, bind, Except.bind] at h
      | ok ki =>
          simp [hI, bind, Except.bind] at h
          simp [Expr.fragmentValid]
          exact lowerExpr_ok_implies_fragmentValid index ki hI
  | .mapGet id key, _, h => by
      unfold lowerExpr at h
      cases hK : lowerExpr key with
      | error _ => simp [hK, bind, Except.bind] at h
      | ok kk =>
          simp [hK, bind, Except.bind] at h
          simp [Expr.fragmentValid]
          exact lowerExpr_ok_implies_fragmentValid key kk hK
  | .structField base field, _, h => by
      unfold lowerExpr at h
      cases hB : lowerExpr base with
      | error _ => simp [hB, bind, Except.bind] at h
      | ok kb =>
          simp [hB, bind, Except.bind] at h
          simp [Expr.fragmentValid]
          exact lowerExpr_ok_implies_fragmentValid base kb hB
  | .arrayIndex base index, _, h => by
      unfold lowerExpr at h
      cases hB : lowerExpr base with
      | error _ => simp [hB, bind, Except.bind] at h
      | ok kb =>
          cases hI : lowerExpr index with
          | error _ => simp [hB, hI, bind, Except.bind] at h
          | ok ki =>
              simp [hB, hI, bind, Except.bind] at h
              simp [Expr.fragmentValid]
              exact ⟨lowerExpr_ok_implies_fragmentValid base kb hB,
                lowerExpr_ok_implies_fragmentValid index ki hI⟩
  | .keccak256 parts, _, h => by
      unfold lowerExpr at h
      cases hParts : lowerExprList parts with
      | error _ => simp [hParts, bind, Except.bind] at h
      | ok kparts =>
          simp [hParts, bind, Except.bind] at h
          simp [Expr.fragmentValid]
          exact lowerExprList_ok_implies_fragmentValidList parts kparts hParts

theorem lowerExprList_ok_implies_fragmentValidList :
    ∀ (es : List Expr) (kes : List KernelExpr),
      lowerExprList es = .ok kes → Expr.fragmentValidList es = true
  | [], _, _ => rfl
  | e :: rest, _, h => by
      unfold lowerExprList at h
      cases hHead : lowerExpr e with
      | error _ => simp [hHead, bind, Except.bind] at h
      | ok ke =>
          cases hTail : lowerExprList rest with
          | error _ => simp [hHead, hTail, bind, Except.bind] at h
          | ok krest =>
              simp [hHead, hTail, bind, Except.bind] at h
              simp [Expr.fragmentValidList]
              exact ⟨lowerExpr_ok_implies_fragmentValid e ke hHead,
                lowerExprList_ok_implies_fragmentValidList rest krest hTail⟩

end

/-- Statement-level reverse iff: `lowerStatement s` succeeds implies
`Statement.kernelLowerable s = true`. -/
theorem lowerStatement_ok_implies_kernelLowerable :
    ∀ (s : Statement) (ks : KernelStatement),
      lowerStatement s = .ok ks → Statement.kernelLowerable s = true
  | .declare name ty value, _, h => by
      unfold lowerStatement at h
      cases hV : lowerExpr value with
      | error _ => simp [hV, bind, Except.bind] at h
      | ok kv =>
          simp [hV, bind, Except.bind] at h
          simp [Statement.kernelLowerable]
          exact lowerExpr_ok_implies_fragmentValid value kv hV
  | .assign name value, _, h => by
      unfold lowerStatement at h
      cases hV : lowerExpr value with
      | error _ => simp [hV, bind, Except.bind] at h
      | ok kv =>
          simp [hV, bind, Except.bind] at h
          simp [Statement.kernelLowerable]
          exact lowerExpr_ok_implies_fragmentValid value kv hV
  | .require cond, _, h => by
      unfold lowerStatement at h
      cases hC : lowerExpr cond with
      | error _ => simp [hC, bind, Except.bind] at h
      | ok kc =>
          simp [hC, bind, Except.bind] at h
          simp [Statement.kernelLowerable]
          exact lowerExpr_ok_implies_fragmentValid cond kc hC
  | .abortIf cond, _, h => by
      unfold lowerStatement at h
      cases hC : lowerExpr cond with
      | error _ => simp [hC, bind, Except.bind] at h
      | ok kc =>
          simp [hC, bind, Except.bind] at h
          simp [Statement.kernelLowerable]
          exact lowerExpr_ok_implies_fragmentValid cond kc hC
  | .ifStmt _ _ _, _, h => by simp [lowerStatement] at h
  | .forLoop _ _ _ _ _, _, h => by simp [lowerStatement] at h
  | .cellSet id value pred, _, h => by
      unfold lowerStatement at h
      cases hV : lowerExpr value with
      | error _ => simp [hV, bind, Except.bind] at h
      | ok kv =>
          cases pred with
          | none =>
              simp [hV, bind, Except.bind] at h
              simp [Statement.kernelLowerable]
              exact lowerExpr_ok_implies_fragmentValid value kv hV
          | some p =>
              cases hP : lowerExpr p with
              | error _ => simp [hV, hP, bind, Except.bind] at h
              | ok kp =>
                  simp [hV, hP, bind, Except.bind] at h
                  simp [Statement.kernelLowerable]
                  exact ⟨lowerExpr_ok_implies_fragmentValid value kv hV,
                    lowerExpr_ok_implies_fragmentValid p kp hP⟩
  | .arraySet id index value pred, _, h => by
      unfold lowerStatement at h
      cases hI : lowerExpr index with
      | error _ => simp [hI, bind, Except.bind] at h
      | ok ki =>
          cases hV : lowerExpr value with
          | error _ => simp [hI, hV, bind, Except.bind] at h
          | ok kv =>
              cases pred with
              | none =>
                  simp [hI, hV, bind, Except.bind] at h
                  simp [Statement.kernelLowerable]
                  exact ⟨lowerExpr_ok_implies_fragmentValid index ki hI,
                    lowerExpr_ok_implies_fragmentValid value kv hV⟩
              | some p =>
                  cases hP : lowerExpr p with
                  | error _ => simp [hI, hV, hP, bind, Except.bind] at h
                  | ok kp =>
                      simp [hI, hV, hP, bind, Except.bind] at h
                      simp [Statement.kernelLowerable]
                      exact ⟨⟨lowerExpr_ok_implies_fragmentValid index ki hI,
                        lowerExpr_ok_implies_fragmentValid value kv hV⟩,
                        lowerExpr_ok_implies_fragmentValid p kp hP⟩
  | .mapPut id key value pred, _, h => by
      unfold lowerStatement at h
      cases hK : lowerExpr key with
      | error _ => simp [hK, bind, Except.bind] at h
      | ok kk =>
          cases hV : lowerExpr value with
          | error _ => simp [hK, hV, bind, Except.bind] at h
          | ok kv =>
              cases pred with
              | none =>
                  simp [hK, hV, bind, Except.bind] at h
                  simp [Statement.kernelLowerable]
                  exact ⟨lowerExpr_ok_implies_fragmentValid key kk hK,
                    lowerExpr_ok_implies_fragmentValid value kv hV⟩
              | some p =>
                  cases hP : lowerExpr p with
                  | error _ => simp [hK, hV, hP, bind, Except.bind] at h
                  | ok kp =>
                      simp [hK, hV, hP, bind, Except.bind] at h
                      simp [Statement.kernelLowerable]
                      exact ⟨⟨lowerExpr_ok_implies_fragmentValid key kk hK,
                        lowerExpr_ok_implies_fragmentValid value kv hV⟩,
                        lowerExpr_ok_implies_fragmentValid p kp hP⟩
  | .retStmt none, _, _ => rfl
  | .retStmt (some value), _, h => by
      unfold lowerStatement at h
      cases hV : lowerExpr value with
      | error _ => simp [hV, bind, Except.bind] at h
      | ok kv =>
          simp [hV, bind, Except.bind] at h
          simp [Statement.kernelLowerable]
          exact lowerExpr_ok_implies_fragmentValid value kv hV

/-- Schedule-level reverse iff. -/
theorem lowerStatementsAux_ok_implies_kernelLowerableScheduleAux :
    ∀ (stmts : List Statement) (index : Nat) (sawReturn : Bool)
      (ks : List KernelStatement),
      lowerStatementsAux stmts index sawReturn = .ok ks →
      Statement.kernelLowerableScheduleAux stmts sawReturn = true
  | [], _, _, _, _ => rfl
  | stmt :: rest, index, sawReturn, _, h => by
      unfold lowerStatementsAux at h
      cases sawReturn with
      | true => simp at h
      | false =>
          simp at h
          cases hS : lowerStatement stmt with
          | error _ => simp [hS, bind, Except.bind] at h
          | ok ks =>
              cases hRest : lowerStatementsAux rest (index + 1) stmt.isReturn with
              | error _ => simp [hS, hRest, bind, Except.bind] at h
              | ok krest =>
                  simp [Statement.kernelLowerableScheduleAux]
                  refine ⟨lowerStatement_ok_implies_kernelLowerable stmt ks hS, ?_⟩
                  exact lowerStatementsAux_ok_implies_kernelLowerableScheduleAux
                    rest (index + 1) stmt.isReturn krest hRest

theorem lowerStatements_ok_implies_kernelLowerableSchedule
    (stmts : List Statement) (ks : List KernelStatement)
    (h : lowerStatements stmts = .ok ks) :
    Statement.kernelLowerableSchedule stmts = true :=
  lowerStatementsAux_ok_implies_kernelLowerableScheduleAux stmts 0 false ks h

/-- Program-level reverse iff. -/
theorem lowerCompiledFunction_ok_implies_kernelLowerable
    (fn : CompiledFunction) (kp : KernelProgram)
    (h : lowerCompiledFunction fn = .ok kp) :
    CompiledFunction.kernelLowerable fn = true := by
  unfold lowerCompiledFunction at h
  cases hLowStmts : lowerStatements fn.body with
  | error _ => simp [hLowStmts, bind, Except.bind] at h
  | ok kbody =>
      simp [CompiledFunction.kernelLowerable]
      exact lowerStatements_ok_implies_kernelLowerableSchedule fn.body kbody hLowStmts

/-! ### W4.5: Status invariant for kernel expression evaluators

`evalKernelExpr` (and its companions) never return `.status .completed`:
every `.status` constructor in the evaluator uses an explicit
non-`.completed` status (`.evalError` or `.unsupported`), and
forwarded `.status` values from sub-expressions inherit the invariant
by induction. -/

private theorem EvalStatus_evalError_ne_completed (msg : String) :
    EvalStatus.evalError msg ≠ EvalStatus.completed := by
  intro h; cases h

mutual

theorem evalKernelExpr_status_ne_completed
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (e : KernelExpr) (s : EvalStatus),
      evalKernelExpr cfg env e = .status s → s ≠ .completed
  | .literal _, _, h => by simp [evalKernelExpr] at h
  | .var name, _, h => by
      unfold evalKernelExpr at h
      cases hLook : env.lookup name with
      | some v => rw [hLook] at h; simp at h
      | none =>
          rw [hLook] at h
          simp at h
          rw [← h]
          exact EvalStatus_evalError_ne_completed _
  | .unary op e', s, h => by
      unfold evalKernelExpr at h
      cases hRec : evalKernelExpr cfg env e' with
      | value v =>
          simp only [hRec] at h
          cases hOp : op.eval v with
          | some v' => simp [hOp] at h
          | none =>
              simp [hOp] at h
              rw [← h]
              exact EvalStatus_evalError_ne_completed _
      | status s' =>
          rw [hRec] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelExpr_status_ne_completed cfg env e' s' hRec
  | .binary op lhs rhs, s, h => by
      unfold evalKernelExpr at h
      cases hL : evalKernelExpr cfg env lhs with
      | status s' =>
          simp only [hL] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelExpr_status_ne_completed cfg env lhs s' hL
      | value lv =>
          simp only [hL] at h
          cases hR : evalKernelExpr cfg env rhs with
          | status s' =>
              simp only [hR] at h
              have heq : s' = s := by injection h
              rw [← heq]
              exact evalKernelExpr_status_ne_completed cfg env rhs s' hR
          | value rv =>
              simp only [hR] at h
              cases hOp : op.eval lv rv with
              | some v => simp [hOp] at h
              | none =>
                  simp [hOp] at h
                  rw [← h]
                  exact EvalStatus_evalError_ne_completed _
  | .select cond wt wf, s, h => by
      unfold evalKernelExpr at h
      cases hC : evalKernelExpr cfg env cond with
      | status s' =>
          simp only [hC] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelExpr_status_ne_completed cfg env cond s' hC
      | value cv =>
          simp only [hC] at h
          cases cv with
          | bool b =>
              cases b with
              | true =>
                  simp at h
                  exact evalKernelPureExpr_status_ne_completed cfg env wt s h
              | false =>
                  simp at h
                  exact evalKernelPureExpr_status_ne_completed cfg env wf s h
          | uint _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | bytes32 _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | address _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | structValue _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | array _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | map _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .cellGet objectId, _, h => by
      unfold evalKernelExpr at h
      cases hRead : cfg.readObject objectId with
      | some v => simp only [hRead] at h; cases h
      | none =>
          simp only [hRead] at h
          simp at h
          rw [← h]
          exact EvalStatus_evalError_ne_completed _
  | .arrayGet objectId indexExpr, s, h => by
      unfold evalKernelExpr at h
      cases hI : evalKernelExpr cfg env indexExpr with
      | status s' =>
          simp [hI] at h
          have hRec := evalKernelExpr_status_ne_completed cfg env indexExpr s' hI
          cases h
          exact hRec
      | value iv =>
          simp [hI] at h
          cases iv with
          | uint idx =>
              cases hObj : cfg.stateObjectById? objectId with
              | none =>
                  simp [hObj] at h
                  cases h
                  exact EvalStatus_evalError_ne_completed _
              | some object =>
                  simp [hObj] at h
                  cases hRead : cfg.readObject objectId with
                  | none =>
                      simp [hRead] at h
                      by_cases hKind : object.kind = .arrayKind
                      · simp [hKind] at h
                      · simp [hKind] at h
                        cases h
                        exact EvalStatus_evalError_ne_completed _
                  | some objVal =>
                      cases objVal with
                      | bool _ =>
                          simp [hRead] at h
                          cases h
                          exact EvalStatus_evalError_ne_completed _
                      | uint _ =>
                          simp [hRead] at h
                          cases h
                          exact EvalStatus_evalError_ne_completed _
                      | bytes32 _ =>
                          simp [hRead] at h
                          cases h
                          exact EvalStatus_evalError_ne_completed _
                      | address _ =>
                          simp [hRead] at h
                          cases h
                          exact EvalStatus_evalError_ne_completed _
                      | structValue _ =>
                          simp [hRead] at h
                          cases h
                          exact EvalStatus_evalError_ne_completed _
                      | array values =>
                          simp [hRead, Value.arrayGetD] at h
                      | map _ =>
                          simp [hRead] at h
                          cases h
                          exact EvalStatus_evalError_ne_completed _
          | bool _ => simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | bytes32 _ => simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | address _ => simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | structValue _ => simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | array _ => simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | map _ => simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .mapGet objectId keyExpr, s, h => by
      unfold evalKernelExpr at h
      cases hK : evalKernelExpr cfg env keyExpr with
      | status s' =>
          simp [hK] at h
          have hRec := evalKernelExpr_status_ne_completed cfg env keyExpr s' hK
          cases h
          exact hRec
      | value kv =>
          simp [hK] at h
          cases hObj : cfg.stateObjectById? objectId with
          | none =>
              simp [hObj] at h
              cases h
              exact EvalStatus_evalError_ne_completed _
          | some object =>
              simp [hObj] at h
              cases hRead : cfg.readObject objectId with
              | none =>
                  simp [hRead] at h
                  by_cases hKind : object.kind = .mapKind
                  · simp [hKind] at h
                  · simp [hKind] at h
                    cases h
                    exact EvalStatus_evalError_ne_completed _
              | some objVal =>
                  cases objVal with
                  | bool _ =>
                      simp [hRead] at h
                      cases h
                      exact EvalStatus_evalError_ne_completed _
                  | uint _ =>
                      simp [hRead] at h
                      cases h
                      exact EvalStatus_evalError_ne_completed _
                  | bytes32 _ =>
                      simp [hRead] at h
                      cases h
                      exact EvalStatus_evalError_ne_completed _
                  | address _ =>
                      simp [hRead] at h
                      cases h
                      exact EvalStatus_evalError_ne_completed _
                  | structValue _ =>
                      simp [hRead] at h
                      cases h
                      exact EvalStatus_evalError_ne_completed _
                  | array _ =>
                      simp [hRead] at h
                      cases h
                      exact EvalStatus_evalError_ne_completed _
                  | map entries =>
                      simp [hRead, Value.mapLookupD] at h
  | .structField base field, s, h => by
      unfold evalKernelExpr at h
      cases hB : evalKernelExpr cfg env base with
        | status s' =>
            simp only [hB] at h
            have heq : s' = s := by injection h
            rw [← heq]
            exact evalKernelExpr_status_ne_completed cfg env base s' hB
        | value bv =>
            simp only [hB] at h
            cases bv with
            | structValue fields =>
                cases hField : Value.structField? fields field with
                | some value => simp [hField] at h
                | none =>
                    simp [hField] at h
                    rw [← h]
                    exact EvalStatus_evalError_ne_completed _
            | bool _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | uint _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | bytes32 _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | address _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | array _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | map _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .arrayIndex base indexExpr, s, h => by
      unfold evalKernelExpr at h
      cases hB : evalKernelExpr cfg env base with
        | status s' =>
            simp only [hB] at h
            have heq : s' = s := by injection h
            rw [← heq]
            exact evalKernelExpr_status_ne_completed cfg env base s' hB
        | value bv =>
            simp only [hB] at h
            cases bv with
            | array values =>
                cases hI : evalKernelExpr cfg env indexExpr with
                | status s' =>
                    simp [hI] at h
                    rw [← h]
                    exact evalKernelExpr_status_ne_completed cfg env indexExpr s' hI
                | value iv =>
                    simp [hI] at h
                    cases iv with
                    | uint idx =>
                        cases hValue : Value.arrayIndex? values idx with
                        | some value => simp [hValue] at h
                        | none =>
                            simp [hValue] at h
                            rw [← h]
                            exact EvalStatus_evalError_ne_completed _
                    | bool _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | bytes32 _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | address _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | structValue _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | array _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | map _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | bool _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | uint _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | bytes32 _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | address _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | structValue _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | map _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .keccak256 parts, s, h => by
      unfold evalKernelExpr at h
      cases hList : evalKernelExprList cfg env parts with
      | error s' =>
          rw [hList] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelExprList_status_ne_completed cfg env parts s' hList
      | ok vs => rw [hList] at h; simp at h

theorem evalKernelExprList_status_ne_completed
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (es : List KernelExpr) (s : EvalStatus),
      evalKernelExprList cfg env es = .error s → s ≠ .completed
  | [], _, h => by simp [evalKernelExprList] at h
  | e :: rest, s, h => by
      unfold evalKernelExprList at h
      cases hHead : evalKernelExpr cfg env e with
      | status s' =>
          rw [hHead] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelExpr_status_ne_completed cfg env e s' hHead
      | value v =>
          rw [hHead] at h
          cases hTail : evalKernelExprList cfg env rest with
          | ok vs => rw [hTail] at h; simp at h
          | error s' =>
              rw [hTail] at h
              have heq : s' = s := by injection h
              rw [← heq]
              exact evalKernelExprList_status_ne_completed cfg env rest s' hTail

theorem evalKernelPureExpr_status_ne_completed
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (e : KernelPureExpr) (s : EvalStatus),
      evalKernelPureExpr cfg env e = .status s → s ≠ .completed
  | .literal _, _, h => by simp [evalKernelPureExpr] at h
  | .var name, _, h => by
      unfold evalKernelPureExpr at h
      cases hLook : env.lookup name with
      | some v => rw [hLook] at h; simp at h
      | none =>
          rw [hLook] at h
          simp at h
          rw [← h]
          exact EvalStatus_evalError_ne_completed _
  | .unary op e', s, h => by
      unfold evalKernelPureExpr at h
      cases hRec : evalKernelPureExpr cfg env e' with
      | value v =>
          simp only [hRec] at h
          cases hOp : op.eval v with
          | some v' => simp [hOp] at h
          | none =>
              simp [hOp] at h
              rw [← h]
              exact EvalStatus_evalError_ne_completed _
      | status s' =>
          rw [hRec] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelPureExpr_status_ne_completed cfg env e' s' hRec
  | .binary op lhs rhs, s, h => by
      unfold evalKernelPureExpr at h
      cases hL : evalKernelPureExpr cfg env lhs with
      | status s' =>
          rw [hL] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelPureExpr_status_ne_completed cfg env lhs s' hL
      | value lv =>
          simp only [hL] at h
          cases hR : evalKernelPureExpr cfg env rhs with
          | status s' =>
              simp only [hR] at h
              have heq : s' = s := by injection h
              rw [← heq]
              exact evalKernelPureExpr_status_ne_completed cfg env rhs s' hR
          | value rv =>
              simp only [hR] at h
              cases hOp : op.eval lv rv with
              | some v => simp [hOp] at h
              | none =>
                  simp [hOp] at h
                  rw [← h]
                  exact EvalStatus_evalError_ne_completed _
  | .select cond wt wf, s, h => by
      unfold evalKernelPureExpr at h
      cases hC : evalKernelPureExpr cfg env cond with
      | status s' =>
          rw [hC] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelPureExpr_status_ne_completed cfg env cond s' hC
      | value cv =>
          rw [hC] at h
          cases cv with
          | bool b =>
              cases b with
              | true =>
                  simp at h
                  exact evalKernelPureExpr_status_ne_completed cfg env wt s h
              | false =>
                  simp at h
                  exact evalKernelPureExpr_status_ne_completed cfg env wf s h
          | uint _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | bytes32 _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | address _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | structValue _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | array _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
          | map _ =>
              simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .structField base field, s, h => by
      unfold evalKernelPureExpr at h
      cases hB : evalKernelPureExpr cfg env base with
        | status s' =>
            rw [hB] at h
            have heq : s' = s := by injection h
            rw [← heq]
            exact evalKernelPureExpr_status_ne_completed cfg env base s' hB
        | value bv =>
            rw [hB] at h
            cases bv with
            | structValue fields =>
                cases hField : Value.structField? fields field with
                | some value => simp [hField] at h
                | none =>
                    simp [hField] at h
                    rw [← h]
                    exact EvalStatus_evalError_ne_completed _
            | bool _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | uint _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | bytes32 _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | address _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | array _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | map _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .arrayIndex base indexExpr, s, h => by
      unfold evalKernelPureExpr at h
      cases hB : evalKernelPureExpr cfg env base with
        | status s' =>
            rw [hB] at h
            have heq : s' = s := by injection h
            rw [← heq]
            exact evalKernelPureExpr_status_ne_completed cfg env base s' hB
        | value bv =>
            rw [hB] at h
            cases bv with
            | array values =>
                cases hI : evalKernelPureExpr cfg env indexExpr with
                | status s' =>
                    simp [hI] at h
                    rw [← h]
                    exact evalKernelPureExpr_status_ne_completed cfg env indexExpr s' hI
                | value iv =>
                    simp [hI] at h
                    cases iv with
                    | uint idx =>
                        cases hValue : Value.arrayIndex? values idx with
                        | some value => simp [hValue] at h
                        | none =>
                            simp [hValue] at h
                            rw [← h]
                            exact EvalStatus_evalError_ne_completed _
                    | bool _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | bytes32 _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | address _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | structValue _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | array _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
                    | map _ =>
                        simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | bool _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | uint _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | bytes32 _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | address _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | structValue _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
            | map _ =>
                simp at h; rw [← h]; exact EvalStatus_evalError_ne_completed _
  | .keccak256 parts, s, h => by
      unfold evalKernelPureExpr at h
      cases hList : evalKernelPureExprList cfg env parts with
      | error s' =>
          rw [hList] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelPureExprList_status_ne_completed cfg env parts s' hList
      | ok vs => rw [hList] at h; simp at h

theorem evalKernelPureExprList_status_ne_completed
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (es : List KernelPureExpr) (s : EvalStatus),
      evalKernelPureExprList cfg env es = .error s → s ≠ .completed
  | [], _, h => by simp [evalKernelPureExprList] at h
  | e :: rest, s, h => by
      unfold evalKernelPureExprList at h
      cases hHead : evalKernelPureExpr cfg env e with
      | status s' =>
          rw [hHead] at h
          have heq : s' = s := by injection h
          rw [← heq]
          exact evalKernelPureExpr_status_ne_completed cfg env e s' hHead
      | value v =>
          rw [hHead] at h
          cases hTail : evalKernelPureExprList cfg env rest with
          | ok vs => rw [hTail] at h; simp at h
          | error s' =>
              rw [hTail] at h
              have heq : s' = s := by injection h
              rw [← heq]
              exact evalKernelPureExprList_status_ne_completed cfg env rest s' hTail

end

/-! ### W4.5: Per-statement runtime-vs-static `kernelSteps` lift

With the `evalKernelExpr_status_ne_completed` invariant in hand, the
per-statement runtime-vs-static `kernelSteps` lift becomes provable
under the natural `.completed` + `publicResult preserved` preconditions:
the resulting outcome's `kernelSteps` is exactly `oc.kernelSteps ++
stmt.expectedStep`. -/

theorem evalKernelStatement_kernelSteps_eq_expected_of_completed
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome)
    (stmt : KernelStatement)
    (hStatus : (evalKernelStatement cfg env oc stmt).snd.snd.status = .completed)
    (hPub : (evalKernelStatement cfg env oc stmt).snd.snd.publicResult =
      oc.publicResult) :
    (evalKernelStatement cfg env oc stmt).snd.snd.kernelSteps =
      oc.kernelSteps ++ stmt.expectedStep := by
  cases stmt with
  | declare name ty value =>
      simp only [evalKernelStatement, KernelStatement.expectedStep,
        List.append_nil] at *
      cases hVal : evalKernelExpr cfg env value with
      | value v => simp
      | status s =>
          simp [hVal] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env value s hVal)
  | assign name value =>
      simp only [evalKernelStatement, KernelStatement.expectedStep,
        List.append_nil] at *
      cases hVal : evalKernelExpr cfg env value with
      | value v => simp
      | status s =>
          simp [hVal] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env value s hVal)
  | require cond =>
      simp only [evalKernelStatement, KernelStatement.expectedStep,
        List.append_nil] at *
      cases hCond : evalKernelExpr cfg env cond with
      | value v =>
          cases v with
          | bool b =>
              cases b with
              | true => simp
              | false => simp [hCond] at hStatus
          | _ => simp [hCond] at hStatus
      | status s =>
          simp [hCond] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env cond s hCond)
  | abortIf cond =>
      simp only [evalKernelStatement, KernelStatement.expectedStep,
        List.append_nil] at *
      cases hCond : evalKernelExpr cfg env cond with
      | value v =>
          cases v with
          | bool b =>
              cases b with
              | true => simp [hCond] at hStatus
              | false => simp
          | _ => simp [hCond] at hStatus
      | status s =>
          simp [hCond] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env cond s hCond)
  | retStmt val =>
      cases val with
      | none =>
          simp only [evalKernelStatement, KernelStatement.expectedStep,
            List.append_nil] at *
      | some value =>
          simp only [evalKernelStatement, KernelStatement.expectedStep,
            List.append_nil] at *
          cases hVal : evalKernelExpr cfg env value with
          | value v => simp
          | status s =>
              simp [hVal] at hStatus
              exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env value s hVal)
  | cellSet objectId value predicate =>
      simp only [evalKernelStatement, KernelStatement.expectedStep] at *
      cases hVal : evalKernelExpr cfg env value with
      | status s =>
          simp [hVal] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env value s hVal)
      | value newVal =>
          cases predicate with
          | none =>
              cases hWrite : cfg.writeObject? objectId newVal with
              | none => simp [hVal, hWrite] at hStatus
              | some cfg' => simp [hWrite]
          | some predExpr =>
              cases hPred : evalKernelExpr cfg env predExpr with
              | status s =>
                  simp [hVal, hPred] at hStatus
                  exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env predExpr s hPred)
              | value pv =>
                  cases pv with
                  | bool b =>
                      cases b
                      · simp [hPred]
                      · cases hWrite : cfg.writeObject? objectId newVal with
                        | none => simp [hVal, hPred, hWrite] at hStatus
                        | some cfg' => simp [hPred, hWrite]
                  | _ => simp [hVal, hPred] at hStatus
  | arraySet objectId index value predicate =>
      simp only [evalKernelStatement, KernelStatement.expectedStep] at *
      cases hIdx : evalKernelExpr cfg env index with
      | status s =>
          simp [hIdx] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env index s hIdx)
      | value indexVal =>
          cases hVal : evalKernelExpr cfg env value with
          | status s =>
              simp [hIdx, hVal] at hStatus
              exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env value s hVal)
          | value newVal =>
              cases predicate with
              | none =>
                  cases indexVal with
                  | uint idx =>
                      cases hRead : cfg.readObject objectId with
                      | none => simp [hIdx, hVal, hRead] at hStatus
                      | some objVal =>
                          cases objVal with
                          | array values =>
                              by_cases hOob : values[idx]? = none
                              · simp [hOob]
                              · cases hWrite :
                                    cfg.writeObject? objectId
                                      (Value.array (Value.arraySetAt values idx newVal)) with
                                | none => simp [hIdx, hVal, hRead, hOob, hWrite] at hStatus
                                | some cfg' => simp [hOob, hWrite]
                          | _ => simp [hIdx, hVal, hRead] at hStatus
                  | _ => simp [hIdx, hVal] at hStatus
              | some predExpr =>
                  cases hPred : evalKernelExpr cfg env predExpr with
                  | status s =>
                      simp [hIdx, hVal, hPred] at hStatus
                      exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env predExpr s hPred)
                  | value pv =>
                      cases pv with
                      | bool b =>
                          cases b
                          · simp [hPred]
                          · cases indexVal with
                            | uint idx =>
                                cases hRead : cfg.readObject objectId with
                                | none => simp [hIdx, hVal, hPred, hRead] at hStatus
                                | some objVal =>
                                    cases objVal with
                                    | array values =>
                                        by_cases hOob : values[idx]? = none
                                        · simp [hPred, hOob]
                                        · cases hWrite :
                                              cfg.writeObject? objectId
                                                (Value.array (Value.arraySetAt values idx newVal)) with
                                          | none =>
                                              simp [hIdx, hVal, hPred, hRead, hOob, hWrite] at hStatus
                                          | some cfg' => simp [hPred, hOob, hWrite]
                                    | _ => simp [hIdx, hVal, hPred, hRead] at hStatus
                            | _ => simp [hIdx, hVal, hPred] at hStatus
                      | _ => simp [hIdx, hVal, hPred] at hStatus
  | mapPut objectId key value predicate =>
      simp only [evalKernelStatement, KernelStatement.expectedStep] at *
      cases hKey : evalKernelExpr cfg env key with
      | status s =>
          simp [hKey] at hStatus
          exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env key s hKey)
      | value keyVal =>
          cases hVal : evalKernelExpr cfg env value with
          | status s =>
              simp [hKey, hVal] at hStatus
              exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env value s hVal)
          | value newVal =>
              cases predicate with
              | none =>
                  cases hObj : cfg.stateObjectById? objectId with
                  | none =>
                      simp [hKey, hVal, hObj] at hStatus
                  | some object =>
                      cases hRead : cfg.readObject objectId with
                      | none =>
                          by_cases hKind : object.kind = .mapKind
                          · cases hOverflow :
                                (Value.mapInsertBounded [] keyVal newVal object.capacity).overflowed
                            · cases hWrite :
                                  cfg.writeObject? objectId
                                    (Value.map
                                      (Value.mapInsertBounded [] keyVal newVal object.capacity).entries) with
                              | none =>
                                  simp [hKey, hVal, hObj, hRead, hKind, hOverflow, hWrite] at hStatus
                              | some cfg' =>
                                  simp [hKind, hOverflow, hWrite]
                            · simp [hKey, hVal, hObj, hRead, hKind, hOverflow] at hStatus
                          · simp [hKey, hVal, hObj, hRead, hKind] at hStatus
                      | some objVal =>
                          cases objVal with
                          | map entries =>
                              cases hOverflow :
                                  (Value.mapInsertBounded entries keyVal newVal object.capacity).overflowed
                              · cases hWrite :
                                    cfg.writeObject? objectId
                                      (Value.map
                                        (Value.mapInsertBounded entries keyVal newVal object.capacity).entries) with
                                | none =>
                                    simp [hKey, hVal, hObj, hRead, hOverflow, hWrite] at hStatus
                                | some cfg' =>
                                    simp [hOverflow, hWrite]
                              · simp [hKey, hVal, hObj, hRead, hOverflow] at hStatus
                          | _ => simp [hKey, hVal, hObj, hRead] at hStatus
              | some predExpr =>
                  cases hPred : evalKernelExpr cfg env predExpr with
                  | status s =>
                      simp [hKey, hVal, hPred] at hStatus
                      exact absurd hStatus (evalKernelExpr_status_ne_completed cfg env predExpr s hPred)
                  | value pv =>
                      cases pv with
                      | bool b =>
                          cases b
                          · simp [hPred]
                          · cases hObj : cfg.stateObjectById? objectId with
                            | none =>
                                simp [hKey, hVal, hPred, hObj] at hStatus
                            | some object =>
                                cases hRead : cfg.readObject objectId with
                                | none =>
                                    by_cases hKind : object.kind = .mapKind
                                    · cases hOverflow :
                                          (Value.mapInsertBounded [] keyVal newVal object.capacity).overflowed
                                      · cases hWrite :
                                            cfg.writeObject? objectId
                                              (Value.map
                                                (Value.mapInsertBounded [] keyVal newVal object.capacity).entries) with
                                        | none =>
                                            simp [hKey, hVal, hPred, hObj, hRead, hKind,
                                              hOverflow, hWrite] at hStatus
                                        | some cfg' =>
                                            simp [hPred, hKind, hOverflow, hWrite]
                                      · simp [hKey, hVal, hPred, hObj, hRead, hKind,
                                          hOverflow] at hStatus
                                    · simp [hKey, hVal, hPred, hObj, hRead, hKind] at hStatus
                                | some objVal =>
                                    cases objVal with
                                    | map entries =>
                                        cases hOverflow :
                                            (Value.mapInsertBounded entries keyVal newVal object.capacity).overflowed
                                        · cases hWrite :
                                              cfg.writeObject? objectId
                                                (Value.map
                                                  (Value.mapInsertBounded entries keyVal newVal object.capacity).entries) with
                                          | none =>
                                              simp [hKey, hVal, hPred, hObj, hRead, hOverflow,
                                                hWrite] at hStatus
                                          | some cfg' =>
                                              simp [hPred, hOverflow, hWrite]
                                        · simp [hKey, hVal, hPred, hObj, hRead, hOverflow] at hStatus
                                    | _ => simp [hKey, hVal, hPred, hObj, hRead] at hStatus
                      | _ => simp [hKey, hVal, hPred] at hStatus

/-! ### W4.5: Body-level runtime-vs-static `kernelSteps` lift

`evalKernelBody_kernelSteps_eq_expected_of_completed` lifts the
per-statement theorem through `evalKernelBody`: under `.completed`
final status AND `oc.publicResult = none` AND
`(evalKernelBody _).snd.snd.publicResult = none` (i.e., no early
`retStmt (some _)` fired during the body), the runtime
`kernelSteps` is `oc.kernelSteps ++ body.flatMap
KernelStatement.expectedStep`.

The strong precondition `oc.publicResult = none` rules out the
pathological case where the input outcome already had a return
value set; the program-level theorem
(`evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_completed`)
discharges this precondition by starting from `Outcome.empty`. -/

theorem evalKernelBody_kernelSteps_eq_expected_of_completed
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome)
    (hOcPub : oc.publicResult = none) :
    ∀ (body : List KernelStatement),
      (evalKernelBody cfg env oc body).snd.snd.status = .completed →
      (evalKernelBody cfg env oc body).snd.snd.publicResult = none →
      (evalKernelBody cfg env oc body).snd.snd.kernelSteps =
        oc.kernelSteps ++ body.flatMap KernelStatement.expectedStep
  | [], _, _ => by simp [evalKernelBody]
  | stmt :: rest, hStatus, hPub => by
      simp only [evalKernelBody] at hStatus hPub ⊢
      generalize hStep : evalKernelStatement cfg env oc stmt = step at *
      obtain ⟨cfg', env', oc'⟩ := step
      simp only at hStatus hPub ⊢
      cases hSt' : oc'.status with
      | completed =>
          simp only [hSt'] at hStatus hPub ⊢
          by_cases hRet : oc'.publicResult.isSome
          · -- Early return: body returns oc' immediately. We have
            -- hPub : oc'.publicResult = none, but hRet : oc'.publicResult.isSome.
            -- Contradiction.
            simp only [hRet, if_true] at hStatus hPub ⊢
            rw [hPub] at hRet
            exact absurd hRet (by simp)
          · -- oc'.publicResult must be `none` (from hRet : ¬ isSome)
            have hOcPubNone : oc'.publicResult = none := by
              cases hOPR : oc'.publicResult with
              | none => rfl
              | some v => rw [hOPR] at hRet; exact absurd (by simp) hRet
            simp only [hOcPubNone, Option.isSome_none, Bool.false_eq_true,
              if_false] at hStatus hPub ⊢
            have h1 : (evalKernelStatement cfg env oc stmt).snd.snd.status = .completed := by
              rw [hStep]; exact hSt'
            have h2 : (evalKernelStatement cfg env oc stmt).snd.snd.publicResult =
              oc.publicResult := by
              rw [hStep, hOcPubNone, hOcPub]
            have hKsEqStmt := evalKernelStatement_kernelSteps_eq_expected_of_completed
              cfg env oc stmt h1 h2
            rw [hStep] at hKsEqStmt
            simp only at hKsEqStmt
            have hKsEqRest := evalKernelBody_kernelSteps_eq_expected_of_completed
              cfg' env' oc' hOcPubNone rest hStatus hPub
            rw [hKsEqRest, hKsEqStmt]
            simp [List.flatMap, List.append_assoc]
      | requireFailed => simp only [hSt'] at hStatus; cases hStatus
      | abortedByUser => simp only [hSt'] at hStatus; cases hStatus
      | capacityOverflow => simp only [hSt'] at hStatus; cases hStatus
      | unsupported _ => simp only [hSt'] at hStatus; cases hStatus
      | evalError _ => simp only [hSt'] at hStatus; cases hStatus

/-! ### W4.5: Program-level runtime-vs-static `kernelSteps` lift

The program-level theorem
`evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_completed`
discharges the body-level theorem's `oc.publicResult = none`
precondition by starting from `Outcome.empty` (which has
`publicResult = none`). The result: when `evalKernelProgram kp cfg`
produces a fully-completed outcome (no error, no early return), its
`kernelSteps` equals `kp.expectedKernelSteps`. -/

theorem evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_completed
    (kp : KernelProgram) (cfg : OperationalConfig)
    (hStatus : (evalKernelProgram kp cfg).status = .completed)
    (hPub : (evalKernelProgram kp cfg).publicResult = none) :
    (evalKernelProgram kp cfg).kernelSteps = kp.expectedKernelSteps := by
  unfold evalKernelProgram at hStatus hPub ⊢
  cases hEnv : kp.initialEnv cfg.declaredArgs with
  | none =>
      simp [hEnv, Outcome.withPublicStateTransition, Outcome.toPublicStateTransition,
        Outcome.committedPublicState, EvalStatus.commitsCandidate] at hStatus
  | some env =>
      simp only [hEnv] at hStatus hPub ⊢
      simp [Outcome.withPublicStateTransition] at hStatus hPub ⊢
      have hOcPub : (Outcome.empty : Outcome).publicResult = none := rfl
      have hBodyEq := evalKernelBody_kernelSteps_eq_expected_of_completed
        cfg env Outcome.empty hOcPub kp.body hStatus hPub
      simp only [KernelProgram.expectedKernelSteps]
      have hOcKs : (Outcome.empty : Outcome).kernelSteps = [] := rfl
      rw [hOcKs] at hBodyEq
      simp at hBodyEq
      exact hBodyEq

end UOToolchain.IR
