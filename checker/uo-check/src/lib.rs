use anyhow::{bail, Result};
use std::collections::{BTreeMap, BTreeSet};
use uo_core::ir::{
    BackendKind, CompiledFunction, ContainerKind, Expr, ProgramMode, StateObject, Statement,
};
use uo_core::manifest::{EntrypointManifest, PATH_ORAM_SCHEME};
use uo_core::{
    lower_confidential_kernel_statements, CompiledArtifact, ContractMetadata, DeclassificationKind,
    OramManifest, ProofRelevantTranslationBundle, ReturnPolicy, StateObjectManifest, StatusPolicy,
    Type, Uint256,
};

#[cfg(test)]
use uo_core::lower_confidential_kernel_expr;

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
    let admitted_package = artifact
        .admitted_package
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("artifact is missing admitted package identity"))?;
    if admitted_package.compiler_version != artifact.compiler_version {
        bail!(
            "admitted package compiler_version mismatch: {} != {}",
            admitted_package.compiler_version,
            artifact.compiler_version
        );
    }
    admitted_package.validate_current_toolchain()?;
    if artifact.contract.manifest.contract != artifact.contract.contract {
        bail!(
            "manifest contract mismatch: {} != {}",
            artifact.contract.manifest.contract,
            artifact.contract.contract
        );
    }
    let expected_mode = manifest_mode(&artifact.contract.mode);
    if artifact.contract.manifest.compilation_mode != expected_mode {
        bail!(
            "manifest compilation_mode mismatch: {} != {}",
            artifact.contract.manifest.compilation_mode,
            expected_mode
        );
    }
    if admitted_package.compilation_mode != expected_mode {
        bail!(
            "admitted package compilation_mode mismatch: {} != {}",
            admitted_package.compilation_mode,
            expected_mode
        );
    }
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
    if artifact.contract.manifest.entrypoints.len() != artifact.contract.functions.len() {
        bail!(
            "manifest entrypoint count mismatch: {} != {}",
            artifact.contract.manifest.entrypoints.len(),
            artifact.contract.functions.len()
        );
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
        let expected = expected_state_object_manifest(object)?;
        if manifest_object != &expected {
            bail!("manifest object mismatch for {}", object.name);
        }
    }
    if manifest_ids != object_ids {
        bail!("manifest object id set does not match contract state object ids");
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
        if entry.secret_args != function.secret_args {
            bail!(
                "manifest secret_args mismatch for entrypoint {}",
                function.signature
            );
        }
        let expected_param_names = function
            .params
            .iter()
            .map(|(name, _)| name.as_str())
            .collect::<Vec<_>>();
        let witnessed_param_names = entry
            .param_names
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>();
        if witnessed_param_names != expected_param_names {
            bail!(
                "manifest param_names mismatch for entrypoint {}",
                function.signature
            );
        }
        let expected_entry_input_len = function
            .params
            .iter()
            .map(|(_, ty)| ty.canonical_len())
            .sum::<usize>();
        if entry.entry_input_len != expected_entry_input_len {
            bail!(
                "manifest entry_input_len mismatch for entrypoint {}: {} != {}",
                function.signature,
                entry.entry_input_len,
                expected_entry_input_len
            );
        }
        let expected_return_canonical_len = function.return_type.as_ref().map(Type::canonical_len);
        if entry.return_canonical_len != expected_return_canonical_len {
            bail!(
                "manifest return_canonical_len mismatch for entrypoint {}: {:?} != {:?}",
                function.signature,
                entry.return_canonical_len,
                expected_return_canonical_len
            );
        }
        validate_manifest_release_policy(function, entry, &artifact.contract.state)?;
        let counts = count_body(&function.body);
        if entry.arena_bytes != 4096 + counts.local_count * 64 {
            bail!(
                "manifest arena_bytes mismatch for entrypoint {}: {} != {}",
                function.signature,
                entry.arena_bytes,
                4096 + counts.local_count * 64
            );
        }
        if entry.max_stack_words != 64 + counts.local_count {
            bail!(
                "manifest max_stack_words mismatch for entrypoint {}: {} != {}",
                function.signature,
                entry.max_stack_words,
                64 + counts.local_count
            );
        }
        let expected_max_hash_part_bytes = if function.confidential {
            function
                .confidential_kernel_program()?
                .max_keccak_part_canonical_len_for_state(&artifact.contract.state)?
        } else {
            0
        };
        if entry.max_hash_part_bytes != expected_max_hash_part_bytes {
            bail!(
                "manifest max_hash_part_bytes mismatch for entrypoint {}: {} != {}",
                function.signature,
                entry.max_hash_part_bytes,
                expected_max_hash_part_bytes
            );
        }
        let expected_kernel_steps = if function.confidential {
            let expected_program = function.confidential_kernel_program()?;
            let witnessed_program = entry.confidential_program.as_ref().ok_or_else(|| {
                anyhow::anyhow!(
                    "manifest confidential_program missing for entrypoint {}",
                    function.signature
                )
            })?;
            if witnessed_program != &expected_program {
                bail!(
                    "manifest confidential_program mismatch for entrypoint {}",
                    function.signature
                );
            }
            let expected_slot_program = expected_program.to_slot_program()?;
            let witnessed_slot_program =
                entry.confidential_slot_program.as_ref().ok_or_else(|| {
                    anyhow::anyhow!(
                        "manifest confidential_slot_program missing for entrypoint {}",
                        function.signature
                    )
                })?;
            if witnessed_slot_program != &expected_slot_program {
                bail!(
                    "manifest confidential_slot_program mismatch for entrypoint {}",
                    function.signature
                );
            }
            witnessed_slot_program
                .expected_runtime_step_manifest()
                .into_vec()
        } else {
            if entry.confidential_program.is_some() {
                bail!(
                    "non-confidential entrypoint {} unexpectedly carries confidential_program",
                    function.signature
                );
            }
            if entry.confidential_slot_program.is_some() {
                bail!(
                    "non-confidential entrypoint {} unexpectedly carries confidential_slot_program",
                    function.signature
                );
            }
            Vec::new()
        };
        if entry.kernel_steps != expected_kernel_steps {
            bail!(
                "manifest kernel_steps mismatch for entrypoint {}",
                function.signature
            );
        }
        assert_entry_count_eq(
            &function.signature,
            "uocell_reads",
            entry.uocell_reads,
            counts.cell_reads,
        )?;
        assert_entry_count_eq(
            &function.signature,
            "uocell_writes",
            entry.uocell_writes,
            counts.cell_writes,
        )?;
        assert_entry_count_eq(
            &function.signature,
            "uoarray_reads",
            entry.uoarray_reads,
            counts.array_reads,
        )?;
        assert_entry_count_eq(
            &function.signature,
            "uoarray_writes",
            entry.uoarray_writes,
            counts.array_writes,
        )?;
        assert_entry_count_eq(
            &function.signature,
            "uomap_reads",
            entry.uomap_reads,
            counts.map_reads,
        )?;
        assert_entry_count_eq(
            &function.signature,
            "uomap_writes",
            entry.uomap_writes,
            counts.map_writes,
        )?;
        let expected_accesses = count_oram_accesses(&function.body, &artifact.contract.state)?;
        if entry.oram_accesses != expected_accesses {
            bail!(
                "manifest ORAM access counts mismatch for entrypoint {}",
                function.signature
            );
        }
        validate_oram_access_shape(
            &function.signature,
            &expected_accesses,
            &artifact.contract.state,
        )?;
        let expected_max_commit_ops =
            expected_commit_ops(&function.body, &expected_accesses, &artifact.contract.state)?;
        if entry.max_commit_ops != expected_max_commit_ops {
            bail!(
                "manifest max_commit_ops mismatch for entrypoint {}: {} != {}",
                function.signature,
                entry.max_commit_ops,
                expected_max_commit_ops
            );
        }
    }
    report.push("admitted package identity/toolchain binding: ok".into());
    report.push("manifest/object exactness: ok".into());
    report.push("manifest/entrypoint exactness: ok".into());
    report.push("forbidden control flow in confidential IR: none".into());
    report.push("raw storage backend for confidential objects: none".into());
    Ok(report)
}

pub fn check_artifact_against_source(
    source_path: &str,
    metadata: &ContractMetadata,
    artifact: &CompiledArtifact,
) -> Result<Vec<String>> {
    check_artifact_against_source_impl(source_path, metadata, None, artifact)
}

pub fn check_artifact_against_source_with_metadata_bytes(
    source_path: &str,
    metadata: &ContractMetadata,
    raw_metadata: &[u8],
    artifact: &CompiledArtifact,
) -> Result<Vec<String>> {
    check_artifact_against_source_impl(source_path, metadata, Some(raw_metadata), artifact)
}

fn check_artifact_against_source_impl(
    source_path: &str,
    metadata: &ContractMetadata,
    raw_metadata: Option<&[u8]>,
    artifact: &CompiledArtifact,
) -> Result<Vec<String>> {
    let mut report = check_artifact(artifact)?;
    let expected = match raw_metadata {
        Some(raw_metadata) => uo_solc::compile_with_metadata_bytes(
            source_path,
            metadata,
            raw_metadata,
            artifact.contract.mode.clone(),
        )?,
        None => uo_solc::compile(source_path, metadata, artifact.contract.mode.clone())?,
    };
    assert_translation_equivalence(&expected, artifact)?;
    report.push("source/artifact translation validation: ok".into());
    Ok(report)
}

pub fn translation_validation_bundle_against_source(
    source_path: &str,
    metadata: &ContractMetadata,
    artifact: &CompiledArtifact,
) -> Result<ProofRelevantTranslationBundle> {
    uo_solc::translation_validation_bundle_against_artifact(source_path, metadata, artifact)
}

pub fn translation_validation_bundle_against_source_with_metadata_bytes(
    source_path: &str,
    metadata: &ContractMetadata,
    raw_metadata: &[u8],
    artifact: &CompiledArtifact,
) -> Result<ProofRelevantTranslationBundle> {
    uo_solc::translation_validation_bundle_against_artifact_with_metadata_bytes(
        source_path,
        metadata,
        raw_metadata,
        artifact,
    )
}

fn manifest_mode(mode: &ProgramMode) -> &'static str {
    match mode {
        ProgramMode::Raw => "raw",
        ProgramMode::Uo => "uo",
    }
}

fn expected_state_object_manifest(object: &StateObject) -> Result<StateObjectManifest> {
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
        key_type: object.key_type.as_ref().map(uo_core::Type::short_name),
        oram: if object.backend == BackendKind::Oram {
            Some(OramManifest::for_object(object)?)
        } else {
            None
        },
    })
}

fn assert_entry_count_eq(
    signature: &str,
    field: &str,
    actual: usize,
    expected: usize,
) -> Result<()> {
    if actual != expected {
        bail!(
            "manifest {} mismatch for entrypoint {}: {} != {}",
            field,
            signature,
            actual,
            expected
        );
    }
    Ok(())
}

fn assert_translation_equivalence(
    expected: &CompiledArtifact,
    actual: &CompiledArtifact,
) -> Result<()> {
    if actual.contract.contract != expected.contract.contract {
        bail!(
            "source/artifact contract mismatch: {} != {}",
            actual.contract.contract,
            expected.contract.contract
        );
    }
    if actual.contract.mode != expected.contract.mode {
        bail!(
            "source/artifact mode mismatch: {:?} != {:?}",
            actual.contract.mode,
            expected.contract.mode
        );
    }
    if actual.contract.state != expected.contract.state {
        bail!("source/artifact state mismatch");
    }
    if actual.contract.functions != expected.contract.functions {
        bail!("source/artifact function mismatch");
    }
    if actual.contract.manifest != expected.contract.manifest {
        bail!("source/artifact manifest mismatch");
    }
    if actual.admitted_package != expected.admitted_package {
        bail!("source/artifact admitted package identity mismatch");
    }
    if actual.admitted_package.is_none() {
        bail!("source/artifact admitted package identity is missing");
    }
    Ok(())
}

#[derive(Default)]
struct ArtifactPolicySensitivity {
    return_sensitive: bool,
    status_sensitive: bool,
    sensitive_public_writes: BTreeSet<String>,
}

fn validate_manifest_release_policy(
    function: &CompiledFunction,
    entry: &EntrypointManifest,
    state: &[StateObject],
) -> Result<()> {
    let sensitivity = artifact_policy_sensitivity(function, state)?;
    if entry.returns == ReturnPolicy::Public && sensitivity.return_sensitive {
        bail!(
            "manifest return policy mismatch for entrypoint {}: sensitive return requires declassification",
            function.signature
        );
    }
    if entry.returns == ReturnPolicy::Declassified
        && !(function.confidential || sensitivity.return_sensitive)
    {
        bail!(
            "manifest return policy mismatch for entrypoint {}: unused plaintext return declassification",
            function.signature
        );
    }
    if entry.returns == ReturnPolicy::EncryptedToClient
        && entry.declassifies.contains(&DeclassificationKind::Return)
    {
        bail!(
            "manifest declassification mismatch for entrypoint {}: encrypted return must not declassify plaintext return",
            function.signature
        );
    }
    if entry.status == StatusPolicy::Public && sensitivity.status_sensitive {
        bail!(
            "manifest status policy mismatch for entrypoint {}: sensitive status requires declassification",
            function.signature
        );
    }
    if entry.status == StatusPolicy::Declassified && !sensitivity.status_sensitive {
        bail!(
            "manifest status policy mismatch for entrypoint {}: unused success declassification",
            function.signature
        );
    }
    let expected_declassifies = expected_declassifies(entry.returns, entry.status);
    let declared_declassifies = entry.declassifies.iter().copied().collect::<BTreeSet<_>>();
    if declared_declassifies != expected_declassifies {
        bail!(
            "manifest declassifies mismatch for entrypoint {}",
            function.signature
        );
    }
    let declared_public_state = entry
        .public_state_declassifies
        .iter()
        .cloned()
        .collect::<BTreeSet<_>>();
    if declared_public_state != sensitivity.sensitive_public_writes {
        bail!(
            "manifest public_state_declassifies mismatch for entrypoint {}",
            function.signature
        );
    }
    Ok(())
}

fn expected_declassifies(
    returns: ReturnPolicy,
    status: StatusPolicy,
) -> BTreeSet<DeclassificationKind> {
    let mut expected = BTreeSet::new();
    if returns == ReturnPolicy::Declassified {
        expected.insert(DeclassificationKind::Return);
    }
    if status == StatusPolicy::Declassified {
        expected.insert(DeclassificationKind::Success);
    }
    expected
}

fn artifact_policy_sensitivity(
    function: &CompiledFunction,
    state: &[StateObject],
) -> Result<ArtifactPolicySensitivity> {
    let mut tainted = BTreeSet::new();
    for index in &function.secret_args {
        if let Some((name, _)) = function.params.get(*index) {
            tainted.insert(name.clone());
        }
    }
    let mut sensitivity = ArtifactPolicySensitivity::default();
    collect_artifact_policy_sensitivity(
        &function.body,
        state,
        &mut tainted,
        &mut sensitivity,
        false,
    )?;
    Ok(sensitivity)
}

fn collect_artifact_policy_sensitivity(
    statements: &[Statement],
    state: &[StateObject],
    tainted: &mut BTreeSet<String>,
    sensitivity: &mut ArtifactPolicySensitivity,
    control_sensitive: bool,
) -> Result<()> {
    for statement in statements {
        match statement {
            Statement::Declare { name, value, .. } | Statement::Assign { name, value } => {
                set_artifact_taint(
                    name,
                    control_sensitive || artifact_expr_sensitive(value, state, tainted),
                    tainted,
                );
            }
            Statement::Require { cond } | Statement::AbortIf { cond } => {
                sensitivity.status_sensitive |=
                    control_sensitive || artifact_expr_sensitive(cond, state, tainted);
            }
            Statement::If {
                cond,
                then_body,
                else_body,
            } => {
                let cond_sensitive = artifact_expr_sensitive(cond, state, tainted);
                let mut then_tainted = tainted.clone();
                let mut else_tainted = tainted.clone();
                if cond_sensitive {
                    mark_artifact_assigned_locals(then_body, &mut then_tainted);
                    mark_artifact_assigned_locals(else_body, &mut else_tainted);
                }
                collect_artifact_policy_sensitivity(
                    then_body,
                    state,
                    &mut then_tainted,
                    sensitivity,
                    control_sensitive || cond_sensitive,
                )?;
                collect_artifact_policy_sensitivity(
                    else_body,
                    state,
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
                let loop_sensitive = control_sensitive
                    || artifact_expr_sensitive(start, state, tainted)
                    || artifact_expr_sensitive(end, state, tainted);
                collect_artifact_policy_sensitivity(
                    body,
                    state,
                    tainted,
                    sensitivity,
                    loop_sensitive,
                )?;
            }
            Statement::CellSet {
                object_id,
                value,
                predicate,
            } => {
                record_artifact_sensitive_public_write(
                    *object_id,
                    control_sensitive
                        || artifact_expr_sensitive(value, state, tainted)
                        || predicate
                            .as_ref()
                            .is_some_and(|expr| artifact_expr_sensitive(expr, state, tainted)),
                    state,
                    sensitivity,
                )?;
            }
            Statement::ArraySet {
                object_id,
                index,
                value,
                predicate,
            } => {
                record_artifact_sensitive_public_write(
                    *object_id,
                    control_sensitive
                        || artifact_expr_sensitive(index, state, tainted)
                        || artifact_expr_sensitive(value, state, tainted)
                        || predicate
                            .as_ref()
                            .is_some_and(|expr| artifact_expr_sensitive(expr, state, tainted)),
                    state,
                    sensitivity,
                )?;
            }
            Statement::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                record_artifact_sensitive_public_write(
                    *object_id,
                    control_sensitive
                        || artifact_expr_sensitive(key, state, tainted)
                        || artifact_expr_sensitive(value, state, tainted)
                        || predicate
                            .as_ref()
                            .is_some_and(|expr| artifact_expr_sensitive(expr, state, tainted)),
                    state,
                    sensitivity,
                )?;
            }
            Statement::Return { value } => {
                if let Some(value) = value {
                    sensitivity.return_sensitive |=
                        control_sensitive || artifact_expr_sensitive(value, state, tainted);
                }
            }
        }
    }
    Ok(())
}

fn artifact_expr_sensitive(expr: &Expr, state: &[StateObject], tainted: &BTreeSet<String>) -> bool {
    match expr {
        Expr::Var(name) => tainted.contains(name),
        Expr::Unary { expr, .. } => artifact_expr_sensitive(expr, state, tainted),
        Expr::Binary { lhs, rhs, .. } => {
            artifact_expr_sensitive(lhs, state, tainted)
                || artifact_expr_sensitive(rhs, state, tainted)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            artifact_expr_sensitive(cond, state, tainted)
                || artifact_expr_sensitive(when_true, state, tainted)
                || artifact_expr_sensitive(when_false, state, tainted)
        }
        Expr::CellGet { object_id } => artifact_state_object_by_id(state, *object_id)
            .map(|object| object.confidential)
            .unwrap_or(true),
        Expr::ArrayGet { object_id, index } => {
            artifact_state_object_by_id(state, *object_id)
                .map(|object| object.confidential)
                .unwrap_or(true)
                || artifact_expr_sensitive(index, state, tainted)
        }
        Expr::MapGet { object_id, key } => {
            artifact_state_object_by_id(state, *object_id)
                .map(|object| object.confidential)
                .unwrap_or(true)
                || artifact_expr_sensitive(key, state, tainted)
        }
        Expr::StructField { base, .. } => artifact_expr_sensitive(base, state, tainted),
        Expr::ArrayIndex { base, index } => {
            artifact_expr_sensitive(base, state, tainted)
                || artifact_expr_sensitive(index, state, tainted)
        }
        Expr::Keccak256 { parts } => parts
            .iter()
            .any(|part| artifact_expr_sensitive(part, state, tainted)),
        Expr::Literal(_) => false,
    }
}

fn record_artifact_sensitive_public_write(
    object_id: u32,
    is_sensitive: bool,
    state: &[StateObject],
    sensitivity: &mut ArtifactPolicySensitivity,
) -> Result<()> {
    if !is_sensitive {
        return Ok(());
    }
    let object = artifact_state_object_by_id(state, object_id)
        .ok_or_else(|| anyhow::anyhow!("unknown state object id {}", object_id))?;
    if !object.confidential {
        sensitivity
            .sensitive_public_writes
            .insert(object.name.clone());
    }
    Ok(())
}

fn artifact_state_object_by_id(state: &[StateObject], object_id: u32) -> Option<&StateObject> {
    state.iter().find(|object| object.id == object_id)
}

fn set_artifact_taint(name: &str, is_tainted: bool, tainted: &mut BTreeSet<String>) {
    if is_tainted {
        tainted.insert(name.to_string());
    } else {
        tainted.remove(name);
    }
}

fn mark_artifact_assigned_locals(statements: &[Statement], tainted: &mut BTreeSet<String>) {
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
                mark_artifact_assigned_locals(then_body, tainted);
                mark_artifact_assigned_locals(else_body, tainted);
            }
            Statement::For { body, .. } => mark_artifact_assigned_locals(body, tainted),
            Statement::Require { .. }
            | Statement::AbortIf { .. }
            | Statement::CellSet { .. }
            | Statement::ArraySet { .. }
            | Statement::MapPut { .. }
            | Statement::Return { .. } => {}
        }
    }
}

#[derive(Default)]
struct CountSummary {
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
                merge_counts(&mut counts, count_body(then_body));
                merge_counts(&mut counts, count_body(else_body));
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
                            merge_counts(&mut counts, count_body_with_env(body, &nested_env));
                        }
                    }
                    _ => merge_counts(&mut counts, count_body_with_env(body, loop_env)),
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
    target.local_count += extra.local_count;
    target.cell_reads += extra.cell_reads;
    target.cell_writes += extra.cell_writes;
    target.array_reads += extra.array_reads;
    target.array_writes += extra.array_writes;
    target.map_reads += extra.map_reads;
    target.map_writes += extra.map_writes;
}

fn validate_oram_access_shape(
    signature: &str,
    oram_accesses: &BTreeMap<u32, usize>,
    state: &[StateObject],
) -> Result<()> {
    uo_core::validate_oram_access_shape(signature, oram_accesses, state)
}

fn expected_commit_ops(
    statements: &[Statement],
    oram_accesses: &BTreeMap<u32, usize>,
    state: &[StateObject],
) -> Result<usize> {
    accessed_objects(statements)?
        .into_iter()
        .map(|object_id| {
            let object = state_object_by_id(state, object_id)?;
            Ok(match object.kind {
                uo_core::ContainerKind::Cell => 1usize,
                uo_core::ContainerKind::Array | uo_core::ContainerKind::Map
                    if object.backend == BackendKind::Oram =>
                {
                    let per_access = OramManifest::for_object(object)?.total_commit_ops();
                    if object.oram_scheme == PATH_ORAM_SCHEME {
                        per_access * oram_accesses.get(&object_id).copied().unwrap_or(0)
                    } else {
                        per_access
                    }
                }
                uo_core::ContainerKind::Array | uo_core::ContainerKind::Map => {
                    object.capacity.unwrap_or(1)
                }
            })
        })
        .collect::<Result<Vec<_>>>()
        .map(|counts| counts.into_iter().sum())
}

fn accessed_objects(statements: &[Statement]) -> Result<BTreeSet<u32>> {
    let mut accessed = BTreeSet::new();
    for statement in statements {
        collect_accessed_object_ids_statement(statement, &mut accessed)?;
    }
    Ok(accessed)
}

fn collect_accessed_object_ids_statement(
    statement: &Statement,
    accessed: &mut BTreeSet<u32>,
) -> Result<()> {
    match statement {
        Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
            collect_accessed_object_ids_expr(value, accessed)
        }
        Statement::Require { cond } | Statement::AbortIf { cond } => {
            collect_accessed_object_ids_expr(cond, accessed)
        }
        Statement::If {
            cond,
            then_body,
            else_body,
        } => {
            collect_accessed_object_ids_expr(cond, accessed)?;
            for stmt in then_body {
                collect_accessed_object_ids_statement(stmt, accessed)?;
            }
            for stmt in else_body {
                collect_accessed_object_ids_statement(stmt, accessed)?;
            }
            Ok(())
        }
        Statement::For {
            start, end, body, ..
        } => {
            collect_accessed_object_ids_expr(start, accessed)?;
            collect_accessed_object_ids_expr(end, accessed)?;
            for stmt in body {
                collect_accessed_object_ids_statement(stmt, accessed)?;
            }
            Ok(())
        }
        Statement::CellSet {
            object_id,
            value,
            predicate,
        } => {
            accessed.insert(*object_id);
            collect_accessed_object_ids_expr(value, accessed)?;
            if let Some(predicate) = predicate {
                collect_accessed_object_ids_expr(predicate, accessed)?;
            }
            Ok(())
        }
        Statement::ArraySet {
            object_id,
            index,
            value,
            predicate,
        } => {
            accessed.insert(*object_id);
            collect_accessed_object_ids_expr(index, accessed)?;
            collect_accessed_object_ids_expr(value, accessed)?;
            if let Some(predicate) = predicate {
                collect_accessed_object_ids_expr(predicate, accessed)?;
            }
            Ok(())
        }
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate,
        } => {
            accessed.insert(*object_id);
            collect_accessed_object_ids_expr(key, accessed)?;
            collect_accessed_object_ids_expr(value, accessed)?;
            if let Some(predicate) = predicate {
                collect_accessed_object_ids_expr(predicate, accessed)?;
            }
            Ok(())
        }
        Statement::Return { value } => {
            if let Some(value) = value {
                collect_accessed_object_ids_expr(value, accessed)?;
            }
            Ok(())
        }
    }
}

fn collect_accessed_object_ids_expr(expr: &Expr, accessed: &mut BTreeSet<u32>) -> Result<()> {
    match expr {
        Expr::Literal(_) | Expr::Var(_) => Ok(()),
        Expr::Unary { expr, .. } => collect_accessed_object_ids_expr(expr, accessed),
        Expr::Binary { lhs, rhs, .. } => {
            collect_accessed_object_ids_expr(lhs, accessed)?;
            collect_accessed_object_ids_expr(rhs, accessed)
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            collect_accessed_object_ids_expr(cond, accessed)?;
            collect_accessed_object_ids_expr(when_true, accessed)?;
            collect_accessed_object_ids_expr(when_false, accessed)
        }
        Expr::CellGet { object_id } => {
            accessed.insert(*object_id);
            Ok(())
        }
        Expr::ArrayGet { object_id, index } => {
            accessed.insert(*object_id);
            collect_accessed_object_ids_expr(index, accessed)
        }
        Expr::MapGet { object_id, key } => {
            accessed.insert(*object_id);
            collect_accessed_object_ids_expr(key, accessed)
        }
        Expr::StructField { base, .. } => collect_accessed_object_ids_expr(base, accessed),
        Expr::ArrayIndex { base, index } => {
            collect_accessed_object_ids_expr(base, accessed)?;
            collect_accessed_object_ids_expr(index, accessed)
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                collect_accessed_object_ids_expr(part, accessed)?;
            }
            Ok(())
        }
    }
}

fn count_oram_accesses(
    statements: &[Statement],
    state: &[StateObject],
) -> Result<BTreeMap<u32, usize>> {
    let mut counts = BTreeMap::new();
    for statement in statements {
        collect_oram_statement_accesses(statement, state, &BTreeMap::new(), &mut counts)?;
    }
    Ok(counts)
}

fn collect_oram_statement_accesses(
    statement: &Statement,
    state: &[StateObject],
    loop_env: &BTreeMap<String, usize>,
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
                collect_oram_statement_accesses(stmt, state, loop_env, counts)?;
            }
            for stmt in else_body {
                collect_oram_statement_accesses(stmt, state, loop_env, counts)?;
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
            collect_oram_expr_accesses(start, state, counts)?;
            collect_oram_expr_accesses(end, state, counts)?;
            let start = eval_loop_bound(start, loop_env);
            let end = eval_loop_bound(end, loop_env);
            match (start, end) {
                (Some(start), Some(end)) => {
                    for index in start..end {
                        let mut nested_env = loop_env.clone();
                        nested_env.insert(index_var.clone(), index);
                        for stmt in body {
                            collect_oram_statement_accesses(stmt, state, &nested_env, counts)?;
                        }
                    }
                }
                _ if body_contains_oram_accesses(body, state)? => {
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

fn body_contains_oram_accesses(statements: &[Statement], state: &[StateObject]) -> Result<bool> {
    let mut counts = BTreeMap::new();
    for statement in statements {
        collect_oram_statement_accesses(statement, state, &BTreeMap::new(), &mut counts)?;
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
        Expr::Literal(uo_core::Value::Uint(value)) => Some(*value),
        Expr::Literal(uo_core::Value::Bool(value)) => Some(Uint256::from_bool(*value)),
        Expr::Var(name) => loop_env.get(name).copied().map(Uint256::from),
        Expr::Unary {
            op: uo_core::UnaryOp::Neg,
            expr,
        } => eval_loop_bound_uint(expr, loop_env).map(Uint256::wrapping_neg),
        Expr::Unary {
            op: uo_core::UnaryOp::Not,
            expr,
        } => eval_loop_bound_uint(expr, loop_env).map(|value| Uint256::from_bool(value.is_zero())),
        Expr::Binary { op, lhs, rhs } => {
            let lhs = eval_loop_bound_uint(lhs, loop_env)?;
            let rhs = eval_loop_bound_uint(rhs, loop_env)?;
            match op {
                uo_core::BinaryOp::Add => Some(lhs.wrapping_add(rhs)),
                uo_core::BinaryOp::Sub => Some(lhs.wrapping_sub(rhs)),
                uo_core::BinaryOp::Mul => Some(lhs.wrapping_mul(rhs)),
                uo_core::BinaryOp::Div => Some(if rhs.is_zero() {
                    Uint256::ZERO
                } else {
                    lhs.div_rem(rhs).0
                }),
                uo_core::BinaryOp::Mod => Some(if rhs.is_zero() {
                    Uint256::ZERO
                } else {
                    lhs.div_rem(rhs).1
                }),
                uo_core::BinaryOp::BitAnd => Some(lhs.bitand(rhs)),
                uo_core::BinaryOp::BitOr => Some(lhs.bitor(rhs)),
                uo_core::BinaryOp::BitXor => Some(lhs.bitxor(rhs)),
                uo_core::BinaryOp::Eq => Some(Uint256::from_bool(lhs == rhs)),
                uo_core::BinaryOp::Neq => Some(Uint256::from_bool(lhs != rhs)),
                uo_core::BinaryOp::Lt => Some(Uint256::from_bool(lhs < rhs)),
                uo_core::BinaryOp::Lte => Some(Uint256::from_bool(lhs <= rhs)),
                uo_core::BinaryOp::Gt => Some(Uint256::from_bool(lhs > rhs)),
                uo_core::BinaryOp::Gte => Some(Uint256::from_bool(lhs >= rhs)),
                uo_core::BinaryOp::And => Some(Uint256::from_bool(lhs.as_bool() && rhs.as_bool())),
                uo_core::BinaryOp::Or => Some(Uint256::from_bool(lhs.as_bool() || rhs.as_bool())),
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
        | Expr::Literal(uo_core::Value::Bytes32(_))
        | Expr::Literal(uo_core::Value::Address(_))
        | Expr::Literal(uo_core::Value::Struct(_))
        | Expr::Literal(uo_core::Value::Array(_)) => None,
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
    lower_confidential_kernel_statements(statements, signature)?;
    Ok(())
}

#[cfg(test)]
fn forbid_raw_expr(expr: &Expr, signature: &str) -> Result<()> {
    lower_confidential_kernel_expr(expr, signature)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        check_artifact, check_artifact_against_source, forbid_raw_expr,
        translation_validation_bundle_against_source,
    };
    use std::fs;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};
    use uo_core::{
        CompiledArtifact, ContractMetadata, DeclassificationKind, Expr, ProgramMode, ReturnPolicy,
        RuntimeKernelStepManifest, StatusPolicy, Value,
    };
    use uo_precompiles::UoOpcode;

    static TEMP_COUNTER: AtomicU64 = AtomicU64::new(0);

    fn write_temp(name: &str, extension: &str, contents: &str) -> PathBuf {
        let unique = TEMP_COUNTER.fetch_add(1, Ordering::Relaxed);
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = PathBuf::from(format!(
            "/tmp/uo-check-test-{}-{}-{}.{}",
            name,
            std::process::id(),
            stamp + unique as u128,
            extension
        ));
        fs::write(&path, contents).unwrap();
        path
    }

    fn parse_metadata(yaml: &str) -> ContractMetadata {
        serde_yaml::from_str(yaml).unwrap()
    }

    fn sample_source_and_metadata() -> (PathBuf, ContractMetadata) {
        let source = write_temp(
            "classifier",
            "sol",
            r#"
            contract FixedSlotClassifier {
                uint256 private last;

                function classify(uint256 secret) public {
                    last = secret & 1;
                }
            }
            "#,
        );
        let metadata = parse_metadata(
            r#"
contract: FixedSlotClassifier
entrypoints:
  classify(uint256):
    secret_args: [secret]
    confidential: true
    public_gas_budget: 7777
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
        (source, metadata)
    }

    fn sample_artifact() -> (PathBuf, ContractMetadata, CompiledArtifact) {
        let (source, metadata) = sample_source_and_metadata();
        let artifact =
            uo_solc::compile(source.to_str().unwrap(), &metadata, ProgramMode::Uo).unwrap();
        (source, metadata, artifact)
    }

    #[test]
    fn artifact_checker_derives_manifest_exactness() {
        let (_, _, artifact) = sample_artifact();
        let report = check_artifact(&artifact).unwrap();
        assert!(report.contains(&"admitted package identity/toolchain binding: ok".to_string()));
        assert!(report.contains(&"manifest/object exactness: ok".to_string()));
        assert!(report.contains(&"manifest/entrypoint exactness: ok".to_string()));
    }

    #[test]
    fn artifact_checker_rejects_toolchain_manifest_digest_drift() {
        let (_, _, mut artifact) = sample_artifact();
        artifact
            .admitted_package
            .as_mut()
            .unwrap()
            .toolchain_manifest_sha256 = "0".repeat(64);
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("toolchain_manifest_sha256 mismatch"));
    }

    #[test]
    fn source_checker_rejects_admitted_package_identity_drift() {
        let (source, metadata, mut artifact) = sample_artifact();
        artifact.admitted_package.as_mut().unwrap().package_sha256 = "1".repeat(64);
        let err = check_artifact_against_source(source.to_str().unwrap(), &metadata, &artifact)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("admitted package package_sha256 mismatch"));
    }

    #[test]
    fn artifact_checker_rejects_secret_arg_drift() {
        let (_, _, mut artifact) = sample_artifact();
        let signature = artifact.contract.functions[0].signature.clone();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap()
            .secret_args = vec![];
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest secret_args mismatch for entrypoint"));
    }

    #[test]
    fn artifact_checker_rejects_plaintext_return_declassification_drift() {
        let source = write_temp(
            "return-policy",
            "sol",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let metadata = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: declassified
    status: public
    declassifies: [return]
state: {}
bounds:
  loops: {}
"#,
        );
        let mut artifact =
            uo_solc::compile(source.to_str().unwrap(), &metadata, ProgramMode::Uo).unwrap();
        let signature = artifact.contract.functions[0].signature.clone();
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap();
        entry.returns = ReturnPolicy::Public;
        entry.declassifies.clear();
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("sensitive return requires declassification"));
    }

    #[test]
    fn artifact_checker_rejects_unused_success_declassification_drift() {
        let (_, _, mut artifact) = sample_artifact();
        let signature = artifact.contract.functions[0].signature.clone();
        let entry = artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap();
        entry.status = StatusPolicy::Declassified;
        entry.declassifies = vec![DeclassificationKind::Success];
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err.to_string().contains("unused success declassification"));
    }

    #[test]
    fn artifact_checker_rejects_public_state_declassification_drift() {
        let source = write_temp(
            "public-state-release",
            "sol",
            r#"
            contract C {
                uint256 private publicCell;
                function f(uint256 value) public { publicCell = value; }
            }
            "#,
        );
        let metadata = parse_metadata(
            r#"
contract: C
entrypoints:
  f(uint256):
    confidential: false
    returns: forbidden
    status: public
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
        let mut artifact =
            uo_solc::compile(source.to_str().unwrap(), &metadata, ProgramMode::Uo).unwrap();
        let signature = artifact.contract.functions[0].signature.clone();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap()
            .public_state_declassifies = vec!["publicCell".into()];
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest public_state_declassifies mismatch"));
    }

    #[test]
    fn checker_rejects_confidential_select_arm_outside_branchless_fragment() {
        let expr = Expr::Select {
            cond: Box::new(Expr::Var("cond".into())),
            when_true: Box::new(Expr::ArrayIndex {
                base: Box::new(Expr::Literal(Value::Array(
                    vec![Value::uint(1)].into_boxed_slice(),
                ))),
                index: Box::new(Expr::Literal(Value::uint(0))),
            }),
            when_false: Box::new(Expr::Literal(Value::uint(0))),
        };
        let err = forbid_raw_expr(&expr, "confidentialSelect(uint256)").unwrap_err();
        assert!(err
            .to_string()
            .contains("select arm outside the branchless pure fragment"));
    }

    #[test]
    fn checker_rejects_confidential_array_index() {
        let expr = Expr::ArrayIndex {
            base: Box::new(Expr::Literal(Value::Array(
                vec![Value::uint(1)].into_boxed_slice(),
            ))),
            index: Box::new(Expr::Literal(Value::uint(0))),
        };
        let err = forbid_raw_expr(&expr, "confidentialArrayIndex()").unwrap_err();
        assert!(err
            .to_string()
            .contains("unsupported array indexing in the confidential fragment"));
    }

    #[test]
    fn checker_rejects_confidential_struct_field() {
        let expr = Expr::StructField {
            base: Box::new(Expr::Literal(Value::Struct(
                vec![("flag".into(), Value::Bool(true))].into_boxed_slice(),
            ))),
            field: "flag".into(),
        };
        let err = forbid_raw_expr(&expr, "confidentialStructField()").unwrap_err();
        assert!(err
            .to_string()
            .contains("unsupported struct-field projection in the confidential fragment"));
    }

    #[test]
    fn artifact_checker_rejects_kernel_step_drift_by_append() {
        let (_, _, mut artifact) = sample_artifact();
        let signature = artifact.contract.functions[0].signature.clone();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap()
            .kernel_steps
            .push(RuntimeKernelStepManifest {
                opcode: UoOpcode::Wipe,
                object_id: None,
            });
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest kernel_steps mismatch for entrypoint"));
    }

    #[test]
    fn artifact_checker_rejects_missing_confidential_kernel_step_trace() {
        let (_, _, mut artifact) = sample_artifact();
        let signature = artifact.contract.functions[0].signature.clone();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap()
            .kernel_steps
            .clear();
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest kernel_steps mismatch for entrypoint"));
    }

    #[test]
    fn artifact_checker_rejects_confidential_kernel_step_drift() {
        let (_, _, mut artifact) = sample_artifact();
        let signature = artifact.contract.functions[0].signature.clone();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap()
            .kernel_steps
            .clear();
        let err = check_artifact(&artifact).unwrap_err();
        assert!(err
            .to_string()
            .contains("manifest kernel_steps mismatch for entrypoint"));
    }

    #[test]
    fn translation_validation_rejects_public_gas_budget_drift() {
        let (source, metadata, mut artifact) = sample_artifact();
        let signature = artifact.contract.functions[0].signature.clone();
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut(&signature)
            .unwrap()
            .public_gas_budget += 1;
        assert!(check_artifact(&artifact).is_ok());
        let err = check_artifact_against_source(source.to_str().unwrap(), &metadata, &artifact)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("source/artifact manifest mismatch"));
    }

    #[test]
    fn debug_translation_bundle_includes_projection_views() {
        let (source, metadata, artifact) = sample_artifact();
        let debug_bundle = translation_validation_bundle_against_source(
            source.to_str().unwrap(),
            &metadata,
            &artifact,
        )
        .unwrap();
        let debug_json = serde_json::to_value(&debug_bundle).unwrap();
        let debug_obj = debug_json.as_object().unwrap();
        assert!(debug_obj.contains_key("source_path"));
        assert!(debug_obj.contains_key("source_view"));
        assert!(debug_obj.contains_key("artifact_view"));
    }

    #[test]
    fn artifact_checker_accepts_raw_bounded_loop_manifest_counts() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
        let source = root.join("benches/raw/AuthScan.sol");
        let metadata: ContractMetadata = serde_yaml::from_str(
            &fs::read_to_string(root.join("benches/raw/AuthScan.raw.yaml")).unwrap(),
        )
        .unwrap();
        let artifact =
            uo_solc::compile(source.to_str().unwrap(), &metadata, ProgramMode::Raw).unwrap();
        check_artifact(&artifact).unwrap();
    }
}
