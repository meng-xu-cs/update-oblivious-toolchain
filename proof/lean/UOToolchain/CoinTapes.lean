/-!
# Uniform coin tapes

`coinTapes L m` lists every tape of `m` coins below `L`, the uniform
distribution over such tapes; `boundedTapes bounds` lets each coordinate have
its own bound. Reading such tapes at `n` distinct coordinates gives the tapes
of those coordinates, each equally often (`map_readAt_coinTapes_perm`,
`map_readAt_boundedTapes_perm`). `PathOramFreshLeaves` uses this to show that
a Path ORAM leaf schedule is uniform whatever the accesses are.
-/

namespace UOToolchain

namespace CoinTape

/-! ## Generic list facts -/

theorem count_eq_ite_of_nodup {α : Type} [BEq α] [LawfulBEq α] {l : List α} (h : l.Nodup) (a : α) :
    l.count a = if a ∈ l then 1 else 0 := by
  induction l with
  | nil => simp
  | cons b l ih =>
      rw [List.nodup_cons] at h
      rw [List.count_cons, ih h.2]
      by_cases hab : b = a
      · subst hab
        simp [h.1]
      · have hba : (b == a) = false := by simpa using hab
        by_cases ha : a ∈ l
        · simp [ha, hba]
        · have : a ∉ b :: l := by
            intro hm
            rcases List.mem_cons.mp hm with h' | h'
            · exact hab h'.symm
            · exact ha h'
          simp [ha, hba, this]

theorem perm_of_nodup_of_mem_iff {α : Type} [BEq α] [LawfulBEq α] {l₁ l₂ : List α}
    (h₁ : l₁.Nodup) (h₂ : l₂.Nodup)
    (hMem : ∀ a, a ∈ l₁ ↔ a ∈ l₂) : l₁.Perm l₂ := by
  rw [List.perm_iff_count]
  intro a
  rw [count_eq_ite_of_nodup h₁, count_eq_ite_of_nodup h₂]
  by_cases ha : a ∈ l₁
  · simp [ha, (hMem a).mp ha]
  · have : a ∉ l₂ := fun h => ha ((hMem a).mpr h)
    simp [ha, this]

theorem nodup_map_of_injOn {α β : Type} {l : List α} {f : α → β} (h : l.Nodup)
    (hInj : ∀ x ∈ l, ∀ y ∈ l, f x = f y → x = y) : (l.map f).Nodup := by
  induction l with
  | nil => simp
  | cons a l ih =>
      rw [List.nodup_cons] at h
      rw [List.map_cons, List.nodup_cons]
      refine ⟨?_, ih h.2 (fun x hx y hy hxy => hInj x (List.mem_cons_of_mem _ hx) y
        (List.mem_cons_of_mem _ hy) hxy)⟩
      intro hm
      obtain ⟨b, hb, hfb⟩ := List.mem_map.mp hm
      have := hInj b (List.mem_cons_of_mem _ hb) a (List.mem_cons_self) hfb
      subst this
      exact h.1 hb

/-! ## Coin tapes -/

/-- Every coin tape of length `m` whose coins are below `L`, in
lexicographic order. -/
def coinTapes (L : Nat) : Nat → List (List Nat)
  | 0 => [[]]
  | m + 1 => (List.range L).flatMap fun x => (coinTapes L m).map (x :: ·)

/-- A coin tape of length `m` over `L` choices. -/
def IsCoinTape (L m : Nat) (t : List Nat) : Prop :=
  t.length = m ∧ ∀ x ∈ t, x < L

theorem mem_coinTapes {L m : Nat} {t : List Nat} :
    t ∈ coinTapes L m ↔ IsCoinTape L m t := by
  induction m generalizing t with
  | zero =>
      cases t with
      | nil => simp [coinTapes, IsCoinTape]
      | cons x t => simp [coinTapes, IsCoinTape]
  | succ m ih =>
      cases t with
      | nil => simp [coinTapes, IsCoinTape]
      | cons x t =>
          simp only [coinTapes, List.mem_flatMap, List.mem_range, List.mem_map,
            List.cons.injEq]
          constructor
          · rintro ⟨y, hy, r, hr, rfl, rfl⟩
            have := ih.mp hr
            refine ⟨by simp [this.1], ?_⟩
            intro z hz
            rcases List.mem_cons.mp hz with rfl | hz
            · exact hy
            · exact this.2 z hz
          · rintro ⟨hLen, hLt⟩
            refine ⟨x, hLt x List.mem_cons_self, t, ih.mpr ⟨?_, ?_⟩, rfl, rfl⟩
            · simpa using hLen
            · intro z hz
              exact hLt z (List.mem_cons_of_mem _ hz)

theorem nodup_coinTapes (L m : Nat) : (coinTapes L m).Nodup := by
  induction m with
  | zero => simp [coinTapes]
  | succ m ih =>
      simp only [coinTapes]
      unfold List.Nodup
      rw [List.pairwise_flatMap]
      refine ⟨?_, ?_⟩
      · intro x _
        exact nodup_map_of_injOn ih (fun a _ b _ h => by simpa using h)
      · refine List.nodup_range.imp ?_
        intro x y hxy
        simp only [List.mem_map]
        rintro t ⟨a, _, rfl⟩ s ⟨b, _, rfl⟩ hts
        exact hxy (List.cons.inj hts).1

theorem length_flatMap_of_length_eq {α β : Type} {l : List α} {f : α → List β} {k : Nat}
    (h : ∀ x ∈ l, (f x).length = k) : (l.flatMap f).length = l.length * k := by
  induction l with
  | nil => simp
  | cons a l ih =>
      rw [List.flatMap_cons, List.length_append, h a List.mem_cons_self,
        ih (fun x hx => h x (List.mem_cons_of_mem _ hx)), List.length_cons, Nat.succ_mul]
      exact Nat.add_comm _ _

theorem length_coinTapes (L m : Nat) : (coinTapes L m).length = L ^ m := by
  induction m with
  | zero => simp [coinTapes]
  | succ m ih =>
      simp only [coinTapes]
      rw [length_flatMap_of_length_eq (k := L ^ m) (fun x _ => by simp [ih]),
        List.length_range, Nat.pow_succ, Nat.mul_comm]

/-- Splitting a tape: the first `a` coins range over all tapes of length `a`,
and for each the last `b` coins over all tapes of length `b`. -/
theorem coinTapes_add (L a b : Nat) :
    coinTapes L (a + b) = (coinTapes L a).flatMap fun v => (coinTapes L b).map (v ++ ·) := by
  induction a with
  | zero => simp [coinTapes]
  | succ a ih =>
      rw [Nat.succ_add]
      simp only [coinTapes, ih, List.map_flatMap, List.flatMap_assoc, List.flatMap_map,
        List.map_map]
      rfl

theorem flatMap_congr_mem {α β : Type} {l : List α} {f g : α → List β}
    (h : ∀ x ∈ l, f x = g x) : l.flatMap f = l.flatMap g := by
  induction l with
  | nil => rfl
  | cons a l ih =>
      rw [List.flatMap_cons, List.flatMap_cons, h a List.mem_cons_self,
        ih (fun x hx => h x (List.mem_cons_of_mem _ hx))]

theorem map_take_coinTapes (L a b : Nat) :
    (coinTapes L (a + b)).map (List.take a) =
      (coinTapes L a).flatMap fun v => List.replicate (L ^ b) v := by
  rw [coinTapes_add, List.map_flatMap]
  apply flatMap_congr_mem
  intro v hv
  have hLen : v.length = a := (mem_coinTapes.mp hv).1
  rw [List.map_map]
  have : ((fun w => List.take a w) ∘ fun w => v ++ w) = fun _ => v := by
    funext w
    exact List.take_left' hLen
  rw [this, List.map_const', length_coinTapes]

/-- Read a tape at the given coordinates, in order. -/
def readAt (positions : List Nat) (tape : List Nat) : List Nat :=
  positions.map fun p => tape.getD p 0

theorem readAt_isCoinTape {L m : Nat} {order : List Nat} {t : List Nat}
    (hOrder : ∀ p ∈ order, p < m) (ht : IsCoinTape L m t) :
    IsCoinTape L order.length (readAt order t) := by
  refine ⟨by simp [readAt], ?_⟩
  intro x hx
  simp only [readAt, List.mem_map] at hx
  obtain ⟨p, hp, rfl⟩ := hx
  have hpLen : p < t.length := ht.1 ▸ hOrder p hp
  rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hpLen, Option.getD_some]
  exact ht.2 _ (List.getElem_mem hpLen)

theorem idxOf_getElem_of_nodup {l : List Nat} (h : l.Nodup) {j : Nat} (hj : j < l.length) :
    l.idxOf l[j] = j := by
  induction l generalizing j with
  | nil => simp at hj
  | cons a l ih =>
      rw [List.nodup_cons] at h
      cases j with
      | zero => simp [List.idxOf_cons_self]
      | succ j =>
          have hj' : j < l.length := by simpa using hj
          rw [List.getElem_cons_succ, List.idxOf_cons]
          have hne : (a == l[j]) = false := by
            rw [beq_eq_false_iff_ne]
            intro h'
            exact h.1 (h' ▸ List.getElem_mem hj')
          rw [hne, cond_false, ih h.2 hj']

theorem getD_of_lt {t : List Nat} {p : Nat} (hp : p < t.length) : t.getD p 0 = t[p] := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hp, Option.getD_some]

/-- Reading tapes through a permutation of their coordinates permutes the
tapes: every tape of length `m` arises exactly once. -/
theorem map_readAt_perm_coinTapes {L m : Nat} {order : List Nat}
    (hOrder : order.Perm (List.range m)) :
    ((coinTapes L m).map (readAt order)).Perm (coinTapes L m) := by
  have hLen : order.length = m := by simpa using hOrder.length_eq
  have hNodup : order.Nodup := hOrder.nodup_iff.mpr List.nodup_range
  have hBound : ∀ p ∈ order, p < m := fun p hp => List.mem_range.mp (hOrder.mem_iff.mp hp)
  have hCover : ∀ q < m, q ∈ order := fun q hq => hOrder.mem_iff.mpr (List.mem_range.mpr hq)
  apply perm_of_nodup_of_mem_iff
  · refine nodup_map_of_injOn (nodup_coinTapes L m) ?_
    intro t ht s hs hts
    have ht' := (mem_coinTapes.mp ht).1
    have hs' := (mem_coinTapes.mp hs).1
    apply List.ext_getElem (by rw [ht', hs'])
    intro i hi _
    have hiOrder : i ∈ order := hCover i (ht' ▸ hi)
    obtain ⟨j, hj, hji⟩ := List.mem_iff_getElem.mp hiOrder
    have h1 := congrArg (fun r => r.getD j 0) hts
    have his : i < s.length := by rw [hs', ← ht']; exact hi
    simp only [readAt, List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hj, Option.map_some, Option.getD_some, hji,
      List.getElem?_eq_getElem hi, List.getElem?_eq_getElem his] at h1
    exact h1
  · exact nodup_coinTapes L m
  · intro a
    constructor
    · intro hm
      obtain ⟨t, ht, rfl⟩ := List.mem_map.mp hm
      apply mem_coinTapes.mpr
      have := readAt_isCoinTape hBound (mem_coinTapes.mp ht)
      rwa [hLen] at this
    · intro ha
      have ha' := mem_coinTapes.mp ha
      let t := (List.range m).map fun q => a.getD (order.idxOf q) 0
      have htLen : t.length = m := by simp [t]
      refine List.mem_map.mpr ⟨t, mem_coinTapes.mpr ⟨htLen, ?_⟩, ?_⟩
      · intro x hx
        simp only [t, List.mem_map, List.mem_range] at hx
        obtain ⟨q, hq, rfl⟩ := hx
        have hIdx : order.idxOf q < a.length := by
          rw [ha'.1, ← hLen]
          exact List.idxOf_lt_length_of_mem (hCover q hq)
        rw [getD_of_lt hIdx]
        exact ha'.2 _ (List.getElem_mem hIdx)
      · apply List.ext_getElem (by simp [readAt, hLen, ha'.1])
        intro j hj hja
        have hjo : j < order.length := by simpa [readAt] using hj
        have hp : order[j] < t.length := by rw [htLen]; exact hBound _ (List.getElem_mem hjo)
        simp only [readAt, List.getElem_map]
        rw [getD_of_lt hp]
        simp only [t, List.getElem_map, List.getElem_range]
        rw [idxOf_getElem_of_nodup hNodup hjo, getD_of_lt hja]

/-- Reading uniform tapes of length `m` at `n` distinct coordinates gives
uniform tapes of length `n`, each `L ^ (m - n)` times. -/
theorem map_readAt_coinTapes_perm {L m : Nat} {ps : List Nat}
    (hNodup : ps.Nodup) (hBound : ∀ p ∈ ps, p < m) :
    ((coinTapes L m).map (readAt ps)).Perm
      ((coinTapes L ps.length).flatMap fun v => List.replicate (L ^ (m - ps.length)) v) := by
  let rest := (List.range m).filter fun q => !(ps.contains q)
  have hRestNodup : rest.Nodup := (List.filter_sublist).nodup List.nodup_range
  have hOrder : (ps ++ rest).Perm (List.range m) := by
    apply perm_of_nodup_of_mem_iff
    · rw [List.nodup_append]
      refine ⟨hNodup, hRestNodup, ?_⟩
      intro a ha b hb hab
      subst hab
      simp [rest, ha] at hb
    · exact List.nodup_range
    · intro q
      simp only [List.mem_append, List.mem_range, rest, List.mem_filter,
        Bool.not_eq_eq_eq_not, Bool.not_true]
      constructor
      · rintro (h | ⟨h, _⟩)
        · exact hBound q h
        · exact h
      · intro hq
        by_cases h : q ∈ ps
        · exact Or.inl h
        · exact Or.inr ⟨hq, by simpa using h⟩
  have hLen : ps.length + rest.length = m := by
    simpa using hOrder.length_eq
  have hTake : ∀ t, readAt ps t = (readAt (ps ++ rest) t).take ps.length := by
    intro t
    simp only [readAt, List.map_append]
    exact (List.take_left' (by simp)).symm
  have hMap : (coinTapes L m).map (readAt ps) =
      ((coinTapes L m).map (readAt (ps ++ rest))).map (List.take ps.length) := by
    rw [List.map_map]
    apply List.map_congr_left
    intro t _
    exact hTake t
  rw [hMap]
  refine ((map_readAt_perm_coinTapes hOrder).map _).trans ?_
  have hm : m = ps.length + (m - ps.length) := by omega
  rw [hm, map_take_coinTapes, ← hm]

/-! ## Coins with a bound per coordinate -/

/-- Every tape whose `j`-th coin is below `bounds[j]`, in lexicographic
order: the uniform distribution over independent coins with those ranges. -/
def boundedTapes : List Nat → List (List Nat)
  | [] => [[]]
  | L :: bounds => (List.range L).flatMap fun x => (boundedTapes bounds).map (x :: ·)

/-- Coins below their bounds. -/
def WithinBounds (bounds t : List Nat) : Prop :=
  t.length = bounds.length ∧ ∀ i (hi : i < t.length) (hb : i < bounds.length), t[i] < bounds[i]

theorem mem_boundedTapes {bounds t : List Nat} :
    t ∈ boundedTapes bounds ↔ WithinBounds bounds t := by
  induction bounds generalizing t with
  | nil =>
      cases t with
      | nil => simp [boundedTapes, WithinBounds]
      | cons x t => simp [boundedTapes, WithinBounds]
  | cons L bounds ih =>
      cases t with
      | nil => simp [boundedTapes, WithinBounds]
      | cons x t =>
          simp only [boundedTapes, List.mem_flatMap, List.mem_range, List.mem_map,
            List.cons.injEq]
          constructor
          · rintro ⟨y, hy, r, hr, rfl, rfl⟩
            have := ih.mp hr
            refine ⟨by simp [this.1], ?_⟩
            intro i hi hb
            cases i with
            | zero => simpa using hy
            | succ i =>
                simp only [List.getElem_cons_succ]
                exact this.2 i (by simpa using hi) (by simpa using hb)
          · rintro ⟨hLen, hLt⟩
            refine ⟨x, by simpa using hLt 0 (by simp) (by simp), t, ih.mpr ⟨by simpa using hLen, ?_⟩,
              rfl, rfl⟩
            intro i hi hb
            simpa using hLt (i + 1) (by simpa using hi) (by simpa using hb)

theorem nodup_boundedTapes (bounds : List Nat) : (boundedTapes bounds).Nodup := by
  induction bounds with
  | nil => simp [boundedTapes]
  | cons L bounds ih =>
      simp only [boundedTapes]
      unfold List.Nodup
      rw [List.pairwise_flatMap]
      refine ⟨?_, ?_⟩
      · intro x _
        exact nodup_map_of_injOn ih (fun a _ b _ h => by simpa using h)
      · refine List.nodup_range.imp ?_
        intro x y hxy
        simp only [List.mem_map]
        rintro t ⟨a, _, rfl⟩ s ⟨b, _, rfl⟩ hts
        exact hxy (List.cons.inj hts).1

theorem boundedTapes_append (as bs : List Nat) :
    boundedTapes (as ++ bs) =
      (boundedTapes as).flatMap fun v => (boundedTapes bs).map (v ++ ·) := by
  induction as with
  | nil => simp [boundedTapes]
  | cons a as ih =>
      simp only [List.cons_append, boundedTapes, ih, List.map_flatMap, List.flatMap_assoc,
        List.flatMap_map, List.map_map]
      rfl

theorem coinTapes_eq_boundedTapes (L m : Nat) : coinTapes L m = boundedTapes (List.replicate m L) := by
  induction m with
  | zero => rfl
  | succ m ih => simp [coinTapes, boundedTapes, List.replicate_succ, ih]

theorem getElem_idxOf_of_mem' {l : List Nat} {a : Nat} (h : a ∈ l) :
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

theorem readAt_withinBounds {bounds order t : List Nat}
    (hBound : ∀ p ∈ order, p < bounds.length) (ht : WithinBounds bounds t) :
    WithinBounds (readAt order bounds) (readAt order t) := by
  refine ⟨by simp [readAt], ?_⟩
  intro i hi hb
  have hio : i < order.length := by simpa [readAt] using hi
  have hp : order[i] < bounds.length := hBound _ (List.getElem_mem hio)
  have hpt : order[i] < t.length := by rw [ht.1]; exact hp
  simp only [readAt, List.getElem_map]
  rw [getD_of_lt hpt, getD_of_lt hp]
  exact ht.2 _ hpt hp

/-- Reading tapes through a permutation of their coordinates permutes the
tapes with the correspondingly permuted bounds. -/
theorem map_readAt_perm_boundedTapes {bounds order : List Nat}
    (hOrder : order.Perm (List.range bounds.length)) :
    ((boundedTapes bounds).map (readAt order)).Perm (boundedTapes (readAt order bounds)) := by
  have hLen : order.length = bounds.length := by simpa using hOrder.length_eq
  have hNodup : order.Nodup := hOrder.nodup_iff.mpr List.nodup_range
  have hBound : ∀ p ∈ order, p < bounds.length :=
    fun p hp => List.mem_range.mp (hOrder.mem_iff.mp hp)
  have hCover : ∀ q < bounds.length, q ∈ order :=
    fun q hq => hOrder.mem_iff.mpr (List.mem_range.mpr hq)
  apply perm_of_nodup_of_mem_iff
  · refine nodup_map_of_injOn (nodup_boundedTapes bounds) ?_
    intro t ht s hs hts
    have ht' := (mem_boundedTapes.mp ht).1
    have hs' := (mem_boundedTapes.mp hs).1
    apply List.ext_getElem (by rw [ht', hs'])
    intro i hi _
    have hiOrder : i ∈ order := hCover i (ht' ▸ hi)
    obtain ⟨j, hj, hji⟩ := List.mem_iff_getElem.mp hiOrder
    have h1 := congrArg (fun r => r.getD j 0) hts
    have his : i < s.length := by rw [hs', ← ht']; exact hi
    simp only [readAt, List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hj, Option.map_some, Option.getD_some, hji,
      List.getElem?_eq_getElem hi, List.getElem?_eq_getElem his] at h1
    exact h1
  · exact nodup_boundedTapes _
  · intro a
    constructor
    · intro hm
      obtain ⟨t, ht, rfl⟩ := List.mem_map.mp hm
      exact mem_boundedTapes.mpr (readAt_withinBounds hBound (mem_boundedTapes.mp ht))
    · intro ha
      have ha' := mem_boundedTapes.mp ha
      have haLen : a.length = bounds.length := by rw [ha'.1]; simp [readAt, hLen]
      let t := (List.range bounds.length).map fun q => a.getD (order.idxOf q) 0
      have htLen : t.length = bounds.length := by simp [t]
      refine List.mem_map.mpr ⟨t, mem_boundedTapes.mpr ⟨htLen, ?_⟩, ?_⟩
      · intro q hq hqb
        have hqo : q ∈ order := hCover q hqb
        have hIdx : order.idxOf q < order.length := List.idxOf_lt_length_of_mem hqo
        have hIdxA : order.idxOf q < a.length := by rw [haLen, ← hLen]; exact hIdx
        have hIdxB : order.idxOf q < (readAt order bounds).length := by simp [readAt]; exact hIdx
        simp only [t, List.getElem_map, List.getElem_range]
        rw [getD_of_lt hIdxA]
        have hA := ha'.2 _ hIdxA hIdxB
        simp only [readAt, List.getElem_map] at hA
        have hEq : bounds.getD (order[order.idxOf q]) 0 = bounds[q] := by
          simp only [getElem_idxOf_of_mem' hqo]
          exact getD_of_lt hqb
        rw [hEq] at hA
        exact hA
      · apply List.ext_getElem (by simp [readAt, hLen, haLen])
        intro j hj hja
        have hjo : j < order.length := by simpa [readAt] using hj
        have hp : order[j] < t.length := by rw [htLen]; exact hBound _ (List.getElem_mem hjo)
        simp only [readAt, List.getElem_map]
        rw [getD_of_lt hp]
        simp only [t, List.getElem_map, List.getElem_range]
        rw [idxOf_getElem_of_nodup hNodup hjo, getD_of_lt hja]

theorem map_take_boundedTapes (as bs : List Nat) :
    (boundedTapes (as ++ bs)).map (List.take as.length) =
      (boundedTapes as).flatMap fun v => List.replicate (boundedTapes bs).length v := by
  rw [boundedTapes_append, List.map_flatMap]
  apply flatMap_congr_mem
  intro v hv
  have hLen : v.length = as.length := (mem_boundedTapes.mp hv).1
  rw [List.map_map]
  have : ((fun w => List.take as.length w) ∘ fun w => v ++ w) = fun _ => v := by
    funext w
    exact List.take_left' hLen
  rw [this, List.map_const']

/-- Reading independent coins at distinct coordinates gives independent coins
with the bounds of those coordinates, each tape as often as there are tapes of
the remaining coordinates. -/
theorem map_readAt_boundedTapes_perm {bounds ps : List Nat}
    (hNodup : ps.Nodup) (hBound : ∀ p ∈ ps, p < bounds.length) :
    ∃ rest : List Nat,
      ((boundedTapes bounds).map (readAt ps)).Perm
        ((boundedTapes (readAt ps bounds)).flatMap fun v =>
          List.replicate (boundedTapes (readAt rest bounds)).length v) := by
  let rest := (List.range bounds.length).filter fun q => !(ps.contains q)
  refine ⟨rest, ?_⟩
  have hRestNodup : rest.Nodup := (List.filter_sublist).nodup List.nodup_range
  have hOrder : (ps ++ rest).Perm (List.range bounds.length) := by
    apply perm_of_nodup_of_mem_iff
    · rw [List.nodup_append]
      refine ⟨hNodup, hRestNodup, ?_⟩
      intro a ha b hb hab
      subst hab
      simp [rest, ha] at hb
    · exact List.nodup_range
    · intro q
      simp only [List.mem_append, List.mem_range, rest, List.mem_filter,
        Bool.not_eq_eq_eq_not, Bool.not_true]
      constructor
      · rintro (h | ⟨h, _⟩)
        · exact hBound q h
        · exact h
      · intro hq
        by_cases h : q ∈ ps
        · exact Or.inl h
        · exact Or.inr ⟨hq, by simpa using h⟩
  have hTake : ∀ t, readAt ps t = (readAt (ps ++ rest) t).take (readAt ps bounds).length := by
    intro t
    simp only [readAt, List.map_append, List.length_map]
    exact (List.take_left' (by simp)).symm
  have hMap : (boundedTapes bounds).map (readAt ps) =
      ((boundedTapes bounds).map (readAt (ps ++ rest))).map
        (List.take (readAt ps bounds).length) := by
    rw [List.map_map]
    apply List.map_congr_left
    intro t _
    exact hTake t
  rw [hMap]
  refine ((map_readAt_perm_boundedTapes hOrder).map _).trans ?_
  have hSplit : readAt (ps ++ rest) bounds = readAt ps bounds ++ readAt rest bounds := by
    simp [readAt]
  rw [hSplit, map_take_boundedTapes]


end CoinTape

end UOToolchain
