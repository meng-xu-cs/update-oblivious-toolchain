import UOToolchain.KernelTyping
import UOToolchain.PaperMainReleases

/-!
# Exact-backend storage traces of admitted kernel programs

The exact backends (`UOCell`, `UOArray`, full-scan `UOMap`) make every storage
access touch its whole object. A run reads each object it accesses once, every
slot of it, when the call loads the object, in object-id order; its accesses
then work on the loaded copy and read nothing more. At commit every object the
run has a write statement for is rewritten slot by slot with `Update`-class
writes, in object-id order, whether or not the write's predicate held. An
object the run only reads is not written. The physical trace of a run is
therefore a function of which statements the run executes, not of keys,
indices, values, or predicates.

This module makes that argument a theorem for admitted kernel programs:

1. `evalKernelBodyExecuted` lists the statements the evaluator executes,
   following `evalKernelBody`'s control flow.
2. For a well-typed program whose only return is its last statement, every
   conforming run executes the whole body (`evalKernelProgramExecuted_eq_body`).
3. `kernelExactTrace` encodes the executed statements as an M+ trace through
   any encoder of statement lists; `exactEncodeRun` is the encoder the runtime's
   exact store implements. All admitted runs of a program produce the same
   trace (`admittedKernel_exactUO`).
4. `paperMain_admittedKernel_exact_noninterference_moduloReleases` instantiates
   the paper-main theorem modulo releases with this trace semantics, so its
   storage-trace premise is discharged rather than assumed.

The encoder models the runtime's exact store. That the Rust store emits
exactly `exactEncodeRun`'s physical trace is a refinement obligation checked
empirically against runtime traces, not proved here.
-/

namespace UOToolchain.IR

/-! ## Storage accesses -/

/-- A storage access of the exact backend: a read of an object, or a write
(read-modify-write) of an object. Operands are deliberately absent. -/
inductive ExactAccess where
  | read (objectId : Nat)
  | write (objectId : Nat)
  deriving DecidableEq, Repr

mutual

/-- Objects an expression reads, in evaluation order. `select` arms are pure,
so only the condition can read storage. -/
def KernelExpr.storageReads : KernelExpr → List Nat
  | .literal _ => []
  | .var _ => []
  | .unary _ e => KernelExpr.storageReads e
  | .binary _ lhs rhs => KernelExpr.storageReads lhs ++ KernelExpr.storageReads rhs
  | .select cond _ _ => KernelExpr.storageReads cond
  | .cellGet objectId => [objectId]
  | .arrayGet objectId index => KernelExpr.storageReads index ++ [objectId]
  | .mapGet objectId key => KernelExpr.storageReads key ++ [objectId]
  | .structField base _ => KernelExpr.storageReads base
  | .arrayIndex base index => KernelExpr.storageReads base ++ KernelExpr.storageReads index
  | .keccak256 parts => KernelExpr.listStorageReads parts

/-- Objects an expression list reads, in evaluation order. -/
def KernelExpr.listStorageReads : List KernelExpr → List Nat
  | [] => []
  | p :: rest => KernelExpr.storageReads p ++ KernelExpr.listStorageReads rest

end

/-- Objects an optional write predicate reads. -/
def predicateStorageReads : Option KernelExpr → List Nat
  | none => []
  | some predicate => predicate.storageReads

/-- Storage accesses of a statement: the reads of its expressions, then the
write of its target object. A write is performed whatever its predicate. -/
def KernelStatement.accesses : KernelStatement → List ExactAccess
  | .declare _ _ value => value.storageReads.map .read
  | .assign _ value => value.storageReads.map .read
  | .require cond => cond.storageReads.map .read
  | .abortIf cond => cond.storageReads.map .read
  | .cellSet objectId value predicate =>
      (value.storageReads ++ predicateStorageReads predicate).map .read ++ [.write objectId]
  | .arraySet objectId index value predicate =>
      (index.storageReads ++ value.storageReads ++ predicateStorageReads predicate).map .read ++
        [.write objectId]
  | .mapPut objectId key value predicate =>
      (key.storageReads ++ value.storageReads ++ predicateStorageReads predicate).map .read ++
        [.write objectId]
  | .retStmt none => []
  | .retStmt (some value) => value.storageReads.map .read

/-- The statements `evalKernelBody` executes, with the same control flow: a
statement whose status stops the body, or that returns, is the last one
executed. -/
def evalKernelBodyExecuted
    (cfg : OperationalConfig) (env : LocalEnv) (oc : Outcome) :
    List KernelStatement → List KernelStatement
  | [] => []
  | stmt :: rest =>
      let (cfg', env', oc') := evalKernelStatement cfg env oc stmt
      stmt ::
        (if oc'.status.continuesBody true then
          if oc'.publicResult.isSome then [] else evalKernelBodyExecuted cfg' env' oc' rest
        else [])

/-- The statements a program run executes, as `evalKernelProgram` runs it. -/
def evalKernelProgramExecuted (kp : KernelProgram) (cfg : OperationalConfig) :
    List KernelStatement :=
  match kp.initialEnv cfg.declaredArgs with
  | none => []
  | some env => evalKernelBodyExecuted cfg env Outcome.empty kp.body

theorem evalKernelBodyExecuted_eq_of_wellTyped :
    ∀ (body : List KernelStatement) {cfg : OperationalConfig} {env : LocalEnv}
      {oc : Outcome} {Γ : List (String × Ty)},
      EnvConforms Γ env → StoreConforms cfg →
      KernelStatement.bodyTyped Γ cfg.contract.state body = true →
      KernelStatement.returnsOnlyLast body = true →
      oc.status.continuesBody true = true → oc.publicResult = none →
      evalKernelBodyExecuted cfg env oc body = body
  | [], _, _, _, _, _, _, _, _, _, _ => by simp [evalKernelBodyExecuted]
  | stmt :: rest, cfg, env, oc, Γ, hEnv, hStore, hTy, hRet, hOc, hPub => by
      simp only [KernelStatement.bodyTyped] at hTy
      split at hTy
      · rename_i Γ' hStmt
        obtain ⟨hStatus, hEnv', hStore', hContract⟩ :=
          evalKernelStatement_wellTyped (oc := oc) hEnv hStore hStmt hOc
        cases rest with
        | nil =>
            rw [evalKernelBodyExecuted]
            generalize evalKernelStatement cfg env oc stmt = step at *
            obtain ⟨cfg', env', oc'⟩ := step
            simp only at hStatus ⊢
            simp only [hStatus, ↓reduceIte]
            split <;> simp [evalKernelBodyExecuted]
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
            rw [evalKernelBodyExecuted]
            generalize evalKernelStatement cfg env oc stmt = step at *
            obtain ⟨cfg', env', oc'⟩ := step
            simp only at hStatus hEnv' hStore' hContract hPubStmt ⊢
            have hPub' : oc'.publicResult = none := by rw [hPubStmt, hPub]
            simp only [hStatus, hPub', Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
            rw [evalKernelBodyExecuted_eq_of_wellTyped (next :: rest') hEnv' hStore'
              (by rw [hContract]; exact hTy) hRet' hStatus hPub']
      · cases hTy

/-- Every conforming run of a well-typed program whose only return is its last
statement executes the program's whole body. -/
theorem evalKernelProgramExecuted_eq_body (kp : KernelProgram)
    (cfg : OperationalConfig)
    (hTy : kp.wellTyped cfg.contract.state = true)
    (hRet : KernelStatement.returnsOnlyLast kp.body = true)
    (hArgs : ArgsConform kp.params cfg.declaredArgs)
    (hStore : StoreConforms cfg) :
    evalKernelProgramExecuted kp cfg = kp.body := by
  obtain ⟨env, hEnvEq, hEnv⟩ := kp.initialEnv_conforms cfg.declaredArgs hArgs
  unfold evalKernelProgramExecuted
  simp only [hEnvEq]
  exact evalKernelBodyExecuted_eq_of_wellTyped kp.body (oc := Outcome.empty) hEnv hStore
    hTy hRet rfl rfl

/-! ## Exact encoding -/

/-- Object an access touches. -/
def ExactAccess.objectId : ExactAccess → Nat
  | .read objectId => objectId
  | .write objectId => objectId

/-- Objects the accesses touch, each once, in increasing id order: the order in
which the runtime loads them and commits them. -/
def touchedObjects (accesses : List ExactAccess) : List Nat :=
  (List.range (accesses.foldl (fun bound access => max bound (access.objectId + 1)) 0)).filter
    fun objectId => accesses.any fun access => access.objectId == objectId

/-- The touched objects are listed in strictly increasing id order, so each is
listed once. -/
theorem touchedObjects_strictly_increasing (accesses : List ExactAccess) :
    (touchedObjects accesses).Pairwise (· < ·) :=
  List.Pairwise.filter _ List.pairwise_lt_range

/-- An object is among the touched ones only if some access is to it. -/
theorem access_of_mem_touchedObjects {accesses : List ExactAccess} {objectId : Nat}
    (h : objectId ∈ touchedObjects accesses) :
    ∃ access ∈ accesses, access.objectId = objectId := by
  unfold touchedObjects at h
  simp only [List.mem_filter, List.any_eq_true] at h
  obtain ⟨_, access, hIn, hEq⟩ := h
  exact ⟨access, hIn, by simpa using hEq⟩

/-- Whether an access is a write. -/
def ExactAccess.isWrite : ExactAccess → Bool
  | .read _ => false
  | .write _ => true

/-- Objects the accesses write, each once, in increasing id order: the objects
the runtime rewrites at commit. An object that is only read is not among
them. -/
def writtenObjects (accesses : List ExactAccess) : List Nat :=
  touchedObjects (accesses.filter ExactAccess.isWrite)

/-- An object is among the written ones only if some access writes it. -/
theorem write_mem_of_mem_writtenObjects {accesses : List ExactAccess} {objectId : Nat}
    (h : objectId ∈ writtenObjects accesses) : ExactAccess.write objectId ∈ accesses := by
  unfold writtenObjects touchedObjects at h
  simp only [List.mem_filter, List.any_eq_true] at h
  obtain ⟨_, access, ⟨hIn, hWrite⟩, hEq⟩ := h
  cases access with
  | read id => simp [ExactAccess.isWrite] at hWrite
  | write id =>
      have hId : id = objectId := by simpa [ExactAccess.objectId] using hEq
      subst hId
      exact hIn

/-- Public layout of an exact-backend object: its name, kind, number of slots
(one for a cell, the capacity for an array or map), and sealed record length. -/
structure ExactObjectLayout where
  name : String
  kind : ContainerKind
  slots : Nat
  recordLen : Nat

/-- Storage location of a slot, in the runtime's naming: `name` for a cell,
`name[slot]` for an array, `name#slot` for a map. -/
def ExactObjectLayout.location (object : ExactObjectLayout) (slot : Nat) : String :=
  match object.kind with
  | .cell => object.name
  | .arrayKind => object.name ++ "[" ++ toString slot ++ "]"
  | .mapKind => object.name ++ "#" ++ toString slot

/-- A full scan: one read of every slot. -/
def ExactObjectLayout.scanReads (object : ExactObjectLayout) : List PhysicalRead :=
  (List.range object.slots).map fun slot =>
    { object := object.name, location := object.location slot, len := object.recordLen }

/-- A full rewrite: one `Update`-class write of every slot. -/
def ExactObjectLayout.updateWrites (object : ExactObjectLayout) : List PhysicalWrite :=
  (List.range object.slots).map fun slot =>
    { object := object.name, location := object.location slot, writeClass := "Update",
      len := object.recordLen }

/-- The exact store's physical trace of a run that executes `statements`: one
full scan of every object a statement accesses, in object-id order, when the
call loads it, and at commit a full rewrite of every object a statement
writes, in object-id order. An object is read once however many statements
access it, and an object the statements only read is not written. -/
def exactEncodeRun (layout : Nat → ExactObjectLayout) (statements : List KernelStatement) :
    Trace :=
  let accesses := statements.flatMap KernelStatement.accesses
  { Trace.empty with
    physicalReads :=
      (touchedObjects accesses).flatMap fun objectId => (layout objectId).scanReads
    physicalWrites :=
      (writtenObjects accesses).flatMap fun objectId => (layout objectId).updateWrites }

/-- The exact encoding reads each object once: its reads are the scans of the
touched objects, which are listed once each in increasing id order, and an
object no statement accesses is not one of them. -/
theorem exactEncodeRun_reads_each_touched_once (layout : Nat → ExactObjectLayout)
    (statements : List KernelStatement) :
    (exactEncodeRun layout statements).physicalReads =
        (touchedObjects (statements.flatMap KernelStatement.accesses)).flatMap
          (fun objectId => (layout objectId).scanReads) ∧
      (touchedObjects (statements.flatMap KernelStatement.accesses)).Pairwise (· < ·) ∧
      ∀ objectId,
        (∀ access ∈ statements.flatMap KernelStatement.accesses,
            access.objectId ≠ objectId) →
          objectId ∉ touchedObjects (statements.flatMap KernelStatement.accesses) :=
  ⟨rfl, touchedObjects_strictly_increasing _, fun _ hNone hMem =>
    let ⟨access, hIn, hEq⟩ := access_of_mem_touchedObjects hMem
    hNone access hIn hEq⟩

/-- The number of records the exact encoding reads: the slots of the touched
objects, each object counted once. -/
theorem exactEncodeRun_read_count (layout : Nat → ExactObjectLayout)
    (statements : List KernelStatement) :
    (exactEncodeRun layout statements).physicalReads.length =
      ((touchedObjects (statements.flatMap KernelStatement.accesses)).map
        fun objectId => (layout objectId).slots).sum := by
  simp [exactEncodeRun, ExactObjectLayout.scanReads, List.length_flatMap]

/-- The exact encoding reveals no write class: every write is an `Update`. -/
theorem exactEncodeRun_writes_update (layout : Nat → ExactObjectLayout)
    (statements : List KernelStatement) :
    ∀ w ∈ (exactEncodeRun layout statements).physicalWrites, w.writeClass = "Update" := by
  intro w hw
  simp only [exactEncodeRun, ExactObjectLayout.updateWrites, List.mem_flatMap,
    List.mem_map] at hw
  obtain ⟨_, _, _, _, rfl⟩ := hw
  rfl

/-- The exact encoding rewrites an object only if a statement writes it: its
writes are the rewrites of the written objects, and an object with no write
access is not one of them. -/
theorem exactEncodeRun_rewrites_only_written (layout : Nat → ExactObjectLayout)
    (statements : List KernelStatement) :
    (exactEncodeRun layout statements).physicalWrites =
        (writtenObjects (statements.flatMap KernelStatement.accesses)).flatMap
          (fun objectId => (layout objectId).updateWrites) ∧
      ∀ objectId,
        ExactAccess.write objectId ∉ statements.flatMap KernelStatement.accesses →
          objectId ∉ writtenObjects (statements.flatMap KernelStatement.accesses) :=
  ⟨rfl, fun _ hNoWrite hMem => hNoWrite (write_mem_of_mem_writtenObjects hMem)⟩

/-- A run that only reads writes nothing. -/
theorem exactEncodeRun_no_writes_of_readOnly (layout : Nat → ExactObjectLayout)
    (statements : List KernelStatement)
    (hRead : ∀ access ∈ statements.flatMap KernelStatement.accesses, access.isWrite = false) :
    (exactEncodeRun layout statements).physicalWrites = [] := by
  have hNone :
      (statements.flatMap KernelStatement.accesses).filter ExactAccess.isWrite = [] := by
    rw [List.filter_eq_nil_iff]
    intro access hMem
    simp [hRead access hMem]
  simp [exactEncodeRun, writtenObjects, touchedObjects, hNone]

/-- The M+ trace of a run: the encoding of the statements it executes, with the
entrypoint's modeled gas. -/
def kernelExactTrace (encodeRun : List KernelStatement → Trace) (gas : Nat)
    (kp : KernelProgram) (cfg : OperationalConfig) : Trace :=
  { encodeRun (evalKernelProgramExecuted kp cfg) with gasUsed := gas }

/-- The trace of every conforming run of an admitted program is the encoding of
its whole body. -/
theorem kernelExactTrace_eq_static (encodeRun : List KernelStatement → Trace) (gas : Nat)
    (kp : KernelProgram) (cfg : OperationalConfig)
    (hTy : kp.wellTyped cfg.contract.state = true)
    (hRet : KernelStatement.returnsOnlyLast kp.body = true)
    (hArgs : ArgsConform kp.params cfg.declaredArgs)
    (hStore : StoreConforms cfg) :
    kernelExactTrace encodeRun gas kp cfg = { encodeRun kp.body with gasUsed := gas } := by
  unfold kernelExactTrace
  rw [evalKernelProgramExecuted_eq_body kp cfg hTy hRet hArgs hStore]

/-- Example: the encoding of a mixer deposit over a capacity-8 full-scan map
(`balances`, object 1) and a cell (`total`, object 2) is the trace the runtime
emits: one scan of the map and one read of the cell, though the body accesses
each twice, then one rewrite of each written object in object-id order. -/
private def depositLayout : Nat → ExactObjectLayout
  | 1 => { name := "balances", kind := .mapKind, slots := 8, recordLen := 190 }
  | 2 => { name := "total", kind := .cell, slots := 1, recordLen := 124 }
  | _ => { name := "", kind := .cell, slots := 0, recordLen := 0 }

private def depositBody : List KernelStatement :=
  [ .declare "oldBalance" (.scalar (.uint 256)) (.mapGet 1 (.var "commitment"))
  , .mapPut 1 (.var "commitment") (.binary .add (.var "oldBalance") (.var "amount")) none
  , .cellSet 2 (.binary .add (.cellGet 2) (.var "amount")) none ]

example :
    (exactEncodeRun depositLayout depositBody).physicalWrites.map PhysicalWrite.location =
      [ "balances#0", "balances#1", "balances#2", "balances#3", "balances#4", "balances#5",
        "balances#6", "balances#7", "total" ] := by
  decide

example :
    (exactEncodeRun depositLayout depositBody).physicalReads.map PhysicalRead.location =
      [ "balances#0", "balances#1", "balances#2", "balances#3", "balances#4", "balances#5",
        "balances#6", "balances#7", "total" ] := by
  decide

/-- Example: a balance query scans the map once and writes nothing, and a body
that reads the map and writes the cell rewrites the cell alone. -/
private def balanceQueryBody : List KernelStatement :=
  [ .retStmt (some (.mapGet 1 (.var "commitment"))) ]

private def totalFromBalanceBody : List KernelStatement :=
  [ .cellSet 2 (.mapGet 1 (.var "commitment")) none ]

example :
    (exactEncodeRun depositLayout balanceQueryBody).physicalReads.length = 8 ∧
      (exactEncodeRun depositLayout balanceQueryBody).physicalWrites.length = 0 := by
  decide

example :
    (exactEncodeRun depositLayout totalFromBalanceBody).physicalWrites.map
        PhysicalWrite.location = ["total"] := by
  decide

/-- A run of an admitted kernel program: a configuration over which the program
is well typed, returns only as its last statement, receives arguments of its
parameter types, and finds a store that conforms to the state layout. -/
structure AdmittedKernelConfig (kp : KernelProgram) where
  cfg : OperationalConfig
  wellTyped : kp.wellTyped cfg.contract.state = true
  returnsLast : KernelStatement.returnsOnlyLast kp.body = true
  args : ArgsConform kp.params cfg.declaredArgs
  store : StoreConforms cfg

/-- Two admitted runs agree on contract, entrypoint, public arguments, public
environment, and public store. -/
def AdmittedKernelConfig.samePublic {kp : KernelProgram}
    (lhs rhs : AdmittedKernelConfig kp) : Prop :=
  sameOperationalPublicProjection lhs.cfg rhs.cfg

/-- Exact update-obliviousness for admitted kernel programs: every pair of
admitted runs produces the same M+ view, under any encoder of the executed
statements, in particular `exactEncodeRun`. The equality does not even need the
runs to share their public inputs. -/
theorem admittedKernel_exactUO {kp : KernelProgram}
    (encodeRun : List KernelStatement → Trace)
    (gas : Nat) (lhs rhs : AdmittedKernelConfig kp) :
    viewMPlus (kernelExactTrace encodeRun gas kp lhs.cfg) =
      viewMPlus (kernelExactTrace encodeRun gas kp rhs.cfg) := by
  rw [kernelExactTrace_eq_static encodeRun gas kp lhs.cfg lhs.wellTyped lhs.returnsLast
      lhs.args lhs.store,
    kernelExactTrace_eq_static encodeRun gas kp rhs.cfg rhs.wellTyped rhs.returnsLast
      rhs.args rhs.store]

end UOToolchain.IR

namespace UOToolchain

/-! ## Paper-main theorem over admitted kernel runs -/

/-- `sgxViewOfTrace` without the configuration argument it ignores. -/
def sgxViewOfRunTrace
    (publicOutcome : SGXPublicOutcome)
    (boundarySchedule : List BoundaryEvent)
    (microTrace : SGXMicroTrace)
    (trace : Trace) : SGXView :=
  { entrypointId := publicOutcome.entrypointId
  , publicArgs := publicOutcome.publicArgs
  , publicEnv := publicOutcome.publicEnv
  , boundarySchedule := boundarySchedule
  , persistentReads := trace.physicalReads
  , persistentWrites := trace.physicalWrites
  , pageTrace := microTrace.pageTrace
  , exitTrace := microTrace.exitTrace
  , sharedResourceTrace := microTrace.sharedResourceTrace
  , terminationStatus := publicOutcome.terminationStatus
  , statusPolicy := publicOutcome.statusPolicy
  , outputShape := publicOutcome.outputShape
  , returnPolicy := publicOutcome.returnPolicy
  , returnPayload := publicOutcome.returnPayload
  , encryptedReturnPayload := publicOutcome.encryptedReturnPayload
  , declassifies := publicOutcome.declassifies
  , gasUsed := publicOutcome.gasUsed
  }

theorem sgxViewOfTrace_eq_sgxViewOfRunTrace (cfg : Config)
    (publicOutcome : SGXPublicOutcome) (boundarySchedule : List BoundaryEvent)
    (microTrace : SGXMicroTrace) (trace : Trace) :
    sgxViewOfTrace cfg publicOutcome boundarySchedule microTrace trace =
      sgxViewOfRunTrace publicOutcome boundarySchedule microTrace trace := rfl

@[simp] theorem sgxViewOfRunTrace_boundarySchedule (publicOutcome : SGXPublicOutcome)
    (boundarySchedule : List BoundaryEvent) (microTrace : SGXMicroTrace) (trace : Trace) :
    (sgxViewOfRunTrace publicOutcome boundarySchedule microTrace trace).boundarySchedule =
      boundarySchedule := rfl

theorem sgxPublicOutcome_sgxViewOfRunTrace (publicOutcome : SGXPublicOutcome)
    (boundarySchedule : List BoundaryEvent) (microTrace : SGXMicroTrace) (trace : Trace) :
    sgxPublicOutcome (sgxViewOfRunTrace publicOutcome boundarySchedule microTrace trace) =
      publicOutcome := by
  cases publicOutcome
  rfl

/-- `View_SGX` of a run over any configuration type. -/
def paperMainViewOfRun {κ : Type}
    (run : κ → Trace)
    (publicOutcome : κ → SGXPublicOutcome)
    (boundarySchedule : κ → List BoundaryEvent)
    (controllerShape : κ → SGXControllerShape)
    (finalPublicStateRollback : κ → PaperMainFinalPublicStateRollback)
    (releaseFunctions : κ → PaperMainDeclaredReleaseFunctions)
    (cfg : κ) : View_SGX :=
  paperMainViewOfSGX
    (finalPublicStateRollback cfg)
    (releaseFunctions cfg)
    (sgxViewOfRunTrace
      (publicOutcome cfg)
      (boundarySchedule cfg)
      (controllerMicroTraceOfShape (controllerShape cfg))
      (run cfg))

/-- Over the abstract configurations, `paperMainViewOfRun` is the exact
paper-main view. -/
theorem paperMainExactView_eq_paperMainViewOfRun
    (run : TraceSemantics)
    (publicOutcome : Config → SGXPublicOutcome)
    (boundarySchedule : Config → List BoundaryEvent)
    (controllerShape : Config → SGXControllerShape)
    (finalPublicStateRollback : Config → PaperMainFinalPublicStateRollback)
    (releaseFunctions : Config → PaperMainDeclaredReleaseFunctions)
    (cfg : Config) :
    paperMainExactView run publicOutcome boundarySchedule controllerShape
        finalPublicStateRollback releaseFunctions cfg =
      paperMainViewOfRun run publicOutcome boundarySchedule controllerShape
        finalPublicStateRollback releaseFunctions cfg := rfl

/-- Paper-main theorem modulo declared releases for any configuration type,
with the storage trace premise stated as public determination of the trace. -/
theorem paperMain_noninterference_moduloReleases_of_publicTrace {κ : Type}
    {samePublic : κ → κ → Prop}
    {run : κ → Trace}
    {publicOutcome : κ → SGXPublicOutcome}
    {boundarySchedule : κ → List BoundaryEvent}
    {controllerShape : κ → SGXControllerShape}
    {finalPublicStateRollback : κ → PaperMainFinalPublicStateRollback}
    {releaseFunctions : κ → PaperMainDeclaredReleaseFunctions}
    (hTrace : PaperMainPublicFieldSafe samePublic run)
    (hOutcome : PublicOutcomeSafeModuloReleases samePublic publicOutcome)
    (hBoundary : BoundarySafeModuloReleases samePublic publicOutcome boundarySchedule)
    (hController : PaperMainPublicFieldSafe samePublic controllerShape)
    (hFinal :
      FinalPublicStateSafeModuloReleases samePublic publicOutcome finalPublicStateRollback)
    (hRelease : PaperMainPublicFieldSafe samePublic releaseFunctions)
    {cfg₁ cfg₂ : κ} (hPublic : samePublic cfg₁ cfg₂) :
    (paperMainViewOfRun run publicOutcome boundarySchedule controllerShape
        finalPublicStateRollback releaseFunctions cfg₁).withoutReleases =
      (paperMainViewOfRun run publicOutcome boundarySchedule controllerShape
        finalPublicStateRollback releaseFunctions cfg₂).withoutReleases := by
  have hTraceEq : run cfg₁ = run cfg₂ := hTrace cfg₁ cfg₂ hPublic
  have hOutcomeEq :
      (publicOutcome cfg₁).withoutReleases = (publicOutcome cfg₂).withoutReleases :=
    hOutcome cfg₁ cfg₂ hPublic
  have hBoundaryEq :
      boundaryWithoutStatusRelease (publicOutcome cfg₁).statusReleased (boundarySchedule cfg₁) =
        boundaryWithoutStatusRelease (publicOutcome cfg₂).statusReleased
          (boundarySchedule cfg₂) :=
    hBoundary cfg₁ cfg₂ hPublic
  have hControllerEq : controllerShape cfg₁ = controllerShape cfg₂ :=
    hController cfg₁ cfg₂ hPublic
  have hFinalEq :
      (finalPublicStateRollback cfg₁).withoutStatusRelease
          (publicOutcome cfg₁).statusReleased =
        (finalPublicStateRollback cfg₂).withoutStatusRelease
          (publicOutcome cfg₂).statusReleased :=
    hFinal cfg₁ cfg₂ hPublic
  have hReleaseEq : releaseFunctions cfg₁ = releaseFunctions cfg₂ :=
    hRelease cfg₁ cfg₂ hPublic
  unfold paperMainViewOfRun paperMainViewOfSGX PaperMainViewSGX.withoutReleases
  simp only [sgxPublicOutcome_sgxViewOfRunTrace, sgxViewOfRunTrace_boundarySchedule]
  rw [hOutcomeEq, hFinalEq, hReleaseEq, hBoundaryEq, hControllerEq, hTraceEq]
  rfl

/-- Paper-main theorem modulo declared releases over admitted kernel runs with
the exact backends' trace semantics. The storage-trace premise is discharged:
the kernel type checker and the exact encoding make the trace the same for every
admitted run. The remaining premises concern the public outcome, boundary
schedule, controller shape, final public state, and release functions. -/
theorem paperMain_admittedKernel_exact_noninterference_moduloReleases
    (kp : IR.KernelProgram) (encodeRun : List IR.KernelStatement → Trace) (gas : Nat)
    {publicOutcome : IR.AdmittedKernelConfig kp → SGXPublicOutcome}
    {boundarySchedule : IR.AdmittedKernelConfig kp → List BoundaryEvent}
    {controllerShape : IR.AdmittedKernelConfig kp → SGXControllerShape}
    {finalPublicStateRollback :
      IR.AdmittedKernelConfig kp → PaperMainFinalPublicStateRollback}
    {releaseFunctions : IR.AdmittedKernelConfig kp → PaperMainDeclaredReleaseFunctions}
    (hOutcome :
      PublicOutcomeSafeModuloReleases IR.AdmittedKernelConfig.samePublic publicOutcome)
    (hBoundary :
      BoundarySafeModuloReleases IR.AdmittedKernelConfig.samePublic publicOutcome
        boundarySchedule)
    (hController : PaperMainPublicFieldSafe IR.AdmittedKernelConfig.samePublic controllerShape)
    (hFinal :
      FinalPublicStateSafeModuloReleases IR.AdmittedKernelConfig.samePublic publicOutcome
        finalPublicStateRollback)
    (hRelease : PaperMainPublicFieldSafe IR.AdmittedKernelConfig.samePublic releaseFunctions)
    {a₁ a₂ : IR.AdmittedKernelConfig kp} (hPublic : a₁.samePublic a₂) :
    (paperMainViewOfRun (fun a => IR.kernelExactTrace encodeRun gas kp a.cfg) publicOutcome
        boundarySchedule controllerShape finalPublicStateRollback releaseFunctions
        a₁).withoutReleases =
      (paperMainViewOfRun (fun a => IR.kernelExactTrace encodeRun gas kp a.cfg) publicOutcome
        boundarySchedule controllerShape finalPublicStateRollback releaseFunctions
        a₂).withoutReleases :=
  paperMain_noninterference_moduloReleases_of_publicTrace
    (fun lhs rhs _ => viewMPlus_injective (IR.admittedKernel_exactUO encodeRun gas lhs rhs))
    hOutcome hBoundary hController hFinal hRelease hPublic

end UOToolchain
