use chacha20poly1305::aead::{Aead, AeadInPlace, Payload};
use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce};
use rand::rngs::OsRng;
use rand::RngCore;
use rand_chacha::ChaCha20Rng;
use std::fmt;
use zeroize::Zeroize;

#[derive(Clone, Debug)]
struct NonZeroCodec;

impl NonZeroCodec {
    fn encode_bytes(payload: &[u8]) -> Vec<u8> {
        let mut out = Vec::with_capacity(payload.len() * 2);
        push_nonzero_encoded(&mut out, payload);
        out
    }

    fn decode_bytes(byte_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
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

impl Drop for StoreCipher {
    fn drop(&mut self) {
        self.key.zeroize();
    }
}

struct WipeOnDrop<'a> {
    bytes: &'a mut [u8],
}

impl WipeOnDrop<'_> {
    fn as_slice(&self) -> &[u8] {
        self.bytes
    }

    fn as_mut_slice(&mut self) -> &mut [u8] {
        self.bytes
    }
}

impl Drop for WipeOnDrop<'_> {
    fn drop(&mut self) {
        self.bytes.zeroize();
    }
}

impl StoreCipher {
    fn sealed_encoded_len(payload_len: usize) -> usize {
        2 * (SEALED_MAGIC.len() + SEALED_NONCE_BYTES + payload_len + SEALED_TAG_BYTES)
    }

    pub fn from_rng<R: RngCore>(rng: &mut R) -> Self {
        let mut key = [0u8; 32];
        rng.fill_bytes(&mut key);
        Self { key }
    }

    pub fn random() -> Self {
        let mut rng = OsRng;
        Self::from_rng(&mut rng)
    }

    fn seal(&self, aad: &[u8], payload: &[u8], rng: &mut ChaCha20Rng) -> Vec<u8> {
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

    pub fn seal_and_wipe(&self, aad: &[u8], payload: &mut [u8], rng: &mut ChaCha20Rng) -> Vec<u8> {
        let payload = WipeOnDrop { bytes: payload };
        self.seal(aad, payload.as_slice(), rng)
    }

    pub fn seal_and_wipe_into(
        &self,
        aad: &[u8],
        payload: &mut [u8],
        rng: &mut ChaCha20Rng,
        out: &mut Vec<u8>,
    ) -> bool {
        let mut payload = WipeOnDrop { bytes: payload };
        let required_len = Self::sealed_encoded_len(payload.as_slice().len());
        if out.capacity() < required_len {
            return false;
        }
        let mut nonce_bytes = [0u8; SEALED_NONCE_BYTES];
        rng.fill_bytes(&mut nonce_bytes);
        let cipher = ChaCha20Poly1305::new_from_slice(&self.key).expect("fixed-size key");
        let tag = cipher
            .encrypt_in_place_detached(Nonce::from_slice(&nonce_bytes), aad, payload.as_mut_slice())
            .expect("fixed-size nonce");
        out.clear();
        push_nonzero_encoded(out, &SEALED_MAGIC);
        push_nonzero_encoded(out, &nonce_bytes);
        push_nonzero_encoded(out, payload.as_slice());
        push_nonzero_encoded(out, tag.as_slice());
        true
    }

    pub fn filler(&self, aad: &[u8], len: usize, rng: &mut ChaCha20Rng) -> Vec<u8> {
        let mut filler = vec![0u8; len];
        self.seal_and_wipe(aad, &mut filler, rng)
    }

    fn open(&self, aad: &[u8], payload_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
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

    pub fn with_opened_payload<T>(
        &self,
        aad: &[u8],
        payload_len: usize,
        encoded: &[u8],
        f: impl FnOnce(&[u8]) -> T,
    ) -> Option<T> {
        let mut payload = self.open(aad, payload_len, encoded)?;
        let payload = WipeOnDrop {
            bytes: payload.as_mut_slice(),
        };
        Some(f(payload.as_slice()))
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
    fn sealed_codec_wipes_owned_payload_buffer() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(37);
        let mut payload = vec![5u8, 6u8, 7u8, 8u8];
        let encoded = cipher.seal_and_wipe(b"object:slot", &mut payload, &mut rng);
        assert_eq!(payload, vec![0u8; 4]);
        assert_eq!(
            cipher.open(b"object:slot", 4, &encoded),
            Some(vec![5u8, 6u8, 7u8, 8u8])
        );
    }

    #[test]
    fn sealed_codec_seal_into_reuses_output_buffer_and_wipes_payload() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(41);
        let mut payload = vec![5u8, 6u8, 7u8, 8u8];
        let mut encoded = Vec::with_capacity(StoreCipher::sealed_encoded_len(payload.len()));
        let encoded_ptr = encoded.as_ptr();

        assert!(cipher.seal_and_wipe_into(b"object:slot", &mut payload, &mut rng, &mut encoded));
        assert_eq!(payload, vec![0u8; 4]);
        assert_eq!(encoded.as_ptr(), encoded_ptr);
        assert_eq!(
            cipher.open(b"object:slot", 4, &encoded),
            Some(vec![5u8, 6u8, 7u8, 8u8])
        );
    }

    #[test]
    fn sealed_codec_with_opened_payload_roundtrips() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(53);
        let payload = [9u8, 10u8, 11u8, 12u8];
        let encoded = cipher.seal(b"object:slot", &payload, &mut rng);
        let reopened =
            cipher.with_opened_payload(b"object:slot", payload.len(), &encoded, |msg| msg.to_vec());
        assert_eq!(reopened, Some(payload.to_vec()));
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
