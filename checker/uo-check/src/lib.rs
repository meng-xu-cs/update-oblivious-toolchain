use anyhow::{bail, Result};
use std::collections::{BTreeMap, BTreeSet};
use uo_core::ir::{BackendKind, Expr, StateObject, Statement};
use uo_core::{CompiledArtifact, ContractMetadata, OramManifest, ProgramMode};

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
    let mut manifest_ids = BTreeSet::new();
    for object in &artifact.contract.manifest.objects {
        if !manifest_ids.insert(object.id) {
            bail!("duplicate manifest object id {}", object.id);
        }
    }
    for object in &artifact.contract.state {
        let manifest_object = artifact
            .contract
            .manifest
            .objects
            .iter()
            .find(|candidate| candidate.id == object.id)
            .ok_or_else(|| anyhow::anyhow!("manifest is missing object {}", object.name))?;
        if object.backend == BackendKind::Oram {
            let expected = OramManifest::for_object(object)?;
            let actual = manifest_object.oram.as_ref().ok_or_else(|| {
                anyhow::anyhow!("manifest is missing ORAM parameters for {}", object.name)
            })?;
            if actual != &expected {
                bail!("manifest ORAM parameters mismatch for {}", object.name);
            }
        } else if manifest_object.oram.is_some() {
            bail!(
                "non-ORAM object {} unexpectedly carries ORAM parameters",
                object.name
            );
        }
    }
    for function in &artifact.contract.functions {
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get(&function.signature)
            .ok_or_else(|| {
                anyhow::anyhow!("manifest is missing entrypoint {}", function.signature)
            })?;
        let expected_accesses = count_oram_accesses(&function.body, &artifact.contract.state)?;
        if entry.oram_accesses != expected_accesses {
            bail!(
                "manifest ORAM access counts mismatch for entrypoint {}",
                function.signature
            );
        }
    }
    report.push("manifest/object consistency: ok".into());
    report.push("forbidden control flow in confidential IR: none".into());
    report.push("raw storage backend for confidential objects: none".into());
    Ok(report)
}

fn count_oram_accesses(
    statements: &[Statement],
    state: &[StateObject],
) -> Result<BTreeMap<u32, usize>> {
    let mut counts = BTreeMap::new();
    for statement in statements {
        collect_oram_statement_accesses(statement, state, &mut counts)?;
    }
    Ok(counts)
}

fn collect_oram_statement_accesses(
    statement: &Statement,
    state: &[StateObject],
    counts: &mut BTreeMap<u32, usize>,
) -> Result<()> {
    match statement {
        Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
            collect_oram_expr_accesses(value, state, counts)
        }
        Statement::Require { cond } | Statement::AbortIf { cond } => {
            collect_oram_expr_accesses(cond, state, counts)
        }
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            collect_oram_expr_accesses(cond, state, counts)?;
            for stmt in then_body {
                collect_oram_statement_accesses(stmt, state, counts)?;
            }
            for stmt in else_body {
                collect_oram_statement_accesses(stmt, state, counts)?;
            }
            Ok(())
        }
        Statement::For {
            start, end, body, ..
        } => {
            collect_oram_expr_accesses(start, state, counts)?;
            collect_oram_expr_accesses(end, state, counts)?;
            for stmt in body {
                collect_oram_statement_accesses(stmt, state, counts)?;
            }
            Ok(())
        }
        Statement::CellSet {
            value, predicate, ..
        } => {
            collect_oram_expr_accesses(value, state, counts)?;
            if let Some(predicate) = predicate {
                collect_oram_expr_accesses(predicate, state, counts)?;
            }
            Ok(())
        }
        Statement::ArraySet {
            index,
            value,
            predicate,
            ..
        } => {
            collect_oram_expr_accesses(index, state, counts)?;
            collect_oram_expr_accesses(value, state, counts)?;
            if let Some(predicate) = predicate {
                collect_oram_expr_accesses(predicate, state, counts)?;
            }
            Ok(())
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            record_oram_access(*object_id, state, counts)?;
            collect_oram_expr_accesses(key, state, counts)?;
            collect_oram_expr_accesses(value, state, counts)?;
            if let Some(predicate) = predicate {
                collect_oram_expr_accesses(predicate, state, counts)?;
            }
            Ok(())
        }
        Statement::Return { value } => {
            if let Some(value) = value {
                collect_oram_expr_accesses(value, state, counts)?;
            }
            Ok(())
        }
    }
}

fn collect_oram_expr_accesses(
    expr: &Expr,
    state: &[StateObject],
    counts: &mut BTreeMap<u32, usize>,
) -> Result<()> {
    match expr {
        Expr::Unary { expr, .. } => collect_oram_expr_accesses(expr, state, counts),
        Expr::Binary { lhs, rhs, .. } => {
            collect_oram_expr_accesses(lhs, state, counts)?;
            collect_oram_expr_accesses(rhs, state, counts)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            collect_oram_expr_accesses(cond, state, counts)?;
            collect_oram_expr_accesses(when_true, state, counts)?;
            collect_oram_expr_accesses(when_false, state, counts)
        }
        Expr::ArrayGet { index, .. } => collect_oram_expr_accesses(index, state, counts),
        Expr::MapGet { object_id, key } => {
            record_oram_access(*object_id, state, counts)?;
            collect_oram_expr_accesses(key, state, counts)
        }
        Expr::StructField { base, .. } => collect_oram_expr_accesses(base, state, counts),
        Expr::ArrayIndex { base, index } => {
            collect_oram_expr_accesses(base, state, counts)?;
            collect_oram_expr_accesses(index, state, counts)
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                collect_oram_expr_accesses(part, state, counts)?;
            }
            Ok(())
        }
        Expr::Literal(_) | Expr::Var(_) | Expr::CellGet { .. } => Ok(()),
    }
}

fn record_oram_access(
    object_id: u32,
    state: &[StateObject],
    counts: &mut BTreeMap<u32, usize>,
) -> Result<()> {
    if state_object_by_id(state, object_id)?.backend == BackendKind::Oram {
        *counts.entry(object_id).or_default() += 1;
    }
    Ok(())
}

fn state_object_by_id(state: &[StateObject], object_id: u32) -> Result<&StateObject> {
    state
        .iter()
        .find(|object| object.id == object_id)
        .ok_or_else(|| anyhow::anyhow!("unknown object id {}", object_id))
}

fn forbid_control_flow(statements: &[Statement], signature: &str) -> Result<()> {
    for statement in statements {
        match statement {
            Statement::If { .. } | Statement::For { .. } => {
                bail!(
                    "confidential entrypoint {} still contains control flow",
                    signature
                )
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
