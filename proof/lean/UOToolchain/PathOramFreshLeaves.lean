import UOToolchain.CoinTapes
import UOToolchain.RuntimeRefinement

/-!
# Path ORAM leaf schedules are uniform, without seed enumeration

A Path ORAM access reads the path of the accessed key's leaf, or a fresh
random path when the key is absent, and then gives the key a fresh leaf
(`stepLeaves`, which `runtimePathOramApplyTransition?` follows:
`applyTransition?_stepLeaves`, `replay_runLeaves`). Tracking which coin each
leaf is (`stepVars`), every access reads a coin no earlier access read and
the keys left behind hold coins no access read (`runVars_spec`). So, for any
accesses and any keys present before the call, uniform coins give a uniform
schedule (`observedLeaves_uniform`, `observedLeaves_canonical`), and the
leaves left behind are uniform and independent of it
(`observedLeaves_finalLeaves_uniform`), which is what the next call needs.

Several maps: the model is generic in the slot type, so a call on several
maps runs it on `(map, slot)` keys, each map's coins below its own leaf count
(`multiObservedLeaves_uniform`, `multiObservedLeaves_canonical`).
-/

set_option autoImplicit false

namespace UOToolchain

namespace PathOramFreshLeaves

open CoinTape

variable {σ : Type} [DecidableEq σ]

/-- One access to a Path ORAM map, by what it does to the accessed key's leaf:
`remap` (read hit, update, or masked write on a present key) reads the key's
path and gives the key a fresh leaf; `miss` (read miss, or masked write on an
absent key) reads a fresh random path; `insert` reads a fresh random path and
gives the new key a fresh leaf; `delete` reads the key's path and drops it. -/
inductive LeafStep (σ : Type)
  | remap (slot : σ)
  | miss
  | insert (slot : σ)
  | delete (slot : σ)

/-- A partial map from slots, updated at one slot. -/
def setAt (m : σ → Option Nat) (slot : σ) (v : Option Nat) : σ → Option Nat :=
  fun s => if s = slot then v else m s

/-! ## Leaves: what the runtime computes from its coins -/

/-- One access on leaf values: the observed leaf, and the new position map.
`missCoin` is the access's random path, `nextCoin` its fresh leaf. -/
def stepLeaves (missCoin nextCoin : Nat) (leaves : σ → Option Nat) :
    LeafStep σ → Nat × (σ → Option Nat)
  | .remap s =>
      match leaves s with
      | some l => (l, setAt leaves s (some nextCoin))
      | none => (missCoin, leaves)
  | .miss => (missCoin, leaves)
  | .insert s => (missCoin, setAt leaves s (some nextCoin))
  | .delete s =>
      match leaves s with
      | some l => (l, setAt leaves s none)
      | none => (missCoin, leaves)

/-- Run accesses, drawing two coins per access (the random path, then the
fresh leaf). The runtime draws both for a write and one for a read, which
serves as whichever of the two the read uses. -/
def runLeaves (leaves : σ → Option Nat) : List (LeafStep σ) → List Nat → List Nat × (σ → Option Nat)
  | [], _ => ([], leaves)
  | step :: steps, coins =>
      let r := stepLeaves (coins.getD 0 0) (coins.getD 1 0) leaves step
      let rest := runLeaves r.2 steps (coins.drop 2)
      (r.1 :: rest.1, rest.2)

/-! ## Coordinates: which tape entry each leaf is -/

/-- One access on tape coordinates: `base` is the coordinate of the access's
random path and `base + 1` that of its fresh leaf. -/
def stepVars (base : Nat) (vars : σ → Option Nat) : LeafStep σ → Nat × (σ → Option Nat)
  | .remap s =>
      match vars s with
      | some v => (v, setAt vars s (some (base + 1)))
      | none => (base, vars)
  | .miss => (base, vars)
  | .insert s => (base, setAt vars s (some (base + 1)))
  | .delete s =>
      match vars s with
      | some v => (v, setAt vars s none)
      | none => (base, vars)

def runVars (start : Nat) (vars : σ → Option Nat) : List (LeafStep σ) → List Nat × (σ → Option Nat)
  | [] => ([], vars)
  | step :: steps =>
      let r := stepVars start vars step
      let rest := runVars (start + 2) r.2 steps
      (r.1 :: rest.1, rest.2)

theorem length_runVars (start : Nat) (vars : σ → Option Nat) (steps : List (LeafStep σ)) :
    (runVars start vars steps).1.length = steps.length := by
  induction steps generalizing start vars with
  | nil => rfl
  | cons step steps ih => simp [runVars, ih]

/-- Reading a tape through a coordinate map. -/
def readVars (tape : List Nat) (vars : σ → Option Nat) : σ → Option Nat :=
  fun s => (vars s).map fun v => tape.getD v 0

theorem readVars_setAt (tape : List Nat) (vars : σ → Option Nat) (s : σ) (v : Option Nat) :
    readVars tape (setAt vars s v) = setAt (readVars tape vars) s (v.map fun v => tape.getD v 0) := by
  funext s'
  simp only [readVars, setAt]
  split <;> rfl

theorem stepLeaves_readVars (tape : List Nat) (base : Nat) (vars : σ → Option Nat)
    (step : LeafStep σ) :
    stepLeaves (tape.getD base 0) (tape.getD (base + 1) 0) (readVars tape vars) step =
      ((stepVars base vars step).1 |> fun v => tape.getD v 0,
        readVars tape (stepVars base vars step).2) := by
  cases step with
  | remap s =>
      simp only [stepLeaves, stepVars, readVars]
      cases h : vars s <;> simp [readVars_setAt]
  | miss => rfl
  | insert s => simp [stepLeaves, stepVars, readVars_setAt]
  | delete s =>
      simp only [stepLeaves, stepVars, readVars]
      cases h : vars s <;> simp [readVars_setAt]

/-- The runtime's leaves are the tape read at the coordinates the accesses
touch: the observed schedule is the tape at `(runVars …).1`, whatever the
tape is. -/
theorem runLeaves_readVars (tape : List Nat) (start : Nat) (vars : σ → Option Nat)
    (steps : List (LeafStep σ)) :
    runLeaves (readVars tape vars) steps (tape.drop start) =
      ((runVars start vars steps).1.map fun v => tape.getD v 0,
        readVars tape (runVars start vars steps).2) := by
  induction steps generalizing start vars with
  | nil => rfl
  | cons step steps ih =>
      have h0 : (tape.drop start).getD 0 0 = tape.getD start 0 := by
        simp [List.getD_eq_getElem?_getD]
      have h1 : (tape.drop start).getD 1 0 = tape.getD (start + 1) 0 := by
        simp [List.getD_eq_getElem?_getD]
      have hd : (tape.drop start).drop 2 = tape.drop (start + 2) := by
        simp [List.drop_drop]
      simp only [runLeaves, runVars, h0, h1, stepLeaves_readVars, hd, ih, List.map_cons]

/-! ## Every access reads a coordinate no earlier access read -/

/-- Coordinate maps whose coordinates are below `start` and distinct across
slots. -/
def Fresh (start : Nat) (vars : σ → Option Nat) : Prop :=
  (∀ s v, vars s = some v → v < start) ∧
    (∀ s s' v, vars s = some v → vars s' = some v → s = s')

theorem stepVars_spec {start : Nat} {vars : σ → Option Nat} (hFresh : Fresh start vars)
    (step : LeafStep σ) :
    let r := stepVars start vars step
    Fresh (start + 2) r.2 ∧ r.1 < start + 2 ∧ (∀ s, r.2 s ≠ some r.1) ∧
      ((∃ s, vars s = some r.1) ∨ r.1 = start) ∧
      (∀ s v, r.2 s = some v → (∃ s', vars s' = some v) ∨ v = start + 1) := by
  obtain ⟨hBelow, hInj⟩ := hFresh
  cases step with
  | miss =>
      refine ⟨⟨fun s v h => by have := hBelow s v h; omega, hInj⟩, by simp [stepVars],
        ?_, Or.inr rfl, fun s v h => Or.inl ⟨s, h⟩⟩
      intro s h
      have := hBelow s _ h
      simp [stepVars] at this
  | insert slot =>
      simp only [stepVars]
      refine ⟨⟨?_, ?_⟩, by omega, ?_, Or.inr trivial, ?_⟩
      · intro s v h
        simp only [setAt] at h
        split at h
        · cases h; omega
        · have := hBelow s v h; omega
      · intro s s' v h h'
        simp only [setAt] at h h'
        split at h <;> split at h'
        · rename_i hs hs'; rw [hs, hs']
        · cases h; have := hBelow s' _ h'; omega
        · cases h'; have := hBelow s _ h; omega
        · exact hInj s s' v h h'
      · intro s h
        simp only [setAt] at h
        split at h
        · cases h
        · have := hBelow s _ h; omega
      · intro s v h
        simp only [setAt] at h
        split at h
        · cases h; exact Or.inr rfl
        · exact Or.inl ⟨s, h⟩
  | remap slot =>
      cases hv : vars slot with
      | none =>
          simp only [stepVars, hv]
          refine ⟨⟨fun s v h => by have := hBelow s v h; omega, hInj⟩, by omega, ?_,
            Or.inr trivial, fun s v h => Or.inl ⟨s, h⟩⟩
          intro s h
          have := hBelow s _ h
          omega
      | some v0 =>
          simp only [stepVars, hv]
          have hv0 := hBelow slot v0 hv
          refine ⟨⟨?_, ?_⟩, by omega, ?_, Or.inl ⟨slot, hv⟩, ?_⟩
          · intro s v h
            simp only [setAt] at h
            split at h
            · cases h; omega
            · have := hBelow s v h; omega
          · intro s s' v h h'
            simp only [setAt] at h h'
            split at h <;> split at h'
            · rename_i hs hs'; rw [hs, hs']
            · cases h; have := hBelow s' _ h'; omega
            · cases h'; have := hBelow s _ h; omega
            · exact hInj s s' v h h'
          · intro s h
            simp only [setAt] at h
            split at h
            · cases h; omega
            · rename_i hs
              exact hs (hInj s slot v0 h hv)
          · intro s v h
            simp only [setAt] at h
            split at h
            · cases h; exact Or.inr rfl
            · exact Or.inl ⟨s, h⟩
  | delete slot =>
      cases hv : vars slot with
      | none =>
          simp only [stepVars, hv]
          refine ⟨⟨fun s v h => by have := hBelow s v h; omega, hInj⟩, by omega, ?_,
            Or.inr trivial, fun s v h => Or.inl ⟨s, h⟩⟩
          intro s h
          have := hBelow s _ h
          omega
      | some v0 =>
          simp only [stepVars, hv]
          have hv0 := hBelow slot v0 hv
          refine ⟨⟨?_, ?_⟩, by omega, ?_, Or.inl ⟨slot, hv⟩, ?_⟩
          · intro s v h
            simp only [setAt] at h
            split at h
            · cases h
            · have := hBelow s v h; omega
          · intro s s' v h h'
            simp only [setAt] at h h'
            split at h <;> split at h'
            · cases h
            · cases h
            · cases h'
            · exact hInj s s' v h h'
          · intro s h
            simp only [setAt] at h
            split at h
            · cases h
            · rename_i hs
              exact hs (hInj s slot v0 h hv)
          · intro s v h
            simp only [setAt] at h
            split at h
            · cases h
            · exact Or.inl ⟨s, h⟩

theorem runVars_spec {start : Nat} {vars : σ → Option Nat} (hFresh : Fresh start vars)
    (steps : List (LeafStep σ)) :
    let r := runVars start vars steps
    r.1.Nodup ∧ (∀ o ∈ r.1, o < start + 2 * steps.length) ∧
      (∀ o ∈ r.1, ∀ s, r.2 s ≠ some o) ∧ Fresh (start + 2 * steps.length) r.2 ∧
      (∀ o ∈ r.1, (∃ s, vars s = some o) ∨ start ≤ o) ∧
      (∀ s v, r.2 s = some v → (∃ s', vars s' = some v) ∨ start ≤ v) := by
  induction steps generalizing start vars with
  | nil =>
      simp only [runVars, List.nodup_nil, List.not_mem_nil, false_implies, implies_true,
        List.length_nil, Nat.mul_zero, Nat.add_zero, true_and]
      exact ⟨hFresh, fun s v h => Or.inl ⟨s, h⟩⟩
  | cons step steps ih =>
      obtain ⟨hFresh', hLt, hGone, hFrom, hNew⟩ := stepVars_spec hFresh step
      obtain ⟨hNodup, hBound, hRestGone, hFreshF, hRestFrom, hFinalFrom⟩ := ih hFresh'
      simp only [runVars, List.length_cons]
      refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
      · rw [List.nodup_cons]
        refine ⟨?_, hNodup⟩
        intro hm
        rcases hRestFrom _ hm with ⟨s, hs⟩ | hge
        · exact hGone s hs
        · omega
      · intro o ho
        rcases List.mem_cons.mp ho with rfl | ho
        · omega
        · have := hBound o ho; omega
      · intro o ho s
        rcases List.mem_cons.mp ho with rfl | ho
        · intro hs
          rcases hFinalFrom s _ hs with ⟨s', hs'⟩ | hge
          · exact hGone s' hs'
          · omega
        · exact hRestGone o ho s
      · have : start + 2 + 2 * steps.length = start + 2 * (steps.length + 1) := by omega
        rw [← this]
        exact hFreshF
      · intro o ho
        rcases List.mem_cons.mp ho with rfl | ho
        · rcases hFrom with h | h
          · exact Or.inl h
          · exact Or.inr (by omega)
        · rcases hRestFrom o ho with ⟨s, hs⟩ | hge
          · rcases hNew s o hs with h | h
            · exact Or.inl h
            · exact Or.inr (by omega)
          · exact Or.inr (by omega)
      · intro s v hs
        rcases hFinalFrom s v hs with ⟨s', hs'⟩ | hge
        · rcases hNew s' v hs' with h | h
          · exact Or.inl h
          · exact Or.inr (by omega)
        · exact Or.inr (by omega)

/-! ## The schedule is uniform, whatever the accesses -/

theorem getElem_idxOf_of_mem {l : List σ} {a : σ} (h : a ∈ l) :
    l[l.idxOf a]'(List.idxOf_lt_length_of_mem h) = a := by
  induction l with
  | nil => simp at h
  | cons b l ih =>
      by_cases hb : b = a
      · subst hb
        simp [List.idxOf_cons_self]
      · have ha : a ∈ l := by
          rcases List.mem_cons.mp h with h | h
          · exact absurd h.symm hb
          · exact h
        have hne : (b == a) = false := by simpa using hb
        have hidx : (b :: l).idxOf a = l.idxOf a + 1 := by
          rw [List.idxOf_cons, hne, cond_false]
        simp only [hidx, List.getElem_cons_succ]
        exact ih ha

/-- The coordinates of a call's starting keys: the `i`-th key of `present`
(distinct slots) has its leaf at tape coordinate `i`. -/
def initialVars (present : List σ) : σ → Option Nat :=
  fun s => if s ∈ present then some (present.idxOf s) else none

theorem initialVars_eq_some {present : List σ} {s : σ} {v : Nat}
    (h : initialVars present s = some v) : ∃ hv : v < present.length, present[v] = s := by
  simp only [initialVars] at h
  split at h
  · rename_i hMem
    cases h
    exact ⟨List.idxOf_lt_length_of_mem hMem, getElem_idxOf_of_mem hMem⟩
  · cases h

theorem fresh_initialVars (present : List σ) : Fresh present.length (initialVars present) := by
  refine ⟨?_, ?_⟩
  · intro s v h
    simp only [initialVars] at h
    split at h
    · cases h; exact List.idxOf_lt_length_of_mem (by assumption)
    · cases h
  · intro s s' v h h'
    simp only [initialVars] at h h'
    split at h <;> split at h'
    · rename_i hs hs'
      cases h
      have := congrArg (fun i => present[i]?) (Option.some.inj h')
      simp only at this
      rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hs'),
        List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hs),
        getElem_idxOf_of_mem hs, getElem_idxOf_of_mem hs'] at this
      exact (Option.some.inj this).symm
    · cases h'
    · cases h
    · cases h

/-- The leaf schedule a call shows the host: one leaf per access. The call
starts with the keys in `present`, whose leaves are the first
`present.length` coordinates of `tape`; the rest of the tape is the call's
coins, two per access. -/
def observedLeaves (present : List σ) (steps : List (LeafStep σ)) (tape : List Nat) : List Nat :=
  (runLeaves (readVars tape (initialVars present)) steps (tape.drop present.length)).1

/-- The leaves of the keys present after the call, listed over `slots`. -/
def finalLeaves (present slots : List σ) (steps : List (LeafStep σ)) (tape : List Nat) :
    List Nat :=
  slots.filterMap (runLeaves (readVars tape (initialVars present)) steps
    (tape.drop present.length)).2

theorem observedLeaves_eq_readAt (present : List σ) (steps : List (LeafStep σ)) (tape : List Nat) :
    observedLeaves present steps tape =
      readAt (runVars present.length (initialVars present) steps).1 tape := by
  simp [observedLeaves, runLeaves_readVars, readAt]

/-- **The leaf schedule is uniform whatever the accesses are.** Over all
`L ^ (p + 2n)` tapes (the `p` leaves of the keys present before the call and
the `2n` coins of its `n` accesses), every schedule of `n` leaves appears
`L ^ (p + n)` times, for every sequence of `n` accesses (hits, misses,
inserts, deletes, masked writes, on any keys). -/
theorem observedLeaves_uniform (L : Nat) (present : List σ) (steps : List (LeafStep σ)) :
    ((coinTapes L (present.length + 2 * steps.length)).map
        (observedLeaves present steps)).Perm
      ((coinTapes L steps.length).flatMap fun v =>
        List.replicate (L ^ (present.length + steps.length)) v) := by
  obtain ⟨hNodup, hBound, -, -, -, -⟩ := runVars_spec (fresh_initialVars present) steps
  have hLen := length_runVars present.length (initialVars present) steps
  have hMap : (coinTapes L (present.length + 2 * steps.length)).map
      (observedLeaves present steps) =
      (coinTapes L (present.length + 2 * steps.length)).map
        (readAt (runVars present.length (initialVars present) steps).1) := by
    apply List.map_congr_left
    intro tape _
    exact observedLeaves_eq_readAt present steps tape
  rw [hMap]
  have := map_readAt_coinTapes_perm (L := L) hNodup hBound
  rw [hLen] at this
  have hExp : present.length + 2 * steps.length - steps.length =
      present.length + steps.length := by omega
  rwa [hExp] at this

omit [DecidableEq σ] in
theorem nodup_filterMap_of_injOn {l : List σ} {f : σ → Option Nat} (h : l.Nodup)
    (hInj : ∀ s s' v, f s = some v → f s' = some v → s = s') : (l.filterMap f).Nodup := by
  induction l with
  | nil => simp
  | cons a l ih =>
      rw [List.nodup_cons] at h
      rw [List.filterMap_cons]
      cases hfa : f a with
      | none => exact ih h.2
      | some v =>
          rw [List.nodup_cons]
          refine ⟨?_, ih h.2⟩
          intro hm
          obtain ⟨b, hb, hfb⟩ := List.mem_filterMap.mp hm
          exact h.1 (hInj a b v hfa hfb ▸ hb)

/-- **The schedule and the leaves left behind are jointly uniform.** Listing
the leaves of the keys present after the call over distinct `slots`, the
schedule followed by those leaves is uniform over tapes of their combined
length. So the leaves the next call starts from are uniform and independent of
everything this call showed the host, which is the premise of
`observedLeaves_uniform` for the next call. -/
theorem observedLeaves_finalLeaves_uniform (L : Nat) (present : List σ) {slots : List σ}
    (hSlots : slots.Nodup) (steps : List (LeafStep σ)) :
    let finals := slots.filterMap (runVars present.length (initialVars present) steps).2
    ((coinTapes L (present.length + 2 * steps.length)).map
        fun tape => observedLeaves present steps tape ++ finalLeaves present slots steps tape).Perm
      ((coinTapes L (steps.length + finals.length)).flatMap fun v =>
        List.replicate (L ^ (present.length + 2 * steps.length - (steps.length + finals.length))) v) := by
  intro finals
  obtain ⟨hNodup, hBound, hGone, hFreshF, -, -⟩ := runVars_spec (fresh_initialVars present) steps
  have hLen := length_runVars present.length (initialVars present) steps
  let os := (runVars present.length (initialVars present) steps).1
  have hFinalsNodup : finals.Nodup := nodup_filterMap_of_injOn hSlots hFreshF.2
  have hAll : (os ++ finals).Nodup := by
    rw [List.nodup_append]
    refine ⟨hNodup, hFinalsNodup, ?_⟩
    intro o ho v hv hov
    subst hov
    obtain ⟨s, _, hs⟩ := List.mem_filterMap.mp hv
    exact hGone o ho s hs
  have hAllBound : ∀ p ∈ os ++ finals, p < present.length + 2 * steps.length := by
    intro p hp
    rcases List.mem_append.mp hp with hp | hp
    · exact hBound p hp
    · obtain ⟨s, _, hs⟩ := List.mem_filterMap.mp hp
      exact hFreshF.1 s p hs
  have hMap : (coinTapes L (present.length + 2 * steps.length)).map
      (fun tape => observedLeaves present steps tape ++ finalLeaves present slots steps tape) =
      (coinTapes L (present.length + 2 * steps.length)).map (readAt (os ++ finals)) := by
    apply List.map_congr_left
    intro tape _
    rw [observedLeaves_eq_readAt]
    simp only [finalLeaves, runLeaves_readVars, readAt, List.map_append, os, finals]
    congr 1
    rw [List.map_filterMap]
    rfl
  rw [hMap]
  have := map_readAt_coinTapes_perm (L := L) hAll hAllBound
  rwa [List.length_append, hLen] at this


/-! ## The runtime follows the model -/

/-- The access a validated runtime transition makes, by what it does to the
key's leaf. -/
def LeafStep.ofTransition (transition : RuntimePathOramTransitionCertificate) : LeafStep Nat :=
  match transition.kind, transition.slotIndex with
  | .readHit, some slot => .remap slot
  | .writeUpdate, some slot => .remap slot
  | .writeNoop, some slot => .remap slot
  | .writeInsert, some slot => .insert slot
  | .writeDelete, some slot => .delete slot
  | _, _ => .miss

/-- A position-map certificate's leaves as a partial map from slots. -/
def leafMapOf (leaves : List (Option Nat)) : Nat → Option Nat :=
  fun slot => (leaves[slot]?).join

theorem getLeafAt?_eq (leaves : List (Option Nat)) (slot : Nat) :
    runtimePathOramGetLeafAt? leaves slot = leaves[slot]? := by
  induction leaves generalizing slot with
  | nil => cases slot <;> rfl
  | cons current leaves ih =>
      cases slot with
      | zero => rfl
      | succ slot => simp [runtimePathOramGetLeafAt?, ih]

theorem leafMapOf_setLeafAt? {leaves updated : List (Option Nat)} {slot : Nat}
    {value : Option Nat} (h : runtimePathOramSetLeafAt? leaves slot value = some updated) :
    leafMapOf updated = setAt (leafMapOf leaves) slot value := by
  induction leaves generalizing slot updated with
  | nil => simp [runtimePathOramSetLeafAt?] at h
  | cons current leaves ih =>
      cases slot with
      | zero =>
          simp only [runtimePathOramSetLeafAt?, Option.some.injEq] at h
          subst h
          funext s
          cases s <;> simp [leafMapOf, setAt]
      | succ slot =>
          simp only [runtimePathOramSetLeafAt?, Option.bind_eq_bind] at h
          cases hTail : runtimePathOramSetLeafAt? leaves slot value with
          | none => simp [hTail] at h
          | some tail =>
              simp only [hTail, Option.bind_some, Option.some.injEq] at h
              subst h
              have := ih hTail
              funext s
              cases s with
              | zero => simp [leafMapOf, setAt]
              | succ s =>
                  have hs := congrFun this s
                  simp only [leafMapOf, setAt] at hs ⊢
                  simpa using hs

theorem stateLookup?_of_stateUpdate? {state state' : RuntimePathOramPositionMapState}
    {objectId : Nat} {leaves : List (Option Nat)}
    (h : runtimePathOramStateUpdate? state objectId leaves = some state') :
    runtimePathOramStateLookup? state' objectId = some leaves := by
  induction state generalizing state' with
  | nil => simp [runtimePathOramStateUpdate?] at h
  | cons entry entries ih =>
      obtain ⟨entryId, entryLeaves⟩ := entry
      simp only [runtimePathOramStateUpdate?] at h
      split at h
      · rename_i hId
        simp only [Option.some.injEq] at h
        subst h
        simp [runtimePathOramStateLookup?, hId]
      · rename_i hId
        cases hTail : runtimePathOramStateUpdate? entries objectId leaves with
        | none => simp [hTail] at h
        | some tail =>
            simp only [hTail, Option.bind_eq_bind, Option.bind_some, Option.some.injEq] at h
            subst h
            have := ih hTail
            simp only [runtimePathOramStateLookup?, List.find?_cons] at this ⊢
            simp only [hId, decide_false]
            exact this

/-- **The runtime follows the leaf model.** Every Path ORAM transition the
Lean replay accepts is one access of the leaf model: the leaf the access
reads is the runtime's observed leaf, and the position map moves as
`stepLeaves` moves it, with the observed leaf as the access's random path
and the transition's next leaf as its fresh leaf. -/
theorem applyTransition?_stepLeaves {state state' : RuntimePathOramPositionMapState}
    {objects : List RuntimeOramObjectCertificate} {leaf : RuntimeOramLeafCertificate}
    {transition : RuntimePathOramTransitionCertificate}
    (h : runtimePathOramApplyTransition? state objects leaf transition = some state')
    {leaves : List (Option Nat)}
    (hLookup : runtimePathOramStateLookup? state leaf.objectId = some leaves) :
    ∃ leaves', runtimePathOramStateLookup? state' leaf.objectId = some leaves' ∧
      stepLeaves leaf.leaf (transition.nextLeaf.getD 0) (leafMapOf leaves)
          (LeafStep.ofTransition transition) =
        (leaf.leaf, leafMapOf leaves') := by
  obtain ⟨objectId, objectName, bucketCount, kind, slotIndex, priorLeaf, nextLeaf⟩ := transition
  simp only [runtimePathOramApplyTransition?, Option.bind_eq_bind] at h
  cases hObj : runtimeOramObjectById? objects leaf.objectId with
  | none => simp [hObj] at h
  | some object =>
      simp only [hObj, Option.bind_some] at h
      split at h
      · cases h
      simp only [hLookup, Option.bind_some] at h
      cases kind <;> rcases slotIndex with _ | slot <;> rcases priorLeaf with _ | prior <;>
        rcases nextLeaf with _ | next <;> simp only at h
      all_goals
        first
        | (simp at h; done)
        | (simp at h; subst h; exact ⟨leaves, hLookup, rfl⟩)
        | (split at h
           · rename_i hCond
             obtain ⟨updated, hSet, hUpd⟩ := Option.bind_eq_some_iff.mp h
             refine ⟨updated, stateLookup?_of_stateUpdate? hUpd, ?_⟩
             simp only [Bool.and_eq_true, decide_eq_true_eq, getLeafAt?_eq] at hCond
             simp [LeafStep.ofTransition, stepLeaves, leafMapOf_setLeafAt? hSet, leafMapOf, hCond]
           · cases h)

/-- The coins a run of runtime transitions records, two per access: the leaf
the access read (its random path when it missed) and its next leaf. -/
def recordedCoins :
    List RuntimeOramLeafCertificate → List RuntimePathOramTransitionCertificate → List Nat
  | leaf :: leafs, transition :: transitions =>
      leaf.leaf :: transition.nextLeaf.getD 0 :: recordedCoins leafs transitions
  | _, _ => []

/-- A replay of one map's transitions that the Lean checker accepts is a run
of the leaf model: the leaves the accesses read are `runLeaves` of the
accesses on the recorded coins, and the final position map is the model's. -/
theorem replay_runLeaves {state final : RuntimePathOramPositionMapState}
    {objects : List RuntimeOramObjectCertificate} {leafs : List RuntimeOramLeafCertificate}
    {transitions : List RuntimePathOramTransitionCertificate} {objectId : Nat}
    (hSame : ∀ leaf ∈ leafs, leaf.objectId = objectId)
    (h : replayRuntimePathOramTransitionsAux state objects leafs transitions = some final)
    {leaves : List (Option Nat)} (hLookup : runtimePathOramStateLookup? state objectId = some leaves) :
    ∃ leaves', runtimePathOramStateLookup? final objectId = some leaves' ∧
      runLeaves (leafMapOf leaves) (transitions.map LeafStep.ofTransition)
          (recordedCoins leafs transitions) =
        (leafs.map (·.leaf), leafMapOf leaves') := by
  induction leafs generalizing state transitions leaves with
  | nil =>
      cases transitions with
      | nil =>
          simp only [replayRuntimePathOramTransitionsAux, Option.some.injEq] at h
          subst h
          exact ⟨leaves, hLookup, rfl⟩
      | cons transition transitions => simp [replayRuntimePathOramTransitionsAux] at h
  | cons leaf leafs ih =>
      cases transitions with
      | nil => simp [replayRuntimePathOramTransitionsAux] at h
      | cons transition transitions =>
          simp only [replayRuntimePathOramTransitionsAux, Option.bind_eq_bind] at h
          obtain ⟨next, hApply, hRest⟩ := Option.bind_eq_some_iff.mp h
          have hId : leaf.objectId = objectId := hSame leaf List.mem_cons_self
          obtain ⟨leaves₁, hLookup₁, hStep⟩ :=
            applyTransition?_stepLeaves hApply (hId ▸ hLookup)
          obtain ⟨leaves', hFinal, hRun⟩ :=
            ih (fun l hl => hSame l (List.mem_cons_of_mem _ hl)) hRest (hId ▸ hLookup₁)
          refine ⟨leaves', hFinal, ?_⟩
          simp only [List.map_cons, runLeaves, recordedCoins]
          simp only [List.getD_cons_zero, List.getD_cons_succ, List.drop_succ_cons,
            List.drop_zero, hStep, hRun]

/-! ## The canonical leaf-value distribution is the uniform tape -/

theorem concat_map_eq_flatMap {α β : Type} (l : List α) (f : α → List β) :
    FiniteDistribution.concat (l.map f) = l.flatMap f := by
  induction l with
  | nil => rfl
  | cons a l ih => simp [FiniteDistribution.concat, ih]

/-- For `n` accesses to one map, the canonical leaf-value distribution the
existing Path ORAM theorems use is uniform over all tapes of `n` leaves. -/
theorem samples_leafValueDistribution_replicate (object : String) (bucketCount n : Nat) :
    (pathOramLeafValueDistributionOfScaffold (List.replicate n (object, bucketCount))).samples =
      CoinTape.coinTapes (pathOramLeafChoiceCount bucketCount) n := by
  induction n with
  | zero => rfl
  | succ n ih =>
      simp only [List.replicate_succ, pathOramLeafValueDistributionOfScaffold,
        FiniteDistribution.samples_productWith, pathOramUniformLeafValueDistribution,
        FiniteDistribution.samples_chooseNat, ih, concat_map_eq_flatMap, CoinTape.coinTapes]

/-- **Enumeration-free Path ORAM schedule theorem, one map.** For any `n`
accesses to a map with `bucketCount` buckets (any keys; hits, misses,
inserts, updates, deletes, masked writes) and any `p` keys present before the
call, if the `p` leaves of those keys and the `2n` coins of the call are
uniform, the leaf schedule the host sees is distributed as the canonical
leaf-value distribution of `n` steps on that map, each schedule weighted
`L ^ (p + n)`. No seed is enumerated; the access pattern does not enter. -/
theorem observedLeaves_canonical (object : String) (bucketCount : Nat) (present : List Nat)
    (steps : List (LeafStep Nat)) :
    ((CoinTape.coinTapes (pathOramLeafChoiceCount bucketCount)
          (present.length + 2 * steps.length)).map (observedLeaves present steps)).Perm
      ((pathOramLeafValueDistributionOfScaffold
          (List.replicate steps.length (object, bucketCount))).samples.flatMap fun v =>
        List.replicate (pathOramLeafChoiceCount bucketCount ^ (present.length + steps.length)) v) := by
  rw [samples_leafValueDistribution_replicate]
  exact observedLeaves_uniform _ present steps


/-! ## Several maps -/


/-- An access to one of several maps: the map, and what it does on that map's
slots. -/
abbrev MapAccess := Nat × LeafStep Nat

def liftStep (map : Nat) : LeafStep Nat → LeafStep (Nat × Nat)
  | .remap s => .remap (map, s)
  | .miss => .miss
  | .insert s => .insert (map, s)
  | .delete s => .delete (map, s)

def liftSteps (accesses : List MapAccess) : List (LeafStep (Nat × Nat)) :=
  accesses.map fun access => liftStep access.1 access.2

/-- Coin bounds for a call on several maps: the leaves of the keys present
before the call, each below its map's leaf count, then two coins per access
below the accessed map's leaf count. -/
def coinBounds (leafCount : Nat → Nat) (accesses : List MapAccess) : List Nat :=
  accesses.flatMap fun access => [leafCount access.1, leafCount access.1]

def multiBounds (leafCount : Nat → Nat) (present : List (Nat × Nat))
    (accesses : List MapAccess) : List Nat :=
  present.map (fun key => leafCount key.1) ++ coinBounds leafCount accesses

theorem length_coinBounds (leafCount : Nat → Nat) (accesses : List MapAccess) :
    (coinBounds leafCount accesses).length = 2 * accesses.length := by
  induction accesses with
  | nil => rfl
  | cons a as ih => simp [coinBounds] at ih ⊢; omega

/-- Every key's coordinate has its map's leaf count as bound. -/
def BoundsOk (bounds : List Nat) (leafCount : Nat → Nat) (vars : Nat × Nat → Option Nat) : Prop :=
  ∀ map slot v, vars (map, slot) = some v → bounds.getD v 0 = leafCount map

theorem getD_append_right {l r : List Nat} {i : Nat} (h : l.length ≤ i) :
    (l ++ r).getD i 0 = r.getD (i - l.length) 0 := by
  simp [List.getD_eq_getElem?_getD, List.getElem?_append_right h]

theorem getD_append_left {l r : List Nat} {i : Nat} (h : i < l.length) :
    (l ++ r).getD i 0 = l.getD i 0 := by
  simp [List.getD_eq_getElem?_getD, List.getElem?_append_left h]

/-- The observed coordinate of each access has the accessed map's leaf count
as bound, so the schedule's bounds are the maps' leaf counts in access
order. -/
theorem readAt_runVars_bounds (leafCount : Nat → Nat) (pre : List Nat)
    (vars : Nat × Nat → Option Nat) (accesses : List MapAccess)
    (hOk : BoundsOk (pre ++ coinBounds leafCount accesses) leafCount vars)
    (hBelow : ∀ key v, vars key = some v → v < pre.length) :
    readAt (runVars pre.length vars (liftSteps accesses)).1 (pre ++ coinBounds leafCount accesses) =
      accesses.map fun access => leafCount access.1 := by
  induction accesses generalizing pre vars with
  | nil => rfl
  | cons access accesses ih =>
      obtain ⟨map, step⟩ := access
      have hSplit : pre ++ coinBounds leafCount ((map, step) :: accesses) =
          (pre ++ [leafCount map, leafCount map]) ++ coinBounds leafCount accesses := by
        simp [coinBounds]
      have hLen : (pre ++ [leafCount map, leafCount map]).length = pre.length + 2 := by simp
      have hCoin0 : (pre ++ coinBounds leafCount ((map, step) :: accesses)).getD pre.length 0 =
          leafCount map := by
        rw [getD_append_right (Nat.le_refl _)]; simp [coinBounds]
      have hCoin1 : (pre ++ coinBounds leafCount ((map, step) :: accesses)).getD (pre.length + 1) 0 =
          leafCount map := by
        rw [getD_append_right (by omega)]; simp [coinBounds]
      -- the state after this access keeps the bounds invariant
      have hStep : ∀ (st : LeafStep (Nat × Nat)), st = liftStep map step →
          let r := stepVars pre.length vars st
          (pre ++ coinBounds leafCount ((map, step) :: accesses)).getD r.1 0 = leafCount map ∧
            BoundsOk ((pre ++ [leafCount map, leafCount map]) ++ coinBounds leafCount accesses)
              leafCount r.2 ∧
            ∀ key v, r.2 key = some v → v < pre.length + 2 := by
        intro st hst
        rw [← hSplit]
        cases step with
        | miss =>
            subst hst
            refine ⟨hCoin0, hOk, fun key v h => by have := hBelow key v h; omega⟩
        | insert s =>
            subst hst
            refine ⟨hCoin0, ?_, ?_⟩
            · intro m s' v h
              simp only [stepVars, liftStep, setAt] at h
              split at h
              · rename_i hk; cases h; cases hk; exact hCoin1
              · exact hOk m s' v h
            · intro key v h
              simp only [stepVars, liftStep, setAt] at h
              split at h
              · cases h; omega
              · have := hBelow key v h; omega
        | remap s =>
            subst hst
            cases hv : vars (map, s) with
            | none =>
                simp only [stepVars, liftStep, hv]
                exact ⟨hCoin0, hOk, fun key v h => by have := hBelow key v h; omega⟩
            | some v0 =>
                simp only [stepVars, liftStep, hv]
                refine ⟨hOk map s v0 hv, ?_, ?_⟩
                · intro m s' v h
                  simp only [setAt] at h
                  split at h
                  · rename_i hk; cases h; cases hk; exact hCoin1
                  · exact hOk m s' v h
                · intro key v h
                  simp only [setAt] at h
                  split at h
                  · cases h; omega
                  · have := hBelow key v h; omega
        | delete s =>
            subst hst
            cases hv : vars (map, s) with
            | none =>
                simp only [stepVars, liftStep, hv]
                exact ⟨hCoin0, hOk, fun key v h => by have := hBelow key v h; omega⟩
            | some v0 =>
                simp only [stepVars, liftStep, hv]
                refine ⟨hOk map s v0 hv, ?_, ?_⟩
                · intro m s' v h
                  simp only [setAt] at h
                  split at h
                  · cases h
                  · exact hOk m s' v h
                · intro key v h
                  simp only [setAt] at h
                  split at h
                  · cases h
                  · have := hBelow key v h; omega
      obtain ⟨hObs, hOk', hBelow'⟩ := hStep (liftStep map step) rfl
      have hRest := ih (pre ++ [leafCount map, leafCount map]) (stepVars pre.length vars (liftStep map step)).2
        hOk' (by rw [hLen]; exact hBelow')
      rw [hLen] at hRest
      simp only [liftSteps, List.map_cons, runVars] at hRest ⊢
      simp only [readAt, List.map_cons] at hRest ⊢
      rw [hSplit] at hObs ⊢
      rw [hObs]
      simp only [List.cons.injEq, true_and]
      exact hRest

theorem length_liftSteps (accesses : List MapAccess) :
    (liftSteps accesses).length = accesses.length := by
  simp [liftSteps]

theorem length_multiBounds (leafCount : Nat → Nat) (present : List (Nat × Nat))
    (accesses : List MapAccess) :
    (multiBounds leafCount present accesses).length = present.length + 2 * accesses.length := by
  simp [multiBounds, length_coinBounds]

/-- **Several maps in one call.** For any accesses to any number of maps, in
any interleaving, and any keys `present` before the call (as `(map, slot)`),
if those keys' leaves and the call's coins are independent and uniform, each
below its map's leaf count, then the schedule is uniform over the accessed
maps' leaf counts in access order: every schedule appears equally often. -/
theorem multiObservedLeaves_uniform (leafCount : Nat → Nat) (present : List (Nat × Nat))
    (accesses : List MapAccess) :
    ∃ K, ((boundedTapes (multiBounds leafCount present accesses)).map
        (observedLeaves present (liftSteps accesses))).Perm
      ((boundedTapes (accesses.map fun access => leafCount access.1)).flatMap fun v =>
        List.replicate K v) := by
  obtain ⟨hNodup, hBound, -, -, -, -⟩ := runVars_spec (fresh_initialVars present) (liftSteps accesses)
  have hBound' : ∀ p ∈ (runVars present.length (initialVars present) (liftSteps accesses)).1,
      p < (multiBounds leafCount present accesses).length := by
    intro p hp
    rw [length_multiBounds, ← length_liftSteps]
    exact hBound p hp
  obtain ⟨rest, hPerm⟩ := map_readAt_boundedTapes_perm (bounds := multiBounds leafCount present accesses)
    hNodup hBound'
  refine ⟨(boundedTapes (readAt rest (multiBounds leafCount present accesses))).length, ?_⟩
  have hMap : (boundedTapes (multiBounds leafCount present accesses)).map
      (observedLeaves present (liftSteps accesses)) =
      (boundedTapes (multiBounds leafCount present accesses)).map
        (readAt (runVars present.length (initialVars present) (liftSteps accesses)).1) := by
    apply List.map_congr_left
    intro tape _
    exact observedLeaves_eq_readAt present (liftSteps accesses) tape
  rw [hMap]
  have hPre : (present.map fun key => leafCount key.1).length = present.length := by simp
  have hReadBounds :
      readAt (runVars present.length (initialVars present) (liftSteps accesses)).1
          (multiBounds leafCount present accesses) =
        accesses.map fun access => leafCount access.1 := by
    have := readAt_runVars_bounds leafCount (present.map fun key => leafCount key.1)
      (initialVars present) accesses ?_ ?_
    · rw [hPre] at this
      exact this
    · intro map slot v h
      obtain ⟨hv, hpv⟩ := initialVars_eq_some h
      rw [getD_append_left (by simpa using hv), getD_of_lt (by simpa using hv)]
      simp only [List.getElem_map, hpv]
    · intro key v h
      rw [hPre]
      exact (fresh_initialVars present).1 key v h
  rw [hReadBounds] at hPerm
  exact hPerm



/-- The canonical leaf-value distribution of any scaffold is uniform over
independent leaves, each below its step's leaf count. -/
theorem samples_leafValueDistribution (scaffold : PathOramLeafScheduleScaffold) :
    (pathOramLeafValueDistributionOfScaffold scaffold).samples =
      boundedTapes (scaffold.map fun step => pathOramLeafChoiceCount step.2) := by
  induction scaffold with
  | nil => rfl
  | cons step scaffold ih =>
      obtain ⟨object, bucketCount⟩ := step
      simp only [pathOramLeafValueDistributionOfScaffold, FiniteDistribution.samples_productWith,
        pathOramUniformLeafValueDistribution, FiniteDistribution.samples_chooseNat, ih,
        concat_map_eq_flatMap, List.map_cons, boundedTapes]

/-- **Enumeration-free Path ORAM schedule theorem, several maps.** A call
whose accesses touch maps `0, 1, …` (map `i` named `name i` with
`bucketCount i` buckets), in any interleaving and with any keys present
before the call: if the keys' leaves and the call's coins are independent and
uniform, the schedule is distributed as the canonical leaf-value distribution
of the call's scaffold, every schedule equally often. -/
theorem multiObservedLeaves_canonical (name : Nat → String) (bucketCount : Nat → Nat)
    (present : List (Nat × Nat)) (accesses : List MapAccess) :
    ∃ K, ((boundedTapes (multiBounds (fun map => pathOramLeafChoiceCount (bucketCount map))
          present accesses)).map (observedLeaves present (liftSteps accesses))).Perm
      ((pathOramLeafValueDistributionOfScaffold
          (accesses.map fun access => (name access.1, bucketCount access.1))).samples.flatMap
        fun v => List.replicate K v) := by
  obtain ⟨K, hK⟩ := multiObservedLeaves_uniform
    (fun map => pathOramLeafChoiceCount (bucketCount map)) present accesses
  refine ⟨K, ?_⟩
  rw [samples_leafValueDistribution, List.map_map]
  exact hK


/-! ## The runtime follows the model on several maps -/

theorem stateLookup?_of_stateUpdate?_ne {state state' : RuntimePathOramPositionMapState}
    {objectId other : Nat} {leaves : List (Option Nat)}
    (h : runtimePathOramStateUpdate? state objectId leaves = some state') (hne : other ≠ objectId) :
    runtimePathOramStateLookup? state' other = runtimePathOramStateLookup? state other := by
  induction state generalizing state' with
  | nil => simp [runtimePathOramStateUpdate?] at h
  | cons entry entries ih =>
      obtain ⟨entryId, entryLeaves⟩ := entry
      simp only [runtimePathOramStateUpdate?] at h
      split at h
      · rename_i hId
        simp only [Option.some.injEq] at h
        subst h
        subst hId
        simp [runtimePathOramStateLookup?, Ne.symm hne]
      · cases hTail : runtimePathOramStateUpdate? entries objectId leaves with
        | none => simp [hTail] at h
        | some tail =>
            simp only [hTail, Option.bind_eq_bind, Option.bind_some, Option.some.injEq] at h
            subst h
            have := ih hTail
            by_cases hId' : entryId = other
            · simp [runtimePathOramStateLookup?, hId']
            · simp only [runtimePathOramStateLookup?, List.find?_cons, hId', decide_false] at this ⊢
              exact this

/-- A transition the replay accepts changes only its own map's entry, and
that entry exists. -/
theorem applyTransition?_frame {state state' : RuntimePathOramPositionMapState}
    {objects : List RuntimeOramObjectCertificate} {leaf : RuntimeOramLeafCertificate}
    {transition : RuntimePathOramTransitionCertificate}
    (h : runtimePathOramApplyTransition? state objects leaf transition = some state') :
    (∃ leaves, runtimePathOramStateLookup? state leaf.objectId = some leaves) ∧
      ∀ other, other ≠ leaf.objectId →
        runtimePathOramStateLookup? state' other = runtimePathOramStateLookup? state other := by
  obtain ⟨objectId, objectName, bucketCount, kind, slotIndex, priorLeaf, nextLeaf⟩ := transition
  simp only [runtimePathOramApplyTransition?, Option.bind_eq_bind] at h
  cases hObj : runtimeOramObjectById? objects leaf.objectId with
  | none => simp [hObj] at h
  | some object =>
      simp only [hObj, Option.bind_some] at h
      split at h
      · cases h
      cases hLookup : runtimePathOramStateLookup? state leaf.objectId with
      | none => simp [hLookup] at h
      | some leaves =>
          refine ⟨⟨leaves, rfl⟩, ?_⟩
          intro other hne
          simp only [hLookup, Option.bind_some] at h
          cases kind <;> rcases slotIndex with _ | slot <;> rcases priorLeaf with _ | prior <;>
            rcases nextLeaf with _ | next <;> simp only at h
          all_goals
            first
            | (simp at h; done)
            | (simp at h; subst h; rfl)
            | (split at h
               · obtain ⟨updated, _, hUpd⟩ := Option.bind_eq_some_iff.mp h
                 exact stateLookup?_of_stateUpdate?_ne hUpd hne
               · cases h)

/-- The replay state as one partial map from `(map, slot)` to leaves. -/
def stateLeafMap (state : RuntimePathOramPositionMapState) : Nat × Nat → Option Nat :=
  fun key =>
    match runtimePathOramStateLookup? state key.1 with
    | some leaves => leafMapOf leaves key.2
    | none => none

theorem stepLeaves_liftStep (missCoin nextCoin : Nat) (combined : Nat × Nat → Option Nat)
    (map : Nat) (step : LeafStep Nat) :
    stepLeaves missCoin nextCoin combined (liftStep map step) =
      ((stepLeaves missCoin nextCoin (fun slot => combined (map, slot)) step).1,
        fun key => if key.1 = map then
          (stepLeaves missCoin nextCoin (fun slot => combined (map, slot)) step).2 key.2
        else combined key) := by
  have hFrame : combined = fun key => if key.1 = map then combined (map, key.2) else combined key := by
    funext key
    obtain ⟨m, s⟩ := key
    by_cases hm : m = map
    · subst hm; simp
    · simp [hm]
  cases step with
  | miss =>
      simp only [liftStep, stepLeaves]
      exact Prod.ext rfl hFrame
  | insert s =>
      simp only [liftStep, stepLeaves]
      refine Prod.ext rfl ?_
      funext key
      obtain ⟨m, s'⟩ := key
      by_cases hm : m = map
      · subst hm; by_cases hs : s' = s <;> simp [setAt, hs]
      · simp [setAt, hm]
  | remap s =>
      cases hv : combined (map, s) with
      | none =>
          simp only [liftStep, stepLeaves, hv]
          exact Prod.ext rfl hFrame
      | some v =>
          simp only [liftStep, stepLeaves, hv]
          refine Prod.ext rfl ?_
          funext key
          obtain ⟨m, s'⟩ := key
          by_cases hm : m = map
          · subst hm; by_cases hs : s' = s <;> simp [setAt, hs]
          · simp [setAt, hm]
  | delete s =>
      cases hv : combined (map, s) with
      | none =>
          simp only [liftStep, stepLeaves, hv]
          exact Prod.ext rfl hFrame
      | some v =>
          simp only [liftStep, stepLeaves, hv]
          refine Prod.ext rfl ?_
          funext key
          obtain ⟨m, s'⟩ := key
          by_cases hm : m = map
          · subst hm; by_cases hs : s' = s <;> simp [setAt, hs]
          · simp [setAt, hm]

/-- The accesses of a run of runtime transitions, on `(map, slot)` keys. -/
def transitionAccesses :
    List RuntimeOramLeafCertificate → List RuntimePathOramTransitionCertificate → List MapAccess
  | leaf :: leafs, transition :: transitions =>
      (leaf.objectId, LeafStep.ofTransition transition) :: transitionAccesses leafs transitions
  | _, _ => []

/-- **The runtime follows the model on several maps.** A replay the Lean
checker accepts, interleaving any maps, is a run of the leaf model on
`(map, slot)` keys with the recorded coins. -/
theorem replay_runLeaves_interleaved {state final : RuntimePathOramPositionMapState}
    {objects : List RuntimeOramObjectCertificate} {leafs : List RuntimeOramLeafCertificate}
    {transitions : List RuntimePathOramTransitionCertificate}
    (h : replayRuntimePathOramTransitionsAux state objects leafs transitions = some final) :
    runLeaves (stateLeafMap state) (liftSteps (transitionAccesses leafs transitions))
        (recordedCoins leafs transitions) =
      (leafs.map (·.leaf), stateLeafMap final) := by
  induction leafs generalizing state transitions with
  | nil =>
      cases transitions with
      | nil =>
          simp only [replayRuntimePathOramTransitionsAux, Option.some.injEq] at h
          subst h
          rfl
      | cons transition transitions => simp [replayRuntimePathOramTransitionsAux] at h
  | cons leaf leafs ih =>
      cases transitions with
      | nil => simp [replayRuntimePathOramTransitionsAux] at h
      | cons transition transitions =>
          simp only [replayRuntimePathOramTransitionsAux, Option.bind_eq_bind] at h
          obtain ⟨next, hApply, hRest⟩ := Option.bind_eq_some_iff.mp h
          obtain ⟨⟨leaves, hLookup⟩, hFrame⟩ := applyTransition?_frame hApply
          obtain ⟨leaves', hLookup', hStep⟩ := applyTransition?_stepLeaves hApply hLookup
          have hRun := ih hRest
          have hSlots : (fun slot => stateLeafMap state (leaf.objectId, slot)) = leafMapOf leaves := by
            funext slot
            simp [stateLeafMap, hLookup]
          have hNext : stateLeafMap next = fun key =>
              if key.1 = leaf.objectId then leafMapOf leaves' key.2 else stateLeafMap state key := by
            funext key
            obtain ⟨m, s⟩ := key
            by_cases hm : m = leaf.objectId
            · subst hm; simp [stateLeafMap, hLookup']
            · simp only [stateLeafMap, hm, if_false, hFrame m hm]
          simp only [transitionAccesses, liftSteps, List.map_cons, runLeaves, recordedCoins,
            List.getD_cons_zero, List.getD_cons_succ, List.drop_succ_cons, List.drop_zero]
          rw [stepLeaves_liftStep, hSlots, hStep]
          rw [← hNext]
          simp only [liftSteps] at hRun
          rw [hRun]

end PathOramFreshLeaves

end UOToolchain
