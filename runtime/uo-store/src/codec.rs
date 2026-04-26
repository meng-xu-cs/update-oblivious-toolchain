#[path = "generated_codec.rs"]
mod generated_codec;
#[path = "generated_surface.rs"]
mod generated_surface;

pub use generated_surface::StoreCipher;

use generated_codec::{
    decode_nonzero_into, sealed_encoded_len as generated_sealed_encoded_len, write_nonzero_encoded,
    SEALED_MAGIC, SEALED_NONCE_BYTES, SEALED_TAG_BYTES,
};

#[cfg(test)]
#[derive(Clone, Debug)]
struct NonZeroCodec;

#[cfg(test)]
impl NonZeroCodec {
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

#[cfg(test)]
mod tests {
    use super::{generated_sealed_encoded_len, NonZeroCodec, StoreCipher};
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
        let mut payload_for_seal = payload.to_vec();
        let encoded = cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload_for_seal, &mut rng)
            .unwrap()
            .into_vec();
        let reopened =
            cipher.with_opened_payload(b"object:slot", payload.len(), &encoded, |payload| {
                payload.to_vec()
            });
        assert_eq!(reopened, Some(payload.to_vec()));
    }

    #[test]
    fn sealed_codec_rejects_tampering() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(29);
        let mut payload = vec![1u8, 2u8, 3u8];
        let encoded = cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload, &mut rng)
            .unwrap()
            .into_vec();
        let mut tampered = encoded.clone();
        tampered[5] ^= 0x01;
        let reopened =
            cipher.with_opened_payload(b"object:slot", 3, &tampered, |payload| payload.to_vec());
        assert_eq!(reopened, None);
    }

    #[test]
    fn sealed_codec_wipes_owned_payload_buffer() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(37);
        let mut payload = vec![5u8, 6u8, 7u8, 8u8];
        let encoded = cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload, &mut rng)
            .unwrap();
        assert_eq!(payload, vec![0u8; 4]);
        let reopened =
            cipher.with_opened_payload(b"object:slot", 4, &encoded, |payload| payload.to_vec());
        assert_eq!(reopened, Some(vec![5u8, 6u8, 7u8, 8u8]));
    }

    #[test]
    fn sealed_codec_seal_into_slice_reuses_fixed_output_buffer_and_wipes_payload() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(43);
        let mut payload = vec![5u8, 6u8, 7u8, 8u8];
        let mut encoded = vec![0u8; generated_sealed_encoded_len(payload.len())];
        let encoded_ptr = encoded.as_ptr();

        assert!(cipher.seal_and_wipe_into_slice(
            b"object:slot",
            &mut payload,
            &mut rng,
            &mut encoded,
        ));
        assert_eq!(payload, vec![0u8; 4]);
        assert_eq!(encoded.as_ptr(), encoded_ptr);
        let reopened =
            cipher.with_opened_payload(b"object:slot", 4, &encoded, |payload| payload.to_vec());
        assert_eq!(reopened, Some(vec![5u8, 6u8, 7u8, 8u8]));
    }

    #[test]
    fn sealed_codec_with_opened_payload_roundtrips() {
        let cipher = StoreCipher::random();
        let mut rng = ChaCha20Rng::seed_from_u64(53);
        let payload = [9u8, 10u8, 11u8, 12u8];
        let mut payload_for_seal = payload.to_vec();
        let encoded = cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload_for_seal, &mut rng)
            .unwrap()
            .into_vec();
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
        let mut payload_lhs = payload.to_vec();
        let mut payload_rhs = payload.to_vec();
        let encoded_lhs = cipher_lhs
            .seal_and_wipe_boxed(b"object:slot", &mut payload_lhs, &mut lhs)
            .unwrap()
            .into_vec();
        let encoded_rhs = cipher_rhs
            .seal_and_wipe_boxed(b"object:slot", &mut payload_rhs, &mut rhs)
            .unwrap()
            .into_vec();
        assert_eq!(encoded_lhs, encoded_rhs);
        let reopened = cipher_lhs.with_opened_payload(
            b"object:slot",
            payload.len(),
            &encoded_lhs,
            |payload| payload.to_vec(),
        );
        assert_eq!(reopened, Some(payload.to_vec()));
    }
}
