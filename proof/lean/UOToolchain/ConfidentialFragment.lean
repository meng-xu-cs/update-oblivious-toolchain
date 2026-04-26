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
  witness.structFieldCount = 0 ∧
    witness.arrayIndexCount = 0 ∧
    witness.nonBranchlessSelectArmCount = 0

def ConfidentialFragmentEntrypointWitness.checkValid
  (witness : ConfidentialFragmentEntrypointWitness) : Bool :=
  decide (witness.structFieldCount = 0) &&
    decide (witness.arrayIndexCount = 0) &&
    decide (witness.nonBranchlessSelectArmCount = 0)

@[simp] theorem confidentialFragmentEntrypointWitness_checkValid_eq_true_iff
  (witness : ConfidentialFragmentEntrypointWitness) :
  witness.checkValid = true ↔ witness.Valid := by
  simp [ConfidentialFragmentEntrypointWitness.checkValid,
    ConfidentialFragmentEntrypointWitness.Valid, and_assoc]

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
  fragment: literals, vars, `unary`, `binary`, `select`, and
  `keccak256` whose subterms are all branchless-pure. Cell, array,
  and map reads, struct-field navigation, and array-index navigation
  are all rejected. This mirrors the kernel-DSL pure expression
  surface in `crates/uo-core/src/confidential_kernel.rs`.
* `IR.Expr.fragmentValid` and `IR.Statement.fragmentValid` decide
  the structural validity of an expression / statement: no
  `Expr.structField` anywhere, no `Expr.arrayIndex` anywhere, and
  every `Expr.select` whose arms are not branchless-pure.
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
  | .structField _ _ => false
  | .arrayIndex _ _ => false
  | .keccak256 parts => branchlessPureExprList parts

def branchlessPureExprList : List Expr → Bool
  | [] => true
  | e :: rest => branchlessPureExpr e && branchlessPureExprList rest

end

mutual

/-- An expression is *fragment-valid* when it contains no
`Expr.structField` anywhere, no `Expr.arrayIndex` anywhere, and every
`Expr.select` has both arms branchless-pure. This is the structural
counterpart to "the count-based witness reports zero forbidden
constructs." -/
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
  | .structField _ _ => false
  | .arrayIndex _ _ => false
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
        if branchlessPureExpr whenTrue && branchlessPureExpr whenFalse then 0 else 1
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

/-! ### Helper lemmas for the deferred characterization theorem

The W4.3 characterization theorem
`(confidentialFragmentEntrypointWitnessOf fn).Valid ↔ fn.fragmentValid`
is deferred to a follow-up commit because the natural proof strategy
is structural induction on `Expr` / `Statement`, which Lean 4's
default `induction` tactic does not yet support for the nested-
inductive `Expr` / `Statement` types defined in `IRSyntax.lean`.
A follow-up commit will use `Expr.recOn` / `Statement.recOn` directly
or restructure the IR types as explicitly mutual inductives so the
induction tactic applies. The `add_zero_forbidden_iff` simp lemma
below is the additive-split primitive that proof will rely on.
-/

/-- The forbidden-construct counts on a sum split additively. -/
@[simp] theorem FragmentStats.add_zero_forbidden_iff
    {lhs rhs : FragmentStats} :
    (lhs.add rhs).structFieldCount = 0 ∧
        (lhs.add rhs).arrayIndexCount = 0 ∧
        (lhs.add rhs).nonBranchlessSelectArmCount = 0 ↔
      (lhs.structFieldCount = 0 ∧ lhs.arrayIndexCount = 0 ∧
          lhs.nonBranchlessSelectArmCount = 0) ∧
        (rhs.structFieldCount = 0 ∧ rhs.arrayIndexCount = 0 ∧
          rhs.nonBranchlessSelectArmCount = 0) := by
  simp only [FragmentStats.add]
  constructor
  · rintro ⟨hSF, hAI, hNB⟩
    refine ⟨⟨?_, ?_, ?_⟩, ?_, ?_, ?_⟩ <;> omega
  · rintro ⟨⟨hLSF, hLAI, hLNB⟩, hRSF, hRAI, hRNB⟩
    refine ⟨?_, ?_, ?_⟩ <;> omega

end IR

end UOToolchain
