import UOToolchain.KernelDsl

namespace UOToolchain.IR

/-!
# Kernel DSL typing and error freedom

A1 shows that every run of a confidential kernel program that hits no
evaluation error emits the program's static kernel-step schedule
(`evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_continues`). This
module discharges the "no evaluation error" premise for well-typed programs: a
type checker for the kernel DSL, and the theorem that a well-typed program run
on inputs of its parameter types, over a store that conforms to the contract's
state layout, never reports `evalError` or `unsupported`.

Typing mirrors exactly the conditions under which the evaluator succeeds.
Indices into local or parameter arrays must be compile-time constants below
the array's length, which is the admission rule `uo-solc` enforces for
confidential entrypoints; state-array and map reads default to the zero value
and need no such restriction.
-/

/-! ## Types -/

mutual

/-- Boolean equality on types. -/
def Ty.beq : Ty → Ty → Bool
  | .scalar a, .scalar b => decide (a = b)
  | .structTy fs, .structTy gs => Ty.fieldsBeq fs gs
  | .array e n, .array f m => Ty.beq e f && decide (n = m)
  | _, _ => false

/-- Boolean equality on struct field types. -/
def Ty.fieldsBeq : List (String × Ty) → List (String × Ty) → Bool
  | [], [] => true
  | (a, t) :: fs, (b, u) :: gs => decide (a = b) && Ty.beq t u && Ty.fieldsBeq fs gs
  | _, _ => false

end

mutual

theorem Ty.eq_of_beq : ∀ {a b : Ty}, Ty.beq a b = true → a = b
  | .scalar a, .scalar b, h => by
      simp only [Ty.beq, decide_eq_true_eq] at h
      rw [h]
  | .structTy fs, .structTy gs, h => by
      rw [Ty.fields_eq_of_fieldsBeq (fs := fs) (gs := gs) (by simpa only [Ty.beq] using h)]
  | .array e n, .array f m, h => by
      simp only [Ty.beq, Bool.and_eq_true, decide_eq_true_eq] at h
      rw [Ty.eq_of_beq h.1, h.2]
  | .scalar _, .structTy _, h => by simp [Ty.beq] at h
  | .scalar _, .array _ _, h => by simp [Ty.beq] at h
  | .structTy _, .scalar _, h => by simp [Ty.beq] at h
  | .structTy _, .array _ _, h => by simp [Ty.beq] at h
  | .array _ _, .scalar _, h => by simp [Ty.beq] at h
  | .array _ _, .structTy _, h => by simp [Ty.beq] at h

theorem Ty.fields_eq_of_fieldsBeq :
    ∀ {fs gs : List (String × Ty)}, Ty.fieldsBeq fs gs = true → fs = gs
  | [], [], _ => rfl
  | (a, t) :: fs, (b, u) :: gs, h => by
      simp only [Ty.fieldsBeq, Bool.and_eq_true, decide_eq_true_eq] at h
      rw [h.1.1, Ty.eq_of_beq h.1.2, Ty.fields_eq_of_fieldsBeq h.2]
  | [], _ :: _, h => by simp [Ty.fieldsBeq] at h
  | _ :: _, [], h => by simp [Ty.fieldsBeq] at h

end

/-- Type of a named struct field. -/
def Ty.fieldType? (tys : List (String × Ty)) (field : String) : Option Ty :=
  match tys.find? (fun entry => entry.fst = field) with
  | some (_, ty) => some ty
  | none => none

/-! ## Value typing

Uint payloads are not range-checked: every uint operation normalizes into the
`uint256` domain. -/

inductive ValueHasTy : Value → Ty → Prop
  | bool (b : Bool) : ValueHasTy (.bool b) (.scalar .bool)
  | uint (n w : Nat) : ValueHasTy (.uint n) (.scalar (.uint w))
  | bytes32 (bytes : List UInt8) : ValueHasTy (.bytes32 bytes) (.scalar .bytes32)
  | address (bytes : List UInt8) : ValueHasTy (.address bytes) (.scalar .address)
  | structValue (fields : List (String × Value)) (tys : List (String × Ty))
      (hPresent : ∀ field ty, Ty.fieldType? tys field = some ty →
        (Value.structField? fields field).isSome = true)
      (hTyped : ∀ field ty value, Ty.fieldType? tys field = some ty →
        Value.structField? fields field = some value → ValueHasTy value ty) :
      ValueHasTy (.structValue fields) (.structTy tys)
  | array (values : List Value) (elem : Ty) (size : Nat)
      (hLength : values.length = size)
      (hElems : ∀ value ∈ values, ValueHasTy value elem) :
      ValueHasTy (.array values) (.array elem size)

theorem ValueHasTy.of_beq {value : Value} {ty ty' : Ty}
    (h : ValueHasTy value ty) (hBeq : Ty.beq ty ty' = true) : ValueHasTy value ty' := by
  rw [← Ty.eq_of_beq hBeq]
  exact h

theorem Ty.fieldType?_zeroStructFields :
    ∀ (tys : List (String × Ty)) (field : String) (ty : Ty),
      Ty.fieldType? tys field = some ty →
        Value.structField? (Value.zeroStructFields tys) field =
          some (Value.zeroForType ty)
  | [], field, ty, h => by simp [Ty.fieldType?] at h
  | (name, t) :: rest, field, ty, h => by
      by_cases hName : name = field
      · subst hName
        simp [Ty.fieldType?] at h
        subst h
        simp [Value.structField?, Value.zeroStructFields]
      · have hRest : Ty.fieldType? rest field = some ty := by
          simpa [Ty.fieldType?, hName] using h
        have := Ty.fieldType?_zeroStructFields rest field ty hRest
        simpa [Value.structField?, Value.zeroStructFields, hName] using this

mutual

/-- `Value.zeroForType ty` has type `ty`. -/
theorem Value.zeroForType_hasTy : ∀ (ty : Ty), ValueHasTy (Value.zeroForType ty) ty
  | .scalar .bool => by simp only [Value.zeroForType]; exact .bool false
  | .scalar (.uint w) => by simp only [Value.zeroForType]; exact .uint 0 w
  | .scalar .bytes32 => by simp only [Value.zeroForType]; exact .bytes32 _
  | .scalar .address => by simp only [Value.zeroForType]; exact .address _
  | .structTy tys => by
      simp only [Value.zeroForType]
      refine .structValue _ _ ?_ ?_
      · intro field ty hTy
        rw [Ty.fieldType?_zeroStructFields tys field ty hTy]
        rfl
      · intro field ty value hTy hField
        rw [Ty.fieldType?_zeroStructFields tys field ty hTy] at hField
        cases hField
        exact Value.zeroStructFields_hasTy tys field ty hTy
  | .array elem size => by
      simp only [Value.zeroForType]
      refine .array _ _ _ (by simp) ?_
      intro value hMem
      rw [List.eq_of_mem_replicate hMem]
      exact Value.zeroForType_hasTy elem

theorem Value.zeroStructFields_hasTy :
    ∀ (tys : List (String × Ty)) (field : String) (ty : Ty),
      Ty.fieldType? tys field = some ty → ValueHasTy (Value.zeroForType ty) ty
  | [], _, _, h => by simp [Ty.fieldType?] at h
  | (name, t) :: rest, field, ty, h => by
      by_cases hName : name = field
      · subst hName
        simp [Ty.fieldType?] at h
        subst h
        exact Value.zeroForType_hasTy t
      · exact Value.zeroStructFields_hasTy rest field ty
          (by simpa [Ty.fieldType?, hName] using h)

end

/-! ## Inversion lemmas -/

def Ty.isUint : Ty → Bool
  | .scalar (.uint _) => true
  | _ => false

def Ty.isBool : Ty → Bool
  | .scalar .bool => true
  | _ => false

theorem ValueHasTy.uint_inv {value : Value} {ty : Ty}
    (h : ValueHasTy value ty) (hTy : ty.isUint = true) : ∃ n, value = .uint n := by
  cases h <;> simp [Ty.isUint] at hTy
  exact ⟨_, rfl⟩

theorem ValueHasTy.bool_inv {value : Value} {ty : Ty}
    (h : ValueHasTy value ty) (hTy : ty.isBool = true) : ∃ b, value = .bool b := by
  cases h <;> simp [Ty.isBool] at hTy
  exact ⟨_, rfl⟩

theorem ValueHasTy.bool_inv' {value : Value}
    (h : ValueHasTy value (.scalar .bool)) : ∃ b, value = .bool b :=
  h.bool_inv rfl

theorem ValueHasTy.array_inv {value : Value} {elem : Ty} {size : Nat}
    (h : ValueHasTy value (.array elem size)) :
    ∃ values, value = .array values ∧ values.length = size ∧
      ∀ v ∈ values, ValueHasTy v elem := by
  cases h with
  | array values _ _ hLength hElems => exact ⟨values, rfl, hLength, hElems⟩

theorem ValueHasTy.struct_inv {value : Value} {tys : List (String × Ty)}
    (h : ValueHasTy value (.structTy tys)) :
    ∃ fields, value = .structValue fields ∧
      (∀ field ty, Ty.fieldType? tys field = some ty →
        (Value.structField? fields field).isSome = true) ∧
      (∀ field ty v, Ty.fieldType? tys field = some ty →
        Value.structField? fields field = some v → ValueHasTy v ty) := by
  cases h with
  | structValue fields _ hPresent hTyped => exact ⟨fields, rfl, hPresent, hTyped⟩

/-! ## Operators -/

def UnaryOp.resultTy? (op : UnaryOp) (ty : Ty) : Option Ty :=
  match op with
  | .not => if ty.isBool then some (.scalar .bool) else none
  | .neg => if ty.isUint then some (.scalar (.uint 256)) else none

theorem UnaryOp.eval_of_resultTy? {op : UnaryOp} {value : Value} {ty ty' : Ty}
    (hValue : ValueHasTy value ty) (hTy : op.resultTy? ty = some ty') :
    ∃ result, op.eval value = some result ∧ ValueHasTy result ty' := by
  cases op <;> simp only [UnaryOp.resultTy?] at hTy <;> split at hTy <;> cases hTy
  · obtain ⟨b, rfl⟩ := hValue.bool_inv (by assumption)
    exact ⟨_, rfl, .bool _⟩
  · obtain ⟨n, rfl⟩ := hValue.uint_inv (by assumption)
    exact ⟨_, rfl, .uint _ _⟩

def BinaryOp.resultTy? (op : BinaryOp) (lhs rhs : Ty) : Option Ty :=
  match op with
  | .eq | .neq => some (.scalar .bool)
  | .add | .sub | .mul | .div | .mod | .bitAnd | .bitOr | .bitXor =>
      if lhs.isUint && rhs.isUint then some (.scalar (.uint 256)) else none
  | .lt | .lte | .gt | .gte =>
      if lhs.isUint && rhs.isUint then some (.scalar .bool) else none
  | .logicAnd | .logicOr =>
      if lhs.isBool && rhs.isBool then some (.scalar .bool) else none

theorem BinaryOp.eval_of_resultTy? {op : BinaryOp} {lv rv : Value} {lt rt ty : Ty}
    (hl : ValueHasTy lv lt) (hr : ValueHasTy rv rt)
    (hTy : op.resultTy? lt rt = some ty) :
    ∃ result, op.eval lv rv = some result ∧ ValueHasTy result ty := by
  cases op <;> simp only [BinaryOp.resultTy?] at hTy
  case eq => cases hTy; exact ⟨_, rfl, .bool _⟩
  case neq => cases hTy; exact ⟨_, rfl, .bool _⟩
  all_goals
    split at hTy
    · rename_i hBoth
      simp only [Bool.and_eq_true] at hBoth
      cases hTy
      first
        | (obtain ⟨a, rfl⟩ := hl.uint_inv hBoth.1
           obtain ⟨b, rfl⟩ := hr.uint_inv hBoth.2
           first
             | exact ⟨_, rfl, .uint _ _⟩
             | exact ⟨_, rfl, .bool _⟩
             | (simp only [BinaryOp.eval]
                split
                · exact ⟨_, rfl, .uint _ _⟩
                · exact ⟨_, rfl, .uint _ _⟩))
        | (obtain ⟨a, rfl⟩ := hl.bool_inv hBoth.1
           obtain ⟨b, rfl⟩ := hr.bool_inv hBoth.2
           exact ⟨_, rfl, .bool _⟩)
    · cases hTy

/-! ## Variables, literals, and constant indices -/

/-- Type of a variable in a typing context (first binding wins, as in
`LocalEnv.lookup`). -/
def tyLookup (Γ : List (String × Ty)) (name : String) : Option Ty :=
  match Γ.find? (fun entry => entry.fst = name) with
  | some (_, ty) => some ty
  | none => none

/-- Bind a variable, mirroring `LocalEnv.insert`. -/
def tyInsert (Γ : List (String × Ty)) (name : String) (ty : Ty) : List (String × Ty) :=
  (name, ty) :: Γ.filter (fun entry => entry.fst ≠ name)

/-- Every typed variable is bound to a value of its type. -/
def EnvConforms (Γ : List (String × Ty)) (env : LocalEnv) : Prop :=
  ∀ name ty, tyLookup Γ name = some ty →
    ∃ value, env.lookup name = some value ∧ ValueHasTy value ty

def Value.literalTy? : Value → Option Ty
  | .bool _ => some (.scalar .bool)
  | .uint _ => some (.scalar (.uint 256))
  | .bytes32 _ => some (.scalar .bytes32)
  | .address _ => some (.scalar .address)
  | _ => none

theorem Value.literalTy?_hasTy {value : Value} {ty : Ty}
    (h : value.literalTy? = some ty) : ValueHasTy value ty := by
  cases value <;> simp [Value.literalTy?] at h <;> subst h
  · exact .bool _
  · exact .uint _ _
  · exact .bytes32 _
  · exact .address _

/-- A uint value that is a constant index below `size`. -/
def constIndexBelow (index : Option Value) (size : Nat) : Bool :=
  match index with
  | some (.uint k) => decide (k < size)
  | _ => false

theorem constIndexBelow_inv {index : Option Value} {size : Nat}
    (h : constIndexBelow index size = true) : ∃ k, index = some (.uint k) ∧ k < size := by
  unfold constIndexBelow at h
  split at h
  · exact ⟨_, rfl, by simpa using h⟩
  · cases h

theorem Value.arrayIndex?_of_lt {values : List Value} {k : Nat}
    (h : k < values.length) : ∃ v, Value.arrayIndex? values k = some v ∧ v ∈ values :=
  ⟨values[k], by simp [Value.arrayIndex?, h], List.getElem_mem h⟩

theorem Value.structField?_of_isSome {fields : List (String × Value)} {field : String}
    (h : (Value.structField? fields field).isSome = true) :
    ∃ v, Value.structField? fields field = some v := by
  cases hField : Value.structField? fields field with
  | none => simp [hField] at h
  | some v => exact ⟨v, rfl⟩

/-- Closed constant value of a pure expression (literals and operators only). -/
def KernelPureExpr.constValue? : KernelPureExpr → Option Value
  | .literal v => some v
  | .unary op e =>
      match KernelPureExpr.constValue? e with
      | some v => op.eval v
      | none => none
  | .binary op lhs rhs =>
      match KernelPureExpr.constValue? lhs, KernelPureExpr.constValue? rhs with
      | some a, some b => op.eval a b
      | _, _ => none
  | _ => none

theorem KernelPureExpr.eval_of_constValue? (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ {e : KernelPureExpr} {value : Value},
      e.constValue? = some value → evalKernelPureExpr cfg env e = .value value
  | .literal v, value, h => by
      simp [KernelPureExpr.constValue?] at h
      subst h
      simp [evalKernelPureExpr]
  | .unary op e, value, h => by
      simp only [KernelPureExpr.constValue?] at h
      split at h
      · rename_i v hv
        simp [evalKernelPureExpr, KernelPureExpr.eval_of_constValue? cfg env hv, h]
      · cases h
  | .binary op lhs rhs, value, h => by
      simp only [KernelPureExpr.constValue?] at h
      split at h
      · rename_i a b ha hb
        simp [evalKernelPureExpr, KernelPureExpr.eval_of_constValue? cfg env ha,
          KernelPureExpr.eval_of_constValue? cfg env hb, h]
      · cases h
  | .var _, _, h => by simp [KernelPureExpr.constValue?] at h
  | .select _ _ _, _, h => by simp [KernelPureExpr.constValue?] at h
  | .structField _ _, _, h => by simp [KernelPureExpr.constValue?] at h
  | .arrayIndex _ _, _, h => by simp [KernelPureExpr.constValue?] at h
  | .keccak256 _, _, h => by simp [KernelPureExpr.constValue?] at h

/-! ## Pure expressions -/

mutual

/-- Type of a pure kernel expression, or `none` if it is ill-typed. -/
def KernelPureExpr.typeOf? (Γ : List (String × Ty)) : KernelPureExpr → Option Ty
  | .literal v => v.literalTy?
  | .var name => tyLookup Γ name
  | .unary op e =>
      match KernelPureExpr.typeOf? Γ e with
      | some ty => op.resultTy? ty
      | none => none
  | .binary op lhs rhs =>
      match KernelPureExpr.typeOf? Γ lhs, KernelPureExpr.typeOf? Γ rhs with
      | some lt, some rt => op.resultTy? lt rt
      | _, _ => none
  | .select cond whenTrue whenFalse =>
      match KernelPureExpr.typeOf? Γ cond, KernelPureExpr.typeOf? Γ whenTrue,
          KernelPureExpr.typeOf? Γ whenFalse with
      | some (.scalar .bool), some t, some f => if Ty.beq t f then some t else none
      | _, _, _ => none
  | .structField base field =>
      match KernelPureExpr.typeOf? Γ base with
      | some (.structTy tys) => Ty.fieldType? tys field
      | _ => none
  | .arrayIndex base index =>
      match KernelPureExpr.typeOf? Γ base with
      | some (.array elem size) =>
          if constIndexBelow index.constValue? size then some elem else none
      | _ => none
  | .keccak256 parts =>
      if KernelPureExpr.listTyped Γ parts then some (.scalar .bytes32) else none

/-- Every expression in the list is well typed. -/
def KernelPureExpr.listTyped (Γ : List (String × Ty)) : List KernelPureExpr → Bool
  | [] => true
  | p :: rest => (KernelPureExpr.typeOf? Γ p).isSome && KernelPureExpr.listTyped Γ rest

end

mutual

/-- A well-typed pure expression evaluates to a value of its type. -/
theorem KernelPureExpr.eval_of_typeOf? (cfg : OperationalConfig)
    {Γ : List (String × Ty)} {env : LocalEnv} (hEnv : EnvConforms Γ env) :
    ∀ (e : KernelPureExpr) {ty : Ty}, e.typeOf? Γ = some ty →
      ∃ value, evalKernelPureExpr cfg env e = .value value ∧ ValueHasTy value ty
  | .literal v, ty, h => ⟨v, by simp [evalKernelPureExpr], Value.literalTy?_hasTy h⟩
  | .var name, ty, h => by
      obtain ⟨v, hv, hvt⟩ := hEnv name ty h
      exact ⟨v, by simp [evalKernelPureExpr, hv], hvt⟩
  | .unary op e, ty, h => by
      simp only [KernelPureExpr.typeOf?] at h
      split at h
      · rename_i te he
        obtain ⟨v, hv, hvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv e he
        obtain ⟨r, hr, hrt⟩ := UnaryOp.eval_of_resultTy? hvt h
        exact ⟨r, by simp [evalKernelPureExpr, hv, hr], hrt⟩
      · cases h
  | .binary op lhs rhs, ty, h => by
      simp only [KernelPureExpr.typeOf?] at h
      split at h
      · rename_i lt rt hlt hrt
        obtain ⟨lv, hlv, hlvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv lhs hlt
        obtain ⟨rv, hrv, hrvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv rhs hrt
        obtain ⟨r, hr, hrty⟩ := BinaryOp.eval_of_resultTy? hlvt hrvt h
        exact ⟨r, by simp [evalKernelPureExpr, hlv, hrv, hr], hrty⟩
      · cases h
  | .select cond whenTrue whenFalse, ty, h => by
      simp only [KernelPureExpr.typeOf?] at h
      split at h
      · rename_i t f hc ht hf
        split at h
        · rename_i hBeq
          cases h
          obtain ⟨cv, hcv, hcvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv cond hc
          obtain ⟨b, rfl⟩ := hcvt.bool_inv'
          cases b
          · obtain ⟨fv, hfv, hfvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv whenFalse hf
            exact ⟨fv, by simp [evalKernelPureExpr, hcv, hfv],
              by rw [Ty.eq_of_beq hBeq]; exact hfvt⟩
          · obtain ⟨tv, htv, htvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv whenTrue ht
            exact ⟨tv, by simp [evalKernelPureExpr, hcv, htv], htvt⟩
        · cases h
      · cases h
  | .structField base field, ty, h => by
      simp only [KernelPureExpr.typeOf?] at h
      split at h
      · rename_i tys hb
        obtain ⟨bv, hbv, hbvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv base hb
        obtain ⟨fields, rfl, hPresent, hTyped⟩ := hbvt.struct_inv
        obtain ⟨v, hv⟩ := Value.structField?_of_isSome (hPresent field ty h)
        exact ⟨v, by simp [evalKernelPureExpr, hbv, hv], hTyped field ty v h hv⟩
      · cases h
  | .arrayIndex base index, ty, h => by
      simp only [KernelPureExpr.typeOf?] at h
      split at h
      · rename_i elem size hb
        split at h
        · rename_i hIndex
          cases h
          obtain ⟨k, hk, hlt⟩ := constIndexBelow_inv hIndex
          obtain ⟨bv, hbv, hbvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv base hb
          obtain ⟨values, rfl, hLength, hElems⟩ := hbvt.array_inv
          obtain ⟨v, hv, hMem⟩ := Value.arrayIndex?_of_lt (values := values) (k := k)
            (by omega)
          exact ⟨v, by
            simp [evalKernelPureExpr, hbv,
              KernelPureExpr.eval_of_constValue? cfg env hk, hv], hElems v hMem⟩
        · cases h
      · cases h
  | .keccak256 parts, ty, h => by
      simp only [KernelPureExpr.typeOf?] at h
      split at h
      · rename_i hParts
        cases h
        obtain ⟨vs, hvs⟩ := KernelPureExpr.evalList_of_listTyped cfg hEnv parts hParts
        exact ⟨Value.keccak256Mock vs, by simp [evalKernelPureExpr, hvs], .bytes32 _⟩
      · cases h

/-- A well-typed expression list evaluates without error. -/
theorem KernelPureExpr.evalList_of_listTyped (cfg : OperationalConfig)
    {Γ : List (String × Ty)} {env : LocalEnv} (hEnv : EnvConforms Γ env) :
    ∀ (parts : List KernelPureExpr), KernelPureExpr.listTyped Γ parts = true →
      ∃ values, evalKernelPureExprList cfg env parts = .ok values
  | [], _ => ⟨[], by simp [evalKernelPureExprList]⟩
  | p :: rest, h => by
      simp only [KernelPureExpr.listTyped, Bool.and_eq_true] at h
      obtain ⟨ty, hty⟩ := Option.isSome_iff_exists.mp h.1
      obtain ⟨v, hv, _⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv p hty
      obtain ⟨vs, hvs⟩ := KernelPureExpr.evalList_of_listTyped cfg hEnv rest h.2
      exact ⟨v :: vs, by simp [evalKernelPureExprList, hv, hvs]⟩

end

/-! ## Storage -/

/-- State object with the given id, as `OperationalConfig.stateObjectById?`
finds it. -/
def stateObjectOf? (state : List StateObject) (objectId : Nat) : Option StateObject :=
  state.find? (fun so => so.id = objectId)

/-- The store holds every declared object with values of its declared type:
cells and state arrays are present, and a map is absent (empty) or present. -/
structure StoreConforms (cfg : OperationalConfig) : Prop where
  cell : ∀ objectId object, cfg.stateObjectById? objectId = some object →
    object.kind = .cell →
      ∃ value, cfg.readObject objectId = some value ∧ ValueHasTy value object.valueType
  array : ∀ objectId object, cfg.stateObjectById? objectId = some object →
    object.kind = .arrayKind →
      ∃ values, cfg.readObject objectId = some (.array values) ∧
        ∀ value ∈ values, ValueHasTy value object.valueType
  map : ∀ objectId object, cfg.stateObjectById? objectId = some object →
    object.kind = .mapKind →
      cfg.readObject objectId = none ∨
        ∃ entries, cfg.readObject objectId = some (.map entries) ∧
          ∀ entry ∈ entries, ValueHasTy entry.snd object.valueType

theorem Value.arrayGetD_hasTy {values : List Value} {index : Nat} {ty : Ty}
    (hElems : ∀ value ∈ values, ValueHasTy value ty) :
    ValueHasTy (Value.arrayGetD values index ty) ty := by
  unfold Value.arrayGetD
  split
  · rename_i value hValue
    exact hElems value (List.mem_of_getElem? hValue)
  · exact Value.zeroForType_hasTy ty

theorem Value.mapLookup_mem {entries : List (Value × Value)} {key value : Value}
    (h : Value.mapLookup entries key = some value) : ∃ entry ∈ entries, entry.snd = value := by
  unfold Value.mapLookup at h
  cases hFind : entries.find? (fun entry => Value.beq entry.fst key) with
  | none => simp [hFind] at h
  | some entry =>
      simp [hFind] at h
      exact ⟨entry, List.mem_of_find?_eq_some hFind, h⟩

theorem Value.mapLookupD_hasTy {entries : List (Value × Value)} {key : Value} {ty : Ty}
    (hEntries : ∀ entry ∈ entries, ValueHasTy entry.snd ty) :
    ValueHasTy (Value.mapLookupD entries key ty) ty := by
  unfold Value.mapLookupD
  split
  · rename_i value hValue
    obtain ⟨entry, hMem, rfl⟩ := Value.mapLookup_mem hValue
    exact hEntries entry hMem
  · exact Value.zeroForType_hasTy ty

/-! ## Expressions -/

/-- Closed constant value of a kernel expression (literals and operators only). -/
def KernelExpr.constValue? : KernelExpr → Option Value
  | .literal v => some v
  | .unary op e =>
      match KernelExpr.constValue? e with
      | some v => op.eval v
      | none => none
  | .binary op lhs rhs =>
      match KernelExpr.constValue? lhs, KernelExpr.constValue? rhs with
      | some a, some b => op.eval a b
      | _, _ => none
  | _ => none

theorem KernelExpr.eval_of_constValue? (cfg : OperationalConfig) (env : LocalEnv) :
    ∀ {e : KernelExpr} {value : Value},
      e.constValue? = some value → evalKernelExpr cfg env e = .value value
  | .literal v, value, h => by
      simp [KernelExpr.constValue?] at h
      subst h
      simp [evalKernelExpr]
  | .unary op e, value, h => by
      simp only [KernelExpr.constValue?] at h
      split at h
      · rename_i v hv
        simp [evalKernelExpr, KernelExpr.eval_of_constValue? cfg env hv, h]
      · cases h
  | .binary op lhs rhs, value, h => by
      simp only [KernelExpr.constValue?] at h
      split at h
      · rename_i a b ha hb
        simp [evalKernelExpr, KernelExpr.eval_of_constValue? cfg env ha,
          KernelExpr.eval_of_constValue? cfg env hb, h]
      · cases h
  | .var _, _, h => by simp [KernelExpr.constValue?] at h
  | .select _ _ _, _, h => by simp [KernelExpr.constValue?] at h
  | .cellGet _, _, h => by simp [KernelExpr.constValue?] at h
  | .arrayGet _ _, _, h => by simp [KernelExpr.constValue?] at h
  | .mapGet _ _, _, h => by simp [KernelExpr.constValue?] at h
  | .structField _ _, _, h => by simp [KernelExpr.constValue?] at h
  | .arrayIndex _ _, _, h => by simp [KernelExpr.constValue?] at h
  | .keccak256 _, _, h => by simp [KernelExpr.constValue?] at h

mutual

/-- Type of a kernel expression over the given state layout, or `none` if it
is ill-typed. -/
def KernelExpr.typeOf? (Γ : List (String × Ty)) (state : List StateObject) :
    KernelExpr → Option Ty
  | .literal v => v.literalTy?
  | .var name => tyLookup Γ name
  | .unary op e =>
      match KernelExpr.typeOf? Γ state e with
      | some ty => op.resultTy? ty
      | none => none
  | .binary op lhs rhs =>
      match KernelExpr.typeOf? Γ state lhs, KernelExpr.typeOf? Γ state rhs with
      | some lt, some rt => op.resultTy? lt rt
      | _, _ => none
  | .select cond whenTrue whenFalse =>
      match KernelExpr.typeOf? Γ state cond, whenTrue.typeOf? Γ, whenFalse.typeOf? Γ with
      | some (.scalar .bool), some t, some f => if Ty.beq t f then some t else none
      | _, _, _ => none
  | .cellGet objectId =>
      match stateObjectOf? state objectId with
      | some object => if object.kind = .cell then some object.valueType else none
      | none => none
  | .arrayGet objectId index =>
      match stateObjectOf? state objectId, KernelExpr.typeOf? Γ state index with
      | some object, some ty =>
          if object.kind = .arrayKind ∧ ty.isUint = true then some object.valueType else none
      | _, _ => none
  | .mapGet objectId key =>
      match stateObjectOf? state objectId, KernelExpr.typeOf? Γ state key with
      | some object, some _ =>
          if object.kind = .mapKind then some object.valueType else none
      | _, _ => none
  | .structField base field =>
      match KernelExpr.typeOf? Γ state base with
      | some (.structTy tys) => Ty.fieldType? tys field
      | _ => none
  | .arrayIndex base index =>
      match KernelExpr.typeOf? Γ state base with
      | some (.array elem size) =>
          if constIndexBelow index.constValue? size then some elem else none
      | _ => none
  | .keccak256 parts =>
      if KernelExpr.listTyped Γ state parts then some (.scalar .bytes32) else none

/-- Every expression in the list is well typed. -/
def KernelExpr.listTyped (Γ : List (String × Ty)) (state : List StateObject) :
    List KernelExpr → Bool
  | [] => true
  | p :: rest =>
      (KernelExpr.typeOf? Γ state p).isSome && KernelExpr.listTyped Γ state rest

end

mutual

/-- A well-typed kernel expression evaluates to a value of its type. -/
theorem KernelExpr.eval_of_typeOf? {cfg : OperationalConfig}
    {Γ : List (String × Ty)} {env : LocalEnv}
    (hEnv : EnvConforms Γ env) (hStore : StoreConforms cfg) :
    ∀ (e : KernelExpr) {ty : Ty}, e.typeOf? Γ cfg.contract.state = some ty →
      ∃ value, evalKernelExpr cfg env e = .value value ∧ ValueHasTy value ty
  | .literal v, ty, h => ⟨v, by simp [evalKernelExpr], Value.literalTy?_hasTy h⟩
  | .var name, ty, h => by
      obtain ⟨v, hv, hvt⟩ := hEnv name ty h
      exact ⟨v, by simp [evalKernelExpr, hv], hvt⟩
  | .unary op e, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i te he
        obtain ⟨v, hv, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore e he
        obtain ⟨r, hr, hrt⟩ := UnaryOp.eval_of_resultTy? hvt h
        exact ⟨r, by simp [evalKernelExpr, hv, hr], hrt⟩
      · cases h
  | .binary op lhs rhs, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i lt rt hlt hrt
        obtain ⟨lv, hlv, hlvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore lhs hlt
        obtain ⟨rv, hrv, hrvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore rhs hrt
        obtain ⟨r, hr, hrty⟩ := BinaryOp.eval_of_resultTy? hlvt hrvt h
        exact ⟨r, by simp [evalKernelExpr, hlv, hrv, hr], hrty⟩
      · cases h
  | .select cond whenTrue whenFalse, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i t f hc ht hf
        split at h
        · rename_i hBeq
          cases h
          obtain ⟨cv, hcv, hcvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore cond hc
          obtain ⟨b, rfl⟩ := hcvt.bool_inv'
          cases b
          · obtain ⟨fv, hfv, hfvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv whenFalse hf
            exact ⟨fv, by simp [evalKernelExpr, hcv, hfv],
              by rw [Ty.eq_of_beq hBeq]; exact hfvt⟩
          · obtain ⟨tv, htv, htvt⟩ := KernelPureExpr.eval_of_typeOf? cfg hEnv whenTrue ht
            exact ⟨tv, by simp [evalKernelExpr, hcv, htv], htvt⟩
        · cases h
      · cases h
  | .cellGet objectId, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i object hObject
        split at h
        · rename_i hKind
          cases h
          obtain ⟨v, hv, hvt⟩ := hStore.cell objectId object hObject hKind
          exact ⟨v, by simp [evalKernelExpr, hv], hvt⟩
        · cases h
      · cases h
  | .arrayGet objectId index, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i object ity hObject hIndex
        split at h
        · rename_i hCond
          cases h
          obtain ⟨iv, hiv, hivt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore index hIndex
          obtain ⟨k, rfl⟩ := hivt.uint_inv hCond.2
          obtain ⟨values, hRead, hElems⟩ :=
            hStore.array objectId object hObject hCond.1
          have hLookup : cfg.stateObjectById? objectId = some object := hObject
          exact ⟨Value.arrayGetD values k object.valueType,
            by simp [evalKernelExpr, hiv, hLookup, hRead], Value.arrayGetD_hasTy hElems⟩
        · cases h
      · cases h
  | .mapGet objectId key, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i object kty hObject hKey
        split at h
        · rename_i hKind
          cases h
          obtain ⟨kv, hkv, _⟩ := KernelExpr.eval_of_typeOf? hEnv hStore key hKey
          have hLookup : cfg.stateObjectById? objectId = some object := hObject
          rcases hStore.map objectId object hObject hKind with hNone | ⟨entries, hRead, hEntries⟩
          · exact ⟨_, by simp [evalKernelExpr, hkv, hLookup, hNone, hKind],
              Value.zeroForType_hasTy _⟩
          · exact ⟨Value.mapLookupD entries kv object.valueType,
              by simp [evalKernelExpr, hkv, hLookup, hRead], Value.mapLookupD_hasTy hEntries⟩
        · cases h
      · cases h
  | .structField base field, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i tys hb
        obtain ⟨bv, hbv, hbvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore base hb
        obtain ⟨fields, rfl, hPresent, hTyped⟩ := hbvt.struct_inv
        obtain ⟨v, hv⟩ := Value.structField?_of_isSome (hPresent field ty h)
        exact ⟨v, by simp [evalKernelExpr, hbv, hv], hTyped field ty v h hv⟩
      · cases h
  | .arrayIndex base index, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i elem size hb
        split at h
        · rename_i hIndex
          cases h
          obtain ⟨k, hk, hlt⟩ := constIndexBelow_inv hIndex
          obtain ⟨bv, hbv, hbvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore base hb
          obtain ⟨values, rfl, hLength, hElems⟩ := hbvt.array_inv
          obtain ⟨v, hv, hMem⟩ := Value.arrayIndex?_of_lt (values := values) (k := k)
            (by omega)
          exact ⟨v, by
            simp [evalKernelExpr, hbv, KernelExpr.eval_of_constValue? cfg env hk, hv],
            hElems v hMem⟩
        · cases h
      · cases h
  | .keccak256 parts, ty, h => by
      simp only [KernelExpr.typeOf?] at h
      split at h
      · rename_i hParts
        cases h
        obtain ⟨vs, hvs⟩ := KernelExpr.evalList_of_listTyped hEnv hStore parts hParts
        exact ⟨Value.keccak256Mock vs, by simp [evalKernelExpr, hvs], .bytes32 _⟩
      · cases h

/-- A well-typed expression list evaluates without error. -/
theorem KernelExpr.evalList_of_listTyped {cfg : OperationalConfig}
    {Γ : List (String × Ty)} {env : LocalEnv}
    (hEnv : EnvConforms Γ env) (hStore : StoreConforms cfg) :
    ∀ (parts : List KernelExpr), KernelExpr.listTyped Γ cfg.contract.state parts = true →
      ∃ values, evalKernelExprList cfg env parts = .ok values
  | [], _ => ⟨[], by simp [evalKernelExprList]⟩
  | p :: rest, h => by
      simp only [KernelExpr.listTyped, Bool.and_eq_true] at h
      obtain ⟨ty, hty⟩ := Option.isSome_iff_exists.mp h.1
      obtain ⟨v, hv, _⟩ := KernelExpr.eval_of_typeOf? hEnv hStore p hty
      obtain ⟨vs, hvs⟩ := KernelExpr.evalList_of_listTyped hEnv hStore rest h.2
      exact ⟨v :: vs, by simp [evalKernelExprList, hv, hvs]⟩

end

/-! ## Environment and store updates -/

theorem find?_filter_of_imp {α : Type} (p q : α → Bool)
    (hpq : ∀ a, p a = true → q a = true) :
    ∀ l : List α, (l.filter q).find? p = l.find? p
  | [] => rfl
  | a :: rest => by
      have ih := find?_filter_of_imp p q hpq rest
      cases hq : q a <;> cases hp : p a
      · rw [List.filter_cons_of_neg (by simp [hq]), List.find?_cons_of_neg (by simp [hp]), ih]
      · exact absurd (hpq a hp) (by simp [hq])
      · rw [List.filter_cons_of_pos hq, List.find?_cons_of_neg (by simp [hp]),
          List.find?_cons_of_neg (by simp [hp]), ih]
      · rw [List.filter_cons_of_pos hq, List.find?_cons_of_pos hp, List.find?_cons_of_pos hp]

theorem find?_cons_filter_ne {α : Type} (l : List (String × α)) (name name' : String)
    (x : α) (hNe : name' ≠ name) :
    ((name, x) :: l.filter (fun entry => entry.fst ≠ name)).find?
        (fun entry => entry.fst = name') =
      l.find? (fun entry => entry.fst = name') := by
  have hHead : ¬ name = name' := fun h => hNe h.symm
  rw [List.find?_cons_of_neg (by simp [hHead])]
  exact find?_filter_of_imp _ _ (fun entry h => by
    simp only [decide_eq_true_eq, ne_eq, decide_not, Bool.not_eq_true'] at h ⊢
    simp [h, hNe]) l

theorem LocalEnv.lookup_insert_same (env : LocalEnv) (name : String) (value : Value) :
    (env.insert name value).lookup name = some value := by
  simp [LocalEnv.insert, LocalEnv.lookup]

theorem LocalEnv.lookup_insert_ne (env : LocalEnv) (name name' : String) (value : Value)
    (hNe : name' ≠ name) :
    (env.insert name value).lookup name' = env.lookup name' := by
  unfold LocalEnv.insert LocalEnv.lookup
  rw [find?_cons_filter_ne env name name' value hNe]

theorem tyLookup_tyInsert_same (Γ : List (String × Ty)) (name : String) (ty : Ty) :
    tyLookup (tyInsert Γ name ty) name = some ty := by
  simp [tyInsert, tyLookup]

theorem tyLookup_tyInsert_ne (Γ : List (String × Ty)) (name name' : String) (ty : Ty)
    (hNe : name' ≠ name) :
    tyLookup (tyInsert Γ name ty) name' = tyLookup Γ name' := by
  unfold tyInsert tyLookup
  rw [find?_cons_filter_ne Γ name name' ty hNe]

theorem EnvConforms.insert {Γ : List (String × Ty)} {env : LocalEnv}
    (hEnv : EnvConforms Γ env) (name : String) {value : Value} {ty : Ty}
    (hValue : ValueHasTy value ty) :
    EnvConforms (tyInsert Γ name ty) (env.insert name value) := by
  intro name' ty' h
  by_cases hName : name' = name
  · subst hName
    rw [tyLookup_tyInsert_same] at h
    cases h
    exact ⟨value, LocalEnv.lookup_insert_same env name' value, hValue⟩
  · rw [tyLookup_tyInsert_ne Γ name name' ty hName] at h
    rw [LocalEnv.lookup_insert_ne env name name' value hName]
    exact hEnv name' ty' h

theorem EnvConforms.assign {Γ : List (String × Ty)} {env : LocalEnv}
    (hEnv : EnvConforms Γ env) {name : String} {value : Value} {ty : Ty}
    (hLookup : tyLookup Γ name = some ty) (hValue : ValueHasTy value ty) :
    EnvConforms Γ (env.insert name value) := by
  intro name' ty' h
  by_cases hName : name' = name
  · subst hName
    rw [hLookup] at h
    cases h
    exact ⟨value, LocalEnv.lookup_insert_same env name' value, hValue⟩
  · rw [LocalEnv.lookup_insert_ne env name name' value hName]
    exact hEnv name' ty' h

theorem OperationalConfig.writeObject?_contract {cfg cfg' : OperationalConfig}
    {objectId : Nat} {value : Value} (h : cfg.writeObject? objectId value = some cfg') :
    cfg'.contract = cfg.contract := by
  unfold OperationalConfig.writeObject? at h
  split at h <;> simp only [Option.some.injEq, reduceCtorEq] at h <;> subst h <;> rfl

theorem OperationalConfig.stateObjectById?_writeObject? {cfg cfg' : OperationalConfig}
    {objectId : Nat} {value : Value} (h : cfg.writeObject? objectId value = some cfg')
    (queryId : Nat) : cfg'.stateObjectById? queryId = cfg.stateObjectById? queryId := by
  simp [OperationalConfig.stateObjectById?, OperationalConfig.writeObject?_contract h]

theorem OperationalConfig.objectConfidential?_writeObject? {cfg cfg' : OperationalConfig}
    {objectId : Nat} {value : Value} (h : cfg.writeObject? objectId value = some cfg')
    (queryId : Nat) :
    cfg'.objectConfidential? queryId = cfg.objectConfidential? queryId := by
  simp only [OperationalConfig.objectConfidential?,
    OperationalConfig.stateObjectById?_writeObject? h]

theorem OperationalConfig.readObject_writeObject?_same {cfg cfg' : OperationalConfig}
    {objectId : Nat} {value : Value} (h : cfg.writeObject? objectId value = some cfg') :
    cfg'.readObject objectId = some value := by
  have hSame := OperationalConfig.objectConfidential?_writeObject? h objectId
  unfold OperationalConfig.readObject
  rw [hSame]
  unfold OperationalConfig.writeObject? at h
  cases hc : cfg.objectConfidential? objectId with
  | none => simp [hc] at h
  | some b =>
      cases b
      · simp only [hc, Option.some.injEq] at h
        subst h
        simp [ObjectStore.lookup_insert_eq]
      · simp only [hc, Option.some.injEq] at h
        subst h
        simp [ObjectStore.lookup_insert_eq]

theorem OperationalConfig.readObject_writeObject?_ne {cfg cfg' : OperationalConfig}
    {objectId queryId : Nat} {value : Value} (h : cfg.writeObject? objectId value = some cfg')
    (hNe : queryId ≠ objectId) :
    cfg'.readObject queryId = cfg.readObject queryId := by
  have hSame := OperationalConfig.objectConfidential?_writeObject? h queryId
  unfold OperationalConfig.readObject
  rw [hSame]
  unfold OperationalConfig.writeObject? at h
  cases hc : cfg.objectConfidential? objectId with
  | none => simp [hc] at h
  | some b =>
      cases b <;> simp only [hc, Option.some.injEq] at h <;> subst h <;>
        cases hq : cfg.objectConfidential? queryId with
        | none => rfl
        | some b' =>
            cases b' <;> simp [ObjectStore.lookup_insert_ne _ _ _ _ hNe,
              ObjectStore.lookup_remove_ne _ _ _ hNe]

theorem OperationalConfig.writeObject?_of_known {cfg : OperationalConfig}
    {objectId : Nat} {object : StateObject} (value : Value)
    (hObject : cfg.stateObjectById? objectId = some object) :
    ∃ cfg', cfg.writeObject? objectId value = some cfg' := by
  unfold OperationalConfig.writeObject? OperationalConfig.objectConfidential?
  rw [hObject]
  cases hc : object.confidential <;> simp [hc]

/-- A value the store may hold for the object, by the object's kind. -/
def ObjectValueConforms (object : StateObject) (value : Value) : Prop :=
  match object.kind with
  | .cell => ValueHasTy value object.valueType
  | .arrayKind => ∃ values, value = .array values ∧
      ∀ v ∈ values, ValueHasTy v object.valueType
  | .mapKind => ∃ entries, value = .map entries ∧
      ∀ entry ∈ entries, ValueHasTy entry.snd object.valueType

theorem StoreConforms.write {cfg cfg' : OperationalConfig} {objectId : Nat}
    {value : Value} {object : StateObject}
    (hStore : StoreConforms cfg) (hWrite : cfg.writeObject? objectId value = some cfg')
    (hObject : cfg.stateObjectById? objectId = some object)
    (hValue : ObjectValueConforms object value) : StoreConforms cfg' := by
  have hLookup := OperationalConfig.stateObjectById?_writeObject? hWrite
  refine ⟨?_, ?_, ?_⟩
  · intro queryId so hSo hKind
    rw [hLookup] at hSo
    by_cases hId : queryId = objectId
    · subst hId
      rw [hObject] at hSo
      cases hSo
      simp only [ObjectValueConforms, hKind] at hValue
      exact ⟨value, OperationalConfig.readObject_writeObject?_same hWrite, hValue⟩
    · rw [OperationalConfig.readObject_writeObject?_ne hWrite hId]
      exact hStore.cell queryId so hSo hKind
  · intro queryId so hSo hKind
    rw [hLookup] at hSo
    by_cases hId : queryId = objectId
    · subst hId
      rw [hObject] at hSo
      cases hSo
      simp only [ObjectValueConforms, hKind] at hValue
      obtain ⟨values, rfl, hElems⟩ := hValue
      exact ⟨values, OperationalConfig.readObject_writeObject?_same hWrite, hElems⟩
    · rw [OperationalConfig.readObject_writeObject?_ne hWrite hId]
      exact hStore.array queryId so hSo hKind
  · intro queryId so hSo hKind
    rw [hLookup] at hSo
    by_cases hId : queryId = objectId
    · subst hId
      rw [hObject] at hSo
      cases hSo
      simp only [ObjectValueConforms, hKind] at hValue
      obtain ⟨entries, rfl, hEntries⟩ := hValue
      exact Or.inr ⟨entries, OperationalConfig.readObject_writeObject?_same hWrite, hEntries⟩
    · rw [OperationalConfig.readObject_writeObject?_ne hWrite hId]
      exact hStore.map queryId so hSo hKind

theorem Value.arraySetAt_mem {values : List Value} {index : Nat} {newVal x : Value}
    (h : x ∈ Value.arraySetAt values index newVal) : x ∈ values ∨ x = newVal := by
  unfold Value.arraySetAt at h
  obtain ⟨i, hi, rfl⟩ := List.mem_iff_getElem.mp h
  simp only [List.getElem_mapIdx]
  split
  · exact Or.inr rfl
  · exact Or.inl (List.getElem_mem _)

theorem Value.mapInsert_mem {entries : List (Value × Value)} {key value : Value}
    {entry : Value × Value} (h : entry ∈ Value.mapInsert entries key value) :
    entry ∈ entries ∨ entry.snd = value := by
  unfold Value.mapInsert at h
  split at h
  · obtain ⟨e, he, rfl⟩ := List.mem_map.mp h
    split
    · exact Or.inr rfl
    · exact Or.inl he
  · rcases List.mem_cons.mp h with rfl | h
    · exact Or.inr rfl
    · exact Or.inl h

theorem Value.mapInsertBounded_mem {entries : List (Value × Value)} {key value : Value}
    {capacity : Option Nat} {entry : Value × Value}
    (h : entry ∈ (Value.mapInsertBounded entries key value capacity).entries) :
    entry ∈ entries ∨ entry.snd = value := by
  unfold Value.mapInsertBounded at h
  split at h
  · exact Value.mapInsert_mem h
  · split at h
    · split at h
      · rcases List.mem_cons.mp h with rfl | h
        · exact Or.inr rfl
        · exact Or.inl h
      · exact Or.inl h
    · rcases List.mem_cons.mp h with rfl | h
      · exact Or.inr rfl
      · exact Or.inl h

/-! ## Statements -/

/-- An optional predicate is a well-typed boolean expression. -/
def predicateTyped (Γ : List (String × Ty)) (state : List StateObject) :
    Option KernelExpr → Bool
  | none => true
  | some predicate =>
      match predicate.typeOf? Γ state with
      | some ty => ty.isBool
      | none => false

theorem predicate_eval_of_typed {cfg : OperationalConfig} {Γ : List (String × Ty)}
    {env : LocalEnv} (hEnv : EnvConforms Γ env) (hStore : StoreConforms cfg)
    {predicate : KernelExpr}
    (h : predicateTyped Γ cfg.contract.state (some predicate) = true) :
    ∃ b, evalKernelExpr cfg env predicate = .value (.bool b) := by
  simp only [predicateTyped] at h
  split at h
  · rename_i ty hTy
    obtain ⟨v, hv, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore predicate hTy
    obtain ⟨b, rfl⟩ := hvt.bool_inv h
    exact ⟨b, hv⟩
  · cases h

/-- Typing context after the statement, or `none` if it is ill-typed. -/
def KernelStatement.typeCheck (Γ : List (String × Ty)) (state : List StateObject) :
    KernelStatement → Option (List (String × Ty))
  | .declare name ty value =>
      match value.typeOf? Γ state with
      | some vty => if Ty.beq vty ty then some (tyInsert Γ name ty) else none
      | none => none
  | .assign name value =>
      match tyLookup Γ name, value.typeOf? Γ state with
      | some ty, some vty => if Ty.beq vty ty then some Γ else none
      | _, _ => none
  | .require cond =>
      match cond.typeOf? Γ state with
      | some ty => if ty.isBool then some Γ else none
      | none => none
  | .abortIf cond =>
      match cond.typeOf? Γ state with
      | some ty => if ty.isBool then some Γ else none
      | none => none
  | .cellSet objectId value predicate =>
      match stateObjectOf? state objectId, value.typeOf? Γ state with
      | some object, some vty =>
          if object.kind = .cell ∧ Ty.beq vty object.valueType = true ∧
              predicateTyped Γ state predicate = true then some Γ else none
      | _, _ => none
  | .arraySet objectId index value predicate =>
      match stateObjectOf? state objectId, index.typeOf? Γ state, value.typeOf? Γ state with
      | some object, some ity, some vty =>
          if object.kind = .arrayKind ∧ ity.isUint = true ∧
              Ty.beq vty object.valueType = true ∧
              predicateTyped Γ state predicate = true then some Γ else none
      | _, _, _ => none
  | .mapPut objectId key value predicate =>
      match stateObjectOf? state objectId, key.typeOf? Γ state, value.typeOf? Γ state with
      | some object, some _, some vty =>
          if object.kind = .mapKind ∧ Ty.beq vty object.valueType = true ∧
              predicateTyped Γ state predicate = true then some Γ else none
      | _, _, _ => none
  | .retStmt none => some Γ
  | .retStmt (some value) =>
      match value.typeOf? Γ state with
      | some _ => some Γ
      | none => none

/-- Closes the conjuncts of `evalKernelStatement_wellTyped` from hypotheses in
context. -/
local macro "stmt_close" : tactic =>
  `(tactic| (refine ⟨?_, ?_, ?_, ?_⟩ <;> first | assumption | rfl | trivial))

/-- A well-typed statement preserves environment and store conformance and
reports at most a recorded abort, never an evaluation error. -/
theorem evalKernelStatement_wellTyped {cfg : OperationalConfig} {env : LocalEnv}
    {oc : Outcome} {Γ Γ' : List (String × Ty)} {stmt : KernelStatement}
    (hEnv : EnvConforms Γ env) (hStore : StoreConforms cfg)
    (hTy : stmt.typeCheck Γ cfg.contract.state = some Γ')
    (hOc : oc.status.continuesBody true = true) :
    (evalKernelStatement cfg env oc stmt).2.2.status.continuesBody true = true ∧
      EnvConforms Γ' (evalKernelStatement cfg env oc stmt).2.1 ∧
      StoreConforms (evalKernelStatement cfg env oc stmt).1 ∧
      (evalKernelStatement cfg env oc stmt).1.contract = cfg.contract := by
  cases stmt with
  | declare name ty value =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i vty hv
        split at hTy
        · rename_i hBeq
          cases hTy
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
          have hEnv' := hEnv.insert name (hvt.of_beq hBeq)
          simp only [evalKernelStatement, hEval]
          stmt_close
        · cases hTy
      · cases hTy
  | assign name value =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i ty vty hLookup hv
        split at hTy
        · rename_i hBeq
          cases hTy
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
          have hEnv' := hEnv.assign hLookup (hvt.of_beq hBeq)
          simp only [evalKernelStatement, hEval]
          stmt_close
        · cases hTy
      · cases hTy
  | require cond =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i ty hc
        split at hTy
        · rename_i hBool
          cases hTy
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore cond hc
          obtain ⟨b, rfl⟩ := hvt.bool_inv hBool
          cases b <;> simp only [evalKernelStatement, hEval] <;> stmt_close
        · cases hTy
      · cases hTy
  | abortIf cond =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i ty hc
        split at hTy
        · rename_i hBool
          cases hTy
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore cond hc
          obtain ⟨b, rfl⟩ := hvt.bool_inv hBool
          cases b <;> simp only [evalKernelStatement, hEval] <;> stmt_close
        · cases hTy
      · cases hTy
  | cellSet objectId value predicate =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i object vty hObject hv
        split at hTy
        · rename_i hCond
          cases hTy
          obtain ⟨hKind, hBeq, hPred⟩ := hCond
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
          have hLookup : cfg.stateObjectById? objectId = some object := hObject
          obtain ⟨cfg', hWrite⟩ := OperationalConfig.writeObject?_of_known v hLookup
          have hConforms : ObjectValueConforms object v := by
            simp only [ObjectValueConforms, hKind]
            exact hvt.of_beq hBeq
          have hStore' := hStore.write hWrite hLookup hConforms
          have hContract := OperationalConfig.writeObject?_contract hWrite
          cases predicate with
          | none =>
              simp only [evalKernelStatement, hEval, hWrite]
              stmt_close
          | some p =>
              obtain ⟨b, hp⟩ := predicate_eval_of_typed hEnv hStore hPred
              cases b
              · simp only [evalKernelStatement, hEval, hp]
                stmt_close
              · simp only [evalKernelStatement, hEval, hp, hWrite]
                stmt_close
        · cases hTy
      · cases hTy
  | arraySet objectId index value predicate =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i object ity vty hObject hi hv
        split at hTy
        · rename_i hCond
          cases hTy
          obtain ⟨hKind, hUint, hBeq, hPred⟩ := hCond
          obtain ⟨iv, hiEval, hivt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore index hi
          obtain ⟨k, rfl⟩ := hivt.uint_inv hUint
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
          have hLookup : cfg.stateObjectById? objectId = some object := hObject
          obtain ⟨values, hRead, hElems⟩ := hStore.array objectId object hLookup hKind
          obtain ⟨cfg', hWrite⟩ := OperationalConfig.writeObject?_of_known
            (Value.array (Value.arraySetAt values k v)) hLookup
          have hConforms :
              ObjectValueConforms object (Value.array (Value.arraySetAt values k v)) := by
            simp only [ObjectValueConforms, hKind]
            refine ⟨_, rfl, ?_⟩
            intro x hx
            rcases Value.arraySetAt_mem hx with hx | rfl
            · exact hElems x hx
            · exact hvt.of_beq hBeq
          have hStore' := hStore.write hWrite hLookup hConforms
          have hContract := OperationalConfig.writeObject?_contract hWrite
          cases predicate with
          | none =>
              simp only [evalKernelStatement, hiEval, hEval, hRead]
              split
              · stmt_close
              · simp only [hWrite]
                stmt_close
          | some p =>
              obtain ⟨b, hp⟩ := predicate_eval_of_typed hEnv hStore hPred
              cases b
              · simp only [evalKernelStatement, hiEval, hEval, hp]
                stmt_close
              · simp only [evalKernelStatement, hiEval, hEval, hp, hRead]
                split
                · stmt_close
                · simp only [hWrite]
                  stmt_close
        · cases hTy
      · cases hTy
  | mapPut objectId key value predicate =>
      simp only [KernelStatement.typeCheck] at hTy
      split at hTy
      · rename_i object kty vty hObject hk hv
        split at hTy
        · rename_i hCond
          cases hTy
          obtain ⟨hKind, hBeq, hPred⟩ := hCond
          obtain ⟨kv, hkEval, _⟩ := KernelExpr.eval_of_typeOf? hEnv hStore key hk
          obtain ⟨v, hEval, hvt⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
          have hLookup : cfg.stateObjectById? objectId = some object := hObject
          have hv' : ValueHasTy v object.valueType := hvt.of_beq hBeq
          have hWriteMap : ∀ entries : List (Value × Value),
              (∀ e ∈ entries, ValueHasTy e.snd object.valueType) →
              ∃ cfg', cfg.writeObject? objectId
                  (Value.map (Value.mapInsertBounded entries kv v object.capacity).entries) =
                  some cfg' ∧ StoreConforms cfg' ∧ cfg'.contract = cfg.contract := by
            intro entries hEntries
            obtain ⟨cfg', hWrite⟩ := OperationalConfig.writeObject?_of_known
              (Value.map (Value.mapInsertBounded entries kv v object.capacity).entries) hLookup
            refine ⟨cfg', hWrite, hStore.write hWrite hLookup ?_,
              OperationalConfig.writeObject?_contract hWrite⟩
            simp only [ObjectValueConforms, hKind]
            refine ⟨_, rfl, ?_⟩
            intro e he
            rcases Value.mapInsertBounded_mem he with he | he
            · exact hEntries e he
            · rw [he]
              exact hv'
          rcases hStore.map objectId object hLookup hKind with hNone | ⟨entries, hRead, hEntries⟩
          · obtain ⟨cfg', hWrite, hStore', hContract⟩ := hWriteMap [] (by simp)
            cases predicate with
            | none =>
                simp only [evalKernelStatement, hkEval, hEval, hLookup, hNone, hKind,
                  ↓reduceIte]
                split
                · stmt_close
                · simp only [hWrite]
                  stmt_close
            | some p =>
                obtain ⟨b, hp⟩ := predicate_eval_of_typed hEnv hStore hPred
                cases b
                · simp only [evalKernelStatement, hkEval, hEval, hp]
                  stmt_close
                · simp only [evalKernelStatement, hkEval, hEval, hp, hLookup, hNone, hKind,
                    ↓reduceIte]
                  split
                  · stmt_close
                  · simp only [hWrite]
                    stmt_close
          · obtain ⟨cfg', hWrite, hStore', hContract⟩ := hWriteMap entries hEntries
            cases predicate with
            | none =>
                simp only [evalKernelStatement, hkEval, hEval, hLookup, hRead]
                split
                · stmt_close
                · simp only [hWrite]
                  stmt_close
            | some p =>
                obtain ⟨b, hp⟩ := predicate_eval_of_typed hEnv hStore hPred
                cases b
                · simp only [evalKernelStatement, hkEval, hEval, hp]
                  stmt_close
                · simp only [evalKernelStatement, hkEval, hEval, hp, hLookup, hRead]
                  split
                  · stmt_close
                  · simp only [hWrite]
                    stmt_close
        · cases hTy
      · cases hTy
  | retStmt value =>
      cases value with
      | none =>
          simp only [KernelStatement.typeCheck] at hTy
          cases hTy
          simp only [evalKernelStatement]
          stmt_close
      | some value =>
          simp only [KernelStatement.typeCheck] at hTy
          split at hTy
          · rename_i vty hv
            cases hTy
            obtain ⟨v, hEval, _⟩ := KernelExpr.eval_of_typeOf? hEnv hStore value hv
            simp only [evalKernelStatement, hEval]
            stmt_close
          · cases hTy

/-! ## Bodies and programs -/

/-- Every statement of the body is well typed in the context its predecessors
leave. -/
def KernelStatement.bodyTyped (Γ : List (String × Ty)) (state : List StateObject) :
    List KernelStatement → Bool
  | [] => true
  | stmt :: rest =>
      match stmt.typeCheck Γ state with
      | some Γ' => KernelStatement.bodyTyped Γ' state rest
      | none => false

theorem evalKernelBody_continues_of_bodyTyped :
    ∀ (body : List KernelStatement) {cfg : OperationalConfig} {env : LocalEnv}
      {oc : Outcome} {Γ : List (String × Ty)},
      EnvConforms Γ env → StoreConforms cfg →
      KernelStatement.bodyTyped Γ cfg.contract.state body = true →
      oc.status.continuesBody true = true →
      (evalKernelBody cfg env oc body).2.2.status.continuesBody true = true
  | [], _, _, _, _, _, _, _, hOc => by
      simp only [evalKernelBody]
      exact hOc
  | stmt :: rest, cfg, env, oc, Γ, hEnv, hStore, hTy, hOc => by
      simp only [KernelStatement.bodyTyped] at hTy
      split at hTy
      · rename_i Γ' hStmt
        obtain ⟨hStatus, hEnv', hStore', hContract⟩ :=
          evalKernelStatement_wellTyped (oc := oc) hEnv hStore hStmt hOc
        simp only [evalKernelBody]
        generalize hStep : evalKernelStatement cfg env oc stmt = step at *
        obtain ⟨cfg', env', oc'⟩ := step
        simp only at hStatus hEnv' hStore' hContract ⊢
        simp only [hStatus, ↓reduceIte]
        split
        · exact hStatus
        · exact evalKernelBody_continues_of_bodyTyped rest hEnv' hStore'
            (by rw [hContract]; exact hTy) hStatus
      · cases hTy

/-- Typing context of a program's parameters, bound in the order
`KernelProgram.initialEnv` binds them. -/
def KernelProgram.paramContext (kp : KernelProgram) : List (String × Ty) :=
  kp.params.foldl (fun Γ param => tyInsert Γ param.name param.ty) []

/-- The kernel program type-checks against the contract's state layout. -/
def KernelProgram.wellTyped (kp : KernelProgram) (state : List StateObject) : Bool :=
  KernelStatement.bodyTyped kp.paramContext state kp.body

/-- Every argument has its parameter's type. -/
inductive ArgsConform : List Param → List Value → Prop
  | nil : ArgsConform [] []
  | cons {param : Param} {arg : Value} {params : List Param} {args : List Value} :
      ValueHasTy arg param.ty → ArgsConform params args →
        ArgsConform (param :: params) (arg :: args)

theorem ArgsConform.length_eq :
    ∀ {params : List Param} {args : List Value}, ArgsConform params args →
      args.length = params.length
  | [], [], .nil => rfl
  | _ :: _, _ :: _, .cons _ hRest => by simp [ArgsConform.length_eq hRest]

theorem paramBindings_conform :
    ∀ {params : List Param} {args : List Value} (Γ : List (String × Ty)) (env : LocalEnv),
      EnvConforms Γ env → ArgsConform params args →
      EnvConforms (params.foldl (fun Γ param => tyInsert Γ param.name param.ty) Γ)
        ((params.zip args).foldl
          (fun env entry => LocalEnv.insert env entry.fst.name entry.snd) env)
  | [], [], _, _, hEnv, .nil => hEnv
  | param :: _, _ :: _, Γ, env, hEnv, .cons hArg hRest => by
      simp only [List.foldl_cons, List.zip_cons_cons]
      exact paramBindings_conform _ _ (hEnv.insert param.name hArg) hRest

theorem KernelProgram.initialEnv_conforms (kp : KernelProgram) (args : List Value)
    (hArgs : ArgsConform kp.params args) :
    ∃ env, kp.initialEnv args = some env ∧ EnvConforms kp.paramContext env := by
  refine ⟨(kp.params.zip args).foldl
      (fun env entry => LocalEnv.insert env entry.fst.name entry.snd) [],
    by simp [KernelProgram.initialEnv, hArgs.length_eq], ?_⟩
  exact paramBindings_conform [] [] (fun _ _ h => by simp [tyLookup] at h) hArgs

/-- A well-typed kernel program, run on arguments of its parameter types over a
conforming store, never reports an evaluation error: its final status is
`completed` or a recorded abort. -/
theorem evalKernelProgram_continues_of_wellTyped (kp : KernelProgram)
    (cfg : OperationalConfig)
    (hTy : kp.wellTyped cfg.contract.state = true)
    (hArgs : ArgsConform kp.params cfg.declaredArgs)
    (hStore : StoreConforms cfg) :
    (evalKernelProgram kp cfg).status.continuesBody true = true := by
  obtain ⟨env, hEnvEq, hEnv⟩ := kp.initialEnv_conforms cfg.declaredArgs hArgs
  have hBody := evalKernelBody_continues_of_bodyTyped kp.body (oc := Outcome.empty)
    hEnv hStore hTy rfl
  unfold evalKernelProgram
  simp only [hEnvEq]
  generalize evalKernelBody cfg env Outcome.empty kp.body = result at *
  obtain ⟨cfg', env', outcome⟩ := result
  simpa [Outcome.withPublicStateTransition] using hBody

/-- A well-typed program without a return value emits its static kernel-step
schedule on every conforming run, whatever its secret inputs. -/
theorem evalKernelProgram_kernelSteps_eq_expected_of_wellTyped (kp : KernelProgram)
    (cfg : OperationalConfig)
    (hTy : kp.wellTyped cfg.contract.state = true)
    (hArgs : ArgsConform kp.params cfg.declaredArgs)
    (hStore : StoreConforms cfg)
    (hPub : (evalKernelProgram kp cfg).publicResult = none) :
    (evalKernelProgram kp cfg).kernelSteps = kp.expectedKernelSteps :=
  evalKernelProgram_kernelSteps_eq_expectedKernelSteps_of_continues kp cfg
    (evalKernelProgram_continues_of_wellTyped kp cfg hTy hArgs hStore) hPub

/-! ## Programs that return a value

`uo-solc` rejects early confidential returns, so a confidential program returns
at most once, as its last statement. Such a program also emits its whole static
schedule. -/

def KernelStatement.isReturn : KernelStatement → Bool
  | .retStmt _ => true
  | _ => false

/-- Only the last statement of the body may return. -/
def KernelStatement.returnsOnlyLast : List KernelStatement → Bool
  | [] => true
  | [_] => true
  | stmt :: rest => !stmt.isReturn && KernelStatement.returnsOnlyLast rest

theorem evalKernelStatement_publicResult_of_not_return (cfg : OperationalConfig)
    (env : LocalEnv) (oc : Outcome) (stmt : KernelStatement)
    (hNot : stmt.isReturn = false) :
    (evalKernelStatement cfg env oc stmt).2.2.publicResult = oc.publicResult := by
  cases stmt <;> simp [KernelStatement.isReturn] at hNot <;>
    simp only [evalKernelStatement] <;> (repeat' split) <;> rfl

theorem evalKernelStatement_kernelSteps_of_return (cfg : OperationalConfig)
    (env : LocalEnv) (oc : Outcome) (value : Option KernelExpr) :
    (evalKernelStatement cfg env oc (.retStmt value)).2.2.kernelSteps = oc.kernelSteps := by
  cases value with
  | none => rfl
  | some value =>
      simp only [evalKernelStatement]
      split <;> rfl

theorem evalKernelBody_kernelSteps_eq_expected_of_wellTyped :
    ∀ (body : List KernelStatement) {cfg : OperationalConfig} {env : LocalEnv}
      {oc : Outcome} {Γ : List (String × Ty)},
      EnvConforms Γ env → StoreConforms cfg →
      KernelStatement.bodyTyped Γ cfg.contract.state body = true →
      KernelStatement.returnsOnlyLast body = true →
      oc.status.continuesBody true = true → oc.publicResult = none →
      (evalKernelBody cfg env oc body).2.2.kernelSteps =
        oc.kernelSteps ++ body.flatMap KernelStatement.expectedStep
  | [], _, _, _, _, _, _, _, _, _, _ => by simp [evalKernelBody]
  | stmt :: rest, cfg, env, oc, Γ, hEnv, hStore, hTy, hRet, hOc, hPub => by
      simp only [KernelStatement.bodyTyped] at hTy
      split at hTy
      · rename_i Γ' hStmt
        obtain ⟨hStatus, hEnv', hStore', hContract⟩ :=
          evalKernelStatement_wellTyped (oc := oc) hEnv hStore hStmt hOc
        have hSteps : (evalKernelStatement cfg env oc stmt).2.2.kernelSteps =
            oc.kernelSteps ++ stmt.expectedStep := by
          cases hIsRet : stmt.isReturn
          · exact evalKernelStatement_kernelSteps_eq_expected_of_continues cfg env oc stmt
              hStatus (evalKernelStatement_publicResult_of_not_return cfg env oc stmt hIsRet)
          · cases stmt <;> simp [KernelStatement.isReturn] at hIsRet
            simp [evalKernelStatement_kernelSteps_of_return, KernelStatement.expectedStep]
        cases rest with
        | nil =>
            rw [evalKernelBody]
            generalize evalKernelStatement cfg env oc stmt = step at *
            obtain ⟨cfg', env', oc'⟩ := step
            simp only at hStatus hSteps ⊢
            simp only [hStatus, ↓reduceIte]
            split <;> simp [evalKernelBody, hSteps]
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
            simp only at hStatus hEnv' hStore' hContract hSteps hPubStmt ⊢
            have hPub' : oc'.publicResult = none := by rw [hPubStmt, hPub]
            simp only [hStatus, hPub', Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
            rw [evalKernelBody_kernelSteps_eq_expected_of_wellTyped (next :: rest') hEnv' hStore'
              (by rw [hContract]; exact hTy) hRet' hStatus hPub', hSteps]
            simp [List.flatMap_cons, List.append_assoc]
      · cases hTy

/-- Every conforming run of a well-typed program whose only return is its last
statement emits the program's static kernel-step schedule. -/
theorem evalKernelProgram_kernelSteps_eq_expected_of_wellTyped_returnsLast
    (kp : KernelProgram) (cfg : OperationalConfig)
    (hTy : kp.wellTyped cfg.contract.state = true)
    (hRet : KernelStatement.returnsOnlyLast kp.body = true)
    (hArgs : ArgsConform kp.params cfg.declaredArgs)
    (hStore : StoreConforms cfg) :
    (evalKernelProgram kp cfg).kernelSteps = kp.expectedKernelSteps := by
  obtain ⟨env, hEnvEq, hEnv⟩ := kp.initialEnv_conforms cfg.declaredArgs hArgs
  have hBody := evalKernelBody_kernelSteps_eq_expected_of_wellTyped kp.body
    (oc := Outcome.empty) hEnv hStore hTy hRet rfl rfl
  unfold evalKernelProgram
  simp only [hEnvEq]
  generalize evalKernelBody cfg env Outcome.empty kp.body = result at *
  obtain ⟨cfg', env', outcome⟩ := result
  simpa [Outcome.withPublicStateTransition, KernelProgram.expectedKernelSteps] using hBody

/-- Schedule noninterference for admitted kernel programs: two conforming runs
of the same well-typed program emit the same kernel steps, whatever their
secret inputs, aborts, or return values. -/
theorem evalKernelProgram_kernelSteps_eq_of_wellTyped
    (kp : KernelProgram) (cfg₁ cfg₂ : OperationalConfig)
    (hTy₁ : kp.wellTyped cfg₁.contract.state = true)
    (hTy₂ : kp.wellTyped cfg₂.contract.state = true)
    (hRet : KernelStatement.returnsOnlyLast kp.body = true)
    (hArgs₁ : ArgsConform kp.params cfg₁.declaredArgs)
    (hArgs₂ : ArgsConform kp.params cfg₂.declaredArgs)
    (hStore₁ : StoreConforms cfg₁) (hStore₂ : StoreConforms cfg₂) :
    (evalKernelProgram kp cfg₁).kernelSteps = (evalKernelProgram kp cfg₂).kernelSteps := by
  rw [evalKernelProgram_kernelSteps_eq_expected_of_wellTyped_returnsLast kp cfg₁ hTy₁ hRet
      hArgs₁ hStore₁,
    evalKernelProgram_kernelSteps_eq_expected_of_wellTyped_returnsLast kp cfg₂ hTy₂ hRet
      hArgs₂ hStore₂]

/-! ## Examples

A mixer-style withdrawal is well typed and returns only as its last statement,
so every conforming run emits its static schedule. Reading a parameter array at
a secret index is rejected, while a constant index below the length is not. -/

private def mixerState : List StateObject :=
  [ { id := 0, name := "balances", kind := .mapKind, backend := .fullScan, oramScheme := ""
    , valueType := .scalar (.uint 256), keyType := some (.scalar .bytes32)
    , capacity := some 8, confidential := true }
  , { id := 1, name := "total", kind := .cell, backend := .fullScan, oramScheme := ""
    , valueType := .scalar (.uint 256), keyType := none, capacity := none
    , confidential := true } ]

private def mixerWithdraw : KernelProgram :=
  { entrypointId := "withdraw(bytes32,uint256)"
  , params := [⟨"commitment", .scalar .bytes32⟩, ⟨"amount", .scalar (.uint 256)⟩]
  , returnType := some (.scalar (.uint 256))
  , secretArgs := [0, 1]
  , body :=
      [ .declare "oldBalance" (.scalar (.uint 256)) (.mapGet 0 (.var "commitment"))
      , .require (.binary .gte (.var "oldBalance") (.var "amount"))
      , .mapPut 0 (.var "commitment") (.binary .sub (.var "oldBalance") (.var "amount")) none
      , .cellSet 1 (.binary .sub (.cellGet 1) (.var "amount")) none
      , .retStmt (some (.var "amount")) ] }

example : mixerWithdraw.wellTyped mixerState = true := by decide

example : KernelStatement.returnsOnlyLast mixerWithdraw.body = true := by decide

private def pickAt (index : KernelExpr) : KernelProgram :=
  { entrypointId := "pick(uint256[4],uint256)"
  , params := [⟨"xs", .array (.scalar (.uint 256)) 4⟩, ⟨"i", .scalar (.uint 256)⟩]
  , returnType := none
  , secretArgs := [0, 1]
  , body := [ .cellSet 1 (.arrayIndex (.var "xs") index) none ] }

example : (pickAt (.var "i")).wellTyped mixerState = false := by decide

example : (pickAt (.literal (.uint 3))).wellTyped mixerState = true := by decide

example : (pickAt (.literal (.uint 4))).wellTyped mixerState = false := by decide

end UOToolchain.IR
