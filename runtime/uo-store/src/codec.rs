#[path = "generated_codec.rs"]
mod generated_codec;
#[path = "generated_surface.rs"]
mod generated_surface;

pub use generated_surface::StoreCipher;

use generated_codec::{
    decode_nonzero_into, seal_nonce, sealed_encoded_len as generated_sealed_encoded_len,
    write_nonzero_encoded, SEALED_MAGIC, SEALED_NONCE_BYTES, SEALED_TAG_BYTES,
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
    use super::{
        generated_sealed_encoded_len, seal_nonce, NonZeroCodec, StoreCipher, SEALED_MAGIC,
        SEALED_NONCE_BYTES, SEALED_TAG_BYTES,
    };
    use rand::SeedableRng;
    use rand_chacha::ChaCha20Rng;
    use std::collections::BTreeSet;

    /// Seal `payload` and return the nonce the sealed record carries.
    fn sealed_nonce(cipher: &StoreCipher, rng_seed: u64, payload: &[u8]) -> Vec<u8> {
        let mut rng = ChaCha20Rng::seed_from_u64(rng_seed);
        let mut payload_for_seal = payload.to_vec();
        let encoded = cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload_for_seal, &mut rng)
            .unwrap();
        let sealed_len = SEALED_MAGIC.len() + SEALED_NONCE_BYTES + payload.len() + SEALED_TAG_BYTES;
        let sealed = NonZeroCodec::decode_bytes(sealed_len, &encoded).unwrap();
        sealed[SEALED_MAGIC.len()..SEALED_MAGIC.len() + SEALED_NONCE_BYTES].to_vec()
    }

    /// The Lean model `sealNonce` and its example: four zero bytes, then the
    /// counter, most significant byte first.
    #[test]
    fn seal_nonce_is_the_big_endian_counter() {
        assert_eq!(seal_nonce(258), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2]);
        for counter in [0, 1, 255, 256, 258, 1 << 32, u64::MAX - 1, u64::MAX] {
            let nonce = seal_nonce(counter);
            assert_eq!(nonce.len(), SEALED_NONCE_BYTES);
            assert_eq!(nonce[..4], [0u8; 4]);
            assert_eq!(nonce[4..], counter.to_be_bytes());
        }
    }

    #[test]
    fn seal_nonces_of_different_counters_differ() {
        let mut counters: Vec<u64> = (0..4096).collect();
        for bit in 0..64 {
            counters.push(1u64 << bit);
            counters.push(u64::MAX ^ (1u64 << bit));
        }
        counters.push(u64::MAX);
        let distinct_counters: BTreeSet<u64> = counters.iter().copied().collect();
        let distinct_nonces: BTreeSet<[u8; SEALED_NONCE_BYTES]> =
            distinct_counters.iter().map(|c| seal_nonce(*c)).collect();
        assert_eq!(distinct_nonces.len(), distinct_counters.len());
    }

    /// A seal's nonce is the count of the seals under the key so far. The
    /// payload and the generator passed to the seal do not choose it.
    #[test]
    fn each_seal_under_a_key_carries_the_next_counter() {
        let cipher = StoreCipher::random();
        assert_eq!(sealed_nonce(&cipher, 11, &[1, 2, 3]), seal_nonce(0));
        assert_eq!(sealed_nonce(&cipher, 11, &[1, 2, 3]), seal_nonce(1));
        assert_eq!(sealed_nonce(&cipher, 97, &[]), seal_nonce(2));
        let mut rng = ChaCha20Rng::seed_from_u64(11);
        cipher.filler_boxed(b"object:slot", 8, &mut rng).unwrap();
        assert_eq!(sealed_nonce(&cipher, 11, &[9; 40]), seal_nonce(4));
    }

    /// A copy of the cipher shares its seal count. A staged call seals with
    /// copies; dropping it does not give its nonces back.
    #[test]
    fn a_dropped_copy_of_the_cipher_does_not_return_its_nonces() {
        let committed = StoreCipher::random();
        assert_eq!(sealed_nonce(&committed, 1, &[7]), seal_nonce(0));
        let staged = committed.clone_for_runtime_state();
        assert_eq!(staged, committed);
        let nested = staged.clone_for_runtime_state();
        assert_eq!(sealed_nonce(&staged, 1, &[8]), seal_nonce(1));
        assert_eq!(sealed_nonce(&nested, 1, &[8]), seal_nonce(2));
        drop(nested);
        drop(staged);
        assert_eq!(sealed_nonce(&committed, 1, &[8]), seal_nonce(3));
    }

    /// Two keys count their seals separately.
    #[test]
    fn each_key_has_its_own_seal_count() {
        let lhs = StoreCipher::random();
        let rhs = StoreCipher::random();
        assert_ne!(lhs, rhs);
        assert_eq!(sealed_nonce(&lhs, 1, &[7]), seal_nonce(0));
        assert_eq!(sealed_nonce(&lhs, 1, &[7]), seal_nonce(1));
        assert_eq!(sealed_nonce(&rhs, 1, &[7]), seal_nonce(0));
    }

    /// The last counter is never handed out: once the count cannot grow, a
    /// seal fails and writes nothing, and it keeps failing.
    #[test]
    fn a_seal_fails_once_the_seal_count_is_exhausted() {
        let cipher = StoreCipher::random();
        cipher.set_seal_count_for_test(u64::MAX - 1);
        assert_eq!(sealed_nonce(&cipher, 1, &[7]), seal_nonce(u64::MAX - 1));
        let mut rng = ChaCha20Rng::seed_from_u64(1);
        for _ in 0..2 {
            let mut payload = vec![5u8, 6u8];
            let mut encoded = vec![0u8; generated_sealed_encoded_len(payload.len())];
            assert!(!cipher.seal_and_wipe_into_slice(
                b"object:slot",
                &mut payload,
                &mut rng,
                &mut encoded,
            ));
            assert_eq!(payload, vec![0u8; 2]);
            assert_eq!(encoded, vec![0u8; generated_sealed_encoded_len(2)]);
            let mut payload = vec![5u8, 6u8];
            assert!(cipher
                .seal_and_wipe_boxed(b"object:slot", &mut payload, &mut rng)
                .is_err());
            assert!(cipher.filler_boxed(b"object:slot", 2, &mut rng).is_err());
        }
        let copy = cipher.clone_for_runtime_state();
        let mut payload = vec![5u8, 6u8];
        assert!(copy
            .seal_and_wipe_boxed(b"object:slot", &mut payload, &mut rng)
            .is_err());
    }

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
