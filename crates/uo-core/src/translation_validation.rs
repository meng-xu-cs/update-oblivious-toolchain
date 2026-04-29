use crate::artifact::CompiledArtifact;
use crate::confidential_kernel::{ConfidentialKernelProgram, ConfidentialKernelSlotProgram};
use crate::ir::{BackendKind, ContainerKind, ProgramMode};
use crate::manifest::{
    EntrypointManifest, OramManifest, RuntimeKernelStepManifest, RuntimeManifest,
};
use crate::metadata::{ContractMetadata, DeclassificationKind, ReturnPolicy, StatusPolicy};
use crate::AdmittedPackageIdentity;
use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

fn canonicalize_json_value(value: Value) -> Value {
    match value {
        Value::Array(items) => {
            Value::Array(items.into_iter().map(canonicalize_json_value).collect())
        }
        Value::Object(object) => {
            let mut entries = object.into_iter().collect::<Vec<_>>();
            entries.sort_by(|lhs, rhs| lhs.0.cmp(&rhs.0));
            let mut canonical = Map::new();
            for (key, value) in entries {
                canonical.insert(key, canonicalize_json_value(value));
            }
            Value::Object(canonical)
        }
        scalar => scalar,
    }
}

fn canonical_json_string<T: Serialize>(value: &T) -> Result<String> {
    let json = serde_json::to_value(value)?;
    Ok(serde_json::to_string(&canonicalize_json_value(json))?)
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantTranslationBundle {
    pub source_path: String,
    pub metadata_contract: String,
    #[serde(default)]
    pub source_admitted_package: Option<AdmittedPackageIdentity>,
    #[serde(default)]
    pub artifact_admitted_package: Option<AdmittedPackageIdentity>,
    pub source_contract_json: String,
    pub artifact_contract_json: String,
    pub source_view: ProofRelevantContractView,
    pub artifact_view: ProofRelevantContractView,
}

impl ProofRelevantTranslationBundle {
    pub fn from_artifacts(
        source_path: impl Into<String>,
        metadata: &ContractMetadata,
        source_artifact: &CompiledArtifact,
        artifact: &CompiledArtifact,
    ) -> Result<Self> {
        let bundle = Self {
            source_path: source_path.into(),
            metadata_contract: metadata.contract.clone(),
            source_admitted_package: source_artifact.admitted_package.clone(),
            artifact_admitted_package: artifact.admitted_package.clone(),
            source_contract_json: serde_json::to_string(&source_artifact.contract)?,
            artifact_contract_json: serde_json::to_string(&artifact.contract)?,
            source_view: ProofRelevantContractView::from_artifact(source_artifact)?,
            artifact_view: ProofRelevantContractView::from_artifact(artifact)?,
        };
        bundle.validate_field_completeness()?;
        Ok(bundle)
    }

    pub fn views_match(&self) -> bool {
        self.source_view == self.artifact_view
            && self.source_admitted_package == self.artifact_admitted_package
            && self.source_admitted_package.is_some()
    }

    pub fn validate_field_completeness(&self) -> Result<()> {
        validate_proof_relevant_translation_bundle_json(&serde_json::to_value(self)?)
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantContractView {
    pub contract: String,
    pub mode: String,
    pub state: Vec<ProofRelevantStateObjectView>,
    pub functions: Vec<ProofRelevantFunctionView>,
    pub manifest: ProofRelevantManifestView,
}

impl ProofRelevantContractView {
    pub fn from_artifact(artifact: &CompiledArtifact) -> Result<Self> {
        Ok(Self {
            contract: artifact.contract.contract.clone(),
            mode: program_mode_tag(&artifact.contract.mode).into(),
            state: artifact
                .contract
                .state
                .iter()
                .map(ProofRelevantStateObjectView::from_state_object)
                .collect::<Result<Vec<_>>>()?,
            functions: artifact
                .contract
                .functions
                .iter()
                .map(ProofRelevantFunctionView::from_compiled_function)
                .collect::<Result<Vec<_>>>()?,
            manifest: ProofRelevantManifestView::from_manifest(&artifact.contract.manifest)?,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantStateObjectView {
    pub id: u32,
    pub name: String,
    pub kind: String,
    pub backend: String,
    pub oram_scheme: String,
    pub value_type: String,
    pub value_type_short_name: String,
    pub key_type: Option<String>,
    pub key_type_short_name: Option<String>,
    pub capacity: Option<usize>,
    pub confidential: bool,
}

impl ProofRelevantStateObjectView {
    fn from_state_object(object: &crate::ir::StateObject) -> Result<Self> {
        Ok(Self {
            id: object.id,
            name: object.name.clone(),
            kind: container_kind_tag(&object.kind).into(),
            backend: backend_kind_tag(&object.backend).into(),
            oram_scheme: object.oram_scheme.clone(),
            value_type: canonical_json_string(&object.value_type)?,
            value_type_short_name: object.value_type.short_name(),
            key_type: object
                .key_type
                .as_ref()
                .map(canonical_json_string)
                .transpose()?,
            key_type_short_name: object.key_type.as_ref().map(crate::Type::short_name),
            capacity: object.capacity,
            confidential: object.confidential,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantParamView {
    pub name: String,
    pub ty: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantFunctionView {
    pub signature: String,
    pub params: Vec<ProofRelevantParamView>,
    pub public_env: Vec<crate::ir::PublicEnvField>,
    pub return_type: Option<String>,
    pub body: Vec<String>,
    pub secret_args: Vec<usize>,
    pub confidential: bool,
    #[serde(default)]
    pub confidential_program: Option<String>,
    #[serde(default)]
    pub confidential_slot_program: Option<String>,
}

impl ProofRelevantFunctionView {
    fn from_compiled_function(function: &crate::ir::CompiledFunction) -> Result<Self> {
        Ok(Self {
            signature: function.signature.clone(),
            params: function
                .params
                .iter()
                .map(|(name, ty)| {
                    Ok(ProofRelevantParamView {
                        name: name.clone(),
                        ty: canonical_json_string(ty)?,
                    })
                })
                .collect::<Result<Vec<_>>>()?,
            public_env: function.public_env.clone(),
            return_type: function
                .return_type
                .as_ref()
                .map(canonical_json_string)
                .transpose()?,
            body: function
                .body
                .iter()
                .map(canonical_json_string)
                .collect::<Result<Vec<_>>>()?,
            secret_args: function.secret_args.clone(),
            confidential: function.confidential,
            confidential_program: function
                .confidential_program
                .as_ref()
                .map(canonical_json_string)
                .transpose()?,
            confidential_slot_program: function
                .confidential_slot_program
                .as_ref()
                .map(canonical_json_string)
                .transpose()?,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantManifestView {
    pub contract: String,
    pub compilation_mode: String,
    pub objects: Vec<ProofRelevantManifestObjectView>,
    pub entrypoints: Vec<ProofRelevantEntrypointView>,
}

impl ProofRelevantManifestView {
    fn from_manifest(manifest: &RuntimeManifest) -> Result<Self> {
        Ok(Self {
            contract: manifest.contract.clone(),
            compilation_mode: manifest.compilation_mode.clone(),
            objects: manifest
                .objects
                .iter()
                .map(ProofRelevantManifestObjectView::from_manifest_object)
                .collect::<Result<Vec<_>>>()?,
            entrypoints: manifest
                .entrypoints
                .iter()
                .map(|(signature, entrypoint)| {
                    ProofRelevantEntrypointView::from_manifest_entrypoint(signature, entrypoint)
                })
                .collect::<Result<Vec<_>>>()?,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantManifestObjectView {
    pub id: u32,
    pub name: String,
    pub kind: String,
    pub backend: String,
    pub capacity: Option<usize>,
    pub value_type: Option<String>,
    pub key_type: Option<String>,
    pub oram: Option<ProofRelevantOramView>,
}

impl ProofRelevantManifestObjectView {
    fn from_manifest_object(object: &crate::manifest::StateObjectManifest) -> Result<Self> {
        Ok(Self {
            id: object.id,
            name: object.name.clone(),
            kind: object.kind.clone(),
            backend: object.backend.clone(),
            capacity: object.capacity,
            value_type: object.value_type.clone(),
            key_type: object.key_type.clone(),
            oram: object
                .oram
                .as_ref()
                .map(ProofRelevantOramView::from_oram_manifest)
                .transpose()?,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantOramView {
    pub scheme: String,
    pub block_size: usize,
    pub bucket_size: usize,
    pub bucket_count: usize,
    pub blocks_per_bucket: usize,
    pub tree_height: usize,
    pub stash_bound: usize,
    pub recursion_depth: usize,
    pub metadata_pages: usize,
    pub metadata_pages_per_access: usize,
    pub buckets_per_access: usize,
    pub accesses_per_call: usize,
}

impl ProofRelevantOramView {
    fn from_oram_manifest(oram: &OramManifest) -> Result<Self> {
        Ok(Self {
            scheme: oram.scheme.clone(),
            block_size: oram.block_size,
            bucket_size: oram.bucket_size,
            bucket_count: oram.bucket_count,
            blocks_per_bucket: oram.blocks_per_bucket,
            tree_height: oram.tree_height,
            stash_bound: oram.stash_bound,
            recursion_depth: oram.recursion_depth,
            metadata_pages: oram.metadata_pages,
            metadata_pages_per_access: oram.metadata_pages_per_access,
            buckets_per_access: oram.buckets_per_access,
            accesses_per_call: oram.accesses_per_call,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantEntrypointView {
    pub signature: String,
    pub secret_args: Vec<usize>,
    pub param_names: Vec<String>,
    pub public_env: Vec<crate::ir::PublicEnvField>,
    pub entry_input_len: usize,
    pub initializer: bool,
    pub requires_initialized: bool,
    pub public_gas_budget: u64,
    pub arena_bytes: usize,
    pub max_stack_words: usize,
    pub max_hash_part_bytes: usize,
    #[serde(default)]
    pub return_canonical_len: Option<usize>,
    pub returns: ReturnPolicy,
    pub status: StatusPolicy,
    pub declassifies: Vec<DeclassificationKind>,
    pub public_state_declassifies: Vec<String>,
    #[serde(default)]
    pub confidential_program: Option<ConfidentialKernelProgram>,
    #[serde(default)]
    pub confidential_slot_program: Option<ConfidentialKernelSlotProgram>,
    pub kernel_steps: Vec<ProofRelevantKernelStepView>,
    pub uocell_reads: usize,
    pub uocell_writes: usize,
    pub uoarray_reads: usize,
    pub uoarray_writes: usize,
    pub uomap_reads: usize,
    pub uomap_writes: usize,
    pub max_commit_ops: usize,
    pub oram_accesses: Vec<ProofRelevantOramAccessView>,
}

impl ProofRelevantEntrypointView {
    fn from_manifest_entrypoint(signature: &str, entrypoint: &EntrypointManifest) -> Result<Self> {
        Ok(Self {
            signature: signature.into(),
            secret_args: entrypoint.secret_args.clone(),
            param_names: entrypoint.param_names.clone(),
            public_env: entrypoint.public_env.clone(),
            entry_input_len: entrypoint.entry_input_len,
            initializer: entrypoint.initializer,
            requires_initialized: entrypoint.requires_initialized,
            public_gas_budget: entrypoint.public_gas_budget,
            arena_bytes: entrypoint.arena_bytes,
            max_stack_words: entrypoint.max_stack_words,
            max_hash_part_bytes: entrypoint.max_hash_part_bytes,
            return_canonical_len: entrypoint.return_canonical_len,
            returns: entrypoint.returns,
            status: entrypoint.status,
            declassifies: entrypoint.declassifies.clone(),
            public_state_declassifies: entrypoint.public_state_declassifies.clone(),
            confidential_program: entrypoint.confidential_program.clone(),
            confidential_slot_program: entrypoint.confidential_slot_program.clone(),
            kernel_steps: entrypoint
                .canonical_kernel_step_manifest()
                .iter()
                .map(ProofRelevantKernelStepView::from_kernel_step)
                .collect::<Result<Vec<_>>>()?,
            uocell_reads: entrypoint.uocell_reads,
            uocell_writes: entrypoint.uocell_writes,
            uoarray_reads: entrypoint.uoarray_reads,
            uoarray_writes: entrypoint.uoarray_writes,
            uomap_reads: entrypoint.uomap_reads,
            uomap_writes: entrypoint.uomap_writes,
            max_commit_ops: entrypoint.max_commit_ops,
            oram_accesses: entrypoint
                .oram_accesses
                .iter()
                .map(|(object_id, accesses)| ProofRelevantOramAccessView {
                    object_id: *object_id,
                    accesses: *accesses,
                })
                .collect(),
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantKernelStepView {
    pub opcode: String,
    pub object_id: Option<u32>,
}

impl ProofRelevantKernelStepView {
    fn from_kernel_step(step: &RuntimeKernelStepManifest) -> Result<Self> {
        Ok(Self {
            opcode: opcode_tag(&step.opcode).into(),
            object_id: step.object_id,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofRelevantOramAccessView {
    pub object_id: u32,
    pub accesses: usize,
}

fn program_mode_tag(mode: &ProgramMode) -> &'static str {
    match mode {
        ProgramMode::Raw => "raw",
        ProgramMode::Uo => "uo",
    }
}

fn container_kind_tag(kind: &ContainerKind) -> &'static str {
    match kind {
        ContainerKind::Cell => "cell",
        ContainerKind::Array => "array",
        ContainerKind::Map => "map",
    }
}

fn backend_kind_tag(backend: &BackendKind) -> &'static str {
    match backend {
        BackendKind::Raw => "raw",
        BackendKind::FullScan => "full_scan",
        BackendKind::Oram => "oram",
    }
}

fn opcode_tag(opcode: &uo_precompiles::UoOpcode) -> &'static str {
    match opcode {
        uo_precompiles::UoOpcode::Begin => "Begin",
        uo_precompiles::UoOpcode::CellGet => "CellGet",
        uo_precompiles::UoOpcode::CellSet => "CellSet",
        uo_precompiles::UoOpcode::ArrayGet => "ArrayGet",
        uo_precompiles::UoOpcode::ArraySet => "ArraySet",
        uo_precompiles::UoOpcode::MapGet => "MapGet",
        uo_precompiles::UoOpcode::MapPut => "MapPut",
        uo_precompiles::UoOpcode::Commit => "Commit",
        uo_precompiles::UoOpcode::Wipe => "Wipe",
    }
}

const BUNDLE_FIELDS: &[&str] = &[
    "artifact_admitted_package",
    "artifact_contract_json",
    "artifact_view",
    "metadata_contract",
    "source_admitted_package",
    "source_contract_json",
    "source_path",
    "source_view",
];

const ADMITTED_PACKAGE_FIELDS: &[&str] = &[
    "compilation_mode",
    "compiler_version",
    "metadata_sha256",
    "package_sha256",
    "schema",
    "source_language",
    "source_sha256",
    "toolchain_manifest_sha256",
];

const ADMITTED_PACKAGE_FIELDS_WITH_RAW_METADATA: &[&str] = &[
    "compilation_mode",
    "compiler_version",
    "metadata_sha256",
    "package_sha256",
    "raw_metadata_sha256",
    "schema",
    "source_language",
    "source_sha256",
    "toolchain_manifest_sha256",
];

const CONTRACT_VIEW_FIELDS: &[&str] = &["contract", "functions", "manifest", "mode", "state"];

const STATE_OBJECT_VIEW_FIELDS: &[&str] = &[
    "backend",
    "capacity",
    "confidential",
    "id",
    "key_type",
    "key_type_short_name",
    "kind",
    "name",
    "oram_scheme",
    "value_type",
    "value_type_short_name",
];

const PARAM_VIEW_FIELDS: &[&str] = &["name", "ty"];

const FUNCTION_VIEW_FIELDS: &[&str] = &[
    "body",
    "confidential",
    "confidential_program",
    "confidential_slot_program",
    "params",
    "public_env",
    "return_type",
    "secret_args",
    "signature",
];

const MANIFEST_VIEW_FIELDS: &[&str] = &["compilation_mode", "contract", "entrypoints", "objects"];

const MANIFEST_OBJECT_VIEW_FIELDS: &[&str] = &[
    "backend",
    "capacity",
    "id",
    "key_type",
    "kind",
    "name",
    "oram",
    "value_type",
];

const ORAM_VIEW_FIELDS: &[&str] = &[
    "accesses_per_call",
    "block_size",
    "blocks_per_bucket",
    "bucket_count",
    "bucket_size",
    "buckets_per_access",
    "metadata_pages",
    "metadata_pages_per_access",
    "recursion_depth",
    "scheme",
    "stash_bound",
    "tree_height",
];

const ENTRYPOINT_VIEW_FIELDS: &[&str] = &[
    "arena_bytes",
    "confidential_program",
    "confidential_slot_program",
    "declassifies",
    "entry_input_len",
    "initializer",
    "kernel_steps",
    "max_commit_ops",
    "max_hash_part_bytes",
    "max_stack_words",
    "oram_accesses",
    "param_names",
    "public_env",
    "public_gas_budget",
    "public_state_declassifies",
    "return_canonical_len",
    "returns",
    "secret_args",
    "signature",
    "status",
    "requires_initialized",
    "uoarray_reads",
    "uoarray_writes",
    "uocell_reads",
    "uocell_writes",
    "uomap_reads",
    "uomap_writes",
];

const KERNEL_STEP_VIEW_FIELDS: &[&str] = &["object_id", "opcode"];

const ORAM_ACCESS_VIEW_FIELDS: &[&str] = &["accesses", "object_id"];

fn require_object_fields(value: &Value, path: &str, expected: &[&str]) -> Result<()> {
    let Value::Object(object) = value else {
        bail!("{path} must be a JSON object");
    };
    let mut actual = object.keys().map(String::as_str).collect::<Vec<_>>();
    actual.sort_unstable();
    let mut expected_sorted = expected.to_vec();
    expected_sorted.sort_unstable();
    if actual != expected_sorted {
        let missing = expected_sorted
            .iter()
            .copied()
            .filter(|field| !actual.contains(field))
            .collect::<Vec<_>>();
        let extra = actual
            .iter()
            .copied()
            .filter(|field| !expected_sorted.contains(field))
            .collect::<Vec<_>>();
        bail!(
            "{path} proof-relevant fields mismatch: missing [{}], extra [{}]",
            missing.join(", "),
            extra.join(", ")
        );
    }
    Ok(())
}

fn require_admitted_package_fields(value: &Value, path: &str) -> Result<()> {
    if value.is_null() {
        return Ok(());
    }
    match require_object_fields(value, path, ADMITTED_PACKAGE_FIELDS) {
        Ok(()) => Ok(()),
        Err(required_err) => {
            require_object_fields(value, path, ADMITTED_PACKAGE_FIELDS_WITH_RAW_METADATA).map_err(
                |with_raw_err| {
                    anyhow::anyhow!(
                        "{required_err}; accepted raw-metadata shape also failed: {with_raw_err}"
                    )
                },
            )
        }
    }
}

fn require_array<'a>(value: &'a Value, path: &str) -> Result<&'a Vec<Value>> {
    match value {
        Value::Array(items) => Ok(items),
        _ => bail!("{path} must be a JSON array"),
    }
}

fn require_field<'a>(value: &'a Value, path: &str, field: &str) -> Result<&'a Value> {
    match value {
        Value::Object(object) => object
            .get(field)
            .ok_or_else(|| anyhow::anyhow!("{path} missing field {field}")),
        _ => bail!("{path} must be a JSON object"),
    }
}

fn validate_contract_view_fields(value: &Value, path: &str) -> Result<()> {
    require_object_fields(value, path, CONTRACT_VIEW_FIELDS)?;
    for (index, state) in require_array(require_field(value, path, "state")?, "state")?
        .iter()
        .enumerate()
    {
        require_object_fields(
            state,
            &format!("{path}.state[{index}]"),
            STATE_OBJECT_VIEW_FIELDS,
        )?;
    }
    for (index, function) in require_array(require_field(value, path, "functions")?, "functions")?
        .iter()
        .enumerate()
    {
        require_object_fields(
            function,
            &format!("{path}.functions[{index}]"),
            FUNCTION_VIEW_FIELDS,
        )?;
        for (param_index, param) in
            require_array(require_field(function, path, "params")?, "params")?
                .iter()
                .enumerate()
        {
            require_object_fields(
                param,
                &format!("{path}.functions[{index}].params[{param_index}]"),
                PARAM_VIEW_FIELDS,
            )?;
        }
    }
    let manifest = require_field(value, path, "manifest")?;
    require_object_fields(manifest, &format!("{path}.manifest"), MANIFEST_VIEW_FIELDS)?;
    for (index, object) in require_array(
        require_field(manifest, path, "objects")?,
        "manifest.objects",
    )?
    .iter()
    .enumerate()
    {
        require_object_fields(
            object,
            &format!("{path}.manifest.objects[{index}]"),
            MANIFEST_OBJECT_VIEW_FIELDS,
        )?;
        let oram = require_field(object, path, "oram")?;
        if !oram.is_null() {
            require_object_fields(
                oram,
                &format!("{path}.manifest.objects[{index}].oram"),
                ORAM_VIEW_FIELDS,
            )?;
        }
    }
    for (index, entrypoint) in require_array(
        require_field(manifest, path, "entrypoints")?,
        "manifest.entrypoints",
    )?
    .iter()
    .enumerate()
    {
        require_object_fields(
            entrypoint,
            &format!("{path}.manifest.entrypoints[{index}]"),
            ENTRYPOINT_VIEW_FIELDS,
        )?;
        for (step_index, step) in require_array(
            require_field(entrypoint, path, "kernel_steps")?,
            "kernel_steps",
        )?
        .iter()
        .enumerate()
        {
            require_object_fields(
                step,
                &format!("{path}.manifest.entrypoints[{index}].kernel_steps[{step_index}]"),
                KERNEL_STEP_VIEW_FIELDS,
            )?;
        }
        for (access_index, access) in require_array(
            require_field(entrypoint, path, "oram_accesses")?,
            "oram_accesses",
        )?
        .iter()
        .enumerate()
        {
            require_object_fields(
                access,
                &format!("{path}.manifest.entrypoints[{index}].oram_accesses[{access_index}]"),
                ORAM_ACCESS_VIEW_FIELDS,
            )?;
        }
    }
    Ok(())
}

pub fn validate_proof_relevant_translation_bundle_json(value: &Value) -> Result<()> {
    require_object_fields(value, "bundle", BUNDLE_FIELDS)?;
    require_admitted_package_fields(
        require_field(value, "bundle", "source_admitted_package")?,
        "source_admitted_package",
    )?;
    require_admitted_package_fields(
        require_field(value, "bundle", "artifact_admitted_package")?,
        "artifact_admitted_package",
    )?;
    validate_contract_view_fields(
        require_field(value, "bundle", "source_view")?,
        "source_view",
    )?;
    validate_contract_view_fields(
        require_field(value, "bundle", "artifact_view")?,
        "artifact_view",
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        canonical_json_string, require_object_fields, ProofRelevantEntrypointView,
        ProofRelevantFunctionView, ProofRelevantStateObjectView, ENTRYPOINT_VIEW_FIELDS,
    };
    use crate::ir::{BackendKind, CompiledFunction, ContainerKind, Expr, StateObject, Statement};
    use crate::{
        DeclassificationKind, EntrypointManifest, ReturnPolicy, ScalarType, StatusPolicy, Type,
    };

    #[test]
    fn canonical_json_string_sorts_nested_statement_object_keys() {
        let statement = Statement::Assign {
            name: "result".into(),
            value: Expr::Select {
                cond: Box::new(Expr::Var("cond".into())),
                when_true: Box::new(Expr::Literal(crate::Value::uint(1))),
                when_false: Box::new(Expr::Literal(crate::Value::uint(0))),
            },
        };
        let rendered = canonical_json_string(&statement).unwrap();
        assert_eq!(
            rendered,
            "{\"Assign\":{\"name\":\"result\",\"value\":{\"Select\":{\"cond\":{\"Var\":\"cond\"},\"when_false\":{\"Literal\":{\"Uint\":\"0\"}},\"when_true\":{\"Literal\":{\"Uint\":\"1\"}}}}}}"
        );
    }

    #[test]
    fn proof_relevant_function_view_uses_canonical_json_for_types_and_body() {
        let function = CompiledFunction {
            signature: "f(uint256)".into(),
            params: vec![("x".into(), Type::Scalar(ScalarType::Uint(256)))],
            public_env: vec![],
            return_type: Some(Type::Scalar(ScalarType::Uint(256))),
            body: vec![Statement::ArraySet {
                object_id: 7,
                index: Expr::Var("x".into()),
                value: Expr::Literal(crate::Value::uint(1)),
                predicate: None,
            }],
            secret_args: vec![],
            confidential: false,
            confidential_program: None,
            confidential_slot_program: None,
        };
        let view = ProofRelevantFunctionView::from_compiled_function(&function).unwrap();
        assert_eq!(view.params[0].ty, "{\"Scalar\":{\"Uint\":256}}");
        assert_eq!(
            view.return_type.as_deref(),
            Some("{\"Scalar\":{\"Uint\":256}}")
        );
        assert_eq!(
            view.body[0],
            "{\"ArraySet\":{\"index\":{\"Var\":\"x\"},\"object_id\":7,\"predicate\":null,\"value\":{\"Literal\":{\"Uint\":\"1\"}}}}"
        );
    }

    #[test]
    fn proof_relevant_state_object_view_uses_canonical_json_for_types() {
        let object = StateObject {
            id: 1,
            name: "items".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
            oram_scheme: "surrogate_public_schedule_v1".into(),
            value_type: Type::Array(Box::new(Type::Scalar(ScalarType::Uint(256))), 4),
            key_type: Some(Type::Scalar(ScalarType::Bytes32)),
            capacity: Some(8),
            confidential: true,
        };
        let view = ProofRelevantStateObjectView::from_state_object(&object).unwrap();
        assert_eq!(
            view.value_type,
            "{\"Array\":[{\"Scalar\":{\"Uint\":256}},4]}"
        );
        assert_eq!(view.value_type_short_name, "uint256[4]");
        assert_eq!(view.key_type.as_deref(), Some("{\"Scalar\":\"Bytes32\"}"));
        assert_eq!(view.key_type_short_name.as_deref(), Some("bytes32"));
    }

    #[test]
    fn proof_relevant_entrypoint_view_carries_host_visibility_policy() {
        let entrypoint = EntrypointManifest {
            secret_args: vec![0],
            param_names: vec!["secret".into()],
            public_env: vec![],
            entry_input_len: 32,
            initializer: false,
            requires_initialized: false,
            public_gas_budget: 2000,
            arena_bytes: 4096,
            max_stack_words: 64,
            max_hash_part_bytes: 0,
            return_canonical_len: Some(32),
            returns: ReturnPolicy::Declassified,
            status: StatusPolicy::Declassified,
            declassifies: vec![DeclassificationKind::Return, DeclassificationKind::Success],
            public_state_declassifies: vec!["publicTotal".into()],
            confidential_program: None,
            confidential_slot_program: None,
            kernel_steps: vec![],
            uocell_reads: 0,
            uocell_writes: 0,
            uoarray_reads: 0,
            uoarray_writes: 0,
            uomap_reads: 0,
            uomap_writes: 0,
            max_commit_ops: 0,
            oram_accesses: Default::default(),
        };
        let view = ProofRelevantEntrypointView::from_manifest_entrypoint("f(uint256)", &entrypoint)
            .unwrap();
        assert_eq!(view.returns, ReturnPolicy::Declassified);
        assert_eq!(view.status, StatusPolicy::Declassified);
        assert_eq!(
            view.declassifies,
            vec![DeclassificationKind::Return, DeclassificationKind::Success]
        );
        assert_eq!(
            view.public_state_declassifies,
            vec!["publicTotal".to_string()]
        );
    }

    #[test]
    fn proof_relevant_entrypoint_view_serializes_optional_fields_as_null() {
        let entrypoint = EntrypointManifest {
            secret_args: vec![],
            param_names: vec![],
            public_env: vec![],
            entry_input_len: 0,
            initializer: false,
            requires_initialized: false,
            public_gas_budget: 2000,
            arena_bytes: 4096,
            max_stack_words: 64,
            max_hash_part_bytes: 0,
            return_canonical_len: None,
            returns: ReturnPolicy::Forbidden,
            status: StatusPolicy::Public,
            declassifies: vec![],
            public_state_declassifies: vec![],
            confidential_program: None,
            confidential_slot_program: None,
            kernel_steps: vec![],
            uocell_reads: 0,
            uocell_writes: 0,
            uoarray_reads: 0,
            uoarray_writes: 0,
            uomap_reads: 0,
            uomap_writes: 0,
            max_commit_ops: 0,
            oram_accesses: Default::default(),
        };
        let view =
            ProofRelevantEntrypointView::from_manifest_entrypoint("f()", &entrypoint).unwrap();
        let json = serde_json::to_value(&view).unwrap();
        let object = json.as_object().unwrap();
        assert!(object.get("return_canonical_len").unwrap().is_null());
        assert!(object.get("confidential_program").unwrap().is_null());
        assert!(object.get("confidential_slot_program").unwrap().is_null());
    }

    #[test]
    fn proof_relevant_entrypoint_field_completeness_rejects_missing_field() {
        let entrypoint = EntrypointManifest {
            secret_args: vec![0],
            param_names: vec!["secret".into()],
            public_env: vec![],
            entry_input_len: 32,
            initializer: false,
            requires_initialized: false,
            public_gas_budget: 2000,
            arena_bytes: 4096,
            max_stack_words: 64,
            max_hash_part_bytes: 0,
            return_canonical_len: Some(32),
            returns: ReturnPolicy::Declassified,
            status: StatusPolicy::Declassified,
            declassifies: vec![DeclassificationKind::Return],
            public_state_declassifies: vec!["publicTotal".into()],
            confidential_program: None,
            confidential_slot_program: None,
            kernel_steps: vec![],
            uocell_reads: 0,
            uocell_writes: 0,
            uoarray_reads: 0,
            uoarray_writes: 0,
            uomap_reads: 0,
            uomap_writes: 0,
            max_commit_ops: 0,
            oram_accesses: Default::default(),
        };
        let view = ProofRelevantEntrypointView::from_manifest_entrypoint("f(uint256)", &entrypoint)
            .unwrap();
        let mut json = serde_json::to_value(&view).unwrap();
        json.as_object_mut()
            .unwrap()
            .remove("public_state_declassifies");
        let err = require_object_fields(&json, "entrypoint", ENTRYPOINT_VIEW_FIELDS)
            .unwrap_err()
            .to_string();
        assert!(err.contains("missing [public_state_declassifies]"));
    }
}
