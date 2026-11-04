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

Scope: one map. Several maps interleave by the public schedule, each with its
own coins; that product is not stated here.
-/

namespace UOToolchain

namespace PathOramFreshLeaves

open CoinTape

/-- One access to a Path ORAM map, by what it does to the accessed key's leaf:
`remap` (read hit, update, or masked write on a present key) reads the key's
path and gives the key a fresh leaf; `miss` (read miss, or masked write on an
absent key) reads a fresh random path; `insert` reads a fresh random path and
gives the new key a fresh leaf; `delete` reads the key's path and drops it. -/
inductive LeafStep
  | remap (slot : Nat)
  | miss
  | insert (slot : Nat)
  | delete (slot : Nat)
deriving Repr, DecidableEq

/-- A partial map from slots, updated at one slot. -/
def setAt (m : Nat → Option Nat) (slot : Nat) (v : Option Nat) : Nat → Option Nat :=
  fun s => if s = slot then v else m s

/-! ## Leaves: what the runtime computes from its coins -/

/-- One access on leaf values: the observed leaf, and the new position map.
`missCoin` is the access's random path, `nextCoin` its fresh leaf. -/
def stepLeaves (missCoin nextCoin : Nat) (leaves : Nat → Option Nat) :
    LeafStep → Nat × (Nat → Option Nat)
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
fresh leaf), as the runtime does. -/
def runLeaves (leaves : Nat → Option Nat) : List LeafStep → List Nat → List Nat × (Nat → Option Nat)
  | [], _ => ([], leaves)
  | step :: steps, coins =>
      let r := stepLeaves (coins.getD 0 0) (coins.getD 1 0) leaves step
      let rest := runLeaves r.2 steps (coins.drop 2)
      (r.1 :: rest.1, rest.2)

/-! ## Coordinates: which tape entry each leaf is -/

/-- One access on tape coordinates: `base` is the coordinate of the access's
random path and `base + 1` that of its fresh leaf. -/
def stepVars (base : Nat) (vars : Nat → Option Nat) : LeafStep → Nat × (Nat → Option Nat)
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

def runVars (start : Nat) (vars : Nat → Option Nat) : List LeafStep → List Nat × (Nat → Option Nat)
  | [] => ([], vars)
  | step :: steps =>
      let r := stepVars start vars step
      let rest := runVars (start + 2) r.2 steps
      (r.1 :: rest.1, rest.2)

theorem length_runVars (start : Nat) (vars : Nat → Option Nat) (steps : List LeafStep) :
    (runVars start vars steps).1.length = steps.length := by
  induction steps generalizing start vars with
  | nil => rfl
  | cons step steps ih => simp [runVars, ih]

/-- Reading a tape through a coordinate map. -/
def readVars (tape : List Nat) (vars : Nat → Option Nat) : Nat → Option Nat :=
  fun s => (vars s).map fun v => tape.getD v 0

theorem readVars_setAt (tape : List Nat) (vars : Nat → Option Nat) (s : Nat) (v : Option Nat) :
    readVars tape (setAt vars s v) = setAt (readVars tape vars) s (v.map fun v => tape.getD v 0) := by
  funext s'
  simp only [readVars, setAt]
  split <;> rfl

theorem stepLeaves_readVars (tape : List Nat) (base : Nat) (vars : Nat → Option Nat)
    (step : LeafStep) :
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
theorem runLeaves_readVars (tape : List Nat) (start : Nat) (vars : Nat → Option Nat)
    (steps : List LeafStep) :
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
def Fresh (start : Nat) (vars : Nat → Option Nat) : Prop :=
  (∀ s v, vars s = some v → v < start) ∧
    (∀ s s' v, vars s = some v → vars s' = some v → s = s')

theorem stepVars_spec {start : Nat} {vars : Nat → Option Nat} (hFresh : Fresh start vars)
    (step : LeafStep) :
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

theorem runVars_spec {start : Nat} {vars : Nat → Option Nat} (hFresh : Fresh start vars)
    (steps : List LeafStep) :
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

theorem getElem_idxOf_of_mem {l : List Nat} {a : Nat} (h : a ∈ l) :
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
def initialVars (present : List Nat) : Nat → Option Nat :=
  fun s => if s ∈ present then some (present.idxOf s) else none

theorem fresh_initialVars (present : List Nat) : Fresh present.length (initialVars present) := by
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
      have := congrArg (fun i => present.getD i 0) (Option.some.inj h')
      simp only at this
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hs'),
        List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hs),
        Option.getD_some, Option.getD_some, getElem_idxOf_of_mem hs, getElem_idxOf_of_mem hs']
        at this
      exact this.symm
    · cases h'
    · cases h
    · cases h

/-- The leaf schedule a call shows the host: one leaf per access. The call
starts with the keys in `present`, whose leaves are the first
`present.length` coordinates of `tape`; the rest of the tape is the call's
coins, two per access. -/
def observedLeaves (present : List Nat) (steps : List LeafStep) (tape : List Nat) : List Nat :=
  (runLeaves (readVars tape (initialVars present)) steps (tape.drop present.length)).1

/-- The leaves of the keys present after the call, listed over `slots`. -/
def finalLeaves (present slots : List Nat) (steps : List LeafStep) (tape : List Nat) :
    List Nat :=
  slots.filterMap (runLeaves (readVars tape (initialVars present)) steps
    (tape.drop present.length)).2

theorem observedLeaves_eq_readAt (present : List Nat) (steps : List LeafStep) (tape : List Nat) :
    observedLeaves present steps tape =
      readAt (runVars present.length (initialVars present) steps).1 tape := by
  simp [observedLeaves, runLeaves_readVars, readAt]

/-- **The leaf schedule is uniform whatever the accesses are.** Over all
`L ^ (p + 2n)` tapes (the `p` leaves of the keys present before the call and
the `2n` coins of its `n` accesses), every schedule of `n` leaves appears
`L ^ (p + n)` times, for every sequence of `n` accesses (hits, misses,
inserts, deletes, masked writes, on any keys). -/
theorem observedLeaves_uniform (L : Nat) (present : List Nat) (steps : List LeafStep) :
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

theorem nodup_filterMap_of_injOn {l : List Nat} {f : Nat → Option Nat} (h : l.Nodup)
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
theorem observedLeaves_finalLeaves_uniform (L : Nat) (present : List Nat) {slots : List Nat}
    (hSlots : slots.Nodup) (steps : List LeafStep) :
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

/-- The access a validated runtime transition makes, by what it does to the
key's leaf. -/
def LeafStep.ofTransition (transition : RuntimePathOramTransitionCertificate) : LeafStep :=
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
    (steps : List LeafStep) :
    ((CoinTape.coinTapes (pathOramLeafChoiceCount bucketCount)
          (present.length + 2 * steps.length)).map (observedLeaves present steps)).Perm
      ((pathOramLeafValueDistributionOfScaffold
          (List.replicate steps.length (object, bucketCount))).samples.flatMap fun v =>
        List.replicate (pathOramLeafChoiceCount bucketCount ^ (present.length + steps.length)) v) := by
  rw [samples_leafValueDistribution_replicate]
  exact observedLeaves_uniform _ present steps


end PathOramFreshLeaves

end UOToolchain
