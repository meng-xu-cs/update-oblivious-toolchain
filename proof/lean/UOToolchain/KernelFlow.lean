import UOToolchain.KernelExactTrace

namespace UOToolchain.IR

/-!
# Information flow in admitted kernel programs

The paper-main theorem modulo releases needs the public outcome to be
determined by the public inputs outside the declared releases: an entrypoint
with `status: public` must not abort depending on secrets, and one with
`returns: public` must not return a secret-dependent value. `uo-solc` enforces
this with a taint analysis; this module states the analysis over kernel
programs and proves it sound.

Variables carry a label, public or secret. Parameters are secret exactly when
their index is in `secretArgs`; every storage read is secret, because a
confidential kernel targets only confidential objects. The analysis marks the
status secret when a `require` or `abortIf` tests a secret condition or the
program writes a map (a full bounded map aborts a write of a new key, and
whether a key is new depends on the map's confidential contents), and marks the
return secret when the returned value is secret.

`evalKernelProgram_status_eq_of_flow` and
`evalKernelProgram_publicResult_eq_of_flow`: for a well-typed program whose
analysis reports a public status (or return), two conforming runs over the same
contract that agree on the arguments at public parameter positions end with the
same status (or return value), whatever their secret arguments and
confidential state.
-/

/-! ## Labels -/

/-- Label of a variable (`true` = secret); the first binding wins, as in
`LocalEnv.lookup`. -/
def labelLookup (labels : List (String × Bool)) (name : String) : Option Bool :=
  match labels.find? (fun entry => entry.fst = name) with
  | some (_, secret) => some secret
  | none => none

/-- Bind a variable's label, mirroring `LocalEnv.insert`. -/
def labelInsert (labels : List (String × Bool)) (name : String) (secret : Bool) :
    List (String × Bool) :=
  (name, secret) :: labels.filter (fun entry => entry.fst ≠ name)

/-- A variable is public only when it is bound with a public label. -/
def isPublicVar (labels : List (String × Bool)) (name : String) : Bool :=
  labelLookup labels name == some false

theorem labelLookup_labelInsert_same (labels : List (String × Bool)) (name : String)
    (secret : Bool) : labelLookup (labelInsert labels name secret) name = some secret := by
  simp [labelInsert, labelLookup]

theorem labelLookup_labelInsert_ne (labels : List (String × Bool)) (name name' : String)
    (secret : Bool) (hNe : name' ≠ name) :
    labelLookup (labelInsert labels name secret) name' = labelLookup labels name' := by
  unfold labelInsert labelLookup
  rw [find?_cons_filter_ne labels name name' secret hNe]

/-- Two environments agree on every public variable. -/
def EnvLowEq (labels : List (String × Bool)) (env₁ env₂ : LocalEnv) : Prop :=
  ∀ name, isPublicVar labels name = true → env₁.lookup name = env₂.lookup name

theorem EnvLowEq.insert {labels : List (String × Bool)} {env₁ env₂ : LocalEnv}
    (hLow : EnvLowEq labels env₁ env₂) (name : String) (secret : Bool)
    {value₁ value₂ : Value} (hValue : secret = false → value₁ = value₂) :
    EnvLowEq (labelInsert labels name secret) (env₁.insert name value₁)
      (env₂.insert name value₂) := by
  intro name' hPublic
  by_cases hName : name' = name
  · subst hName
    simp only [isPublicVar, labelLookup_labelInsert_same, beq_iff_eq, Option.some.injEq]
      at hPublic
    rw [LocalEnv.lookup_insert_same, LocalEnv.lookup_insert_same, hValue hPublic]
  · simp only [isPublicVar, labelLookup_labelInsert_ne labels name name' secret hName]
      at hPublic
    rw [LocalEnv.lookup_insert_ne env₁ name name' value₁ hName,
      LocalEnv.lookup_insert_ne env₂ name name' value₂ hName]
    exact hLow name' (by simpa [isPublicVar] using hPublic)

/-! ## Expressions -/

mutual

/-- A pure expression is secret when it mentions a variable that is not
public. -/
def KernelPureExpr.secret (labels : List (String × Bool)) : KernelPureExpr → Bool
  | .literal _ => false
  | .var name => !isPublicVar labels name
  | .unary _ e => KernelPureExpr.secret labels e
  | .binary _ lhs rhs => KernelPureExpr.secret labels lhs || KernelPureExpr.secret labels rhs
  | .select cond whenTrue whenFalse =>
      KernelPureExpr.secret labels cond || KernelPureExpr.secret labels whenTrue ||
        KernelPureExpr.secret labels whenFalse
  | .structField base _ => KernelPureExpr.secret labels base
  | .arrayIndex base index =>
      KernelPureExpr.secret labels base || KernelPureExpr.secret labels index
  | .keccak256 parts => KernelPureExpr.listSecret labels parts

/-- Some expression in the list is secret. -/
def KernelPureExpr.listSecret (labels : List (String × Bool)) :
    List KernelPureExpr → Bool
  | [] => false
  | p :: rest => KernelPureExpr.secret labels p || KernelPureExpr.listSecret labels rest

end

mutual

/-- A kernel expression is secret when it mentions a variable that is not
public or reads storage. -/
def KernelExpr.secret (labels : List (String × Bool)) : KernelExpr → Bool
  | .literal _ => false
  | .var name => !isPublicVar labels name
  | .unary _ e => KernelExpr.secret labels e
  | .binary _ lhs rhs => KernelExpr.secret labels lhs || KernelExpr.secret labels rhs
  | .select cond whenTrue whenFalse =>
      KernelExpr.secret labels cond || whenTrue.secret labels || whenFalse.secret labels
  | .cellGet _ => true
  | .arrayGet _ _ => true
  | .mapGet _ _ => true
  | .structField base _ => KernelExpr.secret labels base
  | .arrayIndex base index => KernelExpr.secret labels base || KernelExpr.secret labels index
  | .keccak256 parts => KernelExpr.listSecret labels parts

/-- Some expression in the list is secret. -/
def KernelExpr.listSecret (labels : List (String × Bool)) : List KernelExpr → Bool
  | [] => false
  | p :: rest => KernelExpr.secret labels p || KernelExpr.listSecret labels rest

end

mutual

/-- A public pure expression evaluates the same way in two environments that
agree on public variables. -/
theorem KernelPureExpr.eval_eq_of_public (cfg₁ cfg₂ : OperationalConfig)
    {labels : List (String × Bool)} {env₁ env₂ : LocalEnv}
    (hLow : EnvLowEq labels env₁ env₂) :
    ∀ (e : KernelPureExpr), e.secret labels = false →
      evalKernelPureExpr cfg₁ env₁ e = evalKernelPureExpr cfg₂ env₂ e
  | .literal _, _ => by simp [evalKernelPureExpr]
  | .var name, h => by
      have hPublic : isPublicVar labels name = true := by
        simpa [KernelPureExpr.secret] using h
      simp [evalKernelPureExpr, hLow name hPublic]
  | .unary op e, h => by
      simp only [KernelPureExpr.secret] at h
      simp only [evalKernelPureExpr, KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow e h]
  | .binary op lhs rhs, h => by
      simp only [KernelPureExpr.secret, Bool.or_eq_false_iff] at h
      simp only [evalKernelPureExpr, KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow lhs h.1,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow rhs h.2]
  | .select cond whenTrue whenFalse, h => by
      simp only [KernelPureExpr.secret, Bool.or_eq_false_iff] at h
      simp only [evalKernelPureExpr,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow cond h.1.1,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow whenTrue h.1.2,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow whenFalse h.2]
  | .structField base field, h => by
      simp only [KernelPureExpr.secret] at h
      simp only [evalKernelPureExpr, KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow base h]
  | .arrayIndex base index, h => by
      simp only [KernelPureExpr.secret, Bool.or_eq_false_iff] at h
      simp only [evalKernelPureExpr, KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow base h.1,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow index h.2]
  | .keccak256 parts, h => by
      simp only [KernelPureExpr.secret] at h
      simp only [evalKernelPureExpr,
        KernelPureExpr.evalList_eq_of_public cfg₁ cfg₂ hLow parts h]

theorem KernelPureExpr.evalList_eq_of_public (cfg₁ cfg₂ : OperationalConfig)
    {labels : List (String × Bool)} {env₁ env₂ : LocalEnv}
    (hLow : EnvLowEq labels env₁ env₂) :
    ∀ (parts : List KernelPureExpr), KernelPureExpr.listSecret labels parts = false →
      evalKernelPureExprList cfg₁ env₁ parts = evalKernelPureExprList cfg₂ env₂ parts
  | [], _ => by simp [evalKernelPureExprList]
  | p :: rest, h => by
      simp only [KernelPureExpr.listSecret, Bool.or_eq_false_iff] at h
      simp only [evalKernelPureExprList, KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow p h.1,
        KernelPureExpr.evalList_eq_of_public cfg₁ cfg₂ hLow rest h.2]

end

mutual

/-- A public kernel expression reads no storage and evaluates the same way in
two environments that agree on public variables, over any stores. -/
theorem KernelExpr.eval_eq_of_public (cfg₁ cfg₂ : OperationalConfig)
    {labels : List (String × Bool)} {env₁ env₂ : LocalEnv}
    (hLow : EnvLowEq labels env₁ env₂) :
    ∀ (e : KernelExpr), e.secret labels = false →
      evalKernelExpr cfg₁ env₁ e = evalKernelExpr cfg₂ env₂ e
  | .literal _, _ => by simp [evalKernelExpr]
  | .var name, h => by
      have hPublic : isPublicVar labels name = true := by
        simpa [KernelExpr.secret] using h
      simp [evalKernelExpr, hLow name hPublic]
  | .unary op e, h => by
      simp only [KernelExpr.secret] at h
      simp only [evalKernelExpr, KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow e h]
  | .binary op lhs rhs, h => by
      simp only [KernelExpr.secret, Bool.or_eq_false_iff] at h
      simp only [evalKernelExpr, KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow lhs h.1,
        KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow rhs h.2]
  | .select cond whenTrue whenFalse, h => by
      simp only [KernelExpr.secret, Bool.or_eq_false_iff] at h
      simp only [evalKernelExpr, KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow cond h.1.1,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow whenTrue h.1.2,
        KernelPureExpr.eval_eq_of_public cfg₁ cfg₂ hLow whenFalse h.2]
  | .cellGet _, h => by simp [KernelExpr.secret] at h
  | .arrayGet _ _, h => by simp [KernelExpr.secret] at h
  | .mapGet _ _, h => by simp [KernelExpr.secret] at h
  | .structField base field, h => by
      simp only [KernelExpr.secret] at h
      simp only [evalKernelExpr, KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow base h]
  | .arrayIndex base index, h => by
      simp only [KernelExpr.secret, Bool.or_eq_false_iff] at h
      simp only [evalKernelExpr, KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow base h.1,
        KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow index h.2]
  | .keccak256 parts, h => by
      simp only [KernelExpr.secret] at h
      simp only [evalKernelExpr, KernelExpr.evalList_eq_of_public cfg₁ cfg₂ hLow parts h]

theorem KernelExpr.evalList_eq_of_public (cfg₁ cfg₂ : OperationalConfig)
    {labels : List (String × Bool)} {env₁ env₂ : LocalEnv}
    (hLow : EnvLowEq labels env₁ env₂) :
    ∀ (parts : List KernelExpr), KernelExpr.listSecret labels parts = false →
      evalKernelExprList cfg₁ env₁ parts = evalKernelExprList cfg₂ env₂ parts
  | [], _ => by simp [evalKernelExprList]
  | p :: rest, h => by
      simp only [KernelExpr.listSecret, Bool.or_eq_false_iff] at h
      simp only [evalKernelExprList, KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow p h.1,
        KernelExpr.evalList_eq_of_public cfg₁ cfg₂ hLow rest h.2]

end

/-! ## Statement effects that do not depend on secrets -/

/-- `declare` and `assign` bind a variable; no other statement changes the
environment. -/
def KernelStatement.binds : KernelStatement → Bool
  | .declare _ _ _ => true
  | .assign _ _ => true
  | _ => false

theorem evalKernelStatement_env_of_not_binds (cfg : OperationalConfig) (env : LocalEnv)
    (oc : Outcome) (stmt : KernelStatement) (hNot : stmt.binds = false) :
    (evalKernelStatement cfg env oc stmt).2.1 = env := by
  cases stmt with
  | declare => simp [KernelStatement.binds] at hNot
  | assign => simp [KernelStatement.binds] at hNot
  | retStmt value =>
      cases value <;> simp only [evalKernelStatement] <;> (repeat' split) <;> rfl
  | _ => simp only [evalKernelStatement] <;> (repeat' split) <;> rfl

/-- A cell write changes the status only to a status that stops the body. -/
theorem evalKernelStatement_cellSet_status (cfg : OperationalConfig) (env : LocalEnv)
    (oc : Outcome) (objectId : Nat) (value : KernelExpr) (predicate : Option KernelExpr) :
    (evalKernelStatement cfg env oc (.cellSet objectId value predicate)).2.2.status =
        oc.status ∨
      (evalKernelStatement cfg env oc (.cellSet objectId value predicate)).2.2.status.continuesBody
        true = false := by
  simp only [evalKernelStatement]
  repeat' split
  all_goals first
    | exact Or.inl rfl
    | exact Or.inr rfl
    | exact Or.inr (evalKernelExpr_status_stops cfg env _ _ (by assumption))

/-- An array write changes the status only to a status that stops the body. -/
theorem evalKernelStatement_arraySet_status (cfg : OperationalConfig) (env : LocalEnv)
    (oc : Outcome) (objectId : Nat) (index value : KernelExpr)
    (predicate : Option KernelExpr) :
    (evalKernelStatement cfg env oc (.arraySet objectId index value predicate)).2.2.status =
        oc.status ∨
      (evalKernelStatement cfg env oc
        (.arraySet objectId index value predicate)).2.2.status.continuesBody true = false := by
  simp only [evalKernelStatement]
  repeat' split
  all_goals first
    | exact Or.inl rfl
    | exact Or.inr rfl
    | exact Or.inr (evalKernelExpr_status_stops cfg env _ _ (by assumption))
    | (right
       rename_i hShould
       repeat' split at hShould
       all_goals (cases hShould <;> first
         | rfl
         | exact evalKernelExpr_status_stops cfg env _ _ (by assumption)))

/-! ## The flow analysis -/

/-- Analysis state: variable labels, and whether the status or the return value
may depend on secrets so far. -/
structure FlowState where
  labels : List (String × Bool)
  statusSecret : Bool
  returnSecret : Bool

/-- Transfer function of one statement. -/
def KernelStatement.flow (S : FlowState) : KernelStatement → FlowState
  | .declare name _ value => { S with labels := labelInsert S.labels name (value.secret S.labels) }
  | .assign name value => { S with labels := labelInsert S.labels name (value.secret S.labels) }
  | .require cond => { S with statusSecret := S.statusSecret || cond.secret S.labels }
  | .abortIf cond => { S with statusSecret := S.statusSecret || cond.secret S.labels }
  | .cellSet _ _ _ => S
  | .arraySet _ _ _ _ => S
  | .mapPut _ _ _ _ => { S with statusSecret := true }
  | .retStmt none => S
  | .retStmt (some value) =>
      { S with returnSecret := S.returnSecret || value.secret S.labels }

/-- Transfer function of a body. -/
def KernelStatement.bodyFlow : FlowState → List KernelStatement → FlowState
  | S, [] => S
  | S, stmt :: rest => KernelStatement.bodyFlow (stmt.flow S) rest

theorem KernelStatement.flow_statusSecret_mono (S : FlowState) (stmt : KernelStatement)
    (h : (stmt.flow S).statusSecret = false) : S.statusSecret = false := by
  cases stmt with
  | retStmt value => cases value <;> simp_all [KernelStatement.flow]
  | _ => simp_all [KernelStatement.flow]

theorem KernelStatement.flow_returnSecret_mono (S : FlowState) (stmt : KernelStatement)
    (h : (stmt.flow S).returnSecret = false) : S.returnSecret = false := by
  cases stmt with
  | retStmt value => cases value <;> simp_all [KernelStatement.flow]
  | _ => simp_all [KernelStatement.flow]

theorem KernelStatement.bodyFlow_statusSecret_mono :
    ∀ (body : List KernelStatement) (S : FlowState),
      (KernelStatement.bodyFlow S body).statusSecret = false → S.statusSecret = false
  | [], _, h => h
  | stmt :: rest, S, h =>
      KernelStatement.flow_statusSecret_mono S stmt
        (KernelStatement.bodyFlow_statusSecret_mono rest (stmt.flow S) h)

theorem KernelStatement.bodyFlow_returnSecret_mono :
    ∀ (body : List KernelStatement) (S : FlowState),
      (KernelStatement.bodyFlow S body).returnSecret = false → S.returnSecret = false
  | [], _, h => h
  | stmt :: rest, S, h =>
      KernelStatement.flow_returnSecret_mono S stmt
        (KernelStatement.bodyFlow_returnSecret_mono rest (stmt.flow S) h)

/-! ## Noninterference of one statement -/

theorem evalKernelStatement_flow_ni {cfg₁ cfg₂ : OperationalConfig} {env₁ env₂ : LocalEnv}
    {oc₁ oc₂ : Outcome} {Γ Γ' : List (String × Ty)} {stmt : KernelStatement} {S : FlowState}
    (hEnv₁ : EnvConforms Γ env₁) (hEnv₂ : EnvConforms Γ env₂)
    (hStore₁ : StoreConforms cfg₁) (hStore₂ : StoreConforms cfg₂)
    (hState : cfg₂.contract.state = cfg₁.contract.state)
    (hTy : stmt.typeCheck Γ cfg₁.contract.state = some Γ')
    (hOc₁ : oc₁.status.continuesBody true = true) (hOc₂ : oc₂.status.continuesBody true = true)
    (hLow : EnvLowEq S.labels env₁ env₂)
    (hStatus : S.statusSecret = false → oc₁.status = oc₂.status)
    (hResult : S.returnSecret = false → oc₁.publicResult = oc₂.publicResult) :
    EnvLowEq (stmt.flow S).labels (evalKernelStatement cfg₁ env₁ oc₁ stmt).2.1
        (evalKernelStatement cfg₂ env₂ oc₂ stmt).2.1 ∧
      ((stmt.flow S).statusSecret = false →
        (evalKernelStatement cfg₁ env₁ oc₁ stmt).2.2.status =
          (evalKernelStatement cfg₂ env₂ oc₂ stmt).2.2.status) ∧
      ((stmt.flow S).returnSecret = false →
        (evalKernelStatement cfg₁ env₁ oc₁ stmt).2.2.publicResult =
          (evalKernelStatement cfg₂ env₂ oc₂ stmt).2.2.publicResult) := by
  have hTy₂ : stmt.typeCheck Γ cfg₂.contract.state = some Γ' := by rw [hState]; exact hTy
  -- Both runs of a well-typed statement continue.
  have hCont₁ := (evalKernelStatement_wellTyped (oc := oc₁) hEnv₁ hStore₁ hTy hOc₁).1
  have hCont₂ := (evalKernelStatement_wellTyped (oc := oc₂) hEnv₂ hStore₂ hTy₂ hOc₂).1
  cases stmt with
  | declare name ty value =>
      simp only [KernelStatement.typeCheck] at hTy hTy₂
      split at hTy
      · rename_i vty hv
        have hv₂ : value.typeOf? Γ cfg₂.contract.state = some vty := by rw [hState]; exact hv
        obtain ⟨v₁, hEval₁, _⟩ := KernelExpr.eval_of_typeOf? hEnv₁ hStore₁ value hv
        obtain ⟨v₂, hEval₂, _⟩ := KernelExpr.eval_of_typeOf? hEnv₂ hStore₂ value hv₂
        simp only [evalKernelStatement, hEval₁, hEval₂, KernelStatement.flow]
        refine ⟨hLow.insert name _ (fun hPublic => ?_), hStatus, hResult⟩
        have := KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow value hPublic
        rw [hEval₁, hEval₂] at this
        cases this
        rfl
      · cases hTy
  | assign name value =>
      simp only [KernelStatement.typeCheck] at hTy hTy₂
      split at hTy
      · rename_i ty vty hLookup hv
        have hv₂ : value.typeOf? Γ cfg₂.contract.state = some vty := by rw [hState]; exact hv
        obtain ⟨v₁, hEval₁, _⟩ := KernelExpr.eval_of_typeOf? hEnv₁ hStore₁ value hv
        obtain ⟨v₂, hEval₂, _⟩ := KernelExpr.eval_of_typeOf? hEnv₂ hStore₂ value hv₂
        simp only [evalKernelStatement, hEval₁, hEval₂, KernelStatement.flow]
        refine ⟨hLow.insert name _ (fun hPublic => ?_), hStatus, hResult⟩
        have := KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow value hPublic
        rw [hEval₁, hEval₂] at this
        cases this
        rfl
      · cases hTy
  | require cond =>
      simp only [KernelStatement.typeCheck] at hTy hTy₂
      split at hTy
      · rename_i cty hc
        split at hTy
        · rename_i hBool
          have hc₂ : cond.typeOf? Γ cfg₂.contract.state = some cty := by rw [hState]; exact hc
          obtain ⟨c₁, hEval₁, hct₁⟩ := KernelExpr.eval_of_typeOf? hEnv₁ hStore₁ cond hc
          obtain ⟨c₂, hEval₂, hct₂⟩ := KernelExpr.eval_of_typeOf? hEnv₂ hStore₂ cond hc₂
          obtain ⟨b₁, rfl⟩ := hct₁.bool_inv hBool
          obtain ⟨b₂, rfl⟩ := hct₂.bool_inv hBool
          refine ⟨?_, fun hSecret => ?_, ?_⟩
          · cases b₁ <;> cases b₂ <;> simp only [evalKernelStatement, hEval₁, hEval₂] <;>
              exact hLow
          · simp only [KernelStatement.flow, Bool.or_eq_false_iff] at hSecret
            have := KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow cond hSecret.2
            rw [hEval₁, hEval₂] at this
            cases this
            cases b₁ <;> simp only [evalKernelStatement, hEval₁, hEval₂] <;>
              first | rfl | exact hStatus hSecret.1
          · intro hRet
            cases b₁ <;> cases b₂ <;> simp only [evalKernelStatement, hEval₁, hEval₂] <;>
              exact hResult hRet
        · cases hTy
      · cases hTy
  | abortIf cond =>
      simp only [KernelStatement.typeCheck] at hTy hTy₂
      split at hTy
      · rename_i cty hc
        split at hTy
        · rename_i hBool
          have hc₂ : cond.typeOf? Γ cfg₂.contract.state = some cty := by rw [hState]; exact hc
          obtain ⟨c₁, hEval₁, hct₁⟩ := KernelExpr.eval_of_typeOf? hEnv₁ hStore₁ cond hc
          obtain ⟨c₂, hEval₂, hct₂⟩ := KernelExpr.eval_of_typeOf? hEnv₂ hStore₂ cond hc₂
          obtain ⟨b₁, rfl⟩ := hct₁.bool_inv hBool
          obtain ⟨b₂, rfl⟩ := hct₂.bool_inv hBool
          refine ⟨?_, fun hSecret => ?_, ?_⟩
          · cases b₁ <;> cases b₂ <;> simp only [evalKernelStatement, hEval₁, hEval₂] <;>
              exact hLow
          · simp only [KernelStatement.flow, Bool.or_eq_false_iff] at hSecret
            have := KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow cond hSecret.2
            rw [hEval₁, hEval₂] at this
            cases this
            cases b₁ <;> simp only [evalKernelStatement, hEval₁, hEval₂] <;>
              first | rfl | exact hStatus hSecret.1
          · intro hRet
            cases b₁ <;> cases b₂ <;> simp only [evalKernelStatement, hEval₁, hEval₂] <;>
              exact hResult hRet
        · cases hTy
      · cases hTy
  | cellSet objectId value predicate =>
      have hEnvEq₁ := evalKernelStatement_env_of_not_binds cfg₁ env₁ oc₁
        (.cellSet objectId value predicate) rfl
      have hEnvEq₂ := evalKernelStatement_env_of_not_binds cfg₂ env₂ oc₂
        (.cellSet objectId value predicate) rfl
      have hPub₁ := evalKernelStatement_publicResult_of_not_return cfg₁ env₁ oc₁
        (.cellSet objectId value predicate) rfl
      have hPub₂ := evalKernelStatement_publicResult_of_not_return cfg₂ env₂ oc₂
        (.cellSet objectId value predicate) rfl
      have hSt₁ : (evalKernelStatement cfg₁ env₁ oc₁
          (.cellSet objectId value predicate)).2.2.status = oc₁.status := by
        rcases evalKernelStatement_cellSet_status cfg₁ env₁ oc₁ objectId value predicate
          with h | h
        · exact h
        · rw [h] at hCont₁; cases hCont₁
      have hSt₂ : (evalKernelStatement cfg₂ env₂ oc₂
          (.cellSet objectId value predicate)).2.2.status = oc₂.status := by
        rcases evalKernelStatement_cellSet_status cfg₂ env₂ oc₂ objectId value predicate
          with h | h
        · exact h
        · rw [h] at hCont₂; cases hCont₂
      simp only [KernelStatement.flow]
      rw [hEnvEq₁, hEnvEq₂, hSt₁, hSt₂, hPub₁, hPub₂]
      exact ⟨hLow, hStatus, hResult⟩
  | arraySet objectId index value predicate =>
      have hEnvEq₁ := evalKernelStatement_env_of_not_binds cfg₁ env₁ oc₁
        (.arraySet objectId index value predicate) rfl
      have hEnvEq₂ := evalKernelStatement_env_of_not_binds cfg₂ env₂ oc₂
        (.arraySet objectId index value predicate) rfl
      have hPub₁ := evalKernelStatement_publicResult_of_not_return cfg₁ env₁ oc₁
        (.arraySet objectId index value predicate) rfl
      have hPub₂ := evalKernelStatement_publicResult_of_not_return cfg₂ env₂ oc₂
        (.arraySet objectId index value predicate) rfl
      have hSt₁ : (evalKernelStatement cfg₁ env₁ oc₁
          (.arraySet objectId index value predicate)).2.2.status = oc₁.status := by
        rcases evalKernelStatement_arraySet_status cfg₁ env₁ oc₁ objectId index value predicate
          with h | h
        · exact h
        · rw [h] at hCont₁; cases hCont₁
      have hSt₂ : (evalKernelStatement cfg₂ env₂ oc₂
          (.arraySet objectId index value predicate)).2.2.status = oc₂.status := by
        rcases evalKernelStatement_arraySet_status cfg₂ env₂ oc₂ objectId index value predicate
          with h | h
        · exact h
        · rw [h] at hCont₂; cases hCont₂
      simp only [KernelStatement.flow]
      rw [hEnvEq₁, hEnvEq₂, hSt₁, hSt₂, hPub₁, hPub₂]
      exact ⟨hLow, hStatus, hResult⟩
  | mapPut objectId key value predicate =>
      have hEnvEq₁ := evalKernelStatement_env_of_not_binds cfg₁ env₁ oc₁
        (.mapPut objectId key value predicate) rfl
      have hEnvEq₂ := evalKernelStatement_env_of_not_binds cfg₂ env₂ oc₂
        (.mapPut objectId key value predicate) rfl
      have hPub₁ := evalKernelStatement_publicResult_of_not_return cfg₁ env₁ oc₁
        (.mapPut objectId key value predicate) rfl
      have hPub₂ := evalKernelStatement_publicResult_of_not_return cfg₂ env₂ oc₂
        (.mapPut objectId key value predicate) rfl
      simp only [KernelStatement.flow]
      rw [hEnvEq₁, hEnvEq₂, hPub₁, hPub₂]
      exact ⟨hLow, (fun h => by cases h), hResult⟩
  | retStmt value =>
      cases value with
      | none =>
          simp only [evalKernelStatement, KernelStatement.flow]
          exact ⟨hLow, hStatus, hResult⟩
      | some value =>
          simp only [KernelStatement.typeCheck] at hTy hTy₂
          split at hTy
          · rename_i vty hv
            have hv₂ : value.typeOf? Γ cfg₂.contract.state = some vty := by
              rw [hState]; exact hv
            obtain ⟨v₁, hEval₁, _⟩ := KernelExpr.eval_of_typeOf? hEnv₁ hStore₁ value hv
            obtain ⟨v₂, hEval₂, _⟩ := KernelExpr.eval_of_typeOf? hEnv₂ hStore₂ value hv₂
            simp only [evalKernelStatement, hEval₁, hEval₂, KernelStatement.flow]
            refine ⟨hLow, hStatus, fun hSecret => ?_⟩
            simp only [Bool.or_eq_false_iff] at hSecret
            have := KernelExpr.eval_eq_of_public cfg₁ cfg₂ hLow value hSecret.2
            rw [hEval₁, hEval₂] at this
            cases this
            rfl
          · cases hTy

/-! ## Noninterference of bodies and programs -/

theorem evalKernelBody_flow_ni :
    ∀ (body : List KernelStatement) {cfg₁ cfg₂ : OperationalConfig} {env₁ env₂ : LocalEnv}
      {oc₁ oc₂ : Outcome} {Γ : List (String × Ty)} {S : FlowState},
      EnvConforms Γ env₁ → EnvConforms Γ env₂ → StoreConforms cfg₁ → StoreConforms cfg₂ →
      cfg₂.contract.state = cfg₁.contract.state →
      KernelStatement.bodyTyped Γ cfg₁.contract.state body = true →
      KernelStatement.returnsOnlyLast body = true →
      oc₁.status.continuesBody true = true → oc₂.status.continuesBody true = true →
      oc₁.publicResult = none → oc₂.publicResult = none →
      EnvLowEq S.labels env₁ env₂ →
      (S.statusSecret = false → oc₁.status = oc₂.status) →
      ((KernelStatement.bodyFlow S body).statusSecret = false →
          (evalKernelBody cfg₁ env₁ oc₁ body).2.2.status =
            (evalKernelBody cfg₂ env₂ oc₂ body).2.2.status) ∧
        ((KernelStatement.bodyFlow S body).returnSecret = false →
          (evalKernelBody cfg₁ env₁ oc₁ body).2.2.publicResult =
            (evalKernelBody cfg₂ env₂ oc₂ body).2.2.publicResult)
  | [], _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hPub₁, hPub₂, _, hStatus => by
      simp only [evalKernelBody, KernelStatement.bodyFlow]
      exact ⟨hStatus, fun _ => by rw [hPub₁, hPub₂]⟩
  | stmt :: rest, cfg₁, cfg₂, env₁, env₂, oc₁, oc₂, Γ, S, hEnv₁, hEnv₂, hStore₁, hStore₂,
      hState, hTy, hRet, hOc₁, hOc₂, hPub₁, hPub₂, hLow, hStatus => by
      simp only [KernelStatement.bodyTyped] at hTy
      split at hTy
      · rename_i Γ' hStmt
        have hStmt₂ : stmt.typeCheck Γ cfg₂.contract.state = some Γ' := by
          rw [hState]; exact hStmt
        obtain ⟨hCont₁, hEnv₁', hStore₁', hContract₁⟩ :=
          evalKernelStatement_wellTyped (oc := oc₁) hEnv₁ hStore₁ hStmt hOc₁
        obtain ⟨hCont₂, hEnv₂', hStore₂', hContract₂⟩ :=
          evalKernelStatement_wellTyped (oc := oc₂) hEnv₂ hStore₂ hStmt₂ hOc₂
        obtain ⟨hLow', hStatus', hResult'⟩ :=
          evalKernelStatement_flow_ni (oc₁ := oc₁) (oc₂ := oc₂) (S := S) hEnv₁ hEnv₂ hStore₁
            hStore₂ hState hStmt hOc₁ hOc₂ hLow hStatus (fun _ => by rw [hPub₁, hPub₂])
        cases rest with
        | nil =>
            simp only [KernelStatement.bodyFlow]
            rw [evalKernelBody, evalKernelBody]
            generalize evalKernelStatement cfg₁ env₁ oc₁ stmt = step₁ at *
            generalize evalKernelStatement cfg₂ env₂ oc₂ stmt = step₂ at *
            obtain ⟨c₁, e₁, o₁⟩ := step₁
            obtain ⟨c₂, e₂, o₂⟩ := step₂
            simp only at hCont₁ hCont₂ hStatus' hResult' ⊢
            simp only [hCont₁, hCont₂, ↓reduceIte, evalKernelBody, ite_self]
            exact ⟨hStatus', hResult'⟩
        | cons next rest' =>
            have hNotRet : stmt.isReturn = false := by
              simp only [KernelStatement.returnsOnlyLast, Bool.and_eq_true,
                Bool.not_eq_true'] at hRet
              exact hRet.1
            have hRet' : KernelStatement.returnsOnlyLast (next :: rest') = true := by
              simp only [KernelStatement.returnsOnlyLast, Bool.and_eq_true] at hRet
              exact hRet.2
            have hPubStmt₁ :=
              evalKernelStatement_publicResult_of_not_return cfg₁ env₁ oc₁ stmt hNotRet
            have hPubStmt₂ :=
              evalKernelStatement_publicResult_of_not_return cfg₂ env₂ oc₂ stmt hNotRet
            simp only [KernelStatement.bodyFlow]
            rw [evalKernelBody, evalKernelBody]
            generalize evalKernelStatement cfg₁ env₁ oc₁ stmt = step₁ at *
            generalize evalKernelStatement cfg₂ env₂ oc₂ stmt = step₂ at *
            obtain ⟨c₁, e₁, o₁⟩ := step₁
            obtain ⟨c₂, e₂, o₂⟩ := step₂
            simp only at hCont₁ hCont₂ hEnv₁' hEnv₂' hStore₁' hStore₂' hContract₁ hContract₂
            simp only at hLow' hStatus' hPubStmt₁ hPubStmt₂ ⊢
            have hPub₁' : o₁.publicResult = none := by rw [hPubStmt₁, hPub₁]
            have hPub₂' : o₂.publicResult = none := by rw [hPubStmt₂, hPub₂]
            simp only [hCont₁, hCont₂, hPub₁', hPub₂', Option.isSome_none, Bool.false_eq_true,
              ↓reduceIte]
            have hState' : c₂.contract.state = c₁.contract.state := by
              rw [hContract₁, hContract₂, hState]
            exact evalKernelBody_flow_ni (next :: rest') hEnv₁' hEnv₂' hStore₁' hStore₂' hState'
              (by rw [hContract₁]; exact hTy) hRet' hCont₁ hCont₂ hPub₁' hPub₂' hLow' hStatus'
      · cases hTy

/-- Labels of a program's parameters, bound in the order
`KernelProgram.initialEnv` binds them: secret exactly at `secretArgs`. -/
def KernelProgram.paramLabels (kp : KernelProgram) : List (String × Bool) :=
  ((List.range kp.params.length).zip kp.params).foldl
    (fun labels entry => labelInsert labels entry.snd.name (kp.secretArgs.contains entry.fst)) []

/-- The analysis of a whole program. -/
def KernelProgram.flowSummary (kp : KernelProgram) : FlowState :=
  KernelStatement.bodyFlow
    { labels := kp.paramLabels, statusSecret := false, returnSecret := false } kp.body

/-- Two argument vectors agree at every public parameter position. -/
def PublicArgsAgree (kp : KernelProgram) (args₁ args₂ : List Value) : Prop :=
  ∀ index, kp.secretArgs.contains index = false → args₁[index]? = args₂[index]?

theorem paramBindings_lowEq (secretArgs : List Nat) :
    ∀ (params : List Param) (args₁ args₂ : List Value) (k : Nat)
      (labels : List (String × Bool)) (env₁ env₂ : LocalEnv),
      args₁.length = params.length → args₂.length = params.length →
      EnvLowEq labels env₁ env₂ →
      (∀ i, secretArgs.contains (k + i) = false → args₁[i]? = args₂[i]?) →
      EnvLowEq
        (((List.range' k params.length).zip params).foldl
          (fun labels entry => labelInsert labels entry.snd.name
            (secretArgs.contains entry.fst)) labels)
        ((params.zip args₁).foldl
          (fun env entry => LocalEnv.insert env entry.fst.name entry.snd) env₁)
        ((params.zip args₂).foldl
          (fun env entry => LocalEnv.insert env entry.fst.name entry.snd) env₂)
  | [], [], [], _, _, _, _, _, _, hLow, _ => by simpa using hLow
  | p :: params, a₁ :: args₁, a₂ :: args₂, k, labels, env₁, env₂, hLen₁, hLen₂, hLow,
      hArgs => by
      simp only [List.length_cons, List.range'_succ, List.zip_cons_cons, List.foldl_cons]
      refine paramBindings_lowEq secretArgs params args₁ args₂ (k + 1) _ _ _
        (by simpa using hLen₁) (by simpa using hLen₂)
        (hLow.insert p.name (secretArgs.contains k) (fun hPublic => ?_)) (fun i hi => ?_)
      · have := hArgs 0 (by simpa using hPublic)
        simpa using this
      · have := hArgs (i + 1) (by rw [← Nat.add_assoc, Nat.add_right_comm]; exact hi)
        simpa using this
  | [], _ :: _, _, _, _, _, _, hLen₁, _, _, _ => by simp at hLen₁
  | [], [], _ :: _, _, _, _, _, _, hLen₂, _, _ => by simp at hLen₂
  | _ :: _, [], _, _, _, _, _, hLen₁, _, _, _ => by simp at hLen₁
  | _ :: _, _ :: _, [], _, _, _, _, _, hLen₂, _, _ => by simp at hLen₂

/-- Information-flow noninterference for admitted kernel programs. Two runs of
a well-typed program whose only return is its last statement, over stores that
conform to the same state layout, with arguments of the parameter types that
agree at public parameter positions, end with the same status when the
analysis reports a public status, and return the same value when it reports a
public return. -/
theorem evalKernelProgram_flow_ni (kp : KernelProgram) (cfg₁ cfg₂ : OperationalConfig)
    (hTy : kp.wellTyped cfg₁.contract.state = true)
    (hState : cfg₂.contract.state = cfg₁.contract.state)
    (hRet : KernelStatement.returnsOnlyLast kp.body = true)
    (hArgs₁ : ArgsConform kp.params cfg₁.declaredArgs)
    (hArgs₂ : ArgsConform kp.params cfg₂.declaredArgs)
    (hStore₁ : StoreConforms cfg₁) (hStore₂ : StoreConforms cfg₂)
    (hPublic : PublicArgsAgree kp cfg₁.declaredArgs cfg₂.declaredArgs) :
    (kp.flowSummary.statusSecret = false →
        (evalKernelProgram kp cfg₁).status = (evalKernelProgram kp cfg₂).status) ∧
      (kp.flowSummary.returnSecret = false →
        (evalKernelProgram kp cfg₁).publicResult =
          (evalKernelProgram kp cfg₂).publicResult) := by
  obtain ⟨env₁, hEnvEq₁, hEnv₁⟩ := kp.initialEnv_conforms cfg₁.declaredArgs hArgs₁
  obtain ⟨env₂, hEnvEq₂, hEnv₂⟩ := kp.initialEnv_conforms cfg₂.declaredArgs hArgs₂
  have hEnvForm₁ := hEnvEq₁
  have hEnvForm₂ := hEnvEq₂
  simp only [KernelProgram.initialEnv, hArgs₁.length_eq, hArgs₂.length_eq, ↓reduceIte,
    Option.some.injEq] at hEnvForm₁ hEnvForm₂
  have hLow : EnvLowEq kp.paramLabels env₁ env₂ := by
    rw [← hEnvForm₁, ← hEnvForm₂]
    unfold KernelProgram.paramLabels
    rw [List.range_eq_range']
    exact paramBindings_lowEq kp.secretArgs kp.params cfg₁.declaredArgs cfg₂.declaredArgs 0
      [] [] [] hArgs₁.length_eq hArgs₂.length_eq
      (fun name h => by simp [isPublicVar, labelLookup] at h)
      (fun i hi => hPublic i (by simpa using hi))
  have hTy₂ : kp.wellTyped cfg₂.contract.state = true := by rw [hState]; exact hTy
  have hBody := evalKernelBody_flow_ni kp.body (oc₁ := Outcome.empty) (oc₂ := Outcome.empty)
    (S := { labels := kp.paramLabels, statusSecret := false, returnSecret := false })
    hEnv₁ hEnv₂ hStore₁ hStore₂ hState hTy hRet rfl rfl rfl rfl hLow (fun _ => rfl)
  unfold evalKernelProgram
  simp only [hEnvEq₁, hEnvEq₂]
  generalize evalKernelBody cfg₁ env₁ Outcome.empty kp.body = result₁ at *
  generalize evalKernelBody cfg₂ env₂ Outcome.empty kp.body = result₂ at *
  obtain ⟨c₁, e₁, o₁⟩ := result₁
  obtain ⟨c₂, e₂, o₂⟩ := result₂
  simpa [Outcome.withPublicStateTransition, KernelProgram.flowSummary] using hBody

/-! ## Public arguments from the argument layout -/

/-- The declared-order argument vector of a run has one entry per parameter, and
its public entries (those not at `secretArgs`) are the run's public arguments,
as `OperationalConfig.DeclaredArgumentLayoutMatches` requires for compiled
functions. -/
def KernelArgumentLayout (kp : KernelProgram) (cfg : OperationalConfig) : Prop :=
  cfg.declaredArgs.length = kp.params.length ∧
    cfg.publicArgs = declaredPublicArgsBySecretIndices kp.secretArgs cfg.declaredArgs

theorem publicEntries_agree (secretIndices : List Nat) :
    ∀ (k : Nat) (args₁ args₂ : List Value), args₁.length = args₂.length →
      ((List.range' k args₁.length).zip args₁).filterMap
          (fun entry => if secretIndices.contains entry.fst then none else some entry.snd) =
        ((List.range' k args₂.length).zip args₂).filterMap
          (fun entry => if secretIndices.contains entry.fst then none else some entry.snd) →
      ∀ i, secretIndices.contains (k + i) = false → args₁[i]? = args₂[i]?
  | _, [], [], _, _, _, _ => rfl
  | k, x :: xs, y :: ys, hLen, hEq, i, hi => by
      have hLen' : xs.length = ys.length := by simpa using hLen
      simp only [List.length_cons, List.range'_succ, List.zip_cons_cons,
        List.filterMap_cons] at hEq
      cases hk : secretIndices.contains k with
      | false =>
          simp only [hk, Bool.false_eq_true, ↓reduceIte, List.cons.injEq] at hEq
          cases i with
          | zero => simp [hEq.1]
          | succ i =>
              have := publicEntries_agree secretIndices (k + 1) xs ys hLen' hEq.2 i
                (by rw [Nat.add_assoc, Nat.add_comm 1 i]; exact hi)
              simpa using this
      | true =>
          simp only [hk, ↓reduceIte] at hEq
          cases i with
          | zero =>
              have hMem : k ∈ secretIndices := by simpa using hk
              have hNot : ¬ k ∈ secretIndices := by simpa using hi
              exact absurd hMem hNot
          | succ i =>
              have := publicEntries_agree secretIndices (k + 1) xs ys hLen' hEq i
                (by rw [Nat.add_assoc, Nat.add_comm 1 i]; exact hi)
              simpa using this
  | _, [], _ :: _, hLen, _, _, _ => by simp at hLen
  | _, _ :: _, [], hLen, _, _, _ => by simp at hLen

/-- Two runs with the same public arguments and the declared argument layout
agree on every argument at a public parameter position. -/
theorem publicArgsAgree_of_layout {kp : KernelProgram} {cfg₁ cfg₂ : OperationalConfig}
    (h₁ : KernelArgumentLayout kp cfg₁) (h₂ : KernelArgumentLayout kp cfg₂)
    (hPublic : cfg₁.publicArgs = cfg₂.publicArgs) :
    PublicArgsAgree kp cfg₁.declaredArgs cfg₂.declaredArgs := by
  intro index hIndex
  have hLen : cfg₁.declaredArgs.length = cfg₂.declaredArgs.length := by rw [h₁.1, h₂.1]
  have hEq :
      declaredPublicArgsBySecretIndices kp.secretArgs cfg₁.declaredArgs =
        declaredPublicArgsBySecretIndices kp.secretArgs cfg₂.declaredArgs := by
    rw [← h₁.2, ← h₂.2, hPublic]
  unfold declaredPublicArgsBySecretIndices at hEq
  rw [List.range_eq_range', List.range_eq_range'] at hEq
  exact publicEntries_agree kp.secretArgs 0 _ _ hLen hEq index (by simpa using hIndex)

/-! ## Examples

The analysis agrees with the benchmark policies: the classifier's status is
public (it writes a cell, and a cell write cannot abort); a mixer withdrawal's
status is secret (it tests the secret balance and writes a map) and so is its
return (the secret amount); a function returning a public argument has a public
return. -/

private def classifyProgram : KernelProgram :=
  { entrypointId := "classify(uint256)"
  , params := [⟨"secret", .scalar (.uint 256)⟩]
  , returnType := none
  , secretArgs := [0]
  , body :=
      [ .declare "bit" (.scalar (.uint 256)) (.binary .bitAnd (.var "secret") (.literal (.uint 1)))
      , .cellSet 1 (.var "bit") none ] }

example : classifyProgram.flowSummary.statusSecret = false := by decide

private def withdrawProgram : KernelProgram :=
  { entrypointId := "withdraw(bytes32,uint256)"
  , params := [⟨"commitment", .scalar .bytes32⟩, ⟨"amount", .scalar (.uint 256)⟩]
  , returnType := some (.scalar (.uint 256))
  , secretArgs := [0, 1]
  , body :=
      [ .declare "oldBalance" (.scalar (.uint 256)) (.mapGet 0 (.var "commitment"))
      , .require (.binary .gte (.var "oldBalance") (.var "amount"))
      , .mapPut 0 (.var "commitment") (.binary .sub (.var "oldBalance") (.var "amount")) none
      , .retStmt (some (.var "amount")) ] }

example : withdrawProgram.flowSummary.statusSecret = true := by decide

example : withdrawProgram.flowSummary.returnSecret = true := by decide

private def echoProgram : KernelProgram :=
  { entrypointId := "echo(uint256,uint256)"
  , params := [⟨"shown", .scalar (.uint 256)⟩, ⟨"hidden", .scalar (.uint 256)⟩]
  , returnType := some (.scalar (.uint 256))
  , secretArgs := [1]
  , body :=
      [ .require (.binary .lt (.var "shown") (.literal (.uint 100)))
      , .cellSet 1 (.var "hidden") none
      , .retStmt (some (.binary .add (.var "shown") (.literal (.uint 1)))) ] }

example : echoProgram.flowSummary.statusSecret = false := by decide

example : echoProgram.flowSummary.returnSecret = false := by decide

end UOToolchain.IR
