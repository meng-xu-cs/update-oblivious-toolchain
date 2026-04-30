import UOToolchain.ConfidentialKernelDsl

open UOToolchain

namespace GenerateConfidentialKernelRust

def joinSep (sep : String) : List String → String
  | [] => ""
  | x :: xs => xs.foldl (fun acc part => acc ++ sep ++ part) x

def rustString (s : String) : String :=
  "\"" ++ s ++ "\""

def rustBool (b : Bool) : String :=
  if b then "true" else "false"

def operandSlice (operands : String) : String :=
  let parts :=
    if operands = "" then
      []
    else
      operands.splitOn ","
  "&[" ++ joinSep ", " (parts.map rustString) ++ "]"

def tailOpcode (opcode : String) : String :=
  if opcode = "" then
    "None"
  else
    "Some(UoOpcode::" ++ opcode ++ ")"

def statementEffectVariant : String → String
  | "store_slot" => "StoreSlot"
  | "guard_only" => "GuardOnly"
  | "abort_flag" => "AbortFlag"
  | "cell_set" => "CellSet"
  | "array_set" => "ArraySet"
  | "map_put" => "MapPut"
  | "return_value" => "ReturnValue"
  | other => "UnknownGeneratedStatementEffect_" ++ other

def zip6
  : List α → List β → List γ → List δ → List ε → List ζ →
      List (α × β × γ × δ × ε × ζ)
  | a :: as, b :: bs, c :: cs, d :: ds, e :: es, f :: fs =>
      (a, b, c, d, e, f) :: zip6 as bs cs ds es fs
  | _, _, _, _, _, _ => []

def zip4
  : List α → List β → List γ → List δ → List (α × β × γ × δ)
  | a :: as, b :: bs, c :: cs, d :: ds =>
      (a, b, c, d) :: zip4 as bs cs ds
  | _, _, _, _ => []

def zip2 : List α → List β → List (α × β)
  | a :: as, b :: bs => (a, b) :: zip2 as bs
  | _, _ => []

def statementKindVariants : List String :=
  ["Declare", "Assign", "Require", "AbortIf", "CellSet", "ArraySet", "MapPut", "Return"]

def namedExprKindVariants : List String :=
  ["Literal", "Var", "Unary", "Binary", "Select", "CellGet", "ArrayGet", "MapGet",
    "StructField", "ArrayIndex", "Keccak256"]

def slotExprKindVariants : List String :=
  ["Literal", "Slot", "Unary", "Binary", "Select", "CellGet", "ArrayGet", "MapGet",
    "StructField", "ArrayIndex", "Keccak256"]

def namedPureExprKindVariants : List String :=
  ["Literal", "Var", "Unary", "Binary", "Select", "StructField", "ArrayIndex", "Keccak256"]

def slotPureExprKindVariants : List String :=
  ["Literal", "Slot", "Unary", "Binary", "Select", "StructField", "ArrayIndex", "Keccak256"]

def checkLength (label : String) (expected : Nat) (actual : Nat) : IO Unit := do
  if actual == expected then
    pure ()
  else
    throw <| IO.userError s!"{label} length mismatch: expected {expected}, got {actual}"

def checkProfileLengths : IO Unit := do
  checkLength "statement kind variants" 8 statementKindVariants.length
  checkLength "statement trace names" 8 confidentialKernelStatementTraceNames.length
  checkLength "statement runtime-normal-form flags" 8 confidentialKernelStatementRuntimeNormalFormFlags.length
  checkLength "statement effect kinds" 8 confidentialKernelStatementEffectKinds.length
  checkLength "statement evaluated operands" 8 confidentialKernelStatementEvaluatedOperands.length
  checkLength "statement tail opcodes" 8 confidentialKernelStatementTailOpcodes.length
  checkLength "named expression kind variants" 11 namedExprKindVariants.length
  checkLength "named expression evaluated operands" 11 confidentialKernelExprEvaluatedOperands.length
  checkLength "named expression tail opcodes" 11 confidentialKernelExprTailOpcodes.length
  checkLength "slot expression kind variants" 11 slotExprKindVariants.length
  checkLength "slot expression evaluated operands" 11 confidentialKernelSlotExprEvaluatedOperands.length
  checkLength "slot expression tail opcodes" 11 confidentialKernelSlotExprTailOpcodes.length
  checkLength "named pure expression kind variants" 8 namedPureExprKindVariants.length
  checkLength "named pure expression evaluated operands" 8 confidentialKernelPureExprEvaluatedOperands.length
  checkLength "slot pure expression kind variants" 8 slotPureExprKindVariants.length
  checkLength "slot pure expression evaluated operands" 8 confidentialKernelSlotPureExprEvaluatedOperands.length

def renderStatementProfile (row : String × String × Bool × String × String × String) : String :=
  match row with
  | (kind, traceName, runtimeNormalForm, effectKind, evaluatedOperands, opcode) =>
      "    ConfidentialKernelStatementProfile {\n" ++
      "        kind: ConfidentialKernelStatementKind::" ++ kind ++ ",\n" ++
      "        trace_name: " ++ rustString traceName ++ ",\n" ++
      "        runtime_normal_form: " ++ rustBool runtimeNormalForm ++ ",\n" ++
      "        effect_kind: ConfidentialKernelStatementEffectKind::" ++
        statementEffectVariant effectKind ++ ",\n" ++
      "        evaluated_operands: " ++ operandSlice evaluatedOperands ++ ",\n" ++
      "        tail_opcode: " ++ tailOpcode opcode ++ ",\n" ++
      "    },\n"

def renderExprProfile
  (profileType kindType : String)
  (row : String × String × String × String) : String :=
  match row with
  | (kind, evaluatedOperands, opcode, _name) =>
      "    " ++ profileType ++ " {\n" ++
      "        kind: " ++ kindType ++ "::" ++ kind ++ ",\n" ++
      "        evaluated_operands: " ++ operandSlice evaluatedOperands ++ ",\n" ++
      "        tail_opcode: " ++ tailOpcode opcode ++ ",\n" ++
      "    },\n"

def renderPureExprProfile
  (profileType kindType : String)
  (row : String × String) : String :=
  match row with
  | (kind, evaluatedOperands) =>
      "    " ++ profileType ++ " {\n" ++
      "        kind: " ++ kindType ++ "::" ++ kind ++ ",\n" ++
      "        evaluated_operands: " ++ operandSlice evaluatedOperands ++ ",\n" ++
      "    },\n"

def renderStatementProfiles : String :=
  let rows :=
    zip6
      statementKindVariants
      confidentialKernelStatementTraceNames
      confidentialKernelStatementRuntimeNormalFormFlags
      confidentialKernelStatementEffectKinds
      confidentialKernelStatementEvaluatedOperands
      confidentialKernelStatementTailOpcodes
  "pub const CONFIDENTIAL_KERNEL_STATEMENT_PROFILES: [ConfidentialKernelStatementProfile; 8] = [\n" ++
  joinSep "" (rows.map renderStatementProfile) ++
  "];\n"

def renderNamedExprProfiles : String :=
  let rows :=
    zip4
      namedExprKindVariants
      confidentialKernelExprEvaluatedOperands
      confidentialKernelExprTailOpcodes
      confidentialKernelExprEvaluatedOperands
  "pub const CONFIDENTIAL_KERNEL_EXPR_PROFILES: [ConfidentialKernelExprProfile; 11] = [\n" ++
  joinSep "" (rows.map (renderExprProfile "ConfidentialKernelExprProfile" "ConfidentialKernelExprKind")) ++
  "];\n"

def renderSlotExprProfiles : String :=
  let rows :=
    zip4
      slotExprKindVariants
      confidentialKernelSlotExprEvaluatedOperands
      confidentialKernelSlotExprTailOpcodes
      confidentialKernelSlotExprEvaluatedOperands
  "pub const CONFIDENTIAL_KERNEL_SLOT_EXPR_PROFILES: [ConfidentialKernelSlotExprProfile; 11] = [\n" ++
  joinSep "" (rows.map (renderExprProfile "ConfidentialKernelSlotExprProfile" "ConfidentialKernelSlotExprKind")) ++
  "];\n"

def renderNamedPureExprProfiles : String :=
  let rows := zip2 namedPureExprKindVariants confidentialKernelPureExprEvaluatedOperands
  "pub const CONFIDENTIAL_KERNEL_PURE_EXPR_PROFILES: [ConfidentialKernelPureExprProfile; 8] = [\n" ++
  joinSep "" (rows.map (renderPureExprProfile "ConfidentialKernelPureExprProfile" "ConfidentialKernelPureExprKind")) ++
  "];\n"

def renderSlotPureExprProfiles : String :=
  let rows := zip2 slotPureExprKindVariants confidentialKernelSlotPureExprEvaluatedOperands
  "pub const CONFIDENTIAL_KERNEL_SLOT_PURE_EXPR_PROFILES: [ConfidentialKernelSlotPureExprProfile; 8] = [\n" ++
  joinSep "" (rows.map (renderPureExprProfile "ConfidentialKernelSlotPureExprProfile" "ConfidentialKernelSlotPureExprKind")) ++
  "];\n"

def generatedInterpreter : String :=
  joinSep "\n"
    [ "fn note_abort_generated(state: &mut ConfidentialKernelInterpreterState, cond: bool) {"
    , "    state.aborted = masked_select_bool(cond, true, state.aborted);"
    , "}"
    , ""
    , "pub(super) fn execute_confidential_kernel_slot_program_generated<"
    , "    R: ConfidentialKernelSlotRuntime,"
    , ">("
    , "    runtime: &mut R,"
    , "    program: &ConfidentialKernelSlotProgram,"
    , ") -> Result<ConfidentialKernelExecutionOutcome> {"
    , "    if !program.is_runtime_normal_form() {"
    , "        bail!("
    , "            \"confidential slot program {} is not in runtime normal form\","
    , "            program.entrypoint_id"
    , "        );"
    , "    }"
    , "    let mut state = ConfidentialKernelInterpreterState::default();"
    , "    execute_confidential_kernel_slot_block_generated(runtime, &program.body, &mut state)?;"
    , "    Ok(ConfidentialKernelExecutionOutcome::new("
    , "        state.aborted,"
    , "        state.return_value,"
    , "    ))"
    , "}"
    , ""
    , "fn execute_confidential_kernel_slot_block_generated<R: ConfidentialKernelSlotRuntime>("
    , "    runtime: &mut R,"
    , "    statements: &[ConfidentialKernelSlotStatement],"
    , "    state: &mut ConfidentialKernelInterpreterState,"
    , ") -> Result<()> {"
    , "    for statement in statements {"
    , "        runtime.note_statement(statement)?;"
    , "        execute_confidential_kernel_slot_statement_generated(runtime, statement, state)?;"
    , "    }"
    , "    Ok(())"
    , "}"
    , ""
    , "pub(super) fn execute_confidential_kernel_slot_statement_generated<"
    , "    R: ConfidentialKernelSlotRuntime,"
    , ">("
    , "    runtime: &mut R,"
    , "    statement: &ConfidentialKernelSlotStatement,"
    , "    state: &mut ConfidentialKernelInterpreterState,"
    , ") -> Result<()> {"
    , "    match statement {"
    , "        ConfidentialKernelSlotStatement::Declare { slot, value }"
    , "        | ConfidentialKernelSlotStatement::Assign { slot, value } => {"
    , "            let value = eval_confidential_kernel_slot_expr_generated(runtime, value, state)?;"
    , "            runtime.store_slot(*slot, value)?;"
    , "        }"
    , "        ConfidentialKernelSlotStatement::Require { .. } => {"
    , "            bail!(\"confidential slot program must be normalized before runtime execution\");"
    , "        }"
    , "        ConfidentialKernelSlotStatement::AbortIf { cond } => {"
    , "            let cond = eval_confidential_kernel_slot_expr_generated(runtime, cond, state)?"
    , "                .as_bool()"
    , "                .ok_or_else(|| anyhow!(\"abort condition must be boolean\"))?;"
    , "            note_abort_generated(state, cond);"
    , "        }"
    , "        ConfidentialKernelSlotStatement::CellSet {"
    , "            object_id,"
    , "            value,"
    , "            predicate,"
    , "        } => {"
    , "            let value = eval_confidential_kernel_slot_expr_generated(runtime, value, state)?;"
    , "            let predicate = eval_optional_confidential_kernel_predicate_generated("
    , "                runtime, predicate, \"cell\", state,"
    , "            )?;"
    , "            runtime.cell_set(*object_id, value, predicate)?;"
    , "        }"
    , "        ConfidentialKernelSlotStatement::ArraySet {"
    , "            object_id,"
    , "            index,"
    , "            value,"
    , "            predicate,"
    , "        } => {"
    , "            let index = eval_confidential_kernel_slot_expr_generated(runtime, index, state)?"
    , "                .as_uint()"
    , "                .ok_or_else(|| anyhow!(\"array index must be uint\"))?;"
    , "            let index = index.to_usize_saturating();"
    , "            let value = eval_confidential_kernel_slot_expr_generated(runtime, value, state)?;"
    , "            let predicate = eval_optional_confidential_kernel_predicate_generated("
    , "                runtime, predicate, \"array\", state,"
    , "            )?;"
    , "            runtime.array_set(*object_id, index, value, predicate)?;"
    , "        }"
    , "        ConfidentialKernelSlotStatement::MapPut {"
    , "            object_id,"
    , "            key,"
    , "            value,"
    , "            predicate,"
    , "        } => {"
    , "            let key = eval_confidential_kernel_slot_expr_generated(runtime, key, state)?;"
    , "            let value = eval_confidential_kernel_slot_expr_generated(runtime, value, state)?;"
    , "            let predicate = eval_optional_confidential_kernel_predicate_generated("
    , "                runtime, predicate, \"map\", state,"
    , "            )?;"
    , "            let overflowed = runtime.map_put(*object_id, key, value, predicate)?;"
    , "            note_abort_generated(state, overflowed);"
    , "        }"
    , "        ConfidentialKernelSlotStatement::Return { value } => {"
    , "            let return_value = if let Some(expr) = value.as_ref() {"
    , "                Some(eval_confidential_kernel_slot_expr_generated("
    , "                    runtime, expr, state,"
    , "                )?)"
    , "            } else {"
    , "                None"
    , "            };"
    , "            state.return_value = return_value;"
    , "        }"
    , "    }"
    , "    Ok(())"
    , "}"
    , ""
    , "fn lhs_uint_generated(value: &Value) -> Result<Uint256> {"
    , "    value"
    , "        .as_uint()"
    , "        .ok_or_else(|| anyhow!(\"expected uint-compatible value\"))"
    , "}"
    , ""
    , "fn lhs_bool_generated(value: &Value) -> Result<bool> {"
    , "    value"
    , "        .as_bool()"
    , "        .ok_or_else(|| anyhow!(\"expected bool-compatible value\"))"
    , "}"
    , ""
    , "fn eval_confidential_kernel_unary_generated(op: &UnaryOp, value: Value) -> Result<Value> {"
    , "    match op {"
    , "        UnaryOp::Not => Ok(Value::Bool("
    , "            !value"
    , "                .as_bool()"
    , "                .ok_or_else(|| anyhow!(\"logical not expects bool\"))?,"
    , "        )),"
    , "        UnaryOp::Neg => Ok(Value::Uint("
    , "            value"
    , "                .as_uint()"
    , "                .ok_or_else(|| anyhow!(\"negation expects uint\"))?"
    , "                .wrapping_neg(),"
    , "        )),"
    , "    }"
    , "}"
    , ""
    , "fn eval_confidential_kernel_binary_generated("
    , "    op: &BinaryOp,"
    , "    lhs: Value,"
    , "    rhs: Value,"
    , ") -> Result<Value> {"
    , "    match op {"
    , "        BinaryOp::Add => Ok(Value::Uint("
    , "            lhs_uint_generated(&lhs)?.wrapping_add(lhs_uint_generated(&rhs)?),"
    , "        )),"
    , "        BinaryOp::Sub => Ok(Value::Uint("
    , "            lhs_uint_generated(&lhs)?.wrapping_sub(lhs_uint_generated(&rhs)?),"
    , "        )),"
    , "        BinaryOp::Mul => Ok(Value::Uint("
    , "            lhs_uint_generated(&lhs)?.wrapping_mul(lhs_uint_generated(&rhs)?),"
    , "        )),"
    , "        BinaryOp::Div => {"
    , "            let divisor = lhs_uint_generated(&rhs)?;"
    , "            Ok(Value::Uint(if divisor.is_zero() {"
    , "                Uint256::ZERO"
    , "            } else {"
    , "                lhs_uint_generated(&lhs)?.div_rem(divisor).0"
    , "            }))"
    , "        }"
    , "        BinaryOp::Mod => {"
    , "            let divisor = lhs_uint_generated(&rhs)?;"
    , "            Ok(Value::Uint(if divisor.is_zero() {"
    , "                Uint256::ZERO"
    , "            } else {"
    , "                lhs_uint_generated(&lhs)?.div_rem(divisor).1"
    , "            }))"
    , "        }"
    , "        BinaryOp::BitAnd => Ok(Value::Uint("
    , "            lhs_uint_generated(&lhs)?.bitand(lhs_uint_generated(&rhs)?),"
    , "        )),"
    , "        BinaryOp::BitOr => Ok(Value::Uint("
    , "            lhs_uint_generated(&lhs)?.bitor(lhs_uint_generated(&rhs)?),"
    , "        )),"
    , "        BinaryOp::BitXor => Ok(Value::Uint("
    , "            lhs_uint_generated(&lhs)?.bitxor(lhs_uint_generated(&rhs)?),"
    , "        )),"
    , "        BinaryOp::Eq => Ok(Value::Bool(lhs == rhs)),"
    , "        BinaryOp::Neq => Ok(Value::Bool(lhs != rhs)),"
    , "        BinaryOp::Lt => Ok(Value::Bool("
    , "            lhs_uint_generated(&lhs)? < lhs_uint_generated(&rhs)?,"
    , "        )),"
    , "        BinaryOp::Lte => Ok(Value::Bool("
    , "            lhs_uint_generated(&lhs)? <= lhs_uint_generated(&rhs)?,"
    , "        )),"
    , "        BinaryOp::Gt => Ok(Value::Bool("
    , "            lhs_uint_generated(&lhs)? > lhs_uint_generated(&rhs)?,"
    , "        )),"
    , "        BinaryOp::Gte => Ok(Value::Bool("
    , "            lhs_uint_generated(&lhs)? >= lhs_uint_generated(&rhs)?,"
    , "        )),"
    , "        BinaryOp::And => Ok(Value::Bool("
    , "            lhs_bool_generated(&lhs)? && lhs_bool_generated(&rhs)?,"
    , "        )),"
    , "        BinaryOp::Or => Ok(Value::Bool("
    , "            lhs_bool_generated(&lhs)? || lhs_bool_generated(&rhs)?,"
    , "        )),"
    , "    }"
    , "}"
    , ""
    , "fn eval_confidential_kernel_struct_field_generated(base: Value, field: &str) -> Result<Value> {"
    , "    match &base {"
    , "        Value::Struct(fields) => fields"
    , "            .iter()"
    , "            .find(|(name, _)| name == field)"
    , "            .map(|(_, value)| value.clone())"
    , "            .ok_or_else(|| anyhow!(\"unknown struct field {field}\")),"
    , "        _ => bail!(\"struct field access requires struct value\"),"
    , "    }"
    , "}"
    , ""
    , "fn eval_confidential_kernel_array_index_generated(base: Value, index: Value) -> Result<Value> {"
    , "    let index = index"
    , "        .as_uint()"
    , "        .ok_or_else(|| anyhow!(\"array index must be uint\"))?"
    , "        .to_usize_saturating();"
    , "    match &base {"
    , "        Value::Array(values) => values"
    , "            .get(index)"
    , "            .cloned()"
    , "            .ok_or_else(|| anyhow!(\"array literal index out of bounds\")),"
    , "        _ => bail!(\"array indexing requires an array value\"),"
    , "    }"
    , "}"
    , ""
    , "pub(super) fn eval_optional_confidential_kernel_predicate_generated<"
    , "    R: ConfidentialKernelSlotRuntime,"
    , ">("
    , "    runtime: &mut R,"
    , "    predicate: &Option<ConfidentialKernelSlotExpr>,"
    , "    label: &str,"
    , "    state: &mut ConfidentialKernelInterpreterState,"
    , ") -> Result<Option<bool>> {"
    , "    predicate"
    , "        .as_ref()"
    , "        .map(|expr| eval_confidential_kernel_slot_expr_generated(runtime, expr, state))"
    , "        .transpose()?"
    , "        .map(|value| {"
    , "            value"
    , "                .as_bool()"
    , "                .ok_or_else(|| anyhow!(\"{label} predicate must be boolean\"))"
    , "        })"
    , "        .transpose()"
    , "}"
    , ""
    , "pub(super) fn eval_confidential_kernel_slot_expr_generated<R: ConfidentialKernelSlotRuntime>("
    , "    runtime: &mut R,"
    , "    expr: &ConfidentialKernelSlotExpr,"
    , "    state: &mut ConfidentialKernelInterpreterState,"
    , ") -> Result<Value> {"
    , "    match expr {"
    , "        ConfidentialKernelSlotExpr::Literal { value } => Ok(value.clone()),"
    , "        ConfidentialKernelSlotExpr::Slot { slot } => runtime.load_slot(*slot),"
    , "        ConfidentialKernelSlotExpr::Unary { op, expr } => {"
    , "            let value = eval_confidential_kernel_slot_expr_generated(runtime, expr, state)?;"
    , "            eval_confidential_kernel_unary_generated(op, value)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::Binary { op, lhs, rhs } => {"
    , "            let lhs = eval_confidential_kernel_slot_expr_generated(runtime, lhs, state)?;"
    , "            let rhs = eval_confidential_kernel_slot_expr_generated(runtime, rhs, state)?;"
    , "            eval_confidential_kernel_binary_generated(op, lhs, rhs)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::Select {"
    , "            cond,"
    , "            when_true,"
    , "            when_false,"
    , "        } => {"
    , "            let cond = eval_confidential_kernel_slot_expr_generated(runtime, cond, state)?"
    , "                .as_bool()"
    , "                .ok_or_else(|| anyhow!(\"select condition must be boolean\"))?;"
    , "            let when_true = eval_confidential_kernel_slot_pure_expr_generated(runtime, when_true)?;"
    , "            let when_false ="
    , "                eval_confidential_kernel_slot_pure_expr_generated(runtime, when_false)?;"
    , "            Value::confidential_select(cond, when_true, when_false)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::CellGet { object_id } => runtime.cell_get(*object_id),"
    , "        ConfidentialKernelSlotExpr::ArrayGet { object_id, index } => {"
    , "            let index = eval_confidential_kernel_slot_expr_generated(runtime, index, state)?"
    , "                .as_uint()"
    , "                .ok_or_else(|| anyhow!(\"array index must be uint\"))?;"
    , "            let index = index.to_usize_saturating();"
    , "            runtime.array_get(*object_id, index)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::MapGet { object_id, key } => {"
    , "            let key = eval_confidential_kernel_slot_expr_generated(runtime, key, state)?;"
    , "            let (value, overflowed) = runtime.map_get(*object_id, &key)?;"
    , "            note_abort_generated(state, overflowed);"
    , "            Ok(value)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::StructField { base, field } => {"
    , "            let base = eval_confidential_kernel_slot_expr_generated(runtime, base, state)?;"
    , "            eval_confidential_kernel_struct_field_generated(base, field)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::ArrayIndex { base, index } => {"
    , "            let base = eval_confidential_kernel_slot_expr_generated(runtime, base, state)?;"
    , "            let index = eval_confidential_kernel_slot_expr_generated(runtime, index, state)?;"
    , "            eval_confidential_kernel_array_index_generated(base, index)"
    , "        }"
    , "        ConfidentialKernelSlotExpr::Keccak256 { parts } => {"
    , "            let values = collect_confidential_hash_parts("
    , "                parts.len(),"
    , "                parts"
    , "                    .iter()"
    , "                    .map(|part| eval_confidential_kernel_slot_expr_generated(runtime, part, state)),"
    , "            )?;"
    , "            runtime.keccak256(values)"
    , "        }"
    , "    }"
    , "}"
    , ""
    , "pub(super) fn eval_confidential_kernel_slot_pure_expr_generated<"
    , "    R: ConfidentialKernelSlotRuntime,"
    , ">("
    , "    runtime: &mut R,"
    , "    expr: &ConfidentialKernelSlotPureExpr,"
    , ") -> Result<Value> {"
    , "    match expr {"
    , "        ConfidentialKernelSlotPureExpr::Literal { value } => Ok(value.clone()),"
    , "        ConfidentialKernelSlotPureExpr::Slot { slot } => runtime.load_slot(*slot),"
    , "        ConfidentialKernelSlotPureExpr::Unary { op, expr } => {"
    , "            let value = eval_confidential_kernel_slot_pure_expr_generated(runtime, expr)?;"
    , "            eval_confidential_kernel_unary_generated(op, value)"
    , "        }"
    , "        ConfidentialKernelSlotPureExpr::Binary { op, lhs, rhs } => {"
    , "            let lhs = eval_confidential_kernel_slot_pure_expr_generated(runtime, lhs)?;"
    , "            let rhs = eval_confidential_kernel_slot_pure_expr_generated(runtime, rhs)?;"
    , "            eval_confidential_kernel_binary_generated(op, lhs, rhs)"
    , "        }"
    , "        ConfidentialKernelSlotPureExpr::Select {"
    , "            cond,"
    , "            when_true,"
    , "            when_false,"
    , "        } => {"
    , "            let cond = eval_confidential_kernel_slot_pure_expr_generated(runtime, cond)?"
    , "                .as_bool()"
    , "                .ok_or_else(|| anyhow!(\"select condition must be boolean\"))?;"
    , "            let when_true = eval_confidential_kernel_slot_pure_expr_generated(runtime, when_true)?;"
    , "            let when_false ="
    , "                eval_confidential_kernel_slot_pure_expr_generated(runtime, when_false)?;"
    , "            Value::confidential_select(cond, when_true, when_false)"
    , "        }"
    , "        ConfidentialKernelSlotPureExpr::StructField { base, field } => {"
    , "            let base = eval_confidential_kernel_slot_pure_expr_generated(runtime, base)?;"
    , "            eval_confidential_kernel_struct_field_generated(base, field)"
    , "        }"
    , "        ConfidentialKernelSlotPureExpr::ArrayIndex { base, index } => {"
    , "            let base = eval_confidential_kernel_slot_pure_expr_generated(runtime, base)?;"
    , "            let index = eval_confidential_kernel_slot_pure_expr_generated(runtime, index)?;"
    , "            eval_confidential_kernel_array_index_generated(base, index)"
    , "        }"
    , "        ConfidentialKernelSlotPureExpr::Keccak256 { parts } => {"
    , "            let values = collect_confidential_hash_parts("
    , "                parts.len(),"
    , "                parts"
    , "                    .iter()"
    , "                    .map(|part| eval_confidential_kernel_slot_pure_expr_generated(runtime, part)),"
    , "            )?;"
    , "            runtime.keccak256(values)"
    , "        }"
    , "    }"
    , "}"
    ] ++ "\n"

def generatedRust : String :=
  String.intercalate "\n"
    [ "// @generated by proof/lean/GenerateConfidentialKernelRust.lean; do not edit by hand."
    , "// Re-run `lake build generateConfidentialKernelRust` and then `.lake/build/bin/generateConfidentialKernelRust` from proof/lean."
    , ""
    , "use super::{"
    , "    collect_confidential_hash_parts, ConfidentialKernelExecutionOutcome,"
    , "    ConfidentialKernelExprKind, ConfidentialKernelExprProfile, ConfidentialKernelInterpreterState,"
    , "    ConfidentialKernelPureExprKind, ConfidentialKernelPureExprProfile, ConfidentialKernelSlotExpr,"
    , "    ConfidentialKernelSlotExprKind, ConfidentialKernelSlotExprProfile,"
    , "    ConfidentialKernelSlotProgram, ConfidentialKernelSlotPureExpr,"
    , "    ConfidentialKernelSlotPureExprKind, ConfidentialKernelSlotPureExprProfile,"
    , "    ConfidentialKernelSlotRuntime, ConfidentialKernelSlotStatement,"
    , "    ConfidentialKernelStatementEffectKind, ConfidentialKernelStatementKind,"
    , "    ConfidentialKernelStatementProfile,"
    , "};"
    , "use crate::ir::{BinaryOp, UnaryOp};"
    , "use crate::types::{masked_select_bool, Uint256, Value};"
    , "use anyhow::{anyhow, bail, Result};"
    , "use uo_precompiles::UoOpcode;"
    , ""
    , renderStatementProfiles
    , renderSlotExprProfiles
    , renderSlotPureExprProfiles
    , renderNamedExprProfiles
    , renderNamedPureExprProfiles
    , generatedInterpreter
    ]

end GenerateConfidentialKernelRust
