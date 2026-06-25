use crate::ir::CompiledContract;
use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use sha2::{Digest, Sha256};

pub const ADMITTED_PACKAGE_SCHEMA: &str = "uo-admitted-package-v5";
pub const SOURCE_LANGUAGE: &str = "uo-solidity-like-dsl-v1";
/// Versioned tag for the executable Solidity-like semantics the artifact is
/// compiled and proved under: wrapping modulo-2^256 arithmetic, division and
/// modulo by zero returning zero, canonical fixed-size ABI byte encoding,
/// `require`/abort with rollback, no Solidity context variables beyond the
/// admitted public-environment fields, and the mock-hash preservation route
/// paired with the real-Keccak runtime primitive assumption. It is bound into
/// the admitted-package hash so the proof-grade checker can reject artifacts
/// compiled under an unknown or divergent semantics profile. The Lean mirror is
/// `admittedPackageSemanticsProfile` in `TranslationValidationJson.lean`, and
/// the structured model is `uoSolidityLikeDslV1Profile` in
/// `SolidityDialectBoundary.lean`.
pub const SEMANTICS_PROFILE: &str = "uo-evm-modular256-v1";
pub const TOOLCHAIN_MANIFEST_SCHEMA: &str = "uo-toolchain-manifest-v1";
pub const RAW_METADATA_CANONICALIZATION_SCHEMA: &str = "uo-raw-metadata-canonicalization-v1";
pub const RAW_METADATA_CANONICALIZATION_PARSER: &str = "serde-yaml-contract-metadata-v1";
const PROOF_CHECKER_SCHEMA: &str = "uo-proof-checker-translation-validation-v1";
const RUNTIME_MODEL_TAG: &str = "uo-runtime-source-model-v1";
const DEPLOYMENT_ATTESTATION_MODEL_TAG: &str = "uo-sgx-admitted-package-digest-session-binding-v1";
const RUNTIME_BINARY_MODEL_TAG: &str = "uo-runtime-binary-hash-bound-by-deployment-attestation-v1";
const RETURN_CHANNEL_SESSION_MODEL_TAG: &str = "uo-return-channel-package-digest-aad-session-v1";

macro_rules! toolchain_env {
    ($name:literal) => {
        option_env!($name).unwrap_or("unavailable").to_string()
    };
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ArtifactFormat {
    Json,
    Bincode,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CompiledArtifact {
    pub compiler_version: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub admitted_package: Option<AdmittedPackageIdentity>,
    pub contract: CompiledContract,
    #[serde(default)]
    pub diagnostics: Vec<String>,
    #[serde(default)]
    pub transformed_source: Option<String>,
    #[serde(default)]
    pub disassembly: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AdmittedPackageIdentity {
    pub schema: String,
    pub source_language: String,
    pub semantics_profile: String,
    pub source_sha256: String,
    pub metadata_sha256: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub raw_metadata_sha256: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata_canonicalization_sha256: Option<String>,
    pub compilation_mode: String,
    pub compiler_version: String,
    pub toolchain_manifest_sha256: String,
    pub package_sha256: String,
}

impl AdmittedPackageIdentity {
    pub fn new<T: Serialize>(
        source: &str,
        metadata: &T,
        compilation_mode: &str,
        compiler_version: &str,
    ) -> Result<Self> {
        Self::new_with_raw_metadata_optional(
            source,
            metadata,
            None,
            compilation_mode,
            compiler_version,
        )
    }

    pub fn new_with_raw_metadata<T: Serialize>(
        source: &str,
        metadata: &T,
        raw_metadata: &[u8],
        compilation_mode: &str,
        compiler_version: &str,
    ) -> Result<Self> {
        Self::new_with_raw_metadata_optional(
            source,
            metadata,
            Some(raw_metadata),
            compilation_mode,
            compiler_version,
        )
    }

    fn new_with_raw_metadata_optional<T: Serialize>(
        source: &str,
        metadata: &T,
        raw_metadata: Option<&[u8]>,
        compilation_mode: &str,
        compiler_version: &str,
    ) -> Result<Self> {
        let source_sha256 = sha256_hex(source.as_bytes());
        let metadata_sha256 = sha256_hex(&canonical_json_bytes(metadata)?);
        let raw_metadata_sha256 = raw_metadata.map(sha256_hex);
        let metadata_canonicalization_sha256 = raw_metadata_sha256
            .as_deref()
            .map(|raw_metadata_sha256| {
                metadata_canonicalization_sha256(raw_metadata_sha256, &metadata_sha256)
            })
            .transpose()?;
        let toolchain_manifest_sha256 = ToolchainManifest::current(compiler_version).sha256()?;
        let package_input = AdmittedPackageHashInput {
            schema: ADMITTED_PACKAGE_SCHEMA,
            source_language: SOURCE_LANGUAGE,
            semantics_profile: SEMANTICS_PROFILE,
            source_sha256: &source_sha256,
            metadata_sha256: &metadata_sha256,
            raw_metadata_sha256: raw_metadata_sha256.as_deref(),
            metadata_canonicalization_sha256: metadata_canonicalization_sha256.as_deref(),
            compilation_mode,
            compiler_version,
            toolchain_manifest_sha256: &toolchain_manifest_sha256,
        };
        let package_sha256 = sha256_hex(&canonical_json_bytes(&package_input)?);
        Ok(Self {
            schema: ADMITTED_PACKAGE_SCHEMA.into(),
            source_language: SOURCE_LANGUAGE.into(),
            semantics_profile: SEMANTICS_PROFILE.into(),
            source_sha256,
            metadata_sha256,
            raw_metadata_sha256,
            metadata_canonicalization_sha256,
            compilation_mode: compilation_mode.into(),
            compiler_version: compiler_version.into(),
            toolchain_manifest_sha256,
            package_sha256,
        })
    }

    pub fn validate_current_toolchain(&self) -> Result<()> {
        if self.schema != ADMITTED_PACKAGE_SCHEMA {
            bail!(
                "admitted package schema mismatch: {} != {}",
                self.schema,
                ADMITTED_PACKAGE_SCHEMA
            );
        }
        if self.source_language != SOURCE_LANGUAGE {
            bail!(
                "admitted package source_language mismatch: {} != {}",
                self.source_language,
                SOURCE_LANGUAGE
            );
        }
        if self.semantics_profile != SEMANTICS_PROFILE {
            bail!(
                "admitted package semantics_profile mismatch: {} != {}",
                self.semantics_profile,
                SEMANTICS_PROFILE
            );
        }
        let expected_toolchain_sha256 =
            ToolchainManifest::current(&self.compiler_version).sha256()?;
        if self.toolchain_manifest_sha256 != expected_toolchain_sha256 {
            bail!("admitted package toolchain_manifest_sha256 mismatch");
        }
        let expected_package_sha256 = self.recomputed_package_sha256()?;
        if self.package_sha256 != expected_package_sha256 {
            bail!("admitted package package_sha256 mismatch");
        }
        Ok(())
    }

    pub fn validate_proof_grade(&self) -> Result<()> {
        self.validate_current_toolchain()?;
        validate_sha256_hex(
            "admitted package raw_metadata_sha256",
            &self.raw_metadata_sha256,
        )?;
        validate_sha256_hex(
            "admitted package metadata_canonicalization_sha256",
            &self.metadata_canonicalization_sha256,
        )?;
        let raw_metadata_sha256 = self.raw_metadata_sha256.as_ref().expect("validated above");
        let expected_canonicalization_sha256 =
            metadata_canonicalization_sha256(raw_metadata_sha256, &self.metadata_sha256)?;
        if self.metadata_canonicalization_sha256.as_ref() != Some(&expected_canonicalization_sha256)
        {
            bail!("admitted package metadata_canonicalization_sha256 mismatch");
        }
        Ok(())
    }

    fn recomputed_package_sha256(&self) -> Result<String> {
        let package_input = AdmittedPackageHashInput {
            schema: ADMITTED_PACKAGE_SCHEMA,
            source_language: &self.source_language,
            semantics_profile: &self.semantics_profile,
            source_sha256: &self.source_sha256,
            metadata_sha256: &self.metadata_sha256,
            raw_metadata_sha256: self.raw_metadata_sha256.as_deref(),
            metadata_canonicalization_sha256: self.metadata_canonicalization_sha256.as_deref(),
            compilation_mode: &self.compilation_mode,
            compiler_version: &self.compiler_version,
            toolchain_manifest_sha256: &self.toolchain_manifest_sha256,
        };
        Ok(sha256_hex(&canonical_json_bytes(&package_input)?))
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ToolchainManifest {
    pub schema: String,
    pub compiler_package: String,
    pub compiler_version: String,
    pub uo_core_version: String,
    pub rust_toolchain_sha256: String,
    pub cargo_lock_sha256: String,
    pub workspace_manifest_sha256: String,
    pub crate_manifests_sha256: String,
    pub solang_parser_version: String,
    pub lean_toolchain_sha256: String,
    pub proof_grade_root_sha256: String,
    pub proof_import_set_sha256: String,
    pub proof_checker_schema: String,
    pub generated_code_sha256: String,
    pub runtime_model_tag: String,
    pub runtime_model_sha256: String,
    pub runtime_binary_model_tag: String,
    pub deployment_attestation_model_tag: String,
    pub deployment_model_sha256: String,
    pub return_channel_session_model_tag: String,
}

impl ToolchainManifest {
    pub fn current(compiler_version: &str) -> Self {
        Self {
            schema: TOOLCHAIN_MANIFEST_SCHEMA.into(),
            compiler_package: "uo-solc".into(),
            compiler_version: compiler_version.into(),
            uo_core_version: env!("CARGO_PKG_VERSION").into(),
            rust_toolchain_sha256: toolchain_env!("UO_TOOLCHAIN_RUST_TOOLCHAIN_SHA256"),
            cargo_lock_sha256: toolchain_env!("UO_TOOLCHAIN_CARGO_LOCK_SHA256"),
            workspace_manifest_sha256: toolchain_env!("UO_TOOLCHAIN_WORKSPACE_MANIFEST_SHA256"),
            crate_manifests_sha256: toolchain_env!("UO_TOOLCHAIN_CRATE_MANIFESTS_SHA256"),
            solang_parser_version: "0.3.3".into(),
            lean_toolchain_sha256: toolchain_env!("UO_TOOLCHAIN_LEAN_TOOLCHAIN_SHA256"),
            proof_grade_root_sha256: toolchain_env!("UO_TOOLCHAIN_PROOF_GRADE_ROOT_SHA256"),
            proof_import_set_sha256: toolchain_env!("UO_TOOLCHAIN_PROOF_IMPORT_SET_SHA256"),
            proof_checker_schema: PROOF_CHECKER_SCHEMA.into(),
            generated_code_sha256: toolchain_env!("UO_TOOLCHAIN_GENERATED_CODE_SHA256"),
            runtime_model_tag: RUNTIME_MODEL_TAG.into(),
            runtime_model_sha256: toolchain_env!("UO_TOOLCHAIN_RUNTIME_MODEL_SHA256"),
            runtime_binary_model_tag: RUNTIME_BINARY_MODEL_TAG.into(),
            deployment_attestation_model_tag: DEPLOYMENT_ATTESTATION_MODEL_TAG.into(),
            deployment_model_sha256: toolchain_env!("UO_TOOLCHAIN_DEPLOYMENT_MODEL_SHA256"),
            return_channel_session_model_tag: RETURN_CHANNEL_SESSION_MODEL_TAG.into(),
        }
    }

    pub fn sha256(&self) -> Result<String> {
        Ok(sha256_hex(&canonical_json_bytes(self)?))
    }
}

#[derive(Serialize)]
struct AdmittedPackageHashInput<'a> {
    schema: &'static str,
    source_language: &'a str,
    semantics_profile: &'a str,
    source_sha256: &'a str,
    metadata_sha256: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    raw_metadata_sha256: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    metadata_canonicalization_sha256: Option<&'a str>,
    compilation_mode: &'a str,
    compiler_version: &'a str,
    toolchain_manifest_sha256: &'a str,
}

#[derive(Serialize)]
struct MetadataCanonicalizationHashInput<'a> {
    schema: &'static str,
    parser: &'static str,
    raw_metadata_sha256: &'a str,
    metadata_sha256: &'a str,
}

fn metadata_canonicalization_sha256(
    raw_metadata_sha256: &str,
    metadata_sha256: &str,
) -> Result<String> {
    let input = MetadataCanonicalizationHashInput {
        schema: RAW_METADATA_CANONICALIZATION_SCHEMA,
        parser: RAW_METADATA_CANONICALIZATION_PARSER,
        raw_metadata_sha256,
        metadata_sha256,
    };
    Ok(sha256_hex(&canonical_json_bytes(&input)?))
}

fn validate_sha256_hex(label: &str, value: &Option<String>) -> Result<()> {
    match value {
        Some(value) if value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit()) => {
            Ok(())
        }
        _ => bail!("{label} must be a 64-character hex SHA-256 digest"),
    }
}

fn canonical_json_bytes<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    let json = serde_json::to_value(value)?;
    Ok(serde_json::to_vec(&canonicalize_json_value(json))?)
}

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

fn sha256_hex(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}

#[cfg(test)]
mod tests {
    use super::{
        AdmittedPackageIdentity, ToolchainManifest, ADMITTED_PACKAGE_SCHEMA, SEMANTICS_PROFILE,
        SOURCE_LANGUAGE,
    };
    use serde::Serialize;

    #[derive(Serialize)]
    struct MetadataA {
        z: u8,
        a: u8,
    }

    #[derive(Serialize)]
    struct MetadataB {
        a: u8,
        z: u8,
    }

    #[test]
    fn admitted_package_identity_uses_canonical_metadata_ordering() {
        let lhs =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        let rhs =
            AdmittedPackageIdentity::new("contract C {}", &MetadataB { a: 1, z: 2 }, "uo", "test")
                .unwrap();
        assert_eq!(lhs.metadata_sha256, rhs.metadata_sha256);
        assert_eq!(lhs.package_sha256, rhs.package_sha256);
    }

    #[test]
    fn admitted_package_identity_binds_raw_metadata_when_supplied() {
        let lhs = AdmittedPackageIdentity::new_with_raw_metadata(
            "contract C {}",
            &MetadataA { z: 2, a: 1 },
            b"z: 2\na: 1\n",
            "uo",
            "test",
        )
        .unwrap();
        let rhs = AdmittedPackageIdentity::new_with_raw_metadata(
            "contract C {}",
            &MetadataB { a: 1, z: 2 },
            b"a: 1\nz: 2\n",
            "uo",
            "test",
        )
        .unwrap();
        assert_eq!(lhs.metadata_sha256, rhs.metadata_sha256);
        assert_ne!(lhs.raw_metadata_sha256, rhs.raw_metadata_sha256);
        assert_ne!(
            lhs.metadata_canonicalization_sha256,
            rhs.metadata_canonicalization_sha256
        );
        assert_ne!(lhs.package_sha256, rhs.package_sha256);
        lhs.validate_proof_grade().unwrap();
    }

    #[test]
    fn admitted_package_identity_binds_current_toolchain_manifest() {
        let identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        let expected_toolchain_sha256 = ToolchainManifest::current("test").sha256().unwrap();
        assert_eq!(identity.schema, ADMITTED_PACKAGE_SCHEMA);
        assert_eq!(identity.source_language, SOURCE_LANGUAGE);
        assert_eq!(
            identity.toolchain_manifest_sha256,
            expected_toolchain_sha256
        );
        assert_eq!(identity.toolchain_manifest_sha256.len(), 64);
        identity.validate_current_toolchain().unwrap();
    }

    #[test]
    fn admitted_package_identity_proof_grade_requires_raw_metadata_witness() {
        let identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        let err = identity.validate_proof_grade().unwrap_err();
        assert!(err
            .to_string()
            .contains("raw_metadata_sha256 must be a 64-character hex SHA-256 digest"));
    }

    #[test]
    fn admitted_package_identity_rejects_canonicalization_witness_tamper() {
        let mut identity = AdmittedPackageIdentity::new_with_raw_metadata(
            "contract C {}",
            &MetadataA { z: 2, a: 1 },
            b"z: 2\na: 1\n",
            "uo",
            "test",
        )
        .unwrap();
        identity.metadata_canonicalization_sha256 = Some("0".repeat(64));
        identity.package_sha256 = identity.recomputed_package_sha256().unwrap();
        let err = identity.validate_proof_grade().unwrap_err();
        assert!(err
            .to_string()
            .contains("metadata_canonicalization_sha256 mismatch"));
    }

    #[test]
    fn admitted_package_identity_rejects_toolchain_digest_tamper() {
        let mut identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        identity.toolchain_manifest_sha256 = "0".repeat(64);
        let err = identity.validate_current_toolchain().unwrap_err();
        assert!(err
            .to_string()
            .contains("toolchain_manifest_sha256 mismatch"));
    }

    #[test]
    fn admitted_package_identity_rejects_source_language_tamper() {
        let mut identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        identity.source_language = "solidity-0.8".into();
        let err = identity.validate_current_toolchain().unwrap_err();
        assert!(err.to_string().contains("source_language mismatch"));
    }

    #[test]
    fn admitted_package_identity_package_hash_covers_source_language() {
        let identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        let mut tampered = identity.clone();
        tampered.source_language = "solidity-0.8".into();
        assert_ne!(
            identity.package_sha256,
            tampered.recomputed_package_sha256().unwrap()
        );
    }

    #[test]
    fn admitted_package_identity_declares_semantics_profile() {
        let identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        assert_eq!(identity.semantics_profile, SEMANTICS_PROFILE);
        identity.validate_current_toolchain().unwrap();
    }

    #[test]
    fn admitted_package_identity_rejects_semantics_profile_tamper() {
        let mut identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        identity.semantics_profile = "solidity-0.8-checked".into();
        let err = identity.validate_current_toolchain().unwrap_err();
        assert!(err.to_string().contains("semantics_profile mismatch"));
    }

    #[test]
    fn admitted_package_identity_package_hash_covers_semantics_profile() {
        let identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        let mut tampered = identity.clone();
        tampered.semantics_profile = "solidity-0.8-checked".into();
        assert_ne!(
            identity.package_sha256,
            tampered.recomputed_package_sha256().unwrap()
        );
    }

    #[test]
    fn admitted_package_identity_package_hash_covers_toolchain_digest() {
        let identity =
            AdmittedPackageIdentity::new("contract C {}", &MetadataA { z: 2, a: 1 }, "uo", "test")
                .unwrap();
        let mut tampered = identity.clone();
        tampered.toolchain_manifest_sha256 = "1".repeat(64);
        assert_ne!(
            identity.package_sha256,
            tampered.recomputed_package_sha256().unwrap()
        );
    }

    #[test]
    fn toolchain_manifest_digest_changes_when_covered_model_field_changes() {
        let manifest = ToolchainManifest::current("test");
        let original = manifest.sha256().unwrap();
        let mut changed = manifest.clone();
        changed.runtime_model_tag.push_str("-tampered");
        assert_ne!(original, changed.sha256().unwrap());

        let mut changed = manifest.clone();
        changed.proof_import_set_sha256 = "2".repeat(64);
        assert_ne!(original, changed.sha256().unwrap());

        let mut changed = manifest;
        changed.generated_code_sha256 = "3".repeat(64);
        assert_ne!(original, changed.sha256().unwrap());
    }
}
