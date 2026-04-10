use rand::RngCore;
use rand_chacha::ChaCha20Rng;

#[derive(Clone, Debug)]
pub struct NonZeroCodec;

impl NonZeroCodec {
    pub fn encode(payload: &[u8], rng: &mut ChaCha20Rng) -> Vec<u8> {
        let mut nonce = [0u8; 16];
        rng.fill_bytes(&mut nonce);
        let mut out = Vec::with_capacity((payload.len() + nonce.len() + 2) * 2);
        push_nonzero_encoded(&mut out, &[0xA5, 0x5A]);
        push_nonzero_encoded(&mut out, &nonce);
        push_nonzero_encoded(&mut out, payload);
        out
    }

    pub fn filler(len: usize, rng: &mut ChaCha20Rng) -> Vec<u8> {
        Self::encode(&vec![0u8; len], rng)
    }

    pub fn decode(payload_len: usize, encoded: &[u8]) -> Option<Vec<u8>> {
        let expected_len = (payload_len + 18) * 2;
        if encoded.len() != expected_len {
            return None;
        }
        let decoded = decode_nonzero(encoded)?;
        if decoded.len() != payload_len + 18 {
            return None;
        }
        if decoded[0..2] != [0xA5, 0x5A] {
            return None;
        }
        Some(decoded[18..].to_vec())
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
    use super::NonZeroCodec;
    use rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;

    #[test]
    fn encoded_records_are_always_nonzero() {
        let mut rng = ChaCha20Rng::seed_from_u64(7);
        let encoded = NonZeroCodec::encode(&[0u8, 0xFF, 0x11], &mut rng);
        assert!(encoded.iter().all(|byte| *byte != 0));
    }

    #[test]
    fn decode_roundtrips_payload() {
        let mut rng = ChaCha20Rng::seed_from_u64(11);
        let payload = [0u8, 0xAB, 0xCD, 0xEF];
        let encoded = NonZeroCodec::encode(&payload, &mut rng);
        assert_eq!(NonZeroCodec::decode(payload.len(), &encoded), Some(payload.to_vec()));
    }
}
