# Reviewer Summary

## Proof And Report Cost

| Report | Milliseconds |
| --- | ---: |
| `total_probe_ms` | `147562` |
| `canonical_pathoram_pair_validation` | `56290` |
| `fresh_coin_validation` | `13569` |
| `tamper_validation` | `10160` |
| `pathoram_pair_validation` | `6094` |
| `confidential_core_validation` | `3242` |
| `seeded_witness_validation` | `3192` |
| `confidential_core_lowering_validation` | `2991` |
| `confidential_core_shell_boundary_lowering_validation` | `2968` |
| `confidential_core_slot_validation` | `2961` |
| `confidential_core_shell_boundary_slot_validation` | `2925` |
| `shell_boundary_slot_validation` | `2865` |
| `kernel_slot_dsl_validation` | `2861` |
| `kernel_refinement_validation` | `2841` |
| `controller_observer_validation` | `2835` |
| `trusted_kernel_validation` | `2828` |
| `kernel_lowering_validation` | `2814` |
| `kernel_dsl_validation` | `2774` |
| `shell_boundary_lowering_validation` | `2754` |
| `shell_boundary_validation` | `2705` |
| `trace_equivalence` | `2695` |
| `kernel_validation` | `2694` |
| `leakage_auc` | `2541` |
| `mutual_information` | `2524` |
| `pathoram_hidden_validation` | `1970` |
| `witness_validation` | `1873` |
| `static_checks` | `1760` |
| `correctness` | `1205` |
| `runtime_boundary_validation` | `304` |
| `overheads` | `116` |
| `kernel_model_alignment_validation` | `49` |
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
| `confidential_core_shell_boundary_lowering_validation.scenarios[15].confidential_core_shell_boundary_lowering_bundle_json_bytes` | `297490` |
| `confidential_core_shell_boundary_slot_validation.scenarios[15].confidential_core_shell_boundary_slot_bundle_json_bytes` | `295523` |
| `tamper_validation.scenarios[21].artifact_json_bytes` | `262697` |
| `pathoram_pair_validation.scenarios[0].certificate_json_bytes` | `262696` |
| `seeded_witness_validation.scenarios[2].witness_family_json_bytes` | `237521` |
| `confidential_core_lowering_validation.scenarios[15].confidential_core_lowering_bundle_json_bytes` | `195533` |
| `confidential_core_validation.scenarios[15].confidential_core_bundle_json_bytes` | `193962` |
| `confidential_core_slot_validation.scenarios[15].confidential_core_slot_bundle_json_bytes` | `193598` |

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
