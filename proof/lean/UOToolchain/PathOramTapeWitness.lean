import UOToolchain.PathOramAdmitted

/-!
# Path ORAM tape families from one runtime run

A Path ORAM call's coins and the leaves of the keys present before it decide
only where its accesses go: which keys it touches, and whether each access
hits, misses, inserts or deletes, depend on the program and its data. So one
runtime run of the call determines its run on every other tape: substitute the
leaves the leaf model draws from that tape for the run's leaves, in the leaf
schedule, the position-map transitions and states, and the bucket locations of
the trace (`substituteWitness`).

Every substituted run passes the Lean runtime-witness checks
(`substituteWitness_valid`), its leaf values are the model's on its tape, and
its public view, public locations, storage shape, outcome and boundary
schedule are the run's. So one valid run gives a `TapeRuntimePathOramWitnessFamily`
(`RuntimeRefinementWitness.toTapeFamily`), and a pair of runs gives the
paper-main theorem over the pair's two sides, with no seed enumeration.
-/

set_option autoImplicit false

namespace UOToolchain

namespace PathOramTapeWitness

open PathOramFreshLeaves CoinTape

/-! ## Replacing selected list items in order -/

/-- Two lists related item by item. -/
inductive Forall₂ {α β : Type} (R : α → β → Prop) : List α → List β → Prop
  | nil : Forall₂ R [] []
  | cons {a : α} {b : β} {as : List α} {bs : List β} :
      R a b → Forall₂ R as bs → Forall₂ R (a :: as) (b :: bs)

/-- Replace, in order, the items `p` selects: the `i`-th by `f item (new i)`,
while the new values last. -/
def replaceInOrder {α β : Type} (p : α → Bool) (f : α → β → α) : List α → List β → List α
  | [], _ => []
  | a :: as, bs =>
      if p a then
        match bs with
        | b :: bs => f a b :: replaceInOrder p f as bs
        | [] => a :: replaceInOrder p f as []
      else
        a :: replaceInOrder p f as bs

theorem length_replaceInOrder {α β : Type} (p : α → Bool) (f : α → β → α) :
    ∀ (as : List α) (bs : List β), (replaceInOrder p f as bs).length = as.length
  | [], _ => rfl
  | a :: as, bs => by
      unfold replaceInOrder
      split
      · cases bs with
        | nil => simp [length_replaceInOrder p f as []]
        | cons b bs => simp [length_replaceInOrder p f as bs]
      · simp [length_replaceInOrder p f as bs]

/-- A projection that a replacement does not change is unchanged on the whole
list, when replaced items and their new values are related. -/
theorem map_replaceInOrder {α β γ : Type} {p : α → Bool} {f : α → β → α} {g : α → γ}
    (R : α → β → Prop) (hg : ∀ a b, p a = true → R a b → g (f a b) = g a) :
    ∀ (as : List α) (bs : List β), Forall₂ R (as.filter p) bs →
      (replaceInOrder p f as bs).map g = as.map g
  | [], _, _ => rfl
  | a :: as, bs, h => by
      unfold replaceInOrder
      by_cases hp : p a = true
      · rw [List.filter_cons_of_pos hp] at h
        cases bs with
        | nil => cases h
        | cons b bs =>
            cases h with
            | cons hab hrest =>
                simp only [hp, if_true, List.map_cons, hg a b hp hab,
                  map_replaceInOrder R hg as bs hrest]
      · rw [List.filter_cons_of_neg hp] at h
        simp only [hp, if_false, Bool.false_eq_true, List.map_cons,
          map_replaceInOrder R hg as bs h]

/-- After the replacement, the selected items are the replacements, when the
replacements stay selected. -/
theorem filter_replaceInOrder {α β : Type} {p : α → Bool} {f : α → β → α}
    (R : α → β → Prop) (hp : ∀ a b, p a = true → R a b → p (f a b) = true) :
    ∀ (as : List α) (bs : List β), Forall₂ R (as.filter p) bs →
      (replaceInOrder p f as bs).filter p = List.zipWith f (as.filter p) bs
  | [], _, h => by cases h; rfl
  | a :: as, bs, h => by
      unfold replaceInOrder
      by_cases hpa : p a = true
      · rw [List.filter_cons_of_pos hpa] at h ⊢
        cases bs with
        | nil => cases h
        | cons b bs =>
            cases h with
            | cons hab hrest =>
                simp only [hpa, if_true]
                rw [List.filter_cons_of_pos (hp a b hpa hab), List.zipWith_cons_cons,
                  filter_replaceInOrder R hp as bs hrest]
      · rw [List.filter_cons_of_neg hpa] at h ⊢
        simp only [hpa, if_false, Bool.false_eq_true]
        rw [List.filter_cons_of_neg hpa, filter_replaceInOrder R hp as bs h]

/-- Each item is related to its replacement, when every replaced item is
related to every value it may get. -/
theorem forall₂_replaceInOrder {α β : Type} {p : α → Bool} {f : α → β → α}
    (E : α → α → Prop) (hRefl : ∀ a, E a a) (hE : ∀ a b, p a = true → E a (f a b)) :
    ∀ (as : List α) (bs : List β), Forall₂ E as (replaceInOrder p f as bs)
  | [], _ => Forall₂.nil
  | a :: as, bs => by
      unfold replaceInOrder
      split
      · rename_i hp
        cases bs with
        | nil => exact Forall₂.cons (hRefl a) (forall₂_replaceInOrder E hRefl hE as [])
        | cons b bs => exact Forall₂.cons (hE a b hp) (forall₂_replaceInOrder E hRefl hE as bs)
      · exact Forall₂.cons (hRefl a) (forall₂_replaceInOrder E hRefl hE as bs)

/-! ## Strings the trace uses -/

theorem startsWith_append_self (a b : String) : (a ++ b).startsWith a = true := by
  simp

theorem bucketLabel_isBucket (object : String) (index : Nat) :
    isPathOramBucketLabel (pathOramBucketLabelOfIndex object index) = true := by
  unfold isPathOramBucketLabel pathOramBucketLabelOfIndex
  have hEq : s!"{object}@bucket{index}" = (object ++ "@bucket") ++ toString index := by
    simp only [String.append_assoc]; rfl
  simp only [hEq]
  exact startsWith_append_self _ _

theorem bucketDetail_startsWith (index : Nat) : (s!"bucket:{index}").startsWith "bucket:" = true := by
  have hEq : s!"bucket:{index}" = "bucket:" ++ toString index := rfl
  rw [hEq]
  exact startsWith_append_self _ _

theorem not_startsWith_page_of_bucket {s : String} (h : s.startsWith "bucket:" = true) :
    s.startsWith "page:" = false := by
  rw [String.startsWith_string_iff] at h
  rw [String.startsWith_string_eq_false_iff]
  intro hPage
  obtain ⟨t₁, h₁⟩ := h
  obtain ⟨t₂, h₂⟩ := hPage
  have hHead := congrArg List.head? (h₁.trans h₂.symm)
  simp at hHead

theorem ne_counter_of_bucket {s : String} (h : s.startsWith "bucket:" = true) : s ≠ "counter" := by
  intro hEq
  subst hEq
  simp at h

/-- A projection that every replacement leaves unchanged is unchanged on the
whole list. -/
theorem map_replaceInOrder_of_forall {α β γ : Type} {p : α → Bool} {f : α → β → α} {g : α → γ}
    (hg : ∀ a b, p a = true → g (f a b) = g a) :
    ∀ (as : List α) (bs : List β), (replaceInOrder p f as bs).map g = as.map g
  | [], _ => rfl
  | a :: as, bs => by
      unfold replaceInOrder
      split
      · rename_i hp
        cases bs with
        | nil => simp only [List.map_cons, map_replaceInOrder_of_forall hg as []]
        | cons b bs => simp only [List.map_cons, hg a b hp, map_replaceInOrder_of_forall hg as bs]
      · simp only [List.map_cons, map_replaceInOrder_of_forall hg as bs]

theorem Forall₂.length_eq {α β : Type} {R : α → β → Prop} :
    ∀ {as : List α} {bs : List β}, Forall₂ R as bs → as.length = bs.length
  | _, _, .nil => rfl
  | _, _, .cons _ h => by simp [Forall₂.length_eq h]

theorem Forall₂.append {α β : Type} {R : α → β → Prop} :
    ∀ {as₁ : List α} {bs₁ : List β} {as₂ : List α} {bs₂ : List β},
      Forall₂ R as₁ bs₁ → Forall₂ R as₂ bs₂ → Forall₂ R (as₁ ++ as₂) (bs₁ ++ bs₂)
  | _, _, _, _, .nil, h₂ => h₂
  | _, _, _, _, .cons hab h₁, h₂ => .cons hab (Forall₂.append h₁ h₂)

theorem Forall₂.imp {α β : Type} {R S : α → β → Prop} (hRS : ∀ a b, R a b → S a b) :
    ∀ {as : List α} {bs : List β}, Forall₂ R as bs → Forall₂ S as bs
  | _, _, .nil => .nil
  | _, _, .cons hab h => .cons (hRS _ _ hab) (Forall₂.imp hRS h)

theorem Forall₂.of_map_left {α α' β : Type} {R : α' → β → Prop} (g : α → α') :
    ∀ {as : List α} {bs : List β}, Forall₂ R (as.map g) bs → Forall₂ (fun a b => R (g a) b) as bs
  | [], [], _ => .nil
  | [], _ :: _, h => by cases h
  | _ :: _, [], h => by cases h
  | _ :: _, _ :: _, h => by
      cases h with
      | cons hab hrest => exact .cons hab (Forall₂.of_map_left g hrest)

theorem Forall₂.of_map_map {α β γ δ : Type} {R : γ → δ → Prop} (f : α → γ) (g : β → δ)
    (hR : ∀ a b, R (f a) (g b)) :
    ∀ {as : List α} {bs : List β}, as.length = bs.length → Forall₂ R (as.map f) (bs.map g)
  | [], [], _ => .nil
  | [], _ :: _, h => by cases h
  | _ :: _, [], h => by cases h
  | _ :: _, _ :: _, h => .cons (hR _ _) (Forall₂.of_map_map f g hR (by simpa using h))

/-! ## Substituting bucket locations into a trace -/

/-- A logical path read of a Path ORAM bucket. -/
def isPathReadEvent (event : LogicalEvent) : Bool :=
  event.kind == "uooram_path_read" && event.detail.startsWith "bucket:"

def isBucketRead (event : PhysicalRead) : Bool :=
  isPathOramBucketLabel (pathOramPhysicalReadLabel event)

def isBucketWrite (event : PhysicalWrite) : Bool :=
  isPathOramBucketLabel (pathOramPhysicalWriteLabel event)

/-- The details of the logical path reads of a leaf schedule, in order. -/
def readDetails (schedule : PathOramLeafScheduleTrace) : List String :=
  schedule.flatMap fun step =>
    (pathOramBucketIndicesOfLeafStep step).map fun index => s!"bucket:{index}"

/-- A trace with its bucket reads and writes moved to the paths of
`schedule`'s leaves, in order. -/
def substituteTrace (trace : Trace) (schedule : PathOramLeafScheduleTrace) : Trace :=
  { trace with
    logicalAccesses :=
      replaceInOrder isPathReadEvent (fun event detail => { event with detail := detail })
        trace.logicalAccesses (readDetails schedule)
    physicalReads :=
      replaceInOrder isBucketRead
        (fun event (label : PathOramPhysicalEventLabel) => { event with location := label.location })
        trace.physicalReads (pathOramBucketTraceOfLeafScheduleTrace schedule).readBuckets
    physicalWrites :=
      replaceInOrder isBucketWrite
        (fun event (label : PathOramPhysicalEventLabel) => { event with location := label.location })
        trace.physicalWrites (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets }

theorem pathOramNormalizeLogicalEvent_detail {event : LogicalEvent} (h : isPathReadEvent event = true)
    (detail : String) :
    pathOramNormalizeLogicalEvent { event with detail := detail } =
      pathOramNormalizeLogicalEvent event := by
  have hKind : event.kind = "uooram_path_read" := by
    simp only [isPathReadEvent, Bool.and_eq_true, beq_iff_eq] at h
    exact h.1
  obtain ⟨kind, object, detail₀⟩ := event
  simp only at hKind
  subst hKind
  rfl

/-- The substitution does not change the public view. -/
theorem pathOramViewPublicPart_substituteTrace (trace : Trace) (schedule : PathOramLeafScheduleTrace) :
    pathOramViewPublicPart (viewMPlus (substituteTrace trace schedule)) =
      pathOramViewPublicPart (viewMPlus trace) := by
  have hMap :=
    map_replaceInOrder_of_forall (g := pathOramNormalizeLogicalEvent)
      (fun event detail h => pathOramNormalizeLogicalEvent_detail h detail)
      trace.logicalAccesses (readDetails schedule)
  simp only [pathOramViewPublicPart, oramViewPublicPart, viewMPlus, pathOramNormalizePublicPart,
    pathOramNormalizeLogicalAccesses, substituteTrace, hMap]

/-- The substitution does not change the storage shape. -/
theorem pathOramStorageShape_substituteTrace (trace : Trace) (schedule : PathOramLeafScheduleTrace) :
    pathOramStorageShape (oramStorageView (viewMPlus (substituteTrace trace schedule))) =
      pathOramStorageShape (oramStorageView (viewMPlus trace)) := by
  have hReads :=
    map_replaceInOrder_of_forall (g := PhysicalRead.len)
      (p := isBucketRead) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun _ _ _ => rfl) trace.physicalReads
      (pathOramBucketTraceOfLeafScheduleTrace schedule).readBuckets
  have hClasses :=
    map_replaceInOrder_of_forall (g := PhysicalWrite.writeClass)
      (p := isBucketWrite) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun _ _ _ => rfl) trace.physicalWrites
      (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets
  have hLengths :=
    map_replaceInOrder_of_forall (g := PhysicalWrite.len)
      (p := isBucketWrite) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun _ _ _ => rfl) trace.physicalWrites
      (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets
  simp only [pathOramStorageShape, oramStorageView, viewMPlus, substituteTrace, hReads, hClasses,
    hLengths]

/-- A bucket event and the label it moves to: same object, and the label is a
bucket location. -/
def MovesTo (object : String) (label : PathOramPhysicalEventLabel) : Prop :=
  object = label.object ∧ isPathOramBucketLabel label = true

theorem normalize_moved {object location : String} {label : PathOramPhysicalEventLabel}
    (hBucket : isPathOramBucketLabel { object := object, location := location } = true)
    (hMoves : MovesTo object label) :
    pathOramNormalizeLocationLabel { object := object, location := label.location } =
      pathOramNormalizeLocationLabel { object := object, location := location } := by
  obtain ⟨hObject, hLabel⟩ := hMoves
  have hNew : isPathOramBucketLabel { object := object, location := label.location } = true := by
    obtain ⟨labelObject, labelLocation⟩ := label
    simp only at hObject
    subst hObject
    exact hLabel
  simp only [pathOramNormalizeLocationLabel, hNew, hBucket, if_true]

/-- With the bucket events moved to labels of the same objects, the
substitution does not change the public locations. -/
theorem pathOramPublicLocationTrace_substituteTrace (trace : Trace)
    (schedule : PathOramLeafScheduleTrace)
    (hReads :
      Forall₂ (fun event label => MovesTo (PhysicalRead.object event) label)
        (trace.physicalReads.filter isBucketRead)
        (pathOramBucketTraceOfLeafScheduleTrace schedule).readBuckets)
    (hWrites :
      Forall₂ (fun event label => MovesTo (PhysicalWrite.object event) label)
        (trace.physicalWrites.filter isBucketWrite)
        (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets) :
    pathOramPublicLocationTrace
        (pathOramStorageLocationTrace (oramStorageView (viewMPlus (substituteTrace trace schedule)))) =
      pathOramPublicLocationTrace
        (pathOramStorageLocationTrace (oramStorageView (viewMPlus trace))) := by
  have hReadMap :=
    map_replaceInOrder (g := fun event => pathOramNormalizeLocationLabel (pathOramPhysicalReadLabel event))
      (p := isBucketRead) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun event label => MovesTo (PhysicalRead.object event) label)
      (fun event label hp hMoves => normalize_moved hp hMoves)
      trace.physicalReads _ hReads
  have hWriteMap :=
    map_replaceInOrder (g := fun event => pathOramNormalizeLocationLabel (pathOramPhysicalWriteLabel event))
      (p := isBucketWrite) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun event label => MovesTo (PhysicalWrite.object event) label)
      (fun event label hp hMoves => normalize_moved hp hMoves)
      trace.physicalWrites _ hWrites
  simp only [pathOramPublicLocationTrace, pathOramStorageLocationTrace, oramStorageView, viewMPlus,
    substituteTrace, List.map_map, Function.comp_def, pathOramPhysicalReadLabel,
    pathOramPhysicalWriteLabel] at hReadMap hWriteMap ⊢
  rw [hReadMap, hWriteMap]

theorem map_label_zipWith_read :
    ∀ {events : List PhysicalRead} {labels : List PathOramPhysicalEventLabel},
      Forall₂ (fun event label => MovesTo (PhysicalRead.object event) label) events labels →
      (List.zipWith (fun event (label : PathOramPhysicalEventLabel) =>
          { event with location := label.location }) events labels).map pathOramPhysicalReadLabel =
        labels
  | _, _, .nil => rfl
  | _, _, .cons hMoves hrest => by
      rename_i event label events labels
      obtain ⟨hObject, _⟩ := hMoves
      simp only [List.zipWith_cons_cons, List.map_cons, map_label_zipWith_read hrest]
      obtain ⟨labelObject, labelLocation⟩ := label
      simp only at hObject
      simp [pathOramPhysicalReadLabel, hObject]

theorem map_label_zipWith_write :
    ∀ {events : List PhysicalWrite} {labels : List PathOramPhysicalEventLabel},
      Forall₂ (fun event label => MovesTo (PhysicalWrite.object event) label) events labels →
      (List.zipWith (fun event (label : PathOramPhysicalEventLabel) =>
          { event with location := label.location }) events labels).map pathOramPhysicalWriteLabel =
        labels
  | _, _, .nil => rfl
  | _, _, .cons hMoves hrest => by
      rename_i event label events labels
      obtain ⟨hObject, _⟩ := hMoves
      simp only [List.zipWith_cons_cons, List.map_cons, map_label_zipWith_write hrest]
      obtain ⟨labelObject, labelLocation⟩ := label
      simp only at hObject
      simp [pathOramPhysicalWriteLabel, hObject]

/-- **The substituted trace reads and writes the paths of the new leaves.** -/
theorem bucketTrace_substituteTrace (trace : Trace) (schedule : PathOramLeafScheduleTrace)
    (hReads :
      Forall₂ (fun event label => MovesTo (PhysicalRead.object event) label)
        (trace.physicalReads.filter isBucketRead)
        (pathOramBucketTraceOfLeafScheduleTrace schedule).readBuckets)
    (hWrites :
      Forall₂ (fun event label => MovesTo (PhysicalWrite.object event) label)
        (trace.physicalWrites.filter isBucketWrite)
        (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets) :
    pathOramBucketTraceOfView (viewMPlus (substituteTrace trace schedule)) =
      pathOramBucketTraceOfLeafScheduleTrace schedule := by
  have hReadFilter :=
    filter_replaceInOrder (p := isBucketRead) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun event label => MovesTo (PhysicalRead.object event) label)
      (fun event label _ hMoves => by
        obtain ⟨hObject, hLabel⟩ := hMoves
        obtain ⟨labelObject, labelLocation⟩ := label
        simp only at hObject
        subst hObject
        exact hLabel)
      trace.physicalReads _ hReads
  have hWriteFilter :=
    filter_replaceInOrder (p := isBucketWrite) (f := fun event (label : PathOramPhysicalEventLabel) =>
        { event with location := label.location })
      (fun event label => MovesTo (PhysicalWrite.object event) label)
      (fun event label _ hMoves => by
        obtain ⟨hObject, hLabel⟩ := hMoves
        obtain ⟨labelObject, labelLocation⟩ := label
        simp only at hObject
        subst hObject
        exact hLabel)
      trace.physicalWrites _ hWrites
  have hReadLabels :
      ((replaceInOrder isBucketRead
          (fun event (label : PathOramPhysicalEventLabel) => { event with location := label.location })
          trace.physicalReads (pathOramBucketTraceOfLeafScheduleTrace schedule).readBuckets).map
          pathOramPhysicalReadLabel).filter isPathOramBucketLabel =
        (pathOramBucketTraceOfLeafScheduleTrace schedule).readBuckets := by
    rw [List.filter_map]
    have hComp : (isPathOramBucketLabel ∘ pathOramPhysicalReadLabel) = isBucketRead := rfl
    rw [hComp, hReadFilter]
    exact map_label_zipWith_read hReads
  have hWriteLabels :
      ((replaceInOrder isBucketWrite
          (fun event (label : PathOramPhysicalEventLabel) => { event with location := label.location })
          trace.physicalWrites (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets).map
          pathOramPhysicalWriteLabel).filter isPathOramBucketLabel =
        (pathOramBucketTraceOfLeafScheduleTrace schedule).writeBuckets := by
    rw [List.filter_map]
    have hComp : (isPathOramBucketLabel ∘ pathOramPhysicalWriteLabel) = isBucketWrite := rfl
    rw [hComp, hWriteFilter]
    exact map_label_zipWith_write hWrites
  simp only [pathOramBucketTraceOfView, pathOramBucketTrace, pathOramStorageLocationTrace,
    oramStorageView, viewMPlus, substituteTrace]
  rw [hReadLabels, hWriteLabels]

/-! ## Moving a schedule's leaves keeps its bucket labels aligned -/

/-- A step moved to another leaf: same map, same path length. -/
def SameShape (old new : PathOramLeafScheduleStep) : Prop :=
  old.object = new.object ∧
    (pathOramBucketIndicesOfLeafStep old).length = (pathOramBucketIndicesOfLeafStep new).length

theorem concat_forall₂ {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List (List α)} {ys : List (List β)}, Forall₂ (Forall₂ R) xs ys →
      Forall₂ R (xs.foldr (· ++ ·) []) (ys.foldr (· ++ ·) [])
  | _, _, .nil => .nil
  | _, _, .cons h hrest => Forall₂.append h (concat_forall₂ hrest)

theorem concatLabels_eq_foldr (xs : List (List PathOramPhysicalEventLabel)) :
    concatPathOramPhysicalEventLabels xs = xs.foldr (· ++ ·) [] := by
  induction xs with
  | nil => rfl
  | cons x xs ih => simp [concatPathOramPhysicalEventLabels, ih]

theorem Forall₂.map_both {α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop} (f : α → γ)
    (g : β → δ) (h : ∀ a b, R a b → S (f a) (g b)) :
    ∀ {as : List α} {bs : List β}, Forall₂ R as bs → Forall₂ S (as.map f) (bs.map g)
  | _, _, .nil => .nil
  | _, _, .cons hab hrest => .cons (h _ _ hab) (Forall₂.map_both f g h hrest)

theorem readBuckets_parallel {old new : PathOramLeafScheduleTrace} (h : Forall₂ SameShape old new) :
    Forall₂ (fun (x y : PathOramPhysicalEventLabel) => MovesTo x.object y)
      (pathOramBucketTraceOfLeafScheduleTrace old).readBuckets
      (pathOramBucketTraceOfLeafScheduleTrace new).readBuckets := by
  simp only [pathOramBucketTraceOfLeafScheduleTrace, concatLabels_eq_foldr]
  apply concat_forall₂
  refine Forall₂.map_both _ _ ?_ h
  intro a b hab
  obtain ⟨hObject, hLength⟩ := hab
  apply Forall₂.of_map_map
  · intro i j
    exact ⟨hObject, bucketLabel_isBucket _ _⟩
  · exact hLength

theorem writeBuckets_parallel {old new : PathOramLeafScheduleTrace} (h : Forall₂ SameShape old new) :
    Forall₂ (fun (x y : PathOramPhysicalEventLabel) => MovesTo x.object y)
      (pathOramBucketTraceOfLeafScheduleTrace old).writeBuckets
      (pathOramBucketTraceOfLeafScheduleTrace new).writeBuckets := by
  simp only [pathOramBucketTraceOfLeafScheduleTrace, concatLabels_eq_foldr]
  apply concat_forall₂
  refine Forall₂.map_both _ _ ?_ h
  intro a b hab
  obtain ⟨hObject, hLength⟩ := hab
  simp only [pathOramWriteBucketLabelsOfLeafStep]
  apply Forall₂.of_map_map
  · intro i j
    exact ⟨hObject, bucketLabel_isBucket _ _⟩
  · simpa using hLength

/-- Every leaf of a tree with `bucketCount` buckets is at the same depth. -/
def UniformDepth (bucketCount : Nat) : Prop :=
  ∀ (object : String) (leaf : Nat),
    (pathOramBucketIndicesOfLeafStep ⟨object, bucketCount, leaf⟩).length =
      (pathOramBucketIndicesOfLeafStep ⟨"", bucketCount, 0⟩).length

def uniformDepthCheck (bucketCount : Nat) : Bool :=
  (List.range (max (pathOramLeafCount bucketCount) 1)).all fun leaf =>
    (pathOramBucketIndicesOfLeafStep ⟨"", bucketCount, leaf⟩).length ==
      (pathOramBucketIndicesOfLeafStep ⟨"", bucketCount, 0⟩).length

theorem bucketIndices_mod (object : String) (bucketCount leaf : Nat) :
    pathOramBucketIndicesOfLeafStep ⟨object, bucketCount, leaf⟩ =
      pathOramBucketIndicesOfLeafStep ⟨"", bucketCount, leaf % max (pathOramLeafCount bucketCount) 1⟩ := by
  simp [pathOramBucketIndicesOfLeafStep]

theorem uniformDepth_of_check {bucketCount : Nat} (h : uniformDepthCheck bucketCount = true) :
    UniformDepth bucketCount := by
  intro object leaf
  rw [bucketIndices_mod]
  have hPos : 0 < max (pathOramLeafCount bucketCount) 1 := by omega
  have hMem : leaf % max (pathOramLeafCount bucketCount) 1 ∈
      List.range (max (pathOramLeafCount bucketCount) 1) :=
    List.mem_range.mpr (Nat.mod_lt _ hPos)
  have := (List.all_eq_true.mp h) _ hMem
  simpa using this

theorem sameShape_withLeaf {step : PathOramLeafScheduleStep} (hDepth : UniformDepth step.bucketCount)
    (leaf : Nat) : SameShape step { step with leaf := leaf } := by
  refine ⟨rfl, ?_⟩
  obtain ⟨object, bucketCount, leaf₀⟩ := step
  rw [hDepth object leaf₀, hDepth object leaf]

/-! ## The ORAM logical-trace checks ignore bucket details -/

/-- What the ORAM logical-trace checks read of an event. -/
def logicalShape (event : LogicalEvent) : String × String × Bool × Bool × Bool :=
  (event.kind, event.object, event.detail == "counter", event.detail.startsWith "page:",
    event.detail.startsWith "bucket:")

theorem consume_logicalShape {pre : String} (hPre : pre = "page:" ∨ pre = "bucket:")
    (object kind : String) :
    ∀ (count : Nat) (events events' : List LogicalEvent),
      events.map logicalShape = events'.map logicalShape →
      (consumeExpectedOramLogicalEvents events object kind count pre).map (List.map logicalShape) =
        (consumeExpectedOramLogicalEvents events' object kind count pre).map (List.map logicalShape)
  | 0, events, events', h => by simp [consumeExpectedOramLogicalEvents, h]
  | count + 1, [], [], _ => rfl
  | count + 1, [], _ :: _, h => by simp at h
  | count + 1, _ :: _, [], h => by simp at h
  | count + 1, event :: events, event' :: events', h => by
      simp only [List.map_cons, List.cons.injEq] at h
      obtain ⟨hShape, hRest⟩ := h
      simp only [logicalShape, Prod.mk.injEq] at hShape
      obtain ⟨hKind, hObject, _, hPage, hBucket⟩ := hShape
      have hPrefix : event.detail.startsWith pre = event'.detail.startsWith pre := by
        rcases hPre with rfl | rfl
        · exact hPage
        · exact hBucket
      simp only [consumeExpectedOramLogicalEvents, hKind, hObject, hPrefix]
      split
      · exact consume_logicalShape hPre object kind count events events' hRest
      · rfl

theorem reconstructObserved_logicalShape (objects : List RuntimeOramObjectCertificate) :
    ∀ (fuel : Nat) (events events' : List LogicalEvent),
      events.map logicalShape = events'.map logicalShape →
      reconstructObservedOramAccessesFromLogicalTraceAux fuel events objects =
        reconstructObservedOramAccessesFromLogicalTraceAux fuel events' objects
  | 0, [], [], _ => rfl
  | 0, [], _ :: _, h => by simp at h
  | 0, _ :: _, [], h => by simp at h
  | 0, _ :: _, _ :: _, _ => rfl
  | _ + 1, [], [], _ => rfl
  | _ + 1, [], _ :: _, h => by simp at h
  | _ + 1, _ :: _, [], h => by simp at h
  | fuel + 1, event :: events, event' :: events', h => by
      simp only [List.map_cons, List.cons.injEq] at h
      obtain ⟨hShape, hRest⟩ := h
      simp only [logicalShape, Prod.mk.injEq] at hShape
      obtain ⟨hKind, hObject, hCounter, _, _⟩ := hShape
      have hCounter' : (event.detail != "counter") = (event'.detail != "counter") := by
        simp only [bne, hCounter]
      simp only [reconstructObservedOramAccessesFromLogicalTraceAux, hKind, hObject, hCounter']
      split
      · exact reconstructObserved_logicalShape objects fuel events events' hRest
      · split
        · rfl
        · cases hByName : runtimeOramObjectByName? objects event'.object with
          | none => rfl
          | some object =>
              simp only [Option.bind_eq_bind, Option.bind_some]
              cases hMeta : object.metadataEventKind? with
              | none => rfl
              | some metadataKind =>
                  cases hBucketKind : object.bucketEventKind? with
                  | none => rfl
                  | some bucketKind =>
                      simp only [Option.bind_some]
                      have hPages := consume_logicalShape (Or.inl rfl) event'.object metadataKind
                        object.metadataPages events events' hRest
                      cases hc : consumeExpectedOramLogicalEvents events event'.object metadataKind
                          object.metadataPages "page:" with
                      | none =>
                          cases hc' : consumeExpectedOramLogicalEvents events' event'.object
                              metadataKind object.metadataPages "page:" with
                          | none => rfl
                          | some r' => simp [hc, hc'] at hPages
                      | some r =>
                          cases hc' : consumeExpectedOramLogicalEvents events' event'.object
                              metadataKind object.metadataPages "page:" with
                          | none => simp [hc, hc'] at hPages
                          | some r' =>
                              simp only [hc, hc', Option.map_some, Option.some.injEq] at hPages
                              simp only [Option.bind_some]
                              have hBuckets := consume_logicalShape (Or.inr rfl) event'.object
                                bucketKind object.bucketsPerAccess r r' hPages
                              cases hb : consumeExpectedOramLogicalEvents r event'.object bucketKind
                                  object.bucketsPerAccess "bucket:" with
                              | none =>
                                  cases hb' : consumeExpectedOramLogicalEvents r' event'.object
                                      bucketKind object.bucketsPerAccess "bucket:" with
                                  | none => rfl
                                  | some q' => simp [hb, hb'] at hBuckets
                              | some q =>
                                  cases hb' : consumeExpectedOramLogicalEvents r' event'.object
                                      bucketKind object.bucketsPerAccess "bucket:" with
                                  | none => simp [hb, hb'] at hBuckets
                                  | some q' =>
                                      simp only [hb, hb', Option.map_some, Option.some.injEq] at hBuckets
                                      simp only [Option.bind_some]
                                      rw [reconstructObserved_logicalShape objects fuel q q' hBuckets]

theorem reconstructScaffold_logicalShape (objects : List RuntimeOramObjectCertificate) :
    ∀ (fuel : Nat) (events events' : List LogicalEvent),
      events.map logicalShape = events'.map logicalShape →
      reconstructPathOramLeafScaffoldFromLogicalTraceAux fuel events objects =
        reconstructPathOramLeafScaffoldFromLogicalTraceAux fuel events' objects
  | 0, [], [], _ => rfl
  | 0, [], _ :: _, h => by simp at h
  | 0, _ :: _, [], h => by simp at h
  | 0, _ :: _, _ :: _, _ => rfl
  | _ + 1, [], [], _ => rfl
  | _ + 1, [], _ :: _, h => by simp at h
  | _ + 1, _ :: _, [], h => by simp at h
  | fuel + 1, event :: events, event' :: events', h => by
      simp only [List.map_cons, List.cons.injEq] at h
      obtain ⟨hShape, hRest⟩ := h
      simp only [logicalShape, Prod.mk.injEq] at hShape
      obtain ⟨hKind, hObject, hCounter, _, _⟩ := hShape
      have hCounter' : (event.detail != "counter") = (event'.detail != "counter") := by
        simp only [bne, hCounter]
      simp only [reconstructPathOramLeafScaffoldFromLogicalTraceAux, hKind, hObject, hCounter']
      split
      · exact reconstructScaffold_logicalShape objects fuel events events' hRest
      · split
        · rfl
        · cases hByName : runtimeOramObjectByName? objects event'.object with
          | none => rfl
          | some object =>
              simp only [Option.bind_eq_bind, Option.bind_some]
              cases hMeta : object.metadataEventKind? with
              | none => rfl
              | some metadataKind =>
                  cases hBucketKind : object.bucketEventKind? with
                  | none => rfl
                  | some bucketKind =>
                      simp only [Option.bind_some]
                      have hPages := consume_logicalShape (Or.inl rfl) event'.object metadataKind
                        object.metadataPages events events' hRest
                      cases hc : consumeExpectedOramLogicalEvents events event'.object metadataKind
                          object.metadataPages "page:" with
                      | none =>
                          cases hc' : consumeExpectedOramLogicalEvents events' event'.object
                              metadataKind object.metadataPages "page:" with
                          | none => rfl
                          | some r' => simp [hc, hc'] at hPages
                      | some r =>
                          cases hc' : consumeExpectedOramLogicalEvents events' event'.object
                              metadataKind object.metadataPages "page:" with
                          | none => simp [hc, hc'] at hPages
                          | some r' =>
                              simp only [hc, hc', Option.map_some, Option.some.injEq] at hPages
                              simp only [Option.bind_some]
                              have hBuckets := consume_logicalShape (Or.inr rfl) event'.object
                                bucketKind object.bucketsPerAccess r r' hPages
                              cases hb : consumeExpectedOramLogicalEvents r event'.object bucketKind
                                  object.bucketsPerAccess "bucket:" with
                              | none =>
                                  cases hb' : consumeExpectedOramLogicalEvents r' event'.object
                                      bucketKind object.bucketsPerAccess "bucket:" with
                                  | none => rfl
                                  | some q' => simp [hb, hb'] at hBuckets
                              | some q =>
                                  cases hb' : consumeExpectedOramLogicalEvents r' event'.object
                                      bucketKind object.bucketsPerAccess "bucket:" with
                                  | none => simp [hb, hb'] at hBuckets
                                  | some q' =>
                                      simp only [hb, hb', Option.map_some, Option.some.injEq] at hBuckets
                                      simp only [Option.bind_some]
                                      rw [reconstructScaffold_logicalShape objects fuel q q' hBuckets]

/-- Substituting path-read details keeps what the logical checks read, when the
new details are bucket details. -/
theorem logicalShape_substitute (events : List LogicalEvent) (details : List String)
    (hDetails : ∀ detail ∈ details, detail.startsWith "bucket:" = true) :
    (replaceInOrder isPathReadEvent (fun event detail => { event with detail := detail })
        events details).map logicalShape = events.map logicalShape := by
  induction events generalizing details with
  | nil => rfl
  | cons event events ih =>
      unfold replaceInOrder
      split
      · rename_i hp
        cases details with
        | nil => simp only [List.map_cons, ih [] (by simp)]
        | cons detail details =>
            have hOld : event.detail.startsWith "bucket:" = true := by
              simp only [isPathReadEvent, Bool.and_eq_true] at hp
              exact hp.2
            have hNew := hDetails detail List.mem_cons_self
            simp only [List.map_cons, ih details (fun d hd => hDetails d (List.mem_cons_of_mem _ hd))]
            congr 1
            simp only [logicalShape, hOld, hNew, not_startsWith_page_of_bucket hOld,
              not_startsWith_page_of_bucket hNew]
            have h₁ : (detail == "counter") = false := by
              simpa using ne_counter_of_bucket hNew
            have h₂ : (event.detail == "counter") = false := by
              simpa using ne_counter_of_bucket hOld
            rw [h₁, h₂]
      · simp only [List.map_cons, ih details hDetails]

theorem readDetails_bucket (schedule : PathOramLeafScheduleTrace) :
    ∀ detail ∈ readDetails schedule, detail.startsWith "bucket:" = true := by
  intro detail h
  simp only [readDetails, List.mem_flatMap, List.mem_map] at h
  obtain ⟨_, _, index, _, rfl⟩ := h
  exact bucketDetail_startsWith index

/-! ## Replaying the model's leaves through the runtime's transitions -/

/-- Two lists of slots with the same occupied slots. -/
def SameSlots (leaves leaves' : List (Option Nat)) : Prop :=
  Forall₂ (fun (x y : Option Nat) => x.isSome = y.isSome) leaves leaves'

/-- Two position-map states with the same maps and the same occupied slots. -/
def SameSupport (state state' : RuntimePathOramPositionMapState) : Prop :=
  Forall₂ (fun (e e' : Nat × List (Option Nat)) => e.1 = e'.1 ∧ SameSlots e.2 e'.2) state state'

/-- The bucket count of a map, `0` for an unknown map. -/
def objectBucketCount (objects : List RuntimeOramObjectCertificate) (objectId : Nat) : Nat :=
  ((runtimeOramObjectById? objects objectId).map (·.bucketCount)).getD 0

/-- The name of a map, empty for an unknown map. -/
def objectNameOf (objects : List RuntimeOramObjectCertificate) (objectId : Nat) : String :=
  ((runtimeOramObjectById? objects objectId).map (·.objectName)).getD ""

/-- The leaf count of a map, the bound of its leaves and coins. -/
def leafBound (objects : List RuntimeOramObjectCertificate) (objectId : Nat) : Nat :=
  pathOramLeafChoiceCount (objectBucketCount objects objectId)

/-- Every leaf of a state is below its map's leaf count. -/
def Bounded (objects : List RuntimeOramObjectCertificate) (state : RuntimePathOramPositionMapState) :
    Prop :=
  ∀ key v, stateLeafMap state key = some v → v < leafBound objects key.1

/-- Each access's two coins are below its map's leaf count. -/
def CoinsOk (objects : List RuntimeOramObjectCertificate) :
    List RuntimeOramLeafCertificate → List Nat → Prop
  | [], _ => True
  | leaf :: leafs, coins =>
      coins.getD 0 0 < leafBound objects leaf.objectId ∧
        coins.getD 1 0 < leafBound objects leaf.objectId ∧
        CoinsOk objects leafs (coins.drop 2)

/-- The runtime's certificates with the model's leaves: each access reads the
leaf the model reads on `coins`, and takes the model's next leaf. -/
def substSteps (leaves : Nat × Nat → Option Nat) :
    List RuntimeOramLeafCertificate → List RuntimePathOramTransitionCertificate → List Nat →
      List RuntimeOramLeafCertificate × List RuntimePathOramTransitionCertificate
  | leaf :: leafs, transition :: transitions, coins =>
      let r := stepLeaves (coins.getD 0 0) (coins.getD 1 0) leaves
        (liftStep leaf.objectId (LeafStep.ofTransition transition))
      let rest := substSteps r.2 leafs transitions (coins.drop 2)
      ({ leaf with leaf := r.1 } :: rest.1,
        { transition with
          priorLeaf := transition.priorLeaf.map fun _ => r.1
          nextLeaf := transition.nextLeaf.map fun _ => coins.getD 1 0 } :: rest.2)
  | _, _, _ => ([], [])

/-- The substituted leaves are the model's observed leaves. -/
theorem substSteps_leaves (leaves : Nat × Nat → Option Nat) :
    ∀ (leafs : List RuntimeOramLeafCertificate) (transitions : List RuntimePathOramTransitionCertificate)
      (coins : List Nat),
      (substSteps leaves leafs transitions coins).1.map (·.leaf) =
        (runLeaves leaves (liftSteps (transitionAccesses leafs transitions)) coins).1
  | [], _, _ => rfl
  | _ :: _, [], _ => rfl
  | leaf :: leafs, transition :: transitions, coins => by
      simp only [substSteps, transitionAccesses, liftSteps, List.map_cons, runLeaves]
      rw [substSteps_leaves _ leafs transitions (coins.drop 2)]
      rfl

theorem substSteps_scaffold (leaves : Nat × Nat → Option Nat) :
    ∀ (leafs : List RuntimeOramLeafCertificate) (transitions : List RuntimePathOramTransitionCertificate)
      (coins : List Nat), leafs.length = transitions.length →
      (substSteps leaves leafs transitions coins).1.map RuntimeOramLeafCertificate.scaffoldStep =
        leafs.map RuntimeOramLeafCertificate.scaffoldStep
  | [], [], _, _ => rfl
  | [], _ :: _, _, h => by simp at h
  | _ :: _, [], _, h => by simp at h
  | leaf :: leafs, transition :: transitions, coins, h => by
      simp only [substSteps, List.map_cons]
      rw [substSteps_scaffold _ leafs transitions (coins.drop 2) (by simpa using h)]
      rfl

theorem substSteps_shapes (leaves : Nat × Nat → Option Nat) :
    ∀ (leafs : List RuntimeOramLeafCertificate) (transitions : List RuntimePathOramTransitionCertificate)
      (coins : List Nat), leafs.length = transitions.length →
      (substSteps leaves leafs transitions coins).2.map RuntimePathOramTransitionCertificate.shape =
        transitions.map RuntimePathOramTransitionCertificate.shape
  | [], [], _, _ => rfl
  | [], _ :: _, _, h => by simp at h
  | _ :: _, [], _, h => by simp at h
  | leaf :: leafs, transition :: transitions, coins, h => by
      simp only [substSteps, List.map_cons]
      rw [substSteps_shapes _ leafs transitions (coins.drop 2) (by simpa using h)]
      rfl

theorem substSteps_accesses (leaves : Nat × Nat → Option Nat) :
    ∀ (leafs : List RuntimeOramLeafCertificate) (transitions : List RuntimePathOramTransitionCertificate)
      (coins : List Nat),
      transitionAccesses (substSteps leaves leafs transitions coins).1
          (substSteps leaves leafs transitions coins).2 =
        transitionAccesses leafs transitions
  | [], _, _ => rfl
  | _ :: _, [], _ => rfl
  | leaf :: leafs, transition :: transitions, coins => by
      simp only [substSteps, transitionAccesses]
      rw [substSteps_accesses _ leafs transitions (coins.drop 2)]
      rfl

/-! ### Position-map states with the same support -/

theorem lookup_sameSupport {state state' : RuntimePathOramPositionMapState} (h : SameSupport state state')
    {objectId : Nat} {leaves : List (Option Nat)}
    (hLookup : runtimePathOramStateLookup? state objectId = some leaves) :
    ∃ leaves', runtimePathOramStateLookup? state' objectId = some leaves' ∧ SameSlots leaves leaves' := by
  induction h with
  | nil => simp [runtimePathOramStateLookup?] at hLookup
  | @cons e e' es es' hEntry _ ih =>
      obtain ⟨hId, hSlots⟩ := hEntry
      obtain ⟨id, l⟩ := e
      obtain ⟨id', l'⟩ := e'
      simp only at hId hSlots
      subst hId
      by_cases hEq : id = objectId
      · subst hEq
        simp only [runtimePathOramStateLookup?, List.find?_cons, decide_true] at hLookup ⊢
        cases hLookup
        exact ⟨l', rfl, hSlots⟩
      · simp only [runtimePathOramStateLookup?, List.find?_cons, hEq, decide_false] at hLookup ⊢
        exact ih hLookup

theorem getElem?_sameSlots {leaves leaves' : List (Option Nat)} (h : SameSlots leaves leaves') :
    ∀ (slot : Nat), (leaves[slot]?).map Option.isSome = (leaves'[slot]?).map Option.isSome := by
  induction h with
  | nil => intro slot; rfl
  | @cons x y xs ys hxy _ ih =>
      intro slot
      cases slot with
      | zero => simp [hxy]
      | succ slot => simpa using ih slot

theorem setLeafAt?_sameSlots {leaves leaves' : List (Option Nat)} (h : SameSlots leaves leaves')
    {slot : Nat} {value value' : Option Nat} (hValue : value.isSome = value'.isSome)
    {updated : List (Option Nat)}
    (hSet : runtimePathOramSetLeafAt? leaves slot value = some updated) :
    ∃ updated', runtimePathOramSetLeafAt? leaves' slot value' = some updated' ∧
      SameSlots updated updated' := by
  induction h generalizing slot updated with
  | nil => simp [runtimePathOramSetLeafAt?] at hSet
  | @cons x y xs ys hxy hrest ih =>
      cases slot with
      | zero =>
          simp only [runtimePathOramSetLeafAt?, Option.some.injEq] at hSet
          subst hSet
          exact ⟨value' :: ys, rfl, Forall₂.cons hValue hrest⟩
      | succ slot =>
          simp only [runtimePathOramSetLeafAt?, Option.bind_eq_bind] at hSet
          cases hTail : runtimePathOramSetLeafAt? xs slot value with
          | none => simp [hTail] at hSet
          | some tail =>
              simp only [hTail, Option.bind_some, Option.some.injEq] at hSet
              subst hSet
              obtain ⟨tail', hTail', hSlots⟩ := ih hTail
              refine ⟨y :: tail', ?_, Forall₂.cons hxy hSlots⟩
              simp [runtimePathOramSetLeafAt?, hTail']

theorem stateUpdate?_sameSupport {state state' : RuntimePathOramPositionMapState}
    (h : SameSupport state state') {objectId : Nat} {leaves leaves' : List (Option Nat)}
    (hSlots : SameSlots leaves leaves') {next : RuntimePathOramPositionMapState}
    (hUpdate : runtimePathOramStateUpdate? state objectId leaves = some next) :
    ∃ next', runtimePathOramStateUpdate? state' objectId leaves' = some next' ∧
      SameSupport next next' := by
  induction h generalizing next with
  | nil => simp [runtimePathOramStateUpdate?] at hUpdate
  | @cons e e' es es' hEntry hrest ih =>
      obtain ⟨hId, hEntrySlots⟩ := hEntry
      obtain ⟨id, l⟩ := e
      obtain ⟨id', l'⟩ := e'
      simp only at hId hEntrySlots
      subst hId
      by_cases hEq : id = objectId
      · subst hEq
        simp only [runtimePathOramStateUpdate?, if_true, Option.some.injEq] at hUpdate
        subst hUpdate
        exact ⟨(id, leaves') :: es', by simp [runtimePathOramStateUpdate?],
          Forall₂.cons ⟨rfl, hSlots⟩ hrest⟩
      · simp only [runtimePathOramStateUpdate?, hEq, if_false, Option.bind_eq_bind] at hUpdate
        cases hTail : runtimePathOramStateUpdate? es objectId leaves with
        | none => simp [hTail] at hUpdate
        | some tail =>
            simp only [hTail, Option.bind_some, Option.some.injEq] at hUpdate
            subst hUpdate
            obtain ⟨tail', hTail', hSupp⟩ := ih hTail
            refine ⟨(id, l') :: tail', ?_, Forall₂.cons ⟨rfl, hEntrySlots⟩ hSupp⟩
            simp [runtimePathOramStateUpdate?, hEq, hTail']

theorem stateLeafMap_of_lookup {state : RuntimePathOramPositionMapState} {objectId : Nat}
    {leaves : List (Option Nat)} (h : runtimePathOramStateLookup? state objectId = some leaves)
    (slot : Nat) : stateLeafMap state (objectId, slot) = leafMapOf leaves slot := by
  simp [stateLeafMap, h]

theorem stateLeafMap_update {state next : RuntimePathOramPositionMapState} {objectId : Nat}
    {leaves updated : List (Option Nat)} {slot : Nat} {value : Option Nat}
    (hLookup : runtimePathOramStateLookup? state objectId = some leaves)
    (hSet : runtimePathOramSetLeafAt? leaves slot value = some updated)
    (hUpdate : runtimePathOramStateUpdate? state objectId updated = some next) :
    stateLeafMap next = setAt (stateLeafMap state) (objectId, slot) value := by
  funext key
  obtain ⟨m, s⟩ := key
  by_cases hm : m = objectId
  · subst hm
    rw [stateLeafMap_of_lookup (stateLookup?_of_stateUpdate? hUpdate), leafMapOf_setLeafAt? hSet]
    by_cases hs : s = slot
    · subst hs; simp [setAt]
    · simp [setAt, hs, stateLeafMap_of_lookup hLookup]
  · simp only [stateLeafMap, stateLookup?_of_stateUpdate?_ne hUpdate hm, setAt]
    have hNe : ((m, s) = (objectId, slot)) = False := by
      apply propext; constructor
      · intro h; exact hm (Prod.mk.inj h).1
      · intro h; exact h.elim
    simp only [hNe, if_false]

theorem bounded_update {objects : List RuntimeOramObjectCertificate} {state next : RuntimePathOramPositionMapState}
    {objectId : Nat} {leaves updated : List (Option Nat)} {slot : Nat} {value : Option Nat}
    (hBound : Bounded objects state)
    (hValue : ∀ v, value = some v → v < leafBound objects objectId)
    (hLookup : runtimePathOramStateLookup? state objectId = some leaves)
    (hSet : runtimePathOramSetLeafAt? leaves slot value = some updated)
    (hUpdate : runtimePathOramStateUpdate? state objectId updated = some next) :
    Bounded objects next := by
  intro key v hv
  rw [stateLeafMap_update hLookup hSet hUpdate] at hv
  simp only [setAt] at hv
  split at hv
  · rename_i hKey
    subst hKey
    exact hValue v hv
  · exact hBound key v hv

/-- One slot update on states with the same support. -/
theorem slotUpdate_subst {objects : List RuntimeOramObjectCertificate}
    {state state' next : RuntimePathOramPositionMapState} (hSupp : SameSupport state state')
    (hBound : Bounded objects state') {objectId slot : Nat} {leaves updated : List (Option Nat)}
    {value value' : Option Nat} (hValue : value.isSome = value'.isSome)
    (hValueBound : ∀ v, value' = some v → v < leafBound objects objectId)
    (hLookup : runtimePathOramStateLookup? state objectId = some leaves)
    (hSet : runtimePathOramSetLeafAt? leaves slot value = some updated)
    (hUpdate : runtimePathOramStateUpdate? state objectId updated = some next) :
    ∃ leaves' updated' next',
      runtimePathOramStateLookup? state' objectId = some leaves' ∧
      SameSlots leaves leaves' ∧
      runtimePathOramSetLeafAt? leaves' slot value' = some updated' ∧
      runtimePathOramStateUpdate? state' objectId updated' = some next' ∧
      SameSupport next next' ∧ Bounded objects next' ∧
      stateLeafMap next' = setAt (stateLeafMap state') (objectId, slot) value' := by
  obtain ⟨leaves', hLookup', hSlots⟩ := lookup_sameSupport hSupp hLookup
  obtain ⟨updated', hSet', hSlotsUpd⟩ := setLeafAt?_sameSlots hSlots hValue hSet
  obtain ⟨next', hUpdate', hSuppNext⟩ := stateUpdate?_sameSupport hSupp hSlotsUpd hUpdate
  exact ⟨leaves', updated', next', hLookup', hSlots, hSet', hUpdate', hSuppNext,
    bounded_update hBound hValueBound hLookup' hSet' hUpdate',
    stateLeafMap_update hLookup' hSet' hUpdate'⟩

theorem present_slot_subst {leaves leaves' : List (Option Nat)} (hSlots : SameSlots leaves leaves')
    {slot prior : Nat} (h : runtimePathOramGetLeafAt? leaves slot = some (some prior)) :
    ∃ prior', runtimePathOramGetLeafAt? leaves' slot = some (some prior') ∧
      leafMapOf leaves' slot = some prior' := by
  have hMap := getElem?_sameSlots hSlots slot
  rw [getLeafAt?_eq] at h
  rw [h] at hMap
  cases hGet : leaves'[slot]? with
  | none => simp [hGet] at hMap
  | some x =>
      cases x with
      | none => simp [hGet] at hMap
      | some prior' =>
          refine ⟨prior', by rw [getLeafAt?_eq, hGet], by simp [leafMapOf, hGet]⟩

theorem absent_slot_subst {leaves leaves' : List (Option Nat)} (hSlots : SameSlots leaves leaves')
    {slot : Nat} (h : runtimePathOramGetLeafAt? leaves slot = some none) :
    runtimePathOramGetLeafAt? leaves' slot = some none ∧ leafMapOf leaves' slot = none := by
  have hMap := getElem?_sameSlots hSlots slot
  rw [getLeafAt?_eq] at h
  rw [h] at hMap
  cases hGet : leaves'[slot]? with
  | none => simp [hGet] at hMap
  | some x =>
      cases x with
      | none => exact ⟨by rw [getLeafAt?_eq, hGet], by simp [leafMapOf, hGet]⟩
      | some _ => simp [hGet] at hMap

set_option maxHeartbeats 1000000 in
/-- **One transition, with the model's leaves.** If the replay accepts a
transition, it accepts the same transition with the leaf the model reads and
the model's next leaf, from any state with the same support and bounded
leaves, and the state moves as the model's leaves move. -/
theorem applyTransition_subst {objects : List RuntimeOramObjectCertificate}
    {state state' next : RuntimePathOramPositionMapState}
    {leaf : RuntimeOramLeafCertificate} {transition : RuntimePathOramTransitionCertificate}
    (h : runtimePathOramApplyTransition? state objects leaf transition = some next)
    (hSupp : SameSupport state state') (hBound : Bounded objects state')
    {m n : Nat} (hm : m < leafBound objects leaf.objectId) (hn : n < leafBound objects leaf.objectId) :
    ∃ next',
      runtimePathOramApplyTransition? state' objects
          { leaf with
            leaf := (stepLeaves m n (stateLeafMap state')
              (liftStep leaf.objectId (LeafStep.ofTransition transition))).1 }
          { transition with
            priorLeaf := transition.priorLeaf.map fun _ =>
              (stepLeaves m n (stateLeafMap state')
                (liftStep leaf.objectId (LeafStep.ofTransition transition))).1
            nextLeaf := transition.nextLeaf.map fun _ => n } = some next' ∧
      SameSupport next next' ∧ Bounded objects next' ∧
      stateLeafMap next' =
        (stepLeaves m n (stateLeafMap state')
          (liftStep leaf.objectId (LeafStep.ofTransition transition))).2 := by
  obtain ⟨objectId, objectName, bucketCount, leafValue⟩ := leaf
  obtain ⟨tId, tName, tBucket, kind, slotIndex, priorLeaf, nextLeaf⟩ := transition
  simp only [runtimePathOramApplyTransition?, Option.bind_eq_bind] at h
  cases hObj : runtimeOramObjectById? objects objectId with
  | none => simp [hObj] at h
  | some object =>
      simp only [hObj, Option.bind_some] at h
      split at h
      · cases h
      rename_i hGuard
      simp only [Bool.or_eq_true, Bool.not_eq_true', bne_iff_ne, ne_eq, decide_eq_true_eq,
        not_or, Classical.not_not] at hGuard
      obtain ⟨⟨⟨⟨⟨⟨hScheme, hId⟩, hName⟩, hBucket⟩, hObjName⟩, hObjBucket⟩, hLeafLt⟩ := hGuard
      have hBoundObj : leafBound objects objectId = object.pathOramLeafChoiceCount := by
        simp [leafBound, objectBucketCount, hObj, RuntimeOramObjectCertificate.pathOramLeafChoiceCount,
          pathOramLeafChoiceCount, pathOramLeafCount]
      rw [hBoundObj] at hm hn
      cases hLookup : runtimePathOramStateLookup? state objectId with
      | none => simp [hLookup] at h
      | some leaves =>
          simp only [hLookup, Option.bind_some] at h
          obtain ⟨leaves', hLookup', hSlots⟩ := lookup_sameSupport hSupp hLookup
          cases kind <;> rcases slotIndex with _ | slot <;> rcases priorLeaf with _ | prior <;>
            rcases nextLeaf with _ | next₀ <;> simp at h
          all_goals have hScheme' : isPathOramScheme object.scheme = true := by simpa using hScheme
          · -- readMiss
            subst h
            refine ⟨state', ?_, hSupp, hBound, ?_⟩
            · simp [runtimePathOramApplyTransition?, LeafStep.ofTransition, liftStep, stepLeaves, hObj,
                hScheme', hId, hName, hBucket, hObjName, hObjBucket, hLookup', Nat.not_le.mpr hm]
            · simp [LeafStep.ofTransition, liftStep, stepLeaves]
          · -- readHit
            obtain ⟨⟨⟨hPrior, hNextLt⟩, hGet⟩, hRest⟩ := h
            obtain ⟨updated, hSet, hUpdate⟩ := Option.bind_eq_some_iff.mp hRest
            obtain ⟨p', hGet', hMap'⟩ := present_slot_subst hSlots hGet
            have hp' : p' < object.pathOramLeafChoiceCount := by
              have := hBound (objectId, slot) p' (by rw [stateLeafMap_of_lookup hLookup']; exact hMap')
              simpa [hBoundObj] using this
            obtain ⟨l', u', next', hL', _, hSet', hUpdate', hSuppNext, hBoundNext, hMapNext⟩ :=
              slotUpdate_subst (value := some next₀) (value' := some n) hSupp hBound rfl
                (fun v hv => by cases hv; rw [hBoundObj]; exact hn) hLookup hSet hUpdate
            rw [hLookup'] at hL'
            cases hL'
            have hStep : stepLeaves m n (stateLeafMap state') (LeafStep.remap (objectId, slot)) =
                (p', setAt (stateLeafMap state') (objectId, slot) (some n)) := by
              simp [stepLeaves, stateLeafMap_of_lookup hLookup', hMap']
            dsimp only
            simp only [LeafStep.ofTransition, liftStep, hStep]
            refine ⟨next', ?_, hSuppNext, hBoundNext, hMapNext⟩
            simp [runtimePathOramApplyTransition?, hObj, hScheme', hId, hName, hBucket, hObjName,
              hObjBucket, hLookup', hGet', hSet', hUpdate', Nat.not_le.mpr hp', hn]
          · -- writeNoop none
            subst h
            refine ⟨state', ?_, hSupp, hBound, ?_⟩
            · simp [runtimePathOramApplyTransition?, LeafStep.ofTransition, liftStep, stepLeaves, hObj,
                hScheme', hId, hName, hBucket, hObjName, hObjBucket, hLookup', Nat.not_le.mpr hm]
            · simp [LeafStep.ofTransition, liftStep, stepLeaves]
          · -- writeNoop some
            obtain ⟨⟨⟨hPrior, hNextLt⟩, hGet⟩, hRest⟩ := h
            obtain ⟨updated, hSet, hUpdate⟩ := Option.bind_eq_some_iff.mp hRest
            obtain ⟨p', hGet', hMap'⟩ := present_slot_subst hSlots hGet
            have hp' : p' < object.pathOramLeafChoiceCount := by
              have := hBound (objectId, slot) p' (by rw [stateLeafMap_of_lookup hLookup']; exact hMap')
              simpa [hBoundObj] using this
            obtain ⟨l', u', next', hL', _, hSet', hUpdate', hSuppNext, hBoundNext, hMapNext⟩ :=
              slotUpdate_subst (value := some next₀) (value' := some n) hSupp hBound rfl
                (fun v hv => by cases hv; rw [hBoundObj]; exact hn) hLookup hSet hUpdate
            rw [hLookup'] at hL'
            cases hL'
            have hStep : stepLeaves m n (stateLeafMap state') (LeafStep.remap (objectId, slot)) =
                (p', setAt (stateLeafMap state') (objectId, slot) (some n)) := by
              simp [stepLeaves, stateLeafMap_of_lookup hLookup', hMap']
            dsimp only
            simp only [LeafStep.ofTransition, liftStep, hStep]
            refine ⟨next', ?_, hSuppNext, hBoundNext, hMapNext⟩
            simp [runtimePathOramApplyTransition?, hObj, hScheme', hId, hName, hBucket, hObjName,
              hObjBucket, hLookup', hGet', hSet', hUpdate', Nat.not_le.mpr hp', hn]
          · -- writeInsert
            obtain ⟨⟨hNextLt, hGet⟩, hRest⟩ := h
            obtain ⟨updated, hSet, hUpdate⟩ := Option.bind_eq_some_iff.mp hRest
            obtain ⟨hGet', hMap'⟩ := absent_slot_subst hSlots hGet
            obtain ⟨l', u', next', hL', _, hSet', hUpdate', hSuppNext, hBoundNext, hMapNext⟩ :=
              slotUpdate_subst (value := some next₀) (value' := some n) hSupp hBound rfl
                (fun v hv => by cases hv; rw [hBoundObj]; exact hn) hLookup hSet hUpdate
            rw [hLookup'] at hL'
            cases hL'
            dsimp only
            simp only [LeafStep.ofTransition, liftStep, stepLeaves]
            refine ⟨next', ?_, hSuppNext, hBoundNext, hMapNext⟩
            simp [runtimePathOramApplyTransition?, hObj, hScheme', hId, hName, hBucket, hObjName,
              hObjBucket, hLookup', hGet', hSet', hUpdate', Nat.not_le.mpr hm, hn]
          · -- writeUpdate
            obtain ⟨⟨⟨hPrior, hNextLt⟩, hGet⟩, hRest⟩ := h
            obtain ⟨updated, hSet, hUpdate⟩ := Option.bind_eq_some_iff.mp hRest
            obtain ⟨p', hGet', hMap'⟩ := present_slot_subst hSlots hGet
            have hp' : p' < object.pathOramLeafChoiceCount := by
              have := hBound (objectId, slot) p' (by rw [stateLeafMap_of_lookup hLookup']; exact hMap')
              simpa [hBoundObj] using this
            obtain ⟨l', u', next', hL', _, hSet', hUpdate', hSuppNext, hBoundNext, hMapNext⟩ :=
              slotUpdate_subst (value := some next₀) (value' := some n) hSupp hBound rfl
                (fun v hv => by cases hv; rw [hBoundObj]; exact hn) hLookup hSet hUpdate
            rw [hLookup'] at hL'
            cases hL'
            have hStep : stepLeaves m n (stateLeafMap state') (LeafStep.remap (objectId, slot)) =
                (p', setAt (stateLeafMap state') (objectId, slot) (some n)) := by
              simp [stepLeaves, stateLeafMap_of_lookup hLookup', hMap']
            dsimp only
            simp only [LeafStep.ofTransition, liftStep, hStep]
            refine ⟨next', ?_, hSuppNext, hBoundNext, hMapNext⟩
            simp [runtimePathOramApplyTransition?, hObj, hScheme', hId, hName, hBucket, hObjName,
              hObjBucket, hLookup', hGet', hSet', hUpdate', Nat.not_le.mpr hp', hn]
          · -- writeDelete
            obtain ⟨⟨hPrior, hGet⟩, hRest⟩ := h
            obtain ⟨updated, hSet, hUpdate⟩ := Option.bind_eq_some_iff.mp hRest
            obtain ⟨p', hGet', hMap'⟩ := present_slot_subst hSlots hGet
            have hp' : p' < object.pathOramLeafChoiceCount := by
              have := hBound (objectId, slot) p' (by rw [stateLeafMap_of_lookup hLookup']; exact hMap')
              simpa [hBoundObj] using this
            obtain ⟨l', u', next', hL', _, hSet', hUpdate', hSuppNext, hBoundNext, hMapNext⟩ :=
              slotUpdate_subst (value' := none) hSupp hBound rfl (fun v hv => by cases hv)
                hLookup hSet hUpdate
            rw [hLookup'] at hL'
            cases hL'
            have hStep : stepLeaves m n (stateLeafMap state') (LeafStep.delete (objectId, slot)) =
                (p', setAt (stateLeafMap state') (objectId, slot) none) := by
              simp [stepLeaves, stateLeafMap_of_lookup hLookup', hMap']
            dsimp only
            simp only [LeafStep.ofTransition, liftStep, hStep]
            refine ⟨next', ?_, hSuppNext, hBoundNext, hMapNext⟩
            simp [runtimePathOramApplyTransition?, hObj, hScheme', hId, hName, hBucket, hObjName,
              hObjBucket, hLookup', hGet', hSet', hUpdate', Nat.not_le.mpr hp']

/-- **The replay accepts the model's leaves.** If the replay accepts the
runtime's transitions from a state, it accepts them with the model's leaves on
`coins` from any state with the same support and bounded leaves, and ends in
the model's final leaves. -/
theorem replay_substSteps {objects : List RuntimeOramObjectCertificate} :
    ∀ {state final state' : RuntimePathOramPositionMapState}
      {leafs : List RuntimeOramLeafCertificate} {transitions : List RuntimePathOramTransitionCertificate}
      {coins : List Nat},
      replayRuntimePathOramTransitionsAux state objects leafs transitions = some final →
      SameSupport state state' → Bounded objects state' → CoinsOk objects leafs coins →
      ∃ final',
        replayRuntimePathOramTransitionsAux state' objects
            (substSteps (stateLeafMap state') leafs transitions coins).1
            (substSteps (stateLeafMap state') leafs transitions coins).2 = some final' ∧
        SameSupport final final' ∧ Bounded objects final' ∧
        stateLeafMap final' =
          (runLeaves (stateLeafMap state') (liftSteps (transitionAccesses leafs transitions)) coins).2
  | state, final, state', [], [], coins, h, hSupp, hBound, _ => by
      simp only [replayRuntimePathOramTransitionsAux, Option.some.injEq] at h
      subst h
      exact ⟨state', rfl, hSupp, hBound, rfl⟩
  | _, _, _, [], _ :: _, _, h, _, _, _ => by simp [replayRuntimePathOramTransitionsAux] at h
  | _, _, _, _ :: _, [], _, h, _, _, _ => by simp [replayRuntimePathOramTransitionsAux] at h
  | state, final, state', leaf :: leafs, transition :: transitions, coins, h, hSupp, hBound, hCoins => by
      simp only [replayRuntimePathOramTransitionsAux, Option.bind_eq_bind] at h
      obtain ⟨next, hApply, hRest⟩ := Option.bind_eq_some_iff.mp h
      obtain ⟨hm, hn, hCoinsRest⟩ := hCoins
      obtain ⟨next', hApply', hSupp', hBound', hMap'⟩ :=
        applyTransition_subst hApply hSupp hBound hm hn
      obtain ⟨final', hReplay', hSuppFinal, hBoundFinal, hMapFinal⟩ :=
        replay_substSteps hRest hSupp' hBound' hCoinsRest
      rw [hMap'] at hReplay' hMapFinal
      refine ⟨final', ?_, hSuppFinal, hBoundFinal, ?_⟩
      · simp only [substSteps, replayRuntimePathOramTransitionsAux, Option.bind_eq_bind, hApply',
          Option.bind_some]
        exact hReplay'
      · simp only [transitionAccesses, liftSteps, List.map_cons, runLeaves]
        exact hMapFinal

/-! ## Position-map certificates with substituted leaves -/

/-- An entry's occupied slots, given the leaves `leafOf` gives them. -/
def substEntry (leafOf : Nat × Nat → Option Nat) (entry : Nat × List (Option Nat)) :
    Nat × List (Option Nat) :=
  (entry.1, entry.2.mapIdx fun slot leaf => leaf.bind fun _ => leafOf (entry.1, slot))

/-- A position-map certificate's occupied slots, given the leaves `leafOf`
gives them. -/
def substCert (leafOf : Nat × Nat → Option Nat) (cert : RuntimePathOramPositionMapCertificate) :
    RuntimePathOramPositionMapCertificate :=
  { cert with leaves := cert.leaves.mapIdx fun slot leaf => leaf.bind fun _ => leafOf (cert.objectId, slot) }

theorem mapM_option_map {α β γ : Type} {f : α → Option β} {f' : α → Option γ} {g : β → γ} :
    ∀ {xs : List α} {ys : List β}, (∀ a ∈ xs, ∀ b, f a = some b → f' a = some (g b)) →
      xs.mapM f = some ys → xs.mapM f' = some (ys.map g)
  | [], ys, _, h => by
      simp only [List.mapM_nil, pure, Option.some.injEq] at h
      subst h
      rfl
  | a :: as, ys, hf, h => by
      simp only [List.mapM_cons, Option.bind_eq_bind, pure] at h ⊢
      obtain ⟨b, hb, hRest⟩ := Option.bind_eq_some_iff.mp h
      obtain ⟨bs, hbs, hys⟩ := Option.bind_eq_some_iff.mp hRest
      simp only [Option.some.injEq] at hys
      subst hys
      have hb' := hf a List.mem_cons_self b hb
      have hbs' := mapM_option_map (fun a' ha' => hf a' (List.mem_cons_of_mem _ ha')) hbs
      simp [hb', hbs']

theorem mapM_option_fst {α : Type} {f : α → Option (Nat × List (Option Nat))} {key : α → Nat}
    (hKey : ∀ a b, f a = some b → b.1 = key a) :
    ∀ {xs : List α} {ys : List (Nat × List (Option Nat))}, xs.mapM f = some ys →
      ys.map (·.1) = xs.map key
  | [], ys, h => by
      simp only [List.mapM_nil, pure, Option.some.injEq] at h
      subst h
      rfl
  | a :: as, ys, h => by
      simp only [List.mapM_cons, Option.bind_eq_bind, pure] at h
      obtain ⟨b, hb, hRest⟩ := Option.bind_eq_some_iff.mp h
      obtain ⟨bs, hbs, hys⟩ := Option.bind_eq_some_iff.mp hRest
      simp only [Option.some.injEq] at hys
      subst hys
      simp [hKey a b hb, mapM_option_fst hKey hbs]

theorem objectById_of_mem {objects : List RuntimeOramObjectCertificate}
    (hNodup : (objects.map (·.objectId)).Nodup) {object : RuntimeOramObjectCertificate}
    (hMem : object ∈ objects) : runtimeOramObjectById? objects object.objectId = some object := by
  induction objects with
  | nil => simp at hMem
  | cons o objects ih =>
      simp only [List.map_cons, List.nodup_cons, List.mem_map] at hNodup
      obtain ⟨hNotMem, hNodup⟩ := hNodup
      rcases List.mem_cons.mp hMem with rfl | hMem
      · simp [runtimeOramObjectById?]
      · have hNe : o.objectId ≠ object.objectId := by
          intro hEq
          exact hNotMem ⟨object, hMem, hEq.symm⟩
        simp only [runtimeOramObjectById?, List.find?_cons, hNe, decide_false] at ih ⊢
        exact ih hNodup hMem

theorem leafBound_of_mem {objects : List RuntimeOramObjectCertificate}
    (hNodup : (objects.map (·.objectId)).Nodup) {object : RuntimeOramObjectCertificate}
    (hMem : object ∈ objects) : leafBound objects object.objectId = object.pathOramLeafChoiceCount := by
  simp [leafBound, objectBucketCount, objectById_of_mem hNodup hMem,
    RuntimeOramObjectCertificate.pathOramLeafChoiceCount, pathOramLeafChoiceCount, pathOramLeafCount]

/-- The maps of a position-map state are the Path ORAM objects, in order. -/
theorem byObject_ids {before : List RuntimePathOramPositionMapCertificate}
    {objects : List RuntimeOramObjectCertificate} {state : RuntimePathOramPositionMapState}
    (h : runtimePathOramPositionMapStateByObject before objects = some state) :
    state.map (·.1) = (objects.filter RuntimeOramObjectCertificate.isPathOram).map (·.objectId) := by
  unfold runtimePathOramPositionMapStateByObject at h
  simp only [Option.bind_eq_bind] at h
  split at h
  · cases h
  · refine mapM_option_fst ?_ h
    intro object entry hEntry
    obtain ⟨cert, _, hIf⟩ := Option.bind_eq_some_iff.mp hEntry
    split at hIf
    · simp only [Option.some.injEq] at hIf
      subst hIf
      rfl
    · cases hIf

theorem nodup_byObject {before : List RuntimePathOramPositionMapCertificate}
    {objects : List RuntimeOramObjectCertificate} {state : RuntimePathOramPositionMapState}
    (hNodup : (objects.map (·.objectId)).Nodup)
    (h : runtimePathOramPositionMapStateByObject before objects = some state) :
    (state.map (·.1)).Nodup := by
  rw [byObject_ids h]
  exact List.Nodup.sublist (List.Sublist.map _ List.filter_sublist) hNodup

theorem leavesWithinBound_substCert {leaves : List (Option Nat)} {leafOf : Nat × Nat → Option Nat}
    {objectId bound : Nat} (hBound : ∀ slot v, leafOf (objectId, slot) = some v → v < bound) :
    runtimePathOramLeavesWithinBound
        (leaves.mapIdx fun slot leaf => leaf.bind fun _ => leafOf (objectId, slot)) bound = true := by
  unfold runtimePathOramLeavesWithinBound
  rw [List.all_eq_true]
  intro x hx
  obtain ⟨slot, hSlot⟩ := List.mem_iff_getElem?.mp hx
  rw [List.getElem?_mapIdx] at hSlot
  cases hLeaf : leaves[slot]? with
  | none => simp [hLeaf] at hSlot
  | some leaf =>
      simp only [hLeaf, Option.map_some, Option.some.injEq] at hSlot
      subst hSlot
      cases leaf with
      | none => simp
      | some _ =>
          cases hOf : leafOf (objectId, slot) with
          | none => simp
          | some v => simpa [hOf] using hBound slot v hOf

/-- Substituting the leaves of the certificates substitutes those of the
state they give. -/
theorem byObject_substCert (leafOf : Nat × Nat → Option Nat)
    {before : List RuntimePathOramPositionMapCertificate} {objects : List RuntimeOramObjectCertificate}
    {state : RuntimePathOramPositionMapState} (hNodup : (objects.map (·.objectId)).Nodup)
    (hLeafBound : ∀ objectId slot v, leafOf (objectId, slot) = some v → v < leafBound objects objectId)
    (h : runtimePathOramPositionMapStateByObject before objects = some state) :
    runtimePathOramPositionMapStateByObject (before.map (substCert leafOf)) objects =
      some (state.map (substEntry leafOf)) := by
  unfold runtimePathOramPositionMapStateByObject at h ⊢
  simp only [Option.bind_eq_bind, List.length_map] at h ⊢
  split at h
  · cases h
  · rename_i hLen
    simp only [hLen, if_false, Bool.false_eq_true]
    refine mapM_option_map ?_ h
    intro object hObject entry hEntry
    have hMem : object ∈ objects := (List.mem_filter.mp hObject).1
    obtain ⟨cert, hCert, hIf⟩ := Option.bind_eq_some_iff.mp hEntry
    have hFind : runtimePathOramPositionMapCertificateById? (before.map (substCert leafOf))
        object.objectId = some (substCert leafOf cert) := by
      unfold runtimePathOramPositionMapCertificateById? at hCert ⊢
      rw [List.find?_map]
      have hComp : ((fun state : RuntimePathOramPositionMapCertificate =>
          decide (state.objectId = object.objectId)) ∘ substCert leafOf) =
          fun state => decide (state.objectId = object.objectId) := rfl
      rw [hComp, hCert]
      rfl
    have hCertId : cert.objectId = object.objectId := by
      unfold runtimePathOramPositionMapCertificateById? at hCert
      simpa using List.find?_some hCert
    rw [hFind]
    simp only [Option.bind_some]
    split at hIf
    · rename_i hCond
      simp only [Option.some.injEq] at hIf
      subst hIf
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hCond
      obtain ⟨⟨hName, hCapacity⟩, _⟩ := hCond
      have hWithin := leavesWithinBound_substCert (leaves := cert.leaves) (leafOf := leafOf)
        (objectId := object.objectId) (bound := object.pathOramLeafChoiceCount)
        (fun slot v hv => by rw [← leafBound_of_mem hNodup hMem]; exact hLeafBound _ slot v hv)
      simp [substCert, substEntry, hName, hCapacity, hCertId, hWithin]
    · cases hIf

/-- The keys a state holds, map by map and slot by slot. -/
def presentKeys (state : RuntimePathOramPositionMapState) : List (Nat × Nat) :=
  state.flatMap fun entry =>
    (List.range entry.2.length).filterMap fun slot =>
      if (leafMapOf entry.2 slot).isSome then some (entry.1, slot) else none

theorem presentKeys_fst {state : RuntimePathOramPositionMapState} {key : Nat × Nat}
    (h : key ∈ presentKeys state) : key.1 ∈ state.map (·.1) := by
  simp only [presentKeys, List.mem_flatMap, List.mem_filterMap, List.mem_range] at h
  obtain ⟨entry, hEntry, slot, _, hIf⟩ := h
  split at hIf
  · simp only [Option.some.injEq] at hIf
    subst hIf
    exact List.mem_map.mpr ⟨entry, hEntry, rfl⟩
  · cases hIf

theorem leafMapOf_none_of_le {leaves : List (Option Nat)} {slot : Nat} (h : leaves.length ≤ slot) :
    leafMapOf leaves slot = none := by
  simp [leafMapOf, List.getElem?_eq_none h]

theorem stateLeafMap_cons_ne {objectId : Nat} {leaves : List (Option Nat)}
    {rest : RuntimePathOramPositionMapState} {key : Nat × Nat} (h : objectId ≠ key.1) :
    stateLeafMap ((objectId, leaves) :: rest) key = stateLeafMap rest key := by
  simp [stateLeafMap, runtimePathOramStateLookup?, h]

theorem stateLeafMap_cons_eq {objectId : Nat} {leaves : List (Option Nat)}
    {rest : RuntimePathOramPositionMapState} (slot : Nat) :
    stateLeafMap ((objectId, leaves) :: rest) (objectId, slot) = leafMapOf leaves slot := by
  simp [stateLeafMap, runtimePathOramStateLookup?]

theorem isSome_stateLeafMap_mem :
    ∀ {state : RuntimePathOramPositionMapState} {key : Nat × Nat},
      (stateLeafMap state key).isSome = true → key.1 ∈ state.map (·.1)
  | [], key, h => by simp [stateLeafMap, runtimePathOramStateLookup?] at h
  | (objectId, leaves) :: rest, key, h => by
      by_cases hId : objectId = key.1
      · exact List.mem_map.mpr ⟨(objectId, leaves), List.mem_cons_self, hId⟩
      · rw [stateLeafMap_cons_ne hId] at h
        exact List.mem_cons_of_mem _ (isSome_stateLeafMap_mem h)

theorem mem_presentKeys_iff {state : RuntimePathOramPositionMapState} (hNodup : (state.map (·.1)).Nodup)
    (key : Nat × Nat) : key ∈ presentKeys state ↔ (stateLeafMap state key).isSome = true := by
  induction state with
  | nil => simp [presentKeys, stateLeafMap, runtimePathOramStateLookup?]
  | cons entry rest ih =>
      obtain ⟨objectId, leaves⟩ := entry
      simp only [List.map_cons, List.nodup_cons] at hNodup
      obtain ⟨hNotMem, hNodup⟩ := hNodup
      have hHead : key ∈ (List.range leaves.length).filterMap (fun slot =>
          if (leafMapOf leaves slot).isSome then some (objectId, slot) else none) ↔
          key.1 = objectId ∧ (leafMapOf leaves key.2).isSome = true := by
        simp only [List.mem_filterMap, List.mem_range]
        constructor
        · rintro ⟨slot, _, hIf⟩
          split at hIf
          · rename_i hSome
            simp only [Option.some.injEq] at hIf
            subst hIf
            exact ⟨rfl, hSome⟩
          · cases hIf
        · rintro ⟨hId, hSome⟩
          obtain ⟨k₁, k₂⟩ := key
          simp only at hId hSome
          subst hId
          refine ⟨k₂, ?_, by simp [hSome]⟩
          rcases Nat.lt_or_ge k₂ leaves.length with hLt | hGe
          · exact hLt
          · rw [leafMapOf_none_of_le hGe] at hSome
            cases hSome
      have hSplit : key ∈ presentKeys ((objectId, leaves) :: rest) ↔
          key ∈ (List.range leaves.length).filterMap (fun slot =>
            if (leafMapOf leaves slot).isSome then some (objectId, slot) else none) ∨
          key ∈ presentKeys rest := by
        simp [presentKeys]
      rw [hSplit, hHead, ih hNodup]
      by_cases hId : key.1 = objectId
      · obtain ⟨k₁, k₂⟩ := key
        simp only at hId
        subst hId
        rw [stateLeafMap_cons_eq]
        have hRest : (stateLeafMap rest (k₁, k₂)).isSome = false := by
          cases hLookup : stateLeafMap rest (k₁, k₂) with
          | none => rfl
          | some v =>
              exact absurd (isSome_stateLeafMap_mem (state := rest) (key := (k₁, k₂)) (by simp [hLookup])) hNotMem
        rw [hRest]
        simp
      · rw [stateLeafMap_cons_ne (Ne.symm hId)]
        simp [hId]

theorem stateLeafMap_substEntry (leafOf : Nat × Nat → Option Nat) (state : RuntimePathOramPositionMapState)
    (key : Nat × Nat) :
    stateLeafMap (state.map (substEntry leafOf)) key = (stateLeafMap state key).bind fun _ => leafOf key := by
  induction state with
  | nil => simp [stateLeafMap, runtimePathOramStateLookup?]
  | cons entry rest ih =>
      obtain ⟨objectId, leaves⟩ := entry
      by_cases hId : objectId = key.1
      · obtain ⟨k₁, k₂⟩ := key
        simp only at hId
        subst hId
        simp only [List.map_cons, substEntry, stateLeafMap_cons_eq, leafMapOf, List.getElem?_mapIdx]
        cases leaves[k₂]? with
        | none => rfl
        | some leaf => cases leaf <;> rfl
      · simp only [List.map_cons, substEntry]
        rw [stateLeafMap_cons_ne hId, stateLeafMap_cons_ne hId]
        exact ih

theorem forall₂_mapIdx {α β : Type} {R : α → β → Prop} :
    ∀ {l : List α} {f : Nat → α → β}, (∀ i x, l[i]? = some x → R x (f i x)) → Forall₂ R l (l.mapIdx f)
  | [], _, _ => Forall₂.nil
  | x :: xs, f, h => by
      rw [List.mapIdx_cons]
      exact Forall₂.cons (h 0 x rfl) (forall₂_mapIdx fun i y hy => h (i + 1) y (by simpa using hy))

theorem sameSupport_substEntry {state : RuntimePathOramPositionMapState} (hNodup : (state.map (·.1)).Nodup)
    {leafOf : Nat × Nat → Option Nat}
    (hSome : ∀ key, (stateLeafMap state key).isSome = true → (leafOf key).isSome = true) :
    SameSupport state (state.map (substEntry leafOf)) := by
  induction state with
  | nil => exact Forall₂.nil
  | cons entry rest ih =>
      obtain ⟨objectId, leaves⟩ := entry
      simp only [List.map_cons, List.nodup_cons] at hNodup
      obtain ⟨hNotMem, hNodup⟩ := hNodup
      refine Forall₂.cons ⟨rfl, ?_⟩ (ih hNodup ?_)
      · apply forall₂_mapIdx
        intro slot x hx
        cases x with
        | none => rfl
        | some v =>
            have hKey : (stateLeafMap ((objectId, leaves) :: rest) (objectId, slot)).isSome = true := by
              rw [stateLeafMap_cons_eq]
              simp [leafMapOf, hx]
            have := hSome (objectId, slot) hKey
            simp only [Option.isSome_some, Option.bind_some]
            exact this.symm
      · intro key hKey
        apply hSome
        have hNe : objectId ≠ key.1 := by
          intro hEq
          exact hNotMem (hEq ▸ isSome_stateLeafMap_mem hKey)
        rw [stateLeafMap_cons_ne hNe]
        exact hKey

theorem sameSupport_ids :
    ∀ {a b : RuntimePathOramPositionMapState}, SameSupport a b → b.map (·.1) = a.map (·.1)
  | _, _, .nil => rfl
  | _, _, .cons hab h => by simp [hab.1, sameSupport_ids h]

theorem mapIdx_leafMapOf_of_sameSlots {leaves leaves' : List (Option Nat)} (h : SameSlots leaves leaves') :
    leaves.mapIdx (fun slot leaf => leaf.bind fun _ => leafMapOf leaves' slot) = leaves' := by
  apply List.ext_getElem?
  intro slot
  rw [List.getElem?_mapIdx]
  have hMap := getElem?_sameSlots h slot
  cases hl : leaves[slot]? with
  | none =>
      cases hl' : leaves'[slot]? with
      | none => rfl
      | some _ => simp [hl, hl'] at hMap
  | some x =>
      cases hl' : leaves'[slot]? with
      | none => simp [hl, hl'] at hMap
      | some y =>
          simp only [hl, hl', Option.map_some, Option.some.injEq] at hMap
          cases x with
          | none =>
              cases y with
              | none => rfl
              | some _ => simp at hMap
          | some _ =>
              cases y with
              | none => simp at hMap
              | some w => simp [leafMapOf, hl']

/-- A state is determined by its maps, its occupied slots and its leaves. -/
theorem eq_substEntry_of_sameSupport :
    ∀ {final final' : RuntimePathOramPositionMapState}, (final.map (·.1)).Nodup →
      SameSupport final final' → final' = final.map (substEntry (stateLeafMap final'))
  | _, _, _, .nil => rfl
  | (objectId, leaves) :: es, (objectId', leaves') :: es', hNodup, .cons hEntry hRest => by
      obtain ⟨hId, hSlots⟩ := hEntry
      simp only at hId hSlots
      subst hId
      simp only [List.map_cons, List.nodup_cons] at hNodup
      obtain ⟨hNotMem, hNodup⟩ := hNodup
      have hTail := eq_substEntry_of_sameSupport hNodup hRest
      simp only [List.map_cons, substEntry]
      congr 1
      · simp only [stateLeafMap_cons_eq]
        rw [mapIdx_leafMapOf_of_sameSlots hSlots]
      · refine hTail.trans (List.map_congr_left fun entry hEntry => ?_)
        have hNe : objectId ≠ entry.1 := by
          intro hEq
          exact hNotMem (hEq ▸ List.mem_map.mpr ⟨entry, hEntry, rfl⟩)
        have hAgree : ∀ slot, stateLeafMap ((objectId, leaves') :: es') (entry.1, slot) =
            stateLeafMap es' (entry.1, slot) := fun slot => stateLeafMap_cons_ne hNe
        simp only [substEntry, hAgree]

/-! ## A tape's bounds -/

theorem withinBounds_cons {b : Nat} {bs t : List Nat} (h : WithinBounds (b :: bs) t) :
    ∃ x xs, t = x :: xs ∧ x < b ∧ WithinBounds bs xs := by
  obtain ⟨hLen, hLt⟩ := h
  cases t with
  | nil => simp at hLen
  | cons x xs =>
      refine ⟨x, xs, rfl, ?_, ?_, ?_⟩
      · simpa using hLt 0 (by simp) (by simp)
      · simpa using hLen
      · intro i hi hb
        simpa using hLt (i + 1) (by simpa using hi) (by simpa using hb)

theorem mem_boundedTapes_append {as bs t : List Nat} (h : t ∈ boundedTapes (as ++ bs)) :
    WithinBounds as (t.take as.length) ∧ WithinBounds bs (t.drop as.length) := by
  rw [boundedTapes_append, List.mem_flatMap] at h
  obtain ⟨v, hv, hMem⟩ := h
  obtain ⟨w, hw, rfl⟩ := List.mem_map.mp hMem
  have hLen : v.length = as.length := (mem_boundedTapes.mp hv).1
  rw [← hLen, List.take_left' rfl, List.drop_left' rfl]
  exact ⟨mem_boundedTapes.mp hv, mem_boundedTapes.mp hw⟩

/-- The leaves a tape gives the keys present before the call are below their
maps' leaf counts. -/
theorem start_bound {lc : Nat → Nat} {present : List (Nat × Nat)} {t : List Nat}
    (h : WithinBounds (present.map fun key => lc key.1) (t.take present.length)) :
    ∀ key v, readVars t (initialVars present) key = some v → v < lc key.1 := by
  intro key v hv
  simp only [readVars] at hv
  cases hInit : initialVars present key with
  | none => simp [hInit] at hv
  | some idx =>
      simp only [hInit, Option.map_some, Option.some.injEq] at hv
      subst hv
      obtain ⟨hIdx, hKey⟩ := initialVars_eq_some hInit
      have hTakeLen : (t.take present.length).length = present.length := by simpa using h.1
      have hIdxTake : idx < (t.take present.length).length := by rw [hTakeLen]; exact hIdx
      have hIdxT : idx < t.length := by
        have := List.length_take_le present.length t
        rw [List.length_take] at hIdxTake
        omega
      have hLt := h.2 idx hIdxTake (by simpa using hIdx)
      simp only [List.getElem_take, List.getElem_map, hKey] at hLt
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hIdxT, Option.getD_some]
      exact hLt

theorem coinsOk_of_withinBounds {objects : List RuntimeOramObjectCertificate} :
    ∀ {leafs : List RuntimeOramLeafCertificate} {transitions : List RuntimePathOramTransitionCertificate}
      {coins : List Nat}, leafs.length = transitions.length →
      WithinBounds (coinBounds (leafBound objects) (transitionAccesses leafs transitions)) coins →
      CoinsOk objects leafs coins
  | [], [], _, _, _ => trivial
  | [], _ :: _, _, h, _ => by simp at h
  | _ :: _, [], _, h, _ => by simp at h
  | leaf :: leafs, transition :: transitions, coins, hLen, h => by
      simp only [transitionAccesses, coinBounds, List.flatMap_cons, List.cons_append,
        List.nil_append] at h
      obtain ⟨c₀, rest, rfl, hc₀, h⟩ := withinBounds_cons h
      obtain ⟨c₁, rest', rfl, hc₁, h⟩ := withinBounds_cons h
      exact ⟨by simpa using hc₀, by simpa using hc₁,
        coinsOk_of_withinBounds (by simpa using hLen) (by simpa [coinBounds] using h)⟩

/-! ## One run on every tape -/

/-- The keys present before a run. -/
def runPresent (w : RuntimeRefinementWitness) : List (Nat × Nat) :=
  match runtimePathOramPositionMapStateByObject w.oramPositionMapBefore w.oramObjects with
  | some state => presentKeys state
  | none => []

/-- A run's accesses, map by map. -/
def runAccesses (w : RuntimeRefinementWitness) : List MapAccess :=
  transitionAccesses w.oramLeafSchedule w.oramLeafStateTransitions

/-- **The run on another tape.** The leaves of the keys present before the run
are the tape's first coordinates, and every access reads the leaf the model
reads on the rest of the tape and takes the model's next leaf; the leaf
schedule, the transitions, the position maps before and after, and the bucket
locations of the trace move accordingly. -/
def substituteWitness (w : RuntimeRefinementWitness) (tape : List Nat) : RuntimeRefinementWitness :=
  let present := runPresent w
  let start := readVars tape (initialVars present)
  let coins := tape.drop present.length
  let steps := substSteps start w.oramLeafSchedule w.oramLeafStateTransitions coins
  let finish := (runLeaves start (liftSteps (runAccesses w)) coins).2
  { w with
    trace := substituteTrace w.trace (steps.1.map RuntimeOramLeafCertificate.toPathOramLeafScheduleStep)
    oramLeafSchedule := steps.1
    oramLeafStateTransitions := steps.2
    oramPositionMapBefore := w.oramPositionMapBefore.map (substCert start)
    oramPositionMapAfter := w.oramPositionMapAfter.map (substCert finish) }

/-- What an accepted replay says about each access's map. -/
theorem replay_objects {objects : List RuntimeOramObjectCertificate} :
    ∀ {state final : RuntimePathOramPositionMapState} {leafs : List RuntimeOramLeafCertificate}
      {transitions : List RuntimePathOramTransitionCertificate},
      replayRuntimePathOramTransitionsAux state objects leafs transitions = some final →
      leafs.length = transitions.length ∧
        ∀ leaf ∈ leafs, objectNameOf objects leaf.objectId = leaf.objectName ∧
          objectBucketCount objects leaf.objectId = leaf.bucketCount
  | _, _, [], [], _ => ⟨rfl, by simp⟩
  | _, _, [], _ :: _, h => by simp [replayRuntimePathOramTransitionsAux] at h
  | _, _, _ :: _, [], h => by simp [replayRuntimePathOramTransitionsAux] at h
  | state, final, leaf :: leafs, transition :: transitions, h => by
      simp only [replayRuntimePathOramTransitionsAux, Option.bind_eq_bind] at h
      obtain ⟨next, hApply, hRest⟩ := Option.bind_eq_some_iff.mp h
      obtain ⟨hLen, hAll⟩ := replay_objects hRest
      refine ⟨by simp [hLen], ?_⟩
      intro l hl
      rcases List.mem_cons.mp hl with rfl | hl
      · simp only [runtimePathOramApplyTransition?, Option.bind_eq_bind] at hApply
        cases hObj : runtimeOramObjectById? objects l.objectId with
        | none => simp [hObj] at hApply
        | some object =>
            simp only [hObj, Option.bind_some] at hApply
            split at hApply
            · cases hApply
            · rename_i hGuard
              simp only [Bool.or_eq_true, Bool.not_eq_true', bne_iff_ne, ne_eq, decide_eq_true_eq,
                not_or, Classical.not_not] at hGuard
              obtain ⟨⟨⟨⟨⟨⟨_, _⟩, _⟩, _⟩, hObjName⟩, hObjBucket⟩, _⟩ := hGuard
              simp [objectNameOf, objectBucketCount, hObj, hObjName, hObjBucket]
      · exact hAll l hl

theorem sameShape_substSteps (start : Nat × Nat → Option Nat) :
    ∀ (leafs : List RuntimeOramLeafCertificate) (transitions : List RuntimePathOramTransitionCertificate)
      (coins : List Nat), leafs.length = transitions.length →
      (∀ leaf ∈ leafs, UniformDepth leaf.bucketCount) →
      Forall₂ SameShape (leafs.map RuntimeOramLeafCertificate.toPathOramLeafScheduleStep)
        ((substSteps start leafs transitions coins).1.map
          RuntimeOramLeafCertificate.toPathOramLeafScheduleStep)
  | [], [], _, _, _ => .nil
  | [], _ :: _, _, h, _ => by simp at h
  | _ :: _, [], _, h, _ => by simp at h
  | leaf :: leafs, transition :: transitions, coins, hLen, hDepth => by
      simp only [substSteps, List.map_cons]
      exact .cons (sameShape_withLeaf (step := leaf.toPathOramLeafScheduleStep)
          (hDepth leaf List.mem_cons_self) _)
        (sameShape_substSteps _ leafs transitions _ (by simpa using hLen)
          (fun l hl => hDepth l (List.mem_cons_of_mem _ hl)))

theorem moves_of_bucketTrace {trace : Trace} {old new : PathOramLeafScheduleTrace}
    (hBucket : pathOramBucketTraceOfLeafScheduleTrace old = pathOramBucketTraceOfView (viewMPlus trace))
    (hShape : Forall₂ SameShape old new) :
    Forall₂ (fun event label => MovesTo (PhysicalRead.object event) label)
        (trace.physicalReads.filter isBucketRead) (pathOramBucketTraceOfLeafScheduleTrace new).readBuckets ∧
      Forall₂ (fun event label => MovesTo (PhysicalWrite.object event) label)
        (trace.physicalWrites.filter isBucketWrite)
        (pathOramBucketTraceOfLeafScheduleTrace new).writeBuckets := by
  have hReads := readBuckets_parallel hShape
  have hWrites := writeBuckets_parallel hShape
  rw [hBucket] at hReads hWrites
  simp only [pathOramBucketTraceOfView, pathOramBucketTrace, pathOramStorageLocationTrace,
    oramStorageView, viewMPlus, List.filter_map] at hReads hWrites
  have hReads' := Forall₂.of_map_left pathOramPhysicalReadLabel hReads
  have hWrites' := Forall₂.of_map_left pathOramPhysicalWriteLabel hWrites
  exact ⟨hReads', hWrites'⟩

theorem reconstructObserved_substitute (trace : Trace) (schedule : PathOramLeafScheduleTrace)
    (objects : List RuntimeOramObjectCertificate) :
    reconstructObservedOramAccessesFromLogicalTrace (substituteTrace trace schedule).logicalAccesses objects =
      reconstructObservedOramAccessesFromLogicalTrace trace.logicalAccesses objects := by
  unfold reconstructObservedOramAccessesFromLogicalTrace
  simp only [substituteTrace, length_replaceInOrder]
  exact reconstructObserved_logicalShape objects _ _ _
    (logicalShape_substitute _ _ (readDetails_bucket schedule))

theorem reconstructScaffold_substitute (trace : Trace) (schedule : PathOramLeafScheduleTrace)
    (objects : List RuntimeOramObjectCertificate) :
    reconstructPathOramLeafScaffoldFromLogicalTrace (substituteTrace trace schedule).logicalAccesses objects =
      reconstructPathOramLeafScaffoldFromLogicalTrace trace.logicalAccesses objects := by
  unfold reconstructPathOramLeafScaffoldFromLogicalTrace
  simp only [substituteTrace, length_replaceInOrder]
  exact reconstructScaffold_logicalShape objects _ _ _
    (logicalShape_substitute _ _ (readDetails_bucket schedule))

/-- The facts about a valid run that its substitution needs. -/
structure SubstitutionFacts (w : RuntimeRefinementWitness) where
  state : RuntimePathOramPositionMapState
  final : RuntimePathOramPositionMapState
  before : runtimePathOramPositionMapStateByObject w.oramPositionMapBefore w.oramObjects = some state
  after : runtimePathOramPositionMapStateByObject w.oramPositionMapAfter w.oramObjects = some final
  replay : replayRuntimePathOramTransitionsAux state w.oramObjects w.oramLeafSchedule
    w.oramLeafStateTransitions = some final

theorem substitutionFacts {w : RuntimeRefinementWitness} {modelTags : SGXModelTags}
    (hValid : w.Valid modelTags) : Nonempty (SubstitutionFacts w) := by
  obtain ⟨_, _, _, _, _, _, hReplayEq, hReplaySome, _⟩ := hValid
  obtain ⟨final, hRep⟩ := Option.isSome_iff_exists.mp hReplaySome
  have hAfter : runtimePathOramPositionMapStateByObject w.oramPositionMapAfter w.oramObjects = some final := by
    have := hReplayEq.symm.trans hRep
    exact this
  have hRep' := hRep
  simp only [RuntimeRefinementWitness.replayedPathOramPositionMapState, replayRuntimePathOramTransitions,
    Option.bind_eq_bind] at hRep'
  obtain ⟨state, hState, hReplayAux⟩ := Option.bind_eq_some_iff.mp hRep'
  exact ⟨⟨state, final, hState, hAfter, hReplayAux⟩⟩

set_option maxHeartbeats 1000000 in
/-- **Every substituted run is a valid runtime witness.** -/
theorem substituteWitness_valid {w : RuntimeRefinementWitness} {modelTags : SGXModelTags}
    (hValid : w.Valid modelTags)
    (hNodup : (w.oramObjects.map (·.objectId)).Nodup)
    (hDepth : ∀ leaf ∈ w.oramLeafSchedule, UniformDepth leaf.bucketCount)
    {tape : List Nat}
    (hTape : tape ∈ callTapes (objectBucketCount w.oramObjects) (runPresent w) (runAccesses w)) :
    (substituteWitness w tape).Valid modelTags := by
  obtain ⟨facts⟩ := substitutionFacts hValid
  obtain ⟨state, final, hState, hAfter, hReplayAux⟩ := facts
  obtain ⟨hGas, hBoundary, hController, hObserved, hScaffold, hPublicScaffold, _, _, hBucket, hMicro,
    hKernel, hKernelRef⟩ := hValid
  obtain ⟨hLen, _⟩ := replay_objects hReplayAux
  have hPresent : runPresent w = presentKeys state := by simp [runPresent, hState]
  have hStateNodup := nodup_byObject hNodup hState
  have hFinalNodup := nodup_byObject hNodup hAfter
  have hStartSome : ∀ key, (readVars tape (initialVars (runPresent w)) key).isSome =
      (stateLeafMap state key).isSome := by
    intro key
    rw [hPresent]
    simp only [readVars, initialVars]
    by_cases hMem : key ∈ presentKeys state
    · simp [hMem, (mem_presentKeys_iff hStateNodup key).mp hMem]
    · have hNone : (stateLeafMap state key).isSome = false := by
        cases h : (stateLeafMap state key).isSome with
        | false => rfl
        | true => exact absurd ((mem_presentKeys_iff hStateNodup key).mpr h) hMem
      simp [hMem, hNone]
  have hStartMap : stateLeafMap (state.map (substEntry (readVars tape (initialVars (runPresent w))))) =
      readVars tape (initialVars (runPresent w)) := by
    funext key
    rw [stateLeafMap_substEntry]
    cases h : stateLeafMap state key with
    | none =>
        have := hStartSome key
        rw [h] at this
        cases hs : readVars tape (initialVars (runPresent w)) key with
        | none => rfl
        | some _ => rw [hs] at this; cases this
    | some v => rfl
  have hParts := mem_boundedTapes_append hTape
  have hPresentBounds : WithinBounds ((runPresent w).map fun key => leafBound w.oramObjects key.1)
      (tape.take (runPresent w).length) := by
    have := hParts.1
    simp only [List.length_map] at this
    exact this
  have hStartBound : ∀ key v, readVars tape (initialVars (runPresent w)) key = some v →
      v < leafBound w.oramObjects key.1 := start_bound hPresentBounds
  have hCoins : CoinsOk w.oramObjects w.oramLeafSchedule (tape.drop (runPresent w).length) :=
    coinsOk_of_withinBounds hLen (by simpa [runAccesses, List.length_map] using hParts.2)
  have hSupp : SameSupport state (state.map (substEntry (readVars tape (initialVars (runPresent w))))) :=
    sameSupport_substEntry hStateNodup (fun key h => by rw [hStartSome]; exact h)
  have hBounded : Bounded w.oramObjects
      (state.map (substEntry (readVars tape (initialVars (runPresent w))))) := by
    intro key v hv
    rw [hStartMap] at hv
    exact hStartBound key v hv
  obtain ⟨final', hReplay', hSuppFinal, hBoundFinal, hMapFinal⟩ :=
    replay_substSteps hReplayAux hSupp hBounded hCoins
  rw [hStartMap] at hReplay' hMapFinal
  have hFinal' : final' = final.map (substEntry (runLeaves (readVars tape (initialVars (runPresent w)))
      (liftSteps (runAccesses w)) (tape.drop (runPresent w).length)).2) := by
    rw [eq_substEntry_of_sameSupport hFinalNodup hSuppFinal, hMapFinal]
    rfl
  have hBefore' := byObject_substCert (readVars tape (initialVars (runPresent w))) hNodup
    (fun objectId slot v hv => hStartBound (objectId, slot) v hv) hState
  have hAfter' := byObject_substCert (runLeaves (readVars tape (initialVars (runPresent w)))
      (liftSteps (runAccesses w)) (tape.drop (runPresent w).length)).2 hNodup
    (fun objectId slot v hv => by
      have := hBoundFinal (objectId, slot) v (by rw [hMapFinal]; exact hv)
      exact this) hAfter
  have hShapes := sameShape_substSteps (readVars tape (initialVars (runPresent w))) w.oramLeafSchedule
    w.oramLeafStateTransitions (tape.drop (runPresent w).length) hLen hDepth
  obtain ⟨hReads, hWrites⟩ := moves_of_bucketTrace hBucket hShapes
  refine ⟨hGas, hBoundary, hController, ?_, ?_, ?_, ?_, ?_, ?_, hMicro, hKernel, hKernelRef⟩
  · show reconstructObservedOramAccessesFromLogicalTrace (substituteTrace _ _).logicalAccesses _ = _
    rw [reconstructObserved_substitute]
    exact hObserved
  · show reconstructPathOramLeafScaffoldFromLogicalTrace (substituteTrace _ _).logicalAccesses
        w.oramObjects = some (RuntimeRefinementWitness.pathOramLeafScaffold (substituteWitness w tape))
    rw [reconstructScaffold_substitute, hScaffold]
    simp only [RuntimeRefinementWitness.pathOramLeafScaffold, substituteWitness]
    rw [substSteps_scaffold _ _ _ _ hLen]
  · simp only [substituteWitness, RuntimeRefinementWitness.pathOramLeafScaffold]
    rw [substSteps_scaffold _ _ _ _ hLen, hPublicScaffold]
    rfl
  · show replayRuntimePathOramTransitions _ _ _ _ = runtimePathOramPositionMapStateByObject _ _
    simp only [substituteWitness, replayRuntimePathOramTransitions, Option.bind_eq_bind]
    rw [hBefore', hAfter', Option.bind_some, hReplay', hFinal']
  · show (replayRuntimePathOramTransitions _ _ _ _).isSome = true
    simp only [substituteWitness, replayRuntimePathOramTransitions, Option.bind_eq_bind]
    rw [hBefore', Option.bind_some, hReplay']
    rfl
  · show pathOramBucketTraceOfLeafScheduleTrace _ = pathOramBucketTraceOfView (viewMPlus (substituteTrace _ _))
    exact (bucketTrace_substituteTrace _ _ hReads hWrites).symm

/-! ## A valid run gives a tape family -/

theorem substituteWitness_leafValues (w : RuntimeRefinementWitness) (tape : List Nat) :
    pathOramLeafValues (substituteWitness w tape).pathOramLeafScheduleTrace =
      observedLeaves (runPresent w) (liftSteps (runAccesses w)) tape := by
  simp only [substituteWitness, RuntimeRefinementWitness.pathOramLeafScheduleTrace, pathOramLeafValues,
    List.map_map]
  exact substSteps_leaves _ _ _ _

theorem map_transitionAccesses {β : Type} (f : Nat → β) :
    ∀ (leafs : List RuntimeOramLeafCertificate) (transitions : List RuntimePathOramTransitionCertificate),
      leafs.length = transitions.length →
      (transitionAccesses leafs transitions).map (fun access => f access.1) =
        leafs.map fun leaf => f leaf.objectId
  | [], [], _ => rfl
  | [], _ :: _, h => by simp at h
  | _ :: _, [], h => by simp at h
  | leaf :: leafs, transition :: transitions, h => by
      simp only [transitionAccesses, List.map_cons]
      rw [map_transitionAccesses f leafs transitions (by simpa using h)]

/-- A valid run's public leaf scaffold is the scaffold of its accesses. -/
theorem publicScaffold_eq_callScaffold {w : RuntimeRefinementWitness} {modelTags : SGXModelTags}
    (hValid : w.Valid modelTags) :
    w.projectedPublicPathOramLeafScaffold =
      callScaffold (objectNameOf w.oramObjects) (objectBucketCount w.oramObjects) (runAccesses w) := by
  obtain ⟨facts⟩ := substitutionFacts hValid
  obtain ⟨hLen, hObjects⟩ := replay_objects facts.replay
  have hPublic := hValid.2.2.2.2.2.1
  simp only [RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold, hPublic,
    RuntimeRefinementWitness.pathOramLeafScaffold, callScaffold, runAccesses, List.map_map]
  rw [map_transitionAccesses (fun map => (objectNameOf w.oramObjects map, objectBucketCount w.oramObjects map))
    _ _ hLen]
  apply List.map_congr_left
  intro leaf hLeaf
  obtain ⟨hName, hBucket⟩ := hObjects leaf hLeaf
  simp [RuntimeOramLeafCertificate.scaffoldStep,
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep, hName, hBucket]

/-- **A valid run gives a tape family**: the run on every tape is its
substitution. -/
def toTapeFamily (w : RuntimeRefinementWitness) {modelTags : SGXModelTags} (hValid : w.Valid modelTags)
    (hNodup : (w.oramObjects.map (·.objectId)).Nodup)
    (hDepth : ∀ leaf ∈ w.oramLeafSchedule, UniformDepth leaf.bucketCount) :
    TapeRuntimePathOramWitnessFamily modelTags :=
  { name := objectNameOf w.oramObjects
    bucketCount := objectBucketCount w.oramObjects
    present := runPresent w
    accesses := runAccesses w
    witnessAt := substituteWitness w
    valid := fun _ hTape => substituteWitness_valid hValid hNodup hDepth hTape
    publicLeafScaffoldExact := fun _ _ => publicScaffold_eq_callScaffold hValid
    followsModel := fun tape _ => substituteWitness_leafValues w tape }

theorem substituteWitness_publicView (w : RuntimeRefinementWitness) (tape : List Nat) :
    pathOramViewPublicPart (viewMPlus (substituteWitness w tape).trace) =
      pathOramViewPublicPart (viewMPlus w.trace) :=
  pathOramViewPublicPart_substituteTrace _ _

theorem substituteWitness_storageShape (w : RuntimeRefinementWitness) (tape : List Nat) :
    pathOramStorageShape (oramStorageView (viewMPlus (substituteWitness w tape).trace)) =
      pathOramStorageShape (oramStorageView (viewMPlus w.trace)) :=
  pathOramStorageShape_substituteTrace _ _

theorem substituteWitness_publicLocation {w : RuntimeRefinementWitness} {modelTags : SGXModelTags}
    (hValid : w.Valid modelTags) (hDepth : ∀ leaf ∈ w.oramLeafSchedule, UniformDepth leaf.bucketCount)
    (tape : List Nat) :
    pathOramPublicLocationTrace
        (pathOramStorageLocationTrace (oramStorageView (viewMPlus (substituteWitness w tape).trace))) =
      pathOramPublicLocationTrace (pathOramStorageLocationTrace (oramStorageView (viewMPlus w.trace))) := by
  obtain ⟨facts⟩ := substitutionFacts hValid
  obtain ⟨hLen, _⟩ := replay_objects facts.replay
  have hShapes := sameShape_substSteps (readVars tape (initialVars (runPresent w))) w.oramLeafSchedule
    w.oramLeafStateTransitions (tape.drop (runPresent w).length) hLen hDepth
  obtain ⟨hReads, hWrites⟩ := moves_of_bucketTrace hValid.2.2.2.2.2.2.2.2.1 hShapes
  exact pathOramPublicLocationTrace_substituteTrace _ _ hReads hWrites

/-! ## A pair of runs gives the theorem over its two sides -/

/-- Two valid runs of one public configuration, the pair's sides, that show
the same public view, public locations, storage shape, outcome and boundary
schedule. -/
structure TapePair (modelTags : SGXModelTags) where
  cfg : OramConfig
  lhs : RuntimeRefinementWitness
  rhs : RuntimeRefinementWitness
  lhsValid : lhs.Valid modelTags
  rhsValid : rhs.Valid modelTags
  lhsNodup : (lhs.oramObjects.map (·.objectId)).Nodup
  rhsNodup : (rhs.oramObjects.map (·.objectId)).Nodup
  lhsDepth : ∀ leaf ∈ lhs.oramLeafSchedule, UniformDepth leaf.bucketCount
  rhsDepth : ∀ leaf ∈ rhs.oramLeafSchedule, UniformDepth leaf.bucketCount
  cfgWellFormed : PathOramConfigWellFormed cfg
  lhsMatch : lhs.ObjectsMatchPublicConfig cfg
  rhsMatch : rhs.ObjectsMatchPublicConfig cfg
  samePublicView :
    pathOramViewPublicPart (viewMPlus lhs.trace) = pathOramViewPublicPart (viewMPlus rhs.trace)
  samePublicLocation :
    pathOramPublicLocationTrace (pathOramStorageLocationTrace (oramStorageView (viewMPlus lhs.trace))) =
      pathOramPublicLocationTrace (pathOramStorageLocationTrace (oramStorageView (viewMPlus rhs.trace)))
  sameStorageShape :
    pathOramStorageShape (oramStorageView (viewMPlus lhs.trace)) =
      pathOramStorageShape (oramStorageView (viewMPlus rhs.trace))
  samePublicOutcome : lhs.publicOutcome = rhs.publicOutcome
  sameBoundary : lhs.boundarySchedule = rhs.boundarySchedule

namespace TapePair

variable {modelTags : SGXModelTags} (pair : TapePair modelTags)

def lhsCfg : OramConfig := pairSideCfg pair.cfg "lhs"

def rhsCfg : OramConfig := pairSideCfg pair.cfg "rhs"

/-- A pair admits its two sides. -/
def Admitted (cfg : OramConfig) : Prop := cfg = pair.lhsCfg ∨ cfg = pair.rhsCfg

theorem lhsCfg_ne_rhsCfg : pair.lhsCfg ≠ pair.rhsCfg := by
  intro h
  have hArgs := congrArg OramConfig.secretArgs h
  simp [lhsCfg, rhsCfg, pairSideCfg] at hArgs

theorem admittedSamePublic_sides : AdmittedSamePublic pair.Admitted pair.lhsCfg pair.rhsCfg :=
  ⟨Or.inl rfl, Or.inr rfl, rfl⟩

def lhsFamily : TapeRuntimePathOramWitnessFamily modelTags :=
  toTapeFamily pair.lhs pair.lhsValid pair.lhsNodup pair.lhsDepth

def rhsFamily : TapeRuntimePathOramWitnessFamily modelTags :=
  toTapeFamily pair.rhs pair.rhsValid pair.rhsNodup pair.rhsDepth

/-- Each side's runs. -/
def sideFamily (cfg : OramConfig) : TapeRuntimePathOramWitnessFamily modelTags :=
  if cfg = pair.rhsCfg then pair.rhsFamily else pair.lhsFamily

theorem sideFamily_lhs : pair.sideFamily pair.lhsCfg = pair.lhsFamily := if_neg pair.lhsCfg_ne_rhsCfg

theorem sideFamily_rhs : pair.sideFamily pair.rhsCfg = pair.rhsFamily := if_pos rfl

/-- A property of the runs of both sides on every tape holds of each admitted
side's runs. -/
theorem side_cases {cfg : OramConfig} (h : pair.Admitted cfg)
    (P : RuntimeRefinementWitness → Prop)
    (hLhs : ∀ tape, P (substituteWitness pair.lhs tape))
    (hRhs : ∀ tape, P (substituteWitness pair.rhs tape)) :
    ∀ tape ∈ (pair.sideFamily cfg).tapes, P ((pair.sideFamily cfg).witnessAt tape) := by
  rcases h with rfl | rfl
  · rw [sideFamily_lhs]; exact fun tape _ => hLhs tape
  · rw [sideFamily_rhs]; exact fun tape _ => hRhs tape

/-- **The tape-family evidence of a pair**: every tape's run on each side, from
the side's one run. -/
def toEvidence : TapePathOramPaperMainEvidenceOn modelTags pair.Admitted :=
  { tapeFamily := pair.sideFamily
    cfgWellFormed := fun cfg h => by rcases h with rfl | rfl <;> exact pair.cfgWellFormed
    publicView := fun _ => pathOramViewPublicPart (viewMPlus pair.lhs.trace)
    publicViewExact := fun cfg h =>
      pair.side_cases h (fun w => pathOramViewPublicPart (viewMPlus w.trace) =
          pathOramViewPublicPart (viewMPlus pair.lhs.trace))
        (fun tape => substituteWitness_publicView _ tape)
        (fun tape => (substituteWitness_publicView _ tape).trans pair.samePublicView.symm)
    publicViewSafe := fun _ _ _ => rfl
    objectsMatchPublicConfig := fun cfg h => by
      rcases h with rfl | rfl
      · rw [sideFamily_lhs]; exact fun _ _ => pair.lhsMatch
      · rw [sideFamily_rhs]; exact fun _ _ => pair.rhsMatch
    publicLocation := fun _ =>
      pathOramPublicLocationTrace (pathOramStorageLocationTrace (oramStorageView (viewMPlus pair.lhs.trace)))
    publicLocationExact := fun cfg h =>
      pair.side_cases h (fun w =>
          pathOramPublicLocationTrace (pathOramStorageLocationTrace (oramStorageView (viewMPlus w.trace))) =
            pathOramPublicLocationTrace
              (pathOramStorageLocationTrace (oramStorageView (viewMPlus pair.lhs.trace))))
        (fun tape => substituteWitness_publicLocation pair.lhsValid pair.lhsDepth tape)
        (fun tape => (substituteWitness_publicLocation pair.rhsValid pair.rhsDepth tape).trans
          pair.samePublicLocation.symm)
    publicLocationSafe := fun _ _ _ => rfl
    storageShape := fun _ => pathOramStorageShape (oramStorageView (viewMPlus pair.lhs.trace))
    storageShapeExact := fun cfg h =>
      pair.side_cases h (fun w => pathOramStorageShape (oramStorageView (viewMPlus w.trace)) =
          pathOramStorageShape (oramStorageView (viewMPlus pair.lhs.trace)))
        (fun tape => substituteWitness_storageShape _ tape)
        (fun tape => (substituteWitness_storageShape _ tape).trans pair.sameStorageShape.symm)
    storageShapeSafe := fun _ _ _ => rfl
    publicOutcome := fun _ => pair.lhs.publicOutcome
    publicOutcomeExact := fun cfg h =>
      pair.side_cases h (fun w => w.publicOutcome = pair.lhs.publicOutcome)
        (fun _ => rfl) (fun _ => pair.samePublicOutcome.symm)
    publicOutcomeSafe := fun _ _ _ => rfl
    boundarySchedule := fun _ => pair.lhs.boundarySchedule
    boundaryExact := fun cfg h =>
      pair.side_cases h (fun w => w.boundarySchedule = pair.lhs.boundarySchedule)
        (fun _ => rfl) (fun _ => pair.sameBoundary.symm)
    boundarySafe := fun _ _ _ => rfl }

/-- **The theorem at the pair's two sides, without seed enumeration.** The
SGX execution relation holds between the two sides' runs, over every tape of
each side's call. -/
theorem sgxViewRelation_sides (assumptions : PathOramLocalPosmapV1SecurityAssumptions) :
    SGXViewRelation
      (pathOramLocalPosmapV1NormalizedObservedSGXProofRelation assumptions)
      ((oramToSGXSemantics pair.toEvidence.toBundle.run pair.toEvidence.publicOutcome
        pair.toEvidence.boundarySchedule oramControllerMicroTrace) pair.lhsCfg)
      ((oramToSGXSemantics pair.toEvidence.toBundle.run pair.toEvidence.publicOutcome
        pair.toEvidence.boundarySchedule oramControllerMicroTrace) pair.rhsCfg)
      (executionLeakage pair.lhsCfg)
      (oramMicroLeakage pair.toEvidence.publicOutcome modelTags pair.lhsCfg) :=
  pair.toEvidence.toBundle.paperMainSgxExecution assumptions.toCanonicalLeafValueSecurityAssumptions
    pair.lhsCfg pair.rhsCfg pair.admittedSamePublic_sides

/-- The left side's runs are its tape family's, one per canonical schedule. -/
theorem run_lhs : pair.toEvidence.toBundle.run pair.lhsCfg = pair.lhsFamily.toSeeded.viewDistribution := by
  show (pair.sideFamily pair.lhsCfg).toSeeded.viewDistribution = _
  rw [sideFamily_lhs]

theorem run_rhs : pair.toEvidence.toBundle.run pair.rhsCfg = pair.rhsFamily.toSeeded.viewDistribution := by
  show (pair.sideFamily pair.rhsCfg).toSeeded.viewDistribution = _
  rw [sideFamily_rhs]

end TapePair

/-! ## From the runtime's theorem input -/

/-- What a tape family needs of a run beyond validity: distinct object ids, and
every leaf of each tree the run touches at the same depth. -/
def tapeWitnessCheck (w : RuntimeRefinementWitness) : Bool :=
  decide (w.oramObjects.map (·.objectId)).Nodup &&
    w.oramLeafSchedule.all fun leaf => uniformDepthCheck leaf.bucketCount

theorem tapeWitnessCheck_sound {w : RuntimeRefinementWitness} (h : tapeWitnessCheck w = true) :
    (w.oramObjects.map (·.objectId)).Nodup ∧ ∀ leaf ∈ w.oramLeafSchedule, UniformDepth leaf.bucketCount := by
  simp only [tapeWitnessCheck, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h
  exact ⟨h.1, fun leaf hLeaf => uniformDepth_of_check (h.2 leaf hLeaf)⟩

/-- **The runtime's theorem input gives a tape pair**: its two representative
runs, checked valid, with the public values the input checks. -/
def tapePairOfTheoremInput (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
    {modelTags : SGXModelTags} (hValid : input.Valid modelTags)
    (hLhs : tapeWitnessCheck input.lhs_input.runtimeRepresentativeWitness = true)
    (hRhs : tapeWitnessCheck input.rhs_input.runtimeRepresentativeWitness = true) :
    TapePair modelTags :=
  { cfg := input.runtimeCfg
    lhs := input.lhs_input.runtimeRepresentativeWitness
    rhs := input.rhs_input.runtimeRepresentativeWitness
    lhsValid := hValid.2.1.1.1.1
    rhsValid := hValid.2.2.1.1.1
    lhsNodup := (tapeWitnessCheck_sound hLhs).1
    rhsNodup := (tapeWitnessCheck_sound hRhs).1
    lhsDepth := (tapeWitnessCheck_sound hLhs).2
    rhsDepth := (tapeWitnessCheck_sound hRhs).2
    cfgWellFormed := hValid.1
    lhsMatch := hValid.2.1.2.1
    rhsMatch := hValid.2.2.2.1
    samePublicView := hValid.2.1.2.2.1.trans hValid.2.2.2.2.1.symm
    samePublicLocation := hValid.2.1.2.2.2.1.trans hValid.2.2.2.2.2.1.symm
    sameStorageShape := hValid.2.1.2.2.2.2.1.trans hValid.2.2.2.2.2.2.1.symm
    samePublicOutcome := hValid.2.1.2.2.2.2.2.1.trans hValid.2.2.2.2.2.2.2.1.symm
    sameBoundary := hValid.2.1.2.2.2.2.2.2.1.trans hValid.2.2.2.2.2.2.2.2.1.symm }

/-! ## Checking runtime runs against a tape family -/

/-- The tape of another run of the same call: the leaves of the
representative's present keys before the run, then the run's recorded coins
(the leaf each access read and its next leaf). -/
def sampleTape (w sample : RuntimeRefinementWitness) : List Nat :=
  let leafOf : Nat × Nat → Option Nat :=
    match runtimePathOramPositionMapStateByObject sample.oramPositionMapBefore sample.oramObjects with
    | some state => stateLeafMap state
    | none => fun _ => none
  (runPresent w).map (fun key => (leafOf key).getD 0) ++
    recordedCoins sample.oramLeafSchedule sample.oramLeafStateTransitions

def withinBoundsCheck (bounds tape : List Nat) : Bool :=
  tape.length == bounds.length && (List.zip tape bounds).all fun pair => decide (pair.1 < pair.2)

theorem withinBoundsCheck_sound {bounds tape : List Nat} (h : withinBoundsCheck bounds tape = true) :
    WithinBounds bounds tape := by
  simp only [withinBoundsCheck, Bool.and_eq_true, beq_iff_eq, List.all_eq_true,
    decide_eq_true_eq] at h
  obtain ⟨hLen, hAll⟩ := h
  refine ⟨hLen, fun i hi hb => ?_⟩
  have hMem : (tape[i], bounds[i]) ∈ List.zip tape bounds := by
    rw [List.mem_iff_getElem]
    exact ⟨i, by simp only [List.length_zip]; omega, by simp⟩
  exact hAll _ hMem

/-- A sampled runtime run is the representative's run on the sample's own tape,
up to its seed tag. -/
def sampleCheck (w sample : RuntimeRefinementWitness) : Bool :=
  withinBoundsCheck (multiBounds (leafBound w.oramObjects) (runPresent w) (runAccesses w))
      (sampleTape w sample) &&
    decide ({ sample with runtimeSeed := w.runtimeSeed } = substituteWitness w (sampleTape w sample))

/-- **A checked sample is a member of the tape family.** -/
theorem sampleCheck_sound {w sample : RuntimeRefinementWitness} (h : sampleCheck w sample = true) :
    ∃ tape ∈ callTapes (objectBucketCount w.oramObjects) (runPresent w) (runAccesses w),
      { sample with runtimeSeed := w.runtimeSeed } = substituteWitness w tape := by
  simp only [sampleCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨sampleTape w sample, mem_boundedTapes.mpr (withinBoundsCheck_sound h.1), h.2⟩

/-- Every sample checked against a family is the family's run on some tape. -/
theorem samplesCheck_sound {w : RuntimeRefinementWitness} {samples : List RuntimeRefinementWitness}
    (h : samples.all (sampleCheck w) = true) :
    ∀ sample ∈ samples, ∃ tape ∈ callTapes (objectBucketCount w.oramObjects) (runPresent w) (runAccesses w),
      { sample with runtimeSeed := w.runtimeSeed } = substituteWitness w tape := by
  intro sample hSample
  exact sampleCheck_sound ((List.all_eq_true.mp h) sample hSample)

end PathOramTapeWitness

end UOToolchain
