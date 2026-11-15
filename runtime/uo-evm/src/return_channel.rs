use crate::freshness::RuntimeCallFreshness;
use anyhow::{anyhow, bail, Result};
use chacha20poly1305::aead::AeadInPlace;
use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce, Tag};
use hkdf::hmac::{Hmac, Mac};
use hkdf::Hkdf;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::fmt;
use uo_core::{CompiledArtifact, EncryptedReturnPayload, ReturnChannelPublicBinding, Value};
use zeroize::{Zeroize, Zeroizing};

pub const RETURN_CHANNEL_SCHEME: &str = "chacha20poly1305_session_v1";
const NONCE_BYTES: usize = 12;
const TAG_BYTES: usize = 16;
const SHA256_HEX_BYTES: usize = 64;
/// The salt of the key of a production receipt's tag, and the domain of what
/// the tag is computed over.
const PRODUCTION_RECEIPT_TAG_DOMAIN: &[u8] = b"uo-production-receipt-tag/v1";

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

    /// The MAC of the production receipt whose hash is `receipt_sha256`
    /// under this session: HMAC-SHA256 under a key that HKDF derives from
    /// the session's key for receipts alone, so that no tag is a value the
    /// return channel computes. The runtime finishes it into a receipt's
    /// tag, and a caller holding the session into a check of one.
    pub(crate) fn production_receipt_mac(&self, receipt_sha256: &str) -> Result<Hmac<Sha256>> {
        let mut key = Zeroizing::new([0u8; 32]);
        Hkdf::<Sha256>::new(Some(PRODUCTION_RECEIPT_TAG_DOMAIN), &self.key)
            .expand(self.binding.session_id.as_bytes(), key.as_mut_slice())
            .map_err(|_| anyhow!("the key of a production receipt's tag cannot be derived"))?;
        let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(key.as_slice())
            .map_err(|_| anyhow!("the key of a production receipt's tag has the wrong length"))?;
        mac.update(PRODUCTION_RECEIPT_TAG_DOMAIN);
        mac.update(receipt_sha256.as_bytes());
        Ok(mac)
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
    call_freshness: RuntimeCallFreshness,
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
    let nonce = call_freshness.derive_return_nonce(session.binding(), &aad_hash);
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

/// What the client of a session does with an encrypted return. It builds the
/// associated data again from what it knows of the call (the admitted
/// package, the entrypoint, the call's public arguments and its own session
/// binding), checks that the payload is bound to its session and names the
/// hash of that data and the lengths of the entrypoint's return, and opens
/// the ciphertext under the session key. The result is the canonical bytes
/// of the value the call returned. A payload that was not sealed under this
/// session for this call does not open.
pub fn open_encrypted_return(
    artifact: &CompiledArtifact,
    entrypoint: &str,
    public_args: &[String],
    payload: &EncryptedReturnPayload,
    session: &ReturnChannelSession,
) -> Result<Box<[u8]>> {
    let return_canonical_len = artifact
        .contract
        .manifest
        .entrypoints
        .get(entrypoint)
        .ok_or_else(|| anyhow::anyhow!("manifest entry missing for {entrypoint}"))?
        .return_canonical_len
        .ok_or_else(|| {
            anyhow::anyhow!("manifest return_canonical_len missing for encrypted return entrypoint")
        })?;
    if &payload.binding != session.binding() {
        bail!("encrypted return is bound to another session");
    }
    if payload.plaintext_canonical_len != return_canonical_len
        || payload.wire_len != NONCE_BYTES + return_canonical_len + TAG_BYTES
    {
        bail!("encrypted return lengths are not those of {entrypoint}");
    }
    let aad = return_channel_aad_bytes(
        artifact,
        entrypoint,
        return_canonical_len,
        public_args,
        session.binding(),
    )?;
    if payload.aad_hash != hex::encode(Sha256::digest(&aad)) {
        bail!("encrypted return names other associated data");
    }
    let nonce = hex::decode(&payload.nonce)?;
    let tag = hex::decode(&payload.tag)?;
    let mut plaintext = hex::decode(&payload.ciphertext)?;
    if nonce.len() != NONCE_BYTES
        || tag.len() != TAG_BYTES
        || plaintext.len() != return_canonical_len
    {
        bail!("encrypted return has a malformed nonce, tag or ciphertext");
    }
    let cipher = ChaCha20Poly1305::new_from_slice(&session.key)
        .map_err(|_| anyhow::anyhow!("invalid encrypted return channel key length"))?;
    if cipher
        .decrypt_in_place_detached(
            Nonce::from_slice(&nonce),
            &aad,
            plaintext.as_mut_slice(),
            Tag::from_slice(&tag),
        )
        .is_err()
    {
        plaintext.zeroize();
        bail!("encrypted return does not open under this session");
    }
    Ok(plaintext.into_boxed_slice())
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
