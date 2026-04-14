use chacha20poly1305::aead::{Aead, Payload};
use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce};
use rand::rngs::OsRng;
use rand::RngCore;
use rand_chacha::ChaCha20Rng;
use std::fmt;

#[derive(Clone, Debug)]
pub struct NonZeroCodec;

impl NonZeroCodec {
    pub fn encode_bytes(payload: &[u8]) -> Vec<u8> {
        let mut out = Vec::with_capacity(payload.len() * 2);
        push_nonzero_encoded(&mut out, payload);
        out
    }

    pub fn decode_bytes(byte_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
        if encoded.len() != byte_len * 2 {
            return None;
        }
        let decoded = decode_nonzero(encoded)?;
        if decoded.len() != byte_len {
            return None;
        }
        Some(decoded)
    }
}

const SEALED_MAGIC: [u8; 2] = [0xA5, 0x5A];
const SEALED_NONCE_BYTES: usize = 12;
const SEALED_TAG_BYTES: usize = 16;

#[derive(Clone, PartialEq, Eq)]
pub struct StoreCipher {
    key: [u8; 32],
}

impl fmt::Debug for StoreCipher {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("StoreCipher")
            .field("key", &"<redacted>")
            .finish()
    }
}

impl StoreCipher {
    pub fn from_rng<R: RngCore>(rng: &mut R) -> Self {
        let mut key = [0u8; 32];
        rng.fill_bytes(&mut key);
        Self { key }
    }

    pub fn random() -> Self {
        let mut rng = OsRng;
        Self::from_rng(&mut rng)
    }

    pub fn seal(&self, aad: &[u8], payload: &[u8], rng: &mut ChaCha20Rng) -> Vec<u8> {
        let mut nonce_bytes = [0u8; SEALED_NONCE_BYTES];
        rng.fill_bytes(&mut nonce_bytes);
        let cipher = ChaCha20Poly1305::new_from_slice(&self.key).expect("fixed-size key");
        let ciphertext = cipher
            .encrypt(
                Nonce::from_slice(&nonce_bytes),
                Payload { msg: payload, aad },
            )
            .expect("fixed-size nonce");
        let mut sealed =
            Vec::with_capacity(SEALED_MAGIC.len() + nonce_bytes.len() + ciphertext.len());
        sealed.extend_from_slice(&SEALED_MAGIC);
        sealed.extend_from_slice(&nonce_bytes);
        sealed.extend_from_slice(&ciphertext);
        NonZeroCodec::encode_bytes(&sealed)
    }

    pub fn filler(&self, aad: &[u8], len: usize, rng: &mut ChaCha20Rng) -> Vec<u8> {
        self.seal(aad, &vec![0u8; len], rng)
    }

    pub fn open(&self, aad: &[u8], payload_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
        let sealed_len = SEALED_MAGIC.len() + SEALED_NONCE_BYTES + payload_len + SEALED_TAG_BYTES;
        let sealed = NonZeroCodec::decode_bytes(sealed_len, encoded)?;
        let (magic, rest) = sealed.split_at(SEALED_MAGIC.len());
        if magic != SEALED_MAGIC {
            return None;
        }
        let (nonce_bytes, ciphertext) = rest.split_at(SEALED_NONCE_BYTES);
        let cipher = ChaCha20Poly1305::new_from_slice(&self.key).ok()?;
        cipher
            .decrypt(
                Nonce::from_slice(nonce_bytes),
                Payload {
                    msg: ciphertext,
                    aad,
                },
            )
            .ok()
    }
}

fn push_nonzero_encoded(out: &mut Vec<u8>, bytes: &[u8]) {
    for byte in bytes {
        out.push((byte >> 4) + 1);
        out.push((byte & 0x0F) + 1);
    }
}

fn decode_nonzero(encoded: &[u8]) -> Option<Vec<u8>> {
    if encoded.len() % 2 != 0 {
        return None;
    }
    let mut out = Vec::with_capacity(encoded.len() / 2);
    for chunk in encoded.chunks_exact(2) {
        let hi = *chunk.first()?;
        let lo = *chunk.get(1)?;
        if hi == 0 || hi > 16 || lo == 0 || lo > 16 {
            return None;
        }
        out.push(((hi - 1) << 4) | (lo - 1));
    }
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::{NonZeroCodec, StoreCipher};
    use rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;

    #[test]
    fn nonzero_transport_records_are_always_nonzero() {
        let encoded = NonZeroCodec::encode_bytes(&[0u8, 0xFF, 0x11]);
        assert!(encoded.iter().all(|byte| *byte != 0));
    }

    #[test]
    fn nonzero_transport_roundtrips_payload() {
        let payload = [0u8, 0xAB, 0xCD, 0xEF];
        let encoded = NonZeroCodec::encode_bytes(&payload);
        assert_eq!(
            NonZeroCodec::decode_bytes(payload.len(), &encoded),
            Some(payload.to_vec())
        );
    }

    #[test]
    fn sealed_codec_roundtrips_payload() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(11);
        let payload = [0u8, 0xAB, 0xCD, 0xEF];
        let encoded = cipher.seal(b"object:slot", &payload, &mut rng);
        assert_eq!(
            cipher.open(b"object:slot", payload.len(), &encoded),
            Some(payload.to_vec())
        );
    }

    #[test]
    fn sealed_codec_rejects_tampering() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(29);
        let encoded = cipher.seal(b"object:slot", &[1u8, 2u8, 3u8], &mut rng);
        let mut tampered = encoded.clone();
        tampered[5] ^= 0x01;
        assert_eq!(cipher.open(b"object:slot", 3, &tampered), None);
    }

    #[test]
    fn cipher_from_rng_is_seed_deterministic() {
        let mut lhs = ChaCha20Rng::seed_from_u64(41);
        let mut rhs = ChaCha20Rng::seed_from_u64(41);
        let cipher_lhs = StoreCipher::from_rng(&mut lhs);
        let cipher_rhs = StoreCipher::from_rng(&mut rhs);
        let payload = [7u8, 8u8, 9u8];
        let encoded_lhs = cipher_lhs.seal(b"object:slot", &payload, &mut lhs);
        let encoded_rhs = cipher_rhs.seal(b"object:slot", &payload, &mut rhs);
        assert_eq!(encoded_lhs, encoded_rhs);
        assert_eq!(
            cipher_lhs.open(b"object:slot", payload.len(), &encoded_lhs),
            Some(payload.to_vec())
        );
    }
}
