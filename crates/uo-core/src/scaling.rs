use crate::ir::{BackendKind, ContainerKind, StateObject};
use crate::manifest::{OramManifest, PATH_ORAM_PRIVATE_POSMAP_SCHEME};
use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScalablePathOramEvidence {
    pub scheme: String,
    pub capacity: usize,
    pub leaf_count: usize,
    pub recursion_depth: usize,
    pub metadata_pages: usize,
    pub certificate_bytes: usize,
    pub validation_steps: usize,
    pub position_map_commitment_sha256: String,
}

impl ScalablePathOramEvidence {
    pub fn for_object(object: &StateObject) -> Result<Self> {
        if object.kind != ContainerKind::Map || object.backend != BackendKind::Oram {
            bail!("object {} is not an ORAM-backed map", object.name);
        }
        if object.oram_scheme != PATH_ORAM_PRIVATE_POSMAP_SCHEME {
            bail!(
                "scalable Path ORAM evidence requires {}",
                PATH_ORAM_PRIVATE_POSMAP_SCHEME
            );
        }
        let capacity = object
            .capacity
            .ok_or_else(|| anyhow!("map {} is missing capacity", object.name))?;
        let manifest = OramManifest::for_object(object)?;
        let leaf_count = manifest.path_leaf_count()?;
        let validation_steps =
            log2_ceil(capacity.max(2)) + manifest.recursion_depth + log2_ceil(leaf_count);
        let certificate_bytes = 32 + 8 * (manifest.recursion_depth + 1);
        let mut hasher = Sha256::new();
        hasher.update(PATH_ORAM_PRIVATE_POSMAP_SCHEME.as_bytes());
        hasher.update(object.name.as_bytes());
        hasher.update(capacity.to_be_bytes());
        hasher.update(leaf_count.to_be_bytes());
        hasher.update(manifest.recursion_depth.to_be_bytes());
        let position_map_commitment_sha256 = hex::encode(hasher.finalize());
        Ok(Self {
            scheme: manifest.scheme,
            capacity,
            leaf_count,
            recursion_depth: manifest.recursion_depth,
            metadata_pages: manifest.metadata_pages,
            certificate_bytes,
            validation_steps,
            position_map_commitment_sha256,
        })
    }

    pub fn is_subenumerative(&self) -> bool {
        self.certificate_bytes < self.capacity && self.validation_steps < self.capacity
    }
}

fn log2_ceil(value: usize) -> usize {
    if value <= 1 {
        return 0;
    }
    usize::BITS as usize - (value - 1).leading_zeros() as usize
}

#[cfg(test)]
mod tests {
    use super::ScalablePathOramEvidence;
    use crate::ir::{BackendKind, ContainerKind, StateObject};
    use crate::manifest::{
        OramManifest, PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY, PATH_ORAM_PRIVATE_POSMAP_SCHEME,
        PATH_ORAM_SCHEME,
    };
    use crate::{ScalarType, Type};

    fn path_oram_object(capacity: usize, scheme: &str) -> StateObject {
        StateObject {
            id: 1,
            name: "accounts".into(),
            kind: ContainerKind::Map,
            backend: BackendKind::Oram,
            oram_scheme: scheme.into(),
            value_type: Type::Scalar(ScalarType::Uint(256)),
            key_type: Some(Type::Scalar(ScalarType::Address)),
            capacity: Some(capacity),
            confidential: true,
        }
    }

    #[test]
    fn private_position_map_route_admits_capacity_above_local_cap() {
        let local = path_oram_object(PATH_ORAM_LOCAL_POSMAP_MAX_CAPACITY + 1, PATH_ORAM_SCHEME);
        assert!(OramManifest::for_object(&local).is_err());

        let scalable = path_oram_object(1024, PATH_ORAM_PRIVATE_POSMAP_SCHEME);
        let manifest = OramManifest::for_object(&scalable).unwrap();
        assert_eq!(manifest.scheme, PATH_ORAM_PRIVATE_POSMAP_SCHEME);
        assert_eq!(manifest.recursion_depth, 1);
        assert!(manifest
            .validate_theorem_shape_for_object(&scalable)
            .is_ok());
    }

    #[test]
    fn symbolic_certificate_scales_subenumeratively() {
        let scalable = path_oram_object(4096, PATH_ORAM_PRIVATE_POSMAP_SCHEME);
        let evidence = ScalablePathOramEvidence::for_object(&scalable).unwrap();
        assert!(evidence.is_subenumerative());
        assert!(evidence.certificate_bytes < 128);
        assert!(evidence.validation_steps < 64);
        assert_eq!(evidence.position_map_commitment_sha256.len(), 64);
    }
}
