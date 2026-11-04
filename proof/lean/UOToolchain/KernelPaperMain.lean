import UOToolchain.KernelFlow

namespace UOToolchain.IR

/-!
# The paper-main theorem for admitted kernel programs

`paperMain_admittedKernel_exact_noninterference_moduloReleases` discharges the
storage-trace premise of the paper-main theorem modulo releases. This module
discharges the others for exact-backend confidential entrypoints, from
properties of the kernel program that a checker can decide:

* the public outcome: models of the outcome, final public state, and enclave
  boundary schedule the runtime reports, whose safety modulo releases follows
  from the information-flow analysis (`KernelFlow`) when the entrypoint's
  declared policies agree with it;
* the final public state: a program that writes only confidential objects
  leaves the public store unchanged;
* the controller shape and release functions, which are fixed per entrypoint.
-/

/-! ## Return presence -/

/-- A statement returns a value. -/
def KernelStatement.isValueReturn : KernelStatement → Bool
  | .retStmt (some _) => true
  | _ => false

/-- The body's last statement returns a value. -/
def KernelStatement.returnsValue : List KernelStatement → Bool
  | [] => false
  | [stmt] => stmt.isValueReturn
  | _ :: next :: rest => KernelStatement.returnsValue (next :: rest)

theorem evalKernelStatement_publicResult_isSome_last {cfg : OperationalConfig}
    {env : LocalEnv} {oc : Outcome} {Γ Γ' : List (String × Ty)} {stmt : KernelStatement}
    (hEnv : EnvConforms Γ env) (hStore : StoreConforms cfg)
    (hTy : stmt.typeCheck Γ cfg.contract.state = some Γ')
    (hPub : oc.publicResult = none) :
    (evalKernelStatement cfg env oc stmt).2.2.publicResult.isSome = stmt.isValueReturn := by
  cases hIsRet : stmt.isReturn
  · rw [evalKernelStatement_publicResult_of_not_return cfg env oc stmt hIsRet, hPub]
    cases stmt <;> simp_all [KernelStatement.isReturn, KernelStatement.isValueReturn]
  · cases stmt <;> simp [KernelStatement.isReturn] at hIsRet
    rename_i value
    cases value with
    | none => simp [evalKernelStatement, hPub, KernelStatement.isValueReturn]
    | some value =>
        simp only [KernelStatement.typeCheck] at hTy
        split at hTy
        · rename_i vty hv
          obtain ⟨v, hEval, _⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
          simp [evalKernelStatement, hEval, KernelStatement.isValueReturn]
        · cases hTy

theorem evalKernelBody_publicResult_isSome :
    ∀ (body : List KernelStatement) {cfg : OperationalConfig} {env : LocalEnv}
      {oc : Outcome} {Γ : List (String × Ty)},
      EnvConforms Γ env → StoreConforms cfg →
      KernelStatement.bodyTyped Γ cfg.contract.state body = true →
      KernelStatement.returnsOnlyLast body = true →
      oc.status.continuesBody true = true → oc.publicResult = none →
      (evalKernelBody cfg env oc body).2.2.publicResult.isSome =
        KernelStatement.returnsValue body
  | [], _, _, _, _, _, _, _, _, _, hPub => by
      simp [evalKernelBody, KernelStatement.returnsValue, hPub]
  | stmt :: rest, cfg, env, oc, Γ, hEnv, hStore, hTy, hRet, hOc, hPub => by
      simp only [KernelStatement.bodyTyped] at hTy
      split at hTy
      · rename_i Γ' hStmt
        obtain ⟨hStatus, hEnv', hStore', hContract⟩ :=
          evalKernelStatement_wellTyped (oc := oc) hEnv hStore hStmt hOc
        cases rest with
        | nil =>
            have hLast := evalKernelStatement_publicResult_isSome_last hEnv hStore hStmt hPub
            rw [evalKernelBody]
            generalize evalKernelStatement cfg env oc stmt = step at *
            obtain ⟨cfg', env', oc'⟩ := step
            simp only at hStatus hLast ⊢
            simp only [hStatus, ↓reduceIte, evalKernelBody, ite_self]
            simpa [KernelStatement.returnsValue] using hLast
        | cons next rest' =>
            have hNotRet : stmt.isReturn = false := by
              simp only [KernelStatement.returnsOnlyLast, Bool.and_eq_true,
                Bool.not_eq_true'] at hRet
              exact hRet.1
            have hRet' : KernelStatement.returnsOnlyLast (next :: rest') = true := by
              simp only [KernelStatement.returnsOnlyLast, Bool.and_eq_true] at hRet
              exact hRet.2
            have hPubStmt :=
              evalKernelStatement_publicResult_of_not_return cfg env oc stmt hNotRet
            rw [evalKernelBody]
            generalize evalKernelStatement cfg env oc stmt = step at *
            obtain ⟨cfg', env', oc'⟩ := step
            simp only at hStatus hEnv' hStore' hContract hPubStmt ⊢
            have hPub' : oc'.publicResult = none := by rw [hPubStmt, hPub]
            simp only [hStatus, hPub', Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
            rw [evalKernelBody_publicResult_isSome (next :: rest') hEnv' hStore'
              (by rw [hContract]; exact hTy) hRet' hStatus hPub']
            rfl
      · cases hTy

/-- A conforming run of an admitted program returns a value exactly when the
program's last statement returns one. -/
theorem evalKernelProgram_publicResult_isSome (kp : KernelProgram) (cfg : OperationalConfig)
    (hTy : kp.wellTyped cfg.contract.state = true)
    (hRet : KernelStatement.returnsOnlyLast kp.body = true)
    (hArgs : ArgsConform kp.params cfg.declaredArgs)
    (hStore : StoreConforms cfg) :
    (evalKernelProgram kp cfg).publicResult.isSome = KernelStatement.returnsValue kp.body := by
  obtain ⟨env, hEnvEq, hEnv⟩ := kp.initialEnv_conforms cfg.declaredArgs hArgs
  have hBody := evalKernelBody_publicResult_isSome kp.body (oc := Outcome.empty)
    hEnv hStore hTy hRet rfl rfl
  unfold evalKernelProgram
  simp only [hEnvEq]
  generalize evalKernelBody cfg env Outcome.empty kp.body = result at *
  obtain ⟨cfg', env', outcome⟩ := result
  simpa [Outcome.withPublicStateTransition] using hBody

/-! ## The public store -/

/-- The object with this id is a confidential object of the layout. -/
def objectConfidentialIn (state : List StateObject) (objectId : Nat) : Bool :=
  match stateObjectOf? state objectId with
  | some object => object.confidential
  | none => false

/-- A statement writes only confidential objects. -/
def KernelStatement.writesConfidential (state : List StateObject) : KernelStatement → Bool
  | .cellSet objectId _ _ => objectConfidentialIn state objectId
  | .arraySet objectId _ _ _ => objectConfidentialIn state objectId
  | .mapPut objectId _ _ _ => objectConfidentialIn state objectId
  | _ => true

/-- The program writes only confidential objects, as the confidential-object
targeting restriction of `uo-solc` requires. -/
def KernelProgram.writesOnlyConfidential (kp : KernelProgram) (state : List StateObject) :
    Bool :=
  kp.body.all (KernelStatement.writesConfidential state)

theorem objectConfidentialIn_inv {state : List StateObject} {objectId : Nat}
    (h : objectConfidentialIn state objectId = true) :
    ∃ object, stateObjectOf? state objectId = some object ∧ object.confidential = true := by
  unfold objectConfidentialIn at h
  split at h
  · rename_i object hObject
    exact ⟨object, hObject, h⟩
  · cases h

theorem ObjectStore.lookup_isSome_of_mem {store : ObjectStore} {entry : Nat × Value}
    (h : entry ∈ store) : (store.lookup entry.fst).isSome = true := by
  unfold ObjectStore.lookup
  have hFind : (store.find? (fun e => decide (e.fst = entry.fst))).isSome = true :=
    List.find?_isSome.mpr ⟨entry, h, by simp⟩
  cases hFound : store.find? (fun e => decide (e.fst = entry.fst)) with
  | none => rw [hFound] at hFind; cases hFind
  | some found => rfl

/-- Writing a confidential object leaves an owned public store unchanged. -/
theorem OperationalConfig.writeObject?_confidential_publicState {cfg cfg' : OperationalConfig}
    {objectId : Nat} {value : Value} {object : StateObject}
    (hOwned : cfg.publicStoreAgreesWithObjectMap)
    (hObject : cfg.stateObjectById? objectId = some object)
    (hConf : object.confidential = true)
    (hWrite : cfg.writeObject? objectId value = some cfg') :
    cfg'.publicState = cfg.publicState := by
  unfold OperationalConfig.writeObject? OperationalConfig.objectConfidential? at hWrite
  rw [hObject] at hWrite
  simp only [hConf, Option.some.injEq] at hWrite
  subst hWrite
  show cfg.publicState.remove objectId = cfg.publicState
  unfold ObjectStore.remove
  apply List.filter_eq_self.mpr
  intro entry hMem
  simp only [ne_eq, decide_eq_true_eq]
  intro hEq
  obtain ⟨v, hv⟩ := Option.isSome_iff_exists.mp (ObjectStore.lookup_isSome_of_mem hMem)
  have hPublic := hOwned entry.fst v hv
  rw [hEq] at hPublic
  simp [OperationalConfig.objectConfidential?, hObject, hConf] at hPublic

theorem OperationalConfig.publicStoreAgreesWithObjectMap_of_eq {cfg cfg' : OperationalConfig}
    (hOwned : cfg.publicStoreAgreesWithObjectMap)
    (hState : cfg'.publicState = cfg.publicState) (hContract : cfg'.contract = cfg.contract) :
    cfg'.publicStoreAgreesWithObjectMap := by
  intro objectId value hLookup
  rw [hState] at hLookup
  have := hOwned objectId value hLookup
  simpa [OperationalConfig.objectConfidential?, OperationalConfig.stateObjectById?,
    hContract] using this

/-- A statement that writes only confidential objects leaves an owned public
store and the contract unchanged. -/
theorem evalKernelStatement_publicState {cfg : OperationalConfig} {env : LocalEnv}
    {oc : Outcome} {stmt : KernelStatement}
    (hOwned : cfg.publicStoreAgreesWithObjectMap)
    (hWrites : stmt.writesConfidential cfg.contract.state = true) :
    (evalKernelStatement cfg env oc stmt).1.publicState = cfg.publicState ∧
      (evalKernelStatement cfg env oc stmt).1.contract = cfg.contract := by
  cases stmt with
  | cellSet objectId value predicate =>
      obtain ⟨object, hObject, hConf⟩ := objectConfidentialIn_inv hWrites
      have hLookup : cfg.stateObjectById? objectId = some object := hObject
      simp only [evalKernelStatement]
      repeat' split
      all_goals first
        | exact ⟨rfl, rfl⟩
        | exact ⟨OperationalConfig.writeObject?_confidential_publicState hOwned hLookup hConf
            (by assumption), OperationalConfig.writeObject?_contract (by assumption)⟩
  | arraySet objectId index value predicate =>
      obtain ⟨object, hObject, hConf⟩ := objectConfidentialIn_inv hWrites
      have hLookup : cfg.stateObjectById? objectId = some object := hObject
      simp only [evalKernelStatement]
      repeat' split
      all_goals first
        | exact ⟨rfl, rfl⟩
        | exact ⟨OperationalConfig.writeObject?_confidential_publicState hOwned hLookup hConf
            (by assumption), OperationalConfig.writeObject?_contract (by assumption)⟩
  | mapPut objectId key value predicate =>
      obtain ⟨object, hObject, hConf⟩ := objectConfidentialIn_inv hWrites
      have hLookup : cfg.stateObjectById? objectId = some object := hObject
      simp only [evalKernelStatement]
      repeat' split
      all_goals first
        | exact ⟨rfl, rfl⟩
        | exact ⟨OperationalConfig.writeObject?_confidential_publicState hOwned hLookup hConf
            (by assumption), OperationalConfig.writeObject?_contract (by assumption)⟩
  | retStmt value =>
      cases value <;> simp only [evalKernelStatement] <;> (repeat' split) <;>
        first | exact ⟨rfl, rfl⟩ | trivial
  | _ => simp only [evalKernelStatement] <;> (repeat' split) <;> first | exact ⟨rfl, rfl⟩ | trivial

theorem evalKernelBody_publicState :
    ∀ (body : List KernelStatement) {cfg : OperationalConfig} {env : LocalEnv}
      {oc : Outcome},
      cfg.publicStoreAgreesWithObjectMap →
      body.all (KernelStatement.writesConfidential cfg.contract.state) = true →
      (evalKernelBody cfg env oc body).1.publicState = cfg.publicState
  | [], _, _, _, _, _ => by simp [evalKernelBody]
  | stmt :: rest, cfg, env, oc, hOwned, hWrites => by
      simp only [List.all_cons, Bool.and_eq_true] at hWrites
      obtain ⟨hState, hContract⟩ :=
        evalKernelStatement_publicState (env := env) (oc := oc) hOwned hWrites.1
      have hOwned' := OperationalConfig.publicStoreAgreesWithObjectMap_of_eq hOwned hState
        hContract
      rw [evalKernelBody]
      generalize evalKernelStatement cfg env oc stmt = step at *
      obtain ⟨cfg', env', oc'⟩ := step
      simp only at hState hContract hOwned' ⊢
      split
      · split
        · exact hState
        · rw [evalKernelBody_publicState rest hOwned' (by rw [hContract]; exact hWrites.2),
            hState]
      · exact hState

/-! ## Admitted runs and the runtime's public observables -/

/-- An admitted run of an exact-backend confidential entrypoint: an admitted
kernel configuration whose argument vector has the declared layout, whose public
store holds only public objects, and whose program writes only confidential
objects. -/
structure AdmittedKernelRun (kp : KernelProgram) extends AdmittedKernelConfig kp where
  layout : KernelArgumentLayout kp cfg
  publicStoreOwned : cfg.publicStoreAgreesWithObjectMap
  writesConfidential : kp.writesOnlyConfidential cfg.contract.state = true

/-- Two admitted runs agree on contract, entrypoint, public arguments, public
environment, and public store. -/
def AdmittedKernelRun.samePublic {kp : KernelProgram} (lhs rhs : AdmittedKernelRun kp) :
    Prop :=
  sameOperationalPublicProjection lhs.cfg rhs.cfg

/-- Manifest facts that fix an entrypoint's public observables. -/
structure EntrypointPublicPolicy where
  entrypointId : String
  statusPolicy : String
  returnPolicy : String
  declassifies : List String
  returnLength : Nat
  entryInputLen : Nat
  gas : Nat

/-- The entrypoint's declared policies agree with the information-flow analysis
of its kernel program, as the compiler's policy validation requires: a status
that is not declassified is public, and a return that is neither declassified
nor encrypted is public. Encrypted returns are outside this model. -/
structure PolicyAgreesWithFlow (kp : KernelProgram) (policy : EntrypointPublicPolicy) :
    Prop where
  statusPublic : policy.statusPolicy ≠ "declassified" → kp.flowSummary.statusSecret = false
  returnPublic : policy.returnPolicy ≠ "declassified" → kp.flowSummary.returnSecret = false
  notEncrypted : policy.returnPolicy ≠ "encrypted_to_client"

/-- The run completed without a recorded abort. -/
def kernelRunCompleted (kp : KernelProgram) (cfg : OperationalConfig) : Bool :=
  (evalKernelProgram kp cfg).status == .completed

/-- The value the runtime returns: an aborted call returns nothing. -/
def kernelRunReturn (kp : KernelProgram) (cfg : OperationalConfig) : Option Value :=
  if kernelRunCompleted kp cfg then (evalKernelProgram kp cfg).publicResult else none

/-- The public outcome the runtime reports for a run. -/
def kernelPublicOutcome (policy : EntrypointPublicPolicy) (render : Value → String)
    (renderEnv : String × Value → String) (kp : KernelProgram) (cfg : OperationalConfig) :
    SGXPublicOutcome :=
  { entrypointId := policy.entrypointId
  , publicArgs := cfg.publicArgs.map render
  , publicEnv := cfg.publicEnv.map renderEnv
  , terminationStatus := kernelRunCompleted kp cfg
  , statusPolicy := policy.statusPolicy
  , outputShape :=
      if (kernelRunReturn kp cfg).isSome then
        { returnPresent := true, returnLength := policy.returnLength }
      else OutputShape.erased
  , returnPolicy := policy.returnPolicy
  , returnPayload := (kernelRunReturn kp cfg).map render
  , encryptedReturnPayload := none
  , declassifies := policy.declassifies
  , gasUsed := policy.gas
  }

/-- The final public-state record the runtime reports for a run. -/
def kernelFinalPublicState (digest : ObjectStore → String)
    (deltaDigest : List Nat → String) (kp : KernelProgram) (cfg : OperationalConfig) :
    PaperMainFinalPublicStateRollback :=
  match (evalKernelProgram kp cfg).publicStateTransition with
  | some transition =>
      { initialPublicStateDigest := digest transition.initialPublicState
      , candidatePublicStateDigest := digest transition.candidatePublicState
      , committedPublicStateDigest := digest transition.committedPublicState
      , publicDeltaDigest := deltaDigest transition.publicDelta
      , aborted := transition.abortStatus }
  | none =>
      { initialPublicStateDigest := ""
      , candidatePublicStateDigest := ""
      , committedPublicStateDigest := ""
      , publicDeltaDigest := ""
      , aborted := false }

/-- The enclave-boundary schedule the runtime controller certificate assigns to
an exact-backend call (`RuntimeControllerCertificate.boundarySchedule` with no
ORAM accesses): enter with the entry input, exit with the output shape's return
length. -/
def kernelBoundarySchedule (policy : EntrypointPublicPolicy) (outcome : SGXPublicOutcome) :
    List BoundaryEvent :=
  [ { direction := .enter, apiId := policy.entrypointId, inputLen := policy.entryInputLen,
      outputLen := 0 }
  , { direction := .exit, apiId := policy.entrypointId, inputLen := 0,
      outputLen := outcome.outputShape.returnLength } ]

/-! ## Safety of the observables -/

/-- Two admitted runs with the same public projection run over the same
contract, agree on public arguments at public positions, and so end with the
same status when it is public and return the same value when it is public. -/
theorem AdmittedKernelRun.flow_ni {kp : KernelProgram} {lhs rhs : AdmittedKernelRun kp}
    (hPublic : lhs.samePublic rhs) :
    (kp.flowSummary.statusSecret = false →
        (evalKernelProgram kp lhs.cfg).status = (evalKernelProgram kp rhs.cfg).status) ∧
      (kp.flowSummary.returnSecret = false →
        (evalKernelProgram kp lhs.cfg).publicResult =
          (evalKernelProgram kp rhs.cfg).publicResult) := by
  have hContract : rhs.cfg.contract = lhs.cfg.contract :=
    (congrArg OperationalPublicProjection.contract hPublic).symm
  have hArgs : lhs.cfg.publicArgs = rhs.cfg.publicArgs :=
    congrArg OperationalPublicProjection.publicArgs hPublic
  exact evalKernelProgram_flow_ni kp lhs.cfg rhs.cfg lhs.wellTyped (by rw [hContract])
    lhs.returnsLast lhs.args rhs.args lhs.store rhs.store
    (publicArgsAgree_of_layout lhs.layout rhs.layout hArgs)

theorem kernelPublicOutcome_statusReleased (policy : EntrypointPublicPolicy)
    (render : Value → String) (renderEnv : String × Value → String) (kp : KernelProgram)
    (cfg : OperationalConfig) :
    (kernelPublicOutcome policy render renderEnv kp cfg).statusReleased =
      (policy.statusPolicy == "declassified") := rfl

/-- The modeled public outcome is public-determined outside its declared
releases. -/
theorem kernelPublicOutcome_safe (kp : KernelProgram) (policy : EntrypointPublicPolicy)
    (render : Value → String) (renderEnv : String × Value → String)
    (hAgree : PolicyAgreesWithFlow kp policy) :
    PublicOutcomeSafeModuloReleases AdmittedKernelRun.samePublic
      (fun a : AdmittedKernelRun kp => kernelPublicOutcome policy render renderEnv kp a.cfg) := by
  intro a₁ a₂ hPublic
  obtain ⟨hStatusNI, hReturnNI⟩ := AdmittedKernelRun.flow_ni hPublic
  have hArgs : a₁.cfg.publicArgs = a₂.cfg.publicArgs :=
    congrArg OperationalPublicProjection.publicArgs hPublic
  have hEnvs : a₁.cfg.publicEnv = a₂.cfg.publicEnv :=
    congrArg OperationalPublicProjection.publicEnv hPublic
  have hSome₁ := evalKernelProgram_publicResult_isSome kp a₁.cfg a₁.wellTyped a₁.returnsLast
    a₁.args a₁.store
  have hSome₂ := evalKernelProgram_publicResult_isSome kp a₂.cfg a₂.wellTyped a₂.returnsLast
    a₂.args a₂.store
  show (kernelPublicOutcome policy render renderEnv kp a₁.cfg).withoutReleases =
    (kernelPublicOutcome policy render renderEnv kp a₂.cfg).withoutReleases
  by_cases hReleased : policy.statusPolicy = "declassified"
  · simp [SGXPublicOutcome.withoutReleases, kernelPublicOutcome, SGXPublicOutcome.statusReleased,
      hReleased, hArgs, hEnvs]
  · have hStatusEq := hStatusNI (hAgree.statusPublic hReleased)
    have hCompleted : kernelRunCompleted kp a₁.cfg = kernelRunCompleted kp a₂.cfg := by
      simp [kernelRunCompleted, hStatusEq]
    have hReturnSome :
        (kernelRunReturn kp a₁.cfg).isSome = (kernelRunReturn kp a₂.cfg).isSome := by
      unfold kernelRunReturn
      rw [hCompleted]
      split
      · rw [hSome₁, hSome₂]
      · rfl
    by_cases hReturnReleased : policy.returnPolicy = "declassified"
    · simp [SGXPublicOutcome.withoutReleases, kernelPublicOutcome,
        SGXPublicOutcome.statusReleased, SGXPublicOutcome.returnReleased,
        SGXPublicOutcome.returnEncrypted, hReleased, hReturnReleased, hArgs, hEnvs,
        hCompleted, hReturnSome]
    · have hReturnEq : kernelRunReturn kp a₁.cfg = kernelRunReturn kp a₂.cfg := by
        unfold kernelRunReturn
        rw [hCompleted, hReturnNI (hAgree.returnPublic hReturnReleased)]
      simp [SGXPublicOutcome.withoutReleases, kernelPublicOutcome,
        SGXPublicOutcome.statusReleased, SGXPublicOutcome.returnReleased,
        SGXPublicOutcome.returnEncrypted, hReleased, hReturnReleased, hArgs, hEnvs,
        hCompleted, hReturnEq]

/-- The modeled boundary schedule is public-determined outside the status
release whenever the outcome is public-determined outside its releases. -/
theorem kernelBoundarySchedule_safe {κ : Type} {samePublic : κ → κ → Prop}
    {outcome : κ → SGXPublicOutcome} (policy : EntrypointPublicPolicy)
    (hOutcome : PublicOutcomeSafeModuloReleases samePublic outcome)
    (hPolicy : ∀ cfg, (outcome cfg).statusPolicy = policy.statusPolicy) :
    BoundarySafeModuloReleases samePublic outcome
      (fun cfg => kernelBoundarySchedule policy (outcome cfg)) := by
  intro c₁ c₂ hPublic
  have hErased := hOutcome c₁ c₂ hPublic
  show boundaryWithoutStatusRelease (outcome c₁).statusReleased
      (kernelBoundarySchedule policy (outcome c₁)) =
    boundaryWithoutStatusRelease (outcome c₂).statusReleased
      (kernelBoundarySchedule policy (outcome c₂))
  have hReleased₁ : (outcome c₁).statusReleased = (policy.statusPolicy == "declassified") := by
    simp [SGXPublicOutcome.statusReleased, hPolicy]
  have hReleased₂ : (outcome c₂).statusReleased = (policy.statusPolicy == "declassified") := by
    simp [SGXPublicOutcome.statusReleased, hPolicy]
  rw [hReleased₁, hReleased₂]
  cases hDecl : (policy.statusPolicy == "declassified")
  · have hShape : (outcome c₁).outputShape = (outcome c₂).outputShape := by
      have := congrArg SGXPublicOutcome.outputShape hErased
      simpa [SGXPublicOutcome.withoutReleases, SGXPublicOutcome.statusReleased, hPolicy,
        hDecl] using this
    simp [kernelBoundarySchedule, hShape]
  · simp [boundaryWithoutStatusRelease, kernelBoundarySchedule,
      BoundaryEvent.withoutStatusRelease]

/-- The public-state transition of an admitted run: the public store is
unchanged, and only the abort flag depends on the run. -/
theorem evalKernelProgram_publicStateTransition (kp : KernelProgram)
    (a : AdmittedKernelRun kp) :
    (evalKernelProgram kp a.cfg).publicStateTransition =
      some ((evalKernelProgram kp a.cfg).toPublicStateTransition a.cfg.publicState
        a.cfg.publicState) := by
  obtain ⟨env, hEnvEq, _⟩ := kp.initialEnv_conforms a.cfg.declaredArgs a.args
  have hState := evalKernelBody_publicState kp.body (env := env) (oc := Outcome.empty)
    a.publicStoreOwned a.writesConfidential
  unfold evalKernelProgram
  simp only [hEnvEq]
  generalize evalKernelBody a.cfg env Outcome.empty kp.body = result at *
  obtain ⟨cfg', env', outcome⟩ := result
  simp only at hState ⊢
  rw [hState]
  simp [Outcome.withPublicStateTransition, Outcome.toPublicStateTransition,
    Outcome.committedPublicState, Outcome.abortedForCommit]

/-- The modeled final public-state record is public-determined outside the
status release. -/
theorem kernelFinalPublicState_safe (kp : KernelProgram) (policy : EntrypointPublicPolicy)
    (render : Value → String) (renderEnv : String × Value → String)
    (digest : ObjectStore → String) (deltaDigest : List Nat → String)
    (hAgree : PolicyAgreesWithFlow kp policy) :
    FinalPublicStateSafeModuloReleases AdmittedKernelRun.samePublic
      (fun a : AdmittedKernelRun kp => kernelPublicOutcome policy render renderEnv kp a.cfg)
      (fun a : AdmittedKernelRun kp => kernelFinalPublicState digest deltaDigest kp a.cfg) := by
  intro a₁ a₂ hPublic
  obtain ⟨hStatusNI, _⟩ := AdmittedKernelRun.flow_ni hPublic
  have hStore : a₁.cfg.publicState = a₂.cfg.publicState :=
    congrArg OperationalPublicProjection.publicState hPublic
  show (kernelFinalPublicState digest deltaDigest kp a₁.cfg).withoutStatusRelease
      (kernelPublicOutcome policy render renderEnv kp a₁.cfg).statusReleased =
    (kernelFinalPublicState digest deltaDigest kp a₂.cfg).withoutStatusRelease
      (kernelPublicOutcome policy render renderEnv kp a₂.cfg).statusReleased
  rw [kernelPublicOutcome_statusReleased, kernelPublicOutcome_statusReleased]
  unfold kernelFinalPublicState
  rw [evalKernelProgram_publicStateTransition kp a₁, evalKernelProgram_publicStateTransition kp a₂]
  by_cases hReleased : policy.statusPolicy = "declassified"
  · simp [PaperMainFinalPublicStateRollback.withoutStatusRelease, hReleased,
      Outcome.toPublicStateTransition, Outcome.committedPublicState, hStore]
  · have hStatusEq := hStatusNI (hAgree.statusPublic hReleased)
    simp [PaperMainFinalPublicStateRollback.withoutStatusRelease, hReleased,
      Outcome.toPublicStateTransition, Outcome.committedPublicState, Outcome.abortedForCommit,
      hStore, hStatusEq]

/-! ## Examples

The mixer's `withdraw`, as `uo-solc` emits it for the full-scan backend, is
admitted: it is well typed, returns only at its end, writes only confidential
objects, and its declared policies (status and return declassified) agree with
the flow analysis, which finds both secret. -/

private def mixerState : List StateObject :=
  [ { id := 1, name := "balances", kind := .mapKind, backend := .fullScan
    , oramScheme := "surrogate_public_schedule_v1", valueType := .scalar (.uint 256)
    , keyType := some (.scalar .bytes32), capacity := some 8, confidential := true }
  , { id := 2, name := "total", kind := .cell, backend := .fullScan
    , oramScheme := "surrogate_public_schedule_v1", valueType := .scalar (.uint 256)
    , keyType := none, capacity := none, confidential := true } ]

private def mixerWithdraw : KernelProgram :=
  { entrypointId := "withdraw(bytes32,uint256)"
  , params := [⟨"commitment", .scalar .bytes32⟩, ⟨"amount", .scalar (.uint 256)⟩]
  , returnType := some (.scalar (.uint 256))
  , secretArgs := [0, 1]
  , body :=
      [ .declare "oldBalance" (.scalar (.uint 256)) (.mapGet 1 (.var "commitment"))
      , .abortIf (.unary .not (.binary .gte (.var "oldBalance") (.var "amount")))
      , .mapPut 1 (.var "commitment") (.binary .sub (.var "oldBalance") (.var "amount"))
          (some (.literal (.bool true)))
      , .cellSet 2 (.binary .sub (.cellGet 2) (.var "amount")) (some (.literal (.bool true)))
      , .retStmt (some (.var "amount")) ] }

private def withdrawPolicy : EntrypointPublicPolicy :=
  { entrypointId := "withdraw(bytes32,uint256)", statusPolicy := "declassified"
  , returnPolicy := "declassified", declassifies := ["return", "success"]
  , returnLength := 32, entryInputLen := 64, gas := 2428 }

example : mixerWithdraw.wellTyped mixerState = true := by decide

example : KernelStatement.returnsOnlyLast mixerWithdraw.body = true := by decide

example : mixerWithdraw.writesOnlyConfidential mixerState = true := by decide

example : mixerWithdraw.flowSummary.statusSecret = true ∧
    mixerWithdraw.flowSummary.returnSecret = true := by decide

example : PolicyAgreesWithFlow mixerWithdraw withdrawPolicy :=
  ⟨by decide, by decide, by decide⟩

/-- A policy that declared `withdraw`'s status public would disagree with the
analysis. -/
example : ¬ PolicyAgreesWithFlow mixerWithdraw { withdrawPolicy with statusPolicy := "public" } :=
  fun h => absurd (h.statusPublic (by decide)) (by decide)

/-- A completed `withdraw` exits the enclave with its 32-byte return and an
aborted one with nothing, so their boundary schedules differ; they agree once
the status release is erased. -/
example (completed aborted : SGXPublicOutcome)
    (hCompleted : completed.outputShape = { returnPresent := true, returnLength := 32 })
    (hAborted : aborted.outputShape = OutputShape.erased) :
    kernelBoundarySchedule withdrawPolicy completed ≠
        kernelBoundarySchedule withdrawPolicy aborted ∧
      boundaryWithoutStatusRelease true (kernelBoundarySchedule withdrawPolicy completed) =
        boundaryWithoutStatusRelease true (kernelBoundarySchedule withdrawPolicy aborted) := by
  simp [kernelBoundarySchedule, boundaryWithoutStatusRelease,
    BoundaryEvent.withoutStatusRelease, hCompleted, hAborted, OutputShape.erased]

end UOToolchain.IR

namespace UOToolchain

/-- The paper-main theorem modulo declared releases for admitted kernel
programs, with every premise discharged: two admitted runs of an exact-backend
confidential entrypoint whose declared policies agree with the information-flow
analysis have the same `View_SGX ∖ rel` when they agree on contract,
entrypoint, public arguments, public environment, and public store. The view
is built from the models of the runtime's observables: the exact store's trace
encoding, the public outcome, the boundary schedule, the final public-state
record, and the entrypoint's fixed controller shape and release functions. -/
theorem paperMain_admittedKernelRun_exact_noninterference_moduloReleases
    (kp : IR.KernelProgram) (policy : IR.EntrypointPublicPolicy)
    (hAgree : IR.PolicyAgreesWithFlow kp policy)
    (encodeRun : List IR.KernelStatement → Trace)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (controllerShape : SGXControllerShape) (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {a₁ a₂ : IR.AdmittedKernelRun kp} (hPublic : a₁.samePublic a₂) :
    (paperMainViewOfRun
        (fun a : IR.AdmittedKernelRun kp => IR.kernelExactTrace encodeRun policy.gas kp a.cfg)
        (fun a => IR.kernelPublicOutcome policy render renderEnv kp a.cfg)
        (fun a => IR.kernelBoundarySchedule policy
          (IR.kernelPublicOutcome policy render renderEnv kp a.cfg))
        (fun _ => controllerShape)
        (fun a => IR.kernelFinalPublicState digest deltaDigest kp a.cfg)
        (fun _ => releaseFunctions)
        a₁).withoutReleases =
      (paperMainViewOfRun
        (fun a : IR.AdmittedKernelRun kp => IR.kernelExactTrace encodeRun policy.gas kp a.cfg)
        (fun a => IR.kernelPublicOutcome policy render renderEnv kp a.cfg)
        (fun a => IR.kernelBoundarySchedule policy
          (IR.kernelPublicOutcome policy render renderEnv kp a.cfg))
        (fun _ => controllerShape)
        (fun a => IR.kernelFinalPublicState digest deltaDigest kp a.cfg)
        (fun _ => releaseFunctions)
        a₂).withoutReleases :=
  paperMain_noninterference_moduloReleases_of_publicTrace
    (fun lhs rhs _ => viewMPlus_injective
      (IR.admittedKernel_exactUO encodeRun policy.gas lhs.toAdmittedKernelConfig
        rhs.toAdmittedKernelConfig))
    (IR.kernelPublicOutcome_safe kp policy render renderEnv hAgree)
    (IR.kernelBoundarySchedule_safe policy
      (IR.kernelPublicOutcome_safe kp policy render renderEnv hAgree) (fun _ => rfl))
    (fun _ _ _ => rfl)
    (IR.kernelFinalPublicState_safe kp policy render renderEnv digest deltaDigest hAgree)
    (fun _ _ _ => rfl)
    hPublic

end UOToolchain
