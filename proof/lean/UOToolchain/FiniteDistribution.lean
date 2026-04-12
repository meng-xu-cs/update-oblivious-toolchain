namespace UOToolchain

structure FiniteDistribution (α : Type) where
  samples : List α
deriving Repr, DecidableEq

namespace FiniteDistribution

def concat : List (List α) → List α
  | [] => []
  | head :: tail => head ++ concat tail

def pure (value : α) : FiniteDistribution α :=
  { samples := [value] }

def map (f : α → β) (dist : FiniteDistribution α) : FiniteDistribution β :=
  { samples := dist.samples.map f }

def productWith
  (lhs : FiniteDistribution α)
  (rhs : FiniteDistribution β)
  (f : α → β → γ) :
  FiniteDistribution γ :=
  { samples := concat (lhs.samples.map fun left => rhs.samples.map (f left)) }

def chooseNat (bound : Nat) : FiniteDistribution Nat :=
  { samples := List.range bound }

@[simp] theorem samples_pure (value : α) :
    (pure value).samples = [value] := by
  rfl

@[simp] theorem samples_map (f : α → β) (dist : FiniteDistribution α) :
    (map f dist).samples = dist.samples.map f := by
  rfl

@[simp] theorem samples_productWith
  (lhs : FiniteDistribution α)
  (rhs : FiniteDistribution β)
  (f : α → β → γ) :
    (productWith lhs rhs f).samples =
      concat (lhs.samples.map fun left => rhs.samples.map (f left)) := by
  rfl

@[simp] theorem samples_chooseNat (bound : Nat) :
    (chooseNat bound).samples = List.range bound := by
  rfl

end FiniteDistribution

end UOToolchain
