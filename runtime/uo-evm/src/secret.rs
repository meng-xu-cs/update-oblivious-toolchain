//! The runtime's master secret and the secrets that derive from it.
//!
//! A deployment draws one 256-bit master secret from the operating system.
//! Each object's secret derives from it, and from that the seed of the
//! generator that draws the object's storage key and initial placement, and
//! the seed of its Path ORAM leaf coins. Every derivation is an HKDF-SHA256
//! expansion with its own label.
//!
//! Nothing public derives from the master secret. The freshness epoch that
//! production call evidence carries is drawn independently of it.
//!
//! A production deployment seals its master secret to its platform, so that
//! it can restart from its store: the master secret, encrypted under a key
//! that derives from the platform's sealing key, opens only on the same
//! platform and only for the deployment it was sealed for.

use crate::deployment::{SealedMasterSecret, SEALED_MASTER_SECRET_SCHEME};
use anyhow::{anyhow, bail, Result};
use chacha20poly1305::aead::AeadInPlace;
use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce, Tag};
use hkdf::Hkdf;
use rand::rngs::OsRng;
use rand::{RngCore, SeedableRng};
use rand_chacha::ChaCha20Rng;
use sha2::Sha256;
use std::fmt;
use zeroize::{Zeroize, Zeroizing};

const SECRET_BYTES: usize = 32;

const OBJECT_SECRET_LABEL: &[u8] = b"uo-runtime/object-secret/v1";
const OBJECT_RNG_SEED_LABEL: &[u8] = b"uo-runtime/object-rng-seed/v1";
const PATH_ORAM_LEAF_SEED_LABEL: &[u8] = b"uo-runtime/path-oram-leaf-seed/v1";
const PATH_ORAM_LEAF_LABEL: &[u8] = b"uo-runtime/path-oram-leaf/v1";
const STORE_META_KEY_LABEL: &[u8] = b"uo-runtime/store-meta-key/v1";
const STORE_META_TAG_LABEL: &[u8] = b"uo-runtime/store-meta-tag/v1";
const PLATFORM_SEAL_KEY_LABEL: &[u8] = b"uo-runtime/platform-seal-key/v1";
const SEAL_NONCE_BYTES: usize = 12;
const SEAL_TAG_BYTES: usize = 16;
#[cfg(any(test, feature = "diagnostics"))]
const DIAGNOSTIC_MASTER_SECRET_LABEL: &[u8] = b"uo-runtime/diagnostic-master-secret/v1";

/// HKDF-SHA256 expansion of a 32-byte key. The context is the label and then
/// each part, every one prefixed with its length, so that two different
/// contexts never encode to the same bytes.
fn expand(key: &[u8; SECRET_BYTES], label: &[u8], parts: &[&[u8]], out: &mut [u8]) -> Result<()> {
    let mut info = Vec::with_capacity(
        8 + label.len() + parts.iter().map(|part| 8 + part.len()).sum::<usize>(),
    );
    info.extend_from_slice(&(label.len() as u64).to_be_bytes());
    info.extend_from_slice(label);
    for part in parts {
        info.extend_from_slice(&(part.len() as u64).to_be_bytes());
        info.extend_from_slice(part);
    }
    Hkdf::<Sha256>::from_prk(key)
        .map_err(|_| anyhow!("runtime key derivation rejected its key length"))?
        .expand(&info, out)
        .map_err(|_| anyhow!("runtime key derivation rejected its output length"))
}

fn derive(key: &[u8; SECRET_BYTES], label: &[u8], parts: &[&[u8]]) -> Result<[u8; SECRET_BYTES]> {
    let mut out = [0u8; SECRET_BYTES];
    expand(key, label, parts, &mut out)?;
    Ok(out)
}

/// A secret that a test or a diagnostics run can reproduce: the HKDF-SHA256
/// extraction of a public seed under a label. It protects nothing.
#[cfg(any(test, feature = "diagnostics"))]
fn diagnostic_secret(label: &[u8], seed: u64) -> [u8; SECRET_BYTES] {
    let (secret, _) = Hkdf::<Sha256>::extract(Some(label), &seed.to_be_bytes());
    secret.into()
}

/// The root of a deployment's secrets. It has no `Clone` and no
/// serialization, its `Debug` form shows nothing, and it is wiped on drop.
pub(crate) struct RuntimeMasterSecret([u8; SECRET_BYTES]);

impl Drop for RuntimeMasterSecret {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

impl fmt::Debug for RuntimeMasterSecret {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("RuntimeMasterSecret(<redacted>)")
    }
}

impl RuntimeMasterSecret {
    pub(crate) fn from_os_rng() -> Self {
        let mut secret = [0u8; SECRET_BYTES];
        OsRng.fill_bytes(&mut secret);
        Self(secret)
    }

    /// The master secret of a seeded deployment, which a test or a
    /// diagnostics run can replay. It is a function of a public seed.
    #[cfg(any(test, feature = "diagnostics"))]
    pub(crate) fn from_diagnostic_seed(seed: u64) -> Self {
        Self(diagnostic_secret(DIAGNOSTIC_MASTER_SECRET_LABEL, seed))
    }

    pub(crate) fn object_secret(&self, object_id: u32, object_name: &str) -> Result<ObjectSecret> {
        Ok(ObjectSecret(derive(
            &self.0,
            OBJECT_SECRET_LABEL,
            &[&object_id.to_be_bytes(), object_name.as_bytes()],
        )?))
    }

    pub(crate) fn store_meta_key(&self) -> Result<StoreMetaKey> {
        Ok(StoreMetaKey(derive(&self.0, STORE_META_KEY_LABEL, &[])?))
    }

    /// Seal the master secret to `platform` for the deployment whose request
    /// hash is `deployment`, under a nonce drawn from the operating system:
    /// a deployment seals its secret once.
    pub(crate) fn seal_to_platform(
        &self,
        platform: &PlatformSealingKey,
        deployment: &str,
    ) -> Result<SealedMasterSecret> {
        let mut nonce = [0u8; SEAL_NONCE_BYTES];
        OsRng.fill_bytes(&mut nonce);
        let mut sealed = Zeroizing::new(self.0);
        let tag = platform_seal_cipher(platform)?
            .encrypt_in_place_detached(
                Nonce::from_slice(&nonce),
                deployment.as_bytes(),
                sealed.as_mut_slice(),
            )
            .map_err(|_| anyhow!("the master secret could not be sealed"))?;
        Ok(SealedMasterSecret {
            scheme: SEALED_MASTER_SECRET_SCHEME.into(),
            nonce: hex::encode(nonce),
            ciphertext: hex::encode(sealed.as_slice()),
            tag: hex::encode(tag),
        })
    }

    /// The master secret `sealed` holds, if it opens under `platform` for
    /// the deployment whose request hash is `deployment`. It does not open
    /// on another platform, for another deployment, or changed in any byte;
    /// the error says which of these is not known and names no value.
    pub(crate) fn unseal_from_platform(
        sealed: &SealedMasterSecret,
        platform: &PlatformSealingKey,
        deployment: &str,
    ) -> Result<Self> {
        if sealed.scheme != SEALED_MASTER_SECRET_SCHEME {
            bail!("the sealed master secret has an unknown scheme");
        }
        let decode = |hex_bytes: &str, len: usize| -> Result<Vec<u8>> {
            let bytes = hex::decode(hex_bytes)
                .map_err(|_| anyhow!("the sealed master secret is not hex"))?;
            if bytes.len() != len {
                bail!("the sealed master secret has the wrong length");
            }
            Ok(bytes)
        };
        let nonce = decode(&sealed.nonce, SEAL_NONCE_BYTES)?;
        let tag = decode(&sealed.tag, SEAL_TAG_BYTES)?;
        let mut secret = Zeroizing::new([0u8; SECRET_BYTES]);
        secret.copy_from_slice(&decode(&sealed.ciphertext, SECRET_BYTES)?);
        platform_seal_cipher(platform)?
            .decrypt_in_place_detached(
                Nonce::from_slice(&nonce),
                deployment.as_bytes(),
                secret.as_mut_slice(),
                Tag::from_slice(&tag),
            )
            .map_err(|_| {
                anyhow!(
                    "the sealed master secret does not open on this platform for this deployment"
                )
            })?;
        Ok(Self(*secret))
    }
}

/// The key a platform gives an enclave to seal data to itself. On SGX it is
/// the sealing key that `EGETKEY` derives for the enclave's measurement on
/// the platform: only the same enclave on the same platform derives it
/// again. The runtime takes it from the platform and relies on that (the
/// TEE deployment assumption `platformSealing`). It has no `Clone` and no
/// serialization, its `Debug` form shows nothing, and it is wiped on drop.
pub struct PlatformSealingKey([u8; SECRET_BYTES]);

impl PlatformSealingKey {
    /// The key the platform handed the enclave.
    pub fn from_platform(key: [u8; SECRET_BYTES]) -> Self {
        Self(key)
    }
}

impl Drop for PlatformSealingKey {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

impl fmt::Debug for PlatformSealingKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("PlatformSealingKey(<redacted>)")
    }
}

/// The cipher of a platform's sealing key.
fn platform_seal_cipher(platform: &PlatformSealingKey) -> Result<ChaCha20Poly1305> {
    let key = Zeroizing::new(derive(&platform.0, PLATFORM_SEAL_KEY_LABEL, &[])?);
    ChaCha20Poly1305::new_from_slice(key.as_slice())
        .map_err(|_| anyhow!("the platform seal key has the wrong length"))
}

/// The key under which a deployment authenticates the public metadata it
/// leaves in its store with every commit: its freshness counters and the
/// digest of its public state. A runtime that restarts from the store
/// derives the key again and takes metadata only with its tag. It has no
/// `Clone` and no serialization, its `Debug` form shows nothing, and it is
/// wiped on drop.
pub(crate) struct StoreMetaKey([u8; SECRET_BYTES]);

impl Drop for StoreMetaKey {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

impl fmt::Debug for StoreMetaKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("StoreMetaKey(<redacted>)")
    }
}

impl StoreMetaKey {
    /// The tag of `meta`: an HKDF-SHA256 expansion of the key over it, which
    /// is a pseudo-random function of the metadata.
    pub(crate) fn tag(&self, meta: &[u8]) -> Result<[u8; SECRET_BYTES]> {
        derive(&self.0, STORE_META_TAG_LABEL, &[meta])
    }
}

/// One object's secret: the root of its storage key, of its initial
/// placement and of its Path ORAM leaf coins.
pub(crate) struct ObjectSecret([u8; SECRET_BYTES]);

impl Drop for ObjectSecret {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

impl ObjectSecret {
    #[cfg(test)]
    pub(crate) fn from_diagnostic_seed(seed: u64) -> Self {
        const DIAGNOSTIC_OBJECT_SECRET_LABEL: &[u8] = b"uo-runtime/diagnostic-object-secret/v1";
        Self(diagnostic_secret(DIAGNOSTIC_OBJECT_SECRET_LABEL, seed))
    }

    /// The generator that draws the object's storage key and its initial
    /// placement. Its seed is 256 bits derived from the object's secret.
    pub(crate) fn rng(&self) -> Result<ChaCha20Rng> {
        let mut seed = self.rng_seed()?;
        let rng = ChaCha20Rng::from_seed(seed);
        seed.zeroize();
        Ok(rng)
    }

    fn rng_seed(&self) -> Result<[u8; SECRET_BYTES]> {
        derive(&self.0, OBJECT_RNG_SEED_LABEL, &[])
    }

    pub(crate) fn path_oram_leaf_seed(&self) -> Result<PathOramLeafSeed> {
        Ok(PathOramLeafSeed(derive(
            &self.0,
            PATH_ORAM_LEAF_SEED_LABEL,
            &[],
        )?))
    }
}

/// The seed of a Path ORAM map's leaf coins. It has no `Clone`: a second
/// handle is made by `duplicate`, where a call stages its copy of the map.
pub(crate) struct PathOramLeafSeed([u8; SECRET_BYTES]);

impl Drop for PathOramLeafSeed {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

impl fmt::Debug for PathOramLeafSeed {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("PathOramLeafSeed(<redacted>)")
    }
}

impl PathOramLeafSeed {
    #[cfg(test)]
    pub(crate) fn from_diagnostic_seed(seed: u64) -> Self {
        const DIAGNOSTIC_LEAF_SEED_LABEL: &[u8] = b"uo-runtime/diagnostic-path-oram-leaf-seed/v1";
        Self(diagnostic_secret(DIAGNOSTIC_LEAF_SEED_LABEL, seed))
    }

    pub(crate) fn duplicate(&self) -> Self {
        Self(self.0)
    }

    pub(crate) fn wipe(&mut self) {
        self.0.zeroize();
    }
}

/// The coin of one draw of a Path ORAM map: a leaf below `leaf_count`. The
/// draw is named by the map's access counter and by the coin's index within
/// the call. A leaf count is a power of two, so reducing 64 pseudo-random
/// bits to it is exact.
pub(crate) fn derive_path_oram_leaf(
    seed: &PathOramLeafSeed,
    object_id: u32,
    object_name: &str,
    access_counter: u64,
    coin_counter: u64,
    leaf_count: usize,
) -> Result<usize> {
    let mut word = [0u8; 8];
    expand(
        &seed.0,
        PATH_ORAM_LEAF_LABEL,
        &[
            &object_id.to_be_bytes(),
            object_name.as_bytes(),
            &access_counter.to_be_bytes(),
            &coin_counter.to_be_bytes(),
        ],
        &mut word,
    )?;
    let leaf_count = u64::try_from(leaf_count.max(1))
        .map_err(|_| anyhow!("path ORAM leaf count does not fit 64 bits"))?;
    let leaf = u64::from_be_bytes(word) % leaf_count;
    word.zeroize();
    usize::try_from(leaf).map_err(|_| anyhow!("path ORAM leaf does not fit the platform word"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derivations_are_separated_by_label_object_and_counter() {
        let master = RuntimeMasterSecret::from_diagnostic_seed(7);
        let records = master.object_secret(1, "records").unwrap();
        assert_ne!(records.0, master.object_secret(2, "records").unwrap().0);
        assert_ne!(records.0, master.object_secret(1, "record").unwrap().0);
        let leaf_seed = records.path_oram_leaf_seed().unwrap();
        assert_ne!(records.rng_seed().unwrap(), leaf_seed.0);
        assert_ne!(records.rng_seed().unwrap(), records.0);

        let leaf = |access, coin| {
            derive_path_oram_leaf(&leaf_seed, 1, "records", access, coin, 1 << 14).unwrap()
        };
        let first: Vec<usize> = (0..32).map(|coin| leaf(0, coin)).collect();
        let second: Vec<usize> = (0..32).map(|coin| leaf(1, coin)).collect();
        assert!(first.iter().chain(&second).all(|leaf| *leaf < (1 << 14)));
        assert_ne!(first, second);
        assert_ne!(
            first,
            (32..64).map(|coin| leaf(0, coin)).collect::<Vec<usize>>()
        );
        assert_ne!(
            leaf(5, 3),
            derive_path_oram_leaf(&leaf_seed, 2, "records", 5, 3, 1 << 14).unwrap()
        );
        assert_eq!(
            leaf(5, 3),
            derive_path_oram_leaf(&leaf_seed.duplicate(), 1, "records", 5, 3, 1 << 14).unwrap()
        );
    }

    #[test]
    fn os_secrets_differ_and_seeded_secrets_repeat() {
        assert_ne!(
            RuntimeMasterSecret::from_os_rng().0,
            RuntimeMasterSecret::from_os_rng().0
        );
        assert_eq!(
            RuntimeMasterSecret::from_diagnostic_seed(9).0,
            RuntimeMasterSecret::from_diagnostic_seed(9).0
        );
        assert_ne!(
            RuntimeMasterSecret::from_diagnostic_seed(9).0,
            RuntimeMasterSecret::from_diagnostic_seed(10).0
        );
    }

    #[test]
    fn secrets_do_not_show_in_debug_and_are_wiped() {
        let master = RuntimeMasterSecret::from_diagnostic_seed(3);
        assert_eq!(format!("{master:?}"), "RuntimeMasterSecret(<redacted>)");
        let mut leaf_seed = master
            .object_secret(1, "records")
            .unwrap()
            .path_oram_leaf_seed()
            .unwrap();
        assert_eq!(format!("{leaf_seed:?}"), "PathOramLeafSeed(<redacted>)");
        leaf_seed.wipe();
        assert_eq!(leaf_seed.0, [0u8; SECRET_BYTES]);
    }

    /// A master secret sealed to a platform opens there, for its own
    /// deployment, to the same secret: the same store-metadata key derives
    /// from it. It opens on no other platform, for no other deployment, and
    /// with no byte of it changed; its sealed form shows no byte of the
    /// secret, and two seals of it differ.
    #[test]
    fn a_master_secret_sealed_to_its_platform_opens_there_alone() {
        let master = RuntimeMasterSecret::from_diagnostic_seed(5);
        let platform = PlatformSealingKey::from_platform([0x5A; SECRET_BYTES]);
        let deployment = "ab".repeat(32);
        let sealed = master.seal_to_platform(&platform, &deployment).unwrap();
        assert_eq!(sealed.scheme, SEALED_MASTER_SECRET_SCHEME);
        assert!(!sealed.ciphertext.contains(&hex::encode(master.0)));
        assert_ne!(
            master.seal_to_platform(&platform, &deployment).unwrap(),
            sealed
        );
        let opened =
            RuntimeMasterSecret::unseal_from_platform(&sealed, &platform, &deployment).unwrap();
        assert_eq!(opened.0, master.0);
        let meta = b"commit metadata";
        assert_eq!(
            opened.store_meta_key().unwrap().tag(meta).unwrap(),
            master.store_meta_key().unwrap().tag(meta).unwrap()
        );

        let other_platform = PlatformSealingKey::from_platform([0x5B; SECRET_BYTES]);
        assert!(
            RuntimeMasterSecret::unseal_from_platform(&sealed, &other_platform, &deployment)
                .is_err()
        );
        assert!(
            RuntimeMasterSecret::unseal_from_platform(&sealed, &platform, &"cd".repeat(32))
                .is_err()
        );
        for field in 0..3 {
            let mut changed = sealed.clone();
            let part = match field {
                0 => &mut changed.nonce,
                1 => &mut changed.ciphertext,
                _ => &mut changed.tag,
            };
            let first = u8::from_str_radix(&part[..2], 16).unwrap() ^ 1;
            part.replace_range(..2, &format!("{first:02x}"));
            assert!(
                RuntimeMasterSecret::unseal_from_platform(&changed, &platform, &deployment)
                    .is_err(),
                "field {field}"
            );
        }
        let mut renamed = sealed.clone();
        renamed.scheme = "another".into();
        assert!(
            RuntimeMasterSecret::unseal_from_platform(&renamed, &platform, &deployment).is_err()
        );
        assert_eq!(format!("{platform:?}"), "PlatformSealingKey(<redacted>)");
    }

    /// RFC 5869, test case 1: the expansion this module relies on is the
    /// standard one.
    #[test]
    fn hkdf_sha256_matches_rfc_5869_test_case_1() {
        let ikm = [0x0bu8; 22];
        let salt: Vec<u8> = (0x00u8..=0x0c).collect();
        let info: Vec<u8> = (0xf0u8..=0xf9).collect();
        let mut okm = [0u8; 42];
        Hkdf::<Sha256>::new(Some(&salt), &ikm)
            .expand(&info, &mut okm)
            .unwrap();
        assert_eq!(
            hex::encode(okm),
            "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"
        );
    }
}
