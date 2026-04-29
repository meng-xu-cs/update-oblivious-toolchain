use crate::ir::CompiledContract;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use sha2::{Digest, Sha256};

pub const ADMITTED_PACKAGE_SCHEMA: &str = "uo-admitted-package-v2";

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
    pub source_sha256: String,
    pub metadata_sha256: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub raw_metadata_sha256: Option<String>,
    pub compilation_mode: String,
    pub compiler_version: String,
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
        let package_input = AdmittedPackageHashInput {
            schema: ADMITTED_PACKAGE_SCHEMA,
            source_sha256: &source_sha256,
            metadata_sha256: &metadata_sha256,
            raw_metadata_sha256: raw_metadata_sha256.as_deref(),
            compilation_mode,
            compiler_version,
        };
        let package_sha256 = sha256_hex(&canonical_json_bytes(&package_input)?);
        Ok(Self {
            schema: ADMITTED_PACKAGE_SCHEMA.into(),
            source_sha256,
            metadata_sha256,
            raw_metadata_sha256,
            compilation_mode: compilation_mode.into(),
            compiler_version: compiler_version.into(),
            package_sha256,
        })
    }
}

#[derive(Serialize)]
struct AdmittedPackageHashInput<'a> {
    schema: &'static str,
    source_sha256: &'a str,
    metadata_sha256: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    raw_metadata_sha256: Option<&'a str>,
    compilation_mode: &'a str,
    compiler_version: &'a str,
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
    use super::AdmittedPackageIdentity;
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
        assert_ne!(lhs.package_sha256, rhs.package_sha256);
    }
}
