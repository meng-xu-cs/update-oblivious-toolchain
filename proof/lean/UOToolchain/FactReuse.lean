/-!
# Fact reuse

A call on a Path ORAM map writes the map only when it commits. What a lookup
finds about the committed map, a key's value and, on the private scheme, its
presence, is therefore the same at every lookup of that key during the call:
the call's own writes are pending, and a read applies them over what the
lookup found. A lookup is a get of a Path ORAM map, or the get that a write
to a private-scheme map makes to find whether its key is present.

A lookup reuses the fact an earlier lookup of the same map found when the
program shows the two keys equal: equal key expressions, built only from
variables, literals and pure operators, none of whose variables is bound
again in between (`uo_core::fact_reuse`). The plan reads only the program.

This file states the rule over a straight-line program's events and proves
two things of it:

* `run_plan`: the lookups a run makes and the facts it reuses are the plan's,
  for every environment and every value bound: the schedule of a call's
  lookups is a function of the program;
* `run_reuse_sound`: a lookup that reuses a fact has, in every run, the key
  that the lookup which found the fact had, so it returns what a fresh lookup
  would.
-/

namespace UOToolchain.FactReuse

/-- A key expression the rule can compare: its canonical text and the
variables it reads. -/
structure FactKey where
  text : String
  vars : List String
deriving DecidableEq, Repr

/-- One step of a straight-line program, in evaluation order: a lookup of a
map under a key the rule can compare or not, or a variable bound. -/
inductive Event where
  | lookup (objectId : Nat) (key : Option FactKey)
  | bind (var : String)
deriving Repr

/-- A fact a lookup found: its map, its key, and whether every variable of
the key is still bound as it was at the lookup. -/
structure Fact where
  objectId : Nat
  key : Option FactKey
  valid : Bool
deriving Repr

/-- Whether a fact may serve a lookup of `objectId` under `key`. -/
def serves (objectId : Nat) (key : FactKey) (fact : Fact) : Bool :=
  fact.objectId == objectId && fact.valid && fact.key == some key

/-- The index of the last element satisfying `p`. -/
def findLastIdx? {α : Type} (p : α → Bool) (xs : List α) : Option Nat :=
  (xs.zipIdx.filter (fun entry => p entry.1)).getLast?.map (·.2)

/-- The fact a lookup reuses: the latest that may serve it. -/
def reusable (facts : List Fact) (objectId : Nat) : Option FactKey → Option Nat
  | none => none
  | some key => findLastIdx? (serves objectId key) facts

/-- A bind makes every fact whose key reads the variable invalid. -/
def forget (var : String) (fact : Fact) : Fact :=
  { fact with valid := fact.valid && !(fact.key.any (fun key => key.vars.contains var)) }

/-- The plan's state: the facts found so far, and for each lookup so far
the fact it reuses (`none`: it is made, and finds a new fact). -/
def step (state : List Fact × List (Option Nat)) : Event → List Fact × List (Option Nat)
  | .lookup objectId key =>
      match reusable state.1 objectId key with
      | some index => (state.1, state.2 ++ [some index])
      | none =>
          (state.1 ++ [{ objectId := objectId, key := key, valid := key.isSome }],
            state.2 ++ [none])
  | .bind var => (state.1.map (forget var), state.2)

/-- For each lookup, in order, the fact it reuses or `none`. -/
def plan (events : List Event) : List (Option Nat) :=
  (events.foldl step ([], [])).2

/-- The lookups of each map that reuse a fact. -/
def reuseCount (events : List Event) (objectId : Nat) : Nat :=
  let lookups := events.filterMap fun
    | .lookup id _ => some id
    | .bind _ => none
  ((lookups.zip (plan events)).filter
      (fun entry => entry.1 == objectId && entry.2.isSome)).length

/-! ### Runs

A run gives each variable a value; a bind gives its variable the next of a
list of values, which may be anything, secret ones included. A key evaluates
under the run's values, depending on its variables alone. -/

/-- How keys evaluate: by their variables' values alone. Two equal keys have
the same text and so evaluate alike. -/
structure KeySemantics (W K : Type) where
  eval : FactKey → (String → W) → K
  depends : ∀ key env env',
    (∀ var ∈ key.vars, env var = env' var) → eval key env = eval key env'

variable {W K : Type} [DecidableEq K]

/-- A fact a run found, with its key's value at the lookup that found it. -/
structure RunFact (K : Type) where
  fact : Fact
  keyValue : Option K

/-- A run's state: the values of the variables, the facts found, for each
lookup the fact it reused and its key's value, and for each lookup that
reused a fact whether the fact was found under the lookup's key. -/
structure RunState (W K : Type) where
  env : String → W
  facts : List (RunFact K)
  reuses : List (Option Nat)
  keys : List (Option K)
  agreements : List Bool

/-- One step of a run. A bind consumes the next value (any value at all, once
the list runs out: the first of `fallback`). -/
def runStep (sem : KeySemantics W K) (fallback : W) :
    RunState W K × List W → Event → RunState W K × List W
  | (state, values), .lookup objectId key =>
      let keyValue := key.map (fun key => sem.eval key state.env)
      match reusable (state.facts.map (·.fact)) objectId key with
      | some index =>
          ({ state with reuses := state.reuses ++ [some index],
                        keys := state.keys ++ [keyValue],
                        agreements := state.agreements ++
                          [(state.facts[index]?).any (fun runFact => decide (runFact.keyValue = keyValue))] },
            values)
      | none =>
          ({ state with
              facts := state.facts ++
                [{ fact := { objectId := objectId, key := key, valid := key.isSome },
                   keyValue := keyValue }],
              reuses := state.reuses ++ [none],
              keys := state.keys ++ [keyValue] }, values)
  | (state, values), .bind var =>
      let value := values.headD fallback
      ({ state with
          env := fun name => if name = var then value else state.env name,
          facts := state.facts.map (fun runFact => { runFact with fact := forget var runFact.fact }) },
        values.tail)

/-- A run of the events from the variables' values `env` and the bound
values `values`. -/
def run (sem : KeySemantics W K) (fallback : W) (env : String → W) (values : List W)
    (events : List Event) : RunState W K :=
  (events.foldl (runStep sem fallback)
    ({ env := env, facts := [], reuses := [], keys := [], agreements := [] }, values)).1

/-! ### The schedule is the plan's -/

theorem runStep_facts_reuses (sem : KeySemantics W K) (fallback : W)
    (state : RunState W K) (values : List W) (event : Event) :
    let next := (runStep sem fallback (state, values) event).1
    (next.facts.map (·.fact), next.reuses) = step (state.facts.map (·.fact), state.reuses) event := by
  cases event with
  | lookup objectId key =>
      simp only [runStep, step]
      cases reusable (state.facts.map (·.fact)) objectId key <;> simp
  | bind var =>
      simp [runStep, step, List.map_map, Function.comp_def]

theorem foldl_run_facts_reuses (sem : KeySemantics W K) (fallback : W) :
    ∀ (events : List Event) (current : RunState W K × List W),
      let final := (events.foldl (runStep sem fallback) current).1
      (final.facts.map (·.fact), final.reuses) =
        events.foldl step (current.1.facts.map (·.fact), current.1.reuses)
  | [], _ => by simp
  | event :: rest, (state, values) => by
      simp only [List.foldl_cons]
      have hstep := runStep_facts_reuses sem fallback state values event
      have hrest := foldl_run_facts_reuses sem fallback rest
        (runStep sem fallback (state, values) event)
      simp only at hrest hstep
      rw [hrest, hstep]

/-- The lookups a run makes and the facts it reuses are the plan's, whatever
the variables' values and the values bound: the schedule of a call's lookups
is a function of the program. -/
theorem run_plan (sem : KeySemantics W K) (fallback : W) (env : String → W)
    (values : List W) (events : List Event) :
    (run sem fallback env values events).reuses = plan events := by
  have h := foldl_run_facts_reuses sem fallback events
    ({ env := env, facts := [], reuses := [], keys := [], agreements := [] }, values)
  simp only [run, plan]
  exact congrArg Prod.snd h

/-- Two runs make the same lookups and reuse the same facts. -/
theorem run_schedule_independent (sem : KeySemantics W K) (fallback : W)
    (env env' : String → W) (values values' : List W) (events : List Event) :
    (run sem fallback env values events).reuses =
      (run sem fallback env' values' events).reuses := by
  rw [run_plan, run_plan]

/-! ### A reused fact is the fact a fresh lookup would find -/

/-- What the run keeps true: every valid fact's key evaluates, under the
current values, to the value it had when the fact was found. -/
def Consistent (sem : KeySemantics W K) (state : RunState W K) : Prop :=
  ∀ runFact ∈ state.facts, ∀ key, runFact.fact.valid = true → runFact.fact.key = some key →
    runFact.keyValue = some (sem.eval key state.env)

theorem findLastIdx?_spec {α : Type} (p : α → Bool) (xs : List α) (index : Nat)
    (h : findLastIdx? p xs = some index) :
    ∃ x, xs[index]? = some x ∧ p x = true := by
  unfold findLastIdx? at h
  simp only [Option.map_eq_some_iff] at h
  obtain ⟨entry, hlast, hindex⟩ := h
  have hmem := List.mem_of_getLast? hlast
  rw [List.mem_filter] at hmem
  obtain ⟨hzip, hp⟩ := hmem
  rw [List.mem_zipIdx_iff_getElem?] at hzip
  refine ⟨entry.1, ?_, hp⟩
  rw [← hindex]
  simpa using hzip

theorem runStep_consistent (sem : KeySemantics W K) (fallback : W)
    (state : RunState W K) (values : List W) (event : Event)
    (h : Consistent sem state) :
    Consistent sem (runStep sem fallback (state, values) event).1 := by
  cases event with
  | lookup objectId key =>
      simp only [runStep]
      cases reusable (state.facts.map (·.fact)) objectId key with
      | some index => simpa [Consistent] using h
      | none =>
          intro runFact hmem key' hvalid hkey
          simp only [List.mem_append, List.mem_singleton] at hmem
          rcases hmem with hmem | hmem
          · exact h runFact hmem key' hvalid hkey
          · subst hmem
            simp only at hkey
            subst hkey
            rfl
  | bind var =>
      simp only [Consistent, runStep, List.mem_map]
      rintro runFact ⟨old, hold, rfl⟩ key hvalid hkey
      have hkey' : old.fact.key = some key := by simpa [forget] using hkey
      have hvalid' : old.fact.valid = true ∧
          (old.fact.key.any (fun key => key.vars.contains var)) = false := by
        simpa [forget] using hvalid
      obtain ⟨holdValid, hfree⟩ := hvalid'
      have hprev := h old hold key holdValid hkey'
      rw [hprev]
      congr 1
      apply sem.depends
      intro name hname
      have hnot : name ≠ var := by
        intro heq
        subst heq
        rw [hkey'] at hfree
        have hcontains : key.vars.contains name = false := by simpa [Option.any] using hfree
        have hmem : key.vars.contains name = true := List.elem_iff.mpr hname
        rw [hcontains] at hmem
        exact Bool.false_ne_true hmem
      simp [hnot]

theorem foldl_consistent (sem : KeySemantics W K) (fallback : W) :
    ∀ (events : List Event) (state : RunState W K) (values : List W),
      Consistent sem state →
      Consistent sem (events.foldl (runStep sem fallback) (state, values)).1
  | [], _, _, h => h
  | event :: rest, state, values, h => by
      simp only [List.foldl_cons]
      exact foldl_consistent sem fallback rest _ _
        (runStep_consistent sem fallback state values event h)

omit [DecidableEq K] in
/-- At a lookup that reuses a fact, the fact is valid, of the same map, under
the same key, and found with the key's present value. -/
theorem runStep_reuse_sound (sem : KeySemantics W K)
    (state : RunState W K) (objectId : Nat) (key : FactKey)
    (index : Nat) (h : Consistent sem state)
    (hreuse : reusable (state.facts.map (·.fact)) objectId (some key) = some index) :
    ∃ runFact, state.facts[index]? = some runFact ∧
      runFact.fact.objectId = objectId ∧
      runFact.keyValue = some (sem.eval key state.env) := by
  simp only [reusable] at hreuse
  obtain ⟨fact, hfact, hserves⟩ := findLastIdx?_spec _ _ _ hreuse
  rw [List.getElem?_map] at hfact
  cases hentry : state.facts[index]? with
  | none => simp [hentry] at hfact
  | some runFact =>
      rw [hentry] at hfact
      simp only [Option.map_some, Option.some.injEq] at hfact
      subst hfact
      simp only [serves, Bool.and_eq_true, beq_iff_eq] at hserves
      obtain ⟨⟨hobject, hvalid⟩, hkey⟩ := hserves
      refine ⟨runFact, rfl, hobject, ?_⟩
      exact h runFact (List.mem_of_getElem? hentry) key hvalid hkey

/-- What a run keeps true: the facts are consistent, and every lookup that
reused a fact so far had the fact's key. -/
def Sound (sem : KeySemantics W K) (state : RunState W K) : Prop :=
  Consistent sem state ∧ ∀ agreement ∈ state.agreements, agreement = true

theorem runStep_sound (sem : KeySemantics W K) (fallback : W)
    (state : RunState W K) (values : List W) (event : Event)
    (h : Sound sem state) :
    Sound sem (runStep sem fallback (state, values) event).1 := by
  refine ⟨runStep_consistent sem fallback state values event h.1, ?_⟩
  cases event with
  | lookup objectId key =>
      simp only [runStep]
      cases hreuse : reusable (state.facts.map (·.fact)) objectId key with
      | none => simpa using h.2
      | some index =>
          intro agreement hmem
          simp only [List.mem_append, List.mem_singleton] at hmem
          rcases hmem with hmem | rfl
          · exact h.2 agreement hmem
          · cases key with
            | none => simp [reusable] at hreuse
            | some key =>
                obtain ⟨runFact, hentry, _, hvalue⟩ :=
                  runStep_reuse_sound sem state objectId key index h.1 hreuse
                simp [hentry, hvalue]
  | bind var => simpa [runStep] using h.2

theorem foldl_sound (sem : KeySemantics W K) (fallback : W) :
    ∀ (events : List Event) (current : RunState W K × List W),
      Sound sem current.1 →
      Sound sem (events.foldl (runStep sem fallback) current).1
  | [], _, h => h
  | event :: rest, (state, values), h => by
      simp only [List.foldl_cons]
      exact foldl_sound sem fallback rest _ (runStep_sound sem fallback state values event h)

/-- In every run, every lookup that reuses a fact has the key under which the
fact was found: it returns what a fresh lookup of the committed map would,
and the call's pending writes apply over it alike. -/
theorem run_reuse_sound (sem : KeySemantics W K) (fallback : W) (env : String → W)
    (values : List W) (events : List Event) :
    ∀ agreement ∈ (run sem fallback env values events).agreements, agreement = true :=
  (foldl_sound sem fallback events
    ({ env := env, facts := [], reuses := [], keys := [], agreements := [] }, values)
    ⟨by intro runFact hmem; simp at hmem, by simp⟩).2

end UOToolchain.FactReuse
