use anyhow::{anyhow, bail, Context, Result};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use uo_core::ir::{
    BackendKind, BinaryOp, CompiledContract, CompiledFunction, ContainerKind, Expr, ProgramMode,
    StateObject, Statement, UnaryOp,
};
use uo_core::manifest::{
    EntrypointManifest, OramManifest, RuntimeManifest, StateObjectManifest, PATH_ORAM_SCHEME,
    SURROGATE_ORAM_SCHEME,
};
use uo_core::{
    AdmittedPackageIdentity, CompiledArtifact, ConfidentialKernelParam, ConfidentialKernelProgram,
    ConfidentialKernelSlotProgram, ContractMetadata, DeclassificationKind,
    ProofRelevantTranslationBundle, ReturnPolicy, ScalarType, StateMetadata, StatusPolicy,
    StructField, Type, Uint256, Value,
};

use solang_parser::{diagnostics::Diagnostic, parse, pt};

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
        let entry_meta = frontend.entrypoint_metadata.get(&signature).ok_or_else(|| {
            anyhow!(
                "entrypoint {} is missing explicit metadata; declare it public or confidential in the sidecar",
                signature
            )
        })?;
        let mut ctx = LowerCtx {
            frontend: &frontend,
            locals: BTreeMap::new(),
            loop_counter: 0,
        };
        let _ = lower_function(function, entry_meta, ProgramMode::Raw, &mut ctx)?;
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
    compile_impl(source_path, metadata, None, mode)
}

pub fn compile_with_metadata_bytes(
    source_path: &str,
    metadata: &ContractMetadata,
    raw_metadata: &[u8],
    mode: ProgramMode,
) -> Result<CompiledArtifact> {
    compile_impl(source_path, metadata, Some(raw_metadata), mode)
}

fn compile_impl(
    source_path: &str,
    metadata: &ContractMetadata,
    raw_metadata: Option<&[u8]>,
    mode: ProgramMode,
) -> Result<CompiledArtifact> {
    let source = fs::read_to_string(source_path)
        .with_context(|| format!("failed to read Solidity source {}", source_path))?;
    let frontend = parse_frontend(source_path, &source, metadata)?;
    if matches!(mode, ProgramMode::Uo) {
        validate_uo_state_backend_policy(&frontend)?;
    }
    let mut functions = Vec::new();
    let mut manifest_entrypoints = BTreeMap::new();
    for function in &frontend.functions {
        let signature = function_signature(function)
            .ok_or_else(|| anyhow!("function without name is unsupported"))?;
        let entry_meta = frontend.entrypoint_metadata.get(&signature).ok_or_else(|| {
            anyhow!(
                "entrypoint {} is missing explicit metadata; declare it public or confidential in the sidecar",
                signature
            )
        })?;
        let mut ctx = LowerCtx {
            frontend: &frontend,
            locals: BTreeMap::new(),
            loop_counter: 0,
        };
        let compiled = lower_function(function, entry_meta, mode.clone(), &mut ctx)?;
        manifest_entrypoints.insert(
            signature.clone(),
            build_manifest_entry(&compiled, &frontend, entry_meta)?,
        );
        functions.push(compiled);
    }
    let compilation_mode = match mode {
        ProgramMode::Raw => "raw".to_string(),
        ProgramMode::Uo => "uo".to_string(),
    };
    let compiler_version = env!("CARGO_PKG_VERSION").to_string();
    let manifest = RuntimeManifest {
        contract: frontend.contract_name.clone(),
        compilation_mode: compilation_mode.clone(),
        objects: frontend
            .state_by_name
            .values()
            .map(|object| {
                Ok(StateObjectManifest {
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
                    oram: if object.backend == BackendKind::Oram {
                        Some(OramManifest::for_object(object)?)
                    } else {
                        None
                    },
                })
            })
            .collect::<Result<Vec<_>>>()?,
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
    let admitted_package = match raw_metadata {
        Some(raw_metadata) => AdmittedPackageIdentity::new_with_raw_metadata(
            &source,
            metadata,
            raw_metadata,
            &compilation_mode,
            &compiler_version,
        )?,
        None => {
            AdmittedPackageIdentity::new(&source, metadata, &compilation_mode, &compiler_version)?
        }
    };
    Ok(CompiledArtifact {
        compiler_version: compiler_version.clone(),
        admitted_package: Some(admitted_package),
        contract,
        diagnostics: frontend.diagnostics,
        transformed_source: Some(render_contract(&functions)),
        disassembly,
    })
}

pub fn translation_validation_bundle_against_artifact(
    source_path: &str,
    metadata: &ContractMetadata,
    artifact: &CompiledArtifact,
) -> Result<ProofRelevantTranslationBundle> {
    let expected = compile(source_path, metadata, artifact.contract.mode.clone())?;
    ProofRelevantTranslationBundle::from_artifacts(source_path, metadata, &expected, artifact)
}

pub fn translation_validation_bundle_against_artifact_with_metadata_bytes(
    source_path: &str,
    metadata: &ContractMetadata,
    raw_metadata: &[u8],
    artifact: &CompiledArtifact,
) -> Result<ProofRelevantTranslationBundle> {
    let expected = compile_with_metadata_bytes(
        source_path,
        metadata,
        raw_metadata,
        artifact.contract.mode.clone(),
    )?;
    ProofRelevantTranslationBundle::from_artifacts(source_path, metadata, &expected, artifact)
}

fn parse_frontend(
    source_path: &str,
    source: &str,
    metadata: &ContractMetadata,
) -> Result<Frontend> {
    let (unit, _) = parse(source, 0).map_err(render_parse_errors)?;
    let mut selected_contract = None;
    for part in &unit.0 {
        match part {
            pt::SourceUnitPart::PragmaDirective(_, _, _)
            | pt::SourceUnitPart::StraySemicolon(_) => {}
            pt::SourceUnitPart::ContractDefinition(contract) => {
                let name = contract
                    .name
                    .as_ref()
                    .map(|name| name.name.as_str())
                    .unwrap_or("<anonymous>");
                if name == metadata.contract {
                    if selected_contract.is_some() {
                        bail!(
                            "duplicate selected contract {} is unsupported",
                            metadata.contract
                        );
                    }
                    selected_contract = Some(contract.as_ref().clone());
                } else {
                    bail!(
                        "unsupported top-level contract {}; proof-grade sources must contain only the selected contract {}",
                        name,
                        metadata.contract
                    );
                }
            }
            pt::SourceUnitPart::ImportDirective(_) => bail!("top-level imports are unsupported"),
            pt::SourceUnitPart::EnumDefinition(_) => bail!("top-level enums are unsupported"),
            pt::SourceUnitPart::StructDefinition(_) => bail!("top-level structs are unsupported"),
            pt::SourceUnitPart::EventDefinition(_) => bail!("top-level events are unsupported"),
            pt::SourceUnitPart::ErrorDefinition(_) => {
                bail!("top-level custom errors are unsupported")
            }
            pt::SourceUnitPart::FunctionDefinition(_) => {
                bail!("top-level functions are unsupported")
            }
            pt::SourceUnitPart::VariableDefinition(_) => {
                bail!("top-level variables are unsupported")
            }
            pt::SourceUnitPart::TypeDefinition(_) => {
                bail!("top-level type aliases are unsupported")
            }
            pt::SourceUnitPart::Annotation(_) => bail!("top-level annotations are unsupported"),
            pt::SourceUnitPart::Using(_) => bail!("top-level using directives are unsupported"),
        }
    }
    let contract =
        selected_contract.ok_or_else(|| anyhow!("contract {} not found", metadata.contract))?;
    if !contract.base.is_empty() {
        bail!("inheritance is unsupported");
    }
    let mut structs = BTreeMap::new();
    let mut state_by_name = BTreeMap::new();
    let mut functions = Vec::new();
    let mut helpers = BTreeMap::new();
    let diagnostics = Vec::new();
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
                state_by_name.insert(
                    name.clone(),
                    lower_state_object(id, &name, def, state_meta, &structs)?,
                );
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
            pt::ContractPart::TypeDefinition(_) => {
                bail!("user-defined type aliases are unsupported")
            }
            pt::ContractPart::Using(_) => bail!("using directives are unsupported"),
            pt::ContractPart::Annotation(_) => {
                bail!("annotations in Solidity source are unsupported")
            }
            pt::ContractPart::StraySemicolon(_) => {}
        }
    }
    for key in metadata.state.keys() {
        if !state_by_name.contains_key(key) {
            bail!("metadata references unknown state object {}", key);
        }
    }
    let function_signatures = functions
        .iter()
        .map(|function| {
            function_signature(function)
                .ok_or_else(|| anyhow!("function without name is unsupported"))
        })
        .collect::<Result<BTreeSet<_>>>()?;
    for signature in metadata.entrypoints.keys() {
        if !function_signatures.contains(signature) {
            bail!("metadata references unknown entrypoint {}", signature);
        }
    }
    let mut entrypoint_metadata = BTreeMap::new();
    for function in &functions {
        let signature = function_signature(function)
            .ok_or_else(|| anyhow!("function without name is unsupported"))?;
        if let Some(entry_meta) = metadata.entrypoints.get(&signature) {
            entrypoint_metadata.insert(signature.clone(), entry_meta.clone());
            ensure_secret_args_exist(function, entry_meta)?;
            validate_entrypoint_metadata_well_formed(&signature, entry_meta, &state_by_name)?;
        } else {
            bail!(
                "entrypoint {} is missing explicit metadata; declare it public or confidential in the sidecar",
                signature
            );
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
    if matches!(mode, ProgramMode::Uo) {
        validate_static_loop_bounds(&lowered, &BTreeMap::new())?;
    }
    let entrypoint_confidential = required_entrypoint_confidential(&signature, entry_meta)?;
    validate_entrypoint_policy(
        &signature,
        &return_type,
        &lowered,
        entry_meta,
        entrypoint_confidential,
        ctx.frontend,
    )?;
    let confidential = matches!(mode, ProgramMode::Uo) && entrypoint_confidential;
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
    let (confidential_program, confidential_slot_program) = if confidential {
        let confidential_program = ConfidentialKernelProgram {
            entrypoint_id: signature.clone(),
            params: params
                .iter()
                .map(|(name, ty)| ConfidentialKernelParam {
                    name: name.clone(),
                    ty: ty.clone(),
                })
                .collect(),
            return_type: return_type.clone(),
            secret_args: secret_args.clone(),
            body: uo_core::lower_confidential_kernel_statements(&lowered, &signature)?,
        };
        let confidential_slot_program = confidential_program.to_slot_program()?;
        ensure_confidential_slot_program_uses_uo_backends(
            &confidential_slot_program,
            ctx.frontend,
        )?;
        (Some(confidential_program), Some(confidential_slot_program))
    } else {
        (None, None)
    };
    Ok(CompiledFunction {
        signature,
        params,
        return_type,
        body: lowered,
        secret_args,
        confidential,
        confidential_program,
        confidential_slot_program,
    })
}

fn ensure_confidential_slot_program_uses_uo_backends(
    program: &ConfidentialKernelSlotProgram,
    frontend: &Frontend,
) -> Result<()> {
    for step in program.expected_runtime_steps().iter() {
        let Some(object_id) = step.object_id else {
            continue;
        };
        let object = frontend
            .state_by_name
            .values()
            .find(|object| object.id == object_id)
            .ok_or_else(|| {
                anyhow!(
                    "confidential entrypoint {} references unknown state object id {}",
                    program.entrypoint_id,
                    object_id
                )
            })?;
        if object.backend == BackendKind::Raw {
            bail!(
                "confidential entrypoint {} targets raw backend object {} ({})",
                program.entrypoint_id,
                object.name,
                object_id
            );
        }
        if !object.confidential {
            bail!(
                "confidential entrypoint {} targets non-confidential state object {} ({})",
                program.entrypoint_id,
                object.name,
                object_id
            );
        }
    }
    Ok(())
}

fn validate_uo_state_backend_policy(frontend: &Frontend) -> Result<()> {
    for object in frontend.state_by_name.values() {
        if object.confidential && object.backend == BackendKind::Raw {
            bail!(
                "confidential state object {} uses raw backend in UO mode",
                object.name
            );
        }
    }
    Ok(())
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
        pt::Expression::AssignAdd(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::Add))
        }
        pt::Expression::AssignSubtract(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::Sub))
        }
        pt::Expression::AssignAnd(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::BitAnd))
        }
        pt::Expression::AssignOr(_, left, right) => {
            (left.as_ref(), right.as_ref(), Some(BinaryOp::BitOr))
        }
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
                ContainerKind::Cell => Ok(Expr::CellGet {
                    object_id: state.id,
                }),
                _ => bail!(
                    "state object {} must be accessed through index/key",
                    identifier.name
                ),
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
            Ok(Expr::Literal(Value::Uint(Uint256::from_dec_str(integer)?)))
        }
        pt::Expression::HexNumberLiteral(_, value, _) => {
            Ok(Expr::Literal(Value::Uint(Uint256::from_hex_str(value)?)))
        }
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
        pt::Expression::BitwiseAnd(_, lhs, rhs) => {
            lower_binary(BinaryOp::BitAnd, lhs, rhs, ctx, subst)
        }
        pt::Expression::BitwiseOr(_, lhs, rhs) => {
            lower_binary(BinaryOp::BitOr, lhs, rhs, ctx, subst)
        }
        pt::Expression::BitwiseXor(_, lhs, rhs) => {
            lower_binary(BinaryOp::BitXor, lhs, rhs, ctx, subst)
        }
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
                        return Ok(Expr::Literal(Value::uint(len)));
                    }
                    if let Some(Type::Array(_, len)) = ctx.locals.get(&identifier.name) {
                        return Ok(Expr::Literal(Value::uint(*len)));
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
                        ContainerKind::Array => {
                            Ok(LValue::Array(state.id, lower_expr(index, ctx, subst)?))
                        }
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
        pt::Statement::Expression(_, pt::Expression::Assign(_, left, right)) => {
            let name = match left.as_ref() {
                pt::Expression::Variable(identifier) => identifier.name.clone(),
                _ => bail!("for-loop initializer must assign to an identifier"),
            };
            Ok((name, lower_expr(right, ctx, &BTreeMap::new())?))
        }
        pt::Statement::Expression(_, _) => bail!("unsupported for-loop initializer"),
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
        pt::Expression::PostIncrement(_, expr) | pt::Expression::PreIncrement(_, expr) => {
            match expr.as_ref() {
                pt::Expression::Variable(identifier) if identifier.name == index_var => Ok(()),
                _ => bail!("for-loop increment must update {}", index_var),
            }
        }
        pt::Expression::AssignAdd(_, left, right) => match (left.as_ref(), right.as_ref()) {
            (
                pt::Expression::Variable(identifier),
                pt::Expression::NumberLiteral(_, integer, fraction, _),
            ) if identifier.name == index_var && integer == "1" && fraction.is_empty() => Ok(()),
            _ => bail!("for-loop increment must be {} += 1", index_var),
        },
        _ => bail!("unsupported for-loop increment"),
    }
}

fn lower_type_expr(expression: &pt::Expression, structs: &BTreeMap<String, Type>) -> Result<Type> {
    match expression {
        pt::Expression::Type(_, ty) => match ty {
            pt::Type::Bool => Ok(Type::Scalar(ScalarType::Bool)),
            pt::Type::Uint(bits) if *bits == 256 => Ok(Type::Scalar(ScalarType::Uint(*bits))),
            pt::Type::Uint(bits) => {
                bail!("only uint256 is supported in proof-grade mode; found uint{bits}")
            }
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
    let oram_scheme = match (backend.clone(), state_meta.oram_scheme.as_ref()) {
        (BackendKind::Oram, Some(scheme)) => scheme.clone(),
        (BackendKind::Oram, None) => {
            bail!("ORAM state {} is missing explicit oram_scheme", name)
        }
        (_, Some(_)) => {
            bail!("non-ORAM state {} must not declare oram_scheme", name)
        }
        (_, None) => SURROGATE_ORAM_SCHEME.into(),
    };
    match kind {
        ContainerKind::Cell => {
            let value_type = lower_type_expr(&def.ty, structs)?;
            validate_metadata_type(name, "value", &state_meta.value, &value_type)?;
            if state_meta.key.is_some() {
                bail!("cell state {} must not declare metadata key type", name);
            }
            if state_meta.capacity.is_some() {
                bail!("cell state {} must not declare metadata capacity", name);
            }
            Ok(StateObject {
                id,
                name: name.into(),
                kind,
                backend,
                oram_scheme,
                value_type,
                key_type: None,
                capacity: None,
                confidential: state_meta.confidential,
            })
        }
        ContainerKind::Array => {
            let (element_ty, capacity) = match &def.ty {
                pt::Expression::ArraySubscript(_, base, Some(size)) => {
                    (lower_type_expr(base, structs)?, const_usize(size)?)
                }
                _ => bail!("array state {} must have a fixed compile-time size", name),
            };
            if capacity == 0 {
                bail!("array state {} must have positive capacity", name);
            }
            let metadata_capacity = state_meta
                .capacity
                .ok_or_else(|| anyhow!("array state {} is missing metadata capacity", name))?;
            if metadata_capacity != capacity {
                bail!(
                    "array state {} metadata capacity {} does not match source length {}",
                    name,
                    metadata_capacity,
                    capacity
                );
            }
            validate_metadata_type(name, "value", &state_meta.value, &element_ty)?;
            if state_meta.key.is_some() {
                bail!("array state {} must not declare metadata key type", name);
            }
            Ok(StateObject {
                id,
                name: name.into(),
                kind,
                backend,
                oram_scheme,
                value_type: element_ty,
                key_type: None,
                capacity: Some(capacity),
                confidential: state_meta.confidential,
            })
        }
        ContainerKind::Map => {
            let capacity = state_meta
                .capacity
                .ok_or_else(|| anyhow!("map state {} is missing metadata capacity", name))?;
            if capacity == 0 {
                bail!("map state {} must have positive capacity", name);
            }
            match &def.ty {
                pt::Expression::Type(_, pt::Type::Mapping { key, value, .. }) => {
                    let key_type = lower_type_expr(key, structs)?;
                    let value_type = lower_type_expr(value, structs)?;
                    let metadata_key = state_meta.key.as_ref().ok_or_else(|| {
                        anyhow!("map state {} is missing metadata key type", name)
                    })?;
                    validate_metadata_type(name, "key", metadata_key, &key_type)?;
                    validate_metadata_type(name, "value", &state_meta.value, &value_type)?;
                    Ok(StateObject {
                        id,
                        name: name.into(),
                        kind,
                        backend,
                        oram_scheme,
                        value_type,
                        key_type: Some(key_type),
                        capacity: Some(capacity),
                        confidential: state_meta.confidential,
                    })
                }
                _ => bail!("map state {} must use mapping syntax", name),
            }
        }
    }
}

fn validate_metadata_type(
    object_name: &str,
    field_name: &str,
    metadata_type: &str,
    source_type: &Type,
) -> Result<()> {
    let source_type = source_type.short_name();
    if metadata_type == source_type {
        Ok(())
    } else {
        bail!(
            "state {} metadata {} type {} does not match source type {}",
            object_name,
            field_name,
            metadata_type,
            source_type
        )
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
                param
                    .name
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
    let oram_accesses = count_oram_accesses(&function.body, frontend)?;
    validate_oram_access_shape(&function.signature, &oram_accesses, frontend)?;
    let max_commit_ops = accessed_objects
        .iter()
        .map(|object_id| {
            let object = state_object_by_id(frontend, *object_id)?;
            Ok(match object.kind {
                ContainerKind::Cell => 1usize,
                ContainerKind::Array | ContainerKind::Map
                    if object.backend == BackendKind::Oram =>
                {
                    let per_access = OramManifest::for_object(object)?.total_commit_ops();
                    if object.oram_scheme == PATH_ORAM_SCHEME {
                        per_access * oram_accesses.get(object_id).copied().unwrap_or(0)
                    } else {
                        per_access
                    }
                }
                ContainerKind::Array | ContainerKind::Map => object.capacity.unwrap_or(1),
            })
        })
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .sum::<usize>();
    let budget = entry_meta.public_gas_budget.unwrap_or(
        2000 + counts.statement_count as u64 * 11
            + counts.expr_count as u64 * 7
            + max_commit_ops as u64 * 29,
    );
    let (confidential_program, confidential_slot_program, kernel_steps) = if function.confidential {
        let confidential_program = function.confidential_kernel_program()?;
        let confidential_slot_program = confidential_program.to_slot_program()?;
        let kernel_steps = confidential_slot_program
            .expected_runtime_step_manifest()
            .into_vec();
        (
            Some(confidential_program),
            Some(confidential_slot_program),
            kernel_steps,
        )
    } else {
        (None, None, Vec::new())
    };
    let max_hash_part_bytes = confidential_program
        .as_ref()
        .map(|program| {
            program.max_keccak_part_canonical_len_for_state(
                &frontend.state_by_name.values().cloned().collect::<Vec<_>>(),
            )
        })
        .transpose()?
        .unwrap_or(0);
    Ok(EntrypointManifest {
        secret_args: function.secret_args.clone(),
        param_names: function
            .params
            .iter()
            .map(|(name, _)| name.clone())
            .collect(),
        entry_input_len: function
            .params
            .iter()
            .map(|(_, ty)| ty.canonical_len())
            .sum(),
        public_gas_budget: budget,
        arena_bytes: 4096 + counts.local_count * 64,
        max_stack_words: 64 + counts.local_count,
        max_hash_part_bytes,
        return_canonical_len: function.return_type.as_ref().map(Type::canonical_len),
        returns: required_return_policy(&function.signature, entry_meta)?,
        status: required_status_policy(&function.signature, entry_meta)?,
        declassifies: entry_meta.declassifies.clone(),
        public_state_declassifies: entry_meta.public_state_declassifies.clone(),
        confidential_program,
        confidential_slot_program,
        kernel_steps,
        uocell_reads: counts.cell_reads,
        uocell_writes: counts.cell_writes,
        uoarray_reads: counts.array_reads,
        uoarray_writes: counts.array_writes,
        uomap_reads: counts.map_reads,
        uomap_writes: counts.map_writes,
        max_commit_ops,
        oram_accesses,
    })
}

fn validate_oram_access_shape(
    signature: &str,
    oram_accesses: &BTreeMap<u32, usize>,
    frontend: &Frontend,
) -> Result<()> {
    let state = frontend.state_by_name.values().cloned().collect::<Vec<_>>();
    uo_core::validate_oram_access_shape(signature, oram_accesses, &state)
}

fn validate_static_loop_bounds(
    statements: &[Statement],
    loop_env: &BTreeMap<String, usize>,
) -> Result<()> {
    for statement in statements {
        match statement {
            Statement::If {
                then_body,
                else_body,
                ..
            } => {
                validate_static_loop_bounds(then_body, loop_env)?;
                validate_static_loop_bounds(else_body, loop_env)?;
            }
            Statement::For {
                loop_id,
                index_var,
                start,
                end,
                body,
            } => {
                let start = eval_loop_bound(start, loop_env).ok_or_else(|| {
                    anyhow!("loop {} start bound must be compile-time exact", loop_id)
                })?;
                let end = eval_loop_bound(end, loop_env).ok_or_else(|| {
                    anyhow!("loop {} end bound must be compile-time exact", loop_id)
                })?;
                for index in start..end {
                    let mut nested_env = loop_env.clone();
                    nested_env.insert(index_var.clone(), index);
                    validate_static_loop_bounds(body, &nested_env)?;
                }
            }
            Statement::Declare { .. }
            | Statement::Assign { .. }
            | Statement::Require { .. }
            | Statement::AbortIf { .. }
            | Statement::CellSet { .. }
            | Statement::ArraySet { .. }
            | Statement::MapPut { .. }
            | Statement::Return { .. } => {}
        }
    }
    Ok(())
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
    count_body_with_env(statements, &BTreeMap::new())
}

fn count_body_with_env(
    statements: &[Statement],
    loop_env: &BTreeMap<String, usize>,
) -> CountSummary {
    let mut counts = CountSummary::default();
    for statement in statements {
        counts.statement_count += 1;
        match statement {
            Statement::Declare { value, .. } => {
                counts.local_count += 1;
                count_expr(value, &mut counts);
            }
            Statement::Assign { value, .. } => count_expr(value, &mut counts),
            Statement::Require { cond } | Statement::AbortIf { cond } => {
                count_expr(cond, &mut counts)
            }
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
            Statement::For {
                index_var,
                start,
                end,
                body,
                ..
            } => {
                count_expr(start, &mut counts);
                count_expr(end, &mut counts);
                let start = eval_loop_bound(start, loop_env);
                let end = eval_loop_bound(end, loop_env);
                match (start, end) {
                    (Some(start), Some(end)) => {
                        for index in start..end {
                            let mut nested_env = loop_env.clone();
                            nested_env.insert(index_var.clone(), index);
                            let body_counts = count_body_with_env(body, &nested_env);
                            merge_counts(&mut counts, body_counts);
                        }
                    }
                    _ => {
                        let body_counts = count_body_with_env(body, loop_env);
                        merge_counts(&mut counts, body_counts);
                    }
                }
            }
            Statement::CellSet {
                value, predicate, ..
            } => {
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

fn count_oram_accesses(
    statements: &[Statement],
    frontend: &Frontend,
) -> Result<BTreeMap<u32, usize>> {
    let mut counts = BTreeMap::new();
    for statement in statements {
        collect_oram_statement_accesses(statement, frontend, &BTreeMap::new(), &mut counts)?;
    }
    Ok(counts)
}

fn collect_oram_statement_accesses(
    statement: &Statement,
    frontend: &Frontend,
    loop_env: &BTreeMap<String, usize>,
    counts: &mut BTreeMap<u32, usize>,
) -> Result<()> {
    match statement {
        Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
            collect_oram_expr_accesses(value, frontend, counts)
        }
        Statement::Require { cond } | Statement::AbortIf { cond } => {
            collect_oram_expr_accesses(cond, frontend, counts)
        }
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            collect_oram_expr_accesses(cond, frontend, counts)?;
            for stmt in then_body {
                collect_oram_statement_accesses(stmt, frontend, loop_env, counts)?;
            }
            for stmt in else_body {
                collect_oram_statement_accesses(stmt, frontend, loop_env, counts)?;
            }
            Ok(())
        }
        Statement::For {
            loop_id,
            index_var,
            start,
            end,
            body,
        } => {
            collect_oram_expr_accesses(start, frontend, counts)?;
            collect_oram_expr_accesses(end, frontend, counts)?;
            let start = eval_loop_bound(start, loop_env);
            let end = eval_loop_bound(end, loop_env);
            match (start, end) {
                (Some(start), Some(end)) => {
                    for index in start..end {
                        let mut nested_env = loop_env.clone();
                        nested_env.insert(index_var.clone(), index);
                        for stmt in body {
                            collect_oram_statement_accesses(stmt, frontend, &nested_env, counts)?;
                        }
                    }
                }
                _ if body_contains_oram_accesses(body, frontend)? => {
                    bail!(
                        "loop {} contains ORAM accesses but its trip count is not compile-time exact",
                        loop_id
                    );
                }
                _ => {}
            }
            Ok(())
        }
        Statement::CellSet {
            value, predicate, ..
        } => {
            collect_oram_expr_accesses(value, frontend, counts)?;
            if let Some(predicate) = predicate {
                collect_oram_expr_accesses(predicate, frontend, counts)?;
            }
            Ok(())
        }
        Statement::ArraySet {
            index,
            value,
            predicate,
            ..
        } => {
            collect_oram_expr_accesses(index, frontend, counts)?;
            collect_oram_expr_accesses(value, frontend, counts)?;
            if let Some(predicate) = predicate {
                collect_oram_expr_accesses(predicate, frontend, counts)?;
            }
            Ok(())
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            record_oram_access(*object_id, frontend, counts)?;
            collect_oram_expr_accesses(key, frontend, counts)?;
            collect_oram_expr_accesses(value, frontend, counts)?;
            if let Some(predicate) = predicate {
                collect_oram_expr_accesses(predicate, frontend, counts)?;
            }
            Ok(())
        }
        Statement::Return { value } => {
            if let Some(value) = value {
                collect_oram_expr_accesses(value, frontend, counts)?;
            }
            Ok(())
        }
    }
}

fn body_contains_oram_accesses(statements: &[Statement], frontend: &Frontend) -> Result<bool> {
    let mut counts = BTreeMap::new();
    for statement in statements {
        collect_oram_statement_accesses(statement, frontend, &BTreeMap::new(), &mut counts)?;
        if !counts.is_empty() {
            return Ok(true);
        }
    }
    Ok(false)
}

fn eval_loop_bound(expr: &Expr, loop_env: &BTreeMap<String, usize>) -> Option<usize> {
    eval_loop_bound_uint(expr, loop_env)?.checked_to_usize()
}

fn eval_loop_bound_uint(expr: &Expr, loop_env: &BTreeMap<String, usize>) -> Option<Uint256> {
    match expr {
        Expr::Literal(Value::Uint(value)) => Some(*value),
        Expr::Literal(Value::Bool(value)) => Some(Uint256::from_bool(*value)),
        Expr::Var(name) => loop_env.get(name).copied().map(Uint256::from),
        Expr::Unary {
            op: UnaryOp::Neg,
            expr,
        } => eval_loop_bound_uint(expr, loop_env).map(Uint256::wrapping_neg),
        Expr::Unary {
            op: UnaryOp::Not,
            expr,
        } => eval_loop_bound_uint(expr, loop_env).map(|value| Uint256::from_bool(value.is_zero())),
        Expr::Binary { op, lhs, rhs } => {
            let lhs = eval_loop_bound_uint(lhs, loop_env)?;
            let rhs = eval_loop_bound_uint(rhs, loop_env)?;
            match op {
                BinaryOp::Add => Some(lhs.wrapping_add(rhs)),
                BinaryOp::Sub => Some(lhs.wrapping_sub(rhs)),
                BinaryOp::Mul => Some(lhs.wrapping_mul(rhs)),
                BinaryOp::Div => Some(if rhs.is_zero() {
                    Uint256::ZERO
                } else {
                    lhs.div_rem(rhs).0
                }),
                BinaryOp::Mod => Some(if rhs.is_zero() {
                    Uint256::ZERO
                } else {
                    lhs.div_rem(rhs).1
                }),
                BinaryOp::BitAnd => Some(lhs.bitand(rhs)),
                BinaryOp::BitOr => Some(lhs.bitor(rhs)),
                BinaryOp::BitXor => Some(lhs.bitxor(rhs)),
                BinaryOp::Eq => Some(Uint256::from_bool(lhs == rhs)),
                BinaryOp::Neq => Some(Uint256::from_bool(lhs != rhs)),
                BinaryOp::Lt => Some(Uint256::from_bool(lhs < rhs)),
                BinaryOp::Lte => Some(Uint256::from_bool(lhs <= rhs)),
                BinaryOp::Gt => Some(Uint256::from_bool(lhs > rhs)),
                BinaryOp::Gte => Some(Uint256::from_bool(lhs >= rhs)),
                BinaryOp::And => Some(Uint256::from_bool(lhs.as_bool() && rhs.as_bool())),
                BinaryOp::Or => Some(Uint256::from_bool(lhs.as_bool() || rhs.as_bool())),
            }
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            let cond = eval_loop_bound_uint(cond, loop_env)?;
            if cond.as_bool() {
                eval_loop_bound_uint(when_true, loop_env)
            } else {
                eval_loop_bound_uint(when_false, loop_env)
            }
        }
        Expr::CellGet { .. }
        | Expr::ArrayGet { .. }
        | Expr::MapGet { .. }
        | Expr::StructField { .. }
        | Expr::ArrayIndex { .. }
        | Expr::Keccak256 { .. }
        | Expr::Literal(Value::Bytes32(_))
        | Expr::Literal(Value::Address(_))
        | Expr::Literal(Value::Struct(_))
        | Expr::Literal(Value::Array(_)) => None,
    }
}

fn collect_oram_expr_accesses(
    expr: &Expr,
    frontend: &Frontend,
    counts: &mut BTreeMap<u32, usize>,
) -> Result<()> {
    match expr {
        Expr::Unary { expr, .. } => collect_oram_expr_accesses(expr, frontend, counts),
        Expr::Binary { lhs, rhs, .. } => {
            collect_oram_expr_accesses(lhs, frontend, counts)?;
            collect_oram_expr_accesses(rhs, frontend, counts)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            collect_oram_expr_accesses(cond, frontend, counts)?;
            collect_oram_expr_accesses(when_true, frontend, counts)?;
            collect_oram_expr_accesses(when_false, frontend, counts)
        }
        Expr::ArrayGet { index, .. } => collect_oram_expr_accesses(index, frontend, counts),
        Expr::MapGet { object_id, key } => {
            record_oram_access(*object_id, frontend, counts)?;
            collect_oram_expr_accesses(key, frontend, counts)
        }
        Expr::StructField { base, .. } => collect_oram_expr_accesses(base, frontend, counts),
        Expr::ArrayIndex { base, index } => {
            collect_oram_expr_accesses(base, frontend, counts)?;
            collect_oram_expr_accesses(index, frontend, counts)
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                collect_oram_expr_accesses(part, frontend, counts)?;
            }
            Ok(())
        }
        Expr::Literal(_) | Expr::Var(_) | Expr::CellGet { .. } => Ok(()),
    }
}

fn record_oram_access(
    object_id: u32,
    frontend: &Frontend,
    counts: &mut BTreeMap<u32, usize>,
) -> Result<()> {
    if state_object_by_id(frontend, object_id)?.backend == BackendKind::Oram {
        *counts.entry(object_id).or_default() += 1;
    }
    Ok(())
}

fn state_object_by_id(frontend: &Frontend, object_id: u32) -> Result<&StateObject> {
    frontend
        .state_by_name
        .values()
        .find(|object| object.id == object_id)
        .ok_or_else(|| anyhow!("unknown object id {} in manifest counting", object_id))
}

fn collect_statement_objects(statement: &Statement, ids: &mut BTreeSet<u32>) {
    match statement {
        Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
            collect_expr_objects(value, ids);
        }
        Statement::Require { cond } | Statement::AbortIf { cond } => {
            collect_expr_objects(cond, ids)
        }
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
        Statement::For {
            start, end, body, ..
        } => {
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

#[derive(Default)]
struct PolicySensitivity {
    return_sensitive: bool,
    status_sensitive: bool,
    sensitive_public_writes: BTreeSet<String>,
    confidential_reads: BTreeSet<String>,
}

fn validate_entrypoint_policy(
    signature: &str,
    return_type: &Option<Type>,
    body: &[Statement],
    entry_meta: &uo_core::EntrypointMetadata,
    entrypoint_confidential: bool,
    frontend: &Frontend,
) -> Result<()> {
    let returns = required_return_policy(signature, entry_meta)?;
    let status = required_status_policy(signature, entry_meta)?;
    let sensitivity = policy_sensitivity(body, entry_meta, frontend)?;
    if !entrypoint_confidential && !sensitivity.confidential_reads.is_empty() {
        bail!(
            "entrypoint {} reads confidential state {}; mark it confidential",
            signature,
            sensitivity
                .confidential_reads
                .iter()
                .cloned()
                .collect::<Vec<_>>()
                .join(", ")
        );
    }
    match (return_type.is_some(), returns) {
        (true, ReturnPolicy::Forbidden) => bail!(
            "entrypoint {} returns a value but declares returns: forbidden",
            signature
        ),
        (false, ReturnPolicy::Forbidden) => {}
        (false, _) => bail!(
            "entrypoint {} declares a return policy but has no return value; use returns: forbidden",
            signature
        ),
        (true, ReturnPolicy::Public) if entrypoint_confidential => bail!(
            "confidential entrypoint {} returns a plaintext value; declare returns: declassified or remove the return",
            signature
        ),
        (true, ReturnPolicy::Public) if sensitivity.return_sensitive => bail!(
            "entrypoint {} returns data derived from confidential state or secret arguments; declare returns: declassified",
            signature
        ),
        (true, ReturnPolicy::Declassified) => require_declassifies(
            signature,
            entry_meta,
            DeclassificationKind::Return,
            "returns: declassified",
        )
        .and_then(|_| {
            if entrypoint_confidential || sensitivity.return_sensitive {
                Ok(())
            } else {
                bail!(
                    "entrypoint {} declares returns: declassified but the return is not secret-dependent; use returns: public",
                    signature
                )
            }
        })?,
        (true, ReturnPolicy::EncryptedToClient) if !entrypoint_confidential => bail!(
            "entrypoint {} declares encrypted_to_client returns but is not confidential",
            signature
        ),
        (true, ReturnPolicy::EncryptedToClient)
            if entry_meta
                .declassifies
                .contains(&DeclassificationKind::Return) =>
        {
            bail!(
                "entrypoint {} declares encrypted_to_client returns and must not declassify the plaintext return",
                signature
            )
        }
        (true, ReturnPolicy::EncryptedToClient) => {}
        (true, ReturnPolicy::Public) => {}
    }
    if status == StatusPolicy::Declassified {
        require_declassifies(
            signature,
            entry_meta,
            DeclassificationKind::Success,
            "status: declassified",
        )?;
        if !sensitivity.status_sensitive {
            bail!(
                "entrypoint {} declares status: declassified but success status is not secret-dependent; use status: public",
                signature
            );
        }
    } else if sensitivity.status_sensitive {
        bail!(
            "entrypoint {} has secret-dependent success/abort status; declare status: declassified",
            signature
        );
    }
    validate_exact_declassification_labels(signature, entry_meta, returns, status)?;
    let declared_public_state = entry_meta
        .public_state_declassifies
        .iter()
        .collect::<BTreeSet<_>>();
    let undeclared_public_writes = sensitivity
        .sensitive_public_writes
        .iter()
        .filter(|name| !declared_public_state.contains(name))
        .cloned()
        .collect::<Vec<_>>();
    if !undeclared_public_writes.is_empty() {
        bail!(
            "entrypoint {} writes data or predicates derived from confidential state or secret arguments to public state {}; declare public_state_declassifies for the target object(s)",
            signature,
            undeclared_public_writes.join(", ")
        );
    }
    let unused_public_state_releases = declared_public_state
        .iter()
        .filter(|name| !sensitivity.sensitive_public_writes.contains(name.as_str()))
        .map(|name| (*name).clone())
        .collect::<Vec<_>>();
    if !unused_public_state_releases.is_empty() {
        bail!(
            "entrypoint {} declares public_state_declassifies for non-sensitive public state {}; remove the unused release target(s)",
            signature,
            unused_public_state_releases.join(", ")
        );
    }
    Ok(())
}

fn required_return_policy(
    signature: &str,
    entry_meta: &uo_core::EntrypointMetadata,
) -> Result<ReturnPolicy> {
    entry_meta.returns.ok_or_else(|| {
        anyhow!(
            "entrypoint {} is missing explicit returns policy",
            signature
        )
    })
}

fn required_entrypoint_confidential(
    signature: &str,
    entry_meta: &uo_core::EntrypointMetadata,
) -> Result<bool> {
    entry_meta.confidential.ok_or_else(|| {
        anyhow!(
            "entrypoint {} is missing explicit confidential policy",
            signature
        )
    })
}

fn required_status_policy(
    signature: &str,
    entry_meta: &uo_core::EntrypointMetadata,
) -> Result<StatusPolicy> {
    entry_meta
        .status
        .ok_or_else(|| anyhow!("entrypoint {} is missing explicit status policy", signature))
}

fn require_declassifies(
    signature: &str,
    entry_meta: &uo_core::EntrypointMetadata,
    kind: DeclassificationKind,
    field: &str,
) -> Result<()> {
    if entry_meta.declassifies.contains(&kind) {
        Ok(())
    } else {
        bail!(
            "entrypoint {} declares {} but omits declassifies: [{:?}]",
            signature,
            field,
            kind
        )
    }
}

fn validate_exact_declassification_labels(
    signature: &str,
    entry_meta: &uo_core::EntrypointMetadata,
    returns: ReturnPolicy,
    status: StatusPolicy,
) -> Result<()> {
    let mut expected = BTreeSet::new();
    if returns == ReturnPolicy::Declassified {
        expected.insert(DeclassificationKind::Return);
    }
    if status == StatusPolicy::Declassified {
        expected.insert(DeclassificationKind::Success);
    }
    let declared = entry_meta
        .declassifies
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    if declared == expected {
        return Ok(());
    }
    let unused = declared.difference(&expected).copied().collect::<Vec<_>>();
    if !unused.is_empty() {
        bail!(
            "entrypoint {} declares unused declassifies label(s) {:?}",
            signature,
            unused
        );
    }
    let missing = expected.difference(&declared).copied().collect::<Vec<_>>();
    bail!(
        "entrypoint {} is missing required declassifies label(s) {:?}",
        signature,
        missing
    )
}

fn policy_sensitivity(
    statements: &[Statement],
    entry_meta: &uo_core::EntrypointMetadata,
    frontend: &Frontend,
) -> Result<PolicySensitivity> {
    let mut tainted = entry_meta
        .secret_args
        .iter()
        .cloned()
        .collect::<BTreeSet<_>>();
    let mut sensitivity = PolicySensitivity::default();
    collect_policy_sensitivity(statements, frontend, &mut tainted, &mut sensitivity, false)?;
    Ok(sensitivity)
}

fn collect_policy_sensitivity(
    statements: &[Statement],
    frontend: &Frontend,
    tainted: &mut BTreeSet<String>,
    sensitivity: &mut PolicySensitivity,
    control_sensitive: bool,
) -> Result<()> {
    for statement in statements {
        match statement {
            Statement::Declare { name, value, .. } | Statement::Assign { name, value } => {
                collect_confidential_reads_in_expr(
                    value,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                set_taint(
                    name,
                    control_sensitive || expr_is_policy_sensitive(value, frontend, tainted),
                    tainted,
                );
            }
            Statement::Require { cond } | Statement::AbortIf { cond } => {
                collect_confidential_reads_in_expr(
                    cond,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                sensitivity.status_sensitive |=
                    control_sensitive || expr_is_policy_sensitive(cond, frontend, tainted);
            }
            Statement::If {
                cond,
                then_body,
                else_body,
            } => {
                collect_confidential_reads_in_expr(
                    cond,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                let cond_sensitive = expr_is_policy_sensitive(cond, frontend, tainted);
                let mut then_tainted = tainted.clone();
                let mut else_tainted = tainted.clone();
                if cond_sensitive {
                    mark_assigned_locals(then_body, &mut then_tainted);
                    mark_assigned_locals(else_body, &mut else_tainted);
                }
                collect_policy_sensitivity(
                    then_body,
                    frontend,
                    &mut then_tainted,
                    sensitivity,
                    control_sensitive || cond_sensitive,
                )?;
                collect_policy_sensitivity(
                    else_body,
                    frontend,
                    &mut else_tainted,
                    sensitivity,
                    control_sensitive || cond_sensitive,
                )?;
                tainted.extend(then_tainted);
                tainted.extend(else_tainted);
            }
            Statement::For {
                start, end, body, ..
            } => {
                collect_confidential_reads_in_expr(
                    start,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                collect_confidential_reads_in_expr(
                    end,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                let loop_sensitive = control_sensitive
                    || expr_is_policy_sensitive(start, frontend, tainted)
                    || expr_is_policy_sensitive(end, frontend, tainted);
                collect_policy_sensitivity(body, frontend, tainted, sensitivity, loop_sensitive)?;
            }
            Statement::CellSet {
                object_id,
                value,
                predicate,
            } => {
                collect_confidential_reads_in_expr(
                    value,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                if let Some(predicate) = predicate {
                    collect_confidential_reads_in_expr(
                        predicate,
                        frontend,
                        &mut sensitivity.confidential_reads,
                    )?;
                }
                record_sensitive_public_write(
                    *object_id,
                    control_sensitive
                        || expr_is_policy_sensitive(value, frontend, tainted)
                        || predicate
                            .as_ref()
                            .is_some_and(|expr| expr_is_policy_sensitive(expr, frontend, tainted)),
                    frontend,
                    sensitivity,
                )?;
            }
            Statement::ArraySet {
                object_id,
                index,
                value,
                predicate,
            } => {
                collect_confidential_reads_in_expr(
                    index,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                collect_confidential_reads_in_expr(
                    value,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                if let Some(predicate) = predicate {
                    collect_confidential_reads_in_expr(
                        predicate,
                        frontend,
                        &mut sensitivity.confidential_reads,
                    )?;
                }
                record_sensitive_public_write(
                    *object_id,
                    control_sensitive
                        || expr_is_policy_sensitive(index, frontend, tainted)
                        || expr_is_policy_sensitive(value, frontend, tainted)
                        || predicate
                            .as_ref()
                            .is_some_and(|expr| expr_is_policy_sensitive(expr, frontend, tainted)),
                    frontend,
                    sensitivity,
                )?;
            }
            Statement::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                collect_confidential_reads_in_expr(
                    key,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                collect_confidential_reads_in_expr(
                    value,
                    frontend,
                    &mut sensitivity.confidential_reads,
                )?;
                if let Some(predicate) = predicate {
                    collect_confidential_reads_in_expr(
                        predicate,
                        frontend,
                        &mut sensitivity.confidential_reads,
                    )?;
                }
                record_sensitive_public_write(
                    *object_id,
                    control_sensitive
                        || expr_is_policy_sensitive(key, frontend, tainted)
                        || expr_is_policy_sensitive(value, frontend, tainted)
                        || predicate
                            .as_ref()
                            .is_some_and(|expr| expr_is_policy_sensitive(expr, frontend, tainted)),
                    frontend,
                    sensitivity,
                )?;
            }
            Statement::Return { value } => {
                if let Some(value) = value {
                    collect_confidential_reads_in_expr(
                        value,
                        frontend,
                        &mut sensitivity.confidential_reads,
                    )?;
                    sensitivity.return_sensitive |=
                        control_sensitive || expr_is_policy_sensitive(value, frontend, tainted);
                }
            }
        }
    }
    Ok(())
}

fn collect_confidential_reads_in_expr(
    expr: &Expr,
    frontend: &Frontend,
    reads: &mut BTreeSet<String>,
) -> Result<()> {
    match expr {
        Expr::Var(_) | Expr::Literal(_) => {}
        Expr::Unary { expr, .. } => collect_confidential_reads_in_expr(expr, frontend, reads)?,
        Expr::Binary { lhs, rhs, .. } => {
            collect_confidential_reads_in_expr(lhs, frontend, reads)?;
            collect_confidential_reads_in_expr(rhs, frontend, reads)?;
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            collect_confidential_reads_in_expr(cond, frontend, reads)?;
            collect_confidential_reads_in_expr(when_true, frontend, reads)?;
            collect_confidential_reads_in_expr(when_false, frontend, reads)?;
        }
        Expr::CellGet { object_id } => record_confidential_read(*object_id, frontend, reads)?,
        Expr::ArrayGet { object_id, index } => {
            record_confidential_read(*object_id, frontend, reads)?;
            collect_confidential_reads_in_expr(index, frontend, reads)?;
        }
        Expr::MapGet { object_id, key } => {
            record_confidential_read(*object_id, frontend, reads)?;
            collect_confidential_reads_in_expr(key, frontend, reads)?;
        }
        Expr::StructField { base, .. } => {
            collect_confidential_reads_in_expr(base, frontend, reads)?;
        }
        Expr::ArrayIndex { base, index } => {
            collect_confidential_reads_in_expr(base, frontend, reads)?;
            collect_confidential_reads_in_expr(index, frontend, reads)?;
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                collect_confidential_reads_in_expr(part, frontend, reads)?;
            }
        }
    }
    Ok(())
}

fn record_confidential_read(
    object_id: u32,
    frontend: &Frontend,
    reads: &mut BTreeSet<String>,
) -> Result<()> {
    let object = state_object_by_id(frontend, object_id)?;
    if object.confidential {
        reads.insert(object.name.clone());
    }
    Ok(())
}

fn record_sensitive_public_write(
    object_id: u32,
    is_sensitive: bool,
    frontend: &Frontend,
    sensitivity: &mut PolicySensitivity,
) -> Result<()> {
    if !is_sensitive {
        return Ok(());
    }
    let object = state_object_by_id(frontend, object_id)?;
    if !object.confidential {
        sensitivity
            .sensitive_public_writes
            .insert(object.name.clone());
    }
    Ok(())
}

fn set_taint(name: &str, is_tainted: bool, tainted: &mut BTreeSet<String>) {
    if is_tainted {
        tainted.insert(name.to_string());
    } else {
        tainted.remove(name);
    }
}

fn mark_assigned_locals(statements: &[Statement], tainted: &mut BTreeSet<String>) {
    for statement in statements {
        match statement {
            Statement::Declare { name, .. } | Statement::Assign { name, .. } => {
                tainted.insert(name.clone());
            }
            Statement::If {
                then_body,
                else_body,
                ..
            } => {
                mark_assigned_locals(then_body, tainted);
                mark_assigned_locals(else_body, tainted);
            }
            Statement::For { body, .. } => mark_assigned_locals(body, tainted),
            Statement::Require { .. }
            | Statement::AbortIf { .. }
            | Statement::CellSet { .. }
            | Statement::ArraySet { .. }
            | Statement::MapPut { .. }
            | Statement::Return { .. } => {}
        }
    }
}

fn expr_is_policy_sensitive(expr: &Expr, frontend: &Frontend, tainted: &BTreeSet<String>) -> bool {
    match expr {
        Expr::Var(name) => tainted.contains(name),
        Expr::Unary { expr, .. } => expr_is_policy_sensitive(expr, frontend, tainted),
        Expr::Binary { lhs, rhs, .. } => {
            expr_is_policy_sensitive(lhs, frontend, tainted)
                || expr_is_policy_sensitive(rhs, frontend, tainted)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            expr_is_policy_sensitive(cond, frontend, tainted)
                || expr_is_policy_sensitive(when_true, frontend, tainted)
                || expr_is_policy_sensitive(when_false, frontend, tainted)
        }
        Expr::CellGet { object_id } => state_object_by_id(frontend, *object_id)
            .map(|object| object.confidential)
            .unwrap_or(true),
        Expr::ArrayGet { object_id, index } => {
            state_object_by_id(frontend, *object_id)
                .map(|object| object.confidential)
                .unwrap_or(true)
                || expr_is_policy_sensitive(index, frontend, tainted)
        }
        Expr::MapGet { object_id, key } => {
            state_object_by_id(frontend, *object_id)
                .map(|object| object.confidential)
                .unwrap_or(true)
                || expr_is_policy_sensitive(key, frontend, tainted)
        }
        Expr::StructField { base, .. } => expr_is_policy_sensitive(base, frontend, tainted),
        Expr::ArrayIndex { base, index } => {
            expr_is_policy_sensitive(base, frontend, tainted)
                || expr_is_policy_sensitive(index, frontend, tainted)
        }
        Expr::Keccak256 { parts } => parts
            .iter()
            .any(|part| expr_is_policy_sensitive(part, frontend, tainted)),
        Expr::Literal(_) => false,
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
            value: gate_expr(
                predicate,
                value.clone(),
                Expr::Literal(Value::zero_for_type(ty)),
            ),
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
            let start = const_expr_usize(start)?;
            let end = const_expr_usize(end)?;
            let mut out = Vec::new();
            for index in start..end {
                let substituted =
                    substitute_block(body, index_var, &Expr::Literal(Value::uint(index)))?;
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

fn substitute_block(
    statements: &[Statement],
    name: &str,
    replacement: &Expr,
) -> Result<Vec<Statement>> {
    statements
        .iter()
        .map(|statement| substitute_statement(statement, name, replacement))
        .collect()
}

fn substitute_statement(
    statement: &Statement,
    name: &str,
    replacement: &Expr,
) -> Result<Statement> {
    Ok(match statement {
        Statement::Declare {
            name: var,
            ty,
            value,
        } => Statement::Declare {
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

fn const_expr_usize(expr: &Expr) -> Result<usize> {
    match expr {
        Expr::Literal(Value::Uint(value)) => value
            .checked_to_usize()
            .ok_or_else(|| anyhow!("loop bound exceeds host usize range")),
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

fn validate_entrypoint_metadata_well_formed(
    signature: &str,
    entry_meta: &uo_core::EntrypointMetadata,
    state_by_name: &BTreeMap<String, StateObject>,
) -> Result<()> {
    match entry_meta.confidential {
        Some(false) if !entry_meta.secret_args.is_empty() => bail!(
            "entrypoint {} declares confidential: false but also declares secret_args",
            signature
        ),
        _ => {}
    }
    let mut seen_secret_args = BTreeSet::new();
    for secret in &entry_meta.secret_args {
        if !seen_secret_args.insert(secret) {
            bail!(
                "entrypoint {} repeats secret_args entry {}",
                signature,
                secret
            );
        }
    }
    let mut seen_declassifies = BTreeSet::new();
    for declassify in &entry_meta.declassifies {
        if !seen_declassifies.insert(declassify) {
            bail!(
                "entrypoint {} repeats declassifies entry {:?}",
                signature,
                declassify
            );
        }
    }
    let mut seen = BTreeSet::new();
    for object_name in &entry_meta.public_state_declassifies {
        if !seen.insert(object_name) {
            bail!(
                "entrypoint {} repeats public_state_declassifies target {}",
                signature,
                object_name
            );
        }
        let object = state_by_name.get(object_name).ok_or_else(|| {
            anyhow!(
                "entrypoint {} public_state_declassifies unknown state object {}",
                signature,
                object_name
            )
        })?;
        if object.confidential {
            bail!(
                "entrypoint {} public_state_declassifies target {} is confidential; only public state can be declassified this way",
                signature,
                object_name
            );
        }
    }
    Ok(())
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
    function.attributes.iter().any(|attribute| {
        matches!(
            attribute,
            pt::FunctionAttribute::Visibility(pt::Visibility::Internal(_))
                | pt::FunctionAttribute::Visibility(pt::Visibility::Private(_))
        )
    })
}

fn is_pure_or_view(function: &pt::FunctionDefinition) -> bool {
    function.attributes.iter().any(|attribute| {
        matches!(
            attribute,
            pt::FunctionAttribute::Mutability(pt::Mutability::Pure(_))
                | pt::FunctionAttribute::Mutability(pt::Mutability::View(_))
        )
    })
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
            param
                .as_ref()
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
                format!(
                    "mapping({}=>{})",
                    type_expr_name(key),
                    type_expr_name(value)
                )
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
            body.iter()
                .map(render_statement)
                .collect::<Vec<_>>()
                .join("; ")
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
            value
                .as_ref()
                .map(render_expr)
                .unwrap_or_else(|| "()".into())
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
        Expr::ArrayIndex { base, index } => {
            format!("{}[{}]", render_expr(base), render_expr(index))
        }
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
    use uo_core::{ContractMetadata, Expr, ProgramMode, Statement, Uint256, Value};

    fn write_temp(name: &str, contents: &str) -> PathBuf {
        let path = PathBuf::from(format!(
            "/tmp/uo-solc-test-{}-{}.sol",
            name,
            std::process::id()
        ));
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
entrypoints:
  f(uint256):
    confidential: false
    returns: forbidden
    status: public
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
    fn rejects_missing_entrypoint_metadata() {
        let source = write_temp(
            "missing-entrypoint-metadata",
            r#"
            contract C {
                uint256 private x;
                function f(uint256 a) public { x = a; }
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
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f(uint256) is missing explicit metadata"));
    }

    #[test]
    fn rejects_unknown_entrypoint_metadata() {
        let source = write_temp(
            "unknown-entrypoint-metadata",
            r#"
            contract C {
                uint256 private x;
                function f(uint256 a) public { x = a; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  g(uint256):
    confidential: false
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
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("metadata references unknown entrypoint g(uint256)"));
    }

    #[test]
    fn rejects_unsupported_top_level_source_parts() {
        let source = write_temp(
            "top-level-import",
            r#"
            import "./Other.sol";
            contract C {
                uint256 private x;
                function f(uint256 a) public { x = a; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    confidential: false
    returns: forbidden
    status: public
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
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("top-level imports are unsupported"));
    }

    #[test]
    fn rejects_integer_widths_other_than_uint256() {
        let source = write_temp(
            "uint64",
            r#"
            contract C {
                uint64 private x;
                function f(uint64 a) public { x = a; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint64):
    confidential: false
    returns: forbidden
    status: public
state:
  x:
    kind: cell
    value: uint64
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("only uint256 is supported in proof-grade mode"));
    }

    #[test]
    fn accepts_full_width_uint256_decimal_and_hex_literals() {
        let max_decimal =
            "115792089237316195423570985008687907853269984665640564039457584007913129639935";
        let source = write_temp(
            "uint256-max-literals",
            &format!(
                r#"
            contract C {{
                uint256 private x;
                function dec() public {{ x = {max_decimal}; }}
                function hexed() public {{ x = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; }}
            }}
            "#
            ),
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  dec():
    confidential: false
    returns: forbidden
    status: public
  hexed():
    confidential: false
    returns: forbidden
    status: public
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
        let artifact = compile(source.to_str().unwrap(), &meta, ProgramMode::Raw).unwrap();
        for signature in ["dec()", "hexed()"] {
            let function = artifact
                .contract
                .functions
                .iter()
                .find(|function| function.signature == signature)
                .unwrap();
            assert!(matches!(
                function.body.as_slice(),
                [Statement::CellSet {
                    value: Expr::Literal(value),
                    ..
                }] if value == &Value::uint(Uint256::MAX)
            ));
        }
    }

    #[test]
    fn rejects_decimal_literals_above_uint256_max() {
        let overflow =
            "115792089237316195423570985008687907853269984665640564039457584007913129639936";
        let source = write_temp(
            "uint256-overflow-literal",
            &format!(
                r#"
            contract C {{
                uint256 private x;
                function f() public {{ x = {overflow}; }}
            }}
            "#
            ),
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
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
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Raw).unwrap_err();
        assert!(err
            .to_string()
            .contains("uint256 literal exceeds 2^256 - 1"));
    }

    #[test]
    fn rejects_array_capacity_that_differs_from_source_length() {
        let source = write_temp(
            "array-capacity-mismatch",
            r#"
            contract C {
                bytes32[4] private items;
                function f() public { }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
state:
  items:
    kind: array
    value: bytes32
    capacity: 8
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("metadata capacity 8 does not match source length 4"));
    }

    #[test]
    fn rejects_array_missing_metadata_capacity() {
        let source = write_temp(
            "array-missing-capacity",
            r#"
            contract C {
                bytes32[4] private items;
                function f() public { }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
state:
  items:
    kind: array
    value: bytes32
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("array state items is missing metadata capacity"));
    }

    #[test]
    fn rejects_metadata_type_mismatch() {
        let source = write_temp(
            "metadata-type-mismatch",
            r#"
            contract C {
                mapping(bytes32 => uint256) private balances;
                function f(bytes32 key, uint256 value) public { balances[key] = value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(bytes32,uint256):
    confidential: false
    returns: forbidden
    status: public
state:
  balances:
    kind: map
    key: address
    value: uint256
    capacity: 8
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("metadata key type address does not match source type bytes32"));
    }

    #[test]
    fn rejects_map_missing_capacity() {
        let source = write_temp(
            "map-missing-capacity",
            r#"
            contract C {
                mapping(bytes32 => uint256) private records;
                function f(bytes32 key, uint256 value) public { records[key] = value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(bytes32,uint256):
    confidential: false
    returns: forbidden
    status: public
state:
  records:
    kind: map
    key: bytes32
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("map state records is missing metadata capacity"));
    }

    #[test]
    fn rejects_map_zero_capacity() {
        let source = write_temp(
            "map-zero-capacity",
            r#"
            contract C {
                mapping(bytes32 => uint256) private records;
                function f(bytes32 key, uint256 value) public { records[key] = value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(bytes32,uint256):
    confidential: false
    returns: forbidden
    status: public
state:
  records:
    kind: map
    key: bytes32
    value: uint256
    capacity: 0
    backend: full_scan
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("map state records must have positive capacity"));
    }

    #[test]
    fn rejects_oram_scheme_on_non_oram_backend() {
        let source = write_temp(
            "non-oram-scheme",
            r#"
            contract C {
                uint256 private x;
                function f() public { }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    oram_scheme: path_oram_local_posmap_v1
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("non-ORAM state x must not declare oram_scheme"));
    }

    #[test]
    fn rejects_missing_return_policy() {
        let source = write_temp(
            "missing-return-policy",
            r#"
            contract C {
                uint256 private x;
                function f(uint256 a) public { x = a; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    confidential: false
    status: public
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
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f(uint256) is missing explicit returns policy"));
    }

    #[test]
    fn rejects_missing_entrypoint_confidential_policy() {
        let source = write_temp(
            "missing-entrypoint-confidential",
            r#"
            contract C {
                uint256 private x;
                function f(uint256 a) public { x = a; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    returns: forbidden
    status: public
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
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f(uint256) is missing explicit confidential policy"));
    }

    #[test]
    fn rejects_confidential_plaintext_return_without_declassification() {
        let source = write_temp(
            "confidential-public-return",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: public
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("confidential entrypoint f(uint256) returns a plaintext value"));
    }

    #[test]
    fn accepts_confidential_encrypted_return_without_plaintext_declassification() {
        let source = write_temp(
            "confidential-encrypted-return",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let artifact = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap();
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get("f(uint256)")
            .unwrap();
        assert_eq!(entry.returns, uo_core::ReturnPolicy::EncryptedToClient);
        assert!(!entry
            .declassifies
            .contains(&uo_core::DeclassificationKind::Return));
    }

    #[test]
    fn rejects_public_encrypted_return_policy() {
        let source = write_temp(
            "public-encrypted-return",
            r#"
            contract C {
                function f(uint256 value) public returns (uint256) { return value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    confidential: false
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("declares encrypted_to_client returns but is not confidential"));
    }

    #[test]
    fn rejects_encrypted_return_with_plaintext_declassification() {
        let source = write_temp(
            "encrypted-return-declassifies",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
    declassifies: [return]
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("must not declassify the plaintext return"));
    }

    #[test]
    fn rejects_secret_dependent_status_without_declassification() {
        let source = write_temp(
            "secret-status",
            r#"
            contract C {
                uint256 private balance;
                function f(uint256 amount) public { require(balance >= amount); }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [amount]
    confidential: true
    returns: forbidden
    status: public
state:
  balance:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("secret-dependent success/abort status"));
    }

    #[test]
    fn rejects_secret_dependent_control_status_without_declassification() {
        let source = write_temp(
            "secret-control-status",
            r#"
            contract C {
                function f(uint256 secret) public {
                    if (secret > 0) {
                        require(false);
                    }
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: forbidden
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("secret-dependent success/abort status"));
    }

    #[test]
    fn rejects_secret_control_assigned_status_without_declassification() {
        let source = write_temp(
            "secret-control-assigned-status",
            r#"
            contract C {
                function f(uint256 secret) public {
                    uint256 out = 0;
                    if (secret > 0) {
                        out = 1;
                    } else {
                        out = 2;
                    }
                    require(out == 0);
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: forbidden
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("secret-dependent success/abort status"));
    }

    #[test]
    fn rejects_secret_indexed_public_map_status_without_declassification() {
        let source = write_temp(
            "secret-public-map-index-status",
            r#"
            contract C {
                mapping(uint256 => uint256) private publicValues;
                function f(uint256 secret) public {
                    require(publicValues[secret] == 0);
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: forbidden
    status: public
state:
  publicValues:
    kind: map
    key: uint256
    value: uint256
    backend: raw
    confidential: false
    capacity: 8
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("secret-dependent success/abort status"));
    }

    #[test]
    fn rejects_public_getter_over_confidential_state_without_declassification() {
        let source = write_temp(
            "public-confidential-getter",
            r#"
            contract C {
                uint256 private x;
                function f() public returns (uint256) { return x; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: public
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() reads confidential state x"));
    }

    #[test]
    fn rejects_public_confidential_read_without_output_or_write() {
        let source = write_temp(
            "public-confidential-read-only",
            r#"
            contract C {
                uint256 private x;
                function f() public { uint256 shadow = x; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() reads confidential state x"));
    }

    #[test]
    fn rejects_secret_dependent_public_read_in_public_entrypoint() {
        let source = write_temp(
            "public-secret-dependent-public-read",
            r#"
            contract C {
                uint256 private secretCell;
                uint256 private publicCell;
                function f() public {
                    if (secretCell > 0) {
                        uint256 shadow = publicCell;
                    }
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
state:
  secretCell:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
  publicCell:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() reads confidential state secretCell"));
    }

    #[test]
    fn rejects_public_confidential_read_status() {
        let source = write_temp(
            "public-confidential-read-status",
            r#"
            contract C {
                uint256 private x;
                function f() public { require(x > 0); }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() reads confidential state x"));
    }

    #[test]
    fn rejects_secret_control_assigned_return_without_declassification() {
        let source = write_temp(
            "secret-control-assigned-return",
            r#"
            contract C {
                uint256 private x;
                function f() public returns (uint256) {
                    uint256 out = 0;
                    if (x > 0) {
                        out = 1;
                    } else {
                        out = 2;
                    }
                    return out;
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: public
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() reads confidential state x"));
    }

    #[test]
    fn rejects_secret_derived_public_state_write_without_declassification() {
        let source = write_temp(
            "public-state-leak",
            r#"
            contract C {
                uint256 private secretCell;
                uint256 private publicCell;
                function leak() public { publicCell = secretCell; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  leak():
    confidential: false
    returns: forbidden
    status: public
state:
  secretCell:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
  publicCell:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint leak() reads confidential state secretCell"));
    }

    #[test]
    fn rejects_unused_public_state_declassification_for_public_value() {
        let source = write_temp(
            "public-state-declassified-public-value",
            r#"
            contract C {
                uint256 private publicCell;
                function leak(uint256 value) public { publicCell = value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  leak(uint256):
    confidential: false
    returns: forbidden
    status: public
    public_state_declassifies: [publicCell]
state:
  publicCell:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err.to_string().contains(
            "declares public_state_declassifies for non-sensitive public state publicCell"
        ));
    }

    #[test]
    fn rejects_unused_success_declassification_label() {
        let source = write_temp(
            "unused-success-declassifies",
            r#"
            contract C {
                function f() public {}
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
    declassifies: [success]
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() declares unused declassifies label"));
    }

    #[test]
    fn rejects_declassified_public_return_without_sensitive_release() {
        let source = write_temp(
            "unused-return-declassifies",
            r#"
            contract C {
                function f(uint256 value) public returns (uint256) { return value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    confidential: false
    returns: declassified
    status: public
    declassifies: [return]
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("declares returns: declassified but the return is not secret-dependent"));
    }

    #[test]
    fn rejects_public_state_declassification_without_sensitive_write() {
        let source = write_temp(
            "unused-public-state-declassifies",
            r#"
            contract C {
                uint256 private publicCell;
                function f(uint256 value) public { publicCell = value; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    confidential: false
    returns: forbidden
    status: public
    public_state_declassifies: [publicCell]
state:
  publicCell:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err.to_string().contains(
            "declares public_state_declassifies for non-sensitive public state publicCell"
        ));
    }

    #[test]
    fn rejects_secret_dependent_public_write_predicate() {
        let source = write_temp(
            "public-write-predicate-leak",
            r#"
            contract C {
                uint256 private secretCell;
                uint256 private publicCell;
                function leak() public {
                    if (secretCell > 0) {
                        publicCell = 1;
                    }
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  leak():
    confidential: false
    returns: forbidden
    status: public
state:
  secretCell:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
  publicCell:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint leak() reads confidential state secretCell"));
    }

    #[test]
    fn rejects_confidential_false_with_secret_args() {
        let source = write_temp(
            "metadata-secret-public",
            r#"
            contract C {
                function f(uint256 secret) public {}
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: false
    returns: forbidden
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("declares confidential: false but also declares secret_args"));
    }

    #[test]
    fn rejects_duplicate_secret_args() {
        let source = write_temp(
            "metadata-duplicate-secret-args",
            r#"
            contract C {
                function f(uint256 secret) public {}
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret, secret]
    confidential: true
    returns: forbidden
    status: public
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f(uint256) repeats secret_args entry secret"));
    }

    #[test]
    fn rejects_duplicate_declassifies() {
        let source = write_temp(
            "metadata-duplicate-declassifies",
            r#"
            contract C {
                function f() public returns (uint256) { return 1; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: declassified
    status: public
    declassifies: [return, return]
state: {}
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("entrypoint f() repeats declassifies entry Return"));
    }

    #[test]
    fn accepts_confidential_true_without_secret_args_when_reading_confidential_state() {
        let source = write_temp(
            "metadata-confidential-no-secret",
            r#"
            contract C {
                uint256 private x;
                function f() public { uint256 shadow = x; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: true
    returns: forbidden
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let artifact = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap();
        let function = artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == "f()")
            .unwrap();
        assert!(function.confidential);
        assert!(function.secret_args.is_empty());
    }

    #[test]
    fn rejects_public_state_declassification_of_confidential_object() {
        let source = write_temp(
            "metadata-public-state-confidential",
            r#"
            contract C {
                uint256 private x;
                function f() public {}
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
    public_state_declassifies: [x]
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = validate_source(source.to_str().unwrap(), &meta).unwrap_err();
        assert!(err
            .to_string()
            .contains("public_state_declassifies target x is confidential"));
    }

    #[test]
    fn rejects_confidential_raw_state_in_uo_mode() {
        let source = write_temp(
            "confidential-raw-state",
            r#"
            contract C {
                uint256 private secretCell;
                function write(uint256 secret) public { secretCell = secret; }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  write(uint256):
    secret_args: [secret]
    confidential: true
    returns: forbidden
    status: public
state:
  secretCell:
    kind: cell
    value: uint256
    backend: raw
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("confidential state object secretCell uses raw backend"));
    }

    #[test]
    fn rejects_dynamic_public_loop_bounds_in_uo_mode() {
        let source = write_temp(
            "dynamic-public-loop",
            r#"
            contract C {
                uint256 private x;
                function fill(uint256 n) public {
                    for (uint256 i = 0; i < n; i++) {
                        x = i;
                    }
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: C
entrypoints:
  fill(uint256):
    confidential: false
    returns: forbidden
    status: public
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
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("loop loop_0 end bound must be compile-time exact"));
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
    returns: forbidden
    status: public
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

    #[test]
    fn rejects_confidential_entrypoint_targeting_public_raw_state() {
        let source = write_temp(
            "confidential-public-raw-target",
            r#"
            contract RawPublicTarget {
                uint256 private last;
                function classify(uint256 secret) public {
                    last = secret & 1;
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: RawPublicTarget
entrypoints:
  classify(uint256):
    secret_args: [secret]
    confidential: true
    returns: forbidden
    status: public
    public_state_declassifies: [last]
state:
  last:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err.to_string().contains("targets raw backend object last"));
    }

    #[test]
    fn rejects_confidential_entrypoint_targeting_non_confidential_uo_state() {
        let source = write_temp(
            "confidential-public-uo-target",
            r#"
            contract PublicUoTarget {
                uint256 private last;
                function classify(uint256 secret) public {
                    last = secret & 1;
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: PublicUoTarget
entrypoints:
  classify(uint256):
    secret_args: [secret]
    confidential: true
    returns: forbidden
    status: public
    public_state_declassifies: [last]
state:
  last:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: false
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("targets non-confidential state object last"));
    }

    #[test]
    fn rejects_dynamic_loop_oram_access_counts() {
        let source = write_temp(
            "oram-loop",
            r#"
            contract LoopOram {
                mapping(uint256 => uint256) private balances;

                function fill(uint256 n, uint256 value) public {
                    for (uint256 i = 0; i < n; i++) {
                        balances[i] = value;
                    }
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: LoopOram
entrypoints:
  fill(uint256,uint256):
    confidential: true
    secret_args: [value]
    returns: forbidden
    status: public
state:
  balances:
    kind: map
    key: uint256
    value: uint256
    capacity: 8
    backend: oram
    oram_scheme: path_oram_local_posmap_v1
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("loop loop_0 end bound must be compile-time exact"));
    }

    #[test]
    fn accepts_multi_access_path_oram_entrypoints() {
        let source = write_temp(
            "path-multi-access",
            r#"
            contract PathMultiAccess {
                mapping(bytes32 => uint256) private balances;

                function deposit(bytes32 key, uint256 value) public {
                    uint256 oldBalance = balances[key];
                    balances[key] = oldBalance + value;
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: PathMultiAccess
entrypoints:
  deposit(bytes32,uint256):
    confidential: true
    secret_args: [key, value]
    returns: forbidden
    status: public
state:
  balances:
    kind: map
    key: bytes32
    value: uint256
    capacity: 16
    backend: oram
    oram_scheme: path_oram_local_posmap_v1
    confidential: true
bounds:
  loops: {}
"#,
        );
        let artifact = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap();
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get("deposit(bytes32,uint256)")
            .unwrap();
        let object = artifact
            .contract
            .state
            .iter()
            .find(|object| object.name == "balances")
            .unwrap();
        assert_eq!(entry.oram_accesses.get(&object.id), Some(&2));
        assert_eq!(
            entry.max_commit_ops,
            uo_core::OramManifest::for_object(object)
                .unwrap()
                .total_commit_ops()
                * 2
        );
    }

    #[test]
    fn rejects_multi_access_surrogate_oram_entrypoints() {
        let source = write_temp(
            "surrogate-multi-access",
            r#"
            contract SurrogateMultiAccess {
                mapping(bytes32 => uint256) private balances;

                function deposit(bytes32 key, uint256 value) public {
                    uint256 oldBalance = balances[key];
                    balances[key] = oldBalance + value;
                }
            }
            "#,
        );
        let meta = parse_metadata(
            r#"
contract: SurrogateMultiAccess
entrypoints:
  deposit(bytes32,uint256):
    confidential: true
    secret_args: [key, value]
    returns: forbidden
    status: public
state:
  balances:
    kind: map
    key: bytes32
    value: uint256
    capacity: 16
    backend: oram
    oram_scheme: surrogate_public_schedule_v1
    confidential: true
bounds:
  loops: {}
"#,
        );
        let err = compile(source.to_str().unwrap(), &meta, ProgramMode::Uo).unwrap_err();
        assert!(err
            .to_string()
            .contains("only supports one access per entrypoint"));
    }

    #[test]
    fn uo_manifest_embeds_kernel_step_trace() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
        let source = root.join("benches/raw/FixedSlotClassifier.sol");
        let metadata: ContractMetadata = serde_yaml::from_str(
            &fs::read_to_string(root.join("benches/raw/FixedSlotClassifier.uo.yaml")).unwrap(),
        )
        .unwrap();
        let artifact = compile(source.to_str().unwrap(), &metadata, ProgramMode::Uo).unwrap();
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get("classify(uint256)")
            .unwrap();
        assert_eq!(
            entry.kernel_steps.first().and_then(|step| step.object_id),
            None
        );
        assert_eq!(
            entry.kernel_steps.last().and_then(|step| step.object_id),
            None
        );
    }

    #[test]
    fn raw_manifest_counts_bounded_loop_accesses_exactly() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
        let source = root.join("benches/raw/AuthScan.sol");
        let metadata: ContractMetadata = serde_yaml::from_str(
            &fs::read_to_string(root.join("benches/raw/AuthScan.raw.yaml")).unwrap(),
        )
        .unwrap();
        let artifact = compile(source.to_str().unwrap(), &metadata, ProgramMode::Raw).unwrap();
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get("auth(bytes32)")
            .unwrap();
        assert_eq!(entry.uoarray_reads, 4);
        assert_eq!(entry.uocell_writes, 1);
        assert_eq!(entry.max_commit_ops, 5);
    }
}
