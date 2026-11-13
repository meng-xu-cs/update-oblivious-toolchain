#[path = "generated_codec.rs"]
mod generated_codec;
#[path = "generated_surface.rs"]
mod generated_surface;

pub use generated_surface::StoreCipher;

use generated_codec::{
    next_marker, read_units, record_marker, seal_nonce,
    sealed_content_len as generated_sealed_content_len,
    sealed_encoded_len as generated_sealed_encoded_len, write_units, SEALED_MARKERS,
    SEALED_NONCE_BYTES, SEALED_TAG_BYTES,
};

#[cfg(test)]
mod tests {
    use super::{
        generated_sealed_content_len, generated_sealed_encoded_len, read_units, record_marker,
        seal_nonce, write_units, StoreCipher, SEALED_MARKERS, SEALED_NONCE_BYTES,
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
        let mut content = vec![0u8; generated_sealed_content_len(payload.len())];
        read_units(&encoded, &mut content).unwrap();
        content[..SEALED_NONCE_BYTES].to_vec()
    }

    /// A record of `payload` that replaces none.
    fn fresh_record(cipher: &StoreCipher, payload: &[u8]) -> Vec<u8> {
        let mut rng = ChaCha20Rng::seed_from_u64(0);
        let mut payload = payload.to_vec();
        cipher
            .seal_and_wipe_boxed(b"object:slot", &mut payload, &mut rng)
            .unwrap()
            .into_vec()
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
        // The record the failed seals would have replaced: the last one the
        // key sealed.
        let record = {
            let other = StoreCipher::random();
            fresh_record(&other, &[5u8, 6u8])
        };
        for _ in 0..2 {
            let mut payload = vec![5u8, 6u8];
            let mut encoded = record.clone();
            assert!(!cipher.seal_and_wipe_into_slice(
                b"object:slot",
                &mut payload,
                &mut rng,
                &mut encoded,
            ));
            assert_eq!(payload, vec![0u8; 2]);
            assert_eq!(encoded, record);
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
    fn a_sealed_record_is_a_whole_number_of_units() {
        // A unit is a 32-byte word: one marker and 31 bytes of nonce,
        // ciphertext and tag. A 256-bit value takes two words and a map
        // record of a 256-bit key and value three.
        assert_eq!(generated_sealed_content_len(32), 12 + 32 + 16);
        assert_eq!(generated_sealed_encoded_len(32), 64);
        assert_eq!(generated_sealed_encoded_len(65), 96);
        assert_eq!(generated_sealed_encoded_len(0), 32);
        // 31 bytes of content fill one unit, and one more starts another.
        assert_eq!(generated_sealed_encoded_len(3), 32);
        assert_eq!(generated_sealed_encoded_len(4), 64);
        let cipher = StoreCipher::random();
        for payload_len in [0usize, 1, 3, 4, 32, 34, 35, 65, 348] {
            let record = fresh_record(&cipher, &vec![0x3Cu8; payload_len]);
            assert_eq!(record.len(), generated_sealed_encoded_len(payload_len));
            assert_eq!(record.len() % 32, 0);
        }
    }

    #[test]
    fn units_roundtrip_content_and_carry_one_marker() {
        let content: Vec<u8> = (0..70u8).collect();
        for marker in SEALED_MARKERS {
            let mut encoded = vec![0xEEu8; 96];
            assert!(write_units(
                &mut encoded,
                marker,
                &[&content[..12], &content[12..54], &content[54..]]
            ));
            assert_eq!(record_marker(&encoded), Some(marker));
            for unit in encoded.chunks_exact(32) {
                assert_eq!(unit[0], marker);
            }
            // 93 bytes of content fit three units; 70 leave 23 zeros.
            assert!(encoded[3 + 70..].iter().all(|byte| *byte == 0));
            let mut decoded = vec![0u8; content.len()];
            assert_eq!(read_units(&encoded, &mut decoded), Some(marker));
            assert_eq!(decoded, content);
        }
        // A buffer of another size is not written.
        let mut short = vec![0u8; 64];
        assert!(!write_units(&mut short, SEALED_MARKERS[0], &[&content]));
        assert_eq!(short, vec![0u8; 64]);
    }

    #[test]
    fn a_record_with_a_zero_or_foreign_unit_is_not_read() {
        let cipher = StoreCipher::random();
        let payload = [7u8; 40];
        let record = fresh_record(&cipher, &payload);
        assert_eq!(record.len(), 96);
        let open = |encoded: &[u8]| {
            cipher.with_opened_payload(b"object:slot", payload.len(), encoded, |bytes| {
                bytes.to_vec()
            })
        };
        assert_eq!(open(&record), Some(payload.to_vec()));
        for unit in 0..3 {
            // A unit that is zero has no marker.
            let mut zeroed = record.clone();
            zeroed[32 * unit..32 * (unit + 1)].fill(0);
            assert_eq!(record_marker(&zeroed), None);
            assert_eq!(open(&zeroed), None, "unit {unit} zeroed");
            // Nor has one whose first byte is neither marker.
            let mut foreign = record.clone();
            foreign[32 * unit] = 0x01;
            assert_eq!(open(&foreign), None, "unit {unit} foreign");
            // The units of a record carry one marker.
            let mut mixed = record.clone();
            mixed[32 * unit] = SEALED_MARKERS[1];
            assert_eq!(open(&mixed), None, "unit {unit} mixed");
        }
        // The bytes after the content are zero: 68 bytes of content leave
        // 25 in the last unit.
        let mut padded = record.clone();
        *padded.last_mut().unwrap() = 1;
        assert_eq!(open(&padded), None);
        // A record is not read at another length.
        assert_eq!(open(&record[..64]), None);
        let mut longer = record.clone();
        longer.extend_from_slice(&record[..32]);
        assert_eq!(open(&longer), None);
    }

    #[test]
    fn a_record_written_over_another_differs_from_it_in_every_unit() {
        // The first record under a key carries the first marker; each record
        // sealed over it carries the marker its predecessor does not. So a
        // write is an Update in every unit whatever the ciphertexts are:
        // here the key is made again for each seal, which repeats the nonce,
        // and the payload is the same, so that the ciphertexts are equal.
        let cipher = || StoreCipher::from_rng(&mut ChaCha20Rng::seed_from_u64(0x35));
        let mut rng = ChaCha20Rng::seed_from_u64(1);
        let payload = [0x11u8; 65];
        let mut record = fresh_record(&cipher(), &payload);
        assert_eq!(record_marker(&record), Some(SEALED_MARKERS[0]));
        for round in 1..=4 {
            let previous = record.clone();
            let mut payload_for_seal = payload.to_vec();
            assert!(cipher().seal_and_wipe_into_slice(
                b"object:slot",
                &mut payload_for_seal,
                &mut rng,
                &mut record,
            ));
            assert_eq!(record_marker(&record), Some(SEALED_MARKERS[round % 2]));
            assert_eq!(record.len(), previous.len());
            for (old_unit, new_unit) in previous.chunks_exact(32).zip(record.chunks_exact(32)) {
                // The units differ in their marker and in nothing else.
                assert_ne!(old_unit[0], new_unit[0]);
                assert_eq!(old_unit[1..], new_unit[1..]);
            }
            assert!(uo_core::is_update_write(&previous, &record));
        }
        // A buffer that holds no record is not sealed over.
        for mut not_a_record in [vec![0u8; 96], vec![0x01u8; 96]] {
            let before = not_a_record.clone();
            let mut payload_for_seal = payload.to_vec();
            assert!(!cipher().seal_and_wipe_into_slice(
                b"object:slot",
                &mut payload_for_seal,
                &mut rng,
                &mut not_a_record,
            ));
            assert_eq!(payload_for_seal, vec![0u8; 65]);
            assert_eq!(not_a_record, before);
        }
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
        let mut encoded = fresh_record(&cipher, &[0u8; 4]);
        assert_eq!(encoded.len(), generated_sealed_encoded_len(payload.len()));
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
