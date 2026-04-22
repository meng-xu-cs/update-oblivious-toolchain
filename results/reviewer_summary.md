# Reviewer Summary

## Proof And Report Cost

| Report | Milliseconds |
| --- | ---: |
| `total_probe_ms` | `258365` |
| `canonical_pathoram_pair_validation` | `60784` |
| `tamper_validation` | `29079` |
| `fresh_coin_validation` | `15566` |
| `seeded_witness_validation` | `7316` |
| `pathoram_pair_validation` | `6813` |
| `kernel_dsl_validation` | `4550` |
| `confidential_core_lowering_validation` | `4511` |
| `confidential_core_shell_boundary_slot_validation` | `4484` |
| `kernel_slot_dsl_validation` | `4419` |
| `kernel_validation` | `4383` |
| `confidential_core_shell_boundary_lowering_validation` | `4362` |
| `kernel_refinement_validation` | `4342` |
| `shell_boundary_lowering_validation` | `4333` |
| `shell_boundary_slot_validation` | `4313` |
| `kernel_lowering_validation` | `4274` |
| `shell_boundary_validation` | `4248` |
| `trusted_kernel_validation` | `4241` |
| `controller_observer_validation` | `4203` |
| `confidential_proof_family_assurance_validation` | `3793` |
| `confidential_proof_family_kernel_interface_validation` | `3766` |
| `confidential_proof_family_finish_slot_boundary_validation` | `3762` |
| `confidential_proof_family_boundary_validation` | `3737` |
| `confidential_proof_family_validation` | `3720` |
| `confidential_proof_family_refinement_boundary_validation` | `3660` |
| `confidential_proof_family_slot_boundary_validation` | `3528` |
| `confidential_proof_family_slot_assurance_validation` | `3456` |
| `confidential_core_kernel_interface_slot_finish_boundary_validation` | `3328` |
| `pathoram_hidden_validation` | `3277` |
| `confidential_core_kernel_interface_slot_validation` | `3231` |
| `kernel_slot_boundary_validation` | `3182` |
| `confidential_core_validation` | `3118` |
| `confidential_core_slot_validation` | `3108` |
| `confidential_core_kernel_finish_slot_validation` | `3060` |
| `trace_equivalence` | `3022` |
| `static_checks` | `2993` |
| `leakage_auc` | `2806` |
| `mutual_information` | `2805` |
| `kernel_interface_confinement_boundary_validation` | `2290` |
| `kernel_interface_validation` | `2280` |
| `kernel_confinement_boundary_validation` | `2270` |
| `kernel_refinement_boundary_validation` | `2268` |
| `kernel_interface_singleton_boundary_validation` | `2267` |
| `witness_validation` | `2267` |
| `kernel_finish_boundary_validation` | `2228` |
| `correctness` | `1338` |
| `runtime_boundary_validation` | `837` |
| `kernel_model_alignment_validation` | `169` |
| `overheads` | `135` |
| `paper_main_family_boundary_validation` | `1` |
| `confidential_fragment_validation` | `0` |
| `paper_main_slot_boundary_validation` | `0` |

## Largest Materialized Artifacts

| Report Field | Bytes |
| --- | ---: |
| `canonical_pathoram_pair_validation.scenarios[1].certificate_json_bytes` | `189305140` |
| `fresh_coin_validation.scenarios[1].witness_family_json_bytes` | `94647675` |
| `canonical_pathoram_pair_validation.scenarios[0].certificate_json_bytes` | `8216346` |
| `tamper_validation.scenarios[47].artifact_json_bytes` | `8216346` |
| `tamper_validation.scenarios[48].artifact_json_bytes` | `8216346` |
| `fresh_coin_validation.scenarios[0].witness_family_json_bytes` | `4105222` |
| `tamper_validation.scenarios[44].artifact_json_bytes` | `4105222` |
| `confidential_proof_family_slot_assurance_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560961` |
| `confidential_proof_family_assurance_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560880` |
| `confidential_proof_family_finish_slot_boundary_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560846` |
| `confidential_proof_family_boundary_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560799` |
| `confidential_proof_family_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560783` |
| `confidential_proof_family_kernel_interface_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560765` |
| `confidential_proof_family_refinement_boundary_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560747` |
| `confidential_proof_family_slot_boundary_validation.scenarios[15].confidential_proof_bundle_family_json_bytes` | `2560718` |
| `pathoram_pair_validation.scenarios[3].certificate_json_bytes` | `1619968` |
| `confidential_proof_family_kernel_interface_validation.scenarios[14].confidential_proof_bundle_family_json_bytes` | `818754` |
| `confidential_proof_family_slot_assurance_validation.scenarios[14].confidential_proof_bundle_family_json_bytes` | `818734` |
| `confidential_proof_family_assurance_validation.scenarios[14].confidential_proof_bundle_family_json_bytes` | `818727` |
| `confidential_proof_family_boundary_validation.scenarios[14].confidential_proof_bundle_family_json_bytes` | `818727` |

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
| Trusted Rust runtime surface | `10372` |
| Outer runtime risk surface | `896` |
| Lean theorem/checker repo surface | `37246` |

## Current TCB Table

| Component | In Current Proof-Grade TCB? | Role |
| --- | --- | --- |
| Lean kernel plus Lean theorem/checker development | `true` | trusted proof checker and theorem body |
| Explicit backend / cryptographic / deployment assumptions | `true` | trusted assumptions |
| Rust runtime kernel plus witness / certificate / bundle extraction and serialization | `true` | currently trusted for implementation honesty; the remaining trust point is now frozen explicitly as PaperMainRuntimeKernelBoundary and the stronger PaperMainRuntimeKernelSlotBoundary route, with PaperMainRuntimeKernelAssumptions retained only as a lower-level projection wrapper |
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
| `PaperMainRuntimeKernelBoundary / PaperMainRuntimeKernelSlotBoundary` | records the exact runtime-side paper boundary: one valid explicit runtime kernel-interface bundle per witness, and in the stronger slot route one fixed confidential slot program whose expected kernel steps match that bundle exactly | explicit Lean boundaries in PaperPathOramTheoremRoute.lean; they now project mechanically to the native RuntimeProofGradeKernelInterface theorem, the explicit RuntimeKernelConfinementBoundary, and valid native shell-boundary bundles, the top-level paper assumption bundles now carry these boundary facts directly, proof-grade seeded paper-main bundles can discharge them mechanically, but they are not yet discharged for the real runtime by a machine-checked refinement plus confinement theorem |
| `TEE deployment assumptions` | enclave memory confidentiality/integrity, attestation authenticity, rollback/freshness discipline, and the stated crash/patch model | required by the final malicious-host deployment theorem; not yet fully closed in Lean |
