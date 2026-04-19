import Lean.Data.Json
import UOToolchain.ConfidentialKernelDsl
import UOToolchain.RuntimeRefinementJson

open Lean

namespace UOToolchain

structure ImportedConfidentialKernelParam where
  name : String
  ty : Json
deriving FromJson

def importedConfidentialKernelStatementKindNames : List String :=
  ["declare", "assign", "require", "abort_if", "cell_set", "array_set", "map_put", "return"]

def importedConfidentialKernelExprKindNames : List String :=
  ["literal", "var", "unary", "binary", "select", "cell_get", "array_get", "map_get", "keccak256"]

def importedConfidentialKernelPureExprKindNames : List String :=
  ["literal", "var", "unary", "binary", "select", "keccak256"]

def importedConfidentialKernelParamFieldNames : List String :=
  ["name", "ty"]

def importedConfidentialKernelProgramFieldNames : List String :=
  ["entrypoint_id", "params", "return_type", "secret_args", "body"]

mutual

inductive ImportedConfidentialKernelStatement where
  | declare (name : String) (ty : Json) (value : ImportedConfidentialKernelExpr)
  | assign (name : String) (value : ImportedConfidentialKernelExpr)
  | require (cond : ImportedConfidentialKernelExpr)
  | abortIf (cond : ImportedConfidentialKernelExpr)
  | cellSet
      (objectId : Nat)
      (value : ImportedConfidentialKernelExpr)
      (predicate : Option ImportedConfidentialKernelExpr)
  | arraySet
      (objectId : Nat)
      (index : ImportedConfidentialKernelExpr)
      (value : ImportedConfidentialKernelExpr)
      (predicate : Option ImportedConfidentialKernelExpr)
  | mapPut
      (objectId : Nat)
      (key : ImportedConfidentialKernelExpr)
      (value : ImportedConfidentialKernelExpr)
      (predicate : Option ImportedConfidentialKernelExpr)
  | ret (value : Option ImportedConfidentialKernelExpr)


inductive ImportedConfidentialKernelExpr where
  | literal (value : Json)
  | var (name : String)
  | unary (op : Json) (expr : ImportedConfidentialKernelExpr)
  | binary (op : Json) (lhs rhs : ImportedConfidentialKernelExpr)
  | select
      (cond : ImportedConfidentialKernelExpr)
      (whenTrue whenFalse : ImportedConfidentialKernelPureExpr)
  | cellGet (objectId : Nat)
  | arrayGet (objectId : Nat) (index : ImportedConfidentialKernelExpr)
  | mapGet (objectId : Nat) (key : ImportedConfidentialKernelExpr)
  | keccak256 (parts : List ImportedConfidentialKernelExpr)


inductive ImportedConfidentialKernelPureExpr where
  | literal (value : Json)
  | var (name : String)
  | unary (op : Json) (expr : ImportedConfidentialKernelPureExpr)
  | binary (op : Json) (lhs rhs : ImportedConfidentialKernelPureExpr)
  | select
      (cond : ImportedConfidentialKernelPureExpr)
      (whenTrue whenFalse : ImportedConfidentialKernelPureExpr)
  | keccak256 (parts : List ImportedConfidentialKernelPureExpr)
 
end

mutual
private partial def parseImportedConfidentialKernelStatement
  (json : Json) : Except String ImportedConfidentialKernelStatement := do
  let kind ← json.getObjValAs? String "kind"
  match kind with
  | "declare" =>
      pure <| .declare
        (← json.getObjValAs? String "name")
        (← json.getObjValAs? Json "ty")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "value"))
  | "assign" =>
      pure <| .assign
        (← json.getObjValAs? String "name")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "value"))
  | "require" =>
      pure <| .require
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "cond"))
  | "abort_if" =>
      pure <| .abortIf
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "cond"))
  | "cell_set" =>
      pure <| .cellSet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "value"))
        (← parseOptionalImportedConfidentialKernelExprField json "predicate")
  | "array_set" =>
      pure <| .arraySet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "index"))
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "value"))
        (← parseOptionalImportedConfidentialKernelExprField json "predicate")
  | "map_put" =>
      pure <| .mapPut
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "key"))
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "value"))
        (← parseOptionalImportedConfidentialKernelExprField json "predicate")
  | "return" =>
      pure <| .ret (← parseOptionalImportedConfidentialKernelExprField json "value")
  | other =>
      throw s!"unexpected confidential kernel statement kind '{other}'"

private partial def parseImportedConfidentialKernelExpr
  (json : Json) : Except String ImportedConfidentialKernelExpr := do
  let kind ← json.getObjValAs? String "kind"
  match kind with
  | "literal" =>
      pure <| .literal (← json.getObjValAs? Json "value")
  | "var" =>
      pure <| .var (← json.getObjValAs? String "name")
  | "unary" =>
      pure <| .unary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "expr"))
  | "binary" =>
      pure <| .binary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "lhs"))
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "rhs"))
  | "select" =>
      pure <| .select
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "cond"))
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "when_true"))
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "when_false"))
  | "cell_get" =>
      pure <| .cellGet (← json.getObjValAs? Nat "object_id")
  | "array_get" =>
      pure <| .arrayGet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "index"))
  | "map_get" =>
      pure <| .mapGet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelExpr (← json.getObjValAs? Json "key"))
  | "keccak256" =>
      pure <| .keccak256
        (← parseImportedConfidentialKernelExprList (← json.getObjValAs? (List Json) "parts"))
  | other =>
      throw s!"unexpected confidential kernel expression kind '{other}'"

private partial def parseImportedConfidentialKernelPureExpr
  (json : Json) : Except String ImportedConfidentialKernelPureExpr := do
  let kind ← json.getObjValAs? String "kind"
  match kind with
  | "literal" =>
      pure <| .literal (← json.getObjValAs? Json "value")
  | "var" =>
      pure <| .var (← json.getObjValAs? String "name")
  | "unary" =>
      pure <| .unary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "expr"))
  | "binary" =>
      pure <| .binary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "lhs"))
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "rhs"))
  | "select" =>
      pure <| .select
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "cond"))
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "when_true"))
        (← parseImportedConfidentialKernelPureExpr (← json.getObjValAs? Json "when_false"))
  | "keccak256" =>
      pure <| .keccak256
        (← parseImportedConfidentialKernelPureExprList (← json.getObjValAs? (List Json) "parts"))
  | other =>
      throw s!"unexpected confidential kernel pure expression kind '{other}'"

private partial def parseImportedConfidentialKernelExprList
  (items : List Json) : Except String (List ImportedConfidentialKernelExpr) :=
  items.mapM parseImportedConfidentialKernelExpr

private partial def parseImportedConfidentialKernelPureExprList
  (items : List Json) : Except String (List ImportedConfidentialKernelPureExpr) :=
  items.mapM parseImportedConfidentialKernelPureExpr

private partial def parseOptionalImportedConfidentialKernelExprField
  (json : Json)
  (field : String) : Except String (Option ImportedConfidentialKernelExpr) := do
  let value? ← json.getObjValAs? (Option Json) field
  match value? with
  | none => pure none
  | some value => some <$> parseImportedConfidentialKernelExpr value
end

instance : FromJson ImportedConfidentialKernelStatement where
  fromJson? := parseImportedConfidentialKernelStatement

instance : FromJson ImportedConfidentialKernelExpr where
  fromJson? := parseImportedConfidentialKernelExpr

instance : FromJson ImportedConfidentialKernelPureExpr where
  fromJson? := parseImportedConfidentialKernelPureExpr

structure ImportedConfidentialKernelProgram where
  entrypoint_id : String
  params : List ImportedConfidentialKernelParam
  return_type : Option Json
  secret_args : List Nat
  body : List ImportedConfidentialKernelStatement
deriving FromJson

def ImportedConfidentialKernelParam.toConfidentialKernelParam
  (param : ImportedConfidentialKernelParam) : ConfidentialKernelParam :=
  { name := param.name
  , ty := param.ty
  }

mutual

def ImportedConfidentialKernelStatement.toConfidentialKernelStatement :
  ImportedConfidentialKernelStatement → ConfidentialKernelStatement
  | .declare name ty value =>
      .declare name ty value.toConfidentialKernelExpr
  | .assign name value =>
      .assign name value.toConfidentialKernelExpr
  | .require cond =>
      .require cond.toConfidentialKernelExpr
  | .abortIf cond =>
      .abortIf cond.toConfidentialKernelExpr
  | .cellSet objectId value predicate =>
      .cellSet objectId value.toConfidentialKernelExpr
        (predicate.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr)
  | .arraySet objectId index value predicate =>
      .arraySet objectId index.toConfidentialKernelExpr value.toConfidentialKernelExpr
        (predicate.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr)
  | .mapPut objectId key value predicate =>
      .mapPut objectId key.toConfidentialKernelExpr value.toConfidentialKernelExpr
        (predicate.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr)
  | .ret value =>
      .ret (value.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr)

def ImportedConfidentialKernelExpr.toConfidentialKernelExpr :
  ImportedConfidentialKernelExpr → ConfidentialKernelExpr
  | .literal value =>
      .literal value
  | .var name =>
      .var name
  | .unary op expr =>
      .unary op expr.toConfidentialKernelExpr
  | .binary op lhs rhs =>
      .binary op lhs.toConfidentialKernelExpr rhs.toConfidentialKernelExpr
  | .select cond whenTrue whenFalse =>
      .select cond.toConfidentialKernelExpr
        whenTrue.toConfidentialKernelPureExpr
        whenFalse.toConfidentialKernelPureExpr
  | .cellGet objectId =>
      .cellGet objectId
  | .arrayGet objectId index =>
      .arrayGet objectId index.toConfidentialKernelExpr
  | .mapGet objectId key =>
      .mapGet objectId key.toConfidentialKernelExpr
  | .keccak256 parts =>
      .keccak256 (parts.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr)

def ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr :
  ImportedConfidentialKernelPureExpr → ConfidentialKernelPureExpr
  | .literal value =>
      .literal value
  | .var name =>
      .var name
  | .unary op expr =>
      .unary op expr.toConfidentialKernelPureExpr
  | .binary op lhs rhs =>
      .binary op lhs.toConfidentialKernelPureExpr rhs.toConfidentialKernelPureExpr
  | .select cond whenTrue whenFalse =>
      .select cond.toConfidentialKernelPureExpr
        whenTrue.toConfidentialKernelPureExpr
        whenFalse.toConfidentialKernelPureExpr
  | .keccak256 parts =>
      .keccak256 (parts.map ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr)

end

def ImportedConfidentialKernelProgram.toConfidentialKernelProgram
  (program : ImportedConfidentialKernelProgram) : ConfidentialKernelProgram :=
  { entrypointId := program.entrypoint_id
  , params := program.params.map ImportedConfidentialKernelParam.toConfidentialKernelParam
  , returnType := program.return_type
  , secretArgs := program.secret_args
  , body := program.body.map ImportedConfidentialKernelStatement.toConfidentialKernelStatement
  }

def importedRuntimeKernelStep
  (opcode : String)
  (objectId : Option Nat := none) : ImportedRuntimeKernelStep :=
  { opcode := opcode
  , object_id := objectId
  }

mutual

def ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps :
  ImportedConfidentialKernelStatement → List ImportedRuntimeKernelStep
  | .declare _ _ value => value.expectedRuntimeKernelSteps
  | .assign _ value => value.expectedRuntimeKernelSteps
  | .require cond => cond.expectedRuntimeKernelSteps
  | .abortIf cond => cond.expectedRuntimeKernelSteps
  | .cellSet objectId value predicate =>
      value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [importedRuntimeKernelStep "CellSet" (some objectId)]
  | .arraySet objectId index value predicate =>
      index.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [importedRuntimeKernelStep "ArraySet" (some objectId)]
  | .mapPut objectId key value predicate =>
      key.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [importedRuntimeKernelStep "MapPut" (some objectId)]
  | .ret value? =>
      match value? with
      | none => []
      | some value => value.expectedRuntimeKernelSteps

def ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps :
  ImportedConfidentialKernelExpr → List ImportedRuntimeKernelStep
  | .literal _ => []
  | .var _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond _ _ => cond.expectedRuntimeKernelSteps
  | .cellGet objectId => [importedRuntimeKernelStep "CellGet" (some objectId)]
  | .arrayGet objectId index =>
      index.expectedRuntimeKernelSteps ++ [importedRuntimeKernelStep "ArrayGet" (some objectId)]
  | .mapGet objectId key =>
      key.expectedRuntimeKernelSteps ++ [importedRuntimeKernelStep "MapGet" (some objectId)]
  | .keccak256 parts =>
      importedConfidentialKernelExprListExpectedRuntimeKernelSteps parts

def ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps :
  ImportedConfidentialKernelPureExpr → List ImportedRuntimeKernelStep
  | .literal _ => []
  | .var _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond whenTrue whenFalse =>
      cond.expectedRuntimeKernelSteps ++
        whenTrue.expectedRuntimeKernelSteps ++
        whenFalse.expectedRuntimeKernelSteps
  | .keccak256 parts =>
      importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps parts

def importedConfidentialKernelExprListExpectedRuntimeKernelSteps :
  List ImportedConfidentialKernelExpr → List ImportedRuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        importedConfidentialKernelExprListExpectedRuntimeKernelSteps exprs

def importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps :
  List ImportedConfidentialKernelPureExpr → List ImportedRuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps exprs

def importedConfidentialKernelStatementListExpectedRuntimeKernelSteps :
  List ImportedConfidentialKernelStatement → List ImportedRuntimeKernelStep
  | [] => []
  | stmt :: stmts =>
      stmt.expectedRuntimeKernelSteps ++
        importedConfidentialKernelStatementListExpectedRuntimeKernelSteps stmts

end

def ImportedConfidentialKernelProgram.expectedRuntimeKernelSteps
  (program : ImportedConfidentialKernelProgram) : List ImportedRuntimeKernelStep :=
  [importedRuntimeKernelStep "Begin"] ++
    importedConfidentialKernelStatementListExpectedRuntimeKernelSteps program.body ++
    [importedRuntimeKernelStep "Commit", importedRuntimeKernelStep "Wipe"]

@[simp] theorem importedRuntimeKernelStep_toRuntime_eq
  (opcode : String)
  (objectId : Option Nat := none) :
  (importedRuntimeKernelStep opcode objectId).toRuntimeKernelStep =
    confidentialKernelRuntimeKernelStep opcode objectId := by
  rfl

mutual

theorem importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime :
  (expr : ImportedConfidentialKernelExpr) →
    expr.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      expr.toConfidentialKernelExpr.expectedRuntimeKernelSteps
  | .literal value => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps]
  | .var name => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps]
  | .unary op expr => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime expr]
  | .binary op lhs rhs => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime lhs,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime rhs]
  | .select cond whenTrue whenFalse => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime cond]
  | .cellGet objectId => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps]
  | .arrayGet objectId index => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime index]
  | .mapGet objectId key => by
      simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime key]
  | .keccak256 parts => by
      simpa [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
        ConfidentialKernelExpr.expectedRuntimeKernelSteps] using
        importedConfidentialKernelExprListExpectedRuntimeKernelSteps_toRuntime parts
termination_by expr => sizeOf expr

theorem importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime :
  (expr : ImportedConfidentialKernelPureExpr) →
    expr.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      expr.toConfidentialKernelPureExpr.expectedRuntimeKernelSteps
  | .literal value => by
      simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
        ConfidentialKernelPureExpr.expectedRuntimeKernelSteps]
  | .var name => by
      simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
        ConfidentialKernelPureExpr.expectedRuntimeKernelSteps]
  | .unary op expr => by
      simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
        ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime expr]
  | .binary op lhs rhs => by
      simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
        ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime lhs,
        importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime rhs]
  | .select cond whenTrue whenFalse => by
      simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
        ConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime cond,
        importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime whenTrue,
        importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime whenFalse]
  | .keccak256 parts => by
      simpa [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
        ConfidentialKernelPureExpr.expectedRuntimeKernelSteps] using
        importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps_toRuntime parts
termination_by expr => sizeOf expr

theorem importedConfidentialKernelExprListExpectedRuntimeKernelSteps_toRuntime
  : (exprs : List ImportedConfidentialKernelExpr) →
      (importedConfidentialKernelExprListExpectedRuntimeKernelSteps exprs).map
          ImportedRuntimeKernelStep.toRuntimeKernelStep =
        confidentialKernelExprListExpectedRuntimeKernelSteps
          (exprs.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr)
  | [] => by
      simp [importedConfidentialKernelExprListExpectedRuntimeKernelSteps,
        confidentialKernelExprListExpectedRuntimeKernelSteps]
  | expr :: exprs => by
      have hHead := importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime expr
      have hTail := importedConfidentialKernelExprListExpectedRuntimeKernelSteps_toRuntime exprs
      simp [importedConfidentialKernelExprListExpectedRuntimeKernelSteps,
        confidentialKernelExprListExpectedRuntimeKernelSteps,
        hHead, hTail]
termination_by exprs => sizeOf exprs

theorem importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps_toRuntime
  : (exprs : List ImportedConfidentialKernelPureExpr) →
      (importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps exprs).map
          ImportedRuntimeKernelStep.toRuntimeKernelStep =
        confidentialKernelPureExprListExpectedRuntimeKernelSteps
          (exprs.map ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr)
  | [] => by
      simp [importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps,
        confidentialKernelPureExprListExpectedRuntimeKernelSteps]
  | expr :: exprs => by
      have hHead := importedConfidentialKernelPureExpr_expectedRuntimeKernelSteps_toRuntime expr
      have hTail := importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps_toRuntime exprs
      simp [importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps,
        confidentialKernelPureExprListExpectedRuntimeKernelSteps,
        hHead, hTail]
termination_by exprs => sizeOf exprs

decreasing_by
  all_goals simp_wf
  all_goals omega

end

theorem importedConfidentialKernelStatement_expectedRuntimeKernelSteps_toRuntime
  (stmt : ImportedConfidentialKernelStatement) :
  stmt.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
    stmt.toConfidentialKernelStatement.expectedRuntimeKernelSteps := by
  cases stmt with
  | declare name ty value =>
      simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        ConfidentialKernelStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | assign name value =>
      simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        ConfidentialKernelStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | require cond =>
      simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        ConfidentialKernelStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | abortIf cond =>
      simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        ConfidentialKernelStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | cellSet objectId value predicate =>
      cases predicate <;>
        simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
          ConfidentialKernelStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | arraySet objectId index value predicate =>
      cases predicate <;>
        simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
          ConfidentialKernelStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | mapPut objectId key value predicate =>
      cases predicate <;>
        simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
          ConfidentialKernelStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]
  | ret value =>
      cases value <;>
        simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
          ConfidentialKernelStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelExpr_expectedRuntimeKernelSteps_toRuntime]

theorem importedConfidentialKernelStatementListExpectedRuntimeKernelSteps_toRuntime
  (stmts : List ImportedConfidentialKernelStatement) :
  (importedConfidentialKernelStatementListExpectedRuntimeKernelSteps stmts).map
      ImportedRuntimeKernelStep.toRuntimeKernelStep =
    confidentialKernelStatementListExpectedRuntimeKernelSteps
      (stmts.map ImportedConfidentialKernelStatement.toConfidentialKernelStatement) := by
  induction stmts with
  | nil =>
      simp [importedConfidentialKernelStatementListExpectedRuntimeKernelSteps,
        confidentialKernelStatementListExpectedRuntimeKernelSteps]
  | cons stmt stmts ih =>
      simp [importedConfidentialKernelStatementListExpectedRuntimeKernelSteps,
        confidentialKernelStatementListExpectedRuntimeKernelSteps,
        importedConfidentialKernelStatement_expectedRuntimeKernelSteps_toRuntime, ih]

theorem importedConfidentialKernelProgram_expectedRuntimeKernelSteps_toRuntime
  (program : ImportedConfidentialKernelProgram) :
  program.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
    program.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
  cases program with
  | mk entrypoint_id params return_type secret_args body =>
      simp [ImportedConfidentialKernelProgram.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelProgram.toConfidentialKernelProgram,
        ConfidentialKernelProgram.expectedRuntimeKernelSteps,
        importedConfidentialKernelStatementListExpectedRuntimeKernelSteps_toRuntime]

structure ImportedRuntimeKernelDslBundle where
  kernel_witness : ImportedRuntimeKernelWitness
  confidential_program : ImportedConfidentialKernelProgram
deriving FromJson

def ImportedRuntimeKernelDslBundle.programSteps
  (bundle : ImportedRuntimeKernelDslBundle) : List ImportedRuntimeKernelStep :=
  bundle.confidential_program.expectedRuntimeKernelSteps

def ImportedRuntimeKernelDslBundle.Valid
  (bundle : ImportedRuntimeKernelDslBundle) : Prop :=
  bundle.kernel_witness.ProofGradeValid bundle.confidential_program.entrypoint_id ∧
    bundle.kernel_witness.expected_kernel_steps = some bundle.programSteps ∧
    bundle.kernel_witness.kernel_steps = bundle.programSteps

def ImportedRuntimeKernelDslBundle.checkValid
  (bundle : ImportedRuntimeKernelDslBundle) : Bool :=
  bundle.kernel_witness.checkProofGrade bundle.confidential_program.entrypoint_id &&
    decide (bundle.kernel_witness.expected_kernel_steps = some bundle.programSteps) &&
    decide (bundle.kernel_witness.kernel_steps = bundle.programSteps)

@[simp] theorem importedRuntimeKernelDslBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeKernelDslBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeKernelDslBundle.checkValid ImportedRuntimeKernelDslBundle.Valid
  simp [importedRuntimeKernelWitness_checkProofGrade_eq_true_iff, and_assoc]

theorem importedRuntimeKernelDslBundle_schedule_exact
  {bundle : ImportedRuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.expected_kernel_steps = some bundle.programSteps ∧
    bundle.kernel_witness.kernel_steps = bundle.programSteps := by
  exact hValid.2

theorem importedRuntimeKernelDslBundle_toRuntimeSchedule_exact
  {bundle : ImportedRuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
      some bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
    bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
      bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
  rcases importedRuntimeKernelDslBundle_schedule_exact hValid with ⟨hExpected, hKernel⟩
  have hProgram :
      bundle.programSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
        bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
    simpa [ImportedRuntimeKernelDslBundle.programSteps] using
      importedConfidentialKernelProgram_expectedRuntimeKernelSteps_toRuntime
        bundle.confidential_program
  constructor
  · simpa [ImportedRuntimeKernelWitness.toRuntimeKernelWitness, hProgram] using
      congrArg (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep)) hExpected
  · simpa [ImportedRuntimeKernelWitness.toRuntimeKernelWitness, hProgram] using
      congrArg (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep) hKernel

theorem importedRuntimeKernelDslBundle_entrypoint_exact
  {bundle : ImportedRuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.entrypoint_id = bundle.confidential_program.entrypoint_id := by
  exact hValid.1.1.1

theorem importedRuntimeKernelDslBundle_toRuntimeEntrypoint_exact
  {bundle : ImportedRuntimeKernelDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.entrypointId =
    bundle.confidential_program.toConfidentialKernelProgram.entrypointId := by
  simpa [ImportedRuntimeKernelWitness.toRuntimeKernelWitness,
    ImportedConfidentialKernelProgram.toConfidentialKernelProgram] using
    importedRuntimeKernelDslBundle_entrypoint_exact hValid

def parseImportedRuntimeKernelDslBundle
  (input : String) : Except String ImportedRuntimeKernelDslBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeKernelDslBundle
  (input : String) : Except String ImportedRuntimeKernelDslBundle := do
  let bundle ← parseImportedRuntimeKernelDslBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw "imported proof-grade runtime kernel DSL bundle does not satisfy Lean validity checks"

def loadImportedRuntimeKernelDslBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelDslBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelDslBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime kernel DSL bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelDslBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelDslBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelDslBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel DSL bundle: {err}"

def importedConfidentialKernelSlotStatementKindNames : List String :=
  ["declare", "assign", "require", "abort_if", "cell_set", "array_set", "map_put", "return"]

def importedConfidentialKernelSlotExprKindNames : List String :=
  ["literal", "slot", "unary", "binary", "select", "cell_get", "array_get", "map_get",
    "keccak256"]

def importedConfidentialKernelSlotPureExprKindNames : List String :=
  ["literal", "slot", "unary", "binary", "select", "keccak256"]

def importedConfidentialKernelSlotProgramFieldNames : List String :=
  ["entrypoint_id", "param_count", "return_type", "secret_args", "slot_count", "body"]

mutual

inductive ImportedConfidentialKernelSlotStatement where
  | declare (slot : Nat) (value : ImportedConfidentialKernelSlotExpr)
  | assign (slot : Nat) (value : ImportedConfidentialKernelSlotExpr)
  | require (cond : ImportedConfidentialKernelSlotExpr)
  | abortIf (cond : ImportedConfidentialKernelSlotExpr)
  | cellSet
      (objectId : Nat)
      (value : ImportedConfidentialKernelSlotExpr)
      (predicate : Option ImportedConfidentialKernelSlotExpr)
  | arraySet
      (objectId : Nat)
      (index : ImportedConfidentialKernelSlotExpr)
      (value : ImportedConfidentialKernelSlotExpr)
      (predicate : Option ImportedConfidentialKernelSlotExpr)
  | mapPut
      (objectId : Nat)
      (key : ImportedConfidentialKernelSlotExpr)
      (value : ImportedConfidentialKernelSlotExpr)
      (predicate : Option ImportedConfidentialKernelSlotExpr)
  | ret (value : Option ImportedConfidentialKernelSlotExpr)

inductive ImportedConfidentialKernelSlotExpr where
  | literal (value : Json)
  | slot (slot : Nat)
  | unary (op : Json) (expr : ImportedConfidentialKernelSlotExpr)
  | binary (op : Json) (lhs rhs : ImportedConfidentialKernelSlotExpr)
  | select
      (cond : ImportedConfidentialKernelSlotExpr)
      (whenTrue whenFalse : ImportedConfidentialKernelSlotPureExpr)
  | cellGet (objectId : Nat)
  | arrayGet (objectId : Nat) (index : ImportedConfidentialKernelSlotExpr)
  | mapGet (objectId : Nat) (key : ImportedConfidentialKernelSlotExpr)
  | keccak256 (parts : List ImportedConfidentialKernelSlotExpr)

inductive ImportedConfidentialKernelSlotPureExpr where
  | literal (value : Json)
  | slot (slot : Nat)
  | unary (op : Json) (expr : ImportedConfidentialKernelSlotPureExpr)
  | binary (op : Json) (lhs rhs : ImportedConfidentialKernelSlotPureExpr)
  | select
      (cond : ImportedConfidentialKernelSlotPureExpr)
      (whenTrue whenFalse : ImportedConfidentialKernelSlotPureExpr)
  | keccak256 (parts : List ImportedConfidentialKernelSlotPureExpr)

end

mutual
private partial def parseImportedConfidentialKernelSlotStatement
  (json : Json) : Except String ImportedConfidentialKernelSlotStatement := do
  let kind ← json.getObjValAs? String "kind"
  match kind with
  | "declare" =>
      pure <| .declare
        (← json.getObjValAs? Nat "slot")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "value"))
  | "assign" =>
      pure <| .assign
        (← json.getObjValAs? Nat "slot")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "value"))
  | "require" =>
      pure <| .require
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "cond"))
  | "abort_if" =>
      pure <| .abortIf
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "cond"))
  | "cell_set" =>
      pure <| .cellSet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "value"))
        (← parseOptionalImportedConfidentialKernelSlotExprField json "predicate")
  | "array_set" =>
      pure <| .arraySet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "index"))
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "value"))
        (← parseOptionalImportedConfidentialKernelSlotExprField json "predicate")
  | "map_put" =>
      pure <| .mapPut
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "key"))
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "value"))
        (← parseOptionalImportedConfidentialKernelSlotExprField json "predicate")
  | "return" =>
      pure <| .ret (← parseOptionalImportedConfidentialKernelSlotExprField json "value")
  | other =>
      throw s!"unexpected confidential kernel slot statement kind '{other}'"

private partial def parseImportedConfidentialKernelSlotExpr
  (json : Json) : Except String ImportedConfidentialKernelSlotExpr := do
  let kind ← json.getObjValAs? String "kind"
  match kind with
  | "literal" =>
      pure <| .literal (← json.getObjValAs? Json "value")
  | "slot" =>
      pure <| .slot (← json.getObjValAs? Nat "slot")
  | "unary" =>
      pure <| .unary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "expr"))
  | "binary" =>
      pure <| .binary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "lhs"))
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "rhs"))
  | "select" =>
      pure <| .select
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "cond"))
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "when_true"))
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "when_false"))
  | "cell_get" =>
      pure <| .cellGet (← json.getObjValAs? Nat "object_id")
  | "array_get" =>
      pure <| .arrayGet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "index"))
  | "map_get" =>
      pure <| .mapGet
        (← json.getObjValAs? Nat "object_id")
        (← parseImportedConfidentialKernelSlotExpr (← json.getObjValAs? Json "key"))
  | "keccak256" =>
      pure <| .keccak256
        (← parseImportedConfidentialKernelSlotExprList
          (← json.getObjValAs? (List Json) "parts"))
  | other =>
      throw s!"unexpected confidential kernel slot expression kind '{other}'"

private partial def parseImportedConfidentialKernelSlotPureExpr
  (json : Json) : Except String ImportedConfidentialKernelSlotPureExpr := do
  let kind ← json.getObjValAs? String "kind"
  match kind with
  | "literal" =>
      pure <| .literal (← json.getObjValAs? Json "value")
  | "slot" =>
      pure <| .slot (← json.getObjValAs? Nat "slot")
  | "unary" =>
      pure <| .unary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "expr"))
  | "binary" =>
      pure <| .binary
        (← json.getObjValAs? Json "op")
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "lhs"))
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "rhs"))
  | "select" =>
      pure <| .select
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "cond"))
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "when_true"))
        (← parseImportedConfidentialKernelSlotPureExpr (← json.getObjValAs? Json "when_false"))
  | "keccak256" =>
      pure <| .keccak256
        (← parseImportedConfidentialKernelSlotPureExprList
          (← json.getObjValAs? (List Json) "parts"))
  | other =>
      throw s!"unexpected confidential kernel slot pure expression kind '{other}'"

private partial def parseImportedConfidentialKernelSlotExprList
  (items : List Json) : Except String (List ImportedConfidentialKernelSlotExpr) :=
  items.mapM parseImportedConfidentialKernelSlotExpr

private partial def parseImportedConfidentialKernelSlotPureExprList
  (items : List Json) : Except String (List ImportedConfidentialKernelSlotPureExpr) :=
  items.mapM parseImportedConfidentialKernelSlotPureExpr

private partial def parseOptionalImportedConfidentialKernelSlotExprField
  (json : Json)
  (field : String) : Except String (Option ImportedConfidentialKernelSlotExpr) := do
  let value? ← json.getObjValAs? (Option Json) field
  match value? with
  | none => pure none
  | some value => some <$> parseImportedConfidentialKernelSlotExpr value
end

instance : FromJson ImportedConfidentialKernelSlotStatement where
  fromJson? := parseImportedConfidentialKernelSlotStatement

instance : FromJson ImportedConfidentialKernelSlotExpr where
  fromJson? := parseImportedConfidentialKernelSlotExpr

instance : FromJson ImportedConfidentialKernelSlotPureExpr where
  fromJson? := parseImportedConfidentialKernelSlotPureExpr

structure ImportedConfidentialKernelSlotProgram where
  entrypoint_id : String
  param_count : Nat
  return_type : Option Json
  secret_args : List Nat
  slot_count : Nat
  body : List ImportedConfidentialKernelSlotStatement
deriving FromJson

mutual

def ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement :
  ImportedConfidentialKernelSlotStatement → ConfidentialKernelSlotStatement
  | .declare slot value =>
      .declare slot value.toConfidentialKernelSlotExpr
  | .assign slot value =>
      .assign slot value.toConfidentialKernelSlotExpr
  | .require cond =>
      .require cond.toConfidentialKernelSlotExpr
  | .abortIf cond =>
      .abortIf cond.toConfidentialKernelSlotExpr
  | .cellSet objectId value predicate =>
      .cellSet objectId value.toConfidentialKernelSlotExpr
        (predicate.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
  | .arraySet objectId index value predicate =>
      .arraySet objectId index.toConfidentialKernelSlotExpr value.toConfidentialKernelSlotExpr
        (predicate.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
  | .mapPut objectId key value predicate =>
      .mapPut objectId key.toConfidentialKernelSlotExpr value.toConfidentialKernelSlotExpr
        (predicate.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
  | .ret value =>
      .ret (value.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)

def ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr :
  ImportedConfidentialKernelSlotExpr → ConfidentialKernelSlotExpr
  | .literal value =>
      .literal value
  | .slot slot =>
      .slot slot
  | .unary op expr =>
      .unary op expr.toConfidentialKernelSlotExpr
  | .binary op lhs rhs =>
      .binary op lhs.toConfidentialKernelSlotExpr rhs.toConfidentialKernelSlotExpr
  | .select cond whenTrue whenFalse =>
      .select cond.toConfidentialKernelSlotExpr
        whenTrue.toConfidentialKernelSlotPureExpr
        whenFalse.toConfidentialKernelSlotPureExpr
  | .cellGet objectId =>
      .cellGet objectId
  | .arrayGet objectId index =>
      .arrayGet objectId index.toConfidentialKernelSlotExpr
  | .mapGet objectId key =>
      .mapGet objectId key.toConfidentialKernelSlotExpr
  | .keccak256 parts =>
      .keccak256 (parts.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)

def ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr :
  ImportedConfidentialKernelSlotPureExpr → ConfidentialKernelSlotPureExpr
  | .literal value =>
      .literal value
  | .slot slot =>
      .slot slot
  | .unary op expr =>
      .unary op expr.toConfidentialKernelSlotPureExpr
  | .binary op lhs rhs =>
      .binary op lhs.toConfidentialKernelSlotPureExpr rhs.toConfidentialKernelSlotPureExpr
  | .select cond whenTrue whenFalse =>
      .select cond.toConfidentialKernelSlotPureExpr
        whenTrue.toConfidentialKernelSlotPureExpr
        whenFalse.toConfidentialKernelSlotPureExpr
  | .keccak256 parts =>
      .keccak256 (parts.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)

end

def ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram
  (program : ImportedConfidentialKernelSlotProgram) : ConfidentialKernelSlotProgram :=
  { entrypointId := program.entrypoint_id
  , paramCount := program.param_count
  , returnType := program.return_type
  , secretArgs := program.secret_args
  , slotCount := program.slot_count
  , body := program.body.map ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement
  }

def ImportedConfidentialKernelSlotProgram.RuntimeNormalForm
  (program : ImportedConfidentialKernelSlotProgram) : Prop :=
  program.toConfidentialKernelSlotProgram.RuntimeNormalForm

def ImportedConfidentialKernelSlotProgram.checkRuntimeNormalForm
  (program : ImportedConfidentialKernelSlotProgram) : Bool :=
  program.toConfidentialKernelSlotProgram.checkRuntimeNormalForm

@[simp] theorem importedConfidentialKernelSlotProgram_checkRuntimeNormalForm_eq_true_iff
  (program : ImportedConfidentialKernelSlotProgram) :
  program.checkRuntimeNormalForm = true ↔ program.RuntimeNormalForm := by
  unfold ImportedConfidentialKernelSlotProgram.checkRuntimeNormalForm
    ImportedConfidentialKernelSlotProgram.RuntimeNormalForm
  simp [confidentialKernelSlotProgram_checkRuntimeNormalForm_eq_true_iff]

abbrev ImportedConfidentialKernelSlotEnv := List (String × Nat)

private def importedConfidentialKernelSlotEnvResolve
  (env : ImportedConfidentialKernelSlotEnv)
  (name : String) : Except String Nat :=
  match env with
  | [] =>
      throw s!"unknown confidential kernel variable '{name}'"
  | (entryName, slot) :: rest =>
      if entryName = name then
        pure slot
      else
        importedConfidentialKernelSlotEnvResolve rest name

private def importedConfidentialKernelSlotEnvDeclare
  (entrypoint : String)
  (env : ImportedConfidentialKernelSlotEnv)
  (name : String) : Except String (Nat × ImportedConfidentialKernelSlotEnv) := do
  if env.any (fun entry => entry.fst = name) then
    throw s!"confidential entrypoint {entrypoint} declares duplicate variable '{name}'"
  else
    let slot := env.length
    pure (slot, env ++ [(name, slot)])

private def importedConfidentialKernelParamsToSlotEnv
  (entrypoint : String)
  (params : List ImportedConfidentialKernelParam)
  (env : ImportedConfidentialKernelSlotEnv := []) : Except String ImportedConfidentialKernelSlotEnv :=
  match params with
  | [] => pure env
  | param :: rest => do
      let (_, env') ← importedConfidentialKernelSlotEnvDeclare entrypoint env param.name
      importedConfidentialKernelParamsToSlotEnv entrypoint rest env'

mutual

private def importedConfidentialKernelExprsToSlotExprs :
  List ImportedConfidentialKernelExpr →
    ImportedConfidentialKernelSlotEnv → Except String (List ImportedConfidentialKernelSlotExpr)
  | [], _ =>
      pure []
  | expr :: rest, env => do
      let expr' ← importedConfidentialKernelExprToSlotExpr expr env
      let rest' ← importedConfidentialKernelExprsToSlotExprs rest env
      pure (expr' :: rest')
termination_by exprs _ => sizeOf exprs

private def importedConfidentialKernelPureExprsToSlotPureExprs :
  List ImportedConfidentialKernelPureExpr →
    ImportedConfidentialKernelSlotEnv → Except String (List ImportedConfidentialKernelSlotPureExpr)
  | [], _ =>
      pure []
  | expr :: rest, env => do
      let expr' ← importedConfidentialKernelPureExprToSlotPureExpr expr env
      let rest' ← importedConfidentialKernelPureExprsToSlotPureExprs rest env
      pure (expr' :: rest')
termination_by exprs _ => sizeOf exprs

private def importedConfidentialKernelExprToSlotExpr :
  ImportedConfidentialKernelExpr →
    ImportedConfidentialKernelSlotEnv → Except String ImportedConfidentialKernelSlotExpr
  | .literal value, _ =>
      pure <| .literal value
  | .var name, env => do
      pure <| .slot (← importedConfidentialKernelSlotEnvResolve env name)
  | .unary op expr, env => do
      pure <| .unary op (← importedConfidentialKernelExprToSlotExpr expr env)
  | .binary op lhs rhs, env => do
      pure <| .binary op
        (← importedConfidentialKernelExprToSlotExpr lhs env)
        (← importedConfidentialKernelExprToSlotExpr rhs env)
  | .select cond whenTrue whenFalse, env => do
      pure <| .select
        (← importedConfidentialKernelExprToSlotExpr cond env)
        (← importedConfidentialKernelPureExprToSlotPureExpr whenTrue env)
        (← importedConfidentialKernelPureExprToSlotPureExpr whenFalse env)
  | .cellGet objectId, _ =>
      pure <| .cellGet objectId
  | .arrayGet objectId index, env => do
      pure <| .arrayGet objectId (← importedConfidentialKernelExprToSlotExpr index env)
  | .mapGet objectId key, env => do
      pure <| .mapGet objectId (← importedConfidentialKernelExprToSlotExpr key env)
  | .keccak256 parts, env => do
      pure <| .keccak256 (← importedConfidentialKernelExprsToSlotExprs parts env)
termination_by expr _ => sizeOf expr

private def importedConfidentialKernelPureExprToSlotPureExpr :
  ImportedConfidentialKernelPureExpr →
    ImportedConfidentialKernelSlotEnv → Except String ImportedConfidentialKernelSlotPureExpr
  | .literal value, _ =>
      pure <| .literal value
  | .var name, env => do
      pure <| .slot (← importedConfidentialKernelSlotEnvResolve env name)
  | .unary op expr, env => do
      pure <| .unary op (← importedConfidentialKernelPureExprToSlotPureExpr expr env)
  | .binary op lhs rhs, env => do
      pure <| .binary op
        (← importedConfidentialKernelPureExprToSlotPureExpr lhs env)
        (← importedConfidentialKernelPureExprToSlotPureExpr rhs env)
  | .select cond whenTrue whenFalse, env => do
      pure <| .select
        (← importedConfidentialKernelPureExprToSlotPureExpr cond env)
        (← importedConfidentialKernelPureExprToSlotPureExpr whenTrue env)
        (← importedConfidentialKernelPureExprToSlotPureExpr whenFalse env)
  | .keccak256 parts, env => do
      pure <| .keccak256 (← importedConfidentialKernelPureExprsToSlotPureExprs parts env)
termination_by expr _ => sizeOf expr

decreasing_by
  all_goals simp_wf
  all_goals omega

end

private def importedConfidentialKernelStatementToSlotStatement
  (entrypoint : String)
  (stmt : ImportedConfidentialKernelStatement)
  (env : ImportedConfidentialKernelSlotEnv) :
  Except String (ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) := do
  match stmt with
  | .declare name _ value =>
      let (slot, env') ← importedConfidentialKernelSlotEnvDeclare entrypoint env name
      let value' ← importedConfidentialKernelExprToSlotExpr value env'
      pure (.declare slot value', env')
  | .assign name value =>
      let slot ← importedConfidentialKernelSlotEnvResolve env name
      pure (.assign slot (← importedConfidentialKernelExprToSlotExpr value env), env)
  | .require cond =>
      pure (.abortIf (← importedConfidentialKernelExprToSlotExpr cond env), env)
  | .abortIf cond =>
      pure (.abortIf (← importedConfidentialKernelExprToSlotExpr cond env), env)
  | .cellSet objectId value predicate =>
      let predicate' ←
        match predicate with
        | none => pure none
        | some cond => some <$> importedConfidentialKernelExprToSlotExpr cond env
      pure (.cellSet objectId (← importedConfidentialKernelExprToSlotExpr value env) predicate', env)
  | .arraySet objectId index value predicate =>
      let predicate' ←
        match predicate with
        | none => pure none
        | some cond => some <$> importedConfidentialKernelExprToSlotExpr cond env
      pure
        (.arraySet objectId
          (← importedConfidentialKernelExprToSlotExpr index env)
          (← importedConfidentialKernelExprToSlotExpr value env)
          predicate',
          env)
  | .mapPut objectId key value predicate =>
      let predicate' ←
        match predicate with
        | none => pure none
        | some cond => some <$> importedConfidentialKernelExprToSlotExpr cond env
      pure
        (.mapPut objectId
          (← importedConfidentialKernelExprToSlotExpr key env)
          (← importedConfidentialKernelExprToSlotExpr value env)
          predicate',
          env)
  | .ret value =>
      let value' ←
        match value with
        | none => pure none
        | some expr => some <$> importedConfidentialKernelExprToSlotExpr expr env
      pure (.ret value', env)

private def importedConfidentialKernelStatementsToSlotStatements
  (entrypoint : String)
  (stmts : List ImportedConfidentialKernelStatement)
  (env : ImportedConfidentialKernelSlotEnv) :
  Except String (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) := do
  match stmts with
  | [] =>
      pure ([], env)
  | stmt :: rest =>
      let (slotStmt, env') ← importedConfidentialKernelStatementToSlotStatement entrypoint stmt env
      let (slotRest, env'') ← importedConfidentialKernelStatementsToSlotStatements entrypoint rest env'
      pure (slotStmt :: slotRest, env'')

def ImportedConfidentialKernelProgram.toConfidentialKernelSlotProgram?
  (program : ImportedConfidentialKernelProgram) : Except String ImportedConfidentialKernelSlotProgram := do
  let env ← importedConfidentialKernelParamsToSlotEnv program.entrypoint_id program.params
  let (body, env') ← importedConfidentialKernelStatementsToSlotStatements
    program.entrypoint_id program.body env
  pure
    { entrypoint_id := program.entrypoint_id
    , param_count := program.params.length
    , return_type := program.return_type
    , secret_args := program.secret_args
    , slot_count := env'.length
    , body := body
    }

@[simp] theorem importedConfidentialKernelSlotEnvResolve_eq_runtime
  (env : ConfidentialKernelSlotEnv)
  (name : String) :
  confidentialKernelSlotEnvResolve env name =
    importedConfidentialKernelSlotEnvResolve env name := by
  induction env with
  | nil =>
      rfl
  | cons head tail ih =>
      cases head with
      | mk entryName slot =>
          simp [confidentialKernelSlotEnvResolve, importedConfidentialKernelSlotEnvResolve, ih]

@[simp] theorem importedConfidentialKernelSlotEnvDeclare_eq_runtime
  (entrypoint : String)
  (env : ConfidentialKernelSlotEnv)
  (name : String) :
  confidentialKernelSlotEnvDeclare entrypoint env name =
    importedConfidentialKernelSlotEnvDeclare entrypoint env name := by
  simp [confidentialKernelSlotEnvDeclare, importedConfidentialKernelSlotEnvDeclare]

theorem importedConfidentialKernelParamsToSlotEnv_eq_runtime
  (entrypoint : String)
  (params : List ImportedConfidentialKernelParam)
  (env : ConfidentialKernelSlotEnv := []) :
  confidentialKernelParamsToSlotEnv entrypoint
      (params.map ImportedConfidentialKernelParam.toConfidentialKernelParam) env =
    importedConfidentialKernelParamsToSlotEnv entrypoint params env := by
  induction params generalizing env with
  | nil =>
      rfl
  | cons param rest ih =>
      simp [confidentialKernelParamsToSlotEnv, importedConfidentialKernelParamsToSlotEnv,
        ImportedConfidentialKernelParam.toConfidentialKernelParam,
        importedConfidentialKernelSlotEnvDeclare_eq_runtime, ih]

@[simp] theorem importedConfidentialKernelExceptMap_ok
  {ε α β : Type}
  (f : α → β)
  (value : α) :
  Except.map f (.ok value : Except ε α) = .ok (f value) := rfl

@[simp] theorem importedConfidentialKernelExceptMap_error
  {ε α β : Type}
  (f : α → β)
  (err : ε) :
  Except.map f (.error err : Except ε α) = (.error err : Except ε β) := rfl

@[simp] theorem importedConfidentialKernelExceptPure
  {ε α : Type}
  (value : α) :
  (pure value : Except ε α) = .ok value := rfl

@[simp] theorem importedConfidentialKernelExceptBind_error
  {ε α β : Type}
  (err : ε)
  (k : α → Except ε β) :
  Except.bind (.error err : Except ε α) k = (.error err : Except ε β) := rfl

@[simp] theorem importedConfidentialKernelExceptBind_ok
  {ε α β : Type}
  (value : α)
  (k : α → Except ε β) :
  Except.bind (.ok value : Except ε α) k = k value := rfl

private theorem importedConfidentialKernelExceptMap_bind
  {ε α β γ δ : Type}
  (toMid : α → β)
  (toOut : γ → δ)
  (source : Except ε α)
  (kRuntime : β → Except ε δ)
  (kImported : α → Except ε γ)
  (hk :
    ∀ value,
      kRuntime (toMid value) =
        Except.map toOut (kImported value)) :
  (do
      let value ← Except.map toMid source
      kRuntime value) =
    Except.map toOut
      (do
        let value ← source
        kImported value) := by
  cases source with
  | error err =>
      rfl
  | ok value =>
      simpa using hk value

private theorem importedConfidentialKernelExceptMap_fmap
  {ε α β γ δ : Type}
  (toMid : α → β)
  (toOut : γ → δ)
  (source : Except ε α)
  (fRuntime : β → δ)
  (fImported : α → γ)
  (hf :
    ∀ value,
      fRuntime (toMid value) = toOut (fImported value)) :
  fRuntime <$> Except.map toMid source =
    Except.map toOut (fImported <$> source) := by
  simpa using
    importedConfidentialKernelExceptMap_bind toMid toOut source
      (fun value => pure (fRuntime value))
      (fun value => pure (fImported value))
      (by
        intro value
        simp [hf value])

private def importedConfidentialKernelStatementResultToRuntime
  (result : ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) :
  ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv :=
  (result.1.toConfidentialKernelSlotStatement, result.2)

private def importedConfidentialKernelStatementListResultToRuntime
  (result : List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) :
  List ConfidentialKernelSlotStatement × ConfidentialKernelSlotEnv :=
  (result.1.map ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement, result.2)

@[simp] theorem importedConfidentialKernelExprLiteralToSlotExpr_toRuntime
  (value : Json)
  (env : ConfidentialKernelSlotEnv) :
  confidentialKernelExprToSlotExpr (.literal value) env =
    Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
      (importedConfidentialKernelExprToSlotExpr (.literal value) env) := by
  simp [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr]

@[simp] theorem importedConfidentialKernelExprVarToSlotExpr_toRuntime
  (name : String)
  (env : ConfidentialKernelSlotEnv) :
  confidentialKernelExprToSlotExpr (.var name) env =
    Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
      (importedConfidentialKernelExprToSlotExpr (.var name) env) := by
  simpa [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr] using
    importedConfidentialKernelExceptMap_fmap
      (toMid := id)
      (toOut := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
      (source := importedConfidentialKernelSlotEnvResolve env name)
      (fRuntime := ConfidentialKernelSlotExpr.slot)
      (fImported := ImportedConfidentialKernelSlotExpr.slot)
      (by
        intro slot
        simp [ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr])

@[simp] theorem importedConfidentialKernelExprCellGetToSlotExpr_toRuntime
  (objectId : Nat)
  (env : ConfidentialKernelSlotEnv) :
  confidentialKernelExprToSlotExpr (.cellGet objectId) env =
    Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
      (importedConfidentialKernelExprToSlotExpr (.cellGet objectId) env) := by
  simp [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr]

@[simp] theorem importedConfidentialKernelPureExprLiteralToSlotPureExpr_toRuntime
  (value : Json)
  (env : ConfidentialKernelSlotEnv) :
  confidentialKernelPureExprToSlotPureExpr (.literal value) env =
    Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
      (importedConfidentialKernelPureExprToSlotPureExpr (.literal value) env) := by
  simp [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr]

@[simp] theorem importedConfidentialKernelPureExprVarToSlotPureExpr_toRuntime
  (name : String)
  (env : ConfidentialKernelSlotEnv) :
  confidentialKernelPureExprToSlotPureExpr (.var name) env =
    Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
      (importedConfidentialKernelPureExprToSlotPureExpr (.var name) env) := by
  simpa [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr] using
    importedConfidentialKernelExceptMap_fmap
      (toMid := id)
      (toOut := ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
      (source := importedConfidentialKernelSlotEnvResolve env name)
      (fRuntime := ConfidentialKernelSlotPureExpr.slot)
      (fImported := ImportedConfidentialKernelSlotPureExpr.slot)
      (by
        intro slot
        simp [ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr])

mutual

theorem importedConfidentialKernelExprToSlotExpr_toRuntime
  : (expr : ImportedConfidentialKernelExpr) →
      (env : ConfidentialKernelSlotEnv) →
      confidentialKernelExprToSlotExpr expr.toConfidentialKernelExpr env =
        Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
          (importedConfidentialKernelExprToSlotExpr expr env)
  | .literal value, env => by
      simpa only [ImportedConfidentialKernelExpr.toConfidentialKernelExpr] using
        importedConfidentialKernelExprLiteralToSlotExpr_toRuntime value env
  | .var name, env => by
      simpa only [ImportedConfidentialKernelExpr.toConfidentialKernelExpr] using
        importedConfidentialKernelExprVarToSlotExpr_toRuntime name env
  | .unary op expr, env => by
      have hExpr := importedConfidentialKernelExprToSlotExpr_toRuntime expr env
      cases h : importedConfidentialKernelExprToSlotExpr expr env with
      | error err =>
          simp [h] at hExpr
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr, h, hExpr] using
            (show (.error err : Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.error err : Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
      | ok value =>
          simp [h] at hExpr
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
            ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr, h, hExpr] using
            (show (.ok (ImportedConfidentialKernelSlotExpr.unary op value).toConfidentialKernelSlotExpr :
                Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.ok (ImportedConfidentialKernelSlotExpr.unary op value) :
                    Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_ok
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                (ImportedConfidentialKernelSlotExpr.unary op value)).symm)
  | .binary op lhs rhs, env => by
      have hLhs := importedConfidentialKernelExprToSlotExpr_toRuntime lhs env
      have hRhs := importedConfidentialKernelExprToSlotExpr_toRuntime rhs env
      cases hL : importedConfidentialKernelExprToSlotExpr lhs env with
      | error err =>
          simp [hL] at hLhs
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr, hL, hLhs] using
            (show (.error err : Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.error err : Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
      | ok lhsValue =>
          simp [hL] at hLhs
          cases hR : importedConfidentialKernelExprToSlotExpr rhs env with
          | error err =>
              simp [hR] at hRhs
              simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
                ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
                hL, hR, hLhs, hRhs] using
                (show (.error err : Except String ConfidentialKernelSlotExpr) =
                    Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                      (.error err : Except String ImportedConfidentialKernelSlotExpr) from
                  (importedConfidentialKernelExceptMap_error
                    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
          | ok rhsValue =>
              simp [hR] at hRhs
              simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
                ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
                hL, hR, hLhs, hRhs] using
                (show (.ok
                    ((ImportedConfidentialKernelSlotExpr.binary op lhsValue rhsValue).toConfidentialKernelSlotExpr) :
                    Except String ConfidentialKernelSlotExpr) =
                    Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                      (.ok (ImportedConfidentialKernelSlotExpr.binary op lhsValue rhsValue) :
                        Except String ImportedConfidentialKernelSlotExpr) from
                  (importedConfidentialKernelExceptMap_ok
                    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                    (ImportedConfidentialKernelSlotExpr.binary op lhsValue rhsValue)).symm)
  | .select cond whenTrue whenFalse, env => by
      have hCond := importedConfidentialKernelExprToSlotExpr_toRuntime cond env
      have hWhenTrue := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime whenTrue env
      have hWhenFalse := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime whenFalse env
      cases hC : importedConfidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [hC] at hCond
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr, hC, hCond] using
            (show (.error err : Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.error err : Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
      | ok condValue =>
          simp [hC] at hCond
          cases hT : importedConfidentialKernelPureExprToSlotPureExpr whenTrue env with
          | error err =>
              simp [hT] at hWhenTrue
              simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
                confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
                ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                hC, hT, hCond, hWhenTrue] using
                (show (.error err : Except String ConfidentialKernelSlotExpr) =
                    Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                      (.error err : Except String ImportedConfidentialKernelSlotExpr) from
                  (importedConfidentialKernelExceptMap_error
                    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
          | ok whenTrueValue =>
              simp [hT] at hWhenTrue
              cases hF : importedConfidentialKernelPureExprToSlotPureExpr whenFalse env with
              | error err =>
                  simp [hF] at hWhenFalse
                  simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
                    confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                    ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
                    ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                    hC, hT, hF, hCond, hWhenTrue, hWhenFalse] using
                    (show (.error err : Except String ConfidentialKernelSlotExpr) =
                        Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                          (.error err : Except String ImportedConfidentialKernelSlotExpr) from
                      (importedConfidentialKernelExceptMap_error
                        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
              | ok whenFalseValue =>
                  simp [hF] at hWhenFalse
                  simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
                    confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                    ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
                    ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                    ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                    hC, hT, hF, hCond, hWhenTrue, hWhenFalse] using
                    (show (.ok
                        (ImportedConfidentialKernelSlotExpr.select condValue whenTrueValue
                          whenFalseValue).toConfidentialKernelSlotExpr :
                        Except String ConfidentialKernelSlotExpr) =
                        Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                          (.ok
                            (ImportedConfidentialKernelSlotExpr.select condValue whenTrueValue
                              whenFalseValue) :
                            Except String ImportedConfidentialKernelSlotExpr) from
                      (importedConfidentialKernelExceptMap_ok
                        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                        (ImportedConfidentialKernelSlotExpr.select condValue whenTrueValue
                          whenFalseValue)).symm)
  | .cellGet objectId, env => by
      simpa only [ImportedConfidentialKernelExpr.toConfidentialKernelExpr] using
        importedConfidentialKernelExprCellGetToSlotExpr_toRuntime objectId env
  | .arrayGet objectId index, env => by
      have hIndex := importedConfidentialKernelExprToSlotExpr_toRuntime index env
      cases h : importedConfidentialKernelExprToSlotExpr index env with
      | error err =>
          simp [h] at hIndex
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr, h, hIndex] using
            (show (.error err : Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.error err : Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
      | ok value =>
          simp [h] at hIndex
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
            ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr, h, hIndex] using
            (show (.ok (ImportedConfidentialKernelSlotExpr.arrayGet objectId value).toConfidentialKernelSlotExpr :
                Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.ok (ImportedConfidentialKernelSlotExpr.arrayGet objectId value) :
                    Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_ok
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                (ImportedConfidentialKernelSlotExpr.arrayGet objectId value)).symm)
  | .mapGet objectId key, env => by
      have hKey := importedConfidentialKernelExprToSlotExpr_toRuntime key env
      cases h : importedConfidentialKernelExprToSlotExpr key env with
      | error err =>
          simp [h] at hKey
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr, h, hKey] using
            (show (.error err : Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.error err : Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
      | ok value =>
          simp [h] at hKey
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
            ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr, h, hKey] using
            (show (.ok (ImportedConfidentialKernelSlotExpr.mapGet objectId value).toConfidentialKernelSlotExpr :
                Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.ok (ImportedConfidentialKernelSlotExpr.mapGet objectId value) :
                    Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_ok
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                (ImportedConfidentialKernelSlotExpr.mapGet objectId value)).symm)
  | .keccak256 parts, env => by
      have hParts := importedConfidentialKernelExprListToSlotExpr_toRuntime parts env
      cases h : importedConfidentialKernelExprsToSlotExprs parts env with
      | error err =>
          simp [h] at hParts
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr, h, hParts] using
            (show (.error err : Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.error err : Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr err).symm)
      | ok values =>
          simp [h] at hParts
          simpa only [confidentialKernelExprToSlotExpr, importedConfidentialKernelExprToSlotExpr,
            ImportedConfidentialKernelExpr.toConfidentialKernelExpr,
            ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr, h, hParts] using
            (show (.ok
                (ImportedConfidentialKernelSlotExpr.keccak256 values).toConfidentialKernelSlotExpr :
                Except String ConfidentialKernelSlotExpr) =
                Except.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                  (.ok (ImportedConfidentialKernelSlotExpr.keccak256 values) :
                    Except String ImportedConfidentialKernelSlotExpr) from
              (importedConfidentialKernelExceptMap_ok
                ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr
                (ImportedConfidentialKernelSlotExpr.keccak256 values)).symm)
termination_by expr => sizeOf expr

theorem importedConfidentialKernelPureExprToSlotPureExpr_toRuntime
  : (expr : ImportedConfidentialKernelPureExpr) →
      (env : ConfidentialKernelSlotEnv) →
      confidentialKernelPureExprToSlotPureExpr expr.toConfidentialKernelPureExpr env =
        Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
          (importedConfidentialKernelPureExprToSlotPureExpr expr env)
  | .literal value, env => by
      simpa only [ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr] using
        importedConfidentialKernelPureExprLiteralToSlotPureExpr_toRuntime value env
  | .var name, env => by
      simpa only [ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr] using
        importedConfidentialKernelPureExprVarToSlotPureExpr_toRuntime name env
  | .unary op expr, env => by
      have hExpr := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime expr env
      cases h : importedConfidentialKernelPureExprToSlotPureExpr expr env with
      | error err =>
          simp [h] at hExpr
          simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr, h, hExpr] using
            (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                  (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
      | ok value =>
          simp [h] at hExpr
          simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
            ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr, h, hExpr] using
            (show (.ok (ImportedConfidentialKernelSlotPureExpr.unary op value).toConfidentialKernelSlotPureExpr :
                Except String ConfidentialKernelSlotPureExpr) =
                Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                  (.ok (ImportedConfidentialKernelSlotPureExpr.unary op value) :
                    Except String ImportedConfidentialKernelSlotPureExpr) from
              (importedConfidentialKernelExceptMap_ok
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                (ImportedConfidentialKernelSlotPureExpr.unary op value)).symm)
  | .binary op lhs rhs, env => by
      have hLhs := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime lhs env
      have hRhs := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime rhs env
      cases hL : importedConfidentialKernelPureExprToSlotPureExpr lhs env with
      | error err =>
          simp [hL] at hLhs
          simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr, hL, hLhs] using
            (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                  (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
      | ok lhsValue =>
          simp [hL] at hLhs
          cases hR : importedConfidentialKernelPureExprToSlotPureExpr rhs env with
          | error err =>
              simp [hR] at hRhs
              simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                hL, hR, hLhs, hRhs] using
                (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                    Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                      (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
                  (importedConfidentialKernelExceptMap_error
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
          | ok rhsValue =>
              simp [hR] at hRhs
              simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                hL, hR, hLhs, hRhs] using
                (show (.ok
                    ((ImportedConfidentialKernelSlotPureExpr.binary op lhsValue rhsValue).toConfidentialKernelSlotPureExpr) :
                    Except String ConfidentialKernelSlotPureExpr) =
                    Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                      (.ok (ImportedConfidentialKernelSlotPureExpr.binary op lhsValue rhsValue) :
                        Except String ImportedConfidentialKernelSlotPureExpr) from
                  (importedConfidentialKernelExceptMap_ok
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                    (ImportedConfidentialKernelSlotPureExpr.binary op lhsValue rhsValue)).symm)
  | .select cond whenTrue whenFalse, env => by
      have hCond := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime cond env
      have hWhenTrue := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime whenTrue env
      have hWhenFalse := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime whenFalse env
      cases hC : importedConfidentialKernelPureExprToSlotPureExpr cond env with
      | error err =>
          simp [hC] at hCond
          simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr, hC, hCond] using
            (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                  (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
      | ok condValue =>
          simp [hC] at hCond
          cases hT : importedConfidentialKernelPureExprToSlotPureExpr whenTrue env with
          | error err =>
              simp [hT] at hWhenTrue
              simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                hC, hT, hCond, hWhenTrue] using
                (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                    Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                      (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
                  (importedConfidentialKernelExceptMap_error
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
          | ok whenTrueValue =>
              simp [hT] at hWhenTrue
              cases hF : importedConfidentialKernelPureExprToSlotPureExpr whenFalse env with
              | error err =>
                  simp [hF] at hWhenFalse
                  simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                    ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                    hC, hT, hF, hCond, hWhenTrue, hWhenFalse] using
                    (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                        Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                          (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
                      (importedConfidentialKernelExceptMap_error
                        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
              | ok whenFalseValue =>
                  simp [hF] at hWhenFalse
                  simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
                    ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
                    ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
                    hC, hT, hF, hCond, hWhenTrue, hWhenFalse] using
                    (show (.ok
                        (ImportedConfidentialKernelSlotPureExpr.select condValue whenTrueValue
                          whenFalseValue).toConfidentialKernelSlotPureExpr :
                        Except String ConfidentialKernelSlotPureExpr) =
                        Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                          (.ok
                            (ImportedConfidentialKernelSlotPureExpr.select condValue whenTrueValue
                              whenFalseValue) :
                            Except String ImportedConfidentialKernelSlotPureExpr) from
                      (importedConfidentialKernelExceptMap_ok
                        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                        (ImportedConfidentialKernelSlotPureExpr.select condValue whenTrueValue
                          whenFalseValue)).symm)
  | .keccak256 parts, env => by
      have hParts := importedConfidentialKernelPureExprListToSlotPureExpr_toRuntime parts env
      cases h : importedConfidentialKernelPureExprsToSlotPureExprs parts env with
      | error err =>
          simp [h] at hParts
          simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr, h, hParts] using
            (show (.error err : Except String ConfidentialKernelSlotPureExpr) =
                Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                  (.error err : Except String ImportedConfidentialKernelSlotPureExpr) from
              (importedConfidentialKernelExceptMap_error
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr err).symm)
      | ok values =>
          simp [h] at hParts
          simpa only [confidentialKernelPureExprToSlotPureExpr, importedConfidentialKernelPureExprToSlotPureExpr,
            ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr,
            ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr, h, hParts] using
            (show (.ok
                (ImportedConfidentialKernelSlotPureExpr.keccak256 values).toConfidentialKernelSlotPureExpr :
                Except String ConfidentialKernelSlotPureExpr) =
                Except.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                  (.ok (ImportedConfidentialKernelSlotPureExpr.keccak256 values) :
                    Except String ImportedConfidentialKernelSlotPureExpr) from
              (importedConfidentialKernelExceptMap_ok
                ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr
                (ImportedConfidentialKernelSlotPureExpr.keccak256 values)).symm)
termination_by expr => sizeOf expr

theorem importedConfidentialKernelExprListToSlotExpr_toRuntime
  : (exprs : List ImportedConfidentialKernelExpr) →
      (env : ConfidentialKernelSlotEnv) →
      confidentialKernelExprsToSlotExprs
          (exprs.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr) env =
        Except.map (List.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (importedConfidentialKernelExprsToSlotExprs exprs env)
  | [], env => by
      simp [confidentialKernelExprsToSlotExprs, importedConfidentialKernelExprsToSlotExprs]
  | expr :: exprs, env => by
      have hHead := importedConfidentialKernelExprToSlotExpr_toRuntime expr env
      have hTail := importedConfidentialKernelExprListToSlotExpr_toRuntime exprs env
      have hk :
          ∀ headValue,
            List.cons (ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr headValue) <$>
              confidentialKernelExprsToSlotExprs
                (exprs.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr) env =
              Except.map (List.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (List.cons headValue <$> importedConfidentialKernelExprsToSlotExprs exprs env) := by
        intro headValue
        simpa [confidentialKernelExprsToSlotExprs, importedConfidentialKernelExprsToSlotExprs, hTail] using
          importedConfidentialKernelExceptMap_fmap
            (toMid := List.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
            (toOut := List.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
            (source := importedConfidentialKernelExprsToSlotExprs exprs env)
            (fRuntime := List.cons
              (ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr headValue))
            (fImported := List.cons headValue)
            (by
              intro values
              simp)
      simpa [confidentialKernelExprsToSlotExprs, importedConfidentialKernelExprsToSlotExprs, hHead] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := List.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (source := importedConfidentialKernelExprToSlotExpr expr env)
          (kRuntime := fun headValue =>
            List.cons headValue <$>
              confidentialKernelExprsToSlotExprs
                (exprs.map ImportedConfidentialKernelExpr.toConfidentialKernelExpr) env)
          (kImported := fun headValue =>
            List.cons headValue <$> importedConfidentialKernelExprsToSlotExprs exprs env)
          hk
termination_by exprs => sizeOf exprs

theorem importedConfidentialKernelPureExprListToSlotPureExpr_toRuntime
  : (exprs : List ImportedConfidentialKernelPureExpr) →
      (env : ConfidentialKernelSlotEnv) →
      confidentialKernelPureExprsToSlotPureExprs
          (exprs.map ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr) env =
        Except.map (List.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
          (importedConfidentialKernelPureExprsToSlotPureExprs exprs env)
  | [], env => by
      simp [confidentialKernelPureExprsToSlotPureExprs,
        importedConfidentialKernelPureExprsToSlotPureExprs]
  | expr :: exprs, env => by
      have hHead := importedConfidentialKernelPureExprToSlotPureExpr_toRuntime expr env
      have hTail := importedConfidentialKernelPureExprListToSlotPureExpr_toRuntime exprs env
      have hk :
          ∀ headValue,
            List.cons (ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr headValue) <$>
              confidentialKernelPureExprsToSlotPureExprs
                (exprs.map ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr) env =
              Except.map (List.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
                (List.cons headValue <$> importedConfidentialKernelPureExprsToSlotPureExprs exprs env) := by
        intro headValue
        simpa [confidentialKernelPureExprsToSlotPureExprs,
          importedConfidentialKernelPureExprsToSlotPureExprs, hTail] using
          importedConfidentialKernelExceptMap_fmap
            (toMid := List.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
            (toOut := List.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
            (source := importedConfidentialKernelPureExprsToSlotPureExprs exprs env)
            (fRuntime := List.cons
              (ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr headValue))
            (fImported := List.cons headValue)
            (by
              intro values
              simp)
      simpa [confidentialKernelPureExprsToSlotPureExprs,
        importedConfidentialKernelPureExprsToSlotPureExprs, hHead] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
          (toOut := List.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
          (source := importedConfidentialKernelPureExprToSlotPureExpr expr env)
          (kRuntime := fun headValue =>
            List.cons headValue <$>
              confidentialKernelPureExprsToSlotPureExprs
                (exprs.map ImportedConfidentialKernelPureExpr.toConfidentialKernelPureExpr) env)
          (kImported := fun headValue =>
            List.cons headValue <$> importedConfidentialKernelPureExprsToSlotPureExprs exprs env)
          hk
termination_by exprs => sizeOf exprs

decreasing_by
  all_goals simp_wf
  all_goals omega

end

private theorem importedOptionalConfidentialKernelExprToSlotExpr_toRuntime
  : (value : Option ImportedConfidentialKernelExpr) →
      (env : ConfidentialKernelSlotEnv) →
      (match value with
      | none => (pure none : Except String (Option ConfidentialKernelSlotExpr))
      | some expr => some <$> confidentialKernelExprToSlotExpr expr.toConfidentialKernelExpr env) =
        Except.map (Option.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (match value with
          | none => (pure none : Except String (Option ImportedConfidentialKernelSlotExpr))
          | some expr => some <$> importedConfidentialKernelExprToSlotExpr expr env)
  | none, _ => rfl
  | some expr, env => by
      have hExpr := importedConfidentialKernelExprToSlotExpr_toRuntime expr env
      simpa [hExpr] using
        importedConfidentialKernelExceptMap_fmap
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := Option.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (source := importedConfidentialKernelExprToSlotExpr expr env)
          (fRuntime := Option.some)
          (fImported := Option.some)
          (by
            intro value
            rfl)

theorem importedConfidentialKernelStatementToSlotStatement_toRuntime
  (entrypoint : String) :
  (stmt : ImportedConfidentialKernelStatement) →
    (env : ConfidentialKernelSlotEnv) →
    confidentialKernelStatementToSlotStatement
        entrypoint stmt.toConfidentialKernelStatement env =
      Except.map importedConfidentialKernelStatementResultToRuntime
        (importedConfidentialKernelStatementToSlotStatement entrypoint stmt env)
  | .declare name ty value, env => by
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        importedConfidentialKernelSlotEnvDeclare_eq_runtime] using
        importedConfidentialKernelExceptMap_bind
          (toMid := id)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelSlotEnvDeclare entrypoint env name)
          (kRuntime := fun result =>
            let slot := result.1
            let env' := result.2
            (fun value' => (ConfidentialKernelSlotStatement.declare slot value', env')) <$>
              confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env')
          (kImported := fun result =>
            let slot := result.1
            let env' := result.2
            (fun value' => (ImportedConfidentialKernelSlotStatement.declare slot value', env')) <$>
              importedConfidentialKernelExprToSlotExpr value env')
          (by
            intro result
            rcases result with ⟨slot, env'⟩
            have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env'
            simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
              importedConfidentialKernelExceptMap_fmap
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr value env')
                (fRuntime := fun value' =>
                  (ConfidentialKernelSlotStatement.declare slot value', env'))
                (fImported := fun value' =>
                  (ImportedConfidentialKernelSlotStatement.declare slot value', env'))
                (by
                  intro value'
                  rfl))
  | .assign name value, env => by
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        importedConfidentialKernelSlotEnvResolve_eq_runtime] using
        importedConfidentialKernelExceptMap_bind
          (toMid := id)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelSlotEnvResolve env name)
          (kRuntime := fun slot =>
            (fun value' => (ConfidentialKernelSlotStatement.assign slot value', env)) <$>
              confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
          (kImported := fun slot =>
            (fun value' => (ImportedConfidentialKernelSlotStatement.assign slot value', env)) <$>
              importedConfidentialKernelExprToSlotExpr value env)
          (by
            intro slot
            have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
            simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
              importedConfidentialKernelExceptMap_fmap
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr value env)
                (fRuntime := fun value' =>
                  (ConfidentialKernelSlotStatement.assign slot value', env))
                (fImported := fun value' =>
                  (ImportedConfidentialKernelSlotStatement.assign slot value', env))
                (by
                  intro value'
                  rfl))
  | .require cond, env => by
      have hCond := importedConfidentialKernelExprToSlotExpr_toRuntime cond env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        hCond, importedConfidentialKernelStatementResultToRuntime] using
        importedConfidentialKernelExceptMap_fmap
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr cond env)
          (fRuntime := fun cond' => (ConfidentialKernelSlotStatement.abortIf cond', env))
          (fImported := fun cond' => (ImportedConfidentialKernelSlotStatement.abortIf cond', env))
          (by
            intro cond'
            rfl)
  | .abortIf cond, env => by
      have hCond := importedConfidentialKernelExprToSlotExpr_toRuntime cond env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        hCond, importedConfidentialKernelStatementResultToRuntime] using
        importedConfidentialKernelExceptMap_fmap
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr cond env)
          (fRuntime := fun cond' => (ConfidentialKernelSlotStatement.abortIf cond', env))
          (fImported := fun cond' => (ImportedConfidentialKernelSlotStatement.abortIf cond', env))
          (by
            intro cond'
            rfl)
  | .cellSet objectId value none, env => by
      have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        hValue, importedConfidentialKernelStatementResultToRuntime] using
        importedConfidentialKernelExceptMap_fmap
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr value env)
          (fRuntime := fun value' =>
            (ConfidentialKernelSlotStatement.cellSet objectId value' none, env))
          (fImported := fun value' =>
            (ImportedConfidentialKernelSlotStatement.cellSet objectId value' none, env))
          (by
            intro value'
            rfl)
  | .cellSet objectId value (some predicate), env => by
      have hPredicate := importedConfidentialKernelExprToSlotExpr_toRuntime predicate env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement, hPredicate] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr predicate env)
          (kRuntime := fun predicate' =>
            (fun value' =>
              (ConfidentialKernelSlotStatement.cellSet objectId value' (some predicate'), env)) <$>
                confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
          (kImported := fun predicate' =>
            (fun value' =>
              (ImportedConfidentialKernelSlotStatement.cellSet objectId value' (some predicate'), env)) <$>
                importedConfidentialKernelExprToSlotExpr value env)
          (by
            intro predicate'
            have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
            simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
              importedConfidentialKernelExceptMap_fmap
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr value env)
                (fRuntime := fun value' =>
                  (ConfidentialKernelSlotStatement.cellSet objectId value'
                    (some predicate'.toConfidentialKernelSlotExpr), env))
                (fImported := fun value' =>
                  (ImportedConfidentialKernelSlotStatement.cellSet objectId value' (some predicate'), env))
                (by
                  intro value'
                  rfl))
  | .arraySet objectId index value none, env => by
      have hIndex := importedConfidentialKernelExprToSlotExpr_toRuntime index env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement, hIndex] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr index env)
          (kRuntime := fun index' =>
            (fun value' =>
              (ConfidentialKernelSlotStatement.arraySet objectId index' value' none, env)) <$>
                confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
          (kImported := fun index' =>
            (fun value' =>
              (ImportedConfidentialKernelSlotStatement.arraySet objectId index' value' none, env)) <$>
                importedConfidentialKernelExprToSlotExpr value env)
          (by
            intro index'
            have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
            simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
              importedConfidentialKernelExceptMap_fmap
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr value env)
                (fRuntime := fun value' =>
                  (ConfidentialKernelSlotStatement.arraySet objectId
                    index'.toConfidentialKernelSlotExpr value' none, env))
                (fImported := fun value' =>
                  (ImportedConfidentialKernelSlotStatement.arraySet objectId index' value' none, env))
                (by
                  intro value'
                  rfl))
  | .arraySet objectId index value (some predicate), env => by
      have hPredicate := importedConfidentialKernelExprToSlotExpr_toRuntime predicate env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement, hPredicate] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr predicate env)
          (kRuntime := fun predicate' => do
            let index' ← confidentialKernelExprToSlotExpr index.toConfidentialKernelExpr env
            (fun value' =>
              (ConfidentialKernelSlotStatement.arraySet objectId index' value' (some predicate'), env)) <$>
                confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
          (kImported := fun predicate' => do
            let index' ← importedConfidentialKernelExprToSlotExpr index env
            (fun value' =>
              (ImportedConfidentialKernelSlotStatement.arraySet objectId index' value' (some predicate'), env)) <$>
                importedConfidentialKernelExprToSlotExpr value env)
          (by
            intro predicate'
            have hIndex := importedConfidentialKernelExprToSlotExpr_toRuntime index env
            simpa [hIndex] using
              importedConfidentialKernelExceptMap_bind
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr index env)
                (kRuntime := fun index' =>
                  (fun value' =>
                    (ConfidentialKernelSlotStatement.arraySet objectId index' value'
                      (some predicate'.toConfidentialKernelSlotExpr), env)) <$>
                      confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
                (kImported := fun index' =>
                  (fun value' =>
                    (ImportedConfidentialKernelSlotStatement.arraySet objectId index' value' (some predicate'), env)) <$>
                      importedConfidentialKernelExprToSlotExpr value env)
                (by
                  intro index'
                  have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
                  simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
                    importedConfidentialKernelExceptMap_fmap
                      (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                      (toOut := importedConfidentialKernelStatementResultToRuntime)
                      (source := importedConfidentialKernelExprToSlotExpr value env)
                      (fRuntime := fun value' =>
                        (ConfidentialKernelSlotStatement.arraySet objectId
                          index'.toConfidentialKernelSlotExpr value'
                          (some predicate'.toConfidentialKernelSlotExpr), env))
                      (fImported := fun value' =>
                        (ImportedConfidentialKernelSlotStatement.arraySet objectId index' value' (some predicate'), env))
                      (by
                        intro value'
                        rfl)))
  | .mapPut objectId key value none, env => by
      have hKey := importedConfidentialKernelExprToSlotExpr_toRuntime key env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement, hKey] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr key env)
          (kRuntime := fun key' =>
            (fun value' =>
              (ConfidentialKernelSlotStatement.mapPut objectId key' value' none, env)) <$>
                confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
          (kImported := fun key' =>
            (fun value' =>
              (ImportedConfidentialKernelSlotStatement.mapPut objectId key' value' none, env)) <$>
                importedConfidentialKernelExprToSlotExpr value env)
          (by
            intro key'
            have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
            simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
              importedConfidentialKernelExceptMap_fmap
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr value env)
                (fRuntime := fun value' =>
                  (ConfidentialKernelSlotStatement.mapPut objectId
                    key'.toConfidentialKernelSlotExpr value' none, env))
                (fImported := fun value' =>
                  (ImportedConfidentialKernelSlotStatement.mapPut objectId key' value' none, env))
                (by
                  intro value'
                  rfl))
  | .mapPut objectId key value (some predicate), env => by
      have hPredicate := importedConfidentialKernelExprToSlotExpr_toRuntime predicate env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement, hPredicate] using
        importedConfidentialKernelExceptMap_bind
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr predicate env)
          (kRuntime := fun predicate' => do
            let key' ← confidentialKernelExprToSlotExpr key.toConfidentialKernelExpr env
            (fun value' =>
              (ConfidentialKernelSlotStatement.mapPut objectId key' value' (some predicate'), env)) <$>
                confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
          (kImported := fun predicate' => do
            let key' ← importedConfidentialKernelExprToSlotExpr key env
            (fun value' =>
              (ImportedConfidentialKernelSlotStatement.mapPut objectId key' value' (some predicate'), env)) <$>
                importedConfidentialKernelExprToSlotExpr value env)
          (by
            intro predicate'
            have hKey := importedConfidentialKernelExprToSlotExpr_toRuntime key env
            simpa [hKey] using
              importedConfidentialKernelExceptMap_bind
                (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                (toOut := importedConfidentialKernelStatementResultToRuntime)
                (source := importedConfidentialKernelExprToSlotExpr key env)
                (kRuntime := fun key' =>
                  (fun value' =>
                    (ConfidentialKernelSlotStatement.mapPut objectId key' value'
                      (some predicate'.toConfidentialKernelSlotExpr), env)) <$>
                      confidentialKernelExprToSlotExpr value.toConfidentialKernelExpr env)
                (kImported := fun key' =>
                  (fun value' =>
                    (ImportedConfidentialKernelSlotStatement.mapPut objectId key' value' (some predicate'), env)) <$>
                      importedConfidentialKernelExprToSlotExpr value env)
                (by
                  intro key'
                  have hValue := importedConfidentialKernelExprToSlotExpr_toRuntime value env
                  simpa [hValue, importedConfidentialKernelStatementResultToRuntime] using
                    importedConfidentialKernelExceptMap_fmap
                      (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
                      (toOut := importedConfidentialKernelStatementResultToRuntime)
                      (source := importedConfidentialKernelExprToSlotExpr value env)
                      (fRuntime := fun value' =>
                        (ConfidentialKernelSlotStatement.mapPut objectId
                          key'.toConfidentialKernelSlotExpr value'
                          (some predicate'.toConfidentialKernelSlotExpr), env))
                      (fImported := fun value' =>
                        (ImportedConfidentialKernelSlotStatement.mapPut objectId key' value' (some predicate'), env))
                      (by
                        intro value'
                        rfl)))
  | .ret none, env => by
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        importedConfidentialKernelStatementResultToRuntime] using
        importedConfidentialKernelExceptMap_fmap
          (toMid := Option.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := (pure none : Except String (Option ImportedConfidentialKernelSlotExpr)))
          (fRuntime := fun value' => (ConfidentialKernelSlotStatement.ret value', env))
          (fImported := fun value' => (ImportedConfidentialKernelSlotStatement.ret value', env))
          (by
            intro value'
            rfl)
  | .ret (some expr), env => by
      have hExpr := importedConfidentialKernelExprToSlotExpr_toRuntime expr env
      simpa [confidentialKernelStatementToSlotStatement,
        importedConfidentialKernelStatementToSlotStatement,
        ImportedConfidentialKernelStatement.toConfidentialKernelStatement,
        hExpr, importedConfidentialKernelStatementResultToRuntime] using
        importedConfidentialKernelExceptMap_fmap
          (toMid := ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
          (toOut := importedConfidentialKernelStatementResultToRuntime)
          (source := importedConfidentialKernelExprToSlotExpr expr env)
          (fRuntime := fun value' => (ConfidentialKernelSlotStatement.ret (some value'), env))
          (fImported := fun value' => (ImportedConfidentialKernelSlotStatement.ret (some value'), env))
          (by
            intro value'
            rfl)

theorem importedConfidentialKernelStatementsToSlotStatements_toRuntime
  (entrypoint : String) :
  (stmts : List ImportedConfidentialKernelStatement) →
    (env : ConfidentialKernelSlotEnv) →
    confidentialKernelStatementsToSlotStatements
        entrypoint (stmts.map ImportedConfidentialKernelStatement.toConfidentialKernelStatement) env =
      Except.map importedConfidentialKernelStatementListResultToRuntime
        (importedConfidentialKernelStatementsToSlotStatements entrypoint stmts env)
  | [], env => by
      simp [confidentialKernelStatementsToSlotStatements,
        importedConfidentialKernelStatementsToSlotStatements,
        importedConfidentialKernelStatementListResultToRuntime]
  | stmt :: rest, env => by
      have hStmt := importedConfidentialKernelStatementToSlotStatement_toRuntime entrypoint stmt env
      simpa [confidentialKernelStatementsToSlotStatements,
        importedConfidentialKernelStatementsToSlotStatements, hStmt] using
        importedConfidentialKernelExceptMap_bind
          (toMid := importedConfidentialKernelStatementResultToRuntime)
          (toOut := importedConfidentialKernelStatementListResultToRuntime)
          (source := importedConfidentialKernelStatementToSlotStatement entrypoint stmt env)
          (kRuntime := fun stmtResult =>
            let slotStmt := stmtResult.1
            let env' := stmtResult.2
            (fun restResult => (slotStmt :: restResult.1, restResult.2)) <$>
              confidentialKernelStatementsToSlotStatements
                entrypoint (rest.map ImportedConfidentialKernelStatement.toConfidentialKernelStatement) env')
          (kImported := fun stmtResult =>
            let slotStmt := stmtResult.1
            let env' := stmtResult.2
            (fun restResult => (slotStmt :: restResult.1, restResult.2)) <$>
              importedConfidentialKernelStatementsToSlotStatements entrypoint rest env')
          (by
            intro stmtResult
            rcases stmtResult with ⟨slotStmt, env'⟩
            have hRest := importedConfidentialKernelStatementsToSlotStatements_toRuntime entrypoint rest env'
            simpa [hRest, importedConfidentialKernelStatementResultToRuntime,
              importedConfidentialKernelStatementListResultToRuntime] using
              importedConfidentialKernelExceptMap_fmap
                (toMid := importedConfidentialKernelStatementListResultToRuntime)
                (toOut := importedConfidentialKernelStatementListResultToRuntime)
                (source := importedConfidentialKernelStatementsToSlotStatements entrypoint rest env')
                (fRuntime := fun restResult =>
                  (slotStmt.toConfidentialKernelSlotStatement :: restResult.1, restResult.2))
                (fImported := fun restResult =>
                  (slotStmt :: restResult.1, restResult.2))
                (by
                  intro restResult
                  simp [importedConfidentialKernelStatementListResultToRuntime]))

theorem importedConfidentialKernelProgram_toConfidentialKernelSlotProgram_toRuntime
  (program : ImportedConfidentialKernelProgram) :
  program.toConfidentialKernelProgram.toConfidentialKernelSlotProgram? =
    Except.map ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram
      (program.toConfidentialKernelSlotProgram?) := by
  have hEnvEq := importedConfidentialKernelParamsToSlotEnv_eq_runtime
    program.entrypoint_id program.params
  have hBody :
      ∀ env,
        (fun bodyResult =>
          ({ entrypointId := program.entrypoint_id
           , paramCount := program.params.length
           , returnType := program.return_type
           , secretArgs := program.secret_args
           , slotCount := bodyResult.2.length
           , body := bodyResult.1
           } : ConfidentialKernelSlotProgram)) <$>
            confidentialKernelStatementsToSlotStatements
              program.entrypoint_id
              (program.body.map ImportedConfidentialKernelStatement.toConfidentialKernelStatement)
              env =
          Except.map ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram
            ((fun bodyResult =>
              ({ entrypoint_id := program.entrypoint_id
               , param_count := program.params.length
               , return_type := program.return_type
               , secret_args := program.secret_args
               , slot_count := bodyResult.2.length
               , body := bodyResult.1
               } : ImportedConfidentialKernelSlotProgram)) <$>
                importedConfidentialKernelStatementsToSlotStatements
                  program.entrypoint_id program.body env) := by
    intro env
    have hStatements :=
      importedConfidentialKernelStatementsToSlotStatements_toRuntime
        program.entrypoint_id program.body env
    simpa [hStatements] using
      importedConfidentialKernelExceptMap_fmap
        (toMid := importedConfidentialKernelStatementListResultToRuntime)
        (toOut := ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram)
        (source := importedConfidentialKernelStatementsToSlotStatements
          program.entrypoint_id program.body env)
        (fRuntime := fun bodyResult =>
          ({ entrypointId := program.entrypoint_id
           , paramCount := program.params.length
           , returnType := program.return_type
           , secretArgs := program.secret_args
           , slotCount := bodyResult.2.length
           , body := bodyResult.1
           } : ConfidentialKernelSlotProgram))
        (fImported := fun bodyResult =>
          ({ entrypoint_id := program.entrypoint_id
           , param_count := program.params.length
           , return_type := program.return_type
           , secret_args := program.secret_args
           , slot_count := bodyResult.2.length
           , body := bodyResult.1
           } : ImportedConfidentialKernelSlotProgram))
        (by
          intro bodyResult
          cases bodyResult
          rfl)
  simpa [ConfidentialKernelProgram.toConfidentialKernelSlotProgram?,
    ImportedConfidentialKernelProgram.toConfidentialKernelProgram,
    ImportedConfidentialKernelProgram.toConfidentialKernelSlotProgram?,
    hEnvEq] using
    importedConfidentialKernelExceptMap_bind
      (toMid := id)
      (toOut := ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram)
      (source := importedConfidentialKernelParamsToSlotEnv program.entrypoint_id program.params)
      (kRuntime := fun env =>
        (fun bodyResult =>
          ({ entrypointId := program.entrypoint_id
           , paramCount := program.params.length
           , returnType := program.return_type
           , secretArgs := program.secret_args
           , slotCount := bodyResult.2.length
           , body := bodyResult.1
           } : ConfidentialKernelSlotProgram)) <$>
            confidentialKernelStatementsToSlotStatements
              program.entrypoint_id
              (program.body.map ImportedConfidentialKernelStatement.toConfidentialKernelStatement)
              env)
      (kImported := fun env =>
        (fun bodyResult =>
          ({ entrypoint_id := program.entrypoint_id
           , param_count := program.params.length
           , return_type := program.return_type
           , secret_args := program.secret_args
           , slot_count := bodyResult.2.length
           , body := bodyResult.1
           } : ImportedConfidentialKernelSlotProgram)) <$>
            importedConfidentialKernelStatementsToSlotStatements
              program.entrypoint_id program.body env)
      hBody

theorem importedConfidentialKernelProgram_slotLowering_ok_toRuntime
  {program : ImportedConfidentialKernelProgram}
  {slotProgram : ImportedConfidentialKernelSlotProgram}
  (h : program.toConfidentialKernelSlotProgram? = .ok slotProgram) :
  program.toConfidentialKernelProgram.SlotLoweringMatches
    slotProgram.toConfidentialKernelSlotProgram := by
  unfold ConfidentialKernelProgram.SlotLoweringMatches
  simpa [h, ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram] using
    importedConfidentialKernelProgram_toConfidentialKernelSlotProgram_toRuntime program

theorem importedConfidentialKernelProgram_slotLowering_ok_runtimeNormalForm
  {program : ImportedConfidentialKernelProgram}
  {slotProgram : ImportedConfidentialKernelSlotProgram}
  (h : program.toConfidentialKernelSlotProgram? = .ok slotProgram) :
  slotProgram.RuntimeNormalForm := by
  unfold ImportedConfidentialKernelSlotProgram.RuntimeNormalForm
  exact
    confidentialKernelProgram_toConfidentialKernelSlotProgram_runtimeNormalForm
      program.toConfidentialKernelProgram
      (importedConfidentialKernelProgram_slotLowering_ok_toRuntime h)

mutual

private partial def checkImportedConfidentialKernelSlotExprEq
  (lhs rhs : ImportedConfidentialKernelSlotExpr) : Bool :=
  match lhs, rhs with
  | .literal lhsValue, .literal rhsValue => lhsValue == rhsValue
  | .slot lhsSlot, .slot rhsSlot => lhsSlot == rhsSlot
  | .unary lhsOp lhsExpr, .unary rhsOp rhsExpr =>
      lhsOp == rhsOp && checkImportedConfidentialKernelSlotExprEq lhsExpr rhsExpr
  | .binary lhsOp lhsLhs lhsRhs, .binary rhsOp rhsLhs rhsRhs =>
      lhsOp == rhsOp &&
        checkImportedConfidentialKernelSlotExprEq lhsLhs rhsLhs &&
        checkImportedConfidentialKernelSlotExprEq lhsRhs rhsRhs
  | .select lhsCond lhsWhenTrue lhsWhenFalse, .select rhsCond rhsWhenTrue rhsWhenFalse =>
      checkImportedConfidentialKernelSlotExprEq lhsCond rhsCond &&
        checkImportedConfidentialKernelSlotPureExprEq lhsWhenTrue rhsWhenTrue &&
        checkImportedConfidentialKernelSlotPureExprEq lhsWhenFalse rhsWhenFalse
  | .cellGet lhsObjectId, .cellGet rhsObjectId => lhsObjectId == rhsObjectId
  | .arrayGet lhsObjectId lhsIndex, .arrayGet rhsObjectId rhsIndex =>
      lhsObjectId == rhsObjectId &&
        checkImportedConfidentialKernelSlotExprEq lhsIndex rhsIndex
  | .mapGet lhsObjectId lhsKey, .mapGet rhsObjectId rhsKey =>
      lhsObjectId == rhsObjectId &&
        checkImportedConfidentialKernelSlotExprEq lhsKey rhsKey
  | .keccak256 lhsParts, .keccak256 rhsParts =>
      checkImportedConfidentialKernelSlotExprListEq lhsParts rhsParts
  | _, _ => false

private partial def checkImportedConfidentialKernelSlotPureExprEq
  (lhs rhs : ImportedConfidentialKernelSlotPureExpr) : Bool :=
  match lhs, rhs with
  | .literal lhsValue, .literal rhsValue => lhsValue == rhsValue
  | .slot lhsSlot, .slot rhsSlot => lhsSlot == rhsSlot
  | .unary lhsOp lhsExpr, .unary rhsOp rhsExpr =>
      lhsOp == rhsOp && checkImportedConfidentialKernelSlotPureExprEq lhsExpr rhsExpr
  | .binary lhsOp lhsLhs lhsRhs, .binary rhsOp rhsLhs rhsRhs =>
      lhsOp == rhsOp &&
        checkImportedConfidentialKernelSlotPureExprEq lhsLhs rhsLhs &&
        checkImportedConfidentialKernelSlotPureExprEq lhsRhs rhsRhs
  | .select lhsCond lhsWhenTrue lhsWhenFalse, .select rhsCond rhsWhenTrue rhsWhenFalse =>
      checkImportedConfidentialKernelSlotPureExprEq lhsCond rhsCond &&
        checkImportedConfidentialKernelSlotPureExprEq lhsWhenTrue rhsWhenTrue &&
        checkImportedConfidentialKernelSlotPureExprEq lhsWhenFalse rhsWhenFalse
  | .keccak256 lhsParts, .keccak256 rhsParts =>
      checkImportedConfidentialKernelSlotPureExprListEq lhsParts rhsParts
  | _, _ => false

private partial def checkImportedConfidentialKernelSlotStatementEq
  (lhs rhs : ImportedConfidentialKernelSlotStatement) : Bool :=
  match lhs, rhs with
  | .declare lhsSlot lhsValue, .declare rhsSlot rhsValue =>
      lhsSlot == rhsSlot && checkImportedConfidentialKernelSlotExprEq lhsValue rhsValue
  | .assign lhsSlot lhsValue, .assign rhsSlot rhsValue =>
      lhsSlot == rhsSlot && checkImportedConfidentialKernelSlotExprEq lhsValue rhsValue
  | .require lhsCond, .require rhsCond =>
      checkImportedConfidentialKernelSlotExprEq lhsCond rhsCond
  | .abortIf lhsCond, .abortIf rhsCond =>
      checkImportedConfidentialKernelSlotExprEq lhsCond rhsCond
  | .cellSet lhsObjectId lhsValue lhsPredicate, .cellSet rhsObjectId rhsValue rhsPredicate =>
      lhsObjectId == rhsObjectId &&
        checkImportedConfidentialKernelSlotExprEq lhsValue rhsValue &&
        checkOptionalImportedConfidentialKernelSlotExprEq lhsPredicate rhsPredicate
  | .arraySet lhsObjectId lhsIndex lhsValue lhsPredicate,
      .arraySet rhsObjectId rhsIndex rhsValue rhsPredicate =>
      lhsObjectId == rhsObjectId &&
        checkImportedConfidentialKernelSlotExprEq lhsIndex rhsIndex &&
        checkImportedConfidentialKernelSlotExprEq lhsValue rhsValue &&
        checkOptionalImportedConfidentialKernelSlotExprEq lhsPredicate rhsPredicate
  | .mapPut lhsObjectId lhsKey lhsValue lhsPredicate,
      .mapPut rhsObjectId rhsKey rhsValue rhsPredicate =>
      lhsObjectId == rhsObjectId &&
        checkImportedConfidentialKernelSlotExprEq lhsKey rhsKey &&
        checkImportedConfidentialKernelSlotExprEq lhsValue rhsValue &&
        checkOptionalImportedConfidentialKernelSlotExprEq lhsPredicate rhsPredicate
  | .ret lhsValue, .ret rhsValue =>
      checkOptionalImportedConfidentialKernelSlotExprEq lhsValue rhsValue
  | _, _ => false

private partial def checkImportedConfidentialKernelSlotExprListEq
  (lhs rhs : List ImportedConfidentialKernelSlotExpr) : Bool :=
  match lhs, rhs with
  | [], [] => true
  | lhsHead :: lhsTail, rhsHead :: rhsTail =>
      checkImportedConfidentialKernelSlotExprEq lhsHead rhsHead &&
        checkImportedConfidentialKernelSlotExprListEq lhsTail rhsTail
  | _, _ => false

private partial def checkImportedConfidentialKernelSlotPureExprListEq
  (lhs rhs : List ImportedConfidentialKernelSlotPureExpr) : Bool :=
  match lhs, rhs with
  | [], [] => true
  | lhsHead :: lhsTail, rhsHead :: rhsTail =>
      checkImportedConfidentialKernelSlotPureExprEq lhsHead rhsHead &&
        checkImportedConfidentialKernelSlotPureExprListEq lhsTail rhsTail
  | _, _ => false

private partial def checkOptionalImportedConfidentialKernelSlotExprEq
  (lhs rhs : Option ImportedConfidentialKernelSlotExpr) : Bool :=
  match lhs, rhs with
  | none, none => true
  | some lhsExpr, some rhsExpr => checkImportedConfidentialKernelSlotExprEq lhsExpr rhsExpr
  | _, _ => false

end

private def checkImportedConfidentialKernelSlotStatementListEq
  (lhs rhs : List ImportedConfidentialKernelSlotStatement) : Bool :=
  match lhs, rhs with
  | [], [] => true
  | lhsHead :: lhsTail, rhsHead :: rhsTail =>
      checkImportedConfidentialKernelSlotStatementEq lhsHead rhsHead &&
        checkImportedConfidentialKernelSlotStatementListEq lhsTail rhsTail
  | _, _ => false

def checkImportedConfidentialKernelSlotProgramEq
  (lhs rhs : ImportedConfidentialKernelSlotProgram) : Bool :=
  lhs.entrypoint_id == rhs.entrypoint_id &&
    lhs.param_count == rhs.param_count &&
    lhs.return_type == rhs.return_type &&
    lhs.secret_args == rhs.secret_args &&
    lhs.slot_count == rhs.slot_count &&
    checkImportedConfidentialKernelSlotStatementListEq lhs.body rhs.body

def checkImportedConfidentialKernelProgramSlotLowering
  (program : ImportedConfidentialKernelProgram)
  (slotProgram : ImportedConfidentialKernelSlotProgram) : Bool :=
  match program.toConfidentialKernelSlotProgram? with
  | .ok lowered => checkImportedConfidentialKernelSlotProgramEq lowered slotProgram
  | .error _ => false

def ImportedConfidentialKernelProgram.SlotLoweringMatches
  (program : ImportedConfidentialKernelProgram)
  (slotProgram : ImportedConfidentialKernelSlotProgram) : Prop :=
  checkImportedConfidentialKernelProgramSlotLowering program slotProgram = true

@[simp] theorem checkImportedConfidentialKernelProgramSlotLowering_eq_true_iff
  (program : ImportedConfidentialKernelProgram)
  (slotProgram : ImportedConfidentialKernelSlotProgram) :
  checkImportedConfidentialKernelProgramSlotLowering program slotProgram = true ↔
    program.SlotLoweringMatches slotProgram := by
  rfl

private theorem checkImportedConfidentialKernelSlotStatementEq_toRuntime_runtimeNormalForm
  {lhs rhs : ImportedConfidentialKernelSlotStatement}
  (h : checkImportedConfidentialKernelSlotStatementEq lhs rhs = true) :
  lhs.toConfidentialKernelSlotStatement.RuntimeNormalForm ↔
    rhs.toConfidentialKernelSlotStatement.RuntimeNormalForm := by
  cases lhs <;> cases rhs <;>
    simp [checkImportedConfidentialKernelSlotStatementEq,
      ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
      ConfidentialKernelSlotStatement.RuntimeNormalForm] at h ⊢

private theorem checkImportedConfidentialKernelSlotStatementListEq_toRuntime_runtimeNormalForm
  {lhs rhs : List ImportedConfidentialKernelSlotStatement}
  (h : checkImportedConfidentialKernelSlotStatementListEq lhs rhs = true) :
  (∀ stmt ∈ lhs, stmt.toConfidentialKernelSlotStatement.RuntimeNormalForm) →
    (∀ stmt ∈ rhs, stmt.toConfidentialKernelSlotStatement.RuntimeNormalForm) := by
  induction lhs generalizing rhs with
  | nil =>
      cases rhs with
      | nil =>
          intro hNorm
          simpa using hNorm
      | cons rhsHead rhsTail =>
          have : False := by
            change false = true at h
            cases h
          contradiction
  | cons lhsHead lhsTail ih =>
      cases rhs with
      | nil =>
          have : False := by
            change false = true at h
            cases h
          contradiction
      | cons rhsHead rhsTail =>
          have hPair :
              checkImportedConfidentialKernelSlotStatementEq lhsHead rhsHead = true ∧
                checkImportedConfidentialKernelSlotStatementListEq lhsTail rhsTail = true := by
            change
              (checkImportedConfidentialKernelSlotStatementEq lhsHead rhsHead &&
                checkImportedConfidentialKernelSlotStatementListEq lhsTail rhsTail) = true at h
            simpa [Bool.and_eq_true] using h
          clear h
          rcases hPair with ⟨hHead, hTail⟩
          have hHeadNorm :=
            checkImportedConfidentialKernelSlotStatementEq_toRuntime_runtimeNormalForm hHead
          intro hNorm
          intro stmt hMem
          simp at hMem
          cases hMem with
          | inl hEq =>
              subst hEq
              have hHeadLeft :
                  lhsHead.toConfidentialKernelSlotStatement.RuntimeNormalForm := by
                exact hNorm lhsHead (by simp)
              exact hHeadNorm.mp hHeadLeft
          | inr hMemTail =>
              have hTailNorm :
                  ∀ stmt ∈ lhsTail, stmt.toConfidentialKernelSlotStatement.RuntimeNormalForm := by
                intro stmt hMemTail'
                exact hNorm stmt (by simp [hMemTail'])
              exact ih hTail hTailNorm stmt hMemTail

private theorem checkImportedConfidentialKernelSlotProgramEq_runtimeNormalForm
  {lhs rhs : ImportedConfidentialKernelSlotProgram}
  (hEq : checkImportedConfidentialKernelSlotProgramEq lhs rhs = true) :
  lhs.RuntimeNormalForm → rhs.RuntimeNormalForm := by
  intro hNorm
  unfold ImportedConfidentialKernelSlotProgram.RuntimeNormalForm at hNorm ⊢
  have hChecks := hEq
  simp [checkImportedConfidentialKernelSlotProgramEq, Bool.and_eq_true] at hChecks
  have hBodyEq : checkImportedConfidentialKernelSlotStatementListEq lhs.body rhs.body = true :=
    hChecks.2
  have hNormImported :
      ∀ stmt ∈ lhs.body, stmt.toConfidentialKernelSlotStatement.RuntimeNormalForm := by
    intro stmt hMem
    exact
      hNorm stmt.toConfidentialKernelSlotStatement
        (by
          refine List.mem_map.mpr ?_
          exact ⟨stmt, hMem, rfl⟩)
  have hRhsImported :
      ∀ stmt ∈ rhs.body, stmt.toConfidentialKernelSlotStatement.RuntimeNormalForm := by
    exact
      checkImportedConfidentialKernelSlotStatementListEq_toRuntime_runtimeNormalForm hBodyEq
        hNormImported
  intro stmt hMem
  rcases List.mem_map.mp hMem with ⟨importedStmt, hImportedMem, hStmtEq⟩
  subst hStmtEq
  exact hRhsImported importedStmt hImportedMem

theorem importedConfidentialKernelProgram_slotLowering_exists
  (program : ImportedConfidentialKernelProgram)
  (slotProgram : ImportedConfidentialKernelSlotProgram)
  (h : program.SlotLoweringMatches slotProgram) :
  ∃ lowered, program.toConfidentialKernelSlotProgram? = .ok lowered := by
  unfold ImportedConfidentialKernelProgram.SlotLoweringMatches
    checkImportedConfidentialKernelProgramSlotLowering at h
  cases hLowered : program.toConfidentialKernelSlotProgram? with
  | error err =>
      simp [hLowered] at h
  | ok lowered =>
      exact ⟨lowered, rfl⟩

theorem importedConfidentialKernelProgram_slotLowering_runtimeNormalForm
  {program : ImportedConfidentialKernelProgram}
  {slotProgram : ImportedConfidentialKernelSlotProgram}
  (h : program.SlotLoweringMatches slotProgram) :
  slotProgram.RuntimeNormalForm := by
  rcases importedConfidentialKernelProgram_slotLowering_exists program slotProgram h with
    ⟨lowered, hLowered⟩
  have hEq :
      checkImportedConfidentialKernelSlotProgramEq lowered slotProgram = true := by
    unfold ImportedConfidentialKernelProgram.SlotLoweringMatches
      checkImportedConfidentialKernelProgramSlotLowering at h
    rw [hLowered] at h
    simpa using h
  exact
    checkImportedConfidentialKernelSlotProgramEq_runtimeNormalForm hEq
      (importedConfidentialKernelProgram_slotLowering_ok_runtimeNormalForm hLowered)

mutual

def importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps :
  List ImportedConfidentialKernelSlotStatement → List ImportedRuntimeKernelStep
  | [] => []
  | stmt :: stmts =>
      stmt.expectedRuntimeKernelSteps ++
        importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps stmts

def ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps :
  ImportedConfidentialKernelSlotStatement → List ImportedRuntimeKernelStep
  | .declare _ value => value.expectedRuntimeKernelSteps
  | .assign _ value => value.expectedRuntimeKernelSteps
  | .require cond => cond.expectedRuntimeKernelSteps
  | .abortIf cond => cond.expectedRuntimeKernelSteps
  | .cellSet objectId value predicate =>
      value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [importedRuntimeKernelStep "CellSet" (some objectId)]
  | .arraySet objectId index value predicate =>
      index.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [importedRuntimeKernelStep "ArraySet" (some objectId)]
  | .mapPut objectId key value predicate =>
      key.expectedRuntimeKernelSteps ++
        value.expectedRuntimeKernelSteps ++
        (match predicate with
        | none => []
        | some predicate => predicate.expectedRuntimeKernelSteps) ++
        [importedRuntimeKernelStep "MapPut" (some objectId)]
  | .ret value? =>
      match value? with
      | none => []
      | some value => value.expectedRuntimeKernelSteps

def ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps :
  ImportedConfidentialKernelSlotExpr → List ImportedRuntimeKernelStep
  | .literal _ => []
  | .slot _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond _ _ => cond.expectedRuntimeKernelSteps
  | .cellGet objectId => [importedRuntimeKernelStep "CellGet" (some objectId)]
  | .arrayGet objectId index =>
      index.expectedRuntimeKernelSteps ++
        [importedRuntimeKernelStep "ArrayGet" (some objectId)]
  | .mapGet objectId key =>
      key.expectedRuntimeKernelSteps ++
        [importedRuntimeKernelStep "MapGet" (some objectId)]
  | .keccak256 parts =>
      importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps parts

def ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps :
  ImportedConfidentialKernelSlotPureExpr → List ImportedRuntimeKernelStep
  | .literal _ => []
  | .slot _ => []
  | .unary _ expr => expr.expectedRuntimeKernelSteps
  | .binary _ lhs rhs => lhs.expectedRuntimeKernelSteps ++ rhs.expectedRuntimeKernelSteps
  | .select cond whenTrue whenFalse =>
      cond.expectedRuntimeKernelSteps ++
        whenTrue.expectedRuntimeKernelSteps ++
        whenFalse.expectedRuntimeKernelSteps
  | .keccak256 parts =>
      importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps parts

def importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps :
  List ImportedConfidentialKernelSlotExpr → List ImportedRuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps exprs

def importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps :
  List ImportedConfidentialKernelSlotPureExpr → List ImportedRuntimeKernelStep
  | [] => []
  | expr :: exprs =>
      expr.expectedRuntimeKernelSteps ++
        importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps exprs

end

def ImportedConfidentialKernelSlotProgram.expectedRuntimeKernelSteps
  (program : ImportedConfidentialKernelSlotProgram) : List ImportedRuntimeKernelStep :=
  [importedRuntimeKernelStep "Begin"] ++
    importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps program.body ++
    [ importedRuntimeKernelStep "Commit"
    , importedRuntimeKernelStep "Wipe"
    ]

mutual

theorem importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
  : (expr : ImportedConfidentialKernelExpr) →
      (env : ImportedConfidentialKernelSlotEnv) →
      (slotExpr : ImportedConfidentialKernelSlotExpr) →
      importedConfidentialKernelExprToSlotExpr expr env = .ok slotExpr →
        expr.expectedRuntimeKernelSteps = slotExpr.expectedRuntimeKernelSteps
  | .literal _, _, _, h => by
      simp [importedConfidentialKernelExprToSlotExpr] at h
      cases h
      rfl
  | .var name, env, slotExpr, h => by
      cases hResolve : importedConfidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hResolve] at h
          cases h
      | ok slot =>
          simp [importedConfidentialKernelExprToSlotExpr, hResolve] at h
          cases h
          rfl
  | .unary op expr, env, slotExpr, h => by
      cases hExpr : importedConfidentialKernelExprToSlotExpr expr env with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hExpr] at h
          cases h
      | ok slotExpr' =>
          simp [importedConfidentialKernelExprToSlotExpr, hExpr] at h
          cases h
          simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps expr env slotExpr' hExpr]
  | .binary op lhs rhs, env, slotExpr, h => by
      cases hLhs : importedConfidentialKernelExprToSlotExpr lhs env with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hLhs] at h
          cases h
      | ok lhs' =>
          cases hRhs : importedConfidentialKernelExprToSlotExpr rhs env with
          | error err =>
              simp [importedConfidentialKernelExprToSlotExpr, hLhs, hRhs] at h
              cases h
          | ok rhs' =>
              simp [importedConfidentialKernelExprToSlotExpr, hLhs, hRhs] at h
              cases h
              simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
                ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
                importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps lhs env lhs' hLhs,
                importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps rhs env rhs' hRhs]
  | .select cond whenTrue whenFalse, env, slotExpr, h => by
      cases hCond : importedConfidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hCond] at h
          cases h
      | ok cond' =>
          cases hWhenTrue : importedConfidentialKernelPureExprToSlotPureExpr whenTrue env with
          | error err =>
              simp [importedConfidentialKernelExprToSlotExpr, hCond, hWhenTrue] at h
              cases h
          | ok whenTrue' =>
              cases hWhenFalse : importedConfidentialKernelPureExprToSlotPureExpr whenFalse env with
              | error err =>
                  simp [importedConfidentialKernelExprToSlotExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
              | ok whenFalse' =>
                  simp [importedConfidentialKernelExprToSlotExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
                  simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
                    ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps cond env cond' hCond]
  | .cellGet _, _, _, h => by
      simp [importedConfidentialKernelExprToSlotExpr] at h
      cases h
      rfl
  | .arrayGet objectId index, env, slotExpr, h => by
      cases hIndex : importedConfidentialKernelExprToSlotExpr index env with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hIndex] at h
          cases h
      | ok index' =>
          simp [importedConfidentialKernelExprToSlotExpr, hIndex] at h
          cases h
          simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps index env index' hIndex]
  | .mapGet objectId key, env, slotExpr, h => by
      cases hKey : importedConfidentialKernelExprToSlotExpr key env with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hKey] at h
          cases h
      | ok key' =>
          simp [importedConfidentialKernelExprToSlotExpr, hKey] at h
          cases h
          simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps key env key' hKey]
  | .keccak256 parts, env, slotExpr, h => by
      cases hParts : importedConfidentialKernelExprsToSlotExprs parts env with
      | error err =>
          simp [importedConfidentialKernelExprToSlotExpr, hParts] at h
          cases h
      | ok parts' =>
          simp [importedConfidentialKernelExprToSlotExpr, hParts] at h
          cases h
          simp [ImportedConfidentialKernelExpr.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
            importedConfidentialKernelExprsToSlotExprs_expectedRuntimeKernelSteps parts env parts' hParts]

theorem importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
  : (expr : ImportedConfidentialKernelPureExpr) →
      (env : ImportedConfidentialKernelSlotEnv) →
      (slotExpr : ImportedConfidentialKernelSlotPureExpr) →
      importedConfidentialKernelPureExprToSlotPureExpr expr env = .ok slotExpr →
        expr.expectedRuntimeKernelSteps = slotExpr.expectedRuntimeKernelSteps
  | .literal _, _, _, h => by
      simp [importedConfidentialKernelPureExprToSlotPureExpr] at h
      cases h
      rfl
  | .var name, env, slotExpr, h => by
      cases hResolve : importedConfidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hResolve] at h
          cases h
      | ok slot =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hResolve] at h
          cases h
          rfl
  | .unary op expr, env, slotExpr, h => by
      cases hExpr : importedConfidentialKernelPureExprToSlotPureExpr expr env with
      | error err =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hExpr] at h
          cases h
      | ok slotExpr' =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hExpr] at h
          cases h
          simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
            importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
              expr env slotExpr' hExpr]
  | .binary op lhs rhs, env, slotExpr, h => by
      cases hLhs : importedConfidentialKernelPureExprToSlotPureExpr lhs env with
      | error err =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hLhs] at h
          cases h
      | ok lhs' =>
          cases hRhs : importedConfidentialKernelPureExprToSlotPureExpr rhs env with
          | error err =>
              simp [importedConfidentialKernelPureExprToSlotPureExpr, hLhs, hRhs] at h
              cases h
          | ok rhs' =>
              simp [importedConfidentialKernelPureExprToSlotPureExpr, hLhs, hRhs] at h
              cases h
              simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
                ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
                importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps lhs env lhs' hLhs,
                importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps rhs env rhs' hRhs]
  | .select cond whenTrue whenFalse, env, slotExpr, h => by
      cases hCond : importedConfidentialKernelPureExprToSlotPureExpr cond env with
      | error err =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hCond] at h
          cases h
      | ok cond' =>
          cases hWhenTrue : importedConfidentialKernelPureExprToSlotPureExpr whenTrue env with
          | error err =>
              simp [importedConfidentialKernelPureExprToSlotPureExpr, hCond, hWhenTrue] at h
              cases h
          | ok whenTrue' =>
              cases hWhenFalse : importedConfidentialKernelPureExprToSlotPureExpr whenFalse env with
              | error err =>
                  simp [importedConfidentialKernelPureExprToSlotPureExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
              | ok whenFalse' =>
                  simp [importedConfidentialKernelPureExprToSlotPureExpr, hCond, hWhenTrue, hWhenFalse] at h
                  cases h
                  simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
                    ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
                    importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                      cond env cond' hCond,
                    importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                      whenTrue env whenTrue' hWhenTrue,
                    importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                      whenFalse env whenFalse' hWhenFalse]
  | .keccak256 parts, env, slotExpr, h => by
      cases hParts : importedConfidentialKernelPureExprsToSlotPureExprs parts env with
      | error err =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hParts] at h
          cases h
      | ok parts' =>
          simp [importedConfidentialKernelPureExprToSlotPureExpr, hParts] at h
          cases h
          simp [ImportedConfidentialKernelPureExpr.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
            importedConfidentialKernelPureExprsToSlotPureExprs_expectedRuntimeKernelSteps
              parts env parts' hParts]

theorem importedConfidentialKernelExprsToSlotExprs_expectedRuntimeKernelSteps
  : (exprs : List ImportedConfidentialKernelExpr) →
      (env : ImportedConfidentialKernelSlotEnv) →
      (slotExprs : List ImportedConfidentialKernelSlotExpr) →
      importedConfidentialKernelExprsToSlotExprs exprs env = .ok slotExprs →
        importedConfidentialKernelExprListExpectedRuntimeKernelSteps exprs =
          importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps slotExprs
  | [], _, _, h => by
      simp [importedConfidentialKernelExprsToSlotExprs] at h
      cases h
      rfl
  | expr :: exprs, env, slotExprs, h => by
      cases hExpr : importedConfidentialKernelExprToSlotExpr expr env with
      | error err =>
          simp [importedConfidentialKernelExprsToSlotExprs, hExpr] at h
          cases h
      | ok slotExpr =>
          cases hRest : importedConfidentialKernelExprsToSlotExprs exprs env with
          | error err =>
              simp [importedConfidentialKernelExprsToSlotExprs, hExpr, hRest] at h
              cases h
          | ok slotExprs' =>
              simp [importedConfidentialKernelExprsToSlotExprs, hExpr, hRest] at h
              cases h
              simp [importedConfidentialKernelExprListExpectedRuntimeKernelSteps,
                importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps,
                importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps expr env slotExpr hExpr,
                importedConfidentialKernelExprsToSlotExprs_expectedRuntimeKernelSteps
                  exprs env slotExprs' hRest]

theorem importedConfidentialKernelPureExprsToSlotPureExprs_expectedRuntimeKernelSteps
  : (exprs : List ImportedConfidentialKernelPureExpr) →
      (env : ImportedConfidentialKernelSlotEnv) →
      (slotExprs : List ImportedConfidentialKernelSlotPureExpr) →
      importedConfidentialKernelPureExprsToSlotPureExprs exprs env = .ok slotExprs →
        importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps exprs =
          importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps slotExprs
  | [], _, _, h => by
      simp [importedConfidentialKernelPureExprsToSlotPureExprs] at h
      cases h
      rfl
  | expr :: exprs, env, slotExprs, h => by
      cases hExpr : importedConfidentialKernelPureExprToSlotPureExpr expr env with
      | error err =>
          simp [importedConfidentialKernelPureExprsToSlotPureExprs, hExpr] at h
          cases h
      | ok slotExpr =>
          cases hRest : importedConfidentialKernelPureExprsToSlotPureExprs exprs env with
          | error err =>
              simp [importedConfidentialKernelPureExprsToSlotPureExprs, hExpr, hRest] at h
              cases h
          | ok slotExprs' =>
              simp [importedConfidentialKernelPureExprsToSlotPureExprs, hExpr, hRest] at h
              cases h
              simp [importedConfidentialKernelPureExprListExpectedRuntimeKernelSteps,
                importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps,
                importedConfidentialKernelPureExprToSlotPureExpr_expectedRuntimeKernelSteps
                  expr env slotExpr hExpr,
                importedConfidentialKernelPureExprsToSlotPureExprs_expectedRuntimeKernelSteps
                  exprs env slotExprs' hRest]

end

theorem importedConfidentialKernelStatementToSlotStatement_expectedRuntimeKernelSteps
  (entrypoint : String)
  (stmt : ImportedConfidentialKernelStatement)
  (env env' : ImportedConfidentialKernelSlotEnv)
  (slotStmt : ImportedConfidentialKernelSlotStatement)
  (h :
    importedConfidentialKernelStatementToSlotStatement entrypoint stmt env =
      .ok (slotStmt, env')) :
  stmt.expectedRuntimeKernelSteps = slotStmt.expectedRuntimeKernelSteps := by
  cases stmt with
  | declare name ty value =>
      cases hDeclare : importedConfidentialKernelSlotEnvDeclare entrypoint env name with
      | error err =>
          simp [importedConfidentialKernelStatementToSlotStatement, hDeclare] at h
          cases h
      | ok declared =>
          cases declared with
          | mk slot declaredEnv =>
              cases hValue : importedConfidentialKernelExprToSlotExpr value declaredEnv with
              | error err =>
                  have hConcrete :
                      importedConfidentialKernelStatementToSlotStatement
                          entrypoint (.declare name ty value) env = Except.error err := by
                    let f := fun a => (ImportedConfidentialKernelSlotStatement.declare slot a, declaredEnv)
                    have hMap := congrArg (Except.map f) hValue
                    simpa [importedConfidentialKernelStatementToSlotStatement, Except.bind, Except.map,
                      hDeclare, f] using hMap
                  rw [hConcrete] at h
                  cases h
              | ok slotValue =>
                  have hConcrete :
                      importedConfidentialKernelStatementToSlotStatement
                          entrypoint (.declare name ty value) env =
                        Except.ok (ImportedConfidentialKernelSlotStatement.declare slot slotValue, declaredEnv) := by
                    let f := fun a => (ImportedConfidentialKernelSlotStatement.declare slot a, declaredEnv)
                    have hMap := congrArg (Except.map f) hValue
                    simpa [importedConfidentialKernelStatementToSlotStatement, Except.bind, Except.map,
                      hDeclare, f] using hMap
                  have hOk :
                      (Except.ok
                        (ImportedConfidentialKernelSlotStatement.declare slot slotValue, declaredEnv) :
                        Except String
                          (ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv)) =
                      (Except.ok (slotStmt, env') :
                        Except String
                          (ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv)) := by
                    exact hConcrete.symm.trans h
                  injection hOk with hPair
                  cases hPair
                  exact importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                    value env' slotValue hValue
  | assign name value =>
      cases hResolve : importedConfidentialKernelSlotEnvResolve env name with
      | error err =>
          simp [importedConfidentialKernelStatementToSlotStatement, hResolve] at h
          cases h
      | ok slot =>
          cases hValue : importedConfidentialKernelExprToSlotExpr value env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hResolve, hValue] at h
              cases h
          | ok slotValue =>
              simp [importedConfidentialKernelStatementToSlotStatement, hResolve, hValue] at h
              cases h
              simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps value env slotValue hValue]
  | require cond =>
      cases hCond : importedConfidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [importedConfidentialKernelStatementToSlotStatement, hCond] at h
          cases h
      | ok slotCond =>
          simp [importedConfidentialKernelStatementToSlotStatement, hCond] at h
          cases h
          simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
            importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps cond env slotCond hCond]
  | abortIf cond =>
      cases hCond : importedConfidentialKernelExprToSlotExpr cond env with
      | error err =>
          simp [importedConfidentialKernelStatementToSlotStatement, hCond] at h
          cases h
      | ok slotCond =>
          simp [importedConfidentialKernelStatementToSlotStatement, hCond] at h
          cases h
          simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
            ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
            importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps cond env slotCond hCond]
  | cellSet objectId value predicate =>
      cases predicate with
      | none =>
          cases hValue : importedConfidentialKernelExprToSlotExpr value env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hValue] at h
              cases h
          | ok slotValue =>
              simp [importedConfidentialKernelStatementToSlotStatement, hValue] at h
              cases h
              simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                  value env slotValue hValue]
      | some cond =>
          cases hPredicate : importedConfidentialKernelExprToSlotExpr cond env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hPredicate] at h
              cases h
          | ok slotPredicate =>
              cases hValue : importedConfidentialKernelExprToSlotExpr value env with
              | error err =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hValue] at h
                  cases h
              | ok slotValue =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hValue] at h
                  cases h
                  simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                    ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      value env slotValue hValue,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      cond env slotPredicate hPredicate]
  | arraySet objectId index value predicate =>
      cases predicate with
      | none =>
          cases hIndex : importedConfidentialKernelExprToSlotExpr index env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hIndex] at h
              cases h
          | ok slotIndex =>
              cases hValue : importedConfidentialKernelExprToSlotExpr value env with
              | error err =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hIndex, hValue] at h
                  cases h
              | ok slotValue =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hIndex, hValue] at h
                  cases h
                  simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                    ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      index env slotIndex hIndex,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      value env slotValue hValue]
      | some cond =>
          cases hPredicate : importedConfidentialKernelExprToSlotExpr cond env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hPredicate] at h
              cases h
          | ok slotPredicate =>
              cases hIndex : importedConfidentialKernelExprToSlotExpr index env with
              | error err =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hIndex] at h
                  cases h
              | ok slotIndex =>
                  cases hValue : importedConfidentialKernelExprToSlotExpr value env with
                  | error err =>
                      simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hIndex, hValue] at h
                      cases h
                  | ok slotValue =>
                      simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hIndex, hValue] at h
                      cases h
                      simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                        ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                        importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          cond env slotPredicate hPredicate,
                        importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          index env slotIndex hIndex,
                        importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          value env slotValue hValue]
  | mapPut objectId key value predicate =>
      cases predicate with
      | none =>
          cases hKey : importedConfidentialKernelExprToSlotExpr key env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hKey] at h
              cases h
          | ok slotKey =>
              cases hValue : importedConfidentialKernelExprToSlotExpr value env with
              | error err =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hKey, hValue] at h
                  cases h
              | ok slotValue =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hKey, hValue] at h
                  cases h
                  simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                    ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      key env slotKey hKey,
                    importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                      value env slotValue hValue]
      | some cond =>
          cases hPredicate : importedConfidentialKernelExprToSlotExpr cond env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hPredicate] at h
              cases h
          | ok slotPredicate =>
              cases hKey : importedConfidentialKernelExprToSlotExpr key env with
              | error err =>
                  simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hKey] at h
                  cases h
              | ok slotKey =>
                  cases hValue : importedConfidentialKernelExprToSlotExpr value env with
                  | error err =>
                      simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hKey, hValue] at h
                      cases h
                  | ok slotValue =>
                      simp [importedConfidentialKernelStatementToSlotStatement, hPredicate, hKey, hValue] at h
                      cases h
                      simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                        ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                        importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          cond env slotPredicate hPredicate,
                        importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          key env slotKey hKey,
                        importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps
                          value env slotValue hValue]
  | ret value =>
      cases value with
      | none =>
          simp [importedConfidentialKernelStatementToSlotStatement] at h
          cases h
          rfl
      | some expr =>
          cases hExpr : importedConfidentialKernelExprToSlotExpr expr env with
          | error err =>
              simp [importedConfidentialKernelStatementToSlotStatement, hExpr] at h
              cases h
          | ok slotExpr =>
              simp [importedConfidentialKernelStatementToSlotStatement, hExpr] at h
              cases h
              simp [ImportedConfidentialKernelStatement.expectedRuntimeKernelSteps,
                ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
                importedConfidentialKernelExprToSlotExpr_expectedRuntimeKernelSteps expr env slotExpr hExpr]

theorem importedConfidentialKernelStatementsToSlotStatements_expectedRuntimeKernelSteps
  (entrypoint : String)
  (stmts : List ImportedConfidentialKernelStatement)
  (env env' : ImportedConfidentialKernelSlotEnv)
  (slotStmts : List ImportedConfidentialKernelSlotStatement)
  (h :
    importedConfidentialKernelStatementsToSlotStatements entrypoint stmts env =
      .ok (slotStmts, env')) :
  importedConfidentialKernelStatementListExpectedRuntimeKernelSteps stmts =
    importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps slotStmts := by
  induction stmts generalizing env env' slotStmts with
  | nil =>
      simp [importedConfidentialKernelStatementsToSlotStatements] at h
      cases h
      subst slotStmts
      simp [importedConfidentialKernelStatementListExpectedRuntimeKernelSteps,
        importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps]
  | cons stmt rest ih =>
      cases hStmt : importedConfidentialKernelStatementToSlotStatement entrypoint stmt env with
      | error err =>
          simp [importedConfidentialKernelStatementsToSlotStatements, hStmt] at h
          cases h
      | ok stmtResult =>
          cases stmtResult with
          | mk slotStmt env1 =>
              cases hRest :
                  importedConfidentialKernelStatementsToSlotStatements entrypoint rest env1 with
              | error err =>
                  have hConcrete :
                      importedConfidentialKernelStatementsToSlotStatements entrypoint (stmt :: rest) env =
                        Except.error err := by
                    let f :
                        (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) →
                          (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) :=
                      fun a => (slotStmt :: a.1, a.2)
                    have hMap := congrArg (Except.map f) hRest
                    simpa [importedConfidentialKernelStatementsToSlotStatements, Except.bind, Except.map,
                      hStmt, f] using hMap
                  rw [hConcrete] at h
                  cases h
              | ok restResult =>
                  cases restResult with
                  | mk slotRest env2 =>
                      have hConcrete :
                          importedConfidentialKernelStatementsToSlotStatements entrypoint (stmt :: rest) env =
                            Except.ok (slotStmt :: slotRest, env2) := by
                        let f :
                            (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) →
                              (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) :=
                          fun a => (slotStmt :: a.1, a.2)
                        have hMap := congrArg (Except.map f) hRest
                        simpa [importedConfidentialKernelStatementsToSlotStatements, Except.bind, Except.map,
                          hStmt, f] using hMap
                      have hOk :
                          (Except.ok (slotStmt :: slotRest, env2) :
                            Except String
                              (List ImportedConfidentialKernelSlotStatement ×
                                ImportedConfidentialKernelSlotEnv)) =
                          (Except.ok (slotStmts, env') :
                            Except String
                              (List ImportedConfidentialKernelSlotStatement ×
                                ImportedConfidentialKernelSlotEnv)) := by
                        exact hConcrete.symm.trans h
                      injection hOk with hPair
                      cases hPair
                      simp [importedConfidentialKernelStatementListExpectedRuntimeKernelSteps,
                        importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps,
                        importedConfidentialKernelStatementToSlotStatement_expectedRuntimeKernelSteps
                          entrypoint stmt env env1 slotStmt hStmt,
                        ih env1 env' slotRest hRest]

theorem importedConfidentialKernelProgram_slotLowering_ok_expectedRuntimeKernelSteps
  {program : ImportedConfidentialKernelProgram}
  {slotProgram : ImportedConfidentialKernelSlotProgram}
  (h : program.toConfidentialKernelSlotProgram? = .ok slotProgram) :
  program.expectedRuntimeKernelSteps = slotProgram.expectedRuntimeKernelSteps := by
  cases hEnv : importedConfidentialKernelParamsToSlotEnv program.entrypoint_id program.params with
  | error err =>
      simp [ImportedConfidentialKernelProgram.toConfidentialKernelSlotProgram?, hEnv] at h
      cases h
  | ok env =>
      cases hBody :
          importedConfidentialKernelStatementsToSlotStatements program.entrypoint_id program.body env with
      | error err =>
          have hConcrete :
              program.toConfidentialKernelSlotProgram? = Except.error err := by
            let f :
                (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) →
                  ImportedConfidentialKernelSlotProgram :=
              fun a =>
                { entrypoint_id := program.entrypoint_id
                , param_count := program.params.length
                , return_type := program.return_type
                , secret_args := program.secret_args
                , slot_count := a.2.length
                , body := a.1
                }
            have hMap := congrArg (Except.map f) hBody
            simpa [ImportedConfidentialKernelProgram.toConfidentialKernelSlotProgram?,
              Except.bind, Except.map, hEnv, f] using hMap
          rw [hConcrete] at h
          cases h
      | ok bodyResult =>
          cases bodyResult with
          | mk body env' =>
              have hConcrete :
                  program.toConfidentialKernelSlotProgram? =
                    Except.ok
                      { entrypoint_id := program.entrypoint_id
                      , param_count := program.params.length
                      , return_type := program.return_type
                      , secret_args := program.secret_args
                      , slot_count := env'.length
                      , body := body
                      } := by
                let f :
                    (List ImportedConfidentialKernelSlotStatement × ImportedConfidentialKernelSlotEnv) →
                      ImportedConfidentialKernelSlotProgram :=
                  fun a =>
                    { entrypoint_id := program.entrypoint_id
                    , param_count := program.params.length
                    , return_type := program.return_type
                    , secret_args := program.secret_args
                    , slot_count := a.2.length
                    , body := a.1
                    }
                have hMap := congrArg (Except.map f) hBody
                simpa [ImportedConfidentialKernelProgram.toConfidentialKernelSlotProgram?,
                  Except.bind, Except.map, hEnv, f] using hMap
              have hOk :
                  (Except.ok
                    { entrypoint_id := program.entrypoint_id
                    , param_count := program.params.length
                    , return_type := program.return_type
                    , secret_args := program.secret_args
                    , slot_count := env'.length
                    , body := body
                    } : Except String ImportedConfidentialKernelSlotProgram) =
                  (Except.ok slotProgram : Except String ImportedConfidentialKernelSlotProgram) := by
                exact hConcrete.symm.trans h
              injection hOk with hProgram
              cases hProgram
              simp [ImportedConfidentialKernelProgram.expectedRuntimeKernelSteps,
                ImportedConfidentialKernelSlotProgram.expectedRuntimeKernelSteps,
                importedConfidentialKernelStatementsToSlotStatements_expectedRuntimeKernelSteps
                  program.entrypoint_id program.body env env' body hBody]

mutual

theorem importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime :
  (expr : ImportedConfidentialKernelSlotExpr) →
    expr.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      expr.toConfidentialKernelSlotExpr.expectedRuntimeKernelSteps
  | .literal value => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps]
  | .slot slot => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps]
  | .unary op expr => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime expr]
  | .binary op lhs rhs => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime lhs,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime rhs]
  | .select cond whenTrue whenFalse => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime cond]
  | .cellGet objectId => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps]
  | .arrayGet objectId index => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime index]
  | .mapGet objectId key => by
      simp [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime key]
  | .keccak256 parts => by
      simpa [ImportedConfidentialKernelSlotExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr,
        ConfidentialKernelSlotExpr.expectedRuntimeKernelSteps] using
        importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps_toRuntime parts
termination_by expr => sizeOf expr

theorem importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime :
  (expr : ImportedConfidentialKernelSlotPureExpr) →
    expr.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      expr.toConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps
  | .literal value => by
      simp [ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
        ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps]
  | .slot slot => by
      simp [ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
        ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps]
  | .unary op expr => by
      simp [ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
        ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime expr]
  | .binary op lhs rhs => by
      simp [ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
        ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime lhs,
        importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime rhs]
  | .select cond whenTrue whenFalse => by
      simp [ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
        ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime cond,
        importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime whenTrue,
        importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime whenFalse]
  | .keccak256 parts => by
      simpa [ImportedConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr,
        ConfidentialKernelSlotPureExpr.expectedRuntimeKernelSteps] using
        importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps_toRuntime parts
termination_by expr => sizeOf expr

theorem importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps_toRuntime
  : (exprs : List ImportedConfidentialKernelSlotExpr) →
      (importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps exprs).map
          ImportedRuntimeKernelStep.toRuntimeKernelStep =
        confidentialKernelSlotExprListExpectedRuntimeKernelSteps
          (exprs.map ImportedConfidentialKernelSlotExpr.toConfidentialKernelSlotExpr)
  | [] => by
      simp [importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps,
        confidentialKernelSlotExprListExpectedRuntimeKernelSteps]
  | expr :: exprs => by
      have hHead := importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime expr
      have hTail := importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps_toRuntime exprs
      simp [importedConfidentialKernelSlotExprListExpectedRuntimeKernelSteps,
        confidentialKernelSlotExprListExpectedRuntimeKernelSteps, hHead, hTail]
termination_by exprs => sizeOf exprs

theorem importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps_toRuntime
  : (exprs : List ImportedConfidentialKernelSlotPureExpr) →
      (importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps exprs).map
          ImportedRuntimeKernelStep.toRuntimeKernelStep =
        confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps
          (exprs.map ImportedConfidentialKernelSlotPureExpr.toConfidentialKernelSlotPureExpr)
  | [] => by
      simp [importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps,
        confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps]
  | expr :: exprs => by
      have hHead := importedConfidentialKernelSlotPureExpr_expectedRuntimeKernelSteps_toRuntime expr
      have hTail :=
        importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps_toRuntime exprs
      simp [importedConfidentialKernelSlotPureExprListExpectedRuntimeKernelSteps,
        confidentialKernelSlotPureExprListExpectedRuntimeKernelSteps, hHead, hTail]
termination_by exprs => sizeOf exprs

end

theorem importedConfidentialKernelSlotStatement_expectedRuntimeKernelSteps_toRuntime
  (stmt : ImportedConfidentialKernelSlotStatement) :
  stmt.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
    stmt.toConfidentialKernelSlotStatement.expectedRuntimeKernelSteps := by
  cases stmt with
  | declare slot value =>
      simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
        ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | assign slot value =>
      simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
        ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | require cond =>
      simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
        ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | abortIf cond =>
      simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
        ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | cellSet objectId value predicate =>
      cases predicate <;>
        simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
          ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | arraySet objectId index value predicate =>
      cases predicate <;>
        simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
          ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | mapPut objectId key value predicate =>
      cases predicate <;>
        simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
          ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]
  | ret value =>
      cases value <;>
        simp [ImportedConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement,
          ConfidentialKernelSlotStatement.expectedRuntimeKernelSteps,
          importedConfidentialKernelSlotExpr_expectedRuntimeKernelSteps_toRuntime]

theorem importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps_toRuntime
  (stmts : List ImportedConfidentialKernelSlotStatement) :
  (importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps stmts).map
      ImportedRuntimeKernelStep.toRuntimeKernelStep =
    confidentialKernelSlotStatementListExpectedRuntimeKernelSteps
      (stmts.map ImportedConfidentialKernelSlotStatement.toConfidentialKernelSlotStatement) := by
  induction stmts with
  | nil =>
      simp [importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps,
        confidentialKernelSlotStatementListExpectedRuntimeKernelSteps]
  | cons stmt stmts ih =>
      simp [importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps,
        confidentialKernelSlotStatementListExpectedRuntimeKernelSteps,
        importedConfidentialKernelSlotStatement_expectedRuntimeKernelSteps_toRuntime, ih]

theorem importedConfidentialKernelSlotProgram_expectedRuntimeKernelSteps_toRuntime
  (program : ImportedConfidentialKernelSlotProgram) :
  program.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
    program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
  cases program with
  | mk entrypoint_id param_count return_type secret_args slot_count body =>
      simp [ImportedConfidentialKernelSlotProgram.expectedRuntimeKernelSteps,
        ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram,
        ConfidentialKernelSlotProgram.expectedRuntimeKernelSteps,
        importedConfidentialKernelSlotStatementListExpectedRuntimeKernelSteps_toRuntime]

def importedRuntimeKernelSlotDslBundleFieldNames : List String :=
  ["kernel_witness", "confidential_slot_program"]

structure ImportedRuntimeKernelSlotDslBundle where
  kernel_witness : ImportedRuntimeKernelWitness
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeKernelSlotDslBundle.programSteps
  (bundle : ImportedRuntimeKernelSlotDslBundle) : List ImportedRuntimeKernelStep :=
  bundle.confidential_slot_program.expectedRuntimeKernelSteps

def ImportedRuntimeKernelSlotDslBundle.Valid
  (bundle : ImportedRuntimeKernelSlotDslBundle) : Prop :=
  bundle.kernel_witness.ProofGradeValid bundle.confidential_slot_program.entrypoint_id ∧
    bundle.confidential_slot_program.RuntimeNormalForm ∧
    bundle.kernel_witness.expected_kernel_steps = some bundle.programSteps ∧
    bundle.kernel_witness.kernel_steps = bundle.programSteps

def ImportedRuntimeKernelSlotDslBundle.checkValid
  (bundle : ImportedRuntimeKernelSlotDslBundle) : Bool :=
  bundle.kernel_witness.checkProofGrade bundle.confidential_slot_program.entrypoint_id &&
    bundle.confidential_slot_program.checkRuntimeNormalForm &&
    decide (bundle.kernel_witness.expected_kernel_steps = some bundle.programSteps) &&
    decide (bundle.kernel_witness.kernel_steps = bundle.programSteps)

@[simp] theorem importedRuntimeKernelSlotDslBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeKernelSlotDslBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeKernelSlotDslBundle.checkValid ImportedRuntimeKernelSlotDslBundle.Valid
  simp [importedRuntimeKernelWitness_checkProofGrade_eq_true_iff, and_assoc]

theorem importedRuntimeKernelSlotDslBundle_schedule_exact
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.expected_kernel_steps = some bundle.programSteps ∧
    bundle.kernel_witness.kernel_steps = bundle.programSteps := by
  exact hValid.2.2

theorem importedRuntimeKernelSlotDslBundle_runtimeNormalForm
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.confidential_slot_program.RuntimeNormalForm := by
  exact hValid.2.1

theorem importedRuntimeKernelSlotDslBundle_toRuntimeSchedule_exact
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
      some bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
      bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
  rcases importedRuntimeKernelSlotDslBundle_schedule_exact hValid with ⟨hExpected, hKernel⟩
  have hProgram :
      bundle.programSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
        bundle.confidential_slot_program.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    simpa [ImportedRuntimeKernelSlotDslBundle.programSteps] using
      importedConfidentialKernelSlotProgram_expectedRuntimeKernelSteps_toRuntime
        bundle.confidential_slot_program
  constructor
  · simpa [ImportedRuntimeKernelWitness.toRuntimeKernelWitness, hProgram] using
      congrArg (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep)) hExpected
  · simpa [ImportedRuntimeKernelWitness.toRuntimeKernelWitness, hProgram] using
      congrArg (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep) hKernel

theorem importedRuntimeKernelSlotDslBundle_entrypoint_exact
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.entrypoint_id = bundle.confidential_slot_program.entrypoint_id := by
  exact hValid.1.1.1

theorem importedRuntimeKernelSlotDslBundle_toRuntimeEntrypoint_exact
  {bundle : ImportedRuntimeKernelSlotDslBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.toRuntimeKernelWitness.entrypointId =
    bundle.confidential_slot_program.toConfidentialKernelSlotProgram.entrypointId := by
  simpa [ImportedRuntimeKernelWitness.toRuntimeKernelWitness,
    ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram] using
    importedRuntimeKernelSlotDslBundle_entrypoint_exact hValid

def parseImportedRuntimeKernelSlotDslBundle
  (input : String) : Except String ImportedRuntimeKernelSlotDslBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeKernelSlotDslBundle
  (input : String) : Except String ImportedRuntimeKernelSlotDslBundle := do
  let bundle ← parseImportedRuntimeKernelSlotDslBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw "imported proof-grade runtime kernel slot DSL bundle does not satisfy Lean validity checks"

def loadImportedRuntimeKernelSlotDslBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelSlotDslBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelSlotDslBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime kernel slot DSL bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelSlotDslBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelSlotDslBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelSlotDslBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel slot DSL bundle: {err}"

def importedRuntimeKernelLoweringBundleFieldNames : List String :=
  ["kernel_witness", "confidential_program", "confidential_slot_program"]

structure ImportedRuntimeKernelLoweringBundle where
  kernel_witness : ImportedRuntimeKernelWitness
  confidential_program : ImportedConfidentialKernelProgram
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeKernelLoweringBundle.namedBundle
  (bundle : ImportedRuntimeKernelLoweringBundle) : ImportedRuntimeKernelDslBundle :=
  { kernel_witness := bundle.kernel_witness
  , confidential_program := bundle.confidential_program
  }

def ImportedRuntimeKernelLoweringBundle.slotBundle
  (bundle : ImportedRuntimeKernelLoweringBundle) : ImportedRuntimeKernelSlotDslBundle :=
  { kernel_witness := bundle.kernel_witness
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeKernelLoweringBundle.Valid
  (bundle : ImportedRuntimeKernelLoweringBundle) : Prop :=
  bundle.namedBundle.Valid ∧
    bundle.confidential_program.SlotLoweringMatches bundle.confidential_slot_program

def ImportedRuntimeKernelLoweringBundle.checkValid
  (bundle : ImportedRuntimeKernelLoweringBundle) : Bool :=
  bundle.namedBundle.checkValid &&
    checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program

def ImportedRuntimeKernelLoweringBundle.toRuntimeKernelLoweringBundle?
  (bundle : ImportedRuntimeKernelLoweringBundle) :
  Except String RuntimeKernelLoweringBundle := do
  let lowered ← bundle.confidential_program.toConfidentialKernelSlotProgram?
  pure
    { kernelWitness := bundle.kernel_witness.toRuntimeKernelWitness
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    }

@[simp] theorem importedRuntimeKernelLoweringBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeKernelLoweringBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeKernelLoweringBundle.checkValid
    ImportedRuntimeKernelLoweringBundle.Valid
    ImportedRuntimeKernelLoweringBundle.namedBundle
  simp [importedRuntimeKernelDslBundle_checkValid_eq_true_iff,
    checkImportedConfidentialKernelProgramSlotLowering_eq_true_iff]

theorem importedRuntimeKernelLoweringBundle_lowering_exact
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid) :
  checkImportedConfidentialKernelProgramSlotLowering
      bundle.confidential_program bundle.confidential_slot_program = true := by
  exact hValid.2

theorem importedRuntimeKernelLoweringBundle_namedSchedule_exact
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid) :
  bundle.kernel_witness.expected_kernel_steps =
      some bundle.confidential_program.expectedRuntimeKernelSteps ∧
    bundle.kernel_witness.kernel_steps = bundle.confidential_program.expectedRuntimeKernelSteps := by
  exact importedRuntimeKernelDslBundle_schedule_exact hValid.1

theorem importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_exact
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.kernel_witness.expected_kernel_steps =
        some lowered.expectedRuntimeKernelSteps ∧
      bundle.kernel_witness.kernel_steps = lowered.expectedRuntimeKernelSteps := by
  rcases importedRuntimeKernelLoweringBundle_namedSchedule_exact hValid with ⟨hExpected, hKernel⟩
  rcases importedConfidentialKernelProgram_slotLowering_exists
      bundle.confidential_program bundle.confidential_slot_program hValid.2 with
    ⟨lowered, hLowered⟩
  have hSteps :
      bundle.confidential_program.expectedRuntimeKernelSteps =
        lowered.expectedRuntimeKernelSteps := by
    exact importedConfidentialKernelProgram_slotLowering_ok_expectedRuntimeKernelSteps hLowered
  exact ⟨lowered, hLowered, by simpa [hSteps] using hExpected,
    by simpa [hSteps] using hKernel⟩

theorem importedRuntimeKernelLoweringBundle_lowered_toRuntimeExact
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid)
  {lowered : ImportedConfidentialKernelSlotProgram}
  (hLowered : bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered) :
  bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
      some lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
      lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
    bundle.confidential_program.toConfidentialKernelProgram.SlotLoweringMatches
      lowered.toConfidentialKernelSlotProgram := by
  have hNamed := importedRuntimeKernelDslBundle_toRuntimeSchedule_exact hValid.1
  have hLowering :=
    importedConfidentialKernelProgram_slotLowering_ok_toRuntime hLowered
  have hStepEq :
      bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps =
        lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    exact confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps hLowering
  exact
    ⟨by simpa [ImportedRuntimeKernelLoweringBundle.namedBundle, hStepEq] using hNamed.1,
      by simpa [ImportedRuntimeKernelLoweringBundle.namedBundle, hStepEq] using hNamed.2,
      hLowering⟩

theorem importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_toRuntime_exact
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
        some lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
      bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
        lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
      bundle.confidential_program.toConfidentialKernelProgram.SlotLoweringMatches
        lowered.toConfidentialKernelSlotProgram := by
  rcases importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_exact hValid with
    ⟨lowered, hLowered, _, _⟩
  rcases importedRuntimeKernelLoweringBundle_lowered_toRuntimeExact hValid hLowered with
    ⟨hExpected, hKernel, hLowering⟩
  exact ⟨lowered, hLowered, hExpected, hKernel, hLowering⟩

theorem importedRuntimeKernelLoweringBundle_lowered_toRuntimeValid
  {bundle : ImportedRuntimeKernelLoweringBundle}
  (hValid : bundle.Valid)
  {lowered : ImportedConfidentialKernelSlotProgram}
  (hLowered : bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered) :
  RuntimeKernelLoweringBundle.Valid
    { kernelWitness := bundle.kernel_witness.toRuntimeKernelWitness
    , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
    , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
    } := by
  have hProofGrade :
      bundle.kernel_witness.toRuntimeKernelWitness.ProofGradeValid
        bundle.confidential_program.toConfidentialKernelProgram.entrypointId := by
    simpa [ImportedConfidentialKernelProgram.toConfidentialKernelProgram] using
      importedRuntimeKernelWitness_toRuntimeKernelWitness_proofGradeValid
        bundle.kernel_witness bundle.confidential_program.entrypoint_id hValid.1.1
  have hNamed :
      bundle.kernel_witness.toRuntimeKernelWitness.expectedKernelSteps =
          some bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps ∧
        bundle.kernel_witness.toRuntimeKernelWitness.kernelSteps =
          bundle.confidential_program.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
    exact importedRuntimeKernelDslBundle_toRuntimeSchedule_exact hValid.1
  have hLowering :
      bundle.confidential_program.toConfidentialKernelProgram.SlotLoweringMatches
        lowered.toConfidentialKernelSlotProgram := by
    exact importedConfidentialKernelProgram_slotLowering_ok_toRuntime hLowered
  exact ⟨⟨hProofGrade, hNamed.1, hNamed.2⟩, hLowering⟩

theorem importedRuntimeKernelLoweringBundle_toRuntimeValid
  (bundle : ImportedRuntimeKernelLoweringBundle)
  (hValid : bundle.Valid) :
  ∃ lowered,
    bundle.confidential_program.toConfidentialKernelSlotProgram? = .ok lowered ∧
      RuntimeKernelLoweringBundle.Valid
        { kernelWitness := bundle.kernel_witness.toRuntimeKernelWitness
        , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
        , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
        } := by
  rcases importedRuntimeKernelLoweringBundle_recomputedSlotSchedule_exact hValid with
    ⟨lowered, hLowered, _, _⟩
  exact
    ⟨lowered, hLowered,
      importedRuntimeKernelLoweringBundle_lowered_toRuntimeValid hValid hLowered⟩

theorem importedRuntimeKernelLoweringBundle_toRuntimeBundle_sound
  (bundle : ImportedRuntimeKernelLoweringBundle)
  (hValid : bundle.Valid) :
  ∃ runtimeBundle,
    bundle.toRuntimeKernelLoweringBundle? = .ok runtimeBundle ∧
      runtimeBundle.Valid := by
  rcases importedRuntimeKernelLoweringBundle_toRuntimeValid bundle hValid with
    ⟨lowered, hLowered, hRuntimeValid⟩
  refine ⟨{ kernelWitness := bundle.kernel_witness.toRuntimeKernelWitness
          , confidentialProgram := bundle.confidential_program.toConfidentialKernelProgram
          , confidentialSlotProgram := lowered.toConfidentialKernelSlotProgram
          }, ?_, hRuntimeValid⟩
  unfold ImportedRuntimeKernelLoweringBundle.toRuntimeKernelLoweringBundle?
  rw [hLowered]
  rfl

def parseImportedRuntimeKernelLoweringBundle
  (input : String) : Except String ImportedRuntimeKernelLoweringBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeKernelLoweringBundle
  (input : String) : Except String ImportedRuntimeKernelLoweringBundle := do
  let bundle ← parseImportedRuntimeKernelLoweringBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw
      "imported proof-grade runtime kernel lowering bundle does not satisfy Lean validity checks"

def parseAndCheckImportedProofGradeRuntimeKernelLoweringBundleToRuntimeBundle
  (input : String) : Except String RuntimeKernelLoweringBundle := do
  let bundle ← parseAndCheckImportedProofGradeRuntimeKernelLoweringBundle input
  match bundle.toRuntimeKernelLoweringBundle? with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw
        s!"validated imported runtime kernel lowering bundle failed to recompute runtime lowering bundle: {err}"

def loadImportedRuntimeKernelLoweringBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelLoweringBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime kernel lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelLoweringBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelLoweringBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel lowering bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelLoweringBundleToRuntimeBundle
  (path : System.FilePath) : IO RuntimeKernelLoweringBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelLoweringBundleToRuntimeBundle input with
  | .ok runtimeBundle =>
      pure runtimeBundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate/recompute runtime kernel lowering bundle: {err}"

end UOToolchain
