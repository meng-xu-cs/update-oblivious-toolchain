import UOToolchain.TeeDeployment

/-! # SGX boundary-data layer

This file pins the SGX boundary-event vocabulary
(`BoundaryDirection` / `BoundaryEvent`), the page-event and
exit-event vocabularies (`PageEventKind` / `PageEvent` /
`ExitEvent`), and the shared-resource trace abbreviation. It also
defines the paper-facing `SGXView` record, the deterministic SGX
execution view (`SGXExecutionView`), the ambient `SGXSemantics` /
`SGXSecurityRelation` types, and the top-level
`SGXExecutionOblivious` predicate.

This is a pure data layer; no theorems are stated here. The W6
freeze records `sgxObserverSurfaceProvenance`,
`sgxBoundaryCallProvenance`, `sgxPersistentIoProvenance` (in
`SgxObserverFreeze.lean`) pin the ABI-style vocabulary literals of
this layer; the projection chain `SgxRelation.lean` →
`SgxExactProjection.lean` / `SgxOramProjection.lean` /
`SgxJointProjection.lean` then carries the paper-main theorems. -/

namespace UOToolchain

inductive BoundaryDirection where
  | enter
  | exit
deriving Repr, DecidableEq

structure BoundaryEvent where
  direction : BoundaryDirection
  apiId : String
  inputLen : Nat
  outputLen : Nat
deriving Repr, DecidableEq

inductive PageEventKind where
  | faultIn
  | evictOut
deriving Repr, DecidableEq

structure PageEvent where
  pageKind : String
  pageId : Nat
  kind : PageEventKind
deriving Repr, DecidableEq

inductive ExitEvent where
  | interruptExit
  | resume
  | terminate
deriving Repr, DecidableEq

abbrev SharedResourceTrace := List String

structure SGXView where
  entrypointId : String
  publicArgs : List String
  boundarySchedule : List BoundaryEvent
  persistentReads : List PhysicalRead
  persistentWrites : List PhysicalWrite
  pageTrace : List PageEvent
  exitTrace : List ExitEvent
  sharedResourceTrace : SharedResourceTrace
  terminationStatus : Bool
  outputShape : OutputShape
  gasUsed : Nat
deriving Repr, DecidableEq

structure SGXSetupPublic where
  measurement : String
  attestationPolicy : String
deriving Repr, DecidableEq

abbrev SGXExecutionView := SGXSetupPublic × List SGXView
abbrev SGXSemantics (κ : Type) := κ → Distribution SGXView
abbrev SGXSecurityRelation := Distribution SGXView → Distribution SGXView → Prop

def SGXExecutionOblivious
  {κ : Type}
  (samePublic : κ → κ → Prop)
  (R : SGXSecurityRelation)
  (run : SGXSemantics κ) : Prop :=
  ∀ cfg₁ cfg₂, samePublic cfg₁ cfg₂ → R (run cfg₁) (run cfg₂)

def PhysicalSideChannelsExcluded : Prop := True
def RawTimingExcluded : Prop := True

end UOToolchain
