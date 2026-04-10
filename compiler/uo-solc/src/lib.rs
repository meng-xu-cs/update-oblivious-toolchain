use anyhow::{anyhow, bail, Context, Result};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use uo_core::ir::{
    BackendKind, BinaryOp, CompiledContract, CompiledFunction, ContainerKind, Expr, ProgramMode,
    StateObject, Statement, UnaryOp,
};
use uo_core::manifest::{EntrypointManifest, RuntimeManifest, StateObjectManifest};
use uo_core::{
    CompiledArtifact, ContractMetadata, ScalarType, StateMetadata, StructField, Type, Value,
};

use solang_parser::{diagnostics::Diagnostic, pt, parse};

#[derive(Clone, Debug)]
pub struct ValidationOutput {
    pub contract_name: String,
    pub entrypoints: Vec<String>,
    pub diagnostics: Vec<String>,
}

#[derive(Clone, Debug)]
struct Frontend {
    source_file: String,
    contract_name: String,
    structs: BTreeMap<String, Type>,
    state_by_name: BTreeMap<String, StateObject>,
    entrypoint_metadata: BTreeMap<String, uo_core::EntrypointMetadata>,
    functions: Vec<pt::FunctionDefinition>,
    helpers: BTreeMap<String, HelperFunction>,
    diagnostics: Vec<String>,
}

#[derive(Clone, Debug)]
struct HelperFunction {
    params: Vec<String>,
    body: pt::Expression,
}

#[derive(Clone, Debug)]
struct LowerCtx<'a> {
    frontend: &'a Frontend,
    locals: BTreeMap<String, Type>,
    loop_counter: usize,
}

pub fn validate_source(source_path: &str, metadata: &ContractMetadata) -> Result<ValidationOutput> {
    let source = fs::read_to_string(source_path)
        .with_context(|| format!("failed to read Solidity source {}", source_path))?;
    let frontend = parse_frontend(source_path, &source, metadata)?;
    for function in &frontend.functions {
        let signature = function_signature(function)
            .ok_or_else(|| anyhow!("function without name is unsupported"))?;
        let entry_meta = frontend
            .entrypoint_metadata
            .get(&signature)
            .cloned()
            .unwrap_or(uo_core::EntrypointMetadata {
                secret_args: Vec::new(),
                public_gas_budget: None,
                confidential: false,
            });
        let mut ctx = LowerCtx {
            frontend: &frontend,
            locals: BTreeMap::new(),
            loop_counter: 0,
        };
        let _ = lower_function(function, &entry_meta, ProgramMode::Raw, &mut ctx)?;
    }
    Ok(ValidationOutput {
        contract_name: frontend.contract_name,
        entrypoints: frontend
            .functions
            .iter()
            .filter_map(function_signature)
            .collect(),
        diagnostics: frontend.diagnostics,
    })
}

pub fn compile(
    source_path: &str,
    metadata: &ContractMetadata,
    mode: ProgramMode,
) -> Result<CompiledArtifact> {
    let source = fs::read_to_string(source_path)
        .with_context(|| format!("failed to read Solidity source {}", source_path))?;
    let frontend = parse_frontend(source_path, &source, metadata)?;
    let mut functions = Vec::new();
    let mut manifest_entrypoints = BTreeMap::new();
    for function in &frontend.functions {
        let signature = function_signature(function)
            .ok_or_else(|| anyhow!("function without name is unsupported"))?;
        let entry_meta = frontend
            .entrypoint_metadata
            .get(&signature)
            .cloned()
            .unwrap_or(uo_core::EntrypointMetadata {
                secret_args: Vec::new(),
                public_gas_budget: None,
                confidential: false,
            });
        let mut ctx = LowerCtx {
            frontend: &frontend,
            locals: BTreeMap::new(),
            loop_counter: 0,
        };
        let compiled = lower_function(function, &entry_meta, mode.clone(), &mut ctx)?;
        manifest_entrypoints.insert(signature.clone(), build_manifest_entry(&compiled, &frontend, &entry_meta)?);
        functions.push(compiled);
    }
    let manifest = RuntimeManifest {
        contract: frontend.contract_name.clone(),
        compilation_mode: match mode {
            ProgramMode::Raw => "raw".into(),
            ProgramMode::Uo => "uo".into(),
        },
        objects: frontend
            .state_by_name
            .values()
            .map(|object| StateObjectManifest {
                id: object.id,
                name: object.name.clone(),
                kind: match object.kind {
                    ContainerKind::Cell => "cell".into(),
                    ContainerKind::Array => "array".into(),
                    ContainerKind::Map => "map".into(),
                },
                backend: match object.backend {
                    BackendKind::Raw => "raw".into(),
                    BackendKind::FullScan => "full_scan".into(),
                    BackendKind::Oram => "oram".into(),
                },
                capacity: object.capacity,
                value_type: Some(object.value_type.short_name()),
                key_type: object.key_type.as_ref().map(Type::short_name),
            })
            .collect(),
        entrypoints: manifest_entrypoints,
    };
    let contract = CompiledContract {
        contract: frontend.contract_name.clone(),
        mode: mode.clone(),
        source_file: frontend.source_file.clone(),
        state: frontend.state_by_name.values().cloned().collect(),
        functions: functions.clone(),
        manifest,
    };
    let disassembly = disassemble_contract(&contract);
    Ok(CompiledArtifact {
        compiler_version: env!("CARGO_PKG_VERSION").into(),
        contract,
        diagnostics: frontend.diagnostics,
        transformed_source: Some(render_contract(&functions)),
        disassembly,
    })
}

fn parse_frontend(source_path: &str, source: &str, metadata: &ContractMetadata) -> Result<Frontend> {
    let (unit, _) = parse(source, 0).map_err(render_parse_errors)?;
    let contract = unit
        .0
        .iter()
        .find_map(|part| match part {
            pt::SourceUnitPart::ContractDefinition(contract) => {
                let name = contract.name.as_ref()?.name.clone();
                if name == metadata.contract {
                    Some(contract.as_ref().clone())
                } else {
                    None
                }
            }
            _ => None,
        })
        .ok_or_else(|| anyhow!("contract {} not found", metadata.contract))?;
    if !contract.base.is_empty() {
        bail!("inheritance is unsupported");
    }
    let mut structs = BTreeMap::new();
    let mut state_by_name = BTreeMap::new();
    let mut functions = Vec::new();
    let mut helpers = BTreeMap::new();
    let mut diagnostics = Vec::new();
    for part in &contract.parts {
        match part {
            pt::ContractPart::StructDefinition(def) => {
                let name = def
                    .name
                    .as_ref()
                    .ok_or_else(|| anyhow!("anonymous struct is unsupported"))?
                    .name
                    .clone();
                let fields = def
                    .fields
                    .iter()
                    .map(|field| {
                        Ok(StructField {
                            name: field
                                .name
                                .as_ref()
                                .ok_or_else(|| anyhow!("struct field without name"))?
                                .name
                                .clone(),
                            ty: lower_type_expr(&field.ty, &structs)?,
                        })
                    })
                    .collect::<Result<Vec<_>>>()?;
                structs.insert(name, Type::Struct(fields));
            }
            pt::ContractPart::VariableDefinition(def) => {
                let name = def
                    .name
                    .as_ref()
                    .ok_or_else(|| anyhow!("state variable without name"))?
                    .name
                    .clone();
                let state_meta = metadata
                    .state
                    .get(&name)
                    .ok_or_else(|| anyhow!("state variable {} is missing metadata", name))?;
                let id = (state_by_name.len() + 1) as u32;
                state_by_name.insert(name.clone(), lower_state_object(id, &name, def, state_meta, &structs)?);
            }
            pt::ContractPart::FunctionDefinition(def) => {
                reject_function_shape(def)?;
                if is_helper_function(def) {
                    let helper = lower_helper_function(def, &structs)?;
                    let name = def.name.as_ref().unwrap().name.clone();
                    helpers.insert(name, helper);
                } else {
                    functions.push(def.as_ref().clone());
                }
            }
            pt::ContractPart::EventDefinition(_) => bail!("events are unsupported"),
            pt::ContractPart::ErrorDefinition(_) => bail!("custom errors are unsupported"),
            pt::ContractPart::EnumDefinition(_) => bail!("enums are unsupported"),
            pt::ContractPart::TypeDefinition(_) => bail!("user-defined type aliases are unsupported"),
            pt::ContractPart::Using(_) => bail!("using directives are unsupported"),
            pt::ContractPart::Annotation(_) => bail!("annotations in Solidity source are unsupported"),
            pt::ContractPart::StraySemicolon(_) => {}
        }
    }
    for key in metadata.state.keys() {
        if !state_by_name.contains_key(key) {
            bail!("metadata references unknown state object {}", key);
        }
    }
    let mut entrypoint_metadata = BTreeMap::new();
    for function in &functions {
        let signature = function_signature(function)
            .ok_or_else(|| anyhow!("function without name is unsupported"))?;
        if let Some(entry_meta) = metadata.entrypoints.get(&signature) {
            entrypoint_metadata.insert(signature.clone(), entry_meta.clone());
            ensure_secret_args_exist(function, entry_meta)?;
        } else {
            diagnostics.push(format!(
                "no explicit metadata for {}, treating it as public entrypoint",
                signature
            ));
        }
    }
    Ok(Frontend {
        source_file: source_path.into(),
        contract_name: metadata.contract.clone(),
        structs,
        state_by_name,
        entrypoint_metadata,
        functions,
        helpers,
        diagnostics,
    })
}

fn lower_function(
    function: &pt::FunctionDefinition,
    entry_meta: &uo_core::EntrypointMetadata,
    mode: ProgramMode,
    ctx: &mut LowerCtx<'_>,
) -> Result<CompiledFunction> {
    let signature = function_signature(function)
        .ok_or_else(|| anyhow!("function without name is unsupported"))?;
    let params = lower_params(&function.params, &ctx.frontend.structs)?;
    for (name, ty) in &params {
        ctx.locals.insert(name.clone(), ty.clone());
    }
    let return_type = lower_returns(&function.returns, &ctx.frontend.structs)?;
    let body = function
        .body
        .as_ref()
        .ok_or_else(|| anyhow!("function {} has no body", signature))?;
    let mut lowered = lower_block(body, ctx)?;
    let confidential = matches!(mode, ProgramMode::Uo)
        && (entry_meta.confidential || !entry_meta.secret_args.is_empty());
    if confidential {
        ensure_confidential_return_shape(&lowered, &signature)?;
        lowered = linearize_statements(&lowered, &Expr::Literal(Value::Bool(true)))?;
    }
    let secret_args = entry_meta
        .secret_args
        .iter()
        .map(|name| {
            params
                .iter()
                .position(|(param, _)| param == name)
                .ok_or_else(|| anyhow!("secret arg {} not found in {}", name, signature))
        })
        .collect::<Result<Vec<_>>>()?;
    Ok(CompiledFunction {
        signature,
        params,
        return_type,
        body: lowered,
        secret_args,
        confidential,
    })
}

fn lower_block(statement: &pt::Statement, ctx: &mut LowerCtx<'_>) -> Result<Vec<Statement>> {
    match statement {
        pt::Statement::Block { statements, .. } => {
            let mut out = Vec::new();
            for statement in statements {
                out.extend(lower_statement(statement, ctx)?);
            }
            Ok(out)
        }
        other => lower_statement(other, ctx),
    }
}

fn lower_statement(statement: &pt::Statement, ctx: &mut LowerCtx<'_>) -> Result<Vec<Statement>> {
    match statement {
        pt::Statement::Block { .. } => lower_block(statement, ctx),
        pt::Statement::VariableDefinition(_, decl, init) => {
            let name = decl
                .name
                .as_ref()
                .ok_or_else(|| anyhow!("local variable without name"))?
                .name
                .clone();
            let ty = lower_type_expr(&decl.ty, &ctx.frontend.structs)?;
            let value = if let Some(init) = init {
                lower_expr(init, ctx, &BTreeMap::new())?
            } else {
                Expr::Literal(Value::zero_for_type(&ty))
            };
            ctx.locals.insert(name.clone(), ty.clone());
            Ok(vec![Statement::Declare { name, ty, value }])
        }
        pt::Statement::Expression(_, expression) => lower_expression_statement(expression, ctx),
        pt::Statement::If(_, cond, then_stmt, else_stmt) => Ok(vec![Statement::If {
            cond: lower_expr(cond, ctx, &BTreeMap::new())?,
            then_body: lower_block(then_stmt, ctx)?,
            else_body: else_stmt
                .as_ref()
                .map(|stmt| lower_block(stmt, ctx))
                .transpose()?
                .unwrap_or_default(),
        }]),
        pt::Statement::For(_, init, cond, next, body) => {
            let init = init
                .as_ref()
                .ok_or_else(|| anyhow!("for loop initializer is required"))?;
            let (index_var, start) = lower_for_initializer(init, ctx)?;
            let cond = cond
                .as_ref()
                .ok_or_else(|| anyhow!("for loop bound is required"))?;
            let end = lower_for_bound(cond, &index_var, ctx)?;
            lower_for_increment(
                next.as_ref()
                    .ok_or_else(|| anyhow!("for loop increment is required"))?,
                &index_var,
            )?;
            let loop_id = format!("loop_{}", ctx.loop_counter);
            ctx.loop_counter += 1;
            let body = body
                .as_ref()
                .ok_or_else(|| anyhow!("for loop body is required"))?;
            Ok(vec![Statement::For {
                loop_id,
                index_var,
                start,
                end,
                body: lower_block(body, ctx)?,
            }])
        }
        pt::Statement::Return(_, value) => Ok(vec![Statement::Return {
            value: value
                .as_ref()
                .map(|expr| lower_expr(expr, ctx, &BTreeMap::new()))
                .transpose()?,
        }]),
        pt::Statement::While(_, _, _) | pt::Statement::DoWhile(_, _, _) => {
            bail!("while/do-while loops are unsupported")
        }
        pt::Statement::Break(_) | pt::Statement::Continue(_) => {
            bail!("break/continue are unsupported")
        }
        pt::Statement::Revert(_, _, _) | pt::Statement::RevertNamedArgs(_, _, _) => {
            bail!("revert is unsupported")
        }
        pt::Statement::Emit(_, _) => bail!("emit is unsupported"),
        pt::Statement::Try(_, _, _, _) => bail!("try/catch is unsupported"),
        pt::Statement::Assembly { .. } => bail!("inline assembly is unsupported"),
        pt::Statement::Args(_, _) | pt::Statement::Error(_) => {
            bail!("unsupported Solidity statement encountered")
        }
    }
}

fn lower_expression_statement(
    expression: &pt::Expression,
    ctx: &mut LowerCtx<'_>,
) -> Result<Vec<Statement>> {
    if let pt::Expression::FunctionCall(_, callee, args) = expression {
        if let pt::Expression::Variable(identifier) = callee.as_ref() {
            if identifier.name == "require" {
                if args.len() != 1 {
                    bail!("require must have a single argument");
                }
                return Ok(vec![Statement::Require {
                    cond: lower_expr(&args[0], ctx, &BTreeMap::new())?,
                }]);
            }
        }
    }
    lower_assignment(expression, ctx).map(|statement| vec![statement])
}

fn lower_assignment(expression: &pt::Expression, ctx: &mut LowerCtx<'_>) -> Result<Statement> {
    let (left, rhs, op) = match expression {
        pt::Expression::Assign(_, left, right) => (left.as_ref(), right.as_ref(), None),
        pt::Expression::AssignAdd(_, left, right) => (left.as_ref(), right.as_ref(), Some(BinaryOp::Add)),
        pt::Expression::AssignSubtract(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::Sub))
        }
        pt::Expression::AssignAnd(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::BitAnd))
        }
        pt::Expression::AssignOr(_, left, right) => (left.as_ref(), right.as_ref(), Some(BinaryOp::BitOr)),
        pt::Expression::AssignXor(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::BitXor))
        }
        _ => bail!("only assignments may appear as standalone expressions"),
    };
    let lvalue = lower_lvalue(left, ctx, &BTreeMap::new())?;
    let rhs = if let Some(op) = op {
        Expr::Binary {
            op,
            lhs: Box::new(lvalue.read_expr()),
            rhs: Box::new(lower_expr(rhs, ctx, &BTreeMap::new())?),
        }
    } else {
        lower_expr(rhs, ctx, &BTreeMap::new())?
    };
    Ok(lvalue.write_statement(rhs))
}

fn lower_expr(
    expression: &pt::Expression,
    ctx: &mut LowerCtx<'_>,
    subst: &BTreeMap<String, Expr>,
) -> Result<Expr> {
    if let pt::Expression::Variable(identifier) = expression {
        if let Some(expr) = subst.get(&identifier.name) {
            return Ok(expr.clone());
        }
        if ctx.locals.contains_key(&identifier.name) {
            return Ok(Expr::Var(identifier.name.clone()));
        }
        if let Some(state) = ctx.frontend.state_by_name.get(&identifier.name) {
            return match state.kind {
                ContainerKind::Cell => Ok(Expr::CellGet { object_id: state.id }),
                _ => bail!("state object {} must be accessed through index/key", identifier.name),
            };
        }
        bail!("unknown identifier {}", identifier.name);
    }
    match expression {
        pt::Expression::Parenthesis(_, expr) => lower_expr(expr, ctx, subst),
        pt::Expression::Variable(_) => unreachable!("handled before the main expression match"),
        pt::Expression::BoolLiteral(_, value) => Ok(Expr::Literal(Value::Bool(*value))),
        pt::Expression::NumberLiteral(_, integer, fraction, _) => {
            if !fraction.is_empty() {
                bail!("fractional literals are unsupported");
            }
            Ok(Expr::Literal(Value::Uint(integer.parse::<u128>()?)))
        }
        pt::Expression::HexNumberLiteral(_, value, _) => Ok(Expr::Literal(Value::Uint(
            u128::from_str_radix(value.trim_start_matches("0x"), 16)?,
        ))),
        pt::Expression::AddressLiteral(_, value) => {
            let mut bytes = [0u8; 20];
            hex::decode_to_slice(value.trim_start_matches("0x"), &mut bytes)?;
            Ok(Expr::Literal(Value::Address(bytes)))
        }
        pt::Expression::UnaryPlus(_, expr) => lower_expr(expr, ctx, subst),
        pt::Expression::Negate(_, expr) => Ok(Expr::Unary {
            op: UnaryOp::Neg,
            expr: Box::new(lower_expr(expr, ctx, subst)?),
        }),
        pt::Expression::Not(_, expr) => Ok(Expr::Unary {
            op: UnaryOp::Not,
            expr: Box::new(lower_expr(expr, ctx, subst)?),
        }),
        pt::Expression::BitwiseAnd(_, lhs, rhs) => lower_binary(BinaryOp::BitAnd, lhs, rhs, ctx, subst),
        pt::Expression::BitwiseOr(_, lhs, rhs) => lower_binary(BinaryOp::BitOr, lhs, rhs, ctx, subst),
        pt::Expression::BitwiseXor(_, lhs, rhs) => lower_binary(BinaryOp::BitXor, lhs, rhs, ctx, subst),
        pt::Expression::Add(_, lhs, rhs) => lower_binary(BinaryOp::Add, lhs, rhs, ctx, subst),
        pt::Expression::Subtract(_, lhs, rhs) => lower_binary(BinaryOp::Sub, lhs, rhs, ctx, subst),
        pt::Expression::Multiply(_, lhs, rhs) => lower_binary(BinaryOp::Mul, lhs, rhs, ctx, subst),
        pt::Expression::Divide(_, lhs, rhs) => lower_binary(BinaryOp::Div, lhs, rhs, ctx, subst),
        pt::Expression::Modulo(_, lhs, rhs) => lower_binary(BinaryOp::Mod, lhs, rhs, ctx, subst),
        pt::Expression::Equal(_, lhs, rhs) => lower_binary(BinaryOp::Eq, lhs, rhs, ctx, subst),
        pt::Expression::NotEqual(_, lhs, rhs) => lower_binary(BinaryOp::Neq, lhs, rhs, ctx, subst),
        pt::Expression::Less(_, lhs, rhs) => lower_binary(BinaryOp::Lt, lhs, rhs, ctx, subst),
        pt::Expression::LessEqual(_, lhs, rhs) => lower_binary(BinaryOp::Lte, lhs, rhs, ctx, subst),
        pt::Expression::More(_, lhs, rhs) => lower_binary(BinaryOp::Gt, lhs, rhs, ctx, subst),
        pt::Expression::MoreEqual(_, lhs, rhs) => lower_binary(BinaryOp::Gte, lhs, rhs, ctx, subst),
        pt::Expression::And(_, lhs, rhs) => lower_binary(BinaryOp::And, lhs, rhs, ctx, subst),
        pt::Expression::Or(_, lhs, rhs) => lower_binary(BinaryOp::Or, lhs, rhs, ctx, subst),
        pt::Expression::ConditionalOperator(_, cond, when_true, when_false) => Ok(Expr::Select {
            cond: Box::new(lower_expr(cond, ctx, subst)?),
            when_true: Box::new(lower_expr(when_true, ctx, subst)?),
            when_false: Box::new(lower_expr(when_false, ctx, subst)?),
        }),
        pt::Expression::ArraySubscript(_, base, Some(index)) => {
            if let pt::Expression::Variable(identifier) = base.as_ref() {
                if let Some(state) = ctx.frontend.state_by_name.get(&identifier.name) {
                    let index_expr = lower_expr(index, ctx, subst)?;
                    return match state.kind {
                        ContainerKind::Array => Ok(Expr::ArrayGet {
                            object_id: state.id,
                            index: Box::new(index_expr),
                        }),
                        ContainerKind::Map => Ok(Expr::MapGet {
                            object_id: state.id,
                            key: Box::new(index_expr),
                        }),
                        ContainerKind::Cell => bail!("cell {} cannot be indexed", identifier.name),
                    };
                }
            }
            Ok(Expr::ArrayIndex {
                base: Box::new(lower_expr(base, ctx, subst)?),
                index: Box::new(lower_expr(index, ctx, subst)?),
            })
        }
        pt::Expression::MemberAccess(_, base, member) => {
            if member.name == "length" {
                if let pt::Expression::Variable(identifier) = base.as_ref() {
                    if let Some(state) = ctx.frontend.state_by_name.get(&identifier.name) {
                        let len = state
                            .capacity
                            .ok_or_else(|| anyhow!("{} has no static length", identifier.name))?;
                        return Ok(Expr::Literal(Value::Uint(len as u128)));
                    }
                    if let Some(Type::Array(_, len)) = ctx.locals.get(&identifier.name) {
                        return Ok(Expr::Literal(Value::Uint(*len as u128)));
                    }
                }
            }
            Ok(Expr::StructField {
                base: Box::new(lower_expr(base, ctx, subst)?),
                field: member.name.clone(),
            })
        }
        pt::Expression::FunctionCall(_, callee, args) => {
            if let Some(expr) = maybe_lower_keccak(callee, args, ctx, subst)? {
                return Ok(expr);
            }
            if let pt::Expression::Variable(identifier) = callee.as_ref() {
                if let Some(helper) = ctx.frontend.helpers.get(&identifier.name) {
                    if helper.params.len() != args.len() {
                        bail!("helper {} called with wrong arity", identifier.name);
                    }
                    let mut nested_subst = subst.clone();
                    for (param, arg) in helper.params.iter().zip(args.iter()) {
                        nested_subst.insert(param.clone(), lower_expr(arg, ctx, subst)?);
                    }
                    return lower_expr(&helper.body, ctx, &nested_subst);
                }
            }
            bail!("unsupported function call in expression")
        }
        pt::Expression::StringLiteral(_) => bail!("string literals are unsupported"),
        pt::Expression::HexLiteral(_) => bail!("hex byte literals are unsupported"),
        pt::Expression::Type(_, _) => bail!("type expression used as value is unsupported"),
        pt::Expression::Delete(_, _)
        | pt::Expression::PostIncrement(_, _)
        | pt::Expression::PostDecrement(_, _)
        | pt::Expression::PreIncrement(_, _)
        | pt::Expression::PreDecrement(_, _)
        | pt::Expression::Assign(_, _, _)
        | pt::Expression::AssignOr(_, _, _)
        | pt::Expression::AssignAnd(_, _, _)
        | pt::Expression::AssignXor(_, _, _)
        | pt::Expression::AssignShiftLeft(_, _, _)
        | pt::Expression::AssignShiftRight(_, _, _)
        | pt::Expression::AssignAdd(_, _, _)
        | pt::Expression::AssignSubtract(_, _, _)
        | pt::Expression::AssignMultiply(_, _, _)
        | pt::Expression::AssignDivide(_, _, _)
        | pt::Expression::AssignModulo(_, _, _)
        | pt::Expression::ShiftLeft(_, _, _)
        | pt::Expression::ShiftRight(_, _, _)
        | pt::Expression::Power(_, _, _)
        | pt::Expression::BitwiseNot(_, _)
        | pt::Expression::ArraySubscript(_, _, None)
        | pt::Expression::ArraySlice(_, _, _, _)
        | pt::Expression::FunctionCallBlock(_, _, _)
        | pt::Expression::NamedFunctionCall(_, _, _)
        | pt::Expression::RationalNumberLiteral(_, _, _, _, _)
        | pt::Expression::List(_, _)
        | pt::Expression::ArrayLiteral(_, _)
        | pt::Expression::New(_, _) => bail!("unsupported Solidity expression"),
    }
}

fn maybe_lower_keccak(
    callee: &pt::Expression,
    args: &[pt::Expression],
    ctx: &mut LowerCtx<'_>,
    subst: &BTreeMap<String, Expr>,
) -> Result<Option<Expr>> {
    if let pt::Expression::Variable(identifier) = callee {
        if identifier.name == "keccak256" && args.len() == 1 {
            if let pt::Expression::FunctionCall(_, inner_callee, inner_args) = &args[0] {
                if let pt::Expression::MemberAccess(_, base, member) = inner_callee.as_ref() {
                    if matches!(base.as_ref(), pt::Expression::Variable(ident) if ident.name == "abi")
                        && member.name == "encodePacked"
                    {
                        return Ok(Some(Expr::Keccak256 {
                            parts: inner_args
                                .iter()
                                .map(|expr| lower_expr(expr, ctx, subst))
                                .collect::<Result<Vec<_>>>()?,
                        }));
                    }
                }
            }
        }
    }
    Ok(None)
}

fn lower_binary(
    op: BinaryOp,
    lhs: &pt::Expression,
    rhs: &pt::Expression,
    ctx: &mut LowerCtx<'_>,
    subst: &BTreeMap<String, Expr>,
) -> Result<Expr> {
    Ok(Expr::Binary {
        op,
        lhs: Box::new(lower_expr(lhs, ctx, subst)?),
        rhs: Box::new(lower_expr(rhs, ctx, subst)?),
    })
}

#[derive(Clone, Debug)]
enum LValue {
    Local(String),
    Cell(u32),
    Array(u32, Expr),
    Map(u32, Expr),
}

impl LValue {
    fn read_expr(&self) -> Expr {
        match self {
            LValue::Local(name) => Expr::Var(name.clone()),
            LValue::Cell(id) => Expr::CellGet { object_id: *id },
            LValue::Array(id, index) => Expr::ArrayGet {
                object_id: *id,
                index: Box::new(index.clone()),
            },
            LValue::Map(id, key) => Expr::MapGet {
                object_id: *id,
                key: Box::new(key.clone()),
            },
        }
    }

    fn write_statement(&self, value: Expr) -> Statement {
        match self {
            LValue::Local(name) => Statement::Assign {
                name: name.clone(),
                value,
            },
            LValue::Cell(id) => Statement::CellSet {
                object_id: *id,
                value,
                predicate: None,
            },
            LValue::Array(id, index) => Statement::ArraySet {
                object_id: *id,
                index: index.clone(),
                value,
                predicate: None,
            },
            LValue::Map(id, key) => Statement::MapPut {
                object_id: *id,
                key: key.clone(),
                value,
                predicate: None,
            },
        }
    }
}

fn lower_lvalue(
    expression: &pt::Expression,
    ctx: &mut LowerCtx<'_>,
    subst: &BTreeMap<String, Expr>,
) -> Result<LValue> {
    match expression {
        pt::Expression::Variable(identifier) => {
            if ctx.locals.contains_key(&identifier.name) {
                Ok(LValue::Local(identifier.name.clone()))
            } else if let Some(state) = ctx.frontend.state_by_name.get(&identifier.name) {
                match state.kind {
                    ContainerKind::Cell => Ok(LValue::Cell(state.id)),
                    _ => bail!("{} requires an index/key on assignment", identifier.name),
                }
            } else {
                bail!("unknown assignment target {}", identifier.name)
            }
        }
        pt::Expression::ArraySubscript(_, base, Some(index)) => {
            if let pt::Expression::Variable(identifier) = base.as_ref() {
                if let Some(state) = ctx.frontend.state_by_name.get(&identifier.name) {
                    return match state.kind {
                        ContainerKind::Array => Ok(LValue::Array(
                            state.id,
                            lower_expr(index, ctx, subst)?,
                        )),
                        ContainerKind::Map => {
                            Ok(LValue::Map(state.id, lower_expr(index, ctx, subst)?))
                        }
                        ContainerKind::Cell => bail!("{} cannot be indexed", identifier.name),
                    };
                }
            }
            bail!("only state array/map indexing is supported as an lvalue")
        }
        _ => bail!("unsupported assignment target"),
    }
}

fn lower_for_initializer(
    statement: &pt::Statement,
    ctx: &mut LowerCtx<'_>,
) -> Result<(String, Expr)> {
    match statement {
        pt::Statement::VariableDefinition(_, decl, Some(init)) => {
            let name = decl
                .name
                .as_ref()
                .ok_or_else(|| anyhow!("for-loop index variable missing name"))?
                .name
                .clone();
            let ty = lower_type_expr(&decl.ty, &ctx.frontend.structs)?;
            ctx.locals.insert(name.clone(), ty);
            Ok((name, lower_expr(init, ctx, &BTreeMap::new())?))
        }
        pt::Statement::Expression(_, expr) => match expr {
            pt::Expression::Assign(_, left, right) => {
                let name = match left.as_ref() {
                    pt::Expression::Variable(identifier) => identifier.name.clone(),
                    _ => bail!("for-loop initializer must assign to an identifier"),
                };
                Ok((name, lower_expr(right, ctx, &BTreeMap::new())?))
            }
            _ => bail!("unsupported for-loop initializer"),
        },
        _ => bail!("unsupported for-loop initializer"),
    }
}

fn lower_for_bound(
    expression: &pt::Expression,
    index_var: &str,
    ctx: &mut LowerCtx<'_>,
) -> Result<Expr> {
    match expression {
        pt::Expression::Less(_, left, right) => match left.as_ref() {
            pt::Expression::Variable(identifier) if identifier.name == index_var => {
                lower_expr(right, ctx, &BTreeMap::new())
            }
            _ => bail!("for-loop bound must compare index variable on the left"),
        },
        _ => bail!("for-loop bound must use '<' with a public end expression"),
    }
}

fn lower_for_increment(expression: &pt::Expression, index_var: &str) -> Result<()> {
    match expression {
        pt::Expression::PostIncrement(_, expr)
        | pt::Expression::PreIncrement(_, expr) => match expr.as_ref() {
            pt::Expression::Variable(identifier) if identifier.name == index_var => Ok(()),
            _ => bail!("for-loop increment must update {}", index_var),
        },
        pt::Expression::AssignAdd(_, left, right) => match (left.as_ref(), right.as_ref()) {
            (pt::Expression::Variable(identifier), pt::Expression::NumberLiteral(_, integer, fraction, _))
                if identifier.name == index_var && integer == "1" && fraction.is_empty() =>
            {
                Ok(())
            }
            _ => bail!("for-loop increment must be {} += 1", index_var),
        },
        _ => bail!("unsupported for-loop increment"),
    }
}

fn lower_type_expr(expression: &pt::Expression, structs: &BTreeMap<String, Type>) -> Result<Type> {
    match expression {
        pt::Expression::Type(_, ty) => match ty {
            pt::Type::Bool => Ok(Type::Scalar(ScalarType::Bool)),
            pt::Type::Uint(bits) => Ok(Type::Scalar(ScalarType::Uint(*bits))),
            pt::Type::Bytes(32) => Ok(Type::Scalar(ScalarType::Bytes32)),
            pt::Type::Address | pt::Type::AddressPayable => Ok(Type::Scalar(ScalarType::Address)),
            pt::Type::Bytes(_) => bail!("only bytes32 is supported"),
            pt::Type::String | pt::Type::DynamicBytes => {
                bail!("dynamic string/bytes are unsupported")
            }
            pt::Type::Mapping { .. } => bail!("mapping types require explicit map lowering"),
            _ => bail!("unsupported Solidity type"),
        },
        pt::Expression::ArraySubscript(_, base, Some(size)) => {
            let element = lower_type_expr(base, structs)?;
            let len = const_usize(size)?;
            Ok(Type::Array(Box::new(element), len))
        }
        pt::Expression::Variable(identifier) => structs
            .get(&identifier.name)
            .cloned()
            .ok_or_else(|| anyhow!("unknown user-defined type {}", identifier.name)),
        _ => bail!("unsupported type expression"),
    }
}

fn lower_state_object(
    id: u32,
    name: &str,
    def: &pt::VariableDefinition,
    state_meta: &StateMetadata,
    structs: &BTreeMap<String, Type>,
) -> Result<StateObject> {
    let kind = match state_meta.kind.as_str() {
        "cell" => ContainerKind::Cell,
        "array" => ContainerKind::Array,
        "map" => ContainerKind::Map,
        other => bail!("unsupported state kind {}", other),
    };
    let backend = match state_meta.backend.as_str() {
        "raw" => BackendKind::Raw,
        "full_scan" => BackendKind::FullScan,
        "oram" => BackendKind::Oram,
        other => bail!("unsupported backend {}", other),
    };
    match kind {
        ContainerKind::Cell => Ok(StateObject {
            id,
            name: name.into(),
            kind,
            backend,
            value_type: lower_type_expr(&def.ty, structs)?,
            key_type: None,
            capacity: None,
            confidential: state_meta.confidential,
        }),
        ContainerKind::Array => {
            let (element_ty, capacity) = match &def.ty {
                pt::Expression::ArraySubscript(_, base, Some(size)) => {
                    (lower_type_expr(base, structs)?, const_usize(size)?)
                }
                _ => bail!("array state {} must have a fixed compile-time size", name),
            };
            Ok(StateObject {
                id,
                name: name.into(),
                kind,
                backend,
                value_type: element_ty,
                key_type: None,
                capacity: Some(state_meta.capacity.unwrap_or(capacity)),
                confidential: state_meta.confidential,
            })
        }
        ContainerKind::Map => {
            if backend == BackendKind::Raw && state_meta.capacity.is_none() {
                diagnostics_error("raw map still requires a public capacity in metadata")?;
            }
            match &def.ty {
                pt::Expression::Type(_, pt::Type::Mapping { key, value, .. }) => Ok(StateObject {
                    id,
                    name: name.into(),
                    kind,
                    backend,
                    value_type: lower_type_expr(value, structs)?,
                    key_type: Some(lower_type_expr(key, structs)?),
                    capacity: state_meta.capacity,
                    confidential: state_meta.confidential,
                }),
                _ => bail!("map state {} must use mapping syntax", name),
            }
        }
    }
}

fn lower_helper_function(
    function: &pt::FunctionDefinition,
    structs: &BTreeMap<String, Type>,
) -> Result<HelperFunction> {
    let params = lower_params(&function.params, structs)?
        .into_iter()
        .map(|(name, _)| name)
        .collect::<Vec<_>>();
    let _ = lower_returns(&function.returns, structs)?
        .ok_or_else(|| anyhow!("helper function must return a value"))?;
    let body = function
        .body
        .as_ref()
        .ok_or_else(|| anyhow!("helper function without body"))?;
    let return_expr = match body {
        pt::Statement::Block { statements, .. } if statements.len() == 1 => match &statements[0] {
            pt::Statement::Return(_, Some(expr)) => expr.clone(),
            _ => bail!("helper function must contain a single return statement"),
        },
        _ => bail!("helper function must contain a single return statement"),
    };
    Ok(HelperFunction {
        params,
        body: return_expr,
    })
}

fn lower_params(
    params: &pt::ParameterList,
    structs: &BTreeMap<String, Type>,
) -> Result<Vec<(String, Type)>> {
    params
        .iter()
        .map(|(_, param)| {
            let param = param
                .as_ref()
                .ok_or_else(|| anyhow!("malformed parameter"))?;
            Ok((
                param.name
                    .as_ref()
                    .ok_or_else(|| anyhow!("parameter without name"))?
                    .name
                    .clone(),
                lower_type_expr(&param.ty, structs)?,
            ))
        })
        .collect()
}

fn lower_returns(
    returns: &pt::ParameterList,
    structs: &BTreeMap<String, Type>,
) -> Result<Option<Type>> {
    if returns.is_empty() {
        return Ok(None);
    }
    if returns.len() != 1 {
        bail!("multiple return values are unsupported");
    }
    let (_, param) = &returns[0];
    let param = param
        .as_ref()
        .ok_or_else(|| anyhow!("malformed return parameter"))?;
    Ok(Some(lower_type_expr(&param.ty, structs)?))
}

fn build_manifest_entry(
    function: &CompiledFunction,
    frontend: &Frontend,
    entry_meta: &uo_core::EntrypointMetadata,
) -> Result<EntrypointManifest> {
    let counts = count_body(&function.body);
    let accessed_objects = accessed_objects(&function.body);
    let max_commit_ops = accessed_objects
        .iter()
        .map(|object_id| {
            let object = frontend
                .state_by_name
                .values()
                .find(|object| object.id == *object_id)
                .ok_or_else(|| anyhow!("unknown object id {} in manifest counting", object_id))?;
            Ok(match object.kind {
                ContainerKind::Cell => 1usize,
                ContainerKind::Array | ContainerKind::Map if object.backend == BackendKind::Oram => {
                    oram_batch_ops(object.capacity.unwrap_or(8))
                }
                ContainerKind::Array | ContainerKind::Map => object.capacity.unwrap_or(1),
            })
        })
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .sum::<usize>();
    let budget = entry_meta.public_gas_budget.unwrap_or(
        2000
            + counts.statement_count as u64 * 11
            + counts.expr_count as u64 * 7
            + max_commit_ops as u64 * 29,
    );
    Ok(EntrypointManifest {
        secret_args: function.secret_args.clone(),
        public_gas_budget: budget,
        arena_bytes: 4096 + counts.local_count * 64,
        max_stack_words: 64 + counts.local_count,
        uocell_reads: counts.cell_reads,
        uocell_writes: counts.cell_writes,
        uoarray_reads: counts.array_reads,
        uoarray_writes: counts.array_writes,
        uomap_reads: counts.map_reads,
        uomap_writes: counts.map_writes,
        max_commit_ops,
    })
}

#[derive(Default)]
struct CountSummary {
    statement_count: usize,
    expr_count: usize,
    local_count: usize,
    cell_reads: usize,
    cell_writes: usize,
    array_reads: usize,
    array_writes: usize,
    map_reads: usize,
    map_writes: usize,
}

fn count_body(statements: &[Statement]) -> CountSummary {
    let mut counts = CountSummary::default();
    for statement in statements {
        counts.statement_count += 1;
        match statement {
            Statement::Declare { value, .. } => {
                counts.local_count += 1;
                count_expr(value, &mut counts);
            }
            Statement::Assign { value, .. } => count_expr(value, &mut counts),
            Statement::Require { cond } | Statement::AbortIf { cond } => count_expr(cond, &mut counts),
            Statement::If {
                cond,
                then_body,
                else_body,
            } => {
                count_expr(cond, &mut counts);
                let then_counts = count_body(then_body);
                merge_counts(&mut counts, then_counts);
                let else_counts = count_body(else_body);
                merge_counts(&mut counts, else_counts);
            }
            Statement::For { start, end, body, .. } => {
                count_expr(start, &mut counts);
                count_expr(end, &mut counts);
                let body_counts = count_body(body);
                merge_counts(&mut counts, body_counts);
            }
            Statement::CellSet { value, predicate, .. } => {
                counts.cell_writes += 1;
                count_expr(value, &mut counts);
                if let Some(predicate) = predicate {
                    count_expr(predicate, &mut counts);
                }
            }
            Statement::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                counts.array_writes += 1;
                count_expr(index, &mut counts);
                count_expr(value, &mut counts);
                if let Some(predicate) = predicate {
                    count_expr(predicate, &mut counts);
                }
            }
            Statement::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                counts.map_writes += 1;
                count_expr(key, &mut counts);
                count_expr(value, &mut counts);
                if let Some(predicate) = predicate {
                    count_expr(predicate, &mut counts);
                }
            }
            Statement::Return { value } => {
                if let Some(value) = value {
                    count_expr(value, &mut counts);
                }
            }
        }
    }
    counts
}

fn count_expr(expr: &Expr, counts: &mut CountSummary) {
    counts.expr_count += 1;
    match expr {
        Expr::Unary { expr, .. } => count_expr(expr, counts),
        Expr::Binary { lhs, rhs, .. } => {
            count_expr(lhs, counts);
            count_expr(rhs, counts);
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            count_expr(cond, counts);
            count_expr(when_true, counts);
            count_expr(when_false, counts);
        }
        Expr::CellGet { .. } => counts.cell_reads += 1,
        Expr::ArrayGet { index, .. } => {
            counts.array_reads += 1;
            count_expr(index, counts);
        }
        Expr::MapGet { key, .. } => {
            counts.map_reads += 1;
            count_expr(key, counts);
        }
        Expr::StructField { base, .. } => count_expr(base, counts),
        Expr::ArrayIndex { base, index } => {
            count_expr(base, counts);
            count_expr(index, counts);
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                count_expr(part, counts);
            }
        }
        Expr::Literal(_) | Expr::Var(_) => {}
    }
}

fn merge_counts(target: &mut CountSummary, extra: CountSummary) {
    target.statement_count += extra.statement_count;
    target.expr_count += extra.expr_count;
    target.local_count += extra.local_count;
    target.cell_reads += extra.cell_reads;
    target.cell_writes += extra.cell_writes;
    target.array_reads += extra.array_reads;
    target.array_writes += extra.array_writes;
    target.map_reads += extra.map_reads;
    target.map_writes += extra.map_writes;
}

fn accessed_objects(statements: &[Statement]) -> BTreeSet<u32> {
    let mut ids = BTreeSet::new();
    for statement in statements {
        collect_statement_objects(statement, &mut ids);
    }
    ids
}

fn collect_statement_objects(statement: &Statement, ids: &mut BTreeSet<u32>) {
    match statement {
        Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
            collect_expr_objects(value, ids);
        }
        Statement::Require { cond } | Statement::AbortIf { cond } => collect_expr_objects(cond, ids),
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            collect_expr_objects(cond, ids);
            for stmt in then_body {
                collect_statement_objects(stmt, ids);
            }
            for stmt in else_body {
                collect_statement_objects(stmt, ids);
            }
        }
        Statement::For { start, end, body, .. } => {
            collect_expr_objects(start, ids);
            collect_expr_objects(end, ids);
            for stmt in body {
                collect_statement_objects(stmt, ids);
            }
        }
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => {
            ids.insert(*object_id);
            collect_expr_objects(value, ids);
            if let Some(predicate) = predicate {
                collect_expr_objects(predicate, ids);
            }
        }
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => {
            ids.insert(*object_id);
            collect_expr_objects(index, ids);
            collect_expr_objects(value, ids);
            if let Some(predicate) = predicate {
                collect_expr_objects(predicate, ids);
            }
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            ids.insert(*object_id);
            collect_expr_objects(key, ids);
            collect_expr_objects(value, ids);
            if let Some(predicate) = predicate {
                collect_expr_objects(predicate, ids);
            }
        }
        Statement::Return { value } => {
            if let Some(value) = value {
                collect_expr_objects(value, ids);
            }
        }
    }
}

fn collect_expr_objects(expr: &Expr, ids: &mut BTreeSet<u32>) {
    match expr {
        Expr::Unary { expr, .. } => collect_expr_objects(expr, ids),
        Expr::Binary { lhs, rhs, .. } => {
            collect_expr_objects(lhs, ids);
            collect_expr_objects(rhs, ids);
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            collect_expr_objects(cond, ids);
            collect_expr_objects(when_true, ids);
            collect_expr_objects(when_false, ids);
        }
        Expr::CellGet { object_id } => {
            ids.insert(*object_id);
        }
        Expr::ArrayGet { object_id, index } => {
            ids.insert(*object_id);
            collect_expr_objects(index, ids);
        }
        Expr::MapGet { object_id, key } => {
            ids.insert(*object_id);
            collect_expr_objects(key, ids);
        }
        Expr::StructField { base, .. } => collect_expr_objects(base, ids),
        Expr::ArrayIndex { base, index } => {
            collect_expr_objects(base, ids);
            collect_expr_objects(index, ids);
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                collect_expr_objects(part, ids);
            }
        }
        Expr::Literal(_) | Expr::Var(_) => {}
    }
}

fn ensure_confidential_return_shape(body: &[Statement], signature: &str) -> Result<()> {
    let mut returns = 0usize;
    for (index, statement) in body.iter().enumerate() {
        if let Statement::Return { .. } = statement {
            returns += 1;
            if index + 1 != body.len() {
                bail!(
                    "confidential entrypoint {} may only return at the end of the function",
                    signature
                );
            }
        }
    }
    if returns > 1 {
        bail!("confidential entrypoint {} has multiple returns", signature);
    }
    Ok(())
}

fn linearize_statements(statements: &[Statement], predicate: &Expr) -> Result<Vec<Statement>> {
    let mut out = Vec::new();
    for statement in statements {
        out.extend(linearize_statement(statement, predicate)?);
    }
    Ok(out)
}

fn linearize_statement(statement: &Statement, predicate: &Expr) -> Result<Vec<Statement>> {
    match statement {
        Statement::Declare { name, ty, value } => Ok(vec![Statement::Declare {
            name: name.clone(),
            ty: ty.clone(),
            value: gate_expr(predicate, value.clone(), Expr::Literal(Value::zero_for_type(ty))),
        }]),
        Statement::Assign { name, value } => Ok(vec![Statement::Assign {
            name: name.clone(),
            value: gate_expr(predicate, value.clone(), Expr::Var(name.clone())),
        }]),
        Statement::Require { cond } => Ok(vec![Statement::AbortIf {
            cond: and_expr(predicate.clone(), not_expr(cond.clone())),
        }]),
        Statement::AbortIf { cond } => Ok(vec![Statement::AbortIf {
            cond: and_expr(predicate.clone(), cond.clone()),
        }]),
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            let mut out = Vec::new();
            out.extend(linearize_statements(
                then_body,
                &and_expr(predicate.clone(), cond.clone()),
            )?);
            out.extend(linearize_statements(
                else_body,
                &and_expr(predicate.clone(), not_expr(cond.clone())),
            )?);
            Ok(out)
        }
        Statement::For {
            start,
            end,
            body,
            index_var,
            ..
        } => {
            let start = const_expr_uint(start)?;
            let end = const_expr_uint(end)?;
            let mut out = Vec::new();
            for index in start..end {
                let substituted = substitute_block(body, index_var, &Expr::Literal(Value::Uint(index)))?;
                out.extend(linearize_statements(&substituted, predicate)?);
            }
            Ok(out)
        }
        Statement::CellSet {
            object_id,
            value,
            predicate: existing,
        } => Ok(vec![Statement::CellSet {
            object_id: *object_id,
            value: value.clone(),
            predicate: Some(match existing {
                Some(existing) => and_expr(predicate.clone(), existing.clone()),
                None => predicate.clone(),
            }),
        }]),
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate: existing,
        } => Ok(vec![Statement::ArraySet {
            object_id: *object_id,
            index: index.clone(),
            value: value.clone(),
            predicate: Some(match existing {
                Some(existing) => and_expr(predicate.clone(), existing.clone()),
                None => predicate.clone(),
            }),
        }]),
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate: existing,
        } => Ok(vec![Statement::MapPut {
            object_id: *object_id,
            key: key.clone(),
            value: value.clone(),
            predicate: Some(match existing {
                Some(existing) => and_expr(predicate.clone(), existing.clone()),
                None => predicate.clone(),
            }),
        }]),
        Statement::Return { .. } => {
            if matches!(predicate, Expr::Literal(Value::Bool(true))) {
                Ok(vec![statement.clone()])
            } else {
                bail!("predicated return is unsupported")
            }
        }
    }
}

fn substitute_block(statements: &[Statement], name: &str, replacement: &Expr) -> Result<Vec<Statement>> {
    statements
        .iter()
        .map(|statement| substitute_statement(statement, name, replacement))
        .collect()
}

fn substitute_statement(statement: &Statement, name: &str, replacement: &Expr) -> Result<Statement> {
    Ok(match statement {
        Statement::Declare { name: var, ty, value } => Statement::Declare {
            name: var.clone(),
            ty: ty.clone(),
            value: substitute_expr(value, name, replacement),
        },
        Statement::Assign { name: var, value } => Statement::Assign {
            name: var.clone(),
            value: substitute_expr(value, name, replacement),
        },
        Statement::Require { cond } => Statement::Require {
            cond: substitute_expr(cond, name, replacement),
        },
        Statement::AbortIf { cond } => Statement::AbortIf {
            cond: substitute_expr(cond, name, replacement),
        },
        Statement::If {
            cond,
            then_body,
            else_body,
        } => Statement::If {
            cond: substitute_expr(cond, name, replacement),
            then_body: substitute_block(then_body, name, replacement)?,
            else_body: substitute_block(else_body, name, replacement)?,
        },
        Statement::For {
            loop_id,
            index_var,
            start,
            end,
            body,
        } => Statement::For {
            loop_id: loop_id.clone(),
            index_var: index_var.clone(),
            start: substitute_expr(start, name, replacement),
            end: substitute_expr(end, name, replacement),
            body: substitute_block(body, name, replacement)?,
        },
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => Statement::CellSet {
            object_id: *object_id,
            value: substitute_expr(value, name, replacement),
            predicate: predicate
                .as_ref()
                .map(|expr| substitute_expr(expr, name, replacement)),
        },
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => Statement::ArraySet {
            object_id: *object_id,
            index: substitute_expr(index, name, replacement),
            value: substitute_expr(value, name, replacement),
            predicate: predicate
                .as_ref()
                .map(|expr| substitute_expr(expr, name, replacement)),
        },
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => Statement::MapPut {
            object_id: *object_id,
            key: substitute_expr(key, name, replacement),
            value: substitute_expr(value, name, replacement),
            predicate: predicate
                .as_ref()
                .map(|expr| substitute_expr(expr, name, replacement)),
        },
        Statement::Return { value } => Statement::Return {
            value: value
                .as_ref()
                .map(|expr| substitute_expr(expr, name, replacement)),
        },
    })
}

fn substitute_expr(expr: &Expr, name: &str, replacement: &Expr) -> Expr {
    match expr {
        Expr::Var(var) if var == name => replacement.clone(),
        Expr::Unary { op, expr } => Expr::Unary {
            op: op.clone(),
            expr: Box::new(substitute_expr(expr, name, replacement)),
        },
        Expr::Binary { op, lhs, rhs } => Expr::Binary {
            op: op.clone(),
            lhs: Box::new(substitute_expr(lhs, name, replacement)),
            rhs: Box::new(substitute_expr(rhs, name, replacement)),
        },
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => Expr::Select {
            cond: Box::new(substitute_expr(cond, name, replacement)),
            when_true: Box::new(substitute_expr(when_true, name, replacement)),
            when_false: Box::new(substitute_expr(when_false, name, replacement)),
        },
        Expr::ArrayGet { object_id, index } => Expr::ArrayGet {
            object_id: *object_id,
            index: Box::new(substitute_expr(index, name, replacement)),
        },
        Expr::MapGet { object_id, key } => Expr::MapGet {
            object_id: *object_id,
            key: Box::new(substitute_expr(key, name, replacement)),
        },
        Expr::StructField { base, field } => Expr::StructField {
            base: Box::new(substitute_expr(base, name, replacement)),
            field: field.clone(),
        },
        Expr::ArrayIndex { base, index } => Expr::ArrayIndex {
            base: Box::new(substitute_expr(base, name, replacement)),
            index: Box::new(substitute_expr(index, name, replacement)),
        },
        Expr::Keccak256 { parts } => Expr::Keccak256 {
            parts: parts
                .iter()
                .map(|part| substitute_expr(part, name, replacement))
                .collect(),
        },
        other => other.clone(),
    }
}

fn gate_expr(predicate: &Expr, when_true: Expr, when_false: Expr) -> Expr {
    if matches!(predicate, Expr::Literal(Value::Bool(true))) {
        when_true
    } else {
        Expr::Select {
            cond: Box::new(predicate.clone()),
            when_true: Box::new(when_true),
            when_false: Box::new(when_false),
        }
    }
}

fn and_expr(lhs: Expr, rhs: Expr) -> Expr {
    if matches!(lhs, Expr::Literal(Value::Bool(true))) {
        rhs
    } else if matches!(rhs, Expr::Literal(Value::Bool(true))) {
        lhs
    } else {
        Expr::Binary {
            op: BinaryOp::And,
            lhs: Box::new(lhs),
            rhs: Box::new(rhs),
        }
    }
}

fn not_expr(expr: Expr) -> Expr {
    Expr::Unary {
        op: UnaryOp::Not,
        expr: Box::new(expr),
    }
}

fn const_expr_uint(expr: &Expr) -> Result<u128> {
    match expr {
        Expr::Literal(Value::Uint(value)) => Ok(*value),
        _ => bail!("loop bounds must be compile-time constants"),
    }
}

fn const_usize(expr: &pt::Expression) -> Result<usize> {
    match expr {
        pt::Expression::NumberLiteral(_, integer, fraction, _) if fraction.is_empty() => {
            Ok(integer.parse::<usize>()?)
        }
        _ => bail!("expected compile-time integer literal"),
    }
}

fn ensure_secret_args_exist(
    function: &pt::FunctionDefinition,
    entry_meta: &uo_core::EntrypointMetadata,
) -> Result<()> {
    let params = function
        .params
        .iter()
        .filter_map(|(_, param)| param.as_ref().and_then(|param| param.name.as_ref()))
        .map(|identifier| identifier.name.clone())
        .collect::<BTreeSet<_>>();
    for secret in &entry_meta.secret_args {
        if !params.contains(secret) {
            bail!(
                "metadata marks {} as secret in {}, but no such parameter exists",
                secret,
                function_signature(function).unwrap_or_else(|| "<unknown>".into())
            );
        }
    }
    Ok(())
}

fn reject_function_shape(function: &pt::FunctionDefinition) -> Result<()> {
    if function.ty != pt::FunctionTy::Function {
        bail!("constructors/fallbacks/modifiers are unsupported");
    }
    if function.name.is_none() {
        bail!("anonymous functions are unsupported");
    }
    if has_visibility(function, pt::Visibility::Private(None)) {
        return Ok(());
    }
    if has_visibility(function, pt::Visibility::Internal(None)) && !is_helper_function(function) {
        bail!("internal functions must be pure/view single-expression helpers");
    }
    Ok(())
}

fn is_helper_function(function: &pt::FunctionDefinition) -> bool {
    is_internal(function) && is_pure_or_view(function)
}

fn is_internal(function: &pt::FunctionDefinition) -> bool {
    function.attributes.iter().any(|attribute| matches!(
        attribute,
        pt::FunctionAttribute::Visibility(pt::Visibility::Internal(_))
            | pt::FunctionAttribute::Visibility(pt::Visibility::Private(_))
    ))
}

fn is_pure_or_view(function: &pt::FunctionDefinition) -> bool {
    function.attributes.iter().any(|attribute| matches!(
        attribute,
        pt::FunctionAttribute::Mutability(pt::Mutability::Pure(_))
            | pt::FunctionAttribute::Mutability(pt::Mutability::View(_))
    ))
}

fn has_visibility(function: &pt::FunctionDefinition, visibility: pt::Visibility) -> bool {
    function
        .attributes
        .iter()
        .any(|attribute| matches!(attribute, pt::FunctionAttribute::Visibility(v) if std::mem::discriminant(v) == std::mem::discriminant(&visibility)))
}

fn function_signature(function: &pt::FunctionDefinition) -> Option<String> {
    let name = function.name.as_ref()?.name.clone();
    let params = function
        .params
        .iter()
        .map(|(_, param)| {
            param.as_ref()
                .map(|param| type_expr_name(&param.ty))
                .unwrap_or_else(|| "<error>".into())
        })
        .collect::<Vec<_>>()
        .join(",");
    Some(format!("{name}({params})"))
}

fn type_expr_name(expression: &pt::Expression) -> String {
    match expression {
        pt::Expression::Type(_, ty) => match ty {
            pt::Type::Bool => "bool".into(),
            pt::Type::Uint(bits) => format!("uint{bits}"),
            pt::Type::Bytes(32) => "bytes32".into(),
            pt::Type::Address | pt::Type::AddressPayable => "address".into(),
            pt::Type::Mapping { key, value, .. } => {
                format!("mapping({}=>{})", type_expr_name(key), type_expr_name(value))
            }
            other => format!("{other:?}"),
        },
        pt::Expression::ArraySubscript(_, base, Some(size)) => {
            format!("{}[{}]", type_expr_name(base), expr_debug(size))
        }
        pt::Expression::Variable(identifier) => identifier.name.clone(),
        other => format!("{other:?}"),
    }
}

fn expr_debug(expression: &pt::Expression) -> String {
    match expression {
        pt::Expression::NumberLiteral(_, integer, fraction, _) if fraction.is_empty() => {
            integer.clone()
        }
        _ => "<expr>".into(),
    }
}

fn render_parse_errors(errors: Vec<Diagnostic>) -> anyhow::Error {
    anyhow!(
        "{}",
        errors
            .into_iter()
            .map(|error| error.message)
            .collect::<Vec<_>>()
            .join("; ")
    )
}

fn diagnostics_error(message: impl Into<String>) -> Result<()> {
    bail!("{}", message.into())
}

fn oram_batch_ops(capacity: usize) -> usize {
    let batch = ((capacity.max(2) as f64).log2().ceil() as usize + 2).max(3);
    let metadata_pages = capacity.max(1).div_ceil(8) + 1;
    batch + metadata_pages
}

fn disassemble_contract(contract: &CompiledContract) -> Vec<String> {
    let mut lines = Vec::new();
    for function in &contract.functions {
        lines.push(format!("fn {}:", function.signature));
        for (index, statement) in function.body.iter().enumerate() {
            lines.push(format!("  {:04} {}", index, render_statement(statement)));
        }
    }
    lines
}

fn render_contract(functions: &[CompiledFunction]) -> String {
    functions
        .iter()
        .map(|function| {
            let params = function
                .params
                .iter()
                .map(|(name, ty)| format!("{} {}", ty.short_name(), name))
                .collect::<Vec<_>>()
                .join(", ");
            let header = format!("function {}({})", function.signature, params);
            let body = function
                .body
                .iter()
                .map(|statement| format!("  {}", render_statement(statement)))
                .collect::<Vec<_>>()
                .join("\n");
            format!("{header} {{\n{body}\n}}")
        })
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn render_statement(statement: &Statement) -> String {
    match statement {
        Statement::Declare { name, value, .. } => format!("let {} = {}", name, render_expr(value)),
        Statement::Assign { name, value } => format!("{} = {}", name, render_expr(value)),
        Statement::Require { cond } => format!("require {}", render_expr(cond)),
        Statement::AbortIf { cond } => format!("abort_if {}", render_expr(cond)),
        Statement::If {
            cond,
            then_body,
            else_body,
        } => format!(
            "if {} {{ {} }} else {{ {} }}",
            render_expr(cond),
            then_body
                .iter()
                .map(render_statement)
                .collect::<Vec<_>>()
                .join("; "),
            else_body
                .iter()
                .map(render_statement)
                .collect::<Vec<_>>()
                .join("; "),
        ),
        Statement::For {
            index_var,
            start,
            end,
            body,
            ..
        } => format!(
            "for {} in {}..{} {{ {} }}",
            index_var,
            render_expr(start),
            render_expr(end),
            body.iter().map(render_statement).collect::<Vec<_>>().join("; ")
        ),
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => format!(
            "cell[{}] = {} @ {:?}",
            object_id,
            render_expr(value),
            predicate.as_ref().map(render_expr)
        ),
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => format!(
            "array[{}][{}] = {} @ {:?}",
            object_id,
            render_expr(index),
            render_expr(value),
            predicate.as_ref().map(render_expr)
        ),
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => format!(
            "map[{}][{}] = {} @ {:?}",
            object_id,
            render_expr(key),
            render_expr(value),
            predicate.as_ref().map(render_expr)
        ),
        Statement::Return { value } => format!(
            "return {}",
            value.as_ref().map(render_expr).unwrap_or_else(|| "()".into())
        ),
    }
}

fn render_expr(expr: &Expr) -> String {
    match expr {
        Expr::Literal(value) => value.to_string(),
        Expr::Var(name) => name.clone(),
        Expr::Unary { op, expr } => format!("{:?}({})", op, render_expr(expr)),
        Expr::Binary { op, lhs, rhs } => {
            format!("({} {:?} {})", render_expr(lhs), op, render_expr(rhs))
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => format!(
            "select({}, {}, {})",
            render_expr(cond),
            render_expr(when_true),
            render_expr(when_false)
        ),
        Expr::CellGet { object_id } => format!("cell_get({})", object_id),
        Expr::ArrayGet { object_id, index } => {
            format!("array_get({}, {})", object_id, render_expr(index))
        }
        Expr::MapGet { object_id, key } => {
            format!("map_get({}, {})", object_id, render_expr(key))
        }
        Expr::StructField { base, field } => format!("{}.{}", render_expr(base), field),
        Expr::ArrayIndex { base, index } => format!("{}[{}]", render_expr(base), render_expr(index)),
        Expr::Keccak256 { parts } => format!(
            "keccak256({})",
            parts.iter().map(render_expr).collect::<Vec<_>>().join(", ")
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::{compile, validate_source};
    use std::fs;
    use std::path::PathBuf;
    use uo_core::{ContractMetadata, ProgramMode};

    fn write_temp(name: &str, contents: &str) -> PathBuf {
        let path = PathBuf::from(format!("/tmp/uo-solc-test-{}-{}.sol", name, std::process::id()));
        fs::write(&path, contents).unwrap();
        path
    }

    fn parse_metadata(yaml: &str) -> ContractMetadata {
        serde_yaml::from_str(yaml).unwrap()
    }

    #[test]
    fn rejects_inline_assembly() {
        let source = write_temp(
            "asm",
            r#"
            contract C {
                uint256 private x;
                function f(uint256 a) public { assembly { let y := a } }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints: {}
state:
  x:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        assert!(validate_source(source.to_str().unwrap(), &meta).is_err());
    }

    #[test]
    fn compiles_branchless_classifier() {
        let source = write_temp(
            "classifier",
            r#"
            contract FixedSlotClassifier {
                uint256 private last;
                function classify(uint256 secret) public {
                    last = secret & 1;
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: FixedSlotClassifier
entrypoints:
  classify(uint256):
    secret_args: [secret]
    confidential: true
state:
  last:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let artifact = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap();
        assert_eq!(artifact.contract.functions.len(), 1);
        assert!(artifact.contract.functions[0].confidential);
    }
}
