import UOToolchain.PathOramTreeShape

namespace UOToolchain.PathOramAvlMap

/-!
# The private scheme's AVL map

`path_oram_private_posmap_v1` keeps a map as an AVL tree whose nodes are
Path ORAM blocks (`tree_get` and `tree_put` in
`runtime/uo-evm/src/generated_oram_codecs.rs`). This file models its
operations over inductive trees, with the runtime's steps: a get walks the
key's path for a fixed number of levels; a put walks it too (a delete of a
node with two children going on to its successor), changes the tree at the
bottom of the walk, and rebalances from there up to the root, rotating a node
whose children's heights differ by two, double when the taller child leans
the other way. Keys and values are numbers; a zero value deletes.

What is proved: with the walk bounded by the capacity's largest AVL height
(`pathOramTreeAvlHeight`), a get returns the key's value and a put writes,
updates or deletes it, keeps the tree sorted and balanced, and keeps the
size within the capacity, an insert into a full map overflowing and changing
nothing (`get_spec`, `put_spec`). The bound suffices because a balanced tree
of at most `capacity` nodes is no taller (`height_le_avlHeight`). Each
operation makes its fixed number of node accesses (`getAccesses_length`,
`putAccesses_length`).

The model has no node ids, leaves or stash: those are the runtime's pointer
level, which `checkPathOramAvlMapReplay` checks against this model by
replaying runtime operations, not by proof.
-/

/-- A tree map: a leaf, or a node with a left subtree, a key, a value and a
right subtree. -/
inductive Tree where
  | leaf
  | node (left : Tree) (key value : Nat) (right : Tree)
  deriving Repr, DecidableEq, Inhabited

namespace Tree

/-- The height, counted in nodes. -/
def height : Tree → Nat
  | leaf => 0
  | node l _ _ r => max l.height r.height + 1

def size : Tree → Nat
  | leaf => 0
  | node l _ _ r => l.size + r.size + 1

/-- The entries in key order. -/
def toList : Tree → List (Nat × Nat)
  | leaf => []
  | node l k v r => l.toList ++ (k, v) :: r.toList

def present : Tree → Bool
  | leaf => false
  | node .. => true

def key : Tree → Nat
  | leaf => 0
  | node _ k _ _ => k

def value : Tree → Nat
  | leaf => 0
  | node _ _ v _ => v

def leftChild : Tree → Tree
  | leaf => leaf
  | node l _ _ _ => l

def rightChild : Tree → Tree
  | leaf => leaf
  | node _ _ _ r => r

/-- The node with its entry replaced. -/
def withEntry : Tree → Nat → Nat → Tree
  | leaf, _, _ => leaf
  | node l _ _ r, k, v => node l k v r

/-- What replaces a deleted node with at most one child: that child. -/
def oneChild : Tree → Tree
  | leaf => leaf
  | node l _ _ r => if l.present then l else r

/-- Every node's children differ in height by at most one. -/
def Balanced : Tree → Prop
  | leaf => True
  | node l _ _ r => l.Balanced ∧ r.Balanced ∧ l.height ≤ r.height + 1 ∧ r.height ≤ l.height + 1

/-- The keys strictly increase in key order. -/
def Sorted (t : Tree) : Prop :=
  t.toList.Pairwise fun a b => a.1 < b.1

/-- The map the tree holds. -/
def lookup (t : Tree) (x : Nat) : Option Nat :=
  t.toList.lookup x

end Tree

open Tree

/-! ## Rebalancing -/

/-- A node whose left child is two taller: a single right rotation, or a
left-right double rotation when the left child leans right. -/
def fixLeft (l : Tree) (k v : Nat) (r : Tree) : Tree :=
  match l with
  | node ll lk lv lr =>
      if ll.height < lr.height then
        match lr with
        | node lrl lrk lrv lrr => node (node ll lk lv lrl) lrk lrv (node lrr k v r)
        | leaf => node l k v r
      else node ll lk lv (node lr k v r)
  | leaf => node l k v r

/-- A node whose right child is two taller: a single left rotation, or a
right-left double rotation when the right child leans left. -/
def fixRight (l : Tree) (k v : Nat) (r : Tree) : Tree :=
  match r with
  | node rl rk rv rr =>
      if rr.height < rl.height then
        match rl with
        | node rll rlk rlv rlr => node (node l k v rll) rlk rlv (node rlr rk rv rr)
        | leaf => node l k v r
      else node (node l k v rl) rk rv rr
  | leaf => node l k v r

/-- The runtime's rebalance step: rotate a node whose children's heights
differ by two or more, toward the shorter side. -/
def balanceNode (l : Tree) (k v : Nat) (r : Tree) : Tree :=
  if r.height + 2 ≤ l.height then fixLeft l k v r
  else if l.height + 2 ≤ r.height then fixRight l k v r
  else node l k v r

/-- A node of the walk takes `sub` on the side the walk went from it. -/
def plug : Tree → Bool → Tree → Tree
  | leaf, _, sub => sub
  | node l k v r, goLeft, sub => if goLeft then node sub k v r else node l k v sub

/-- The same, rebalanced. -/
def plugBalance : Tree → Bool → Tree → Tree
  | leaf, _, sub => sub
  | node l k v r, goLeft, sub => if goLeft then balanceNode sub k v r else balanceNode l k v sub

/-! ## The operations -/

/-- A get: walk at most `fuel` levels from the root toward the key. Returns
its value, zero if absent, and whether it is present. -/
def get (x : Nat) : Nat → Tree → Nat × Bool
  | 0, _ => (0, false)
  | _ + 1, leaf => (0, false)
  | fuel + 1, node l k v r =>
      if x = k then (v, true) else if x < k then get x fuel l else get x fuel r

/-- The leftmost path from a node: each node with the walk going left, at
most `fuel` levels. -/
def leftSpine : Nat → Tree → List (Tree × Bool)
  | 0, _ => []
  | _ + 1, leaf => []
  | fuel + 1, node l k v r => (node l k v r, true) :: leftSpine fuel l

/-- A put's walk, at most `fuel` levels: the nodes it visits from the root
down, each with whether the walk goes left from it, and, if it finds the key,
the key's level and whether that node has two children. A delete of a node
with two children goes on to its successor, the leftmost node of its right
subtree. -/
def walk (x : Nat) (deleteRequest : Bool) : Nat → Tree → List (Tree × Bool) × Option (Nat × Bool)
  | 0, _ => ([], none)
  | _ + 1, leaf => ([], none)
  | fuel + 1, node l k v r =>
      if x = k then
        if deleteRequest && l.present && r.present then
          ((node l k v r, false) :: leftSpine fuel r, some (0, true))
        else ([(node l k v r, false)], some (0, l.present && r.present))
      else if x < k then
        let w := walk x deleteRequest fuel l
        ((node l k v r, true) :: w.1, w.2.map fun f => (f.1 + 1, f.2))
      else
        let w := walk x deleteRequest fuel r
        ((node l k v r, false) :: w.1, w.2.map fun f => (f.1 + 1, f.2))

/-- Rebalance up a walk's levels, deepest first: each takes the new subtree
below it and is rebalanced. The result is the new root. -/
def rebuild : List (Tree × Bool) → Tree → Tree
  | [], sub => sub
  | (t, goLeft) :: rest, sub => plugBalance t goLeft (rebuild rest sub)

/-- The same without rebalancing, for a put that changes no structure. -/
def rebuildPlain : List (Tree × Bool) → Tree → Tree
  | [], sub => sub
  | (t, goLeft) :: rest, sub => plug t goLeft (rebuildPlain rest sub)

/-- A put's outcome: the tree, the map's size, and whether an insert found
the map full. -/
structure PutResult where
  tree : Tree
  size : Nat
  overflow : Bool
  deriving Repr, DecidableEq

/-- A put of `value` to `x`, if `apply`: an insert or an update, or a delete
when `value` is zero. It walks at most `fuel` levels; an insert attaches a
node at the bottom of the walk, an update rewrites the found node's value, a
delete removes the found node or, when it has two children, moves its
successor's entry into it and removes the successor; then the levels above
the change are rebalanced. An insert into a map of `capacity` keys
overflows and changes nothing. -/
def put (capacity fuel : Nat) (t : Tree) (size x value : Nat) (apply : Bool) : PutResult :=
  let w := walk x (apply && value == 0) fuel t
  match w.2 with
  | none =>
      if apply && value != 0 then
        if size < capacity then
          { tree := rebuild w.1 (node leaf x value leaf), size := size + 1, overflow := false }
        else { tree := t, size := size, overflow := true }
      else { tree := t, size := size, overflow := false }
  | some (level, twoChildren) =>
      let found := (w.1.getD level (leaf, false)).1
      if !apply then { tree := t, size := size, overflow := false }
      else if value != 0 then
        { tree := rebuildPlain (w.1.take level) (found.withEntry x value), size := size,
          overflow := false }
      else if twoChildren then
        let successor := (w.1.getLastD (leaf, false)).1
        { tree := rebuild ((w.1.dropLast).modify level fun e =>
              (e.1.withEntry successor.key successor.value, e.2)) successor.rightChild,
          size := size - 1, overflow := false }
      else
        { tree := rebuild (w.1.take level) found.oneChild, size := size - 1, overflow := false }


/-! ## The rebalance step keeps a tree balanced -/

theorem toList_fixLeft (l : Tree) (k v : Nat) (r : Tree) :
    (fixLeft l k v r).toList = l.toList ++ (k, v) :: r.toList := by
  unfold fixLeft
  split
  · split
    · split <;> simp [toList, List.append_assoc]
    · simp [toList, List.append_assoc]
  · rfl

theorem toList_fixRight (l : Tree) (k v : Nat) (r : Tree) :
    (fixRight l k v r).toList = l.toList ++ (k, v) :: r.toList := by
  unfold fixRight
  split
  · split
    · split <;> simp [toList, List.append_assoc]
    · simp [toList, List.append_assoc]
  · rfl

theorem toList_balanceNode (l : Tree) (k v : Nat) (r : Tree) :
    (balanceNode l k v r).toList = l.toList ++ (k, v) :: r.toList := by
  unfold balanceNode
  split
  · exact toList_fixLeft l k v r
  · split
    · exact toList_fixRight l k v r
    · rfl

theorem size_fixLeft (l : Tree) (k v : Nat) (r : Tree) :
    (fixLeft l k v r).size = l.size + r.size + 1 := by
  unfold fixLeft
  split
  · split
    · split <;> simp [size] <;> omega
    · simp [size]; omega
  · rfl

theorem size_fixRight (l : Tree) (k v : Nat) (r : Tree) :
    (fixRight l k v r).size = l.size + r.size + 1 := by
  unfold fixRight
  split
  · split
    · split <;> simp [size] <;> omega
    · simp [size]; omega
  · rfl

theorem size_balanceNode (l : Tree) (k v : Nat) (r : Tree) :
    (balanceNode l k v r).size = l.size + r.size + 1 := by
  unfold balanceNode
  split
  · exact size_fixLeft l k v r
  · split
    · exact size_fixRight l k v r
    · rfl

/-- A rotation at a node whose left child is two taller balances it; its
height is the left child's or one more. -/
theorem fixLeft_spec {l r : Tree} {k v : Nat} (hl : l.Balanced) (hr : r.Balanced)
    (hh : l.height = r.height + 2) :
    (fixLeft l k v r).Balanced ∧ l.height ≤ (fixLeft l k v r).height ∧
      (fixLeft l k v r).height ≤ l.height + 1 := by
  match l, hl, hh with
  | node ll lk lv lr, ⟨hll, hlr, h1, h2⟩, hh =>
    unfold fixLeft
    simp only [height] at hh
    by_cases hlt : ll.height < lr.height
    · simp only [hlt, if_true]
      match lr, hlr, hlt, h1, h2, hh with
      | node lrl lrk lrv lrr, ⟨hlrl, hlrr, h3, h4⟩, hlt, h1, h2, hh =>
        simp only [height] at *
        refine ⟨⟨⟨hll, hlrl, ?_, ?_⟩, ⟨hlrr, hr, ?_, ?_⟩, ?_, ?_⟩, ?_, ?_⟩ <;> (try simp only [height]) <;> omega
      | leaf, _, hlt, _, _, _ => simp [height] at hlt
    · simp only [hlt, if_false]
      refine ⟨⟨hll, ⟨hlr, hr, ?_, ?_⟩, ?_, ?_⟩, ?_, ?_⟩ <;> simp only [height] at * <;> omega
  | leaf, _, hh => simp [height] at hh

theorem fixRight_spec {l r : Tree} {k v : Nat} (hl : l.Balanced) (hr : r.Balanced)
    (hh : r.height = l.height + 2) :
    (fixRight l k v r).Balanced ∧ r.height ≤ (fixRight l k v r).height ∧
      (fixRight l k v r).height ≤ r.height + 1 := by
  match r, hr, hh with
  | node rl rk rv rr, ⟨hrl, hrr, h1, h2⟩, hh =>
    unfold fixRight
    simp only [height] at hh
    by_cases hlt : rr.height < rl.height
    · simp only [hlt, if_true]
      match rl, hrl, hlt, h1, h2, hh with
      | node rll rlk rlv rlr, ⟨hrll, hrlr, h3, h4⟩, hlt, h1, h2, hh =>
        simp only [height] at *
        refine ⟨⟨⟨hl, hrll, ?_, ?_⟩, ⟨hrlr, hrr, ?_, ?_⟩, ?_, ?_⟩, ?_, ?_⟩ <;> (try simp only [height]) <;> omega
      | leaf, _, hlt, _, _, _ => simp [height] at hlt
    · simp only [hlt, if_false]
      refine ⟨⟨⟨hl, hrl, ?_, ?_⟩, hrr, ?_, ?_⟩, ?_, ?_⟩ <;> simp only [height] at * <;> omega
  | leaf, _, hh => simp [height] at hh

/-- The rebalance step on children that differ in height by at most two:
the node is balanced; it is the plain node when they differ by at most one,
and otherwise as tall as the taller child or one more. -/
theorem balanceNode_spec {l r : Tree} {k v : Nat} (hl : l.Balanced) (hr : r.Balanced)
    (h1 : l.height ≤ r.height + 2) (h2 : r.height ≤ l.height + 2) :
    (balanceNode l k v r).Balanced ∧
      (l.height ≤ r.height + 1 → r.height ≤ l.height + 1 → balanceNode l k v r = node l k v r) ∧
      (l.height = r.height + 2 →
        l.height ≤ (balanceNode l k v r).height ∧ (balanceNode l k v r).height ≤ l.height + 1) ∧
      (r.height = l.height + 2 →
        r.height ≤ (balanceNode l k v r).height ∧ (balanceNode l k v r).height ≤ r.height + 1) := by
  unfold balanceNode
  by_cases hL : r.height + 2 ≤ l.height
  · have hh : l.height = r.height + 2 := by omega
    have := fixLeft_spec (k := k) (v := v) hl hr hh
    simp only [hL, if_true]
    exact ⟨this.1, fun a _ => by omega, fun _ => this.2, fun _ => by omega⟩
  · simp only [hL, if_false]
    by_cases hR : l.height + 2 ≤ r.height
    · have hh : r.height = l.height + 2 := by omega
      have := fixRight_spec (k := k) (v := v) hl hr hh
      simp only [hR, if_true]
      exact ⟨this.1, fun _ b => by omega, fun _ => by omega, fun _ => this.2⟩
    · simp only [hR, if_false]
      exact ⟨⟨hl, hr, by omega, by omega⟩, by simp, fun _ => by omega, fun _ => by omega⟩


/-! ## Sorted entry lists -/

/-- Keys strictly increase. -/
abbrev SortedList (xs : List (Nat × Nat)) : Prop := xs.Pairwise fun a b => a.1 < b.1

theorem lookup_cons' (x k v : Nat) (xs : List (Nat × Nat)) :
    ((k, v) :: xs).lookup x = if x = k then some v else xs.lookup x := by
  simp [List.lookup]; split <;> simp_all

theorem lookup_eq_none {xs : List (Nat × Nat)} {x : Nat} (h : ∀ e ∈ xs, e.1 ≠ x) :
    xs.lookup x = none := by
  induction xs with
  | nil => rfl
  | cons e rest ih =>
    obtain ⟨k, v⟩ := e
    rw [lookup_cons']
    have hk : x ≠ k := fun hx => h (k, v) (by simp) hx.symm
    simp only [hk, if_false]
    exact ih fun e he => h e (by simp [he])

theorem bounds_of_sorted {lo hi : List (Nat × Nat)} {x v : Nat}
    (hs : SortedList (lo ++ (x, v) :: hi)) :
    (∀ e ∈ lo, e.1 < x) ∧ (∀ e ∈ hi, x < e.1) ∧ SortedList (lo ++ hi) := by
  unfold SortedList at *
  rw [List.pairwise_append, List.pairwise_cons] at hs
  obtain ⟨hlo, ⟨hx, hhi⟩, hcross⟩ := hs
  refine ⟨fun e he => hcross e he (x, v) (by simp), hx, ?_⟩
  rw [List.pairwise_append]
  exact ⟨hlo, hhi, fun a ha b hb => hcross a ha b (by simp [hb])⟩

theorem sorted_insert_mid {lo hi : List (Nat × Nat)} {x v : Nat}
    (hs : SortedList (lo ++ hi)) (hlo : ∀ e ∈ lo, e.1 < x) (hhi : ∀ e ∈ hi, x < e.1) :
    SortedList (lo ++ (x, v) :: hi) := by
  unfold SortedList at *
  rw [List.pairwise_append] at hs ⊢
  obtain ⟨h1, h2, h3⟩ := hs
  refine ⟨h1, List.pairwise_cons.2 ⟨hhi, h2⟩, ?_⟩
  intro a ha b hb
  simp only [List.mem_cons] at hb
  rcases hb with rfl | hb
  · exact hlo a ha
  · exact h3 a ha b hb

theorem lookup_insert_mid {lo hi : List (Nat × Nat)} {x v : Nat}
    (hlo : ∀ e ∈ lo, e.1 < x) (hhi : ∀ e ∈ hi, x < e.1) (y : Nat) :
    (lo ++ (x, v) :: hi).lookup y = if y = x then some v else (lo ++ hi).lookup y := by
  rw [List.lookup_append, List.lookup_append, lookup_cons']
  by_cases hy : y = x
  · subst hy
    rw [lookup_eq_none (fun e he => Nat.ne_of_lt (hlo e he))]
    simp
  · simp [hy]

theorem lookup_remove_mid {lo hi : List (Nat × Nat)} {x v : Nat}
    (hs : SortedList (lo ++ (x, v) :: hi)) (y : Nat) :
    (lo ++ hi).lookup y = if y = x then none else (lo ++ (x, v) :: hi).lookup y := by
  obtain ⟨hlo, hhi, _⟩ := bounds_of_sorted hs
  rw [lookup_insert_mid hlo hhi y]
  by_cases hy : y = x
  · subst hy
    simp only [if_true]
    apply lookup_eq_none
    intro e he
    simp only [List.mem_append] at he
    rcases he with he | he
    · exact Nat.ne_of_lt (hlo e he)
    · exact Nat.ne_of_gt (hhi e he)
  · simp [hy]

/-! ## The tree's entries -/

theorem Tree.sorted_node {l r : Tree} {k v : Nat} (h : (node l k v r).Sorted) :
    l.Sorted ∧ r.Sorted ∧ (∀ e ∈ l.toList, e.1 < k) ∧ (∀ e ∈ r.toList, k < e.1) := by
  unfold Sorted at *
  simp only [toList] at h
  have hb := bounds_of_sorted h
  rw [List.pairwise_append] at h
  exact ⟨h.1, (List.pairwise_cons.1 h.2.1).2, hb.1, hb.2.1⟩

theorem Tree.size_eq_length (t : Tree) : t.size = t.toList.length := by
  induction t with
  | leaf => rfl
  | node l k v r ihl ihr => simp [size, toList, ihl, ihr]; omega

/-- The entry of a key in a sorted node: the node's own, or in the subtree
on the key's side. -/
theorem Tree.mem_node_sorted {l r : Tree} {k v x w : Nat} (hs : (node l k v r).Sorted)
    (hm : (x, w) ∈ (node l k v r).toList) :
    (x = k ∧ w = v) ∨ (x < k ∧ (x, w) ∈ l.toList) ∨ (k < x ∧ (x, w) ∈ r.toList) := by
  obtain ⟨_, _, hlk, hrk⟩ := Tree.sorted_node hs
  simp only [toList, List.mem_append, List.mem_cons, Prod.mk.injEq] at hm
  rcases hm with hm | hm | hm
  · exact Or.inr (Or.inl ⟨hlk _ hm, hm⟩)
  · exact Or.inl hm
  · exact Or.inr (Or.inr ⟨hrk _ hm, hm⟩)

/-! ## A level's change, rebalanced -/

/-- A node whose left subtree changed height by at most one, rebalanced: it
is balanced and its height changed by at most one. -/
theorem balanceNode_changeLeft {l l' r : Tree} {k v k' v' : Nat}
    (hbal : (node l k v r).Balanced) (hl' : l'.Balanced)
    (h1 : l'.height ≤ l.height + 1) (h2 : l.height ≤ l'.height + 1) :
    (balanceNode l' k' v' r).Balanced ∧
      (balanceNode l' k' v' r).height ≤ (node l k v r).height + 1 ∧
      (node l k v r).height ≤ (balanceNode l' k' v' r).height + 1 := by
  obtain ⟨_, hr, a, b⟩ := hbal
  obtain ⟨hb, heq, hL, hR⟩ := balanceNode_spec (k := k') (v := v') hl' hr (by omega) (by omega)
  refine ⟨hb, ?_⟩
  simp only [height]
  by_cases c1 : l'.height ≤ r.height + 1
  · by_cases c2 : r.height ≤ l'.height + 1
    · rw [heq c1 c2]; simp only [height]; omega
    · have := hR (by omega); omega
  · have := hL (by omega); omega

theorem balanceNode_changeRight {l r r' : Tree} {k v k' v' : Nat}
    (hbal : (node l k v r).Balanced) (hr' : r'.Balanced)
    (h1 : r'.height ≤ r.height + 1) (h2 : r.height ≤ r'.height + 1) :
    (balanceNode l k' v' r').Balanced ∧
      (balanceNode l k' v' r').height ≤ (node l k v r).height + 1 ∧
      (node l k v r).height ≤ (balanceNode l k' v' r').height + 1 := by
  obtain ⟨hl, _, a, b⟩ := hbal
  obtain ⟨hb, heq, hL, hR⟩ := balanceNode_spec (k := k') (v := v') hl hr' (by omega) (by omega)
  refine ⟨hb, ?_⟩
  simp only [height]
  by_cases c1 : l.height ≤ r'.height + 1
  · by_cases c2 : r'.height ≤ l.height + 1
    · rw [heq c1 c2]; simp only [height]; omega
    · have := hR (by omega); omega
  · have := hL (by omega); omega

/-! ## Insert, update and delete, recursively

The runtime's put walks down and then rebalances up; these are the same
steps as recursions, the proof's route to the put's semantics
(`put_eq`). -/

/-- Insert a key that is absent. -/
def insertRec (x value : Nat) : Tree → Tree
  | leaf => node leaf x value leaf
  | node l k v r =>
      if x < k then balanceNode (insertRec x value l) k v r
      else balanceNode l k v (insertRec x value r)

/-- Rewrite the value of a key that is present. -/
def updateRec (x value : Nat) : Tree → Tree
  | leaf => leaf
  | node l k v r =>
      if x = k then node l k value r
      else if x < k then node (updateRec x value l) k v r
      else node l k v (updateRec x value r)

/-- Remove the leftmost node: its entry and the rebalanced rest. -/
def deleteMin : Tree → (Nat × Nat) × Tree
  | leaf => ((0, 0), leaf)
  | node l k v r =>
      if l.present then
        let m := deleteMin l
        (m.1, balanceNode m.2 k v r)
      else ((k, v), r)

/-- Remove a key that is present: a node with two children takes its
successor's entry, and the successor is removed. -/
def deleteRec (x : Nat) : Tree → Tree
  | leaf => leaf
  | node l k v r =>
      if x = k then
        if l.present && r.present then
          let m := deleteMin r
          balanceNode l m.1.1 m.1.2 m.2
        else (node l k v r).oneChild
      else if x < k then balanceNode (deleteRec x l) k v r
      else balanceNode l k v (deleteRec x r)

/-- A node with at most one child, replaced by that child. -/
theorem oneChild_spec {l r : Tree} {k v : Nat} (hbal : (node l k v r).Balanced)
    (h : (l.present && r.present) = false) :
    (node l k v r).oneChild.toList = l.toList ++ r.toList ∧ (node l k v r).oneChild.Balanced ∧
      (node l k v r).oneChild.height + 1 = (node l k v r).height := by
  obtain ⟨hl, hr, a, b⟩ := hbal
  cases l with
  | leaf =>
    refine ⟨by simp [oneChild, present, toList], by simpa [oneChild, present] using hr, ?_⟩
    simp only [oneChild, present, Bool.false_eq_true, ↓reduceIte]
    simp only [height] at a b ⊢
    omega
  | node ll lk lv lr =>
    cases r with
    | leaf =>
      refine ⟨by simp [oneChild, present, toList], by simpa [oneChild, present] using hl, ?_⟩
      simp only [oneChild, present, ↓reduceIte]
      simp only [height] at a b ⊢
      omega
    | node => simp [present] at h

theorem insertRec_balanced (x value : Nat) : ∀ (t : Tree), t.Balanced →
    (insertRec x value t).Balanced ∧ (insertRec x value t).height ≤ t.height + 1 ∧
      t.height ≤ (insertRec x value t).height + 1
  | leaf, _ => by simp [insertRec, Balanced, height]
  | node l k v r, hbal => by
    have ⟨hl, hr, _, _⟩ := hbal
    unfold insertRec
    split
    · obtain ⟨h1, h2, h3⟩ := insertRec_balanced x value l hl
      exact balanceNode_changeLeft hbal h1 h2 h3
    · obtain ⟨h1, h2, h3⟩ := insertRec_balanced x value r hr
      exact balanceNode_changeRight hbal h1 h2 h3

theorem insertRec_toList (x value : Nat) : ∀ (t : Tree), t.Sorted →
    (∀ e ∈ t.toList, e.1 ≠ x) →
    ∃ lo hi, t.toList = lo ++ hi ∧ (insertRec x value t).toList = lo ++ (x, value) :: hi ∧
      (∀ e ∈ lo, e.1 < x) ∧ (∀ e ∈ hi, x < e.1)
  | leaf, _, _ => ⟨[], [], rfl, rfl, by simp, by simp⟩
  | node l k v r, hs, hx => by
    obtain ⟨hsl, hsr, hlk, hrk⟩ := Tree.sorted_node hs
    have hxk : x ≠ k := fun h => hx (k, v) (by simp [toList]) h.symm
    unfold insertRec
    split
    · rename_i hlt
      obtain ⟨lo, hi, e1, e2, b1, b2⟩ :=
        insertRec_toList x value l hsl (fun e he => hx e (by simp [toList, he]))
      refine ⟨lo, hi ++ (k, v) :: r.toList, ?_, ?_, b1, ?_⟩
      · simp [toList, e1]
      · rw [toList_balanceNode, e2]; simp
      · intro e he
        simp only [List.mem_append, List.mem_cons] at he
        rcases he with he | rfl | he
        · exact b2 e he
        · exact hlt
        · exact Nat.lt_trans hlt (hrk e he)
    · rename_i hge
      have hgt : k < x := by omega
      obtain ⟨lo, hi, e1, e2, b1, b2⟩ :=
        insertRec_toList x value r hsr (fun e he => hx e (by simp [toList, he]))
      refine ⟨l.toList ++ (k, v) :: lo, hi, ?_, ?_, ?_, b2⟩
      · simp [toList, e1]
      · rw [toList_balanceNode, e2]; simp
      · intro e he
        simp only [List.mem_append, List.mem_cons] at he
        rcases he with he | rfl | he
        · exact Nat.lt_trans (hlk e he) hgt
        · exact hgt
        · exact b1 e he

theorem updateRec_shape (x value : Nat) : ∀ (t : Tree),
    (updateRec x value t).height = t.height ∧ (updateRec x value t).size = t.size ∧
      (t.Balanced → (updateRec x value t).Balanced)
  | leaf => by simp [updateRec]
  | node l k v r => by
    obtain ⟨al, bl, cl⟩ := updateRec_shape x value l
    obtain ⟨ar, br, cr⟩ := updateRec_shape x value r
    unfold updateRec
    split
    · exact ⟨rfl, rfl, fun h => h⟩
    · split
      · refine ⟨by simp [height, al], by simp [size, bl], fun ⟨hl, hr, a, b⟩ => ⟨cl hl, hr, ?_, ?_⟩⟩
          <;> omega
      · refine ⟨by simp [height, ar], by simp [size, br], fun ⟨hl, hr, a, b⟩ => ⟨hl, cr hr, ?_, ?_⟩⟩
          <;> omega

theorem updateRec_toList (x value : Nat) : ∀ (t : Tree) (v0 : Nat), t.Sorted →
    (x, v0) ∈ t.toList →
    ∃ lo hi, t.toList = lo ++ (x, v0) :: hi ∧ (updateRec x value t).toList = lo ++ (x, value) :: hi
  | leaf, _, _, hm => by simp [toList] at hm
  | node l k v r, v0, hs, hm => by
    obtain ⟨hsl, hsr, _, _⟩ := Tree.sorted_node hs
    unfold updateRec
    rcases Tree.mem_node_sorted hs hm with ⟨rfl, rfl⟩ | ⟨hlt, hml⟩ | ⟨hgt, hmr⟩
    · exact ⟨l.toList, r.toList, rfl, by simp [toList]⟩
    · have hne : x ≠ k := Nat.ne_of_lt hlt
      obtain ⟨lo, hi, e1, e2⟩ := updateRec_toList x value l v0 hsl hml
      refine ⟨lo, hi ++ (k, v) :: r.toList, ?_, ?_⟩
      · simp [toList, e1]
      · simp [hne, hlt, toList, e2]
    · have hne : x ≠ k := Nat.ne_of_gt hgt
      have hnlt : ¬ x < k := by omega
      obtain ⟨lo, hi, e1, e2⟩ := updateRec_toList x value r v0 hsr hmr
      refine ⟨l.toList ++ (k, v) :: lo, hi, ?_, ?_⟩
      · simp [toList, e1]
      · simp [hne, hnlt, toList, e2]

theorem deleteMin_spec : ∀ (t : Tree), t.present = true → t.Balanced →
    t.toList = (deleteMin t).1 :: (deleteMin t).2.toList ∧ (deleteMin t).2.Balanced ∧
      (deleteMin t).2.height ≤ t.height + 1 ∧ t.height ≤ (deleteMin t).2.height + 1
  | leaf, h, _ => by simp [present] at h
  | node l k v r, _, hbal => by
    have ⟨hl, hr, a, b⟩ := hbal
    unfold deleteMin
    split
    · rename_i hlp
      obtain ⟨e1, e2, e3, e4⟩ := deleteMin_spec l hlp hl
      obtain ⟨f1, f2, f3⟩ := balanceNode_changeLeft (k' := k) (v' := v) hbal e2 e3 e4
      exact ⟨by simp [toList, toList_balanceNode, e1], f1, f2, f3⟩
    · rename_i hlp
      cases l with
      | leaf =>
        refine ⟨by simp [toList], hr, ?_, ?_⟩ <;> simp only [height] at * <;> omega
      | node => simp [present] at hlp

theorem deleteRec_spec (x : Nat) : ∀ (t : Tree) (v0 : Nat), t.Sorted → t.Balanced →
    (x, v0) ∈ t.toList →
    (∃ lo hi, t.toList = lo ++ (x, v0) :: hi ∧ (deleteRec x t).toList = lo ++ hi) ∧
      (deleteRec x t).Balanced ∧ (deleteRec x t).height ≤ t.height + 1 ∧
      t.height ≤ (deleteRec x t).height + 1
  | leaf, _, _, _, hm => by simp [toList] at hm
  | node l k v r, v0, hs, hbal, hm => by
    obtain ⟨hsl, hsr, _, _⟩ := Tree.sorted_node hs
    have ⟨hl, hr, a, b⟩ := hbal
    unfold deleteRec
    rcases Tree.mem_node_sorted hs hm with ⟨rfl, rfl⟩ | ⟨hlt, hml⟩ | ⟨hgt, hmr⟩
    · simp only [if_true]
      split
      · rename_i hboth
        simp only [Bool.and_eq_true] at hboth
        obtain ⟨e1, e2, e3, e4⟩ := deleteMin_spec r hboth.2 hr
        obtain ⟨f1, f2, f3⟩ :=
          balanceNode_changeRight (k' := (deleteMin r).1.1) (v' := (deleteMin r).1.2) hbal e2 e3 e4
        refine ⟨⟨l.toList, r.toList, rfl, ?_⟩, f1, f2, f3⟩
        rw [toList_balanceNode, e1]
      · rename_i hnot
        simp only [Bool.not_eq_true] at hnot
        obtain ⟨o1, o2, o3⟩ := oneChild_spec hbal hnot
        exact ⟨⟨l.toList, r.toList, rfl, o1⟩, o2, by omega, by omega⟩
    · have hne : x ≠ k := Nat.ne_of_lt hlt
      simp only [hne, hlt, if_false, if_true]
      obtain ⟨⟨lo, hi, e1, e2⟩, d1, d2, d3⟩ := deleteRec_spec x l v0 hsl hl hml
      obtain ⟨f1, f2, f3⟩ := balanceNode_changeLeft (k' := k) (v' := v) hbal d1 d2 d3
      refine ⟨⟨lo, hi ++ (k, v) :: r.toList, by simp [toList, e1], ?_⟩, f1, f2, f3⟩
      rw [toList_balanceNode, e2]; simp
    · have hne : x ≠ k := Nat.ne_of_gt hgt
      have hnlt : ¬ x < k := by omega
      simp only [hne, hnlt, if_false]
      obtain ⟨⟨lo, hi, e1, e2⟩, d1, d2, d3⟩ := deleteRec_spec x r v0 hsr hr hmr
      obtain ⟨f1, f2, f3⟩ := balanceNode_changeRight (k' := k) (v' := v) hbal d1 d2 d3
      refine ⟨⟨l.toList ++ (k, v) :: lo, hi, by simp [toList, e1], ?_⟩, f1, f2, f3⟩
      rw [toList_balanceNode, e2]; simp


/-! ## The walk is the recursions' descent -/

theorem getLastD_of_ne_nil {α : Type} {l : List α} (h : l ≠ []) (a b : α) :
    l.getLastD a = l.getLastD b := by
  cases l with
  | nil => exact absurd rfl h
  | cons x xs => simp only [List.getLastD_cons]

theorem walk_found_ne_nil (x : Nat) (d : Bool) : ∀ (fuel : Nat) (t : Tree) (f : Nat × Bool),
    (walk x d fuel t).2 = some f → (walk x d fuel t).1 ≠ []
  | 0, _, _, h => by simp [walk] at h
  | _ + 1, leaf, _, h => by simp [walk] at h
  | fuel + 1, node l k v r, _, _ => by
    simp only [walk]
    split
    · split <;> simp
    · split <;> simp

theorem rebuild_walk_insert (x value : Nat) (d : Bool) : ∀ (fuel : Nat) (t : Tree),
    t.height ≤ fuel → (walk x d fuel t).2 = none →
    rebuild (walk x d fuel t).1 (node leaf x value leaf) = insertRec x value t
  | 0, leaf, _, _ => rfl
  | _ + 1, leaf, _, _ => rfl
  | 0, node l k v r, hh, _ => by simp [height] at hh
  | fuel + 1, node l k v r, hh, hw => by
    simp only [height] at hh
    simp only [walk] at hw ⊢
    by_cases hxk : x = k
    · simp only [hxk, if_true] at hw
      split at hw <;> simp at hw
    · simp only [hxk, if_false] at hw ⊢
      by_cases hlt : x < k
      · simp only [hlt, if_true, Option.map_eq_none_iff] at hw ⊢
        simp only [rebuild, plugBalance, if_true, insertRec, hlt]
        rw [rebuild_walk_insert x value d fuel l (by omega) hw]
      · simp only [hlt, if_false, Option.map_eq_none_iff] at hw ⊢
        simp only [rebuild, plugBalance, Bool.false_eq_true, if_false, insertRec, hlt]
        rw [rebuild_walk_insert x value d fuel r (by omega) hw]

theorem rebuildPlain_walk_update (x value : Nat) (d : Bool) : ∀ (fuel : Nat) (t : Tree)
    (lvl : Nat) (two : Bool), (walk x d fuel t).2 = some (lvl, two) →
    rebuildPlain ((walk x d fuel t).1.take lvl)
        (((walk x d fuel t).1.getD lvl (leaf, false)).1.withEntry x value) = updateRec x value t
  | 0, _, _, _, h => by simp [walk] at h
  | _ + 1, leaf, _, _, h => by simp [walk] at h
  | fuel + 1, node l k v r, lvl, two, hw => by
    simp only [walk] at hw ⊢
    by_cases hxk : x = k
    · subst hxk
      simp only [if_true] at hw ⊢
      by_cases hb : (d && l.present && r.present) = true
      · rw [if_pos hb] at hw ⊢
        simp only [Option.some.injEq, Prod.mk.injEq] at hw
        obtain ⟨rfl, rfl⟩ := hw
        simp [rebuildPlain, withEntry, updateRec]
      · rw [if_neg hb] at hw ⊢
        simp only [Option.some.injEq, Prod.mk.injEq] at hw
        obtain ⟨rfl, _⟩ := hw
        simp [rebuildPlain, withEntry, updateRec]
    · simp only [hxk, if_false] at hw ⊢
      by_cases hlt : x < k
      · simp only [hlt, if_true, Option.map_eq_some_iff] at hw ⊢
        obtain ⟨⟨lvl', two'⟩, hw', he⟩ := hw
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        simp only [List.take_succ_cons, List.getD_cons_succ, rebuildPlain, plug, if_true,
          updateRec, hxk, hlt, if_false]
        rw [rebuildPlain_walk_update x value d fuel l lvl' two' hw']
      · simp only [hlt, if_false, Option.map_eq_some_iff] at hw ⊢
        obtain ⟨⟨lvl', two'⟩, hw', he⟩ := hw
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        simp only [List.take_succ_cons, List.getD_cons_succ, rebuildPlain, plug,
          Bool.false_eq_true, if_false, updateRec, hxk, hlt]
        rw [rebuildPlain_walk_update x value d fuel r lvl' two' hw']

theorem rebuild_walk_deleteOne (x : Nat) : ∀ (fuel : Nat) (t : Tree) (lvl : Nat),
    (walk x true fuel t).2 = some (lvl, false) →
    rebuild ((walk x true fuel t).1.take lvl)
        ((walk x true fuel t).1.getD lvl (leaf, false)).1.oneChild = deleteRec x t
  | 0, _, _, h => by simp [walk] at h
  | _ + 1, leaf, _, h => by simp [walk] at h
  | fuel + 1, node l k v r, lvl, hw => by
    simp only [walk] at hw ⊢
    by_cases hxk : x = k
    · subst hxk
      simp only [if_true, Bool.true_and] at hw ⊢
      by_cases hb : (l.present && r.present) = true
      · rw [if_pos hb] at hw
        simp at hw
      · rw [if_neg hb] at hw ⊢
        simp only [Option.some.injEq, Prod.mk.injEq] at hw
        obtain ⟨rfl, _⟩ := hw
        simp only [List.take_zero, rebuild, deleteRec, if_true]
        rw [if_neg hb]
        rfl
    · simp only [hxk, if_false] at hw ⊢
      by_cases hlt : x < k
      · simp only [hlt, if_true, Option.map_eq_some_iff] at hw ⊢
        obtain ⟨⟨lvl', two'⟩, hw', he⟩ := hw
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        simp only [List.take_succ_cons, List.getD_cons_succ, rebuild, plugBalance, if_true,
          deleteRec, hxk, hlt, if_false]
        rw [rebuild_walk_deleteOne x fuel l lvl' hw']
      · simp only [hlt, if_false, Option.map_eq_some_iff] at hw ⊢
        obtain ⟨⟨lvl', two'⟩, hw', he⟩ := hw
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        simp only [List.take_succ_cons, List.getD_cons_succ, rebuild, plugBalance,
          Bool.false_eq_true, if_false, deleteRec, hxk, hlt]
        rw [rebuild_walk_deleteOne x fuel r lvl' hw']

/-- The successor walk: the left spine of a subtree ends at its leftmost
node, whose removal, rebalanced up the spine, is `deleteMin`. -/
theorem leftSpine_spec : ∀ (fuel : Nat) (r : Tree), r.present = true → r.height ≤ fuel →
    leftSpine fuel r ≠ [] ∧
      rebuild (leftSpine fuel r).dropLast
          ((leftSpine fuel r).getLastD (leaf, false)).1.rightChild = (deleteMin r).2 ∧
      (((leftSpine fuel r).getLastD (leaf, false)).1.key,
          ((leftSpine fuel r).getLastD (leaf, false)).1.value) = (deleteMin r).1
  | _, leaf, h, _ => by simp [present] at h
  | 0, node .., _, hh => by simp [height] at hh
  | fuel + 1, node l k v r, _, hh => by
    simp only [height] at hh
    simp only [leftSpine]
    by_cases hl : l.present = true
    · obtain ⟨ne, e1, e2⟩ := leftSpine_spec fuel l hl (by omega)
      refine ⟨by simp, ?_, ?_⟩
      · rw [List.dropLast_cons_of_ne_nil ne, List.getLastD_cons,
          getLastD_of_ne_nil ne _ (leaf, false)]
        simp only [rebuild, plugBalance, if_true, deleteMin, hl]
        rw [e1]
      · rw [List.getLastD_cons, getLastD_of_ne_nil ne _ (leaf, false), e2]
        simp [deleteMin, hl]
    · cases l with
      | node => simp [present] at hl
      | leaf =>
        have hs : leftSpine fuel leaf = [] := by cases fuel <;> rfl
        simp [hs, rebuild, rightChild, key, value, deleteMin, present]

theorem rebuild_walk_deleteTwo (x : Nat) : ∀ (fuel : Nat) (t : Tree) (lvl : Nat),
    t.height ≤ fuel → (walk x true fuel t).2 = some (lvl, true) →
    rebuild (((walk x true fuel t).1.dropLast).modify lvl fun e =>
        (e.1.withEntry ((walk x true fuel t).1.getLastD (leaf, false)).1.key
          ((walk x true fuel t).1.getLastD (leaf, false)).1.value, e.2))
      ((walk x true fuel t).1.getLastD (leaf, false)).1.rightChild = deleteRec x t
  | 0, _, _, _, h => by simp [walk] at h
  | _ + 1, leaf, _, _, h => by simp [walk] at h
  | fuel + 1, node l k v r, lvl, hh, hw => by
    simp only [height] at hh
    by_cases hxk : x = k
    · subst hxk
      simp only [walk, if_true, Bool.true_and] at hw ⊢
      by_cases hb : (l.present && r.present) = true
      · rw [if_pos hb] at hw ⊢
        have hboth := hb
        simp only [Bool.and_eq_true] at hboth
        simp only [Option.some.injEq, Prod.mk.injEq] at hw
        obtain ⟨rfl, _⟩ := hw
        obtain ⟨ne, e1, e2⟩ := leftSpine_spec fuel r hboth.2 (by omega)
        rw [List.dropLast_cons_of_ne_nil ne, List.modify_zero_cons, List.getLastD_cons,
          getLastD_of_ne_nil ne _ (leaf, false)]
        simp only [rebuild, plugBalance, withEntry, Bool.false_eq_true, if_false, deleteRec,
          if_true, hboth.1, hboth.2, Bool.and_self]
        rw [e1, ← e2]
      · rw [if_neg hb] at hw
        simp only [Option.some.injEq, Prod.mk.injEq] at hw
        exact absurd hw.2 (by simpa using hb)
    · simp only [walk, hxk, if_false] at hw ⊢
      by_cases hlt : x < k
      · simp only [hlt, if_true, Option.map_eq_some_iff] at hw ⊢
        obtain ⟨⟨lvl', two'⟩, hw', he⟩ := hw
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        have ne := walk_found_ne_nil x true fuel l _ hw'
        rw [List.dropLast_cons_of_ne_nil ne, List.modify_succ_cons, List.getLastD_cons,
          getLastD_of_ne_nil ne _ (leaf, false)]
        simp only [rebuild, plugBalance, if_true, deleteRec, hxk, hlt, if_false]
        rw [rebuild_walk_deleteTwo x fuel l lvl' (by omega) hw']
      · simp only [hlt, if_false, Option.map_eq_some_iff] at hw ⊢
        obtain ⟨⟨lvl', two'⟩, hw', he⟩ := hw
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        have ne := walk_found_ne_nil x true fuel r _ hw'
        rw [List.dropLast_cons_of_ne_nil ne, List.modify_succ_cons, List.getLastD_cons,
          getLastD_of_ne_nil ne _ (leaf, false)]
        simp only [rebuild, plugBalance, Bool.false_eq_true, if_false, deleteRec, hxk, hlt]
        rw [rebuild_walk_deleteTwo x fuel r lvl' (by omega) hw']

/-- A walk that does not find the key: the key is absent. -/
theorem walk_none_absent (x : Nat) (d : Bool) : ∀ (fuel : Nat) (t : Tree), t.Sorted →
    t.height ≤ fuel → (walk x d fuel t).2 = none → ∀ e ∈ t.toList, e.1 ≠ x
  | _, leaf, _, _, _ => by simp [toList]
  | 0, node .., _, hh, _ => by simp [height] at hh
  | fuel + 1, node l k v r, hs, hh, hw => by
    simp only [height] at hh
    obtain ⟨hsl, hsr, hlk, hrk⟩ := Tree.sorted_node hs
    simp only [walk] at hw
    by_cases hxk : x = k
    · simp only [hxk, if_true] at hw
      split at hw <;> simp at hw
    · simp only [hxk, if_false] at hw
      intro e he
      simp only [toList, List.mem_append, List.mem_cons] at he
      by_cases hlt : x < k
      · simp only [hlt, if_true, Option.map_eq_none_iff] at hw
        rcases he with he | rfl | he
        · exact walk_none_absent x d fuel l hsl (by omega) hw e he
        · exact fun h => hxk h.symm
        · have := hrk e he; omega
      · simp only [hlt, if_false, Option.map_eq_none_iff] at hw
        rcases he with he | rfl | he
        · have := hlk e he; omega
        · exact fun h => hxk h.symm
        · exact walk_none_absent x d fuel r hsr (by omega) hw e he

/-- A walk that finds the key: the key is present. -/
theorem walk_some_present (x : Nat) (d : Bool) : ∀ (fuel : Nat) (t : Tree) (f : Nat × Bool),
    (walk x d fuel t).2 = some f → ∃ v0, (x, v0) ∈ t.toList
  | 0, _, _, h => by simp [walk] at h
  | _ + 1, leaf, _, h => by simp [walk] at h
  | fuel + 1, node l k v r, f, hw => by
    simp only [walk] at hw
    by_cases hxk : x = k
    · subst hxk; exact ⟨v, by simp [toList]⟩
    · simp only [hxk, if_false] at hw
      by_cases hlt : x < k
      · simp only [hlt, if_true, Option.map_eq_some_iff] at hw
        obtain ⟨f', hw', _⟩ := hw
        obtain ⟨v0, hm⟩ := walk_some_present x d fuel l f' hw'
        exact ⟨v0, by simp [toList, hm]⟩
      · simp only [hlt, if_false, Option.map_eq_some_iff] at hw
        obtain ⟨f', hw', _⟩ := hw
        obtain ⟨v0, hm⟩ := walk_some_present x d fuel r f' hw'
        exact ⟨v0, by simp [toList, hm]⟩


/-! ## The height bound -/

/-- The fewest nodes of a balanced tree of height `h`, `F(h + 2) - 1`. -/
def avlMinNodes : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => avlMinNodes (n + 1) + avlMinNodes n + 1

theorem avlMinNodes_succ (n : Nat) : avlMinNodes n < avlMinNodes (n + 1) := by
  induction n with
  | zero => decide
  | succ n ih =>
    cases n with
    | zero => decide
    | succ m => simp only [avlMinNodes] at ih ⊢; omega

theorem avlMinNodes_mono {a b : Nat} (h : a ≤ b) : avlMinNodes a ≤ avlMinNodes b := by
  induction b with
  | zero => cases a <;> simp_all
  | succ b ih =>
    by_cases hab : a = b + 1
    · subst hab; exact Nat.le_refl _
    · exact Nat.le_trans (ih (by omega)) (Nat.le_of_lt (avlMinNodes_succ b))

theorem le_avlMinNodes (n : Nat) : n ≤ avlMinNodes n := by
  induction n with
  | zero => exact Nat.zero_le _
  | succ n ih => have := avlMinNodes_succ n; omega

/-- A balanced tree has at least the fewest nodes of its height. -/
theorem avlMinNodes_le_size : ∀ (t : Tree), t.Balanced → avlMinNodes t.height ≤ t.size
  | leaf, _ => Nat.le_refl _
  | node l k v r, hbal => by
    obtain ⟨hl, hr, a, b⟩ := hbal
    have il := avlMinNodes_le_size l hl
    have ir := avlMinNodes_le_size r hr
    simp only [height, size]
    by_cases hlr : r.height ≤ l.height
    · have hm : max l.height r.height = l.height := by omega
      rw [hm]
      cases hlh : l.height with
      | zero => simp [avlMinNodes]
      | succ n =>
        rw [hlh] at il
        have hr' : n ≤ r.height := by omega
        have := avlMinNodes_mono hr'
        simp only [avlMinNodes]; omega
    · have hm : max l.height r.height = r.height := by omega
      rw [hm]
      cases hrh : r.height with
      | zero => simp [avlMinNodes]
      | succ n =>
        rw [hrh] at ir
        have hl' : n ≤ l.height := by omega
        have := avlMinNodes_mono hl'
        simp only [avlMinNodes]; omega

theorem avlHeightFrom_ge_start (capacity : Nat) : ∀ (fuel a b h : Nat),
    h ≤ pathOramTreeAvlHeightFrom capacity fuel a b h
  | 0, _, _, _ => Nat.le_refl _
  | fuel + 1, a, b, h => by
    simp only [pathOramTreeAvlHeightFrom]
    split
    · have := avlHeightFrom_ge_start capacity fuel b (b + a) (h + 1); omega
    · exact Nat.le_refl _

/-- The height loop reaches every height whose fewest nodes fit. -/
theorem avlHeightFrom_ge (capacity : Nat) : ∀ (fuel h H : Nat), h ≤ H →
    avlMinNodes H ≤ capacity → H - h ≤ fuel →
    H ≤ pathOramTreeAvlHeightFrom capacity fuel (avlMinNodes h + 1) (avlMinNodes (h + 1) + 1) h
  | 0, h, H, h1, _, h3 => by
    have : H = h := by omega
    subst this; exact avlHeightFrom_ge_start capacity 0 _ _ _
  | fuel + 1, h, H, h1, h2, h3 => by
    by_cases hH : H = h
    · subst hH; exact avlHeightFrom_ge_start capacity _ _ _ _
    · have hfit : avlMinNodes (h + 1) ≤ capacity :=
        Nat.le_trans (avlMinNodes_mono (by omega)) h2
      simp only [pathOramTreeAvlHeightFrom]
      rw [if_pos (by omega)]
      have hnext : avlMinNodes (h + 1) + 1 + (avlMinNodes h + 1) = avlMinNodes (h + 2) + 1 := by
        simp only [avlMinNodes]; omega
      rw [hnext]
      exact avlHeightFrom_ge capacity fuel (h + 1) H (by omega) h2 (by omega)

/-- A balanced tree of at most `capacity` nodes is no taller than the
capacity's largest AVL height, so a walk of that many levels always
reaches the bottom. -/
theorem height_le_avlHeight {t : Tree} {capacity : Nat} (hb : t.Balanced)
    (hs : t.size ≤ capacity) : t.height ≤ pathOramTreeAvlHeight capacity := by
  have h1 := avlMinNodes_le_size t hb
  have h2 := le_avlMinNodes t.height
  have h3 := avlHeightFrom_ge capacity (capacity + 2) 0 t.height (Nat.zero_le _) (by omega)
    (by omega)
  simp only [avlMinNodes, Nat.reduceAdd] at h3
  unfold pathOramTreeAvlHeight
  omega


/-! ## The operations' semantics -/

theorem lookup_isSome_of_mem {xs : List (Nat × Nat)} {x v : Nat} (h : (x, v) ∈ xs) :
    (xs.lookup x).isSome = true := by
  induction xs with
  | nil => simp at h
  | cons e rest ih =>
    obtain ⟨k, w⟩ := e
    rw [lookup_cons']
    by_cases hxk : x = k
    · simp [hxk]
    · simp only [hxk, if_false]
      simp only [List.mem_cons, Prod.mk.injEq] at h
      rcases h with ⟨h1, _⟩ | h
      · exact absurd h1 hxk
      · exact ih h

theorem mem_of_lookup_eq_some {xs : List (Nat × Nat)} {x v : Nat} (h : xs.lookup x = some v) :
    (x, v) ∈ xs := by
  induction xs with
  | nil => simp at h
  | cons e rest ih =>
    obtain ⟨k, w⟩ := e
    rw [lookup_cons'] at h
    by_cases hxk : x = k
    · simp only [hxk, if_true, Option.some.injEq] at h
      subst hxk; subst h; simp
    · simp only [hxk, if_false] at h
      exact List.mem_cons_of_mem _ (ih h)

theorem Tree.lookup_node {l r : Tree} {k v : Nat} (hs : (node l k v r).Sorted) (x : Nat) :
    (node l k v r).lookup x = if x = k then some v else if x < k then l.lookup x else r.lookup x := by
  obtain ⟨_, _, hlk, hrk⟩ := Tree.sorted_node hs
  unfold lookup
  simp only [toList, List.lookup_append, lookup_cons']
  by_cases hxk : x = k
  · subst hxk
    rw [lookup_eq_none (fun e he => Nat.ne_of_lt (hlk e he))]
    simp
  · simp only [hxk, if_false]
    by_cases hlt : x < k
    · rw [lookup_eq_none (xs := r.toList) (fun e he => Nat.ne_of_gt (Nat.lt_trans hlt (hrk e he)))]
      simp [hlt]
    · rw [lookup_eq_none (xs := l.toList) (fun e he => by have := hlk e he; omega)]
      simp [hlt]

/-- A get returns the key's value, zero if absent, and whether it is present,
when it walks at least the tree's height. -/
theorem get_eq_lookup (x : Nat) : ∀ (fuel : Nat) (t : Tree), t.Sorted → t.height ≤ fuel →
    get x fuel t = ((t.lookup x).getD 0, (t.lookup x).isSome)
  | _, leaf, _, _ => by cases ‹Nat› <;> rfl
  | 0, node .., _, hh => by simp [height] at hh
  | fuel + 1, node l k v r, hs, hh => by
    obtain ⟨hsl, hsr, _, _⟩ := Tree.sorted_node hs
    simp only [height] at hh
    rw [Tree.lookup_node hs]
    simp only [get]
    by_cases hxk : x = k
    · simp [hxk]
    · simp only [hxk, if_false]
      by_cases hlt : x < k
      · simp only [hlt, if_true]; exact get_eq_lookup x fuel l hsl (by omega)
      · simp only [hlt, if_false]; exact get_eq_lookup x fuel r hsr (by omega)

/-- The put, case by case: an update or a delete of a present key, an
insert of an absent one if the map has room, an overflow if not. -/
theorem put_eq {capacity fuel : Nat} {t : Tree} {size x value : Nat} {apply : Bool}
    (hs : t.Sorted) (hh : t.height ≤ fuel) :
    put capacity fuel t size x value apply =
      if (t.lookup x).isSome then
        if !apply then { tree := t, size := size, overflow := false }
        else if value != 0 then { tree := updateRec x value t, size := size, overflow := false }
        else { tree := deleteRec x t, size := size - 1, overflow := false }
      else if apply && value != 0 then
        if size < capacity then { tree := insertRec x value t, size := size + 1, overflow := false }
        else { tree := t, size := size, overflow := true }
      else { tree := t, size := size, overflow := false } := by
  simp only [put]
  cases hw : (walk x (apply && value == 0) fuel t).2 with
  | none =>
    have habs := walk_none_absent x _ fuel t hs hh hw
    have hnone : (t.lookup x).isSome = false := by
      unfold lookup; rw [lookup_eq_none habs]; rfl
    simp only [hnone, Bool.false_eq_true, if_false]
    split
    · split
      · rw [rebuild_walk_insert x value _ fuel t hh hw]
      · rfl
    · rfl
  | some f =>
    obtain ⟨lvl, two⟩ := f
    obtain ⟨v0, hm⟩ := walk_some_present x _ fuel t _ hw
    have hsome : (t.lookup x).isSome = true := lookup_isSome_of_mem hm
    simp only [hsome, if_true]
    cases apply with
    | false => simp
    | true =>
      simp only [Bool.not_true, Bool.false_eq_true, if_false]
      by_cases hv : value = 0
      · subst hv
        simp only [bne_self_eq_false, Bool.false_eq_true, if_false]
        simp only [Bool.true_and, beq_self_eq_true] at hw ⊢
        cases two with
        | true =>
          simp only [if_true]
          rw [rebuild_walk_deleteTwo x fuel t lvl hh hw]
        | false =>
          simp only [Bool.false_eq_true, if_false]
          rw [rebuild_walk_deleteOne x fuel t lvl hw]
      · have hv' : (value != 0) = true := by simpa using hv
        simp only [hv', if_true]
        rw [rebuildPlain_walk_update x value _ fuel t lvl two hw]

/-- The map invariant: sorted keys, balanced, no zero values (a zero value
deletes), and a size that counts the keys and fits the capacity. -/
structure Valid (capacity : Nat) (t : Tree) (size : Nat) : Prop where
  sorted : t.Sorted
  balanced : t.Balanced
  nonzero : ∀ e ∈ t.toList, e.2 ≠ 0
  size_eq : t.size = size
  size_le : size ≤ capacity

/-- A put on a valid map, walking at least the tree's height: the map stays
valid; it overflows exactly when it would insert into a full map; and,
unless it overflows or is masked off, it maps the key to the value (or
deletes it, for a zero value) and leaves every other key alone. -/
theorem put_spec_of_height {capacity fuel : Nat} {t : Tree} {size : Nat}
    (hv : Valid capacity t size) (hh : t.height ≤ fuel) (x value : Nat) (apply : Bool) :
    Valid capacity (put capacity fuel t size x value apply).tree
        (put capacity fuel t size x value apply).size ∧
      (put capacity fuel t size x value apply).overflow =
        (apply && value != 0 && (t.lookup x).isNone && decide (capacity ≤ size)) ∧
      ∀ y, (put capacity fuel t size x value apply).tree.lookup y =
        if apply && !(put capacity fuel t size x value apply).overflow && y = x then
          (if value = 0 then none else some value)
        else t.lookup y := by
  obtain ⟨hs, hb, hnz, hsize, hcap⟩ := hv
  rw [put_eq hs hh]
  by_cases hp : (t.lookup x).isSome = true
  · -- The key is present.
    obtain ⟨v0, hlk⟩ := Option.isSome_iff_exists.1 hp
    have hm := mem_of_lookup_eq_some hlk
    have hnone : (t.lookup x).isNone = false := by simp [hlk]
    simp only [hp, if_true]
    cases apply with
    | false =>
      simp only [Bool.not_false, if_true, Bool.false_and, Bool.false_eq_true, if_false]
      refine ⟨⟨hs, hb, hnz, hsize, hcap⟩, ?_, ?_⟩ <;> simp
    | true =>
      simp only [Bool.not_true, Bool.false_eq_true, if_false]
      by_cases hv0 : value = 0
      · -- A delete.
        subst hv0
        simp only [bne_self_eq_false, Bool.false_eq_true, if_false]
        obtain ⟨⟨lo, hi, e1, e2⟩, d1, _, _⟩ := deleteRec_spec x t v0 hs hb hm
        have hsl : SortedList (lo ++ (x, v0) :: hi) := by rw [← e1]; exact hs
        refine ⟨⟨?_, d1, ?_, ?_, by omega⟩, by simp [hnone], ?_⟩
        · unfold Sorted; rw [e2]; exact (bounds_of_sorted hsl).2.2
        · intro e he; rw [e2] at he
          apply hnz e
          rw [e1]
          simp only [List.mem_append, List.mem_cons] at he ⊢
          rcases he with he | he
          · exact Or.inl he
          · exact Or.inr (Or.inr he)
        · rw [Tree.size_eq_length, e2, ← hsize, Tree.size_eq_length, e1]; simp
        · intro y
          simp only [Bool.not_false, Bool.true_and]
          unfold lookup
          rw [e2, lookup_remove_mid hsl y, ← e1]
          by_cases hy : y = x <;> simp [hy]
      · -- An update.
        have hv' : (value != 0) = true := by simpa using hv0
        simp only [hv', if_true]
        obtain ⟨lo, hi, e1, e2⟩ := updateRec_toList x value t v0 hs hm
        obtain ⟨s1, s2, s3⟩ := updateRec_shape x value t
        have hsl : SortedList (lo ++ (x, v0) :: hi) := by rw [← e1]; exact hs
        obtain ⟨b1, b2, b3⟩ := bounds_of_sorted hsl
        refine ⟨⟨?_, s3 hb, ?_, by rw [s2]; exact hsize, hcap⟩, by simp [hnone], ?_⟩
        · unfold Sorted; rw [e2]; exact sorted_insert_mid b3 b1 b2
        · intro e he; rw [e2] at he
          simp only [List.mem_append, List.mem_cons] at he
          rcases he with he | rfl | he
          · exact hnz e (by rw [e1]; simp [he])
          · exact hv0
          · exact hnz e (by rw [e1]; simp [he])
        · intro y
          simp only [Bool.not_false, Bool.true_and]
          unfold lookup
          rw [e2, lookup_insert_mid b1 b2 y, e1, lookup_insert_mid b1 b2 y]
          by_cases hy : y = x <;> simp [hy, hv0]
  · -- The key is absent.
    have hp' : (t.lookup x).isSome = false := by simpa using hp
    have hnone : (t.lookup x).isNone = true := by simpa using hp
    have habs : ∀ e ∈ t.toList, e.1 ≠ x := by
      intro e he hex
      have := lookup_isSome_of_mem (xs := t.toList) (x := x) (v := e.2) (by rw [← hex]; exact he)
      exact hp this
    simp only [hp', Bool.false_eq_true, if_false]
    by_cases hins : (apply && value != 0) = true
    · simp only [hins, if_true]
      simp only [Bool.and_eq_true, bne_iff_ne, ne_eq] at hins
      obtain ⟨rfl, hv0⟩ := hins
      by_cases hroom : size < capacity
      · -- An insert.
        simp only [hroom, if_true]
        obtain ⟨lo, hi, e1, e2, b1, b2⟩ := insertRec_toList x value t hs habs
        obtain ⟨i1, _, _⟩ := insertRec_balanced x value t hb
        have hsl : SortedList (lo ++ hi) := by rw [← e1]; exact hs
        refine ⟨⟨?_, i1, ?_, ?_, by omega⟩, ?_, ?_⟩
        · unfold Sorted; rw [e2]; exact sorted_insert_mid hsl b1 b2
        · intro e he; rw [e2] at he
          simp only [List.mem_append, List.mem_cons] at he
          rcases he with he | rfl | he
          · exact hnz e (by rw [e1]; simp [he])
          · exact hv0
          · exact hnz e (by rw [e1]; simp [he])
        · rw [Tree.size_eq_length, e2, ← hsize, Tree.size_eq_length, e1]; simp; omega
        · simp only [Bool.true_and, hnone]; simp; omega
        · intro y
          simp only [Bool.not_false, Bool.true_and]
          unfold lookup
          rw [e2, lookup_insert_mid b1 b2 y, e1]
          by_cases hy : y = x <;> simp [hy, hv0]
      · -- The map is full.
        simp only [hroom, if_false]
        refine ⟨⟨hs, hb, hnz, hsize, hcap⟩, ?_, ?_⟩
        · simp only [Bool.true_and, hnone]; simp; omega
        · intro y; simp
    · simp only [hins, Bool.false_eq_true, if_false]
      refine ⟨⟨hs, hb, hnz, hsize, hcap⟩, ?_, ?_⟩
      · simp only [Bool.not_eq_true] at hins; simp
      · intro y
        by_cases hy : y = x
        · subst hy
          have hl : t.lookup y = none := by simpa using hp
          by_cases hz : value = 0
          · simp [hl, hz]
          · have ha : apply = false := by cases apply <;> simp_all
            simp [hl, ha]
        · simp [hy]

/-- The get, at the capacity's largest AVL height. -/
theorem get_spec {capacity : Nat} {t : Tree} {size : Nat} (hv : Valid capacity t size)
    (x : Nat) :
    get x (pathOramTreeAvlHeight capacity) t = ((t.lookup x).getD 0, (t.lookup x).isSome) :=
  get_eq_lookup x _ t hv.sorted (height_le_avlHeight hv.balanced (hv.size_eq ▸ hv.size_le))

/-- The put, at the capacity's largest AVL height. -/
theorem put_spec {capacity : Nat} {t : Tree} {size : Nat} (hv : Valid capacity t size)
    (x value : Nat) (apply : Bool) :
    let r := put capacity (pathOramTreeAvlHeight capacity) t size x value apply
    Valid capacity r.tree r.size ∧
      r.overflow = (apply && value != 0 && (t.lookup x).isNone && decide (capacity ≤ size)) ∧
      ∀ y, r.tree.lookup y =
        if apply && !r.overflow && y = x then (if value = 0 then none else some value)
        else t.lookup y :=
  put_spec_of_height hv (height_le_avlHeight hv.balanced (hv.size_eq ▸ hv.size_le)) x value apply

/-- The empty map is valid. -/
theorem valid_empty (capacity : Nat) : Valid capacity leaf 0 :=
  ⟨List.Pairwise.nil, trivial, by simp [toList], rfl, Nat.zero_le _⟩


/-! ## Node accesses

Every operation makes a fixed number of node accesses, as the trace shape
counts them (`pathOramTreeGetAccesses`, `pathOramTreePutAccesses`); an
access is real when it reads a node the operation needs and has not read,
and a dummy otherwise. These functions give each access's kind, in order,
so the replay can compare them with the runtime's. -/

/-- A get's accesses, one per level: real while the walk is on the tree. -/
def getAccesses (x : Nat) : Nat → Tree → List Bool
  | 0, _ => []
  | fuel + 1, leaf => List.replicate (fuel + 1) false
  | fuel + 1, node l k _ r =>
      true :: (if x = k then List.replicate fuel false
        else if x < k then getAccesses x fuel l else getAccesses x fuel r)

/-- One rebalance level's two accesses, given the keys of the nodes the put
has read: the taller child of a node two taller on one side, and, for a
double rotation, that child's inner child. Each is real unless the put has
read that node already. -/
def rebalanceAccesses (read : List Nat) : Tree → List Nat × Bool × Bool
  | leaf => (read, false, false)
  | node l _ _ r =>
      let heavyLeft := decide (r.height + 2 ≤ l.height)
      let heavyRight := decide (l.height + 2 ≤ r.height)
      let child := if heavyLeft then l else r
      let childReal := (heavyLeft || heavyRight) && child.present && !read.contains child.key
      let read := if childReal then child.key :: read else read
      let double := (heavyLeft && decide (child.leftChild.height < child.rightChild.height)) ||
        (heavyRight && decide (child.rightChild.height < child.leftChild.height))
      let grandchild := if heavyLeft then child.rightChild else child.leftChild
      let grandchildReal := double && grandchild.present && !read.contains grandchild.key
      let read := if grandchildReal then grandchild.key :: read else read
      (read, childReal, grandchildReal)

/-- The rebalance's accesses up a walk's levels, deepest level first. -/
def rebuildAccesses (read : List Nat) : List (Tree × Bool) → Tree → List Nat × List Bool
  | [], _ => (read, [])
  | (t, goLeft) :: rest, sub =>
      let below := rebuildAccesses read rest sub
      let level := rebalanceAccesses below.1 (plug t goLeft (rebuild rest sub))
      (level.1, below.2 ++ [level.2.1, level.2.2])

/-- A put's accesses: one per walk level, real while on the tree; one to
pop the free list, real for an insert; and two per rebalance level, from
the deepest level up, dummies below the change. -/
def putAccesses (capacity fuel : Nat) (t : Tree) (size x value : Nat) (apply : Bool) :
    List Bool :=
  let w := walk x (apply && value == 0) fuel t
  let read := w.1.map fun e => e.1.key
  let insert := apply && w.2.isNone && value != 0 && decide (size < capacity)
  let rebalance : List Bool :=
    match w.2 with
    | none => if insert then (rebuildAccesses (x :: read) w.1 (node leaf x value leaf)).2 else []
    | some (level, twoChildren) =>
        if apply && value == 0 then
          if twoChildren then
            let successor := (w.1.getLastD (leaf, false)).1
            (rebuildAccesses read ((w.1.dropLast).modify level fun e =>
              (e.1.withEntry successor.key successor.value, e.2)) successor.rightChild).2
          else (rebuildAccesses read (w.1.take level) (w.1.getD level (leaf, false)).1.oneChild).2
        else []
  List.replicate w.1.length true ++ List.replicate (fuel - w.1.length) false ++ [insert] ++
    List.replicate (2 * fuel - rebalance.length) false ++ rebalance

theorem getAccesses_length (x : Nat) : ∀ (fuel : Nat) (t : Tree),
    (getAccesses x fuel t).length = fuel
  | 0, _ => rfl
  | fuel + 1, leaf => by simp [getAccesses]
  | fuel + 1, node l k v r => by
    simp only [getAccesses, List.length_cons]
    split
    · simp
    · split
      · rw [getAccesses_length x fuel l]
      · rw [getAccesses_length x fuel r]

theorem leftSpine_length_le : ∀ (fuel : Nat) (t : Tree), (leftSpine fuel t).length ≤ fuel
  | 0, _ => Nat.le_refl _
  | _ + 1, leaf => Nat.zero_le _
  | fuel + 1, node l _ _ _ => by
    simp only [leftSpine, List.length_cons]
    have := leftSpine_length_le fuel l; omega

theorem walk_length_le (x : Nat) (d : Bool) : ∀ (fuel : Nat) (t : Tree),
    (walk x d fuel t).1.length ≤ fuel
  | 0, _ => Nat.le_refl _
  | _ + 1, leaf => Nat.zero_le _
  | fuel + 1, node l k v r => by
    simp only [walk]
    split
    · split
      · simp only [List.length_cons]; have := leftSpine_length_le fuel r; omega
      · simp
    · split
      · simp only [List.length_cons]; have := walk_length_le x d fuel l; omega
      · simp only [List.length_cons]; have := walk_length_le x d fuel r; omega

theorem rebuildAccesses_length (read : List Nat) : ∀ (levels : List (Tree × Bool)) (sub : Tree),
    (rebuildAccesses read levels sub).2.length = 2 * levels.length
  | [], _ => rfl
  | (t, goLeft) :: rest, sub => by
    simp only [rebuildAccesses, List.length_append, List.length_cons, List.length_nil,
      rebuildAccesses_length read rest sub]
    omega

/-- A put makes `3 * fuel + 1` accesses whatever its inputs. -/
theorem putAccesses_length (capacity fuel : Nat) (t : Tree) (size x value : Nat)
    (apply : Bool) : (putAccesses capacity fuel t size x value apply).length = 3 * fuel + 1 := by
  have hw := walk_length_le x (apply && value == 0) fuel t
  simp only [putAccesses, List.length_append, List.length_replicate, List.length_cons,
    List.length_nil]
  split
  · split
    · rw [rebuildAccesses_length]; omega
    · simp only [List.length_nil]; omega
  · split
    · split
      · rw [rebuildAccesses_length, List.length_modify, List.length_dropLast]; omega
      · rw [rebuildAccesses_length, List.length_take]; omega
    · simp only [List.length_nil]; omega

/-- At the capacity's largest AVL height, the counts are the trace shape's. -/
theorem getAccesses_length_shape (capacity x : Nat) (t : Tree) :
    (getAccesses x (pathOramTreeAvlHeight capacity) t).length =
      pathOramTreeGetAccesses capacity :=
  getAccesses_length x _ t

theorem putAccesses_length_shape (capacity : Nat) (t : Tree) (size x value : Nat)
    (apply : Bool) :
    (putAccesses capacity (pathOramTreeAvlHeight capacity) t size x value apply).length =
      pathOramTreePutAccesses capacity :=
  putAccesses_length capacity _ t size x value apply

end UOToolchain.PathOramAvlMap
