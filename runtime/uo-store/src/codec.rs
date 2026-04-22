use chacha20poly1305::aead::AeadInPlace;
use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce, Tag};
use rand::rngs::OsRng;
use rand::RngCore;
use rand_chacha::ChaCha20Rng;
use std::fmt;
use zeroize::Zeroize;

#[derive(Clone, Debug)]
struct NonZeroCodec;

impl NonZeroCodec {
    #[cfg(test)]
    fn encode_bytes(payload: &[u8]) -> Vec<u8> {
        let mut out = vec![0u8; payload.len() * 2];
        let mut cursor = 0usize;
        write_nonzero_encoded(&mut out, &mut cursor, payload);
        debug_assert_eq!(cursor, out.len());
        out
    }

    fn decode_bytes(byte_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
        if encoded.len() != byte_len * 2 {
            return None;
        }
        let mut decoded = vec![0u8; byte_len];
        decode_nonzero_into(encoded, &mut decoded)?;
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

    #[cfg(test)]
    fn seal(&self, aad: &[u8], payload: &[u8], rng: &mut ChaCha20Rng) -> Vec<u8> {
        let mut payload = payload.to_vec();
        self.seal_and_wipe(aad, &mut payload, rng)
    }

    pub fn seal_and_wipe(&self, aad: &[u8], payload: &mut [u8], rng: &mut ChaCha20Rng) -> Vec<u8> {
        let mut encoded = vec![0u8; Self::sealed_encoded_len(payload.len())];
        let sealed = self.seal_and_wipe_into_slice(aad, payload, rng, &mut encoded);
        debug_assert!(sealed, "exact-size sealed output buffer must fit");
        encoded
    }

    pub fn seal_and_wipe_boxed(
        &self,
        aad: &[u8],
        payload: &mut [u8],
        rng: &mut ChaCha20Rng,
    ) -> Box<[u8]> {
        let mut encoded = vec![0u8; Self::sealed_encoded_len(payload.len())].into_boxed_slice();
        let sealed = self.seal_and_wipe_into_slice(aad, payload, rng, &mut encoded);
        debug_assert!(sealed, "exact-size sealed output buffer must fit");
        encoded
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
        out.resize(required_len, 0);
        let mut cursor = 0usize;
        write_nonzero_encoded(out.as_mut_slice(), &mut cursor, &SEALED_MAGIC);
        write_nonzero_encoded(out.as_mut_slice(), &mut cursor, &nonce_bytes);
        write_nonzero_encoded(out.as_mut_slice(), &mut cursor, payload.as_slice());
        write_nonzero_encoded(out.as_mut_slice(), &mut cursor, tag.as_slice());
        debug_assert_eq!(cursor, out.len());
        true
    }

    pub fn seal_and_wipe_into_slice(
        &self,
        aad: &[u8],
        payload: &mut [u8],
        rng: &mut ChaCha20Rng,
        out: &mut [u8],
    ) -> bool {
        let mut payload = WipeOnDrop { bytes: payload };
        let required_len = Self::sealed_encoded_len(payload.as_slice().len());
        if out.len() != required_len {
            return false;
        }
        let mut nonce_bytes = [0u8; SEALED_NONCE_BYTES];
        rng.fill_bytes(&mut nonce_bytes);
        let cipher = ChaCha20Poly1305::new_from_slice(&self.key).expect("fixed-size key");
        let tag = cipher
            .encrypt_in_place_detached(Nonce::from_slice(&nonce_bytes), aad, payload.as_mut_slice())
            .expect("fixed-size nonce");
        let mut cursor = 0usize;
        write_nonzero_encoded(out, &mut cursor, &SEALED_MAGIC);
        write_nonzero_encoded(out, &mut cursor, &nonce_bytes);
        write_nonzero_encoded(out, &mut cursor, payload.as_slice());
        write_nonzero_encoded(out, &mut cursor, tag.as_slice());
        debug_assert_eq!(cursor, out.len());
        true
    }

    pub fn filler(&self, aad: &[u8], len: usize, rng: &mut ChaCha20Rng) -> Vec<u8> {
        let mut filler = vec![0u8; len];
        self.seal_and_wipe(aad, &mut filler, rng)
    }

    pub fn filler_boxed(&self, aad: &[u8], len: usize, rng: &mut ChaCha20Rng) -> Box<[u8]> {
        let mut filler = vec![0u8; len].into_boxed_slice();
        self.seal_and_wipe_boxed(aad, &mut filler, rng)
    }

    fn open(&self, aad: &[u8], payload_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
        let sealed_len = SEALED_MAGIC.len() + SEALED_NONCE_BYTES + payload_len + SEALED_TAG_BYTES;
        let sealed = NonZeroCodec::decode_bytes(sealed_len, encoded)?;
        let (magic, rest) = sealed.split_at(SEALED_MAGIC.len());
        if magic != SEALED_MAGIC {
            return None;
        }
        let (nonce_bytes, ciphertext_and_tag) = rest.split_at(SEALED_NONCE_BYTES);
        let (ciphertext, tag_bytes) = ciphertext_and_tag.split_at(payload_len);
        let mut payload = vec![0u8; payload_len];
        payload.copy_from_slice(ciphertext);
        let cipher = ChaCha20Poly1305::new_from_slice(&self.key).ok()?;
        cipher
            .decrypt_in_place_detached(
                Nonce::from_slice(nonce_bytes),
                aad,
                payload.as_mut_slice(),
                Tag::from_slice(tag_bytes),
            )
            .ok()?;
        Some(payload)
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

fn write_nonzero_encoded(out: &mut [u8], cursor: &mut usize, bytes: &[u8]) {
    let end = *cursor + bytes.len() * 2;
    let out = &mut out[*cursor..end];
    for (index, byte) in bytes.iter().enumerate() {
        out[index * 2] = (byte >> 4) + 1;
        out[index * 2 + 1] = (byte & 0x0F) + 1;
    }
    *cursor = end;
}

fn decode_nonzero_into(encoded: &[u8], out: &mut [u8]) -> Option<()> {
    if encoded.len() != out.len() * 2 {
        return None;
    }
    for (index, chunk) in encoded.chunks_exact(2).enumerate() {
        let hi = *chunk.first()?;
        let lo = *chunk.get(1)?;
        if hi == 0 || hi > 16 || lo == 0 || lo > 16 {
            return None;
        }
        out[index] = ((hi - 1) << 4) | (lo - 1);
    }
    Some(())
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
    fn sealed_codec_seal_into_slice_reuses_fixed_output_buffer_and_wipes_payload() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(43);
        let mut payload = vec![5u8, 6u8, 7u8, 8u8];
        let mut encoded = vec![0u8; StoreCipher::sealed_encoded_len(payload.len())];
        let encoded_ptr = encoded.as_ptr();

        assert!(cipher.seal_and_wipe_into_slice(
            b"object:slot",
            &mut payload,
            &mut rng,
            &mut encoded,
        ));
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
