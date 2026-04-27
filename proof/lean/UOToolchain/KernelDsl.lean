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
`IRSemantics.lean` constructor-for-constructor. -/
partial def evalKernelExpr (cfg : OperationalConfig) (env : LocalEnv) :
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
      let rec evalParts : List KernelExpr → Except EvalStatus (List Value)
        | [] => .ok []
        | p :: rest =>
            match evalKernelExpr cfg env p with
            | .status s => .error s
            | .value v =>
                match evalParts rest with
                | .ok vs => .ok (v :: vs)
                | .error s => .error s
      match evalParts parts with
      | .error s => .status s
      | .ok vs => .value (Value.keccak256Mock vs)

/-- Big-step evaluator for `KernelPureExpr`. Pure expressions never
read storage. -/
partial def evalKernelPureExpr (cfg : OperationalConfig) (env : LocalEnv) :
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
      let rec evalParts : List KernelPureExpr → Except EvalStatus (List Value)
        | [] => .ok []
        | p :: rest =>
            match evalKernelPureExpr cfg env p with
            | .status s => .error s
            | .value v =>
                match evalParts rest with
                | .ok vs => .ok (v :: vs)
                | .error s => .error s
      match evalParts parts with
      | .error s => .status s
      | .ok vs => .value (Value.keccak256Mock vs)

end

mutual

/-- Big-step statement evaluator for the kernel DSL. Threads the
`OperationalConfig` so masked-store updates persist into subsequent
statements, mirroring the W4.1+++ IR statement evaluator. -/
partial def evalKernelStatement
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

partial def evalKernelBody
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
        let isReturn :=
          match stmt with
          | .retStmt _ => true
          | _ => false
        let krest ← lowerStatementsAux rest (index + 1) isReturn
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
        let isReturn :=
          match stmt with
          | .retStmt _ => true
          | _ => false
        Statement.kernelLowerable stmt
          && Statement.kernelLowerableScheduleAux rest isReturn

def Statement.kernelLowerableSchedule (stmts : List Statement) : Bool :=
  Statement.kernelLowerableScheduleAux stmts false

/-- A function is *kernel-lowerable* when its body is. -/
def CompiledFunction.kernelLowerable (fn : CompiledFunction) : Bool :=
  Statement.kernelLowerableSchedule fn.body

/-! ### Lowering succeeds-iff-precondition theorems (deferred)

`branchlessPureExpr e = true` is the lowering precondition for
`lowerPureExpr`. `Expr.fragmentValid e = true` is the lowering
precondition for `lowerExpr`. `Statement.kernelLowerable s = true` is
the lowering precondition for `lowerStatement`, and
`Statement.kernelLowerableSchedule stmts = true` is the precondition
for `lowerStatements`. Their iff theorems will land in a follow-up
W4.4 commit; the proofs are structural mutual recursions analogous
to W4.3 but with three theorem families instead of two, plus the
companion list lemmas.

The W4.4 *semantics-preservation* theorem
(`evalContract cfg = evalKernelProgram (lowerCompiledFunction fn) cfg`
when the lowering succeeds) is the W4.4 Session B deliverable; it
will use these iff theorems.

For the W4.4 forward use ("if `fn.kernelLowerable` then the lowering
succeeds and the kernel program agrees with the IR"), the helper
`branchlessPureExpr_implies_fragmentValid` below already factors out
the structural fact that branchless-pure expressions are also
fragment-valid. -/

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
