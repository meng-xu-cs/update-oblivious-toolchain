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
}

fn push_nonzero_encoded(out: &mut Vec<u8>, bytes: &[u8]) {
    for byte in bytes {
        out.push((byte >> 4) + 1);
        out.push((byte & 0x0F) + 1);
    }
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
}
