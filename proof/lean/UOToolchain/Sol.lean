import UOToolchain.IRSyntax
import UOToolchain.IRSemantics
import UOToolchain.ConfidentialFragment
import UOToolchain.KernelDsl

/-!
# W4.2: Solidity AST mirror, operational semantics, and AST-to-IR lowering

This module is the WP4 W4.2 deliverable: a typed Lean mirror of the
admitted Solidity AST surface that `uo-solc` lowers from
`solang_parser::pt::Statement` / `pt::Expression`, together with an
operational semantics for that surface and a lowering function plus
preservation theorem connecting the AST semantics to the IR semantics
(W4.1 evaluator).

## Scope

This commit covers the **structural fragment** of the admitted
Solidity subset — the constructors that lower constructor-for-
constructor to IR with no context-dependent rewriting:

- Literals (bool, uint, address)
- Variable reference
- Unary operators (`!`, `-`)
- Binary operators (the 16 IR `BinaryOp`s)
- Conditional expression (`?:` → `IR.Expr.select`)
- Keccak256 (the structural form, without the
  `abi.encodePacked` wrapper)
- Statements: declare, assign-to-local, require, if/else, for,
  return

The **context-dependent fragment** (where uo-solc's lowering depends
on the state-object table or on identifier resolution) is deferred
to a follow-up commit. It includes:

- `ArraySubscript base index` → `IR.ArrayGet` / `IR.MapGet` /
  `IR.ArrayIndex` depending on whether `base` is an array/map state
  variable.
- `MemberAccess base ".length"` → `IR.Literal length` when `base`
  is a state with declared capacity.
- `Assign lhs rhs` where `lhs` is a state variable → `IR.CellSet` /
  `IR.ArraySet` / `IR.MapPut`.
- `FunctionCall keccak256 (abi.encodePacked args)` → `IR.Keccak256
  args` (the structural `Sol.Expr.keccak256 args` form skips the
  outer ABI wrapping; the deferred follow-up adds the wrapper).
- Helper-function inlining via `ctx.frontend.helpers`.

The structural fragment is the cleanest piece of the W4.2 charter
deliverable: each Sol constructor maps directly to one IR
constructor with the same name and arity, so the preservation
theorem is provable by direct structural induction with `rfl` /
`unfold + rw [ih]` patterns mirroring the W4.4 Session B-2 proofs.

## Why a separate AST mirror?

The W4.2 charter task requires a Lean-side semantics for the
admitted Solidity subset, distinct from the IR. Without it, the
"source-to-IR correctness" theorem has no source-side semantic
referent. This module provides the source-side referent at the
typed-AST level (the `solang_parser::pt` parser is treated as a
trusted parser step that produces values of these inductives).
-/

namespace UOToolchain.Sol

/-! ## Sol.Expr -/

/-- Mirror of the structural admitted subset of
`solang_parser::pt::Expression`. Each constructor maps directly to
one `IR.Expr` constructor with the same name and arity; the
preservation theorem witnesses this directly. -/
inductive Expr where
  | literal (v : IR.Value)
  | var (name : String)
  | unary (op : IR.UnaryOp) (e : Expr)
  | binary (op : IR.BinaryOp) (lhs : Expr) (rhs : Expr)
  | conditional (cond : Expr) (whenTrue : Expr) (whenFalse : Expr)
  | keccak256 (parts : List Expr)
  deriving Inhabited

/-! ## Sol.Statement -/

/-- Mirror of the structural admitted subset of
`solang_parser::pt::Statement`. The `assign` constructor here only
handles assignment-to-local; assignment-to-state is deferred to the
context-dependent follow-up. -/
inductive Statement where
  | declare (name : String) (ty : IR.Ty) (value : Expr)
  | assign (name : String) (value : Expr)
  | require_ (cond : Expr)
  | ifStmt (cond : Expr) (thenBody : List Statement) (elseBody : List Statement)
  | forLoop
      (loopId : String) (indexVar : String)
      (start_ : Expr) (end_ : Expr) (body : List Statement)
  | retStmt (value : Option Expr)
  deriving Inhabited

/-! ## Sol.Function

Mirror of `uo-solc`'s admitted entrypoint shape. The
`secretArgs : List Nat` field carries the indices of parameters
declared as secret, matching the IR / kernel surface. -/
structure Function where
  signature : String
  params : List IR.Param
  returnType : Option IR.Ty
  secretArgs : List Nat
  confidential : Bool
  body : List Statement
  deriving Inhabited

/-! ## Operational semantics

The Sol AST evaluator is the `IR.evalExpr` / `IR.evalStatement`
counterpart on the Sol AST. Each evaluator branch produces the same
`IR.Outcome` as the corresponding IR branch would on the lowered
IR construct; the preservation theorem witnesses this directly.

Like the IR evaluator, the Sol evaluator threads the
`OperationalConfig` so masked-store updates persist (though no
masked-store assignments appear in the structural fragment yet).
-/

open IR (OperationalConfig LocalEnv Outcome ExprResult EvalStatus
  UnaryOp BinaryOp)

mutual

/-- Big-step Sol expression evaluator. Mirrors `IR.evalExpr` on the
Sol AST. -/
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
  | .conditional cond whenTrue whenFalse =>
      match evalExpr cfg env cond with
      | .status s => .status s
      | .value (.bool true) => evalExpr cfg env whenTrue
      | .value (.bool false) => evalExpr cfg env whenFalse
      | .value _ => .status (.evalError "select condition not boolean")
  | .keccak256 parts =>
      match evalExprList cfg env parts with
      | .error s => .status s
      | .ok vs => .value (IR.Value.keccak256Mock vs)

/-- List companion for `evalExpr` (`keccak256` case). -/
def evalExprList (cfg : OperationalConfig) (env : LocalEnv) :
    List Expr → Except EvalStatus (List IR.Value)
  | [] => .ok []
  | p :: rest =>
      match evalExpr cfg env p with
      | .status s => .error s
      | .value v =>
          match evalExprList cfg env rest with
          | .ok vs => .ok (v :: vs)
          | .error s => .error s

end

mutual

/-- Big-step Sol statement evaluator. Mirrors `IR.evalStatement` on
the Sol AST. -/
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
  | .require_ cond =>
      match evalExpr cfg env cond with
      | .value (.bool true) => (cfg, env, oc)
      | .value (.bool false) => (cfg, env, { oc with status := .requireFailed })
      | .value _ => (cfg, env, { oc with status := .evalError "require not boolean" })
      | .status s => (cfg, env, { oc with status := s })
  | .ifStmt cond thenBody elseBody =>
      match evalExpr cfg env cond with
      | .status s => (cfg, env, { oc with status := s })
      | .value (.bool true) => evalBody cfg env oc thenBody
      | .value (.bool false) => evalBody cfg env oc elseBody
      | .value _ => (cfg, env, { oc with status := .evalError "if condition not boolean" })
  | .forLoop _loopId indexVar startExpr endExpr body =>
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

/-- Construct the initial environment from the Sol function's parameters
and the supplied public/secret arguments. Mirrors
`IR.OperationalConfig.initialEnv`. -/
def Function.initialEnv (fn : Function)
    (publicArgs secretArgs : List IR.Value) : Option LocalEnv :=
  let allArgs := publicArgs ++ secretArgs
  if allArgs.length = fn.params.length then
    some <| (fn.params.zip allArgs).foldl
      (fun env entry => env.insert entry.fst.name entry.snd) []
  else
    none

/-- Big-step program-level Sol evaluator. -/
def evalFunction (fn : Function) (cfg : OperationalConfig) : Outcome :=
  match fn.initialEnv cfg.publicArgs cfg.secretArgs with
  | none =>
      { Outcome.empty with status := .evalError "argument arity mismatch" }
  | some env =>
      let (_cfg', _env', outcome) := evalBody cfg env Outcome.empty fn.body
      outcome

/-! ## AST → IR lowering

Mirrors `lower_expr` / `lower_statement` from
`compiler/uo-solc/src/lib.rs` on the structural fragment. Each
constructor maps to its same-named IR counterpart; the lowering is
*total* on this surface (no `Except` needed at the structural level). -/

mutual

/-- Lower `Sol.Expr` to `IR.Expr`. -/
def lowerExpr : Expr → IR.Expr
  | .literal v => .literal v
  | .var name => .var name
  | .unary op e => .unary op (lowerExpr e)
  | .binary op lhs rhs => .binary op (lowerExpr lhs) (lowerExpr rhs)
  | .conditional cond wt wf =>
      .select (lowerExpr cond) (lowerExpr wt) (lowerExpr wf)
  | .keccak256 parts => .keccak256 (lowerExprList parts)

/-- List companion for `lowerExpr` (`keccak256` case). -/
def lowerExprList : List Expr → List IR.Expr
  | [] => []
  | e :: rest => lowerExpr e :: lowerExprList rest

end

mutual

/-- Lower `Sol.Statement` to `IR.Statement`. -/
def lowerStatement : Statement → IR.Statement
  | .declare name ty value => .declare name ty (lowerExpr value)
  | .assign name value => .assign name (lowerExpr value)
  | .require_ cond => .require (lowerExpr cond)
  | .ifStmt cond thenBody elseBody =>
      .ifStmt (lowerExpr cond) (lowerStatementList thenBody) (lowerStatementList elseBody)
  | .forLoop loopId indexVar start_ end_ body =>
      .forLoop loopId indexVar (lowerExpr start_) (lowerExpr end_)
        (lowerStatementList body)
  | .retStmt none => .retStmt none
  | .retStmt (some value) => .retStmt (some (lowerExpr value))

/-- List companion for `lowerStatement`. -/
def lowerStatementList : List Statement → List IR.Statement
  | [] => []
  | s :: rest => lowerStatement s :: lowerStatementList rest

end

/-- Lower a `Sol.Function` to an `IR.CompiledFunction`. The IR
function carries no `confidentialProgram` / `confidentialSlotProgram`
side-data — those are runtime instrumentation that uo-solc emits
separately, outside the W4.2 source-to-IR scope. -/
def lowerFunction (fn : Function) : IR.CompiledFunction :=
  { signature := fn.signature
  , params := fn.params
  , returnType := fn.returnType
  , body := lowerStatementList fn.body
  , secretArgs := fn.secretArgs
  , confidential := fn.confidential
  }

/-! ## W4.2 source-to-IR preservation theorem

The lowering preserves semantics: for every Sol expression `e`,
`evalExpr cfg env e = IR.evalExpr cfg env (lowerExpr e)`. Mutually
recursive with `lowerExprList_preserves_semantics` for the
`keccak256` case. The proof follows the W4.4 Session B-2 pattern
(`unfold + rw [ih]` per case, terminating in `rfl`). -/

mutual

theorem lowerExpr_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (e : Expr), evalExpr cfg env e = IR.evalExpr cfg env (lowerExpr e)
  | .literal _ => by
      unfold evalExpr lowerExpr IR.evalExpr; rfl
  | .var _ => by
      unfold evalExpr lowerExpr IR.evalExpr; rfl
  | .unary op e => by
      unfold evalExpr lowerExpr IR.evalExpr
      rw [lowerExpr_preserves_semantics cfg env e]
      rfl
  | .binary op lhs rhs => by
      unfold evalExpr lowerExpr IR.evalExpr
      rw [lowerExpr_preserves_semantics cfg env lhs,
          lowerExpr_preserves_semantics cfg env rhs]
      rfl
  | .conditional cond wt wf => by
      unfold evalExpr lowerExpr IR.evalExpr
      rw [lowerExpr_preserves_semantics cfg env cond]
      cases IR.evalExpr cfg env (lowerExpr cond) with
      | status _ => rfl
      | value v =>
          cases v with
          | bool b =>
              cases b
              · exact lowerExpr_preserves_semantics cfg env wf
              · exact lowerExpr_preserves_semantics cfg env wt
          | uint _ => rfl
          | bytes32 _ => rfl
          | address _ => rfl
          | structValue _ => rfl
          | array _ => rfl
          | map _ => rfl
  | .keccak256 parts => by
      unfold evalExpr lowerExpr IR.evalExpr
      rw [lowerExprList_preserves_semantics cfg env parts]
      rfl

theorem lowerExprList_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ (es : List Expr),
      evalExprList cfg env es = IR.evalExprList cfg env (lowerExprList es)
  | [] => by
      unfold evalExprList lowerExprList IR.evalExprList; rfl
  | e :: rest => by
      unfold evalExprList lowerExprList IR.evalExprList
      rw [lowerExpr_preserves_semantics cfg env e,
          lowerExprList_preserves_semantics cfg env rest]
      rfl

end

/-! ### W4.2 per-Statement preservation -/

mutual

theorem lowerStatement_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    ∀ (s : Statement),
      evalStatement cfg env oc s = IR.evalStatement cfg env oc (lowerStatement s)
  | .declare name ty value => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
      rw [lowerExpr_preserves_semantics cfg env value]
      rfl
  | .assign name value => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
      rw [lowerExpr_preserves_semantics cfg env value]
      rfl
  | .require_ cond => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
      rw [lowerExpr_preserves_semantics cfg env cond]
      rfl
  | .ifStmt cond thenBody elseBody => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
      rw [lowerExpr_preserves_semantics cfg env cond]
      cases IR.evalExpr cfg env (lowerExpr cond) with
      | status _ => rfl
      | value v =>
          cases v with
          | bool b =>
              cases b
              · exact lowerStatementList_preserves_semantics cfg env oc elseBody
              · exact lowerStatementList_preserves_semantics cfg env oc thenBody
          | uint _ => rfl
          | bytes32 _ => rfl
          | address _ => rfl
          | structValue _ => rfl
          | array _ => rfl
          | map _ => rfl
  | .forLoop loopId indexVar startE endE body => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
      rw [lowerExpr_preserves_semantics cfg env startE]
      cases IR.evalExpr cfg env (lowerExpr startE) with
      | status _ => rfl
      | value sv =>
          rw [lowerExpr_preserves_semantics cfg env endE]
          cases IR.evalExpr cfg env (lowerExpr endE) with
          | status _ =>
              cases sv <;> rfl
          | value ev =>
              cases sv with
              | uint sn =>
                  cases ev with
                  | uint en =>
                      exact lowerForLoop_preserves_semantics cfg env oc indexVar sn en body
                  | bool _ => rfl
                  | bytes32 _ => rfl
                  | address _ => rfl
                  | structValue _ => rfl
                  | array _ => rfl
                  | map _ => rfl
              | bool _ => cases ev <;> rfl
              | bytes32 _ => cases ev <;> rfl
              | address _ => cases ev <;> rfl
              | structValue _ => cases ev <;> rfl
              | array _ => cases ev <;> rfl
              | map _ => cases ev <;> rfl
  | .retStmt none => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
  | .retStmt (some value) => by
      simp only [evalStatement, lowerStatement, IR.evalStatement]
      rw [lowerExpr_preserves_semantics cfg env value]
      rfl
termination_by s => (sizeOf s, 0, 0)

theorem lowerStatementList_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    ∀ (stmts : List Statement),
      evalBody cfg env oc stmts =
        IR.evalBody cfg env oc (lowerStatementList stmts)
  | [] => by
      simp only [evalBody, lowerStatementList, IR.evalBody]
  | stmt :: rest => by
      simp only [evalBody, lowerStatementList, IR.evalBody]
      rw [lowerStatement_preserves_semantics cfg env oc stmt]
      generalize hStep : IR.evalStatement cfg env oc (lowerStatement stmt) = step
      cases step with
      | mk cfg' rest' =>
          cases rest' with
          | mk env' oc' =>
              simp only []
              cases hStatus : oc'.status with
              | completed =>
                  by_cases hRet : oc'.publicResult.isSome
                  · simp [hRet]
                  · simp only [hRet]
                    exact lowerStatementList_preserves_semantics cfg' env' oc' rest
              | _ => simp
termination_by stmts => (sizeOf stmts, 0, 0)

theorem lowerForLoop_preserves_semantics
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome)
    (indexVar : String) (i endN : Nat) (body : List Statement) :
    evalForLoop cfg env oc indexVar i endN body =
      IR.evalForLoop cfg env oc indexVar i endN (lowerStatementList body) := by
  unfold evalForLoop IR.evalForLoop
  by_cases h : i ≥ endN
  · simp [h]
  · simp only [h, if_false]
    rw [lowerStatementList_preserves_semantics cfg (env.insert indexVar (.uint i)) oc body]
    generalize hStep : IR.evalBody cfg (env.insert indexVar (.uint i)) oc
      (lowerStatementList body) = step
    cases step with
    | mk cfg' rest' =>
        cases rest' with
        | mk env'' oc' =>
            simp only []
            cases hStatus : oc'.status with
            | completed =>
                by_cases hRet : oc'.publicResult.isSome
                · simp [hRet]
                · simp only [hRet]
                  exact lowerForLoop_preserves_semantics cfg' env'' oc'
                    indexVar (i + 1) endN body
            | _ => simp
termination_by (sizeOf body, endN - i, 1)

end

/-! ### W4.2 program-level preservation -/

/-- Helper: `lowerFunction` preserves the parameter list, so the
initial-env construction agrees with the IR side. The two sides reduce
to the same `foldl` because `(lowerFunction fn).params = fn.params`
definitionally. -/
theorem lowerFunction_initialEnv_eq
    (fn : Function) (cfg : OperationalConfig) :
    fn.initialEnv cfg.publicArgs cfg.secretArgs =
      cfg.initialEnv (lowerFunction fn) := rfl

/-- Program-level preservation: the Sol-side `evalFunction` agrees
with the IR-side `evalContract` whenever the IR config's entrypoint
resolves to the lowered function. -/
theorem lowerFunction_preserves_semantics
    (fn : Function) (cfg : OperationalConfig)
    (hEntry : cfg.entrypointFn? = some (lowerFunction fn)) :
    evalFunction fn cfg = IR.evalContract cfg := by
  -- `(lowerFunction fn).body = lowerStatementList fn.body` definitionally,
  -- and `Function.initialEnv` agrees with `OperationalConfig.initialEnv`
  -- on the lowered function. The body preservation theorem closes the
  -- `some env` branch.
  unfold evalFunction IR.evalContract
  simp only [hEntry, ← lowerFunction_initialEnv_eq fn cfg]
  cases hEnv : fn.initialEnv cfg.publicArgs cfg.secretArgs with
  | none => rfl
  | some env =>
      simp only []
      have ihBody := lowerStatementList_preserves_semantics
        cfg env Outcome.empty fn.body
      rw [ihBody]
      rfl

end UOToolchain.Sol
