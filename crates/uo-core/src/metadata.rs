use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ContractMetadata {
    pub contract: String,
    #[serde(default)]
    pub entrypoints: BTreeMap<String, EntrypointMetadata>,
    #[serde(default)]
    pub state: BTreeMap<String, StateMetadata>,
    #[serde(default)]
    pub bounds: BoundsMetadata,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct EntrypointMetadata {
    #[serde(default)]
    pub secret_args: Vec<String>,
    #[serde(default)]
    pub public_gas_budget: Option<u64>,
    #[serde(default)]
    pub confidential: Option<bool>,
    #[serde(default)]
    pub returns: Option<ReturnPolicy>,
    #[serde(default)]
    pub status: Option<StatusPolicy>,
    #[serde(default)]
    pub declassifies: Vec<DeclassificationKind>,
    #[serde(default)]
    pub public_state_declassifies: Vec<String>,
    #[serde(default)]
    pub initializer: bool,
    #[serde(default)]
    pub requires_initialized: Option<bool>,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum ReturnPolicy {
    #[default]
    Forbidden,
    Public,
    Declassified,
    EncryptedToClient,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum StatusPolicy {
    #[default]
    Public,
    Declassified,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum DeclassificationKind {
    Return,
    Success,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct StateMetadata {
    pub kind: String,
    #[serde(default)]
    pub key: Option<String>,
    pub value: String,
    #[serde(default)]
    pub capacity: Option<usize>,
    pub backend: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub oram_scheme: Option<String>,
    pub confidential: bool,
    /// For a map whose backend is `auto`: what the backend planner reads
    /// besides the map's capacity and types (`uo_core::backend_plan`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub plan: Option<BackendPlanMetadata>,
}

/// What a map whose backend is `auto` declares to the backend planner.
#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct BackendPlanMetadata {
    /// Reads among the map's operations, in percent: 50 if absent.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub read_percent: Option<u64>,
    /// The enclave memory a call may hold for the map, in bytes.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub enclave_memory_budget_bytes: Option<usize>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct BoundsMetadata {
    #[serde(default)]
    pub loops: BTreeMap<String, usize>,
}

#[cfg(test)]
mod tests {
    use super::ContractMetadata;

    #[test]
    fn sidecar_rejects_unknown_top_level_field() {
        let err = serde_yaml::from_str::<ContractMetadata>(
            r#"
contract: C
unexpected: true
entrypoints: {}
state: {}
bounds:
  loops: {}
"#,
        )
        .unwrap_err();
        assert!(err.to_string().contains("unknown field"));
    }

    #[test]
    fn sidecar_rejects_unknown_entrypoint_field() {
        let err = serde_yaml::from_str::<ContractMetadata>(
            r#"
contract: C
entrypoints:
  f():
    confidential: false
    returns: forbidden
    status: public
    declassify_public_state: [x]
state: {}
bounds:
  loops: {}
"#,
        )
        .unwrap_err();
        assert!(err.to_string().contains("unknown field"));
    }

    #[test]
    fn sidecar_rejects_unknown_state_field() {
        let err = serde_yaml::from_str::<ContractMetadata>(
            r#"
contract: C
entrypoints: {}
state:
  x:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
    storage_class: public
bounds:
  loops: {}
"#,
        )
        .unwrap_err();
        assert!(err.to_string().contains("unknown field"));
    }

    #[test]
    fn sidecar_rejects_unknown_bounds_field() {
        let err = serde_yaml::from_str::<ContractMetadata>(
            r#"
contract: C
entrypoints: {}
state: {}
bounds:
  loops: {}
  max_steps: 5
"#,
        )
        .unwrap_err();
        assert!(err.to_string().contains("unknown field"));
    }
}
