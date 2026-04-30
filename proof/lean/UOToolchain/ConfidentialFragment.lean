import UOToolchain.IRSyntax

namespace UOToolchain

structure ConfidentialFragmentEntrypointWitness where
  entrypointId : String
  selectCount : Nat
  structFieldCount : Nat
  arrayIndexCount : Nat
  nonBranchlessSelectArmCount : Nat
deriving Repr, DecidableEq

def ConfidentialFragmentEntrypointWitness.Valid
  (witness : ConfidentialFragmentEntrypointWitness) : Prop :=
  witness.nonBranchlessSelectArmCount = 0

def ConfidentialFragmentEntrypointWitness.checkValid
  (witness : ConfidentialFragmentEntrypointWitness) : Bool :=
  decide (witness.nonBranchlessSelectArmCount = 0)

@[simp] theorem confidentialFragmentEntrypointWitness_checkValid_eq_true_iff
  (witness : ConfidentialFragmentEntrypointWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  simp [ConfidentialFragmentEntrypointWitness.checkValid,
    ConfidentialFragmentEntrypointWitness.Valid]

structure ConfidentialFragmentWitness where
  contract : String
  entrypoints : List ConfidentialFragmentEntrypointWitness
deriving Repr, DecidableEq

def ConfidentialFragmentWitness.entrypoint?
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) : Option ConfidentialFragmentEntrypointWitness :=
  witness.entrypoints.find? (fun entrypoint => entrypoint.entrypointId == entrypointId)

def ConfidentialFragmentWitness.Valid
  (witness : ConfidentialFragmentWitness) : Prop :=
  witness.entrypoints.all ConfidentialFragmentEntrypointWitness.checkValid = true

def ConfidentialFragmentWitness.checkValid
  (witness : ConfidentialFragmentWitness) : Bool :=
  witness.entrypoints.all ConfidentialFragmentEntrypointWitness.checkValid

@[simp] theorem confidentialFragmentWitness_checkValid_eq_true_iff
  (witness : ConfidentialFragmentWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  rfl

def ConfidentialFragmentWitness.ValidForEntrypoint
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) : Prop :=
  match witness.entrypoint? entrypointId with
  | none => False
  | some entrypoint => entrypoint.Valid

def ConfidentialFragmentWitness.checkValidForEntrypoint
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) : Bool :=
  match witness.entrypoint? entrypointId with
  | none => false
  | some entrypoint => entrypoint.checkValid

@[simp] theorem confidentialFragmentWitness_checkValidForEntrypoint_eq_true_iff
  (witness : ConfidentialFragmentWitness)
  (entrypointId : String) :
  witness.checkValidForEntrypoint entrypointId = true ↔
    witness.ValidForEntrypoint entrypointId := by
  cases hEntrypoint : witness.entrypoint? entrypointId with
  | none =>
      simp [ConfidentialFragmentWitness.checkValidForEntrypoint,
        ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint]
  | some entrypoint =>
      simp [ConfidentialFragmentWitness.checkValidForEntrypoint,
        ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint,
        confidentialFragmentEntrypointWitness_checkValid_eq_true_iff]

theorem confidentialFragmentWitness_validForEntrypoint_exists
  {witness : ConfidentialFragmentWitness}
  {entrypointId : String}
  (hValid : witness.ValidForEntrypoint entrypointId) :
  ∃ entrypoint,
    witness.entrypoint? entrypointId = some entrypoint ∧
      entrypoint.Valid := by
  cases hEntrypoint : witness.entrypoint? entrypointId with
  | none =>
      simp [ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint] at hValid
  | some entrypoint =>
      refine ⟨entrypoint, rfl, ?_⟩
      simpa [ConfidentialFragmentWitness.ValidForEntrypoint, hEntrypoint] using hValid

/-! ## W4.3: Structural confidential-fragment characterization

This section adds a structured-IR companion to the count-based
`ConfidentialFragmentEntrypointWitness`:

* `IR.branchlessPureExpr` characterises the kernel-DSL branchless-pure
  fragment: literals, vars, `unary`, `binary`, `select`, local
  struct-field navigation, local fixed-array indexing, and `keccak256`
  whose subterms are all branchless-pure. Cell, array, and map storage
  reads are rejected. This mirrors the kernel-DSL pure expression surface
  in `crates/uo-core/src/confidential_kernel.rs`.
* `IR.Expr.fragmentValid` and `IR.Statement.fragmentValid` decide
  the structural validity of an expression / statement: every
  `Expr.select` must have branchless-pure arms; local struct projections
  and local fixed-array indexing are valid when their subexpressions are.
* `IR.confidentialFragmentEntrypointWitnessOf` is a Lean-side
  classifier that produces the count-based witness directly from a
  structured `IR.CompiledFunction`. It mirrors the Rust classifier
  in `crates/uo-core/src/fragment.rs` constructor-for-constructor.
* `IR.confidentialFragmentEntrypointWitnessOf_valid_iff` is the W4.3
  characterization theorem: the count-based witness is `Valid` iff
  the function body is structurally `fragmentValid`.

Together with `IR.evalContract`, this surface gives WP4 a Lean-side
*structural* confidential-fragment surface to project the
admission/rejection theorem against.
-/

namespace IR

mutual

/-- An expression is *branchless-pure* when it can be lowered into the
kernel-DSL pure-expression surface. Mirrors
`lower_confidential_kernel_pure_expr` in
`crates/uo-core/src/confidential_kernel.rs`. The mutual companion
`branchlessPureExprList` lets Lean see structural recursion through
the nested `List Expr` inside `keccak256`. -/
def branchlessPureExpr : Expr → Bool
  | .literal _ => true
  | .var _ => true
  | .unary _ e => branchlessPureExpr e
  | .binary _ lhs rhs => branchlessPureExpr lhs && branchlessPureExpr rhs
  | .select cond whenTrue whenFalse =>
      branchlessPureExpr cond && branchlessPureExpr whenTrue && branchlessPureExpr whenFalse
  | .cellGet _ => false
  | .arrayGet _ _ => false
  | .mapGet _ _ => false
  | .structField base _ => branchlessPureExpr base
  | .arrayIndex base index => branchlessPureExpr base && branchlessPureExpr index
  | .keccak256 parts => branchlessPureExprList parts

def branchlessPureExprList : List Expr → Bool
  | [] => true
  | e :: rest => branchlessPureExpr e && branchlessPureExprList rest

end

mutual

/-- An expression is *fragment-valid* when every `Expr.select` has both arms
branchless-pure. Local struct projections and local fixed-array indexing are
admitted when their subexpressions are admitted; storage access remains limited
to the explicit `cellGet` / `arrayGet` / `mapGet` constructors. -/
def Expr.fragmentValid : Expr → Bool
  | .literal _ => true
  | .var _ => true
  | .unary _ e => Expr.fragmentValid e
  | .binary _ lhs rhs => Expr.fragmentValid lhs && Expr.fragmentValid rhs
  | .select cond whenTrue whenFalse =>
      Expr.fragmentValid cond && Expr.fragmentValid whenTrue
        && Expr.fragmentValid whenFalse
        && branchlessPureExpr whenTrue && branchlessPureExpr whenFalse
  | .cellGet _ => true
  | .arrayGet _ index => Expr.fragmentValid index
  | .mapGet _ key => Expr.fragmentValid key
  | .structField base _ => Expr.fragmentValid base
  | .arrayIndex base index => Expr.fragmentValid base && Expr.fragmentValid index
  | .keccak256 parts => Expr.fragmentValidList parts

def Expr.fragmentValidList : List Expr → Bool
  | [] => true
  | e :: rest => Expr.fragmentValid e && Expr.fragmentValidList rest

end

mutual

/-- A statement is *fragment-valid* when every expression inside it is
fragment-valid. The mutual companion `Statement.fragmentValidList`
lets Lean see structural recursion through the nested `List Statement`
inside `ifStmt` and `forLoop`. -/
def Statement.fragmentValid : Statement → Bool
  | .declare _ _ value => Expr.fragmentValid value
  | .assign _ value => Expr.fragmentValid value
  | .require cond => Expr.fragmentValid cond
  | .abortIf cond => Expr.fragmentValid cond
  | .ifStmt cond thenBody elseBody =>
      Expr.fragmentValid cond
        && Statement.fragmentValidList thenBody
        && Statement.fragmentValidList elseBody
  | .forLoop _ _ start_ end_ body =>
      Expr.fragmentValid start_ && Expr.fragmentValid end_
        && Statement.fragmentValidList body
  | .cellSet _ value pred =>
      Expr.fragmentValid value
        && (match pred with | none => true | some p => Expr.fragmentValid p)
  | .arraySet _ index value pred =>
      Expr.fragmentValid index && Expr.fragmentValid value
        && (match pred with | none => true | some p => Expr.fragmentValid p)
  | .mapPut _ key value pred =>
      Expr.fragmentValid key && Expr.fragmentValid value
        && (match pred with | none => true | some p => Expr.fragmentValid p)
  | .retStmt none => true
  | .retStmt (some value) => Expr.fragmentValid value

def Statement.fragmentValidList : List Statement → Bool
  | [] => true
  | s :: rest => Statement.fragmentValid s && Statement.fragmentValidList rest

end

/-- A function body is fragment-valid when every statement is. -/
def CompiledFunction.fragmentValid (fn : CompiledFunction) : Bool :=
  Statement.fragmentValidList fn.body

/-! ### Count-based classifier

The Lean classifier mirrors `confidential_fragment_stats_of_*` in
`crates/uo-core/src/fragment.rs`. Each function contributes its own
counts; statements containing nested statements / expressions
recursively merge their stats. -/

/-- Per-statement structural counts. Mirrors
`crates::uo_core::fragment::ConfidentialFragmentStats`. -/
structure FragmentStats where
  selectCount : Nat
  structFieldCount : Nat
  arrayIndexCount : Nat
  nonBranchlessSelectArmCount : Nat
  deriving Repr, DecidableEq, Inhabited

namespace FragmentStats

@[inline] def empty : FragmentStats :=
  { selectCount := 0
  , structFieldCount := 0
  , arrayIndexCount := 0
  , nonBranchlessSelectArmCount := 0
  }

@[inline] def add (lhs rhs : FragmentStats) : FragmentStats :=
  { selectCount := lhs.selectCount + rhs.selectCount
  , structFieldCount := lhs.structFieldCount + rhs.structFieldCount
  , arrayIndexCount := lhs.arrayIndexCount + rhs.arrayIndexCount
  , nonBranchlessSelectArmCount :=
      lhs.nonBranchlessSelectArmCount + rhs.nonBranchlessSelectArmCount
  }

@[simp] theorem add_zero (s : FragmentStats) : s.add empty = s := by
  cases s; rfl

@[simp] theorem zero_add (s : FragmentStats) : empty.add s = s := by
  cases s; simp [add, empty]

end FragmentStats

mutual

/-- Walk an expression and collect its structural counts. The mutual
companion `Expr.fragmentStatsList` aggregates an expression list. -/
def Expr.fragmentStats : Expr → FragmentStats
  | .literal _ => FragmentStats.empty
  | .var _ => FragmentStats.empty
  | .unary _ e => Expr.fragmentStats e
  | .binary _ lhs rhs => (Expr.fragmentStats lhs).add (Expr.fragmentStats rhs)
  | .select cond whenTrue whenFalse =>
      let inner :=
        ((Expr.fragmentStats cond).add (Expr.fragmentStats whenTrue)).add
          (Expr.fragmentStats whenFalse)
      let armPenalty : Nat :=
        _root_.cond (branchlessPureExpr whenTrue && branchlessPureExpr whenFalse) 0 1
      { inner with
        selectCount := inner.selectCount + 1
      , nonBranchlessSelectArmCount := inner.nonBranchlessSelectArmCount + armPenalty
      }
  | .cellGet _ => FragmentStats.empty
  | .arrayGet _ index => Expr.fragmentStats index
  | .mapGet _ key => Expr.fragmentStats key
  | .structField base _ =>
      let inner := Expr.fragmentStats base
      { inner with structFieldCount := inner.structFieldCount + 1 }
  | .arrayIndex base index =>
      let inner := (Expr.fragmentStats base).add (Expr.fragmentStats index)
      { inner with arrayIndexCount := inner.arrayIndexCount + 1 }
  | .keccak256 parts => Expr.fragmentStatsList parts

def Expr.fragmentStatsList : List Expr → FragmentStats
  | [] => FragmentStats.empty
  | e :: rest => (Expr.fragmentStats e).add (Expr.fragmentStatsList rest)

end

mutual

/-- Walk a statement and collect its structural counts. The mutual
companion `Statement.fragmentStatsList` aggregates a statement list. -/
def Statement.fragmentStats : Statement → FragmentStats
  | .declare _ _ value => Expr.fragmentStats value
  | .assign _ value => Expr.fragmentStats value
  | .require cond => Expr.fragmentStats cond
  | .abortIf cond => Expr.fragmentStats cond
  | .ifStmt cond thenBody elseBody =>
      ((Expr.fragmentStats cond).add (Statement.fragmentStatsList thenBody)).add
        (Statement.fragmentStatsList elseBody)
  | .forLoop _ _ start_ end_ body =>
      ((Expr.fragmentStats start_).add (Expr.fragmentStats end_)).add
        (Statement.fragmentStatsList body)
  | .cellSet _ value pred =>
      let predStats :=
        match pred with
        | none => FragmentStats.empty
        | some p => Expr.fragmentStats p
      (Expr.fragmentStats value).add predStats
  | .arraySet _ index value pred =>
      let predStats :=
        match pred with
        | none => FragmentStats.empty
        | some p => Expr.fragmentStats p
      ((Expr.fragmentStats index).add (Expr.fragmentStats value)).add predStats
  | .mapPut _ key value pred =>
      let predStats :=
        match pred with
        | none => FragmentStats.empty
        | some p => Expr.fragmentStats p
      ((Expr.fragmentStats key).add (Expr.fragmentStats value)).add predStats
  | .retStmt none => FragmentStats.empty
  | .retStmt (some value) => Expr.fragmentStats value

def Statement.fragmentStatsList : List Statement → FragmentStats
  | [] => FragmentStats.empty
  | s :: rest => (Statement.fragmentStats s).add (Statement.fragmentStatsList rest)

end

/-- Aggregate a function body's stats. -/
def CompiledFunction.fragmentStats (fn : CompiledFunction) : FragmentStats :=
  Statement.fragmentStatsList fn.body

/-- Build a count-based confidential-fragment witness directly from a
structured function. Mirrors
`CompiledFunction::confidential_fragment_entrypoint_witness` in
`crates/uo-core/src/fragment.rs`. -/
def confidentialFragmentEntrypointWitnessOf
    (fn : CompiledFunction) : ConfidentialFragmentEntrypointWitness :=
  let stats := fn.fragmentStats
  { entrypointId := fn.signature
  , selectCount := stats.selectCount
  , structFieldCount := stats.structFieldCount
  , arrayIndexCount := stats.arrayIndexCount
  , nonBranchlessSelectArmCount := stats.nonBranchlessSelectArmCount
  }

/-! ### Characterization theorem: count-validity ↔ structural validity

The W4.3 deliverable: the count-based confidential-fragment witness
is `Valid` iff the function body satisfies the structural fragment-
validity predicate. The proof goes via per-expression and per-
statement iff lemmas, lifted through the function body.

Proofs use mutual recursive `theorem` blocks (paired with the list
companions) because Lean 4.30's `induction` tactic does not handle
nested-inductive `Expr` / `Statement` types directly.
-/

/-- The forbidden structural count is zero. Struct projection and local
fixed-array indexing remain counted for auditability, but are admitted by
the proof-grade fragment when their subexpressions are admitted. -/
def FragmentStats.forbidden_zero (s : FragmentStats) : Prop :=
  s.nonBranchlessSelectArmCount = 0

@[simp] theorem FragmentStats.forbidden_zero_empty :
    FragmentStats.empty.forbidden_zero := by
  simp [FragmentStats.forbidden_zero, FragmentStats.empty]

/-- The forbidden-construct counts on a sum split additively. -/
@[simp] theorem FragmentStats.forbidden_zero_add
    {lhs rhs : FragmentStats} :
    (lhs.add rhs).forbidden_zero ↔ lhs.forbidden_zero ∧ rhs.forbidden_zero := by
  simp only [FragmentStats.forbidden_zero, FragmentStats.add]
  constructor
  · intro h
    omega
  · rintro ⟨hLNB, hRNB⟩
    omega

/-- The forbidden structural count on a sum splits additively (long form).
Retained for backwards compatibility with the W4.3 definitions commit;
new lemmas should prefer `forbidden_zero_add`. -/
@[simp] theorem FragmentStats.add_zero_forbidden_iff
    {lhs rhs : FragmentStats} :
    (lhs.add rhs).nonBranchlessSelectArmCount = 0 ↔
      lhs.nonBranchlessSelectArmCount = 0 ∧
        rhs.nonBranchlessSelectArmCount = 0 := by
  have h := @FragmentStats.forbidden_zero_add lhs rhs
  simpa [FragmentStats.forbidden_zero] using h

mutual

/-- Per-expression characterization: the stats are forbidden-free iff
the expression is structurally fragment-valid. Mutually recursive with
the list companion to handle the nested `List Expr` inside
`Expr.keccak256`. -/
theorem Expr.fragmentStats_valid_iff :
    ∀ e : Expr, e.fragmentStats.forbidden_zero ↔ e.fragmentValid = true
  | .literal _ => by
      simp [Expr.fragmentStats, Expr.fragmentValid]
  | .var _ => by
      simp [Expr.fragmentStats, Expr.fragmentValid]
  | .unary _ inner => by
      simp only [Expr.fragmentStats, Expr.fragmentValid]
      exact Expr.fragmentStats_valid_iff inner
  | .binary _ lhs rhs => by
      simp only [Expr.fragmentStats, Expr.fragmentValid,
        FragmentStats.forbidden_zero_add, Bool.and_eq_true]
      rw [Expr.fragmentStats_valid_iff lhs, Expr.fragmentStats_valid_iff rhs]
  | .select condE wt wf => by
      have ihC := Expr.fragmentStats_valid_iff condE
      have ihT := Expr.fragmentStats_valid_iff wt
      have ihF := Expr.fragmentStats_valid_iff wf
      cases hAnd : branchlessPureExpr wt && branchlessPureExpr wf with
      | true =>
        have hBPwt : branchlessPureExpr wt = true := by
          cases hWt : branchlessPureExpr wt
          · simp [hWt] at hAnd
          · rfl
        have hBPwf : branchlessPureExpr wf = true := by
          cases hWf : branchlessPureExpr wf
          · simp [hBPwt, hWf] at hAnd
          · rfl
        constructor
        · intro hForbidden
          have hCv : Expr.fragmentValid condE = true := by
            apply ihC.mp
            simp only [Expr.fragmentStats, FragmentStats.forbidden_zero,
              FragmentStats.add, hAnd, _root_.cond] at hForbidden
            simp only [Nat.add_eq_zero_iff] at hForbidden
            simpa [FragmentStats.forbidden_zero] using hForbidden.1.1.1
          have hTv : Expr.fragmentValid wt = true := by
            apply ihT.mp
            simp only [Expr.fragmentStats, FragmentStats.forbidden_zero,
              FragmentStats.add, hAnd, _root_.cond] at hForbidden
            simp only [Nat.add_eq_zero_iff] at hForbidden
            simpa [FragmentStats.forbidden_zero] using hForbidden.1.1.2
          have hFv : Expr.fragmentValid wf = true := by
            apply ihF.mp
            simp only [Expr.fragmentStats, FragmentStats.forbidden_zero,
              FragmentStats.add, hAnd, _root_.cond] at hForbidden
            simp only [Nat.add_eq_zero_iff] at hForbidden
            simpa [FragmentStats.forbidden_zero] using hForbidden.1.2
          simp [Expr.fragmentValid, hCv, hTv, hFv, hBPwt, hBPwf]
        · intro hValid
          have hValidUnfold :
              Expr.fragmentValid condE = true ∧
              Expr.fragmentValid wt = true ∧
              Expr.fragmentValid wf = true := by
            cases hC : Expr.fragmentValid condE <;>
              cases hT : Expr.fragmentValid wt <;>
              cases hF : Expr.fragmentValid wf <;>
              simp [Expr.fragmentValid, hC, hT, hF, hBPwt, hBPwf] at hValid <;>
              first | (exact ⟨rfl, rfl, rfl⟩) | (cases hValid)
          rcases hValidUnfold with ⟨hCv, hTv, hFv⟩
          have hC := ihC.mpr hCv
          have hT := ihT.mpr hTv
          have hF := ihF.mpr hFv
          simp only [Expr.fragmentStats, FragmentStats.forbidden_zero,
            FragmentStats.add, hAnd, _root_.cond]
          simp only [FragmentStats.forbidden_zero] at hC hT hF
          simp [hC, hT, hF]
      | false =>
        simp only [Expr.fragmentStats, Expr.fragmentValid,
          FragmentStats.forbidden_zero, FragmentStats.add,
          hAnd, _root_.cond]
        constructor
        · intro hArm
          simp at hArm
        · intro hValid
          cases hWt : branchlessPureExpr wt
          · simp [hWt] at hValid
          · cases hWf : branchlessPureExpr wf
            · simp [hWt, hWf] at hValid
            · simp [hWt, hWf] at hAnd
  | .cellGet _ => by
      simp [Expr.fragmentStats, Expr.fragmentValid]
  | .arrayGet _ index => by
      simp only [Expr.fragmentStats, Expr.fragmentValid]
      exact Expr.fragmentStats_valid_iff index
  | .mapGet _ key => by
      simp only [Expr.fragmentStats, Expr.fragmentValid]
      exact Expr.fragmentStats_valid_iff key
  | .structField base _ => by
      simp only [Expr.fragmentStats, Expr.fragmentValid, FragmentStats.forbidden_zero]
      exact Expr.fragmentStats_valid_iff base
  | .arrayIndex base index => by
      have ihB := Expr.fragmentStats_valid_iff base
      have ihI := Expr.fragmentStats_valid_iff index
      simp only [Expr.fragmentStats, Expr.fragmentValid, FragmentStats.forbidden_zero,
        FragmentStats.add, Bool.and_eq_true]
      constructor
      · intro h
        have hParts := Nat.add_eq_zero_iff.mp h
        exact ⟨ihB.mp (by simpa [FragmentStats.forbidden_zero] using hParts.1),
          ihI.mp (by simpa [FragmentStats.forbidden_zero] using hParts.2)⟩
      · rintro ⟨hB, hI⟩
        have hBz := ihB.mpr hB
        have hIz := ihI.mpr hI
        simp only [FragmentStats.forbidden_zero] at hBz hIz
        simp [hBz, hIz]
  | .keccak256 parts => by
      simp only [Expr.fragmentStats, Expr.fragmentValid]
      exact Expr.fragmentStatsList_valid_iff parts

/-- List companion: the aggregate stats are forbidden-free iff every
expression in the list is structurally fragment-valid. -/
theorem Expr.fragmentStatsList_valid_iff :
    ∀ es : List Expr,
      (Expr.fragmentStatsList es).forbidden_zero ↔
        Expr.fragmentValidList es = true
  | [] => by
      simp [Expr.fragmentStatsList, Expr.fragmentValidList]
  | e :: rest => by
      simp only [Expr.fragmentStatsList, Expr.fragmentValidList,
        FragmentStats.forbidden_zero_add, Bool.and_eq_true]
      rw [Expr.fragmentStats_valid_iff e, Expr.fragmentStatsList_valid_iff rest]

end

mutual

/-- Per-statement characterization: the stats are forbidden-free iff
the statement is structurally fragment-valid. Mutually recursive with
the list companion to handle the nested `List Statement` inside
`Statement.ifStmt` and `Statement.forLoop`. -/
theorem Statement.fragmentStats_valid_iff :
    ∀ s : Statement, s.fragmentStats.forbidden_zero ↔ s.fragmentValid = true
  | .declare _ _ value => by
      simp only [Statement.fragmentStats, Statement.fragmentValid]
      exact Expr.fragmentStats_valid_iff value
  | .assign _ value => by
      simp only [Statement.fragmentStats, Statement.fragmentValid]
      exact Expr.fragmentStats_valid_iff value
  | .require cond => by
      simp only [Statement.fragmentStats, Statement.fragmentValid]
      exact Expr.fragmentStats_valid_iff cond
  | .abortIf cond => by
      simp only [Statement.fragmentStats, Statement.fragmentValid]
      exact Expr.fragmentStats_valid_iff cond
  | .ifStmt cond thenBody elseBody => by
      simp only [Statement.fragmentStats, Statement.fragmentValid,
        FragmentStats.forbidden_zero_add, Bool.and_eq_true]
      rw [Expr.fragmentStats_valid_iff cond,
          Statement.fragmentStatsList_valid_iff thenBody,
          Statement.fragmentStatsList_valid_iff elseBody]
  | .forLoop _ _ start_ end_ body => by
      simp only [Statement.fragmentStats, Statement.fragmentValid,
        FragmentStats.forbidden_zero_add, Bool.and_eq_true]
      rw [Expr.fragmentStats_valid_iff start_,
          Expr.fragmentStats_valid_iff end_,
          Statement.fragmentStatsList_valid_iff body]
  | .cellSet _ value pred => by
      cases pred with
      | none =>
          simp only [Statement.fragmentStats, Statement.fragmentValid,
            FragmentStats.add_zero, Bool.and_true]
          exact Expr.fragmentStats_valid_iff value
      | some p =>
          simp only [Statement.fragmentStats, Statement.fragmentValid,
            FragmentStats.forbidden_zero_add, Bool.and_eq_true]
          rw [Expr.fragmentStats_valid_iff value, Expr.fragmentStats_valid_iff p]
  | .arraySet _ index value pred => by
      cases pred with
      | none =>
          simp only [Statement.fragmentStats, Statement.fragmentValid,
            FragmentStats.add_zero, Bool.and_true,
            FragmentStats.forbidden_zero_add, Bool.and_eq_true]
          rw [Expr.fragmentStats_valid_iff index, Expr.fragmentStats_valid_iff value]
      | some p =>
          simp only [Statement.fragmentStats, Statement.fragmentValid,
            FragmentStats.forbidden_zero_add, Bool.and_eq_true]
          rw [Expr.fragmentStats_valid_iff index, Expr.fragmentStats_valid_iff value,
              Expr.fragmentStats_valid_iff p]
  | .mapPut _ key value pred => by
      cases pred with
      | none =>
          simp only [Statement.fragmentStats, Statement.fragmentValid,
            FragmentStats.add_zero, Bool.and_true,
            FragmentStats.forbidden_zero_add, Bool.and_eq_true]
          rw [Expr.fragmentStats_valid_iff key, Expr.fragmentStats_valid_iff value]
      | some p =>
          simp only [Statement.fragmentStats, Statement.fragmentValid,
            FragmentStats.forbidden_zero_add, Bool.and_eq_true]
          rw [Expr.fragmentStats_valid_iff key, Expr.fragmentStats_valid_iff value,
              Expr.fragmentStats_valid_iff p]
  | .retStmt none => by
      simp [Statement.fragmentStats, Statement.fragmentValid]
  | .retStmt (some value) => by
      simp only [Statement.fragmentStats, Statement.fragmentValid]
      exact Expr.fragmentStats_valid_iff value

/-- List companion: the aggregate stats are forbidden-free iff every
statement in the list is structurally fragment-valid. -/
theorem Statement.fragmentStatsList_valid_iff :
    ∀ ss : List Statement,
      (Statement.fragmentStatsList ss).forbidden_zero ↔
        Statement.fragmentValidList ss = true
  | [] => by
      simp [Statement.fragmentStatsList, Statement.fragmentValidList]
  | s :: rest => by
      simp only [Statement.fragmentStatsList, Statement.fragmentValidList,
        FragmentStats.forbidden_zero_add, Bool.and_eq_true]
      rw [Statement.fragmentStats_valid_iff s,
          Statement.fragmentStatsList_valid_iff rest]

end

/-- Function-level characterization: the count-based confidential-
fragment witness is `Valid` iff the function body is structurally
fragment-valid. -/
theorem confidentialFragmentEntrypointWitnessOf_valid_iff
    (fn : CompiledFunction) :
    (confidentialFragmentEntrypointWitnessOf fn).Valid ↔
      fn.fragmentValid = true := by
  unfold confidentialFragmentEntrypointWitnessOf
  unfold ConfidentialFragmentEntrypointWitness.Valid
  unfold CompiledFunction.fragmentStats CompiledFunction.fragmentValid
  exact Statement.fragmentStatsList_valid_iff fn.body

end IR

end UOToolchain
