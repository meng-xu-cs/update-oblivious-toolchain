//! Claim / evaluation artifact manifest (Issue 21).
//!
//! Emits a generated mapping from every claim, trusted assumption, non-claim,
//! and TCB component in `docs/claim-boundary.md` to the source, Lean, runtime/
//! compiler, and benchmark/result artifacts that support it, plus the command
//! that validates it. Three artifacts are produced:
//!
//! - `results/claim_artifact_manifest.json` — the full per-entry artifact map;
//! - `results/claim_status.json` — id/text/status summary plus the fail-closed
//!   doc-coverage checks;
//! - `results/claim_status.md` — a human-readable rendering of the status table.
//!
//! The report fails closed: every manifest entry's `doc_anchor` must appear in
//! `docs/claim-boundary.md`, and every structured entity the doc declares (each
//! assumption-table row, each TCB-table row, each non-claim bullet) must be
//! covered by a manifest entry. If the doc names a claim/assumption/non-claim
//! that the manifest does not carry, `accepted` is `false` and CI rejects it.

use anyhow::{anyhow, Result};
use serde_json::{json, Value as JsonValue};
use std::fs;
use std::path::{Path, PathBuf};

pub const CLAIM_MANIFEST_SCHEMA: &str = "uo.claim_artifact_manifest.v1";
pub const CLAIM_STATUS_SCHEMA: &str = "uo.claim_status.v1";

/// Allowed claim status values (Issue 21).
const STATUS_LEAN_PROVED: &str = "Lean-proved";
const STATUS_GENERATED_CHECKED: &str = "generated-and-checked";
const STATUS_SOURCE_FROZEN: &str = "source-frozen";
const STATUS_EMPIRICAL: &str = "empirically-tested";
const STATUS_TRUSTED: &str = "trusted";
const STATUS_EXPERIMENTAL: &str = "experimental";
const STATUS_NON_CLAIM: &str = "non-claim";

const ALLOWED_STATUSES: &[&str] = &[
    STATUS_LEAN_PROVED,
    STATUS_GENERATED_CHECKED,
    STATUS_SOURCE_FROZEN,
    STATUS_EMPIRICAL,
    STATUS_TRUSTED,
    STATUS_EXPERIMENTAL,
    STATUS_NON_CLAIM,
];

struct ClaimEntry {
    id: &'static str,
    /// Manifest category: claim, assumption, non_claim, or tcb.
    category: &'static str,
    text: &'static str,
    status: &'static str,
    /// A substring that must appear verbatim in `docs/claim-boundary.md`. Used
    /// both to prove the manifest does not invent claims and to cover the
    /// structured doc entities.
    doc_anchor: &'static str,
    source_files: &'static [&'static str],
    lean_modules: &'static [&'static str],
    runtime_compiler_files: &'static [&'static str],
    benchmark_result_files: &'static [&'static str],
    validation_command: &'static str,
}

const CLAIM_ENTRIES: &[ClaimEntry] = &[
    // -------------------------- Theorem / backend claims --------------------------
    ClaimEntry {
        id: "paper-update-obliviousness-theorem",
        category: "claim",
        text: "For every admitted package, two executions with the same public projection have equal normalized hostile-host observations outside the artifact-declared releases (status, plaintext return, encrypted-return ciphertext): exactly for the exact backends, and up to the Path ORAM storage relation on the proof-grade Path ORAM routes.",
        status: STATUS_LEAN_PROVED,
        doc_anchor: "update-obliviousness theorem",
        source_files: &["crates/uo-core/src/lib.rs"],
        lean_modules: &[
            "proof/lean/UOToolchain/ProofGradeRoot.lean",
            "proof/lean/UOToolchain/PaperMainTheorem.lean",
            "proof/lean/UOToolchain/PaperMainReleases.lean",
            "proof/lean/UOToolchain/KernelPaperMain.lean",
            "proof/lean/UOToolchain/KernelAdmission.lean",
            "proof/lean/UOToolchain/PathOramKernelPaperMain.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &[
            "results/bridge_validation.json",
            "results/trace_equivalence.json",
            "results/static_checks.json",
        ],
        validation_command: "lake build UOToolchain.ProofGradeRoot",
    },
    ClaimEntry {
        id: "deployment-acceptance-theorem",
        category: "claim",
        text: "A production runtime accepts a call only under a current admitted-package identity, deployment policy hash match, return-channel session match, freshness evidence and the hash of the receipt it issued last, and answers with the next receipt of the deployment's chain; a replayed, reordered or skipped receipt does not follow.",
        status: STATUS_LEAN_PROVED,
        doc_anchor: "ProductionContractInstance::call_authorized",
        source_files: &["crates/uo-core/src/lib.rs"],
        lean_modules: &["proof/lean/UOToolchain/DeploymentAcceptance.lean"],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &["results/bridge_validation.json"],
        validation_command: "cargo test -p uo-evm",
    },
    ClaimEntry {
        id: "exact-uo-backends",
        category: "claim",
        text: "Exact-UO is claimed for the exact backends on the instrumented abstract/runtime model: UOCell, UOArray, and full-scan UOMap.",
        status: STATUS_LEAN_PROVED,
        doc_anchor: "Exact-UO is claimed for exact backends",
        source_files: &["crates/uo-core/src/trace.rs"],
        lean_modules: &[
            "proof/lean/UOToolchain/ProofGradeRoot.lean",
            "proof/lean/UOToolchain/KernelExactTrace.lean",
            "proof/lean/UOToolchain/ExactObjectLayout.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/objects.rs"],
        benchmark_result_files: &["results/trace_equivalence.json", "results/correctness.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only trace-equivalence --out-dir results",
    },
    ClaimEntry {
        id: "computational-uo-path-oram-local",
        category: "claim",
        text: "The bounded local-position-map Path ORAM route path_oram_local_posmap_v1 (capacity 128) executes; its Lean paper-main theorem holds over admitted configurations given bundle evidence, whose leaf obligation follows from the leaf model without seed enumeration, and the bundle is derived for a concrete single-access instance (SingleAccessMap.put) and, for the multi-access entrypoints, from one runtime run per side whose leaves are substituted for every other tape, with runtime runs on sampled tapes checked against the substitution.",
        status: STATUS_GENERATED_CHECKED,
        doc_anchor: "path_oram_local_posmap_v1",
        source_files: &["crates/uo-core/src/trace.rs"],
        lean_modules: &[
            "proof/lean/UOToolchain/PathOramLocalPosmapV1.lean",
            "proof/lean/UOToolchain/RuntimePaperInstantiation.lean",
            "proof/lean/UOToolchain/RuntimeCoins.lean",
            "proof/lean/UOToolchain/PathOramFreshLeaves.lean",
            "proof/lean/UOToolchain/PathOramAdmitted.lean",
            "proof/lean/UOToolchain/PathOramTapeWitness.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/controller.rs"],
        benchmark_result_files: &["results/bridge_validation.json", "results/capacity_sweep.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-consistency --out-dir results",
    },
    ClaimEntry {
        id: "computational-uo-path-oram-private",
        category: "claim",
        text: "The private-position-map Path ORAM route path_oram_private_posmap_v1 lifts the local route's capacity cap and keeps a map as an oblivious AVL tree of preallocated nodes in one Path ORAM tree, each node holding its children's leaves, so the position map recurses through the tree: a get makes h node accesses and a put 3h + 1, h the largest AVL height for the capacity, each reading and writing one path, and an operation reads and writes its header and stash pages once; a write also makes a get that finds whether its key is present, unless the program shows that the most recent access to the map is a get of the same key, whose presence it reuses; its Lean paper-main theorem holds over admitted configurations whose maps use either scheme, given the same bundle evidence, with the stash bounded by the Path ORAM bound plus the 3h + 1 nodes an operation returns to it (stashOverflowBounded), and the bundle is derived for ERC20Lite.transferFrom with balances on the private scheme from one runtime run per side whose leaves are substituted for every other tape, with runtime runs on sampled tapes checked against the substitution.",
        status: STATUS_GENERATED_CHECKED,
        doc_anchor: "path_oram_private_posmap_v1",
        source_files: &[
            "crates/uo-core/src/trace.rs",
            "crates/uo-core/src/manifest.rs",
            "runtime/uo-evm/src/generated_oram_codecs.rs",
        ],
        lean_modules: &[
            "proof/lean/UOToolchain/PathOramPrivatePosmapV1.lean",
            "proof/lean/UOToolchain/PathOramTreeShape.lean",
            "proof/lean/UOToolchain/RuntimeCoins.lean",
            "proof/lean/UOToolchain/PathOramAdmitted.lean",
            "proof/lean/UOToolchain/PathOramTapeWitness.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/controller.rs"],
        benchmark_result_files: &["results/bridge_validation.json", "results/capacity_sweep.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-consistency --out-dir results",
    },
    ClaimEntry {
        id: "path-oram-kernel-premises",
        category: "claim",
        text: "On both Path ORAM routes, the paper-main theorems' public outcome, boundary schedule, final public-state record and release premises are discharged for entrypoints whose kernel program is admitted, from the same kernel models as on the exact route, given a denotation of the admitted configurations as admitted kernel runs that keeps the public projection; the modeled boundary schedule leaves and re-enters the enclave around each of the call's ORAM accesses, whose number the program and its maps' schemes fix. The runtime's outcomes, boundary schedules and final records are checked against the models on every Path ORAM experiment run, not proved to follow them.",
        status: STATUS_LEAN_PROVED,
        doc_anchor: "kernelOramBoundarySchedule",
        source_files: &["crates/uo-core/src/manifest.rs"],
        lean_modules: &[
            "proof/lean/UOToolchain/PathOramKernelPaperMain.lean",
            "proof/lean/UOToolchain/KernelPaperMain.lean",
            "proof/lean/UOToolchain/PathOramAdmitted.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/controller.rs"],
        benchmark_result_files: &["results/trace_equivalence.json", "results/static_checks.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only trace-equivalence --out-dir results",
    },
    ClaimEntry {
        id: "path-oram-private-avl-map-semantics",
        category: "claim",
        text: "The private scheme's AVL map algorithm, modeled over inductive trees with the runtime's walk, successor delete, rotation rule and node-access counts, implements a finite map: with the walk bounded by the capacity's largest AVL height, a get returns the key's value and a put writes, updates or deletes it, keeps the tree sorted, balanced and within the capacity, and overflows exactly when it would insert into a full map; the runtime's tree_get and tree_put are replayed against the model, not proved to follow it.",
        status: STATUS_LEAN_PROVED,
        doc_anchor: "UOToolchain/PathOramAvlMap.lean",
        source_files: &["runtime/uo-evm/src/avl_map_replay.rs"],
        lean_modules: &[
            "proof/lean/UOToolchain/PathOramAvlMap.lean",
            "proof/lean/UOToolchain/PathOramAvlMapReplay.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/generated_oram_codecs.rs"],
        benchmark_result_files: &[
            "results/path_oram_avl_map_replay.json",
            "results/path_oram_avl_map_replay_full.json",
        ],
        validation_command: "cargo run -q -p mplus-probe -- --only path-oram-avl-map-replay --out-dir results",
    },
    ClaimEntry {
        id: "path-oram-tape-substitution-tested",
        category: "claim",
        text: "That a runtime run of a call on another tape is the representative run with that tape's leaves substituted, which the tape-family theorems take from one runtime run, is tested and not proved of the Rust runtime: on maps of both Path ORAM schemes at three capacities each, calls of seven kinds (a read that hits, one that misses, an insert, an overwrite, a delete, a delete of an absent key and a write that aborts), each after a setup with deletes and aborts, run on 16 other deployment seeds each, and the Lean checker finds every one of the 1,344 runs equal to the substituted run.",
        status: STATUS_EMPIRICAL,
        doc_anchor: "tape_substitution_full.json",
        source_files: &["probe/mplus-probe/src/tape_substitution.rs"],
        lean_modules: &[
            "proof/lean/UOToolchain/PathOramTapeWitness.lean",
            "proof/lean/CheckPathOramTapeSamples.lean",
        ],
        runtime_compiler_files: &["runtime/uo-evm/src/oram.rs"],
        benchmark_result_files: &[
            "results/tape_substitution.json",
            "results/tape_substitution_full.json",
        ],
        validation_command: "cargo run -q --release -p mplus-probe -- --only tape-substitution-full --out-dir results",
    },
    ClaimEntry {
        id: "admitted-package-identity-hash",
        category: "claim",
        text: "The artifact-level admitted-package hash is a canonical SHA-256 binding over source-language tag, semantics-profile tag, source bytes, sidecar metadata, compilation mode, compiler version, toolchain digest, and package schema tag.",
        status: STATUS_GENERATED_CHECKED,
        doc_anchor: "admitted-package hash",
        source_files: &["crates/uo-core/src/artifact.rs"],
        lean_modules: &["proof/lean/UOToolchain/TranslationValidationJson.lean"],
        runtime_compiler_files: &["compiler/uo-solc/src/lib.rs"],
        benchmark_result_files: &["results/bridge_validation.json"],
        validation_command: "cargo test -p uo-core",
    },
    ClaimEntry {
        id: "executable-semantics-profile",
        category: "claim",
        text: "Every artifact declares the executable-semantics profile tag uo-evm-modular256-v1, bound into the admitted-package hash, pinning the executable divergences from Solidity 0.8; the proof-grade checker rejects an unknown or divergent profile.",
        status: STATUS_GENERATED_CHECKED,
        doc_anchor: "uo-evm-modular256-v1",
        source_files: &["crates/uo-core/src/artifact.rs"],
        lean_modules: &["proof/lean/UOToolchain/SolidityDialectBoundary.lean"],
        runtime_compiler_files: &["crates/uo-core/src/translation_validation.rs"],
        benchmark_result_files: &["results/bridge_validation.json"],
        validation_command: "cargo test -p uo-core",
    },
    ClaimEntry {
        id: "source-backed-runtime-boundaries",
        category: "claim",
        text: "The source-backed runtime implementation boundaries are source-frozen/static-drift evidence, not a full semantics-of-Rust refinement; proof-critical obligations may not rest solely on a source regression.",
        status: STATUS_SOURCE_FROZEN,
        doc_anchor: "source-frozen/static-drift evidence",
        source_files: &["crates/uo-core/src/runtime_boundary_schema.rs"],
        lean_modules: &["proof/lean/UOToolchain/ProofGradeRoot.lean"],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &["results/runtime_boundary_validation.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only runtime-boundary-validation --out-dir results",
    },
    ClaimEntry {
        id: "storage-boundary-log",
        category: "claim",
        text: "Every sealed record the runtime opens or seals crosses to a storage adapter, which logs the read with the record it keeps and the write with the class it computes from its own records. On every benchmark and sealed backend the adapter's writes are the trace's writes of sealed objects, each an Update, and its reads are the trace's reads, except that a Path ORAM map's counter and metadata pages cross once per call where the trace names them at every access or operation. A runtime restarted from the adapter's files answers as before and repeats no nonce. Empirically tested over the benchmarks; the places where a record crosses are source-frozen.",
        status: STATUS_EMPIRICAL,
        doc_anchor: "storage adapter",
        source_files: &["runtime/uo-store/src/storage.rs"],
        lean_modules: &["proof/lean/UOToolchain/RuntimeImplementationInterface.lean"],
        runtime_compiler_files: &[
            "runtime/uo-store/src/generated_surface.rs",
            "runtime/uo-evm/src/generated_object_helpers.rs",
            "runtime/uo-evm/src/engine.rs",
            "runtime/uo-evm/src/store_meta.rs",
        ],
        benchmark_result_files: &[
            "results/storage_boundary.json",
            "results/runtime_boundary_validation.json",
        ],
        validation_command:
            "cargo run -q -p mplus-probe -- --only storage-boundary --out-dir results",
    },
    ClaimEntry {
        id: "dsl-admission-subset",
        category: "claim",
        text: "uo-solc admits the uo-solidity-like-dsl-v1 subset and rejects every unsupported feature with a diagnostic that names it; admission is empirically exercised, not a semantic proof.",
        status: STATUS_EMPIRICAL,
        doc_anchor: "uo-solidity-like-dsl-v1",
        source_files: &["docs/supported-subset.md"],
        lean_modules: &[],
        runtime_compiler_files: &["compiler/uo-solc/src/lib.rs"],
        benchmark_result_files: &["results/admission_matrix.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only admission-matrix --out-dir results",
    },
    ClaimEntry {
        id: "insecure-evaluation-baselines",
        category: "claim",
        text: "Executable insecure raw baselines (insecure-eval-raw) run confidential work on raw backends to measure overhead and leakage; they are evaluation-only and never admitted by the proof-grade or deployment paths.",
        status: STATUS_EXPERIMENTAL,
        doc_anchor: "Executable insecure raw baselines",
        source_files: &["probe/mplus-probe/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &["results/overheads.json", "results/leakage_auc.json"],
        validation_command: "cargo run -q -p mplus-probe --features insecure-eval-raw -- --only overheads --out-dir results",
    },
    // ------------------------------ Trusted assumptions ------------------------------
    ClaimEntry {
        id: "assumption-bucket-encryption-indcpa",
        category: "assumption",
        text: "bucketEncryptionINDCPA: hides Path ORAM bucket/path ciphertext contents; named in Lean and not formalized (a Prop field that no proof uses and the checkers fill with True), grounded in the runtime ChaCha20Poly1305 sealed-record boundary.",
        status: STATUS_TRUSTED,
        doc_anchor: "bucketEncryptionINDCPA",
        source_files: &["runtime/uo-store/src/lib.rs"],
        lean_modules: &["proof/lean/UOToolchain/PathOramLocalPosmapV1.lean"],
        runtime_compiler_files: &["runtime/uo-store/src/lib.rs"],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    ClaimEntry {
        id: "assumption-metadata-encryption-indcpa",
        category: "assumption",
        text: "metadataEncryptionINDCPA: hides encrypted position-map metadata pages; named in Lean and not formalized, paired with the same sealed-record crypto route.",
        status: STATUS_TRUSTED,
        doc_anchor: "metadataEncryptionINDCPA",
        source_files: &["runtime/uo-store/src/lib.rs"],
        lean_modules: &["proof/lean/UOToolchain/PathOramLocalPosmapV1.lean"],
        runtime_compiler_files: &["runtime/uo-store/src/lib.rs"],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    ClaimEntry {
        id: "assumption-stash-overflow-bounded",
        category: "assumption",
        text: "stashOverflowBounded: bounds Path ORAM stash failure for deployed parameters; named in Lean and not formalized, paired with the JACM stash theorem at Z = 5 and pinned parameters.",
        status: STATUS_TRUSTED,
        doc_anchor: "stashOverflowBounded",
        source_files: &["runtime/uo-evm/src/controller.rs"],
        lean_modules: &["proof/lean/UOToolchain/PathOramLocalPosmapV1.lean"],
        runtime_compiler_files: &["runtime/uo-evm/src/controller.rs"],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    ClaimEntry {
        id: "assumption-runtime-key-derivation",
        category: "assumption",
        text: "Runtime key derivation: each object's storage key, initial placement and Path ORAM leaf coins derive from a 256-bit master secret from the OS by HKDF-SHA256, one label per use, and the ChaCha20 generator; trusted and not modeled in Lean, with the derivation's call sites pinned by the runtime boundary validation.",
        status: STATUS_TRUSTED,
        doc_anchor: "Runtime key derivation",
        source_files: &["runtime/uo-evm/src/secret.rs"],
        lean_modules: &[],
        runtime_compiler_files: &[
            "runtime/uo-evm/src/secret.rs",
            "runtime/uo-evm/src/engine.rs",
        ],
        benchmark_result_files: &["results/runtime_boundary_validation.json"],
        validation_command:
            "cargo run -q -p mplus-probe -- --only runtime-boundary-validation --out-dir results",
    },
    ClaimEntry {
        id: "assumption-return-channel-aead",
        category: "assumption",
        text: "Return-channel AEAD: a value returned under encrypted_to_client is hidden from the host by ChaCha20Poly1305 under the session key, with associated data that bind the package, the entrypoint, the public arguments and the session, and a nonce hashed from the runtime's freshness counters; the theorems erase the ciphertext and the tag as a declared release, so the assumption is trusted and not named in Lean, and the session key comes from an attested key exchange the repository does not implement.",
        status: STATUS_TRUSTED,
        doc_anchor: "Return-channel AEAD",
        source_files: &["runtime/uo-evm/src/return_channel.rs"],
        lean_modules: &["proof/lean/UOToolchain/KernelPaperMain.lean"],
        runtime_compiler_files: &[
            "runtime/uo-evm/src/return_channel.rs",
            "runtime/uo-evm/src/freshness.rs",
        ],
        benchmark_result_files: &["results/trace_equivalence.json"],
        validation_command:
            "cargo run -q -p mplus-probe -- --only trace-equivalence --out-dir results",
    },
    ClaimEntry {
        id: "assumption-tee-deployment",
        category: "assumption",
        text: "TEE deployment assumptions: enclave memory confidentiality/integrity, attestation authenticity, rollback resistance, freshness, crash recovery, and patch-level trust; explicit Lean bundle SgxDeploymentAssumptions.",
        status: STATUS_TRUSTED,
        doc_anchor: "TEE deployment assumptions",
        source_files: &["crates/uo-core/src/lib.rs"],
        lean_modules: &["proof/lean/UOToolchain/DeploymentAcceptance.lean"],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    ClaimEntry {
        id: "assumption-parser-preprocessing-equivalence",
        category: "assumption",
        text: "Parser/preprocessing equivalence: connects raw Solidity-like source text to the post-resolution AST consumed by Lean; still a trusted front-end surface.",
        status: STATUS_TRUSTED,
        doc_anchor: "Parser/preprocessing equivalence",
        source_files: &["compiler/uo-solc/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["compiler/uo-solc/src/lib.rs"],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    ClaimEntry {
        id: "assumption-real-keccak-equivalence",
        category: "assumption",
        text: "Real Keccak equivalence: connects runtime tiny_keccak Keccak::v256() to the Lean mock-hash abstraction; not yet proved, Lean preservation uses the shared abstraction.",
        status: STATUS_TRUSTED,
        doc_anchor: "Real Keccak equivalence",
        source_files: &["runtime/uo-precompiles/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["runtime/uo-precompiles/src/lib.rs"],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    // ---------------------------------- Non-claims ----------------------------------
    ClaimEntry {
        id: "nonclaim-production-restart-and-store-rollback",
        category: "non_claim",
        text: "Not claimed: a restart of a deployment from OS randomness, whose master secret is in memory alone, or the detection of a store that was rolled back or holds an older record of a location. A restart relies on the rollback resistance of the TEE deployment assumptions.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "a restart of a deployment from OS randomness",
        source_files: &["docs/claim-boundary.md"],
        lean_modules: &[],
        runtime_compiler_files: &["runtime/uo-evm/src/engine.rs"],
        benchmark_result_files: &["results/storage_boundary.json"],
        validation_command:
            "cargo run -q -p mplus-probe -- --only storage-boundary --out-dir results",
    },
    ClaimEntry {
        id: "nonclaim-machine-code-equivalence",
        category: "non_claim",
        text: "Not claimed: downstream machine-code equivalence below the checked runtime boundary. Would require additional models and proofs.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "downstream machine-code equivalence",
        source_files: &["docs/claim-boundary.md"],
        lean_modules: &[],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-status --out-dir results",
    },
    ClaimEntry {
        id: "nonclaim-rust-semantics-refinement",
        category: "non_claim",
        text: "Not claimed: a complete semantics-of-Rust refinement for every residual implementation detail.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "semantics-of-Rust refinement",
        source_files: &["docs/claim-boundary.md"],
        lean_modules: &[],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-status --out-dir results",
    },
    ClaimEntry {
        id: "nonclaim-sgx-page-identities",
        category: "non_claim",
        text: "Not claimed: raw equality of SGX page identities or full micro-event sequences.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "raw equality of SGX page identities",
        source_files: &["docs/claim-boundary.md"],
        lean_modules: &[],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-status --out-dir results",
    },
    ClaimEntry {
        id: "nonclaim-physical-side-channels",
        category: "non_claim",
        text: "Not claimed: CPU-time, cache-behavior, page-fault, allocator, scheduler, power, electromagnetic, or wall-clock obliviousness.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "cache-behavior, page-fault",
        source_files: &["docs/claim-boundary.md"],
        lean_modules: &[],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-status --out-dir results",
    },
    ClaimEntry {
        id: "nonclaim-mock-hash-keccak-value-equality",
        category: "non_claim",
        text: "Not claimed: value-level equality between the Lean mock hash and real runtime Keccak outputs.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "value-level equality between the Lean mock hash",
        source_files: &["docs/claim-boundary.md"],
        lean_modules: &[],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-status --out-dir results",
    },
    ClaimEntry {
        id: "nonclaim-solidity-08-semantics",
        category: "non_claim",
        text: "Not claimed: Solidity 0.8 checked-arithmetic, division/modulo-by-zero, ABI, revert, or context-variable semantics beyond the admitted public-environment fields.",
        status: STATUS_NON_CLAIM,
        doc_anchor: "Solidity 0.8 checked-arithmetic",
        source_files: &["docs/supported-subset.md"],
        lean_modules: &["proof/lean/UOToolchain/SolidityDialectBoundary.lean"],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "cargo run -q -p mplus-probe -- --only claim-status --out-dir results",
    },
    // ------------------------------ TCB components ------------------------------
    ClaimEntry {
        id: "tcb-lean-kernel",
        category: "tcb",
        text: "Lean kernel plus Lean theorem/checker development: trusted proof checker and theorem body.",
        status: STATUS_TRUSTED,
        doc_anchor: "Lean kernel plus Lean theorem/checker development",
        source_files: &[],
        lean_modules: &["proof/lean/UOToolchain/ProofGradeRoot.lean"],
        runtime_compiler_files: &[],
        benchmark_result_files: &[],
        validation_command: "lake build UOToolchain.ProofGradeRoot",
    },
    ClaimEntry {
        id: "tcb-rust-runtime-kernel",
        category: "tcb",
        text: "Rust runtime kernel plus witness/certificate/bundle extraction and serialization: trusted implementation-side extraction surface.",
        status: STATUS_TRUSTED,
        doc_anchor: "Rust runtime kernel plus witness",
        source_files: &["crates/uo-core/src/confidential_kernel.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["runtime/uo-kernel-runtime/src/lib.rs"],
        benchmark_result_files: &["results/kernel_validation.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only kernel-validation --out-dir results",
    },
    ClaimEntry {
        id: "tcb-source-backed-boundaries",
        category: "tcb",
        text: "Source-backed runtime implementation boundaries: source-frozen/static-drift evidence classified by evidence kind in runtime_boundary_validation.json.",
        status: STATUS_TRUSTED,
        doc_anchor: "Source-backed runtime implementation boundaries",
        source_files: &["crates/uo-core/src/runtime_boundary_schema.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &["results/runtime_boundary_validation.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only runtime-boundary-validation --out-dir results",
    },
    ClaimEntry {
        id: "tcb-fixed-capacity-buffers",
        category: "tcb",
        text: "Fixed-capacity Rust buffer helpers: safe Vec-backed wrappers; no production unsafe or MaybeUninit surface remains in fixed_buffer.",
        status: STATUS_TRUSTED,
        doc_anchor: "Fixed-capacity Rust buffer helpers",
        source_files: &["crates/uo-core/src/fixed_buffer.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["crates/uo-core/src/fixed_buffer.rs"],
        benchmark_result_files: &[],
        validation_command: "cargo test -p uo-core",
    },
    ClaimEntry {
        id: "tcb-trusted-assumptions",
        category: "tcb",
        text: "Explicit backend/crypto/deployment assumptions: trusted assumptions enumerated above and grounded by the Lean assumption budget.",
        status: STATUS_TRUSTED,
        doc_anchor: "Explicit backend/crypto/deployment assumptions",
        source_files: &[],
        lean_modules: &["proof/lean/UOToolchain/PathOramLocalPosmapV1.lean"],
        runtime_compiler_files: &[],
        benchmark_result_files: &["results/lean_assumption_budget.json"],
        validation_command: "scripts/lean_assumption_budget.sh",
    },
    ClaimEntry {
        id: "tcb-rust-outside-kernel",
        category: "tcb",
        text: "Rust code outside the tiny confidential kernel: not part of the confidential-work TCB when pinned to public-only or generated-helper routes.",
        status: STATUS_TRUSTED,
        doc_anchor: "Rust code outside the tiny confidential kernel",
        source_files: &["crates/uo-core/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["runtime/uo-evm/src/lib.rs"],
        benchmark_result_files: &["results/runtime_boundary_validation.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only runtime-boundary-validation --out-dir results",
    },
    ClaimEntry {
        id: "tcb-uo-solc-front-end",
        category: "tcb",
        text: "uo-solc: not trusted as a proof oracle for accepted artifacts, but its parser/preprocessing front end remains trusted.",
        status: STATUS_TRUSTED,
        doc_anchor: "uo-solc",
        source_files: &["compiler/uo-solc/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["compiler/uo-solc/src/lib.rs"],
        benchmark_result_files: &["results/admission_matrix.json"],
        validation_command: "cargo test -p uo-solc",
    },
    ClaimEntry {
        id: "tcb-uo-check",
        category: "tcb",
        text: "uo-check: diagnostics/debug wrapper, outside the proof-grade TCB.",
        status: STATUS_TRUSTED,
        doc_anchor: "uo-check",
        source_files: &["checker/uo-check/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["checker/uo-check/src/lib.rs"],
        benchmark_result_files: &[],
        validation_command: "cargo test -p uo-check",
    },
    ClaimEntry {
        id: "tcb-mplus-probe",
        category: "tcb",
        text: "mplus-probe: orchestration and reporting, outside the proof-grade TCB.",
        status: STATUS_TRUSTED,
        doc_anchor: "mplus-probe",
        source_files: &["probe/mplus-probe/src/lib.rs"],
        lean_modules: &[],
        runtime_compiler_files: &["probe/mplus-probe/src/lib.rs"],
        benchmark_result_files: &["results/acceptance.json"],
        validation_command: "cargo run -q -p mplus-probe -- --only acceptance-check --out-dir results",
    },
];

fn repo_root() -> PathBuf {
    let manifest = Path::new(env!("CARGO_MANIFEST_DIR"));
    manifest
        .join("..")
        .join("..")
        .canonicalize()
        .unwrap_or_else(|_| manifest.to_path_buf())
}

fn read(root: &Path, rel: &str) -> Result<String> {
    let path = root.join(rel);
    fs::read_to_string(&path)
        .map_err(|err| anyhow!("claim-manifest cannot read {}: {err}", path.display()))
}

/// First cell of each table row under a header line containing `header_marker`,
/// with surrounding backticks/whitespace trimmed. Stops at the first non-table
/// line after the header.
fn table_first_cells(doc: &str, header_marker: &str) -> Vec<String> {
    let mut cells = Vec::new();
    let mut in_table = false;
    for line in doc.lines() {
        let trimmed = line.trim();
        if trimmed.contains(header_marker) && trimmed.starts_with('|') {
            in_table = true;
            continue;
        }
        if !in_table {
            continue;
        }
        if !trimmed.starts_with('|') {
            break;
        }
        // Separator row like `| --- | --- |`.
        if trimmed.replace(['|', '-', ' ', ':'], "").is_empty() {
            continue;
        }
        let first = trimmed
            .trim_start_matches('|')
            .split('|')
            .next()
            .unwrap_or("")
            .trim()
            .trim_matches('`')
            .trim()
            .to_string();
        if !first.is_empty() {
            cells.push(first);
        }
    }
    cells
}

/// Bullet items in the section whose heading contains `heading_marker`, until the
/// next `## ` heading.
fn section_bullets(doc: &str, heading_marker: &str) -> Vec<String> {
    let mut bullets = Vec::new();
    let mut in_section = false;
    for line in doc.lines() {
        if line.starts_with("## ") {
            in_section = line.contains(heading_marker);
            continue;
        }
        if !in_section {
            continue;
        }
        let trimmed = line.trim_start();
        if let Some(rest) = trimmed.strip_prefix("- ") {
            bullets.push(rest.trim().to_string());
        }
    }
    bullets
}

fn entry_json(entry: &ClaimEntry) -> JsonValue {
    json!({
        "id": entry.id,
        "category": entry.category,
        "text": entry.text,
        "status": entry.status,
        "doc_anchor": entry.doc_anchor,
        "source_files": entry.source_files,
        "lean_modules": entry.lean_modules,
        "runtime_compiler_files": entry.runtime_compiler_files,
        "benchmark_result_files": entry.benchmark_result_files,
        "validation_command": entry.validation_command,
    })
}

struct Check {
    name: String,
    ok: bool,
    detail: String,
}

fn check(name: impl Into<String>, ok: bool, detail: impl Into<String>) -> Check {
    Check {
        name: name.into(),
        ok,
        detail: detail.into(),
    }
}

/// Whether some manifest entry's `doc_anchor` is contained in `entity` (so the
/// structured doc entity is covered by the manifest).
fn entity_covered(entity: &str) -> bool {
    CLAIM_ENTRIES
        .iter()
        .any(|entry| entity.contains(entry.doc_anchor))
}

/// Run the doc-coverage checks. Returns (checks, all_ok).
fn run_checks(root: &Path, claim_boundary: &str) -> (Vec<Check>, bool) {
    let mut checks = Vec::new();

    // 1. Every manifest entry's doc_anchor must appear in claim-boundary.md, and
    //    its status must be one of the allowed values.
    for entry in CLAIM_ENTRIES {
        checks.push(check(
            format!("anchor-in-doc:{}", entry.id),
            claim_boundary.contains(entry.doc_anchor),
            format!(
                "doc_anchor {:?} for {} appears in docs/claim-boundary.md",
                entry.doc_anchor, entry.id
            ),
        ));
        checks.push(check(
            format!("status-allowed:{}", entry.id),
            ALLOWED_STATUSES.contains(&entry.status),
            format!("{} declares an allowed status ({})", entry.id, entry.status),
        ));
    }

    // 2. Every assumption-table row in the doc must be covered by a manifest
    //    assumption entry (docs may not name an assumption the manifest omits).
    for assumption in table_first_cells(claim_boundary, "| Assumption |") {
        checks.push(check(
            format!("assumption-covered:{assumption}"),
            entity_covered(&assumption),
            format!("assumption-table row {assumption:?} is covered by the manifest"),
        ));
    }

    // 3. Every TCB-table row must be covered.
    for component in table_first_cells(claim_boundary, "| Component |") {
        checks.push(check(
            format!("tcb-covered:{component}"),
            entity_covered(&component),
            format!("TCB-table row {component:?} is covered by the manifest"),
        ));
    }

    // 4. Every non-claim bullet must be covered.
    for non_claim in section_bullets(claim_boundary, "Non-Claims") {
        checks.push(check(
            format!("nonclaim-covered:{}", &non_claim[..non_claim.len().min(40)]),
            entity_covered(&non_claim),
            format!("non-claim {non_claim:?} is covered by the manifest"),
        ));
    }

    // 5. Manifest must carry at least one entry of each category.
    for category in ["claim", "assumption", "non_claim", "tcb"] {
        let count = CLAIM_ENTRIES
            .iter()
            .filter(|entry| entry.category == category)
            .count();
        checks.push(check(
            format!("category-present:{category}"),
            count > 0,
            format!("{count} manifest entries in category {category}"),
        ));
    }

    // 6. Every referenced source / Lean / runtime-compiler file must exist, so
    //    the manifest can never point a claim at a phantom artifact.
    for entry in CLAIM_ENTRIES {
        for file in entry
            .source_files
            .iter()
            .chain(entry.lean_modules.iter())
            .chain(entry.runtime_compiler_files.iter())
        {
            checks.push(check(
                format!("file-exists:{}:{file}", entry.id),
                root.join(file).exists(),
                format!("artifact {file} referenced by {} exists", entry.id),
            ));
        }
    }

    let all_ok = checks.iter().all(|c| c.ok);
    (checks, all_ok)
}

fn checks_json(checks: &[Check]) -> Vec<JsonValue> {
    checks
        .iter()
        .map(|c| json!({"name": c.name, "ok": c.ok, "detail": c.detail}))
        .collect()
}

/// The full per-entry artifact manifest (`claim_artifact_manifest.json`).
pub fn claim_artifact_manifest_json() -> Result<JsonValue> {
    let root = repo_root();
    let claim_boundary = read(&root, "docs/claim-boundary.md")?;
    let (checks, all_ok) = run_checks(&root, &claim_boundary);
    Ok(json!({
        "schema": CLAIM_MANIFEST_SCHEMA,
        "source_of_truth": "docs/claim-boundary.md",
        "entries": CLAIM_ENTRIES.iter().map(entry_json).collect::<Vec<_>>(),
        "entry_count": CLAIM_ENTRIES.len(),
        "checks": checks_json(&checks),
        "accepted": all_ok,
    }))
}

/// The id/text/status summary plus the coverage checks (`claim_status.json`).
pub fn run_claim_status_report() -> Result<JsonValue> {
    let root = repo_root();
    let claim_boundary = read(&root, "docs/claim-boundary.md")?;
    let (checks, all_ok) = run_checks(&root, &claim_boundary);
    let claims = CLAIM_ENTRIES
        .iter()
        .map(|entry| {
            json!({
                "id": entry.id,
                "category": entry.category,
                "status": entry.status,
                "text": entry.text,
                "validation_command": entry.validation_command,
            })
        })
        .collect::<Vec<_>>();
    let mut status_counts = serde_json::Map::new();
    for status in ALLOWED_STATUSES {
        let count = CLAIM_ENTRIES
            .iter()
            .filter(|entry| &entry.status == status)
            .count();
        status_counts.insert((*status).to_string(), json!(count));
    }
    Ok(json!({
        "schema": CLAIM_STATUS_SCHEMA,
        "source_of_truth": "docs/claim-boundary.md",
        "claims": claims,
        "claim_count": CLAIM_ENTRIES.len(),
        "status_counts": status_counts,
        "checks": checks_json(&checks),
        "failing_check_count": checks.iter().filter(|c| !c.ok).count(),
        "accepted": all_ok,
    }))
}

/// The human-readable status table (`claim_status.md`).
pub fn claim_status_markdown() -> String {
    let mut out = String::new();
    out.push_str("# Claim Status\n\n");
    out.push_str(
        "Generated from `docs/claim-boundary.md` by `mplus-probe --only claim-status`. Do not edit by hand.\n\n",
    );
    for category in ["claim", "assumption", "non_claim", "tcb"] {
        let heading = match category {
            "claim" => "## Claims",
            "assumption" => "## Trusted Assumptions",
            "non_claim" => "## Non-Claims",
            _ => "## TCB Components",
        };
        out.push_str(heading);
        out.push_str("\n\n| id | status | claim |\n| --- | --- | --- |\n");
        for entry in CLAIM_ENTRIES.iter().filter(|e| e.category == category) {
            let text = entry.text.replace('|', "\\|");
            out.push_str(&format!(
                "| `{}` | {} | {} |\n",
                entry.id, entry.status, text
            ));
        }
        out.push('\n');
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_manifest_anchor_is_in_the_claim_boundary_doc() {
        let root = repo_root();
        let claim_boundary = read(&root, "docs/claim-boundary.md").unwrap();
        for entry in CLAIM_ENTRIES {
            assert!(
                claim_boundary.contains(entry.doc_anchor),
                "doc_anchor {:?} for {} missing from claim-boundary.md",
                entry.doc_anchor,
                entry.id
            );
        }
    }

    #[test]
    fn doc_structured_entities_are_covered_and_report_is_accepted() {
        let root = repo_root();
        let claim_boundary = read(&root, "docs/claim-boundary.md").unwrap();
        let (checks, all_ok) = run_checks(&root, &claim_boundary);
        let failing: Vec<&str> = checks
            .iter()
            .filter(|c| !c.ok)
            .map(|c| c.name.as_str())
            .collect();
        assert!(all_ok, "failing claim-manifest checks: {failing:?}");
    }

    #[test]
    fn claim_ids_are_unique() {
        let mut ids: Vec<&str> = CLAIM_ENTRIES.iter().map(|e| e.id).collect();
        ids.sort_unstable();
        let len = ids.len();
        ids.dedup();
        assert_eq!(len, ids.len(), "duplicate claim ids in manifest");
    }
}
