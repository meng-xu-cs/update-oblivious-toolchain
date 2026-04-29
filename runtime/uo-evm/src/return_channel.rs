use anyhow::{bail, Result};
use chacha20poly1305::aead::AeadInPlace;
use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce};
use rand::rngs::OsRng;
use rand::RngCore;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::fmt;
use uo_core::{CompiledArtifact, EncryptedReturnPayload, ReturnChannelPublicBinding, Value};
use zeroize::Zeroize;

pub const RETURN_CHANNEL_SCHEME: &str = "chacha20poly1305_session_v1";
const NONCE_BYTES: usize = 12;
const TAG_BYTES: usize = 16;
const SHA256_HEX_BYTES: usize = 64;

#[derive(PartialEq, Eq)]
pub struct ReturnChannelSession {
    key: [u8; 32],
    binding: ReturnChannelPublicBinding,
}

#[derive(Serialize)]
struct ReturnChannelAad<'a> {
    domain: &'static str,
    version: u8,
    package_sha256: &'a str,
    contract: &'a str,
    entrypoint: &'a str,
    return_policy: &'static str,
    return_canonical_len: usize,
    public_args: &'a [String],
    binding: &'a ReturnChannelPublicBinding,
}

impl ReturnChannelSession {
    pub fn new(key: [u8; 32], binding: ReturnChannelPublicBinding) -> Result<Self> {
        validate_binding(&binding)?;
        Ok(Self { key, binding })
    }

    pub fn binding(&self) -> &ReturnChannelPublicBinding {
        &self.binding
    }

    #[cfg(test)]
    pub(crate) fn key_for_test(&self) -> &[u8; 32] {
        &self.key
    }
}

impl fmt::Debug for ReturnChannelSession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ReturnChannelSession")
            .field("key", &"<redacted>")
            .field("binding", &self.binding)
            .finish()
    }
}

impl Drop for ReturnChannelSession {
    fn drop(&mut self) {
        self.key.zeroize();
    }
}

pub(crate) fn encrypt_return_value(
    artifact: &CompiledArtifact,
    entrypoint: &str,
    public_args: &[String],
    value: &Value,
    session: &ReturnChannelSession,
) -> Result<EncryptedReturnPayload> {
    let manifest_entry = artifact
        .contract
        .manifest
        .entrypoints
        .get(entrypoint)
        .ok_or_else(|| anyhow::anyhow!("manifest entry missing for {entrypoint}"))?;
    let return_canonical_len = manifest_entry.return_canonical_len.ok_or_else(|| {
        anyhow::anyhow!("manifest return_canonical_len missing for encrypted return entrypoint")
    })?;
    let mut ciphertext = value.canonical_bytes_boxed()?.into_vec();
    if ciphertext.len() != return_canonical_len {
        bail!(
            "return canonical length mismatch for {}: manifest {}, observed {}",
            entrypoint,
            return_canonical_len,
            ciphertext.len()
        );
    }
    let aad = return_channel_aad_bytes(
        artifact,
        entrypoint,
        return_canonical_len,
        public_args,
        session.binding(),
    )?;
    let aad_hash = hex::encode(Sha256::digest(&aad));
    let mut nonce = [0u8; NONCE_BYTES];
    OsRng.fill_bytes(&mut nonce);
    let cipher = ChaCha20Poly1305::new_from_slice(&session.key)
        .map_err(|_| anyhow::anyhow!("invalid encrypted return channel key length"))?;
    let tag = cipher
        .encrypt_in_place_detached(Nonce::from_slice(&nonce), &aad, ciphertext.as_mut_slice())
        .map_err(|_| anyhow::anyhow!("failed to encrypt return payload"))?;
    let wire_len = NONCE_BYTES + ciphertext.len() + TAG_BYTES;
    Ok(EncryptedReturnPayload {
        binding: session.binding().clone(),
        aad_hash,
        nonce: hex::encode(nonce),
        ciphertext: hex::encode(ciphertext),
        tag: hex::encode(tag.as_slice()),
        plaintext_canonical_len: return_canonical_len,
        wire_len,
    })
}

pub(crate) fn return_channel_aad_bytes(
    artifact: &CompiledArtifact,
    entrypoint: &str,
    return_canonical_len: usize,
    public_args: &[String],
    binding: &ReturnChannelPublicBinding,
) -> Result<Vec<u8>> {
    validate_binding(binding)?;
    let package_sha256 = artifact
        .admitted_package
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("encrypted returns require an admitted package identity"))?
        .package_sha256
        .as_str();
    let aad = ReturnChannelAad {
        domain: "uo-return-channel-aad",
        version: 1,
        package_sha256,
        contract: artifact.contract.contract.as_str(),
        entrypoint,
        return_policy: "encrypted_to_client",
        return_canonical_len,
        public_args,
        binding,
    };
    Ok(serde_json::to_vec(&aad)?)
}

fn validate_binding(binding: &ReturnChannelPublicBinding) -> Result<()> {
    if binding.scheme != RETURN_CHANNEL_SCHEME {
        bail!(
            "unsupported encrypted return channel scheme {}; expected {}",
            binding.scheme,
            RETURN_CHANNEL_SCHEME
        );
    }
    validate_hash_hex("session_id", &binding.session_id)?;
    validate_hash_hex("client_public_key_hash", &binding.client_public_key_hash)?;
    validate_hash_hex(
        "attestation_transcript_hash",
        &binding.attestation_transcript_hash,
    )?;
    Ok(())
}

fn validate_hash_hex(field: &str, value: &str) -> Result<()> {
    if value.len() != SHA256_HEX_BYTES || !value.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        bail!("{field} must be a 32-byte SHA-256 hex string");
    }
    Ok(())
}
