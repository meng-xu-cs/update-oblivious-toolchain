import Lean.Data.Json
import UOToolchain.RuntimeRefinement

open Lean

namespace UOToolchain

structure ConfidentialKernelParam where
  name : String
  ty : Json

mutual

inductive ConfidentialKernelStatement where
  | declare (name : String) (ty : Json) (value : ConfidentialKernelExpr)
  | assign (name : String) (value : ConfidentialKernelExpr)
  | require (cond : ConfidentialKernelExpr)
  | abortIf (cond : ConfidentialKernelExpr)
  | cellSet
      (objectId : Nat)
      (value : ConfidentialKernelExpr)
      (predicate : Option ConfidentialKernelExpr)
  | arraySet
      (objectId : Nat)
      (index : ConfidentialKernelExpr)
      (value : ConfidentialKernelExpr)
      (predicate : Option ConfidentialKernelExpr)
  | mapPut
      (objectId : Nat)
      (key : ConfidentialKernelExpr)
      (value : ConfidentialKernelExpr)
      (predicate : Option ConfidentialKernelExpr)
  | ret (value : Option ConfidentialKernelExpr)

inductive ConfidentialKernelExpr where
  | literal (value : Json)
  | var (name : String)
  | unary (op : Json) (expr : ConfidentialKernelExpr)
  | binary (op : Json) (lhs rhs : ConfidentialKernelExpr)
  | select
      (cond : ConfidentialKernelExpr)
      (whenTrue whenFalse : ConfidentialKernelPureExpr)
  | cellGet (objectId : Nat)
  | arrayGet (objectId : Nat) (index : ConfidentialKernelExpr)
  | mapGet (objectId : Nat) (key : ConfidentialKernelExpr)
  | keccak256 (parts : List ConfidentialKernelExpr)

inductive ConfidentialKernelPureExpr where
  | literal (value : Json)
  | var (name : String)
  | unary (op : Json) (expr : ConfidentialKernelPureExpr)
  | binary (op : Json) (lhs rhs : ConfidentialKernelPureExpr)
  | select
      (cond : ConfidentialKernelPureExpr)
      (whenTrue whenFalse : ConfidentialKernelPureExpr)
  | keccak256 (parts : List ConfidentialKernelPureExpr)

end

structure ConfidentialKernelProgram where
  entrypointId : String
  params : List ConfidentialKernelParam
  returnType : Option Json
  secretArgs : List Nat
  body : List ConfidentialKernelStatement

def confidentialKernelRuntimeKernelStep
  (opcode : String)
  (objectId : Option Nat := none) : RuntimeKernelStep :=
  { opcode := opcode
  , objectId := objectId
  }

mutual

def ConfidentialKernelStatement.expectedRuntimeKernelSteps :
  ConfidentialKernelStatement → List RuntimeKernelStep
  | .declare _ _ value => value.expectedRuntimeKernelSteps
  | .assign _ value => value.expectedRuntimeKernelSteps
  | .require cond => cond.expectedRuntimeKernelSteps
  | .abortIf cond => cond.expectedRuntimeKernelSteps
  | .cellSet objectId value predicate =>
      value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [confidentialKernelRuntimeKernelStep "CellSet" (some objectId)]
  | .arraySet objectId index value predicate =>
      index.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [confidentialKernelRuntimeKernelStep "ArraySet" (some objectId)]
  | .mapPut objectId key value predicate =>
      key.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [confidentialKernelRuntimeKernelStep "MapPut" (some objectId)]
  | .ret value? =>
      match value? with
      | none => []
      | some value => value.expectedRuntimeKernelSteps

def ConfidentialKernelExpr.expectedRuntimeKernelSteps :
  ConfidentialKernelExpr → List RuntimeKernelStep
  | .literal _ => []
  | .var _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond _ _ => cond.expectedRuntimeKernelSteps
  | .cellGet objectId => [confidentialKernelRuntimeKernelStep "CellGet" (some objectId)]
  | .arrayGet objectId index =>
      index.expectedRuntimeKernelSteps ++
        [confidentialKernelRuntimeKernelStep "ArrayGet" (some objectId)]
  | .mapGet objectId key =>
      key.expectedRuntimeKernelSteps ++
        [confidentialKernelRuntimeKernelStep "MapGet" (some objectId)]
  | .keccak256 parts =>
      confidentialKernelExprListExpectedRuntimeKernelSteps parts

def ConfidentialKernelPureExpr.expectedRuntimeKernelSteps :
  ConfidentialKernelPureExpr → List RuntimeKernelStep
  | .literal _ => []
  | .var _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond whenTrue whenFalse =>
      cond.expectedRuntimeKernelSteps ++
        whenTrue.expectedRuntimeKernelSteps ++
        whenFalse.expectedRuntimeKernelSteps
  | .keccak256 parts =>
      confidentialKernelPureExprListExpectedRuntimeKernelSteps parts

def confidentialKernelExprListExpectedRuntimeKernelSteps :
  List ConfidentialKernelExpr → List RuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        confidentialKernelExprListExpectedRuntimeKernelSteps exprs

def confidentialKernelPureExprListExpectedRuntimeKernelSteps :
  List ConfidentialKernelPureExpr → List RuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        confidentialKernelPureExprListExpectedRuntimeKernelSteps exprs

def confidentialKernelStatementListExpectedRuntimeKernelSteps :
  List ConfidentialKernelStatement → List RuntimeKernelStep
  | [] => []
  | stmt :: stmts =>
      stmt.expectedRuntimeKernelSteps ++
        confidentialKernelStatementListExpectedRuntimeKernelSteps stmts

end

def ConfidentialKernelProgram.expectedRuntimeKernelSteps
  (program : ConfidentialKernelProgram) : List RuntimeKernelStep :=
  [confidentialKernelRuntimeKernelStep "Begin"] ++
    confidentialKernelStatementListExpectedRuntimeKernelSteps program.body ++
    [ confidentialKernelRuntimeKernelStep "Commit"
    , confidentialKernelRuntimeKernelStep "Wipe"
    ]

def ConfidentialKernelProgram.expectedRuntimeKernelSchedule
  (program : ConfidentialKernelProgram) : RuntimeKernelSchedule :=
  let steps := program.expectedRuntimeKernelSteps
  { opcodes := steps.map RuntimeKernelStep.opcode
  , steps := steps
  }

mutual

inductive ConfidentialKernelSlotStatement where
  | declare (slot : Nat) (value : ConfidentialKernelSlotExpr)
  | assign (slot : Nat) (value : ConfidentialKernelSlotExpr)
  | require (cond : ConfidentialKernelSlotExpr)
  | abortIf (cond : ConfidentialKernelSlotExpr)
  | cellSet
      (objectId : Nat)
      (value : ConfidentialKernelSlotExpr)
      (predicate : Option ConfidentialKernelSlotExpr)
  | arraySet
      (objectId : Nat)
      (index : ConfidentialKernelSlotExpr)
      (value : ConfidentialKernelSlotExpr)
      (predicate : Option ConfidentialKernelSlotExpr)
  | mapPut
      (objectId : Nat)
      (key : ConfidentialKernelSlotExpr)
      (value : ConfidentialKernelSlotExpr)
      (predicate : Option ConfidentialKernelSlotExpr)
  | ret (value : Option ConfidentialKernelSlotExpr)

inductive ConfidentialKernelSlotExpr where
  | literal (value : Json)
  | slot (slot : Nat)
  | unary (op : Json) (expr : ConfidentialKernelSlotExpr)
  | binary (op : Json) (lhs rhs : ConfidentialKernelSlotExpr)
  | select
      (cond : ConfidentialKernelSlotExpr)
      (whenTrue whenFalse : ConfidentialKernelSlotPureExpr)
  | cellGet (objectId : Nat)
  | arrayGet (objectId : Nat) (index : ConfidentialKernelSlotExpr)
  | mapGet (objectId : Nat) (key : ConfidentialKernelSlotExpr)
  | keccak256 (parts : List ConfidentialKernelSlotExpr)

inductive ConfidentialKernelSlotPureExpr where
  | literal (value : Json)
  | slot (slot : Nat)
  | unary (op : Json) (expr : ConfidentialKernelSlotPureExpr)
  | binary (op : Json) (lhs rhs : ConfidentialKernelSlotPureExpr)
  | select
      (cond : ConfidentialKernelSlotPureExpr)
      (whenTrue whenFalse : ConfidentialKernelSlotPureExpr)
  | keccak256 (parts : List ConfidentialKernelSlotPureExpr)

end

structure ConfidentialKernelSlotProgram where
  entrypointId : String
  paramCount : Nat
  returnType : Option Json
  secretArgs : List Nat
  slotCount : Nat
  body : List ConfidentialKernelSlotStatement

def ConfidentialKernelSlotStatement.RuntimeNormalForm :
  ConfidentialKernelSlotStatement → Prop
  | .require _ => False
  | _ => True

def ConfidentialKernelSlotStatement.checkRuntimeNormalForm
  (stmt : ConfidentialKernelSlotStatement) : Bool :=
  match stmt with
  | .require _ => false
  | _ => true

@[simp] theorem confidentialKernelSlotStatement_checkRuntimeNormalForm_eq_true_iff
  (stmt : ConfidentialKernelSlotStatement) :
  stmt.checkRuntimeNormalForm = true ↔ stmt.RuntimeNormalForm := by
  cases stmt <;> simp [ConfidentialKernelSlotStatement.checkRuntimeNormalForm,
    ConfidentialKernelSlotStatement.RuntimeNormalForm]

def ConfidentialKernelSlotProgram.RuntimeNormalForm
  (program : ConfidentialKernelSlotProgram) : Prop :=
  ∀ stmt ∈ program.body, stmt.RuntimeNormalForm

def ConfidentialKernelSlotProgram.checkRuntimeNormalForm
  (program : ConfidentialKernelSlotProgram) : Bool :=
  program.body.all ConfidentialKernelSlotStatement.checkRuntimeNormalForm

@[simp] theorem confidentialKernelSlotProgram_checkRuntimeNormalForm_eq_true_iff
  (program : ConfidentialKernelSlotProgram) :
  program.checkRuntimeNormalForm = true ↔ program.RuntimeNormalForm := by
  unfold ConfidentialKernelSlotProgram.checkRuntimeNormalForm
    ConfidentialKernelSlotProgram.RuntimeNormalForm
  rw [List.all_eq_true]
  constructor
  · intro h stmt hMem
    exact
      (confidentialKernelSlotStatement_checkRuntimeNormalForm_eq_true_iff stmt).mp
        (h stmt hMem)
  · intro h stmt hMem
    exact
      (confidentialKernelSlotStatement_checkRuntimeNormalForm_eq_true_iff stmt).mpr
        (h stmt hMem)

mutual

def confidentialKernelStatementTraceNames : List String :=
  ["declare", "assign", "require", "abort_if", "cell_set", "array_set", "map_put", "return"]

def confidentialKernelStatementRuntimeNormalFormFlags : List Bool :=
  [true, true, false, true, true, true, true, true]

def confidentialKernelStatementEffectKinds : List String :=
  ["store_slot", "store_slot", "guard_only", "abort_flag", "cell_set", "array_set", "map_put",
    "return_value"]

def confidentialKernelStatementEvaluatedOperands : List String :=
  ["value", "value", "cond", "cond", "value,predicate?", "index,value,predicate?",
    "key,value,predicate?", "value?"]

def confidentialKernelStatementTailOpcodes : List String :=
  ["", "", "", "", "CellSet", "ArraySet", "MapPut", ""]

def confidentialKernelExprEvaluatedOperands : List String :=
  ["", "", "expr", "lhs,rhs", "cond", "", "index", "key", "parts"]

def confidentialKernelExprTailOpcodes : List String :=
  ["", "", "", "", "", "CellGet", "ArrayGet", "MapGet", ""]

def confidentialKernelPureExprEvaluatedOperands : List String :=
  ["", "", "expr", "lhs,rhs", "cond,when_true,when_false", "parts"]

def confidentialKernelSlotStatementTraceNames : List String :=
  confidentialKernelStatementTraceNames

def confidentialKernelSlotStatementRuntimeNormalFormFlags : List Bool :=
  confidentialKernelStatementRuntimeNormalFormFlags

def confidentialKernelSlotStatementEffectKinds : List String :=
  confidentialKernelStatementEffectKinds

def confidentialKernelSlotStatementEvaluatedOperands : List String :=
  confidentialKernelStatementEvaluatedOperands

def confidentialKernelSlotStatementTailOpcodes : List String :=
  confidentialKernelStatementTailOpcodes

def confidentialKernelSlotExprEvaluatedOperands : List String :=
  ["", "", "expr", "lhs,rhs", "cond", "", "index", "key", "parts"]

def confidentialKernelSlotExprTailOpcodes : List String :=
  ["", "", "", "", "", "CellGet", "ArrayGet", "MapGet", ""]

def confidentialKernelSlotPureExprEvaluatedOperands : List String :=
  ["", "", "expr", "lhs,rhs", "cond,when_true,when_false", "parts"]

def ConfidentialKernelSlotStatement.traceName :
  ConfidentialKernelSlotStatement → String
  | .declare _ _ => "declare"
  | .assign _ _ => "assign"
  | .require _ => "require"
  | .abortIf _ => "abort_if"
  | .cellSet _ _ _ => "cell_set"
  | .arraySet _ _ _ _ => "array_set"
  | .mapPut _ _ _ _ => "map_put"
  | .ret _ => "return"

def ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps :
  ConfidentialKernelSlotStatement → List RuntimeKernelStep
  | .declare _ value => value.expectedRuntimeKernelSteps
  | .assign _ value => value.expectedRuntimeKernelSteps
  | .require cond => cond.expectedRuntimeKernelSteps
  | .abortIf cond => cond.expectedRuntimeKernelSteps
  | .cellSet objectId value predicate =>
      value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [confidentialKernelRuntimeKernelStep "CellSet" (some objectId)]
  | .arraySet objectId index value predicate =>
      index.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [confidentialKernelRuntimeKernelStep "ArraySet" (some objectId)]
  | .mapPut objectId key value predicate =>
      key.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [confidentialKernelRuntimeKernelStep "MapPut" (some objectId)]
  | .ret value? =>
      match value? with
      | none => []
      | some value => value.expectedRuntimeKernelSteps

def ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps :
  ConfidentialKernelSlotExpr → List RuntimeKernelStep
  | .literal _ => []
  | .slot _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond _ _ => cond.expectedRuntimeKernelSteps
  | .cellGet objectId => [confidentialKernelRuntimeKernelStep "CellGet" (some objectId)]
  | .arrayGet objectId index =>
      index.expectedRuntimeKernelSteps ++
        [confidentialKernelRuntimeKernelStep "ArrayGet" (some objectId)]
  | .mapGet objectId key =>
      key.expectedRuntimeKernelSteps ++
        [confidentialKernelRuntimeKernelStep "MapGet" (some objectId)]
  | .keccak256 parts =>
      confidentialKernelSlotExprListExpectedRuntimeKernelSteps parts

def ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps :
  ConfidentialKernelSlotPureExpr → List RuntimeKernelStep
  | .literal _ => []
  | .slot _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond whenTrue whenFalse =>
      cond.expectedRuntimeKernelSteps ++
        whenTrue.expectedRuntimeKernelSteps ++
        whenFalse.expectedRuntimeKernelSteps
  | .keccak256 parts =>
      confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps parts

def confidentialKernelSlotExprListExpectedRuntimeKernelSteps :
  List ConfidentialKernelSlotExpr → List RuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        confidentialKernelSlotExprListExpectedRuntimeKernelSteps exprs

def confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps :
  List ConfidentialKernelSlotPureExpr → List RuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps exprs

def confidentialKernelSlotStatementListExpectedRuntimeKernelSteps :
  List ConfidentialKernelSlotStatement → List RuntimeKernelStep
  | [] => []
  | stmt :: stmts =>
      stmt.expectedRuntimeKernelSteps ++
        confidentialKernelSlotStatementListExpectedRuntimeKernelSteps stmts

end

def ConfidentialKernelSlotProgram.statementTraceNames
  (program : ConfidentialKernelSlotProgram) : List String :=
  program.body.map ConfidentialKernelSlotStatement.traceName

def ConfidentialKernelSlotProgram.expectedRuntimeKernelSteps
  (program : ConfidentialKernelSlotProgram) : List RuntimeKernelStep :=
  [confidentialKernelRuntimeKernelStep "Begin"] ++
    confidentialKernelSlotStatementListExpectedRuntimeKernelSteps program.body ++
    [ confidentialKernelRuntimeKernelStep "Commit"
    , confidentialKernelRuntimeKernelStep "Wipe"
    ]

def ConfidentialKernelSlotProgram.expectedRuntimeKernelSchedule
  (program : ConfidentialKernelSlotProgram) : RuntimeKernelSchedule :=
  let steps := program.expectedRuntimeKernelSteps
  { opcodes := steps.map RuntimeKernelStep.opcode
  , steps := steps
  }

abbrev ConfidentialKernelSlotEnv := List (String × Nat)

def confidentialKernelSlotEnvResolve
  (env : ConfidentialKernelSlotEnv)
  (name : String) : Except String Nat :=
  match env with
  | [] =>
      throw s!"unknown confidential kernel variable '{name}'"
  | (entryName, slot) :: rest =>
      if entryName = name then
        pure slot
      else
        confidentialKernelSlotEnvResolve rest name

def confidentialKernelSlotEnvDeclare
  (entrypoint : String)
  (env : ConfidentialKernelSlotEnv)
  (name : String) : Except String (Nat × ConfidentialKernelSlotEnv) := do
  if env.any (fun entry => entry.fst = name) then
    throw s!"confidential entrypoint {entrypoint} declares duplicate variable '{name}'"
  else
    let slot := env.length
    pure (slot, env ++ [(name, slot)])

def confidentialKernelParamsToSlotEnv
  (entrypoint : String)
  (params : List ConfidentialKernelParam)
  (env : ConfidentialKernelSlotEnv := []) : Except String ConfidentialKernelSlotEnv :=
  match params with
  | [] => pure env
  | param :: rest => do
      let (_, env') ← confidentialKernelSlotEnvDeclare entrypoint env param.name
      confidentialKernelParamsToSlotEnv entrypoint rest env'

mutual

def confidentialKernelExprsToSlotExprs :
  List ConfidentialKernelExpr → ConfidentialKernelSlotEnv → Except String (List ConfidentialKernelSlotExpr)
  | [], _ =>
      pure []
  | expr :: rest, env => do
      let expr' ← confidentialKernelExprToSlotExpr expr env
      let rest' ← confidentialKernelExprsToSlotExprs rest env
      pure (expr' :: rest')
termination_by exprs _ => sizeOf exprs

def confidentialKernelPureExprsToSlotPureExprs :
  List ConfidentialKernelPureExpr →
    ConfidentialKernelSlotEnv → Except String (List ConfidentialKernelSlotPureExpr)
  | [], _ =>
      pure []
  | expr :: rest, env => do
      let expr' ← confidentialKernelPureExprToSlotPureExpr expr env
      let rest' ← confidentialKernelPureExprsToSlotPureExprs rest env
      pure (expr' :: rest')
termination_by exprs _ => sizeOf exprs

def confidentialKernelExprToSlotExpr :
  ConfidentialKernelExpr → ConfidentialKernelSlotEnv → Except String ConfidentialKernelSlotExpr
  | .literal value, _ =>
      pure <| .literal value
  | .var name, env => do
      pure <| .slot (← confidentialKernelSlotEnvResolve env name)
  | .unary op expr, env => do
      pure <| .unary op (← confidentialKernelExprToSlotExpr expr env)
  | .binary op lhs rhs, env => do
      pure <| .binary op
        (← confidentialKernelExprToSlotExpr lhs env)
        (← confidentialKernelExprToSlotExpr rhs env)
  | .select cond whenTrue whenFalse, env => do
      pure <| .select
        (← confidentialKernelExprToSlotExpr cond env)
        (← confidentialKernelPureExprToSlotPureExpr whenTrue env)
        (← confidentialKernelPureExprToSlotPureExpr whenFalse env)
  | .cellGet objectId, _ =>
      pure <| .cellGet objectId
  | .arrayGet objectId index, env => do
      pure <| .arrayGet objectId (← confidentialKernelExprToSlotExpr index env)
  | .mapGet objectId key, env => do
      pure <| .mapGet objectId (← confidentialKernelExprToSlotExpr key env)
  | .keccak256 parts, env => do
      pure <| .keccak256 (← confidentialKernelExprsToSlotExprs parts env)
termination_by expr _ => sizeOf expr

def confidentialKernelPureExprToSlotPureExpr :
  ConfidentialKernelPureExpr → ConfidentialKernelSlotEnv → Except String ConfidentialKernelSlotPureExpr
  | .literal value, _ =>
      pure <| .literal value
  | .var name, env => do
      pure <| .slot (← confidentialKernelSlotEnvResolve env name)
  | .unary op expr, env => do
      pure <| .unary op (← confidentialKernelPureExprToSlotPureExpr expr env)
  | .binary op lhs rhs, env => do
      pure <| .binary op
        (← confidentialKernelPureExprToSlotPureExpr lhs env)
        (← confidentialKernelPureExprToSlotPureExpr rhs env)
  | .select cond whenTrue whenFalse, env => do
      pure <| .select
        (← confidentialKernelPureExprToSlotPureExpr cond env)
        (← confidentialKernelPureExprToSlotPureExpr whenTrue env)
        (← confidentialKernelPureExprToSlotPureExpr whenFalse env)
  | .keccak256 parts, env => do
      pure <| .keccak256 (← confidentialKernelPureExprsToSlotPureExprs parts env)
termination_by expr _ => sizeOf expr

decreasing_by
  all_goals simp_wf
  all_goals omega

end

def confidentialKernelStatementToSlotStatement
  (entrypoint : String)
  (stmt : ConfidentialKernelStatement)
  (env : ConfidentialKernelSlotEnv) :
  Except String (ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) := do
  match stmt with
  | .declare name _ value =>
      let (slot, env') ← confidentialKernelSlotEnvDeclare entrypoint env name
      let value' ← confidentialKernelExprToSlotExpr value env'
      pure (.declare slot value', env')
  | .assign name value =>
      let slot ← confidentialKernelSlotEnvResolve env name
      pure (.assign slot (← confidentialKernelExprToSlotExpr value env), env)
  | .require cond =>
      pure (.abortIf (← confidentialKernelExprToSlotExpr cond env), env)
  | .abortIf cond =>
      pure (.abortIf (← confidentialKernelExprToSlotExpr cond env), env)
  | .cellSet objectId value predicate =>
      let predicate' ←
        match predicate with
        | none => pure none
        | some cond => some <$> confidentialKernelExprToSlotExpr cond env
      pure (.cellSet objectId (← confidentialKernelExprToSlotExpr value env) predicate', env)
  | .arraySet objectId index value predicate =>
      let predicate' ←
        match predicate with
        | none => pure none
        | some cond => some <$> confidentialKernelExprToSlotExpr cond env
      pure
        (.arraySet objectId
          (← confidentialKernelExprToSlotExpr index env)
          (← confidentialKernelExprToSlotExpr value env)
          predicate',
          env)
  | .mapPut objectId key value predicate =>
      let predicate' ←
        match predicate with
        | none => pure none
        | some cond => some <$> confidentialKernelExprToSlotExpr cond env
      pure
        (.mapPut objectId
          (← confidentialKernelExprToSlotExpr key env)
          (← confidentialKernelExprToSlotExpr value env)
          predicate',
          env)
  | .ret value =>
      let value' ←
        match value with
        | none => pure none
        | some expr => some <$> confidentialKernelExprToSlotExpr expr env
      pure (.ret value', env)

def confidentialKernelStatementsToSlotStatements
  (entrypoint : String)
  (stmts : List ConfidentialKernelStatement)
  (env : ConfidentialKernelSlotEnv) :
  Except String (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) := do
  match stmts with
  | [] =>
      pure ([], env)
  | stmt :: rest =>
      let (slotStmt, env') ← confidentialKernelStatementToSlotStatement entrypoint stmt env
      let (slotRest, env'') ← confidentialKernelStatementsToSlotStatements entrypoint rest env'
      pure (slotStmt :: slotRest, env'')

theorem confidentialKernelStatementToSlotStatement_runtimeNormalForm
  (entrypoint : String)
  (stmt : ConfidentialKernelStatement)
  (env : ConfidentialKernelSlotEnv)
  (slotStmt : ConfidentialKernelSlotStatement)
  (env' : ConfidentialKernelSlotEnv)
  (h :
    confidentialKernelStatementToSlotStatement entrypoint stmt env =
      .ok (slotStmt, env')) :
  slotStmt.RuntimeNormalForm := by
  cases stmt with
  | declare name ty value =>
      cases hDecl : confidentialKernelSlotEnvDeclare entrypoint env name with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hDecl] at h
          cases h
      | ok decl =>
          cases decl with
          | mk slot env1 =>
              cases hValue : confidentialKernelExprToSlotExpr value (slot, env1).snd with
              | error err =>
                  have hTmp := h
                  simp [confidentialKernelStatementToSlotStatement, hDecl] at hTmp
                  have hTmp' :
                      (fun a => (ConfidentialKernelSlotStatement.declare slot a, env1)) <$>
                        confidentialKernelExprToSlotExpr value env1 =
                        Except.ok (slotStmt, env') := by
                    simpa using hTmp
                  simp [Functor.map, Except.map, hValue] at hTmp'
              | ok value' =>
                  have hTmp := h
                  simp [confidentialKernelStatementToSlotStatement, hDecl] at hTmp
                  have hTmp' :
                      (fun a => (ConfidentialKernelSlotStatement.declare slot a, env1)) <$>
                        confidentialKernelExprToSlotExpr value env1 =
                        Except.ok (slotStmt, env') := by
                    simpa using hTmp
                  have hPairEq :
                      ConfidentialKernelSlotStatement.declare slot value' = slotStmt ∧
                        env1 = env' := by
                    simpa [Functor.map, Except.map, hValue] using hTmp'
                  rcases hPairEq with ⟨hStmtEq, hEnvEq⟩
                  subst hStmtEq
                  subst hEnvEq
                  trivial
  | assign name value =>
      cases hSlot : confidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hSlot] at h
          cases h
      | ok slot =>
          cases hValue : confidentialKernelExprToSlotExpr value env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hSlot, hValue] at h
              cases h
          | ok value' =>
              simp [confidentialKernelStatementToSlotStatement, hSlot, hValue] at h
              cases h
              trivial
  | require cond =>
      cases hCond : confidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
      | ok cond' =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
          trivial
  | abortIf cond =>
      cases hCond : confidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
      | ok cond' =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
          trivial
  | cellSet objectId value predicate =>
      cases hValue : confidentialKernelExprToSlotExpr value env with
      | error err =>
          cases predicate with
          | none =>
              simp [confidentialKernelStatementToSlotStatement, hValue] at h
              cases h
          | some cond =>
              cases hCond : confidentialKernelExprToSlotExpr cond env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hValue, hCond] at h
                  cases h
              | ok cond' =>
                  simp [confidentialKernelStatementToSlotStatement, hValue, hCond] at h
                  cases h
      | ok value' =>
          cases predicate with
          | none =>
              simp [confidentialKernelStatementToSlotStatement, hValue] at h
              cases h
              trivial
          | some cond =>
              cases hCond : confidentialKernelExprToSlotExpr cond env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hValue, hCond] at h
                  cases h
              | ok cond' =>
                  simp [confidentialKernelStatementToSlotStatement, hValue, hCond] at h
                  cases h
                  trivial
  | arraySet objectId index value predicate =>
      cases hIndex : confidentialKernelExprToSlotExpr index env with
      | error err =>
          cases predicate with
          | none =>
              simp [confidentialKernelStatementToSlotStatement, hIndex] at h
              cases h
          | some cond =>
              cases hCond : confidentialKernelExprToSlotExpr cond env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hIndex, hCond] at h
                  cases h
              | ok cond' =>
                  simp [confidentialKernelStatementToSlotStatement, hIndex, hCond] at h
                  cases h
      | ok index' =>
          cases hValue : confidentialKernelExprToSlotExpr value env with
          | error err =>
              cases predicate with
              | none =>
                  simp [confidentialKernelStatementToSlotStatement, hIndex, hValue] at h
                  cases h
              | some cond =>
                  cases hCond : confidentialKernelExprToSlotExpr cond env with
                  | error err =>
                      simp [confidentialKernelStatementToSlotStatement, hIndex, hValue, hCond] at h
                      cases h
                  | ok cond' =>
                      simp [confidentialKernelStatementToSlotStatement, hIndex, hValue, hCond] at h
                      cases h
          | ok value' =>
              cases predicate with
              | none =>
                  simp [confidentialKernelStatementToSlotStatement, hIndex, hValue] at h
                  cases h
                  trivial
              | some cond =>
                  cases hCond : confidentialKernelExprToSlotExpr cond env with
                  | error err =>
                      simp [confidentialKernelStatementToSlotStatement, hIndex, hValue, hCond] at h
                      cases h
                  | ok cond' =>
                      simp [confidentialKernelStatementToSlotStatement, hIndex, hValue, hCond] at h
                      cases h
                      trivial
  | mapPut objectId key value predicate =>
      cases hKey : confidentialKernelExprToSlotExpr key env with
      | error err =>
          cases predicate with
          | none =>
              simp [confidentialKernelStatementToSlotStatement, hKey] at h
              cases h
          | some cond =>
              cases hCond : confidentialKernelExprToSlotExpr cond env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hKey, hCond] at h
                  cases h
              | ok cond' =>
                  simp [confidentialKernelStatementToSlotStatement, hKey, hCond] at h
                  cases h
      | ok key' =>
          cases hValue : confidentialKernelExprToSlotExpr value env with
          | error err =>
              cases predicate with
              | none =>
                  simp [confidentialKernelStatementToSlotStatement, hKey, hValue] at h
                  cases h
              | some cond =>
                  cases hCond : confidentialKernelExprToSlotExpr cond env with
                  | error err =>
                      simp [confidentialKernelStatementToSlotStatement, hKey, hValue, hCond] at h
                      cases h
                  | ok cond' =>
                      simp [confidentialKernelStatementToSlotStatement, hKey, hValue, hCond] at h
                      cases h
          | ok value' =>
              cases predicate with
              | none =>
                  simp [confidentialKernelStatementToSlotStatement, hKey, hValue] at h
                  cases h
                  trivial
              | some cond =>
                  cases hCond : confidentialKernelExprToSlotExpr cond env with
                  | error err =>
                      simp [confidentialKernelStatementToSlotStatement, hKey, hValue, hCond] at h
                      cases h
                  | ok cond' =>
                      simp [confidentialKernelStatementToSlotStatement, hKey, hValue, hCond] at h
                      cases h
                      trivial
  | ret value =>
      cases value with
      | none =>
          simp [confidentialKernelStatementToSlotStatement] at h
          cases h
          trivial
      | some expr =>
          cases hExpr : confidentialKernelExprToSlotExpr expr env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hExpr] at h
              cases h
          | ok expr' =>
              simp [confidentialKernelStatementToSlotStatement, hExpr] at h
              cases h
              trivial

theorem confidentialKernelStatementsToSlotStatements_runtimeNormalForm
  (entrypoint : String)
  (stmts : List ConfidentialKernelStatement)
  (env env' : ConfidentialKernelSlotEnv)
  (slotBody : List ConfidentialKernelSlotStatement)
  (h :
    confidentialKernelStatementsToSlotStatements entrypoint stmts env =
      .ok (slotBody, env')) :
  slotBody.all ConfidentialKernelSlotStatement.checkRuntimeNormalForm = true := by
  induction stmts generalizing env env' slotBody with
  | nil =>
      simp [confidentialKernelStatementsToSlotStatements] at h
      cases h
      simp
  | cons stmt rest ih =>
      unfold confidentialKernelStatementsToSlotStatements at h
      cases hStmt : confidentialKernelStatementToSlotStatement entrypoint stmt env with
      | error err =>
          rw [hStmt] at h
          simp at h
          cases h
      | ok stmtResult =>
          cases stmtResult with
          | mk slotStmt env1 =>
              cases hRest :
                  confidentialKernelStatementsToSlotStatements entrypoint rest env1 with
              | error err =>
                  have hTmp := h
                  simp [hStmt] at hTmp
                  have hTmp' :
                      (fun a => (slotStmt :: a.fst, a.snd)) <$>
                        confidentialKernelStatementsToSlotStatements entrypoint rest env1 =
                        Except.ok (slotBody, env') := by
                    simpa using hTmp
                  simp [Functor.map, Except.map, hRest] at hTmp'
              | ok restResult =>
                  cases restResult with
                  | mk restBody env2 =>
                      have hTmp := h
                      simp [hStmt] at hTmp
                      have hTmp' :
                          (fun a => (slotStmt :: a.fst, a.snd)) <$>
                            confidentialKernelStatementsToSlotStatements entrypoint rest env1 =
                            Except.ok (slotBody, env') := by
                        simpa using hTmp
                      have hPairEq :
                          slotStmt :: restBody = slotBody ∧ env2 = env' := by
                        simpa [Functor.map, Except.map, hRest] using hTmp'
                      rcases hPairEq with ⟨hBody, hEnv⟩
                      subst hBody
                      subst hEnv
                      have hStmtNormal :
                          slotStmt.RuntimeNormalForm := by
                        exact
                          confidentialKernelStatementToSlotStatement_runtimeNormalForm
                            entrypoint stmt env slotStmt env1 hStmt
                      have hStmtCheck :
                          slotStmt.checkRuntimeNormalForm = true := by
                        exact
                          (confidentialKernelSlotStatement_checkRuntimeNormalForm_eq_true_iff slotStmt).mpr
                            hStmtNormal
                      have hRestNormal :
                          restBody.all ConfidentialKernelSlotStatement.checkRuntimeNormalForm = true := by
                        exact
                          ih env1 env2 restBody hRest
                      simp [hStmtCheck, hRestNormal]

def ConfidentialKernelProgram.toConfidentialKernelSlotProgram?
  (program : ConfidentialKernelProgram) : Except String ConfidentialKernelSlotProgram := do
  let env ← confidentialKernelParamsToSlotEnv program.entrypointId program.params
  let (body, env') ←
    confidentialKernelStatementsToSlotStatements program.entrypointId program.body env
  pure
    { entrypointId := program.entrypointId
    , paramCount := program.params.length
    , returnType := program.returnType
    , secretArgs := program.secretArgs
    , slotCount := env'.length
    , body := body
    }

def ConfidentialKernelProgram.SlotLoweringMatches
  (program : ConfidentialKernelProgram)
  (slotProgram : ConfidentialKernelSlotProgram) : Prop :=
  program.toConfidentialKernelSlotProgram? = .ok slotProgram

theorem confidentialKernelProgram_toConfidentialKernelSlotProgram_runtimeNormalForm
  (program : ConfidentialKernelProgram)
  {slotProgram : ConfidentialKernelSlotProgram}
  (h : program.toConfidentialKernelSlotProgram? = .ok slotProgram) :
  slotProgram.RuntimeNormalForm := by
  unfold ConfidentialKernelProgram.toConfidentialKernelSlotProgram? at h
  cases hEnv : confidentialKernelParamsToSlotEnv program.entrypointId program.params with
  | error err =>
      simp [hEnv] at h
      cases h
  | ok env =>
      cases hBody :
          confidentialKernelStatementsToSlotStatements program.entrypointId program.body env with
      | error err =>
          have hTmp := h
          simp [hEnv] at hTmp
          have hTmp' :
              (fun a =>
                    { entrypointId := program.entrypointId
                    , paramCount := program.params.length
                    , returnType := program.returnType
                    , secretArgs := program.secretArgs
                    , slotCount := List.length a.snd
                    , body := a.fst
                    }) <$>
                confidentialKernelStatementsToSlotStatements program.entrypointId program.body env =
                Except.ok slotProgram := by
            simpa using hTmp
          simp [Functor.map, Except.map, hBody] at hTmp'
      | ok bodyResult =>
          cases bodyResult with
          | mk body env' =>
              have hTmp := h
              simp [hEnv] at hTmp
              have hTmp' :
                  (fun a =>
                        { entrypointId := program.entrypointId
                        , paramCount := program.params.length
                        , returnType := program.returnType
                        , secretArgs := program.secretArgs
                        , slotCount := List.length a.snd
                        , body := a.fst
                        }) <$>
                    confidentialKernelStatementsToSlotStatements program.entrypointId program.body env =
                    Except.ok slotProgram := by
                simpa using hTmp
              have hProgramEq :
                  { entrypointId := program.entrypointId
                  , paramCount := program.params.length
                  , returnType := program.returnType
                  , secretArgs := program.secretArgs
                  , slotCount := env'.length
                  , body := body
                  } = slotProgram := by
                simpa [Functor.map, Except.map, hBody] using hTmp'
              cases hProgramEq
              unfold ConfidentialKernelSlotProgram.RuntimeNormalForm
              have hBodyNormal :
                  body.all ConfidentialKernelSlotStatement.checkRuntimeNormalForm = true := by
                exact
                  confidentialKernelStatementsToSlotStatements_runtimeNormalForm
                    program.entrypointId program.body env env' body hBody
              rw [List.all_eq_true] at hBodyNormal
              intro stmt hMem
              exact
                (confidentialKernelSlotStatement_checkRuntimeNormalForm_eq_true_iff stmt).mp
                  (hBodyNormal stmt hMem)

theorem confidentialKernelProgram_slotLowering_runtimeNormalForm
  {program : ConfidentialKernelProgram}
  {slotProgram : ConfidentialKernelSlotProgram}
  (h : program.SlotLoweringMatches slotProgram) :
  slotProgram.RuntimeNormalForm := by
  unfold ConfidentialKernelProgram.SlotLoweringMatches at h
  exact
    confidentialKernelProgram_toConfidentialKernelSlotProgram_runtimeNormalForm
      program h

mutual

theorem confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
  : (expr : ConfidentialKernelExpr) →
      (env : ConfidentialKernelSlotEnv) →
      (slotExpr : ConfidentialKernelSlotExpr) →
      confidentialKernelExprToSlotExpr expr env = .ok slotExpr →
        expr.expectedRuntimeKernelSteps = slotExpr.expectedRuntimeKernelSteps
  | .literal _, _, _, h => by
      simp [confidentialKernelExprToSlotExpr] at h
      cases h
      rfl
  | .var name, env, slotExpr, h => by
      cases hResolve : confidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hResolve] at h
          cases h
      | ok slot =>
          simp [confidentialKernelExprToSlotExpr, hResolve] at h
          cases h
          rfl
  | .unary op expr, env, slotExpr, h => by
      cases hExpr : confidentialKernelExprToSlotExpr expr env with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hExpr] at h
          cases h
      | ok slotExpr' =>
          simp [confidentialKernelExprToSlotExpr, hExpr] at h
          cases h
          simp [ConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps expr env slotExpr' hExpr]
  | .binary op lhs rhs, env, slotExpr, h => by
      cases hLhs : confidentialKernelExprToSlotExpr lhs env with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hLhs] at h
          cases h
      | ok lhs' =>
          cases hRhs : confidentialKernelExprToSlotExpr rhs env with
          | error err =>
              simp [confidentialKernelExprToSlotExpr, hLhs, hRhs] at h
              cases h
          | ok rhs' =>
              simp [confidentialKernelExprToSlotExpr, hLhs, hRhs] at h
              cases h
              simp [ConfidentialKernelExpr.expectedRuntimeKernelSteps,
                ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
                confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps lhs env lhs' hLhs,
                confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps rhs env rhs' hRhs]
  | .select cond whenTrue whenFalse, env, slotExpr, h => by
      cases hCond : confidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hCond] at h
          cases h
      | ok cond' =>
          cases hWhenTrue : confidentialKernelPureExprToSlotPureExpr whenTrue env with
          | error err =>
              simp [confidentialKernelExprToSlotExpr, hCond, hWhenTrue] at h
              cases h
          | ok whenTrue' =>
              cases hWhenFalse : confidentialKernelPureExprToSlotPureExpr whenFalse env with
              | error err =>
                  simp [confidentialKernelExprToSlotExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
              | ok whenFalse' =>
                  simp [confidentialKernelExprToSlotExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
                  simp [ConfidentialKernelExpr.expectedRuntimeKernelSteps,
                    ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps cond env cond' hCond]
  | .cellGet _, _, _, h => by
      simp [confidentialKernelExprToSlotExpr] at h
      cases h
      rfl
  | .arrayGet objectId index, env, slotExpr, h => by
      cases hIndex : confidentialKernelExprToSlotExpr index env with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hIndex] at h
          cases h
      | ok index' =>
          simp [confidentialKernelExprToSlotExpr, hIndex] at h
          cases h
          simp [ConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps index env index' hIndex]
  | .mapGet objectId key, env, slotExpr, h => by
      cases hKey : confidentialKernelExprToSlotExpr key env with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hKey] at h
          cases h
      | ok key' =>
          simp [confidentialKernelExprToSlotExpr, hKey] at h
          cases h
          simp [ConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps key env key' hKey]
  | .keccak256 parts, env, slotExpr, h => by
      cases hParts : confidentialKernelExprsToSlotExprs parts env with
      | error err =>
          simp [confidentialKernelExprToSlotExpr, hParts] at h
          cases h
      | ok parts' =>
          simp [confidentialKernelExprToSlotExpr, hParts] at h
          cases h
          simp [ConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            confidentialKernelExprsToSlotExprs_expectedRuntimeKernelSteps parts env parts' hParts]

theorem confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
  : (expr : ConfidentialKernelPureExpr) →
      (env : ConfidentialKernelSlotEnv) →
      (slotExpr : ConfidentialKernelSlotPureExpr) →
      confidentialKernelPureExprToSlotPureExpr expr env = .ok slotExpr →
        expr.expectedRuntimeKernelSteps = slotExpr.expectedRuntimeKernelSteps
  | .literal _, _, _, h => by
      simp [confidentialKernelPureExprToSlotPureExpr] at h
      cases h
      rfl
  | .var name, env, slotExpr, h => by
      cases hResolve : confidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [confidentialKernelPureExprToSlotPureExpr, hResolve] at h
          cases h
      | ok slot =>
          simp [confidentialKernelPureExprToSlotPureExpr, hResolve] at h
          cases h
          rfl
  | .unary op expr, env, slotExpr, h => by
      cases hExpr : confidentialKernelPureExprToSlotPureExpr expr env with
      | error err =>
          simp [confidentialKernelPureExprToSlotPureExpr, hExpr] at h
          cases h
      | ok slotExpr' =>
          simp [confidentialKernelPureExprToSlotPureExpr, hExpr] at h
          cases h
          simp [ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
            confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
              expr env slotExpr' hExpr]
  | .binary op lhs rhs, env, slotExpr, h => by
      cases hLhs : confidentialKernelPureExprToSlotPureExpr lhs env with
      | error err =>
          simp [confidentialKernelPureExprToSlotPureExpr, hLhs] at h
          cases h
      | ok lhs' =>
          cases hRhs : confidentialKernelPureExprToSlotPureExpr rhs env with
          | error err =>
              simp [confidentialKernelPureExprToSlotPureExpr, hLhs, hRhs] at h
              cases h
          | ok rhs' =>
              simp [confidentialKernelPureExprToSlotPureExpr, hLhs, hRhs] at h
              cases h
              simp [ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
                ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
                confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps lhs env lhs' hLhs,
                confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps rhs env rhs' hRhs]
  | .select cond whenTrue whenFalse, env, slotExpr, h => by
      cases hCond : confidentialKernelPureExprToSlotPureExpr cond env with
      | error err =>
          simp [confidentialKernelPureExprToSlotPureExpr, hCond] at h
          cases h
      | ok cond' =>
          cases hWhenTrue : confidentialKernelPureExprToSlotPureExpr whenTrue env with
          | error err =>
              simp [confidentialKernelPureExprToSlotPureExpr, hCond, hWhenTrue] at h
              cases h
          | ok whenTrue' =>
              cases hWhenFalse : confidentialKernelPureExprToSlotPureExpr whenFalse env with
              | error err =>
                  simp [confidentialKernelPureExprToSlotPureExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
              | ok whenFalse' =>
                  simp [confidentialKernelPureExprToSlotPureExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
                  simp [ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
                    ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
                    confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                      cond env cond' hCond,
                    confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                      whenTrue env whenTrue' hWhenTrue,
                    confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                      whenFalse env whenFalse' hWhenFalse]
  | .keccak256 parts, env, slotExpr, h => by
      cases hParts : confidentialKernelPureExprsToSlotPureExprs parts env with
      | error err =>
          simp [confidentialKernelPureExprToSlotPureExpr, hParts] at h
          cases h
      | ok parts' =>
          simp [confidentialKernelPureExprToSlotPureExpr, hParts] at h
          cases h
          simp [ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
            confidentialKernelPureExprsToSlotPureExprs_expectedRuntimeKernelSteps
              parts env parts' hParts]

theorem confidentialKernelExprsToSlotExprs_expectedRuntimeKernelSteps
  : (exprs : List ConfidentialKernelExpr) →
      (env : ConfidentialKernelSlotEnv) →
      (slotExprs : List ConfidentialKernelSlotExpr) →
      confidentialKernelExprsToSlotExprs exprs env = .ok slotExprs →
        confidentialKernelExprListExpectedRuntimeKernelSteps exprs =
          confidentialKernelSlotExprListExpectedRuntimeKernelSteps slotExprs
  | [], _, _, h => by
      simp [confidentialKernelExprsToSlotExprs] at h
      cases h
      rfl
  | expr :: exprs, env, slotExprs, h => by
      cases hExpr : confidentialKernelExprToSlotExpr expr env with
      | error err =>
          simp [confidentialKernelExprsToSlotExprs, hExpr] at h
          cases h
      | ok slotExpr =>
          cases hRest : confidentialKernelExprsToSlotExprs exprs env with
          | error err =>
              simp [confidentialKernelExprsToSlotExprs, hExpr, hRest] at h
              cases h
          | ok slotExprs' =>
              simp [confidentialKernelExprsToSlotExprs, hExpr, hRest] at h
              cases h
              simp [confidentialKernelExprListExpectedRuntimeKernelSteps,
                confidentialKernelSlotExprListExpectedRuntimeKernelSteps,
                confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps expr env slotExpr hExpr,
                confidentialKernelExprsToSlotExprs_expectedRuntimeKernelSteps
                  exprs env slotExprs' hRest]

theorem confidentialKernelPureExprsToSlotPureExprs_expectedRuntimeKernelSteps
  : (exprs : List ConfidentialKernelPureExpr) →
      (env : ConfidentialKernelSlotEnv) →
      (slotExprs : List ConfidentialKernelSlotPureExpr) →
      confidentialKernelPureExprsToSlotPureExprs exprs env = .ok slotExprs →
        confidentialKernelPureExprListExpectedRuntimeKernelSteps exprs =
          confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps slotExprs
  | [], _, _, h => by
      simp [confidentialKernelPureExprsToSlotPureExprs] at h
      cases h
      rfl
  | expr :: exprs, env, slotExprs, h => by
      cases hExpr : confidentialKernelPureExprToSlotPureExpr expr env with
      | error err =>
          simp [confidentialKernelPureExprsToSlotPureExprs, hExpr] at h
          cases h
      | ok slotExpr =>
          cases hRest : confidentialKernelPureExprsToSlotPureExprs exprs env with
          | error err =>
              simp [confidentialKernelPureExprsToSlotPureExprs, hExpr, hRest] at h
              cases h
          | ok slotExprs' =>
              simp [confidentialKernelPureExprsToSlotPureExprs, hExpr, hRest] at h
              cases h
              simp [confidentialKernelPureExprListExpectedRuntimeKernelSteps,
                confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps,
                confidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                  expr env slotExpr hExpr,
                confidentialKernelPureExprsToSlotPureExprs_expectedRuntimeKernelSteps
                  exprs env slotExprs' hRest]

end

theorem confidentialKernelStatementToSlotStatement_expectedRuntimeKernelSteps
  (entrypoint : String)
  (stmt : ConfidentialKernelStatement)
  (env env' : ConfidentialKernelSlotEnv)
  (slotStmt : ConfidentialKernelSlotStatement)
  (h :
    confidentialKernelStatementToSlotStatement entrypoint stmt env =
      .ok (slotStmt, env')) :
  stmt.expectedRuntimeKernelSteps = slotStmt.expectedRuntimeKernelSteps := by
  cases stmt with
  | declare name ty value =>
      cases hDeclare : confidentialKernelSlotEnvDeclare entrypoint env name with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hDeclare] at h
          cases h
      | ok declared =>
          cases declared with
          | mk slot declaredEnv =>
              cases hValue : confidentialKernelExprToSlotExpr value declaredEnv with
              | error err =>
                  have hConcrete :
                      confidentialKernelStatementToSlotStatement
                          entrypoint (.declare name ty value) env = Except.error err := by
                    let f := fun a => (ConfidentialKernelSlotStatement.declare slot a, declaredEnv)
                    have hMap := congrArg (Except.map f) hValue
                    simpa [confidentialKernelStatementToSlotStatement, Except.bind, Except.map,
                      hDeclare, f] using hMap
                  rw [hConcrete] at h
                  cases h
              | ok slotValue =>
                  have hConcrete :
                      confidentialKernelStatementToSlotStatement
                          entrypoint (.declare name ty value) env =
                        Except.ok (ConfidentialKernelSlotStatement.declare slot slotValue, declaredEnv) := by
                    let f := fun a => (ConfidentialKernelSlotStatement.declare slot a, declaredEnv)
                    have hMap := congrArg (Except.map f) hValue
                    simpa [confidentialKernelStatementToSlotStatement, Except.bind, Except.map,
                      hDeclare, f] using hMap
                  have hOk :
                      (Except.ok (ConfidentialKernelSlotStatement.declare slot slotValue, declaredEnv) :
                        Except String (ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv)) =
                      Except.ok (slotStmt, env') := by
                    exact hConcrete.symm.trans h
                  injection hOk with hPair
                  cases hPair
                  exact confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                    value env' slotValue hValue
  | assign name value =>
      cases hResolve : confidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hResolve] at h
          cases h
      | ok slot =>
          cases hValue : confidentialKernelExprToSlotExpr value env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hResolve, hValue] at h
              cases h
          | ok slotValue =>
              simp [confidentialKernelStatementToSlotStatement, hResolve, hValue] at h
              cases h
              simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps value env slotValue hValue]
  | require cond =>
      cases hCond : confidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
      | ok slotCond =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
          simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
            confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps cond env slotCond hCond]
  | abortIf cond =>
      cases hCond : confidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
      | ok slotCond =>
          simp [confidentialKernelStatementToSlotStatement, hCond] at h
          cases h
          simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
            ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
            confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps cond env slotCond hCond]
  | cellSet objectId value predicate =>
      cases predicate with
      | none =>
          cases hValue : confidentialKernelExprToSlotExpr value env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hValue] at h
              cases h
          | ok slotValue =>
              simp [confidentialKernelStatementToSlotStatement, hValue] at h
              cases h
              simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                  value env slotValue hValue]
      | some cond =>
          cases hPredicate : confidentialKernelExprToSlotExpr cond env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hPredicate] at h
              cases h
          | ok slotPredicate =>
              cases hValue : confidentialKernelExprToSlotExpr value env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hPredicate, hValue] at h
                  cases h
              | ok slotValue =>
                  simp [confidentialKernelStatementToSlotStatement, hPredicate, hValue] at h
                  cases h
                  simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                    ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      value env slotValue hValue,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      cond env slotPredicate hPredicate]
  | arraySet objectId index value predicate =>
      cases predicate with
      | none =>
          cases hIndex : confidentialKernelExprToSlotExpr index env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hIndex] at h
              cases h
          | ok slotIndex =>
              cases hValue : confidentialKernelExprToSlotExpr value env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hIndex, hValue] at h
                  cases h
              | ok slotValue =>
                  simp [confidentialKernelStatementToSlotStatement, hIndex, hValue] at h
                  cases h
                  simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                    ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      index env slotIndex hIndex,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      value env slotValue hValue]
      | some cond =>
          cases hPredicate : confidentialKernelExprToSlotExpr cond env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hPredicate] at h
              cases h
          | ok slotPredicate =>
              cases hIndex : confidentialKernelExprToSlotExpr index env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hPredicate, hIndex] at h
                  cases h
              | ok slotIndex =>
                  cases hValue : confidentialKernelExprToSlotExpr value env with
                  | error err =>
                      simp [confidentialKernelStatementToSlotStatement, hPredicate, hIndex, hValue] at h
                      cases h
                  | ok slotValue =>
                      simp [confidentialKernelStatementToSlotStatement, hPredicate, hIndex, hValue] at h
                      cases h
                      simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                        ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                        confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          cond env slotPredicate hPredicate,
                        confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          index env slotIndex hIndex,
                        confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          value env slotValue hValue]
  | mapPut objectId key value predicate =>
      cases predicate with
      | none =>
          cases hKey : confidentialKernelExprToSlotExpr key env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hKey] at h
              cases h
          | ok slotKey =>
              cases hValue : confidentialKernelExprToSlotExpr value env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hKey, hValue] at h
                  cases h
              | ok slotValue =>
                  simp [confidentialKernelStatementToSlotStatement, hKey, hValue] at h
                  cases h
                  simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                    ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      key env slotKey hKey,
                    confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      value env slotValue hValue]
      | some cond =>
          cases hPredicate : confidentialKernelExprToSlotExpr cond env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hPredicate] at h
              cases h
          | ok slotPredicate =>
              cases hKey : confidentialKernelExprToSlotExpr key env with
              | error err =>
                  simp [confidentialKernelStatementToSlotStatement, hPredicate, hKey] at h
                  cases h
              | ok slotKey =>
                  cases hValue : confidentialKernelExprToSlotExpr value env with
                  | error err =>
                      simp [confidentialKernelStatementToSlotStatement, hPredicate, hKey, hValue] at h
                      cases h
                  | ok slotValue =>
                      simp [confidentialKernelStatementToSlotStatement, hPredicate, hKey, hValue] at h
                      cases h
                      simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                        ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                        confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          cond env slotPredicate hPredicate,
                        confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          key env slotKey hKey,
                        confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          value env slotValue hValue]
  | ret value =>
      cases value with
      | none =>
          simp [confidentialKernelStatementToSlotStatement] at h
          cases h
          rfl
      | some expr =>
          cases hExpr : confidentialKernelExprToSlotExpr expr env with
          | error err =>
              simp [confidentialKernelStatementToSlotStatement, hExpr] at h
              cases h
          | ok slotExpr =>
              simp [confidentialKernelStatementToSlotStatement, hExpr] at h
              cases h
              simp [ConfidentialKernelStatement.expectedRuntimeKernelSteps,
                ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                confidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps expr env slotExpr hExpr]

theorem confidentialKernelStatementsToSlotStatements_expectedRuntimeKernelSteps
  (entrypoint : String)
  (stmts : List ConfidentialKernelStatement)
  (env env' : ConfidentialKernelSlotEnv)
  (slotStmts : List ConfidentialKernelSlotStatement)
  (h :
    confidentialKernelStatementsToSlotStatements entrypoint stmts env =
      .ok (slotStmts, env')) :
  confidentialKernelStatementListExpectedRuntimeKernelSteps stmts =
    confidentialKernelSlotStatementListExpectedRuntimeKernelSteps slotStmts := by
  induction stmts generalizing env env' slotStmts with
  | nil =>
      simp [confidentialKernelStatementsToSlotStatements] at h
      cases h
      rfl
  | cons stmt rest ih =>
      cases hStmt :
          confidentialKernelStatementToSlotStatement entrypoint stmt env with
      | error err =>
          simp [confidentialKernelStatementsToSlotStatements, hStmt] at h
          cases h
      | ok stmtResult =>
          cases stmtResult with
          | mk slotStmt env1 =>
              cases hRest :
                  confidentialKernelStatementsToSlotStatements entrypoint rest env1 with
              | error err =>
                  have hConcrete :
                      confidentialKernelStatementsToSlotStatements entrypoint (stmt :: rest) env =
                        Except.error err := by
                    let f :
                        (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) →
                          (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) :=
                      fun a => (slotStmt :: a.1, a.2)
                    have hMap := congrArg (Except.map f) hRest
                    simpa [confidentialKernelStatementsToSlotStatements, Except.bind, Except.map,
                      hStmt, f] using hMap
                  rw [hConcrete] at h
                  cases h
              | ok restResult =>
                  cases restResult with
                  | mk slotRest env2 =>
                      have hConcrete :
                          confidentialKernelStatementsToSlotStatements entrypoint (stmt :: rest) env =
                            Except.ok (slotStmt :: slotRest, env2) := by
                        let f :
                            (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) →
                              (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) :=
                          fun a => (slotStmt :: a.1, a.2)
                        have hMap := congrArg (Except.map f) hRest
                        simpa [confidentialKernelStatementsToSlotStatements, Except.bind, Except.map,
                          hStmt, f] using hMap
                      have hOk :
                          (Except.ok (slotStmt :: slotRest, env2) :
                            Except String
                              (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv)) =
                          (Except.ok (slotStmts, env') :
                            Except String
                              (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv)) := by
                        exact hConcrete.symm.trans h
                      injection hOk with hPair
                      cases hPair
                      simp [confidentialKernelStatementListExpectedRuntimeKernelSteps,
                        confidentialKernelSlotStatementListExpectedRuntimeKernelSteps,
                        confidentialKernelStatementToSlotStatement_expectedRuntimeKernelSteps
                          entrypoint stmt env env1 slotStmt hStmt,
                        ih env1 env' slotRest hRest]

theorem confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps
  {program : ConfidentialKernelProgram}
  {slotProgram : ConfidentialKernelSlotProgram}
  (h : program.SlotLoweringMatches slotProgram) :
  program.expectedRuntimeKernelSteps = slotProgram.expectedRuntimeKernelSteps := by
  unfold ConfidentialKernelProgram.SlotLoweringMatches at h
  cases hEnv : confidentialKernelParamsToSlotEnv program.entrypointId program.params with
  | error err =>
      simp [ConfidentialKernelProgram.toConfidentialKernelSlotProgram?, hEnv] at h
      cases h
  | ok env =>
      cases hBody :
          confidentialKernelStatementsToSlotStatements program.entrypointId program.body env with
      | error err =>
          have hConcrete :
              program.toConfidentialKernelSlotProgram? = Except.error err := by
            let f :
                (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) →
                  ConfidentialKernelSlotProgram :=
              fun a =>
                { entrypointId := program.entrypointId
                , paramCount := program.params.length
                , returnType := program.returnType
                , secretArgs := program.secretArgs
                , slotCount := a.2.length
                , body := a.1
                }
            have hMap := congrArg (Except.map f) hBody
            simpa [ConfidentialKernelProgram.toConfidentialKernelSlotProgram?, Except.bind, Except.map,
              hEnv, f] using hMap
          rw [hConcrete] at h
          cases h
      | ok bodyResult =>
          cases bodyResult with
          | mk body env' =>
              have hConcrete :
                  program.toConfidentialKernelSlotProgram? =
                    Except.ok
                      { entrypointId := program.entrypointId
                      , paramCount := program.params.length
                      , returnType := program.returnType
                      , secretArgs := program.secretArgs
                      , slotCount := env'.length
                      , body := body
                      } := by
                let f :
                    (List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv) →
                      ConfidentialKernelSlotProgram :=
                  fun a =>
                    { entrypointId := program.entrypointId
                    , paramCount := program.params.length
                    , returnType := program.returnType
                    , secretArgs := program.secretArgs
                    , slotCount := a.2.length
                    , body := a.1
                    }
                have hMap := congrArg (Except.map f) hBody
                simpa [ConfidentialKernelProgram.toConfidentialKernelSlotProgram?, Except.bind, Except.map,
                  hEnv, f] using hMap
              have hOk :
                  (Except.ok
                    { entrypointId := program.entrypointId
                    , paramCount := program.params.length
                    , returnType := program.returnType
                    , secretArgs := program.secretArgs
                    , slotCount := env'.length
                    , body := body
                    } : Except String ConfidentialKernelSlotProgram) =
                  (Except.ok slotProgram : Except String ConfidentialKernelSlotProgram) := by
                exact hConcrete.symm.trans h
              injection hOk with hProgram
              cases hProgram
              simp [ConfidentialKernelProgram.expectedRuntimeKernelSteps,
                ConfidentialKernelSlotProgram.expectedRuntimeKernelSteps,
                confidentialKernelStatementsToSlotStatements_expectedRuntimeKernelSteps
                  program.entrypointId program.body env env' body hBody]

structure RuntimeKernelDslBundle where
  kernelWitness : RuntimeKernelWitness
  confidentialProgram : ConfidentialKernelProgram

def RuntimeKernelDslBundle.Valid
  (bundle : RuntimeKernelDslBundle) : Prop :=
  bundle.kernelWitness.ProofGradeValid bundle.confidentialProgram.entrypointId ∧
    bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps

theorem runtimeKernelDslBundle_schedule_exact
  {bundle : RuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps := by
  exact hValid.2

theorem runtimeKernelDslBundle_entrypoint_exact
  {bundle : RuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernelWitness.entrypointId = bundle.confidentialProgram.entrypointId := by
  exact hValid.1.1.1

structure RuntimeKernelSlotDslBundle where
  kernelWitness : RuntimeKernelWitness
  confidentialProgram : ConfidentialKernelSlotProgram

def RuntimeKernelSlotDslBundle.Valid
  (bundle : RuntimeKernelSlotDslBundle) : Prop :=
  bundle.kernelWitness.ProofGradeValid bundle.confidentialProgram.entrypointId ∧
    bundle.confidentialProgram.RuntimeNormalForm ∧
    bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps

theorem runtimeKernelSlotDslBundle_schedule_exact
  {bundle : RuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps := by
  exact hValid.2.2

theorem runtimeKernelSlotDslBundle_runtimeNormalForm
  {bundle : RuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.confidentialProgram.RuntimeNormalForm := by
  exact hValid.2.1

theorem runtimeKernelSlotDslBundle_entrypoint_exact
  {bundle : RuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernelWitness.entrypointId = bundle.confidentialProgram.entrypointId := by
  exact hValid.1.1.1

structure RuntimeKernelLoweringBundle where
  kernelWitness : RuntimeKernelWitness
  confidentialProgram : ConfidentialKernelProgram
  confidentialSlotProgram : ConfidentialKernelSlotProgram

def RuntimeKernelLoweringBundle.namedBundle
  (bundle : RuntimeKernelLoweringBundle) : RuntimeKernelDslBundle :=
  { kernelWitness := bundle.kernelWitness
  , confidentialProgram := bundle.confidentialProgram
  }

def RuntimeKernelLoweringBundle.slotBundle
  (bundle : RuntimeKernelLoweringBundle) : RuntimeKernelSlotDslBundle :=
  { kernelWitness := bundle.kernelWitness
  , confidentialProgram := bundle.confidentialSlotProgram
  }

def RuntimeKernelLoweringBundle.Valid
  (bundle : RuntimeKernelLoweringBundle) : Prop :=
  bundle.namedBundle.Valid ∧
    bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram

theorem runtimeKernelLoweringBundle_namedSchedule_exact
  {bundle : RuntimeKernelLoweringBundle}
  (hValid : bundle.Valid) :
  bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps := by
  exact runtimeKernelDslBundle_schedule_exact hValid.1

theorem runtimeKernelLoweringBundle_proofGradeAssurance
  (bundle : RuntimeKernelLoweringBundle)
  (hValid : bundle.Valid) :
  bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.expectedKernelSteps =
      some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.kernelWitness.kernelSteps =
      bundle.confidentialSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.confidentialProgram.SlotLoweringMatches bundle.confidentialSlotProgram := by
  have hStepEq :
      bundle.confidentialProgram.expectedRuntimeKernelSteps =
        bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    exact confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps hValid.2
  have hNamed :=
    runtimeKernelLoweringBundle_namedSchedule_exact hValid
  have hSlotExpected :
      bundle.kernelWitness.expectedKernelSteps =
        some bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    simpa [hStepEq] using hNamed.1
  have hSlotSteps :
      bundle.kernelWitness.kernelSteps =
        bundle.confidentialSlotProgram.expectedRuntimeKernelSteps := by
    simpa [hStepEq] using hNamed.2
  exact ⟨hNamed.1, hNamed.2, hSlotExpected, hSlotSteps, hValid.2⟩

end UOToolchain
