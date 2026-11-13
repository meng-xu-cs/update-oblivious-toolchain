use crate::deployment::{
    validate_production_artifact, validate_production_call_preflight, validate_production_policy,
    validate_production_public_environment_trace, ProductionCallEvidence, ProductionReceipt,
    ProductionRuntimePolicy,
};
use crate::freshness::RuntimeFreshnessState;
use crate::return_channel::ReturnChannelSession;
#[cfg(any(test, feature = "diagnostics"))]
use crate::runtime::{
    audit_contract_kept_witness, bulk_load_contract_map_for_diagnostics,
    keep_decoded_contract_witness,
};
use crate::runtime::{
    deploy_contract_runtime, run_contract_call, stage_contract_runtime, ContractRuntime,
    PathOramFreshCoinPlan,
};
use crate::secret::RuntimeMasterSecret;
use anyhow::{anyhow, bail, Result};
use uo_core::{
    CompiledArtifact, EncryptedReturnPayload, ExecutionTrace, PublicEnvironment, PublicReceipt,
    ReturnPolicy, Value,
};

pub struct ContractInstance {
    artifact: CompiledArtifact,
    state: ContractRuntime,
    /// The seed of a seeded (test or diagnostics) deployment. It tags the
    /// instance's traces so that a run can be replayed. A deployment from OS
    /// randomness has none.
    replay_seed: Option<u64>,
    freshness: RuntimeFreshnessState,
    environment: PublicEnvironment,
    initialized: bool,
}

/// The instance holds the runtime's secrets (its objects' storage keys and
/// leaf-coin seeds), so its `Debug` form shows none of its state.
impl std::fmt::Debug for ContractInstance {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ContractInstance").finish_non_exhaustive()
    }
}

#[cfg(feature = "diagnostics")]
#[derive(Clone, Debug)]
pub struct CallTelemetry {
    pub zero_writes: usize,
}

/// What a call returns to its caller. Of the call's trace, a production
/// build returns the receipt alone: the private evidence stays inside the
/// runtime and is dropped when the call ends. A test or diagnostics build
/// returns the whole trace, from which the proof objects are built.
#[derive(Debug)]
pub struct CallResult {
    pub return_value: Option<Value>,
    pub encrypted_return: Option<EncryptedReturnPayload>,
    pub aborted: bool,
    /// What the observer of the call sees.
    #[cfg(not(any(test, feature = "diagnostics")))]
    pub receipt: PublicReceipt,
    /// The call's receipt and its private evidence.
    #[cfg(any(test, feature = "diagnostics"))]
    pub trace: ExecutionTrace,
}

impl CallResult {
    /// What the observer of the call sees, in every build.
    pub fn receipt(&self) -> &PublicReceipt {
        #[cfg(not(any(test, feature = "diagnostics")))]
        {
            &self.receipt
        }
        #[cfg(any(test, feature = "diagnostics"))]
        {
            &self.trace.receipt
        }
    }

    fn from_staged(
        return_value: Option<Value>,
        encrypted_return: Option<EncryptedReturnPayload>,
        aborted: bool,
        trace: ExecutionTrace,
    ) -> Self {
        Self {
            return_value,
            encrypted_return,
            aborted,
            #[cfg(not(any(test, feature = "diagnostics")))]
            receipt: trace.into_receipt(),
            #[cfg(any(test, feature = "diagnostics"))]
            trace,
        }
    }
}

/// A call executed on a staged copy of committed state and freshness. It is
/// applied to `self` only by `commit_staged`, after all host-visible
/// validation succeeds; otherwise it is dropped and `self` is unchanged. It
/// holds the call's whole trace, which the production checks read; the
/// private evidence leaves it only in a test or diagnostics build.
#[derive(Debug)]
struct StagedCall {
    return_value: Option<Value>,
    encrypted_return: Option<EncryptedReturnPayload>,
    aborted: bool,
    trace: ExecutionTrace,
    zero_writes: usize,
    state: ContractRuntime,
    freshness: RuntimeFreshnessState,
    initialized: bool,
}

/// Preflight the return-channel/session policy for an entrypoint before any
/// execution: `encrypted_to_client` returns require a session, and every other
/// return policy must not be given one. Trace finalization keeps the same
/// checks as defensive assertions.
fn ensure_return_channel_policy(
    entrypoint: &str,
    returns: ReturnPolicy,
    return_channel: Option<&ReturnChannelSession>,
) -> Result<()> {
    match (returns, return_channel) {
        (ReturnPolicy::EncryptedToClient, None) => bail!(
            "entrypoint {entrypoint} with encrypted_to_client return requires a return channel session"
        ),
        (policy, Some(_)) if policy != ReturnPolicy::EncryptedToClient => bail!(
            "entrypoint {entrypoint} has a non-encrypted return policy but a return channel session was supplied"
        ),
        _ => Ok(()),
    }
}

#[derive(Debug)]
pub struct ProductionContractInstance {
    inner: ContractInstance,
    policy: ProductionRuntimePolicy,
    /// The receipt the runtime issued last, for the deployment or for the
    /// last accepted call, and its hash. The next call must name the hash.
    last_receipt: ProductionReceipt,
    last_receipt_sha256: String,
}

/// What an accepted production call returns: the call's result, and the
/// runtime's receipt for it, which follows the receipt the call named.
#[derive(Debug)]
pub struct ProductionCallResult {
    pub call: CallResult,
    pub receipt: ProductionReceipt,
}

#[cfg(feature = "diagnostics")]
#[derive(Debug)]
pub struct DiagnosticCallResult {
    pub call: CallResult,
    pub telemetry: CallTelemetry,
}

impl ProductionContractInstance {
    pub fn deploy(artifact: CompiledArtifact, policy: ProductionRuntimePolicy) -> Result<Self> {
        validate_production_artifact(&artifact)?;
        validate_production_policy(&policy)?;
        Self::from_deployed(ContractInstance::deploy(artifact)?, policy)
    }

    /// Issue the deployment's receipt, the first of the instance's chain.
    fn from_deployed(inner: ContractInstance, policy: ProductionRuntimePolicy) -> Result<Self> {
        let last_receipt = ProductionReceipt::for_deployment(
            &inner.artifact,
            &policy,
            inner.freshness.snapshot(),
            inner.state.public_state_digest()?,
            inner.state.ciphertext_store_digest()?,
        )?;
        let last_receipt_sha256 = last_receipt.sha256()?;
        Ok(Self {
            inner,
            policy,
            last_receipt,
            last_receipt_sha256,
        })
    }

    /// The receipt the runtime issued last: the deployment's, until a call
    /// is accepted, and then the last accepted call's. A caller builds the
    /// evidence of its next call from it: its hash, its freshness epoch and
    /// its counters.
    pub fn last_receipt(&self) -> &ProductionReceipt {
        &self.last_receipt
    }

    #[cfg(any(test, feature = "diagnostics"))]
    #[cfg_attr(all(not(test), feature = "diagnostics"), allow(dead_code))]
    fn deploy_with_authorized_seed(
        artifact: CompiledArtifact,
        policy: ProductionRuntimePolicy,
        deploy_seed: u64,
    ) -> Result<Self> {
        validate_production_artifact(&artifact)?;
        validate_production_policy(&policy)?;
        Self::from_deployed(
            ContractInstance::deploy_with_seed(artifact, deploy_seed)?,
            policy,
        )
    }

    pub fn call_authorized(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        session: &ReturnChannelSession,
        evidence: &ProductionCallEvidence,
    ) -> Result<ProductionCallResult> {
        let environment = self.inner.environment.clone();
        self.call_authorized_with_environment(entrypoint, args, session, environment, evidence)
    }

    pub fn call_authorized_with_environment(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        session: &ReturnChannelSession,
        environment: PublicEnvironment,
        evidence: &ProductionCallEvidence,
    ) -> Result<ProductionCallResult> {
        validate_production_call_preflight(
            &self.inner.artifact,
            &self.policy,
            evidence,
            session,
            &environment,
            self.inner.freshness.snapshot(),
            &self.last_receipt_sha256,
        )?;
        let manifest_entry = self
            .inner
            .artifact
            .contract
            .manifest
            .entrypoints
            .get(entrypoint)
            .ok_or_else(|| anyhow!("manifest entry missing for {entrypoint}"))?;
        let expected_public_environment_projection =
            environment.public_bindings(&manifest_entry.public_env);
        let execution_session = if manifest_entry.returns == ReturnPolicy::EncryptedToClient {
            Some(session)
        } else {
            None
        };
        // Stage the call, run the production checks on the staged trace and
        // build the call's receipt from the staged state, and commit only if
        // all of it succeeds. A failure leaves committed state, freshness
        // and the last receipt untouched.
        let staged =
            self.inner
                .stage_call(entrypoint, args, None, execution_session, Some(environment))?;
        validate_production_public_environment_trace(
            &staged.trace.receipt,
            &expected_public_environment_projection,
        )?;
        let receipt = ProductionReceipt::for_call(
            evidence,
            &self.last_receipt,
            &staged.trace.receipt,
            staged.freshness.snapshot(),
            staged.state.public_state_digest()?,
            staged.state.ciphertext_store_digest()?,
        )?;
        let receipt_sha256 = receipt.sha256()?;
        let call = self.inner.commit_staged(staged).0;
        self.last_receipt = receipt.clone();
        self.last_receipt_sha256 = receipt_sha256;
        Ok(ProductionCallResult { call, receipt })
    }
}

impl ContractInstance {
    /// Deploy from OS randomness. The master secret and the freshness epoch
    /// are drawn independently: the epoch is public, since production call
    /// evidence carries it, and nothing public derives from the secret.
    pub fn deploy(artifact: CompiledArtifact) -> Result<Self> {
        let master = RuntimeMasterSecret::from_os_rng();
        let freshness = RuntimeFreshnessState::from_os_rng();
        Self::deploy_internal(artifact, &master, freshness, None)
    }

    /// Deploy from a seed, so that a test or a diagnostics run can replay
    /// the deployment. The seed is the epoch, the root of the secrets and
    /// the tag of the instance's traces; it protects nothing.
    #[cfg(any(test, feature = "diagnostics"))]
    pub fn deploy_with_seed(artifact: CompiledArtifact, deploy_seed: u64) -> Result<Self> {
        let master = RuntimeMasterSecret::from_diagnostic_seed(deploy_seed);
        let freshness = RuntimeFreshnessState::from_epoch(deploy_seed);
        Self::deploy_internal(artifact, &master, freshness, Some(deploy_seed))
    }

    fn deploy_internal(
        artifact: CompiledArtifact,
        master: &RuntimeMasterSecret,
        freshness: RuntimeFreshnessState,
        replay_seed: Option<u64>,
    ) -> Result<Self> {
        let initialized = !artifact
            .contract
            .manifest
            .entrypoints
            .values()
            .any(|entry| entry.initializer);
        Ok(Self {
            state: deploy_contract_runtime(&artifact.contract.state, master)?,
            artifact,
            replay_seed,
            freshness,
            environment: PublicEnvironment::default(),
            initialized,
        })
    }

    pub fn call(&mut self, entrypoint: &str, args: Vec<Value>) -> Result<CallResult> {
        Ok(self.call_impl(entrypoint, args, None, None, None)?.0)
    }

    pub fn set_public_environment(&mut self, environment: PublicEnvironment) {
        self.environment = environment;
    }

    pub fn call_with_environment(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        environment: PublicEnvironment,
    ) -> Result<CallResult> {
        Ok(self
            .call_impl(entrypoint, args, None, None, Some(environment))?
            .0)
    }

    pub fn call_with_return_channel(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        session: &ReturnChannelSession,
    ) -> Result<CallResult> {
        Ok(self
            .call_impl(entrypoint, args, None, Some(session), None)?
            .0)
    }

    #[cfg(feature = "diagnostics")]
    pub fn call_with_path_oram_fresh_coins(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: PathOramFreshCoinPlan,
    ) -> Result<CallResult> {
        Ok(self
            .call_impl(entrypoint, args, Some(fresh_coins), None, None)?
            .0)
    }

    #[cfg(feature = "diagnostics")]
    pub fn call_with_diagnostics(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
    ) -> Result<DiagnosticCallResult> {
        let (call, zero_writes) = self.call_impl(entrypoint, args, None, None, None)?;
        Ok(DiagnosticCallResult {
            call,
            telemetry: CallTelemetry { zero_writes },
        })
    }

    /// The digest of the committed public state, as a call's public-state
    /// transition record reports it.
    #[cfg(feature = "diagnostics")]
    pub fn public_state_digest(&self) -> Result<String> {
        self.state.public_state_digest()
    }

    /// The digest of the ciphertext the committed state holds in storage,
    /// which a production receipt names. A measurement times it.
    #[cfg(feature = "diagnostics")]
    pub fn ciphertext_store_digest(&self) -> Result<String> {
        self.state.ciphertext_store_digest()
    }

    /// Store `entries` in the map named `map` with no call: the map takes
    /// each write as a committed call's write would reach it, and nothing is
    /// traced, witnessed or proved. The freshness counters do not move. The
    /// capacity sweep fills its maps this way; a production build has no such
    /// function.
    #[cfg(any(test, feature = "diagnostics"))]
    pub fn bulk_load_map_for_diagnostics(
        &mut self,
        map: &str,
        entries: Vec<(Value, Value)>,
    ) -> Result<()> {
        bulk_load_contract_map_for_diagnostics(&mut self.state, map, entries)
    }

    /// Decode the position-map witness of the Path ORAM maps from the whole
    /// store and fail unless the witness the runtime keeps for its calls
    /// equals it. `false` when no call has needed a witness since the
    /// deployment or the last bulk load, so that none is kept. A production
    /// build keeps no witness and has no such function.
    #[cfg(any(test, feature = "diagnostics"))]
    pub fn audit_kept_position_map_witness(&self) -> Result<bool> {
        audit_contract_kept_witness(&self.state)
    }

    /// Decode the position-map witness of the Path ORAM maps from the whole
    /// store and keep it for the next calls, as the first call after a
    /// deployment or a bulk load does. The capacity sweep does it after it
    /// fills a map, so that the calls it times open no record for their
    /// witnesses. A production build keeps no witness and has no such
    /// function.
    #[cfg(any(test, feature = "diagnostics"))]
    pub fn keep_decoded_position_map_witness(&mut self) -> Result<()> {
        keep_decoded_contract_witness(&mut self.state)
    }

    fn call_impl(
        &mut self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        return_channel: Option<&ReturnChannelSession>,
        environment: Option<PublicEnvironment>,
    ) -> Result<(CallResult, usize)> {
        let staged = self.stage_call(entrypoint, args, fresh_coins, return_channel, environment)?;
        Ok(self.commit_staged(staged))
    }

    /// Apply a staged call to `self`. Only called once every host-visible
    /// validation has succeeded, so a failure before this point leaves
    /// committed state, freshness counters, and the initialized flag unchanged.
    fn commit_staged(&mut self, staged: StagedCall) -> (CallResult, usize) {
        self.state = staged.state;
        self.freshness = staged.freshness;
        self.initialized = staged.initialized;
        (
            CallResult::from_staged(
                staged.return_value,
                staged.encrypted_return,
                staged.aborted,
                staged.trace,
            ),
            staged.zero_writes,
        )
    }

    /// Execute a call on a staged copy of committed state and freshness without
    /// mutating `self`. The caller (local or production) commits the result via
    /// `commit_staged` only after all validation passes.
    fn stage_call(
        &self,
        entrypoint: &str,
        args: Vec<Value>,
        fresh_coins: Option<PathOramFreshCoinPlan>,
        return_channel: Option<&ReturnChannelSession>,
        environment: Option<PublicEnvironment>,
    ) -> Result<StagedCall> {
        let function = self
            .artifact
            .contract
            .functions
            .iter()
            .find(|function| function.signature == entrypoint)
            .cloned()
            .ok_or_else(|| anyhow!("unknown entrypoint: {entrypoint}"))?;
        let (initializer, requires_initialized, returns) = {
            let manifest_entry = self
                .artifact
                .contract
                .manifest
                .entrypoints
                .get(entrypoint)
                .ok_or_else(|| anyhow!("manifest entry missing for {entrypoint}"))?;
            if function.public_env != manifest_entry.public_env {
                bail!("entrypoint {entrypoint} public environment manifest drift");
            }
            (
                manifest_entry.initializer,
                manifest_entry.requires_initialized,
                manifest_entry.returns,
            )
        };
        // Preflight the return-channel/session policy before any execution, so a
        // policy violation never creates a trace or touches state/freshness.
        ensure_return_channel_policy(entrypoint, returns, return_channel)?;
        if requires_initialized && !self.initialized {
            bail!("entrypoint {entrypoint} requires initialized contract state");
        }
        if initializer && self.initialized {
            bail!("initializer entrypoint {entrypoint} already executed");
        }
        let source_arg_count = function
            .params
            .len()
            .checked_sub(function.public_env.len())
            .ok_or_else(|| anyhow!("entrypoint {entrypoint} public_env longer than params"))?;
        if source_arg_count != args.len() {
            bail!(
                "entrypoint {} expects {} source args, got {}",
                function.signature,
                source_arg_count,
                args.len()
            );
        }
        let environment = environment.unwrap_or_else(|| self.environment.clone());
        let mut runtime_args = args;
        for field in &function.public_env {
            runtime_args.push(environment.value_for(*field));
        }
        let args = runtime_args.into_boxed_slice();
        let mut staged_freshness = self.freshness.clone();
        let call_freshness = staged_freshness.begin_call()?;
        let mut staged_state = stage_contract_runtime(&self.state)?;
        let (return_value, encrypted_return, aborted, trace, zero_writes) = run_contract_call(
            &mut staged_state,
            &self.artifact,
            &function,
            self.replay_seed,
            call_freshness,
            args,
            fresh_coins,
            return_channel,
        )?;
        staged_freshness.finish_call(aborted)?;
        let initialized = self.initialized || (initializer && !aborted);
        Ok(StagedCall {
            return_value,
            encrypted_return,
            aborted,
            trace,
            zero_writes,
            state: staged_state,
            freshness: staged_freshness,
            initialized,
        })
    }
}

/// Deploy an artifact from OS randomness and call an entrypoint that takes
/// no arguments.
pub fn run_artifact(artifact: &CompiledArtifact, entrypoint: &str) -> Result<CallResult> {
    let mut instance = ContractInstance::deploy(artifact.clone())?;
    instance.call(entrypoint, Vec::new())
}

/// As `run_artifact`, on a deployment that the seed replays.
#[cfg(any(test, feature = "diagnostics"))]
pub fn run_artifact_with_seed(
    artifact: &CompiledArtifact,
    entrypoint: &str,
    deploy_seed: u64,
) -> Result<CallResult> {
    let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), deploy_seed)?;
    instance.call(entrypoint, Vec::new())
}

#[cfg(test)]
mod tests {
    /// Path of a benchmark file under `benches/raw`, resolved from this
    /// crate's manifest directory so the tests do not depend on where the
    /// repository is checked out. Usable both as a runtime path and inside
    /// `include_str!`.
    macro_rules! bench_raw {
        ($name:literal) => {
            concat!(env!("CARGO_MANIFEST_DIR"), "/../../benches/raw/", $name)
        };
    }

    use super::{CallResult, ContractInstance, ProductionContractInstance};
    use crate::deployment::{production_build_profile_sha256, ProductionRuntimePolicy};
    #[cfg(not(feature = "diagnostics"))]
    use crate::deployment::{
        production_public_environment_sha256, production_public_environment_transcript,
        production_translation_validation_certificate_sha256, ProductionCallEvidence,
        ProductionReceipt,
    };
    use crate::return_channel::{
        return_channel_aad_bytes, ReturnChannelSession, RETURN_CHANNEL_SCHEME,
    };
    use crate::runtime::ensure_contract_runtime_cold;
    use crate::runtime::objects::RuntimeObject;
    use crate::runtime::ContractRuntime;
    use chacha20poly1305::aead::AeadInPlace;
    use chacha20poly1305::{ChaCha20Poly1305, KeyInit, Nonce, Tag};
    use sha2::{Digest, Sha256};
    use std::collections::{BTreeMap, BTreeSet};
    use std::fs;
    use std::path::PathBuf;
    #[cfg(not(feature = "diagnostics"))]
    use uo_core::PublicEnvironment;
    use uo_core::{
        canonical_runtime_public_object_ids, public_delta_digest, ContractMetadata,
        EncryptedReturnPayload, ProgramMode, ReturnChannelPublicBinding,
        RuntimeKernelResourceEventKindWitness, RuntimeKernelScratchRegionWitness, Value,
    };

    fn compile_bench(source: &str, metadata: &str, mode: ProgramMode) -> uo_core::CompiledArtifact {
        let parsed_metadata: ContractMetadata = serde_yaml::from_str(metadata).unwrap();
        uo_solc::compile_with_metadata_bytes(source, &parsed_metadata, metadata.as_bytes(), mode)
            .unwrap()
    }

    fn write_temp(name: &str, contents: &str) -> PathBuf {
        // A per-call suffix keeps parallel tests that reuse a label from racing
        // on the same file.
        static NEXT_TEMP: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
        let path = std::env::temp_dir().join(format!(
            "uo-evm-engine-test-{}-{}-{}.sol",
            name,
            std::process::id(),
            NEXT_TEMP.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        fs::write(&path, contents).unwrap();
        path
    }

    fn return_channel_session() -> ReturnChannelSession {
        ReturnChannelSession::new(
            [7u8; 32],
            ReturnChannelPublicBinding {
                scheme: RETURN_CHANNEL_SCHEME.into(),
                session_id: "11".repeat(32),
                client_public_key_hash: "22".repeat(32),
                attestation_transcript_hash: "33".repeat(32),
            },
        )
        .unwrap()
    }

    #[cfg(not(feature = "diagnostics"))]
    fn alternate_return_channel_session() -> ReturnChannelSession {
        ReturnChannelSession::new(
            [8u8; 32],
            ReturnChannelPublicBinding {
                scheme: RETURN_CHANNEL_SCHEME.into(),
                session_id: "44".repeat(32),
                client_public_key_hash: "55".repeat(32),
                attestation_transcript_hash: "66".repeat(32),
            },
        )
        .unwrap()
    }

    fn production_policy() -> ProductionRuntimePolicy {
        ProductionRuntimePolicy {
            runtime_binary_sha256: "aa".repeat(32),
            proof_root_sha256: "bb".repeat(32),
            accepted_sgx_quote_sha256: "cc".repeat(32),
            build_profile_sha256: production_build_profile_sha256(),
        }
    }

    #[cfg(not(feature = "diagnostics"))]
    fn production_evidence(
        artifact: &uo_core::CompiledArtifact,
        policy: &ProductionRuntimePolicy,
        session: &ReturnChannelSession,
        environment: &PublicEnvironment,
        previous: &ProductionReceipt,
    ) -> ProductionCallEvidence {
        let identity = artifact.admitted_package.as_ref().unwrap();
        ProductionCallEvidence {
            admitted_package_sha256: identity.package_sha256.clone(),
            toolchain_manifest_sha256: identity.toolchain_manifest_sha256.clone(),
            runtime_binary_sha256: policy.runtime_binary_sha256.clone(),
            proof_root_sha256: policy.proof_root_sha256.clone(),
            sgx_quote_sha256: policy.accepted_sgx_quote_sha256.clone(),
            build_profile_sha256: policy.build_profile_sha256.clone(),
            public_environment: production_public_environment_transcript(environment),
            public_environment_sha256: production_public_environment_sha256(environment).unwrap(),
            session_id: session.binding().session_id.clone(),
            attestation_transcript_hash: session.binding().attestation_transcript_hash.clone(),
            freshness_epoch: previous.freshness_epoch,
            rollback_counter: previous.rollback_counter,
            next_call_counter: previous.next_call_counter,
            previous_receipt_sha256: previous.sha256().unwrap(),
            translation_validation_certificate_sha256:
                production_translation_validation_certificate_sha256(artifact, policy).unwrap(),
        }
    }

    fn decrypt_return_payload(
        artifact: &uo_core::CompiledArtifact,
        entrypoint: &str,
        public_args: &[String],
        payload: &EncryptedReturnPayload,
        session: &ReturnChannelSession,
    ) -> Vec<u8> {
        let aad = return_channel_aad_bytes(
            artifact,
            entrypoint,
            payload.plaintext_canonical_len,
            public_args,
            &payload.binding,
        )
        .unwrap();
        assert_eq!(payload.aad_hash, hex::encode(Sha256::digest(&aad)));
        let mut ciphertext = hex::decode(&payload.ciphertext).unwrap();
        let nonce = hex::decode(&payload.nonce).unwrap();
        let tag = hex::decode(&payload.tag).unwrap();
        let cipher = ChaCha20Poly1305::new_from_slice(session.key_for_test()).unwrap();
        cipher
            .decrypt_in_place_detached(
                Nonce::from_slice(&nonce),
                &aad,
                ciphertext.as_mut_slice(),
                Tag::from_slice(&tag),
            )
            .unwrap();
        ciphertext
    }

    fn b32(byte: u8) -> Value {
        Value::Bytes32([byte; 32])
    }

    fn assert_objects_are_cold(instance: &ContractInstance) {
        ensure_contract_runtime_cold(
            &instance.state,
            &canonical_runtime_public_object_ids(&instance.artifact.contract.state),
            "in engine test",
        )
        .unwrap();
    }

    #[test]
    fn public_require_after_write_rolls_back_committed_public_state() {
        let source = write_temp(
            "rollback-require",
            r#"
            contract C {
                uint256 private x;
                function setThenFail(uint256 v) public {
                    x = v;
                    require(false);
                }
                function read() public returns (uint256) {
                    return x;
                }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: C
entrypoints:
  setThenFail(uint256):
    confidential: false
    returns: forbidden
    status: public
  read():
    confidential: false
    returns: public
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
            ProgramMode::Raw,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 17).unwrap();

        let failed = instance
            .call("setThenFail(uint256)", vec![Value::uint(7)])
            .unwrap();
        assert!(failed.aborted);
        let transition = failed.trace.public_state_transition.as_ref().unwrap();
        assert!(transition.aborted);
        assert!(transition.commits_initial_on_abort());
        assert_eq!(
            transition.committed_public_state_hash,
            transition.initial_public_state_hash
        );
        assert_ne!(
            transition.candidate_public_state_hash,
            transition.initial_public_state_hash
        );

        let read = instance.call("read()", vec![]).unwrap();
        assert!(!read.aborted);
        assert_eq!(read.return_value, Some(Value::uint(0)));
    }

    fn object_id(instance: &ContractInstance, name: &str) -> u32 {
        instance
            .artifact
            .contract
            .state
            .iter()
            .find(|object| object.name == name)
            .unwrap()
            .id
    }

    #[test]
    fn public_state_transition_records_the_public_delta() {
        let source = write_temp(
            "public-state-delta",
            r#"
            contract C {
                uint256 private x;
                uint256 private y;
                function setX(uint256 v) public {
                    x = v;
                }
                function setThenFail(uint256 v) public {
                    y = v;
                    require(false);
                }
                function read() public returns (uint256) {
                    return x;
                }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: C
entrypoints:
  setX(uint256):
    confidential: false
    returns: forbidden
    status: public
  setThenFail(uint256):
    confidential: false
    returns: forbidden
    status: public
  read():
    confidential: false
    returns: public
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
  y:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#,
            ProgramMode::Raw,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 19).unwrap();
        let x = object_id(&instance, "x");

        // A completed write commits its candidate state; the delta is the
        // written object.
        let before = instance.state.public_state_digest().unwrap();
        let set = instance
            .call("setX(uint256)", vec![Value::uint(7)])
            .unwrap();
        let after = instance.state.public_state_digest().unwrap();
        let transition = set.trace.public_state_transition.as_ref().unwrap();
        assert!(!transition.aborted);
        assert_eq!(transition.initial_public_state_hash, before);
        assert_eq!(transition.candidate_public_state_hash, after);
        assert_eq!(transition.committed_public_state_hash, after);
        assert_ne!(before, after);
        assert_eq!(
            transition.public_delta_hash,
            public_delta_digest(&[x]).unwrap()
        );

        // An aborted write commits the initial state; its delta is empty.
        let failed = instance
            .call("setThenFail(uint256)", vec![Value::uint(9)])
            .unwrap();
        let transition = failed.trace.public_state_transition.as_ref().unwrap();
        assert!(transition.aborted);
        assert_eq!(transition.initial_public_state_hash, after);
        assert_ne!(transition.candidate_public_state_hash, after);
        assert_eq!(transition.committed_public_state_hash, after);
        assert_eq!(
            transition.public_delta_hash,
            public_delta_digest(&[]).unwrap()
        );

        // A read changes nothing.
        let read = instance.call("read()", vec![]).unwrap();
        let transition = read.trace.public_state_transition.as_ref().unwrap();
        assert_eq!(read.return_value, Some(Value::uint(7)));
        assert_eq!(transition.initial_public_state_hash, after);
        assert_eq!(transition.committed_public_state_hash, after);
        assert_eq!(
            transition.public_delta_hash,
            public_delta_digest(&[]).unwrap()
        );
    }

    #[test]
    fn confidential_call_records_its_unchanged_public_state() {
        let source = write_temp(
            "confidential-public-state",
            r#"
            contract C {
                uint256 private p;
                uint256 private secret;
                function setP(uint256 v) public {
                    p = v;
                }
                function setSecret(uint256 amount) public {
                    require(amount < 100);
                    secret = amount;
                }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: C
entrypoints:
  setP(uint256):
    confidential: false
    returns: forbidden
    status: public
  setSecret(uint256):
    confidential: true
    secret_args: [amount]
    returns: forbidden
    status: declassified
    declassifies: [success]
state:
  p:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
  secret:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#,
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 23).unwrap();
        instance
            .call("setP(uint256)", vec![Value::uint(5)])
            .unwrap();
        let public_state = instance.state.public_state_digest().unwrap();
        let empty_delta = public_delta_digest(&[]).unwrap();

        // Completed and aborted confidential calls both leave the public state
        // as it was; only the abort flag differs.
        for (amount, aborted) in [(7, false), (700, true)] {
            let call = instance
                .call("setSecret(uint256)", vec![Value::uint(amount)])
                .unwrap();
            assert_eq!(call.aborted, aborted);
            let transition = call.trace.public_state_transition.as_ref().unwrap();
            assert_eq!(transition.aborted, aborted);
            assert_eq!(transition.initial_public_state_hash, public_state);
            assert_eq!(transition.candidate_public_state_hash, public_state);
            assert_eq!(transition.committed_public_state_hash, public_state);
            assert_eq!(transition.public_delta_hash, empty_delta);
            assert_eq!(instance.state.public_state_digest().unwrap(), public_state);
        }
    }

    #[test]
    fn encrypted_return_requires_session_and_keeps_plaintext_out_of_public_outcome() {
        let source = write_temp(
            "encrypted-return",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#,
            ProgramMode::Uo,
        );

        let mut missing_session = ContractInstance::deploy(artifact.clone()).unwrap();
        let err = missing_session
            .call("f(uint256)", vec![Value::uint(7)])
            .unwrap_err()
            .to_string();
        assert!(err.contains("requires a return channel session"));

        let session = return_channel_session();
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call_with_return_channel("f(uint256)", vec![Value::uint(7)], &session)
            .unwrap();
        let payload = result.encrypted_return.as_ref().unwrap();
        let public_outcome = result.trace.theorem_trace.public_outcome.as_ref().unwrap();

        assert_eq!(result.return_value, None);
        assert_eq!(public_outcome.return_payload, None);
        assert_eq!(
            public_outcome.return_policy,
            uo_core::ReturnPolicy::EncryptedToClient
        );
        assert_eq!(
            public_outcome.encrypted_return_payload.as_ref(),
            Some(payload)
        );
        assert_eq!(public_outcome.output_shape.return_length, payload.wire_len);
        assert_eq!(payload.plaintext_canonical_len, 32);
        assert_eq!(payload.wire_len, 12 + 32 + 16);
        assert_eq!(payload.nonce.len(), 24);
        assert_eq!(payload.tag.len(), 32);
        assert_eq!(payload.ciphertext.len(), 64);
        assert!(!public_outcome
            .declassifies
            .contains(&uo_core::DeclassificationKind::Return));

        let decrypted = decrypt_return_payload(
            &artifact,
            "f(uint256)",
            &public_outcome.public_args,
            payload,
            &session,
        );
        assert_eq!(
            decrypted,
            Value::uint(7).canonical_bytes_boxed().unwrap().into_vec()
        );

        let second = instance
            .call_with_return_channel("f(uint256)", vec![Value::uint(8)], &session)
            .unwrap();
        let second_payload = second.encrypted_return.as_ref().unwrap();
        assert_ne!(payload.nonce, second_payload.nonce);
        let second_decrypted = decrypt_return_payload(
            &artifact,
            "f(uint256)",
            second
                .trace
                .theorem_trace
                .public_outcome
                .as_ref()
                .unwrap()
                .public_args
                .as_ref(),
            second_payload,
            &session,
        );
        assert_eq!(
            second_decrypted,
            Value::uint(8).canonical_bytes_boxed().unwrap().into_vec()
        );
    }

    #[test]
    fn confidential_entrypoint_binds_mixed_public_secret_args_in_declared_order() {
        let source = write_temp(
            "mixed-argument-order",
            r#"
            contract MixedArgumentOrder {
                function f(uint256 left, uint256 secret, uint256 right) public returns (uint256) {
                    return left * 100 + secret * 10 + right;
                }
            }
            "#,
        );
        let artifact = compile_bench(
            source.to_str().unwrap(),
            r#"
contract: MixedArgumentOrder
entrypoints:
  f(uint256,uint256,uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#,
            ProgramMode::Uo,
        );
        let manifest_entry = artifact
            .contract
            .manifest
            .entrypoints
            .get("f(uint256,uint256,uint256)")
            .unwrap();
        assert_eq!(
            manifest_entry.param_names,
            vec!["left".to_owned(), "secret".to_owned(), "right".to_owned()]
        );
        assert_eq!(manifest_entry.secret_args, vec![1]);

        let session = return_channel_session();
        let mut instance = ContractInstance::deploy(artifact.clone()).unwrap();
        let result = instance
            .call_with_return_channel(
                "f(uint256,uint256,uint256)",
                vec![Value::uint(1), Value::uint(7), Value::uint(3)],
                &session,
            )
            .unwrap();
        let public_outcome = result.trace.theorem_trace.public_outcome.as_ref().unwrap();
        assert_eq!(
            public_outcome.public_args.as_ref(),
            ["left=1".to_owned(), "right=3".to_owned()]
        );
        let decrypted = decrypt_return_payload(
            &artifact,
            "f(uint256,uint256,uint256)",
            &public_outcome.public_args,
            result.encrypted_return.as_ref().unwrap(),
            &session,
        );
        assert_eq!(
            decrypted,
            Value::uint(173).canonical_bytes_boxed().unwrap().into_vec()
        );
    }

    #[cfg(not(feature = "diagnostics"))]
    #[test]
    fn production_runtime_requires_attested_receipt_session_and_freshness() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let entrypoint = "add(bytes32,uint256)";
        let args = vec![b32(7), Value::uint(5)];
        let policy = production_policy();
        let session = return_channel_session();
        let environment = PublicEnvironment::default();
        // A seeded deployment is replayed by its seed, so every instance
        // deployed from it below issues this deployment receipt.
        let deployed = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap()
        .last_receipt()
        .clone();
        let evidence = production_evidence(&artifact, &policy, &session, &environment, &deployed);

        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let accepted = production
            .call_authorized(entrypoint, args.clone(), &session, &evidence)
            .unwrap();
        // The call's receipt follows the deployment's, is for this request
        // and this public receipt, and is now the head of the chain.
        accepted.receipt.follows(&deployed).unwrap();
        accepted
            .receipt
            .binds_call(&evidence, accepted.call.receipt())
            .unwrap();
        assert_eq!(production.last_receipt(), &accepted.receipt);

        let mut missing_proof = evidence.clone();
        missing_proof.previous_receipt_sha256.clear();
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &missing_proof)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("previous_receipt_sha256 must be a 64-character hex SHA-256 digest"));

        let mut wrong_proof = evidence.clone();
        wrong_proof.previous_receipt_sha256 = "00".repeat(32);
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_proof)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime previous_receipt_sha256 mismatch"));

        let mut wrong_toolchain = evidence.clone();
        wrong_toolchain.toolchain_manifest_sha256 = "00".repeat(32);
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_toolchain)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime toolchain_manifest_sha256 mismatch"));

        let mut wrong_quote = evidence.clone();
        wrong_quote.sgx_quote_sha256 = "00".repeat(32);
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_quote)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime sgx_quote_sha256 mismatch"));

        let mut wrong_build_profile = evidence.clone();
        wrong_build_profile.build_profile_sha256 = "00".repeat(32);
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_build_profile)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime build_profile_sha256 mismatch"));

        let mut wrong_environment_transcript = evidence.clone();
        wrong_environment_transcript.public_environment[0] =
            format!("msg.sender={}", Value::Address([0x77u8; 20]));
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(
                entrypoint,
                args.clone(),
                &session,
                &wrong_environment_transcript,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime public_environment transcript mismatch"));

        let mut wrong_environment_hash = evidence.clone();
        wrong_environment_hash.public_environment_sha256 = "00".repeat(32);
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_environment_hash)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime public_environment_sha256 mismatch"));

        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(
                entrypoint,
                args.clone(),
                &alternate_return_channel_session(),
                &evidence,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime session_id mismatch"));

        let mut wrong_rollback = evidence.clone();
        wrong_rollback.rollback_counter += 1;
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_rollback)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime rollback_counter mismatch"));

        let mut unadmitted = artifact.clone();
        unadmitted.admitted_package = None;
        let err = ProductionContractInstance::deploy_with_authorized_seed(unadmitted, policy, 91)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime requires admitted_package identity"));

        let mut diagnostics_policy = production_policy();
        diagnostics_policy.build_profile_sha256 = "00".repeat(32);
        let err = ProductionContractInstance::deploy_with_authorized_seed(
            artifact,
            diagnostics_policy,
            91,
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime build_profile_sha256 mismatch"));
    }

    #[cfg(not(feature = "diagnostics"))]
    #[test]
    fn production_runtime_binds_attested_public_environment_context() {
        let source = write_temp(
            "production-env-auth",
            r#"
            contract ProductionEnvAuth {
                uint256 private secret;

                function setSecret(address expected, uint256 amount) public {
                    require(msg.sender == expected);
                    secret = amount;
                }
            }
            "#,
        );
        let metadata = r#"
contract: ProductionEnvAuth
entrypoints:
  setSecret(address,uint256):
    confidential: true
    secret_args: [amount]
    returns: forbidden
    status: public
state:
  secret:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#;
        let artifact = compile_bench(source.to_str().unwrap(), metadata, ProgramMode::Uo);
        let entrypoint = "setSecret(address,uint256)";
        let owner = [0x11u8; 20];
        let other = [0x22u8; 20];
        let args = vec![Value::Address(owner), Value::uint(9)];
        let environment = PublicEnvironment::with_caller(owner);
        let policy = production_policy();
        let session = return_channel_session();

        // A seeded deployment is replayed by its seed, so every instance
        // deployed from it below issues this deployment receipt.
        let deployed = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            41,
        )
        .unwrap()
        .last_receipt()
        .clone();
        let evidence = production_evidence(&artifact, &policy, &session, &environment, &deployed);

        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            41,
        )
        .unwrap();
        let accepted = production
            .call_authorized_with_environment(
                entrypoint,
                args.clone(),
                &session,
                environment.clone(),
                &evidence,
            )
            .unwrap();
        assert!(!accepted.call.aborted);
        assert_eq!(
            accepted
                .call
                .trace
                .theorem_trace
                .public_outcome
                .as_ref()
                .unwrap()
                .public_env
                .as_ref(),
            &[format!("msg.sender={}", Value::Address(owner))]
        );

        let mut production =
            ProductionContractInstance::deploy_with_authorized_seed(artifact, policy, 41).unwrap();
        let err = production
            .call_authorized_with_environment(
                entrypoint,
                args,
                &session,
                PublicEnvironment::with_caller(other),
                &evidence,
            )
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime public_environment transcript mismatch"));
    }

    #[cfg(feature = "diagnostics")]
    #[test]
    fn production_runtime_rejects_diagnostics_build_profile() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let err = ProductionContractInstance::deploy_with_authorized_seed(
            artifact,
            production_policy(),
            91,
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("production runtime build profile enables diagnostics"));
    }

    #[test]
    fn only_a_seeded_deployment_tags_its_traces_with_the_seed() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let entrypoint = "put(bytes32,uint256)";
        let args = || vec![b32(7), Value::uint(5)];

        // A deployment from OS randomness has no seed: its traces carry no
        // seed tag, and neither they nor its `Debug` form carry the epoch
        // it drew.
        let mut unseeded = ContractInstance::deploy(artifact.clone()).unwrap();
        assert_eq!(unseeded.replay_seed, None);
        let epoch = unseeded.freshness.snapshot().epoch.to_string();
        let result = unseeded.call(entrypoint, args()).unwrap();
        assert_eq!(result.trace.runtime_seed(), None);
        let trace_json = serde_json::to_string(&result.trace).unwrap();
        assert!(trace_json.contains("\"runtime_seed\":null"));
        assert!(!trace_json.contains(&epoch));
        assert!(!format!("{unseeded:?}").contains(&epoch));
        // The proof objects of an untagged trace still build, without it.
        let bundle = result.trace.runtime_trusted_kernel_bundle().unwrap();
        assert!(!serde_json::to_string(&bundle).unwrap().contains(&epoch));
        result.trace.runtime_refinement_witness().unwrap();
        result
            .trace
            .runtime_confidential_proof_bundle_family(&artifact)
            .unwrap();

        // A seeded deployment tags its traces, so that a run can be replayed.
        let mut seeded = ContractInstance::deploy_with_seed(artifact, 17).unwrap();
        let result = seeded.call(entrypoint, args()).unwrap();
        assert_eq!(result.trace.runtime_seed(), Some(17));
    }

    /// Contracts that between them hold every kind of sealed object: a cell,
    /// a full-scan map, and Path ORAM maps of both schemes. Each comes with a
    /// call that writes it.
    fn sealing_contracts() -> Vec<(uo_core::CompiledArtifact, &'static str, Vec<Value>)> {
        vec![
            (
                compile_bench(
                    bench_raw!("ConfidentialMixer.sol"),
                    include_str!(bench_raw!("ConfidentialMixer.pathoram.yaml")),
                    ProgramMode::Uo,
                ),
                "deposit(bytes32,uint256)",
                vec![b32(7), Value::uint(5)],
            ),
            (
                compile_bench(
                    bench_raw!("ERC20Lite.sol"),
                    include_str!(bench_raw!("ERC20Lite.private-posmap.yaml")),
                    ProgramMode::Uo,
                ),
                "mint(address,uint256)",
                vec![Value::Address([0x11; 20]), Value::uint(5)],
            ),
            (
                compile_bench(
                    bench_raw!("RegistryCRUD.sol"),
                    include_str!(bench_raw!("RegistryCRUD.uo.yaml")),
                    ProgramMode::Uo,
                ),
                "upsert(bytes32,uint256)",
                vec![b32(7), Value::uint(5)],
            ),
            (
                compile_bench(
                    bench_raw!("FixedSlotClassifier.sol"),
                    include_str!(bench_raw!("FixedSlotClassifier.uo.yaml")),
                    ProgramMode::Uo,
                ),
                "classify(uint256)",
                vec![Value::uint(1)],
            ),
        ]
    }

    /// The ciphers of a state's sealed objects, by object id.
    fn sealed_ciphers(state: &ContractRuntime) -> Vec<(u32, &uo_store::StoreCipher)> {
        state
            .object_entries_for_test()
            .filter_map(|(id, object)| Some((id, object.sealed_storage_for_test()?.0)))
            .collect()
    }

    /// The counter that a sealed record's nonce carries. A record is a
    /// whole number of 32-byte units, each a marker and 31 bytes of content:
    /// the twelve bytes of the nonce, then the ciphertext and the tag.
    fn sealed_record_counter(record: &[u8]) -> u64 {
        assert_eq!(record.len() % 32, 0, "not a sealed record");
        assert!(matches!(record[0], 0xA5 | 0x5A), "not a sealed record");
        assert!(record.chunks_exact(32).all(|unit| unit[0] == record[0]));
        // The nonce is the first twelve bytes of the first unit's content.
        assert_eq!(record[1..5], [0u8; 4]);
        u64::from_be_bytes(std::array::from_fn(|index| record[5 + index]))
    }

    /// The nonce counters of the records in a state's storage, by object id.
    fn sealed_counters(state: &ContractRuntime) -> BTreeMap<u32, Vec<u64>> {
        state
            .object_entries_for_test()
            .filter_map(|(id, object)| {
                let (_, records) = object.sealed_storage_for_test()?;
                Some((id, records.into_iter().map(sealed_record_counter).collect()))
            })
            .collect()
    }

    #[test]
    fn deployments_from_os_randomness_share_no_epoch_and_no_key() {
        for (artifact, _, _) in sealing_contracts() {
            let lhs = ContractInstance::deploy(artifact.clone()).unwrap();
            let rhs = ContractInstance::deploy(artifact.clone()).unwrap();
            assert_ne!(
                lhs.freshness.snapshot().epoch,
                rhs.freshness.snapshot().epoch
            );
            // Every object of either deployment has a key of its own.
            let ciphers: Vec<&uo_store::StoreCipher> = sealed_ciphers(&lhs.state)
                .into_iter()
                .chain(sealed_ciphers(&rhs.state))
                .map(|(_, cipher)| cipher)
                .collect();
            assert!(ciphers.len() >= 2);
            for (index, cipher) in ciphers.iter().enumerate() {
                for other in &ciphers[index + 1..] {
                    assert_ne!(cipher, other);
                }
            }

            // A seeded deployment is replayed by its seed and by nothing else.
            let seeded = ContractInstance::deploy_with_seed(artifact.clone(), 7).unwrap();
            let replayed = ContractInstance::deploy_with_seed(artifact.clone(), 7).unwrap();
            let reseeded = ContractInstance::deploy_with_seed(artifact, 8).unwrap();
            assert_eq!(
                sealed_ciphers(&seeded.state),
                sealed_ciphers(&replayed.state)
            );
            for ((_, cipher), (_, other)) in sealed_ciphers(&seeded.state)
                .into_iter()
                .zip(sealed_ciphers(&reseeded.state))
            {
                assert_ne!(cipher, other);
            }
        }
    }

    /// A call that is staged and then dropped has sealed records under the
    /// committed keys. The records are gone, but their nonces stay used: the
    /// next call seals with later ones. Before the seal count was kept with
    /// the key, the next call drew the dropped call's nonces again.
    #[test]
    fn a_dropped_staged_call_does_not_give_its_nonces_back() {
        for (artifact, entrypoint, args) in sealing_contracts() {
            let mut instance = ContractInstance::deploy_with_seed(artifact, 7).unwrap();
            instance.call(entrypoint, args.clone()).unwrap();
            let before = sealed_counters(&instance.state);
            assert!(!before.is_empty());

            let staged = instance
                .stage_call(entrypoint, args.clone(), None, None, None)
                .unwrap();
            let dropped = sealed_counters(&staged.state);
            drop(staged);
            assert_eq!(sealed_counters(&instance.state), before);

            instance.call(entrypoint, args).unwrap();
            let after = sealed_counters(&instance.state);
            assert_eq!(
                after.keys().collect::<Vec<_>>(),
                before.keys().collect::<Vec<_>>()
            );

            let mut resealed_objects = 0;
            for (object, counters) in &after {
                // No two records of an object carry the same nonce.
                let distinct: BTreeSet<u64> = counters.iter().copied().collect();
                assert_eq!(distinct.len(), counters.len());

                let old: BTreeSet<u64> = before[object].iter().copied().collect();
                let fresh = |counters: &[u64]| -> BTreeSet<u64> {
                    counters
                        .iter()
                        .copied()
                        .filter(|counter| !old.contains(counter))
                        .collect()
                };
                let dropped_fresh = fresh(&dropped[object]);
                let committed_fresh = fresh(counters);
                // The two calls made the same writes, with different nonces.
                assert_eq!(dropped_fresh.len(), committed_fresh.len());
                assert!(dropped_fresh.is_disjoint(&committed_fresh));
                if let (Some(last_dropped), Some(first_committed)) =
                    (dropped_fresh.iter().max(), committed_fresh.iter().min())
                {
                    assert!(last_dropped < first_committed);
                    resealed_objects += 1;
                }
            }
            assert!(resealed_objects >= 1);
        }
    }

    #[cfg(not(feature = "diagnostics"))]
    #[test]
    fn production_freshness_mismatch_names_the_field_and_prints_no_value() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let entrypoint = "add(bytes32,uint256)";
        let args = vec![b32(7), Value::uint(5)];
        let policy = production_policy();
        let session = return_channel_session();
        let environment = PublicEnvironment::default();
        let deployed = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap()
        .last_receipt()
        .clone();
        let base = production_evidence(&artifact, &policy, &session, &environment, &deployed);
        assert_eq!(
            (
                base.freshness_epoch,
                base.rollback_counter,
                base.next_call_counter
            ),
            (91, 0, 0)
        );
        let evidence =
            |freshness_epoch, rollback_counter, next_call_counter| ProductionCallEvidence {
                freshness_epoch,
                rollback_counter,
                next_call_counter,
                ..base.clone()
            };
        // The runtime's values are 91, 0 and 0. Each error names the field
        // that differs and says nothing more.
        for (evidence, field) in [
            (evidence(92, 0, 0), "freshness_epoch"),
            (evidence(91, 1, 0), "rollback_counter"),
            (evidence(91, 0, 1), "next_call_counter"),
        ] {
            let mut production = ProductionContractInstance::deploy_with_authorized_seed(
                artifact.clone(),
                policy.clone(),
                91,
            )
            .unwrap();
            let err = production
                .call_authorized(entrypoint, args.clone(), &session, &evidence)
                .unwrap_err();
            assert_eq!(
                err.to_string(),
                format!("production runtime {field} mismatch")
            );
        }
    }

    #[test]
    fn engine_source_keeps_secret_object_helpers_behind_runtime_boundary() {
        let source = include_str!("engine.rs")
            .split("#[cfg(test)]")
            .next()
            .expect("engine.rs should contain a test boundary marker");
        let seeded_deploy = source
            .find("pub fn deploy_with_seed")
            .expect("seeded deployment API should exist for diagnostics/tests");
        assert!(
            source[..seeded_deploy]
                .trim_end()
                .ends_with("#[cfg(any(test, feature = \"diagnostics\"))]"),
            "seeded deployment must stay out of the default production API"
        );
        let injected_fresh_coins = source
            .find("pub fn call_with_path_oram_fresh_coins")
            .expect("fresh-coin injection API should exist for diagnostics");
        assert!(
            source[..injected_fresh_coins]
                .trim_end()
                .ends_with("#[cfg(feature = \"diagnostics\")]"),
            "fresh-coin injection must stay out of the default production API"
        );
        let bulk_load = source
            .find("pub fn bulk_load_map_for_diagnostics")
            .expect("bulk-load API should exist for diagnostics/tests");
        assert!(
            source[..bulk_load]
                .trim_end()
                .ends_with("#[cfg(any(test, feature = \"diagnostics\"))]"),
            "the bulk loader changes committed state with no call, so it must stay out of the default production API"
        );
        assert!(
            source.contains("state: ContractRuntime"),
            "engine.rs should hold an opaque runtime wrapper rather than the raw committed state"
        );
        assert!(
            source.contains("run_contract_call"),
            "engine.rs should delegate call execution through the runtime-owned call bridge"
        );
        assert!(
            !source.contains("use crate::runtime::theorem::run_traced_call;"),
            "engine.rs should not import the theorem bridge module directly once runtime.rs owns that boundary"
        );
        assert!(
            !source.contains("use crate::runtime::shell::run_public_entrypoint;"),
            "engine.rs should not import the public shell directly once the runtime bridge owns dispatch"
        );
        assert!(
            !source.contains("ConfidentialCallInputs"),
            "engine.rs should not construct confidential runtime call wrappers directly"
        );
        assert!(
            !source.contains("PublicRuntimeShadowState"),
            "engine.rs should not manipulate the public shadow wrapper type directly once the shell is split out"
        );
        assert!(
            !source.contains("use crate::runtime::objects::RuntimeObject;"),
            "engine.rs implementation should not import RuntimeObject directly"
        );
        assert!(
            !source.contains("use crate::runtime::kernel::RuntimeKernel;"),
            "engine.rs implementation should not import the raw RuntimeKernel directly"
        );
        assert!(
            !source.contains("use crate::runtime::kernel::PublicRuntimeKernel;"),
            "engine.rs should not import the public kernel facade directly once the public and confidential setup paths are delegated"
        );
        assert!(
            source.contains("run_contract_call("),
            "engine.rs should delegate call execution through run_contract_call"
        );
        assert!(
            !source.contains("run_confidential_entrypoint("),
            "engine.rs should not dispatch confidential calls directly once the theorem bridge owns runtime branching"
        );
        assert!(
            !source.contains("run_public_entrypoint("),
            "engine.rs should not dispatch public calls directly once the theorem bridge owns runtime branching"
        );
        assert!(
            !source.contains("prepare_confidential_entrypoint("),
            "engine.rs should not stage confidential manifest-to-kernel planning outside ContractRuntime"
        );
        assert!(
            !source.contains("ConfidentialEntrypointPlan"),
            "engine.rs should not mention the confidential entrypoint plan directly"
        );
        assert!(
            !source.contains("RuntimeKernelRefinementEventWitness"),
            "engine.rs implementation should not construct runtime phase witness events directly"
        );
        for forbidden in [
            ".confidential_slot_program",
            "RuntimeKernelStepWitness",
            "expected_runtime_steps()",
            "max_hash_part_bytes",
            "kernel_steps",
            "max_commit_ops",
        ] {
            assert!(
                !source.contains(forbidden),
                "engine.rs should not derive confidential runtime plan detail `{forbidden}` directly"
            );
        }
        for forbidden_type in [
            "RuntimeControllerObserverCertificate",
            "RuntimePathOramHiddenCertificate",
            "RuntimeTrustedKernelBundle",
        ] {
            assert!(
                !source.contains(forbidden_type),
                "engine.rs implementation should not construct theorem-side certificate type `{forbidden_type}` directly"
            );
        }
        assert!(
            !source.contains("BTreeMap<u32, RuntimeObject>"),
            "engine.rs implementation should not own raw runtime object maps"
        );
        for forbidden in [
            "fn exec_block(",
            "fn exec_statement(",
            "fn eval_expr(",
            "fn eval_binary(",
            "fn store_env_value(",
        ] {
            assert!(
                !source.contains(forbidden),
                "engine.rs should not keep inline public-shell helper `{forbidden}` after the shell split"
            );
        }
        assert!(
            !source.contains("ExecutionTrace {"),
            "engine.rs implementation should not assemble ExecutionTrace directly"
        );
        for forbidden in [
            "prepare_public_shadow(",
            "commit_public_shadow(",
            "replace_with_cold_public_shadow(",
            "ensure_cold_call_boundary(",
            "build_theorem_trace(",
            "finalize_execution_trace(",
            "output_shape_of(",
            "clone_for_tx(",
            "commit(",
            "shadow_load_objects(",
            "shadow_load_public_objects(",
            "shadow_load_confidential_objects(",
            "enable_injected_path_oram_leaf_coins(",
            "install_path_oram_leaf_coins(",
            "ensure_path_oram_leaf_coins_consumed(",
            "path_oram_position_map_witness(",
            "path_oram_access_counter_witness(",
            "into_cold_committed(",
            "committed_cache_is_cold(",
            "cold_store_object(",
            "post_committed_cold_object(",
        ] {
            assert!(
                !source.contains(forbidden),
                "engine.rs should not call low-level runtime object helper `{forbidden}` directly"
            );
        }
    }

    #[test]
    fn committed_uo_cell_state_is_cold_between_calls() {
        let artifact = compile_bench(
            bench_raw!("FixedSlotClassifier.sol"),
            include_str!(bench_raw!("FixedSlotClassifier.uo.yaml")),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 7).unwrap();
        instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap();

        instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoCell(_)))
            .expect("expected one UO cell object");
        assert_objects_are_cold(&instance);

        let peek = instance.call("peek()", vec![]).unwrap();
        assert_eq!(peek.return_value, Some(Value::uint(1)));
    }

    #[test]
    fn call_rejects_hot_committed_state_before_execution() {
        let artifact = compile_bench(
            bench_raw!("FixedSlotClassifier.sol"),
            include_str!(bench_raw!("FixedSlotClassifier.uo.yaml")),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 11).unwrap();
        instance
            .call("classify(uint256)", vec![Value::uint(1)])
            .unwrap();

        let (cell_id, mut hot_cell) = {
            let (cell_id, _) = instance
                .state
                .object_entries_for_test()
                .find(|(_, object)| matches!(object, RuntimeObject::UoCell(_)))
                .expect("expected one UO cell object");
            let hot_cell = instance
                .state
                .shadow_remove_object_for_test(cell_id)
                .unwrap();
            (cell_id, hot_cell)
        };
        hot_cell.force_committed_cache_hot_for_test().unwrap();
        instance.state.insert_object_for_test(cell_id, hot_cell);

        let err = instance.call("peek()", vec![]).unwrap_err();
        assert!(
            err.to_string().contains(&format!(
                "object {} was not cold before executing the next call from committed storage",
                cell_id
            )),
            "unexpected error: {err:?}"
        );
    }

    #[test]
    fn committed_path_oram_state_is_cold_between_calls() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 9).unwrap();
        instance
            .call("put(bytes32,uint256)", vec![b32(7), Value::uint(9)])
            .unwrap();

        let committed_map = instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(1));

        let read = instance.call("read(bytes32)", vec![b32(7)]).unwrap();
        assert_eq!(read.return_value, Some(Value::uint(9)));
    }

    /// SingleAccessMap's sidecar with its map on another backend and
    /// capacity.
    fn single_access_map_metadata(capacity: usize, backend: &str, scheme: Option<&str>) -> String {
        let base = include_str!(bench_raw!("SingleAccessMap.pathoram.yaml"));
        let scheme_line = scheme
            .map(|scheme| format!("    oram_scheme: {scheme}\n"))
            .unwrap_or_default();
        let metadata = base
            .replace("    capacity: 16\n", &format!("    capacity: {capacity}\n"))
            .replace("    backend: oram\n", &format!("    backend: {backend}\n"))
            .replace("    oram_scheme: path_oram_local_posmap_v1\n", &scheme_line);
        assert_ne!(metadata, base, "the sidecar's map lines changed");
        metadata
    }

    #[test]
    fn a_bulk_load_stores_what_calls_would() {
        const CAPACITY: u8 = 24;
        let read = |instance: &mut ContractInstance, key: u8| {
            instance
                .call("read(bytes32)", vec![b32(key)])
                .unwrap()
                .return_value
        };
        let read_all = |instance: &mut ContractInstance| -> Vec<Option<Value>> {
            (1..=CAPACITY + 3).map(|key| read(instance, key)).collect()
        };
        for (backend, scheme) in [
            ("full_scan", None),
            ("oram", Some("path_oram_local_posmap_v1")),
            ("oram", Some("path_oram_private_posmap_v1")),
        ] {
            let metadata = single_access_map_metadata(usize::from(CAPACITY), backend, scheme);
            let artifact = compile_bench(
                bench_raw!("SingleAccessMap.sol"),
                &metadata,
                ProgramMode::Uo,
            );
            let entries: Vec<(Value, Value)> = (1..=20u8)
                .map(|key| (b32(key), Value::uint(100 + u64::from(key))))
                .collect();

            // A load onto a map that already holds one of the keys, against
            // the same writes made by calls.
            let mut loaded = ContractInstance::deploy_with_seed(artifact.clone(), 11).unwrap();
            let mut called = ContractInstance::deploy_with_seed(artifact, 11).unwrap();
            for instance in [&mut loaded, &mut called] {
                instance
                    .call("put(bytes32,uint256)", vec![b32(1), Value::uint(5)])
                    .unwrap();
            }
            loaded
                .bulk_load_map_for_diagnostics("records", entries.clone())
                .unwrap();
            assert_objects_are_cold(&loaded);
            for (key, value) in entries {
                let put = called
                    .call("put(bytes32,uint256)", vec![key, value])
                    .unwrap();
                assert!(!put.aborted);
            }
            assert_eq!(
                read_all(&mut loaded),
                read_all(&mut called),
                "{backend} {scheme:?}"
            );
            assert_eq!(read(&mut loaded, 1), Some(Value::uint(101)));
            assert_eq!(read(&mut loaded, 21), Some(Value::uint(0)));

            // The loaded map takes calls: four more keys fill it, and the
            // next new key overflows it.
            for key in 21..=CAPACITY {
                let put = loaded
                    .call("put(bytes32,uint256)", vec![b32(key), Value::uint(7)])
                    .unwrap();
                assert!(!put.aborted, "{backend} {scheme:?} key {key}");
            }
            let overflow = loaded
                .call(
                    "put(bytes32,uint256)",
                    vec![b32(CAPACITY + 1), Value::uint(7)],
                )
                .unwrap();
            assert!(overflow.aborted, "{backend} {scheme:?}");

            // A load that overflows the map fails and stores nothing.
            let before = read_all(&mut loaded);
            let error = loaded
                .bulk_load_map_for_diagnostics("records", vec![(b32(CAPACITY + 2), Value::uint(1))])
                .unwrap_err();
            assert!(!format!("{error:#}").is_empty());
            assert_objects_are_cold(&loaded);
            assert_eq!(read_all(&mut loaded), before, "{backend} {scheme:?}");

            // A zero value deletes its key, which makes room for another.
            loaded
                .bulk_load_map_for_diagnostics(
                    "records",
                    vec![
                        (b32(3), Value::uint(0)),
                        (b32(CAPACITY + 2), Value::uint(9)),
                    ],
                )
                .unwrap();
            assert_eq!(read(&mut loaded, 3), Some(Value::uint(0)));
            assert_eq!(read(&mut loaded, CAPACITY + 2), Some(Value::uint(9)));

            // No object by that name.
            assert!(loaded
                .bulk_load_map_for_diagnostics("absent", Vec::new())
                .is_err());
        }
    }

    /// The position maps a call's witness records before and after, as the
    /// runtime refinement witness of its trace holds them.
    fn witnessed_position_maps(result: &CallResult) -> (serde_json::Value, serde_json::Value) {
        let witness =
            serde_json::to_value(result.trace.runtime_refinement_witness().unwrap()).unwrap();
        (
            witness["oram_position_map_before"].clone(),
            witness["oram_position_map_after"].clone(),
        )
    }

    /// The runtime keeps the position-map witness of its calls: the witness
    /// before a call is the one after the call before it, and a call moves
    /// it by its own leaf transitions. No call but the first decodes a map
    /// for its witness. A test build compares the kept witness with the
    /// decode of the whole store before and after every call, so every call
    /// of this suite checks the two against each other. This test also asks
    /// after each call, for a contract with a map of each Path ORAM scheme:
    /// calls that touch one map, the other, and both, an abort, reads that
    /// hit and miss, a call that is refused, and a bulk load.
    #[test]
    fn the_kept_position_map_witness_equals_the_decoded_store_after_every_call() {
        let artifact = compile_bench(
            bench_raw!("ERC20Lite.sol"),
            include_str!(bench_raw!("ERC20Lite.private-posmap.yaml")),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 0x36).unwrap();
        // Nothing is kept until a call needs a witness.
        assert!(!instance.audit_kept_position_map_witness().unwrap());

        let owner = Value::Address([0xA1; 20]);
        let spender = Value::Address([0xB2; 20]);
        let to = Value::Address([0xC3; 20]);
        let stranger = Value::Address([0xEE; 20]);
        let calls: Vec<(&str, Vec<Value>, bool)> = vec![
            // The tree alone: an insert.
            (
                "mint(address,uint256)",
                vec![owner.clone(), Value::uint(10)],
                false,
            ),
            // The local scheme's map alone.
            (
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(5)],
                false,
            ),
            // The tree: an update and an insert.
            (
                "transfer(address,address,uint256)",
                vec![owner.clone(), to.clone(), Value::uint(3)],
                false,
            ),
            // A call that aborts makes its accesses all the same.
            (
                "transfer(address,address,uint256)",
                vec![owner.clone(), to.clone(), Value::uint(100)],
                true,
            ),
            // Both maps.
            (
                "transferFrom(address,address,address,uint256)",
                vec![owner.clone(), spender.clone(), to.clone(), Value::uint(2)],
                false,
            ),
            // Reads that hit, and one that misses.
            ("balanceOf(address)", vec![owner.clone()], false),
            (
                "allowanceOf(address,address)",
                vec![owner.clone(), spender.clone()],
                false,
            ),
            ("balanceOf(address)", vec![stranger], false),
            // A write of the value a key has, and a write of zero.
            (
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(3)],
                false,
            ),
            (
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(0)],
                false,
            ),
        ];
        let mut last_after: Option<serde_json::Value> = None;
        for (index, (entrypoint, args, aborts)) in calls.into_iter().enumerate() {
            let result = instance.call(entrypoint, args).unwrap();
            assert_eq!(result.aborted, aborts, "call {index}, {entrypoint}");
            assert!(
                instance.audit_kept_position_map_witness().unwrap(),
                "call {index}, {entrypoint}"
            );
            let (before, after) = witnessed_position_maps(&result);
            // Both maps are witnessed, whichever the call touched.
            assert_eq!(before.as_array().unwrap().len(), 2);
            if let Some(last_after) = &last_after {
                assert_eq!(&before, last_after, "call {index}, {entrypoint}");
            }
            last_after = Some(after);
        }

        // A call that is refused before it runs leaves the kept witness as
        // it was.
        assert!(instance
            .call("mint(address,uint256)", vec![owner.clone()])
            .is_err());
        assert!(instance.audit_kept_position_map_witness().unwrap());
        let read = instance
            .call("balanceOf(address)", vec![owner.clone()])
            .unwrap();
        assert_eq!(read.return_value, Some(Value::uint(5)));
        assert_eq!(
            Some(witnessed_position_maps(&read).0),
            last_after,
            "the refused call moved the witness"
        );

        // A bulk load is not a call: no transition moves the witness, so
        // none is kept after it, and the next call decodes one again.
        let loaded = Value::Address([0xD4; 20]);
        instance
            .bulk_load_map_for_diagnostics("balances", vec![(loaded.clone(), Value::uint(9))])
            .unwrap();
        assert!(!instance.audit_kept_position_map_witness().unwrap());
        let read = instance.call("balanceOf(address)", vec![loaded]).unwrap();
        assert_eq!(read.return_value, Some(Value::uint(9)));
        assert!(instance.audit_kept_position_map_witness().unwrap());

        // A measurement decodes the witness itself after a load.
        instance
            .bulk_load_map_for_diagnostics(
                "balances",
                vec![(Value::Address([0xD5; 20]), Value::uint(4))],
            )
            .unwrap();
        instance.keep_decoded_position_map_witness().unwrap();
        assert!(instance.audit_kept_position_map_witness().unwrap());
        instance.call("balanceOf(address)", vec![owner]).unwrap();
        assert!(instance.audit_kept_position_map_witness().unwrap());
    }

    /// A kept witness that is not the one of the store fails the next call,
    /// which changes nothing.
    #[test]
    fn a_kept_position_map_witness_that_differs_from_the_store_fails_the_call() {
        let artifact = compile_bench(
            bench_raw!("ERC20Lite.sol"),
            include_str!(bench_raw!("ERC20Lite.private-posmap.yaml")),
            ProgramMode::Uo,
        );
        let mint = |instance: &mut ContractInstance, owner: u8| {
            instance.call(
                "mint(address,uint256)",
                vec![Value::Address([owner; 20]), Value::uint(7)],
            )
        };
        // Two deployments place their nodes under different leaves.
        let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), 1).unwrap();
        let mut other = ContractInstance::deploy_with_seed(artifact, 2).unwrap();
        mint(&mut instance, 0x11).unwrap();
        mint(&mut other, 0x11).unwrap();
        assert!(instance.audit_kept_position_map_witness().unwrap());
        let digest = instance.state.ciphertext_store_digest().unwrap();
        let freshness = instance.freshness.snapshot();

        instance.state.replace_kept_witness_for_test(&other.state);
        let err = instance.audit_kept_position_map_witness().unwrap_err();
        assert!(
            format!("{err:#}").contains("kept position-map witness differs from the decoded store"),
            "{err:#}"
        );
        let err = mint(&mut instance, 0x22).unwrap_err();
        assert!(
            format!("{err:#}")
                .contains("kept position-map witness differs from the decoded store before a call"),
            "{err:#}"
        );
        // The call was staged and dropped: the store and the freshness
        // counters are those of before it.
        assert_eq!(instance.state.ciphertext_store_digest().unwrap(), digest);
        assert_eq!(instance.freshness.snapshot(), freshness);

        // With its own witness decoded again the runtime takes calls.
        instance.keep_decoded_position_map_witness().unwrap();
        mint(&mut instance, 0x22).unwrap();
        assert!(instance.audit_kept_position_map_witness().unwrap());
    }

    /// A call that records no witness of its hidden ORAM state, as every
    /// call of a production build, is the same call: from the same seed it
    /// returns the same values, issues the same receipt and leaves the same
    /// ciphertext in storage as the call that records one, and the checks
    /// that need no position map accept it. Its evidence holds no position
    /// map and no access counter, so no proof object can be built from it.
    #[test]
    fn a_call_without_a_witness_is_the_same_call() {
        let artifact = compile_bench(
            bench_raw!("ERC20Lite.sol"),
            include_str!(bench_raw!("ERC20Lite.private-posmap.yaml")),
            ProgramMode::Uo,
        );
        let mut witnessed = ContractInstance::deploy_with_seed(artifact.clone(), 0x36).unwrap();
        let mut unwitnessed = ContractInstance::deploy_with_seed(artifact, 0x36).unwrap();
        unwitnessed.state.run_unwitnessed_for_test();

        let owner = Value::Address([0xA1; 20]);
        let spender = Value::Address([0xB2; 20]);
        let to = Value::Address([0xC3; 20]);
        let calls: Vec<(&str, Vec<Value>)> = vec![
            (
                "mint(address,uint256)",
                vec![owner.clone(), Value::uint(10)],
            ),
            (
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(5)],
            ),
            (
                "transfer(address,address,uint256)",
                vec![owner.clone(), to.clone(), Value::uint(3)],
            ),
            // This one aborts.
            (
                "transfer(address,address,uint256)",
                vec![owner.clone(), to.clone(), Value::uint(100)],
            ),
            (
                "transferFrom(address,address,address,uint256)",
                vec![owner.clone(), spender.clone(), to.clone(), Value::uint(2)],
            ),
            ("balanceOf(address)", vec![owner.clone()]),
            (
                "allowanceOf(address,address)",
                vec![owner.clone(), spender.clone()],
            ),
            ("balanceOf(address)", vec![Value::Address([0xEE; 20])]),
        ];
        let mut aborted = 0;
        for (index, (entrypoint, args)) in calls.into_iter().enumerate() {
            let with = witnessed.call(entrypoint, args.clone()).unwrap();
            let without = unwitnessed.call(entrypoint, args).unwrap();
            let context = format!("call {index}, {entrypoint}");
            assert_eq!(without.aborted, with.aborted, "{context}");
            assert_eq!(without.return_value, with.return_value, "{context}");
            assert_eq!(without.trace.receipt, with.trace.receipt, "{context}");
            assert_eq!(
                unwitnessed.state.ciphertext_store_digest().unwrap(),
                witnessed.state.ciphertext_store_digest().unwrap(),
                "{context}"
            );
            aborted += usize::from(with.aborted);

            // The evidence both calls hold is the same.
            assert_eq!(
                without.trace.exact_runtime_kernel_witness().unwrap(),
                with.trace.exact_runtime_kernel_witness().unwrap(),
                "{context}"
            );
            assert_eq!(
                without
                    .trace
                    .runtime_controller_observer_certificate()
                    .unwrap(),
                with.trace
                    .runtime_controller_observer_certificate()
                    .unwrap(),
                "{context}"
            );

            // The hidden ORAM state is in the evidence of one alone.
            let (before, after) = witnessed_position_maps(&with);
            assert_eq!(before.as_array().unwrap().len(), 2, "{context}");
            assert_eq!(after.as_array().unwrap().len(), 2, "{context}");
            assert!(!with
                .trace
                .runtime_public_oram_access_counters_before()
                .is_empty());
            assert!(without
                .trace
                .runtime_public_oram_access_counters_before()
                .is_empty());
            assert!(with.trace.runtime_trusted_kernel_bundle().is_ok());
            assert!(without
                .trace
                .runtime_path_oram_hidden_certificate()
                .is_err());
            assert!(without.trace.runtime_trusted_kernel_bundle().is_err());
            assert!(without.trace.runtime_refinement_witness().is_err());

            // Nothing is kept for the runtime that records nothing.
            assert!(witnessed.audit_kept_position_map_witness().unwrap());
            assert!(!unwitnessed.audit_kept_position_map_witness().unwrap());
        }
        assert_eq!(aborted, 1);
    }

    /// Where each sealed record of each object of a runtime is in memory.
    fn sealed_record_addresses(runtime: &ContractRuntime) -> BTreeMap<u32, Vec<*const u8>> {
        runtime
            .object_entries_for_test()
            .filter_map(|(object_id, object)| {
                let (_, records) = object.sealed_storage_for_test()?;
                Some((
                    object_id,
                    records.into_iter().map(<[u8]>::as_ptr).collect::<Vec<_>>(),
                ))
            })
            .collect()
    }

    /// Staging a call copies no object: the staged runtime holds the
    /// committed objects themselves. A call replaces the objects it loaded
    /// and no other, so an object a call did not load stays where it was in
    /// memory through any number of calls, whether they commit, abort or
    /// fail.
    #[test]
    fn staging_a_call_copies_no_object_and_a_call_replaces_only_its_own() {
        let artifact = compile_bench(
            bench_raw!("ERC20Lite.sol"),
            include_str!(bench_raw!("ERC20Lite.private-posmap.yaml")),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 0x37).unwrap();
        let ids: Vec<u32> = instance
            .state
            .object_entries_for_test()
            .map(|(object_id, _)| object_id)
            .collect();
        let object_id = |name: &str| {
            instance
                .state
                .object_entries_for_test()
                .find(|(_, object)| object.name() == name)
                .map(|(object_id, _)| object_id)
                .unwrap()
        };
        let (balances, allowances) = (object_id("balances"), object_id("allowances"));
        assert_eq!(ids.len(), 2);

        // The staged runtime's records are the committed runtime's.
        let committed = sealed_record_addresses(&instance.state);
        assert!(committed.values().all(|records| !records.is_empty()));
        let staged = crate::runtime::stage_contract_runtime(&instance.state).unwrap();
        assert_eq!(sealed_record_addresses(&staged), committed);
        drop(staged);
        assert_eq!(sealed_record_addresses(&instance.state), committed);

        let owner = Value::Address([0xA1; 20]);
        let spender = Value::Address([0xB2; 20]);
        let to = Value::Address([0xC3; 20]);
        // (entrypoint, arguments, aborts, the objects it loads)
        let calls: Vec<(&str, Vec<Value>, bool, Vec<u32>)> = vec![
            (
                "mint(address,uint256)",
                vec![owner.clone(), Value::uint(10)],
                false,
                vec![balances],
            ),
            (
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(5)],
                false,
                vec![allowances],
            ),
            // More than the owner has: the call aborts.
            (
                "transfer(address,address,uint256)",
                vec![owner.clone(), to.clone(), Value::uint(100)],
                true,
                vec![balances],
            ),
            (
                "balanceOf(address)",
                vec![owner.clone()],
                false,
                vec![balances],
            ),
            (
                "allowanceOf(address,address)",
                vec![owner.clone(), spender.clone()],
                false,
                vec![allowances],
            ),
            (
                "transferFrom(address,address,address,uint256)",
                vec![owner.clone(), spender.clone(), to.clone(), Value::uint(2)],
                false,
                vec![balances, allowances],
            ),
        ];
        for (index, (entrypoint, args, aborts, loaded)) in calls.into_iter().enumerate() {
            let before = sealed_record_addresses(&instance.state);
            let result = instance.call(entrypoint, args).unwrap();
            assert_eq!(result.aborted, aborts, "call {index}, {entrypoint}");
            let after = sealed_record_addresses(&instance.state);
            for id in &ids {
                assert_eq!(
                    after[id] != before[id],
                    loaded.contains(id),
                    "call {index}, {entrypoint}, object {id}"
                );
                // Of a map it loaded, a call replaces the records it wrote:
                // the paths it read and the metadata pages. The others are
                // the committed map's own records still.
                if loaded.contains(id) {
                    let replaced = after[id]
                        .iter()
                        .zip(&before[id])
                        .filter(|(after, before)| after != before)
                        .count();
                    assert!(
                        0 < replaced && replaced < after[id].len(),
                        "call {index}, {entrypoint}, object {id}: {replaced} of {}",
                        after[id].len()
                    );
                }
            }
        }

        // A call that fails replaces nothing.
        let before = sealed_record_addresses(&instance.state);
        assert!(instance
            .call("mint(address,uint256)", vec![owner.clone()])
            .is_err());
        assert_eq!(sealed_record_addresses(&instance.state), before);
    }

    /// An object keeps the digest of its sealed records, so a digest of the
    /// ciphertext reads the records of the objects written since the last
    /// one and of no other. The digest is what reading every record again
    /// gives.
    #[test]
    fn a_ciphertext_digest_reads_only_the_objects_written_since_the_last() {
        let artifact = compile_bench(
            bench_raw!("ERC20Lite.sol"),
            include_str!(bench_raw!("ERC20Lite.private-posmap.yaml")),
            ProgramMode::Uo,
        );
        let mut instance = ContractInstance::deploy_with_seed(artifact, 0x37).unwrap();
        // The digest, and how many objects it read the records of.
        let digest = |instance: &ContractInstance| {
            let before = crate::instrumentation::sealed_records_digests_computed();
            let digest = instance.state.ciphertext_store_digest().unwrap();
            let read = crate::instrumentation::sealed_records_digests_computed() - before;
            assert_eq!(
                digest,
                instance
                    .state
                    .ciphertext_store_digest_from_records()
                    .unwrap()
            );
            (digest, read)
        };
        let (deployed, read) = digest(&instance);
        assert_eq!(read, 2);
        assert_eq!(digest(&instance), (deployed.clone(), 0));
        // A staged runtime has the committed objects, digests included.
        let staged = crate::runtime::stage_contract_runtime(&instance.state).unwrap();
        let before = crate::instrumentation::sealed_records_digests_computed();
        assert_eq!(staged.ciphertext_store_digest().unwrap(), deployed);
        assert_eq!(
            crate::instrumentation::sealed_records_digests_computed(),
            before
        );
        drop(staged);

        let owner = Value::Address([0xA1; 20]);
        let spender = Value::Address([0xB2; 20]);
        let to = Value::Address([0xC3; 20]);
        // (entrypoint, arguments, the objects it loads)
        let calls: Vec<(&str, Vec<Value>, u64)> = vec![
            (
                "mint(address,uint256)",
                vec![owner.clone(), Value::uint(10)],
                1,
            ),
            (
                "approve(address,address,uint256)",
                vec![owner.clone(), spender.clone(), Value::uint(5)],
                1,
            ),
            // This one aborts, and writes what a committed one does.
            (
                "transfer(address,address,uint256)",
                vec![owner.clone(), to.clone(), Value::uint(100)],
                1,
            ),
            // A read of a Path ORAM map writes the path it read.
            ("balanceOf(address)", vec![owner.clone()], 1),
            (
                "transferFrom(address,address,address,uint256)",
                vec![owner.clone(), spender.clone(), to.clone(), Value::uint(2)],
                2,
            ),
        ];
        let mut last = deployed;
        for (index, (entrypoint, args, loaded)) in calls.into_iter().enumerate() {
            instance.call(entrypoint, args).unwrap();
            let (next, read) = digest(&instance);
            assert_eq!(read, loaded, "call {index}, {entrypoint}");
            assert_ne!(next, last, "call {index}, {entrypoint}");
            assert_eq!(digest(&instance), (next.clone(), 0));
            last = next;
        }

        // A call that fails writes nothing, and nothing is read again.
        assert!(instance.call("mint(address,uint256)", vec![owner]).is_err());
        assert_eq!(digest(&instance), (last, 0));
    }

    #[test]
    fn an_abort_on_a_large_full_scan_map_stays_within_the_allocator_budget() {
        // An aborting call once opened every slot of an exact map a second
        // time, to restore it, and the allocator's event budget did not count
        // that: the call failed, instead of aborting, on maps above about
        // 4,600 entries. It now restores the map from the copy it loaded and
        // opens each slot once, as a committed call does.
        let base = include_str!(bench_raw!("SweepMap.pathoram.yaml"));
        let metadata = base
            .replace("    capacity: 16\n", "    capacity: 5000\n")
            .replace("    backend: oram\n", "    backend: full_scan\n")
            .replace("    oram_scheme: path_oram_local_posmap_v1\n", "");
        assert_ne!(metadata, base, "the sidecar's map lines changed");
        let artifact = compile_bench(bench_raw!("SweepMap.sol"), &metadata, ProgramMode::Uo);
        let mut instance = ContractInstance::deploy_with_seed(artifact, 3).unwrap();
        instance
            .call("put(bytes32,uint256)", vec![b32(1), Value::uint(9)])
            .unwrap();
        let guarded = instance
            .call(
                "putBelow(bytes32,uint256,uint256)",
                vec![b32(1), Value::uint(5), Value::uint(0)],
            )
            .unwrap();
        assert!(guarded.aborted);
        let read = instance.call("read(bytes32)", vec![b32(1)]).unwrap();
        assert_eq!(read.return_value, Some(Value::uint(9)));
        assert_objects_are_cold(&instance);
    }

    #[test]
    fn a_full_scan_read_writes_nothing_and_an_aborted_write_still_rewrites() {
        let base = include_str!(bench_raw!("SweepMap.pathoram.yaml"));
        let metadata = base
            .replace("    capacity: 16\n", "    capacity: 8\n")
            .replace("    backend: oram\n", "    backend: full_scan\n")
            .replace("    oram_scheme: path_oram_local_posmap_v1\n", "");
        assert_ne!(metadata, base, "the sidecar's map lines changed");
        let artifact = compile_bench(bench_raw!("SweepMap.sol"), &metadata, ProgramMode::Uo);
        let entry = |signature: &str| &artifact.contract.manifest.entrypoints[signature];
        let records = artifact.contract.state[0].id;
        // The manifest lists the map for the writers and not for the reader,
        // and counts its slots as commit operations only for the writers.
        assert!(entry("read(bytes32)").may_write_objects.is_empty());
        assert_eq!(entry("read(bytes32)").max_commit_ops, 0);
        assert_eq!(entry("read(bytes32)").max_load_ops, 8);
        for writer in [
            "put(bytes32,uint256)",
            "clear(bytes32)",
            "putBelow(bytes32,uint256,uint256)",
        ] {
            assert_eq!(entry(writer).may_write_objects, vec![records], "{writer}");
            assert_eq!(entry(writer).max_commit_ops, 8, "{writer}");
            assert_eq!(entry(writer).max_load_ops, 8, "{writer}");
        }

        let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), 5).unwrap();
        let counts = |result: &CallResult| {
            let receipt = result.receipt();
            (receipt.physical_reads.len(), receipt.physical_writes.len())
        };
        let put = instance
            .call("put(bytes32,uint256)", vec![b32(1), Value::uint(9)])
            .unwrap();
        assert_eq!(counts(&put), (8, 8));
        // A read scans the map and rewrites no slot, whether or not it finds
        // its key.
        for key in [1u8, 2] {
            let read = instance.call("read(bytes32)", vec![b32(key)]).unwrap();
            assert_eq!(counts(&read), (8, 0), "key {key}");
        }
        // A write whose guard fails aborts and still rewrites every slot,
        // with what the map held.
        let guarded = instance
            .call(
                "putBelow(bytes32,uint256,uint256)",
                vec![b32(1), Value::uint(5), Value::uint(0)],
            )
            .unwrap();
        assert!(guarded.aborted);
        assert_eq!(counts(&guarded), (8, 8));
        assert!(guarded
            .receipt()
            .physical_writes
            .iter()
            .all(|write| write.class == uo_core::WriteClass::Update));
        let read = instance.call("read(bytes32)", vec![b32(1)]).unwrap();
        assert_eq!(read.return_value, Some(Value::uint(9)));
        assert_objects_are_cold(&instance);

        // What commit reseals comes from the program. A manifest that lists
        // other objects than its slot program writes is refused before the
        // call runs.
        let mut drifted = artifact;
        drifted
            .contract
            .manifest
            .entrypoints
            .get_mut("put(bytes32,uint256)")
            .unwrap()
            .may_write_objects
            .clear();
        let mut instance = ContractInstance::deploy_with_seed(drifted, 5).unwrap();
        let error = instance
            .call("put(bytes32,uint256)", vec![b32(1), Value::uint(9)])
            .unwrap_err();
        assert!(
            format!("{error:#}").contains("are not the objects its slot program writes"),
            "{error:#}"
        );
    }

    #[test]
    fn a_call_reads_each_exact_object_once_when_it_loads_it() {
        let artifact = compile_bench(
            bench_raw!("ERC20Lite.sol"),
            include_str!(bench_raw!("ERC20Lite.uo.yaml")),
            ProgramMode::Uo,
        );
        let entry = |signature: &str| &artifact.contract.manifest.entrypoints[signature];
        let slots = |name: &str| {
            artifact
                .contract
                .state
                .iter()
                .find(|object| object.name == name)
                .and_then(|object| object.capacity)
                .unwrap()
        };
        let (balances, allowances) = (slots("balances"), slots("allowances"));
        // The load bound counts each object a body accesses once, however
        // many statements access it.
        assert_eq!(
            entry("transfer(address,address,uint256)").max_load_ops,
            balances
        );
        assert_eq!(
            entry("transferFrom(address,address,address,uint256)").max_load_ops,
            balances + allowances
        );

        let addr = |byte: u8| Value::Address([byte; 20]);
        let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), 7).unwrap();
        let reads_of = |result: &CallResult, object: &str| {
            result
                .receipt()
                .physical_reads
                .iter()
                .filter(|read| read.object == object)
                .count()
        };
        let read_objects = |result: &CallResult| {
            let mut objects: Vec<String> = Vec::new();
            for read in result.receipt().physical_reads.iter() {
                if objects.last() != Some(&read.object) {
                    objects.push(read.object.clone());
                }
            }
            objects
        };
        // The traced reads of a call on exact objects are the records it
        // opens. Every opening and every seal of a sealed record reserves
        // I/O scratch once, and the call's kernel witness lists the
        // reservations: they number the traced reads plus the traced writes.
        let opens_what_it_traces = |result: &CallResult| {
            let reservations = result
                .trace
                .exact_runtime_kernel_witness()
                .unwrap()
                .resource_events()
                .iter()
                .filter(|event| {
                    event.kind() == RuntimeKernelResourceEventKindWitness::ReserveScratch
                        && event.region() == Some(RuntimeKernelScratchRegionWitness::IoScratch)
                })
                .count();
            let receipt = result.receipt();
            reservations == receipt.physical_reads.len() + receipt.physical_writes.len()
        };
        let mint = instance
            .call("mint(address,uint256)", vec![addr(0x11), Value::uint(50)])
            .unwrap();
        assert!(opens_what_it_traces(&mint));

        // A transfer accesses `balances` four times: it reads and writes the
        // sender, then the recipient. It reads the map's slots once, when
        // the call loads the map, and every access still scans the opened
        // entries.
        let transfer = instance
            .call(
                "transfer(address,address,uint256)",
                vec![addr(0x11), addr(0x22), Value::uint(20)],
            )
            .unwrap();
        assert!(!transfer.aborted);
        let receipt = transfer.receipt();
        assert_eq!(receipt.physical_reads.len(), balances);
        assert_eq!(receipt.physical_writes.len(), balances);
        assert_eq!(
            receipt
                .physical_reads
                .iter()
                .map(|read| read.location.clone())
                .collect::<Vec<_>>(),
            (0..balances)
                .map(|slot| format!("balances#{slot}"))
                .collect::<Vec<_>>()
        );
        assert_eq!(receipt.logical_accesses.len(), 4 * balances);
        assert_eq!(receipt.logical_writes.len(), 2);
        assert!(opens_what_it_traces(&transfer));

        // A call that touches both maps reads each once, in object-id order.
        instance
            .call(
                "approve(address,address,uint256)",
                vec![addr(0x11), addr(0x33), Value::uint(9)],
            )
            .unwrap();
        let transfer_from = instance
            .call(
                "transferFrom(address,address,address,uint256)",
                vec![addr(0x11), addr(0x33), addr(0x44), Value::uint(4)],
            )
            .unwrap();
        assert!(!transfer_from.aborted);
        assert_eq!(reads_of(&transfer_from, "balances"), balances);
        assert_eq!(reads_of(&transfer_from, "allowances"), allowances);
        assert_eq!(read_objects(&transfer_from), ["balances", "allowances"]);
        assert_eq!(
            transfer_from.receipt().physical_writes.len(),
            balances + allowances
        );
        assert!(opens_what_it_traces(&transfer_from));

        // A transfer that aborts reads what one that commits reads, rewrites
        // the same slots, and leaves the balances as they were.
        let overdrawn = instance
            .call(
                "transfer(address,address,uint256)",
                vec![addr(0x11), addr(0x22), Value::uint(1000)],
            )
            .unwrap();
        assert!(overdrawn.aborted);
        assert_eq!(overdrawn.receipt().physical_reads.len(), balances);
        assert_eq!(overdrawn.receipt().physical_writes.len(), balances);
        assert!(opens_what_it_traces(&overdrawn));
        for (owner, balance) in [(0x11u8, 26u64), (0x22, 20), (0x44, 4)] {
            let query = instance
                .call("balanceOf(address)", vec![addr(owner)])
                .unwrap();
            assert_eq!(query.return_value, Some(Value::uint(balance)), "{owner:#x}");
            assert_eq!(query.receipt().physical_reads.len(), balances);
            assert!(query.receipt().physical_writes.is_empty());
            assert!(opens_what_it_traces(&query));
        }
        assert_objects_are_cold(&instance);
    }

    #[test]
    fn a_public_call_loads_only_the_objects_its_body_accesses() {
        let artifact = compile_bench(
            bench_raw!("AuthScan.sol"),
            include_str!(bench_raw!("AuthScan.uo.yaml")),
            ProgramMode::Uo,
        );
        let seed = "seed(uint256,bytes32)";
        let tokens = artifact
            .contract
            .state
            .iter()
            .find(|object| object.name == "TOKENS")
            .unwrap();
        let (tokens_id, tokens_slots) = (tokens.id, tokens.capacity.unwrap());
        let entry = &artifact.contract.manifest.entrypoints[seed];
        assert!(entry.confidential_program.is_none());
        assert_eq!(entry.may_write_objects, vec![tokens_id]);
        assert_eq!(entry.max_load_ops, tokens_slots);

        // `seed` is public and writes the sealed array at a public index. It
        // loads the array, not the cell `lastAuth` that its body never names:
        // its reads are the array's slots, within the manifest's load bound.
        let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), 11).unwrap();
        let seeded = instance.call(seed, vec![Value::uint(1), b32(7)]).unwrap();
        let receipt = seeded.receipt();
        assert_eq!(receipt.physical_reads.len(), tokens_slots);
        assert!(receipt
            .physical_reads
            .iter()
            .all(|read| read.object == "TOKENS"));
        assert_eq!(receipt.physical_writes.len(), tokens_slots);
        // It opens the array's slots and seals them, and nothing else.
        let io_reservations = seeded
            .trace
            .exact_runtime_kernel_witness()
            .unwrap()
            .resource_events()
            .iter()
            .filter(|event| {
                event.kind() == RuntimeKernelResourceEventKindWitness::ReserveScratch
                    && event.region() == Some(RuntimeKernelScratchRegionWitness::IoScratch)
            })
            .count();
        assert_eq!(io_reservations, 2 * tokens_slots);
        assert_objects_are_cold(&instance);
        // The confidential entrypoints see the write.
        let auth = instance.call("auth(bytes32)", vec![b32(7)]).unwrap();
        assert_eq!(auth.return_value, Some(Value::uint(1)));
        let last = instance.call("readLast()", vec![]).unwrap();
        assert_eq!(last.return_value, Some(Value::uint(1)));
        assert_eq!(last.receipt().physical_reads.len(), 1);
        assert!(last.receipt().physical_writes.is_empty());

        // What a public call reseals comes from its body. A manifest that
        // lists other objects is refused before the call runs.
        let mut drifted = artifact;
        drifted
            .contract
            .manifest
            .entrypoints
            .get_mut(seed)
            .unwrap()
            .may_write_objects
            .clear();
        let mut instance = ContractInstance::deploy_with_seed(drifted, 11).unwrap();
        let error = instance
            .call(seed, vec![Value::uint(1), b32(7)])
            .unwrap_err();
        assert!(
            format!("{error:#}").contains("are not the objects its body writes"),
            "{error:#}"
        );
    }

    #[test]
    fn deployed_path_oram_state_is_cold_before_first_call() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let instance = ContractInstance::deploy_with_seed(artifact, 13).unwrap();
        let committed_map = instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(0));
    }

    fn trace_digest(result: &CallResult) -> String {
        hex::encode(Sha256::digest(
            serde_json::to_vec(&result.trace).expect("serialize trace"),
        ))
    }

    #[test]
    fn missing_return_channel_rolls_back_and_retry_matches_fresh() {
        let source = write_temp(
            "rollback-missing-return-channel",
            r#"
            contract C {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let metadata = r#"
contract: C
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#;
        let artifact = compile_bench(source.to_str().unwrap(), metadata, ProgramMode::Uo);
        let mut instance = ContractInstance::deploy_with_seed(artifact.clone(), 17).unwrap();
        let before = instance.freshness.snapshot();
        let before_initialized = instance.initialized;

        // A missing return-channel session is discovered during finalization;
        // with staging it must roll back rather than advance freshness.
        let err = instance
            .call("f(uint256)", vec![Value::uint(7)])
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("requires a return channel session"));
        assert_eq!(
            instance.freshness.snapshot(),
            before,
            "rolled-back call must not advance freshness counters"
        );
        assert_eq!(instance.initialized, before_initialized);

        // A successful retry must match a fresh instance's trace exactly, proving
        // the failed attempt left no residue.
        let session = return_channel_session();
        let retried = instance
            .call_with_return_channel("f(uint256)", vec![Value::uint(7)], &session)
            .unwrap();
        let mut fresh = ContractInstance::deploy_with_seed(artifact, 17).unwrap();
        let fresh_result = fresh
            .call_with_return_channel("f(uint256)", vec![Value::uint(7)], &session)
            .unwrap();
        assert_eq!(trace_digest(&retried), trace_digest(&fresh_result));
    }

    #[test]
    fn exceeded_commit_budget_rolls_back_committed_state() {
        let mut artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        // Force the resource budget to fail after the kernel runs on staged state.
        artifact
            .contract
            .manifest
            .entrypoints
            .get_mut("put(bytes32,uint256)")
            .expect("entrypoint")
            .max_commit_ops = 0;
        let mut instance = ContractInstance::deploy_with_seed(artifact, 9).unwrap();
        let before = instance.freshness.snapshot();

        let err = instance
            .call("put(bytes32,uint256)", vec![b32(7), Value::uint(9)])
            .unwrap_err();
        assert!(err.to_string().contains("exceeded manifest commit budget"));
        assert_eq!(
            instance.freshness.snapshot(),
            before,
            "budget failure must not advance freshness"
        );
        // Committed objects are untouched (still cold and at access counter 0).
        let committed_map = instance
            .state
            .object_values_for_test()
            .find(|object| matches!(object, RuntimeObject::UoOramMap(_)))
            .expect("expected one UO ORAM map object");
        assert_objects_are_cold(&instance);
        assert_eq!(committed_map.path_oram_access_counter_for_test(), Some(0));
    }

    #[test]
    fn return_channel_policy_preflight_rejects_invalid_pairs() {
        // Encrypted-return entrypoint: a session is required.
        let enc_source = write_temp(
            "return-channel-encrypted",
            r#"
            contract Enc {
                function f(uint256 secret) public returns (uint256) { return secret; }
            }
            "#,
        );
        let enc_metadata = r#"
contract: Enc
entrypoints:
  f(uint256):
    secret_args: [secret]
    confidential: true
    returns: encrypted_to_client
    status: public
state: {}
bounds:
  loops: {}
"#;
        let enc_artifact =
            compile_bench(enc_source.to_str().unwrap(), enc_metadata, ProgramMode::Uo);
        let mut enc = ContractInstance::deploy_with_seed(enc_artifact, 17).unwrap();
        let before = enc.freshness.snapshot();
        let err = enc.call("f(uint256)", vec![Value::uint(7)]).unwrap_err();
        assert!(err
            .to_string()
            .contains("requires a return channel session"));
        assert_eq!(
            enc.freshness.snapshot(),
            before,
            "preflight reject must not advance freshness"
        );
        // Valid pair: encrypted return with a session.
        let session = return_channel_session();
        enc.call_with_return_channel("f(uint256)", vec![Value::uint(7)], &session)
            .unwrap();

        // Non-encrypted return: a supplied session is rejected before execution.
        let pub_source = write_temp(
            "return-channel-public",
            r#"
            contract Pub {
                uint256 private x;
                function setX(uint256 v) public { x = v; }
                function read() public returns (uint256) { return x; }
            }
            "#,
        );
        let pub_metadata = r#"
contract: Pub
entrypoints:
  setX(uint256):
    confidential: false
    returns: forbidden
    status: public
  read():
    confidential: false
    returns: public
    status: public
state:
  x:
    kind: cell
    value: uint256
    backend: raw
    confidential: false
bounds:
  loops: {}
"#;
        let pub_artifact =
            compile_bench(pub_source.to_str().unwrap(), pub_metadata, ProgramMode::Raw);
        let mut pub_inst = ContractInstance::deploy_with_seed(pub_artifact, 5).unwrap();
        let before_pub = pub_inst.freshness.snapshot();
        let err = pub_inst
            .call_with_return_channel("read()", vec![], &session)
            .unwrap_err();
        assert!(err.to_string().contains("non-encrypted return policy"));
        assert_eq!(
            pub_inst.freshness.snapshot(),
            before_pub,
            "preflight reject must not advance freshness"
        );
        // Valid pair: non-encrypted return without a session.
        let read = pub_inst.call("read()", vec![]).unwrap();
        assert_eq!(read.return_value, Some(Value::uint(0)));
    }

    #[test]
    // Strict default-build property: the insecure-eval-raw evaluation feature
    // deliberately admits raw confidential backends and skips the
    // confidential-object targeting check, so this rejection is not expected there.
    #[cfg(not(feature = "insecure-eval-raw"))]
    fn confidential_kernel_targeting_public_uo_object_is_rejected() {
        let source = write_temp(
            "confidential-target",
            r#"
            contract C {
                uint256 private secret;
                function setSecret(uint256 amount) public { secret = amount; }
            }
            "#,
        );
        let metadata = r#"
contract: C
entrypoints:
  setSecret(uint256):
    confidential: true
    secret_args: [amount]
    returns: forbidden
    status: public
state:
  secret:
    kind: cell
    value: uint256
    backend: full_scan
    confidential: true
bounds:
  loops: {}
"#;
        let mut artifact = compile_bench(source.to_str().unwrap(), metadata, ProgramMode::Uo);
        // The well-formed confidential artifact runs.
        {
            let mut ok = ContractInstance::deploy_with_seed(artifact.clone(), 7).unwrap();
            ok.call("setSecret(uint256)", vec![Value::uint(9)]).unwrap();
        }
        // Tamper: flip the target object to public while keeping the UO backend.
        let secret = artifact
            .contract
            .state
            .iter_mut()
            .find(|object| object.name == "secret")
            .expect("secret object");
        assert!(secret.confidential);
        secret.confidential = false;
        let mut instance = ContractInstance::deploy_with_seed(artifact, 7).unwrap();
        let err = instance
            .call("setSecret(uint256)", vec![Value::uint(9)])
            .unwrap_err();
        assert!(
            err.to_string().contains("targets non-confidential object"),
            "unexpected error: {err}"
        );
    }

    #[cfg(not(feature = "diagnostics"))]
    #[test]
    fn rejected_production_call_leaves_state_freshness_and_receipt_untouched() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let entrypoint = "add(bytes32,uint256)";
        let args = vec![b32(7), Value::uint(5)];
        let policy = production_policy();
        let session = return_channel_session();
        let environment = PublicEnvironment::default();
        // A seeded deployment is replayed by its seed, so every instance
        // deployed from it below issues this deployment receipt.
        let deployed = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap()
        .last_receipt()
        .clone();
        let evidence = production_evidence(&artifact, &policy, &session, &environment, &deployed);

        let mut production =
            ProductionContractInstance::deploy_with_authorized_seed(artifact.clone(), policy, 91)
                .unwrap();
        let before = production.inner.freshness.snapshot();
        let store_before = production.inner.state.ciphertext_store_digest().unwrap();

        // A call that names a receipt the runtime did not issue last.
        let mut wrong_receipt = evidence.clone();
        wrong_receipt.previous_receipt_sha256 = "00".repeat(32);
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong_receipt)
            .unwrap_err();
        assert_eq!(
            err.to_string(),
            "production runtime previous_receipt_sha256 mismatch"
        );
        assert_eq!(
            production.inner.freshness.snapshot(),
            before,
            "a rejected production call must not advance freshness"
        );
        assert_eq!(production.last_receipt(), &deployed);
        assert_eq!(
            production.inner.state.ciphertext_store_digest().unwrap(),
            store_before
        );

        // Because nothing moved, the original evidence still applies and a
        // retry succeeds.
        let accepted = production
            .call_authorized(entrypoint, args, &session, &evidence)
            .unwrap();
        assert!(!accepted.call.aborted);
        accepted.receipt.follows(&deployed).unwrap();
    }

    #[cfg(not(feature = "diagnostics"))]
    #[test]
    fn production_translation_validation_certificate_binds_artifact_contents() {
        let artifact = compile_bench(
            bench_raw!("SingleAccessMap.sol"),
            include_str!(bench_raw!("SingleAccessMap.pathoram.yaml")),
            ProgramMode::Uo,
        );
        let entrypoint = "add(bytes32,uint256)";
        let args = vec![b32(7), Value::uint(5)];
        let policy = production_policy();
        let session = return_channel_session();
        let environment = PublicEnvironment::default();
        // A seeded deployment is replayed by its seed, so every instance
        // deployed from it below issues this deployment receipt.
        let deployed = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap()
        .last_receipt()
        .clone();
        let evidence = production_evidence(&artifact, &policy, &session, &environment, &deployed);

        // Valid certificate: accepted.
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        production
            .call_authorized(entrypoint, args.clone(), &session, &evidence)
            .unwrap();

        // Missing certificate: rejected by the hex validation.
        let mut missing = evidence.clone();
        missing.translation_validation_certificate_sha256.clear();
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &missing)
            .unwrap_err();
        assert!(err.to_string().contains(
            "translation_validation_certificate_sha256 must be a 64-character hex SHA-256 digest"
        ));

        // Wrong certificate: rejected by the equality check.
        let mut wrong = evidence.clone();
        wrong.translation_validation_certificate_sha256 = "00".repeat(32);
        let mut production = ProductionContractInstance::deploy_with_authorized_seed(
            artifact.clone(),
            policy.clone(),
            91,
        )
        .unwrap();
        let err = production
            .call_authorized(entrypoint, args.clone(), &session, &wrong)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("translation_validation_certificate_sha256 mismatch"));

        // Tampering the artifact contents (a state object) after compilation
        // changes the recomputed certificate, so the attested evidence no longer
        // matches and the call is rejected before execution.
        let mut tampered_artifact = artifact.clone();
        tampered_artifact
            .contract
            .state
            .first_mut()
            .expect("state object")
            .confidential ^= true;
        let mut production =
            ProductionContractInstance::deploy_with_authorized_seed(tampered_artifact, policy, 91)
                .unwrap();
        let err = production
            .call_authorized(entrypoint, args, &session, &evidence)
            .unwrap_err();
        assert!(err
            .to_string()
            .contains("translation_validation_certificate_sha256 mismatch"));
    }
}
