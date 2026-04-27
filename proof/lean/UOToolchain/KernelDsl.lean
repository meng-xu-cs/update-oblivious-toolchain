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
      match evalKernelExpr cfg env keyExpr with
      | .status s => .status s
      | .value keyVal =>
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
              (cfg.writeObject objectId newVal, env, oc')
          | some predExpr =>
              match evalKernelExpr cfg env predExpr with
              | .status s => (cfg, env, { oc with status := s })
              | .value (.bool true) =>
                  (cfg.writeObject objectId newVal, env, oc')
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
                  match cfg.readObject objectId with
                  | some (.map entries) =>
                      let updated := Value.map (Value.mapInsert entries keyVal newVal)
                      (cfg.writeObject objectId updated, env, oc')
                  | some _ =>
                      let msg := s!"mapPut on non-map object {objectId}"
                      (cfg, env, { oc with status := .evalError msg })
                  | none =>
                      let updated := Value.map [(keyVal, newVal)]
                      (cfg.writeObject objectId updated, env, oc')
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
    (publicArgs secretArgs : List Value) : Option LocalEnv :=
  let allArgs := publicArgs ++ secretArgs
  if allArgs.length = kp.params.length then
    some <| (kp.params.zip allArgs).foldl
      (fun env entry => env.insert entry.fst.name entry.snd) []
  else
    none

/-- Big-step program evaluator: bind the entrypoint arguments and walk
the body using `evalKernelBody`. Discards the final config / env, like
`evalContract`. -/
def evalKernelProgram (kp : KernelProgram) (cfg : OperationalConfig) : Outcome :=
  match kp.initialEnv cfg.publicArgs cfg.secretArgs with
  | none =>
      { Outcome.empty with status := .evalError "argument arity mismatch" }
  | some env =>
      let (_cfg', _env', outcome) := evalKernelBody cfg env Outcome.empty kp.body
      outcome

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
  | .structField _ _ => .error .confidentialStructField
  | .arrayIndex _ _ => .error .confidentialArrayIndex
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
  | .structField _ _ => .error .confidentialStructField
  | .arrayIndex _ _ => .error .confidentialArrayIndex
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
  | .structField _ _, h => by simp [branchlessPureExpr] at h
  | .arrayIndex _ _, h => by simp [branchlessPureExpr] at h
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
  | .structField _ _, h => by simp [Expr.fragmentValid] at h
  | .arrayIndex _ _, h => by simp [Expr.fragmentValid] at h
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
  | .structField _ _, _, h => by simp [lowerExpr] at h
  | .arrayIndex _ _, _, h => by simp [lowerExpr] at h
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
  | .structField _ _, _, h => by simp [lowerPureExpr] at h
  | .arrayIndex _ _, _, h => by simp [lowerPureExpr] at h
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
  | .structField _ _, h => by simp [branchlessPureExpr] at h
  | .arrayIndex _ _, h => by simp [branchlessPureExpr] at h
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

end UOToolchain.IR
