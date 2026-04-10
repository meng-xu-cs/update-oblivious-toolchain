use anyhow::{bail, Result};
use std::collections::BTreeSet;
use uo_core::ir::{Expr, Statement};
use uo_core::{CompiledArtifact, ContractMetadata, ProgramMode};

pub fn check_source(source_path: &str, metadata: &ContractMetadata) -> Result<Vec<String>> {
    let report = uo_solc::validate_source(source_path, metadata)?;
    let mut lines = Vec::new();
    lines.push(format!("validated contract {}", report.contract_name));
    lines.push(format!("entrypoints: {}", report.entrypoints.join(", ")));
    if report.diagnostics.is_empty() {
        lines.push("diagnostics: none".into());
    } else {
        lines.push(format!("diagnostics: {}", report.diagnostics.join(" | ")));
    }
    Ok(lines)
}

pub fn check_artifact(artifact: &CompiledArtifact) -> Result<Vec<String>> {
    let mut report = Vec::new();
    report.push(format!(
        "artifact contract {} mode {:?}",
        artifact.contract.contract, artifact.contract.mode
    ));
    if artifact.contract.mode == ProgramMode::Uo {
        for object in &artifact.contract.state {
            if object.confidential && object.backend == uo_core::BackendKind::Raw {
                bail!("confidential object {} uses raw backend", object.name);
            }
        }
        for function in &artifact.contract.functions {
            if function.confidential {
                forbid_control_flow(&function.body, &function.signature)?;
            }
        }
    }
    for function in &artifact.contract.functions {
        if !artifact
            .contract
            .manifest
            .entrypoints
            .contains_key(&function.signature)
        {
            bail!("manifest is missing entrypoint {}", function.signature);
        }
    }
    let mut object_ids = BTreeSet::new();
    for object in &artifact.contract.state {
        if !object_ids.insert(object.id) {
            bail!("duplicate object id {}", object.id);
        }
    }
    report.push("manifest/object consistency: ok".into());
    report.push("forbidden control flow in confidential IR: none".into());
    report.push("raw storage backend for confidential objects: none".into());
    Ok(report)
}

fn forbid_control_flow(statements: &[Statement], signature: &str) -> Result<()> {
    for statement in statements {
        match statement {
            Statement::If { .. } | Statement::For { .. } => {
                bail!("confidential entrypoint {} still contains control flow", signature)
            }
            Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
                forbid_raw_expr(value, signature)?
            }
            Statement::Require { cond } | Statement::AbortIf { cond } => {
                forbid_raw_expr(cond, signature)?
            }
            Statement::CellSet {
                value, predicate, ..
            } => {
                forbid_raw_expr(value, signature)?;
                if let Some(predicate) = predicate {
                    forbid_raw_expr(predicate, signature)?;
                }
            }
            Statement::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                forbid_raw_expr(index, signature)?;
                forbid_raw_expr(value, signature)?;
                if let Some(predicate) = predicate {
                    forbid_raw_expr(predicate, signature)?;
                }
            }
            Statement::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                forbid_raw_expr(key, signature)?;
                forbid_raw_expr(value, signature)?;
                if let Some(predicate) = predicate {
                    forbid_raw_expr(predicate, signature)?;
                }
            }
            Statement::Return { value } => {
                if let Some(value) = value {
                    forbid_raw_expr(value, signature)?;
                }
            }
        }
    }
    Ok(())
}

fn forbid_raw_expr(expr: &Expr, signature: &str) -> Result<()> {
    match expr {
        Expr::Unary { expr, .. } => forbid_raw_expr(expr, signature),
        Expr::Binary { lhs, rhs, .. } => {
            forbid_raw_expr(lhs, signature)?;
            forbid_raw_expr(rhs, signature)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            forbid_raw_expr(cond, signature)?;
            forbid_raw_expr(when_true, signature)?;
            forbid_raw_expr(when_false, signature)
        }
        Expr::StructField { base, .. } => forbid_raw_expr(base, signature),
        Expr::ArrayIndex { base, index } => {
            forbid_raw_expr(base, signature)?;
            forbid_raw_expr(index, signature)
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                forbid_raw_expr(part, signature)?;
            }
            Ok(())
        }
        Expr::Literal(_)
        | Expr::Var(_)
        | Expr::CellGet { .. }
        | Expr::ArrayGet { .. }
        | Expr::MapGet { .. } => Ok(()),
    }
}
