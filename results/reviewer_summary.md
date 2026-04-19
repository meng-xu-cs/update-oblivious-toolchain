# Reviewer Summary

## Proof And Report Cost

| Report | Milliseconds |
| --- | ---: |
| `total_probe_ms` | `148632` |
| `canonical_pathoram_pair_validation` | `56898` |
| `fresh_coin_validation` | `13716` |
| `tamper_validation` | `10754` |
| `pathoram_pair_validation` | `6088` |
| `shell_boundary_slot_validation` | `3260` |
| `seeded_witness_validation` | `3234` |
| `confidential_core_lowering_validation` | `3041` |
| `confidential_core_validation` | `2997` |
| `trusted_kernel_validation` | `2986` |
| `confidential_core_shell_boundary_lowering_validation` | `2930` |
| `kernel_slot_dsl_validation` | `2842` |
| `kernel_validation` | `2835` |
| `shell_boundary_validation` | `2832` |
| `kernel_lowering_validation` | `2831` |
| `shell_boundary_lowering_validation` | `2805` |
| `controller_observer_validation` | `2760` |
| `trace_equivalence` | `2748` |
| `kernel_dsl_validation` | `2725` |
| `confidential_core_slot_validation` | `2714` |
| `kernel_refinement_validation` | `2684` |
| `confidential_core_shell_boundary_slot_validation` | `2617` |
| `leakage_auc` | `2546` |
| `mutual_information` | `2545` |
| `pathoram_hidden_validation` | `2036` |
| `witness_validation` | `1837` |
| `static_checks` | `1578` |
| `correctness` | `1210` |
| `runtime_boundary_validation` | `282` |
| `overheads` | `117` |
| `kernel_model_alignment_validation` | `3` |
| `confidential_fragment_validation` | `0` |

## Largest Materialized Artifacts

| Report Field | Bytes |
| --- | ---: |
| `canonical_pathoram_pair_validation.scenarios[1].certificate_json_bytes` | `189305140` |
| `fresh_coin_validation.scenarios[1].witness_family_json_bytes` | `94647675` |
| `canonical_pathoram_pair_validation.scenarios[0].certificate_json_bytes` | `8216346` |
| `tamper_validation.scenarios[22].artifact_json_bytes` | `8216346` |
| `tamper_validation.scenarios[23].artifact_json_bytes` | `8216346` |
| `fresh_coin_validation.scenarios[0].witness_family_json_bytes` | `4105222` |
| `tamper_validation.scenarios[19].artifact_json_bytes` | `4105222` |
| `pathoram_pair_validation.scenarios[3].certificate_json_bytes` | `1619968` |
| `seeded_witness_validation.scenarios[3].witness_family_json_bytes` | `768398` |
| `pathoram_pair_validation.scenarios[2].certificate_json_bytes` | `498341` |
| `canonical_pathoram_pair_validation.scenarios[3].theorem_input_json_bytes` | `468944` |
| `pathoram_pair_validation.scenarios[1].certificate_json_bytes` | `379834` |
| `confidential_core_shell_boundary_lowering_validation.scenarios[15].confidential_core_shell_boundary_lowering_bundle_json_bytes` | `297476` |
| `confidential_core_shell_boundary_slot_validation.scenarios[15].confidential_core_shell_boundary_slot_bundle_json_bytes` | `295547` |
| `tamper_validation.scenarios[21].artifact_json_bytes` | `262697` |
| `pathoram_pair_validation.scenarios[0].certificate_json_bytes` | `262696` |
| `seeded_witness_validation.scenarios[2].witness_family_json_bytes` | `237521` |
| `confidential_core_lowering_validation.scenarios[15].confidential_core_lowering_bundle_json_bytes` | `195531` |
| `confidential_core_validation.scenarios[15].confidential_core_bundle_json_bytes` | `193951` |
| `confidential_core_slot_validation.scenarios[15].confidential_core_slot_bundle_json_bytes` | `193585` |

## Largest Estimated Artifacts

| Report Field | Estimated Bytes |
| --- | ---: |
| `canonical_pathoram_pair_validation.scenarios[3].estimated_certificate_json_bytes` | `6754132803663691776` |
| `canonical_pathoram_pair_validation.scenarios[3].lhs_estimate.estimated_family_json_bytes` | `3377066401831321600` |
| `canonical_pathoram_pair_validation.scenarios[3].rhs_estimate.estimated_family_json_bytes` | `3377066401831321600` |
| `fresh_coin_validation.scenarios[3].size_estimate.estimated_family_json_bytes` | `3377066401831321600` |
| `canonical_pathoram_pair_validation.scenarios[2].estimated_certificate_json_bytes` | `31107055616` |
| `canonical_pathoram_pair_validation.scenarios[2].lhs_estimate.estimated_family_json_bytes` | `15553003520` |
| `canonical_pathoram_pair_validation.scenarios[2].rhs_estimate.estimated_family_json_bytes` | `15553003520` |
| `fresh_coin_validation.scenarios[2].size_estimate.estimated_family_json_bytes` | `15553003520` |

## Runtime Overheads

| Benchmark | Raw Gas | Raw Writes | Raw Bytes | Full-Scan Gas | Full-Scan Writes | Full-Scan Bytes | ORAM Gas | ORAM Writes | ORAM Bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ConfidentialMixer/deposit` | `50` | `2` | `64` | `32768` | `65` | `12284` | `12288` | `49` | `56520` |

## TCB Surface

| Surface | Total Non-Empty LOC |
| --- | ---: |
| Trusted Rust runtime surface | `6968` |
| Outer runtime risk surface | `934` |
| Lean theorem/checker repo surface | `28083` |

## Current TCB Table

| Component | In Current Proof-Grade TCB? | Role |
| --- | --- | --- |
| Lean kernel plus Lean theorem/checker development | `true` | trusted proof checker and theorem body |
| Explicit backend / cryptographic / deployment assumptions | `true` | trusted assumptions |
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | `true` | currently trusted for implementation honesty |
| Rust code outside the tiny kernel | `true` | still part of the implementation risk until confinement and refinement are proved |
| uo-check | `false` | not in the proof-grade TCB |
| mplus-probe | `false` | validation/reporting only |
| uo-solc | `false` | not trusted for the current artifact-level acceptance claim; still unverified for the final source-level compiler theorem |

## Explicit Assumptions

| Assumption | Meaning | Status |
| --- | --- | --- |
| `bucketEncryptionINDCPA` | hides bucket/path ciphertext contents for the concrete local-posmap backend | explicit Lean assumption in PathOramLocalPosmapV1SecurityAssumptions; not yet discharged in-repo |
| `metadataEncryptionINDCPA` | hides encrypted position-map metadata pages | explicit Lean assumption in PathOramLocalPosmapV1SecurityAssumptions; not yet discharged in-repo |
| `stashOverflowBounded` | bounds stash-overflow failure for the deployed parameters | explicit Lean assumption in PathOramLocalPosmapV1SecurityAssumptions; not yet fully discharged in-repo |
| `TEE deployment assumptions` | enclave memory confidentiality/integrity, attestation authenticity, rollback/freshness discipline, and the stated crash/patch model | required by the final malicious-host deployment theorem; not yet fully closed in Lean |
