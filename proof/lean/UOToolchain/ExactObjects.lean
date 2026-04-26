import UOToolchain.IRSemantics

namespace UOToolchain

def exactBackend (backend : String) : Prop :=
  backend = "uocell" ∨ backend = "uoarray" ∨ backend = "full_scan"

def ExactUO (run : TraceSemantics) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → viewMPlus (run cfg₁) = viewMPlus (run cfg₂)

def ExactUOFamily : List TraceSemantics → Prop
  | [] => True
  | run :: runs => ExactUO run ∧ ExactUOFamily runs

def composeExactRuns : List TraceSemantics → TraceSemantics
  | [] => fun _ => Trace.empty
  | run :: runs => fun cfg => Trace.append (run cfg) (composeExactRuns runs cfg)

theorem exactObjectTheorem
  (run : TraceSemantics)
  (hExact : ExactUO run)
  (cfg₁ cfg₂ : Config) :
  samePublicProjection cfg₁ cfg₂ →
  viewMPlus (run cfg₁) = viewMPlus (run cfg₂) := by
  intro hPublic
  exact hExact cfg₁ cfg₂ hPublic

theorem exactUO_empty : ExactUO (fun _ => Trace.empty) := by
  intro cfg₁ cfg₂ _hPublic
  simp

theorem exactUO_append {lhs rhs : TraceSemantics}
  (hLhs : ExactUO lhs)
  (hRhs : ExactUO rhs) :
  ExactUO (fun cfg => Trace.append (lhs cfg) (rhs cfg)) := by
  intro cfg₁ cfg₂ hPublic
  have hLhsTrace : lhs cfg₁ = lhs cfg₂ :=
    viewMPlus_injective (hLhs cfg₁ cfg₂ hPublic)
  have hRhsTrace : rhs cfg₁ = rhs cfg₂ :=
    viewMPlus_injective (hRhs cfg₁ cfg₂ hPublic)
  simp [hLhsTrace, hRhsTrace]

theorem exactUO_compose : ∀ {runs : List TraceSemantics}, ExactUOFamily runs → ExactUO (composeExactRuns runs)
  | [], _ => exactUO_empty
  | run :: runs, hFamily =>
      let hRun : ExactUO run := hFamily.left
      let hRuns : ExactUOFamily runs := hFamily.right
      exactUO_append hRun (exactUO_compose hRuns)

end UOToolchain
