# Action Plan

## P0 — Claim-safety fixes

1. Add a public-entrypoint confidential-read ban, or mark all confidential-read entrypoints as confidential. Mirror the rule in Lean. Add negative tests for secret-dependent gas/schedule leaks.
2. Add `serde(deny_unknown_fields)` and raw sidecar hashing. Reject duplicate policy entries and irrelevant fields.
3. Add an admitted-package identity v2 binding the full toolchain/proof/runtime version tuple.
4. Pin abort rollback semantics in IR and runtime; prove source/runtime final-public-state agreement.

## P1 — Theorem reframing

1. Create a direct paper-main relational theorem over `View_SGX`.
2. Add release-function-based declassification theorem.
3. Strengthen adaptive history theorem from conditional projection equality to an inductive noninterference theorem for public strategies.
4. Generate a proof-relevance coverage table for runtime observer fields.

## P2 — Runtime/deployment hardening

1. Bind admitted identity to SGX quote/session transcript.
2. Make production runtime refuse unchecked/unattested artifacts.
3. Mechanize freshness/counter/nonce discipline or make deployment assumptions operationally checkable.
4. Reduce theorem-adjacent unsafe Rust via safe refactor or formal/static verification.

## P3 — Practicality/scaling

1. Replace local position map with recursive/private position map.
2. Replace enumerated proof families with symbolic/compact certificates.
3. Add a small verified environment/auth model.
4. Decide whether to call the source language a Solidity-like DSL or prove a Solidity-version bridge.
